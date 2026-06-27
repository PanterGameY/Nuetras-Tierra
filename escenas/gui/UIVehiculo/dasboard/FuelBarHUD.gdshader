shader_type canvas_item;

// ── Datos dinámicos ────────────────────────────────────────────────────────
uniform float combustible : hint_range(0.0, 1.0) = 1.0;
uniform float opacidad    : hint_range(0.0, 1.0) = 1.0;

// ── Colores configurables ─────────────────────────────────────────────────
uniform vec4 col_vacio    : source_color = vec4(1.00, 0.18, 0.04, 1.0);
uniform vec4 col_medio    : source_color = vec4(1.00, 0.72, 0.10, 1.0);
uniform vec4 col_lleno    : source_color = vec4(0.92, 0.95, 1.00, 1.0);
uniform vec4 col_pista    : source_color = vec4(0.18, 0.18, 0.19, 1.0);
uniform float ancho_barra : hint_range(4.0, 24.0) = 12.0;
uniform float glow_intens : hint_range(0.0, 1.0) = 0.30;

// ─── Gradiente rojo → ámbar → blanco ──────────────────────────────────────
vec3 col_fuel(float nivel) {
	if (nivel < 0.30) return mix(col_vacio.rgb, col_medio.rgb, nivel / 0.30);
	if (nivel < 0.60) return mix(col_medio.rgb, col_lleno.rgb, (nivel - 0.30) / 0.30);
	return col_lleno.rgb;
}

// ─── Geometría ────────────────────────────────────────────────────────────
// ColorRect: 47 × 170 px, hijo de PanelVelocimetro (220 × 220)
// Centro del velocímetro en coordenadas locales: (-80, 85), radio ≈ 107 px

void fragment() {
	float py = UV.y * 170.0;

	// Borde derecho del círculo en este Y
	float dy     = py - 85.0;
	float circ_x = -80.0 + sqrt(max(0.0, 107.0 * 107.0 - dy * dy));
	float circ_u = circ_x / 47.0;

	// Franja de ancho_barra px que arranca en el borde del círculo
	float sl     = max(0.0, circ_u);
	float sr     = sl + ancho_barra / 47.0;
	float in_bar = step(sl, UV.x) * step(UV.x, sr);

	// ── Nivel: llena de abajo (UV.y=1) a arriba (UV.y=0) ──────────────────
	float fill_y = 1.0 - combustible;
	float active = step(fill_y, UV.y);
	float nivel  = 1.0 - UV.y;

	// ── Punta nítida en el límite de llenado (sin fade) ───────────────────
	float tip    = smoothstep(0.022, 0.0, abs(UV.y - fill_y)) * in_bar;

	// ── Sheen: reflejo de luz en el borde izquierdo de la barra ───────────
	float bar_u = (UV.x - sl) / max(sr - sl, 0.001);
	float sheen = smoothstep(0.0, 0.28, bar_u) * (1.0 - smoothstep(0.28, 0.62, bar_u));
	sheen      *= active * 0.20;

	// ── Color ─────────────────────────────────────────────────────────────
	vec3 col = mix(col_pista.rgb, col_fuel(nivel), active);
	col += col_fuel(combustible) * active * glow_intens;   // glow activo
	col += vec3(sheen);                                     // reflejo gloss
	col  = mix(col, vec3(1.0), tip * 0.96);                // punta blanca
	col += col_fuel(combustible) * tip * 0.40;             // tinte en punta

	// ── Alpha: pista oscura, zona activa opaca, bordes nítidos ────────────
	float alfa = mix(0.50 * opacidad, opacidad, active);
	alfa = max(alfa, tip * opacidad);
	alfa *= in_bar;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), clamp(alfa, 0.0, 1.0));
}
