import 'package:dungeon_crawler/game/components/core/audio_manager.dart';
import 'package:dungeon_crawler/game/components/core/i18n.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class SettingsMenuOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const SettingsMenuOverlay({super.key, required this.game});

  String _buildVolumeBars(int level) {
    String bars = "";
    for (int i = 1; i <= 10; i++) {
      bars += (i <= level) ? "|" : "."; 
    }
    return "< $bars >";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.preto,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([game.settingsCursor, game.settingsRefresh]),
          builder: (context, child) {
            
            int cursorIndex = game.settingsCursor.value;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  I18n.t('menu_settings'), 
                  style: const TextStyle(
                    fontFamily: 'pixelFont', color: Palette.amarelo, 
                    fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2,
                    decoration: TextDecoration.none, 
                  )
                ),
                
                const SizedBox(height: 60),
                
                _buildMenuOption(
                  title: "${I18n.t('opt_music')}: ${_buildVolumeBars(AudioManager.bgmVolumeLevel)}",
                  index: 0, currentIndex: cursorIndex,
                ),
                const SizedBox(height: 20),
                
                _buildMenuOption(
                  title: "${I18n.t('opt_sfx')}: ${_buildVolumeBars(AudioManager.sfxVolumeLevel)}",
                  index: 1, currentIndex: cursorIndex,
                ),
                const SizedBox(height: 20),
                
                _buildMenuOption(
                  title: "${I18n.t('opt_lang')}: < ${I18n.t('lang_name')} >",
                  index: 2, currentIndex: cursorIndex,
                ),
                const SizedBox(height: 20),
                
                _buildMenuOption(
                  title: I18n.t('opt_back'),
                  index: 3, currentIndex: cursorIndex,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuOption({required String title, required int index, required int currentIndex}) {
    bool isSelected = (index == currentIndex);
    return GestureDetector(
      onTap: () {
        game.settingsCursor.value = index;
        game.startInput(GameInput.buttonA);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isSelected ? "> " : "  ",
            style: TextStyle(
              fontFamily: 'pixelFont', fontSize: 20,
              color: isSelected ? Palette.amarelo : Colors.transparent,
              fontWeight: FontWeight.bold, decoration: TextDecoration.none,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'pixelFont', fontSize: 20,
              color: isSelected ? Palette.amarelo : Palette.branco,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}