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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("DUNGEON CRAWLER", style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Palette.vermelho, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () => game.startGame(),
              child: const Text("INICIAR NOVO JOGO", style: TextStyle(fontFamily: 'pixelFont', fontSize: 18, color: Palette.branco)),
            ),
          ],
        ),
      ),
    );
  }
}