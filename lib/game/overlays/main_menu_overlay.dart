import 'package:a_blade_in_the_abyss/game/components/core/i18n.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/dungeon_game.dart';
import 'package:flutter/material.dart';

class MainMenuOverlay extends StatefulWidget {
  final DungeonCrawlerGame game;
  const MainMenuOverlay({super.key, required this.game});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  // Uma única animação para o bloco completo
  late Animation<Offset> _blockOffsetAnimation;

  @override
  void initState() {
    super.initState();

    widget.game.isMainMenuAnimating = true;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _blockOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0), 
      end: Offset.zero,            
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear, 
      ),
    );

    _animationController.forward().then((_) {
      if (mounted) {
        widget.game.isMainMenuAnimating = false;
      }
    });
  }

  @override
  void dispose() {
    widget.game.isMainMenuAnimating = false;
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = widget.game.isDesktopLayout;

    return Container(
      color: Palette.preto,
      // O LayoutBuilder nos dá as restrições reais da área do jogo (ex: 2/3 da tela no mobile)
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth;
          final double availableHeight = constraints.maxHeight;

          // Largura da imagem proporcional e com limites para não estourar
          final double imageWidth = isDesktop 
              ? (availableWidth * 0.40).clamp(200.0, 600.0) 
              : (availableWidth * 0.70).clamp(150.0, 400.0);

          // Tamanho de fontes proporcionais ao espaço disponível
          final double safeTitleSize = (availableWidth * 0.05).clamp(20.0, 36.0);
          final double safeOptionSize = (availableWidth * 0.04).clamp(14.0, 24.0);

          // Espaçamento dinâmico baseado na altura disponível
          final double spacing = (availableHeight * 0.03).clamp(10.0, 30.0);

          return Center(
            // O SingleChildScrollView garante que NUNCA haverá erro de Overflow (faixa amarela/preta)
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ValueListenableBuilder<int>(
                valueListenable: widget.game.mainMenuCursor,
                builder: (context, cursorIndex, child) {
                  return SlideTransition(
                    position: _blockOffsetAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Image.asset(
                            'assets/images/title.png', 
                            width: imageWidth, 
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                "A BLADE IN THE ABYSS", 
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'pixelFont', 
                                  color: Palette.branco, 
                                  fontSize: safeTitleSize, 
                                  fontWeight: FontWeight.bold, 
                                  letterSpacing: 2,
                                  decoration: TextDecoration.none, 
                                ),
                              );
                            },
                          ),
                        
                        SizedBox(height: spacing * 1.5),

                        if (widget.game.hasSavedGame) ...[
                          _buildMenuOption(
                            title: I18n.t('menu_continue'),
                            index: 0,
                            currentIndex: cursorIndex,
                            isDesktop: isDesktop,
                            fontSize: safeOptionSize,
                          ),
                          SizedBox(height: spacing),
                          _buildMenuOption(
                            title: I18n.t('menu_new'),
                            index: 1,
                            currentIndex: cursorIndex,
                            isDesktop: isDesktop,
                            fontSize: safeOptionSize,
                          ),
                          SizedBox(height: spacing),
                          _buildMenuOption(
                            title: I18n.t('menu_settings'),
                            index: 2,
                            currentIndex: cursorIndex,
                            isDesktop: isDesktop,
                            fontSize: safeOptionSize,
                          ),
                          SizedBox(height: spacing),
                          _buildMenuOption(
                            title: I18n.t('menu_manual'),
                            index: 3,
                            currentIndex: cursorIndex,
                            isDesktop: isDesktop,
                            fontSize: safeOptionSize,
                          ),
                        ] else ...[
                          _buildMenuOption(
                            title: I18n.t('menu_new'),
                            index: 0,
                            currentIndex: cursorIndex,
                            isDesktop: isDesktop,
                            fontSize: safeOptionSize,
                          ),
                          SizedBox(height: spacing),
                          _buildMenuOption(
                            title: I18n.t('menu_settings'),
                            index: 1,
                            currentIndex: cursorIndex,
                            isDesktop: isDesktop,
                            fontSize: safeOptionSize,
                          ),
                          SizedBox(height: spacing),
                          _buildMenuOption(
                            title: I18n.t('menu_manual'),
                            index: 2,
                            currentIndex: cursorIndex,
                            isDesktop: isDesktop,
                            fontSize: safeOptionSize,
                          ),
                        ],
                        
                        // Padding final para não ficar colado embaixo se precisar rolar a tela
                        SizedBox(height: spacing),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildMenuOption({
    required String title, 
    required int index, 
    required int currentIndex, 
    required bool isDesktop,
    required double fontSize,
  }) {
    bool isSelected = (index == currentIndex);

    return MouseRegion(
      onEnter: (_) {
        if (!widget.game.isMainMenuAnimating && isDesktop) {
          widget.game.mainMenuCursor.value = index;
        }
      },
      child: GestureDetector(
        onTap: () {
          if (widget.game.isMainMenuAnimating) return;
          widget.game.mainMenuCursor.value = index;
          widget.game.startInput(GameInput.buttonA);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min, // Garante que a área de clique seja apenas o tamanho do texto
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSelected ? "> " : "  ",
              style: TextStyle(
                fontFamily: 'pixelFont', 
                fontSize: fontSize,
                color: isSelected ? Palette.amarelo : Colors.transparent,
                fontWeight: FontWeight.bold, 
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'pixelFont', 
                fontSize: fontSize,
                color: isSelected ? Palette.amarelo : Palette.branco,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}