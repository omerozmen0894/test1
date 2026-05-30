// lib/core/models/streak_model.dart

class StreakData {
  final int currentStreak;
  final int bestStreak;
  final List<String> completedDays; // 'YYYY-MM-DD' formatında
  final List<BadgeInfo> unlockedBadges;

  const StreakData({
    required this.currentStreak,
    required this.bestStreak,
    required this.completedDays,
    required this.unlockedBadges,
  });

  bool get hasCompletedToday {
    final today = _todayKey();
    return completedDays.contains(today);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  StreakData addToday() {
    final key = _todayKey();
    if (completedDays.contains(key)) return this;

    final newDays = [...completedDays, key];
    final newStreak = _calcStreak(newDays);
    final newBest = newStreak > bestStreak ? newStreak : bestStreak;
    final newBadges = _checkBadges(newStreak, newBest, [...unlockedBadges]);

    return StreakData(
      currentStreak: newStreak,
      bestStreak: newBest,
      completedDays: newDays,
      unlockedBadges: newBadges,
    );
  }

  static int _calcStreak(List<String> days) {
    if (days.isEmpty) return 0;
    final sorted = [...days]..sort((a, b) => b.compareTo(a));
    int streak = 1;
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = DateTime.parse(sorted[i]);
      final b = DateTime.parse(sorted[i + 1]);
      if (a.difference(b).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static List<BadgeInfo> _checkBadges(int streak, int best, List<BadgeInfo> existing) {
    final existingIds = existing.map((b) => b.id).toSet();
    final toAdd = <BadgeInfo>[];

    void maybeAdd(BadgeInfo badge) {
      if (!existingIds.contains(badge.id)) toAdd.add(badge);
    }

    if (streak >= 3) maybeAdd(Badge.streak3);
    if (streak >= 7) maybeAdd(Badge.streak7);
    if (streak >= 14) maybeAdd(Badge.streak14);
    if (streak >= 30) maybeAdd(Badge.streak30);
    if (best >= 7) maybeAdd(Badge.bestWeek);
    if (best >= 30) maybeAdd(Badge.bestMonth);

    return [...existing, ...toAdd];
  }

  factory StreakData.empty() => const StreakData(
        currentStreak: 0, bestStreak: 0,
        completedDays: [], unlockedBadges: [],
      );

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'completedDays': completedDays,
        'unlockedBadges': unlockedBadges.map((b) => b.toMap()).toList(),
      };

  factory StreakData.fromMap(Map<String, dynamic> m) => StreakData(
        currentStreak: m['currentStreak'] ?? 0,
        bestStreak: m['bestStreak'] ?? 0,
        completedDays: List<String>.from(m['completedDays'] ?? []),
        unlockedBadges: (m['unlockedBadges'] as List? ?? [])
            .map((b) => BadgeInfo.fromMap(b))
            .toList(),
      );
}

// ─── Badge tanımları ──────────────────────────────────────────────────────────

class BadgeInfo {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final DateTime unlockedAt;

  const BadgeInfo({
    required this.id, required this.emoji,
    required this.title, required this.description,
    required this.unlockedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'emoji': emoji, 'title': title,
        'description': description, 'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory BadgeInfo.fromMap(Map m) => BadgeInfo(
        id: m['id'], emoji: m['emoji'], title: m['title'],
        description: m['description'],
        unlockedAt: DateTime.parse(m['unlockedAt']),
      );
}

class Badge {
  static BadgeInfo get streak3 => BadgeInfo(
        id: 'streak_3', emoji: '🔥', title: '3 Günlük Seri',
        description: '3 gün üst üste günlük bölümü tamamla',
        unlockedAt: DateTime.now(),
      );
  static BadgeInfo get streak7 => BadgeInfo(
        id: 'streak_7', emoji: '⚡', title: 'Haftalık Seri',
        description: '7 gün üst üste günlük bölümü tamamla',
        unlockedAt: DateTime.now(),
      );
  static BadgeInfo get streak14 => BadgeInfo(
        id: 'streak_14', emoji: '💎', title: '2 Haftalık Seri',
        description: '14 gün üst üste tamamla',
        unlockedAt: DateTime.now(),
      );
  static BadgeInfo get streak30 => BadgeInfo(
        id: 'streak_30', emoji: '👑', title: 'Aylık Seri',
        description: '30 gün üst üste tamamla',
        unlockedAt: DateTime.now(),
      );
  static BadgeInfo get bestWeek => BadgeInfo(
        id: 'best_week', emoji: '🏅', title: 'Hafta Rekoru',
        description: 'En iyi serin 7 güne ulaştı',
        unlockedAt: DateTime.now(),
      );
  static BadgeInfo get bestMonth => BadgeInfo(
        id: 'best_month', emoji: '🏆', title: 'Ay Rekoru',
        description: 'En iyi serin 30 güne ulaştı',
        unlockedAt: DateTime.now(),
      );
}
