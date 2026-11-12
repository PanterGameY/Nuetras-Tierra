shader_type canvas_item;

uniform vec4 icon_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;
	
	// Manejar imágenes PNG con transparencia o con fondo blanco
	if (tex.a >= 0.98 && (tex.r + tex.g + tex.b) > 2.7) {
		alpha = 0.0;
	} else if (tex.a >= 0.98) {
		alpha = 1.0 - ((tex.r + tex.g + tex.b) / 3.0);
	}
	
	COLOR = vec4(icon_color.rgb * COLOR.rgb, alpha * COLOR.a);
}
