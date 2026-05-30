import 'package:flutter/material.dart';

import '../../core/models/maze_model.dart';

class MazeGestureHandler extends StatelessWidget {
  final Widget child;
  final ValueChanged<Direction> onMove;

  const MazeGestureHandler({
    super.key,
    required this.child,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    Offset? start;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => start = details.localPosition,
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        if (velocity.distance > 120) {
          _emitFromOffset(velocity);
          return;
        }
        start = null;
      },
      onPanUpdate: (details) {
        final origin = start;
        if (origin == null) return;
        final delta = details.localPosition - origin;
        if (delta.distance < 28) return;
        _emitFromOffset(delta);
        start = details.localPosition;
      },
      child: child,
    );
  }

  void _emitFromOffset(Offset delta) {
    if (delta.dx.abs() > delta.dy.abs()) {
      onMove(delta.dx > 0 ? Direction.right : Direction.left);
    } else {
      onMove(delta.dy > 0 ? Direction.down : Direction.up);
    }
  }
}
