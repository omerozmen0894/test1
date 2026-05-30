// lib/core/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../database/progress_model.dart';
import '../models/theme_model.dart';
import '../services/auth_service.dart';
import 'isar_provider.dart';

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
    () => SettingsNotifier());

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final isar = ref.watch(isarProvider);
    final uid = ref.watch(currentUidProvider);
    return await isar.appSettings.filter().uidEqualTo(uid).findFirst() ??
        AppSettings.defaults(uid);
  }

  Future<void> _update(void Function(AppSettings s) fn) async {
    final isar = ref.read(isarProvider);
    final uid = ref.read(currentUidProvider);
    await isar.writeTxn(() async {
      final s = await isar.appSettings.filter().uidEqualTo(uid).findFirst() ??
          AppSettings.defaults(uid);
      fn(s);
      await isar.appSettings.put(s);
    });
    ref.invalidateSelf();
  }

  Future<void> setTheme(String id) => _update((s) => s.themeId = id);
  Future<void> setSoundEnabled(bool v) => _update((s) => s.soundEnabled = v);
  Future<void> setHapticsEnabled(bool v) =>
      _update((s) => s.hapticsEnabled = v);
  Future<void> setAdsRemoved(bool v) => _update((s) => s.adsRemoved = v);
  Future<void> setPremiumUnlocked(bool v) =>
      _update((s) => s.premiumUnlocked = v);
  Future<void> setDisplayName(String v) => _update((s) => s.displayName = v);
  Future<void> addHints(int n) =>
      _update((s) => s.totalHints = (s.totalHints) + n);
  Future<void> useHint() => _update((s) {
        if (s.totalHints > 0) s.totalHints--;
      });
}

final activeThemeProvider = Provider<MazeTheme>((ref) {
  final settings = ref.watch(settingsProvider);
  final value = settings.valueOrNull;
  final id = value?.themeId ?? 'classic';
  final theme = AppThemes.all
      .firstWhere((t) => t.id == id, orElse: () => AppThemes.classic);
  if (theme.isPremium && value?.premiumUnlocked != true) {
    return AppThemes.classic;
  }
  return theme;
});
