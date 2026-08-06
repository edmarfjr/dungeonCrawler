import 'package:a_blade_in_the_abyss/game/components/core/game_button.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/components/core/settings_manager.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
import 'package:a_blade_in_the_abyss/game/overlays/bestiary_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/crt_overlay_widget.dart';
import 'package:a_blade_in_the_abyss/game/overlays/gameover_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/intro_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/main_menu_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/manual_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/pause_menu_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/settings_menu_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/splash_overlay.dart';
import 'package:a_blade_in_the_abyss/game/overlays/vitory_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; 
import 'dart:io';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  await Flame.device.fullScreen();
  
  // Trava orientação se não for Desktop
  if (!isDesktopPlatform) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      title: 'A Blade in the Abyss', // O nome do seu jogo
      fullScreen: true,              // Força a tela cheia clássica sem bordas
      center: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await SettingsManager.init();
  runApp(const DungeonApp());
}

bool get isDesktopPlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
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
  late final GameWidget _gameWidget; 

  @override
  void initState() {
    super.initState();
    _game = DungeonCrawlerGame();
    
    _gameWidget = GameWidget(
      game: _game,
      overlayBuilderMap: {
        'Splash': (context, game) => SplashOverlay(game: game as DungeonCrawlerGame),
        'MainMenu': (context, game) => MainMenuOverlay(game: game as DungeonCrawlerGame),
        'Intro': (context, game) => IntroOverlay(game: game as DungeonCrawlerGame),
        'PauseMenu': (context, game) => PauseMenuOverlay(game: game as DungeonCrawlerGame),
        'GameOver': (context, game) => GameOverOverlay(game: game as DungeonCrawlerGame),
        'ManualMenu': (context, game) => ManualOverlay(game: game as DungeonCrawlerGame),
        'Victory': (context, game) => VictoryCutsceneOverlay(game: game as DungeonCrawlerGame),
        'settings': (context, game) => SettingsMenuOverlay(game: game as DungeonCrawlerGame),
        'BestiaryMenu': (context, game) => BestiaryOverlay(game: game as DungeonCrawlerGame),
      },
      initialActiveOverlays: const ['Splash'],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width > 700;
    bool showDesktopUI = isDesktopPlatform && isWideScreen;
    
    // Avisamos o Flame de que ele deve assumir o desenho da HUD Lateral!
    _game.isDesktopLayout = showDesktopUI;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: showDesktopUI ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    // No PC, o jogo ocupa a tela inteira. O Flame fará o trabalho de desenhar as bordas!
    return ClipRect(
      child: CrtOverlayWidget(
        crtFilterEnabled: _game.crtFilterEnabled,
        child: _gameWidget, 
      ),
    );
  }

  // ============================================================================
  // === LAYOUT MOBILE (COM D-PAD E BOTÕES DE GAMEBOY) ===
  // ============================================================================
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: ClipRect(
            child: CrtOverlayWidget(
              crtFilterEnabled: _game.crtFilterEnabled,
              child: _gameWidget, 
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            color: Palette.cinza,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  flex: 5,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Listener(
                          onPointerDown: (event) => _handleDPadSlide(event.localPosition, constraints.biggest),
                          onPointerMove: (event) => _handleDPadSlide(event.localPosition, constraints.biggest),
                          onPointerUp: (_) => _handleDPadEnd(),
                          onPointerCancel: (_) => _handleDPadEnd(),
                          child: Stack(
                            children: [
                              Align(alignment: Alignment.center, child: Container(width: 63, height: 110, decoration: const BoxDecoration(color: Palette.cinzaEsc, shape: BoxShape.rectangle))),
                              Align(alignment: Alignment.center, child: Container(width: 110, height: 63, decoration: const BoxDecoration(color: Palette.cinzaEsc, shape: BoxShape.rectangle))),
                              Align(alignment: Alignment.topCenter, child: _buildStaticArrow(Icons.arrow_upward, GameInput.up)),
                              Align(alignment: Alignment.bottomCenter, child: _buildStaticArrow(Icons.arrow_downward, GameInput.down)),
                              Align(alignment: Alignment.centerLeft, child: _buildStaticArrow(Icons.arrow_back, GameInput.left)),
                              Align(alignment: Alignment.centerRight, child: _buildStaticArrow(Icons.arrow_forward, GameInput.right)),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      GameButton(
                        onDown: () {
                          HapticFeedback.mediumImpact();
                          _game.startInput(GameInput.pause);
                        },
                        onUp: () => _game.stopInput(GameInput.pause),
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
                Expanded(
                  flex: 4,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Align(alignment: Alignment.topRight, child: _buildActionButton("A", GameInput.buttonA, Palette.vermelho)),
                        Align(alignment: Alignment.bottomLeft, child: _buildActionButton("B", GameInput.buttonB, Palette.vermelho)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Lógica de Input Mobile ---
  GameInput? _currentDPadInput;

  void _handleDPadSlide(Offset localPosition, Size dpadSize) {
    double dx = localPosition.dx - (dpadSize.width / 2);
    double dy = localPosition.dy - (dpadSize.height / 2);
    GameInput? newInput;

    if (dx.abs() < 15 && dy.abs() < 15) {
      newInput = null; 
    } 
    else if (dx.abs() > dy.abs()) {
      newInput = dx > 0 ? GameInput.right : GameInput.left;
    } else {
      newInput = dy > 0 ? GameInput.down : GameInput.up;
    }

    if (newInput != _currentDPadInput) {
      setState(() {
        if (_currentDPadInput != null) _game.stopInput(_currentDPadInput!);
        _currentDPadInput = newInput;
      });
      if (_currentDPadInput != null){
        HapticFeedback.lightImpact();
        _game.startInput(_currentDPadInput!);
        _game.onTouchStart(_currentDPadInput!);
      } 
    }
  }

  void _handleDPadEnd() {
    if (_currentDPadInput != null) {
      setState(() {
        _game.stopInput(_currentDPadInput!);
        _currentDPadInput = null;
      });
    }
  }

  Widget _buildStaticArrow(IconData icon, GameInput direction) {
    bool isPressed = _currentDPadInput == direction;
    return AnimatedScale(
      scale: isPressed ? 0.85 : 1.0, 
      duration: const Duration(milliseconds: 50),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: isPressed ? 0.6 : 1.0, 
        duration: const Duration(milliseconds: 50),
        child: Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: Palette.cinzaEsc, shape: BoxShape.rectangle, borderRadius: BorderRadius.all(Radius.circular(8))),
          child: Icon(icon, color: Palette.preto, size: 30),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, GameInput input, Color color) {
    return GameButton(
      onDown: () {
        HapticFeedback.mediumImpact(); 
        _game.startInput(input);
      },
      onUp: () => _game.stopInput(input),
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