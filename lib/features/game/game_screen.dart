import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/progress_model.dart';
import '../../core/maze_generator.dart';
import '../../core/models/maze_model.dart';
import '../../core/models/theme_model.dart';
import '../../core/providers/isar_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/leaderboard_service.dart';
import 'game_provider.dart';
import 'gesture_handler.dart';
import 'maze_painter.dart';

enum _LevelGoal { fillAll, keyExit, crystalOrder, noTrap, boss }

class GameScreen extends ConsumerStatefulWidget {
  final int level;
  final MazeConfig? maze;
  final bool endless;

  const GameScreen({
    super.key,
    required this.level,
    this.maze,
    this.endless = false,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  static const _tutorialKey = 'wrap_maze_tutorial_seen_v3';
  static const _coinsKey = 'wrap_maze_coins';

  late int _level;
  late GameState _state;
  late DateTime _startedAt;
  Timer? _pulseTimer;
  double _pulseValue = 0;
  bool _pulseForward = true;
  DateTime? _lastHapticAt;
  int _hintsLeft = 3;
  int _hintsUsed = 0;
  int _flowStreak = 0;
  int _coins = 0;
  int _shields = 1;
  int _rewindsLeft = 1;
  int _freezeCardsLeft = 1;
  int _cleanseCardsLeft = 1;
  bool _timeFrozen = false;
  int _bossPressure = 0;
  int _trapHits = 0;
  int _crystalIndex = 0;
  late _LevelGoal _goal;
  List<Cell> _crystalRoute = const [];
  Set<Cell> _bonusCells = const {};
  late String _levelFlavor;
  Timer? _ticker;
  int _elapsedSeconds = 0;
  Cell? _enemy;
  Set<Cell> _unstableCells = const {};
  Set<Cell> _rubbleCells = const {};
  Set<Cell> _trapCells = const {};
  Set<Cell> _timeBonusCells = const {};
  Cell? _blastCell;
  Set<Cell> _blastWaveCells = const {};
  Set<Cell> _keyCells = const {};
  Set<Cell> _gateCells = const {};
  bool _levelIntro = true;
  String? _feedbackText;
  Color _feedbackColor = const Color(0xFF7C3AED);
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _level = widget.level;
    _state = GameState.initial(widget.maze ?? MazeGenerator.generate(_level));
    _goal = _goalForLevel(_level);
    _levelFlavor = _flavorForLevel(_level);
    _bonusCells = _bonusCellsFor(_state.maze, _level);
    _unstableCells = _unstableCellsFor(_state.maze, _level);
    _rubbleCells = _rubbleCellsFor(_state.maze, _level);
    _trapCells = _trapCellsFor(_state.maze, _level);
    _crystalRoute = _crystalRouteFor(_state.maze, _level);
    _timeBonusCells = {
      ..._timeBonusCellsFor(_state.maze, _level),
      ..._crystalRoute,
    };
    _keyCells = _keyCellsFor(_state.maze, _level);
    _gateCells = _gateCellsFor(_state.maze, _level);
    _enemy = (_hasEnemy || _isBossLevel) ? _state.maze.end : null;
    _startedAt = DateTime.now();
    _startPulseTimer();
    _loadCoins();
    _startTicker();
    _playLevelIntro();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _showTutorialIfNeeded());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _feedbackTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _startPulseTimer() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 84), (_) {
      if (!mounted) return;
      setState(() {
        final next = _pulseValue + (_pulseForward ? 0.07 : -0.07);
        if (next >= 1) {
          _pulseValue = 1;
          _pulseForward = false;
        } else if (next <= 0) {
          _pulseValue = 0;
          _pulseForward = true;
        } else {
          _pulseValue = next;
        }
      });
    });
  }

  void _playLevelIntro() {
    setState(() => _levelIntro = true);
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _levelIntro = false);
    });
  }

  void _showFeedback(String text, Color color) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  void _tapHaptic() {
    final now = DateTime.now();
    final previous = _lastHapticAt;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 90)) {
      return;
    }
    _lastHapticAt = now;
    HapticFeedback.selectionClick();
  }

  void _startTicker() {
    _ticker?.cancel();
    _elapsedSeconds = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (!_timeFrozen) _elapsedSeconds++;
        if ((_hasEnemy || _isBossLevel) && _elapsedSeconds % 2 == 0) {
          _enemy = _nextEnemyStep();
        }
        if (_isBossLevel && !_timeFrozen && _elapsedSeconds % 4 == 0) {
          _bossPressure++;
          _levelFlavor = 'Boss yaklasiyor';
        }
      });
      if (_enemy == _state.head) {
        _handleEnemyCatch();
      }
    });
  }

  Future<void> _loadCoins() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = ref.read(currentUidProvider);
    if (!mounted) return;
    setState(() => _coins = prefs.getInt('${_coinsKey}_$uid') ?? 0);
  }

  bool get _hasEnemy => _level >= 4 && _level % 3 == 0;
  bool get _hasTimer => _level >= 4 && _level % 2 == 0;
  bool get _hasTraps => _level >= 5 && _level % 3 != 1;
  bool get _hasTimeBonus => _level >= 6 && _level % 2 == 0;
  bool get _isBossLevel => _level > 0 && _level % 10 == 0;

  int get _timeTarget {
    final base = _state.maze.totalCells * 2;
    final pressure = _isBossLevel ? 8 + _bossPressure : 0;
    return math.max(14, base - _level ~/ 2 - pressure);
  }

  int get _remainingSeconds => math.max(0, _timeTarget - _elapsedSeconds);

  _LevelGoal _goalForLevel(int level) {
    if (level > 0 && level % 10 == 0) return _LevelGoal.boss;
    if (level >= 8 && level % 5 == 0) return _LevelGoal.crystalOrder;
    if (level == 2 || (level >= 7 && level % 4 == 3)) {
      return _LevelGoal.keyExit;
    }
    if (level >= 6 && level % 3 == 2) return _LevelGoal.noTrap;
    return _LevelGoal.fillAll;
  }

  String get _goalTitle => switch (_goal) {
        _LevelGoal.keyExit => 'Anahtarlarla cikisa ulas',
        _LevelGoal.crystalOrder => 'Kristalleri sirayla topla',
        _LevelGoal.noTrap => 'Tuzaga basmadan bitir',
        _LevelGoal.boss => 'Boss baskisindan kac',
        _LevelGoal.fillAll => 'Tum kareleri boya',
      };

  String get _goalProgress => switch (_goal) {
        _LevelGoal.keyExit => '${_keyCells.length} anahtar kaldi',
        _LevelGoal.crystalOrder =>
          '$_crystalIndex/${_crystalRoute.length} kristal',
        _LevelGoal.noTrap => _trapHits == 0 ? 'Temiz rota' : '$_trapHits tuzak',
        _LevelGoal.boss => 'Baski $_bossPressure',
        _LevelGoal.fillAll => '${(_state.progressPercent * 100).round()}%',
      };

  String _flavorForLevel(int level) {
    if (level == 2) return 'Anahtarı Bul';
    if (level == 3) return 'İlk Bomba';
    if (level == 4) return 'Zamana Karşı';
    if (level >= 7 && level % 4 == 3) return 'Anahtar Kilidi';
    if (level >= 5 && level % 4 == 1) return 'Patlayan Kareler';
    if (level >= 4 && level % 3 == 0) return 'Takipten Kaç';
    if (level >= 3 && level % 2 == 0) return 'Zamana Karşı';
    if (level % 5 == 0) return 'Kristal Avı';
    if (level % 5 == 2) return 'Seri Bölümü';
    return 'Kusursuz Rota';
  }

  Set<Cell> _bonusCellsFor(MazeConfig maze, int level) {
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 8) return const {};
    final count = math.min(2 + level ~/ 6, 6);
    final step = math.max(2, solution.length ~/ (count + 1));
    return {
      for (var i = 1; i <= count; i++)
        solution[(i * step).clamp(1, solution.length - 2)]
    };
  }

  Set<Cell> _unstableCellsFor(MazeConfig maze, int level) {
    if (_goal == _LevelGoal.crystalOrder || _goal == _LevelGoal.keyExit) {
      return const {};
    }
    if (level != 3 && (level < 5 || level % 4 != 1)) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 12) return const {};
    final cells = {
      solution[(solution.length * 0.34).floor()],
      if (level != 3) solution[(solution.length * 0.68).floor()],
    };
    return cells
      ..remove(maze.start)
      ..remove(maze.end);
  }

  Set<Cell> _rubbleCellsFor(MazeConfig maze, int level) {
    if (_goal == _LevelGoal.crystalOrder || _goal == _LevelGoal.keyExit) {
      return const {};
    }
    if (level != 3 && (level < 5 || level % 4 != 1)) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 14) return const {};
    final blockers = <Cell>{};
    for (final bomb in _unstableCellsFor(maze, level)) {
      final index = solution.indexOf(bomb);
      if (index > 0 && index + 1 < solution.length - 1) {
        blockers.add(solution[index + 1]);
      }
      if (level >= 13 && index > 0 && index + 2 < solution.length - 1) {
        blockers.add(solution[index + 2]);
      }
    }
    return blockers
      ..remove(maze.start)
      ..remove(maze.end);
  }

  Set<Cell> _keyCellsFor(MazeConfig maze, int level) {
    if (_goal != _LevelGoal.keyExit) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 12) return const {};
    return {
      solution[(solution.length * 0.24).floor()],
      if (level >= 15 || _isBossLevel)
        solution[(solution.length * 0.46).floor()],
    }
      ..remove(maze.start)
      ..remove(maze.end);
  }

  Set<Cell> _gateCellsFor(MazeConfig maze, int level) {
    if (_goal != _LevelGoal.keyExit) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 12) return const {};
    return {
      solution[(solution.length * 0.62).floor()],
      if (level >= 15) solution[(solution.length * 0.78).floor()],
    }
      ..remove(maze.start)
      ..remove(maze.end);
  }

  Set<Cell> _trapCellsFor(MazeConfig maze, int level) {
    if (_goal == _LevelGoal.crystalOrder || _goal == _LevelGoal.keyExit) {
      return const {};
    }
    if (!_hasTraps) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 14) return const {};
    final count = math.min(1 + level ~/ 10, 4);
    return {
      for (var i = 0; i < count; i++)
        solution[((solution.length * (0.38 + i * 0.17)).floor())
            .clamp(2, solution.length - 3)]
    }
      ..remove(maze.start)
      ..remove(maze.end);
  }

  Set<Cell> _timeBonusCellsFor(MazeConfig maze, int level) {
    if (!_hasTimeBonus && _goal != _LevelGoal.crystalOrder) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 16) return const {};
    return {
      solution[(solution.length * 0.55).floor()],
      if (level >= 18) solution[(solution.length * 0.78).floor()],
    }
      ..remove(maze.start)
      ..remove(maze.end);
  }

  List<Cell> _crystalRouteFor(MazeConfig maze, int level) {
    if (_goal != _LevelGoal.crystalOrder) return const [];
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 16) return const [];
    final route = [
      solution[(solution.length * 0.28).floor()],
      solution[(solution.length * 0.55).floor()],
      solution[(solution.length * 0.76).floor()],
    ];
    return route
        .where((cell) => cell != maze.start && cell != maze.end)
        .toSet()
        .toList();
  }

  void _triggerBlast(Cell cell) {
    HapticFeedback.heavyImpact();
    final solution = MazeSolver.solve(_state.maze) ?? const <Cell>[];
    final blastWave = {
      cell,
      for (final d in Direction.values) cell.offset(d.dr, d.dc),
      cell.offset(-1, -1),
      cell.offset(-1, 1),
      cell.offset(1, -1),
      cell.offset(1, 1),
    }.where(_state.maze.isValid).toSet();
    var clearedRubble =
        _rubbleCells.where((c) => _distance(c, cell) <= 2).toSet();
    if (clearedRubble.isEmpty && _rubbleCells.isNotEmpty) {
      clearedRubble = {_rubbleCells.first};
    }
    final remaining = solution
        .where((c) => !_state.inPath(c) && c != _state.maze.end && c != cell)
        .toList();
    final shiftedBonuses = <Cell>{};
    for (var i = 0; i < math.min(3, remaining.length); i++) {
      shiftedBonuses.add(remaining[(i * 3 + _level) % remaining.length]);
    }
    setState(() {
      _blastCell = cell;
      _blastWaveCells = blastWave;
      _unstableCells = _unstableCells.difference({cell});
      _rubbleCells = _rubbleCells.difference(clearedRubble);
      _bonusCells = {..._bonusCells, ...shiftedBonuses};
      _shields = math.min(2, _shields + 1);
      _flowStreak += 2;
      _levelFlavor = clearedRubble.isEmpty ? 'Bomba patladı' : 'Yol açıldı!';
    });
    _showFeedback(
      clearedRubble.isEmpty ? 'BOMBA!' : 'YOL AÇILDI',
      const Color(0xFFF97316),
    );
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _blastCell == cell) {
        setState(() {
          _blastCell = null;
          _blastWaveCells = const {};
        });
      }
    });
  }

  void _handleEnemyCatch() {
    if ((!_hasEnemy && !_isBossLevel) ||
        _enemy != _state.head ||
        _state.isWon) {
      return;
    }
    HapticFeedback.heavyImpact();

    if (_shields > 0) {
      setState(() {
        _shields--;
        _flowStreak = 0;
        _enemy = _state.maze.end;
        _blastCell = _state.head;
        _levelFlavor = 'Kalkan kırıldı';
      });
      _showFeedback('KALKAN KIRILDI', const Color(0xFFEF4444));
    } else {
      final keepCount = math.max(1, _state.path.length - 3);
      setState(() {
        _state = _state.copyWith(
          path: _state.path.take(keepCount).toList(),
          moveCount: _state.moveCount + 1,
          hintPath: const [],
          history: const [],
        );
        _flowStreak = 0;
        _enemy = _state.maze.end;
        _blastCell = _state.head;
        _levelFlavor = 'Yakalandın!';
      });
      _showFeedback('YAKALANDIN', const Color(0xFFEF4444));
    }

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _blastCell = null);
    });
  }

  void _triggerTrap(Cell cell) {
    HapticFeedback.heavyImpact();
    final blockedByShield = _shields > 0;
    setState(() {
      _trapCells = _trapCells.difference({cell});
      _flowStreak = 0;
      _trapHits++;
      _blastCell = cell;
      if (blockedByShield) {
        _shields--;
        _levelFlavor = 'Tuzak kalkani kirdi';
      } else {
        final keepCount = math.max(1, _state.path.length - 2);
        _state = _state.copyWith(
          path: _state.path.take(keepCount).toList(),
          moveCount: _state.moveCount + 1,
          hintPath: const [],
        );
        _levelFlavor = 'Tuzak geri itti';
      }
    });
    _showFeedback(
      blockedByShield ? 'TUZAK!' : 'GERI ITILDIN',
      const Color(0xFFEF4444),
    );
    Future.delayed(const Duration(milliseconds: 520), () {
      if (mounted && _blastCell == cell) setState(() => _blastCell = null);
    });
  }

  Cell? _nextEnemyStep() {
    final enemy = _enemy ?? _state.maze.end;
    final options = Direction.values
        .map((d) => enemy.offset(d.dr, d.dc))
        .where((c) =>
            _state.maze.isValid(c) && (c == _state.head || !_state.inPath(c)))
        .toList();
    if (options.isEmpty) return enemy;
    options.sort((a, b) =>
        _distance(a, _state.head).compareTo(_distance(b, _state.head)));
    return options.first;
  }

  int _distance(Cell a, Cell b) =>
      (a.row - b.row).abs() + (a.col - b.col).abs();

  bool _canEnterExitEarly(Cell next) {
    if (next != _state.maze.end) return true;
    return false;
  }

  bool _objectiveComplete() {
    return switch (_goal) {
      _LevelGoal.keyExit => _keyCells.isEmpty,
      _LevelGoal.crystalOrder => _crystalIndex >= _crystalRoute.length,
      _LevelGoal.boss => _keyCells.isEmpty,
      _LevelGoal.noTrap || _LevelGoal.fillAll => true,
    };
  }

  bool _isGoalWin(GameState updated) {
    if (updated.head != updated.maze.end) return false;
    if (updated.path.length != updated.maze.totalCells) return false;
    return _objectiveComplete();
  }

  Future<void> _showTutorialIfNeeded() async {
    if (!mounted || widget.maze != null || _level != 1) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tutorialKey) ?? false) return;
    await prefs.setBool(_tutorialKey, true);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _TutorialSheet(),
    );
  }

  Future<void> _move(Direction direction) async {
    _tapHaptic();
    final next = _state.head.offset(direction.dr, direction.dc);
    if (_keyCells.isNotEmpty &&
        (_gateCells.contains(next) || next == _state.maze.end)) {
      HapticFeedback.lightImpact();
      setState(() {
        _flowStreak = 0;
        _levelFlavor = 'Önce anahtarı topla';
      });
      _showFeedback('ANAHTAR GEREKİYOR', const Color(0xFF0EA5E9));
      return;
    }
    if (next == _state.maze.end &&
        _state.path.length + 1 < _state.maze.totalCells &&
        !_canEnterExitEarly(next)) {
      HapticFeedback.lightImpact();
      setState(() {
        _flowStreak = 0;
        _levelFlavor = 'Hedef en son';
      });
      _showFeedback('HEDEF EN SON', const Color(0xFFF97316));
      return;
    }
    if (_rubbleCells.contains(next)) {
      HapticFeedback.lightImpact();
      setState(() {
        _flowStreak = 0;
        _levelFlavor = 'Önce bombayı patlat';
      });
      _showFeedback('BOMBA GEREKİYOR', const Color(0xFFF97316));
      return;
    }
    if (_goal == _LevelGoal.crystalOrder &&
        _crystalRoute.contains(next) &&
        _crystalRoute.indexOf(next) != _crystalIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _flowStreak = 0;
        _levelFlavor = 'Siradaki kristali bul';
      });
      _showFeedback('SIRA YANLIS', const Color(0xFF14B8A6));
      return;
    }
    final updated = _state.tryMove(next);
    if (updated == null) {
      HapticFeedback.lightImpact();
      setState(() => _flowStreak = 0);
      return;
    }

    final collectedBonus = _bonusCells.contains(updated.head);
    final collectedKey = _keyCells.contains(updated.head);
    final collectedTime = _timeBonusCells.contains(updated.head);
    final collectedCrystal = _goal == _LevelGoal.crystalOrder &&
        _crystalIndex < _crystalRoute.length &&
        updated.head == _crystalRoute[_crystalIndex];
    final hitTrap = _trapCells.contains(updated.head);
    setState(() {
      _flowStreak += collectedBonus || collectedKey || collectedCrystal ? 3 : 1;
      _state = updated.copyWith(hintPath: const []);
      _bonusCells = _bonusCells.difference({updated.head});
      _keyCells = _keyCells.difference({updated.head});
      _timeBonusCells = _timeBonusCells.difference({updated.head});
      if (collectedBonus) {
        _shields = math.min(2, _shields + 1);
        _levelFlavor = 'Kalkan kazandın';
      }
      if (collectedKey) {
        _levelFlavor =
            _keyCells.length <= 1 ? 'Kilit açıldı' : 'Anahtar toplandı';
      }
      if (collectedTime) {
        _elapsedSeconds = math.max(0, _elapsedSeconds - 6);
        _flowStreak += 2;
        if (!collectedCrystal) _levelFlavor = 'Zaman kristali';
      }
      if (collectedCrystal) {
        _crystalIndex++;
        _levelFlavor = _crystalIndex >= _crystalRoute.length
            ? 'Cikis acildi'
            : 'Siradaki kristal';
      }
    });
    if (collectedBonus || collectedKey || collectedTime || collectedCrystal) {
      HapticFeedback.mediumImpact();
      _showFeedback(
        collectedKey
            ? 'ANAHTAR!'
            : collectedCrystal
                ? 'KRISTAL!'
                : collectedTime
                    ? 'ZAMAN +6'
                    : 'KALKAN +1',
        collectedKey ? const Color(0xFF0EA5E9) : const Color(0xFF06B6D4),
      );
    }
    if (hitTrap && !_state.isWon) {
      _triggerTrap(updated.head);
    }
    if (_flowStreak > 0 && _flowStreak % 8 == 0) {
      HapticFeedback.selectionClick();
    }
    if (_unstableCells.contains(updated.head)) {
      _triggerBlast(updated.head);
    }
    _handleEnemyCatch();

    final won = _isGoalWin(_state);
    if (won) {
      HapticFeedback.mediumImpact();
      final winningState = _state.copyWith(isWon: true);
      await _saveWin(winningState.moveCount);
      if (!mounted) return;
      final usedHints = _hintsUsed;
      final stars = _starsForWin(winningState.moveCount, usedHints);
      final reward = _rewardForWin(stars, winningState.moveCount, usedHints);
      await _addCoins(reward);
      if (!mounted) return;
      final nextLevel = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.emoji_events_rounded, size: 42),
          title: const Text('Bölüm tamamlandı'),
          content: _WinSummary(
            moves: winningState.moveCount,
            stars: stars,
            reward: reward,
            coins: _coins,
            perfect: usedHints == 0 &&
                updated.moveCount == updated.maze.totalCells - 1,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Menü'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sonraki bölüm'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (nextLevel == true) {
        setState(() {
          _level++;
          _hintsLeft = 3;
          _hintsUsed = 0;
          _flowStreak = 0;
          _shields = 1;
          _rewindsLeft = 1;
          _freezeCardsLeft = 1;
          _cleanseCardsLeft = 1;
          _timeFrozen = false;
          _bossPressure = 0;
          _trapHits = 0;
          _crystalIndex = 0;
          _goal = _goalForLevel(_level);
          _state = GameState.initial(MazeGenerator.generate(_level));
          _levelFlavor = _flavorForLevel(_level);
          _bonusCells = _bonusCellsFor(_state.maze, _level);
          _unstableCells = _unstableCellsFor(_state.maze, _level);
          _rubbleCells = _rubbleCellsFor(_state.maze, _level);
          _trapCells = _trapCellsFor(_state.maze, _level);
          _crystalRoute = _crystalRouteFor(_state.maze, _level);
          _timeBonusCells = {
            ..._timeBonusCellsFor(_state.maze, _level),
            ..._crystalRoute,
          };
          _keyCells = _keyCellsFor(_state.maze, _level);
          _gateCells = _gateCellsFor(_state.maze, _level);
          _blastCell = null;
          _blastWaveCells = const {};
          _enemy = (_hasEnemy || _isBossLevel) ? _state.maze.end : null;
          _startTicker();
          _startedAt = DateTime.now();
        });
        _playLevelIntro();
      } else {
        Navigator.pop(context);
      }
    }
  }

  int _starsForWin(int moves, int usedHints) {
    final perfectMoves = _state.maze.totalCells - 1;
    if (_goal == _LevelGoal.noTrap && _trapHits > 0) return 1;
    if (_goal == _LevelGoal.boss && _bossPressure > 4) return 1;
    if (usedHints == 0 && moves <= perfectMoves) return 3;
    if (usedHints <= 1 && moves <= perfectMoves + 4) return 2;
    return 1;
  }

  int _rewardForWin(int stars, int moves, int usedHints) {
    final perfectMoves = _state.maze.totalCells - 1;
    final perfectBonus = usedHints == 0 && moves <= perfectMoves ? 15 : 0;
    final noHintBonus = usedHints == 0 ? 10 : 0;
    final comboBonus = math.min(_flowStreak ~/ 8 * 2, 12);
    return stars * 10 + perfectBonus + noHintBonus + comboBonus;
  }

  Future<void> _addCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = ref.read(currentUidProvider);
    final key = '${_coinsKey}_$uid';
    final nextCoins = (prefs.getInt(key) ?? _coins) + amount;
    await prefs.setInt(key, nextCoins);
    if (mounted) setState(() => _coins = nextCoins);
  }

  void _useHint() {
    final settings = ref.read(settingsProvider).valueOrNull;
    final premiumUnlocked = settings?.premiumUnlocked == true;
    final totalHints = settings?.totalHints ?? 0;
    if (!premiumUnlocked && _hintsLeft <= 0 && totalHints <= 0) {
      HapticFeedback.lightImpact();
      return;
    }
    final hintPath = _solutionHintPath();
    if (hintPath == null) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    final spendGlobalHint =
        !premiumUnlocked && _hintsLeft <= 0 && totalHints > 0;
    setState(() {
      if (!premiumUnlocked) {
        if (_hintsLeft > 0) {
          _hintsLeft--;
        }
      }
      _hintsUsed++;
      _state = _state.copyWith(hintPath: hintPath);
    });
    if (spendGlobalHint) {
      unawaited(ref.read(settingsProvider.notifier).useHint());
    }
  }

  void _useRewindCard() {
    if (_rewindsLeft <= 0) return;
    final previous = _state.undo();
    if (previous == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _rewindsLeft--;
      _state = previous;
      _flowStreak = 0;
      _levelFlavor = 'Geri sarildi';
    });
    _showFeedback('GERI SAR', const Color(0xFF7C3AED));
  }

  void _useFreezeCard() {
    if (_freezeCardsLeft <= 0 || _timeFrozen) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _freezeCardsLeft--;
      _timeFrozen = true;
      _levelFlavor = 'Zaman durdu';
    });
    _showFeedback('ZAMAN DURDU', const Color(0xFF14B8A6));
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _timeFrozen = false);
    });
  }

  void _useCleanseCard() {
    if (_cleanseCardsLeft <= 0) return;
    final removed = _trapCells.take(2).toSet();
    if (removed.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _cleanseCardsLeft--;
      _trapCells = _trapCells.difference(removed);
      _levelFlavor = 'Tuzak temizlendi';
    });
    _showFeedback('TUZAK TEMIZ', const Color(0xFF16A34A));
  }

  List<Cell>? _solutionHintPath() {
    final visited = _state.path.toSet();
    final path = [..._state.path];
    final deadline = DateTime.now().add(const Duration(milliseconds: 600));

    bool lockedFor(Cell next, Set<Cell> seen) {
      final keysStillAhead = _keyCells.any((key) => !seen.contains(key));
      return keysStillAhead &&
          (_gateCells.contains(next) || next == _state.maze.end);
    }

    bool dfs(Cell current) {
      if (DateTime.now().isAfter(deadline)) return false;
      if (path.length == _state.maze.totalCells) {
        return current == _state.maze.end;
      }

      final nextCells = Direction.values
          .map((d) => current.offset(d.dr, d.dc))
          .where((next) =>
              _state.maze.isValid(next) &&
              !_rubbleCells.contains(next) &&
              !lockedFor(next, visited) &&
              !visited.contains(next))
          .toList()
        ..sort((a, b) =>
            _onwardMoves(a, visited).compareTo(_onwardMoves(b, visited)));

      for (final next in nextCells) {
        final wouldFinish = path.length + 1 == _state.maze.totalCells;
        if (next == _state.maze.end && !wouldFinish) continue;
        visited.add(next);
        path.add(next);
        if (dfs(next)) return true;
        path.removeLast();
        visited.remove(next);
      }
      return false;
    }

    if (dfs(_state.head)) return [...path];

    final fallback = Direction.values
        .map((d) => _state.head.offset(d.dr, d.dc))
        .where((next) =>
            _state.maze.isValid(next) &&
            !_rubbleCells.contains(next) &&
            !lockedFor(next, visited) &&
            !visited.contains(next))
        .toList();
    if (fallback.isEmpty) return null;
    return [..._state.path, fallback.first];
  }

  int _onwardMoves(Cell cell, Set<Cell> visited) {
    return Direction.values
        .map((d) => cell.offset(d.dr, d.dc))
        .where((next) =>
            _state.maze.isValid(next) &&
            !_rubbleCells.contains(next) &&
            !(_keyCells.any((key) => !visited.contains(key)) &&
                _gateCells.contains(next)) &&
            !visited.contains(next))
        .length;
  }

  Future<void> _saveWin(int moves) async {
    if (widget.endless) {
      final seconds = DateTime.now().difference(_startedAt).inSeconds;
      unawaited(ref.read(leaderboardServiceProvider).submitEndlessScore(
            stage: _level,
            moves: moves,
            seconds: seconds,
          ));
      return;
    }
    if (_state.maze.isCustom || _state.maze.isDaily) return;
    final seconds = DateTime.now().difference(_startedAt).inSeconds;
    final isar = ref.read(isarProvider);
    final uid = ref.read(currentUidProvider);
    await isar.writeTxn(() async {
      final existing = await isar.levelProgress
          .filter()
          .uidEqualTo(uid)
          .levelNumberEqualTo(_level)
          .findFirst();
      final record = existing ??
          LevelProgress.create(uid: uid, levelNumber: _level, moves: moves);
      record
        ..completed = true
        ..bestMoves = existing == null
            ? moves
            : (moves < existing.bestMoves ? moves : existing.bestMoves)
        ..playCount = (existing?.playCount ?? 0) + 1
        ..completedAt = DateTime.now();
      await isar.levelProgress.put(record);
    });
    ref.invalidate(completedLevelsProvider);
    unawaited(ref.read(leaderboardServiceProvider).submitLevelScore(
          level: _level,
          moves: moves,
          seconds: seconds,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(activeThemeProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (_state.progressPercent * 100).round();
    final visibleHints = settings?.premiumUnlocked == true
        ? 99
        : _hintsLeft + (settings?.totalHints ?? 0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.endless ? 'Sonsuz $_level' : 'Bölüm $_level'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Geri al',
            onPressed: () {
              final previous = _state.undo();
              if (previous != null) setState(() => _state = previous);
            },
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Nasıl oynanır?',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => const _TutorialSheet(),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF111827), Color(0xFF020617)]
                  : const [Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _MissionPanel(
                    key: ValueKey('$_levelFlavor-$progress-$_flowStreak'),
                    moves: _state.moveCount,
                    progress: progress,
                    goalTitle: _goalTitle,
                    goalProgress: _goalProgress,
                    hintsLeft: visibleHints,
                    flowStreak: _flowStreak,
                    shields: _shields,
                    keysLeft: _keyCells.length,
                    rewindCards: _rewindsLeft,
                    freezeCards: _freezeCardsLeft,
                    cleanseCards: _cleanseCardsLeft,
                    flavor: _levelFlavor,
                    remainingSeconds: _hasTimer ? _remainingSeconds : null,
                    enemyActive: _hasEnemy || _isBossLevel,
                    onHint: _useHint,
                    onRewind: _useRewindCard,
                    onFreeze: _useFreezeCard,
                    onCleanse: _useCleanseCard,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final side = math
                              .min(constraints.maxWidth, constraints.maxHeight)
                              .clamp(190.0, 560.0)
                              .toDouble();
                          return MazeGestureHandler(
                            onMove: _move,
                            child: AnimatedScale(
                              scale: _levelIntro ? 0.94 : 1,
                              duration: const Duration(milliseconds: 360),
                              curve: Curves.easeOutBack,
                              child: AnimatedOpacity(
                                opacity: _levelIntro ? 0.2 : 1,
                                duration: const Duration(milliseconds: 260),
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    size: Size(side, side),
                                    isComplex: true,
                                    willChange: true,
                                    painter: MazePainter(
                                      gameState: _state,
                                      theme: theme,
                                      isDark: isDark,
                                      pulse: _pulseValue,
                                      bonusCells: _bonusCells,
                                      enemy: _enemy,
                                      unstableCells: _unstableCells,
                                      rubbleCells: _rubbleCells,
                                      trapCells: _trapCells,
                                      timeBonusCells: _timeBonusCells,
                                      blastCell: _blastCell,
                                      blastWaveCells: _blastWaveCells,
                                      keyCells: _keyCells,
                                      gateCells: _gateCells,
                                      gatesLocked: _keyCells.isNotEmpty,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      child: _FeedbackBurst(
                        text: _feedbackText,
                        color: _feedbackColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: _DPad(onMove: _move),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Text(
                  'Tüm açık kareleri dolaş. Turuncu HEDEF karesine en son ulaş.',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.64),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBurst extends StatelessWidget {
  final String? text;
  final Color color;

  const _FeedbackBurst({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          );
          return ScaleTransition(
            scale: curved,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: text == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(text),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  text!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
      ),
    );
  }
}

class _MissionPanel extends StatelessWidget {
  final int moves;
  final int progress;
  final String goalTitle;
  final String goalProgress;
  final int hintsLeft;
  final int flowStreak;
  final int shields;
  final int keysLeft;
  final int rewindCards;
  final int freezeCards;
  final int cleanseCards;
  final String flavor;
  final int? remainingSeconds;
  final bool enemyActive;
  final VoidCallback onHint;
  final VoidCallback onRewind;
  final VoidCallback onFreeze;
  final VoidCallback onCleanse;

  const _MissionPanel({
    super.key,
    required this.moves,
    required this.progress,
    required this.goalTitle,
    required this.goalProgress,
    required this.hintsLeft,
    required this.flowStreak,
    required this.shields,
    required this.keysLeft,
    required this.rewindCards,
    required this.freezeCards,
    required this.cleanseCards,
    required this.flavor,
    required this.remainingSeconds,
    required this.enemyActive,
    required this.onHint,
    required this.onRewind,
    required this.onFreeze,
    required this.onCleanse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                enemyActive
                    ? Icons.warning_amber_rounded
                    : remainingSeconds != null
                        ? Icons.timer_rounded
                        : Icons.auto_awesome_rounded,
                size: 18,
                color: enemyActive ? const Color(0xFFEF4444) : scheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  flavor,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (remainingSeconds != null)
                Text(
                  '${remainingSeconds}s',
                  style: TextStyle(
                    color: remainingSeconds! <= 8
                        ? const Color(0xFFEF4444)
                        : scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  goalTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                goalProgress,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withOpacity(0.68),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Stat(label: 'Hamle', value: '$moves'),
              _Stat(label: 'İlerleme', value: '$progress%'),
              _Stat(label: 'Seri', value: 'x$flowStreak'),
              _ShieldPill(count: shields),
              if (keysLeft > 0) _KeyPill(count: keysLeft),
              const _TargetBadge(),
              _HintPill(count: hintsLeft, onTap: onHint),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CardPill(
                icon: Icons.replay_rounded,
                label: 'Geri',
                count: rewindCards,
                onTap: onRewind,
              ),
              _CardPill(
                icon: Icons.ac_unit_rounded,
                label: 'Dondur',
                count: freezeCards,
                onTap: onFreeze,
              ),
              _CardPill(
                icon: Icons.cleaning_services_rounded,
                label: 'Temizle',
                count: cleanseCards,
                onTap: onCleanse,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF97316)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WinSummary extends StatelessWidget {
  final int moves;
  final int stars;
  final int reward;
  final int coins;
  final bool perfect;

  const _WinSummary({
    required this.moves,
    required this.stars,
    required this.reward,
    required this.coins,
    required this.perfect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 34,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('$moves hamle',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Text('+$reward jeton  ·  Toplam $coins'),
              ],
            ),
          ),
          if (perfect) ...[
            const SizedBox(height: 8),
            Text(
              'Kusursuz rota bonusu!',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            stars == 3
                ? 'Harika. Bir sonraki bölüm biraz daha çetin.'
                : 'Devam et; yıldızları topladıkça jeton kazanırsın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurface.withOpacity(0.68)),
          ),
        ],
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _HintPill({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Material(
            color: count > 0
                ? const Color(0xFFFFF7D6)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color:
                          count > 0 ? const Color(0xFFF59E0B) : scheme.outline,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: count > 0
                            ? const Color(0xFF92400E)
                            : scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'İpucu',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldPill extends StatelessWidget {
  final int count;

  const _ShieldPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = count > 0;
    return Expanded(
      child: Column(
        children: [
          Icon(
            active ? Icons.shield_rounded : Icons.shield_outlined,
            size: 22,
            color: active ? const Color(0xFF06B6D4) : scheme.outline,
          ),
          const SizedBox(height: 2),
          Text(
            'x$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: active ? const Color(0xFF0E7490) : scheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _CardPill({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = count > 0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: enabled
              ? scheme.primaryContainer.withOpacity(0.7)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: enabled ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$label x$count',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: enabled ? scheme.primary : scheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyPill extends StatelessWidget {
  final int count;

  const _KeyPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          const Icon(
            Icons.key_rounded,
            size: 22,
            color: Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 2),
          Text(
            'x$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0369A1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetBadge extends StatelessWidget {
  const _TargetBadge();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD166), width: 4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Hedef',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  final ValueChanged<Direction> onMove;

  const _DPad({required this.onMove});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MoveButton(
            icon: Icons.keyboard_arrow_up_rounded,
            onTap: () => onMove(Direction.up)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MoveButton(
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: () => onMove(Direction.left)),
            const SizedBox(width: 48),
            _MoveButton(
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: () => onMove(Direction.right)),
          ],
        ),
        _MoveButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => onMove(Direction.down)),
      ],
    );
  }
}

class _MoveButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MoveButton({required this.icon, required this.onTap});

  @override
  State<_MoveButton> createState() => _MoveButtonState();
}

class _MoveButtonState extends State<_MoveButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _pressed = true);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 70),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            width: 86,
            height: 68,
            decoration: BoxDecoration(
              color: _pressed ? scheme.primary : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.primary.withOpacity(_pressed ? 0.35 : 0.12),
              ),
              boxShadow: [
                if (!_pressed)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Icon(
              widget.icon,
              size: 46,
              color: _pressed ? scheme.onPrimary : scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialSheet extends StatelessWidget {
  const _TutorialSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nasıl oynanır?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            const _TutorialDemo(),
            const SizedBox(height: 12),
            const _TutorialLine(
              icon: Icons.grid_on_rounded,
              title: 'Her açık kareden geç',
              text: 'Boş karelerin tamamını tek rota halinde dolaş.',
            ),
            const _TutorialLine(
              icon: Icons.flag_rounded,
              title: 'Turuncu HEDEF en son',
              text:
                  'Hedefe erken girersen bölüm bitmez. Önce tüm alanı doldur.',
            ),
            const _TutorialLine(
              icon: Icons.touch_app_rounded,
              title: 'Kaydır veya yön tuşlarını kullan',
              text:
                  'Alttaki büyük tuşların tamamı basılabilir alan; kaydırma da çalışır.',
            ),
            const _TutorialLine(
              icon: Icons.lightbulb_rounded,
              title: 'İpucu jokeri',
              text:
                  'Başlangıçta 3 ipucun var. İpucu önerilen kareyi sarı gösterir.',
            ),
            const _TutorialLine(
              icon: Icons.shield_rounded,
              title: 'Kalkan ve takip',
              text:
                  'Kirmizi takipci yakalarsa once kalkanin kirilir. Kalkansiz yakalanirsan birkac adim geri savrulursun.',
            ),
            const _TutorialLine(
              icon: Icons.warning_amber_rounded,
              title: 'Catlak karelere dikkat',
              text:
                  'Catlak kareler patlayip bolumun ritmini degistirir. Yildizlar ekstra kalkan kazandirabilir.',
            ),
            const _TutorialLine(
              icon: Icons.key_rounded,
              title: 'Anahtarli kilitler',
              text:
                  'Mavi kilitli karelere ve hedefe girmeden once anahtarlari toplaman gerekir.',
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Başla'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialDemo extends StatefulWidget {
  const _TutorialDemo();

  @override
  State<_TutorialDemo> createState() => _TutorialDemoState();
}

class _TutorialDemoState extends State<_TutorialDemo> {
  static const _maze = MazeConfig(
    size: 4,
    start: Cell(0, 0),
    end: Cell(3, 0),
    walls: [],
    levelNumber: 0,
  );

  static const _route = [
    Cell(0, 0),
    Cell(0, 1),
    Cell(0, 2),
    Cell(0, 3),
    Cell(1, 3),
    Cell(1, 2),
    Cell(1, 1),
    Cell(1, 0),
    Cell(2, 0),
    Cell(2, 1),
    Cell(2, 2),
    Cell(2, 3),
    Cell(3, 3),
    Cell(3, 2),
    Cell(3, 1),
    Cell(3, 0),
  ];

  Timer? _timer;
  var _step = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _step = _step >= _route.length ? 1 : _step + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = GameState(
      maze: _maze,
      path: _route.take(_step).toList(),
      moveCount: _step - 1,
      isWon: _step == _route.length,
      history: const [],
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SizedBox(
        width: 190,
        height: 190,
        child: CustomPaint(
          painter: MazePainter(
            gameState: state,
            theme: AppThemes.classic,
            isDark: isDark,
            pulse: _step / _route.length,
          ),
        ),
      ),
    );
  }
}

class _TutorialLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _TutorialLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(text,
                    style:
                        TextStyle(color: scheme.onSurface.withOpacity(0.65))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

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
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}
