import 'dart:math';
import 'dart:ui';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/arc_projectile.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';

  
enum ItemType { weapon, armor, consumable, spell }

class Item {
  final String name;
  final ItemType type;
  final String imagePath; 
  final double power; 
  final Color cor;
  final int manaCost;
  int quantity;

  final void Function(Item item, DungeonCrawlerGame game)? onUse;

  Item(this.name, this.type, this.imagePath, this.power, {this.quantity = 1, this.onUse, this.cor = Palette.branco, this.manaCost = 0});
}

class ItemDatabase {
  static Item get adaga => Item("Adaga", ItemType.weapon, 'itens/dagger.png', 5, cor: Palette.cinza, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 15.0;
  });

  static Item get espadaCurta => Item("Espada Curta", ItemType.weapon, 'itens/sword.png', 10, cor: Palette.cinza, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.2;
    game.playerCombatStats.activeTime = 0.2;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 20.0;
  });

  static Item get espadaLonga => Item("Espada Longa", ItemType.weapon, 'itens/longSword.png', 15, cor: Palette.cinzaCla, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.2;
    game.playerCombatStats.activeTime = 0.2;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 25.0;
  });

  static Item get machado => Item("Machado", ItemType.weapon, 'itens/axe.png', 15, cor: Palette.cinza, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.2;
    game.playerCombatStats.activeTime = 0.2;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 25.0;
  });

  static Item get tanga => Item("Tanga", ItemType.armor, 'itens/tanga.png', 0, cor: Palette.bege, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 5.0;
  });

  static Item get armaduraCouro => Item("Armadura de Couro", ItemType.armor, 'itens/leatherArmor.png', 5, cor: Palette.marromEsc, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = 0.0;
  });
  static Item get armaduraFerro => Item("Armadura de Ferro", ItemType.armor, 'itens/armor.png', 10, cor: Palette.cinzaMed, onUse: (item, game) {
    game.playerCombatStats.staminaRegenBonus = -10.0;
  });

  static Item get healthPotion => Item("Poção de Cura", ItemType.consumable, 'itens/potion.png', cor: Palette.vermelho, 40, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    game.playerCombatStats.healVfxTimer = 0.5;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de HP!");
    //}
  });

  static Item get manaPotion => Item("Poção de Mana", ItemType.consumable, 'itens/potion.png', cor: Palette.azul, 100, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.mana = min(game.playerCombatStats.maxMana, game.playerCombatStats.mana + item.power);
    game.playerCombatStats.manaVfxTimer = 0.5;
    //if (game.currentState == GameState.exploration) {
    game.showMessage("Você recuperou ${item.power} de Mana!");
    //}
  });

  static Item get bomb => Item("Bomba", ItemType.consumable, 'itens/bomb.png', cor: Palette.cinzaEsc, 30, quantity: 1, onUse: (item, game) {
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
    game.playerCombatStats.activeProjectiles.add(
      PlayerProjectile(game.playerCombatStats.strafePosition, 1.0, 1.5, item.power, item.cor)
    );
  });
}