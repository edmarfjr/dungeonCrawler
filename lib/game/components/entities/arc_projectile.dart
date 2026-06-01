import 'dart:ui';
import 'package:flame/components.dart';

class ArcProjectile {
  double strafeX; double yPos; double vx; double vy;
  bool isActive = true;

  ArcProjectile(this.strafeX, this.yPos, this.vx, this.vy);

  void update(double dt) {
    vy += 3.0 * dt; // Gravidade puxando para baixo
    strafeX += vx * dt;
    yPos += vy * dt;
    if (yPos > 0.8) isActive = false; // Bateu no chão
  }

  bool get isFalling => vy > 0; // Só tem hitbox se estiver caindo!

  Rect getHitbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafeX * scale);
    return Rect.fromCenter(center: Offset(cx, screenSize.y * yPos), width: 30, height: 30);
  }

  Rect getHitboxImageSize(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafeX * scale);
    return Rect.fromCenter(center: Offset(cx, screenSize.y * yPos), width: 120, height: 120);
  }
}