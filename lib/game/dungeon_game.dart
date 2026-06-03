// (Mantenha os seus imports e variáveis iniciais...)
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

enum GameInput { up, down, left, right, buttonA, buttonB, pause }
enum GameState { mainMenu, exploration, combat, paused, gameOver, inventory, levelUp }

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
  late ui.Image spikeSprite;
  late ui.Image roamerSprite;

  bool leftPressed = false, rightPressed = false, downPressed = false, showHitboxes = false;
  bool showVictoryMessage = false;
  double encounterEssence = 0;

  String? activeMessage; 
  VoidCallback? onMessageDismissed; 
  
  int mapSize = 20;

  // --- VARIÁVEIS DE INVENTÁRIO ---
  int inventoryCursor = 0;
  bool isActionMenuOpen = false;
  int selectedConsumableIndex = 0;
  bool isItemActionMenuOpen = false;
  int itemActionCursor = 0;

  int levelUpCursor = 0;       // 0: STR, 1: CON, 2: WIS, 3: Confirmar
  int pointsToDistribute = 0;  // Começa com 3 pontos ganhos
  int tempStr = 0, tempCon = 0, tempWis = 0; // Guardam a distribuição temporária
  
  // Cálculo de custo progressivo: ex: Custo = 50 + (LevelTotal * 15)
  int get levelUpCost {
    int totalLevel = (playerCombatStats.str + playerCombatStats.con + playerCombatStats.wis).toInt();
    return 50 + (totalLevel * 15);
  }

  void showMessage(String text, {VoidCallback? onDismiss}) {
    activeMessage = text;
    onMessageDismissed = onDismiss;
  }

  void dismissMessage() {
    activeMessage = null;
    if (onMessageDismissed != null) {
      onMessageDismissed!(); 
      onMessageDismissed = null;
    }
  }

  // Função para receber itens (Tenta colocar na mochila, se não der, cai no chão)
  void receiveItem(Item newItem) {
    // 1. Tenta acumular se for consumível (Pilha)
    if (newItem.type == ItemType.consumable) {
      var existing = playerCombatStats.inventory.where((i) => i.name == newItem.name).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity += newItem.quantity;
        showMessage("Obteve mais ${newItem.quantity}x ${newItem.name}!");
        return;
      }
    }

    // 2. Verifica se tem espaço
    if (playerCombatStats.inventory.length < playerCombatStats.maxInventory) {
      playerCombatStats.inventory.add(newItem);
      showMessage("Você pegou: ${newItem.name}!");
    } else {
      // 3. Sem espaço: Deixa no chão
      Point<int> pos = Point(player.x, player.y);
      dungeon.droppedItems.putIfAbsent(pos, () => []).add(newItem);
      showMessage("Inventário Cheio! ${newItem.name} ficou no chão.");
    }
  }

  // Função para Descartar itens do Inventário
  void dropSelectedItem(int cursorIndex) {
    if (playerCombatStats.inventory.isEmpty) return;
    Item item = playerCombatStats.inventory[cursorIndex];

    // Impede de jogar fora algo que está equipado
    if (playerCombatStats.equippedWeapon == item || 
        playerCombatStats.equippedArmor == item || 
        playerCombatStats.equippedShield == item) {
      showMessage("Não pode descartar um item Equipado!");
      return;
    }

    // Joga no chão
    Point<int> pos = Point(player.x, player.y);
    dungeon.droppedItems.putIfAbsent(pos, () => []).add(item);
    
    // Remove da mochila
    playerCombatStats.inventory.removeAt(cursorIndex);
    showMessage("${item.name} foi deixado no chão.");
  }

  void _initializeInventory() {
    playerCombatStats.inventory = [
      ItemDatabase.adaga,
      ItemDatabase.tanga,
      ItemDatabase.bloquel,
      ItemDatabase.escudoMadeira,
      ItemDatabase.escudoFerro,
      ItemDatabase.espadaCurta,
      ItemDatabase.healthPotion,
      ItemDatabase.toxicCloud,
    ];
    playerCombatStats.equippedWeapon = playerCombatStats.inventory[0];
    playerCombatStats.equippedArmor = playerCombatStats.inventory[1];
    playerCombatStats.equippedShield = playerCombatStats.inventory[2];
    selectedConsumableIndex = 0;
  }

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      'itens/dagger.png',
      'itens/armor.png',
      'itens/potion.png',
      'itens/tanga.png',
      'itens/sword.png',
      'itens/longSword.png',
      'itens/sword.png',
      'itens/axe.png',
      'itens/bomb.png',
      'itens/leatherArmor.png',
      'itens/scroll.png',
      'itens/woodShield.png',
      'itens/ironShield.png',
      'itens/buckler.png',
    ]);
    final ui.Image wallImg = await images.load('tilesets/wall.png');
    final ui.Image floorImg = await images.load('tilesets/floor.png');
    roamerSprite = await images.load('tilesets/enemy.png');

    keySprite = await images.load('itens/key.png');     
    doorTexture = await images.load('tilesets/trapdoor.png');
    chestSprite = await images.load('tilesets/bau.png');
    spikeSprite = await images.load('tilesets/trap.png');
    enemySheets = {
      EnemyType.slime: await images.load('actors/slime.png'),
      EnemyType.goblin: await images.load('actors/goblin.png'),
      EnemyType.spider: await images.load('actors/spider.png'),
      EnemyType.mimic: await images.load('actors/mimic.png'),
    };
    playerSheet = await images.load('actors/player.png');

    weaponSheet = await images.load('actors/dagger.png');
    armorSheet = await images.load('actors/tanga.png');
    shieldSheet = await images.load('actors/buckler.png');
    playerSlashSprite = await images.load('effects/slashV.png'); // O corte da espada do herói
    
    enemySlashSprites = {
      EnemyType.slime: await images.load('effects/golpe.png'), 
      EnemyType.goblin: await images.load('effects/golpe.png'),
      EnemyType.spider: await images.load('effects/bite.png'), 
      EnemyType.mimic: await images.load('effects/coin.png'),
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
      playerSlashImage: playerSlashSprite,    // <--- Passa o do player
      enemySlashImages: enemySlashSprites,    // <--- Passa a lista dos inimigos
    );
    combatOverlay.size = size; add(combatOverlay);

    minimap = MinimapRenderer();
    add(minimap);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); 

    if (activeMessage != null /* && currentState == GameState.exploration */) {
      // (Código existente da caixa de diálogo da exploração...)
      double boxWidth = 340; double boxHeight = 100;
      double boxX = (size.x - boxWidth) / 2; double boxY = size.y - boxHeight - 80; 
      final rect = Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight);
      canvas.drawRect(rect, Paint()..color = Colors.black.withOpacity(0.95));
      canvas.drawRect(rect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      final textSpan = TextSpan(text: '$activeMessage\n\n[A] Continuar', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Courier', fontWeight: FontWeight.bold));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
      textPainter.layout(minWidth: boxWidth, maxWidth: boxWidth);
      textPainter.paint(canvas, Offset(boxX, boxY + (boxHeight - textPainter.height) / 2));
    }

    if (currentState == GameState.inventory) {
      _drawInventoryScreen(canvas);
    }
    // --- DESENHO DA TELA DE LEVEL UP ---
    if (currentState == GameState.levelUp) {
      // Cria um fundo escuro translúcido elegante
      final overlayRect = Rect.fromLTWH(0, 0, size.x, size.y * 0.66); // Cobre os 2/3 superiores do jogo
      canvas.drawRect(overlayRect, Paint()..color = Colors.black.withOpacity(0.85));

      final borderPaint = Paint()..color = Palette.roxo..style = PaintingStyle.stroke..strokeWidth = 3;
      canvas.drawRect(overlayRect.deflate(15), borderPaint);

      final titleSpan = const TextSpan(
        text: "Distribua seus Pontos",
        style: TextStyle(color: Palette.roxo, fontSize: 22, fontFamily: 'Courier', fontWeight: FontWeight.bold)
      );
      final titlePainter = TextPainter(text: titleSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: size.x);
      titlePainter.paint(canvas, Offset(0, 40));

      // Mostra os pontos restantes
      final ptSpan = TextSpan(
        text: "Pontos Disponíveis: $pointsToDistribute",
        style: TextStyle(color: pointsToDistribute > 0 ? Palette.amarelo : Palette.verde, fontSize: 18, fontFamily: 'Courier')
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
          style: TextStyle(color: textColor, fontSize: 18, fontFamily: 'Courier', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)
        );
        final labelPainter = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)..layout();
        labelPainter.paint(canvas, Offset(40, 160 + (i * 45)));
      }

      // Ajuda rápida no rodapé da janela
      final helpSpan = const TextSpan(
        text: "[▲▼] Mudar Linha   [◄►] Alterar Pontos   [A] Confirmar",
        style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Courier')
      );
      final helpPainter = TextPainter(text: helpSpan, textDirection: TextDirection.ltr)..layout();
      helpPainter.paint(canvas, Offset((size.x - helpPainter.width) / 2, size.y * 0.66 - 40));
    }
  }

  void _drawInventoryScreen(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Palette.preto);
    final titlePainter = TextPainter(text: TextSpan(text: "INVENTÁRIO", style: TextStyle(color: Palette.amarelo, fontSize: 24, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    titlePainter.paint(canvas, Offset((size.x - titlePainter.width) / 2, 30));

    double startY = 80;
    for (int i = 0; i < playerCombatStats.inventory.length; i++) {
      Item item = playerCombatStats.inventory[i];
      Color textColor = i == inventoryCursor ? Palette.branco : Palette.cinzaCla;
      String equipTag = (playerCombatStats.equippedWeapon == item || playerCombatStats.equippedArmor == item || playerCombatStats.equippedShield == item) ? " [Equipado]" : "";
      String qtyTag = item.quantity > 1 ? " x${item.quantity}" : "";
      
      // Fundo de seleção
      canvas.drawRect(Rect.fromLTWH(20, startY + (i * 50), size.x - 40, 45), Paint()..color = i == inventoryCursor ? Palette.azul.withOpacity(0.3) : Colors.transparent);
      
      // --- NOVO: DESENHA O ÍCONE DO ITEM NA LISTA ---
      try {
        // Tenta pegar do cache
        ui.Image itemImg = images.fromCache(item.imagePath);
        
        // Garante que a cor não seja nula (fallback para branco se não tiver cor)
        Color tint = item.cor; 
        final tintPaint = Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
        
        canvas.drawImageRect(
          itemImg,
          Rect.fromLTWH(0, 0, itemImg.width.toDouble(), itemImg.height.toDouble()),
          Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), 
          tintPaint 
        );
      } catch (e) {
        // SE A IMAGEM NÃO APARECER, OLHE O CONSOLE (TERMINAL) DO VS CODE!
        debugPrint("⚠️ ERRO: A imagem '${item.imagePath}' não foi carregada no onLoad!");
        
        // Desenha um quadrado rosa choque no lugar para você saber que a imagem falhou
        canvas.drawRect(
          Rect.fromLTWH(25, startY + (i * 50) + 2, 50, 50), 
          Paint()..color = Colors.pinkAccent
        );
      }

      // Texto do Item (Agora com Offset 60 para não ficar em cima da imagem)
      TextPainter(text: TextSpan(text: "${item.name}$equipTag$qtyTag", style: TextStyle(color: textColor, fontSize: 24)), textDirection: TextDirection.ltr)..layout()..paint(canvas, Offset(70, startY + (i * 50) + 12));
    }

    if (isActionMenuOpen) {
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.preto);
      canvas.drawRect(Rect.fromLTWH(size.x/2 - 75, size.y/2 - 40, 150, 80), Paint()..color = Palette.branco..style = PaintingStyle.stroke);
      TextPainter(text: const TextSpan(text: "A - Confirmar\nB - Cancelar", style: TextStyle(color: Palette.branco, fontSize: 24)), textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout()..paint(canvas, Offset(size.x/2 - 50, size.y/2 - 20));
    }
    if (isItemActionMenuOpen) {
      double menuWidth = 200;
      double menuHeight = 130;
      double menuX = (size.x - menuWidth) / 2 + 50; // Deslocado para a direita da lista
      double menuY = (size.y - menuHeight) / 2;

      final menuRect = Rect.fromLTWH(menuX, menuY, menuWidth, menuHeight);
      // Fundo preto com borda branca
      canvas.drawRect(menuRect, Paint()..color = Palette.preto.withOpacity(0.95));
      canvas.drawRect(menuRect, Paint()..color = Palette.branco..style = PaintingStyle.stroke..strokeWidth = 2);

      List<String> options = ["Equipar/Usar", "Descartar", "Cancelar"];
      
      for (int i = 0; i < options.length; i++) {
        // Se for a opção selecionada, fica amarela e ganha uma setinha ">"
        Color textColor = (i == itemActionCursor) ? Palette.amarelo : Palette.branco;
        String prefix = (i == itemActionCursor) ? "> " : "  ";
        
        final optSpan = TextSpan(
          text: "$prefix${options[i]}", 
          style: TextStyle(color: textColor, fontSize: 18, fontFamily: 'Courier', fontWeight: FontWeight.bold)
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

  void resetGame() {
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
    
    if (currentState == GameState.mainMenu || currentState == GameState.paused || currentState == GameState.gameOver) return;

    if (currentState == GameState.exploration) {
      if (activeMessage != null) return;
      // --- SISTEMA DE FOG OF WAR ---
      // Revela uma área 3x3 ao redor do jogador para que ele veja as paredes coladas a ele
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          dungeon.markExplored(player.x + dx, player.y + dy);
        }
      }
      
      // Checa se o jogador pisou no mesmo bloco onde está a chave
      if (dungeon.keyPosition != null && player.x == dungeon.keyPosition!.x && player.y == dungeon.keyPosition!.y) {
        player.hasKey = true;
        dungeon.keyPosition = null;
        showMessage("Você encontrou a Chave da Masmorra!");
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
      return; // Pausa o update do jogo enquanto a mensagem estiver ativa
    }

    // --- 1. ATUALIZA A IA E COLISÃO ---
    if (combatOverlay.enemies.isNotEmpty) {
      //Rect pHurtbox = playerCombatStats.getHurtbox(size);

      Rect pHitbox = playerCombatStats.getHitbox(size);
      bool weaponHasReach = playerCombatStats.equippedWeapon?.hasReach ?? false;
      // A. Ataque do Jogador
      if (playerCombatStats.currentPhase == CombatPhase.active && !playerCombatStats.attackHit) {
        playerCombatStats.attackHit = true;
        for (var enemy in combatOverlay.enemies) {
          if (!enemy.isFrontRow && !weaponHasReach) continue;
          if (!enemy.isDying && pHitbox.overlaps(enemy.getHurtbox(size))){
            double damage = playerCombatStats.str.toDouble();//(playerCombatStats.comboCount >= 3) ? playerCombatStats.str * 1.5 : playerCombatStats.str.toDouble();
            if (playerCombatStats.equippedWeapon != null) damage += playerCombatStats.equippedWeapon!.power;
            if(enemy.isVulnerable){
              bool isCrit = Random().nextDouble() * 100 < playerCombatStats.critChance;
              if (isCrit) {
                damage *= playerCombatStats.critMultiplier;
                combatOverlay.addFloatingText("*CRIT.*", enemy.getHurtbox(size), Palette.amarelo);
              }
              //combatOverlay.addFloatingText("-${damage.toInt()}", enemy.getHurtbox(size), Palette.branco);
              enemy.hp -= damage;
              enemy.applyHitStun(0.3);
            }else{
              enemy.applyHitGuard(0.1);
              combatOverlay.addFloatingText("BLOCK!", enemy.getHurtbox(size), Palette.cinzaCla);
            }
            
            if (enemy.hp <= 0) {
              enemy.hp = 0;
              enemy.isDying = true; // Inicia animação de morte (piscar)
              encounterEssence += enemy.dropEssence; // Guarda a essência provisoriamente
            }
          }
        }
        //combatOverlay.enemies.removeWhere((e) => e.hp <= 0);
        if (combatOverlay.enemies.isEmpty) { _endEncounter(); return; }
      }

      // B. Processamento e Ataque dos Inimigos
      
    }

    combatOverlay.enemies.removeWhere((e) => !e.isAlive);

    if (combatOverlay.enemies.isEmpty && !showVictoryMessage && playerCombatStats.currentPhase != CombatPhase.exiting) {
      // ...Aguarda o jogador terminar qualquer animação de golpe e voltar pro Idle
      if (playerCombatStats.currentPhase == CombatPhase.idle) {
        showVictoryMessage = true; // Mostra a caixa na tela
        playerCombatStats.essence += encounterEssence; // Transfere pra carteira do player
        
        playerCombatStats.isGuarding = false; // Solta o escudo se tiver segurando
      }
    }

    // --- 2. MOVIMENTAÇÃO DO JOGADOR ---
    bool isFreeToMove = !showVictoryMessage && (playerCombatStats.currentPhase == CombatPhase.idle || playerCombatStats.currentPhase == CombatPhase.walk || playerCombatStats.currentPhase == CombatPhase.guard);

    if (isFreeToMove) {
      if (downPressed && !playerCombatStats.cansado) { playerCombatStats.isGuarding = true; playerCombatStats.currentPhase = CombatPhase.guard; } 
      else {
        playerCombatStats.isGuarding = false;
        if (leftPressed) { playerCombatStats.strafePosition -= (playerCombatStats.moveSpeed - playerCombatStats.moveSpeedPenalty) * dt; playerCombatStats.currentPhase = CombatPhase.walk; } 
        else if (rightPressed) { playerCombatStats.strafePosition += (playerCombatStats.moveSpeed - playerCombatStats.moveSpeedPenalty) * dt; playerCombatStats.currentPhase = CombatPhase.walk; } 
        else { playerCombatStats.currentPhase = CombatPhase.idle; }
        playerCombatStats.strafePosition = playerCombatStats.strafePosition.clamp(-1.0, 1.0);
      }
    } else if (showVictoryMessage) {
      playerCombatStats.currentPhase = CombatPhase.idle; // Fica parado lendo
    }
  }

  void _endEncounter() { playerCombatStats.currentPhase = CombatPhase.exiting; playerCombatStats.animTimer = 1; }
  //void _handlePlayerDeath() { playerCombatStats.hp = playerCombatStats.maxHp; currentState = GameState.exploration; playerCombatStats.currentPhase = CombatPhase.idle; }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    leftPressed = keysPressed.contains(LogicalKeyboardKey.arrowLeft); rightPressed = keysPressed.contains(LogicalKeyboardKey.arrowRight); downPressed = keysPressed.contains(LogicalKeyboardKey.arrowDown);
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyP || event.logicalKey == LogicalKeyboardKey.escape) togglePause();
      
      if (event.logicalKey == LogicalKeyboardKey.keyZ) startInput(GameInput.buttonA);
      if (event.logicalKey == LogicalKeyboardKey.keyX) startInput(GameInput.buttonB);
      
      if (currentState == GameState.exploration && activeMessage == null) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) startInput(GameInput.up);
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) startInput(GameInput.down);
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) startInput(GameInput.left);
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) startInput(GameInput.right);
      } else if (currentState == GameState.inventory || currentState == GameState.combat) {
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

  void triggerEncounter() {
    encounterEssence = 0;         
    showVictoryMessage = false;
    currentState = GameState.combat;
    int numEnemies = Random().nextInt(4) + 1; 
    List<Enemy> spawnedEnemies = [];
    for (int i = 0; i < numEnemies; i++) {
      int enemyType = Random().nextInt(3); 
      Enemy newEnemy;
      switch (enemyType) {
        case 0: newEnemy = SlimeEnemy(); break;
        case 1: newEnemy = GoblinEnemy(); break;
        case 2: newEnemy = SpiderEnemy(); break;
        default: newEnemy = SlimeEnemy(); break;
      }
      
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
    playerCombatStats.currentPhase = CombatPhase.entering; playerCombatStats.animTimer = 0.5;
  }

  void _triggerSpecificEncounter(EnemyType type) {
    encounterEssence = 0; showVictoryMessage = false; currentState = GameState.combat;
    Enemy newEnemy = MimicEnemy(); // Se quiser adicionar outros específicos depois, basta checar o tipo!
    newEnemy.strafePosition = 0.0; // Centralizado no jogador
    combatOverlay.startEncounter([newEnemy]);
    playerCombatStats.currentPhase = CombatPhase.entering; playerCombatStats.animTimer = 0.5;
  }

  // (Mantenha seus métodos startInput e stopInput que já estavam prontos para a interface touch)
  void startInput(GameInput input) {
    if (input == GameInput.pause) { togglePause(); return; }

    // level up
    if (currentState == GameState.levelUp) {
      if (input == GameInput.up) {
        levelUpCursor = (levelUpCursor - 1 + 4) % 4; // Navega pelas 3 opções + botão confirmar
      }
      if (input == GameInput.down) {
        levelUpCursor = (levelUpCursor + 1) % 4;
      }
      
      // Adicionar pontos (Botão Direita ou Botão A nas opções de status)
      if (input == GameInput.right || (input == GameInput.buttonA && levelUpCursor < 3)) {
        if (pointsToDistribute > 0 && levelUpCursor < 3) {
          pointsToDistribute--;
          if (levelUpCursor == 0) tempStr++;
          if (levelUpCursor == 1) tempCon++;
          if (levelUpCursor == 2) tempWis++;
        }
      }
      
      // Remover pontos distribuídos temporariamente (Botão Esquerda ou Botão B)
      if (input == GameInput.left || input == GameInput.buttonB) {
        if (levelUpCursor == 0 && tempStr > 0) { tempStr--; pointsToDistribute++; }
        if (levelUpCursor == 1 && tempCon > 0) { tempCon--; pointsToDistribute++; }
        if (levelUpCursor == 2 && tempWis > 0) { tempWis--; pointsToDistribute++; }
        // Se apertar B no botão de Confirmar, cancela tudo e volta para a exploração sem gastar nada
        if (levelUpCursor == 3 && input == GameInput.buttonB) {
          currentState = GameState.exploration;
        }
      }

      // Confirmar (Botão A em cima da opção "CONFIRMAR")
      if (input == GameInput.buttonA && levelUpCursor == 3) {
        if (pointsToDistribute == 0) {
          // 1. Cobra o custo de essências
          playerCombatStats.essence -= levelUpCost;
          
          // 2. Aplica definitivamente os atributos
          playerCombatStats.str += tempStr;
          playerCombatStats.con += tempCon;
          playerCombatStats.wis += tempWis;

          playerCombatStats.recalculateMaxHp();
          
          // --- REGRA CRÍTICA: Destrói o Altar transformando-o em chão comum! ---
          dungeon.grid[player.y][player.x] = TileType.floor;
          
          showMessage("Atributos Melhorados! O Altar desmorona...");
          currentState = GameState.exploration;
        } else {
          showMessage("Distribua todos os 3 pontos antes de confirmar!");
        }
      }
      return;
    }
    // --- MODO INVENTÁRIO ---
    if (currentState == GameState.inventory) {
      if (playerCombatStats.inventory.isEmpty) {
        isItemActionMenuOpen = false;
      }

      // SUBMENU DO ITEM (Aberto)
      if (isItemActionMenuOpen) {
        if (input == GameInput.up) {
          itemActionCursor = (itemActionCursor - 1 + 3) % 3;
        } else if (input == GameInput.down) {
          itemActionCursor = (itemActionCursor + 1) % 3;
        } else if (input == GameInput.buttonA) {
          
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
          isItemActionMenuOpen = false; 
        }
      } 
      // NAVEGAÇÃO NORMAL DO INVENTÁRIO (Submenu Fechado)
      else {
        if (input == GameInput.up) {
          inventoryCursor = max(0, inventoryCursor - 1);
        } else if (input == GameInput.down) {
          inventoryCursor = min(playerCombatStats.inventory.length - 1, inventoryCursor + 1);
        } else if (input == GameInput.buttonA && playerCombatStats.inventory.isNotEmpty) {
          isItemActionMenuOpen = true;
          itemActionCursor = 0;
        } else if (input == GameInput.buttonB || input == GameInput.pause) {
          currentState = GameState.exploration; 
        }
      }
      return; // FUNDAMENTAL: Impede que a mesma tecla vaze para a exploração!
    }
    
    // --- MODO EXPLORAÇÃO ---
    if (currentState == GameState.exploration) {
      if (activeMessage != null) { if (input == GameInput.buttonA) dismissMessage(); return; }
      if (input == GameInput.up) { if (player.move(true, dungeon)) _onPlayerStepped(); }
      if (input == GameInput.down) { if (player.move(false, dungeon)) _onPlayerStepped(); }
      if (input == GameInput.left) player.turn(false);
      if (input == GameInput.right) player.turn(true);
      
      if (input == GameInput.buttonA) {
        Point<int> currentPos = Point(player.x, player.y);
        
        // Tenta pegar item do chão SÓ SE O BOTÃO 'A' FOR APERTADO!
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

        _interact(); // Só tenta abrir baú/porta se não pegou nada do chão
      }
      
      if (input == GameInput.buttonB) { 
        currentState = GameState.inventory; 
        inventoryCursor = 0; 
        isActionMenuOpen = false; 
        isItemActionMenuOpen = false; 
      }
      return; 
    } 
    
    // --- MODO COMBATE ---
    if (currentState == GameState.combat) {
      if (showVictoryMessage) { if (input == GameInput.buttonA) { showVictoryMessage = false; _endEncounter(); } return; }
      
      if (input == GameInput.left) leftPressed = true;
      if (input == GameInput.right) rightPressed = true;
      if (input == GameInput.down) downPressed = true;
      if (input == GameInput.buttonA) {
        if (activeMessage != null) dismissMessage();
        else _performAttack();
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
      _consumeItem(item);
    }
  }

  void _useCombatConsumable(Item item) {
    if (item.type == ItemType.consumable) {
      if (item.onUse != null) item.onUse!(item, this);
      _consumeItem(item); 
    } 
    else if (item.type == ItemType.spell) {
      if (playerCombatStats.mana >= item.manaCost) {
        playerCombatStats.mana -= item.manaCost; 
        if (item.onUse != null) item.onUse!(item, this);
      } else {
        //showMessage("Mana insuficiente para usar ${item.name}!");
        combatOverlay.addFloatingText("Mana insuficiente!", playerCombatStats.getHurtbox(size), Palette.cinzaCla);
      }
    }
  }

  void _consumeItem(Item item) {
    item.quantity--;
    if (item.quantity <= 0) {
      playerCombatStats.inventory.remove(item);
      // Ajusta o cursor caso o último item seja gasto
      if (selectedConsumableIndex >= playerCombatStats.consumables.length) selectedConsumableIndex = 0;
      if (inventoryCursor >= playerCombatStats.inventory.length) inventoryCursor = 0;
    }
  }

  void _onPlayerStepped() {
    // 1. Avança a animação das armadilhas no mapa
    dungeon.advanceSpikes();
    playerCombatStats.recoverMana();
    // 2. Verifica se o jogador pisou num espinho E se o espinho está esticado (estado 2)
    if (dungeon.getTile(player.x, player.y) == TileType.spike && dungeon.spikeState == 2) {
      playerCombatStats.hp -= 20; // Dano pesado da armadilha
      playerCombatStats.applyHitStun(0.3); // Pisca em vermelho igual no combate!
      showMessage("Você pisou em uma armadilha de espinhos!");
      if (playerCombatStats.hp <= 0) handlePlayerDeath();
    }

    dungeon.moveEnemies(Point(player.x, player.y));

    // 3. Checa colisão fatal: Inimigo encostou no Player?
    for (int i = 0; i < dungeon.roamingEnemies.length; i++) {
      if (dungeon.roamingEnemies[i].x == player.x && dungeon.roamingEnemies[i].y == player.y) {
        // Se bater, o ícone do inimigo é deletado do mapa...
        dungeon.roamingEnemies.removeAt(i); 
        // ...e a batalha começa!
        triggerEncounter(); 
        break; // Impede que o jogador lute contra 2 grupos ao mesmo tempo
      }
    }
  }

  void _interact() {
    //int dx = 0, dy = 0;
    //switch (player.facing) { case Direction.north: dy = -1; break; case Direction.east: dx = 1; break; case Direction.south: dy = 1; break; case Direction.west: dx = -1; break; }
    //int targetX = player.x + dx; int targetY = player.y + dy;
    
    //TileType targetTile = dungeon.getTile(targetX, targetY);
    TileType playerTile = dungeon.getTile(player.x, player.y);

    if (playerTile == TileType.shrine) {
        int cost = levelUpCost;
        
        if (playerCombatStats.essence >= cost) {
          // Prepara as variáveis para a tela de Level Up
          pointsToDistribute = 3;
          tempStr = 0; tempCon = 0; tempWis = 0;
          levelUpCursor = 0;
          
          currentState = GameState.levelUp; // Muda o estado do jogo!
        } else {
          showMessage("Altar Antigo: Exige $cost Essências (Você tem: ${playerCombatStats.essence.toInt()})");
        }
        return;
      }

    if (playerTile == TileType.door) {
      if (player.hasKey) {
        // Envia a mensagem, e quando ela fechar (onDismiss), avança de nível!
        showMessage("A porta se abre. Descendo para o Andar ${player.floorLevel + 1}...", onDismiss: () {
          player.floorLevel++;
          player.hasKey = false;
          player.noiseLevel = 0;
          dungeon.width += 5; 
          dungeon.height += 5;
          dungeon.generateProceduralMap(); 
          player.x = dungeon.playerSpawn.x;
          player.y = dungeon.playerSpawn.y;
          player.facing = Direction.north;
        });
      } else {
        showMessage("A porta está trancada. Encontre a chave.");
      }
    } 
    // INTERAÇÃO COM O BAÚ
    else if (playerTile == TileType.chest) {
      dungeon.grid[player.y][player.x] = TileType.floor; // O baú some ao ser aberto!
      
      int chance = Random().nextInt(100);
      
      if (chance < 25) { 
        // 1. 25% DE CHANCE: MÍMICO!
        showMessage("O baú era um MÍMICO!!", onDismiss: () { _triggerSpecificEncounter(EnemyType.mimic); }); 
      
      } else if (chance < 60) { 
        // 2. 35% DE CHANCE: ESSÊNCIAS (25 a 59)
        int loot = Random().nextInt(30) + 10; 
        showMessage("Você achou $loot Essências!", onDismiss: () { playerCombatStats.essence += loot; }); 
      
      } else {
        // 3. 40% DE CHANCE: ITEM (Dividido entre Equipamento e Consumível)
        
        // Crie uma lista com todos os equipamentos disponíveis no jogo
        // (Você pode expandir isso no ItemDatabase depois!)
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

        // Filtra a lista deixando APENAS os itens que o jogador NÃO TEM no inventário
        List<Item> unownedEquipments = allEquipments.where((equip) {
          return !playerCombatStats.inventory.any((invItem) => invItem.name == equip.name);
        }).toList();

        // 15% de chance de tentar dropar um equipamento (60 a 74)
        bool tryEquipment = chance >= 60 && chance < 75;

        // Se tirou a sorte grande E ainda existem equipamentos não coletados:
        if (tryEquipment && unownedEquipments.isNotEmpty) {
          
          unownedEquipments.shuffle(); // Embaralha os equipamentos restantes
          Item newEquipment = unownedEquipments.first;
          newEquipment.quantity = 1; // Equipamentos não acumulam, mas garantimos a quantidade 1

          showMessage("Você encontrou um item: ${newEquipment.name}!", onDismiss: () {
            receiveItem(newEquipment);
          });
          
        } else {
          // CAI AQUI SE: Tirou os 25% do consumível (75 a 99) 
          // OU tentou equipamento mas o jogador já tem todos!

          List<Item> allConsumables = [
          ItemDatabase.healthPotion,
          ItemDatabase.manaPotion,
          ItemDatabase.bomb,
          ItemDatabase.staminaPotion,
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