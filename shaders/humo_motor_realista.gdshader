// humo_motor_realista.gdshader
// Shader volumétrico suave para humo de escape, aceleración y daño de motor.
// Totalmente configurable en color, densidad y suavizado para múltiples propósitos
// (combustión diésel, humo negro de falla mecánica o vapor blanco de radiador).
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;

// --- Parámetros de Color y Apariencia ---
uniform vec4 color_humo : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform float opacidad_maxima : hint_range(0.05, 1.0, 0.02) = 0.50;

// --- Dinámica y Textura de Remolino ---
uniform float velocidad_turbulencia : hint_range(0.0, 3.0, 0.01) = 0.50;
uniform float escala_ruido : hint_range(0.5, 8.0, 0.05) = 2.8;
uniform float deformacion : hint_range(0.0, 0.5, 0.005) = 0.18;
uniform float contraste_detalle : hint_range(0.0, 1.0, 0.01) = 0.35;

// Hash pseudoaleatorio 2D
vec2 _hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Ruido continuo interpolado suavemente
float _vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(_hash2(i),             f),
			dot(_hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(_hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(_hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Movimiento browniano fractal (fBm) de 4 octavas
float _fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amp * _vnoise(p);
		p = p * 2.13 + vec2(5.2, 1.3);
		amp *= 0.5;
	}
	return total;
}

void vertex() {
	// Billboard esférico perfecto: encarar a cámara preservando escala exacta de partículas
	mat4 mat_world = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0].xyz),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1].xyz),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
}

void fragment() {
	vec2 uv = UV - 0.5;
	float t = TIME * velocidad_turbulencia;

	// Domain warping fractal para crear volutas orgánicas fluidas
	vec2 q = vec2(
		_fbm(uv * escala_ruido + vec2( t * 0.35,  t * 0.10)),
		_fbm(uv * escala_ruido + vec2(-t * 0.22,  t * 0.40))
	);
	vec2 r = vec2(
		_fbm(uv * escala_ruido + q + vec2(1.7, 9.2) + t * 0.12),
		_fbm(uv * escala_ruido + q + vec2(8.3, 2.8) - t * 0.15)
	);

	vec2 distorsionado = uv + r * deformacion;
	float dist = length(distorsionado);

	// Caída radial suave y difusa (elimina cualquier borde duro o aspecto compacto de disco)
	float mascara_suave = smoothstep(0.48, 0.0, dist);
	mascara_suave = pow(mascara_suave, 1.35);

	// Detalle de remolinos internos
	float n = _fbm(distorsionado * (escala_ruido * 1.25) + vec2(t * 0.18, -t * 0.12));
	float densidad = mascara_suave * clamp(n * 0.65 + 0.55, 0.0, 1.0);

	// Sombreado de volumen: solo oscurece en las hendiduras, nunca clarea hacia blanco
	float sombra_interna = mix(1.0 - contraste_detalle, 1.0, clamp(n * 0.5 + 0.5, 0.0, 1.0));
	vec3 color_final = color_humo.rgb * COLOR.rgb * sombra_interna;

	float alpha_final = densidad * COLOR.a * color_humo.a * opacidad_maxima;

	ALBEDO = clamp(color_final, vec3(0.0), vec3(1.0));
	ALPHA = clamp(alpha_final, 0.0, 1.0);
}
