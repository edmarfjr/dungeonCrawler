import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'dungeon_map.dart';
import 'player_state.dart';

class MazeRenderer extends PositionComponent {
  final DungeonMap map;
  final PlayerState player;
  final ui.Image wallImage;
  final ui.Image floorImage;
  final ui.Image doorImage;
  final ui.Image keyImage;
  final ui.Image chestImage;
  final ui.Image spikeImage;

  MazeRenderer({
    required this.map,
    required this.player,
    required this.wallImage,
    required this.floorImage,
    required this.doorImage, 
    required this.keyImage,  
    required this.chestImage,
    required this.spikeImage,
  });

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Fundo preto (teto e o vazio distante)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.black);

    // Vetores de direção
    int dx = 0, dy = 0;
    int sideDx = 0, sideDy = 0;

    switch (player.facing) {
      case Direction.north: dy = -1; sideDx = 1; break;
      case Direction.south: dy = 1;  sideDx = -1; break;
      case Direction.east:  dx = 1;  sideDy = 1; break;
      case Direction.west:  dx = -1; sideDy = -1; break;
    }

    // Renderiza do fundo para a frente
    for (int cz = 4; cz >= 0; cz--) {
      for (int cx in [-3, 3, -2, 2, -1, 1, 0]) {
        int mapX = player.x + (dx * cz) + (sideDx * cx);
        int mapY = player.y + (dy * cz) + (sideDy * cx);
        
        TileType tile = map.getTile(mapX, mapY);

        // Sempre desenha o chão
        _drawFloorTile(canvas, cx, cz, floorImage, Palette.cinzaEsc);
        _drawCeiling(canvas, cx, cz);

        // --- 1. LÓGICA DAS PAREDES SÓLIDAS ---
        if (tile == TileType.wall) {
          if (cx > 0) _drawLeftFace(canvas, cx, cz, wallImage, Palette.marrom); 
          if (cx < 0) _drawRightFace(canvas, cx, cz, wallImage, Palette.marrom); 
          if (cz > 0) _drawFrontFace(canvas, cx, cz, wallImage, Palette.marrom);
        }

        // --- 2. LÓGICA DA PORTA ---
        if (tile == TileType.door) {
          // A porta vai do chão (0.5) até quase o teto (-0.1)
           _drawFloorTile(canvas, cx, cz, doorImage, Palette.vermelhoEsc);
        }

        // --- 3. LÓGICA DA CHAVE ---
        if (map.keyPosition != null && map.keyPosition!.x == mapX && map.keyPosition!.y == mapY) {
          // A chave vai do chão (0.5) até uma altura menor (0.1)
          _drawBillboardItem(canvas, cx, cz, keyImage, 0.5, 0.1, Palette.cinzaMed);
        }

        if (tile == TileType.chest) {
          _drawBillboardItem(canvas, cx, cz, chestImage, 0.5, 0.1, Palette.amarelo);
        }

        if (tile == TileType.spike) {
          // Sempre desenha o chão normal debaixo da armadilha
          _drawFloorTile(canvas, cx, cz, floorImage, Palette.cinzaEsc);

          // Calcula a largura de 1 frame (divide a spritesheet por 3)
          double frameWidth = spikeImage.width / 3;
          
          // O frameX é o estado atual do mapa (0, 1 ou 2)
          Rect frameRect = Rect.fromLTWH(map.spikeState * frameWidth, 0, frameWidth, spikeImage.height.toDouble());

          // Desenha o espinho! O topY=0.2 garante que ele suba bastante em relação ao chão (0.5)
          _drawBillboardItem(canvas, cx, cz, spikeImage, 0.7, 0.1,Palette.cinza, srcRect: frameRect);
        }
      }
    }
  }

  Offset _project(double x, double y, double z) {
    double cameraZ = z + 0.5; 
    double fov = size.x * 0.8; 
    return Offset(
      (x / cameraZ) * fov + size.x / 2,
      (y / cameraZ) * fov + size.y / 2,
    );
  }

  // --- NOVA FUNÇÃO GENÉRICA DE BILLBOARDING ---
  // Ela serve para qualquer objeto (Inimigos, Chaves, Portas, Magias...)
  void _drawBillboardItem(Canvas canvas, int cx, int cz, ui.Image image, double bottomY, double topY, Color cor, {Rect? srcRect}) {
    double zCenter = cz + 0.5;

    // Projeta as alturas baseadas nos parâmetros informados
    Offset bottom = _project(cx.toDouble(), bottomY, zCenter);
    Offset top = _project(cx.toDouble(), topY, zCenter);

    double spriteHeight = bottom.dy - top.dy;

    double sourceWidth = srcRect != null ? srcRect.width : image.width.toDouble();
    double sourceHeight = srcRect != null ? srcRect.height : image.height.toDouble();
    // Calcula a largura mantendo a proporção original do sprite da imagem
    double aspectRatio = sourceWidth / sourceHeight;
    double spriteWidth = spriteHeight * aspectRatio;

    Rect dstRect = Rect.fromLTWH(
      bottom.dx - (spriteWidth / 2), // Centraliza perfeitamente no eixo horizontal do bloco
      top.dy,
      spriteWidth, 
      spriteHeight
    );

    final paint = Paint()
      ..colorFilter = ColorFilter.mode(cor, BlendMode.modulate);

    // Renderiza a imagem
    canvas.drawImageRect(
      image,
      srcRect ?? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), // Pega a imagem inteira
      dstRect,
      paint
    );
  }

  // MÉTODOS 3D MANTIDOS INTACTOS:
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

  void _drawCeiling(Canvas canvas, int cx, int cz) {
    // Usamos a mesma floorImage, mas mudamos o eixo Y de 0.5 para -0.5
    _drawSubdividedPolygon(canvas, floorImage, Palette.cinzaEsc, [
      [cx - 0.5, -0.5, cz + 1.0], 
      [cx + 0.5, -0.5, cz + 1.0], 
      [cx + 0.5, -0.5, cz.toDouble()], 
      [cx - 0.5, -0.5, cz.toDouble()], 
    ]);
  }

  void _drawSubdividedPolygon(Canvas canvas, ui.Image image, Color tintColor, List<List<double>> points3D) {
    final paint = Paint()
      ..shader = ImageShader(
        image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage,
      )
      ..colorFilter = ColorFilter.mode(tintColor, BlendMode.multiply);

    const int segs = 4; 
    int numVertices = (segs + 1) * (segs + 1);
    var positions = Float32List(numVertices * 2);
    var texCoords = Float32List(numVertices * 2);
    var indices = Uint16List(segs * segs * 6);

    int vIdx = 0;
    int tIdx = 0;

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
      indices: indices,
    );

    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
  }
}