import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

final weeklyEventServiceProvider = Provider<WeeklyEventService>(
  (ref) => WeeklyEventService(),
);

final weeklyEventSnapshotProvider =
    FutureProvider<WeeklyEventSnapshot>((ref) async {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(weeklyEventServiceProvider).snapshot(uid);
});

class WeeklyEventService {
  static const _prefix = 'wrapMaze.weeklyEvent.v1';
  static const targetStars = 30;
  static const rewardCoins = 80;

  String _weekKey() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(firstDay).inDays + 1;
    final week = ((dayOfYear + firstDay.weekday - 2) ~/ 7) + 1;
    return '${now.year}-W${week.toString().padLeft(2, '0')}';
  }

  String _key(String uid, String field) => '$_prefix.$uid.${_weekKey()}.$field';

  Future<WeeklyEventSnapshot> snapshot(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return WeeklyEventSnapshot(
      weekKey: _weekKey(),
      titleTr: 'Haftalik yildiz avı',
      titleEn: 'Weekly star hunt',
      progress: prefs.getInt(_key(uid, 'stars')) ?? 0,
      target: targetStars,
      reward: rewardCoins,
      claimed: prefs.getBool(_key(uid, 'claimed')) ?? false,
    );
  }

  Future<int> recordLevelWin({
    required String uid,
    required int stars,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(uid, 'stars'),
      (prefs.getInt(_key(uid, 'stars')) ?? 0) + stars,
    );
    final updated = await snapshot(uid);
    if (!updated.done || updated.claimed) return 0;
    await prefs.setBool(_key(uid, 'claimed'), true);
    return rewardCoins;
  }
}

class WeeklyEventSnapshot {
  final String weekKey;
  final String titleTr;
  final String titleEn;
  final int progress;
  final int target;
  final int reward;
  final bool claimed;

  const WeeklyEventSnapshot({
    required this.weekKey,
    required this.titleTr,
    required this.titleEn,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
  });

  bool get done => progress >= target;
  double get ratio => (progress / target).clamp(0.0, 1.0).toDouble();
}
