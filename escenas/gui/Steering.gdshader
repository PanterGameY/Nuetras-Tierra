shader_type canvas_item;

// Simple texture-based mask: captura negro → blanco translúcido + contorno
uniform float rotacion           : hint_range(-6.28, 6.28) = 0.0;
uniform float mask_from_texture  : hint_range(0.0, 1.0)     = 1.0;
uniform float black_threshold    : hint_range(0.0, 1.0)     = 0.12;
uniform float target_alpha       : hint_range(0.0, 1.0)     = 0.45;
uniform float outline_pixels     : hint_range(0.0, 12.0)    = 3.0;
uniform float outline_softness   : hint_range(0.0, 8.0)     = 1.5;
uniform float outline_alpha      : hint_range(0.0, 1.0)     = 1.0;
uniform vec4  outline_color      : source_color = vec4(1.0,1.0,1.0,1.0);

void fragment() {
	// Centrar y rotar la UV para muestrear la textura en la orientación del volante
	vec2 uvc = UV - 0.5;
	float sa = sin(rotacion);
	float ca = cos(rotacion);
	vec2 p = vec2(ca * uvc.x + sa * uvc.y, -sa * uvc.x + ca * uvc.y);
	vec2 tex_uv = p + vec2(0.5);

	// Muestreo principal
	vec4 tex = texture(TEXTURE, tex_uv);

	// Si la textura es transparente, o no se usa la máscara, manejar con ramas
	if (tex.a < 0.01) {
		COLOR = vec4(0.0);
	} else if (mask_from_texture < 0.5) {
		// Si no se usa la máscara, solo dibuja la textura tal cual
		COLOR = tex;
	} else {
		float lum = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
		float mask = clamp(1.0 - smoothstep(0.0, black_threshold, lum), 0.0, 1.0);

	// Tamaño aproximado de píxel en UV para muestreos vecinos
	float px = max(fwidth(tex_uv.x), fwidth(tex_uv.y));
	float delta = max(px * outline_pixels, px * 0.5);

	// Muestreos vecinos para blur rápido
	float m_up    = clamp(1.0 - smoothstep(0.0, black_threshold, dot(texture(TEXTURE, tex_uv + vec2(0.0,  delta)).rgb, vec3(0.2126,0.7152,0.0722))), 0.0, 1.0);
	float m_down  = clamp(1.0 - smoothstep(0.0, black_threshold, dot(texture(TEXTURE, tex_uv - vec2(0.0,  delta)).rgb, vec3(0.2126,0.7152,0.0722))), 0.0, 1.0);
	float m_left  = clamp(1.0 - smoothstep(0.0, black_threshold, dot(texture(TEXTURE, tex_uv - vec2(delta, 0.0)).rgb, vec3(0.2126,0.7152,0.0722))), 0.0, 1.0);
	float m_right = clamp(1.0 - smoothstep(0.0, black_threshold, dot(texture(TEXTURE, tex_uv + vec2(delta, 0.0)).rgb, vec3(0.2126,0.7152,0.0722))), 0.0, 1.0);

	float blurred = (mask + m_up + m_down + m_left + m_right) * 0.2;
	float diff = mask - blurred;
	float edge = clamp(diff / max(0.0001, px * outline_softness), 0.0, 1.0);
	edge = smoothstep(0.0, 1.0, edge);

	// Interior: mezclar hacia blanco donde hay 'negro'
	vec3 base = mix(tex.rgb, vec3(1.0), mask);
	// Añadir trazo blanco en el borde
	base = mix(base, outline_color.rgb, edge * outline_color.a);

	float interior_alpha = mix(tex.a, target_alpha, mask);
	float outline_alpha_local = outline_alpha * edge;
		float final_alpha = max(interior_alpha, outline_alpha_local);

		COLOR = vec4(clamp(base, vec3(0.0), vec3(1.0)), clamp(final_alpha, 0.0, 1.0));
	}
}
