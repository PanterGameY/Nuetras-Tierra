shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform int superficie_tipo = 0; // 0: Estandar, 1: Asfalto Nuevo, 2: Asfalto Desgastado, 3: Adoquin, 4: Recebo, 5: Ciclovia
uniform int demarcacion_tipo = 0; // 0: Discontinua Blanca, 1: Continua Amarilla, 2: Doble Amarilla, 3: Sin Lineas
uniform float num_carriles = 2.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// UV.x: 0..1 a lo ancho de la calzada, UV.y: metros a lo largo del tramo
	float u = clamp(UV.x, 0.0, 1.0);
	float v = UV.y;

	vec3 base_col = vec3(0.14, 0.15, 0.17);
	float rough = 0.78;
	float grano = noise(vec2(u * 28.0, v * 3.5));

	if (superficie_tipo == 1) {
		// Asfalto Nuevo (oscuro, grano fino)
		base_col = mix(vec3(0.08, 0.085, 0.095), vec3(0.12, 0.125, 0.14), grano);
		rough = 0.62;
	} else if (superficie_tipo == 2) {
		// Asfalto Desgastado (gris claro con desgaste en rodadas)
		float desgaste = noise(vec2(u * 6.0, v * 0.4));
		base_col = mix(vec3(0.20, 0.21, 0.22), vec3(0.30, 0.30, 0.31), grano * 0.6 + desgaste * 0.4);
		rough = 0.88;
	} else if (superficie_tipo == 3) {
		// Adoquin colonial
		float bx = fract(u * 16.0 + floor(v * 3.5) * 0.5);
		float by = fract(v * 3.5);
		float junta = step(0.08, bx) * step(0.08, by);
		float tono = hash21(vec2(floor(u * 16.0 + floor(v * 3.5) * 0.5), floor(v * 3.5)));
		vec3 piedra = mix(vec3(0.36, 0.31, 0.27), vec3(0.50, 0.44, 0.38), tono);
		base_col = mix(vec3(0.18, 0.16, 0.14), piedra, junta);
		rough = mix(0.95, 0.80, junta);
	} else if (superficie_tipo == 4) {
		// Recebo / Grava compactada
		float grava = noise(vec2(u * 40.0, v * 6.0));
		base_col = mix(vec3(0.42, 0.35, 0.26), vec3(0.58, 0.50, 0.39), grava * 0.7 + grano * 0.3);
		rough = 0.94;
	} else if (superficie_tipo == 5) {
		// Ciclovia / Sendero Terracota
		base_col = mix(vec3(0.54, 0.21, 0.16), vec3(0.64, 0.26, 0.20), grano);
		rough = 0.72;
	} else {
		// Asfalto Estandar
		base_col = mix(vec3(0.13, 0.14, 0.16), vec3(0.18, 0.19, 0.21), grano);
		rough = 0.76;
	}

	// Bordes laterales blancos (si no es Sin Lineas)
	if (demarcacion_tipo != 3) {
		float edge_l = smoothstep(0.035, 0.042, u) * (1.0 - smoothstep(0.055, 0.062, u));
		float edge_r = smoothstep(0.938, 0.945, u) * (1.0 - smoothstep(0.958, 0.965, u));
		float edge_mask = max(edge_l, edge_r);
		base_col = mix(base_col, vec3(0.92, 0.92, 0.90), edge_mask * 0.9);
	}

	// Linea central segun demarcacion_tipo
	if (num_carriles >= 2.0 && demarcacion_tipo != 3) {
		float dash = step(0.45, fract(v * 0.12));
		if (demarcacion_tipo == 0) {
			// Discontinua Blanca
			float c_mask = (1.0 - smoothstep(0.008, 0.014, abs(u - 0.5))) * dash;
			base_col = mix(base_col, vec3(0.94, 0.94, 0.92), c_mask * 0.92);
		} else if (demarcacion_tipo == 1) {
			// Continua Amarilla
			float c_mask = 1.0 - smoothstep(0.009, 0.015, abs(u - 0.5));
			base_col = mix(base_col, vec3(0.95, 0.72, 0.12), c_mask * 0.95);
		} else if (demarcacion_tipo == 2) {
			// Doble Amarilla
			float l1 = 1.0 - smoothstep(0.006, 0.011, abs(u - 0.482));
			float l2 = 1.0 - smoothstep(0.006, 0.011, abs(u - 0.518));
			base_col = mix(base_col, vec3(0.95, 0.72, 0.12), max(l1, l2) * 0.95);
		}
	}

	ALBEDO = base_col;
	ROUGHNESS = rough;
}
