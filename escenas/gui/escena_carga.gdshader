// =====================================================
//  velocimetro.gdshader — Godot 4
//  Velocímetro circular estilo cuentakilómetros
//  Para usar en un TextureRect cuadrado (ej. 220x220)
// =====================================================
shader_type canvas_item;

uniform float progress     : hint_range(0.0, 1.0) = 0.0;
uniform vec4  color_vacio  : source_color = vec4(0.08, 0.12, 0.06, 1.0);
uniform vec4  color_lleno  : source_color = vec4(0.15, 0.55, 0.1,  1.0);
uniform vec4  color_punta  : source_color = vec4(0.95, 0.55, 0.05, 1.0);
uniform vec4  color_fondo  : source_color = vec4(0.05, 0.08, 0.03, 1.0);
uniform float grosor       : hint_range(0.02, 0.25) = 0.10;
uniform float angulo_inicio: hint_range(0.0, 6.28)  = 3.93; // 225°
uniform float angulo_total : hint_range(0.5,  6.28)  = 4.71; // 270°
uniform float brillo_speed : hint_range(0.0,  4.0)   = 1.8;
uniform float tick_count   : hint_range(4.0, 32.0)   = 12.0;


float sdf_arco(vec2 uv, float r_int, float r_ext, float a_ini, float a_fin) {
	float r = length(uv);
	if (r < r_int || r > r_ext) return 0.0;
	float ang = atan(uv.y, uv.x);
	ang = mod(ang - a_ini + TAU * 2.0, TAU);
	float rango = mod(a_fin - a_ini + TAU * 2.0, TAU);
	return step(ang, rango);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0; // centrar [-1, 1]

	float r = length(uv);
	float ang = atan(uv.y, uv.x);

	// ── Fondo circular ──────────────────────────────
	float mascara_circulo = 1.0 - smoothstep(0.97, 1.0, r);
	vec4 col = color_fondo * mascara_circulo;

	// ── Borde exterior ──────────────────────────────
	float borde_ext = smoothstep(0.90, 0.92, r) * smoothstep(1.0, 0.97, r);
	col = mix(col, vec4(0.25, 0.45, 0.12, 1.0), borde_ext * mascara_circulo);

	// ── Aro de fondo (gris oscuro) ──────────────────
	float r_int = 0.60;
	float r_ext = 0.60 + grosor;
	float aro_bg = sdf_arco(uv, r_int, r_ext, angulo_inicio,
		angulo_inicio + angulo_total);
	col = mix(col, color_vacio, aro_bg * 0.6);

	// ── Aro de progreso ─────────────────────────────
	float a_fin_prog = angulo_inicio + angulo_total * progress;
	float aro_prog = sdf_arco(uv, r_int, r_ext, angulo_inicio, a_fin_prog);

	// Gradiente verde → naranja según progreso
	vec4 c_prog = mix(color_lleno, color_punta, progress);

	// Brillo animado sobre el arco
	float brillo_t = fract(TIME * brillo_speed * 0.3);
	float brillo_ang = angulo_inicio + angulo_total * brillo_t * progress;
	float brillo_ang_uv = mod(ang - angulo_inicio + TAU * 2.0, TAU);
	float brillo_rango = mod(brillo_ang - angulo_inicio + TAU * 2.0, TAU);
	float brillo = (1.0 - smoothstep(0.0, 0.18, abs(brillo_ang_uv - brillo_rango)))
				 * float(brillo_ang_uv < brillo_rango + 0.01);
	c_prog.rgb += brillo * 0.5 * c_prog.rgb;

	col = mix(col, c_prog, aro_prog);

	// ── Punta luminosa en el frente del arco ────────
	float punta_ang = mod(a_fin_prog, TAU);
	float ang_norm  = mod(ang - punta_ang + TAU * 2.0, TAU);
	float punta     = (1.0 - smoothstep(0.0, 0.08, ang_norm))
					* smoothstep(0.60, 0.62, r) * smoothstep(r_ext + 0.02, r_ext, r);
	col = mix(col, color_punta, punta * aro_prog * 0.8 + punta * step(0.001, progress) * 0.6);

	// ── Ticks (marcas del velocímetro) ──────────────
	float ticks = tick_count;
	for (float i = 0.0; i < 32.0; i++) {
		if (i >= ticks) break;
		float t_ang = angulo_inicio + angulo_total * (i / (ticks - 1.0));
		vec2 dir = vec2(cos(t_ang), sin(t_ang));
		float dist_linea = abs(dot(uv - dir * 0.73, vec2(-dir.y, dir.x)));
		float en_rango   = step(0.68, dot(uv, dir)) * step(dot(uv, dir), 0.80);
		float es_grande  = step(fract(i / 3.0), 0.01); // cada 3 ticks, uno largo
		float largo = mix(0.006, 0.009, es_grande);
		float tick_mask = (1.0 - smoothstep(0.0, largo, dist_linea)) * en_rango;
		vec4 c_tick = (i / (ticks - 1.0) <= progress)
			? mix(color_lleno, color_punta, i / (ticks - 1.0))
			: vec4(0.3, 0.4, 0.2, 0.6);
		col = mix(col, c_tick, tick_mask * mascara_circulo);
	}

	// ── Centro (hub) ────────────────────────────────
	float hub = 1.0 - smoothstep(0.08, 0.11, r);
	col = mix(col, color_punta * 0.9, hub * mascara_circulo);
	float hub_brillo = 1.0 - smoothstep(0.0, 0.06, r);
	col = mix(col, vec4(1.0, 0.9, 0.6, 1.0), hub_brillo * mascara_circulo * 0.7);

	// ── Aguja ───────────────────────────────────────
	float aguja_ang = angulo_inicio + angulo_total * progress;
	vec2 dir_aguja  = vec2(cos(aguja_ang), sin(aguja_ang));
	float dist_aguja = abs(dot(uv, vec2(-dir_aguja.y, dir_aguja.x)));
	float aguja_long = step(0.0, dot(uv, dir_aguja)) * step(dot(uv, dir_aguja), 0.58);
	float aguja_mask = (1.0 - smoothstep(0.0, 0.018, dist_aguja)) * aguja_long;
	col = mix(col, color_punta, aguja_mask * mascara_circulo);

	// ── Descarte fuera del círculo ───────────────────
	col.a *= mascara_circulo;
	COLOR = col;
}