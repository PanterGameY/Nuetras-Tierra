class_name EditorColabManager
extends Node

## EditorColabManager.gd — Creación de Mapas Online Colaborativa (WebSocket ligero)
## Permite que hasta 6 editores trabajen en el mismo proyecto simultáneamente con
## sincronización de estado, código de invitación y cursores 3D en vivo.

signal estado_colab_cambiado(activo: bool, codigo: String, num_editores: int)

const FONT := preload("res://recursos/fonts/Moderniz.otf")
const ICON_ESMERALDA := preload("res://recursos/botones/Esmeralda.png")
const UIEditorHelpers := preload("res://mundo/editor_mapas/ui/UIEditorHelpers.gd")
const WS_BUFFER_BYTES := 4 * 1024 * 1024 # 4 MB para snapshots de mapas grandes
const SYNC_DEBOUNCE_SEC := 0.85
const PRECIO_STOCK_ESMERALDAS := 100
const MAX_JUGADORES_COLAB := 6

const C_BG_OVERLAY := Color(0.02, 0.03, 0.04, 0.72)
const C_BG_PANEL := Color(0.06, 0.07, 0.08, 0.94)
const C_BG_CARD := Color(0.09, 0.10, 0.12, 0.90)
const C_BG_CARD_SELF := Color(0.12, 0.11, 0.09, 0.92)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.92)
const C_AMBER_BRIGHT := Color(1.0, 0.80, 0.40, 1.0)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_ONLINE := Color(0.28, 0.88, 0.54, 1.0)
const C_DISCORD := Color(0.45, 0.54, 0.98, 1.0)
const C_TEXT_MAIN := Color(0.94, 0.95, 0.97, 1.0)
const C_TEXT_MUTED := Color(0.62, 0.66, 0.72, 0.92)
const MAX_AVATAR_CACHE := 30

var _editor: Node3D = null
var _ws: WebSocketPeer = null
var _ws_abierto: bool = false
var _cola_envio: Array[Dictionary] = []

var sesion_activa: bool = false
var codigo_sala: String = ""
var nombre_proyecto: String = ""
var mi_peer_id: int = 0
var revision_actual: int = 0
var edicion_bloqueada: bool = false
var peers_conectados: Array = []
var salas_abiertas: Array = []

var _aplicando_remoto: bool = false
var _sync_pendiente: bool = false
var _sync_timer: float = 0.0
var _resumen_pendiente: String = "Editó el mapa"
var _pendiente_consumir_stock: bool = false
var _terreno_deltas_pendientes: Dictionary = {}
var _categorias_pendientes: Dictionary = {} # cat -> summary
var _esperando_respuesta_timer: float = 0.0
var _ping_timer: float = 0.0
var mi_ping_ms: int = 0
var _btn_lock_host: Button = null
var _avatar_cache: Dictionary = {}
var _avatares_descargando: Dictionary = {}
var _material_circular: ShaderMaterial = null

# Modal UI
var _capa_modal: CanvasLayer = null
var _panel_modal: PanelContainer = null
var _lbl_estado_modal: Label = null
var _lbl_stocks_info: Label = null
var _lbl_codigo_grande: Label = null
var _lbl_revision: Label = null
var _input_codigo: LineEdit = null
var _input_proyecto: LineEdit = null
var _vbox_sin_sesion: VBoxContainer = null
var _vbox_en_sesion: VBoxContainer = null
var _lista_peers_vbox: VBoxContainer = null
var _lista_stocks_vbox: VBoxContainer = null
var _lbl_stocks_titulo: Label = null
var _btn_comprar_slot: Button = null
var _btn_comprar_slot_sesion: Button = null
var _lista_salas_vbox: VBoxContainer = null


func _ready() -> void:
	set_process(false)


func configurar(editor_ref: Node3D) -> void:
	_editor = editor_ref


func esta_aplicando_remoto() -> bool:
	return _aplicando_remoto


func _exit_tree() -> void:
	if _ws:
		_ws.close()
		_ws = null


func _process(delta: float) -> void:
	if _ws == null:
		set_process(false)
		return

	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _ws_abierto:
			_ws_abierto = true
			_actualizar_estado_ui("CONECTADO AL SERVIDOR COLABORATIVO", C_ONLINE)
			_vaciar_cola()

		while _ws.get_available_packet_count() > 0:
			var raw := _ws.get_packet().get_string_from_utf8()
			_procesar_mensaje(raw)

		if _esperando_respuesta_timer > 0.0:
			_esperando_respuesta_timer -= delta
			if _esperando_respuesta_timer <= 0.0:
				_pendiente_consumir_stock = false
				_actualizar_estado_ui("EL SERVIDOR NO SOPORTA COLAB AUN · DESPLIEGA server.js EN RENDER", C_CRIMSON)
				_notificar_editor("Sin respuesta del servidor: sube los cambios de server.js a Render.")

		if sesion_activa and _sync_pendiente:
			_sync_timer -= delta
			if _sync_timer <= 0.0:
				_sync_pendiente = false
				if not _categorias_pendientes.is_empty():
					_enviar_parches_pendientes()
				else:
					sincronizar_ahora(_resumen_pendiente)

		if sesion_activa:
			_ping_timer -= delta
			if _ping_timer <= 0.0:
				_ping_timer = 4.0
				_enviar({"type": "collab_ping", "t": Time.get_ticks_msec()})

	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		_ws_abierto = false
		_pendiente_consumir_stock = false
		if sesion_activa:
			_respaldar_copia_local()
			sesion_activa = false
			codigo_sala = ""
			edicion_bloqueada = false
			peers_conectados.clear()
			estado_colab_cambiado.emit(false, "", 0)
			_notificar_editor("Conexión cerrada. Se guardó una copia local.")
		_actualizar_estado_ui("DESCONECTADO DEL SERVIDOR", C_CRIMSON)
		_refrescar_modal_ui()
		set_process(false)


# ── CONEXIÓN WEBSOCKET ────────────────────────────────────────────────────

func _obtener_ws_url() -> String:
	var net := get_node_or_null("/root/Network")
	if net and ("vps_signaling_url" in net):
		var u := str(net.vps_signaling_url).strip_edges()
		if not u.is_empty():
			return u
	return "wss://nuestra-tierra-signaling.onrender.com"


func _asegurar_conexion() -> bool:
	if _ws and (_ws.get_ready_state() == WebSocketPeer.STATE_OPEN or _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING):
		set_process(true)
		return true

	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = WS_BUFFER_BYTES
	_ws.outbound_buffer_size = WS_BUFFER_BYTES
	var err := _ws.connect_to_url(_obtener_ws_url())
	if err != OK:
		_ws = null
		_ws_abierto = false
		_actualizar_estado_ui("ERROR AL CONECTAR CON EL SERVIDOR", C_CRIMSON)
		return false

	_ws_abierto = false
	set_process(true)
	_actualizar_estado_ui("CONECTANDO AL SERVIDOR COLABORATIVO...", C_AMBER_BRIGHT)
	return true


func _enviar(payload: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(payload))
	else:
		_cola_envio.append(payload)
		_asegurar_conexion()


func _vaciar_cola() -> void:
	while _cola_envio.size() > 0 and _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var msg: Dictionary = _cola_envio.pop_front()
		_ws.send_text(JSON.stringify(msg))


func _nombre_usuario_actual() -> String:
	var du := get_node_or_null("/root/DatosUsuario")
	if du and "nombre_usuario" in du:
		var n := str(du.nombre_usuario).strip_edges()
		if not n.is_empty():
			return n
	return "Creador"


func _datos_perfil_local() -> Dictionary:
	var discord := ""
	var avatar_url := ""
	var avatar_tex: Texture2D = null
	var du := get_node_or_null("/root/DatosUsuario")
	if du:
		discord = str(du.discord_username).strip_edges()
		if "avatar_texture" in du and du.avatar_texture is Texture2D:
			avatar_tex = du.avatar_texture
	var sb := get_node_or_null("/root/SupabaseManager")
	if sb and "user_metadata" in sb and sb.user_metadata is Dictionary:
		avatar_url = str(sb.user_metadata.get("avatar_url", sb.user_metadata.get("picture", ""))).strip_edges()
	return {"discord": discord, "avatar_url": avatar_url, "avatar_tex": avatar_tex}


# ── API PÚBLICA DE SESIÓN ─────────────────────────────────────────────────

func _obtener_clave_mapa_actual() -> String:
	if sesion_activa and not nombre_proyecto.strip_edges().is_empty():
		return nombre_proyecto.strip_edges()
	if is_instance_valid(_input_proyecto) and not _input_proyecto.text.strip_edges().is_empty():
		return _input_proyecto.text.strip_edges()
	if _editor and "_nombre_mapa_actual" in _editor:
		var n := str(_editor._nombre_mapa_actual).strip_edges()
		if not n.is_empty():
			return n
	return "Mapa Guardado"


func obtener_stocks_disponibles() -> int:
	var du := get_node_or_null("/root/DatosUsuario")
	if du and du.has_method("obtener_slots_mapa"):
		return int(du.obtener_slots_mapa(_obtener_clave_mapa_actual()))
	return 0


func comprar_stock_online() -> bool:
	var mapa := _obtener_clave_mapa_actual()
	if obtener_stocks_disponibles() >= MAX_JUGADORES_COLAB:
		_actualizar_estado_ui("LIMITE ALCANZADO: MAXIMO %d SLOTS EN '%s'" % [MAX_JUGADORES_COLAB, mapa.to_upper()], C_AMBER_BRIGHT)
		_notificar_editor("Máximo %d slots permitidos en '%s'" % [MAX_JUGADORES_COLAB, mapa])
		return false
	var du := get_node_or_null("/root/DatosUsuario")
	if not du or not du.has_method("comprar_slot_mapa"):
		_actualizar_estado_ui("NO SE PUDO ACCEDER A TUS DATOS DE USUARIO", C_CRIMSON)
		return false
	if du.comprar_slot_mapa(mapa, PRECIO_STOCK_ESMERALDAS, MAX_JUGADORES_COLAB):
		var total := obtener_stocks_disponibles()
		_actualizar_estado_ui("SLOT COMPRADO PARA '%s' (%d / %d)" % [mapa.to_upper(), total, MAX_JUGADORES_COLAB], C_ONLINE)
		_notificar_editor("Slot comprado para '%s' (%d/%d)" % [mapa, total, MAX_JUGADORES_COLAB])
		_refrescar_modal_ui()
		return true
	_actualizar_estado_ui("NECESITAS %d ESMERALDAS PARA COMPRAR 1 SLOT" % PRECIO_STOCK_ESMERALDAS, C_CRIMSON)
	_notificar_editor("Esmeraldas insuficientes (%d requeridas)" % PRECIO_STOCK_ESMERALDAS)
	return false


func crear_sesion_online(proyecto: String = "") -> void:
	if obtener_stocks_disponibles() <= 0:
		_actualizar_estado_ui("NECESITAS 1 STOCK ONLINE (%d ESMERALDAS) PARA CREAR UN PROYECTO" % PRECIO_STOCK_ESMERALDAS, C_CRIMSON)
		_notificar_editor("Compra 1 Stock Online (%d Esmeraldas) para crear un proyecto." % PRECIO_STOCK_ESMERALDAS)
		abrir_modal_colab()
		return

	var nom := proyecto.strip_edges()
	if nom.is_empty() and _editor and "_nombre_mapa_actual" in _editor:
		nom = str(_editor._nombre_mapa_actual).strip_edges()
	if nom.is_empty():
		nom = "Proyecto Online"

	var snap: Dictionary = {}
	if _editor and _editor.has_method("serializar_estado_mapa_dict"):
		snap = _editor.serializar_estado_mapa_dict()
		if "controlador_terreno" in _editor and _editor.controlador_terreno and _editor.controlador_terreno.has_method("serializar_alturas_modificadas_online"):
			var th = _editor.controlador_terreno.serializar_alturas_modificadas_online()
			if th is Dictionary and th.get("pts", []) is Array and not th["pts"].is_empty():
				snap["terreno_heights"] = th

	var perf := _datos_perfil_local()
	_pendiente_consumir_stock = false
	_esperando_respuesta_timer = 8.0
	_enviar({
		"type": "collab_create",
		"player_name": _nombre_usuario_actual(),
		"discord": perf["discord"],
		"avatar_url": perf["avatar_url"],
		"project_name": nom,
		"snapshot": snap
	})
	_actualizar_estado_ui("CREANDO PROYECTO ONLINE...", C_AMBER_BRIGHT)


func unirse_sesion_online(codigo: String) -> void:
	var c := codigo.strip_edges().to_upper()
	if c.is_empty():
		_actualizar_estado_ui("INGRESA UN CODIGO VALIDO (6 CARACTERES)", C_CRIMSON)
		return
	var perf := _datos_perfil_local()
	_esperando_respuesta_timer = 8.0
	_enviar({
		"type": "collab_join",
		"code": c,
		"player_name": _nombre_usuario_actual(),
		"discord": perf["discord"],
		"avatar_url": perf["avatar_url"]
	})
	_actualizar_estado_ui("UNIENDOSE AL PROYECTO %s..." % c, C_AMBER_BRIGHT)


func solicitar_proyectos_abiertos() -> void:
	_enviar({"type": "collab_list"})


func salir_sesion_online() -> void:
	if sesion_activa:
		_respaldar_copia_local()
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"type": "collab_leave"}))
		_ws.close()
	_ws = null
	_ws_abierto = false
	_pendiente_consumir_stock = false
	sesion_activa = false
	codigo_sala = ""
	edicion_bloqueada = false
	peers_conectados.clear()
	_categorias_pendientes.clear()
	_sync_pendiente = false
	set_process(false)
	estado_colab_cambiado.emit(false, "", 0)
	_notificar_editor("Saliste de la sesión (copia local guardada).")
	_refrescar_modal_ui()


func _respaldar_copia_local() -> void:
	if _editor and _editor.has_method("guardar_mapa"):
		_editor.guardar_mapa()


func es_host_actual() -> bool:
	for p in peers_conectados:
		if p is Dictionary and int(p.get("peer_id", -1)) == mi_peer_id:
			return bool(p.get("is_host", false))
	return mi_peer_id == 1


func alternar_bloqueo_edicion() -> void:
	if not sesion_activa or not es_host_actual():
		return
	_enviar({"type": "collab_lock", "locked": not edicion_bloqueada})


func expulsar_editor(target_peer_id: int) -> void:
	if not sesion_activa or not es_host_actual():
		return
	_enviar({"type": "collab_kick", "target_peer_id": target_peer_id})


func notificar_cambio_categoria(categoria: String, resumen: String = "Editó el mapa") -> void:
	if not sesion_activa or _aplicando_remoto:
		return
	if edicion_bloqueada and not es_host_actual():
		_notificar_editor("El anfitrión pausó las ediciones.")
		return
	_categorias_pendientes[categoria] = resumen
	_resumen_pendiente = resumen
	_sync_pendiente = true
	_sync_timer = SYNC_DEBOUNCE_SEC


func _enviar_parches_pendientes() -> void:
	if not sesion_activa or not _editor:
		_categorias_pendientes.clear()
		return
	var cats := _categorias_pendientes.keys()
	_categorias_pendientes.clear()
	for cat in cats:
		var c_str := str(cat)
		var payload = null
		if c_str == "terreno":
			if not _terreno_deltas_pendientes.is_empty() and "controlador_terreno" in _editor and _editor.controlador_terreno:
				payload = _editor.controlador_terreno.serializar_snapshot_altura(_terreno_deltas_pendientes)
				_terreno_deltas_pendientes.clear()
		elif c_str == "vias":
			if "controlador_carreteras" in _editor and _editor.controlador_carreteras:
				payload = {
					"vias": _editor.controlador_carreteras.serializar_carreteras(),
					"equip": _editor.controlador_equipamiento.serializar_equipamiento() if ("controlador_equipamiento" in _editor and _editor.controlador_equipamiento) else []
				}
		elif _editor.has_method("_capturar_estado_categoria"):
			payload = _editor._capturar_estado_categoria(c_str)
		if payload != null:
			_enviar({
				"type": "collab_patch",
				"category": c_str,
				"payload": payload,
				"summary": _resumen_pendiente
			})


func notificar_cambio_local(resumen: String = "Editó el mapa") -> void:
	if not sesion_activa or _aplicando_remoto:
		return
	if edicion_bloqueada and not es_host_actual():
		_notificar_editor("El anfitrión pausó las ediciones.")
		return
	_resumen_pendiente = resumen
	_sync_pendiente = true
	_sync_timer = SYNC_DEBOUNCE_SEC


func registrar_terreno_delta(snap: Dictionary) -> void:
	if not sesion_activa or _aplicando_remoto or snap.is_empty():
		return
	for k in snap.keys():
		_terreno_deltas_pendientes[k] = snap[k]
		if _terreno_deltas_pendientes.size() > 4000:
			break


func sincronizar_ahora(resumen: String = "Sincronizó el mapa") -> void:
	if not sesion_activa or _aplicando_remoto:
		return
	if not _editor or not _editor.has_method("serializar_estado_mapa_dict"):
		return
	var snap: Dictionary = _editor.serializar_estado_mapa_dict()
	if not _terreno_deltas_pendientes.is_empty() and "controlador_terreno" in _editor and _editor.controlador_terreno:
		if _editor.controlador_terreno.has_method("serializar_snapshot_altura"):
			snap["terreno_heights"] = _editor.controlador_terreno.serializar_snapshot_altura(_terreno_deltas_pendientes)
		_terreno_deltas_pendientes.clear()
	_enviar({
		"type": "collab_sync",
		"summary": resumen,
		"snapshot": snap
	})


# ── PROCESAMIENTO DE MENSAJES ─────────────────────────────────────────────

func _procesar_mensaje(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	var t := str(data.get("type", ""))

	match t:
		"collab_rooms":
			var arr = data.get("rooms", [])
			salas_abiertas = arr if arr is Array else []
			_refrescar_lista_salas()

		"collab_created":
			_esperando_respuesta_timer = 0.0
			if _pendiente_consumir_stock:
				_pendiente_consumir_stock = false
				var du := get_node_or_null("/root/DatosUsuario")
				if du and du.has_method("consumir_stock_editor_online"):
					du.consumir_stock_editor_online()
			sesion_activa = true
			codigo_sala = str(data.get("code", ""))
			mi_peer_id = int(data.get("peer_id", 1))
			nombre_proyecto = str(data.get("project_name", "Proyecto Online"))
			revision_actual = int(data.get("revision", 1))
			peers_conectados = data.get("peers", []) if data.get("peers") is Array else []
			estado_colab_cambiado.emit(true, codigo_sala, peers_conectados.size())
			_notificar_editor("Proyecto online creado · Código: %s (1 Stock usado)" % codigo_sala)
			_actualizar_estado_ui("SESION ACTIVA · COMPARTE EL CODIGO %s" % codigo_sala, C_ONLINE)
			_refrescar_modal_ui()

		"collab_joined":
			_esperando_respuesta_timer = 0.0
			sesion_activa = true
			codigo_sala = str(data.get("code", ""))
			mi_peer_id = int(data.get("peer_id", 0))
			nombre_proyecto = str(data.get("project_name", "Proyecto Online"))
			revision_actual = int(data.get("revision", 1))
			peers_conectados = data.get("peers", []) if data.get("peers") is Array else []
			var snap = data.get("snapshot", {})
			if snap is Dictionary and not snap.is_empty():
				_aplicar_snapshot_con_carga(snap)
			estado_colab_cambiado.emit(true, codigo_sala, peers_conectados.size())
			_notificar_editor("Unido al proyecto '%s' (%s)" % [nombre_proyecto, codigo_sala])
			_actualizar_estado_ui("CONECTADO AL PROYECTO %s" % codigo_sala, C_ONLINE)
			_refrescar_modal_ui()

		"collab_peer_joined":
			peers_conectados = data.get("peers", []) if data.get("peers") is Array else []
			var nom := str(data.get("name", "Editor"))
			estado_colab_cambiado.emit(true, codigo_sala, peers_conectados.size())
			_notificar_editor("%s se unió al proyecto online" % nom)
			_refrescar_modal_ui()

		"collab_peer_left":
			peers_conectados = data.get("peers", []) if data.get("peers") is Array else []
			var nom := str(data.get("name", "Editor"))
			estado_colab_cambiado.emit(true, codigo_sala, peers_conectados.size())
			_notificar_editor("%s salió del proyecto" % nom)
			_refrescar_modal_ui()

		"collab_state_updated":
			revision_actual = int(data.get("revision", revision_actual + 1))
			var from_name := str(data.get("from_name", "Editor"))
			var summary := str(data.get("summary", "actualizó el mapa"))
			var snap = data.get("snapshot", {})
			if snap is Dictionary and not snap.is_empty():
				_aplicar_snapshot_remoto(snap)
			_notificar_editor("%s: %s (rev #%d)" % [from_name, summary, revision_actual])
			_refrescar_modal_ui()

		"collab_sync_ack":
			revision_actual = int(data.get("revision", revision_actual))
			if is_instance_valid(_lbl_revision):
				_lbl_revision.text = "REVISION #%d · SINCRONIZADO" % revision_actual

		"collab_patch_received":
			revision_actual = int(data.get("revision", revision_actual + 1))
			var from_name := str(data.get("from_name", "Editor"))
			var cat := str(data.get("category", ""))
			var summary := str(data.get("summary", "editó " + cat))
			_aplicar_parche_remoto(cat, data.get("payload", null))
			_notificar_editor("%s: %s" % [from_name, summary])
			_refrescar_modal_ui()

		"collab_lock_changed":
			edicion_bloqueada = bool(data.get("locked", false))
			_notificar_editor("Edición pausada por el anfitrión" if edicion_bloqueada else "Edición habilitada")
			_refrescar_modal_ui()

		"collab_kicked", "collab_closed":
			if t == "collab_kicked":
				_respaldar_copia_local()
			sesion_activa = false
			codigo_sala = ""
			peers_conectados.clear()
			estado_colab_cambiado.emit(false, "", 0)
			var motivo := str(data.get("reason", "La sala colaborativa fue cerrada."))
			_notificar_editor(motivo)
			_actualizar_estado_ui(motivo.to_upper(), C_CRIMSON)
			_refrescar_modal_ui()

		"collab_pong":
			var t_env := int(data.get("t", 0))
			if t_env > 0:
				mi_ping_ms = maxi(1, Time.get_ticks_msec() - t_env)
				if sesion_activa:
					_enviar({"type": "collab_ping_report", "ping_ms": mi_ping_ms})

		"collab_peers_updated":
			if data.get("peers") is Array:
				peers_conectados = data["peers"]
				if is_instance_valid(_capa_modal) and _capa_modal.visible and sesion_activa:
					_refrescar_modal_ui()

		"collab_error":
			_esperando_respuesta_timer = 0.0
			_pendiente_consumir_stock = false
			var msg := str(data.get("message", "Error en sesión colaborativa"))
			_actualizar_estado_ui(msg.to_upper(), C_CRIMSON)
			_notificar_editor(msg)


func _aplicar_parche_remoto(cat: String, payload) -> void:
	if not _editor or payload == null:
		return
	_aplicando_remoto = true
	if cat == "terreno" and payload is Array:
		if "controlador_terreno" in _editor and _editor.controlador_terreno and _editor.controlador_terreno.has_method("deserializar_snapshot_altura"):
			var t_snap: Dictionary = _editor.controlador_terreno.deserializar_snapshot_altura(payload)
			_editor.controlador_terreno.restaurar_snapshot_altura(t_snap)
	elif cat == "vias" and payload is Dictionary:
		if "controlador_carreteras" in _editor and _editor.controlador_carreteras and payload.has("vias"):
			_editor.controlador_carreteras.deserializar_carreteras(payload["vias"])
		if "controlador_equipamiento" in _editor and _editor.controlador_equipamiento and payload.has("equip"):
			_editor.controlador_equipamiento.deserializar_equipamiento(payload["equip"])
	elif _editor.has_method("_aplicar_estado_categoria"):
		_editor._aplicar_estado_categoria(cat, payload)
	_aplicando_remoto = false


func _aplicar_snapshot_con_carga(snap: Dictionary) -> void:
	var carga := UIEditorHelpers.crear_carga_sencilla(self, "CARGANDO PROYECTO...")
	if is_inside_tree() and get_tree():
		await get_tree().process_frame
	_aplicar_snapshot_remoto(snap)
	UIEditorHelpers.cerrar_carga_sencilla(carga)


func _aplicar_snapshot_remoto(snap: Dictionary) -> void:
	if not _editor or not _editor.has_method("aplicar_estado_mapa_dict"):
		return
	_aplicando_remoto = true
	_editor.aplicar_estado_mapa_dict(snap, false)
	if snap.has("terreno_heights"):
		if "controlador_terreno" in _editor and _editor.controlador_terreno and _editor.controlador_terreno.has_method("aplicar_alturas_online"):
			_editor.controlador_terreno.aplicar_alturas_online(snap["terreno_heights"])
	_aplicando_remoto = false


func _notificar_editor(msg: String) -> void:
	if _editor and "ui_editor" in _editor and is_instance_valid(_editor.ui_editor):
		if _editor.ui_editor.has_method("mostrar_notificacion"):
			_editor.ui_editor.mostrar_notificacion(msg)


# ── MODAL UI GLASSMORPHISM AUTOMOTRIZ ─────────────────────────────────────

func abrir_modal_colab() -> void:
	if not is_instance_valid(_capa_modal):
		_construir_modal()
	_capa_modal.visible = true
	_refrescar_modal_ui()

	if is_instance_valid(_panel_modal):
		_panel_modal.pivot_offset = _panel_modal.size * 0.5
		_panel_modal.scale = Vector2(0.92, 0.92)
		_panel_modal.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_panel_modal, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel_modal, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func cerrar_modal_colab() -> void:
	if is_instance_valid(_capa_modal):
		_capa_modal.visible = false


func _construir_modal() -> void:
	_capa_modal = CanvasLayer.new()
	_capa_modal.layer = 140
	add_child(_capa_modal)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG_OVERLAY
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cerrar_modal_colab()
	)
	_capa_modal.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 140)
	margin.add_theme_constant_override("margin_right", 140)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 70)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_modal.add_child(margin)

	_panel_modal = PanelContainer.new()
	_panel_modal.custom_minimum_size = Vector2(1100, 680)
	_panel_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := _crear_estilo(C_BG_PANEL, C_BORDER_FROST, 16, 1, 14)
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 26.0
	sb.content_margin_bottom = 26.0
	_panel_modal.add_theme_stylebox_override("panel", sb)
	margin.add_child(_panel_modal)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	_panel_modal.add_child(root)

	# Header minimalista
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)

	var lbl_t := Label.new()
	lbl_t.text = "COLAB ONLINE"
	lbl_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_t.add_theme_font_override("font", FONT)
	lbl_t.add_theme_font_size_override("font_size", 36)
	lbl_t.add_theme_color_override("font_color", C_TEXT_MAIN)
	header.add_child(lbl_t)

	_lbl_stocks_info = Label.new()
	_lbl_stocks_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lbl_stocks_info.text = "SLOTS: 0 / %d" % MAX_JUGADORES_COLAB
	_lbl_stocks_info.add_theme_font_override("font", FONT)
	_lbl_stocks_info.add_theme_font_size_override("font_size", 20)
	_lbl_stocks_info.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	header.add_child(_lbl_stocks_info)

	var btn_cerrar := _crear_boton("CERRAR", C_CRIMSON, 150, 52, 20, false)
	btn_cerrar.pressed.connect(cerrar_modal_colab)
	header.add_child(btn_cerrar)

	# ── VISTA SIN SESION (solo crear sala o agregar stocks) ──
	_vbox_sin_sesion = VBoxContainer.new()
	_vbox_sin_sesion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox_sin_sesion.alignment = BoxContainer.ALIGNMENT_BEGIN
	_vbox_sin_sesion.add_theme_constant_override("separation", 16)
	root.add_child(_vbox_sin_sesion)

	var card_crear := _crear_tarjeta()
	card_crear.custom_minimum_size = Vector2(680, 0)
	card_crear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vbox_sin_sesion.add_child(card_crear)
	var vb_c := VBoxContainer.new()
	vb_c.add_theme_constant_override("separation", 18)
	card_crear.add_child(vb_c)

	var lbl_c := Label.new()
	lbl_c.text = "CREAR SALA PARA ESTE MAPA"
	lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_c.add_theme_font_override("font", FONT)
	lbl_c.add_theme_font_size_override("font_size", 26)
	lbl_c.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	vb_c.add_child(lbl_c)

	_input_proyecto = _crear_input("Nombre del proyecto")
	_input_proyecto.text_changed.connect(func(_t: String) -> void:
		_refrescar_solo_slots_sin_sesion()
	)
	vb_c.add_child(_input_proyecto)

	var btn_crear := _crear_boton("INICIAR SALA", C_AMBER, 0, 62, 22, true)
	btn_crear.pressed.connect(func() -> void:
		crear_sesion_online(_input_proyecto.text)
	)
	vb_c.add_child(btn_crear)

	_lbl_stocks_titulo = Label.new()
	_lbl_stocks_titulo.text = "CASILLAS DE JUGADORES (0 / %d)" % MAX_JUGADORES_COLAB
	_lbl_stocks_titulo.add_theme_font_override("font", FONT)
	_lbl_stocks_titulo.add_theme_font_size_override("font_size", 20)
	_lbl_stocks_titulo.add_theme_color_override("font_color", C_TEXT_MAIN)
	_vbox_sin_sesion.add_child(_lbl_stocks_titulo)

	var scroll_stocks := ScrollContainer.new()
	scroll_stocks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox_sin_sesion.add_child(scroll_stocks)
	_lista_stocks_vbox = VBoxContainer.new()
	_lista_stocks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_stocks_vbox.add_theme_constant_override("separation", 10)
	scroll_stocks.add_child(_lista_stocks_vbox)

	_btn_comprar_slot = _crear_boton("+ COMPRAR SLOT DE JUGADOR (%d)" % PRECIO_STOCK_ESMERALDAS, C_AMBER, 0, 72, 24, true)
	_estilizar_boton_compra_slot(_btn_comprar_slot)
	_btn_comprar_slot.pressed.connect(comprar_stock_online)
	_vbox_sin_sesion.add_child(_btn_comprar_slot)

	# ── VISTA EN SESION ──
	_vbox_en_sesion = VBoxContainer.new()
	_vbox_en_sesion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox_en_sesion.add_theme_constant_override("separation", 18)
	_vbox_en_sesion.visible = false
	root.add_child(_vbox_en_sesion)

	var card_info := _crear_tarjeta()
	_vbox_en_sesion.add_child(card_info)
	var h_info := HBoxContainer.new()
	h_info.add_theme_constant_override("separation", 18)
	card_info.add_child(h_info)

	var vb_cod := VBoxContainer.new()
	vb_cod.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_cod.add_theme_constant_override("separation", 4)
	h_info.add_child(vb_cod)

	_lbl_codigo_grande = Label.new()
	_lbl_codigo_grande.text = "CODIGO: ------"
	_lbl_codigo_grande.add_theme_font_override("font", FONT)
	_lbl_codigo_grande.add_theme_font_size_override("font_size", 34)
	_lbl_codigo_grande.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	vb_cod.add_child(_lbl_codigo_grande)

	_lbl_revision = Label.new()
	_lbl_revision.text = "REVISION #1 · SINCRONIZADO"
	_lbl_revision.add_theme_font_override("font", FONT)
	_lbl_revision.add_theme_font_size_override("font_size", 18)
	_lbl_revision.add_theme_color_override("font_color", C_ONLINE)
	vb_cod.add_child(_lbl_revision)

	var btn_copiar := _crear_boton("COPIAR CODIGO", C_AMBER, 220, 56, 20, true)
	btn_copiar.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(codigo_sala)
		_actualizar_estado_ui("CODIGO %s COPIADO AL PORTAPAPELES" % codigo_sala, C_ONLINE)
	)
	h_info.add_child(btn_copiar)

	var btn_sync := _crear_boton("SINCRONIZAR", C_ONLINE, 200, 56, 20, false)
	btn_sync.pressed.connect(func() -> void:
		sincronizar_ahora("Sincronización manual")
		_actualizar_estado_ui("ENVIANDO CAMBIOS A TODOS LOS EDITORES...", C_AMBER_BRIGHT)
	)
	h_info.add_child(btn_sync)

	_btn_lock_host = _crear_boton("PAUSAR", C_AMBER, 160, 56, 18, false)
	_btn_lock_host.pressed.connect(alternar_bloqueo_edicion)
	h_info.add_child(_btn_lock_host)

	var btn_salir := _crear_boton("SALIR", C_CRIMSON, 150, 56, 20, false)
	btn_salir.pressed.connect(salir_sesion_online)
	h_info.add_child(btn_salir)

	var lbl_ed := Label.new()
	lbl_ed.text = "EDITORES CONECTADOS EN ESTE PROYECTO"
	lbl_ed.add_theme_font_override("font", FONT)
	lbl_ed.add_theme_font_size_override("font_size", 20)
	lbl_ed.add_theme_color_override("font_color", C_TEXT_MAIN)
	_vbox_en_sesion.add_child(lbl_ed)

	var scroll_peers := ScrollContainer.new()
	scroll_peers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox_en_sesion.add_child(scroll_peers)
	_lista_peers_vbox = VBoxContainer.new()
	_lista_peers_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_peers_vbox.add_theme_constant_override("separation", 10)
	scroll_peers.add_child(_lista_peers_vbox)

	_btn_comprar_slot_sesion = _crear_boton("+ COMPRAR SLOT DE JUGADOR (%d)" % PRECIO_STOCK_ESMERALDAS, C_AMBER, 0, 70, 23, true)
	_estilizar_boton_compra_slot(_btn_comprar_slot_sesion)
	_btn_comprar_slot_sesion.pressed.connect(comprar_stock_online)
	_vbox_en_sesion.add_child(_btn_comprar_slot_sesion)

	# Footer status
	_lbl_estado_modal = Label.new()
	_lbl_estado_modal.text = "LISTO PARA COLABORAR"
	_lbl_estado_modal.add_theme_font_override("font", FONT)
	_lbl_estado_modal.add_theme_font_size_override("font_size", 17)
	_lbl_estado_modal.add_theme_color_override("font_color", C_TEXT_MUTED)
	root.add_child(_lbl_estado_modal)


func _actualizar_estado_ui(txt: String, col: Color) -> void:
	if is_instance_valid(_lbl_estado_modal):
		_lbl_estado_modal.text = txt
		_lbl_estado_modal.add_theme_color_override("font_color", col)


func _refrescar_modal_ui() -> void:
	if not is_instance_valid(_capa_modal):
		return
	_vbox_sin_sesion.visible = not sesion_activa
	_vbox_en_sesion.visible = sesion_activa

	var stocks := mini(obtener_stocks_disponibles(), MAX_JUGADORES_COLAB)
	if is_instance_valid(_lbl_stocks_info):
		_lbl_stocks_info.text = "SLOTS: %d / %d" % [stocks, MAX_JUGADORES_COLAB]
	if is_instance_valid(_btn_comprar_slot):
		_btn_comprar_slot.disabled = (stocks >= MAX_JUGADORES_COLAB)
		_btn_comprar_slot.icon = null if stocks >= MAX_JUGADORES_COLAB else ICON_ESMERALDA
		_btn_comprar_slot.text = "MAXIMO DE SLOTS ALCANZADO (6 / 6)" if stocks >= MAX_JUGADORES_COLAB else "+ COMPRAR SLOT DE JUGADOR (%d)" % PRECIO_STOCK_ESMERALDAS
	if is_instance_valid(_btn_comprar_slot_sesion):
		_btn_comprar_slot_sesion.disabled = (stocks >= MAX_JUGADORES_COLAB)
		_btn_comprar_slot_sesion.icon = null if stocks >= MAX_JUGADORES_COLAB else ICON_ESMERALDA
		_btn_comprar_slot_sesion.text = "MAXIMO DE SLOTS ALCANZADO (6 / 6)" if stocks >= MAX_JUGADORES_COLAB else "+ COMPRAR SLOT DE JUGADOR (%d)" % PRECIO_STOCK_ESMERALDAS

	if sesion_activa:
		_lbl_codigo_grande.text = "%s  ·  CODIGO: %s" % [nombre_proyecto.to_upper(), codigo_sala]
		_lbl_revision.text = "REVISION #%d · %d/%d EDITORES%s" % [revision_actual, peers_conectados.size(), stocks, " · PAUSADO" if edicion_bloqueada else ""]
		if is_instance_valid(_btn_lock_host):
			_btn_lock_host.visible = es_host_actual()
			_btn_lock_host.text = "REANUDAR" if edicion_bloqueada else "PAUSAR"
		for c in _lista_peers_vbox.get_children():
			c.queue_free()
		var soy_host := es_host_actual()
		var ocupados := 0
		for p in peers_conectados:
			if not (p is Dictionary):
				continue
			_lista_peers_vbox.add_child(_crear_tarjeta_colaborador(p, soy_host))
			ocupados += 1
		var libres := maxi(0, stocks - ocupados)
		for i in range(libres):
			_lista_peers_vbox.add_child(_crear_tarjeta_casilla_vacia(ocupados + i + 1))
	else:
		if is_instance_valid(_input_proyecto) and _input_proyecto.text.is_empty() and _editor and "_nombre_mapa_actual" in _editor:
			_input_proyecto.text = str(_editor._nombre_mapa_actual)
		_refrescar_solo_slots_sin_sesion()
		_refrescar_lista_salas()


func _refrescar_solo_slots_sin_sesion() -> void:
	var stocks := mini(obtener_stocks_disponibles(), MAX_JUGADORES_COLAB)
	var mapa := _obtener_clave_mapa_actual().to_upper()
	if is_instance_valid(_lbl_stocks_info):
		_lbl_stocks_info.text = "SLOTS: %d / %d" % [stocks, MAX_JUGADORES_COLAB]
	if is_instance_valid(_lbl_stocks_titulo):
		_lbl_stocks_titulo.text = "CASILLAS DE '%s' (%d / %d)" % [mapa, stocks, MAX_JUGADORES_COLAB]
	if is_instance_valid(_btn_comprar_slot):
		_btn_comprar_slot.disabled = (stocks >= MAX_JUGADORES_COLAB)
		_btn_comprar_slot.icon = null if stocks >= MAX_JUGADORES_COLAB else ICON_ESMERALDA
		_btn_comprar_slot.text = "MAXIMO DE SLOTS ALCANZADO (6 / 6)" if stocks >= MAX_JUGADORES_COLAB else "+ COMPRAR SLOT DE JUGADOR (%d)" % PRECIO_STOCK_ESMERALDAS
	if is_instance_valid(_lista_stocks_vbox):
		for c in _lista_stocks_vbox.get_children():
			c.queue_free()
		for i in range(stocks):
			_lista_stocks_vbox.add_child(_crear_tarjeta_casilla_vacia(i + 1))


func _refrescar_lista_salas() -> void:
	if not is_instance_valid(_lista_salas_vbox):
		return
	for c in _lista_salas_vbox.get_children():
		c.queue_free()

	if salas_abiertas.is_empty():
		var lbl := Label.new()
		lbl.text = "No hay proyectos abiertos en este momento. Crea uno arriba o pide un código."
		lbl.add_theme_font_override("font", FONT)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", C_TEXT_MUTED)
		_lista_salas_vbox.add_child(lbl)
		return

	for s in salas_abiertas:
		if not (s is Dictionary):
			continue
		var code := str(s.get("code", ""))
		var card := _crear_tarjeta()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		card.add_child(hb)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l1 := Label.new()
		l1.text = str(s.get("project_name", "Proyecto")).to_upper()
		l1.add_theme_font_override("font", FONT)
		l1.add_theme_font_size_override("font_size", 22)
		l1.add_theme_color_override("font_color", C_TEXT_MAIN)
		vb.add_child(l1)

		var l2 := Label.new()
		l2.text = "HOST: %s · CODIGO: %s · %d/%d EDITORES" % [
			str(s.get("host_name", "Creador")).to_upper(),
			code,
			int(s.get("editors", 1)),
			int(s.get("max_editors", 6))
		]
		l2.add_theme_font_override("font", FONT)
		l2.add_theme_font_size_override("font_size", 16)
		l2.add_theme_color_override("font_color", C_AMBER)
		vb.add_child(l2)
		hb.add_child(vb)

		var btn := _crear_boton("UNIRSE", C_ONLINE, 160, 50, 20, false)
		btn.pressed.connect(func() -> void:
			unirse_sesion_online(code)
		)
		hb.add_child(btn)
		_lista_salas_vbox.add_child(card)


func _crear_tarjeta_casilla_vacia(indice: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 96)
	var sb := _crear_estilo(Color(0.07, 0.08, 0.10, 0.78), C_BORDER_FROST, 12, 1, 4)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(hbox)

	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(68, 68)
	avatar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(avatar_wrap)

	var marco := Panel.new()
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb_marco := StyleBoxFlat.new()
	sb_marco.bg_color = Color(0.09, 0.10, 0.12, 0.70)
	sb_marco.set_border_width_all(1)
	sb_marco.border_color = Color(0.78, 0.81, 0.85, 0.28)
	sb_marco.set_corner_radius_all(34)
	marco.add_theme_stylebox_override("panel", sb_marco)
	avatar_wrap.add_child(marco)

	var lbl_num := Label.new()
	lbl_num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_num.text = "%d" % indice
	lbl_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_num.add_theme_font_override("font", FONT)
	lbl_num.add_theme_font_size_override("font_size", 24)
	lbl_num.add_theme_color_override("font_color", C_TEXT_MUTED)
	marco.add_child(lbl_num)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_theme_constant_override("separation", 4)
	hbox.add_child(vb)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "CASILLA #%d · STOCK DISPONIBLE" % indice
	lbl_titulo.add_theme_font_override("font", FONT)
	lbl_titulo.add_theme_font_size_override("font_size", 20)
	lbl_titulo.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	vb.add_child(lbl_titulo)

	var lbl_sub := Label.new()
	lbl_sub.text = "Sin jugador · Esperando que alguien ingrese"
	lbl_sub.add_theme_font_override("font", FONT)
	lbl_sub.add_theme_font_size_override("font_size", 15)
	lbl_sub.add_theme_color_override("font_color", C_TEXT_MUTED)
	vb.add_child(lbl_sub)

	return card


func _crear_tarjeta_colaborador(p: Dictionary, soy_host: bool) -> PanelContainer:
	var pid := int(p.get("peer_id", -1))
	var es_local := (pid == mi_peer_id)
	var es_host_p := bool(p.get("is_host", false))
	var color_peer := Color.from_string(str(p.get("color", "#FFC52E")), C_AMBER_BRIGHT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 104)
	var borde := C_AMBER if es_local else C_BORDER_FROST
	var fondo := C_BG_CARD_SELF if es_local else C_BG_CARD
	var sb := _crear_estilo(fondo, borde, 12, 1, 6)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(hbox)

	# Avatar circular 72x72 + inicial + punto verde en línea (estilo ComunidadModal)
	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(72, 72)
	avatar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(avatar_wrap)

	var marco := Panel.new()
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb_marco := StyleBoxFlat.new()
	sb_marco.bg_color = Color(0.11, 0.13, 0.16, 0.95)
	sb_marco.set_border_width_all(2)
	sb_marco.border_color = C_AMBER if es_local else color_peer
	sb_marco.set_corner_radius_all(36)
	marco.add_theme_stylebox_override("panel", sb_marco)
	avatar_wrap.add_child(marco)

	var nombre_base := str(p.get("name", "Editor")).strip_edges()
	var inicial := nombre_base.substr(0, 1).to_upper() if not nombre_base.is_empty() else "?"
	var lbl_inicial := Label.new()
	lbl_inicial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_inicial.text = inicial
	lbl_inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_inicial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_inicial.add_theme_font_override("font", FONT)
	lbl_inicial.add_theme_font_size_override("font_size", 28)
	lbl_inicial.add_theme_color_override("font_color", C_AMBER_BRIGHT if es_local else C_TEXT_MAIN)
	avatar_wrap.add_child(lbl_inicial)

	var avatar_rect := TextureRect.new()
	avatar_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar_rect.offset_left = 3.0
	avatar_rect.offset_top = 3.0
	avatar_rect.offset_right = -3.0
	avatar_rect.offset_bottom = -3.0
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_rect.material = _obtener_material_circular()
	avatar_wrap.add_child(avatar_rect)

	_aplicar_avatar_colaborador(p, es_local, avatar_rect, lbl_inicial)

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dot.offset_left = -16.0
	dot.offset_top = -16.0
	dot.offset_right = 0.0
	dot.offset_bottom = 0.0
	var sb_dot := StyleBoxFlat.new()
	sb_dot.bg_color = C_ONLINE
	sb_dot.set_border_width_all(2)
	sb_dot.border_color = Color(0.06, 0.07, 0.08, 1.0)
	sb_dot.set_corner_radius_all(8)
	sb_dot.shadow_color = Color(C_ONLINE.r, C_ONLINE.g, C_ONLINE.b, 0.55)
	sb_dot.shadow_size = 5
	dot.add_theme_stylebox_override("panel", sb_dot)
	avatar_wrap.add_child(dot)

	# Nombre + Discord / Rol
	var vbox_info := VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox_info.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox_info)

	var nombre_txt := nombre_base.to_upper()
	if es_local:
		nombre_txt += "  (TU)"
	var lbl_nombre := Label.new()
	lbl_nombre.text = nombre_txt
	lbl_nombre.add_theme_font_override("font", FONT)
	lbl_nombre.add_theme_font_size_override("font_size", 26)
	lbl_nombre.add_theme_color_override("font_color", C_AMBER_BRIGHT if es_local else C_TEXT_MAIN)
	vbox_info.add_child(lbl_nombre)

	var discord_txt := str(p.get("discord", "")).strip_edges()
	var sub_txt := "Discord: @" + discord_txt if not discord_txt.is_empty() else ("Anfitrión del proyecto" if es_host_p else "Editando en vivo")
	var lbl_sub := Label.new()
	lbl_sub.text = sub_txt
	lbl_sub.add_theme_font_override("font", FONT)
	lbl_sub.add_theme_font_size_override("font_size", 17)
	lbl_sub.add_theme_color_override("font_color", C_DISCORD if not discord_txt.is_empty() else C_TEXT_MUTED)
	vbox_info.add_child(lbl_sub)

	# Pill de rol
	var pill_rol := PanelContainer.new()
	pill_rol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c_rol := C_AMBER if es_host_p else color_peer
	var sb_rol := _crear_estilo(
		Color(c_rol.r, c_rol.g, c_rol.b, 0.14),
		Color(c_rol.r, c_rol.g, c_rol.b, 0.72),
		10, 1, 0
	)
	sb_rol.content_margin_left = 18.0
	sb_rol.content_margin_right = 18.0
	sb_rol.content_margin_top = 8.0
	sb_rol.content_margin_bottom = 8.0
	pill_rol.add_theme_stylebox_override("panel", sb_rol)
	hbox.add_child(pill_rol)

	var lbl_rol := Label.new()
	lbl_rol.text = "HOST" if es_host_p else "EDITOR"
	lbl_rol.add_theme_font_override("font", FONT)
	lbl_rol.add_theme_font_size_override("font_size", 17)
	lbl_rol.add_theme_color_override("font_color", c_rol.lightened(0.25))
	pill_rol.add_child(lbl_rol)

	# Pill de Ping (ms)
	var ping_val := mi_ping_ms if es_local else int(p.get("ping_ms", 0))
	var col_ping := C_ONLINE if ping_val <= 90 else (C_AMBER_BRIGHT if ping_val <= 180 else C_CRIMSON)
	if ping_val <= 0:
		col_ping = C_TEXT_MUTED
	var pill_ping := PanelContainer.new()
	pill_ping.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_ping := _crear_estilo(Color(col_ping.r, col_ping.g, col_ping.b, 0.12), Color(col_ping.r, col_ping.g, col_ping.b, 0.60), 10, 1, 0)
	sb_ping.content_margin_left = 14.0
	sb_ping.content_margin_right = 14.0
	sb_ping.content_margin_top = 8.0
	sb_ping.content_margin_bottom = 8.0
	pill_ping.add_theme_stylebox_override("panel", sb_ping)
	hbox.add_child(pill_ping)

	var lbl_ping := Label.new()
	lbl_ping.text = ("%d MS" % ping_val) if ping_val > 0 else "-- MS"
	lbl_ping.add_theme_font_override("font", FONT)
	lbl_ping.add_theme_font_size_override("font_size", 16)
	lbl_ping.add_theme_color_override("font_color", col_ping)
	pill_ping.add_child(lbl_ping)

	if soy_host and not es_local and pid > 0:
		var btn_k := _crear_boton("EXPULSAR", C_CRIMSON, 150, 48, 17, false)
		btn_k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn_k.pressed.connect(func() -> void: expulsar_editor(pid))
		hbox.add_child(btn_k)

	return card


func _obtener_material_circular() -> ShaderMaterial:
	if _material_circular == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float alpha = 1.0 - smoothstep(0.47, 0.5, length(d));
	vec4 col = texture(TEXTURE, UV) * COLOR;
	col.a *= alpha;
	COLOR = col;
}"""
		_material_circular = ShaderMaterial.new()
		_material_circular.shader = sh
	return _material_circular


func _aplicar_avatar_colaborador(p: Dictionary, es_local: bool, rect: TextureRect, lbl_inicial: Label) -> void:
	if es_local:
		var du := get_node_or_null("/root/DatosUsuario")
		if du and "avatar_texture" in du and du.avatar_texture is Texture2D:
			rect.texture = du.avatar_texture
			lbl_inicial.visible = false
			return

	var url := str(p.get("avatar_url", "")).strip_edges()
	if url.is_empty():
		return
	if _avatar_cache.has(url):
		var cached = _avatar_cache[url]
		if cached is Texture2D:
			rect.texture = cached
			lbl_inicial.visible = false
		return
	if _avatares_descargando.has(url):
		_avatares_descargando[url].append({"rect": rect, "inicial": lbl_inicial})
		return

	_avatares_descargando[url] = [{"rect": rect, "inicial": lbl_inicial}]
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var targets: Array = _avatares_descargando.get(url, [])
		_avatares_descargando.erase(url)
		if status < 200 or status >= 300 or body.is_empty():
			return
		var img := Image.new()
		var ok := false
		if body.size() >= 8 and body[0] == 0x89 and body[1] == 0x50:
			ok = (img.load_png_from_buffer(body) == OK)
		elif body.size() >= 3 and body[0] == 0xFF and body[1] == 0xD8:
			ok = (img.load_jpg_from_buffer(body) == OK)
		elif body.size() >= 12 and body.slice(8, 12).get_string_from_ascii() == "WEBP":
			ok = (img.load_webp_from_buffer(body) == OK)
		if not ok:
			ok = (img.load_png_from_buffer(body) == OK or img.load_webp_from_buffer(body) == OK or img.load_jpg_from_buffer(body) == OK)
		if not ok or img.is_empty():
			return
		if img.get_width() > 128 or img.get_height() > 128:
			img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		var tex := ImageTexture.create_from_image(img)
		if _avatar_cache.size() >= MAX_AVATAR_CACHE:
			_avatar_cache.erase(_avatar_cache.keys()[0])
		_avatar_cache[url] = tex
		for t in targets:
			var r = t.get("rect")
			var l = t.get("inicial")
			if is_instance_valid(r):
				r.texture = tex
			if is_instance_valid(l):
				l.visible = false
	)
	if http.request(url, [], HTTPClient.METHOD_GET) != OK:
		http.queue_free()
		_avatares_descargando.erase(url)


func _crear_tarjeta() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _crear_estilo(C_BG_CARD, C_BORDER_FROST, 12, 1, 4)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	p.add_theme_stylebox_override("panel", sb)
	return p


func _crear_input(placeholder: String) -> LineEdit:
	var inp := LineEdit.new()
	inp.placeholder_text = placeholder
	inp.custom_minimum_size = Vector2(0, 54)
	inp.add_theme_font_override("font", FONT)
	inp.add_theme_font_size_override("font_size", 20)
	var sb := _crear_estilo(Color(0.05, 0.06, 0.08, 0.95), C_BORDER_FROST, 10, 1, 0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	inp.add_theme_stylebox_override("normal", sb)
	var sb_f := sb.duplicate()
	sb_f.border_color = C_AMBER
	inp.add_theme_stylebox_override("focus", sb_f)
	return inp


func _estilizar_boton_compra_slot(btn: Button) -> void:
	btn.icon = ICON_ESMERALDA
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btn.add_theme_constant_override("h_separation", 14)
	var normal := _crear_estilo(Color(0.88, 0.62, 0.16, 0.34), Color(1.0, 0.82, 0.36, 0.98), 12, 2, 8)
	var hover := _crear_estilo(Color(0.95, 0.70, 0.22, 0.50), Color(1.0, 0.90, 0.52, 1.0), 12, 2, 10)
	var pressed := _crear_estilo(Color(0.98, 0.74, 0.26, 0.65), Color(1.0, 0.94, 0.65, 1.0), 12, 2, 12)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))


func _crear_boton(texto: String, acento: Color, ancho: float, alto: float, font_sz: int, destacado: bool) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(ancho, alto)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg := Color(acento.r, acento.g, acento.b, 0.18) if destacado else Color(0.08, 0.09, 0.11, 0.84)
	var brd := Color(acento.r, acento.g, acento.b, 0.72) if destacado else Color(acento.r, acento.g, acento.b, 0.45)
	var normal := _crear_estilo(bg, brd, 10, 1, 4)
	var hover := _crear_estilo(Color(acento.r, acento.g, acento.b, 0.30), acento.lightened(0.2), 10, 1, 6)
	var pressed := _crear_estilo(Color(acento.r, acento.g, acento.b, 0.42), acento.lightened(0.25), 10, 1, 8)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", acento.lightened(0.30) if destacado else C_TEXT_MAIN)
	btn.add_theme_color_override("font_hover_color", acento.lightened(0.35))
	return btn


func _crear_estilo(fondo: Color, borde: Color, radio: int, grosor: int = 1, sombra: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(grosor)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = sombra
	sb.shadow_offset = Vector2(0, 3)
	return sb
