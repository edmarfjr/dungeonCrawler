import 'package:flutter/material.dart';
import 'dart:math';

enum TileType { wall, floor, door, exit, chest, spike }
enum Direction { north, east, south, west } 

class DungeonMap {
  final int width;
  final int height;
  late List<List<TileType>> grid;
  late List<List<bool>> explored; 

  Point<int> playerSpawn = const Point(0, 0);
  late Point<int> doorPosition;
  Point<int>? keyPosition;

  int spikeState = 0;

  void advanceSpikes() {
    spikeState = (spikeState + 1) % 3; // Fica rodando: 0, 1, 2, 0, 1, 2...
  }

  DungeonMap({this.width = 20, this.height = 20}) {
    generateProceduralMap(); 
  }

  void generateProceduralMap() {
    grid = List.generate(height, (_) => List.filled(width, TileType.wall));
    explored = List.generate(height, (_) => List.filled(width, false)); 
    
    final random = Random();
    int currentX = width ~/ 2;
    int currentY = height ~/ 2;
    
    playerSpawn = Point(currentX, currentY);
    grid[currentY][currentX] = TileType.floor;

    int floorCount = 1;
    final int maxFloors = (width * height * 0.35).toInt(); 
    List<Point<int>> floorTiles = [playerSpawn];

    int currentDirection = random.nextInt(4);

    // --- GERAÇÃO DO LABIRINTO (Com inércia para corredores longos) ---
    while (floorCount < maxFloors) {
      if (random.nextDouble() > 0.8) {
        currentDirection = random.nextInt(4);
      }

      int dx = 0, dy = 0;
      switch (currentDirection) {
        case 0: dy = -1; break; 
        case 1: dx = 1; break;  
        case 2: dy = 1; break;  
        case 3: dx = -1; break; 
      }

      int nextX = currentX + dx;
      int nextY = currentY + dy;

      if (nextX > 0 && nextX < width - 1 && nextY > 0 && nextY < height - 1) {
        currentX = nextX;
        currentY = nextY;

        if (grid[currentY][currentX] == TileType.wall) {
          grid[currentY][currentX] = TileType.floor;
          floorTiles.add(Point(currentX, currentY)); 
          floorCount++;
        }
      } else {
        currentDirection = random.nextInt(4);
      }
    }
    
    // ==========================================================
    // --- DISTRIBUIÇÃO SEGURA DE OBJETOS (SEM SOBREPOSIÇÃO) ---
    // ==========================================================

    // 1. Define a PORTA no último bloco gerado (mais longe)
    doorPosition = floorTiles.last;
    grid[doorPosition.y][doorPosition.x] = TileType.door;

    // 2. Tira a porta e o lugar onde o jogador nasce da lista de "lugares livres"
    floorTiles.remove(playerSpawn);
    floorTiles.remove(doorPosition);
    
    // 3. Embaralha todos os lugares livres restantes
    floorTiles.shuffle(random);

    // 4. Coloca a CHAVE (Pega a 1ª coordenada da lista embaralhada e REMOVE ela da lista)
    if (floorTiles.isNotEmpty) {
      keyPosition = floorTiles.removeAt(0); 
    } else {
      keyPosition = playerSpawn; 
    }

    // 5. Coloca os BAÚS (Pega as próximas coordenadas livres e REMOVE)
    int numChests = random.nextInt(3) + 1; 
    for (int i = 0; i < numChests; i++) {
      if (floorTiles.isNotEmpty) {
        Point<int> chestPos = floorTiles.removeAt(0);
        grid[chestPos.y][chestPos.x] = TileType.chest; 
      }
    }

    // 6. Coloca as ARMADILHAS (Pega as próximas coordenadas livres e REMOVE)
    int numSpikes = random.nextInt(6) + 4; 
    for (int i = 0; i < numSpikes; i++) {
      if (floorTiles.isNotEmpty) {
        Point<int> spikePos = floorTiles.removeAt(0); 
        grid[spikePos.y][spikePos.x] = TileType.spike; 
      }
    }
  }

  TileType getTile(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return TileType.wall;
    return grid[y][x]; 
  }

  void markExplored(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      explored[y][x] = true;
    }
  }
}