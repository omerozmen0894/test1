import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class SoundService {
  final Ref _ref;
  final Map<SoundCue, AudioPlayer> _players = {};
  final Map<SoundCue, DateTime> _lastPlayed = {};

  SoundService(this._ref);

  Future<void> play(SoundCue cue) async {
    final settings = _ref.read(settingsProvider).valueOrNull;
    if (settings?.soundEnabled == false) return;
    if (cue.isHighFrequency) return;

    final now = DateTime.now();
    final last = _lastPlayed[cue];
    if (last != null && now.difference(last) < cue.cooldown) return;
    _lastPlayed[cue] = now;

    try {
      final player = _players.putIfAbsent(
        cue,
        () {
          final p = AudioPlayer(playerId: 'wrap_maze_sfx_${cue.name}');
          p.setReleaseMode(ReleaseMode.stop);
          p.setPlayerMode(PlayerMode.lowLatency);
          return p;
        },
      );
      await player.seek(Duration.zero);
      await player.play(AssetSource('audio/${cue.fileName}'),
          volume: cue.volume);
    } catch (_) {
      // Sound must never block gameplay.
    }
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

enum SoundCue {
  move('move.wav'),
  blocked('blocked.wav'),
  combo('combo.wav'),
  key('key.wav'),
  hint('hint.wav'),
  blast('blast.wav'),
  enemy('enemy.wav'),
  gate('gate.wav'),
  win('win.wav');

  final String fileName;
  const SoundCue(this.fileName);

  bool get isHighFrequency => this == SoundCue.move || this == SoundCue.blocked;

  Duration get cooldown => switch (this) {
        SoundCue.combo => const Duration(milliseconds: 180),
        SoundCue.key => const Duration(milliseconds: 120),
        SoundCue.hint => const Duration(milliseconds: 250),
        SoundCue.blast => const Duration(milliseconds: 300),
        SoundCue.enemy => const Duration(milliseconds: 350),
        SoundCue.gate => const Duration(milliseconds: 160),
        SoundCue.win => const Duration(milliseconds: 600),
        SoundCue.move || SoundCue.blocked => const Duration(milliseconds: 999),
      };

  double get volume => switch (this) {
        SoundCue.win => 0.58,
        SoundCue.blast => 0.52,
        SoundCue.enemy => 0.48,
        _ => 0.42,
      };
}
