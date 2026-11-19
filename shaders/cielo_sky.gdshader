shader_type sky;

// Colores del cielo para el ciclo día / atardecer / noche
group_uniforms SkyGradients;
uniform vec4 sky_day : source_color = vec4(0.09, 0.28, 0.66, 1.0);
uniform vec4 horizon_day : source_color = vec4(0.48, 0.70, 0.88, 1.0);
uniform vec4 sky_sunset : source_color = vec4(0.14, 0.18, 0.42, 1.0);
uniform vec4 horizon_sunset : source_color = vec4(0.92, 0.46, 0.18, 1.0);
uniform vec4 sky_night : source_color = vec4(0.015, 0.025, 0.065, 1.0);
uniform vec4 horizon_night : source_color = vec4(0.04, 0.06, 0.13, 1.0);

group_uniforms SkyControls;
uniform float day_night_mix : hint_range(0.0, 1.0) = 0.8;
uniform bool use_directional_light = true;
uniform float horizon_exponent : hint_range(0.1, 10.0) = 3.2;
uniform float sunset_amount_exponent : hint_range(0.1, 5.0) = 0.65;
uniform float night_amount_exponent : hint_range(0.1, 10.0) = 3.5;

group_uniforms Clouds;
uniform sampler2D cloud_tex_01 : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_tex_02 : filter_linear_mipmap, repeat_enable;
uniform vec4 cloud_color : source_color = vec4(0.98, 0.98, 0.99, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.45, 0.54, 0.68, 1.0);
uniform vec2 cloud_tiling = vec2(1.0, 1.0);
uniform vec2 wind_speed = vec2(0.35, 0.18);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.38;
uniform float cloud_feather : hint_range(0.0, 1.0) = 0.22;
uniform float cloud_depth : hint_range(0.0, 10.0) = 3.0;
uniform float cloud_occlude_exponent : hint_range(0.1, 5.0) = 1.4;

group_uniforms Stars;
uniform sampler2D night_noise_01 : filter_linear_mipmap, repeat_enable;
uniform sampler2D night_noise_02 : filter_linear_mipmap, repeat_enable;

group_uniforms SunAndMoon;
uniform float sun_scale : hint_range(0.001, 0.5) = 0.04;
uniform float sun_strength : hint_range(0.0, 50.0) = 3.2;
uniform vec4 sun_color : source_color = vec4(1.0, 0.96, 0.84, 1.0);

uniform float moon_scale : hint_range(0.001, 0.5) = 0.032;
uniform float moon_strength : hint_range(0.0, 50.0) = 4.0;
uniform vec4 moon_color : source_color = vec4(0.72, 0.82, 0.98, 1.0);

// Ruido procedural 2D rápido para nubes realistas y estrellas sin depender de texturas externas
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float cloud_fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p = rot * p * 2.05;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	// Posición del sol y mezcla día / atardecer / noche
	vec3 sun_dir = normalize(LIGHT0_DIRECTION);
	bool sun_active = LIGHT0_ENABLED;

	float sun_height = sun_active ? sun_dir.y : 1.0;
	if (!use_directional_light) {
		sun_height = (day_night_mix - 0.5) * 2.0;
	}

	float day_factor = smoothstep(-0.08, 0.35, sun_height);
	float sunset_band = clamp(1.0 - abs(sun_height - 0.04) * 3.8, 0.0, 1.0);
	float sunset_factor = pow(sunset_band, sunset_amount_exponent);
	float night_factor = smoothstep(0.05, -0.25, sun_height);

	// Gradiente atmosférico vertical realista (Rayleigh)
	float altitude = clamp(dir.y, 0.0, 1.0);
	float horizon_factor = pow(1.0 - altitude, horizon_exponent);

	vec3 day_grad = mix(sky_day.rgb, horizon_day.rgb, horizon_factor);
	vec3 sunset_grad = mix(sky_sunset.rgb, horizon_sunset.rgb, horizon_factor);
	vec3 night_grad = mix(sky_night.rgb, horizon_night.rgb, horizon_factor);

	vec3 sky_base = mix(night_grad, day_grad, day_factor);
	sky_base = mix(sky_base, sunset_grad, sunset_factor * 0.82);

	// Dispersión cálida de Mie alrededor del sol (sin quemar todo el cielo a blanco)
	if (sun_active) {
		float sun_dot = max(dot(dir, sun_dir), 0.0);
		float mie_halo = pow(sun_dot, 10.0) * 0.22 * (0.35 + sunset_factor * 0.65);
		sky_base += sun_color.rgb * mie_halo * day_factor;

		// Disco solar nítido
		if (sun_strength > 0.01 && sun_height > -0.05) {
			float sun_disk = smoothstep(1.0 - sun_scale * 0.012, 1.0 - sun_scale * 0.002, sun_dot);
			float sun_corona = pow(sun_dot, 128.0) * 0.45;
			sky_base += sun_color.rgb * (sun_disk * sun_strength + sun_corona) * smoothstep(-0.05, 0.12, sun_height);
		}
	}

	// Estrellas nítidas en la noche
	if (!AT_CUBEMAP_PASS && altitude > 0.04 && night_factor > 0.05) {
		vec2 star_uv = dir.xz / (dir.y + 0.25) * 42.0;
		float s = hash21(floor(star_uv));
		float star_mask = step(0.9945, s);
		float twinkle = 0.65 + 0.35 * sin(TIME * 2.2 + s * 60.0);
		sky_base += vec3(0.85, 0.90, 1.0) * star_mask * twinkle * night_factor * (1.0 - horizon_factor);
	}

	// Nubes cúmulus procedurales en capas (omitidas en cubemap pass para máximo rendimiento)
	if (!AT_CUBEMAP_PASS && dir.y > 0.015 && cloud_coverage > 0.01) {
		vec2 plane_uv = (dir.xz / (dir.y + 0.16)) * cloud_tiling * 1.45;
		vec2 move = TIME * wind_speed * 0.035;

		float n_main = cloud_fbm(plane_uv + move);
		float n_detail = cloud_fbm(plane_uv * 2.3 - move * 0.6);
		float cloud_density = mix(n_main, n_detail, 0.28);

		float threshold = clamp(0.82 - cloud_coverage * 0.72, 0.18, 0.85);
		float feather = max(cloud_feather, 0.06);
		float cloud_alpha = smoothstep(threshold, threshold + feather, cloud_density);

		// Sombreado direccional de nube (borde iluminado por el sol + base sombreada)
		vec2 sun_off = normalize(sun_dir.xz + vec2(0.001)) * 0.06;
		float n_lit = cloud_fbm(plane_uv + move + sun_off);
		float light_diff = clamp((cloud_density - n_lit) * 4.5 + 0.55, 0.0, 1.0);

		vec3 lit_col = mix(cloud_color.rgb, horizon_sunset.rgb * 1.05, sunset_factor * 0.55);
		vec3 shad_col = mix(cloud_shadow_color.rgb, sky_sunset.rgb * 1.2, sunset_factor * 0.45);
		vec3 final_cloud = mix(shad_col, lit_col, light_diff);

		// Oscurecer nubes suavemente de noche
		final_cloud *= mix(vec3(0.10, 0.14, 0.24), vec3(1.0), day_factor);

		// Desvanecimiento limpio al horizonte para evitar cortes
		float horizon_fade = smoothstep(0.015, 0.20, dir.y);
		cloud_alpha *= horizon_fade * 0.92;

		sky_base = mix(sky_base, final_cloud, cloud_alpha);
	}

	// Hemisferio inferior (bajo el horizonte)
	if (dir.y < 0.0) {
		float under = clamp(-dir.y * 4.0, 0.0, 1.0);
		vec3 ground_col = mix(horizon_night.rgb * 0.4, horizon_day.rgb * 0.28, day_factor);
		sky_base = mix(sky_base, ground_col, under);
	}

	if (AT_CUBEMAP_PASS) {
		COLOR = sky_base * 0.75;
	} else {
		COLOR = sky_base;
	}
}
