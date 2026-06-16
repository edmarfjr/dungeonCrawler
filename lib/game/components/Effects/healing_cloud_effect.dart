import 'dart:ui';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class HealingCloudEffect extends PositionComponent {
  final double strafeX;
  final double yPos;
  final DungeonCrawlerGame gameRef;

  double timer = 0.0;
  final double maxTime = 1.0; 

  HealingCloudEffect(this.strafeX, this.yPos, this.gameRef) : super(anchor: Anchor.center) {
    size = Vector2(300, 300);
  }

  @override
  void update(double dt) {
    if(gameRef.currentState == GameState.paused) return;
    super.update(dt);
    timer += dt;
    
    if (timer >= maxTime) {
      removeFromParent();
    }

    // Acompanha a matemática visual do jogo
    double scale = gameRef.size.x * 0.35;
    double cx = (gameRef.size.x / 2) + (strafeX * scale);
    double cy = gameRef.size.y * yPos;
    position = Vector2(cx, cy);
  }

  @override
  void render(Canvas canvas) {
    // 1. Calcula o progresso da animação (0.0 até 1.0)
    double progress = timer / maxTime;
    
    // 2. A nuvem vai ficando transparente conforme se expande
    double alpha = (1.0 - progress).clamp(0.0, 1.0);
    
    // 3. O raio do gás cresce de 40 até 160
    double currentRadius = 40.0 + (120.0 * progress); 

    // O segredo do efeito: MaskFilter.blur desfoca as bordas da forma geométrica!
    final paint = Paint()
      ..color = Palette.verde.withOpacity(alpha * 0.6) 
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25.0); 

    canvas.drawCircle(Offset(size.x/2, size.y/2), currentRadius, paint);
  }
}