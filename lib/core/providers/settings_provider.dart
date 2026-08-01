// lib/core/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/progress_model.dart';
import '../models/theme_model.dart';
import '../services/auth_service.dart';
import 'isar_provider.dart';

const _settingsPrefsPrefix = 'wrapMaze.settings.v1';

String _settingsKey(String uid, String field) =>
    '$_settingsPrefsPrefix.$uid.$field';

Future<AppSettings> _loadSettingsFallback(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings.defaults(uid)
    ..themeId = prefs.getString(_settingsKey(uid, 'themeId')) ?? 'classic'
    ..soundEnabled = prefs.getBool(_settingsKey(uid, 'soundEnabled')) ?? true
    ..hapticsEnabled =
        prefs.getBool(_settingsKey(uid, 'hapticsEnabled')) ?? true
    ..adsRemoved = prefs.getBool(_settingsKey(uid, 'adsRemoved')) ?? false
    ..premiumUnlocked =
        prefs.getBool(_settingsKey(uid, 'premiumUnlocked')) ?? false
    ..displayName =
        prefs.getString(_settingsKey(uid, 'displayName')) ?? 'Oyuncu'
    ..totalHints = prefs.getInt(_settingsKey(uid, 'totalHints')) ?? 3;
}

Future<void> _saveSettingsFallback(AppSettings settings) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = settings.uid;
  await Future.wait([
    prefs.setString(_settingsKey(uid, 'themeId'), settings.themeId),
    prefs.setBool(_settingsKey(uid, 'soundEnabled'), settings.soundEnabled),
    prefs.setBool(_settingsKey(uid, 'hapticsEnabled'), settings.hapticsEnabled),
    prefs.setBool(_settingsKey(uid, 'adsRemoved'), settings.adsRemoved),
    prefs.setBool(
        _settingsKey(uid, 'premiumUnlocked'), settings.premiumUnlocked),
    prefs.setString(_settingsKey(uid, 'displayName'), settings.displayName),
    prefs.setInt(_settingsKey(uid, 'totalHints'), settings.totalHints),
  ]);
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
    () => SettingsNotifier());

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final isar = ref.watch(isarProvider);
    final uid = ref.watch(currentUidProvider);
    if (isar == null) return _loadSettingsFallback(uid);
    return await isar.appSettings.filter().uidEqualTo(uid).findFirst() ??
        AppSettings.defaults(uid);
  }

  Future<void> _update(void Function(AppSettings s) fn) async {
    final isar = ref.read(isarProvider);
    final uid = ref.read(currentUidProvider);
    if (isar == null) {
      final s = state.valueOrNull ?? await _loadSettingsFallback(uid);
      fn(s);
      await _saveSettingsFallback(s);
      state = AsyncData(s);
      return;
    }
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
