shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// ── Control principal ─────────────────────────────────────────────────
uniform vec4  glass_color      : source_color = vec4(0.72, 0.82, 0.86, 0.10);
uniform float roughness        : hint_range(0.0, 1.0) = 0.03;
uniform float metallic         : hint_range(0.0, 1.0) = 0.0;
uniform float specular_str     : hint_range(0.0, 1.0) = 0.98;

// ── Fresnel ───────────────────────────────────────────────────────────
uniform float fresnel_power    : hint_range(1.0, 8.0) = 5.0;
uniform float fresnel_scale    : hint_range(0.0, 1.0) = 0.7;
uniform vec4  fresnel_tint     : source_color = vec4(0.55, 0.72, 0.78, 1.0);

// ── Suciedad ──────────────────────────────────────────────────────────
uniform float dirt_level       : hint_range(0.0, 1.0) = 0.0;
uniform vec4  dirt_color       : source_color = vec4(0.42, 0.36, 0.28, 1.0);
uniform sampler2D dirt_noise   : hint_default_white;

// ── Lluvia / condensacion ─────────────────────────────────────────────
uniform float rain_intensity   : hint_range(0.0, 1.0) = 0.0;
uniform float rain_speed       : hint_range(0.0, 5.0) = 1.8;

// ── Danos (telarana de grietas) ───────────────────────────────────────
uniform float damage_level     : hint_range(0.0, 1.0) = 0.0;
uniform vec2  damage_center                            = vec2(0.5, 0.5);
uniform sampler2D parabrisas_roto : hint_default_black;

// ─────────────────────────────────────────────────────────────────────
// UTILIDADES
// ─────────────────────────────────────────────────────────────────────
float hash(vec2 p) {
    p  = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 17.31);
    return fract(p.x * p.y);
}

float hash1(float v) {
    return fract(sin(v * 127.1) * 43758.5453);
}

// ─────────────────────────────────────────────────────────────────────
// LLUVIA ─ Gotas deslizandose + micro-impactos
// ─────────────────────────────────────────────────────────────────────
vec3 get_rain_normal(vec2 uv, float t) {
    vec3 n = vec3(0.0, 0.0, 1.0);

    // ── Capa A: gotas grandes que se deslizan hacia abajo ─────────────
    vec2 gA = uv * vec2(18.0, 9.0);
    vec2 idA = floor(gA);
    vec2 locA = fract(gA) - 0.5;
    float hA = hash(idA);
    float tA = t * rain_speed * (0.6 + hA * 0.8) + hA * 40.0;
    float yA = fract(tA) - 0.5;
    vec2 dpA = vec2((hash(idA + 3.7) - 0.5) * 0.65, yA);

    float dA = length(locA - dpA);
    float szA = 0.13 * rain_intensity;
    if (dA < szA) {
        vec2 diff = (locA - dpA) / szA;
        float z = sqrt(max(0.001, 1.0 - dot(diff, diff)));
        n = vec3(diff * 3.0, z);
    }
    // rastro fino hacia arriba
    float tw = 0.012 * rain_intensity;
    if (abs(locA.x - dpA.x) < tw && locA.y > dpA.y && locA.y < dpA.y + 0.42) {
        float td  = abs(locA.x - dpA.x) / tw;
        float fad = 1.0 - smoothstep(0.0, 0.42, locA.y - dpA.y);
        n = mix(n, vec3((locA.x - dpA.x) * 6.0, 0.0, 1.0), (1.0 - td) * fad * 0.75 * rain_intensity);
    }

    // ── Capa B: micro-gotas de impacto (aparecen y desaparecen) ──────
    vec2 gB   = uv * 78.0;
    vec2 idB  = floor(gB);
    vec2 locB = fract(gB) - 0.5;
    float hB  = hash(idB);
    float life = sin(t * 9.0 + hB * 6.283);
    if (life > 0.35 && hB < rain_intensity * 0.85) {
        float szB = 0.08 * (life - 0.35);
        float dB  = length(locB);
        if (dB < szB) {
            vec2 diff = locB / max(szB, 0.001);
            float z   = sqrt(max(0.001, 1.0 - dot(diff, diff)));
            n = normalize(mix(n, vec3(diff * 2.5, z), 0.9));
        }
    }

    // ── Capa C: gotas pequenas secundarias (densidad mas alta) ────────
    vec2 gC   = uv * vec2(35.0, 18.0);
    vec2 idC  = floor(gC);
    vec2 locC = fract(gC) - 0.5;
    float hC  = hash(idC);
    float tC  = t * rain_speed * (0.3 + hC * 0.5) + hC * 60.0;
    vec2 dpC  = vec2((hash(idC + 7.3) - 0.5) * 0.6, fract(tC) - 0.5);
    float dC  = length(locC - dpC);
    float szC = 0.06 * rain_intensity;
    if (dC < szC) {
        vec2 diff = (locC - dpC) / max(szC, 0.001);
        float z   = sqrt(max(0.001, 1.0 - dot(diff, diff)));
        n = normalize(mix(n, vec3(diff * 2.0, z), 0.65));
    }

    return normalize(n);
}

// ─────────────────────────────────────────────────────────────────────
// DANO ─ Telarana de grietas procedimientales
// ─────────────────────────────────────────────────────────────────────
float get_cracks(vec2 uv, vec2 center, float intensity) {
    if (intensity < 0.01) return 0.0;

    vec2  dir  = uv - center;
    float dist = length(dir);
    float ang  = atan(dir.y, dir.x);

    // Ruido de grano fino que hace las lineas irregulares y organicas
    float grain = hash(floor(uv * 90.0)) * 0.05;
    float dist_p = dist + grain * intensity;

    float radius = intensity * 0.48;
    if (dist_p > radius) return 0.0;

    // ── 1. Grietas radiales (rayos desiguales) ────────────────────────
    float spokes = 7.0 + floor(intensity * 11.0);
    // Perturbacion angular organica basada en la distancia
    float ang_warp = sin(dist_p * 28.0 + hash1(ang * 2.2) * 4.0) * 0.35;
    float spoke_pat = sin(ang * spokes + ang_warp);
    float spoke_width = 0.97 - intensity * 0.04;
    float radial = smoothstep(spoke_width, 1.0, spoke_pat);

    // Ramas secundarias (grietas mas finas que salen de las principales)
    float branch_spokes = spokes * 2.2;
    float branch_pat = sin(ang * branch_spokes - ang_warp * 0.5);
    float branch = smoothstep(0.985, 1.0, branch_pat) * smoothstep(radius * 0.55, radius * 0.2, dist_p);
    radial = max(radial, branch);

    // ── 2. Anillos concentricos rotos ─────────────────────────────────
    float ring_freq = 38.0;
    float ring_pat  = sin(dist_p * ring_freq - ang * 1.8 + hash(floor(uv * 18.0)) * 1.2);
    float ring_raw  = smoothstep(0.93 - intensity * 0.05, 1.0, ring_pat);
    // Hacer que los anillos sean arcos discontinuos, no circulos
    float ring_cut  = step(0.28, hash(floor(uv * 14.0 + center * 3.1)));
    float rings     = ring_raw * ring_cut;

    // ── 3. Nucleo pulverizado ─────────────────────────────────────────
    float crush = smoothstep(radius * 0.18, 0.0, dist_p);

    // ── 4. Imagen auxiliar parabrisas_roto ────────────────────────────
    float tex = texture(parabrisas_roto, uv).r * intensity * 0.85;

    // ── Combinar ──────────────────────────────────────────────────────
    float cracks = max(max(radial, rings), max(crush, tex));

    // Fade hacia los bordes del radio
    float edge = smoothstep(radius, radius * 0.65, dist_p);
    return clamp(cracks * edge, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────
// FRAGMENT
// ─────────────────────────────────────────────────────────────────────
void fragment() {
    vec2 uv = UV;

    // ── Suciedad procedimental ────────────────────────────────────────
    float dirt_mask = texture(dirt_noise, uv).r * dirt_level;

    // ── Lluvia ────────────────────────────────────────────────────────
    vec3 rain_n = vec3(0.0, 0.0, 1.0);
    if (rain_intensity > 0.001) {
        rain_n = get_rain_normal(uv, TIME);
    }

    // ── Grietas de dano ───────────────────────────────────────────────
    float crack_mask = 0.0;
    vec3  crack_n    = vec3(0.0, 0.0, 1.0);
    if (damage_level > 0.001) {
        crack_mask = get_cracks(uv, damage_center, damage_level);
        // Normal abrupta de borde roto (usa derivadas de pantalla)
        float e = 0.0008;
        float cL = get_cracks(uv - vec2(e, 0.0), damage_center, damage_level);
        float cR = get_cracks(uv + vec2(e, 0.0), damage_center, damage_level);
        float cD = get_cracks(uv - vec2(0.0, e), damage_center, damage_level);
        float cU = get_cracks(uv + vec2(0.0, e), damage_center, damage_level);
        crack_n = normalize(vec3((cL - cR) * 30.0, (cD - cU) * 30.0, 1.0));
    }

    // ── Normal combinada ──────────────────────────────────────────────
    vec3 N = NORMAL;
    N = normalize(mix(N, rain_n, rain_intensity * 0.45));
    if (damage_level > 0.001) {
        N = normalize(mix(N, crack_n, crack_mask * 0.92));
    }
    NORMAL = N;

    // ── Fresnel fisicamente correcto ──────────────────────────────────
    float NoV     = max(dot(N, VIEW), 0.0);
    float fresnel = pow(1.0 - NoV, fresnel_power) * fresnel_scale;

    // ── Color ─────────────────────────────────────────────────────────
    vec3 base_col = glass_color.rgb;
    // Tinte de suciedad
    base_col = mix(base_col, dirt_color.rgb, dirt_mask * 0.55);
    // Tinte fresnel (vidrio automotriz real tiene reflejo azul-verdoso en bordes)
    base_col = mix(base_col, fresnel_tint.rgb, fresnel * 0.5);
    // Grietas / bordes rotos son blancos brillantes
    vec3 crack_white = vec3(0.93, 0.97, 1.0);
    base_col = mix(base_col, crack_white, crack_mask * 0.88);

    ALBEDO = base_col;

    // ── Opacidad ──────────────────────────────────────────────────────
    float alpha = glass_color.a;
    // Fresnel hace los bordes mas opacos (comportamiento real del vidrio laminado)
    alpha = mix(alpha, min(alpha + 0.65, 1.0), fresnel);
    // Suciedad incrementa opacidad
    alpha = mix(alpha, min(alpha + 0.5, 1.0),  dirt_mask * 0.6);
    // Condensacion/empanado (lluvia)
    float cond = rain_intensity * 0.72;
    alpha = mix(alpha, min(alpha + 0.35, 1.0), cond);
    // Grietas son casi completamente opacas y blancas
    alpha = mix(alpha, 0.97, crack_mask);
    // Gotas individuales incrementan leve opacidad localizada
    if (rain_intensity > 0.001) {
        alpha = mix(alpha, alpha + 0.14, length(rain_n.xy) * rain_intensity);
    }
    ALPHA = clamp(alpha, 0.0, 1.0);

    // ── Propiedades de superficie ─────────────────────────────────────
    float rough = roughness;
    rough = mix(rough, 0.82, dirt_mask);           // suciedad dispersa reflejo
    rough = mix(rough, 0.78, cond);                // condensacion empaña
    rough = mix(rough, 0.92, crack_mask);          // grietas son asperas
    ROUGHNESS = rough;
    METALLIC  = metallic;
    SPECULAR  = specular_str;

    // ── Emision minima ────────────────────────────────────────────────
    // Solo un brillo de borde fisico muy sutil, sin refraccion de pantalla
    float rim_glow = pow(fresnel, 3.5) * 0.07;
    EMISSION = mix(base_col * rim_glow, crack_white * 0.12, crack_mask);
}
