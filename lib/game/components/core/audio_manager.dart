import 'package:dungeon_crawler/game/components/core/settings_manager.dart';
import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  // Variáveis globais de controle
  static bool isMusicMuted = false;
  static bool isSfxMuted = false;

  // Método global para tocar SFX (já faz a checagem do mute!)
  static void playSfx(String file, {double volume = 1.0}) {
    if (!isSfxMuted) {
      FlameAudio.play(file, volume: volume);
    }
  }

  // Controles de Mute
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
      FlameAudio.bgm.resume();
    }
  }
}