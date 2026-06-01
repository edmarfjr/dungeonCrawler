import 'dart:math';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/arc_projectile.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum CombatPhase { idle, walk, guard, windup, active, recovery, entering, exiting, hit }

class PlayerCombatStats {
  double hp = 100, maxHp = 100, mana = 50, maxMana = 50, essence = 0;
  double stamina = 100.0, maxStamina = 100.0; 
  double staminaTmr = 0.0; 
  double staminaRegenDelay = 1.0;
  double strafePosition = 0.0; 
  bool isGuarding = false, attackHit = false;
  int comboCount = 0;
  double comboTimer = 0.0, animTimer = 0.0;
  CombatPhase currentPhase = CombatPhase.idle;

  // --- DIMENSÕES E OFFSETS DO PLAYER ---
  // Tamanho do corpo vulnerável do jogador
  double hurtboxWidth = 60.0;
  double hurtboxHeight = 120.0;
  double hurtboxOffsetY = 0.0; 

  // Tamanho do golpe da arma do jogador
  double hitboxWidth = 70.0;
  double hitboxHeight = 120.0;
  // Offset Y negativo sobe a caixa (útil para acertar aranhas e voadores)
  double hitboxOffsetY = -80.0; 
  double hitboxOffsetX = 0.0;

  double hitFlashTimer = 0.0;

  //variaveis da arma
  double windupTime = 0.1;
  double activeTime = 0.1;
  double recoveryTime = 0.1;
  double staminaCost = 20.0;
  double damage = 10;
  Color weaponColor = Palette.cinza;

  //variaveis da armadura
  Color armorColor = Palette.bege;

  List<Item> inventory = [];
  Item? equippedWeapon;
  Item? equippedArmor;

  List<Item> get consumables => inventory.where((i) => i.type == ItemType.consumable).toList();

  void recoverStamina(double dt) {
    if(staminaTmr > 0) {
      staminaTmr -= dt;
      return; // Ainda no delay, não regenera
    }
    if (!isGuarding && stamina < maxStamina) {
      stamina += 40.0 * dt; 
      if (stamina > maxStamina) stamina = maxStamina;
    }
  }

  void applyHitStun(double duration) {
    hitFlashTimer = duration;
    currentPhase = CombatPhase.hit; // Interrompe qualquer ação atual
    comboCount = 0; // Quebra o combo
    attackHit = false; // Cancela ataques ativos
  }

  void updatePhase(double dt) {
    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
      if (hitFlashTimer <= 0 && currentPhase == CombatPhase.hit) {
        currentPhase = CombatPhase.idle; // Acordou da paralisia
      }
      return; // Impede que o resto da lógica continue rodando
    }
    if (comboCount > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        comboCount = 0; // O tempo acabou! Reseta o combo para o primeiro golpe.
      }
    }
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery || currentPhase == CombatPhase.entering || currentPhase == CombatPhase.exiting) {
      animTimer -= dt;
      if (animTimer <= 0) {
        switch (currentPhase) {
          case CombatPhase.windup: currentPhase = CombatPhase.active; animTimer = windupTime; break;
          case CombatPhase.active: currentPhase = CombatPhase.recovery; animTimer = recoveryTime; break;
          case CombatPhase.recovery: currentPhase = CombatPhase.idle; attackHit = false; break;
          case CombatPhase.entering: currentPhase = CombatPhase.idle; break;
          case CombatPhase.exiting: break; 
          default: currentPhase = CombatPhase.idle; break;
        }
      }
    }
  }

  Rect getHurtbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y - 70 - 55; // Posição Y base do jogador
    return Rect.fromCenter(center: Offset(cx, cy + hurtboxOffsetY), width: hurtboxWidth, height: hurtboxHeight);
  }

  Rect getHitbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y - 70 - 55;
    return Rect.fromCenter(center: Offset(cx + hitboxOffsetX, cy + hitboxOffsetY), width: hitboxWidth, height: hitboxHeight);
  }

  Rect getHitboxImageSize(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y - 70 - 55;
    return Rect.fromCenter(center: Offset(cx + hitboxOffsetX, cy + hitboxOffsetY), width: 120, height: 120);
  }

}

enum EnemyType { slime, spider, goblin, mimic }

abstract class Enemy {
  final EnemyType type;
  final Color color;
  final double width, height, maxAttackCooldown;
  double hitFlashTimer = 0.0;
  Color flashColor = Palette.branco;
  double deathTimer = 0.6;

  // --- DIMENSÕES E OFFSETS DOS INIMIGOS ---
  final double hurtboxWidth, hurtboxHeight, hurtboxOffsetX, hurtboxOffsetY;
  final double hitboxWidth, hitboxHeight, hitboxOffsetX, hitboxOffsetY;

  double hp, maxHp, dropEssence, damage;
  double yPosition, targetY, speed, attackCooldown;
  double strafePosition = 0.0, animTimer = 0.0;
  bool isAlive = true, attackHit = false, isDying = false;
  CombatPhase currentPhase = CombatPhase.idle;
  bool get isVulnerable => true;

  List<ArcProjectile> projectiles = [];

  Enemy({
    required this.type, required this.color, required this.hp, required this.maxHp,
    required this.dropEssence, required this.width, required this.height,
    required this.hurtboxWidth, required this.hurtboxHeight, this.hurtboxOffsetX = 0.0, this.hurtboxOffsetY = 0.0,
    required this.hitboxWidth, required this.hitboxHeight, this.hitboxOffsetX = 0.0, this.hitboxOffsetY = 0.0,
    this.yPosition = 0.7, this.targetY = 0.7,
    this.speed = 0.4, this.maxAttackCooldown = 2.0, this.damage = 10,
  }) : attackCooldown = maxAttackCooldown;

  void applyHitStun(double duration) {
    flashColor = Palette.vermelho;
    hitFlashTimer = duration;
    currentPhase = CombatPhase.hit;
    attackHit = false; 
    attackCooldown = maxAttackCooldown/2; 
    onHitStun(); // Permite que a Aranha reaja a isso
  }

  void applyHitGuard(double duration) {
    flashColor = Palette.cinzaMed;
    hitFlashTimer = duration;
  }

  void onHitStun() {}

  void update(double dt, PlayerCombatStats player, Vector2 screenSize) {
    if (!isAlive) return;

    for (var p in projectiles) {
      p.update(dt); 
    }
    projectiles.removeWhere((p) => !p.isActive);

    if (isDying) {
      deathTimer -= dt;
      if (deathTimer <= 0) {
        isAlive = false; // Só morre de verdade quando o timer acaba
      }
      return; // Impede que ele ande ou ataque enquanto morre
    }

    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
      if (hitFlashTimer <= 0 && currentPhase == CombatPhase.hit) {
        currentPhase = CombatPhase.idle;
      }
      return; // Inimigo paralisado! Não anda, não cai, não calcula IA.
    }

    _updatePhase(dt);

    // 1. TRAVA DE ATAQUE CORRIGIDA: Agora bloqueia as 3 fases do golpe!
    bool isAttacking = currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery;
    
    // Se está no meio de um ataque, NÃO pode se mover verticalmente nem horizontalmente
    if (!isAttacking) {
      if ((yPosition - targetY).abs() > 0.01) {
        yPosition += (targetY > yPosition ? 1 : -1) * 0.4 * dt; 
      }

      updateBehavior(dt, player);
      checkAttackDecision(dt, player, screenSize); // Transformada em pública para a Aranha modificar
    }
  }

  void updateBehavior(double dt, PlayerCombatStats player);

  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    // Calcula o alcance do ataque em PIXELS exatos na tela
    double scale = screenSize.x * 0.35;
    double distancePixels = (player.strafePosition - strafePosition).abs() * scale;
    double reachPixels = (hitboxWidth / 2) + (player.hurtboxWidth / 2);

    attackCooldown -= dt;
    
    bool isCloseY = type == EnemyType.spider ? yPosition >= 0.4 : true;

    if (distancePixels <= reachPixels && isCloseY && attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup;
      animTimer = 0.5; 
      attackCooldown = maxAttackCooldown;
    }
  }

  void _updatePhase(double dt) {
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery) {
      animTimer -= dt;
      if (animTimer <= 0) {
        if (currentPhase == CombatPhase.windup) { currentPhase = CombatPhase.active; animTimer = 0.15; attackHit = false; }
        else if (currentPhase == CombatPhase.active) { currentPhase = CombatPhase.recovery; animTimer = 1.0; } 
        else { currentPhase = CombatPhase.idle; }
      }
    }
  }

  Rect getHurtbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y * yPosition;
    return Rect.fromCenter(center: Offset(cx + hurtboxOffsetX, cy + hurtboxOffsetY), width: hurtboxWidth, height: hurtboxHeight);
  }

  Rect getHitbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y * yPosition;
    return Rect.fromCenter(center: Offset(cx + hitboxOffsetX, cy + hitboxOffsetY), width: hitboxWidth, height: hitboxHeight);
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

  SlimeEnemy() : super(
    type: EnemyType.slime, color: Palette.verdeCla, hp: 30, maxHp: 30, dropEssence: 10, width: 144, height: 144, speed: 0.4,
    hurtboxWidth: 80, hurtboxHeight: 70, hurtboxOffsetY: 0, // Hurtbox achatada no chão
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30,  // O ataque dele se expande do corpo
  );

  @override void updateBehavior(double dt, PlayerCombatStats player) {
    moveTimer -= dt;
    if (moveTimer <= 0) {
      currentDir = (Random().nextInt(3) - 1).toDouble();
      moveTimer = 1.0 + Random().nextDouble() * 1.5;
    }
    strafePosition += currentDir * speed * dt;
    if (strafePosition >= 1.0) { strafePosition = 1.0; currentDir = -1.0; }
    if (strafePosition <= -1.0) { strafePosition = -1.0; currentDir = 1.0; }
  }
}

class GoblinEnemy extends Enemy {
  bool isFleeing = false;
  GoblinEnemy() : super(
    type: EnemyType.goblin, color: Palette.verde, hp: 50, maxHp: 50, dropEssence: 20, width: 144, height: 144, speed: 0.6, damage: 15,
    hurtboxWidth: 60, hurtboxHeight: 90, hurtboxOffsetY: 10,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 50, maxAttackCooldown: 1.0 
  );

  @override 
  void onHitStun() { 
    isFleeing = true; 
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

  SpiderEnemy() : super(
    type: EnemyType.spider, color: Palette.marromCla, hp: 20, maxHp: 20, dropEssence: 15, width: 144, height: 144, yPosition: 0.1, targetY: 0.1,
    hurtboxWidth: 60, hurtboxHeight: 70, hurtboxOffsetY: 0,
    hitboxWidth: 50, hitboxHeight: 50, hitboxOffsetY: 30, 
  );

  @override void onHitStun() {
    isDropping = false; 
    hasAttacked = false; 
    targetY = 0.1; // Se tomar porrada, desiste do ataque e foge pro teto!
  }
  
  @override void updateBehavior(double dt, PlayerCombatStats player) {
    // 1. GATILHO PARA DESCER
    if (!isDropping && yPosition <= 0.15 && (player.strafePosition - strafePosition).abs() < 0.2) {
      isDropping = true; 
      hasAttacked = false; // Prepara o bote
      targetY = 0.7; // Vai pro chão
    }
    
    // 2. GATILHO PARA SUBIR (SÓ DEPOIS QUE ATACAR)
    // Se a aranha desceu, já completou o ataque e voltou para o modo Idle, ela sobe para o teto.
    if (isDropping && hasAttacked && currentPhase == CombatPhase.idle) {
      isDropping = false; 
      targetY = 0.1; // Volta pro teto
    }
  }

  @override
  void checkAttackDecision(double dt, PlayerCombatStats player, Vector2 screenSize) {
    attackCooldown -= dt;

    // A Aranha ignora a distância X! Se ela estiver descendo, não atacou ainda, e tocou no chão, ela explode num ataque instantâneo!
    if (isDropping && !hasAttacked && yPosition >= 0.69 && currentPhase == CombatPhase.idle) {
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

  MimicEnemy() : super(
    type: EnemyType.mimic, color: Palette.amarelo, hp: 40, maxHp: 60, dropEssence: 40, width: 144, height: 144, speed: 0.5, damage: 15,
    hurtboxWidth: 90, hurtboxHeight: 90, hurtboxOffsetY: 10,
    hitboxWidth: 0, hitboxHeight: 0, // Não usa dano corpo a corpo!
  );

  // MÁGICA 1: Só toma dano enquanto ataca!
  @override
  bool get isVulnerable => currentPhase == CombatPhase.windup ||  currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery;

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
    // Ele não liga pra distância (ignora reachPixels). Ele atira de onde estiver!
    if (attackCooldown <= 0 && currentPhase == CombatPhase.idle) {
      currentPhase = CombatPhase.windup; 
      animTimer = 1.0; 
      attackCooldown = maxAttackCooldown;
      _spawnedProjectiles = false; // Reseta a flag do tiro
    }
  }

  @override
  void update(double dt, PlayerCombatStats player, Vector2 screenSize) {
    super.update(dt, player, screenSize); // Mantém a lógica de vida e gravidade dos projéteis

    // MÁGICA 2: Dispara os 3 projéteis na fase ativa
    if (currentPhase == CombatPhase.active && !_spawnedProjectiles) {
      _spawnedProjectiles = true;
      // Projétil Esquerdo, Central e Direito
      projectiles.add(ArcProjectile(strafePosition, yPosition, -1, -1.2)); 
      projectiles.add(ArcProjectile(strafePosition, yPosition,  0.0, -1.4)); 
      projectiles.add(ArcProjectile(strafePosition, yPosition,  1, -1.2)); 
    }
  }
}