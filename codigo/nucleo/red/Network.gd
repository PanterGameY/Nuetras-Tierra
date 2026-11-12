extends Node

# ═══════════════════════════════════════════════════════════════════════
# Network.gd — Singleton de Conectividad Híbrida ENet (Host Local / LAN / VPS)
# Soporta:
#   1. Host Jugador (Listen Server): 1 Host + hasta 4 clientes = 5 personas máx.
#   2. Descubrimiento automático LAN / Hotspot por UDP Broadcast (puerto 10568).
#   3. Conexión futura a VPS Dedicada (Headless Server o Relay por código de sala).
# ═══════════════════════════════════════════════════════════════════════

signal sala_creada_exito(info_sala: Dictionary)
signal conectado_a_sala(info_sala: Dictionary)
signal error_red(mensaje: String)
signal lista_jugadores_actualizada(nombres: Dictionary)
signal salas_lan_actualizadas(salas: Array)
signal partida_iniciada(escena_destino: String)

enum ModoRed {
	HOST_JUGADOR_LAN,    # Un jugador es el Host de la partida (máx 5 personas)
	VPS_SENALIZACION,    # Host Jugador anunciado mediante servidor WebSocket en VPS
	VPS_DEDICADO_24_7    # Conexión directa a instancia Headless corriendo en VPS
}

const MAX_JUGADORES_SALA: int = 5
const DEFAULT_PORT: int = 10567
const LAN_BROADCAST_PORT: int = 10568
const BASE_PORT: int = 10000
const MAX_PORT_OFFSET: int = 5000
const MULTIJUGADOR_SCENE: String = "res://mundo/principal/PrincipalMultijugador.tscn"

# Configuración lista para VPS futura (editable en tiempo de ejecución o por variables de entorno)
var vps_ip: String = "2.25.71.102"
var vps_signaling_url: String = "ws://sdbger1qghfrbw960k2xlnx4.2.25.71.102.sslip.io"
var modo_actual: ModoRed = ModoRed.HOST_JUGADOR_LAN

var enet_peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_dedicated_vps: bool = false
var current_room_code: String = ""
var current_room_name: String = ""
var current_port: int = DEFAULT_PORT
var max_players_actual: int = MAX_JUGADORES_SALA
var partida_en_curso: bool = false

# Diccionario sincronizado de jugadores: peer_id (int) -> nombre (String)
var nombres_jugadores: Dictionary = {}

# Descubrimiento automático de salas en LAN / Hotspot
var _udp_broadcaster: PacketPeerUDP = null
var _udp_listener: PacketPeerUDP = null
var _broadcast_timer: float = 0.0
var _salas_lan_detectadas: Dictionary = {} # room_key -> Dictionary

func _ready() -> void:
	if OS.has_environment("NT_VPS_IP") and OS.get_environment("NT_VPS_IP") != "":
		vps_ip = OS.get_environment("NT_VPS_IP")
	if OS.has_environment("NT_SIGNALING_URL") and OS.get_environment("NT_SIGNALING_URL") != "":
		vps_signaling_url = OS.get_environment("NT_SIGNALING_URL")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	# 1. Si somos Host Jugador en sala abierta, emitir anuncio LAN cada 1.2s
	if is_host and enet_peer and enet_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_broadcast_timer += delta
		if _broadcast_timer >= 1.2:
			_broadcast_timer = 0.0
			_emitir_anuncio_lan()

	# 2. Si estamos buscando salas en el Lobby, escuchar anuncios LAN
	if _udp_listener and _udp_listener.is_bound():
		var hubo_cambios := false
		while _udp_listener.get_available_packet_count() > 0:
			var pkt = _udp_listener.get_packet()
			var sender_ip = _udp_listener.get_packet_ip()
			var texto = pkt.get_string_from_utf8()
			var data = JSON.parse_string(texto)
			if typeof(data) == TYPE_DICTIONARY and data.get("game") == "NuestraTierra2":
				var r_ip = sender_ip if sender_ip != "" else String(data.get("ip", "127.0.0.1"))
				var r_port = int(data.get("port", DEFAULT_PORT))
				var key = "%s:%d" % [r_ip, r_port]
				data["ip"] = r_ip
				data["last_seen"] = Time.get_ticks_msec()
				_salas_lan_detectadas[key] = data
				hubo_cambios = true

		# Limpiar salas LAN inactivas (> 4.5 segundos sin señal)
		var ahora = Time.get_ticks_msec()
		for k in _salas_lan_detectadas.keys():
			if ahora - int(_salas_lan_detectadas[k].get("last_seen", 0)) > 4500:
				_salas_lan_detectadas.erase(k)
				hubo_cambios = true

		if hubo_cambios:
			salas_lan_actualizadas.emit(_salas_lan_detectadas.values())

# ─────────────────────────────────────────────────────────────────────────────
# CREACIÓN DE PARTIDA (JUGADOR HOST — MÁXIMO 5 PERSONAS)
# ─────────────────────────────────────────────────────────────────────────────

func start_server_on_port(port: int = DEFAULT_PORT, max_players: int = MAX_JUGADORES_SALA, room_name: String = "", dedicated_headless: bool = false) -> int:
	cerrar_conexion()

	# Garantizar tope estricto de 5 personas en la partida
	max_players_actual = clampi(max_players, 2, MAX_JUGADORES_SALA)
	is_dedicated_vps = dedicated_headless or (DisplayServer.get_name() == "headless")

	# IMPORTANTE EN GODOT 4 (ENetMultiplayerPeer):
	# create_server(port, max_clients) define cuántos CLIENTES remotos pueden unirse.
	# Si un jugador actúa como Host (Listen Server), él ocupa 1 cupo (peer_id = 1),
	# por lo que permitimos máximo (max_players_actual - 1) clientes remotos (1 Host + 4 Clientes = 5 personas).
	# Si es un servidor dedicado en VPS sin jugador local, permitimos los 5 clientes.
	var max_remote_clients: int = max_players_actual if is_dedicated_vps else max(1, max_players_actual - 1)

	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(port, max_remote_clients)
	if error != OK:
		var msg = "No se pudo abrir el puerto UDP %d (Error %d)." % [port, error]
		print("[Network] ", msg)
		error_red.emit(msg)
		return error

	multiplayer.multiplayer_peer = enet_peer
	is_host = true
	current_port = port
	current_room_code = str(port) if current_room_code == "" else current_room_code
	var nombre_host = _obtener_nombre_local()
	current_room_name = room_name if room_name.strip_edges() != "" else ("SALA DE " + nombre_host.to_upper())

	nombres_jugadores.clear()
	if not is_dedicated_vps:
		nombres_jugadores[1] = nombre_host
		var pm = get_node_or_null("/root/PlayersManager")
		if pm and pm.has_method("registrar_jugador"):
			pm.registrar_jugador(1, nombre_host, 0, true)

	_iniciar_broadcaster_lan()
	_sincronizar_con_red_manager()

	var info = {
		"room_code": current_room_code,
		"room_name": current_room_name,
		"ip": get_ip_address(),
		"port": current_port,
		"max_players": max_players_actual,
		"players": nombres_jugadores.size()
	}
	print("[Network] Host iniciado en ", info.ip, ":", current_port, " | Cupo máx: ", max_players_actual, " personas (1 Host + ", max_remote_clients, " clientes)")
	sala_creada_exito.emit(info)
	lista_jugadores_actualizada.emit(nombres_jugadores)
	return OK

func start_server_for_room(room_code: String, max_players: int = MAX_JUGADORES_SALA, room_name: String = "") -> int:
	current_room_code = room_code.strip_edges()
	var port = _calcular_puerto(current_room_code) if current_room_code != "" else DEFAULT_PORT
	return start_server_on_port(port, max_players, room_name)

# ─────────────────────────────────────────────────────────────────────────────
# CONEXIÓN DE CLIENTE (LAN / HOTSPOT / IP DIRECTA / VPS FUTURA)
# ─────────────────────────────────────────────────────────────────────────────

func start_client_for_host(host_ip: String, port: int = DEFAULT_PORT) -> int:
	cerrar_conexion()

	var clean_ip = host_ip.strip_edges()
	if clean_ip == "":
		clean_ip = "127.0.0.1"
	if port <= 0 or port > 65535:
		port = DEFAULT_PORT

	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_client(clean_ip, port)
	if error != OK:
		var msg = "Error al iniciar cliente hacia %s:%d (Código %d)." % [clean_ip, port, error]
		print("[Network] ", msg)
		error_red.emit(msg)
		return error

	multiplayer.multiplayer_peer = enet_peer
	is_host = false
	current_port = port
	current_room_code = str(port)
	print("[Network] Conectando como cliente a ", clean_ip, ":", port)
	return OK

## Preparado para conectar a una VPS dedicada por código o número de sala (1..5 o código dinámico)
func start_client_for_room(room_code: String, custom_vps_ip: String = "") -> int:
	var target_ip = custom_vps_ip.strip_edges() if custom_vps_ip.strip_edges() != "" else vps_ip
	current_room_code = room_code.strip_edges()
	var port = _calcular_puerto(current_room_code)
	modo_actual = ModoRed.VPS_DEDICADO_24_7
	print("[Network] Conectando a VPS (", target_ip, ":", port, ") para Sala ", current_room_code)
	return start_client_for_host(target_ip, port)

func configurar_vps(nueva_ip_vps: String, nueva_url_senalizacion: String = "") -> void:
	if nueva_ip_vps.strip_edges() != "":
		vps_ip = nueva_ip_vps.strip_edges()
	if nueva_url_senalizacion.strip_edges() != "":
		vps_signaling_url = nueva_url_senalizacion.strip_edges()
	var red = get_node_or_null("/root/RedManager")
	if red and red.has_method("configurar_endpoints_vps"):
		red.configurar_endpoints_vps(vps_ip, vps_signaling_url)

# ─────────────────────────────────────────────────────────────────────────────
# SINCRONIZACIÓN DE JUGADORES Y ARRANQUE DE PARTIDA (RPCs)
# ─────────────────────────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer conectado: ", id)
	if is_host:
		# Verificar límite estricto de 5 jugadores totales
		var total_actual = nombres_jugadores.size()
		if total_actual >= max_players_actual and not nombres_jugadores.has(id):
			print("[Network] Sala llena (5/5). Desconectando peer excedente: ", id)
			if enet_peer:
				enet_peer.disconnect_peer(id)
			return

		# Si la partida ya está en curso en PrincipalMultijugador, llevar al nuevo cliente directamente
		if partida_en_curso:
			_rpc_cargar_escena_multijugador.rpc_id(id, MULTIJUGADOR_SCENE)

func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer desconectado: ", id)
	if nombres_jugadores.has(id):
		nombres_jugadores.erase(id)
	var pm = get_node_or_null("/root/PlayersManager")
	if pm and pm.has_method("eliminar_jugador"):
		pm.eliminar_jugador(id)
	_sincronizar_con_red_manager()
	if is_host:
		_rpc_sincronizar_lista_jugadores.rpc(nombres_jugadores, current_room_name, max_players_actual)
	lista_jugadores_actualizada.emit(nombres_jugadores)

func _on_connected_to_server() -> void:
	var mi_id = multiplayer.get_unique_id()
	var mi_nombre = _obtener_nombre_local()
	print("[Network] Conectado al Host exitosamente con ID: ", mi_id, " (", mi_nombre, ")")
	_rpc_registrar_jugador_en_host.rpc_id(1, mi_id, mi_nombre)
	conectado_a_sala.emit({
		"peer_id": mi_id,
		"port": current_port,
		"room_code": current_room_code
	})

func _on_connection_failed() -> void:
	print("[Network] Falló la conexión con el Host / VPS.")
	cerrar_conexion()
	error_red.emit("NO SE PUDO CONECTAR AL HOST O VPS. VERIFICA LA IP Y EL PUERTO.")

func _on_server_disconnected() -> void:
	print("[Network] El Host cerró la sala o se perdió la conexión.")
	cerrar_conexion()
	error_red.emit("EL HOST HA CERRADO LA PARTIDA.")

@rpc("any_peer", "call_local", "reliable")
func _rpc_registrar_jugador_en_host(peer_id: int, nombre: String) -> void:
	if not multiplayer.is_server():
		return
	var remitente = multiplayer.get_remote_sender_id()
	var id_real = remitente if remitente > 0 else peer_id
	if nombres_jugadores.size() >= max_players_actual and not nombres_jugadores.has(id_real):
		if enet_peer and id_real != 1:
			enet_peer.disconnect_peer(id_real)
		return

	var nombre_limpio = nombre.strip_edges()
	if nombre_limpio == "":
		nombre_limpio = "CONDUCTOR #" + str(id_real)
	nombres_jugadores[id_real] = nombre_limpio

	var pm = get_node_or_null("/root/PlayersManager")
	if pm and pm.has_method("registrar_jugador"):
		pm.registrar_jugador(id_real, nombre_limpio, -1, id_real == 1)

	_sincronizar_con_red_manager()
	_rpc_sincronizar_lista_jugadores.rpc(nombres_jugadores, current_room_name, max_players_actual)

@rpc("authority", "call_local", "reliable")
func _rpc_sincronizar_lista_jugadores(diccionario_nombres: Dictionary, nombre_sala: String, cupo_max: int) -> void:
	nombres_jugadores = diccionario_nombres.duplicate()
	if nombre_sala != "":
		current_room_name = nombre_sala
	max_players_actual = clampi(cupo_max, 2, MAX_JUGADORES_SALA)

	var pm = get_node_or_null("/root/PlayersManager")
	if pm:
		pm.jugadores_conectados.clear()
		var idx = 0
		for pid in nombres_jugadores.keys():
			pm.registrar_jugador(int(pid), String(nombres_jugadores[pid]), idx, int(pid) == 1)
			idx += 1

	_sincronizar_con_red_manager()
	lista_jugadores_actualizada.emit(nombres_jugadores)

## Llamado por el Host al presionar "INICIAR JUEGO" en el Lobby
func iniciar_partida_multijugador(escena_destino: String = MULTIJUGADOR_SCENE) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	partida_en_curso = true
	_rpc_cargar_escena_multijugador.rpc(escena_destino)

@rpc("authority", "call_local", "reliable")
func _rpc_cargar_escena_multijugador(escena_destino: String) -> void:
	partida_en_curso = true
	detener_escucha_lan()
	partida_iniciada.emit(escena_destino)
	var escena_final = escena_destino if ResourceLoader.exists(escena_destino) else "res://mundo/principal/Principal.tscn"
	print("[Network] Cargando escena multijugador sincronizada: ", escena_final)
	get_tree().change_scene_to_file(escena_final)

# ─────────────────────────────────────────────────────────────────────────────
# DESCUBRIMIENTO AUTOMÁTICO EN LAN / HOTSPOT (UDP BROADCAST)
# ─────────────────────────────────────────────────────────────────────────────

func _iniciar_broadcaster_lan() -> void:
	_detener_broadcaster_lan()
	_udp_broadcaster = PacketPeerUDP.new()
	_udp_broadcaster.set_broadcast_enabled(true)

func _detener_broadcaster_lan() -> void:
	if _udp_broadcaster:
		_udp_broadcaster.close()
		_udp_broadcaster = null

func _emitir_anuncio_lan() -> void:
	if not _udp_broadcaster:
		return
	var mi_ip = get_ip_address()
	var payload = {
		"game": "NuestraTierra2",
		"room_code": current_room_code if current_room_code != "" else str(current_port),
		"name": current_room_name,
		"host_name": _obtener_nombre_local(),
		"ip": mi_ip,
		"port": current_port,
		"players": nombres_jugadores.size(),
		"max_players": max_players_actual,
		"in_progress": partida_en_curso
	}
	var data = JSON.stringify(payload).to_utf8_buffer()

	# Enviar broadcast global y subnet local broadcast para compatibilidad con routers/hotspots
	_udp_broadcaster.set_dest_address("255.255.255.255", LAN_BROADCAST_PORT)
	_udp_broadcaster.put_packet(data)

	if mi_ip.begins_with("192.168."):
		var partes = mi_ip.split(".")
		if partes.size() == 4:
			var subnet_bcast = "%s.%s.%s.255" % [partes[0], partes[1], partes[2]]
			_udp_broadcaster.set_dest_address(subnet_bcast, LAN_BROADCAST_PORT)
			_udp_broadcaster.put_packet(data)

func iniciar_escucha_lan() -> void:
	detener_escucha_lan()
	_salas_lan_detectadas.clear()
	_udp_listener = PacketPeerUDP.new()
	var err = _udp_listener.bind(LAN_BROADCAST_PORT)
	if err != OK:
		print("[Network] Aviso: Puerto LAN Discovery ", LAN_BROADCAST_PORT, " ocupado (", err, "). Conexión manual por IP activa.")
		_udp_listener = null

func detener_escucha_lan() -> void:
	if _udp_listener:
		_udp_listener.close()
		_udp_listener = null

# ─────────────────────────────────────────────────────────────────────────────
# UTILIDADES Y LIMPIEZA
# ─────────────────────────────────────────────────────────────────────────────

func cerrar_conexion() -> void:
	_detener_broadcaster_lan()
	partida_en_curso = false
	is_host = false
	nombres_jugadores.clear()
	var pm = get_node_or_null("/root/PlayersManager")
	if pm and pm.has_method("limpiar"):
		pm.limpiar()
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	if enet_peer:
		enet_peer.close()
		enet_peer = null

func _calcular_puerto(room_code: String) -> int:
	var trimmed = room_code.strip_edges()
	if trimmed.is_valid_int():
		var val = int(trimmed)
		# Si es Sala 1..5 de la VPS dedicada, usa puertos 10567..10571
		if val >= 1 and val <= 5:
			return 10566 + val
		if val >= 1024 and val <= 65535:
			return val
	var num_code = abs(trimmed.hash())
	return BASE_PORT + (num_code % MAX_PORT_OFFSET)

func _obtener_nombre_local() -> String:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and "nombre_usuario" in datos and String(datos.nombre_usuario).strip_edges() != "":
		return String(datos.nombre_usuario).strip_edges()
	var pm = get_node_or_null("/root/PlayersManager")
	if pm and "player_name" in pm and String(pm.player_name).strip_edges() != "":
		return String(pm.player_name).strip_edges()
	return "Conductor"

func _sincronizar_con_red_manager() -> void:
	var red = get_node_or_null("/root/RedManager")
	if red:
		red.nombres_jugadores = nombres_jugadores.duplicate()
		red.is_host = is_host
		red.current_room = current_room_code

func get_ip_address() -> String:
	# Priorizar WiFi/LAN 192.168.x.x
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168."):
			return ip
	# Luego redes privadas clase A (10.x.x.x) y clase B (172.16..31)
	for ip in IP.get_local_addresses():
		if ip.begins_with("10.") or (ip.begins_with("172.") and ip.split(".").size() > 1 and int(ip.split(".")[1]) >= 16 and int(ip.split(".")[1]) <= 31):
			return ip
	for ip in IP.get_local_addresses():
		if not ip.contains(":") and ip != "127.0.0.1" and not ip.begins_with("169.254."):
			return ip
	return "127.0.0.1"
