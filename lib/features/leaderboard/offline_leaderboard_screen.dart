// lib/features/leaderboard/offline_leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/progress_model.dart';
import '../../core/services/offline_leaderboard_service.dart';

final _offlineScoresProvider = FutureProvider<List<OfflineScore>>((ref) async {
  return ref.watch(offlineLeaderboardProvider).getTopScores();
});

class OfflineLeaderboardScreen extends ConsumerWidget {
  const OfflineLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(_offlineScoresProvider);
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
        title: const Text('📱 Yerel Sıralama',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Temizle',
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Açıklama
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İnternet olmadan da çalışır. Aynı cihazdaki tüm oyuncu kayıtları görünür.',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurface.withOpacity(0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Liste
          Expanded(
            child: scoresAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (scores) {
                if (scores.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Henüz kayıt yok',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500,
                                color: scheme.onSurface)),
                        Text('Bölümleri tamamla ve ilk sıraya gir!',
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: scores.length,
                  itemBuilder: (ctx, i) {
                    final score = scores[i];
                    final rank = i + 1;
                    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: rank <= 3
                              ? scheme.primary.withOpacity(0.3)
                              : scheme.outline.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: medal != null
                                ? Text(medal, style: const TextStyle(fontSize: 22))
                                : Text('#$rank',
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w600,
                                        color: scheme.onSurface.withOpacity(0.4))),
                          ),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 18, backgroundColor: scheme.primaryContainer,
                            child: Text(
                              score.displayName.isNotEmpty
                                  ? score.displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, color: scheme.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(score.displayName,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  DateFormat('d MMM, HH:mm', 'tr_TR')
                                      .format(score.recordedAt),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface.withOpacity(0.4)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${score.totalCompleted}',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700,
                                      color: scheme.primary)),
                              Text('bölüm',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSurface.withOpacity(0.4))),
                              const SizedBox(height: 2),
                              Text('🔥 ${score.bestStreak}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface.withOpacity(0.5))),
                            ],
                          ),
                        ],
                      ),
                    ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.05);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sıralamayı Temizle'),
        content: const Text('Tüm yerel kayıtlar silinecek. Emin misin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              await ref.read(offlineLeaderboardProvider).clearAll();
              ref.invalidate(_offlineScoresProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }
}
