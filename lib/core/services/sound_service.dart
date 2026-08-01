import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

final soundServiceProvider = Provider<SoundService>((ref) => SoundService(ref));

class SoundService {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer(playerId: 'wrap_maze_sfx');

  SoundService(this._ref) {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> play(SoundCue cue) async {
    final settings = _ref.read(settingsProvider).valueOrNull;
    if (settings?.soundEnabled == false) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/${cue.fileName}'), volume: 0.62);
    } catch (_) {
      // Sound must never block gameplay.
    }
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
}
