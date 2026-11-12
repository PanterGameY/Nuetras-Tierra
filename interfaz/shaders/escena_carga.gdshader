shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 amber : source_color = vec4(1.0, 0.62, 0.16, 1.0);
uniform vec4 blue : source_color = vec4(0.18, 0.38, 0.55, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float line(vec2 uv, float center, float width) {
	return 1.0 - smoothstep(width, width + 0.0018, abs(uv.y - center));
}

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.008, 0.012, 0.016);

	float horizon = smoothstep(0.72, 0.08, abs(uv.y - 0.48));
	float light_a = exp(-2.8 * distance(uv, vec2(0.18, 0.28)));
	float light_b = exp(-3.5 * distance(uv, vec2(0.82, 0.62)));
	col += blue.rgb * light_a * 0.12;
	col += amber.rgb * light_b * 0.10;
	col += amber.rgb * horizon * 0.022;

	vec2 grid_uv = uv * vec2(38.0, 22.0);
	vec2 grid = abs(fract(grid_uv - 0.5) - 0.5) / max(fwidth(grid_uv), vec2(0.001));
	float grid_line = 1.0 - min(min(grid.x, grid.y), 1.0);
	col += vec3(0.18, 0.25, 0.30) * grid_line * 0.018 * smoothstep(0.85, 0.18, uv.y);

	float scan_x = fract(TIME * 0.105);
	float scan = exp(-180.0 * abs(uv.x - scan_x));
	col += amber.rgb * scan * 0.075;
	col += vec3(0.7, 0.82, 0.9) * line(uv, fract(TIME * 0.10), 0.00055) * 0.035;

	float grain = hash21(floor(SCREEN_UV * 420.0) + fract(TIME));
	col += (grain - 0.5) * 0.018;

	float center = 1.0 - smoothstep(0.0, 0.72, length((uv - 0.5) * vec2(0.8, 1.0)));
	col += amber.rgb * center * progress * 0.018;
	COLOR = vec4(col, 1.0);
}