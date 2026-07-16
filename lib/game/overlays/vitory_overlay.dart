import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
import 'package:dungeon_crawler/game/components/core/audio_manager.dart';

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
  // === DEFINA AQUI AS CENAS DO SEU FINAL ===
  final List<CutsceneFrame> framesRuim = [
    CutsceneFrame('assets/images/tilesets/boss.png', "Com a derrocata do Antigo, você se aproxima da saída, imaginando o que lhe aguarda"),
    CutsceneFrame('assets/images/tilesets/chest.png', "A luz começa a entrar em seus olhos, revelando uma paisagem aterradora."),
    CutsceneFrame('assets/images/tilesets/font.png', '"ONDE ESTOU?"\n\nVoce sobreviveu a masmorra.\nMas sua aventura está apenas começando...'),
  ];

  final List<CutsceneFrame> framesBom = [
    CutsceneFrame('assets/images/tilesets/boss.png', "Com a derrocata do Antigo, você se aproxima da saída, imaginando o que lhe aguarda"),
    CutsceneFrame('assets/images/tilesets/chest.png', "A luz começa a entrar em seus olhos, revelando uma paisagem conhecida."),
    CutsceneFrame('assets/images/tilesets/font.png', '"ESTOU DE VOLTA!"\n\nVoce sobreviveu a masmorra.\nO mundo finalmente está salvo...'),
  ];

  List<CutsceneFrame> frames =[];

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
    }else{
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
    String fullText = frames[currentFrame].text;

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
        // Pular a digitação (mostra tudo de uma vez)
        isTyping = false;
        typingTimer?.cancel();
        String fullText = frames[currentFrame].text;
        charIndex = fullText.length;
        visibleText = fullText;
      } else {
        // Avançar para a próxima cena
        if (currentFrame < frames.length - 1) {
          currentFrame++;
          _startTyping();
        } else {
          // Fim da cutscene -> Fade out para o menu principal
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
              // Quando o fade out terminar, reseta e vai para o menu principal
              widget.game.quitToMainMenu();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // A IMAGEM DA CENA ATUAL (com errorBuilder para evitar crash)
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
                const SizedBox(height: 20),
                // A CAIXA DE TEXTO ESTILO RPG
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Palette.preto,
                    ),
                    child: Text(
                      visibleText,
                      style: const TextStyle(
                        fontFamily: 'pixelFont',
                        color: Palette.branco,
                        fontSize: 16,
                        height: 1.5,
                        decoration: TextDecoration.none,
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