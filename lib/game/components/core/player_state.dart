import 'dungeon_map.dart';
//import 'package:flutter/material.dart';

class PlayerState {
  int x;
  int y;
  Direction facing;
  
  bool hasKey = false;
  //int floorLevel = 1;

  PlayerState({required this.x, required this.y, this.facing = Direction.north});

  void turn(bool right) {
    int dirIndex = facing.index;
    if (right) {
      dirIndex = (dirIndex + 1) % 4;
    } else {
      dirIndex = (dirIndex - 1 + 4) % 4;
    }
    facing = Direction.values[dirIndex];
  }

  // --- MUDANÇA: Agora retorna bool para confirmar que o passo foi dado ---
  bool move(bool forward, DungeonMap map) {
    int dx = 0, dy = 0;
    
    switch (facing) {
      case Direction.north: dy = -1; break;
      case Direction.east:  dx = 1; break;
      case Direction.south: dy = 1; break;
      case Direction.west:  dx = -1; break;
    }

    if (!forward) {
      dx = -dx;
      dy = -dy;
    }

    int nextX = x + dx;
    int nextY = y + dy;

    if (map.getTile(nextX, nextY) != TileType.wall && map.getTile(nextX, nextY) != TileType.secretWall ) {
      x = nextX;
      y = nextY;
      
      return true; // Passo dado com sucesso
    }
    
    return false; // Bateu na parede ou porta (não faz ruído)
  }
}