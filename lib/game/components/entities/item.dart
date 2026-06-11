import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/core/palette.dart';
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

  final void Function(Item item, DungeonCrawlerGame game)? onUse;

  Item(this.name, this.type, this.imagePath, this.power, {this.quantity = 1, this.onUse, this.cor = Palette.branco, this.manaCost = 0, this.hasReach = false});
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

  static Item get espadaLonga => Item("Espada Longa", ItemType.weapon, 'itens/longSword.png', 15, cor: Colors.white, hasReach: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 4.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 2;
  });

  static Item get machado => Item("Machado", ItemType.weapon, 'itens/axe.png', 20, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 5.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.2;
  });

  static Item get tanga => Item("Tanga", ItemType.armor, 'itens/tanga.png', 0, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 5.0;
  });

  static Item get armaduraCouro => Item("Armadura de Couro", ItemType.armor, 'itens/leatherArmor.png', 2, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 0.0;
  });
  static Item get armaduraFerro => Item("Armadura de Ferro", ItemType.armor, 'itens/armor.png', 3, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = -10.0;
  });

  static Item get bloquel => Item("Bloquel", ItemType.shield, 'itens/buckler.png', 3, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoMadeira => Item("Escudo de Madeira", ItemType.shield, 'itens/woodShield.png', 3, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoFerro => Item("Escudo de Ferro", ItemType.shield, 'itens/ironShield.png', 5, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.moveSpeedPenalty = 0.5;
  });

  static Item get healthPotion => Item("Poção Vermelha", ItemType.consumable, 'itens/potion.png', cor: Palette.vermelho, 40, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    game.playerCombatStats.healVfxTimer = 0.5;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de HP!");
    //}
  });

  static Item get manaPotion => Item("Poção Azul", ItemType.consumable, 'itens/potion.png', cor: Palette.azul, 100, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.mana = min(game.playerCombatStats.wis*3, game.playerCombatStats.mana + item.power);
    game.playerCombatStats.manaVfxTimer = 0.5;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de Mana!");
    //}
  });

  static Item get staminaPotion => Item("Poção Verde", ItemType.consumable, 'itens/potion.png', cor: Palette.verde, 50, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.cansado = false;
    game.playerCombatStats.stamina = game.playerCombatStats.con*3;
    game.playerCombatStats.staminaInfiniteTmr = 6;
    //if (game.currentState == GameState.exploration) {
   // game.showMessage("Você recuperou ${item.power} de Stamina!");
    //}
  });

  static Item get reflexPotion => Item("Poção Amarela", ItemType.consumable, 'itens/potion.png', cor: Palette.amarelo, 50, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.reflex = true;
    //if (game.currentState == GameState.exploration) {
   // game.showMessage("Você recuperou ${item.power} de Stamina!");
    //}
  });

  static Item get bomb => Item("Bomba", ItemType.consumable, 'itens/bomb.png', cor: Colors.white, 30, quantity: 1, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde isso para usar durante as batalhas!");
      item.quantity++; // Devolve o item
      return;
    }
    FlameAudio.play('sfx/fire.wav');
    game.playerCombatStats.explosionVfxTimer = 0.5;
    // Dano em área para todos os inimigos vivos no Overlay de Combate
    for (var enemy in game.combatOverlay.enemies) {
      if (enemy.isAlive) { 
        enemy.hp -= item.power; 
        enemy.applyHitStun(0.3); 
        if (enemy.hp <= 0) { 
          enemy.hp = 0; 
          enemy.isDying = true; 
          game.encounterEssence += enemy.dropEssence; 
        } 
      }
    }
  });

  
  static Item get slimeEye => Item("Olho de Slime", ItemType.consumable, 'itens/slime_eye.png', 3, quantity: 1, cor: Palette.verdeCla, onUse: (item, game) async {
    // 1. Trava de segurança para não gastar fora do combate
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde isso para usar durante as batalhas!");
      item.quantity++;
      return;
    }

    //FlameAudio.play('sfx/throw.wav');

    // 2. Define o ponto de partida (Centro inferior da tela de combate)
    Vector2 launchPos = Vector2(game.size.x / 2, game.size.y * 0.70);

    // 3. Calcula um vetor diagonal inicial aleatório jogado para cima
    double randomAngleOffsetX = (Random().nextDouble() * 0.4) - 0.2; 
    double projectileSpeed = 550.0; // Velocidade ágil em pixels por segundo
    Vector2 initialVelocity = Vector2(randomAngleOffsetX, -1.0).normalized() * projectileSpeed;

    // 4. Calcula o dano mágico baseado na sabedoria (wis)
    double calculatedDamage = item.power + game.playerCombatStats.str.toDouble();

    final ui.Image img = await game.images.load(item.imagePath);
    // 5. Instancia e joga o projétil caótico direto na árvore do combate
    game.combatOverlay.add(SlimeEyeProjectile(
      startPosition: launchPos, 
      velocity: initialVelocity,
      damage: calculatedDamage,
      img: img,
    ));
  });

  static Item get firePillar => Item("Pilar de Fogo", ItemType.spell, 'itens/scroll.png', 5, manaCost: 15, cor: Palette.laranja, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde a sua mana para as batalhas!");
      game.playerCombatStats.mana += item.manaCost; // Devolve a mana!
      return;
    }

    // Instancia o projétil exatamente na posição horizontal do jogador!
    FlameAudio.play('sfx/fire.wav');
    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 1.0, 1.5, item.power*game.playerCombatStats.wis, item.cor, width: 80, height: 180
    ));
  });

  static Item get piercingShot => Item("Tiro Perfurante", ItemType.spell, 'itens/scroll.png', 4, manaCost: 10, cor: Palette.cinzaCla, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde a sua mana para as batalhas!");
      game.playerCombatStats.mana += item.manaCost; // Devolve a mana!
      return;
    }
    FlameAudio.play('sfx/charge.wav');
    game.combatOverlay.add(PlayerProjectile(
      game.playerCombatStats.strafePosition, 0.0, 2.5, item.power*game.playerCombatStats.wis, item.cor, yDir: 1, isPiercing: true, width: 40, height: 180
    ));
  });

  static Item get toxicCloud => Item("Nuvem Tóxica", ItemType.spell, 'itens/scroll.png', 1, manaCost: 15, cor: Palette.verde, onUse: (item, game) {
    if (game.currentState != GameState.combat) { game.playerCombatStats.mana += item.manaCost; return; }
    FlameAudio.play('sfx/poison.wav');
    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 1.0, 1.5, item.power*game.playerCombatStats.wis, item.cor, width: 80, height: 180
      , isPiercing: true,hitCooldown: 0.5
    ));
  });
}