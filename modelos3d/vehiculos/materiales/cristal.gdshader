shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// --- Color base del vidrio ---
uniform vec4 glass_color : source_color = vec4(0.55, 0.65, 0.68, 1.0);
uniform float transparency : hint_range(0.0, 1.0) = 0.12;

// --- Propiedades fisicas ---
uniform float roughness : hint_range(0.0, 1.0) = 0.04;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.95;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// --- Fresnel (angulos rasantes) ---
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.5;
uniform float fresnel_intensity : hint_range(0.0, 1.0) = 0.75;
// Color del reflejo en angulos rasantes (vidrio automotriz real tiene tinte azul-verde)
uniform vec4 fresnel_tint : source_color = vec4(0.5, 0.62, 0.65, 1.0);

// --- Micro-textura de superficie (microaranas, polvo atmosferico) ---
// Rugosidad base que hace que el cristal no sea "espejo perfecto"
uniform float surface_variation : hint_range(0.0, 0.1) = 0.018;

// --- Tinte polarizado / ahumado ---
uniform bool tinted_glass = false;
uniform vec4 tint_color : source_color = vec4(0.18, 0.22, 0.25, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.35;

// --- Suciedad y polvo ---
uniform sampler2D dirt_texture : hint_default_white;
uniform bool use_dirt_texture = false;
uniform float dirt_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dirt_color : source_color = vec4(0.38, 0.32, 0.26, 1.0);

// --- Normal map ---
uniform sampler2D normal_map_tex : hint_normal;
uniform bool use_normal_map = false;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.4;

// Funcion de hash para variacion de superficie
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void fragment() {
    // --- Color base del vidrio ---
    vec3 albedo = glass_color.rgb;

    // Tinte polarizado / ahumado
    if (tinted_glass) {
        albedo = mix(albedo, tint_color.rgb, tint_strength);
    }

    // --- Suciedad superficial ---
    float dirt = 0.0;
    if (use_dirt_texture && dirt_intensity > 0.0) {
        dirt = texture(dirt_texture, UV).r * dirt_intensity;
        albedo = mix(albedo, dirt_color.rgb, dirt * 0.6);
    }

    // --- Fresnel fisicamente correcto ---
    float NoV = max(dot(NORMAL, VIEW), 0.0);
    float fresnel = pow(1.0 - NoV, fresnel_power);
    float fresnel_factor = fresnel * fresnel_intensity;

    // En los bordes rasantes el cristal refleja y se vuelve casi opaco
    // (comportamiento real del vidrio laminado automotriz)
    vec3 final_albedo = mix(albedo, fresnel_tint.rgb, fresnel_factor * 0.45);

    // --- Variacion de micro-superficie (sin textura, procedimental) ---
    // Simula aranas microscopicas, polvo y microimperfecciones del vidrio real
    vec2 uv_scaled = UV * 180.0;
    float micro_rough = hash21(floor(uv_scaled));
    float micro_contrib = micro_rough * surface_variation;

    // Brillo especular con variacion realista
    float final_roughness = roughness + micro_contrib + dirt * 0.3;
    final_roughness = clamp(final_roughness, 0.0, 1.0);

    // --- Alpha / Transparencia ---
    // El vidrio es mas transparente al centro, mas opaco en los bordes (Fresnel)
    float base_alpha = 1.0 - transparency;
    float edge_opacity = mix(base_alpha, min(base_alpha + 0.55, 1.0), fresnel_factor);
    float dirt_opacity = mix(edge_opacity, min(edge_opacity + 0.4, 1.0), dirt * 0.7);
    float final_alpha = clamp(dirt_opacity, 0.05, 1.0);

    // --- Normal map ---
    if (use_normal_map) {
        NORMAL_MAP = texture(normal_map_tex, UV).rgb;
        NORMAL_MAP_DEPTH = normal_strength;
    }

    // --- Salidas ---
    ALBEDO = final_albedo;
    ALPHA = final_alpha;
    ROUGHNESS = final_roughness;
    METALLIC = metallic;
    SPECULAR = specular_strength;

    // Emision sutilisima para el rim y la auto-iluminacion del vidrio
    // Vidrio real emite muy poco, principalmente en los bordes
    float rim_glow = pow(fresnel, 3.0) * 0.06;
    EMISSION = final_albedo * rim_glow;
}
