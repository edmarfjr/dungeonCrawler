import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioManager {
  static double sfxVolume = 1.0;
  static double bgmVolume = 0.5;

  static bool _isMutedMusic = false;
  static bool get isMutedMusic => _isMutedMusic;
  static bool _isMutedSfx = false;
  static bool get isMutedSfx => _isMutedSfx;

  static bool _isBgmPlaying = false;
  static String _currentBgm = '';

  static final Map<String, AudioSource> _sfxSources = {};

  static String _resolveSfxPath(String filename) {
    if (kIsWeb) {
      return 'sfx/mp3/$filename'; 
    } else {
      String wavName = filename.replaceAll('.mp3', '.wav');
      return 'sfx/wav/$wavName'; 
    }
  }

  static Future<void> _loadSfx(String filename) async {
    try {
      String resolvedPath = _resolveSfxPath(filename);
      String fullPath = 'assets/audio/$resolvedPath';
      AudioSource source = await SoLoud.instance.loadAsset(fullPath);
      _sfxSources[filename] = source;
    } catch (e) {
      //print("Erro SoLoud: $e");
    }
  }

  static Future<void> init() async {
    FlameAudio.bgm.initialize();

      await _loadSfx('claw.wav');
      await _loadSfx('hit.wav');
      await _loadSfx('block.wav');
      await _loadSfx('encounter.wav');
      await _loadSfx('attack.wav');
      await _loadSfx('enemy_die.wav');
      await _loadSfx('use_item.wav');
      await _loadSfx('fire.wav');
      await _loadSfx('charge.wav');
      await _loadSfx('poison.wav');
  }

  static void playSfx(String filename) {
    if (_isMutedSfx) return;
    //print("Tocando SFX: $filename");
    /*if (kIsWeb) {
      try {
        FlameAudio.play(_resolveSfxPath(filename), volume: sfxVolume);
      } catch (e) { }
      return; 
    }

    String poolKey = filename.replaceAll('.wav', '.mp3');
    */
    try {
      if (_sfxSources.containsKey(filename)) {
        SoLoud.instance.play(_sfxSources[filename]!, volume: sfxVolume);
      }
    } catch (e) { }
  }


  static void playBgm(String filename) {
    if (_currentBgm == filename && _isBgmPlaying && !_isMutedMusic) return; 
    _currentBgm = filename; 
    if (_isMutedMusic) return;

    FlameAudio.bgm.stop(); 
    try {
      FlameAudio.bgm.play('music/$filename', volume: bgmVolume);
      _isBgmPlaying = true;
    } catch (e) { }
  }

  static void stopBgm() {
    FlameAudio.bgm.stop();
    _isBgmPlaying = false;
  }

  static void pauseBgm(){
    FlameAudio.bgm.pause();
  }

  static void resumeBgm(){
    if (!_isMutedMusic) FlameAudio.bgm.resume();
  }
  
  static void toggleMuteMusic(bool mute) {
    _isMutedMusic = mute;
    if (_isMutedMusic) {
      FlameAudio.bgm.pause(); 
      _isBgmPlaying = false;
    } else {
      if (_currentBgm.isNotEmpty) playBgm(_currentBgm); 
    }
  }

  static void toggleMuteSfx(bool mute) {
    _isMutedSfx = mute;
  }

  static void updateBgmVolume(double volume) {
    bgmVolume = volume;
    if (FlameAudio.bgm.isPlaying) {
      FlameAudio.bgm.audioPlayer.setVolume(volume);
    }
  }

  static void updateSfxVolume(double volume) {
    sfxVolume = volume;
  }
}