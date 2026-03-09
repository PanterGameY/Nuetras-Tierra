shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Color y transparencia del vidrio
uniform vec4 glass_color : source_color = vec4(0.6, 0.7, 0.75, 1.0);
uniform float transparency : hint_range(0.0, 1.0) = 0.15;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;

// Propiedades del cristal
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float specular : hint_range(0.0, 1.0) = 0.9;

// Efecto Fresnel (más reflejo en ángulos rasantes)
uniform float fresnel_power : hint_range(1.0, 5.0) = 3.0;
uniform float fresnel_intensity : hint_range(0.0, 1.0) = 0.6;

// Suciedad y detalles
uniform sampler2D dirt_texture : hint_default_white;
uniform bool use_dirt_texture = false;
uniform float dirt_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dirt_color : source_color = vec4(0.4, 0.35, 0.3, 1.0);

// Normal map para detalles
uniform sampler2D normal_map : hint_normal;
uniform bool use_normal_map = false;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.3;

// Reflejo
uniform float reflection_intensity : hint_range(0.0, 2.0) = 1.0;

// Polarizado/ahumado
uniform bool tinted_glass = false;
uniform vec4 tint_color : source_color = vec4(0.2, 0.2, 0.25, 1.0);

void fragment() {
	// Color base del vidrio
	vec3 albedo = glass_color.rgb;
	
	// Aplicar tinte si está activado
	if (tinted_glass) {
		albedo = mix(albedo, tint_color.rgb, tint_strength);
	}
	
	// Efecto Fresnel - más reflejo en ángulos rasantes
	float fresnel = pow(1.0 - max(dot(VIEW, NORMAL), 0.0), fresnel_power);
	float final_transparency = transparency * (1.0 - fresnel * fresnel_intensity);
	
	// Suciedad
	if (use_dirt_texture && dirt_intensity > 0.0) {
		float dirt = texture(dirt_texture, UV).r * dirt_intensity;
		albedo = mix(albedo, dirt_color.rgb, dirt);
		final_transparency = mix(final_transparency, 1.0, dirt * 0.5);
	}
	
	ALBEDO = albedo;
	ALPHA = 1.0 - final_transparency;
	
	// Propiedades del material
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	
	// Normal map para detalles sutiles
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_map, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	
	// Emisión sutil para simular brillo del vidrio
	EMISSION = albedo * 0.02 * (1.0 - final_transparency);
	
	// RIM para bordes brillantes
	float rim = 1.0 - max(dot(VIEW, NORMAL), 0.0);
	rim = pow(rim, 4.0);
	EMISSION += vec3(rim * 0.1);
}
