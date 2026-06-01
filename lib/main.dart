import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:dungeon_crawler/game/overlays/gameover_overlay.dart';
import 'package:dungeon_crawler/game/overlays/main_menu_overlay.dart';
import 'package:dungeon_crawler/game/overlays/pause_menu_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';

void main() {
  runApp(const DungeonApp());
}

class DungeonApp extends StatelessWidget {
  const DungeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DungeonCrawlerGame _game;

  @override
  void initState() {
    super.initState();
    _game = DungeonCrawlerGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Tela do Jogo (2/3 da tela)
            Expanded(
              flex: 2,
              child: ClipRect(
                child: GameWidget(
                  game: _game,
                  // --- 1. MAPEAMENTO DOS MENUS ---
                  overlayBuilderMap: {
                    'MainMenu': (context, game) => MainMenuOverlay(game: game as DungeonCrawlerGame),
                    'PauseMenu': (context, game) => PauseMenuOverlay(game: game as DungeonCrawlerGame),
                    'GameOver': (context, game) => GameOverOverlay(game: game as DungeonCrawlerGame),
                  },
                  // Define qual menu aparece primeiro quando abre o app
                  initialActiveOverlays: const ['MainMenu'],
                ),
              ),
            ),
            
            // Controles estilo Game Boy (1/3 da tela)
            Expanded(
              flex: 1,
              child: Container(
                color: Palette.cinza,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // D-PAD
                    SizedBox(
                      width: 220, height: 220,
                      child: Stack(
                        children: [
                          Align(alignment: Alignment.topCenter, child: _buildHoldButton(Icons.arrow_upward, GameInput.up)),
                          Align(alignment: Alignment.bottomCenter, child: _buildHoldButton(Icons.arrow_downward, GameInput.down)),
                          Align(alignment: Alignment.centerLeft, child: _buildHoldButton(Icons.arrow_back, GameInput.left)),
                          Align(alignment: Alignment.centerRight, child: _buildHoldButton(Icons.arrow_forward, GameInput.right)),
                        ],
                      ),
                    ),

                    // --- 2. BOTÃO DE PAUSE NO MEIO (Start/Select) ---
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTapDown: (_) => _game.startInput(GameInput.pause),
                          child: Container(
                            width: 60, height: 25,
                            decoration: BoxDecoration(color: Palette.cinzaEsc, borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text("PAUSE", style: TextStyle(color: Palette.cinzaEsc, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                      ],
                    ),

                    // BOTÕES A e B
                    SizedBox(
                      width: 180, height: 180,
                      child: Stack(
                        children: [
                          Align(alignment: Alignment.topRight, child: _buildActionButton("A", GameInput.buttonA, Palette.cinzaEsc)),
                          Align(alignment: Alignment.centerLeft, child: _buildActionButton("B", GameInput.buttonB, Palette.cinzaEsc)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  // Novo widget para botões direcionais que suportam segurar
  Widget _buildHoldButton(IconData icon, GameInput input) {
    return GestureDetector(
      onTapDown: (_) => _game.startInput(input), // Dedo pressionou
      onTapUp: (_) => _game.stopInput(input),    // Dedo soltou
      onTapCancel: () => _game.stopInput(input), // Dedo arrastou pra fora
      child: Container(
        width: 75, 
        height: 75,
        decoration: BoxDecoration(
          color: Palette.cinzaEsc, 
          shape: BoxShape.rectangle
        ),
        child: Icon(icon, color: Palette.branco,size: 30,),
      ),
    );
  }

  // Novo widget para botões de ação que suportam segurar
  Widget _buildActionButton(String label, GameInput input, Color color) {
    return GestureDetector(
      onTapDown: (_) => _game.startInput(input),
      onTapUp: (_) => _game.stopInput(input),
      onTapCancel: () => _game.stopInput(input),
      child: Container(
        width: 75, 
        height: 75,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Palette.cinzaEsc, blurRadius: 4, offset: Offset(2, 2))],
        ),
        child: Center(
          child: Text(label, style: const TextStyle(color: Palette.branco, fontWeight: FontWeight.bold, fontSize: 20)),
        ),
      ),
    );
  }
}