import 'package:audioplayers/audioplayers.dart';

class BgMusic {
  BgMusic._();
  static final BgMusic _instance = BgMusic._();
  static BgMusic get instance => _instance;

  final AudioPlayer _menuPlayer = AudioPlayer();
  final AudioPlayer _gameplayPlayer = AudioPlayer();
  bool _menuPlaying = false;
  bool _gameplayPlaying = false;

  Future<void> play() async {
    if (_menuPlaying) return;
    _menuPlaying = true;
    await _menuPlayer.setReleaseMode(ReleaseMode.loop);
    await _menuPlayer.play(AssetSource('audio/japanesechiptune.mp3'));
  }

  Future<void> stop() async {
    if (!_menuPlaying) return;
    _menuPlaying = false;
    await _menuPlayer.stop();
  }

  Future<void> playGameplay() async {
    if (_gameplayPlaying) return;
    _gameplayPlaying = true;
    await _gameplayPlayer.setReleaseMode(ReleaseMode.loop);
    await _gameplayPlayer.play(AssetSource('audio/EternityLivesLoop.wav'));
  }

  Future<void> stopGameplay() async {
    if (!_gameplayPlaying) return;
    _gameplayPlaying = false;
    await _gameplayPlayer.stop();
  }

  Future<void> disposePlayer() async {
    await _menuPlayer.dispose();
    await _gameplayPlayer.dispose();
  }
}
