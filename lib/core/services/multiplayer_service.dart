// lib/core/services/multiplayer_service.dart
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maze_model.dart';
import '../models/multiplayer_model.dart';
import '../maze_generator.dart';

final multiplayerServiceProvider =
    Provider<MultiplayerService>((ref) => MultiplayerService());

final activeRoomProvider = StreamProvider.family<MultiplayerRoom?, String>(
  (ref, roomCode) => ref.watch(multiplayerServiceProvider).watchRoom(roomCode),
);

class MultiplayerService {
  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Çok oyunculu mod için giriş yapılmalı.');
    }
    return uid;
  }

  String get _displayName =>
      _auth.currentUser?.displayName?.trim().isNotEmpty == true
          ? _auth.currentUser!.displayName!
          : 'Oyuncu';

  DatabaseReference _roomRef(String code) =>
      _db.ref('rooms/$code');

  // ─── Oda oluştur ─────────────────────────────────────────────────────────

  Future<String> createRoom() async {
    final code = _generateCode();
    final ref = _roomRef(code);

    await ref.set({
      'hostId': _uid,
      'status': RoomStatus.waiting.name,
      'createdAt': ServerValue.timestamp,
      'players': {
        _uid: PlayerData(
          uid: _uid,
          displayName: _displayName,
          path: [],
          moveCount: 0,
          finished: false,
          status: PlayerStatus.connected,
        ).toMap(),
      },
    });

    // 10 dakika sonra oda silinsin
    ref.onDisconnect().remove();
    return code;
  }

  // ─── Odaya katıl ─────────────────────────────────────────────────────────

  Future<bool> joinRoom(String code) async {
    final ref = _roomRef(code);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final room = MultiplayerRoom.fromMap(
      Map<dynamic, dynamic>.from(snap.value as Map),
      code,
    );

    if (room.isFull || room.status != RoomStatus.waiting) return false;

    await ref.child('players/$_uid').set(PlayerData(
      uid: _uid,
      displayName: _displayName,
      path: [],
      moveCount: 0,
      finished: false,
      status: PlayerStatus.connected,
    ).toMap());

    return true;
  }

  // ─── Oyunu başlat (sadece host) ──────────────────────────────────────────

  Future<void> startGame(String code) async {
    final seedLevel = DateTime.now().millisecondsSinceEpoch % 1000;
    final maze = MazeGenerator.generate(seedLevel);
    final ref = _roomRef(code);

    // 3 saniyelik geri sayım
    for (int i = 3; i >= 1; i--) {
      await ref.update({'countdown': i, 'status': RoomStatus.countdown.name});
      await Future.delayed(const Duration(seconds: 1));
    }

    await ref.update({
      'status': RoomStatus.playing.name,
      'countdown': null,
      'maze': maze.toMap(),
      'seedLevel': seedLevel,
    });
  }

  // ─── Oyuncu hamle yaptı ──────────────────────────────────────────────────

  Future<void> updatePath(String code, List<Cell> path, int moveCount) async {
    final pathData = path.map((c) => c.toMap()).toList();
    await _roomRef(code).child('players/$_uid').update({
      'path': pathData,
      'moveCount': moveCount,
    });
  }

  // ─── Oyuncu bitirdi ──────────────────────────────────────────────────────

  Future<void> markFinished(String code) async {
    await _roomRef(code).child('players/$_uid').update({
      'finished': true,
      'status': PlayerStatus.finished.name,
      'finishTime': ServerValue.timestamp,
    });

    // Tüm oyuncular bitirdiyse odayı kapat
    final snap = await _roomRef(code).child('players').get();
    final players = Map<dynamic, dynamic>.from(snap.value as Map);
    final allFinished = players.values.every((p) => p['finished'] == true);
    if (allFinished) {
      await _roomRef(code).update({'status': RoomStatus.finished.name});
    }
  }

  // ─── Odadan çık ─────────────────────────────────────────────────────────

  Future<void> leaveRoom(String code) async {
    await _roomRef(code).child('players/$_uid').update({
      'status': PlayerStatus.disconnected.name,
    });
  }

  // ─── Oda dinle ───────────────────────────────────────────────────────────

  Stream<MultiplayerRoom?> watchRoom(String code) {
    return _roomRef(code).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return MultiplayerRoom.fromMap(
        Map<dynamic, dynamic>.from(event.snapshot.value as Map),
        code,
      );
    });
  }

  // ─── Kod üret ────────────────────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
