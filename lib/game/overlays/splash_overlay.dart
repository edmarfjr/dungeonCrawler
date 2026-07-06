import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:dungeon_crawler/game/components/core/audio_manager.dart'; // Ajuste o caminho

class SplashOverlay extends StatefulWidget {
  final DungeonCrawlerGame game;

  const SplashOverlay({super.key, required this.game});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  Timer? _autoAdvanceTimer;
  
  double _opacity = 0.0; 
  bool _isTransitioning = false; 

  @override
  void initState() {
    super.initState();
    
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    _autoAdvanceTimer = Timer(const Duration(seconds: 2), () {
      _startFadeOut(autoAdvance: true);
    });
  }

  void _startFadeOut({bool autoAdvance = false}) {
    if (_isTransitioning || !mounted) return;

    setState(() {
      _isTransitioning = true;
      _opacity = 0.0; // Inicia o Fade-Out
    });
    
    _autoAdvanceTimer?.cancel();

    if (!autoAdvance) {
      AudioManager.playSfx('sfx/confirm.wav');
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _startFadeOut(autoAdvance: false),
      
      child: Container(
        color: Palette.preto,
        width: double.infinity,
        height: double.infinity,
        
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(seconds: 1), 
          curve: Curves.easeInOut,
          onEnd: () {
            if (_opacity == 0.0 && mounted) {
              widget.game.startInput(GameInput.buttonA);
            }
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "DUNGEON CRAWLER", 
                  style: TextStyle(
                    fontFamily: 'pixelFont', 
                    color: Palette.vermelho, 
                    fontSize: 40, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 2,
                    decoration: TextDecoration.none, 
                  )
                ),
                const SizedBox(height: 80),
                const Text(
                  "BY EDMAUL POWERED BY FLAME FLUTTER",
                  style: TextStyle(
                    fontFamily: 'pixelFont',
                    color: Palette.branco,
                    fontSize: 18,
                    decoration: TextDecoration.none,
                  ),
                ),
                
                /*
                // Só exibe o "PRESSIONE QUALQUER BOTAO" se o jogo não estiver a fazer Fade-Out
                if (!_isTransitioning)
                  FadeTransition(
                    opacity: _blinkController,
                    child: const Text(
                      "PRESSIONE QUALQUER BOTAO",
                      style: TextStyle(
                        fontFamily: 'pixelFont',
                        color: Palette.branco,
                        fontSize: 18,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  )
                else 
                  // Mantém o espaço para o layout não dar "saltos" durante o Fade-Out
                  const SizedBox(height: 18), 
                  */
              ],
            ),
          ),
        ),
      ),
    );
  }
}