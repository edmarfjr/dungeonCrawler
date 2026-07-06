import 'package:dungeon_crawler/game/components/core/i18n.dart';
import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart';
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.preto,
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: widget.game.mainMenuCursor,
          builder: (context, cursorIndex, child) {
            return SlideTransition(
              position: _blockOffsetAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "DUNGEON CRAWLER", 
                    style: TextStyle(
                      fontFamily: 'pixelFont', 
                      color: Palette.branco, 
                      fontSize: 32, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 2,
                      decoration: TextDecoration.none, 
                    ),
                  ),
                  
                  const SizedBox(height: 60),

                  if (widget.game.hasSavedGame) ...[
                    _buildMenuOption(
                      title: I18n.t('menu_continue'),
                      index: 0,
                      currentIndex: cursorIndex,
                    ),
                    const SizedBox(height: 20),
                    _buildMenuOption(
                      title: I18n.t('menu_new'),
                      index: 1,
                      currentIndex: cursorIndex,
                    ),
                    const SizedBox(height: 20),
                    _buildMenuOption(
                      title: I18n.t('menu_settings'),
                      index: 2,
                      currentIndex: cursorIndex,
                    ),
                    const SizedBox(height: 20),
                    _buildMenuOption(
                      title: I18n.t('menu_manual'),
                      index: 3,
                      currentIndex: cursorIndex,
                    ),
                  ] else ...[
                    _buildMenuOption(
                      title: I18n.t('menu_new'),
                      index: 0,
                      currentIndex: cursorIndex,
                    ),
                    const SizedBox(height: 20),
                    _buildMenuOption(
                      title: I18n.t('menu_settings'),
                      index: 1,
                      currentIndex: cursorIndex,
                    ),
                    const SizedBox(height: 20),
                    _buildMenuOption(
                      title: I18n.t('menu_manual'),
                      index: 2,
                      currentIndex: cursorIndex,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuOption({required String title, required int index, required int currentIndex}) {
    bool isSelected = (index == currentIndex);

    return GestureDetector(
      onTap: () {
        widget.game.mainMenuCursor.value = index;
        widget.game.startInput(GameInput.buttonA);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isSelected ? "> " : "  ",
            style: TextStyle(
              fontFamily: 'pixelFont', fontSize: 20,
              color: isSelected ? Palette.amarelo : Colors.transparent,
              fontWeight: FontWeight.bold, decoration: TextDecoration.none,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'pixelFont', fontSize: 20,
              color: isSelected ? Palette.amarelo : Palette.branco,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}