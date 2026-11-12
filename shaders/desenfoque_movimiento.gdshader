// desenfoque_movimiento.gdshader
// Shader de post-procesamiento para desenfoque direccional (Motion Blur)
// al girar rápidamente la cámara. Optimizado para dispositivos móviles y PC.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 direccion = vec2(1.0, 0.0);
uniform float intensidad : hint_range(0.0, 1.0) = 0.0;
uniform int muestras : hint_range(3, 12) = 5;

void fragment() {
	if (intensidad <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec4 col = vec4(0.0);
		float f_muestras = float(muestras);
		vec2 paso = direccion * (intensidad * 0.032) / f_muestras;
		
		for (int i = 0; i < muestras; i++) {
			float offset = float(i) - (f_muestras - 1.0) * 0.5;
			vec2 uv = clamp(SCREEN_UV + paso * offset, vec2(0.001), vec2(0.999));
			col += texture(screen_texture, uv);
		}
		COLOR = col / f_muestras;
	}
}
