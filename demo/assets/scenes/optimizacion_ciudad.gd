@tool
extends Node3D

# ==========================================
# PARÁMETROS CONFIGURABLES
# ==========================================
@export_category("Configuración de Auto-Chunks")
@export var chunk_size: float = 100.0:
	set(val):
		chunk_size = val
		if is_inside_tree():
			_build_virtual_chunks()
			_on_check_timer_timeout()

@export var max_load_distance: float = 200.0:
	set(val):
		max_load_distance = val
		if is_inside_tree():
			_on_check_timer_timeout()

@export var debug_mode: bool = false

@export_category("Nodos Requeridos")
@export var player: Node3D 
@export var city_root: Node3D 

# ==========================================
# VARIABLES INTERNAS
# ==========================================
var virtual_chunks: Dictionary = {} 
var active_chunks: Array[Vector2i] = []
var last_player_chunk: Vector2i = Vector2i(-9999, -9999)
var fps_label: Label
var _time_since_last_check: float = 0.0
const CHECK_INTERVAL: float = 0.35

func _ready() -> void:
	add_to_group("city_optimizer")
	
	if not Engine.is_editor_hint():
		_setup_fps_ui()
	
	if not player:
		if get_tree():
			player = get_tree().get_first_node_in_group("jugador") as Node3D
			
	if not city_root:
		printerr("ADVERTENCIA: Asigna el City Root en el inspector.")
		return
		
	# 1. Agrupar la ciudad en pedazos virtuales
	_build_virtual_chunks()
	
	# 2. Cargar configuraciones del juego
	update_settings_from_config()

func update_settings_from_config() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	
	var is_opt_enabled = true
	var opt_dist = 200.0
	
	if err == OK:
		is_opt_enabled = cfg.get_value("graficos", "city_optimizer_enabled", true)
		opt_dist = cfg.get_value("graficos", "city_optimizer_dist", 200.0)
	
	if not is_opt_enabled:
		# Mostrar todo de inmediato y detener el optimizador
		for chunk_key in virtual_chunks.keys():
			for node in virtual_chunks[chunk_key]:
				if is_instance_valid(node):
					node.visible = true
					node.process_mode = Node.PROCESS_MODE_INHERIT
		set_process(false)
		if debug_mode:
			print("[CityOptimizer] Desactivado globalmente desde configuración. Todo cargado.")
	else:
		set_process(true)
		max_load_distance = opt_dist
		_on_check_timer_timeout()
		if debug_mode:
			print("[CityOptimizer] Activado. Distancia de carga: ", max_load_distance)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		# Restaurar visibilidad total de los nodos para no guardar la escena recortada en el editor
		for chunk_key in virtual_chunks.keys():
			for node in virtual_chunks[chunk_key]:
				if is_instance_valid(node):
					node.visible = true
					node.process_mode = Node.PROCESS_MODE_INHERIT

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and is_instance_valid(fps_label):
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
		
	# Lógica del temporizador integrada directamente en _process
	_time_since_last_check += delta
	if _time_since_last_check >= CHECK_INTERVAL:
		_time_since_last_check = 0.0
		_on_check_timer_timeout()

# ==========================================
# LÓGICA DE AGRUPACIÓN Y PROTECCIÓN
# ==========================================
func _build_virtual_chunks() -> void:
	virtual_chunks.clear()
	active_chunks.clear()
	last_player_chunk = Vector2i(-9999, -9999)
	
	var nodes_to_chunk: Array[Node3D] = []
	_gather_nodes_to_chunk(city_root, nodes_to_chunk)
	
	for node in nodes_to_chunk:
		var pos = _get_node_global_center(node)
		var chunk_key: Vector2i = Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))
		
		if not virtual_chunks.has(chunk_key):
			virtual_chunks[chunk_key] = []
		virtual_chunks[chunk_key].append(node)
		
		# Apagamos al inicio (respetando carreteras y Floor/terrenos grandes)
		_set_node_active(node, false)

func _gather_nodes_to_chunk(node: Node, out_list: Array[Node3D]) -> void:
	if not node:
		return
	if node is MeshInstance3D:
		out_list.append(node as Node3D)
		return
	for child in node.get_children():
		_gather_nodes_to_chunk(child, out_list)

func _get_node_global_center(node: Node3D) -> Vector3:
	if node is MeshInstance3D and node.mesh:
		var aabb = node.mesh.get_aabb()
		var global_trans = node.global_transform
		return global_trans * (aabb.position + aabb.size * 0.5)
	return node.global_position

func _is_large_or_protected(node: Node3D) -> bool:
	# 1. SISTEMA DE PROTECCIÓN POR NOMBRE: Si es o pertenece a "Carretera", "Floor", "suelo", etc.
	var p = node
	while p != null:
		var n_name = p.name.to_lower()
		if n_name.contains("carretera") or n_name.contains("floor") or n_name.contains("suelo") or n_name.contains("terrain") or n_name.contains("terreno") or n_name.contains("road") or n_name.contains("via") or n_name.contains("pista") or n_name.contains("calle"):
			return true
		p = p.get_parent()
		
	# 2. SISTEMA DE PROTECCIÓN POR TAMAÑO AABB GLOBAL: Si es muy grande horizontalmente, no apagar
	if node is MeshInstance3D and node.mesh:
		var aabb = node.mesh.get_aabb()
		var global_trans = node.global_transform
		
		# Proyectar las extensiones locales del AABB en los ejes X y Z globales
		var extents = aabb.size * 0.5
		var x_axis = global_trans.basis * Vector3(extents.x, 0, 0)
		var y_axis = global_trans.basis * Vector3(0, extents.y, 0)
		var z_axis = global_trans.basis * Vector3(0, 0, extents.z)
		
		var max_x = abs(x_axis.x) + abs(y_axis.x) + abs(z_axis.x)
		var max_z = abs(x_axis.z) + abs(y_axis.z) + abs(z_axis.z)
		var global_width = max_x * 2.0
		var global_depth = max_z * 2.0
		
		# Si supera el límite horizontal de 120 metros, se protege automáticamente (carretera o terreno)
		if global_width > 120.0 or global_depth > 120.0:
			return true
			
	return false

func _set_node_active(node: Node3D, active: bool) -> void:
	if _is_large_or_protected(node):
		node.visible = true
		node.process_mode = Node.PROCESS_MODE_INHERIT
		return
		
	# Comportamiento normal para edificios/props
	node.visible = active
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

# ==========================================
# LÓGICA DE DISTANCIA
# ==========================================
func _find_editor_camera() -> Camera3D:
	if not Engine.is_editor_hint():
		return null
		
	# Acceso directo al viewport 3D del editor de Godot 4
	if Engine.has_singleton("EditorInterface"):
		var ei = Engine.get_singleton("EditorInterface")
		if ei:
			var vp = ei.call("get_editor_viewport_3d", 0)
			if vp and vp.has_method("get_camera_3d"):
				return vp.call("get_camera_3d") as Camera3D
				
	return null

func _get_target_position() -> Vector3:
	# 1. Si estamos en el editor, rastrear la cámara de vista del editor
	if Engine.is_editor_hint():
		var ed_cam = _find_editor_camera()
		if is_instance_valid(ed_cam):
			return ed_cam.global_position
			
	# 2. En tiempo de ejecución normal:
	if not is_instance_valid(player):
		if get_tree():
			player = get_tree().get_first_node_in_group("jugador") as Node3D
			
	if is_instance_valid(player):
		var vehiculo = player.get("_vehiculo_actual")
		if vehiculo and is_instance_valid(vehiculo):
			return vehiculo.global_position
		return player.global_position
		
	var cam = get_viewport().get_camera_3d() if get_viewport() else null
	if is_instance_valid(cam):
		return cam.global_position
		
	return Vector3.ZERO

func _on_check_timer_timeout() -> void:
	var target_pos = _get_target_position()
	var current_chunk: Vector2i = Vector2i(floori(target_pos.x / chunk_size), floori(target_pos.z / chunk_size))
	
	var closest_dist = 9999999.0
	var closest_key = Vector2i(-999, -999)
	for chunk_key in virtual_chunks.keys():
		var chunk_center: Vector3 = Vector3(
			(chunk_key.x * chunk_size) + (chunk_size / 2.0), 
			target_pos.y, 
			(chunk_key.y * chunk_size) + (chunk_size / 2.0)
		)
		var dist = target_pos.distance_to(chunk_center)
		if dist < closest_dist:
			closest_dist = dist
			closest_key = chunk_key
			
	if debug_mode:
		print("[CityOptimizer Debug] Timeout check. Pos: ", target_pos, " | current_chunk: ", current_chunk, " | chunk_size: ", chunk_size, " | virtual_chunks count: ", virtual_chunks.size(), " | closest chunk: ", closest_key, " (dist: ", closest_dist, ", limit: ", max_load_distance, ")")
	
	last_player_chunk = current_chunk
	
	var activated_count = 0
	var deactivated_count = 0
	var max_dist_sq = max_load_distance * max_load_distance
	
	# Procesar visibilidad
	for chunk_key in virtual_chunks.keys():
		var chunk_center: Vector3 = Vector3(
			(chunk_key.x * chunk_size) + (chunk_size / 2.0), 
			target_pos.y, 
			(chunk_key.y * chunk_size) + (chunk_size / 2.0)
		)
		var should_be_active: bool = target_pos.distance_squared_to(chunk_center) <= max_dist_sq
		var is_active: bool = active_chunks.has(chunk_key)
		
		if should_be_active and not is_active:
			for node in virtual_chunks[chunk_key]:
				if is_instance_valid(node):
					_set_node_active(node, true)
					activated_count += 1
			active_chunks.append(chunk_key)
		elif not should_be_active and is_active:
			for node in virtual_chunks[chunk_key]:
				if is_instance_valid(node):
					_set_node_active(node, false)
					deactivated_count += 1
			active_chunks.erase(chunk_key)
			
	if debug_mode:
		print("[CityOptimizer] Position: ", target_pos, " | Chunk: ", current_chunk, " | Activated: ", activated_count, " | Deactivated: ", deactivated_count, " | Active Chunks: ", active_chunks.size())

# ==========================================
# UI
# ==========================================
func _setup_fps_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	fps_label = Label.new()
	canvas.add_child(fps_label)
	fps_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	fps_label.add_theme_font_size_override("font_size", 30)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)