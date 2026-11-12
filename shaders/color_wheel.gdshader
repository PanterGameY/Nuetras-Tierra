shader_type canvas_item;

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    if (dist > 0.5) {
        discard; // Forma circular perfecta
    }
    
    // Obtener ángulo de 0 a 2*PI
    float angle = atan(uv.y, uv.x);
    if (angle < 0.0) {
        angle += 6.28318530718;
    }
    
    float hue = angle / 6.28318530718;
    float sat = dist / 0.5;
    
    // Convertir HSV a RGB directamente en el fragment shader
    vec3 c = vec3(hue, sat, 1.0);
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    vec3 rgb = c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    
    // Anti-aliasing en el borde exterior del círculo
    float alpha = smoothstep(0.5, 0.485, dist);
    
    COLOR = vec4(rgb, alpha);
}
