import 'dart:math';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/arc_projectile.dart';
import 'package:dungeon_crawler/game/components/entities/combat_entities.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

enum EnemyType { slime, spider, goblin, mimic, orc, bat }

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

  String name;


  Enemy({
    required this.name, required this.type, required this.color, required this.hp, required this.maxHp,
    required this.dropEssence, required this.width, required this.height,
    required this.hurtboxWidth, required this.hurtboxHeight, this.hurtboxOffsetX = 0.0, this.hurtboxOffsetY = 0.0,
    required this.hitboxWidth, required this.hitboxHeight, this.hitboxOffsetX = 0.0, this.hitboxOffsetY = 0.0,
    this.yPosition = 0.7, this.targetY = 0.7,
    this.speed = 0.4, this.maxAttackCooldown = 2.0, this.damage = 3,
    this.isMelee = true,
  }) : attackCooldown = maxAttackCooldown, super(anchor: Anchor.center); // Anchor Center ajuda muito no Flame!

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

    // --- Animação suave entre a linha de frente e de trás ---
    if (isFrontRow != _lastRow) {
      _lastRow = isFrontRow;
      jumpTimer = maxJumpTime; // A duração do salto será de 400 milissegundos
    }

    // 2. Calcula a altura do salto usando um arco de Seno (Sobe e Desce)
    double jumpOffset = 0.0;
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
    double targetDarkness = (game.playerCombatStats.currentPhase == CombatPhase.entering) ? 1 :isFrontRow  ? 0.0 : 0.6; 

    double transitionSpeed = 4.6 / maxJumpTime;

    visualScale += (targetScale - visualScale) * transitionSpeed * dt;
    visualYOffset += (targetYOffset - visualYOffset) * transitionSpeed * dt;
    visualDarkness += (targetDarkness - visualDarkness) * transitionSpeed * dt;

    // 4. Aplica a posição visual final somando o Pulo (jumpOffset)
    double scale = gameRef.size.x * 0.35;
    double cx = (gameRef.size.x / 2) + (strafePosition * scale);
    double cy = gameRef.size.y * (yPosition + visualYOffset + jumpOffset); 
    
    position = Vector2(cx, cy);
    size = Vector2(width * visualScale, height * visualScale);
    // ----------------------------------------------------------------------

    if (isDying) {
      deathTimer -= dt;
      if (deathTimer <= 0) {
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
    if (game.playerCombatStats.currentPhase == CombatPhase.entering) return;
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

  @override
  void render(Canvas canvas) {
    if (isDying && (deathTimer * 15).toInt() % 2 == 0) return;

    if (hitFlashTimer>0 && (hitFlashTimer * 15).toInt() % 2 == 0) return;
    
  // sombra
    final shadowPaint = Paint()..color = Palette.preto..isAntiAlias = false;
      
      // A sombra tem 60% da largura do inimigo e é achatada (15% da altura)
    double shadowWidth = size.x * 0.6;
    double shadowHeight = size.y * 0.15;
    
    // 1. Descobrimos onde é o chão 
    // (Como a Aranha paira no ar, fixamos o chão virtual dela no 0.65 da tela)
    double groundYPos = (type == EnemyType.spider || type == EnemyType.bat) ? 0.65 : yPosition; 
    double floorGlobalY = gameRef.size.y * (groundYPos + visualYOffset);
    
    // 2. Calculamos a distância entre o inimigo (flutuando ou saltando) e o chão
    double distanceToFloor = floorGlobalY - position.y;
    
    // 3. Empurramos a sombra para o chão verdadeiro!
    double shadowLocalY = size.y - (shadowHeight / 2) + distanceToFloor;

    // 4. Detalhe visual: Se a aranha estiver muito alta, a sombra fica mais pequena!
    double altitudeScale = 1.0;
    if (type == EnemyType.spider) {
        altitudeScale = (1.0 - (distanceToFloor / gameRef.size.y) * 2).clamp(0.3, 1.0);
    }

    // Desenha a elipse (sombra) devidamente projetada
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, shadowLocalY), 
        width: shadowWidth * altitudeScale, 
        height: shadowHeight * altitudeScale
      ),
      shadowPaint,
    );

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
    Color finalColor = game.playerCombatStats.currentPhase == CombatPhase.entering? Palette.preto : Color.fromARGB(flashC.alpha, r, g, b);
    
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

// --- SUBCLASSES COM CAIXAS TOTALMENTE PERSONALIZADAS ---

class SlimeEnemy extends Enemy {
  double moveTimer = 0.0;
  double currentDir = 1.0;

  SlimeEnemy() : super(name:'slime',
    type: EnemyType.slime, color: Palette.verdeCla, hp: 50, maxHp: 30, dropEssence: 20, width: 144, height: 144, speed: 0.4,
    hurtboxWidth: 80, hurtboxHeight: 70, hurtboxOffsetY: 0, // Hurtbox achatada no chão
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30,  // O ataque dele se expande do corpo
  );

  @override
  void updateBehavior(double dt, PlayerCombatStats player) {
    moveTimer -= dt;
    if (moveTimer <= 0) {
      // 1. Escolhe uma nova direção horizontal (Esquerda, Direita ou Parado)
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
    type: EnemyType.goblin, color: Palette.verde, hp: 60, maxHp: 50, dropEssence: 30, width: 144, height: 144, speed: 0.6, damage: 5,
    hurtboxWidth: 60, hurtboxHeight: 90, hurtboxOffsetY: 10,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 50, maxAttackCooldown: 1.0 
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
    type: EnemyType.spider, color: Palette.marromCla, hp: 30, maxHp: 20, dropEssence: 15, width: 144, height: 144, yPosition: 0.1, targetY: 0.1,
    hurtboxWidth: 60, hurtboxHeight: 70, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30, 
  );

  @override
  bool get canChangeRow => (yPosition - targetY).abs() < 0.01 && yPosition < 0.4;

  @override void onHitStun() {
    isDropping = false; 
    hasAttacked = false; 
    targetY = 0.1; // Se tomar porrada, desiste do ataque e foge pro teto!
  }
  
  @override void updateBehavior(double dt, PlayerCombatStats player) {
    if(isFrontRow){
      // 1. GATILHO PARA DESCER
      if (!isDropping && yPosition <= 0.15 && (player.strafePosition - strafePosition).abs() < 0.2) {
        isDropping = true; 
        hasAttacked = false; // Prepara o bote
        targetY = 0.7; // Vai p
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
    type: EnemyType.mimic, color: Palette.amarelo, hp: 60, maxHp: 60, dropEssence: 60, width: 144, height: 144, speed: 0.5, damage: 5,
    hurtboxWidth: 90, hurtboxHeight: 90, hurtboxOffsetY: 10,
    hitboxWidth: 0, hitboxHeight: 0, isMelee: false, 
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
  OrcEnemy() : super(name: 'orc',
    type: EnemyType.orc, 
    color: Palette.cinza, // Cor do escudo/armadura
    hp: 80, maxHp: 80, dropEssence: 20, width: 144, height: 144, speed: 0.6,
    hurtboxWidth: 80, hurtboxHeight: 100, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetY: 60,
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
      // O jogador tentou bater e o Goblin não estava ocupado: DEFESA IMEDIATA!
      currentPhase = CombatPhase.guard;
    } else if (currentPhase == CombatPhase.guard && !isPlayerAttacking) {
      // O jogador parou de atacar, o Goblin baixa o escudo
      currentPhase = CombatPhase.idle;
    }

    // --- MOVIMENTO NORMAL (Só anda se não estiver a guarder) ---
    if (currentPhase != CombatPhase.guard && !isSelfAttacking) {
      double targetStrafe = player.strafePosition;
      if ((strafePosition - targetStrafe).abs() > 0.05) {
        strafePosition += (targetStrafe > strafePosition ? 1 : -1) * speed * dt;
        currentPhase = CombatPhase.walk;
      } else {
        currentPhase = CombatPhase.idle;
      }
    }
  }

  @override 
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;
    // Só toma a decisão de atacar se a guarda estiver baixa (idle)
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle && isFrontRow) {
      currentPhase = CombatPhase.windup; 
      animTimer = 0.8; 
      attackCooldown = maxAttackCooldown;
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
    hp: 40, maxHp: 40, dropEssence: 10, width: 120, height: 120, speed: 0.5,
    hurtboxWidth: 60, hurtboxHeight: 60, hurtboxOffsetX: 0, hurtboxOffsetY: 0,
    hitboxWidth: 60, hitboxHeight: 60, hitboxOffsetX: 0, hitboxOffsetY: 10,
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