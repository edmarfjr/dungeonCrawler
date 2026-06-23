import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:dungeon_crawler/game/components/entities/player_projectile.dart';
import 'package:dungeon_crawler/game/components/entities/bounce_projectile.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

  
enum ItemType { weapon, armor, shield, consumable, spell }

class Item {
  final String name;
  final ItemType type;
  final String imagePath; 
  final double power; 
  final Color cor;
  final int manaCost;
  int quantity;

  final bool hasReach;
  final bool hasStun;
  final bool noShield;
  final bool hasChargeAttack;
  final bool hasPoisonAttack;
  final bool walkSlow;
  final bool walkFast;
  final bool easyDash;
  final bool hasRegen;

  final void Function(Item item, DungeonCrawlerGame game)? onUse;

  Item(this.name, this.type, this.imagePath, this.power, {
    this.quantity = 1, 
    this.onUse, 
    this.cor = Palette.branco, 
    this.manaCost = 0, 
    this.hasReach = false, 
    this.hasStun = false,
    this.noShield = false,
    this.hasChargeAttack = false,
    this.hasPoisonAttack = false,
    this.walkSlow = false,
    this.walkFast = false,
    this.easyDash = false,
    this.hasRegen = false,
  });
}

class ItemDatabase {
  static Item get adaga => Item("Adaga", ItemType.weapon, 'itens/dagger.png', 5, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.05;
    game.playerCombatStats.staminaCost = 3.0;
    game.playerCombatStats.critChance = 10;
    game.playerCombatStats.critMultiplier = 2;
  });

  static Item get espadaCurta => Item("Espada Curta", ItemType.weapon, 'itens/sword.png', 7, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 3.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
  });

  static Item get espadaLonga => Item("Espada Longa", ItemType.weapon, 'itens/longSword.png', 15, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 4.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 2;
  });

  static Item get lanca => Item("Lança", ItemType.weapon, 'itens/lanca.png', 12, cor: Colors.white, hasReach: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 4.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
  });

  static Item get espadaOrc => Item("Espada Orc", ItemType.weapon, 'itens/orcSword.png', 12, cor: Colors.white, hasStun: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 4.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
  });

  static Item get machado => Item("Machado", ItemType.weapon, 'itens/axe.png', 20, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 5.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.2;
  });

  static Item get clava => Item("Clava", ItemType.weapon, 'itens/club.png', 20, cor: Colors.white, hasStun: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 5.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.2;
  });

  static Item get tanga => Item("Tanga", ItemType.armor, 'itens/tanga.png', 0,easyDash: true, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 5.0;
  });

  static Item get armaduraCouro => Item("Armadura de Couro", ItemType.armor, 'itens/leatherArmor.png', 2, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 0.0;
  });

  static Item get armaduraFerro => Item("Armadura de Ferro", ItemType.armor, 'itens/armor.png', 4, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = -10.0;
  });

  static Item get armaduraBug => Item("Armadura de Carapaça", ItemType.armor, 'itens/armorBug.png', 2,hasPoisonAttack:true, hasRegen:true, easyDash: true, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 0.0;
  });

  static Item get bloquel => Item("Bloquel", ItemType.shield, 'itens/buckler.png', 3, cor: Colors.white, onUse: (item, game) {
    //game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoMadeira => Item("Escudo de Madeira", ItemType.shield, 'itens/woodShield.png', 3, cor: Colors.white, onUse: (item, game) {
    //game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoFerro => Item("Escudo de Ferro", ItemType.shield, 'itens/ironShield.png', 5, walkSlow: true, cor: Colors.white, onUse: (item, game) {
    //game.playerCombatStats.moveSpeedPenalty = 0.5;
  });

  static Item get braceleteNaga => Item("Bracelete Naga", ItemType.shield, 'itens/bracerNaga.png', 5, walkFast: true, easyDash: true ,noShield: true, hasChargeAttack: true, cor: Colors.white, onUse: (item, game) {

  });

  static Item get braceleteFung => Item("Bracelete Fungico", ItemType.shield, 'itens/bracerFung.png', 5, walkFast: true, easyDash: true, noShield: true, hasPoisonAttack: true, cor: Colors.white, onUse: (item, game) {

  });

  static Item get healthPotion => Item("Poção Vermelha", ItemType.consumable, 'itens/potionVermelha.png', cor: Colors.white, 40, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.vermelho;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de HP!");
    //}
  });

  static Item get meat => Item("Carne", ItemType.consumable, 'itens/meat.png', cor: Colors.white, 10, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.vermelho;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de HP!");
    //}
  });

  static Item get manaPotion => Item("Poção Azul", ItemType.consumable, 'itens/potionAzul.png', cor: Colors.white, 100, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.mana = min(game.playerCombatStats.wis*3, game.playerCombatStats.mana + item.power);
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.azul;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de Mana!");
    //}
  });

  static Item get staminaPotion => Item("Poção Verde", ItemType.consumable, 'itens/potionVerde.png', cor: Colors.white, 50, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.cansado = false;
    game.playerCombatStats.stamina = game.playerCombatStats.con*3;
    game.playerCombatStats.staminaInfiniteTmr = 6;
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.verdeCla;
    game.showMessage("Você recuperou todo seu fôlego!");
    //if (game.currentState == GameState.exploration) {
   // game.showMessage("Você recuperou ${item.power} de Stamina!");
    //}
  });

  static Item get reflexPotion => Item("Poção Amarela", ItemType.consumable, 'itens/potionAmarela.png', cor: Colors.white, 50, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.reflex = true;
    game.showMessage("Você se sente mais ágil!");
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.amarelo;
    //if (game.currentState == GameState.exploration) {
   // game.showMessage("Você recuperou ${item.power} de Stamina!");
    //}
  });

  static Item get bugOrgan => Item("Orgão de inseto", ItemType.consumable, 'itens/organ.png', cor: Colors.white, 50, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.poisonTmr = 0;
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.vermelhoCla;
    game.showMessage("Você se sente melhor!");
    //if (game.currentState == GameState.exploration) {
   // game.showMessage("Você recuperou ${item.power} de Stamina!");
    //}
  });

  static Item get bomb => Item("Bomba", ItemType.consumable, 'itens/bomb.png', cor: Colors.white, 30, quantity: 1, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde isso para usar durante as batalhas!");
      item.quantity++;
      return;
    }
    FlameAudio.play('sfx/fire.wav');
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.laranja;
    for (var enemy in game.combatOverlay.enemies) {
      if (enemy.isAlive) { 
        enemy.hp -= item.power; 
        enemy.applyHitStun(0.4); 
        if (enemy.hp <= 0) { 
          enemy.hp = 0; 
          enemy.isDying = true; 
          game.encounterEssence += enemy.dropEssence; 
          game.encounterDrop.addAll(enemy.drop);
        } 
      }
    }
  });

  static Item get web => Item("Teia de aranha", ItemType.consumable, 'itens/web.png', cor: Colors.white, 0, quantity: 1, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde isso para usar durante as batalhas!");
      item.quantity++;
      return;
    }
    //FlameAudio.play('sfx/fire.wav');
    game.playerCombatStats.VfxTimer = 0.5;
    game.playerCombatStats.VfxColor = Palette.branco;
    for (var enemy in game.combatOverlay.enemies) {
      if (enemy.isAlive) { 
        enemy.applyHitStun(0.8); 
      }
    }
  });

  static Item get faca => Item("Faca de arremeço", ItemType.consumable, 'itens/faca.png', cor: Colors.white, 3, quantity: 1, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde isso para usar durante as batalhas!");
      item.quantity++;
      return;
    }
    FlameAudio.play('sfx/hit.wav');
   // game.playerCombatStats.explosionVfxTimer = 0.5;
    Enemy enemy = game.combatOverlay.enemies[Random().nextInt(game.combatOverlay.enemies.length)];
    if (!enemy.isAlive) {
      while(!enemy.isAlive){
        enemy = game.combatOverlay.enemies[Random().nextInt(game.combatOverlay.enemies.length)];
      }
    }
    else { 
      enemy.hp -= item.power + game.playerCombatStats.str.toDouble(); 
      enemy.applyHitStun(0.4); 
      if (enemy.hp <= 0) { 
        enemy.hp = 0; 
        enemy.isDying = true; 
        game.encounterEssence += enemy.dropEssence; 
        game.encounterDrop.addAll(enemy.drop);
      } 
    }
  });

  
  static Item get slimeEye => Item("Olho de Slime", ItemType.consumable, 'itens/slime_eye.png', 3, quantity: 1, cor: Colors.white, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde isso para usar durante as batalhas!");
      item.quantity++;
      return;
    }
    double scale = game.size.x * 0.35; 
    double playerPixelX = (game.size.x / 2) + (game.playerCombatStats.strafePosition * scale);
    
    Vector2 launchPos = Vector2(playerPixelX, game.size.y * 0.70);

    double randomAngleOffsetX = (Random().nextDouble() * 0.4) - 0.2; 
    double projectileSpeed = 550.0; 
    Vector2 initialVelocity = Vector2(randomAngleOffsetX, -1.0).normalized() * projectileSpeed;

    double calculatedDamage = item.power + game.playerCombatStats.str.toDouble();

    final ui.Image img = await game.images.load('effects/slime_eye.png');
    game.combatOverlay.add(SlimeEyeProjectile(
      startPosition: launchPos, 
      velocity: initialVelocity,
      damage: calculatedDamage,
      img: img,
    ));
  });

  static Item get firePillar => Item("Pilar de Fogo", ItemType.spell, 'itens/fire.png', 5, manaCost: 15, cor: Colors.white, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde a sua mana para as batalhas!");
      game.playerCombatStats.mana += item.manaCost; // Devolve a mana!
      return;
    }

    final ui.Image img = await game.images.load('effects/fire.png');
    FlameAudio.play('sfx/fire.wav');
    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 1.0, 1.5, item.power*game.playerCombatStats.wis, Colors.white, width: 80, height: 180
       ,img : img, isFlip: true
    ));
  });

  static Item get piercingShot => Item("Tiro Perfurante", ItemType.spell, 'itens/piercing.png', 4, manaCost: 10, cor: Colors.white, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde a sua mana para as batalhas!");
      game.playerCombatStats.mana += item.manaCost; // Devolve a mana!
      return;
    }
    final ui.Image img = await game.images.load('effects/piercing.png');
    FlameAudio.play('sfx/charge.wav');
    game.combatOverlay.add(PlayerProjectile(
      game.playerCombatStats.strafePosition, 0.0, 2.5, item.power*game.playerCombatStats.wis, Colors.white, yDir: 1, isPiercing: true, width: 40, height: 180
      ,img : img
    ));
  });

  static Item get toxicCloud => Item("Nuvem Tóxica", ItemType.spell, 'itens/poison.png', 1, manaCost: 15, cor: Palette.verde, onUse: (item, game) async {
    if (game.currentState != GameState.combat) { game.playerCombatStats.mana += item.manaCost; return; }
    FlameAudio.play('sfx/poison.wav');
    final ui.Image img = await game.images.load('effects/poison.png');
    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 0.7, 0, item.power*game.playerCombatStats.wis, Palette.verde.withAlpha(180), width: 80, height: 180
      , isPiercing: true,hitCooldown: 0.5,img : img, isFlip: true
    ));
  });
}