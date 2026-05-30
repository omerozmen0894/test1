// lib/core/models/multiplayer_model.dart

enum RoomStatus { waiting, countdown, playing, finished }
enum PlayerStatus { connected, playing, finished, disconnected }

class MultiplayerRoom {
  final String roomCode;
  final String hostId;
  final Map<String, PlayerData> players;
  final RoomStatus status;
  final Map<String, dynamic>? mazeData; // MazeConfig.toMap()
  final int? countdownValue;
  final DateTime createdAt;

  const MultiplayerRoom({
    required this.roomCode,
    required this.hostId,
    required this.players,
    required this.status,
    this.mazeData,
    this.countdownValue,
    required this.createdAt,
  });

  bool get isFull => players.length >= 4;
  bool get canStart => players.length >= 2 && status == RoomStatus.waiting;

  factory MultiplayerRoom.fromMap(Map<dynamic, dynamic> m, String code) =>
      MultiplayerRoom(
        roomCode: code,
        hostId: m['hostId'] ?? '',
        players: (m['players'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), PlayerData.fromMap(v)),
        ),
        status: RoomStatus.values.firstWhere(
          (s) => s.name == (m['status'] ?? 'waiting'),
          orElse: () => RoomStatus.waiting,
        ),
        mazeData: m['maze'] != null ? Map<String, dynamic>.from(m['maze']) : null,
        countdownValue: m['countdown'],
        createdAt: m['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['createdAt'])
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'hostId': hostId,
        'status': status.name,
        if (mazeData != null) 'maze': mazeData,
        if (countdownValue != null) 'countdown': countdownValue,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}

class PlayerData {
  final String uid;
  final String displayName;
  final List<Map<String, int>> path; // [{r:0,c:0}, ...]
  final int moveCount;
  final bool finished;
  final int? finishTime; // epoch ms
  final PlayerStatus status;

  const PlayerData({
    required this.uid,
    required this.displayName,
    required this.path,
    required this.moveCount,
    required this.finished,
    this.finishTime,
    required this.status,
  });

  double progressPercent(int totalCells) =>
      totalCells > 0 ? path.length / totalCells : 0;

  factory PlayerData.fromMap(Map m) => PlayerData(
        uid: m['uid'] ?? '',
        displayName: m['displayName'] ?? 'Oyuncu',
        path: (m['path'] as List? ?? [])
            .map((p) => Map<String, int>.from(p))
            .toList(),
        moveCount: m['moveCount'] ?? 0,
        finished: m['finished'] ?? false,
        finishTime: m['finishTime'],
        status: PlayerStatus.values.firstWhere(
          (s) => s.name == (m['status'] ?? 'connected'),
          orElse: () => PlayerStatus.connected,
        ),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'path': path,
        'moveCount': moveCount,
        'finished': finished,
        if (finishTime != null) 'finishTime': finishTime,
        'status': status.name,
      };
}
