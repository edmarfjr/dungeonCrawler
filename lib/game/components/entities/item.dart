import 'dart:math';
import 'dart:ui';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/player_projectile.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
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
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 3.0;
    game.playerCombatStats.critChance = 10;
    game.playerCombatStats.critMultiplier = 2;
  });

  static Item get espadaCurta => Item("Espada Curta", ItemType.weapon, 'itens/sword.png', 10, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 4.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
  });

  static Item get espadaLonga => Item("Espada Longa", ItemType.weapon, 'itens/longSword.png', 15, cor: Colors.white, hasReach: true, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.2;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 5.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.5;
  });

  static Item get machado => Item("Machado", ItemType.weapon, 'itens/axe.png', 20, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.2;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.3;
    game.playerCombatStats.staminaCost = 6.0;
    game.playerCombatStats.critChance = 5;
    game.playerCombatStats.critMultiplier = 1.2;
  });

  static Item get tanga => Item("Tanga", ItemType.armor, 'itens/tanga.png', 0, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 5.0;
  });

  static Item get armaduraCouro => Item("Armadura de Couro", ItemType.armor, 'itens/leatherArmor.png', 5, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 0.0;
  });
  static Item get armaduraFerro => Item("Armadura de Ferro", ItemType.armor, 'itens/armor.png', 10, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = -10.0;
  });

  static Item get bloquel => Item("Bloquel", ItemType.shield, 'itens/buckler.png', 0, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoMadeira => Item("Escudo de Madeira", ItemType.shield, 'itens/woodShield.png', 3, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.moveSpeedPenalty = 0.0;
  });

  static Item get escudoFerro => Item("Escudo de Ferro", ItemType.shield, 'itens/ironShield.png', 5, cor: Colors.white, onUse: (item, game) {
    game.playerCombatStats.moveSpeedPenalty = 0.5;
  });

  static Item get healthPotion => Item("Poção de Cura", ItemType.consumable, 'itens/potion.png', cor: Palette.vermelho, 40, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    game.playerCombatStats.healVfxTimer = 0.5;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de HP!");
    //}
  });

  static Item get manaPotion => Item("Poção de Mana", ItemType.consumable, 'itens/potion.png', cor: Palette.azul, 100, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.mana = min(game.playerCombatStats.wis*3, game.playerCombatStats.mana + item.power);
    game.playerCombatStats.manaVfxTimer = 0.5;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de Mana!");
    //}
  });

  static Item get staminaPotion => Item("Poção de Vigor", ItemType.consumable, 'itens/potion.png', cor: Palette.verde, 50, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.cansado = false;
    game.playerCombatStats.stamina = game.playerCombatStats.con*3;
    game.playerCombatStats.staminaInfiniteTmr = 6;
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

  static Item get firePillar => Item("Pilar de Fogo", ItemType.spell, 'itens/scroll.png', 25, manaCost: 20, cor: Palette.laranja, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde a sua mana para as batalhas!");
      game.playerCombatStats.mana += item.manaCost; // Devolve a mana!
      return;
    }

    // Instancia o projétil exatamente na posição horizontal do jogador!
    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 1.0, 1.5, item.power, item.cor, width: 80, height: 180
    ));
  });

  static Item get piercingShot => Item("Tiro Perfurante", ItemType.spell, 'itens/scroll.png', 25, manaCost: 30, cor: Palette.cinzaCla, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("Guarde a sua mana para as batalhas!");
      game.playerCombatStats.mana += item.manaCost; // Devolve a mana!
      return;
    }

    // Instancia o projétil exatamente na posição horizontal do jogador!
    
    game.combatOverlay.add(PlayerProjectile(
      game.playerCombatStats.strafePosition, 0.0, 2.5, item.power, item.cor, yDir: 1, isPiercing: true, width: 40, height: 180
    ));
  });

  static Item get toxicCloud => Item("Nuvem Tóxica", ItemType.spell, 'itens/scroll.png', 5, manaCost: 15, cor: Palette.verde, onUse: (item, game) {
    if (game.currentState != GameState.combat) { game.playerCombatStats.mana += item.manaCost; return; }

    game.combatOverlay.add(PlayerProjectile(
       game.playerCombatStats.strafePosition, 1.0, 1.5, item.power, item.cor, width: 80, height: 180
      , isPiercing: true,hitCooldown: 0.5
    ));
  });
}