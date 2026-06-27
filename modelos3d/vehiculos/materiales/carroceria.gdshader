shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// ═══════════════════════════════════════════════════════════════════════
// carroceria.gdshader — Shader de Pintura Automotriz Premium (Con laca, perlado, daños multinivel realistas y barro)
// ═══════════════════════════════════════════════════════════════════════

group_uniforms Pintura_Base;
// Color principal de la carrocería.
uniform vec4 color_base : source_color = vec4(0.05, 0.22, 0.45, 1.0);
// Nivel metálico de la pintura base (1.0 = metal completo, 0.0 = pintura mate/plástica).
uniform float metalico : hint_range(0.0, 1.0) = 0.85;
// Rugosidad de la pintura base (valores bajos = más reflectiva).
uniform float rugosidad : hint_range(0.0, 1.0) = 0.2;
// Brillo especular de la pintura.
uniform float especular : hint_range(0.0, 1.0) = 0.5;

group_uniforms Pintura_Base.Texturas;
// ¿Usar textura albedo base?
uniform bool usar_textura_albedo = false;
// Textura de albedo base para logos, calcomanías o patrones.
uniform sampler2D textura_albedo : hint_default_white, filter_linear_mipmap;
// ¿Usar mapa de normales?
uniform bool usar_mapa_normales = false;
// Mapa de normales para detalles de superficie.
uniform sampler2D mapa_normales : hint_normal, filter_linear_mipmap;
// Fuerza del relieve de normales.
uniform float fuerza_normales : hint_range(0.0, 2.0) = 1.0;
// ¿Usar mapa de rugosidad?
uniform bool usar_mapa_rugosidad = false;
// Mapa de rugosidad para variar el brillo en partes del chasis.
uniform sampler2D mapa_rugosidad : hint_default_white, filter_linear_mipmap;

group_uniforms Efecto_Perlado_Chameleon;
// ¿Activar el efecto perlado/camaleón (cambio de color según el ángulo de visión)?
uniform bool activar_perlado = true;
// Color secundario hacia el cual cambia la pintura en ángulos extremos.
uniform vec4 color_perlado : source_color = vec4(0.5, 0.05, 0.6, 1.0);
// Exponente fresnel (mayor = el color perlado solo se ve en los bordes muy inclinados).
uniform float perlado_fresnel_power : hint_range(1.0, 8.0) = 3.5;
// Intensidad / mezcla del efecto perlado.
uniform float perlado_intensidad : hint_range(0.0, 1.0) = 0.4;

group_uniforms Capa_Laca_Clearcoat;
// Intensidad de la capa de laca protectora brillante externa.
uniform float laca_clearcoat : hint_range(0.0, 1.0) = 1.0;
// Rugosidad de la capa de laca (valores muy bajos dan reflejos de espejo perfectos).
uniform float laca_rugosidad : hint_range(0.0, 1.0) = 0.03;

group_uniforms Danos_Y_Descascarado;
// Nivel de daño/descascarado global (0 = impecable, 1 = destruido/chocado).
uniform float dano_nivel : hint_range(0.0, 1.0) = 0.0;
// Escala de los parches de pintura descascarada (menor = parches grandes, mayor = pequeños).
uniform float dano_escala_parches : hint_range(1.0, 50.0) = 12.0;
// Escala de los rasguños lineales.
uniform float dano_escala_rayones : hint_range(50.0, 500.0) = 250.0;
// Grosor de los rasguños.
uniform float dano_grosor_rayones : hint_range(0.001, 0.03) = 0.005;
// Relieve/Profundidad 3D en los bordes de la pintura descascarada (simula grosor de la pintura).
uniform float dano_grosor_pintura_3d : hint_range(0.0, 5.0) = 2.0;

group_uniforms Danos_Y_Descascarado.Capas_Internas;
// Color de la imprimación/primer expuesto (capa intermedia de protección antes del metal).
uniform vec4 color_imprimacion : source_color = vec4(0.25, 0.25, 0.25, 1.0);
// Color del metal expuesto profundo (capa final de acero/aluminio brillante).
uniform vec4 color_metal_interno : source_color = vec4(0.65, 0.65, 0.65, 1.0);
// Rugosidad en la zona dañada (el metal/primer expuesto no es liso).
uniform float dano_rugosidad : hint_range(0.0, 1.0) = 0.55;
// ¿Activar óxido en los bordes y zonas de daño antiguo?
uniform bool activar_oxido = true;
// Color del óxido (marrón-rojizo).
uniform vec4 color_oxido : source_color = vec4(0.35, 0.14, 0.05, 1.0);
// Cantidad de óxido dentro del daño.
uniform float oxido_intensidad : hint_range(0.0, 1.0) = 0.5;

group_uniforms Efecto_Barro_Suciedad;
// Nivel de suciedad/barro acumulado (0 = limpio, 1 = barro extremo).
uniform float barro_nivel : hint_range(0.0, 1.0) = 0.0;
// Color del barro seco o polvo.
uniform vec4 barro_color : source_color = vec4(0.25, 0.17, 0.11, 1.0);
// Rugosidad del barro (el barro seco es totalmente opaco y rugoso).
uniform float barro_rugosidad : hint_range(0.0, 1.0) = 0.9;
// Humedad del barro (hace que partes del barro brillen como si estuviera mojado).
uniform float barro_humedad : hint_range(0.0, 1.0) = 0.2;
// Escala de las manchas y salpicaduras de barro.
uniform float barro_ruido_escala : hint_range(1.0, 50.0) = 15.0;
// Altura máxima a la que llega la salpicadura de barro en el chasis.
uniform float barro_altura_maxima : hint_range(-5.0, 5.0) = -0.2;
// Difuminación vertical del barro (mayor = transición más suave hacia arriba).
uniform float barro_caida_vertical : hint_range(0.1, 8.0) = 2.5;

varying vec3 local_pos;

// Hash pseudo-aleatorio 3D
float hash3D(vec3 p) {
	p = fract(p * vec3(443.8975, 397.2973, 491.1871));
	p += dot(p.xyz, p.yzx + 19.19);
	return fract(p.x * p.y * p.z);
}

// Ruido de valor 3D
float ruido3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash3D(i + vec3(0.0, 0.0, 0.0));
	float b = hash3D(i + vec3(1.0, 0.0, 0.0));
	float c = hash3D(i + vec3(0.0, 1.0, 0.0));
	float d = hash3D(i + vec3(1.0, 1.0, 0.0));
	float e = hash3D(i + vec3(0.0, 0.0, 1.0));
	float g = hash3D(i + vec3(1.0, 0.0, 1.0));
	float h = hash3D(i + vec3(0.0, 1.0, 1.0));
	float k = hash3D(i + vec3(1.0, 1.0, 1.0));
	
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
			   mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

// Ruido Fractal Browniano para formas más orgánicas en el barro
float ruido_fbm(vec3 p) {
	float valor = 0.0;
	float amplitud = 0.5;
	float frecuencia = 1.0;
	for (int i = 0; i < 3; i++) {
		valor += amplitud * ruido3D(p * frecuencia);
		frecuencia *= 2.0;
		amplitud *= 0.5;
	}
	return valor;
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Vector de vista normalizado
	vec3 n_view = normalize(VIEW);
	
	// ═══════════════════════════════════════════════════════════════════════
	// 1. OBTENCIÓN DE PINTURA BASE (ALBEDO)
	// ═══════════════════════════════════════════════════════════════════════
	vec3 albedo_final = color_base.rgb;
	if (usar_textura_albedo) {
		vec4 tex = texture(textura_albedo, UV);
		albedo_final *= tex.rgb;
	}
	
	// ═══════════════════════════════════════════════════════════════════════
	// 2. EFECTO PERLADO / CAMALEÓN (FRESNEL)
	// ═══════════════════════════════════════════════════════════════════════
	if (activar_perlado) {
		float fresnel = pow(1.0 - max(dot(NORMAL, n_view), 0.0), perlado_fresnel_power);
		albedo_final = mix(albedo_final, color_perlado.rgb, fresnel * perlado_intensidad);
	}
	
	// ═══════════════════════════════════════════════════════════════════════
	// 3. MAPAS FÍSICOS (METAL, RUGOSIDAD Y NORMALES)
	// ═══════════════════════════════════════════════════════════════════════
	float metalico_final = metalico;
	float rugosidad_final = rugosidad;
	
	if (usar_mapa_rugosidad) {
		rugosidad_final *= texture(mapa_rugosidad, UV).r;
	}
	
	// Laca (Clearcoat) inicial
	float laca_final = laca_clearcoat;
	float laca_rugosidad_final = laca_rugosidad;
	
	// Normal acumulada para perturbar
	vec3 normal_acumulada = NORMAL;
	
	// ═══════════════════════════════════════════════════════════════════════
	// 4. DAÑOS MULTINIVEL REALISTAS (DESCASCARADO, RASGUÑOS Y ÓXIDO)
	// ═══════════════════════════════════════════════════════════════════════
	float mascara_dano_total = 0.0;
	
	if (dano_nivel > 0.0) {
		// A) Zonas de impacto principales (agrupación orgánica del daño)
		float ruido_impactos = ruido3D(local_pos * 2.8) * 0.7 + ruido3D(local_pos * 5.0) * 0.3;
		float mascara_zonas = smoothstep(1.0 - dano_nivel, 1.1 - dano_nivel, ruido_impactos);
		
		if (mascara_zonas > 0.001) {
			// B) Descascarado (Pintura saltada en parches irregulares con bordes duros)
			float ruido_parches = ruido3D(local_pos * dano_escala_parches) * 0.65 + 
			                      ruido3D(local_pos * dano_escala_parches * 2.5) * 0.35;
			float mascara_parches = smoothstep(0.48, 0.52, ruido_parches * mascara_zonas);
			
			// C) Rasguños lineales (Líneas finas)
			vec3 coord_rayas = local_pos * dano_escala_rayones;
			float n1 = ruido3D(coord_rayas);
			float n2 = ruido3D(coord_rayas + vec3(0.1, 0.15, 0.2));
			float rayas = abs(n1 - n2);
			float mascara_rayas = smoothstep(dano_grosor_rayones, 0.0, rayas) * mascara_zonas * 0.7;
			
			// Máscara combinada del daño
			mascara_dano_total = clamp(mascara_parches + mascara_rayas, 0.0, 1.0);
			
			if (mascara_dano_total > 0.001) {
				// D) Relieve 3D en el borde de la pintura descascarada (Normal perturbation)
				// Usamos derivadas de pantalla (dFdx/dFdy) para detectar el borde exacto de la pintura
				vec2 derivadas = vec2(dFdx(mascara_dano_total), dFdy(mascara_dano_total));
				vec3 normal_borde = vec3(-derivadas * dano_grosor_pintura_3d, 0.0);
				normal_acumulada = normalize(normal_acumulada + normal_borde);
				
				// E) Capas de daño multinivel (Primer / Metal Expuesto / Óxido)
				// Si el daño es superficial (ej. bordes o rayas finas): se ve Imprimación (Primer).
				// Si el daño es profundo (centro de parches grandes): se ve Metal Expuesto.
				float factor_profundidad = smoothstep(0.3, 0.8, mascara_dano_total * (ruido_parches * 1.5));
				vec3 color_dano = mix(color_imprimacion.rgb, color_metal_interno.rgb, factor_profundidad);
				
				// Nivel metálico: el metal interno es metálico (1.0), el primer/imprimación no (0.0)
				float metalico_dano = mix(0.0, 1.0, factor_profundidad);
				
				// F) Simulación de Óxido
				if (activar_oxido) {
					// El óxido se concentra en los bordes expuestos del metal y parches de daño
					float ruido_oxido = ruido3D(local_pos * (dano_escala_parches * 1.8));
					float mascara_oxido = smoothstep(0.4, 0.7, ruido_oxido) * mascara_dano_total * oxido_intensidad;
					
					// Mezclamos el color y las propiedades físicas del óxido (el óxido es totalmente dieléctrico y rugoso)
					color_dano = mix(color_dano, color_oxido.rgb, mascara_oxido);
					metalico_dano = mix(metalico_dano, 0.0, mascara_oxido);
				}
				
				// Aplicación de las físicas y albedo del daño sobre la pintura
				albedo_final = mix(albedo_final, color_dano, mascara_dano_total);
				metalico_final = mix(metalico_final, metalico_dano, mascara_dano_total);
				rugosidad_final = mix(rugosidad_final, dano_rugosidad, mascara_dano_total);
				
				// El daño destruye la laca (clearcoat) por completo
				laca_final = mix(laca_final, 0.0, mascara_dano_total);
			}
		}
	}
	
	// ═══════════════════════════════════════════════════════════════════════
	// 5. CAPA DE BARRO Y SUCIEDAD ORGANICA Y PROCEDURAL
	// ═══════════════════════════════════════════════════════════════════════
	if (barro_nivel > 0.0) {
		// Gradiente de altura basado en la posición vertical local (se acumula abajo)
		float gradiente_vertical = clamp((barro_altura_maxima - local_pos.y) * barro_caida_vertical, 0.0, 1.0);
		
		// Ruido detallado orgánico para simular salpicaduras
		float ruido_barro_p1 = ruido_fbm(local_pos * barro_ruido_escala);
		float ruido_barro_p2 = ruido3D(local_pos * (barro_ruido_escala * 3.14)) * 0.3;
		float mascara_barro_ruido = clamp((ruido_barro_p1 + ruido_barro_p2) * 1.5 - 0.25, 0.0, 1.0);
		
		// Combinamos altura y ruido para formar la máscara final de barro
		float mascara_barro = clamp(gradiente_vertical * mascara_barro_ruido * 2.0, 0.0, 1.0) * barro_nivel;
		
		// El barro cubre tanto la pintura como el daño previo
		albedo_final = mix(albedo_final, barro_color.rgb, mascara_barro);
		
		// El barro seco es opaco, pero si tiene humedad brilla un poco de forma desigual
		float rugosidad_barro_real = mix(barro_rugosidad, 0.35, barro_humedad * ruido_barro_p2);
		rugosidad_final = mix(rugosidad_final, rugosidad_barro_real, mascara_barro);
		
		// El barro no es metal
		metalico_final = mix(metalico_final, 0.0, mascara_barro);
		
		// El barro destruye el reflejo de la laca
		laca_final = mix(laca_final, 0.0, mascara_barro);
	}
	
	// ═══════════════════════════════════════════════════════════════════════
	// 6. ASIGNACIONES FINALES AL MOTOR DE RENDER
	// ═══════════════════════════════════════════════════════════════════════
	ALBEDO = albedo_final;
	METALLIC = metalico_final;
	ROUGHNESS = rugosidad_final;
	SPECULAR = especular;
	NORMAL = normal_acumulada;
	
	// Mapa de Normales secundario
	if (usar_mapa_normales) {
		vec3 normal_tex = texture(mapa_normales, UV).rgb;
		NORMAL_MAP = normal_tex;
		NORMAL_MAP_DEPTH = fuerza_normales;
	}
	
	// Laca protectora
	CLEARCOAT = laca_final;
	CLEARCOAT_ROUGHNESS = laca_rugosidad_final;
	
	// Oclusión Ambiental por defecto
	AO = 1.0;
}
