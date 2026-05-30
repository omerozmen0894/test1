// lib/features/multiplayer/multiplayer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart' hide Direction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/maze_model.dart';
import '../../core/models/multiplayer_model.dart';
import '../../core/services/multiplayer_service.dart';
import '../game/maze_painter.dart';
import '../game/gesture_handler.dart';
import '../../core/providers/settings_provider.dart';

// ─── Lobi Ekranı ─────────────────────────────────────────────────────────────

class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() => _LobbyState();
}

class _LobbyState extends ConsumerState<MultiplayerLobbyScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _activeRoomCode;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('⚔️ Çok Oyunculu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary ?? scheme.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text('Aynı Labirette Yarış',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: scheme.onPrimary)),
                Text('Kim daha hızlı çözer?',
                    style: TextStyle(
                        fontSize: 14, color: scheme.onPrimary.withOpacity(0.8))),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 28),

          // Oda oluştur
          Text('Yeni Oda Oluştur',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.5), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _createRoom,
            icon: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_rounded),
            label: const Text('Oda Aç'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 20),

          // Odaya katıl
          Text('Odaya Katıl',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(0.5), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'Oda kodu gir (örn: AB3X7Z)',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _loading ? null : _joinRoom,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Katıl'),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Nasıl çalışır
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nasıl Oynanır?',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                const SizedBox(height: 10),
                ...[
                  ('1️⃣', 'Oda oluştur ve kodu arkadaşına gönder'),
                  ('2️⃣', 'Herkes aynı labirenti görür'),
                  ('3️⃣', 'Karşılıklı ilerlemenizi gerçek zamanlı takip edin'),
                  ('4️⃣', 'En hızlı çözen kazanır!'),
                ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(f.$1, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(f.$2,
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurface.withOpacity(0.7))),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(multiplayerServiceProvider);
      final code = await service.createRoom();
      if (mounted) {
        _goToRoom(code, isHost: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6 haneli oda kodu gir')));
      return;
    }
    setState(() => _loading = true);
    try {
      final service = ref.read(multiplayerServiceProvider);
      final ok = await service.joinRoom(code);
      if (mounted) {
        if (ok) {
          _goToRoom(code, isHost: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oda bulunamadı veya dolu')));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToRoom(String code, {required bool isHost}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MultiplayerRoomScreen(
          roomCode: code, isHost: isHost)));
  }
}

// ─── Oda (Bekleme + Oyun) Ekranı ─────────────────────────────────────────────

class MultiplayerRoomScreen extends ConsumerWidget {
  final String roomCode;
  final bool isHost;
  const MultiplayerRoomScreen(
      {super.key, required this.roomCode, required this.isHost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(activeRoomProvider(roomCode));
    final scheme = Theme.of(context).colorScheme;

    return roomAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (room) {
        if (room == null) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Oda bulunamadı'),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Geri Dön'),
                ),
              ]),
            ),
          );
        }

        if (room.status == RoomStatus.playing || room.status == RoomStatus.finished) {
          return MultiplayerGameScreen(room: room, isHost: isHost);
        }

        // Bekleme ekranı
        return _WaitingRoom(room: room, isHost: isHost, roomCode: roomCode);
      },
    );
  }
}

// ─── Bekleme Odası ────────────────────────────────────────────────────────────

class _WaitingRoom extends ConsumerWidget {
  final MultiplayerRoom room;
  final bool isHost;
  final String roomCode;
  const _WaitingRoom(
      {required this.room, required this.isHost, required this.roomCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final countdown = room.countdownValue;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await ref.read(multiplayerServiceProvider).leaveRoom(roomCode);
            if (context.mounted) Navigator.pop(context);
          },
        ),
        title: Text('Oda: $roomCode',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Kodu Kopyala',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı!')));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Oda kodu
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('Oda Kodu',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withOpacity(0.5))),
                  const SizedBox(height: 6),
                  Text(roomCode,
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                          letterSpacing: 6)),
                  Text('Arkadaşına gönder',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(0.4))),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Oyuncular
            Text('Oyuncular (${room.players.length}/4)',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(height: 10),
            ...room.players.values.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outline.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16, backgroundColor: scheme.primaryContainer,
                    child: Text(p.displayName[0].toUpperCase(),
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.displayName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                  if (p.uid == room.hostId)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Host',
                          style: TextStyle(fontSize: 11, color: scheme.primary)),
                    ),
                ],
              ),
            )),

            const Spacer(),

            // Geri sayım göster
            if (countdown != null)
              Text('$countdown',
                  style: const TextStyle(
                      fontSize: 72, fontWeight: FontWeight.w800))
                  .animate(key: ValueKey(countdown))
                  .scale(begin: const Offset(1.5, 1.5), end: const Offset(1, 1))
                  .fadeIn(),

            // Başlat butonu (sadece host)
            if (isHost && room.canStart && countdown == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => ref
                      .read(multiplayerServiceProvider)
                      .startGame(roomCode),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('🚀 Oyunu Başlat',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

            if (!isHost)
              Text('Host oyunu başlatmayı bekliyor...',
                  style: TextStyle(
                      fontSize: 14, color: scheme.onSurface.withOpacity(0.5))),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Çok Oyunculu Oyun Ekranı ─────────────────────────────────────────────────

class MultiplayerGameScreen extends ConsumerStatefulWidget {
  final MultiplayerRoom room;
  final bool isHost;
  const MultiplayerGameScreen({super.key, required this.room, required this.isHost});

  @override
  ConsumerState<MultiplayerGameScreen> createState() => _MultiGameState();
}

class _MultiGameState extends ConsumerState<MultiplayerGameScreen> {
  late MazeConfig _maze;
  late GameState _gameState;
  final _myUid = 'local'; // FirebaseAuth.instance.currentUser?.uid ?? 'local'

  @override
  void initState() {
    super.initState();
    if (widget.room.mazeData != null) {
      _maze = MazeConfig.fromMap(widget.room.mazeData!);
    } else {
      _maze = _fallbackMaze();
    }
    _gameState = GameState.initial(_maze);
  }

  MazeConfig _fallbackMaze() => MazeConfig(
        size: 5, start: const Cell(0, 0), end: const Cell(4, 4),
        walls: const [], levelNumber: 0);

  void _move(Direction dir) {
    final target = _gameState.head.offset(dir.dr, dir.dc);
    final newState = _gameState.tryMove(target);
    if (newState == null) return;
    setState(() => _gameState = newState);

    // Firebase'e gönder
    ref.read(multiplayerServiceProvider).updatePath(
      widget.room.roomCode,
      _gameState.path,
      _gameState.moveCount,
    );

    if (newState.isWon) {
      ref.read(multiplayerServiceProvider).markFinished(widget.room.roomCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(activeThemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final roomAsync = ref.watch(activeRoomProvider(widget.room.roomCode));
    final room = roomAsync.valueOrNull ?? widget.room;

    final players = room.players.values.toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('⚔️ Yarış',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app_rounded),
          onPressed: () async {
            await ref.read(multiplayerServiceProvider)
                .leaveRoom(widget.room.roomCode);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Oyuncu sıralaması (gerçek zamanlı)
          SizedBox(
            height: 64,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final p = players[i];
                final pct = p.progressPercent(_maze.totalCells);
                return Column(
                  children: [
                    Text('#${i + 1} ${p.displayName}',
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        backgroundColor: scheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(
                            p.finished ? Colors.green : scheme.primary),
                      ),
                    ),
                    if (p.finished)
                      const Text('✅', style: TextStyle(fontSize: 10)),
                  ],
                );
              },
            ),
          ),

          // Maze
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(builder: (ctx, c) {
                final size = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
                return Center(
                  child: SizedBox(
                    width: size, height: size,
                    child: _gameState.isWon
                        ? Stack(children: [
                            CustomPaint(
                                size: Size(size, size),
                                painter: MazePainter(
                                    gameState: _gameState,
                                    theme: theme, isDark: isDark)),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text('🏆\nTebrikler!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 24, color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ])
                        : MazeGestureHandler(
                            onMove: _move,
                            child: CustomPaint(
                              size: Size(size, size),
                              painter: MazePainter(
                                  gameState: _gameState,
                                  theme: theme, isDark: isDark),
                            ),
                          ),
                  ),
                );
              }),
            ),
          ),

          // Geri al
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _gameState.history.isNotEmpty
                        ? () => setState(() => _gameState = _gameState.undo()!)
                        : null,
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Geri Al'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _gameState = GameState.initial(_maze)),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Yeniden'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
