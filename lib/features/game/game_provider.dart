import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/progress_model.dart';
import '../../core/providers/isar_provider.dart';
import '../../core/services/auth_service.dart';

const _completedLevelsPrefsPrefix = 'wrapMaze.completedLevels.v1';
const _deviceCompletedLevelsPrefsKey = 'wrapMaze.completedLevels.device.v1';

String _completedLevelsKey(String uid) => '$_completedLevelsPrefsPrefix.$uid';

List<int> _parseCompletedLevels(List<String> raw) {
  final levels = raw
      .map(int.tryParse)
      .whereType<int>()
      .where((level) => level > 0)
      .toSet()
      .toList()
    ..sort();
  return levels;
}

Future<List<int>> _loadCompletedLevelNumbers(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  final userLevels = _parseCompletedLevels(
    prefs.getStringList(_completedLevelsKey(uid)) ?? const [],
  );
  final deviceLevels = _parseCompletedLevels(
    prefs.getStringList(_deviceCompletedLevelsPrefsKey) ?? const [],
  );
  final levels = {...userLevels, ...deviceLevels}.toList()..sort();
  return levels;
}

Future<void> saveCompletedLevelFallback({
  required String uid,
  required int levelNumber,
}) async {
  if (levelNumber <= 0) return;
  final prefs = await SharedPreferences.getInstance();
  final levels = (await _loadCompletedLevelNumbers(uid)).toSet()
    ..add(levelNumber);
  final values = levels.toList()..sort();
  final encoded = values.map((level) => level.toString()).toList();
  await Future.wait([
    prefs.setStringList(_completedLevelsKey(uid), encoded),
    prefs.setStringList(_deviceCompletedLevelsPrefsKey, encoded),
  ]);
}

Future<void> deleteCompletedLevelFallback(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_completedLevelsKey(uid));
}

Future<void> deleteAllCompletedLevelFallback() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs
      .getKeys()
      .where((key) =>
          key.startsWith('$_completedLevelsPrefsPrefix.') ||
          key == _deviceCompletedLevelsPrefsKey)
      .toList();
  for (final key in keys) {
    await prefs.remove(key);
  }
}

LevelProgress _fallbackProgress(String uid, int levelNumber) {
  return LevelProgress.create(uid: uid, levelNumber: levelNumber, moves: 0);
}

List<LevelProgress> _mergeProgress(
  String uid,
  List<LevelProgress> stored,
  List<int> fallbackLevels,
) {
  final byLevel = <int, LevelProgress>{
    for (final progress in stored) progress.levelNumber: progress,
  };
  for (final level in fallbackLevels) {
    byLevel.putIfAbsent(level, () => _fallbackProgress(uid, level));
  }
  return byLevel.values.toList()
    ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
}

final completedLevelsProvider =
    StreamProvider<List<LevelProgress>>((ref) async* {
  final isar = ref.watch(isarProvider);
  final uid = ref.watch(currentUidProvider);
  final fallbackLevels = await _loadCompletedLevelNumbers(uid);
  if (isar == null) {
    yield _mergeProgress(uid, const [], fallbackLevels);
    return;
  }
  await for (final stored in isar.levelProgress
      .filter()
      .uidEqualTo(uid)
      .sortByLevelNumber()
      .watch(fireImmediately: true)) {
    yield _mergeProgress(uid, stored, fallbackLevels);
  }
});
