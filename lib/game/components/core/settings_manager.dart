import 'package:dungeon_crawler/game/components/core/audio_manager.dart';
import 'package:dungeon_crawler/game/components/core/i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static late SharedPreferences prefs;

  // Carrega tudo quando o jogo abre
  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    AudioManager.bgmVolumeLevel = prefs.getInt('bgmVolume') ?? 3; // Padrão: 3
    AudioManager.sfxVolumeLevel = prefs.getInt('sfxVolume') ?? 10; // Padrão: 10
    AudioManager.applyVolumes(); // Aplica a matemática para o motor de som
    
    // --- CARREGAR ÁUDIO ---
    // Se não encontrar o save (?? false), o padrão é começar ligado (false = não mutado)
    AudioManager.isMusicMuted = prefs.getBool('isMusicMuted') ?? false;
    AudioManager.isSfxMuted = prefs.getBool('isSfxMuted') ?? false;
    
    // --- CARREGAR IDIOMA ---
    // O padrão será português ('pt') se for a primeira vez
    String savedLang = prefs.getString('language') ?? 'pt';
    I18n.currentLanguage = (savedLang == 'en') ? AppLanguage.en : AppLanguage.pt;
  }

  static Future<void> saveBgmVolume(int level) async {
    await prefs.setInt('bgmVolume', level);
  }

  static Future<void> saveSfxVolume(int level) async {
    await prefs.setInt('sfxVolume', level);
  }
  // Métodos para salvar cada alteração individualmente
  static Future<void> saveMusic(bool isMuted) async {
    await prefs.setBool('isMusicMuted', isMuted);
  }

  static Future<void> saveSfx(bool isMuted) async {
    await prefs.setBool('isSfxMuted', isMuted);
  }

  static Future<void> saveLanguage(AppLanguage lang) async {
    String langCode = (lang == AppLanguage.en) ? 'en' : 'pt';
    await prefs.setString('language', langCode);
  }
}