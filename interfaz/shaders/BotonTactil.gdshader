shader_type canvas_item;

// Parámetros del botón de borde
uniform bool presionado = false;
uniform bool activo = false;
uniform vec4 color_normal : source_color = vec4(0.3, 0.4, 0.6, 0.75);
uniform vec4 color_presionado : source_color = vec4(0.5, 0.7, 1.0, 0.95);
uniform vec4 color_activo : source_color = vec4(0.3, 0.9, 0.5, 0.9);
uniform float brillo_pulso = 0.0;
uniform float grosor_linea = 0.08; // Grosor de la línea visible
uniform float difuminado_borde = 0.25; // Cuánto difuminar hacia los bordes
uniform int posicion_borde = 0; // 0=izq, 1=der, 2=arriba, 3=abajo

void fragment() {
    vec2 uv = UV;
    float dist_borde = 0.0;
    
    // Calcular distancia según posición del borde
    if (posicion_borde == 0) { // Izquierda
        dist_borde = uv.x;
    } else if (posicion_borde == 1) { // Derecha
        dist_borde = 1.0 - uv.x;
    } else if (posicion_borde == 2) { // Arriba
        dist_borde = uv.y;
    } else { // Abajo
        dist_borde = 1.0 - uv.y;
    }
    
    // Color base según estado
    vec4 base_color = color_normal;
    if (activo) {
        base_color = color_activo;
    }
    if (presionado) {
        base_color = color_presionado;
    }
    
    // Agregar brillo de pulso
    base_color.rgb += vec3(brillo_pulso);
    
    // Crear máscara de línea en el borde
    float linea = smoothstep(grosor_linea + 0.02, grosor_linea, dist_borde);
    
    // Difuminado hacia los bordes perpendiculares
    float fade_perpendicular = 1.0;
    if (posicion_borde <= 1) { // Bordes verticales (izq/der)
        // Difuminar arriba y abajo
        float fade_top = smoothstep(0.0, difuminado_borde, uv.y);
        float fade_bottom = smoothstep(1.0, 1.0 - difuminado_borde, uv.y);
        fade_perpendicular = fade_top * fade_bottom;
    } else { // Bordes horizontales (arriba/abajo)
        // Difuminar izquierda y derecha
        float fade_left = smoothstep(0.0, difuminado_borde, uv.x);
        float fade_right = smoothstep(1.0, 1.0 - difuminado_borde, uv.x);
        fade_perpendicular = fade_left * fade_right;
    }
    
    // Gradiente sutil en la línea
    float gradient = 1.0;
    if (posicion_borde <= 1) {
        gradient = 0.7 + sin(uv.y * 3.14159) * 0.3;
    } else {
        gradient = 0.7 + sin(uv.x * 3.14159) * 0.3;
    }
    
    base_color.rgb *= gradient;
    
    // Intensidad extra cuando presionado
    if (presionado) {
        base_color.rgb += vec3(0.2);
    }
    
    // Combinar todo
    base_color.a *= linea * fade_perpendicular;
    
    COLOR = base_color;
}
