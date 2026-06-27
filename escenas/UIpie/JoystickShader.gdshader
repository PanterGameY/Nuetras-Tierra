shader_type canvas_item;

uniform vec2 joy_position = vec2(0.5, 0.5);
uniform float limit_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float run_mode : hint_range(0.0, 1.0) = 0.0;

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
    vec2 uv = UV;
    vec2 center = vec2(0.5);

    // Vibración mecánica — se intensifica con run_mode
    float vib_amp  = (limit_pulse + run_mode * 2.5) * 0.004;
    float vib_freq = mix(48.0, 120.0, run_mode);
    vec2  vib_off  = vec2(
        sin(TIME * vib_freq) * vib_amp,
        cos(TIME * vib_freq * 1.3 + 1.0) * vib_amp
    );

    float d_center = distance(uv, center);
    float d_joy    = distance(uv + vib_off, joy_position);
    vec2  dir      = joy_position - center;
    float dist_len = length(dir);

    float angulo_pixel = atan(uv.y - center.y, uv.x - center.x);
    float angulo_joy   = atan(dir.y, dir.x);
    float angulo_rel   = angulo_pixel - angulo_joy;

    // Paleta base
    vec3 col_dorado  = vec3(0.9,  0.75, 0.4);
    vec3 col_ambar   = vec3(1.0,  0.6,  0.15);
    vec3 col_blanco  = vec3(1.0,  1.0,  1.0);
    vec3 col_cristal = vec3(0.14, 0.17, 0.21);
    vec3 col_frio    = vec3(0.3,  0.55, 0.85);
    vec3 col_polvo   = vec3(0.78, 0.65, 0.42);
    // Paleta run
    vec3 col_fuego   = vec3(1.0,  0.28, 0.05);
    vec3 col_energia = vec3(1.0,  0.55, 0.0);

    // =====================================================
    // 1. BASE CRISTAL
    // =====================================================
    float base_mask = smoothstep(0.46, 0.42, d_center);

    float heat_spd = mix(1.2, 4.5, run_mode);
    vec2  heat_uv  = uv * 5.5;
    heat_uv.x     += sin(uv.y * 12.0 + TIME * heat_spd) * mix(0.03, 0.06, run_mode) * (1.0 - d_center * 1.8);
    heat_uv.y     += cos(uv.x * 10.0 + TIME * heat_spd * 0.75) * mix(0.02, 0.05, run_mode) * (1.0 - d_center * 1.8);
    float tex      = fbm(heat_uv + vec2(TIME * 0.04, TIME * 0.025));
    float polar_grad  = cos(angulo_pixel * 2.0 - TIME * 0.35) * 0.5 + 0.5;
    float radial_grad = smoothstep(0.0, 0.46, d_center);

    // Destello solar (solo modo normal)
    float sweep_phase = fract(TIME / 6.0);
    float sweep_angle = sweep_phase * PI * 2.0 - PI;
    float sweep_proj  = dot(uv - center, vec2(cos(sweep_angle), sin(sweep_angle))) / 0.46;
    float sweep_band  = smoothstep(0.85, 1.0, sweep_proj) * smoothstep(1.0, 0.85, sweep_proj + 0.12);
    float sweep_glow  = sweep_band * smoothstep(0.0, 0.15, sweep_phase) * smoothstep(1.0, 0.85, sweep_phase) * 0.55 * (1.0 - run_mode);

    vec3 cristal_base = mix(col_cristal, vec3(0.22, 0.06, 0.04), run_mode * 0.7);
    vec3 cristal_rgb  = mix(cristal_base, cristal_base * 1.7, tex * 0.4 + polar_grad * 0.15);
    cristal_rgb      += col_blanco * sweep_glow * base_mask;
    // Pulso rojo en run_mode
    float run_pulse   = sin(TIME * 8.0) * 0.5 + 0.5;
    cristal_rgb      += col_fuego * run_mode * run_pulse * 0.12 * base_mask * (1.0 - d_center * 2.0);

    float cristal_alpha = base_mask * mix(0.20, 0.42, radial_grad * tex + run_mode * 0.15);
    vec4 final_color = vec4(cristal_rgb, cristal_alpha);

    // =====================================================
    // 2. FRESNEL RIM
    // =====================================================
    float rim_mask = smoothstep(0.46, 0.44, d_center) - smoothstep(0.44, 0.42, d_center);
    float rim_dir  = cos(angulo_rel) * 0.5 + 0.5;
    vec3  rim_col  = mix(col_cristal * 2.0, mix(col_dorado, col_ambar, limit_pulse * 0.6), rim_dir * dist_len * 2.2);
    rim_col        = mix(rim_col, col_fuego * 1.2, run_mode * 0.85);
    float rim_alpha = rim_mask * mix(0.12, 0.60, rim_dir) * (0.35 + dist_len * 0.9 + run_mode * 0.4);
    final_color.rgb = mix(final_color.rgb, rim_col, rim_mask * mix(0.12, 0.60, rim_dir));
    final_color.a   = max(final_color.a, rim_mask * rim_alpha);

    // =====================================================
    // 3A. ARCO NORMAL (desaparece en run_mode)
    // =====================================================
    float nm = 1.0 - run_mode;
    float arco_match = cos(angulo_rel);
    float arco_ancho = smoothstep(0.88, 0.97, arco_match);
    float anillo_ext = smoothstep(0.47, 0.455, d_center) - smoothstep(0.455, 0.44, d_center);
    float barrido    = sin(angulo_pixel * 8.0 - TIME * 3.5) * 0.12 + 0.88;

    // Marcas tacómetro
    float taco   = smoothstep(0.92, 1.0, abs(sin(angulo_pixel * 9.0))) * 0.45 * nm;
    float a_taco = smoothstep(0.47, 0.462, d_center) - smoothstep(0.462, 0.455, d_center);
    final_color.rgb += col_dorado * taco * a_taco * 0.6;
    final_color.a   += taco * a_taco * 0.4;

    vec3  arco_rgb   = mix(mix(col_dorado, col_blanco, arco_ancho * 0.45), col_ambar, limit_pulse * 0.4);
    float arco_alpha = anillo_ext * arco_ancho * limit_pulse * barrido * nm;
    final_color.rgb  = mix(final_color.rgb, arco_rgb, arco_alpha);
    final_color.a    = max(final_color.a, arco_alpha * 0.92);

    float p_ring = fract(d_center * 9.0 - TIME * 1.5);
    float p_mask = smoothstep(0.0, 0.18, p_ring) * smoothstep(0.55, 0.18, p_ring);
    final_color.rgb += col_ambar * p_mask * anillo_ext * arco_ancho * limit_pulse * 0.4 * nm;
    final_color.a   += p_mask * anillo_ext * arco_ancho * limit_pulse * 0.4 * nm * 0.3;

    // =====================================================
    // 3B. ANILLO DE BLOQUEO (run_mode)
    // =====================================================
    float lock_pulse = sin(TIME * 10.0) * 0.5 + 0.5;
    float lock_ring  = smoothstep(0.475, 0.465, d_center) - smoothstep(0.465, 0.455, d_center);
    float lock_marks = smoothstep(0.7, 1.0, abs(sin(angulo_pixel * 6.0)));
    float lock_alpha = lock_ring * run_mode * mix(0.7, 1.0, lock_pulse * lock_marks);
    final_color.rgb  = mix(final_color.rgb, mix(col_energia, col_fuego, lock_pulse), lock_alpha);
    final_color.a    = max(final_color.a, lock_alpha * 0.95);

    // Anillo expansivo de energía
    float expand      = fract(TIME * 2.5);
    float expand_r    = 0.47 + expand * 0.08;
    float expand_ring = (smoothstep(expand_r + 0.01, expand_r, d_center) - smoothstep(expand_r, expand_r - 0.008, d_center)) * (1.0 - expand) * run_mode;
    final_color.rgb  += col_fuego * expand_ring;
    final_color.a    += expand_ring * 0.7;

    // =====================================================
    // 3C. RAYOS DE ENERGÍA (run_mode)
    // =====================================================
    for (int r = 0; r < 6; r++) {
        float ray_angle = angulo_joy + float(r) * 1.0472 + sin(TIME * 3.0 + float(r)) * 0.15;
        vec2  ray_d     = vec2(cos(ray_angle), sin(ray_angle));
        vec2  to_uv     = uv - joy_position;
        float ray_proj  = dot(to_uv, ray_d);
        float ray_perp  = length(to_uv - ray_d * ray_proj);
        float ray_start = 0.19;
        float ray_len   = mix(0.08, 0.18, hash1(float(r) * 3.7));
        float ray_in    = smoothstep(ray_start, ray_start + 0.01, ray_proj)
                        * smoothstep(ray_start + ray_len, ray_start + ray_len * 0.5, ray_proj);
        float ray_w     = mix(0.006, 0.002, (ray_proj - ray_start) / ray_len);
        float ray_shape = smoothstep(ray_w, 0.0, ray_perp);
        float ray_flick = sin(TIME * 12.0 + float(r) * 2.1) * 0.3 + 0.7;
        float ray_alpha = ray_in * ray_shape * ray_flick * run_mode;
        final_color.rgb = mix(final_color.rgb, mix(col_energia, col_blanco, ray_shape * 0.6), ray_alpha);
        final_color.a   = max(final_color.a, ray_alpha * 0.85);
    }

    // =====================================================
    // 4. ESTELA
    // =====================================================
    vec2  dir_norm   = dist_len > 0.001 ? normalize(dir) : vec2(1.0, 0.0);
    float t_proj     = clamp(dot(uv - center, dir_norm) / dist_len, 0.0, 1.0);
    float seg_dist   = distance(uv, center + dir_norm * t_proj * dist_len);
    float trail_w    = mix(0.024 - t_proj * 0.013, 0.032, run_mode);
    float trail_mask = smoothstep(trail_w, 0.0, seg_dist);
    float trail_fade = smoothstep(1.0, 0.0, t_proj) * smoothstep(0.0, 0.10, t_proj);
    vec3  trail_norm_col = mix(col_frio, col_ambar, dist_len * 1.6 * t_proj);
    float fire_noise     = fbm(uv * 14.0 + vec2(0.0, -TIME * 3.5)) * 0.4 + 0.6;
    vec3  trail_rgb      = mix(trail_norm_col, mix(col_energia, col_fuego, t_proj) * fire_noise, run_mode);
    float trail_noise    = fbm(uv * 11.0 - TIME * vec2(1.8, 0.4)) * 0.3 + 0.7;
    float trail_alpha    = trail_mask * trail_fade * dist_len * mix(0.95, 1.3, run_mode) * trail_noise;
    final_color.rgb = mix(final_color.rgb, trail_rgb, trail_alpha);
    final_color.a   = max(final_color.a, trail_alpha * mix(0.88, 1.0, run_mode));

    // Partículas (polvo normal / chispas en run)
    for (int k = 0; k < 6; k++) {
        float seed  = float(k) * 1.618;
        float spd   = mix(0.18, 0.55, run_mode) + hash1(seed + 5.0) * 0.15;
        float pt    = fract(hash1(seed) + TIME * spd);
        vec2  perp  = vec2(-dir_norm.y, dir_norm.x);
        vec2  p_pos = center + dir_norm * pt * dist_len + perp * (hash1(seed + 2.0) - 0.5) * mix(0.04, 0.09, run_mode);
        float p_d   = distance(uv, p_pos);
        float p_sz  = mix(0.007, 0.004, run_mode) + hash1(seed + 3.0) * 0.006;
        float p_m   = smoothstep(p_sz, 0.0, p_d);
        float p_a   = p_m * dist_len * 0.75 * smoothstep(0.0, 0.1, pt) * smoothstep(1.0, 0.85, pt);
        vec3  p_col = mix(col_polvo, mix(col_energia, col_blanco, p_m), run_mode);
        final_color.rgb = mix(final_color.rgb, p_col, p_m * p_a);
        final_color.a   = max(final_color.a, p_a * mix(0.6, 0.9, run_mode));
    }

    // =====================================================
    // 5. PALANCA
    // =====================================================
    float palanca_mask = smoothstep(0.18, 0.155, d_joy);
    vec2  joy_local    = (uv + vib_off) - joy_position;
    float joy_angle    = atan(joy_local.y, joy_local.x);
    float joy_lit      = cos(joy_angle + radians(220.0)) * 0.5 + 0.5;
    float joy_depth    = 1.0 - d_joy * 4.5;

    vec3 joy_normal = mix(vec3(0.20, 0.20, 0.23), col_blanco, joy_lit * 0.45 + joy_depth * 0.35);
    joy_normal = mix(joy_normal, joy_normal + mix(col_dorado, col_ambar, limit_pulse) * 0.35, limit_pulse * 0.65);
    vec3 joy_run   = mix(vec3(0.30, 0.05, 0.02), col_energia, joy_lit * 0.6 + joy_depth * 0.5);
    joy_run       += col_blanco * joy_depth * 0.3;
    vec3 joy_base  = mix(joy_normal, joy_run, run_mode);

    float joy_rim     = smoothstep(0.18, 0.14, d_joy) - smoothstep(0.14, 0.12, d_joy);
    float joy_rim_dir = cos(joy_angle - angulo_joy + PI) * 0.5 + 0.5;
    joy_base += mix(mix(col_dorado, col_ambar, limit_pulse), col_fuego, run_mode) * joy_rim * joy_rim_dir * max(limit_pulse, run_mode) * 0.9;

    // Halo de energía en run_mode
    float joy_halo  = smoothstep(0.22, 0.18, d_joy) - smoothstep(0.18, 0.155, d_joy);
    float halo_puls = sin(TIME * 9.0) * 0.4 + 0.6;
    final_color.rgb += col_fuego * joy_halo * run_mode * halo_puls * 0.7;
    final_color.a   += joy_halo * run_mode * halo_puls * 0.5;

    float spec1 = smoothstep(0.04, 0.0, distance(uv, joy_position + vec2(-0.055, -0.05)));
    float spec2 = smoothstep(0.02, 0.0, distance(uv, joy_position + vec2(-0.038, -0.033)));
    joy_base += col_blanco * spec1 * mix(0.22, 0.5,  run_mode);
    joy_base += col_blanco * spec2 * mix(0.52, 0.8, run_mode);

    float shadow_dir = cos(joy_angle + radians(40.0)) * 0.5 + 0.5;
    float shadow_rim = (smoothstep(0.18, 0.16, d_joy) - smoothstep(0.16, 0.14, d_joy)) * shadow_dir;
    joy_base -= vec3(0.08) * shadow_rim * (1.0 - run_mode);

    float joy_alpha = mix(mix(0.52, 0.88, joy_lit), 0.95, run_mode) * palanca_mask;
    final_color.rgb = mix(final_color.rgb, joy_base, palanca_mask);
    final_color.a   = mix(final_color.a, joy_alpha, palanca_mask);

    // =====================================================
    // 6. RECORTE FINAL
    // =====================================================
    final_color.a *= max(max(base_mask, palanca_mask), run_mode * 0.3);

    COLOR = final_color;
}