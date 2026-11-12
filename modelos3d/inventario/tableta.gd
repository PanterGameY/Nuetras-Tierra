extends Node3D

@onready var pantalla: MeshInstance3D = $Pantalla

func _ready() -> void:
	# Create SubViewport dynamically
	var viewport = SubViewport.new()
	viewport.size = Vector2(520, 860) # Matches the default screen size of CelularUI.tscn
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true # Only rendering 2D elements in the phone UI
	add_child(viewport)

	# Instance CelularUI
	var celular_ui = load("res://interfaz/celular/sistema/CelularUI.tscn").instantiate()
	
	# Set start properties before adding to tree
	celular_ui.current_app = "waze"
	
	# Find player and assign
	var player = _find_player()
	if player:
		celular_ui.player = player
	
	viewport.add_child(celular_ui)

	# Wait a frame for setup to complete, then make sure it is open and in Waze app
	await get_tree().process_frame
	celular_ui.is_open = true
	celular_ui.target_y_offset = 0
	celular_ui.current_y_offset = 0
	if celular_ui.has_method("_switch_app"):
		celular_ui.call("_switch_app", "waze")

	# Create material override for screen mesh surface
	var material = StandardMaterial3D.new()
	material.albedo_texture = viewport.get_texture()
	material.roughness = 0.15
	material.metallic = 0.1
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Unshaded so it stays bright/visible in dark cabins
	
	# Apply material to surface 0 of the screen (Pantalla)
	if pantalla:
		pantalla.set_surface_override_material(0, material)

func _find_player() -> Node:
	# Search by group
	var p = get_tree().get_first_node_in_group("jugador")
	if p:
		return p
	# Search recursively from root
	return _find_player_recursive(get_tree().root)

func _find_player_recursive(node: Node) -> Node:
	if node.name.to_lower().contains("jugador") or node.name.to_lower().contains("player"):
		if node is CharacterBody3D:
			return node
	for child in node.get_children():
		var res = _find_player_recursive(child)
		if res:
			return res
	return null
