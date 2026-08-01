import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrap_maze/core/game_constants.dart';
import 'package:wrap_maze/core/maze_generator.dart';
import 'package:wrap_maze/core/providers/isar_provider.dart';
import 'package:wrap_maze/core/services/auth_service.dart';
import 'package:wrap_maze/features/game/game_provider.dart';

void main() {
  testWidgets('test harness is available', (WidgetTester tester) async {
    expect(tester, isNotNull);
  });

  test('campaign generates solvable levels', () {
    for (var level = 1; level <= totalCampaignLevels; level++) {
      final maze = MazeGenerator.generate(level);
      final solution = MazeSolver.solve(maze);

      expect(maze.size, inInclusiveRange(4, 10), reason: 'level $level');
      expect(solution, isNotNull, reason: 'level $level');
      expect(solution!.length, maze.totalCells, reason: 'level $level');
      expect(solution.first, maze.start, reason: 'level $level');
      expect(solution.last, maze.end, reason: 'level $level');
    }
  });

  test('completed levels are restored from device fallback', () async {
    SharedPreferences.setMockInitialValues({});

    await saveCompletedLevelFallback(uid: 'user-a', levelNumber: 7);
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(null),
        currentUidProvider.overrideWithValue('user-b'),
      ],
    );
    addTearDown(container.dispose);

    final restored = await container.read(completedLevelsProvider.future);

    expect(restored.map((p) => p.levelNumber), contains(7));
  });
}
