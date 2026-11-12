// ═══════════════════════════════════════════════════════════════════════════════
// cromo_automotriz.gdshader
// Shader de Cromo Automotriz Fotorrealista para Vehículos Pesados
// Simula reflectividad de cromo puro (F0/F90 Schlick), micro-pulido y reacción a lluvia.
// Proyecto: Nuestra Tierra 2.0
// ═══════════════════════════════════════════════════════════════════════════════
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

group_uniforms Cromo_Base;
// Tinte base metálico (blanco frío acerado característico del cromo automotriz)
uniform vec4 color_cromo : source_color = vec4(0.92, 0.94, 0.97, 1.0);
// Nivel de metalicidad (1.0 para cromo puro)
uniform float metalico : hint_range(0.0, 1.0, 0.01) = 1.0;
// Rugosidad especular (0.035 da brillo espejo de alta fidelidad sin aliasing)
uniform float rugosidad_base : hint_range(0.01, 0.3, 0.005) = 0.035;
// Reflectividad especular
uniform float especular : hint_range(0.0, 1.0, 0.05) = 0.95;

group_uniforms Reflejo_Fresnel;
// Intensidad del brillo en ángulos rasantes (curvatura de tubos y rines)
uniform float fuerza_fresnel : hint_range(0.0, 2.0, 0.05) = 0.45;
// Tinte del borde en ángulo rasante
uniform vec4 tinte_borde : source_color = vec4(0.97, 0.98, 1.0, 1.0);

group_uniforms Micro_Pulido;
// Simula el micro-grano de pulido que elimina la apariencia plástica/sintética
uniform bool activar_micro_pulido = true;
uniform float escala_micro_pulido : hint_range(10.0, 300.0, 10.0) = 120.0;
uniform float fuerza_micro_pulido : hint_range(0.0, 0.05, 0.002) = 0.012;

group_uniforms Clima;
// Nivel de lluvia / humedad ambiental transmitido por el controlador de clima
uniform float nivel_lluvia : hint_range(0.0, 1.0, 0.01) = 0.0;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 n = NORMAL;
	vec3 v = VIEW;
	float n_dot_v = clamp(dot(n, v), 0.0, 1.0);
	float fresnel = pow(1.0 - n_dot_v, 3.5);

	// 1. Albedo con respuesta física Fresnel de conductor
	vec3 albedo_final = mix(color_cromo.rgb, tinte_borde.rgb, fresnel * fuerza_fresnel);

	// 2. Micro-pulido industrial (funciona tanto con UVs como con coordenadas de vértice)
	float micro_rugosidad = rugosidad_base;
	if (activar_micro_pulido) {
		vec2 coords = (UV != vec2(0.0)) ? UV * escala_micro_pulido : (VERTEX.xy + VERTEX.yz) * (escala_micro_pulido * 0.1);
		float ruido = hash21(floor(coords)) * 2.0 - 1.0;

		// Micro-perturbación que dispersa sutilmente los brillos a lo largo de las curvas
		NORMAL = normalize(NORMAL + vec3(ruido * fuerza_micro_pulido, 0.0, ruido * fuerza_micro_pulido));
		micro_rugosidad += abs(ruido) * 0.010;
	}

	// 3. Gotas microscópicas de condensación / salpicadura en lluvia
	if (nivel_lluvia > 0.05) {
		vec2 uv_gotas = (UV != vec2(0.0)) ? UV * 55.0 : VERTEX.xz * 12.0;
		float gota = step(0.85, hash21(floor(uv_gotas)));
		micro_rugosidad = mix(micro_rugosidad, 0.25, gota * nivel_lluvia * 0.80);
		albedo_final = mix(albedo_final, albedo_final * 0.88, gota * nivel_lluvia * 0.25);
	}

	ALBEDO = albedo_final;
	METALLIC = metalico;
	ROUGHNESS = clamp(micro_rugosidad, 0.02, 1.0);
	SPECULAR = especular;
}
