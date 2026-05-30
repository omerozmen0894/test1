// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/streak_service.dart';
import '../../core/services/auth_service.dart';
import '../daily/daily_screen.dart';
import '../editor/editor_screen.dart';
import '../game/game_provider.dart';
import '../game/game_screen.dart';
import '../iap/iap_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../leaderboard/offline_leaderboard_screen.dart';
import '../multiplayer/multiplayer_screen.dart';
import '../settings/settings_screen.dart';
import '../streak/streak_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final completedAsync = ref.watch(completedLevelsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final completed = completedAsync.valueOrNull ?? [];
    final completedSet = {for (final p in completed) p.levelNumber};
    final streakAsync = ref.watch(streakDataProvider);
    final streak = streakAsync.valueOrNull;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F6),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wrap Maze',
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                      letterSpacing: -0.5))
                              .animate()
                              .fadeIn()
                              .slideX(begin: -0.08),
                          Text('Sarmala · çöz · yarış',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          scheme.onSurface.withOpacity(0.45)))
                              .animate(delay: 80.ms)
                              .fadeIn(),
                        ],
                      ),
                    ),
                    // Streak badge
                    if (streak != null && streak.currentStreak > 0)
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StreakScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    const Color(0xFFEF4444).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text('${streak.currentStreak}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Menü',
                      onSelected: (value) async {
                        if (value == 'settings') {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()));
                        }
                        if (value == 'logout') {
                          await ref.read(authServiceProvider).signOut();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          enabled: false,
                          child: Text(
                            user?.displayName?.isNotEmpty == true
                                ? user!.displayName!
                                : 'Oyuncu',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined),
                              SizedBox(width: 10),
                              Text('Ayarlar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout_rounded),
                              SizedBox(width: 10),
                              Text('Çıkış yap'),
                            ],
                          ),
                        ),
                      ],
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          (user?.displayName?.isNotEmpty == true
                                  ? user!.displayName![0]
                                  : 'O')
                              .toUpperCase(),
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Özet kart ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _SummaryCard(
                    count: completedSet.length,
                    streak: streak?.currentStreak ?? 0),
              ),
            ),

            // ── Hızlı butonlar (2x3 grid) ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: [
                    _QuickBtn(
                      emoji: '∞',
                      label: 'Sonsuz',
                      color: const Color(0xFF0EA5E9).withOpacity(0.14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const GameScreen(level: 1, endless: true),
                        ),
                      ),
                    ),
                    _QuickBtn(
                        emoji: '📅',
                        label: 'Günlük',
                        color: scheme.primaryContainer,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DailyScreen()))),
                    _QuickBtn(
                        emoji: '⚔️',
                        label: 'Çok Oyunculu',
                        color: const Color(0xFFEF4444).withOpacity(0.15),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const MultiplayerLobbyScreen()))),
                    _QuickBtn(
                        emoji: '🔥',
                        label: 'Streak',
                        color: const Color(0xFFEA580C).withOpacity(0.15),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StreakScreen()))),
                    _QuickBtn(
                        emoji: '🏆',
                        label: 'Sıralama',
                        color: scheme.secondaryContainer,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen()))),
                    _QuickBtn(
                        emoji: '📱',
                        label: 'Yerel',
                        color: const Color(0xFF16A34A).withOpacity(0.1),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const OfflineLeaderboardScreen()))),
                    _QuickBtn(
                        emoji: '✏️',
                        label: 'Editör',
                        color: const Color(0xFF7C3AED).withOpacity(0.12),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EditorScreen()))),
                  ],
                ),
              ),
            ),

            // ── Premium banner (reklam yoksa) ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const IAPScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.secondary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Text('👑', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Premium\'a Geç',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onPrimary)),
                              Text('Temalar · İpuçları · Reklamsız',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          scheme.onPrimary.withOpacity(0.8))),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: scheme.onPrimary),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bölümler başlık ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Row(
                  children: [
                    Text('Bölümler',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                    const Spacer(),
                    Text('${completedSet.length} / 60',
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _WorldMap(completedSet: completedSet),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _WorldMap extends StatelessWidget {
  final Set<int> completedSet;

  const _WorldMap({required this.completedSet});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var row = 0; row < 12; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: row.isEven
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _MapNode(
                        level: row * 5 + i + 1,
                        completedSet: completedSet,
                        color: _zoneColor(row, scheme),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _zoneColor(int row, ColorScheme scheme) {
    if (row >= 10) return const Color(0xFFDC2626);
    if (row >= 8) return const Color(0xFF7C3AED);
    if (row >= 6) return const Color(0xFF0EA5E9);
    if (row >= 4) return const Color(0xFFF97316);
    return scheme.primary;
  }
}

class _MapNode extends StatelessWidget {
  final int level;
  final Set<int> completedSet;
  final Color color;

  const _MapNode({
    required this.level,
    required this.completedSet,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final completed = completedSet.contains(level);
    final locked = level > 1 && !completedSet.contains(level - 1);
    final boss = level % 10 == 0;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: locked
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GameScreen(level: level)),
              ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: boss ? 56 : 46,
        height: boss ? 56 : 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: locked
              ? scheme.surfaceContainerHighest
              : completed
                  ? color
                  : scheme.surface,
          border: Border.all(
            color: boss
                ? const Color(0xFFEF4444)
                : locked
                    ? scheme.outline.withOpacity(0.12)
                    : color.withOpacity(0.45),
            width: boss ? 3 : 1.5,
          ),
          boxShadow: [
            if (!locked)
              BoxShadow(
                color: color.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Center(
          child: locked
              ? Icon(Icons.lock_rounded,
                  size: 15, color: scheme.onSurface.withOpacity(0.25))
              : Text(
                  boss ? 'B$level' : '$level',
                  style: TextStyle(
                    fontSize: boss ? 12 : 13,
                    fontWeight: FontWeight.w900,
                    color: completed ? Colors.white : scheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int count;
  final int streak;
  const _SummaryCard({required this.count, required this.streak});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _Stat('Tamamlanan', '$count'),
          _div(),
          _Stat('Toplam', '60'),
          _div(),
          _Stat('Oran', '${(count / 60 * 100).round()}%'),
          _div(),
          _Stat('🔥 Seri', '$streak'),
        ],
      ),
    );
  }

  Widget _div() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.black12);
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.primary)),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: scheme.onSurface.withOpacity(0.45)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── Quick Button ─────────────────────────────────────────────────────────────

class _QuickBtn extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn(
      {required this.emoji,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Level Cell ───────────────────────────────────────────────────────────────
