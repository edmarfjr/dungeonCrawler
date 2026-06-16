import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';

class ArcProjectile extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  double strafeX;
  double yPos;
  double vx;
  double vy;
  double grav;
  double radius;
  final Enemy owner; // Guarda quem atirou para saber a cor, dano e imagem!

  ArcProjectile(this.strafeX, this.yPos, this.vx, this.vy, this.owner,{ this.grav = 3.0,this.radius = 30})
      : super(anchor: Anchor.center);

  @override
  void update(double dt) {
    if(gameRef.currentState == GameState.paused)return;
    super.update(dt);
    vy += grav * dt; 
    strafeX += vx * dt;
    yPos += vy * dt;

    if (yPos > 0.8 || !owner.isAlive) {
      removeFromParent();
      return;
    }

    double scale = gameRef.size.x * 0.35;
    double cx = (gameRef.size.x / 2) + (strafeX * scale);
    position = Vector2(cx, gameRef.size.y * yPos);
    size = Vector2(144, 144);

    // 2. COLISÃO AUTÓNOMA COM O JOGADOR
    if (isFalling) {
      Rect myHitbox = Rect.fromCenter(center: position.toOffset(), width: radius, height: radius);
      if (myHitbox.overlaps(gameRef.playerCombatStats.getHurtbox(gameRef.size))) {
        
        gameRef.applyEnemyDamage(owner); 
        removeFromParent();
        
        if (gameRef.playerCombatStats.hp <= 0) {
          gameRef.handlePlayerDeath();
        }
      }
    }
  }

  bool get isFalling => vy > 0; 

  @override
  void render(Canvas canvas) {
    final ui.Image? img = gameRef.combatOverlay.enemySlashImages[owner.type];
    if (img == null) return;

    Paint projPaint = Paint()..colorFilter = ColorFilter.mode(owner.color, BlendMode.modulate);

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, size.x, size.y), 
      projPaint
    );
  }
}

