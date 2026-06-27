shader_type canvas_item;

uniform float tension : hint_range(0.0, 1.0) = 0.0;
uniform float en_suelo : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float hash1(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
        mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x),
        u.y
    );
}

float fbm(vec2 uv) {
    float v = 0.0; float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += noise(uv) * amp;
        uv = uv * 2.1 + vec2(1.7, 9.2);
        amp *= 0.5;
    }
    return v;
}

void fragment() {
    vec2  uv      = UV;
    vec2  center  = vec2(0.5);
    float d       = distance(uv, center);

    // Paleta identica al joystick
    vec3 col_dorado  = vec3(0.9,  0.75, 0.4);
    vec3 col_ambar   = vec3(1.0,  0.6,  0.15);
    vec3 col_blanco  = vec3(1.0,  1.0,  1.0);
    vec3 col_cristal = vec3(0.14, 0.17, 0.21);
    vec3 col_frio    = vec3(0.3,  0.55, 0.85);
    vec3 col_fuego   = vec3(1.0,  0.28, 0.05);
    vec3 col_energia = vec3(1.0,  0.55, 0.0);

    float angulo_pixel = atan(uv.y - center.y, uv.x - center.x);

    // Inactivo en el aire
    float inactivo = 1.0 - en_suelo;

    // =====================================================
    // 1. BASE CRISTAL
    // =====================================================
    float base_mask = smoothstep(0.46, 0.42, d);

    float heat_spd = mix(1.2, 4.5, tension);
    vec2  heat_uv  = uv * 5.5;
    heat_uv.x     += sin(uv.y * 12.0 + TIME * heat_spd) * mix(0.02, 0.05, tension);
    heat_uv.y     += cos(uv.x * 10.0 + TIME * heat_spd * 0.75) * mix(0.015, 0.04, tension);
    float tex      = fbm(heat_uv + vec2(TIME * 0.04, TIME * 0.025));
    float polar_grad  = cos(angulo_pixel * 2.0 - TIME * 0.35) * 0.5 + 0.5;
    float radial_grad = smoothstep(0.0, 0.46, d);

    // Destello cuando no hay tension
    float sweep_phase = fract(TIME / 6.0);
    float sweep_angle = sweep_phase * PI * 2.0 - PI;
    float sweep_proj  = dot(uv - center, vec2(cos(sweep_angle), sin(sweep_angle))) / 0.46;
    float sweep_band  = smoothstep(0.85, 1.0, sweep_proj) * smoothstep(1.0, 0.85, sweep_proj + 0.12);
    float sweep_glow  = sweep_band * smoothstep(0.0, 0.15, sweep_phase) * smoothstep(1.0, 0.85, sweep_phase) * 0.55 * (1.0 - tension);

    vec3 cristal_base = mix(col_cristal, vec3(0.22, 0.06, 0.04), tension * 0.7);
    cristal_base      = mix(cristal_base, vec3(0.08, 0.08, 0.12), inactivo * 0.8);
    vec3 cristal_rgb  = mix(cristal_base, cristal_base * 1.7, tex * 0.4 + polar_grad * 0.15);
    cristal_rgb      += col_blanco * sweep_glow * base_mask;
    float run_pulse   = sin(TIME * 8.0) * 0.5 + 0.5;
    cristal_rgb      += col_fuego * tension * run_pulse * 0.12 * base_mask * (1.0 - d * 2.0);

    float cristal_alpha = base_mask * mix(0.20, 0.42, radial_grad * tex + tension * 0.15) * mix(1.0, 0.4, inactivo);
    vec4 final_color = vec4(cristal_rgb, cristal_alpha);

    // =====================================================
    // 2. FRESNEL RIM
    // =====================================================
    float rim_mask  = smoothstep(0.46, 0.44, d) - smoothstep(0.44, 0.42, d);
    vec3  rim_col   = mix(col_cristal * 2.0, mix(col_dorado, col_ambar, tension * 0.6), tension);
    rim_col         = mix(rim_col, col_fuego * 1.2, tension * 0.85);
    rim_col         = mix(rim_col, col_frio * 0.5, inactivo * 0.7);
    float rim_alpha = rim_mask * mix(0.12, 0.60, tension) * (0.35 + tension * 0.9) * mix(1.0, 0.3, inactivo);
    final_color.rgb = mix(final_color.rgb, rim_col, rim_mask * rim_alpha);
    final_color.a   = max(final_color.a, rim_mask * rim_alpha);

    // =====================================================
    // 3. ANILLO EXTERIOR CON MARCAS
    // =====================================================
    float anillo_ext = smoothstep(0.47, 0.455, d) - smoothstep(0.455, 0.44, d);
    float taco       = smoothstep(0.92, 1.0, abs(sin(angulo_pixel * 9.0))) * 0.45;
    float a_taco     = smoothstep(0.47, 0.462, d) - smoothstep(0.462, 0.455, d);
    final_color.rgb += mix(col_dorado, col_frio, inactivo) * taco * a_taco * 0.6 * mix(1.0, 0.3, inactivo);
    final_color.a   += taco * a_taco * 0.4 * mix(1.0, 0.2, inactivo);

    // Arco de carga (llena con la tension, empieza arriba sentido horario)
    float ang_norm  = (angulo_pixel + PI) / (2.0 * PI); // 0→1
    // Rotar para que empiece arriba (0 = arriba)
    ang_norm        = fract(ang_norm + 0.75);
    float arco_fill = step(ang_norm, tension) * anillo_ext * en_suelo;
    float barrido   = sin(angulo_pixel * 8.0 - TIME * 3.5) * 0.12 + 0.88;
    vec3  arco_col  = mix(col_dorado, col_fuego, tension);
    final_color.rgb = mix(final_color.rgb, arco_col * barrido, arco_fill);
    final_color.a   = max(final_color.a, arco_fill * 0.92);

    // Punta del arco
    float punta = smoothstep(0.014, 0.0, abs(ang_norm - tension)) * anillo_ext * en_suelo;
    final_color.rgb = mix(final_color.rgb, col_blanco, punta * 0.8);
    final_color.a   = max(final_color.a, punta * 0.95);

    // Anillo de bloqueo al maximo (como run_mode del joystick)
    float lock_pulse = sin(TIME * 10.0) * 0.5 + 0.5;
    float lock_ring  = smoothstep(0.475, 0.465, d) - smoothstep(0.465, 0.455, d);
    float lock_marks = smoothstep(0.7, 1.0, abs(sin(angulo_pixel * 6.0)));
    float lock_alpha = lock_ring * tension * mix(0.7, 1.0, lock_pulse * lock_marks) * en_suelo;
    final_color.rgb  = mix(final_color.rgb, mix(col_energia, col_fuego, lock_pulse), lock_alpha);
    final_color.a    = max(final_color.a, lock_alpha * 0.95);

    // Ring expansivo al maximo
    float expand      = fract(TIME * 2.5);
    float expand_r    = 0.47 + expand * 0.08;
    float expand_ring = (smoothstep(expand_r + 0.01, expand_r, d) - smoothstep(expand_r, expand_r - 0.008, d))
                      * (1.0 - expand) * smoothstep(0.9, 1.0, tension) * en_suelo;
    final_color.rgb  += col_fuego * expand_ring;
    final_color.a    += expand_ring * 0.7;

    // =====================================================
    // 4. FLECHA QUE CRECE (en lugar de palanca)
    // =====================================================
    float altura   = mix(0.08, 0.30, tension);
    float ancho_t  = mix(0.018, 0.038, tension);
    float ancho_p  = mix(0.08,  0.18,  tension);
    float origen_y = mix(0.15, 0.06, tension);

    // Vibracion al maximo
    float vib = step(0.95, tension) * sin(TIME * 45.0) * 0.008;

    // Tallo
    vec2  uv_t  = uv - vec2(0.5 + vib, 0.5 + origen_y);
    float tallo = smoothstep(ancho_t, 0.0, abs(uv_t.x))
                * smoothstep(0.0, -altura * 0.7, uv_t.y)
                * smoothstep(-altura, -altura * 0.6, uv_t.y)
                * base_mask;

    // Punta
    vec2  uv_p  = uv - vec2(0.5 + vib, 0.5 + origen_y - altura * 0.65);
    float f_pi  = smoothstep(0.006, 0.0,  uv_p.x + uv_p.y * (ancho_p / 0.12) + ancho_p);
    float f_pd  = smoothstep(0.006, 0.0, -uv_p.x + uv_p.y * (ancho_p / 0.12) + ancho_p);
    float f_top = smoothstep(0.006, 0.0, uv_p.y + 0.12);
    float punta_f = f_pi * f_pd * f_top * base_mask;

    float flecha = clamp(tallo + punta_f, 0.0, 1.0);

    // Color de la flecha igual al rim del joystick
    float joy_lit   = 1.0 - length(uv - vec2(0.5 + vib, 0.5 + origen_y)) * 3.0;
    vec3  col_flecha = mix(
        mix(vec3(0.20, 0.20, 0.23), col_dorado, joy_lit * 0.5),
        mix(col_energia, col_fuego, tension),
        tension * 0.8
    );
    col_flecha = mix(col_flecha, col_frio * 0.6, inactivo * 0.7);
    // Especular en la punta
    float spec = smoothstep(0.02, 0.0, distance(uv, vec2(0.5 - 0.03, 0.5 + origen_y - altura * 0.9)));
    col_flecha += col_blanco * spec * mix(0.3, 0.7, tension);

    final_color.rgb = mix(final_color.rgb, col_flecha, flecha * mix(0.6, 0.95, en_suelo));
    final_color.a   = max(final_color.a, flecha * mix(0.3, 0.92, en_suelo));

    // Flechas fantasma (como partículas del joystick)
    for (int k = 0; k < 2; k++) {
        float off_k    = float(k + 1) * mix(0.06, 0.10, tension);
        float alpha_k  = mix(0.0, 0.35, tension) / float(k + 1);
        float alt_k    = altura * mix(0.55, 0.7, hash1(float(k)));
        vec2  uv_tk    = uv - vec2(0.5 + vib, 0.5 + origen_y + off_k);
        float t_k      = smoothstep(ancho_t * 0.6, 0.0, abs(uv_tk.x))
                       * smoothstep(0.0, -alt_k * 0.7, uv_tk.y)
                       * smoothstep(-alt_k, -alt_k * 0.6, uv_tk.y)
                       * base_mask;
        vec2  uv_pk    = uv - vec2(0.5 + vib, 0.5 + origen_y + off_k - alt_k * 0.65);
        float ap_p     = ancho_p * 0.6;
        float fk_pi    = smoothstep(0.005, 0.0,  uv_pk.x + uv_pk.y * (ap_p / 0.09) + ap_p);
        float fk_pd    = smoothstep(0.005, 0.0, -uv_pk.x + uv_pk.y * (ap_p / 0.09) + ap_p);
        float fk_top   = smoothstep(0.005, 0.0, uv_pk.y + 0.09);
        float pk       = fk_pi * fk_pd * fk_top * base_mask;
        float fk       = clamp(t_k + pk, 0.0, 1.0) * alpha_k * en_suelo;
        final_color.rgb = mix(final_color.rgb, col_flecha * 0.7, fk);
        final_color.a   = max(final_color.a, fk * 0.5);
    }

    // Particulas de polvo/chispas al cargar
    for (int k = 0; k < 5; k++) {
        float seed  = float(k) * 1.618;
        float spd   = 0.25 + hash1(seed + 5.0) * 0.2;
        float pt    = fract(hash1(seed) + TIME * spd);
        vec2  p_pos = vec2(
            0.5 + (hash1(seed + 1.0) - 0.5) * 0.3,
            0.5 + 0.2 - pt * 0.5
        );
        float p_d  = distance(uv, p_pos);
        float p_sz = 0.008 + hash1(seed + 3.0) * 0.006;
        float p_m  = smoothstep(p_sz, 0.0, p_d);
        float p_a  = p_m * tension * smoothstep(0.0, 0.1, pt) * smoothstep(1.0, 0.85, pt) * base_mask;
        vec3  p_col = mix(col_dorado, mix(col_energia, col_blanco, p_m), tension);
        final_color.rgb = mix(final_color.rgb, p_col, p_m * p_a);
        final_color.a   = max(final_color.a, p_a * 0.85);
    }

    // =====================================================
    // 5. RECORTE FINAL
    // =====================================================
    final_color.a *= max(base_mask, flecha * 0.5);
    COLOR = final_color;
}