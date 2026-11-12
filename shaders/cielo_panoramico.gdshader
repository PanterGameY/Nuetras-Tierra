shader_type sky;

// Textura panorámica del cielo (imagen equirrectangular)
uniform sampler2D textura_panorama : filter_linear, source_color;

// Color con el que se modula o tiñe el cielo (cambia según la hora del día)
uniform vec4 tinte_cielo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Multiplicador de exposición / brillo
uniform float exposicion : hint_range(0.0, 4.0, 0.05) = 1.0;

// Rotación horizontal en grados (para alinear el cielo o dar movimiento)
uniform float rotacion_horizontal : hint_range(0.0, 360.0, 0.1) = 0.0;

void sky() {
	// Proyección panorámica con rotación en el eje horizontal
	vec2 uv = SKY_COORDS;
	uv.x = fract(uv.x + (rotacion_horizontal / 360.0));

	// Muestreo de la imagen panorámica
	vec4 color_textura = texture(textura_panorama, uv);

	// Modulación de tono y brillo
	COLOR = color_textura.rgb * tinte_cielo.rgb * exposicion;
}
