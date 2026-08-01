import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

final dailyQuestServiceProvider = Provider<DailyQuestService>(
  (ref) => DailyQuestService(),
);

final dailyQuestSnapshotProvider =
    FutureProvider<DailyQuestSnapshot>((ref) async {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(dailyQuestServiceProvider).snapshot(uid);
});

class DailyQuestService {
  static const _prefix = 'wrapMaze.dailyQuests.v1';

  String _todayKey() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  String _key(String uid, String field) =>
      '$_prefix.$uid.${_todayKey()}.$field';

  Future<DailyQuestSnapshot> snapshot(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final completedLevels = prefs.getInt(_key(uid, 'completedLevels')) ?? 0;
    final noHintWins = prefs.getInt(_key(uid, 'noHintWins')) ?? 0;
    final stars = prefs.getInt(_key(uid, 'stars')) ?? 0;
    final claimed = prefs.getStringList(_key(uid, 'claimed')) ?? const [];
    return DailyQuestSnapshot(
      dateKey: _todayKey(),
      quests: [
        DailyQuest(
          id: 'complete_2',
          titleTr: '2 bolum tamamla',
          titleEn: 'Complete 2 levels',
          progress: completedLevels,
          target: 2,
          reward: 20,
          claimed: claimed.contains('complete_2'),
        ),
        DailyQuest(
          id: 'no_hint_1',
          titleTr: '1 bolumu ipucusuz bitir',
          titleEn: 'Win 1 level without hints',
          progress: noHintWins,
          target: 1,
          reward: 25,
          claimed: claimed.contains('no_hint_1'),
        ),
        DailyQuest(
          id: 'stars_6',
          titleTr: '6 yildiz topla',
          titleEn: 'Earn 6 stars',
          progress: stars,
          target: 6,
          reward: 30,
          claimed: claimed.contains('stars_6'),
        ),
      ],
    );
  }

  Future<DailyQuestReward> recordLevelWin({
    required String uid,
    required int stars,
    required bool noHint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(uid, 'completedLevels'),
      (prefs.getInt(_key(uid, 'completedLevels')) ?? 0) + 1,
    );
    await prefs.setInt(
      _key(uid, 'stars'),
      (prefs.getInt(_key(uid, 'stars')) ?? 0) + stars,
    );
    if (noHint) {
      await prefs.setInt(
        _key(uid, 'noHintWins'),
        (prefs.getInt(_key(uid, 'noHintWins')) ?? 0) + 1,
      );
    }

    final updated = await snapshot(uid);
    final claimed =
        (prefs.getStringList(_key(uid, 'claimed')) ?? const []).toSet();
    var bonus = 0;
    final completedTitlesTr = <String>[];
    final completedTitlesEn = <String>[];
    for (final quest in updated.quests) {
      if (!quest.done || claimed.contains(quest.id)) continue;
      claimed.add(quest.id);
      bonus += quest.reward;
      completedTitlesTr.add(quest.titleTr);
      completedTitlesEn.add(quest.titleEn);
    }
    await prefs.setStringList(_key(uid, 'claimed'), claimed.toList()..sort());
    return DailyQuestReward(
      coins: bonus,
      titlesTr: completedTitlesTr,
      titlesEn: completedTitlesEn,
    );
  }
}

class DailyQuestSnapshot {
  final String dateKey;
  final List<DailyQuest> quests;

  const DailyQuestSnapshot({
    required this.dateKey,
    required this.quests,
  });

  int get completedCount => quests.where((quest) => quest.claimed).length;
  int get totalCount => quests.length;
}

class DailyQuest {
  final String id;
  final String titleTr;
  final String titleEn;
  final int progress;
  final int target;
  final int reward;
  final bool claimed;

  const DailyQuest({
    required this.id,
    required this.titleTr,
    required this.titleEn,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
  });

  bool get done => progress >= target;
  double get ratio => (progress / target).clamp(0, 1);
}

class DailyQuestReward {
  final int coins;
  final List<String> titlesTr;
  final List<String> titlesEn;

  const DailyQuestReward({
    required this.coins,
    required this.titlesTr,
    required this.titlesEn,
  });

  bool get hasReward => coins > 0;
}
