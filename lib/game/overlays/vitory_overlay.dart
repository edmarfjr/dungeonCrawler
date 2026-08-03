import 'dart:async';
import 'package:a_blade_in_the_abyss/game/components/core/i18n.dart';
import 'package:flutter/material.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
import 'package:a_blade_in_the_abyss/game/components/core/audio_manager.dart';

class CutsceneFrame {
  final String imagePath;
  final String text;
  CutsceneFrame(this.imagePath, this.text);
}

class VictoryCutsceneOverlay extends StatefulWidget {
  final DungeonCrawlerGame game;

  const VictoryCutsceneOverlay({super.key, required this.game});

  @override
  State<VictoryCutsceneOverlay> createState() => _VictoryCutsceneOverlayState();
}

class _VictoryCutsceneOverlayState extends State<VictoryCutsceneOverlay> {
  final List<CutsceneFrame> framesRuim = [
    CutsceneFrame('assets/images/tilesets/tunel.png', "finalRuim1"),
    CutsceneFrame('assets/images/tilesets/paisagemAlien.png', "finalRuim2"),
    CutsceneFrame('assets/images/tilesets/retratoAssustada.png', 'finalRuim3'),
  ];

  final List<CutsceneFrame> framesBom = [
    CutsceneFrame('assets/images/tilesets/tunel.png', "finalBom1"),
    CutsceneFrame('assets/images/tilesets/paisagem.png', "finalBom2"),
    CutsceneFrame('assets/images/tilesets/retratoFeliz.png', 'finalBom3'),
  ];

  List<CutsceneFrame> frames = [];

  int currentFrame = 0;
  String visibleText = "";
  int charIndex = 0;
  Timer? typingTimer;
  bool isTyping = true;

  double _opacity = 0.0;
  bool _isFadingOut = false;

  @override
  void initState() {
    super.initState();
    widget.game.victoryInputNotifier.addListener(_handleInput);
    AudioManager.playBgm('music/main-menu.ogg'); 
    
    if(widget.game.finalBom){
      frames = framesBom;
    } else {
      frames = framesRuim;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _startTyping();
    });
  }

  void _startTyping() {
    isTyping = true;
    visibleText = "";
    charIndex = 0;
    String fullText = I18n.t(frames[currentFrame].text);

    typingTimer?.cancel();
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
        String fullText = I18n.t(frames[currentFrame].text); 
        charIndex = fullText.length;
        visibleText = fullText;
      } else {
        if (currentFrame < frames.length - 1) {
          currentFrame++;
          _startTyping();
        } else {
          _isFadingOut = true;
          _opacity = 0.0;
        }
      }
    });
  }

  @override
  void dispose() {
    widget.game.victoryInputNotifier.removeListener(_handleInput);
    typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = widget.game.isDesktopLayout;
    
    double fontSize = isDesktop ? 26.0 : 15.0;
    double paddingHorizontal = isDesktop ? widget.game.size.x * 0.15 : 20.0;
    double paddingVertical = isDesktop ? 40.0 : 20.0;
    
    double borderWidth = isDesktop ? 8.0 : 4.0;

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
              widget.game.apagaSave();
              widget.game.quitToMainMenu();
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: paddingHorizontal, vertical: paddingVertical),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Image.asset(
                    frames[currentFrame].imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Palette.cinzaEsc,
                      child: const Center(child: Icon(Icons.image, color: Palette.cinzaCla, size: 50)),
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 30 : 15),
                
                Expanded(
                  flex: isDesktop ? 1 : 2, 
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                    decoration: BoxDecoration(
                      color: Palette.preto,
                      border: Border.all(color: Palette.marromCla, width: borderWidth),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        visibleText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'pixelFont',
                          color: Palette.branco,
                          fontSize: fontSize,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}