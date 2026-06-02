import 'dart:ui' as ui;
import 'dart:math';
import 'package:dungeon_crawler/game/components/Effects/buff_particles.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/combat_entities.dart';
import 'package:dungeon_crawler/game/components/Effects/floating_text.dart';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart'; 
import 'package:flutter/material.dart';

class EnemyAnimationSet {
  final SpriteAnimation idleWalk, attackWindup, attackActive, attackRecovery;
  EnemyAnimationSet({required this.idleWalk, required this.attackWindup, required this.attackActive, required this.attackRecovery});
}

class CombatOverlay extends PositionComponent with HasGameRef<DungeonCrawlerGame> {
  final PlayerCombatStats playerStats;
  final ui.Image playerSheetImage;
  final Map<EnemyType, ui.Image> enemySheets;

  late SpriteAnimation playerIdle, playerWalk, playerAttackWindup, playerAttackActive, playerAttackRecovery, playerGuard, playerHit;
  late SpriteAnimationTicker playerIdleTicker, playerWalkTicker, playerAttackWindupTicker, playerAttackActiveTicker, playerAttackRecoveryTicker, playerGuardTicker, playerHitTicker;

  late SpriteAnimation weaponIdle, weaponWalk, weaponAttackWindup, weaponAttackActive, weaponAttackRecovery, weaponGuard, weaponHit;
  late SpriteAnimationTicker weaponIdleTicker, weaponWalkTicker, weaponAttackWindupTicker, weaponAttackActiveTicker, weaponAttackRecoveryTicker, weaponGuardTicker, weaponHitTicker;

  late SpriteAnimation armorIdle, armorWalk, armorAttackWindup, armorAttackActive, armorAttackRecovery, armorGuard, armorHit;
  late SpriteAnimationTicker armorIdleTicker, armorWalkTicker, armorAttackWindupTicker, armorAttackActiveTicker, armorAttackRecoveryTicker, armorGuardTicker, armorHitTicker;

  late SpriteAnimation shieldIdle, shieldWalk, shieldAttackWindup, shieldAttackActive, shieldAttackRecovery, shieldGuard, shieldHit;
  late SpriteAnimationTicker shieldIdleTicker, shieldWalkTicker, shieldAttackWindupTicker, shieldAttackActiveTicker, shieldAttackRecoveryTicker, shieldGuardTicker, shieldHitTicker;


  Map<EnemyType, EnemyAnimationSet> enemyAnimationSets = {}; 
  Map<Enemy, SpriteAnimationTicker> enemyTickers = {};       
  Map<Enemy, CombatPhase> enemyLastPhase = {};      

  final ui.Image playerSlashImage;
  ui.Image weaponSheetImage; 
  ui.Image armorSheetImage; 
  ui.Image shieldSheetImage;
  final Map<EnemyType, ui.Image> enemySlashImages;         

  List<Enemy> enemies = [];
  double _walkTimer = 0.0;


  // Função super fácil para você chamar de qualquer lugar!
  void addFloatingText(String text, Rect targetRect, Color color) {
    // Nasce bem no meio do alvo, um pouco para cima
    add(FloatingText(text, targetRect.center.dx, targetRect.top + 20, color));
  }

  CombatOverlay({
    required this.playerStats, 
    required this.playerSheetImage, 
    required this.enemySheets, 
    required this.playerSlashImage, 
    required this.weaponSheetImage, 
    required this.armorSheetImage, 
    required this.shieldSheetImage,
    required this.enemySlashImages
  }) {
    _initSpriteSheets();
  }

  void _initSpriteSheets() {
    // --- PLAYER ---
    final playerSheet = SpriteSheet.fromColumnsAndRows(image: playerSheetImage, columns: 5, rows: 1);
    playerIdle = playerSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.20, loop: true);
    playerWalk = playerSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.15, loop: true);
    playerAttackWindup = playerSheet.createAnimation(row: 0, from: 1, to: 2, stepTime: 0.10, loop: false); 
    playerAttackActive = playerSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.10, loop: false); 
    playerAttackRecovery = playerSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.5, loop: false); 
    playerGuard = playerSheet.createAnimation(row: 0, from: 3, to: 4, stepTime: 0.20, loop: true); 
    playerHit = playerSheet.createAnimation(row: 0, from: 4, to: 5, stepTime: 0.10, loop: false); 

    playerIdleTicker = SpriteAnimationTicker(playerIdle); playerWalkTicker = SpriteAnimationTicker(playerWalk); playerAttackWindupTicker = SpriteAnimationTicker(playerAttackWindup);
    playerAttackActiveTicker = SpriteAnimationTicker(playerAttackActive); playerAttackRecoveryTicker = SpriteAnimationTicker(playerAttackRecovery); playerGuardTicker = SpriteAnimationTicker(playerGuard); playerHitTicker = SpriteAnimationTicker(playerHit);

    // --- ARMA DO PLAYER ---
    _initWeaponAnimations();

    // --- ARMADURA DO PLAYER ---
    _initArmorAnimations();

    _initShieldAnimations();

    // --- INIMIGOS ---
    enemyAnimationSets.clear();
    for (var entry in enemySheets.entries) {
      final sheet = SpriteSheet.fromColumnsAndRows(image: entry.value, columns: 4, rows: 1);
      enemyAnimationSets[entry.key] = EnemyAnimationSet(
        idleWalk: sheet.createAnimation(row: 0, from: 0, to: 2, stepTime: 0.20, loop: true),
        attackWindup: sheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 1.0, loop: false), 
        attackActive: sheet.createAnimation(row: 0, from: 3, to: 4, stepTime: 0.15, loop: false),
        attackRecovery: sheet.createAnimation(row: 0, from:  3, to: 4, stepTime: 1.0, loop: false),
      );
    }
  }

  void _initWeaponAnimations() {
    final weaponSheet = SpriteSheet.fromColumnsAndRows(image: weaponSheetImage, columns: 5, rows: 1);
    weaponIdle = weaponSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.20, loop: true);
    weaponWalk = weaponSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.15, loop: true);
    weaponAttackWindup = weaponSheet.createAnimation(row: 0, from: 1, to: 2, stepTime: 0.10, loop: false);
    weaponAttackActive = weaponSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.10, loop: false);
    weaponAttackRecovery = weaponSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.5, loop: false);
    weaponGuard = weaponSheet.createAnimation(row: 0, from: 3, to: 4, stepTime: 0.20, loop: true);
    weaponHit = weaponSheet.createAnimation(row: 0, from: 4, to: 5, stepTime: 0.10, loop: false);

    weaponIdleTicker = SpriteAnimationTicker(weaponIdle); weaponWalkTicker = SpriteAnimationTicker(weaponWalk); weaponAttackWindupTicker = SpriteAnimationTicker(weaponAttackWindup);
    weaponAttackActiveTicker = SpriteAnimationTicker(weaponAttackActive); weaponAttackRecoveryTicker = SpriteAnimationTicker(weaponAttackRecovery); weaponGuardTicker = SpriteAnimationTicker(weaponGuard); weaponHitTicker = SpriteAnimationTicker(weaponHit);
  }

  
  void _initArmorAnimations() {
    final armorSheet = SpriteSheet.fromColumnsAndRows(image: armorSheetImage, columns: 5, rows: 1);
    armorIdle = armorSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.20, loop: true);
    armorWalk = armorSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.15, loop: true);
    armorAttackWindup = armorSheet.createAnimation(row: 0, from: 1, to: 2, stepTime: 0.10, loop: false);
    armorAttackActive = armorSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.10, loop: false);
    armorAttackRecovery = armorSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.5, loop: false);
    armorGuard = armorSheet.createAnimation(row: 0, from: 3, to: 4, stepTime: 0.20, loop: true);
    armorHit = armorSheet.createAnimation(row: 0, from: 4, to: 5, stepTime: 0.10, loop: false);

    armorIdleTicker = SpriteAnimationTicker(armorIdle); armorWalkTicker = SpriteAnimationTicker(armorWalk); armorAttackWindupTicker = SpriteAnimationTicker(armorAttackWindup);
    armorAttackActiveTicker = SpriteAnimationTicker(armorAttackActive); armorAttackRecoveryTicker = SpriteAnimationTicker(armorAttackRecovery); armorGuardTicker = SpriteAnimationTicker(armorGuard); armorHitTicker = SpriteAnimationTicker(armorHit);
  }

  void _initShieldAnimations() {
    final shieldSheet = SpriteSheet.fromColumnsAndRows(image: shieldSheetImage, columns: 5, rows: 1);
    shieldIdle = shieldSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.20, loop: true);
    shieldWalk = shieldSheet.createAnimation(row: 0, from: 0, to: 1, stepTime: 0.15, loop: true);
    shieldAttackWindup = shieldSheet.createAnimation(row: 0, from: 1, to: 2, stepTime: 0.10, loop: false);
    shieldAttackActive = shieldSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.10, loop: false);
    shieldAttackRecovery = shieldSheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 0.5, loop: false);
    shieldGuard = shieldSheet.createAnimation(row: 0, from: 3, to: 4, stepTime: 0.20, loop: true);
    shieldHit = shieldSheet.createAnimation(row: 0, from: 4, to: 5, stepTime: 0.10, loop: false);

    shieldIdleTicker = SpriteAnimationTicker(shieldIdle); shieldWalkTicker = SpriteAnimationTicker(shieldWalk); shieldAttackWindupTicker = SpriteAnimationTicker(shieldAttackWindup);
    shieldAttackActiveTicker = SpriteAnimationTicker(shieldAttackActive); shieldAttackRecoveryTicker = SpriteAnimationTicker(shieldAttackRecovery); shieldGuardTicker = SpriteAnimationTicker(shieldGuard); shieldHitTicker = SpriteAnimationTicker(shieldHit);
  }


  void equipNewWeapon(ui.Image newWeaponImage) {
    weaponSheetImage = newWeaponImage; 
    _initWeaponAnimations();           
  }

  void equipNewArmor(ui.Image newArmorImage) {
    armorSheetImage = newArmorImage; 
    _initArmorAnimations();           
  }

  void equipNewShield(ui.Image newShieldImage) {
    shieldSheetImage = newShieldImage; 
    _initShieldAnimations();           
  }

  void startEncounter(List<Enemy> newEnemies) {
    enemies = newEnemies; 
    enemyTickers.clear(); 
    enemyLastPhase.clear(); 
    playerStats.strafePosition = 0.0; 
    playerIdleTicker.reset();
    
    // --- NOVO: Pede ao Flame para tomar conta dos inimigos! ---
    for (var e in enemies) { add(e); } 
  }

  SpriteAnimationTicker getTickerForEnemy(Enemy enemy) {
    final animSet = enemyAnimationSets[enemy.type] ?? enemyAnimationSets[EnemyType.slime]!;
    SpriteAnimation targetAnim = animSet.idleWalk;
    if (enemy.currentPhase == CombatPhase.windup) targetAnim = animSet.attackWindup;
    else if (enemy.currentPhase == CombatPhase.active) targetAnim = animSet.attackActive;
    else if (enemy.currentPhase == CombatPhase.recovery) targetAnim = animSet.attackRecovery;

    if (!enemyTickers.containsKey(enemy) || enemyLastPhase[enemy] != enemy.currentPhase) {
      enemyTickers[enemy] = SpriteAnimationTicker(targetAnim);
      enemyLastPhase[enemy] = enemy.currentPhase;
    }
    return enemyTickers[enemy]!;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (playerStats.currentPhase == CombatPhase.walk || playerStats.currentPhase == CombatPhase.idle) playerStats.recoverStamina(dt);
    playerStats.updatePhase(dt);

    if (playerStats.staminaInfiniteTmr > 0 && gameRef.currentState == GameState.combat) {
      // 30% de chance por frame de gerar uma partícula nova (ajuste para mais ou menos denso)
      if (Random().nextDouble() < 0.3) { 
        double px = (size.x / 2) + (playerStats.strafePosition * size.x * 0.35) + (Random().nextDouble() * 100 - 50);
        double py = size.y - 50 - (Random().nextDouble() * 50); // Nasce perto do chão
        add(BuffParticle(px, py, 40 + Random().nextDouble() * 60, 0.8 + Random().nextDouble())); // Vive cerca de 1 a 2 seg
      }
    }

    if (gameRef.currentState != GameState.combat) return;
    if (playerStats.currentPhase == CombatPhase.walk) _walkTimer += dt;
    _updateAnimationTimers(dt);
  }

  void _updateAnimationTimers(double dt) {
    if (playerStats.hitFlashTimer > 0) {
      playerHitTicker.update(dt);
      weaponHitTicker.update(dt); 
      armorHitTicker.update(dt);  // <--- Faltava a Armadura
      shieldHitTicker.update(dt); // <--- Faltava o Escudo
    } else {
      switch (playerStats.currentPhase) {
        case CombatPhase.idle: 
          playerIdleTicker.update(dt); weaponIdleTicker.update(dt); armorIdleTicker.update(dt); shieldIdleTicker.update(dt); 
          break;
        case CombatPhase.walk: 
          playerWalkTicker.update(dt); weaponWalkTicker.update(dt); armorWalkTicker.update(dt); shieldWalkTicker.update(dt); 
          break;
        case CombatPhase.windup: 
          playerAttackWindupTicker.update(dt); weaponAttackWindupTicker.update(dt); armorAttackWindupTicker.update(dt); shieldAttackWindupTicker.update(dt); 
          break;
        case CombatPhase.active: 
          playerAttackActiveTicker.update(dt); weaponAttackActiveTicker.update(dt); armorAttackActiveTicker.update(dt); shieldAttackActiveTicker.update(dt); 
          break;
        case CombatPhase.recovery: 
          playerAttackRecoveryTicker.update(dt); weaponAttackRecoveryTicker.update(dt); armorAttackRecoveryTicker.update(dt); shieldAttackRecoveryTicker.update(dt); 
          break;
        case CombatPhase.guard: 
          playerGuardTicker.update(dt); weaponGuardTicker.update(dt); armorGuardTicker.update(dt); shieldGuardTicker.update(dt); 
          break;
        case CombatPhase.hit: 
          break; 
        case CombatPhase.entering: 
        case CombatPhase.exiting: 
          playerIdleTicker.update(dt); weaponIdleTicker.update(dt); armorIdleTicker.update(dt); shieldIdleTicker.update(dt); 
          break;
      }
    }
    for (var enemy in enemies) { 
      if (enemy.hitFlashTimer <= 0) {
        getTickerForEnemy(enemy).update(dt); 
      }
    }
  }

  void applyEnemyDamage(Enemy enemy) {
    double defense = playerStats.equippedArmor?.power ?? 0; // Armadura reduz dano!
    double dmg = max(1, enemy.damage - defense);
    if (playerStats.isGuarding) {
      if (playerStats.stamina >= 0) {
        if (playerStats.staminaInfiniteTmr <= 0){
          playerStats.stamina -= (25.0 - playerStats.equippedShield!.power); 
        } 
        playerStats.stamina = playerStats.stamina.clamp(0, playerStats.maxStamina);
        if (playerStats.stamina <= 0) {
          playerStats.cansado = true;
        }
        playerStats.flashColor = Palette.cinza;
        playerStats.hitFlashTimer = 0.1; 
      } else { 
        playerStats.stamina = 0; 
        playerStats.hp -= dmg; 
        playerStats.applyHitStun(0.3);
        playerHitTicker.reset(); 
        weaponHitTicker.reset();
      }
    } else { 
      playerStats.hp -= dmg; 
      playerStats.applyHitStun(0.3); 
      playerHitTicker.reset(); 
      weaponHitTicker.reset();
    }
    if (playerStats.hp < 0) playerStats.hp = 0;
  }

  @override
  void render(Canvas canvas) {
    // 1. O que estiver aqui é desenhado ANTES dos inimigos (Lá no fundo da tela)
    if (gameRef.currentState == GameState.combat) {
      _drawAttackEffects(canvas); 
    }
  }

  @override
  void renderTree(Canvas canvas) {
    // 2. Manda o Flame desenhar o fundo (render acima) e DEPOIS todos os Inimigos, Magias e Partículas
    super.renderTree(canvas);

    // 3. O que estiver aqui é desenhado POR CIMA dos inimigos (Primeiro Plano da Câmera)
    if (gameRef.currentState == GameState.combat) {
      
      _drawPlayer(canvas); // A arma do jogador volta a tapar os inimigos!
      
      if (gameRef.showHitboxes) _drawDebugBoxes(canvas);
      _drawVictoryMessage(canvas);
    }
    
    // 4. A interface (HP, Mana, Textos) fica sempre por cima de absolutamente tudo
    _drawPlayerUI(canvas);
    _drawEffects(canvas);
    _drawBottomBarBackground(canvas);
  }


  void _drawEffects(Canvas canvas) {
    if (playerStats.healVfxTimer > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.greenAccent.withOpacity(playerStats.healVfxTimer.clamp(0.0, 0.5)));
    }
    if (playerStats.explosionVfxTimer > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.deepOrange.withOpacity(playerStats.explosionVfxTimer.clamp(0.0, 0.5)));
    }
    if (playerStats.manaVfxTimer > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.blueAccent.withOpacity(playerStats.manaVfxTimer.clamp(0.0, 0.5)));
    }
  }

  void _drawAttackEffects(Canvas canvas) {
    if (playerStats.currentPhase == CombatPhase.active) {
      canvas.drawImageRect(
        playerSlashImage,
        Rect.fromLTWH(0, 0, playerSlashImage.width.toDouble(), playerSlashImage.height.toDouble()),
        playerStats.getHitboxImageSize(size), 
        Paint()
      );
    }

    for (var enemy in enemies) {
      if (!enemy.isAlive) continue;
      
      if (enemy.currentPhase == CombatPhase.active && enemy.getHitbox(size).width > 0) {
        final slashImg = enemySlashImages[enemy.type] ?? enemySlashImages[EnemyType.slime]!;
        final slashPaint = Paint();
        canvas.drawImageRect(
          slashImg,
          Rect.fromLTWH(0, 0, slashImg.width.toDouble(), slashImg.height.toDouble()),
          enemy.getHitboxImageSize(size),
          slashPaint 
        );
      }

    }
  }

  void _drawBottomBarBackground(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, size.y - 70, size.x, 70), Paint()..color = Palette.preto.withOpacity(0.9));
  }

  void _drawDebugBoxes(Canvas canvas) {
    for (var enemy in enemies) {
      canvas.drawRect(enemy.getHurtbox(size), Paint()..color = Colors.green.withOpacity(0.4)..style = PaintingStyle.fill);
      canvas.drawRect(enemy.getHurtbox(size), Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 2);
      
      if (enemy.currentPhase == CombatPhase.active && enemy.getHitbox(size).width > 0) {
        canvas.drawRect(enemy.getHitbox(size), Paint()..color = Colors.red.withOpacity(0.4)..style = PaintingStyle.fill);
        canvas.drawRect(enemy.getHitbox(size), Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
    canvas.drawRect(playerStats.getHurtbox(size), Paint()..color = Colors.blueAccent.withOpacity(0.4)..style = PaintingStyle.fill);
    canvas.drawRect(playerStats.getHurtbox(size), Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2);
    
    if (playerStats.currentPhase == CombatPhase.active) {
      canvas.drawRect(playerStats.getHitbox(size), Paint()..color = Colors.orange.withOpacity(0.4)..style = PaintingStyle.fill);
      canvas.drawRect(playerStats.getHitbox(size), Paint()..color = Colors.orange..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  void _drawSpiderWebLines(Canvas canvas, Enemy enemy) {
    if (enemy.type != EnemyType.spider || !enemy.isAlive) return;
    double cx = (size.x / 2) + (enemy.strafePosition * size.x * 0.35) + 4;
    double spiderTopY = size.y * enemy.yPosition;
    final webPaint = Paint()
      ..color = Palette.branco 
      ..strokeWidth = 5.0 
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
    final webPaintBorder = Paint()
      ..color = Palette.preto
      ..strokeWidth = 15.0 
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke;  
    canvas.drawLine(Offset(cx, spiderTopY), Offset(cx, 0), webPaintBorder);
    canvas.drawLine(Offset(cx, spiderTopY), Offset(cx, 0), webPaint);
  }

  void _drawEnemy(Canvas canvas) {
    for (var enemy in enemies) {
      if (!enemy.isAlive) continue; 

      if (enemy.isDying) {
        int blinkCycle = (enemy.deathTimer * 15).toInt();
        if (blinkCycle % 2 == 0) continue; 
      }

      _drawSpiderWebLines(canvas, enemy);

      double xPixel = (size.x / 2) + (enemy.strafePosition * size.x * 0.35) - (enemy.width / 2);
      double yPixel = size.y * enemy.yPosition - (enemy.height / 2);
      final dstRect = Rect.fromLTWH(xPixel, yPixel, enemy.width, enemy.height);

      SpriteAnimationTicker activeTicker = getTickerForEnemy(enemy);
      final Color flashColor = enemy.hitFlashTimer > 0 ? enemy.flashColor : Colors.white;
      final BlendMode blendMode = enemy.hitFlashTimer > 0 ? BlendMode.srcATop : BlendMode.modulate;

      final tintPaint = Paint()..colorFilter = ColorFilter.mode(flashColor, blendMode);

      activeTicker.getSprite().renderRect(canvas, dstRect, overridePaint: tintPaint);
    }
  }

  void _drawPlayer(Canvas canvas) {
    double playerWidth = 196; double playerHeight = 196;
    double yOffset = 0; double duration = 0.5;

    if (playerStats.currentPhase == CombatPhase.walk) { yOffset = -(sin(_walkTimer * 12) * 4).abs() * -1; } 
    else if (playerStats.currentPhase == CombatPhase.entering) { yOffset = playerHeight * (1.0 - ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0)); } 
    else if (playerStats.currentPhase == CombatPhase.exiting) { yOffset = playerHeight * ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0); }

    double xPixel = (size.x / 2) + (playerStats.strafePosition * size.x * 0.35) - (playerWidth / 2);
    final dstRect = Rect.fromLTWH(xPixel, size.y - 65 - playerHeight + yOffset, playerWidth, playerHeight);
    final dstRectWeapon = Rect.fromLTWH(xPixel, size.y - 65 - playerHeight + yOffset + playerStats.offYWeapon, playerWidth, playerHeight);

    SpriteAnimationTicker activeTicker;
    SpriteAnimationTicker activeWeaponTicker; 
    SpriteAnimationTicker activeArmorTicker;
    SpriteAnimationTicker activeShieldTicker;

    switch (playerStats.currentPhase) {
      case CombatPhase.windup: activeTicker = playerAttackWindupTicker; activeWeaponTicker = weaponAttackWindupTicker; activeArmorTicker = armorAttackWindupTicker; activeShieldTicker = shieldAttackWindupTicker; break;
      case CombatPhase.active: activeTicker = playerAttackActiveTicker; activeWeaponTicker = weaponAttackActiveTicker; activeArmorTicker = armorAttackActiveTicker; activeShieldTicker = shieldAttackActiveTicker; break;
      case CombatPhase.recovery: activeTicker = playerAttackRecoveryTicker; activeWeaponTicker = weaponAttackRecoveryTicker; activeArmorTicker = armorAttackRecoveryTicker; activeShieldTicker = shieldAttackRecoveryTicker; break;
      case CombatPhase.guard: activeTicker = playerGuardTicker; activeWeaponTicker = weaponGuardTicker; activeArmorTicker = armorGuardTicker; activeShieldTicker = shieldGuardTicker; break;
      case CombatPhase.walk: activeTicker = playerWalkTicker; activeWeaponTicker = weaponWalkTicker; activeArmorTicker = armorWalkTicker; activeShieldTicker = shieldWalkTicker; break;
      case CombatPhase.hit: activeTicker = playerHitTicker; activeWeaponTicker = weaponHitTicker; activeArmorTicker = armorHitTicker; activeShieldTicker = shieldHitTicker; break;
      default: activeTicker = playerIdleTicker; activeWeaponTicker = weaponIdleTicker; activeArmorTicker = armorIdleTicker; activeShieldTicker = shieldIdleTicker; break;
    }

    final playerPaint = Paint();
    //playerPaint.colorFilter = const ColorFilter.mode(Palette.bege, BlendMode.modulate); 

    Color corArma = playerStats.equippedWeapon?.cor ?? Colors.white;
    Color corArmadura = playerStats.equippedArmor?.cor ?? Colors.white;
    Color corEscudo = playerStats.equippedShield?.cor ?? Colors.white;

    final weaponPaint = Paint();
    weaponPaint.colorFilter = ColorFilter.mode(corArma, BlendMode.modulate); 
    
    final armorPaint = Paint();
    armorPaint.colorFilter =  ColorFilter.mode(corArmadura, BlendMode.modulate); 

    final shieldPaint = Paint();
    shieldPaint.colorFilter =  ColorFilter.mode(corEscudo, BlendMode.modulate); 

    if (playerStats.hitFlashTimer > 0) { 
      playerPaint.colorFilter =  ColorFilter.mode(playerStats.flashColor, BlendMode.modulate); 
    }
    if(playerStats.cansado) {
      playerPaint.colorFilter = const ColorFilter.mode(Palette.bege, BlendMode.modulate); 
    }
    
    // 1. Desenha o Corpo
    activeTicker.getSprite().renderRect(canvas, dstRect, overridePaint: playerPaint);
    
    // 2. Desenha a Arma
    activeWeaponTicker.getSprite().renderRect(canvas, dstRectWeapon, overridePaint: weaponPaint);
    
    // 3. Desenha a Armadura
    activeArmorTicker.getSprite().renderRect(canvas, dstRect, overridePaint: armorPaint);
    
    // 4. Desenha o Escudo
    activeShieldTicker.getSprite().renderRect(canvas, dstRect, overridePaint: shieldPaint);
  }

  void _drawPlayerUI(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 60), Paint()..color = Palette.preto);
    double barWidth = (size.x - 40) / 3;
    _drawHorizontalBar(canvas, 10, 15, barWidth, 12, Palette.vermelho, playerStats.hp / playerStats.maxHp);
    _drawHorizontalBar(canvas, 10, 30, barWidth, 12, Palette.verde, playerStats.stamina / playerStats.maxStamina);
    _drawHorizontalBar(canvas, 10, 45, barWidth, 12, Palette.azul, playerStats.mana / playerStats.maxMana);
    if (gameRef.selectedConsumableIndex < playerStats.consumables.length && gameRef.currentState == GameState.combat) {
      Item sel = playerStats.consumables[gameRef.selectedConsumableIndex];
      double boxX = size.x/2 - 35;
      double boxY = 5;

      // Desenha a caixa de fundo
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, 60, 60), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, 60, 60), Paint()..color = Palette.cinzaCla..style = PaintingStyle.stroke);
      try {
        ui.Image itemImg = gameRef.images.fromCache(sel.imagePath);
        
        // Aplica a cor definida na variável do Item
        final tintPaint = Paint()..colorFilter = ColorFilter.mode(sel.cor, BlendMode.modulate);
        
        canvas.drawImageRect(
          itemImg,
          Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()),
          Rect.fromLTWH(boxX + 5, boxY + 0, 55, 55), 
          tintPaint // <--- Usa o paint com cor aqui!
        );
      } catch (e) {
        // Se a imagem não for encontrada, não quebra o jogo
      }

      String amountText = sel.type == ItemType.spell ? '${sel.manaCost} MP' : '${sel.quantity}x';
      
      TextPainter(
        text: TextSpan(text: amountText, style: TextStyle(color: sel.type == ItemType.spell ? Palette.azul : Palette.branco, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(size.x/2 - 30, 35));
      TextPainter(
        text: const TextSpan(text: 'Uso[B]', style: TextStyle(color: Palette.amarelo, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(size.x/2 - 30, 8));
    }
    if (gameRef.currentState == GameState.exploration && gameRef.player.hasKey) {
      double keyX = size.x/2 - 20;
      double keyY = 15;
      
      // Fundo escuro com borda dourada
      canvas.drawRect(Rect.fromLTWH(keyX, keyY, 40, 40), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(keyX, keyY, 40, 40), Paint()..color = Palette.amarelo..style = PaintingStyle.stroke..strokeWidth = 1);
      
      // Desenha o Sprite da Chave
      try {
        canvas.drawImageRect(
          gameRef.keySprite, 
          Rect.fromLTWH(0, 0, gameRef.keySprite.width.toDouble(), gameRef.keySprite.height.toDouble()),
          Rect.fromLTWH(keyX + 5, keyY + 5, 30, 30), // Margem de 5px dentro do quadrado
          Paint()..colorFilter = ColorFilter.mode(Palette.cinza, BlendMode.modulate)
        );
      } catch (e) {
        // Fallback caso a imagem dê erro
      }
    }
  
  }

  void _drawEnemyUI(Canvas canvas) {
    for (int i = 0; i < enemies.length; i++) {
      if (!enemies[i].isAlive) continue;
      _drawHorizontalBar(canvas, 15, size.y - 70 + 10 + i*14, size.x - 30, 10, Palette.vermelho, enemies[i].hp / enemies[i].maxHp);
    }
  }

  void _drawHorizontalBar(Canvas canvas, double x, double y, double w, double h, Color c, double r) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Colors.black);
    canvas.drawRect(Rect.fromLTWH(x, y, w * r.clamp(0.0, 1.0), h), Paint()..color = c);
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Colors.white24..style = PaintingStyle.stroke);
  }

  void _drawVictoryMessage(Canvas canvas) {
    if (!gameRef.showVictoryMessage) return;

    double boxWidth = 320;
    double boxHeight = 120;
    double boxX = (size.x - boxWidth) / 2;
    double boxY = (size.y - boxHeight) / 2 - 50; 

    final rect = Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight);
    canvas.drawRect(rect, Paint()..color = Palette.preto.withOpacity(0.95));
    canvas.drawRect(rect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

    final textSpan = TextSpan(
      text: 'VITÓRIA!\n\nVocê obteve ${gameRef.encounterEssence} Essências.\n\n[A] Continuar',
      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3, fontFamily: 'Courier', fontWeight: FontWeight.bold),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    textPainter.layout(minWidth: boxWidth, maxWidth: boxWidth);
    
    double textY = boxY + (boxHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(boxX, textY));
  }
}