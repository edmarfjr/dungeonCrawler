import 'package:a_blade_in_the_abyss/game/components/core/audio_manager.dart';
import 'package:a_blade_in_the_abyss/game/components/core/i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    AudioManager.bgmVolumeLevel = prefs.getInt('bgmVolume') ?? 3; 
    AudioManager.sfxVolumeLevel = prefs.getInt('sfxVolume') ?? 10; 
    AudioManager.applyVolumes(); 
    
    // --- CARREGAR ÁUDIO ---
    AudioManager.isMusicMuted = prefs.getBool('isMusicMuted') ?? false;
    AudioManager.isSfxMuted = prefs.getBool('isSfxMuted') ?? false;
    
    // --- CARREGAR IDIOMA ---
    String savedLang = prefs.getString('language') ?? 'en';
    I18n.currentLanguage = (savedLang == 'en') ? AppLanguage.en : AppLanguage.pt;
  }

  static Future<void> saveBgmVolume(int level) async {
    await prefs.setInt('bgmVolume', level);
  }

  static Future<void> saveSfxVolume(int level) async {
    await prefs.setInt('sfxVolume', level);
  }
  
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