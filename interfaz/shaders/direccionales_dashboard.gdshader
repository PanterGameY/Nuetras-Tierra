shader_type canvas_item;

// --- Parámetros de Control ---
uniform vec4 color_on : source_color = vec4(0.0, 1.0, 0.0, 1.0);  // Verde encendido
uniform vec4 color_off : source_color = vec4(0.1, 0.1, 0.1, 1.0); // Gris oscuro apagado
uniform float blink_speed : hint_range(0.0, 10.0) = 4.0;          // Velocidad
uniform bool is_on = false;                                       // Interruptor principal
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;        // Intensidad de brillo

void fragment() {
    // Obtener la textura original (tu flecha)
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Si el píxel es transparente, terminamos rápido (optimización)
    if (tex_color.a < 0.01) {
        discard;
    }

    // 1. Lógica de parpadeo binario (Cuadrada)
    // fract(TIME) crea una sierra de 0 a 1. step(0.5) la convierte en 0 o 1.
    float blink = step(0.5, fract(TIME * blink_speed * 0.2));
    
    // Si no está activado (is_on), forzamos a 0 (apagado)
    float active = is_on ? blink : 0.0;
    
    // 2. Mezcla de colores
    // Si está activo usamos color_on, si no, color_off
    vec3 final_rgb = mix(color_off.rgb, color_on.rgb, active);
    
    // 3. Efecto de Brillo (Glow)
    // Multiplicamos el color por la intensidad cuando está encendido
    // En Godot, si el HDR está activo, valores > 1.0 brillan
    if (active > 0.5) {
        final_rgb *= glow_intensity;
    }
    
    // 4. Salida final
    // Mantener la transparencia de la flecha original
    COLOR = vec4(final_rgb, tex_color.a);
}