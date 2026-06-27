// Segmented bar shader (bloques) — para Gasolina y Temperatura
shader_type canvas_item;

// Progreso [0..1]
uniform float value = 0.5;
// Número de segmentos (bloques)
uniform int segments = 12;
// Colores cuando "vacío" y cuando "lleno"
uniform vec4 color_empty = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 color_full = vec4(1.0, 1.0, 1.0, 1.0);
// Si true usa gradiente temperatura (azul -> naranja)
uniform bool is_temperature = false;
// Grieta entre bloques (fracción del ancho del segmento)
uniform float gap = 0.12;
// Orientación: true = horizontal (por defecto para ColorRect ancho)
uniform bool horizontal = true;

void fragment() {
    vec2 uv = UV;
    float pos = horizontal ? uv.x : uv.y;

    int segs = max(segments, 1);
    float segW = 1.0 / float(segs);

    // Coordenada local dentro del segmento [0..1]
    float local = fract(pos / segW);
    float index_f = floor(pos / segW);

    // Umbral para decidir si el bloque está "encendido" según el valor
    float blockEdge = (index_f + 1.0) * segW;
    float current_block = step(blockEdge, value);

    // Máscara para el interior del bloque (agujero/gap)
    float inside_low = step(gap, local);
    float inside_high = 1.0 - step(1.0 - gap, local);
    float block_mask = inside_low * inside_high;

    // Color final del bloque (gradiente si es temperatura)
    vec4 final_color = color_full;
    if (is_temperature) {
        vec3 temp_grad = mix(vec3(0.0, 0.5, 1.0), vec3(1.0, 0.2, 0.0), pos);
        final_color = vec4(temp_grad, 1.0);
    }

    vec4 col = mix(color_empty, final_color, current_block);
    float alpha = col.a * block_mask;
    COLOR = vec4(col.rgb, alpha);
}
