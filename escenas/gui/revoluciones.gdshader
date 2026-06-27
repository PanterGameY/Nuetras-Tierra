shader_type canvas_item;

// --- Parámetros de Control ---
uniform float rpm : hint_range(0.0, 8000.0) = 3500.0;
uniform float max_rpm : hint_range(0.0, 8000.0) = 8000.0;
uniform vec2 canvas_size = vec2(300.0, 300.0);

// --- Colores y Estética ---
uniform vec4 needle_color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform vec4 bg_dark : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 blue_zone : source_color = vec4(0.0, 0.8, 1.0, 0.6);
uniform vec4 red_zone : source_color = vec4(1.0, 0.0, 0.0, 0.8);
uniform vec4 metal_color : source_color = vec4(0.7, 0.7, 0.75, 1.0);

// --- Configuración de Ángulos ---
// Ajustados para que coincidan con la imagen (0 a las 7-8 en punto)
uniform float start_angle : hint_range(-360.0, 360.0) = -225.0;
uniform float end_angle : hint_range(-360.0, 360.0) = 45.0;
uniform int num_ticks = 9;

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float sdArcPanel(vec2 p, float r, float cut) {
    float d = length(p) - r;
    return max(d, p.y - cut);
}

void fragment() {
    vec2 uv = (UV - 0.5) * 2.0;
    uv.x *= canvas_size.x / canvas_size.y;
    vec2 p = uv;
    
    vec4 out_col = vec4(0.0);
    float radius = 0.85;
    
    // 1. FORMA DEL PANEL
    float panel_sdf = sdArcPanel(p, radius, 0.65);
    float mask = 1.0 - smoothstep(0.0, 0.01, panel_sdf);
    
    // 2. FONDO FIBRA DE CARBONO
    vec2 carbon_uv = UV * 60.0;
    float carbon = step(0.5, fract((carbon_uv.x + carbon_uv.y) * 0.5)) * 0.1 + 0.9;
    out_col = mix(out_col, bg_dark * carbon, mask);

    // --- CORRECCIÓN DE ÁNGULO Y ZONAS ---
    float angle_rad = atan(p.y, p.x);
    float angle_deg = degrees(angle_rad);
    
    // Normalizar ángulo para evitar el salto de -180 a 180
    if (angle_deg > end_angle + 10.0) angle_deg -= 360.0;
    
    // Factor T: 0.0 en el inicio (azul), 1.0 en el final (rojo)
    float t_zone = clamp((angle_deg - start_angle) / (end_angle - start_angle), 0.0, 1.0);
    
    // Anillo de luz (Glow)
    float ring_dist = abs(length(p) - (radius - 0.08));
    float zone_mask = (1.0 - smoothstep(0.0, 0.12, ring_dist)) * mask;
    
    // Solo pintar color si estamos dentro del rango de ángulos
    if (angle_deg >= start_angle && angle_deg <= end_angle) {
        vec4 zone_col = mix(blue_zone, red_zone, smoothstep(0.5, 0.9, t_zone));
        // Intensidad mayor en los bordes del anillo
        out_col += zone_col * zone_mask;
    }

    // 4. TICKS
    int total_sub = (num_ticks - 1) * 10;
    for (int i = 0; i <= total_sub; i++) {
        float t = float(i) / float(total_sub);
        float ang = radians(mix(start_angle, end_angle, t));
        vec2 dir = vec2(cos(ang), sin(ang));
        
        bool is_main = (i % 10 == 0);
        float l = is_main ? 0.12 : 0.06;
        float w = is_main ? 0.012 : 0.005;
        
        float dseg = sdSegment(p, dir * (radius - 0.05 - l), dir * (radius - 0.05));
        float t_mask = 1.0 - smoothstep(w, w + 0.005, dseg);
        out_col = mix(out_col, vec4(1.0), t_mask * mask);
    }

    // 5. BORDE METÁLICO
    float border_sdf = abs(panel_sdf);
    float border_mask = (1.0 - smoothstep(0.0, 0.05, border_sdf)) * (1.0 - mask);
    out_col = mix(out_col, metal_color + (smoothstep(0.4, 0.5, abs(uv.x + uv.y)) * 0.3), border_mask);

    // 6. AGUJA Y CAPA CENTRAL
    float rpm_ratio = clamp(rpm / max_rpm, 0.0, 1.0);
    float needle_ang = radians(mix(start_angle, end_angle, rpm_ratio));
    vec2 n_dir = vec2(cos(needle_ang), sin(needle_ang));
    
    float d_needle = sdSegment(p, vec2(0.0), n_dir * 0.75);
    float n_mask = 1.0 - smoothstep(0.015, 0.02, d_needle);
    
    float cap = 1.0 - smoothstep(0.07, 0.08, length(p));
    out_col = mix(out_col, needle_color, n_mask * mask);
    out_col = mix(out_col, bg_dark, cap * mask);

    COLOR = out_col;
}