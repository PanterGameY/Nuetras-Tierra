shader_type canvas_item;

uniform vec4 brillo_color : source_color = vec4(1.0, 1.0, 1.0, 0.15);
uniform float intensidad_reflejo : hint_range(0.0, 1.0) = 0.2;
uniform float curvatura : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // Obtenemos la textura original (por si quieres ponerle un tinte)
    vec4 color_original = texture(TEXTURE, UV);
    
    // 1. Crear el reflejo diagonal
    // Combinamos X e Y para que el brillo cruce la pantalla de esquina a esquina
    float reflejo = smoothstep(0.4, 0.5, (UV.x + UV.y * 0.5) * 0.6);
    
    // 2. Crear un segundo brillo más fino (efecto cristal pulido)
    float linea_fina = smoothstep(0.18, 0.2, (UV.x + UV.y * 0.5) * 0.5);
    linea_fina -= smoothstep(0.2, 0.22, (UV.x + UV.y * 0.5) * 0.5);
    
    // 3. Viñeta interna (oscurece un poco los bordes para dar profundidad)
    float vineta = distance(UV, vec2(0.5));
    vineta = smoothstep(0.3, 0.7, vineta) * 0.3;
    
    // Mezcla final
    vec3 final_brillo = brillo_color.rgb * (reflejo + linea_fina * 2.0);
    float alpha_final = (reflejo + linea_fina) * intensidad_reflejo;
    
    // Aplicamos el brillo sobre el color de la pantalla (o transparente)
    COLOR = vec4(final_brillo, alpha_final - vineta);
}