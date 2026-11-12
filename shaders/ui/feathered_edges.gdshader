shader_type canvas_item;

uniform float feather_margin : hint_range(0.01, 0.5) = 0.18;

void fragment() {
	vec2 uv = UV;
	vec4 col = texture(TEXTURE, uv);

	// Distancia hacia los 4 bordes del rectángulo (0 en los bordes, 0.5 en el centro)
	vec2 edge = min(uv, 1.0 - uv);
	float dist = min(edge.x, edge.y);

	// Suavizado/Difuminado transparente progresivo en el perímetro
	float alpha_mask = smoothstep(0.0, feather_margin, dist);

	COLOR = vec4(col.rgb, col.a * alpha_mask * COLOR.a);
}
