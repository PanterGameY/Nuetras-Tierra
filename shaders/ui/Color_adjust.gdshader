shader_type canvas_item;

// Ajustes principales
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0; // desplazamiento de tono (en vueltas: 1.0 = 360°)
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float value_multiplier : hint_range(0.0, 2.0) = 1.0;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0; // suma después de conversión
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

// Convierte RGB -> HSV
vec3 rgb2hsv(vec3 c) {
    float r = c.r;
    float g = c.g;
    float b = c.b;
    float maxc = max(r, max(g, b));
    float minc = min(r, min(g, b));
    float d = maxc - minc;
    float h = 0.0;
    if (d < 1e-6) {
        h = 0.0;
    } else if (maxc == r) {
        h = mod((g - b) / d, 6.0);
    } else if (maxc == g) {
        h = (b - r) / d + 2.0;
    } else {
        h = (r - g) / d + 4.0;
    }
    h = h / 6.0;
    float s = (maxc < 1e-6) ? 0.0 : d / maxc;
    float v = maxc;
    return vec3(h, s, v);
}

// Convierte HSV -> RGB (truco GLSL)
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.x + vec3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 col = tex.rgb;
    vec3 modulate = COLOR.rgb; // modulate del nodo
    float in_alpha = tex.a * COLOR.a;

    // HSV adjustments
    vec3 hsv = rgb2hsv(col);
    hsv.x = fract(hsv.x + hue_shift); // envolver
    hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
    hsv.z = clamp(hsv.z * value_multiplier, 0.0, 1.0);
    vec3 out_rgb = hsv2rgb(hsv);

    // Brillo y contraste
    out_rgb += brightness;
    out_rgb = (out_rgb - 0.5) * contrast + 0.5;

    // Tinte
    out_rgb = mix(out_rgb, tint_color, tint_amount);

    // Aplicar modulate del nodo y alpha final
    out_rgb *= modulate;
    float out_alpha = in_alpha * alpha_multiplier;

    COLOR = vec4(out_rgb, out_alpha);
}
