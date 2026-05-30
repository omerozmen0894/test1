// lib/core/models/maze_model.dart

enum CellType { empty, wall, start, end }
enum Direction { up, down, left, right }

extension DirectionExt on Direction {
  int get dr => switch (this) { Direction.up => -1, Direction.down => 1, _ => 0 };
  int get dc => switch (this) { Direction.left => -1, Direction.right => 1, _ => 0 };
}

class Cell {
  final int row;
  final int col;
  const Cell(this.row, this.col);

  @override
  bool operator ==(Object other) => other is Cell && other.row == row && other.col == col;
  @override
  int get hashCode => row * 1000 + col;
  Cell offset(int dr, int dc) => Cell(row + dr, col + dc);

  Map<String, int> toMap() => {'r': row, 'c': col};
  factory Cell.fromMap(Map m) => Cell(m['r'] as int, m['c'] as int);

  @override
  String toString() => '($row,$col)';
}

class MazeConfig {
  final int size;
  final Cell start;
  final Cell end;
  final List<Cell> walls;
  final int levelNumber;
  final bool isDaily;
  final bool isCustom;
  final String? customId;

  const MazeConfig({
    required this.size,
    required this.start,
    required this.end,
    required this.walls,
    required this.levelNumber,
    this.isDaily = false,
    this.isCustom = false,
    this.customId,
  });

  int get totalCells => size * size - walls.length;
  bool isWall(Cell c) => walls.contains(c);
  bool isValid(Cell c) =>
      c.row >= 0 && c.row < size && c.col >= 0 && c.col < size && !isWall(c);

  Map<String, dynamic> toMap() => {
        'size': size,
        'start': start.toMap(),
        'end': end.toMap(),
        'walls': walls.map((w) => w.toMap()).toList(),
        'levelNumber': levelNumber,
        'isCustom': isCustom,
        'customId': customId,
      };

  factory MazeConfig.fromMap(Map<String, dynamic> m) => MazeConfig(
        size: m['size'],
        start: Cell.fromMap(m['start']),
        end: Cell.fromMap(m['end']),
        walls: (m['walls'] as List).map((w) => Cell.fromMap(w)).toList(),
        levelNumber: m['levelNumber'],
        isCustom: m['isCustom'] ?? false,
        customId: m['customId'],
      );
}

class GameState {
  final MazeConfig maze;
  final List<Cell> path;
  final int moveCount;
  final bool isWon;
  final List<List<Cell>> history;
  final List<Cell>? hintPath;

  const GameState({
    required this.maze,
    required this.path,
    required this.moveCount,
    required this.isWon,
    required this.history,
    this.hintPath,
  });

  factory GameState.initial(MazeConfig maze) => GameState(
        maze: maze, path: [maze.start],
        moveCount: 0, isWon: false, history: const [],
      );

  Cell get head => path.last;
  double get progressPercent => path.length / maze.totalCells;
  bool inPath(Cell c) => path.contains(c);

  Cell? get nextHint {
    if (hintPath == null || hintPath!.length <= path.length) return null;
    for (int i = 0; i < path.length; i++) {
      if (i >= hintPath!.length || hintPath![i] != path[i]) return null;
    }
    return hintPath![path.length];
  }

  GameState? tryMove(Cell target) {
    if (!maze.isValid(target)) return null;
    if (path.length >= 2 && path[path.length - 2] == target) {
      return copyWith(
        path: [...path]..removeLast(),
        moveCount: moveCount + 1,
        history: [...history, [...path]],
      );
    }
    if (inPath(target)) return null;
    final newPath = [...path, target];
    final won = target == maze.end && newPath.length == maze.totalCells;
    return copyWith(path: newPath, moveCount: moveCount + 1, isWon: won,
        history: [...history, [...path]]);
  }

  GameState? undo() {
    if (history.isEmpty) return null;
    return copyWith(path: history.last, history: history.sublist(0, history.length - 1));
  }

  GameState copyWith({
    MazeConfig? maze, List<Cell>? path, int? moveCount,
    bool? isWon, List<List<Cell>>? history, List<Cell>? hintPath,
  }) => GameState(
    maze: maze ?? this.maze, path: path ?? this.path,
    moveCount: moveCount ?? this.moveCount, isWon: isWon ?? this.isWon,
    history: history ?? this.history, hintPath: hintPath ?? this.hintPath,
  );
}
