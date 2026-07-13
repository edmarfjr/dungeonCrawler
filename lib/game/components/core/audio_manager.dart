import 'package:dungeon_crawler/game/components/core/settings_manager.dart';
import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static bool isMusicMuted = false;
  static bool isSfxMuted = false;
  static String? currentTrack;      
  static bool _isBgmInitialized = false;
  static bool _isBgmPausedInternally = false;
  // Níveis de volume para a Interface (0 a 10)
  static int bgmVolumeLevel = 3;
  static int sfxVolumeLevel = 10;

  // Multiplicadores reais para o motor de áudio (0.0 a 1.0)
  static double _bgmVolume = 0.3;
  static double _sfxVolume = 1.0;

  static void applyVolumes() {
    // A música costuma ser muito alta, então o máximo (10) será 50% do volume real
    _bgmVolume = (bgmVolumeLevel / 10.0) * 0.5; 
    
    // Os efeitos sonoros vão de 0.0 a 1.0
    _sfxVolume = sfxVolumeLevel / 10.0;
    
    // Se a música já estiver a tocar, atualiza o volume instantaneamente!
    if (_isBgmInitialized && bgmVolumeLevel > 0) {
       FlameAudio.bgm.audioPlayer.setVolume(_bgmVolume);
    }
  }

  static void playSfx(String file, {double volume = 1.0}) {
    if (sfxVolumeLevel > 0) {
      FlameAudio.play(file, volume: _sfxVolume * volume);
    }
  }

  static void playBgm(String track, {double volume = 1.0}) {
    currentTrack = track; 
    _isBgmPausedInternally = false;

    if (bgmVolumeLevel > 0) {
      FlameAudio.bgm.play(track, volume: _bgmVolume * volume);
      _isBgmInitialized = true; 
    } else {
      _isBgmInitialized = false;
    }
  }

  static void stopBgm() {
    currentTrack = null;
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

    if (bgmVolumeLevel > 0 && currentTrack != null) {
      if (_isBgmInitialized) {
        FlameAudio.bgm.resume();
      } else {
        FlameAudio.bgm.play(currentTrack!, volume: 0.3);
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
      if (currentTrack != null && !_isBgmPausedInternally) {
        if (_isBgmInitialized) {
          FlameAudio.bgm.resume();
        } else {
          FlameAudio.bgm.play(currentTrack!, volume: 0.3);
          _isBgmInitialized = true;
        }
      }
    }
  }
  static void changeSfxVolume(int delta) {
    sfxVolumeLevel = (sfxVolumeLevel + delta).clamp(0, 10); // Mantém entre 0 e 10
    applyVolumes();
    SettingsManager.saveSfxVolume(sfxVolumeLevel);
    
    // Toca um som de feedback rápido ao ajustar o volume (se não estiver no 0)
    if (delta != 0 && sfxVolumeLevel > 0) {
      playSfx('sfx/hover.wav'); 
    }
  }

  static void changeBgmVolume(int delta) {
    bgmVolumeLevel = (bgmVolumeLevel + delta).clamp(0, 10);
    applyVolumes();
    SettingsManager.saveBgmVolume(bgmVolumeLevel);

    if (bgmVolumeLevel == 0) {
      FlameAudio.bgm.pause(); // Muta a música
    } else {
      if (currentTrack != null && !_isBgmPausedInternally) {
        if (_isBgmInitialized) {
          FlameAudio.bgm.resume(); 
        } else {
          FlameAudio.bgm.play(currentTrack!, volume: _bgmVolume);
          _isBgmInitialized = true;
        }
      }
    }
  }

}