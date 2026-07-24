import 'package:dungeon_crawler/game/components/core/i18n.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class GameOverOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final tempoAtual = game.getFormattedRunTime();
    final bool isDesktop = game.isDesktopLayout;

    return Container(
      color: Palette.vermelho.withOpacity(0.5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableW = constraints.maxWidth;
          final double availableH = constraints.maxHeight;

          // Escala responsiva das fontes
          final double titleSize = (availableW * 0.08).clamp(28.0, 48.0);
          final double subtitleSize = (availableW * 0.04).clamp(14.0, 20.0);
          final double optionSize = (availableW * 0.045).clamp(16.0, 24.0);
          
          // Escala responsiva do espaçamento
          final double spacing = (availableH * 0.05).clamp(10.0, 60.0);

          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ValueListenableBuilder<int>(
                valueListenable: game.mainMenuCursor,
                builder: (context, cursorIndex, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text(
                        I18n.t('game_over'), 
                        style: TextStyle(
                          fontFamily: 'pixelFont', 
                          color: Palette.branco, 
                          fontSize: titleSize, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 2,
                          decoration: TextDecoration.none, 
                        )
                      ),
                      SizedBox(height: spacing * 0.2),
                      Text(
                        I18n.t('time') + tempoAtual,
                        style: TextStyle(
                          fontFamily: 'pixelFont',
                          color: Palette.branco,
                          fontSize: subtitleSize,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: spacing),
                      _buildMenuOption(
                          title: I18n.t('try_again'),
                          index: 0,
                          currentIndex: cursorIndex,
                          isDesktop: isDesktop,
                          fontSize: optionSize,
                        ),
                        SizedBox(height: spacing * 0.3),
                        _buildMenuOption(
                          title: I18n.t('main_menu'),
                          index: 1,
                          currentIndex: cursorIndex,
                          isDesktop: isDesktop,
                          fontSize: optionSize,
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildMenuOption({
    required String title, 
    required int index, 
    required int currentIndex,
    required bool isDesktop,
    required double fontSize,
  }) {
    bool isSelected = (index == currentIndex);

    return MouseRegion(
      onEnter: (_) {
        if (isDesktop) {
          game.mainMenuCursor.value = index;
        }
      },
      child: GestureDetector(
        onTap: () {
          game.mainMenuCursor.value = index;
          game.startInput(GameInput.buttonA);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min, // Restringe a área de clique ao texto
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A SETINHA DE SELEÇÃO:
            Text(
              isSelected ? "> " : "  ",
              style: TextStyle(
                fontFamily: 'pixelFont',
                fontSize: fontSize,
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
                fontSize: fontSize,
                color: isSelected ? Palette.amarelo : Palette.branco,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}