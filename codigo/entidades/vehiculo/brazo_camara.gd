extends Node3D

@export var objetivo: Node3D
@export var sensibilidad_rotacion: float = 0.15
@export var sensibilidad_zoom: float = 0.02
@export var limite_pitch: Vector2 = Vector2(-45.0, 25.0)

var yaw: float = 0.0
var pitch: float = 0.0
var spring_arm: SpringArm3D = null
var _remolque_actual: RigidBody3D = null
var _remolque_rids_excluidos: Array[RID] = []
var _base_spring_length: float = 8.0
var _extra_length_trailer: float = 0.0
var _check_timer: float = 0.0

func _ready() -> void:
	# Configurar como top_level para independizar rotaciones de la física del coche
	set_as_top_level(true)
	
	yaw = rotation_degrees.y
	pitch = rotation_degrees.x
	
	spring_arm = find_child("SpringArm3D", true, false)
	
	if not objetivo:
		var parent = get_parent()
		if parent:
			var parent_parent = parent.get_parent()
			if parent_parent:
				objetivo = parent_parent

	if spring_arm:
		_base_spring_length = spring_arm.spring_length
		if objetivo and objetivo.has_method("get_rid"):
			spring_arm.add_excluded_object(objetivo.get_rid())

var _factor_remolque: float = 0.0

func _physics_process(delta: float) -> void:
	if not objetivo or not is_instance_valid(objetivo):
		return

	_check_timer += delta
	if _check_timer >= 0.25:
		_check_timer = 0.0
		_verificar_remolque()

	var tiene_remolque := _remolque_actual != null and is_instance_valid(_remolque_actual)
	_factor_remolque = lerpf(_factor_remolque, 0.25 if tiene_remolque else 0.0, clampf(2.2 * delta, 0.0, 1.0))

	var target_pos: Vector3 = objetivo.global_position
	if tiene_remolque and _factor_remolque > 0.001:
		target_pos = target_pos.lerp(_remolque_actual.global_position, _factor_remolque)

	global_position = global_position.lerp(target_pos, 1.0 - exp(-12.0 * delta))

	if spring_arm:
		var target_len = _base_spring_length + _extra_length_trailer
		spring_arm.spring_length = lerpf(spring_arm.spring_length, target_len, clamp(2.5 * delta, 0.0, 1.0))

func _verificar_remolque() -> void:
	var remolque: RigidBody3D = null
	var enganche = objetivo.find_child("Enganche", true, false)
	if enganche and enganche.get("conectado") == true:
		var remoto = enganche.get("enganche_remoto")
		if remoto and is_instance_valid(remoto):
			if enganche.has_method("_buscar_cuerpo"):
				remolque = enganche.call("_buscar_cuerpo", remoto) as RigidBody3D
			elif remoto.has_method("_buscar_cuerpo"):
				remolque = remoto.call("_buscar_cuerpo", remoto) as RigidBody3D
			elif remoto.get_parent() is RigidBody3D:
				remolque = remoto.get_parent() as RigidBody3D

	if remolque != _remolque_actual:
		_remolque_actual = remolque
		_aplicar_exclusion_remolque()

func _aplicar_exclusion_remolque() -> void:
	if not spring_arm or not is_instance_valid(spring_arm):
		return
	if _remolque_actual and is_instance_valid(_remolque_actual):
		var stack: Array[Node] = [_remolque_actual]
		while stack.size() > 0:
			var n = stack.pop_back()
			if n is CollisionObject3D:
				var rid = n.get_rid()
				if not _remolque_rids_excluidos.has(rid):
					_remolque_rids_excluidos.append(rid)
					spring_arm.add_excluded_object(rid)
			for ch in n.get_children():
				stack.append(ch)
		_extra_length_trailer = 12.0
	else:
		_remolque_rids_excluidos.clear()
		_extra_length_trailer = 0.0

func _on_camara_movida(relative: Vector2) -> void:
	yaw -= relative.x * sensibilidad_rotacion
	pitch -= relative.y * sensibilidad_rotacion
	pitch = clamp(pitch, limite_pitch.x, limite_pitch.y)
	
	rotation_degrees = Vector3(pitch, yaw, 0.0)

func _on_camara_pinch(delta_dist: float) -> void:
	if spring_arm:
		_base_spring_length = clamp(_base_spring_length - delta_dist * sensibilidad_zoom, 3.0, 30.0)

func set_active(active: bool) -> void:
	set_physics_process(active)
