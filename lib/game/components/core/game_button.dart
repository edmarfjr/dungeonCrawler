import 'package:flutter/material.dart';

class GameButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onDown; 
  final VoidCallback onUp;  

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
      onPointerCancel: (_) {
        setState(() {
          _isPressed = false;
        });
        widget.onUp();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 50), 
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.6 : 1.0, 
          duration: const Duration(milliseconds: 50),
          child: widget.child,
        ),
      ),
    );
  }
}