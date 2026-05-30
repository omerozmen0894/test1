import 'package:flutter/material.dart';

import 'core/maze_generator.dart';
import 'core/models/maze_model.dart';

void main() => runApp(const WrapMazeDemo());

class WrapMazeDemo extends StatelessWidget {
  const WrapMazeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wrap Maze Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
        scaffoldBackgroundColor: const Color(0xFFF8F8F6),
      ),
      home: const DemoGameScreen(),
    );
  }
}

class DemoGameScreen extends StatefulWidget {
  const DemoGameScreen({super.key});

  @override
  State<DemoGameScreen> createState() => _DemoGameScreenState();
}

class _DemoGameScreenState extends State<DemoGameScreen> {
  var _level = 1;
  var _advancing = false;
  var _autoPlaying = false;
  var _showGuide = true;
  final List<_ScoreEntry> _scores = [];
  late GameState _state = GameState.initial(MazeGenerator.generate(_level));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted && _level == 1 && _state.moveCount == 0) {
        _playFirstLevelDemo();
      }
    });
  }

  void _move(Direction direction) {
    if (_advancing || _autoPlaying) return;
    _moveInternal(direction);
  }

  void _moveInternal(Direction direction, {bool automatic = false}) {
    final next = _state.head.offset(direction.dr, direction.dc);
    final updated = _state.tryMove(next);
    if (updated == null) return;
    setState(() => _state = updated);

    if (updated.isWon) {
      _finishLevel(automatic: automatic);
    }
  }

  Future<void> _playFirstLevelDemo() async {
    if (_autoPlaying || _level != 1 || _state.moveCount != 0) return;
    final solution = MazeSolver.solve(_state.maze);
    if (solution == null || solution.length < 2) return;

    setState(() {
      _showGuide = false;
      _autoPlaying = true;
    });

    for (var i = 1; i < solution.length; i++) {
      if (!mounted || _level != 1) return;
      final direction = _directionBetween(solution[i - 1], solution[i]);
      if (direction == null) return;
      await Future.delayed(const Duration(milliseconds: 210));
      if (!mounted) return;
      _moveInternal(direction, automatic: true);
      if (_state.isWon) break;
    }

    if (mounted && !_advancing) {
      setState(() => _autoPlaying = false);
    }
  }

  Direction? _directionBetween(Cell from, Cell to) {
    final dr = to.row - from.row;
    final dc = to.col - from.col;
    if (dr == -1 && dc == 0) return Direction.up;
    if (dr == 1 && dc == 0) return Direction.down;
    if (dr == 0 && dc == -1) return Direction.left;
    if (dr == 0 && dc == 1) return Direction.right;
    return null;
  }

  void _finishLevel({required bool automatic}) {
    if (_advancing) return;
    _scores.add(_ScoreEntry(
      level: _level,
      moves: _state.moveCount,
      automatic: automatic,
    ));
    _scores.sort((a, b) {
      final byLevel = b.level.compareTo(a.level);
      if (byLevel != 0) return byLevel;
      return a.moves.compareTo(b.moves);
    });

    setState(() {
      _advancing = true;
      _autoPlaying = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          automatic
              ? 'Demo leveli tamamladı. Sıralama güncellendi.'
              : 'Level $_level tamamlandı. Sıralama güncellendi.',
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _level++;
        _state = GameState.initial(MazeGenerator.generate(_level));
        _advancing = false;
      });
    });
  }

  void _restart() {
    setState(() {
      _level = 1;
      _scores.clear();
      _advancing = false;
      _autoPlaying = false;
      _showGuide = true;
      _state = GameState.initial(MazeGenerator.generate(_level));
    });
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted && _level == 1 && _state.moveCount == 0) {
        _playFirstLevelDemo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Wrap Maze',
                              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              _autoPlaying
                                  ? 'Level 1 demo oynatılıyor'
                                  : 'Boş kareleri gez, en son mavi karede bitir',
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _restart,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Restart'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      _Stat(label: 'Level', value: '$_level'),
                      _Stat(label: 'Moves', value: '${_state.moveCount}'),
                      _Stat(
                        label: 'Progress',
                        value: '${(_state.progressPercent * 100).round()}%',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side = constraints.biggest.shortestSide.clamp(280.0, 620.0);
                              return _SwipeHandler(
                                onMove: _move,
                                child: CustomPaint(
                                  size: Size(side, side),
                                  painter: _DemoMazePainter(_state, scheme),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (wide)
                        SizedBox(
                          width: 300,
                          child: _RankingPanel(scores: _scores),
                        ),
                    ],
                  ),
                ),
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _RankingPanel(scores: _scores, compact: true),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _autoPlaying ? null : () => _move(Direction.up),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _autoPlaying ? null : () => _move(Direction.left),
                            icon: const Icon(Icons.keyboard_arrow_left_rounded),
                          ),
                          const SizedBox(width: 36),
                          IconButton.filledTonal(
                            onPressed: _autoPlaying ? null : () => _move(Direction.right),
                            icon: const Icon(Icons.keyboard_arrow_right_rounded),
                          ),
                        ],
                      ),
                      IconButton.filledTonal(
                        onPressed: _autoPlaying ? null : () => _move(Direction.down),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_showGuide)
              _GuideCard(
                autoPlaying: _autoPlaying,
                onClose: () => setState(() => _showGuide = false),
                onDemo: _playFirstLevelDemo,
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHandler extends StatelessWidget {
  final Widget child;
  final ValueChanged<Direction> onMove;

  const _SwipeHandler({required this.child, required this.onMove});

  @override
  Widget build(BuildContext context) {
    Offset? start;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => start = details.localPosition,
      onPanUpdate: (details) {
        final origin = start;
        if (origin == null) return;
        final delta = details.localPosition - origin;
        if (delta.distance < 28) return;
        if (delta.dx.abs() > delta.dy.abs()) {
          onMove(delta.dx > 0 ? Direction.right : Direction.left);
        } else {
          onMove(delta.dy > 0 ? Direction.down : Direction.up);
        }
        start = details.localPosition;
      },
      child: child,
    );
  }
}

class _DemoMazePainter extends CustomPainter {
  final GameState state;
  final ColorScheme scheme;

  const _DemoMazePainter(this.state, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final maze = state.maze;
    final cell = size.width / maze.size;
    final gap = cell * 0.08;
    final radius = Radius.circular(cell * 0.14);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var row = 0; row < maze.size; row++) {
      for (var col = 0; col < maze.size; col++) {
        final current = Cell(row, col);
        final rect = Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
        paint.color = const Color(0xFFEFEDEA);
        if (maze.isWall(current)) paint.color = const Color(0xFFB9B5AA);
        if (current == maze.start) paint.color = const Color(0xFFD1FAE5);
        if (current == maze.end) paint.color = const Color(0xFFDBEAFE);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      }
    }

    for (final current in state.path) {
      final rect = Rect.fromLTWH(
        current.col * cell + gap * 1.7,
        current.row * cell + gap * 1.7,
        cell - gap * 3.4,
        cell - gap * 3.4,
      );
      paint.color = scheme.primary;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DemoMazePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.scheme != scheme;
}

class _GuideCard extends StatelessWidget {
  final bool autoPlaying;
  final VoidCallback onClose;
  final VoidCallback onDemo;

  const _GuideCard({
    required this.autoPlaying,
    required this.onClose,
    required this.onDemo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.18),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(20, 86, 20, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(18),
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Nasıl oynanır?',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _GuideLine(
                    icon: Icons.route_rounded,
                    text: 'Mor yolunla tüm açık kareleri bir kez dolaş.',
                  ),
                  const _GuideLine(
                    icon: Icons.flag_rounded,
                    text: 'Bölüm yalnızca en son mavi karede bitince tamamlanır.',
                  ),
                  const _GuideLine(
                    icon: Icons.swipe_rounded,
                    text: 'Ok tuşlarıyla veya ekranda kaydırarak hareket et.',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: autoPlaying ? null : onDemo,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(autoPlaying ? 'Demo oynuyor' : 'İlk bölümü göster'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: onClose,
                        child: const Text('Oyuna geç'),
                      ),
                    ],
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

class _GuideLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuideLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _RankingPanel extends StatelessWidget {
  final List<_ScoreEntry> scores;
  final bool compact;

  const _RankingPanel({required this.scores, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = scores.take(compact ? 3 : 6).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 8, compact ? 0 : 24, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withOpacity(0.14)),
        ),
        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Sıralama',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              Text(
                'İlk biten bölüm burada görünecek.',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.55)),
              )
            else
              ...visible.map((score) {
                final rank = scores.indexOf(score) + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Level ${score.level}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('${score.moves} hamle'),
                      if (score.automatic) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.smart_toy_rounded, size: 16, color: scheme.primary),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ScoreEntry {
  final int level;
  final int moves;
  final bool automatic;

  const _ScoreEntry({
    required this.level,
    required this.moves,
    required this.automatic,
  });
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
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.primary)),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.55))),
        ],
      ),
    );
  }
}
