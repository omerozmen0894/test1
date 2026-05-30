// lib/features/streak/streak_screen.dart
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/streak_model.dart';
import '../../core/services/streak_service.dart';

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakDataProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🔥 Streak',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: streakAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (streak) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Streak Hero ───────────────────────────────────────────────
            _StreakHero(streak: streak),

            const SizedBox(height: 20),

            // ── Son 4 hafta takvim ────────────────────────────────────────
            _CalendarView(streak: streak),

            const SizedBox(height: 20),

            // ── Rozetler ─────────────────────────────────────────────────
            Text('Rozetler',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(height: 12),
            _BadgeGrid(streak: streak),

            const SizedBox(height: 20),

            // ── Hedefler ─────────────────────────────────────────────────
            Text('Hedefler',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(height: 12),
            ..._buildGoals(streak, scheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGoals(StreakData streak, ColorScheme scheme) {
    final goals = [
      (3, '🔥', '3 Günlük Seri', Badge.streak3.id),
      (7, '⚡', 'Haftalık Seri', Badge.streak7.id),
      (14, '💎', '2 Haftalık Seri', Badge.streak14.id),
      (30, '👑', 'Aylık Seri', Badge.streak30.id),
    ];
    return goals.map((g) {
      final unlocked = streak.unlockedBadges.any((b) => b.id == g.$4);
      final progress = (streak.currentStreak / g.$1).clamp(0.0, 1.0);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked
                ? scheme.primary.withOpacity(0.4)
                : scheme.outline.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Text(g.$2, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(g.$3,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                      if (unlocked)
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: scheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(
                        unlocked ? Colors.green : scheme.primary),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unlocked
                        ? 'Tamamlandı!'
                        : '${streak.currentStreak} / ${g.$1} gün',
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ─── Streak Hero ─────────────────────────────────────────────────────────────

class _StreakHero extends StatelessWidget {
  final StreakData streak;
  const _StreakHero({required this.streak});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: streak.currentStreak >= 7
              ? [const Color(0xFFEF4444), const Color(0xFFEA580C)]
              : [scheme.primaryContainer, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${streak.currentStreak}',
                style: const TextStyle(
                    fontSize: 56, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1),
              ),
              Text('günlük seri 🔥',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9))),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('En iyi',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.7))),
              Text('${streak.bestStreak} gün',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(streak.hasCompletedToday ? '✅ Bugün tamam!' : '⏳ Bugün henüz yok',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85))),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}

// ─── Takvim ──────────────────────────────────────────────────────────────────

class _CalendarView extends StatelessWidget {
  final StreakData streak;
  const _CalendarView({required this.streak});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // Son 28 gün
    final days = List.generate(28, (i) => now.subtract(Duration(days: 27 - i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Son 4 Hafta',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600,
                color: scheme.onSurface)),
        const SizedBox(height: 12),
        // Gün başlıkları
        Row(
          children: ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'].map((d) {
            return Expanded(
              child: Text(d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withOpacity(0.4))),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        // Takvim grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4,
          ),
          itemCount: days.length,
          itemBuilder: (ctx, i) {
            final day = days[i];
            final key =
                '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
            final completed = streak.completedDays.contains(key);
            final isToday = key == _todayKey();

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFFEF4444)
                    : isToday
                        ? scheme.primaryContainer
                        : scheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
                border: isToday
                    ? Border.all(color: scheme.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: completed
                          ? Colors.white
                          : scheme.onSurface.withOpacity(0.7)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ─── Rozet Gridi ─────────────────────────────────────────────────────────────

class _BadgeGrid extends StatelessWidget {
  final StreakData streak;
  const _BadgeGrid({required this.streak});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allBadges = [
      Badge.streak3, Badge.streak7, Badge.streak14,
      Badge.streak30, Badge.bestWeek, Badge.bestMonth,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: allBadges.length,
      itemBuilder: (ctx, i) {
        final template = allBadges[i];
        final unlocked = streak.unlockedBadges.any((b) => b.id == template.id);
        final info = unlocked
            ? streak.unlockedBadges.firstWhere((b) => b.id == template.id)
            : null;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: unlocked
                ? scheme.primaryContainer.withOpacity(0.5)
                : scheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unlocked
                  ? scheme.primary.withOpacity(0.4)
                  : scheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                template.emoji,
                style: TextStyle(
                    fontSize: 28,
                    color: unlocked ? null : Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                template.title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: unlocked
                        ? scheme.onSurface
                        : scheme.onSurface.withOpacity(0.3)),
                textAlign: TextAlign.center,
              ),
              if (info != null) ...[
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM', 'tr_TR').format(info.unlockedAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurface.withOpacity(0.45)),
                ),
              ] else
                Text('Kilitli',
                    style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurface.withOpacity(0.25))),
            ],
          ),
        ).animate(delay: (i * 60).ms).fadeIn().scale(begin: const Offset(0.8, 0.8));
      },
    );
  }
}
