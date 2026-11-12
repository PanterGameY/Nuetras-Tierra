shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// --- Parámetros de Vidrio Estándar ---
uniform vec4  base_color           : source_color = vec4(0.08, 0.18, 0.12, 0.12);
uniform float roughness            : hint_range(0.0, 1.0)  = 0.02;
uniform float metallic             : hint_range(0.0, 1.0)  = 0.0;
uniform float fresnel_power         : hint_range(1.0, 10.0) = 5.0;
uniform float reflection_intensity : hint_range(0.0, 2.0)  = 0.85;
uniform float ior                  : hint_range(1.0, 2.5)  = 1.52; // Vidrio real
uniform float dispersion           : hint_range(0.0, 0.1)  = 0.018;

// --- Franja Solar ---
uniform float sun_strip_thickness  : hint_range(0.0, 0.5)  = 0.18;
uniform float sun_strip_pos        : hint_range(0.0, 1.0)  = 0.88;
uniform float sun_strip_opacity    : hint_range(0.0, 1.0)  = 0.75;
uniform vec4  sun_strip_color      : source_color = vec4(0.0, 0.0, 0.02, 1.0);

// --- Suciedad ---
uniform float dirt_intensity       : hint_range(0.0, 1.0)  = 0.08;

// --- SISTEMA DE DAÑO (GRIETAS) ---
// Usamos "instance uniform" para que el script pueda romper cada vidrio por separado
instance uniform float damage_amount : hint_range(0.0, 1.0) = 0.0; 
uniform sampler2D crack_tex          : source_color; // Textura de grietas tipo telaraña
uniform float crack_scale            : hint_range(0.1, 5.0) = 1.0;

void fragment() {
    // =====================================================
    // 1. CÁLCULOS DE VISTA Y NORMALES
    // =====================================================
    float cos_theta = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    
    // Perturbación sutil (vidrio no perfecto)
    float noise_n = sin(UV.x * 200.0 + UV.y * 150.0) * 0.002;
    vec3 normal_pert = normalize(NORMAL + vec3(noise_n, noise_n, 0.0));
    
    // Fresnel de Schlick
    float f0 = pow((1.0 - ior) / (1.0 + ior), 2.0);
    float fresnel = f0 + (1.0 - f0) * pow(1.0 - cos_theta, fresnel_power);
    
    // Dirección de reflexión
    vec3 reflect_dir = reflect(-VIEW, NORMAL);

    // =====================================================
    // 2. SISTEMA DE GRIETAS DINÁMICAS
    // =====================================================
    // Leemos la textura de grietas (canal R usualmente)
    vec4 crack_data = texture(crack_tex, UV * crack_scale);
    
    // Máscara de daño: a medida que damage_amount sube, más grietas aparecen
    float crack_mask = smoothstep(1.0 - damage_amount, (1.0 - damage_amount) + 0.05, crack_data.r);
    
    // Distorsión física: las grietas cambian la normal del vidrio
    // Para el reflejo se "rompa" visualmente
    vec3 normal_damaged = normalize(NORMAL + (crack_data.rgb * 0.4 * damage_amount));
    vec3 final_normal = mix(normal_pert, normal_damaged, crack_mask);

    // =====================================================
    // 3. REFLEJOS Y DISPERSIÓN
    // =====================================================
    float sky_ref = clamp(reflect_dir.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 col_reflejo = mix(vec3(0.15, 0.15, 0.15), vec3(0.4, 0.6, 0.9), sky_ref);
    
    // Dispersión cromática en bordes
    float disp_r = pow(1.0 - clamp(cos_theta + dispersion, 0.0, 1.0), fresnel_power);
    float disp_b = pow(1.0 - clamp(cos_theta - dispersion, 0.0, 1.0), fresnel_power);
    vec3 dispersion_col = vec3(disp_r, fresnel, disp_b) * 0.1;

    // =====================================================
    // 4. FRANJA SOLAR Y SUCIEDAD
    // =====================================================
    float strip_mask = smoothstep(sun_strip_pos, sun_strip_pos - 0.02, UV.y) * smoothstep(sun_strip_pos - sun_strip_thickness, sun_strip_pos - sun_strip_thickness + 0.04, UV.y);
    
    float dirt_pattern = (sin(UV.x * 50.0) * cos(UV.y * 40.0) * 0.5 + 0.5);
    float dirt = smoothstep(0.5, 0.9, dirt_pattern) * dirt_intensity;

    // =====================================================
    // 5. COMPOSICIÓN FINAL
    // =====================================================
    vec3 col_vidrio = base_color.rgb;
    
    // Mezclar reflejos según Fresnel
    col_vidrio = mix(col_vidrio, col_reflejo, fresnel * reflection_intensity);
    col_vidrio += dispersion_col * reflection_intensity;
    
    // Tinte de franja solar
    col_vidrio = mix(col_vidrio, sun_strip_color.rgb, strip_mask * sun_strip_opacity);
    
    // Aplicar suciedad
    col_vidrio = mix(col_vidrio, col_vidrio * 0.8 + vec3(0.05), dirt);
    
    // Color de la grieta: el vidrio roto dispersa mucha luz (blanco/cian)
    vec3 col_grieta = vec3(0.85, 0.9, 1.0);
    col_vidrio = mix(col_vidrio, col_grieta, crack_mask * 0.8 * damage_amount);

    // --- Salidas ---
    ALBEDO = col_vidrio;
    
    // El vidrio roto es extremadamente rugoso y difuso
    ROUGHNESS = mix(roughness + dirt, 0.5, crack_mask * damage_amount);
    METALLIC = metallic;
    SPECULAR = 1.0;
    NORMAL = final_normal;

    // ALPHA: Transparencia base + fresnel + opacidad de las grietas
    float alpha_base = mix(base_color.a, sun_strip_color.a, strip_mask * sun_strip_opacity);
    // El vidrio fracturado se vuelve opaco por las micro-roturas
    float alpha_fractura = crack_mask * damage_amount * 0.6; 
    
    ALPHA = clamp(alpha_base + (fresnel * 0.6 * reflection_intensity) + alpha_fractura, 0.0, 1.0);
}