import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class GameOverOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.vermelho.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("VOCÊ MORREU", style: TextStyle(color: Palette.branco, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Você sobreviveu até o Andar ${game.player.floorLevel}", style: const TextStyle(color: Palette.branco, fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Palette.preto, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () => game.startGame(),
              child: const Text("TENTAR NOVAMENTE", style: TextStyle(fontSize: 18, color: Palette.branco)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => game.quitToMainMenu(),
              child: const Text("MENU PRINCIPAL", style: TextStyle(color: Palette.branco, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}