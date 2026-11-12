shader_type canvas_item;

void fragment() {
    vec2 center = vec2(0.5);
    float d = distance(UV, center);
    
    // Fondo gris oscuro translúcido
    vec4 col = vec4(0.1, 0.1, 0.1, 0.5); 
    
    // Borde blanco/dorado muy fino
    float border = smoothstep(0.48, 0.5, max(abs(UV.x-0.5), abs(UV.y-0.5)));
    col.rgb += border * vec3(0.8, 0.7, 0.4);
    col.a += border;

    COLOR = col;
}