extends Control

# ═══════════════════════════════════════════════════════════════════════
# LobbyMultijugador.gd — Interfaz de entrada a las salas multijugador
# Adaptada para conectar directamente al nuevo sistema Network.gd
# ═══════════════════════════════════════════════════════════════════════

const FONT = preload("res://recursos/fonts/Moderniz.otf")
const MAIN_MENU_SCENE = "res://escenas/main menu/Main-Menu.tscn"

@onready var network = get_node("/root/Network")
@onready var players_manager = get_node("/root/PlayersManager")

@onready var lbl_titulo: Label = $Card/VBox/Title
@onready var lbl_estado: Label = $Card/VBox/Status
@onready var vbox_salas: VBoxContainer = $Card/VBox/Columns/LeftRoom/Scroll/Rooms
@onready var vbox_jugadores: VBoxContainer = $Card/VBox/Columns/LeftPlayers/Scroll/Players

# Botones principales derecha
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
@onready var btn_buscar_sala: Button = $ModalUnirse/Center/Panel/VBox/SearchButton
@onready var panel_search_result: PanelContainer = $ModalUnirse/Center/Panel/VBox/SearchResult
@onready var lbl_search_room_name: Label = $ModalUnirse/Center/Panel/VBox/SearchResult/HBox/VBoxInfo/RoomName
@onready var lbl_search_room_details: Label = $ModalUnirse/Center/Panel/VBox/SearchResult/HBox/VBoxInfo/RoomDetails
@onready var btn_unirse_encontrado: Button = $ModalUnirse/Center/Panel/VBox/SearchResult/HBox/JoinFoundButton
@onready var lbl_search_status: Label = $ModalUnirse/Center/Panel/VBox/SearchStatus
@onready var btn_unirse_cancelar: Button = $ModalUnirse/Center/Panel/VBox/CancelJoinButton

@onready var room_list_panel: PanelContainer = $Card/VBox/Columns/LeftRoom
@onready var players_panel: PanelContainer = $Card/VBox/Columns/LeftPlayers

func _ready() -> void:
	# Configurar opciones de limites de jugadores
	option_max_jugadores.add_item("2 JUGADORES", 2)
	option_max_jugadores.add_item("4 JUGADORES", 4)
	option_max_jugadores.add_item("6 JUGADORES", 6)
	option_max_jugadores.add_item("8 JUGADORES", 8)
	option_max_jugadores.add_item("10 JUGADORES", 10)
	option_max_jugadores.selected = 1 # 4 jugadores por defecto
	
	lbl_estado.text = "ELIGE UNA OPCIÓN MULTIJUGADOR"
	_aplicar_estilo_premium()
	
	# Navegacion lobby
	btn_crear_sala_abrir.pressed.connect(_on_crear_sala_abrir_pressed)
	btn_unirse_codigo_abrir.pressed.connect(_on_unirse_codigo_abrir_pressed)
	btn_volver.pressed.connect(_on_volver_lobby_pressed)
	
	# Acciones Modal Crear
	btn_crear_confirmar.pressed.connect(_on_crear_sala_pressed)
	btn_crear_cancelar.pressed.connect(_on_crear_sala_cancelar_pressed)
	
	# Acciones Modal Unirse (Conexión directa)
	btn_buscar_sala.pressed.connect(func():
		var codigo = input_codigo_sala.text.strip_edges()
		if codigo == "":
			lbl_search_status.text = "INGRESA UN CODIGO VALIDO"
			lbl_search_status.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			return
		_on_unirse_encontrado_pressed(codigo)
	)
	btn_unirse_cancelar.pressed.connect(_on_unirse_cancelar_pressed)
	
	# Acciones de sala activa
	btn_iniciar.pressed.connect(_on_iniciar_juego_pressed)
	btn_salir_sala.pressed.connect(_on_salir_sala_pressed)
	
	# Ocultar paneles de lista ya que no usamos servidor web/señalización
	room_list_panel.visible = false
	players_panel.visible = false
	btn_iniciar.visible = false
	btn_salir_sala.visible = false

func _aplicar_estilo_premium() -> void:
	lbl_titulo.add_theme_font_override("font", FONT)
	lbl_titulo.add_theme_font_size_override("font_size", 42)
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	lbl_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl_titulo.add_theme_constant_override("shadow_offset_x", 3)
	lbl_titulo.add_theme_constant_override("shadow_offset_y", 3)
	
	lbl_estado.add_theme_font_override("font", FONT)
	lbl_estado.add_theme_font_size_override("font_size", 22)
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
	
	for input in [input_nombre_sala, input_codigo_sala]:
		input.add_theme_font_override("font", FONT)
		input.add_theme_font_size_override("font_size", 26)
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_stylebox_override("normal", input_style)
		input.add_theme_stylebox_override("focus", input_focus)
		
	option_max_jugadores.add_theme_font_override("font", FONT)
	option_max_jugadores.add_theme_font_size_override("font_size", 24)
	option_max_jugadores.add_theme_stylebox_override("normal", input_style)
	option_max_jugadores.add_theme_stylebox_override("hover", input_focus)
	option_max_jugadores.add_theme_stylebox_override("focus", input_focus)
	
	var popup = option_max_jugadores.get_popup()
	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 26)
	popup.add_theme_constant_override("v_separation", 25)
	
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.04, 0.06, 0.12, 0.98)
	popup_style.border_width_left = 2
	popup_style.border_width_top = 2
	popup_style.border_width_right = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = Color(0.008, 0.43, 0.8, 0.8)
	popup_style.corner_radius_top_left = 12
	popup_style.corner_radius_top_right = 12
	popup_style.corner_radius_bottom_right = 12
	popup_style.corner_radius_bottom_left = 12
	popup_style.content_margin_left = 20
	popup_style.content_margin_right = 20
	popup_style.content_margin_top = 20
	popup_style.content_margin_bottom = 20
	
	popup.add_theme_stylebox_override("panel", popup_style)
	
	var popup_hover = StyleBoxFlat.new()
	popup_hover.bg_color = Color(0.008, 0.43, 0.8, 0.3)
	popup_hover.corner_radius_top_left = 6
	popup_hover.corner_radius_top_right = 6
	popup_hover.corner_radius_bottom_right = 6
	popup_hover.corner_radius_bottom_left = 6
	
	popup.add_theme_stylebox_override("hover", popup_hover)
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.0))
	popup.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	
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
	btn_buscar_sala.text = "UNIRSE A LA SALA"
	_set_button_style(btn_buscar_sala, Color(0.2, 0.65, 0.15))
	_set_button_style(btn_unirse_encontrado, Color(0.2, 0.65, 0.15))
	_set_button_style(btn_unirse_cancelar, Color(0.75, 0.12, 0.15))
	
	_set_button_style(btn_iniciar, Color(0.2, 0.65, 0.15))
	_set_button_style(btn_salir_sala, Color(0.75, 0.12, 0.15))

func _set_button_style(btn: Button, color: Color) -> void:
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 28)
	
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
	norm.shadow_color = Color(0, 0, 0, 0.45)
	norm.shadow_size = 10
	norm.shadow_offset = Vector2(0, 8)
	norm.content_margin_top = 18
	norm.content_margin_bottom = 18
	
	var hov = StyleBoxFlat.new()
	hov.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
	hov.border_width_left = 3
	hov.border_width_top = 3
	hov.border_width_right = 3
	hov.border_width_bottom = 3
	hov.border_color = Color(color.r, color.g, color.b, 0.95)
	hov.corner_radius_top_left = 20
	hov.corner_radius_top_right = 20
	hov.corner_radius_bottom_right = 20
	hov.corner_radius_bottom_left = 20
	hov.shadow_color = Color(color.r, color.g, color.b, 0.25)
	hov.shadow_size = 14
	hov.shadow_offset = Vector2(0, 10)
	hov.content_margin_top = 18
	hov.content_margin_bottom = 18
	
	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus", hov)

func _on_crear_sala_abrir_pressed() -> void:
	input_nombre_sala.text = "SALA DE " + DatosUsuario.nombre_usuario.to_upper()
	modal_crear.visible = true

func _on_crear_sala_cancelar_pressed() -> void:
	modal_crear.visible = false

func _on_unirse_codigo_abrir_pressed() -> void:
	input_codigo_sala.text = ""
	lbl_search_status.text = ""
	panel_search_result.visible = false
	modal_unirse.visible = true

func _on_unirse_cancelar_pressed() -> void:
	modal_unirse.visible = false

func _on_crear_sala_pressed() -> void:
	randomize()
	var codigo = str(randi_range(10000, 99999))
	modal_crear.visible = false
	lbl_estado.text = "CREANDO SERVIDOR..."
	
	if players_manager:
		players_manager.player_name = DatosUsuario.nombre_usuario
		
	if network:
		network.start_server_for_room(codigo)
		
	_on_iniciar_juego_pressed()

func _on_unirse_encontrado_pressed(codigo: String) -> void:
	modal_unirse.visible = false
	lbl_estado.text = "UNIENDO A SALA..."
	
	if players_manager:
		players_manager.player_name = DatosUsuario.nombre_usuario
		
	if network:
		network.start_client_for_room(codigo)
		
	_on_iniciar_juego_pressed()

func _on_iniciar_juego_pressed() -> void:
	get_tree().change_scene_to_file("res://demo/Sky3DDemo.tscn")

func _on_salir_sala_pressed() -> void:
	_restaurar_lobby_list()

func _on_volver_lobby_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
