import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'dungeon_map.dart';
import 'player_state.dart';

class MazeRenderer extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  DungeonMap map;
  PlayerState player;
  final List <ui.Image> wallImage;
  final List <ui.Image> secretWallImage;
  final List <ui.Image> floorImage;
  final ui.Image doorImage;
  final ui.Image doorImage2;
  final ui.Image keyImage;
  final ui.Image chestImage;
  final ui.Image crateImage;
  final ui.Image openCrateImage;
  final ui.Image openChestImage;
  final List <ui.Image> trapImage;
  final ui.Image roamerImage;
  final ui.Image bossImage;
  final ui.Image shopImage;
  final ui.Image shrineImage;
  final ui.Image brokenShrineImage;
  final ui.Image fontImage;
  final ui.Image loreImage;
  final List <ui.Image> darkRoomImage;

  double _bumpTimer = 0.0;
  double _maxBumpTime = 0.18; 
  bool _bumpForward = true;
  double yOffsetAnim = 0.0;

  double _smoothMoveTimer = 0.0;
  final double _maxSmoothMoveTime = 0.20;
  bool _smoothMoveForward = true;

  double _smoothTurnTimer = 0.0;
  final double _maxSmoothTurnTime = 0.18;
  bool _smoothTurnRight = true;

  int darkRoomIdx = 0;

  // Variáveis para armazenar a resolução da tela de jogo (Viewport)
  double _currentViewWidth = 400.0;
  double _currentViewHeight = 400.0;

  MazeRenderer({
    required this.map,
    required this.player,
    required this.wallImage,
    required this.secretWallImage,
    required this.floorImage,
    required this.doorImage, 
    required this.doorImage2, 
    required this.keyImage,  
    required this.chestImage,
    required this.trapImage,
    required this.roamerImage,
    required this.bossImage,
    required this.shrineImage,
    required this.openChestImage,
    required this.crateImage,
    required this.openCrateImage,
    required this.shopImage,
    required this.fontImage,
    required this.loreImage,
    required this.darkRoomImage,
    required this.brokenShrineImage,
  });

  void triggerWallBump({required bool forward}) {
    _bumpTimer = _maxBumpTime;
    _bumpForward = forward;
  }

  void triggerSmoothMove({required bool forward}) {
    _smoothMoveTimer = _maxSmoothMoveTime;
    _smoothMoveForward = forward;
  }

  void triggerSmoothTurn({required bool right}) {
    _smoothTurnTimer = _maxSmoothTurnTime;
    _smoothTurnRight = right;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_bumpTimer > 0) {
      _bumpTimer -= dt;
    }
    if (_smoothMoveTimer > 0) {
      _smoothMoveTimer -= dt;
    }
    if (_smoothTurnTimer > 0) {
      _smoothTurnTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. APLICA A ESCALA GLOBAL DO JOGO
    double scaleFactor = gameRef.isDesktopLayout ? (size.y / 720.0).clamp(0.1, 5.0) : (size.x / 400.0).clamp(0.1, 5.0);
    double logicalWidth = size.x / scaleFactor;
    double logicalHeight = size.y / scaleFactor;

    // 2. RECORTA A TELA (VIEWPORT DA HUD)
    Rect viewportRect;
    if (gameRef.isDesktopLayout) {
      double panelWidth = 260.0;
      viewportRect = Rect.fromLTWH(panelWidth, 0, logicalWidth - (panelWidth * 2), logicalHeight);
    } else {
      double topHudHeight = 76.0;
      double bottomHudHeight = 76.0;
      viewportRect = Rect.fromLTWH(0, topHudHeight, logicalWidth, logicalHeight - topHudHeight - bottomHudHeight);
    }

    _currentViewWidth = viewportRect.width;
    _currentViewHeight = viewportRect.height;

    canvas.save();
    canvas.scale(scaleFactor, scaleFactor);
    
    if (yOffsetAnim > 0) {
      canvas.translate(0, yOffsetAnim);
    }

    // ==== MÁGICA DA MOLDURA: O labirinto só pode desenhar dentro deste buraco! ====
    canvas.clipRect(viewportRect);
    canvas.translate(viewportRect.left, viewportRect.top);

    // 3. APLICA O TRANCO DE IMPACTO NA CÂMERA
    if (_bumpTimer > 0) {
      double progress = 1.0 - (_bumpTimer / _maxBumpTime);
      double intensity = sin(progress * pi);

      if (_bumpForward) {
        double scalePunch = 1.0 + (intensity * 0.05); 
        double yJolt = intensity * 14.0;
        canvas.translate(_currentViewWidth / 2, _currentViewHeight / 2);
        canvas.scale(scalePunch);
        canvas.translate(-_currentViewWidth / 2, (-_currentViewHeight / 2) + yJolt);
      } else {
        double yJolt = -intensity * 10.0;
        canvas.translate(0, yJolt);
      }
    }

    // 4. APLICA O MOVIMENTO SUAVE (ZOOM IN / ZOOM OUT)
    if (_smoothMoveTimer > 0) {
      double progress = (_smoothMoveTimer / _maxSmoothMoveTime).clamp(0.0, 1.0);
      double ease = progress * progress; 
      
      if (_smoothMoveForward) {
        double scale = 1.0 - (0.2 * ease); 
        double yJolt = 15.0 * ease; 
        
        canvas.translate(_currentViewWidth / 2, _currentViewHeight / 2);
        canvas.scale(scale);
        canvas.translate(-_currentViewWidth / 2, (-_currentViewHeight / 2) + yJolt);
      } else {
        double scale = 1.0 + (0.2 * ease); 
        double yJolt = -15.0 * ease; 
        
        canvas.translate(_currentViewWidth / 2, _currentViewHeight / 2);
        canvas.scale(scale);
        canvas.translate(-_currentViewWidth / 2, (-_currentViewHeight / 2) + yJolt);
      }
    }

    // 5. APLICA A ROTAÇÃO SUAVE (DESLIZE HORIZONTAL)
    if (_smoothTurnTimer > 0) {
      double progress = (_smoothTurnTimer / _maxSmoothTurnTime).clamp(0.0, 1.0);
      double ease = progress * progress; 
      
      double offset = _currentViewWidth * 0.5 * ease; 
      
      if (_smoothTurnRight) {
        canvas.translate(offset, 0); 
      } else {
        canvas.translate(-offset, 0); 
      }
    }

    canvas.drawRect(Rect.fromLTWH(-_currentViewWidth, -_currentViewHeight, _currentViewWidth * 3, _currentViewHeight * 3), Paint()..color = Palette.preto );

    if (gameRef.isDarkRoom) {
      double imgW = darkRoomImage[darkRoomIdx].width.toDouble();
      double imgH = darkRoomImage[darkRoomIdx].height.toDouble();
      
      double scale = min(_currentViewWidth / imgW, _currentViewHeight / imgH);
      double drawW = imgW * scale;
      double drawH = imgH * scale;
      
      double dx = (_currentViewWidth - drawW) / 2;
      double dy = (_currentViewHeight - drawH) / 2;

      canvas.drawImageRect(
        darkRoomImage[darkRoomIdx],
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(dx, dy, drawW, drawH),
        Paint(),
      );
    } else {
      int dx = 0, dy = 0;
      int sideDx = 0, sideDy = 0;

      switch (player.facing) {
        case Direction.north: dy = -1; sideDx = 1; break;
        case Direction.south: dy = 1;  sideDx = -1; break;
        case Direction.east:  dx = 1;  sideDy = 1; break;
        case Direction.west:  dx = -1; sideDy = -1; break;
      }

      for (int cz = 4; cz >= 0; cz--) {
        // A MÁGICA ACONTECE AQUI: Expandimos o labirinto de -8 até 8!
        // Isto garante que há cenário de sobra para cobrir a tela durante os giros rápidos.
        for (int cx in [-8, 8, -7, 7, -6, 6, -5, 5, -4, 4, -3, 3, -2, 2, -1, 1, 0]) {
          int mapX = player.x + (dx * cz) + (sideDx * cx);
          int mapY = player.y + (dy * cz) + (sideDy * cx);
          
          TileType tile = map.getTile(mapX, mapY);

          int tileIdx = 0;
          Color corChao = Colors.white;
          Color corParede = Colors.white;

          if (map.level >= 4) tileIdx = 1;
          if (map.level >= 7) tileIdx = 2;
          if (map.level >= 10) tileIdx = 3;

          _drawFloorTile(canvas, cx, cz, floorImage[tileIdx], corChao);
          _drawCeiling(canvas, cx, cz,floorImage[tileIdx], corChao);

          if (tile == TileType.wall) {
            _drawLeftFace(canvas, cx, cz, wallImage[tileIdx], corParede); 
            _drawRightFace(canvas, cx, cz, wallImage[tileIdx], corParede); 
            _drawFrontFace(canvas, cx, cz, wallImage[tileIdx], corParede);
          }

          if (tile == TileType.secretWall) {
            _drawLeftFace(canvas, cx, cz, secretWallImage[tileIdx], corParede); 
            _drawRightFace(canvas, cx, cz, secretWallImage[tileIdx], corParede); 
            _drawFrontFace(canvas, cx, cz, secretWallImage[tileIdx], corParede);
          }

          if (tile == TileType.door) {
            _drawFloorTile(canvas, cx, cz, doorImage, Colors.white);
          }

          if (map.keyPosition != null && map.keyPosition!.x == mapX && map.keyPosition!.y == mapY && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, keyImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.chest && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, chestImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.font && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, fontImage, 0.6, 0.1, Colors.white);
          }

          if (tile == TileType.fontPoison && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, fontImage, 0.6, 0.1, Colors.white);
          }

          if (tile == TileType.crate && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, crateImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.openCrate && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, openCrateImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.boss && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, bossImage, 0.6, 0.0, Colors.white);
          }

          if (tile == TileType.shop && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, shopImage, 0.6, 0.0, Colors.white);
          }

          if (tile == TileType.openChest && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, openChestImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.shrine && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, shrineImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.brokenShrine && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, brokenShrineImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.lore && gameRef.currentState == GameState.exploration) {
            _drawBillboardItem(canvas, cx, cz, loreImage, 0.5, 0.1, Colors.white);
          }

          if (tile == TileType.spike && gameRef.currentState == GameState.exploration) {
            _drawFloorTile(canvas, cx, cz, floorImage[tileIdx], corChao);
            double frameWidth = trapImage[0].width / 4;
            Rect frameRect = Rect.fromLTWH(map.spikeState * frameWidth, 0, frameWidth, trapImage[0].height.toDouble());
            _drawBillboardItem(canvas, cx, cz, trapImage[0], 0.7, 0.1,Colors.white, srcRect: frameRect);
          }

          if (tile == TileType.poison && gameRef.currentState == GameState.exploration) {
            _drawFloorTile(canvas, cx, cz, floorImage[tileIdx], corChao);
            double frameWidth = trapImage[1].width / 5;
            Rect frameRect = Rect.fromLTWH(map.poisonState * frameWidth, 0, frameWidth, trapImage[1].height.toDouble());
            _drawBillboardItem(canvas, cx, cz, trapImage[1], 0.7, 0.1,Colors.white, srcRect: frameRect);
          }

          if (tile == TileType.teleport && gameRef.currentState == GameState.exploration) {
            _drawFloorTile(canvas, cx, cz, floorImage[tileIdx], corChao);
            double frameWidth = trapImage[2].width / 5;
            Rect frameRect = Rect.fromLTWH(map.teleportState * frameWidth, 0, frameWidth, trapImage[2].height.toDouble());
            _drawBillboardItem(canvas, cx, cz, trapImage[2], 0.6, 0.1,Colors.white, srcRect: frameRect);
          }

          Point<int> currentMapPos = Point(mapX, mapY);
          if (map.droppedItems.containsKey(currentMapPos) && map.droppedItems[currentMapPos]!.isNotEmpty && gameRef.currentState == GameState.exploration) {
            for(var item in map.droppedItems[currentMapPos]!.reversed){
              try {
                ui.Image itemImg = gameRef.images.fromCache(item.imagePath);
                _drawBillboardItem(canvas, cx, cz, itemImg, 0.5, 0.2, item.cor);
              } catch (e) {
                _drawBillboardItem(canvas, cx, cz, chestImage, 0.5, 0.2, item.cor);
              }
            }
          }
          
          for (var enemy in map.roamingEnemies) {
            if (enemy.x == mapX && enemy.y == mapY && gameRef.currentState == GameState.exploration) {
              _drawBillboardItem(canvas, cx, cz, roamerImage, 0.6, 0.0,Colors.white);
            }
          }
        }
      }
    }

    canvas.restore();
  
  }

  // --- NOVA PROJEÇÃO: Utiliza o tamanho do viewport ao invés da tela cheia!
  Offset _project(double x, double y, double z) {
    double cameraZ = z + 0.5; 
    
    double baseDim = min(_currentViewWidth, _currentViewHeight); 
    double fov = baseDim * 0.8; 
    
    return Offset(
      (x / cameraZ) * fov + _currentViewWidth / 2,
      (y / cameraZ) * fov + _currentViewHeight / 2,
    );
  }

  void _drawBillboardItem(Canvas canvas, int cx, int cz, ui.Image image, double bottomY, double topY, Color cor, {Rect? srcRect}) {
    double zCenter = cz + 0.5;

    double rawDarkness = (zCenter / 5.0).clamp(0.0, 1.0);
    double darkness = (rawDarkness * 4).round() / 4.0;
    Color darkenedColor = Color.lerp(cor, Colors.black, darkness)!;

    Offset bottom = _project(cx.toDouble(), bottomY, zCenter);
    Offset top = _project(cx.toDouble(), topY, zCenter);

    double spriteHeight = bottom.dy - top.dy;

    double sourceWidth = srcRect != null ? srcRect.width : image.width.toDouble();
    double sourceHeight = srcRect != null ? srcRect.height : image.height.toDouble();
    double aspectRatio = sourceWidth / sourceHeight;
    double spriteWidth = spriteHeight * aspectRatio;

    Rect dstRect = Rect.fromLTWH(
      bottom.dx - (spriteWidth / 2),
      top.dy,
      spriteWidth, 
      spriteHeight
    );

    final paint = Paint()
      ..colorFilter = ColorFilter.mode(darkenedColor, BlendMode.modulate);

    canvas.drawImageRect(
      image,
      srcRect ?? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dstRect,
      paint
    );
  }

  void _drawFrontFace(Canvas canvas, int cx, int cz, ui.Image tex, Color color) {
    _drawSubdividedPolygon(canvas, tex, color, [
      [cx - 0.5, -0.5, cz.toDouble()], 
      [cx + 0.5, -0.5, cz.toDouble()], 
      [cx + 0.5,  0.5, cz.toDouble()], 
      [cx - 0.5,  0.5, cz.toDouble()], 
    ]);
  }

  void _drawLeftFace(Canvas canvas, int cx, int cz, ui.Image tex, Color color) {
    double x = cx - 0.5;
    _drawSubdividedPolygon(canvas, tex, color, [
      [x, -0.5, cz + 1.0], 
      [x, -0.5, cz.toDouble()], 
      [x,  0.5, cz.toDouble()], 
      [x,  0.5, cz + 1.0], 
    ]);
  }

  void _drawRightFace(Canvas canvas, int cx, int cz, ui.Image tex, Color color) {
    double x = cx + 0.5;
    _drawSubdividedPolygon(canvas, tex, color, [
      [x, -0.5, cz.toDouble()], 
      [x, -0.5, cz + 1.0], 
      [x,  0.5, cz + 1.0], 
      [x,  0.5, cz.toDouble()], 
    ]);
  }

  void _drawFloorTile(Canvas canvas, int cx, int cz, ui.Image img, Color color) {
    _drawSubdividedPolygon(canvas, img, color, [
      [cx - 0.5, 0.5, cz + 1.0], 
      [cx + 0.5, 0.5, cz + 1.0], 
      [cx + 0.5, 0.5, cz.toDouble()], 
      [cx - 0.5, 0.5, cz.toDouble()], 
    ]);
  }

  void _drawCeiling(Canvas canvas, int cx, int cz, ui.Image img, Color color) {
    _drawSubdividedPolygon(canvas, img, color, [
      [cx - 0.5, -0.5, cz + 1.0], 
      [cx + 0.5, -0.5, cz + 1.0], 
      [cx + 0.5, -0.5, cz.toDouble()], 
      [cx - 0.5, -0.5, cz.toDouble()], 
    ]);
  }

  // --- CORTINAS SÓLIDAS PARA VAZAMENTO DE CÂMERA ---
  void _drawLeftBlocker(Canvas canvas, int cx, int cz) {
    double x = cx - 0.5;
    // Puxa o vértice para um valor X absurdamente negativo
    Offset topLeft = _project(-10.0, -0.5, cz.toDouble());
    Offset botLeft = _project(-10.0,  0.5, cz.toDouble());
    Offset topRight = _project(x, -0.5, cz.toDouble());
    Offset botRight = _project(x,  0.5, cz.toDouble());

    // Calculamos o nível de escurecimento (Igual aos tiles normais)
    double rawDarkness = (cz / 4.5).clamp(0.0, 1.0);
    double darkness = (rawDarkness * 4).round() / 4.0;
    Color blockerColor = Color.lerp(Colors.black, Colors.black, darkness)!;

    Path path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(botLeft.dx, botLeft.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = blockerColor);
  }

  void _drawRightBlocker(Canvas canvas, int cx, int cz) {
    double x = cx + 0.5;
    // Puxa o vértice para um valor X absurdamente positivo
    Offset topLeft = _project(x, -0.5, cz.toDouble());
    Offset botLeft = _project(x,  0.5, cz.toDouble());
    Offset topRight = _project(10.0, -0.5, cz.toDouble());
    Offset botRight = _project(10.0,  0.5, cz.toDouble());

    double rawDarkness = (cz / 4.5).clamp(0.0, 1.0);
    double darkness = (rawDarkness * 4).round() / 4.0;
    Color blockerColor = Color.lerp(Colors.black, Colors.black, darkness)!;

    Path path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(botLeft.dx, botLeft.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = blockerColor);
  }

  void _drawSubdividedPolygon(Canvas canvas, ui.Image image, Color tintColor, List<List<double>> points3D) {
    final paint = Paint()
      ..shader = ImageShader(
        image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage,
      );

    const int segs = 4; 
    int numVertices = (segs + 1) * (segs + 1);
    
    var positions = Float32List(numVertices * 2);
    var texCoords = Float32List(numVertices * 2);
    var indices = Uint16List(segs * segs * 6);
    var colors = Int32List(numVertices); 

    int vIdx = 0;
    int tIdx = 0;
    int cIdx = 0; 

    final p0 = points3D[0];
    final p1 = points3D[1];
    final p2 = points3D[2];
    final p3 = points3D[3];

    for (int v = 0; v <= segs; v++) {
      double ty = v / segs; 
      for (int u = 0; u <= segs; u++) {
        double tx = u / segs; 

        double topX = p0[0] + (p1[0] - p0[0]) * tx;
        double topY = p0[1] + (p1[1] - p0[1]) * tx;
        double topZ = p0[2] + (p1[2] - p0[2]) * tx;

        double botX = p3[0] + (p2[0] - p3[0]) * tx;
        double botY = p3[1] + (p2[1] - p3[1]) * tx;
        double botZ = p3[2] + (p2[2] - p3[2]) * tx;

        double finalX = topX + (botX - topX) * ty;
        double finalY = topY + (botY - topY) * ty;
        double finalZ = topZ + (botZ - topZ) * ty;

        double rawDarkness = (finalZ / 4.5).clamp(0.0, 1.0);
        double darkness = (rawDarkness * 4).round() / 4.0;
        
        Color vertexColor = Color.lerp(tintColor, Colors.black, darkness)!;
        colors[cIdx++] = vertexColor.value;

        Offset proj = _project(finalX, finalY, finalZ);

        positions[vIdx++] = proj.dx;
        positions[vIdx++] = proj.dy;

        texCoords[tIdx++] = tx * image.width.toDouble();
        texCoords[tIdx++] = ty * image.height.toDouble();
      }
    }

    int iIdx = 0;
    for (int v = 0; v < segs; v++) {
      for (int u = 0; u < segs; u++) {
        int topLeft = v * (segs + 1) + u;
        int topRight = topLeft + 1;
        int bottomLeft = (v + 1) * (segs + 1) + u;
        int bottomRight = bottomLeft + 1;

        indices[iIdx++] = topLeft;
        indices[iIdx++] = topRight;
        indices[iIdx++] = bottomLeft;

        indices[iIdx++] = topRight;
        indices[iIdx++] = bottomRight;
        indices[iIdx++] = bottomLeft;
      }
    }

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: colors, 
      indices: indices,
    );

    canvas.drawVertices(vertices, BlendMode.modulate, paint);
  }
}