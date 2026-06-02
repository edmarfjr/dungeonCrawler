import 'dart:ui';

import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:flame/components.dart';

class BuffParticle extends PositionComponent {
  double speedY;
  double life;
  double maxLife;

  BuffParticle(double startX, double startY, this.speedY, this.maxLife)
      : life = maxLife,
        super(position: Vector2(startX, startY), size: Vector2(8, 8), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= speedY * dt;
    life -= dt;
    
    if (life <= 0) removeFromParent(); // Destrói-se sozinha
  }

  @override
  void render(Canvas canvas) {
    double opacity = (life / maxLife).clamp(0.0, 1.0);
    canvas.drawCircle(
      const Offset(0, 0), // Centro do componente
      4.0, 
      Paint()
        ..color = Palette.verdeCla.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
    );
  }
}