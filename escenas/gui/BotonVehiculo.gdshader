shader_type canvas_item;

uniform bool activo = false;
uniform vec4 color_activo   : source_color = vec4(1.0, 0.9, 0.1, 0.88); 
uniform vec4 color_inactivo : source_color = vec4(1.0, 1.0, 1.0, 0.22); 
uniform float brillo_activo  : hint_range(1.0, 2.0) = 1.4;

// Parametros de estilo (Cristal)
uniform vec4 col_borde : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float grosor_borde : hint_range(0.0, 0.1) = 0.025;
uniform float radio_bordes  : hint_range(0.0, 0.5) = 0.18;
uniform float shadow_size : hint_range(0.0, 0.5) = 0.3; // Profundidad de la sombra

float sdRoundedRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    vec2 uv = UV - 0.5;
    vec2 tam = vec2(0.48); // Margen pequeño para que no se corte el borde
    
    // 1. Geometria Base (SDF)
    float dist = sdRoundedRect(uv, tam, radio_bordes);
    
    // 2. Mascaras de capas
    float m_externa = smoothstep(0.01, -0.01, dist);
    float m_interna = smoothstep(-grosor_borde, -grosor_borde - 0.01, dist);
    float m_borde = m_externa - m_interna;
    
    // 3. Logica de Color Segun Estado
    vec4 color_base = activo ? color_activo : color_inactivo;
    float brillo = activo ? brillo_activo : 1.0;
    vec3 rgb_final = color_base.rgb * brillo;
    
    // 4. Efecto de Profundidad (Sombra interna)
    // La sombra nace desde el borde hacia adentro
    float s_factor = clamp((dist + grosor_borde) / -shadow_size, 0.0, 1.0);
    float sombra = pow(1.0 - s_factor, 2.0) * 0.5; // Sombra sutil
    
    // 5. Composicion
    // Capa fondo (el color del boton + sombra de profundidad)
    vec3 capa_fondo = mix(rgb_final, vec3(0.0), sombra);
    float alpha_fondo = color_base.a * m_interna;
    
    // Capa Borde (Blanco brillante)
    vec3 color_con_borde = mix(capa_fondo, col_borde.rgb, m_borde);
    float alpha_con_borde = max(alpha_fondo, m_borde);
    
    // Añadimos un pequeño brillo especular en la parte superior del borde
    float brillo_especular = smoothstep(-0.05, -0.15, uv.y) * m_borde * 0.4;
    
    vec3 color_salida = color_con_borde + vec3(1.0) * brillo_especular;
    float alpha_salida = alpha_con_borde * m_externa;

    COLOR = vec4(color_salida, alpha_salida);
}