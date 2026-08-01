import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/progress_model.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/maze_generator.dart';
import '../../core/models/maze_model.dart';
import '../../core/models/theme_model.dart';
import '../../core/providers/isar_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/daily_quest_service.dart';
import '../../core/services/leaderboard_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/wallet_service.dart';
import '../../core/services/weekly_event_service.dart';
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
  Map<Cell, Cell> _portalPairs = const {};
  Map<Cell, Direction> _oneWayCells = const {};
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
    _portalPairs = _portalPairsFor(_state.maze, _level);
    _oneWayCells = _oneWayCellsFor(_state.maze, _level);
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
      if (_hasTimer && !_timeFrozen && _remainingSeconds <= 0) {
        _handleTimeExpired();
      }
    });
  }

  Future<void> _loadCoins() async {
    final uid = ref.read(currentUidProvider);
    final coins = await ref.read(walletServiceProvider).balance(uid);
    if (!mounted) return;
    setState(() => _coins = coins);
  }

  bool get _hasEnemy => _level >= 4 && _level % 3 == 0;
  bool get _hasTimer => _level >= 4 && (_level % 2 == 0 || _isBossLevel);
  bool get _hasTraps =>
      _level >= 5 && (_level % 3 != 1 || (_level >= 12 && _level % 4 == 0));
  bool get _hasTimeBonus =>
      _level >= 6 && (_hasTimer || _goal == _LevelGoal.crystalOrder);
  bool get _isBossLevel => _level > 0 && _level % 10 == 0;
  bool get _hasMoveLimit => _level >= 12 && (_level % 6 == 0 || _isBossLevel);

  int? get _moveLimit {
    if (!_hasMoveLimit) return null;
    final slack = _isBossLevel ? 8 : 5;
    return _state.maze.totalCells - 1 + slack;
  }

  int get _timeTarget {
    final base = _state.maze.totalCells * 2;
    final pressure = _isBossLevel ? 8 + _bossPressure : 0;
    return math.max(14, base - _level ~/ 2 - pressure);
  }

  int get _remainingSeconds => math.max(0, _timeTarget - _elapsedSeconds);

  Color get _stageAccent {
    if (_isBossLevel) return const Color(0xFFEF4444);
    if (_goal == _LevelGoal.crystalOrder) return const Color(0xFF06B6D4);
    if (_goal == _LevelGoal.keyExit) return const Color(0xFF0EA5E9);
    if (_hasTraps) return const Color(0xFFF97316);
    return const Color(0xFF7C3AED);
  }

  _LevelGoal _goalForLevel(int level) {
    if (level > 0 && level % 10 == 0) return _LevelGoal.boss;
    if (level >= 8 && level % 5 == 0) return _LevelGoal.crystalOrder;
    if (level == 2 || (level >= 7 && level % 4 == 3)) {
      return _LevelGoal.keyExit;
    }
    if (level >= 6 && level % 3 == 2) return _LevelGoal.noTrap;
    return _LevelGoal.fillAll;
  }

  String _goalTitle(BuildContext context) => switch (_goal) {
        _LevelGoal.keyExit => context.l10n.t('key_exit'),
        _LevelGoal.crystalOrder => context.l10n.t('crystals'),
        _LevelGoal.noTrap => context.l10n.t('avoid_traps'),
        _LevelGoal.boss => context.l10n.t('boss'),
        _LevelGoal.fillAll => context.l10n.t('fill_all'),
      };

  String _goalProgress(BuildContext context) => switch (_goal) {
        _LevelGoal.keyExit => context.l10n.isTr
            ? '${_keyCells.length} anahtar kaldi'
            : '${_keyCells.length} keys left',
        _LevelGoal.crystalOrder => context.l10n.isTr
            ? '${_crystalIndex}/${_crystalRoute.length} kristal'
            : '${_crystalIndex}/${_crystalRoute.length} crystals',
        _LevelGoal.noTrap => _trapHits == 0
            ? (context.l10n.isTr ? 'Temiz rota' : 'Clean route')
            : (context.l10n.isTr ? '${_trapHits} tuzak' : '${_trapHits} traps'),
        _LevelGoal.boss => context.l10n.isTr
            ? 'Baski ${_bossPressure}'
            : 'Pressure ${_bossPressure}',
        _LevelGoal.fillAll => '${(_state.progressPercent * 100).round()}%',
      };

  String _flavorForLevel(int level) {
    final l10n = AppLocalizations.of(context);
    if (level == 2) return l10n.isTr ? 'Anahtari Bul' : 'Find the Key';
    if (level == 3) return l10n.isTr ? 'Ilk Bomba' : 'First Blast';
    if (level == 4) return l10n.isTr ? 'Zamana Karsi' : 'Beat the Clock';
    if (level >= 18 && level % 7 == 4) {
      return l10n.isTr ? 'Portal Gecidi' : 'Portal Gate';
    }
    if (level >= 14 && level % 6 == 2) {
      return l10n.isTr ? 'Tek Yon Akisi' : 'One-Way Flow';
    }
    if (level >= 7 && level % 4 == 3) {
      return l10n.isTr ? 'Anahtar Kilidi' : 'Key Lock';
    }
    if (level >= 5 && level % 4 == 1) {
      return l10n.isTr ? 'Patlayan Kareler' : 'Blast Tiles';
    }
    if (level >= 4 && level % 3 == 0) {
      return l10n.isTr ? 'Takipten Kac' : 'Escape the Chase';
    }
    if (level >= 3 && level % 2 == 0) {
      return l10n.isTr ? 'Zamana Karsi' : 'Beat the Clock';
    }
    if (level % 5 == 0) return l10n.isTr ? 'Kristal Avi' : 'Crystal Hunt';
    if (level % 5 == 2) return l10n.isTr ? 'Seri Bolumu' : 'Combo Stage';
    return l10n.isTr ? 'Kusursuz Rota' : 'Perfect Route';
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

  Map<Cell, Cell> _portalPairsFor(MazeConfig maze, int level) {
    if (level < 18 || level % 7 != 4) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 18) return const {};
    final entryIndex = (solution.length * 0.42).floor();
    final entry = solution[entryIndex];
    final exit = solution[entryIndex + 1];
    if (entry == maze.start || exit == maze.end) return const {};
    return {entry: exit};
  }

  Map<Cell, Direction> _oneWayCellsFor(MazeConfig maze, int level) {
    if (level < 14 || level % 6 != 2) return const {};
    final solution = MazeSolver.solve(maze);
    if (solution == null || solution.length < 16) return const {};
    final cells = <Cell, Direction>{};
    for (final factor in const [0.32, 0.64]) {
      final index = (solution.length * factor).floor();
      if (index <= 0 || index + 1 >= solution.length) continue;
      final cell = solution[index];
      final next = solution[index + 1];
      if (cell == maze.start || cell == maze.end) continue;
      cells[cell] = _directionBetween(cell, next);
    }
    return cells;
  }

  Direction _directionBetween(Cell from, Cell to) {
    if (to.row < from.row) return Direction.up;
    if (to.row > from.row) return Direction.down;
    if (to.col < from.col) return Direction.left;
    return Direction.right;
  }

  void _triggerBlast(Cell cell) {
    HapticFeedback.heavyImpact();
    unawaited(ref.read(soundServiceProvider).play(SoundCue.blast));
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
      _levelFlavor = clearedRubble.isEmpty
          ? (context.l10n.isTr ? 'Bomba patladi' : 'Blast!')
          : (context.l10n.isTr ? 'Yol acildi!' : 'Path opened!');
    });
    _showFeedback(
      clearedRubble.isEmpty
          ? (context.l10n.isTr ? 'BOMBA!' : 'BLAST!')
          : (context.l10n.isTr ? 'YOL ACILDI' : 'PATH OPENED'),
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
    unawaited(ref.read(soundServiceProvider).play(SoundCue.enemy));

    if (_shields > 0) {
      setState(() {
        _shields--;
        _flowStreak = 0;
        _enemy = _state.maze.end;
        _blastCell = _state.head;
        _levelFlavor = context.l10n.isTr ? 'Kalkan kirildi' : 'Shield broke';
      });
      _showFeedback(
        context.l10n.isTr ? 'KALKAN KIRILDI' : 'SHIELD BROKE',
        const Color(0xFFEF4444),
      );
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
        _levelFlavor = context.l10n.isTr ? 'Yakalandin!' : 'Caught!';
      });
      _showFeedback(
        context.l10n.isTr ? 'YAKALANDIN' : 'CAUGHT',
        const Color(0xFFEF4444),
      );
    }

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _blastCell = null);
    });
  }

  void _handleTimeExpired() {
    if (!_hasTimer || _timeFrozen || _state.isWon) return;
    HapticFeedback.heavyImpact();
    unawaited(ref.read(soundServiceProvider).play(SoundCue.enemy));
    final blockedByShield = _shields > 0;
    setState(() {
      _flowStreak = 0;
      _blastCell = _state.head;
      _elapsedSeconds = math.max(0, _timeTarget - 6);
      if (blockedByShield) {
        _shields--;
        _levelFlavor =
            context.l10n.isTr ? 'Sure kalkani kirdi' : 'Time shield broke';
      } else {
        final keepCount = math.max(1, _state.path.length - 3);
        _state = _state.copyWith(
          path: _state.path.take(keepCount).toList(),
          moveCount: _state.moveCount + 1,
          hintPath: const [],
          history: const [],
        );
        _levelFlavor = context.l10n.isTr ? 'Sure doldu' : 'Time is up';
      }
    });
    _showFeedback(
      blockedByShield
          ? (context.l10n.isTr ? 'SURE DOLDU' : 'TIME IS UP')
          : (context.l10n.isTr ? 'GERI SARILDIN' : 'REWOUND'),
      const Color(0xFFEF4444),
    );
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
        _levelFlavor =
            context.l10n.isTr ? 'Tuzak kalkani kirdi' : 'Trap broke shield';
      } else {
        final keepCount = math.max(1, _state.path.length - 2);
        _state = _state.copyWith(
          path: _state.path.take(keepCount).toList(),
          moveCount: _state.moveCount + 1,
          hintPath: const [],
        );
        _levelFlavor =
            context.l10n.isTr ? 'Tuzak geri itti' : 'Trap pushed back';
      }
    });
    _showFeedback(
      blockedByShield
          ? (context.l10n.isTr ? 'TUZAK!' : 'TRAP!')
          : (context.l10n.isTr ? 'GERI ITILDIN' : 'PUSHED BACK'),
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
      _LevelGoal.boss => true,
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
    final forced = _oneWayCells[_state.head];
    if (forced != null && forced != direction) {
      HapticFeedback.lightImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.blocked));
      _showFeedback(
          context.l10n.isTr ? 'TEK YON' : 'ONE WAY', const Color(0xFF0EA5E9));
      return;
    }
    final moveLimit = _moveLimit;
    if (moveLimit != null && _state.moveCount >= moveLimit) {
      HapticFeedback.lightImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.blocked));
      _showFeedback(context.l10n.isTr ? 'HAMLE LIMITI' : 'MOVE LIMIT',
          const Color(0xFFEF4444));
      return;
    }
    final next = _state.head.offset(direction.dr, direction.dc);
    if (_keyCells.isNotEmpty &&
        (_gateCells.contains(next) || next == _state.maze.end)) {
      HapticFeedback.lightImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.blocked));
      setState(() {
        _flowStreak = 0;
        _levelFlavor =
            context.l10n.isTr ? 'Once anahtari topla' : 'Collect the key first';
      });
      _showFeedback(context.l10n.isTr ? 'ANAHTAR GEREKIYOR' : 'KEY REQUIRED',
          const Color(0xFF0EA5E9));
      return;
    }
    if (next == _state.maze.end &&
        _state.path.length + 1 < _state.maze.totalCells &&
        !_canEnterExitEarly(next)) {
      HapticFeedback.lightImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.blocked));
      setState(() {
        _flowStreak = 0;
        _levelFlavor = context.l10n.isTr ? 'Hedef en son' : 'Target comes last';
      });
      _showFeedback(context.l10n.isTr ? 'HEDEF EN SON' : 'TARGET LAST',
          const Color(0xFFF97316));
      return;
    }
    if (_rubbleCells.contains(next)) {
      HapticFeedback.lightImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.blocked));
      setState(() {
        _flowStreak = 0;
        _levelFlavor =
            context.l10n.isTr ? 'Once bombayi patlat' : 'Blast the bomb first';
      });
      _showFeedback(context.l10n.isTr ? 'BOMBA GEREKIYOR' : 'BOMB REQUIRED',
          const Color(0xFFF97316));
      return;
    }
    if (_goal == _LevelGoal.crystalOrder &&
        _crystalRoute.contains(next) &&
        _crystalRoute.indexOf(next) != _crystalIndex) {
      HapticFeedback.lightImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.blocked));
      setState(() {
        _flowStreak = 0;
        _levelFlavor = context.l10n.isTr
            ? 'Siradaki kristali bul'
            : 'Find the next crystal';
      });
      _showFeedback(context.l10n.isTr ? 'SIRA YANLIS' : 'WRONG ORDER',
          const Color(0xFF14B8A6));
      return;
    }
    final updated = _state.tryMove(next);
    if (updated == null) {
      HapticFeedback.lightImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.blocked));
      setState(() => _flowStreak = 0);
      return;
    }

    var nextState = updated;
    final portalExit = _portalPairs[updated.head];
    final usedPortal = portalExit != null &&
        !_state.inPath(portalExit) &&
        portalExit != updated.maze.end;
    if (usedPortal) {
      nextState = updated.copyWith(
        path: [...updated.path, portalExit],
        moveCount: updated.moveCount + 1,
        history: [
          ...updated.history,
          [...updated.path]
        ],
      );
    }

    final collectedBonus = _bonusCells.contains(nextState.head);
    final collectedKey = _keyCells.contains(nextState.head);
    final collectedTime = _timeBonusCells.contains(nextState.head);
    final collectedCrystal = _goal == _LevelGoal.crystalOrder &&
        _crystalIndex < _crystalRoute.length &&
        nextState.head == _crystalRoute[_crystalIndex];
    final hitTrap = _trapCells.contains(nextState.head);
    setState(() {
      _flowStreak +=
          collectedBonus || collectedKey || collectedCrystal || usedPortal
              ? 3
              : 1;
      _state = nextState.copyWith(hintPath: const []);
      _bonusCells = _bonusCells.difference({nextState.head});
      _keyCells = _keyCells.difference({nextState.head});
      _timeBonusCells = _timeBonusCells.difference({nextState.head});
      if (usedPortal) {
        _levelFlavor = context.l10n.isTr ? 'Portal sicramasi' : 'Portal jump';
      }
      if (collectedBonus) {
        _shields = math.min(2, _shields + 1);
        _levelFlavor = context.l10n.isTr ? 'Kalkan kazandin' : 'Shield gained';
      }
      if (collectedKey) {
        _levelFlavor = _keyCells.length <= 1
            ? (context.l10n.isTr ? 'Kilit acildi' : 'Lock opened')
            : (context.l10n.isTr ? 'Anahtar toplandi' : 'Key collected');
      }
      if (collectedTime) {
        _elapsedSeconds = math.max(0, _elapsedSeconds - 6);
        _flowStreak += 2;
        if (!collectedCrystal)
          _levelFlavor = context.l10n.isTr ? 'Zaman kristali' : 'Time crystal';
      }
      if (collectedCrystal) {
        _crystalIndex++;
        _levelFlavor = _crystalIndex >= _crystalRoute.length
            ? (context.l10n.isTr ? 'Cikis acildi' : 'Exit opened')
            : (context.l10n.isTr ? 'Siradaki kristal' : 'Next crystal');
      }
    });
    unawaited(ref.read(soundServiceProvider).play(SoundCue.move));
    if (usedPortal) {
      HapticFeedback.mediumImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.gate));
      _showFeedback(
        context.l10n.isTr ? 'PORTAL' : 'PORTAL',
        const Color(0xFF7C3AED),
      );
    }
    if (collectedBonus || collectedKey || collectedTime || collectedCrystal) {
      HapticFeedback.mediumImpact();
      unawaited(ref.read(soundServiceProvider).play(
            collectedKey
                ? SoundCue.key
                : collectedCrystal
                    ? SoundCue.combo
                    : SoundCue.gate,
          ));
      _showFeedback(
        collectedKey
            ? (context.l10n.isTr ? 'ANAHTAR!' : 'KEY!')
            : collectedCrystal
                ? (context.l10n.isTr ? 'KRISTAL!' : 'CRYSTAL!')
                : collectedTime
                    ? (context.l10n.isTr ? 'ZAMAN +6' : 'TIME +6')
                    : (context.l10n.isTr ? 'KALKAN +1' : 'SHIELD +1'),
        collectedKey ? const Color(0xFF0EA5E9) : const Color(0xFF06B6D4),
      );
    }
    if (hitTrap && !_state.isWon) {
      _triggerTrap(nextState.head);
    }
    if (_flowStreak > 0 && _flowStreak % 6 == 0) {
      HapticFeedback.selectionClick();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.combo));
      _showFeedback(
        context.l10n.isTr ? 'AKIS x$_flowStreak' : 'FLOW x$_flowStreak',
        _stageAccent,
      );
    }
    if (_unstableCells.contains(updated.head)) {
      _triggerBlast(updated.head);
    }
    _handleEnemyCatch();

    final won = _isGoalWin(_state);
    if (won) {
      HapticFeedback.mediumImpact();
      unawaited(ref.read(soundServiceProvider).play(SoundCue.win));
      final winningState = _state.copyWith(isWon: true);
      final usedHints = _hintsUsed;
      final stars = _starsForWin(winningState.moveCount, usedHints);
      final reward = _rewardForWin(stars, winningState.moveCount, usedHints);
      await _saveWin(winningState.moveCount);
      final questReward = widget.endless || _state.maze.isCustom
          ? const DailyQuestReward(coins: 0, titlesTr: [], titlesEn: [])
          : await ref.read(dailyQuestServiceProvider).recordLevelWin(
                uid: ref.read(currentUidProvider),
                stars: stars,
                noHint: usedHints == 0,
              );
      final weeklyReward = widget.endless || _state.maze.isCustom
          ? 0
          : await ref.read(weeklyEventServiceProvider).recordLevelWin(
                uid: ref.read(currentUidProvider),
                stars: stars,
              );
      await _addCoins(reward + questReward.coins + weeklyReward);
      ref.invalidate(dailyQuestSnapshotProvider);
      ref.invalidate(weeklyEventSnapshotProvider);
      if (!mounted) return;
      final l10n = context.l10n;
      final nextLevel = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.emoji_events_rounded, size: 42),
          title: Text(l10n.t('level_done')),
          content: _WinSummary(
            moves: winningState.moveCount,
            stars: stars,
            reward: reward,
            coins: _coins,
            questReward: questReward,
            weeklyReward: weeklyReward,
            perfect: usedHints == 0 &&
                winningState.moveCount == winningState.maze.totalCells - 1,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.t('menu')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.t('next_level')),
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
          _portalPairs = _portalPairsFor(_state.maze, _level);
          _oneWayCells = _oneWayCellsFor(_state.maze, _level);
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
    final comboBonus = math.min(_flowStreak ~/ 6 * 3, 18);
    final chapterBonus = _level >= 10 ? math.min(18, 5 + _level ~/ 2) : 0;
    return stars * 10 + perfectBonus + noHintBonus + comboBonus + chapterBonus;
  }

  Future<void> _addCoins(int amount) async {
    if (amount <= 0) return;
    final uid = ref.read(currentUidProvider);
    final nextCoins = await ref.read(walletServiceProvider).add(uid, amount);
    ref.invalidate(coinBalanceProvider);
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
    unawaited(ref.read(soundServiceProvider).play(SoundCue.hint));
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
      _levelFlavor = context.l10n.isTr ? 'Geri sarildi' : 'Rewound';
    });
    _showFeedback(
      context.l10n.isTr ? 'GERI SAR' : 'REWIND',
      const Color(0xFF7C3AED),
    );
  }

  void _useFreezeCard() {
    if (_freezeCardsLeft <= 0 || _timeFrozen) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _freezeCardsLeft--;
      _timeFrozen = true;
      _levelFlavor = context.l10n.isTr ? 'Zaman durdu' : 'Time frozen';
    });
    _showFeedback(
      context.l10n.isTr ? 'ZAMAN DURDU' : 'TIME FROZEN',
      const Color(0xFF14B8A6),
    );
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
      _levelFlavor = context.l10n.isTr ? 'Tuzak temizlendi' : 'Traps cleared';
    });
    _showFeedback(
      context.l10n.isTr ? 'TUZAK TEMIZ' : 'TRAPS CLEARED',
      const Color(0xFF16A34A),
    );
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
    await saveCompletedLevelFallback(uid: uid, levelNumber: _level);
    if (isar != null) {
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
    }
    ref.invalidate(completedLevelsProvider);
    unawaited(ref.read(leaderboardServiceProvider).submitLevelScore(
          level: _level,
          moves: moves,
          seconds: seconds,
        ));
  }

  String? _liveTutorialText(BuildContext context) {
    final l10n = context.l10n;
    if (_level == 1 && _state.moveCount < 2) {
      return l10n.isTr
          ? 'Acik karelerin hepsini boya. Turuncu hedefe en son git.'
          : 'Paint every open tile. Reach the orange target last.';
    }
    if (_level == 2 && _keyCells.isNotEmpty) {
      return l10n.isTr
          ? 'Once mavi anahtari topla, sonra kilitli cikisa ilerle.'
          : 'Collect the blue key first, then head to the locked exit.';
    }
    if (_level == 3 && _unstableCells.isNotEmpty) {
      return l10n.isTr
          ? 'Turuncu bomba yolu acabilir. Zamanlamani iyi yap.'
          : 'Orange blast tiles can open the route. Time it well.';
    }
    if (_level >= 14 && _oneWayCells.containsKey(_state.head)) {
      return l10n.isTr
          ? 'Bu kare tek yonlu. Okun gosterdigi yonden cik.'
          : 'This is a one-way tile. Exit in the arrow direction.';
    }
    if (_level >= 18 && _portalPairs.containsKey(_state.head)) {
      return l10n.isTr
          ? 'Portal seni rotadaki sonraki guvenli kareye tasir.'
          : 'The portal jumps you to the next safe route tile.';
    }
    final moveLimit = _moveLimit;
    if (moveLimit != null && moveLimit - _state.moveCount <= 4) {
      return l10n.isTr
          ? 'Hamle limitine yaklastin: ${moveLimit - _state.moveCount} hamle kaldi.'
          : 'Move limit close: ${moveLimit - _state.moveCount} moves left.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(activeThemeProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (_state.progressPercent * 100).round();
    final visibleHints = settings?.premiumUnlocked == true
        ? 99
        : _hintsLeft + (settings?.totalHints ?? 0);
    final media = MediaQuery.of(context);
    final isLandscape = media.size.width > media.size.height;
    final wideLayout = isLandscape && media.size.width >= 700;
    const controlsReserve = 218.0;

    Widget missionPanel() => AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _MissionPanel(
            key: ValueKey('$_levelFlavor-$progress-$_flowStreak'),
            moves: _state.moveCount,
            progress: progress,
            goalTitle: _goalTitle(context),
            goalProgress: _goalProgress(context),
            hintsLeft: visibleHints,
            flowStreak: _flowStreak,
            shields: _shields,
            keysLeft: _keyCells.length,
            rewindCards: _rewindsLeft,
            freezeCards: _freezeCardsLeft,
            cleanseCards: _cleanseCardsLeft,
            flavor: _levelFlavor,
            remainingSeconds: _hasTimer ? _remainingSeconds : null,
            moveLimit: _moveLimit,
            enemyActive: _hasEnemy || _isBossLevel,
            onHint: _useHint,
            onRewind: _useRewindCard,
            onFreeze: _useFreezeCard,
            onCleanse: _useCleanseCard,
          ),
        );

    Widget mazeBoard({double maxSide = 780, bool expanded = true}) {
      final board = Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math
                    .min(constraints.maxWidth, constraints.maxHeight)
                    .clamp(150.0, maxSide)
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
                            portalPairs: _portalPairs,
                            oneWayCells: _oneWayCells,
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
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: _LiveTutorialBubble(text: _liveTutorialText(context)),
          ),
        ],
      );
      return expanded ? Expanded(child: board) : board;
    }

    Widget controlsPanel({bool compact = false}) => SizedBox(
          height: compact ? 136 : 172,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1E7FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFB9A7D8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(compact ? 6 : 8),
                child: _DPad(compact: compact, onMove: _move),
              ),
            ),
          ),
        );

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            widget.endless ? l10n.endlessLevel(_level) : l10n.level(_level)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.t('undo'),
            onPressed: () {
              final previous = _state.undo();
              if (previous != null) setState(() => _state = previous);
            },
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: l10n.t('how_to_play'),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: 320,
        height: 172,
        child: controlsPanel(),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [Color(0xFF111827), Color(0xFF020617)]
                      : const [Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GameAtmospherePainter(
                          pulse: _pulseValue,
                          accent: _stageAccent,
                          danger: (_hasTimer && _remainingSeconds <= 8) ||
                              _isBossLevel,
                          flow: _flowStreak,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: controlsReserve),
                      child: wideLayout
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 292,
                                    child: SingleChildScrollView(
                                      child: missionPanel(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  mazeBoard(maxSide: 620),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  child: missionPanel(),
                                ),
                                mazeBoard(maxSide: 520),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GameAtmospherePainter extends CustomPainter {
  final double pulse;
  final Color accent;
  final bool danger;
  final int flow;

  const _GameAtmospherePainter({
    required this.pulse,
    required this.accent,
    required this.danger,
    required this.flow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final energy = (flow / 18).clamp(0.0, 1.0);
    final alpha = danger ? 0.18 : 0.10 + energy * 0.08;
    final yBase = size.height * (0.18 + pulse * 0.08);

    paint
      ..color = accent.withOpacity(alpha)
      ..strokeWidth = 2.0 + energy * 2.0;
    for (var i = 0; i < 4; i++) {
      final y = yBase + i * size.height * 0.18;
      final start = Offset(-size.width * 0.12, y);
      final end = Offset(size.width * 1.12, y + size.height * 0.10);
      canvas.drawLine(start, end, paint);
    }

    paint
      ..color = (danger ? const Color(0xFFEF4444) : accent).withOpacity(0.12)
      ..strokeWidth = 1.2;
    final inset = 18.0 + pulse * 8.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - inset * 2),
      math.max(0, size.height - inset * 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GameAtmospherePainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.accent != accent ||
        oldDelegate.danger != danger ||
        oldDelegate.flow != flow;
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

class _LiveTutorialBubble extends StatelessWidget {
  final String? text;

  const _LiveTutorialBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: text == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(text),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.primary.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
  final int? moveLimit;
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
    required this.moveLimit,
    required this.enemyActive,
    required this.onHint,
    required this.onRewind,
    required this.onFreeze,
    required this.onCleanse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
              if (moveLimit != null) ...[
                const SizedBox(width: 10),
                Icon(
                  Icons.route_rounded,
                  size: 15,
                  color: moves >= moveLimit! - 3
                      ? const Color(0xFFEF4444)
                      : scheme.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  '${(moveLimit! - moves).clamp(0, moveLimit!)}',
                  style: TextStyle(
                    color: moves >= moveLimit! - 3
                        ? const Color(0xFFEF4444)
                        : scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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
              _Stat(label: l10n.t('moves_label'), value: '$moves'),
              _Stat(label: l10n.t('progress_label'), value: '$progress%'),
              _Stat(label: l10n.t('series'), value: 'x$flowStreak'),
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
                label: l10n.t('rewind'),
                count: rewindCards,
                onTap: onRewind,
              ),
              _CardPill(
                icon: Icons.ac_unit_rounded,
                label: l10n.t('freeze'),
                count: freezeCards,
                onTap: onFreeze,
              ),
              _CardPill(
                icon: Icons.cleaning_services_rounded,
                label: l10n.t('cleanse'),
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
  final DailyQuestReward questReward;
  final int weeklyReward;
  final bool perfect;

  const _WinSummary({
    required this.moves,
    required this.stars,
    required this.reward,
    required this.coins,
    required this.questReward,
    required this.weeklyReward,
    required this.perfect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
          Text(l10n.moves(moves),
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
                Text(l10n.reward(reward, coins)),
              ],
            ),
          ),
          if (perfect) ...[
            const SizedBox(height: 8),
            Text(
              l10n.isTr ? 'Kusursuz rota bonusu!' : 'Perfect route bonus!',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (questReward.hasReward) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.primary.withOpacity(0.18)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt_rounded,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        l10n.isTr
                            ? 'Gunluk gorev +${questReward.coins}'
                            : 'Daily quest +${questReward.coins}',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (l10n.isTr ? questReward.titlesTr : questReward.titlesEn)
                        .join(' \u00B7 '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.66),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (weeklyReward > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available_rounded,
                      size: 18, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text(
                    l10n.isTr
                        ? 'Haftalik etkinlik +$weeklyReward'
                        : 'Weekly event +$weeklyReward',
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            stars == 3
                ? (l10n.isTr
                    ? 'Harika. Bir sonraki bolum biraz daha cetin.'
                    : 'Great. The next level gets a little tougher.')
                : (l10n.isTr
                    ? 'Devam et; yildizlari topladikca jeton kazanirsin.'
                    : 'Keep going; stars earn you more coins.'),
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
            context.l10n.t('hint'),
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
            context.l10n.isTr ? 'Hedef' : 'Target',
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
  final bool compact;
  final ValueChanged<Direction> onMove;

  const _DPad({
    this.compact = false,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 18.0 : 22.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MoveButton(
            compact: compact,
            icon: Icons.keyboard_arrow_up_rounded,
            onTap: () => onMove(Direction.up)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MoveButton(
                compact: compact,
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: () => onMove(Direction.left)),
            SizedBox(width: gap),
            _MoveButton(
                compact: compact,
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: () => onMove(Direction.right)),
          ],
        ),
        _MoveButton(
            compact: compact,
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => onMove(Direction.down)),
      ],
    );
  }
}

class _MoveButton extends StatefulWidget {
  final bool compact;
  final IconData icon;
  final VoidCallback onTap;

  const _MoveButton({
    this.compact = false,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_MoveButton> createState() => _MoveButtonState();
}

class _MoveButtonState extends State<_MoveButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = widget.compact ? 58.0 : 74.0;
    final height = widget.compact ? 44.0 : 50.0;
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
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: _pressed ? scheme.primary : const Color(0xFFE9D5FF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF6D5A8D).withOpacity(0.16),
              ),
              boxShadow: [
                if (!_pressed)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Icon(
              widget.icon,
              size: widget.compact ? 32 : 36,
              color: _pressed ? Colors.white : const Color(0xFF6D5A8D),
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
    final l10n = context.l10n;
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.t('how_to_play'),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.t('skip')),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const _TutorialDemo(),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      _TutorialLine(
                        icon: Icons.grid_on_rounded,
                        title: l10n.t('tutorial_paint_title'),
                        text: l10n.t('tutorial_paint_text'),
                      ),
                      _TutorialLine(
                        icon: Icons.flag_rounded,
                        title: l10n.t('tutorial_target_title'),
                        text: l10n.t('tutorial_target_text'),
                      ),
                      _TutorialLine(
                        icon: Icons.touch_app_rounded,
                        title: l10n.t('tutorial_controls_title'),
                        text: l10n.t('tutorial_controls_text'),
                      ),
                      _TutorialLine(
                        icon: Icons.lightbulb_rounded,
                        title: l10n.t('tutorial_hint_title'),
                        text: l10n.t('tutorial_hint_text'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(context.l10n.t('start')),
                ),
              ),
            ],
          ),
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
        width: 140,
        height: 140,
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
