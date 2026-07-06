import 'dart:math';
import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/Effects/healing_cloud_effect.dart';
import 'package:dungeon_crawler/game/components/core/audio_manager.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/arc_projectile.dart';
import 'package:dungeon_crawler/game/components/entities/combat_entities.dart';
import 'package:dungeon_crawler/game/components/entities/fire_pillar.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:dungeon_crawler/game/components/entities/poison_cloud.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

enum EnemyType { slime, spider, goblin, mimic, orc, bat, boss1, bug, worm, ovo, fungo, fungo2, infectado, boss2, 
garra, esqueleto, jester, naga, mao, doll, goblinShop, boss3, aberraBruto, aberraVoa, aberraBesta, aberraArv, aberraCult,
aberraOvo, tentaculo, boss4 }

abstract class Enemy extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  final EnemyType type;
  final Color color;
  final double width, height, maxAttackCooldown;
  double hitFlashTimer = 0.0;
  Color flashColor = Palette.branco;
  double deathTimer = 0.5;

  final double hurtboxWidth, hurtboxHeight, hurtboxOffsetX, hurtboxOffsetY;
  final double hitboxWidth, hitboxHeight, hitboxOffsetX, hitboxOffsetY;

  double hp, maxHp, dropEssence, damage;
  double yPosition, targetY, speed, attackCooldown;
  double strafePosition = 0.0, animTimer = 0.0;
  bool isAlive = true, attackHit = false, isDying = false;
  CombatPhase currentPhase = CombatPhase.idle;
  CombatPhase dieAnim;

  bool get isVulnerable => true;
  bool isMelee;

  bool isFrontRow = true;

  bool get _EstaAtacando {
    return 
      currentPhase == CombatPhase.windup || 
      currentPhase == CombatPhase.active || 
      currentPhase == CombatPhase.recovery ||
      currentPhase == CombatPhase.windup2 || 
      currentPhase == CombatPhase.active2 || 
      currentPhase == CombatPhase.recovery2 ||
      currentPhase == CombatPhase.summon
      ;
    
  }
  bool get canChangeRow => !_EstaAtacando;

  double visualScale = 1.0; 
  double visualYOffset = 0.0;
  double visualDarkness = 0.0;

  double rowSwapTimer = 2.0;

  bool _lastRow = true;   
  double jumpTimer = 0.0;
  double maxJumpTime = 0.7;  
  double maxJumpHeight = 0.1;
  double jumpOffset = 0.0;
  double flightOffset = 0.0;

  bool isBoss;

  bool naoInterrompe = false;

  String name;
  
  bool isHeavyAttack = false;

  List<Item> drop ;

  bool isFlipped = false;

  bool isPoison = false;
  double poisonTmr = 2;
  bool imunePoison;

  double ritualTmr = 0;

  Enemy({
    required this.name, required this.type, required this.color, required this.hp, required this.maxHp,
    required this.dropEssence, required this.width, required this.height,
    required this.hurtboxWidth, required this.hurtboxHeight, this.hurtboxOffsetX = 0.0, this.hurtboxOffsetY = 0.0,
    required this.hitboxWidth, required this.hitboxHeight, this.hitboxOffsetX = 0.0, this.hitboxOffsetY = 0.0,
    this.yPosition = 0.75, this.targetY = 0.75,
    this.speed = 0.4, this.maxAttackCooldown = 2.0, this.damage = 3,
    this.isMelee = true,
    this.isBoss = false,
    this.dieAnim = CombatPhase.hit,
    this.imunePoison = false,
    required this.drop,
  }) : attackCooldown = Random().nextDouble() * maxAttackCooldown, 
       super(anchor: Anchor.center
      ); // Anchor Center ajuda muito no Flame!

  void applyHitStun(double duration) {
    flashColor = Palette.vermelho;
    hitFlashTimer = duration;
    if(!naoInterrompe){
      currentPhase = CombatPhase.hit;
      attackHit = false; 
      attackCooldown = maxAttackCooldown / 2; 
      onHitStun(); 
    }
    
  }

  void applyHitGuard(double duration) {
    flashColor = Palette.cinzaMed;
    hitFlashTimer = duration;
  }

  void onHitStun() {}

  @override
  void update(double dt) {
    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;
    super.update(dt);
    priority = isFrontRow ? 10 : 0;

    if (!isAlive) return;
    if (gameRef.activeMessage != null) return;

    if(isPoison && !imunePoison){
      poisonTmr -= dt;
      if(poisonTmr<=0){
        hp -= game.playerCombatStats.wis/2;
        poisonTmr = 2;
        game.combatOverlay.addFloatingText((game.playerCombatStats.wis/2).toString(), getHurtbox(size), Palette.verde);
        if (hp<=0)isDying = true;
      }
    }

    // --- Animação suave entre a linha de frente e de trás ---
    if (isFrontRow != _lastRow) {
      _lastRow = isFrontRow;
      jumpTimer = maxJumpTime; // A duração do salto será de 400 milissegundos
    }

    // 2. Calcula a altura do salto usando um arco de Seno (Sobe e Desce)
    
    if (jumpTimer > 0) {
      jumpTimer -= dt;
      // Transforma o tempo num progresso de 0.0 a 1.0
      double progress = 1.0 - (jumpTimer / maxJumpTime).clamp(0.0, 1.0);
      
      // O sin() com pi desenha o arco. Multiplicamos por -0.2 para ele subir no ecrã!
      jumpOffset = -sin(progress * pi) * maxJumpHeight; 
    }

    // 3. Destinos da profundidade
    double targetScale = isFrontRow ? 1.0 : 0.85;
    double targetYOffset = isFrontRow ? 0.0 : -0.02; 
    double targetDarkness = isFrontRow  ? 0.0 : 0.6; 

    double transitionSpeed = 4.6 / maxJumpTime;

    visualScale += (targetScale - visualScale) * transitionSpeed * dt;
    visualYOffset += (targetYOffset - visualYOffset) * transitionSpeed * dt;
    visualDarkness += (targetDarkness - visualDarkness) * transitionSpeed * dt;

    // 4. Aplica a posição visual final
    double scale = gameRef.size.x * 0.35;
    double cx = (gameRef.size.x / 2) + (strafePosition * scale);
    
    // NOVO: Descobre a linha exata do chão (a sua linha azul claro)
    double baseFloorY = gameRef.size.y * (yPosition + visualYOffset);
    
    // NOVO: Calcula a distância do centro do sprite até a sola do pé (base da hurtbox)
    double distanceToFeet = (hurtboxOffsetY * visualScale) + ((hurtboxHeight / 2) * visualScale);
    
    // NOVO: O 'cy' agora empurra o personagem para cima para o pé cravar no chão, e soma o pulo!
    double cy = baseFloorY - distanceToFeet + (gameRef.size.y * jumpOffset) + (gameRef.size.y * flightOffset);
    
    position = Vector2(cx, cy);
    size = Vector2(width * visualScale, height * visualScale);
    // ----------------------------------------------------------------------

    if (isDying) {
      hitFlashTimer = 0;
      currentPhase = CombatPhase.die;
      deathTimer -= dt;
      if (deathTimer <= 0) {
        if(isBoss){
          gameRef.player.hasKey = true;
          gameRef.showMessage("Você encontrou a Chave da Masmorra!");
        }

        isAlive = false; 
        removeFromParent(); 
        gameRef.combatOverlay.enemies.remove(this); 
       
      }
      return; 
    }

    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
      if (hitFlashTimer <= 0 && currentPhase == CombatPhase.hit) currentPhase = CombatPhase.idle;
      if(!naoInterrompe)return; 
    }
    if (game.playerCombatStats.currentPhase == CombatPhase.entering || game.playerCombatStats.reflex) return;
    _updatePhase(dt);

    bool isAttacking = currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery ||
    currentPhase == CombatPhase.windup2 || currentPhase == CombatPhase.active2 || currentPhase == CombatPhase.recovery2;
    
    if (!isAttacking && !isDying) {
      if ((yPosition - targetY).abs() > 0.01) yPosition += (targetY > yPosition ? 1 : -1) * speed * dt; 
      updateBehavior(dt, gameRef.playerCombatStats);
      checkAttackDecision(dt, gameRef.playerCombatStats, gameRef.size);

      
      rowSwapTimer -= dt;
      if (!isFrontRow && canChangeRow && rowSwapTimer <= 0) {
        int frontRowCount = gameRef.combatOverlay.enemies.where((e) => e.isFrontRow && e.isAlive).length;
        if (frontRowCount < 2) {
          isFrontRow = true; 
          rowSwapTimer = 1.5; // Dá um tempo para ele respirar antes de tentar recuar de novo
        }
      }

      // 2. DECISÃO VOLUNTÁRIA (Recuar ou Trocar de lugar)
      // Só entra aqui se o Vácuo não tiver puxado ele neste exato milissegundo.
      if (rowSwapTimer <= 0) {
        rowSwapTimer = 1.0 + Random().nextDouble() * 2.0; // Pensa novamente entre 1s e 3s
        
        if (canChangeRow) { 
          if (isFrontRow) {
            // --- REGRA DE RECUO ---
            // Conta quantos inimigos existem no TOTAL na batalha
            int totalEnemies = gameRef.combatOverlay.enemies.where((e) => e.isAlive).length;
            
            // Se a batalha tem 2 ou menos inimigos no total, a chance de recuar é pequena (15%)
            // Se for uma horda (3 ou mais), eles recuam mais vezes (40%) para rodar os monstros.
            double retreatChance = totalEnemies <= 2 ? 0.15 : 0.40;

            if (Random().nextDouble() < retreatChance) { 
               isFrontRow = false; // Recua voluntariamente!
               rowSwapTimer = 2.0; // TRAVA DE SEGURANÇA: Fica no MÍNIMO 2 segundos lá atrás imune ao Vácuo
            }
          } else {
            // --- REGRA DE TROCA ---
            // Está atrás, mas o Vácuo não o puxou (ou seja, a frente já tem 2 monstros). 
            // Ele tenta forçar uma troca com um colega!
            var swappableEnemies = gameRef.combatOverlay.enemies.where((e) => 
                e.isFrontRow && 
                e.isAlive && 
                e.canChangeRow &&
                (e.currentPhase == CombatPhase.idle || e.currentPhase == CombatPhase.walk) &&
                e != this
              ).toList();

            if (swappableEnemies.isNotEmpty && Random().nextDouble() < 0.40) {
                // Manda o colega da frente recuar...
                swappableEnemies.first.isFrontRow = false; 
                swappableEnemies.first.rowSwapTimer = 2.0; // Trava o colega atrás para ele não dar bate-volta!
                
                // ...e avança para o lugar dele!
                isFrontRow = true; 
                rowSwapTimer = 2.0;
            }
          }
        }
      }
    }

    if ((currentPhase == CombatPhase.active || currentPhase == CombatPhase.active2) && !attackHit && isMelee && isFrontRow) {
      if (getHitbox(gameRef.size).overlaps(gameRef.playerCombatStats.getHurtbox(gameRef.size))) {
        attackHit = true;
        gameRef.applyEnemyDamage(this);
        gameRef.playerCombatStats.hitFlashTimer = 0.20;
        if (gameRef.playerCombatStats.hp <= 0) gameRef.handlePlayerDeath();
      }
    }
  }

  void updateBehavior(double dt, PlayerCombatStats player);

  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = 20;//(hitboxWidth / 2) + (player.hurtboxWidth / 2);

    attackCooldown -= dt;
    bool isCloseY = type == EnemyType.spider ? yPosition >= 0.4 : true;

    // NOVO: Adicionado '&& isFrontRow' - Inimigos na linha de trás NUNCA atacam!
    if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0 && currentPhase == CombatPhase.idle && isFrontRow) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.5; 
      attackCooldown = maxAttackCooldown;
    }
  }

  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) { currentPhase = CombatPhase.active; animTimer = 0.15; attackHit = false; AudioManager.playSfx('sfx/claw.wav'); }
        else if (currentPhase == CombatPhase.active) { currentPhase = CombatPhase.recovery; animTimer = 0.6; } 
        else { currentPhase = CombatPhase.idle; }
      }
    }
  }

  void renderShadow(Canvas canvas) {
    final shadowPaint = Paint()..color = Colors.black..isAntiAlias = false;
      
    double scaleToUse = (visualScale > 0) ? visualScale : 1.0;
    double actualHurtboxWidth = hurtboxWidth * scaleToUse;
    double actualHurtboxHeight = hurtboxHeight * scaleToUse;

    double shadowWidth = actualHurtboxWidth * 1;  
    double shadowHeight = shadowWidth * 0.4; 
    
    // ========================================================================
    // 1. O CHÃO VERDADEIRO DA MASMORRA
    // Inimigos voadores ou de teto (spider, bat) ficam com o 'yPosition' no alto, 
    // mas a sombra deles tem que ser cravada no 0.75 (chão)!
    // Adicione o Fungo ou outros inimigos voadores nesta lista se precisarem.
    double groundYPos = (type == EnemyType.spider || type == EnemyType.bat || type == EnemyType.fungo
    || type == EnemyType.doll || type == EnemyType.goblinShop || type == EnemyType.boss3
    || type == EnemyType.aberraVoa || type == EnemyType.boss4 || type == EnemyType.tentaculo) ? 0.75 : yPosition;

    // 2. CALCULA O VÃO ATÉ O CHÃO (Gap to Floor)
    // Calcula a distância do centro do inimigo até o chão verdadeiro, somando 
    // todas as variáveis que fazem o bicho flutuar ou pular.
    // (Lembre-se: jumpOffset e flightOffset são negativos quando sobem, então 
    // subtraí-los aqui empurra a sombra positivamente para baixo da tela!)
    double gapToFloor = (groundYPos - yPosition - visualYOffset - jumpOffset - flightOffset) * gameRef.size.y;
    // ========================================================================

    // 3. ENCONTRAR A BASE DOS PÉS NO CANVAS
    double localHurtboxBottomY = (size.y / 2) + (hurtboxOffsetY * scaleToUse) + (actualHurtboxHeight / 2);
    
    // A sombra desce a partir dos pés e atravessa o ar até bater no chão verdadeiro
    double shadowLocalY = localHurtboxBottomY + gapToFloor;
    double shadowLocalX = (size.x / 2);

    // 4. ESCALA DE ALTITUDE
    // Quanto maior for o vão entre o monstro e o chão, menor a sombra fica!
    double altitudeScale = 1.0;
    if (gapToFloor > 0) {
        altitudeScale = (1.0 - (gapToFloor / gameRef.size.y) * 1.5).clamp(0.2, 1.0);
    }

    // 5. DESENHA A SOMBRA
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(shadowLocalX, shadowLocalY), 
        width: shadowWidth * altitudeScale, 
        height: shadowHeight * altitudeScale
      ),
      shadowPaint,
    );
  }

  @override
  void render(Canvas canvas) {
    if (isDying && (deathTimer * 15).toInt() % 2 == 0) return;
    if (hitFlashTimer>0 && (hitFlashTimer * 15).toInt() % 2 == 0) return;
    
    if (type == EnemyType.spider) {
      final webPaint = Paint()..color = Palette.branco..strokeWidth = 5.0..style = PaintingStyle.stroke..isAntiAlias = false;
      final webPaintBorder = Paint()..color = Palette.preto..strokeWidth = 15.0..isAntiAlias = false..style = PaintingStyle.stroke;  
      
      double screenTopLocalY = -(position.y - size.y / 2);
      double posX = size.x / 2 + 4;
      canvas.drawLine(Offset(posX, size.y / 2), Offset(posX, screenTopLocalY), webPaintBorder);
      canvas.drawLine(Offset(posX, size.y / 2), Offset(posX, screenTopLocalY), webPaint);
    }

    if (type == EnemyType.doll) {
      final webPaint = Paint()..color = Palette.bege..strokeWidth = 5.0..style = PaintingStyle.stroke..isAntiAlias = false;
      final webPaintBorder = Paint()..color = Palette.preto..strokeWidth = 15.0..isAntiAlias = false..style = PaintingStyle.stroke;  
      
      double screenTopLocalY = -(position.y - size.y / 2);
      double posX = size.x / 2 + 4;
      canvas.drawLine(Offset(posX+hurtboxWidth/2, size.y / 2), Offset(posX, screenTopLocalY), webPaintBorder);
      canvas.drawLine(Offset(posX+hurtboxWidth/2, size.y / 2), Offset(posX, screenTopLocalY), webPaint);

      canvas.drawLine(Offset(posX-hurtboxWidth/2, size.y / 2), Offset(posX, screenTopLocalY), webPaintBorder);
      canvas.drawLine(Offset(posX-hurtboxWidth/2, size.y / 2), Offset(posX, screenTopLocalY), webPaint);

      canvas.drawLine(Offset(posX, size.y / 2), Offset(posX, screenTopLocalY), webPaintBorder);
      canvas.drawLine(Offset(posX, size.y / 2), Offset(posX, screenTopLocalY), webPaint);
    }

    SpriteAnimationTicker activeTicker = gameRef.combatOverlay.getTickerForEnemy(this);
    final Color flashC =  Colors.white; 
    int r = (flashC.red * (1.0 - visualDarkness)).toInt().clamp(0, 255);
    int g = (flashC.green * (1.0 - visualDarkness)).toInt().clamp(0, 255);
    int b = (flashC.blue * (1.0 - visualDarkness)).toInt().clamp(0, 255);
    Color finalColor = (gameRef.playerCombatStats.currentPhase == CombatPhase.entering || ritualTmr>0) ? Palette.preto : Color.fromARGB(flashC.alpha, r, g, b);
    
    final tintPaint = Paint()..colorFilter = ColorFilter.mode(finalColor, BlendMode.modulate);

    // =================================================================
    // CORREÇÃO CRÍTICA: O save() deve acontecer SEMPRE, independentemente do if!
    canvas.save(); 

    if (isFlipped) {
      canvas.translate(size.x, 0); 
      canvas.scale(-1.0, 1.0); 
    }

    activeTicker.getSprite().render(canvas, size: size, overridePaint: tintPaint);
    
    canvas.restore(); // Agora ele vai restaurar com segurança SEMPRE!
    // =================================================================
  }

  Rect getHurtbox(Vector2 screenSize) {
    return Rect.fromCenter(
      center: Offset(
        position.x + (hurtboxOffsetX * visualScale), 
        position.y + (hurtboxOffsetY * visualScale)
      ), 
      width: hurtboxWidth * visualScale, 
      height: hurtboxHeight * visualScale
    );
  }

  Rect getHitbox(Vector2 screenSize) {
    return Rect.fromCenter(
      center: Offset(
        position.x + (hitboxOffsetX * visualScale), 
        position.y + (hitboxOffsetY * visualScale)
      ), 
      width: hitboxWidth * visualScale, 
      height: hitboxHeight * visualScale
    );
  }

  Rect getHitboxImageSize(Vector2 screenSize) {
    return Rect.fromCenter(
      center: Offset(
        position.x + (hitboxOffsetX * visualScale), 
        position.y + (hitboxOffsetY * visualScale)
      ), 
      width: 120 * visualScale, 
      height: 120 * visualScale
    );
  }

  void checkAttackPadrao (double dt, PlayerCombatStats player, Vector2 screenSize,{double dist = 20, double windupTmr = 0.5}) {
    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = dist;//(hitboxWidth / 2) + (player.hurtboxWidth / 2);

    attackCooldown -= dt;
    bool isCloseY = type == EnemyType.spider ? yPosition >= 0.4 : true;

    // NOVO: Adicionado '&& isFrontRow' - Inimigos na linha de trás NUNCA atacam!
    if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0 && currentPhase == CombatPhase.idle && isFrontRow) {
      currentPhase = CombatPhase.windup;
      animTimer = windupTmr; 
      attackCooldown = maxAttackCooldown;
    }
  }

}


class EnemyShadowsRenderer extends Component with HasGameRef<DungeonCrawlerGame> {
  EnemyShadowsRenderer() : super(priority: -5); // Prioridade -5 garante que roda ANTES de qualquer inimigo!

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Percorre a lista de inimigos ativos na batalha
    for (var enemy in gameRef.combatOverlay.enemies) {
      if (!enemy.isAlive) continue;

      // Salva o estado do canvas para não bagunçar o resto do jogo
      canvas.save();
      
      // O Flame move o Canvas para o canto Top-Left de cada componente ao renderizar.
      // Como o Anchor do seu Enemy é Center, calculamos a quina superior esquerda dele:
      double topLeftX = enemy.position.x - (enemy.size.x / 2);
      double topLeftY = enemy.position.y - (enemy.size.y / 2);
      
      // Desloca o Canvas global para a posição simulada do inimigo
      canvas.translate(topLeftX, topLeftY);

      // Manda o inimigo desenhar APENAS a sombra dele ali
      enemy.renderShadow(canvas);

      // Restaura o Canvas para a posição original antes de ir para o próximo monstro
      canvas.restore();
    }
  }
}

class SlimeEnemy extends Enemy {
  double moveTimer = 0.0;
  double currentDir = 1.0;

  SlimeEnemy() : super(name: 'slime',
    type: EnemyType.slime, color: Palette.verdeCla, hp: 50, maxHp: 50, dropEssence: 10, width: 144, height: 144, speed: 0.4,
    hurtboxWidth: 130, hurtboxHeight: 70, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30,
    drop: [ItemDatabase.slimeEye]
  );

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    moveTimer -= dt;
    if (moveTimer <= 0) {
      currentDir = (Random().nextInt(3) - 1).toDouble();
      moveTimer = 1.0 + Random().nextDouble() * 1.5;

    }
    
    // 2. Aplica o movimento horizontal
    strafePosition += currentDir * speed * dt;
    if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
    if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
  }
}

class GoblinEnemy extends Enemy {
  bool isFleeing = false;
  GoblinEnemy() : super(name: 'goblin',
    type: EnemyType.goblin, color: Palette.verde, hp: 60, maxHp: 60, dropEssence: 15, width: 144, height: 144, speed: 0.6, damage: 5,
    hurtboxWidth: 60, hurtboxHeight: 90, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 40, hitboxOffsetX: 10, maxAttackCooldown: 1.0,drop: [ItemDatabase.faca]
  );

  @override 
  void onHitStun() { 
    isFleeing = true; 
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize);
  }
  
  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();

    // --- GATILHO 2: O GOBLIN TERMINA DE ATACAR OU ESTÁ SEM COOLDOWN ---
    // Se ele está perto do player, mas não pode atacar (pois acabou de bater 
    // ou você correu atrás dele), ele entra em desespero e foge!
    if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
      isFleeing = true;
    }

    // --- GATILHO 3: O GOBLIN BATEU NA PAREDE ---
    // Se ele fugiu e bateu nas bordas (-1.0 ou 1.0), ele recupera a coragem 
    // e volta a focar em seguir o jogador.
    if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
      isFleeing = false;
    }

    // --- LÓGICA DE MOVIMENTO ---
    if (isFleeing) {
      // Foge para a direção OPOSTA ao jogador
      double dir = -(player.strafePosition - strafePosition).sign;
      if (dir == 0) dir = 1.0; // Previne que ele fique congelado se estiverem em cima um do outro
      strafePosition += dir * speed * dt;
    } else {
      // Vai para a direção DO jogador (com zona morta para não tremer)
      if (distanceToPlayer > 0.01) {
        double dir = (player.strafePosition - strafePosition).sign;
        strafePosition += dir * speed * dt;
      }
    }

    // Garante que não vai sair da tela
    strafePosition = strafePosition.clamp(-1.0, 1.0);
  }
}

class SpiderEnemy extends Enemy {
  bool isDropping = false;
  bool hasAttacked = false;
  double landTmr = 0.0;
  double speedIni = 0.4;

  SpiderEnemy() : super(name: 'aranha',
    type: EnemyType.spider, color: Palette.marromCla, hp: 30, maxHp: 30, dropEssence: 10, width: 144, height: 144, yPosition: 0.2, targetY: 0.2,
    hurtboxWidth: 60, hurtboxHeight: 70, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30, drop: [ItemDatabase.web]
  );

  @override
  bool get canChangeRow => (yPosition - targetY).abs() < 0.01 && yPosition <= 0.2;

  @override void onHitStun() {
    isDropping = false; 
    hasAttacked = false; 
    targetY = 0.2; 
  }
  
  @override void updateBehavior(double dt, PlayerCombatStats player) {
    if(isFrontRow){
      // 1. GATILHO PARA DESCER
      if (!isDropping && yPosition <= 0.25 && (player.strafePosition - strafePosition).abs() < 0.2) {
        isDropping = true; 
        speed = speedIni * 2;
        hasAttacked = false; 
        targetY = 0.75; 
      }
      
      // 2. GATILHO PARA SUBIR (SÓ DEPOIS QUE ATACAR)
      // Se a aranha desceu, já completou o ataque e voltou para o modo Idle, ela sobe para o teto.
      if (isDropping && hasAttacked && currentPhase == CombatPhase.idle) {
        speed = speedIni;
        isDropping = false; 
        targetY = 0.2; // Volta pro teto

      }
    }
    
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    if (isDropping && !hasAttacked && yPosition >= 0.69 && currentPhase == CombatPhase.idle && isFrontRow) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.5; 
      hasAttacked = true; 
      attackCooldown = maxAttackCooldown; 
    }
  }
}

class MimicEnemy extends Enemy {
  double moveTimer = 0.0; 
  double currentDir = 1.0;
  bool _spawnedProjectiles = false;

  MimicEnemy() : super(name: 'mimico',
    type: EnemyType.mimic, color: Palette.amarelo, hp: 60, maxHp: 60, dropEssence: 40, width: 144, height: 144, speed: 0.5, damage: 10,
    hurtboxWidth: 90, hurtboxHeight: 90, hurtboxOffsetY: 10,
    hitboxWidth: 0, hitboxHeight: 0, isMelee: false, drop: []
  );/*{
    List<Item> allEquipments = [
          ItemDatabase.espadaCurta,
          ItemDatabase.armaduraFerro,
          ItemDatabase.espadaLonga,
          ItemDatabase.armaduraCouro,
          ItemDatabase.machado,
          ItemDatabase.firePillar,
          ItemDatabase.escudoMadeira,
          ItemDatabase.escudoFerro,
          ItemDatabase.piercingShot,
          ItemDatabase.toxicCloud,
        ];

    List<Item> unownedEquipments = allEquipments.where((equip) {
          return !game.playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
        }).toList();    

    drop.add(unownedEquipments[Random().nextInt(unownedEquipments.length)]);
  } */

  // MÁGICA 1: Só toma dano enquanto ataca!
  @override
  bool get isVulnerable => currentPhase == CombatPhase.hit || currentPhase == CombatPhase.windup ||  currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    // Anda aleatoriamente igual ao Slime
    moveTimer -= dt;
    if (moveTimer <= 0) {
      currentDir = (Random().nextInt(3) - 1).toDouble();
      moveTimer = 1.0 + Random().nextDouble() * 1.5;
    }
    strafePosition += currentDir * speed * dt;
    if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
    if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
   
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && isFrontRow) {
      currentPhase = CombatPhase.windup; 
      animTimer = 1.0; 
      attackCooldown = maxAttackCooldown;
      _spawnedProjectiles = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt); // Chama o update do Flame!

    // MÁGICA 2: Dispara os 3 projéteis na fase ativa
    if (currentPhase == CombatPhase.active && !_spawnedProjectiles) {
      _spawnedProjectiles = true;
      // Projétil Esquerdo, Central e Direito
      parent?.add(ArcProjectile(strafePosition, yPosition, -1, -1.2, this)); 
      parent?.add(ArcProjectile(strafePosition, yPosition,  0.0, -1.4, this)); 
      parent?.add(ArcProjectile(strafePosition, yPosition,  1, -1.2, this));
    }
  }
}

class OrcEnemy extends Enemy {
  bool isFleeing = false;
  OrcEnemy() : super(name: 'orc',
    type: EnemyType.orc, 
    color: Palette.cinza, // Cor do escudo/armadura
    hp: 80, maxHp: 80, dropEssence: 20, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 130, hurtboxOffsetY: 0, damage: 12,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 20, hitboxOffsetX: 20,drop: [ItemDatabase.clavaOrc]
  ) {
    isMelee = true;
  }

  // --- REGRA DE OURO: Só recebe dano se NÃO estiver a guarder ---
  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    // 1. Lê a "mente" do jogador: O jogador levantou a espada ou está a atacar?
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    // 2. Lê o próprio estado: Eu já comecei a atacar?
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery;

    // --- INTELIGÊNCIA DE DEFESA ---
    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer <= 0.3) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    // --- MOVIMENTO NORMAL ---
    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      

      if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
        isFleeing = true;
      }

      if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
        isFleeing = false;
      }

      // --- LÓGICA DE MOVIMENTO ---
      if (isFleeing) {
        // Foge para a direção OPOSTA ao jogador
        double dir = -(player.strafePosition - strafePosition).sign;
        if (dir == 0) dir = 1.0; // Previne que ele fique congelado se estiverem em cima um do outro
        strafePosition += dir * speed * dt;
      } else {
        // Vai para a direção DO jogador (com zona morta para não tremer)
        if (distanceToPlayer > 0.01) {
          double dir = (player.strafePosition - strafePosition).sign;
          strafePosition += dir * speed * dt;
        }
      }

      // Garante que não vai sair da tela
      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize);
  }
}

class BatEnemy extends Enemy {
  double currentDir = 1.0;
  
  final double flightHeight = 0.3; 
  final double attackHeight = 0.75;   
  double targetStrafe = 0;

  BatEnemy() : super(
    type: EnemyType.bat, name: 'bat',
    color: Palette.roxo, 
    hp: 40, maxHp: 40, dropEssence: 10, width: 144, height: 144, speed: 0.5,
    hurtboxWidth: 60, hurtboxHeight: 60, hurtboxOffsetX: 0, hurtboxOffsetY: 0, damage: 5,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetX: 0, hitboxOffsetY: 10,drop: [ItemDatabase.meat]
  ) {
    isMelee = true;
    yPosition = flightHeight; 
    targetY = flightHeight;
  }


  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    if (currentPhase == CombatPhase.idle) {
      targetY = flightHeight; 

      if ((yPosition - flightHeight).abs() < 0.05) {
        strafePosition += currentDir * speed * dt;
        
        if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
        if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
      }
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
   
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && (yPosition - flightHeight).abs() < 0.05 && isFrontRow) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.5; 
      targetY = attackHeight; 
      attackCooldown = maxAttackCooldown;
      targetStrafe = gameRef.playerCombatStats.strafePosition;
    }
  }

  @override
  void update(double dt) {
    super.update(dt); 

    if (currentPhase == CombatPhase.windup) {
      priority = 15;
      targetY = attackHeight;

      double dx = targetStrafe - strafePosition;
      double dy = targetY - yPosition;
      
      double distance = sqrt(dx * dx + dy * dy);

      if (distance > 0.01) {
        double diveSpeed = speed*3; 
        double moveStep = diveSpeed * dt;

        if (moveStep > distance) moveStep = distance;

        strafePosition += (dx / distance) * moveStep;
        yPosition += (dy / distance) * moveStep;
      }

    } else {
      if(isDying) return;
      if ((yPosition - targetY).abs() > 0.01) {
        double verticalSpeed = speed; 
        yPosition += (targetY > yPosition ? 1 : -1) * verticalSpeed * dt;
      }

      if (currentPhase == CombatPhase.recovery || currentPhase == CombatPhase.active || currentPhase == CombatPhase.hit) {
        targetY = attackHeight; 
      } else if (currentPhase == CombatPhase.idle) {
        targetY = flightHeight; 
        priority = isFrontRow ? 10 : 0;
      }
    }
  }
}

class OrcChefe extends Enemy {
  bool isSummoning = false;
  double summonCooldown = 5.0;
  bool isFleeing = false;

  OrcChefe() : super(
    name: 'orcChefe',isBoss: true,
    type: EnemyType.boss1, 
    color: Palette.vermelhoEsc, 
    hp: 300, maxHp: 300, dropEssence: 100, 
    width: 192, height: 192, speed: 0.45, damage: 20, isMelee: true,
    hurtboxWidth: 100, hurtboxHeight: 160, hurtboxOffsetY: 0,
    hitboxWidth: 90, hitboxHeight: 90, hitboxOffsetY: 40, hitboxOffsetX: 20,drop: [ItemDatabase.espadaOrc]
  );

  @override
  bool get isMelee => !isSummoning;

  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();

    if (isSummoning || currentPhase == CombatPhase.summon) {
      return; 
    }
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery ||
                           currentPhase == CombatPhase.windup2 || 
                           currentPhase == CombatPhase.active2 || 
                           currentPhase == CombatPhase.recovery2;

    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer <= 0.3) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
        isFleeing = true;
      }

      if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
        isFleeing = false;
      }

      if (isFleeing) {
        double dir = -(player.strafePosition - strafePosition).sign;
        strafePosition += dir * speed * dt;
      } else {
        if (distanceToPlayer > 0.01) {
          double dir = (player.strafePosition - strafePosition).sign;
          strafePosition += dir * speed * dt;
        }
      }

      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
    summonCooldown -= dt;

    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = 20;//(hitboxWidth / 2) + (player.hurtboxWidth / 2);

    bool isCloseY = true;

    if (currentPhase == CombatPhase.idle && isFrontRow) {
      
      if (summonCooldown <= 0) {
        isSummoning = true;
        isFrontRow = false;
        currentPhase = CombatPhase.summon;
        animTimer = 1.0;
        summonCooldown = 15.0 + Random().nextDouble() * 5.0; 
        return;
      }

      if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0) {
        isSummoning = false;
        isHeavyAttack = !isHeavyAttack;

        naoInterrompe = isHeavyAttack;

        if(isHeavyAttack){
          currentPhase = CombatPhase.windup2;
        }else{
          currentPhase = CombatPhase.windup;
        }
        
        animTimer = isHeavyAttack ? 0.8 : 0.5; 
        attackCooldown = maxAttackCooldown;
        
        damage = isHeavyAttack ? 25 : 15; 
      }
    }
  }

  @override
  void _updatePhase(double dt) {

    if (isSummoning) {
      if (currentPhase == CombatPhase.summon) {
        animTimer -= dt;
        if (animTimer <= 0) {
          _spawnGoblin();
          currentPhase = CombatPhase.idle;
          isSummoning = false;
        }
      }
      return;
    }
    if (currentPhase == CombatPhase.windup2 || currentPhase == CombatPhase.active2 || currentPhase == CombatPhase.recovery2) {
      animTimer -= dt;
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup2) { currentPhase = CombatPhase.active2; animTimer = 0.15; attackHit = false;AudioManager.playSfx('sfx/claw.wav'); }
        else if (currentPhase == CombatPhase.active2) { currentPhase = CombatPhase.recovery2; animTimer = 0.4; } 
        else { currentPhase = CombatPhase.idle; }
      }
    }

    super._updatePhase(dt);
  }

  void _spawnGoblin() {
    var goblin = GoblinEnemy();
    
    goblin.isFrontRow = false; 
    
    goblin.strafePosition = strafePosition + (Random().nextBool() ? 0.3 : -0.3);
    goblin.strafePosition = goblin.strafePosition.clamp(-1.0, 1.0);

    gameRef.combatOverlay.enemies.add(goblin);
    parent?.add(goblin);
    
  }

  @override
  void render(Canvas canvas) {
    if (currentPhase == CombatPhase.windup) {
      Paint? auraPaint;
      
      if (isHeavyAttack && !isSummoning) {
        auraPaint = Paint()
          ..color = Palette.vermelho.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      } else if (isSummoning) {
        auraPaint = Paint()
          ..color = Palette.verde.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      }

      if (auraPaint != null) {
        canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x * 0.5, auraPaint);
      }
    }

    super.render(canvas); 
  }
}

class BugEnemy extends Enemy {
  bool isFleeing = false;
  BugEnemy() : super(name: 'bug',
    type: EnemyType.bug, 
    color: Palette.cinza,
    hp: 100, maxHp: 100, dropEssence: 30, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0, damage: 15,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 10,drop: [ItemDatabase.bugOrgan]
  ) {
    isMelee = true;
  }

  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery;

    if (player.stamina <= 0){
      attackCooldown = 0;
      isFleeing = false;
    }

    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer <= 0.3) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
        isFleeing = true;
      }

      if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
        isFleeing = false;
      }

      if (isFleeing) {
        double dir = -(player.strafePosition - strafePosition).sign;
        if (dir == 0) dir = 1.0; 
        strafePosition += dir * speed * dt;
      } else {
        if (distanceToPlayer > 0.01) {
          double dir = (player.strafePosition - strafePosition).sign;
          strafePosition += dir * speed * dt;
        }
      }

      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize);
  }
}

class WormEnemy extends Enemy {
  WormEnemy() : super(name: 'worm',
    type: EnemyType.worm, 
    color: Palette.cinza, damage: 10,
    hp: 50, maxHp: 50, dropEssence: 20, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 10, hitboxOffsetX: -20 ,drop: [ItemDatabase.bugOrgan],
    maxAttackCooldown: 0
  ) {
    isMelee = true;
  }

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    if (distanceToPlayer > 0.01) {
        double dir = (player.strafePosition - strafePosition).sign;
        strafePosition += dir * speed * dt;
    }

    strafePosition = strafePosition.clamp(-1.0, 1.0);
    
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize);
  }
}

class OvoEnemy extends Enemy {
  OvoEnemy() : super(name: 'ovo',
    type: EnemyType.ovo, 
    color: Palette.cinza,
    hp: 80, maxHp: 80, dropEssence: 10, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 10,drop: [ItemDatabase.bugOrgan],
    maxAttackCooldown: 5, isMelee: false, dieAnim: CombatPhase.recovery,
  );

  late bool _fixedRow;

  @override
  void update(double dt) {
    isFrontRow = _fixedRow; 
    super.update(dt);
  }

  @override
  void onMount() {
    super.onMount();
    _fixedRow = isFrontRow; 
  }

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
  }

   void _spawnworm() {
    var worm = WormEnemy();
    
    worm.isFrontRow = isFrontRow; 
    worm.priority = priority + 1;
    
    worm.strafePosition = strafePosition;
    worm.strafePosition = worm.strafePosition.clamp(-1.0, 1.0);

    gameRef.combatOverlay.enemies.add(worm);
    parent?.add(worm);
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    if (attackCooldown <= 0 ) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.5; 
      attackCooldown = 999;
    }
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) {
          currentPhase = CombatPhase.active;
          animTimer = 0.2; 
          _spawnworm();
        } else if (currentPhase == CombatPhase.active) {
          currentPhase = CombatPhase.recovery;
          animTimer = 0.1;
        } else if (currentPhase == CombatPhase.recovery) {
          hp = 0;
          isDying = true; 
          gameRef.encounterEssence += dropEssence; 
          gameRef.encounterDrop.addAll(drop);
          currentPhase = CombatPhase.idle; 
        }
      }
      return; 
    }
    
    super._updatePhase(dt); 
  }
}

class FungoEnemy extends Enemy {
  FungoEnemy() : super(
    name: 'fungo',
    type: EnemyType.fungo,
    color: Palette.roxo, damage: 10,
    hp: 60, maxHp: 60, dropEssence: 20, width: 144, height: 144, speed: 0.5,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: -10,
    hitboxWidth: 0, hitboxHeight: 0,
    drop: [],
    maxAttackCooldown: 4.0,isMelee: false,
    imunePoison: true,
  );

  double floatTimer = 0.0;
  bool isHealingAttack = false;
  double startDirection = Random().nextBool() ? 1.0 : -1.0;

  @override
  void update(double dt) {
    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;

    floatTimer += dt;

    flightOffset = -0.25 + (sin(floatTimer * speed) * 0.25);


    bool isAttacking = currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery;
    if (!isAttacking && !isDying && hitFlashTimer <= 0) {
      strafePosition += startDirection * cos(floatTimer * speed) * speed * dt;
      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }

    super.update(dt);
  }

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
    
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.8; 
      attackCooldown = maxAttackCooldown;
      
      isHealingAttack = Random().nextDouble() < 0.40;
    }
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) {
          currentPhase = CombatPhase.active;
          animTimer = 0.5; 
          
          if (isHealingAttack) {
            _castHealingCloud();
          } else {
            _spawnSpores();
          }
        } 
        else if (currentPhase == CombatPhase.active) {
          currentPhase = CombatPhase.recovery;
          animTimer = 0.5;
        } 
        else if (currentPhase == CombatPhase.recovery) {
          currentPhase = CombatPhase.idle;
        }
      }
      return; 
    }
    
    super._updatePhase(dt); 
  }

  void _castHealingCloud() {
    double currentY = yPosition + visualYOffset + flightOffset;
    
    gameRef.combatOverlay.add(HealingCloudEffect(strafePosition, currentY, gameRef));

    for (var enemy in gameRef.combatOverlay.enemies) {
      if (enemy.isAlive && enemy != this) {
        
        double distance = (enemy.strafePosition - strafePosition).abs();
        
        if (distance <= 0.4) {
          double healAmount = 25.0;
          enemy.hp += healAmount;
          if (enemy.hp > enemy.maxHp) enemy.hp = enemy.maxHp;
          
          gameRef.combatOverlay.addFloatingText(
            "+${healAmount.toInt()}", 
            enemy.getHurtbox(gameRef.size), 
            Palette.verde
          );
        }
      }
    }
  }

  void _spawnSpores() {
    double startY = yPosition + visualYOffset + flightOffset;

    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY - 0.1, -0.2, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY, -0.4, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY, 0.4, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY - 0.2, 0.0, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY - 0.1, 0.2, 0, this, grav:0.5, radius: 20));
  }
}

class Fungo2Enemy extends Enemy {
  Fungo2Enemy() : super(
    name: 'fungo',
    type: EnemyType.fungo2,
    color: Palette.roxo, damage: 10,
    hp: 60, maxHp: 60, dropEssence: 15, width: 144, height: 144, speed: 0.5,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: -10,
    hitboxWidth: 0, hitboxHeight: 0,
    drop: [],
    maxAttackCooldown: 4.0,isMelee: false,
    imunePoison: true,
  );

  double floatTimer = 0.0;
  double startDirection = Random().nextBool() ? 1.0 : -1.0;

  @override
  void update(double dt) {
    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;
    floatTimer += dt;

    flightOffset = -0.25 + (sin(floatTimer * speed) * 0.25);


    bool isAttacking = currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery;
    if (!isAttacking && !isDying && hitFlashTimer <= 0) {
      strafePosition += startDirection * cos(floatTimer * speed) * speed * dt;
      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }

    super.update(dt);
  }

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.8;
      attackCooldown = maxAttackCooldown;
    }
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) {
          currentPhase = CombatPhase.active;
          animTimer = 0.2; 
          _spawnSpores();
        } 
        else if (currentPhase == CombatPhase.active) {
          currentPhase = CombatPhase.recovery;
          animTimer = 0.1;
        } 
        else if (currentPhase == CombatPhase.recovery) {
          hp = 0;
          isDying = true; 
          gameRef.encounterEssence += dropEssence; 
          //gameRef.encounterDrop.addAll(drop);
          currentPhase = CombatPhase.idle; 
        }
      }
      return; 
    }
    
    super._updatePhase(dt); 
  }

  @override void onHitStun() {
    _spawnSpores();
    hp = 0;
    isDying = true; 
    currentPhase = CombatPhase.idle; 
  }


  void _spawnSpores() {
    double startY = yPosition + visualYOffset + flightOffset;

    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY - 0.1, -0.2, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY, -0.4, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY, 0.4, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY - 0.2, 0.0, 0, this, grav:0.5, radius: 20));
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY - 0.1, 0.2, 0, this, grav:0.5, radius: 20));
  }
}

class InfectadoEnemy extends Enemy {
  bool isFleeing = false;
  bool isPoisonAtk = false;

  InfectadoEnemy() : super(name: 'infectado',
    type: EnemyType.infectado,  damage: 12,
    color: Palette.cinza, 
    hp: 90, maxHp: 90, dropEssence: 40, width: 144, height: 144, speed: 0.55,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 20,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 10,drop: [ItemDatabase.braceleteFung],
    imunePoison: true,
  ) {
    isMelee = true;
  }
  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery ||
                           currentPhase == CombatPhase.windup2 || 
                           currentPhase == CombatPhase.active2 || 
                           currentPhase == CombatPhase.recovery2;

    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer <= 0.3) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
        isFleeing = true;
      }

      if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
        isFleeing = false;
      }

      if (isFleeing) {
        double dir = -(player.strafePosition - strafePosition).sign;
        if (dir == 0) dir = 1.0;
        strafePosition += dir * speed * dt;
      } else {
        if (distanceToPlayer > 0.01) {
          double dir = (player.strafePosition - strafePosition).sign;
          strafePosition += dir * speed * dt;
        }
      }

      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = 20;//(hitboxWidth / 2) + (player.hurtboxWidth / 2);

    bool isCloseY = true;

    if (currentPhase == CombatPhase.idle && isFrontRow) {
      if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0) {
        isPoisonAtk = !isPoisonAtk;
        isMelee = !isPoisonAtk;

        if (isPoisonAtk){
          currentPhase = CombatPhase.windup2;
        }else{
          currentPhase = CombatPhase.windup;
        }

        animTimer = 0.5; 
        attackCooldown = maxAttackCooldown;
        
      }
    }
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup2 || currentPhase == CombatPhase.active2 || currentPhase == CombatPhase.recovery2) {
      animTimer -= dt;
      
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup2) {
          currentPhase = CombatPhase.active2;
          animTimer = 0.5; 
          _shootPoisonCloud();
        } 
        else if (currentPhase == CombatPhase.active2) {
          currentPhase = CombatPhase.recovery2;
          animTimer = 0.5;
        } 
        else if (currentPhase == CombatPhase.recovery2) {
          currentPhase = CombatPhase.idle;
        }
      }
      return;
    }
    
    super._updatePhase(dt); 
  }

  Future<void> _shootPoisonCloud() async {
    double startY = yPosition + visualYOffset - 0.05;
    final ui.Image img = await game.images.load('effects/poison.png');
    gameRef.combatOverlay.add(PoisonCloud(strafePosition, startY, 0.0,0, this, img:img));
  }

}

class GarraRainhaEnemy extends Enemy {
  final Enemy rainha;
  final double strafeOffset; 
  GarraRainhaEnemy(this.rainha, this.strafeOffset) : super(
    name: 'garra',
    type: EnemyType.garra, 
    color: Palette.vermelho,  damage: 20,
    hp: 120, maxHp: 120, dropEssence: 0, width: 192, height: 192, speed: 0.0,
    hurtboxWidth: 50, hurtboxHeight: 170, hurtboxOffsetY: 0,
    hitboxWidth: 30, hitboxHeight: 80, hitboxOffsetY: 40, 
    drop: [], isMelee: true, 
    maxAttackCooldown: 3.5, 
  ) {
    isMelee = true;
    naoInterrompe = true;
  }

  @override
  bool get canChangeRow => false;

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    if (rainha.isAlive) {
      strafePosition = rainha.strafePosition + strafeOffset;
      isFrontRow = rainha.isFrontRow;
    }
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize);
  }
}

class RainhaInsetoEnemy extends Enemy {
  RainhaInsetoEnemy() : super(
    name: 'queen',
    type: EnemyType.boss2,
    color: Palette.roxo,
    hp: 300, maxHp: 300, dropEssence: 100, width: 192, height: 192, speed: 0.3,
    hurtboxWidth: 192, hurtboxHeight: 192, hurtboxOffsetY: 0,
    hitboxWidth: 0, hitboxHeight: 0, damage: 20,
    drop: [ItemDatabase.armaduraBug],
    maxAttackCooldown: 4.5,
    isBoss: true,
    isMelee: false,
  );

  bool isSummoningEgg = false;
  bool isPoisonCloud = false;

  double summonCooldown = 20;

  bool get _clawsDefeated {
    return !gameRef.combatOverlay.enemies.any((e) => e is GarraRainhaEnemy && e.isAlive);
  }

  bool get _garrasEstaoAtacando {
    return gameRef.combatOverlay.enemies.any((e) {
      if (e is GarraRainhaEnemy && e.isAlive) {
        return e.currentPhase == CombatPhase.windup || 
               e.currentPhase == CombatPhase.active || 
               e.currentPhase == CombatPhase.recovery;
      }
      return false;
    });
  }

  @override
  bool get canChangeRow => !_garrasEstaoAtacando;

  @override
  bool get isVulnerable => _clawsDefeated;

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    if (_clawsDefeated && !isFrontRow) {
      isFrontRow = true;
    }

    if(!_garrasEstaoAtacando){
      if (strafePosition < player.strafePosition - 0.1) {
        strafePosition += speed * dt;
      } else if (strafePosition > player.strafePosition + 0.1) {
        strafePosition -= speed * dt;
      }
      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }
    
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
    summonCooldown -= dt;

    if (summonCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup;
      animTimer = 1.0; 
      summonCooldown = 20;
      isSummoningEgg = true;
    }

    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup;
      animTimer = 1.0; 
      attackCooldown = maxAttackCooldown;
      
      isPoisonCloud = Random().nextDouble() < 0.9;
    }
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) {
          currentPhase = CombatPhase.active;
          animTimer = 0.5; 
          
          if (isSummoningEgg) {
            _spawnEgg();
          } else {
            if(isPoisonCloud){
              _shootPoisonCloud();
            }else{
              _shootPoison();
            }
            
          }
        } 
        else if (currentPhase == CombatPhase.active) {
          currentPhase = CombatPhase.recovery;
          animTimer = 0.8;
        } 
        else if (currentPhase == CombatPhase.recovery) {
          currentPhase = CombatPhase.idle;
        }
      }
      return; 
    }
    super._updatePhase(dt); 
  }

  void _spawnEgg() {
    var ovo = OvoEnemy();
    ovo.isFrontRow = false;
    
    ovo.strafePosition = strafePosition + (Random().nextBool() ? 0.4 : -0.4);
    ovo.strafePosition = ovo.strafePosition.clamp(-1.0, 1.0);

    gameRef.combatOverlay.enemies.add(ovo);
    parent?.add(ovo);
  }

  void _shootPoison() {
    double startY = yPosition + visualYOffset - 0.2;
    
    gameRef.combatOverlay.add(ArcProjectile(strafePosition, startY, 0.0, -0.5, this, isHoming: true));
  }
  Future<void> _shootPoisonCloud() async {
    double startY = yPosition + visualYOffset - 0.05;
    final ui.Image img = await game.images.load('effects/poison.png');
    gameRef.combatOverlay.add(PoisonCloud(strafePosition, startY, 0.0,0, this, img:img));
  }
}

class EsqueletoEnemy extends Enemy {
  bool isFleeing = false;
  EsqueletoEnemy() : super(name: 'esqueleto',
    type: EnemyType.esqueleto,  damage: 15,
    color: Palette.cinza, // Cor do escudo/armadura
    hp: 120, maxHp: 120, dropEssence: 30, width: 144, height: 144, speed: 0.62,
    hurtboxWidth: 80, hurtboxHeight: 140, hurtboxOffsetY: 0,
    hitboxWidth: 100, hitboxHeight: 100, hitboxOffsetY: 10,drop: [],
    imunePoison: true,
  ) {
    isMelee = true;
  }

  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery;

    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer<=0.3) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
        isFleeing = true;
      }

      if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
        isFleeing = false;
      }

      if (isFleeing) {
        double dir = -(player.strafePosition - strafePosition).sign;
        if (dir == 0) dir = 1.0;
        strafePosition += dir * speed * dt;
      } else {
        if (distanceToPlayer > 0.01) {
          double dir = (player.strafePosition - strafePosition).sign;
          strafePosition += dir * speed * dt;
        }
      }

      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize,dist:40);
  }
}

class JesterEnemy extends Enemy {
  double _hopTimer = 0.0;
  double _targetStrafe = 0.0;
  bool _isHopping = false;
  bool isSummoning = false;
  double summonCooldown = 10.0;

  JesterEnemy() : super(
    name: 'jester',
    type: EnemyType.jester,
    color: Palette.amarelo, 
    hp: 100, maxHp: 100, dropEssence: 20, 
    width: 144, height: 144, 
    hurtboxWidth: 70, hurtboxHeight: 140,
    hitboxWidth: 80, hitboxHeight: 80, 
    speed: 1.5, 
    maxAttackCooldown: 2.5, 
    drop: [ItemDatabase.bola],
    isMelee: false, 
    damage: 15,
  ) {
    _targetStrafe = strafePosition;
    _hopTimer = 0.0;
    maxJumpHeight = 0.25;
    maxJumpTime = 1.2;
  }

  @override
  bool get canChangeRow {
    bool isAttacking = currentPhase == CombatPhase.windup || 
                       currentPhase == CombatPhase.active || 
                       currentPhase == CombatPhase.recovery;
    return !isAttacking && !_isHopping;
  }

  @override
  bool get isVulnerable {
    return currentPhase == CombatPhase.windup || 
           currentPhase == CombatPhase.active || 
           currentPhase == CombatPhase.recovery;
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {

    attackCooldown -= dt;
    summonCooldown -= dt;

    if (summonCooldown <= 0) {
        isSummoning = true;
        currentPhase = CombatPhase.windup;
        animTimer = 0.5; 
        summonCooldown = 10.0 + Random().nextDouble() * 5.0; 
        return;
      }
    
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && !_isHopping) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.5; 
      attackCooldown = maxAttackCooldown;
    }
  }

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery;

    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer <= 0.3) {
      currentPhase = CombatPhase.guard;
      animTimer = 0.5; 
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      animTimer -= dt;
      if (animTimer <= 0) currentPhase = CombatPhase.idle;
    }

    if (currentPhase == CombatPhase.idle || currentPhase == CombatPhase.guard && !_isHopping) {
      _hopTimer -= dt;

      if (_hopTimer <= 0) {
        List<double> linhas = [-1.0, 0.0, 1.0];
        linhas.remove(strafePosition); 
        _targetStrafe = linhas[Random().nextInt(linhas.length)];

        _isHopping = true;
        jumpTimer = maxJumpTime; 
        _hopTimer = maxJumpTime + 0.2; 
      }
    }

    if (_isHopping) {
      if ((strafePosition - _targetStrafe).abs() > 0.05) {
        strafePosition += (_targetStrafe > strafePosition ? 1 : -1) * speed * dt;
      } else {
        strafePosition = _targetStrafe;
      }

      if (jumpTimer <= 0) {
        _isHopping = false;
        strafePosition = _targetStrafe; 
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;

    if (currentPhase == CombatPhase.active && !attackHit) {
      attackHit = true;

      if(isSummoning){
        isSummoning= false;
        _spawnDoll();

      }else{
        double startY = yPosition + visualYOffset;

        gameRef.combatOverlay.add(ArcProjectile(
          strafePosition, 
          startY, 
          0.0,
          -0.8,
          this,
          grav: 1,
          speedX: 6,
          isHoming: true
        ));
      }

    }
  }

  void _spawnDoll() {
    var doll = DollEnemy();
    
    doll.isFrontRow = isFrontRow; 
    
    doll.strafePosition = strafePosition + (Random().nextBool() ? 0.3 : -0.3);
    doll.strafePosition = doll.strafePosition.clamp(-1.0, 1.0);

    gameRef.combatOverlay.enemies.add(doll);
    parent?.add(doll);
    
  }
}

class NagaEnemy extends Enemy {
  bool isFleeing = false;

  NagaEnemy() : super(
    name: 'naga',isBoss: true,
    type: EnemyType.naga, 
    color: Palette.vermelhoEsc, 
    hp: 250, maxHp: 250, dropEssence: 40, 
    width: 144, height: 144, speed: 0.45, damage: 20,
    hurtboxWidth: 100, hurtboxHeight: 170, hurtboxOffsetY: 0,
    hitboxWidth: 90, hitboxHeight: 90, hitboxOffsetY: 10,drop: [ItemDatabase.braceleteNaga]
  ) {
    isMelee = true;
    damage = 5; 
  }

  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery ||
                           currentPhase == CombatPhase.windup2 || 
                           currentPhase == CombatPhase.active2 || 
                           currentPhase == CombatPhase.recovery2;

    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer<=0.3) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      

      if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
        isFleeing = true;
      }

      if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
        isFleeing = false;
      }

      if (isFleeing) {
        double dir = -(player.strafePosition - strafePosition).sign;
        if (dir == 0) dir = 1.0; 
        strafePosition += dir * speed * dt;
      } else {
        if (distanceToPlayer > 0.01) {
          double dir = (player.strafePosition - strafePosition).sign;
          strafePosition += dir * speed * dt;
        }
      }
      strafePosition = strafePosition.clamp(-1.0, 1.0);
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = 20;//(hitboxWidth / 2) + (player.hurtboxWidth / 2);

    bool isCloseY = true;

    if (currentPhase == CombatPhase.idle && isFrontRow) {
      
      if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0) {
        isHeavyAttack = !isHeavyAttack;

        naoInterrompe = isHeavyAttack;

        if(isHeavyAttack){
          currentPhase = CombatPhase.windup2;
        }else{
          currentPhase = CombatPhase.windup;
        }
        
        animTimer = isHeavyAttack ? 0.8 : 0.5; 
        attackCooldown = maxAttackCooldown;
        
        damage = isHeavyAttack ? 10 : 5; 
      }
    }
  }

  @override
  void _updatePhase(double dt) {

    if (currentPhase == CombatPhase.windup2 || currentPhase == CombatPhase.active2 || currentPhase == CombatPhase.recovery2) {
      animTimer -= dt;
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup2) { currentPhase = CombatPhase.active2; animTimer = 0.15; attackHit = false;AudioManager.playSfx('sfx/claw.wav'); }
        else if (currentPhase == CombatPhase.active2) { currentPhase = CombatPhase.recovery2; animTimer = 1.0; } 
        else { currentPhase = CombatPhase.idle; }
      }
    }

    super._updatePhase(dt);
  }

  @override
  void render(Canvas canvas) {
    if (currentPhase == CombatPhase.windup) {
      Paint? auraPaint;
      
      if (isHeavyAttack) {
        auraPaint = Paint()
          ..color = Palette.vermelho.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      }

      if (auraPaint != null) {
        canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x * 1.5, auraPaint);
      }
    }

    super.render(canvas); 
  }
}

class HandEnemy extends Enemy {
  double _teleportTimer = 0.0;
  int _nextAttackType = 1;

  HandEnemy() : super(
    name: 'mao',
    type: EnemyType.mao,
    color: Palette.cinzaEsc, 
    hp: 150, maxHp: 150, dropEssence: 40, 
    width: 144, height: 144, 
    hurtboxWidth: 80, hurtboxHeight: 130,
    hitboxWidth: 90, hitboxHeight: 90, 
    speed: 0.0,
    maxAttackCooldown: 3.0, 
    drop: [], damage: 15,
    isMelee: false, 
  ) {
    _teleportTimer = 2.0; 
  }

  @override
  bool get isVulnerable {
    return currentPhase == CombatPhase.windup || 
           currentPhase == CombatPhase.active || 
           currentPhase == CombatPhase.recovery ||
           currentPhase == CombatPhase.windup2 || 
           currentPhase == CombatPhase.active2 || 
           currentPhase == CombatPhase.recovery2;
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt; 
    
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      _nextAttackType = Random().nextBool() ? 1 : 2;
      
      if (_nextAttackType == 1) {
        currentPhase = CombatPhase.windup;
      } else {
        currentPhase = CombatPhase.windup2;
      }
      animTimer = 0.7;
      attackCooldown = maxAttackCooldown;
    }
  }

  @override
  void render(Canvas canvas) {
    if (currentPhase == CombatPhase.idle && _teleportTimer > 0 && _teleportTimer <= 0.4) {
      
      if ((_teleportTimer * 20).toInt() % 2 == 0) {
        return; 
      }
    }
    
    super.render(canvas);
  }

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    bool isSelfAttacking = currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery ||
                           currentPhase == CombatPhase.windup2 || currentPhase == CombatPhase.active2 || currentPhase == CombatPhase.recovery2;

    if (isPlayerAttacking && !isSelfAttacking && distanceToPlayer <= 0.3) {
      currentPhase = CombatPhase.guard;
      animTimer = 0.5; 
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      animTimer -= dt;
      if (animTimer <= 0) currentPhase = CombatPhase.idle;
    }

    if (currentPhase == CombatPhase.idle) {
      _teleportTimer -= dt;
      if (_teleportTimer <= 0) {
        List<double> linhas = [-1.0, 0.0, 1.0];
        linhas.remove(strafePosition); 
        strafePosition = linhas[Random().nextInt(linhas.length)];
        _teleportTimer = 1.5 + Random().nextDouble() * 2.0; 
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;

    if (currentPhase == CombatPhase.windup2 || currentPhase == CombatPhase.active2 || currentPhase == CombatPhase.recovery2) {
      animTimer -= dt;
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup2) { 
          currentPhase = CombatPhase.active2; 
          animTimer = 0.15; 
          attackHit = false; 
        }
        else if (currentPhase == CombatPhase.active2) { 
          currentPhase = CombatPhase.recovery2; 
          animTimer = 1.0; 
        } 
        else { 
          currentPhase = CombatPhase.idle; 
        }
      }
    }

    if (currentPhase == CombatPhase.active && !attackHit) {
      attackHit = true; 
      gameRef.combatOverlay.add(ArcProjectile(
        strafePosition, yPosition + visualYOffset, 0.0, -0.7, this, isHoming: true, grav: 1
      ));
    }

    if (currentPhase == CombatPhase.active2 && !attackHit) {
      attackHit = true; 

      gameRef.shakeScreen(0.2, 15.0);
      
      List<double> linhas = [-1.0,-0.5, 0.0, 0.5 ,1.0];
      linhas.shuffle();
      
      for (int i = 0; i < 3; i++) {
        gameRef.combatOverlay.add(ArcProjectile(
          linhas[i], -0.4, 0.0, 0.0, this, grav: 1 
        ));
      }
    }
  }
}

class DollEnemy extends Enemy {
  double currentDir = 1.0;
  
  final double flightHeight = 0.5; 
  final double attackHeight = 0.75;   
  double targetStrafe = 0;

  DollEnemy() : super(
    type: EnemyType.doll, name: 'doll',
    color: Palette.roxo,  damage: 15,
    hp: 70, maxHp: 70, dropEssence: 10, width: 144, height: 144, speed: 0.5,
    hurtboxWidth: 40, hurtboxHeight: 120, hurtboxOffsetX: 0, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetX: 0, hitboxOffsetY: 60,drop: []
  ) {
    isMelee = true;
    yPosition = flightHeight; 
    targetY = flightHeight;
  }


  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    if (currentPhase == CombatPhase.idle) {
      targetY = flightHeight;

      if ((yPosition - flightHeight).abs() < 0.05) {
        strafePosition += currentDir * speed * dt;
        
        if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
        if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
      }
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
   
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && (yPosition - flightHeight).abs() < 0.05 && isFrontRow) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.5;
      targetY = attackHeight; 
      attackCooldown = maxAttackCooldown;
      targetStrafe = gameRef.playerCombatStats.strafePosition;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (currentPhase == CombatPhase.windup) {
      priority = 15;
      targetY = attackHeight;

      double dx = targetStrafe - strafePosition;
      double dy = targetY - yPosition;
      
      double distance = sqrt(dx * dx + dy * dy);

      if (distance > 0.01) {
        double diveSpeed = speed*3;
        double moveStep = diveSpeed * dt;

        if (moveStep > distance) moveStep = distance;

        strafePosition += (dx / distance) * moveStep;
        yPosition += (dy / distance) * moveStep;
      }

    } else {
      if(isDying) return;
      if ((yPosition - targetY).abs() > 0.01) {
        double verticalSpeed = speed;
        yPosition += (targetY > yPosition ? 1 : -1) * verticalSpeed * dt;
      }

      if (currentPhase == CombatPhase.recovery || currentPhase == CombatPhase.active || currentPhase == CombatPhase.hit) {
        targetY = attackHeight;
      } else if (currentPhase == CombatPhase.idle) {
        targetY = flightHeight;
        priority = isFrontRow ? 10 : 0;
      }
    }
  }
}

class GoblinShopEnemy extends Enemy {
  double currentDir = 1.0;
  
  final double flightHeight = 0.5; 
  final double attackHeight = 0.75;   
  double targetStrafe = 0;

  GoblinShopEnemy() : super(
    type: EnemyType.goblinShop, name: 'vendedor',
    color: Palette.amarelo,  damage: 15,
    hp: 150, maxHp: 150, dropEssence: 50, width: 144, height: 144, speed: 0.5,
    hurtboxWidth: 60, hurtboxHeight: 90, hurtboxOffsetY: 0, maxAttackCooldown: 5,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 40, hitboxOffsetX: 10, drop: []
  ) {
    yPosition = flightHeight; 
    targetY = flightHeight;
  }

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    if (currentPhase == CombatPhase.idle) {
      targetY = flightHeight; 
      if ((yPosition - flightHeight).abs() < 0.05) {
        strafePosition += currentDir * speed * dt;
        
        if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
        if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
      }
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
   
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && (yPosition - flightHeight).abs() < 0.05 && isFrontRow) {

      if(Random().nextBool()){
        isMelee = true;
        currentPhase = CombatPhase.windup; 
        animTimer = 0.8;
        targetY = attackHeight;
        attackCooldown = maxAttackCooldown;
        targetStrafe = gameRef.playerCombatStats.strafePosition;
      }else{
        isMelee = false;
        currentPhase = CombatPhase.windup2; 
        animTimer = 0.5;
        attackCooldown = maxAttackCooldown;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt); 

    if (currentPhase == CombatPhase.windup) {
      priority = 15;
      targetY = attackHeight;

      double dx = targetStrafe - strafePosition;
      double dy = targetY - yPosition;
      
      double distance = sqrt(dx * dx + dy * dy);

      if (distance > 0.01) {
        double diveSpeed = speed * 3; 
        double moveStep = diveSpeed * dt;

        if (moveStep > distance) moveStep = distance;

        strafePosition += (dx / distance) * moveStep;
        yPosition += (dy / distance) * moveStep;
      }
    } 
    else {
      if (currentPhase == CombatPhase.windup2 || currentPhase == CombatPhase.active2 || currentPhase == CombatPhase.recovery2) {
        animTimer -= dt;
        
        if (animTimer <= 0) {
          if (currentPhase == CombatPhase.windup2) {
            currentPhase = CombatPhase.active2;
            animTimer = 0.5; 
            attackHit = false; 
          } 
          else if (currentPhase == CombatPhase.active2) {
            currentPhase = CombatPhase.recovery2;
            animTimer = 0.5;
          } 
          else if (currentPhase == CombatPhase.recovery2) {
            currentPhase = CombatPhase.idle;
          }
        }
      }

      if (currentPhase == CombatPhase.active2 && !attackHit) {
        attackHit = true; 
        
        if (Random().nextBool()) {
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition - 0.25, yPosition + visualYOffset, 0.0, -0.7, this, isHoming: true, grav: 1, imgPath: 'effects/coin.png'
          ));
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition, yPosition + visualYOffset, 0.0, -0.7, this, waitTmr: 0.5, isHoming: true, grav: 1, imgPath: 'effects/coin.png'
          ));
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition + 0.25, yPosition + visualYOffset, 0.0, -0.7, this, waitTmr: 1, isHoming: true, grav: 1, imgPath: 'effects/coin.png'
          ));
        } else {
          double startY = 0.63;
          List<double> posX = [0.4, 0, -0.4];
          posX.shuffle();
          _spawnLightningPillar(posX[0], startY); 
        }
      }
    }

    if (isDying) return;
    
    if ((yPosition - targetY).abs() > 0.01) {
      double verticalSpeed = speed; 
      yPosition += (targetY > yPosition ? 1 : -1) * verticalSpeed * dt;
    }

    if (currentPhase == CombatPhase.recovery || currentPhase == CombatPhase.active || currentPhase == CombatPhase.hit) {
      targetY = attackHeight; 
    } else if (currentPhase == CombatPhase.idle) {
      targetY = flightHeight;
      priority = isFrontRow ? 10 : 0;
    }
  }

  Future<void> _spawnLightningPillar(double startX, double startY) async {
    final ui.Image img = await game.images.load('effects/raio.png');
    gameRef.combatOverlay.add(FirePillar(startX, startY, 0.0, 0, this, img: img, tmr: 0.5));
  }
}

class MagoEnemy extends Enemy {
  double moveTimer = 0.0;
  double currentDir = 1.0;

  final double flightHeight = 0.5; 
  final double attackHeight = 0.7;  

  bool ataque2 = false;
  bool podeInvocar = false;
  bool isSummoning = false;
  double summonTmr = 5;

  MagoEnemy() : super(name: 'necro',
    type: EnemyType.boss3, color: Palette.roxo, hp: 300, maxHp: 300, dropEssence: 10, width: 192, height: 192, speed: 0.4,
    hurtboxWidth: 100, hurtboxHeight: 160, hurtboxOffsetY: 0, damage: 25,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30, isMelee: false, isBoss: true,maxAttackCooldown: 8,
    drop: []
  );

  bool get _temEsqueleto {
    return gameRef.combatOverlay.enemies.any((e) => e is EsqueletoEnemy && e.isAlive);
  }

  @override
  bool get canChangeRow {
    return !_temEsqueleto;
  }

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    moveTimer -= dt;
    if (moveTimer <= 0) {
      currentDir = (Random().nextInt(3) - 1).toDouble();
      moveTimer = 1.0 + Random().nextDouble() * 1.5;

      if(Random().nextBool()){
        targetY = flightHeight;
      }else{
        targetY = attackHeight;
      }


    }
    
    strafePosition += currentDir * speed * dt;
    if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
    if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    if(podeInvocar){
      summonTmr -= dt;
    }

    if(summonTmr <=0 && currentPhase == CombatPhase.idle && !_temEsqueleto){
      isFrontRow = false;
      isSummoning = true;
      currentPhase = CombatPhase.windup; 
      animTimer = 0.8; 
      summonTmr = 20;
    }
   
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.8; 
      attackCooldown = maxAttackCooldown;
      ataque2 = Random().nextBool();
    }
  }

  void _spawnEsqueleto() {
    var esq1 = EsqueletoEnemy();
    var esq2 = EsqueletoEnemy();

    esq1.isFrontRow = true; 
    esq2.isFrontRow = true; 
    
    esq1.strafePosition = 0.3;
    esq2.strafePosition = -0.3;

    gameRef.combatOverlay.enemies.add(esq1);
    gameRef.combatOverlay.enemies.add(esq2);
    parent?.add(esq1);
    parent?.add(esq2);
  }

  @override
  void update(double dt) {
    super.update(dt); 

    if(hp <= maxHp/2 && !podeInvocar) podeInvocar = true;

    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;

    if (currentPhase == CombatPhase.active && !attackHit) {
      attackHit = true;

      if(isSummoning){
        isSummoning = false;
        _spawnEsqueleto();
      }else{
        if(ataque2){
          _shootfirePillar();
        } else {
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition, yPosition + visualYOffset- 0.2, 0.0, -0.2, this, waitTmr: 0, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
          ));
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition, yPosition + visualYOffset - 0.2 , 0.0, -0.2, this, waitTmr: 0.5, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
          ));
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition, yPosition + visualYOffset - 0.2, 0.0, -0.2, this, waitTmr: 1, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
          ));
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition, yPosition + visualYOffset - 0.2, 0.0, -0.2, this, waitTmr: 1.5 ,isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
          ));
          gameRef.combatOverlay.add(ArcProjectile(
            strafePosition, yPosition + visualYOffset- 0.2, 0.0, -0.2, this, waitTmr: 2, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
          ));
        }
      }
    }
  }

  Future<void> _shootfirePillar() async {
    double startY = 0.63;
    double startX = 0.8;
    if(gameRef.playerCombatStats.strafePosition > 0) startX = -0.8;
    final ui.Image img = await game.images.load('effects/firePillar.png');
    gameRef.combatOverlay.add(FirePillar(startX, startY, 0.0,0, this, img:img));
  }
}

class AberraBrutoEnemy extends Enemy {
  bool isFleeing = false;
  
  AberraBrutoEnemy() : super(name: 'aberraBruto',
    type: EnemyType.aberraBruto, color: Palette.verde, hp: 120, maxHp: 120, dropEssence: 30, width: 144, height: 144
    , speed: 0.6, damage: 30,hurtboxWidth: 100, hurtboxHeight: 140, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 40, hitboxOffsetX: 10, maxAttackCooldown: 3.0,drop: []
  ){
    naoInterrompe = true;
    isHeavyAttack = true;
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize);
  }
  
  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();

    if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
      isFleeing = true;
    }
    if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
      isFleeing = false;
    }

    if (isFleeing) {
      double dir = -(player.strafePosition - strafePosition).sign;
      if (dir == 0) dir = 1.0; 
      strafePosition += dir * speed * dt;
    } else {
      if (distanceToPlayer > 0.01) {
        double dir = (player.strafePosition - strafePosition).sign;
        strafePosition += dir * speed * dt;
      }
    }

    strafePosition = strafePosition.clamp(-1.0, 1.0);
  }
}

class AberraVoaEnemy extends Enemy {
  double moveTimer = 0.0;
  double currentDir = 1.0;

  final double flightHeight = 0.5; 
  final double attackHeight = 0.7;  


  AberraVoaEnemy() : super(name: 'aberraVoa',
    type: EnemyType.aberraVoa, color: Palette.vermelhoEsc, hp: 80, maxHp: 80, dropEssence: 15, width: 144, height: 144, speed: 0.4,
    hurtboxWidth: 100, hurtboxHeight: 100, hurtboxOffsetY: 0, damage: 20,
    hitboxWidth: 0, hitboxHeight: 0, hitboxOffsetY: 0, isMelee: false,maxAttackCooldown: 4,
    drop: []
  );

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    moveTimer -= dt;
    if (moveTimer <= 0) {
      currentDir = (Random().nextInt(3) - 1).toDouble();
      moveTimer = 1.0 + Random().nextDouble() * 1.5;

      if(Random().nextBool()){
        targetY = flightHeight;
      }else{
        targetY = attackHeight;
      }
    }
    
    strafePosition += currentDir * speed * dt;
    if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
    if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.8; 
      attackCooldown = maxAttackCooldown;
    }
  }

  @override
  void update(double dt) {
    super.update(dt); 

    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;

    if (currentPhase == CombatPhase.active && !attackHit) {
      attackHit = true;
      gameRef.combatOverlay.add(ArcProjectile(
        strafePosition, yPosition + visualYOffset, 0.0, -0.2, this, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
      ));
    }
  }
}

class AberraBestaEnemy extends Enemy {
  bool isFleeing = false;
  AberraBestaEnemy() : super(name: 'aberraBesta',
    type: EnemyType.aberraBesta, color: Palette.verde, hp: 100, maxHp: 100, dropEssence: 20, width: 144, height: 144, speed: 0.6, damage: 30,
    hurtboxWidth: 100, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 40, hitboxOffsetX: 10, maxAttackCooldown: 1.0,drop: []
  );

  @override 
  void onHitStun() { 
    isFleeing = true; 
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize);
  }
  
  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();

    if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
      isFleeing = true;
    }

    if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
      isFleeing = false;
    }

    if (isFleeing) {
      double dir = -(player.strafePosition - strafePosition).sign;
      if (dir == 0) dir = 1.0;
      strafePosition += dir * speed * dt;
    } else {
      if (distanceToPlayer > 0.01) {
        double dir = (player.strafePosition - strafePosition).sign;
        strafePosition += dir * speed * dt;
      }
    }

    strafePosition = strafePosition.clamp(-1.0, 1.0);
  }
}

class AberraArvEnemy extends Enemy {
  
  AberraArvEnemy() : super(name: 'aberraArv',
    type: EnemyType.aberraArv, color: Palette.verde, hp: 120, maxHp: 120, dropEssence: 30, width: 192, height: 192
    , speed: 0, damage: 30,hurtboxWidth: 120, hurtboxHeight: 180, hurtboxOffsetY: 0,
    hitboxWidth: 80, hitboxHeight: 80, hitboxOffsetY: 50, hitboxOffsetX: -10, maxAttackCooldown: 2.0,drop: []
  ){
    naoInterrompe = true;
    isHeavyAttack = true;
    isFrontRow = true;
  }
  @override
  bool get canChangeRow => false;

  @override
  bool get isVulnerable => currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery;

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    checkAttackPadrao(dt,player,screenSize,windupTmr: 1);
  }
  
  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) { currentPhase = CombatPhase.active; animTimer = 0.15; attackHit = false; AudioManager.playSfx('sfx/claw.wav'); }
        else if (currentPhase == CombatPhase.active) { currentPhase = CombatPhase.recovery; animTimer = 1.5; } 
        else { currentPhase = CombatPhase.idle; }
      }
    }
  }
}

class AberraCultistaEnemy extends Enemy {
  bool isFleeing = false;
  bool isHealingAttack = false;
  AberraCultistaEnemy() : super(name: 'aberraCult',
    type: EnemyType.aberraCult, color: Palette.verde, hp: 100, maxHp: 100, dropEssence: 20, width: 144, height: 144, speed: 0.6, damage: 30,
    hurtboxWidth: 100, hurtboxHeight: 140, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 35, hitboxOffsetX: -20, maxAttackCooldown: 4.0,drop: []
  ){
    isFrontRow = false;
  }

  bool get _temInimigos {
    return gameRef.combatOverlay.enemies.any((e) => (e is !AberraCultistaEnemy && e is !AntigoEnemy && e is !TentaculoEnemy) && e.isAlive);
  }

  @override
  bool get canChangeRow => !_temInimigos;

  @override 
  void onHitStun() { 
    isFleeing = true; 
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = 20;//(hitboxWidth / 2) + (player.hurtboxWidth / 2);

    attackCooldown -= dt;
    //bool isCloseY = type == EnemyType.spider ? yPosition >= 0.4 : true;

    if (distancePixels <= reachPixels && attackCooldown <= 0 && currentPhase == CombatPhase.idle && isFrontRow) {
      isHealingAttack = Random().nextDouble() < 0.40;
      isMelee = !isHealingAttack;
      currentPhase = CombatPhase.windup;
      animTimer = 0.5; 
      attackCooldown = maxAttackCooldown;
    }
    
  }
  
  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();

    if (!isFleeing && distanceToPlayer < 0.4 && attackCooldown > 0) {
      isFleeing = true;
    }

    if (isFleeing && (strafePosition <= -0.98 || strafePosition >= 0.98)) {
      isFleeing = false;
    }

    if (isFleeing) {
      double dir = -(player.strafePosition - strafePosition).sign;
      if (dir == 0) dir = 1.0;
      strafePosition += dir * speed * dt;
    } else {
      
      if (distanceToPlayer > 0.01) {
        double dir = (player.strafePosition - strafePosition).sign;
        strafePosition += dir * speed * dt;
      }
    }

    strafePosition = strafePosition.clamp(-1.0, 1.0);
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) {
          currentPhase = CombatPhase.active;
          animTimer = 0.5; 
          
          if (isHealingAttack) {
            _castHealingCloud();
          }
        } 
        else if (currentPhase == CombatPhase.active) {
          currentPhase = CombatPhase.recovery;
          animTimer = 0.5;
        } 
        else if (currentPhase == CombatPhase.recovery) {
          currentPhase = CombatPhase.idle;
        }
      }
      return; 
    }
    
    super._updatePhase(dt); 
  }

   void _castHealingCloud() {
    double currentY = yPosition + visualYOffset + flightOffset;
    
    gameRef.combatOverlay.add(HealingCloudEffect(strafePosition, currentY, gameRef));

    for (var enemy in gameRef.combatOverlay.enemies) {
      if (enemy.isAlive && enemy != this) {
        
        double distance = (enemy.strafePosition - strafePosition).abs();
        
        if (distance <= 0.4) {
          double healAmount = 25.0;
          enemy.hp += healAmount;
          if (enemy.hp > enemy.maxHp) enemy.hp = enemy.maxHp;
          
          gameRef.combatOverlay.addFloatingText(
            "+${healAmount.toInt()}", 
            enemy.getHurtbox(gameRef.size), 
            Palette.verde
          );
        }
      }
    }
  }
}

class AberraOvoEnemy extends Enemy {
  AberraOvoEnemy() : super(name: 'aberraOvo',
    type: EnemyType.aberraOvo, 
    color: Palette.cinza,
    hp: 100, maxHp: 100, dropEssence: 15, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 0, hitboxHeight: 0, hitboxOffsetY: 0,drop: [],
    maxAttackCooldown: 8, isMelee: false
  ){
    isFrontRow = true;
  }
  @override
  bool get canChangeRow => false;

  late bool _fixedRow;

  @override
  void update(double dt) {
    isFrontRow = _fixedRow; 
    super.update(dt);
  }

  @override
  void onMount() {
    super.onMount();
    _fixedRow = isFrontRow; 
  }


  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    
  }

   void _spawnBesta() {
    var besta = AberraBestaEnemy();
    
    besta.isFrontRow = isFrontRow; 
    besta.priority = priority + 1;
    
    besta.strafePosition = strafePosition;
    besta.strafePosition = besta.strafePosition.clamp(-1.0, 1.0);

    gameRef.combatOverlay.enemies.add(besta);
    parent?.add(besta);
    
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    if (attackCooldown <= 0 ) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.5; 
      attackCooldown = 999;
    }
  }

  @override
  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) {
          currentPhase = CombatPhase.active;
          animTimer = 0.2; 
          _spawnBesta();
        } else if (currentPhase == CombatPhase.active) {
          currentPhase = CombatPhase.recovery;
          animTimer = 0.1;
        } else if (currentPhase == CombatPhase.recovery) {
          currentPhase = CombatPhase.idle; 
        }
      }
      return; 
    }
    
    super._updatePhase(dt); 
  }
}

class AntigoEnemy extends Enemy {
  double moveTimer = 0.0;
  double currentDir = 1.0;

  double flightHeight = 0.65; 
  double attackHeight = 0.5;  

  int tipoAtaque = 0;

  bool invocado = false;
  bool terminouRitual = false;

  AntigoEnemy() : super(name:'antigo',
    type: EnemyType.boss4, color: Palette.roxo, hp: 500, maxHp: 500, dropEssence: 10, width: 192, height: 192, speed: 0.4,
    hurtboxWidth: 140, hurtboxHeight: 140, hurtboxOffsetY: 0, damage: 25,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30, isMelee: false, isBoss: true,maxAttackCooldown: 6,
    drop: []
  ){
    ritualTmr = 30;
  }

  bool get _temCultistas {
    return gameRef.combatOverlay.enemies.any((e) => (e is AberraCultistaEnemy || e is AberraBrutoEnemy) && e.isAlive);
  }

  bool get _temTentaculos {
    return gameRef.combatOverlay.enemies.any((e) => e is TentaculoEnemy && e.isAlive);
  }

  @override
  bool get isVulnerable => invocado;

  @override
  bool get canChangeRow {
    return !_temTentaculos && invocado;
  }

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    if(ritualTmr>0){
      return;
    }
    moveTimer -= dt;
    if (moveTimer <= 0) {
      currentDir = (Random().nextInt(3) - 1).toDouble();
      moveTimer = 1.0 + Random().nextDouble() * 1.5;

      if(Random().nextBool()){
        targetY = flightHeight;
      }else{
        targetY = attackHeight;
      }
    }
    
    strafePosition += currentDir * speed * dt;
    if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
    if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.8; 
      attackCooldown = maxAttackCooldown;
      tipoAtaque = Random().nextInt(4);
    }
  }

  @override
  void update(double dt) {
    super.update(dt); 

    if(!_temTentaculos) attackHeight = 0.7;

    if (gameRef.currentState == GameState.paused || gameRef.currentState == GameState.settings) return;

    if(!_temCultistas){
      ritualTmr = 0;
      if(!invocado){
        invocado = true;
        _spawnTentaculo();
      }
    }

    if(ritualTmr>0){
      ritualTmr -= dt;
      return;
    }else{
      if(!invocado){
        invocado = true;
        terminouRitual = true;
        _spawnTentaculo();
      }
    }

    if (currentPhase == CombatPhase.active && !attackHit) {
      attackHit = true;
      
      if(tipoAtaque == 0){
        _shootfirePillar();
      } else if(tipoAtaque == 1){
        _shootPoisonCloud();
      }else if(tipoAtaque == 2){
        double startY = 0.63;
        List<double> posX = [0.4, 0, -0.4];
        posX.shuffle();
        _spawnLightningPillar(posX[0], startY);
      }
      else {
        gameRef.combatOverlay.add(ArcProjectile(
          strafePosition, yPosition + visualYOffset- 0.2, 0.0, -0.2, this, waitTmr: 0, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
        ));
        gameRef.combatOverlay.add(ArcProjectile(
          strafePosition, yPosition + visualYOffset - 0.2 , 0.0, -0.2, this, waitTmr: 0.5, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
        ));
        gameRef.combatOverlay.add(ArcProjectile(
          strafePosition, yPosition + visualYOffset - 0.2, 0.0, -0.2, this, waitTmr: 1, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
        ));
        gameRef.combatOverlay.add(ArcProjectile(
          strafePosition, yPosition + visualYOffset - 0.2, 0.0, -0.2, this, waitTmr: 1.5 ,isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
        ));
        gameRef.combatOverlay.add(ArcProjectile(
          strafePosition, yPosition + visualYOffset- 0.2, 0.0, -0.2, this, waitTmr: 2, isHoming: true, grav: 0.5, imgPath: 'effects/bola2.png',radius: 50
        ));
      }
    }
  }

  
  void _spawnTentaculo() {
    var tent1 = TentaculoEnemy()
      ..isFrontRow = true
      ..strafePosition = 0.4;
    gameRef.combatOverlay.enemies.add(tent1);
    parent?.add(tent1);

    if(terminouRitual){
      var tent2 = TentaculoEnemy()
          ..isFrontRow = true
          ..isFlipped = true
          ..strafePosition = -0.4;
      gameRef.combatOverlay.enemies.add(tent2);
      parent?.add(tent2);
    }
  }

  Future<void> _shootfirePillar() async {
    double startY = 0.63;
    double startX = 0.8;
    if(gameRef.playerCombatStats.strafePosition > 0) startX = -0.8;
    final ui.Image img = await game.images.load('effects/firePillar.png');
    gameRef.combatOverlay.add(FirePillar(startX, startY, 0.0,0, this, img:img));
  }

  Future<void> _shootPoisonCloud() async {
    double startY = yPosition + visualYOffset - 0.05;
    final ui.Image img = await game.images.load('effects/poison.png');
    gameRef.combatOverlay.add(PoisonCloud(strafePosition, startY, 0.0,0, this, img:img));
  }

  Future<void> _spawnLightningPillar(double startX, double startY) async {
    final ui.Image img = await game.images.load('effects/raio.png');
    gameRef.combatOverlay.add(FirePillar(startX, startY, 0.0, 0, this, img: img, tmr: 0.5));
  }
}

class TentaculoEnemy extends Enemy {
  double currentDir = 1.0;
  
  final double flightHeight = 0.5; 
  final double attackHeight = 0.75;   
  double targetStrafe = 0;

  TentaculoEnemy() : super(
    type: EnemyType.tentaculo, name: 'tentaculo',
    color: Palette.roxo,  damage: 15,
    hp: 200, maxHp: 200, dropEssence: 10, width: 192, height: 192, speed: 0.5,
    hurtboxWidth: 120, hurtboxHeight: 90, hurtboxOffsetX: 0, hurtboxOffsetY: 0, maxAttackCooldown: 3,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetX: 0, hitboxOffsetY: 60,drop: []
  ) {
    yPosition = flightHeight; 
    targetY = flightHeight;
    naoInterrompe = true;
  }

  @override
  bool get canChangeRow => false;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    if (currentPhase == CombatPhase.idle) {
      targetY = flightHeight; 

      if ((yPosition - flightHeight).abs() < 0.05) {
        strafePosition += currentDir * speed * dt;
        
        if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
        if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
      }
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
   
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && (yPosition - flightHeight).abs() < 0.05 && isFrontRow) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.5; 
      targetY = attackHeight; 
      attackCooldown = maxAttackCooldown * (0.8 + Random().nextDouble() * 0.4); 
      targetStrafe = gameRef.playerCombatStats.strafePosition;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (currentPhase == CombatPhase.windup) {
      priority = 15;
      targetY = attackHeight;

      double dx = targetStrafe - strafePosition;
      double dy = targetY - yPosition;
      double distance = sqrt(dx * dx + dy * dy);

      if (distance > 0.01) {
        double diveSpeed = speed*5; 
        double moveStep = diveSpeed * dt;

        if (moveStep > distance) moveStep = distance;

        strafePosition += (dx / distance) * moveStep;
        yPosition += (dy / distance) * moveStep;
      }

    } else {
      if(isDying) return;
      if ((yPosition - targetY).abs() > 0.01) {
        double verticalSpeed = speed; 
        yPosition += (targetY > yPosition ? 1 : -1) * verticalSpeed * dt;
      }

      if (currentPhase == CombatPhase.recovery || currentPhase == CombatPhase.active || currentPhase == CombatPhase.hit) {
        targetY = attackHeight; 
      } else if (currentPhase == CombatPhase.idle) {
        targetY = flightHeight; 
        priority = isFrontRow ? 10 : 0;
      }
    }
  }
}