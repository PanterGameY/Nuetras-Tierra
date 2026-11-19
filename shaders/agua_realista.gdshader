shader_type spatial;
render_mode depth_draw_always, cull_disabled;

// Texture de Profundidad de Pantalla para Detección de Orilla (Godot 4)
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

// ── Objetos Interactivos (Vehículos, Jugadores) ──
// Array de hasta 8 objetos interactivos (x, y, z, radio_influencia)
uniform vec4 objetos_interactivos[8];
uniform int cantidad_objetos = 0;
uniform float fuerza_onda_interaccion : hint_range(0.0, 1.0) = 0.35;

// ── Texturas de Olas y Normales ──
uniform sampler2D textura_normal1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_normal2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_espuma : hint_default_white, filter_linear_mipmap, repeat_enable;

// ── Colores Naturales del Agua ──
uniform vec4 color_orilla : source_color = vec4(0.12, 0.42, 0.45, 0.5);   // Verde turquesa de orilla
uniform vec4 color_profundo : source_color = vec4(0.02, 0.12, 0.22, 0.95); // Azul verdoso profundo
uniform vec4 color_espuma : source_color = vec4(0.95, 0.98, 1.0, 0.95);   // Espuma blanca agitada

// ── Detección y Controles Avanzados de Espuma ──
uniform float distancia_espuma_orilla : hint_range(0.1, 5.0) = 1.2;
uniform float velocidad_espuma : hint_range(0.0, 5.0) = 1.8;
uniform float intensidad_espuma : hint_range(0.1, 3.0) = 1.5;
uniform float escala_burbujas_espuma : hint_range(1.0, 30.0) = 12.0; // Escala de células de burbujas
uniform float espuma_cresta_olas : hint_range(0.0, 1.0) = 0.45;      // Espuma en picos de olas

// ── Propiedades PBR de Superficie ──
uniform float rugosidad : hint_range(0.0, 1.0) = 0.05;
uniform float metalico : hint_range(0.0, 1.0) = 0.05;
uniform float fresnel_potencia : hint_range(0.5, 8.0) = 3.5;

// ── Oleaje y Corriente ──
uniform float velocidad_olas : hint_range(0.0, 5.0) = 1.0;
uniform float altura_olas : hint_range(0.0, 1.5) = 0.12;
uniform float escala_olas : hint_range(0.1, 20.0) = 3.5;
uniform float fuerza_normal : hint_range(0.0, 3.0) = 1.2;

// Ruido pseudo-aleatorio para patrón Voronoi
vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Algoritmo de Células de Espuma / Burbujas estilo Voronoi
float voronoi_espuma(vec2 p, float time) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			o = 0.5 + 0.5 * sin(time * 2.0 + 6.2831 * o);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
			}
		}
	}
	return sqrt(md);
}

// Cálculo de oleaje 3D en vértices
float calcular_olas(vec2 p, float t) {
	float o1 = sin(p.x * escala_olas * 0.5 + t * velocidad_olas) * 0.5;
	float o2 = cos((p.y * 0.7 + p.x * 0.4) * escala_olas * 0.5 + t * velocidad_olas * 1.2) * 0.5;
	return (o1 + o2) * altura_olas;
}

// Cálculo de deformación de ondas de estela por vehículos
float calcular_onda_vehiculos(vec2 pos_world, float t) {
	float h_interaccion = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= cantidad_objetos) break;
		vec4 obj = objetos_interactivos[i];
		float dist = length(pos_world - obj.xz);
		float radio_max = max(1.5, obj.w * 2.5);
		if (dist < radio_max) {
			float factor_dist = (1.0 - (dist / radio_max));
			float onda = sin(dist * 6.0 - t * 8.0) * exp(-dist * 1.2);
			h_interaccion += onda * factor_dist * fuerza_onda_interaccion;
		}
	}
	return h_interaccion;
}

varying float v_wave_height;
varying vec3 v_world_pos;

void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vec2 pos_world = wp.xz;
	float h_olas = calcular_olas(pos_world, TIME);
	float h_inter = calcular_onda_vehiculos(pos_world, TIME);
	
	VERTEX.y += h_olas + h_inter;
	v_wave_height = h_olas + h_inter;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 pos_world = v_world_pos.xz;
	vec2 uv_anim1 = pos_world * (escala_olas * 0.1) + vec2(TIME * velocidad_olas * 0.03, TIME * velocidad_olas * 0.02);
	vec2 uv_anim2 = pos_world * (escala_olas * 0.15) - vec2(TIME * velocidad_olas * 0.02, -TIME * velocidad_olas * 0.03);

	// ── 1. Mapa de Normales Doble ──
	vec3 n1 = texture(textura_normal1, uv_anim1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(textura_normal2, uv_anim2).rgb * 2.0 - 1.0;
	vec3 normal_combinada = normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));
	NORMAL = normalize(mix(NORMAL, TANGENT * normal_combinada.x + BINORMAL * normal_combinada.y + NORMAL * normal_combinada.z, fuerza_normal));

	// ── 2. Detección de Profundidad con DEPTH_TEXTURE ──
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
	float depth_scene = -view_pos.z / view_pos.w;
	float depth_water = -VERTEX.z;
	float depth_diff = depth_scene - depth_water;

	// ── 3. Generación Avanzada de Espuma Estilo Voronoi / Burbujas Marinas ──
	vec2 uv_voro = pos_world * escala_burbujas_espuma * 0.2 + vec2(TIME * velocidad_espuma * 0.04);
	float burbujas_voro = 1.0 - voronoi_espuma(uv_voro, TIME * 0.5);
	burbujas_voro = smoothstep(0.35, 0.85, burbujas_voro);

	// Ondas pulsantes en orilla
	float factor_orilla = clamp(1.0 - (depth_diff / distancia_espuma_orilla), 0.0, 1.0);
	float onda_lavado_1 = sin(depth_diff * 14.0 - TIME * velocidad_espuma * 2.2) * 0.5 + 0.5;
	float onda_lavado_2 = cos(depth_diff * 8.0 - TIME * velocidad_espuma * 1.5) * 0.5 + 0.5;
	
	float tex_espuma_val = texture(textura_espuma, pos_world * 0.15 + vec2(TIME * velocidad_espuma * 0.03)).r;
	float patron_espuma_orilla = (burbujas_voro * 0.6 + tex_espuma_val * 0.4) * (onda_lavado_1 * 0.6 + onda_lavado_2 * 0.4 + 0.3);
	float mascara_espuma_orilla = smoothstep(0.15, 0.6, factor_orilla * patron_espuma_orilla) * factor_orilla;

	// Espuma adicional en crestas
	float mascara_espuma_cresta = smoothstep(altura_olas * (1.0 - espuma_cresta_olas), altura_olas, v_wave_height) * burbujas_voro * 0.7;

	// Espuma dinámica de chapoteo alrededor de vehículos y jugador
	float mascara_espuma_vehiculo = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= cantidad_objetos) break;
		vec4 obj = objetos_interactivos[i];
		float dist = length(pos_world - obj.xz);
		float radio_max = max(1.5, obj.w * 2.2);
		if (dist < radio_max) {
			float f_dist = 1.0 - (dist / radio_max);
			mascara_espuma_vehiculo += smoothstep(0.2, 0.8, f_dist * (burbujas_voro * 0.7 + 0.3)) * f_dist;
		}
	}

	// Máscara final de espuma (Orilla + Crestas + Vehículos)
	float mascara_espuma = clamp((mascara_espuma_orilla + mascara_espuma_cresta + mascara_espuma_vehiculo * 0.9) * intensidad_espuma, 0.0, 1.0);

	// ── 4. Fresnel y Mezcla de Colores PBR ──
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_potencia);
	float factor_profundidad = clamp(depth_diff / 3.0, 0.0, 1.0);
	
	vec3 color_base = mix(color_orilla.rgb, color_profundo.rgb, factor_profundidad);
	vec3 color_final = mix(color_base, color_espuma.rgb, mascara_espuma * color_espuma.a);
	
	color_final = mix(color_final, vec3(0.85, 0.94, 1.0), fresnel * 0.5);

	ALBEDO = color_final;
	ROUGHNESS = mix(rugosidad, 0.6, mascara_espuma);
	METALLIC = metalico;
	SPECULAR = 0.7;
	ALPHA = clamp(mix(color_orilla.a, color_profundo.a, factor_profundidad) + mascara_espuma * 0.9 + fresnel * 0.2, 0.0, 1.0);
}
