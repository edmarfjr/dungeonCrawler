import 'package:a_blade_in_the_abyss/game/components/core/settings_manager.dart';
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

  // NOVO: Mapa de AudioPools para evitar a criação de instâncias nativas repetidas!
  static final Map<String, AudioPool> _sfxPools = {};
  
  static final Map<String, int> _lastPlayedTime = {};

  // NOVO: Função de inicialização obrigatória. Deve ser chamada no onLoad do jogo!
  static Future<void> init() async {
    // Lista de todos os efeitos sonoros rápidos do jogo
    final sfxFiles = [
      'sfx/hit.wav', 'sfx/block.wav', 'sfx/encounter.wav', 'sfx/attack.wav',
      'sfx/enemy_die.wav', 'sfx/use_item.wav', 'sfx/fire.wav', 'sfx/charge.wav',
      'sfx/poison.wav', 'sfx/confirm.wav', 'sfx/hover.wav', 'sfx/step.wav',
      'sfx/landing.wav', 'sfx/denied.wav', 'sfx/thunder.wav', 'sfx/claw.wav',
      'sfx/decline.wav', 'sfx/explosion.wav', 'sfx/shot.wav'
    ];

    for (var file in sfxFiles) {
      _sfxPools[file] = await FlameAudio.createPool(file, minPlayers: 1, maxPlayers: 10);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

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
      // --- ANTI-SPAM (DEBOUNCE) DE ÁUDIO ---
      // Previne que o mesmo som seja tocado dezenas de vezes num único milissegundo,
      // o que causa travamentos (lag) na thread nativa do celular.
      int now = DateTime.now().millisecondsSinceEpoch;
      if (_lastPlayedTime.containsKey(file)) {
        if (now - _lastPlayedTime[file]! < 60) { // 60ms de respiro
          return; // Ignora o som para salvar processamento!
        }
      }
      _lastPlayedTime[file] = now;

      if (_sfxPools.containsKey(file)) {
        // Se o som está no pool (RAM), dispara instantaneamente
        _sfxPools[file]!.start(volume: _sfxVolume * volume);
      } else {
        // Fallback: Se você esquecer de registrar algum som no init()
        FlameAudio.play(file, volume: _sfxVolume * volume);
      }
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
        FlameAudio.bgm.play(currentTrack!, volume: _bgmVolume);
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
          FlameAudio.bgm.play(currentTrack!, volume: _bgmVolume);
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