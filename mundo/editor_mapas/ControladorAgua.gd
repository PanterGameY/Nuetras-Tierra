class_name ControladorAgua
extends Node3D

## ControladorAgua.gd
## Gestión de cuerpos de agua procedurables (Lagos, Cuencas, Ríos, Nivel y Limpieza) para el Editor de Mapas.

signal cuerpo_agua_creado(nodo: Node3D)
signal cuerpo_agua_modificado(nodo: Node3D)
signal cuerpo_agua_eliminado(nodo: Node3D)

const SHADER_AGUA := preload("res://shaders/agua_realista.gdshader")

enum TipoAgua {
	LAGO_CIRCULAR,
	LAGO_RECTANGULAR,
	RIO_TRAMO
}

var controlador_terreno: Node = null

var cuerpo_seleccionado: Node3D = null
var _contenedor_aguas: Node3D = null
var _contador_aguas: int = 0

var _tex_normal1: ImageTexture = null
var _tex_normal2: ImageTexture = null

var _cursor_agua: Node3D = null
var _cursor_anillo: MeshInstance3D = null
var _cursor_mat: StandardMaterial3D = null

var _puntos_rio_activo: Array[Vector3] = []
var _rio_activo: Node3D = null
var _ancho_rio_activo: float = 8.0

func _ready() -> void:
	_inicializar_contenedor()
	_asegurar_texturas_agua()
	_asegurar_cursor()

func _inicializar_contenedor() -> void:
	if not _contenedor_aguas or not is_instance_valid(_contenedor_aguas):
		_contenedor_aguas = Node3D.new()
		_contenedor_aguas.name = "ContenedorCuerposAgua"
		add_child(_contenedor_aguas)

func _asegurar_texturas_agua() -> void:
	if _tex_normal1 and _tex_normal2:
		return
	var n1 := FastNoiseLite.new()
	n1.seed = 101
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.045
	n1.fractal_octaves = 4
	var img1: Image = n1.get_seamless_image(256, 256, false, false)
	img1.bump_map_to_normal_map(2.2)
	img1.generate_mipmaps()
	_tex_normal1 = ImageTexture.create_from_image(img1)

	var n2 := FastNoiseLite.new()
	n2.seed = 307
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.frequency = 0.075
	n2.fractal_octaves = 3
	var img2: Image = n2.get_seamless_image(256, 256, false, false)
	img2.bump_map_to_normal_map(1.8)
	img2.generate_mipmaps()
	_tex_normal2 = ImageTexture.create_from_image(img2)

func _crear_material_agua(es_rio: bool) -> ShaderMaterial:
	_asegurar_texturas_agua()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_AGUA
	mat.set_shader_parameter("textura_normal1", _tex_normal1)
	mat.set_shader_parameter("textura_normal2", _tex_normal2)
	mat.set_shader_parameter("color_orilla", Color(0.14, 0.44, 0.42, 0.58) if es_rio else Color(0.12, 0.42, 0.45, 0.52))
	mat.set_shader_parameter("color_profundo", Color(0.04, 0.16, 0.22, 0.94) if es_rio else Color(0.02, 0.12, 0.22, 0.95))
	mat.set_shader_parameter("color_espuma", Color(0.95, 0.98, 1.0, 0.95))
	mat.set_shader_parameter("fuerza_normal", 0.9)
	mat.set_shader_parameter("rugosidad", 0.06)
	mat.set_shader_parameter("metalico", 0.04)
	mat.set_shader_parameter("velocidad_olas", 1.6 if es_rio else 0.9)
	mat.set_shader_parameter("altura_olas", 0.05 if es_rio else 0.07)
	return mat

func _asegurar_cursor() -> void:
	if is_instance_valid(_cursor_agua):
		return
	_cursor_agua = Node3D.new()
	_cursor_agua.name = "CursorAgua"
	_cursor_mat = StandardMaterial3D.new()
	_cursor_mat.albedo_color = Color(0.18, 0.78, 0.95, 0.45)
	_cursor_mat.emission_enabled = true
	_cursor_mat.emission = Color(0.15, 0.72, 0.95)
	_cursor_mat.emission_energy_multiplier = 1.2
	_cursor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_cursor_anillo = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.25
	cyl.radial_segments = 40
	_cursor_anillo.mesh = cyl
	_cursor_anillo.material_override = _cursor_mat
	_cursor_agua.add_child(_cursor_anillo)
	_cursor_agua.visible = false
	add_child(_cursor_agua)

func actualizar_cursor_agua(pos_mundo: Vector3, visible_flag: bool, subherramienta: String, radio: float = 24.0) -> void:
	_asegurar_cursor()
	_cursor_agua.visible = visible_flag
	if not visible_flag:
		return
	_cursor_agua.global_position = pos_mundo + Vector3(0.0, 0.20, 0.0)
	var r_vis: float = radio
	var col := Color(0.18, 0.78, 0.95, 0.40)
	if subherramienta == "cuenca":
		col = Color(0.88, 0.65, 0.22, 0.40)
	elif subherramienta in ["rio", "rio_agua"]:
		r_vis = maxf(2.0, radio * 0.5)
		col = Color(0.20, 0.88, 0.75, 0.48)
	elif subherramienta == "nivel":
		r_vis = 6.0
		col = Color(0.35, 0.85, 0.98, 0.50)
	elif subherramienta == "limpiar":
		r_vis = 8.0
		col = Color(0.95, 0.30, 0.28, 0.48)
	_cursor_mat.albedo_color = col
	_cursor_mat.emission = Color(col.r, col.g, col.b)
	_cursor_anillo.scale = Vector3(r_vis, 1.0, r_vis)

func _crear_malla_lago_circular(radio: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGS := 40
	const RINGS := 8
	for r_i in range(RINGS):
		var r0 := radio * float(r_i) / float(RINGS)
		var r1 := radio * float(r_i + 1) / float(RINGS)
		for s_i in range(SEGS):
			var a0 := TAU * float(s_i) / float(SEGS)
			var a1 := TAU * float(s_i + 1) / float(SEGS)
			var p00 := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var p10 := Vector3(cos(a0) * r1, 0.0, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
			var p01 := Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var uv00 := Vector2(p00.x, p00.z) / maxf(radio * 2.0, 1.0) + Vector2(0.5, 0.5)
			var uv10 := Vector2(p10.x, p10.z) / maxf(radio * 2.0, 1.0) + Vector2(0.5, 0.5)
			var uv11 := Vector2(p11.x, p11.z) / maxf(radio * 2.0, 1.0) + Vector2(0.5, 0.5)
			var uv01 := Vector2(p01.x, p01.z) / maxf(radio * 2.0, 1.0) + Vector2(0.5, 0.5)
			st.set_normal(Vector3.UP); st.set_uv(uv00); st.add_vertex(p00)
			st.set_normal(Vector3.UP); st.set_uv(uv10); st.add_vertex(p10)
			st.set_normal(Vector3.UP); st.set_uv(uv11); st.add_vertex(p11)
			st.set_normal(Vector3.UP); st.set_uv(uv00); st.add_vertex(p00)
			st.set_normal(Vector3.UP); st.set_uv(uv11); st.add_vertex(p11)
			st.set_normal(Vector3.UP); st.set_uv(uv01); st.add_vertex(p01)
	return st.commit()

func crear_lago(pos_mundo: Vector3, radio: float = 24.0, profundidad: float = 3.5, es_circular: bool = true, excavar: bool = true) -> Node3D:
	_inicializar_contenedor()
	_contador_aguas += 1

	var nivel_agua: Vector3 = pos_mundo
	if excavar and profundidad > 0.4:
		deprimir_terreno_bajo_lago(pos_mundo, radio, profundidad)
		nivel_agua.y = pos_mundo.y - minf(0.35, profundidad * 0.18)

	var lago_root := Node3D.new()
	lago_root.name = "Lago_%d" % _contador_aguas
	_contenedor_aguas.add_child(lago_root)
	if lago_root.is_inside_tree():
		lago_root.global_position = nivel_agua
	else:
		lago_root.position = nivel_agua
	lago_root.set_meta("tipo_cuerpo", TipoAgua.LAGO_CIRCULAR if es_circular else TipoAgua.LAGO_RECTANGULAR)
	lago_root.set_meta("radio", radio)
	lago_root.set_meta("profundidad", profundidad)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SuperficieAgua"
	if es_circular:
		mesh_inst.mesh = _crear_malla_lago_circular(radio)
	else:
		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = Vector2(radio * 2.0, radio * 2.0)
		plane_mesh.subdivide_width = 16
		plane_mesh.subdivide_depth = 16
		mesh_inst.mesh = plane_mesh
	mesh_inst.material_override = _crear_material_agua(false)
	lago_root.add_child(mesh_inst)

	var area := Area3D.new()
	area.name = "AreaAgua"
	area.add_to_group("area_agua")
	var col_shape := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(radio * 2.0, profundidad * 2.0, radio * 2.0)
	col_shape.shape = box_col
	col_shape.position = Vector3(0, -profundidad * 0.5, 0)
	area.add_child(col_shape)
	lago_root.add_child(area)

	cuerpo_seleccionado = lago_root
	cuerpo_agua_creado.emit(lago_root)
	return lago_root

func excavar_cuenca(pos_centro: Vector3, radio: float = 24.0, profundidad: float = 3.5) -> bool:
	return deprimir_terreno_bajo_lago(pos_centro, radio, profundidad)

func deprimir_terreno_bajo_lago(pos_centro: Vector3, radio: float, profundidad: float) -> bool:
	if not controlador_terreno or not controlador_terreno.get("terrain"):
		return false
	var terrain = controlador_terreno.terrain
	if not is_instance_valid(terrain) or not terrain.data:
		return false
	var t_data = terrain.data
	var vs: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var radio_ext: float = radio + maxf(6.0, radio * 0.35)
	var min_xz := Vector3(pos_centro.x - radio_ext, 0.0, pos_centro.z - radio_ext).snapped(Vector3(vs, 0.0, vs))
	var max_xz := Vector3(pos_centro.x + radio_ext, 0.0, pos_centro.z + radio_ext).snapped(Vector3(vs, 0.0, vs)) + Vector3(vs, 0.0, vs)

	var modificado := false
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var wp := Vector3(x, 0.0, z)
			if t_data.has_regionp(wp):
				var curr_h: float = t_data.get_height(wp)
				if not is_nan(curr_h):
					var d := Vector2(x - pos_centro.x, z - pos_centro.z).length()
					if d <= radio_ext:
						var target_h := curr_h
						if d <= radio * 0.72:
							target_h = minf(curr_h, pos_centro.y - profundidad)
						elif d <= radio_ext:
							var t := clampf((d - radio * 0.72) / maxf(radio_ext - radio * 0.72, 0.1), 0.0, 1.0)
							var s := t * t * (3.0 - 2.0 * t)
							var bowl_h := pos_centro.y - profundidad
							target_h = minf(curr_h, lerpf(bowl_h, curr_h, s))
						if absf(curr_h - target_h) > 0.02:
							t_data.set_height(wp, target_h)
							modificado = true
			z += vs
		x += vs

	if modificado:
		t_data.update_maps(0)
		t_data.calc_height_range()
		if controlador_terreno.has_signal("terreno_modificado"):
			controlador_terreno.terreno_modificado.emit()
	return modificado

func agregar_punto_rio(pos_mundo: Vector3, ancho: float = 8.0) -> int:
	_inicializar_contenedor()
	_ancho_rio_activo = ancho
	_puntos_rio_activo.append(pos_mundo + Vector3(0.0, 0.12, 0.0))
	if _puntos_rio_activo.size() >= 2:
		if is_instance_valid(_rio_activo):
			_actualizar_malla_rio(_rio_activo, _puntos_rio_activo, _ancho_rio_activo)
		else:
			_rio_activo = crear_tramo_rio(_puntos_rio_activo, _ancho_rio_activo)
		_deprimir_lecho_rio(_puntos_rio_activo, _ancho_rio_activo, 1.6)
	return _puntos_rio_activo.size()

func limpiar_trazo_rio() -> void:
	_puntos_rio_activo.clear()
	if is_instance_valid(_rio_activo):
		if cuerpo_seleccionado == _rio_activo:
			cuerpo_seleccionado = null
		_rio_activo.queue_free()
		_rio_activo = null

func finalizar_tramo_rio() -> bool:
	var tenia := _puntos_rio_activo.size() >= 2 or is_instance_valid(_rio_activo)
	_puntos_rio_activo.clear()
	_rio_activo = null
	return tenia

func _deprimir_lecho_rio(puntos: Array[Vector3], ancho: float, prof: float) -> void:
	if puntos.size() < 2 or not controlador_terreno or not controlador_terreno.get("terrain"):
		return
	var terrain = controlador_terreno.terrain
	if not is_instance_valid(terrain) or not terrain.data:
		return
	var t_data = terrain.data
	var vs: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var hw := ancho * 0.5
	var pad := hw + 4.0

	var min_x := puntos[0].x; var max_x := puntos[0].x
	var min_z := puntos[0].z; var max_z := puntos[0].z
	for p in puntos:
		min_x = minf(min_x, p.x); max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z); max_z = maxf(max_z, p.z)
	var min_xz := Vector3(min_x - pad, 0.0, min_z - pad).snapped(Vector3(vs, 0.0, vs))
	var max_xz := Vector3(max_x + pad, 0.0, max_z + pad).snapped(Vector3(vs, 0.0, vs)) + Vector3(vs, 0.0, vs)

	var modificado := false
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var wp := Vector3(x, 0.0, z)
			if t_data.has_regionp(wp):
				var curr_h: float = t_data.get_height(wp)
				if not is_nan(curr_h):
					var p2 := Vector2(x, z)
					var mejor_d := 999999.0
					var mejor_y := curr_h
					for i in range(puntos.size() - 1):
						var a2 := Vector2(puntos[i].x, puntos[i].z)
						var b2 := Vector2(puntos[i + 1].x, puntos[i + 1].z)
						var q := Geometry2D.get_closest_point_to_segment(p2, a2, b2)
						var d := p2.distance_to(q)
						if d < mejor_d:
							mejor_d = d
							var t := clampf(a2.distance_to(q) / maxf(a2.distance_to(b2), 0.001), 0.0, 1.0)
							mejor_y = lerpf(puntos[i].y, puntos[i + 1].y, t)
					if mejor_d <= hw + 3.5:
						var target_y := curr_h
						if mejor_d <= hw * 0.65:
							target_y = minf(curr_h, mejor_y - prof)
						else:
							var f := clampf((mejor_d - hw * 0.65) / maxf(hw * 0.35 + 3.5, 0.1), 0.0, 1.0)
							var s := f * f * (3.0 - 2.0 * f)
							target_y = minf(curr_h, lerpf(mejor_y - prof, curr_h, s))
						if absf(curr_h - target_y) > 0.02:
							t_data.set_height(wp, target_y)
							modificado = true
			z += vs
		x += vs
	if modificado:
		t_data.update_maps(0)
		t_data.calc_height_range()
		if controlador_terreno.has_signal("terreno_modificado"):
			controlador_terreno.terreno_modificado.emit()

func _actualizar_malla_rio(rio_root: Node3D, puntos_mundo: Array[Vector3], ancho: float) -> void:
	if puntos_mundo.size() < 2:
		return
	rio_root.set_meta("radio", ancho)
	rio_root.set_meta("ancho", ancho)
	rio_root.set_meta("puntos", puntos_mundo.duplicate())

	var mesh_inst := rio_root.get_node_or_null("SuperficieRio") as MeshInstance3D
	if not mesh_inst:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acum_dist := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in range(puntos_mundo.size()):
		var p := puntos_mundo[i] - rio_root.global_position
		var fwd := Vector3.FORWARD
		if i == 0:
			fwd = (puntos_mundo[1] - puntos_mundo[0])
		elif i == puntos_mundo.size() - 1:
			fwd = (puntos_mundo[i] - puntos_mundo[i - 1])
		else:
			fwd = (puntos_mundo[i + 1] - puntos_mundo[i - 1])
		fwd.y = 0.0
		if fwd.length_squared() < 0.0001:
			fwd = Vector3.FORWARD
		else:
			fwd = fwd.normalized()
		var lat := fwd.cross(Vector3.UP).normalized() * (ancho * 0.5)
		if i > 0:
			acum_dist += puntos_mundo[i].distance_to(puntos_mundo[i - 1])
		var v_coord := acum_dist / maxf(1.0, ancho)
		var cur_l := p - lat
		var cur_r := p + lat
		if i > 0:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, prev_v)); st.add_vertex(prev_l)
			st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, prev_v)); st.add_vertex(prev_r)
			st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, v_coord)); st.add_vertex(cur_r)
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, prev_v)); st.add_vertex(prev_l)
			st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, v_coord)); st.add_vertex(cur_r)
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, v_coord)); st.add_vertex(cur_l)
		prev_l = cur_l
		prev_r = cur_r
		prev_v = v_coord
	mesh_inst.mesh = st.commit()

func crear_tramo_rio(puntos_mundo: Array[Vector3], ancho: float = 8.0) -> Node3D:
	if puntos_mundo.size() < 2:
		return null
	_inicializar_contenedor()
	_contador_aguas += 1

	var rio_root := Node3D.new()
	rio_root.name = "Rio_%d" % _contador_aguas
	_contenedor_aguas.add_child(rio_root)
	rio_root.global_position = puntos_mundo[0]
	rio_root.set_meta("tipo_cuerpo", TipoAgua.RIO_TRAMO)
	rio_root.set_meta("ancho", ancho)
	rio_root.set_meta("radio", ancho)
	rio_root.set_meta("puntos", puntos_mundo.duplicate())

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SuperficieRio"
	mesh_inst.material_override = _crear_material_agua(true)
	rio_root.add_child(mesh_inst)
	_actualizar_malla_rio(rio_root, puntos_mundo, ancho)

	cuerpo_seleccionado = rio_root
	cuerpo_agua_creado.emit(rio_root)
	return rio_root

func seleccionar_cuerpo_cercano(pos_mundo: Vector3, radio_max: float = 40.0) -> Node3D:
	if not _contenedor_aguas:
		return null
	var mejor_dist := radio_max
	var mejor_cuerpo: Node3D = null
	var p2 := Vector2(pos_mundo.x, pos_mundo.z)
	for hijo in _contenedor_aguas.get_children():
		var node := hijo as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var tipo: int = int(node.get_meta("tipo_cuerpo", 0))
		var d := 999999.0
		if tipo == TipoAgua.RIO_TRAMO:
			var pts: Array = node.get_meta("puntos", [])
			var off_y: float = node.global_position.y - (pts[0].y if pts.size() > 0 else node.global_position.y)
			for i in range(pts.size() - 1):
				var a2 := Vector2(pts[i].x, pts[i].z)
				var b2 := Vector2(pts[i + 1].x, pts[i + 1].z)
				d = minf(d, p2.distance_to(Geometry2D.get_closest_point_to_segment(p2, a2, b2)))
			var ancho_r := float(node.get_meta("ancho", 8.0))
			if d <= ancho_r * 0.75 + 4.0 and d < mejor_dist:
				mejor_dist = d
				mejor_cuerpo = node
		else:
			var rad := float(node.get_meta("radio", 24.0))
			d = p2.distance_to(Vector2(node.global_position.x, node.global_position.z))
			if d <= rad + 6.0 and d < mejor_dist:
				mejor_dist = d
				mejor_cuerpo = node
	cuerpo_seleccionado = mejor_cuerpo
	return mejor_cuerpo

func modificar_nivel_agua(delta_y: float) -> float:
	if cuerpo_seleccionado and is_instance_valid(cuerpo_seleccionado):
		cuerpo_seleccionado.global_position.y += delta_y
		cuerpo_agua_modificado.emit(cuerpo_seleccionado)
		return cuerpo_seleccionado.global_position.y
	return 0.0

func borrar_agua_en_posicion(pos_mundo: Vector3) -> bool:
	var c := seleccionar_cuerpo_cercano(pos_mundo, 60.0)
	if not c:
		return false
	return eliminar_cuerpo_seleccionado()

func eliminar_cuerpo_seleccionado() -> bool:
	if cuerpo_seleccionado and is_instance_valid(cuerpo_seleccionado):
		var target := cuerpo_seleccionado
		if target == _rio_activo:
			_rio_activo = null
			_puntos_rio_activo.clear()
		cuerpo_seleccionado = null
		cuerpo_agua_eliminado.emit(target)
		target.queue_free()
		return true
	return false

func limpiar_todo_agua() -> void:
	cuerpo_seleccionado = null
	_rio_activo = null
	_puntos_rio_activo.clear()
	if _contenedor_aguas:
		for hijo in _contenedor_aguas.get_children():
			hijo.queue_free()

func serializar_aguas() -> Array:
	var lista: Array = []
	if not _contenedor_aguas:
		return lista
	for hijo in _contenedor_aguas.get_children():
		var node := hijo as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var tipo: int = int(node.get_meta("tipo_cuerpo", 0))
		var radio: float = float(node.get_meta("radio", 20.0))
		var prof: float = float(node.get_meta("profundidad", 3.0))
		var puntos: Array = node.get_meta("puntos", [])
		var p_ser: Array = []
		for p in puntos:
			p_ser.append([p.x, p.y, p.z])
		var p_pos: Vector3 = node.global_position if node.is_inside_tree() else node.position
		lista.append({
			"tipo": tipo,
			"posicion": [p_pos.x, p_pos.y, p_pos.z],
			"radio": radio,
			"profundidad": prof,
			"puntos": p_ser
		})
	return lista

func deserializar_aguas(lista: Array) -> void:
	limpiar_todo_agua()
	for it in lista:
		var tipo: int = int(it.get("tipo", 0))
		var pos_arr = it.get("posicion", [0, 0, 0])
		var pos := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		var rad: float = float(it.get("radio", 20.0))
		var prof: float = float(it.get("profundidad", 3.0))
		if tipo == TipoAgua.RIO_TRAMO:
			var pts_arr = it.get("puntos", [])
			var pts: Array[Vector3] = []
			for p in pts_arr:
				pts.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
			if pts.size() >= 2:
				var rio := crear_tramo_rio(pts, rad)
				if rio:
					rio.global_position.y = pos.y
		else:
			crear_lago(pos, rad, prof, tipo == TipoAgua.LAGO_CIRCULAR, false)
