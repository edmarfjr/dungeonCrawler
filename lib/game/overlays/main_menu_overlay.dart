import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class MainMenuOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.preto,
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: game.mainMenuCursor,
          builder: (context, cursorIndex, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "DUNGEON CRAWLER", 
                  style: TextStyle(
                    fontFamily: 'pixelFont', 
                    color: Palette.branco, 
                    fontSize: 32, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 2,
                    decoration: TextDecoration.none, // Remove sublinhados amarelos do Flutter
                  )
                ),
                const SizedBox(height: 60),

                // OPÇÃO 0: NOVO JOGO
                _buildMenuOption(
                  title: "INICIAR NOVO JOGO",
                  index: 0,
                  currentIndex: cursorIndex,
                ),
                
                const SizedBox(height: 20),

                // OPÇÃO 1: MANUAL
                _buildMenuOption(
                  title: "MANUAL DE INSTRUÇÕES",
                  index: 1,
                  currentIndex: cursorIndex,
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
        game.mainMenuCursor.value = index;
        game.startInput(GameInput.buttonA);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A SETINHA DE SELEÇÃO:
          Text(
            isSelected ? "> " : "  ",
            style: TextStyle(
              fontFamily: 'pixelFont',
              fontSize: 20,
              color: isSelected ? Palette.amarelo : Colors.transparent,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          // O TEXTO DO BOTÃO:
          Text(
            title,
            style: TextStyle(
              fontFamily: 'pixelFont',
              fontSize: 20,
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