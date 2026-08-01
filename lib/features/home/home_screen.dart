// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/daily_quest_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/weekly_event_service.dart';
import '../daily/daily_screen.dart';
import '../editor/editor_screen.dart';
import '../game/game_provider.dart';
import '../game/game_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../leaderboard/offline_leaderboard_screen.dart';
import '../multiplayer/multiplayer_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../streak/streak_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final completedAsync = ref.watch(completedLevelsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final completed = completedAsync.valueOrNull ?? [];
    final completedSet = {for (final p in completed) p.levelNumber};
    final nextLevel = _nextPlayableLevel(completedSet);
    final streakAsync = ref.watch(streakDataProvider);
    final streak = streakAsync.valueOrNull;
    final questsAsync = ref.watch(dailyQuestSnapshotProvider);
    final weeklyAsync = ref.watch(weeklyEventSnapshotProvider);
    final screenSize = MediaQuery.sizeOf(context);
    final isTablet = screenSize.shortestSide >= 600;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 860 : double.infinity,
            ),
            child: CustomScrollView(
              key: UniqueKey(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 24,
                      isTablet ? 34 : 28,
                      isTablet ? 32 : 24,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('app_title'),
                                style: TextStyle(
                                  fontSize: isTablet ? 38 : 30,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ).animate().fadeIn().slideX(begin: -0.08),
                              Text(
                                l10n.t('tagline'),
                                style: TextStyle(
                                  fontSize: isTablet ? 17 : 14,
                                  color: scheme.onSurface.withOpacity(0.45),
                                ),
                              ).animate(delay: 80.ms).fadeIn(),
                            ],
                          ),
                        ),
                        // Streak badge
                        if (streak != null && streak.currentStreak > 0)
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StreakScreen(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEF4444,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${streak.currentStreak}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: l10n.t('menu'),
                          onSelected: (value) async {
                            if (value == 'settings') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            }
                            if (value == 'profile') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            }
                            if (value == 'logout') {
                              await ref
                                  .read(offlineModeProvider.notifier)
                                  .setOfflineMode(false);
                              await ref.read(authServiceProvider).signOut();
                              ref.invalidate(authStateProvider);
                              ref.invalidate(completedLevelsProvider);
                              ref.invalidate(streakDataProvider);
                              ref.invalidate(settingsProvider);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Text(
                                user?.displayName?.isNotEmpty == true
                                    ? user!.displayName!
                                    : l10n.t('local_player'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded),
                                  const SizedBox(width: 10),
                                  Text(l10n.isTr ? 'Profil' : 'Profile'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  const Icon(Icons.settings_outlined),
                                  const SizedBox(width: 10),
                                  Text(l10n.t('settings')),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  const Icon(Icons.logout_rounded),
                                  const SizedBox(width: 10),
                                  Text(l10n.t('logout')),
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

                // Summary card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 24,
                      16,
                      isTablet ? 32 : 24,
                      0,
                    ),
                    child: _SummaryCard(
                      count: completedSet.length,
                      streak: streak?.currentStreak ?? 0,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 24,
                      14,
                      isTablet ? 32 : 24,
                      0,
                    ),
                    child: _ContinueLevelButton(
                      level: nextLevel,
                      allDone: completedSet.length >= totalCampaignLevels,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 24,
                      14,
                      isTablet ? 32 : 24,
                      0,
                    ),
                    child: questsAsync.maybeWhen(
                      data: (snapshot) => _DailyQuestCard(snapshot: snapshot),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 24,
                      14,
                      isTablet ? 32 : 24,
                      0,
                    ),
                    child: weeklyAsync.maybeWhen(
                      data: (snapshot) => _WeeklyEventCard(snapshot: snapshot),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Quick buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 24,
                      18,
                      isTablet ? 32 : 24,
                      0,
                    ),
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: isTablet ? 14 : 10,
                      crossAxisSpacing: isTablet ? 14 : 10,
                      childAspectRatio: 1.1,
                      children: [
                        _QuickBtn(
                          icon: Icons.all_inclusive_rounded,
                          label: l10n.t('home_endless'),
                          color: const Color(0xFF0EA5E9).withOpacity(0.14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GameScreen(
                                level: 1,
                                endless: true,
                              ),
                            ),
                          ),
                        ),
                        _QuickBtn(
                          icon: Icons.sports_martial_arts_rounded,
                          label: l10n.t('home_multiplayer'),
                          color: const Color(0xFFEF4444).withOpacity(0.15),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MultiplayerLobbyScreen(),
                            ),
                          ),
                        ),
                        _QuickBtn(
                          icon: Icons.calendar_month_rounded,
                          label: l10n.t('home_daily'),
                          color: const Color(0xFF7C3AED).withOpacity(0.15),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DailyScreen(),
                            ),
                          ),
                        ),
                        _QuickBtn(
                          icon: Icons.local_fire_department_rounded,
                          label: l10n.t('home_streak'),
                          color: const Color(0xFFEA580C).withOpacity(0.15),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StreakScreen(),
                            ),
                          ),
                        ),
                        _QuickBtn(
                          icon: Icons.emoji_events_rounded,
                          label: l10n.t('home_leaderboard'),
                          color: scheme.secondaryContainer,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          ),
                        ),
                        _QuickBtn(
                          icon: Icons.phone_android_rounded,
                          label: l10n.t('home_local'),
                          color: const Color(0xFF16A34A).withOpacity(0.1),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OfflineLeaderboardScreen(),
                            ),
                          ),
                        ),
                        _QuickBtn(
                          icon: Icons.edit_rounded,
                          label: l10n.t('home_editor'),
                          color: const Color(0xFF7C3AED).withOpacity(0.12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditorScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Levels header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 24,
                      24,
                      isTablet ? 32 : 24,
                      12,
                    ),
                    child: Row(
                      children: [
                        Text(
                          l10n.t('levels'),
                          style: TextStyle(
                            fontSize: isTablet ? 22 : 17,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${completedSet.length} / $totalCampaignLevels',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _WorldMap(completedSet: completedSet),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _nextPlayableLevel(Set<int> completedSet) {
    for (var level = 1; level <= totalCampaignLevels; level++) {
      if (!completedSet.contains(level)) return level;
    }
    return totalCampaignLevels;
  }
}

class _ContinueLevelButton extends StatelessWidget {
  final int level;
  final bool allDone;

  const _ContinueLevelButton({
    required this.level,
    required this.allDone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameScreen(level: level)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone
                          ? l10n.t('all_levels_done')
                          : l10n.t('continue_level'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allDone
                          ? l10n.t('replay_final_level')
                          : l10n.level(level),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyQuestCard extends StatelessWidget {
  final DailyQuestSnapshot snapshot;

  const _DailyQuestCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final nextQuest = snapshot.quests.firstWhere(
      (quest) => !quest.claimed,
      orElse: () => snapshot.quests.last,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('daily_quests'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      l10n.isTr
                          ? '${snapshot.completedCount}/${snapshot.totalCount} tamamlandi'
                          : '${snapshot.completedCount}/${snapshot.totalCount} complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+${nextQuest.reward}',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final quest in snapshot.quests)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    quest.claimed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: quest.claimed
                        ? const Color(0xFF22C55E)
                        : scheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.isTr ? quest.titleTr : quest.titleEn,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: quest.ratio,
                            minHeight: 5,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              quest.claimed
                                  ? const Color(0xFF22C55E)
                                  : scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${quest.progress.clamp(0, quest.target)}/${quest.target}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeeklyEventCard extends StatelessWidget {
  final WeeklyEventSnapshot snapshot;

  const _WeeklyEventCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withOpacity(0.15),
            const Color(0xFF06B6D4).withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isTr ? snapshot.titleTr : snapshot.titleEn,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: snapshot.ratio,
                    minHeight: 7,
                    backgroundColor: scheme.surface.withOpacity(0.8),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${snapshot.progress.clamp(0, snapshot.target).toInt()}/${snapshot.target}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                snapshot.claimed ? 'OK' : '+${snapshot.reward}',
                style: TextStyle(
                  color: snapshot.claimed
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
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
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              for (var zone = 0; zone < totalCampaignLevels ~/ 10; zone++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ZoneBlock(
                    zone: zone,
                    completedSet: completedSet,
                    color: _zoneColor(zone, scheme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _zoneColor(int row, ColorScheme scheme) {
    if (row >= 8) return const Color(0xFFDC2626);
    if (row >= 6) return const Color(0xFF7C3AED);
    if (row >= 4) return const Color(0xFF0EA5E9);
    if (row >= 2) return const Color(0xFFF97316);
    return scheme.primary;
  }
}

class _ZoneBlock extends StatelessWidget {
  final int zone;
  final Set<int> completedSet;
  final Color color;

  const _ZoneBlock({
    required this.zone,
    required this.completedSet,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = zone * 10 + 1;
    final end = start + 9;
    final completedInZone = [
      for (var level = start; level <= end; level++)
        if (completedSet.contains(level)) level
    ].length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                _zoneName(context, zone),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$completedInZone/10',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 10,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final level = start + index;
              return Center(
                child: _MapNode(
                  level: level,
                  completedSet: completedSet,
                  color: color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _zoneName(BuildContext context, int zone) {
    final tr = context.l10n.isTr;
    final namesTr = [
      'Baslangic Vadisi',
      'Kristal Gecidi',
      'Kum Firtinasi',
      'Buz Rotasi',
      'Portal Sehri',
      'Tuzak Ormani',
      'Neon Kule',
      'Golge Labirenti',
      'Lav Arenasi',
      'Final Haritasi',
    ];
    final namesEn = [
      'Starter Valley',
      'Crystal Pass',
      'Sandstorm',
      'Ice Route',
      'Portal City',
      'Trap Forest',
      'Neon Tower',
      'Shadow Maze',
      'Lava Arena',
      'Final Map',
    ];
    final names = tr ? namesTr : namesEn;
    return names[zone.clamp(0, names.length - 1).toInt()];
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
    final nodeSize = boss ? 50.0 : 44.0;
    return GestureDetector(
      onTap: locked
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GameScreen(level: level)),
              ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: nodeSize,
        height: nodeSize,
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
              ? Icon(
                  Icons.lock_rounded,
                  size: 15,
                  color: scheme.onSurface.withOpacity(0.25),
                )
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

// Summary Card

class _SummaryCard extends StatelessWidget {
  final int count;
  final int streak;
  const _SummaryCard({required this.count, required this.streak});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _Stat(l10n.t('completed'), '$count'),
          _div(),
          _Stat(l10n.t('total'), '$totalCampaignLevels'),
          _div(),
          _Stat(
            l10n.t('rate'),
            '${(count / totalCampaignLevels * 100).round()}%',
          ),
          _div(),
          _Stat(l10n.t('series'), '$streak'),
        ],
      ),
    );
  }

  Widget _div() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.black12,
      );
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurface.withOpacity(0.45),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Quick Button

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 31),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Level Cell
