import 'package:a_blade_in_the_abyss/game/components/core/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart'; 
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';

class ManualOverlay extends StatefulWidget {
  final DungeonCrawlerGame game;

  const ManualOverlay({Key? key, required this.game}) : super(key: key);

  @override
  State<ManualOverlay> createState() => _ManualOverlayState();
}

class _ManualOverlayState extends State<ManualOverlay> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Vincula o controlador do Flutter diretamente ao motor do Flame!
    widget.game.manualScrollController = _scrollController;
    
    // Força o foco no overlay para capturar o teclado imediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // Desvincula para evitar vazamento de memória (Memory Leak)
    widget.game.manualScrollController = null;
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // VERIFICAÇÃO DE PLATAFORMA: Define os tamanhos com base no layout
    bool isDesktop = widget.game.isDesktopLayout;
    
    double titleFontSize = isDesktop ? 40.0 : 20.0;
    double bodyFontSize = isDesktop ? 22.0 : 13.0;
    double footerFontSize = isDesktop ? 20.0 : 13.0;
    double paddingHorizontal = isDesktop ? 60.0 : 20.0;
    double paddingVertical = isDesktop ? 40.0 : 25.0;

    return Align(
      alignment: Alignment.topCenter,
      child: KeyboardListener(
        focusNode: _focusNode,
        // BLINDA O TECLADO: Se o foco estiver no Flutter, responde aos comandos por aqui!
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.keyX || 
                event.logicalKey == LogicalKeyboardKey.escape) {
              widget.game.closeManual();
            }
          }
        },
        child: Container(
          width: double.infinity,
          height: widget.game.size.y,
          color: Palette.preto,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.fromLTRB(paddingHorizontal, paddingVertical, paddingHorizontal, 10),
              child: Column(
                children: [
                  Text(
                    "MANUAL DE INSTRUÇÕES",
                    style: TextStyle(
                      fontFamily: 'pixelFont',
                      color: Palette.amarelo,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 24 : 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Palette.branco, width: isDesktop ? 4 : 2),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      padding: EdgeInsets.all(isDesktop ? 24 : 12),
                      child: SingleChildScrollView(
                        controller: _scrollController, // Vinculado!
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          _getManualContent(),
                          style: TextStyle(
                            fontFamily: 'pixelFont',
                            color: Palette.branco,
                            fontSize: bodyFontSize,
                            height: 1.4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isDesktop ? 20 : 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "[▲▼] Controles ou Arrastar",
                        style: TextStyle(
                          fontFamily: 'pixelFont',
                          color: Palette.branco,
                          fontSize: footerFontSize,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        ),
                        onPressed: () {
                          widget.game.closeManual();
                        },
                        child: Text(
                          I18n.t('b_voltar'),
                          style: TextStyle(
                            fontFamily: 'pixelFont',
                            color: Palette.amarelo,
                            fontSize: footerFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getManualContent() {
    return "${I18n.t('man_prologue_title')}\n"
           "${I18n.t('man_prologue_text')}\n\n"
           "${I18n.t('man_explo_title')}\n"
           "${I18n.t('man_explo_text')}\n\n"
           "${I18n.t('man_combat_title')}\n"
           "${I18n.t('man_combat_text')}\n\n"
           "${I18n.t('man_attrib_title')}\n"
           "${I18n.t('man_attrib_text')}\n\n";
  }
}