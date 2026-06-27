shader_type canvas_item;

uniform vec4 color_carcasa : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float redondeo : hint_range(0.0, 0.5) = 0.15; // Curvatura de las esquinas
uniform float grosor_borde : hint_range(0.0, 0.1) = 0.02; // El marco de metal

// Función para calcular bordes redondeados (SDF)
float sdRoundedRect(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

void fragment() {
    vec2 uv = UV - 0.5;
    vec2 size = vec2(0.45, 0.9); // Proporción del móvil (alto y flaco)
    
    // Dibujar la carcasa
    float dist = sdRoundedRect(uv, size * 0.5, redondeo);
    float mask = smoothstep(0.01, 0.0, dist);
    
    // Dibujar el marco (un pequeño brillo metálico)
    float marco = smoothstep(0.0, -0.01, dist) - smoothstep(-grosor_borde, -grosor_borde - 0.01, dist);
    
    vec3 color_final = mix(vec3(0.0), color_carcasa.rgb, mask);
    color_final += marco * 0.2; // Añade un toque metálico al borde
    
    COLOR = vec4(color_final, mask);
}