// MarchaBoton.gdshader - Shader para cada botón de marcha individual
shader_type canvas_item;

uniform float intensidad : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color_base = vec3(0.15, 0.18, 0.22);
uniform vec3 color_activo = vec3(0.25, 0.6, 0.9); // Azul más prudente
uniform bool es_activo = false;

void fragment() {
	// Fondo base
	vec3 fondo = mix(color_base, color_activo, float(es_activo) * 0.7);
	
	// Borde sutil
	vec2 borde_uv = abs(UV - 0.5) * 2.0;
	float borde = smoothstep(1.0, 0.95, max(borde_uv.x, borde_uv.y));
	vec3 borde_col = mix(vec3(0.25, 0.25, 0.25), vec3(0.4, 0.7, 1.0), float(es_activo) * 0.5);
	
	vec3 col = mix(fondo, borde_col, borde * 0.4);
	
	// Efecto de presión
	float presion_fade = sin(TIME * 3.0) * 0.1 + 0.1;
	float glow = mix(0.0, presion_fade, intensidad);
	
	COLOR = vec4(col + glow, 1.0);
}
