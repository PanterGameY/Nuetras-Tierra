shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_roughness : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_emission : source_color, filter_linear_mipmap, repeat_disable;

uniform bool usar_emision = false;
uniform float intensidad_emision : hint_range(0.0, 3.0) = 0.0;
uniform float fuerza_normal : hint_range(0.0, 2.0) = 1.1;
uniform float metallic_vidrio : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float tile_idx = floor(UV2.x + 0.5);
	float modo = floor(UV2.y + 0.5); // 0 = tileable (fachada/techo), 1 = 1:1 (ventana/puerta), 2 = color sólido (molduras)

	if (modo >= 1.5) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.62;
		METALLIC = 0.06;
	} else {
		float col = mod(tile_idx, 4.0);
		float row = floor(tile_idx / 4.0);
		vec2 tile_origin = vec2(col, row) * 0.25;

		vec2 local_uv;
		vec2 ddx = dFdx(UV) * 0.25;
		vec2 ddy = dFdy(UV) * 0.25;

		if (modo < 0.5) {
			local_uv = clamp(fract(UV), vec2(0.008), vec2(0.992));
		} else {
			local_uv = clamp(UV, vec2(0.008), vec2(0.992));
		}

		vec2 atlas_uv = tile_origin + local_uv * 0.25;

		vec3 alb = textureGrad(atlas_albedo, atlas_uv, ddx, ddy).rgb;
		vec3 nrm = textureGrad(atlas_normal, atlas_uv, ddx, ddy).rgb;
		float rgh = textureGrad(atlas_roughness, atlas_uv, ddx, ddy).r;

		bool es_vidrio = (modo > 0.5) && (rgh < 0.16);
		if (es_vidrio) {
			// Reflejo Fresnel realista en el cristal de ventanas y puertas
			float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
			vec3 sky_refl = vec3(0.32, 0.44, 0.58) * (0.35 + 0.65 * fresnel);
			ALBEDO = mix(alb, sky_refl, 0.35 + 0.40 * fresnel);
			ROUGHNESS = rgh;
			METALLIC = metallic_vidrio;
			SPECULAR = 0.9;
			if (usar_emision && intensidad_emision > 0.01) {
				vec3 emi = textureGrad(atlas_emission, atlas_uv, ddx, ddy).rgb;
				EMISSION = emi * intensidad_emision;
			}
		} else {
			// Sutil variación orgánica por posición para evitar repetición uniforme
			float macro = sin(v_world_pos.x * 0.45 + v_world_pos.z * 0.35) * 0.035;
			ALBEDO = clamp(alb * COLOR.rgb * (1.0 + macro), vec3(0.0), vec3(1.0));
			ROUGHNESS = rgh;
			METALLIC = 0.04;
		}

		NORMAL_MAP = nrm;
		NORMAL_MAP_DEPTH = fuerza_normal;
	}
}
