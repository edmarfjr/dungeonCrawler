import 'dart:ui' as ui;
import 'dart:math';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/combat_entities.dart';
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


  Map<EnemyType, EnemyAnimationSet> enemyAnimationSets = {}; 
  Map<Enemy, SpriteAnimationTicker> enemyTickers = {};       
  Map<Enemy, CombatPhase> enemyLastPhase = {};      

  final ui.Image playerSlashImage;
  ui.Image weaponSheetImage; 
  ui.Image armorSheetImage; 
  final Map<EnemyType, ui.Image> enemySlashImages;         

  List<Enemy> enemies = [];
  double _walkTimer = 0.0;

  CombatOverlay({
    required this.playerStats, 
    required this.playerSheetImage, 
    required this.enemySheets, 
    required this.playerSlashImage, 
    required this.weaponSheetImage, 
    required this.armorSheetImage, 
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

  void equipNewWeapon(ui.Image newWeaponImage) {
    weaponSheetImage = newWeaponImage; 
    _initWeaponAnimations();           
  }

  void equipNewArmor(ui.Image newArmorImage) {
    armorSheetImage = newArmorImage; 
    _initArmorAnimations();           
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

  void startEncounter(List<Enemy> newEnemies) {
    enemies = newEnemies; enemyTickers.clear(); enemyLastPhase.clear(); playerStats.strafePosition = 0.0; playerIdleTicker.reset();
  }

  SpriteAnimationTicker _getTickerForEnemy(Enemy enemy) {
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
    if (gameRef.currentState != GameState.combat) return;
    
    playerStats.updatePhase(dt);
    if (playerStats.currentPhase == CombatPhase.walk) _walkTimer += dt;
    _updateAnimationTimers(dt);
  }

  void _updateAnimationTimers(double dt) {
    if (playerStats.hitFlashTimer > 0) {
      playerHitTicker.update(dt);
      weaponHitTicker.update(dt); 
    } else {
      switch (playerStats.currentPhase) {
        case CombatPhase.idle: playerIdleTicker.update(dt); weaponIdleTicker.update(dt); break;
        case CombatPhase.walk: playerWalkTicker.update(dt); weaponWalkTicker.update(dt); break;
        case CombatPhase.windup: playerAttackWindupTicker.update(dt); weaponAttackWindupTicker.update(dt); break;
        case CombatPhase.active: playerAttackActiveTicker.update(dt); weaponAttackActiveTicker.update(dt); break;
        case CombatPhase.recovery: playerAttackRecoveryTicker.update(dt); weaponAttackRecoveryTicker.update(dt); break;
        case CombatPhase.guard: playerGuardTicker.update(dt); weaponGuardTicker.update(dt); break;
        case CombatPhase.hit: break; 
        case CombatPhase.entering: 
        case CombatPhase.exiting: playerIdleTicker.update(dt); weaponIdleTicker.update(dt); break;
      }
    }
    for (var enemy in enemies) { 
      if (enemy.hitFlashTimer <= 0) {
        _getTickerForEnemy(enemy).update(dt); 
      }
    }
  }

  void applyEnemyDamage(Enemy enemy) {
    double defense = playerStats.equippedArmor?.power ?? 0; // Armadura reduz dano!
    double dmg = max(1, enemy.damage - defense);
    if (playerStats.isGuarding) {
      if (playerStats.stamina >= 25.0) { 
        playerStats.stamina -= 25.0; 
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
    if (gameRef.currentState == GameState.combat) {
      if (enemies.isNotEmpty) {
        _drawEnemy(canvas);
      }
      _drawAttackEffects(canvas);
      _drawPlayer(canvas);
      
      if (gameRef.showHitboxes) _drawDebugBoxes(canvas);
      
      _drawPlayerUI(canvas);
      _drawBottomBarBackground(canvas);
      if (enemies.isNotEmpty) _drawEnemyUI(canvas); 
      
      _drawVictoryMessage(canvas);
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

      for (var proj in enemy.projectiles) {
        if (!proj.isActive) continue;

        Paint projPaint = Paint();
        projPaint.colorFilter =  ColorFilter.mode(enemy.color, BlendMode.modulate); 
      
        final projImg = enemySlashImages[enemy.type] ?? enemySlashImages[EnemyType.slime]!;
       
        //canvas.drawCircle(proj.getHitbox(size).center, 15, projPaint);
        //canvas.drawCircle(proj.getHitbox(size).center, 8, Paint()..color = Colors.white);
        canvas.drawImageRect(
          projImg,
          Rect.fromLTWH(0, 0, projImg.width.toDouble(), projImg.height.toDouble()),
          proj.getHitboxImageSize(size),
          projPaint 
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

      for (var proj in enemy.projectiles) {
        Color pColor = proj.isFalling ? Colors.red : Colors.yellow;
        canvas.drawRect(proj.getHitbox(size), Paint()..color = pColor.withOpacity(0.4)..style = PaintingStyle.fill);
        canvas.drawRect(proj.getHitbox(size), Paint()..color = pColor..style = PaintingStyle.stroke..strokeWidth = 2);
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

      SpriteAnimationTicker activeTicker = _getTickerForEnemy(enemy);
      final Color flashColor = enemy.hitFlashTimer > 0 ? enemy.flashColor : enemy.color;
      final BlendMode blendMode = BlendMode.modulate;//enemy.hitFlashTimer > 0 ? BlendMode.srcATop : BlendMode.modulate;

      final tintPaint = Paint()..colorFilter = ColorFilter.mode(flashColor, blendMode);

      activeTicker.getSprite().renderRect(canvas, dstRect, overridePaint: tintPaint);
    }
  }

  void _drawPlayer(Canvas canvas) {
    double playerWidth = 196; double playerHeight = 196;
    double yOffset = 0; double duration = 0.5;

    if (playerStats.currentPhase == CombatPhase.walk) { yOffset = (sin(_walkTimer * 12) * 4).abs() * -1; } 
    else if (playerStats.currentPhase == CombatPhase.entering) { yOffset = playerHeight * (1.0 - ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0)); } 
    else if (playerStats.currentPhase == CombatPhase.exiting) { yOffset = playerHeight * ((duration - playerStats.animTimer) / duration).clamp(0.0, 1.0); }

    double xPixel = (size.x / 2) + (playerStats.strafePosition * size.x * 0.35) - (playerWidth / 2);
    final dstRect = Rect.fromLTWH(xPixel, size.y - 70 - playerHeight + yOffset, playerWidth, playerHeight);

    SpriteAnimationTicker activeTicker;
    SpriteAnimationTicker activeWeaponTicker; 
    SpriteAnimationTicker activeArmorTicker;

    switch (playerStats.currentPhase) {
      case CombatPhase.windup: activeTicker = playerAttackWindupTicker; activeWeaponTicker = weaponAttackWindupTicker; activeArmorTicker = armorAttackWindupTicker; break;
      case CombatPhase.active: activeTicker = playerAttackActiveTicker; activeWeaponTicker = weaponAttackActiveTicker; activeArmorTicker = armorAttackActiveTicker; break;
      case CombatPhase.recovery: activeTicker = playerAttackRecoveryTicker; activeWeaponTicker = weaponAttackRecoveryTicker; activeArmorTicker = armorAttackRecoveryTicker; break;
      case CombatPhase.guard: activeTicker = playerGuardTicker; activeWeaponTicker = weaponGuardTicker; activeArmorTicker = armorGuardTicker; break;
      case CombatPhase.walk: activeTicker = playerWalkTicker; activeWeaponTicker = weaponWalkTicker; activeArmorTicker = armorWalkTicker; break;
      case CombatPhase.hit: activeTicker = playerHitTicker; activeWeaponTicker = weaponHitTicker; activeArmorTicker = armorHitTicker; break;
      default: activeTicker = playerIdleTicker; activeWeaponTicker = weaponIdleTicker; activeArmorTicker = armorIdleTicker; break;
    }

    final playerPaint = Paint();
    //playerPaint.colorFilter = const ColorFilter.mode(Palette.bege, BlendMode.modulate); 

    final weaponPaint = Paint();
    weaponPaint.colorFilter = ColorFilter.mode(playerStats.weaponColor, BlendMode.modulate); 
    
    final armorPaint = Paint();
    armorPaint.colorFilter =  ColorFilter.mode(playerStats.armorColor, BlendMode.modulate); 

    if (playerStats.hitFlashTimer > 0) { 
      playerPaint.colorFilter = const ColorFilter.mode(Palette.vermelho, BlendMode.modulate); 
      weaponPaint.colorFilter = const ColorFilter.mode(Palette.vermelho, BlendMode.modulate); // Adicionado para a arma piscar junto
      armorPaint.colorFilter = const ColorFilter.mode(Palette.vermelho, BlendMode.modulate); // Adicionado para a armadura piscar junto
    }
    
    // 1. Desenha o Corpo
    activeTicker.getSprite().renderRect(canvas, dstRect, overridePaint: playerPaint);
    
    // 2. Desenha a Arma
    activeWeaponTicker.getSprite().renderRect(canvas, dstRect, overridePaint: weaponPaint);
    
    // 3. Desenha a Armadura
    activeArmorTicker.getSprite().renderRect(canvas, dstRect, overridePaint: armorPaint);
  }

  void _drawPlayerUI(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 60), Paint()..color = Palette.preto.withOpacity(0.9));
    double barWidth = (size.x - 40) / 3;
    _drawHorizontalBar(canvas, 10, 15, barWidth, 12, Palette.vermelho, playerStats.hp / playerStats.maxHp);
    _drawHorizontalBar(canvas, 10, 30, barWidth, 12, Palette.verde, playerStats.stamina / playerStats.maxStamina);
    _drawHorizontalBar(canvas, 10, 45, barWidth, 12, Palette.azul, playerStats.mana / playerStats.maxMana);
    if (gameRef.selectedConsumableIndex < playerStats.consumables.length) {
      Item sel = playerStats.consumables[gameRef.selectedConsumableIndex];
      double boxX = size.x - 70;
      double boxY = 5;

      // Desenha a caixa de fundo
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, 60, 50), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(boxX, boxY, 60, 50), Paint()..color = Palette.cinzaCla..style = PaintingStyle.stroke);
      try {
        ui.Image itemImg = gameRef.images.fromCache(sel.imagePath);
        
        // Aplica a cor definida na variável do Item
        final tintPaint = Paint()..colorFilter = ColorFilter.mode(sel.cor, BlendMode.modulate);
        
        canvas.drawImageRect(
          itemImg,
          Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()),
          Rect.fromLTWH(boxX + 15, boxY + 2, 30, 30), 
          tintPaint // <--- Usa o paint com cor aqui!
        );
      } catch (e) {
        // Se a imagem não for encontrada, não quebra o jogo
      }

      TextPainter(
        text: TextSpan(text: '${sel.quantity}x', style: const TextStyle(color: Palette.branco, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(size.x - 65, 35));
      TextPainter(
        text: const TextSpan(text: 'Uso[B]', style: TextStyle(color: Palette.amarelo, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(size.x - 65, 8));
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