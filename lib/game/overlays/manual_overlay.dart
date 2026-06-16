import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dungeon_crawler/game/dungeon_game.dart'; // Ajuste o seu import
import 'package:dungeon_crawler/game/components/core/palette.dart';

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
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
              child: Column(
                children: [
                  const Text(
                    "MANUAL DE INSTRUÇÕES",
                    style: TextStyle(
                      fontFamily: 'pixelFont',
                      color: Palette.amarelo,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Palette.branco, width: 2),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        controller: _scrollController, // Vinculado!
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          _getManualContent(),
                          style: const TextStyle(
                            fontFamily: 'pixelFont',
                            color: Palette.branco,
                            fontSize: 13,
                            height: 1.4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "[▲▼] Controles ou Arrastar",
                        style: TextStyle(
                          fontFamily: 'pixelFont',
                          color: Palette.branco,
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          backgroundColor: Colors.redAccent.withOpacity(0.2),
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: () {
                          widget.game.closeManual();
                        },
                        child: const Text(
                          "SAIR [B]",
                          style: TextStyle(
                            fontFamily: 'pixelFont',
                            color: Colors.redAccent,
                            fontSize: 12,
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
    return " PRÓLOGO: QUEDA NA ESCURIDÃO\n"
        "Nenhum cavaleiro retornou com vida de Gnothrok.\n"
        "Explore o labirinto procedural, pegue a Chave\n"
        "da Masmorra e desça as escadarias ocultas!\n\n"
        " MODO EXPLORAÇÃO (Navegação)\n"
        "- Seta [▲]/[▼]: Anda para frente/trás.\n"
        "  *Segure o botão para andar continuamente.*\n"
        "- Seta [◄]/[►]: Gira a visão em 90 graus.\n"
        "- Botão [A]: Abre baús/portas e recolhe itens.\n"
        "- Botão [B]: Abre ou fecha a mochila.\n"
        "  *Bater na parede gera um tranco na tela!*\n\n"
        " MODO COMBATE (Batalhas)\n"
        "- Seta [◄]/[►]: Deslocamento lateral\n"
        "- Clique duplo [◄◄] / [►►]: Dash\n"
        "- Seta [▲]: Alterna a Magia/Item selecionado\n"
        "- Seta [▼]: Levanta o escudo.\n"
        "- Botão [A]: Ataca.\n"
        "- Botão [B]: Usa a Magia/Item selecionado.\n\n"
        " ATRIBUTOS & EVOLUÇÃO (Altares)\n"
        "Gaste Essências acumuladas nos Altares para\n"
        "adquirir 3 pontos de melhoria de status:\n"
        "1. FORÇA (STR): Dano físico e Regeneração de Stamina.\n"
        "2. CONSTITUIÇÃO (CON): Aumenta HP e Stamina.\n"
        "3. SABEDORIA (WIS): Aumenta Mana e dano mágico.\n\n"
      /*  "🔮 MAGIAS EM DESTAQUE\n"
        "- Tiro Perfurante (10 Mana): Onda cinza que fura\n"
        "  e hita todas as fileiras de monstros de uma vez.\n"
        "- Olho de Slime (12 Mana): Projétil rebatedor\n"
        "  estilo Pinball. Quica 12 vezes nas paredes e\n"
        "  aplica Stun de 1.5s (paralisia) nos monstros.\n\n"
        "👾 BESTIÁRIO DAS PROFUNDEZAS\n"
        "- Gelatina (Slime): Salta erraticamente.\n"
        "- Aranha: Dá botes verticais rápidos do teto.\n"
        "- Lacaio (Goblin): Corre para as paredes se\n"
        "  ficar encurralado na linha de frente.\n"
        "- Mímico: Baú falso. Só toma dano quando abre\n"
        "  a boca para golpear.\n"
        "- Morcego: Mergulha na diagonal vindo do alto.\n"
        "- Orc Comum: Lê sua mente e ergue o escudo em\n"
        "  tempo real se você tentar atacá-lo.\n\n"
        "👑 SUPREMO: ORC CHEFE (BOSS)\n"
        "Possui 250 HP e habilidades implacáveis:\n"
        "- Ataque Pesado (Aura Vermelha): Demora 1.2s\n"
        "  para carregar, dá 30 de dano e é INDEFENSÁVEL.\n"
        "  Você deve desviar usando o Dash horizontal!\n"
        "- Berrante (Aura Verde): Canaliza por 1.5s e\n"
        "  invoca um Goblin Lacaio na linha de trás.\n\n"
        "💎 RECOMPENSAS EM FILA REATIVA\n"
        "Ao vencer, os saques de essências e drops são\n"
        "empilhados em uma fila de mensagens. Pressione\n"
        "[A] para esvaziar a fila e ler uma por uma.\n"
        "O combate só fecha quando a lista acabar!" */
        ;
  }
}