import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';

class PoisonCloud extends SpriteComponent with HasGameRef<DungeonCrawlerGame> {
  double strafeX;
  double yPos;
  double vx;
  double vy;
  double radius;
  double tmr = 5;
  final Enemy owner; 

  double _flipTimer = 0.0; 
  final double _flipInterval = 0.15;

  PoisonCloud(
    this.strafeX, 
    this.yPos, 
    this.vx, 
    this.vy, 
    this.owner, 
    {this.radius = 160, required ui.Image img}
  ) : super(
          anchor: Anchor.center, 
          priority: 20,           
          size: Vector2(radius, radius), 
      ) {
    
    sprite = Sprite(img);
    
    paint = Paint()..colorFilter = ColorFilter.mode(Palette.roxo.withAlpha(180), BlendMode.modulate);
  }

  @override
  void update(double dt) {
    if(gameRef.currentState == GameState.paused) return;
    super.update(dt);
    tmr -= dt;

    _flipTimer += dt; 

    if (_flipTimer >= _flipInterval) {
      _flipTimer -= _flipInterval; 
      flipHorizontally(); 
    }

    if (tmr <= 0 || !owner.isAlive || game.currentState == GameState.exploration) {
      removeFromParent();
      return;
    }

    strafeX += vx * dt;
    yPos += vy * dt;

    double scale = gameRef.size.x * 0.35;
    double cx = (gameRef.size.x / 2) + (strafeX * scale);
    position = Vector2(cx, gameRef.size.y * yPos);

    Rect myHitbox = Rect.fromCenter(
      center: position.toOffset(), 
      width: radius * 0.8,    
      height: gameRef.size.y  
    );
    
    if (myHitbox.overlaps(gameRef.playerCombatStats.getHurtbox(gameRef.size))) {   
      gameRef.playerCombatStats.stamina -= dt * 50; 
      
      if (gameRef.playerCombatStats.stamina < 0) {
        gameRef.playerCombatStats.stamina = 0;
      }
    }
  }

}