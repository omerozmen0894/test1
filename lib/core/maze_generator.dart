// lib/core/maze_generator.dart
import 'dart:math';
import 'models/maze_model.dart';

class MazeGenerator {
  static int sizeForLevel(int level) {
    if (level <= 3) return 4;
    if (level <= 8) return 5;
    if (level <= 15) return 6;
    if (level <= 25) return 7;
    if (level <= 40) return 8;
    if (level <= 60) return 9;
    return min(4 + level ~/ 12, 10);
  }

  static int wallCountForLevel(int level, int size) {
    return 0;
  }

  static MazeConfig generate(int levelNumber) {
    return _build(levelNumber, isDaily: false);
  }

  static MazeConfig generateDaily(DateTime date) {
    final seedLevel = 10 + (date.year * 372 + date.month * 31 + date.day) % 45;
    return _build(seedLevel, isDaily: true);
  }

  static MazeConfig _build(int levelNumber, {required bool isDaily}) {
    final size = isDaily ? 6 : sizeForLevel(levelNumber);
    final variants = MazeSolver.routeVariants(size);
    final route = variants[levelNumber % variants.length];
    final start = route.first;
    final end = route.last;
    return MazeConfig(
      size: size,
      start: start,
      end: end,
      walls: const [],
      levelNumber: levelNumber,
      isDaily: isDaily,
    );
  }

  // Wilson's Loop-Erased Random Walk
  static List<Cell> wilsonMaze(Random rng, int size) {
    final inMaze = <Cell>{};
    final all = [
      for (int r = 0; r < size; r++)
        for (int c = 0; c < size; c++) Cell(r, c)
    ];
    inMaze.add(all[rng.nextInt(all.length)]);
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];

    while (inMaze.length < all.length) {
      final notIn = all.where((c) => !inMaze.contains(c)).toList();
      if (notIn.isEmpty) break;

      var current = notIn[rng.nextInt(notIn.length)];
      final path = <Cell>[current];

      while (!inMaze.contains(current)) {
        final d = dirs[rng.nextInt(dirs.length)];
        final next = Cell(current.row + d[0], current.col + d[1]);
        if (next.row < 0 ||
            next.row >= size ||
            next.col < 0 ||
            next.col >= size) continue;
        final loopIdx = path.indexOf(next);
        if (loopIdx >= 0) {
          path.removeRange(loopIdx + 1, path.length);
        } else {
          path.add(next);
        }
        current = next;
      }
      inMaze.addAll(path);
    }
    return inMaze.toList();
  }
}

class MazeSolver {
  static final Map<int, List<List<Cell>>> _variantCache = {};

  static List<Cell>? solve(MazeConfig maze) {
    if (maze.walls.isEmpty) {
      for (final path in routeVariants(maze.size)) {
        if (path.first == maze.start && path.last == maze.end) return path;
        if (path.first == maze.end && path.last == maze.start) {
          return path.reversed.toList();
        }
      }
    }

    final visited = {maze.start};
    final path = [maze.start];
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];

    bool dfs(Cell cur) {
      if (DateTime.now().isAfter(deadline)) return false;
      if (cur == maze.end) return path.length == maze.totalCells;
      for (final d in dirs) {
        final next = Cell(cur.row + d[0], cur.col + d[1]);
        if (!maze.isValid(next) || visited.contains(next)) continue;
        visited.add(next);
        path.add(next);
        if (dfs(next)) return true;
        path.removeLast();
        visited.remove(next);
      }
      return false;
    }

    return dfs(maze.start) ? [...path] : null;
  }

  static List<List<Cell>> snakeVariants(int size) {
    final horizontal = [
      for (var row = 0; row < size; row++)
        if (row.isEven)
          for (var col = 0; col < size; col++) Cell(row, col)
        else
          for (var col = size - 1; col >= 0; col--) Cell(row, col)
    ];
    final vertical = [
      for (var col = 0; col < size; col++)
        if (col.isEven)
          for (var row = 0; row < size; row++) Cell(row, col)
        else
          for (var row = size - 1; row >= 0; row--) Cell(row, col)
    ];
    return [
      horizontal,
      horizontal.reversed.toList(),
      vertical,
      vertical.reversed.toList(),
    ];
  }

  static List<List<Cell>> routeVariants(int size) {
    final cached = _variantCache[size];
    if (cached != null) return cached;
    final variants = [...snakeVariants(size)];
    final spiral = _spiral(size);
    variants.add(spiral);
    variants.add(spiral.reversed.toList());
    variants.addAll(_edgeWeaves(size));
    variants.addAll(_randomRoutes(size));
    return _variantCache[size] = variants;
  }

  static List<List<Cell>> _randomRoutes(int size) {
    final routes = <List<Cell>>[];
    for (var seed = 0; seed < 10 && routes.length < 5; seed++) {
      final route = _randomHamiltonian(size, Random(size * 997 + seed * 37));
      if (route == null) continue;
      final key = route.map((c) => '${c.row},${c.col}').join('|');
      final duplicate = routes.any(
        (r) => r.map((c) => '${c.row},${c.col}').join('|') == key,
      );
      if (!duplicate) {
        routes.add(route);
        routes.add(route.reversed.toList());
      }
    }
    return routes;
  }

  static List<Cell>? _randomHamiltonian(int size, Random rng) {
    final cells = [
      for (var r = 0; r < size; r++)
        for (var c = 0; c < size; c++) Cell(r, c)
    ];
    final corners = [
      const Cell(0, 0),
      Cell(0, size - 1),
      Cell(size - 1, 0),
      Cell(size - 1, size - 1),
    ]..shuffle(rng);
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    final deadline = DateTime.now().add(const Duration(milliseconds: 22));

    for (final start in corners) {
      final visited = <Cell>{start};
      final path = <Cell>[start];

      bool dfs(Cell current) {
        if (DateTime.now().isAfter(deadline)) return false;
        if (path.length == cells.length) return true;
        final options = <Cell>[];
        for (final d in dirs) {
          final next = Cell(current.row + d[0], current.col + d[1]);
          if (next.row < 0 ||
              next.row >= size ||
              next.col < 0 ||
              next.col >= size ||
              visited.contains(next)) {
            continue;
          }
          options.add(next);
        }
        options.sort((a, b) {
          final ac = _openNeighborCount(a, size, visited);
          final bc = _openNeighborCount(b, size, visited);
          final compare = ac.compareTo(bc);
          if (compare != 0) return compare;
          return rng.nextBool() ? -1 : 1;
        });
        for (final next in options) {
          visited.add(next);
          path.add(next);
          if (dfs(next)) return true;
          path.removeLast();
          visited.remove(next);
        }
        return false;
      }

      if (dfs(start)) return [...path];
    }
    return null;
  }

  static int _openNeighborCount(Cell cell, int size, Set<Cell> visited) {
    var count = 0;
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (final d in dirs) {
      final next = Cell(cell.row + d[0], cell.col + d[1]);
      if (next.row >= 0 &&
          next.row < size &&
          next.col >= 0 &&
          next.col < size &&
          !visited.contains(next)) {
        count++;
      }
    }
    return count;
  }

  static List<List<Cell>> _edgeWeaves(int size) {
    final routes = <List<Cell>>[];
    for (var offset = 1; offset < size - 1; offset++) {
      final upperRows = [for (var r = offset; r >= 0; r--) r];
      final lowerRows = [for (var r = offset + 1; r < size; r++) r];
      final rowOrder = [...upperRows, ...lowerRows];
      final route = <Cell>[];
      for (var i = 0; i < rowOrder.length; i++) {
        final row = rowOrder[i];
        if (i.isEven) {
          for (var col = 0; col < size; col++) {
            route.add(Cell(row, col));
          }
        } else {
          for (var col = size - 1; col >= 0; col--) {
            route.add(Cell(row, col));
          }
        }
      }
      if (route.length == size * size &&
          _isContinuous(route) &&
          route.toSet().length == route.length) {
        routes.add(route);
        routes.add(route.reversed.toList());
      }
    }
    return routes;
  }

  static bool _isContinuous(List<Cell> route) {
    for (var i = 1; i < route.length; i++) {
      final a = route[i - 1];
      final b = route[i];
      final distance = (a.row - b.row).abs() + (a.col - b.col).abs();
      if (distance != 1) return false;
    }
    return true;
  }

  static List<Cell> _spiral(int size) {
    final cells = <Cell>[];
    var top = 0;
    var left = 0;
    var right = size - 1;
    var bottom = size - 1;
    while (left <= right && top <= bottom) {
      for (var col = left; col <= right; col++) {
        cells.add(Cell(top, col));
      }
      top++;
      for (var row = top; row <= bottom; row++) {
        cells.add(Cell(row, right));
      }
      right--;
      if (top <= bottom) {
        for (var col = right; col >= left; col--) {
          cells.add(Cell(bottom, col));
        }
        bottom--;
      }
      if (left <= right) {
        for (var row = bottom; row >= top; row--) {
          cells.add(Cell(row, left));
        }
        left++;
      }
    }
    return cells;
  }
}
