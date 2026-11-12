shader_type canvas_item;

// Shader de contorno/borde exclusivo para volante táctil (Godot 4 Mobile / Forward+)
// Extrae únicamente los bordes limpios y nítidos del volante (aro exterior, aro interior, rayos y centro),
// haciendo que todo el interior negro sea 100% transparente.

uniform float rotacion : hint_range(-6.28318, 6.28318) = 0.0;
uniform vec4  borde_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float borde_grosor : hint_range(1.0, 8.0) = 3.0;
uniform float borde_brillo : hint_range(1.0, 3.0) = 1.35;
uniform float interior_alpha : hint_range(0.0, 1.0) = 0.0; // 0.0 = Solo bordes (interior transparente)
uniform vec4  interior_color : source_color = vec4(0.06, 0.07, 0.09, 0.0);

// Parámetros de compatibilidad heredada
uniform vec4  wheel_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4  rim_color : source_color = vec4(1.0, 0.45, 0.0, 0.85);
uniform float target_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float mask_from_texture : hint_range(0.0, 1.0) = 1.0;
uniform float black_threshold : hint_range(0.0, 1.0) = 0.12;
uniform float outline_pixels : hint_range(0.0, 12.0) = 3.0;
uniform float outline_softness : hint_range(0.0, 8.0) = 1.5;
uniform float outline_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4  outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// 1. Centrar y rotar coordenadas UV alrededor del centro (0.5, 0.5)
	vec2 uvc = UV - vec2(0.5);
	float sa = sin(rotacion);
	float ca = cos(rotacion);
	vec2 rot_uv = vec2(ca * uvc.x + sa * uvc.y, -sa * uvc.x + ca * uvc.y) + vec2(0.5);

	// 2. Prevenir repetición en las esquinas al rotar
	if (rot_uv.x < 0.0 || rot_uv.x > 1.0 || rot_uv.y < 0.0 || rot_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		// Vector de desplazamiento en píxeles basado en TEXTURE_PIXEL_SIZE
		vec2 px = TEXTURE_PIXEL_SIZE * borde_grosor;

		// Muestreo central
		float a_center = texture(TEXTURE, rot_uv).a;

		// Muestreos en cruz y diagonales (8 vecinos)
		float a0 = texture(TEXTURE, rot_uv + vec2(-px.x, 0.0)).a;
		float a1 = texture(TEXTURE, rot_uv + vec2( px.x, 0.0)).a;
		float a2 = texture(TEXTURE, rot_uv + vec2(0.0, -px.y)).a;
		float a3 = texture(TEXTURE, rot_uv + vec2(0.0,  px.y)).a;

		float a4 = texture(TEXTURE, rot_uv + vec2(-px.x * 0.7071, -px.y * 0.7071)).a;
		float a5 = texture(TEXTURE, rot_uv + vec2( px.x * 0.7071, -px.y * 0.7071)).a;
		float a6 = texture(TEXTURE, rot_uv + vec2(-px.x * 0.7071,  px.y * 0.7071)).a;
		float a7 = texture(TEXTURE, rot_uv + vec2( px.x * 0.7071,  px.y * 0.7071)).a;

		float max_a = max(a_center, max(max(max(a0, a1), max(a2, a3)), max(max(a4, a5), max(a6, a7))));
		float min_a = min(a_center, min(min(min(a0, a1), min(a2, a3)), min(min(a4, a5), min(a6, a7))));

		// Gradiente morfológico: 1.0 en los bordes, 0.0 en el interior y exterior
		float borde = clamp((max_a - min_a) * borde_brillo, 0.0, 1.0);

		// Mezcla entre fondo interior (transparente por defecto) y el borde
		vec4 color_final = mix(
			vec4(interior_color.rgb, interior_alpha * a_center),
			borde_color,
			borde
		);

		// Modular con el alpha del nodo (self_modulate / fade de volante.gd)
		color_final.a *= COLOR.a * target_alpha;
		COLOR = color_final;
	}
}
