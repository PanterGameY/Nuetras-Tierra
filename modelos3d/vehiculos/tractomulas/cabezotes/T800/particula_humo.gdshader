shader_type spatial;
// blend_mix        – transparencia alfa estándar (humo semitransparente)
// unshaded         – iluminación volumétrica analítica integrada (rápida en móvil/PC)
// depth_draw_never – sin escritura al z-buffer (evita cortar otras partículas)
// cull_disabled    – ambas caras visibles (billboard siempre enfrenta cámara)
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;

// ─── Parámetros controlados desde GDScript ───────────────────────────────────
uniform float velocidad_turbulencia : hint_range(0.0, 4.0, 0.01) = 0.65;
uniform float escala_ruido : hint_range(0.5, 8.0, 0.05) = 3.2;
uniform float deformacion : hint_range(0.0, 0.5, 0.005) = 0.24;
uniform float dureza_borde : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float contraste_detalle : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float suavizado_borde : hint_range(0.05, 0.5, 0.005) = 0.42;

varying float v_seed;
varying float v_rot;

// ─── Helpers de ruido FBM optimizado (3 octavas) ──────────────────────────────
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
			dot(_hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(_hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(_hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float _fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 3; i++) {
		v += a * _vnoise(p);
		p  = p * 2.07 + vec2(5.2, 1.3);
		a *= 0.48;
	}
	return v;
}

// ─── Billboard preservando rotación y semilla por partícula ───────────────────
void vertex() {
	v_seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 19.3;
	v_rot = atan(MODEL_MATRIX[0].y, MODEL_MATRIX[0].x);

	mat4 mat_world = mat4(
		normalize(INV_VIEW_MATRIX[0]) * length(MODEL_MATRIX[0].xyz),
		normalize(INV_VIEW_MATRIX[1]) * length(MODEL_MATRIX[1].xyz),
		normalize(INV_VIEW_MATRIX[2]) * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
}

// ─── Fragmento ultra-suave sin bordes circulares ──────────────────────────────
void fragment() {
	vec2 uv_raw = UV - 0.5;
	float r_box = length(uv_raw);
	if (r_box >= 0.495) {
		discard;
	}

	float c = cos(v_rot);
	float s = sin(v_rot);
	vec2 uv = vec2(c * uv_raw.x - s * uv_raw.y, s * uv_raw.x + c * uv_raw.y);

	float t = TIME * velocidad_turbulencia + v_seed;

	// Domain warping orgánico para romper por completo la forma circular
	vec2 q = vec2(
		_fbm3(uv * escala_ruido + vec2( t * 0.32,  t * 0.14)),
		_fbm3(uv * escala_ruido + vec2(-t * 0.21,  t * 0.39) + vec2(3.7, 1.9))
	);
	float n_main = _fbm3(uv * (escala_ruido * 1.15) + q * (1.1 + deformacion * 3.2) + vec2(v_seed * 0.4, -t * 0.16));
	float density = clamp(n_main * 0.5 + 0.5, 0.0, 1.0);

	// Caída gaussiana suave desde el centro (0.0) hasta el borde (0.5), sin disco sólido
	float r_norm = clamp(r_box * 2.0, 0.0, 1.0);
	float soft_gauss = exp(-r_norm * r_norm * mix(3.8, 2.4, dureza_borde)) * (1.0 - smoothstep(0.68, 1.0, r_norm));

	// El ruido esculpe la silueta para que parezca humo irregular y nunca una esfera
	float life_alpha = COLOR.a;
	float erosion_min = mix(0.28, 0.04, life_alpha);
	float cloud = soft_gauss * smoothstep(erosion_min, 0.88, density * 0.78 + soft_gauss * 0.42);
	float alpha = cloud * life_alpha;
	if (alpha < 0.005) {
		discard;
	}

	// Sombreado volumétrico sutil basado en altura y densidad (sin aro brillante en el borde)
	float top_light = clamp(0.5 - uv_raw.y * 0.95 + (density - 0.5) * 0.65, 0.0, 1.0);
	float shade = mix(1.0 - contraste_detalle * 0.65, 1.0 + contraste_detalle * 0.65, top_light);

	ALBEDO = clamp(COLOR.rgb * shade, vec3(0.0), vec3(1.0));
	ALPHA = clamp(alpha, 0.0, 0.88);
}
