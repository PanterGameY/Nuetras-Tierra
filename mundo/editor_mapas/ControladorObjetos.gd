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
@export var tamano_cuadricula: float = 4.0
@export var rotacion_actual_grados: float = 0.0

var id_objeto_seleccionado: String = "casa_suburbana"
var modo_demolicion: bool = false
var objeto_seleccionado: Node3D = null

var _contenedor_objetos: Node3D
var _preview_fantasma: Node3D
var _marcador_demolicion: MeshInstance3D = null
var _caja_delimitadora: Node3D = null
var _mesh_caja_solida: MeshInstance3D = null
var _mesh_caja_lineas: MeshInstance3D = null
var _objetos_en_escena: Array[Node3D] = []
var _objeto_resaltado_demolicion: Node3D = null

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
	_crear_nodo_caja_delimitadora()

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
	modo_demolicion = false
	id_objeto_seleccionado = id_modelo
	_recrear_preview_fantasma()

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
	var res = pos_mundo
	if snap_cuadricula_activo:
		res.x = round(pos_mundo.x / tamano_cuadricula) * tamano_cuadricula
		res.z = round(pos_mundo.z / tamano_cuadricula) * tamano_cuadricula
	return res

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
	
	add_child(_caja_delimitadora)

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
	
	var margen := 0.35
	var x0 = aabb.position.x - margen
	var x1 = aabb.end.x + margen
	var z0 = aabb.position.z - margen
	var z1 = aabb.end.z + margen
	var y_base = 0.05
	var y_esquina = min(aabb.size.y * 0.35, 1.0)
	
	var p0 = Vector3(x0, y_base, z0)
	var p1 = Vector3(x1, y_base, z0)
	var p2 = Vector3(x1, y_base, z1)
	var p3 = Vector3(x0, y_base, z1)
	
	# Marco de selección limpio en el suelo
	im.surface_add_vertex(p0); im.surface_add_vertex(p1)
	im.surface_add_vertex(p1); im.surface_add_vertex(p2)
	im.surface_add_vertex(p2); im.surface_add_vertex(p3)
	im.surface_add_vertex(p3); im.surface_add_vertex(p0)
	
	# Brackets de esquinas verticales elegantes
	im.surface_add_vertex(p0); im.surface_add_vertex(p0 + Vector3(0, y_esquina, 0))
	im.surface_add_vertex(p1); im.surface_add_vertex(p1 + Vector3(0, y_esquina, 0))
	im.surface_add_vertex(p2); im.surface_add_vertex(p2 + Vector3(0, y_esquina, 0))
	im.surface_add_vertex(p3); im.surface_add_vertex(p3 + Vector3(0, y_esquina, 0))
	
	im.surface_end()
	_mesh_caja_lineas.mesh = im
	_mesh_caja_lineas.position = Vector3.ZERO
	
	_caja_delimitadora.global_position = objeto_seleccionado.global_position
	_caja_delimitadora.rotation_degrees.y = objeto_seleccionado.rotation_degrees.y
	_caja_delimitadora.visible = true

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
	var off_y = float(obj.get_meta("offset_y", 0.0))
	pos_final.y += off_y
	obj.global_position = pos_final
	if obj == objeto_seleccionado and _caja_delimitadora:
		_caja_delimitadora.global_position = pos_final

func actualizar_cursor_objeto(pos_mundo: Vector3, visible_en_pantalla: bool) -> void:
	if is_instance_valid(objeto_seleccionado):
		if _preview_fantasma:
			_preview_fantasma.visible = false
		if _marcador_demolicion:
			_marcador_demolicion.visible = false
		return
		
	if modo_demolicion:
		if _preview_fantasma:
			_preview_fantasma.visible = false
		if _marcador_demolicion:
			_marcador_demolicion.visible = visible_en_pantalla
			if visible_en_pantalla:
				_marcador_demolicion.global_position = pos_mundo + Vector3(0, 0.15, 0)
		return
		
	if _marcador_demolicion:
		_marcador_demolicion.visible = false
		
	if not _preview_fantasma:
		return
		
	_preview_fantasma.visible = visible_en_pantalla
	if visible_en_pantalla:
		var pos_ajustada = calcular_posicion_snap(pos_mundo)
		_preview_fantasma.global_position = pos_ajustada
		_preview_fantasma.rotation_degrees.y = rotacion_actual_grados

func colocar_objeto(pos_mundo: Vector3) -> Node3D:
	if modo_demolicion:
		return null
		
	var pos_final = calcular_posicion_snap(pos_mundo)
	var nuevo_obj = GeneradorModelosCiudad.crear_instancia_objeto(id_objeto_seleccionado)
	_contenedor_objetos.add_child(nuevo_obj)
	nuevo_obj.global_position = pos_final
	nuevo_obj.rotation_degrees.y = rotacion_actual_grados
	nuevo_obj.set_meta("es_objeto_ciudad", true)
	
	_objetos_en_escena.append(nuevo_obj)
	objeto_colocado.emit(nuevo_obj)
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
		
	_preview_fantasma = GeneradorModelosCiudad.crear_instancia_objeto(id_objeto_seleccionado)
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
			lista.append({
				"id": id_mod,
				"posicion": [obj.global_position.x, obj.global_position.y, obj.global_position.z],
				"rotacion_y": obj.rotation_degrees.y,
				"offset_y": float(obj.get_meta("offset_y", 0.0))
			})
	return lista

func deserializar_objetos(lista: Array) -> void:
	limpiar_todos_los_objetos()
	for d in lista:
		var id_mod = d.get("id", "casa_suburbana")
		var pos_arr = d.get("posicion", [0, 0, 0])
		var rot_y = d.get("rotacion_y", 0.0)
		var off_y = float(d.get("offset_y", 0.0))
		
		var obj = GeneradorModelosCiudad.crear_instancia_objeto(id_mod)
		_contenedor_objetos.add_child(obj)
		obj.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		obj.rotation_degrees.y = rot_y
		obj.set_meta("offset_y", off_y)
		obj.set_meta("es_objeto_ciudad", true)
		_objetos_en_escena.append(obj)
		obj.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		obj.rotation_degrees.y = rot_y
		obj.set_meta("es_objeto_ciudad", true)
		_objetos_en_escena.append(obj)
	lista_objetos_actualizada.emit(_objetos_en_escena.size())


# ── SISTEMA DE DISPERSIÓN DE VEGETACIÓN EN MASA (MULTIMESH) ──────────

func alternar_modo_dispersion(activo: bool) -> void:
	modo_pincel_dispersion = activo
	if _preview_fantasma:
		_preview_fantasma.visible = not activo

func establecer_radio_dispersion(r: float) -> void:
	radio_pincel_dispersion = clampf(r, 4.0, 45.0)

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
