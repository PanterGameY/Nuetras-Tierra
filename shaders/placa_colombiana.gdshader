shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Textura del texto renderizado (SubViewport 2D)
uniform sampler2D texto_texture : hint_default_white, filter_linear_mipmap;
uniform bool usar_textura_fuente = true;

// Colores base
uniform vec4 color_fondo : source_color = vec4(0.988, 0.76, 0.05, 1.0); // Amarillo reflectivo colombiano #FABA0C
uniform vec4 color_texto : source_color = vec4(0.08, 0.08, 0.08, 1.0);
uniform vec4 color_borde : source_color = vec4(0.12, 0.12, 0.12, 1.0);

// Propiedades de material metálico / reflectivo estilo aluminio estampado
uniform float metallic : hint_range(0.0, 1.0) = 0.45;
uniform float roughness : hint_range(0.0, 1.0) = 0.20;

// Tipo de placa según normativa colombiana:
// 0 = Personalizada, 1 = Particular, 2 = Público, 3 = Oficial,
// 4 = Diplomático, 5 = Importación Temporal, 6 = Remolque, 7 = Clásico
uniform int tipo_placa : hint_range(0, 7) = 1;

// EFECTO DE SUCIEDAD Y BARRO ORGANICO
uniform float suciedad_nivel : hint_range(0.0, 1.0) = 0.0;
uniform vec4 suciedad_color : source_color = vec4(0.25, 0.17, 0.11, 1.0);
uniform float suciedad_escala : hint_range(1.0, 50.0) = 14.0;

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
	float amplitud = 0.5;
	float frecuencia = 1.0;
	for (int i = 0; i < 3; i++) {
		valor += amplitud * ruido3D(p * frecuencia);
		frecuencia *= 2.0;
		amplitud *= 0.5;
	}
	return valor;
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = UV;
	
	// Paletas de color auténticas según norma colombiana
	vec4 base_bg = color_fondo;
	vec4 active_text_color = color_texto;
	vec4 active_border_color = color_borde;
	
	if (tipo_placa == 1 || tipo_placa == 3) { // Particular u Oficial (Amarillo brillante)
		base_bg = vec4(0.988, 0.76, 0.05, 1.0);
		active_text_color = vec4(0.08, 0.08, 0.08, 1.0);
		active_border_color = vec4(0.08, 0.08, 0.08, 1.0);
	} else if (tipo_placa == 2) { // Público (Blanco limpio)
		base_bg = vec4(0.96, 0.96, 0.96, 1.0);
		active_text_color = vec4(0.08, 0.08, 0.08, 1.0);
		active_border_color = vec4(0.08, 0.08, 0.08, 1.0);
	} else if (tipo_placa == 4) { // Diplomático
		if (uv.y < 0.22) {
			base_bg = vec4(0.0, 0.53, 0.86, 1.0); // Azul franja superior
		} else {
			base_bg = vec4(0.96, 0.96, 0.96, 1.0);
		}
		active_text_color = vec4(0.08, 0.08, 0.08, 1.0);
		active_border_color = vec4(0.08, 0.08, 0.08, 1.0);
	} else if (tipo_placa == 5) { // Importación Temporal (Rojo)
		base_bg = vec4(0.82, 0.11, 0.11, 1.0);
		active_text_color = vec4(0.96, 0.96, 0.96, 1.0);
		active_border_color = vec4(0.96, 0.96, 0.96, 1.0);
	} else if (tipo_placa == 6) { // Remolque (Verde)
		base_bg = vec4(0.06, 0.54, 0.26, 1.0);
		active_text_color = vec4(0.96, 0.96, 0.96, 1.0);
		active_border_color = vec4(0.96, 0.96, 0.96, 1.0);
	} else if (tipo_placa == 7) { // Clásico / Antiguo
		if (uv.x < 0.20 || uv.x > 0.80 || uv.y < 0.22) {
			base_bg = vec4(0.11, 0.21, 0.85, 1.0);
		} else {
			base_bg = vec4(0.96, 0.96, 0.96, 1.0);
		}
		active_text_color = vec4(0.08, 0.08, 0.08, 1.0);
		active_border_color = vec4(0.08, 0.08, 0.08, 1.0);
	}
	
	// 1. Recorte de bordes redondeados precisos
	vec2 p = uv * 2.0 - 1.0; // [-1, 1]
	vec2 border_dist = abs(p) - vec2(0.95, 0.90);
	float corner = length(max(border_dist, vec2(0.0))) - 0.03;
	
	if (corner > 0.01) {
		discard;
	}
	
	vec4 final_color = base_bg;
	
	// 2. Fino marco estampado troquelado (borde negro exterior delgado de 3mm)
	float dist_edge_x = abs(p.x);
	float dist_edge_y = abs(p.y);
	if ((dist_edge_x >= 0.93 && dist_edge_x <= 0.97) || (dist_edge_y >= 0.88 && dist_edge_y <= 0.94)) {
		final_color = mix(final_color, active_border_color, 0.92);
	}
	
	// 3. Orificios / Remaches discretos de montaje en las 4 esquinas (pequeños círculos metálicos)
	vec2 screw_pos = abs(p) - vec2(0.88, 0.78);
	float screw_dist = length(screw_pos);
	if (screw_dist < 0.028) {
		vec4 screw_col = mix(vec4(0.15, 0.15, 0.18, 1.0), vec4(0.55, 0.55, 0.60, 1.0), smoothstep(0.0, 0.025, screw_dist));
		final_color = screw_col;
	}
	
	// 4. Muestra del Texto (Fuente 2D)
	if (usar_textura_fuente) {
		vec4 text_sample = texture(texto_texture, uv);
		if (text_sample.a > 0.08) {
			final_color = mix(final_color, active_text_color, text_sample.a);
		}
	}
	
	// 5. Capa de Suciedad / Barro
	float metalico_final = metallic;
	float rugosidad_final = roughness;
	
	if (suciedad_nivel > 0.0) {
		vec3 pos_ruido = local_pos * suciedad_escala;
		if (length(local_pos) == 0.0) {
			pos_ruido = vec3(uv * suciedad_escala, 1.0);
		}
		
		float n1 = ruido_fbm(pos_ruido);
		float n2 = ruido3D(pos_ruido * 2.5) * 0.4;
		float mascara_barro = clamp((n1 + n2) * 1.6 - 0.3, 0.0, 1.0) * suciedad_nivel;
		
		float gradiente_inferior = smoothstep(0.1, 0.9, uv.y);
		mascara_barro = clamp(mascara_barro * (0.5 + 0.8 * gradiente_inferior), 0.0, 1.0);
		
		final_color = mix(final_color, suciedad_color, mascara_barro);
		rugosidad_final = mix(rugosidad_final, 0.9, mascara_barro);
		metalico_final = mix(metalico_final, 0.0, mascara_barro);
	}
	
	ALBEDO = final_color.rgb;
	METALLIC = metalico_final;
	ROUGHNESS = rugosidad_final;
}
