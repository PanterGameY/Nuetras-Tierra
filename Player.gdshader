shader_type canvas_item;

uniform float blur_amount : hint_range(0, 5) = 2.0;
uniform float radius : hint_range(0, 1) = 0.2;
uniform float softness : hint_range(0, 1) = 0.8;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// 1. Obtener la distancia desde el centro (0.5, 0.5)
	float dist = distance(UV, vec2(0.5, 0.5));
	
	// 2. Crear la máscara de viñeta
	// El centro será 0 (sin blur) y los bordes 1 (máximo blur)
	float mask = smoothstep(radius, radius + softness, dist);
	
	// 3. Leer la textura de la pantalla con el desenfoque aplicado
	// textureLod permite desenfocar usando los niveles de mipmap
	vec4 color = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount * mask);
	
	// 4. Salida final
	COLOR = color;
}