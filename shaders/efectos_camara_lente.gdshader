// ═══════════════════════════════════════════════════════════════════════════════
// EFECTOS DE CÁMARA: LENS FLARE Y LLUVIA EN LENTE - NUESTRA TIERRA 2.0
// ═══════════════════════════════════════════════════════════════════════════════
// 1. Lens Flare Cinematográfico: Corona solar, raya anamórfica horizontal,
//    rayos de sol (god rays) y fantasmas ópticos concéntricos al mirar al sol.
// 2. Deslumbramiento / Adaptación de ojo: Aumento dinámico de exposición.
// 3. Gotas de Lluvia en el Cristal: Refracción física de la imagen en pantalla
//    y escurridos animados que caen por el lente al llover.
// ═══════════════════════════════════════════════════════════════════════════════
shader_type spatial;
render_mode blend_mix, depth_test_disabled, cull_disabled, unshaded, fog_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

group_uniforms lens_flare_solar;
uniform bool lens_flare_activo = true;
// Posición 2D del sol en pantalla (UV de 0.0 a 1.0)
uniform vec2 sol_screen_uv = vec2(0.5, 0.5);
// Intensidad de visibilidad (1.0 = sol de frente, 0.0 = fuera de cámara / tapado)
uniform float sol_intensidad : hint_range(0.0, 1.0, 0.01) = 0.0;
// Color del destello solar
uniform vec4 sol_color_flare : source_color = vec4(1.0, 0.88, 0.58, 1.0);
uniform float flare_escala : hint_range(0.2, 3.0, 0.1) = 1.0;

group_uniforms lluvia_en_lente;
// Nivel de lluvia en el cristal de la cámara (0.0 = seco, 1.0 = empapado)
uniform float nivel_lluvia_lente : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float escala_gotas_lente : hint_range(10.0, 80.0, 2.0) = 36.0;
uniform float distorsion_gotas : hint_range(0.005, 0.15, 0.005) = 0.045;
uniform float velocidad_escurrido_lente : hint_range(0.0, 1.0, 0.05) = 0.30;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Cálculo de gotas y escurridos en el cristal de la lente
vec2 calcular_distorsion_gotas_lente(vec2 uv, float t) {
	vec2 st = uv * escala_gotas_lente;
	vec2 id = floor(st);
	vec2 f = fract(st);

	float min_dist = 1.0;
	vec2 min_pt = vec2(0.0);

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 vecino = vec2(float(x), float(y));
			vec2 p = hash22(id + vecino);
			if (p.x > 0.38) {
				vec2 pt_pos = vecino + vec2(0.25 + 0.5 * p.x, 0.25 + 0.5 * p.y);
				// Escurrido lento con variación de fase
				pt_pos.y += fract(t * (0.4 + 0.6 * p.y));
				vec2 diff = pt_pos - f;
				float d = length(diff);
				if (d < min_dist) {
					min_dist = d;
					min_pt = diff;
				}
			}
		}
	}

	float radio = 0.26;
	if (min_dist < radio) {
		float z = sqrt(max(0.0, 1.0 - (min_dist / radio) * (min_dist / radio)));
		float len_pt = length(min_pt);
		vec2 dir_pt = len_pt > 0.0001 ? min_pt / len_pt : vec2(0.0);
		return dir_pt * (1.0 - z) * distorsion_gotas;
	}
	return vec2(0.0);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;

	// 1. REFRACCIÓN DE AGUA EN LA LENTE
	vec2 offset_lluvia = vec2(0.0);
	float mascara_gota = 0.0;
	if (nivel_lluvia_lente > 0.01) {
		offset_lluvia = calcular_distorsion_gotas_lente(uv, TIME * velocidad_escurrido_lente) * nivel_lluvia_lente;
		mascara_gota = length(offset_lluvia) > 0.001 ? 1.0 : 0.0;
	}

	// Muestra de la escena con refracción
	vec4 scene_color = texture(screen_texture, uv + offset_lluvia);

	// Micro-brillo especular en los bordes curvos de las gotas
	if (mascara_gota > 0.5) {
		scene_color.rgb += vec3(0.09 * nivel_lluvia_lente);
	}

	// 2. LENS FLARE CINEMATOGRÁFICO CUANDO MIRAS AL SOL
	vec3 flare_total = vec3(0.0);
	if (lens_flare_activo && sol_intensidad > 0.005) {
		vec2 delta_sol = (uv - sol_screen_uv);
		delta_sol.x *= aspect; // Corrección anamórfica de pantalla
		float dist_sol = length(delta_sol);

		// A. Corona y halo solar cegador
		float corona = pow(max(0.0, 1.0 - dist_sol * 1.8), 3.5) * 2.2;
		float halo_grande = pow(max(0.0, 1.0 - dist_sol * 0.75), 2.2) * 0.50;

		// B. Raya anamórfica horizontal (estilo lente cinematográfica de automotriz)
		float streak_y = abs(uv.y - sol_screen_uv.y);
		float streak_x = abs(uv.x - sol_screen_uv.x);
		float anamorfico = pow(max(0.0, 1.0 - streak_y * 38.0), 12.0) * pow(max(0.0, 1.0 - streak_x * 0.85), 2.0) * 1.8;

		// C. Rayos de sol radiales (God Rays / Starburst)
		float angulo = atan(delta_sol.y, delta_sol.x);
		float rayos = (sin(angulo * 12.0) * 0.5 + 0.5) * pow(max(0.0, 1.0 - dist_sol * 2.4), 2.8) * 0.7;

		// D. Lens Ghosts (Fantasmas de lente concéntricos hacia el centro de la pantalla)
		vec2 centro_pantalla = vec2(0.5, 0.5);
		vec2 dir_al_centro = centro_pantalla - sol_screen_uv;

		// Fantasma 1 (anillo ámbar cálido)
		vec2 g1_pos = sol_screen_uv + dir_al_centro * 0.65;
		vec2 d_g1 = (uv - g1_pos); d_g1.x *= aspect;
		float ghost1 = pow(max(0.0, 1.0 - length(d_g1) * 4.8), 3.0) * 0.40;

		// Fantasma 2 (disco azul/cian)
		vec2 g2_pos = sol_screen_uv + dir_al_centro * 1.30;
		vec2 d_g2 = (uv - g2_pos); d_g2.x *= aspect;
		float ghost2 = pow(max(0.0, 1.0 - length(d_g2) * 3.8), 2.5) * 0.28;

		// Fantasma 3 (halo violeta amplio)
		vec2 g3_pos = sol_screen_uv + dir_al_centro * 1.85;
		vec2 d_g3 = (uv - g3_pos); d_g3.x *= aspect;
		float dist_aro = abs(length(d_g3) - 0.20);
		float halo_aro = pow(max(0.0, 1.0 - dist_aro * 8.5), 3.0) * 0.25;

		// Suma de componentes cromáticas
		vec3 col_corona = sol_color_flare.rgb * (corona + halo_grande + anamorfico + rayos);
		vec3 col_fantasmas = vec3(ghost1 * 1.0 + halo_aro * 0.5, ghost1 * 0.75 + ghost2 * 0.4, ghost2 * 1.0 + halo_aro * 0.8);

		flare_total = (col_corona + col_fantasmas) * sol_intensidad * flare_escala;

		// Deslumbramiento suave de exposición al mirar directamente
		float deslumbramiento = pow(sol_intensidad, 2.5) * 0.16;
		scene_color.rgb = mix(scene_color.rgb, vec3(1.0, 0.98, 0.94), deslumbramiento);
	}

	ALBEDO = scene_color.rgb + flare_total;
	ALPHA = 1.0;
}
