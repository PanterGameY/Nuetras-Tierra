shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

uniform vec4 line_color : source_color = vec4(0.2, 0.85, 0.35, 1.0);
uniform float line_thickness : hint_range(0.01, 0.3) = 0.06;
uniform float corner_radius : hint_range(0.05, 0.5) = 0.25; // Radio de esquinas redondeadas
uniform float trail_speed : hint_range(0.0, 10.0) = 3.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform bool es_circulo = false;

// SDF de caja con esquinas redondeadas
float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float dist_from_line = 0.0;
	float perimeter_coord = 0.0;

	if (es_circulo) {
		float dist = length(p) * 2.0; // 0 en centro, 1 en borde
		dist_from_line = abs(dist - (1.0 - line_thickness * 0.5));
		perimeter_coord = atan(p.y, p.x) / (2.0 * 3.14159265) + 0.5;
	} else {
		// Ajustar según el tamaño manteniendo esquinas suavemente redondeadas
		vec2 box_size = vec2(0.5 - line_thickness * 0.5);
		float sdf = sd_rounded_box(p, box_size, corner_radius * 0.4);
		dist_from_line = abs(sdf);
		
		// Coordenada perimetral continua para el trail que viaja alrededor
		perimeter_coord = (atan(p.y, p.x) / (2.0 * 3.14159265) + 0.5);
	}

	// Ancho de la línea con suavizado Antialiasing
	float half_width = line_thickness * 0.4;
	float alpha_line = smoothstep(half_width, half_width - 0.015, dist_from_line);
	
	// Resplandor exterior (Aura Neón suave)
	float aura = smoothstep(half_width * 2.5, 0.0, dist_from_line) * 0.45;

	if (alpha_line <= 0.001 && aura <= 0.001) {
		discard;
	}

	// ── Animación Dinámica ──
	// 1. Trail láser de energía que viaja a lo largo del borde
	float trail_1 = sin((perimeter_coord - TIME * trail_speed * 0.1) * 6.28318 * 2.0) * 0.5 + 0.5;
	trail_1 = pow(trail_1, 3.0); // Concentrar la intensidad en la cabeza del trail
	
	float trail_2 = sin((perimeter_coord + TIME * trail_speed * 0.15) * 6.28318 * 4.0) * 0.5 + 0.5;
	trail_2 = pow(trail_2, 5.0);

	// 2. Respiración/Pulsación rítmica
	float pulse = sin(TIME * pulse_speed) * 0.25 + 0.75;

	// Combinar efectos dinámicos
	float total_energy = (0.5 + trail_1 * 1.2 + trail_2 * 0.8) * pulse;
	
	vec3 base_rgb = line_color.rgb;
	vec3 emissive_rgb = base_rgb * (1.3 + total_energy * 1.5);
	
	float final_alpha = line_color.a * (alpha_line * (0.8 + total_energy * 0.4) + aura * pulse);

	ALBEDO = emissive_rgb;
	ALPHA = clamp(final_alpha, 0.0, 1.0);
}
