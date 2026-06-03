import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';

class PlayerProjectile extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  double strafeX;
  double yPos; 
  double speed;
  double yDir;
  double power;
  Color color;
  bool isPiercing;
  double hitCooldown; 
  Map<Enemy, double> hitEnemies = {};
  double dieTmr;

  // O 'super(size, anchor)' avisa ao Flame o tamanho oficial deste objeto
  PlayerProjectile(this.strafeX, this.yPos, this.speed, this.power, this.color, 
      {this.dieTmr = 2, this.yDir = -1, this.isPiercing = false, double width = 80, double height = 180, this.hitCooldown = 999.0}) 
      : super(size: Vector2(width, height), anchor: Anchor.center);

  @override
  void update(double dt) {
    if(gameRef.currentState == GameState.paused)return;
    super.update(dt);
    
    // 1. Lógica de Vida e Movimento
    dieTmr -= dt;
    yPos += yDir * speed * dt;

    // FLAME MAGIC: Destrói o objeto da memória automaticamente!
    if (dieTmr <= 0 || (yDir < 0 && yPos < -0.2) || (yDir > 0 && yPos > 1.2)) {
      removeFromParent(); 
      return;
    }

    // 2. Atualiza a posição real na tela para o Flame renderizar
    double scale = gameRef.size.x * 0.35;
    double cx = (gameRef.size.x / 2) + (strafeX * scale);
    position = Vector2(cx, gameRef.size.y * yPos);

    // 3. Atualiza Cooldowns de perfuração
    for (var enemy in hitEnemies.keys.toList()) {
      if (hitEnemies[enemy]! > 0) hitEnemies[enemy] = hitEnemies[enemy]! - dt;
    }

    // 4. COLISÃO AUTO-GERENCIADA (Ele mesmo checa se bateu no inimigo!)
    final myHitbox = size.toRect().shift(position.toOffset() - Offset(size.x/2, size.y/2));
    
    for (var enemy in gameRef.combatOverlay.enemies) {
      bool isImmune = hitEnemies.containsKey(enemy) && hitEnemies[enemy]! > 0;
      
      if (!isImmune && !enemy.isDying && enemy.isVulnerable && myHitbox.overlaps(enemy.getHurtbox(gameRef.size))) {
        enemy.hp -= power;
        enemy.applyHitStun(0.3);
        
        if (enemy.hp <= 0) { 
          enemy.hp = 0; enemy.isDying = true; gameRef.encounterEssence += enemy.dropEssence; 
        }
        
        if (isPiercing) {
          hitEnemies[enemy] = hitCooldown;
        } else {
          removeFromParent(); // Se destrói no impacto
          break; 
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // No Flame, o render sempre começa do (0,0) do próprio objeto! Muito mais fácil.
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    
    final glowPaint = Paint()..color = color.withOpacity(0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    final corePaint = Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawRect(rect, glowPaint);
    canvas.drawRect(rect.deflate(10), corePaint);
  }
}