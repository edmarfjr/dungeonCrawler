import 'dart:math';

import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MinimapRenderer extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  final double tileSize = 4.0; // Tamanho de cada bloco no minimapa em pixels
  final int viewRadius = 7;
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Mostra o minimapa apenas na fase de exploração
    if (gameRef.currentState != GameState.exploration) return;

    final map = gameRef.dungeon;
    final player = gameRef.player;

    // Calcula o tamanho total da janela fixa em pixels
    int viewDiameter = (viewRadius * 2) + 1; // Ex: 7 + 7 + 1 = 15 blocos
    double mapWidth = viewDiameter * tileSize;
    double mapHeight = viewDiameter * tileSize;
    
    // Posiciona o minimapa no canto superior direito da tela
    double startX = gameRef.size.x - mapWidth ;
    double startY = 0.0; 

    // Guardar o estado do canvas para aplicar o recorte seguro (Clip)
    canvas.save();

    // 1. Fundo do Minimapa (Borda preta translúcida fixa)
    final backgroundRect = Rect.fromLTWH(startX, startY, mapWidth-1, mapHeight);
    canvas.drawRect(backgroundRect, Paint()..color = Palette.preto);
    canvas.drawRect(backgroundRect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

    // Máscara de Recorte: Garante que NADA desenhado saia para fora do quadrado do minimapa
    canvas.clipRect(Rect.fromLTWH(startX, startY, mapWidth, mapHeight));

    // 2. DESENHO DOS BLOCOS RELATIVOS À POSIÇÃO DO JOGADOR
    // Varre uma matriz restrita ao redor do jogador, e não o mapa inteiro!
    for (int offsetScaleY = -viewRadius; offsetScaleY <= viewRadius; offsetScaleY++) {
      for (int offsetScaleX = -viewRadius; offsetScaleX <= viewRadius; offsetScaleX++) {
        
        // Coordenada real dentro da matriz global da dungeon
        int mapX = player.x + offsetScaleX;
        int mapY = player.y + offsetScaleY;

        // Posição onde este bloco específico deve ser desenhado na tela
        double renderX = startX + (offsetScaleX + viewRadius) * tileSize;
        double renderY = startY + (offsetScaleY + viewRadius) * tileSize;

        // Se estiver fora dos limites da masmorra gerada, desenha o vazio/parede externa
        if (mapX < 0 || mapX >= map.width || mapY < 0 || mapY >= map.height) {
          canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), Paint()..color = Palette.preto);
          continue;
        }

        // Só desenha se o jogador já tiver explorado/iluminado este bloco (Fog of War)
        if (!map.explored[mapY][mapX]) continue;

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
            // Spikes mudam de cor conforme o estado da armadilha
            tilePaint.color = map.spikeState == 0 ? Palette.cinzaCla : Palette.cinzaEsc;
            canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize, tileSize), tilePaint);
            break;
          case TileType.poison:
            // Spikes mudam de cor conforme o estado da armadilha
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
        }

        // Desenha a Chave se ela estiver nessa posição e o jogador ainda não pegou
        if (map.keyPosition != null && map.keyPosition!.x == mapX && map.keyPosition!.y == mapY && !player.hasKey) {
          canvas.drawRect(
            Rect.fromLTWH(renderX + 1, renderY + 1, tileSize/2, tileSize/2),
            Paint()..color = Palette.amarelo
          );
        }

        if (map.droppedItems.containsKey(Point(mapX, mapY)) && map.droppedItems[Point(mapX, mapY)]!.isNotEmpty) {
          canvas.drawRect(
            Rect.fromLTWH(renderX + 2, renderY + 2, tileSize, tileSize),
            Paint()..color = Palette.azulCla
          );
        }
      }
    }

    // 3. DESENHO DOS INIMIGOS PRÓXIMOS
    final enemyPaint = Paint()..color = Palette.vermelho;
    for (var enemy in map.roamingEnemies) {
      // Verifica se o inimigo está dentro do raio visível do radar do minimapa
      int offsetX = enemy.x - player.x;
      int offsetY = enemy.y - player.y;

      if (offsetX.abs() <= viewRadius && offsetY.abs() <= viewRadius) {
        if (map.explored[enemy.y][enemy.x]) {
          double renderX = startX + (offsetX + viewRadius) * tileSize;
          double renderY = startY + (offsetY + viewRadius) * tileSize;
          canvas.drawRect(Rect.fromLTWH(renderX, renderY, tileSize-1, tileSize-1), enemyPaint);
        }
      }
    }

    // 4. DESENHO DO JOGADOR (Sempre centralizado no radar!)
    double playerRenderX = startX + viewRadius * tileSize;
    double playerRenderY = startY + viewRadius * tileSize;
    canvas.drawRect(Rect.fromLTWH(playerRenderX, playerRenderY, tileSize, tileSize), Paint()..color = Palette.azul);

    // 5. Indicador minúsculo de direção do jogador (Seta/Ponto de direção)
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

    // Restaurar o canvas para o estado original (remover o Clip) para não afetar o resto da interface
    canvas.restore();
  }
}