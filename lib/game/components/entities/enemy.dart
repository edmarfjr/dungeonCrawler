import 'dart:math';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/arc_projectile.dart';
import 'package:dungeon_crawler/game/components/entities/combat_entities.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

enum EnemyType { slime, spider, goblin, mimic, orc, bat, boss1, bug, larva, ovo }

abstract class Enemy extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  final EnemyType type;
  final Color color;
  final double width, height, maxAttackCooldown;
  double hitFlashTimer = 0.0;
  Color flashColor = Palette.branco;
  double deathTimer = 1;

  final double hurtboxWidth, hurtboxHeight, hurtboxOffsetX, hurtboxOffsetY;
  final double hitboxWidth, hitboxHeight, hitboxOffsetX, hitboxOffsetY;

  double hp, maxHp, dropEssence, damage;
  double yPosition, targetY, speed, attackCooldown;
  double strafePosition = 0.0, animTimer = 0.0;
  bool isAlive = true, attackHit = false, isDying = false;
  CombatPhase currentPhase = CombatPhase.idle;
  bool get isVulnerable => true;
  bool isMelee;

  bool isFrontRow = true;
  bool get canChangeRow => true;
  double visualScale = 1.0; 
  double visualYOffset = 0.0;
  double visualDarkness = 0.0;

  double rowSwapTimer = 2.0;

  bool _lastRow = true;   
  double jumpTimer = 0.0;
  double maxJumpTime = 0.7;  
  double maxJumpHeight = 0.1;
  double jumpOffset = 0.0;

  bool isBoss;

  String name;
  
  bool isHeavyAttack = false;

  List<Item> drop ;

  Enemy({
    required this.name, required this.type, required this.color, required this.hp, required this.maxHp,
    required this.dropEssence, required this.width, required this.height,
    required this.hurtboxWidth, required this.hurtboxHeight, this.hurtboxOffsetX = 0.0, this.hurtboxOffsetY = 0.0,
    required this.hitboxWidth, required this.hitboxHeight, this.hitboxOffsetX = 0.0, this.hitboxOffsetY = 0.0,
    this.yPosition = 0.75, this.targetY = 0.75,
    this.speed = 0.4, this.maxAttackCooldown = 2.0, this.damage = 3,
    this.isMelee = true,
    this.isBoss = false,
    required this.drop,
  }) : attackCooldown = maxAttackCooldown, 
       super(anchor: Anchor.center
      ); // Anchor Center ajuda muito no Flame!

  void applyHitStun(double duration) {
    flashColor = Palette.vermelho;
    hitFlashTimer = duration;
    currentPhase = CombatPhase.hit;
    attackHit = false; 
    attackCooldown = maxAttackCooldown / 2; 
    onHitStun(); 
  }

  void applyHitGuard(double duration) {
    flashColor = Palette.cinzaMed;
    hitFlashTimer = duration;
  }

  void onHitStun() {}

  @override
  void update(double dt) {
    if(gameRef.currentState == GameState.paused)return;
    super.update(dt);
    priority = isFrontRow ? 10 : 0;

    if (!isAlive) return;
    if (gameRef.activeMessage != null) return;

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
    double cy = baseFloorY - distanceToFeet + (gameRef.size.y * jumpOffset); 
    
    position = Vector2(cx, cy);
    size = Vector2(width * visualScale, height * visualScale);
    // ----------------------------------------------------------------------

    if (isDying) {
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
      return; 
    }
    if (game.playerCombatStats.currentPhase == CombatPhase.entering || game.playerCombatStats.reflex) return;
    _updatePhase(dt);

    bool isAttacking = currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery;
    
    if (!isAttacking) {
      if ((yPosition - targetY).abs() > 0.01) yPosition += (targetY > yPosition ? 1 : -1) * 0.4 * dt; 
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

    if (currentPhase == CombatPhase.active && !attackHit && isMelee && isFrontRow) {
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
    double reachPixels = (hitboxWidth / 2) + (player.hurtboxWidth / 2);

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
        if (currentPhase == CombatPhase.windup) { currentPhase = CombatPhase.active; animTimer = 0.15; attackHit = false; FlameAudio.play('sfx/claw.wav'); }
        else if (currentPhase == CombatPhase.active) { currentPhase = CombatPhase.recovery; animTimer = 1.0; } 
        else { currentPhase = CombatPhase.idle; }
      }
    }
  }

  void renderShadow(Canvas canvas) {
    final shadowPaint = Paint()..color = Palette.preto..isAntiAlias = false;
      
    // 1. DIMENSÕES BASEADAS NA HURTBOX REAL (Já aplicando a escala visual)
    double actualHurtboxWidth = hurtboxWidth * visualScale;
    double actualHurtboxHeight = hurtboxHeight * visualScale;

    // A sombra agora se adapta ao corpo real do inimigo, não ao tamanho do componente (ex: 144x144)
    double shadowWidth = actualHurtboxWidth * 1;  
    double shadowHeight = shadowWidth * 0.4; 
    
    // 2. LOGICA DO CHÃO (Mantemos a sua estrutura original intacta)
    double groundYPos = (type == EnemyType.spider || type == EnemyType.bat) ? 0.75 : yPosition; 
    double floorGlobalY = gameRef.size.y * (groundYPos + visualYOffset);
    
    // 3. DISTÂNCIA DO CENTRO ATÉ O CHÃO
    double distanceToFloor = -(gameRef.size.y * jumpOffset);
    
    // 4. O PULO DO GATO: Encontrar a base dos "pés" dentro do espaço local do Canvas
    // Pegamos o centro local (size.y / 2), somamos o deslocamento Y e adicionamos metade da altura da hurtbox.
    double localHurtboxBottomY = (size.y / 2) + (hurtboxOffsetY * visualScale) + (actualHurtboxHeight / 2);
    
    // A posição final da sombra será na base dos pés, empurrada para baixo caso o inimigo suba (pule/voe)
    double shadowLocalY = localHurtboxBottomY + distanceToFloor;

    // Alinhamento horizontal: Centraliza a sombra exatamente abaixo do miolo do sprite (hurtbox)
    double shadowLocalX = (size.x / 2) + (hurtboxOffsetX * visualScale);

    // 5. ESCALA DE ALTITUDE (Garante que a sombra encolha se o inimigo se afastar do chão)
    double altitudeScale = 1.0;
    if (distanceToFloor > 0) {
        altitudeScale = (1.0 - (distanceToFloor / gameRef.size.y) * 2).clamp(0.2, 1.0);
    }

    // Desenha a elipse perfeitamente sincronizada com a posição do desenho real
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
      
      // Desenha a teia para cima a partir do centro do componente
      double screenTopLocalY = -(position.y - size.y / 2);
      double posX = size.x / 2 + 4;
      canvas.drawLine(Offset(posX, size.y / 2), Offset(posX, screenTopLocalY), webPaintBorder);
      canvas.drawLine(Offset(posX, size.y / 2), Offset(posX, screenTopLocalY), webPaint);
    }

    SpriteAnimationTicker activeTicker = gameRef.combatOverlay.getTickerForEnemy(this);
    final Color flashC =  Colors.white;// hitFlashTimer > 0 ? flashColor : Colors.white;
    int r = (flashC.red * (1.0 - visualDarkness)).toInt().clamp(0, 255);
    int g = (flashC.green * (1.0 - visualDarkness)).toInt().clamp(0, 255);
    int b = (flashC.blue * (1.0 - visualDarkness)).toInt().clamp(0, 255);
    Color finalColor = gameRef.playerCombatStats.currentPhase == CombatPhase.entering ? Palette.preto : Color.fromARGB(flashC.alpha, r, g, b);
    
    final tintPaint = Paint()..colorFilter = ColorFilter.mode(finalColor, BlendMode.modulate);
    activeTicker.getSprite().render(canvas, size: size, overridePaint: tintPaint);
    
  }

  Rect getHurtbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y * (yPosition + visualYOffset);
    return Rect.fromCenter(
      center: Offset(cx + hurtboxOffsetX * visualScale, cy + hurtboxOffsetY * visualScale), 
      width: hurtboxWidth * visualScale, height: hurtboxHeight * visualScale
    );
  }

  Rect getHitbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y * (yPosition + visualYOffset);
    return Rect.fromCenter(
      center: Offset(cx + hitboxOffsetX * visualScale, cy + hitboxOffsetY * visualScale), 
      width: hitboxWidth * visualScale, height: hitboxHeight * visualScale
    );
  }

  Rect getHitboxImageSize(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y * yPosition;
    return Rect.fromCenter(center: Offset(cx + hitboxOffsetX, cy + hitboxOffsetY), width: 120, height: 120);
  }
}

class SlimeEnemy extends Enemy {
  double moveTimer = 0.0;
  double currentDir = 1.0;

  SlimeEnemy() : super(name:'slime',
    type: EnemyType.slime, color: Palette.verdeCla, hp: 50, maxHp: 50, dropEssence: 10, width: 144, height: 144, speed: 0.4,
    hurtboxWidth: 110, hurtboxHeight: 70, hurtboxOffsetY: 0,
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
  GoblinEnemy() : super(name:'goblin',
    type: EnemyType.goblin, color: Palette.verde, hp: 60, maxHp: 60, dropEssence: 15, width: 144, height: 144, speed: 0.6, damage: 5,
    hurtboxWidth: 60, hurtboxHeight: 90, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 10, maxAttackCooldown: 1.0,drop: [ItemDatabase.faca]
  );

  @override 
  void onHitStun() { 
    isFleeing = true; 
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = (hitboxWidth / 2) + (player.hurtboxWidth / 2);

    attackCooldown -= dt;
    bool isCloseY = true;

    if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      if(isFrontRow){
        currentPhase = CombatPhase.windup;
        animTimer = 0.5; 
        attackCooldown = maxAttackCooldown;
      }else{
        isFleeing = true;
      }
    }
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
      if (distanceToPlayer > 0.02) {
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

  SpiderEnemy() : super(name:'aranha',
    type: EnemyType.spider, color: Palette.marromCla, hp: 30, maxHp: 30, dropEssence: 10, width: 144, height: 144, yPosition: 0.1, targetY: 0.1,
    hurtboxWidth: 60, hurtboxHeight: 70, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30, drop: [ItemDatabase.web]
  );

  @override
  bool get canChangeRow => (yPosition - targetY).abs() < 0.01 && yPosition < 0.4;

  @override void onHitStun() {
    isDropping = false; 
    hasAttacked = false; 
    targetY = 0.1; 
  }
  
  @override void updateBehavior(double dt, PlayerCombatStats player) {
    if(isFrontRow){
      // 1. GATILHO PARA DESCER
      if (!isDropping && yPosition <= 0.15 && (player.strafePosition - strafePosition).abs() < 0.2) {
        isDropping = true; 
        hasAttacked = false; 
        targetY = 0.75; 
      }
      
      // 2. GATILHO PARA SUBIR (SÓ DEPOIS QUE ATACAR)
      // Se a aranha desceu, já completou o ataque e voltou para o modo Idle, ela sobe para o teto.
      if (isDropping && hasAttacked && currentPhase == CombatPhase.idle) {
        isDropping = false; 
        targetY = 0.1; // Volta pro teto

      }
    }
    
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    // A Aranha ignora a distância X! Se ela estiver descendo, não atacou ainda, e tocou no chão, ela explode num ataque instantâneo!
    if (isDropping && !hasAttacked && yPosition >= 0.69 && currentPhase == CombatPhase.idle && isFrontRow) {
      currentPhase = CombatPhase.windup;
      animTimer = 1.0; 
      hasAttacked = true; // Marca que o bote foi dado
      attackCooldown = maxAttackCooldown; // Reseta o cooldown para o próximo mergulho
    }
  }
}

class MimicEnemy extends Enemy {
  double moveTimer = 0.0; 
  double currentDir = 1.0;
  bool _spawnedProjectiles = false;

  MimicEnemy() : super(name:'mimico',
    type: EnemyType.mimic, color: Palette.amarelo, hp: 60, maxHp: 60, dropEssence: 40, width: 144, height: 144, speed: 0.5, damage: 5,
    hurtboxWidth: 90, hurtboxHeight: 90, hurtboxOffsetY: 10,
    hitboxWidth: 0, hitboxHeight: 0, isMelee: false, drop: []
  );

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
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 10,drop: [ItemDatabase.clava]
  ) {
    isMelee = true;
  }

  // --- REGRA DE OURO: Só recebe dano se NÃO estiver a guarder ---
  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    // 1. Lê a "mente" do jogador: O jogador levantou a espada ou está a atacar?
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    // 2. Lê o próprio estado: Eu já comecei a atacar?
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery;

    // --- INTELIGÊNCIA DE DEFESA ---
    if (isPlayerAttacking && !isSelfAttacking) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    // --- MOVIMENTO NORMAL ---
    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      double distanceToPlayer = (player.strafePosition - strafePosition).abs();

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
        if (distanceToPlayer > 0.02) {
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
    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = (hitboxWidth / 2) + (player.hurtboxWidth / 2);

    attackCooldown -= dt;
    bool isCloseY = true;

    if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      if(isFrontRow){
        currentPhase = CombatPhase.windup;
        animTimer = 0.5; 
        attackCooldown = maxAttackCooldown;
      }else{
        isFleeing = true;
      }
    }
  }
}



class BatEnemy extends Enemy {
  double currentDir = 1.0;
  
  final double flightHeight = 0.15; 
  final double attackHeight = 0.65;   
  double targetStrafe = 0;

  BatEnemy() : super(
    type: EnemyType.bat, name: 'morcego',
    color: Palette.roxo, 
    hp: 40, maxHp: 40, dropEssence: 10, width: 144, height: 144, speed: 0.5,
    hurtboxWidth: 60, hurtboxHeight: 60, hurtboxOffsetX: 0, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetX: 0, hitboxOffsetY: 10,drop: [ItemDatabase.meat]
  ) {
    isMelee = true;
    yPosition = flightHeight; // Já nasce colado no teto
    targetY = flightHeight;
  }

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    // FASE DE PATRULHA
    if (currentPhase == CombatPhase.idle) {
      targetY = flightHeight; // Garante que a intenção é ficar no teto

      // Só flutua de um lado pro outro se já tiver chegado lá em cima
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
   
    // Decide atacar se o tempo estourou E se ele estiver fisicamente lá no alto
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && (yPosition - flightHeight).abs() < 0.05 && isFrontRow) {
      currentPhase = CombatPhase.windup; 
      animTimer = 1.0; // Tempo de preparo/mergulho
      targetY = attackHeight; // Comando para a classe pai: "Desça para o chão!"
      attackCooldown = maxAttackCooldown;
      targetStrafe = gameRef.playerCombatStats.strafePosition;
    }
  }

  @override
  void update(double dt) {
    super.update(dt); // A classe pai resolve a cor, timers e sprites

    if (currentPhase == CombatPhase.windup) {
      targetY = attackHeight;

      // 1. Descobre a diferença nos eixos X e Y
      double dx = targetStrafe - strafePosition;
      double dy = targetY - yPosition;
      
      // 2. Calcula a distância total em linha reta (Teorema de Pitágoras)
      double distance = sqrt(dx * dx + dy * dy);

      // 3. Move o morcego simultaneamente nos dois eixos se ainda não chegou ao alvo
      if (distance > 0.01) {
        double diveSpeed = speed*3; // Velocidade do mergulho (Aumente se quiser mais agressivo)
        double moveStep = diveSpeed * dt;

        // Trava de segurança para ele não "passar do ponto" e tremer
        if (moveStep > distance) moveStep = distance;

        // Distribui a velocidade perfeitamente na diagonal
        strafePosition += (dx / distance) * moveStep;
        yPosition += (dy / distance) * moveStep;
      }

    } else {
      // Se ele não está a mergulhar, usa a física normal de subida ou de ficar parado
      if ((yPosition - targetY).abs() > 0.01) {
        double verticalSpeed = speed; // Velocidade que ele volta para o teto
        yPosition += (targetY > yPosition ? 1 : -1) * verticalSpeed * dt;
      }

      // Controla a intenção de altura baseada na fase
      if (currentPhase == CombatPhase.recovery || currentPhase == CombatPhase.active || currentPhase == CombatPhase.hit) {
        targetY = attackHeight; // Mantém no chão para você poder bater nele
      } else if (currentPhase == CombatPhase.idle) {
        targetY = flightHeight; // O ataque acabou, manda subir de volta para o teto!
      }
    }
  }
}

class OrcChefe extends Enemy {
  bool isSummoning = false;
  double summonCooldown = 5.0;
  bool isFleeing = false;

  OrcChefe() : super(
    name: 'orc chefe',isBoss: true,
    type: EnemyType.boss1, 
    color: Palette.vermelhoEsc, 
    hp: 250, maxHp: 250, dropEssence: 100, 
    width: 192, height: 192, speed: 0.45,
    hurtboxWidth: 100, hurtboxHeight: 120, hurtboxOffsetY: 0,
    hitboxWidth: 90, hitboxHeight: 90, hitboxOffsetY: 10,drop: []
  ) {
    isMelee = true;
    damage = 5; // Dano base do ataque normal
  }

  // MÁGICA 1: Se ele estiver invocando, desligamos o melee para a hitbox não machucar o jogador!
  @override
  bool get isMelee => !isSummoning;

  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {

    if (isSummoning || currentPhase == CombatPhase.summon) {
      return; 
    }
    // 1. Lê a mente do jogador (Igual ao Orc comum)
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    // 2. Verifica se o próprio chefe está ocupado atacando ou invocando
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery;

    // --- INTELIGÊNCIA DE DEFESA (Igual ao Orc comum) ---
    if (isPlayerAttacking && !isSelfAttacking) {
      // O jogador tentou bater e o Chefe está livre: Levanta o Escudo!
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      // O jogador parou de bater: Abaixa o Escudo!
      currentPhase = CombatPhase.idle;
    }

    // --- MOVIMENTO NORMAL ---
    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      double distanceToPlayer = (player.strafePosition - strafePosition).abs();

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
        if (distanceToPlayer > 0.02) {
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
    attackCooldown -= dt;
    summonCooldown -= dt;

    if (currentPhase == CombatPhase.idle && isFrontRow) {
      
      // 1. PRIORIDADE: Invocar o lacaio
      if (summonCooldown <= 0) {
        isSummoning = true;
        currentPhase = CombatPhase.summon;
        animTimer = 1.5; // Fica 1.5s tocando o berrante / fazendo a pose
        summonCooldown = 15.0 + Random().nextDouble() * 5.0; // Próximo goblin só daqui a ~17s
        return;
      }

      // 2. ALTERNÂNCIA DE ATAQUES
      if (attackCooldown <= 0) {
        isSummoning = false;
        isHeavyAttack = !isHeavyAttack; // Alterna entre normal e pesado!

        currentPhase = CombatPhase.windup;
        
        // O ataque pesado tem um aviso (windup) BEM MAIOR para dar tempo de o jogador esquivar
        animTimer = isHeavyAttack ? 1.2 : 0.6; 
        attackCooldown = maxAttackCooldown;
        
        // O dano sobe violentamente no ataque pesado
        damage = isHeavyAttack ? 10 : 5; 
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
        // Aura vermelha do mal (Ataque Indefensável)
        auraPaint = Paint()
          ..color = Palette.vermelho.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      } else if (isSummoning) {
        // Aura verde brilhante (Invocação)
        auraPaint = Paint()
          ..color = Palette.verde.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      }

      if (auraPaint != null) {
        canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x * 0.5, auraPaint);
      }
    }

    super.render(canvas); // Desenha a sombra e o sprite normalmente
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

class BugEnemy extends Enemy {
  bool isFleeing = false;
  BugEnemy() : super(name: 'bug',
    type: EnemyType.bug, 
    color: Palette.cinza,
    hp: 80, maxHp: 80, dropEssence: 20, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 10,drop: []
  ) {
    isMelee = true;
  }

  @override
  bool get isVulnerable => currentPhase != CombatPhase.guard;

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    // 1. Lê a "mente" do jogador: O jogador levantou a espada ou está a atacar?
    bool isPlayerAttacking = player.currentPhase == CombatPhase.windup || player.currentPhase == CombatPhase.active;
    
    // 2. Lê o próprio estado: Eu já comecei a atacar?
    bool isSelfAttacking = currentPhase == CombatPhase.windup || 
                           currentPhase == CombatPhase.active || 
                           currentPhase == CombatPhase.recovery;

    // 3. Le se o player está sem stamina
    if (player.stamina <= 0){
      attackCooldown = 0;
      isFleeing = false;
    }

    // --- INTELIGÊNCIA DE DEFESA ---
    if (isPlayerAttacking && !isSelfAttacking) {
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      currentPhase = CombatPhase.idle;
    }

    // --- MOVIMENTO NORMAL ---
    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      double distanceToPlayer = (player.strafePosition - strafePosition).abs();

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
        if (distanceToPlayer > 0.02) {
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
    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = (hitboxWidth / 2) + (player.hurtboxWidth / 2);

    attackCooldown -= dt;
    bool isCloseY = true;

    if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      if(isFrontRow){
        currentPhase = CombatPhase.windup;
        animTimer = 0.5; 
        attackCooldown = maxAttackCooldown;
      }else{
        isFleeing = true;
      }
    }
  }
}

class LarvaEnemy extends Enemy {
  bool isFleeing = false;
  LarvaEnemy() : super(name: 'larva',
    type: EnemyType.larva, 
    color: Palette.cinza,
    hp: 80, maxHp: 80, dropEssence: 20, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 10,drop: [],
    maxAttackCooldown: 0
  ) {
    isMelee = true;
  }

  @override 
  void updateBehavior(double dt, PlayerCombatStats player) {
    double distanceToPlayer = (player.strafePosition - strafePosition).abs();
    if (distanceToPlayer > 0.02) {
        double dir = (player.strafePosition - strafePosition).sign;
        strafePosition += dir * speed * dt;
    }

      // Garante que não vai sair da tela
    strafePosition = strafePosition.clamp(-1.0, 1.0);
    
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && isFrontRow) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.8; 
      attackCooldown = maxAttackCooldown;
    }
  }
}