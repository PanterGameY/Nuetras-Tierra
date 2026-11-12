extends Control

# ═══════════════════════════════════════════════════════════════════════
# LobbyMultijugadorModerno.gd — Sala de Espera Multijugador LAN/Online
# ═══════════════════════════════════════════════════════════════════════

const FONT = preload("res://recursos/fonts/Moderniz.otf")
const MAIN_MENU_SCENE = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const MAIN_MENU_FALLBACK = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const GAME_SCENE = "res://mundo/principal/PrincipalMultijugador.tscn"
const MAX_JUGADORES: int = 5

@onready var network = get_node_or_null("/root/Network")
@onready var players_manager = get_node_or_null("/root/PlayersManager")

@onready var lbl_titulo: Label = $Margin/MainCard/VBox/Header/VBoxTitle/Titulo
@onready var lbl_subtitulo: Label = $Margin/MainCard/VBox/Header/VBoxTitle/Subtitulo
@onready var badge_ip: Label = $Margin/MainCard/VBox/Header/BadgeIP
@onready var lbl_status: Label = $Margin/MainCard/VBox/StatusBanner/LabelStatus

@onready var panel_salas: PanelContainer = $Margin/MainCard/VBox/Body/PanelSalas
@onready var lista_salas: VBoxContainer = $Margin/MainCard/VBox/Body/PanelSalas/Scroll/ListaSalas

@onready var panel_jugadores: PanelContainer = $Margin/MainCard/VBox/Body/PanelJugadores
@onready var lista_jugadores: VBoxContainer = $Margin/MainCard/VBox/Body/PanelJugadores/Scroll/ListaJugadores

@onready var btn_volver: Button = $Margin/MainCard/VBox/Header/BtnVolver
@onready var btn_crear_sala: Button = $Margin/MainCard/VBox/Body/Sidebar/BtnCrearSala
@onready var btn_unirse_ip: Button = $Margin/MainCard/VBox/Body/Sidebar/BtnUnirseIP
@onready var btn_iniciar: Button = $Margin/MainCard/VBox/Body/Sidebar/BtnIniciarJuego
@onready var btn_salir: Button = $Margin/MainCard/VBox/Body/Sidebar/BtnSalirSala

# Modales
@onready var modal_crear: ColorRect = $ModalCrear
@onready var input_nombre_sala: LineEdit = $ModalCrear/Center/Panel/VBox/InputNombreSala
@onready var option_cupos: OptionButton = $ModalCrear/Center/Panel/VBox/OptionCupos
@onready var btn_confirmar_crear: Button = $ModalCrear/Center/Panel/VBox/HBoxBtns/BtnConfirmarCrear
@onready var btn_cancelar_crear: Button = $ModalCrear/Center/Panel/VBox/HBoxBtns/BtnCancelarCrear

@onready var modal_unirse: ColorRect = $ModalUnirse
@onready var input_ip: LineEdit = $ModalUnirse/Center/Panel/VBox/InputIP
@onready var input_puerto: LineEdit = $ModalUnirse/Center/Panel/VBox/InputPuerto
@onready var btn_confirmar_unirse: Button = $ModalUnirse/Center/Panel/VBox/HBoxBtns/BtnConfirmarUnirse
@onready var btn_cancelar_unirse: Button = $ModalUnirse/Center/Panel/VBox/HBoxBtns/BtnCancelarUnirse

var _salas_cache: Array = []

func _ready() -> void:
	option_cupos.clear()
	option_cupos.add_item("2 CONDUCTORES", 2)
	option_cupos.add_item("3 CONDUCTORES", 3)
	option_cupos.add_item("4 CONDUCTORES", 4)
	option_cupos.add_item("5 CONDUCTORES (MÁX)", 5)
	option_cupos.selected = 3

	var mi_ip = network.get_ip_address() if network else "127.0.0.1"
	badge_ip.text = "TU IP: " + mi_ip
	lbl_status.text = "BUSCANDO SALAS EN RED LOCAL (LAN / HOTSPOT)..."

	_estilizar_controles()

	btn_volver.pressed.connect(_on_volver_pressed)
	btn_crear_sala.pressed.connect(_on_crear_sala_abrir)
	btn_unirse_ip.pressed.connect(_on_unirse_ip_abrir)
	btn_iniciar.pressed.connect(_on_iniciar_partida_pressed)
	btn_salir.pressed.connect(_on_salir_sala_pressed)

	btn_confirmar_crear.pressed.connect(_on_crear_sala_confirmar)
	btn_cancelar_crear.pressed.connect(func(): modal_crear.visible = false)

	btn_confirmar_unirse.pressed.connect(_on_unirse_ip_confirmar)
	btn_cancelar_unirse.pressed.connect(func(): modal_unirse.visible = false)

	panel_salas.visible = true
	panel_jugadores.visible = false
	btn_iniciar.visible = false
	btn_salir.visible = false

	if network:
		if not network.salas_lan_actualizadas.is_connected(_on_salas_actualizadas):
			network.salas_lan_actualizadas.connect(_on_salas_actualizadas)
		if not network.lista_jugadores_actualizada.is_connected(_on_jugadores_actualizados):
			network.lista_jugadores_actualizada.connect(_on_jugadores_actualizados)
		if not network.conectado_a_sala.is_connected(_on_conectado_exito):
			network.conectado_a_sala.connect(_on_conectado_exito)
		if not network.error_red.is_connected(_on_error_red):
			network.error_red.connect(_on_error_red)
		network.iniciar_escucha_lan()

	_renderizar_salas()

func _exit_tree() -> void:
	if network and network.has_method("detener_escucha_lan"):
		network.detener_escucha_lan()

func _estilizar_controles() -> void:
	_aplicar_estilo_boton(btn_crear_sala, Color(0.1, 0.55, 0.95), 24)
	_aplicar_estilo_boton(btn_unirse_ip, Color(0.15, 0.75, 0.35), 24)
	_aplicar_estilo_boton(btn_iniciar, Color(0.15, 0.8, 0.25), 26)
	_aplicar_estilo_boton(btn_salir, Color(0.85, 0.2, 0.25), 24)
	_aplicar_estilo_boton(btn_volver, Color(0.35, 0.4, 0.5), 20)

	_aplicar_estilo_boton(btn_confirmar_crear, Color(0.15, 0.75, 0.35), 24)
	_aplicar_estilo_boton(btn_cancelar_crear, Color(0.85, 0.2, 0.25), 24)
	_aplicar_estilo_boton(btn_confirmar_unirse, Color(0.15, 0.75, 0.35), 24)
	_aplicar_estilo_boton(btn_cancelar_unirse, Color(0.85, 0.2, 0.25), 24)

	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.02, 0.04, 0.08, 0.95)
	input_style.border_width_left = 2
	input_style.border_width_top = 2
	input_style.border_width_right = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(0.1, 0.5, 0.9, 0.8)
	input_style.corner_radius_top_left = 16
	input_style.corner_radius_top_right = 16
	input_style.corner_radius_bottom_right = 16
	input_style.corner_radius_bottom_left = 16
	input_style.content_margin_left = 20
	input_style.content_margin_right = 20

	for inp in [input_nombre_sala, option_cupos, input_ip, input_puerto]:
		inp.add_theme_font_override("font", FONT)
		inp.add_theme_font_size_override("font_size", 22)
		inp.add_theme_stylebox_override("normal", input_style)

func _aplicar_estilo_boton(btn: Button, color: Color, font_size: int) -> void:
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", font_size)

	var norm = StyleBoxFlat.new()
	norm.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.9)
	norm.border_width_left = 3
	norm.border_width_top = 3
	norm.border_width_right = 3
	norm.border_width_bottom = 3
	norm.border_color = color
	norm.corner_radius_top_left = 18
	norm.corner_radius_top_right = 18
	norm.corner_radius_bottom_right = 18
	norm.corner_radius_bottom_left = 18
	norm.shadow_color = Color(0, 0, 0, 0.5)
	norm.shadow_size = 6

	var hov = norm.duplicate()
	hov.bg_color = Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, 0.98)
	hov.border_color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 1.0)

	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus", hov)

func _on_crear_sala_abrir() -> void:
	var usr = DatosUsuario.nombre_usuario.to_upper() if DatosUsuario else "CONDUCTOR"
	input_nombre_sala.text = "CONVOY DE " + usr
	modal_crear.visible = true

func _on_crear_sala_confirmar() -> void:
	var max_p = option_cupos.get_item_id(option_cupos.selected)
	max_p = clampi(max_p if max_p > 0 else MAX_JUGADORES, 2, MAX_JUGADORES)
	var nombre = input_nombre_sala.text.strip_edges()
	modal_crear.visible = false

	lbl_status.text = "INICIANDO SALA COMO HOST..."
	if players_manager and DatosUsuario:
		players_manager.player_name = DatosUsuario.nombre_usuario

	if network:
		var err = network.start_server_on_port(10567, max_p, nombre, false)
		if err != OK:
			return

	var mi_ip = network.get_ip_address() if network else "127.0.0.1"
	lbl_titulo.text = nombre.to_upper() if nombre != "" else "SALA CREADA"
	lbl_status.text = "HOST ACTIVO EN %s:10567 • CUPO: %d" % [mi_ip, max_p]
	lbl_status.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))

	panel_salas.visible = false
	panel_jugadores.visible = true
	btn_iniciar.visible = true
	btn_iniciar.text = "INICIAR PARTIDA (HOST)"
	btn_salir.visible = true
	btn_crear_sala.visible = false
	btn_unirse_ip.visible = false

	_actualizar_ui_jugadores(network.nombres_jugadores if network else {})

func _on_unirse_ip_abrir() -> void:
	var local_ip = network.get_ip_address() if network else "127.0.0.1"
	if local_ip != "127.0.0.1":
		var partes = local_ip.split(".")
		if partes.size() == 4:
			input_ip.placeholder_text = "%s.%s.%s.X" % [partes[0], partes[1], partes[2]]
	modal_unirse.visible = true

func _on_unirse_ip_confirmar() -> void:
	var ip = input_ip.text.strip_edges()
	var port = int(input_puerto.text.strip_edges()) if input_puerto.text.strip_edges().is_valid_int() else 10567

	if ip == "":
		if OS.get_name() == "Android" or OS.get_name() == "iOS":
			lbl_status.text = "INGRESA LA IP DEL HOST (Ej: 192.168.x.x)"
			lbl_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.2))
			return
		ip = network.get_ip_address() if network else "127.0.0.1"

	modal_unirse.visible = false
	lbl_status.text = "CONECTANDO AL HOST EN %s:%d..." % [ip, port]
	lbl_status.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	if network:
		network.start_client_for_host(ip, port)

func _on_conectado_exito(_info: Dictionary) -> void:
	lbl_titulo.text = "EN SALA DE ESPERA"
	lbl_status.text = "¡CONECTADO! ESPERANDO A QUE EL HOST INICIE LA RUTA..."
	lbl_status.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))

	panel_salas.visible = false
	panel_jugadores.visible = true
	btn_iniciar.visible = false
	btn_salir.visible = true
	btn_crear_sala.visible = false
	btn_unirse_ip.visible = false

func _on_error_red(msg: String) -> void:
	lbl_status.text = msg
	lbl_status.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	panel_salas.visible = true
	panel_jugadores.visible = false
	btn_iniciar.visible = false
	btn_salir.visible = false
	btn_crear_sala.visible = true
	btn_unirse_ip.visible = true

func _on_salas_actualizadas(salas: Array) -> void:
	_salas_cache = salas
	_renderizar_salas()

func _renderizar_salas() -> void:
	for c in lista_salas.get_children():
		c.queue_free()

	var mi_ip = network.get_ip_address() if network else "127.0.0.1"
	var header = Label.new()
	header.text = "PARTIDAS ENCONTRADAS EN LA RED LOCAL (TU IP: %s)" % mi_ip
	header.add_theme_font_override("font", FONT)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(1, 0.82, 0.1))
	lista_salas.add_child(header)

	if _salas_cache.is_empty():
		var empty = Label.new()
		empty.text = "No hay salas abiertas en tu red Wi-Fi / Hotspot actualmente.\nPuedes presionar 'CREAR SALA' para ser el Host o 'CONECTAR POR IP'."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		lista_salas.add_child(empty)
		return

	for s in _salas_cache:
		_crear_tarjeta_sala(s)

func _crear_tarjeta_sala(s: Dictionary) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.16, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.5, 0.9, 0.7)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = "🚛 " + String(s.get("name", "SALA LAN")).to_upper()
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))

	var info_lbl = Label.new()
	var host_ip = String(s.get("ip", "127.0.0.1"))
	var port = int(s.get("port", 10567))
	var players = int(s.get("players", 1))
	var max_p = int(s.get("max_players", 5))
	info_lbl.text = "HOST: %s:%d • CONDUCTORES: %d/%d" % [host_ip, port, players, max_p]
	info_lbl.add_theme_font_size_override("font_size", 16)
	info_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 0.6))

	vbox.add_child(name_lbl)
	vbox.add_child(info_lbl)
	hbox.add_child(vbox)

	var btn = Button.new()
	btn.text = "UNIRSE" if players < max_p else "LLENA"
	btn.disabled = players >= max_p
	btn.custom_minimum_size = Vector2(160, 60)
	_aplicar_estilo_boton(btn, Color(0.15, 0.75, 0.35), 22)
	btn.pressed.connect(func():
		if network:
			lbl_status.text = "CONECTANDO A %s:%d..." % [host_ip, port]
			network.start_client_for_host(host_ip, port)
	)
	hbox.add_child(btn)
	panel.add_child(hbox)
	lista_salas.add_child(panel)

func _on_jugadores_actualizados(nombres: Dictionary) -> void:
	_actualizar_ui_jugadores(nombres)

func _actualizar_ui_jugadores(nombres: Dictionary) -> void:
	for c in lista_jugadores.get_children():
		c.queue_free()

	var cupo = network.max_players_actual if network else MAX_JUGADORES
	var header = Label.new()
	header.text = "CONDUCTORES EN CONVOY (%d / %d)" % [nombres.size(), cupo]
	header.add_theme_font_override("font", FONT)
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1, 0.82, 0.1))
	lista_jugadores.add_child(header)

	var mi_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for pid in nombres.keys():
		var row = HBoxContainer.new()
		var lbl = Label.new()
		var rol = " [HOST]" if int(pid) == 1 else ""
		var tu = " (TÚ)" if int(pid) == mi_id else ""
		lbl.text = "🚛 %s%s%s" % [String(nombres[pid]).to_upper(), rol, tu]
		lbl.add_theme_font_override("font", FONT)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55) if int(pid) == mi_id else Color(0.85, 0.92, 1.0))
		row.add_child(lbl)
		lista_jugadores.add_child(row)

func _on_iniciar_partida_pressed() -> void:
	if network and network.is_host:
		lbl_status.text = "CARGANDO MAPA MULTIJUGADOR..."
		network.iniciar_partida_multijugador(GAME_SCENE)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)

func _on_salir_sala_pressed() -> void:
	if network:
		network.cerrar_conexion()
		network.iniciar_escucha_lan()

	lbl_titulo.text = "CONVOY MULTIJUGADOR"
	lbl_status.text = "BUSCANDO SALAS EN RED LOCAL (LAN / HOTSPOT)..."
	panel_salas.visible = true
	panel_jugadores.visible = false
	btn_iniciar.visible = false
	btn_salir.visible = false
	btn_crear_sala.visible = true
	btn_unirse_ip.visible = true
	_renderizar_salas()

func _on_volver_pressed() -> void:
	if network:
		network.detener_escucha_lan()
		network.cerrar_conexion()
	var dest = MAIN_MENU_SCENE if ResourceLoader.exists(MAIN_MENU_SCENE) else MAIN_MENU_FALLBACK
	get_tree().change_scene_to_file(dest)
