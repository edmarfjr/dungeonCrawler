import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'dungeon_map.dart';
import 'player_state.dart';

class MazeRenderer extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  DungeonMap map;
  PlayerState player;
  final List <ui.Image> wallImage;
  final List <ui.Image> floorImage;
  final ui.Image doorImage;
  final ui.Image doorImage2;
  final ui.Image keyImage;
  final ui.Image chestImage;
  final ui.Image crateImage;
  final ui.Image openChestImage;
  final List <ui.Image> trapImage;
  final ui.Image roamerImage;
  final ui.Image bossImage;
  final ui.Image shopImage;
  final ui.Image shrineImage;
  final ui.Image fontImage;

  double _bumpTimer = 0.0;
  double _maxBumpTime = 0.18; // Duração do tranco (180 milissegundos é o Sweet Spot)
  bool _bumpForward = true;

  MazeRenderer({
    required this.map,
    required this.player,
    required this.wallImage,
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
    required this.shopImage,
    required this.fontImage,
  });

  void triggerWallBump({required bool forward}) {
    _bumpTimer = _maxBumpTime;
    _bumpForward = forward;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_bumpTimer > 0) {
      _bumpTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    // 2. APLICA O TRANCO DE IMPACTO NA CÂMERA
    if (_bumpTimer > 0) {
      // Transforma o tempo em um progresso de 0.0 a 1.0
      double progress = 1.0 - (_bumpTimer / _maxBumpTime);
      
      // O Seno faz o valor subir suavemente e voltar (0 -> 1 -> 0)
      double intensity = sin(progress * pi);

      if (_bumpForward) {
        // Impacto andando para frente: Câmera avança 5% na parede e desce 14 pixels pelo baque
        double scalePunch = 1.0 + (intensity * 0.05); 
        double yJolt = intensity * 14.0;

        // Faz o Zoom acontecer a partir do centro da tela, em vez do canto superior esquerdo
        canvas.translate(gameRef.size.x / 2, gameRef.size.y / 2);
        canvas.scale(scalePunch);
        canvas.translate(-gameRef.size.x / 2, (-gameRef.size.y / 2) + yJolt);
      } else {
        // Impacto andando de costas: Câmera dá um solavanco rápido para cima
        double yJolt = -intensity * 10.0;
        canvas.translate(0, yJolt);
      }
    }

    // Fundo preto (teto e o vazio distante)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.black );

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

        int tileIdx = 0;
        Color corChao = Colors.white;
        Color corParede = Colors.white;

        if (map.level >= 4){
          tileIdx = 1;
        }

        if (map.level >= 7){
          tileIdx = 2;
        }

        // Sempre desenha o chão
        _drawFloorTile(canvas, cx, cz, floorImage[tileIdx], corChao);
        _drawCeiling(canvas, cx, cz,floorImage[tileIdx], corChao);

        // --- 1. LÓGICA DAS PAREDES SÓLIDAS ---
        if (tile == TileType.wall) {
          if (cx > 0) _drawLeftFace(canvas, cx, cz, wallImage[tileIdx], corParede); 
          if (cx < 0) _drawRightFace(canvas, cx, cz, wallImage[tileIdx], corParede); 
          if (cz > 0) _drawFrontFace(canvas, cx, cz, wallImage[tileIdx], corParede);
        }

        // --- 2. LÓGICA DA PORTA ---
        if (tile == TileType.door) {
          // A porta vai do chão (0.5) até quase o teto (-0.1)
           _drawFloorTile(canvas, cx, cz, doorImage, Colors.white);
        }

        if (tile == TileType.entry) {
           _drawCeiling(canvas, cx, cz, doorImage2, Colors.white);
        }

        

        // --- 3. LÓGICA DA CHAVE ---
        if (map.keyPosition != null && map.keyPosition!.x == mapX && map.keyPosition!.y == mapY && gameRef.currentState == GameState.exploration) {
          // A chave vai do chão (0.5) até uma altura menor (0.1)
          _drawBillboardItem(canvas, cx, cz, keyImage, 0.5, 0.1, Palette.amarelo);
        }

        if (tile == TileType.chest && gameRef.currentState == GameState.exploration) {
          _drawBillboardItem(canvas, cx, cz, chestImage, 0.5, 0.1, Palette.amarelo);
        }

        if (tile == TileType.font && gameRef.currentState == GameState.exploration) {
          _drawBillboardItem(canvas, cx, cz, fontImage, 0.6, 0.1, Colors.white);
        }

        if (tile == TileType.crate && gameRef.currentState == GameState.exploration) {
          _drawBillboardItem(canvas, cx, cz, crateImage, 0.5, 0.1, Palette.marrom);
        }

        if (tile == TileType.boss && gameRef.currentState == GameState.exploration) {
          _drawBillboardItem(canvas, cx, cz, bossImage, 0.6, 0.0, Palette.vermelho);
        }

         if (tile == TileType.shop && gameRef.currentState == GameState.exploration) {
          _drawBillboardItem(canvas, cx, cz, shopImage, 0.6, 0.0, Colors.white);
        }

        if (tile == TileType.openChest && gameRef.currentState == GameState.exploration) {
          _drawBillboardItem(canvas, cx, cz, openChestImage, 0.5, 0.1, Palette.amarelo);
        }

        if (tile == TileType.shrine && gameRef.currentState == GameState.exploration) {
          _drawBillboardItem(canvas, cx, cz, shrineImage, 0.5, 0.1, Colors.white);
        }

        if (tile == TileType.spike && gameRef.currentState == GameState.exploration) {
          // Sempre desenha o chão normal debaixo da armadilha
          _drawFloorTile(canvas, cx, cz, floorImage[tileIdx], corChao);

          // Calcula a largura de 1 frame (divide a spritesheet por 4)
          double frameWidth = trapImage[0].width / 4;
          
          // O frameX é o estado atual do mapa (0, 1, 2 ou 3)
          Rect frameRect = Rect.fromLTWH(map.spikeState * frameWidth, 0, frameWidth, trapImage[0].height.toDouble());

          // Desenha o espinho! O topY=0.2 garante que ele suba bastante em relação ao chão (0.5)
          _drawBillboardItem(canvas, cx, cz, trapImage[0], 0.7, 0.1,Colors.white, srcRect: frameRect);
        }

        if (tile == TileType.poison && gameRef.currentState == GameState.exploration) {
          // Sempre desenha o chão normal debaixo da armadilha
          _drawFloorTile(canvas, cx, cz, floorImage[tileIdx], corChao);

          // Calcula a largura de 1 frame (divide a spritesheet por 4)
          double frameWidth = trapImage[1].width / 4;
          
          // O frameX é o estado atual do mapa (0, 1, 2 ou 3)
          Rect frameRect = Rect.fromLTWH(map.spikeState * frameWidth, 0, frameWidth, trapImage[1].height.toDouble());

          // Desenha o espinho! O topY=0.2 garante que ele suba bastante em relação ao chão (0.5)
          _drawBillboardItem(canvas, cx, cz, trapImage[1], 0.7, 0.1,Colors.white, srcRect: frameRect);
        }

        Point<int> currentMapPos = Point(mapX, mapY);
        if (map.droppedItems.containsKey(currentMapPos) && map.droppedItems[currentMapPos]!.isNotEmpty && gameRef.currentState == GameState.exploration) {
          
          for(var item in map.droppedItems[currentMapPos]!.reversed){
            try {
            // Puxa a imagem verdadeira do item usando o cache do Flame!
            ui.Image itemImg = gameRef.images.fromCache(item.imagePath);
            
            // Desenha usando o Billboarding. O item flutua da altura 0.5 (chão) até a 0.2
            _drawBillboardItem(canvas, cx, cz, itemImg, 0.5, 0.2, item.cor);
          } catch (e) {
            // Fallback de segurança: Se a imagem falhar ao carregar, desenha uma caixinha/baú
            _drawBillboardItem(canvas, cx, cz, chestImage, 0.5, 0.2, item.cor);
          }
          }
          // Pega sempre o item que está no topo da pilha do chão (last)
         // var dropItem = map.droppedItems[currentMapPos]!.last;
          
          
        }
        
        for (var enemy in map.roamingEnemies) {
          
          // Se o inimigo estiver na coordenada que o laço está varrendo agora...
          if (enemy.x == mapX && enemy.y == mapY && gameRef.currentState == GameState.exploration) {
            // Desenha ele no chão (0.5), um pouco esticado pra cima (0.0) para parecer intimidador
            _drawBillboardItem(canvas, cx, cz, roamerImage, 0.6, 0.0,Palette.vermelho);
          }
        }
      }
    }

    canvas.restore();
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

    // Calcula a escuridão bruta
    double rawDarkness = (zCenter / 5.0).clamp(0.0, 1.0);
    
    // O EFEITO CROCANTE: Quebra o degradê em 4 níveis rígidos (0%, 25%, 50%, 75%, 100%)
    double darkness = (rawDarkness * 4).round() / 4.0;
    
    // Mistura a cor
    Color darkenedColor = Color.lerp(cor, Colors.black, darkness)!;

    // Projeta as alturas baseadas nos parâmetros informados
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

    // Usa a nova cor escurecida no ColorFilter
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(darkenedColor, BlendMode.modulate);

    canvas.drawImageRect(
      image,
      srcRect ?? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dstRect,
      paint
    );
  }

  // MÉTODOS 3D:
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
    // Usamos a mesma floorImage, mas mudamos o eixo Y de 0.5 para -0.5
    _drawSubdividedPolygon(canvas, img, color, [
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
      );

    const int segs = 4; 
    int numVertices = (segs + 1) * (segs + 1);
    
    var positions = Float32List(numVertices * 2);
    var texCoords = Float32List(numVertices * 2);
    var indices = Uint16List(segs * segs * 6);
    var colors = Int32List(numVertices); // Lista de cores pronta para receber dados

    int vIdx = 0;
    int tIdx = 0;
    int cIdx = 0; // NOVO: Índice para rastrear a cor de cada vértice

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

       // Escuridão bruta baseada na profundidade daquele pedacinho
        double rawDarkness = (finalZ / 4.5).clamp(0.0, 1.0);
        
        // Aplica a mesma quebra para criar faixas duras de sombra na parede
        double darkness = (rawDarkness * 4).round() / 4.0;
        
        Color vertexColor = Color.lerp(tintColor, Colors.black, darkness)!;
        
        // Aplica a cor escurecida diretamente no vértice atual
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