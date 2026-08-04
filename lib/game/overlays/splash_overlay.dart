import 'dart:async';
import 'package:flutter/material.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
//import 'package:a_blade_in_the_abyss/game/components/core/audio_manager.dart';

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

    _autoAdvanceTimer = Timer(const Duration(seconds: 5), () {
      _startFadeOut(autoAdvance: true);
    });
  }

  void _startFadeOut({bool autoAdvance = false}) {
    if (_isTransitioning || !mounted) return;

    setState(() {
      _isTransitioning = true;
      _opacity = 0.0; 
    });
    
    _autoAdvanceTimer?.cancel();

    if (!autoAdvance) {
      //AudioManager.playSfx('sfx/confirm.wav');
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
    final bool isDesktop = widget.game.isDesktopLayout;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double fontSize = isDesktop 
                  ? (constraints.maxWidth * 0.015).clamp(12.0, 24.0) 
                  : (constraints.maxWidth * 0.035).clamp(10.0, 16.0); 

              final double bottomPadding = isDesktop 
                  ? (constraints.maxHeight * 0.05).clamp(20.0, 50.0)
                  : (constraints.maxHeight * 0.15).clamp(20.0, 40.0);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // 1. A IMAGEM DE FUNDO
                  Image.asset(
                    'assets/images/splash.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: isDesktop ? BoxFit.contain : BoxFit.cover,
                  ),
                  
                  Positioned(
                    bottom: bottomPadding,
                    child: Text(
                      "made by EDMAUL", 
                      style: TextStyle(
                        fontFamily: 'pixelFont', 
                        color: Palette.branco, 
                        fontSize: fontSize, 
                        fontWeight: FontWeight.bold, 
                        decoration: TextDecoration.none, 
                      )
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}