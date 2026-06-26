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
            const Text(
              "JOGO PAUSADO", 
              style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 28, fontWeight: FontWeight.bold, decoration: TextDecoration.none)
            ),
            const SizedBox(height: 10),
            Text(
              "Andar Atual: ${game.dungeon.level}", 
              style: const TextStyle(fontFamily: 'pixelFont', color: Palette.amarelo, fontSize: 18, decoration: TextDecoration.none)
            ),
            const SizedBox(height: 10),
            Text(
              "Essências: ${game.playerCombatStats.essence.toInt()}", 
              style: const TextStyle(fontFamily: 'pixelFont', color: Palette.azul, fontSize: 18, decoration: TextDecoration.none)
            ),
            const SizedBox(height: 10),
            
            // --- O MAPA ---
            Container(
              width: screenSize.width * 0.50,  
              height: screenSize.height * 0.25,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Palette.cinza, width: 3), 
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CustomPaint(
                  painter: _MapPainter(
                    map: game.dungeon,
                    playerX: game.player.x,
                    playerY: game.player.y,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            ValueListenableBuilder<int>(
              valueListenable: game.pauseMenuCursor,
              builder: (context, cursorIndex, child) {
                return Column(
                  children: [
                    _buildMenuOption(
                      title: "CONTINUAR",
                      index: 0,
                      currentIndex: cursorIndex,
                      color: Palette.branco,
                    ),
                    const SizedBox(height: 15),
                    
                    _buildMenuOption(
                      title: "VOLTAR AO MENU PRINCIPAL",
                      index: 1,
                      currentIndex: cursorIndex,
                      color: Palette.branco,
                    ),
                    const SizedBox(height: 15),
                    
                    _buildMenuOption(
                      title: "DEBUG (Hitboxes)",
                      index: 2,
                      currentIndex: cursorIndex,
                      color: Palette.vermelho,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required String title, 
    required int index, 
    required int currentIndex,
    required Color color,
  }) {
    bool isSelected = (index == currentIndex);

    return GestureDetector(
      onTap: () {
        game.pauseMenuCursor.value = index;
        game.startInput(GameInput.buttonA);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isSelected ? "> " : "  ",
            style: TextStyle(
              fontFamily: 'pixelFont',
              fontSize: 18,
              color: isSelected ? Palette.amarelo : Colors.transparent,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'pixelFont',
              fontSize: 18,
              color: isSelected ? Palette.amarelo : color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              decoration: TextDecoration.none,
            ),
          ),
        ],
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
    final paintBoss = Paint()..color = Palette.vermelhoCla;
    final paintChest = Paint()..color = Palette.amarelo;
    final paintKey = Paint()..color = Palette.laranja;
    final paintSpike = Paint()..color = map.spikeState == 0 ? Palette.cinzaCla : Palette.cinzaEsc;
    final paintPoison = Paint()..color = map.spikeState == 0 ? Palette.cinzaCla : Palette.verde;
    final paintShrine = Paint()..color = Palette.roxo;
    final paintCrate = Paint()..color = Palette.marrom;
    final paintShop = Paint()..color = Palette.azulCla;
    final fontShop = Paint()..color = Palette.azul;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        
        bool isExplored = map.explored[y][x]; 
        
        if (!isExplored) {
          continue;
        }

        Rect tileRect = Rect.fromLTWH(offsetX + x * tileSize, offsetY + y * tileSize, tileSize, tileSize);

        TileType tile = map.grid[y][x];
        if (tile == TileType.wall) canvas.drawRect(tileRect, paintWall);
        else if (tile == TileType.floor) canvas.drawRect(tileRect, paintFloor);
        else if (tile == TileType.door) canvas.drawRect(tileRect, paintDoor);
        else if (tile == TileType.chest) canvas.drawRect(tileRect, paintChest);
        else if (tile == TileType.shrine) canvas.drawRect(tileRect, paintShrine);
        else if (tile == TileType.spike) canvas.drawRect(tileRect, paintSpike);
        else if (tile == TileType.poison) canvas.drawRect(tileRect, paintPoison);
        else if (tile == TileType.boss) canvas.drawRect(tileRect, paintBoss);
        else if (tile == TileType.crate) canvas.drawRect(tileRect, paintCrate);
        else if (tile == TileType.shop) canvas.drawRect(tileRect, paintShop);
        else if (tile == TileType.font || tile == TileType.fontPoison) canvas.drawRect(tileRect, fontShop);

        if (map.keyPosition!.x == x && map.keyPosition!.y == y){
          canvas.drawRect(tileRect, paintKey);
        }

      }
    }

    // Desenha o Jogador
    //Rect tileRect = Rect.fromLTWH(offsetX + playerX * tileSize, offsetY + playerY * tileSize, tileSize, tileSize);
    final playerPaint = Paint()..color = Palette.azul;

    //canvas.drawRect(tileRect, playerPaint);
    canvas.drawCircle(Offset((offsetX + playerX * tileSize)+tileSize/2, (offsetY + playerY * tileSize)+tileSize/2), tileSize/2, playerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}