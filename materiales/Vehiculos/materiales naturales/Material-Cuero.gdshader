shader_type spatial;

uniform vec4 leather_color : source_color = vec4(0.15, 0.08, 0.05, 1.0); // Negro/café oscuro
uniform float roughness_base : hint_range(0.0, 1.0) = 0.75;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.5;
uniform float grain_scale : hint_range(1.0, 50.0) = 20.0;  // Escala del grano
uniform float wear_strength : hint_range(0.0, 1.0) = 0.3;  // Desgaste en bordes
uniform vec4 wear_color : source_color = vec4(0.3, 0.18, 0.1, 1.0); // Color desgastado

// Hash simple para ruido procedural
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453);
}

// Ruido para simular grano de cuero
float leather_noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(dot(hash2(i + vec2(0,0)), f - vec2(0,0)),
            dot(hash2(i + vec2(1,0)), f - vec2(1,0)), u.x),
        mix(dot(hash2(i + vec2(0,1)), f - vec2(0,1)),
            dot(hash2(i + vec2(1,1)), f - vec2(1,1)), u.x), u.y
    );
}

void fragment() {
    vec2 uv = UV * grain_scale;

    // Capas de ruido para el grano del cuero
    float grain = leather_noise(uv) * 0.5 + 0.5;
    float grain2 = leather_noise(uv * 2.3 + vec2(5.1, 3.7)) * 0.5 + 0.5;
    float grain3 = leather_noise(uv * 5.0 + vec2(1.2, 8.4)) * 0.5 + 0.5;

    float combined_grain = grain * 0.5 + grain2 * 0.3 + grain3 * 0.2;

    // Color base con variación del grano
    vec3 color = mix(leather_color.rgb, leather_color.rgb * 1.3, combined_grain * 0.4);

    // Desgaste en bordes con fresnel
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
    color = mix(color, wear_color.rgb, fresnel * wear_strength);

    // Normal map procedural del grano
    float grain_dx = leather_noise(uv + vec2(0.1, 0.0)) - leather_noise(uv - vec2(0.1, 0.0));
    float grain_dy = leather_noise(uv + vec2(0.0, 0.1)) - leather_noise(uv - vec2(0.0, 0.1));
    vec3 grain_normal = normalize(vec3(grain_dx * normal_strength, grain_dy * normal_strength, 1.0));

    // Roughness variable (más rugoso en zonas desgastadas)
    float rough = roughness_base + combined_grain * 0.15 + fresnel * 0.1;
    rough = clamp(rough, 0.0, 1.0);

    ALBEDO = color;
    METALLIC = metallic;
    ROUGHNESS = rough;
    SPECULAR = specular - combined_grain * 0.1; // Menos brillo en zonas rugosas
    NORMAL_MAP = grain_normal;
    NORMAL_MAP_DEPTH = normal_strength;
}