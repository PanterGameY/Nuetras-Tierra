shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

uniform vec4 neon_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 1.0;
uniform vec2 inner_box = vec2(0.34, 0.58);
uniform float softness : hint_range(0.05, 1.0) = 0.36;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = abs(p) - inner_box;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);

	// Caída suave hacia afuera del chasis y relleno tenue debajo del vehículo
	float outer_glow = exp(-max(d, 0.0) * max(d, 0.0) / max(softness * softness * 0.22, 0.001));
	float inner_atten = mix(0.42, 1.0, smoothstep(-0.28, 0.06, d));

	// Desvanecer en los bordes extremos del plano para evitar cortes cuadrados
	float edge_fade = (1.0 - smoothstep(0.75, 1.0, abs(p.x))) * (1.0 - smoothstep(0.75, 1.0, abs(p.y)));
	float glow = outer_glow * inner_atten * edge_fade;

	ALBEDO = neon_color.rgb * (0.65 + intensity * 0.95);
	ALPHA = clamp(glow * (0.35 + intensity * 0.45), 0.0, 0.92);
}
