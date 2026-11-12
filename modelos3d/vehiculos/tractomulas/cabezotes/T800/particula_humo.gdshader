shader_type spatial;
// blend_mix        – transparencia alfa estándar (humo semitransparente)
// unshaded         – sin iluminación PBR (el humo no recibe luz directa)
// depth_draw_never – sin escritura al z-buffer (evita cortar otras partículas)
// cull_disabled    – ambas caras visibles (billboard siempre enfrenta cámara)
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;

// ─── Parámetros controlados desde GDScript ───────────────────────────────────
// Todos estos valores se setean via material.set_shader_parameter() en humo.gd

/// Velocidad de animación interna del ruido (turbulencia). 0 = estático.
uniform float velocidad_turbulencia : hint_range(0.0, 4.0, 0.01) = 0.55;

/// Escala del ruido: valores altos = nubes más finas y detalladas.
uniform float escala_ruido : hint_range(0.5, 8.0, 0.05) = 3.2;

/// Cuánto se deforma el dominio del ruido (volumen/esponjosidad).
uniform float deformacion : hint_range(0.0, 0.5, 0.005) = 0.18;

/// Radio interior sólido del penacho (0 = difuso, 1 = muy sólido al centro).
uniform float dureza_borde : hint_range(0.0, 1.0, 0.01) = 0.22;

/// Variación de brillo interna (detalle de volumen).
uniform float contraste_detalle : hint_range(0.0, 1.0, 0.01) = 0.18;

/// Suavizado de los bordes exteriores (0 = borde duro, 1 = muy difuminado).
uniform float suavizado_borde : hint_range(0.05, 0.5, 0.005) = 0.28;

// ─── Helpers de ruido FBM ────────────────────────────────────────────────────

vec2 _hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float _vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(dot(_hash2(i),             f),
			dot(_hash2(i + vec2(1,0)), f - vec2(1,0)), u.x),
		mix(dot(_hash2(i + vec2(0,1)), f - vec2(0,1)),
			dot(_hash2(i + vec2(1,1)), f - vec2(1,1)), u.x), u.y);
}

// FBM de 4 octavas — la base del aspecto voluminoso del humo
float _fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * _vnoise(p);
		p  = p * 2.13 + vec2(5.2, 1.3);
		a *= 0.5;
	}
	return v;
}

// ─── Billboard ─────────────────────────────────────────────────────────────

void vertex() {
	mat4 mat_world = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0].xyz),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1].xyz),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
}

// ─── Fragmento ───────────────────────────────────────────────────────────────

void fragment() {
	vec2  uv = UV - 0.5;                          // Centro en (0,0)
	float t  = TIME * velocidad_turbulencia;

	// Domain warping: dos capas de FBM desplazan el dominio antes del muestreo
	vec2 q = vec2(
		_fbm(uv * escala_ruido + vec2( t * 0.38,  t * 0.12)),
		_fbm(uv * escala_ruido + vec2(-t * 0.24,  t * 0.47))
	);
	vec2 r = vec2(
		_fbm(uv * escala_ruido + q + vec2(1.7, 9.2) + t * 0.15),
		_fbm(uv * escala_ruido + q + vec2(8.3, 2.8) - t * 0.18)
	);

	vec2  distorted = uv + r * deformacion;
	float dist      = length(distorted);

	// Borde suave exterior (smoothstep controlado por dureza_borde y suavizado_borde)
	float inner = 0.5 * (1.0 - dureza_borde);     // Radio hasta donde es opaco
	float outer = inner + suavizado_borde;         // Radio donde desaparece
	float alpha = 1.0 - smoothstep(inner, outer, dist);

	// Detalle de volumen: varía el brillo del interior para simular profundidad
	float detail = _fbm(uv * (escala_ruido * 1.3) + vec2(t * 0.18, -t * 0.13)) * 0.5 + 0.5;
	vec3  color  = COLOR.rgb * (1.0 - contraste_detalle + detail * contraste_detalle * 2.0);

	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	ALPHA  = COLOR.a * clamp(alpha, 0.0, 1.0);
}
