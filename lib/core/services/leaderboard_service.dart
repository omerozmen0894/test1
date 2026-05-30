import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final leaderboardServiceProvider =
    Provider<LeaderboardService>((ref) => LeaderboardService());

final globalLeaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardServiceProvider).watchGlobalTop();
});

enum LeaderboardPeriod {
  daily('Günlük'),
  weekly('Haftalık'),
  monthly('Aylık');

  final String label;
  const LeaderboardPeriod(this.label);
}

final periodLeaderboardProvider =
    StreamProvider.family<List<LeaderboardEntry>, LeaderboardPeriod>(
        (ref, period) {
  return ref.watch(leaderboardServiceProvider).watchPeriodTop(period);
});

final endlessLeaderboardProvider =
    StreamProvider<List<EndlessLeaderboardEntry>>((ref) {
  return ref.watch(leaderboardServiceProvider).watchEndlessTop();
});

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signInAnonymously() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
    } catch (_) {}
  }

  Future<void> submitLevelScore({
    required int level,
    required int moves,
    required int seconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('leaderboard').doc(user.uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final data = snap.data() ?? {};
      final bestLevel = (data['bestLevel'] as num?)?.toInt() ?? 0;
      final totalCompleted = (data['totalCompleted'] as num?)?.toInt() ?? 0;
      final bestMovesByLevel =
          Map<String, dynamic>.from(data['bestMovesByLevel'] as Map? ?? {});
      final oldMoves = (bestMovesByLevel['$level'] as num?)?.toInt();
      final isNewLevel = oldMoves == null;
      final isBetter = oldMoves == null || moves < oldMoves;
      if (isBetter) bestMovesByLevel['$level'] = moves;

      txn.set(
          userRef,
          {
            'uid': user.uid,
            'displayName': user.displayName?.trim().isNotEmpty == true
                ? user.displayName
                : 'Oyuncu',
            'bestLevel': level > bestLevel ? level : bestLevel,
            'totalCompleted': totalCompleted + (isNewLevel ? 1 : 0),
            'bestMovesByLevel': bestMovesByLevel,
            'lastLevel': level,
            'lastMoves': moves,
            'lastSeconds': seconds,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    await _firestore.collection('level_scores').add({
      'uid': user.uid,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : 'Oyuncu',
      'level': level,
      'moves': moves,
      'seconds': seconds,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final period in LeaderboardPeriod.values) {
      try {
        await _submitPeriodLevelScore(
          period: period,
          user: user,
          level: level,
          moves: moves,
          seconds: seconds,
        );
      } catch (_) {
        // Period tables need the latest Firestore rules. Keep the main score safe.
      }
    }
  }

  Future<void> submitEndlessScore({
    required int stage,
    required int moves,
    required int seconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('endless_leaderboard').doc(user.uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final data = snap.data() ?? {};
      final bestStage = (data['bestStage'] as num?)?.toInt() ?? 0;
      final bestMoves = (data['bestMoves'] as num?)?.toInt() ?? 999999;
      final isBetter =
          stage > bestStage || (stage == bestStage && moves < bestMoves);
      if (!isBetter) return;

      txn.set(
          userRef,
          {
            'uid': user.uid,
            'displayName': user.displayName?.trim().isNotEmpty == true
                ? user.displayName
                : 'Oyuncu',
            'bestStage': stage,
            'bestMoves': moves,
            'bestSeconds': seconds,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> _submitPeriodLevelScore({
    required LeaderboardPeriod period,
    required User user,
    required int level,
    required int moves,
    required int seconds,
  }) async {
    final periodKey = _periodKey(period, DateTime.now());
    final userRef = _firestore
        .collection('leaderboard_periods')
        .doc(periodKey)
        .collection('level')
        .doc(user.uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final data = snap.data() ?? {};
      final bestLevel = (data['bestLevel'] as num?)?.toInt() ?? 0;
      final totalCompleted = (data['totalCompleted'] as num?)?.toInt() ?? 0;
      final bestMovesByLevel =
          Map<String, dynamic>.from(data['bestMovesByLevel'] as Map? ?? {});
      final oldMoves = (bestMovesByLevel['$level'] as num?)?.toInt();
      final isNewLevel = oldMoves == null;
      final isBetter = oldMoves == null || moves < oldMoves;
      if (isBetter) bestMovesByLevel['$level'] = moves;

      txn.set(
          userRef,
          {
            'uid': user.uid,
            'displayName': user.displayName?.trim().isNotEmpty == true
                ? user.displayName
                : 'Oyuncu',
            'periodKey': periodKey,
            'period': period.name,
            'bestLevel': level > bestLevel ? level : bestLevel,
            'totalCompleted': totalCompleted + (isNewLevel ? 1 : 0),
            'bestMovesByLevel': bestMovesByLevel,
            'lastLevel': level,
            'lastMoves': moves,
            'lastSeconds': seconds,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Stream<List<LeaderboardEntry>> watchGlobalTop({int limit = 50}) {
    return _firestore
        .collection('leaderboard')
        .orderBy('bestLevel', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => LeaderboardEntry.fromMap(doc.data()))
          .toList();
      entries.sort((a, b) {
        final byLevel = b.bestLevel.compareTo(a.bestLevel);
        if (byLevel != 0) return byLevel;
        final byCompleted = b.totalCompleted.compareTo(a.totalCompleted);
        if (byCompleted != 0) return byCompleted;
        return a.lastMoves.compareTo(b.lastMoves);
      });
      return entries;
    });
  }

  Stream<List<LeaderboardEntry>> watchPeriodTop(
    LeaderboardPeriod period, {
    int limit = 50,
  }) async* {
    final periodKey = _periodKey(period, DateTime.now());
    try {
      await for (final snapshot in _firestore
          .collection('leaderboard_periods')
          .doc(periodKey)
          .collection('level')
          .orderBy('bestLevel', descending: true)
          .limit(limit)
          .snapshots()) {
        final entries = snapshot.docs
            .map((doc) => LeaderboardEntry.fromMap(doc.data()))
            .toList();
        entries.sort((a, b) {
          final byLevel = b.bestLevel.compareTo(a.bestLevel);
          if (byLevel != 0) return byLevel;
          final byCompleted = b.totalCompleted.compareTo(a.totalCompleted);
          if (byCompleted != 0) return byCompleted;
          return a.lastMoves.compareTo(b.lastMoves);
        });
        yield entries;
      }
    } on FirebaseException {
      yield const <LeaderboardEntry>[];
    }
  }

  Stream<List<EndlessLeaderboardEntry>> watchEndlessTop({int limit = 50}) {
    return _firestore
        .collection('endless_leaderboard')
        .orderBy('bestStage', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => EndlessLeaderboardEntry.fromMap(doc.data()))
          .toList();
      entries.sort((a, b) {
        final byStage = b.bestStage.compareTo(a.bestStage);
        if (byStage != 0) return byStage;
        return a.bestMoves.compareTo(b.bestMoves);
      });
      return entries;
    });
  }

  String _periodKey(LeaderboardPeriod period, DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return switch (period) {
      LeaderboardPeriod.daily =>
        'day_${local.year}${_two(local.month)}${_two(local.day)}',
      LeaderboardPeriod.weekly =>
        'week_${local.year}_${_two(_weekOfYear(local))}',
      LeaderboardPeriod.monthly => 'month_${local.year}${_two(local.month)}',
    };
  }

  int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final dayOffset = firstDay.weekday - DateTime.monday;
    final firstMonday = firstDay.subtract(Duration(days: dayOffset));
    return ((date.difference(firstMonday).inDays) ~/ 7) + 1;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int bestLevel;
  final int totalCompleted;
  final int lastMoves;
  final int lastSeconds;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.bestLevel,
    required this.totalCompleted,
    required this.lastMoves,
    required this.lastSeconds,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Oyuncu',
      bestLevel: (map['bestLevel'] as num?)?.toInt() ?? 0,
      totalCompleted: (map['totalCompleted'] as num?)?.toInt() ?? 0,
      lastMoves: (map['lastMoves'] as num?)?.toInt() ?? 0,
      lastSeconds: (map['lastSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class EndlessLeaderboardEntry {
  final String uid;
  final String displayName;
  final int bestStage;
  final int bestMoves;
  final int bestSeconds;

  const EndlessLeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.bestStage,
    required this.bestMoves,
    required this.bestSeconds,
  });

  factory EndlessLeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return EndlessLeaderboardEntry(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Oyuncu',
      bestStage: (map['bestStage'] as num?)?.toInt() ?? 0,
      bestMoves: (map['bestMoves'] as num?)?.toInt() ?? 0,
      bestSeconds: (map['bestSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
