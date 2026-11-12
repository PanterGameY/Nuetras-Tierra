shader_type canvas_item;

// Control de posición: 0=P, 1=R, 2=N, 3=D
uniform float posicion_marcha : hint_range(0.0, 3.0) = 0.0; 
uniform float opacidad_global : hint_range(0.0, 1.0) = 0.9;
uniform bool tocando = false;

float sdRect(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

float drawSeg(vec2 p, vec2 a, vec2 b, float w) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return smoothstep(w + 0.02, w - 0.01, length(pa - ba * h));
}

void fragment() {
    // Ajuste de escala para que se vea bien en vertical
    vec2 uv = (UV - 0.5) * vec2(1.0, 4.0);
    
    // Colores Originales Estéticos
    vec3 col_fondo = vec3(0.03, 0.04, 0.06);
    vec3 col_texto = vec3(0.35, 0.4, 0.45); 
    vec3 col_activo = vec3(1.0, 0.65, 0.1); // Naranja Ámbar
    vec3 col_indicador = vec3(0.0, 0.8, 1.0); // Azul Cian Neón
    
    // Fondo con borde redondeado
    float d_fondo = sdRect(uv, vec2(0.42, 1.92), 0.15);
    float mask_fondo = smoothstep(0.02, 0.0, d_fondo);
    
    float posY[4] = float[](-1.5, -0.5, 0.5, 1.5);
    
    // --- DIBUJO ESTÉTICO DE LETRAS ---
    // P
    vec2 p_uv = (uv - vec2(0.0, posY[0])) * 7.0;
    float L_P = drawSeg(p_uv, vec2(-0.4, -1.2), vec2(-0.4, 1.2), 0.15);
    L_P = max(L_P, drawSeg(p_uv, vec2(-0.4, -1.2), vec2(0.4, -1.2), 0.15));
    L_P = max(L_P, drawSeg(p_uv, vec2(0.4, -1.2), vec2(0.4, 0.0), 0.15));
    L_P = max(L_P, drawSeg(p_uv, vec2(0.4, 0.0), vec2(-0.4, 0.0), 0.15));
    
    // R
    vec2 r_uv = (uv - vec2(0.0, posY[1])) * 7.0;
    float L_R = drawSeg(r_uv, vec2(-0.4, -1.2), vec2(-0.4, 1.2), 0.15);
    L_R = max(L_R, drawSeg(r_uv, vec2(-0.4, -1.2), vec2(0.4, -1.2), 0.15));
    L_R = max(L_R, drawSeg(r_uv, vec2(0.4, -1.2), vec2(0.4, 0.0), 0.15));
    L_R = max(L_R, drawSeg(r_uv, vec2(0.4, 0.0), vec2(-0.4, 0.0), 0.15));
    L_R = max(L_R, drawSeg(r_uv, vec2(-0.1, 0.0), vec2(0.5, 1.2), 0.15));
    
    // N
    vec2 n_uv = (uv - vec2(0.0, posY[2])) * 7.0;
    float L_N = drawSeg(n_uv, vec2(-0.5, -1.2), vec2(-0.5, 1.2), 0.15);
    L_N = max(L_N, drawSeg(n_uv, vec2(0.5, -1.2), vec2(0.5, 1.2), 0.15));
    L_N = max(L_N, drawSeg(n_uv, vec2(-0.5, -1.2), vec2(0.5, 1.2), 0.15));
    
    // D
    vec2 d_uv = (uv - vec2(0.0, posY[3])) * 7.0;
    float L_D = drawSeg(d_uv, vec2(-0.4, -1.2), vec2(-0.4, 1.2), 0.15);
    L_D = max(L_D, drawSeg(d_uv, vec2(-0.4, -1.2), vec2(0.2, -1.2), 0.15));
    L_D = max(L_D, drawSeg(d_uv, vec2(-0.4, 1.2), vec2(0.2, 1.2), 0.15));
    L_D = max(L_D, drawSeg(d_uv, vec2(0.2, -1.2), vec2(0.5, -0.8), 0.15));
    L_D = max(L_D, drawSeg(d_uv, vec2(0.5, -0.8), vec2(0.5, 0.8), 0.15));
    L_D = max(L_D, drawSeg(d_uv, vec2(0.5, 0.8), vec2(0.2, 1.2), 0.15));

    // Iluminación de letra activa (basado en posicion_marcha redondeada)
    float cur = round(posicion_marcha);
    float p_mask = smoothstep(0.4, 0.2, abs(cur - 0.0));
    float r_mask = smoothstep(0.4, 0.2, abs(cur - 1.0));
    float n_mask = smoothstep(0.4, 0.2, abs(cur - 2.0));
    float d_mask = smoothstep(0.4, 0.2, abs(cur - 3.0));
    
    vec3 col_letras = mix(col_texto, col_activo, L_P * p_mask);
    col_letras = mix(col_letras, col_activo, L_R * r_mask);
    col_letras = mix(col_letras, col_activo, L_N * n_mask);
    col_letras = mix(col_letras, col_activo, L_D * d_mask);
    
    float mask_total_letras = max(max(L_P, L_R), max(L_N, L_D));
    vec3 col = mix(col_fondo, col_letras, mask_total_letras * mask_fondo);

    // --- INDICADOR DESLIZANTE ---
    float pos_y_ind = mix(-1.5, 1.5, posicion_marcha / 3.0);
    float d_ind = sdRect(uv - vec2(0.0, pos_y_ind), vec2(0.42, 0.45), 0.12);
    float indicador_glow = smoothstep(0.35, 0.0, d_ind);
    
    // El indicador brilla más cuando se toca
    col += col_indicador * indicador_glow * (tocando ? 0.8 : 0.4);
    
    // Borde metálico exterior
    float borde_caja = smoothstep(0.02, 0.0, abs(d_fondo) - 0.01);
    col += col_texto * borde_caja * 0.4;

    COLOR = vec4(col, mask_fondo * opacidad_global);
}