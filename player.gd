extends CharacterBody3D

const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const ACCELERATION = 10.0
const DECELERATION = 8.0

# Para el movimiento realista de la cámara (Head Bob)
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D # Necesitamos esta referencia
@onready var blur_rect = $CameraPivot/Camera3D/ColorRect

var mouse_sensitivity = 0.002 # Bajé un poco esto para que sea más controlable

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta):
	if Input.is_action_just_pressed("quit"):
		# 1. Hacemos visible el mouse para poder interactuar con el menú
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# 2. Cambiamos a la escena del menú principal
		get_tree().change_scene_to_file("res://MainMenu.tscn")

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -deg_to_rad(80), deg_to_rad(80))

func _head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _physics_process(delta: float) -> void:
	# 1. Determinar velocidad
	var current_speed = WALK_SPEED
	if Input.is_action_pressed("shift"):
		current_speed = SPRINT_SPEED
		
	# 2. Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 3. Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 4. Movimiento
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, DECELERATION * delta)

	# 5. Lógica del Head Bob (Balanceo)
	if is_on_floor() and velocity.length() > 0.1:
		t_bob += delta * velocity.length()
		camera.transform.origin = _head_bob(t_bob)
	else:
		# Volver a la posición original suavemente
		camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 10)

	var is_running = Input.is_action_pressed("shift") and velocity.length() > 0.1
	var target_blur = 2.5 if is_running else 0.0 # Puedes subirlo un poco más aquí

	var current_blur = blur_rect.material.get_shader_parameter("blur_amount")
	var new_blur = lerp(current_blur, target_blur, delta * 4.0)

	blur_rect.material.set_shader_parameter("blur_amount", new_blur)

	move_and_slide()
