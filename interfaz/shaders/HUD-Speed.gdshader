shader_type canvas_item;

uniform float valor : hint_range(0.0, 1.0) = 0.5; // Velocidad de 0.0 a 1.0
uniform vec4 color_brillo : source_color = vec4(0.85, 0.7, 0.4, 1.0); // Dorado
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5);
    float dist = distance(uv, center);
    
    // --- DISTORSIÓN DE FONDO (Efecto Cristal) ---
    vec2 blur_uv = SCREEN_UV + (uv - center) * 0.01;
    vec4 screen = texture(SCREEN_TEXTURE, blur_uv);

    // --- CÁLCULO DEL ARCO ---
    float angle = atan(uv.y - center.y, uv.x - center.x);
    // Ajustamos el ángulo para que el 0 esté abajo (como un tacómetro real)
    float angle_norm = (angle + PI) / (2.0 * PI); 
    angle_norm = fract(angle_norm + 0.25); 

    // Solo dibujamos el arco entre 0.1 y 0.9 (dejamos un hueco abajo)
    float arc_mask = smoothstep(0.35, 0.34, dist) - smoothstep(0.32, 0.31, dist);
    arc_mask *= step(0.1, angle_norm) * step(angle_norm, 0.9);
    
    // --- PROGRESIÓN DEL VALOR ---
    float progreso = step(angle_norm, mix(0.1, 0.9, valor));
    vec4 col_arco = mix(vec4(1.0, 1.0, 1.0, 0.2), color_brillo, progreso);
    
    // --- EFECTO DE ESCANEO (SCANLINES) ---
    float scanline = sin(uv.y * 200.0 + TIME * 5.0) * 0.1 + 0.9;
    
    vec4 final_col = col_arco * arc_mask * scanline;
    // Mezclamos con el fondo transparente/difuminado
    final_col.a += arc_mask * 0.2; 
    
    COLOR = final_col;
}