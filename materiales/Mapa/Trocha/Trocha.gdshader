shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// =============================================================================
// CAPA BASE: TEXTURAS PBR DE TIERRA Y RELIEVE
// =============================================================================
group_uniforms TEXTURAS_BASE;
uniform sampler2D textura_tierra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_rugosidad : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_relieve : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_piedras : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_piedras_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_maleza : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 escala_uv = vec2(0.25, 0.25);
uniform vec2 escala_piedras_uv = vec2(0.35, 0.35);
uniform float fuerza_normal : hint_range(0.0, 4.0) = 2.4;

// =============================================================================
// HUELLAS DE VEHICULOS / ZANJAS (HUELLONES)
// =============================================================================
group_uniforms ZANJAS_HUELLAS;
uniform bool activar_huellones = true;
// Rota la orientacion de la trocha 90 grados (intercambia horizontal y vertical)
uniform bool rotar_camino_90 = true;
// Modo automatico para segmentos de via procedurales del Editor de Mapas
uniform bool modo_via_procedural = false;
// Desfase para centrar las huellas si la malla esta corrida
uniform float desfase_lateral : hint_range(-0.5, 0.5) = 0.0;
// Separacion lateral entre las dos rodadas de neumaticos
uniform float separacion_huellas : hint_range(0.1, 0.8) = 0.45;
// Ancho de cada surco de llanta
uniform float ancho_rodada : hint_range(0.04, 0.35) = 0.16;
// Profundidad visual del surco donde se compacta la tierra
uniform float profundidad_huellas : hint_range(0.0, 1.0) = 0.70;
// Donde pasan las llantas, la tierra se aplasta y se vuelve mas lisa y oscura
uniform float compactacion_huellas : hint_range(0.0, 1.0) = 0.65;
// Ondulacion y curva natural del camino para que las huellas no sean rectas
uniform float meandro_huellas : hint_range(0.0, 0.15) = 0.04;
// Intensidad del labrado de llanta de camion/tractor impreso en el barro
uniform float fuerza_labrado_llantas : hint_range(0.0, 1.0) = 0.78;
// Camellon central elevado con cascajo y pasto ralo entre las dos rodadas
uniform bool activar_camellon_central = true;

// =============================================================================
// BARRO, LODO Y ARCILLA
// =============================================================================
group_uniforms BARRO_Y_LODO;
uniform vec4 color_tierra_seca : source_color = vec4(0.56, 0.46, 0.34, 1.0);
uniform vec4 color_barro_humedo : source_color = vec4(0.28, 0.18, 0.11, 1.0);
// Cantidad de barro espeso y revuelto
uniform float cantidad_barro : hint_range(0.0, 1.0) = 0.28;
uniform float escala_manchas_barro : hint_range(0.01, 0.3) = 0.04;
uniform float rugosidad_tierra_seca : hint_range(0.0, 1.0) = 0.92;
uniform float rugosidad_barro : hint_range(0.0, 1.0) = 0.32;

// =============================================================================
// CHARCOS Y AGUA ENLODADA
// =============================================================================
group_uniforms CHARCOS_AGUA;
// Nivel de acumulacion de agua en las partes bajas y zanjas
uniform float nivel_charcos : hint_range(0.0, 1.0) = 0.32;
// Color del agua turbia / chocolatosa tipica de trocha
uniform vec4 color_agua_charco : source_color = vec4(0.24, 0.18, 0.12, 1.0);
uniform float turbidez_agua : hint_range(0.0, 1.0) = 0.85;

// =============================================================================
// HUMEDAD Y CLIMA
// =============================================================================
group_uniforms HUMEDAD_CLIMA;
// 0 = Trocha seca polvorienta, 1 = Barrizal empapado resbaladizo
uniform float humedad : hint_range(0.0, 1.0) = 0.35;

// =============================================================================
// PIEDRAS, CASCAJO Y BARRANCOS
// =============================================================================
group_uniforms PIEDRAS_CASCAJO;
uniform float cantidad_piedras : hint_range(0.0, 1.0) = 0.48;
uniform float escala_piedras : hint_range(0.01, 0.5) = 0.08;
uniform float rugosidad_piedras : hint_range(0.0, 1.0) = 0.82;

// =============================================================================
// MALEZA Y ORILLAS
// =============================================================================
group_uniforms MALEZA_ORILLAS;
uniform bool activar_maleza_bordes = true;
uniform vec4 color_maleza : source_color = vec4(0.48, 0.56, 0.24, 1.0);
uniform float ancho_maleza : hint_range(0.0, 0.4) = 0.16;

// =============================================================================
// CONFIGURACION Y DISTANCIA
// =============================================================================
group_uniforms CONFIGURACION;
uniform bool usar_coordenadas_mundo = false;
uniform float distancia_detalle : hint_range(1.0, 100.0) = 25.0;
uniform float distancia_desvanecido : hint_range(10.0, 300.0) = 100.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_uv = UV;
}

// Funciones de ruido procedural rapido para movil y escritorio
float hash_trocha(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float ruido_suave(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_trocha(i + vec2(0.0, 0.0)), hash_trocha(i + vec2(1.0, 0.0)), u.x),
	           mix(hash_trocha(i + vec2(0.0, 1.0)), hash_trocha(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm_trocha(vec2 p) {
	float t = ruido_suave(p) * 0.55;
	t += ruido_suave(p * 2.3) * 0.30;
	t += ruido_suave(p * 5.1) * 0.15;
	return t;
}

vec3 mezclar_normales_rnm(vec3 n1, vec3 n2, float peso) {
	vec3 a = n1 * 2.0 - 1.0;
	vec3 b = mix(vec3(0.0, 0.0, 1.0), n2 * 2.0 - 1.0, clamp(peso, 0.0, 1.0));
	vec3 r = normalize(vec3(a.xy + b.xy, a.z * b.z));
	return r * 0.5 + 0.5;
}

void fragment() {
	float cam_dist = length(VERTEX);
	float lod_cercano = 1.0 - smoothstep(distancia_detalle * 0.7, distancia_desvanecido, cam_dist);

	// Orientacion de las coordenadas del camino (soporta mallas fijas y vias curvas del RoadGenerator)
	bool rotar_efectivo = rotar_camino_90 && !modo_via_procedural;
	vec2 uv_camino = rotar_efectivo ? vec2(v_uv.y, v_uv.x) : v_uv;
	float eje_lateral = uv_camino.x + desfase_lateral; // 0.0 = borde izq, 0.5 = centro, 1.0 = borde der
	float eje_longitudinal = uv_camino.y; // Avance a lo largo de la via

	// Coordenadas de texturizado multi-escala (evita repeticion visible)
	vec2 coords_base = usar_coordenadas_mundo ? v_world_pos.xz : (modo_via_procedural ? vec2(eje_lateral * 8.0, eje_longitudinal * 8.0) : uv_camino);
	vec2 uv_tierra = coords_base * escala_uv;
	vec2 uv_rocas = coords_base * escala_piedras_uv;

	// 1. Texturas base de tierra, micro-variacion y relieve
	vec4 col_tierra = texture(textura_tierra, uv_tierra);
	vec4 col_tierra_macro = texture(textura_tierra, uv_tierra * 0.31 + vec2(0.43, 0.71));
	vec3 norm_tierra = texture(textura_normal, uv_tierra).rgb;
	float rough_tex = texture(textura_rugosidad, uv_tierra).r;
	float relieve_tex = texture(textura_relieve, uv_tierra).r;

	float variacion_macro = fbm_trocha(v_world_pos.xz * 0.045);
	vec3 tierra_combinada = mix(col_tierra.rgb, col_tierra_macro.rgb, 0.40);
	vec3 final_albedo = mix(color_tierra_seca.rgb, tierra_combinada, 0.82);
	final_albedo *= (0.90 + 0.20 * variacion_macro);

	float final_roughness = mix(rugosidad_tierra_seca, rough_tex, 0.65);
	vec3 final_normal = norm_tierra;
	float final_specular = 0.35;
	float normal_depth = fuerza_normal;
	float ao_acumulado = 1.0;

	// 2. Calculo de zanjas / huellones 3D + camellon de barro desplazado + labrado de llanta
	float factor_huella = 0.0;
	float factor_reborde_barro = 0.0;
	float factor_camellon_central = 0.0;

	if (activar_huellones) {
		// Ondulacion suave y organica a baja frecuencia (no oscila cada 8 metros)
		float curva = 0.0;
		if (modo_via_procedural) {
			curva = (ruido_suave(vec2(eje_longitudinal * 0.45, 7.31)) - 0.5) * meandro_huellas;
			curva += (ruido_suave(v_world_pos.xz * 0.025) - 0.5) * (meandro_huellas * 0.5);
		} else {
			curva = (sin(eje_longitudinal * 1.8) + cos(eje_longitudinal * 3.6) * 0.35) * meandro_huellas;
			curva += (ruido_suave(v_world_pos.xz * 0.08) - 0.5) * (meandro_huellas * 0.5);
		}

		float centro_izq = (0.5 - separacion_huellas * 0.5) + curva;
		float centro_der = (0.5 + separacion_huellas * 0.5) + curva;

		float delta_izq = eje_lateral - centro_izq;
		float delta_der = eje_lateral - centro_der;
		bool es_carril_izq = abs(delta_izq) < abs(delta_der);
		float delta_carril = es_carril_izq ? delta_izq : delta_der;
		float dist_min = abs(delta_carril);

		// Perfil de la zanja hundida y rebordes laterales de barro empujado por el peso del camion
		float t_zanja = clamp(dist_min / max(ancho_rodada, 0.02), 0.0, 1.0);
		float perfil_zanja = 1.0 - (t_zanja * t_zanja * (3.0 - 2.0 * t_zanja));
		factor_huella = clamp(perfil_zanja * profundidad_huellas, 0.0, 1.0);

		// Camellon de lodo desplazado justo a los lados de cada huella
		float dist_reborde = abs(dist_min - ancho_rodada * 1.05);
		factor_reborde_barro = exp(-pow(dist_reborde / max(ancho_rodada * 0.35, 0.015), 2.0)) * profundidad_huellas * 0.55;

		// Camellon central entre las dos huellas (donde crece pasto ralo y se acumula cascajo)
		float dist_centro_via = abs(eje_lateral - (0.5 + curva));
		float ancho_centro = max((separacion_huellas * 0.5) - ancho_rodada * 0.75, 0.04);
		if (activar_camellon_central) {
			factor_camellon_central = (1.0 - smoothstep(0.0, ancho_centro, dist_centro_via)) * (1.0 - factor_huella);
		}

		// Labrado de neumatico pesado (tacos en espina de pescado / chevron) dentro del surco
		float signo_chevron = es_carril_izq ? 1.0 : -1.0;
		float escala_lon_taco = modo_via_procedural ? 38.0 : 75.0;
		float fase_taco = eje_longitudinal * escala_lon_taco + abs(delta_carril / max(ancho_rodada, 0.02)) * 2.8 * signo_chevron;
		float onda_taco = sin(fase_taco);
		float labrado = smoothstep(-0.25, 0.65, onda_taco) * factor_huella * (1.0 - pow(t_zanja, 2.0)) * fuerza_labrado_llantas * lod_cercano;

		// Perturbacion 3D analitica del Normal Map para dar volumen real a las paredes de la zanja y al labrado
		float pendiente_lat = sign(delta_carril) * (5.5 * t_zanja * (1.0 - t_zanja)) * profundidad_huellas * 0.85;
		// Reborde externo invierte la pendiente en la cresta del barro
		pendiente_lat -= sign(delta_carril) * (dist_min - ancho_rodada * 1.05) * factor_reborde_barro * 7.0;
		float pendiente_lon = cos(fase_taco) * factor_huella * fuerza_labrado_llantas * 0.35 * lod_cercano;

		vec2 grad_uv = rotar_efectivo ? vec2(pendiente_lon, pendiente_lat) : vec2(pendiente_lat, pendiente_lon);
		vec3 normal_huellon = normalize(vec3(-grad_uv.x, -grad_uv.y, 1.0)) * 0.5 + 0.5;
		final_normal = mezclar_normales_rnm(final_normal, normal_huellon, clamp(factor_huella + factor_reborde_barro, 0.0, 1.0));

		// Compactacion, oscurecimiento por humedad retenida y contraste de tacos de llanta
		if (factor_huella > 0.01) {
			float oscurecer = mix(1.0, 0.74, factor_huella * compactacion_huellas);
			oscurecer *= (0.92 + 0.14 * labrado);
			final_albedo *= oscurecer;
			final_roughness = mix(final_roughness, 0.32 + 0.16 * labrado, factor_huella * compactacion_huellas);
			final_specular = mix(final_specular, 0.60, factor_huella * compactacion_huellas);
			ao_acumulado *= (1.0 - factor_huella * 0.32 - (1.0 - labrado) * factor_huella * 0.10);
		}
		if (factor_reborde_barro > 0.01) {
			final_albedo = mix(final_albedo, color_barro_humedo.rgb * 1.15, factor_reborde_barro * 0.45);
			final_roughness = mix(final_roughness, rugosidad_barro + 0.10, factor_reborde_barro * 0.5);
		}
	}

	// 3. Parches de barro, lodo espeso y arcilla (concentrado en las zanjas y no inundando todo)
	float ruido_barro = fbm_trocha(v_world_pos.xz * escala_manchas_barro);
	float factor_barro = smoothstep(1.0 - cantidad_barro, 1.0, ruido_barro * 0.75 + factor_huella * 0.45 + factor_reborde_barro * 0.25);
	factor_barro = clamp(factor_barro * (0.35 + humedad * 0.65), 0.0, 1.0);

	if (factor_barro > 0.01) {
		vec3 barro_vivo = mix(color_barro_humedo.rgb, color_barro_humedo.rgb * 0.80, factor_huella * 0.5);
		final_albedo = mix(final_albedo, barro_vivo, factor_barro * 0.65);
		final_roughness = mix(final_roughness, rugosidad_barro, factor_barro * 0.7);
		final_specular = mix(final_specular, 0.65, factor_barro * 0.55);
	}

	// 4. Piedras, recebo y cascajo suelto (con su propio mapa normal 3D)
	if (cantidad_piedras > 0.01) {
		vec4 col_roca = texture(textura_piedras, uv_rocas);
		vec3 norm_roca = texture(textura_piedras_normal, uv_rocas).rgb;
		float n_piedras = fbm_trocha(v_world_pos.xz * escala_piedras);
		// El cascajo aflora mas en el camellon central y en los hombros que en el fondo lodoso de la huella
		float sesgo_ubicacion = (1.0 - factor_huella * 0.45) + factor_camellon_central * 0.45;
		float mascara_piedras = smoothstep(1.0 - cantidad_piedras * sesgo_ubicacion, 1.0, n_piedras * 0.60 + col_roca.r * 0.60);
		if (mascara_piedras > 0.01) {
			final_albedo = mix(final_albedo, col_roca.rgb * 1.10, mascara_piedras * 0.85);
			final_roughness = mix(final_roughness, rugosidad_piedras, mascara_piedras);
			final_normal = mezclar_normales_rnm(final_normal, norm_roca, mascara_piedras * 0.85);
			ao_acumulado *= (1.0 - mascara_piedras * 0.14);
		}
	}

	// 5. Maleza en las orillas y pasto ralo en el camellon central de la trocha
	if (activar_maleza_bordes) {
		float dist_borde = clamp(min(eje_lateral, 1.0 - eje_lateral), 0.0, 0.5);
		float n_maleza = (fbm_trocha(v_world_pos.xz * 0.15) - 0.35) * 0.12;
		float mascara_orilla = 1.0 - smoothstep(0.0, max(ancho_maleza + n_maleza, 0.02), dist_borde);
		// Pasto ralo en el lomo central del camino
		float mascara_centro = factor_camellon_central * smoothstep(0.38, 0.75, fbm_trocha(v_world_pos.xz * 0.20)) * 0.70;
		float mascara_maleza = clamp(max(mascara_orilla, mascara_centro) * (1.0 - factor_huella * 0.85), 0.0, 1.0);

		if (mascara_maleza > 0.01) {
			vec3 tex_pasto = texture(textura_maleza, uv_tierra * 1.25).rgb;
			vec3 verde_natural = mix(color_maleza.rgb, tex_pasto * color_maleza.rgb * 2.2, 0.60);
			verde_natural *= (0.85 + 0.30 * variacion_macro);
			final_albedo = mix(final_albedo, verde_natural, mascara_maleza * 0.88);
			final_roughness = mix(final_roughness, 0.78, mascara_maleza);
			final_specular = mix(final_specular, 0.25, mascara_maleza);
		}
	}

	// 6. Charcos de agua turbia (solo en depresiones ocasionales del terreno a gran escala, no en bucle)
	if (nivel_charcos > 0.01 && humedad > 0.15) {
		float ruido_baches = fbm_trocha(v_world_pos.xz * 0.032);
		float depresion = smoothstep(0.60, 0.85, ruido_baches);
		float cuenca = factor_huella * 0.75 * depresion + (1.0 - relieve_tex) * 0.15 * factor_huella - factor_camellon_central * 0.45;

		float agua_disponible = clamp(humedad * nivel_charcos * 1.5, 0.0, 1.0);
		float umbral_agua = 1.0 - agua_disponible;

		// Aureola de tierra empapada alrededor del charco
		float aureola_humeda = smoothstep(umbral_agua - 0.12, umbral_agua, cuenca) * clamp(agua_disponible * 1.8, 0.0, 1.0);
		if (aureola_humeda > 0.01) {
			final_albedo *= mix(1.0, 0.62, aureola_humeda);
			final_roughness = mix(final_roughness, 0.20, aureola_humeda * 0.70);
		}

		float mascara_charco = smoothstep(umbral_agua, umbral_agua + 0.07, cuenca);
		if (mascara_charco > 0.01) {
			// Profundidad del charco (bordes semitransparentes, centro chocolatoso opaco)
			float prof_charco = smoothstep(umbral_agua, 1.0, cuenca);
			vec3 agua_col = mix(color_agua_charco.rgb * 1.15, color_agua_charco.rgb * 0.82, prof_charco);
			final_albedo = mix(final_albedo, agua_col, mascara_charco * clamp(turbidez_agua + prof_charco * 0.15, 0.0, 0.95));
			final_roughness = mix(final_roughness, 0.03, mascara_charco);
			final_specular = mix(final_specular, 0.95, mascara_charco);

			// Micro-ondas de brisa en la superficie del charco
			vec2 p_onda = v_world_pos.xz * 3.5;
			float onda_x = cos(p_onda.x * 2.1 + TIME * 1.2 + p_onda.y) * 0.012;
			float onda_y = sin(p_onda.y * 2.5 - TIME * 1.0 + p_onda.x) * 0.012;
			vec3 normal_agua = normalize(vec3(onda_x, onda_y, 1.0)) * 0.5 + 0.5;
			final_normal = mix(final_normal, normal_agua, mascara_charco * 0.95);
			ao_acumulado = mix(ao_acumulado, 1.0, mascara_charco * 0.8);
		}
	}

	// 7. Humedad general del clima
	if (humedad > 0.01) {
		final_albedo *= mix(1.0, 0.72, humedad);
		final_roughness = mix(final_roughness, final_roughness * 0.42 + 0.04, humedad);
		final_specular = mix(final_specular, 0.82, humedad * 0.65);
	}

	// 8. Optimizacion de distancia (LOD)
	float fade = 1.0 - smoothstep(distancia_detalle, distancia_desvanecido, cam_dist);
	normal_depth *= mix(0.35, 1.0, fade);

	// Salida PBR
	ALBEDO = final_albedo;
	ROUGHNESS = clamp(final_roughness, 0.02, 1.0);
	METALLIC = 0.0;
	SPECULAR = clamp(final_specular, 0.0, 1.0);
	NORMAL_MAP = final_normal;
	NORMAL_MAP_DEPTH = normal_depth;
	AO = clamp(ao_acumulado, 0.25, 1.0);
}
