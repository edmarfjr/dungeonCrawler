import 'dart:math';

import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class PauseMenuOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const PauseMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Container(
      color: Palette.preto.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("JOGO PAUSADO", style: TextStyle(color: Palette.branco, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Andar Atual: ${game.player.floorLevel}", style: const TextStyle(color: Palette.amarelo, fontSize: 18)),
            const SizedBox(height: 10),
            Text("Essências: ${game.playerCombatStats.essence}", style: const TextStyle(color: Palette.azul, fontSize: 18)),
            const SizedBox(height: 10),
            Container(
              width: screenSize.width * 0.50,  
              height: screenSize.height * 0.25,
              decoration: BoxDecoration(
                color: Colors.black, // Fundo do mapa
                border: Border.all(color: Palette.cinza, width: 3), // Borda estilo Gameboy
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CustomPaint(
                  // Passamos as informações do labirinto atual para o pintor
                  painter: _MapPainter(
                    map: game.dungeon,
                    playerX: game.player.x,
                    playerY: game.player.y,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Palette.cinza, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () => game.togglePause(),
              child: const Text("CONTINUAR", style: TextStyle(fontSize: 18, color: Palette.branco)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => game.quitToMainMenu(),
              child: const Text("VOLTAR AO MENU PRINCIPAL", style: TextStyle(color: Palette.vermelho, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => {game.showHitboxes = !game.showHitboxes},
              child: const Text("debug", style: TextStyle(color: Palette.vermelho, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final DungeonMap map;
  final int playerX;
  final int playerY;

  _MapPainter({required this.map, required this.playerX, required this.playerY});

  @override
  void paint(Canvas canvas, Size size) {
    if (map.grid.isEmpty) return;

    int rows = map.height;
    int cols = map.width;

    double tileSize = min(size.width / cols, size.height / rows);
    double offsetX = (size.width - (cols * tileSize)) / 2;
    double offsetY = (size.height - (rows * tileSize)) / 2;

    final paintWall = Paint()..color = Palette.branco;
    final paintFloor = Paint()..color = Palette.cinzaMed;
    final paintDoor = Paint()..color = Palette.vermelhoEsc;
    final paintChest = Paint()..color = Palette.amarelo;
    final paintSpike = Paint()..color = map.spikeState == 0 ? Palette.cinzaCla : Palette.cinzaEsc;
    final paintShrine = Paint()..color = Palette.roxo;
    //final paintGrid = Paint()..color = Colors.white12..style = PaintingStyle.stroke;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        
        bool isExplored = map.explored[y][x]; 
        
        if (!isExplored) {
          continue;
        }

        Rect tileRect = Rect.fromLTWH(offsetX + x * tileSize, offsetY + y * tileSize, tileSize, tileSize);
        //Rect tileRectMenor = Rect.fromLTWH(offsetX + x * tileSize/2, offsetY + y * tileSize/2, tileSize/2, tileSize/2);

        TileType tile = map.grid[y][x];
        if (tile == TileType.wall) canvas.drawRect(tileRect, paintWall);
        else if (tile == TileType.floor) canvas.drawRect(tileRect, paintFloor);
        else if (tile == TileType.door) canvas.drawRect(tileRect, paintDoor);
        else if (tile == TileType.chest) canvas.drawRect(tileRect, paintChest);
        else if (tile == TileType.shrine) canvas.drawRect(tileRect, paintShrine);
        else if (tile == TileType.spike) canvas.drawRect(tileRect, paintSpike);

        // Desenha a borda do bloco apenas nos blocos visíveis
        //canvas.drawRect(tileRect, paintGrid);
      }
    }

    // Desenha o Jogador
    Rect tileRect = Rect.fromLTWH(offsetX + playerX * tileSize, offsetY + playerY * tileSize, tileSize, tileSize);
    final playerPaint = Paint()..color = Palette.azul;
    //canvas.drawCircle(
    //  Offset(offsetX + playerX * tileSize + tileSize / 2, offsetY + playerY * tileSize + tileSize / 2),
    //  tileSize / 2.5, 
    //  playerPaint,
    //);

    canvas.drawRect(tileRect, playerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}