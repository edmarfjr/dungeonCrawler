import 'dart:math';
import 'dart:ui';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';

  
enum ItemType { weapon, armor, consumable }

class Item {
  final String name;
  final ItemType type;
  final String imagePath; 
  final double power; 
  final Color cor;
  int quantity;

  final void Function(Item item, DungeonCrawlerGame game)? onUse;

  Item(this.name, this.type, this.imagePath, this.power, {this.quantity = 1, this.onUse, this.cor = Palette.branco});
}

class ItemDatabase {
  static Item get dagger => Item("Adaga", ItemType.weapon, 'itens/dagger.png', 5, cor: Palette.cinza, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.1;
    game.playerCombatStats.activeTime = 0.1;
    game.playerCombatStats.recoveryTime = 0.1;
    game.playerCombatStats.staminaCost = 15.0;
    game.playerCombatStats.weaponColor = item.cor;
  });

  static Item get shortSword => Item("Espada Curta", ItemType.weapon, 'itens/sword.png', 10, cor: Palette.cinza, onUse: (item, game) {
    game.playerCombatStats.windupTime = 0.2;
    game.playerCombatStats.activeTime = 0.2;
    game.playerCombatStats.recoveryTime = 0.2;
    game.playerCombatStats.staminaCost = 20.0;
    game.playerCombatStats.weaponColor = item.cor;
  });

  static Item get tanga => Item("Tanga", ItemType.armor, 'itens/tanga.png', 0, cor: Palette.bege, onUse: (item, game) {
    game.playerCombatStats.armorColor = item.cor;
  });
  static Item get armaduraFerro => Item("Armadura de Ferro", ItemType.armor, 'itens/armor.png', 10, cor: Palette.cinzaMed, onUse: (item, game) {

    game.playerCombatStats.armorColor = item.cor;
  });

  static Item get healthPotion => Item("Poção de Cura", ItemType.consumable, 'itens/potion.png', cor: Palette.vermelho, 40, quantity: 1, onUse: (item, game) {
    game.playerCombatStats.hp = min(game.playerCombatStats.maxHp, game.playerCombatStats.hp + item.power);
    if (game.currentState == GameState.exploration) {
       game.showMessage("💚 Você recuperou ${item.power} de HP!");
    }
  });

  static Item get alchemistsFire => Item("Fogo Alquímico", ItemType.consumable, 'itens/potion.png', cor: Palette.laranja, 30, quantity: 1, onUse: (item, game) {
    if (game.currentState != GameState.combat) {
      game.showMessage("🔥 Guarde isso para usar durante as batalhas!");
      item.quantity++; // Devolve o item
      return;
    }
    
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
}