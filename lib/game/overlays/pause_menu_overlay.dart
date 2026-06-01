import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class PauseMenuOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const PauseMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.preto.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("JOGO PAUSADO", style: TextStyle(color: Palette.branco, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Andar Atual: ${game.player.floorLevel}", style: const TextStyle(color: Palette.amarelo, fontSize: 18)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Palette.cinza, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () => game.togglePause(),
              child: const Text("CONTINUAR", style: TextStyle(fontSize: 18, color: Palette.branco)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => game.quitToMainMenu(),
              child: const Text("VOLTAR AO MENU PRINCIPAL", style: TextStyle(color: Palette.vermelho, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}