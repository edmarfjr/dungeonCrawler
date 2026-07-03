import 'package:dungeon_crawler/game/components/core/settings_manager.dart';
import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static bool isMusicMuted = false;
  static bool isSfxMuted = false;
  static String? _currentTrack;      
  static bool _isBgmInitialized = false;
  static bool _isBgmPausedInternally = false;

  static void playSfx(String file, {double volume = 1.0}) {
    if (!isSfxMuted) {
      FlameAudio.play(file, volume: volume);
    }
  }

  static void playBgm(String track, {double volume = 0.3}) {
    _currentTrack = track; 
    _isBgmPausedInternally = false;

    if (!isMusicMuted) {
      FlameAudio.bgm.play(track, volume: volume);
      _isBgmInitialized = true; 
    } else {
      _isBgmInitialized = false;
    }
  }

  static void stopBgm() {
    _currentTrack = null;
    _isBgmInitialized = false;
    _isBgmPausedInternally = false;
    FlameAudio.bgm.stop();
  }

  static void pauseBgm() {
    _isBgmPausedInternally = true;
    if (_isBgmInitialized) {
      FlameAudio.bgm.pause();
    }
  }

  static void resumeBgm() {
    _isBgmPausedInternally = false; 

    if (!isMusicMuted && _currentTrack != null) {
      if (_isBgmInitialized) {
        FlameAudio.bgm.resume();
      } else {
        FlameAudio.bgm.play(_currentTrack!, volume: 0.3);
        _isBgmInitialized = true;
      }
    }
  }

  static void toggleSfx() {
    isSfxMuted = !isSfxMuted;
    SettingsManager.saveSfx(isSfxMuted);
  }

  static void toggleMusic() {
    isMusicMuted = !isMusicMuted;
    SettingsManager.saveMusic(isMusicMuted);

    if (isMusicMuted) {
      FlameAudio.bgm.pause();
    } else {
      if (_currentTrack != null && !_isBgmPausedInternally) {
        if (_isBgmInitialized) {
          FlameAudio.bgm.resume();
        } else {
          FlameAudio.bgm.play(_currentTrack!, volume: 0.3);
          _isBgmInitialized = true;
        }
      }
    }
  }
}