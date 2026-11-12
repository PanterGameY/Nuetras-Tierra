shader_type canvas_item;

// ── Textura del pedal (asignar desde el Inspector) ───────────────────────
uniform sampler2D pedal_texture;

// ── Control de presión (0 = sin presionar, 1 = máxima presión) ───────────
uniform float intensidad_presion : hint_range(0.0, 1.0) = 0.0;

// ── Cuánto se achica la imagen al presionar al máximo (0.10 = 10%) ───────
uniform float presion_escala : hint_range(0.0, 0.4) = 0.10;

// ── Color del tinte que aparece al presionar ─────────────────────────────
uniform vec4 color_presion : source_color = vec4(1.0, 0.2, 0.05, 1.0);

// ── Intensidad del tinte de color (0 = sin tinte, 1 = todo el color) ─────
uniform float presion_tinte : hint_range(0.0, 1.0) = 0.40;

// ── Oscurecimiento al presionar (simula hundimiento) ─────────────────────
uniform float presion_oscuridad : hint_range(0.0, 1.0) = 0.30;

// ── Opacidad global del pedal ────────────────────────────────────────────
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // 1. Escalar la UV respecto al centro:
    //    al presionar, la imagen se achica (zoom out centrado)
    float s = max(0.001, 1.0 - intensidad_presion * presion_escala);
    vec2 uv = (UV - vec2(0.5)) / s + vec2(0.5);

    // 2. Determinar si estamos dentro del área de la imagen escalada
    //    (fuera → transparente, evita que se repita)
    float en_rect = step(0.0, uv.x) * step(uv.x, 1.0)
                  * step(0.0, uv.y) * step(uv.y, 1.0);

    // 3. Muestrear la textura del pedal
    vec4 tex = texture(pedal_texture, clamp(uv, vec2(0.0), vec2(1.0)));

    // 4. Oscurecer según presión (simula hundimiento / sombra)
    tex.rgb *= 1.0 - intensidad_presion * presion_oscuridad;

    // 5. Tinte de color proporcional a la presión
    tex.rgb = mix(tex.rgb, color_presion.rgb, intensidad_presion * presion_tinte);

    // 6. Alfa final: usa el canal alpha de la textura, opacidad global y máscara del rect
    float alfa = tex.a * opacidad * en_rect;

    COLOR = vec4(tex.rgb, alfa);
}