shader_type canvas_item;

// Pictogramas del HUD a pie (se dibujan por SDF, no son texturas).
//   0 = sprint   -> tres chevrones de velocidad
//   1 = asomar izquierda
//   2 = asomar derecha
uniform int   icono = 0;
uniform float activo : hint_range(0.0, 1.0) = 0.0;
uniform float aspecto : hint_range(0.5, 6.0) = 2.78;

// Distancia con signo a un segmento con extremos redondeados.
float sd_segmento(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

// Chevron: dos segmentos que se juntan en un apice.
// dir = 1 apunta a la derecha, dir = -1 a la izquierda.
float chevron(vec2 p, float x0, float dir, float ancho, float alto, float grosor) {
    vec2 apice = vec2(x0 + ancho * dir, 0.0);
    return min(
        sd_segmento(p, apice, vec2(x0, -alto), grosor),
        sd_segmento(p, apice, vec2(x0,  alto), grosor)
    );
}

void fragment() {
    vec3 col_frio  = vec3(0.82, 0.87, 0.94);
    vec3 col_ambar = vec3(1.00, 0.80, 0.44);

    const float aa = 0.020;

    // Coordenadas centradas y corregidas por aspecto (alto = 1.0).
    vec2 p = vec2((UV.x - 0.5) * aspecto, UV.y - 0.5);

    float alfa  = 0.0;
    float forma = 1e5;

    if (icono == 0) {
        // ── Sprint: tres chevrones con peso creciente ─────────────────
        float deriva = sin(TIME * 2.4) * 0.014 * activo;
        for (int k = 0; k < 3; k++) {
            float xk   = -0.315 + float(k) * 0.26 + deriva;
            float d    = chevron(p, xk, 1.0, 0.110, 0.275, 0.052);
            float peso = 0.62 + 0.38 * (float(k) / 2.0);
            alfa  = max(alfa, smoothstep(aa, -aa, d) * peso);
            forma = min(forma, d);
        }
    } else {
        // ── Asomar: un chevron hacia el borde + riel exterior ─────────
        float dir = icono == 1 ? -1.0 : 1.0;
        float dchev = chevron(p, -0.255 * dir, dir, 0.250, 0.235, 0.048);
        float driel = sd_segmento(
            p,
            vec2(0.280 * dir, -0.215),
            vec2(0.280 * dir,  0.215),
            0.022
        );
        alfa  = max(smoothstep(aa, -aa, dchev), smoothstep(aa, -aa, driel) * 0.70);
        forma = min(dchev, driel);
    }

    // Halo calido que solo respira cuando el boton esta activo.
    float halo = (1.0 - smoothstep(0.0, 0.15, forma)) * activo;

    vec3  col_icono = mix(col_frio, col_ambar, activo);
    float a_icono   = clamp(alfa * (0.62 + 0.38 * activo), 0.0, 1.0);

    vec3 rgb = mix(col_icono, col_ambar, clamp(halo * 0.45, 0.0, 1.0));
    float a  = max(a_icono, halo * 0.30);

    COLOR = vec4(rgb, clamp(a, 0.0, 1.0));
}
