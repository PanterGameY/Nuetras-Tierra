extends Node

# ═══════════════════════════════════════════════════════════════════════
# MultiplayerManager.gd — Gestor de Escena Multijugador (Máximo 5 Personas)
# Sincronizado con PrincipalMultijugador.tscn, jugador3D.gd y coche_pesado.gd
# Soporta:
#   - Host Jugador (Listen Server: 1 Host + hasta 4 Clientes = 5 personas)
#   - Servidor Dedicado VPS Headless (--server: hasta 5 Clientes = 5 personas)
# ═══════════════════════════════════════════════════════════════════════

const PLAYER_SCENE: String = "res://modelos3d/personajes/Jugador/Jugador.tscn"
const VEHICLE_SCENE: String = "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn"
const VEHICLE_SCENE_FALLBACK: String = "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn"
const MAX_JUGADORES: int = 5

# Coordenadas base en el parqueadero principal (junto al remolque carpado)
const BASE_PLAYER_POS := Vector3(30.4923, 0.95, 786.3555)
const BASE_VEHICLE_POS := Vector3(33.8119, 1.11, 783.8547)
const SPAWN_OFFSETS_X: Array[float] = [0.0, 8.0, -8.0, 16.0, -16.0]

var _slots_ocupados: Dictionary = {} # peer_id (int) -> slot_index (0..4)
var _peers_spawneados: Dictionary = {} # peer_id (int) -> bool
var _vehiculos_peers: Dictionary = {} # peer_id (int) -> String (modelo_id)
var _personalizacion_vehiculos: Dictionary = {} # peer_id (int) -> Dictionary
var _trailers_activos: Dictionary = {} # peer_id (int) -> Dictionary {ruta, pos, rot_y}

const CATALOGO_VEHICULOS_MP := {
	"T800_A": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T800_Alargada": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T800": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"800_Modular": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T680": "res://modelos3d/vehiculos/tractomulas/cabezotes/T680/T680.tscn",
	"Kodiak": "res://modelos3d/vehiculos/tractomulas/cabezotes/KODIAK/kodiak.tscn",
	"NPR": "res://modelos3d/vehiculos/NPR/npr.tscn",
	"Marcopolo": "res://modelos3d/vehiculos/Buses/MarcopoloG8-1200/MarcopoloG8-1200.tscn",
	"Duster": "res://modelos3d/vehiculos/automoviles/Duster/duster.tscn",
	"Mespark": "res://modelos3d/vehiculos/automoviles/Mespark/mespark.tscn",
	"ToyotaHiace": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Hiage": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Pardo": "res://modelos3d/vehiculos/automoviles/Pardo/pardo.tscn",
	"Sprinter": "res://modelos3d/vehiculos/automoviles/sprinter/sprinter_repartidor.tscn"
}

func _obtener_vehiculo_local_id() -> String:
	var du := get_node_or_null("/root/DatosUsuario")
	var id_veh := "T800_A"
	if du:
		if "guardado_player_vehiculo_nombre" in du and str(du.guardado_player_vehiculo_nombre) != "":
			id_veh = str(du.guardado_player_vehiculo_nombre)
		elif "vehiculo_actual" in du and str(du.vehiculo_actual) != "":
			id_veh = str(du.vehiculo_actual)
	if not CATALOGO_VEHICULOS_MP.has(id_veh):
		for k in CATALOGO_VEHICULOS_MP.keys():
			if k.to_lower() in id_veh.to_lower() or id_veh.to_lower() in k.to_lower():
				return k
		return "T800_A"
	return id_veh

func _resolver_ruta_vehiculo(modelo_id: String) -> String:
	var clave := modelo_id if modelo_id != "" else "T800_A"
	if not CATALOGO_VEHICULOS_MP.has(clave):
		for k in CATALOGO_VEHICULOS_MP.keys():
			if k.to_lower() in clave.to_lower() or clave.to_lower() in k.to_lower():
				clave = k
				break
	var ruta: String = CATALOGO_VEHICULOS_MP.get(clave, VEHICLE_SCENE)
	return ruta if ResourceLoader.exists(ruta) else VEHICLE_SCENE_FALLBACK

var _contenedor_jugadores: Node3D = null
var _contenedor_vehiculos: Node3D = null
var _world_sync: MultiplayerSynchronizer = null

var _hud_mp_canvas: CanvasLayer = null
var _lbl_estado_sala: Label = null
var _timer_handshake_cliente: Timer = null
var _intentos_handshake: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz = get_parent()
	if not raiz:
		return

	_configurar_contenedores(raiz)
	_ocultar_nodos_default(raiz)
	_crear_hud_multijugador(raiz)
	_limpiar_nodos_default.call_deferred()

	# Si se ejecuta PrincipalMultijugador.tscn directamente desde el editor (F6) sin pasar por el Lobby,
	# levantar automáticamente un Host local para pruebas inmediatas (hasta 5 personas).
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		var net = get_node_or_null("/root/Network")
		if net and net.has_method("start_server_on_port"):
			print("[MultiplayerManager] Iniciando Host local automático (puerto 10567, máx 5 jugadores)...")
			net.start_server_on_port(10567, MAX_JUGADORES, "SALA LOCAL")

	if multiplayer.is_server():
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)

		if _world_sync:
			_world_sync.set_multiplayer_authority(1)

		# Spawnear al Host jugador (peer_id = 1) salvo que sea un servidor VPS headless sin pantalla
		var net = get_node_or_null("/root/Network")
		var es_dedicado = (DisplayServer.get_name() == "headless") or (net != null and net.get("is_dedicated_vps") == true)
		if not es_dedicado:
			_asignar_y_spawnear_peer.call_deferred(1)

		# Si ya existen clientes conectados que llegaron antes de que el Host cargara la escena,
		# enviarles una solicitud para que anuncien su presencia
		for p in multiplayer.get_peers():
			solicitar_listo_a_peer.rpc_id(p)
	else:
		# Somos Cliente: iniciar ciclo de handshake robusto con el Host
		_iniciar_handshake_cliente()

	_actualizar_hud_multijugador()

func _configurar_contenedores(raiz: Node) -> void:
	_contenedor_jugadores = raiz.get_node_or_null("ContenedorJugadores") as Node3D
	if not _contenedor_jugadores:
		_contenedor_jugadores = Node3D.new()
		_contenedor_jugadores.name = "ContenedorJugadores"
		raiz.add_child.call_deferred(_contenedor_jugadores)

	_contenedor_vehiculos = raiz.get_node_or_null("ContenedorVehiculos") as Node3D
	if not _contenedor_vehiculos:
		_contenedor_vehiculos = Node3D.new()
		_contenedor_vehiculos.name = "ContenedorVehiculos"
		raiz.add_child.call_deferred(_contenedor_vehiculos)

	_world_sync = raiz.get_node_or_null("WorldStateSynchronizer") as MultiplayerSynchronizer

func _ocultar_nodos_default(raiz: Node) -> void:
	for node_name in ["Jugador2", "T800_Alargada", "RigidBody3D", "Mespark"]:
		var n = raiz.get_node_or_null(node_name)
		if n:
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED

func _limpiar_nodos_default() -> void:
	var raiz = get_parent()
	if not raiz:
		return
	for node_name in ["Jugador2", "T800_Alargada", "RigidBody3D", "Mespark"]:
		var n = raiz.get_node_or_null(node_name)
		if n and is_instance_valid(n):
			n.queue_free()

# ─────────────────────────────────────────────────────────────────────────────
# HANDSHAKE Y SINCRONIZACIÓN CLIENTE <-> HOST
# ─────────────────────────────────────────────────────────────────────────────

func _iniciar_handshake_cliente() -> void:
	_intentos_handshake = 0
	_enviar_peer_listo()

	# Configurar timer de reintento por si el Host estaba ocupado cargando mapa
	if not _timer_handshake_cliente:
		_timer_handshake_cliente = Timer.new()
		_timer_handshake_cliente.name = "TimerHandshake"
		_timer_handshake_cliente.wait_time = 0.9
		_timer_handshake_cliente.autostart = false
		_timer_handshake_cliente.one_shot = false
		_timer_handshake_cliente.timeout.connect(_on_timer_handshake_timeout)
		add_child(_timer_handshake_cliente)

	_timer_handshake_cliente.start()

func _enviar_peer_listo() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return
	var mi_id = multiplayer.get_unique_id()
	var mi_nombre = _obtener_nombre_jugador(mi_id)
	var red = get_node_or_null("/root/RedManager")
	if red and red.has_method("registrar_nombre_jugador"):
		red.registrar_nombre_jugador.rpc(mi_id, mi_nombre)
	var mi_modelo := _obtener_vehiculo_local_id()
	print("[MultiplayerManager] Cliente (ID: %d) enviando peer_listo al Host (vehículo: %s)..." % [mi_id, mi_modelo])
	peer_listo.rpc_id(1, mi_nombre, mi_modelo)

func _on_timer_handshake_timeout() -> void:
	var mi_id = multiplayer.get_unique_id()
	if _buscar_entidad("Jugador_" + str(mi_id)) != null:
		# Ya aparecimos en el juego, detener el timer
		if _timer_handshake_cliente:
			_timer_handshake_cliente.stop()
		return

	_intentos_handshake += 1
	if _intentos_handshake <= 25:
		print("[MultiplayerManager] Reintentando peer_listo hacia el Host (intento %d/25)..." % _intentos_handshake)
		_enviar_peer_listo()
	else:
		if _timer_handshake_cliente:
			_timer_handshake_cliente.stop()

@rpc("authority", "call_remote", "reliable")
func solicitar_listo_a_peer() -> void:
	if not multiplayer.is_server():
		_enviar_peer_listo()

# ─────────────────────────────────────────────────────────────────────────────
# GESTIÓN DE SLOTS Y SPAWN (MÁXIMO 5 JUGADORES)
# ─────────────────────────────────────────────────────────────────────────────

func _obtener_slot_para_peer(peer_id: int) -> int:
	if _slots_ocupados.has(peer_id):
		return int(_slots_ocupados[peer_id])
	var usados: Array[int] = []
	for s in _slots_ocupados.values():
		usados.append(int(s))
	for i in range(MAX_JUGADORES):
		if not usados.has(i):
			_slots_ocupados[peer_id] = i
			return i
	return -1

func _obtener_posiciones_slot(slot_idx: int) -> Dictionary:
	var raiz = get_parent()
	var idx_clamped = clampi(slot_idx, 0, MAX_JUGADORES - 1)
	var base_p := BASE_PLAYER_POS
	var base_v := BASE_VEHICLE_POS
	if Engine.has_meta("nt_mp_spawn_pos"):
		var custom_spawn: Variant = Engine.get_meta("nt_mp_spawn_pos")
		if custom_spawn is Vector3:
			base_p = custom_spawn + Vector3(0.0, 0.25, 0.0)
			base_v = custom_spawn + Vector3(3.6, 0.35, -2.5)

	var p_pos = base_p + Vector3(SPAWN_OFFSETS_X[idx_clamped], 0.0, 0.0)
	var v_pos = base_v + Vector3(SPAWN_OFFSETS_X[idx_clamped], 0.0, 0.0)

	if raiz:
		var marker_p = raiz.get_node_or_null("PuntosSpawn/PuntosJugadores/SpawnJugador" + str(idx_clamped + 1)) as Node3D
		if marker_p:
			p_pos = marker_p.global_position
		var marker_v = raiz.get_node_or_null("PuntosSpawn/PuntosVehiculos/SpawnVehiculo" + str(idx_clamped + 1)) as Node3D
		if marker_v:
			v_pos = marker_v.global_position
		p_pos = _ajustar_pos_sobre_suelo(raiz, p_pos, 0.25)
		v_pos = _ajustar_pos_sobre_suelo(raiz, v_pos, 0.35)

	return {"player_pos": p_pos, "vehicle_pos": v_pos}


func _ajustar_pos_sobre_suelo(raiz: Node, pos: Vector3, margen_y: float) -> Vector3:
	if not (raiz is Node3D):
		return pos
	var out := pos
	var ctrl_terr := raiz.find_child("ControladorTerreno", true, false)
	if ctrl_terr and "terrain" in ctrl_terr and is_instance_valid(ctrl_terr.terrain) and ctrl_terr.terrain.data:
		var h_terr: float = ctrl_terr.terrain.data.get_height(pos)
		if not is_nan(h_terr) and not is_inf(h_terr):
			out.y = maxf(out.y, h_terr + margen_y)
	var mundo := (raiz as Node3D).get_world_3d()
	if not mundo or not mundo.direct_space_state:
		return out
	var space := mundo.direct_space_state
	var excl: Array[RID] = []
	var y_origen: float = maxf(out.y + 25.0, 40.0)
	for _i in range(6):
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(out.x, y_origen, out.z),
			Vector3(out.x, out.y - 25.0, out.z),
			1,
			excl
		)
		var res := space.intersect_ray(q)
		if res.is_empty():
			break
		var hit_col = res["collider"]
		if hit_col is VehicleBody3D or hit_col is RigidBody3D or hit_col is CharacterBody3D:
			excl.append(res["rid"])
			y_origen = (res["position"] as Vector3).y - 0.05
			continue
		var norm: Vector3 = res["normal"]
		if norm.y >= 0.45:
			out.y = maxf(out.y, (res["position"] as Vector3).y + margen_y)
			return out
		excl.append(res["rid"])
		y_origen = (res["position"] as Vector3).y - 0.05
	return out

func _asignar_y_spawnear_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _slots_ocupados.size() >= MAX_JUGADORES and not _slots_ocupados.has(peer_id):
		print("[MultiplayerManager] Cupo máximo alcanzado (5/5). Rechazando spawn para peer: ", peer_id)
		return

	var slot = _obtener_slot_para_peer(peer_id)
	if slot < 0:
		return

	var coords = _obtener_posiciones_slot(slot)
	var nombre = _obtener_nombre_jugador(peer_id)
	if not _vehiculos_peers.has(peer_id) and peer_id == multiplayer.get_unique_id():
		_vehiculos_peers[peer_id] = _obtener_vehiculo_local_id()
	var modelo_veh: String = str(_vehiculos_peers.get(peer_id, "T800_A"))
	_peers_spawneados[peer_id] = true

	print("[MultiplayerManager] Spawneando peer %d (%s, %s) en slot %d..." % [peer_id, nombre, modelo_veh, slot])
	spawn_entidad.rpc("vehicle", peer_id, coords.vehicle_pos, nombre, modelo_veh)
	spawn_entidad.rpc("player", peer_id, coords.player_pos, nombre, "")
	_actualizar_hud_multijugador()

@rpc("any_peer", "call_remote", "reliable")
func peer_listo(nombre_cliente: String = "", modelo_vehiculo: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		return
	if modelo_vehiculo.strip_edges() != "":
		_vehiculos_peers[peer_id] = modelo_vehiculo.strip_edges()

	print("[MultiplayerManager] Host recibió peer_listo de peer: ", peer_id, " (", nombre_cliente, ")")

	# Verificar límite estricto de 5 personas
	if _slots_ocupados.size() >= MAX_JUGADORES and not _slots_ocupados.has(peer_id):
		return

	if nombre_cliente.strip_edges() != "":
		var net = get_node_or_null("/root/Network")
		if net:
			net.nombres_jugadores[peer_id] = nombre_cliente.strip_edges()
		var red = get_node_or_null("/root/RedManager")
		if red:
			red.nombres_jugadores[peer_id] = nombre_cliente.strip_edges()

	# 1. Sincronizar lista completa de nombres al cliente entrante
	var net_node = get_node_or_null("/root/Network")
	if net_node and net_node.has_method("_rpc_sincronizar_lista_jugadores"):
		net_node._rpc_sincronizar_lista_jugadores.rpc(net_node.nombres_jugadores, net_node.current_room_name, MAX_JUGADORES)

	# 2. Enviar al nuevo cliente todas las entidades que ya existen en el juego
	for existing_peer in _peers_spawneados.keys():
		if int(existing_peer) == peer_id:
			continue
		var p_node = _buscar_entidad("Jugador_" + str(existing_peer))
		var v_node = _buscar_entidad("Vehiculo_" + str(existing_peer))
		var p_nombre = _obtener_nombre_jugador(int(existing_peer))
		if v_node:
			spawn_entidad.rpc_id(peer_id, "vehicle", int(existing_peer), v_node.global_position, p_nombre, str(_vehiculos_peers.get(int(existing_peer), "T800_A")))
		if p_node:
			spawn_entidad.rpc_id(peer_id, "player", int(existing_peer), p_node.global_position, p_nombre, "")
		if _personalizacion_vehiculos.has(int(existing_peer)):
			var pdata: Dictionary = _personalizacion_vehiculos[int(existing_peer)]
			sincronizar_personalizacion_vehiculo.rpc_id(
				peer_id,
				int(existing_peer),
				str(pdata.get("color_hex", "ffffff")),
				float(pdata.get("metallic", 0.3)),
				float(pdata.get("roughness", 0.35)),
				bool(pdata.get("neon_on", false)),
				str(pdata.get("neon_hex", "0066ff")),
				float(pdata.get("neon_intensity", 1.2))
			)
		var t_node = _buscar_entidad("Trailer_" + str(existing_peer))
		if t_node and _trailers_activos.has(int(existing_peer)):
			var td: Dictionary = _trailers_activos[int(existing_peer)]
			spawn_trailer_red.rpc_id(peer_id, int(existing_peer), str(td.get("ruta", "")), t_node.global_position, t_node.rotation.y)

	# 3. Spawnear al nuevo cliente en todos los peers
	_asignar_y_spawnear_peer(peer_id)
	notificar_conexion_jugador.rpc(peer_id, _obtener_nombre_jugador(peer_id))

	# 4. Actualizar visibilidad de todos los sincronizadores
	_actualizar_visibilidad_sincronizadores()

@rpc("authority", "call_local", "reliable")
func spawn_entidad(type: String, peer_id: int, pos: Vector3, nombre_jugador: String = "", modelo_vehiculo: String = "") -> void:
	var nombre_mostrar = nombre_jugador if nombre_jugador != "" else _obtener_nombre_jugador(peer_id)

	if type == "player":
		var node_name = "Jugador_" + str(peer_id)
		if _buscar_entidad(node_name) != null:
			return

		var es_local := (peer_id == multiplayer.get_unique_id())
		var player: Node3D = null

		if es_local:
			var scene = load(PLAYER_SCENE) as PackedScene
			if not scene:
				push_error("[MultiplayerManager] No se encontró PLAYER_SCENE: " + PLAYER_SCENE)
				return
			player = scene.instantiate()
		else:
			player = _crear_capsula_jugador_remoto(peer_id)

		player.name = node_name
		# CRÍTICO: Asignar autoridad ANTES de add_child() para que jugador3D._ready() detecte si es local o remoto
		player.set_multiplayer_authority(peer_id)
		player.position = pos

		_add_synchronizer(player, peer_id, {
			".:global_position": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:global_rotation": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:velocity": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			".:_conduciendo": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
			".:_anim_actual": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		})

		if not es_local:
			_agregar_etiqueta_nombre_3d(player, nombre_mostrar, Vector3(0, 2.15, 0))

		var parent_target: Node = _contenedor_jugadores if is_instance_valid(_contenedor_jugadores) else get_parent()
		parent_target.add_child(player, true)

		if es_local:
			if _timer_handshake_cliente:
				_timer_handshake_cliente.stop()
			_activar_camara_deferred.call_deferred(player)

	elif type == "vehicle":
		var node_name = "Vehiculo_" + str(peer_id)
		if _buscar_entidad(node_name) != null:
			return

		var modelo_resuelto := modelo_vehiculo if modelo_vehiculo != "" else (_obtener_vehiculo_local_id() if peer_id == multiplayer.get_unique_id() else "T800_A")
		var ruta_veh := _resolver_ruta_vehiculo(modelo_resuelto)
		var scene = load(ruta_veh) as PackedScene
		if not scene:
			push_error("[MultiplayerManager] No se encontró escena de vehículo: " + ruta_veh)
			return

		var vehicle = scene.instantiate()
		vehicle.name = node_name
		vehicle.set_meta("modelo_id", modelo_resuelto)
		# CRÍTICO: Asignar autoridad ANTES de add_child()
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
			".:direccional_derecha": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
			".:angulo_direccion_red": SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		})

		if peer_id != multiplayer.get_unique_id():
			_agregar_etiqueta_nombre_3d(vehicle, "🚛 " + nombre_mostrar, Vector3(0, 4.2, 0))

		var parent_target: Node = _contenedor_vehiculos if is_instance_valid(_contenedor_vehiculos) else get_parent()
		parent_target.add_child(vehicle, true)

		if _personalizacion_vehiculos.has(peer_id):
			var pdata: Dictionary = _personalizacion_vehiculos[peer_id]
			sincronizar_personalizacion_vehiculo(
				peer_id,
				str(pdata.get("color_hex", "ffffff")),
				float(pdata.get("metallic", 0.3)),
				float(pdata.get("roughness", 0.35)),
				bool(pdata.get("neon_on", false)),
				str(pdata.get("neon_hex", "0066ff")),
				float(pdata.get("neon_intensity", 1.2))
			)
		elif peer_id == multiplayer.get_unique_id():
			_enviar_personalizacion_guardada_deferred.call_deferred(peer_id)

	_actualizar_hud_multijugador()

func _buscar_entidad(nombre: String) -> Node3D:
	if is_instance_valid(_contenedor_jugadores) and _contenedor_jugadores.has_node(nombre):
		return _contenedor_jugadores.get_node(nombre) as Node3D
	if is_instance_valid(_contenedor_vehiculos) and _contenedor_vehiculos.has_node(nombre):
		return _contenedor_vehiculos.get_node(nombre) as Node3D
	if get_parent() and get_parent().has_node(nombre):
		return get_parent().get_node(nombre) as Node3D
	return null

func _crear_capsula_jugador_remoto(_peer_id: int) -> CharacterBody3D:
	var cuerpo := CharacterBody3D.new()
	var script_remoto := load("res://codigo/nucleo/red/JugadorCapsulaRemota.gd")
	if script_remoto:
		cuerpo.set_script(script_remoto)
	cuerpo.collision_layer = 2
	cuerpo.collision_mask = 1

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.76
	col.shape = shape
	col.position = Vector3(0.0, 0.88, 0.0)
	cuerpo.add_child(col)

	var glb_path := "res://modelos3d/personajes/Jugador/jugador_voxel_remoto.glb"
	var escena_voxel := load(glb_path) as PackedScene if ResourceLoader.exists(glb_path) else null
	if escena_voxel:
		var modelo := escena_voxel.instantiate() as Node3D
		modelo.name = "ModeloVoxel"
		# Igual que Modelo en Jugador.tscn (Transform3D -1..): Blender -Y exporta a +Z en glTF,
		# mientras jugador3D.gd orienta el movimiento hacia -Z (atan2(-dir.x, -dir.z)).
		modelo.rotation.y = PI
		cuerpo.add_child(modelo)
	else:
		var malla := MeshInstance3D.new()
		var capsula := CapsuleMesh.new()
		capsula.radius = 0.35
		capsula.height = 1.75
		malla.mesh = capsula
		malla.position = Vector3(0.0, 0.875, 0.0)
		cuerpo.add_child(malla)

	return cuerpo

func _activar_camara_deferred(player_node: Node) -> void:
	if not is_instance_valid(player_node):
		return
	var cam = player_node.find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.cull_mask = cam.cull_mask & ~2
		cam.make_current()
	var raiz := get_parent()
	if is_instance_valid(raiz):
		var ctrl_terr := raiz.find_child("ControladorTerreno", true, false)
		if ctrl_terr:
			if "bloqueado_en_prueba" in ctrl_terr:
				ctrl_terr.bloqueado_en_prueba = true
			if "terrain" in ctrl_terr and is_instance_valid(ctrl_terr.terrain):
				var t = ctrl_terr.terrain
				t.collision_mode = 1
				t.collision_radius = 96
				t.collision_target = player_node
				if cam:
					t.set_camera(cam)
					t.set_clipmap_target(cam)
			if cam and ctrl_terr.has_method("aplicar_distancia_renderizado"):
				ctrl_terr.aplicar_distancia_renderizado(450.0, cam)
	_limpiar_nodos_default()

func _on_peer_connected(peer_id: int) -> void:
	print("[MultiplayerManager] Peer conectado a la partida: ", peer_id)
	solicitar_listo_a_peer.rpc_id(peer_id)
	_actualizar_hud_multijugador()

func _on_peer_disconnected(peer_id: int) -> void:
	print("[MultiplayerManager] Peer desconectado de la partida: ", peer_id)
	_slots_ocupados.erase(peer_id)
	_peers_spawneados.erase(peer_id)
	despawn_entidades_peer.rpc(peer_id)
	_actualizar_hud_multijugador()

@rpc("authority", "call_local", "reliable")
func despawn_entidades_peer(peer_id: int) -> void:
	var player = _buscar_entidad("Jugador_" + str(peer_id))
	if player:
		player.queue_free()
	var vehicle = _buscar_entidad("Vehiculo_" + str(peer_id))
	if vehicle:
		vehicle.queue_free()
	var trailer = _buscar_entidad("Trailer_" + str(peer_id))
	if trailer:
		trailer.queue_free()
	_personalizacion_vehiculos.erase(peer_id)
	_trailers_activos.erase(peer_id)
	_actualizar_hud_multijugador()

func _enviar_personalizacion_guardada_deferred(peer_id: int) -> void:
	var veh := _buscar_entidad("Vehiculo_" + str(peer_id))
	if veh:
		var cust := veh.get_node_or_null("CustomizerComponent")
		if not cust:
			cust = veh.find_child("CustomizerComponent", true, false)
		if not cust:
			var cust_script := load("res://codigo/sistemas/taller/customizer_component.gd")
			if cust_script:
				cust = Node.new()
				cust.set_script(cust_script)
				cust.name = "CustomizerComponent"
				veh.add_child(cust)
		if cust and cust.has_method("cargar_personalizacion"):
			cust.cargar_personalizacion()

	var du = get_node_or_null("/root/DatosUsuario")
	if not du or not ("vehiculos_personalizados" in du):
		return
	var id_veh := _obtener_vehiculo_local_id()
	var dicts = du.get("vehiculos_personalizados")
	if not (dicts is Dictionary) or not dicts.has(id_veh):
		return
	var d: Dictionary = dicts[id_veh]
	var cols: Array = d.get("colores_slots", [])
	var mets: Array = d.get("metallic_slots", [])
	var roughs: Array = d.get("roughness_slots", [])
	var c_hex := str(cols[0]) if cols.size() > 0 else "ffffff"
	var met := float(mets[0]) if mets.size() > 0 else 0.3
	var rough := float(roughs[0]) if roughs.size() > 0 else 0.35
	var n_on := bool(d.get("neon_enabled", false))
	var n_hex := str(d.get("neon_color", "0066ff"))
	var n_int := float(d.get("neon_intensity", 1.2))
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		sincronizar_personalizacion_vehiculo.rpc(peer_id, c_hex, met, rough, n_on, n_hex, n_int)
	else:
		sincronizar_personalizacion_vehiculo(peer_id, c_hex, met, rough, n_on, n_hex, n_int)

@rpc("any_peer", "call_local", "reliable")
func sincronizar_personalizacion_vehiculo(peer_id: int, color_hex: String, metallic: float, roughness: float, neon_on: bool, neon_hex: String, neon_intensity: float) -> void:
	_personalizacion_vehiculos[peer_id] = {
		"color_hex": color_hex,
		"metallic": metallic,
		"roughness": roughness,
		"neon_on": neon_on,
		"neon_hex": neon_hex,
		"neon_intensity": neon_intensity
	}
	var veh := _buscar_entidad("Vehiculo_" + str(peer_id))
	if not veh:
		return
	var comp := veh.find_child("CustomizerComponent", true, false) as CustomizerComponent
	if not comp:
		comp = CustomizerComponent.new()
		comp.name = "CustomizerComponent"
		veh.add_child(comp)
		comp.detectar_materiales_personalizables()
	if comp.materiales_detectados.is_empty():
		comp.detectar_materiales_personalizables()
	comp.aplicar_pintura(Color.html(color_hex), metallic, roughness, 0.5)
	comp.aplicar_neon(neon_on, Color.html(neon_hex), neon_intensity)

@rpc("any_peer", "call_local", "reliable")
func solicitar_spawn_trailer(peer_id: int, ruta_trailer: String = "") -> void:
	if not multiplayer.is_server():
		return
	var remitente := multiplayer.get_remote_sender_id()
	var id_real := remitente if remitente > 0 else peer_id
	var veh := _buscar_entidad("Vehiculo_" + str(id_real)) as Node3D
	if not veh:
		return
	var ruta := ruta_trailer
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		ruta = TrailerFactory.RUTA_CHASIS_DEFECTO
	var atras := veh.global_transform.basis.z.normalized()
	var pos := veh.global_position + atras * 9.5 + Vector3(0.0, 0.35, 0.0)
	var rot_y := veh.rotation.y
	spawn_trailer_red.rpc(id_real, ruta, pos, rot_y)

@rpc("authority", "call_local", "reliable")
func spawn_trailer_red(peer_id: int, ruta_trailer: String, pos: Vector3, rot_y: float) -> void:
	var node_name := "Trailer_" + str(peer_id)
	var previo := _buscar_entidad(node_name)
	if previo:
		previo.queue_free()
	var ruta := ruta_trailer if (ruta_trailer != "" and ResourceLoader.exists(ruta_trailer)) else TrailerFactory.RUTA_CHASIS_DEFECTO
	var trailer := TrailerFactory.crear_trailer(ruta, "rin_t2_cromo", pos, Vector3(0.0, rot_y, 0.0))
	if not trailer and ruta != TrailerFactory.RUTA_CHASIS_DEFECTO:
		trailer = TrailerFactory.crear_trailer(TrailerFactory.RUTA_CHASIS_DEFECTO, "rin_t2_cromo", pos, Vector3(0.0, rot_y, 0.0))
	if not trailer:
		return
	trailer.name = node_name
	trailer.set_multiplayer_authority(peer_id)
	trailer.position = pos
	trailer.rotation = Vector3(0.0, rot_y, 0.0)
	_trailers_activos[peer_id] = {"ruta": ruta, "pos": pos, "rot_y": rot_y}
	_add_synchronizer(trailer, peer_id, {
		".:global_position": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
		".:global_rotation": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
		".:linear_velocity": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
		".:angular_velocity": SceneReplicationConfig.REPLICATION_MODE_ALWAYS
	})
	var parent_target: Node = _contenedor_vehiculos if is_instance_valid(_contenedor_vehiculos) else get_parent()
	parent_target.add_child(trailer, true)
	_actualizar_visibilidad_sincronizadores()

func _add_synchronizer(node: Node, authority: int, properties: Dictionary) -> void:
	var sync = MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.set_multiplayer_authority(authority)
	sync.replication_interval = 0.05 # 20 Hz fluido sin saturar CPU ni canal WebRTC
	sync.delta_interval = 0.05
	var replication_config = SceneReplicationConfig.new()
	for prop in properties.keys():
		var mode = properties[prop]
		replication_config.add_property(prop)
		replication_config.property_set_replication_mode(prop, mode)
		replication_config.property_set_spawn(prop, true)
	sync.replication_config = replication_config
	node.add_child(sync)

func _actualizar_visibilidad_sincronizadores() -> void:
	for cont in [_contenedor_jugadores, _contenedor_vehiculos, get_parent()]:
		if not is_instance_valid(cont):
			continue
		for child in cont.get_children():
			var sync_node = child.get_node_or_null("Sync")
			if sync_node and sync_node is MultiplayerSynchronizer:
				sync_node.update_visibility()

func _agregar_etiqueta_nombre_3d(target: Node3D, texto: String, offset: Vector3) -> void:
	var lbl = Label3D.new()
	lbl.name = "NombreJugador3D"
	lbl.text = texto.to_upper()
	lbl.position = offset
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = false
	lbl.pixel_size = 0.0045
	lbl.font_size = 32
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.85, 0.15, 0.95)
	lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
		lbl.font = load("res://recursos/fonts/Moderniz.otf")
	target.add_child(lbl)

func _obtener_nombre_jugador(peer_id: int) -> String:
	if peer_id == multiplayer.get_unique_id():
		var datos = get_node_or_null("/root/DatosUsuario")
		if datos and "nombre_usuario" in datos and String(datos.nombre_usuario).strip_edges() != "":
			return String(datos.nombre_usuario).strip_edges()
	var pm = get_node_or_null("/root/PlayersManager")
	if pm and pm.has_method("obtener_nombre"):
		return pm.obtener_nombre(peer_id)
	var net = get_node_or_null("/root/Network")
	if net and "nombres_jugadores" in net and net.nombres_jugadores.has(peer_id):
		return String(net.nombres_jugadores[peer_id])
	return "CONDUCTOR #" + str(peer_id)

# ─────────────────────────────────────────────────────────────────────────────
# HUD DE ESTADO MULTIJUGADOR Y NOTIFICACIONES EN PANTALLA
# ─────────────────────────────────────────────────────────────────────────────

func _crear_hud_multijugador(raiz: Node) -> void:
	_hud_mp_canvas = CanvasLayer.new()
	_hud_mp_canvas.name = "HUDMultijugador"
	_hud_mp_canvas.layer = 95

	var panel = PanelContainer.new()
	panel.name = "BadgeSala"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -170.0
	panel.offset_right = 170.0
	panel.offset_top = 18.0
	panel.offset_bottom = 60.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.12, 0.78)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.15, 0.75, 0.45, 0.85)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	_lbl_estado_sala = Label.new()
	_lbl_estado_sala.add_theme_font_size_override("font_size", 15)
	_lbl_estado_sala.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
		_lbl_estado_sala.add_theme_font_override("font", load("res://recursos/fonts/Moderniz.otf"))
	panel.add_child(_lbl_estado_sala)
	_hud_mp_canvas.add_child(panel)

	# CRÍTICO: add_child.call_deferred para evitar 'Parent node is busy setting up children'
	raiz.add_child.call_deferred(_hud_mp_canvas)

func _actualizar_hud_multijugador() -> void:
	if not is_instance_valid(_lbl_estado_sala) or not is_inside_tree() or not multiplayer:
		return
	var net = get_node_or_null("/root/Network")
	var rol = "HOST" if (multiplayer.has_multiplayer_peer() and multiplayer.is_server()) else "CLIENTE"
	if net and net.get("is_dedicated_vps") == true:
		rol = "VPS 24/7"
	var conectados = 1 + multiplayer.get_peers().size() if multiplayer.has_multiplayer_peer() else 1
	conectados = clampi(conectados, 1, MAX_JUGADORES)
	var ip_str = net.get_ip_address() if net and net.has_method("get_ip_address") else "127.0.0.1"
	var port_str = str(net.current_port) if net and "current_port" in net else "10567"
	_lbl_estado_sala.text = "● %s (%s:%s) | JUGADORES: %d/%d" % [rol, ip_str, port_str, conectados, MAX_JUGADORES]

@rpc("any_peer", "call_local", "reliable")
func notificar_conexion_jugador(peer_id: int, nombre: String = "") -> void:
	var p_name = nombre if nombre != "" else _obtener_nombre_jugador(peer_id)
	_mostrar_notificacion(p_name.to_upper() + " SE HA UNIDO A LA RUTA (%d/%d)" % [clampi(1 + multiplayer.get_peers().size(), 1, MAX_JUGADORES), MAX_JUGADORES])
	_actualizar_hud_multijugador()

func _mostrar_notificacion(texto: String) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100

	var label = Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
		label.add_theme_font_override("font", load("res://recursos/fonts/Moderniz.otf"))
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.12, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.008, 0.43, 0.8, 0.85)
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
	if get_parent():
		get_parent().add_child.call_deferred(canvas)

	panel.anchors_preset = Control.PRESET_CENTER_TOP
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.set_deferred("position", Vector2(
		(get_viewport().get_visible_rect().size.x - panel.size.x) / 2.0, 50
	))

	var tw = create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.8)
	tw.finished.connect(func(): canvas.queue_free())
