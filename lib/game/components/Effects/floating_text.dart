import 'dart:ui';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingText extends PositionComponent {
  final String text;
  final Color color;
  double lifeTime;
  final double maxLifeTime;
  final double speedY;

  FloatingText(this.text, double startX, double startY, this.color, {this.maxLifeTime = 1.2, this.speedY = 60.0})
      : lifeTime = maxLifeTime,
        super(position: Vector2(startX, startY), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    lifeTime -= dt;
    position.y -= speedY * dt; // Flutua para cima
    priority = 50;

    if (lifeTime <= 0) {
      removeFromParent(); // O Flame destrói-o automaticamente!
    }
  }

  @override
  void render(Canvas canvas) {
    double opacity = (lifeTime / maxLifeTime).clamp(0.0, 1.0);
    
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withOpacity(opacity),
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: 'pixelFont', 
        shadows: [
          Shadow(color: Palette.preto.withOpacity(opacity), blurRadius: 2, offset: const Offset(2, 2))
        ]
      ),
    );
    
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    
    // No Flame, o render acontece sempre nas coordenadas (0,0) do próprio componente
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
}