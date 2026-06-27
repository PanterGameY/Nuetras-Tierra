shader_type canvas_item;

uniform float agachado : hint_range(0.0, 1.0) = 0.0;

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
    vec2  uv     = UV;
    vec2  center = vec2(0.5);
    float d      = distance(uv, center);
    float angulo = atan(uv.y - center.y, uv.x - center.x);

    vec3 col_dorado  = vec3(0.9,  0.75, 0.4);
    vec3 col_ambar   = vec3(1.0,  0.6,  0.15);
    vec3 col_blanco  = vec3(1.0,  1.0,  1.0);
    vec3 col_cristal = vec3(0.14, 0.17, 0.21);
    vec3 col_frio    = vec3(0.3,  0.55, 0.85);
    vec3 col_fuego   = vec3(1.0,  0.28, 0.05);
    vec3 col_energia = vec3(1.0,  0.55, 0.0);

    // =====================================================
    // 1. BASE CRISTAL
    // =====================================================
    float base_mask = smoothstep(0.46, 0.42, d);

    vec2  heat_uv = uv * 5.5;
    heat_uv.x    += sin(uv.y * 12.0 + TIME * mix(1.2, 3.5, agachado)) * 0.025;
    heat_uv.y    += cos(uv.x * 10.0 + TIME * 0.9) * 0.018;
    float tex     = fbm(heat_uv + vec2(TIME * 0.04, TIME * 0.025));
    float polar_grad  = cos(angulo * 2.0 - TIME * 0.35) * 0.5 + 0.5;
    float radial_grad = smoothstep(0.0, 0.46, d);

    float sweep_phase = fract(TIME / 6.0);
    float sweep_angle = sweep_phase * PI * 2.0 - PI;
    float sweep_proj  = dot(uv - center, vec2(cos(sweep_angle), sin(sweep_angle))) / 0.46;
    float sweep_band  = smoothstep(0.85, 1.0, sweep_proj) * smoothstep(1.0, 0.85, sweep_proj + 0.12);
    float sweep_glow  = sweep_band * smoothstep(0.0, 0.15, sweep_phase)
                      * smoothstep(1.0, 0.85, sweep_phase) * 0.55 * (1.0 - agachado);

    vec3 cristal_base = mix(col_cristal, mix(col_cristal, vec3(0.05, 0.10, 0.22), 0.7), agachado);
    vec3 cristal_rgb  = mix(cristal_base, cristal_base * 1.7, tex * 0.4 + polar_grad * 0.15);
    cristal_rgb      += col_blanco * sweep_glow * base_mask;
    float ag_pulse    = sin(TIME * 5.0) * 0.5 + 0.5;
    cristal_rgb      += col_frio * agachado * ag_pulse * 0.10 * base_mask * (1.0 - d * 2.0);

    float cristal_alpha = base_mask * mix(0.20, 0.42, radial_grad * tex + agachado * 0.12);
    vec4 final_color = vec4(cristal_rgb, cristal_alpha);

    // =====================================================
    // 2. FRESNEL RIM
    // =====================================================
    float rim_mask  = smoothstep(0.46, 0.44, d) - smoothstep(0.44, 0.42, d);
    vec3  rim_col   = mix(col_cristal * 2.0, mix(col_dorado, col_frio, agachado), agachado * 0.8);
    float rim_alpha = rim_mask * mix(0.20, 0.65, agachado);
    final_color.rgb = mix(final_color.rgb, rim_col, rim_mask * rim_alpha);
    final_color.a   = max(final_color.a, rim_mask * rim_alpha);

    // =====================================================
    // 3. ANILLO CON ARCO DE ESTADO
    // =====================================================
    float anillo_ext = smoothstep(0.47, 0.455, d) - smoothstep(0.455, 0.44, d);
    float taco       = smoothstep(0.92, 1.0, abs(sin(angulo * 9.0))) * 0.45;
    float a_taco     = smoothstep(0.47, 0.462, d) - smoothstep(0.462, 0.455, d);
    final_color.rgb += col_dorado * taco * a_taco * 0.6;
    final_color.a   += taco * a_taco * 0.4;

    // Arco de estado — lleno = agachado activo
    float ang_norm  = fract((angulo + PI) / (2.0 * PI) + 0.75);
    float arco_fill = step(ang_norm, agachado) * anillo_ext;
    float barrido   = sin(angulo * 8.0 - TIME * 2.5) * 0.12 + 0.88;
    vec3  arco_col  = mix(col_dorado, col_frio, agachado);
    final_color.rgb = mix(final_color.rgb, arco_col * barrido, arco_fill);
    final_color.a   = max(final_color.a, arco_fill * 0.92);

    // Anillo de bloqueo al activarse
    float lock_pulse = sin(TIME * 6.0) * 0.5 + 0.5;
    float lock_ring  = smoothstep(0.475, 0.465, d) - smoothstep(0.465, 0.455, d);
    float lock_marks = smoothstep(0.7, 1.0, abs(sin(angulo * 6.0)));
    float lock_alpha = lock_ring * agachado * mix(0.6, 1.0, lock_pulse * lock_marks);
    final_color.rgb  = mix(final_color.rgb, mix(col_frio, col_dorado, lock_pulse), lock_alpha);
    final_color.a    = max(final_color.a, lock_alpha * 0.95);

    // Ring expansivo al activarse
    float expand      = fract(TIME * 2.0);
    float expand_r    = 0.47 + expand * 0.08;
    float expand_ring = (smoothstep(expand_r + 0.01, expand_r, d) - smoothstep(expand_r, expand_r - 0.008, d))
                      * (1.0 - expand) * agachado;
    final_color.rgb  += col_frio * expand_ring;
    final_color.a    += expand_ring * 0.7;

    // =====================================================
    // 4. FIGURA HUMANA (se agacha igual que la palanca del joystick)
    // =====================================================
    float altura_cuerpo = mix(0.18, 0.09, agachado);
    float pos_y_base    = mix(0.05, 0.14, agachado);

    // Cabeza
    float cabeza_y = -pos_y_base - altura_cuerpo - 0.07;
    vec2  pos_cabeza = center + vec2(0.0, cabeza_y);
    float d_cabeza   = distance(uv, pos_cabeza);
    float cabeza     = smoothstep(0.065, 0.045, d_cabeza) * base_mask;

    // Iluminacion en cabeza igual que palanca
    float c_angle = atan(uv.y - pos_cabeza.y, uv.x - pos_cabeza.x);
    float c_lit   = cos(c_angle + radians(220.0)) * 0.5 + 0.5;
    float c_depth = 1.0 - d_cabeza * 8.0;
    float c_spec1 = smoothstep(0.025, 0.0, distance(uv, pos_cabeza + vec2(-0.03, -0.025)));
    float c_spec2 = smoothstep(0.012, 0.0, distance(uv, pos_cabeza + vec2(-0.02, -0.018)));

    vec3 col_figura = mix(vec3(0.20, 0.20, 0.23), col_blanco, c_lit * 0.45 + c_depth * 0.35);
    col_figura      = mix(col_figura, col_figura + mix(col_dorado, col_frio, agachado) * 0.4, agachado * 0.65);
    col_figura     += col_blanco * c_spec1 * mix(0.3, 0.5, agachado);
    col_figura     += col_blanco * c_spec2 * mix(0.5, 0.7, agachado);

    // Cuerpo
    vec2  uv_c   = uv - (center + vec2(0.0, -pos_y_base - altura_cuerpo * 0.5));
    float cuerpo = smoothstep(0.048, 0.030, abs(uv_c.x))
                 * smoothstep(altura_cuerpo, altura_cuerpo - 0.015, abs(uv_c.y))
                 * base_mask;

    // Piernas con doblez
    float ang_pierna = mix(0.0, 0.35, agachado);
    vec2  uv_pi      = uv - (center + vec2(-0.05, pos_y_base));
    float pierna_i   = smoothstep(0.020, 0.006, abs(uv_pi.x + uv_pi.y * ang_pierna))
                     * smoothstep(0.0, -0.14, uv_pi.y + abs(uv_pi.x) * ang_pierna)
                     * smoothstep(-0.16, -0.12, uv_pi.y)
                     * base_mask;
    vec2  uv_pd      = uv - (center + vec2(0.05, pos_y_base));
    float pierna_d   = smoothstep(0.020, 0.006, abs(uv_pd.x - uv_pd.y * ang_pierna))
                     * smoothstep(0.0, -0.14, uv_pd.y + abs(uv_pd.x) * ang_pierna)
                     * smoothstep(-0.16, -0.12, uv_pd.y)
                     * base_mask;

    float figura = clamp(cabeza + cuerpo + pierna_i + pierna_d, 0.0, 1.0);
    float fig_rim = smoothstep(0.065, 0.055, d_cabeza) - smoothstep(0.055, 0.045, d_cabeza);
    col_figura   += mix(col_dorado, col_frio, agachado) * fig_rim * agachado * 0.8;

    final_color.rgb = mix(final_color.rgb, col_figura, figura);
    final_color.a   = max(final_color.a, figura * 0.92);

    // Particulas al agacharse (polvo)
    for (int k = 0; k < 4; k++) {
        float seed  = float(k) * 2.1;
        float spd   = 0.3 + hash1(seed) * 0.2;
        float pt    = fract(hash1(seed + 1.0) + TIME * spd);
        vec2  p_pos = center + vec2(
            (hash1(seed + 2.0) - 0.5) * 0.5,
            0.15 + pt * 0.2
        );
        float p_d  = distance(uv, p_pos);
        float p_sz = 0.007 + hash1(seed + 3.0) * 0.005;
        float p_m  = smoothstep(p_sz, 0.0, p_d);
        float p_a  = p_m * agachado * smoothstep(0.0, 0.1, pt) * smoothstep(1.0, 0.85, pt) * base_mask;
        final_color.rgb = mix(final_color.rgb, mix(col_dorado, col_frio, agachado), p_m * p_a);
        final_color.a   = max(final_color.a, p_a * 0.75);
    }

    // =====================================================
    // 5. RECORTE
    // =====================================================
    final_color.a *= max(base_mask, figura * 0.5);
    COLOR = final_color;
}