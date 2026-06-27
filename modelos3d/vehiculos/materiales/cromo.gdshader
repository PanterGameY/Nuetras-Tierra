shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Parámetros del cromo
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float specular : hint_range(0.0, 1.0) = 1.0;
uniform vec4 chrome_tint : source_color = vec4(0.95, 0.95, 1.0, 1.0);
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float reflection_intensity : hint_range(0.0, 2.0) = 1.5;

// Parámetros de Clearcoat (Capa de brillo extra para cromo premium)
uniform float clearcoat : hint_range(0.0, 1.0) = 1.0;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.02;

// Textura de ambiente para reflejos (opcional)
uniform sampler2D environment_map : hint_default_white;
uniform bool use_environment_map = false;

// Parámetros del sistema de suciedad (Dirt)
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dirt_color : source_color = vec4(0.35, 0.27, 0.18, 1.0); // Tono marrón tierra/polvo
uniform sampler2D dirt_noise_tex : hint_default_white;
uniform vec2 dirt_tile = vec2(3.0, 3.0);

void fragment() {
	// Color base plateado/cromo
	vec3 base_color = chrome_tint.rgb;
	
	// Calcular reflejo ambiental si hay textura
	if (use_environment_map) {
		vec3 reflected = reflect(VIEW, NORMAL);
		vec4 env_color = texture(environment_map, reflected.xy * 0.5 + 0.5);
		base_color = mix(base_color, env_color.rgb, reflection_intensity * 0.5);
	}
	
	// Efecto rim (borde de luz) para mayor realismo en siluetas metálicas
	float rim = 1.0 - max(dot(VIEW, NORMAL), 0.0);
	rim = pow(rim, 3.0);
	base_color += vec3(rim) * rim_intensity;
	
	// --- Sistema de Suciedad (Dust/Polvo System) ---
	// Muestreamos el ruido
	float noise_val = texture(dirt_noise_tex, UV * dirt_tile).r;
	
	// Para un efecto de polvo suave, combinamos el ruido y el dirt_amount de forma muy difuminada
	// en lugar de manchas de barro con bordes definidos.
	float final_dirt = mix(0.0, noise_val, dirt_amount) * dirt_amount;
	
	// Aplicar propiedades PBR combinadas con la suciedad (polvo)
	ALBEDO = mix(base_color, dirt_color.rgb, final_dirt * 0.8); // El polvo es translúcido, limitamos su opacidad máxima
	METALLIC = mix(metallic, 0.15, final_dirt); // El polvo atenúa el metalizado, pero no lo apaga por completo de inmediato
	ROUGHNESS = mix(roughness, 0.7, final_dirt); // Aumenta la rugosidad de forma más suave
	SPECULAR = mix(specular, 0.3, final_dirt);
	
	// El clearcoat se reduce gradualmente con el polvo
	CLEARCOAT = mix(clearcoat, 0.1, final_dirt);
	CLEARCOAT_ROUGHNESS = mix(clearcoat_roughness, 0.8, final_dirt);
	
	// Añadir emisión muy sutil en las zonas limpias para destacar reflejos
	EMISSION = mix(base_color * 0.02, vec3(0.0), final_dirt);
}
