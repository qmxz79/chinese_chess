import 'package:audioplayers/audioplayers.dart';
import 'chess_constants.dart';
import 'config_manager.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  static final AudioPlayer _player = AudioPlayer();
  
  factory SoundManager() {
    return _instance;
  }

  SoundManager._internal();

  static Future<void> playSound(String soundFile) async {
    if (!ConfigManager.soundEnabled) return;
    try {
      await _player.setSource(AssetSource('assets/sounds/$soundFile'));
      await _player.resume();
    } catch (_) {
      // ignore play errors
    }
  }

  static void playMove() {
    playSound(ChessConstants.soundMove);
  }

  static void playCapture() {
    playSound(ChessConstants.soundCapture);
  }

  static void playCheck() {
    playSound(ChessConstants.soundCheck);
  }

  static void playGameOver() {
    playSound(ChessConstants.soundGameOver);
  }
}