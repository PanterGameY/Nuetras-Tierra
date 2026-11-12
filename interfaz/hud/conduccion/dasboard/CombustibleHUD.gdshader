shader_type canvas_item;

// Nivel de combustible normalizado (0 = vacío, 1 = lleno)
uniform float combustible : hint_range(0.0, 1.0) = 1.0;
// Opacidad global del panel
uniform float opacidad    : hint_range(0.0, 1.0) = 1.0;

// Gradiente del arco: rojo (vacío) → ámbar → blanco (lleno)
vec3 col_comb(float prog) {
	if (prog < 0.30) return mix(vec3(1.00, 0.18, 0.04), vec3(1.00, 0.72, 0.10), prog / 0.30);
	if (prog < 0.60) return mix(vec3(1.00, 0.72, 0.10), vec3(0.92, 0.95, 1.00), (prog - 0.30) / 0.30);
	return vec3(0.92, 0.95, 1.00);
}

void fragment() {
	// ── Coordenadas centradas, +y apunta hacia arriba ──────────────────────
	vec2 uv = UV * 2.0 - 1.0;
	uv.y    = -uv.y;
	float r = length(uv);

	// ── Mismo arco de 270° que el velocímetro ─────────────────────────────
	float ang    = atan(uv.x, uv.y);
	float A_INI  = -PI * 0.75;
	float A_SPAN =  PI * 1.5;

	float prog     = (ang - A_INI) / A_SPAN;
	float en_gauge = step(0.0, prog) * step(prog, 1.0);

	// ── Anillo ────────────────────────────────────────────────────────────
	const float R_OUT    = 0.85;
	const float R_IN     = 0.70;
	const float R_MID    = (R_OUT + R_IN) * 0.5;
	const float H_GROSOR = (R_OUT - R_IN) * 0.5;

	float en_anillo = smoothstep(R_IN  - 0.012, R_IN  + 0.012, r)
	                * smoothstep(R_OUT + 0.012, R_OUT - 0.012, r);

	float activo   = step(prog, combustible)          * en_gauge * en_anillo;
	float inactivo = (1.0 - step(prog, combustible))  * en_gauge * en_anillo;
	vec3  col_prog = col_comb(prog);

	// ── Glow radial ───────────────────────────────────────────────────────
	float glow_ang = step(prog, combustible) * en_gauge;
	float glow_rad = exp(-pow((r - R_MID) / (H_GROSOR * 1.6), 2.0));
	float glow     = glow_ang * glow_rad * 0.50;

	// ── Ticks ─────────────────────────────────────────────────────────────
	float tick_acc = 0.0;
	for (int i = 0; i <= 18; i++) {
		float t_i  = float(i) / 18.0;
		float ai   = A_INI + t_i * A_SPAN;
		float d_a  = abs(ang - ai);
		bool  mayor = (i % 2 == 0);

		float r_in_t  = mayor ? R_IN  - 0.09 : R_IN  - 0.01;
		float r_out_t = mayor ? R_OUT + 0.05 : R_OUT + 0.01;
		float ang_w   = mayor ? 0.022        : 0.014;

		float en_t = smoothstep(ang_w, ang_w * 0.20, d_a)
		           * step(r_in_t, r) * step(r, r_out_t);
		tick_acc = max(tick_acc, en_t);
	}

	// ── Punta brillante en el nivel actual ────────────────────────────────
	float ang_punta = A_INI + combustible * A_SPAN;
	float d_a_p     = abs(ang - ang_punta);
	float en_punta  = smoothstep(0.035, 0.003, d_a_p)
	                * smoothstep(R_IN  - 0.08, R_IN  + 0.02, r)
	                * smoothstep(R_OUT + 0.08, R_OUT - 0.02, r);

	// ── Fondo circular ────────────────────────────────────────────────────
	float R_PAN = 0.97;
	float fondo  = smoothstep(R_PAN, R_PAN - 0.04, r);
	float grad   = 1.0 - r * 0.22;

	// Rim difuminado hacia abajo
	float rim_base = smoothstep(R_PAN - 0.04, R_PAN - 0.07, r)
	               * (1.0 - smoothstep(R_PAN - 0.07, R_PAN - 0.10, r));
	float rim_fade = smoothstep(-0.85, -0.10, uv.y);
	float rim      = rim_base * rim_fade;

	// Punto central decorativo
	float cdot = smoothstep(0.08, 0.055, r);

	// ── Composición ───────────────────────────────────────────────────────
	vec3 COL_BG    = vec3(0.06, 0.06,  0.07) * grad;
	vec3 COL_PISTA = vec3(0.18, 0.18,  0.19);
	vec3 COL_RIM   = vec3(0.75, 0.77,  0.80);
	vec3 COL_TICKS = vec3(0.92, 0.94,  0.96);
	vec3 COL_CDOT  = vec3(0.30, 0.30,  0.32);
	vec3 col_vel   = col_comb(combustible);

	vec3 col = COL_BG;
	col = mix(col, COL_RIM,    rim);
	col = mix(col, COL_PISTA,  inactivo);
	col = mix(col, col_prog,   activo);
	col += col_vel * glow;
	col = mix(col, COL_TICKS,  tick_acc * fondo);
	col = mix(col, vec3(1.0),  en_punta * 0.96);
	col += col_vel * en_punta * 0.55;
	col = mix(col, COL_CDOT,   cdot);

	// Fondo translúcido, elementos opacos
	float elem = clamp(
		(activo + inactivo) * en_anillo + tick_acc + en_punta + cdot + rim * 2.0,
		0.0, 1.0);
	float alfa = mix(0.18, opacidad, elem) * fondo;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(2.5)), alfa);
}
