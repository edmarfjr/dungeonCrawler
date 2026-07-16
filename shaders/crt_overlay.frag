#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;

uniform float uDensidade; // Espaçamento
uniform float uGrossura;  // Espessura da linha
uniform float uAlpha;     //Alpha da linha
uniform float uMTamanho;     // tamanho da matriz
uniform float uMAlpha;        //alpha da matriz

out vec4 fragColor;

void main() {
    vec2 coord = FlutterFragCoord().xy;
    
    // 1. TELA PLANA (Sem a função curveRemapUV)
    vec2 uv = coord / uResolution;

    // --- EFEITO DE ONDA DE DISTORÇÃO (ROLL/TRACKING) ---
    // Cria uma linha imaginária que desce a tela
    float rollPhase = uv.y * 5.0 - uTime * 2.5;
    float waveTear = smoothstep(0.98, 1.0, sin(rollPhase));
    
    // A onda aparece de tempos em tempos
    float occasional = smoothstep(0.8, 1.0, sin(uTime * 0.3));
    
    // Entorta as coordenadas do eixo X na área da onda
    uv.x += waveTear * occasional * 0.03; 

    // 2. SCANLINES (Finas e Espaçadas)
    // 1º Passo: DISTÂNCIA (Densidade das linhas)
    // Diminuir o 0.15 afasta as linhas umas das outras.
    float densidade = uResolution.y * uDensidade;
    // Cria uma repetição em loop de 0.0 até 1.0 para cada espaço de linha
    float ciclo = fract(uv.y * densidade);
    
    // 2º Passo: GROSSURA DA LINHA
    // A função step(0.85, ciclo) só desenha a linha quando o loop chega no final.
    // O valor 0.85 significa: 85% do espaço é vazio, e apenas 15% vira a linha preta.
    // Se quiser a linha AINDA MAIS FINA, mude para 0.90 ou 0.95!
    float scanline = step(uGrossura, ciclo);
    
    // 3º Passo: OPACIDADE
    // Como a linha agora é fininha, podemos forçar o preto dela para marcar bem.
    // (Aumente o 0.25 se quiser a linha mais escura)
    float scanlineAlpha = scanline * uAlpha;

    // 3. MATRIZ DE PIXELS (AUMENTADA)
    float matrixX = sin(coord.x * 3.14159 * uMTamanho); 
    float matrixY = sin(coord.y * 3.14159 * uMTamanho); 
    float pixelMatrixAlpha = (1.0 - (matrixX * matrixY)) * uMAlpha;

    // 4. VIGNETTE (Sombra profunda dos cantos)
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.25), 0.0, 1.0);
    float vignetteAlpha = (1.0 - vignette) * 0.4;

    // 5. FLICKER (A oscilação de energia da TV)
    float flicker = sin(uTime * 15.0) * 0.02;

    // COMBINANDO OS EFEITOS
    float finalAlpha = scanlineAlpha + pixelMatrixAlpha + vignetteAlpha + flicker;

    // Detalhe extra: Quando a onda de distorção passa, ela "clareia" a tela
    finalAlpha -= waveTear * occasional * 0.15;

    // Trava de segurança gráfica
    finalAlpha = clamp(finalAlpha, 0.0, 1.0);

    // O shader desenha PRETO, e o Alpha faz a máscara!
    fragColor = vec4(0.0, 0.0, 0.0, finalAlpha);
}