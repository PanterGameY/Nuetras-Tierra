//shader de velocimetro para el dashboard
shader_type canvas_item;

//tacometro de revoluciones por minuto
uniform float rpm : hint_range(0.0, 8000.0) = 0.0;
uniform float max_rpm : hint_range(0.0, 8000.0) = 8000.0;
uniform float needle_length : hint_range(0.0, 200.0) = 100.0;
uniform vec2 canvas_size = vec2(200.0, 200.0);
uniform vec4 needle_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 background_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 tick_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int num_ticks : hint_range(1, 20) = 10; //Número de marcas en el tacómetro
uniform float tick_length : hint_range(0.0, 20.0) = 10.0;
uniform float tick_width : hint_range(0.0, 5.0) = 2.0;
uniform float tick_offset : hint_range(0.0, 20.0) = 20.0; //Distancia desde el borde del velocímetro
uniform float start_angle : hint_range(-360.0, 360.0) = -135.0; //Ángulo de inicio del tacómetro
uniform float end_angle : hint_range(-360.0, 360.0) = 135.0; //Ángulo de fin del tacómetro

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float denom = max(dot(ba, ba), 1e-6);
    float h = clamp(dot(pa, ba) / denom, 0.0, 1.0);
    return length(pa - ba * h);
}

void fragment() {
    vec2 size = canvas_size;
    vec2 center = size * 0.5;
    vec2 p = UV * size;

    vec4 out_col = vec4(0.0);
    float meter_radius = min(size.x, size.y) * 0.5;

    // Fondo (círculo relleno)
    float d = length(p - center);
    float bg_mask = 1.0 - smoothstep(meter_radius - 1.0, meter_radius + 1.0, d);
    out_col = mix(out_col, background_color, bg_mask);

    // Marcas del tacómetro
    int denom = num_ticks - 1;
    if (denom < 1) { denom = 1; }
    for (int i = 0; i < num_ticks; i++) {
        float t = float(i) / float(denom);
        float angle = mix(radians(start_angle), radians(end_angle), t);
        vec2 dir = vec2(cos(angle), sin(angle));
        vec2 a = center + dir * (meter_radius - tick_offset);
        vec2 b = a + dir * tick_length;
        float dseg = sdSegment(p, a, b);
        float tick_mask = 1.0 - smoothstep(tick_width * 0.5 - 0.5, tick_width * 0.5 + 0.5, dseg);
        out_col = mix(out_col, tick_color, tick_mask);
    }

    // Aguja del tacómetro
    float rpm_ratio = clamp(rpm / max_rpm, 0.0, 1.0);
    float needle_angle = mix(radians(start_angle), radians(end_angle), rpm_ratio);
    vec2 ndir = vec2(cos(needle_angle), sin(needle_angle));
    vec2 nend = center + ndir * needle_length;
    float needle_half = 3.0 * 0.5;
    float dneedle = sdSegment(p, center, nend);
    float needle_mask = 1.0 - smoothstep(needle_half - 0.5, needle_half + 0.5, dneedle);
    out_col = mix(out_col, needle_color, needle_mask);

    COLOR = out_col;
}
