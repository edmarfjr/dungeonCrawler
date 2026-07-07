import 'dart:math';
import 'dart:ui' as ui;
import 'package:dungeon_crawler/game/components/core/encounter_manager.dart';
import 'package:dungeon_crawler/game/components/core/save_manager.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart' hide PlayerState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dungeon_crawler/game/components/core/audio_manager.dart';
import 'package:dungeon_crawler/game/components/core/dungeon_map.dart';
import 'package:dungeon_crawler/game/components/core/i18n.dart';
import 'package:dungeon_crawler/game/components/core/minimap_renderer.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/core/player_state.dart';
import 'package:dungeon_crawler/game/components/core/maze_renderer.dart';
import 'package:dungeon_crawler/game/components/entities/combat_entities.dart';
import 'package:dungeon_crawler/game/components/entities/enemy.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:dungeon_crawler/game/components/entities/player_projectile.dart';
import 'package:dungeon_crawler/game/overlays/combat_overlay.dart';

enum GameInput { up, down, left, right, buttonA, buttonB, pause }
enum GameState { mainMenu, intro, exploration, combat, paused, gameOver, inventory, levelUp, manual, shop, vitory, settings, splash }
enum ShopPhase { main, buy, sell, confirmSell, steal }

class GameMessage {
  final String text;
  final VoidCallback? onDismiss;
  GameMessage(this.text, {this.onDismiss});
}

class DungeonCrawlerGame extends FlameGame with KeyboardEvents {
  // --- ESTADOS E MANAGERS ---
  GameState currentState = GameState.splash;
  GameState previousState = GameState.splash;
  GameState previousState2 = GameState.splash;
  
  bool hasSavedGame = false;
  late DungeonMap dungeon;
  late PlayerState player;
  late MazeRenderer renderer;
  late MinimapRenderer minimap;
  late PlayerCombatStats playerCombatStats;
  late CombatOverlay combatOverlay;

  bool _hasStartedMenuMusic = false;

  // --- DICIONÁRIOS DE ASSETS ---
  late Map<EnemyType, ui.Image> enemySheets;
  late Map<EnemyType, ui.Image> enemySlashSprites;
  late ui.Image playerSheet, playerSlashSprite1, playerSlashSprite2;
  late ui.Image weaponSheet, armorSheet, shieldSheet;
  late ui.Image keySprite, doorTexture, doorTexture2, chestSprite, crateSprite, openChestSprite;
  late ui.Image trapImage, trapImage2, trapImage3, roamerSprite, bossSprite, shrineSprite;

  // --- FILA DE MENSAGENS ---
  final List<GameMessage> _messageQueue = []; 
  String? get activeMessage => _messageQueue.isNotEmpty ? _messageQueue.first.text : null;
  
  // --- LOJA E INVENTÁRIO ---
  ShopPhase currentShopPhase = ShopPhase.main;
  int shopCursor = 0, inventoryCursor = 0, itemActionCursor = 0, levelUpCursor = 0;
  int selectedConsumableIndex = 0, pointsToDistribute = 0;
  int tempStr = 0, tempCon = 0, tempWis = 0;
  Item? itemToSell;
  List<Item> shopInventory = [];
  bool isActionMenuOpen = false, isItemActionMenuOpen = false, isPassTurnPromptOpen = false;

  // --- CONTROLES DE COMBATE E EXPLORAÇÃO ---
  bool leftPressed = false, rightPressed = false, downPressed = false, upPressed = false, showHitboxes = false;
  double explorationMoveCooldown = 0.0, explorationMoveCooldownTime = 0.3;
  double leftTapTimer = 0.0, rightTapTimer = 0.0, dashTimer = 0.0;
  double dashDur = 0.1, dashVel = 7.0, dashDirection = 0.0, dashCusto = 14;
  double shakeTimer = 0.0, shakeIntensity = 0.0, runTime = 0.0;
  bool isRunStartAnimating = false;
  double runStartAnimTimer = 0.0;
  bool isMainMenuAnimating = false;
  final double runStartAnimDuration = 1.2;
  double maxHp = 0, regenTmr = 2;
  bool godMode = false, victoryProcessed = true, isBoss = false, isMimic = false;
  double encounterEssence = 0;
  int mapSize = 30;
  List<Item> encounterDrop = [];

  // --- MENUS ---
  ScrollController? manualScrollController;
  final ValueNotifier<int> mainMenuCursor = ValueNotifier<int>(0);
  final ValueNotifier<int> pauseMenuCursor = ValueNotifier<int>(0);
  ValueNotifier<int> settingsCursor = ValueNotifier<int>(0);
  ValueNotifier<bool> settingsRefresh = ValueNotifier<bool>(false);
  final ValueNotifier<int> introInputNotifier = ValueNotifier<int>(0);

  // --- HELPERS DA UI PRÉ-COMPILADOS (Otimização) ---
  late final TextPaint _normalTextPaint;
  late final TextPaint _titleTextPaint;
  late final TextPaint _selectTextPaint;
  late final TextPaint _dangerTextPaint;

  // ===========================================================================
  // GETTERS AUXILIARES
  // ===========================================================================
  String getFormattedRunTime() {
    int totalSeconds = runTime.toInt();
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60; 
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
  
  int get levelUpCost {
    int totalLevel = (playerCombatStats.str + playerCombatStats.con + playerCombatStats.wis).toInt();
    return 50 + (totalLevel * 15);
  }

  int _getPlayerCoins() {
    try { return playerCombatStats.inventory.firstWhere((i) => i.name == "moeda").quantity; } 
    catch (e) { return 0; }
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
      if (coin.quantity <= 0) playerCombatStats.inventory.remove(coin);
    } catch (e) {}
  }

  void showMessage(String text, {VoidCallback? onDismiss}) {
    _messageQueue.add(GameMessage(text, onDismiss: onDismiss));
  }

  void dismissMessage() {
    if (_messageQueue.isNotEmpty) {
      final dismissedMessage = _messageQueue.removeAt(0);
      if (dismissedMessage.onDismiss != null) dismissedMessage.onDismiss!(); 
    }
  }

  void shakeScreen(double duration, double intensity) {
    shakeTimer = duration;
    shakeIntensity = intensity;
  }

  // ===========================================================================
  // INICIALIZAÇÃO (ONLOAD)
  // ===========================================================================
  @override
  Future<void> onLoad() async {
    final prefs = await SharedPreferences.getInstance();
    hasSavedGame = prefs.containsKey('save_game');

    _normalTextPaint = TextPaint(style: const TextStyle(color: Palette.branco, fontSize: 16, fontFamily: 'pixelFont'));
    _titleTextPaint = TextPaint(style: const TextStyle(color: Palette.amarelo, fontSize: 24, fontFamily: 'pixelFont'));
    _selectTextPaint = TextPaint(style: const TextStyle(color: Palette.verdeCla, fontSize: 16, fontFamily: 'pixelFont'));
    _dangerTextPaint = TextPaint(style: const TextStyle(color: Palette.vermelho, fontSize: 16, fontFamily: 'pixelFont'));

    await FlameAudio.audioCache.loadAll([
      'sfx/hit.wav', 'sfx/block.wav', 'sfx/encounter.wav', 'sfx/attack.wav',
      'sfx/enemy_die.wav', 'sfx/use_item.wav', 'sfx/fire.wav', 'sfx/charge.wav',
      'sfx/poison.wav', 'sfx/confirm.wav', 'sfx/hover.wav', 'sfx/step.wav',
      'sfx/landing.wav', 'sfx/denied.wav', 'sfx/thunder.wav'
    ]);
    
    await images.loadAll([
      'itens/dagger.png', 'itens/armor.png', 'itens/potion.png', 'itens/potionVermelha.png',
      'itens/potionVerde.png', 'itens/potionAzul.png', 'itens/potionAmarela.png', 'itens/tanga.png',
      'itens/sword.png', 'itens/longSword.png', 'itens/lanca.png', 'itens/axe.png', 'itens/bomb.png',
      'itens/leatherArmor.png', 'itens/scroll.png', 'itens/woodShield.png', 'itens/ironShield.png',
      'itens/buckler.png', 'itens/slime_eye.png', 'itens/club.png', 'itens/clubOrc.png', 'itens/web.png',
      'itens/meat.png', 'itens/faca.png', 'itens/fire.png', 'itens/poison.png', 'itens/piercing.png',
      'itens/organ.png', 'itens/orcSword.png', 'itens/bracerNaga.png', 'itens/bracerFung.png',
      'itens/armorBug.png', 'itens/bola.png', 'itens/coin.png', 'itens/claymore.png', 'itens/warhammer.png',
      'itens/steelArmor.png', 'itens/bronzeArmor.png', 'itens/towerShield.png', 'itens/gambeson.png',
      'itens/varinha.png', 'itens/zweihander.png', 'itens/chainMail.png', 'itens/raio.png', 'itens/potionPreta.png',
    ]);

    final ui.Image wallImg = await images.load('tilesets/wall.png');
    final ui.Image floorImg = await images.load('tilesets/floor.png');
    final ui.Image wallImg2 = await images.load('tilesets/wall2.png');
    final ui.Image floorImg2 = await images.load('tilesets/floor2.png');
    final ui.Image wallImg3 = await images.load('tilesets/wall1.png');
    final ui.Image floorImg3 = await images.load('tilesets/floor1.png');
    final ui.Image wallImg4 = await images.load('tilesets/tile4.png');
    final ui.Image floorImg4 = await images.load('tilesets/tile4.png');
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
    trapImage3 = await images.load('tilesets/trap3.png');
    
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
      EnemyType.aberraBruto: await images.load('actors/aberraBruto.png'),
      EnemyType.aberraVoa: await images.load('actors/aberraVoador.png'),
      EnemyType.aberraBesta: await images.load('actors/aberraBesta.png'),
      EnemyType.aberraArv: await images.load('actors/aberraFixo.png'),
      EnemyType.aberraCult: await images.load('actors/aberraCultista.png'),
      EnemyType.aberraOvo: await images.load('actors/aberraOvo.png'),
      EnemyType.boss4: await images.load('actors/boss4.png'),
      EnemyType.tentaculo: await images.load('actors/tentaculo.png'),
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
      EnemyType.orc: await images.load('effects/golpe2.png'),
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
      EnemyType.goblinShop: await images.load('effects/golpe2.png'), 
      EnemyType.boss3: await images.load('effects/soco2.png'), 
      EnemyType.aberraBruto: await images.load('effects/porrada.png'), 
      EnemyType.aberraVoa: await images.load('effects/spore.png'), 
      EnemyType.aberraBesta: await images.load('effects/bite2.png'), 
      EnemyType.aberraArv: await images.load('effects/porrada.png'), 
      EnemyType.aberraCult: await images.load('effects/golpe2.png'), 
      EnemyType.boss4: await images.load('effects/bola.png'), 
      EnemyType.tentaculo: await images.load('effects/golpe2.png'), 
    };

    dungeon = DungeonMap(width: mapSize, height: mapSize);
    player = PlayerState(x: dungeon.playerSpawn.x, y: dungeon.playerSpawn.y, facing: Direction.north);

    renderer = MazeRenderer(
      map: dungeon, player: player, 
      wallImage: [wallImg,wallImg2,wallImg3,wallImg4], floorImage: [floorImg,floorImg2,floorImg3,floorImg4],
      doorImage: doorTexture, doorImage2: doorTexture2, keyImage: keySprite, chestImage: chestSprite,
      trapImage: [trapImage,trapImage2,trapImage3], roamerImage: roamerSprite, bossImage: bossSprite,
      shrineImage: shrineSprite, openChestImage: openChestSprite, crateImage: crateSprite,
      shopImage: shopImg, fontImage: fontImg,
    );
    renderer.size = size; 
    add(renderer);

    playerCombatStats = PlayerCombatStats();
    _initializeInventory();
    combatOverlay = CombatOverlay(
      playerStats: playerCombatStats, playerSheetImage: playerSheet, 
      weaponSheetImage: weaponSheet, armorSheetImage: armorSheet, shieldSheetImage: shieldSheet,
      enemySheets: enemySheets, playerSlashImage: [playerSlashSprite1,playerSlashSprite2], enemySlashImages: enemySlashSprites,
    );
    combatOverlay.add(EnemyShadowsRenderer());
    combatOverlay.size = size; add(combatOverlay);

    minimap = MinimapRenderer();
    add(minimap);

    FlameAudio.bgm.initialize();

    await FlameAudio.audioCache.loadAll([
      'music/8-bit-dungeon.mp3',
      'music/main-menu.ogg',
      'music/boss-battle.mp3',
      'music/gameover.mp3'
    ]);
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    if (isLoaded) { renderer.size = gameSize; combatOverlay.size = gameSize; }
  }

  // ===========================================================================
  // FUNÇÕES AUXILIARES DE INVENTÁRIO E SAVE
  // ===========================================================================
  void _initializeInventory() {
    playerCombatStats.inventory = [
      ItemDatabase.adaga, 
      ItemDatabase.tanga, 
      ItemDatabase.bloquel, 
     // ItemDatabase.healthPotion,
      ItemDatabase.strPotion,
    ];
    playerCombatStats.equippedWeapon = playerCombatStats.inventory[0];
    playerCombatStats.equippedArmor = playerCombatStats.inventory[1];
    playerCombatStats.equippedShield = playerCombatStats.inventory[2];
    selectedConsumableIndex = 0;
  }

  void receiveItem(Item newItem) {
    if (newItem.type == ItemType.consumable) {
      var existing = playerCombatStats.inventory.where((i) => i.name == newItem.name).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity += newItem.quantity;
        showMessage(I18n.t('obteve_mais').replaceAll('[quant]', newItem.quantity.toString()).replaceAll('[item]', I18n.t(newItem.name)));
        return;
      }
    }

    if (playerCombatStats.inventory.length < playerCombatStats.maxInventory) {
      playerCombatStats.inventory.add(newItem);
      showMessage(I18n.t('pegou_item').replaceAll('[item]', I18n.t(newItem.name)));
    } else {
      Point<int> pos = Point(player.x, player.y);
      dungeon.droppedItems.putIfAbsent(pos, () => []).add(newItem);
      showMessage(I18n.t('inv_chao').replaceAll('[item]', I18n.t(newItem.name)));
    }
  }

  void dropSelectedItem(int cursorIndex) {
    if (playerCombatStats.inventory.isEmpty) return;
    Item item = playerCombatStats.inventory[cursorIndex];

    if (playerCombatStats.equippedWeapon == item || playerCombatStats.equippedArmor == item || playerCombatStats.equippedShield == item) {
      showMessage(I18n.t('desc_item_eqp'));
      return;
    }

    Point<int> pos = Point(player.x, player.y);
    dungeon.droppedItems.putIfAbsent(pos, () => []).add(item);
    
    playerCombatStats.inventory.removeAt(cursorIndex);
    showMessage(I18n.t('inv_chao').replaceAll('[item]', I18n.t(item.name)));
  }

  Future<void> equipSavedItem(String itemName, ItemType type) async {
    try {
      var item = playerCombatStats.inventory.firstWhere((i) => i.name == itemName);
      String fileName = item.imagePath.split('/').last;

      if (type == ItemType.weapon) { 
        playerCombatStats.equippedWeapon = item; 
        await changeWeaponSprite('actors/$fileName'); 
      }
      else if (type == ItemType.armor) { 
        playerCombatStats.equippedArmor = item; 
        await changeArmorSprite('actors/$fileName'); 
      }
      else if (type == ItemType.shield) { 
        playerCombatStats.equippedShield = item; 
        await changeShieldSprite('actors/$fileName'); 
      }
    } catch (e) {
      debugPrint("Erro ao reequipar item salvo: $itemName");
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

  // ===========================================================================
  // GAME LOOP (UPDATE)
  // ===========================================================================
  @override
  void update(double dt) {
    super.update(dt);

    if (isRunStartAnimating && currentState == GameState.exploration) {
      runStartAnimTimer += dt;
      double animDur = 1;
      double progress = (runStartAnimTimer / runStartAnimDuration).clamp(0.0, animDur);
      double curvedProgress = Curves.linear.transform(progress);
      
      // Em vez de mover o Canvas global, passamos o valor para o Labirinto!
      renderer.yOffsetAnim = (animDur - curvedProgress) * size.y;
      
      if (runStartAnimTimer >= runStartAnimDuration) {
        isRunStartAnimating = false;
        renderer.yOffsetAnim = 0.0; // Garante que tranca na posição 0
      }
      return; 
    }

    if (shakeTimer > 0) shakeTimer -= dt;
    if (leftTapTimer > 0) leftTapTimer -= dt;
    if (rightTapTimer > 0) rightTapTimer -= dt;
    
    if (currentState == GameState.mainMenu || currentState == GameState.paused || currentState == GameState.gameOver) return;

    if (currentState == GameState.exploration || currentState == GameState.combat) {
      runTime += dt;
    }

    if (currentState == GameState.manual) {
      double scrollSpeed = 450.0; 
      if (upPressed && manualScrollController != null && manualScrollController!.hasClients) {
        manualScrollController!.jumpTo((manualScrollController!.offset - scrollSpeed * dt).clamp(0.0, manualScrollController!.position.maxScrollExtent));
      } else if (downPressed && manualScrollController != null && manualScrollController!.hasClients) {
        manualScrollController!.jumpTo((manualScrollController!.offset + scrollSpeed * dt).clamp(0.0, manualScrollController!.position.maxScrollExtent));
      }
      return; 
    }

    switch (currentState) {
      case GameState.exploration: _updateExploration(dt); break;
      case GameState.combat: _updateCombat(dt); break;
      default: break;
    }
  }

  void _updateExploration(double dt) {
    if (activeMessage != null) return;
      
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        dungeon.markExplored(player.x + dx, player.y + dy);
      }
    }

    if (explorationMoveCooldown > 0) explorationMoveCooldown -= dt;

    if (activeMessage == null && !isPassTurnPromptOpen) {
      if (explorationMoveCooldown <= 0) {
        if (upPressed) { startInput(GameInput.up); explorationMoveCooldown = explorationMoveCooldownTime; } 
        else if (downPressed) { startInput(GameInput.down); explorationMoveCooldown = explorationMoveCooldownTime; } 
        else if (leftPressed) { startInput(GameInput.left); explorationMoveCooldown = explorationMoveCooldownTime; } 
        else if (rightPressed) { startInput(GameInput.right); explorationMoveCooldown = explorationMoveCooldownTime; }
      }
    }
    
    if (dungeon.keyPosition != null && player.x == dungeon.keyPosition!.x && player.y == dungeon.keyPosition!.y) {
      player.hasKey = true;
      dungeon.keyPosition = null;
      showMessage(I18n.t('encontrou_key'));
    }

    TileType playerTile = dungeon.getTile(player.x, player.y);

    if (playerTile == TileType.boss){
      dungeon.grid[player.y][player.x] = TileType.floor; 
      switch(dungeon.level){
        case 3: EncounterManager.triggerSpecificEncounter(this, EnemyType.boss1); break;
        case 6: EncounterManager.triggerSpecificEncounter(this, EnemyType.boss2); break;
        case 9: EncounterManager.triggerSpecificEncounter(this, EnemyType.boss3); break;
        case 12: EncounterManager.triggerSpecificEncounter(this, EnemyType.boss4); break;
      }
    }

    while (dungeon.roamingEnemies.length < 3) {
      dungeon.spawnEnemyAwayFrom(Point(player.x, player.y), 7);
    }
  }

  void _updateCombat(double dt) {
    if (playerCombatStats.currentPhase == CombatPhase.exiting && playerCombatStats.animTimer <= 0) {
      currentState = GameState.exploration;
      combatOverlay.enemies.clear();
      playerCombatStats.currentPhase = CombatPhase.idle;
      leftPressed = false; rightPressed = false; downPressed = false;
      return; 
    }
    
    if (playerCombatStats.currentPhase == CombatPhase.entering || playerCombatStats.currentPhase == CombatPhase.exiting) return;
    if (activeMessage != null) return; 

    if (currentState == GameState.combat && playerCombatStats.isCharging) {
      bool hasHeavyAttackShield = playerCombatStats.equippedShield?.hasChargeAttack ?? false;  
      bool hasHeavyAttackWeapon = playerCombatStats.equippedWeapon?.hasChargeAttack ?? false;  

      if (hasHeavyAttackShield || hasHeavyAttackWeapon) {
        playerCombatStats.chargeTimer += dt;
        playerCombatStats.animTimer = 0.5; 
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
        if(playerCombatStats.hp < maxHp) playerCombatStats.hp += 2;
      }
    }

    // IA E COLISÃO
    if (combatOverlay.enemies.isNotEmpty) {
      Rect pHitbox = playerCombatStats.getHitbox(size);
      bool weaponHasReach = playerCombatStats.equippedWeapon?.hasReach ?? false;
      bool weaponHasStun = playerCombatStats.equippedWeapon?.hasStun ?? false;
      bool weaponHasPoison = playerCombatStats.equippedWeapon?.hasPoisonAttack ?? false;
      bool shieldHasPoison = playerCombatStats.equippedShield?.hasPoisonAttack ?? false;
      
      if (playerCombatStats.currentPhase == CombatPhase.active && !playerCombatStats.attackHit) {
        playerCombatStats.attackHit = true;
        bool projAtk = playerCombatStats.equippedWeapon?.projetil ?? false;

        if(projAtk && playerCombatStats.mana >= 3){
          playerCombatStats.mana -= 3;
          projetil();
        }

        for (var enemy in combatOverlay.enemies) {
          if (!enemy.isFrontRow && !weaponHasReach) continue;
          if (!enemy.isDying && pHitbox.overlaps(enemy.getHurtbox(size))){

            double damage = playerCombatStats.str.toDouble();
            if (playerCombatStats.equippedWeapon != null) damage += playerCombatStats.equippedWeapon!.power;
            if (playerCombatStats.isHeavyAttack) damage *= 2.0;
            if(godMode) damage *= 5;

            if(playerCombatStats.buffForcaTmr>0) damage *=2;

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
              AudioManager.playSfx('sfx/hit.wav');
            }else{
              enemy.applyHitGuard(0.3);
              playerCombatStats.stamina -= 4;
              playerCombatStats.stamina = max(playerCombatStats.stamina - playerCombatStats.staminaCost,0);
              combatOverlay.addFloatingText("BLOCK!", enemy.getHurtbox(size), Palette.cinzaCla);
              AudioManager.playSfx('sfx/block.wav');
            }
            
            if (enemy.hp <= 0) {
              AudioManager.playSfx('sfx/enemy_die.wav');
              enemy.hp = 0; enemy.isDying = true; 
              encounterEssence += enemy.dropEssence; 
              encounterDrop.addAll(enemy.drop);
            }
          }
        }
      }
    }

    combatOverlay.enemies.removeWhere((e) => !e.isAlive);

    if (combatOverlay.enemies.isEmpty && !victoryProcessed && playerCombatStats.currentPhase != CombatPhase.exiting) {
      if (playerCombatStats.currentPhase == CombatPhase.idle) {
        victoryProcessed = true;
        playerCombatStats.essence += encounterEssence; 
        playerCombatStats.isGuarding = false; 

        int dropChance = isMimic? 100 : isBoss? 50: 10;
        for (var drop in encounterDrop){
          if(Random().nextInt(100) <= dropChance) receiveItem(drop); 
        }

        showMessage(I18n.t('vitoria_essencias').replaceAll('{essencias}', encounterEssence.toInt().toString()), onDismiss: () {
          _endEncounter();
        });
      }
    }

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

  // ===========================================================================
  // RENDERIZAÇÃO
  // ===========================================================================
  @override
  void render(Canvas canvas) {
    if (shakeTimer > 0) {
      canvas.save();
      double dx = (Random().nextDouble() - 0.5) * shakeIntensity;
      double dy = (Random().nextDouble() - 0.5) * shakeIntensity;
      canvas.translate(dx, dy);
      super.render(canvas);
      canvas.restore();
    }
    else {
      super.render(canvas);
    }

    switch (currentState) {
      case GameState.shop: _renderShop(canvas); break;
      case GameState.inventory: _renderInventory(canvas); break;
      case GameState.levelUp: _renderLevelUp(canvas); break;
      default: break;
    }

    if (currentState == GameState.exploration && isPassTurnPromptOpen) _renderPassTurnPrompt(canvas);
    if (activeMessage != null) _renderMessageQueue(canvas);
  }

  void _renderShop(Canvas canvas) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(2, 2, size.x-3, size.y-3), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      _titleTextPaint.render(canvas, I18n.t('loja'), Vector2(20, 20));
      _normalTextPaint.render(canvas, "${I18n.t('moedas')}${_getPlayerCoins()}", Vector2(20, 50));

      double startY = 90;

      if (currentShopPhase == ShopPhase.main) {
        List<String> options = [I18n.t('comprar'), I18n.t('vender'), I18n.t('roubar'), I18n.t('sair')];
        for (int i = 0; i < options.length; i++) {
          TextPaint paintToUse = _normalTextPaint;
          if (i == shopCursor){ paintToUse = _selectTextPaint; }
          else if (i == 2) { paintToUse = _dangerTextPaint; }
          paintToUse.render(canvas, (i == shopCursor ? "> " : "  ") + options[i], Vector2(20, startY + (i * 30)));
        }
      }
      else if (currentShopPhase == ShopPhase.buy) {
        _titleTextPaint.render(canvas, I18n.t('comprar'), Vector2(20, startY - 15));
        for (int i = 0; i < shopInventory.length; i++) {
          Item item = shopInventory[i];
          Color textColor = i == shopCursor ? Palette.branco : Palette.cinzaCla;
          String equipTag = (playerCombatStats.equippedWeapon == item || playerCombatStats.equippedArmor == item || playerCombatStats.equippedShield == item) ? " ${I18n.t('equipado')}" : "";
          String qtyTag = item.quantity > 1 ? " x${item.quantity}" : "";
          
          TextPainter(text: TextSpan(text: (i == shopCursor ? "> " : "  "), style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 24)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(18, startY + (i * 50) + 12));

          try {
            ui.Image itemImg = images.fromCache(item.imagePath);
            final tintPaint = Paint()..colorFilter = ColorFilter.mode(item.cor, BlendMode.modulate);
            canvas.drawImageRect(itemImg, Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()), Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), tintPaint);
          } catch (e) {
            canvas.drawRect(Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), Paint()..color = Colors.pinkAccent);
          }
          TextPainter(text: TextSpan(text: "${I18n.t(item.name)}$equipTag$qtyTag", style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 16)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(76, startY + (i * 50) + 12));
        }
      }
      else if (currentShopPhase == ShopPhase.sell) {
        _titleTextPaint.render(canvas, I18n.t('vender'), Vector2(20, startY - 15));
        for (int i = 0; i < playerCombatStats.inventory.length; i++) {
          Item item = playerCombatStats.inventory[i];
          bool itEqp = (playerCombatStats.equippedWeapon == item || playerCombatStats.equippedArmor == item || playerCombatStats.equippedShield == item);
          Color textColor = i == shopCursor ? Palette.branco : itEqp? Palette.cinzaEsc:Palette.cinzaCla;
          String equipTag = itEqp ? " ${I18n.t('equipado')}" : "";
          String qtyTag = item.quantity > 1 ? " x${item.quantity}" : "";
          
          TextPainter(text: TextSpan(text: (i == shopCursor ? "> " : "  "), style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 24)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(18, startY + (i * 50) + 12));

          try {
            ui.Image itemImg = images.fromCache(item.imagePath);
            final tintPaint = Paint()..colorFilter = ColorFilter.mode(item.cor, BlendMode.modulate);
            canvas.drawImageRect(itemImg, Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()), Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), tintPaint);
          } catch (e) {
            canvas.drawRect(Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), Paint()..color = Colors.pinkAccent);
          }
          TextPainter(text: TextSpan(text: "${I18n.t(item.name)}$equipTag$qtyTag", style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 16)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(76, startY + (i * 50) + 12));
        }
      }
      else if (currentShopPhase == ShopPhase.confirmSell && itemToSell != null) {
        int valorVenda = (itemToSell!.value * 0.5).floor();
        if (valorVenda < 1) valorVenda = 1;

        _titleTextPaint.render(canvas, "${I18n.t('vender')} ${itemToSell!.name} por \$$valorVenda?", Vector2(20, startY));
        List<String> options = [I18n.t('vender'), I18n.t('sair')];
        for (int i = 0; i < options.length; i++) {
          (i == shopCursor ? _selectTextPaint : _normalTextPaint).render(canvas, (i == shopCursor ? "> " : "  ") + options[i], Vector2(20, startY + 40 + (i * 30)));
        }
      }
      else if (currentShopPhase == ShopPhase.steal) {
        _dangerTextPaint.render(canvas, I18n.t('roubar'), Vector2(20, startY - 15));
        for (int i = 0; i < shopInventory.length; i++) {
          Item item = shopInventory[i];
          Color textColor = i == shopCursor ? Palette.branco : Palette.cinzaCla;
          TextPainter(text: TextSpan(text: (i == shopCursor ? "> " : "  "), style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 24)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(18, startY + (i * 50) + 12));

          try {
            ui.Image itemImg = images.fromCache(item.imagePath);
            final tintPaint = Paint()..colorFilter = ColorFilter.mode(item.cor, BlendMode.modulate);
            canvas.drawImageRect(itemImg, Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()), Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), tintPaint);
          } catch (e) {
            canvas.drawRect(Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), Paint()..color = Colors.pinkAccent);
          }
          TextPainter(text: TextSpan(text: I18n.t(item.name), style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 16)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(76, startY + (i * 50) + 12));
        }
      }
  }

  void _renderPassTurnPrompt(Canvas canvas) {
      double promptWidth = size.x * 0.8;
      double promptHeight = 100;
      double promptX = (size.x - promptWidth) / 2;
      double promptY = (size.y - promptHeight) / 2;
      final promptRect = Rect.fromLTWH(promptX, promptY, promptWidth, promptHeight);
      
      canvas.drawRect(promptRect, Paint()..color = Palette.preto);
      canvas.drawRect(promptRect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      final titleSpan = TextSpan(text: I18n.t('pass_turn'), style: const TextStyle(color: Palette.branco, fontSize: 18, fontFamily: 'pixelFont', fontWeight: FontWeight.bold));
      final titlePainter = TextPainter(text: titleSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(minWidth: promptWidth, maxWidth: promptWidth);
      titlePainter.paint(canvas, Offset(promptX, promptY + 15));

      final optionsSpan =  TextSpan(text: I18n.t('optsA_B'), style: TextStyle(color: Palette.amarelo, fontSize: 16, fontFamily: 'pixelFont'));
      final optionsPainter = TextPainter(text: optionsSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(minWidth: promptWidth, maxWidth: promptWidth);
      optionsPainter.paint(canvas, Offset(promptX, promptY + 45));
  }

  void _renderInventory(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Palette.preto);
    canvas.drawRect(Rect.fromLTWH(2, 2, size.x-3, size.y-3), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
    final titlePainter = TextPainter(text: TextSpan(text: I18n.t('inventario'), style: TextStyle(fontFamily: 'pixelFont', color: Palette.amarelo, fontSize: 24, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    titlePainter.paint(canvas, Offset((size.x - titlePainter.width) / 2, 30));

    double startY = 80;
    for (int i = 0; i < playerCombatStats.inventory.length; i++) {
      Item item = playerCombatStats.inventory[i];
      Color textColor = i == inventoryCursor ? Palette.branco : Palette.cinzaCla;
      String equipTag = (playerCombatStats.equippedWeapon == item || playerCombatStats.equippedArmor == item || playerCombatStats.equippedShield == item) ? " ${I18n.t('equipado')}" : "";
      String qtyTag = item.quantity > 1 ? " x${item.quantity}" : "";
      
      TextPainter(text: TextSpan(text: (i == inventoryCursor ? "> " : "  "), style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 24)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(18, startY + (i * 50) + 12));

      try {
        ui.Image itemImg = images.fromCache(item.imagePath);
        final tintPaint = Paint()..colorFilter = ColorFilter.mode(item.cor, BlendMode.modulate);
        canvas.drawImageRect(itemImg, Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()), Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), tintPaint );
      } catch (e) {
        canvas.drawRect(Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), Paint()..color = Colors.pinkAccent);
      }
      TextPainter(text: TextSpan(text: "${I18n.t(item.name)}$equipTag$qtyTag", style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 16)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(76, startY + (i * 50) + 12));
    }

    if (isActionMenuOpen) {
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
      TextPainter(text:  TextSpan(text: "${I18n.t('a_confirma')}\n${I18n.t('b_cancelar')}", style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 16)), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout()..paint(canvas, Offset(size.x/2 - 50, size.y/2 - 20));
    }
    if (isItemActionMenuOpen) {
      double menuWidth = 200, menuHeight = 130;
      double menuX = (size.x - menuWidth) / 2 + 50, menuY = (size.y - menuHeight) / 2;
      final menuRect = Rect.fromLTWH(menuX, menuY, menuWidth, menuHeight);
      canvas.drawRect(menuRect, Paint()..color = Palette.preto);
      canvas.drawRect(menuRect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      List<String> options = [I18n.t('eqpUse'), I18n.t('eqpDescarte'), I18n.t('cancel')];
      for (int i = 0; i < options.length; i++) {
        Color textColor = (i == itemActionCursor) ? Palette.amarelo : Palette.branco;
        String prefix = (i == itemActionCursor) ? "> " : "  ";
        final optSpan = TextSpan(text: "$prefix${options[i]}", style: TextStyle(color: textColor, fontSize: 18, fontFamily: 'pixelFont', fontWeight: FontWeight.bold));
        final optPainter = TextPainter(text: optSpan, textDirection: TextDirection.ltr)..layout();
        optPainter.paint(canvas, Offset(menuX + 15, menuY + 20 + (i * 35)));
      }
    }
  }

  void _renderLevelUp(Canvas canvas) {
      final overlayRect = Rect.fromLTWH(0, 0, size.x, size.y * 0.66);
      canvas.drawRect(overlayRect, Paint()..color = Palette.preto);
      canvas.drawRect(overlayRect.deflate(15), Paint()..color = Palette.roxo..style = PaintingStyle.stroke..strokeWidth = 3);

      final titlePainter = TextPainter(text: TextSpan(text: I18n.t('distr_pontos'), style: TextStyle(color: Palette.roxo, fontSize: 22, fontFamily: 'pixelFont', fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: size.x);
      titlePainter.paint(canvas, Offset((size.x - titlePainter.width) / 2, 40));

      final ptPainter = TextPainter(text: TextSpan(text: "${I18n.t('pontos_disponiveis')}: $pointsToDistribute", style: TextStyle(color: pointsToDistribute > 0 ? Palette.amarelo : Palette.verde, fontSize: 18, fontFamily: 'pixelFont')), textDirection: TextDirection.ltr)..layout();
      ptPainter.paint(canvas, Offset((size.x - ptPainter.width) / 2, 100));

      List<String> labels = [
        "${I18n.t('forca')}: ${playerCombatStats.str.toInt()} (+ $tempStr)",
        "${I18n.t('constituicao')}: ${playerCombatStats.con.toInt()} (+ $tempCon)",
        "${I18n.t('sabedoria')}: ${playerCombatStats.wis.toInt()} (+ $tempWis)",
        "== ${I18n.t('confirmar_melhorias')} =="
      ];

      for (int i = 0; i < labels.length; i++) {
        bool isSelected = (i == levelUpCursor);
        Color textColor = isSelected ? Colors.yellow : Colors.white;
        if (i == 3) textColor = isSelected ? Colors.greenAccent : Colors.purpleAccent;
        String prefix = isSelected ? "> " : "  ";
        final labelPainter = TextPainter(text: TextSpan(text: "$prefix${labels[i]}", style: TextStyle(color: textColor, fontSize: 18, fontFamily: 'pixelFont', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), textDirection: TextDirection.ltr)..layout();
        labelPainter.paint(canvas, Offset(40, 160 + (i * 45)));
      }

      final helpPainter = TextPainter(text: TextSpan(text: I18n.t('pontos_legenda'), style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'pixelFont')), textDirection: TextDirection.ltr)..layout();
      helpPainter.paint(canvas, Offset((size.x - helpPainter.width) / 2, size.y * 0.66 - 40));
  }

  void _renderMessageQueue(Canvas canvas) {
      double boxWidth = size.x * 0.8, boxHeight = 100;
      double boxX = (size.x - boxWidth) / 2, boxY = size.y - boxHeight - 80; 
      final rect = Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight);
      canvas.drawRect(rect, Paint()..color = Palette.preto);
      canvas.drawRect(rect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);
      final textSpan = TextSpan(text: '$activeMessage\n\n${I18n.t('a_continuar')}', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'pixelFont', fontWeight: FontWeight.bold));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(minWidth: boxWidth, maxWidth: boxWidth);
      textPainter.paint(canvas, Offset(boxX, boxY + (boxHeight - textPainter.height) / 2));
  }

  // ===========================================================================
  // NAVEGAÇÃO DE MENUS GLOBAIS
  // ===========================================================================
  void openManual() { currentState = GameState.manual; overlays.remove('MainMenu'); overlays.add('ManualMenu'); }
  void closeManual() { currentState = GameState.mainMenu; overlays.remove('ManualMenu'); overlays.add('MainMenu'); }
  void openSettings() {
    if(currentState == GameState.paused) overlays.remove('PauseMenu');
    if(currentState == GameState.mainMenu) overlays.remove('MainMenu');
    previousState2 = currentState; currentState = GameState.settings; overlays.add('settings');   
  }
  void closeSettings() {
    if(previousState2 == GameState.mainMenu) overlays.add('MainMenu');
    if(previousState2 == GameState.paused) overlays.add('PauseMenu');
    currentState = previousState2; overlays.remove('settings'); 
  }
  void openShop() {
    currentState = GameState.shop; currentShopPhase = ShopPhase.main;
    shopCursor = 0; itemToSell = null;
  }
  void togglePause() {
    if(currentState == GameState.mainMenu || currentState == GameState.gameOver) return;
    if (currentState == GameState.exploration || currentState == GameState.combat) {
      previousState = currentState; currentState = GameState.paused; AudioManager.pauseBgm(); overlays.add('PauseMenu');
    } else if (currentState == GameState.paused) {
      currentState = previousState; AudioManager.resumeBgm(); overlays.remove('PauseMenu');
    }
  }
  void quitToMainMenu() {
    AudioManager.stopBgm(); overlays.remove('PauseMenu'); overlays.remove('GameOver');
    currentState = GameState.mainMenu; overlays.add('MainMenu');
    //AudioManager.playBgm('music/main-menu.ogg');
  }

  // ===========================================================================
  // GERENCIAMENTO DE INPUTS (KEYBOARD)
  // ===========================================================================
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    leftPressed = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    rightPressed = keysPressed.contains(LogicalKeyboardKey.arrowRight); 
    downPressed = keysPressed.contains(LogicalKeyboardKey.arrowDown);
    upPressed = keysPressed.contains(LogicalKeyboardKey.arrowUp);
    
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (event is KeyDownEvent) startInput(GameInput.buttonA);
      else if (event is KeyUpEvent) stopInput(GameInput.buttonA); 
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyP || event.logicalKey == LogicalKeyboardKey.escape) togglePause();
      if (event.logicalKey == LogicalKeyboardKey.keyC) showHitboxes = !showHitboxes;
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        godMode = !godMode;
        combatOverlay.addFloatingText('godMode: $godMode',Rect.fromLTWH(0, size.y/2, size.x, size.y/2),Palette.branco,speedY: 0);
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV && currentState == GameState.exploration && !isRunStartAnimating) EncounterManager.triggerSpecificEncounter(this, EnemyType.boss1);
      if (event.logicalKey == LogicalKeyboardKey.keyX) startInput(GameInput.buttonB);

      if (currentState == GameState.levelUp && activeMessage == null) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) startInput(GameInput.up);
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) startInput(GameInput.down);
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) startInput(GameInput.left);
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) startInput(GameInput.right);
      } 
      else if ([GameState.inventory, GameState.combat, GameState.shop, GameState.manual, GameState.mainMenu, GameState.paused].contains(currentState)) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) startInput(GameInput.up);
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) startInput(GameInput.down);
      }
    }
    return KeyEventResult.handled;
  }

  void onTouchStart(GameInput input) {
    if (input == GameInput.up) upPressed = true;
    if (input == GameInput.down) downPressed = true;
    if (input == GameInput.left) leftPressed = true;
    if (input == GameInput.right) rightPressed = true;
    explorationMoveCooldown = explorationMoveCooldownTime;
  }

  void startInput(GameInput input) {
    //if (!_hasStartedMenuMusic && currentState == GameState.mainMenu) {
    //  _hasStartedMenuMusic = true;
      //AudioManager.playBgm('music/main-menu.ogg');
      //quitToMainMenu(); 
    //}
    if (isRunStartAnimating && currentState == GameState.exploration) return;

    if (activeMessage != null) { if (input == GameInput.buttonA) dismissMessage(); return; }

    switch (currentState) {
      case GameState.splash: _handleSplashInput(input); break;
      case GameState.intro: 
        // Avisa a IntroOverlay que um botão foi apertado!
        if (input == GameInput.buttonA || input == GameInput.buttonB) {
          introInputNotifier.value++; 
        }
        break;
      case GameState.exploration: _handleExplorationInput(input); break;
      case GameState.combat: _handleCombatInput(input); break;
      case GameState.shop: _handleShopInput(input); break;
      case GameState.inventory: _handleInventoryInput(input); break;
      case GameState.settings: _handleSettingsInput(input); break;
      case GameState.levelUp: _handleLevelUpInput(input); break;
      case GameState.paused: _handlePauseInput(input); break;
      case GameState.mainMenu: _handleMainMenuInput(input); break;
      case GameState.gameOver: 
      case GameState.vitory: _handleGameOverInput(input); break;
      case GameState.manual: 
        if (input == GameInput.buttonB) { AudioManager.playSfx('sfx/decline.wav'); closeManual(); }
        break;
      //default: break;
    }
    if(input == GameInput.pause && !(currentState == GameState.settings || currentState == GameState.mainMenu || currentState == GameState.gameOver || currentState == GameState.vitory)) togglePause();
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

        if (playerCombatStats.chargeTimer >= 1.0) {
          playerCombatStats.isHeavyAttack = true;
          playerCombatStats.stamina = max(playerCombatStats.stamina - (custoStaminaBase * 1.5), 0.0);
        } else {
          playerCombatStats.isHeavyAttack = false;
          playerCombatStats.stamina = max(playerCombatStats.stamina - custoStaminaBase, 0.0);
        }

        playerCombatStats.currentPhase = CombatPhase.active;
        playerCombatStats.animTimer = 0.15; 
        playerCombatStats.attackHit = false;
      }
    }
  }

  // ===========================================================================
  // SUB-MÉTODOS DE INPUT (Isolados e Limpos)
  // ===========================================================================
  void _handleSplashInput(GameInput input) {
    
    currentState = GameState.mainMenu;
    overlays.remove('Splash');
    overlays.add('MainMenu');
    
    //AudioManager.playBgm('music/main-menu.ogg'); 
    // (Ajuste para .mp3 se tiver voltado atrás na conversão)
  }

  void _handleExplorationInput(GameInput input) {
    if (isPassTurnPromptOpen) {
      if (input == GameInput.buttonA) { isPassTurnPromptOpen = false; _onPlayerStepped(); } 
      else if (input == GameInput.buttonB) { isPassTurnPromptOpen = false; }
      return;
    }

    if (input == GameInput.up) { 
      if (player.move(true, dungeon)){ _onPlayerStepped(); AudioManager.playSfx('sfx/step.wav'); } 
      else { renderer.triggerWallBump(forward: true); AudioManager.playSfx('sfx/landing.wav'); } 
    }
    else if (input == GameInput.down) { 
      if (player.move(false, dungeon)){ _onPlayerStepped(); AudioManager.playSfx('sfx/step.wav'); } 
      else { renderer.triggerWallBump(forward: true); AudioManager.playSfx('sfx/landing.wav'); } 
    }
    else if (input == GameInput.left){ player.turn(false); AudioManager.playSfx('sfx/step.wav'); }
    else if (input == GameInput.right) { player.turn(true); AudioManager.playSfx('sfx/step.wav'); }
    else if (input == GameInput.buttonA) {
      Point<int> currentPos = Point(player.x, player.y);
      if (dungeon.droppedItems.containsKey(currentPos) && dungeon.droppedItems[currentPos]!.isNotEmpty) {
        Item itemToPick = dungeon.droppedItems[currentPos]!.first;
        if (playerCombatStats.inventory.length < playerCombatStats.maxInventory) {
          dungeon.droppedItems[currentPos]!.removeAt(0); receiveItem(itemToPick); 
        } else { showMessage("$I18n.t('inv_cheio') ${itemToPick.name}."); }
        return; 
      }
      _interact(); 
    }
    else if (input == GameInput.buttonB) { 
      AudioManager.playSfx('sfx/confirm.wav');
      currentState = GameState.inventory; inventoryCursor = 0; isActionMenuOpen = false; isItemActionMenuOpen = false; 
    }
  }

  void _handleCombatInput(GameInput input) {
    bool easyDashShield = playerCombatStats.equippedShield?.easyDash ?? false; 
    bool easyDashArmor = playerCombatStats.equippedArmor?.easyDash ?? false; 
    bool chargeAttackShield = playerCombatStats.equippedShield?.hasChargeAttack ?? false; 
    bool chargeAttackWeapon = playerCombatStats.equippedWeapon?.hasChargeAttack ?? false; 
    int peso = playerCombatStats.equippedArmor?.peso ?? 0; 

    double dcusto = dashCusto + peso*2 ;
    if (easyDashShield || easyDashArmor) dcusto = dashCusto/2;
    
    if (input == GameInput.left) {
      leftPressed = true;
      if (leftTapTimer > 0) { playerCombatStats.stamina -= dcusto; dashTimer = dashDur; dashDirection = -1.0; leftTapTimer = 0.0; } 
      else { leftTapTimer = 0.25; }
    }
    if (input == GameInput.right) {
      rightPressed = true;
      if (rightTapTimer > 0) { playerCombatStats.stamina -= dashCusto; dashTimer = dashDur; dashDirection = 1.0; rightTapTimer = 0.0; } 
      else { rightTapTimer = 0.25; }
    }
    if (input == GameInput.down) downPressed = true;
    
    if (input == GameInput.buttonA) {
      if(chargeAttackShield || chargeAttackWeapon){
        if (playerCombatStats.currentPhase == CombatPhase.idle) {
          playerCombatStats.currentPhase = CombatPhase.windup; playerCombatStats.isCharging = true;
          playerCombatStats.chargeTimer = 0.0; playerCombatStats.isHeavyAttack = false; playerCombatStats.animTimer = 0.5; 
        }
      }else{ _performAttack(); }
    }
    if (input == GameInput.up && playerCombatStats.consumables.isNotEmpty) {
      selectedConsumableIndex++;
      if (selectedConsumableIndex >= playerCombatStats.consumables.length) selectedConsumableIndex = 0;
    }
    if (input == GameInput.buttonB && playerCombatStats.consumables.isNotEmpty) {
      _useCombatConsumable(playerCombatStats.consumables[selectedConsumableIndex]);
    }
  }

  void _handleShopInput(GameInput input) {
    if (input == GameInput.up) { shopCursor--; AudioManager.playSfx('sfx/hover.wav'); }
    if (input == GameInput.down) { shopCursor++; AudioManager.playSfx('sfx/hover.wav'); }

    int maxCursor = 0;
    if (currentShopPhase == ShopPhase.main) maxCursor = 3; 
    else if (currentShopPhase == ShopPhase.buy || currentShopPhase == ShopPhase.steal) maxCursor = max(0, shopInventory.length - 1);
    else if (currentShopPhase == ShopPhase.sell) maxCursor = max(0, playerCombatStats.inventory.length - 1);
    else if (currentShopPhase == ShopPhase.confirmSell) maxCursor = 1; 

    if (shopCursor < 0) shopCursor = maxCursor;
    if (shopCursor > maxCursor) shopCursor = 0;

    if (input == GameInput.buttonB) {
      if (currentShopPhase == ShopPhase.main) { currentState = GameState.exploration; } 
      else { currentShopPhase = ShopPhase.main; shopCursor = 0; }
    }

    if (input == GameInput.buttonA) {
      if (currentShopPhase == ShopPhase.main) {
        AudioManager.playSfx('sfx/confirm.wav');
        if (shopCursor == 0) { currentShopPhase = ShopPhase.buy; shopCursor = 0; } 
        else if (shopCursor == 1) { currentShopPhase = ShopPhase.sell; shopCursor = 0; } 
        else if (shopCursor == 2) { currentShopPhase = ShopPhase.steal; shopCursor = 0; } 
        else if (shopCursor == 3) currentState = GameState.exploration; 
      }
      else if (currentShopPhase == ShopPhase.buy) {
        if (shopInventory.isEmpty) return;
        Item itemToBuy = shopInventory[shopCursor];
        if (playerCombatStats.inventory.length >= playerCombatStats.maxInventory && !playerCombatStats.inventory.any((i) => i.name == itemToBuy.name)) {
          showMessage(I18n.t('vend_inv_cheio'));
        } else if (_getPlayerCoins() >= itemToBuy.value) {
          _removeCoins(itemToBuy.value);
          try { playerCombatStats.inventory.firstWhere((i) => i.name == itemToBuy.name).quantity++; } 
          catch (e) { playerCombatStats.inventory.add(Item(itemToBuy.name, itemToBuy.type, itemToBuy.imagePath, itemToBuy.power, value: itemToBuy.value, quantity: 1, cor: itemToBuy.cor)); }
          
          itemToBuy.quantity--;
          if (itemToBuy.quantity <= 0) {
            shopInventory.remove(itemToBuy);
            if (shopCursor >= shopInventory.length && shopCursor > 0) shopCursor--;
            if (shopInventory.isEmpty) { currentShopPhase = ShopPhase.main; shopCursor = 0; }
          }
          AudioManager.playSfx('sfx/confirm.wav');
        } else { AudioManager.playSfx('sfx/denied.wav'); }
      }
      else if (currentShopPhase == ShopPhase.sell) {
        if (playerCombatStats.inventory.isEmpty) return;
        itemToSell = playerCombatStats.inventory[shopCursor];
        
        if (itemToSell!.name == "moeda" || itemToSell == playerCombatStats.equippedWeapon || itemToSell == playerCombatStats.equippedArmor || itemToSell == playerCombatStats.equippedShield) {
          AudioManager.playSfx('sfx/denied.wav');
          showMessage(I18n.t('npode_vender'));
          return;
        }
        AudioManager.playSfx('sfx/confirm.wav');
        currentShopPhase = ShopPhase.confirmSell; shopCursor = 0;
      }
      else if (currentShopPhase == ShopPhase.confirmSell) {
        if (shopCursor == 0 && itemToSell != null) {
          int valorVenda = (itemToSell!.value * 0.25).ceil(); 
          if (valorVenda < 1) valorVenda = 1;
          _addCoins(valorVenda);
          itemToSell!.quantity--;
          if (itemToSell!.quantity <= 0) playerCombatStats.inventory.remove(itemToSell);
          AudioManager.playSfx('sfx/use_item.wav');
          currentShopPhase = ShopPhase.sell; shopCursor = 0; itemToSell = null;
        } else {
          currentShopPhase = ShopPhase.sell; shopCursor = 0;
        }
      }
      else if (currentShopPhase == ShopPhase.steal) {
        if (shopInventory.isEmpty) return;
        Item itemToSteal = shopInventory[shopCursor];
        if (playerCombatStats.inventory.length >= playerCombatStats.maxInventory && !playerCombatStats.inventory.any((i) => i.name == itemToSteal.name)) {
          showMessage(I18n.t('vend_inv_cheio'));
        } else {
          try { playerCombatStats.inventory.firstWhere((i) => i.name == itemToSteal.name).quantity++; } 
          catch (e) { playerCombatStats.inventory.add(Item(itemToSteal.name, itemToSteal.type, itemToSteal.imagePath, itemToSteal.power, value: itemToSteal.value, quantity: 1, cor: itemToSteal.cor)); }
          
          dungeon.grid[player.y][player.x] = TileType.floor;
          showMessage(I18n.t('vend_ladrao'));
          EncounterManager.triggerSpecificEncounter(this, EnemyType.goblinShop);
        }
      }
    }
  }

  void _handleInventoryInput(GameInput input) {
    if (playerCombatStats.inventory.isEmpty) isItemActionMenuOpen = false;

    if (isItemActionMenuOpen) {
      if (input == GameInput.up) { AudioManager.playSfx('sfx/hover.wav'); itemActionCursor = (itemActionCursor - 1 + 3) % 3; } 
      else if (input == GameInput.down) { AudioManager.playSfx('sfx/hover.wav'); itemActionCursor = (itemActionCursor + 1) % 3; } 
      else if (input == GameInput.buttonA) {
        AudioManager.playSfx('sfx/confirm.wav');
        if (itemActionCursor == 0) {
          _useOrEquipItem(playerCombatStats.inventory[inventoryCursor]); 
          isItemActionMenuOpen = false;
        } else if (itemActionCursor == 1) {
          dropSelectedItem(inventoryCursor);
          isItemActionMenuOpen = false;
          if (inventoryCursor >= playerCombatStats.inventory.length) inventoryCursor = max(0, playerCombatStats.inventory.length - 1);
        } else if (itemActionCursor == 2) { isItemActionMenuOpen = false; }
      } else if (input == GameInput.buttonB || input == GameInput.pause) {
        AudioManager.playSfx('sfx/decline.wav'); isItemActionMenuOpen = false; 
      }
    } else {
      if (input == GameInput.up) {
        AudioManager.playSfx('sfx/hover.wav'); inventoryCursor -= 1;
        if(inventoryCursor<0) inventoryCursor = playerCombatStats.inventory.length - 1;
      } else if (input == GameInput.down) {
        AudioManager.playSfx('sfx/hover.wav'); inventoryCursor += 1;
        if(inventoryCursor>playerCombatStats.inventory.length - 1) inventoryCursor = 0;
      } else if (input == GameInput.buttonA && playerCombatStats.inventory.isNotEmpty) {
        AudioManager.playSfx('sfx/confirm.wav'); isItemActionMenuOpen = true; itemActionCursor = 0;
      } else if (input == GameInput.buttonB || input == GameInput.pause) {
        AudioManager.playSfx('sfx/decline.wav'); currentState = GameState.exploration; 
      }
    }
  }

  void _handleSettingsInput(GameInput input) {
    if (input == GameInput.up) { AudioManager.playSfx('sfx/hover.wav'); settingsCursor.value = (settingsCursor.value - 1 + 4) % 4; }
    if (input == GameInput.down) { AudioManager.playSfx('sfx/hover.wav'); settingsCursor.value = (settingsCursor.value + 1) % 4; }
    
    // NOVO: Setas para os lados controlam as barras de volume e idioma!
    if (input == GameInput.left) {
      if (settingsCursor.value == 0) AudioManager.changeBgmVolume(-1);
      else if (settingsCursor.value == 1) AudioManager.changeSfxVolume(-1);
      else if (settingsCursor.value == 2) { I18n.toggleLanguage(); AudioManager.playSfx('sfx/hover.wav'); }
      settingsRefresh.value = !settingsRefresh.value; 
    }
    
    if (input == GameInput.right) {
      if (settingsCursor.value == 0) AudioManager.changeBgmVolume(1);
      else if (settingsCursor.value == 1) AudioManager.changeSfxVolume(1);
      else if (settingsCursor.value == 2) { I18n.toggleLanguage(); AudioManager.playSfx('sfx/hover.wav'); }
      settingsRefresh.value = !settingsRefresh.value; 
    }

    if (input == GameInput.buttonA) {
      if (settingsCursor.value == 2) { 
        AudioManager.playSfx('sfx/confirm.wav');
        I18n.toggleLanguage(); 
        settingsRefresh.value = !settingsRefresh.value; 
      }
      else if (settingsCursor.value == 3) { 
        AudioManager.playSfx('sfx/confirm.wav');
        closeSettings(); 
      }
    }
    
    if (input == GameInput.buttonB) {
      AudioManager.playSfx('sfx/decline.wav');
      closeSettings();
    }
  }

  void _handleLevelUpInput(GameInput input) {
    AudioManager.playSfx('sfx/hover.wav');
    if (input == GameInput.up) levelUpCursor = (levelUpCursor - 1 + 4) % 4; 
    if (input == GameInput.down) levelUpCursor = (levelUpCursor + 1) % 4;
    
    if (input == GameInput.right || (input == GameInput.buttonA && levelUpCursor < 3)) {
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
      if (levelUpCursor == 3 && input == GameInput.buttonB) currentState = GameState.exploration;
    }

    if (input == GameInput.buttonA && levelUpCursor == 3) {
      if (pointsToDistribute == 0) {
        playerCombatStats.essence -= levelUpCost;
        playerCombatStats.str += tempStr; playerCombatStats.con += tempCon; playerCombatStats.wis += tempWis;
        playerCombatStats.recalculateMaxHp();
        dungeon.grid[player.y][player.x] = TileType.floor;
        showMessage(I18n.t('atrib_melhorados'));
        currentState = GameState.exploration;
      } else {
        showMessage(I18n.t('atrib_distri'));
      }
    }
  }

  void _handlePauseInput(GameInput input) {
    if (input == GameInput.up) { AudioManager.playSfx('sfx/hover.wav'); pauseMenuCursor.value = (pauseMenuCursor.value - 1 + 3) % 3; }
    if (input == GameInput.down) { AudioManager.playSfx('sfx/hover.wav'); pauseMenuCursor.value = (pauseMenuCursor.value + 1) % 3; }
    if (input == GameInput.buttonA) {
      AudioManager.playSfx('sfx/confirm.wav');
      if (pauseMenuCursor.value == 0) togglePause();
      else if (pauseMenuCursor.value == 1) quitToMainMenu();
      else if (pauseMenuCursor.value == 2) openSettings(); 
    }
  }

  void _handleMainMenuInput(GameInput input) {
    //if (AudioManager.currentTrack != 'music/main-menu.ogg') {
    //  AudioManager.playBgm('music/main-menu.ogg');
    //}
    if (isMainMenuAnimating) return;
    int maxOptions = hasSavedGame ? 4 : 3; 
    if (input == GameInput.up) { AudioManager.playSfx('sfx/hover.wav'); mainMenuCursor.value = (mainMenuCursor.value - 1 + maxOptions) % maxOptions; }
    if (input == GameInput.down) { AudioManager.playSfx('sfx/hover.wav'); mainMenuCursor.value = (mainMenuCursor.value + 1) % maxOptions; }
    if (input == GameInput.buttonA) {
      AudioManager.playSfx('sfx/confirm.wav');
      if (hasSavedGame) {
        if (mainMenuCursor.value == 0) { SaveManager.loadGame(this).then((_) { currentState = GameState.exploration; overlays.remove('MainMenu'); }); } 
        else if (mainMenuCursor.value == 1) { startGame(); } 
        else if (mainMenuCursor.value == 2) { openSettings(); } 
        else if (mainMenuCursor.value == 3) { openManual(); }
      } else {
        if (mainMenuCursor.value == 0) { startGame(); } 
        else if (mainMenuCursor.value == 1) { openSettings(); } 
        else if (mainMenuCursor.value == 2) { openManual(); }
      }
    }
  }

  void _handleGameOverInput(GameInput input) {
    int maxOptions = 2; 
    if (input == GameInput.up) { AudioManager.playSfx('sfx/hover.wav'); mainMenuCursor.value = (mainMenuCursor.value - 1 + maxOptions) % maxOptions; }
    if (input == GameInput.down) { AudioManager.playSfx('sfx/hover.wav'); mainMenuCursor.value = (mainMenuCursor.value + 1) % maxOptions; }
    if (input == GameInput.buttonA) {
      AudioManager.playSfx('sfx/confirm.wav');
      if (mainMenuCursor.value == 0) startGame();
      else if (mainMenuCursor.value == 1) quitToMainMenu();
    }
  }

  // ===========================================================================
  // INTERAÇÕES E COMBATE
  // ===========================================================================
  void _onPlayerStepped() {
    dungeon.advanceSpikes(); dungeon.advancePoison(); dungeon.advanceTeleport();
    playerCombatStats.recoverMana();
    
    if (dungeon.getTile(player.x, player.y) == TileType.spike && dungeon.spikeState == 3) {
      playerCombatStats.hp -= 5; shakeScreen(0.3, 10.0); playerCombatStats.applyHitStun(0.3); 
      showMessage(I18n.t('trap1'));
      if (playerCombatStats.hp <= 0) handlePlayerDeath();
    }

    if (dungeon.getTile(player.x, player.y) == TileType.poison && (dungeon.poisonState == 3 || dungeon.poisonState == 4)) {
      playerCombatStats.poisonTmr = 10; shakeScreen(0.3, 10.0); playerCombatStats.applyHitStun(0.3); 
      showMessage(I18n.t('trap2'));
    }

    if (dungeon.getTile(player.x, player.y) == TileType.teleport && (dungeon.teleportState == 3 || dungeon.teleportState == 4)) {
      List<Point<int>> safeTiles = [];
      for (int y = 1; y < dungeon.height - 1; y++) {
        for (int x = 1; x < dungeon.width - 1; x++) {
          if (dungeon.grid[y][x] == TileType.floor && (x != player.x || y != player.y)) safeTiles.add(Point(x, y));
        }
      }
      if (safeTiles.isNotEmpty) {
        Point<int> randomDest = safeTiles[Random().nextInt(safeTiles.length)];
        player.x = randomDest.x; player.y = randomDest.y;
        dungeon.explored[player.y][player.x] = true;
        showMessage(I18n.t('trap3'));
        shakeScreen(0.3, 10.0);
        List<Direction> dirs = [Direction.north, Direction.east, Direction.south, Direction.west];
        player.facing = dirs[Random().nextInt(dirs.length)];
      }
    }

    if (playerCombatStats.poisonTmr > 0){
      playerCombatStats.poisonTmr --;
      if(playerCombatStats.hp > 1) playerCombatStats.hp -= 1;   
      playerCombatStats.applyEffect(0.3,Palette.verde);
      if (playerCombatStats.poisonTmr == 0) showMessage(I18n.t('sente_bem'));
    }
    
    dungeon.moveEnemies(Point(player.x, player.y));
    for (int i = 0; i < dungeon.roamingEnemies.length; i++) {
      if (dungeon.roamingEnemies[i].x == player.x && dungeon.roamingEnemies[i].y == player.y) {
        dungeon.roamingEnemies.removeAt(i); 
        EncounterManager.triggerRandomEncounter(this); // CHAMANDO O MANAGER
        break; 
      }
    }
  }

  void _interact() {
    TileType playerTile = dungeon.getTile(player.x, player.y);

    if ([TileType.floor, TileType.entry, TileType.openChest, TileType.spike, TileType.poison, TileType.teleport].contains(playerTile)) {
      Point<int> currentPos = Point(player.x, player.y);
      if (!dungeon.droppedItems.containsKey(currentPos) || dungeon.droppedItems[currentPos]!.isEmpty) {
        isPassTurnPromptOpen = true; return;
      }
    }

    if (playerTile == TileType.shop) openShop();

    if (playerTile == TileType.font) {
      playerCombatStats.hp = playerCombatStats.maxHp; playerCombatStats.mana = playerCombatStats.wis*3;
      playerCombatStats.vfxTimer = 0.5; playerCombatStats.vfxColor = Palette.vermelho;
      showMessage(I18n.t('font_healed'));
    }

    if (playerTile == TileType.fontPoison) {
      playerCombatStats.poisonTmr = 10; playerCombatStats.vfxTimer = 0.5; playerCombatStats.vfxColor = Palette.verde;
      showMessage(I18n.t('font_poisoned'));
    }

    if (playerTile == TileType.shrine) {
      int cost = levelUpCost;
      if (playerCombatStats.essence >= cost) {
        pointsToDistribute = 3; tempStr = 0; tempCon = 0; tempWis = 0; levelUpCursor = 0;
        currentState = GameState.levelUp; 
      } else { showMessage(I18n.t('shrine_cost').replaceAll('{cost}', cost.toString()).replaceAll('{essence}', playerCombatStats.essence.toInt().toString())); }
      return;
    }

    if (playerTile == TileType.door) {
      if (player.hasKey) {
        showMessage(I18n.t('open_door').replaceAll('{level}', (dungeon.level + 1).toString()), onDismiss: () async {
          player.hasKey = false;
          dungeon.width += 5; dungeon.height += 5; dungeon.level ++;
          dungeon.droppedItems.clear(); dungeon.generateProceduralMap(); 
          player.x = dungeon.playerSpawn.x; player.y = dungeon.playerSpawn.y; player.facing = Direction.north;

          List<Item> items = [
            ItemDatabase.espadaCurta, ItemDatabase.espadaLonga, ItemDatabase.machado,ItemDatabase.clava,
            ItemDatabase.lanca,ItemDatabase.claymore,ItemDatabase.warhammer,ItemDatabase.varinha,ItemDatabase.zweihander,
            ItemDatabase.armaduraFerro, ItemDatabase.armaduraCouro,ItemDatabase.armaduraAco,
            ItemDatabase.armaduraBronze, ItemDatabase.gambeson, ItemDatabase.chainMail,
            ItemDatabase.escudoMadeira, ItemDatabase.escudoFerro, ItemDatabase.escudoTorre,
            ItemDatabase.firePillar, ItemDatabase.piercingShot, ItemDatabase.toxicCloud, ItemDatabase.thunderStorm,
          ];
          List<Item> consumiveis = [
            ItemDatabase.healthPotion, ItemDatabase.manaPotion, ItemDatabase.staminaPotion, ItemDatabase.reflexPotion,
            ItemDatabase.faca, ItemDatabase.bomb, ItemDatabase.meat, ItemDatabase.web, ItemDatabase.slimeEye,
            ItemDatabase.bugOrgan, ItemDatabase.bola, ItemDatabase.strPotion
          ];

          List<Item> unownedItens = items.where((equip) => !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name)).toList();
          unownedItens.addAll(consumiveis); unownedItens.shuffle();
          shopInventory = [unownedItens[0], unownedItens[1], unownedItens[2], unownedItens[3]];

          await SaveManager.saveGame(this); // MANAGER AQUI
          isRunStartAnimating = true;
          runStartAnimTimer = 0.0;
          String dung = '';
          if(dungeon.level == 4){
            dung = I18n.t('dung2');
          }else if(dungeon.level == 8){
            dung = I18n.t('dung3');
          }else if(dungeon.level == 4){
            dung = I18n.t('dung4');
          }
          combatOverlay.addFloatingText('-Floor ${dungeon.level}-$dung',Rect.fromLTWH(0, size.y/2, size.x, size.y/2),Palette.branco,speedY: 0,tmr:2);

          if(dungeon.level >= 13){ currentState = GameState.vitory; overlays.add('Vitory'); }
        });
      } else { showMessage(I18n.t('door_locked')); }
    } 
    else if (playerTile == TileType.chest) {
      int chance = Random().nextInt(100);
      if (chance < 45) { 
        dungeon.grid[player.y][player.x] = TileType.floor; 
        showMessage(I18n.t('mimico_found'), onDismiss: () { EncounterManager.triggerSpecificEncounter(this, EnemyType.mimic); }); 
      } else if (chance < 60) { 
        dungeon.grid[player.y][player.x] = TileType.openChest; 
        int loot = Random().nextInt(30) + 10; 
        showMessage(I18n.t('found_essences').replaceAll('{loot}', loot.toString()), onDismiss: () { playerCombatStats.essence += loot; }); 
      } else {
        dungeon.grid[player.y][player.x] = TileType.openChest; 
        List<Item> allEquipments = [
          ItemDatabase.espadaCurta, ItemDatabase.armaduraFerro, ItemDatabase.armaduraAco, ItemDatabase.armaduraBronze,
          ItemDatabase.espadaLonga, ItemDatabase.zweihander, ItemDatabase.varinha, ItemDatabase.escudoTorre, ItemDatabase.warhammer,
          ItemDatabase.clava, ItemDatabase.claymore, ItemDatabase.lanca, ItemDatabase.armaduraCouro, ItemDatabase.chainMail,
          ItemDatabase.machado, ItemDatabase.firePillar, ItemDatabase.escudoMadeira, ItemDatabase.escudoFerro,
          ItemDatabase.piercingShot, ItemDatabase.toxicCloud, ItemDatabase.thunderStorm,
        ];

        List<Item> unownedEquipments = allEquipments.where((equip) => !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name)).toList();
        unownedEquipments.shuffle(); 
        Item newEquipment = unownedEquipments.first; newEquipment.quantity = 1; 

        showMessage(I18n.t('item_found').replaceAll('{item}', I18n.t(newEquipment.name)), onDismiss: () { receiveItem(newEquipment); });
      }
    }
    else if (playerTile == TileType.crate) {
      int chance = Random().nextInt(100);
      dungeon.grid[player.y][player.x] = TileType.floor; 
      
      if (chance < 40) { showMessage(I18n.t('caixa_vazia')); } 
      else {
        List<Item> allConsumables = [
            ItemDatabase.healthPotion, ItemDatabase.manaPotion, ItemDatabase.bomb, ItemDatabase.staminaPotion,
            ItemDatabase.reflexPotion, ItemDatabase.meat, ItemDatabase.faca, ItemDatabase.bugOrgan, ItemDatabase.strPotion
          ];
        Item droppedItem = allConsumables[Random().nextInt(allConsumables.length)];
        droppedItem.quantity = 1;

        showMessage(I18n.t('item_found').replaceAll('{item}', I18n.t(droppedItem.name)), onDismiss: () {
          var existingItems = playerCombatStats.inventory.where((i) => i.name == droppedItem.name).toList();
          if (existingItems.isNotEmpty) existingItems.first.quantity += droppedItem.quantity; 
          else receiveItem(droppedItem);
        });
      }
    }
  }

  void _performAttack() {
    if (playerCombatStats.stamina >= 0 && !playerCombatStats.cansado && (playerCombatStats.currentPhase == CombatPhase.idle || playerCombatStats.currentPhase == CombatPhase.walk)) {
      if (playerCombatStats.staminaInfiniteTmr <= 0) playerCombatStats.stamina -= playerCombatStats.staminaCost;
      if(playerCombatStats.stamina <=0){ playerCombatStats.stamina = 0; playerCombatStats.cansado = true; }
      playerCombatStats.staminaTmr = playerCombatStats.staminaRegenDelay; 
      playerCombatStats.currentPhase = CombatPhase.windup; playerCombatStats.animTimer = playerCombatStats.windupTime;
      combatOverlay.playerAttackWindupTicker.reset(); combatOverlay.weaponAttackWindupTicker.reset();
      playerCombatStats.comboCount++; if (playerCombatStats.comboCount > 3) playerCombatStats.comboCount = 1;
      playerCombatStats.comboTimer = 1.0;
    }
  }

  Future<void> projetil() async {
    final ui.Image img = await images.load('effects/magia.png');
    double damage = playerCombatStats.equippedWeapon?.power ?? 5; 
    AudioManager.playSfx('sfx/fire.wav');
     combatOverlay.add(PlayerProjectile(playerCombatStats.strafePosition, 0.75, 1.5, damage * playerCombatStats.wis * 0.5 , Palette.azulCla, width: 48, height: 48, img : img));
  }

  void applyEnemyDamage(Enemy enemy) {
    double defense = playerCombatStats.equippedArmor?.power ?? 0; 
    double dmg = max(1, enemy.damage - defense);
    bool unblockable = enemy.isHeavyAttack;
    
    if(dashTimer>0 || playerCombatStats.invencibleTmr > 0 || godMode)return;

    if (playerCombatStats.isGuarding && !unblockable) {
      AudioManager.playSfx('sfx/block.wav');
      if (playerCombatStats.stamina >= 0) {
        if (playerCombatStats.staminaInfiniteTmr <= 0) playerCombatStats.stamina -= (8 - playerCombatStats.equippedShield!.power); 
        playerCombatStats.stamina = playerCombatStats.stamina.clamp(0, playerCombatStats.con * 3);
        if (playerCombatStats.stamina <= 0) playerCombatStats.cansado = true;
        playerCombatStats.flashColor = Palette.cinza; playerCombatStats.hitFlashTimer = 0.1; 
      }
    } else { 
      AudioManager.playSfx('sfx/hit.wav');
      playerCombatStats.hp -= dmg; playerCombatStats.applyHitStun(0.3); 
      combatOverlay.playerHitTicker.reset(); combatOverlay.weaponHitTicker.reset();
        if(playerCombatStats.equippedArmor?.hasPoisonAttack ?? false){
          for (var enemy in combatOverlay.enemies) {
            if (enemy.isAlive && (enemy.strafePosition - playerCombatStats.strafePosition).abs() <= 0.2) enemy.isPoison = true;
          }
        }
    }
    if (playerCombatStats.hp < 0) playerCombatStats.hp = 0;
  }

  void _useOrEquipItem(Item item) async {
    String fileName = item.imagePath.split('/').last;
    if (item.type == ItemType.weapon) { 
      if (item.str > playerCombatStats.str){ AudioManager.playSfx('sfx/denied.wav'); showMessage(I18n.t('precisa_str').replaceAll('{str}', item.str.toString())); }
      else{ playerCombatStats.equippedWeapon = item; if (item.onUse != null) item.onUse!(item, this); await changeWeaponSprite('actors/$fileName'); }
    }
    else if (item.type == ItemType.armor) { 
      playerCombatStats.equippedArmor = item; if (item.onUse != null) item.onUse!(item, this); await changeArmorSprite('actors/$fileName'); 
      int peso = playerCombatStats.equippedArmor?.peso ?? 0;
      double staminaDelay = 0.5; if (peso == 2) staminaDelay = 0.6; else if(peso == 3) staminaDelay = 1.0;
      playerCombatStats.staminaRegenDelay = staminaDelay;
    }
    else if (item.type == ItemType.shield) { playerCombatStats.equippedShield = item; if (item.onUse != null) item.onUse!(item, this); await changeShieldSprite('actors/$fileName'); }
    else if (item.type == ItemType.consumable) { if (item.onUse != null) item.onUse!(item, this); AudioManager.playSfx('sfx/use_item.wav'); _consumeItem(item); }
    else if (item.type == ItemType.coin) { showMessage(I18n.t('guarda_batalha')); }
  }

  void _useCombatConsumable(Item item) {
    if (item.type == ItemType.consumable) {
      if (item.onUse != null) item.onUse!(item, this); _consumeItem(item); AudioManager.playSfx('sfx/use_item.wav');
    } 
    else if (item.type == ItemType.spell) {
      if (playerCombatStats.mana >= item.manaCost) { playerCombatStats.mana -= item.manaCost; if (item.onUse != null) item.onUse!(item, this); } 
      else { combatOverlay.addFloatingText(I18n.t('no_mana'), playerCombatStats.getHurtbox(size), Palette.cinzaCla); }
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

  void _endEncounter() {
    playerCombatStats.currentPhase = CombatPhase.exiting; playerCombatStats.animTimer = 1; 
    if(isBoss){
      AudioManager.playBgm('music/8-bit-dungeon.mp3');
    }
    isMimic = false; isBoss = false;
  }   
  
  void startCombat(List<Enemy> enemies) {
    AudioManager.playSfx('sfx/encounter.wav'); encounterEssence = 0; encounterDrop.clear(); victoryProcessed = false;
    currentState = GameState.combat;
    combatOverlay.startEncounter(enemies);
    playerCombatStats.currentPhase = CombatPhase.entering; playerCombatStats.animTimer = 1;
    if(isBoss){
      AudioManager.playBgm('music/boss-battle.mp3');
    }
  }

  void resetGame() {
    runTime=0;
    for (var enemy in combatOverlay.enemies) enemy.removeFromParent(); 
    combatOverlay.enemies.clear(); _messageQueue.clear(); 

    playerCombatStats.str = 5; playerCombatStats.con = 5; playerCombatStats.wis = 5;
    playerCombatStats.hp = playerCombatStats.maxHp; playerCombatStats.stamina = playerCombatStats.con*3; playerCombatStats.mana = playerCombatStats.wis*3;
    playerCombatStats.currentPhase = CombatPhase.idle;

    _initializeInventory();
    dungeon.level = 1; player.hasKey = false;
    dungeon.width = mapSize; dungeon.height = mapSize; dungeon.generateProceduralMap();
    player.x = dungeon.playerSpawn.x; player.y = dungeon.playerSpawn.y; player.facing = Direction.north;

    shopInventory = [ ItemDatabase.clava, ItemDatabase.gambeson, ItemDatabase.escudoFerro, ItemDatabase.staminaPotion ];
    combatOverlay.enemies.clear();
  }

  void startGame() {
    resetGame();
    currentState = GameState.intro; 
    overlays.remove('GameOver');
    overlays.remove('MainMenu');
    overlays.add('Intro');
  }

  void finishIntro() {
    currentState = GameState.exploration;
    overlays.remove('Intro');
    combatOverlay.addFloatingText('-Floor ${dungeon.level}-${I18n.t('dung1')}',Rect.fromLTWH(0, size.y/2, size.x, size.y/2),Palette.branco,speedY: 0,tmr:2);
    isRunStartAnimating = true;
    runStartAnimTimer = 0.0;
    AudioManager.playBgm('music/8-bit-dungeon.mp3');
  }

  void handlePlayerDeath() async { 
    final prefs = await SharedPreferences.getInstance(); await prefs.remove('save_game');
    hasSavedGame = false;
    AudioManager.playBgm('music/gameover.mp3');
    for (var e in combatOverlay.enemies) e.isAlive = false;
    currentState = GameState.gameOver; overlays.add('GameOver');
  }
}