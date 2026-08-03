import 'dart:ui' as ui;
import 'dart:math';
import 'package:a_blade_in_the_abyss/game/components/Effects/buff_particles.dart';
import 'package:a_blade_in_the_abyss/game/components/core/dungeon_map.dart';
import 'package:a_blade_in_the_abyss/game/components/core/i18n.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/components/entities/combat_entities.dart';
import 'package:a_blade_in_the_abyss/game/components/Effects/floating_text.dart';
import 'package:a_blade_in_the_abyss/game/components/entities/enemy.dart';
import 'package:a_blade_in_the_abyss/game/components/entities/item.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
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
  bool isDesktopLayout = false;
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

  // ============================================================================
  // === ESCALA VIRTUAL E VIEWPORT (O SEGREDO DA MOLDURA E ALINHAMENTO) ===
  // ============================================================================
  
  double get scaleFactor => gameRef.isDesktopLayout 
      ? (size.y / 720.0).clamp(0.1, 5.0) 
      : (size.x / 500.0).clamp(0.1, 5.0);

  double get logicalWidth => size.x / scaleFactor;
  double get logicalHeight => size.y / scaleFactor;
  Vector2 get logicalSize => Vector2(logicalWidth, logicalHeight);

  // Define a área central livre onde o jogo 3D e combate acontecem
  Rect get viewportRect {
    if (gameRef.isDesktopLayout) {
      double panelWidth = 260.0;
      return Rect.fromLTWH(panelWidth, 0, logicalWidth - (panelWidth * 2), logicalHeight);
    } else {
      double topHudHeight = 76.0;
      double bottomHudHeight = 76.0;
      return Rect.fromLTWH(0, topHudHeight, logicalWidth, logicalHeight - topHudHeight - bottomHudHeight);
    }
  }

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
        double px = (logicalWidth / 2) + (playerStats.strafePosition * viewportRect.width * 0.35) + (Random().nextDouble() * 100 - 50);
        // O py acompanha a compensação de D2 do jogador
        double py = logicalHeight - 110 - (Random().nextDouble() * 50);
        add(BuffParticle(px, py, 40 + Random().nextDouble() * 60, 0.8 + Random().nextDouble()));
      }
    }

    if (playerStats.buffForcaTmr > 0 && gameRef.currentState == GameState.combat) {
      if (Random().nextDouble() < 0.3) { 
        double px = (logicalWidth / 2) + (playerStats.strafePosition * viewportRect.width * 0.35) + (Random().nextDouble() * 100 - 50);
        double py = logicalHeight - 110 - (Random().nextDouble() * 50);
        add(BuffParticle(px, py, 40 + Random().nextDouble() * 60, 0.8 + Random().nextDouble(),cor:Palette.cinzaMed));
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
    // === 1. MÁGICA DA ESCALA GLOBAL ===
    canvas.save();
    canvas.scale(scaleFactor, scaleFactor);

    render(canvas); 

    // ====================================================================
    // === 2. MÁSCARA DO VIEWPORT E ALINHAMENTO DO CHÃO DOS ATORES ===
    // ====================================================================
    canvas.save();
    canvas.clipRect(viewportRect); 
    
    // Ajuste D1: Adicionamos +25.0 pixels para descer os inimigos levemente, 
    // afundando eles um pouco para trás da HUD (profundidade de campo)
    double actorOffsetY = viewportRect.bottom - logicalHeight + 65.0;
    canvas.translate(0, actorOffsetY);

    if (gameRef.currentState == GameState.combat && gameRef.isBoss && gameRef.dungeon.level == 12) {
        canvas.drawRect(Rect.fromLTWH(0, 0, logicalWidth, logicalHeight), Paint()..color = Palette.preto);
    }

    for (var child in children) {
      if (child.runtimeType.toString() != 'BuffParticle') {
        child.renderTree(canvas);
      }
    }

    if (gameRef.currentState == GameState.combat) {
      _drawAttackEffects(canvas);
      _drawPlayer(canvas);
      if (gameRef.showHitboxes) _drawDebugBoxes(canvas);
    }

    for (var child in children) {
      if (child.runtimeType.toString() == 'BuffParticle') {
        child.renderTree(canvas);
      }
    }

    canvas.restore(); 

    // ====================================================================
    // === 3. DESENHO DAS BORDAS / HUD (Desenhadas por cima de tudo) ===
    // ====================================================================
    if (gameRef.isDesktopLayout) {
      _drawDesktopHUD(canvas);
    } else {
      _drawBottomBarBackground(canvas);
      _drawPlayerUI(canvas);
      if (gameRef.currentState == GameState.combat) _drawEnemyUI(canvas);
    }

    _drawEffects(canvas);
    
    canvas.restore();
  }

  void _drawEffects(Canvas canvas) {
    if (playerStats.vfxTimer > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, logicalWidth, logicalHeight), Paint()..color = playerStats.vfxColor.withOpacity(playerStats.vfxTimer.clamp(0.0, 0.5)));
    }
  }

  void _drawAttackEffects(Canvas canvas) {
    canvas.save();
    canvas.translate(0, -60.0); // Ajuste D2 para elevar o Efeito de Ataque

    if (playerStats.currentPhase == CombatPhase.active) {
      int slashIdx = 0;
      bool wide = playerStats.equippedWeapon?.isWide ?? false;
      if (wide) slashIdx = 1;
      
      // Rescale correto (Tamanho Gigante) usando viewportRect
      double baseSizeMultiplier = (viewportRect.width / 500.0).clamp(0.5, 3.0);
      double playerCX = (logicalWidth / 2) + (playerStats.strafePosition * viewportRect.width * 0.35);
      
      Rect attackRect = Rect.fromCenter(
        center: Offset(playerCX, logicalHeight - 65 - ((196 * baseSizeMultiplier) / 2)),
        width: 120 * baseSizeMultiplier,
        height: 120 * baseSizeMultiplier
      );

      canvas.drawImageRect(
        playerSlashImage[slashIdx],
        Rect.fromLTWH(0, 0, playerSlashImage[slashIdx].width.toDouble(), playerSlashImage[slashIdx].height.toDouble()),
        attackRect, 
        Paint()
      );
    }
    canvas.restore();

    for (var enemy in enemies) {
      if (!enemy.isAlive) continue;
      
      if ((enemy.currentPhase == CombatPhase.active || enemy.currentPhase == CombatPhase.active2)&& enemy.getHitbox(logicalSize).width > 0 && enemy.isMelee) {
        final slashImg = enemySlashImages[enemy.type] ?? enemySlashImages[EnemyType.slime]!;
        final slashPaint = Paint();
        canvas.drawImageRect(
          slashImg,
          Rect.fromLTWH(0, 0, slashImg.width.toDouble(), slashImg.height.toDouble()),
          enemy.getHitboxImageSize(logicalSize),
          slashPaint 
        );
      }
    }
  }

  void _drawBottomBarBackground(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, logicalHeight - logicalHeight*0.145, logicalWidth, logicalHeight*0.145), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(-2, logicalHeight - logicalHeight*0.145 - 3, logicalWidth+4, (logicalHeight*0.145) + 1), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 4);
  }

  Rect getPlayerHurtbox() {
    double baseSizeMultiplier = (viewportRect.width / 500.0).clamp(0.5, 3.0);
    double playerCX = (logicalSize.x / 2) + (playerStats.strafePosition * viewportRect.width * 0.35);
    double playerCY = logicalSize.y - ((196 * baseSizeMultiplier) / 2) - 50.0 ; 

    if(isDesktopLayout) playerCY += 50;

    return Rect.fromCenter(
      center: Offset(playerCX, playerCY),
      width: 60 * baseSizeMultiplier, 
      height: 130 * baseSizeMultiplier
    );
  }

  Rect getPlayerHitbox() {
    double baseSizeMultiplier = (viewportRect.width / 500.0).clamp(0.5, 3.0);
    double playerCX = (logicalSize.x / 2) + (playerStats.strafePosition * viewportRect.width * 0.35);
    double playerCY = logicalSize.y - 65 - ((196 * baseSizeMultiplier) / 2) - 60.0; 
    
    bool wide = playerStats.equippedWeapon?.isWide ?? false;
    double hitWidth = wide ? 120.0 : 60.0;
    
    return Rect.fromCenter(
      center: Offset(playerCX, playerCY),
      width: hitWidth * baseSizeMultiplier, 
      height: 80 * baseSizeMultiplier
    );
  }

  void _drawDebugBoxes(Canvas canvas) {
    for (var enemy in enemies) {
      final eHurtbox = enemy.getHurtbox(logicalSize);
      canvas.drawRect(eHurtbox, Paint()..color = Colors.green.withOpacity(0.4)..style = PaintingStyle.fill);
      canvas.drawRect(eHurtbox, Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 2);
      
      if (enemy.currentPhase == CombatPhase.active && enemy.getHitbox(logicalSize).width > 0) {
        final eHitbox = enemy.getHitbox(logicalSize);
        canvas.drawRect(eHitbox, Paint()..color = Colors.red.withOpacity(0.4)..style = PaintingStyle.fill);
        canvas.drawRect(eHitbox, Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
    
    // Agora usamos as caixas geradas perfeitamente alinhadas com o visual!
    Rect pHurtbox = getPlayerHurtbox();
    canvas.drawRect(pHurtbox, Paint()..color = Colors.blueAccent.withOpacity(0.4)..style = PaintingStyle.fill);
    canvas.drawRect(pHurtbox, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2);
    
    if (playerStats.currentPhase == CombatPhase.active) {
      Rect pHitbox = getPlayerHitbox();
      canvas.drawRect(pHitbox, Paint()..color = Colors.orange.withOpacity(0.4)..style = PaintingStyle.fill);
      canvas.drawRect(pHitbox, Paint()..color = Colors.orange..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  void _drawPlayer(Canvas canvas) {
    if (playerStats.invencibleTmr>0 && (playerStats.invencibleTmr * 15).toInt() % 2 == 0) return;
    
    // Rescale Correto garantindo que não fique gigante (viewportRect)
    double baseSizeMultiplier = (viewportRect.width / 500.0).clamp(0.5, 3.0);
    double playerWidth = 196 * baseSizeMultiplier; 
    double playerHeight = 196 * baseSizeMultiplier;
    double yOffset = 0; double duration = 0.5;

    if (playerStats.currentPhase == CombatPhase.walk) { yOffset = -(sin(_walkTimer * 12) * 4).abs() * -1; } 
    else if (playerStats.currentPhase == CombatPhase.entering) { yOffset = playerHeight * (1.0 - ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0)); } 
    else if (playerStats.currentPhase == CombatPhase.exiting) { yOffset = playerHeight * ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0); }

    double xPixel = (logicalWidth / 2) + (playerStats.strafePosition * viewportRect.width * 0.35) - (playerWidth / 2);
    
    canvas.save();
    if(!isDesktopLayout)canvas.translate(0, -15.0); 

    final dstRect = Rect.fromLTWH(xPixel, logicalHeight - 65 - playerHeight + yOffset, playerWidth, playerHeight);
    final dstRectWeapon = Rect.fromLTWH(xPixel, logicalHeight - 65 - playerHeight + yOffset - playerStats.offYWeapon, playerWidth, playerHeight);

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

    Color corArma = playerStats.equippedWeapon?.cor ?? Colors.white;
    Color corArmadura = playerStats.equippedArmor?.cor ?? Colors.white;
    Color corEscudo = playerStats.equippedShield?.cor ?? Colors.white;

    final weaponPaint = Paint();
    weaponPaint.colorFilter = ColorFilter.mode(corArma, BlendMode.modulate); 
    
    final armorPaint = Paint();
    armorPaint.colorFilter =  ColorFilter.mode(corArmadura, BlendMode.modulate); 

    final shieldPaint = Paint();
    shieldPaint.colorFilter =  ColorFilter.mode(corEscudo, BlendMode.modulate); 

    if (playerStats.flashTimer > 0) { 
      playerPaint.colorFilter =  ColorFilter.mode(playerStats.flashColor, BlendMode.modulate); 
    }
    if(playerStats.cansado) {
      playerPaint.colorFilter = const ColorFilter.mode(Palette.marromCla, BlendMode.modulate); 
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

    canvas.restore();
  }

  // ============================================================================
  // FUNÇÕES DE TEXTO E DESENHO DE BARRAS
  // ============================================================================

  void _drawText(Canvas canvas, String text, double x, double y, double fontSize, Color color, {bool alignCenter = false}) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontFamily: 'pixelFont', color: color, fontSize: fontSize, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    double drawX = alignCenter ? x - (textPainter.width / 2) : x;
    textPainter.paint(canvas, Offset(drawX, y));
  }

  void _drawHorizontalBar(Canvas canvas, double x, double y, double w, double h, Color c, double r) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(x, y, w * r.clamp(0.0, 1.0), h), Paint()..color = c);
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawVerticalBar(Canvas canvas, double x, double y, double w, double h, Color c, double r) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(x, y, w , h * r.clamp(0.0, 1.0)), Paint()..color = c);
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  // ============================================================================
  // === HUD PC / WEB DESKTOP ===
  // ============================================================================
  void _drawDesktopHUD(Canvas canvas) {
    double panelWidth = 260.0;
    
    // --- PAINEL ESQUERDO (HERÓI) ---
    canvas.drawRect(Rect.fromLTWH(0, 0, panelWidth, logicalHeight), Paint()..color = Palette.preto); // Moldura
    canvas.drawRect(Rect.fromLTWH(4, -4, panelWidth-4, logicalHeight+8), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 8);
    
    _drawText(canvas, "ESSENCE: ${playerStats.essence}", panelWidth / 2, 30, 24, Palette.branco, alignCenter: true);
    canvas.drawRect(Rect.fromLTWH(0, -4, panelWidth-2, 69), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 4);
    _drawText(canvas, 'STR: ${playerStats.str}\nCON: ${playerStats.con}\nWIS: ${playerStats.wis}', panelWidth / 2, 70, 24, Palette.branco, alignCenter: true);
    canvas.drawRect(Rect.fromLTWH(0, -4, panelWidth-2, 169), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 4);


    // Barras de Status
    _drawText(canvas, "HP", 58, 170, 16, Palette.branco);
    _drawVerticalBar(canvas, 50, 190, 40, playerStats.maxHp * 4, Palette.vermelho, playerStats.hp / playerStats.maxHp);
    
    _drawText(canvas, "ST", 118, 170, 16, Palette.branco);
    _drawVerticalBar(canvas, 110, 190, 40, playerStats.con * 12, Palette.verdeCla, playerStats.stamina / (playerStats.con * 3));
    
    _drawText(canvas, "MP", 178, 170, 16, Palette.branco);
    _drawVerticalBar(canvas, 170, 190, 40, playerStats.wis * 12, Palette.azulCla, playerStats.mana / (playerStats.wis * 3));


    // Bússola e Chave na exploração
    if (gameRef.currentState == GameState.exploration) {
    
    }else{
      
      if(playerStats.reflex){
        _drawText(canvas, "REFLEXO ATIVO", panelWidth / 2, logicalHeight - 80, 14, Palette.amarelo, alignCenter: true);
      }
    }

    // --- PAINEL DIREITO (INIMIGOS / INFO) ---
    double rightX = logicalWidth - panelWidth;
    canvas.drawRect(Rect.fromLTWH(rightX, 0, panelWidth, logicalHeight), Paint()..color = Palette.preto); // Moldura
    canvas.drawRect(Rect.fromLTWH(rightX, -4, panelWidth-4, logicalHeight+8), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawRect(Rect.fromLTWH(rightX, -4, panelWidth-4, 225), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 4);
    if (gameRef.currentState == GameState.combat) {

        if (gameRef.selectedConsumableIndex < playerStats.consumables.length) {
        Item sel = playerStats.consumables[gameRef.selectedConsumableIndex];
        double bxSize = 150;
        double boxX = logicalWidth - (panelWidth / 2) - (bxSize / 2);
        double boxY = 40;
        
        canvas.drawRect(Rect.fromLTWH(boxX, boxY, bxSize, bxSize), Paint()..color = Palette.preto);
        try {
          ui.Image itemImg = gameRef.images.fromCache(sel.imagePath);
          final tintPaint = Paint()..colorFilter = ColorFilter.mode(sel.cor, BlendMode.modulate);
          canvas.drawImageRect(
            itemImg,
            Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()),
            Rect.fromLTWH(boxX, boxY, bxSize, bxSize), 
            tintPaint
          );
        } catch (e) {}
        canvas.drawRect(Rect.fromLTWH(boxX, boxY, bxSize, bxSize), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 8);

        String amountText = sel.type == ItemType.spell ? '${sel.manaCost} MP' : '${sel.quantity}x';
        _drawText(canvas, amountText, boxX + bxSize/2, boxY + bxSize + 10, 14, sel.type == ItemType.spell ? Palette.azul : Palette.branco, alignCenter: true);
      }

     // _drawText(canvas, "INIMIGOS", rightX + panelWidth / 2, 220, 24, Palette.vermelho, alignCenter: true);
      
      double startY = 230;
      for (var enemy in enemies) {
        if (!enemy.isAlive) continue;
        
        _drawText(canvas, I18n.t(enemy.name).toUpperCase(), rightX + panelWidth / 2, startY, 14, Palette.branco, alignCenter: true);
        _drawHorizontalBar(canvas, rightX + 20, startY + 20, panelWidth - 40, 16, Palette.vermelho, enemy.hp / enemy.maxHp);
        
        startY += 45;
      }
    } else {
      /*_drawText(canvas, "MUNDO", rightX + panelWidth / 2, 30, 24, Palette.amarelo, alignCenter: true);
      _drawText(canvas, "Andar: ${gameRef.dungeon.level}", rightX + panelWidth / 2, 80, 18, Palette.branco, alignCenter: true);
      
      _drawText(canvas, "Controles PC:", rightX + panelWidth / 2, 160, 16, Palette.cinzaCla, alignCenter: true);
      _drawText(canvas, "W,A,S,D - Mover / Girar", rightX + panelWidth / 2, 190, 12, Palette.branco, alignCenter: true);
      _drawText(canvas, "E / Espaço - Interagir", rightX + panelWidth / 2, 220, 12, Palette.branco, alignCenter: true);
      _drawText(canvas, "Q / Shift - Usar Item", rightX + panelWidth / 2, 250, 12, Palette.branco, alignCenter: true);
      */
       String direc = 'dir_n';
       switch (gameRef.player.facing) {
         case Direction.north: direc = 'dir_n'; break;
         case Direction.east:  direc = 'dir_l'; break;
         case Direction.south: direc = 'dir_s'; break;
         case Direction.west:  direc = 'dir_o'; break;
       }
       _drawText(canvas, "${I18n.t(direc).toUpperCase()}", logicalWidth -panelWidth / 2, 5, 20, Palette.branco, alignCenter: true);

       
       if (gameRef.player.hasKey) {
          double bxSize = 150;
          double keyX = logicalWidth -(panelWidth / 2) - (bxSize / 2);
          double keyY = logicalHeight - 260;
          try {
            canvas.drawImageRect(
              gameRef.keySprite, 
              Rect.fromLTWH(0, 0, gameRef.keySprite.width.toDouble(), gameRef.keySprite.height.toDouble()),
              Rect.fromLTWH(keyX, keyY, bxSize, bxSize),
              Paint()..colorFilter = const ColorFilter.mode(Palette.amarelo, BlendMode.modulate)
            );
          } catch (e) {}
          canvas.drawRect(Rect.fromLTWH(keyX, keyY, bxSize, bxSize), Paint()..color = Palette.amarelo..style = PaintingStyle.stroke..strokeWidth = 4);

       }
       
    }
  }

  // ============================================================================
  // === HUD MOBILE ===
  // ============================================================================

  void _drawPlayerUI(Canvas canvas) {
    // Fundo sólido garantido no Topo
    double boxHeight = logicalHeight*0.145+1;
    canvas.drawRect(Rect.fromLTWH(0, 0, logicalWidth, boxHeight), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(-2, 2, logicalWidth+4, boxHeight), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 4);
    
    _drawHorizontalBar(canvas, 10, 35, playerStats.maxHp * 3, 12, Palette.vermelho, playerStats.hp / playerStats.maxHp);
    _drawHorizontalBar(canvas, 10, 52, playerStats.con * 9, 12, Palette.verdeCla, playerStats.stamina / (playerStats.con * 3));
    _drawHorizontalBar(canvas, 10, 69, playerStats.wis * 9, 12, Palette.azulCla, playerStats.mana / (playerStats.wis * 3));
    
    //inventario
    if (gameRef.selectedConsumableIndex < playerStats.consumables.length && gameRef.currentState == GameState.combat) {
      Item sel = playerStats.consumables[gameRef.selectedConsumableIndex];
      double bxSize = 65;
      double boxX = logicalWidth - (bxSize + 1);
      double boxY = 1;
      
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, bxSize, bxSize), Paint()..color = Palette.preto);
      
      try {
        ui.Image itemImg = gameRef.images.fromCache(sel.imagePath);
        final tintPaint = Paint()..colorFilter = ColorFilter.mode(sel.cor, BlendMode.modulate);
        canvas.drawImageRect(
          itemImg,
          Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()),
          Rect.fromLTWH(boxX, boxY, bxSize, bxSize), 
          tintPaint
        );
      } catch (e) {}
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, bxSize, bxSize), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 4);

      String amountText = sel.type == ItemType.spell ? '${sel.manaCost} MP' : '${sel.quantity}x';
      
      TextPainter(
        text: TextSpan(text: amountText, style: TextStyle(fontFamily: 'pixelFont', color: sel.type == ItemType.spell ? Palette.azul : Palette.branco, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(boxX + bxSize/2 - amountText.length*3, bxSize + 5));
      
      if(playerStats.reflex){
        TextPainter(
          text: const TextSpan(text: 'REFLEX', style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout()..paint(canvas, Offset(logicalWidth-(bxSize*1.5)-'REFLEX'.length*10, 20));
      }

    }
    if (gameRef.currentState == GameState.exploration && gameRef.player.hasKey) {
      double bxSize = 55;
      double keyX = logicalWidth/2 + bxSize;
      double keyY = boxHeight/2 - bxSize/2;
      
      canvas.drawRect(Rect.fromLTWH(keyX, keyY, bxSize, bxSize), Paint()..color = Palette.preto);
      try {
        canvas.drawImageRect(
          gameRef.keySprite, 
          Rect.fromLTWH(0, 0, gameRef.keySprite.width.toDouble(), gameRef.keySprite.height.toDouble()),
          Rect.fromLTWH(keyX, keyY, bxSize, bxSize),
          Paint()..colorFilter = const ColorFilter.mode(Palette.branco, BlendMode.modulate)
        );
      } catch (e) {}
      canvas.drawRect(Rect.fromLTWH(keyX, keyY, bxSize, bxSize), Paint()..color = Palette.marromCla..style = PaintingStyle.stroke..strokeWidth = 4);
      
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
        )..layout()..paint(canvas, Offset(logicalWidth/2 - I18n.t(direc).length*6 , 5));

        double statusY = logicalHeight - logicalHeight*0.145/2 -35;

      String statusTxt = 'STR: ${playerStats.str}  CON: ${playerStats.con}  WIS: ${playerStats.wis}';
      String essenTxt = 'ESSENCE: ${playerStats.essence}';

      TextPainter(
            text: TextSpan(text: statusTxt, style: const TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 24)),
            textDirection: TextDirection.ltr,
          )..layout()..paint(canvas, Offset(logicalWidth/2 - statusTxt.length*7, statusY));

      TextPainter(
            text: TextSpan(text: essenTxt, style: const TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 24)),
            textDirection: TextDirection.ltr,
          )..layout()..paint(canvas, Offset(logicalWidth/2 - essenTxt.length*7, statusY + 40));

    }else{
      
    }

    

  }

  void _drawEnemyUI(Canvas canvas) {
    double margin = 15.0; 
    double gap = 10.0;  
    
    double barWidth = (logicalWidth - (margin * 2) - gap) / 2;

    int displayIndex = 0; 

    for (int i = 0; i < enemies.length; i++) {
      if (!enemies[i].isAlive) continue;

      if (displayIndex >= 8) break; 

      int col = displayIndex % 2;  
      int row = displayIndex ~/ 2; 

      double startX = margin + (col * (barWidth + gap));
      double startY = logicalHeight - 75 + 2 + (row * 18);

      _drawHorizontalBar(
        canvas, 
        startX, 
        startY, 
        barWidth, 
        16, 
        Palette.vermelho, 
        enemies[i].hp / enemies[i].maxHp
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: I18n.t(enemies[i].name).toUpperCase(),
          style: const TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 14, fontWeight: FontWeight.bold)
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      double textX = startX + (barWidth / 2) - (textPainter.width / 2);
      
      textPainter.paint(canvas, Offset(textX, startY));

      displayIndex++;
    }
  }
}