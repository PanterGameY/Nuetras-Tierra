shader_type sky;

// Colores del cielo para el ciclo día / atardecer / noche
group_uniforms SkyGradients;
uniform vec4 sky_day : source_color = vec4(0.24, 0.46, 0.72, 1.0);
uniform vec4 horizon_day : source_color = vec4(0.74, 0.80, 0.85, 1.0);
uniform vec4 sky_sunset : source_color = vec4(0.18, 0.22, 0.42, 1.0);
uniform vec4 horizon_sunset : source_color = vec4(0.92, 0.52, 0.22, 1.0);
uniform vec4 sky_night : source_color = vec4(0.03, 0.04, 0.08, 1.0);
uniform vec4 horizon_night : source_color = vec4(0.06, 0.08, 0.14, 1.0);

group_uniforms SkyControls;
uniform float day_night_mix : hint_range(0.0, 1.0) = 0.8;
uniform bool use_directional_light = true;
uniform float horizon_exponent : hint_range(0.1, 10.0) = 2.8;
uniform float sunset_amount_exponent : hint_range(0.1, 5.0) = 0.4;
uniform float night_amount_exponent : hint_range(0.1, 10.0) = 4.0;

group_uniforms Clouds;
uniform sampler2D cloud_tex_01 : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_tex_02 : filter_linear_mipmap, repeat_enable;
uniform vec4 cloud_color : source_color = vec4(0.96, 0.97, 0.98, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.52, 0.58, 0.68, 1.0);
uniform vec2 cloud_tiling = vec2(1.0, 1.0);
uniform vec2 wind_speed = vec2(0.35, 0.18);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;
uniform float cloud_feather : hint_range(0.0, 1.0) = 0.12;
uniform float cloud_depth : hint_range(0.0, 10.0) = 3.5;
uniform float cloud_occlude_exponent : hint_range(0.1, 5.0) = 1.5;

group_uniforms Stars;
uniform sampler2D night_noise_01 : filter_linear_mipmap, repeat_enable;
uniform sampler2D night_noise_02 : filter_linear_mipmap, repeat_enable;

group_uniforms SunAndMoon;
uniform float sun_scale : hint_range(0.001, 0.5) = 0.045;
uniform float sun_strength : hint_range(0.0, 50.0) = 14.0;
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);

uniform float moon_scale : hint_range(0.001, 0.5) = 0.035;
uniform float moon_strength : hint_range(0.0, 50.0) = 9.0;
uniform vec4 moon_color : source_color = vec4(0.65, 0.75, 0.95, 1.0);

void sky() {
	vec3 dir = EYEDIR;

	// Determinar posición del sol y mezcla día/noche
	vec3 sun_dir = LIGHT0_DIRECTION;
	bool sun_active = LIGHT0_ENABLED;

	// Altura del sol respecto al horizonte (-1.0 a 1.0)
	float sun_height = sun_active ? sun_dir.y : 1.0;
	if (!use_directional_light) {
		sun_height = (day_night_mix - 0.5) * 2.0;
	}

	// Factores de mezcla suave
	float day_factor = clamp(sun_height * 3.5, 0.0, 1.0);
	float sunset_raw = 1.0 - abs(sun_height * 2.5);
	float sunset_factor = pow(clamp(sunset_raw, 0.0, 1.0), sunset_amount_exponent);
	float night_factor = pow(clamp(-sun_height * 2.0, 0.0, 1.0), night_amount_exponent);

	// Gradiente vertical de altitud
	float altitude = clamp(dir.y, 0.0, 1.0);
	float horizon_factor = pow(1.0 - altitude, horizon_exponent);

	// Colores base para cada momento del día
	vec3 day_gradient = mix(sky_day.rgb, horizon_day.rgb, horizon_factor);
	vec3 sunset_gradient = mix(sky_sunset.rgb, horizon_sunset.rgb, horizon_factor);
	vec3 night_gradient = mix(sky_night.rgb, horizon_night.rgb, horizon_factor);

	// Mezcla final de cielo base
	vec3 sky_base = day_gradient;
	sky_base = mix(sky_base, sunset_gradient, sunset_factor);
	sky_base = mix(sky_base, night_gradient, clamp(night_factor + (1.0 - day_factor) * 0.5, 0.0, 1.0));

	// Estrellas en la noche
	if (altitude > 0.05 && night_factor > 0.1) {
		vec2 star_uv = (dir.xz / (dir.y + 0.15)) * 0.4;
		float n1 = texture(night_noise_01, star_uv).r;
		float n2 = texture(night_noise_02, star_uv * 1.5 + vec2(0.3, 0.7)).r;
		float stars = pow(clamp((n1 * n2 - 0.55) * 4.0, 0.0, 1.0), 3.0);
		sky_base += vec3(stars) * night_factor * (1.0 - horizon_factor);
	}

	// Sol y Luna (Disco visible)
	if (sun_active && sun_strength > 0.01) {
		float sun_dot = max(dot(dir, sun_dir), 0.0);
		float sun_disk = smoothstep(1.0 - sun_scale * 0.02, 1.0, sun_dot);
		float sun_glow = pow(sun_dot, 16.0) * 0.35;
		sky_base += (sun_color.rgb * sun_disk * sun_strength) + (sun_color.rgb * sun_glow * (sun_strength * 0.2));
	}

	// Nubes volumétricas 2D optimizadas
	if (dir.y > 0.02) {
		// Proyección planar horizontal hacia el domo
		vec2 cloud_uv = (dir.xz / (dir.y + 0.2)) * cloud_tiling * 0.08;
		vec2 move = TIME * wind_speed * 0.01;

		float c1 = texture(cloud_tex_01, cloud_uv + move).r;
		float c2 = texture(cloud_tex_02, cloud_uv * 1.7 - move * 0.6).r;
		float cloud_raw = (c1 * 0.6 + c2 * 0.4);

		// Cobertura y suavizado de bordes
		float cloud_threshold = 1.0 - cloud_coverage;
		float cloud_alpha = smoothstep(cloud_threshold, cloud_threshold + max(cloud_feather, 0.01), cloud_raw);

		// Efecto de sombreado y profundidad de nube
		float depth_sample = texture(cloud_tex_01, cloud_uv + move + vec2(0.02, 0.02)).r;
		float shadow_factor = pow(clamp(depth_sample * cloud_depth, 0.0, 1.0), cloud_occlude_exponent);
		vec3 dynamic_cloud_color = mix(cloud_shadow_color.rgb, cloud_color.rgb, shadow_factor);

		// Modulación de luz diurna en nubes
		dynamic_cloud_color *= mix(vec3(0.15, 0.18, 0.25), vec3(1.0), day_factor);

		// Atenuación de nubes cerca del horizonte para horizonte limpio
		float horizon_fade = smoothstep(0.02, 0.25, dir.y);
		cloud_alpha *= horizon_fade;

		// Mezcla de nubes con el fondo de cielo
		sky_base = mix(sky_base, dynamic_cloud_color, cloud_alpha);
	}

	// Si mira por debajo del horizonte, atenuar ligeramente
	if (dir.y < 0.0) {
		float under = clamp(-dir.y * 3.0, 0.0, 1.0);
		vec3 ground_color = horizon_day.rgb * 0.2;
		sky_base = mix(sky_base, ground_color, under);
	}

	// En subpase cubemap, entregar radiance suave y rápido
	if (AT_CUBEMAP_PASS) {
		COLOR = sky_base * 0.75;
	} else {
		COLOR = sky_base;
	}
}
