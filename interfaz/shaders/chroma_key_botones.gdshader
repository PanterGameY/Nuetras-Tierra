shader_type canvas_item;

// ═══════════════════════════════════════════════════════════════════════════
// chroma_key_botones.gdshader — Recorte Chroma Key + Medallón Translúcido Sutil
// Elimina el fondo verde (#00FF00), neutraliza el tinte verde del cristal
// y vuelve semitransparente el disco oscuro para que solo destaque el ícono.
// ═══════════════════════════════════════════════════════════════════════════

uniform vec4 color_clave : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float umbral : hint_range(0.05, 0.85) = 0.42;
uniform float suavizado : hint_range(0.01, 0.35) = 0.12;
uniform float opacidad_disco : hint_range(0.05, 1.0) = 0.40;
uniform float opacidad_icono : hint_range(0.5, 1.0) = 0.96;
uniform float brillo : hint_range(0.5, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// 1. Detectar fondo verde (#00FF00)
	float max_rb = max(tex.r, tex.b);
	float green_excess = tex.g - max_rb;
	float dist_key = distance(tex.rgb, color_clave.rgb);
	
	float mask_dist = smoothstep(umbral, umbral + suavizado, dist_key);
	float mask_excess = 1.0 - smoothstep(0.14, 0.34, green_excess);
	float mask_chroma = min(mask_dist, mask_excess);
	
	// 2. Neutralizar por completo cualquier reflejo verdoso sobre el grafito/plata
	vec3 neutral_rgb = tex.rgb;
	neutral_rgb.g = min(neutral_rgb.g, max_rb);
	
	// 3. Separar la luminancia del ícono plateado frente al disco oscuro de fondo
	float luma = dot(neutral_rgb, vec3(0.299, 0.587, 0.114));
	float icon_weight = smoothstep(0.22, 0.46, luma);
	
	// El disco oscuro queda muy sutil (40% alfa) y el ícono interior nítido (96% alfa)
	float alpha_sutil = mix(opacidad_disco, opacidad_icono, icon_weight);
	
	COLOR = vec4(neutral_rgb * brillo, tex.a * mask_chroma * alpha_sutil) * COLOR;
}
