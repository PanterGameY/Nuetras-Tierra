shader_type canvas_item;

uniform vec3 color_base : source_color = vec3(0.12, 0.12, 0.14);
uniform vec3 color_led : source_color = vec3(0.0, 1.0, 0.5);
uniform float brillo : hint_range(0.0, 1.0) = 0.0;
uniform float redondeo : hint_range(0.0, 0.5) = 0.15;

// Función para crear un cuadrado redondeado
float sd_rounded_box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Generador de ruido simple para textura de plástico
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV - 0.5;
    float d = sd_rounded_box(uv, vec2(0.45), redondeo);
    
    // 1. Máscara principal y sombra interna
    float mascara = smoothstep(0.01, -0.01, d);
    
    // 2. Simulación de Bisel (Iluminación)
    float bisel = smoothstep(0.05, 0.0, abs(d + 0.02));
    vec3 iluminacion = vec3(smoothstep(-0.2, 0.2, uv.y + uv.x)) * 0.15;
    
    // 3. Textura de plástico rugoso
    float ruido = hash(uv * 100.0) * 0.04;
    vec3 color_plastico = color_base + ruido + iluminacion;
    
    // 4. El LED (Círculo pequeño en la esquina superior derecha)
    vec2 pos_led = vec2(0.3, -0.3);
    float d_led = length(uv - pos_led) - 0.06;
    float m_led = smoothstep(0.01, -0.01, d_led);
    
    // Efecto de encendido del LED
    vec3 led_final = mix(vec3(0.05), color_led, brillo);
    led_final += color_led * brillo * smoothstep(0.15, 0.0, length(uv - pos_led)) * 0.6; // Glow
    
    // 5. Composición final
    vec3 final_rgb = mix(vec3(0.0), color_plastico, mascara); // Color del botón
    final_rgb = mix(final_rgb, led_final, m_led * mascara); // Añadir el LED
    
    // Sombra exterior sutil
    float sombra_ext = smoothstep(0.1, -0.2, d);
    
    COLOR = vec4(final_rgb, mascara + (sombra_ext * 0.3));
}