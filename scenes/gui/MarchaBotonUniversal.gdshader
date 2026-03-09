shader_type canvas_item;

uniform bool activo = false;
uniform vec3 color_activo : source_color = vec3(1.0, 0.55, 0.12);
uniform vec3 color_inactivo : source_color = vec3(1.0, 1.0, 1.0);
uniform float opacidad_activo : hint_range(0.0, 1.0) = 1.0;
uniform float opacidad_inactivo : hint_range(0.0, 1.0) = 0.62;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.24;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

void fragment() {
    vec2 uv = UV - 0.5;
    vec3 col_fondo = vec3(0.05, 0.06, 0.08);
    vec3 color_tema = activo ? color_activo : color_inactivo;
    float d = sdCircle(uv, 0.47);
    float mask = smoothstep(0.01, -0.01, d);
    float borde = smoothstep(0.03, 0.0, abs(d));

    float n = hash12(UV * 120.0);
    float grano = (n - 0.5) * rugosidad;
    float opacidad_base = activo ? opacidad_activo : opacidad_inactivo;

    float glow = activo ? (1.0 - smoothstep(0.0, 0.8, length(uv) * 1.6)) : 0.0;

    vec3 col = col_fondo;
    col = mix(col, col + color_tema * (0.25 + grano), mask);
    col += color_tema * borde * 0.9;
    col += color_tema * glow * mask * 0.35;

    float alpha_final = clamp(mask + borde * 0.2, 0.0, 1.0) * clamp(opacidad_base + grano * 0.45, 0.0, 1.0);
    COLOR = vec4(col, alpha_final);
}