import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class GameOverOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final tempoAtual = game.getFormattedRunTime();

    return Container(
      color: Palette.vermelho.withOpacity(0.9),
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: game.mainMenuCursor,
          builder: (context, cursorIndex, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "VOCÊ MORREU", 
                  style: TextStyle(
                    fontFamily: 'pixelFont', 
                    color: Palette.branco, 
                    fontSize: 32, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 2,
                    decoration: TextDecoration.none, // Remove sublinhados amarelos do Flutter
                  )
                ),
                const SizedBox(height: 10),
                Text(
                  'TEMPO: $tempoAtual',
                  style: const TextStyle(
                    fontFamily: 'pixelFont',
                    color: Palette.branco,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 60),
                _buildMenuOption(
                    title: "TENTAR NOVAMENTE",
                    index: 0,
                    currentIndex: cursorIndex,
                  ),
                  const SizedBox(height: 20),
                  _buildMenuOption(
                    title: "MENU PRINCIPAL",
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

/*  Widget build(BuildContext context) {
    return Container(
      color: Palette.vermelho.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("VOCÊ MORREU", style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Você sobreviveu até o Andar ${game.player.floorLevel}", style: const TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Palette.preto, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () => game.startGame(),
              child: const Text("TENTAR NOVAMENTE", style: TextStyle(fontFamily: 'pixelFont', fontSize: 18, color: Palette.branco)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => game.quitToMainMenu(),
              child: const Text("MENU PRINCIPAL", style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
*/
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