import 'dart:async';
import 'package:a_blade_in_the_abyss/game/components/core/i18n.dart';
import 'package:flutter/material.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
import 'package:a_blade_in_the_abyss/game/components/core/audio_manager.dart';

class IntroOverlay extends StatefulWidget {
  final DungeonCrawlerGame game;

  const IntroOverlay({super.key, required this.game});

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> {
  final String fullText = I18n.t('intro_txt');
  
  String visibleText = "";
  int charIndex = 0;
  Timer? typingTimer;
  bool isTyping = true;
  
  double _opacity = 0.0;
  bool _isFadingOut = false;

  @override
  void initState() {
    super.initState();
    
    widget.game.introInputNotifier.addListener(_handleInput);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && isTyping) _startTyping();
    });
  }

  void _startTyping() {
    typingTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (charIndex < fullText.length) {
          charIndex++;
          visibleText = fullText.substring(0, charIndex);
        } else {
          isTyping = false;
          timer.cancel();
        }
      });
    });
  }

  void _handleInput() {
    if (_isFadingOut || !mounted) return;

    AudioManager.playSfx('sfx/hover.wav');

    setState(() {
      if (isTyping) {
        isTyping = false;
        typingTimer?.cancel();
        charIndex = fullText.length;
        visibleText = fullText;
      } else {
        _isFadingOut = true;
        _opacity = 0.0;
      }
    });
  }

  @override
  void dispose() {
    widget.game.introInputNotifier.removeListener(_handleInput);
    typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleInput,
      child: Container(
        color: Palette.preto,
        width: double.infinity,
        height: double.infinity,
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 800),
          onEnd: () {
            if (_opacity == 0.0 && mounted) {
              widget.game.finishIntro();
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Ajusta o tamanho da fonte para não ficar minúscula no PC
              final double fontSize = widget.game.isDesktopLayout ? 18.0 : 13.0;
              
              return Center(
                // O ConstrainedBox garante que no Widescreen o texto não vai virar uma linha reta enorme,
                // mantendo o aspecto de "caixa de texto de RPG" elegante no centro.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        visibleText,
                        style: TextStyle(
                          fontFamily: 'pixelFont',
                          color: Palette.branco,
                          fontSize: fontSize,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}