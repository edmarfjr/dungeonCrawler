import 'dart:math';
import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/minimap_renderer.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/core/player_state.dart';
import 'package:dungeon_crawler/game/components/core/maze_renderer.dart';
import 'package:dungeon_crawler/game/components/entities/combat_entities.dart';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:dungeon_crawler/game/components/entities/player_projectile.dart';
import 'package:dungeon_crawler/game/overlays/combat_overlay.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart' hide PlayerState;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum GameInput { up, down, left, right, buttonA, buttonB, pause }
enum GameState { mainMenu, exploration, combat, paused, gameOver, inventory, levelUp, manual, shop }
enum ShopPhase { main, buy, sell, confirmSell, steal }

ShopPhase currentShopPhase = ShopPhase.main;
int shopCursor = 0;
Item? itemToSell;
List<Item> shopInventory = [];

// --- CLASSE AUXILIAR PARA A FILA DE MENSAGENS ---
class GameMessage {
  final String text;
  final VoidCallback? onDismiss;
  GameMessage(this.text, {this.onDismiss});
}

class DungeonCrawlerGame extends FlameGame with KeyboardEvents {
  GameState currentState = GameState.mainMenu;
  GameState previousState = GameState.mainMenu;

  bool hasSavedGame = false;
  late DungeonMap dungeon;
  late PlayerState player;
  late MazeRenderer renderer;
  late MinimapRenderer minimap;
  late PlayerCombatStats playerCombatStats;
  late CombatOverlay combatOverlay;
  late Map<EnemyType, ui.Image> enemySheets;
  late ui.Image playerSheet; 
  late ui.Image playerSlashSprite1;
  late ui.Image playerSlashSprite2;
  late Map<EnemyType, ui.Image> enemySlashSprites;
  late ui.Image weaponSheet;
  late ui.Image armorSheet;
  late ui.Image shieldSheet;

  late ui.Image keySprite;
  late ui.Image doorTexture;
  late ui.Image doorTexture2;
  late ui.Image chestSprite;
  late ui.Image crateSprite;
  late ui.Image openChestSprite;
  late ui.Image trapImage;
  late ui.Image trapImage2;
  late ui.Image roamerSprite;
  late ui.Image bossSprite;
  late ui.Image shrineSprite;

  bool leftPressed = false, rightPressed = false, downPressed = false, showHitboxes = false, upPressed = false;
  double explorationMoveCooldown = 0.0;
  double explorationMoveCooldownTime = 0.3;

  double leftTapTimer = 0.0;  // Janela de tempo para o clique duplo (Esquerda)
  double rightTapTimer = 0.0; // Janela de tempo para o clique duplo (Direita)
  double dashTimer = 0.0;     // Duração do Dash na tela
  double dashDur = 0.1;
  double dashVel = 7.0;
  double dashDirection = 0.0;
  double dashCusto = 14;

  double maxHp = 0;
  double regenTmr = 2;

  // REFACTOR: Substituído showVictoryMessage por um controle de fluxo de fim de turno
  bool _victoryProcessed = true;
  double encounterEssence = 0;

  List<Item> encounterDrop = [];
  bool isMimic = false;
  bool isBoss = false;

  // REFACTOR: O sistema agora usa uma lista interna agindo como fila (Queue)
  final List<GameMessage> _messageQueue = []; 

  // O getter reativo garante que a interface renderize sempre o texto que está no topo da fila
  String? get activeMessage => _messageQueue.isNotEmpty ? _messageQueue.first.text : null;
  
  int mapSize = 30;

  // --- VARIÁVEIS DE INVENTÁRIO ---
  int inventoryCursor = 0;
  bool isActionMenuOpen = false;
  int selectedConsumableIndex = 0;
  bool isItemActionMenuOpen = false;
  int itemActionCursor = 0;

  int levelUpCursor = 0;       // 0: STR, 1: CON, 2: WIS, 3: Confirmar
  int pointsToDistribute = 0;  // Começa com 3 pontos ganhos
  int tempStr = 0, tempCon = 0, tempWis = 0; // Guardam a distribuição temporária

  bool isPassTurnPromptOpen = false;

  ScrollController? manualScrollController;

  final ValueNotifier<int> mainMenuCursor = ValueNotifier<int>(0);
  final ValueNotifier<int> pauseMenuCursor = ValueNotifier<int>(0);

  double shakeTimer = 0.0;
  double shakeIntensity = 0.0;

  void shakeScreen(double duration, double intensity) {
    shakeTimer = duration;
    shakeIntensity = intensity;
  }
  
  int get levelUpCost {
    int totalLevel = (playerCombatStats.str + playerCombatStats.con + playerCombatStats.wis).toInt();
    return 50 + (totalLevel * 15);
  }

  int _getPlayerCoins() {
    try {
      return playerCombatStats.inventory.firstWhere((i) => i.name == "moeda").quantity;
    } catch (e) {
      return 0; // Não achou a moeda
    }
  }

  void _addCoins(int amount) {
    try {
      var coin = playerCombatStats.inventory.firstWhere((i) => i.name == "moeda");
      coin.quantity += amount;
    } catch (e) {
      var newCoin = ItemDatabase.coin;
      newCoin.quantity = amount;
      playerCombatStats.inventory.add(newCoin);
    }
  }

  void _removeCoins(int amount) {
    try {
      var coin = playerCombatStats.inventory.firstWhere((i) => i.name == "moeda");
      coin.quantity -= amount;
      if (coin.quantity <= 0) {
        playerCombatStats.inventory.remove(coin);
      }
    } catch (e) {}
  }

  void openShop() {
    currentState = GameState.shop;
    currentShopPhase = ShopPhase.main; // Força a loja a abrir no menu inicial
    shopCursor = 0;                    // Coloca o cursor na opção "COMPRAR"
    itemToSell = null;                 // Limpa qualquer item que tenha ficado na memória
  }

  // REFACTOR: showMessage agora empilha novas mensagens no fim da fila
  void showMessage(String text, {VoidCallback? onDismiss}) {
    _messageQueue.add(GameMessage(text, onDismiss: onDismiss));
  }

  // REFACTOR: dismissMessage agora remove o topo da fila e ativa o seu callback individual
  void dismissMessage() {
    if (_messageQueue.isNotEmpty) {
      final dismissedMessage = _messageQueue.removeAt(0);
      if (dismissedMessage.onDismiss != null) {
        dismissedMessage.onDismiss!(); 
      }
    }
  }

  void receiveItem(Item newItem) {
    if (newItem.type == ItemType.consumable) {
      var existing = playerCombatStats.inventory.where((i) => i.name == newItem.name).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity += newItem.quantity;
        showMessage("Obteve mais ${newItem.quantity}x ${newItem.name}!");
        return;
      }
    }

    if (playerCombatStats.inventory.length < playerCombatStats.maxInventory) {
      playerCombatStats.inventory.add(newItem);
      showMessage("Você pegou: ${newItem.name}!");
    } else {
      Point<int> pos = Point(player.x, player.y);
      dungeon.droppedItems.putIfAbsent(pos, () => []).add(newItem);
      showMessage("Inventário Cheio! ${newItem.name} ficou no chão.");
    }
  }

  void dropSelectedItem(int cursorIndex) {
    if (playerCombatStats.inventory.isEmpty) return;
    Item item = playerCombatStats.inventory[cursorIndex];

    if (playerCombatStats.equippedWeapon == item || 
        playerCombatStats.equippedArmor == item || 
        playerCombatStats.equippedShield == item) {
      showMessage("Não pode descartar um item Equipado!");
      return;
    }

    Point<int> pos = Point(player.x, player.y);
    dungeon.droppedItems.putIfAbsent(pos, () => []).add(item);
    
    playerCombatStats.inventory.removeAt(cursorIndex);
    showMessage("${item.name} foi deixado no chão.");
  }

  void _initializeInventory() {
    playerCombatStats.inventory = [
      ItemDatabase.adaga,
      ItemDatabase.tanga,
      ItemDatabase.bloquel,
      ItemDatabase.healthPotion,
    ];
    playerCombatStats.equippedWeapon = playerCombatStats.inventory[0];
    playerCombatStats.equippedArmor = playerCombatStats.inventory[1];
    playerCombatStats.equippedShield = playerCombatStats.inventory[2];
    selectedConsumableIndex = 0;
  }

  Future<void> saveGame() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Salva o Mapa Procedural
    List<List<int>> gridJson = dungeon.grid.map((row) => row.map((tile) => tile.index).toList()).toList();
    List<List<bool>> exploredJson = dungeon.explored.map((row) => row.toList()).toList();
    
    // 2. Salva o Inventário
    List<Map<String, dynamic>> invJson = playerCombatStats.inventory.map((item) => {
      'name': item.name,
      'quantity': item.quantity,
    }).toList();

    // 3. Empacota tudo num Grande JSON
    Map<String, dynamic> saveData = {
      'dungeon': {
        'width': dungeon.width,
        'height': dungeon.height,
        'grid': gridJson,
        'explored': exploredJson,
        'spikeState': dungeon.spikeState,
        'poisonState': dungeon.poisonState,
      },
      'player': {
        'x': player.x,
        'y': player.y,
        'facing': player.facing.index,
        'floorLevel': dungeon.level,
        'hasKey': player.hasKey,
      },
      'stats': {
        'str': playerCombatStats.str,
        'con': playerCombatStats.con,
        'wis': playerCombatStats.wis,
        'hp': playerCombatStats.hp,
        'essence': playerCombatStats.essence,
        'inventory': invJson,
        'equippedWeapon': playerCombatStats.equippedWeapon?.name,
        'equippedArmor': playerCombatStats.equippedArmor?.name,
        'equippedShield': playerCombatStats.equippedShield?.name,
      }
    };

    await prefs.setString('save_game', jsonEncode(saveData));
    hasSavedGame = true;
    debugPrint("Jogo Salvo com Sucesso!");
  }

  Future<void> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    String? saveDataStr = prefs.getString('save_game');
    if (saveDataStr == null) return;

    Map<String, dynamic> data = jsonDecode(saveDataStr);
    
    // 1. Reconstrói o Labirinto
    var dData = data['dungeon'];
    dungeon = DungeonMap(width: dData['width'], height: dData['height']);
    dungeon.spikeState = dData['spikeState'] ?? 0;
    dungeon.poisonState = dData['poisonState'] ?? 0;
    
    List<dynamic> gridDyn = dData['grid'];
    List<dynamic> expDyn = dData['explored'];
    for(int y = 0; y < dungeon.height; y++) {
      for(int x = 0; x < dungeon.width; x++) {
        dungeon.grid[y][x] = TileType.values[gridDyn[y][x]];
        dungeon.explored[y][x] = expDyn[y][x];
      }
    }

    // 2. Reconstrói o Jogador
    var pData = data['player'];
    player.x = pData['x'];
    player.y = pData['y'];
    player.facing = Direction.values[pData['facing']];
    dungeon.level = pData['floorLevel'];
    player.hasKey = pData['hasKey'];

    // 3. Reconstrói os Status
    var sData = data['stats'];
    playerCombatStats.str = sData['str'];
    playerCombatStats.con = sData['con'];
    playerCombatStats.wis = sData['wis'];
    playerCombatStats.hp = sData['hp'];
    playerCombatStats.essence = sData['essence'];
    playerCombatStats.recalculateMaxHp();

    // 4. Reconstrói o Inventário
    playerCombatStats.inventory.clear();
    List<dynamic> invDyn = sData['inventory'];
    
    // Lista mestra para buscar as instâncias reais dos itens pelo nome
    List<Item> allGameItems = [
      //armas
      ItemDatabase.adaga, ItemDatabase.espadaCurta, ItemDatabase.espadaLonga, ItemDatabase.machado,ItemDatabase.clava,
      ItemDatabase.espadaOrc, ItemDatabase.lanca,ItemDatabase.claymore,ItemDatabase.clavaOrc,ItemDatabase.warhammer,
      ItemDatabase.varinha,ItemDatabase.zweihander,
      //armaduras
      ItemDatabase.tanga, ItemDatabase.armaduraFerro, ItemDatabase.armaduraCouro, ItemDatabase.armaduraBug,ItemDatabase.armaduraAco,
      ItemDatabase.armaduraBronze, ItemDatabase.gambeson,
      //escudos
      ItemDatabase.bloquel, ItemDatabase.escudoMadeira, ItemDatabase.escudoFerro, ItemDatabase.braceleteFung, 
      ItemDatabase.braceleteNaga, ItemDatabase.escudoTorre,
      //pocoes
      ItemDatabase.healthPotion, ItemDatabase.manaPotion, ItemDatabase.staminaPotion, ItemDatabase.reflexPotion,
      //itens
      ItemDatabase.faca, ItemDatabase.bomb, ItemDatabase.meat, ItemDatabase.web, ItemDatabase.slimeEye,
      ItemDatabase.bugOrgan, ItemDatabase.bola, ItemDatabase.coin,
      //magias
      ItemDatabase.firePillar, ItemDatabase.piercingShot, ItemDatabase.toxicCloud,
    ]; // IMPORTANTE: Mantenha essa lista atualizada se criar itens novos!

    for(var itemData in invDyn) {
      try {
        Item baseItem = allGameItems.firstWhere((i) => i.name == itemData['name']);
        baseItem.quantity = itemData['quantity'];
        playerCombatStats.inventory.add(baseItem);
      } catch (e) {
        debugPrint("Item não encontrado no database: ${itemData['name']}");
      }
    }

    // 5. Re-equipa os itens visualmente
    String? wName = sData['equippedWeapon'];
    if(wName != null) {
      playerCombatStats.equippedWeapon = playerCombatStats.inventory.firstWhere((i) => i.name == wName);
      await changeWeaponSprite('actors/${playerCombatStats.equippedWeapon!.imagePath.split('/').last}');
    }
    
    String? aName = sData['equippedArmor'];
    if(aName != null) {
      playerCombatStats.equippedArmor = playerCombatStats.inventory.firstWhere((i) => i.name == aName);
      await changeArmorSprite('actors/${playerCombatStats.equippedArmor!.imagePath.split('/').last}');
    }
    
    String? sName = sData['equippedShield'];
    if(sName != null) {
      playerCombatStats.equippedShield = playerCombatStats.inventory.firstWhere((i) => i.name == sName);
      await changeShieldSprite('actors/${playerCombatStats.equippedShield!.imagePath.split('/').last}');
    }

    // Limpa a tela para exploração
    combatOverlay.enemies.clear();
    dungeon.roamingEnemies.clear(); 

    renderer.map = dungeon;
    renderer.player = player;
  }

  @override
  Future<void> onLoad() async {
    final prefs = await SharedPreferences.getInstance();
    hasSavedGame = prefs.containsKey('save_game');

    await FlameAudio.audioCache.loadAll([
      'sfx/hit.wav',
      'sfx/block.wav',
      'sfx/encounter.wav',
      'sfx/attack.wav',
      'sfx/enemy_die.wav',
      'sfx/use_item.wav',
      'sfx/fire.wav',
      'sfx/charge.wav',
      'sfx/poison.wav',
      'sfx/confirm.wav',
      'sfx/hover.wav',
      'sfx/step.wav',
      'sfx/landing.wav',
      'sfx/denied.wav',
    ]);
    
    await images.loadAll([
      'itens/dagger.png',
      'itens/armor.png',
      'itens/potion.png',
      'itens/potionVermelha.png',
      'itens/potionVerde.png',
      'itens/potionAzul.png',
      'itens/potionAmarela.png',
      'itens/tanga.png',
      'itens/sword.png',
      'itens/longSword.png',
      'itens/lanca.png',
      'itens/axe.png',
      'itens/bomb.png',
      'itens/leatherArmor.png',
      'itens/scroll.png',
      'itens/woodShield.png',
      'itens/ironShield.png',
      'itens/buckler.png',
      'itens/slime_eye.png',
      'itens/club.png',
      'itens/clubOrc.png',
      'itens/web.png',
      'itens/meat.png',
      'itens/faca.png',
      'itens/fire.png',
      'itens/poison.png',
      'itens/piercing.png',
      'itens/organ.png',
      'itens/orcSword.png',
      'itens/bracerNaga.png',
      'itens/bracerFung.png',
      'itens/armorBug.png',
      'itens/bola.png',
      'itens/coin.png',
      'itens/claymore.png',
      'itens/warhammer.png',
      'itens/steelArmor.png',
      'itens/bronzeArmor.png',
      'itens/towerShield.png',
      'itens/gambeson.png',
      'itens/varinha.png',
      'itens/zweihander.png',
    ]);
    final ui.Image wallImg = await images.load('tilesets/wall.png');
    final ui.Image floorImg = await images.load('tilesets/floor.png');
    final ui.Image wallImg2 = await images.load('tilesets/wall2.png');
    final ui.Image floorImg2 = await images.load('tilesets/floor2.png');
    final ui.Image wallImg3 = await images.load('tilesets/wall1.png');
    final ui.Image floorImg3 = await images.load('tilesets/floor1.png');

    final ui.Image shopImg = await images.load('tilesets/shop.png');
    final ui.Image fontImg = await images.load('tilesets/fonte.png');

    roamerSprite = await images.load('tilesets/enemy.png');
    bossSprite = await images.load('tilesets/boss.png');
    shrineSprite = await images.load('tilesets/altar.png');

    keySprite = await images.load('itens/key.png');     
    doorTexture = await images.load('tilesets/trapdoor.png');
    doorTexture2 = await images.load('tilesets/trapdoor2.png');
    chestSprite = await images.load('tilesets/bau.png');
    crateSprite = await images.load('tilesets/crate.png');
    openChestSprite = await images.load('tilesets/bauAberto.png');
    trapImage = await images.load('tilesets/trap.png');
    trapImage2 = await images.load('tilesets/trap2.png');
    enemySheets = {
      EnemyType.slime: await images.load('actors/slime.png'),
      EnemyType.goblin: await images.load('actors/goblin.png'),
      EnemyType.spider: await images.load('actors/spider.png'),
      EnemyType.mimic: await images.load('actors/mimic.png'),
      EnemyType.orc: await images.load('actors/orc.png'),
      EnemyType.bat: await images.load('actors/bat.png'),
      EnemyType.boss1: await images.load('actors/boss1.png'),
      EnemyType.bug: await images.load('actors/bug.png'),
      EnemyType.worm: await images.load('actors/larva.png'),
      EnemyType.ovo: await images.load('actors/ovo.png'),
      EnemyType.fungo: await images.load('actors/fungo.png'),
      EnemyType.fungo2: await images.load('actors/fungo2.png'),
      EnemyType.infectado: await images.load('actors/infectado.png'),
      EnemyType.garra: await images.load('actors/garra.png'),
      EnemyType.boss2: await images.load('actors/boss2.png'),
      EnemyType.esqueleto: await images.load('actors/esqueleto.png'),
      EnemyType.jester: await images.load('actors/jester.png'),
      EnemyType.naga: await images.load('actors/naga.png'),
      EnemyType.mao: await images.load('actors/mao.png'),
      EnemyType.doll: await images.load('actors/doll.png'),
      EnemyType.goblinShop: await images.load('actors/goblinShop.png'),
      EnemyType.boss3: await images.load('actors/boss3.png'),
    };
    playerSheet = await images.load('actors/player.png');

    weaponSheet = await images.load('actors/dagger.png');
    armorSheet = await images.load('actors/tanga.png');
    shieldSheet = await images.load('actors/buckler.png');
    playerSlashSprite1 = await images.load('effects/slashV.png');
    playerSlashSprite2 = await images.load('effects/slashH.png');
    
    enemySlashSprites = {
      EnemyType.slime: await images.load('effects/golpe.png'), 
      EnemyType.goblin: await images.load('effects/golpe.png'),
      EnemyType.orc: await images.load('effects/golpe.png'),
      EnemyType.boss1: await images.load('effects/golpe.png'),
      EnemyType.spider: await images.load('effects/bite.png'), 
      EnemyType.mimic: await images.load('effects/coin.png'),
      EnemyType.bat: await images.load('effects/bite.png'), 
      EnemyType.bug: await images.load('effects/golpe.png'), 
      EnemyType.worm: await images.load('effects/bite.png'), 
      EnemyType.fungo: await images.load('effects/spore.png'), 
      EnemyType.fungo2: await images.load('effects/spore.png'), 
      EnemyType.boss2: await images.load('effects/spore.png'), 
      EnemyType.infectado: await images.load('effects/soco.png'), 
      EnemyType.esqueleto: await images.load('effects/golpeLargo.png'), 
      EnemyType.jester: await images.load('effects/bola.png'), 
      EnemyType.mao: await images.load('effects/bola.png'), 
      EnemyType.naga: await images.load('effects/golpe.png'), 
      EnemyType.doll: await images.load('effects/golpe.png'), 
      EnemyType.goblinShop: await images.load('effects/golpe.png'), 
      EnemyType.boss3: await images.load('effects/soco2.png'), 
    };

    dungeon = DungeonMap(width: mapSize, height: mapSize);
    player = PlayerState(x: dungeon.playerSpawn.x, y: dungeon.playerSpawn.y, facing: Direction.north);

    renderer = MazeRenderer(
      map: dungeon, 
      player: player, 
      wallImage: [wallImg,wallImg2,wallImg3], 
      floorImage: [floorImg,floorImg2,floorImg3],
      doorImage: doorTexture, 
      doorImage2: doorTexture2, 
      keyImage: keySprite, 
      chestImage: chestSprite,
      trapImage: [trapImage,trapImage2],
      roamerImage: roamerSprite,
      bossImage: bossSprite,
      shrineImage: shrineSprite,
      openChestImage: openChestSprite,
      crateImage: crateSprite,
      shopImage: shopImg,
      fontImage: fontImg,
    );
    renderer.size = size; 
    add(renderer);

    playerCombatStats = PlayerCombatStats();
    _initializeInventory();
    combatOverlay = CombatOverlay(
      playerStats: playerCombatStats, 
      playerSheetImage: playerSheet, 
      weaponSheetImage: weaponSheet,
      armorSheetImage: armorSheet,
      shieldSheetImage: shieldSheet,
      enemySheets: enemySheets,
      playerSlashImage: [playerSlashSprite1,playerSlashSprite2], 
      enemySlashImages: enemySlashSprites,
    );
    combatOverlay.add(EnemyShadowsRenderer());
    combatOverlay.size = size; add(combatOverlay);

    minimap = MinimapRenderer();
    add(minimap);
  }

  @override
  void render(Canvas canvas) {
    if (shakeTimer > 0) {
      canvas.save(); // Salva a posição normal
      
      // Sorteia números entre -0.5 e 0.5, multiplicados pela intensidade
      double dx = (Random().nextDouble() - 0.5) * shakeIntensity;
      double dy = (Random().nextDouble() - 0.5) * shakeIntensity;
      
      canvas.translate(dx, dy); // Arremessa a tela inteira fora do lugar!
      
      super.render(canvas); // Desenha TUDO (Combate, Masmorra, etc)
      
      canvas.restore(); // Puxa a tela de volta pro lugar
    } else {
      // Se não tem terremoto, desenha normal
      super.render(canvas);
    }

    if (currentState == GameState.shop) {
      // Fundo escuro transparente
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(2, 2, size.x-3, size.y-3), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      TextPaint titlePaint = TextPaint(style: const TextStyle(color: Palette.amarelo, fontSize: 24, fontFamily: 'pixelFont'));
      TextPaint normalPaint = TextPaint(style: const TextStyle(color: Palette.branco, fontSize: 16, fontFamily: 'pixelFont'));
      TextPaint selectPaint = TextPaint(style: const TextStyle(color: Palette.verdeCla, fontSize: 16, fontFamily: 'pixelFont'));

      titlePaint.render(canvas, "LOJA", Vector2(20, 20));
      normalPaint.render(canvas, "Moedas: ${_getPlayerCoins()}", Vector2(20, 50));

      double startY = 90;

      // DESENHA O MENU PRINCIPAL
      if (currentShopPhase == ShopPhase.main) {
        List<String> options = ["COMPRAR", "VENDER", "ROUBAR", "SAIR"];
        for (int i = 0; i < options.length; i++) {
          
          // Opcional: Pinta a palavra "ROUBAR" de vermelho para destacar o perigo
          TextPaint paintToUse = normalPaint;
          if (i == shopCursor){
             paintToUse = selectPaint;
          }else if (i == 2) {
            paintToUse = TextPaint(style: const TextStyle(color: Palette.vermelho, fontSize: 16, fontFamily: 'pixelFont'));
          }
          paintToUse.render(canvas, (i == shopCursor ? "> " : "  ") + options[i], Vector2(20, startY + (i * 30)));
        }
      }
      
      // DESENHA O MENU DE COMPRA
      else if (currentShopPhase == ShopPhase.buy) {
        titlePaint.render(canvas, "COMPRAR", Vector2(20, startY - 15));
        for (int i = 0; i < shopInventory.length; i++) {
          Item item = shopInventory[i];
          String texto = "${item.name} - \$${item.value}";
          (i == shopCursor ? selectPaint : normalPaint).render(canvas, (i == shopCursor ? "> " : "  ") + texto, Vector2(20, startY + 15 +(i * 30)));
        }
      }

      // DESENHA O MENU DE VENDA (Seu inventário)
      else if (currentShopPhase == ShopPhase.sell) {
        titlePaint.render(canvas, "VENDER", Vector2(20, startY - 15));
        for (int i = 0; i < playerCombatStats.inventory.length; i++) {
          Item item = playerCombatStats.inventory[i];
          int valorVenda = (item.value * 0.5).floor(); // Metade do preço
          if (valorVenda < 1) valorVenda = 1;
          
          bool isEquipped = (item == playerCombatStats.equippedWeapon || item == playerCombatStats.equippedArmor || item == playerCombatStats.equippedShield);
          String sufixo = isEquipped ? " (Equipado)" : "";
          
          String texto = "${item.name} (x${item.quantity})$sufixo - Vender por: \$$valorVenda";
          
          TextPaint paintToUse = normalPaint;
          if (i == shopCursor) {
            paintToUse = selectPaint;
          } else if (isEquipped) {
            paintToUse = TextPaint(style: const TextStyle(color: Palette.cinzaEsc, fontSize: 16, fontFamily: 'pixelFont'));
          }
          (i == shopCursor ? selectPaint : paintToUse).render(canvas, (i == shopCursor ? "> " : "  ") + texto, Vector2(20, startY + 15 +(i * 30)));
        }
      }

      // DESENHA A CONFIRMAÇÃO DE VENDA
      else if (currentShopPhase == ShopPhase.confirmSell && itemToSell != null) {
        int valorVenda = (itemToSell!.value * 0.5).floor();
        if (valorVenda < 1) valorVenda = 1;

        titlePaint.render(canvas, "Vender ${itemToSell!.name} por \$$valorVenda?", Vector2(20, startY));
        
        List<String> options = ["VENDER", "SAIR"];
        for (int i = 0; i < options.length; i++) {
          (i == shopCursor ? selectPaint : normalPaint).render(canvas, (i == shopCursor ? "> " : "  ") + options[i], Vector2(20, startY + 40 + (i * 30)));
        }
      }

      else if (currentShopPhase == ShopPhase.steal) {
        // Título intimidador
        TextPaint dangerTitle = TextPaint(style: const TextStyle(color: Palette.vermelho, fontSize: 24, fontFamily: 'pixelFont'));
        dangerTitle.render(canvas, "ROUBAR?", Vector2(20, startY - 15));
        
        for (int i = 0; i < shopInventory.length; i++) {
          Item item = shopInventory[i];
          String texto = "${item.name} (Grátis!)";
          (i == shopCursor ? selectPaint : normalPaint).render(canvas, (i == shopCursor ? "> " : "  ") + texto, Vector2(20, startY + 15 +(i * 30)));
        }
      }
    }

    if (currentState == GameState.exploration && isPassTurnPromptOpen) {
      double promptWidth = size.x * 0.8;
      double promptHeight = 100;
      double promptX = (size.x - promptWidth) / 2;
      double promptY = (size.y - promptHeight) / 2;

      final promptRect = Rect.fromLTWH(promptX, promptY, promptWidth, promptHeight);
      canvas.drawRect(promptRect, Paint()..color = Palette.preto);
      canvas.drawRect(promptRect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      final titleSpan = const TextSpan(
        text: "Passar o turno?",
        style: TextStyle(color: Palette.branco, fontSize: 18, fontFamily: 'pixelFont', fontWeight: FontWeight.bold)
      );
      final titlePainter = TextPainter(text: titleSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(minWidth: promptWidth, maxWidth: promptWidth);
      titlePainter.paint(canvas, Offset(promptX, promptY + 15));


      final optionsSpan = const TextSpan(
        text: "[A] Sim   [B] Não",
        style: TextStyle(color: Palette.amarelo, fontSize: 16, fontFamily: 'pixelFont')
      );
      final optionsPainter = TextPainter(text: optionsSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(minWidth: promptWidth, maxWidth: promptWidth);
      optionsPainter.paint(canvas, Offset(promptX, promptY + 45));

    }

    if (currentState == GameState.inventory) {
      _drawInventoryScreen(canvas);
    }
    
    if (currentState == GameState.levelUp) {
      final overlayRect = Rect.fromLTWH(0, 0, size.x, size.y * 0.66);
      canvas.drawRect(overlayRect, Paint()..color = Palette.preto);

      final borderPaint = Paint()..color = Palette.roxo..style = PaintingStyle.stroke..strokeWidth = 3;
      canvas.drawRect(overlayRect.deflate(15), borderPaint);

      final titleSpan = const TextSpan(
        text: "Distribua seus Pontos",
        style: TextStyle(color: Palette.roxo, fontSize: 22, fontFamily: 'pixelFont', fontWeight: FontWeight.bold)
      );
      final titlePainter = TextPainter(text: titleSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: size.x);
      titlePainter.paint(canvas, Offset((size.x - titlePainter.width) / 2, 40));

      final ptSpan = TextSpan(
        text: "Pontos Disponíveis: $pointsToDistribute",
        style: TextStyle(color: pointsToDistribute > 0 ? Palette.amarelo : Palette.verde, fontSize: 18, fontFamily: 'pixelFont')
      );
      final ptPainter = TextPainter(text: ptSpan, textDirection: TextDirection.ltr)..layout();
      ptPainter.paint(canvas, Offset((size.x - ptPainter.width) / 2, 100));

      List<String> labels = [
        "FORÇA (STR) : ${playerCombatStats.str.toInt()} (+ $tempStr)",
        "CONSTITUIÇÃO (CON) : ${playerCombatStats.con.toInt()} (+ $tempCon)",
        "SABEDORIA (WIS) : ${playerCombatStats.wis.toInt()} (+ $tempWis)",
        "== CONFIRMAR MELHORIAS =="
      ];

      for (int i = 0; i < labels.length; i++) {
        bool isSelected = (i == levelUpCursor);
        Color textColor = isSelected ? Colors.yellow : Colors.white;
        if (i == 3) textColor = isSelected ? Colors.greenAccent : Colors.purpleAccent;
        
        String prefix = isSelected ? "> " : "  ";

        final labelSpan = TextSpan(
          text: "$prefix${labels[i]}",
          style: TextStyle(color: textColor, fontSize: 18, fontFamily: 'pixelFont', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)
        );
        final labelPainter = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)..layout();
        labelPainter.paint(canvas, Offset(40, 160 + (i * 45)));
      }

      final helpSpan = const TextSpan(
        text: "[▲▼] Mudar Linha [◄►] Alterar Pontos [A] Confirmar",
        style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'pixelFont')
      );
      final helpPainter = TextPainter(text: helpSpan, textDirection: TextDirection.ltr)..layout();
      helpPainter.paint(canvas, Offset((size.x - helpPainter.width) / 2, size.y * 0.66 - 40));
    }

    
    if (activeMessage != null) {
      double boxWidth = size.x * 0.8; double boxHeight = 100;
      double boxX = (size.x - boxWidth) / 2; double boxY = size.y - boxHeight - 80; 
      final rect = Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight);
      canvas.drawRect(rect, Paint()..color = Palette.preto);
      canvas.drawRect(rect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
      final textSpan = TextSpan(text: '$activeMessage\n\n[A] Continuar', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'pixelFont', fontWeight: FontWeight.bold));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
      textPainter.layout(minWidth: boxWidth, maxWidth: boxWidth);
      textPainter.paint(canvas, Offset(boxX, boxY + (boxHeight - textPainter.height) / 2));
    }
  }

  void _drawInventoryScreen(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(2, 2, size.x-3, size.y-3), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
    final titlePainter = TextPainter(text: TextSpan(text: "INVENTÁRIO", style: TextStyle(fontFamily: 'pixelFont', color: Palette.amarelo, fontSize: 24, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    titlePainter.paint(canvas, Offset((size.x - titlePainter.width) / 2, 30));

    double startY = 80;
    for (int i = 0; i < playerCombatStats.inventory.length; i++) {
      Item item = playerCombatStats.inventory[i];
      Color textColor = i == inventoryCursor ? Palette.branco : Palette.cinzaCla;
      String equipTag = (playerCombatStats.equippedWeapon == item || playerCombatStats.equippedArmor == item || playerCombatStats.equippedShield == item) ? " [Equipado]" : "";
      String qtyTag = item.quantity > 1 ? " x${item.quantity}" : "";
      
      //canvas.drawRect(Rect.fromLTWH(20, startY + (i * 50), size.x - 40, 50), 
      //Paint()..color = i == inventoryCursor ? Palette.azul.withOpacity(0.3) : Colors.transparent);    

      TextPainter(text: TextSpan(text: (i == inventoryCursor ? "> " : "  "), style: TextStyle(fontFamily: 'pixelFont', color: 
      textColor, fontSize: 24)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(18, startY + (i * 50) + 12));

      //(i == shopCursor ? selectPaint : normalPaint).render(canvas, (i == shopCursor ? "> " : "  ") + options[i], 
      //Vector2(20, startY + 40 + (i * 30)));

      TextPaint(style: const TextStyle(color: Palette.verdeCla, fontSize: 16, fontFamily: 'pixelFont'));
      try {
        ui.Image itemImg = images.fromCache(item.imagePath);
        Color tint = item.cor; 
        final tintPaint = Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
        
        canvas.drawImageRect(
          itemImg,
          Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()),
          Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), 
          tintPaint 
        );
      } catch (e) {
        debugPrint("⚠️ ERRO: A imagem '${item.imagePath}' não foi carregada no onLoad!");
        canvas.drawRect(
          Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), 
          Paint()..color = Colors.pinkAccent
        );
      }

      TextPainter(text: TextSpan(text: "${item.name}$equipTag$qtyTag", style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 16)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(76, startY + (i * 50) + 12));
    }

    if (isActionMenuOpen) {
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
      TextPainter(text: const TextSpan(text: "A - Confirmar\nB - Cancelar", style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 16)), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout()..paint(canvas, Offset(size.x/2 - 50, size.y/2 - 20));
    }
    if (isItemActionMenuOpen) {
      double menuWidth = 200;
      double menuHeight = 130;
      double menuX = (size.x - menuWidth) / 2 + 50; 
      double menuY = (size.y - menuHeight) / 2;

      final menuRect = Rect.fromLTWH(menuX, menuY, menuWidth, menuHeight);
      canvas.drawRect(menuRect, Paint()..color = Palette.preto);
      canvas.drawRect(menuRect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      List<String> options = ["Equipar/Usar", "Descartar", "Cancelar"];
      
      for (int i = 0; i < options.length; i++) {
        Color textColor = (i == itemActionCursor) ? Palette.amarelo : Palette.branco;
        String prefix = (i == itemActionCursor) ? "> " : "  ";
        
        final optSpan = TextSpan(
          text: "$prefix${options[i]}", 
          style: TextStyle(color: textColor, fontSize: 18, fontFamily: 'pixelFont', fontWeight: FontWeight.bold)
        );
        final optPainter = TextPainter(text: optSpan, textDirection: TextDirection.ltr)..layout();
        optPainter.paint(canvas, Offset(menuX + 15, menuY + 20 + (i * 35)));
      }
    }
  }

  Future<void> changeWeaponSprite(String imagePath) async {
    ui.Image newWeapon = await images.load(imagePath);
    weaponSheet = newWeapon;
    combatOverlay.equipNewWeapon(weaponSheet);
  }

  Future<void> changeArmorSprite(String imagePath) async {
    ui.Image newArmor = await images.load(imagePath);
    armorSheet = newArmor;
    combatOverlay.equipNewArmor(armorSheet);
  }

  Future<void> changeShieldSprite(String imagePath) async {
    ui.Image newShield = await images.load(imagePath);
    shieldSheet = newShield;
    combatOverlay.equipNewShield(shieldSheet);
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    if (isLoaded) { renderer.size = gameSize; combatOverlay.size = gameSize; }
  }

  void openManual() {
    currentState = GameState.manual;
    overlays.remove('MainMenu');
    overlays.add('ManualMenu');   
  }

  void closeManual() {
    currentState = GameState.mainMenu;
    overlays.remove('ManualMenu'); 
    overlays.add('MainMenu');      
  }

  void resetGame() {
    for (var enemy in combatOverlay.enemies) {
      enemy.removeFromParent(); 
    }
    combatOverlay.enemies.clear();
    _messageQueue.clear(); 

    playerCombatStats.str = 5;
    playerCombatStats.con = 5;
    playerCombatStats.wis = 5;
    playerCombatStats.hp = playerCombatStats.maxHp;
    playerCombatStats.stamina = playerCombatStats.con*3;
    playerCombatStats.mana = playerCombatStats.wis*3;
    playerCombatStats.currentPhase = CombatPhase.idle;

    _initializeInventory();
    
    dungeon.level = 1;
    player.hasKey = false;

    dungeon.width = mapSize;
    dungeon.height = mapSize;
    dungeon.generateProceduralMap();
    player.x = dungeon.playerSpawn.x;
    player.y = dungeon.playerSpawn.y;
    player.facing = Direction.north;

    shopInventory = [
      ItemDatabase.clava,
      ItemDatabase.gambeson,
      ItemDatabase.escudoFerro,
      ItemDatabase.staminaPotion
    ];

    combatOverlay.enemies.clear();
  }

  void startGame() {
    resetGame();
    currentState = GameState.exploration;
    overlays.remove('GameOver');
    overlays.remove('MainMenu');
  }

  void togglePause() {
    if(currentState == GameState.mainMenu || currentState == GameState.gameOver) return;
    if (currentState == GameState.exploration || currentState == GameState.combat) {
      previousState = currentState;
      currentState = GameState.paused;
      overlays.add('PauseMenu');
    } else if (currentState == GameState.paused) {
      currentState = previousState;
      overlays.remove('PauseMenu');
    }
  }

  void quitToMainMenu() {
    overlays.remove('PauseMenu');
    overlays.remove('GameOver');
    currentState = GameState.mainMenu;
    overlays.add('MainMenu');
  }

  void handlePlayerDeath() async { 
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('save_game');
    hasSavedGame = false;
    combatOverlay.enemies.clear();
    currentState = GameState.gameOver;
    overlays.add('GameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (shakeTimer > 0) {
      shakeTimer -= dt;
    }

    if (leftTapTimer > 0) leftTapTimer -= dt;
    if (rightTapTimer > 0) rightTapTimer -= dt;
    
    if (currentState == GameState.mainMenu || currentState == GameState.paused || currentState == GameState.gameOver) return;

    if (currentState == GameState.manual) {
      double scrollSpeed = 450.0; // Velocidade da rolagem em pixels por segundo
      if (upPressed) {
        if (manualScrollController != null && manualScrollController!.hasClients) {
          manualScrollController!.jumpTo(
            (manualScrollController!.offset - scrollSpeed * dt).clamp(0.0, manualScrollController!.position.maxScrollExtent),
          );
        }
      } else if (downPressed) {
        if (manualScrollController != null && manualScrollController!.hasClients) {
          manualScrollController!.jumpTo(
            (manualScrollController!.offset + scrollSpeed * dt).clamp(0.0, manualScrollController!.position.maxScrollExtent),
          );
        }
      }
      return; // Garante o congelamento do labirinto em segundo plano
    }

    if (currentState == GameState.exploration) {
      if (activeMessage != null) return;
      
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          dungeon.markExplored(player.x + dx, player.y + dy);
        }
      }

      if (explorationMoveCooldown > 0) {
        explorationMoveCooldown -= dt;
      }

      if (activeMessage == null && !isPassTurnPromptOpen) {
        if (explorationMoveCooldown <= 0) {
          if (upPressed) {
            startInput(GameInput.up);
            explorationMoveCooldown = explorationMoveCooldownTime;
          } 
          else if (downPressed) {
            startInput(GameInput.down);
            explorationMoveCooldown = explorationMoveCooldownTime;
          } 
          else if (leftPressed) {
            startInput(GameInput.left);
            explorationMoveCooldown = explorationMoveCooldownTime;
          } 
          else if (rightPressed) {
            startInput(GameInput.right);
            explorationMoveCooldown = explorationMoveCooldownTime;
          }
        }
      }
      
      if (dungeon.keyPosition != null && player.x == dungeon.keyPosition!.x && player.y == dungeon.keyPosition!.y) {
        player.hasKey = true;
        dungeon.keyPosition = null;
        showMessage("Você encontrou a Chave da Masmorra!");
      }

      TileType playerTile = dungeon.getTile(player.x, player.y);

      if (playerTile == TileType.boss){
        dungeon.grid[player.y][player.x] = TileType.floor; 
        switch(dungeon.level){
          case 3:
            _triggerSpecificEncounter(EnemyType.boss1);
            break;
          case 6:
            _triggerSpecificEncounter(EnemyType.boss2);
            break;
          case 9:
            _triggerSpecificEncounter(EnemyType.boss3);
            break;
        }
        
      }

      while (dungeon.roamingEnemies.length < 3) {
        dungeon.spawnEnemyAwayFrom(Point(player.x, player.y), 7);
      }

      return;
    }

    if (playerCombatStats.currentPhase == CombatPhase.exiting && playerCombatStats.animTimer <= 0) {
      currentState = GameState.exploration;
      combatOverlay.enemies.clear();
      playerCombatStats.currentPhase = CombatPhase.idle;
      leftPressed = false; rightPressed = false; downPressed = false;
      return; 
    }
    
    if (playerCombatStats.currentPhase == CombatPhase.entering || playerCombatStats.currentPhase == CombatPhase.exiting) return;

    if (activeMessage != null) {
      return; 
    }

    if (currentState == GameState.combat && playerCombatStats.isCharging) {

      bool hasHeavyAttackShield = playerCombatStats.equippedShield?.hasChargeAttack ?? false;  
      bool hasHeavyAttackWeapon = playerCombatStats.equippedWeapon?.hasChargeAttack ?? false;  

      if (hasHeavyAttackShield || hasHeavyAttackWeapon) {
        playerCombatStats.chargeTimer += dt;
        playerCombatStats.animTimer = 0.5; // Força a pose de Windup
        
        if (playerCombatStats.chargeTimer >= 1.0 && (playerCombatStats.chargeTimer - dt) < 1.0) {
          playerCombatStats.applyEffect(0.1, Palette.vermelhoCla);
        }
        return; 
      }
    }

    bool hasRegen = playerCombatStats.equippedArmor?.hasRegen ?? false; 

    if(hasRegen){
      regenTmr -= dt;
      if(regenTmr<=0){
        regenTmr = 2;
        if(playerCombatStats.hp < maxHp){
          playerCombatStats.hp += 2;
        }
      }
    }

    // --- 1. ATUALIZA A IA E COLISÃO ---
    if (combatOverlay.enemies.isNotEmpty) {
      Rect pHitbox = playerCombatStats.getHitbox(size);
      bool weaponHasReach = playerCombatStats.equippedWeapon?.hasReach ?? false;
      bool weaponHasStun = playerCombatStats.equippedWeapon?.hasStun ?? false;
      bool weaponHasPoison = playerCombatStats.equippedWeapon?.hasPoisonAttack ?? false;
      bool shieldHasPoison = playerCombatStats.equippedShield?.hasPoisonAttack ?? false;
      
      if (playerCombatStats.currentPhase == CombatPhase.active && !playerCombatStats.attackHit) {
        playerCombatStats.attackHit = true;

        bool projAtk = playerCombatStats.equippedWeapon?.projetil ?? false;

        if(projAtk){
          if(playerCombatStats.mana >= 3){
            playerCombatStats.mana -= 3;
            projetil();
          }
        }else{
        }

        for (var enemy in combatOverlay.enemies) {
          if (!enemy.isFrontRow && !weaponHasReach) continue;
          if (!enemy.isDying && pHitbox.overlaps(enemy.getHurtbox(size))){
            double damage = playerCombatStats.str.toDouble();
            if (playerCombatStats.equippedWeapon != null) damage += playerCombatStats.equippedWeapon!.power;
            if (playerCombatStats.isHeavyAttack) {
              damage *= 2.0;
            }
            if(enemy.isVulnerable || playerCombatStats.isHeavyAttack){
              playerCombatStats.reflex = false;
              bool isCrit = Random().nextDouble() * 100 < playerCombatStats.critChance;
              double stun = 0.4;
              if (isCrit) {
                damage *= playerCombatStats.critMultiplier;
                combatOverlay.addFloatingText("*CRIT.*", enemy.getHurtbox(size), Palette.amarelo);
                if(weaponHasStun){
                  stun = 1;
                  combatOverlay.addFloatingText("*STUN*", enemy.getHurtbox(size), Palette.amarelo);
                } 
              }
              enemy.hp -= damage;
              enemy.applyHitStun(stun);
              if(weaponHasPoison || shieldHasPoison) enemy.isPoison = true;
              playerCombatStats.recoverMana();
              FlameAudio.play('sfx/hit.wav');
            }else{
              enemy.applyHitGuard(0.3);
              playerCombatStats.stamina -= 4;
              playerCombatStats.stamina = max(playerCombatStats.stamina - playerCombatStats.staminaCost,0);
              combatOverlay.addFloatingText("BLOCK!", enemy.getHurtbox(size), Palette.cinzaCla);
              FlameAudio.play('sfx/block.wav');
            }
            
            if (enemy.hp <= 0) {
              FlameAudio.play('sfx/enemy_die.wav');
              enemy.hp = 0;
              enemy.isDying = true; 
              encounterEssence += enemy.dropEssence; 
              encounterDrop.addAll(enemy.drop);
            }
          }
        }
      }
    }

    combatOverlay.enemies.removeWhere((e) => !e.isAlive);

    if (combatOverlay.enemies.isEmpty && !_victoryProcessed && playerCombatStats.currentPhase != CombatPhase.exiting) {
      if (playerCombatStats.currentPhase == CombatPhase.idle) {
        _victoryProcessed = true;
        playerCombatStats.essence += encounterEssence; 
        playerCombatStats.isGuarding = false; 

        //showMessage("Vitória! Você purificou a área e obteve +${encounterEssence.toInt()} Essências!");
        int dropChance = isMimic? 100 : isBoss? 50: 10;
        for (var drop in encounterDrop){
          if(Random().nextInt(100) <= dropChance) {
            receiveItem(drop); 
          }
        }

        showMessage("Vitória! Você obteve +${encounterEssence.toInt()} Essências!", onDismiss: () {
          _endEncounter();
        });
      }
    }

    // --- 2. MOVIMENTAÇÃO DO JOGADOR ---
    bool isFreeToMove = activeMessage == null && (playerCombatStats.currentPhase == CombatPhase.idle || playerCombatStats.currentPhase == CombatPhase.walk || playerCombatStats.currentPhase == CombatPhase.guard);

    if (isFreeToMove) {
      bool noShield = playerCombatStats.equippedShield?.noShield ?? false;
      bool shieldWalkSlow = playerCombatStats.equippedShield?.walkSlow ?? false;
      bool armorWalkSlow = playerCombatStats.equippedArmor?.walkSlow ?? false;
      bool shieldWalkFast = playerCombatStats.equippedShield?.walkFast ?? false;
      int peso = playerCombatStats.equippedArmor?.peso ?? 0;
      double moveSpeedPenalty = 0;

      if(shieldWalkSlow || armorWalkSlow) moveSpeedPenalty = 1;
      if(shieldWalkFast) moveSpeedPenalty = -1;

      moveSpeedPenalty += peso*0.2;

      if (downPressed && !playerCombatStats.cansado && !noShield) {
        playerCombatStats.isGuarding = true; 
        playerCombatStats.currentPhase = CombatPhase.guard; 
      } else {
        playerCombatStats.isGuarding = false;
        if (dashTimer > 0) {
          dashTimer -= dt;
          playerCombatStats.strafePosition += dashDirection * dashVel * dt; 
        } else {
          if (leftPressed) { playerCombatStats.strafePosition -= (playerCombatStats.moveSpeed - moveSpeedPenalty) * dt; playerCombatStats.currentPhase = CombatPhase.walk; } 
          else if (rightPressed) { playerCombatStats.strafePosition += (playerCombatStats.moveSpeed - moveSpeedPenalty) * dt; playerCombatStats.currentPhase = CombatPhase.walk; } 
          else { playerCombatStats.currentPhase = CombatPhase.idle; }
        }
        playerCombatStats.strafePosition = playerCombatStats.strafePosition.clamp(-1.0, 1.0);
      }
    } else if (activeMessage != null) {
      playerCombatStats.currentPhase = CombatPhase.idle;
    }
  }

  void _endEncounter() { 
    playerCombatStats.currentPhase = CombatPhase.exiting; 
    playerCombatStats.animTimer = 1; 
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Mantém a leitura dos direcionais fluida (Isso já funciona perfeitamente)
    leftPressed = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    rightPressed = keysPressed.contains(LogicalKeyboardKey.arrowRight); 
    downPressed = keysPressed.contains(LogicalKeyboardKey.arrowDown);
    upPressed = keysPressed.contains(LogicalKeyboardKey.arrowUp);
    
    // =========================================================================
    // 1. TRATAMENTO DE SEGURAR E SOLTAR (Ataque Carregado)
    // =========================================================================
    
    // Botão A (Tecla Z) - Ataque / Interação
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (event is KeyDownEvent) {
        startInput(GameInput.buttonA); // Inicia o Windup e a Carga
      } else if (event is KeyUpEvent) {
        stopInput(GameInput.buttonA);  // Executa o Ataque (Forte ou Fraco)
      }
    }

   /* // Botão B (Tecla X) - Inventário / Uso de Item
    if (event.logicalKey == LogicalKeyboardKey.keyX) {
      if (event is KeyDownEvent) {
        startInput(GameInput.buttonB);
      } else if (event is KeyUpEvent) {
        stopInput(GameInput.buttonB); 
      }
    }
  */
    // =========================================================================
    // 2. TRATAMENTO DE TOQUE SIMPLES (Só importa quando afunda a tecla)
    // =========================================================================
    if (event is KeyDownEvent) {
      
      if (event.logicalKey == LogicalKeyboardKey.keyP || event.logicalKey == LogicalKeyboardKey.escape) {
        togglePause();
      }

      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        showHitboxes = !showHitboxes;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        if(currentState == GameState.exploration){
          //triggerEncounter();
          _triggerSpecificEncounter(EnemyType.orc);
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.keyX) {
        startInput(GameInput.buttonB);
      }

      // Navegação de Menus e Nivelamento
      if (currentState == GameState.levelUp && activeMessage == null) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) startInput(GameInput.up);
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) startInput(GameInput.down);
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) startInput(GameInput.left);
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) startInput(GameInput.right);
      } 
      else if (currentState == GameState.inventory || currentState == GameState.combat || currentState == GameState.shop 
       || currentState == GameState.manual || currentState == GameState.mainMenu || currentState == GameState.paused) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) startInput(GameInput.up);
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) startInput(GameInput.down);
      }
    }
    
    return KeyEventResult.handled;
  }

  void _performAttack() {
    if (playerCombatStats.stamina >= 0 && !playerCombatStats.cansado && (playerCombatStats.currentPhase == CombatPhase.idle || playerCombatStats.currentPhase == CombatPhase.walk)) {
      if (playerCombatStats.staminaInfiniteTmr <= 0) {
        playerCombatStats.stamina -= playerCombatStats.staminaCost;
      }
      if(playerCombatStats.stamina <=0){
        playerCombatStats.stamina = 0;
        playerCombatStats.cansado = true; 
      }
      playerCombatStats.staminaTmr = playerCombatStats.staminaRegenDelay; 
      playerCombatStats.currentPhase = CombatPhase.windup;
      playerCombatStats.animTimer = playerCombatStats.windupTime;
      combatOverlay.playerAttackWindupTicker.reset();
      combatOverlay.weaponAttackWindupTicker.reset();
      playerCombatStats.comboCount++;
      if (playerCombatStats.comboCount > 3) playerCombatStats.comboCount = 1;
      playerCombatStats.comboTimer = 1.0;
    }
  }

  Future<void> projetil() async {
    final ui.Image img = await images.load('effects/magia.png');
    double damage = playerCombatStats.equippedWeapon?.power ?? 5; 
    FlameAudio.play('sfx/fire.wav');
     combatOverlay.add(PlayerProjectile(
       playerCombatStats.strafePosition, 0.75, 1.5, damage * playerCombatStats.wis * 0.5 , Palette.azulCla, width: 48, height: 48
       ,img : img
    ));
  }

  void applyEnemyDamage(Enemy enemy) {
    double defense = playerCombatStats.equippedArmor?.power ?? 0; 
    double dmg = max(1, enemy.damage - defense);
    bool unblockable = enemy.isHeavyAttack;
    
    if(dashTimer>0 || playerCombatStats.invencibleTmr > 0)return;

    if (playerCombatStats.isGuarding && !unblockable) {
      FlameAudio.play('sfx/block.wav');
      if (playerCombatStats.stamina >= 0) {
        if (playerCombatStats.staminaInfiniteTmr <= 0){
          playerCombatStats.stamina -= (8 - playerCombatStats.equippedShield!.power); 
        } 
        playerCombatStats.stamina = playerCombatStats.stamina.clamp(0, playerCombatStats.con * 3);
        if (playerCombatStats.stamina <= 0) {
          playerCombatStats.cansado = true;
        }
        playerCombatStats.flashColor = Palette.cinza;
        playerCombatStats.hitFlashTimer = 0.1; 
      }/* else { 
        playerCombatStats.stamina = 0; 
        playerCombatStats.hp -= dmg; 
        playerCombatStats.applyHitStun(0.3);
        combatOverlay.playerHitTicker.reset(); 
        combatOverlay.weaponHitTicker.reset();
      }*/
    } else { 
      FlameAudio.play('sfx/hit.wav');
      playerCombatStats.hp -= dmg; 
      playerCombatStats.applyHitStun(0.3); 
      combatOverlay.playerHitTicker.reset(); 
      combatOverlay.weaponHitTicker.reset();
      //conterPoison
        bool counterPoison = playerCombatStats.equippedArmor?.hasPoisonAttack ?? false;
        if(counterPoison){
          
          for (var enemy in combatOverlay.enemies) {
            if (enemy.isAlive) {
              
              double distance = (enemy.strafePosition - playerCombatStats.strafePosition).abs();
              
              if (distance <= 0.2) {
                enemy.isPoison = true;
              }
            }
          }
        }
    }
    if (playerCombatStats.hp < 0) playerCombatStats.hp = 0;
  }

  void triggerEncounter() {
    FlameAudio.play('sfx/encounter.wav');
    maxHp = playerCombatStats.hp;
    encounterEssence = 0;         
    encounterDrop.clear();
    _victoryProcessed = false; 
    isMimic = false;
    isBoss = false;
    currentState = GameState.combat;
    int numEnemies = Random().nextInt(4) + 1; 
    List<Enemy> spawnedEnemies = [];
    List<Enemy Function()> iniPool = [
      () => SlimeEnemy(),
      () => GoblinEnemy(),
      () => SpiderEnemy(),
      () => BatEnemy(),
      () => OrcEnemy(),
    ];
    
    /*
    if(dungeon.level >= 2){
      iniPool.add(() => BatEnemy());
    }

    if(dungeon.level >= 3){
      iniPool.add(() => OrcEnemy());
    }
    */
    if(dungeon.level >= 4){
      iniPool = [
        () => OvoEnemy(),
        () => WormEnemy(),
        () => FungoEnemy(),
        () => Fungo2Enemy(), 
        () => BugEnemy(),   
        () => InfectadoEnemy(), 
      ];
    }
  /*
    if(dungeon.level >= 5){
      iniPool.add(() => BugEnemy());
    }

    if(dungeon.level >= 6){
      iniPool.add(() => InfectadoEnemy());
    }
  */
    if(dungeon.level >= 7){
      iniPool = [
        () => EsqueletoEnemy(),
        () => DollEnemy(),
        () => InfectadoEnemy(),
        () => JesterEnemy(),
        () => NagaEnemy(),
        () => HandEnemy()
      ];
    }
/*
    if(dungeon.level >= 8){
      iniPool.add(() => NagaEnemy());
    }

    if(dungeon.level >= 8){
      iniPool.add(() => HandEnemy());
    }
*/
    for (int i = 0; i < numEnemies; i++) {
      int enemyType = Random().nextInt(iniPool.length); 
      Enemy newEnemy = iniPool[enemyType]();
      
      newEnemy.strafePosition = -0.6 + (i * 0.6); 

      if (i >= 2) { 
        newEnemy.isFrontRow = false;
        newEnemy.visualScale = 0.65;  
        newEnemy.visualYOffset = -0.15;
        newEnemy.visualDarkness = 0.6;
      }

      spawnedEnemies.add(newEnemy);
    }
    combatOverlay.startEncounter(spawnedEnemies);
    playerCombatStats.currentPhase = CombatPhase.entering; playerCombatStats.animTimer = 1;
  }

  void _triggerSpecificEncounter(EnemyType type) {
    encounterEssence = 0; 
    maxHp = playerCombatStats.hp;
    encounterDrop.clear();
    _victoryProcessed = false;
    isMimic = false;
    isBoss = false;
    currentState = GameState.combat;
    Enemy newEnemy;
    switch (type) {
        case EnemyType.slime: newEnemy = SlimeEnemy(); break;
        case EnemyType.goblin: newEnemy = GoblinEnemy(); break;
        case EnemyType.spider: newEnemy = SpiderEnemy(); break;
        case EnemyType.orc: newEnemy = OrcEnemy(); break;
        case EnemyType.mimic: 
          isMimic = true;
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
            ItemDatabase.machado,
            ItemDatabase.firePillar,
            ItemDatabase.escudoMadeira,
            ItemDatabase.escudoFerro,
            ItemDatabase.piercingShot,
            ItemDatabase.toxicCloud,
          ];

          List<Item> unownedEquipments = allEquipments.where((equip) {
            return !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
          }).toList();    
          
          var mimic = MimicEnemy()
              ..strafePosition = 0
              ..isFrontRow = true
              ..drop.add(unownedEquipments[Random().nextInt(unownedEquipments.length)]);
          combatOverlay.startEncounter([mimic]);
          playerCombatStats.currentPhase = CombatPhase.entering; 
          playerCombatStats.animTimer = 1;
          return;

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
        case EnemyType.boss1: isBoss = true; newEnemy = OrcChefe(); break;
        case EnemyType.boss3: isBoss = true; newEnemy = MagoEnemy(); break;
        case EnemyType.boss2:

          isBoss = true;

          var bug1 = BugEnemy()
              ..strafePosition = 0.4
              ..isFrontRow = true;

          var bug2 = BugEnemy()
              ..strafePosition = -0.4
              ..isFrontRow = true;
        
          var queen = RainhaInsetoEnemy()
            ..strafePosition = 0.0
            ..isFrontRow = false;
          
          var leftClaw = GarraRainhaEnemy(queen, -0.24)
            ..isFrontRow = false;
            
          var rightClaw = GarraRainhaEnemy(queen, 0.24)
            ..isFrontRow = false
            ..isFlipped = true;

          combatOverlay.startEncounter([bug1, bug2, queen, leftClaw, rightClaw]);
          playerCombatStats.currentPhase = CombatPhase.entering; 
          playerCombatStats.animTimer = 1;
          return;
        
        case EnemyType.jester: newEnemy = JesterEnemy(); break;  
        case EnemyType.naga: newEnemy = NagaEnemy(); break;  
        default: newEnemy = SlimeEnemy(); break;
      }
    newEnemy.strafePosition = 0.0; 
    combatOverlay.startEncounter([newEnemy]);
    playerCombatStats.currentPhase = CombatPhase.entering; playerCombatStats.animTimer = 1;
  }

  void startInput(GameInput input) {
    if (activeMessage != null) { if (input == GameInput.buttonA) dismissMessage(); return; }
    if (currentState == GameState.shop) {
      // Movimentação do Cursor
      if (input == GameInput.up) {
        shopCursor--;
        FlameAudio.play('sfx/hover.wav'); 
      }
      if (input == GameInput.down) {
        shopCursor++;
        FlameAudio.play('sfx/hover.wav');
      }

      // --- LIMITES DO CURSOR ---
      int maxCursor = 0;
      if (currentShopPhase == ShopPhase.main) maxCursor = 3; 
      else if (currentShopPhase == ShopPhase.buy) maxCursor = max(0, shopInventory.length - 1);
      else if (currentShopPhase == ShopPhase.steal) maxCursor = max(0, shopInventory.length - 1);
      else if (currentShopPhase == ShopPhase.sell) maxCursor = max(0, playerCombatStats.inventory.length - 1);
      else if (currentShopPhase == ShopPhase.confirmSell) maxCursor = 1; 

      if (shopCursor < 0) shopCursor = maxCursor;
      if (shopCursor > maxCursor) shopCursor = 0;

      // --- BOTÃO B (VOLTAR) ---
      if (input == GameInput.buttonB) {
        if (currentShopPhase == ShopPhase.main) {
          currentState = GameState.exploration; // Sai da loja de vez
        } else {
          currentShopPhase = ShopPhase.main; // Volta pro menu principal da loja
          shopCursor = 0;
        }
      }

      // --- BOTÃO A (CONFIRMAR) ---
      if (input == GameInput.buttonA) {
        
        // FASE 1: MENU PRINCIPAL DA LOJA
        if (currentShopPhase == ShopPhase.main) {
          FlameAudio.play('sfx/confirm.wav');
          if (shopCursor == 0) { currentShopPhase = ShopPhase.buy; shopCursor = 0; } 
          else if (shopCursor == 1) { currentShopPhase = ShopPhase.sell; shopCursor = 0; } 
          else if (shopCursor == 2) { currentShopPhase = ShopPhase.steal; shopCursor = 0; } 
          else if (shopCursor == 3) { currentState = GameState.exploration; }
        }
        
        // FASE 2: COMPRAR ITENS
        else if (currentShopPhase == ShopPhase.buy) {
          if (shopInventory.isEmpty) return;
          Item itemToBuy = shopInventory[shopCursor];
          
          if (playerCombatStats.inventory.length >= playerCombatStats.maxInventory && 
              !playerCombatStats.inventory.any((i) => i.name == itemToBuy.name)) {
            showMessage("Inventário cheio!");
          } else if (_getPlayerCoins() >= itemToBuy.value) {
            _removeCoins(itemToBuy.value);
            
            // Adiciona no inventário do jogador (Lógica de stack ou novo slot)
            try {
              var existingItem = playerCombatStats.inventory.firstWhere((i) => i.name == itemToBuy.name);
              existingItem.quantity++;
            } catch (e) {
              // Simula um clone do item para não bugar a referência da loja
              Item clonedItem = Item(itemToBuy.name, itemToBuy.type, itemToBuy.imagePath, itemToBuy.power, value: itemToBuy.value, quantity: 1, cor: itemToBuy.cor);
              playerCombatStats.inventory.add(clonedItem);
            }
            itemToBuy.quantity--;
            if (itemToBuy.quantity <= 0) {
              shopInventory.remove(itemToBuy);
              
              // Se o cursor estava no final da lista e o item sumiu, recua o cursor em 1
              if (shopCursor >= shopInventory.length && shopCursor > 0) {
                shopCursor--;
              }
              
              // Se o jogador comprou absolutamente TUDO, volta pro menu principal!
              if (shopInventory.isEmpty) {
                currentShopPhase = ShopPhase.main;
                shopCursor = 0;
              }
            }
            FlameAudio.play('sfx/confirm.wav'); // Som de caixa registradora
            //showMessage("Comprado: ${itemToBuy.name}");
          } else {
            FlameAudio.play('sfx/denied.wav');
            //showMessage("Moedas insuficientes!");
          }
        }

        // FASE 3: ESCOLHER ITEM PARA VENDER
        else if (currentShopPhase == ShopPhase.sell) {
          if (playerCombatStats.inventory.isEmpty) return;
          itemToSell = playerCombatStats.inventory[shopCursor];
          
          if (itemToSell!.name == "moeda") {
            FlameAudio.play('sfx/denied.wav');
            showMessage("Você não pode vender dinheiro!");
            return;
          }

          if (itemToSell == playerCombatStats.equippedWeapon) { 
            FlameAudio.play('sfx/denied.wav');
            showMessage("Desequipa o item antes de o vender!");
            return; // Bloqueia o avanço para a tela de confirmação
          }

          if (itemToSell == playerCombatStats.equippedArmor) { 
            FlameAudio.play('sfx/denied.wav');
            showMessage("Desequipa o item antes de o vender!");
            return; // Bloqueia o avanço para a tela de confirmação
          }

          if (itemToSell == playerCombatStats.equippedShield) { 
            FlameAudio.play('sfx/denied.wav');
            showMessage("Desequipa o item antes de o vender!");
            return; // Bloqueia o avanço para a tela de confirmação
          }
          FlameAudio.play('sfx/confirm.wav');
          currentShopPhase = ShopPhase.confirmSell;
          shopCursor = 0;
        }

        // FASE 4: CONFIRMAR VENDA
        else if (currentShopPhase == ShopPhase.confirmSell) {
          if (shopCursor == 0 && itemToSell != null) { // VENDER
            int valorVenda = (itemToSell!.value * 0.25).ceil(); 
            if (valorVenda < 1) valorVenda = 1;

            _addCoins(valorVenda);
            
            itemToSell!.quantity--;
            if (itemToSell!.quantity <= 0) {
              playerCombatStats.inventory.remove(itemToSell);
            }
            FlameAudio.play('sfx/use_item.wav');
            currentShopPhase = ShopPhase.sell; // Volta pra lista de venda
            shopCursor = 0;
            itemToSell = null;
          } else if (shopCursor == 1) { // SAIR
            currentShopPhase = ShopPhase.sell;
            shopCursor = 0;
          }
        }

        else if (currentShopPhase == ShopPhase.steal) {
          if (shopInventory.isEmpty) return;
          Item itemToSteal = shopInventory[shopCursor];
          
          if (playerCombatStats.inventory.length >= playerCombatStats.maxInventory && 
              !playerCombatStats.inventory.any((i) => i.name == itemToSteal.name)) {
            showMessage("roubar!");
          } else {
            // 1. Adiciona o item de graça ao jogador
            try {
              var existingItem = playerCombatStats.inventory.firstWhere((i) => i.name == itemToSteal.name);
              existingItem.quantity++;
            } catch (e) {
              Item clonedItem = Item(itemToSteal.name, itemToSteal.type, itemToSteal.imagePath, itemToSteal.power, value: itemToSteal.value, quantity: 1, cor: itemToSteal.cor);
              playerCombatStats.inventory.add(clonedItem);
            }

            // 2. Toca um som de alarme/erro
            // FlameAudio.play('sfx/alarm.wav'); 

            // 3. Deleta a loja do mapa
             int nx = player.x; int ny = player.y;
             dungeon.grid[ny][nx] = TileType.floor;
            
            // 4. Inicia o combate com o Mercador 
            showMessage("LADRÃO! VOCÊ PAGARÁ COM A VIDA!");
            _triggerSpecificEncounter(EnemyType.goblinShop);
            
            // Força a saída do menu
            return;
          }
        }
      }
      return; // Interrompe a função aqui para o jogador não andar no fundo!
    }

    if (currentState == GameState.manual) {
      if (input == GameInput.buttonB) {
        FlameAudio.play('sfx/decline.wav');
        closeManual();
      }
      return;
    }
    if (input == GameInput.pause) { togglePause(); return; }

    if (currentState == GameState.paused) {
      if (input == GameInput.up) {
        FlameAudio.play('sfx/hover.wav');
        // Sobe o cursor (0, 1, 2)
        pauseMenuCursor.value = (pauseMenuCursor.value - 1 + 3) % 3;
      }
      if (input == GameInput.down) {
        FlameAudio.play('sfx/hover.wav');
        // Desce o cursor
        pauseMenuCursor.value = (pauseMenuCursor.value + 1) % 3;
      }
      if (input == GameInput.buttonA) {
        FlameAudio.play('sfx/confirm.wav');
        if (pauseMenuCursor.value == 0) {
          togglePause(); // CONTINUAR
        } else if (pauseMenuCursor.value == 1) {
          quitToMainMenu(); // VOLTAR
        } else if (pauseMenuCursor.value == 2) {
          showHitboxes = !showHitboxes; // DEBUG
        }
      }
      return;
    }

    if (currentState == GameState.mainMenu) {
      // Se tiver jogo salvo, temos 3 botões. Se não, apenas 2.
      int maxOptions = hasSavedGame ? 3 : 2; 

      if (input == GameInput.up) {
        FlameAudio.play('sfx/hover.wav');
        mainMenuCursor.value = (mainMenuCursor.value - 1 + maxOptions) % maxOptions;
      }
      if (input == GameInput.down) {
        FlameAudio.play('sfx/hover.wav');
        mainMenuCursor.value = (mainMenuCursor.value + 1) % maxOptions;
      }
      if (input == GameInput.buttonA) {
        FlameAudio.play('sfx/confirm.wav');
        
        if (hasSavedGame) {
          if (mainMenuCursor.value == 0) {
             // NOVO: Carrega o Jogo Salvo!
             loadGame().then((_) {
               currentState = GameState.exploration;
               overlays.remove('MainMenu');
             });
          } else if (mainMenuCursor.value == 1) {
             startGame(); // Substitui o save (Novo Jogo)
          } else if (mainMenuCursor.value == 2) {
             openManual();
          }
        } else {
          // Sem save game
          if (mainMenuCursor.value == 0) startGame();
          else if (mainMenuCursor.value == 1) openManual();
        }
      }
      return; 
    }

    if (currentState == GameState.gameOver) {
      // Se tiver jogo salvo, temos 3 botões. Se não, apenas 2.
      int maxOptions = 2; 

      if (input == GameInput.up) {
        FlameAudio.play('sfx/hover.wav');
        mainMenuCursor.value = (mainMenuCursor.value - 1 + maxOptions) % maxOptions;
      }
      if (input == GameInput.down) {
        FlameAudio.play('sfx/hover.wav');
        mainMenuCursor.value = (mainMenuCursor.value + 1) % maxOptions;
      }
      if (input == GameInput.buttonA) {
        FlameAudio.play('sfx/confirm.wav');

        if (mainMenuCursor.value == 0) startGame();
        else if (mainMenuCursor.value == 1) quitToMainMenu();
        
      }
      return; 
    }

    if (currentState == GameState.levelUp) {
      FlameAudio.play('sfx/hover.wav');
      if (input == GameInput.up) {
        levelUpCursor = (levelUpCursor - 1 + 4) % 4; 
      }
      if (input == GameInput.down) {
        levelUpCursor = (levelUpCursor + 1) % 4;
      }
      
      if (input == GameInput.right || (input == GameInput.buttonA && levelUpCursor < 3)) {
        FlameAudio.play('sfx/hover.wav');
        if (pointsToDistribute > 0 && levelUpCursor < 3) {
          pointsToDistribute--;
          if (levelUpCursor == 0) tempStr++;
          if (levelUpCursor == 1) tempCon++;
          if (levelUpCursor == 2) tempWis++;
        }
      }
      
      if (input == GameInput.left || input == GameInput.buttonB) {
        if (levelUpCursor == 0 && tempStr > 0) { tempStr--; pointsToDistribute++; }
        if (levelUpCursor == 1 && tempCon > 0) { tempCon--; pointsToDistribute++; }
        if (levelUpCursor == 2 && tempWis > 0) { tempWis--; pointsToDistribute++; }
        if (levelUpCursor == 3 && input == GameInput.buttonB) {
          currentState = GameState.exploration;
        }
      }

      if (input == GameInput.buttonA && levelUpCursor == 3) {
        if (pointsToDistribute == 0) {
          playerCombatStats.essence -= levelUpCost;
          playerCombatStats.str += tempStr;
          playerCombatStats.con += tempCon;
          playerCombatStats.wis += tempWis;
          playerCombatStats.recalculateMaxHp();
          
          dungeon.grid[player.y][player.x] = TileType.floor;
          showMessage("Atributos Melhorados! O Altar desmorona...");
          currentState = GameState.exploration;
        } else {
          showMessage("Distribua todos os 3 pontos antes de confirmar!");
        }
      }
      return;
    }

    if (currentState == GameState.inventory) {
      if (playerCombatStats.inventory.isEmpty) {
        isItemActionMenuOpen = false;
      }

      if (isItemActionMenuOpen) {
        if (input == GameInput.up) {
          FlameAudio.play('sfx/hover.wav');
          itemActionCursor = (itemActionCursor - 1 + 3) % 3;
        } else if (input == GameInput.down) {
          FlameAudio.play('sfx/hover.wav');
          itemActionCursor = (itemActionCursor + 1) % 3;
        } else if (input == GameInput.buttonA) {
          FlameAudio.play('sfx/confirm.wav');
          if (itemActionCursor == 0) {
            Item item = playerCombatStats.inventory[inventoryCursor];
            _useOrEquipItem(item); 
            isItemActionMenuOpen = false;
          } else if (itemActionCursor == 1) {
            dropSelectedItem(inventoryCursor);
            isItemActionMenuOpen = false;
            if (inventoryCursor >= playerCombatStats.inventory.length) {
              inventoryCursor = max(0, playerCombatStats.inventory.length - 1);
            }
          } else if (itemActionCursor == 2) {
            isItemActionMenuOpen = false;
          }
        } else if (input == GameInput.buttonB || input == GameInput.pause) {
          FlameAudio.play('sfx/decline.wav');
          isItemActionMenuOpen = false; 
        }
      } 
      else {
        if (input == GameInput.up) {
          FlameAudio.play('sfx/hover.wav');
          //inventoryCursor = max(0, inventoryCursor - 1);
          inventoryCursor -= 1;
          if(inventoryCursor<0) inventoryCursor = playerCombatStats.inventory.length - 1;
        } else if (input == GameInput.down) {
          FlameAudio.play('sfx/hover.wav');
          //inventoryCursor = min(playerCombatStats.inventory.length - 1, inventoryCursor + 1);
          inventoryCursor += 1;
          if(inventoryCursor>playerCombatStats.inventory.length - 1) inventoryCursor = 0;
        } else if (input == GameInput.buttonA && playerCombatStats.inventory.isNotEmpty) {
          FlameAudio.play('sfx/confirm.wav');
          isItemActionMenuOpen = true;
          itemActionCursor = 0;
        } else if (input == GameInput.buttonB || input == GameInput.pause) {
          FlameAudio.play('sfx/decline.wav');
          currentState = GameState.exploration; 
        }
      }
      return; 
    }
    
    if (currentState == GameState.exploration) {
      if (isPassTurnPromptOpen) {
        if (input == GameInput.buttonA) {
          isPassTurnPromptOpen = false; 
          _onPlayerStepped(); 
        } else if (input == GameInput.buttonB) {
          isPassTurnPromptOpen = false; 
        }
        return;
      }

      if (activeMessage != null) { if (input == GameInput.buttonA) dismissMessage(); return; }
      if (input == GameInput.up) { 
        if (player.move(true, dungeon)){
          _onPlayerStepped(); 
          FlameAudio.play('sfx/step.wav');
        } else {
          renderer.triggerWallBump(forward: true);
          FlameAudio.play('sfx/landing.wav');
        } 
      }
      if (input == GameInput.down) { 
        if (player.move(false, dungeon)){
          _onPlayerStepped(); 
          FlameAudio.play('sfx/step.wav');
        } else {
          renderer.triggerWallBump(forward: true);
          FlameAudio.play('sfx/landing.wav');
        } 
      }
      if (input == GameInput.left){ 
        player.turn(false);
        FlameAudio.play('sfx/step.wav');
      }
      if (input == GameInput.right) { 
        player.turn(true);
        FlameAudio.play('sfx/step.wav');
      }
      if (input == GameInput.buttonA) {
        Point<int> currentPos = Point(player.x, player.y);
        
        if (dungeon.droppedItems.containsKey(currentPos) && dungeon.droppedItems[currentPos]!.isNotEmpty) {
          Item itemToPick = dungeon.droppedItems[currentPos]!.first;
          
          if (playerCombatStats.inventory.length < playerCombatStats.maxInventory) {
            dungeon.droppedItems[currentPos]!.removeAt(0); 
            receiveItem(itemToPick); 
          } else {
            showMessage("Inventário Cheio! Não consegue pegar ${itemToPick.name}.");
          }
          return; 
        }
        _interact(); 
      }
      
      if (input == GameInput.buttonB) { 
        // /*
        FlameAudio.play('sfx/confirm.wav');
        currentState = GameState.inventory; 
        inventoryCursor = 0; 
        isActionMenuOpen = false; 
        isItemActionMenuOpen = false; 
        // */
        //_triggerSpecificEncounter(EnemyType.naga);
        //triggerEncounter();
      }
      return; 
    } 
    
    // --- MODO COMBATE ---
    if (currentState == GameState.combat) {
      if (activeMessage != null) { 
        if (input == GameInput.buttonA) dismissMessage(); 
        return; 
      }

      bool easyDashShield = playerCombatStats.equippedShield?.easyDash ?? false; 
      bool easyDashArmor = playerCombatStats.equippedArmor?.easyDash ?? false; 
      bool chargeAttackShield = playerCombatStats.equippedShield?.hasChargeAttack ?? false; 
      bool chargeAttackWeapon = playerCombatStats.equippedWeapon?.hasChargeAttack ?? false; 

      int peso = playerCombatStats.equippedArmor?.peso ?? 0; 

      double dcusto = dashCusto + peso*2 ;
      if (easyDashShield || easyDashArmor) dcusto = dashCusto/2;
      
      if (input == GameInput.left) {
        leftPressed = true;
        if (leftTapTimer > 0) {
          playerCombatStats.stamina -= dcusto;
          dashTimer = dashDur; 
          dashDirection = -1.0;
          leftTapTimer = 0.0; 
        } else {
          leftTapTimer = 0.25; 
        }
      }
      if (input == GameInput.right) {
        rightPressed = true;
        if (rightTapTimer > 0) {
          playerCombatStats.stamina -= dashCusto;
          dashTimer = dashDur;
          dashDirection = 1.0;
          rightTapTimer = 0.0;
        } else {
          rightTapTimer = 0.25;
        }
      }
      if (input == GameInput.down) downPressed = true;
      if (input == GameInput.buttonA) {
        if(chargeAttackShield || chargeAttackWeapon){
          if (playerCombatStats.currentPhase == CombatPhase.idle) {
            playerCombatStats.currentPhase = CombatPhase.windup;
            playerCombatStats.isCharging = true;
            playerCombatStats.chargeTimer = 0.0;
            playerCombatStats.isHeavyAttack = false;
            playerCombatStats.animTimer = 0.5; // Reseta o temporizador visual da animação
          }
        }else{
          _performAttack();
        }
        // 
        
      }
      
      if (input == GameInput.up && playerCombatStats.consumables.isNotEmpty) {
        selectedConsumableIndex++;
        if (selectedConsumableIndex >= playerCombatStats.consumables.length) selectedConsumableIndex = 0;
      }
      if (input == GameInput.buttonB && playerCombatStats.consumables.isNotEmpty) {
        Item sel = playerCombatStats.consumables[selectedConsumableIndex];
        _useCombatConsumable(sel);
      }
    }
  }
  
  void stopInput(GameInput input) {
    if (input == GameInput.left) leftPressed = false;
    if (input == GameInput.right) rightPressed = false;
    if (input == GameInput.down) downPressed = false;
    if (input == GameInput.up) upPressed = false;

    if (currentState == GameState.combat && input == GameInput.buttonA) {
      if (playerCombatStats.isCharging) {
        playerCombatStats.isCharging = false;

        double custoStaminaBase = playerCombatStats.staminaCost;

        // Se segurou por 1.0 segundo ou mais, é um ataque pesado!
        if (playerCombatStats.chargeTimer >= 1.0) {
          playerCombatStats.isHeavyAttack = true;
          playerCombatStats.stamina = max(playerCombatStats.stamina - (custoStaminaBase * 1.5), 0.0);
        } else {
          playerCombatStats.isHeavyAttack = false;
          playerCombatStats.stamina = max(playerCombatStats.stamina - custoStaminaBase, 0.0);
        }

        // Transiciona para a fase ativa de dano
        playerCombatStats.currentPhase = CombatPhase.active;
        playerCombatStats.animTimer = 0.15; // Tempo que o hit box fica ativo na tela
        playerCombatStats.attackHit = false;
      }
    }
  }

  void onTouchStart(GameInput input) {
    if (input == GameInput.up) upPressed = true;
    if (input == GameInput.down) downPressed = true;
    if (input == GameInput.left) leftPressed = true;
    if (input == GameInput.right) rightPressed = true;

    explorationMoveCooldown = explorationMoveCooldownTime;
  }

  void _useOrEquipItem(Item item) async {
    String fileName = item.imagePath.split('/').last;

    if (item.type == ItemType.weapon) { 
      if (item.str > playerCombatStats.str){
        FlameAudio.play('sfx/denied.wav');
        showMessage("você precisa de ${item.str.toString()} de força para equipar");
      }else{
        playerCombatStats.equippedWeapon = item; 
        if (item.onUse != null) item.onUse!(item, this);
        await changeWeaponSprite('actors/$fileName'); 
      }
      
    }
    else if (item.type == ItemType.armor) { 
      playerCombatStats.equippedArmor = item; 
      if (item.onUse != null) item.onUse!(item, this);
      await changeArmorSprite('actors/$fileName'); 

      int peso = playerCombatStats.equippedArmor?.peso ?? 0;
      double staminaDelay = 0.5;
      if (peso == 2) staminaDelay = 0.6;
      else if(peso == 3) staminaDelay = 1.0;
      playerCombatStats.staminaRegenDelay = staminaDelay;
    }
    else if (item.type == ItemType.shield) { 
      playerCombatStats.equippedShield = item; 
      if (item.onUse != null) item.onUse!(item, this);
      await changeShieldSprite('actors/$fileName'); 
    }
    else if (item.type == ItemType.consumable) { 
      if (item.onUse != null) item.onUse!(item, this);
      FlameAudio.play('sfx/use_item.wav');
      _consumeItem(item);
    }
    else if (item.type == ItemType.coin) { 
      showMessage("Guarde isso para usar durante as batalhas!");
    }
  }

  void _useCombatConsumable(Item item) {
    if (item.type == ItemType.consumable) {
      if (item.onUse != null) item.onUse!(item, this);
      _consumeItem(item); 
      FlameAudio.play('sfx/use_item.wav');
    } 
    else if (item.type == ItemType.spell) {
      if (playerCombatStats.mana >= item.manaCost) {
        playerCombatStats.mana -= item.manaCost; 
        if (item.onUse != null) item.onUse!(item, this);
      } else {
        combatOverlay.addFloatingText("Mana insuficiente!", playerCombatStats.getHurtbox(size), Palette.cinzaCla);
      }
    }
  }

  void _consumeItem(Item item) {
    item.quantity--;
    if (item.quantity <= 0) {
      playerCombatStats.inventory.remove(item);
      if (selectedConsumableIndex >= playerCombatStats.consumables.length) selectedConsumableIndex = 0;
      if (inventoryCursor >= playerCombatStats.inventory.length) inventoryCursor = 0;
    }
  }

  void _onPlayerStepped() {
    dungeon.advanceSpikes();
    dungeon.advancePoison();
    playerCombatStats.recoverMana();
    if (dungeon.getTile(player.x, player.y) == TileType.spike && dungeon.spikeState == 3) {
      playerCombatStats.hp -= 5; 
      playerCombatStats.applyHitStun(0.3); 
      showMessage("Você pisou em uma armadilha de espinhos!");
      if (playerCombatStats.hp <= 0) handlePlayerDeath();
    }

    if (dungeon.getTile(player.x, player.y) == TileType.poison && (dungeon.poisonState == 3 || dungeon.poisonState == 4)) {
      playerCombatStats.poisonTmr = 10; 
      playerCombatStats.applyHitStun(0.3); 
      showMessage("Você pisou em uma armadilha de veneno!");
    }

    if (playerCombatStats.poisonTmr > 0){
      playerCombatStats.poisonTmr --;
      if(playerCombatStats.hp > 1)playerCombatStats.hp -= 1;   
      playerCombatStats.applyEffect(0.3,Palette.verde);
      if (playerCombatStats.poisonTmr == 0)showMessage("Você se sente melhor!");
    }
    dungeon.moveEnemies(Point(player.x, player.y));

    for (int i = 0; i < dungeon.roamingEnemies.length; i++) {
      if (dungeon.roamingEnemies[i].x == player.x && dungeon.roamingEnemies[i].y == player.y) {
        dungeon.roamingEnemies.removeAt(i); 
        triggerEncounter(); 
        break; 
      }
    }
  }

  void _interact() {
    TileType playerTile = dungeon.getTile(player.x, player.y);

    if (playerTile == TileType.floor || playerTile == TileType.entry || playerTile == TileType.openChest
     || playerTile == TileType.spike || playerTile == TileType.poison) {
      Point<int> currentPos = Point(player.x, player.y);
      if (!dungeon.droppedItems.containsKey(currentPos) || dungeon.droppedItems[currentPos]!.isEmpty) {
        isPassTurnPromptOpen = true; 
        return;
      }
    }

    if (playerTile == TileType.shop) {
      openShop();
    }

    if (playerTile == TileType.font) {
      playerCombatStats.hp = playerCombatStats.maxHp;
      playerCombatStats.mana = playerCombatStats.wis*3;
      playerCombatStats.vfxTimer = 0.5;
      playerCombatStats.vfxColor = Palette.vermelho;
      showMessage("Você se sente revigorado!");
    }

    if (playerTile == TileType.fontPoison) {
      playerCombatStats.poisonTmr = 10; 
      playerCombatStats.vfxTimer = 0.5;
      playerCombatStats.vfxColor = Palette.verde;
      showMessage("Você se sente mal!");
    }

    if (playerTile == TileType.shrine) {
      int cost = levelUpCost;
      if (playerCombatStats.essence >= cost) {
        pointsToDistribute = 3;
        tempStr = 0; tempCon = 0; tempWis = 0;
        levelUpCursor = 0;
        currentState = GameState.levelUp; 
      } else {
        showMessage("Altar Antigo: Exige $cost Essências (Você tem: ${playerCombatStats.essence.toInt()})");
      }
      return;
    }

    if (playerTile == TileType.door) {
      if (player.hasKey) {
        showMessage("A porta se abre. Descendo para o Andar ${dungeon.level + 1}...", onDismiss: () async {
          //player.floorLevel++;
          player.hasKey = false;
          dungeon.width += 5; 
          dungeon.height += 5;
          dungeon.level ++;
          dungeon.droppedItems.clear();
          dungeon.generateProceduralMap(); 
          player.x = dungeon.playerSpawn.x;
          player.y = dungeon.playerSpawn.y;
          player.facing = Direction.north;

          /*
          List<Item> armas = [ItemDatabase.espadaCurta, ItemDatabase.espadaLonga, ItemDatabase.machado,ItemDatabase.lanca,ItemDatabase.claymore,ItemDatabase.clava,ItemDatabase.warhammer,];
          List<Item> armaduras = [ItemDatabase.armaduraFerro, ItemDatabase.armaduraCouro,ItemDatabase.armaduraAco, ItemDatabase.gambeson,
          ItemDatabase.armaduraBronze,];
          List<Item> escudos = [ItemDatabase.escudoMadeira, ItemDatabase.escudoFerro,ItemDatabase.escudoTorre,];
          List<Item> pocoes = [ItemDatabase.healthPotion, ItemDatabase.manaPotion, ItemDatabase.staminaPotion, ItemDatabase.reflexPotion,];
          
          List<Item> unownedWeapons = armas.where((equip) {
            return !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
          }).toList();
          List<Item> unownedArmors = armaduras.where((equip) {
            return !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
          }).toList();
          List<Item> unownedShields = escudos.where((equip) {
            return !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
          }).toList();

          unownedWeapons.shuffle();
          unownedArmors.shuffle();
          unownedShields.shuffle();
          pocoes.shuffle();

          shopInventory = [];

          shopInventory.add(unownedWeapons[0]);
          shopInventory.add(unownedArmors[0]);
          shopInventory.add(unownedShields[0]);
          shopInventory.add(pocoes[0]);
        */

          List<Item> items = [
            //armas
            ItemDatabase.espadaCurta, ItemDatabase.espadaLonga, ItemDatabase.machado,ItemDatabase.clava,
            ItemDatabase.lanca,ItemDatabase.claymore,ItemDatabase.warhammer,ItemDatabase.varinha,ItemDatabase.zweihander,
            //armaduras
            ItemDatabase.armaduraFerro, ItemDatabase.armaduraCouro,ItemDatabase.armaduraAco,
            ItemDatabase.armaduraBronze, ItemDatabase.gambeson,
            //escudos
            ItemDatabase.escudoMadeira, ItemDatabase.escudoFerro, ItemDatabase.escudoTorre,
            //magias
            ItemDatabase.firePillar, ItemDatabase.piercingShot, ItemDatabase.toxicCloud,
          ];

          List<Item> consumiveis = [
            //pocoes
            ItemDatabase.healthPotion, ItemDatabase.manaPotion, ItemDatabase.staminaPotion, ItemDatabase.reflexPotion,
            //itens
            ItemDatabase.faca, ItemDatabase.bomb, ItemDatabase.meat, ItemDatabase.web, ItemDatabase.slimeEye,
            ItemDatabase.bugOrgan, ItemDatabase.bola,
          ];

          List<Item> unownedItens = items.where((equip) {
            return !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
          }).toList();

          unownedItens.addAll(consumiveis);

          unownedItens.shuffle();

          shopInventory = [];

          shopInventory.add(unownedItens[0]);
          shopInventory.add(unownedItens[1]);
          shopInventory.add(unownedItens[2]);
          shopInventory.add(unownedItens[3]);

          await saveGame();

          if(dungeon.level >= 10){
            currentState = GameState.gameOver;
            overlays.add('GameOver');
          }
        });
      } else {
        showMessage("A porta está trancada. Encontre a chave.");
      }
    } 
    else if (playerTile == TileType.chest) {
      int chance = Random().nextInt(100);
      
      if (chance < 45) { 
        dungeon.grid[player.y][player.x] = TileType.floor; 
        showMessage("O baú era um MÍMICO!!", onDismiss: () { _triggerSpecificEncounter(EnemyType.mimic); }); 
      
      } else if (chance < 60) { 
        dungeon.grid[player.y][player.x] = TileType.openChest; 
        int loot = Random().nextInt(30) + 10; 
        showMessage("Você achou $loot Essências!", onDismiss: () { playerCombatStats.essence += loot; }); 
      
      } else {
        dungeon.grid[player.y][player.x] = TileType.openChest; 
        
        List<Item> allEquipments = [
          ItemDatabase.espadaCurta,
          ItemDatabase.armaduraFerro,
          ItemDatabase.armaduraAco,
          ItemDatabase.armaduraBronze,
          ItemDatabase.espadaLonga,
          ItemDatabase.zweihander,
          ItemDatabase.varinha,
          ItemDatabase.escudoTorre,
          ItemDatabase.warhammer,
          ItemDatabase.clava,
          ItemDatabase.claymore,
          ItemDatabase.lanca,
          ItemDatabase.armaduraCouro,
          ItemDatabase.machado,
          ItemDatabase.firePillar,
          ItemDatabase.escudoMadeira,
          ItemDatabase.escudoFerro,
          ItemDatabase.piercingShot,
          ItemDatabase.toxicCloud,
        ];

        List<Item> unownedEquipments = allEquipments.where((equip) {
          return !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
        }).toList();

        unownedEquipments.shuffle(); 
        Item newEquipment = unownedEquipments.first;
        newEquipment.quantity = 1; 

        showMessage("Você encontrou um item: ${newEquipment.name}!", onDismiss: () {
          receiveItem(newEquipment);
        });

        /*bool tryEquipment = chance >= 45 && chance < 75;

        if (tryEquipment && unownedEquipments.isNotEmpty) {
          unownedEquipments.shuffle(); 
          Item newEquipment = unownedEquipments.first;
          newEquipment.quantity = 1; 

          showMessage("Você encontrou um item: ${newEquipment.name}!", onDismiss: () {
            receiveItem(newEquipment);
          });
          
        } else {
          List<Item> allConsumables = [
            ItemDatabase.healthPotion,
            ItemDatabase.manaPotion,
            ItemDatabase.bomb,
            ItemDatabase.staminaPotion,
            ItemDatabase.reflexPotion,
          ];

          int totalConsumables = allConsumables.length;
          int randomIndex = Random().nextInt(totalConsumables);
          
          Item droppedItem = allConsumables[randomIndex];
          droppedItem.quantity = 1;

          showMessage("Você encontrou um item: ${droppedItem.name}!", onDismiss: () {
            var existingItems = playerCombatStats.inventory.where((i) => i.name == droppedItem.name).toList();
            if (existingItems.isNotEmpty) {
              existingItems.first.quantity += droppedItem.quantity; 
            } else {
              receiveItem(droppedItem);
            }
          });
        }
        */
      }
    }
    else if (playerTile == TileType.crate) {
      int chance = Random().nextInt(100);
      dungeon.grid[player.y][player.x] = TileType.floor; 
      
      if (chance < 40) { 
        showMessage("Caixa vazia!"); 
      } else {
        List<Item> allConsumables = [
            ItemDatabase.healthPotion,
            ItemDatabase.manaPotion,
            ItemDatabase.bomb,
            ItemDatabase.staminaPotion,
            ItemDatabase.reflexPotion,
            ItemDatabase.meat,
            ItemDatabase.faca,
            ItemDatabase.bugOrgan,
          ];

        int totalConsumables = allConsumables.length;
        int randomIndex = Random().nextInt(totalConsumables);
        
        Item droppedItem = allConsumables[randomIndex];
        droppedItem.quantity = 1;

        showMessage("Você encontrou um item: ${droppedItem.name}!", onDismiss: () {
          var existingItems = playerCombatStats.inventory.where((i) => i.name == droppedItem.name).toList();
          if (existingItems.isNotEmpty) {
            existingItems.first.quantity += droppedItem.quantity; 
          } else {
            receiveItem(droppedItem);
          }
        });
      }
    }
  }
}