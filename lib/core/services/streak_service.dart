// lib/core/services/streak_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../database/progress_model.dart';
import '../models/streak_model.dart';
import '../providers/isar_provider.dart';
import 'auth_service.dart';

final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(ref.read(isarProvider), ref.watch(currentUidProvider));
});

final streakDataProvider = FutureProvider<StreakData>((ref) async {
  return ref.watch(streakServiceProvider).load();
});

class StreakService {
  final Isar? _isar;
  final String _uid;
  StreakService(this._isar, this._uid);

  Future<StreakData> load() async {
    final isar = _isar;
    if (isar == null) return StreakData.empty();
    final record =
        await isar.streakRecords.filter().uidEqualTo(_uid).findFirst();
    if (record == null) return StreakData.empty();
    return StreakData(
      currentStreak: record.currentStreak,
      bestStreak: record.bestStreak,
      completedDays: record.completedDays,
      unlockedBadges: record.badgeData
          .map((json) => BadgeInfo.fromMap(jsonDecode(json)))
          .toList(),
    );
  }

  /// Günlük tamamlandığında çağır — yeni rozet varsa döner
  Future<List<BadgeInfo>> markToday() async {
    final isar = _isar;
    if (isar == null) return const [];
    final current = await load();
    final oldBadgeCount = current.unlockedBadges.length;
    final updated = current.addToday();

    await isar.writeTxn(() async {
      final record =
          await isar.streakRecords.filter().uidEqualTo(_uid).findFirst() ??
              StreakRecord.empty(_uid);
      record
        ..currentStreak = updated.currentStreak
        ..bestStreak = updated.bestStreak
        ..completedDays = updated.completedDays
        ..badgeIds = updated.unlockedBadges.map((b) => b.id).toList()
        ..badgeData =
            updated.unlockedBadges.map((b) => jsonEncode(b.toMap())).toList();
      await isar.streakRecords.put(record);
    });

    // Yeni kazanılan rozetleri döndür
    return updated.unlockedBadges.skip(oldBadgeCount).toList();
  }

  Future<void> reset() async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.streakRecords.filter().uidEqualTo(_uid).deleteAll();
    });
  }
}
