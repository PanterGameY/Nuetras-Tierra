shader_type canvas_item;

uniform vec4 color_carcasa = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 color_marco = vec4(0.15, 0.15, 0.18, 1.0);
uniform float radio_esquina : hint_range(0.0, 0.3) = 0.08;
uniform float grosor_marco : hint_range(0.0, 0.15) = 0.08;
uniform float altura_notch : hint_range(0.0, 0.2) = 0.08;
uniform float brillo : hint_range(0.0, 2.0) = 1.2;

// Función para dibujar esquinas redondeadas
float esquinas_redondeadas(vec2 uv, float radio) {
	vec2 esquina = abs(uv - 0.5);
	esquina = max(esquina - (0.5 - radio), vec2(0.0));
	return 1.0 - smoothstep(radio, radio + 0.02, length(esquina));
}

// Función para dibujar el notch (muesca superior)
float notch(vec2 uv) {
	// Notch en la parte superior central
	if (uv.y > 1.0 - altura_notch * 1.5) {
		float distancia = abs(uv.x - 0.5);
		float ancho_notch = 0.25;
		if (distancia < ancho_notch) {
			float curve = smoothstep(altura_notch * 0.5, 0.0, abs(uv.y - (1.0 - altura_notch)));
			return curve;
		}
	}
	return 0.0;
}

void fragment() {
	vec2 uv = UV;
	
	// Marco exterior (carcasa)
	float marco_dist = esquinas_redondeadas(uv, radio_esquina);
	
	// Marco interior (pantalla)
	vec2 pantalla_uv = (uv - 0.5) / (1.0 - grosor_marco * 2.0) + 0.5;
	float pantalla_dist = esquinas_redondeadas(pantalla_uv, radio_esquina * 0.6);
	
	// Notch
	float notch_dist = notch(uv);
	
	// Si está fuera del marco principal, descartar
	if (marco_dist < 0.5) {
		discard;
	}
	
	// Marco (borde oscuro)
	float es_marco = 1.0 - smoothstep(grosor_marco - 0.02, grosor_marco + 0.02, 
			length((uv - 0.5) * 2.0) - (1.0 - grosor_marco * 2.5));
	
	vec4 color = color_carcasa;
	
	// Añadir gradiente sutil al marco
	float gradiente = mix(1.0, 1.3, uv.y);
	color = mix(color, color_marco * gradiente, es_marco);
	
	// Efecto de brillo en los bordes
	float borde_brillo = pow(1.0 - abs(uv.x - 0.5) * 2.0, 3.0) * 0.1;
	color.rgb += vec3(borde_brillo) * brillo;
	
	// Oscurecer el notch
	color = mix(color, color_marco * 0.5, notch_dist);
	
	COLOR = color;
}
