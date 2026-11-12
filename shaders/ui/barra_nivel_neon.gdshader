shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.75;
uniform vec4 color_start : source_color = vec4(0.15, 0.95, 0.35, 1.0); // Neon Emerald/Green
uniform vec4 color_end : source_color = vec4(0.0, 0.85, 1.0, 1.0);   // Neon Cyan/Blue
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 0.85);
uniform float stripe_speed : hint_range(0.0, 5.0) = 1.2;
uniform float shine_speed : hint_range(0.0, 5.0) = 0.7;

void fragment() {
	vec2 uv = UV;
	
	vec4 final_color = bg_color;
	
	if (uv.x <= progress) {
		float p_uv = uv.x / max(progress, 0.001);
		
		// Gradient fill
		vec4 fill_color = mix(color_start, color_end, p_uv);
		
		// Animated diagonal energy stripes
		float stripe = sin((uv.x * 30.0 - uv.y * 12.0) - TIME * stripe_speed * 4.0);
		stripe = smoothstep(0.3, 0.8, stripe) * 0.22;
		
		// Moving specular shine
		float shine = sin((uv.x - TIME * shine_speed * 0.5) * 6.28);
		shine = pow(max(shine, 0.0), 5.0) * 0.4;
		
		// Top glass reflection
		float glass = smoothstep(0.5, 0.0, uv.y) * 0.25;
		
		fill_color.rgb += vec3(stripe + shine + glass);
		final_color = fill_color;
	} else {
		// Glass reflection on empty track
		float glass_bg = smoothstep(0.4, 0.0, uv.y) * 0.12;
		final_color.rgb += vec3(glass_bg);
	}
	
	// Edge pulse glow at progress line
	float edge_dist = abs(uv.x - progress);
	float edge = smoothstep(0.015, 0.0, edge_dist);
	final_color.rgb += vec3(edge * 0.6);
	
	COLOR = final_color;
}
