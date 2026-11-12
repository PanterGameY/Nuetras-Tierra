shader_type canvas_item;

// Parámetros configurables desde el Inspector de Godot
uniform vec4 col_inicio : source_color = vec4(0.06, 0.08, 0.1, 1.0); // Gris muy oscuro
uniform vec4 col_fin    : source_color = vec4(0.06, 0.08, 0.1, 0.0); // Mismo color, pero transparente

// Parámetro para mover el degradado si es necesario
uniform float punto_medio : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // 1. Obtener la coordenada UV X (va de 0.0 en la izquierda a 1.0 en la derecha)
    float factor_x = UV.x;
    
    // 2. Aplicar la lógica de punto medio para centrar el degradado lineal suave
    // El degradado lineal es inherentemente suave, no necesitamos smoothstep
    float degradado_mask = clamp((factor_x - punto_medio) * 2.0 + 1.0, 0.0, 1.0);
    
    // 3. Mezclar los dos colores usando la máscara lineal que creamos
    vec4 color_final = mix(col_inicio, col_fin, degradado_mask);
    
    // 4. Asignar el color final al píxel
    COLOR = color_final;
}