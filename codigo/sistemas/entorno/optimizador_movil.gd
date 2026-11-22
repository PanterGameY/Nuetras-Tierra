extends Node

## Optimizador de rendimiento 3D para dispositivos móviles (Android / GLES3) y PC.
## Reduce draw calls en mapa y pase de sombras sin afectar la calidad cercana.

@export var aplicar_culling_mapa: bool = true


func _ready() -> void:
	var es_movil: bool = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
	var mem_info: Dictionary = OS.get_memory_info()
	var ram_mb: int = int(float(mem_info.get("physical", 0)) / 1048576.0)
	var es_ram_baja: bool = es_movil and ram_mb > 0 and ram_mb <= 3900
	call_deferred("_aplicar_optimizaciones", es_movil, es_ram_baja)


func _aplicar_optimizaciones(es_movil: bool, es_ram_baja: bool = false) -> void:
	if not is_inside_tree():
		return
	var raiz := get_parent()
	if not raiz:
		return

	if aplicar_culling_mapa:
		var mapa := raiz.get_node_or_null("mapa")
		if mapa:
			_optimizar_mallas_mapa(mapa, es_movil, es_ram_baja)

	if es_movil:
		_optimizar_entorno_movil(raiz, es_ram_baja)


func _es_malla_suelo_o_via(nom: String, nom_padre: String) -> bool:
	for kw in ["carretera", "asfalto", "calle", "rotonda", "trocha", "terreno", "grid", "suelo", "piso", "acera", "via", "puente"]:
		if nom.contains(kw) or nom_padre.contains(kw):
			return true
	return false


func _optimizar_mallas_mapa(nodo_raiz: Node, es_movil: bool, es_ram_baja: bool = false) -> void:
	var dist_peq: float = 85.0 if es_ram_baja else (115.0 if es_movil else 150.0)
	var dist_med: float = 135.0 if es_ram_baja else (185.0 if es_movil else 240.0)
	var dist_edif: float = 250.0 if es_ram_baja else (360.0 if es_movil else 450.0)
	var pila: Array[Node] = [nodo_raiz]
	while not pila.is_empty():
		var actual: Node = pila.pop_back()
		if actual is MeshInstance3D:
			var m := actual as MeshInstance3D
			var nom := m.name.to_lower()
			var nom_p := m.get_parent().name.to_lower() if m.get_parent() else ""
			if _es_malla_suelo_o_via(nom, nom_p):
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif m.mesh:
				var scl := m.global_transform.basis.get_scale()
				var max_scl := maxf(scl.x, maxf(scl.y, scl.z))
				var tam: float = m.mesh.get_aabb().size.length() * maxf(max_scl, 1.0)
				if tam < 6.0:
					m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					m.visibility_range_end = dist_peq
					m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				elif tam < 18.0:
					if es_movil and (es_ram_baja or tam < 10.5):
						m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					m.visibility_range_end = dist_med
					m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				elif tam < 65.0:
					m.visibility_range_end = dist_edif
					m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		for hijo in actual.get_children():
			pila.append(hijo)


func _optimizar_entorno_movil(raiz: Node, es_ram_baja: bool = false) -> void:
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	var sun := raiz.get_node_or_null("ControladorSolLuna/SunLight") as DirectionalLight3D
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_blend_splits = false
		sun.directional_shadow_max_distance = 52.0 if es_ram_baja else 75.0
		sun.shadow_blur = 0.25

	var moon := raiz.get_node_or_null("ControladorSolLuna/MoonLight") as DirectionalLight3D
	if moon:
		moon.shadow_enabled = false

	var we := raiz.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env := we.environment
		env.glow_enabled = false
		env.ssao_enabled = false
		env.adjustment_enabled = false
		if es_ram_baja:
			env.fog_enabled = false
		if env.sky:
			env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
