shader_type canvas_item;

uniform bool activo = false;
uniform vec4 color_activo = vec4(1.0, 1.0, 0.0, 1.0);  // Amarillo
uniform vec4 color_inactivo = vec4(1.0, 1.0, 1.0, 1.0); // Blanco
uniform float brillo_activo : hint_range(0.5, 2.0) = 1.4;

void fragment() {
	vec4 textura = texture(TEXTURE, UV);
	if (textura.a <= 0.001) {
		// ColorRect no tiene TEXTURE; usar el COLOR base del nodo.
		textura = COLOR;
	}
	
	// Calcular color objetivo basado en estado
	vec4 color_objetivo = activo ? color_activo : color_inactivo;
	float brillo_objetivo = activo ? brillo_activo : 1.0;
	
	// Aplicar color y brillo al icono (mantiene la transparencia original)
	vec3 color_final = textura.rgb * color_objetivo.rgb * brillo_objetivo;
	
	COLOR = vec4(color_final, textura.a);
}
