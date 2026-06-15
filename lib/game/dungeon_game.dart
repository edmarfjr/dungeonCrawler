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
import 'package:dungeon_crawler/game/overlays/combat_overlay.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart' hide PlayerState;

enum GameInput { up, down, left, right, buttonA, buttonB, pause }
enum GameState { mainMenu, exploration, combat, paused, gameOver, inventory, levelUp, manual }

// --- CLASSE AUXILIAR PARA A FILA DE MENSAGENS ---
class GameMessage {
  final String text;
  final VoidCallback? onDismiss;
  GameMessage(this.text, {this.onDismiss});
}

class DungeonCrawlerGame extends FlameGame with KeyboardEvents {
  GameState currentState = GameState.mainMenu;
  GameState previousState = GameState.mainMenu;

  late DungeonMap dungeon;
  late PlayerState player;
  late MazeRenderer renderer;
  late MinimapRenderer minimap;
  late PlayerCombatStats playerCombatStats;
  late CombatOverlay combatOverlay;
  late Map<EnemyType, ui.Image> enemySheets;
  late ui.Image playerSheet; 
  late ui.Image playerSlashSprite;
  late Map<EnemyType, ui.Image> enemySlashSprites;
  late ui.Image weaponSheet;
  late ui.Image armorSheet;
  late ui.Image shieldSheet;

  late ui.Image keySprite;
  late ui.Image doorTexture;
  late ui.Image chestSprite;
  late ui.Image openChestSprite;
  late ui.Image spikeSprite;
  late ui.Image roamerSprite;
  late ui.Image bossSprite;
  late ui.Image shrineSprite;

  bool leftPressed = false, rightPressed = false, downPressed = false, showHitboxes = false, upPressed = false;
  double explorationMoveCooldown = 0.0;
  double explorationMoveCooldownTime = 0.3;

  double leftTapTimer = 0.0;  // Janela de tempo para o clique duplo (Esquerda)
  double rightTapTimer = 0.0; // Janela de tempo para o clique duplo (Direita)
  double dashTimer = 0.0;     // Duração do Dash na tela
  double dashDirection = 0.0;

  // REFACTOR: Substituído showVictoryMessage por um controle de fluxo de fim de turno
  bool _victoryProcessed = false;
  double encounterEssence = 0;

  List<Item> encounterDrop = [];

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
  
  int get levelUpCost {
    int totalLevel = (playerCombatStats.str + playerCombatStats.con + playerCombatStats.wis).toInt();
    return 50 + (totalLevel * 15);
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
      ItemDatabase.faca,
    ];
    playerCombatStats.equippedWeapon = playerCombatStats.inventory[0];
    playerCombatStats.equippedArmor = playerCombatStats.inventory[1];
    playerCombatStats.equippedShield = playerCombatStats.inventory[2];
    selectedConsumableIndex = 0;
  }

  @override
  Future<void> onLoad() async {
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
    ]);
    
    await images.loadAll([
      'itens/dagger.png',
      'itens/armor.png',
      'itens/potion.png',
      'itens/tanga.png',
      'itens/sword.png',
      'itens/longSword.png',
      'itens/axe.png',
      'itens/bomb.png',
      'itens/leatherArmor.png',
      'itens/scroll.png',
      'itens/woodShield.png',
      'itens/ironShield.png',
      'itens/buckler.png',
      'itens/slime_eye.png',
      'itens/club.png',
      'itens/web.png',
      'itens/meat.png',
      'itens/faca.png',
    ]);
    final ui.Image wallImg = await images.load('tilesets/wall1.png');
    final ui.Image floorImg = await images.load('tilesets/floor1.png');
    roamerSprite = await images.load('tilesets/enemy.png');
    bossSprite = await images.load('tilesets/boss.png');
    shrineSprite = await images.load('tilesets/trono.png');

    keySprite = await images.load('itens/key.png');     
    doorTexture = await images.load('tilesets/trapdoor.png');
    chestSprite = await images.load('tilesets/bau.png');
    openChestSprite = await images.load('tilesets/bauAberto.png');
    spikeSprite = await images.load('tilesets/trap.png');
    enemySheets = {
      EnemyType.slime: await images.load('actors/slime.png'),
      EnemyType.goblin: await images.load('actors/goblin.png'),
      EnemyType.spider: await images.load('actors/spider.png'),
      EnemyType.mimic: await images.load('actors/mimic.png'),
      EnemyType.orc: await images.load('actors/orc.png'),
      EnemyType.bat: await images.load('actors/bat.png'),
      EnemyType.bug: await images.load('actors/bug.png'),
      EnemyType.larva: await images.load('actors/larva.png'),
      EnemyType.ovo: await images.load('actors/ovo.png'),
    };
    playerSheet = await images.load('actors/player.png');

    weaponSheet = await images.load('actors/dagger.png');
    armorSheet = await images.load('actors/tanga.png');
    shieldSheet = await images.load('actors/buckler.png');
    playerSlashSprite = await images.load('effects/slashV.png');
    
    enemySlashSprites = {
      EnemyType.slime: await images.load('effects/golpe.png'), 
      EnemyType.goblin: await images.load('effects/golpe.png'),
      EnemyType.orc: await images.load('effects/golpe.png'),
      EnemyType.spider: await images.load('effects/bite.png'), 
      EnemyType.mimic: await images.load('effects/coin.png'),
      EnemyType.bat: await images.load('effects/bite.png'), 
      EnemyType.bug: await images.load('effects/golpe.png'), 
      EnemyType.larva: await images.load('effects/bite.png'), 
    };

    dungeon = DungeonMap(width: mapSize, height: mapSize);
    player = PlayerState(x: dungeon.playerSpawn.x, y: dungeon.playerSpawn.y, facing: Direction.north);

    renderer = MazeRenderer(
      map: dungeon, 
      player: player, 
      wallImage: wallImg, 
      floorImage: floorImg,
      doorImage: doorTexture, 
      keyImage: keySprite, 
      chestImage: chestSprite,
      spikeImage: spikeSprite,
      roamerImage: roamerSprite,
      bossImage: bossSprite,
      shrineImage: shrineSprite,
      openChestImage: openChestSprite,
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
      playerSlashImage: playerSlashSprite, 
      enemySlashImages: enemySlashSprites,
    );
    combatOverlay.size = size; add(combatOverlay);

    minimap = MinimapRenderer();
    add(minimap);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); 

    if (activeMessage != null) {
      double boxWidth = 340; double boxHeight = 100;
      double boxX = (size.x - boxWidth) / 2; double boxY = size.y - boxHeight - 80; 
      final rect = Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight);
      canvas.drawRect(rect, Paint()..color = Colors.black.withOpacity(0.95));
      canvas.drawRect(rect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      final textSpan = TextSpan(text: '$activeMessage\n\n[A] Continuar', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'pixelFont', fontWeight: FontWeight.bold));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
      textPainter.layout(minWidth: boxWidth, maxWidth: boxWidth);
      textPainter.paint(canvas, Offset(boxX, boxY + (boxHeight - textPainter.height) / 2));
    }

    if (currentState == GameState.exploration && isPassTurnPromptOpen) {
      double promptWidth = size.x * 0.8;
      double promptHeight = 80;
      double promptX = (size.x - promptWidth) / 2;
      double promptY = (size.y - promptHeight) / 2;

      final promptRect = Rect.fromLTWH(promptX, promptY, promptWidth, promptHeight);
      canvas.drawRect(promptRect, Paint()..color = Palette.preto);
      canvas.drawRect(promptRect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      final titleSpan = const TextSpan(
        text: "Passar o turno?",
        style: TextStyle(color: Palette.branco, fontSize: 18, fontFamily: 'pixelFont', fontWeight: FontWeight.bold)
      );
      final titlePainter = TextPainter(text: titleSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: promptWidth);
      titlePainter.paint(canvas, Offset(promptX, promptY + 15));

      final optionsSpan = const TextSpan(
        text: "[A] Sim   [B] Não",
        style: TextStyle(color: Palette.amarelo, fontSize: 16, fontFamily: 'pixelFont')
      );
      final optionsPainter = TextPainter(text: optionsSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: promptWidth);
      optionsPainter.paint(canvas, Offset(promptX, promptY + 45));
    }

    if (currentState == GameState.inventory) {
      _drawInventoryScreen(canvas);
    }
    
    if (currentState == GameState.levelUp) {
      final overlayRect = Rect.fromLTWH(0, 0, size.x, size.y * 0.66);
      canvas.drawRect(overlayRect, Paint()..color = Colors.black.withOpacity(0.85));

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
        text: "[▲▼] Mudar Linha   [◄►] Alterar Pontos   [A] Confirmar",
        style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'pixelFont')
      );
      final helpPainter = TextPainter(text: helpSpan, textDirection: TextDirection.ltr)..layout();
      helpPainter.paint(canvas, Offset((size.x - helpPainter.width) / 2, size.y * 0.66 - 40));
    }
  }

  void _drawInventoryScreen(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Palette.preto);
    final titlePainter = TextPainter(text: TextSpan(text: "INVENTÁRIO", style: TextStyle(fontFamily: 'pixelFont', color: Palette.amarelo, fontSize: 24, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    titlePainter.paint(canvas, Offset((size.x - titlePainter.width) / 2, 30));

    double startY = 80;
    for (int i = 0; i < playerCombatStats.inventory.length; i++) {
      Item item = playerCombatStats.inventory[i];
      Color textColor = i == inventoryCursor ? Palette.branco : Palette.cinzaCla;
      String equipTag = (playerCombatStats.equippedWeapon == item || playerCombatStats.equippedArmor == item || playerCombatStats.equippedShield == item) ? " [Equipado]" : "";
      String qtyTag = item.quantity > 1 ? " x${item.quantity}" : "";
      
      canvas.drawRect(Rect.fromLTWH(20, startY + (i * 50), size.x - 40, 45), Paint()..color = i == inventoryCursor ? Palette.azul.withOpacity(0.3) : Colors.transparent);
      
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

      TextPainter(text: TextSpan(text: "${item.name}$equipTag$qtyTag", style: TextStyle(fontFamily: 'pixelFont', color: textColor, fontSize: 24)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(76, startY + (i * 50) + 12));
    }

    if (isActionMenuOpen) {
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.branco..style = PaintingStyle.stroke);
      TextPainter(text: const TextSpan(text: "A - Confirmar\nB - Cancelar", style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: 24)), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout()..paint(canvas, Offset(size.x/2 - 50, size.y/2 - 20));
    }
    if (isItemActionMenuOpen) {
      double menuWidth = 200;
      double menuHeight = 130;
      double menuX = (size.x - menuWidth) / 2 + 50; 
      double menuY = (size.y - menuHeight) / 2;

      final menuRect = Rect.fromLTWH(menuX, menuY, menuWidth, menuHeight);
      canvas.drawRect(menuRect, Paint()..color = Palette.preto.withOpacity(0.95));
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
    overlays.remove('MainMenu');  // Remove o menu inicial em Flutter
    overlays.add('ManualMenu');   // Adiciona o novo overlay do manual!
  }

  void closeManual() {
    currentState = GameState.mainMenu;
    overlays.remove('ManualMenu'); // Esconde o manual
    overlays.add('MainMenu');      // Devolve o menu inicial
  }

  void resetGame() {
    for (var enemy in combatOverlay.enemies) {
      enemy.removeFromParent(); 
    }
    combatOverlay.enemies.clear();
    _messageQueue.clear(); // Limpa mensagens fantasmas

    playerCombatStats.str = 5;
    playerCombatStats.con = 5;
    playerCombatStats.wis = 5;
    playerCombatStats.hp = playerCombatStats.maxHp;
    playerCombatStats.stamina = playerCombatStats.con*3;
    playerCombatStats.mana = playerCombatStats.wis*3;
    playerCombatStats.currentPhase = CombatPhase.idle;

    _initializeInventory();
    
    player.floorLevel = 1;
    player.hasKey = false;
    player.noiseLevel = 0;

    dungeon.width = mapSize;
    dungeon.height = mapSize;
    dungeon.generateProceduralMap();
    player.x = dungeon.playerSpawn.x;
    player.y = dungeon.playerSpawn.y;
    player.facing = Direction.north;
    
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

  void handlePlayerDeath() {
    currentState = GameState.gameOver;
    overlays.add('GameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);

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
        _triggerSpecificEncounter(EnemyType.boss1);
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

    // REFACTOR: Congela o update global enquanto houver mensagens ativas na fila
    if (activeMessage != null) {
      return; 
    }

    // --- 1. ATUALIZA A IA E COLISÃO ---
    if (combatOverlay.enemies.isNotEmpty) {
      Rect pHitbox = playerCombatStats.getHitbox(size);
      bool weaponHasReach = playerCombatStats.equippedWeapon?.hasReach ?? false;
      bool weaponHasStun = playerCombatStats.equippedWeapon?.hasStun ?? false;
      
      if (playerCombatStats.currentPhase == CombatPhase.active && !playerCombatStats.attackHit) {
        playerCombatStats.attackHit = true;
        for (var enemy in combatOverlay.enemies) {
          if (!enemy.isFrontRow && !weaponHasReach) continue;
          if (!enemy.isDying && pHitbox.overlaps(enemy.getHurtbox(size))){
            double damage = playerCombatStats.str.toDouble();
            if (playerCombatStats.equippedWeapon != null) damage += playerCombatStats.equippedWeapon!.power;
            if(enemy.isVulnerable){
              playerCombatStats.reflex = false;
              bool isCrit = Random().nextDouble() * 100 < playerCombatStats.critChance;
              double stun = 0.4;
              if (isCrit) {
                damage *= playerCombatStats.critMultiplier;
                combatOverlay.addFloatingText("*CRIT.*", enemy.getHurtbox(size), Palette.amarelo);
                if(weaponHasStun) stun = 0.8;
              }
              enemy.hp -= damage;
              enemy.applyHitStun(stun);
              playerCombatStats.recoverMana();
              FlameAudio.play('sfx/hit.wav');
            }else{
              enemy.applyHitGuard(0.1);
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

    // REFACTOR: LÓGICA DE VITÓRIA INTEGRADA À FILA GENÉRICA
    if (combatOverlay.enemies.isEmpty && !_victoryProcessed && playerCombatStats.currentPhase != CombatPhase.exiting) {
      if (playerCombatStats.currentPhase == CombatPhase.idle) {
        _victoryProcessed = true; // Impede que execute este bloco em loop repetidamente
        playerCombatStats.essence += encounterEssence; 
        playerCombatStats.isGuarding = false; 

        // 1. Mensagem principal de vitória (Dinheiro/Essências)
        showMessage("Vitória! Você purificou a área e obteve +${encounterEssence.toInt()} Essências!");

        // 2. Roda a roleta de drops (cada item bem-sucedido adicionará sua própria mensagem à fila)
        for (var drop in encounterDrop){
          if(Random().nextInt(100) <= 10) {
            receiveItem(drop); 
          }
        }
        
        // 3. MÁGICA: Adicionamos uma mensagem de encerramento no fim da fila.
        // Quando o jogador fechar esta última caixa de texto, o callback 'onDismiss' ativa a transição de saída!
        showMessage("A batalha terminou. Retornando ao labirinto...", onDismiss: () {
          _endEncounter();
        });
      }
    }

    // --- 2. MOVIMENTAÇÃO DO JOGADOR ---
    bool isFreeToMove = activeMessage == null && (playerCombatStats.currentPhase == CombatPhase.idle || playerCombatStats.currentPhase == CombatPhase.walk || playerCombatStats.currentPhase == CombatPhase.guard);

    if (isFreeToMove) {
      if (downPressed && !playerCombatStats.cansado) { playerCombatStats.isGuarding = true; playerCombatStats.currentPhase = CombatPhase.guard; } 
      else {
        playerCombatStats.isGuarding = false;
        if (dashTimer > 0) {
          dashTimer -= dt;
          playerCombatStats.strafePosition += dashDirection * 6.0 * dt; 
        } else {
          if (leftPressed) { playerCombatStats.strafePosition -= (playerCombatStats.moveSpeed - playerCombatStats.moveSpeedPenalty) * dt; playerCombatStats.currentPhase = CombatPhase.walk; } 
          else if (rightPressed) { playerCombatStats.strafePosition += (playerCombatStats.moveSpeed - playerCombatStats.moveSpeedPenalty) * dt; playerCombatStats.currentPhase = CombatPhase.walk; } 
          else { playerCombatStats.currentPhase = CombatPhase.idle; }
        }
        playerCombatStats.strafePosition = playerCombatStats.strafePosition.clamp(-1.0, 1.0);
      }
    } else if (activeMessage != null) {
      playerCombatStats.currentPhase = CombatPhase.idle; // Fica parado lendo o texto da fila
    }
  }

  void _endEncounter() { playerCombatStats.currentPhase = CombatPhase.exiting; playerCombatStats.animTimer = 1; }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    leftPressed = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    rightPressed = keysPressed.contains(LogicalKeyboardKey.arrowRight); 
    downPressed = keysPressed.contains(LogicalKeyboardKey.arrowDown);
    upPressed = keysPressed.contains(LogicalKeyboardKey.arrowUp);
    
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyP || event.logicalKey == LogicalKeyboardKey.escape) togglePause();
      
      if (event.logicalKey == LogicalKeyboardKey.keyZ) startInput(GameInput.buttonA);
      if (event.logicalKey == LogicalKeyboardKey.keyX) startInput(GameInput.buttonB);

      if (event.logicalKey == LogicalKeyboardKey.keyC){
        showHitboxes = !showHitboxes;
      }

      if (currentState == GameState.levelUp && activeMessage == null) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) startInput(GameInput.up);
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) startInput(GameInput.down);
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) startInput(GameInput.left);
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) startInput(GameInput.right);
      } else if (currentState == GameState.inventory || currentState == GameState.combat
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

  void applyEnemyDamage(Enemy enemy) {
    double defense = playerCombatStats.equippedArmor?.power ?? 0; 
    double dmg = max(1, enemy.damage - defense);
    bool unblockable = enemy.isHeavyAttack;
    if (playerCombatStats.isGuarding && !unblockable) {
      FlameAudio.play('sfx/block.wav');
      if (playerCombatStats.stamina >= 0) {
        if (playerCombatStats.staminaInfiniteTmr <= 0){
          playerCombatStats.stamina -= (16 - playerCombatStats.equippedShield!.power); 
        } 
        playerCombatStats.stamina = playerCombatStats.stamina.clamp(0, playerCombatStats.con * 3);
        if (playerCombatStats.stamina <= 0) {
          playerCombatStats.cansado = true;
        }
        playerCombatStats.flashColor = Palette.cinza;
        playerCombatStats.hitFlashTimer = 0.1; 
      } else { 
        playerCombatStats.stamina = 0; 
        playerCombatStats.hp -= dmg; 
        playerCombatStats.applyHitStun(0.3);
        combatOverlay.playerHitTicker.reset(); 
        combatOverlay.weaponHitTicker.reset();
      }
    } else { 
      FlameAudio.play('sfx/hit.wav');
      playerCombatStats.hp -= dmg; 
      playerCombatStats.applyHitStun(0.3); 
      combatOverlay.playerHitTicker.reset(); 
      combatOverlay.weaponHitTicker.reset();
    }
    if (playerCombatStats.hp < 0) playerCombatStats.hp = 0;
  }

  void triggerEncounter() {
    FlameAudio.play('sfx/encounter.wav');
    encounterEssence = 0;         
    encounterDrop.clear();
    _victoryProcessed = false; // REFACTOR
    currentState = GameState.combat;
    int numEnemies = Random().nextInt(4) + 1; 
    List<Enemy> spawnedEnemies = [];
    List<Enemy Function()> iniPool = [
      () => SlimeEnemy(),
      () => GoblinEnemy(),
      () => SpiderEnemy(),
    ];
    
    if(player.floorLevel == 2){
      iniPool.add(() => BatEnemy());
    }
    if(player.floorLevel == 3){
      iniPool.add(() => OrcEnemy());
    }

    if(player.floorLevel >= 4){
      iniPool = [
        () => OvoEnemy(),
        () => LarvaEnemy(),
        () => BugEnemy(),
      ];
    }


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
    encounterDrop.clear();
    _victoryProcessed = false;
    currentState = GameState.combat;
    Enemy newEnemy;
    switch (type) {
        case EnemyType.slime: newEnemy = SlimeEnemy(); break;
        case EnemyType.goblin: newEnemy = GoblinEnemy(); break;
        case EnemyType.spider: newEnemy = SpiderEnemy(); break;
        case EnemyType.orc: newEnemy = OrcEnemy(); break;
        case EnemyType.mimic: newEnemy = MimicEnemy(); break;
        case EnemyType.boss1: newEnemy = OrcChefe(); break;
        default: newEnemy = SlimeEnemy(); break;
      }
    newEnemy.strafePosition = 0.0; 
    combatOverlay.startEncounter([newEnemy]);
    playerCombatStats.currentPhase = CombatPhase.entering; playerCombatStats.animTimer = 1;
  }

  void startInput(GameInput input) {
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
      if (input == GameInput.up || input == GameInput.down) {
        FlameAudio.play('sfx/hover.wav');
        // Como só temos 2 opções (0 e 1), alternamos entre elas:
        mainMenuCursor.value = (mainMenuCursor.value == 0) ? 1 : 0; 
      }
      if (input == GameInput.buttonA) {
        FlameAudio.play('sfx/confirm.wav');
        if (mainMenuCursor.value == 0) {
          startGame();
        } else {
          openManual();
        }
      }
      return; // Interrompe para não vazar comandos
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
          inventoryCursor = max(0, inventoryCursor - 1);
        } else if (input == GameInput.down) {
          FlameAudio.play('sfx/hover.wav');
          inventoryCursor = min(playerCombatStats.inventory.length - 1, inventoryCursor + 1);
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
        FlameAudio.play('sfx/confirm.wav');
        currentState = GameState.inventory; 
        inventoryCursor = 0; 
        isActionMenuOpen = false; 
        isItemActionMenuOpen = false; 
      }
      return; 
    } 
    
    // --- MODO COMBATE ---
    if (currentState == GameState.combat) {
      // REFACTOR: Intercepta o botão [A] se houver caixas de diálogo na fila de combate
      if (activeMessage != null) { 
        if (input == GameInput.buttonA) dismissMessage(); 
        return; 
      }
      
      if (input == GameInput.left) {
        leftPressed = true;
        if (leftTapTimer > 0) {
          playerCombatStats.stamina -= 15;
          dashTimer = 0.10; 
          dashDirection = -1.0;
          leftTapTimer = 0.0; 
        } else {
          leftTapTimer = 0.25; 
        }
      }
      if (input == GameInput.right) {
        rightPressed = true;
        if (rightTapTimer > 0) {
          playerCombatStats.stamina -= 15;
          dashTimer = 0.10;
          dashDirection = 1.0;
          rightTapTimer = 0.0;
        } else {
          rightTapTimer = 0.25;
        }
      }
      if (input == GameInput.down) downPressed = true;
      if (input == GameInput.buttonA) {
        _performAttack(); // Filtramos activeMessage acima, processa o ataque nativo direto
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
      playerCombatStats.equippedWeapon = item; 
      if (item.onUse != null) item.onUse!(item, this);
      await changeWeaponSprite('actors/$fileName'); 
    }
    else if (item.type == ItemType.armor) { 
      playerCombatStats.equippedArmor = item; 
      if (item.onUse != null) item.onUse!(item, this);
      await changeArmorSprite('actors/$fileName'); 
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
    playerCombatStats.recoverMana();
    if (dungeon.getTile(player.x, player.y) == TileType.spike && dungeon.spikeState == 3) {
      playerCombatStats.hp -= 5; 
      playerCombatStats.applyHitStun(0.3); 
      showMessage("Você pisou em uma armadilha de espinhos!");
      if (playerCombatStats.hp <= 0) handlePlayerDeath();
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

    if (playerTile == TileType.floor) {
      Point<int> currentPos = Point(player.x, player.y);
      if (!dungeon.droppedItems.containsKey(currentPos) || dungeon.droppedItems[currentPos]!.isEmpty) {
        isPassTurnPromptOpen = true; 
        return;
      }
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
        showMessage("A porta se abre. Descendo para o Andar ${player.floorLevel + 1}...", onDismiss: () {
          player.floorLevel++;
          player.hasKey = false;
          player.noiseLevel = 0;
          dungeon.width += 5; 
          dungeon.height += 5;
          dungeon.level ++;
          dungeon.generateProceduralMap(); 
          player.x = dungeon.playerSpawn.x;
          player.y = dungeon.playerSpawn.y;
          player.facing = Direction.north;
        });
      } else {
        showMessage("A porta está trancada. Encontre a chave.");
      }
    } 
    else if (playerTile == TileType.chest) {
      int chance = Random().nextInt(100);
      
      if (chance < 25) { 
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
          ItemDatabase.espadaLonga,
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

        bool tryEquipment = chance >= 60 && chance < 75;

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
      }
    }
  }
}