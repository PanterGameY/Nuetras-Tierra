extends Node

const PLAYER_SCENE = "res://modelos3d/personajes/Jugador/Jugador.tscn"
const VEHICLE_SCENE = "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_Alargada.tscn"

var _spawn_index: int = 0  # Indice incremental para offsets de posicion

var _debug_label: RichTextLabel
var _debug_canvas: CanvasLayer

func _print_on_screen(text: String) -> void:
	print(text)
	call_deferred("_add_to_screen_log", text)

func _add_to_screen_log(text: String) -> void:
	if not _debug_canvas:
		_debug_canvas = CanvasLayer.new()
		_debug_canvas.layer = 120
		
		var panel = PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.size = Vector2(500, 300)
		panel.position = Vector2(20, 80)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.7)
		panel.add_theme_stylebox_override("panel", style)
		
		_debug_label = RichTextLabel.new()
		_debug_label.bbcode_enabled = true
		_debug_label.scroll_following = true
		panel.add_child(_debug_label)
		_debug_canvas.add_child(panel)
		
		var parent = get_parent()
		if parent:
			parent.add_child(_debug_canvas)
			
	if _debug_label:
		_debug_label.text += text + "\n"

func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
		
	_print_on_screen("[MultiplayerManager] Iniciando modo multijugador (RPC)...")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ocultar (no liberar todavia) los nodos locales de la escena por defecto.
	for node_name in ["../Jugador2", "../T800_Alargada", "../RigidBody3D"]:
		var n = get_node_or_null(node_name)
		if n:
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
			
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		# Spawnear al host localmente solo si no es servidor dedicado/headless
		if DisplayServer.get_name() != "headless":
			_spawn_player_and_vehicle(1)
		_limpiar_nodos_default.call_deferred()
	else:
		_print_on_screen("[MultiplayerManager] Cliente listo, enviando peer_listo al host y registrando nombre...")
		var red = get_node_or_null("/root/RedManager")
		if red:
			red.registrar_nombre_jugador.rpc(multiplayer.get_unique_id(), DatosUsuario.nombre_usuario)
		peer_listo.rpc_id(1)

# Spawnea una entidad en todos los clientes conectados (incluyendo localmente)
@rpc("authority", "call_local")
func spawn_entidad(type: String, peer_id: int, pos: Vector3) -> void:
	_print_on_screen("[MultiplayerManager] spawn_entidad: " + type + " para peer " + str(peer_id) + " en " + str(pos))
	
	if type == "player":
		if get_parent().has_node("Jugador_" + str(peer_id)):
			_print_on_screen("[MultiplayerManager] Jugador_" + str(peer_id) + " ya existe. Omitiendo.")
			return
			
		var scene = load(PLAYER_SCENE)
		var player = scene.instantiate()
		player.name = "Jugador_" + str(peer_id)
		player.set_multiplayer_authority(peer_id)
		player.position = pos
		_add_synchronizer(player, peer_id, {
			".:global_position": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:global_rotation": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:velocity": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:_conduciendo": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
			".:_anim_actual": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		})
		get_parent().add_child(player, true) # force_readable_name = true
		
		# Activar la camara y UI del jugador LOCAL
		if peer_id == multiplayer.get_unique_id():
			_print_on_screen("[MultiplayerManager] Es nuestro propio jugador local! Activando camara...")
			_activar_camara_deferred.call_deferred(player)
			
	elif type == "vehicle":
		if get_parent().has_node("Vehiculo_" + str(peer_id)):
			_print_on_screen("[MultiplayerManager] Vehiculo_" + str(peer_id) + " ya existe. Omitiendo.")
			return
			
		var scene = load(VEHICLE_SCENE)
		var vehicle = scene.instantiate()
		vehicle.name = "Vehiculo_" + str(peer_id)
		vehicle.set_multiplayer_authority(peer_id)
		vehicle.position = pos
		_add_synchronizer(vehicle, peer_id, {
			".:global_position": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:global_rotation": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:linear_velocity": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:angular_velocity": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:activo": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
			".:luces_emergencia": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
			".:direccional_izquierda": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
			".:direccional_derecha": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		})
		get_parent().add_child(vehicle, true)

func _limpiar_nodos_default() -> void:
	_print_on_screen("[MultiplayerManager] _limpiar_nodos_default llamado.")
	for node_name in ["Jugador2", "T800_Alargada", "RigidBody3D"]:
		var n = get_parent().get_node_or_null(node_name)
		if n and is_instance_valid(n):
			n.queue_free()
			_print_on_screen("[MultiplayerManager] Nodo default liberado: " + node_name)

func _activar_camara_deferred(player_node: Node) -> void:
	_print_on_screen("[MultiplayerManager] _activar_camara_deferred para " + player_node.name)
	if not is_instance_valid(player_node):
		return
	var cam = player_node.find_child("Camera3D", true, false)
	if cam:
		cam.make_current()
		_print_on_screen("[MultiplayerManager] Camara activada!")
	else:
		_print_on_screen("[MultiplayerManager] No se encontro Camera3D")
	
	_limpiar_nodos_default()

# Llamado por el cliente cuando se ha cargado la escena para que el host le envíe el estado del juego
@rpc("any_peer", "call_remote")
func peer_listo() -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	_print_on_screen("[MultiplayerManager] Host: peer " + str(peer_id) + " listo.")
	
	# Enviar nombres registrados al cliente que se unió tarde
	var red = get_node_or_null("/root/RedManager")
	if red:
		for p_id in red.nombres_jugadores.keys():
			red.registrar_nombre_jugador.rpc_id(peer_id, p_id, red.nombres_jugadores[p_id])
	
	# Enviar al nuevo cliente los personajes y vehículos que ya existen en el juego
	var host_player = get_parent().get_node_or_null("Jugador_1")
	if host_player:
		spawn_entidad.rpc_id(peer_id, "player", 1, host_player.position)
	var host_vehicle = get_parent().get_node_or_null("Vehiculo_1")
	if host_vehicle:
		spawn_entidad.rpc_id(peer_id, "vehicle", 1, host_vehicle.position)
		
	# Enviar también el resto de clientes conectados
	for p_id in multiplayer.get_peers():
		if p_id == peer_id:
			continue
		var other_player = get_parent().get_node_or_null("Jugador_" + str(p_id))
		if other_player:
			spawn_entidad.rpc_id(peer_id, "player", p_id, other_player.position)
		var other_vehicle = get_parent().get_node_or_null("Vehiculo_" + str(p_id))
		if other_vehicle:
			spawn_entidad.rpc_id(peer_id, "vehicle", p_id, other_vehicle.position)
			
	# Ahora spawnear al nuevo cliente en todos los peers
	_spawn_player_and_vehicle(peer_id)
	notificar_conexion_jugador.rpc(peer_id)
	
	# Forzar la actualización de visibilidad en los sincronizadores existentes del host
	# para que comiencen a enviar actualizaciones al nuevo cliente que se unió tarde.
	for child in get_parent().get_children():
		var sync_node = child.get_node_or_null("Sync")
		if sync_node and sync_node is MultiplayerSynchronizer:
			sync_node.update_visibility()

func _on_peer_connected(peer_id: int) -> void:
	_print_on_screen("[MultiplayerManager] Peer conectado a red: " + str(peer_id))

func _on_peer_disconnected(peer_id: int) -> void:
	_print_on_screen("[MultiplayerManager] Peer desconectado de red: " + str(peer_id))
	var player = get_parent().get_node_or_null("Jugador_" + str(peer_id))
	if player:
		player.queue_free()
	var vehicle = get_parent().get_node_or_null("Vehiculo_" + str(peer_id))
	if vehicle:
		vehicle.queue_free()

func _spawn_player_and_vehicle(peer_id: int) -> void:
	_print_on_screen("[MultiplayerManager] Solicitando spawn de jugador/vehiculo para peer: " + str(peer_id))
	
	var offset = Vector3(_spawn_index * 8.0, 0, 0)
	_spawn_index += 1
	
	var v_pos = Vector3(-25.531, 0.47, 394.62) + offset
	var p_pos = Vector3(-47.79, 0.87, 404.60) + offset
	
	# El host llama a spawn_entidad via RPC a todos (incluyendo localmente)
	spawn_entidad.rpc("vehicle", peer_id, v_pos)
	spawn_entidad.rpc("player", peer_id, p_pos)

func _add_synchronizer(node: Node, authority: int, properties: Dictionary) -> void:
	var sync = MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.set_multiplayer_authority(authority)
	var replication_config = SceneReplicationConfig.new()
	for prop in properties.keys():
		var mode = properties[prop]
		replication_config.add_property(prop)
		replication_config.property_set_replication_mode(prop, mode)
	sync.replication_config = replication_config
	node.add_child(sync)

@rpc("any_peer", "call_local")
func notificar_conexion_jugador(peer_id: int) -> void:
	var red = get_node_or_null("/root/RedManager")
	var p_name = red.nombres_jugadores.get(peer_id, "JUGADOR " + str(peer_id)) if red else "JUGADOR"
	_mostrar_notificacion(p_name.to_upper() + " SE HA UNIDO A LA PARTIDA")

func _mostrar_notificacion(texto: String) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	
	var font = preload("res://recursos/fonts/Moderniz.otf")
	
	var label = Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.12, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.008, 0.43, 0.8, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	canvas.add_child(panel)
	get_parent().add_child(canvas)
	
	# Posicionar centrado en la parte superior
	panel.anchors_preset = Control.PRESET_CENTER_TOP
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.set_deferred("position", Vector2(
		(get_viewport().get_visible_rect().size.x - panel.size.x) / 2.0, 50
	))
	
	var tw = create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(panel, "modulate:a", 0.0, 1.0)
	tw.finished.connect(func(): canvas.queue_free())
