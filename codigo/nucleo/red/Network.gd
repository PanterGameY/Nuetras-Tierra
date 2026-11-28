extends Node

# ═══════════════════════════════════════════════════════════════════════
# Network.gd — Singleton de Conectividad WebRTC Peer-to-Peer (Señalización WS)
# Soporta:
#   1. Señalización vía WebSocket (VPS / Servidor Node.js) para crear y listar salas.
#   2. Conexión directa Peer-to-Peer (WebRTCMultiplayerPeer) entre jugadores
#      sin depender de LAN ni abrir puertos en el router.
#   3. Tope de hasta 5 jugadores por sala (1 Host + 4 Clientes).
# ═══════════════════════════════════════════════════════════════════════

signal sala_creada_exito(info_sala: Dictionary)
signal conectado_a_sala(info_sala: Dictionary)
signal error_red(mensaje: String)
signal lista_jugadores_actualizada(nombres: Dictionary)
signal salas_lan_actualizadas(salas: Array)
signal partida_iniciada(escena_destino: String)
signal estado_senalizacion_cambiado(conectado: bool, mensaje: String)

enum ModoRed {
	HOST_JUGADOR_LAN,    # Compatibilidad legado
	VPS_SENALIZACION,    # WebRTC P2P con servidor de señalización WebSocket
	VPS_DEDICADO_24_7    # Reservado
}

const MAX_JUGADORES_SALA: int = 5
const DEFAULT_PORT: int = 10567
const MULTIJUGADOR_SCENE: String = "res://mundo/principal/PrincipalMultijugador.tscn"
const ICE_SERVERS := [
	{
		"urls": [
			"stun:stun.l.google.com:19302",
			"stun:stun1.l.google.com:19302"
		]
	}
]

var vps_ip: String = "2.25.71.102"
var vps_signaling_url: String = "wss://nuestra-tierra-signaling.onrender.com"
var modo_actual: ModoRed = ModoRed.VPS_SENALIZACION

var webrtc_peer: WebRTCMultiplayerPeer = null
var _ws: WebSocketPeer = null
var _ws_conectado: bool = false
var _peers_rtc: Dictionary = {} # peer_id (int) -> WebRTCPeerConnection
var _cola_mensajes_ws: Array[Dictionary] = []
var _list_poll_timer: float = 0.0
var _ws_reintentos: int = 0
var _ws_retry_timer: float = 0.0

var is_host: bool = false
var is_dedicated_vps: bool = false
var current_room_code: String = ""
var current_room_name: String = ""
var current_map_name: String = ""
var current_map_path: String = ""
var current_port: int = DEFAULT_PORT
var max_players_actual: int = MAX_JUGADORES_SALA
var partida_en_curso: bool = false

# Diccionario sincronizado de jugadores: peer_id (int) -> nombre (String)
var nombres_jugadores: Dictionary = {}

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
	if _ws:
		_ws.poll()
		var state := _ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if not _ws_conectado:
				_ws_conectado = true
				_ws_reintentos = 0
				_ws_retry_timer = 0.0
				estado_senalizacion_cambiado.emit(true, "CONECTADO AL SERVIDOR WEBRTC")
				_vaciar_cola_ws()

			while _ws.get_available_packet_count() > 0:
				var raw := _ws.get_packet().get_string_from_utf8()
				_procesar_mensaje_ws(raw)

			# Refresco periódico de salas mientras estamos en el lobby sin sala activa
			if current_room_code == "":
				_list_poll_timer += delta
				if _list_poll_timer >= 4.0:
					_list_poll_timer = 0.0
					_enviar_ws({"type": "list_rooms"})
		elif state == WebSocketPeer.STATE_CLOSED:
			var code := _ws.get_close_code()
			_ws = null
			if _ws_conectado:
				_ws_conectado = false
				estado_senalizacion_cambiado.emit(false, "DESCONECTADO DE SEÑALIZACIÓN (%d)" % code)
			elif _ws_reintentos < 5:
				_ws_reintentos += 1
				_ws_retry_timer = 4.0
				estado_senalizacion_cambiado.emit(false, "DESPERTANDO SERVIDOR WEBRTC (%d/5)..." % _ws_reintentos)
			else:
				_ws_reintentos = 0
				estado_senalizacion_cambiado.emit(false, "NO SE PUDO CONECTAR AL SERVIDOR WEBRTC")
				error_red.emit("NO SE PUDO CONECTAR AL SERVIDOR DE SEÑALIZACIÓN WEBRTC.")
	elif _ws_retry_timer > 0.0:
		_ws_retry_timer -= delta
		if _ws_retry_timer <= 0.0:
			conectar_senalizacion()

	if webrtc_peer:
		webrtc_peer.poll()

# ─────────────────────────────────────────────────────────────────────────────
# SEÑALIZACIÓN WEBSOCKET
# ─────────────────────────────────────────────────────────────────────────────

func conectar_senalizacion(custom_url: String = "") -> int:
	if custom_url.strip_edges() != "":
		vps_signaling_url = custom_url.strip_edges()

	if _ws and (_ws.get_ready_state() == WebSocketPeer.STATE_OPEN or _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING):
		return OK

	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(vps_signaling_url)
	if err != OK:
		_ws = null
		_ws_conectado = false
		estado_senalizacion_cambiado.emit(false, "ERROR DE URL WEBSOCKET")
		error_red.emit("ERROR AL CONECTAR CON SEÑALIZACIÓN WEBRTC (%d)." % err)
		return err

	estado_senalizacion_cambiado.emit(false, "CONECTANDO A SERVIDOR WEBRTC...")
	return OK

func configurar_vps(nueva_ip_vps: String, nueva_url_senalizacion: String = "") -> void:
	if nueva_ip_vps.strip_edges() != "":
		vps_ip = nueva_ip_vps.strip_edges()
	if nueva_url_senalizacion.strip_edges() != "":
		vps_signaling_url = nueva_url_senalizacion.strip_edges()
		if _ws:
			_ws.close()
			_ws = null
			_ws_conectado = false
	var red = get_node_or_null("/root/RedManager")
	if red and red.has_method("configurar_endpoints_vps"):
		red.configurar_endpoints_vps(vps_ip, vps_signaling_url)

func solicitar_lista_salas() -> void:
	_enviar_ws({"type": "list_rooms"})

func _enviar_ws(payload: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(payload))
		return

	_cola_mensajes_ws.append(payload)
	conectar_senalizacion()

func _vaciar_cola_ws() -> void:
	if not _ws or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	for msg in _cola_mensajes_ws:
		_ws.send_text(JSON.stringify(msg))
	_cola_mensajes_ws.clear()

# ─────────────────────────────────────────────────────────────────────────────
# CREAR / UNIRSE A SALAS WEBRTC P2P
# ─────────────────────────────────────────────────────────────────────────────

func crear_sala_webrtc(room_name: String = "", max_players: int = MAX_JUGADORES_SALA, map_name: String = "Principal", map_path: String = "") -> int:
	_limpiar_solo_webrtc()
	max_players_actual = clampi(max_players, 2, MAX_JUGADORES_SALA)
	var nombre_host := _obtener_nombre_local()
	current_room_name = room_name.strip_edges() if room_name.strip_edges() != "" else ("CONVOY DE " + nombre_host.to_upper())
	current_map_name = map_name.strip_edges() if map_name.strip_edges() != "" else "Principal"
	current_map_path = map_path.strip_edges()

	webrtc_peer = WebRTCMultiplayerPeer.new()
	var err := webrtc_peer.create_server()
	if err != OK:
		webrtc_peer = null
		error_red.emit("NO SE PUDO INICIAR HOST WEBRTC (CÓDIGO %d)." % err)
		return err

	multiplayer.multiplayer_peer = webrtc_peer
	is_host = true
	is_dedicated_vps = false

	_enviar_ws({
		"type": "create_room",
		"player_name": nombre_host,
		"room_name": current_room_name,
		"map_name": current_map_name,
		"max_players": max_players_actual
	})
	return OK

func unirse_sala_webrtc(room_code: String) -> int:
	var code := room_code.strip_edges().to_upper()
	if code == "":
		error_red.emit("INGRESA UN CÓDIGO DE SALA VÁLIDO.")
		return ERR_INVALID_PARAMETER

	_limpiar_solo_webrtc()
	is_host = false
	current_room_code = code

	_enviar_ws({
		"type": "join_room",
		"code": code,
		"player_name": _obtener_nombre_local()
	})
	return OK

# Wrappers de compatibilidad con llamadas anteriores
func start_server_on_port(_port: int = DEFAULT_PORT, max_players: int = MAX_JUGADORES_SALA, room_name: String = "", _dedicated_headless: bool = false) -> int:
	return crear_sala_webrtc(room_name, max_players)

func start_server_for_room(_room_code: String, max_players: int = MAX_JUGADORES_SALA, room_name: String = "") -> int:
	return crear_sala_webrtc(room_name, max_players)

func start_client_for_host(room_code_or_ip: String, _port: int = DEFAULT_PORT) -> int:
	return unirse_sala_webrtc(room_code_or_ip)

func start_client_for_room(room_code: String, custom_ws_url: String = "") -> int:
	if custom_ws_url.strip_edges() != "":
		configurar_vps(vps_ip, custom_ws_url)
	return unirse_sala_webrtc(room_code)

func iniciar_escucha_lan() -> void:
	conectar_senalizacion()
	solicitar_lista_salas()

func detener_escucha_lan() -> void:
	pass

# ─────────────────────────────────────────────────────────────────────────────
# PROCESAMIENTO DE MENSAJES DE SEÑALIZACIÓN + NEGOCIACIÓN WEBRTC
# ─────────────────────────────────────────────────────────────────────────────

func _procesar_mensaje_ws(raw: String) -> void:
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return

	var msg_type := String(data.get("type", ""))
	match msg_type:
		"welcome":
			solicitar_lista_salas()

		"room_list":
			var salas: Array = data.get("rooms", [])
			salas_lan_actualizadas.emit(salas)

		"room_created":
			current_room_code = String(data.get("code", ""))
			var room_info: Dictionary = data.get("room", {})
			current_room_name = String(room_info.get("name", current_room_name))
			_aplicar_diccionario_jugadores(data.get("players", {}))
			var info := {
				"room_code": current_room_code,
				"room_name": current_room_name,
				"max_players": max_players_actual,
				"players": nombres_jugadores.size()
			}
			print("[Network/WebRTC] Sala creada: ", current_room_code)
			sala_creada_exito.emit(info)

		"room_joined":
			current_room_code = String(data.get("code", ""))
			var my_id := int(data.get("peer_id", 2))
			var room_info: Dictionary = data.get("room", {})
			current_room_name = String(room_info.get("name", "SALA P2P"))
			current_map_name = String(room_info.get("map_name", ""))
			max_players_actual = int(room_info.get("max_players", MAX_JUGADORES_SALA))

			webrtc_peer = WebRTCMultiplayerPeer.new()
			var err := webrtc_peer.create_client(my_id)
			if err != OK:
				webrtc_peer = null
				error_red.emit("NO SE PUDO CREAR CLIENTE WEBRTC (CÓDIGO %d)." % err)
				return

			multiplayer.multiplayer_peer = webrtc_peer
			_aplicar_diccionario_jugadores(data.get("players", {}))

			var existing: Array = data.get("existing_peers", [])
			for p in existing:
				var remote_id := int(p.get("peer_id", 0))
				if remote_id > 0 and remote_id != my_id:
					_crear_peer_rtc(remote_id, true)

			conectado_a_sala.emit({
				"peer_id": my_id,
				"room_code": current_room_code,
				"room_name": current_room_name
			})

		"peer_connected":
			var remote_id := int(data.get("peer_id", 0))
			if remote_id > 0:
				_crear_peer_rtc(remote_id, false)

		"peer_disconnected":
			var remote_id := int(data.get("peer_id", 0))
			if _peers_rtc.has(remote_id):
				var pc: WebRTCPeerConnection = _peers_rtc[remote_id]
				if pc:
					pc.close()
				_peers_rtc.erase(remote_id)
			if webrtc_peer and webrtc_peer.has_peer(remote_id):
				webrtc_peer.remove_peer(remote_id)

		"players_updated":
			_aplicar_diccionario_jugadores(data.get("players", {}))

		"offer", "answer":
			var from_id := int(data.get("from_id", 0))
			var sdp := String(data.get("sdp", ""))
			if from_id <= 0 or sdp == "":
				return
			var pc := _obtener_o_crear_peer_rtc(from_id)
			if pc:
				pc.set_remote_description(msg_type, sdp)

		"candidate":
			var from_id := int(data.get("from_id", 0))
			var media := String(data.get("media", ""))
			var index := int(data.get("index", 0))
			var cand_name := String(data.get("name", ""))
			if from_id <= 0:
				return
			var pc := _obtener_o_crear_peer_rtc(from_id)
			if pc:
				pc.add_ice_candidate(media, index, cand_name)

		"game_started":
			var scene := String(data.get("scene", MULTIJUGADOR_SCENE))
			var m_name := String(data.get("map_name", current_map_name))
			var m_path := String(data.get("map_path", current_map_path))
			_cargar_escena_multijugador_local(scene, m_name, m_path)

		"room_closed":
			var reason := String(data.get("reason", "El anfitrión cerró la sala."))
			cerrar_conexion()
			error_red.emit(reason.to_upper())

		"error":
			var msg := String(data.get("message", "Error de señalización WebRTC"))
			error_red.emit(msg.to_upper())

func _obtener_o_crear_peer_rtc(remote_id: int) -> WebRTCPeerConnection:
	if _peers_rtc.has(remote_id):
		return _peers_rtc[remote_id]
	return _crear_peer_rtc(remote_id, false)

func _crear_peer_rtc(remote_id: int, enviar_oferta: bool) -> WebRTCPeerConnection:
	if not webrtc_peer:
		return null
	if _peers_rtc.has(remote_id):
		return _peers_rtc[remote_id]

	var pc := WebRTCPeerConnection.new()
	if pc == null:
		error_red.emit("FALTA LA EXTENSIÓN NATIVA DE WEBRTC (webrtc-native) EN EL PROYECTO.")
		return null

	var err := pc.initialize({"iceServers": ICE_SERVERS})
	if err != OK:
		error_red.emit("NO SE PUDO INICIALIZAR WEBRTC P2P (ERROR %d). VERIFICA webrtc-native." % err)
		return null

	pc.session_description_created.connect(_on_rtc_session_description.bind(remote_id, pc))
	pc.ice_candidate_created.connect(_on_rtc_ice_candidate.bind(remote_id))

	var add_err := webrtc_peer.add_peer(pc, remote_id)
	if add_err != OK:
		push_error("[Network/WebRTC] Error al registrar peer %d: %d" % [remote_id, add_err])
		return null

	_peers_rtc[remote_id] = pc
	if enviar_oferta:
		pc.create_offer()
	return pc

func _on_rtc_session_description(type: String, sdp: String, remote_id: int, pc: WebRTCPeerConnection) -> void:
	pc.set_local_description(type, sdp)
	_enviar_ws({
		"type": type,
		"target_id": remote_id,
		"sdp": sdp
	})

func _on_rtc_ice_candidate(media: String, index: int, cand_name: String, remote_id: int) -> void:
	_enviar_ws({
		"type": "candidate",
		"target_id": remote_id,
		"media": media,
		"index": index,
		"name": cand_name
	})

# ─────────────────────────────────────────────────────────────────────────────
# EVENTOS MULTIPLAYER Y SINCRONIZACIÓN DE JUGADORES
# ─────────────────────────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	print("[Network/WebRTC] Peer P2P conectado: ", id)
	if is_host and partida_en_curso:
		_rpc_cargar_escena_multijugador.rpc_id(id, MULTIJUGADOR_SCENE)

func _on_peer_disconnected(id: int) -> void:
	print("[Network/WebRTC] Peer P2P desconectado: ", id)
	if nombres_jugadores.has(id):
		nombres_jugadores.erase(id)
	var pm = get_node_or_null("/root/PlayersManager")
	if pm and pm.has_method("eliminar_jugador"):
		pm.eliminar_jugador(id)
	_sincronizar_con_red_manager()
	lista_jugadores_actualizada.emit(nombres_jugadores)

func _on_connected_to_server() -> void:
	var mi_id := multiplayer.get_unique_id()
	var mi_nombre := _obtener_nombre_local()
	print("[Network/WebRTC] Túnel P2P establecido con Host. Mi ID: ", mi_id)
	_rpc_registrar_jugador_en_host.rpc_id(1, mi_id, mi_nombre)

func _on_connection_failed() -> void:
	print("[Network/WebRTC] Falló la negociación P2P.")
	cerrar_conexion()
	error_red.emit("NO SE PUDO ESTABLECER CONEXIÓN P2P WEBRTC CON LA SALA.")

func _on_server_disconnected() -> void:
	print("[Network/WebRTC] El Host cerró la sala o se perdió la conexión P2P.")
	cerrar_conexion()
	error_red.emit("EL ANFITRIÓN HA CERRADO LA PARTIDA.")

@rpc("any_peer", "call_local", "reliable")
func _rpc_registrar_jugador_en_host(peer_id: int, nombre: String) -> void:
	if not multiplayer.is_server():
		return
	var remitente := multiplayer.get_remote_sender_id()
	var id_real := remitente if remitente > 0 else peer_id
	var nombre_limpio := nombre.strip_edges()
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
	_aplicar_diccionario_jugadores(diccionario_nombres)
	if nombre_sala != "":
		current_room_name = nombre_sala
	max_players_actual = clampi(cupo_max, 2, MAX_JUGADORES_SALA)

func _aplicar_diccionario_jugadores(diccionario_raw: Dictionary) -> void:
	nombres_jugadores.clear()
	for k in diccionario_raw.keys():
		nombres_jugadores[int(k)] = String(diccionario_raw[k])

	var pm = get_node_or_null("/root/PlayersManager")
	if pm:
		pm.jugadores_conectados.clear()
		var idx := 0
		for pid in nombres_jugadores.keys():
			pm.registrar_jugador(int(pid), String(nombres_jugadores[pid]), idx, int(pid) == 1)
			idx += 1

	_sincronizar_con_red_manager()
	lista_jugadores_actualizada.emit(nombres_jugadores)

func iniciar_partida_multijugador(escena_destino: String = MULTIJUGADOR_SCENE, map_name: String = "", map_path: String = "") -> void:
	if not is_host:
		return
	partida_en_curso = true
	var m_name := map_name if map_name.strip_edges() != "" else current_map_name
	var m_path := map_path if map_path.strip_edges() != "" else current_map_path
	_enviar_ws({
		"type": "start_game",
		"scene": escena_destino,
		"map_name": m_name,
		"map_path": m_path
	})
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		_rpc_cargar_escena_multijugador.rpc(escena_destino, m_name, m_path)

@rpc("authority", "call_local", "reliable")
func _rpc_cargar_escena_multijugador(escena_destino: String, map_name: String = "", map_path: String = "") -> void:
	_cargar_escena_multijugador_local(escena_destino, map_name, map_path)

func _cargar_escena_multijugador_local(escena_destino: String, map_name: String = "", map_path: String = "") -> void:
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == escena_destino:
		return
	if get_tree().root.get_node_or_null("PantallaCargaOnline") != null:
		return
	partida_en_curso = true
	if escena_destino.contains("EditorMapas.tscn") or map_path != "":
		var ruta_resuelta := _resolver_ruta_mapa_local(map_path, map_name)
		if ruta_resuelta != "":
			Engine.set_meta("nt_editor_mapa_ruta", ruta_resuelta)
		Engine.set_meta("nt_editor_mapa_nombre", map_name)
		Engine.set_meta("nt_jugar_directo", true)
		Engine.set_meta("nt_mp_modo_activo", true)
	else:
		Engine.set_meta("nt_mp_modo_activo", false)
	partida_iniciada.emit(escena_destino)
	var escena_final := escena_destino if ResourceLoader.exists(escena_destino) else "res://mundo/principal/Principal.tscn"
	print("[Network/WebRTC] Cargando escena multijugador P2P con pantalla de carga: ", escena_final, " | Mapa: ", map_name)
	var script_carga: GDScript = load("res://interfaz/pantallas/multijugador/PantallaCargaOnline.gd")
	var pantalla: CanvasLayer = script_carga.new()
	pantalla.name = "PantallaCargaOnline"
	get_tree().root.add_child(pantalla)
	pantalla.call("iniciar_carga", escena_final, map_name)

func _resolver_ruta_mapa_local(map_path: String, map_name: String) -> String:
	if map_path != "" and FileAccess.file_exists(map_path):
		return map_path
	var objetivo := map_name.strip_edges().to_lower()
	for carpeta in ["user://mapas", "user://mapas_comunidad_cache", "user://mapas_comunidad", "res://mundo/editor_mapas/mapas_defecto"]:
		var dir := DirAccess.open(carpeta)
		if not dir:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".ntmap"):
				var full: String = String(carpeta).path_join(fname)
				if objetivo == "" or fname.get_basename().to_lower() == objetivo:
					return full
				var f := FileAccess.open(full, FileAccess.READ)
				if f:
					var parsed = JSON.parse_string(f.get_as_text())
					if typeof(parsed) == TYPE_DICTIONARY and String(parsed.get("nombre", "")).strip_edges().to_lower() == objetivo:
						return full
			fname = dir.get_next()
		dir.list_dir_end()
	return map_path

# ─────────────────────────────────────────────────────────────────────────────
# UTILIDADES Y LIMPIEZA
# ─────────────────────────────────────────────────────────────────────────────

func _limpiar_solo_webrtc() -> void:
	partida_en_curso = false
	is_host = false
	current_room_code = ""
	nombres_jugadores.clear()
	for pc in _peers_rtc.values():
		if pc:
			pc.close()
	_peers_rtc.clear()
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	if webrtc_peer:
		webrtc_peer.close()
		webrtc_peer = null

func cerrar_conexion() -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and current_room_code != "":
		_ws.send_text(JSON.stringify({"type": "leave_room"}))
	_limpiar_solo_webrtc()
	var pm = get_node_or_null("/root/PlayersManager")
	if pm and pm.has_method("limpiar"):
		pm.limpiar()

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
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168."):
			return ip
	for ip in IP.get_local_addresses():
		if not ip.contains(":") and ip != "127.0.0.1" and not ip.begins_with("169.254."):
			return ip
	return "127.0.0.1"
