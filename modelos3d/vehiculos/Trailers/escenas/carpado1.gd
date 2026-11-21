extends RigidBody3D

@export var debug_patas: bool = false
@export var auto_snap_on_ready: bool = true
@export var mass_kg: float = 7500.0

@export_group("Distribución de Centro de Masa")
## Si está activo, el centro de masa se calcula dinámicamente distribuyendo el peso de la carga de forma equilibrada entre el enganche (Z=-5.61) y las ruedas traseras (Z=+4.90).
@export var balance_automatico_distribuido: bool = true
## Porcentaje objetivo del peso de la carga que recae en las ruedas del trailer (0.50 = 50% ruedas y 50% enganche / quinta rueda).
@export_range(0.2, 0.8, 0.01) var porcentaje_carga_a_ruedas: float = 0.50
## Posición longitudinal Z del centro de masa del trailer en vacío.
@export var cm_offset_z_vacio: float = 0.60
## Altura base Y del centro de masa en vacío.
@export var cm_offset_y_vacio: float = 0.55
## Altura Y del centro de masa con carga completa.
@export var cm_offset_y_cargado: float = 0.95

## Variables públicas calculadas de posición de centro de masa (compatibilidad con inspector y scripts externos)
@export var cm_offset_y: float = 0.6
@export var cm_offset_z: float = -0.355 ## Punto equilibrado 50% enganche / 50% ejes traseros

@export_group("Física General")
@export var linear_damp_override: float = 0.05
@export var angular_damp_override: float = 0.05
@export var gravity_scale_override: float = 1.0
@export var ensure_patas_enabled: bool = true
@export var snap_clamp_max: float = 2.0
@export var patas_subida_y: float = 0.65
@export var patas_velocidad_subida: float = 1.0

@export_group("Carga y Peso")
## Peso de prueba de la carga en kg (configurable en el Inspector para pruebas; luego será asignado por el sistema de carga).
## Al modificar este valor se actualiza la masa total física del trailer (mass = mass_kg + peso)
## y se recalcula dinámicamente la rigidez y amortiguación de las suspensiones de todas las ruedas.
@export var peso: float = 0.0:
	set(val):
		var nuevo_peso = maxf(val, 0.0)
		if is_equal_approx(peso, nuevo_peso):
			return
		peso = nuevo_peso
		if is_node_ready():
			_aplicar_peso_carga(peso)

@export_group("Personalización de Ruedas")
## ID del preset de ruedas del catálogo (ej. 'rin_t2_cromo', 'rin_t3_aluminio', 'rin_t1_artillado', 'original_carpado')
@export var tipo_ruedas: String = "":
	set(val):
		if tipo_ruedas == val:
			return
		tipo_ruedas = val
		if is_node_ready() and val != "":
			_aplicar_tipo_ruedas_interno(val)
@export var color_rines: Color = Color(0, 0, 0, 0)
@export var metallic_rines: float = -1.0
@export var roughness_rines: float = -1.0

var _snap_done: bool = false
var _cuerpo_camion: RigidBody3D = null
var _patas_shape: CollisionShape3D = null
var _nodo_patas: Node3D = null
var _patas_pos_original: Vector3 = Vector3.ZERO
var _tween_patas: Tween = null
var patas_abajo: bool = true

var _sprite_patas: Sprite3D = null
var _label_patas: Label3D = null
var _sprite_patas_visible: bool = false
var _tween_sprite_patas: Tween = null
var _pos_base_sprite: Vector3 = Vector3.ZERO
var _canvas_patas: CanvasLayer = null
var _btn_pantalla_patas: Button = null
var _audio_patas: AudioStreamPlayer3D = null
var _ultimo_tiempo_interaccion_ms: int = 0

func tiene_patas_abajo() -> bool:
	return patas_abajo

func _ready() -> void:
	add_to_group("remolque")
	add_to_group("trailers")
	_eliminar_static_bodies_internos()
	
	if tipo_ruedas != "":
		aplicar_tipo_ruedas(tipo_ruedas)
	else:
		_configurar_ruedas()

	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	mass = mass_kg + peso
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = _calcular_centro_de_masa(peso)
	linear_damp = linear_damp_override
	angular_damp = angular_damp_override
	gravity_scale = gravity_scale_override
	continuous_cd = true
	can_sleep = false

	if peso > 0.0:
		_aplicar_peso_carga(peso)

	if ensure_patas_enabled and _patas_shape:
		_patas_shape.disabled = false

	var shapes: Array[CollisionShape3D] = []
	_gather_collision_shapes(self, shapes)
	for cs in shapes:
		if cs.shape:
			var cls_name: String = cs.shape.get_class()
			if cls_name.find("Concave") != -1 or cls_name.find("ConcavePolygon") != -1:
				print("[carpado1] WARNING: Collision shape is concave:", cs.get_path(), " class=", cls_name)
	_nodo_patas = find_child("Patas", true, false) as Node3D
	if not _nodo_patas:
		_nodo_patas = _buscar_nodo_patas_recursivo(self)
	if _nodo_patas:
		_patas_pos_original = _nodo_patas.position
		print("[Patas] Nodo patas encontrado:", _nodo_patas.get_path(), " pos_original:", _patas_pos_original)
		call_deferred("_crear_boton_sprite_patas")
	else:
		print("[Patas] AVISO: No se encontró ningún nodo de Patas en ", name)

	if not _tiene_reconexion_activa():
		var gv_ini := get_node_or_null("/root/GestorVehiculos")
		if gv_ini and gv_ini.has_method("restaurar_ubicacion_vehiculo"):
			gv_ini.call("restaurar_ubicacion_vehiculo", self)

	if auto_snap_on_ready:
		call_deferred("_snap_to_ground")
	else:
		freeze = false

	call_deferred("_reconectar_si_activo")

	if debug_patas:
		print("Carpado ready:", name, "global_pos=", global_transform.origin)
		var raycasts := []
		_gather_raycasts(self, raycasts)
		for rc in raycasts:
			if rc is RayCast3D:
				rc.force_raycast_update()
				print("  raycast:", rc.name, " enabled=", rc.enabled, " target=", rc.target_position, " colliding=", rc.is_colliding())


func _configurar_ruedas() -> void:
	var ruedas: Array[RuedaTrailer] = []
	_gather_ruedas(self, ruedas)
	if ruedas.is_empty():
		return

	# Calcular la porción exacta de peso que soportan las ruedas del trailer
	# según la distribución del centro de masa entre el enganche (Z=-5.61) y los ejes (Z=+4.90)
	var z_hitch: float = -5.61
	var z_axles: float = 4.90
	var distancia_apoyos: float = z_axles - z_hitch
	var fraccion_ejes: float = clampf((center_of_mass.z - z_hitch) / distancia_apoyos, 0.25, 0.85)
	var masa_sobre_ejes: float = mass * fraccion_ejes

	for r in ruedas:
		r.configurar_desde_masa(masa_sobre_ejes, ruedas.size())

## Aplica un tipo de rueda del catálogo a todas las ruedas del trailer
func aplicar_tipo_ruedas(id_tipo: String) -> void:
	if tipo_ruedas != id_tipo:
		tipo_ruedas = id_tipo
	_aplicar_tipo_ruedas_interno(id_tipo)

func _aplicar_tipo_ruedas_interno(id_tipo: String) -> void:
	var ruedas: Array[RuedaTrailer] = []
	_gather_ruedas(self, ruedas)
	for r in ruedas:
		r.aplicar_tipo_rueda(id_tipo)
		if color_rines.a > 0.001 or metallic_rines >= 0.0 or roughness_rines >= 0.0:
			r.aplicar_color_rin(color_rines, metallic_rines, roughness_rines)
	_configurar_ruedas()

## Personaliza el color y acabado de los rines de todas las ruedas
func aplicar_color_rines(col: Color, met: float = -1.0, rough: float = -1.0) -> void:
	color_rines = col
	metallic_rines = met
	roughness_rines = rough
	var ruedas: Array[RuedaTrailer] = []
	_gather_ruedas(self, ruedas)
	for r in ruedas:
		r.aplicar_color_rin(col, met, rough)

## Obtiene la lista de todas las ruedas del trailer
func obtener_ruedas() -> Array[RuedaTrailer]:
	var r: Array[RuedaTrailer] = []
	_gather_ruedas(self, r)
	return r

func _gather_ruedas(node: Node, out: Array[RuedaTrailer]) -> void:
	for c in node.get_children():
		if c is RuedaTrailer:
			out.append(c)
		_gather_ruedas(c, out)

func _eliminar_static_bodies_internos() -> void:
	var statics: Array[StaticBody3D] = []
	_gather_static_bodies(self, statics)
	for sb in statics:
		for child in sb.get_children():
			if child is CollisionShape3D:
				var shape: CollisionShape3D = child as CollisionShape3D
				if shape.shape:
					var was_patas: bool = _is_patas_shape(sb)
					var local_t = _obtener_transform_relativo(shape, self)
					sb.remove_child(shape)
					add_child(shape)
					shape.transform = local_t
					if was_patas:
						_patas_shape = shape
		sb.queue_free()
		if debug_patas:
			print("[carpado1] Eliminado StaticBody3D interno:", sb.get_path())


func _obtener_transform_relativo(nodo_hijo: Node3D, ancestro: Node3D) -> Transform3D:
	var t = Transform3D.IDENTITY
	var curr = nodo_hijo
	while curr != null and curr != ancestro:
		t = curr.transform * t
		curr = curr.get_parent()
	return t


func _is_patas_shape(sb: StaticBody3D) -> bool:
	if sb.name.to_lower().find("pata") != -1:
		return true
	var parent: Node = sb.get_parent()
	if parent:
		var name_lower: String = parent.name.to_lower()
		if name_lower.find("pata") != -1:
			return true
	return false

func _buscar_nodo_patas_recursivo(n: Node) -> Node3D:
	for child in n.get_children():
		if child is Node3D and child.name.to_lower().find("pata") != -1 and not (child is CollisionShape3D):
			return child as Node3D
		var res = _buscar_nodo_patas_recursivo(child)
		if res:
			return res
	return null


func _gather_static_bodies(node: Node, out_array: Array[StaticBody3D]) -> void:
	for c in node.get_children():
		if c is StaticBody3D:
			out_array.append(c as StaticBody3D)
		else:
			_gather_static_bodies(c, out_array)


func _physics_process(_delta: float) -> void:
	# Failsafe anti-abismo: si el tráiler cae por debajo del mapa por algún glitch de colisión
	if global_position.y < -12.0:
		_rescatar_del_abismo()


func _rescatar_del_abismo() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if esta_enganchado() and is_instance_valid(_cuerpo_camion):
		var hitch = _find_my_hitch()
		var pos_camion = _cuerpo_camion.global_position
		global_position = pos_camion - _cuerpo_camion.global_transform.basis.z * 5.0 + Vector3.UP * 1.0
	else:
		global_position.y = 2.0
		call_deferred("_snap_to_ground")


func desactivar_patas() -> void:
	if _patas_shape:
		_patas_shape.disabled = true

func activar_patas() -> void:
	if _patas_shape:
		_patas_shape.disabled = false

func esta_enganchado() -> bool:
	return _cuerpo_camion != null

func enganchado_a(camion: RigidBody3D) -> void:
	_cuerpo_camion = camion
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	sleeping = false

	# Guardar tipo de ruedas en la sesión activa si existe
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and tipo_ruedas != "":
		var remolques = datos.get("remolques_activos") as Dictionary
		if remolques:
			var mi_ruta = _get_mi_ruta_escena()
			for truck_key in remolques:
				var entry = remolques[truck_key] as Dictionary
				if entry and entry.get("trailer_scene", "") == mi_ruta:
					entry["tipo_ruedas"] = tipo_ruedas
					break

	var raycasts: Array = []
	_gather_raycasts(self, raycasts)
	for rc in raycasts:
		if rc is RayCast3D:
			(rc as RayCast3D).add_exception(camion)
	# Las patas permanecen abajo hasta que el jugador las suba manualmente a pie (o arranque el camión)

func desenganchado_de(camion: RigidBody3D) -> void:
	var raycasts: Array = []
	_gather_raycasts(self, raycasts)
	for rc in raycasts:
		if rc is RayCast3D:
			(rc as RayCast3D).remove_exception(camion)
	_cuerpo_camion = null
	_snap_done = false
	_bajar_patas()
	var gv := get_node_or_null("/root/GestorVehiculos")
	if gv and gv.has_method("guardar_ubicacion_vehiculo"):
		gv.call("guardar_ubicacion_vehiculo", self)
	call_deferred("_snap_to_ground")

func _subir_patas() -> void:
	patas_abajo = false
	desactivar_patas()
	_actualizar_aspecto_flecha()
	if not _nodo_patas:
		print("[Patas] ERROR: _nodo_patas es null al intentar subir")
		return
	if _tween_patas:
		_tween_patas.kill()
	_tween_patas = create_tween()
	var target := Vector3(_patas_pos_original.x, _patas_pos_original.y + patas_subida_y, _patas_pos_original.z)
	print("[Patas] Subiendo patas de ", _nodo_patas.position, " a ", target)
	_tween_patas.tween_property(_nodo_patas, "position", target, patas_velocidad_subida).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween_patas.tween_callback(func():
		if is_instance_valid(_audio_patas):
			_audio_patas.pitch_scale = randf_range(1.15, 1.25)
			_audio_patas.play()
		print("[Patas] Patas completamente subidas.")
	)
	if has_node("/root/NotificationManager"):
		get_node("/root/NotificationManager").notificar_exito("¡Patas subidas! El camión ya puede arrancar.")

func _bajar_patas() -> void:
	patas_abajo = true
	activar_patas()
	_actualizar_aspecto_flecha()
	if not _nodo_patas:
		print("[Patas] ERROR: _nodo_patas es null al intentar bajar")
		return
	if _tween_patas:
		_tween_patas.kill()
	_tween_patas = create_tween()
	print("[Patas] Bajando patas de ", _nodo_patas.position, " a ", _patas_pos_original)
	_tween_patas.tween_property(_nodo_patas, "position", _patas_pos_original, patas_velocidad_subida).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween_patas.tween_callback(func():
		if is_instance_valid(_audio_patas):
			_audio_patas.pitch_scale = randf_range(0.85, 0.95)
			_audio_patas.play()
		print("[Patas] Patas completamente bajadas en el suelo.")
	)

func _gather_raycasts(node: Node, out_array: Array) -> void:
	for c in node.get_children():
		if c is RayCast3D:
			out_array.append(c)
		_gather_raycasts(c, out_array)

func _gather_collision_shapes(node: Node, out_array: Array[CollisionShape3D]) -> void:
	for c in node.get_children():
		if c is CollisionShape3D:
			out_array.append(c)
		_gather_collision_shapes(c, out_array)

func _gather_collision_objects(node: Node, out_array: Array) -> void:
	if node is CollisionObject3D:
		out_array.append(node)
	for c in node.get_children():
		if c is CollisionObject3D:
			out_array.append(c)
		_gather_collision_objects(c, out_array)

func _tiene_reconexion_activa() -> bool:
	var datos = get_node_or_null("/root/DatosUsuario")
	if not datos:
		return false
	var mi_ruta = _get_mi_ruta_escena()
	if typeof(datos.remolques_activos) == TYPE_DICTIONARY:
		for t_key in datos.remolques_activos:
			var entry = datos.remolques_activos[t_key] as Dictionary
			if not entry:
				continue
			var t_name := str(entry.get("trailer_name", ""))
			if t_name != "" and t_name == str(name):
				return true
			if t_name == "" and mi_ruta != "" and str(entry.get("trailer_scene", "")) == mi_ruta:
				return true
	if typeof(datos.vehiculos_posiciones) == TYPE_DICTIONARY and datos.vehiculos_posiciones.has(str(name)):
		var v_data = datos.vehiculos_posiciones[str(name)] as Dictionary
		if v_data.get("enganchado_a", "") != "":
			return true
	return false


func _snap_to_ground() -> void:
	if _snap_done or esta_enganchado():
		return

	# Seguridad anti-desenganche (BUG-009): Si los datos guardados indican que este remolque
	# estaba acoplado a un camión, NO alterar la altura Y del kingpin para no quebrar el joint físico!
	if _tiene_reconexion_activa():
		_snap_done = true
		return

	_snap_done = true

	var raycasts := []
	_gather_raycasts(self, raycasts)
	var colliders := []
	_gather_collision_objects(self, colliders)
	var max_delta: float = 0.0
	for rc in raycasts:
		if rc is RayCast3D and rc.enabled:
			for col in colliders:
				rc.add_exception(col)
			rc.force_raycast_update()
			if rc.is_colliding():
				var cp: Vector3 = rc.get_collision_point()
				var desired_len: float = 0.0
				if rc.has_method("configurar_desde_masa") or "radio_rueda" in rc:
					var r_rueda: float = float(rc.get("radio_rueda")) if "radio_rueda" in rc else 0.52
					var l_repo: float = float(rc.get("largo_reposo")) if "largo_reposo" in rc else 0.16
					desired_len = r_rueda + l_repo * 0.70
				elif rc.target_position.y != 0.0:
					desired_len = abs(rc.target_position.y) - 0.25
				else:
					desired_len = rc.target_position.length() - 0.25
				var desired_origin_y: float = cp.y + desired_len
				var delta: float = desired_origin_y - rc.global_position.y
				if delta > max_delta:
					max_delta = delta
				if debug_patas:
					print("_snap_to_ground: rc=", rc.name, " cp=", cp, " desired_len=", desired_len, " delta=", delta, " collider=", rc.get_collider())

	if max_delta > snap_clamp_max:
		max_delta = snap_clamp_max

	if max_delta > 0.001:
		global_transform.origin.y += max_delta
		if debug_patas:
			print("_snap_to_ground: moved trailer up by ", max_delta)

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var _tree = get_tree()
	if _tree:
		await _tree.physics_frame
		await _tree.physics_frame
		await _tree.physics_frame
	if not is_instance_valid(self) or not is_inside_tree() or esta_enganchado():
		return
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	sleeping = false

func _reconectar_si_activo() -> void:
	if esta_enganchado():
		return
	var datos = get_node_or_null("/root/DatosUsuario")
	if not datos:
		return
	var remolques = datos.get("remolques_activos") as Dictionary
	if not remolques or remolques.is_empty():
		return
	var mi_ruta = _get_mi_ruta_escena()
	if mi_ruta == "":
		return
	for truck_key in remolques:
		var entry = remolques[truck_key] as Dictionary
		if not entry:
			continue
		var entry_t_name := str(entry.get("trailer_name", ""))
		if entry_t_name != "" and entry_t_name != str(name):
			continue
		if entry.get("trailer_scene", "") != mi_ruta:
			continue
		var truck_name = entry.get("truck_name", "")
		var hitch_name = entry.get("hitch_name", "Enganche")
		if truck_name == "":
			continue
		var truck = get_tree().current_scene.find_child(truck_name, true, false) if get_tree() and get_tree().current_scene else null
		if not truck:
			continue
		var hitch = truck.find_child(hitch_name, true, false)
		if not hitch or not hitch.has_method("_conectar_a"):
			continue
		var mi_enganche = _find_my_hitch()
		if not mi_enganche:
			continue

		# Alinear remolque físicamente a la quinta rueda antes de activar el joint
		var marker = hitch.find_child("Marker3D", true, false)
		var marker_pos = marker.global_position if marker else hitch.global_position
		global_transform.basis = truck.global_transform.basis
		var local_pin = to_local(mi_enganche.global_position)
		global_position = marker_pos - (global_transform.basis * local_pin)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		hitch.call("_conectar_a", mi_enganche, true)
		var t_ruedas = entry.get("tipo_ruedas", "")
		if t_ruedas != "":
			aplicar_tipo_ruedas(t_ruedas)
		print("[Carpado] Re-enganchado automaticamente a: ", truck_name)
		return

func _find_my_hitch() -> Node:
	for c in get_children():
		if c.has_method("_conectar_a") or c.get("es_remolque") == true:
			return c
	for c in get_children():
		var sub = _find_hitch_recursive(c)
		if sub:
			return sub
	return null

func _find_hitch_recursive(n: Node) -> Node:
	for c in n.get_children():
		if c.has_method("_conectar_a") or c.get("es_remolque") == true:
			return c
		var sub = _find_hitch_recursive(c)
		if sub:
			return sub
	return null

func _get_mi_ruta_escena() -> String:
	var escena = scene_file_path
	if escena != "":
		return escena
	var owner_node = owner
	if owner_node and owner_node.scene_file_path != "":
		return owner_node.scene_file_path
	return ""


func actualizar_carga(peso_carga: float) -> void:
	var nuevo_peso = maxf(peso_carga, 0.0)
	if not is_equal_approx(peso, nuevo_peso):
		peso = nuevo_peso
	_aplicar_peso_carga(nuevo_peso)


func _aplicar_peso_carga(peso_carga_actual: float) -> void:
	mass = mass_kg + peso_carga_actual
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = _calcular_centro_de_masa(peso_carga_actual)
	
	# Recalcular dinámicamente la suspensión de las ruedas para la fracción de peso que soportan
	_configurar_ruedas()

## Calcula el centro de masa de forma físicamente distribuida entre el enganche y los ejes traseros
func _calcular_centro_de_masa(peso_carga_actual: float) -> Vector3:
	if not balance_automatico_distribuido:
		return Vector3(0.0, cm_offset_y, cm_offset_z)

	# Puntos de apoyo longitudinales del trailer
	var z_hitch: float = -5.61 # Pivote del enganche con la quinta rueda
	var z_axles: float = 4.90 # Centro geométrico de los 3 ejes traseros
	var largo_apoyos: float = z_axles - z_hitch # 10.51 m
	
	# Posición longitudinal del centro de masa de la carga
	# Con porcentaje_carga_a_ruedas = 0.50 -> Z = -5.61 + 0.50 * 10.51 = -0.355 m (equilibrio 50% / 50%)
	var z_carga: float = z_hitch + (porcentaje_carga_a_ruedas * largo_apoyos)
	
	var m_vacia: float = mass_kg
	var m_total: float = maxf(m_vacia + peso_carga_actual, 1.0)
	
	# Distribución combinada del centro de masa (chasis en vacío + carga distribuida uniformemente)
	var z_final: float = (m_vacia * cm_offset_z_vacio + peso_carga_actual * z_carga) / m_total
	var factor_carga: float = clampf(peso_carga_actual / 45000.0, 0.0, 1.0)
	var y_final: float = lerpf(cm_offset_y_vacio, cm_offset_y_cargado, factor_carga)
	
	cm_offset_z = z_final
	cm_offset_y = y_final
	return Vector3(0.0, y_final, z_final)


# ═══════════════════════════════════════════════════════════════════════
# BOTÓN INTERACTIVO SPRITE3D DE PATAS DE APOYO (FLECHA)
# ═══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	_actualizar_presencia_jugador_patas(delta)

	# Mantener el botón táctil 2D posicionado exactamente sobre el Sprite3D en pantalla
	if _sprite_patas_visible and is_instance_valid(_sprite_patas) and _sprite_patas.visible:
		var cam := get_viewport().get_camera_3d()
		if cam and not cam.is_position_behind(_sprite_patas.global_position):
			var sp := cam.unproject_position(_sprite_patas.global_position)
			if is_instance_valid(_btn_pantalla_patas):
				_btn_pantalla_patas.global_position = sp - _btn_pantalla_patas.size * 0.5
				_btn_pantalla_patas.visible = true
		else:
			if is_instance_valid(_btn_pantalla_patas):
				_btn_pantalla_patas.visible = false
	else:
		if is_instance_valid(_btn_pantalla_patas):
			_btn_pantalla_patas.visible = false


func _crear_boton_sprite_patas() -> void:
	if not _nodo_patas:
		return

	var ruta_flecha = "res://recursos/botones/flecha.svg"
	if not ResourceLoader.exists(ruta_flecha):
		return
	var tex = load(ruta_flecha) as Texture2D
	if not tex:
		return

	# Audio 3D para clank mecánico de patas
	if not is_instance_valid(_audio_patas):
		_audio_patas = AudioStreamPlayer3D.new()
		_audio_patas.name = "AudioPatas"
		_audio_patas.max_distance = 25.0
		_audio_patas.unit_size = 4.0
		var snd_path = "res://recursos/sonidos_vehiculo/sonidos_metalicos/clank.mp3"
		if ResourceLoader.exists(snd_path):
			_audio_patas.stream = load(snd_path)
		_nodo_patas.add_child(_audio_patas)

	# Sprite3D indicador flotante
	_sprite_patas = Sprite3D.new()
	_sprite_patas.name = "BotonPatasSprite3D"
	_sprite_patas.texture = tex
	_sprite_patas.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite_patas.pixel_size = 0.0014
	_sprite_patas.shaded = false
	_sprite_patas.no_depth_test = true
	_sprite_patas.render_priority = 3
	_sprite_patas.visible = false
	_sprite_patas.modulate = Color(1.0, 0.45, 0.0, 0.0)

	# Ubicación exterior accesible a pie (costado izquierdo del trailer, altura ergonómica)
	var local_pata = _nodo_patas.position
	_pos_base_sprite = local_pata + Vector3(-1.35, 0.85, 0.0)
	_sprite_patas.position = _pos_base_sprite
	_nodo_patas.get_parent().add_child(_sprite_patas)


	# Etiqueta de texto indicador estilizado con fuente Moderniz
	_label_patas = Label3D.new()
	_label_patas.name = "TextoPatas"
	_label_patas.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_patas.pixel_size = 0.0028
	_label_patas.no_depth_test = true
	_label_patas.render_priority = 4
	_label_patas.position = Vector3(0, 0.44, 0)
	_label_patas.font_size = 28
	_label_patas.outline_size = 8
	_label_patas.modulate = Color(1.0, 0.45, 0.0)
	_label_patas.outline_modulate = Color(0.06, 0.06, 0.08, 0.95)
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		_label_patas.font = load(font_path)
	_label_patas.text = "▲ SUBIR"
	_sprite_patas.add_child(_label_patas)

	# CanvasLayer UI táctil (capa 125, superior a controles HUD existentes para garantizar recepción de toques)
	_crear_ui_tactil_patas()

	_actualizar_aspecto_flecha()


func _crear_ui_tactil_patas() -> void:
	if is_instance_valid(_canvas_patas):
		_canvas_patas.queue_free()

	_canvas_patas = CanvasLayer.new()
	_canvas_patas.name = "CanvasPatas"
	_canvas_patas.layer = 125
	add_child(_canvas_patas)

	# Botón táctil transparente que se posiciona en la pantalla justo sobre el Sprite3D
	_btn_pantalla_patas = Button.new()
	_btn_pantalla_patas.name = "BtnPantallaPatas"
	_btn_pantalla_patas.custom_minimum_size = Vector2(160, 160)
	_btn_pantalla_patas.size = Vector2(160, 160)
	_btn_pantalla_patas.flat = true
	_btn_pantalla_patas.focus_mode = Control.FOCUS_NONE
	_btn_pantalla_patas.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_pantalla_patas.visible = false
	_btn_pantalla_patas.pressed.connect(_interactuar_patas)
	_canvas_patas.add_child(_btn_pantalla_patas)

	_actualizar_aspecto_flecha()


func _input(event: InputEvent) -> void:
	if not _sprite_patas_visible or not is_instance_valid(_sprite_patas) or not _sprite_patas.visible:
		return

	# Teclado físico para PC (E, Q, F, Espacio o acción "interactuar")
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E or event.keycode == KEY_Q or event.keycode == KEY_F or event.keycode == KEY_SPACE or event.is_action_pressed("interactuar"):
			print("[Patas] Tecla física interactuar presionada: ", event.as_text())
			_interactuar_patas()
			get_viewport().set_input_as_handled()
			return


func _interactuar_patas() -> void:
	# Debounce riguroso para evitar que toques rápidos o disparos dobles alternen el estado en el mismo frame
	var ahora_ms: int = Time.get_ticks_msec()
	if ahora_ms - _ultimo_tiempo_interaccion_ms < 600:
		print("[Patas] Pulsación ignorada por debounce (", ahora_ms - _ultimo_tiempo_interaccion_ms, "ms)")
		return
	if is_instance_valid(_tween_patas) and _tween_patas.is_running():
		print("[Patas] Animación de patas en curso, ignorando nueva pulsación.")
		return
	_ultimo_tiempo_interaccion_ms = ahora_ms

	print("[Patas] _interactuar_patas() ejecutado. Acción: ", "SUBIR PATAS" if patas_abajo else "BAJAR PATAS")

	# Efecto visual de rebote al pulsar ("punch scale")
	if is_instance_valid(_sprite_patas):
		var tw_punch = create_tween()
		tw_punch.tween_property(_sprite_patas, "scale", Vector3.ONE * 0.45, 0.08).set_ease(Tween.EASE_OUT)
		tw_punch.tween_property(_sprite_patas, "scale", Vector3.ONE * 0.70, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Sonido mecánico de activación
	if is_instance_valid(_audio_patas):
		_audio_patas.pitch_scale = randf_range(0.95, 1.05)
		_audio_patas.play()

	if patas_abajo:
		_subir_patas()
	else:
		_bajar_patas()


func _actualizar_aspecto_flecha() -> void:
	if not is_instance_valid(_sprite_patas):
		return
	if patas_abajo:
		# Patas abajo: Flecha mirando hacia ARRIBA por defecto para SUBIR patas
		_sprite_patas.flip_v = false
		_sprite_patas.modulate = Color(1.00, 0.45, 0.00, _sprite_patas.modulate.a)
		if is_instance_valid(_label_patas):
			_label_patas.text = "▲ SUBIR"
			_label_patas.modulate = Color(1.00, 0.45, 0.00)
	else:
		# Patas arriba: Flecha invertida mirando hacia ABAJO para BAJAR patas
		_sprite_patas.flip_v = true
		_sprite_patas.modulate = Color(0.20, 0.85, 1.00, _sprite_patas.modulate.a)
		if is_instance_valid(_label_patas):
			_label_patas.text = "▼ BAJAR"
			_label_patas.modulate = Color(0.20, 0.85, 1.00)


func _actualizar_presencia_jugador_patas(_delta: float) -> void:
	if not is_instance_valid(_sprite_patas) or not is_instance_valid(_nodo_patas):
		return

	var tree = get_tree()
	if not tree:
		return
	var j = tree.get_first_node_in_group("jugador")
	if not is_instance_valid(j):
		j = tree.get_first_node_in_group("player")

	var iv = get_node_or_null("/root/InputVehiculo")
	var conduciendo: bool = iv and "conduciendo" in iv and iv.conduciendo

	var mostrar = false
	if not conduciendo and is_instance_valid(j) and (j is Node3D):
		var dist = _nodo_patas.global_position.distance_to((j as Node3D).global_position)
		mostrar = dist <= 4.8

	if mostrar != _sprite_patas_visible:
		_mostrar_ocultar_sprite_patas(mostrar)

	if _sprite_patas_visible and _sprite_patas.visible:
		# Animación de respiración / flotación sutil en Y
		var hover = sin(Time.get_ticks_msec() * 0.0035) * 0.04
		_sprite_patas.position.y = _pos_base_sprite.y + hover


func _mostrar_ocultar_sprite_patas(mostrar: bool) -> void:
	_sprite_patas_visible = mostrar
	if _tween_sprite_patas:
		_tween_sprite_patas.kill()
	_tween_sprite_patas = create_tween().set_parallel(true)

	if mostrar:
		_actualizar_aspecto_flecha()
		_sprite_patas.visible = true
		_sprite_patas.scale = Vector3.ZERO
		_sprite_patas.modulate.a = 0.0
		# Aparición interesante con pop-up elástico y fade in
		_tween_sprite_patas.tween_property(_sprite_patas, "scale", Vector3.ONE * 0.70, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_tween_sprite_patas.tween_property(_sprite_patas, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	else:
		# Desaparición suave
		_tween_sprite_patas.tween_property(_sprite_patas, "scale", Vector3.ZERO, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		_tween_sprite_patas.tween_property(_sprite_patas, "modulate:a", 0.0, 0.18)
		_tween_sprite_patas.chain().tween_callback(func():
			if is_instance_valid(_sprite_patas) and not _sprite_patas_visible:
				_sprite_patas.visible = false
			if is_instance_valid(_btn_pantalla_patas) and not _sprite_patas_visible:
				_btn_pantalla_patas.visible = false
		)

