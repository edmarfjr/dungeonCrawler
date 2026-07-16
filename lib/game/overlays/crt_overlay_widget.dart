import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// Variável global para ligar/desligar o CRT em qualquer lugar do seu jogo
// Ex: crtFilterEnabled.value = false; (no menu de configurações)
final ValueNotifier<bool> crtFilterEnabled = ValueNotifier<bool>(true);

// 1. Criamos um StatefulWidget para controlar a passagem do tempo
class CrtOverlayWidget extends StatefulWidget {
  final Widget child; // O jogo e os menus vão entrar aqui!
  
  const CrtOverlayWidget({super.key, required this.child});

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
    
    // O Ticker atualiza o tempo constantemente para animar as scanlines
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMicroseconds / 1000000.0; // Converte para segundos
      });
    });
    _ticker.start();
  }

  void _loadShader() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/crt_overlay.frag');
      if (mounted) setState(() {}); // Força a tela a redesenhar quando o shader carregar
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
    double contrast = 1.2; // Aumento de contraste para o fósforo
    double brightness = 15; // Brilho aditivo puro
    
    return Stack(
      children:[
        // 1. O JOGO INTEIRO RODA AQUI NO FUNDO (Livre do filtro global)
        widget.child,
        
        // 2. A PELÍCULA CRT E FILTROS DE COR
        ValueListenableBuilder<bool>(
          valueListenable: crtFilterEnabled,
          builder: (context, crtOn, child) {
            if (crtOn && _program != null) {
              
              // O TRUQUE MÁGICO:
              // Usamos uma Column com flex 4 e 2 para "imitar" a estrutura
              // exata da sua UI. Isto garante alinhamento milimétrico!
              return Column(
                children: [
                  Expanded(
                    flex: 4, // 4 partes de tela para o Filtro CRT (Tela do Jogo)
                    child: ClipRect( 
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Filtros de Cor Aplicados APENAS ao fundo desta área (BackdropFilter)
                          BackdropFilter(
                            filter: ui.ImageFilter.compose(
                              outer: ui.ColorFilter.matrix([
                                contrast,  0.0,  0.0,  0.0,  brightness, // Canal Vermelho
                                0.0,  contrast,  0.0,  0.0,  brightness, // Canal Verde
                                0.0,  0.0,  contrast,  0.0,  brightness, // Canal Azul
                                0.0,  0.0,  0.0,  1.0,   0.0,            // Canal Alpha
                              ]),
                              inner: const ui.ColorFilter.mode(
                                Color(0xFF0A0E18), // Cor de fundo da tela desligada
                                BlendMode.lighten, 
                              ),
                            ),
                            child: const SizedBox.shrink(), // O BackdropFilter aplica nos elementos de trás
                          ),

                          // 2. O Shader do CRT (Scanlines) desenhado por cima
                          IgnorePointer( 
                            child: CustomPaint(
                              painter: CrtPainter(_program!, _time),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 2 partes de tela totalmente VAZIAS E LIMPAS para os Controles!
                  const Expanded(
                    flex: 2, 
                    child: SizedBox.shrink(),
                  ),
                ],
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
    
    // Pegamos a resolução física real da tela do dispositivo
    final physicalSize = ui.PlatformDispatcher.instance.views.first.physicalSize;
    
    shader.setFloat(0, physicalSize.width);
    shader.setFloat(1, physicalSize.height);
    shader.setFloat(2, time);

    shader.setFloat(3, 0.2);  // Densidade (Menor = Mais espaçado)
    shader.setFloat(4, 0.70); // Grossura (Maior = Mais fina)
    shader.setFloat(5, 0.2);  // Alpha (Maior = Mais Escura)

    shader.setFloat(6, 0.2);  // tamanho matriz
    shader.setFloat(7, 0.08); // Alpha matriz

    var paint = Paint()..shader = shader;
    
    // Pinta a área permitida (neste caso, as flex=4 definidos pela Column)
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CrtPainter oldDelegate) {
    // Redesenha a cada frame (já que o tempo está mudando)
    return oldDelegate.time != time;
  }
}