import 'dart:math';

enum TileType { wall, floor, door, exit, chest, spike }
enum Direction { north, east, south, west } 

class DungeonMap {
  int width;
  int height;
  late List<List<TileType>> grid;
  late List<List<bool>> explored; 

  Point<int> playerSpawn = const Point(0, 0);
  late Point<int> doorPosition;
  Point<int>? keyPosition;

  int spikeState = 0;
  
  List<Point<int>> roamingEnemies = [];

  void advanceSpikes() {
    spikeState = (spikeState + 1) % 3;
  }

  DungeonMap({this.width = 20, this.height = 20}) { generateProceduralMap(); }

  int _calculateDistance(Point<int> p1, Point<int> p2) {
    return (p1.x - p2.x).abs() + (p1.y - p2.y).abs();
  }

  bool _isWalkable(int x, int y) {
    TileType t = getTile(x, y);
    return t == TileType.floor || t == TileType.spike;
  }

  void moveEnemies(Point<int> playerPos) {
    // Distância máxima que o inimigo consegue ver o jogador (em blocos)
    int aggroRange = 5; 

    for (int i = 0; i < roamingEnemies.length; i++) {
      Point<int> enemy = roamingEnemies[i];

      // 1. CHECAGEM DE DISTÂNCIA: Se o jogador estiver muito longe, o inimigo ignora e fica parado!
      if (_calculateDistance(enemy, playerPos) > aggroRange) {
        continue; 
      }

      int dx = playerPos.x - enemy.x;
      int dy = playerPos.y - enemy.y;

      if (dx == 0 && dy == 0) continue; // Já está em cima do jogador

      int stepX = dx == 0 ? 0 : dx.sign;
      int stepY = dy == 0 ? 0 : dy.sign;

      // 2. IA DE PERSEGUIÇÃO (Só roda se o jogador estiver dentro do aggroRange)
      if (dx.abs() > dy.abs()) {
        if (_isWalkable(enemy.x + stepX, enemy.y)) {
          roamingEnemies[i] = Point(enemy.x + stepX, enemy.y);
        } else if (stepY != 0 && _isWalkable(enemy.x, enemy.y + stepY)) {
          roamingEnemies[i] = Point(enemy.x, enemy.y + stepY);
        }
      } else {
        if (_isWalkable(enemy.x, enemy.y + stepY)) {
          roamingEnemies[i] = Point(enemy.x, enemy.y + stepY);
        } else if (stepX != 0 && _isWalkable(enemy.x + stepX, enemy.y)) {
          roamingEnemies[i] = Point(enemy.x + stepX, enemy.y);
        }
      }
    }
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

    while (floorCount < maxFloors) {
      if (random.nextDouble() > 0.8) currentDirection = random.nextInt(4);
      int dx = 0, dy = 0;
      switch (currentDirection) {
        case 0: dy = -1; break; case 1: dx = 1; break; case 2: dy = 1; break; case 3: dx = -1; break; 
      }
      int nextX = currentX + dx; int nextY = currentY + dy;
      if (nextX > 0 && nextX < width - 1 && nextY > 0 && nextY < height - 1) {
        currentX = nextX; currentY = nextY;
        if (grid[currentY][currentX] == TileType.wall) { grid[currentY][currentX] = TileType.floor; floorTiles.add(Point(currentX, currentY)); floorCount++; }
      } else { currentDirection = random.nextInt(4); }
    }
    
    floorTiles.sort((a, b) => _calculateDistance(a, playerSpawn).compareTo(_calculateDistance(b, playerSpawn)));
    doorPosition = floorTiles.last; grid[doorPosition.y][doorPosition.x] = TileType.door;
    floorTiles.remove(playerSpawn); floorTiles.remove(doorPosition);
    floorTiles.shuffle(random);
    
    Point<int>? selectedKey;
    for (int i = 0; i < floorTiles.length; i++) {
      if (_calculateDistance(floorTiles[i], playerSpawn) >= 6) { selectedKey = floorTiles[i]; floorTiles.removeAt(i); break; }
    }
    if (selectedKey == null && floorTiles.isNotEmpty) {
      selectedKey = floorTiles.removeAt(0);
    } else {
      selectedKey ??= playerSpawn;
    } 
    keyPosition = selectedKey;

    int numChests = random.nextInt(3) + 1; 
    for (int i = 0; i < numChests; i++) { if (floorTiles.isNotEmpty) { Point<int> chestPos = floorTiles.removeAt(0); grid[chestPos.y][chestPos.x] = TileType.chest; } }

    int numSpikes = random.nextInt(6) + 4; 
    for (int i = 0; i < numSpikes; i++) { if (floorTiles.isNotEmpty) { Point<int> spikePos = floorTiles.removeAt(0); grid[spikePos.y][spikePos.x] = TileType.spike; } }

    roamingEnemies.clear();
    int numRoaming = random.nextInt(4) + 3; // de 3 a 6 inimigos patrulhando
    for (int i = 0; i < numRoaming; i++) {
      if (floorTiles.isNotEmpty) {
        int index = random.nextInt(floorTiles.length);
        roamingEnemies.add(floorTiles.removeAt(index)); // Ocupa blocos livres aleatórios
      }
    }
  }

  TileType getTile(int x, int y) { if (x < 0 || x >= width || y < 0 || y >= height) return TileType.wall; return grid[y][x]; }
  void markExplored(int x, int y) { if (x >= 0 && x < width && y >= 0 && y < height) explored[y][x] = true; }
}