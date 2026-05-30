import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/leaderboard_service.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sıralama'),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Genel'),
              Tab(text: 'Günlük'),
              Tab(text: 'Haftalık'),
              Tab(text: 'Aylık'),
              Tab(text: 'Sonsuz'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LevelLeaderboard(title: 'Genel Sıralama'),
            _LevelLeaderboard(
              title: 'Günlük Yarış',
              period: LeaderboardPeriod.daily,
            ),
            _LevelLeaderboard(
              title: 'Haftalık Yarış',
              period: LeaderboardPeriod.weekly,
            ),
            _LevelLeaderboard(
              title: 'Aylık Yarış',
              period: LeaderboardPeriod.monthly,
            ),
            _EndlessLeaderboard(),
          ],
        ),
      ),
    );
  }
}

class _LevelLeaderboard extends ConsumerWidget {
  final String title;
  final LeaderboardPeriod? period;

  const _LevelLeaderboard({required this.title, this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = period == null
        ? ref.watch(globalLeaderboardProvider)
        : ref.watch(periodLeaderboardProvider(period!));
    return scores.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              period == null
                  ? 'Henüz skor yok.'
                  : 'Bu dönem için henüz skor yok.',
            ),
          );
        }
        return _LeaderboardList(
          title: title,
          items: items
              .map(
                (item) => _RankItem(
                  displayName: item.displayName,
                  primary: 'Bölüm ${item.bestLevel}',
                  secondary: '${item.totalCompleted} tamamlandı',
                  trailing: '${item.lastMoves} hamle',
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _EndlessLeaderboard extends ConsumerWidget {
  const _EndlessLeaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(endlessLeaderboardProvider);
    return scores.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Sonsuz modda henüz skor yok.'));
        }
        return _LeaderboardList(
          title: 'Sonsuz Mod',
          items: items
              .map(
                (item) => _RankItem(
                  displayName: item.displayName,
                  primary: 'Seri ${item.bestStage}',
                  secondary: '${item.bestSeconds} saniye',
                  trailing: '${item.bestMoves} hamle',
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final String title;
  final List<_RankItem> items;

  const _LeaderboardList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final top = items.take(3).toList();
    final rest = items.skip(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _HeaderCard(title: title, count: items.length),
        const SizedBox(height: 16),
        if (top.isNotEmpty) _Podium(items: top),
        const SizedBox(height: 16),
        for (var i = 0; i < rest.length; i++) ...[
          _RankTile(rank: i + 4, item: rest[i]),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final int count;

  const _HeaderCard({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '$count oyuncu',
            style: TextStyle(
              color: scheme.onPrimaryContainer.withOpacity(0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<_RankItem> items;

  const _Podium({required this.items});

  @override
  Widget build(BuildContext context) {
    final ordered = <int>[1, 0, 2]
        .where((index) => index < items.length)
        .map((index) => (rank: index + 1, item: items[index]))
        .toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in ordered)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _PodiumCard(
                rank: entry.rank,
                item: entry.item,
                tall: entry.rank == 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final int rank;
  final _RankItem item;
  final bool tall;

  const _PodiumCard({
    required this.rank,
    required this.item,
    required this.tall,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (rank) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFF94A3B8),
      _ => const Color(0xFFB45309),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      height: tall ? 190 : 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.95), color.withOpacity(0.58)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            rank == 1
                ? Icons.workspace_premium_rounded
                : Icons.military_tech_rounded,
            color: Colors.white,
            size: rank == 1 ? 34 : 28,
          ),
          CircleAvatar(
            radius: rank == 1 ? 28 : 24,
            backgroundColor: Colors.white,
            child: Text(
              item.initial,
              style: TextStyle(
                color: scheme.primary,
                fontSize: rank == 1 ? 22 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            item.primary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final int rank;
  final _RankItem item;

  const _RankTile({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      tileColor: scheme.surfaceContainerHighest.withOpacity(0.52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          '$rank',
          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
        ),
      ),
      title: Text(
        item.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${item.primary} · ${item.secondary}'),
      trailing: Text(
        item.trailing,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RankItem {
  final String displayName;
  final String primary;
  final String secondary;
  final String trailing;

  const _RankItem({
    required this.displayName,
    required this.primary,
    required this.secondary,
    required this.trailing,
  });

  String get initial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}
