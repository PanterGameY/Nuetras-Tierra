shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;

// ── Texturas y PBR ──
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 color_albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rugosidad : hint_range(0.0, 1.0) = 0.7;
uniform float umbral_alpha : hint_range(0.0, 1.0) = 0.45; // Umbral de Alpha Scissor para hojas

// ── Viento ──
uniform float fuerza_viento : hint_range(0.0, 5.0) = 0.6;
uniform float velocidad_viento : hint_range(0.0, 10.0) = 3.0;
uniform float altura_minima = 0.0;
uniform float sensibilidad_altura = 0.8;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Calcular el peso de viento usando la altura relativa local en Y
	float h = max(0.0, VERTEX.y - altura_minima);
	float peso = pow(h * sensibilidad_altura, 1.3);

	// Deformación de viento fluida
	float swing_x = sin(TIME * velocidad_viento + world_pos.x * 0.4) * 0.15 * fuerza_viento * peso;
	float swing_z = cos(TIME * velocidad_viento * 0.85 + world_pos.z * 0.4) * 0.15 * fuerza_viento * peso;
	
	// Micro temblor en las hojas
	float flutter = sin(TIME * velocidad_viento * 4.0 + world_pos.y * 5.0) * 0.03 * fuerza_viento * peso;

	VERTEX.x += swing_x + flutter;
	VERTEX.z += swing_z + flutter;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV) * color_albedo;
	ALBEDO = tex_color.rgb;
	ALPHA = tex_color.a;
	ALPHA_SCISSOR_THRESHOLD = umbral_alpha; // Activa Alpha Scissor en Godot 4
	ROUGHNESS = rugosidad;
}
