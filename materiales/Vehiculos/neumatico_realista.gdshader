shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Caucho;
uniform vec4 color_flanco : source_color = vec4(0.085, 0.09, 0.098, 1.0);
uniform vec4 color_banda : source_color = vec4(0.125, 0.13, 0.138, 1.0);
uniform float rugosidad_flanco : hint_range(0.2, 1.0) = 0.62;
uniform float rugosidad_banda : hint_range(0.2, 1.0) = 0.86;
uniform float especular_caucho : hint_range(0.0, 1.0) = 0.32;

group_uniforms Detalle_Micro;
uniform float escala_grano : hint_range(20.0, 400.0) = 140.0;
uniform float fuerza_grano : hint_range(0.0, 0.25) = 0.08;
uniform float fuerza_normal_grano : hint_range(0.0, 0.2) = 0.045;

varying vec3 v_local_pos;
varying vec3 v_local_norm;

float hash31(vec3 p) {
	p = fract(p * vec3(443.8975, 397.2973, 491.1871));
	p += dot(p, p.yzx + 19.19);
	return fract(p.x * p.y * p.z);
}

void vertex() {
	v_local_pos = VERTEX;
	v_local_norm = NORMAL;
}

void fragment() {
	vec3 n_loc = normalize(v_local_norm);
	// En ruedas orientadas en eje X: caras laterales (flanco) tienen |n_loc.x| alto
	float es_flanco = smoothstep(0.25, 0.72, abs(n_loc.x));

	// Micro-grano de caucho vulcanizado en espacio local (rota con la rueda sin deslizarse)
	vec3 cell = floor(v_local_pos * escala_grano);
	float g0 = hash31(cell);
	float gx = hash31(cell + vec3(1.0, 0.0, 0.0));
	float gz = hash31(cell + vec3(0.0, 0.0, 1.0));

	// Anillo sutil radial en el flanco para dar relieve realista de neumático
	float r_flanco = length(v_local_pos.yz);
	float estria_radial = sin(r_flanco * 95.0) * 0.5 + 0.5;
	float micro_var = (g0 - 0.5) * fuerza_grano;

	vec3 base_col = mix(color_banda.rgb, color_flanco.rgb, es_flanco);
	base_col += vec3(micro_var) + vec3(estria_radial * 0.012 * es_flanco);

	// Fresnel suave propio de goma satinada en ángulos rasantes
	float n_dot_v = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - n_dot_v, 3.2);
	base_col = mix(base_col, base_col * 1.35 + vec3(0.025), fresnel * 0.38 * es_flanco);

	// Perturbación sutil de normales para romper el aspecto plástico liso
	vec3 n_pert = vec3((gx - g0) * fuerza_normal_grano, 0.0, (gz - g0) * fuerza_normal_grano);
	NORMAL = normalize(NORMAL + n_pert);

	ALBEDO = clamp(base_col, vec3(0.0), vec3(1.0));
	METALLIC = 0.0;
	ROUGHNESS = clamp(mix(rugosidad_banda, rugosidad_flanco, es_flanco) + (g0 - 0.5) * 0.06, 0.35, 0.96);
	SPECULAR = especular_caucho;
}
