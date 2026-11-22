// ═══════════════════════════════════════════════════════════════════════════════
// Carroceria.gdshader — Pintura Automotriz Fotorrealista de Alta Fidelidad
// Incluye: Laca bicapa con piel de naranja (orange peel), micro-escamas metálicas (flakes),
// compatibilidad con capas dinámicas de polvo, barro procedural y lluvia.
// Proyecto: Nuestra Tierra 2.0
// ═══════════════════════════════════════════════════════════════════════════════
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// --- Configuración de Pintura Base ---
group_uniforms Pintura_Base;
uniform vec4 base_color : source_color = vec4(0.55, 0.76, 0.70, 1.0);
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float roughness : hint_range(0.01, 1.0, 0.01) = 0.18;
uniform float specular_strength : hint_range(0.0, 1.0, 0.05) = 0.60;

// --- Micro-Escamas Metálicas (Flakes) ---
group_uniforms Pintura_Base.Micro_Escamas;
uniform bool activar_escamas = true;
uniform float escala_escamas : hint_range(50.0, 500.0, 10.0) = 240.0;
uniform float brillo_escamas : hint_range(0.0, 1.0, 0.05) = 0.30;

// --- Laca y Acabado Automotriz (Clearcoat) ---
group_uniforms Laca_Clearcoat;
uniform float clearcoat : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float clearcoat_roughness_val : hint_range(0.01, 0.3, 0.005) = 0.035;
// Ondulación sutil de piel de naranja ("orange peel") para romper reflejos de espejo computarizados
uniform bool activar_piel_naranja = true;
uniform float escala_piel_naranja : hint_range(20.0, 200.0, 5.0) = 85.0;
uniform float fuerza_piel_naranja : hint_range(0.0, 0.05, 0.002) = 0.008;

// --- Control dinámico de suciedad y desgaste (desde GDScript) ---
group_uniforms Desgaste_Y_Clima;
instance uniform float dirt_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform float mud_amount : hint_range(0.0, 1.0) = 0.0;
instance uniform float wet_amount : hint_range(0.0, 1.0) = 0.0;
uniform float nivel_lluvia : hint_range(0.0, 1.0, 0.01) = 0.0;

// --- Texturas ---
group_uniforms Texturas;
uniform sampler2D dirt_noise_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_noise_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_noise_tex : source_color, filter_linear_mipmap, repeat_enable;

group_uniforms Reflejo_Entorno;
uniform bool activar_reflejo_entorno = false;
uniform sampler2D env_map : source_color, filter_linear_mipmap, repeat_enable;
uniform float intensidad_reflejo : hint_range(0.0, 1.0, 0.05) = 0.28;

// --- Colores de suciedad ---
group_uniforms Suciedad_Colores;
uniform vec4 dust_color : source_color = vec4(0.62, 0.54, 0.42, 1.0);
uniform vec4 mud_color : source_color = vec4(0.28, 0.20, 0.12, 1.0);
uniform vec4 mud_streak_color : source_color = vec4(0.18, 0.13, 0.08, 1.0);

// --- Escalas y profundidades de normales ---
group_uniforms Escalas_Y_Relieve;
uniform float dust_scale : hint_range(0.1, 10.0) = 3.0;
uniform float mud_scale : hint_range(0.1, 10.0) = 1.8;
uniform float wet_scale : hint_range(0.1, 10.0) = 4.0;
uniform float dust_normal_depth : hint_range(0.0, 2.0) = 0.4;
uniform float mud_normal_depth : hint_range(0.0, 3.0) = 1.4;

varying float v_height;
varying vec3 v_world_pos;
varying vec3 v_local_pos;

float hash3D(vec3 p) {
	p = fract(p * vec3(443.8975, 397.2973, 491.1871));
	p += dot(p.xyz, p.yzx + 19.19);
	return fract(p.x * p.y * p.z);
}

float fast_atan2(float y, float x) {
	float ax = abs(x) + 1e-6;
	float ay = abs(y);
	float mn = min(ax, ay);
	float mx = max(ax, ay);
	float a = mn / mx;
	float s = a * a;
	float r = ((-0.0464964749 * s + 0.15931422) * s - 0.327622764) * s * a + a;
	if (ay > ax) { r = 1.57079637 - r; }
	if (x < 0.0) { r = 3.14159274 - r; }
	return (y < 0.0) ? -r : r;
}

float fast_asin(float x) {
	float ax = clamp(abs(x), 0.0, 1.0);
	float r = 1.57079637 - sqrt(1.0 - ax) * (1.5707288 + ax * (-0.2121144 + ax * 0.0742610));
	return (x < 0.0) ? -r : r;
}

void vertex() {
	v_height = VERTEX.y;
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 bump_normal(sampler2D tex, vec2 uv, float strength) {
	float s01 = texture(tex, uv + vec2(-0.008, 0.0)).r;
	float s21 = texture(tex, uv + vec2( 0.008, 0.0)).r;
	float s10 = texture(tex, uv + vec2(0.0, -0.008)).r;
	float s12 = texture(tex, uv + vec2(0.0,  0.008)).r;
	vec3 va = normalize(vec3(2.0, 0.0, s21 - s01));
	vec3 vb = normalize(vec3(0.0, 2.0, s12 - s10));
	return cross(va, vb) * strength;
}

void fragment() {
	vec3 n_view = normalize(VIEW);
	vec3 normal_acumulada = NORMAL;

	// 1. Simulación de piel de naranja ("orange peel") en la laca automotriz
	if (activar_piel_naranja && clearcoat > 0.1) {
		vec3 coord_piel = v_local_pos * escala_piel_naranja;
		float n_piel_x = (hash3D(floor(coord_piel)) * 2.0 - 1.0);
		float n_piel_z = (hash3D(floor(coord_piel + vec3(1.7, 3.1, 0.9))) * 2.0 - 1.0);
		normal_acumulada = normalize(normal_acumulada + vec3(n_piel_x, 0.0, n_piel_z) * fuerza_piel_naranja);
	}

	// 2. Color base de pintura y micro-escamas metálicas (Flakes)
	vec3 albedo_paint = base_color.rgb;
	if (activar_escamas) {
		vec3 coord_escamas = v_local_pos * escala_escamas;
		float flake = step(0.70, hash3D(floor(coord_escamas)));
		float flake_spec = pow(clamp(dot(n_view, normal_acumulada), 0.0, 1.0), 3.0) * flake * brillo_escamas;
		albedo_paint += albedo_paint * flake_spec;
	}

	// 3. UVs triplanares para capas de polvo y barro
	vec2 uv_dust = v_world_pos.xz * dust_scale;
	vec2 uv_mud  = v_world_pos.xz * mud_scale;
	vec2 uv_wet  = v_world_pos.xz * wet_scale;

	float noise_dust = 0.0;
	if (dirt_amount > 0.001) {
		noise_dust = texture(dirt_noise_tex, uv_dust).r;
	}

	float noise_mud = 0.0;
	float mud_streaks = 0.0;
	if (mud_amount > 0.001) {
		noise_mud = texture(mud_noise_tex, uv_mud).r;
		float noise_mud2 = texture(mud_noise_tex, uv_mud * 0.5 + vec2(0.3, 0.7)).r;
		mud_streaks = noise_mud * noise_mud2;
	}

	float noise_wet = 0.0;
	float wet_total = max(wet_amount, nivel_lluvia);
	if (wet_total > 0.001) {
		noise_wet = texture(wet_noise_tex, uv_wet).r;
	}

	// 4. Gradientes de altura y máscaras
	float height_dust = smoothstep(2.0, -0.5, v_height);
	float height_mud  = smoothstep(1.2, -1.0, v_height);
	float height_wet  = clamp(1.0 - v_height * 0.15, 0.0, 1.0);

	float dust_mask = 0.0;
	if (dirt_amount > 0.001) {
		dust_mask = smoothstep(1.0 - dirt_amount, 1.05 - dirt_amount, noise_dust * height_dust);
	}

	float mud_mask = 0.0;
	if (mud_amount > 0.001) {
		float mud_base = smoothstep(1.0 - mud_amount, 1.08 - mud_amount, noise_mud * height_mud);
		mud_mask = clamp(mud_base + mud_streaks * mud_amount * 0.6, 0.0, 1.0);
	}

	float wet_mask = 0.0;
	if (wet_total > 0.001) {
		wet_mask = wet_total * (0.6 + noise_wet * 0.4) * height_wet;
	}

	// 5. Aplicación de normales de barro y polvo
	if (dust_mask > 0.01) {
		vec3 n_dust = bump_normal(dirt_noise_tex, uv_dust, dust_normal_depth);
		normal_acumulada = mix(normal_acumulada, normalize(normal_acumulada + n_dust), dust_mask * 0.5);
	}
	if (mud_mask > 0.01) {
		vec3 n_mud  = bump_normal(mud_noise_tex,  uv_mud,  mud_normal_depth);
		normal_acumulada = mix(normal_acumulada, normalize(normal_acumulada + n_mud), mud_mask);
	}
	NORMAL = normalize(normal_acumulada);

	// 6. Mezcla de albedo (Pintura PBR pura -> Polvo -> Barro -> Mojado)
	vec3 with_dust = mix(albedo_paint, dust_color.rgb, dust_mask);
	vec3 mud_final_color = mix(mud_color.rgb, mud_streak_color.rgb, clamp(mud_streaks * 2.0, 0.0, 1.0));
	vec3 with_mud = mix(with_dust, mud_final_color, mud_mask);
	vec3 wet_darkened = with_mud * (1.0 - wet_mask * 0.25);

	// Reflejo panorámico 360° en la laca automotriz (atenuado en zonas sucias/barro)
	vec3 emis_cc = vec3(0.0);
	if (activar_reflejo_entorno) {
		vec3 view_dir_w = normalize((INV_VIEW_MATRIX * vec4(-n_view, 0.0)).xyz);
		vec3 norm_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 refl_w = reflect(view_dir_w, norm_w);
		float u_env = fract(fast_atan2(refl_w.z, refl_w.x) / 6.2831853 + 0.5);
		float v_env = 0.5 - fast_asin(refl_w.y) / 3.14159265;
		vec3 env_col = textureLod(env_map, vec2(u_env, v_env), clearcoat_roughness_val * 5.0).rgb;
		float fresnel_cc = pow(1.0 - clamp(dot(NORMAL, n_view), 0.0, 1.0), 2.5);
		float clean_factor = clearcoat * (1.0 - mud_mask) * (1.0 - dust_mask * 0.85);
		float refl_mix = clamp((0.18 + 0.82 * fresnel_cc) * intensidad_reflejo * clean_factor, 0.0, 0.65);
		wet_darkened = mix(wet_darkened, env_col * (0.45 + 0.55 * wet_darkened), refl_mix);
		emis_cc = env_col * (0.12 + 0.24 * fresnel_cc) * clean_factor * intensidad_reflejo;
	}

	ALBEDO = wet_darkened;
	EMISSION = emis_cc;

	// 7. Parámetros PBR
	float m_dust = mix(metallic, 0.0, dust_mask);
	float r_dust = mix(roughness, 0.92, dust_mask);

	float m_mud = mix(m_dust, 0.0, mud_mask);
	float r_mud = mix(r_dust, 0.98, mud_mask);

	float wet_influence = wet_mask * (1.0 - mud_mask);
	METALLIC = mix(m_mud, 0.0, wet_influence);
	ROUGHNESS = mix(r_mud, 0.05, wet_influence);

	float spec = mix(specular_strength, 0.85, wet_influence);
	SPECULAR = mix(spec, 0.0, mud_mask);

	// Clearcoat automotriz de alta gama
	CLEARCOAT = clearcoat * (1.0 - mud_mask) * (1.0 - dust_mask * 0.8);
	CLEARCOAT_ROUGHNESS = mix(clearcoat_roughness_val, 0.5, dust_mask);
}