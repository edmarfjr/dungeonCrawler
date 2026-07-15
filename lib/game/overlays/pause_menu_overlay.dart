import 'dart:math';
import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/i18n.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class PauseMenuOverlay extends StatelessWidget {
  final DungeonCrawlerGame game;
  const PauseMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final tempoAtual = game.getFormattedRunTime();
    
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
            Text(
              'TEMPO: $tempoAtual',
              style: const TextStyle(
                fontFamily: 'pixelFont',
                color: Palette.branco,
                fontSize: 16,
              ),
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
                    playerFacing: game.player.facing,
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
                      title: I18n.t('pause_continue'),
                      index: 0,
                      currentIndex: cursorIndex,
                      color: Palette.branco,
                    ),
                    const SizedBox(height: 15),
                    
                    _buildMenuOption(
                      title: I18n.t('pause_main_menu'),
                      index: 1,
                      currentIndex: cursorIndex,
                      color: Palette.branco,
                    ),
                    const SizedBox(height: 15),
                    
                    _buildMenuOption(
                      title: I18n.t('menu_settings'),
                      index: 2,
                      currentIndex: cursorIndex,
                      color: Palette.branco,
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
  final Direction playerFacing;

 _MapPainter({
    required this.map, 
    required this.playerX, 
    required this.playerY,
    required this.playerFacing, 
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (map.grid.isEmpty) return;

    int rows = map.height;
    int cols = map.width;

    double tileSize = min(size.width / cols, size.height / rows);
    double offsetX = (size.width - (cols * tileSize)) / 2;
    double offsetY = (size.height - (rows * tileSize)) / 2;

    final paintWall = Paint()..color = Palette.branco;
    final paintFloor = Paint()..color = Palette.cinzaEsc;
    final paintDoor = Paint()..color = Palette.vermelhoEsc;
    final paintBoss = Paint()..color = Palette.vermelhoCla;
    final paintChest = Paint()..color = Palette.amarelo;
    final paintKey = Paint()..color = Palette.laranja;
    final paintSpike = Paint()..color = map.spikeState == 3 ? Palette.cinzaCla : Palette.cinza;
    final paintTele = Paint()..color = map.teleportState == 3 || map.teleportState == 4 ? Palette.rosa : Palette.cinza;
    final paintPoison = Paint()..color = map.poisonState == 3 || map.poisonState == 4 ? Palette.verde : Palette.cinza;
    final paintShrine = Paint()..color = Palette.roxo;
    final paintCrate = Paint()..color = Palette.marrom;
    final paintShop = Paint()..color = Palette.azulCla;
    final paintFont = Paint()..color = Palette.azul;
    final paintSecretWall = Paint()..color = Palette.marromCla;

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
        else if (tile == TileType.teleport) canvas.drawRect(tileRect, paintTele);
        else if (tile == TileType.boss) canvas.drawRect(tileRect, paintBoss);
        else if (tile == TileType.crate) canvas.drawRect(tileRect, paintCrate);
        else if (tile == TileType.shop) canvas.drawRect(tileRect, paintShop);
        else if (tile == TileType.secretWall) canvas.drawRect(tileRect, paintSecretWall);
        else if (tile == TileType.font || tile == TileType.fontPoison) canvas.drawRect(tileRect, paintFont);

        if (map.keyPosition != null && map.keyPosition!.x == x && map.keyPosition!.y == y){
          canvas.drawRect(tileRect, paintKey);
        }

      }
    }

    // Desenha o Jogador
    // 1. Encontra o centro exato do tile onde o jogador está
    double centerX = offsetX + (playerX * tileSize) + (tileSize / 2);
    double centerY = offsetY + (playerY * tileSize) + (tileSize / 2);

    canvas.save(); 
    
    // 2. Move o eixo para o centro do jogador
    canvas.translate(centerX, centerY);

    // 3. Rotaciona o canvas baseado na direção
    double angle = 0;
    switch (playerFacing) {
      case Direction.north: angle = 0; break;
      case Direction.east:  angle = pi / 2; break; // 90 graus
      case Direction.south: angle = pi; break;     // 180 graus
      case Direction.west:  angle = -pi / 2; break;// -90 graus
    }
    canvas.rotate(angle);

    // 4. Desenha o Path da seta apontando para cima
    Path playerPath = Path();
    
    // Ajustamos o tamanho da seta para caber certinho dentro do Tile do mapa
    double sizeArrow = tileSize * 0.4; 
    
    playerPath.moveTo(0, -sizeArrow); 
    playerPath.lineTo(sizeArrow, sizeArrow); 
   // playerPath.lineTo(0, sizeArrow * 0.4); 
    playerPath.lineTo(-sizeArrow, sizeArrow); 
    playerPath.close();

    canvas.drawPath(playerPath, Paint()..color = Palette.vermelho);
    //canvas.drawPath(playerPath, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 1.0);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}