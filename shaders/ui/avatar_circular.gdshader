shader_type canvas_item;

uniform float border_width : hint_range(0.0, 0.2) = 0.045;
uniform vec4 border_color : source_color = vec4(0.88, 0.68, 0.28, 1.0); // Automotive Instrument Amber
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.35;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	
	// Suavizado anti-aliasing en el borde exterior
	float alpha = 1.0 - smoothstep(0.485, 0.5, dist);
	if (alpha <= 0.001) {
		discard;
	}
	
	float border_inner = 0.5 - border_width;
	if (dist > border_inner) {
		float t = smoothstep(border_inner, 0.5, dist);
		vec4 b_col = border_color;
		b_col.rgb += vec3(glow_intensity * (0.7 + 0.3 * t));
		COLOR = vec4(b_col.rgb, b_col.a * alpha);
	} else {
		vec4 tex = texture(TEXTURE, UV);
		float rim = smoothstep(border_inner - 0.04, border_inner, dist);
		tex.rgb = mix(tex.rgb, border_color.rgb * 0.35, rim * 0.4);
		COLOR = vec4(tex.rgb, tex.a * alpha);
	}
}
