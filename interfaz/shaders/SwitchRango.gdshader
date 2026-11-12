shader_type canvas_item;

uniform bool activo = false;
uniform vec4 color_dorado : source_color = vec4(0.85, 0.7, 0.4, 1.0);

void fragment() {
    vec2 uv = UV;
    // Base de cristal
    vec4 col = vec4(0.15, 0.15, 0.15, 0.4);
    
    // Dibujar el marco
    float marco = smoothstep(0.47, 0.49, max(abs(uv.x - 0.5), abs(uv.y - 0.5)));
    
    if (activo) {
        // Si está activo, el borde brilla en dorado y el fondo se aclara
        col.rgb = mix(col.rgb, color_dorado.rgb, marco);
        col.a = 0.7;
        col.rgb += 0.05; // Aclarado sutil
    } else {
        // Si está inactivo, el borde es gris/blanco sutil
        col.rgb = mix(col.rgb, vec3(0.5), marco);
        col.a = 0.3;
    }
    
    COLOR = col;
}