import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/database/progress_model.dart';
import '../../core/providers/isar_provider.dart';
import '../../core/services/auth_service.dart';

final completedLevelsProvider = StreamProvider<List<LevelProgress>>((ref) {
  final isar = ref.watch(isarProvider);
  final uid = ref.watch(currentUidProvider);
  return isar.levelProgress
      .filter()
      .uidEqualTo(uid)
      .sortByLevelNumber()
      .watch(fireImmediately: true);
});
