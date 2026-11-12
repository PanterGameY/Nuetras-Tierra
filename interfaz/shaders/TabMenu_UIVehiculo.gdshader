shader_type canvas_item;

// Parámetros configurables desde el Inspector de Godot
uniform vec4 col_brillante : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Blanco puro
uniform vec4 col_desvanecido : source_color = vec4(1.0, 1.0, 1.0, 0.2); // Blanco muy transparente

uniform float punto_medio : hint_range(0.0, 1.0) = 0.5; // Dónde empieza el desvanecimiento

void fragment() {
    // 1. Obtener la coordenada UV X (va de 0.0 en la izquierda a 1.0 en la derecha del icono)
    float factor_x = UV.x;
    
    // 2. Crear una máscara de degradado lineal suave
    float degradado_mask = clamp((factor_x - punto_medio) * 2.0 + 1.0, 0.0, 1.0);
    
    // 3. Mezclar los dos colores usando la máscara lineal
    vec4 color_final = mix(col_brillante, col_desvanecido, degradado_mask);
    
    // 4. Multiplicar por la textura original (para mantener las líneas del icono)
    // Esto asegura que el shader solo afecte a las líneas del icono y no al fondo transparente
    color_final *= texture(TEXTURE, UV);
    
    // 5. Asignar el color final al píxel
    COLOR = color_final;
}