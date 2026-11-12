shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 color_albedo : source_color = vec4(0.14, 0.85, 0.45, 0.45);
uniform float speed : hint_range(0.0, 10.0) = 2.5;
uniform float frequency : hint_range(0.1, 30.0) = 12.0;
uniform float amplitude : hint_range(0.0, 1.0) = 0.3;
uniform float fresnel_power : hint_range(0.1, 10.0) = 2.5;
uniform float glow_intensity : hint_range(1.0, 5.0) = 2.5;

// Parámetros de la pulsación (respiración) del checkpoint
uniform float scale_pulse_speed : hint_range(0.0, 10.0) = 1.5;
uniform float scale_pulse_strength : hint_range(0.0, 0.5) = 0.08;

void vertex() {
	// Modificar la posición de los vértices en los ejes laterales (X/Z)
	// para lograr una pulsación/respiración física del cilindro
	float pulse = 1.0 + sin(TIME * scale_pulse_speed) * scale_pulse_strength;
	VERTEX.x *= pulse;
	VERTEX.z *= pulse;
}

void fragment() {
	// Efecto Fresnel para iluminar los bordes laterales y dar aspecto holográfico/volumétrico
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	
	// Ondas sinusoidales ascendentes que simulan un escaneo de energía
	float wave1 = sin(UV.y * frequency - TIME * speed) * 0.5 + 0.5;
	float wave2 = cos(UV.y * (frequency * 1.5) + TIME * (speed * 0.8)) * 0.5 + 0.5;
	float combined_wave = mix(wave1, wave2, 0.4) * amplitude;
	
	// Pulsación suave adicional de luminosidad
	float glow_pulse = sin(TIME * scale_pulse_speed) * 0.15;
	
	// El color base recibe la intensidad de fresnel multiplicada por el color albedo
	ALBEDO = color_albedo.rgb * (1.0 + fresnel * (glow_intensity + glow_pulse));
	
	// Atenuar los extremos superior e inferior para evitar cortes bruscos en la geometría
	float vertical_fade = sin(UV.y * 3.14159);
	
	// Calcular opacidad final combinando el pulso de energía, el fresnel y la atenuación vertical
	ALPHA = color_albedo.a * vertical_fade * (0.4 + combined_wave + fresnel + glow_pulse * 0.5);
}
