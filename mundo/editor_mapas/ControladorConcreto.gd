class_name ControladorConcreto
extends Node3D

signal zona_actualizada(total: int)
signal zona_seleccionada_cambiada(hay_seleccion: bool, datos: Dictionary)

enum AcabadoConcreto {
	LISO = 0,
	LOSAS = 1,
	OSCURO = 2,
	ADOQUIN = 3
}

var controlador_terreno = null

var _contenedor: Node3D = null
var _zonas: Array[Dictionary] = []

var indice_seleccionado: int = -1
var punto_seleccionado: int = -1
var _manejadores_visibles: bool = false

var rotacion_cursor_grados: float = 0.0
var adaptar_terreno_activo: bool = true

var _cursor_concreto: Node3D = null
var _materiales_acabado: Array[StandardMaterial3D] = []
var _mat_borde_losa: StandardMaterial3D = null
var _mat_punto_idle: StandardMaterial3D = null
var _mat_punto_sel: StandardMaterial3D = null

func _ready() -> void:
	_asegurar_inicializado()

func _asegurar_inicializado() -> void:
	if not is_instance_valid(_contenedor):
		_contenedor = Node3D.new()
		_contenedor.name = "ZonasConcreto"
		add_child(_contenedor)
	if _materiales_acabado.is_empty():
		_inicializar_materiales()
	if not is_instance_valid(_cursor_concreto):
		_cursor_concreto = _construir_cursor_concreto()
		_cursor_concreto.visible = false
		add_child(_cursor_concreto)

func _crear_material_concreto(base_col: Color, var_macro: float, var_grano: float, con_juntas: bool, modo_adoquin: bool, rough: float, scale: float) -> StandardMaterial3D:
	var noise_macro := FastNoiseLite.new()
	noise_macro.seed = 421 if not modo_adoquin else 887
	noise_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_macro.frequency = 0.045
	noise_macro.fractal_octaves = 4

	var noise_grano := FastNoiseLite.new()
	noise_grano.seed = 1337
	noise_grano.noise_type = FastNoiseLite.TYPE_VALUE
	noise_grano.frequency = 0.38
	noise_grano.fractal_octaves = 3

	var img_macro: Image = noise_macro.get_seamless_image(256, 256, false, false)
	var img_grano: Image = noise_grano.get_seamless_image(256, 256, false, false)
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var img_h := Image.create(256, 256, false, Image.FORMAT_RF)

	for y in range(256):
		for x in range(256):
			var vm := img_macro.get_pixel(x, y).r - 0.5
			var vg := img_grano.get_pixel(x, y).r - 0.5
			var d := vm * var_macro + vg * var_grano
			var h_val := clampf(0.5 + vm * 0.25 + vg * 0.30, 0.0, 1.0)
			# Ligero matiz cálido/frío mineral para realismo de concreto
			var c := Color(
				clampf(base_col.r + d + vm * 0.02, 0.0, 1.0),
				clampf(base_col.g + d, 0.0, 1.0),
				clampf(base_col.b + d - vm * 0.015, 0.0, 1.0),
				1.0
			)
			if con_juntas:
				if x < 3 or y < 3 or abs(x - 128) < 2 or abs(y - 128) < 2:
					c = c.darkened(0.32)
					h_val = 0.12
			elif modo_adoquin:
				var row := y / 32
				var ox := (x + (16 if (row % 2) == 1 else 0)) % 64
				var oy := y % 32
				if ox < 3 or oy < 3:
					c = c.darkened(0.36)
					h_val = 0.10
				else:
					var cell_hash := float(((x + (16 if (row % 2) == 1 else 0)) / 64) * 31 + row * 17)
					var tone := (sin(cell_hash) * 0.5 + 0.5 - 0.5) * 0.07
					c = Color(clampf(c.r + tone, 0.0, 1.0), clampf(c.g + tone, 0.0, 1.0), clampf(c.b + tone, 0.0, 1.0), 1.0)
			img.set_pixel(x, y, c)
			img_h.set_pixel(x, y, Color(h_val, h_val, h_val, 1.0))

	img.generate_mipmaps()
	img_h.bump_map_to_normal_map(1.6)
	img_h.generate_mipmaps()

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.normal_enabled = true
	mat.normal_texture = ImageTexture.create_from_image(img_h)
	mat.normal_scale = 0.85
	mat.roughness = rough
	mat.metallic = 0.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(scale, scale, scale)
	return mat

func _inicializar_materiales() -> void:
	_materiales_acabado.clear()
	var specs := [
		{"col": Color(0.61, 0.60, 0.58), "macro": 0.12, "grano": 0.09, "juntas": false, "adoquin": false, "rough": 0.90, "scale": 0.30},
		{"col": Color(0.65, 0.64, 0.61), "macro": 0.10, "grano": 0.08, "juntas": true,  "adoquin": false, "rough": 0.88, "scale": 0.24},
		{"col": Color(0.32, 0.33, 0.35), "macro": 0.11, "grano": 0.09, "juntas": false, "adoquin": false, "rough": 0.92, "scale": 0.30},
		{"col": Color(0.51, 0.50, 0.48), "macro": 0.09, "grano": 0.08, "juntas": false, "adoquin": true,  "rough": 0.90, "scale": 0.42},
	]
	for sp in specs:
		_materiales_acabado.append(_crear_material_concreto(sp["col"], sp["macro"], sp["grano"], sp["juntas"], sp["adoquin"], sp["rough"], sp["scale"]))

	_mat_borde_losa = StandardMaterial3D.new()
	_mat_borde_losa.albedo_color = Color(0.48, 0.49, 0.51)
	_mat_borde_losa.roughness = 0.88

	_mat_punto_idle = StandardMaterial3D.new()
	_mat_punto_idle.albedo_color = Color(0.95, 0.75, 0.20)
	_mat_punto_idle.emission_enabled = true
	_mat_punto_idle.emission = Color(0.95, 0.70, 0.10)
	_mat_punto_idle.emission_energy_multiplier = 1.6

	_mat_punto_sel = StandardMaterial3D.new()
	_mat_punto_sel.albedo_color = Color(0.20, 0.95, 0.48)
	_mat_punto_sel.emission_enabled = true
	_mat_punto_sel.emission = Color(0.20, 0.95, 0.48)
	_mat_punto_sel.emission_energy_multiplier = 2.0

func _construir_cursor_concreto() -> Node3D:
	var n := Node3D.new()
	n.name = "CursorConcreto"
	var mat_c := StandardMaterial3D.new()
	mat_c.albedo_color = Color(0.85, 0.90, 0.96, 0.92)
	mat_c.emission_enabled = true
	mat_c.emission = Color(0.75, 0.82, 0.92)
	mat_c.emission_energy_multiplier = 1.4
	mat_c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mat_fill := StandardMaterial3D.new()
	mat_fill.albedo_color = Color(0.75, 0.82, 0.90, 0.24)
	mat_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_fill.cull_mode = BaseMaterial3D.CULL_DISABLED

	var hw := 8.0
	var hd := 6.0
	var pts := [
		Vector3(-hw, 0.0, -hd),
		Vector3(0.0, 0.0, -hd),
		Vector3(hw, 0.0, -hd),
		Vector3(hw, 0.0, 0.0),
		Vector3(hw, 0.0, hd),
		Vector3(0.0, 0.0, hd),
		Vector3(-hw, 0.0, hd),
		Vector3(-hw, 0.0, 0.0)
	]

	var st_f := SurfaceTool.new()
	st_f.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_f.add_vertex(pts[0]); st_f.add_vertex(pts[2]); st_f.add_vertex(pts[4])
	st_f.add_vertex(pts[0]); st_f.add_vertex(pts[4]); st_f.add_vertex(pts[6])
	st_f.generate_normals()
	var mi_f := MeshInstance3D.new()
	mi_f.mesh = st_f.commit()
	mi_f.material_override = mat_fill
	n.add_child(mi_f)

	for pt in pts:
		var esf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.50; sm.height = 1.0
		esf.mesh = sm
		esf.position = pt + Vector3(0.0, 0.50, 0.0)
		esf.material_override = mat_c
		n.add_child(esf)
	return n

func actualizar_cursor_concreto(pos_mundo: Vector3, visible_flag: bool) -> void:
	_asegurar_inicializado()
	if not is_instance_valid(_cursor_concreto):
		return
	_cursor_concreto.visible = visible_flag
	if visible_flag:
		_cursor_concreto.global_position = pos_mundo + Vector3(0.0, 0.25, 0.0)
		_cursor_concreto.rotation.y = -deg_to_rad(rotacion_cursor_grados)

func rotar_cursor(delta_grados: float) -> float:
	rotacion_cursor_grados = wrapf(rotacion_cursor_grados + delta_grados, 0.0, 360.0)
	return rotacion_cursor_grados

func _altura_terreno(p: Vector3) -> float:
	if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
		return float(controlador_terreno.obtener_altura(p))
	return p.y

func crear_zona_concreto(pos_mundo: Vector3, acabado: int = 0) -> int:
	_asegurar_inicializado()
	var hw := 8.0
	var hd := 6.0
	var rot_rad := deg_to_rad(rotacion_cursor_grados)
	var base_2d := [
		Vector2(-hw, -hd),
		Vector2(0.0, -hd),
		Vector2(hw, -hd),
		Vector2(hw, 0.0),
		Vector2(hw, hd),
		Vector2(0.0, hd),
		Vector2(-hw, hd),
		Vector2(-hw, 0.0)
	]
	var pts: Array[Vector3] = []
	for b in base_2d:
		var r: Vector2 = (b as Vector2).rotated(rot_rad)
		var p := pos_mundo + Vector3(r.x, 0.0, r.y)
		p.y = _altura_terreno(p)
		pts.append(p)

	var nodo := Node3D.new()
	nodo.name = "Concreto_%d" % (_zonas.size() + 1)
	_contenedor.add_child(nodo)

	_zonas.append({
		"puntos": pts,
		"acabado": acabado,
		"altura_losa": 0.16,
		"bordillo": false,
		"adaptar_terreno": adaptar_terreno_activo,
		"finalizado": false,
		"nodo": nodo,
		"manejadores": []
	})
	var idx := _zonas.size() - 1
	indice_seleccionado = idx
	punto_seleccionado = -1
	_reconstruir_zona(idx)
	if adaptar_terreno_activo:
		_adaptar_terreno_a_zona(idx, false)
	zona_actualizada.emit(_zonas.size())
	_emitir_seleccion()
	return idx

func establecer_visibilidad_manejadores(visible_flag: bool) -> void:
	_manejadores_visibles = visible_flag
	for z in _zonas:
		var mostrar := visible_flag and not bool(z.get("finalizado", false))
		for m in z.get("manejadores", []):
			if is_instance_valid(m):
				m.visible = mostrar

func esta_editando_puntos() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	return not bool(_zonas[indice_seleccionado].get("finalizado", false))

func obtener_centro_seleccionado() -> Vector3:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return Vector3.ZERO
	var pts: Array = _zonas[indice_seleccionado]["puntos"]
	if pts.is_empty():
		return Vector3.ZERO
	var suma := Vector3.ZERO
	for p in pts:
		suma += p as Vector3
	return suma / float(pts.size())

func buscar_punto_por_rayo(origen: Vector3, dir: Vector3) -> Dictionary:
	var mejor := {"encontrado": false, "idx_zona": -1, "idx_pto": -1, "dist": 9999.0}
	if not _manejadores_visibles:
		return mejor
	var d_norm := dir.normalized()
	for i in range(_zonas.size()):
		if bool(_zonas[i].get("finalizado", false)):
			continue
		var pts: Array = _zonas[i]["puntos"]
		for j in range(pts.size()):
			var p: Vector3 = pts[j] + Vector3(0.0, 0.65, 0.0)
			var to_p := p - origen
			var t := to_p.dot(d_norm)
			if t <= 0.1:
				continue
			var perp := (origen + d_norm * t).distance_to(p)
			if perp <= 2.3 and t < float(mejor["dist"]):
				mejor = {"encontrado": true, "idx_zona": i, "idx_pto": j, "dist": t}
	return mejor

func seleccionar_punto(idx_zona: int, idx_pto: int) -> void:
	indice_seleccionado = idx_zona
	punto_seleccionado = idx_pto
	_actualizar_colores_manejadores()
	_emitir_seleccion()

func buscar_zona_por_posicion(pos_mundo: Vector3) -> int:
	var p2 := Vector2(pos_mundo.x, pos_mundo.z)
	for i in range(_zonas.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(p2, _pts_a_poly2d(_zonas[i]["puntos"])):
			return i
	return -1

func seleccionar_zona(idx_zona: int) -> void:
	indice_seleccionado = idx_zona
	punto_seleccionado = -1
	_actualizar_colores_manejadores()
	_emitir_seleccion()

func finalizar_edicion_actual() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	_zonas[indice_seleccionado]["finalizado"] = true
	punto_seleccionado = -1
	if bool(_zonas[indice_seleccionado].get("adaptar_terreno", true)):
		_adaptar_terreno_a_zona(indice_seleccionado, false)
	establecer_visibilidad_manejadores(_manejadores_visibles)
	_emitir_seleccion()
	return true

func activar_edicion_puntos_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	_zonas[indice_seleccionado]["finalizado"] = false
	establecer_visibilidad_manejadores(true)
	_emitir_seleccion()
	return true

func mover_punto(idx_zona: int, idx_pto: int, nueva_pos: Vector3) -> void:
	if idx_zona < 0 or idx_zona >= _zonas.size():
		return
	var pts: Array = _zonas[idx_zona]["puntos"]
	if idx_pto < 0 or idx_pto >= pts.size():
		return
	var pos_adj := nueva_pos
	pos_adj.y = _altura_terreno(nueva_pos)
	pts[idx_pto] = pos_adj
	_reconstruir_zona(idx_zona)

func agregar_punto_en_borde_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	var pts: Array = _zonas[indice_seleccionado]["puntos"]
	if pts.size() < 3:
		return false
	var idx_ins := punto_seleccionado if (punto_seleccionado >= 0 and punto_seleccionado < pts.size()) else 0
	if punto_seleccionado < 0:
		# Si no hay punto específico seleccionado, dividir el borde más largo
		var max_len := -1.0
		for i in range(pts.size()):
			var len_i: float = (pts[i] as Vector3).distance_to(pts[(i + 1) % pts.size()] as Vector3)
			if len_i > max_len:
				max_len = len_i
				idx_ins = i
	var p_a: Vector3 = pts[idx_ins]
	var p_b: Vector3 = pts[(idx_ins + 1) % pts.size()]
	var p_mid := p_a.lerp(p_b, 0.5)
	p_mid.y = _altura_terreno(p_mid)
	pts.insert(idx_ins + 1, p_mid)
	punto_seleccionado = idx_ins + 1
	_reconstruir_zona(indice_seleccionado)
	_emitir_seleccion()
	return true

func subdividir_bordes_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	var pts: Array = _zonas[indice_seleccionado]["puntos"]
	if pts.size() >= 32:
		return false
	var nuevos: Array[Vector3] = []
	for i in range(pts.size()):
		var p_a: Vector3 = pts[i]
		var p_b: Vector3 = pts[(i + 1) % pts.size()]
		nuevos.append(p_a)
		var p_mid := p_a.lerp(p_b, 0.5)
		p_mid.y = _altura_terreno(p_mid)
		nuevos.append(p_mid)
	_zonas[indice_seleccionado]["puntos"] = nuevos
	punto_seleccionado = -1
	_reconstruir_zona(indice_seleccionado)
	_emitir_seleccion()
	return true

func eliminar_punto_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	var pts: Array = _zonas[indice_seleccionado]["puntos"]
	if pts.size() <= 3:
		return false
	var idx_del := punto_seleccionado if (punto_seleccionado >= 0 and punto_seleccionado < pts.size()) else (pts.size() - 1)
	pts.remove_at(idx_del)
	punto_seleccionado = mini(idx_del, pts.size() - 1)
	_reconstruir_zona(indice_seleccionado)
	_emitir_seleccion()
	return true

func establecer_acabado_seleccionado(acabado: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return
	_zonas[indice_seleccionado]["acabado"] = clampi(acabado, 0, 3)
	_reconstruir_zona(indice_seleccionado)
	_emitir_seleccion()

func establecer_altura_losa_seleccionada(altura: float) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return
	_zonas[indice_seleccionado]["altura_losa"] = clampf(altura, 0.05, 0.80)
	_reconstruir_zona(indice_seleccionado)

func establecer_bordillo_seleccionado(activo: bool) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return
	_zonas[indice_seleccionado]["bordillo"] = activo
	_reconstruir_zona(indice_seleccionado)
	_emitir_seleccion()

func establecer_adaptar_terreno(activo: bool) -> void:
	adaptar_terreno_activo = activo
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return
	_zonas[indice_seleccionado]["adaptar_terreno"] = activo
	if activo:
		_adaptar_terreno_a_zona(indice_seleccionado, false)
	else:
		var pts: Array = _zonas[indice_seleccionado]["puntos"]
		for j in range(pts.size()):
			var pj: Vector3 = pts[j]
			pj.y = _altura_terreno(pj)
			pts[j] = pj
		_reconstruir_zona(indice_seleccionado)
	_emitir_seleccion()

func adaptar_terreno_zona(idx: int) -> bool:
	if idx < 0 or idx >= _zonas.size():
		return false
	if not bool(_zonas[idx].get("adaptar_terreno", true)):
		return false
	return _adaptar_terreno_a_zona(idx, false)

func nivelar_terreno_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	return _adaptar_terreno_a_zona(indice_seleccionado, true)

func rotar_seleccionado(delta_grados: float) -> float:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return 0.0
	var pts: Array = _zonas[indice_seleccionado]["puntos"]
	if pts.is_empty():
		return 0.0
	var cx := 0.0
	var cz := 0.0
	for p in pts:
		cx += float(p.x)
		cz += float(p.z)
	cx /= float(pts.size())
	cz /= float(pts.size())
	var delta_rad := deg_to_rad(delta_grados)
	for j in range(pts.size()):
		var pj: Vector3 = pts[j]
		var rel := Vector2(pj.x - cx, pj.z - cz).rotated(delta_rad)
		var p_rot := Vector3(cx + rel.x, pj.y, cz + rel.y)
		p_rot.y = _altura_terreno(p_rot)
		pts[j] = p_rot
	_reconstruir_zona(indice_seleccionado)
	if bool(_zonas[indice_seleccionado].get("adaptar_terreno", true)):
		_adaptar_terreno_a_zona(indice_seleccionado, false)
	return _obtener_rotacion_grados(_zonas[indice_seleccionado])

func _obtener_rotacion_grados(z: Dictionary) -> float:
	var pts: Array = z["puntos"]
	if pts.size() < 2:
		return 0.0
	var dv := Vector2(pts[1].x - pts[0].x, pts[1].z - pts[0].z)
	if dv.length_squared() < 0.0001:
		return 0.0
	return wrapf(rad_to_deg(atan2(dv.y, dv.x)), 0.0, 360.0)

func borrar_zona_en_posicion(pos_mundo: Vector3) -> bool:
	var idx := buscar_zona_por_posicion(pos_mundo)
	if idx < 0:
		return false
	var prev_sel := indice_seleccionado
	indice_seleccionado = idx
	var ok := eliminar_seleccionado()
	if prev_sel != idx and prev_sel >= 0:
		indice_seleccionado = mini(prev_sel, _zonas.size() - 1)
	return ok

func eliminar_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _zonas.size():
		return false
	var nodo: Node3D = _zonas[indice_seleccionado]["nodo"]
	if is_instance_valid(nodo):
		_contenedor.remove_child(nodo)
		nodo.queue_free()
	_zonas.remove_at(indice_seleccionado)
	indice_seleccionado = -1
	punto_seleccionado = -1
	zona_actualizada.emit(_zonas.size())
	_emitir_seleccion()
	return true

func limpiar_todos() -> void:
	for z in _zonas:
		if is_instance_valid(z.get("nodo")):
			_contenedor.remove_child(z["nodo"])
			(z["nodo"] as Node3D).queue_free()
	_zonas.clear()
	indice_seleccionado = -1
	punto_seleccionado = -1
	zona_actualizada.emit(0)
	_emitir_seleccion()

func _pts_a_poly2d(pts: Array) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(float(p.x), float(p.z)))
	return poly

func _adaptar_terreno_a_zona(idx: int, nivelar_plano: bool) -> bool:
	if idx < 0 or idx >= _zonas.size():
		return false
	if not controlador_terreno or not controlador_terreno.terrain or not controlador_terreno.terrain.data:
		return false
	var terrain = controlador_terreno.terrain
	var t_data = terrain.data
	var pts: Array = _zonas[idx]["puntos"]
	if pts.size() < 3:
		return false

	var h_prom := 0.0
	for p in pts:
		h_prom += float(p.y)
	h_prom /= float(pts.size())
	if nivelar_plano:
		for j in range(pts.size()):
			var pj: Vector3 = pts[j]
			pj.y = h_prom
			pts[j] = pj

	var poly := _pts_a_poly2d(pts)
	var tris := Geometry2D.triangulate_polygon(poly)
	var vertex_spacing: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var edge_margin := 1.4
	var edge_falloff := 5.0
	var pad := edge_margin + edge_falloff + vertex_spacing * 2.0

	var min_x := float(pts[0].x)
	var max_x := float(pts[0].x)
	var min_z := float(pts[0].z)
	var max_z := float(pts[0].z)
	for p in pts:
		min_x = minf(min_x, float(p.x))
		max_x = maxf(max_x, float(p.x))
		min_z = minf(min_z, float(p.z))
		max_z = maxf(max_z, float(p.z))

	var min_xz := Vector3(min_x - pad, 0.0, min_z - pad).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing))
	var max_xz := Vector3(max_x + pad, 0.0, max_z + pad).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing)) + Vector3(vertex_spacing, 0.0, vertex_spacing)

	var modificado := false
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var world_pos := Vector3(x, 0.0, z)
			if t_data.has_regionp(world_pos):
				var curr_h: float = t_data.get_height(world_pos)
				if not is_nan(curr_h):
					var hd := _altura_poly_y_dist(Vector2(x, z), pts, poly, tris, h_prom, nivelar_plano)
					var h_target := hd.x - 0.05
					var dist := hd.y
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
		_reconstruir_zona(idx)
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
	return Vector3(1.0 - u - v, u, v)

func _altura_poly_y_dist(p_xz: Vector2, pts: Array, poly: PackedVector2Array, tris: PackedInt32Array, h_prom: float, nivelar_plano: bool) -> Vector2:
	var dentro := Geometry2D.is_point_in_polygon(p_xz, poly)
	if nivelar_plano and dentro:
		return Vector2(h_prom, 0.0)
	if dentro and tris.size() >= 3:
		for ti in range(0, tris.size(), 3):
			var i0 := tris[ti]
			var i1 := tris[ti + 1]
			var i2 := tris[ti + 2]
			var bc := _barycentric_2d(p_xz, poly[i0], poly[i1], poly[i2])
			if bc.x >= -0.002 and bc.y >= -0.002 and bc.z >= -0.002:
				var h := bc.x * float(pts[i0].y) + bc.y * float(pts[i1].y) + bc.z * float(pts[i2].y)
				return Vector2(h, 0.0)

	var mejor_dist := 999999.0
	var mejor_h := h_prom
	var n := pts.size()
	for i in range(n):
		var j := (i + 1) % n
		var q_xz := Geometry2D.get_closest_point_to_segment(p_xz, poly[i], poly[j])
		var d := p_xz.distance_to(q_xz)
		if d < mejor_dist:
			mejor_dist = d
			var seg_len := poly[i].distance_to(poly[j])
			var t := clampf(poly[i].distance_to(q_xz) / maxf(seg_len, 0.0001), 0.0, 1.0)
			mejor_h = lerpf(float(pts[i].y), float(pts[j].y), t)
	return Vector2(h_prom if nivelar_plano else mejor_h, 0.0 if dentro else mejor_dist)

func _reconstruir_zona(idx: int) -> void:
	if idx < 0 or idx >= _zonas.size():
		return
	var z: Dictionary = _zonas[idx]
	var nodo: Node3D = z["nodo"]
	for ch in nodo.get_children():
		nodo.remove_child(ch)
		ch.queue_free()
	var manejadores: Array[MeshInstance3D] = []
	z["manejadores"] = manejadores

	var pts: Array = z["puntos"]
	if pts.size() < 3:
		return
	var acabado: int = clampi(int(z.get("acabado", 0)), 0, _materiales_acabado.size() - 1)
	var altura_losa: float = float(z.get("altura_losa", 0.16))
	var con_bordillo: bool = bool(z.get("bordillo", false))

	var poly := _pts_a_poly2d(pts)
	var tris := Geometry2D.triangulate_polygon(poly)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ti in range(0, tris.size(), 3):
		var a: Vector3 = pts[tris[ti]] + Vector3(0.0, altura_losa, 0.0)
		var b: Vector3 = pts[tris[ti + 1]] + Vector3(0.0, altura_losa, 0.0)
		var c: Vector3 = pts[tris[ti + 2]] + Vector3(0.0, altura_losa, 0.0)
		var nrm := (b - a).cross(c - a)
		if nrm.y > 0.0:
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
		else:
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

	# Faldones perimetrales hacia abajo para evitar huecos en pendientes
	var n := pts.size()
	var area2 := 0.0
	for i in range(n):
		var j := (i + 1) % n
		area2 += (poly[i].x * poly[j].y - poly[j].x * poly[i].y)
	var ccw := area2 > 0.0
	for i in range(n):
		var j := (i + 1) % n
		var e0: Vector3 = (pts[i] as Vector3) + Vector3(0.0, altura_losa, 0.0)
		var e1: Vector3 = (pts[j] as Vector3) + Vector3(0.0, altura_losa, 0.0)
		var b0 := e0 - Vector3(0.0, altura_losa + 0.65, 0.0)
		var b1 := e1 - Vector3(0.0, altura_losa + 0.65, 0.0)
		if ccw:
			st.add_vertex(e0); st.add_vertex(b0); st.add_vertex(b1)
			st.add_vertex(e0); st.add_vertex(b1); st.add_vertex(e1)
		else:
			st.add_vertex(e0); st.add_vertex(e1); st.add_vertex(b1)
			st.add_vertex(e0); st.add_vertex(b1); st.add_vertex(b0)

	st.generate_normals()
	var mesh_losa := st.commit()
	var mi_losa := MeshInstance3D.new()
	mi_losa.mesh = mesh_losa
	mi_losa.material_override = _materiales_acabado[acabado]
	nodo.add_child(mi_losa)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh_losa.create_trimesh_shape()
	sb.add_child(cs)
	nodo.add_child(sb)

	if con_bordillo:
		var st_bord := SurfaceTool.new()
		st_bord.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(n):
			var j := (i + 1) % n
			var pa: Vector3 = (pts[i] as Vector3) + Vector3(0.0, altura_losa + 0.08, 0.0)
			var pb: Vector3 = (pts[j] as Vector3) + Vector3(0.0, altura_losa + 0.08, 0.0)
			_agregar_segmento_caja(st_bord, pa, pb, 0.26, 0.16)
		st_bord.generate_normals()
		var mi_b := MeshInstance3D.new()
		mi_b.mesh = st_bord.commit()
		mi_b.material_override = _mat_borde_losa
		nodo.add_child(mi_b)

	var mostrar_ed := _manejadores_visibles and not bool(z.get("finalizado", false))
	for j in range(pts.size()):
		var esf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.60; sm.height = 1.20
		esf.mesh = sm
		esf.position = (pts[j] as Vector3) + Vector3(0.0, altura_losa + 0.60, 0.0)
		esf.visible = mostrar_ed
		esf.material_override = _mat_punto_sel if (idx == indice_seleccionado and j == punto_seleccionado) else _mat_punto_idle
		nodo.add_child(esf)
		manejadores.append(esf)

func _agregar_segmento_caja(st: SurfaceTool, a: Vector3, b: Vector3, ancho: float, alto: float) -> void:
	var dir := b - a
	var len_seg := dir.length()
	if len_seg < 0.05:
		return
	var fwd := dir / len_seg
	var right := fwd.cross(Vector3.UP).normalized() * (ancho * 0.5)
	if right.length_squared() < 0.001:
		right = Vector3(ancho * 0.5, 0.0, 0.0)
	var half_h := Vector3(0.0, alto * 0.5, 0.0)
	var a_l := a - right; var a_r := a + right
	var b_l := b - right; var b_r := b + right
	for quad in [
		[a_l + half_h, a_r + half_h, b_r + half_h, b_l + half_h],
		[a_l - half_h, a_l + half_h, b_l + half_h, b_l - half_h],
		[a_r + half_h, a_r - half_h, b_r - half_h, b_r + half_h],
		[a_l - half_h, a_r - half_h, a_r + half_h, a_l + half_h],
		[b_r - half_h, b_l - half_h, b_l + half_h, b_r + half_h],
	]:
		st.add_vertex(quad[0]); st.add_vertex(quad[1]); st.add_vertex(quad[2])
		st.add_vertex(quad[0]); st.add_vertex(quad[2]); st.add_vertex(quad[3])

func _actualizar_colores_manejadores() -> void:
	for i in range(_zonas.size()):
		var mans: Array = _zonas[i].get("manejadores", [])
		for j in range(mans.size()):
			var m := mans[j] as MeshInstance3D
			if is_instance_valid(m):
				m.material_override = _mat_punto_sel if (i == indice_seleccionado and j == punto_seleccionado) else _mat_punto_idle

func _emitir_seleccion() -> void:
	if indice_seleccionado >= 0 and indice_seleccionado < _zonas.size():
		var z: Dictionary = _zonas[indice_seleccionado]
		zona_seleccionada_cambiada.emit(true, {
			"indice": indice_seleccionado,
			"num_puntos": (z["puntos"] as Array).size(),
			"acabado": int(z.get("acabado", 0)),
			"altura_losa": float(z.get("altura_losa", 0.16)),
			"bordillo": bool(z.get("bordillo", false)),
			"adaptar_terreno": bool(z.get("adaptar_terreno", true)),
			"finalizado": bool(z.get("finalizado", false))
		})
	else:
		zona_seleccionada_cambiada.emit(false, {})

func serializar_zonas() -> Array:
	var salida: Array = []
	for z in _zonas:
		var pts_arr: Array = []
		for p in z["puntos"]:
			pts_arr.append([p.x, p.y, p.z])
		salida.append({
			"puntos": pts_arr,
			"acabado": int(z.get("acabado", 0)),
			"altura_losa": float(z.get("altura_losa", 0.16)),
			"bordillo": bool(z.get("bordillo", false)),
			"adaptar_terreno": bool(z.get("adaptar_terreno", true)),
			"finalizado": bool(z.get("finalizado", false))
		})
	return salida

func deserializar_zonas(lista: Array) -> void:
	_asegurar_inicializado()
	limpiar_todos()
	for d in lista:
		if not (d is Dictionary):
			continue
		var pts: Array[Vector3] = []
		for pa in d.get("puntos", []):
			if pa is Array and pa.size() >= 3:
				pts.append(Vector3(float(pa[0]), float(pa[1]), float(pa[2])))
		if pts.size() < 3:
			continue
		var nodo := Node3D.new()
		nodo.name = "Concreto_%d" % (_zonas.size() + 1)
		_contenedor.add_child(nodo)
		_zonas.append({
			"puntos": pts,
			"acabado": int(d.get("acabado", 0)),
			"altura_losa": float(d.get("altura_losa", 0.16)),
			"bordillo": bool(d.get("bordillo", false)),
			"adaptar_terreno": bool(d.get("adaptar_terreno", true)),
			"finalizado": bool(d.get("finalizado", false)),
			"nodo": nodo,
			"manejadores": []
		})
		_reconstruir_zona(_zonas.size() - 1)
	zona_actualizada.emit(_zonas.size())
