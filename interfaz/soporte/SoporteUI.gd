extends Control

signal volver_pressed()
signal mensaje_soporte_recibido(autor: String, mensaje: String)

# ══════════════════════════════════════════════════════════════════════════════
#  SoporteUI.gd  |  Nuestra Tierra 2.0 — Centro de Soporte & Tickets en Vivo v3.0
#  PANTALLA COMPLETA • Capturas de Pantalla • Telemetría • Chat Glassmorphism AAA
# ══════════════════════════════════════════════════════════════════════════════

# ─── Paleta de Colores Moderna (Sin Naranja Aburrido) ──────────────────────────
const C_BG_GLASS         := Color(0.05, 0.05, 0.08, 0.96)  # Vidrio esmerilado oscuro
const C_BORDER_CYAN      := Color(0.20, 0.75, 1.00, 0.85)  # Cyan neón
const C_BORDER_ORANGE    := Color(1.00, 0.50, 0.10, 0.85)  # Naranja sutil
const C_NAME_PLAYER      := Color(0.30, 0.88, 1.00, 1.00)  # Azul Cyan Eléctrico
const C_NAME_STAFF       := Color(0.20, 0.95, 0.60, 1.00)  # Verde Neón Esmeralda
const C_NAME_STAFF_GOLD  := Color(1.00, 0.84, 0.20, 1.00)  # Oro brillante
const C_TEXT_MAIN        := Color(0.90, 0.92, 0.98, 1.00)  # Blanco grisáceo
const C_TEXT_DIM         := Color(0.55, 0.58, 0.68, 1.00)
const C_GREEN            := Color(0.14, 0.88, 0.48, 1.00)
const C_YELLOW           := Color(1.00, 0.78, 0.15, 1.00)
const C_RED              := Color(0.95, 0.25, 0.25, 1.00)

# ─── Variables de Red & Servidor ──────────────────────────────────────────────
const URL_SIGNALLING_VPS := "ws://sdbger1qghfrbw960k2xlnx4.2.25.71.102.sslip.io"
const URL_SIGNALLING_FALLBACK := "ws://2.25.71.102:8080"
const URL_SIGNALLING_LOCAL := "ws://127.0.0.1:8080"

var _ws_peer: WebSocketPeer = WebSocketPeer.new()
var _is_connected: bool = false
var _active_ticket_id: String = ""
var _is_ticket_open: bool = false
var _staff_assigned_name: String = ""
var _ultimo_mensaje_inicial: String = ""
var _font_moderniz: FontFile = null

var _candidate_urls: Array[String] = []
var _current_url_index: int = 0
var _connection_timer: float = 0.0
const CONNECTION_TIMEOUT: float = 3.5

# Control de Reconexión Inteligente y Ahorro de Recursos (0% CPU en reposo)
var _is_trying_to_connect: bool = false
var _retry_count: int = 0
var _reconnect_cooldown: float = 0.0
const RECONNECT_DELAY: float = 3.0
var _last_network_indicator_text: String = ""
var _last_typing_sent_time: float = -10.0

# Datos de soporte recibidos del juego
var _recent_bank_transactions: Array = []
var _regex_negritas: RegEx = null

func _formatear_bbcode_negritas(texto: String) -> String:
	if _regex_negritas == null:
		_regex_negritas = RegEx.new()
		_regex_negritas.compile("\\*\\*(.*?)\\*\\*")
	return _regex_negritas.sub(texto, "[b]$1[/b]", true)

# ─── Nodos de UI ──────────────────────────────────────────────────────────────
var _status_btn: Button = null
var _tel_hbox: HBoxContainer = null
var _form_scroll: ScrollContainer = null
var _chat_container: VBoxContainer = null

# Formulario
var _selected_category: String = "Vehículos y Garaje"
var _category_buttons: Array[Button] = []
var _selected_priority: String = "Normal"
var _priority_buttons: Array[Button] = []
var _desc_text: TextEdit = null
var _create_btn: Button = null

# Chat en Vivo
var _banner_status_panel: PanelContainer = null
var _banner_status_title: Label = null
var _banner_status_sub: Label = null
var _messages_vbox: VBoxContainer = null
var _scroll_container: ScrollContainer = null
var _msg_input: LineEdit = null
var _send_btn: Button = null
var _close_ticket_btn: Button = null
var _typing_indicator_box: PanelContainer = null
var _typing_timer: float = 0.0
var _typing_dots_tween: Tween = null
var _audio_player: AudioStreamPlayer = null

func _ready() -> void:
	_font_moderniz = load("res://recursos/fonts/Moderniz.otf") as FontFile
	
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)
	
	if OS.has_feature("editor") or OS.is_debug_build() or OS.get_name() == "Windows":
		_candidate_urls = [URL_SIGNALLING_LOCAL, URL_SIGNALLING_VPS, URL_SIGNALLING_FALLBACK]
	else:
		_candidate_urls = [URL_SIGNALLING_VPS, URL_SIGNALLING_FALLBACK, URL_SIGNALLING_LOCAL]
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_construir_interfaz_pantalla_completa()

	# Por defecto, procesamiento desactivado (0% CPU mientras el jugador conduce)
	set_process(false)

	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		set_process(true)
		_animar_entrada()
		_actualizar_banner_telemetria()
		if not _is_connected and not _is_trying_to_connect:
			_iniciar_conexion_soporte()
	else:
		# Si el usuario cierra el soporte y no hay ticket abierto, desconectar y apagar proceso
		if not _is_ticket_open:
			if _ws_peer:
				_ws_peer.close()
			_is_connected = false
			_is_trying_to_connect = false
			_reconnect_cooldown = 0.0
			set_process(false)

func asignar_actividades_recientes(transacciones: Array) -> void:
	_recent_bank_transactions = transacciones

func _process(delta: float) -> void:
	if not visible and not _is_ticket_open:
		set_process(false)
		return

	# Temporizador del indicador de escritura de soporte
	if _typing_timer > 0.0:
		_typing_timer -= delta
		if _typing_timer <= 0.0:
			_detener_animacion_typing_dots()
			if is_instance_valid(_typing_indicator_box):
				_typing_indicator_box.visible = false

	# Manejar pausa/cooldown de reintento sin saturar el procesador
	if _reconnect_cooldown > 0.0:
		_reconnect_cooldown -= delta
		if _reconnect_cooldown <= 0.0:
			_conectar_servidor()
		return

	if not _ws_peer:
		return

	_ws_peer.poll()
	var state = _ws_peer.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _is_connected:
			_is_connected = true
			_is_trying_to_connect = false
			_retry_count = 0
			_reconnect_cooldown = 0.0
			var current_target = _candidate_urls[_current_url_index] if not _candidate_urls.is_empty() else "Servidor"
			print("[SoporteUI] Conectado exitosamente con: ", current_target)
			_actualizar_indicador_red("🟢 EN LÍNEA", C_GREEN)
			if _active_ticket_id != "":
				_enviar_ws({"action": "ticket_reconnect", "ticket_id": _active_ticket_id})
		
		while _ws_peer.get_available_packet_count() > 0:
			var raw = _ws_peer.get_packet().get_string_from_utf8()
			_procesar_mensaje_servidor(raw)

	elif state == WebSocketPeer.STATE_CONNECTING:
		_is_connected = false
		_connection_timer += delta
		_actualizar_indicador_red("🟡 CONECTANDO...", C_YELLOW)
		if _connection_timer >= CONNECTION_TIMEOUT:
			_ws_peer.close()
			_manejar_fallo_conexion()

	elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
		if _is_connected:
			_is_connected = false
			_actualizar_indicador_red("🔴 DESCONECTADO", C_RED)
			_manejar_fallo_conexion()
		elif _is_trying_to_connect:
			_manejar_fallo_conexion()

func _construir_interfaz_pantalla_completa() -> void:
	for c in get_children():
		c.queue_free()

	# Fondo Glassmorphic Pantalla Completa
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.03, 0.03, 0.05, 0.96)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)

	# Margen seguro general
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	# Panel Principal Glassmorphic
	var main_panel = PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var glass_style = StyleBoxFlat.new()
	glass_style.bg_color = C_BG_GLASS
	glass_style.border_width_left = 2
	glass_style.border_width_top = 2
	glass_style.border_width_right = 2
	glass_style.border_width_bottom = 2
	glass_style.border_color = C_BORDER_CYAN
	glass_style.corner_radius_top_left = 18
	glass_style.corner_radius_top_right = 18
	glass_style.corner_radius_bottom_left = 18
	glass_style.corner_radius_bottom_right = 18
	glass_style.content_margin_left = 28
	glass_style.content_margin_right = 28
	glass_style.content_margin_top = 20
	glass_style.content_margin_bottom = 20
	glass_style.shadow_color = Color(0, 0, 0, 0.8)
	glass_style.shadow_size = 35
	main_panel.add_theme_stylebox_override("panel", glass_style)
	margin.add_child(main_panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	main_panel.add_child(root_vbox)

	# ─── HEADER SUPERIOR ───────────────────────────────────────────────────────
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 20)
	root_vbox.add_child(header_hbox)

	var back_btn = Button.new()
	back_btn.text = "◀  VOLVER AL JUEGO"
	back_btn.custom_minimum_size = Vector2(270, 65)
	var back_st = _crear_estilo_boton(Color(0.10, 0.12, 0.18, 0.95), C_BORDER_CYAN, 12)
	back_btn.add_theme_stylebox_override("normal", back_st)
	var back_st_h = _crear_estilo_boton(Color(0.18, 0.22, 0.32, 0.95), Color.WHITE, 12)
	back_btn.add_theme_stylebox_override("hover", back_st_h)
	back_btn.add_theme_font_size_override("font_size", 24)
	if _font_moderniz: back_btn.add_theme_font_override("font", _font_moderniz)
	back_btn.pressed.connect(func(): emit_signal("volver_pressed"))
	header_hbox.add_child(back_btn)

	var title_lbl = Label.new()
	title_lbl.text = "CENTRO DE SOPORTE Y ASISTENCIA NT"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", C_NAME_PLAYER)
	if _font_moderniz: title_lbl.add_theme_font_override("font", _font_moderniz)
	header_hbox.add_child(title_lbl)

	_status_btn = Button.new()
	_status_btn.text = "🟡 CONECTANDO..."
	_status_btn.flat = true
	_status_btn.custom_minimum_size = Vector2(280, 55)
	_status_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_btn.add_theme_font_size_override("font_size", 22)
	_status_btn.add_theme_color_override("font_color", C_YELLOW)
	_status_btn.pressed.connect(func():
		_iniciar_conexion_soporte()
	)
	header_hbox.add_child(_status_btn)

	# ─── BARRA DE TELEMETRÍA Y GANANCIAS EN VIVO ──────────────────────────────
	var telemetry_panel = PanelContainer.new()
	var tel_st = StyleBoxFlat.new()
	tel_st.bg_color = Color(0.08, 0.10, 0.16, 0.90)
	tel_st.border_width_left = 1
	tel_st.border_width_top = 1
	tel_st.border_width_right = 1
	tel_st.border_width_bottom = 1
	tel_st.border_color = Color(0.20, 0.70, 1.00, 0.4)
	tel_st.corner_radius_top_left = 10
	tel_st.corner_radius_top_right = 10
	tel_st.corner_radius_bottom_left = 10
	tel_st.corner_radius_bottom_right = 10
	tel_st.content_margin_left = 16
	tel_st.content_margin_right = 16
	tel_st.content_margin_top = 8
	tel_st.content_margin_bottom = 8
	telemetry_panel.add_theme_stylebox_override("panel", tel_st)
	root_vbox.add_child(telemetry_panel)

	_tel_hbox = HBoxContainer.new()
	_tel_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_tel_hbox.add_theme_constant_override("separation", 20)
	telemetry_panel.add_child(_tel_hbox)
	_actualizar_banner_telemetria()

	# ─── VISTA 1: FORMULARIO PANTALLA COMPLETA ────────────────────────────────
	_form_scroll = ScrollContainer.new()
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_form_scroll)

	var form_vbox = VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 16)
	_form_scroll.add_child(form_vbox)

	var subtitulo = Label.new()
	subtitulo.text = "Selecciona la categoría del problema para dirigir tu ticket al departamento correcto en Discord:"
	subtitulo.add_theme_font_size_override("font_size", 26)
	subtitulo.add_theme_color_override("font_color", C_TEXT_MAIN)
	form_vbox.add_child(subtitulo)

	# Cuadrícula de Tarjetas de Categoría (3 columnas x 2 filas)
	var cat_grid = GridContainer.new()
	cat_grid.columns = 3
	cat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_grid.add_theme_constant_override("h_separation", 16)
	cat_grid.add_theme_constant_override("v_separation", 14)
	form_vbox.add_child(cat_grid)

	_category_buttons.clear()
	var categorias = [
		{"name": "Vehículos y Garaje", "icon": "🚛", "desc": "Pérdida de camión, tunning o grúa"},
		{"name": "Economía y Banco",   "icon": "💰", "desc": "Dinero, compras o esmeraldas"},
		{"name": "Bugs y Errores",     "icon": "🐛", "desc": "Fallos de mapa, colisiones o físicas"},
		{"name": "Trabajos y Licencias","icon": "🪪", "desc": "Misiones de carga, pagos o licencias"},
		{"name": "Reporte de Jugador", "icon": "🚨", "desc": "Conductas inapropiadas o choques"},
		{"name": "Asistencia General", "icon": "❓", "desc": "Dudas del simulador, cuenta o ideas"}
	]

	for cat in categorias:
		var btn = _crear_tarjeta_categoria(cat["name"], cat["icon"], cat["desc"])
		cat_grid.add_child(btn)
		_category_buttons.append(btn)

	# Selector de Prioridad
	var prio_box = VBoxContainer.new()
	prio_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_child(prio_box)

	var prio_lbl = Label.new()
	prio_lbl.text = "Urgencia del caso:"
	prio_lbl.add_theme_font_size_override("font_size", 24)
	prio_lbl.add_theme_color_override("font_color", C_TEXT_MAIN)
	prio_box.add_child(prio_lbl)

	var prio_hbox = HBoxContainer.new()
	prio_hbox.add_theme_constant_override("separation", 14)
	prio_box.add_child(prio_hbox)

	_priority_buttons.clear()
	var prioridades = [
		{"name": "Normal", "color": C_GREEN, "icon": "🟢"},
		{"name": "Media",  "color": C_YELLOW, "icon": "🟡"},
		{"name": "Urgente","color": C_RED, "icon": "🔴"}
	]
	for p in prioridades:
		var p_btn = Button.new()
		p_btn.text = p["icon"] + " " + p["name"]
		p_btn.custom_minimum_size = Vector2(170, 52)
		p_btn.add_theme_font_size_override("font_size", 24)
		var p_st = _crear_estilo_boton(Color(0.10, 0.12, 0.18), p["color"], 10)
		p_btn.add_theme_stylebox_override("normal", p_st)
		p_btn.pressed.connect(func(): _seleccionar_prioridad(p["name"]))
		prio_hbox.add_child(p_btn)
		_priority_buttons.append(p_btn)

	_actualizar_estilo_prioridades()

	# Campo de Descripción
	var desc_label = Label.new()
	desc_label.text = "Describe detalladamente lo ocurrido o tu consulta:"
	desc_label.add_theme_font_size_override("font_size", 26)
	desc_label.add_theme_color_override("font_color", C_TEXT_MAIN)
	form_vbox.add_child(desc_label)

	_desc_text = TextEdit.new()
	_desc_text.placeholder_text = "Escribe tu problema o consulta aquí con todos los detalles posibles..."
	_desc_text.custom_minimum_size = Vector2(0, 130)
	_desc_text.add_theme_font_size_override("font_size", 26)
	_desc_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var text_st = _crear_estilo_caja_texto()
	_desc_text.add_theme_stylebox_override("normal", text_st)
	_desc_text.add_theme_stylebox_override("focus", text_st)
	form_vbox.add_child(_desc_text)

	# Botón de Acción Principal (80px, Moderniz 32px)
	_create_btn = Button.new()
	_create_btn.text = "🚀  ABRIR TICKET EN DISCORD"
	_create_btn.custom_minimum_size = Vector2(0, 80)
	var btn_st = _crear_estilo_boton(C_NAME_STAFF, Color.WHITE, 12)
	_create_btn.add_theme_stylebox_override("normal", btn_st)
	var btn_st_h = _crear_estilo_boton(Color(0.35, 1.00, 0.70), Color.WHITE, 12)
	_create_btn.add_theme_stylebox_override("hover", btn_st_h)
	_create_btn.add_theme_font_size_override("font_size", 32)
	_create_btn.add_theme_color_override("font_color", Color.BLACK)
	if _font_moderniz: _create_btn.add_theme_font_override("font", _font_moderniz)
	_create_btn.pressed.connect(_on_crear_ticket_pressed)
	form_vbox.add_child(_create_btn)

	# ─── VISTA 2: CHAT EN TIEMPO REAL PANTALLA COMPLETA ───────────────────────
	_chat_container = VBoxContainer.new()
	_chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_container.add_theme_constant_override("separation", 14)
	_chat_container.visible = false
	root_vbox.add_child(_chat_container)

	# BANNER DESTACADO: "TOMADO POR EL EQUIPO DE SOPORTE"
	_banner_status_panel = PanelContainer.new()
	var ban_st = StyleBoxFlat.new()
	ban_st.bg_color = Color(0.06, 0.20, 0.14, 0.95)
	ban_st.border_width_left = 2
	ban_st.border_width_top = 2
	ban_st.border_width_right = 2
	ban_st.border_width_bottom = 2
	ban_st.border_color = C_GREEN
	ban_st.corner_radius_top_left = 12
	ban_st.corner_radius_top_right = 12
	ban_st.corner_radius_bottom_left = 12
	ban_st.corner_radius_bottom_right = 12
	ban_st.content_margin_left = 20
	ban_st.content_margin_right = 20
	ban_st.content_margin_top = 10
	ban_st.content_margin_bottom = 10
	_banner_status_panel.add_theme_stylebox_override("panel", ban_st)
	_chat_container.add_child(_banner_status_panel)

	var ban_hbox = HBoxContainer.new()
	ban_hbox.add_theme_constant_override("separation", 20)
	_banner_status_panel.add_child(ban_hbox)

	var ban_vbox = VBoxContainer.new()
	ban_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ban_hbox.add_child(ban_vbox)

	_banner_status_title = Label.new()
	_banner_status_title.text = "⏳ EN ESPERA DE ATENCIÓN"
	_banner_status_title.add_theme_font_size_override("font_size", 28)
	_banner_status_title.add_theme_color_override("font_color", C_YELLOW)
	if _font_moderniz: _banner_status_title.add_theme_font_override("font", _font_moderniz)
	ban_vbox.add_child(_banner_status_title)

	_banner_status_sub = Label.new()
	_banner_status_sub.text = "Tu ticket ha sido recibido en Discord. Un moderador lo tomará en breve."
	_banner_status_sub.add_theme_font_size_override("font_size", 22)
	_banner_status_sub.add_theme_color_override("font_color", C_TEXT_MAIN)
	ban_vbox.add_child(_banner_status_sub)

	_close_ticket_btn = Button.new()
	_close_ticket_btn.text = "FINALIZAR TICKET"
	_close_ticket_btn.custom_minimum_size = Vector2(260, 65)
	var close_st = _crear_estilo_boton(Color(0.8, 0.2, 0.2, 0.9), Color(1.0, 0.4, 0.4), 10)
	_close_ticket_btn.add_theme_stylebox_override("normal", close_st)
	var close_st_h = _crear_estilo_boton(Color(0.95, 0.25, 0.25, 1.0), Color.WHITE, 10)
	_close_ticket_btn.add_theme_stylebox_override("hover", close_st_h)
	_close_ticket_btn.add_theme_font_size_override("font_size", 22)
	if _font_moderniz: _close_ticket_btn.add_theme_font_override("font", _font_moderniz)
	_close_ticket_btn.pressed.connect(_on_cerrar_ticket_pressed)
	ban_hbox.add_child(_close_ticket_btn)

	# ScrollContainer para los mensajes del chat
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var scroll_bg = PanelContainer.new()
	var s_bg_st = StyleBoxFlat.new()
	s_bg_st.bg_color = Color(0.04, 0.04, 0.07, 0.92)
	s_bg_st.corner_radius_top_left = 12
	s_bg_st.corner_radius_top_right = 12
	s_bg_st.corner_radius_bottom_left = 12
	s_bg_st.corner_radius_bottom_right = 12
	s_bg_st.content_margin_left = 20
	s_bg_st.content_margin_right = 20
	s_bg_st.content_margin_top = 18
	s_bg_st.content_margin_bottom = 18
	scroll_bg.add_theme_stylebox_override("panel", s_bg_st)
	scroll_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_messages_vbox = VBoxContainer.new()
	_messages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages_vbox.add_theme_constant_override("separation", 16)
	scroll_bg.add_child(_messages_vbox)
	_scroll_container.add_child(scroll_bg)
	_chat_container.add_child(_scroll_container)

	# Indicador de Escritura en Vivo de Soporte (Bouncing Dots)
	_typing_indicator_box = PanelContainer.new()
	var typ_st = StyleBoxFlat.new()
	typ_st.bg_color = Color(0.06, 0.18, 0.14, 0.95)
	typ_st.border_width_left = 2; typ_st.border_width_top = 2
	typ_st.border_width_right = 2; typ_st.border_width_bottom = 2
	typ_st.border_color = C_NAME_STAFF
	typ_st.shadow_color = Color(0.15, 0.95, 0.55, 0.35)
	typ_st.shadow_size = 12
	for c in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		typ_st.set("corner_radius_" + c, 14)
	typ_st.content_margin_left = 20
	typ_st.content_margin_right = 20
	typ_st.content_margin_top = 8
	typ_st.content_margin_bottom = 8
	_typing_indicator_box.add_theme_stylebox_override("panel", typ_st)
	_typing_indicator_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_typing_indicator_box.visible = false

	var typ_hbox = HBoxContainer.new()
	typ_hbox.add_theme_constant_override("separation", 8)
	_typing_indicator_box.add_child(typ_hbox)

	var typ_lbl = Label.new()
	typ_lbl.name = "TypingLabel"
	typ_lbl.text = "✍️  Soporte está redactando"
	typ_lbl.add_theme_font_size_override("font_size", 22)
	typ_lbl.add_theme_color_override("font_color", C_NAME_STAFF)
	if _font_moderniz: typ_lbl.add_theme_font_override("font", _font_moderniz)
	typ_hbox.add_child(typ_lbl)

	for i in range(3):
		var d = Label.new()
		d.name = "Dot" + str(i + 1)
		d.text = "●"
		d.add_theme_font_size_override("font_size", 20)
		d.add_theme_color_override("font_color", C_NAME_STAFF_GOLD)
		typ_hbox.add_child(d)

	_chat_container.add_child(_typing_indicator_box)

	# Barra de Entrada de Mensajes (80px)
	var input_hbox = HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 16)
	_chat_container.add_child(input_hbox)

	_msg_input = LineEdit.new()
	_msg_input.placeholder_text = "Escribe un mensaje al equipo de soporte..."
	_msg_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_input.custom_minimum_size = Vector2(0, 80)
	_msg_input.add_theme_font_size_override("font_size", 28)
	_msg_input.add_theme_stylebox_override("normal", text_st)
	_msg_input.add_theme_stylebox_override("focus", text_st)
	_msg_input.text_submitted.connect(_on_mensaje_enviado)
	_msg_input.text_changed.connect(_on_input_text_changed)
	input_hbox.add_child(_msg_input)

	_send_btn = Button.new()
	_send_btn.text = "ENVIAR"
	_send_btn.custom_minimum_size = Vector2(230, 80)
	var send_st = _crear_estilo_boton(C_NAME_PLAYER, Color.WHITE, 12)
	_send_btn.add_theme_stylebox_override("normal", send_st)
	var send_st_h = _crear_estilo_boton(Color(0.4, 0.9, 1.0), Color.WHITE, 12)
	_send_btn.add_theme_stylebox_override("hover", send_st_h)
	_send_btn.add_theme_font_size_override("font_size", 32)
	_send_btn.add_theme_color_override("font_color", Color.BLACK)
	if _font_moderniz: _send_btn.add_theme_font_override("font", _font_moderniz)
	_send_btn.pressed.connect(func(): _on_mensaje_enviado(_msg_input.text))
	input_hbox.add_child(_send_btn)

# ─── FUNCIONES DE COMPONENTES INTERACTIVOS ────────────────────────────────────

func _crear_tarjeta_categoria(nombre: String, icono: String, descripcion: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 92)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var is_sel = (nombre == _selected_category)
	var st = _crear_estilo_tarjeta(is_sel)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var tit = Label.new()
	tit.text = icono + " " + nombre
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 26)
	tit.add_theme_color_override("font_color", C_NAME_PLAYER if is_sel else Color.WHITE)
	if _font_moderniz: tit.add_theme_font_override("font", _font_moderniz)
	vb.add_child(tit)
	
	var sub = Label.new()
	sub.text = descripcion
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", C_TEXT_DIM)
	vb.add_child(sub)
	
	btn.add_child(vb)
	btn.pressed.connect(func(): _seleccionar_categoria(nombre))
	return btn

func _seleccionar_categoria(nombre: String) -> void:
	_selected_category = nombre
	for btn in _category_buttons:
		var vb = btn.get_child(0) as VBoxContainer
		if vb:
			var tit = vb.get_child(0) as Label
			var is_sel = (tit.text.ends_with(nombre))
			btn.add_theme_stylebox_override("normal", _crear_estilo_tarjeta(is_sel))
			btn.add_theme_stylebox_override("hover", _crear_estilo_tarjeta(is_sel))
			tit.add_theme_color_override("font_color", C_NAME_PLAYER if is_sel else Color.WHITE)

func _seleccionar_prioridad(prio: String) -> void:
	_selected_priority = prio
	_actualizar_estilo_prioridades()

func _actualizar_estilo_prioridades() -> void:
	for btn in _priority_buttons:
		var is_sel = btn.text.ends_with(_selected_priority)
		var base_color = Color(0.18, 0.22, 0.32) if is_sel else Color(0.08, 0.10, 0.14)
		var border = C_NAME_PLAYER if is_sel else Color(0.25, 0.25, 0.35)
		var st = _crear_estilo_boton(base_color, border, 10)
		btn.add_theme_stylebox_override("normal", st)

func _crear_estilo_tarjeta(seleccionada: bool) -> StyleBoxFlat:
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.18, 0.28, 0.95) if seleccionada else Color(0.08, 0.09, 0.13, 0.85)
	st.border_width_left = 3 if seleccionada else 1
	st.border_width_top = 3 if seleccionada else 1
	st.border_width_right = 3 if seleccionada else 1
	st.border_width_bottom = 3 if seleccionada else 1
	st.border_color = C_NAME_PLAYER if seleccionada else Color(0.22, 0.25, 0.35, 0.6)
	st.corner_radius_top_left = 12
	st.corner_radius_top_right = 12
	st.corner_radius_bottom_left = 12
	st.corner_radius_bottom_right = 12
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	return st

# ─── TELEMETRÍA Y RED ─────────────────────────────────────────────────────────

func _actualizar_banner_telemetria() -> void:
	if not _tel_hbox:
		return
	for c in _tel_hbox.get_children():
		c.queue_free()

	var name_str = "Conductor"
	var uid_str = "NT-LOCAL"
	var level_int = 1
	var money_int = 0
	var emeralds_int = 0
	var veh_str = "Ninguno"
	var DU = get_node_or_null("/root/DatosUsuario")
	if DU:
		if "nombre_usuario" in DU and DU.nombre_usuario != "": name_str = DU.nombre_usuario
		if "firebase_uid" in DU and DU.firebase_uid != "": uid_str = DU.firebase_uid
		if "nivel" in DU: level_int = DU.nivel
		if "dinero" in DU: money_int = DU.dinero
		if "esmeraldas" in DU: emeralds_int = DU.esmeraldas
		if "guardado_player_vehiculo_nombre" in DU and DU.guardado_player_vehiculo_nombre != "":
			veh_str = DU.guardado_player_vehiculo_nombre

	var tags = [
		"👤 Conductor: " + name_str,
		"🆔 UID: " + uid_str,
		"⭐ Nivel: " + str(level_int),
		"💵 $" + _formatear_pesos(money_int),
		"💎 " + str(emeralds_int),
		"🚛 " + veh_str,
		"📱 " + OS.get_name()
	]
	for t in tags:
		var lbl = Label.new()
		lbl.text = t
		lbl.add_theme_font_size_override("font_size", 21)
		lbl.add_theme_color_override("font_color", C_TEXT_MAIN)
		_tel_hbox.add_child(lbl)

func _obtener_telemetria_jugador() -> Dictionary:
	var data = {
		"name": "Conductor",
		"uid": "NT-LOCAL",
		"level": 1,
		"money": 0,
		"emeralds": 0,
		"vehicle": "Ninguno",
		"is_driving": false,
		"position": "(0, 0)",
		"platform": OS.get_name(),
		"licenses_str": "Básica",
		"vehicles_owned_str": "Ninguno",
		"transactions": []
	}
	var DU = get_node_or_null("/root/DatosUsuario")
	if DU:
		if "nombre_usuario" in DU and DU.nombre_usuario != "": data["name"] = DU.nombre_usuario
		if "firebase_uid" in DU and DU.firebase_uid != "": data["uid"] = DU.firebase_uid
		if "nivel" in DU: data["level"] = DU.nivel
		if "dinero" in DU: data["money"] = DU.dinero
		if "esmeraldas" in DU: data["emeralds"] = DU.esmeraldas
		if "guardado_player_vehiculo_nombre" in DU and DU.guardado_player_vehiculo_nombre != "":
			data["vehicle"] = DU.guardado_player_vehiculo_nombre
		if "guardado_player_conduciendo" in DU:
			data["is_driving"] = DU.guardado_player_conduciendo

		# Licencias
		var lics = []
		if "licencia_automovil" in DU and DU.licencia_automovil: lics.append("Automóvil")
		if "licencia_camion" in DU and DU.licencia_camion: lics.append("Camión C2/C3")
		if "licencia_carga_delicada" in DU and DU.licencia_carga_delicada: lics.append("Carga Delicada")
		if "licencia_carga_sobredimensionada" in DU and DU.licencia_carga_sobredimensionada: lics.append("Sobredimensionada")
		if not lics.is_empty():
			data["licenses_str"] = ", ".join(lics)

		# Vehículos en propiedad
		if "vehiculos_personalizados" in DU and DU.vehiculos_personalizados is Dictionary:
			var v_names = DU.vehiculos_personalizados.keys()
			if not v_names.is_empty():
				data["vehicles_owned_str"] = ", ".join(v_names)

	# Historial reciente de transacciones
	if not _recent_bank_transactions.is_empty():
		data["transactions"] = _recent_bank_transactions.slice(max(0, _recent_bank_transactions.size() - 5))

	# Coordenadas exactas en mapa usando búsqueda directa O(1) de primer nodo
	var tree = get_tree()
	if tree:
		var player = tree.get_first_node_in_group("Jugador")
		if player is Node3D:
			var pos = player.global_position
			data["position"] = "X: %.1f, Y: %.1f, Z: %.1f" % [pos.x, pos.y, pos.z]
	
	return data

func _formatear_pesos(valor: int) -> String:
	var s = str(valor)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res

func _formatear_numero(valor: int) -> String:
	return _formatear_pesos(valor)

func _iniciar_conexion_soporte() -> void:
	_retry_count = 0
	_current_url_index = 0
	_reconnect_cooldown = 0.0
	_is_trying_to_connect = true
	_conectar_servidor()

func _conectar_servidor() -> void:
	if _candidate_urls.is_empty():
		_candidate_urls = [URL_SIGNALLING_LOCAL, URL_SIGNALLING_VPS, URL_SIGNALLING_FALLBACK]
	
	if _current_url_index >= _candidate_urls.size():
		_current_url_index = 0

	var target_url = _candidate_urls[_current_url_index]
	_actualizar_indicador_red("🟡 CONECTANDO...", C_YELLOW)
	_connection_timer = 0.0
	
	if _ws_peer:
		_ws_peer.close()
	_ws_peer = WebSocketPeer.new()
	var err = _ws_peer.connect_to_url(target_url)
	if err != OK:
		_manejar_fallo_conexion()

func _manejar_fallo_conexion() -> void:
	_retry_count += 1
	if _retry_count >= _candidate_urls.size():
		# Se probaron todos los servidores y ninguno respondió
		# Detener el ciclo por completo para que el juego consuma 0% CPU
		_is_trying_to_connect = false
		_retry_count = 0
		_reconnect_cooldown = 0.0
		_actualizar_indicador_red("🔴 DESCONECTADO (Reintentar)", C_RED)
		print("[SoporteUI] Servidores de soporte no disponibles. Entrando en reposo.")
		if not visible and not _is_ticket_open:
			set_process(false)
	else:
		# Siguiente servidor tras 3 segundos de cooldown
		_current_url_index = (_current_url_index + 1) % _candidate_urls.size()
		_reconnect_cooldown = RECONNECT_DELAY
		_actualizar_indicador_red("🟡 REINTENTANDO...", C_YELLOW)

func _enviar_ws(payload: Dictionary) -> void:
	if _ws_peer and _ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_str = JSON.stringify(payload)
		_ws_peer.send_text(json_str)
		print("[SoporteUI] WebSocket enviado -> ", payload.get("action", ""))
	else:
		push_warning("[SoporteUI] No se pudo enviar mensaje por WS: estado no es OPEN.")

func _procesar_mensaje_servidor(raw_text: String) -> void:
	print("[SoporteUI] <<< Mensaje recibido del servidor: ", raw_text)
	var parsed = JSON.parse_string(raw_text)
	if not parsed or not (parsed is Dictionary):
		return

	var action = parsed.get("action", "")

	match action:
		"ticket_created":
			_active_ticket_id = str(parsed.get("ticket_id", ""))
			_is_ticket_open = true
			_limpiar_mensajes_chat()
			_mostrar_vista_chat()
			_actualizar_banner_estado(false, "")
			_agregar_burbuja_sistema("¡Ticket #" + _active_ticket_id + " creado con éxito! Esperando que el equipo de soporte lo atienda en Discord.")
			if _ultimo_mensaje_inicial != "":
				_agregar_burbuja_jugador("Tú", _ultimo_mensaje_inicial)

		"ticket_typing":
			_typing_timer = 4.5
			if is_instance_valid(_typing_indicator_box):
				_typing_indicator_box.visible = true
				_iniciar_animacion_typing_dots()
				_scroll_to_bottom()

		"ticket_claimed":
			var area = parsed.get("area", "Soporte Oficial NT")
			var staff = parsed.get("staff_name", "Especialista")
			var welcome = parsed.get("welcome_message", "")
			_staff_assigned_name = area
			_actualizar_banner_estado(true, area)
			_typing_timer = 0.0
			_detener_animacion_typing_dots()
			if is_instance_valid(_typing_indicator_box):
				_typing_indicator_box.visible = false
			_reproducir_sonido("res://recursos/efectos/checkpoint.mp3")
			if welcome != "":
				_agregar_burbuja_soporte(area, welcome)
			else:
				_agregar_burbuja_sistema("🛡️ Tu ticket ha sido tomado por el área de: " + area)
			emit_signal("mensaje_soporte_recibido", area, "Ticket asignado a " + area)

		"ticket_escalated":
			var area = parsed.get("area", "Especialistas")
			var reason = parsed.get("reason", "")
			var ai_handover = parsed.get("ai_handover", "")
			_staff_assigned_name = area
			_actualizar_banner_estado(true, area)
			_typing_timer = 0.0
			_detener_animacion_typing_dots()
			if is_instance_valid(_typing_indicator_box):
				_typing_indicator_box.visible = false
			_reproducir_sonido("res://recursos/efectos/checkpoint.mp3")
			_agregar_tarjeta_elevacion_impacto(area, reason)
			if ai_handover != "":
				_agregar_burbuja_asistente_ia(area, ai_handover)
			emit_signal("mensaje_soporte_recibido", area, "Ticket transferido a " + area)

		"ticket_reply":
			var area = parsed.get("area", "Soporte Oficial NT")
			var msg = parsed.get("message", "")
			_typing_timer = 0.0
			_detener_animacion_typing_dots()
			if is_instance_valid(_typing_indicator_box):
				_typing_indicator_box.visible = false
			_reproducir_sonido("res://recursos/efectos/seleccion1.mp3")
			_agregar_burbuja_soporte(area, msg)
			emit_signal("mensaje_soporte_recibido", area, msg)

		"ticket_action_unstuck":
			var staff = parsed.get("staff_name", "Soporte Técnico")
			_desatascar_jugador_y_vehiculo()
			_agregar_tarjeta_asistencia_mecanica(staff)
			_reproducir_sonido("res://recursos/sonidos_vehiculo/efectos/Hidraulico.mp3")
			emit_signal("mensaje_soporte_recibido", staff, "🚜 Grúa y asistencia técnica aplicada a tu vehículo.")

		"ticket_action_compensate":
			var staff = parsed.get("staff_name", "Equipo de Soporte")
			var amount = int(parsed.get("amount", 15000))
			var reason = str(parsed.get("reason", "Bonificación por soporte"))
			_aplicar_bonificacion_jugador(amount)
			_agregar_tarjeta_compensacion(staff, amount, reason)
			_reproducir_sonido("res://recursos/efectos/money.mp3")
			emit_signal("mensaje_soporte_recibido", staff, "🎁 Has recibido una bonificación de $" + str(amount) + " COP.")

		"ticket_request_telemetry":
			var tele = _obtener_telemetria_jugador()
			tele["action"] = "ticket_telemetry_update"
			tele["ticket_id"] = _active_ticket_id
			_enviar_ws(tele)

		"ticket_msg_sent":
			pass

		"ticket_closed":
			_is_ticket_open = false
			_detener_animacion_typing_dots()
			if is_instance_valid(_typing_indicator_box):
				_typing_indicator_box.visible = false
			var by = parsed.get("by", "Soporte")
			_actualizar_banner_cerrado(by)
			_agregar_burbuja_sistema("El ticket ha sido finalizado por: " + by)
			_msg_input.editable = false
			_send_btn.disabled = true
			_close_ticket_btn.text = "CREAR OTRO TICKET"
			_mostrar_tarjeta_calificacion_servicio()

		"ticket_reconnected":
			var is_open = parsed.get("is_open", false)
			if is_open:
				_is_ticket_open = true
				var claimed = parsed.get("claimed_by", null)
				_mostrar_vista_chat()
				if claimed and str(claimed) != "":
					_staff_assigned_name = str(claimed)
					_actualizar_banner_estado(true, _staff_assigned_name)
				else:
					_actualizar_banner_estado(false, "")
				_agregar_burbuja_sistema("Reconectado a la sesión del ticket #" + _active_ticket_id)
			else:
				_active_ticket_id = ""
				_mostrar_vista_formulario()

		"ticket_error":
			var err_msg = parsed.get("message", "Error en el ticket.")
			_agregar_burbuja_sistema("⚠️ " + err_msg)

# ─── ACCIONES DE USUARIO ──────────────────────────────────────────────────────

func _on_crear_ticket_pressed() -> void:
	var desc = _desc_text.text.strip_edges()
	if desc == "":
		_desc_text.placeholder_text = "⚠️ Por favor describe tu problema antes de enviar..."
		return

	if not _ws_peer or _ws_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_create_btn.text = "⚠️ SIN CONEXIÓN - RECONECTANDO..."
		_iniciar_conexion_soporte()
		await get_tree().create_timer(1.2).timeout
		if not _ws_peer or _ws_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			_create_btn.disabled = false
			_create_btn.text = "🚀  ABRIR TICKET EN DISCORD"
			return

	_ultimo_mensaje_inicial = desc
	_limpiar_mensajes_chat()

	_create_btn.disabled = true
	_create_btn.text = "ENVIANDO TICKET A DISCORD..."
	# Ceder un cuadro de ejecución para que la UI se refresque instantáneamente
	await get_tree().process_frame

	var tele = _obtener_telemetria_jugador()

	var payload = {
		"action": "ticket_create",
		"player_name": tele["name"],
		"player_id": tele["uid"],
		"category": _selected_category,
		"priority": _selected_priority,
		"level": tele["level"],
		"money": tele["money"],
		"emeralds": tele["emeralds"],
		"vehicle": tele["vehicle"],
		"is_driving": tele["is_driving"],
		"position": tele["position"],
		"platform": tele["platform"],
		"licenses_str": tele["licenses_str"],
		"vehicles_owned_str": tele["vehicles_owned_str"],
		"transactions": tele["transactions"],
		"message": desc
	}

	_enviar_ws(payload)

	# Watchdog de seguridad: Si en 5 segundos no llega respuesta, desbloquear botón
	get_tree().create_timer(5.0).timeout.connect(func():
		if not _is_ticket_open and is_instance_valid(_create_btn) and _create_btn.disabled:
			_create_btn.disabled = false
			_create_btn.text = "🚀  ABRIR TICKET EN DISCORD"
			_actualizar_indicador_red("⚠️ REINTENTAR TICKET", C_YELLOW)
	)

func _on_input_text_changed(new_text: String) -> void:
	if not _is_ticket_open or _active_ticket_id == "":
		return
	if new_text.strip_edges() == "":
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_typing_sent_time > 3.0:
		_last_typing_sent_time = now
		_enviar_ws({
			"action": "ticket_typing",
			"ticket_id": _active_ticket_id
		})

func _on_mensaje_enviado(texto: String) -> void:
	var msg = texto.strip_edges()
	if msg == "" or not _is_ticket_open:
		return

	_msg_input.text = ""
	_agregar_burbuja_jugador("Tú", msg)

	_enviar_ws({
		"action": "ticket_send_msg",
		"ticket_id": _active_ticket_id,
		"message": msg
	})

func _on_cerrar_ticket_pressed() -> void:
	if not _is_ticket_open:
		_active_ticket_id = ""
		_staff_assigned_name = ""
		_mostrar_vista_formulario()
		return

	_enviar_ws({
		"action": "ticket_close",
		"ticket_id": _active_ticket_id
	})

# ─── BURBUJAS DE CHAT MODERNAS (AAA GLASSMORPHISM) ───────────────────────────

func _actualizar_banner_estado(tomado: bool, staff_name: String) -> void:
	if not _banner_status_panel:
		return
	var st = _banner_status_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if tomado:
		if st:
			st.bg_color = Color(0.06, 0.22, 0.12, 0.95)
			st.border_color = C_GREEN
		_banner_status_title.text = "🟢 TOMADO POR EL EQUIPO DE SOPORTE"
		_banner_status_title.add_theme_color_override("font_color", C_NAME_STAFF)
		_banner_status_sub.text = "🛡️ Atendido por: " + staff_name + " • Conversación en vivo"
		_banner_status_sub.add_theme_color_override("font_color", C_NAME_STAFF_GOLD)
	else:
		if st:
			st.bg_color = Color(0.20, 0.15, 0.05, 0.95)
			st.border_color = C_YELLOW
		_banner_status_title.text = "⏳ EN ESPERA DE ATENCIÓN"
		_banner_status_title.add_theme_color_override("font_color", C_YELLOW)
		_banner_status_sub.text = "Tu ticket ha sido recibido en Discord. Un moderador lo tomará en breve."
		_banner_status_sub.add_theme_color_override("font_color", C_TEXT_MAIN)

	# Microinteracción: Pulso de atención dinámico
	_banner_status_panel.pivot_offset = _banner_status_panel.size / 2.0
	var tw = _banner_status_panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner_status_panel, "scale", Vector2(1.02, 1.02), 0.14)
	tw.tween_property(_banner_status_panel, "scale", Vector2(1.0, 1.0), 0.14)

func _actualizar_banner_cerrado(by: String) -> void:
	if not _banner_status_panel:
		return
	var st = _banner_status_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if st:
		st.bg_color = Color(0.20, 0.06, 0.06, 0.95)
		st.border_color = C_RED
	_banner_status_title.text = "🔒 TICKET FINALIZADO"
	_banner_status_title.add_theme_color_override("font_color", C_RED)
	_banner_status_sub.text = "Este ticket ha sido cerrado por: " + by

func _agregar_burbuja_jugador(autor: String, mensaje: String) -> void:
	var bubble = PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	bubble.custom_minimum_size = Vector2(520, 0)
	
	# Estilo Glassmorphic Cyan Eléctrico
	var b_st = StyleBoxFlat.new()
	b_st.bg_color = Color(0.08, 0.22, 0.38, 0.92)
	b_st.border_width_left = 2
	b_st.border_width_top = 2
	b_st.border_width_right = 2
	b_st.border_width_bottom = 2
	b_st.border_color = C_NAME_PLAYER
	b_st.corner_radius_top_left = 16
	b_st.corner_radius_top_right = 16
	b_st.corner_radius_bottom_left = 16
	b_st.corner_radius_bottom_right = 4
	b_st.content_margin_left = 22
	b_st.content_margin_right = 22
	b_st.content_margin_top = 14
	b_st.content_margin_bottom = 14
	bubble.add_theme_stylebox_override("panel", b_st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	var header_h = HBoxContainer.new()
	var tag = Label.new()
	tag.text = "👤 " + autor
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", C_NAME_PLAYER)
	if _font_moderniz: tag.add_theme_font_override("font", _font_moderniz)
	header_h.add_child(tag)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_h.add_child(spacer)

	var time_lbl = Label.new()
	time_lbl.text = "Ahora  ✓✓"
	time_lbl.add_theme_font_size_override("font_size", 18)
	time_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.8))
	header_h.add_child(time_lbl)
	vb.add_child(header_h)

	var body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _formatear_bbcode_negritas(mensaje)
	body.add_theme_font_size_override("normal_font_size", 28)
	body.add_theme_font_size_override("bold_font_size", 28)
	body.add_theme_color_override("default_color", Color.WHITE)
	vb.add_child(body)

	bubble.add_child(vb)
	_messages_vbox.add_child(bubble)
	_animar_aparicion_burbuja(bubble, true)
	_scroll_to_bottom()

func _agregar_burbuja_soporte(autor: String, mensaje: String) -> void:
	var bubble = PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bubble.custom_minimum_size = Vector2(560, 0)
	
	# Estilo Glassmorphic Esmeralda / Oro
	var b_st = StyleBoxFlat.new()
	b_st.bg_color = Color(0.08, 0.16, 0.14, 0.95)
	b_st.border_width_left = 3
	b_st.border_width_top = 3
	b_st.border_width_right = 3
	b_st.border_width_bottom = 3
	b_st.border_color = C_NAME_STAFF
	b_st.corner_radius_top_left = 16
	b_st.corner_radius_top_right = 16
	b_st.corner_radius_bottom_left = 4
	b_st.corner_radius_bottom_right = 16
	b_st.content_margin_left = 22
	b_st.content_margin_right = 22
	b_st.content_margin_top = 14
	b_st.content_margin_bottom = 14
	bubble.add_theme_stylebox_override("panel", b_st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)

	var header_h = HBoxContainer.new()
	var tag = Label.new()
	tag.text = "🛡️ [Soporte NT • " + autor + "]"
	tag.add_theme_font_size_override("font_size", 23)
	tag.add_theme_color_override("font_color", C_NAME_STAFF)
	if _font_moderniz: tag.add_theme_font_override("font", _font_moderniz)
	header_h.add_child(tag)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_h.add_child(spacer)

	var verified = Label.new()
	verified.text = "⭐ Verificado"
	verified.add_theme_font_size_override("font_size", 18)
	verified.add_theme_color_override("font_color", C_NAME_STAFF_GOLD)
	header_h.add_child(verified)
	vb.add_child(header_h)

	var body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _formatear_bbcode_negritas(mensaje)
	body.add_theme_font_size_override("normal_font_size", 28)
	body.add_theme_font_size_override("bold_font_size", 28)
	body.add_theme_color_override("default_color", C_TEXT_MAIN)
	vb.add_child(body)

	bubble.add_child(vb)
	_messages_vbox.add_child(bubble)
	_animar_aparicion_burbuja(bubble, false)
	_scroll_to_bottom()

func _agregar_burbuja_sistema(mensaje: String) -> void:
	var p = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.14, 0.20, 0.85)
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", st)

	var lbl = Label.new()
	lbl.text = "ℹ️  " + mensaje
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	p.add_child(lbl)

	_messages_vbox.add_child(p)
	_animar_aparicion_burbuja(p, false)
	_scroll_to_bottom()

func _animar_aparicion_burbuja(bubble: Control, desde_derecha: bool) -> void:
	bubble.modulate.a = 0.0
	bubble.scale = Vector2(0.88, 0.88)
	bubble.pivot_offset = Vector2(500 if desde_derecha else 0, 25)
	var tw = bubble.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "modulate:a", 1.0, 0.26)
	tw.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.26)

func _limpiar_mensajes_chat() -> void:
	if _messages_vbox:
		for child in _messages_vbox.get_children():
			child.queue_free()

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if _scroll_container:
		_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)

func _iniciar_animacion_typing_dots() -> void:
	if _typing_dots_tween and _typing_dots_tween.is_valid():
		return
	if not is_instance_valid(_typing_indicator_box):
		return
	var d1 = _typing_indicator_box.find_child("Dot1", true, false)
	var d2 = _typing_indicator_box.find_child("Dot2", true, false)
	var d3 = _typing_indicator_box.find_child("Dot3", true, false)
	if not d1 or not d2 or not d3:
		return

	d1.modulate.a = 0.2
	d2.modulate.a = 0.2
	d3.modulate.a = 0.2

	_typing_dots_tween = create_tween().set_loops()
	_typing_dots_tween.tween_property(d1, "modulate:a", 1.0, 0.22)
	_typing_dots_tween.tween_property(d2, "modulate:a", 1.0, 0.22)
	_typing_dots_tween.tween_property(d3, "modulate:a", 1.0, 0.22)
	_typing_dots_tween.tween_property(d1, "modulate:a", 0.2, 0.22)
	_typing_dots_tween.tween_property(d2, "modulate:a", 0.2, 0.22)
	_typing_dots_tween.tween_property(d3, "modulate:a", 0.2, 0.22)

func _detener_animacion_typing_dots() -> void:
	if _typing_dots_tween and _typing_dots_tween.is_valid():
		_typing_dots_tween.kill()
		_typing_dots_tween = null

func _agregar_tarjeta_elevacion_impacto(area: String, motivo: String) -> void:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 140)

	# Estilo Glassmorphic Dorado / Ámbar Neón de Alta Jerarquía
	var card_st = StyleBoxFlat.new()
	card_st.bg_color = Color(0.14, 0.09, 0.03, 0.96)
	card_st.border_width_left = 3
	card_st.border_width_top = 3
	card_st.border_width_right = 3
	card_st.border_width_bottom = 3
	card_st.border_color = Color(1.0, 0.78, 0.15, 1.0)
	card_st.shadow_color = Color(1.0, 0.70, 0.10, 0.50)
	card_st.shadow_size = 24
	card_st.corner_radius_top_left = 16
	card_st.corner_radius_top_right = 16
	card_st.corner_radius_bottom_left = 16
	card_st.corner_radius_bottom_right = 16
	card_st.content_margin_left = 26
	card_st.content_margin_right = 26
	card_st.content_margin_top = 18
	card_st.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	# Fila 1: Badge de Elevación & Prioridad
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)

	var icon_badge = Label.new()
	icon_badge.text = "⚡ CASO ELEVADO A ESPECIALISTAS"
	icon_badge.add_theme_font_size_override("font_size", 24)
	icon_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	if _font_moderniz: icon_badge.add_theme_font_override("font", _font_moderniz)
	row1.add_child(icon_badge)

	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp)

	var tag_prio = Label.new()
	tag_prio.text = "⭐ PRIORIDAD TÉCNICA ACTIVA"
	tag_prio.add_theme_font_size_override("font_size", 19)
	tag_prio.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0, 1.0))
	if _font_moderniz: tag_prio.add_theme_font_override("font", _font_moderniz)
	row1.add_child(tag_prio)
	vb.add_child(row1)

	# Fila 2: Nombre del Departamento
	var dept_lbl = Label.new()
	dept_lbl.text = "🏛️ Departamento: " + area
	dept_lbl.add_theme_font_size_override("font_size", 30)
	dept_lbl.add_theme_color_override("font_color", Color.WHITE)
	if _font_moderniz: dept_lbl.add_theme_font_override("font", _font_moderniz)
	vb.add_child(dept_lbl)

	# Fila 3: Motivo / Causa si está especificado
	if motivo.strip_edges() != "":
		var mot_lbl = Label.new()
		mot_lbl.text = "📋 Motivo de transferencia: " + motivo
		mot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mot_lbl.add_theme_font_size_override("font_size", 24)
		mot_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.95))
		vb.add_child(mot_lbl)

	# Fila 4: Subtexto informativo tranquilizador
	var sub_lbl = Label.new()
	sub_lbl.text = "Un especialista asignado con permisos técnicos ha tomado control del ticket."
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 20)
	sub_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85, 0.85))
	vb.add_child(sub_lbl)

	card.add_child(vb)
	_messages_vbox.add_child(card)

	# Animación de Entrada con Alto Impacto Visual (Spring bounce + HDR Flash)
	card.modulate = Color(2.5, 2.2, 1.0, 0.0)
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = Vector2(500, 70)
	var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.35)

func _agregar_burbuja_asistente_ia(area: String, mensaje: String) -> void:
	var bubble = PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bubble.custom_minimum_size = Vector2(580, 0)

	# Estilo Glassmorphic Cyberpunk Neón Púrpura / Cyan
	var b_st = StyleBoxFlat.new()
	b_st.bg_color = Color(0.12, 0.08, 0.24, 0.95)
	b_st.border_width_left = 3
	b_st.border_width_top = 3
	b_st.border_width_right = 3
	b_st.border_width_bottom = 3
	b_st.border_color = Color(0.72, 0.38, 1.0, 1.0)
	b_st.shadow_color = Color(0.60, 0.20, 1.0, 0.45)
	b_st.shadow_size = 28
	b_st.corner_radius_top_left = 16
	b_st.corner_radius_top_right = 16
	b_st.corner_radius_bottom_left = 4
	b_st.corner_radius_bottom_right = 16
	b_st.content_margin_left = 24
	b_st.content_margin_right = 24
	b_st.content_margin_top = 18
	b_st.content_margin_bottom = 18
	bubble.add_theme_stylebox_override("panel", b_st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	var header_h = HBoxContainer.new()
	header_h.add_theme_constant_override("separation", 12)

	var tag = Label.new()
	tag.text = "🤖 ASISTENTE IA NT • " + area.to_upper()
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(0.85, 0.60, 1.0, 1.0))
	if _font_moderniz: tag.add_theme_font_override("font", _font_moderniz)
	header_h.add_child(tag)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_h.add_child(spacer)

	var badge = Label.new()
	badge.text = "⚡ CONTEXTO ANALIZADO"
	badge.add_theme_font_size_override("font_size", 17)
	badge.add_theme_color_override("font_color", Color(0.35, 0.95, 0.80, 1.0))
	if _font_moderniz: badge.add_theme_font_override("font", _font_moderniz)
	header_h.add_child(badge)
	vb.add_child(header_h)

	var body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _formatear_bbcode_negritas(mensaje)
	body.add_theme_font_size_override("normal_font_size", 26)
	body.add_theme_font_size_override("bold_font_size", 26)
	body.add_theme_color_override("default_color", Color(0.96, 0.96, 1.0, 1.0))
	vb.add_child(body)

	bubble.add_child(vb)
	_messages_vbox.add_child(bubble)
	_animar_aparicion_burbuja(bubble, false)
	_scroll_to_bottom()

func _reproducir_sonido(ruta: String) -> void:
	if not _audio_player:
		return
	var s = load(ruta) as AudioStream
	if s:
		_audio_player.stream = s
		_audio_player.play()

func _desatascar_jugador_y_vehiculo() -> void:
	var tree = get_tree()
	if not tree:
		return
	var player = tree.get_first_node_in_group("Jugador")
	if player is Node3D:
		player.global_position.y += 2.5
	var coche = tree.get_first_node_in_group("coche")
	if coche:
		if coche.has_method("desvolcar"):
			coche.desvolcar()
		elif coche is Node3D:
			coche.global_position.y += 3.0
			coche.rotation_degrees = Vector3(0, coche.rotation_degrees.y, 0)

func _aplicar_bonificacion_jugador(amount: int) -> void:
	var DU = get_node_or_null("/root/DatosUsuario")
	if DU and "dinero" in DU:
		DU.dinero += amount
		if DU.has_method("guardar_datos"):
			DU.guardar_datos()

func _agregar_tarjeta_asistencia_mecanica(staff: String) -> void:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 130)

	var card_st = StyleBoxFlat.new()
	card_st.bg_color = Color(0.04, 0.12, 0.22, 0.96)
	card_st.border_width_left = 3; card_st.border_width_top = 3
	card_st.border_width_right = 3; card_st.border_width_bottom = 3
	card_st.border_color = Color(0.25, 0.85, 1.0, 1.0)
	card_st.shadow_color = Color(0.15, 0.75, 1.0, 0.45)
	card_st.shadow_size = 20
	for c in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		card_st.set("corner_radius_" + c, 16)
	card_st.content_margin_left = 24; card_st.content_margin_right = 24
	card_st.content_margin_top = 16; card_st.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)

	var tit = Label.new()
	tit.text = "🚜  ASISTENCIA MECÁNICA EN CAMINO"
	tit.add_theme_font_size_override("font_size", 26)
	tit.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0, 1.0))
	if _font_moderniz: tit.add_theme_font_override("font", _font_moderniz)
	vb.add_child(tit)

	var sub = Label.new()
	sub.text = "El especialista " + staff + " ha activado la grúa satelital remota.\nTu vehículo ha sido enderezado, estabilizado y posicionado en la calzada de forma segura."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", C_TEXT_MAIN)
	vb.add_child(sub)

	card.add_child(vb)
	_messages_vbox.add_child(card)

	card.modulate = Color(2.0, 2.5, 3.0, 0.0)
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = Vector2(500, 65)
	var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.35)
	_scroll_to_bottom()

func _agregar_tarjeta_compensacion(staff: String, amount: int, reason: String) -> void:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 140)

	var card_st = StyleBoxFlat.new()
	card_st.bg_color = Color(0.04, 0.20, 0.12, 0.96)
	card_st.border_width_left = 3; card_st.border_width_top = 3
	card_st.border_width_right = 3; card_st.border_width_bottom = 3
	card_st.border_color = Color(0.20, 0.95, 0.55, 1.0)
	card_st.shadow_color = Color(0.15, 0.95, 0.50, 0.45)
	card_st.shadow_size = 22
	for c in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		card_st.set("corner_radius_" + c, 16)
	card_st.content_margin_left = 24; card_st.content_margin_right = 24
	card_st.content_margin_top = 16; card_st.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)

	var tit_h = HBoxContainer.new()
	var tit = Label.new()
	tit.text = "🎁  BONIFICACIÓN DE CORTESÍA ACREDITADA"
	tit.add_theme_font_size_override("font_size", 25)
	tit.add_theme_color_override("font_color", Color(0.25, 0.98, 0.60, 1.0))
	if _font_moderniz: tit.add_theme_font_override("font", _font_moderniz)
	tit_h.add_child(tit)
	vb.add_child(tit_h)

	var amount_lbl = Label.new()
	amount_lbl.text = "+$" + _formatear_numero(amount) + " COP"
	amount_lbl.add_theme_font_size_override("font_size", 34)
	amount_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))
	if _font_moderniz: amount_lbl.add_theme_font_override("font", _font_moderniz)
	vb.add_child(amount_lbl)

	var sub = Label.new()
	sub.text = reason + "\nAutorizado oficialmente por: " + staff + " • Saldo sumado a tu cuenta."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 21)
	sub.add_theme_color_override("font_color", C_TEXT_MAIN)
	vb.add_child(sub)

	card.add_child(vb)
	_messages_vbox.add_child(card)

	card.modulate = Color(1.5, 3.0, 1.5, 0.0)
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = Vector2(500, 70)
	var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.35)
	_scroll_to_bottom()

func _mostrar_tarjeta_calificacion_servicio() -> void:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 150)

	var card_st = StyleBoxFlat.new()
	card_st.bg_color = Color(0.12, 0.10, 0.18, 0.96)
	card_st.border_width_left = 2; card_st.border_width_top = 2
	card_st.border_width_right = 2; card_st.border_width_bottom = 2
	card_st.border_color = Color(0.8, 0.65, 1.0, 0.85)
	for c in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		card_st.set("corner_radius_" + c, 16)
	card_st.content_margin_left = 24; card_st.content_margin_right = 24
	card_st.content_margin_top = 18; card_st.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	var tit = Label.new()
	tit.text = "⭐ ¿CÓMO CALIFICARÍAS LA ATENCIÓN RECIBIDA?"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 24)
	tit.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30, 1.0))
	if _font_moderniz: tit.add_theme_font_override("font", _font_moderniz)
	vb.add_child(tit)

	var sub = Label.new()
	sub.text = "Selecciona una valoración para enviar a Discord y calificar a tu moderador:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", C_TEXT_DIM)
	vb.add_child(sub)

	var stars_hbox = HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_hbox.add_theme_constant_override("separation", 14)

	var buttons_array = []
	for i in range(1, 6):
		var star_btn = Button.new()
		star_btn.text = "⭐ " + str(i)
		star_btn.custom_minimum_size = Vector2(95, 55)
		star_btn.add_theme_font_size_override("font_size", 22)
		var st = _crear_estilo_boton(Color(0.20, 0.16, 0.28, 0.95), Color(0.8, 0.65, 1.0), 10)
		star_btn.add_theme_stylebox_override("normal", st)
		var st_h = _crear_estilo_boton(Color(0.35, 0.28, 0.50, 0.95), Color.WHITE, 10)
		star_btn.add_theme_stylebox_override("hover", st_h)
		
		var rating_val = i
		star_btn.pressed.connect(func():
			for b in buttons_array:
				if is_instance_valid(b):
					b.disabled = true
			sub.text = "¡Muchas gracias! Has valorado la atención con " + str(rating_val) + "/5 estrellas."
			sub.add_theme_color_override("font_color", Color(0.3, 0.95, 0.6))
			_reproducir_sonido("res://recursos/efectos/seleccion1.mp3")
			_enviar_ws({
				"action": "ticket_feedback",
				"ticket_id": _active_ticket_id,
				"rating": rating_val
			})
		)
		buttons_array.append(star_btn)
		stars_hbox.add_child(star_btn)

	vb.add_child(stars_hbox)
	card.add_child(vb)
	_messages_vbox.add_child(card)

	card.modulate.a = 0.0
	card.scale = Vector2(0.9, 0.9)
	card.pivot_offset = Vector2(500, 70)
	var tw = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.3)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.3)
	_scroll_to_bottom()

# ─── GESTIÓN DE VISTAS Y ESTILOS ──────────────────────────────────────────────

func _mostrar_vista_formulario() -> void:
	_detener_animacion_typing_dots()
	if is_instance_valid(_typing_indicator_box):
		_typing_indicator_box.visible = false
	_form_scroll.visible = true
	_chat_container.visible = false
	_create_btn.disabled = false
	_create_btn.text = "🚀  ABRIR TICKET EN DISCORD"
	_desc_text.text = ""
	_active_ticket_id = ""
	_staff_assigned_name = ""
	_is_ticket_open = false
	_limpiar_mensajes_chat()

func _mostrar_vista_chat() -> void:
	_form_scroll.visible = false
	_chat_container.visible = true
	_msg_input.editable = true
	_send_btn.disabled = false
	_close_ticket_btn.text = "FINALIZAR TICKET"

func _actualizar_indicador_red(texto: String, color: Color) -> void:
	if _status_btn and _last_network_indicator_text != texto:
		_last_network_indicator_text = texto
		_status_btn.text = texto
		_status_btn.add_theme_color_override("font_color", color)

func _animar_entrada() -> void:
	modulate.a = 0.0
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

func _crear_estilo_boton(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var st = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_width_left = 2
	st.border_width_top = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.border_color = border
	st.corner_radius_top_left = radius
	st.corner_radius_top_right = radius
	st.corner_radius_bottom_left = radius
	st.corner_radius_bottom_right = radius
	return st

func _crear_estilo_caja_texto() -> StyleBoxFlat:
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	st.border_width_left = 2
	st.border_width_top = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.border_color = Color(0.20, 0.40, 0.65, 0.8)
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	return st
