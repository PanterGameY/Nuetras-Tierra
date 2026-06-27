shader_type canvas_item;

uniform float inclinacion : hint_range(-1.0, 1.0) = 0.0;

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

float capsula(vec2 uv, float radio, float largo) {
    uv.x = uv.x - clamp(uv.x, -largo, largo);
    return length(uv) - radio;
}

void fragment() {
    vec2  uv     = UV - vec2(0.5);
    uv.x        *= 3.0;
    float abs_inc = abs(inclinacion);

    vec3 col_dorado  = vec3(0.9,  0.75, 0.4);
    vec3 col_ambar   = vec3(1.0,  0.6,  0.15);
    vec3 col_blanco  = vec3(1.0,  1.0,  1.0);
    vec3 col_cristal = vec3(0.14, 0.17, 0.21);
    vec3 col_frio    = vec3(0.3,  0.55, 0.85);

    // =====================================================
    // 1. BASE CRISTAL DEL RIEL
    // =====================================================
    float largo_cap = 1.10;
    float radio_cap = 0.28;
    float d_cap     = capsula(uv, radio_cap, largo_cap);
    float riel_ext  = smoothstep(0.015, -0.015, d_cap);
    float riel_int  = smoothstep(-0.015, -0.055, d_cap);
    float anillo    = riel_ext - riel_int;

    vec2  heat_uv = (uv + vec2(0.5)) * 5.5;
    heat_uv.x    += sin(uv.y * 12.0 + TIME * 1.2) * 0.02;
    heat_uv.y    += cos(uv.x * 10.0 + TIME * 0.9) * 0.015;
    float tex     = fbm(heat_uv + vec2(TIME * 0.04, TIME * 0.025));

    vec3  col_riel = mix(col_cristal, col_cristal * 1.6, tex * 0.4);
    col_riel      += col_frio * abs_inc * 0.08 * (1.0 - length(uv) * 1.5);
    float riel_alpha = riel_int * mix(0.20, 0.40, tex);
    vec4  final_color = vec4(col_riel, riel_alpha);

    // Fresnel del riel
    float rim_cap   = anillo;
    float angulo_uv = atan(uv.y, uv.x);
    float rim_dir   = cos(angulo_uv) * 0.5 + 0.5;
    vec3  rim_col   = mix(col_cristal * 2.0, mix(col_dorado, col_frio, abs_inc), abs_inc * 0.7);
    float rim_alpha = rim_cap * mix(0.25, 0.70, abs_inc);
    final_color.rgb = mix(final_color.rgb, rim_col, rim_cap * rim_alpha);
    final_color.a   = max(final_color.a, rim_cap * rim_alpha);

    // =====================================================
    // 2. CANAL Y MARCAS
    // =====================================================
    float canal = smoothstep(0.05, 0.03, abs(uv.y)) * riel_int;
    vec3  col_canal = col_cristal * 0.5;
    final_color.rgb = mix(final_color.rgb, col_canal, canal * 0.7);

    // Marcas tacómetro verticales
    float marcas = 0.0;
    for (int m = 0; m <= 4; m++) {
        float pos_m   = mix(-largo_cap, largo_cap, float(m) / 4.0);
        float d_m     = abs(uv.x - pos_m);
        float alto_m  = (m == 2) ? 0.18 : 0.10;
        float mk      = smoothstep(0.020, 0.0, d_m)
                      * smoothstep(alto_m, 0.0, abs(uv.y))
                      * riel_int;
        float vis     = (m == 2) ? 0.5 : 0.22;
        marcas       += mk * vis;
    }
    vec3 col_marcas = mix(col_dorado * 0.7, col_frio * 0.9, abs_inc);
    final_color.rgb += col_marcas * marcas;
    final_color.a   += marcas * 0.4;

    // =====================================================
    // 3. BOLITA (palanca horizontal — igual que palanca del joystick)
    // =====================================================
    float radio_bola = 0.20;
    float bola_x     = inclinacion * (largo_cap - radio_bola * 0.9);

    // Vibracion al extremo
    float vib = step(0.92, abs_inc) * sin(TIME * 48.0) * 0.015;
    vec2  pos_bola = vec2(bola_x + vib, 0.0);

    float d_bola    = length(uv - pos_bola) - radio_bola;
    float bola_mask = smoothstep(0.012, -0.012, d_bola);
    float bola_rim  = smoothstep(0.025, 0.012, d_bola) - bola_mask;

    // Iluminacion identica a la palanca del joystick
    vec2  bola_local = uv - pos_bola;
    float joy_angle  = atan(bola_local.y, bola_local.x);
    float joy_lit    = cos(joy_angle + radians(220.0)) * 0.5 + 0.5;
    float joy_depth  = 1.0 - length(bola_local) * 4.5;

    vec3 bola_col = mix(vec3(0.20, 0.20, 0.23), col_blanco, joy_lit * 0.45 + joy_depth * 0.35);
    bola_col      = mix(bola_col, bola_col + mix(col_dorado, col_frio, abs_inc) * 0.35, abs_inc * 0.65);

    float bola_rim_dir = cos(joy_angle - sign(inclinacion) * 1.5708 + PI) * 0.5 + 0.5;
    bola_col += mix(col_dorado, col_frio, abs_inc) * bola_rim * bola_rim_dir * abs_inc * 0.9;

    float spec1 = smoothstep(0.035, 0.0, distance(uv, pos_bola + vec2(-0.05, -0.04)));
    float spec2 = smoothstep(0.018, 0.0, distance(uv, pos_bola + vec2(-0.032, -0.028)));
    bola_col   += col_blanco * spec1 * mix(0.22, 0.45, abs_inc);
    bola_col   += col_blanco * spec2 * mix(0.52, 0.75, abs_inc);

    float shadow_dir = cos(joy_angle + radians(40.0)) * 0.5 + 0.5;
    float shadow_rim = (smoothstep(0.20, 0.17, length(bola_local)) - smoothstep(0.17, 0.14, length(bola_local))) * shadow_dir;
    bola_col        -= vec3(0.08) * shadow_rim;

    // Halo de energía al extremo (igual que run_mode del joystick)
    float joy_halo  = smoothstep(0.26, 0.22, length(bola_local)) - smoothstep(0.22, 0.20, length(bola_local));
    float halo_puls = sin(TIME * 9.0) * 0.4 + 0.6;
    final_color.rgb += mix(col_dorado, col_frio, abs_inc) * joy_halo * abs_inc * halo_puls * 0.7;
    final_color.a   += joy_halo * abs_inc * halo_puls * 0.5;

    float bola_alpha = mix(mix(0.52, 0.88, joy_lit), 0.95, abs_inc) * bola_mask;
    final_color.rgb  = mix(final_color.rgb, bola_col, bola_mask);
    final_color.a    = mix(final_color.a, bola_alpha, bola_mask);

    // =====================================================
    // 4. ESTELA (como la estela del joystick)
    // =====================================================
    float estela_dir  = sign(inclinacion);
    vec2  dir_norm    = vec2(estela_dir, 0.0);
    float t_proj      = clamp(dot(uv - pos_bola, -dir_norm) / (largo_cap * 0.8), 0.0, 1.0);
    float seg_dist    = abs(uv.y);
    float estela_mask = smoothstep(0.025, 0.0, seg_dist) * riel_int;
    float estela_fade = smoothstep(1.0, 0.0, t_proj) * smoothstep(0.0, 0.08, t_proj);
    float estela_x    = smoothstep(bola_x - estela_dir * 0.05,
                                   bola_x - estela_dir * 0.6, uv.x * estela_dir) * abs_inc;
    vec3  estela_col  = mix(col_frio, col_ambar, abs_inc);
    float estela_noise = fbm((uv + vec2(0.5)) * 11.0 - TIME * vec2(estela_dir * 1.8, 0.4)) * 0.3 + 0.7;
    float estela_alpha = estela_x * estela_mask * abs_inc * 0.85 * estela_noise;
    final_color.rgb    = mix(final_color.rgb, estela_col, estela_alpha);
    final_color.a      = max(final_color.a, estela_alpha * 0.88);

    // Particulas en la estela
    for (int k = 0; k < 5; k++) {
        float seed  = float(k) * 1.618;
        float spd   = 0.20 + hash1(seed + 5.0) * 0.15;
        float pt    = fract(hash1(seed) + TIME * spd);
        vec2  p_pos = pos_bola + vec2(-estela_dir * pt * 0.7, (hash1(seed + 2.0) - 0.5) * 0.08);
        float p_d   = distance(uv, p_pos);
        float p_sz  = 0.007 + hash1(seed + 3.0) * 0.005;
        float p_m   = smoothstep(p_sz, 0.0, p_d);
        float p_a   = p_m * abs_inc * smoothstep(0.0, 0.1, pt) * smoothstep(1.0, 0.85, pt) * riel_int;
        vec3  p_col = mix(col_dorado, mix(col_frio, col_blanco, p_m), abs_inc);
        final_color.rgb = mix(final_color.rgb, p_col, p_m * p_a);
        final_color.a   = max(final_color.a, p_a * 0.80);
    }

    // Flechas laterales (izq/der) con mismo estilo que arco del joystick
    for (int f = 0; f < 2; f++) {
        float lado     = float(f) * 2.0 - 1.0; // -1 izq, +1 der
        float activo   = max(lado * inclinacion, 0.0);
        vec2  uv_fa    = uv - vec2(lado * (largo_cap + 0.16), 0.0);
        float fa_i     = smoothstep(0.005, 0.0, lado * uv_fa.x + abs(uv_fa.y) * 1.1 - 0.04);
        float fa_lim   = smoothstep(0.005, 0.0, lado * uv_fa.x - 0.04) * 0.35;
        float fa       = fa_i * fa_lim * mix(0.3, 1.0, activo);
        vec3  col_fa   = mix(col_dorado * 0.8, col_frio, activo);
        final_color.rgb += col_fa * fa;
        final_color.a   += fa * mix(0.5, 0.85, activo);
    }

    // =====================================================
    // 5. RECORTE
    // =====================================================
    final_color.a *= max(riel_ext, bola_mask);
    COLOR = final_color;
}