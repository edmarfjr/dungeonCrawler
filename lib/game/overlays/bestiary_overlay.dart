import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:a_blade_in_the_abyss/game/components/core/i18n.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/components/core/audio_manager.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
import 'package:a_blade_in_the_abyss/game/components/entities/enemy.dart'; 

class BestiaryOverlay extends StatefulWidget {
  final DungeonCrawlerGame game;

  const BestiaryOverlay({Key? key, required this.game}) : super(key: key);

  @override
  State<BestiaryOverlay> createState() => _BestiaryOverlayState();
}

class _BestiaryOverlayState extends State<BestiaryOverlay> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.game.bestiaryCursor.addListener(_scrollToCursor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _scrollToCursor();
    });
  }

  @override
  void dispose() {
    widget.game.bestiaryCursor.removeListener(_scrollToCursor);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCursor() {
    double itemH = widget.game.isDesktopLayout ? 50.0 : 35.0;
    double offset = widget.game.bestiaryCursor.value * itemH; // USANDO .value
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        (offset - 100).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyX ||
        event.logicalKey == LogicalKeyboardKey.gameButtonB ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      widget.game.closeBestiary();
    } 
    else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.game.bestiaryCursor.value--;
      if (widget.game.bestiaryCursor.value < 0) {
        widget.game.bestiaryCursor.value = EnemyType.values.length - 1;
      }
      AudioManager.playSfx('sfx/hover.wav');
    } 
    else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.game.bestiaryCursor.value++;
      if (widget.game.bestiaryCursor.value >= EnemyType.values.length) {
        widget.game.bestiaryCursor.value = 0;
      }
      AudioManager.playSfx('sfx/hover.wav');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = widget.game.isDesktopLayout;
    double titleFontSize = isDesktop ? 44.0 : 22.0;
    double listFontSize = isDesktop ? 26.0 : 14.0;
    double itemHeight = isDesktop ? 50.0 : 35.0;
    double paddingAll = isDesktop ? 40.0 : 20.0;

    return Align(
      alignment: Alignment.center,
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          width: double.infinity,
          height: widget.game.size.y,
          color: Palette.preto,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.all(paddingAll),
              child: ValueListenableBuilder<int>(
                valueListenable: widget.game.bestiaryCursor,
                builder: (context, cursorIndex, child) {
                  return Column(
                    children: [
                      Text(
                        I18n.t('bestiario').toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'pixelFont',
                          color: Palette.amarelo,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 40 : 20),
                      
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ESQUERDA: LISTA
                            Expanded(
                              flex: 45,
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: EnemyType.values.length,
                                itemBuilder: (context, index) {
                                  EnemyType type = EnemyType.values[index];
                                  int kills = widget.game.bestiaryKills[type] ?? 0;
                                  int reqKills = widget.game.getEnemyReqKills(type);
                                  bool unlocked = kills >= reqKills;
                                  bool selected = (index == cursorIndex);

                                  Color textColor = selected ? Palette.amarelo : (unlocked ? Palette.branco : Palette.cinzaEsc);
                                  String nameStr = unlocked ? I18n.t(type.name).toUpperCase() : "???";
                                  String prefix = selected ? "> " : "  ";

                                  return Container(
                                    height: itemHeight,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "$prefix$nameStr",
                                      style: TextStyle(
                                        fontFamily: 'pixelFont',
                                        color: textColor,
                                        fontSize: listFontSize,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            // LINHA DIVISÓRIA
                            Container(
                              width: 4,
                              color: Palette.cinzaEsc,
                              margin: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 10),
                            ),
                            
                            // DIREITA: DETALHES
                            Expanded(
                              flex: 55,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: _buildRightPanel(titleFontSize, listFontSize, cursorIndex),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // RODAPÉ (Botão Voltar)
                      SizedBox(height: isDesktop ? 20 : 10),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          ),
                          onPressed: () => widget.game.closeBestiary(),
                          child: Text(
                            I18n.t('b_voltar'),
                            style: TextStyle(
                              fontFamily: 'pixelFont',
                              color: Palette.amarelo,
                              fontSize: listFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(double titleFontSize, double listFontSize, int cursorIndex) {
    EnemyType selectedType = EnemyType.values[cursorIndex];
    int kills = widget.game.bestiaryKills[selectedType] ?? 0;
    int reqKills = widget.game.getEnemyReqKills(selectedType);
    bool unlocked = kills >= reqKills;

    if (!unlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.t('desconhecido').toUpperCase(),
            style: TextStyle(fontFamily: 'pixelFont', color: Palette.vermelho, fontSize: titleFontSize),
          ),
          const SizedBox(height: 20),
          Text(
            I18n.t('derrote_mais').replaceAll('{kills}', (reqKills - kills).toString()),
            style: TextStyle(fontFamily: 'pixelFont', color: Palette.cinzaCla, fontSize: listFontSize),
          ),
        ],
      );
    } else {
      var info = widget.game.getEnemyInfo(selectedType);
      ui.Image? spr = widget.game.enemySheets[selectedType];
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            I18n.t(selectedType.name).toUpperCase(),
            style: TextStyle(fontFamily: 'pixelFont', color: Palette.verdeCla, fontSize: titleFontSize),
          ),
          const SizedBox(height: 20),
          
          if (spr != null) 
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(painter: EnemySpritePainter(spr)),
            ),
            
          const SizedBox(height: 20),
          Text(
            "Abates: $kills\nHP: ${info['hp']}\nDMG: ${info['dmg']}\n\n${info['desc']}",
            style: TextStyle(fontFamily: 'pixelFont', color: Palette.branco, fontSize: listFontSize),
          ),
        ],
      );
    }
  }
}

class EnemySpritePainter extends CustomPainter {
  final ui.Image image;

  EnemySpritePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    // Pega exatamente a métrica original do Flame: image.height / 2
    double frameSize = image.height.toDouble() / 2;
    Rect src = Rect.fromLTWH(0, 0, frameSize, frameSize);
    Rect dst = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Desenha sem anti-aliasing para manter o aspecto Pixel Art nítido
    canvas.drawImageRect(image, src, dst, Paint()..isAntiAlias = false..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}