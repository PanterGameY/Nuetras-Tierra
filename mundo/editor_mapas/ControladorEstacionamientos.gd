class_name ControladorEstacionamientos
extends Node3D

signal estacionamiento_actualizado(cantidad: int)
signal estacionamiento_seleccionado_cambiado(hay_seleccion: bool, datos: Dictionary)

enum TipoEstacionamiento {
	AUTOS_90,
	TRACTOMULAS,
	MIXTO_BUSES
}

var controlador_terreno: Node3D = null
var controlador_carreteras: Node3D = null
var _contenedor: Node3D = null
var _estacionamientos: Array[Dictionary] = []

var indice_seleccionado: int = -1
var esquina_seleccionada: int = -1
var _manejadores_visibles: bool = false

var _mat_asfalto: StandardMaterial3D = null
var _mat_bordillo: StandardMaterial3D = null
var _mat_lineas_blanco: StandardMaterial3D = null
var _mat_lineas_amarillo: StandardMaterial3D = null
var _mat_tope: StandardMaterial3D = null
var _mat_esquina_idle: StandardMaterial3D = null
var _mat_esquina_sel: StandardMaterial3D = null
var _mat_entrada_idle: StandardMaterial3D = null
var _mat_entrada_sel: StandardMaterial3D = null
var rotacion_cursor_grados: float = 0.0
var adaptar_terreno_activo: bool = true
var _mat_banqueta: StandardMaterial3D = null
var _mat_jardinera: StandardMaterial3D = null
var _mat_discapacidad: StandardMaterial3D = null
var _mat_frente_guia: StandardMaterial3D = null
var _cursor_parqueo: Node3D = null
var _cursor_tipo_actual: int = -1
var _mat_metal_oscuro: StandardMaterial3D = null
var _mat_barrera_roja: StandardMaterial3D = null
var _mat_acceso_verde: StandardMaterial3D = null
var _escena_roble: PackedScene = null
var _escena_talanquera: PackedScene = null

func _ready() -> void:
	_asegurar_inicializado()

func _asegurar_inicializado() -> void:
	if _contenedor == null:
		_contenedor = Node3D.new()
		_contenedor.name = "ContenedorEstacionamientos"
		add_child(_contenedor)
	if _mat_asfalto == null:
		_inicializar_materiales()

func actualizar_cursor_parqueo(pos_mundo: Vector3, visible_flag: bool, tipo: int = 0) -> void:
	_asegurar_inicializado()
	if not visible_flag:
		if is_instance_valid(_cursor_parqueo):
			_cursor_parqueo.visible = false
		return
	if not is_instance_valid(_cursor_parqueo) or _cursor_tipo_actual != tipo:
		if is_instance_valid(_cursor_parqueo):
			remove_child(_cursor_parqueo)
			_cursor_parqueo.queue_free()
		_cursor_tipo_actual = tipo
		_cursor_parqueo = _construir_cursor_parqueo(tipo)
		add_child(_cursor_parqueo)
	_cursor_parqueo.visible = true
	_cursor_parqueo.position = Vector3(pos_mundo.x, pos_mundo.y + 0.18, pos_mundo.z)
	_cursor_parqueo.rotation.y = -deg_to_rad(rotacion_cursor_grados)

func rotar_cursor(delta_grados: float) -> float:
	rotacion_cursor_grados = wrapf(rotacion_cursor_grados + delta_grados, 0.0, 360.0)
	if is_instance_valid(_cursor_parqueo):
		_cursor_parqueo.rotation.y = -deg_to_rad(rotacion_cursor_grados)
	return rotacion_cursor_grados

func _construir_cursor_parqueo(tipo: int) -> Node3D:
	var n := Node3D.new()
	n.name = "CursorParqueo"
	var hw := 14.0 if tipo != TipoEstacionamiento.TRACTOMULAS else 22.0
	var hd := 10.0 if tipo != TipoEstacionamiento.TRACTOMULAS else 18.0
	var mat_c := StandardMaterial3D.new()
	mat_c.albedo_color = Color(0.95, 0.72, 0.18, 0.92)
	mat_c.emission_enabled = true
	mat_c.emission = Color(0.95, 0.72, 0.18)
	mat_c.emission_energy_multiplier = 2.0
	mat_c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_c.no_depth_test = true
	mat_c.render_priority = 20

	var mat_fill := StandardMaterial3D.new()
	mat_fill.albedo_color = Color(0.95, 0.72, 0.18, 0.22)
	mat_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_fill.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_fill.no_depth_test = true
	mat_fill.render_priority = 19

	var st_b := SurfaceTool.new()
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3(-hw, 0.0, -hd)
	var p1 := Vector3(hw, 0.0, -hd)
	var p2 := Vector3(hw, 0.0, hd)
	var p3 := Vector3(-hw, 0.0, hd)
	_agregar_segmento_caja(st_b, p0, p1, 0.35, 0.12)
	_agregar_segmento_caja(st_b, p1, p2, 0.35, 0.12)
	_agregar_segmento_caja(st_b, p2, p3, 0.35, 0.12)
	_agregar_segmento_caja(st_b, p3, p0, 0.35, 0.12)
	# Flecha frontal indicando el acceso (P0->P1)
	_agregar_flecha_uv(st_b, [p0, p1, p2, p3], 0.50, -0.08, 0.0, 1.0, 3.6, 2.4, 0.15)
	st_b.generate_normals()
	var mi_b := MeshInstance3D.new()
	mi_b.mesh = st_b.commit()
	mi_b.material_override = mat_c
	n.add_child(mi_b)

	# Relleno semitransparente + punto central
	var st_f := SurfaceTool.new()
	st_f.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_f.add_vertex(p0); st_f.add_vertex(p1); st_f.add_vertex(p2)
	st_f.add_vertex(p0); st_f.add_vertex(p2); st_f.add_vertex(p3)
	st_f.generate_normals()
	var mi_f := MeshInstance3D.new()
	mi_f.mesh = st_f.commit()
	mi_f.material_override = mat_fill
	n.add_child(mi_f)

	var esf_c := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.85; sm.height = 1.7
	esf_c.mesh = sm
	esf_c.position = Vector3(0.0, 1.8, 0.0)
	esf_c.material_override = mat_c
	n.add_child(esf_c)

	var pin_c := MeshInstance3D.new()
	var cyl_c := CylinderMesh.new()
	cyl_c.top_radius = 0.12; cyl_c.bottom_radius = 0.12; cyl_c.height = 1.8
	pin_c.mesh = cyl_c
	pin_c.position = Vector3(0.0, 0.9, 0.0)
	pin_c.material_override = mat_c
	n.add_child(pin_c)

	for corner in [p0, p1, p2, p3]:
		var esf_q := MeshInstance3D.new()
		var sm_q := SphereMesh.new()
		sm_q.radius = 0.55; sm_q.height = 1.1
		esf_q.mesh = sm_q
		esf_q.position = corner + Vector3(0.0, 0.55, 0.0)
		esf_q.material_override = mat_c
		n.add_child(esf_q)
	return n

func _inicializar_materiales() -> void:
	_mat_asfalto = StandardMaterial3D.new()
	_mat_asfalto.albedo_color = Color(0.18, 0.19, 0.21)
	_mat_asfalto.roughness = 0.78
	_mat_asfalto.uv1_triplanar = true
	_mat_asfalto.uv1_world_triplanar = true
	_mat_asfalto.uv1_scale = Vector3(0.22, 0.22, 0.22)
	if ResourceLoader.exists("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris.png"):
		_mat_asfalto.albedo_texture = load("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris.png")
	if ResourceLoader.exists("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris_normal.png"):
		_mat_asfalto.normal_enabled = true
		_mat_asfalto.normal_texture = load("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris_normal.png")
		_mat_asfalto.normal_scale = 0.6

	_mat_bordillo = StandardMaterial3D.new()
	_mat_bordillo.albedo_color = Color(0.62, 0.64, 0.67)
	_mat_bordillo.roughness = 0.85

	_mat_lineas_blanco = StandardMaterial3D.new()
	_mat_lineas_blanco.albedo_color = Color(0.95, 0.95, 0.93)
	_mat_lineas_blanco.roughness = 0.5

	_mat_lineas_amarillo = StandardMaterial3D.new()
	_mat_lineas_amarillo.albedo_color = Color(0.95, 0.74, 0.14)
	_mat_lineas_amarillo.roughness = 0.5

	_mat_tope = StandardMaterial3D.new()
	_mat_tope.albedo_color = Color(0.88, 0.68, 0.18)
	_mat_tope.roughness = 0.7

	_mat_esquina_idle = StandardMaterial3D.new()
	_mat_esquina_idle.albedo_color = Color(0.88, 0.68, 0.28, 0.92)
	_mat_esquina_idle.emission_enabled = true
	_mat_esquina_idle.emission = Color(0.88, 0.68, 0.28)
	_mat_esquina_idle.emission_energy_multiplier = 1.4
	_mat_esquina_idle.no_depth_test = true
	_mat_esquina_idle.render_priority = 21

	_mat_esquina_sel = StandardMaterial3D.new()
	_mat_esquina_sel.albedo_color = Color(0.2, 0.85, 1.0, 0.98)
	_mat_esquina_sel.emission_enabled = true
	_mat_esquina_sel.emission = Color(0.2, 0.85, 1.0)
	_mat_esquina_sel.emission_energy_multiplier = 2.0
	_mat_esquina_sel.no_depth_test = true
	_mat_esquina_sel.render_priority = 21

	_mat_entrada_idle = StandardMaterial3D.new()
	_mat_entrada_idle.albedo_color = Color(0.18, 0.92, 0.52, 0.96)
	_mat_entrada_idle.emission_enabled = true
	_mat_entrada_idle.emission = Color(0.18, 0.92, 0.52)
	_mat_entrada_idle.emission_energy_multiplier = 1.6
	_mat_entrada_idle.no_depth_test = true
	_mat_entrada_idle.render_priority = 22

	_mat_entrada_sel = StandardMaterial3D.new()
	_mat_entrada_sel.albedo_color = Color(0.45, 1.0, 0.92, 1.0)
	_mat_entrada_sel.emission_enabled = true
	_mat_entrada_sel.emission = Color(0.45, 1.0, 0.92)
	_mat_entrada_sel.emission_energy_multiplier = 2.2
	_mat_entrada_sel.no_depth_test = true
	_mat_entrada_sel.render_priority = 22

	_mat_banqueta = StandardMaterial3D.new()
	_mat_banqueta.albedo_color = Color(0.56, 0.58, 0.60)
	_mat_banqueta.roughness = 0.88

	_mat_jardinera = StandardMaterial3D.new()
	_mat_jardinera.albedo_color = Color(0.88, 0.94, 0.86)
	_mat_jardinera.roughness = 0.95
	_mat_jardinera.uv1_triplanar = true
	_mat_jardinera.uv1_world_triplanar = true
	_mat_jardinera.uv1_scale = Vector3(0.35, 0.35, 0.35)
	if ResourceLoader.exists("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde.png"):
		_mat_jardinera.albedo_texture = load("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde.png")
	if ResourceLoader.exists("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde_normal.png"):
		_mat_jardinera.normal_enabled = true
		_mat_jardinera.normal_texture = load("res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde_normal.png")
		_mat_jardinera.normal_scale = 0.55

	_mat_discapacidad = StandardMaterial3D.new()
	_mat_discapacidad.albedo_color = Color(0.10, 0.42, 0.85)
	_mat_discapacidad.roughness = 0.55

	_mat_frente_guia = StandardMaterial3D.new()
	_mat_frente_guia.albedo_color = Color(0.95, 0.72, 0.18, 0.95)
	_mat_frente_guia.emission_enabled = true
	_mat_frente_guia.emission = Color(0.95, 0.72, 0.18)
	_mat_frente_guia.emission_energy_multiplier = 1.6

	_mat_metal_oscuro = StandardMaterial3D.new()
	_mat_metal_oscuro.albedo_color = Color(0.20, 0.22, 0.25)
	_mat_metal_oscuro.metallic = 0.65
	_mat_metal_oscuro.roughness = 0.42

	_mat_barrera_roja = StandardMaterial3D.new()
	_mat_barrera_roja.albedo_color = Color(0.84, 0.18, 0.18)
	_mat_barrera_roja.roughness = 0.45

	_mat_acceso_verde = StandardMaterial3D.new()
	_mat_acceso_verde.albedo_color = Color(0.18, 0.78, 0.36)
	_mat_acceso_verde.emission_enabled = true
	_mat_acceso_verde.emission = Color(0.18, 0.78, 0.36)
	_mat_acceso_verde.emission_energy_multiplier = 1.2

	if ResourceLoader.exists("res://modelos3d/mapa/arboles/arbol_roble_3d.tscn"):
		_escena_roble = load("res://modelos3d/mapa/arboles/arbol_roble_3d.tscn")
	if ResourceLoader.exists("res://modelos3d/mapa/accesorios/talanquera_parqueo.glb"):
		_escena_talanquera = load("res://modelos3d/mapa/accesorios/talanquera_parqueo.glb")

func _altura_terreno(p: Vector3) -> float:
	if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
		return float(controlador_terreno.obtener_altura(p))
	return p.y

func crear_estacionamiento(pos_mundo: Vector3, tipo: int = 0) -> int:
	_asegurar_inicializado()
	var half_w := 14.0 if tipo != TipoEstacionamiento.TRACTOMULAS else 22.0
	var half_d := 10.0 if tipo != TipoEstacionamiento.TRACTOMULAS else 18.0
	var rot_rad := deg_to_rad(rotacion_cursor_grados)
	var o0 := Vector2(-half_w, -half_d).rotated(rot_rad)
	var o1 := Vector2(half_w, -half_d).rotated(rot_rad)
	var o2 := Vector2(half_w, half_d).rotated(rot_rad)
	var o3 := Vector2(-half_w, half_d).rotated(rot_rad)
	var p0 := pos_mundo + Vector3(o0.x, 0.0, o0.y)
	var p1 := pos_mundo + Vector3(o1.x, 0.0, o1.y)
	var p2 := pos_mundo + Vector3(o2.x, 0.0, o2.y)
	var p3 := pos_mundo + Vector3(o3.x, 0.0, o3.y)
	p0.y = _altura_terreno(p0)
	p1.y = _altura_terreno(p1)
	p2.y = _altura_terreno(p2)
	p3.y = _altura_terreno(p3)

	var nodo := Node3D.new()
	nodo.name = "Estacionamiento_%d" % (_estacionamientos.size() + 1)
	_contenedor.add_child(nodo)

	var pts: Array[Vector3] = [p0, p1, p2, p3]
	_estacionamientos.append({
		"puntos": pts,
		"tipo": tipo,
		"color_lineas": 0,
		"iluminacion": true,
		"arbolado": true,
		"u_entrada": 0.50,
		"adaptar_terreno": adaptar_terreno_activo,
		"finalizado": false,
		"conexion_via": {},
		"nodo": nodo,
		"manejadores": [],
		"guias_editor": []
	})
	var idx := _estacionamientos.size() - 1
	indice_seleccionado = idx
	esquina_seleccionada = -1
	_reconstruir_estacionamiento(idx)
	if adaptar_terreno_activo:
		_adaptar_terreno_al_estacionamiento(idx, false)
	estacionamiento_actualizado.emit(_estacionamientos.size())
	_emitir_seleccion()
	return idx

func establecer_visibilidad_manejadores(visible_flag: bool) -> void:
	_manejadores_visibles = visible_flag
	for est in _estacionamientos:
		var mostrar := visible_flag and not bool(est.get("finalizado", false))
		for m in est.get("manejadores", []):
			if is_instance_valid(m):
				m.visible = mostrar
		for g in est.get("guias_editor", []):
			if is_instance_valid(g):
				g.visible = mostrar

func buscar_esquina_por_rayo(origen: Vector3, dir: Vector3) -> Dictionary:
	var mejor := {"encontrado": false, "idx_est": -1, "idx_esq": -1, "dist": 9999.0}
	if not _manejadores_visibles:
		return mejor
	var d_norm := dir.normalized()
	for i in range(_estacionamientos.size()):
		if bool(_estacionamientos[i].get("finalizado", false)):
			continue
		var pts: Array = _estacionamientos[i]["puntos"]
		for j in range(pts.size()):
			var p: Vector3 = pts[j] + Vector3(0, 0.7, 0)
			var to_p := p - origen
			var t := to_p.dot(d_norm)
			if t <= 0.0:
				continue
			var proj := origen + d_norm * t
			var dist_ray := proj.distance_to(p)
			if dist_ray <= 1.8 and t < mejor["dist"]:
				mejor = {"encontrado": true, "idx_est": i, "idx_esq": j, "dist": t}
		var u_ent_c := float(_estacionamientos[i].get("u_entrada", 0.50))
		var p_ent := _bilerp(pts, u_ent_c, 0.0) + Vector3(0, 1.0, 0)
		var to_e := p_ent - origen
		var te := to_e.dot(d_norm)
		if te > 0.0:
			var proj_e := origen + d_norm * te
			if proj_e.distance_to(p_ent) <= 2.0 and te < mejor["dist"]:
				mejor = {"encontrado": true, "idx_est": i, "idx_esq": 4, "dist": te}
	return mejor

func seleccionar_esquina(idx_est: int, idx_esq: int) -> void:
	indice_seleccionado = idx_est
	esquina_seleccionada = idx_esq
	_actualizar_colores_manejadores()
	_emitir_seleccion()

func buscar_estacionamiento_por_posicion(pos_mundo: Vector3) -> int:
	for i in range(_estacionamientos.size() - 1, -1, -1):
		if _punto_en_quad_xz(Vector2(pos_mundo.x, pos_mundo.z), _estacionamientos[i]["puntos"]):
			return i
	return -1

func seleccionar_estacionamiento(idx_est: int) -> void:
	if idx_est < 0 or idx_est >= _estacionamientos.size():
		indice_seleccionado = -1
	else:
		indice_seleccionado = idx_est
	esquina_seleccionada = -1
	_actualizar_colores_manejadores()
	_emitir_seleccion()

func finalizar_edicion_actual() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return false
	_estacionamientos[indice_seleccionado]["finalizado"] = true
	esquina_seleccionada = -1
	if bool(_estacionamientos[indice_seleccionado].get("adaptar_terreno", true)):
		_adaptar_terreno_al_estacionamiento(indice_seleccionado, false)
	establecer_visibilidad_manejadores(_manejadores_visibles)
	_emitir_seleccion()
	return true

func activar_edicion_esquinas_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return false
	_estacionamientos[indice_seleccionado]["finalizado"] = false
	establecer_visibilidad_manejadores(true)
	_emitir_seleccion()
	return true

func esta_editando_puntos() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return false
	return not bool(_estacionamientos[indice_seleccionado].get("finalizado", false))

func obtener_centro_seleccionado() -> Vector3:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return Vector3.ZERO
	var pts: Array = _estacionamientos[indice_seleccionado]["puntos"]
	if pts.is_empty():
		return Vector3.ZERO
	var suma := Vector3.ZERO
	for p in pts:
		suma += p as Vector3
	return suma / float(pts.size())

func unir_salida_con_carretera_mas_cercana() -> Dictionary:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return {"ok": false, "mensaje": "Selecciona primero un estacionamiento"}
	if not controlador_carreteras or not controlador_carreteras.road_container or not is_instance_valid(controlador_carreteras.road_container):
		return {"ok": false, "mensaje": "No hay sistema de carreteras disponible"}
	var est: Dictionary = _estacionamientos[indice_seleccionado]
	var pts: Array = est["puntos"]
	var p_ent := _bilerp(pts, float(est.get("u_entrada", 0.50)), 0.0)
	var mejor_pt := Vector3.ZERO
	var mejor_dist := 260.0
	var mejor_ancho := 8.8
	var encontro := false
	for obj in controlador_carreteras.road_container.get_segments():
		var seg := obj as Node3D
		if not is_instance_valid(seg):
			continue
		var curva: Curve3D = seg.get("curve") as Curve3D
		if not curva:
			continue
		var local_p: Vector3 = seg.to_local(p_ent) if seg.is_inside_tree() else (p_ent - seg.position)
		var closest_local: Vector3 = curva.get_closest_point(local_p)
		var closest_world: Vector3 = seg.to_global(closest_local) if seg.is_inside_tree() else (seg.position + closest_local)
		var d := p_ent.distance_to(closest_world)
		if d < mejor_dist:
			mejor_dist = d
			mejor_pt = closest_world
			if controlador_carreteras.has_method("_obtener_ancho_via_punto") and seg.get("start_point") != null:
				mejor_ancho = float(controlador_carreteras._obtener_ancho_via_punto(seg.get("start_point")))
			encontro = true
	if not encontro:
		return {"ok": false, "mensaje": "No se encontró ninguna carretera cercana (máx. 260m)"}
	est["conexion_via"] = {"punto_via": [mejor_pt.x, mejor_pt.y, mejor_pt.z], "ancho_via": mejor_ancho}
	_reconstruir_estacionamiento(indice_seleccionado)
	_emitir_seleccion()
	return {"ok": true, "mensaje": "✓ Salida unida con la carretera más cercana (%.1fm)" % mejor_dist, "distancia": mejor_dist}

func mover_esquina(idx_est: int, idx_esq: int, nueva_pos: Vector3) -> void:
	if idx_est < 0 or idx_est >= _estacionamientos.size():
		return
	var est: Dictionary = _estacionamientos[idx_est]
	var pts: Array = est["puntos"]
	if idx_esq == 4:
		var p0_xz := Vector2(pts[0].x, pts[0].z)
		var p1_xz := Vector2(pts[1].x, pts[1].z)
		var seg := p1_xz - p0_xz
		var len_sq := seg.length_squared()
		if len_sq > 0.01:
			var np_xz := Vector2(nueva_pos.x, nueva_pos.z)
			var u_raw := (np_xz - p0_xz).dot(seg) / len_sq
			var ancho_prom := 0.5 * (float(pts[0].distance_to(pts[1])) + float(pts[3].distance_to(pts[2])))
			var u_ent_half := clampf(4.6 / maxf(ancho_prom, 1.0), 0.04, 0.40)
			var u_marg := clampf((1.8 if bool(est.get("arbolado", true)) else 0.7) / maxf(ancho_prom, 1.0), 0.02, 0.14)
			var u_min := minf(0.49, u_marg + u_ent_half)
			var u_max := maxf(0.51, 1.0 - u_marg - u_ent_half)
			est["u_entrada"] = clampf(u_raw, u_min, u_max)
			_reconstruir_estacionamiento(idx_est)
		return
	if idx_esq < 0 or idx_esq >= pts.size():
		return
	var pos_adj := nueva_pos
	pos_adj.y = _altura_terreno(nueva_pos)
	pts[idx_esq] = pos_adj
	_reconstruir_estacionamiento(idx_est)

func _obtener_rotacion_grados_est(est: Dictionary) -> float:
	var pts: Array = est["puntos"]
	var dv := Vector2(pts[1].x - pts[0].x, pts[1].z - pts[0].z)
	if dv.length_squared() < 0.0001:
		return 0.0
	return wrapf(rad_to_deg(atan2(dv.y, dv.x)), 0.0, 360.0)

func establecer_rotacion_seleccionado(angulo_grados: float) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return
	var ang_act := _obtener_rotacion_grados_est(_estacionamientos[indice_seleccionado])
	var target_ang := wrapf(angulo_grados, 0.0, 360.0)
	var delta_deg := wrapf(target_ang - ang_act + 180.0, 0.0, 360.0) - 180.0
	if absf(delta_deg) < 0.05:
		return
	_rotar_puntos_estacionamiento(indice_seleccionado, deg_to_rad(delta_deg))

func rotar_seleccionado(delta_grados: float) -> float:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return 0.0
	_rotar_puntos_estacionamiento(indice_seleccionado, deg_to_rad(delta_grados))
	return _obtener_rotacion_grados_est(_estacionamientos[indice_seleccionado])

func _rotar_puntos_estacionamiento(idx: int, delta_rad: float) -> void:
	var pts: Array = _estacionamientos[idx]["puntos"]
	var cx: float = 0.25 * (float(pts[0].x) + float(pts[1].x) + float(pts[2].x) + float(pts[3].x))
	var cz: float = 0.25 * (float(pts[0].z) + float(pts[1].z) + float(pts[2].z) + float(pts[3].z))
	for j in range(4):
		var pj: Vector3 = pts[j]
		var rel := Vector2(pj.x - cx, pj.z - cz).rotated(delta_rad)
		var p_rot := Vector3(cx + rel.x, pj.y, cz + rel.y)
		p_rot.y = _altura_terreno(p_rot)
		pts[j] = p_rot
	_reconstruir_estacionamiento(idx)
	if bool(_estacionamientos[idx].get("adaptar_terreno", true)):
		_adaptar_terreno_al_estacionamiento(idx, false)

func establecer_tipo_seleccionado(nuevo_tipo: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return
	_estacionamientos[indice_seleccionado]["tipo"] = clampi(nuevo_tipo, 0, 2)
	_reconstruir_estacionamiento(indice_seleccionado)
	_emitir_seleccion()

func establecer_color_lineas_seleccionado(nuevo_color: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return
	_estacionamientos[indice_seleccionado]["color_lineas"] = clampi(nuevo_color, 0, 1)
	_reconstruir_estacionamiento(indice_seleccionado)
	_emitir_seleccion()

func establecer_iluminacion_seleccionado(activa: bool) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return
	_estacionamientos[indice_seleccionado]["iluminacion"] = activa
	_reconstruir_estacionamiento(indice_seleccionado)
	_emitir_seleccion()

func establecer_arbolado_seleccionado(activa: bool) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return
	_estacionamientos[indice_seleccionado]["arbolado"] = activa
	_reconstruir_estacionamiento(indice_seleccionado)
	_emitir_seleccion()

func establecer_adaptar_terreno(activo: bool) -> void:
	adaptar_terreno_activo = activo
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return
	_estacionamientos[indice_seleccionado]["adaptar_terreno"] = activo
	if activo:
		_adaptar_terreno_al_estacionamiento(indice_seleccionado, false)
	else:
		var pts: Array = _estacionamientos[indice_seleccionado]["puntos"]
		for j in range(pts.size()):
			var pj: Vector3 = pts[j]
			pj.y = _altura_terreno(pj)
			pts[j] = pj
		_reconstruir_estacionamiento(indice_seleccionado)
	_emitir_seleccion()

func adaptar_terreno_estacionamiento(idx: int) -> bool:
	if idx < 0 or idx >= _estacionamientos.size():
		return false
	if not bool(_estacionamientos[idx].get("adaptar_terreno", true)):
		return false
	return _adaptar_terreno_al_estacionamiento(idx, false)

func nivelar_terreno_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return false
	return _adaptar_terreno_al_estacionamiento(indice_seleccionado, true)

func _adaptar_terreno_al_estacionamiento(idx: int, nivelar_plano: bool = false) -> bool:
	if idx < 0 or idx >= _estacionamientos.size():
		return false
	if not controlador_terreno or not controlador_terreno.terrain or not controlador_terreno.terrain.data:
		return false
	var terrain = controlador_terreno.terrain
	var t_data = terrain.data
	var pts: Array = _estacionamientos[idx]["puntos"]
	if pts.size() < 4:
		return false

	var h_prom := 0.0
	if nivelar_plano:
		for p in pts:
			h_prom += p.y
		h_prom /= float(pts.size())
		for j in range(pts.size()):
			pts[j].y = h_prom

	var vertex_spacing: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var edge_margin := 1.6
	var edge_falloff := 5.5
	var pad := edge_margin + edge_falloff + vertex_spacing * 2.0

	var min_x := minf(minf(pts[0].x, pts[1].x), minf(pts[2].x, pts[3].x)) - pad
	var max_x := maxf(maxf(pts[0].x, pts[1].x), maxf(pts[2].x, pts[3].x)) + pad
	var min_z := minf(minf(pts[0].z, pts[1].z), minf(pts[2].z, pts[3].z)) - pad
	var max_z := maxf(maxf(pts[0].z, pts[1].z), maxf(pts[2].z, pts[3].z)) + pad

	var min_xz := Vector3(min_x, 0.0, min_z).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing))
	var max_xz := Vector3(max_x, 0.0, max_z).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing)) + Vector3(vertex_spacing, 0.0, vertex_spacing)

	var modificado := false
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var world_pos := Vector3(x, 0.0, z)
			if t_data.has_regionp(world_pos):
				var curr_h: float = t_data.get_height(world_pos)
				if not is_nan(curr_h):
					var hd := _altura_quad_y_distancia_xz(Vector2(x, z), pts)
					var h_quad := h_prom if nivelar_plano else hd.x
					var dist := hd.y
					var h_target := h_quad - 0.06
					if dist <= edge_margin:
						if absf(curr_h - h_target) > 0.015:
							t_data.set_height(world_pos, h_target)
							modificado = true
					elif dist <= edge_margin + edge_falloff:
						var t := (dist - edge_margin) / edge_falloff
						var factor := t * t * (3.0 - 2.0 * t)
						var desired := lerpf(h_target, curr_h, factor)
						if absf(curr_h - desired) > 0.015:
							t_data.set_height(world_pos, desired)
							modificado = true
			z += vertex_spacing
		x += vertex_spacing

	if modificado:
		t_data.update_maps(0)
		t_data.calc_height_range()
		if controlador_terreno.has_signal("terreno_modificado"):
			controlador_terreno.terreno_modificado.emit()
	if nivelar_plano:
		_reconstruir_estacionamiento(idx)
	return true

func _barycentric_2d(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var denom := v0.x * v1.y - v1.x * v0.y
	if absf(denom) < 0.00001:
		return Vector3(-1.0, -1.0, -1.0)
	var inv := 1.0 / denom
	var u := (v2.x * v1.y - v1.x * v2.y) * inv
	var v := (v0.x * v2.y - v2.x * v0.y) * inv
	var w := 1.0 - u - v
	return Vector3(w, u, v)

func _altura_quad_y_distancia_xz(p_xz: Vector2, pts: Array) -> Vector2:
	var p0: Vector3 = pts[0]
	var p1: Vector3 = pts[1]
	var p2: Vector3 = pts[2]
	var p3: Vector3 = pts[3]
	var pc: Vector3 = (p0 + p1 + p2 + p3) * 0.25
	var pc_xz := Vector2(pc.x, pc.z)
	var verts := [p0, p1, p2, p3]
	var dentro := _punto_en_quad_xz(p_xz, pts)

	if dentro:
		for i in range(4):
			var va: Vector3 = verts[i]
			var vb: Vector3 = verts[(i + 1) % 4]
			var bc := _barycentric_2d(p_xz, pc_xz, Vector2(va.x, va.z), Vector2(vb.x, vb.z))
			if bc.x >= -0.002 and bc.y >= -0.002 and bc.z >= -0.002:
				return Vector2(bc.x * pc.y + bc.y * va.y + bc.z * vb.y, 0.0)

	var mejor_dist := 999999.0
	var mejor_h := pc.y
	for i in range(4):
		var va: Vector3 = verts[i]
		var vb: Vector3 = verts[(i + 1) % 4]
		var a_xz := Vector2(va.x, va.z)
		var b_xz := Vector2(vb.x, vb.z)
		var q_xz := Geometry2D.get_closest_point_to_segment(p_xz, a_xz, b_xz)
		var d := p_xz.distance_to(q_xz)
		if d < mejor_dist:
			mejor_dist = d
			var seg_len := a_xz.distance_to(b_xz)
			var t := clampf(a_xz.distance_to(q_xz) / maxf(seg_len, 0.0001), 0.0, 1.0)
			mejor_h = lerpf(va.y, vb.y, t)

	return Vector2(mejor_h, 0.0 if dentro else mejor_dist)

func borrar_estacionamiento_en_posicion(pos_mundo: Vector3) -> bool:
	for i in range(_estacionamientos.size() - 1, -1, -1):
		if _punto_en_quad_xz(Vector2(pos_mundo.x, pos_mundo.z), _estacionamientos[i]["puntos"]):
			var nodo: Node3D = _estacionamientos[i]["nodo"]
			if is_instance_valid(nodo):
				_contenedor.remove_child(nodo)
				nodo.queue_free()
			_estacionamientos.remove_at(i)
			if indice_seleccionado == i:
				indice_seleccionado = -1
				esquina_seleccionada = -1
			elif indice_seleccionado > i:
				indice_seleccionado -= 1
			estacionamiento_actualizado.emit(_estacionamientos.size())
			_emitir_seleccion()
			return true
	return false

func eliminar_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _estacionamientos.size():
		return false
	var nodo: Node3D = _estacionamientos[indice_seleccionado]["nodo"]
	if is_instance_valid(nodo):
		_contenedor.remove_child(nodo)
		nodo.queue_free()
	_estacionamientos.remove_at(indice_seleccionado)
	indice_seleccionado = -1
	esquina_seleccionada = -1
	estacionamiento_actualizado.emit(_estacionamientos.size())
	_emitir_seleccion()
	return true

func limpiar_todos() -> void:
	for est in _estacionamientos:
		var nodo: Node3D = est.get("nodo")
		if is_instance_valid(nodo):
			_contenedor.remove_child(nodo)
			nodo.queue_free()
	_estacionamientos.clear()
	indice_seleccionado = -1
	esquina_seleccionada = -1
	estacionamiento_actualizado.emit(0)
	_emitir_seleccion()

func _punto_en_quad_xz(p: Vector2, pts: Array) -> bool:
	var v: Array[Vector2] = []
	for pt in pts:
		v.append(Vector2(pt.x, pt.z))
	var dentro := false
	var j := v.size() - 1
	for i in range(v.size()):
		if ((v[i].y > p.y) != (v[j].y > p.y)) and (p.x < (v[j].x - v[i].x) * (p.y - v[i].y) / ((v[j].y - v[i].y) + 0.00001) + v[i].x):
			dentro = not dentro
		j = i
	return dentro

func _bilerp(pts: Array, u: float, v: float) -> Vector3:
	var p0: Vector3 = pts[0]
	var p1: Vector3 = pts[1]
	var p2: Vector3 = pts[2]
	var p3: Vector3 = pts[3]
	return p0 * ((1.0 - u) * (1.0 - v)) + p1 * (u * (1.0 - v)) + p2 * (u * v) + p3 * ((1.0 - u) * v)

func _reconstruir_estacionamiento(idx: int) -> void:
	if idx < 0 or idx >= _estacionamientos.size():
		return
	var est: Dictionary = _estacionamientos[idx]
	var nodo: Node3D = est["nodo"]
	for ch in nodo.get_children():
		nodo.remove_child(ch)
		ch.queue_free()
	var manejadores: Array[MeshInstance3D] = []
	var guias_editor: Array[MeshInstance3D] = []
	est["manejadores"] = manejadores
	est["guias_editor"] = guias_editor

	var pts: Array = est["puntos"]
	var tipo: int = int(est.get("tipo", 0))
	var col_idx: int = int(est.get("color_lineas", 0))
	var ilum: bool = bool(est.get("iluminacion", true))
	var arbolado: bool = bool(est.get("arbolado", true))

	# 1. Plataforma de asfalto adaptada al cuadrilátero (subdividida 6x6 para adaptarse a pendientes)
	var st_deck := SurfaceTool.new()
	st_deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SUB := 6
	for ix in range(SUB):
		var u0 := float(ix) / float(SUB)
		var u1 := float(ix + 1) / float(SUB)
		for iz in range(SUB):
			var v0 := float(iz) / float(SUB)
			var v1 := float(iz + 1) / float(SUB)
			var a := _bilerp(pts, u0, v0) + Vector3(0, 0.08, 0)
			var b := _bilerp(pts, u1, v0) + Vector3(0, 0.08, 0)
			var c := _bilerp(pts, u1, v1) + Vector3(0, 0.08, 0)
			var d := _bilerp(pts, u0, v1) + Vector3(0, 0.08, 0)
			st_deck.add_vertex(a); st_deck.add_vertex(b); st_deck.add_vertex(c)
			st_deck.add_vertex(a); st_deck.add_vertex(c); st_deck.add_vertex(d)
	# Faldones laterales hacia abajo (-0.65m)
	for edge in [[0, 1], [1, 2], [2, 3], [3, 0]]:
		var e0: Vector3 = pts[edge[0]] + Vector3(0, 0.08, 0)
		var e1: Vector3 = pts[edge[1]] + Vector3(0, 0.08, 0)
		var b0 := e0 - Vector3(0, 0.65, 0)
		var b1 := e1 - Vector3(0, 0.65, 0)
		st_deck.add_vertex(e0); st_deck.add_vertex(b0); st_deck.add_vertex(b1)
		st_deck.add_vertex(e0); st_deck.add_vertex(b1); st_deck.add_vertex(e1)
	st_deck.generate_normals()

	var mesh_deck := st_deck.commit()
	var mi_deck := MeshInstance3D.new()
	mi_deck.mesh = mesh_deck
	mi_deck.material_override = _mat_asfalto
	nodo.add_child(mi_deck)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh_deck.create_trimesh_shape()
	sb.add_child(cs)
	nodo.add_child(sb)

	# Dimensiones promedio en metros y ancho constante de la entrada (9.2m)
	var ancho_prom: float = 0.5 * (float(pts[0].distance_to(pts[1])) + float(pts[3].distance_to(pts[2])))
	var largo_prom: float = 0.5 * (float(pts[0].distance_to(pts[3])) + float(pts[1].distance_to(pts[2])))
	var u_ent_half := clampf(4.6 / maxf(ancho_prom, 1.0), 0.04, 0.40)
	var margin_m := 1.8 if arbolado else 0.7
	var u_margin := clampf(margin_m / maxf(ancho_prom, 1.0), 0.02, 0.14)
	var u_min_c := minf(0.49, u_margin + u_ent_half)
	var u_max_c := maxf(0.51, 1.0 - u_margin - u_ent_half)
	var u_ent_centro := clampf(float(est.get("u_entrada", 0.50)), u_min_c, u_max_c)
	var u_ent_izq := u_ent_centro - u_ent_half
	var u_ent_der := u_ent_centro + u_ent_half

	# 2. Bordillos perimetrales (dejando entrada de tamaño constante en P0->P1)
	var st_bord := SurfaceTool.new()
	st_bord.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lados := [[0, 1], [1, 2], [2, 3], [3, 0]]
	for l_idx in range(lados.size()):
		var p_a: Vector3 = pts[lados[l_idx][0]] + Vector3(0, 0.16, 0)
		var p_b: Vector3 = pts[lados[l_idx][1]] + Vector3(0, 0.16, 0)
		var len_lado := p_a.distance_to(p_b)
		if l_idx == 0 and len_lado > 10.0:
			var m1 := p_a.lerp(p_b, u_ent_izq)
			var m2 := p_a.lerp(p_b, u_ent_der)
			_agregar_segmento_caja(st_bord, p_a, m1, 0.28, 0.18)
			_agregar_segmento_caja(st_bord, m2, p_b, 0.28, 0.18)
		else:
			_agregar_segmento_caja(st_bord, p_a, p_b, 0.28, 0.18)
	st_bord.generate_normals()
	var mi_bord := MeshInstance3D.new()
	mi_bord.mesh = st_bord.commit()
	mi_bord.material_override = _mat_bordillo
	nodo.add_child(mi_bord)

	# 3. Cajones de parqueo procedurales densos (filas perimetrales + islas centrales dobles + banquetas con árboles)
	var cajon_w := 3.15 if tipo == TipoEstacionamiento.AUTOS_90 else (4.6 if tipo == TipoEstacionamiento.TRACTOMULAS else 3.85)
	var cajon_d := 5.2 if tipo == TipoEstacionamiento.AUTOS_90 else (14.0 if tipo == TipoEstacionamiento.TRACTOMULAS else 9.5)
	var pasillo := 5.8 if tipo == TipoEstacionamiento.AUTOS_90 else (9.0 if tipo == TipoEstacionamiento.TRACTOMULAS else 7.2)

	var st_lin := SurfaceTool.new()
	st_lin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_top := SurfaceTool.new()
	st_top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_banq := SurfaceTool.new()
	st_banq.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_jard := SurfaceTool.new()
	st_jard.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_disc := SurfaceTool.new()
	st_disc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_metal := SurfaceTool.new()
	st_metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_barr := SurfaceTool.new()
	st_barr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_verde := SurfaceTool.new()
	st_verde.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_simb_blanco := SurfaceTool.new()
	st_simb_blanco.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posiciones_robles: Array[Dictionary] = []

	var v_margin := clampf(margin_m / maxf(largo_prom, 1.0), 0.02, 0.14)
	var v_cajon := clampf(cajon_d / maxf(largo_prom, 1.0), 0.10, 0.42)
	var v_pasillo := clampf(pasillo / maxf(largo_prom, 1.0), 0.10, 0.36)
	var v_isla := clampf((1.8 if arbolado else 0.65) / maxf(largo_prom, 1.0), 0.018, 0.09)
	var u_cross := clampf((6.0 if tipo != TipoEstacionamiento.TRACTOMULAS else 9.0) / maxf(ancho_prom, 1.0), 0.10, 0.22) if ancho_prom >= 20.0 else 0.0

	# Banquetas perimetrales (dejando abertura en P0->P1 u in [0.34, 0.66])
	if arbolado and ancho_prom > 10.0 and largo_prom > 10.0:
		var bw := 1.4
		var u_bw := clampf(bw / maxf(ancho_prom, 1.0), 0.02, 0.09)
		var v_bw := clampf(bw / maxf(largo_prom, 1.0), 0.02, 0.09)
		# Franja izquierda, derecha y trasera
		_agregar_plataforma_uv(st_banq, pts, 0.0, 0.0, u_bw, 1.0, 0.18)
		_agregar_plataforma_uv(st_banq, pts, 1.0 - u_bw, 0.0, 1.0, 1.0, 0.18)
		_agregar_plataforma_uv(st_banq, pts, u_bw, 1.0 - v_bw, 1.0 - u_bw, 1.0, 0.18)
		# Franja frontal dividida por la entrada de tamaño constante
		if u_ent_izq > u_bw + 0.02:
			_agregar_plataforma_uv(st_banq, pts, u_bw, 0.0, u_ent_izq, v_bw, 0.18)
			var pos_af_i := _bilerp(pts, 0.5 * (u_bw + u_ent_izq), v_bw * 0.5) + Vector3(0, 0.19, 0)
			_agregar_bloque_3d(st_jard, pos_af_i, Vector3(1.20, 0.08, 1.20))
			posiciones_robles.append({"pos": pos_af_i, "escala": 0.45, "rot": 0.7})
		if 1.0 - u_bw > u_ent_der + 0.02:
			_agregar_plataforma_uv(st_banq, pts, u_ent_der, 0.0, 1.0 - u_bw, v_bw, 0.18)
			var pos_af_d := _bilerp(pts, 0.5 * (u_ent_der + 1.0 - u_bw), v_bw * 0.5) + Vector3(0, 0.19, 0)
			_agregar_bloque_3d(st_jard, pos_af_d, Vector3(1.20, 0.08, 1.20))
			posiciones_robles.append({"pos": pos_af_d, "escala": 0.45, "rot": 3.5})
		# Jardineras (alcorques) y árboles Roble reales perimetrales
		var n_arb_lat := maxi(2, int(floor(largo_prom / 12.0)))
		for k in range(n_arb_lat):
			var vk := lerpf(0.14, 0.86, float(k) / float(maxi(1, n_arb_lat - 1)))
			for uk in [u_bw * 0.5, 1.0 - u_bw * 0.5]:
				var pos_a := _bilerp(pts, uk, vk) + Vector3(0, 0.19, 0)
				_agregar_bloque_3d(st_jard, pos_a, Vector3(1.25, 0.08, 1.25))
				posiciones_robles.append({"pos": pos_a, "escala": 0.48, "rot": float(k) * 1.15 + uk * 3.1})

	# Calcular filas de cajones + islas centrales + pasillos de circulación
	var filas_v: Array = [] # [v_ini, v_fin, tope_en_ini, u_start, u_end, skip_entrada]
	var pasillos_v: Array = [] # [v_center, dir_sign]
	var islas_v: Array = [] # [v_ini, v_fin]

	var v_front_ini := v_margin
	var v_front_fin := v_front_ini + v_cajon
	var v_back_fin := 1.0 - v_margin
	var v_back_ini := v_back_fin - v_cajon

	if largo_prom >= cajon_d * 2.0 + pasillo + margin_m * 2.0:
		# Fila frontal (con abertura central de acceso) y fila trasera completa
		filas_v.append([v_front_ini, v_front_fin, true, u_margin, 1.0 - u_margin, true])
		filas_v.append([v_back_ini, v_back_fin, false, u_margin, 1.0 - u_margin, false])

		var v_cursor := v_front_fin + v_pasillo
		pasillos_v.append([v_front_fin + v_pasillo * 0.5, 1.0])
		var dir_pasillo := -1.0

		var u_isl_ini := maxf(u_margin, u_cross)
		var u_isl_fin := 1.0 - u_isl_ini
		# Llenar el centro con islas dobles mientras quepan
		while v_cursor + v_cajon * 2.0 + v_isla + v_pasillo <= v_back_ini + 0.005:
			var r1_ini := v_cursor
			var r1_fin := r1_ini + v_cajon
			var m_ini := r1_fin
			var m_fin := m_ini + v_isla
			var r2_ini := m_fin
			var r2_fin := r2_ini + v_cajon
			filas_v.append([r1_ini, r1_fin, false, u_isl_ini, u_isl_fin, false])
			islas_v.append([m_ini, m_fin])
			filas_v.append([r2_ini, r2_fin, true, u_isl_ini, u_isl_fin, false])
			v_cursor = r2_fin + v_pasillo
			pasillos_v.append([r2_fin + v_pasillo * 0.5, dir_pasillo])
			dir_pasillo *= -1.0

		# Si aún sobra espacio en medio para 1 fila sencilla + pasillo
		if v_cursor + v_cajon + v_pasillo <= v_back_ini + 0.005:
			filas_v.append([v_cursor, v_cursor + v_cajon, true, u_isl_ini, u_isl_fin, false])
			pasillos_v.append([v_cursor + v_cajon + v_pasillo * 0.5, dir_pasillo])
	elif largo_prom >= cajon_d + pasillo * 0.6 + margin_m * 2.0:
		filas_v.append([v_back_ini, v_back_fin, false, u_margin, 1.0 - u_margin, false])
		pasillos_v.append([lerpf(v_front_ini, v_back_ini, 0.5), 1.0])

	# Pintar cajones (90° para autos/buses, 45° diagonal para tractomulas), líneas en U y topes
	var sesgo_u := clampf((cajon_d * 0.45) / maxf(ancho_prom, 1.0), 0.04, 0.12) if tipo == TipoEstacionamiento.TRACTOMULAS else 0.0
	for fila in filas_v:
		var v_ini: float = fila[0]
		var v_fin: float = fila[1]
		var tope_en_ini: bool = fila[2]
		var u_a: float = fila[3]
		var u_b: float = fila[4]
		var skip_ent: bool = fila[5]
		var span_u := maxf(0.05, u_b - u_a - sesgo_u)
		var ancho_fila := ancho_prom * span_u
		var num_cols := maxi(1, int(floor(ancho_fila / cajon_w)))
		var du := span_u / float(num_cols)

		for c in range(num_cols):
			var u0 := u_a + float(c) * du
			var u1 := u0 + du
			var u0_top := u0 if tope_en_ini else (u0 + sesgo_u)
			var u1_top := u1 if tope_en_ini else (u1 + sesgo_u)
			var u0_bot := (u0 + sesgo_u) if tope_en_ini else u0
			var u1_bot := (u1 + sesgo_u) if tope_en_ini else u1
			var u_mid := 0.5 * (u0_top + u1_top)
			if skip_ent and u_mid > (u_ent_izq - 0.005) and u_mid < (u_ent_der + 0.005):
				continue
			# Líneas laterales del cajón (grosor equilibrado)
			_agregar_segmento_caja(st_lin, _bilerp(pts, u0_top, v_ini) + Vector3(0, 0.106, 0), _bilerp(pts, u0_bot, v_fin) + Vector3(0, 0.106, 0), 0.13, 0.02)
			_agregar_segmento_caja(st_lin, _bilerp(pts, u1_top, v_ini) + Vector3(0, 0.106, 0), _bilerp(pts, u1_bot, v_fin) + Vector3(0, 0.106, 0), 0.13, 0.02)
			# Línea de fondo del cajón
			var v_fondo := v_ini if tope_en_ini else v_fin
			var uf0 := u0_top if tope_en_ini else u0_bot
			var uf1 := u1_top if tope_en_ini else u1_bot
			_agregar_segmento_caja(st_lin, _bilerp(pts, uf0, v_fondo) + Vector3(0, 0.106, 0), _bilerp(pts, uf1, v_fondo) + Vector3(0, 0.106, 0), 0.13, 0.02)
			# Tope de llanta
			var v_tope := lerpf(v_ini, v_fin, 0.16 if tope_en_ini else 0.84)
			var ut_mid := lerpf(0.5 * (u0_top + u1_top), 0.5 * (u0_bot + u1_bot), 0.16 if tope_en_ini else 0.84)
			var t_a := _bilerp(pts, ut_mid - du * 0.30, v_tope) + Vector3(0, 0.13, 0)
			var t_b := _bilerp(pts, ut_mid + du * 0.30, v_tope) + Vector3(0, 0.13, 0)
			_agregar_segmento_caja(st_top, t_a, t_b, 0.18, 0.10)

	# Islas centrales (banqueta elevada + franja completa de césped PBR + cabezales + árboles Roble)
	var u_isl_ini_m := maxf(u_margin, u_cross)
	var u_isl_fin_m := 1.0 - u_isl_ini_m
	for isla in islas_v:
		var m_ini: float = isla[0]
		var m_fin: float = isla[1]
		_agregar_plataforma_uv(st_banq, pts, u_isl_ini_m, m_ini, u_isl_fin_m, m_fin, 0.18)
		if arbolado:
			# Franja continua de césped PBR dentro del camellón central
			_agregar_plataforma_uv(st_jard, pts, u_isl_ini_m + 0.015, m_ini + 0.004, u_isl_fin_m - 0.015, m_fin - 0.004, 0.20)
			var n_arb_isl := maxi(2, int(floor((ancho_prom * (u_isl_fin_m - u_isl_ini_m)) / 11.0)))
			for a_i in range(n_arb_isl):
				var ua := lerpf(u_isl_ini_m + 0.05, u_isl_fin_m - 0.05, float(a_i) / float(maxi(1, n_arb_isl - 1)))
				var pos_ai := _bilerp(pts, ua, 0.5 * (m_ini + m_fin)) + Vector3(0, 0.20, 0)
				posiciones_robles.append({"pos": pos_ai, "escala": 0.44, "rot": float(a_i) * 1.7 + m_ini * 5.0})

	# 3B. Entrada principal de tamaño constante en metros (9.2m de ancho, profundidades fijas en metros)
	var u_cen_half := clampf(0.45 / maxf(ancho_prom, 1.0), 0.005, 0.04)
	var v_ceb0 := clampf(0.35 / maxf(largo_prom, 1.0), 0.005, 0.04)
	var v_ceb1 := clampf(2.20 / maxf(largo_prom, 1.0), 0.02, 0.10)
	var v_tal := clampf(2.90 / maxf(largo_prom, 1.0), 0.03, 0.14)
	var v_pare := clampf(3.60 / maxf(largo_prom, 1.0), 0.04, 0.16)
	var v_isl_ent1 := clampf(4.60 / maxf(largo_prom, 1.0), 0.05, 0.20)
	var v_flecha_ent := clampf(5.80 / maxf(largo_prom, 1.0), 0.06, 0.24)
	var v_div_fin := clampf(7.80 / maxf(largo_prom, 1.0), 0.08, 0.30)

	if ancho_prom >= 12.0:
		_agregar_plataforma_uv(st_banq, pts, u_ent_centro - u_cen_half, v_ceb0, u_ent_centro + u_cen_half, v_isl_ent1, 0.22)
		var pos_pil_cen := _bilerp(pts, u_ent_centro, v_tal) + Vector3(0, 0.22, 0)
		_agregar_bloque_3d(st_metal, pos_pil_cen + Vector3(0, 0.55, 0), Vector3(0.32, 1.10, 0.45))
		_agregar_bloque_3d(st_verde, pos_pil_cen + Vector3(0, 1.12, 0), Vector3(0.24, 0.12, 0.34))
		# Instanciar talanqueras 3D dinámicas en posición fija respecto a la entrada (en metros)
		var dir_ent_xz := Vector3(pts[1].x - pts[0].x, 0.0, pts[1].z - pts[0].z)
		var ang_ent := atan2(-dir_ent_xz.z, dir_ent_xz.x) if dir_ent_xz.length_squared() > 0.01 else 0.0
		var u_tal_off := clampf(0.30 / maxf(ancho_prom, 1.0), 0.003, 0.03)
		if _escena_talanquera:
			var scr_tal := load("res://mundo/editor_mapas/TalanqueraParqueo.gd")
			for t_cfg in [
				{"u": u_ent_der - u_tal_off, "rot": ang_ent + PI},
				{"u": u_ent_izq + u_tal_off, "rot": ang_ent}
			]:
				var tal_root := Node3D.new()
				tal_root.position = _bilerp(pts, t_cfg["u"], v_tal) + Vector3(0, 0.12, 0)
				tal_root.rotation.y = t_cfg["rot"]
				var tal_mesh: Node3D = _escena_talanquera.instantiate()
				tal_root.add_child(tal_mesh)
				if scr_tal:
					tal_root.set_script(scr_tal)
				nodo.add_child(tal_root)
		else:
			for u_pil in [u_ent_izq + u_tal_off, u_ent_der - u_tal_off]:
				var pos_p := _bilerp(pts, u_pil, v_tal) + Vector3(0, 0.16, 0)
				_agregar_bloque_3d(st_metal, pos_p + Vector3(0, 0.55, 0), Vector3(0.30, 1.10, 0.38))
				_agregar_bloque_3d(st_verde, pos_p + Vector3(0, 1.12, 0), Vector3(0.22, 0.10, 0.28))

	# Paso peatonal (cebra) dividido en ambos carriles de entrada/salida
	var u_pad_ceb := u_cen_half * 1.4
	for u_rango in [[u_ent_izq + u_pad_ceb, u_ent_centro - u_pad_ceb], [u_ent_centro + u_pad_ceb, u_ent_der - u_pad_ceb]]:
		for z_i in range(4):
			var uz := lerpf(u_rango[0], u_rango[1], float(z_i) / 3.0)
			_agregar_segmento_caja(st_simb_blanco, _bilerp(pts, uz, v_ceb0) + Vector3(0, 0.11, 0), _bilerp(pts, uz, v_ceb1) + Vector3(0, 0.11, 0), 0.36, 0.02)

	# Línea divisoria continua entre carril de entrada y salida + barra de PARE en salida
	_agregar_segmento_caja(st_lin, _bilerp(pts, u_ent_centro, v_isl_ent1) + Vector3(0, 0.11, 0), _bilerp(pts, u_ent_centro, v_div_fin) + Vector3(0, 0.11, 0), 0.14, 0.02)
	_agregar_segmento_caja(st_simb_blanco, _bilerp(pts, u_ent_izq + u_pad_ceb, v_pare) + Vector3(0, 0.11, 0), _bilerp(pts, u_ent_centro - u_pad_ceb, v_pare) + Vector3(0, 0.11, 0), 0.24, 0.02)

	# Flechas de ENTRADA (+v) y SALIDA (-v) proporcionadas al carril
	_agregar_flecha_uv(st_simb_blanco, pts, u_ent_centro + u_ent_half * 0.5, v_flecha_ent, 0.0, 1.0, 2.4, 1.25, 0.112)
	_agregar_flecha_uv(st_simb_blanco, pts, u_ent_centro - u_ent_half * 0.5, v_flecha_ent, 0.0, -1.0, 2.4, 1.25, 0.112)

	# Flechas direccionales y líneas de eje proporcionadas en cada pasillo de circulación
	for p_info in pasillos_v:
		var vc: float = p_info[0]
		var d_sign: float = p_info[1]
		for ua in [0.22, 0.50, 0.78]:
			_agregar_flecha_uv(st_lin, pts, ua, vc, d_sign, 0.0, 2.1, 1.15, 0.112)
		for seg_i in range(6):
			var u_s0 := lerpf(0.12, 0.88, float(seg_i) / 6.0)
			var u_s1 := lerpf(0.12, 0.88, (float(seg_i) + 0.45) / 6.0)
			_agregar_segmento_caja(st_lin, _bilerp(pts, u_s0, vc) + Vector3(0, 0.108, 0), _bilerp(pts, u_s1, vc) + Vector3(0, 0.108, 0), 0.11, 0.02)

	# Flechas del anillo lateral de circulación (conectando pasillos hacia entrada y salida)
	if u_cross > 0.0:
		var u_izq_anillo := maxf(u_margin, u_cross * 0.55)
		var u_der_anillo := 1.0 - u_izq_anillo
		for v_an in [0.35, 0.55, 0.72]:
			_agregar_flecha_uv(st_simb_blanco, pts, u_der_anillo, v_an, 0.0, 1.0, 2.1, 1.15, 0.112)
			_agregar_flecha_uv(st_simb_blanco, pts, u_izq_anillo, v_an, 0.0, -1.0, 2.1, 1.15, 0.112)

	st_lin.generate_normals()
	var mi_lin := MeshInstance3D.new()
	mi_lin.mesh = st_lin.commit()
	mi_lin.material_override = _mat_lineas_amarillo if col_idx == 1 else _mat_lineas_blanco
	nodo.add_child(mi_lin)

	st_top.generate_normals()
	var mi_top := MeshInstance3D.new()
	mi_top.mesh = st_top.commit()
	mi_top.material_override = _mat_tope
	nodo.add_child(mi_top)

	if st_banq.get_vertex_count() > 0 if st_banq.has_method("get_vertex_count") else true:
		st_banq.generate_normals()
		var mesh_b := st_banq.commit()
		if mesh_b and mesh_b.get_surface_count() > 0:
			var mi_banq := MeshInstance3D.new()
			mi_banq.mesh = mesh_b
			mi_banq.material_override = _mat_banqueta
			nodo.add_child(mi_banq)

	st_jard.generate_normals()
	var mesh_j := st_jard.commit()
	if mesh_j and mesh_j.get_surface_count() > 0:
		var mi_jard := MeshInstance3D.new()
		mi_jard.mesh = mesh_j
		mi_jard.material_override = _mat_jardinera
		nodo.add_child(mi_jard)

	st_disc.generate_normals()
	var mesh_dc := st_disc.commit()
	if mesh_dc and mesh_dc.get_surface_count() > 0:
		var mi_dc := MeshInstance3D.new()
		mi_dc.mesh = mesh_dc
		mi_dc.material_override = _mat_discapacidad
		nodo.add_child(mi_dc)

	for pair_st in [
		[st_metal, _mat_metal_oscuro],
		[st_barr, _mat_barrera_roja],
		[st_verde, _mat_acceso_verde],
		[st_simb_blanco, _mat_lineas_blanco]
	]:
		var st_cur: SurfaceTool = pair_st[0]
		st_cur.generate_normals()
		var mesh_cur := st_cur.commit()
		if mesh_cur and mesh_cur.get_surface_count() > 0:
			var mi_cur := MeshInstance3D.new()
			mi_cur.mesh = mesh_cur
			mi_cur.material_override = pair_st[1]
			nodo.add_child(mi_cur)

	# Instanciar árboles Roble reales del proyecto en cada jardinera
	if _escena_roble:
		for r_info in posiciones_robles:
			var roble: Node3D = _escena_roble.instantiate()
			roble.position = r_info["pos"]
			var esc: float = float(r_info["escala"])
			roble.scale = Vector3(esc, esc, esc)
			roble.rotation.y = float(r_info["rot"])
			nodo.add_child(roble)

	# Guía visual 3D flotante de FRENTE / ACCESO (solo visible en modo edición de esquinas)
	var mostrar_ed := _manejadores_visibles and not bool(est.get("finalizado", false))
	var st_guia := SurfaceTool.new()
	st_guia.begin(Mesh.PRIMITIVE_TRIANGLES)
	_agregar_flecha_uv(st_guia, pts, u_ent_centro, -0.05, 0.0, 1.0, 3.2, 2.2, 0.65)
	st_guia.generate_normals()
	var mi_guia := MeshInstance3D.new()
	mi_guia.mesh = st_guia.commit()
	mi_guia.material_override = _mat_frente_guia
	mi_guia.visible = mostrar_ed
	nodo.add_child(mi_guia)
	guias_editor.append(mi_guia)

	# 3C. Vía de enlace con la carretera más cercana (si fue unida)
	var con_via: Dictionary = est.get("conexion_via", {})
	if con_via.has("punto_via") and con_via["punto_via"] is Array and con_via["punto_via"].size() >= 3:
		var pv_arr: Array = con_via["punto_via"]
		var p_via := Vector3(float(pv_arr[0]), float(pv_arr[1]), float(pv_arr[2]))
		var ancho_v := float(con_via.get("ancho_via", 8.8))
		_construir_rampa_conexion_via(nodo, _bilerp(pts, u_ent_izq, 0.0), _bilerp(pts, u_ent_der, 0.0), p_via, ancho_v, col_idx)

	# 4. Postes de iluminación en esquinas
	if ilum:
		var mat_p := StandardMaterial3D.new()
		mat_p.albedo_color = Color(0.25, 0.27, 0.30)
		mat_p.metallic = 0.65
		for c_idx in [0, 1, 2, 3]:
			var pos_l: Vector3 = pts[c_idx]
			var mast := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.07; cyl.bottom_radius = 0.10; cyl.height = 5.5
			mast.mesh = cyl
			mast.material_override = mat_p
			mast.position = pos_l + Vector3(0, 2.75, 0)
			nodo.add_child(mast)

			var foco := OmniLight3D.new()
			foco.light_color = Color(1.0, 0.88, 0.68)
			foco.light_energy = 1.6
			foco.omni_range = 18.0
			foco.position = pos_l + Vector3(0, 5.4, 0)
			nodo.add_child(foco)

	# 5. Manejadores de las 4 esquinas para arrastrar/editar
	for j in range(pts.size()):
		var esf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.75; sm.height = 1.5
		esf.mesh = sm
		esf.position = pts[j] + Vector3(0, 0.75, 0)
		esf.visible = mostrar_ed
		esf.material_override = _mat_esquina_sel if (idx == indice_seleccionado and j == esquina_seleccionada) else _mat_esquina_idle
		nodo.add_child(esf)
		manejadores.append(esf)

	# 6. Manejador verde en la entrada para deslizar su ubicación a lo largo del frente (índice 4)
	var esf_ent := MeshInstance3D.new()
	var sm_ent := SphereMesh.new()
	sm_ent.radius = 0.90; sm_ent.height = 1.80
	esf_ent.mesh = sm_ent
	esf_ent.position = _bilerp(pts, u_ent_centro, 0.0) + Vector3(0, 1.05, 0)
	esf_ent.visible = mostrar_ed
	esf_ent.material_override = _mat_entrada_sel if (idx == indice_seleccionado and esquina_seleccionada == 4) else _mat_entrada_idle
	var mast_ent := MeshInstance3D.new()
	var cyl_ent := CylinderMesh.new()
	cyl_ent.top_radius = 0.14; cyl_ent.bottom_radius = 0.14; cyl_ent.height = 1.05
	mast_ent.mesh = cyl_ent
	mast_ent.position = Vector3(0, -0.52, 0)
	mast_ent.material_override = _mat_entrada_idle
	esf_ent.add_child(mast_ent)
	nodo.add_child(esf_ent)
	manejadores.append(esf_ent)

func _agregar_segmento_caja(st: SurfaceTool, a: Vector3, b: Vector3, ancho: float, alto: float) -> void:
	var dir := b - a
	var d_xz := Vector3(dir.x, 0.0, dir.z)
	if d_xz.length_squared() < 0.0001:
		return
	var lat := Vector3.UP.cross(d_xz).normalized() * (ancho * 0.5)
	var dy := Vector3(0, alto * 0.5, 0)
	var a_tl := a - lat + dy; var a_tr := a + lat + dy
	var b_tl := b - lat + dy; var b_tr := b + lat + dy
	var a_bl := a - lat - dy; var a_br := a + lat - dy
	var b_bl := b - lat - dy; var b_br := b + lat - dy
	# Top (+Y)
	st.add_vertex(a_tl); st.add_vertex(a_tr); st.add_vertex(b_tr)
	st.add_vertex(a_tl); st.add_vertex(b_tr); st.add_vertex(b_tl)
	# Left (-lat)
	st.add_vertex(b_tl); st.add_vertex(a_tl); st.add_vertex(a_bl)
	st.add_vertex(b_tl); st.add_vertex(a_bl); st.add_vertex(b_bl)
	# Right (+lat)
	st.add_vertex(a_tr); st.add_vertex(b_tr); st.add_vertex(b_br)
	st.add_vertex(a_tr); st.add_vertex(b_br); st.add_vertex(a_br)
	# Front cap (a)
	st.add_vertex(a_tr); st.add_vertex(a_tl); st.add_vertex(a_bl)
	st.add_vertex(a_tr); st.add_vertex(a_bl); st.add_vertex(a_br)
	# Back cap (b)
	st.add_vertex(b_tl); st.add_vertex(b_tr); st.add_vertex(b_br)
	st.add_vertex(b_tl); st.add_vertex(b_br); st.add_vertex(b_bl)

func _agregar_plataforma_uv(st: SurfaceTool, pts: Array, u0: float, v0: float, u1: float, v1: float, y_top: float) -> void:
	var p00 := _bilerp(pts, u0, v0) + Vector3(0, y_top, 0)
	var p10 := _bilerp(pts, u1, v0) + Vector3(0, y_top, 0)
	var p11 := _bilerp(pts, u1, v1) + Vector3(0, y_top, 0)
	var p01 := _bilerp(pts, u0, v1) + Vector3(0, y_top, 0)
	st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
	st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
	var y_bot := 0.08
	var b00 := Vector3(p00.x, p00.y - y_top + y_bot, p00.z)
	var b10 := Vector3(p10.x, p10.y - y_top + y_bot, p10.z)
	var b11 := Vector3(p11.x, p11.y - y_top + y_bot, p11.z)
	var b01 := Vector3(p01.x, p01.y - y_top + y_bot, p01.z)
	for side in [[p00, p10, b10, b00], [p10, p11, b11, b10], [p11, p01, b01, b11], [p01, p00, b00, b01]]:
		st.add_vertex(side[0]); st.add_vertex(side[2]); st.add_vertex(side[1])
		st.add_vertex(side[0]); st.add_vertex(side[3]); st.add_vertex(side[2])

func _agregar_flecha_uv(st: SurfaceTool, pts: Array, u: float, v: float, dir_u: float, dir_v: float, largo_m: float, ancho_m: float, y_off: float) -> void:
	var centro := _bilerp(pts, u, v) + Vector3(0, y_off, 0)
	var p_du := _bilerp(pts, clampf(u + 0.05, 0.0, 1.0), v) - _bilerp(pts, clampf(u - 0.05, 0.0, 1.0), v)
	var p_dv := _bilerp(pts, u, clampf(v + 0.05, 0.0, 1.0)) - _bilerp(pts, u, clampf(v - 0.05, 0.0, 1.0))
	var eje_u := Vector3(p_du.x, 0.0, p_du.z).normalized()
	var eje_v := Vector3(p_dv.x, 0.0, p_dv.z).normalized()
	if eje_u.length_squared() < 0.01 or eje_v.length_squared() < 0.01:
		return
	var fwd := (eje_u * dir_u + eje_v * dir_v).normalized()
	var lat := Vector3.UP.cross(fwd).normalized()
	var cola := centro - fwd * (largo_m * 0.5)
	var cuello := centro + fwd * (largo_m * 0.12)
	var punta := centro + fwd * (largo_m * 0.5)
	var w_tallo := ancho_m * 0.22
	var w_ala := ancho_m * 0.52
	# Tallo
	var t0 := cola - lat * w_tallo
	var t1 := cola + lat * w_tallo
	var t2 := cuello + lat * w_tallo
	var t3 := cuello - lat * w_tallo
	st.add_vertex(t0); st.add_vertex(t1); st.add_vertex(t2)
	st.add_vertex(t0); st.add_vertex(t2); st.add_vertex(t3)
	# Punta triangular
	var a0 := cuello - lat * w_ala
	var a1 := cuello + lat * w_ala
	st.add_vertex(a0); st.add_vertex(a1); st.add_vertex(punta)

func _agregar_simbolo_accesibilidad_uv(st: SurfaceTool, pts: Array, u: float, v: float, y_off: float) -> void:
	var centro := _bilerp(pts, u, v) + Vector3(0, y_off, 0)
	var p_du := _bilerp(pts, clampf(u + 0.05, 0.0, 1.0), v) - _bilerp(pts, clampf(u - 0.05, 0.0, 1.0), v)
	var p_dv := _bilerp(pts, u, clampf(v + 0.05, 0.0, 1.0)) - _bilerp(pts, u, clampf(v - 0.05, 0.0, 1.0))
	var eje_u := Vector3(p_du.x, 0.0, p_du.z).normalized()
	var eje_v := Vector3(p_dv.x, 0.0, p_dv.z).normalized()
	if eje_u.length_squared() < 0.01 or eje_v.length_squared() < 0.01:
		return
	# Símbolo estilizado de silla de ruedas en blanco (rueda + respaldo + asiento + cabeza)
	var r := 0.42
	var p_rueda_b := centro + eje_v * 0.18
	_agregar_segmento_caja(st, p_rueda_b - eje_u * r, p_rueda_b + eje_u * r, 0.14, 0.02)
	_agregar_segmento_caja(st, p_rueda_b - eje_u * r, p_rueda_b - eje_u * r - eje_v * 0.52, 0.14, 0.02)
	_agregar_segmento_caja(st, p_rueda_b + eje_u * (r * 0.3) - eje_v * 0.24, p_rueda_b + eje_u * (r * 1.15) - eje_v * 0.24, 0.14, 0.02)
	_agregar_segmento_caja(st, p_rueda_b + eje_u * (r * 1.15) - eje_v * 0.24, p_rueda_b + eje_u * (r * 1.15) + eje_v * 0.22, 0.14, 0.02)
	_agregar_bloque_3d(st, centro - eje_v * 0.55 - eje_u * (r * 0.8), Vector3(0.28, 0.025, 0.28))

func _agregar_jardinera_y_arbol(st_jard: SurfaceTool, st_tronco: SurfaceTool, st_copa_a: SurfaceTool, st_copa_b: SurfaceTool, pos: Vector3, escala: float) -> void:
	# Cuadro de tierra/pasto
	_agregar_bloque_3d(st_jard, pos + Vector3(0, 0.03, 0), Vector3(1.1 * escala, 0.08, 1.1 * escala))
	# Tronco
	var h_tronco := 2.4 * escala
	_agregar_bloque_3d(st_tronco, pos + Vector3(0, h_tronco * 0.5, 0), Vector3(0.32 * escala, h_tronco, 0.32 * escala))
	# Copa en 2 niveles estilizados
	_agregar_bloque_3d(st_copa_a, pos + Vector3(0, h_tronco + 0.7 * escala, 0), Vector3(2.2 * escala, 1.5 * escala, 2.2 * escala))
	_agregar_bloque_3d(st_copa_b, pos + Vector3(0.15 * escala, h_tronco + 1.45 * escala, -0.1 * escala), Vector3(1.55 * escala, 1.15 * escala, 1.55 * escala))

func _agregar_bloque_3d(st: SurfaceTool, centro: Vector3, tam: Vector3) -> void:
	var hx := tam.x * 0.5
	var hy := tam.y * 0.5
	var hz := tam.z * 0.5
	var p000 := centro + Vector3(-hx, -hy, -hz)
	var p100 := centro + Vector3(hx, -hy, -hz)
	var p110 := centro + Vector3(hx, hy, -hz)
	var p010 := centro + Vector3(-hx, hy, -hz)
	var p001 := centro + Vector3(-hx, -hy, hz)
	var p101 := centro + Vector3(hx, -hy, hz)
	var p111 := centro + Vector3(hx, hy, hz)
	var p011 := centro + Vector3(-hx, hy, hz)
	for f in [
		[p010, p110, p111, p011], # Top
		[p000, p001, p101, p100], # Bottom
		[p001, p011, p111, p101], # Front
		[p100, p110, p010, p000], # Back
		[p000, p010, p011, p001], # Left
		[p101, p111, p110, p100], # Right
	]:
		st.add_vertex(f[0]); st.add_vertex(f[1]); st.add_vertex(f[2])
		st.add_vertex(f[0]); st.add_vertex(f[2]); st.add_vertex(f[3])

func _actualizar_colores_manejadores() -> void:
	for i in range(_estacionamientos.size()):
		var mans: Array = _estacionamientos[i].get("manejadores", [])
		for j in range(mans.size()):
			if is_instance_valid(mans[j]):
				var sel := (i == indice_seleccionado and j == esquina_seleccionada)
				if j == 4:
					mans[j].material_override = _mat_entrada_sel if sel else _mat_entrada_idle
				else:
					mans[j].material_override = _mat_esquina_sel if sel else _mat_esquina_idle

func _emitir_seleccion() -> void:
	if indice_seleccionado >= 0 and indice_seleccionado < _estacionamientos.size():
		var est: Dictionary = _estacionamientos[indice_seleccionado]
		estacionamiento_seleccionado_cambiado.emit(true, {
			"indice": indice_seleccionado,
			"tipo": int(est.get("tipo", 0)),
			"color_lineas": int(est.get("color_lineas", 0)),
			"iluminacion": bool(est.get("iluminacion", true)),
			"arbolado": bool(est.get("arbolado", true)),
			"u_entrada": float(est.get("u_entrada", 0.50)),
			"adaptar_terreno": bool(est.get("adaptar_terreno", true)),
			"rotacion": _obtener_rotacion_grados_est(est),
			"finalizado": bool(est.get("finalizado", false)),
			"tiene_conexion": not (est.get("conexion_via", {}) as Dictionary).is_empty()
		})
	else:
		estacionamiento_seleccionado_cambiado.emit(false, {})

func _construir_rampa_conexion_via(nodo: Node3D, p_ent_izq: Vector3, p_ent_der: Vector3, p_via: Vector3, ancho_via: float, col_idx: int) -> void:
	var p_ent_cen := 0.5 * (p_ent_izq + p_ent_der)
	var dir_total := Vector3(p_via.x - p_ent_cen.x, 0.0, p_via.z - p_ent_cen.z)
	if dir_total.length() < 0.8:
		return
	var dir_xz := dir_total.normalized()
	# Detener la rampa justo en el borde exterior de la calzada (sin invadir la doble línea amarilla)
	var recorte_via := maxf(0.0, ancho_via * 0.5 - 0.25)
	var dist_util := maxf(1.2, dir_total.length() - recorte_via)
	var p_destino := p_ent_cen + dir_xz * dist_util
	p_destino.y = p_via.y

	# Garantizar orientación izquierda/derecha consistente con CW hacia arriba (sin cruce en X)
	var right := Vector3.UP.cross(dir_xz).normalized()
	var p_a_ent := p_ent_izq
	var p_b_ent := p_ent_der
	if right.dot(p_ent_der - p_ent_izq) < 0.0:
		p_a_ent = p_ent_der
		p_b_ent = p_ent_izq

	var half_w_ent := clampf(p_ent_izq.distance_to(p_ent_der) * 0.5, 3.8, 5.5)
	var st_rampa := SurfaceTool.new()
	st_rampa.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_bord_r := SurfaceTool.new()
	st_bord_r.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_lin_r := SurfaceTool.new()
	st_lin_r.begin(Mesh.PRIMITIVE_TRIANGLES)

	const PASOS := 8
	for i in range(PASOS):
		var t0 := float(i) / float(PASOS)
		var t1 := float(i + 1) / float(PASOS)
		var c0 := p_ent_cen.lerp(p_destino, t0)
		var c1 := p_ent_cen.lerp(p_destino, t1)
		if i > 0 and i < PASOS - 1:
			c0.y = lerpf(c0.y, _altura_terreno(c0), 0.50)
			c1.y = lerpf(c1.y, _altura_terreno(c1), 0.50)
		var y_off0 := lerpf(0.08, 0.015, t0)
		var y_off1 := lerpf(0.08, 0.015, t1)
		# Ensanchar suavemente (abocinamiento) al llegar al borde de la carretera
		var hw0 := half_w_ent + pow(t0, 2.0) * 1.4
		var hw1 := half_w_ent + pow(t1, 2.0) * 1.4
		var a0 := (p_a_ent if i == 0 else (c0 - right * hw0)) + Vector3(0, y_off0, 0)
		var b0 := (p_b_ent if i == 0 else (c0 + right * hw0)) + Vector3(0, y_off0, 0)
		var a1 := (c1 - right * hw1) + Vector3(0, y_off1, 0)
		var b1 := (c1 + right * hw1) + Vector3(0, y_off1, 0)
		# Cara superior en sentido horario mirando desde +Y
		st_rampa.add_vertex(a0); st_rampa.add_vertex(b0); st_rampa.add_vertex(b1)
		st_rampa.add_vertex(a0); st_rampa.add_vertex(b1); st_rampa.add_vertex(a1)
		# Bordillos laterales solo hasta antes de tocar el hombro de la carretera
		if i < PASOS - 1:
			_agregar_segmento_caja(st_bord_r, a0 + Vector3(0, 0.08, 0), a1 + Vector3(0, 0.08, 0), 0.24, 0.16)
			_agregar_segmento_caja(st_bord_r, b0 + Vector3(0, 0.08, 0), b1 + Vector3(0, 0.08, 0), 0.24, 0.16)
			_agregar_segmento_caja(st_lin_r, c0 + Vector3(0, y_off0 + 0.025, 0), c1 + Vector3(0, y_off1 + 0.025, 0), 0.13, 0.02)
	st_rampa.generate_normals()
	var m_rampa := st_rampa.commit()
	var mi_r := MeshInstance3D.new()
	mi_r.mesh = m_rampa
	mi_r.material_override = _mat_asfalto
	nodo.add_child(mi_r)
	var sb_r := StaticBody3D.new()
	var cs_r := CollisionShape3D.new()
	cs_r.shape = m_rampa.create_trimesh_shape()
	sb_r.add_child(cs_r)
	nodo.add_child(sb_r)
	st_bord_r.generate_normals()
	var mi_br := MeshInstance3D.new()
	mi_br.mesh = st_bord_r.commit()
	mi_br.material_override = _mat_bordillo
	nodo.add_child(mi_br)
	st_lin_r.generate_normals()
	var mi_lr := MeshInstance3D.new()
	mi_lr.mesh = st_lin_r.commit()
	mi_lr.material_override = _mat_lineas_amarillo if col_idx == 1 else _mat_lineas_blanco
	nodo.add_child(mi_lr)

func serializar_estacionamientos() -> Array:
	var salida: Array = []
	for est in _estacionamientos:
		var pts_arr: Array = []
		for p in est["puntos"]:
			pts_arr.append([p.x, p.y, p.z])
		salida.append({
			"puntos": pts_arr,
			"tipo": int(est.get("tipo", 0)),
			"color_lineas": int(est.get("color_lineas", 0)),
			"iluminacion": bool(est.get("iluminacion", true)),
			"arbolado": bool(est.get("arbolado", true)),
			"u_entrada": float(est.get("u_entrada", 0.50)),
			"adaptar_terreno": bool(est.get("adaptar_terreno", true)),
			"finalizado": bool(est.get("finalizado", false)),
			"conexion_via": est.get("conexion_via", {})
		})
	return salida

func deserializar_estacionamientos(lista: Array) -> void:
	_asegurar_inicializado()
	limpiar_todos()
	for d in lista:
		if not (d is Dictionary):
			continue
		var pts: Array[Vector3] = []
		for pa in d.get("puntos", []):
			if pa is Array and pa.size() >= 3:
				pts.append(Vector3(float(pa[0]), float(pa[1]), float(pa[2])))
		if pts.size() != 4:
			continue
		var nodo := Node3D.new()
		nodo.name = "Estacionamiento_%d" % (_estacionamientos.size() + 1)
		_contenedor.add_child(nodo)
		_estacionamientos.append({
			"puntos": pts,
			"tipo": int(d.get("tipo", 0)),
			"color_lineas": int(d.get("color_lineas", 0)),
			"iluminacion": bool(d.get("iluminacion", true)),
			"arbolado": bool(d.get("arbolado", true)),
			"u_entrada": float(d.get("u_entrada", 0.50)),
			"adaptar_terreno": bool(d.get("adaptar_terreno", true)),
			"finalizado": bool(d.get("finalizado", false)),
			"conexion_via": d.get("conexion_via", {}),
			"nodo": nodo,
			"manejadores": [],
			"guias_editor": []
		})
		_reconstruir_estacionamiento(_estacionamientos.size() - 1)
	estacionamiento_actualizado.emit(_estacionamientos.size())
