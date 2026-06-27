extends Node

# Autoload para gestionar Conexiones mediante ENet y Señalización
signal salas_actualizadas(salas: Array)
signal jugadores_actualizados()
signal error_conexion(msg: String)
signal sala_creada(sala_id: String)
signal unido_a_sala(sala_id: String)
signal host_desconectado()

const SIGNALING_URL_PC = "ws://sdbger1qghfrbw960k2xlnx4.2.25.71.102.sslip.io"
const SIGNALING_URL_MOBILE = "ws://sdbger1qghfrbw960k2xlnx4.2.25.71.102.sslip.io"

var ws_peer: WebSocketPeer = WebSocketPeer.new()
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
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

func _on_node_added(node: Node) -> void:
	if node.name == "Main" and str(node.get_path()) == "/root/Main":
		call_deferred("_setup_multiplayer_manager", node)

func _setup_multiplayer_manager(node: Node) -> void:
	if enet_peer and enet_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		var manager = Node.new()
		manager.name = "MultiplayerManager"
		manager.set_script(preload("res://Scripts/MultiplayerManager.gd"))
		node.add_child(manager)

func _process(_delta: float) -> void:
	ws_peer.poll()
	var state = ws_peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while ws_peer.get_available_packet_count() > 0:
			var packet = ws_peer.get_packet()
			_on_signaling_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED and current_room != "":
		_clean_up_multiplayer()
		error_conexion.emit("DESCONECTADO DEL SERVIDOR DE RED.")

func conectar_a_senalizacion(url: String = "") -> void:
	if url == "":
		if OS.get_name() == "Android" or OS.get_name() == "iOS":
			url = SIGNALING_URL_MOBILE
		else:
			url = SIGNALING_URL_PC
			
	ws_peer = WebSocketPeer.new()
	var err = ws_peer.connect_to_url(url)
	if err != OK:
		error_conexion.emit("ERROR AL CONECTAR CON EL SERVIDOR DE RED.")

func salir_de_sala() -> void:
	_clean_up_multiplayer()
	consultar_salas()

func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for ip in addresses:
		if ip.begins_with("192.168."):
			return ip
	for ip in addresses:
		if ip.begins_with("10.") or (ip.begins_with("172.") and int(ip.split(".")[1]) >= 16 and int(ip.split(".")[1]) <= 31):
			return ip
	return "127.0.0.1"

func crear_sala(room_id: String, room_name: String = "", max_players: int = 4) -> void:
	if ws_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error_conexion.emit("SIN CONEXION AL SERVIDOR DE RED.")
		return
		
	_clean_up_multiplayer()
	
	enet_peer = ENetMultiplayerPeer.new()
	var err = enet_peer.create_server(10567, max_players)
	if err != OK:
		error_conexion.emit("ERROR AL INICIAR SERVIDOR LOCAL EN PUERTO 10567.")
		return
		
	multiplayer.multiplayer_peer = enet_peer
	is_host = true
	current_room = room_id
	
	print("[RedManager] Configurando UPnP para acceso externo...")
	var public_ip = _setup_upnp()
	
	var local_ip = get_local_ip()
	var msg = {
		"action": "create",
		"room": room_id,
		"name": room_name if room_name != "" else "SALA DE " + DatosUsuario.nombre_usuario.to_upper(),
		"max_players": max_players,
		"ip": local_ip
	}
	if public_ip != "":
		msg["public_ip"] = public_ip
		
	ws_peer.send_text(JSON.stringify(msg))

func _setup_upnp() -> String:
	upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "InternetGatewayDevice")
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		print("[RedManager] UPnP: Descubrimiento fallo con codigo: ", discover_result)
		upnp = null
		return ""
		
	if not upnp.get_gateway() or not upnp.get_gateway().is_valid_gateway():
		print("[RedManager] UPnP: No se encontro puerta de enlace valida.")
		upnp = null
		return ""
		
	var map_result = upnp.add_port_mapping(10567, 10567, "NuestraTierra UDP", "UDP")
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		print("[RedManager] UPnP: Error al mapear puerto 10567 UDP. Codigo: ", map_result)
		upnp = null
		return ""
		
	var ext_ip = upnp.query_external_address()
	print("[RedManager] UPnP configurado. IP externa: ", ext_ip)
	return ext_ip

func _cleanup_upnp() -> void:
	if upnp:
		print("[RedManager] Liberando puerto UPnP...")
		var err = upnp.delete_port_mapping(10567, "UDP")
		if err != UPNP.UPNP_RESULT_SUCCESS:
			print("[RedManager] UPnP: Error al liberar puerto: ", err)
		else:
			print("[RedManager] UPnP: Puerto 10567 UDP liberado con exito.")
		upnp = null

func unirse_a_sala(room_id: String) -> void:
	if ws_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error_conexion.emit("SIN CONEXION AL SERVIDOR DE RED.")
		return
	is_host = false
	current_room = room_id
	var msg = {
		"action": "join",
		"room": room_id
	}
	ws_peer.send_text(JSON.stringify(msg))

func consultar_salas() -> void:
	if ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var msg = {"action": "get_rooms"}
		ws_peer.send_text(JSON.stringify(msg))

func _on_signaling_message(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not msg or not msg.has("action"):
		return
		
	var action = msg.action
	match action:
		"created":
			local_peer_id = 1
			sala_creada.emit(current_room)
			
		"joined":
			local_peer_id = msg.peer_id
			var host_ip = msg.get("host_ip", "127.0.0.1")
			var host_port = int(msg.get("host_port", 10567))
			if host_ip == get_local_ip():
				host_ip = "127.0.0.1"
			
			_clean_up_multiplayer()
			
			enet_peer = ENetMultiplayerPeer.new()
			var err = enet_peer.create_client(host_ip, host_port)
			if err != OK:
				error_conexion.emit("ERROR AL INICIAR CONEXION EN PUERTO " + str(host_port) + ".")
				_clean_up_multiplayer()
				return
				
			multiplayer.multiplayer_peer = enet_peer
			unido_a_sala.emit(current_room)
			
		"host_disconnected":
			host_desconectado.emit()
			_clean_up_multiplayer()
			
		"rooms_list":
			salas_actualizadas.emit(msg.rooms)
			
		"error":
			error_conexion.emit(msg.message)
			_clean_up_multiplayer()

func cerrar_sala() -> void:
	_clean_up_multiplayer()
	ws_peer.close()

func _clean_up_multiplayer() -> void:
	_cleanup_upnp()
	multiplayer.multiplayer_peer = null
	if enet_peer:
		enet_peer.close()
	local_peer_id = 0
	current_room = ""
	is_host = false
	nombres_jugadores.clear()

func _on_peer_connected(id: int) -> void:
	print("[RedManager] ENet Peer conectado: ", id)
	registrar_nombre_jugador.rpc(multiplayer.get_unique_id(), DatosUsuario.nombre_usuario)

func _on_peer_disconnected(id: int) -> void:
	print("[RedManager] ENet Peer desconectado: ", id)
	if nombres_jugadores.has(id):
		nombres_jugadores.erase(id)
	jugadores_actualizados.emit()

@rpc("any_peer", "call_local")
func registrar_nombre_jugador(peer_id: int, nombre: String) -> void:
	nombres_jugadores[peer_id] = nombre
	jugadores_actualizados.emit()

@rpc("any_peer", "call_remote")
func cargar_juego() -> void:
	cargar_juego_local()

func cargar_juego_local() -> void:
	if DatosUsuario:
		DatosUsuario.next_scene = "res://demo/Sky3DDemo.tscn"
	# Notificar a todos los clientes que carguen el juego
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		cargar_juego.rpc()
	get_tree().change_scene_to_file("res://escenas/gui/escena_carga.tscn")

func _check_server_cmdline() -> void:
	var args = OS.get_cmdline_args()
	if "--server" in args:
		var port = 10567
		for i in range(args.size()):
			if args[i] == "--port" and i + 1 < args.size():
				port = int(args[i+1])
		print("[RedManager] Iniciando servidor dedicado en puerto: ", port)
		iniciar_servidor_dedicado(port)

func iniciar_servidor_dedicado(port: int) -> void:
	_clean_up_multiplayer()
	enet_peer = ENetMultiplayerPeer.new()
	var err = enet_peer.create_server(port, 10) # Max 10 jugadores por sala
	if err != OK:
		print("[RedManager] Error al iniciar servidor en puerto ", port)
		return
	multiplayer.multiplayer_peer = enet_peer
	is_host = true
	
	call_deferred("_cargar_escena_servidor")

func _cargar_escena_servidor() -> void:
	print("[RedManager] Cargando escena del mapa para servidor dedicado...")
	get_tree().change_scene_to_file("res://demo/Sky3DDemo.tscn")

func _on_connected_to_server() -> void:
	print("[RedManager] Conexión establecida exitosamente con el servidor ENet de juego.")

func _on_connection_failed() -> void:
	print("[RedManager] Error: No se pudo conectar al servidor ENet de juego.")
	error_conexion.emit("ERROR DE CONEXION: EL SERVIDOR DE JUEGO NO ESTA CORRIENDO EN LA VPS.")
	_clean_up_multiplayer()

func _on_server_disconnected() -> void:
	print("[RedManager] Desconectado del servidor ENet de juego.")
	error_conexion.emit("DESCONECTADO DEL SERVIDOR DE JUEGO.")
	_clean_up_multiplayer()
