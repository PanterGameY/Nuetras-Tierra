extends Control

# ═══════════════════════════════════════════════════════════════════════
# LobbyMultijugador.gd — Sala de Espera Multijugador (Máximo 5 Personas)
# Sincronizada con Network.gd, RedManager.gd y PrincipalMultijugador.tscn
# Soporta:
#   - Host Jugador (Listen Server en LAN / Hotspot / VPN hasta 5 personas)
#   - Descubrimiento automático de salas LAN en vivo
#   - Conexión futura a Servidor VPS Dedicado (Salas 1..5 o IP personalizada)
# ═══════════════════════════════════════════════════════════════════════

const FONT = preload("res://recursos/fonts/Moderniz.otf")
const MAIN_MENU_SCENE = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const GAME_SCENE = "res://mundo/principal/PrincipalMultijugador.tscn"
const MAX_JUGADORES_PERMITIDOS: int = 5

@onready var network = get_node_or_null("/root/Network")
@onready var red_manager = get_node_or_null("/root/RedManager")
@onready var players_manager = get_node_or_null("/root/PlayersManager")

@onready var lbl_titulo: Label = $Card/VBox/Title
@onready var lbl_estado: Label = $Card/VBox/Status
@onready var vbox_salas: VBoxContainer = $Card/VBox/Columns/LeftRoom/Scroll/Rooms
@onready var vbox_jugadores: VBoxContainer = $Card/VBox/Columns/LeftPlayers/Scroll/Players

@onready var btn_crear_sala_abrir: Button = $Card/VBox/Columns/Right/BtnCrearSalaAbrir
@onready var btn_unirse_codigo_abrir: Button = $Card/VBox/Columns/Right/BtnUnirseCodigoAbrir
@onready var btn_iniciar: Button = $Card/VBox/Columns/Right/StartButton
@onready var btn_salir_sala: Button = $Card/VBox/Columns/Right/LeaveButton
@onready var btn_volver: Button = $Card/VBox/Columns/Right/BackButton

# Modales
@onready var modal_crear: ColorRect = $ModalCrear
@onready var modal_unirse: ColorRect = $ModalUnirse

# Modal Crear
@onready var input_nombre_sala: LineEdit = $ModalCrear/Center/Panel/VBox/InputNombre
@onready var option_max_jugadores: OptionButton = $ModalCrear/Center/Panel/VBox/OptionMaxJugadores
@onready var btn_crear_confirmar: Button = $ModalCrear/Center/Panel/VBox/HBox/CreateButton
@onready var btn_crear_cancelar: Button = $ModalCrear/Center/Panel/VBox/HBox/CancelCreateButton

# Modal Unirse
@onready var input_codigo_sala: LineEdit = $ModalUnirse/Center/Panel/VBox/InputCodigo
@onready var input_ip_host: LineEdit = $ModalUnirse/Center/Panel/VBox/InputIP
@onready var btn_buscar_sala: Button = $ModalUnirse/Center/Panel/VBox/SearchButton
@onready var panel_search_result: PanelContainer = $ModalUnirse/Center/Panel/VBox/SearchResult
@onready var lbl_search_room_name: Label = $ModalUnirse/Center/Panel/VBox/SearchResult/HBox/VBoxInfo/RoomName
@onready var lbl_search_room_details: Label = $ModalUnirse/Center/Panel/VBox/SearchResult/HBox/VBoxInfo/RoomDetails
@onready var btn_unirse_encontrado: Button = $ModalUnirse/Center/Panel/VBox/SearchResult/HBox/JoinFoundButton
@onready var lbl_search_status: Label = $ModalUnirse/Center/Panel/VBox/SearchStatus
@onready var btn_unirse_cancelar: Button = $ModalUnirse/Center/Panel/VBox/CancelJoinButton
@onready var lbl_ip_label: Label = $ModalUnirse/Center/Panel/VBox/IPLabel

@onready var room_list_panel: PanelContainer = $Card/VBox/Columns/LeftRoom
@onready var players_panel: PanelContainer = $Card/VBox/Columns/LeftPlayers

var host_port: int = 10567
var _salas_vps_cache: Array = []
var _salas_lan_cache: Array = []

func _ready() -> void:
	option_max_jugadores.clear()
	option_max_jugadores.add_item("2 JUGADORES", 2)
	option_max_jugadores.add_item("3 JUGADORES", 3)
	option_max_jugadores.add_item("4 JUGADORES", 4)
	option_max_jugadores.add_item("5 JUGADORES (MÁX)", 5)
	option_max_jugadores.selected = 3 # 5 personas por defecto

	lbl_estado.text = "CREA UNA PARTIDA (HOST MÁX 5 PERSONAS) O ÚNETE A UNA SALA"
	_aplicar_estilo_premium()

	btn_crear_sala_abrir.pressed.connect(_on_crear_sala_abrir_pressed)
	btn_unirse_codigo_abrir.pressed.connect(_on_unirse_codigo_abrir_pressed)
	btn_volver.pressed.connect(_on_volver_lobby_pressed)

	btn_crear_confirmar.pressed.connect(_on_crear_sala_pressed)
	btn_crear_cancelar.pressed.connect(_on_crear_sala_cancelar_pressed)

	btn_buscar_sala.pressed.connect(_on_unirse_lan_pressed)
	btn_unirse_cancelar.pressed.connect(_on_unirse_cancelar_pressed)
	btn_unirse_encontrado.pressed.connect(_on_unirse_directo_pressed)

	btn_iniciar.pressed.connect(_on_iniciar_juego_pressed)
	btn_salir_sala.pressed.connect(_on_salir_sala_pressed)

	room_list_panel.visible = true
	players_panel.visible = false
	btn_iniciar.visible = false
	btn_salir_sala.visible = false

	if network:
		if not network.lista_jugadores_actualizada.is_connected(_on_lista_jugadores_actualizada):
			network.lista_jugadores_actualizada.connect(_on_lista_jugadores_actualizada)
		if not network.salas_lan_actualizadas.is_connected(_on_salas_lan_actualizadas):
			network.salas_lan_actualizadas.connect(_on_salas_lan_actualizadas)
		if not network.conectado_a_sala.is_connected(_on_conectado_a_sala):
			network.conectado_a_sala.connect(_on_conectado_a_sala)
		if not network.error_red.is_connected(_on_error_red):
			network.error_red.connect(_on_error_red)
		network.iniciar_escucha_lan()

	if red_manager:
		if not red_manager.salas_actualizadas.is_connected(_on_salas_vps_actualizadas):
			red_manager.salas_actualizadas.connect(_on_salas_vps_actualizadas)

	_renderizar_lista_salas()

func _exit_tree() -> void:
	if network and network.has_method("detener_escucha_lan"):
		network.detener_escucha_lan()

func _aplicar_estilo_premium() -> void:
	lbl_titulo.add_theme_font_override("font", FONT)
	lbl_titulo.add_theme_font_size_override("font_size", 42)
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	lbl_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl_titulo.add_theme_constant_override("shadow_offset_x", 3)
	lbl_titulo.add_theme_constant_override("shadow_offset_y", 3)

	lbl_estado.add_theme_font_override("font", FONT)
	lbl_estado.add_theme_font_size_override("font_size", 20)
	lbl_estado.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))

	var list_panel_style = StyleBoxFlat.new()
	list_panel_style.bg_color = Color(0.02, 0.03, 0.07, 0.6)
	list_panel_style.border_width_left = 2
	list_panel_style.border_width_top = 2
	list_panel_style.border_width_right = 2
	list_panel_style.border_width_bottom = 2
	list_panel_style.border_color = Color(1, 1, 1, 0.08)
	list_panel_style.corner_radius_top_left = 20
	list_panel_style.corner_radius_top_right = 20
	list_panel_style.corner_radius_bottom_right = 20
	list_panel_style.corner_radius_bottom_left = 20
	list_panel_style.content_margin_left = 25
	list_panel_style.content_margin_right = 25
	list_panel_style.content_margin_top = 25
	list_panel_style.content_margin_bottom = 25
	room_list_panel.add_theme_stylebox_override("panel", list_panel_style)
	players_panel.add_theme_stylebox_override("panel", list_panel_style)

	var modal_panel_style = StyleBoxFlat.new()
	modal_panel_style.bg_color = Color(0.04, 0.06, 0.12, 0.96)
	modal_panel_style.border_width_left = 3
	modal_panel_style.border_width_top = 3
	modal_panel_style.border_width_right = 3
	modal_panel_style.border_width_bottom = 3
	modal_panel_style.border_color = Color(0.008, 0.43, 0.8, 0.85)
	modal_panel_style.corner_radius_top_left = 20
	modal_panel_style.corner_radius_top_right = 20
	modal_panel_style.corner_radius_bottom_right = 20
	modal_panel_style.corner_radius_bottom_left = 20
	modal_panel_style.content_margin_left = 30
	modal_panel_style.content_margin_right = 30
	modal_panel_style.content_margin_top = 30
	modal_panel_style.content_margin_bottom = 30

	$ModalCrear/Center/Panel.add_theme_stylebox_override("panel", modal_panel_style)
	$ModalUnirse/Center/Panel.add_theme_stylebox_override("panel", modal_panel_style)
	panel_search_result.add_theme_stylebox_override("panel", list_panel_style)

	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.02, 0.03, 0.06, 0.95)
	input_style.border_width_left = 2
	input_style.border_width_top = 2
	input_style.border_width_right = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(1, 1, 1, 0.15)
	input_style.corner_radius_top_left = 18
	input_style.corner_radius_top_right = 18
	input_style.corner_radius_bottom_right = 18
	input_style.corner_radius_bottom_left = 18
	input_style.content_margin_left = 20
	input_style.content_margin_right = 20

	var input_focus = input_style.duplicate()
	input_focus.border_color = Color(0.008, 0.43, 0.8, 0.95)

	for input in [input_nombre_sala, input_codigo_sala, input_ip_host]:
		input.add_theme_font_override("font", FONT)
		input.add_theme_font_size_override("font_size", 24)
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_stylebox_override("normal", input_style)
		input.add_theme_stylebox_override("focus", input_focus)

	option_max_jugadores.add_theme_font_override("font", FONT)
	option_max_jugadores.add_theme_font_size_override("font_size", 24)
	option_max_jugadores.add_theme_stylebox_override("normal", input_style)
	option_max_jugadores.add_theme_stylebox_override("hover", input_focus)
	option_max_jugadores.add_theme_stylebox_override("focus", input_focus)

	$ModalCrear/Center/Panel/VBox/Title.add_theme_font_override("font", FONT)
	$ModalUnirse/Center/Panel/VBox/Title.add_theme_font_override("font", FONT)
	lbl_search_room_name.add_theme_font_override("font", FONT)
	lbl_search_room_name.add_theme_font_size_override("font_size", 22)
	lbl_search_room_details.add_theme_font_override("font", FONT)
	lbl_search_room_details.add_theme_font_size_override("font_size", 14)
	lbl_search_status.add_theme_font_override("font", FONT)
	lbl_search_status.add_theme_font_size_override("font_size", 18)

	_set_button_style(btn_crear_sala_abrir, Color(0.008, 0.43, 0.8))
	_set_button_style(btn_unirse_codigo_abrir, Color(0.008, 0.7, 0.8))
	_set_button_style(btn_volver, Color(0.25, 0.28, 0.38))

	_set_button_style(btn_crear_confirmar, Color(0.2, 0.65, 0.15))
	_set_button_style(btn_crear_cancelar, Color(0.75, 0.12, 0.15))
	btn_buscar_sala.text = "CONECTAR (LAN / VPS)"
	_set_button_style(btn_buscar_sala, Color(0.2, 0.65, 0.15))
	_set_button_style(btn_unirse_encontrado, Color(0.2, 0.65, 0.15))
	_set_button_style(btn_unirse_cancelar, Color(0.75, 0.12, 0.15))

	_set_button_style(btn_iniciar, Color(0.2, 0.65, 0.15))
	_set_button_style(btn_salir_sala, Color(0.75, 0.12, 0.15))

func _set_button_style(btn: Button, color: Color) -> void:
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 24)

	var norm = StyleBoxFlat.new()
	norm.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.75)
	norm.border_width_left = 3
	norm.border_width_top = 3
	norm.border_width_right = 3
	norm.border_width_bottom = 3
	norm.border_color = Color(color.r, color.g, color.b, 0.6)
	norm.corner_radius_top_left = 20
	norm.corner_radius_top_right = 20
	norm.corner_radius_bottom_right = 20
	norm.corner_radius_bottom_left = 20
	norm.content_margin_top = 16
	norm.content_margin_bottom = 16

	var hov = norm.duplicate()
	hov.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
	hov.border_color = Color(color.r, color.g, color.b, 0.95)

	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus", hov)

# ─────────────────────────────────────────────────────────────────────────────
# FLUJO DE CREACIÓN DE SALA (HOST JUGADOR — MÁXIMO 5 PERSONAS)
# ─────────────────────────────────────────────────────────────────────────────

func _on_crear_sala_abrir_pressed() -> void:
	var nombre_usr = DatosUsuario.nombre_usuario.to_upper() if DatosUsuario else "CONDUCTOR"
	input_nombre_sala.text = "CONVOY DE " + nombre_usr
	modal_crear.visible = true

func _on_crear_sala_cancelar_pressed() -> void:
	modal_crear.visible = false

func _on_crear_sala_pressed() -> void:
	var max_players = option_max_jugadores.get_item_id(option_max_jugadores.selected)
	max_players = clampi(max_players if max_players > 0 else MAX_JUGADORES_PERMITIDOS, 2, MAX_JUGADORES_PERMITIDOS)

	modal_crear.visible = false
	lbl_estado.text = "INICIANDO PARTIDA COMO HOST..."

	if players_manager:
		players_manager.player_name = DatosUsuario.nombre_usuario if DatosUsuario else "Conductor"

	host_port = 10567
	var nombre_sala = input_nombre_sala.text.strip_edges()

	if network:
		var err = network.start_server_on_port(host_port, max_players, nombre_sala, false)
		if err != OK:
			return

	var local_ip = network.get_ip_address() if network else "127.0.0.1"
	lbl_estado.text = "HOST ACTIVO EN %s:%d | CUPO MÁXIMO: %d PERSONAS" % [local_ip, host_port, max_players]
	lbl_estado.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))

	room_list_panel.visible = false
	players_panel.visible = true
	btn_iniciar.visible = true
	btn_iniciar.disabled = false
	btn_iniciar.text = "INICIAR JUEGO (HOST)"
	btn_salir_sala.visible = true
	btn_crear_sala_abrir.visible = false
	btn_unirse_codigo_abrir.visible = false

	lbl_titulo.text = nombre_sala if nombre_sala != "" else "SALA CREADA (HOST)"
	lbl_titulo.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))

	actualizar_lista_jugadores(network.nombres_jugadores if network else {})

# ─────────────────────────────────────────────────────────────────────────────
# FLUJO DE CONEXIÓN A SALA (LAN / HOTSPOT / VPS)
# ─────────────────────────────────────────────────────────────────────────────

func _on_unirse_codigo_abrir_pressed() -> void:
	input_codigo_sala.text = "10567"
	var local_ip = network.get_ip_address() if network else "127.0.0.1"
	# Sugerir la IP de la misma subred si no es loopback
	if input_ip_host.text.strip_edges() == "" and local_ip != "127.0.0.1":
		var partes = local_ip.split(".")
		if partes.size() == 4:
			input_ip_host.placeholder_text = "%s.%s.%s.X" % [partes[0], partes[1], partes[2]]
	panel_search_result.visible = false
	modal_unirse.visible = true

	lbl_ip_label.text = "IP DEL HOST (LAN / Hotspot) o IP DE LA VPS"
	lbl_search_status.text = "Tu IP local: %s | Escribe la IP del Host para conectar" % [local_ip]
	lbl_search_status.add_theme_color_override("font_color", Color(0.5, 0.85, 0.6))

func _on_unirse_cancelar_pressed() -> void:
	modal_unirse.visible = false

func _on_unirse_lan_pressed() -> void:
	var ip = input_ip_host.text.strip_edges()
	var port_text = input_codigo_sala.text.strip_edges()

	if players_manager and DatosUsuario:
		players_manager.player_name = DatosUsuario.nombre_usuario

	modal_unirse.visible = false

	# Si el usuario escribió "VPS" o dejó IP vacía pero puso un número de sala 1..5 de VPS:
	if ip.to_upper() == "VPS" and network:
		lbl_estado.text = "CONECTANDO A SALA VPS " + port_text + "..."
		network.start_client_for_room(port_text if port_text != "" else "1")
		return

	if ip == "":
		var local_ip = network.get_ip_address() if network else "127.0.0.1"
		# Si estamos en un dispositivo móvil y no pusimos IP, advertir al usuario en vez de conectar a loopback
		if OS.get_name() == "Android" or OS.get_name() == "iOS":
			lbl_estado.text = "POR FAVOR INGRESA LA IP DEL HOST (Ej: 192.168.x.x)"
			lbl_estado.add_theme_color_override("font_color", Color(0.95, 0.45, 0.2))
			modal_unirse.visible = true
			return
		ip = local_ip

	var port = 10567
	if port_text.is_valid_int():
		port = int(port_text)

	lbl_estado.text = "CONECTANDO AL HOST EN %s:%d..." % [ip, port]
	lbl_estado.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	if network:
		network.start_client_for_host(ip, port)

func _on_unirse_directo_pressed() -> void:
	_on_iniciar_juego_pressed()

func _on_conectado_a_sala(_info: Dictionary) -> void:
	lbl_titulo.text = "EN SALA DE ESPERA"
	lbl_titulo.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))
	lbl_estado.text = "¡CONECTADO! ESPERANDO A QUE EL HOST INICIE LA PARTIDA..."
	lbl_estado.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45))

	room_list_panel.visible = false
	players_panel.visible = true
	btn_iniciar.visible = false # Solo el Host puede iniciar la partida
	btn_salir_sala.visible = true
	btn_crear_sala_abrir.visible = false
	btn_unirse_codigo_abrir.visible = false

func _on_error_red(mensaje: String) -> void:
	lbl_estado.text = mensaje
	lbl_estado.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	room_list_panel.visible = true
	players_panel.visible = false
	btn_iniciar.visible = false
	btn_salir_sala.visible = false
	btn_crear_sala_abrir.visible = true
	btn_unirse_codigo_abrir.visible = true

# ─────────────────────────────────────────────────────────────────────────────
# LISTA DE JUGADORES Y SALAS DETECTADAS EN VIVO
# ─────────────────────────────────────────────────────────────────────────────

func _on_lista_jugadores_actualizada(nombres: Dictionary) -> void:
	actualizar_lista_jugadores(nombres)

func actualizar_lista_jugadores(nombres: Dictionary) -> void:
	for child in vbox_jugadores.get_children():
		child.queue_free()

	var cupo_max = network.max_players_actual if network else MAX_JUGADORES_PERMITIDOS
	var header = Label.new()
	header.text = "CONDUCTORES EN SALA (%d / %d MÁX)" % [nombres.size(), cupo_max]
	header.add_theme_font_override("font", FONT)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	vbox_jugadores.add_child(header)

	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for p_id in nombres.keys():
		var p_lbl = Label.new()
		var etiqueta_rol = " [HOST]" if int(p_id) == 1 else ""
		var etiqueta_tu = " (TÚ)" if int(p_id) == mi_id else ""
		p_lbl.text = "🚛 %s%s%s" % [String(nombres[p_id]).to_upper(), etiqueta_rol, etiqueta_tu]
		p_lbl.add_theme_font_override("font", FONT)
		p_lbl.add_theme_font_size_override("font_size", 20)
		p_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.45) if int(p_id) == mi_id else Color(0.85, 0.92, 1.0))
		vbox_jugadores.add_child(p_lbl)

func _on_salas_lan_actualizadas(salas: Array) -> void:
	_salas_lan_cache = salas
	_renderizar_lista_salas()

func _on_salas_vps_actualizadas(salas: Array) -> void:
	_salas_vps_cache = salas
	_renderizar_lista_salas()

func _renderizar_lista_salas() -> void:
	for child in vbox_salas.get_children():
		child.queue_free()

	var titulo_lista = Label.new()
	var mi_ip_local = network.get_ip_address() if network else "127.0.0.1"
	titulo_lista.text = "SALAS LAN DISPONIBLES (TU IP: %s)" % [mi_ip_local]
	titulo_lista.add_theme_font_override("font", FONT)
	titulo_lista.add_theme_font_size_override("font_size", 18)
	titulo_lista.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	vbox_salas.add_child(titulo_lista)

	if _salas_lan_cache.is_empty() and _salas_vps_cache.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Buscando partidas en red local (Máx 5 personas)...
También puedes crear una sala como Host o unirte por IP / VPS."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", FONT)
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
		vbox_salas.add_child(empty_lbl)
		return

	for sala in _salas_lan_cache:
		_crear_fila_sala(
			String(sala.get("name", "SALA LAN")),
			String(sala.get("ip", "127.0.0.1")),
			int(sala.get("port", 10567)),
			int(sala.get("players", 1)),
			int(sala.get("max_players", MAX_JUGADORES_PERMITIDOS)),
			"LAN"
		)

	for sala_vps in _salas_vps_cache:
		_crear_fila_sala(
			String(sala_vps.get("name", "SALA VPS")),
			network.vps_ip if network else "2.25.71.102",
			10566 + int(sala_vps.get("id", 1)),
			int(sala_vps.get("players", 0)),
			int(sala_vps.get("max_players", MAX_JUGADORES_PERMITIDOS)),
			"VPS"
		)

func _crear_fila_sala(nombre: String, ip: String, port: int, jugadores: int, max_jug: int, tipo: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var lbl = Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "[%s] %s (%d/%d)" % [tipo, nombre, jugadores, max_jug]
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	hbox.add_child(lbl)

	var btn = Button.new()
	btn.text = "UNIRSE" if jugadores < max_jug else "LLENA"
	btn.disabled = jugadores >= max_jug
	btn.custom_minimum_size = Vector2(140, 48)
	_set_button_style(btn, Color(0.2, 0.65, 0.15))
	btn.pressed.connect(func():
		if network:
			lbl_estado.text = "CONECTANDO A %s (%s:%d)..." % [nombre, ip, port]
			network.start_client_for_host(ip, port)
	)
	hbox.add_child(btn)
	vbox_salas.add_child(hbox)

# ─────────────────────────────────────────────────────────────────────────────
# INICIO SINCRONIZADO DE PARTIDA Y SALIDA
# ─────────────────────────────────────────────────────────────────────────────

func _on_iniciar_juego_pressed() -> void:
	if network and network.is_host:
		lbl_estado.text = "CARGANDO MAPA MULTIJUGADOR PARA TODOS LOS JUGADORES..."
		network.iniciar_partida_multijugador(GAME_SCENE)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)

func _on_salir_sala_pressed() -> void:
	if network:
		network.cerrar_conexion()
		network.iniciar_escucha_lan()

	lbl_titulo.text = "SALA MULTIJUGADOR"
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	room_list_panel.visible = true
	players_panel.visible = false
	btn_iniciar.visible = false
	btn_salir_sala.visible = false
	btn_crear_sala_abrir.visible = true
	btn_unirse_codigo_abrir.visible = true
	lbl_estado.text = "CREA UNA PARTIDA (HOST MÁX 5 PERSONAS) O ÚNETE A UNA SALA"
	_renderizar_lista_salas()

func _on_volver_lobby_pressed() -> void:
	if network:
		network.detener_escucha_lan()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
