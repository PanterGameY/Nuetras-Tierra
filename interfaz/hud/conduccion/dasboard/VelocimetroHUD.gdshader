shader_type canvas_item;

// ── Datos dinámicos (actualizados por GDScript cada frame) ────────────────
uniform float velocidad   : hint_range(0.0, 1.0) = 0.0;
uniform float opacidad    : hint_range(0.0, 1.0) = 1.0;
uniform float rpm_norm    : hint_range(0.0, 1.0) = 0.0;

// ── Colores del arco de velocidad ─────────────────────────────────────────
uniform vec4 col_arco_bajo    : source_color = vec4(0.92, 0.95, 1.00, 1.0);
uniform vec4 col_arco_medio   : source_color = vec4(1.00, 0.80, 0.10, 1.0);
uniform vec4 col_arco_alto    : source_color = vec4(1.00, 0.18, 0.04, 1.0);

// ── Colores del anillo de RPM ─────────────────────────────────────────────
uniform vec4 col_rpm_bajo     : source_color = vec4(0.30, 0.65, 1.00, 1.0);
uniform vec4 col_rpm_medio    : source_color = vec4(0.92, 0.95, 1.00, 1.0);
uniform vec4 col_rpm_caliente : source_color = vec4(1.00, 0.72, 0.10, 1.0);
uniform vec4 col_rpm_maximo   : source_color = vec4(1.00, 0.18, 0.04, 1.0);

// ── Colores del panel ─────────────────────────────────────────────────────
uniform vec4 col_fondo_panel  : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform vec4 col_pista_arco   : source_color = vec4(0.18, 0.18, 0.19, 1.0);
uniform vec4 col_pista_rpm    : source_color = vec4(0.14, 0.14, 0.16, 1.0);
uniform vec4 col_borde_rim    : source_color = vec4(0.75, 0.77, 0.80, 1.0);
uniform vec4 col_marcas       : source_color = vec4(0.92, 0.94, 0.96, 1.0);

// ── Intensidades y opacidad ───────────────────────────────────────────────
uniform float glow_intensidad : hint_range(0.0, 2.0) = 0.50;
uniform float opacidad_fondo  : hint_range(0.0, 0.50) = 0.18;

// Gradiente del anillo RPM: azul → blanco → ámbar → rojo
vec3 col_rpm(float t) {
	if (t < 0.65) return mix(col_rpm_bajo.rgb, col_rpm_medio.rgb, t / 0.65);
	if (t < 0.85) return mix(col_rpm_medio.rgb, col_rpm_caliente.rgb, (t - 0.65) / 0.20);
	return mix(col_rpm_caliente.rgb, col_rpm_maximo.rgb, (t - 0.85) / 0.15);
}

// Gradiente de color del arco: blanco → amarillo → rojo
vec3 col_velocidad(float t) {
	if (t < 0.5) return mix(col_arco_bajo.rgb, col_arco_medio.rgb, t * 2.0);
	return mix(col_arco_medio.rgb, col_arco_alto.rgb, (t - 0.5) * 2.0);
}

void fragment() {
	// ── Coordenadas centradas, +y apunta hacia arriba ──────────────────────
	vec2 uv = UV * 2.0 - 1.0;
	uv.y    = -uv.y;
	float r = length(uv);

	// ── Ángulo desde +y en sentido horario  (atan(x,y)) ───────────────────
	// atan(0, 1)=0   → 12 en punto
	// atan(1, 0)=π/2 → 3 en punto
	// atan(-1,0)=-π/2→ 9 en punto
	float ang    = atan(uv.x, uv.y);
	float A_INI  = -PI * 0.75;   // -135° = posición 7:30 (inf-izq)
	float A_SPAN =  PI * 1.5;    //  270° de barrido horario

	// Progreso del arco [0..1]  (0=inicio inf-izq, 0.5=arriba, 1=inf-der)
	float prog     = (ang - A_INI) / A_SPAN;
	float en_gauge = step(0.0, prog) * step(prog, 1.0);

	// ── Geometría del anillo ──────────────────────────────────────────────
	const float R_OUT   = 0.85;
	const float R_IN    = 0.70;
	const float R_MID   = (R_OUT + R_IN) * 0.5;
	const float H_GROSOR = (R_OUT - R_IN) * 0.5;

	float en_anillo = smoothstep(R_IN  - 0.012, R_IN  + 0.012, r)
	                * smoothstep(R_OUT + 0.012, R_OUT - 0.012, r);

	// Partes activa / inactiva del arco
	float activo   = step(prog, velocidad)         * en_gauge * en_anillo;
	float inactivo = (1.0 - step(prog, velocidad)) * en_gauge * en_anillo;
	vec3  col_prog = col_velocidad(prog);

	// ── Glow radial suave alrededor del arco activo ───────────────────────
	float glow_ang = step(prog, velocidad) * en_gauge;
	float glow_rad = exp(-pow((r - R_MID) / (H_GROSOR * 1.6), 2.0));
	float glow     = glow_ang * glow_rad * glow_intensidad;

	// ── Marcas de tick (19 totales, 10 mayores) ───────────────────────────
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

	// ── Anillo interior de RPM ────────────────────────────────────────────
	float R_IN2  = 0.56;
	float R_OUT2 = 0.63;
	float R_MID2 = (R_IN2 + R_OUT2) * 0.5;
	float H_GRPM = (R_OUT2 - R_IN2) * 0.5;

	float en_anillo_rpm = smoothstep(R_IN2 - 0.010, R_IN2 + 0.010, r)
	                    * smoothstep(R_OUT2 + 0.010, R_OUT2 - 0.010, r);

	float rpm_activo   = step(prog, rpm_norm) * en_gauge * en_anillo_rpm;
	float rpm_inactivo = (1.0 - step(prog, rpm_norm)) * en_gauge * en_anillo_rpm;

	float rpm_glow = step(prog, rpm_norm) * en_gauge
	               * exp(-pow((r - R_MID2) / (H_GRPM * 1.6), 2.0)) * (glow_intensidad * 0.70);

	float ang_rpm   = A_INI + rpm_norm * A_SPAN;
	float d_rpm     = abs(ang - ang_rpm);
	float rpm_punta = smoothstep(0.030, 0.002, d_rpm)
	                * smoothstep(R_IN2 - 0.06, R_IN2 + 0.015, r)
	                * smoothstep(R_OUT2 + 0.06, R_OUT2 - 0.015, r);

	// ── Punta brillante en la posición de velocidad actual ────────────────
	float ang_punta = A_INI + velocidad * A_SPAN;
	float d_a_p     = abs(ang - ang_punta);
	float en_punta  = smoothstep(0.035, 0.003, d_a_p)
	                * smoothstep(R_IN  - 0.08, R_IN  + 0.02, r)
	                * smoothstep(R_OUT + 0.08, R_OUT - 0.02, r);

	// ── Fondo circular ────────────────────────────────────────────────────
	float R_PAN = 0.97;
	float fondo  = smoothstep(R_PAN, R_PAN - 0.04, r);
	float grad   = 1.0 - r * 0.22;

	// Borde / rim metálico sutil — difuminado hacia abajo
	float rim_base = smoothstep(R_PAN - 0.04, R_PAN - 0.07, r)
	               * (1.0 - smoothstep(R_PAN - 0.07, R_PAN - 0.10, r));
	float rim_fade = smoothstep(-0.85, -0.10, uv.y); // 0 en la base, 1 en la parte alta
	float rim      = rim_base * rim_fade;

	// Punto central decorativo
	float cdot = smoothstep(0.08, 0.055, r);

	// ── Composición ───────────────────────────────────────────────────────
	vec3 col_vel = col_velocidad(velocidad);

	vec3 col = col_fondo_panel.rgb * grad;
	col = mix(col, col_borde_rim.rgb,  rim);
	col = mix(col, col_pista_arco.rgb, inactivo);
	col = mix(col, col_prog,           activo);
	col += col_vel * glow;
	col = mix(col, col_marcas.rgb,     tick_acc * fondo);
	col = mix(col, vec3(1.0),          en_punta * 0.96);
	col += col_vel * en_punta * 0.55;
	col = mix(col, vec3(0.30, 0.30, 0.32), cdot);

	// ── Anillo RPM ────────────────────────────────────────────────────────
	vec3 col_rpm_cur = col_rpm(rpm_norm);
	col = mix(col, col_pista_rpm.rgb,  rpm_inactivo);
	col = mix(col, col_rpm(prog),      rpm_activo);
	col += col_rpm_cur * rpm_glow;
	col  = mix(col, vec3(1.0),         rpm_punta * 0.88);
	col += col_rpm_cur * rpm_punta * 0.35;

	// ── Alpha ─────────────────────────────────────────────────────────────
	float elem = clamp(
		(activo + inactivo) * en_anillo +
		(rpm_activo + rpm_inactivo) * en_anillo_rpm +
		tick_acc + en_punta + rpm_punta + cdot + rim * 2.0,
		0.0, 1.0);
	float alfa = mix(opacidad_fondo, opacidad, elem) * fondo;
	COLOR = vec4(clamp(col, vec3(0.0), vec3(2.5)), clamp(alfa * COLOR.a, 0.0, 1.0));
}
