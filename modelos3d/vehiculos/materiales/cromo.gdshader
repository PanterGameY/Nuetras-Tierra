shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Parámetros del cromo
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float specular : hint_range(0.0, 1.0) = 0.8;
uniform vec4 chrome_tint : source_color = vec4(0.95, 0.95, 1.0, 1.0);
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float reflection_intensity : hint_range(0.0, 2.0) = 1.5;

// Textura de ambiente para reflejos
uniform sampler2D environment_map : hint_default_white;
uniform bool use_environment_map = false;

void fragment() {
	// Color base plateado/cromo
	vec3 base_color = chrome_tint.rgb;
	
	// Aplicar metallic alto para efecto cromado
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	
	// Calcular reflejo ambiental si hay textura
	if (use_environment_map) {
		vec3 reflected = reflect(VIEW, NORMAL);
		vec4 env_color = texture(environment_map, reflected.xy * 0.5 + 0.5);
		base_color = mix(base_color, env_color.rgb, reflection_intensity * 0.5);
	}
	
	// Efecto rim (borde de luz) para mayor realismo
	float rim = 1.0 - max(dot(VIEW, NORMAL), 0.0);
	rim = pow(rim, 3.0);
	base_color += vec3(rim) * rim_intensity;
	
	ALBEDO = base_color;
	
	// Añadir emisión sutil para mayor brillo
	EMISSION = base_color * 0.05;
}
