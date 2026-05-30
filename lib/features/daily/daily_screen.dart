import 'package:flutter/material.dart';

import '../../core/maze_generator.dart';
import '../game/game_screen.dart';

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final maze = MazeGenerator.generateDaily(DateTime.now());
    return GameScreen(level: maze.levelNumber, maze: maze);
  }
}
