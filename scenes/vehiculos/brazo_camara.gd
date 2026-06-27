extends Node3D

@export var objetivo: Node3D
@export var sensibilidad_rotacion: float = 0.15
@export var sensibilidad_zoom: float = 0.05
@export var limite_pitch: Vector2 = Vector2(-45.0, 20.0)

var yaw: float = 0.0
var pitch: float = 0.0
var spring_arm: SpringArm3D = null

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
		spring_arm.collision_mask = 0
		if objetivo and objetivo.has_method("get_rid"):
			spring_arm.add_excluded_object(objetivo.get_rid())

func _physics_process(delta: float) -> void:
	if objetivo and is_instance_valid(objetivo):
		# Seguir la posición del objetivo de manera suave e independiente
		global_position = global_position.lerp(objetivo.global_position, 1.0 - exp(-15.0 * delta))

func _on_camara_movida(relative: Vector2) -> void:
	yaw -= relative.x * sensibilidad_rotacion
	pitch -= relative.y * sensibilidad_rotacion
	pitch = clamp(pitch, limite_pitch.x, limite_pitch.y)
	
	rotation_degrees = Vector3(pitch, yaw, 0.0)

func _on_camara_pinch(delta_dist: float) -> void:
	if spring_arm:
		spring_arm.spring_length = clamp(spring_arm.spring_length - delta_dist * sensibilidad_zoom, 3.0, 15.0)

func set_active(active: bool) -> void:
	set_physics_process(active)
