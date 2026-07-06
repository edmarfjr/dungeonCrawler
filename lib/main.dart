import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/core/settings_manager.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:dungeon_crawler/game/overlays/gameover_overlay.dart';
import 'package:dungeon_crawler/game/overlays/intro_overlay.dart';
import 'package:dungeon_crawler/game/overlays/main_menu_overlay.dart';
import 'package:dungeon_crawler/game/overlays/manual_overlay.dart';
import 'package:dungeon_crawler/game/overlays/pause_menu_overlay.dart';
import 'package:dungeon_crawler/game/overlays/settings_menu_overlay.dart';
import 'package:dungeon_crawler/game/overlays/splash_overlay.dart';
import 'package:dungeon_crawler/game/overlays/vitory_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  await SettingsManager.init();
  
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
              flex: 4,
              child: ClipRect(
                child: GameWidget(
                  game: _game,
                  // --- 1. MAPEAMENTO DOS MENUS ---
                  overlayBuilderMap: {
                    'Splash': (context, game) => SplashOverlay(game: game as DungeonCrawlerGame),
                    'MainMenu': (context, game) => MainMenuOverlay(game: game as DungeonCrawlerGame),
                    'Intro': (context, game) => IntroOverlay(game: game as DungeonCrawlerGame),
                    'PauseMenu': (context, game) => PauseMenuOverlay(game: game as DungeonCrawlerGame),
                    'GameOver': (context, game) => GameOverOverlay(game: game as DungeonCrawlerGame),
                    'ManualMenu': (context, game) => ManualOverlay(game: game as DungeonCrawlerGame),
                    'Vitory': (context, game) => VitoryOverlay(game: game as DungeonCrawlerGame),
                    'settings': (context, game) => SettingsMenuOverlay(game: game as DungeonCrawlerGame),
                  },
                  // Define qual menu aparece primeiro quando abre o app
                  initialActiveOverlays: const ['Splash'],
                ),
              ),
            ),
            
            // Controles estilo Game Boy (1/3 da tela)
            Expanded(
              flex: 2,
              child: Container(
                color: Palette.cinza,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // --- D-PAD REFEITO COM SUPORTE A DESLIZE ---
                    Expanded(
                      flex: 5,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Listener(
                              // Detecta quando o dedo toca, move ou sai da tela
                              onPointerDown: (event) => _handleDPadSlide(event.localPosition, constraints.biggest),
                              onPointerMove: (event) => _handleDPadSlide(event.localPosition, constraints.biggest),
                              onPointerUp: (_) => _handleDPadEnd(),
                              onPointerCancel: (_) => _handleDPadEnd(),
                              child: Stack(
                                children: [
                                  Align(alignment: Alignment.center, child: Container(width: 63, height: 110, decoration: const BoxDecoration(color: Palette.cinzaEsc, shape: BoxShape.rectangle))),
                                  Align(alignment: Alignment.center, child: Container(width: 110, height: 63, decoration: const BoxDecoration(color: Palette.cinzaEsc, shape: BoxShape.rectangle))),
                                  Align(alignment: Alignment.topCenter, child: _buildStaticArrow(Icons.arrow_upward)),
                                  Align(alignment: Alignment.bottomCenter, child: _buildStaticArrow(Icons.arrow_downward)),
                                  Align(alignment: Alignment.centerLeft, child: _buildStaticArrow(Icons.arrow_back)),
                                  Align(alignment: Alignment.centerRight, child: _buildStaticArrow(Icons.arrow_forward)),
                                ],
                              ),
                            );
                          }
                        ),
                      ),
                    ),

                    // --- BOTÃO DE PAUSE ---
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTapDown: (_) => {_game.startInput(GameInput.pause), HapticFeedback.mediumImpact() },
                            child: Container(
                              width: 50, height: 20,
                              decoration: BoxDecoration(color: Palette.cinzaEsc, borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text("PAUSE", style: TextStyle(fontFamily: 'pixelFont', color: Palette.cinzaEsc, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    // --- BOTÕES A e B ---
                    Expanded(
                      flex: 4,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          children: [
                            Align(alignment: Alignment.topRight, child: _buildActionButton("A", GameInput.buttonA, Palette.vermelhoCla)),
                            Align(alignment: Alignment.bottomLeft, child: _buildActionButton("B", GameInput.buttonB, Palette.vermelhoCla)),
                          ],
                        ),
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

  // --- NOVA LÓGICA DE DESLIZE DO D-PAD ---
  GameInput? _currentDPadInput;

  void _handleDPadSlide(Offset localPosition, Size dpadSize) {
    // Encontra o centro do D-Pad
    double dx = localPosition.dx - (dpadSize.width / 2);
    double dy = localPosition.dy - (dpadSize.height / 2);

    GameInput? newInput;

    // Cria uma "Zona Morta" no meio para o jogador poder descansar o dedo sem andar
    if (dx.abs() < 15 && dy.abs() < 15) {
      newInput = null; 
    } 
    // Divide o D-pad em 4 triângulos invisíveis formando um "X"
    else if (dx.abs() > dy.abs()) {
      newInput = dx > 0 ? GameInput.right : GameInput.left;
    } else {
      newInput = dy > 0 ? GameInput.down : GameInput.up;
    }

    // Só avisa o jogo se a direção mudar (ex: escorregou do Cima pro Lado)
    if (newInput != _currentDPadInput) {
      if (_currentDPadInput != null) _game.stopInput(_currentDPadInput!);
      _currentDPadInput = newInput;
      if (_currentDPadInput != null){
        HapticFeedback.lightImpact();
        _game.startInput(_currentDPadInput!);
        _game.onTouchStart(_currentDPadInput!);
      } 
    }
  }

  void _handleDPadEnd() {
    if (_currentDPadInput != null) {
      _game.stopInput(_currentDPadInput!);
      _currentDPadInput = null;
    }
  }

  // Desenha os botões do D-Pad apenas como visual (quem controla a ação agora é o Listener invisível em cima deles)
  Widget _buildStaticArrow(IconData icon) {
    return Container(
      width: 80, height: 80,
      decoration: const BoxDecoration(color: Palette.cinzaEsc, shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(8))),
      child: Icon(icon, color: Palette.preto, size: 30),
    );
  }

  // Os botões A e B continuam iguais, pois geralmente você bate o dedo neles
  Widget _buildActionButton(String label, GameInput input, Color color) {
    // 1. Trocamos GestureDetector por Listener
    return Listener(
      // 2. Garante que o botão deteta o toque mesmo se o dedo deslizar um pouco
      behavior: HitTestBehavior.opaque, 
      
      // 3. onPointerDown é INSTANTÂNEO (ocorre no milissegundo em que o dedo toca no vidro)
      onPointerDown: (_) {
        HapticFeedback.mediumImpact(); 
        _game.startInput(input);
      },
      
      // 4. onPointerUp é quando o dedo levanta
      onPointerUp: (_) => _game.stopInput(input),
      
      // 5. onPointerCancel é quando o sistema interrompe o toque (ex: abrir uma notificação)
      onPointerCancel: (_) => _game.stopInput(input),
      
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Palette.cinzaEsc, blurRadius: 4, offset: Offset(2, 2))],
        ),
        child: Center(
          child: Text(
            label, 
            style: const TextStyle(
              fontFamily: 'pixelFont', 
              color: Palette.vermelhoEsc, 
              fontWeight: FontWeight.bold, 
              fontSize: 20
            )
          ),
        ),
      ),
    );
  }
}