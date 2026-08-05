import 'dart:math';

import 'package:a_blade_in_the_abyss/game/components/core/dungeon_map.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MinimapRenderer extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  final int viewRadius = 7;
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    if (gameRef.currentState != GameState.exploration) return;

    // =====================================================================
    // 1. APLICA A ESCALA GLOBAL DO JOGO
    // =====================================================================
    final bool isDesktop = gameRef.isDesktopLayout;
    double scaleFactor = isDesktop 
        ? (gameRef.size.y / 720.0).clamp(0.1, 5.0) 
        : (gameRef.size.x / 400.0).clamp(0.1, 5.0);

    double logicalWidth = gameRef.size.x / scaleFactor;
    double logicalHeight = gameRef.size.y / scaleFactor;

    // Ajusta o tamanho dos blocos para caber perfeitamente na HUD do PC ou Mobile
    double tileSize = isDesktop ? 11.5 : 4.0;

    int viewDiameter = (viewRadius * 2) + 1; 
    double mapWidth = viewDiameter * tileSize;
    double mapHeight = viewDiameter * tileSize;
    
    // 3. POSICIONA O MINIMAPA BASEADO NO DISPOSITIVO
    double startX = 0;
    double startY = 0;

    if (isDesktop) {
      double panelWidth = 260.0;
      double rightPanelX = logicalWidth - panelWidth;
      // PC: Centralizado dentro do painel lateral direito, abaixo do andar
      startX = rightPanelX + (panelWidth - mapWidth) / 2;
      startY = 35; 
    } else {
      double topHudHeight = 0;
      //double margin = 0;
      // Mobile: Canto superior direito da tela de exploração (com margem de respiro)
      startX = logicalWidth - mapWidth - 3;
      startY = topHudHeight + 9;
    }

    // Salva o canvas para aplicar a escala
    canvas.save();
    canvas.scale(scaleFactor, scaleFactor);

    final map = gameRef.dungeon;
    final player = gameRef.player;

    final backgroundRect = Rect.fromLTWH(startX, startY, mapWidth, mapHeight);

    // 4. Fundo do Minimapa e Borda externa
    /*canvas.drawRect(
      Rect.fromLTWH(startX - 4, startY - 4, mapWidth + 8, mapHeight + 8), 
      Paint()..color = Palette.marromCla
    );
    */
    
    canvas.drawRect(backgroundRect, Paint()..color = Palette.preto);
    
    // Salva novamente apenas para o Clipping interno do minimapa
    canvas.save();
    canvas.clipRect(backgroundRect);

    // =====================================================================
    // A MÁGICA: TRAVA DE CÂMARA (CLAMPING)
    // =====================================================================
    int cameraX = player.x;
    int cameraY = player.y;

    int minCam = viewRadius;
    int maxCamX = max(minCam, map.width - 1 - viewRadius);
    int maxCamY = max(minCam, map.height - 1 - viewRadius);

    if (cameraX < minCam) cameraX = minCam;
    if (cameraX > maxCamX) cameraX = maxCamX;
    
    if (cameraY < minCam) cameraY = minCam;
    if (cameraY > maxCamY) cameraY = maxCamY;

    int startMapX = cameraX - viewRadius;
    int startMapY = cameraY - viewRadius;
    // =====================================================================

    // 5. DESENHO DOS BLOCOS DA MASMORRA
    for (int y = 0; y < viewDiameter; y++) {
      for (int x = 0; x < viewDiameter; x++) {
        
        int mapX = startMapX + x;
        int mapY = startMapY + y;

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
            tilePaint.strokeWidth = 2;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.wall:
            tilePaint.color = Palette.branco;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.floor:
            tilePaint.color = Palette.azulEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.door:
            tilePaint.color = Palette.vermelhoEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.chest:
            tilePaint.color = Palette.amarelo;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.boss:
            tilePaint.color = Palette.vermelho;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break; 
          case TileType.openChest:
            tilePaint.color = Palette.amarelo;
            tilePaint.style = PaintingStyle.stroke;
            tilePaint.strokeWidth = 2;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY , tileSize, tileSize), tilePaint);
            break;
          case TileType.spike:
            tilePaint.color = map.spikeState == 2 ? Palette.cinza : Palette.cinzaEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.poison:
            tilePaint.color = map.poisonState == 3 || map.poisonState == 4 ? Palette.verde : Palette.cinzaEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.shrine:
            tilePaint.color = Palette.roxo;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.brokenShrine:
            tilePaint.color = Palette.roxo;
            tilePaint.style = PaintingStyle.stroke;
            tilePaint.strokeWidth = 2;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.crate:
            tilePaint.color = Palette.marromEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.openCrate:
            tilePaint.color = Palette.marromEsc;
            tilePaint.style = PaintingStyle.stroke;
            tilePaint.strokeWidth = 2;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.shop:
            tilePaint.color = Palette.azulCla;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.teleport:
            tilePaint.color = map.teleportState == 3 || map.teleportState == 4 ? Palette.rosa : Palette.cinzaEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.font:
          case TileType.fontPoison:
            tilePaint.color = Palette.azul;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.secretWall:
            tilePaint.color = Palette.PlumEsc;
            tilePaint.style = PaintingStyle.stroke;
            tilePaint.strokeWidth = 2;
            canvas.drawRect(Rect.fromLTWH(renderX , renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.lore:
            tilePaint.color = Palette.marromCla;
            //tilePaint.style = PaintingStyle.stroke;
            //tilePaint.strokeWidth = 2;
            canvas.drawRect(Rect.fromLTWH(renderX , renderY, tileSize, tileSize), tilePaint);
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

    // 6. DESENHO DOS INIMIGOS PRÓXIMOS
    final enemyPaint = Paint()..color = Palette.vermelho;
    for (var enemy in map.roamingEnemies) {
      if (map.explored[enemy.y][enemy.x]) {
        int ex = enemy.x - startMapX;
        int ey = enemy.y - startMapY;
        
        if (ex >= 0 && ex < viewDiameter && ey >= 0 && ey < viewDiameter) {
          double renderX = startX + (ex * tileSize);
          double renderY = startY + (ey * tileSize);
          canvas.drawCircle(Offset(renderX+tileSize/2, renderY+tileSize/2), tileSize/2, enemyPaint);
        }
      }
    }

    // 7. DESENHO DO JOGADOR
    int playerRelX = player.x - startMapX;
    int playerRelY = player.y - startMapY;
    
    double playerRenderX = startX + (playerRelX * tileSize);
    double playerRenderY = startY + (playerRelY * tileSize);
    
    double centerX = playerRenderX + (tileSize / 2);
    double centerY = playerRenderY + (tileSize / 2);

    canvas.save(); 
    
    canvas.translate(centerX, centerY);

    double angle = 0;
    switch (player.facing) {
      case Direction.north: angle = 0; break;
      case Direction.east:  angle = pi / 2; break; // 90 graus
      case Direction.south: angle = pi; break;     // 180 graus
      case Direction.west:  angle = -pi / 2; break;// -90 graus
    }
    canvas.rotate(angle);

    Path playerPath = Path();
    double sizeArrow = tileSize * 0.4; 
    
    playerPath.moveTo(0, -sizeArrow); 
    playerPath.lineTo(sizeArrow, sizeArrow); 
    playerPath.lineTo(-sizeArrow, sizeArrow); 
    playerPath.close();

    canvas.drawPath(playerPath, Paint()..color = Palette.vermelho);
    canvas.drawRect(Rect.fromLTWH(-sizeArrow/3, -sizeArrow, sizeArrow/1.5, sizeArrow/1.5), Paint()..color = Palette.branco);

    

    // Restaura o Clipping interno do minimapa
    canvas.restore();
    
  }
}