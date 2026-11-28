shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, depth_test_default;

// Shader de daño por colisión sin modificación de vértices:
// - Simula abolladuras mediante perturbación analítica de normales (normal bump).
// - Genera rayones metálicos y oscurecimiento por impacto de forma 100% procedural.
// - Descarta fragmentos fuera de los radios de impacto para máximo rendimiento en móvil/PC.

uniform int impact_count = 0;
uniform vec4 impactos[8]; // xyz = posición local en el vehículo, w = intensidad (0..1)
uniform float radios[8];  // radio de cada impacto en metros
uniform mat4 veh_inv_matrix = mat4(1.0);

uniform vec3 color_raspon : source_color = vec3(0.48, 0.51, 0.55);
uniform vec3 color_abolladura : source_color = vec3(0.07, 0.07, 0.08);
uniform float intensidad_normal : hint_range(0.0, 2.0) = 0.85;

varying vec3 v_veh_pos;
varying vec3 v_world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_veh_pos = (veh_inv_matrix * vec4(world_pos, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (impact_count <= 0) {
		discard;
	}

	float max_dent = 0.0;
	float scratch_acc = 0.0;
	vec3 grad_world = vec3(0.0);

	for (int i = 0; i < 8; i++) {
		if (i >= impact_count) {
			break;
		}
		vec3 delta = v_veh_pos - impactos[i].xyz;
		float rad = max(radios[i], 0.05);
		float dist = length(delta);
		if (dist < rad) {
			float norm_d = dist / rad;
			float falloff = 1.0 - smoothstep(0.0, 1.0, norm_d);
			float power = clamp(impactos[i].w, 0.0, 1.0);

			// Ruido de arrugado metálico y rayones direccionales (sin texturas extra)
			float crumple = noise3(v_veh_pos * 14.0);
			float streaks = noise3(vec3(v_veh_pos.x * 4.5, v_veh_pos.y * 18.0, v_veh_pos.z * 18.0));

			float dent = falloff * power * (0.65 + 0.35 * crumple);
			max_dent = max(max_dent, dent);

			float scratch = smoothstep(0.52, 0.85, streaks) * falloff * power;
			scratch_acc = max(scratch_acc, scratch);

			// Gradiente radial + arrugado para simular relieve de abolladura en normales
			vec3 dir_local = (dist > 0.001) ? (delta / dist) : vec3(0.0, 1.0, 0.0);
			float slope = sin(norm_d * 3.14159) * power * (0.7 + 0.6 * crumple);
			grad_world += dir_local * slope;
		}
	}

	float total_mask = max(max_dent, scratch_acc);
	if (total_mask < 0.02) {
		discard;
	}

	// Perturbación de normal en espacio de vista para efecto 3D de abolladura
	vec3 grad_view = (VIEW_MATRIX * vec4(grad_world, 0.0)).xyz;
	NORMAL = normalize(NORMAL + grad_view * intensidad_normal);

	// Mezcla entre zona hundida oscura y metal raspado brillante
	float scratch_mix = clamp(scratch_acc * 1.25, 0.0, 1.0);
	ALBEDO = mix(color_abolladura, color_raspon, scratch_mix);
	METALLIC = scratch_mix * 0.78;
	ROUGHNESS = mix(0.86, 0.30, scratch_mix);
	ALPHA = clamp(max_dent * 0.82 + scratch_acc * 0.55, 0.0, 0.90);
}
