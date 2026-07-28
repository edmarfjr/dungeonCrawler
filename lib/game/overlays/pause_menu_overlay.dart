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
    final tempoAtual = game.getFormattedRunTime();
    final bool isDesktop = game.isDesktopLayout;
    
    return Container(
      color: Palette.preto.withOpacity(0.85),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableW = constraints.maxWidth;
          final double availableH = constraints.maxHeight;

          // Fontes responsivas
          final double titleSize = (availableW * 0.07).clamp(20.0, 36.0);
          final double subtitleSize = (availableW * 0.04).clamp(14.0, 20.0);
          final double optionSize = (availableW * 0.045).clamp(16.0, 24.0);
          final double spacing = (availableH * 0.02).clamp(5.0, 20.0);

          // Tamanho do mapa adaptativo
          final double mapWidth = (availableW * 0.6).clamp(150.0, 400.0);
          final double mapHeight = (availableH * 0.3).clamp(100.0, 250.0);

          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "JOGO PAUSADO", 
                    style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: titleSize, fontWeight: FontWeight.bold, decoration: TextDecoration.none)
                  ),
                  SizedBox(height: spacing),
                  Text(
                    "Andar Atual: ${game.dungeon.level}", 
                    style: TextStyle(fontFamily: 'pixelFont', color: Palette.amarelo, fontSize: subtitleSize, decoration: TextDecoration.none)
                  ),
                  SizedBox(height: spacing * 0.5),
                  Text(
                    "Essências: ${game.playerCombatStats.essence.toInt()}", 
                    style: TextStyle(fontFamily: 'pixelFont', color: Palette.azul, fontSize: subtitleSize, decoration: TextDecoration.none)
                  ),
                  SizedBox(height: spacing * 0.5),
                  Text(
                    'TEMPO: $tempoAtual',
                    style: TextStyle(
                      fontFamily: 'pixelFont',
                      color: Palette.branco,
                      fontSize: subtitleSize,
                      decoration: TextDecoration.none
                    ),
                  ),
                  SizedBox(height: spacing),
                  
                  // --- O MAPA ---
                  Container(
                    width: mapWidth,  
                    height: mapHeight,
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
                  SizedBox(height: spacing * 1.5),

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
                            isDesktop: isDesktop, fontSize: optionSize,
                          ),
                          SizedBox(height: spacing),
                          
                          _buildMenuOption(
                            title: I18n.t('pause_main_menu'),
                            index: 1,
                            currentIndex: cursorIndex,
                            color: Palette.branco,
                            isDesktop: isDesktop, fontSize: optionSize,
                          ),
                          SizedBox(height: spacing),
                          
                          _buildMenuOption(
                            title: I18n.t('menu_settings'),
                            index: 2,
                            currentIndex: cursorIndex,
                            color: Palette.branco,
                            isDesktop: isDesktop, fontSize: optionSize,
                          ),
                         /* _buildMenuOption(
                            title:'debug-hitbox',
                            index: 3,
                            currentIndex: cursorIndex,
                            color: Palette.branco,
                            isDesktop: isDesktop, fontSize: optionSize,
                          ),
                          */
                          SizedBox(height: spacing),
                        ],
                      );
                    },
                  ),
                ],
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
    required Color color,
    required bool isDesktop,
    required double fontSize,
  }) {
    bool isSelected = (index == currentIndex);

    return MouseRegion(
      onEnter: (_) {
        if (isDesktop) game.pauseMenuCursor.value = index;
      },
      child: GestureDetector(
        onTap: () {
          game.pauseMenuCursor.value = index;
          game.startInput(GameInput.buttonA);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            Text(
              title,
              style: TextStyle(
                fontFamily: 'pixelFont',
                fontSize: fontSize,
                color: isSelected ? Palette.amarelo : color,
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
    final paintLore = Paint()..color = Palette.bege;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        
        bool isExplored = map.explored[y][x]; 
        
        if (!isExplored) {
          continue;
        }

        Rect tileRect = Rect.fromLTWH(offsetX + x * tileSize, offsetY + y * tileSize, tileSize, tileSize);

        TileType tile = map.grid[y][x];
        if (tile == TileType.wall) {
          canvas.drawRect(tileRect, paintWall);
        } else if (tile == TileType.floor) {
          canvas.drawRect(tileRect, paintFloor);
        } else if (tile == TileType.door) {
          canvas.drawRect(tileRect, paintDoor);
        } else if (tile == TileType.chest) {
          canvas.drawRect(tileRect, paintChest);
        } else if (tile == TileType.shrine) {
          canvas.drawRect(tileRect, paintShrine);
        } else if (tile == TileType.spike) {
          canvas.drawRect(tileRect, paintSpike);
        } else if (tile == TileType.poison) {
          canvas.drawRect(tileRect, paintPoison);
        } else if (tile == TileType.teleport) {
          canvas.drawRect(tileRect, paintTele);
        } else if (tile == TileType.boss) {
          canvas.drawRect(tileRect, paintBoss);
        } else if (tile == TileType.crate) {
          canvas.drawRect(tileRect, paintCrate);
        } else if (tile == TileType.shop) {
          canvas.drawRect(tileRect, paintShop);
        } else if (tile == TileType.secretWall) {
          canvas.drawRect(tileRect, paintSecretWall);
        } else if (tile == TileType.lore) {
          canvas.drawRect(tileRect, paintLore);
        } else if (tile == TileType.font || tile == TileType.fontPoison) {
          canvas.drawRect(tileRect, paintFont);
        }

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
    playerPath.lineTo(-sizeArrow, sizeArrow); 
    playerPath.close();

    canvas.drawPath(playerPath, Paint()..color = Palette.vermelho);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}