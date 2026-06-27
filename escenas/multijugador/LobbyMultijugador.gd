extends Control

const FONT = preload("res://recursos/fonts/Moderniz.otf")
const MAIN_MENU_SCENE = "res://escenas/main menu/Main-Menu.tscn"

@onready var red_manager = get_node("/root/RedManager")

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

var refresh_timer: Timer
var salas_actuales: Array = []
var jugadores_previos: Array = []

func _ready() -> void:
	# Configurar opciones de limites de jugadores
	option_max_jugadores.add_item("2 JUGADORES", 2)
	option_max_jugadores.add_item("4 JUGADORES", 4)
	option_max_jugadores.add_item("6 JUGADORES", 6)
	option_max_jugadores.add_item("8 JUGADORES", 8)
	option_max_jugadores.add_item("10 JUGADORES", 10)
	option_max_jugadores.selected = 1 # 4 jugadores por defecto
	
	# Aplicar el tema visual premium consistente con el juego
	_aplicar_estilo_premium()
	
	# Navegacion lobby
	btn_crear_sala_abrir.pressed.connect(_on_crear_sala_abrir_pressed)
	btn_unirse_codigo_abrir.pressed.connect(_on_unirse_codigo_abrir_pressed)
	btn_volver.pressed.connect(_on_volver_lobby_pressed)
	
	# Acciones Modal Crear
	btn_crear_confirmar.pressed.connect(_on_crear_sala_pressed)
	btn_crear_cancelar.pressed.connect(_on_crear_sala_cancelar_pressed)
	
	# Acciones Modal Unirse
	btn_buscar_sala.pressed.connect(_on_buscar_sala_pressed)
	btn_unirse_cancelar.pressed.connect(_on_unirse_cancelar_pressed)
	
	# Acciones de sala activa
	btn_iniciar.pressed.connect(_on_iniciar_juego_pressed)
	btn_salir_sala.pressed.connect(_on_salir_sala_pressed)
	
	# Conectar senales de red_manager
	red_manager.salas_actualizadas.connect(_al_recibir_salas)
	red_manager.jugadores_actualizados.connect(_al_jugadores_actualizados)
	red_manager.sala_creada.connect(_al_crear_sala)
	red_manager.unido_a_sala.connect(_al_unirse_sala)
	red_manager.error_conexion.connect(_al_error_conexion)
	red_manager.host_desconectado.connect(_al_host_desconectado)
	
	# Temporizador de auto-refresco de salas
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 4.0
	refresh_timer.autostart = true
	add_child(refresh_timer)
	refresh_timer.timeout.connect(func():
		if red_manager.current_room == "":
			red_manager.consultar_salas()
	)
	
	# Conectar a la senalizacion WebSocket
	red_manager.conectar_a_senalizacion()

func _aplicar_estilo_premium() -> void:
	# 1. Titulo con degradado / sombra
	lbl_titulo.add_theme_font_override("font", FONT)
	lbl_titulo.add_theme_font_size_override("font_size", 42)
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0)) # Dorado
	lbl_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl_titulo.add_theme_constant_override("shadow_offset_x", 3)
	lbl_titulo.add_theme_constant_override("shadow_offset_y", 3)
	
	# 2. Etiquetas
	lbl_estado.add_theme_font_override("font", FONT)
	lbl_estado.add_theme_font_size_override("font_size", 22)
	lbl_estado.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	
	# 3. Paneles de listas y modales
	var list_panel_style = StyleBoxFlat.new()
	list_panel_style.bg_color = Color(0.02, 0.03, 0.07, 0.6) # Cristal muy transparente
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
	modal_panel_style.bg_color = Color(0.04, 0.06, 0.12, 0.96) # Opaco
	modal_panel_style.border_width_left = 3
	modal_panel_style.border_width_top = 3
	modal_panel_style.border_width_right = 3
	modal_panel_style.border_width_bottom = 3
	modal_panel_style.border_color = Color(0.008, 0.43, 0.8, 0.85) # Borde azul neon
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
	
	# 4. Inputs LineEdit
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
	input_focus.border_color = Color(0.008, 0.43, 0.8, 0.95) # Glow azul neon
	
	for input in [input_nombre_sala, input_codigo_sala]:
		input.add_theme_font_override("font", FONT)
		input.add_theme_font_size_override("font_size", 26)
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.add_theme_stylebox_override("normal", input_style)
		input.add_theme_stylebox_override("focus", input_focus)
		
	# OptionButton de Jugadores y su Dropdown PopupMenu
	option_max_jugadores.add_theme_font_override("font", FONT)
	option_max_jugadores.add_theme_font_size_override("font_size", 24)
	option_max_jugadores.add_theme_stylebox_override("normal", input_style)
	option_max_jugadores.add_theme_stylebox_override("hover", input_focus)
	option_max_jugadores.add_theme_stylebox_override("focus", input_focus)
	
	var popup = option_max_jugadores.get_popup()
	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 26) # Letras mas grandes para lectura facil
	popup.add_theme_constant_override("v_separation", 25) # Espacio vertical amplio para pulsar en moviles
	
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
	
	# Labels modales
	$ModalCrear/Center/Panel/VBox/Title.add_theme_font_override("font", FONT)
	$ModalUnirse/Center/Panel/VBox/Title.add_theme_font_override("font", FONT)
	lbl_search_room_name.add_theme_font_override("font", FONT)
	lbl_search_room_name.add_theme_font_size_override("font_size", 22)
	lbl_search_room_details.add_theme_font_override("font", FONT)
	lbl_search_room_details.add_theme_font_size_override("font_size", 14)
	lbl_search_status.add_theme_font_override("font", FONT)
	lbl_search_status.add_theme_font_size_override("font_size", 18)
	
	# 5. Estilizar Botones principales derecha
	_set_button_style(btn_crear_sala_abrir, Color(0.008, 0.43, 0.8))       # Azul
	_set_button_style(btn_unirse_codigo_abrir, Color(0.008, 0.7, 0.8))    # Cyan
	_set_button_style(btn_volver, Color(0.25, 0.28, 0.38))                 # Gris
	
	# Estilizar Botones modales
	_set_button_style(btn_crear_confirmar, Color(0.2, 0.65, 0.15))         # Verde
	_set_button_style(btn_crear_cancelar, Color(0.75, 0.12, 0.15))          # Rojo
	_set_button_style(btn_buscar_sala, Color(0.008, 0.7, 0.8))             # Cyan
	_set_button_style(btn_unirse_encontrado, Color(0.2, 0.65, 0.15))       # Verde
	_set_button_style(btn_unirse_cancelar, Color(0.75, 0.12, 0.15))        # Rojo
	
	# Estilizar Botones de sala activa
	_set_button_style(btn_iniciar, Color(0.2, 0.65, 0.15))                 # Verde
	_set_button_style(btn_salir_sala, Color(0.75, 0.12, 0.15))             # Rojo

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

# Navegacion entre modales y vistas
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
	
	var nombre_sala = input_nombre_sala.text.strip_edges()
	if nombre_sala == "":
		nombre_sala = "SALA DE " + DatosUsuario.nombre_usuario.to_upper()
		
	var index = option_max_jugadores.selected
	var limite_jugadores = option_max_jugadores.get_item_metadata(index) if option_max_jugadores.get_item_metadata(index) != null else 4
	if limite_jugadores == 0:
		limite_jugadores = option_max_jugadores.get_item_id(index)
		
	modal_crear.visible = false
	lbl_estado.text = "CREANDO SALA: " + codigo + "..."
	red_manager.crear_sala(codigo, nombre_sala, limite_jugadores)

func _on_buscar_sala_pressed() -> void:
	var codigo = input_codigo_sala.text.strip_edges()
	if codigo == "":
		lbl_search_status.text = "INGRESA UN CODIGO VALIDO"
		lbl_search_status.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		panel_search_result.visible = false
		return
		
	lbl_search_status.text = "BUSCANDO SALA..."
	lbl_search_status.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	panel_search_result.visible = false
	
	# Buscar sala en cache
	var sala_encontrada = null
	for sala in salas_actuales:
		if typeof(sala) == TYPE_DICTIONARY:
			if str(sala.get("id", "")) == codigo:
				sala_encontrada = sala
				break
		else:
			if str(sala) == codigo:
				sala_encontrada = {
					"id": str(sala),
					"name": "SALA " + str(sala),
					"players": 1,
					"max_players": 4
				}
				break
				
	if sala_encontrada:
		lbl_search_status.text = "SALA ENCONTRADA"
		lbl_search_status.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		
		lbl_search_room_name.text = str(sala_encontrada.get("name", "")).to_upper()
		lbl_search_room_details.text = "CODIGO: " + str(sala_encontrada.get("id", "")) + "  |  JUGADORES: " + str(sala_encontrada.get("players", 1)) + "/" + str(sala_encontrada.get("max_players", 4))
		
		# Conectar presion de unirse a la sala encontrada
		if btn_unirse_encontrado.pressed.is_connected(_on_unirse_encontrado_pressed):
			btn_unirse_encontrado.pressed.disconnect(_on_unirse_encontrado_pressed)
		btn_unirse_encontrado.pressed.connect(_on_unirse_encontrado_pressed.bind(str(sala_encontrada.get("id", ""))))
		
		panel_search_result.visible = true
	else:
		lbl_search_status.text = "NO SE ENCONTRO LA SALA"
		lbl_search_status.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		panel_search_result.visible = false

func _on_unirse_encontrado_pressed(codigo: String) -> void:
	modal_unirse.visible = false
	lbl_estado.text = "UNIENDO A SALA: " + codigo + "..."
	red_manager.unirse_a_sala(codigo)

func _on_iniciar_juego_pressed() -> void:
	red_manager.cargar_juego_local()

func _on_salir_sala_pressed() -> void:
	red_manager.salir_de_sala()
	_restaurar_lobby_list()

func _on_volver_lobby_pressed() -> void:
	if red_manager.salas_actualizadas.is_connected(_al_recibir_salas):
		red_manager.salas_actualizadas.disconnect(_al_recibir_salas)
	if red_manager.jugadores_actualizados.is_connected(_al_jugadores_actualizados):
		red_manager.jugadores_actualizados.disconnect(_al_jugadores_actualizados)
	if red_manager.sala_creada.is_connected(_al_crear_sala):
		red_manager.sala_creada.disconnect(_al_crear_sala)
	if red_manager.unido_a_sala.is_connected(_al_unirse_sala):
		red_manager.unido_a_sala.disconnect(_al_unirse_sala)
	if red_manager.error_conexion.is_connected(_al_error_conexion):
		red_manager.error_conexion.disconnect(_al_error_conexion)
	if red_manager.host_desconectado.is_connected(_al_host_desconectado):
		red_manager.host_desconectado.disconnect(_al_host_desconectado)
		
	red_manager.cerrar_sala()
	
	if refresh_timer:
		refresh_timer.queue_free()
		refresh_timer = null
		
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _al_recibir_salas(salas: Array) -> void:
	salas_actuales = salas
	lbl_estado.text = "CONECTADO. SALAS DISPONIBLES EN INTERNET:"
	
	# Solo actualizar la lista de salas cuando NO estamos en una sala
	if red_manager.current_room != "":
		return
		
	for child in vbox_salas.get_children():
		child.queue_free()
		
	if salas.is_empty():
		var lbl_vacio = Label.new()
		lbl_vacio.text = "NO HAY SALAS ACTIVAS. CREA UNA NUEVA!"
		lbl_vacio.add_theme_font_override("font", FONT)
		lbl_vacio.add_theme_font_size_override("font_size", 20)
		lbl_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox_salas.add_child(lbl_vacio)
		return
		
	for sala_info in salas:
		var sala_id = ""
		var sala_name = ""
		var count_players = 1
		var max_limit = 4
		
		if typeof(sala_info) == TYPE_DICTIONARY:
			sala_id = str(sala_info.get("id", ""))
			sala_name = str(sala_info.get("name", "SALA " + sala_id)).to_upper()
			count_players = int(sala_info.get("players", 1))
			max_limit = int(sala_info.get("max_players", 4))
		else:
			sala_id = str(sala_info)
			sala_name = "SALA: " + sala_id
		
		var card_sala = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(1.0, 1.0, 1.0, 0.04) # Cristal sutil
		card_style.border_width_left = 4
		card_style.border_color = Color(0.008, 0.43, 0.8, 0.8)
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_top_right = 10
		card_style.corner_radius_bottom_right = 10
		card_style.corner_radius_bottom_left = 10
		card_style.content_margin_left = 20
		card_style.content_margin_right = 20
		card_style.content_margin_top = 15
		card_style.content_margin_bottom = 15
		card_sala.add_theme_stylebox_override("panel", card_style)
		vbox_salas.add_child(card_sala)
		
		var hbox = HBoxContainer.new()
		card_sala.add_child(hbox)
		
		var v_info = VBoxContainer.new()
		v_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_info.add_theme_constant_override("separation", 2)
		hbox.add_child(v_info)
		
		var lbl_name = Label.new()
		lbl_name.text = sala_name
		lbl_name.add_theme_font_override("font", FONT)
		lbl_name.add_theme_font_size_override("font_size", 22)
		v_info.add_child(lbl_name)
		
		var lbl_detalles = Label.new()
		lbl_detalles.text = "CODIGO: " + sala_id + "  |  JUGADORES: " + str(count_players) + "/" + str(max_limit)
		lbl_detalles.add_theme_font_override("font", FONT)
		lbl_detalles.add_theme_font_size_override("font_size", 14)
		lbl_detalles.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
		v_info.add_child(lbl_detalles)
		
		var btn_join = Button.new()
		btn_join.text = "UNIRSE"
		btn_join.custom_minimum_size = Vector2(150, 50)
		btn_join.add_theme_font_override("font", FONT)
		btn_join.add_theme_font_size_override("font_size", 18)
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.65, 0.15, 0.7)
		btn_style.border_width_left = 2
		btn_style.border_width_top = 2
		btn_style.border_width_right = 2
		btn_style.border_width_bottom = 2
		btn_style.border_color = Color(0.2, 0.65, 0.15, 0.95)
		btn_style.corner_radius_top_left = 10
		btn_style.corner_radius_top_right = 10
		btn_style.corner_radius_bottom_right = 10
		btn_style.corner_radius_bottom_left = 10
		btn_join.add_theme_stylebox_override("normal", btn_style)
		
		var btn_style_hov = btn_style.duplicate()
		btn_style_hov.bg_color = Color(0.2, 0.65, 0.15, 0.9)
		btn_style_hov.shadow_color = Color(0.2, 0.65, 0.15, 0.2)
		btn_style_hov.shadow_size = 6
		btn_join.add_theme_stylebox_override("hover", btn_style_hov)
		btn_join.add_theme_stylebox_override("pressed", btn_style_hov)
		
		btn_join.pressed.connect(func():
			lbl_estado.text = "UNIENDO A SALA: " + str(sala_id) + "..."
			red_manager.unirse_a_sala(sala_id)
		)
		hbox.add_child(btn_join)

func _al_crear_sala(sala_id: String) -> void:
	lbl_estado.text = "SALA CREADA CON EXITO. CODIGO: " + sala_id
	_mostrar_lobby_sala(sala_id)

func _al_unirse_sala(sala_id: String) -> void:
	lbl_estado.text = "CONECTADO A LA SALA. CODIGO: " + sala_id
	_mostrar_lobby_sala(sala_id)

func _al_error_conexion(msg: String) -> void:
	lbl_estado.text = "ERROR: " + msg.to_upper()

func _al_host_desconectado() -> void:
	lbl_estado.text = "EL HOST HA CERRADO LA SALA. REGRESANDO..."
	_restaurar_lobby_list()

func _mostrar_lobby_sala(_sala_id: String) -> void:
	room_list_panel.visible = false
	players_panel.visible = true
	
	# Ocultar botones de navegación principal
	btn_crear_sala_abrir.visible = false
	btn_unirse_codigo_abrir.visible = false
	btn_volver.visible = false
	
	btn_salir_sala.visible = true
	
	# Todos los jugadores pueden iniciar el juego en salas dedicadas
	btn_iniciar.text = "INICIAR JUEGO"
	btn_iniciar.visible = true
		
	_actualizar_lista_jugadores()

func _al_jugadores_actualizados() -> void:
	if red_manager.current_room != "":
		_actualizar_lista_jugadores()

func _restaurar_lobby_list() -> void:
	room_list_panel.visible = true
	players_panel.visible = false
	
	# Mostrar botones de navegación principal
	btn_crear_sala_abrir.visible = true
	btn_unirse_codigo_abrir.visible = true
	btn_volver.visible = true
	
	btn_salir_sala.visible = false
	btn_iniciar.visible = false
	
	red_manager.consultar_salas()

func _actualizar_lista_jugadores() -> void:
	var jugadores_actuales: Array = []
	jugadores_actuales.append(1)
	for id in red_manager.multiplayer.get_peers():
		if id != 1:
			jugadores_actuales.append(id)
			
	# Detectar conexiones al lobby
	for id in jugadores_actuales:
		if not id in jugadores_previos:
			var p_name = red_manager.nombres_jugadores.get(id, "JUGADOR")
			if id == red_manager.multiplayer.get_unique_id():
				p_name = DatosUsuario.nombre_usuario.to_upper() + " (YO)"
			if jugadores_previos.size() > 0:
				lbl_estado.text = p_name.to_upper() + " SE HA UNIDO AL LOBBY"
				
	jugadores_previos = jugadores_actuales

	for child in vbox_jugadores.get_children():
		child.queue_free()
		
	# Agregar Host
	var host_card = PanelContainer.new()
	var host_style = StyleBoxFlat.new()
	host_style.bg_color = Color(1.0, 0.8, 0.0, 0.06)
	host_style.border_width_left = 4
	host_style.border_color = Color(1.0, 0.8, 0.0, 0.8)
	host_style.corner_radius_top_left = 10
	host_style.corner_radius_top_right = 10
	host_style.corner_radius_bottom_right = 10
	host_style.corner_radius_bottom_left = 10
	host_style.content_margin_left = 20
	host_style.content_margin_right = 20
	host_style.content_margin_top = 12
	host_style.content_margin_bottom = 12
	host_card.add_theme_stylebox_override("panel", host_style)
	vbox_jugadores.add_child(host_card)
	
	var host_lbl = Label.new()
	var host_name = red_manager.nombres_jugadores.get(1, "HOST")
	if red_manager.is_host:
		host_name = DatosUsuario.nombre_usuario.to_upper() + " (YO)"
	host_lbl.text = "HOST: " + host_name.to_upper()
	host_lbl.add_theme_font_override("font", FONT)
	host_lbl.add_theme_font_size_override("font_size", 24)
	host_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	host_card.add_child(host_lbl)
	
	# Agregar otros jugadores
	for id in red_manager.multiplayer.get_peers():
		if id == 1:
			continue
		var player_card = PanelContainer.new()
		var player_style = StyleBoxFlat.new()
		player_style.bg_color = Color(1.0, 1.0, 1.0, 0.04)
		player_style.border_width_left = 4
		player_style.border_color = Color(0.008, 0.43, 0.8, 0.8)
		player_style.corner_radius_top_left = 10
		player_style.corner_radius_top_right = 10
		player_style.corner_radius_bottom_right = 10
		player_style.corner_radius_bottom_left = 10
		player_style.content_margin_left = 20
		player_style.content_margin_right = 20
		player_style.content_margin_top = 12
		player_style.content_margin_bottom = 12
		player_card.add_theme_stylebox_override("panel", player_style)
		vbox_jugadores.add_child(player_card)
		
		var player_lbl = Label.new()
		var p_name = red_manager.nombres_jugadores.get(id, "JUGADOR " + str(id))
		if id == red_manager.multiplayer.get_unique_id():
			p_name = DatosUsuario.nombre_usuario.to_upper() + " (YO)"
		player_lbl.text = p_name.to_upper()
		player_lbl.add_theme_font_override("font", FONT)
		player_lbl.add_theme_font_size_override("font_size", 22)
		player_card.add_child(player_lbl)
