import 'dart:math';
import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/core/audio_manager.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:dungeon_crawler/game/components/entities/player_projectile.dart';
import 'package:dungeon_crawler/game/components/entities/bounce_projectile.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dungeon_crawler/game/components/core/i18n.dart';

  
enum ItemType { weapon, armor, shield, consumable, spell, coin, gem }

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
  final bool staminaSlowRegen;
  final bool isWide;
  final int value;
  final int str;
  final int peso;
  final bool projetil;
  String description;

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
    this.isWide = false,
    this.staminaSlowRegen = false,
    this.value = 1,
    this.str = 5,
    this.peso = 0,
    this.projetil = false,
    this.description = '',
  });
}

class ItemDatabase {
  static Item get adaga => Item('adaga', ItemType.weapon, 'itens/dagger.png', 5,description: 'd_adaga', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.05;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.05;
    game.playerCombatStats.staminaCost = 3.0;
    game.playerCombatStats.critChance = 10;
    game.playerCombatStats.critMultiplier = 2;
    game.playerCombatStats.offYWeapon = 0;
    
  });

  static Item get varinha => Item('varinha', ItemType.weapon, 'itens/varinha.png', 5,description: 'd_varinha',projetil:true, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 3.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get espadaCurta => Item('espada_curta', ItemType.weapon, 'itens/sword.png', 7,description: 'd_espada_curta',value:4, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.05;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 3.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get espadaMagica => Item('espada_magica', ItemType.weapon, 'itens/magicSword.png', 10,description: 'd_espada_magica',projetil:true,hasChargeAttack:true,value:20, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 8.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 3;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get espadaLonga => Item('espada_longa', ItemType.weapon, 'itens/longSword.png', 10,description: 'd_espada_longa', str:6,value:6, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 5.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 2;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get claymore => Item('claymore', ItemType.weapon, 'itens/claymore.png', str:8, 15,description: 'd_claymore',value:12,isWide: true ,cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 6.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.8;
    game.playerCombatStats.offYWeapon = 12;
  });

  static Item get zweihander => Item('zweihander', ItemType.weapon, 'itens/zweihander.png', str:15, 25,description: 'd_zweihander',value:16,isWide: true, hasReach: true ,cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.15;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 12.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 2;
    game.playerCombatStats.offYWeapon = 24;
  });

  static Item get lanca => Item('lanca', ItemType.weapon, 'itens/lanca.png', 9,description: 'd_lanca', cor: Colors.white, str:8, value:6, hasReach: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 5.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 2;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get espadaOrc => Item('espadaOrc', ItemType.weapon, 'itens/orcSword.png', 12,description: 'd_espadaOrc', cor: Colors.white, str:8,value:8, hasStun: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 4.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get machado => Item('machado', ItemType.weapon, 'itens/axe.png', 20,description: 'd_machado', value:16,isWide: true , cor: Colors.white, str:10, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 10.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 3.5;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get clava => Item('clava', ItemType.weapon, 'itens/club.png', 6,description: 'd_clava', cor: Colors.white,value:5, hasStun: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 4.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 2;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get clavaOrc => Item('clavaOrc', ItemType.weapon, 'itens/clubOrc.png', 10,description: 'd_clavaOrc', cor: Colors.white,value:4, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 6.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.2;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get warhammer => Item('warhammer', ItemType.weapon, 'itens/warhammer.png', 12,description: 'd_warhammer',value:14, str:10, hasStun: true, hasChargeAttack: true,cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 5.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 2.8;
    game.playerCombatStats.offYWeapon = 0;

  });

  static Item get tanga => Item('tanga', ItemType.armor, 'itens/tanga.png', 0,description: 'd_tanga',easyDash: true, cor: Colors.white, onUse: (item, game) {

  });

  static Item get armaduraCouro => Item('armaduraCouro', ItemType.armor, 'itens/leatherArmor.png', 5,description: 'd_armaduraCouro', peso:1, value:4, cor: Colors.white, onUse: (item, game) {

  });

  static Item get gambeson => Item('gambeson', ItemType.armor, 'itens/gambeson.png', 3,description: 'd_gambeson', peso:1, value:4, cor: Colors.white, onUse: (item, game) {

  });

  static Item get armaduraFerro => Item('armFerro', ItemType.armor, 'itens/armor.png',12,description: 'd_armFerro', peso:3,staminaSlowRegen:true,value:10, cor: Colors.white, onUse: (item, game) {

  });

  static Item get armaduraBronze => Item('armBronze', ItemType.armor, 'itens/bronzeArmor.png', 10,description: 'd_armBronze', peso:3,walkSlow: true,value:8, cor: Colors.white, onUse: (item, game) {

  });

   static Item get armaduraAco => Item('armAco', ItemType.armor, 'itens/steelArmor.png',15,description: 'd_armAco',value:12, peso:3, cor: Colors.white, onUse: (item, game) {

  });

  static Item get chainMail => Item('chainMail', ItemType.armor, 'itens/chainMail.png',7,description: 'd_chainMail',value:10, peso:2, cor: Colors.white, onUse: (item, game) {

  });

  static Item get armaduraBug => Item('armCarap', ItemType.armor, 'itens/armorBug.png',8,description: 'd_armCarap',value:10, peso:2,hasPoisonAttack:true, hasRegen:true, easyDash: true, cor: Colors.white, onUse: (item, game) {

  });

  static Item get bloquel => Item('bloquel', ItemType.shield, 'itens/buckler.png', 0,description: 'd_bloquel', cor: Colors.white, onUse: (item, game) {
    //game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoMadeira => Item('escudoMadeira', ItemType.shield, 'itens/woodShield.png', 2,description: 'd_escudoMadeira',value:4, cor: Colors.white, onUse: (item, game) {
    //game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoFerro => Item('escudoFerro', ItemType.shield, 'itens/ironShield.png', 4,value:6, description: 'd_escudoFerro',cor: Colors.white, onUse: (item, game) {
    //game.playerCombatStats.moveSpeedPenalty = 0.5;
  });

  static Item get escudoTorre => Item('escudoTorre', ItemType.shield, 'itens/towerShield.png', 6,value:6, description: 'd_escudoTorre',walkSlow: true, cor: Colors.white, onUse: (item, game) {
    //game.playerCombatStats.moveSpeedPenalty = 0.5;
  });

  static Item get braceleteNaga => Item('bracNaga', ItemType.shield, 'itens/bracerNaga.png', 5,description: 'd_bracNaga', value:6, walkFast: true, easyDash: true ,noShield: true, hasChargeAttack: true, cor: Colors.white, onUse: (item, game) {

  });

  static Item get braceleteFung => Item('bracFung', ItemType.shield, 'itens/bracerFung.png', 5,description: 'd_bracFung', value:6, walkFast: true, easyDash: true, noShield: true, hasPoisonAttack: true, cor: Colors.white, onUse: (item, game) {

  });

   static Item get healthPotion => Item('potVerm', ItemType.consumable, 'itens/potionVermelha.png', 40, 
    quantity: 1, description: 'd_potVerm', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    game.playerCombatStats.applyEffect(0.5,Palette.vermelho) ;
    game.showMessage(I18n.t('recupera_hp').replaceFirst('[hp]', item.power.toString()));
  });

  static Item get meat => Item('carne', ItemType.consumable, 'itens/meat.png', 10, 
    quantity: 1, description: 'd_carne', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    game.playerCombatStats.applyEffect(0.5,Palette.vermelho) ;
    game.showMessage(I18n.t('recupera_hp').replaceFirst('[hp]', item.power.toString()));
  });

  static Item get meat2 => Item('carne2', ItemType.consumable, 'itens/meat2.png', 50, 
    quantity: 1, description: 'd_carne2', cor: Colors.white, onUse: (item, game) {
    if(Random().nextBool()){
      game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
      game.playerCombatStats.applyEffect(0.5,Palette.vermelho) ;
      game.showMessage(I18n.t('recupera_hp').replaceFirst('[hp]', item.power.toString()));
    }else{
      game.playerCombatStats.hp /= 2;
      game.playerCombatStats.applyEffect(0.5,Palette.roxo) ;
      game.showMessage(I18n.t('perde_metade_hp'));
    }
  });

  static Item get manaPotion => Item('potAzul', ItemType.consumable, 'itens/potionAzul.png', 100, 
    quantity: 1, description: 'd_potAzul', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.mana = min(game.playerCombatStats.wis*3, game.playerCombatStats.mana + item.power);
    game.playerCombatStats.applyEffect(0.5,Palette.azul) ;
    game.showMessage(I18n.t('recupera_mana').replaceFirst('[mana]', item.power.toString()));
  });

  static Item get staminaPotion => Item('potVerde', ItemType.consumable, 'itens/potionVerde.png', 50, 
    quantity: 1, description: 'd_potVerde', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.cansado = false;
    game.playerCombatStats.stamina = game.playerCombatStats.con*3;
    game.playerCombatStats.staminaInfiniteTmr = 10;
    game.playerCombatStats.applyEffect(0.5,Palette.verdeCla) ;
    game.showMessage(I18n.t('recupera_stamina'));
  });

  static Item get reflexPotion => Item('potAmarela', ItemType.consumable, 'itens/potionAmarela.png', 50, 
    quantity: 1, description: 'd_potAmarela', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.reflex = true;
    game.showMessage(I18n.t('reflexo'));
    game.playerCombatStats.applyEffect(0.5,Palette.amarelo) ;
  });

  static Item get strPotion => Item('potPreta', ItemType.consumable, 'itens/potionPreta.png', 50, 
    quantity: 1, description: 'd_potPreta', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.buffForcaTmr = 10;
    game.showMessage(I18n.t('forcaBns'));
    game.playerCombatStats.applyEffect(0.5,Palette.cinza) ;
  });

  static Item get bugOrgan => Item('orgao', ItemType.consumable, 'itens/organ.png', 50, 
    quantity: 1, description: 'd_orgao', cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.poisonTmr = 0;
    game.playerCombatStats.applyEffect(0.5,Palette.vermelhoCla) ;
    game.showMessage("Você se sente melhor!");
  });

  static Item get bomb => Item('bomba', ItemType.consumable, 'itens/bomb.png', 30, 
    quantity: 1, description: 'd_bomba', cor: Colors.white, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
      item.quantity++;
      return;
    }
    AudioManager.playSfx('sfx/fire.wav');
    game.playerCombatStats.applyEffect(0.5,Palette.laranja) ;
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

  static Item get web => Item('teia', ItemType.consumable, 'itens/web.png', 0, 
    quantity: 1, description: 'd_teia', cor: Colors.white, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
      item.quantity++;
      return;
    }
    game.playerCombatStats.applyEffect(0.5,Palette.branco) ;
    for (var enemy in game.combatOverlay.enemies) {
      if (enemy.isAlive) { 
        enemy.applyHitStun(0.8); 
      }
    }
  });

  static Item get faca => Item('faca', ItemType.consumable, 'itens/faca.png', 3, 
    quantity: 1, description: 'd_faca', cor: Colors.white, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
      item.quantity++;
      return;
    }
    AudioManager.playSfx('sfx/hit.wav');
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

  static Item get coin => Item('moeda', ItemType.coin, 'itens/coin.png', 3, 
    quantity: 1, description: 'd_moeda', cor: Colors.white, onUse: (item, game) {
  });

  static Item get rubi => Item('rubi', ItemType.gem, 'itens/ruby.png', 3, 
    quantity: 1, description: 'd_rubi', cor: Colors.white, onUse: (item, game) {
  });

  static Item get esmeralda => Item('esmeralda', ItemType.gem, 'itens/esmeralda.png', 3, 
    quantity: 1, description: 'd_esmeralda', cor: Colors.white, onUse: (item, game) {
  });

  static Item get safira => Item('safira', ItemType.gem, 'itens/safira.png', 3, 
    quantity: 1, description: 'd_safira', cor: Colors.white, onUse: (item, game) {
  });

  static Item get slimeEye => Item('olhoSlime', ItemType.consumable, 'itens/slime_eye.png', 3, 
    quantity: 1, description: 'd_olhoSlime', cor: Colors.white, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
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
    game.combatOverlay.add(BounceProjectile(
      startPosition: launchPos, 
      velocity: initialVelocity,
      damage: calculatedDamage,
      img: img,
    ));
  });

  static Item get bola => Item('bola', ItemType.consumable, 'itens/bola.png', 5, 
    quantity: 1, description: 'd_bola', cor: Colors.white, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
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

    final ui.Image img = await game.images.load('effects/bola.png');
    game.combatOverlay.add(BounceProjectile(
      startPosition: launchPos, 
      velocity: initialVelocity,
      damage: calculatedDamage,
      img: img,
      remainingTime: 30
    ));
  });

  static Item get firePillar => Item('firePillar', ItemType.spell, 'itens/fire.png', 5, 
    manaCost: 10, value:6, description: 'd_firePillar', cor: Colors.white, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
      game.playerCombatStats.mana += item.manaCost; 
      return;
    }

    final ui.Image img = await game.images.load('effects/fire.png');
    AudioManager.playSfx('sfx/fire.wav');
    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 1.0, 1.5, item.power*game.playerCombatStats.wis, Colors.white, width: 80, height: 180
       ,img : img, isFlip: true
    ));
  });

  static Item get piercingShot => Item('piercingShot', ItemType.spell, 'itens/piercing.png', 4, 
    manaCost: 5, value:6, description: 'd_piercingShot', cor: Colors.white, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
      game.playerCombatStats.mana += item.manaCost; 
      return;
    }
    final ui.Image img = await game.images.load('effects/piercing.png');
    AudioManager.playSfx('sfx/charge.wav');
    game.combatOverlay.add(PlayerProjectile(
      game.playerCombatStats.strafePosition, 0.0, 2.5, item.power*game.playerCombatStats.wis, Colors.white, yDir: 1, isPiercing: true, width: 40, height: 180
      ,img : img
    ));
  });

  static Item get toxicCloud => Item('toxicCloud', ItemType.spell, 'itens/poison.png', 1, 
    manaCost: 10, value:6, description: 'd_toxicCloud', cor: Palette.verde, onUse: (item, game) async {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
      game.playerCombatStats.mana += item.manaCost; 
      return;
    }
    AudioManager.playSfx('sfx/poison.wav');
    final ui.Image img = await game.images.load('effects/poison.png');
    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 0.7, 0, item.power*game.playerCombatStats.wis, Palette.verde.withAlpha(180), width: 80, height: 180
      , isPiercing: true,hitCooldown: 0.5,img : img, isFlip: true
    ));
  });

  static Item get thunderStorm => Item('thunderStorm', ItemType.spell, 'itens/raio.png', 5, 
    manaCost: 15, value:16, quantity: 1, description: 'd_thunderStorm', cor: Colors.white, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage(I18n.t('guarda_batalha'));
      item.quantity++;
      return;
    }
    AudioManager.playSfx('sfx/thunder.wav');
    game.playerCombatStats.applyEffect(0.5,Palette.amarelo) ;
    for (var enemy in game.combatOverlay.enemies) {
      if (enemy.isAlive) { 
        enemy.hp -= item.power*game.playerCombatStats.wis; 
        enemy.applyHitStun(0.6); 
        if (enemy.hp <= 0) { 
          enemy.hp = 0; 
          enemy.isDying = true; 
          game.encounterEssence += enemy.dropEssence; 
          game.encounterDrop.addAll(enemy.drop);
        } 
      }
    }
  });
}