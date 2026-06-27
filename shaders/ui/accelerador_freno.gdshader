// Shader: un único pedal moderno (CanvasItem)
// Dibuja la forma del pedal; use `accent_color` para indicar freno/accelerador.
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0; // 0 = sin presión, 1 = completamente presionado
uniform vec4 base_color : source_color = vec4(0.10, 0.11, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(0.0, 0.8, 0.15, 1.0); // cambie a rojo para freno
uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform float pedal_width : hint_range(0.02, 0.6) = 0.18; // semiancho (en UV)
uniform float pedal_height : hint_range(0.02, 0.6) = 0.32; // semialtura (en UV)
uniform float radius : hint_range(0.0, 0.5) = 0.06;
uniform float outline_width : hint_range(0.0, 0.12) = 0.01;
uniform vec2 pedal_center = vec2(0.5, 0.5);
uniform float rotation : hint_range(-45.0, 45.0) = 0.0; // grados
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.6;
uniform float glow : hint_range(0.0, 1.0) = 0.12;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float shadow_offset_y : hint_range(0.0, 0.08) = 0.02;
// Transparencia central suave
uniform float center_transparency : hint_range(0.0, 1.0) = 0.70;
uniform float center_radius : hint_range(0.0, 1.0) = 0.20;
uniform float center_falloff : hint_range(0.0, 0.6) = 0.12;

float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, vec2(0.0))) - r;
}

vec2 rotate(vec2 p, float ang) {
    float c = cos(ang);
    float s = sin(ang);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
    vec2 uv = UV;
    float aa = 0.0035;

    // coordenadas locales centradas en el pedal
    vec2 p = uv - pedal_center;
    float ang = rotation * (PI / 180.0);
    vec2 pr = rotate(p, -ang);

    vec2 b = vec2(pedal_width, pedal_height);

    // sombra (ligera, desplazada hacia abajo)
    vec2 pShadow = uv - (pedal_center + vec2(0.0, shadow_offset_y));
    vec2 prShadow = rotate(pShadow, -ang);
    float sdShadow = sdRoundRect(prShadow, b + vec2(0.01), radius + 0.01);
    float shadowMask = (1.0 - smoothstep(0.0, aa * 2.0, sdShadow)) * shadow_intensity;

    // SDF del pedal
    float sd = sdRoundRect(pr, b, radius);
    float inside = 1.0 - smoothstep(0.0, aa, sd);
    float inner = 1.0 - smoothstep(-outline_width - aa, -outline_width + aa, sd);
    float outlineMask = max(0.0, inside - inner);

    // distancia radial normalizada desde el centro (0 en el centro)
    float rnorm = length(pr / (b * 0.9));
    rnorm = clamp(rnorm, 0.0, 1.0);
    float centerMask = 1.0 - smoothstep(center_radius, center_radius + center_falloff, rnorm);
    centerMask *= inner;

    // coordenada vertical para gradiente sutil
    float localY = clamp((pr.y + b.y) / (2.0 * b.y), 0.0, 1.0);

    // gradiente base
    float grad = smoothstep(0.0, 1.0, localY);
    vec3 baseGrad = mix(base_color.rgb * 0.9, base_color.rgb * 1.18, grad * 0.35);

    // relleno uniforme según `amount` (mismo valor en todo el pedal)
    float amt = clamp(amount, 0.0, 1.0);
    vec3 filled = baseGrad;
    // ligero tinte hacia accent cuando se presiona (muy sutil)
    filled = mix(filled, mix(filled, accent_color.rgb, 0.05), amt * 0.6);

    // brillo
    float glossMask = pow(smoothstep(0.6, 1.0, localY), 2.0) * gloss_strength * inner;

    // rim fino para acentuar borde
    float rim = smoothstep(-aa, aa, sd + outline_width * 0.5) - smoothstep(-aa, aa, sd - outline_width * 0.5);
    rim *= 0.6;

    // color del outline cambia hacia `accent_color` según `amount`
    vec3 outlineCol = mix(outline_color.rgb, accent_color.rgb, pow(amt, 0.9));
    float outlineAlpha = mix(outline_color.a, 1.0, pow(amt, 0.9));

    // composición
    vec3 color = filled;
    color += vec3(1.0) * glossMask * 0.12;
    // rim acentuado por accent color
    color += accent_color.rgb * rim * amt * 0.9;
    // glow exterior usando accent color
    float glowMask = 1.0 - smoothstep(0.0, aa * 6.0, sd);
    color += accent_color.rgb * glow * glowMask * amt * 0.6;
    // aplicar outline coloreado
    color = mix(color, outlineCol, outlineMask * outlineAlpha);

    // transparencia suave en el centro
    float alphaCenter = 1.0 - center_transparency * centerMask;

    // aplicar sombra como oscurecimiento
    vec3 finalColor = mix(vec3(0.0), color, inside);
    finalColor = mix(finalColor, vec3(0.0), shadowMask * 0.6);

    float finalAlpha = clamp(inside * alphaCenter, 0.0, 1.0);
    COLOR = vec4(finalColor, finalAlpha);
}
