shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// =============================================================================
// CAPA 1: CÉSPED BASE (PBR)
// =============================================================================
group_uniforms CAPA_CESPED;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_height : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(0.2, 0.2);
uniform float normal_scale : hint_range(0.0, 4.0) = 2.28;
uniform float roughness_scale : hint_range(0.0, 2.0) = 0.94;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 1.0;
// Profundidad de sombra en la raiz de las briznas para dar sensacion 3D
uniform float root_shadow_depth : hint_range(0.0, 1.0) = 0.55;
// Translucidez solar (la luz atraviesa las briznas dandoles vida)
uniform float grass_translucency : hint_range(0.0, 0.5) = 0.18;
// Sistema anti-repeticion para romper el patron cuadrado del atlas en distancias medias
uniform bool anti_tiling_enabled = true;

// =============================================================================
// CAPA 2: TIERRA Y BARRO
// =============================================================================
group_uniforms CAPA_TIERRA;
uniform bool dirt_enabled = true;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float dirt_roughness : hint_range(0.0, 1.0) = 0.95;
uniform vec2 dirt_uv_scale = vec2(0.25, 0.25);
// Cantidad de parches de tierra natural asomando entre la hierba
uniform float dirt_blend_amount : hint_range(0.0, 1.0) = 0.28;
// Tamano de los manchones de tierra en el campo
uniform float dirt_noise_scale : hint_range(0.001, 0.2) = 0.035;

// =============================================================================
// CAPA 3: ROCA Y ACANTILADOS
// =============================================================================
group_uniforms CAPA_ROCA;
uniform bool rock_enabled = true;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float rock_roughness : hint_range(0.0, 1.0) = 0.88;
uniform vec2 rock_uv_scale = vec2(0.18, 0.18);
// Inclinacion para que aparezca roca en laderas y barrancos
uniform float rock_slope_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float rock_slope_sharpness : hint_range(0.5, 10.0) = 3.5;

// =============================================================================
// BORDES EXTERIORES DEL OBJETO / ORILLA DE CARRETERA
// =============================================================================
group_uniforms BORDES_CARRETERA;
// Activa la transicion de tierra en los bordes perimetrales del objeto
uniform bool road_edge_enabled = false;
// 0 = Canal UV2 (Desenvuelto de todo el objeto), 1 = Limites locales en metros, 2 = Mascara
uniform int road_edge_source : hint_range(0, 2) = 0;
uniform sampler2D road_edge_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec2 object_size = vec2(50.0, 50.0);
uniform float road_edge_width : hint_range(0.01, 20.0) = 0.15;
uniform float road_edge_dirt_intensity : hint_range(0.0, 1.0) = 0.85;
uniform float road_edge_noise_scale : hint_range(0.01, 0.5) = 0.08;
uniform float road_edge_irregularity : hint_range(0.0, 1.0) = 0.65;
uniform float road_edge_pebbles : hint_range(0.0, 1.0) = 0.35;

// =============================================================================
// MEZCLA ORGANICA POR RELIEVE (HEIGHT-BLEND)
// =============================================================================
group_uniforms MEZCLA_ORGANICA;
// Coordenadas de mundo para mantener escala metrica perfecta en todo el terreno
uniform bool use_world_coords = true;
// La tierra se cuela entre las raices del cesped con corte nitido y natural
uniform float height_blend_sharpness : hint_range(0.01, 0.99) = 0.65;

// =============================================================================
// VARIACION DE COLOR FOTOREALISTA
// =============================================================================
group_uniforms VARIACION_COLOR;
uniform bool variation_enabled = true;
uniform float variation_strength : hint_range(0.0, 1.0) = 0.45;
uniform float variation_scale : hint_range(0.001, 0.2) = 0.025;
uniform float macro_variation_scale : hint_range(0.0005, 0.05) = 0.005;
uniform vec3 variation_tint_warm : source_color = vec3(1.10, 1.04, 0.78);
uniform vec3 variation_tint_lush : source_color = vec3(0.90, 1.05, 0.85);

// =============================================================================
// CLIMA Y CHARCOS DINAMICOS
// =============================================================================
group_uniforms CLIMA_LLUVIA;
// 0 = Seco, 1 = Lluvia/Charcos (el agua se acumula en las partes bajas del relieve)
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_depth : hint_range(0.0, 1.0) = 0.60;

// =============================================================================
// ESTADO DE SEQUIA Y ESTACIONES
// =============================================================================
group_uniforms ESTADO_SEQUIA;
// 0 = Verde natural, 1 = Verano calido, 2 = Sabana amarillenta, 3 = Seco/Marchito
uniform float grass_state : hint_range(0.0, 3.0) = 0.0;

// =============================================================================
// DESGASTE Y HUELLAS
// =============================================================================
group_uniforms DESGASTE_HUELLAS;
uniform float wear_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;

// =============================================================================
// ONDAS DE VIENTO SOBRE EL CAMPO
// =============================================================================
group_uniforms ONDAS_VIENTO;
uniform bool wind_enabled = true;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_speed : hint_range(0.0, 10.0) = 1.5;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.30;
uniform float wind_frequency : hint_range(0.0, 5.0) = 0.55;
uniform float wind_gust_strength : hint_range(0.0, 2.0) = 0.40;
uniform float wind_gust_speed : hint_range(0.0, 10.0) = 2.0;

// =============================================================================
// DISTANCIA Y CALIDAD
// =============================================================================
group_uniforms DISTANCIA_Y_CALIDAD;
uniform float detail_distance : hint_range(1.0, 100.0) = 25.0;
uniform float medium_distance : hint_range(5.0, 200.0) = 70.0;
uniform float fade_distance : hint_range(10.0, 500.0) = 140.0;
uniform int quality_level : hint_range(0, 2) = 2;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec3 v_local_pos;
varying vec2 v_uv2;
varying vec4 v_vertex_color;

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_vertex_color = COLOR;
	v_uv2 = UV2;
}

// Ruido procedural multicapa para bordes y tierra
float hash_noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_noise(i + vec2(0.0, 0.0)), hash_noise(i + vec2(1.0, 0.0)), u.x),
	           mix(hash_noise(i + vec2(0.0, 1.0)), hash_noise(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm_noise(vec2 p) {
	float total = smooth_noise(p) * 0.65;
	total += smooth_noise(p * 2.3) * 0.35;
	return total;
}

// Borde exterior del objeto
float calcular_borde_carretera(vec3 local_pos, vec2 uv2, vec3 world_pos) {
	if (!road_edge_enabled) return 0.0;

	float dist = 1.0;
	float max_w = road_edge_width;

	if (road_edge_source == 0) {
		dist = min(min(uv2.x, 1.0 - uv2.x), min(uv2.y, 1.0 - uv2.y));
	} else if (road_edge_source == 1) {
		vec2 half_size = max(vec2(0.5), object_size * 0.5);
		float dist_x = half_size.x - abs(local_pos.x);
		float dist_z = half_size.y - abs(local_pos.z);
		dist = min(dist_x, dist_z);
	} else if (road_edge_source == 2) {
		float mask = texture(road_edge_mask, uv2).r;
		return clamp(mask * road_edge_dirt_intensity, 0.0, 1.0);
	}

	float edge_n = fbm_noise(world_pos.xz * road_edge_noise_scale) * 2.0 - 1.0;
	float distorted_dist = dist + edge_n * (max_w * road_edge_irregularity);
	float edge_mask = 1.0 - smoothstep(0.0, max_w, distorted_dist);

	return clamp(edge_mask * road_edge_dirt_intensity, 0.0, 1.0);
}

void fragment() {
	float cam_dist = length(VERTEX);

	// Coordenadas base
	vec2 base_uv = use_world_coords ? v_world_pos.xz : UV;
	vec2 uv_grass = base_uv * uv_scale;
	vec2 uv_dirt = base_uv * dirt_uv_scale;
	vec2 uv_rock = base_uv * rock_uv_scale;

	// 1. Muestreo PBR de Cesped (con Anti-Tiling opcional para eliminar repeticion)
	vec4 grass_col = texture(texture_albedo, uv_grass);
	float grass_rough = texture(texture_roughness, uv_grass).r * roughness_scale;
	float grass_ao = texture(texture_ao, uv_grass).r;
	vec3 grass_norm = texture(texture_normal, uv_grass).rgb;
	float grass_h = texture(texture_height, uv_grass).r;

	if (anti_tiling_enabled && quality_level >= 1) {
		// Muestreo macro con diferente escala y angulo para romper la cuadricula
		vec2 macro_uv = uv_grass * 0.37 + vec2(0.31, 0.77);
		vec4 grass_macro = texture(texture_albedo, macro_uv);
		float noise_pattern = smooth_noise(v_world_pos.xz * 0.08);
		grass_col = mix(grass_col, grass_macro, noise_pattern * 0.35);
	}

	// 2. Profundidad 3D en la base del cesped (sombras entre briznas)
	// Las raices reciben menos luz (humus/tierra oscura bajo el pasto)
	float root_shadow = mix(1.0 - root_shadow_depth, 1.0, clamp(grass_h * 1.3, 0.0, 1.0));
	grass_col.rgb *= root_shadow;

	vec3 final_albedo = grass_col.rgb;
	float final_roughness = grass_rough;
	vec3 final_normal = grass_norm;
	float final_ao = grass_ao;
	float final_specular = 0.5;
	float current_normal_scale = normal_scale;

	// 3. Orilla de carretera y perimetro exterior
	float road_edge_factor = calcular_borde_carretera(v_local_pos, v_uv2, v_world_pos);

	// 4. Pendiente para afloramiento de rocas en lomas y cortes
	float slope = 1.0 - clamp(v_world_normal.y, 0.0, 1.0);
	float rock_factor = 0.0;
	if (rock_enabled) {
		rock_factor = clamp((slope - rock_slope_threshold) * rock_slope_sharpness, 0.0, 1.0);
		if (road_edge_pebbles > 0.001) {
			rock_factor = max(rock_factor, road_edge_factor * road_edge_pebbles);
		}
	}

	// 5. Parches organicos de tierra en el pasto
	float dirt_weight = 0.0;
	if (dirt_enabled) {
		float n_dirt = fbm_noise(v_world_pos.xz * dirt_noise_scale);
		dirt_weight = smoothstep(1.0 - dirt_blend_amount, 1.0, n_dirt);
	}

	dirt_weight = clamp(dirt_weight + road_edge_factor, 0.0, 1.0);

	if (wear_amount > 0.001) {
		float wear_sample = texture(wear_mask, UV).r;
		dirt_weight = clamp(dirt_weight + wear_sample * wear_amount, 0.0, 1.0);
	}

	// 6. Height-Blend Avanzado (Corte realista entre tierra y cesped segun el relieve de las hojas)
	float blend_factor = dirt_weight;
	if (dirt_enabled && quality_level >= 1) {
		float sharpness = max(0.01, 1.0 - height_blend_sharpness);
		float h_grass = grass_h;
		float h_dirt = 0.45; // Relieve promedio del suelo
		float w_g = (1.0 - dirt_weight) * h_grass;
		float w_d = dirt_weight * h_dirt;
		float h_diff = (w_d - w_g) / sharpness;
		blend_factor = clamp(h_diff * 0.5 + 0.5, 0.0, 1.0);
		blend_factor = mix(dirt_weight, blend_factor, height_blend_sharpness);
	}

	// 7. Mezcla de Tierra
	if (dirt_enabled && blend_factor > 0.001) {
		vec4 dirt_col = texture(dirt_albedo, uv_dirt);
		final_albedo = mix(final_albedo, dirt_col.rgb, blend_factor);
		final_roughness = mix(final_roughness, dirt_roughness, blend_factor);
		vec3 d_norm = texture(dirt_normal, uv_dirt).rgb;
		if (length(d_norm) > 0.1) {
			final_normal = mix(final_normal, d_norm, blend_factor);
		}
	}

	// 8. Mezcla de Roca en barrancos
	if (rock_enabled && rock_factor > 0.001) {
		vec4 rock_col = texture(rock_albedo, uv_rock);
		final_albedo = mix(final_albedo, rock_col.rgb, rock_factor);
		final_roughness = mix(final_roughness, rock_roughness, rock_factor);
		vec3 r_norm = texture(rock_normal, uv_rock).rgb;
		if (length(r_norm) > 0.1) {
			final_normal = mix(final_normal, r_norm, rock_factor);
		}
	}

	// =========================================================================
	// VARIACION DE COLOR MACRO (Rompe la monotonia a escala kilometrica)
	// =========================================================================
	if (variation_enabled && quality_level > 0) {
		float var_fade = 1.0 - smoothstep(detail_distance, fade_distance, cam_dist);
		if (quality_level == 1) var_fade *= 0.6;

		if (var_fade > 0.001) {
			float n_macro = fbm_noise(v_world_pos.xz * macro_variation_scale) * 2.0 - 1.0;
			float n_meso = fbm_noise(v_world_pos.xz * variation_scale) * 2.0 - 1.0;
			float combined = n_macro * 0.65 + n_meso * 0.35;
			float eff_str = variation_strength * var_fade;

			vec3 tint = mix(variation_tint_lush, variation_tint_warm, combined * 0.5 + 0.5);
			final_albedo = mix(final_albedo, final_albedo * tint, eff_str * 0.65);
			final_albedo *= (1.0 + combined * eff_str * 0.22);

			float luma = dot(final_albedo, vec3(0.299, 0.587, 0.114));
			final_albedo = mix(vec3(luma), final_albedo, 1.0 + combined * eff_str * 0.15);
		}
	}

	// =========================================================================
	// ESTADO DE SEQUIA (Transicion botanica natural)
	// =========================================================================
	if (grass_state > 0.001) {
		vec3 state_tint = vec3(1.0);
		float rough_add = 0.0;

		if (grass_state <= 1.0) {
			float t = grass_state;
			state_tint = mix(vec3(1.0, 1.0, 1.0), vec3(1.05, 1.02, 0.80), t);
			rough_add = t * 0.04;
		} else if (grass_state <= 2.0) {
			float t = grass_state - 1.0;
			state_tint = mix(vec3(1.05, 1.02, 0.80), vec3(1.22, 1.12, 0.55), t);
			rough_add = 0.04 + t * 0.08;
		} else {
			float t = clamp(grass_state - 2.0, 0.0, 1.0);
			state_tint = mix(vec3(1.22, 1.12, 0.55), vec3(0.92, 0.78, 0.50), t);
			rough_add = 0.12 + t * 0.10;
		}

		float grass_mask = (1.0 - rock_factor) * (1.0 - blend_factor * 0.7);
		final_albedo = mix(final_albedo, final_albedo * state_tint, grass_mask);
		final_roughness = clamp(final_roughness + rough_add * grass_mask, 0.0, 1.0);
	}

	// =========================================================================
	// ONDAS DE VIENTO SOBRE LA PRADERA (Brisa y luz rasante)
	// =========================================================================
	if (wind_enabled && quality_level > 0) {
		vec2 w_dir = length(wind_direction) > 0.001 ? normalize(wind_direction) : vec2(1.0, 0.0);
		float w_time = TIME * wind_speed;
		float w_phase = (v_world_pos.x * w_dir.x + v_world_pos.z * w_dir.y) * wind_frequency;
		float w_cross = (v_world_pos.x * w_dir.y - v_world_pos.z * w_dir.x) * (wind_frequency * 0.55);

		float wave = sin(w_time + w_phase + sin(w_cross * 0.8));
		if (quality_level >= 2 && wind_gust_strength > 0.0) {
			float gust = sin(TIME * wind_gust_speed + (v_world_pos.x + v_world_pos.z) * 0.22);
			wave += max(0.0, gust) * wind_gust_strength;
		}

		float wind_fade = 1.0 - smoothstep(detail_distance, medium_distance, cam_dist);
		float sheen = wave * wind_strength * 0.15 * wind_fade * (1.0 - blend_factor) * (1.0 - rock_factor);
		final_albedo += vec3(sheen);
	}

	// =========================================================================
	// LLUVIA Y CHARCOS DINAMICOS EN EL RELIEVE
	// =========================================================================
	if (wetness > 0.001) {
		// Oscurecimiento general de suelo mojado
		final_albedo *= mix(1.0, 0.65, wetness);

		// Los charcos se forman primero en las partes bajas del mapa de altura y en la tierra
		float puddle_mask = clamp((wetness - grass_h * puddle_depth) / max(0.01, 1.0 - puddle_depth), 0.0, 1.0);
		puddle_mask = max(puddle_mask * wetness, wetness * blend_factor * 0.85);

		// En los charcos, la superficie es espejo liso y el normal se aplana
		final_roughness = mix(final_roughness, 0.02, puddle_mask);
		final_specular = mix(0.5, 0.95, wetness * 0.8);
		final_normal = mix(final_normal, vec3(0.5, 0.5, 1.0), puddle_mask * 0.9);

		// Saturacion de agua limpia
		float wet_luma = dot(final_albedo, vec3(0.299, 0.587, 0.114));
		final_albedo = mix(final_albedo, mix(vec3(wet_luma), final_albedo, 1.25), wetness * 0.45);
	}

	// =========================================================================
	// DISTANCIA Y SALIDA PBR
	// =========================================================================
	float normal_fade = 1.0 - smoothstep(medium_distance, fade_distance, cam_dist);
	if (quality_level == 0) normal_fade *= 0.5;
	current_normal_scale *= normal_fade;

	ALBEDO = final_albedo;
	ROUGHNESS = clamp(final_roughness, 0.0, 1.0);
	METALLIC = 0.0;
	SPECULAR = final_specular;
	NORMAL_MAP = final_normal;
	NORMAL_MAP_DEPTH = current_normal_scale;
	AO = final_ao;
	AO_LIGHT_AFFECT = ao_light_affect;
	BACKLIGHT = final_albedo * grass_translucency * (1.0 - blend_factor);
}
