class_name ControladorObjetos
extends Node3D

const GeneradorModelosCiudad = preload("res://mundo/editor_mapas/GeneradorModelosCiudad.gd")

## ControladorObjetos.gd — Gestor de colocación, rotación, ajuste de cuadrícula y demolición
## de edificios, árboles y mobiliario urbano estilo Cities: Skylines.

signal objeto_colocado(objeto: Node3D)
signal objeto_demolido(posicion: Vector3)
signal lista_objetos_actualizada(cantidad: int)
signal objeto_seleccionado_cambiado(hay_seleccion: bool, datos: Dictionary)

@export var snap_cuadricula_activo: bool = false
@export var snap_carretera_activo: bool = true
@export var tamano_cuadricula: float = 4.0
@export var rotacion_actual_grados: float = 0.0
var controlador_carreteras = null

var id_objeto_seleccionado: String = "casa_suburbana"
var config_casa_modular_actual: Dictionary = DatosCasaModular.crear_config_defecto()
var modo_demolicion: bool = false
var modo_auto_casas: bool = false
var radio_auto_casas: float = 35.0
var objeto_seleccionado: Node3D = null

var _contenedor_objetos: Node3D
var _preview_fantasma: Node3D
var _marcador_demolicion: MeshInstance3D = null
var _caja_delimitadora: Node3D = null
var _mesh_caja_solida: MeshInstance3D = null
var _mesh_caja_lineas: MeshInstance3D = null
var _flechas_gizmo: Array[Dictionary] = [] # {"nodo": Node3D, "eje_local": Vector3, "mat": StandardMaterial3D}
var _objetos_en_escena: Array[Node3D] = []
var _objeto_resaltado_demolicion: Node3D = null
var _preview_anillo_dispersion: MeshInstance3D = null

# ── PINCEL DISPERSOR DE VEGETACIÓN (MULTIMESH SCATTER BRUSH) ─────────
var modo_pincel_dispersion: bool = false
var radio_pincel_dispersion: float = 14.0
var densidad_pincel_dispersion: int = 4
var controlador_terreno: Node = null
var _contenedor_multimesh: Node3D = null
var _multimeshes_por_modelo: Dictionary = {} # id_modelo -> MultiMeshInstance3D
var _transforms_por_modelo: Dictionary = {}  # id_modelo -> Array[Transform3D]
var _base_transforms_por_modelo: Dictionary = {} # id_modelo -> Transform3D

func _ready() -> void:
	_contenedor_objetos = Node3D.new()
	_contenedor_objetos.name = "ContenedorObjetos_Editor"
	add_child(_contenedor_objetos)
	
	_contenedor_multimesh = Node3D.new()
	_contenedor_multimesh.name = "ContenedorMultiMesh_Vegetacion"
	add_child(_contenedor_multimesh)
	
	_crear_preview_fantasma()
	_crear_marcador_demolicion()
	_crear_anillo_dispersion()
	_crear_nodo_caja_delimitadora()

func _crear_anillo_dispersion() -> void:
	_preview_anillo_dispersion = MeshInstance3D.new()
	_preview_anillo_dispersion.name = "PreviewAnilloDispersion"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	_preview_anillo_dispersion.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.68, 0.28, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_anillo_dispersion.material_override = mat
	_preview_anillo_dispersion.scale = Vector3(radio_pincel_dispersion, 1.0, radio_pincel_dispersion)
	_preview_anillo_dispersion.visible = false
	add_child(_preview_anillo_dispersion)

func _crear_marcador_demolicion() -> void:
	_marcador_demolicion = MeshInstance3D.new()
	_marcador_demolicion.name = "MarcadorDemolicion"
	var torus := TorusMesh.new()
	torus.inner_radius = 3.6
	torus.outer_radius = 4.0
	torus.rings = 36
	torus.ring_segments = 6
	_marcador_demolicion.mesh = torus
	
	var mat_demo := StandardMaterial3D.new()
	mat_demo.albedo_color = Color(0.78, 0.28, 0.26, 0.85) # Technical Crimson
	mat_demo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_demo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marcador_demolicion.material_override = mat_demo
	_marcador_demolicion.visible = false
	add_child(_marcador_demolicion)

func seleccionar_objeto(id_modelo: String) -> void:
	if id_modelo in ["", "rotar", "snap", "grid", "dispersion", "borrar", "catalogo", "demoler", "mover", "res", "com", "inst", "hist", "ind"]:
		return
	modo_demolicion = false
	id_objeto_seleccionado = id_modelo
	_recrear_preview_fantasma()

func establecer_config_casa_modular(cfg: Dictionary) -> void:
	config_casa_modular_actual = DatosCasaModular.normalizar_config(cfg)
	modo_demolicion = false
	id_objeto_seleccionado = "casa_modular"
	_recrear_preview_fantasma()

func aplicar_config_a_casa_seleccionada(cfg: Dictionary) -> bool:
	if objeto_seleccionado and is_instance_valid(objeto_seleccionado) and objeto_seleccionado.get_meta("es_casa_modular", false):
		GeneradorCasaModular.reconstruir_casa(objeto_seleccionado, cfg)
		_actualizar_caja_delimitadora(_calcular_aabb_objeto(objeto_seleccionado))
		return true
	return false

func _instanciar_modelo_actual() -> Node3D:
	if id_objeto_seleccionado == "casa_modular":
		return GeneradorCasaModular.crear_casa(config_casa_modular_actual)
	return GeneradorModelosCiudad.crear_instancia_objeto(id_objeto_seleccionado)

func alternar_demolicion() -> void:
	modo_demolicion = not modo_demolicion
	if modo_demolicion:
		if _preview_fantasma:
			_preview_fantasma.visible = false
	else:
		if _preview_fantasma:
			_preview_fantasma.visible = true

func rotar_objeto(paso_grados: float = 45.0) -> void:
	rotacion_actual_grados = fmod(rotacion_actual_grados + paso_grados, 360.0)
	if is_instance_valid(objeto_seleccionado):
		rotar_objeto_seleccionado(paso_grados)
	elif _preview_fantasma:
		_preview_fantasma.rotation_degrees.y = rotacion_actual_grados

func alternar_snap_cuadricula() -> bool:
	snap_cuadricula_activo = not snap_cuadricula_activo
	return snap_cuadricula_activo

func calcular_posicion_snap(pos_mundo: Vector3) -> Vector3:
	return calcular_transform_snap(pos_mundo)["pos"]

func calcular_transform_snap(pos_mundo: Vector3) -> Dictionary:
	var res := pos_mundo
	var rot_y := rotacion_actual_grados
	var snapped_via := false
	if snap_carretera_activo and controlador_carreteras and controlador_carreteras.get("road_container") and is_instance_valid(controlador_carreteras.road_container):
		var rc = controlador_carreteras.road_container
		var mejor_d := 16.0
		var mejor_pos := Vector3.ZERO
		var mejor_tan := Vector3.FORWARD
		var mejor_ancho := 8.8
		for seg_obj in rc.get_segments():
			var seg := seg_obj as Node3D
			if not is_instance_valid(seg):
				continue
			var curve := seg.get("curve") as Curve3D
			if not curve:
				continue
			var loc := seg.to_local(pos_mundo) if seg.is_inside_tree() else (pos_mundo - seg.position)
			var off: float = curve.get_closest_offset(loc)
			var pt_loc: Vector3 = curve.sample_baked(off)
			var pt_w: Vector3 = seg.to_global(pt_loc) if seg.is_inside_tree() else (seg.position + pt_loc)
			var d := Vector2(pos_mundo.x - pt_w.x, pos_mundo.z - pt_w.z).length()
			if d < mejor_d:
				mejor_d = d
				mejor_pos = pt_w
				var eps := clampf(off + 0.5, 0.0, curve.get_baked_length())
				var pt2_loc: Vector3 = curve.sample_baked(eps)
				var pt2_w: Vector3 = seg.to_global(pt2_loc) if seg.is_inside_tree() else (seg.position + pt2_loc)
				var t_dir: Vector3 = pt2_w - pt_w
				t_dir.y = 0.0
				if t_dir.length_squared() < 0.001 and off > 0.5:
					var pt0_loc: Vector3 = curve.sample_baked(off - 0.5)
					var pt0_w: Vector3 = seg.to_global(pt0_loc) if seg.is_inside_tree() else (seg.position + pt0_loc)
					t_dir = pt_w - pt0_w
					t_dir.y = 0.0
				mejor_tan = t_dir.normalized() if t_dir.length_squared() > 0.0001 else Vector3.FORWARD
				var sp = seg.get("start_point")
				if controlador_carreteras.has_method("_obtener_ancho_via_punto") and sp != null and is_instance_valid(sp):
					mejor_ancho = float(controlador_carreteras._obtener_ancho_via_punto(sp))
				snapped_via = true
		if snapped_via:
			var lado := Vector2(pos_mundo.x - mejor_pos.x, pos_mundo.z - mejor_pos.z)
			var lat_r := Vector3(-mejor_tan.z, 0.0, mejor_tan.x)
			var signo := 1.0 if lado.dot(Vector2(lat_r.x, lat_r.z)) >= 0.0 else -1.0
			var min_retiro := 6.5
			if is_instance_valid(_preview_fantasma):
				var aabb_p := _calcular_aabb_objeto(_preview_fantasma)
				min_retiro = maxf(6.5, aabb_p.size.z * 0.55 + 2.8)
			var dist_borde := maxf(mejor_ancho * 0.5 + min_retiro, minf(mejor_d, mejor_ancho * 0.5 + min_retiro + 3.5))
			res = Vector3(mejor_pos.x + lat_r.x * signo * dist_borde, pos_mundo.y, mejor_pos.z + lat_r.z * signo * dist_borde)
			if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
				res.y = float(controlador_terreno.obtener_altura(res))
			var dir_hacia_via := -lat_r * signo
			rot_y = rad_to_deg(atan2(dir_hacia_via.x, dir_hacia_via.z))
			return {"pos": res, "rot_y": rot_y, "snapped_via": true}
	if snap_cuadricula_activo:
		res.x = round(pos_mundo.x / tamano_cuadricula) * tamano_cuadricula
		res.z = round(pos_mundo.z / tamano_cuadricula) * tamano_cuadricula
	return {"pos": res, "rot_y": rot_y, "snapped_via": false}

func _crear_nodo_caja_delimitadora() -> void:
	_caja_delimitadora = Node3D.new()
	_caja_delimitadora.name = "CajaDelimitadora_Editor"
	_caja_delimitadora.visible = false
	
	_mesh_caja_lineas = MeshInstance3D.new()
	_mesh_caja_lineas.name = "CajaLineas"
	var mat_lineas := StandardMaterial3D.new()
	mat_lineas.albedo_color = Color(0.95, 0.78, 0.35, 0.95) # Amber brillante bordes
	mat_lineas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_caja_lineas.material_override = mat_lineas
	_caja_delimitadora.add_child(_mesh_caja_lineas)
	
	_crear_flechas_gizmo()
	add_child(_caja_delimitadora)

func _crear_flechas_gizmo() -> void:
	_flechas_gizmo.clear()
	var definiciones := [
		{"nombre": "FlechaPosX", "eje": Vector3(1, 0, 0), "color": Color(0.95, 0.34, 0.28, 1.0)},
		{"nombre": "FlechaNegX", "eje": Vector3(-1, 0, 0), "color": Color(0.95, 0.34, 0.28, 1.0)},
		{"nombre": "FlechaPosY", "eje": Vector3(0, 1, 0), "color": Color(0.32, 0.88, 0.42, 1.0)},
		{"nombre": "FlechaNegY", "eje": Vector3(0, -1, 0), "color": Color(0.32, 0.88, 0.42, 1.0)},
		{"nombre": "FlechaPosZ", "eje": Vector3(0, 0, 1), "color": Color(0.28, 0.74, 0.98, 1.0)},
		{"nombre": "FlechaNegZ", "eje": Vector3(0, 0, -1), "color": Color(0.28, 0.74, 0.98, 1.0)}
	]
	for def in definiciones:
		var nodo_f := Node3D.new()
		nodo_f.name = def["nombre"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def["color"]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 4

		# Asta de la flecha (eje +Y local, luego rotada hacia def["eje"])
		var mi_asta := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.22
		cyl.height = 2.4
		mi_asta.mesh = cyl
		mi_asta.position = Vector3(0, 1.2, 0)
		mi_asta.material_override = mat
		nodo_f.add_child(mi_asta)

		# Punta cónica de la flecha
		var mi_punta := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.62
		cono.height = 1.25
		mi_punta.mesh = cono
		mi_punta.position = Vector3(0, 2.85, 0)
		mi_punta.material_override = mat
		nodo_f.add_child(mi_punta)

		# Orientar +Y hacia la dirección del eje
		var eje: Vector3 = def["eje"]
		if eje.is_equal_approx(Vector3(1, 0, 0)):
			nodo_f.rotation_degrees = Vector3(0, 0, -90)
		elif eje.is_equal_approx(Vector3(-1, 0, 0)):
			nodo_f.rotation_degrees = Vector3(0, 0, 90)
		elif eje.is_equal_approx(Vector3(0, -1, 0)):
			nodo_f.rotation_degrees = Vector3(180, 0, 0)
		elif eje.is_equal_approx(Vector3(0, 0, 1)):
			nodo_f.rotation_degrees = Vector3(90, 0, 0)
		elif eje.is_equal_approx(Vector3(0, 0, -1)):
			nodo_f.rotation_degrees = Vector3(-90, 0, 0)

		_caja_delimitadora.add_child(nodo_f)
		_flechas_gizmo.append({"nodo": nodo_f, "eje_local": eje, "mat": mat})

func _calcular_aabb_objeto(obj: Node3D) -> AABB:
	var aabb_total := AABB()
	var primera := true
	for hijo in obj.find_children("*", "MeshInstance3D"):
		var mi := hijo as MeshInstance3D
		if mi and mi.mesh:
			var mesh_aabb = mi.mesh.get_aabb()
			var xf = obj.global_transform.affine_inverse() * mi.global_transform
			var aabb_trans = xf * mesh_aabb
			if primera:
				aabb_total = aabb_trans
				primera = false
			else:
				aabb_total = aabb_total.merge(aabb_trans)
	if primera:
		aabb_total = AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 3.5, 4.0))
	return aabb_total

func _actualizar_caja_delimitadora(aabb: AABB) -> void:
	if not _caja_delimitadora or not is_instance_valid(objeto_seleccionado):
		return
	
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var margen := 0.45
	var x0 = aabb.position.x - margen
	var x1 = aabb.end.x + margen
	var z0 = aabb.position.z - margen
	var z1 = aabb.end.z + margen
	var y_base = minf(aabb.position.y, 0.0) + 0.12
	var y_top = maxf(aabb.end.y, 2.5) + 0.35
	
	var p0 = Vector3(x0, y_base, z0)
	var p1 = Vector3(x1, y_base, z0)
	var p2 = Vector3(x1, y_base, z1)
	var p3 = Vector3(x0, y_base, z1)
	
	var t0 = Vector3(x0, y_top, z0)
	var t1 = Vector3(x1, y_top, z0)
	var t2 = Vector3(x1, y_top, z1)
	var t3 = Vector3(x0, y_top, z1)
	
	# Base inferior
	im.surface_add_vertex(p0); im.surface_add_vertex(p1)
	im.surface_add_vertex(p1); im.surface_add_vertex(p2)
	im.surface_add_vertex(p2); im.surface_add_vertex(p3)
	im.surface_add_vertex(p3); im.surface_add_vertex(p0)
	
	# Tapa superior
	im.surface_add_vertex(t0); im.surface_add_vertex(t1)
	im.surface_add_vertex(t1); im.surface_add_vertex(t2)
	im.surface_add_vertex(t2); im.surface_add_vertex(t3)
	im.surface_add_vertex(t3); im.surface_add_vertex(t0)
	
	# 4 Aristas verticales completas de la caja delimitadora
	im.surface_add_vertex(p0); im.surface_add_vertex(t0)
	im.surface_add_vertex(p1); im.surface_add_vertex(t1)
	im.surface_add_vertex(p2); im.surface_add_vertex(t2)
	im.surface_add_vertex(p3); im.surface_add_vertex(t3)
	
	im.surface_end()
	_mesh_caja_lineas.mesh = im
	_mesh_caja_lineas.position = Vector3.ZERO
	
	_caja_delimitadora.global_position = objeto_seleccionado.global_position
	_caja_delimitadora.rotation_degrees.y = objeto_seleccionado.rotation_degrees.y
	_caja_delimitadora.visible = true

	# Posicionar las 4 flechas justo por el borde exterior de la caja delimitadora
	var y_flecha: float = clampf(aabb.size.y * 0.25, 0.85, 2.2)
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	var sep_borde: float = 0.45
	for f in _flechas_gizmo:
		var nodo_f: Node3D = f["nodo"]
		var eje: Vector3 = f["eje_local"]
		if eje.x > 0.5:
			nodo_f.position = Vector3(x1 + sep_borde, y_flecha, cz)
		elif eje.x < -0.5:
			nodo_f.position = Vector3(x0 - sep_borde, y_flecha, cz)
		elif eje.y > 0.5:
			nodo_f.position = Vector3(cx, aabb.end.y + margen + sep_borde, cz)
		elif eje.y < -0.5:
			nodo_f.position = Vector3(cx, aabb.position.y - margen - sep_borde, cz)
		elif eje.z > 0.5:
			nodo_f.position = Vector3(cx, y_flecha, z1 + sep_borde)
		elif eje.z < -0.5:
			nodo_f.position = Vector3(cx, y_flecha, z0 - sep_borde)

func detectar_flecha_gizmo_por_rayo(ray_origen: Vector3, ray_dir: Vector3) -> Vector3:
	if not _caja_delimitadora or not _caja_delimitadora.visible or not is_instance_valid(objeto_seleccionado):
		return Vector3.ZERO
	var mejor_eje := Vector3.ZERO
	var menor_dist_cam: float = INF
	for f in _flechas_gizmo:
		var nodo_f: Node3D = f["nodo"]
		var eje_local: Vector3 = f["eje_local"]
		var eje_mundo := (_caja_delimitadora.global_transform.basis * eje_local).normalized()
		var centro_flecha := nodo_f.global_position + eje_mundo * 1.5
		var aabb_f := AABB(centro_flecha - Vector3(1.8, 1.8, 1.8), Vector3(3.6, 3.6, 3.6))
		var hit = aabb_f.intersects_ray(ray_origen, ray_dir)
		if hit != null:
			var d_cam := ray_origen.distance_squared_to(hit)
			if d_cam < menor_dist_cam:
				menor_dist_cam = d_cam
				mejor_eje = eje_mundo
	return mejor_eje

func mover_objeto_en_eje(obj: Node3D, pos_origen: Vector3, eje_mundo: Vector3, pos_terreno: Vector3) -> void:
	if not is_instance_valid(obj):
		return
	if absf(eje_mundo.y) > 0.5:
		var nueva_y: float = pos_terreno.y
		var pos_f := Vector3(pos_origen.x, nueva_y, pos_origen.z)
		obj.global_position = pos_f
		if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
			var h_terr: float = controlador_terreno.obtener_altura(pos_f)
			obj.set_meta("offset_y", nueva_y - h_terr)
		if obj == objeto_seleccionado and _caja_delimitadora:
			_caja_delimitadora.global_position = pos_f
		return
	var eje_xz := Vector3(eje_mundo.x, 0.0, eje_mundo.z).normalized()
	if eje_xz.length_squared() < 0.001:
		return
	var delta_xz := Vector3(pos_terreno.x - pos_origen.x, 0.0, pos_terreno.z - pos_origen.z)
	var proyeccion: float = delta_xz.dot(eje_xz)
	var pos_objetivo := pos_origen + eje_xz * proyeccion
	mover_objeto(obj, pos_objetivo)

func seleccionar_objeto_en_escena(obj: Node3D) -> Dictionary:
	if not is_instance_valid(obj):
		deseleccionar_objeto()
		return {}
		
	objeto_seleccionado = obj
	rotacion_actual_grados = obj.rotation_degrees.y
	if _preview_fantasma:
		_preview_fantasma.visible = false
		
	var aabb = _calcular_aabb_objeto(obj)
	_actualizar_caja_delimitadora(aabb)
	
	var datos = obtener_datos_objeto_seleccionado()
	objeto_seleccionado_cambiado.emit(true, datos)
	return datos

func deseleccionar_objeto() -> void:
	objeto_seleccionado = null
	if _caja_delimitadora:
		_caja_delimitadora.visible = false
	objeto_seleccionado_cambiado.emit(false, {})

func obtener_datos_objeto_seleccionado() -> Dictionary:
	if not is_instance_valid(objeto_seleccionado):
		return {}
	var id_mod = objeto_seleccionado.get_meta("id_modelo", id_objeto_seleccionado)
	return {
		"id": id_mod,
		"nombre": id_mod.replace("_", " ").capitalize(),
		"posicion": objeto_seleccionado.global_position,
		"rotacion_y": objeto_seleccionado.rotation_degrees.y,
		"rotacion_z": objeto_seleccionado.rotation_degrees.z,
		"offset_y": float(objeto_seleccionado.get_meta("offset_y", 0.0))
	}

func rotar_objeto_seleccionado(delta_grados: float) -> float:
	if not is_instance_valid(objeto_seleccionado):
		return 0.0
	var nuevo_ang = fmod(objeto_seleccionado.rotation_degrees.y + delta_grados, 360.0)
	if nuevo_ang < 0.0:
		nuevo_ang += 360.0
	objeto_seleccionado.rotation_degrees.y = nuevo_ang
	rotacion_actual_grados = nuevo_ang
	if _caja_delimitadora:
		_caja_delimitadora.rotation_degrees.y = nuevo_ang
	return nuevo_ang

func establecer_rotacion_objeto_seleccionado(grados: float) -> float:
	if not is_instance_valid(objeto_seleccionado):
		return 0.0
	var ang = fmod(grados, 360.0)
	if ang < 0.0:
		ang += 360.0
	objeto_seleccionado.rotation_degrees.y = ang
	rotacion_actual_grados = ang
	if _caja_delimitadora:
		_caja_delimitadora.rotation_degrees.y = ang
	return ang

func establecer_inclinacion_objeto_seleccionado(grados: float) -> float:
	if not is_instance_valid(objeto_seleccionado):
		return 0.0
	var ang := clampf(grados, -90.0, 90.0)
	objeto_seleccionado.rotation_degrees.z = ang
	return ang

func modificar_altura_objeto_seleccionado(delta_y: float) -> float:
	if not is_instance_valid(objeto_seleccionado):
		return 0.0
	var off_actual = float(objeto_seleccionado.get_meta("offset_y", 0.0))
	off_actual = clamp(off_actual + delta_y, -10.0, 50.0)
	objeto_seleccionado.set_meta("offset_y", off_actual)
	objeto_seleccionado.global_position.y += delta_y
	if _caja_delimitadora:
		_caja_delimitadora.global_position.y = objeto_seleccionado.global_position.y
	return off_actual

func establecer_altura_offset_seleccionado(nuevo_offset: float) -> float:
	if not is_instance_valid(objeto_seleccionado):
		return 0.0
	var off_prev = float(objeto_seleccionado.get_meta("offset_y", 0.0))
	var delta = nuevo_offset - off_prev
	return modificar_altura_objeto_seleccionado(delta)

func reemplazar_objeto_seleccionado(nuevo_id: String = "") -> Node3D:
	if not is_instance_valid(objeto_seleccionado):
		return null
	var obj_viejo = objeto_seleccionado
	var id_reemplazo = nuevo_id if not nuevo_id.is_empty() else id_objeto_seleccionado
	var pos = obj_viejo.global_position
	var rot_y = obj_viejo.rotation_degrees.y
	var off_y = float(obj_viejo.get_meta("offset_y", 0.0))
	
	_objetos_en_escena.erase(obj_viejo)
	obj_viejo.queue_free()
	
	var nuevo_obj = GeneradorModelosCiudad.crear_instancia_objeto(id_reemplazo)
	_contenedor_objetos.add_child(nuevo_obj)
	nuevo_obj.global_position = pos
	nuevo_obj.rotation_degrees.y = rot_y
	nuevo_obj.set_meta("offset_y", off_y)
	nuevo_obj.set_meta("es_objeto_ciudad", true)
	_objetos_en_escena.append(nuevo_obj)
	
	seleccionar_objeto_en_escena(nuevo_obj)
	lista_objetos_actualizada.emit(_objetos_en_escena.size())
	return nuevo_obj

func eliminar_objeto_seleccionado() -> bool:
	if not is_instance_valid(objeto_seleccionado):
		return false
	var obj = objeto_seleccionado
	var pos = obj.global_position
	deseleccionar_objeto()
	_objetos_en_escena.erase(obj)
	obj.queue_free()
	objeto_demolido.emit(pos)
	lista_objetos_actualizada.emit(_objetos_en_escena.size())
	return true

func mover_objeto(obj: Node3D, pos_mundo: Vector3) -> void:
	if not is_instance_valid(obj):
		return
	var pos_final = calcular_posicion_snap(pos_mundo)
	if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
		pos_final.y = controlador_terreno.obtener_altura(pos_final)
	var off_y = float(obj.get_meta("offset_y", 0.0))
	pos_final.y += off_y
	obj.global_position = pos_final
	if obj == objeto_seleccionado and _caja_delimitadora:
		_caja_delimitadora.global_position = pos_final

func actualizar_cursor_objeto(pos_mundo: Vector3, visible_en_pantalla: bool) -> void:
	if is_instance_valid(objeto_seleccionado):
		if _preview_fantasma:
			_preview_fantasma.visible = false
		if _preview_anillo_dispersion:
			_preview_anillo_dispersion.visible = false
		if _marcador_demolicion:
			_marcador_demolicion.visible = false
		return
		
	if modo_demolicion:
		if _preview_fantasma:
			_preview_fantasma.visible = false
		if _preview_anillo_dispersion:
			_preview_anillo_dispersion.visible = false
		if _marcador_demolicion:
			_marcador_demolicion.visible = visible_en_pantalla
			if visible_en_pantalla:
				_marcador_demolicion.global_position = pos_mundo + Vector3(0, 0.15, 0)
		return
		
	if _marcador_demolicion:
		_marcador_demolicion.visible = false

	if _preview_anillo_dispersion:
		_preview_anillo_dispersion.visible = visible_en_pantalla and (modo_pincel_dispersion or modo_auto_casas)
		if _preview_anillo_dispersion.visible:
			_preview_anillo_dispersion.global_position = pos_mundo + Vector3(0, 0.25, 0)
			var r_anillo := radio_auto_casas if modo_auto_casas else radio_pincel_dispersion
			_preview_anillo_dispersion.scale = Vector3(r_anillo, 1.0, r_anillo)
		
	if not _preview_fantasma:
		return
		
	_preview_fantasma.visible = visible_en_pantalla and (not modo_auto_casas)
	if visible_en_pantalla:
		var xf_snap := calcular_transform_snap(pos_mundo)
		_preview_fantasma.global_position = xf_snap["pos"]
		_preview_fantasma.rotation_degrees.y = float(xf_snap["rot_y"])

func colocar_objeto(pos_mundo: Vector3) -> Node3D:
	if modo_demolicion:
		return null
		
	var xf_snap := calcular_transform_snap(pos_mundo)
	var nuevo_obj = _instanciar_modelo_actual()
	_contenedor_objetos.add_child(nuevo_obj)
	nuevo_obj.global_position = xf_snap["pos"]
	nuevo_obj.rotation_degrees.y = float(xf_snap["rot_y"])
	nuevo_obj.set_meta("es_objeto_ciudad", true)
	var id_col: String = str(nuevo_obj.get_meta("id_modelo", id_objeto_seleccionado))
	if id_col == "garaje_camiones":
		_nivelar_terreno_para_garaje(nuevo_obj)
	elif id_col in ["zona_carga", "zona_descarga", "zona_alquiler_trailer"]:
		_nivelar_terreno_para_zona(nuevo_obj, id_col)
	elif id_col == "casa_modular" or nuevo_obj.get_meta("es_casa_modular", false):
		_agregar_base_concreto_casa(nuevo_obj)
	nuevo_obj.set_meta("radio_huella", _obtener_radio_huella(nuevo_obj))
	
	_objetos_en_escena.append(nuevo_obj)
	_aplicar_visibilidad_nodo(nuevo_obj)
	objeto_colocado.emit(nuevo_obj)
	lista_objetos_actualizada.emit(_objetos_en_escena.size())
	return nuevo_obj

func reemplazar_objeto_en_sitio(obj_antiguo: Node3D, nuevo_id: String) -> Node3D:
	if not is_instance_valid(obj_antiguo) or not _contenedor_objetos:
		return null
	var pos := obj_antiguo.global_position
	var rot_y := obj_antiguo.rotation_degrees.y
	var era_sel := (objeto_seleccionado == obj_antiguo)
	if era_sel:
		deseleccionar_objeto()
	_objetos_en_escena.erase(obj_antiguo)
	obj_antiguo.queue_free()

	id_objeto_seleccionado = nuevo_id
	var nuevo_obj := _instanciar_modelo_actual()
	_contenedor_objetos.add_child(nuevo_obj)
	nuevo_obj.global_position = pos
	nuevo_obj.rotation_degrees.y = rot_y
	nuevo_obj.set_meta("es_objeto_ciudad", true)
	if nuevo_id in ["garaje_camiones", "garaje_doble", "garaje_terminal", "garaje_moderno"]:
		_nivelar_terreno_para_garaje(nuevo_obj)
	elif nuevo_id in ["zona_carga", "zona_descarga", "zona_alquiler_trailer"]:
		_nivelar_terreno_para_zona(nuevo_obj, nuevo_id)
	nuevo_obj.set_meta("radio_huella", _obtener_radio_huella(nuevo_obj))
	_objetos_en_escena.append(nuevo_obj)
	_aplicar_visibilidad_nodo(nuevo_obj)
	if era_sel:
		seleccionar_objeto_en_escena(nuevo_obj)
	_recrear_preview_fantasma()
	lista_objetos_actualizada.emit(_objetos_en_escena.size())
	return nuevo_obj

func buscar_objeto_por_rayo(ray_origen: Vector3, ray_dir: Vector3, pos_terreno: Vector3, radio_fallback: float = 6.5) -> Node3D:
	var mejor_obj: Node3D = null
	var menor_dist_cam: float = INF

	for obj in _objetos_en_escena:
		if not is_instance_valid(obj):
			continue
		var aabb_local := _calcular_aabb_objeto(obj)
		var xf := obj.global_transform
		var aabb_mundo := AABB(xf * aabb_local.position, Vector3.ZERO)
		for ix in 2:
			for iy in 2:
				for iz in 2:
					var esquina := Vector3(
						aabb_local.position.x if ix == 0 else aabb_local.end.x,
						aabb_local.position.y if iy == 0 else aabb_local.end.y,
						aabb_local.position.z if iz == 0 else aabb_local.end.z
					)
					aabb_mundo = aabb_mundo.expand(xf * esquina)
		aabb_mundo = aabb_mundo.grow(0.9)
		var hit = aabb_mundo.intersects_ray(ray_origen, ray_dir)
		if hit != null:
			var d_cam := ray_origen.distance_squared_to(hit)
			if d_cam < menor_dist_cam:
				menor_dist_cam = d_cam
				mejor_obj = obj

	if mejor_obj != null:
		return mejor_obj

	var cercano := buscar_objeto_cercano(pos_terreno, radio_fallback)
	if cercano != null:
		return cercano

	# Si se tocó un árbol del Pincel de Bosque (MultiMesh), promoverlo a objeto editable
	return _extraer_arbol_multimesh_cercano(ray_origen, ray_dir, pos_terreno, 5.5)

func _extraer_arbol_multimesh_cercano(ray_origen: Vector3, ray_dir: Vector3, pos_terreno: Vector3, radio_max: float) -> Node3D:
	var mejor_id := ""
	var mejor_idx := -1
	var menor_d2 := radio_max * radio_max
	var dir_n := ray_dir.normalized()

	for id_mod in _transforms_por_modelo.keys():
		var arr: Array = _transforms_por_modelo[id_mod]
		for idx in arr.size():
			var tf: Transform3D = arr[idx]
			var pos_inst: Vector3 = tf.origin
			# Distancia al punto de terreno o al rayo (para copas altas)
			var d2_terreno := Vector2(pos_inst.x - pos_terreno.x, pos_inst.z - pos_terreno.z).length_squared()
			var centro_copa := pos_inst + Vector3(0, 5.0, 0)
			var t_proj := maxf(0.0, (centro_copa - ray_origen).dot(dir_n))
			var d2_rayo := (ray_origen + dir_n * t_proj).distance_squared_to(centro_copa)
			var d2 := minf(d2_terreno, d2_rayo)
			if d2 < menor_d2:
				menor_d2 = d2
				mejor_id = id_mod
				mejor_idx = idx

	if mejor_idx == -1 or mejor_id.is_empty():
		return null

	var arr_sel: Array = _transforms_por_modelo[mejor_id]
	var tf_sel: Transform3D = arr_sel[mejor_idx]
	arr_sel.remove_at(mejor_idx)
	_transforms_por_modelo[mejor_id] = arr_sel
	_actualizar_buffer_multimesh(mejor_id)

	var nuevo_obj := GeneradorModelosCiudad.crear_instancia_objeto(mejor_id)
	_contenedor_objetos.add_child(nuevo_obj)
	nuevo_obj.global_transform = tf_sel
	nuevo_obj.set_meta("es_objeto_ciudad", true)
	nuevo_obj.set_meta("id_modelo", mejor_id)
	_objetos_en_escena.append(nuevo_obj)
	lista_objetos_actualizada.emit(_objetos_en_escena.size())
	return nuevo_obj

func buscar_objeto_cercano(pos_mundo: Vector3, radio_deteccion: float = 4.0) -> Node3D:
	var mejor_obj: Node3D = null
	var menor_dist: float = radio_deteccion * radio_deteccion
	for obj in _objetos_en_escena:
		if is_instance_valid(obj):
			var dist = obj.global_position.distance_squared_to(pos_mundo)
			if dist < menor_dist:
				menor_dist = dist
				mejor_obj = obj
	return mejor_obj

func demoler_en_posicion(pos_mundo: Vector3, radio_deteccion: float = 4.0) -> bool:
	var mejor_obj: Node3D = null
	var menor_dist: float = radio_deteccion * radio_deteccion
	
	for obj in _objetos_en_escena:
		if is_instance_valid(obj):
			var dist = obj.global_position.distance_squared_to(pos_mundo)
			if dist < menor_dist:
				menor_dist = dist
				mejor_obj = obj
				
	if mejor_obj != null:
		if mejor_obj == objeto_seleccionado:
			objeto_seleccionado = null
		var pos = mejor_obj.global_position
		_objetos_en_escena.erase(mejor_obj)
		mejor_obj.queue_free()
		objeto_demolido.emit(pos)
		lista_objetos_actualizada.emit(_objetos_en_escena.size())
		return true
		
	return false

func eliminar_objeto(obj: Node3D) -> bool:
	if not is_instance_valid(obj):
		return false
	if obj == objeto_seleccionado:
		deseleccionar_objeto()
	var pos := obj.global_position
	_objetos_en_escena.erase(obj)
	obj.queue_free()
	objeto_demolido.emit(pos)
	lista_objetos_actualizada.emit(_objetos_en_escena.size())
	return true

func demoler_en_radio(pos_mundo: Vector3, radio: float = 8.0) -> int:
	var eliminados := 0
	for i in range(_objetos_en_escena.size() - 1, -1, -1):
		var obj := _objetos_en_escena[i]
		if not is_instance_valid(obj):
			_objetos_en_escena.remove_at(i)
			continue
		if obj.global_position.distance_to(pos_mundo) <= radio:
			if obj == objeto_seleccionado:
				objeto_seleccionado = null
			_objetos_en_escena.remove_at(i)
			obj.queue_free()
			eliminados += 1
	if eliminados > 0:
		objeto_demolido.emit(pos_mundo)
		lista_objetos_actualizada.emit(_objetos_en_escena.size())
	return eliminados

func obtener_id_en_posicion(pos_mundo: Vector3, radio: float = 6.0) -> String:
	var obj := buscar_objeto_cercano(pos_mundo, radio)
	if is_instance_valid(obj):
		return str(obj.get_meta("id_modelo", ""))
	return ""

var _mat_base_concreto_casa: StandardMaterial3D = null

func _agregar_base_concreto_casa(obj: Node3D) -> void:
	if not is_instance_valid(obj) or obj.get_node_or_null("BaseConcretoCasa") != null:
		return
	var aabb := _calcular_aabb_objeto(obj)
	var sx := maxf(8.2, aabb.size.x + 2.4)
	var sz := maxf(10.5, aabb.size.z + 4.2)
	var cx := aabb.position.x + aabb.size.x * 0.5
	var cz := aabb.position.z + aabb.size.z * 0.5 + 1.0

	if not _mat_base_concreto_casa:
		_mat_base_concreto_casa = StandardMaterial3D.new()
		_mat_base_concreto_casa.albedo_color = Color(0.60, 0.60, 0.58)
		_mat_base_concreto_casa.roughness = 0.88
		_mat_base_concreto_casa.metallic = 0.0

	var mi := MeshInstance3D.new()
	mi.name = "BaseConcretoCasa"
	var bm := BoxMesh.new()
	bm.size = Vector3(sx, 0.60, sz)
	mi.mesh = bm
	mi.material_override = _mat_base_concreto_casa
	# Tope a +0.15m para nivelarse y unirse con la acera (+0.165m), enterrado -0.45m
	mi.position = Vector3(cx, -0.15, cz)
	obj.add_child(mi)

func _nivelar_terreno_para_garaje(obj: Node3D) -> void:
	if not is_instance_valid(obj) or not controlador_terreno:
		return
	var max_h := obj.global_position.y
	if controlador_terreno.has_method("obtener_altura"):
		var xf := obj.global_transform
		for off_v in [Vector3(-5.3, 0, -6.5), Vector3(5.3, 0, -6.5), Vector3(-5.3, 0, 9.0), Vector3(5.3, 0, 9.0), Vector3.ZERO]:
			var off_loc: Vector3 = off_v
			var p_w: Vector3 = xf * off_loc
			var h := float(controlador_terreno.obtener_altura(p_w))
			if h > max_h:
				max_h = h
		obj.global_position.y = max_h + 0.04

	var terrain = controlador_terreno.get("terrain")
	if not terrain or not is_instance_valid(terrain) or not terrain.data:
		return
	var t_data = terrain.data
	var step: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var xf_inv := obj.global_transform.affine_inverse()
	var centro := obj.global_position
	var min_x := centro.x - 12.0
	var max_x := centro.x + 12.0
	var min_z := centro.z - 12.0
	var max_z := centro.z + 12.0
	var h_target := obj.global_position.y - 0.02
	var x := floorf(min_x / step) * step
	while x <= max_x:
		var z := floorf(min_z / step) * step
		while z <= max_z:
			var p_loc := xf_inv * Vector3(x, centro.y, z)
			if absf(p_loc.x) <= 6.2 and p_loc.z >= -7.2 and p_loc.z <= 9.8:
				t_data.set_height(Vector3(x, 0.0, z), h_target)
			z += step
		x += step
	t_data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false, true)

func _nivelar_terreno_para_zona(obj: Node3D, id_zona: String) -> void:
	if not is_instance_valid(obj) or not controlador_terreno:
		return
	var hw: float = 3.8
	var hl: float = 8.0 if id_zona == "zona_alquiler_trailer" else 6.0
	var max_h := obj.global_position.y
	if controlador_terreno.has_method("obtener_altura"):
		var xf := obj.global_transform
		for off_v in [Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(-hw, 0, hl), Vector3(hw, 0, hl), Vector3.ZERO]:
			var p_w: Vector3 = xf * (off_v as Vector3)
			var h := float(controlador_terreno.obtener_altura(p_w))
			if h > max_h:
				max_h = h
		obj.global_position.y = max_h + 0.04

	var terrain = controlador_terreno.get("terrain")
	if not terrain or not is_instance_valid(terrain) or not terrain.data:
		return
	var t_data = terrain.data
	var step: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var xf_inv := obj.global_transform.affine_inverse()
	var centro := obj.global_position
	var radio_b: float = maxf(hw, hl) + 2.5
	var min_x := centro.x - radio_b
	var max_x := centro.x + radio_b
	var min_z := centro.z - radio_b
	var max_z := centro.z + radio_b
	var h_target := obj.global_position.y - 0.03
	var x := floorf(min_x / step) * step
	while x <= max_x:
		var z := floorf(min_z / step) * step
		while z <= max_z:
			var p_loc := xf_inv * Vector3(x, centro.y, z)
			if absf(p_loc.x) <= hw and absf(p_loc.z) <= hl:
				t_data.set_height(Vector3(x, 0.0, z), h_target)
			z += step
		x += step
	t_data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false, true)

var distancia_visibilidad: float = 550.0

func aplicar_distancia_visibilidad(dist: float) -> void:
	distancia_visibilidad = clampf(dist, 120.0, 2200.0)
	for obj in _objetos_en_escena:
		if is_instance_valid(obj):
			_aplicar_visibilidad_nodo(obj)

func _aplicar_visibilidad_nodo(raiz: Node) -> void:
	var es_prop_pequeno := false
	if raiz is Node3D and raiz.has_meta("radio_huella"):
		es_prop_pequeno = float(raiz.get_meta("radio_huella")) <= 3.0
	var dist_efectiva := minf(distancia_visibilidad, 220.0) if es_prop_pequeno else distancia_visibilidad
	var es_movil := OS.has_feature("android") or OS.has_feature("ios")
	var pila: Array[Node] = [raiz]
	while not pila.is_empty():
		var cur: Node = pila.pop_back()
		for ch in cur.get_children():
			pila.append(ch)
		if cur is GeometryInstance3D:
			var gi := cur as GeometryInstance3D
			gi.visibility_range_end = dist_efectiva
			gi.visibility_range_end_margin = 20.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if es_movil and es_prop_pequeno:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _obtener_radio_huella(obj: Node3D) -> float:
	if not is_instance_valid(obj):
		return 4.0
	if obj.has_meta("radio_huella"):
		return float(obj.get_meta("radio_huella"))
	var aabb := _calcular_aabb_objeto(obj)
	var r := clampf(maxf(aabb.size.x, aabb.size.z) * 0.52, 2.5, 16.0)
	obj.set_meta("radio_huella", r)
	return r

func hay_colision_huella(pos: Vector3, radio_nuevo: float, extras: Array = [], margen: float = 0.4, ignorar_obj: Node3D = null) -> bool:
	var p2 := Vector2(pos.x, pos.z)
	for obj in _objetos_en_escena:
		if not is_instance_valid(obj) or obj == ignorar_obj:
			continue
		var r_ex := _obtener_radio_huella(obj)
		var d := p2.distance_to(Vector2(obj.global_position.x, obj.global_position.z))
		if d < (radio_nuevo + r_ex + margen):
			return true
	for obj in extras:
		if not is_instance_valid(obj) or obj == ignorar_obj:
			continue
		var r_ex := _obtener_radio_huella(obj)
		var d := p2.distance_to(Vector2(obj.global_position.x, obj.global_position.z))
		if d < (radio_nuevo + r_ex + margen):
			return true
	return false

func _existe_objeto_cerca(pos: Vector3, min_dist: float, extras: Array = []) -> bool:
	return hay_colision_huella(pos, min_dist * 0.5, extras, 0.0)

func _obtener_rotacion_hacia_via_cercana(pos: Vector3, max_dist: float = 24.0) -> Dictionary:
	if not controlador_carreteras or not controlador_carreteras.get("road_container") or not is_instance_valid(controlador_carreteras.road_container):
		return {"encontrada": false, "rot_y": float(randi() % 4) * 90.0}
	var rc = controlador_carreteras.road_container
	var mejor_d := max_dist
	var mejor_pt := Vector3.ZERO
	for seg_obj in rc.get_segments():
		var seg := seg_obj as Node3D
		if not is_instance_valid(seg):
			continue
		var curve := seg.get("curve") as Curve3D
		if not curve:
			continue
		var loc := seg.to_local(pos) if seg.is_inside_tree() else (pos - seg.position)
		var cl := curve.get_closest_point(loc)
		var wp := seg.to_global(cl) if seg.is_inside_tree() else (seg.position + cl)
		var d := Vector2(pos.x - wp.x, pos.z - wp.z).length()
		if d < mejor_d:
			mejor_d = d
			mejor_pt = wp
	if mejor_d < max_dist:
		var dir := Vector2(mejor_pt.x - pos.x, mejor_pt.z - pos.z)
		if dir.length_squared() > 0.01:
			return {"encontrada": true, "rot_y": rad_to_deg(atan2(dir.x, dir.y))}
	return {"encontrada": false, "rot_y": float(randi() % 4) * 90.0}

func generar_config_modular_aleatoria(seccion_id: String = "01_Residencial", ancho_max: float = 7.4, fondo_max: float = 7.6) -> Dictionary:
	var presets: Array[Dictionary] = DatosCasaModular.obtener_presets()
	var presets_limpios: Array[Dictionary] = []
	for pr in presets:
		var c_pr: Dictionary = pr.get("config", {})
		if int(c_pr.get("modulos_conjunto", 1)) <= 1 and not bool(c_pr.get("tiene_porteria", false)) and int(c_pr.get("silos_laterales", 0)) == 0:
			presets_limpios.append(pr)
	var pool := presets_limpios if not presets_limpios.is_empty() else presets
	var cfg: Dictionary = DatosCasaModular.crear_config_defecto()
	if not pool.is_empty():
		var pr: Dictionary = pool[randi() % pool.size()]
		cfg = DatosCasaModular.normalizar_config(pr.get("config", {}))
	var paleta := ["#f4efe6", "#e8d5b7", "#d9c2a3", "#e29578", "#a8dadc", "#f2cc8f", "#d8e2dc", "#cdb4db"]
	cfg["color_fachada"] = paleta[randi() % paleta.size()]
	cfg["ancho"] = clampf(float(cfg.get("ancho", 6.8)), 5.8, ancho_max)
	cfg["fondo"] = clampf(float(cfg.get("fondo", 7.0)), 6.0, fondo_max)
	# Desactivar elementos exteriores que exceden el lote (portería, silos, múltiples módulos, muros perimetrales)
	cfg["tiene_porteria"] = false
	cfg["silos_laterales"] = 0
	cfg["modulos_conjunto"] = 1
	cfg["muelles_carga"] = 0
	cfg["tiene_chimenea_ind"] = false
	cfg["tiene_muro_perimetral"] = false
	cfg["tiene_piscina"] = false
	match seccion_id:
		"02_Comercial":
			cfg["pisos"] = randi_range(2, 3)
			cfg["tipo_puerta"] = 5
			cfg["tipo_ventana_p1"] = 11
			cfg["tiene_garaje"] = false
		"03_Industrial_Logistica":
			cfg["pisos"] = 1
			cfg["mat_fachada"] = 12
			cfg["color_fachada"] = ["#8d99ae", "#a5a58d", "#b56576", "#ced4da"][randi() % 4]
			cfg["tipo_techo"] = "dos_aguas"
			cfg["mat_techo"] = 3
			cfg["tiene_balcon"] = false
		"04_Servicios_Publicos":
			cfg["pisos"] = randi_range(2, 3)
			cfg["color_fachada"] = ["#edf2f4", "#e9ecef", "#f8f9fa"][randi() % 3]
			cfg["tiene_porche"] = true
		_:
			cfg["pisos"] = clampi(int(cfg.get("pisos", 1)) + (randi() % 2), 1, 3)
	return cfg

func generar_casas_automaticas(pos_centro: Vector3, seccion_id: String = "01_Residencial", radio: float = 35.0, cantidad: int = 8, modo: String = "pincel") -> Array[Node3D]:
	var creados: Array[Node3D] = []
	var presets: Array[Dictionary] = DatosCasaModular.obtener_presets()
	var items_sec: Array[Dictionary] = []
	if seccion_id != "modulares":
		items_sec = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", seccion_id)

	var candidatos_pos: Array[Dictionary] = [] # {"pos": Vector3, "rot_y": float}
	if modo == "via" and controlador_carreteras and controlador_carreteras.get("road_container") and is_instance_valid(controlador_carreteras.road_container):
		var rc = controlador_carreteras.road_container
		var mejor_seg: Node3D = null
		var mejor_d := 50.0
		for seg_obj in rc.get_segments():
			var seg := seg_obj as Node3D
			if not is_instance_valid(seg):
				continue
			var curve := seg.get("curve") as Curve3D
			if not curve:
				continue
			var loc := seg.to_local(pos_centro) if seg.is_inside_tree() else (pos_centro - seg.position)
			var cl := curve.get_closest_point(loc)
			var wp := seg.to_global(cl) if seg.is_inside_tree() else (seg.position + cl)
			var d := Vector2(pos_centro.x - wp.x, pos_centro.z - wp.z).length()
			if d < mejor_d:
				mejor_d = d
				mejor_seg = seg
		if mejor_seg:
			var curve := mejor_seg.get("curve") as Curve3D
			var largo := curve.get_baked_length()
			var ancho_via := 8.8
			var sp = mejor_seg.get("start_point")
			if controlador_carreteras.has_method("_obtener_ancho_via_punto") and sp != null and is_instance_valid(sp):
				ancho_via = float(controlador_carreteras._obtener_ancho_via_punto(sp))
			var dist_lado := ancho_via * 0.5 + 8.5
			var paso := 8.2
			var off := 4.5
			while off < largo - 4.0 and candidatos_pos.size() < cantidad * 2:
				var p_l := curve.sample_baked(off)
				var p_w := mejor_seg.to_global(p_l) if mejor_seg.is_inside_tree() else (mejor_seg.position + p_l)
				var p2_l := curve.sample_baked(minf(off + 0.5, largo))
				var p2_w := mejor_seg.to_global(p2_l) if mejor_seg.is_inside_tree() else (mejor_seg.position + p2_l)
				var tan := p2_w - p_w
				tan.y = 0.0
				if tan.length_squared() > 0.001:
					tan = tan.normalized()
					var lat := Vector3(-tan.z, 0.0, tan.x)
					for s_v in [-1.0, 1.0]:
						var s: float = float(s_v)
						var cp := p_w + lat * s * (dist_lado + randf_range(-0.6, 1.2))
						var rot_y := rad_to_deg(atan2(-lat.x * s, -lat.z * s))
						candidatos_pos.append({"pos": cp, "rot_y": rot_y})
				off += paso
	else:
		# Muestreo espiral dorado para evitar agrupamientos feos
		var max_intentos := cantidad * 4
		for i in range(max_intentos):
			var frac := float(i + 1) / float(max_intentos)
			var r := radio * sqrt(frac) * randf_range(0.85, 1.05)
			var ang := float(i) * 2.399963 + randf_range(-0.25, 0.25)
			var cp := pos_centro + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			var info_via := _obtener_rotacion_hacia_via_cercana(cp, 24.0)
			candidatos_pos.append({"pos": cp, "rot_y": float(info_via["rot_y"])})

	var id_prev := id_objeto_seleccionado
	var cfg_prev := config_casa_modular_actual.duplicate(true)
	var rot_prev := rotacion_actual_grados
	var snap_v_prev := snap_carretera_activo
	var snap_g_prev := snap_cuadricula_activo
	snap_carretera_activo = false
	snap_cuadricula_activo = false

	var paleta_fachadas := ["#f4efe6", "#e8d5b7", "#d9c2a3", "#e29578", "#a8dadc", "#f2cc8f", "#d8e2dc", "#cdb4db"]
	for cand in candidatos_pos:
		if creados.size() >= cantidad:
			break
		var pos_c: Vector3 = cand["pos"]
		if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
			pos_c.y = float(controlador_terreno.obtener_altura(pos_c))
		if _existe_objeto_cerca(pos_c, 7.2, creados):
			continue

		config_casa_modular_actual = generar_config_modular_aleatoria(seccion_id, 7.6, 8.0)
		id_objeto_seleccionado = "casa_modular"

		rotacion_actual_grados = float(cand["rot_y"])
		var obj := colocar_objeto(pos_c)
		if obj:
			var r_h := _obtener_radio_huella(obj)
			if hay_colision_huella(pos_c, r_h, creados, 0.35, obj):
				# Evitar superposición: si la malla real choca con otra ya colocada, retirarla
				_objetos_en_escena.erase(obj)
				obj.queue_free()
			else:
				creados.append(obj)

	id_objeto_seleccionado = id_prev
	config_casa_modular_actual = cfg_prev
	rotacion_actual_grados = rot_prev
	snap_carretera_activo = snap_v_prev
	snap_cuadricula_activo = snap_g_prev
	return creados

func generar_cuadra_casas(pos_centro: Vector3, seccion_id: String = "01_Residencial", cols: int = 5, rot_grados: float = 0.0, con_calles: bool = true) -> Array[Node3D]:
	var creados: Array[Node3D] = []
	var presets: Array[Dictionary] = DatosCasaModular.obtener_presets()
	var items_sec: Array[Dictionary] = []
	if seccion_id != "modulares":
		items_sec = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", seccion_id)

	var paso_x := 8.4
	var sep_z := 9.4
	var ancho_lote := float(cols) * paso_x
	var rot_rad := deg_to_rad(rot_grados)

	if con_calles and controlador_carreteras:
		var hx := ancho_lote * 0.5 + 8.5
		var hz := sep_z + 7.5
		var esquinas_2d := [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
		var pts_via: Array[Vector3] = []
		for e in esquinas_2d:
			var r: Vector2 = (e as Vector2).rotated(rot_rad)
			var p := pos_centro + Vector3(r.x, 0.0, r.y)
			if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
				p.y = float(controlador_terreno.obtener_altura(p))
			pts_via.append(p)
		if controlador_carreteras.has_method("finalizar_tramo_actual"):
			controlador_carreteras.finalizar_tramo_actual()
		var rps_cuadra: Array = []
		for p_v in pts_via:
			var rp = controlador_carreteras.agregar_punto_carretera(p_v)
			if rp:
				rps_cuadra.append(rp)
		if rps_cuadra.size() >= 4 and controlador_carreteras.has_method("conectar_dos_puntos"):
			controlador_carreteras.conectar_dos_puntos(rps_cuadra[3], rps_cuadra[0])
		if controlador_carreteras.has_method("finalizar_tramo_actual"):
			controlador_carreteras.finalizar_tramo_actual()

	var id_prev := id_objeto_seleccionado
	var cfg_prev := config_casa_modular_actual.duplicate(true)
	var rot_prev := rotacion_actual_grados
	var snap_v_prev := snap_carretera_activo
	var snap_g_prev := snap_cuadricula_activo
	snap_carretera_activo = false
	snap_cuadricula_activo = false
	var paleta := ["#f4efe6", "#e8d5b7", "#d9c2a3", "#e29578", "#a8dadc", "#f2cc8f", "#d8e2dc", "#cdb4db"]

	for fila in range(2):
		var z_off := -sep_z * 0.5 if fila == 0 else sep_z * 0.5
		var rot_fila := 180.0 if fila == 0 else 0.0
		for c_i in range(cols):
			var x_off := (float(c_i) - float(cols - 1) * 0.5) * paso_x
			var rel := Vector2(x_off, z_off).rotated(rot_rad)
			var pos_c := pos_centro + Vector3(rel.x, 0.0, rel.y)
			if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
				pos_c.y = float(controlador_terreno.obtener_altura(pos_c))
			config_casa_modular_actual = generar_config_modular_aleatoria(seccion_id, 7.2, 7.6)
			id_objeto_seleccionado = "casa_modular"
			rotacion_actual_grados = rot_fila - rot_grados
			var obj := colocar_objeto(pos_c)
			if obj:
				var r_h := _obtener_radio_huella(obj)
				if hay_colision_huella(pos_c, r_h, creados, 0.25, obj):
					_objetos_en_escena.erase(obj)
					obj.queue_free()
				else:
					creados.append(obj)

	id_objeto_seleccionado = id_prev
	config_casa_modular_actual = cfg_prev
	rotacion_actual_grados = rot_prev
	snap_carretera_activo = snap_v_prev
	snap_cuadricula_activo = snap_g_prev
	return creados

func limpiar_todos_los_objetos() -> void:
	objeto_seleccionado = null
	limpiar_vegetacion_multimesh()
	for obj in _objetos_en_escena:
		if is_instance_valid(obj):
			obj.queue_free()
	_objetos_en_escena.clear()
	lista_objetos_actualizada.emit(0)

func _crear_preview_fantasma() -> void:
	_recrear_preview_fantasma()

func _recrear_preview_fantasma() -> void:
	if _preview_fantasma and is_instance_valid(_preview_fantasma):
		_preview_fantasma.queue_free()
		
	_preview_fantasma = _instanciar_modelo_actual()
	_preview_fantasma.name = "PreviewFantasma"
	
	# Desactivar colisiones del preview y aplicar material translúcido holográfico
	_desactivar_colisiones_y_holograma(_preview_fantasma)
	_preview_fantasma.visible = false
	add_child(_preview_fantasma)

func _desactivar_colisiones_y_holograma(nodo: Node) -> void:
	if nodo is CollisionShape3D or nodo is CollisionPolygon3D:
		nodo.disabled = true
	elif nodo is MeshInstance3D:
		var mi: MeshInstance3D = nodo
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			for s in range(mi.mesh.get_surface_count()):
				var orig_mat = mi.get_surface_override_material(s)
				if not orig_mat:
					orig_mat = mi.mesh.surface_get_material(s)
					
				var mat_holo := StandardMaterial3D.new()
				mat_holo.albedo_color = Color(0.88, 0.68, 0.28, 0.65) # Automotive Instrument Amber
				mat_holo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat_holo.cull_mode = BaseMaterial3D.CULL_DISABLED
				
				if orig_mat is StandardMaterial3D and orig_mat.albedo_texture != null:
					mat_holo.albedo_texture = orig_mat.albedo_texture
					mat_holo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat_holo.alpha_scissor_threshold = 0.4
				else:
					mat_holo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					
				mi.set_surface_override_material(s, mat_holo)
		else:
			var mat_holo := StandardMaterial3D.new()
			mat_holo.albedo_color = Color(0.88, 0.68, 0.28, 0.55)
			mat_holo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat_holo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat_holo
		
	for hijo in nodo.get_children():
		_desactivar_colisiones_y_holograma(hijo)

func serializar_objetos() -> Array:
	var lista: Array = []
	for obj in _objetos_en_escena:
		if is_instance_valid(obj):
			var id_mod = obj.get_meta("id_modelo", "casa_suburbana")
			var item_dict := {
				"id": id_mod,
				"posicion": [obj.global_position.x, obj.global_position.y, obj.global_position.z],
				"rotacion_y": obj.rotation_degrees.y,
				"rotacion_z": obj.rotation_degrees.z,
				"escala": [obj.scale.x, obj.scale.y, obj.scale.z],
				"offset_y": float(obj.get_meta("offset_y", 0.0))
			}
			if obj.has_meta("config_casa"):
				item_dict["config_casa"] = obj.get_meta("config_casa")
			lista.append(item_dict)
	return lista

func deserializar_objetos(lista: Array) -> void:
	limpiar_todos_los_objetos()
	for d in lista:
		if not (d is Dictionary):
			continue
		var id_mod: String = str(d.get("id", "casa_suburbana"))
		var pos_arr = d.get("posicion", [0, 0, 0])
		var rot_y: float = float(d.get("rotacion_y", 0.0))
		var rot_z: float = float(d.get("rotacion_z", 0.0))
		var off_y: float = float(d.get("offset_y", 0.0))
		
		var obj: Node3D
		if id_mod == "casa_modular" and d.has("config_casa") and d["config_casa"] is Dictionary:
			obj = GeneradorCasaModular.crear_casa(d["config_casa"])
		else:
			obj = GeneradorModelosCiudad.crear_instancia_objeto(id_mod)
		_contenedor_objetos.add_child(obj)
		if pos_arr is Array and pos_arr.size() >= 3:
			obj.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		obj.rotation_degrees.y = rot_y
		obj.rotation_degrees.z = rot_z
		var esc_arr = d.get("escala", null)
		if esc_arr is Array and esc_arr.size() >= 3:
			obj.scale = Vector3(float(esc_arr[0]), float(esc_arr[1]), float(esc_arr[2]))
		obj.set_meta("id_modelo", id_mod)
		obj.set_meta("offset_y", off_y)
		obj.set_meta("es_objeto_ciudad", true)
		_objetos_en_escena.append(obj)
	lista_objetos_actualizada.emit(_objetos_en_escena.size())


# ── SISTEMA DE DISPERSIÓN DE VEGETACIÓN EN MASA (MULTIMESH) ──────────

func alternar_modo_dispersion(activo: bool) -> void:
	modo_pincel_dispersion = activo
	if _preview_anillo_dispersion:
		_preview_anillo_dispersion.visible = activo and not modo_demolicion

func establecer_radio_dispersion(r: float) -> void:
	radio_pincel_dispersion = clampf(r, 4.0, 45.0)
	if _preview_anillo_dispersion:
		_preview_anillo_dispersion.scale = Vector3(radio_pincel_dispersion, 1.0, radio_pincel_dispersion)

func establecer_densidad_dispersion(d: int) -> void:
	densidad_pincel_dispersion = clampi(d, 1, 15)

func dispersar_vegetacion(pos_centro: Vector3, id_modelo_override: String = "") -> int:
	var id_mod = id_modelo_override if id_modelo_override != "" else id_objeto_seleccionado
	if id_mod == "":
		id_mod = "arbol_sabanero"
		
	var mmi = _obtener_o_crear_multimesh(id_mod)
	if not mmi:
		return 0
		
	var arr: Array = _transforms_por_modelo.get(id_mod, [])
	var colocadas: int = 0
	
	for i in range(densidad_pincel_dispersion):
		var angulo = randf_range(0.0, TAU)
		var dist = sqrt(randf()) * radio_pincel_dispersion
		var offset_xz = Vector2(cos(angulo), sin(angulo)) * dist
		var pos_inst := Vector3(pos_centro.x + offset_xz.x, pos_centro.y, pos_centro.z + offset_xz.y)
		
		# Ajustar al relieve del terreno
		if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
			pos_inst.y = controlador_terreno.obtener_altura(pos_inst)
			
		var rot_y = randf_range(0.0, TAU)
		var escala = randf_range(0.85, 1.25)
		
		var t := Transform3D()
		t = t.scaled(Vector3.ONE * escala)
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = pos_inst
		
		arr.append(t)
		colocadas += 1
		
	_transforms_por_modelo[id_mod] = arr
	_actualizar_buffer_multimesh(id_mod)
	return colocadas

func borrar_vegetacion_en_radio(pos_centro: Vector3, radio: float) -> int:
	var total_borradas: int = 0
	var r2 = radio * radio
	for id_mod in _transforms_por_modelo.keys():
		var arr: Array = _transforms_por_modelo[id_mod]
		var nuevos: Array = []
		for t in arr:
			var tf: Transform3D = t
			var dist2 = Vector2(tf.origin.x - pos_centro.x, tf.origin.z - pos_centro.z).length_squared()
			if dist2 <= r2:
				total_borradas += 1
			else:
				nuevos.append(tf)
		_transforms_por_modelo[id_mod] = nuevos
		_actualizar_buffer_multimesh(id_mod)
	return total_borradas

func limpiar_vegetacion_multimesh() -> void:
	for id_mod in _multimeshes_por_modelo.keys():
		var mmi = _multimeshes_por_modelo[id_mod]
		if is_instance_valid(mmi):
			mmi.queue_free()
	_multimeshes_por_modelo.clear()
	_transforms_por_modelo.clear()

func _asegurar_contenedor_multimesh() -> void:
	if not _contenedor_multimesh or not is_instance_valid(_contenedor_multimesh):
		_contenedor_multimesh = Node3D.new()
		_contenedor_multimesh.name = "ContenedorMultiMesh_Vegetacion"
		add_child(_contenedor_multimesh)

func _obtener_o_crear_multimesh(id_modelo: String) -> MultiMeshInstance3D:
	_asegurar_contenedor_multimesh()
	if _multimeshes_por_modelo.has(id_modelo) and is_instance_valid(_multimeshes_por_modelo[id_modelo]):
		return _multimeshes_por_modelo[id_modelo]
		
	# Extraer malla del prefab del modelo
	var temp_node = GeneradorModelosCiudad.crear_instancia_objeto(id_modelo)
	if not temp_node:
		return null
		
	var mesh_encontrada: Mesh = null
	var mat_encontrado: Material = null
	
	var cola: Array[Node] = [temp_node]
	while not cola.is_empty():
		var n = cola.pop_front()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi = n as MeshInstance3D
			mesh_encontrada = mi.mesh
			mat_encontrado = mi.material_override
			if not mat_encontrado and mi.get_surface_override_material_count() > 0:
				mat_encontrado = mi.get_surface_override_material(0)
			_base_transforms_por_modelo[id_modelo] = mi.transform
			break
		for c in n.get_children():
			cola.append(c)
			
	temp_node.queue_free()
	
	if not mesh_encontrada:
		return null
		
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "MMI_%s" % id_modelo
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_encontrada
	mmi.multimesh = mm
	if mat_encontrado:
		mmi.material_override = mat_encontrado
		
	_contenedor_multimesh.add_child(mmi)
	_multimeshes_por_modelo[id_modelo] = mmi
	if not _transforms_por_modelo.has(id_modelo):
		_transforms_por_modelo[id_modelo] = []
	return mmi

func _actualizar_buffer_multimesh(id_modelo: String) -> void:
	if not _multimeshes_por_modelo.has(id_modelo):
		return
	var mmi: MultiMeshInstance3D = _multimeshes_por_modelo[id_modelo]
	if not is_instance_valid(mmi) or not mmi.multimesh:
		return
		
	var arr: Array = _transforms_por_modelo.get(id_modelo, [])
	var count = arr.size()
	var base_t: Transform3D = _base_transforms_por_modelo.get(id_modelo, Transform3D.IDENTITY)
	mmi.multimesh.instance_count = count
	for i in range(count):
		mmi.multimesh.set_instance_transform(i, arr[i] * base_t)

func serializar_vegetacion_multimesh() -> Dictionary:
	var res: Dictionary = {}
	for id_mod in _transforms_por_modelo.keys():
		var arr: Array = _transforms_por_modelo[id_mod]
		var ser_arr: Array = []
		for t in arr:
			var tf: Transform3D = t
			ser_arr.append([
				tf.origin.x, tf.origin.y, tf.origin.z,
				tf.basis.get_euler().y,
				tf.basis.get_scale().x
			])
		res[id_mod] = ser_arr
	return res

func deserializar_vegetacion_multimesh(datos: Dictionary) -> void:
	limpiar_vegetacion_multimesh()
	for id_mod in datos.keys():
		var ser_arr = datos[id_mod]
		var transforms: Array = []
		for item in ser_arr:
			var pos := Vector3(item[0], item[1], item[2])
			var rot_y: float = float(item[3])
			var escala: float = float(item[4])
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * escala)
			t = t.rotated(Vector3.UP, rot_y)
			t.origin = pos
			transforms.append(t)
		_transforms_por_modelo[id_mod] = transforms
		_obtener_o_crear_multimesh(id_mod)
		_actualizar_buffer_multimesh(id_mod)
