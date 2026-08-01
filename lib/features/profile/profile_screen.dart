import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/daily_quest_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/wallet_service.dart';
import '../../core/services/weekly_event_service.dart';
import '../game/game_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final completed =
        ref.watch(completedLevelsProvider).valueOrNull ?? const [];
    final streak = ref.watch(streakDataProvider).valueOrNull;
    final coins = ref.watch(coinBalanceProvider).valueOrNull ?? 0;
    final daily = ref.watch(dailyQuestSnapshotProvider).valueOrNull;
    final weekly = ref.watch(weeklyEventSnapshotProvider).valueOrNull;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : settings?.displayName ?? l10n.t('local_player');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.isTr ? 'Profil' : 'Profile'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.primary.withOpacity(0.16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primary,
                  child: Text(
                    (name.isEmpty ? '?' : name[0]).toUpperCase(),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.isAnonymous == true
                            ? l10n.t('guest_account')
                            : user?.email ?? l10n.t('offline_note'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.58),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _ProfileStat(
                icon: Icons.flag_rounded,
                label: l10n.t('completed'),
                value: '${completed.length} / $totalCampaignLevels',
              ),
              _ProfileStat(
                icon: Icons.monetization_on_rounded,
                label: l10n.isTr ? 'Jeton' : 'Coins',
                value: '$coins',
              ),
              _ProfileStat(
                icon: Icons.local_fire_department_rounded,
                label: l10n.t('series'),
                value: '${streak?.currentStreak ?? 0}',
              ),
              _ProfileStat(
                icon: Icons.percent_rounded,
                label: l10n.t('rate'),
                value:
                    '${(completed.length / totalCampaignLevels * 100).round()}%',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (daily != null)
            _ProgressCard(
              icon: Icons.task_alt_rounded,
              title: l10n.t('daily_quests'),
              subtitle: l10n.isTr
                  ? '${daily.completedCount}/${daily.totalCount} tamamlandi'
                  : '${daily.completedCount}/${daily.totalCount} complete',
              ratio: daily.completedCount / daily.totalCount,
              reward: daily.quests.fold<int>(0, (sum, q) => sum + q.reward),
            ),
          if (weekly != null) ...[
            const SizedBox(height: 10),
            _ProgressCard(
              icon: Icons.event_available_rounded,
              title: l10n.isTr ? weekly.titleTr : weekly.titleEn,
              subtitle:
                  '${weekly.progress.clamp(0, weekly.target).toInt()} / ${weekly.target}',
              ratio: weekly.ratio,
              reward: weekly.reward,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: scheme.primary),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurface.withOpacity(0.58)),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double ratio;
  final int reward;

  const _ProgressCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ratio,
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                      subtitle,
                      style:
                          TextStyle(color: scheme.onSurface.withOpacity(0.58)),
                    ),
                  ],
                ),
              ),
              Text(
                '+$reward',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
