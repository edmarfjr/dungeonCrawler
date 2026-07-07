import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:flutter/material.dart';

class SaveManager {
  static Future<void> saveGame(DungeonCrawlerGame game) async {
    final prefs = await SharedPreferences.getInstance();
    
    List<List<int>> gridJson = game.dungeon.grid.map((row) => row.map((t) => t.index).toList()).toList();
    List<List<bool>> exploredJson = game.dungeon.explored.map((row) => row.toList()).toList();
    
    List<Map<String, dynamic>> invJson = game.playerCombatStats.inventory.map((item) => {
      'name': item.name, 'quantity': item.quantity,
    }).toList();

    Map<String, dynamic> saveData = {
      'dungeon': {
        'width': game.dungeon.width, 'height': game.dungeon.height,
        'grid': gridJson, 'explored': exploredJson,
        'spikeState': game.dungeon.spikeState, 'poisonState': game.dungeon.poisonState, 'teleportState': game.dungeon.teleportState,

      },
      'player': {
        'x': game.player.x, 'y': game.player.y,
        'facing': game.player.facing.index, 'floorLevel': game.dungeon.level, 'hasKey': game.player.hasKey,
        'runTime': game.runTime,
      },
      'stats': {
        'str': game.playerCombatStats.str, 'con': game.playerCombatStats.con, 'wis': game.playerCombatStats.wis,
        'hp': game.playerCombatStats.hp, 'essence': game.playerCombatStats.essence,
        'inventory': invJson,
        'equippedWeapon': game.playerCombatStats.equippedWeapon?.name,
        'equippedArmor': game.playerCombatStats.equippedArmor?.name,
        'equippedShield': game.playerCombatStats.equippedShield?.name,
      }
    };

    await prefs.setString('save_game', jsonEncode(saveData));
    game.hasSavedGame = true;
  }

  static Future<void> loadGame(DungeonCrawlerGame game) async {
    final prefs = await SharedPreferences.getInstance();
    String? saveDataStr = prefs.getString('save_game');
    if (saveDataStr == null) return;

    Map<String, dynamic> data = jsonDecode(saveDataStr);
    var dData = data['dungeon'];
    game.dungeon = DungeonMap(width: dData['width'], height: dData['height']);
    game.dungeon.spikeState = dData['spikeState'] ?? 0;
    game.dungeon.poisonState = dData['poisonState'] ?? 0;
    game.dungeon.teleportState = dData['teleportState'] ?? 0;
    
    // Grid
    for(int y = 0; y < game.dungeon.height; y++) {
      for(int x = 0; x < game.dungeon.width; x++) {
        game.dungeon.grid[y][x] = TileType.values[dData['grid'][y][x]];
        game.dungeon.explored[y][x] = dData['explored'][y][x];
      }
    }

    // Player
    var pData = data['player'];
    game.player.x = pData['x']; game.player.y = pData['y'];
    game.player.facing = Direction.values[pData['facing']];
    game.dungeon.level = pData['floorLevel'];
    game.player.hasKey = pData['hasKey'];
    game.runTime = pData['runTime'];

    // Stats
    var sData = data['stats'];
    game.playerCombatStats.str = sData['str']; game.playerCombatStats.con = sData['con'];
    game.playerCombatStats.wis = sData['wis']; game.playerCombatStats.hp = sData['hp'];
    game.playerCombatStats.essence = sData['essence'];
    game.playerCombatStats.recalculateMaxHp();

    // Inv
    game.playerCombatStats.inventory.clear();
    List<Item> allGameItems = [
      // armas
      ItemDatabase.adaga, ItemDatabase.espadaCurta, ItemDatabase.espadaLonga, ItemDatabase.machado, ItemDatabase.clava,
      ItemDatabase.espadaOrc, ItemDatabase.lanca, ItemDatabase.claymore, ItemDatabase.clavaOrc, ItemDatabase.warhammer,
      ItemDatabase.varinha, ItemDatabase.zweihander,
      // armaduras
      ItemDatabase.tanga, ItemDatabase.armaduraFerro, ItemDatabase.armaduraCouro, ItemDatabase.armaduraBug, ItemDatabase.armaduraAco,
      ItemDatabase.armaduraBronze, ItemDatabase.gambeson, ItemDatabase.chainMail,
      // escudos
      ItemDatabase.bloquel, ItemDatabase.escudoMadeira, ItemDatabase.escudoFerro, ItemDatabase.braceleteFung, 
      ItemDatabase.braceleteNaga, ItemDatabase.escudoTorre,
      // pocoes
      ItemDatabase.healthPotion, ItemDatabase.manaPotion, ItemDatabase.staminaPotion, ItemDatabase.reflexPotion, ItemDatabase.strPotion,
      // itens
      ItemDatabase.faca, ItemDatabase.bomb, ItemDatabase.meat, ItemDatabase.web, ItemDatabase.slimeEye,
      ItemDatabase.bugOrgan, ItemDatabase.bola, ItemDatabase.coin,
      // magias
      ItemDatabase.firePillar, ItemDatabase.piercingShot, ItemDatabase.toxicCloud, ItemDatabase.thunderStorm,
    ];
    
    for(var itemData in sData['inventory']) {
      try {
        Item baseItem = allGameItems.firstWhere((i) => i.name == itemData['name']);
        // Precisamos clonar o item para não alterar o banco de dados global!
        Item loadedItem = Item(
          baseItem.name, baseItem.type, baseItem.imagePath, baseItem.power, 
          value: baseItem.value, quantity: itemData['quantity'], cor: baseItem.cor,
          str: baseItem.str, hasChargeAttack: baseItem.hasChargeAttack, // ... repasse os atributos principais
        );
        // Ou, se a sua classe Item permitir, use apenas: baseItem.quantity = itemData['quantity'];
        game.playerCombatStats.inventory.add(baseItem);
      } catch (e) {
        debugPrint("Item não encontrado no database: ${itemData['name']}");
      }
    }

    // Equip
    if(sData['equippedWeapon'] != null) await equipSavedItem(sData['equippedWeapon'], ItemType.weapon, game);
    if(sData['equippedArmor'] != null) await equipSavedItem(sData['equippedArmor'], ItemType.armor, game);
    if(sData['equippedShield'] != null) await equipSavedItem(sData['equippedShield'], ItemType.shield, game);

    game.combatOverlay.enemies.clear();
    game.dungeon.roamingEnemies.clear();
    game.renderer.map = game.dungeon; game.renderer.player = game.player;
  }

  static Future<void> equipSavedItem(String itemName, ItemType type,DungeonCrawlerGame game) async {
    try {
      // Busca o item no inventário
      var item = game.playerCombatStats.inventory.firstWhere((i) => i.name == itemName);
      String fileName = item.imagePath.split('/').last;

      // Equipa o item e muda a imagem (Sprite)
      if (type == ItemType.weapon) { 
        game.playerCombatStats.equippedWeapon = item; 
        await game.changeWeaponSprite('actors/$fileName'); 
      }
      else if (type == ItemType.armor) { 
        game.playerCombatStats.equippedArmor = item; 
        await game.changeArmorSprite('actors/$fileName'); 
      }
      else if (type == ItemType.shield) { 
        game.playerCombatStats.equippedShield = item; 
        await game.changeShieldSprite('actors/$fileName'); 
      }
    } catch (e) {
      debugPrint("Erro ao tentar reequipar o item: $itemName");
    }
  }
}