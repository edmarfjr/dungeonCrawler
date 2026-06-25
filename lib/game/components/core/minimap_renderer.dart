import 'dart:math';

import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MinimapRenderer extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  final double tileSize = 4.0;
  final int viewRadius = 7;
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    if (gameRef.currentState != GameState.exploration) return;

    final map = gameRef.dungeon;
    final player = gameRef.player;

    int viewDiameter = (viewRadius * 2) + 1; 
    double mapWidth = viewDiameter * tileSize;
    double mapHeight = viewDiameter * tileSize;
    
    double startX = gameRef.size.x - mapWidth;
    double startY = 0.0; 

    final backgroundRect = Rect.fromLTWH(startX, startY, mapWidth, mapHeight);

    // 1. Fundo do Minimapa
    canvas.drawRect(backgroundRect, Paint()..color = Palette.preto);
    canvas.save();
    canvas.clipRect(backgroundRect);

    // =====================================================================
    // A MÁGICA: TRAVA DE CÂMARA (CLAMPING)
    // =====================================================================
    int cameraX = player.x;
    int cameraY = player.y;

    // Impede que a câmara tente mostrar o vazio além das bordas do mapa!
    int minCam = viewRadius;
    int maxCamX = max(minCam, map.width - 1 - viewRadius);
    int maxCamY = max(minCam, map.height - 1 - viewRadius);

    if (cameraX < minCam) cameraX = minCam;
    if (cameraX > maxCamX) cameraX = maxCamX;
    
    if (cameraY < minCam) cameraY = minCam;
    if (cameraY > maxCamY) cameraY = maxCamY;

    // Define qual é o bloco que fica no canto superior esquerdo do minimapa
    int startMapX = cameraX - viewRadius;
    int startMapY = cameraY - viewRadius;
    // =====================================================================


    // 2. DESENHO DOS BLOCOS DA MASMORRA
    for (int y = 0; y < viewDiameter; y++) {
      for (int x = 0; x < viewDiameter; x++) {
        
        int mapX = startMapX + x;
        int mapY = startMapY + y;

        // Se por algum motivo o mapa for minúsculo, previne erros
        if (mapX < 0 || mapX >= map.width || mapY < 0 || mapY >= map.height) continue;
        if (!map.explored[mapY][mapX]) continue;

        double renderX = startX + (x * tileSize);
        double renderY = startY + (y * tileSize);

        TileType tile = map.getTile(mapX, mapY);
        Paint tilePaint = Paint();

        switch (tile) {
          case TileType.entry:
            tilePaint.color = Palette.branco;
            tilePaint.style = PaintingStyle.stroke;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.wall:
            tilePaint.color = Palette.branco;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.floor:
            tilePaint.color = Palette.cinzaMed;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.door:
            tilePaint.color = Palette.vermelhoEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.chest:
            tilePaint.color = Palette.amarelo;
            canvas.drawRect(Rect.fromLTWH(renderX + 1, renderY + 1, tileSize, tileSize), tilePaint);
            break;
          case TileType.boss:
            tilePaint.color = Palette.vermelho;
            canvas.drawRect(Rect.fromLTWH(renderX + 1, renderY + 1, tileSize, tileSize), tilePaint);
            break; 
          case TileType.openChest:
            tilePaint.color = Palette.amarelo;
            tilePaint.style = PaintingStyle.stroke;
            canvas.drawRect(Rect.fromLTWH(renderX + 1, renderY + 1, tileSize, tileSize), tilePaint);
            break;
          case TileType.spike:
            tilePaint.color = map.spikeState == 0 ? Palette.cinzaCla : Palette.cinzaEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.poison:
            tilePaint.color = map.spikeState == 0 ? Palette.cinzaCla : Palette.verde;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.shrine:
            tilePaint.color = Palette.roxo;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.crate:
            tilePaint.color = Palette.marrom;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.shop:
            tilePaint.color = Palette.azulCla;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.font:
            tilePaint.color = Palette.azul;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
        }

        if (map.keyPosition != null && map.keyPosition!.x == mapX && map.keyPosition!.y == mapY && !player.hasKey) {
          canvas.drawRect(Rect.fromLTWH(renderX + 1, renderY + 1, tileSize/2, tileSize/2), Paint()..color = Palette.amarelo);
        }

        if (map.droppedItems.containsKey(Point(mapX, mapY)) && map.droppedItems[Point(mapX, mapY)]!.isNotEmpty) {
          canvas.drawRect(Rect.fromLTWH(renderX + 2, renderY + 2, tileSize, tileSize), Paint()..color = Palette.azulCla);
        }
      }
    }

    // 3. DESENHO DOS INIMIGOS PRÓXIMOS
    final enemyPaint = Paint()..color = Palette.vermelho;
    for (var enemy in map.roamingEnemies) {
      if (map.explored[enemy.y][enemy.x]) {
        // Calcula a posição do inimigo relativa à câmara do minimapa
        int ex = enemy.x - startMapX;
        int ey = enemy.y - startMapY;
        
        // Só desenha se ele estiver dentro do visor do minimapa
        if (ex >= 0 && ex < viewDiameter && ey >= 0 && ey < viewDiameter) {
          double renderX = startX + (ex * tileSize);
          double renderY = startY + (ey * tileSize);
         //canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize-1, tileSize-1), enemyPaint);
          canvas.drawCircle(Offset(renderX+tileSize/2, renderY+tileSize/2), tileSize/2, enemyPaint);
        }
      }
    }

    // 4. DESENHO DO JOGADOR
    // O jogador agora move-se livremente no radar quando a câmara trava na parede!
    int playerRelX = player.x - startMapX;
    int playerRelY = player.y - startMapY;
    
    double playerRenderX = startX + (playerRelX * tileSize);
    double playerRenderY = startY + (playerRelY * tileSize);
    
    //canvas.drawRect(Rect.fromLTWH(playerRenderX, playerRenderY, tileSize, tileSize), Paint()..color = Palette.azul);
    canvas.drawCircle(Offset(playerRenderX+tileSize/2, playerRenderY+tileSize/2), tileSize/2, Paint()..color = Palette.azul);

    // Indicador de direção do jogador
    double dx = 0, dy = 0;
    switch (player.facing) {
      case Direction.north: dy = -tileSize * 0.35; break;
      case Direction.east:  dx = tileSize * 0.35;  break;
      case Direction.south: dy = tileSize * 0.35;  break;
      case Direction.west:  dx = -tileSize * 0.35; break;
    }
    
    canvas.drawRect(
      Rect.fromLTWH(playerRenderX + (tileSize/4) + dx, playerRenderY + (tileSize/4) + dy, tileSize/2, tileSize/2),
      Paint()..color = Palette.vermelhoCla
    );

    canvas.restore();
    
    // 5. Borda final por cima de tudo
    canvas.drawRect(
      backgroundRect, 
      Paint()
        ..color = Palette.branco
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
    );
  }
}