// lib/features/editor/editor_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../core/database/progress_model.dart';
import '../../core/maze_generator.dart';
import '../../core/models/maze_model.dart';
import '../../core/providers/isar_provider.dart';

enum EditorTool { wall, start, end, eraser }

final _editorProvider = ChangeNotifierProvider<EditorNotifier>((ref) {
  return EditorNotifier(ref.read(isarProvider));
});

class EditorNotifier extends ChangeNotifier {
  final Isar? _isar;
  int size = 5;
  Cell? start;
  Cell? end;
  final Set<Cell> walls = {};
  EditorTool tool = EditorTool.wall;
  bool isPublishing = false;
  String title = 'Benim Labirentim';

  EditorNotifier(this._isar);

  void setSize(int s) {
    size = s;
    start = null;
    end = null;
    walls.clear();
    notifyListeners();
  }

  void tapCell(Cell cell) {
    switch (tool) {
      case EditorTool.wall:
        if (cell == start || cell == end) return;
        if (walls.contains(cell)) {
          walls.remove(cell);
        } else {
          walls.add(cell);
        }
      case EditorTool.start:
        walls.remove(cell);
        start = cell;
      case EditorTool.end:
        walls.remove(cell);
        end = cell;
      case EditorTool.eraser:
        walls.remove(cell);
        if (cell == start) start = null;
        if (cell == end) end = null;
    }
    notifyListeners();
  }

  bool get isValid {
    if (start == null || end == null) return false;
    if (start == end) return false;
    final maze = _buildConfig();
    return _isConnected(maze);
  }

  bool _isConnected(MazeConfig maze) {
    final visited = <Cell>{};
    final queue = [maze.start];
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (visited.contains(cur)) continue;
      visited.add(cur);
      for (final d in dirs) {
        final n = Cell(cur.row + d[0], cur.col + d[1]);
        if (maze.isValid(n) && !visited.contains(n)) queue.add(n);
      }
    }
    return visited.contains(maze.end) && visited.length == maze.totalCells;
  }

  MazeConfig _buildConfig() => MazeConfig(
    size: size,
    start: start ?? Cell(0, 0),
    end: end ?? Cell(size - 1, size - 1),
    walls: walls.toList(),
    levelNumber: 0,
    isCustom: true,
  );

  Future<void> saveLocal() async {
    if (start == null || end == null) return;
    final isar = _isar;
    if (isar == null) return;
    final level =
        CustomLevel()
          ..uid = FirebaseAuth.instance.currentUser?.uid ?? 'local'
          ..title = title
          ..size = size
          ..startJson = jsonEncode(start!.toMap())
          ..endJson = jsonEncode(end!.toMap())
          ..wallsJson = jsonEncode(walls.map((w) => w.toMap()).toList())
          ..createdAt = DateTime.now()
          ..playCount = 0
          ..rating = 0
          ..ratingCount = 0
          ..isPublished = false;
    await isar.writeTxn(() => isar.customLevels.put(level));
  }

  Future<void> publishToFirebase() async {
    if (!isValid) return;
    isPublishing = true;
    notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('custom_levels').add({
        'uid': FirebaseAuth.instance.currentUser?.uid ?? 'anon',
        'title': title,
        'size': size,
        'start': start!.toMap(),
        'end': end!.toMap(),
        'walls': walls.map((w) => w.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'playCount': 0,
        'rating': 0,
        'ratingCount': 0,
      });
      await saveLocal();
    } finally {
      isPublishing = false;
      notifyListeners();
    }
  }
}

// ─── Editor Screen ────────────────────────────────────────────────────────────

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(_editorProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () => _editTitle(context, editor),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                editor.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: scheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // Kaydet
          TextButton(
            onPressed:
                editor.isValid
                    ? () async {
                      await editor.saveLocal();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kaydedildi!')),
                        );
                      }
                    }
                    : null,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Grid boyutu seçici
          _SizePicker(current: editor.size, onChanged: editor.setSize),

          // Araç çubuğu
          _ToolBar(
            tool: editor.tool,
            onChanged: (t) {
              editor.tool = t;
              editor.notifyListeners();
            },
          ),

          // Grid
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: LayoutBuilder(
                builder: (ctx, c) {
                  final size =
                      (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight)
                          .clamp(280.0, isTablet ? 760.0 : 560.0)
                          .toDouble();
                  return Center(
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: _EditorGrid(
                        editor: editor,
                        gridSize: size,
                        isDark: isDark,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Yayınla
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              0,
              isTablet ? 24 : 20,
              isTablet ? 24 : 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        editor.isValid
                            ? () => _testPlay(context, editor)
                            : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, isTablet ? 54 : 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('▶ Test Oyna'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        editor.isValid && !editor.isPublishing
                            ? () async {
                              await editor.publishToFirebase();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🌍 Yayınlandı!'),
                                  ),
                                );
                              }
                            }
                            : null,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(0, isTablet ? 54 : 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        editor.isPublishing
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('🌍 Yayınla'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editTitle(BuildContext context, EditorNotifier editor) {
    final ctrl = TextEditingController(text: editor.title);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Labirent Adı'),
            content: TextField(
              controller: ctrl,
              maxLength: 30,
              decoration: const InputDecoration(hintText: 'Adını gir...'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    editor.title = ctrl.text.trim();
                    editor.notifyListeners();
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }

  void _testPlay(BuildContext context, EditorNotifier editor) {
    // TODO: EditorNotifier'dan MazeConfig oluşturup GameScreen'e yönlendir
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test modu — GameScreen entegrasyonu gerekli'),
      ),
    );
  }
}

// ─── Editor Grid ─────────────────────────────────────────────────────────────

class _EditorGrid extends StatelessWidget {
  final EditorNotifier editor;
  final double gridSize;
  final bool isDark;

  const _EditorGrid({
    required this.editor,
    required this.gridSize,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final n = editor.size;
    final cs = gridSize / n;

    return GestureDetector(
      onPanUpdate: (d) {
        final col = (d.localPosition.dx / cs).floor();
        final row = (d.localPosition.dy / cs).floor();
        if (row >= 0 && row < n && col >= 0 && col < n) {
          editor.tapCell(Cell(row, col));
        }
      },
      onTapDown: (d) {
        final col = (d.localPosition.dx / cs).floor();
        final row = (d.localPosition.dy / cs).floor();
        if (row >= 0 && row < n && col >= 0 && col < n) {
          editor.tapCell(Cell(row, col));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F4F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: n * n,
          itemBuilder: (ctx, i) {
            final row = i ~/ n, col = i % n;
            final cell = Cell(row, col);
            Color color;
            String? label;

            if (cell == editor.start) {
              color = const Color(0xFF86EFAC);
              label = 'S';
            } else if (cell == editor.end) {
              color = const Color(0xFF93C5FD);
              label = 'B';
            } else if (editor.walls.contains(cell)) {
              color =
                  isDark ? const Color(0xFF374151) : const Color(0xFF9CA3AF);
            } else {
              color =
                  isDark ? const Color(0xFF252525) : const Color(0xFFF1F0EC);
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  label != null
                      ? Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      )
                      : null,
            );
          },
        ),
      ),
    );
  }
}

// ─── Size Picker ─────────────────────────────────────────────────────────────

class _SizePicker extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  const _SizePicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 620 : double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: 8,
          ),
          child: Row(
            children: [
              Text(
                'Grid:',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 10),
              ...[4, 5, 6, 7, 8].map((s) {
                final selected = s == current;
                return GestureDetector(
                  onTap: () => onChanged(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${s}x$s',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color:
                            selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tool Bar ────────────────────────────────────────────────────────────────

class _ToolBar extends StatelessWidget {
  final EditorTool tool;
  final ValueChanged<EditorTool> onChanged;
  const _ToolBar({required this.tool, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final tools = [
      (EditorTool.wall, Icons.square_rounded, 'Duvar'),
      (EditorTool.start, Icons.play_arrow_rounded, 'Başlangıç'),
      (EditorTool.end, Icons.flag_rounded, 'Bitiş'),
      (EditorTool.eraser, Icons.auto_fix_high_rounded, 'Sil'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 620 : double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: 4,
          ),
          child: Row(
            children:
                tools.map((t) {
                  final selected = t.$1 == tool;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(t.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              selected ? scheme.primary : scheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              t.$2,
                              size: 18,
                              color:
                                  selected
                                      ? scheme.onPrimary
                                      : scheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.$3,
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    selected
                                        ? scheme.onPrimary
                                        : scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}
