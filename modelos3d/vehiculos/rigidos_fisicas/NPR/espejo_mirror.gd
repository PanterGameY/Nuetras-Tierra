extends MeshInstance3D

@export var rotate_speed = 2.0
@export var camera_distance = 5.0

var camera: Camera3D
var is_mouse_over = false

func _ready():
	# Crear el SubViewport para capturar la vista
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(1024, 1024)
	sub_viewport.transparent_bg = true
	add_child(sub_viewport)
	
	# Crear la cámara
	camera = Camera3D.new()
	sub_viewport.add_child(camera)
	update_camera_position()
	
	# Crear la textura desde el viewport
	var viewport_texture = ViewportTexture.new()
	viewport_texture.viewport_path = sub_viewport.get_path()
	
	# Crear material y asignarlo
	var new_material = StandardMaterial3D.new()
	new_material.albedo_texture = viewport_texture
	new_material.metallic = 0.8
	new_material.roughness = 0.05
	
	material_override = new_material

func update_camera_position():
	if camera:
		var offset = Vector3(0, 1, camera_distance)
		camera.global_position = global_position + offset
		camera.look_at(global_position, Vector3.UP)

func _process(delta):
	# Rotación con flechas si presionas Q/E
	if Input.is_action_pressed("ui_focus_next"):  # E
		rotate_y(rotate_speed * delta)
	if Input.is_action_pressed("ui_focus_prev"):   # Q
		rotate_y(-rotate_speed * delta)
	
	if Input.is_action_pressed("ui_up"):
		rotate_x(-rotate_speed * delta)
	if Input.is_action_pressed("ui_down"):
		rotate_x(rotate_speed * delta)
	
	# Actualizar posición de cámara
	update_camera_position()
