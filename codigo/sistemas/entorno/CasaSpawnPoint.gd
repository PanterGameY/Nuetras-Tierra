@tool
extends Node3D
class_name CasaSpawnPoint

## CasaSpawnPoint.gd
##
## Coloca este nodo en tu escena 3D (por ejemplo, en el lugar de la casa del jugador)
## para definir la posición de inicio del personaje al entrar al juego por primera vez.
##
## Este punto también se registrará automáticamente en el GPS de Waze como "Casa".

@export_group("Visuales del Checkpoint")
## Color del holograma del checkpoint (se recomienda verde brillante)
@export var checkpoint_color: Color = Color(0.14, 0.85, 0.45, 0.45):
	set(val):
		checkpoint_color = val
		_update_visuals()

## Radio del checkpoint
@export var checkpoint_radius: float = 1.8:
	set(val):
		checkpoint_radius = val
		_update_visuals()

## Altura de la columna de luz
@export var checkpoint_height: float = 3.5:
	set(val):
		checkpoint_height = val
		_update_visuals()

## Velocidad de la pulsación de respiración
@export var pulse_speed: float = 1.5:
	set(val):
		pulse_speed = val
		_update_visuals()

## Intensidad de la pulsación (expansión de tamaño)
@export var pulse_strength: float = 0.08:
	set(val):
		pulse_strength = val
		_update_visuals()

## Velocidad de la onda de escaneo vertical
@export var scan_speed: float = 2.5:
	set(val):
		scan_speed = val
		_update_visuals()

var label_3d: Label3D = null

func _ready() -> void:
	# Limpiar cualquier residuo del visual antiguo del editor si existe
	var legacy_visual = get_node_or_null("_EditorVisual")
	if legacy_visual:
		legacy_visual.queue_free()
		
	_update_visuals()
	
	if not Engine.is_editor_hint():
		add_to_group("CasaSpawnPoint")
		print("[CasaSpawnPoint] Registrado en la escena en la posición: ", global_position)

func _update_visuals() -> void:
	# Asegurarnos de que el árbol esté listo
	if not is_inside_tree():
		return
		
	# 1. Crear o buscar Marker3D para el Checkpoint
	var marker_node = get_node_or_null("Marker3D") as Marker3D
	if not marker_node:
		marker_node = Marker3D.new()
		marker_node.name = "Marker3D"
		add_child(marker_node)
		if Engine.is_editor_hint():
			marker_node.owner = get_tree().edited_scene_root
		
	# 2. Añadir/Actualizar la malla visual del Checkpoint
	var checkpoint_mesh = marker_node.get_node_or_null("CheckpointVisual") as MeshInstance3D
	if not checkpoint_mesh:
		checkpoint_mesh = MeshInstance3D.new()
		checkpoint_mesh.name = "CheckpointVisual"
		marker_node.add_child(checkpoint_mesh)
		if Engine.is_editor_hint():
			checkpoint_mesh.owner = get_tree().edited_scene_root
		
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = checkpoint_radius
	cylinder.bottom_radius = checkpoint_radius
	cylinder.height = checkpoint_height
	cylinder.radial_segments = 32
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	checkpoint_mesh.mesh = cylinder
	
	# Centrar el cilindro para que el pivote de CasaSpawnPoint esté exactamente en el suelo
	checkpoint_mesh.position = Vector3(0, checkpoint_height / 2.0, 0)
	
	# Material con el shader animado
	var shader_res = load("res://shaders/checkpoint.gdshader")
	if shader_res:
		var mat = ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("color_albedo", checkpoint_color)
		mat.set_shader_parameter("scale_pulse_speed", pulse_speed)
		mat.set_shader_parameter("scale_pulse_strength", pulse_strength)
		mat.set_shader_parameter("speed", scan_speed)
		checkpoint_mesh.material_override = mat
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = checkpoint_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		checkpoint_mesh.material_override = mat

	# 3. Crear/Actualizar Label3D para el texto flotante de "Casa"
	var label_node = get_node_or_null("TextoCasa") as Label3D
	if not label_node:
		label_node = Label3D.new()
		label_node.name = "TextoCasa"
		label_node.text = "Casa"
		label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_node.font_size = 48
		label_node.outline_modulate = Color.BLACK
		label_node.outline_size = 12
		add_child(label_node)
		if Engine.is_editor_hint():
			label_node.owner = get_tree().edited_scene_root
		
	# Sincronizar el color del texto y la altura
	label_node.modulate = Color(checkpoint_color.r, checkpoint_color.g, checkpoint_color.b)
	label_node.position = Vector3(0, checkpoint_height + 0.5, 0)
	
	# En el editor queremos ver el texto "Casa" siempre para saber cómo queda
	if Engine.is_editor_hint():
		label_node.visible = true
	else:
		label_node.visible = false
		
	label_3d = label_node

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	# Verificar si el GPS está apuntando a esta casa
	var gps_dirigido_a_casa := false
	# Buscar al jugador usando el grupo oficial "jugador"
	var player = null
	var players = get_tree().get_nodes_in_group("jugador")
	if players.size() > 0:
		player = players[0]
		
	if not player:
		# Fallback a búsqueda en escena por nombre
		var root = get_tree().current_scene if get_tree() else null
		if root:
			player = root.find_child("Jugador2", true, false)
			if not player:
				for child in root.get_children():
					if (child.name.to_int() > 0 or child.name.begins_with("Jugador_")) and child is Node3D:
						player = child
						break
		
	if player and player is Node3D:
		var gps_line = player.get_node_or_null("GPSRutaLinea")
		if gps_line and gps_line.get("active") == true:
			var target_pos = gps_line.get("target_position")
			if target_pos.distance_to(global_position) < 2.0:
				gps_dirigido_a_casa = true
					
		# Mostrar u ocultar el texto según si el GPS nos dirige aquí
		if is_instance_valid(label_3d) and label_3d.visible != gps_dirigido_a_casa:
			label_3d.visible = gps_dirigido_a_casa
