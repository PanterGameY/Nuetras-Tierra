// ═══════════════════════════════════════════════════════════════════════════════
// carroceria.gdshader — Shader de Pintura Automotriz de Alta Calidad (PBR Next-Gen)
// Incluye: Basecoat metálico con micro-escamas (flakes), laca con piel de naranja (orange peel),
// perlado suave, daños multinivel con profundidad 3D, barro procedural y gotas de lluvia.
// Proyecto: Nuestra Tierra 2.0
// ═══════════════════════════════════════════════════════════════════════════════
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

group_uniforms Pintura_Base;
// Color principal de la carrocería automotriz
uniform vec4 color_base : source_color = vec4(0.55, 0.76, 0.70, 1.0);
// Nivel metálico (0.3 - 0.7 para pinturas metalizadas automotrices con laca)
uniform float metalico : hint_range(0.0, 1.0, 0.01) = 0.55;
// Rugosidad del acabado base
uniform float rugosidad : hint_range(0.01, 1.0, 0.01) = 0.18;
// Coeficiente de brillo especular
uniform float especular : hint_range(0.0, 1.0, 0.01) = 0.60;

group_uniforms Pintura_Base.Micro_Escamas;
// Simula las micro-escamas metálicas reflectivas que brillan al sol
uniform bool activar_escamas_metalicas = true;
uniform float escala_escamas : hint_range(50.0, 500.0, 10.0) = 220.0;
uniform float brillo_escamas : hint_range(0.0, 1.0, 0.05) = 0.35;

group_uniforms Pintura_Base.Texturas;
uniform bool usar_textura_albedo = false;
uniform sampler2D textura_albedo : hint_default_white, filter_linear_mipmap;
uniform bool usar_mapa_normales = false;
uniform sampler2D mapa_normales : hint_normal, filter_linear_mipmap;
uniform float fuerza_normales : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform bool usar_mapa_rugosidad = false;
uniform sampler2D mapa_rugosidad : hint_default_white, filter_linear_mipmap;

group_uniforms Efecto_Perlado;
// Cambio de tonalidad en ángulos de visión rasantes
uniform bool activar_perlado = false;
uniform vec4 color_perlado : source_color = vec4(0.70, 0.88, 0.82, 1.0);
uniform float perlado_fresnel_power : hint_range(1.0, 8.0, 0.1) = 3.5;
uniform float perlado_intensidad : hint_range(0.0, 1.0, 0.02) = 0.25;

group_uniforms Capa_Laca_Clearcoat;
// Capa externa transparente de poliuretano / laca de fábrica
uniform float laca_clearcoat : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float laca_rugosidad : hint_range(0.005, 0.2, 0.005) = 0.035;
// Ondulación sutil de piel de naranja ("orange peel") para romper reflejos sintéticos
uniform bool activar_piel_naranja = true;
uniform float escala_piel_naranja : hint_range(20.0, 200.0, 5.0) = 90.0;
uniform float fuerza_piel_naranja : hint_range(0.0, 0.05, 0.002) = 0.008;

group_uniforms Clima;
// Humedad y condensación transmitida por el sistema meteorológico
uniform float nivel_lluvia : hint_range(0.0, 1.0, 0.01) = 0.0;

group_uniforms Danos_Y_Descascarado;
uniform float dano_nivel : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float dano_escala_parches : hint_range(1.0, 50.0, 0.5) = 12.0;
uniform float dano_escala_rayones : hint_range(50.0, 500.0, 10.0) = 250.0;
uniform float dano_grosor_rayones : hint_range(0.001, 0.03, 0.001) = 0.005;
uniform float dano_grosor_pintura_3d : hint_range(0.0, 5.0, 0.1) = 2.0;

group_uniforms Danos_Y_Descascarado.Capas_Internas;
uniform vec4 color_imprimacion : source_color = vec4(0.25, 0.25, 0.25, 1.0);
uniform vec4 color_metal_interno : source_color = vec4(0.65, 0.65, 0.65, 1.0);
uniform float dano_rugosidad : hint_range(0.0, 1.0, 0.02) = 0.55;
uniform bool activar_oxido = true;
uniform vec4 color_oxido : source_color = vec4(0.35, 0.14, 0.05, 1.0);
uniform float oxido_intensidad : hint_range(0.0, 1.0, 0.02) = 0.5;

group_uniforms Efecto_Barro_Suciedad;
uniform float barro_nivel : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 barro_color : source_color = vec4(0.25, 0.17, 0.11, 1.0);
uniform float barro_rugosidad : hint_range(0.0, 1.0, 0.02) = 0.9;
uniform float barro_humedad : hint_range(0.0, 1.0, 0.02) = 0.2;
uniform float barro_ruido_escala : hint_range(1.0, 50.0, 0.5) = 15.0;
uniform float barro_altura_maxima : hint_range(-5.0, 5.0, 0.1) = -0.2;
uniform float barro_caida_vertical : hint_range(0.1, 8.0, 0.1) = 2.5;

varying vec3 local_pos;

float hash3D(vec3 p) {
	p = fract(p * vec3(443.8975, 397.2973, 491.1871));
	p += dot(p.xyz, p.yzx + 19.19);
	return fract(p.x * p.y * p.z);
}

float ruido3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash3D(i + vec3(0.0, 0.0, 0.0));
	float b = hash3D(i + vec3(1.0, 0.0, 0.0));
	float c = hash3D(i + vec3(0.0, 1.0, 0.0));
	float d = hash3D(i + vec3(1.0, 1.0, 0.0));
	float e = hash3D(i + vec3(0.0, 0.0, 1.0));
	float g = hash3D(i + vec3(1.0, 0.0, 1.0));
	float h = hash3D(i + vec3(0.0, 1.0, 1.0));
	float k = hash3D(i + vec3(1.0, 1.0, 1.0));

	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
			   mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float ruido_fbm(vec3 p) {
	float valor = 0.0;
	float amp = 0.5;
	float frec = 1.0;
	for (int i = 0; i < 3; i++) {
		valor += amp * ruido3D(p * frec);
		frec *= 2.0;
		amp *= 0.5;
	}
	return valor;
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n_view = normalize(VIEW);
	vec3 normal_acumulada = NORMAL;

	// 1. Obtención de Color Base
	vec3 albedo_final = color_base.rgb;
	if (usar_textura_albedo) {
		vec4 tex = texture(textura_albedo, UV);
		albedo_final *= tex.rgb;
	}

	// 2. Micro-escamas metálicas de purpurina automotriz (Flakes)
	if (activar_escamas_metalicas) {
		vec3 coord_escamas = (UV != vec2(0.0)) ? vec3(UV * escala_escamas, 0.0) : local_pos * escala_escamas;
		float flake = step(0.72, hash3D(floor(coord_escamas)));
		// Destello que reacciona con la dirección de la luz y la vista
		float flake_spec = pow(dot(n_view, normal_acumulada), 2.0) * flake * brillo_escamas;
		albedo_final += albedo_final * flake_spec;
	}

	// 3. Efecto perlado suave
	if (activar_perlado) {
		float fresnel = pow(1.0 - max(dot(normal_acumulada, n_view), 0.0), perlado_fresnel_power);
		albedo_final = mix(albedo_final, color_perlado.rgb, fresnel * perlado_intensidad);
	}

	// 4. Parámetros PBR
	float metalico_final = metalico;
	float rugosidad_final = rugosidad;
	if (usar_mapa_rugosidad) {
		rugosidad_final *= texture(mapa_rugosidad, UV).r;
	}

	float laca_final = laca_clearcoat;
	float laca_rugosidad_final = laca_rugosidad;

	// 5. Simulación de piel de naranja ("orange peel") en la laca
	if (activar_piel_naranja && laca_final > 0.1) {
		vec3 coord_piel = local_pos * escala_piel_naranja;
		float n_piel_x = ruido3D(coord_piel) * 2.0 - 1.0;
		float n_piel_z = ruido3D(coord_piel + vec3(1.7, 3.1, 0.9)) * 2.0 - 1.0;
		normal_acumulada = normalize(normal_acumulada + vec3(n_piel_x, 0.0, n_piel_z) * fuerza_piel_naranja);
	}

	// 6. Daños y descascarado multinivel
	if (dano_nivel > 0.0) {
		float ruido_impactos = ruido3D(local_pos * 2.8) * 0.7 + ruido3D(local_pos * 5.0) * 0.3;
		float mascara_zonas = smoothstep(1.0 - dano_nivel, 1.1 - dano_nivel, ruido_impactos);

		if (mascara_zonas > 0.001) {
			float ruido_parches = ruido3D(local_pos * dano_escala_parches) * 0.65 +
								  ruido3D(local_pos * dano_escala_parches * 2.5) * 0.35;
			float mascara_parches = smoothstep(0.48, 0.52, ruido_parches * mascara_zonas);

			vec3 coord_rayas = local_pos * dano_escala_rayones;
			float rayas = abs(ruido3D(coord_rayas) - ruido3D(coord_rayas + vec3(0.1, 0.15, 0.2)));
			float mascara_rayas = smoothstep(dano_grosor_rayones, 0.0, rayas) * mascara_zonas * 0.7;

			float mascara_dano_total = clamp(mascara_parches + mascara_rayas, 0.0, 1.0);

			if (mascara_dano_total > 0.001) {
				vec2 derivadas = vec2(dFdx(mascara_dano_total), dFdy(mascara_dano_total));
				normal_acumulada = normalize(normal_acumulada + vec3(-derivadas * dano_grosor_pintura_3d, 0.0));

				float factor_prof = smoothstep(0.3, 0.8, mascara_dano_total * (ruido_parches * 1.5));
				vec3 color_dano = mix(color_imprimacion.rgb, color_metal_interno.rgb, factor_prof);
				float metal_dano = mix(0.0, 1.0, factor_prof);

				if (activar_oxido) {
					float r_oxido = ruido3D(local_pos * (dano_escala_parches * 1.8));
					float m_oxido = smoothstep(0.4, 0.7, r_oxido) * mascara_dano_total * oxido_intensidad;
					color_dano = mix(color_dano, color_oxido.rgb, m_oxido);
					metal_dano = mix(metal_dano, 0.0, m_oxido);
				}

				albedo_final = mix(albedo_final, color_dano, mascara_dano_total);
				metalico_final = mix(metalico_final, metal_dano, mascara_dano_total);
				rugosidad_final = mix(rugosidad_final, dano_rugosidad, mascara_dano_total);
				laca_final = mix(laca_final, 0.0, mascara_dano_total);
			}
		}
	}

	// 7. Capa de barro y suciedad
	if (barro_nivel > 0.0) {
		float gradiente_vert = clamp((barro_altura_maxima - local_pos.y) * barro_caida_vertical, 0.0, 1.0);
		float r_barro1 = ruido_fbm(local_pos * barro_ruido_escala);
		float r_barro2 = ruido3D(local_pos * (barro_ruido_escala * 3.14)) * 0.3;
		float m_barro = clamp((r_barro1 + r_barro2) * 1.5 - 0.25, 0.0, 1.0);
		float mascara_barro = clamp(gradiente_vert * m_barro * 2.0, 0.0, 1.0) * barro_nivel;

		albedo_final = mix(albedo_final, barro_color.rgb, mascara_barro);
		float rug_barro = mix(barro_rugosidad, 0.35, barro_humedad * r_barro2);
		rugosidad_final = mix(rugosidad_final, rug_barro, mascara_barro);
		metalico_final = mix(metalico_final, 0.0, mascara_barro);
		laca_final = mix(laca_final, 0.0, mascara_barro);
	}

	// 8. Reacción dinámica a la lluvia (gotas y escurrimiento sobre la laca)
	if (nivel_lluvia > 0.05) {
		vec2 uv_lluvia = (UV != vec2(0.0)) ? UV * 60.0 : local_pos.xz * 15.0;
		float gota_pintura = step(0.82, hash3D(vec3(floor(uv_lluvia), 1.0)));
		laca_rugosidad_final = mix(laca_rugosidad_final, 0.12, gota_pintura * nivel_lluvia);
		albedo_final = mix(albedo_final, albedo_final * 0.92, nivel_lluvia * 0.2);
	}

	// Asignaciones finales al motor de render
	ALBEDO = albedo_final;
	METALLIC = metalico_final;
	ROUGHNESS = rugosidad_final;
	SPECULAR = especular;
	NORMAL = normal_acumulada;

	if (usar_mapa_normales) {
		NORMAL_MAP = texture(mapa_normales, UV).rgb;
		NORMAL_MAP_DEPTH = fuerza_normales;
	}

	CLEARCOAT = laca_final;
	CLEARCOAT_ROUGHNESS = laca_rugosidad_final;
	AO = 1.0;
}
