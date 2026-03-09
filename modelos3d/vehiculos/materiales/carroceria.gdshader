shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Color de la pintura
uniform vec4 base_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform sampler2D base_texture : hint_default_white;
uniform bool use_base_texture = false;

// Propiedades del material
uniform float metallic : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float specular : hint_range(0.0, 1.0) = 0.6;

// Clearcoat (capa transparente brillante)
uniform float clearcoat : hint_range(0.0, 1.0) = 0.8;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.05;

// Acabado metálico/perlado
uniform bool metallic_paint = false;
uniform vec4 metallic_tint : source_color = vec4(0.9, 0.9, 1.0, 1.0);
uniform float metallic_intensity : hint_range(0.0, 1.0) = 0.3;

// Texturas adicionales
uniform sampler2D normal_map : hint_normal;
uniform bool use_normal_map = false;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

uniform sampler2D roughness_map : hint_default_white;
uniform bool use_roughness_map = false;

uniform sampler2D metallic_map : hint_default_white;
uniform bool use_metallic_map = false;

// Detalles y variación
uniform float ambient_occlusion : hint_range(0.0, 1.0) = 1.0;
uniform vec4 dirt_color : source_color = vec4(0.3, 0.25, 0.2, 1.0);
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Color base
	vec3 albedo = base_color.rgb;
	
	if (use_base_texture) {
		vec4 tex_color = texture(base_texture, UV);
		albedo *= tex_color.rgb;
	}
	
	// Efecto metálico/perlado
	if (metallic_paint) {
		float fresnel = pow(1.0 - max(dot(VIEW, NORMAL), 0.0), 3.0);
		albedo = mix(albedo, albedo * metallic_tint.rgb, fresnel * metallic_intensity);
	}
	
	// Suciedad
	if (dirt_amount > 0.0) {
		float dirt = pow(1.0 - NORMAL.y, 2.0) * dirt_amount;
		albedo = mix(albedo, dirt_color.rgb, dirt);
	}
	
	// Aplicar propiedades del material
	float final_metallic = metallic;
	if (use_metallic_map) {
		final_metallic *= texture(metallic_map, UV).r;
	}
	
	float final_roughness = roughness;
	if (use_roughness_map) {
		final_roughness *= texture(roughness_map, UV).r;
	}
	
	ALBEDO = albedo;
	METALLIC = final_metallic;
	ROUGHNESS = final_roughness;
	SPECULAR = specular;
	
	// Normal map
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_map, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	
	// Clearcoat
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	
	// Ambient Occlusion
	AO = ambient_occlusion;
}
