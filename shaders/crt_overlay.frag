#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;

uniform float uDensidade; // Espaçamento das linhas
uniform float uGrossura;  // Espessura da linha preta
uniform float uAlpha;     // Força das scanlines
uniform float uMTamanho;  // Tamanho das células RGB
uniform float uMAlpha;    // Contraste da grelha RGB

out vec4 fragColor;

void main() {
    vec2 coord = FlutterFragCoord().xy;
    vec2 uv = coord / uResolution;

    // --- 1. ONDA DE DISTORÇÃO (Roll / Tracking) ---
    float rollPhase = uv.y * 5.0 - uTime * 2.5;
    float waveTear = smoothstep(0.98, 1.0, sin(rollPhase));
    float occasional = smoothstep(0.8, 1.0, sin(uTime * 0.3));

    // A onda gera um pico de luz
    float waveGlow = waveTear * occasional * 0.2;

    // --- 2. GRELHA RGB COM PRESERVAÇÃO DE LUMINÂNCIA ---
    float rgbPattern = mod(coord.x * uMTamanho, 3.0);
    
    // O Segredo: No modo Overlay do Flutter, o valor 0.5 é INVISÍVEL (neutro).
    // Para colorir sem estragar a luz, empurramos a cor ativa para cima de 0.5
    // e as cores inativas para baixo de 0.5.
    float high = 0.5 + (uMAlpha * 0.5); // "Acende" o fósforo
    float low  = 0.5 - (uMAlpha * 0.5); // "Apaga" os fósforos vizinhos

    vec3 maskColor;
    if (rgbPattern < 1.0) {
        maskColor = vec3(high, low, low); // Fósforo Vermelho
    } else if (rgbPattern < 2.0) {
        maskColor = vec3(low, high, low); // Fósforo Verde
    } else {
        maskColor = vec3(low, low, high); // Fósforo Azul
    }

    // --- 3. SCANLINES (Linhas Horizontais) ---
    float densidade = uResolution.y * uDensidade;
    float ciclo = fract(uv.y * densidade);
    float scanline = step(uGrossura, ciclo);
    
    // Escurece ligeiramente a nossa base 0.5 onde a linha preta cai
    float scanIntensity = mix(1.0, 1.0 - uAlpha, 1.0 - scanline);
    maskColor *= scanIntensity;

    // --- 4. VIGNETTE (Sombra dos cantos) ---
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.25), 0.0, 1.0);
    float vignetteIntensity = mix(1.0, vignette, 0.6); 
    maskColor *= vignetteIntensity;

    // --- 5. FLICKER (Oscilação de Energia) ---
    float flicker = sin(uTime * 15.0) * 0.015;
    maskColor += vec3(flicker);

    // Adiciona a luz do ecrã quando a onda passa
    maskColor += vec3(waveGlow);

    // Envia a máscara final para interagir com o ecrã
    fragColor = vec4(maskColor, 1.0);
}