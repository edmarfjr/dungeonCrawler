import 'package:flutter/material.dart';

class GameButton extends StatefulWidget {
  final Widget child; // A imagem ou desenho do seu botão atual
  final VoidCallback onDown; // O que acontece quando aperta
  final VoidCallback onUp;   // O que acontece quando solta

  const GameButton({
    super.key,
    required this.child,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Usamos o Listener porque ele não tem delay de toque (perfeito para jogos)
    return Listener(
      onPointerDown: (_) {
        setState(() {
          _isPressed = true;
        });
        widget.onDown();
      },
      onPointerUp: (_) {
        setState(() {
          _isPressed = false;
        });
        widget.onUp();
      },
      // O Cancel é disparado se o jogador arrastar o dedo para fora do botão
      onPointerCancel: (_) {
        setState(() {
          _isPressed = false;
        });
        widget.onUp();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0, // Encolhe o botão em 15% quando pressionado
        duration: const Duration(milliseconds: 50), // Animação hiper rápida
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.6 : 1.0, // Deixa o botão 40% mais escuro/transparente
          duration: const Duration(milliseconds: 50),
          child: widget.child,
        ),
      ),
    );
  }
}