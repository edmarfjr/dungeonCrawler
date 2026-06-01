import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class MinimapRenderer extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  final double tileSize = 5.0; // Tamanho de cada bloco no minimapa em pixels

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Mostra o minimapa apenas na fase de exploração
    if (gameRef.currentState != GameState.exploration) return;

    final map = gameRef.dungeon;
    final player = gameRef.player;

    double mapWidth = map.width * tileSize;
    double mapHeight = map.height * tileSize;
    double startX = gameRef.size.x - mapWidth - 15.0;
    double startY = 15.0; 
    // 1. Fundo do Minimapa (Borda preta translúcida)
    canvas.drawRect(
      Rect.fromLTWH(startX - 2, startY - 2, mapWidth + 4, mapHeight + 4),
      Paint()..color = Colors.black.withOpacity(0.6)
    );

    canvas.drawRect(
      Rect.fromLTWH(startX - 2, startY - 2, mapWidth + 4, mapHeight + 4),
      Paint()..color = Colors.white.withOpacity(0.6) ..style = PaintingStyle.stroke ..strokeWidth = 1
    );

    // 2. Desenha os Blocos (Apenas os Explorados)
    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        if (map.explored[y][x]) {
          TileType tile = map.grid[y][x];
          Color color = Colors.transparent;

          if (tile == TileType.floor) color = Palette.cinza;
          else if (tile == TileType.wall) color = Palette.marrom;
          else if (tile == TileType.door) color = Palette.vermelhoEsc;

          if (color != Colors.transparent) {
            canvas.drawRect(
              Rect.fromLTWH(startX + x * tileSize, startY + y * tileSize, tileSize, tileSize),
              Paint()..color = color
            );
          }

          // Se a chave estiver aqui e o chão foi explorado, desenha um pontinho amarelo
          if (map.keyPosition != null && map.keyPosition!.x == x && map.keyPosition!.y == y) {
            canvas.drawRect(
              Rect.fromLTWH(startX + x * tileSize + 1, startY + y * tileSize + 1, tileSize - 2, tileSize - 2),
              Paint()..color = Palette.amarelo
            );
          }
        }
      }
    }

    final enemyPaint = Paint()..color = Palette.vermelho;
    
    for (var enemy in gameRef.dungeon.roamingEnemies) {
      // Opcional: Só desenha no minimapa se a área em que o inimigo está já foi iluminada pelo Fog of War!
      if (gameRef.dungeon.explored[enemy.y][enemy.x]) {
        canvas.drawRect(
          Rect.fromLTWH(
            startX + (enemy.x * tileSize), 
            startY + (enemy.y * tileSize), 
            tileSize, 
            tileSize
          ), 
          enemyPaint
        );
      }
    }

    // 3. Desenha o Jogador (Um ponto azul)
    double px = startX + player.x * tileSize;
    double py = startY + player.y * tileSize;
    canvas.drawRect(Rect.fromLTWH(px, py, tileSize, tileSize), Paint()..color = Palette.azul);

    // 4. Desenha um indicador minúsculo apontando a direção do jogador
    double dx = 0, dy = 0;
    switch (player.facing) {
      case Direction.north: dy = -tileSize; break;
      case Direction.east: dx = tileSize; break;
      case Direction.south: dy = tileSize; break;
      case Direction.west: dx = -tileSize; break;
    }
    canvas.drawRect(
      Rect.fromLTWH(px + dx * 0.6 + 1, py + dy * 0.6 + 1, tileSize - 2, tileSize - 2),
      Paint()..color = Palette.verde
    );
  }
}