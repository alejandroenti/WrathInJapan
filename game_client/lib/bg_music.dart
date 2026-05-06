import 'package:audioplayers/audioplayers.dart';

class BgMusic {
  BgMusic._();
  static final BgMusic _instance = BgMusic._();
  static BgMusic get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  Future<void> play() async {
    if (_playing) return;
    _playing = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('audio/japanesechiptune.mp3'));
  }

  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    await _player.stop();
  }

  Future<void> disposePlayer() async {
    await _player.dispose();
  }
}
