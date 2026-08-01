import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrap_maze/core/game_constants.dart';
import 'package:wrap_maze/core/maze_generator.dart';
import 'package:wrap_maze/core/providers/isar_provider.dart';
import 'package:wrap_maze/core/services/auth_service.dart';
import 'package:wrap_maze/core/services/daily_quest_service.dart';
import 'package:wrap_maze/core/services/wallet_service.dart';
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

  test('wallet keeps a device fallback balance', () async {
    SharedPreferences.setMockInitialValues({});
    final wallet = WalletService();

    await wallet.add('user-a', 40);

    expect(await wallet.balance('user-b'), 40);
    expect(await wallet.spend('user-b', 25), isTrue);
    expect(await wallet.balance('user-a'), 15);
  });

  test('daily quests grant rewards once', () async {
    SharedPreferences.setMockInitialValues({});
    final quests = DailyQuestService();

    final first = await quests.recordLevelWin(
      uid: 'local',
      stars: 3,
      noHint: true,
    );
    final second = await quests.recordLevelWin(
      uid: 'local',
      stars: 3,
      noHint: false,
    );
    final third = await quests.recordLevelWin(
      uid: 'local',
      stars: 3,
      noHint: false,
    );

    expect(first.coins, 25);
    expect(second.coins, 50);
    expect(third.coins, 0);
  });
}
