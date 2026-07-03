import 'dart:math';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';

class EncounterManager {
  static void triggerRandomEncounter(DungeonCrawlerGame game) {
    int level = game.dungeon.level;
    List<Enemy Function()> iniPool = [];

    if (level < 4) {
      iniPool = [() => SlimeEnemy(), () => GoblinEnemy(), () => SpiderEnemy(), () => BatEnemy(), () => OrcEnemy()];
    } else if (level < 7) {
      iniPool = [() => OvoEnemy(), () => WormEnemy(), () => FungoEnemy(), () => Fungo2Enemy(), () => BugEnemy(), () => InfectadoEnemy()];
    } else if (level < 10) {
      iniPool = [() => EsqueletoEnemy(), () => DollEnemy(), () => InfectadoEnemy(), () => JesterEnemy(), () => NagaEnemy(), () => HandEnemy()];
    } else {
      iniPool = [() => AberraArvEnemy(), () => AberraBestaEnemy(), () => AberraBrutoEnemy(), () => AberraVoaEnemy(), () => AberraOvoEnemy(), () => AberraCultistaEnemy()];
    }

    int numEnemies = Random().nextInt(4) + 1; 
    List<Enemy> spawnedEnemies = [];
    
    for (int i = 0; i < numEnemies; i++) {
      Enemy newEnemy = iniPool[Random().nextInt(iniPool.length)]();
      newEnemy.strafePosition = -0.6 + (i * 0.6); 
      if (i >= 2) { 
        newEnemy.isFrontRow = false;
        newEnemy.visualScale = 0.65;  
        newEnemy.visualYOffset = -0.15;
        newEnemy.visualDarkness = 0.6;
      }
      spawnedEnemies.add(newEnemy);
    }
    game.startCombat(spawnedEnemies);
  }

  static void triggerSpecificEncounter(DungeonCrawlerGame game, EnemyType type) {
    game.encounterEssence = 0; game.maxHp = game.playerCombatStats.hp; game.encounterDrop.clear(); game.victoryProcessed = false;
    game.isMimic = false; game.isBoss = false; game.currentState = GameState.combat; Enemy newEnemy;
    
    switch (type) {
        case EnemyType.slime: newEnemy = SlimeEnemy(); break;
        case EnemyType.goblin: newEnemy = GoblinEnemy(); break;
        case EnemyType.spider: newEnemy = SpiderEnemy(); break;
        case EnemyType.orc: newEnemy = OrcEnemy(); break;
        case EnemyType.mimic: 
          game.isMimic = true;
          List<Item> allEquipments = [
            ItemDatabase.espadaCurta,
            ItemDatabase.armaduraFerro,
            ItemDatabase.armaduraAco,
            ItemDatabase.armaduraBronze,
            ItemDatabase.clava,
            ItemDatabase.espadaLonga,
            ItemDatabase.zweihander,
            ItemDatabase.varinha,
            ItemDatabase.gambeson,
            ItemDatabase.escudoTorre,
            ItemDatabase.warhammer,
            ItemDatabase.lanca,
            ItemDatabase.claymore,
            ItemDatabase.armaduraCouro,
            ItemDatabase.chainMail,
            ItemDatabase.machado,
            ItemDatabase.firePillar,
            ItemDatabase.escudoMadeira,
            ItemDatabase.escudoFerro,
            ItemDatabase.piercingShot,
            ItemDatabase.toxicCloud,
          ];

          List<Item> unownedEquipments = allEquipments.where((equip) {
            return !game.playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
          }).toList();    

          var mimic = MimicEnemy()
              ..strafePosition = 0
              ..isFrontRow = true
              ..drop.add(unownedEquipments[Random().nextInt(unownedEquipments.length)]);
          game.startCombat([mimic]); return;
          
        case EnemyType.bug: newEnemy = BugEnemy(); break;
        case EnemyType.worm: newEnemy = WormEnemy(); break;
        case EnemyType.ovo: newEnemy = OvoEnemy(); break;
        case EnemyType.fungo: newEnemy = FungoEnemy(); break;
        case EnemyType.fungo2: newEnemy = Fungo2Enemy(); break;
        case EnemyType.infectado: newEnemy = InfectadoEnemy(); break;
        case EnemyType.esqueleto: newEnemy = EsqueletoEnemy(); break;
        case EnemyType.mao: newEnemy = HandEnemy(); break;
        case EnemyType.doll: newEnemy = DollEnemy(); break;
        case EnemyType.goblinShop: newEnemy = GoblinShopEnemy(); break;
        case EnemyType.boss1: game.isBoss = true; newEnemy = OrcChefe(); break;
        case EnemyType.boss3: game.isBoss = true; newEnemy = MagoEnemy(); break;
        case EnemyType.boss2:
          game. isBoss = true;
          var bug1 = BugEnemy()..strafePosition = 0.4..isFrontRow = true;
          var bug2 = BugEnemy()..strafePosition = -0.4..isFrontRow = true;
          var queen = RainhaInsetoEnemy()..strafePosition = 0.0..isFrontRow = false;
          var leftClaw = GarraRainhaEnemy(queen, -0.24)..isFrontRow = false;
          var rightClaw = GarraRainhaEnemy(queen, 0.24)..isFrontRow = false..isFlipped = true;
          game.startCombat([bug1, bug2, queen, leftClaw, rightClaw]); return;
        case EnemyType.jester: newEnemy = JesterEnemy(); break;  
        case EnemyType.naga: newEnemy = NagaEnemy(); break;  
        case EnemyType.aberraBruto: newEnemy = AberraBrutoEnemy(); break;  
        case EnemyType.aberraVoa: newEnemy = AberraVoaEnemy(); break;  
        case EnemyType.aberraBesta: newEnemy = AberraBestaEnemy(); break;  
        case EnemyType.aberraArv: newEnemy = AberraArvEnemy(); break;  
        case EnemyType.aberraCult: newEnemy = AberraCultistaEnemy(); break;  
        case EnemyType.aberraOvo: newEnemy = AberraOvoEnemy(); break;  
        case EnemyType.boss4:
          game.isBoss = true;
          var cult1 = AberraCultistaEnemy()..strafePosition = 0.5..isFrontRow = false;
          var cult2 = AberraCultistaEnemy()..strafePosition = -0.5..isFrontRow = false..isFlipped = true;
          var cult3 = AberraBrutoEnemy()..strafePosition = 0..isFrontRow = true;          
          var ant = AntigoEnemy()..strafePosition = 0.0..isFrontRow = false;
          game.startCombat([cult1, cult2, cult3, ant]); return;
        default: newEnemy = SlimeEnemy(); break;
    }
    newEnemy.strafePosition = 0.0; 
    game.startCombat([newEnemy]);
  }
}