import 'dart:ui' as ui;
import 'dart:math';
import 'package:dungeon_crawler/game/components/Effects/buff_particles.dart';
import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/i18n.dart';
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
  final SpriteAnimation idleWalk, attackWindup, attackActive, attackRecovery, hit, die;
  final SpriteAnimation? defend;
  final SpriteAnimation? summon;
  final SpriteAnimation? attackWindup2;
  final SpriteAnimation? attackActive2;
  final SpriteAnimation? attackRecovery2;

  EnemyAnimationSet({
    required this.idleWalk, 
    required this.attackWindup, 
    required this.attackActive, 
    required this.attackRecovery, 
    required this.hit,
    required this.die,
    this.defend, 
    this.summon, 
    this.attackWindup2, 
    this.attackActive2, 
    this.attackRecovery2, 
  });
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

  List <ui.Image> playerSlashImage;
  ui.Image weaponSheetImage; 
  ui.Image armorSheetImage; 
  ui.Image shieldSheetImage;
  final Map<EnemyType, ui.Image> enemySlashImages;         

  List<Enemy> enemies = [];
  double _walkTimer = 0.0;

  void addFloatingText(String text, Rect targetRect, Color color,{double speedY = 60, double tmr = 1.5}) {
    add(FloatingText(text, targetRect.center.dx, targetRect.top + 20, color,speedY: speedY, maxLifeTime: tmr));
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
      int totalColumns = 5;

      switch (entry.key){
        case EnemyType.orc:
        case EnemyType.bug:
        case EnemyType.esqueleto:
        case EnemyType.jester:
          totalColumns = 6;
          break;
        case EnemyType.boss1:
          totalColumns = 9;
          break;
        case EnemyType.infectado:
        case EnemyType.naga:
        case EnemyType.mao:
          totalColumns = 8;
          break;
        case EnemyType.goblinShop:
          totalColumns = 7;
          break; 
        default:
          totalColumns = 5;
          break;
      }

      final sheet = SpriteSheet.fromColumnsAndRows(image: entry.value, columns: totalColumns, rows: 2);
      
      SpriteAnimation? defendAnim;
      if (entry.key == EnemyType.orc || entry.key == EnemyType.boss1 || entry.key == EnemyType.bug 
      || entry.key == EnemyType.infectado || entry.key == EnemyType.esqueleto || entry.key == EnemyType.jester
      || entry.key == EnemyType.naga || entry.key == EnemyType.mao) {
        defendAnim = sheet.createAnimation(row: 0, from: 5, to: 6, stepTime: 1.0, loop: true);
      }

      SpriteAnimation? summonAnim;
      if (entry.key == EnemyType.boss1) {
        summonAnim = sheet.createAnimation(row: 0, from: 6, to: 7, stepTime: 1.0, loop: true);
      }

      SpriteAnimation? windup2;
      SpriteAnimation? active2;
      SpriteAnimation? recovery2;
      if (entry.key == EnemyType.infectado || entry.key == EnemyType.naga || entry.key == EnemyType.mao) {
        windup2 = sheet.createAnimation(row: 0, from: 6, to: 7, stepTime: 1.0, loop: false);
        active2 = sheet.createAnimation(row: 0, from: 7, to: 8, stepTime: 0.15, loop: false);
        recovery2 = sheet.createAnimation(row: 0, from: 7, to: 8, stepTime: 1.0, loop: false);
      }
      if (entry.key == EnemyType.boss1) {
        windup2 = sheet.createAnimation(row: 0, from: 7, to: 8, stepTime: 1.0, loop: false);
        active2 = sheet.createAnimation(row: 0, from: 8, to: 9, stepTime: 0.15, loop: false);
        recovery2 = sheet.createAnimation(row: 0, from: 8, to: 9, stepTime: 1.0, loop: false);
      }
      if (entry.key == EnemyType.goblinShop) {
        windup2 = sheet.createAnimation(row: 0, from: 5, to: 6, stepTime: 1.0, loop: false);
        active2 = sheet.createAnimation(row: 0, from: 6, to: 7, stepTime: 0.15, loop: false);
        recovery2 = sheet.createAnimation(row: 0, from: 6, to: 7, stepTime: 1.0, loop: false);
      }

      enemyAnimationSets[entry.key] = EnemyAnimationSet(
        idleWalk: sheet.createAnimation(row: 0, from: 0, to: 2, stepTime: 0.20, loop: true),
        attackWindup: sheet.createAnimation(row: 0, from: 2, to: 3, stepTime: 1.0, loop: false), 
        attackActive: sheet.createAnimation(row: 0, from: 3, to: 4, stepTime: 0.15, loop: false),
        attackRecovery: sheet.createAnimation(row: 0, from:  3, to: 4, stepTime: 1.0, loop: false),
        hit: sheet.createAnimation(row: 0, from:  4, to: 5, stepTime: 0.3, loop: true),
        die: sheet.createAnimation(row: 1, from:  0, to: 1, stepTime: 0.3, loop: true),
        defend: defendAnim, 
        summon: summonAnim,
        attackWindup2: windup2,
        attackActive2: active2,
        attackRecovery2: recovery2,
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
    
    for (var e in enemies) { add(e); } 
  }

  SpriteAnimationTicker getTickerForEnemy(Enemy enemy) {
    final animSet = enemyAnimationSets[enemy.type] ?? enemyAnimationSets[EnemyType.slime]!;
    SpriteAnimation targetAnim = animSet.idleWalk;
    if (enemy.currentPhase == CombatPhase.windup) {
      targetAnim = animSet.attackWindup;
    } else if (enemy.currentPhase == CombatPhase.active){
      targetAnim = animSet.attackActive;
    } 
    else if (enemy.currentPhase == CombatPhase.recovery) {
      targetAnim = animSet.attackRecovery;
    }
    else if (enemy.currentPhase == CombatPhase.hit){
      targetAnim = animSet.hit;
    }
    else if (enemy.currentPhase == CombatPhase.die){
      targetAnim = animSet.die;
    } 
    else if (enemy.currentPhase == CombatPhase.guard) {
      targetAnim = animSet.defend ?? animSet.idleWalk; 
    }
    else if (enemy.currentPhase == CombatPhase.summon) {
      targetAnim = animSet.summon ?? animSet.idleWalk; 
    }
    if (enemy.currentPhase == CombatPhase.windup2) {
      targetAnim = animSet.attackWindup2 ?? animSet.idleWalk;
    } else if (enemy.currentPhase == CombatPhase.active2){
      targetAnim = animSet.attackActive2 ?? animSet.idleWalk;
    } 
    else if (enemy.currentPhase == CombatPhase.recovery2) {
      targetAnim = animSet.attackRecovery2 ?? animSet.idleWalk;
    }

    if (!enemyTickers.containsKey(enemy) || enemyLastPhase[enemy] != enemy.currentPhase) {
      enemyTickers[enemy] = SpriteAnimationTicker(targetAnim);
      enemyLastPhase[enemy] = enemy.currentPhase;
    }
    return enemyTickers[enemy]!;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if(gameRef.currentState == GameState.paused)return;
    
    if (playerStats.currentPhase == CombatPhase.walk || playerStats.currentPhase == CombatPhase.idle) playerStats.recoverStamina(dt);
    playerStats.updatePhase(dt);

    if (playerStats.staminaInfiniteTmr > 0 && gameRef.currentState == GameState.combat) {
      if (Random().nextDouble() < 0.3) { 
        double px = (size.x / 2) + (playerStats.strafePosition * size.x * 0.35) + (Random().nextDouble() * 100 - 50);
        double py = size.y - 50 - (Random().nextDouble() * 50);
        add(BuffParticle(px, py, 40 + Random().nextDouble() * 60, 0.8 + Random().nextDouble()));
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
      armorHitTicker.update(dt);
      shieldHitTicker.update(dt); 
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
        default:
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

  @override
  void renderTree(Canvas canvas) {
    if (gameRef.currentState == GameState.combat) {
      if(gameRef.isBoss && gameRef.dungeon.level == 12){//12
        canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.black);
      }
    }
    super.renderTree(canvas);

    if (gameRef.currentState == GameState.combat) {
      _drawAttackEffects(canvas);
      _drawPlayer(canvas);
      if (gameRef.showHitboxes) _drawDebugBoxes(canvas);
    }
    _drawPlayerUI(canvas);
    _drawBottomBarBackground(canvas);

    if (gameRef.currentState == GameState.combat)_drawEnemyUI(canvas);

    _drawEffects(canvas);
  }


  void _drawEffects(Canvas canvas) {
    if (playerStats.vfxTimer > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = playerStats.vfxColor.withOpacity(playerStats.vfxTimer.clamp(0.0, 0.5)));
    }
  }

  void _drawAttackEffects(Canvas canvas) {
    if (playerStats.currentPhase == CombatPhase.active) {
      int slashIdx = 0;
      bool wide = playerStats.equippedWeapon?.isWide ?? false;
      if (wide) slashIdx = 1;
      canvas.drawImageRect(
        playerSlashImage[slashIdx],
        Rect.fromLTWH(0, 0, playerSlashImage[slashIdx].width.toDouble(), playerSlashImage[slashIdx].height.toDouble()),
        playerStats.getHitboxImageSize(size), 
        Paint()
      );
    }

    for (var enemy in enemies) {
      if (!enemy.isAlive) continue;
      
      if ((enemy.currentPhase == CombatPhase.active || enemy.currentPhase == CombatPhase.active2)&& enemy.getHitbox(size).width > 0 && enemy.isMelee) {
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
    canvas.drawRect(Rect.fromLTWH(1, size.y - 76, size.x-2, 75), Paint()..color = Colors.black);
    canvas.drawRect(Rect.fromLTWH(1, size.y - 76, size.x-2, 75), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
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

  void _drawPlayer(Canvas canvas) {
    if (playerStats.invencibleTmr>0 && (playerStats.invencibleTmr * 15).toInt() % 2 == 0) return;
    
    double playerWidth = 196; double playerHeight = 196;
    double yOffset = 0; double duration = 0.5;

    if (playerStats.currentPhase == CombatPhase.walk) { yOffset = -(sin(_walkTimer * 12) * 4).abs() * -1; } 
    else if (playerStats.currentPhase == CombatPhase.entering) { yOffset = playerHeight * (1.0 - ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0)); } 
    else if (playerStats.currentPhase == CombatPhase.exiting) { yOffset = playerHeight * ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0); }

    double xPixel = (size.x / 2) + (playerStats.strafePosition * size.x * 0.35) - (playerWidth / 2);
    final dstRect = Rect.fromLTWH(xPixel, size.y - 65 - playerHeight + yOffset, playerWidth, playerHeight);
    final dstRectWeapon = Rect.fromLTWH(xPixel, size.y - 65 - playerHeight + yOffset - playerStats.offYWeapon, playerWidth, playerHeight);

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

    if (playerStats.vfxTimer > 0) { 
      playerPaint.colorFilter =  ColorFilter.mode(playerStats.flashColor, BlendMode.modulate); 
    }
    if(playerStats.cansado) {
      playerPaint.colorFilter = const ColorFilter.mode(Palette.bege, BlendMode.modulate); 
    }
    
    bool noShield = playerStats.equippedShield?.noShield ?? false;
    bool isShieldInFront = noShield || playerStats.currentPhase == CombatPhase.active || playerStats.currentPhase == CombatPhase.recovery;

    if (isShieldInFront){
      // 1. Desenha o Corpo
      activeTicker.getSprite().renderRect(canvas, dstRect, overridePaint: playerPaint);
      // 2. Desenha a Arma
      activeWeaponTicker.getSprite().renderRect(canvas, dstRectWeapon, overridePaint: weaponPaint);
      // 3. Desenha a Armadura
      activeArmorTicker.getSprite().renderRect(canvas, dstRect, overridePaint: armorPaint);
      // 4. Desenha o Escudo
      activeShieldTicker.getSprite().renderRect(canvas, dstRect, overridePaint: shieldPaint);

    }else{
      // 1. Desenha o Escudo
      activeShieldTicker.getSprite().renderRect(canvas, dstRect, overridePaint: shieldPaint);
      // 2. Desenha o Corpo
      activeTicker.getSprite().renderRect(canvas, dstRect, overridePaint: playerPaint);
      // 3. Desenha a Arma
      activeWeaponTicker.getSprite().renderRect(canvas, dstRectWeapon, overridePaint: weaponPaint);
      // 4. Desenha a Armadura
      activeArmorTicker.getSprite().renderRect(canvas, dstRect, overridePaint: armorPaint);
    }

  }

  void _drawPlayerUI(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(1, 1, size.x-2, 75), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(1, 1, size.x-2, 75), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
    //double barWidth = (size.x - 40) / 3;
    _drawHorizontalBar(canvas, 10, 10, playerStats.maxHp * 4, 12, Palette.vermelho, playerStats.hp / playerStats.maxHp);
    _drawHorizontalBar(canvas, 10, 25, playerStats.con * 12, 12, Palette.verde, playerStats.stamina / (playerStats.con * 3));
    _drawHorizontalBar(canvas, 10, 40, playerStats.wis * 12, 12, Palette.azul, playerStats.mana / (playerStats.wis * 3));
    
    //inventario
    if (gameRef.selectedConsumableIndex < playerStats.consumables.length && gameRef.currentState == GameState.combat) {
      Item sel = playerStats.consumables[gameRef.selectedConsumableIndex];
      double bxSize = 55;
      double boxX = size.x - (bxSize + 1);
      double boxY = 1;
      // Desenha a caixa de fundo
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, bxSize, bxSize), Paint()..color = Palette.preto);
      
      try {
        ui.Image itemImg = gameRef.images.fromCache(sel.imagePath);
        
        // Aplica a cor definida na variável do Item
        final tintPaint = Paint()..colorFilter = ColorFilter.mode(sel.cor, BlendMode.modulate);
        
        canvas.drawImageRect(
          itemImg,
          Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()),
          Rect.fromLTWH(boxX, boxY, bxSize, bxSize), 
          tintPaint // <--- Usa o paint com cor aqui!
        );
      } catch (e) {
        // Se a imagem não for encontrada, não quebra o jogo
      }
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, bxSize, bxSize), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      String amountText = sel.type == ItemType.spell ? '${sel.manaCost} MP' : '${sel.quantity}x';
      
      TextPainter(
        text: TextSpan(text: amountText, style: TextStyle(fontFamily: 'pixelFont', color: sel.type == ItemType.spell ? Palette.azul : Palette.branco, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(boxX, bxSize + 5));
      //TextPainter(
      //  text: const TextSpan(text: 'Uso[B]', style: TextStyle(fontFamily: 'pixelFont', color: Palette.amarelo, fontSize: 10)),
      //  textDirection: TextDirection.ltr,
      //)..layout()..paint(canvas, Offset(boxX, 45));
      if(playerStats.reflex){
        TextPainter(
          text: const TextSpan(text: 'REFLEX', style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout()..paint(canvas, Offset(size.x-(bxSize*1.5)-'REFLEX'.length*10, 20));
      }

    }
    if (gameRef.currentState == GameState.exploration && gameRef.player.hasKey) {
      double bxSize = 55;
      double keyX = size.x/2 + bxSize;
      double keyY = 10;
      
      canvas.drawRect(Rect.fromLTWH(keyX, keyY, bxSize, bxSize), Paint()..color = Palette.preto);
      try {
        canvas.drawImageRect(
          gameRef.keySprite, 
          Rect.fromLTWH(0, 0, gameRef.keySprite.width.toDouble(), gameRef.keySprite.height.toDouble()),
          Rect.fromLTWH(keyX, keyY, bxSize, bxSize),
          Paint()..colorFilter = ColorFilter.mode(Palette.amarelo, BlendMode.modulate)
        );
      } catch (e) {
        // Fallback caso a imagem dê erro
      }
      canvas.drawRect(Rect.fromLTWH(keyX, keyY, bxSize, bxSize), Paint()..color = Palette.amarelo..style = PaintingStyle.stroke..strokeWidth = 1);
      
    }

    if (gameRef.currentState == GameState.exploration) {
      
      String direc = 'dir_n';
      switch (gameRef.player.facing) {
      case Direction.north: direc = 'dir_n'; break;
      case Direction.east:  direc = 'dir_l'; break;
      case Direction.south: direc = 'dir_s'; break;
      case Direction.west:  direc = 'dir_o'; break;
    }
      TextPainter(
          text: TextSpan(text: I18n.t(direc).toUpperCase(), style: const TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 24)),
          textDirection: TextDirection.ltr,
        )..layout()..paint(canvas, Offset(size.x/2 - I18n.t(direc).length*6 , 22));
    }
  }

  void _drawEnemyUI(Canvas canvas) {
    // 1. Configurações de espaçamento da grade
    double margin = 15.0; // Margem das laterais da tela
    double gap = 10.0;    // Espaço em branco entre a Coluna 1 e a Coluna 2
    
    // 2. Calcula a largura que cada barra terá (Metade da tela - margens e espaçamento)
    double barWidth = (size.x - (margin * 2) - gap) / 2;

    int displayIndex = 0; // Índice visual para não deixar buracos quando um inimigo morrer

    for (int i = 0; i < enemies.length; i++) {
      if (!enemies[i].isAlive) continue;

      // Impede de desenhar mais do que 8 barras para não vazar da caixa preta
      if (displayIndex >= 8) break; 

      // 3. Matemática da Grade (Grid)
      int col = displayIndex % 2;  // Retorna 0 (Esquerda) ou 1 (Direita)
      int row = displayIndex ~/ 2; // Retorna a linha: 0, 1, 2 ou 3

      // Calcula as posições X e Y baseadas na coluna e linha
      double startX = margin + (col * (barWidth + gap));
      double startY = size.y - 75 + 2 + (row * 18);

      // Desenha a barra com o novo tamanho e posição
      _drawHorizontalBar(
        canvas, 
        startX, 
        startY, 
        barWidth, 
        16, 
        Palette.vermelho, 
        enemies[i].hp / enemies[i].maxHp
      );

      // 4. Desenha o Texto
      final textPainter = TextPainter(
        text: TextSpan(
          text: I18n.t(enemies[i].name).toUpperCase(),
          style: const TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 14, fontWeight: FontWeight.bold)
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Melhoria: Usando o 'textPainter.width' o texto fica perfeitamente centralizado na barra!
      double textX = startX + (barWidth / 2) - (textPainter.width / 2);
      
      textPainter.paint(canvas, Offset(textX, startY));

      displayIndex++;
    }
  }

  void _drawHorizontalBar(Canvas canvas, double x, double y, double w, double h, Color c, double r) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(x, y, w * r.clamp(0.0, 1.0), h), Paint()..color = c);
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
  }

}