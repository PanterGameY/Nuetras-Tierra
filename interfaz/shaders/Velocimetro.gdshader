shader_type canvas_item;

uniform bool presionado = false;
uniform float intensidad_presion : hint_range(0.0, 1.0) = 0.0;
uniform float opacidad_global : hint_range(0.0, 1.0) = 0.8;
uniform bool es_freno = false;

// --- FUNCIONES COMPARTIDAS PARA COHERENCIA VISUAL ---
float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float sdRect(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

void fragment() {
    // 1. DIMENSIONES (Rectángulo vertical de pedal)
    vec2 uv = UV - vec2(0.5);
    uv.x *= 0.52; 
    
    // 2. EFECTO DE HUNDIMIENTO 3D
    // Reducimos escala y desplazamos levemente en Y para dar perspectiva
    float hundimiento = mix(1.0, 0.88, intensidad_presion);
    vec2 uv_p = (uv + vec2(0.0, intensidad_presion * 0.03)) / hundimiento;
    
    // 3. PALETA (Basada en tu Joystick)
    vec3 col_dorado  = vec3(0.9,  0.75, 0.4);
    vec3 col_ambar   = vec3(1.0,  0.6,  0.15);
    vec3 col_cristal = vec3(0.14, 0.17, 0.21);
    vec3 col_fuego   = vec3(1.0,  0.28, 0.05);
    vec3 col_blanco  = vec3(1.0,  1.0,  1.0);
    
    vec3 col_main = es_freno ? col_fuego : col_dorado;
    
    // 4. GEOMETRÍA Y MÁSCARAS
    float d = sdRect(uv_p, vec2(0.2, 0.42), 0.04);
    float mascara = smoothstep(0.01, -0.01, d);
    float borde = smoothstep(0.02, 0.01, abs(d));
    
    // 5. CRISTAL REACTIVO (Cambia con la presión)
    float grano = hash(uv_p * 250.0) * 0.04;
    // El cristal se oscurece al hundirse (oclusión ambiental)
    vec3 cristal_rgb = mix(col_cristal, col_cristal * 0.5, intensidad_presion);
    cristal_rgb += col_main * (1.0 - length(uv_p)) * 0.15 * intensidad_presion;
    cristal_rgb -= grano;
    
    // 6. LÍNEAS DE AGARRE (Grip tech)
    float lineas = step(0.78, fract(uv_p.y * 14.0)) * mascara;
    lineas *= smoothstep(0.18, 0.14, abs(uv_p.x));
    
    // 7. COMPOSICIÓN Y "SHADOW DEPTH"
    // Sombra en el fondo que aparece cuando el pedal se aleja (se hunde)
    float sombra_externa = smoothstep(0.0, 0.2, d) * (1.0 - mascara) * intensidad_presion * 0.6;
    
    vec3 final_rgb = mix(cristal_rgb, col_main, borde);
    
    // Glow de activación en el borde al presionar
    final_rgb += col_main * borde * intensidad_presion * 2.0;
    
    // Mezcla de líneas con brillo dinámico
    final_rgb = mix(final_rgb, col_blanco, lineas * (0.2 + intensidad_presion * 0.5));
    
    // 8. ALFA FINAL
    // El borde siempre es visible, el fondo es traslúcido
    float alfa = (mascara * mix(0.3, 0.7, intensidad_presion) + borde) * opacidad_global;
    
    COLOR = vec4(final_rgb, clamp(alfa - sombra_externa, 0.0, 1.0));
}