import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/models/maze_model.dart';
import '../../core/models/theme_model.dart';

class MazePainter extends CustomPainter {
  final GameState gameState;
  final MazeTheme theme;
  final bool isDark;
  final double pulse;
  final Set<Cell> bonusCells;
  final Cell? enemy;
  final Set<Cell> unstableCells;
  final Set<Cell> rubbleCells;
  final Set<Cell> trapCells;
  final Set<Cell> timeBonusCells;
  final Cell? blastCell;
  final Set<Cell> blastWaveCells;
  final Set<Cell> keyCells;
  final Set<Cell> gateCells;
  final bool gatesLocked;

  const MazePainter({
    required this.gameState,
    required this.theme,
    required this.isDark,
    this.pulse = 0,
    this.bonusCells = const {},
    this.enemy,
    this.unstableCells = const {},
    this.rubbleCells = const {},
    this.trapCells = const {},
    this.timeBonusCells = const {},
    this.blastCell,
    this.blastWaveCells = const {},
    this.keyCells = const {},
    this.gateCells = const {},
    this.gatesLocked = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maze = gameState.maze;
    final cell = size.width / maze.size;
    final gap = cell * 0.08;
    final radius = Radius.circular(cell * 0.16);
    final paint = Paint()..style = PaintingStyle.fill;
    final boardRect = Offset.zero & size;

    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(cell * 0.22)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1D1B2F), Color(0xFF0F172A)]
              : const [Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
        ).createShader(boardRect),
    );

    for (var row = 0; row < maze.size; row++) {
      for (var col = 0; col < maze.size; col++) {
        final c = Cell(row, col);
        final rect = Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );

        paint.color = isDark ? const Color(0xFF24243A) : theme.cellEmpty;
        if (maze.isWall(c)) {
          paint.color = isDark ? const Color(0xFF111827) : theme.cellWall;
        }
        if (c == maze.start) paint.color = const Color(0xFF22C55E);
        if (c == maze.end) paint.color = const Color(0xFFF97316);
        if (rubbleCells.contains(c)) {
          paint.color =
              isDark ? const Color(0xFF3B1B1B) : const Color(0xFFFFD6A5);
        }
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      }
    }

    _drawRubbleCells(canvas, cell);
    _drawTrapCells(canvas, cell);
    _drawGateCells(canvas, cell);
    _drawUnstableCells(canvas, cell);
    _drawBlastWave(canvas, cell);
    _drawBlast(canvas, cell);
    final pathPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [theme.primary, const Color(0xFF06B6D4)],
      ).createShader(boardRect);
    for (final c in gameState.path) {
      final rect = Rect.fromLTWH(
        c.col * cell + gap * 1.8,
        c.row * cell + gap * 1.8,
        cell - gap * 3.6,
        cell - gap * 3.6,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), pathPaint);
    }

    _drawHintRoute(canvas, cell, gap);
    _drawKeyCells(canvas, cell);
    _drawTimeBonusCells(canvas, cell);
    _drawBonusCells(canvas, cell);

    _drawTarget(canvas, maze.end, cell, gap);
    _drawStart(canvas, maze.start, cell);
    _drawEnemy(canvas, cell);

    final head = gameState.head;
    _drawHeadTrail(canvas, cell);
    paint.shader = null;
    paint.color = Colors.white;
    canvas.drawShadow(
      Path()
        ..addOval(Rect.fromCircle(
          center:
              Offset(head.col * cell + cell / 2, head.row * cell + cell / 2),
          radius: cell * 0.24,
        )),
      Colors.black.withOpacity(0.35),
      4,
      true,
    );
    canvas.drawCircle(
      Offset(head.col * cell + cell / 2, head.row * cell + cell / 2),
      cell * 0.22,
      paint,
    );
    canvas.drawCircle(
      Offset(head.col * cell + cell / 2, head.row * cell + cell / 2),
      cell * 0.11,
      Paint()..color = const Color(0xFF111827),
    );
  }

  void _drawRubbleCells(Canvas canvas, double cell) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.045
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF92400E).withOpacity(0.72);
    for (final c in rubbleCells) {
      if (gameState.inPath(c)) continue;
      final x = c.col * cell;
      final y = c.row * cell;
      canvas.drawLine(
        Offset(x + cell * 0.24, y + cell * 0.28),
        Offset(x + cell * 0.76, y + cell * 0.72),
        paint,
      );
      canvas.drawLine(
        Offset(x + cell * 0.76, y + cell * 0.28),
        Offset(x + cell * 0.24, y + cell * 0.72),
        paint,
      );
      canvas.drawCircle(
        Offset(x + cell * 0.5, y + cell * 0.5),
        cell * 0.28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.035
          ..color = const Color(0xFFF97316).withOpacity(0.7),
      );
    }
  }

  void _drawTrapCells(Canvas canvas, double cell) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.045
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEF4444);
    for (final c in trapCells) {
      if (gameState.inPath(c)) continue;
      final x = c.col * cell;
      final y = c.row * cell;
      final center = Offset(x + cell * 0.5, y + cell * 0.5);
      canvas.drawCircle(
        center,
        cell * (0.25 + pulse * 0.03),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.04
          ..color = const Color(0xFFEF4444).withOpacity(0.8),
      );
      canvas.drawLine(
        Offset(x + cell * 0.34, y + cell * 0.34),
        Offset(x + cell * 0.66, y + cell * 0.66),
        paint,
      );
      canvas.drawLine(
        Offset(x + cell * 0.66, y + cell * 0.34),
        Offset(x + cell * 0.34, y + cell * 0.66),
        paint,
      );
    }
  }

  void _drawGateCells(Canvas canvas, double cell) {
    final color =
        gatesLocked ? const Color(0xFF2563EB) : const Color(0xFF22C55E);
    for (final c in gateCells) {
      if (gameState.inPath(c)) continue;
      final center = Offset(c.col * cell + cell / 2, c.row * cell + cell / 2);
      final rect = Rect.fromCenter(
        center: center,
        width: cell * 0.48,
        height: cell * 0.38,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.08)),
        Paint()..color = color.withOpacity(gatesLocked ? 0.95 : 0.55),
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: center - Offset(0, cell * 0.13),
          width: cell * 0.34,
          height: cell * 0.34,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.055
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      canvas.drawCircle(
        center,
        cell * 0.055,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawKeyCells(Canvas canvas, double cell) {
    for (final c in keyCells) {
      if (gameState.inPath(c)) continue;
      final center = Offset(c.col * cell + cell / 2, c.row * cell + cell / 2);
      canvas.drawCircle(
        center,
        cell * (0.22 + pulse * 0.04),
        Paint()..color = const Color(0xFF38BDF8).withOpacity(0.85),
      );
      canvas.drawCircle(
        center - Offset(cell * 0.08, 0),
        cell * 0.085,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.035
          ..color = Colors.white,
      );
      canvas.drawLine(
        center,
        center + Offset(cell * 0.18, 0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.045
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
      canvas.drawLine(
        center + Offset(cell * 0.12, 0),
        center + Offset(cell * 0.12, cell * 0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.035
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
    }
  }

  void _drawUnstableCells(Canvas canvas, double cell) {
    final crackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.035
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF111827).withOpacity(0.62);
    for (final c in unstableCells) {
      if (gameState.inPath(c)) continue;
      final x = c.col * cell;
      final y = c.row * cell;
      final center = Offset(x + cell * 0.5, y + cell * 0.5);
      canvas.drawCircle(
        center,
        cell * (0.22 + pulse * 0.04),
        Paint()..color = const Color(0xFF111827),
      );
      canvas.drawCircle(
        center + Offset(cell * 0.08, -cell * 0.08),
        cell * 0.08,
        Paint()..color = const Color(0xFFEF4444),
      );
      canvas.drawLine(
        center + Offset(cell * 0.10, -cell * 0.20),
        center + Offset(cell * 0.24, -cell * 0.34),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.035
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFD166),
      );
      final path = Path()
        ..moveTo(x + cell * 0.30, y + cell * 0.22)
        ..lineTo(x + cell * 0.48, y + cell * 0.45)
        ..lineTo(x + cell * 0.38, y + cell * 0.62)
        ..moveTo(x + cell * 0.50, y + cell * 0.45)
        ..lineTo(x + cell * 0.70, y + cell * 0.30)
        ..moveTo(x + cell * 0.39, y + cell * 0.62)
        ..lineTo(x + cell * 0.64, y + cell * 0.76);
      canvas.drawPath(path, crackPaint);
    }
  }

  void _drawBlastWave(Canvas canvas, double cell) {
    if (blastWaveCells.isEmpty) return;
    final wavePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFD166).withOpacity(0.28);
    for (final c in blastWaveCells) {
      final center = Offset(c.col * cell + cell / 2, c.row * cell + cell / 2);
      canvas.drawCircle(center, cell * (0.25 + pulse * 0.12), wavePaint);
    }
  }

  void _drawBlast(Canvas canvas, double cell) {
    final b = blastCell;
    if (b == null) return;
    final center = Offset(b.col * cell + cell / 2, b.row * cell + cell / 2);
    canvas.drawCircle(
      center,
      cell * (0.32 + pulse * 0.22),
      Paint()..color = const Color(0xFFF97316).withOpacity(0.26),
    );
    canvas.drawCircle(
      center,
      cell * (0.16 + pulse * 0.10),
      Paint()..color = const Color(0xFFFFD166).withOpacity(0.42),
    );
    final sparkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.035
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFF7D6).withOpacity(0.95);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + pulse * 0.7;
      final inner = center +
          Offset(math.cos(angle), math.sin(angle)) *
              cell *
              (0.20 + pulse * 0.10);
      final outer = center +
          Offset(math.cos(angle), math.sin(angle)) *
              cell *
              (0.44 + pulse * 0.24);
      canvas.drawLine(inner, outer, sparkPaint);
    }
  }

  void _drawEnemy(Canvas canvas, double cell) {
    final e = enemy;
    if (e == null || gameState.inPath(e) || e == gameState.maze.end) return;
    final center = Offset(e.col * cell + cell / 2, e.row * cell + cell / 2);
    canvas.drawCircle(
      center,
      cell * (0.24 + pulse * 0.04),
      Paint()..color = const Color(0xFFEF4444).withOpacity(0.22),
    );
    canvas.drawCircle(
      center,
      cell * 0.19,
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.drawCircle(
      center + Offset(-cell * 0.06, -cell * 0.04),
      cell * 0.035,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center + Offset(cell * 0.06, -cell * 0.04),
      cell * 0.035,
      Paint()..color = Colors.white,
    );
  }

  void _drawBonusCells(Canvas canvas, double cell) {
    for (final c in bonusCells) {
      if (gameState.inPath(c)) continue;
      final center = Offset(c.col * cell + cell / 2, c.row * cell + cell / 2);
      canvas.drawCircle(
        center,
        cell * (0.28 + pulse * 0.10),
        Paint()..color = const Color(0xFFFFD166).withOpacity(0.20),
      );
      final points = <Offset>[];
      for (var i = 0; i < 8; i++) {
        final angle = -1.5708 + i * 0.7854;
        final radius = i.isEven ? cell * 0.18 : cell * 0.09;
        points.add(center + Offset(math.cos(angle), math.sin(angle)) * radius);
      }
      canvas.drawPath(
        Path()..addPolygon(points, true),
        Paint()..color = const Color(0xFFFFD166),
      );
      canvas.drawCircle(
        center,
        cell * (0.22 + pulse * 0.03),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.025
          ..color = const Color(0xFFFFD166).withOpacity(0.55),
      );
    }
  }

  void _drawTimeBonusCells(Canvas canvas, double cell) {
    for (final c in timeBonusCells) {
      if (gameState.inPath(c)) continue;
      final center = Offset(c.col * cell + cell / 2, c.row * cell + cell / 2);
      canvas.drawCircle(
        center,
        cell * (0.22 + pulse * 0.04),
        Paint()..color = const Color(0xFF14B8A6).withOpacity(0.82),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: cell * 0.13),
        -math.pi / 2,
        math.pi * 1.45,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.035
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
      canvas.drawCircle(center, cell * 0.025, Paint()..color = Colors.white);
    }
  }

  void _drawHintRoute(Canvas canvas, double cell, double gap) {
    final hintPath = gameState.hintPath;
    if (hintPath == null || hintPath.length <= gameState.path.length) return;
    final start = gameState.path.length;
    final route = hintPath.skip(start).toList();
    final routePaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < route.length; i++) {
      final c = route[i];
      final center = Offset(c.col * cell + cell / 2, c.row * cell + cell / 2);
      final alpha = (0.42 - i * 0.018).clamp(0.12, 0.42);
      routePaint.color = const Color(0xFFFFD166).withOpacity(alpha);
      canvas.drawCircle(center, cell * 0.18, routePaint);
      if (i == 0) {
        canvas.drawCircle(
          center,
          cell * (0.28 + pulse * 0.06),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.06
            ..color = const Color(0xFFFFD166),
        );
      }
    }
  }

  void _drawTarget(Canvas canvas, Cell target, double cell, double gap) {
    final center =
        Offset(target.col * cell + cell / 2, target.row * cell + cell / 2);
    final glowRadius = cell * (0.34 + pulse * 0.08);
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()..color = const Color(0xFFF97316).withOpacity(0.24 - pulse * 0.08),
    );
    for (var i = 0; i < 4; i++) {
      final angle = pulse * math.pi * 2 + i * math.pi / 2;
      final dot = center +
          Offset(math.cos(angle), math.sin(angle)) *
              cell *
              (0.42 + pulse * 0.04);
      canvas.drawCircle(
        dot,
        cell * 0.035,
        Paint()..color = const Color(0xFFFFD166).withOpacity(0.85),
      );
    }
    canvas.drawCircle(
      center,
      cell * 0.31,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.07
        ..color = const Color(0xFFFFD166),
    );
    canvas.drawCircle(
      center,
      cell * 0.17,
      Paint()..color = const Color(0xFFEA580C),
    );

    if (cell > 34) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'HEDEF',
          style: TextStyle(
            color: Colors.white,
            fontSize: cell * 0.15,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
          canvas, center - Offset(painter.width / 2, painter.height / 2));
    }
  }

  void _drawStart(Canvas canvas, Cell start, double cell) {
    final center =
        Offset(start.col * cell + cell / 2, start.row * cell + cell / 2);
    canvas.drawCircle(
      center,
      cell * 0.26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05
        ..color = const Color(0xFFA7F3D0),
    );
  }

  void _drawHeadTrail(Canvas canvas, double cell) {
    final head = gameState.head;
    final center =
        Offset(head.col * cell + cell / 2, head.row * cell + cell / 2);
    canvas.drawCircle(
      center,
      cell * (0.32 + pulse * 0.06),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.035
        ..color = theme.primary.withOpacity(0.42),
    );
    if (gameState.path.length < 2) return;
    final prev = gameState.path[gameState.path.length - 2];
    final prevCenter =
        Offset(prev.col * cell + cell / 2, prev.row * cell + cell / 2);
    canvas.drawLine(
      prevCenter,
      center,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.10
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.18),
    );
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) =>
      oldDelegate.gameState != gameState ||
      oldDelegate.theme != theme ||
      oldDelegate.isDark != isDark ||
      oldDelegate.pulse != pulse ||
      oldDelegate.bonusCells != bonusCells ||
      oldDelegate.enemy != enemy ||
      oldDelegate.unstableCells != unstableCells ||
      oldDelegate.rubbleCells != rubbleCells ||
      oldDelegate.trapCells != trapCells ||
      oldDelegate.timeBonusCells != timeBonusCells ||
      oldDelegate.blastCell != blastCell ||
      oldDelegate.blastWaveCells != blastWaveCells ||
      oldDelegate.keyCells != keyCells ||
      oldDelegate.gateCells != gateCells ||
      oldDelegate.gatesLocked != gatesLocked;
}
