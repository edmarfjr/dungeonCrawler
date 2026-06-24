import 'dart:ui';
import 'dart:ui' as ui;

import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';

class BounceProjectile extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  Vector2 velocity;
  double damage;        // Dano do item
  double remainingTime; // O olho some sozinho após 6 segundos...
  //int maxBounces = 10;       // ...ou após quicar 10 vezes pelas paredes/inimigos
  int bounceCount = 0;
  ui.Image img;
  double tamanho;
  bool liberado = false;
  

  // Guarda uma lista de inimigos atingidos com um pequeno cooldown 
  // para o projétil não dar dano múltiplo no mesmo inimigo no mesmo frame
  final Map<Enemy, double> _hitCooldowns = {};

  BounceProjectile({required Vector2 startPosition, required this.velocity, required this.img, this.damage = 3, this.tamanho = 30,this.remainingTime = 6})
      : super(
          position: startPosition,
          size: Vector2(144, 144),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
   
    Paint projPaint = Paint();//..colorFilter = ColorFilter.mode(owner.color, BlendMode.modulate);

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, size.x,size.y),
      projPaint
    );

  }

  @override
  void update(double dt) {
    super.update(dt);
    if(gameRef.currentState == GameState.paused)return;
    // 1. Controle de vida do projétil
    remainingTime -= dt;
    if (remainingTime <= 0){// || bounceCount >= maxBounces) {
      liberado = true;
    }

    // Atualiza os temporizadores de imunidade dos inimigos
    _hitCooldowns.updateAll((enemy, time) => time - dt);
    _hitCooldowns.removeWhere((enemy, time) => time <= 0);

    // 2. Aplica o movimento contínuo
    position += velocity * dt;


    if(!liberado){
      // 3. LIMITES DE CAIXA DO COMBATE (Paredes, Teto e Chão virtuais da tela)
      // Ajuste esses valores baseados na moldura do seu GameBoy!
      double minX = gameRef.size.x * 0.15;
      double maxX = gameRef.size.x * 0.85;
      double minY = gameRef.size.y * 0.10;
      double maxY = gameRef.size.y * 0.72; // Um pouco acima do D-Pad

      bool bounced = false;

      // Quica nas Paredes Esquerdas/Direitas
      if (position.x < minX) {
        position.x = minX;
        velocity.x = -velocity.x; // Inverte o vetor X
        bounced = true;
      } else if (position.x > maxX) {
        position.x = maxX;
        velocity.x = -velocity.x;
        bounced = true;
      }

      // Quica no Teto / Chão
      if (position.y < minY) {
        position.y = minY;
        velocity.y = -velocity.y; // Inverte o vetor Y
        bounced = true;
      } else if (position.y > maxY) {
        position.y = maxY;
        velocity.y = -velocity.y;
        bounced = true;
      }

      if (bounced) {
        bounceCount++;
        FlameAudio.play('sfx/hit.wav');
      }

      // 4. COLISÃO COM INIMIGOS
      final projectileRect = Rect.fromCenter(center: position.toOffset(), width: tamanho, height: tamanho);//toRect();
      
      for (var enemy in gameRef.combatOverlay.enemies) {
        if (!enemy.isAlive || _hitCooldowns.containsKey(enemy)) continue;

        // Lê a Hurtbox em tempo real do seu inimigo (já com offset e escala!)
        final enemyRect = enemy.getHurtbox(gameRef.size);

        if (projectileRect.overlaps(enemyRect)) {
          // CAUSA DANO E STUN!
          enemy.hp -= damage;
          
          // MÁGICA: Usa o seu método original do enemy.dart para paralisar o monstro!
          enemy.applyHitStun(1.5); // 1.5 segundos travado piscando em vermelho

          // Ativa a morte nativa do seu sistema caso a vida zere
          if (enemy.hp <= 0) {
            enemy.isDying = true;
          }

          // Dá 0.4 segundos de imunidade para este inimigo não sugar o projétil por inteiro
          _hitCooldowns[enemy] = 0.4; 

          // RICOHETE ORGÂNICO: O olho quica na direção oposta ao miolo do inimigo
          Vector2 bounceDirection = (position - enemy.position).normalized();
          if (bounceDirection.length == 0) {
            velocity = -velocity; // Salvaguarda se estiverem no mesmo pixel
          } else {
            double currentSpeed = velocity.length;
            velocity = bounceDirection * currentSpeed; // Mantém a velocidade mas muda o ângulo
          }

          bounceCount++;
          FlameAudio.play('sfx/hit.wav');
          break;
        }
      }
    }else{
      if(position.x > 1 || position.x < 0 || position.y > 1 || position.y < 0){
        removeFromParent();
        return;
      }
    }

    if(game.currentState == GameState.exploration){
      removeFromParent();
      return;
    }
    
  }
}