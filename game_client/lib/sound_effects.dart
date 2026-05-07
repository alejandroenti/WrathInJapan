import 'package:audioplayers/audioplayers.dart';

class SoundEffects {
  SoundEffects._();
  static final SoundEffects _instance = SoundEffects._();
  static SoundEffects get instance => _instance;

  final AudioPlayer _swordPlayer = AudioPlayer();
  final AudioPlayer _deathPlayer = AudioPlayer();

  Future<void> playSwordSlice() async {
    await _swordPlayer.stop();
    await _swordPlayer.play(AssetSource('audio/sword_slice.wav'));
  }

  Future<void> playMusicBoxNegative() async {
    await _deathPlayer.stop();
    await _deathPlayer.play(AssetSource('audio/music_box_negative.wav'));
  }

  Future<void> dispose() async {
    await _swordPlayer.dispose();
    await _deathPlayer.dispose();
  }
}
