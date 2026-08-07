#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;

uniform float uDensidade; 
uniform float uGrossura;  
uniform float uAlpha;     
uniform float uMTamanho;  // Controla o "tamanho" das células RGB
uniform float uMAlpha;    // Intensidade das células RGB

out vec4 fragColor;

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 uv = coord / uResolution;

    // --- 1. ONDA DE DISTORÇÃO (Roll / Tracking) ---
    float rollPhase = uv.y * 5.0 - uTime * 2.5;
    float waveTear = smoothstep(0.98, 1.0, sin(rollPhase));
    float occasional = smoothstep(0.8, 1.0, sin(uTime * 0.3));

    // A máscara base começa "Branca" (Branco no BlendMode.multiply não altera a imagem do jogo)
    vec3 maskColor = vec3(1.0);

    // --- 2. MATRIZ RGB (Shadow Mask) ---
    // Pega na coordenada X e cria blocos de repetição de 0 a 3
    float rgbPattern = mod(coord.x * uMTamanho, 3.0);
    
    // O valor 'dim' dita o quão escuros ficam os canais apagados (quanto maior uMAlpha, mais escuro)
    float dim = 1.0 - uMAlpha; 

    // Lógica do Fósforo: Se for a coluna do Vermelho, abafa o Verde e o Azul.
    if (rgbPattern < 1.0) {
        maskColor = vec3(1.0, dim, dim); // Célula Vermelha
    } else if (rgbPattern < 2.0) {
        maskColor = vec3(dim, 1.0, dim); // Célula Verde
    } else {
        maskColor = vec3(dim, dim, 1.0); // Célula Azul
    }

    // --- 3. SCANLINES (Linhas Horizontais) ---
    float densidade = uResolution.y * uDensidade;
    float ciclo = fract(uv.y * densidade);
    float scanline = step(uGrossura, ciclo);
    // Transforma a linha preta num valor multiplicador
    float scanIntensity = mix(1.0, 1.0 - uAlpha, 1.0 - scanline);
    
    maskColor *= scanIntensity;

    // --- 4. VIGNETTE (Sombra dos cantos do Tubo) ---
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.25), 0.0, 1.0);
    // Não deixamos escurecer 100%, travamos a sombra em 60% de opacidade
    float vignetteIntensity = mix(1.0, vignette, 0.6); 
    maskColor *= vignetteIntensity;

    // --- 5. FLICKER (Oscilação de energia) ---
    float flicker = sin(uTime * 15.0) * 0.02;
    maskColor += vec3(flicker);

    // Detalhe extra: Quando a onda pesada da TV passa, ela dá um "estouro" de brilho
    maskColor += vec3(waveTear * occasional * 0.15);

    // Envia a máscara final para a tela!
    fragColor = vec4(maskColor, 1.0);
}