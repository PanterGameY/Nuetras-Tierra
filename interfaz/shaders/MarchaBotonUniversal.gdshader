shader_type canvas_item;

// Modernized button shader: glass + neon glow + subtle sheen
uniform bool activo = false;
uniform vec3 color_activo : source_color = vec3(1.0, 0.55, 0.12);
uniform vec3 color_inactivo : source_color = vec3(1.0, 1.0, 1.0);
uniform float opacidad_activo : hint_range(0.0, 1.0) = 1.0;
uniform float opacidad_inactivo : hint_range(0.0, 1.0) = 0.62;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.24;
uniform float time_scale : hint_range(0.0, 10.0) = 1.0;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float sdRoundedRect(vec2 p, vec2 b, float r) {
    vec2 d = abs(p) - b + vec2(r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

void fragment() {
    vec2 uv = UV - 0.5;
    vec3 base_dark = vec3(0.03, 0.04, 0.06);
    vec3 color_tema = activo ? color_activo : color_inactivo;

    // Rounded-rect mask for square-ish buttons with soft corners
    float d = sdRoundedRect(uv, vec2(0.46, 0.46), 0.12);
    float mask = smoothstep(0.02, -0.02, d);

    // Subtle radial gradient to give depth
    float radial = 1.0 - pow(length(uv) * 1.05, 1.4);
    vec3 col = base_dark * 0.8 + vec3(0.06, 0.07, 0.1) * radial * 0.7;

    // Micro surface noise for material feel
    float n = hash12(UV * 160.0);
    col += (n - 0.5) * rugosidad * 0.08;

    // Dynamic sheen that moves subtly
    float sheen_pos = fract(TIME * 0.4 * time_scale + uv.x * 0.6);
    float sheen = smoothstep(0.0, 0.6, 1.0 - abs(sheen_pos - 0.5) * 2.0);
    sheen = pow(sheen, 3.0) * (activo ? 1.0 : 0.25);
    col += vec3(1.0) * sheen * 0.18;

    // Neon halo when active (based on distance to center)
    float halo = smoothstep(0.6, 0.5, length(uv));
    float glow_strength = activo ? 0.9 : 0.12;
    col = mix(col, col + color_tema * 1.2 * glow_strength, halo * 0.6);

    // Rim highlight for metallic feel
    float rim = smoothstep(0.55, 0.5, length(uv));
    col += color_tema * rim * (activo ? 0.55 : 0.12);

    float alpha_final = mask * (activo ? opacidad_activo : opacidad_inactivo);
    COLOR = vec4(col, alpha_final);
}