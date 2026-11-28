extends Control

# ═══════════════════════════════════════════════════════════════════════
# LobbyMultijugadorModerno.gd — Sala de Espera Multijugador LAN/Online
# ═══════════════════════════════════════════════════════════════════════

const FONT = preload("res://recursos/fonts/Moderniz.otf")
const MAIN_MENU_SCENE = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const MAIN_MENU_FALLBACK = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const GAME_SCENE = "res://mundo/principal/PrincipalMultijugador.tscn"
const EDITOR_MAPAS_SCENE = "res://mundo/editor_mapas/EditorMapas.tscn"
const HUB_MAPAS_SCENE = "res://mundo/editor_mapas/HubEditorMapas.tscn"
const RepositorioComunidad = preload("res://mundo/editor_mapas/RepositorioMapasComunidad.gd")
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
var _mapa_ruta: String = ""
var _mapa_nombre: String = ""
var _repo_comunidad: Node = null
var _modal_comprar_mapa: CanvasLayer = null

func _ready() -> void:
	_mapa_ruta = str(Engine.get_meta("nt_mp_mapa_ruta", ""))
	_mapa_nombre = str(Engine.get_meta("nt_mp_mapa_nombre", ""))
	var auto_crear := bool(Engine.get_meta("nt_mp_auto_crear_sala", false))
	Engine.set_meta("nt_mp_auto_crear_sala", false)
	if _mapa_nombre != "" and is_instance_valid(lbl_subtitulo):
		lbl_subtitulo.text = "MAPA SELECCIONADO: " + _mapa_nombre.to_upper()
	elif is_instance_valid(lbl_subtitulo):
		lbl_subtitulo.text = "UNETE A UNA SALA ACTIVA • CREA SALAS DESDE EL CENTRO DE MAPAS"
	option_cupos.clear()
	option_cupos.add_item("2 CONDUCTORES", 2)
	option_cupos.add_item("3 CONDUCTORES", 3)
	option_cupos.add_item("4 CONDUCTORES", 4)
	option_cupos.add_item("5 CONDUCTORES (MÁX)", 5)
	option_cupos.selected = 3

	var mi_ip = network.get_ip_address() if network else "127.0.0.1"
	badge_ip.text = "WEBRTC P2P • " + mi_ip
	lbl_status.text = "CONECTANDO AL SERVIDOR DE SEÑALIZACIÓN WEBRTC..."
	btn_unirse_ip.text = "UNIRSE POR CÓDIGO"
	input_puerto.visible = false

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
	# Solo se permite crear sala cuando se entra desde un mapa en el Centro de Mapas
	btn_crear_sala.visible = (_mapa_ruta != "" or _mapa_nombre != "")

	if network:
		if not network.salas_lan_actualizadas.is_connected(_on_salas_actualizadas):
			network.salas_lan_actualizadas.connect(_on_salas_actualizadas)
		if not network.lista_jugadores_actualizada.is_connected(_on_jugadores_actualizados):
			network.lista_jugadores_actualizada.connect(_on_jugadores_actualizados)
		if not network.sala_creada_exito.is_connected(_on_sala_creada_exito):
			network.sala_creada_exito.connect(_on_sala_creada_exito)
		if not network.conectado_a_sala.is_connected(_on_conectado_exito):
			network.conectado_a_sala.connect(_on_conectado_exito)
		if not network.error_red.is_connected(_on_error_red):
			network.error_red.connect(_on_error_red)
		if network.has_signal("estado_senalizacion_cambiado") and not network.estado_senalizacion_cambiado.is_connected(_on_estado_senalizacion):
			network.estado_senalizacion_cambiado.connect(_on_estado_senalizacion)
		if auto_crear and (_mapa_nombre != "" or _mapa_ruta != ""):
			var datos = get_node_or_null("/root/DatosUsuario")
			var usr := String(datos.nombre_usuario).to_upper() if datos and "nombre_usuario" in datos else "CONDUCTOR"
			var nombre_sala := (_mapa_nombre.to_upper() + " • " + usr) if _mapa_nombre != "" else ("CONVOY DE " + usr)
			lbl_status.text = "CREANDO SALA AUTOMÁTICAMENTE PARA '%s'..." % _mapa_nombre.to_upper()
			lbl_status.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
			network.conectar_senalizacion()
			network.crear_sala_webrtc(nombre_sala, MAX_JUGADORES, _mapa_nombre, _mapa_ruta)
		else:
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

func _on_estado_senalizacion(conectado: bool, mensaje: String) -> void:
	if network and network.current_room_code != "":
		return
	lbl_status.text = mensaje
	lbl_status.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95) if conectado else Color(0.95, 0.55, 0.25))

func _on_crear_sala_abrir() -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	var usr = String(datos.nombre_usuario).to_upper() if datos and "nombre_usuario" in datos else "CONDUCTOR"
	input_nombre_sala.text = (_mapa_nombre.to_upper() + " • " + usr) if _mapa_nombre != "" else ("CONVOY DE " + usr)
	_mostrar_modal_suave(modal_crear)

func _on_crear_sala_confirmar() -> void:
	var max_p = option_cupos.get_item_id(option_cupos.selected)
	max_p = clampi(max_p if max_p > 0 else MAX_JUGADORES, 2, MAX_JUGADORES)
	var nombre = input_nombre_sala.text.strip_edges()
	modal_crear.visible = false

	lbl_status.text = "CREANDO SALA EN SERVIDOR WEBRTC..."
	lbl_status.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
	var datos = get_node_or_null("/root/DatosUsuario")
	if players_manager and datos and "nombre_usuario" in datos:
		players_manager.player_name = datos.nombre_usuario

	if network:
		network.crear_sala_webrtc(nombre, max_p, _mapa_nombre, _mapa_ruta)

func _on_sala_creada_exito(info: Dictionary) -> void:
	var code := String(info.get("room_code", ""))
	var nombre := String(info.get("room_name", "SALA P2P"))
	var max_p := int(info.get("max_players", MAX_JUGADORES))
	lbl_titulo.text = nombre.to_upper()
	lbl_status.text = "SALA WEBRTC ACTIVA • CÓDIGO: %s • CUPO: %d" % [code, max_p]
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
	input_ip.text = ""
	input_ip.placeholder_text = "CÓDIGO DE SALA (EJ: A7K9P2)"
	_mostrar_modal_suave(modal_unirse)

func _on_unirse_ip_confirmar() -> void:
	var code = input_ip.text.strip_edges().to_upper()
	if code == "":
		lbl_status.text = "INGRESA EL CÓDIGO DE LA SALA WEBRTC"
		lbl_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.2))
		return

	modal_unirse.visible = false
	lbl_status.text = "CONECTANDO P2P A SALA %s..." % code
	lbl_status.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))

	if network:
		network.unirse_sala_webrtc(code)

func _mostrar_modal_suave(modal: Control) -> void:
	modal.visible = true
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.92, 0.92)
	modal.pivot_offset = modal.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(modal, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

	var m_name: String = String(network.current_map_name) if network else ""
	if m_name != "" and m_name.to_lower() != "principal":
		lbl_subtitulo.text = "MAPA DE LA SALA: " + m_name.to_upper()
		var ruta_local: String = String(network._resolver_ruta_mapa_local("", m_name)) if network else ""
		if ruta_local == "":
			_mostrar_modal_comprar_mapa(m_name)

func _cerrar_modal_comprar_mapa() -> void:
	if is_instance_valid(_modal_comprar_mapa):
		_modal_comprar_mapa.queue_free()
		_modal_comprar_mapa = null

func _mostrar_modal_comprar_mapa(nombre_mapa: String) -> void:
	_cerrar_modal_comprar_mapa()
	if not is_instance_valid(_repo_comunidad):
		_repo_comunidad = RepositorioComunidad.new()
		add_child(_repo_comunidad)

	var capa := CanvasLayer.new()
	capa.layer = 130
	add_child(capa)
	_modal_comprar_mapa = capa

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.02, 0.03, 0.04, 0.82)
	capa.add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.95)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.81, 0.85, 0.25)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 32)
	mc.add_theme_constant_override("margin_right", 32)
	mc.add_theme_constant_override("margin_top", 28)
	mc.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(mc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	mc.add_child(vb)

	var lbl_t := Label.new()
	lbl_t.text = "MAPA REQUERIDO"
	lbl_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_t.add_theme_font_override("font", FONT)
	lbl_t.add_theme_font_size_override("font_size", 32)
	lbl_t.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.98))
	vb.add_child(lbl_t)

	var lbl_msg := Label.new()
	lbl_msg.text = "Debes adquirir este mapa para poder jugar:\n" + nombre_mapa.to_upper()
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 22)
	lbl_msg.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 0.95))
	vb.add_child(lbl_msg)

	var lbl_info_compra := Label.new()
	lbl_info_compra.text = ""
	lbl_info_compra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info_compra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_info_compra.add_theme_font_size_override("font_size", 18)
	lbl_info_compra.add_theme_color_override("font_color", Color(0.95, 0.55, 0.25))
	vb.add_child(lbl_info_compra)

	var btn_comprar := Button.new()
	btn_comprar.text = "COMPRAR MAPA (%d ESMERALDAS)" % RepositorioComunidad.PRECIO_DESCARGA_ESMERALDAS
	btn_comprar.custom_minimum_size = Vector2(0, 60)
	_aplicar_estilo_boton(btn_comprar, Color(0.88, 0.68, 0.28), 22)
	btn_comprar.pressed.connect(func():
		btn_comprar.disabled = true
		btn_comprar.text = "BUSCANDO MAPA EN TIENDA..."
		lbl_info_compra.text = ""
		_repo_comunidad.buscar_mapa_por_nombre_async(nombre_mapa, func(item: Dictionary):
			if not is_instance_valid(btn_comprar):
				return
			if item.is_empty():
				btn_comprar.disabled = false
				btn_comprar.text = "COMPRAR MAPA (%d ESMERALDAS)" % RepositorioComunidad.PRECIO_DESCARGA_ESMERALDAS
				lbl_info_compra.text = "Este mapa es privado o aún no está publicado en Descubrir."
				return
			btn_comprar.text = "DESCARGANDO MAPA..."
			_repo_comunidad.descargar_y_preparar_async(item, func(res: Dictionary):
				if not is_instance_valid(btn_comprar):
					return
				if res.get("exito", false):
					lbl_status.text = "¡MAPA ADQUIRIDO! LISTO PARA JUGAR."
					lbl_status.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
					_cerrar_modal_comprar_mapa()
				else:
					btn_comprar.disabled = false
					btn_comprar.text = "COMPRAR MAPA (%d ESMERALDAS)" % RepositorioComunidad.PRECIO_DESCARGA_ESMERALDAS
					lbl_info_compra.text = str(res.get("mensaje", "No se pudo completar la compra."))
			)
		)
	)
	vb.add_child(btn_comprar)

	var btn_salir_modal := Button.new()
	btn_salir_modal.text = "SALIR DE LA SALA"
	btn_salir_modal.custom_minimum_size = Vector2(0, 52)
	_aplicar_estilo_boton(btn_salir_modal, Color(0.78, 0.28, 0.26), 20)
	btn_salir_modal.pressed.connect(func():
		_cerrar_modal_comprar_mapa()
		_on_salir_sala_pressed()
	)
	vb.add_child(btn_salir_modal)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = Vector2(360, 170)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_error_red(msg: String) -> void:
	lbl_status.text = msg
	lbl_status.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	panel_salas.visible = true
	panel_jugadores.visible = false
	btn_iniciar.visible = false
	btn_salir.visible = false
	# Solo se permite crear sala cuando se entra desde un mapa en el Centro de Mapas
	btn_crear_sala.visible = (_mapa_ruta != "" or _mapa_nombre != "")
	btn_unirse_ip.visible = true

func _on_salas_actualizadas(salas: Array) -> void:
	_salas_cache = salas
	_renderizar_salas()

func _renderizar_salas() -> void:
	for c in lista_salas.get_children():
		c.queue_free()

	var header = Label.new()
	header.text = "SALAS DISPONIBLES EN SERVIDOR WEBRTC P2P"
	header.add_theme_font_override("font", FONT)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
	lista_salas.add_child(header)

	if _salas_cache.is_empty():
		var empty = Label.new()
		empty.text = "No hay salas públicas abiertas en el servidor WebRTC actualmente.\nPresiona 'CREAR SALA' para ser Host o 'UNIRSE POR CÓDIGO'."
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
	name_lbl.text = "🚛 " + String(s.get("name", "SALA WEBRTC")).to_upper()
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))

	var info_lbl = Label.new()
	var code = String(s.get("code", ""))
	var host_name = String(s.get("host_name", "Anfitrión")).to_upper()
	var m_name = String(s.get("map_name", "Principal")).to_upper()
	var players = int(s.get("players", 1))
	var max_p = int(s.get("max_players", 5))
	info_lbl.text = "MAPA: %s • HOST: %s • CÓDIGO: %s • %d/%d" % [m_name, host_name, code, players, max_p]
	info_lbl.add_theme_font_size_override("font_size", 16)
	info_lbl.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.92))

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
			lbl_status.text = "CONECTANDO P2P A SALA %s..." % code
			network.unirse_sala_webrtc(code)
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

	var mi_id = multiplayer.get_unique_id() if (is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer()) else 1
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
	var escena := EDITOR_MAPAS_SCENE if (_mapa_ruta != "" or _mapa_nombre != "") else GAME_SCENE
	if network and network.is_host:
		lbl_status.text = "CARGANDO MAPA MULTIJUGADOR..."
		network.iniciar_partida_multijugador(escena, _mapa_nombre, _mapa_ruta)
	else:
		get_tree().change_scene_to_file(escena)

func _on_salir_sala_pressed() -> void:
	_cerrar_modal_comprar_mapa()
	if network:
		network.cerrar_conexion()
		network.iniciar_escucha_lan()

	lbl_titulo.text = "CONVOY MULTIJUGADOR"
	lbl_status.text = "BUSCANDO SALAS EN SERVIDOR WEBRTC P2P..."
	panel_salas.visible = true
	panel_jugadores.visible = false
	btn_iniciar.visible = false
	btn_salir.visible = false
	# Solo se permite crear sala cuando se entra desde un mapa en el Centro de Mapas
	btn_crear_sala.visible = (_mapa_ruta != "" or _mapa_nombre != "")
	btn_unirse_ip.visible = true
	_renderizar_salas()

func _on_volver_pressed() -> void:
	if network:
		network.detener_escucha_lan()
		network.cerrar_conexion()
	var venia_de_mapa := (_mapa_ruta != "" or _mapa_nombre != "")
	Engine.set_meta("nt_mp_mapa_ruta", "")
	Engine.set_meta("nt_mp_mapa_nombre", "")
	if venia_de_mapa and ResourceLoader.exists(HUB_MAPAS_SCENE):
		get_tree().change_scene_to_file(HUB_MAPAS_SCENE)
		return
	var dest = MAIN_MENU_SCENE if ResourceLoader.exists(MAIN_MENU_SCENE) else MAIN_MENU_FALLBACK
	get_tree().change_scene_to_file(dest)
