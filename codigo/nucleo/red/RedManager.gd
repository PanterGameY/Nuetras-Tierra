extends Node

# ═══════════════════════════════════════════════════════════════════════
# RedManager.gd — Gestor de Señalización WebSocket (VPS) y Coordinador ENet
# Sincronizado con Network.gd y PrincipalMultijugador.tscn (Máx 5 Jugadores)
# ═══════════════════════════════════════════════════════════════════════

signal salas_actualizadas(salas: Array)
signal jugadores_actualizados()
signal error_conexion(msg: String)
signal sala_creada(sala_id: String)
signal unido_a_sala(sala_id: String)
signal host_desconectado()

const MAX_JUGADORES_SALA: int = 5
const MULTIJUGADOR_SCENE: String = "res://mundo/principal/PrincipalMultijugador.tscn"

var signaling_url_pc: String = "wss://nuestra-tierra-signaling.onrender.com"
var signaling_url_mobile: String = "wss://nuestra-tierra-signaling.onrender.com"
var vps_ip: String = "2.25.71.102"

var ws_peer: WebSocketPeer = WebSocketPeer.new()
var upnp: UPNP = null

var active_connections: Dictionary = {}
var local_peer_id: int = 0
var current_room: String = ""
var is_host: bool = false
var nombres_jugadores: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_check_server_cmdline")

func configurar_endpoints_vps(nueva_ip: String, nueva_ws_url: String) -> void:
	if nueva_ip.strip_edges() != "":
		vps_ip = nueva_ip.strip_edges()
	if nueva_ws_url.strip_edges() != "":
		signaling_url_pc = nueva_ws_url.strip_edges()
		signaling_url_mobile = nueva_ws_url.strip_edges()

func _on_node_added(node: Node) -> void:
	# Soporta tanto la nueva escena PrincipalMultijugador como Principal y Main
	if node.get_parent() == get_tree().root and node.name in ["PrincipalMultijugador", "Principal", "Main"]:
		call_deferred("_setup_multiplayer_manager", node)

func _setup_multiplayer_manager(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_node("MultiplayerManager"):
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		var manager = Node.new()
		manager.name = "MultiplayerManager"
		manager.set_script(preload("res://codigo/nucleo/red/MultiplayerManager.gd"))
		node.add_child(manager)

func _process(_delta: float) -> void:
	if ws_peer.get_ready_state() == WebSocketPeer.STATE_CLOSED and current_room == "":
		return
	ws_peer.poll()
	var state = ws_peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while ws_peer.get_available_packet_count() > 0:
			var packet = ws_peer.get_packet()
			_on_signaling_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED and current_room != "":
		current_room = ""
		error_conexion.emit("DESCONECTADO DEL SERVIDOR DE SEÑALIZACIÓN VPS.")

func conectar_a_senalizacion(url: String = "") -> void:
	if url.strip_edges() == "":
		if OS.get_name() in ["Android", "iOS"]:
			url = signaling_url_mobile
		else:
			url = signaling_url_pc

	ws_peer = WebSocketPeer.new()
	var err = ws_peer.connect_to_url(url)
	if err != OK:
		error_conexion.emit("ERROR AL CONECTAR CON EL SERVIDOR VPS.")

func salir_de_sala() -> void:
	_clean_up_multiplayer()
	consultar_salas()

func get_local_ip() -> String:
	var net = get_node_or_null("/root/Network")
	if net and net.has_method("get_ip_address"):
		return net.get_ip_address()
	return "127.0.0.1"

func crear_sala(room_id: String, room_name: String = "", max_players: int = MAX_JUGADORES_SALA, usar_upnp: bool = false) -> void:
	var cupo = clampi(max_players, 2, MAX_JUGADORES_SALA)
	var net = get_node_or_null("/root/Network")
	if net:
		var err = net.start_server_on_port(10567, cupo, room_name)
		if err != OK:
			error_conexion.emit("ERROR AL INICIAR HOST LOCAL EN PUERTO 10567.")
			return

	is_host = true
	current_room = room_id if room_id != "" else "10567"

	var public_ip := ""
	if usar_upnp:
		public_ip = _setup_upnp(10567)

	# Si el WebSocket de la VPS está abierto, registrar la sala del Host en el listado global
	if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var msg = {
			"action": "create",
			"room": current_room,
			"name": room_name if room_name != "" else ("SALA DE " + _obtener_nombre_usuario().to_upper()),
			"max_players": cupo,
			"port": 10567,
			"ip": get_local_ip()
		}
		if public_ip != "":
			msg["public_ip"] = public_ip
		ws_peer.send_text(JSON.stringify(msg))
	else:
		local_peer_id = 1
		sala_creada.emit(current_room)

func _setup_upnp(port: int = 10567) -> String:
	upnp = UPNP.new()
	var discover_result = upnp.discover(1500, 2, "InternetGatewayDevice")
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		upnp = null
		return ""
	if not upnp.get_gateway() or not upnp.get_gateway().is_valid_gateway():
		upnp = null
		return ""
	var map_result = upnp.add_port_mapping(port, port, "NuestraTierra UDP", "UDP")
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		upnp = null
		return ""
	return upnp.query_external_address()

func _cleanup_upnp() -> void:
	if upnp:
		upnp.delete_port_mapping(10567, "UDP")
		upnp = null

func unirse_a_sala(room_id: String) -> void:
	is_host = false
	current_room = room_id
	if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.send_text(JSON.stringify({
			"action": "join",
			"room": room_id
		}))
	else:
		var net = get_node_or_null("/root/Network")
		if net:
			net.start_client_for_room(room_id, vps_ip)

func consultar_salas() -> void:
	if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.send_text(JSON.stringify({"action": "get_rooms"}))

func _on_signaling_message(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("action"):
		return

	match String(msg.action):
		"created":
			local_peer_id = 1
			current_room = String(msg.get("room", current_room))
			sala_creada.emit(current_room)

		"joined":
			var host_ip = String(msg.get("host_ip", vps_ip))
			var host_port = int(msg.get("host_port", 10567))
			if host_ip == get_local_ip():
				host_ip = "127.0.0.1"

			var net = get_node_or_null("/root/Network")
			if net:
				var err = net.start_client_for_host(host_ip, host_port)
				if err != OK:
					error_conexion.emit("ERROR AL CONECTAR CON EL HOST EN " + host_ip + ":" + str(host_port))
					return
			local_peer_id = multiplayer.get_unique_id()
			unido_a_sala.emit(current_room)

		"host_disconnected":
			host_desconectado.emit()
			_clean_up_multiplayer()

		"rooms_list":
			salas_actualizadas.emit(msg.get("rooms", []))

		"error":
			error_conexion.emit(String(msg.get("message", "Error desconocido del servidor.")))

func cerrar_sala() -> void:
	_clean_up_multiplayer()
	if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.close()

func _clean_up_multiplayer() -> void:
	_cleanup_upnp()
	var net = get_node_or_null("/root/Network")
	if net and net.has_method("cerrar_conexion"):
		net.cerrar_conexion()
	local_peer_id = 0
	current_room = ""
	is_host = false
	nombres_jugadores.clear()

func _on_peer_connected(id: int) -> void:
	registrar_nombre_jugador.rpc(multiplayer.get_unique_id(), _obtener_nombre_usuario())
	if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.send_text(JSON.stringify({
			"action": "register_enet_peer",
			"room": current_room,
			"enet_peer_id": multiplayer.get_unique_id()
		}))

func _on_peer_disconnected(id: int) -> void:
	if nombres_jugadores.has(id):
		nombres_jugadores.erase(id)
	jugadores_actualizados.emit()

@rpc("any_peer", "call_local", "reliable")
func registrar_nombre_jugador(peer_id: int, nombre: String) -> void:
	nombres_jugadores[peer_id] = nombre
	var net = get_node_or_null("/root/Network")
	if net:
		net.nombres_jugadores[peer_id] = nombre
	jugadores_actualizados.emit()

@rpc("authority", "call_remote", "reliable")
func cargar_juego() -> void:
	cargar_juego_local()

func cargar_juego_local() -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.next_scene = MULTIJUGADOR_SCENE
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		cargar_juego.rpc()
	get_tree().change_scene_to_file(MULTIJUGADOR_SCENE)

func _check_server_cmdline() -> void:
	var args = OS.get_cmdline_args()
	if "--server" in args:
		var port = 10567
		var max_p = MAX_JUGADORES_SALA
		for i in range(args.size()):
			if args[i] == "--port" and i + 1 < args.size():
				port = int(args[i + 1])
			elif args[i] == "--max-players" and i + 1 < args.size():
				max_p = clampi(int(args[i + 1]), 2, MAX_JUGADORES_SALA)
		print("[RedManager] Iniciando servidor dedicado VPS en puerto ", port, " (Máx ", max_p, " jugadores)")
		iniciar_servidor_dedicado(port, max_p)

func iniciar_servidor_dedicado(port: int, max_p: int = MAX_JUGADORES_SALA) -> void:
	var net = get_node_or_null("/root/Network")
	if net:
		var err = net.start_server_on_port(port, max_p, "SALA VPS " + str(port), true)
		if err != OK:
			return
	is_host = true
	call_deferred("_cargar_escena_servidor")

func _cargar_escena_servidor() -> void:
	get_tree().change_scene_to_file(MULTIJUGADOR_SCENE)

func _obtener_nombre_usuario() -> String:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and "nombre_usuario" in datos and String(datos.nombre_usuario).strip_edges() != "":
		return String(datos.nombre_usuario).strip_edges()
	return "Conductor"

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()

func _on_connection_failed() -> void:
	error_conexion.emit("ERROR DE CONEXIÓN CON EL HOST O LA VPS.")
	_clean_up_multiplayer()

func _on_server_disconnected() -> void:
	error_conexion.emit("DESCONECTADO DEL SERVIDOR DE PARTIDA.")
	_clean_up_multiplayer()
