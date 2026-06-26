import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';

class FirePillar extends SpriteComponent with HasGameRef<DungeonCrawlerGame> {
  double strafeX;
  double yPos;
  double vx;
  double vy;
  double radius;
  double tmr;
  double sizeImg;
  final Enemy owner; 
  double _flipTimer = 0.0; 
  final double _flipInterval = 0.1;

  FirePillar(
    this.strafeX, 
    this.yPos, 
    this.vx, 
    this.vy, 
    this.owner,
    {
      this.radius = 80,
      required ui.Image img, 
      this.sizeImg = 288,
      this.tmr = 5,
    }
  ) : super(
          anchor: Anchor.center, 
          priority: 20,           
          size: Vector2(sizeImg, sizeImg), 
      ) {
    
    sprite = Sprite(img);
    
    paint = Paint();
  }

  @override
  void update(double dt) {
    if(gameRef.currentState == GameState.paused) return;
    super.update(dt);
    tmr -= dt;

    double playerX = gameRef.playerCombatStats.strafePosition;
      
    double direction = (playerX - strafeX).sign;
    
    vx += direction * 0.01 * dt; 
    
    vx = vx.clamp(-2.5, 2.5);

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
      gameRef.applyEnemyDamage(owner); 
      if (gameRef.playerCombatStats.hp <= 0) {
        gameRef.handlePlayerDeath();
      }
      
    }
  }

}