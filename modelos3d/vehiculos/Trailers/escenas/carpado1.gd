extends RigidBody3D

@export var debug_patas: bool = false
@export var auto_snap_on_ready: bool = true
@export var mass_kg: float = 3000.0
@export var cm_offset_y: float = -0.6
@export var cm_offset_z: float = 0.0 ## Desplazamiento longitudinal del centro de masa
@export var linear_damp_override: float = 0.05
@export var angular_damp_override: float = 0.05
@export var gravity_scale_override: float = 1.0
@export var ensure_patas_enabled: bool = true
@export var snap_clamp_max: float = 2.0
@export var patas_subida_y: float = 0.5
@export var patas_velocidad_subida: float = 1.5
var _snap_done: bool = false
var _cuerpo_camion: RigidBody3D = null
var _patas_shape: CollisionShape3D = null
var _nodo_patas: Node3D = null
var _patas_pos_original: Vector3 = Vector3.ZERO
var _tween_patas: Tween = null

func _ready() -> void:
	_eliminar_static_bodies_internos()
	_configurar_ruedas()

	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	mass = mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, cm_offset_y, cm_offset_z)
	linear_damp = linear_damp_override
	angular_damp = angular_damp_override
	gravity_scale = gravity_scale_override

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
	if _nodo_patas:
		_patas_pos_original = _nodo_patas.position

	if auto_snap_on_ready:
		call_deferred("_snap_to_ground")
	else:
		freeze = false
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
	for r in ruedas:
		r.configurar_desde_masa(mass_kg, ruedas.size())

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


func _gather_static_bodies(node: Node, out_array: Array[StaticBody3D]) -> void:
	for c in node.get_children():
		if c is StaticBody3D:
			out_array.append(c as StaticBody3D)
		else:
			_gather_static_bodies(c, out_array)


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
	var raycasts: Array = []
	_gather_raycasts(self, raycasts)
	for rc in raycasts:
		if rc is RayCast3D:
			(rc as RayCast3D).add_exception(camion)
	_subir_patas()

func desenganchado_de(camion: RigidBody3D) -> void:
	var raycasts: Array = []
	_gather_raycasts(self, raycasts)
	for rc in raycasts:
		if rc is RayCast3D:
			(rc as RayCast3D).remove_exception(camion)
	_cuerpo_camion = null
	_snap_done = false
	_bajar_patas()
	call_deferred("_snap_to_ground")

func _subir_patas() -> void:
	if not _nodo_patas:
		return
	if _tween_patas:
		_tween_patas.kill()
	_tween_patas = create_tween()
	var target := _patas_pos_original + Vector3(0, patas_subida_y, 0)
	_tween_patas.tween_property(_nodo_patas, "position", target, patas_velocidad_subida).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _bajar_patas() -> void:
	if not _nodo_patas:
		return
	if _tween_patas:
		_tween_patas.kill()
	_tween_patas = create_tween()
	_tween_patas.tween_property(_nodo_patas, "position", _patas_pos_original, patas_velocidad_subida).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

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

func _snap_to_ground() -> void:
	if _snap_done:
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
				if rc.target_position.y != 0.0:
					desired_len = abs(rc.target_position.y)
				else:
					desired_len = rc.target_position.length()
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
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	sleeping = false

func actualizar_carga(peso_carga: float) -> void:
	var peso_carga_actual = maxf(peso_carga, 0.0)
	mass = mass_kg + peso_carga_actual
	
	# Recalcular dinámicamente la suspensión de las ruedas para soportar el peso de la carga
	var ruedas: Array[RuedaTrailer] = []
	_gather_ruedas(self, ruedas)
	for r in ruedas:
		r.configurar_desde_masa(mass, ruedas.size())
