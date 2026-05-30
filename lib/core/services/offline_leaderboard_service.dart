// lib/core/services/offline_leaderboard_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../database/progress_model.dart';
import '../providers/isar_provider.dart';

final offlineLeaderboardProvider =
    Provider<OfflineLeaderboardService>((ref) {
  return OfflineLeaderboardService(ref.read(isarProvider));
});

/// Yerel sıralama — internet olmadan çalışır
/// Aynı cihazdaki farklı kullanıcı adlarını saklar
class OfflineLeaderboardService {
  final Isar _isar;
  OfflineLeaderboardService(this._isar);

  Future<void> submitScore({
    required String displayName,
    required int totalCompleted,
    required int bestStreak,
    required int dailyCompleted,
  }) async {
    await _isar.writeTxn(() async {
      // Aynı isimde varsa güncelle
      final existing = await _isar.offlineScores
          .filter()
          .displayNameEqualTo(displayName)
          .findFirst();

      if (existing != null) {
        if (totalCompleted > existing.totalCompleted) {
          existing.totalCompleted = totalCompleted;
          existing.bestStreak = bestStreak;
          existing.dailyCompleted = dailyCompleted;
          existing.recordedAt = DateTime.now();
          await _isar.offlineScores.put(existing);
        }
      } else {
        await _isar.offlineScores.put(OfflineScore.create(
          displayName: displayName,
          totalCompleted: totalCompleted,
          bestStreak: bestStreak,
          dailyCompleted: dailyCompleted,
        ));
      }
    });
  }

  /// Top 20 yerel sıralama — tamamlanan bölüm sayısına göre
  Future<List<OfflineScore>> getTopScores({int limit = 20}) async {
    return await _isar.offlineScores
        .filter()
        .totalCompletedGreaterThan(0)
        .sortByTotalCompletedDesc()
        .limit(limit)
        .findAll();
  }

  /// Benim sıram (displayName'e göre)
  Future<int?> myRank(String displayName) async {
    final myScore = await _isar.offlineScores
        .filter()
        .displayNameEqualTo(displayName)
        .findFirst();
    if (myScore == null) return null;

    final above = await _isar.offlineScores
        .filter()
        .totalCompletedGreaterThan(myScore.totalCompleted)
        .count();
    return above + 1;
  }

  /// Tüm kayıtları temizle (reset)
  Future<void> clearAll() async {
    await _isar.writeTxn(() => _isar.offlineScores.clear());
  }
}
