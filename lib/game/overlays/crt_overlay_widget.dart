import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';


// 1. Criamos um StatefulWidget para controlar a passagem do tempo
class CrtOverlayWidget extends StatefulWidget {
  final Widget child; 
  final ValueNotifier<bool> crtFilterEnabled;
  
  const CrtOverlayWidget({
    super.key, 
    required this.child, 
    required this.crtFilterEnabled, // <-- Requer a variável ao ser criado
  });

  @override
  State<CrtOverlayWidget> createState() => _CrtOverlayWidgetState();
}

class _CrtOverlayWidgetState extends State<CrtOverlayWidget> with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _loadShader();
    
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMicroseconds / 1000000.0; 
      });
    });
    _ticker.start();
  }

  void _loadShader() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/crt_overlay.frag');
      if (mounted) setState(() {}); 
    } catch (e) {
      debugPrint('Erro ao carregar o Shader CRT: $e\nNão se esqueça de adicionar a pasta no pubspec.yaml!');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double contrast = 1.2; 
    double brightness = 15; 
    
    // Agora o filtro usa um StackFit.expand para respeitar milimetricamente o tamanho do parent
    return Stack(
      fit: StackFit.expand,
      children:[
        widget.child, // O JOGO
        
        ValueListenableBuilder<bool>(
          valueListenable: widget.crtFilterEnabled,
          builder: (context, crtOn, child) {
            if (crtOn && _program != null) {
              return ClipRect( // Garante que o filtro NUNCA vaza deste bloco
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ui.ImageFilter.compose(
                        outer: ui.ColorFilter.matrix([
                          contrast,  0.0,  0.0,  0.0,  brightness,
                          0.0,  contrast,  0.0,  0.0,  brightness,
                          0.0,  0.0,  contrast,  0.0,  brightness,
                          0.0,  0.0,  0.0,  1.0,   0.0,            
                        ]),
                        inner: const ui.ColorFilter.mode(
                          Color(0xFF0A0E18), 
                          BlendMode.lighten, 
                        ),
                      ),
                      child: const SizedBox.shrink(),
                    ),
                    IgnorePointer( 
                      child: CustomPaint(
                        painter: CrtPainter(_program!, _time),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink(); 
          },
        ),
      ],
    );
  }
}

// 4. O Pintor que desenha o GLSL na tela
class CrtPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;

  CrtPainter(this.program, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    var shader = program.fragmentShader();
    
    // CORREÇÃO CRÍTICA: 
    // Substituímos o "physicalSize" brutal do telemóvel pelo tamanho lógico ("size")
    // Desta forma o shader fica perfeito independente da densidade de pixéis do ecrã!
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    shader.setFloat(3, 0.2);  // Densidade 
    shader.setFloat(4, 0.70); // Grossura 
    shader.setFloat(5, 0.2);  // Alpha 

    shader.setFloat(6, 0.2);  // Tamanho matriz
    shader.setFloat(7, 0.08); // Alpha matriz

    var paint = Paint()..shader = shader;
    
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CrtPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}