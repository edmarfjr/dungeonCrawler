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
  final Enemy owner; // Guarda quem atirou para saber a cor, dano e imagem!

  ArcProjectile(this.strafeX, this.yPos, this.vx, this.vy, this.owner)
      : super(anchor: Anchor.center);

  @override
  void update(double dt) {
    if(gameRef.currentState == GameState.paused)return;
    super.update(dt);
    vy += 3.0 * dt; // Gravidade a puxar para baixo
    strafeX += vx * dt;
    yPos += vy * dt;

    // Se bater no chão, o Flame destrói-o automaticamente!
    if (yPos > 0.8 || !owner.isAlive) {
      removeFromParent();
      return;
    }

    // 1. Sincroniza a matemática com a posição visual do Flame
    double scale = gameRef.size.x * 0.35;
    double cx = (gameRef.size.x / 2) + (strafeX * scale);
    position = Vector2(cx, gameRef.size.y * yPos);
    size = Vector2(120, 120); // Tamanho visual da imagem

    // 2. COLISÃO AUTÓNOMA COM O JOGADOR
    if (isFalling) {
      Rect myHitbox = Rect.fromCenter(center: position.toOffset(), width: 30, height: 30);
      if (myHitbox.overlaps(gameRef.playerCombatStats.getHurtbox(gameRef.size))) {
        
        gameRef.applyEnemyDamage(owner); // Aplica o dano!
        removeFromParent(); // Destrói o projétil ao bater
        
        if (gameRef.playerCombatStats.hp <= 0) {
          gameRef.handlePlayerDeath();
        }
      }
    }
  }

  // Só tem hitbox e dá dano se estiver a cair!
  bool get isFalling => vy > 0; 

  @override
  void render(Canvas canvas) {
    final ui.Image? img = gameRef.combatOverlay.enemySlashImages[owner.type];
    if (img == null) return;

    // Pinta o projétil com a cor do monstro que o atirou
    Paint projPaint = Paint()..colorFilter = ColorFilter.mode(owner.color, BlendMode.modulate);

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, size.x, size.y), // Desenha no ponto 0,0 local do componente
      projPaint
    );
  }
}

