extends Node3D
class_name ZonaCargaInteractiva

## ZonaCargaInteractiva.gd
## Selector de mercancías en Punto de Carga (requiere tráiler acoplado o en bahía)
## y confirmación de entrega en Punto de Descarga, con barra de progreso animada,
## estilo glassmorphic sobrio y activación únicamente al detenerse el vehículo.

const FUENTE_TITULO := "res://recursos/fonts/creato_display/CreatoDisplay-Bold.otf"
const FUENTE_CUERPO := "res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf"
const RUTA_IMAGEN_EXITO := "res://recursos/ui/logistica_exito.jpg"

const COL_FONDO := Color(0.06, 0.07, 0.08, 0.78)
const COL_CARD := Color(0.09, 0.10, 0.12, 0.68)
const COL_BORDE := Color(0.78, 0.81, 0.85, 0.16)
const COL_ACENTO := Color(0.88, 0.68, 0.28, 0.78)
const COL_CERRAR := Color(0.78, 0.28, 0.26, 0.70)

const CATALOGO_CARGAS := [
	{
		"id": "cafe_exportacion",
		"nombre": "Café de Exportación",
		"detalle": "Sacos en estibas · Carga frágil",
		"icono": "☕",
		"peso_kg": 18500,
		"pago": 4200
	},
	{
		"id": "material_construccion",
		"nombre": "Material de Construcción",
		"detalle": "Palés de bloque, cemento y acero",
		"icono": "🧱",
		"peso_kg": 24000,
		"pago": 5100
	},
	{
		"id": "contenedor_general",
		"nombre": "Contenedor General 40'",
		"detalle": "Contenedor marítimo de carga seca",
		"icono": "📦",
		"peso_kg": 21000,
		"pago": 4600
	},
	{
		"id": "maquinaria_pesada",
		"nombre": "Maquinaria Pesada",
		"detalle": "Equipo industrial sobre plataforma",
		"icono": "🚜",
		"peso_kg": 32000,
		"pago": 6800
	},
]

@export var es_descarga: bool = false

var _area: Area3D = null
var _ui_layer: CanvasLayer = null
var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _lbl_estado: Label = null
var _badge_estado: Label = null
var _barra_progreso: ProgressBar = null
var _lbl_progreso: Label = null
var _box_progreso: VBoxContainer = null
var _tarjetas: Array[PanelContainer] = []
var _botones_accion: Array[Button] = []
var _entidades_dentro: Array[Node] = []
var _panel_mostrado_en_parada: bool = false
var _en_proceso: bool = false
var _es_fantasma: bool = false


func _ready() -> void:
	var p: Node = get_parent()
	while p:
		if "Preview" in p.name or "Fantasma" in p.name:
			_es_fantasma = true
			return
		p = p.get_parent()

	_crear_area_deteccion()


func _process(_delta: float) -> void:
	if _es_fantasma or _entidades_dentro.is_empty() or not _en_modo_juego():
		return
	if _entidad_detenida_en_zona() and not _panel_mostrado_en_parada:
		_panel_mostrado_en_parada = true
		_mostrar_ui()


func _entidad_detenida_en_zona() -> bool:
	for e in _entidades_dentro:
		if not is_instance_valid(e):
			continue
		if e is RigidBody3D:
			if (e as RigidBody3D).linear_velocity.length() < 0.6:
				return true
		elif e is CharacterBody3D:
			if (e as CharacterBody3D).velocity.length() < 0.6:
				return true
		else:
			return true
	return false


func _crear_area_deteccion() -> void:
	_area = Area3D.new()
	_area.name = "AreaCargaInteractiva"
	_area.monitoring = true
	_area.monitorable = false
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.8, 3.8, 9.8)
	col.shape = box
	col.position = Vector3(0.0, 1.9, 0.0)
	_area.add_child(col)
	add_child(_area)

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _en_modo_juego() -> bool:
	var mp := get_tree().root.find_child("ModoPrueba", true, false)
	if mp and "en_prueba" in mp:
		return bool(mp.get("en_prueba"))
	var ed := get_tree().root.find_child("EditorMapas", true, false)
	if ed != null:
		return false
	return true


func _es_entidad_jugador(body: Node) -> bool:
	if not is_instance_valid(body):
		return false
	if body.is_in_group("jugador") or "jugador" in body.name.to_lower():
		return true
	if body is RigidBody3D and "activo" in body and bool(body.get("activo")):
		return true
	return false


func _on_body_entered(body: Node) -> void:
	if _es_fantasma or not _en_modo_juego():
		return
	if not _es_entidad_jugador(body):
		return
	if not _entidades_dentro.has(body):
		_entidades_dentro.append(body)


func _on_body_exited(body: Node) -> void:
	_entidades_dentro.erase(body)
	if _entidades_dentro.is_empty():
		_panel_mostrado_en_parada = false
		if not _en_proceso:
			_ocultar_ui()


func _mostrar_ui() -> void:
	if not _ui_layer:
		_construir_ui()
	_actualizar_texto_estado()
	_ui_layer.visible = true
	if is_instance_valid(_backdrop):
		_backdrop.modulate.a = 0.0
		create_tween().tween_property(_backdrop, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_panel):
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.90, 0.90)
		_panel.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in range(_tarjetas.size()):
		var c := _tarjetas[i]
		if not is_instance_valid(c):
			continue
		c.modulate.a = 0.0
		var tw_c := create_tween()
		tw_c.tween_interval(0.05 * float(i + 1))
		tw_c.tween_property(c, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _ocultar_ui(forzar: bool = false) -> void:
	if (_en_proceso and not forzar) or not is_instance_valid(_ui_layer) or not _ui_layer.visible:
		return
	if is_instance_valid(_panel):
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_panel, "scale", Vector2(0.94, 0.94), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_panel, "modulate:a", 0.0, 0.16)
		if is_instance_valid(_backdrop):
			tw.tween_property(_backdrop, "modulate:a", 0.0, 0.16)
		tw.chain().tween_callback(func():
			if is_instance_valid(_ui_layer):
				_ui_layer.visible = false
		)
	else:
		_ui_layer.visible = false


func _actualizar_texto_estado() -> void:
	if not _lbl_estado:
		return
	var carga_act: Dictionary = {}
	if get_tree().root.has_meta("carga_activa_mapa"):
		carga_act = get_tree().root.get_meta("carga_activa_mapa") as Dictionary

	if es_descarga:
		if carga_act.is_empty():
			if _badge_estado:
				_badge_estado.text = "SIN CARGA"
			_lbl_estado.text = "No llevas mercancía activa. Dirígete primero a un Punto de Carga con un tráiler."
		else:
			if _badge_estado:
				_badge_estado.text = "LISTO"
			_lbl_estado.text = "Mercancía a bordo: %s (%d t) · Pago: $%d" % [
				str(carga_act.get("nombre", "Carga")),
				int(round(float(carga_act.get("peso_kg", 0)) / 1000.0)),
				int(carga_act.get("pago", 0))
			]
	else:
		var trailer := _buscar_trailer_objetivo()
		if not trailer:
			if _badge_estado:
				_badge_estado.text = "SIN TRÁILER"
			_lbl_estado.text = "Necesitas un tráiler acoplado o estacionado en esta zona para poder cargar."
		elif carga_act.is_empty():
			if _badge_estado:
				_badge_estado.text = "DISPONIBLE"
			_lbl_estado.text = "Tráiler listo. Selecciona la mercancía para iniciar la carga:"
		else:
			if _badge_estado:
				_badge_estado.text = "CARGADO"
			_lbl_estado.text = "Llevas %s (%d t). Puedes reemplazarla si lo deseas:" % [
				str(carga_act.get("nombre", "Carga")),
				int(round(float(carga_act.get("peso_kg", 0)) / 1000.0))
			]


func _construir_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 45
	add_child(_ui_layer)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.03, 0.04, 0.34)
	_ui_layer.add_child(_backdrop)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(centro)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FONDO
	sb.set_border_width_all(1)
	sb.border_color = COL_BORDE
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 20
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", sb)
	centro.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var fuente_tit: Font = load(FUENTE_TITULO) if ResourceLoader.exists(FUENTE_TITULO) else null
	var fuente_cuerpo: Font = load(FUENTE_CUERPO) if ResourceLoader.exists(FUENTE_CUERPO) else fuente_tit

	var hbox_head := HBoxContainer.new()
	hbox_head.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox_head)

	var lbl_tit := Label.new()
	lbl_tit.text = "PUNTO DE DESCARGA" if es_descarga else "CENTRO DE CARGA"
	lbl_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_tit.add_theme_font_size_override("font_size", 26)
	lbl_tit.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 0.98))
	if fuente_tit:
		lbl_tit.add_theme_font_override("font", fuente_tit)
	hbox_head.add_child(lbl_tit)

	_badge_estado = Label.new()
	_badge_estado.text = "DISPONIBLE"
	_badge_estado.add_theme_font_size_override("font_size", 14)
	_badge_estado.add_theme_color_override("font_color", COL_ACENTO)
	if fuente_tit:
		_badge_estado.add_theme_font_override("font", fuente_tit)
	hbox_head.add_child(_badge_estado)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.14)
	vbox.add_child(sep)

	_lbl_estado = Label.new()
	_lbl_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_estado.add_theme_font_size_override("font_size", 17)
	_lbl_estado.add_theme_color_override("font_color", Color(0.76, 0.80, 0.85, 0.92))
	if fuente_cuerpo:
		_lbl_estado.add_theme_font_override("font", fuente_cuerpo)
	vbox.add_child(_lbl_estado)

	# Barra de progreso de carga / descarga
	_box_progreso = VBoxContainer.new()
	_box_progreso.visible = false
	_box_progreso.add_theme_constant_override("separation", 6)
	vbox.add_child(_box_progreso)

	_lbl_progreso = Label.new()
	_lbl_progreso.text = "Procesando... 0%"
	_lbl_progreso.add_theme_font_size_override("font_size", 15)
	_lbl_progreso.add_theme_color_override("font_color", COL_ACENTO)
	if fuente_tit:
		_lbl_progreso.add_theme_font_override("font", fuente_tit)
	_box_progreso.add_child(_lbl_progreso)

	_barra_progreso = ProgressBar.new()
	_barra_progreso.custom_minimum_size = Vector2(0, 16)
	_barra_progreso.show_percentage = false
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.12, 0.14, 0.17, 0.72)
	sb_bg.set_corner_radius_all(6)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = COL_ACENTO
	sb_fill.set_corner_radius_all(6)
	_barra_progreso.add_theme_stylebox_override("background", sb_bg)
	_barra_progreso.add_theme_stylebox_override("fill", sb_fill)
	_box_progreso.add_child(_barra_progreso)

	_tarjetas.clear()
	_botones_accion.clear()
	if es_descarga:
		var btn_entregar := _crear_boton_accion("INICIAR DESCARGA", COL_ACENTO, fuente_tit)
		btn_entregar.pressed.connect(_on_entregar_carga)
		_botones_accion.append(btn_entregar)
		vbox.add_child(btn_entregar)
	else:
		for c in CATALOGO_CARGAS:
			var card := _crear_tarjeta_carga(c, fuente_tit, fuente_cuerpo)
			_tarjetas.append(card)
			vbox.add_child(card)

	var btn_cerrar := _crear_boton_accion("CERRAR", COL_CERRAR, fuente_tit)
	btn_cerrar.pressed.connect(_ocultar_ui)
	vbox.add_child(btn_cerrar)


func _crear_tarjeta_carga(c: Dictionary, fuente_tit: Font, fuente_cuerpo: Font) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_border_width_all(1)
	sb.border_color = COL_BORDE
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var lbl_ico := Label.new()
	lbl_ico.text = str(c["icono"])
	lbl_ico.add_theme_font_size_override("font_size", 32)
	hbox.add_child(lbl_ico)

	var vbox_info := VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_info.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox_info)

	var lbl_nom := Label.new()
	lbl_nom.text = str(c["nombre"])
	lbl_nom.add_theme_font_size_override("font_size", 19)
	lbl_nom.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	if fuente_tit:
		lbl_nom.add_theme_font_override("font", fuente_tit)
	vbox_info.add_child(lbl_nom)

	var lbl_det := Label.new()
	lbl_det.text = "%s · %d t · $%d" % [str(c["detalle"]), int(round(float(c["peso_kg"]) / 1000.0)), int(c["pago"])]
	lbl_det.add_theme_font_size_override("font_size", 15)
	lbl_det.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78, 0.90))
	if fuente_cuerpo:
		lbl_det.add_theme_font_override("font", fuente_cuerpo)
	vbox_info.add_child(lbl_det)

	var btn_cargar := _crear_boton_accion("CARGAR", COL_ACENTO, fuente_tit)
	btn_cargar.custom_minimum_size = Vector2(138, 48)
	var carga_copia: Dictionary = c.duplicate()
	btn_cargar.pressed.connect(func():
		_pulsar_tarjeta(card)
		_seleccionar_carga(carga_copia)
	)
	_botones_accion.append(btn_cargar)
	hbox.add_child(btn_cargar)
	return card


func _pulsar_tarjeta(card: PanelContainer) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(0.97, 0.97), 0.08)
	tw.tween_property(card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _crear_boton_accion(texto: String, borde_hover: Color, fuente: Font) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97, 1.0))
	if fuente:
		btn.add_theme_font_override("font", fuente)

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.08, 0.09, 0.11, 0.65)
	sb_n.set_border_width_all(1)
	sb_n.border_color = COL_BORDE
	sb_n.set_corner_radius_all(10)

	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.14, 0.16, 0.19, 0.85)
	sb_p.border_color = borde_hover

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_p)
	btn.add_theme_stylebox_override("pressed", sb_p)
	return btn


func _set_botones_habilitados(habilitado: bool) -> void:
	for b in _botones_accion:
		if is_instance_valid(b):
			b.disabled = not habilitado


func _ejecutar_cinematica_operacion(titulo_accion: String, es_carga: bool, trailer: RigidBody3D, id_carga: String, duracion: float, al_terminar: Callable) -> void:
	_en_proceso = true
	_set_botones_habilitados(false)
	_ocultar_ui(true)

	# Capa cinematográfica (barras letterbox + píldora de progreso inferior)
	var cine_layer := CanvasLayer.new()
	cine_layer.layer = 52
	add_child(cine_layer)

	var fuente_tit: Font = load(FUENTE_TITULO) if ResourceLoader.exists(FUENTE_TITULO) else null

	var barra_top := ColorRect.new()
	barra_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra_top.custom_minimum_size = Vector2(0, 56)
	barra_top.offset_bottom = 56
	barra_top.color = Color(0.02, 0.03, 0.04, 0.90)
	barra_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine_layer.add_child(barra_top)

	var barra_bot := ColorRect.new()
	barra_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	barra_bot.custom_minimum_size = Vector2(0, 56)
	barra_bot.offset_top = -56
	barra_bot.color = Color(0.02, 0.03, 0.04, 0.90)
	barra_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine_layer.add_child(barra_bot)

	var center_hud := CenterContainer.new()
	center_hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center_hud.offset_top = -148
	center_hud.offset_bottom = -68
	center_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine_layer.add_child(center_hud)

	var pill_prog := PanelContainer.new()
	pill_prog.custom_minimum_size = Vector2(540, 0)
	pill_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_p := StyleBoxFlat.new()
	sb_p.bg_color = COL_FONDO
	sb_p.set_border_width_all(1)
	sb_p.border_color = COL_BORDE
	sb_p.set_corner_radius_all(12)
	sb_p.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	sb_p.shadow_size = 16
	sb_p.content_margin_left = 20
	sb_p.content_margin_right = 20
	sb_p.content_margin_top = 12
	sb_p.content_margin_bottom = 12
	pill_prog.add_theme_stylebox_override("panel", sb_p)
	center_hud.add_child(pill_prog)

	var vb_p := VBoxContainer.new()
	vb_p.add_theme_constant_override("separation", 8)
	vb_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_prog.add_child(vb_p)

	var hb_p := HBoxContainer.new()
	hb_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb_p.add_child(hb_p)

	var lbl_act := Label.new()
	lbl_act.text = titulo_accion.to_upper()
	lbl_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_act.add_theme_font_size_override("font_size", 15)
	lbl_act.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 0.98))
	if fuente_tit:
		lbl_act.add_theme_font_override("font", fuente_tit)
	hb_p.add_child(lbl_act)

	var lbl_pct := Label.new()
	lbl_pct.text = "0%"
	lbl_pct.add_theme_font_size_override("font_size", 15)
	lbl_pct.add_theme_color_override("font_color", COL_ACENTO)
	if fuente_tit:
		lbl_pct.add_theme_font_override("font", fuente_tit)
	hb_p.add_child(lbl_pct)

	var prog := ProgressBar.new()
	prog.custom_minimum_size = Vector2(0, 10)
	prog.show_percentage = false
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.12, 0.14, 0.17, 0.72)
	sb_bg.set_corner_radius_all(5)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = COL_ACENTO
	sb_fill.set_corner_radius_all(5)
	prog.add_theme_stylebox_override("background", sb_bg)
	prog.add_theme_stylebox_override("fill", sb_fill)
	vb_p.add_child(prog)

	barra_top.position.y = -56.0
	barra_bot.modulate.a = 0.0
	pill_prog.modulate.a = 0.0
	var tw_hud := create_tween().set_parallel(true)
	tw_hud.tween_property(barra_top, "position:y", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_hud.tween_property(barra_bot, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_hud.tween_property(pill_prog, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Cámara orbital cinematográfica
	var cam_previa: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var cam_cin := Camera3D.new()
	cam_cin.name = "CamaraCinematicaCarga"
	cam_cin.near = 0.2
	cam_cin.far = 2200.0
	add_child(cam_cin)
	cam_cin.current = true

	var centro_obj: Vector3 = (trailer.global_position if is_instance_valid(trailer) else global_position)
	var foco: Vector3 = centro_obj + Vector3(0.0, 1.9, 0.0)
	var yaw_base: float = trailer.global_rotation.y if is_instance_valid(trailer) else global_rotation.y
	var ang_ini: float = yaw_base + (0.58 if es_carga else -0.62)
	var ang_fin: float = yaw_base + (1.88 if es_carga else -1.92)

	# Animación 3D de la carga descendiendo o elevándose
	if es_carga and is_instance_valid(trailer):
		_aplicar_carga_visual_trailer(trailer, id_carga)
		var carga_vis := trailer.get_node_or_null("CargaVisual3D") as Node3D
		if carga_vis:
			var pos_final := carga_vis.position
			carga_vis.position = pos_final + Vector3(0.0, 4.8, 0.0)
			carga_vis.scale = Vector3(0.92, 0.92, 0.92)
			var tw_carga := create_tween().set_parallel(true)
			tw_carga.tween_interval(0.35)
			tw_carga.chain().tween_property(carga_vis, "position", pos_final, duracion * 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw_carga.parallel().tween_property(carga_vis, "scale", Vector3.ONE, duracion * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not es_carga and is_instance_valid(trailer):
		var carga_vis := trailer.get_node_or_null("CargaVisual3D") as Node3D
		if carga_vis:
			var pos_arriba := carga_vis.position + Vector3(0.0, 5.2, 0.0)
			var tw_desc := create_tween().set_parallel(true)
			tw_desc.tween_property(carga_vis, "position", pos_arriba, duracion * 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw_desc.tween_property(carga_vis, "scale", Vector3(0.84, 0.84, 0.84), duracion * 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	var tw := create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(cam_cin):
			var ang := lerpf(ang_ini, ang_fin, t)
			var radio := lerpf(13.8, 10.6, t)
			var alt := lerpf(3.7, 2.75, t)
			var pos_cam := foco + Vector3(sin(ang) * radio, alt, cos(ang) * radio)
			cam_cin.global_position = pos_cam
			cam_cin.look_at(foco, Vector3.UP)
			cam_cin.fov = lerpf(54.0, 45.0, t)
		if is_instance_valid(prog):
			prog.value = t * 100.0
		if is_instance_valid(lbl_pct):
			lbl_pct.text = "%d%%" % int(round(t * 100.0))
	, 0.0, 1.0, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if is_instance_valid(cam_previa):
			cam_previa.current = true
		if is_instance_valid(cam_cin):
			cam_cin.queue_free()
		if is_instance_valid(cine_layer):
			cine_layer.queue_free()
		_en_proceso = false
		_set_botones_habilitados(true)
		al_terminar.call()
	)


func _seleccionar_carga(carga: Dictionary) -> void:
	if _en_proceso:
		return
	var trailer := _buscar_trailer_objetivo()
	if not trailer:
		if _badge_estado:
			_badge_estado.text = "SIN TRÁILER"
		if _lbl_estado:
			_lbl_estado.text = "No puedes cargar sin un tráiler acoplado o estacionado en esta zona."
		return

	if _badge_estado:
		_badge_estado.text = "CARGANDO"
	var id_carga := str(carga.get("id", "contenedor_general"))
	_ejecutar_cinematica_operacion("Cargando %s..." % str(carga.get("nombre", "")), true, trailer, id_carga, 3.5, func():
		var tr := _buscar_trailer_objetivo()
		if not tr:
			if _badge_estado:
				_badge_estado.text = "SIN TRÁILER"
			if _lbl_estado:
				_lbl_estado.text = "El tráiler salió de la zona antes de completar la carga."
			return
		get_tree().root.set_meta("carga_activa_mapa", carga)
		var destino_info := _actualizar_gps_hacia_descarga(carga)
		var peso_t := int(round(float(carga.get("peso_kg", 0)) / 1000.0))
		var destino_txt := "Sin destino GPS"
		var msg_exito := "Mercancía asegurada sobre el tráiler. Coloca un Punto de Descarga en el mapa para guiar tu ruta."
		if not destino_info.is_empty():
			destino_txt = "%d m · %s" % [int(destino_info.get("dist", 0)), str(destino_info.get("nombre", "Descarga"))]
			msg_exito = "Mercancía asegurada y ruta GPS trazada hacia %s. Sigue la guía para completar el viaje." % str(destino_info.get("nombre", "Descarga"))
		var resumen: Array[Dictionary] = [
			{"label": "MERCANCÍA", "valor": str(carga.get("nombre", ""))},
			{"label": "PESO BRUTO", "valor": "%d toneladas" % peso_t},
			{"label": "DESTINO GPS", "valor": destino_txt},
			{"label": "PAGO ESTIMADO", "valor": "$%d" % int(carga.get("pago", 0))},
		]
		_mostrar_notificacion_exito("LOGÍSTICA · DESPACHO LISTO", "CARGA COMPLETADA", msg_exito, "EN RUTA", resumen)
	)


func _on_entregar_carga() -> void:
	if _en_proceso:
		return
	if not get_tree().root.has_meta("carga_activa_mapa"):
		if _lbl_estado:
			_lbl_estado.text = "No tienes ninguna carga activa para entregar."
		return
	var carga: Dictionary = get_tree().root.get_meta("carga_activa_mapa") as Dictionary
	if carga.is_empty():
		if _lbl_estado:
			_lbl_estado.text = "No tienes ninguna carga activa para entregar."
		return

	if _badge_estado:
		_badge_estado.text = "DESCARGANDO"
	var trailer_ini := _buscar_trailer_objetivo()
	_ejecutar_cinematica_operacion("Descargando %s..." % str(carga.get("nombre", "")), false, trailer_ini, "", 3.5, func():
		get_tree().root.remove_meta("carga_activa_mapa")
		get_tree().root.remove_meta("destino_gps_mapa")
		var cel_ui := _obtener_celular_ui()
		if cel_ui and cel_ui.has_method("limpiar_ruta_mapa"):
			cel_ui.call("limpiar_ruta_mapa")

		var trailer := _buscar_trailer_objetivo()
		if trailer:
			var old_vis := trailer.get_node_or_null("CargaVisual3D")
			if old_vis:
				old_vis.queue_free()

		var peso_t := int(round(float(carga.get("peso_kg", 0)) / 1000.0))
		var pago_val := int(carga.get("pago", 0))
		var resumen: Array[Dictionary] = [
			{"label": "MERCANCÍA", "valor": str(carga.get("nombre", ""))},
			{"label": "PESO ENTREGADO", "valor": "%d toneladas" % peso_t},
			{"label": "RECOMPENSA", "valor": "+$%d" % pago_val},
			{"label": "ESTADO", "valor": "Entrega Verificada"},
		]
		_mostrar_notificacion_exito(
			"LOGÍSTICA · ENTREGA CONFIRMADA",
			"DESCARGA COMPLETADA",
			"La operación finalizó sin novedades. El tráiler quedó libre para un nuevo viaje.",
			"COMPLETADO",
			resumen
		)
	)


func _mostrar_notificacion_exito(subtitulo: String, titulo: String, detalle: String, badge_texto: String, resumen: Array[Dictionary]) -> void:
	ZonaCargaInteractiva.mostrar_notificacion_global(self, subtitulo, titulo, detalle, badge_texto, resumen)


static func mostrar_notificacion_global(anfitrion: Node, subtitulo: String, titulo: String, detalle: String, badge_texto: String, resumen: Array[Dictionary]) -> void:
	if not is_instance_valid(anfitrion):
		return
	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 55
	anfitrion.add_child(modal_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.04, 0.44)
	modal_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.84)
	sb.set_border_width_all(1)
	sb.border_color = COL_BORDE
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	sb.shadow_size = 26
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var fuente_tit: Font = load(FUENTE_TITULO) if ResourceLoader.exists(FUENTE_TITULO) else null
	var fuente_cuerpo: Font = load(FUENTE_CUERPO) if ResourceLoader.exists(FUENTE_CUERPO) else fuente_tit

	var hbox_main := HBoxContainer.new()
	hbox_main.add_theme_constant_override("separation", 26)
	panel.add_child(hbox_main)

	# Columna izquierda: imagen emblemática glassmorphic
	var marco_img := PanelContainer.new()
	marco_img.custom_minimum_size = Vector2(210, 210)
	marco_img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_img := StyleBoxFlat.new()
	sb_img.bg_color = Color(0.08, 0.09, 0.11, 0.78)
	sb_img.set_border_width_all(1)
	sb_img.border_color = Color(0.88, 0.68, 0.28, 0.32)
	sb_img.set_corner_radius_all(14)
	sb_img.content_margin_left = 4
	sb_img.content_margin_right = 4
	sb_img.content_margin_top = 4
	sb_img.content_margin_bottom = 4
	marco_img.add_theme_stylebox_override("panel", sb_img)
	hbox_main.add_child(marco_img)

	if ResourceLoader.exists(RUTA_IMAGEN_EXITO):
		var tex := load(RUTA_IMAGEN_EXITO) as Texture2D
		if tex:
			var img_rect := TextureRect.new()
			img_rect.texture = tex
			img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img_rect.custom_minimum_size = Vector2(202, 202)
			marco_img.add_child(img_rect)

	# Columna derecha: encabezado, resumen en tarjetas y botón continuar
	var vbox_der := VBoxContainer.new()
	vbox_der.add_theme_constant_override("separation", 12)
	vbox_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_main.add_child(vbox_der)

	var hbox_top := HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 12)
	vbox_der.add_child(hbox_top)

	var vbox_tit := VBoxContainer.new()
	vbox_tit.add_theme_constant_override("separation", 2)
	vbox_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_top.add_child(vbox_tit)

	var lbl_sub := Label.new()
	lbl_sub.text = subtitulo
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", COL_ACENTO)
	if fuente_tit:
		lbl_sub.add_theme_font_override("font", fuente_tit)
	vbox_tit.add_child(lbl_sub)

	var lbl_t := Label.new()
	lbl_t.text = titulo
	lbl_t.add_theme_font_size_override("font_size", 30)
	lbl_t.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	if fuente_tit:
		lbl_t.add_theme_font_override("font", fuente_tit)
	vbox_tit.add_child(lbl_t)

	var pill_estado := PanelContainer.new()
	pill_estado.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_pill := StyleBoxFlat.new()
	sb_pill.bg_color = Color(0.88, 0.68, 0.28, 0.14)
	sb_pill.set_border_width_all(1)
	sb_pill.border_color = Color(0.88, 0.68, 0.28, 0.48)
	sb_pill.set_corner_radius_all(8)
	sb_pill.content_margin_left = 12
	sb_pill.content_margin_right = 12
	sb_pill.content_margin_top = 6
	sb_pill.content_margin_bottom = 6
	pill_estado.add_theme_stylebox_override("panel", sb_pill)
	hbox_top.add_child(pill_estado)

	var lbl_pill := Label.new()
	lbl_pill.text = badge_texto
	lbl_pill.add_theme_font_size_override("font_size", 13)
	lbl_pill.add_theme_color_override("font_color", COL_ACENTO)
	if fuente_tit:
		lbl_pill.add_theme_font_override("font", fuente_tit)
	pill_estado.add_child(lbl_pill)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.12)
	vbox_der.add_child(sep)

	var lbl_d := Label.new()
	lbl_d.text = detalle
	lbl_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_d.add_theme_font_size_override("font_size", 16)
	lbl_d.add_theme_color_override("font_color", Color(0.78, 0.82, 0.87, 0.94))
	if fuente_cuerpo:
		lbl_d.add_theme_font_override("font", fuente_cuerpo)
	vbox_der.add_child(lbl_d)

	var tarjetas_resumen: Array[PanelContainer] = []
	if not resumen.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		vbox_der.add_child(grid)

		for item in resumen:
			var stat_card := PanelContainer.new()
			stat_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sb_st := StyleBoxFlat.new()
			sb_st.bg_color = COL_CARD
			sb_st.set_border_width_all(1)
			sb_st.border_color = COL_BORDE
			sb_st.set_corner_radius_all(10)
			sb_st.content_margin_left = 14
			sb_st.content_margin_right = 14
			sb_st.content_margin_top = 10
			sb_st.content_margin_bottom = 10
			stat_card.add_theme_stylebox_override("panel", sb_st)
			grid.add_child(stat_card)

			var vb_st := VBoxContainer.new()
			vb_st.add_theme_constant_override("separation", 3)
			stat_card.add_child(vb_st)

			var lbl_k := Label.new()
			lbl_k.text = str(item.get("label", ""))
			lbl_k.add_theme_font_size_override("font_size", 11)
			lbl_k.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74, 0.90))
			if fuente_tit:
				lbl_k.add_theme_font_override("font", fuente_tit)
			vb_st.add_child(lbl_k)

			var lbl_v := Label.new()
			lbl_v.text = str(item.get("valor", ""))
			lbl_v.add_theme_font_size_override("font_size", 17)
			lbl_v.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
			if fuente_tit:
				lbl_v.add_theme_font_override("font", fuente_tit)
			vb_st.add_child(lbl_v)
			tarjetas_resumen.append(stat_card)

	var btn_continuar := Button.new()
	btn_continuar.text = "CONTINUAR"
	btn_continuar.custom_minimum_size = Vector2(0, 52)
	btn_continuar.add_theme_font_size_override("font_size", 18)
	btn_continuar.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 1.0))
	if fuente_tit:
		btn_continuar.add_theme_font_override("font", fuente_tit)
	var sb_btn_n := StyleBoxFlat.new()
	sb_btn_n.bg_color = Color(0.10, 0.12, 0.14, 0.78)
	sb_btn_n.set_border_width_all(1)
	sb_btn_n.border_color = Color(0.88, 0.68, 0.28, 0.55)
	sb_btn_n.set_corner_radius_all(10)
	var sb_btn_p := sb_btn_n.duplicate() as StyleBoxFlat
	sb_btn_p.bg_color = Color(0.16, 0.18, 0.21, 0.92)
	sb_btn_p.border_color = COL_ACENTO
	btn_continuar.add_theme_stylebox_override("normal", sb_btn_n)
	btn_continuar.add_theme_stylebox_override("hover", sb_btn_p)
	btn_continuar.add_theme_stylebox_override("pressed", sb_btn_p)
	vbox_der.add_child(btn_continuar)

	var cerrar_modal := func():
		if not is_instance_valid(modal_layer):
			return
		btn_continuar.disabled = true
		var tw_out := anfitrion.create_tween().set_parallel(true)
		tw_out.tween_property(panel, "scale", Vector2(0.94, 0.94), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_out.tween_property(panel, "modulate:a", 0.0, 0.18)
		tw_out.tween_property(backdrop, "modulate:a", 0.0, 0.18)
		tw_out.chain().tween_callback(func():
			if is_instance_valid(modal_layer):
				modal_layer.queue_free()
		)

	btn_continuar.pressed.connect(cerrar_modal)

	# Animación fluida de entrada
	backdrop.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(390, 170)
	panel.scale = Vector2(0.90, 0.90)
	marco_img.pivot_offset = Vector2(105, 105)
	marco_img.scale = Vector2(0.84, 0.84)

	var tw_in := anfitrion.create_tween().set_parallel(true)
	tw_in.tween_property(backdrop, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(panel, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(marco_img, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for i in range(tarjetas_resumen.size()):
		var c := tarjetas_resumen[i]
		c.modulate.a = 0.0
		var tw_c := anfitrion.create_tween()
		tw_c.tween_interval(0.06 * float(i + 1))
		tw_c.tween_property(c, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _obtener_celular_ui() -> Node:
	var cel := get_tree().root.get_node_or_null("CelularUI")
	if not cel and get_tree().current_scene:
		cel = get_tree().current_scene.find_child("CelularUI", true, false)
	return cel


func _actualizar_gps_hacia_descarga(carga: Dictionary) -> Dictionary:
	var mejor_pos := Vector3.ZERO
	var mejor_dist := INF
	var mejor_nombre := "Punto de Descarga"

	var raiz := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var pila: Array[Node] = [raiz]
	while not pila.is_empty():
		var cur: Node = pila.pop_back()
		for ch in cur.get_children():
			pila.append(ch)
		if cur is ZonaCargaInteractiva and (cur as ZonaCargaInteractiva).es_descarga:
			var n3 := cur as Node3D
			var d := global_position.distance_to(n3.global_position)
			if d < mejor_dist:
				mejor_dist = d
				mejor_pos = n3.global_position
				mejor_nombre = "Punto de Descarga"

	if mejor_dist == INF:
		return {}

	get_tree().root.set_meta("destino_gps_mapa", {
		"pos": mejor_pos,
		"nombre": mejor_nombre,
		"carga": str(carga.get("nombre", "Carga"))
	})

	var cel_ui := _obtener_celular_ui()
	if cel_ui and cel_ui.has_method("trazar_ruta_mapa"):
		var ruta := PackedVector3Array([global_position + Vector3(0, 1.0, 0), mejor_pos + Vector3(0, 1.0, 0)])
		cel_ui.call("trazar_ruta_mapa", ruta)

	return {"nombre": mejor_nombre, "dist": int(round(mejor_dist))}


func _buscar_trailer_objetivo() -> RigidBody3D:
	var raiz := get_tree().current_scene if get_tree().current_scene else get_tree().root
	var pila: Array[Node] = [raiz]
	var mejor_trailer: RigidBody3D = null
	var mejor_dist: float = 18.0

	while not pila.is_empty():
		var cur: Node = pila.pop_back()
		for ch in cur.get_children():
			pila.append(ch)
		if cur is RigidBody3D:
			var rb := cur as RigidBody3D
			var nm := rb.name.to_lower()
			if "carpado" in nm or "ct_1" in nm or "trailer" in nm or "remolque" in nm:
				var d := rb.global_position.distance_to(global_position)
				if d < mejor_dist:
					mejor_dist = d
					mejor_trailer = rb
			elif "activo" in rb and bool(rb.get("activo")):
				var eng := rb.find_child("Enganche", true, false)
				if eng and "conectado" in eng and bool(eng.get("conectado")):
					var rem = eng.get("enganche_remoto")
					if rem and rem is Node:
						var p: Node = rem
						while p and not (p is RigidBody3D):
							p = p.get_parent()
						if p is RigidBody3D:
							return p as RigidBody3D
	return mejor_trailer


func _aplicar_carga_visual_trailer(trailer: RigidBody3D, id_carga: String) -> void:
	var previo := trailer.get_node_or_null("CargaVisual3D")
	if previo:
		previo.queue_free()

	var cont := Node3D.new()
	cont.name = "CargaVisual3D"
	cont.position = Vector3(0.0, 1.42, 4.2)
	trailer.add_child(cont)

	match id_carga:
		"cafe_exportacion":
			_crear_pila_cajas(cont, Color(0.68, 0.50, 0.32), Color(0.50, 0.34, 0.18), 2, 4, Vector3(0.95, 0.65, 1.5))
		"material_construccion":
			_crear_pila_cajas(cont, Color(0.64, 0.30, 0.24), Color(0.56, 0.56, 0.58), 2, 4, Vector3(0.95, 0.72, 1.5))
		"maquinaria_pesada":
			_crear_maquinaria(cont)
		_:
			_crear_contenedor(cont)


func _crear_pila_cajas(cont: Node3D, col_a: Color, col_b: Color, cols: int, filas: int, tam: Vector3) -> void:
	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = col_a
	mat_a.roughness = 0.82
	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = col_b
	mat_b.roughness = 0.85

	for ix in range(cols):
		for iz in range(filas):
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = tam
			mi.mesh = box
			mi.material_override = mat_a if (ix + iz) % 2 == 0 else mat_b
			mi.position = Vector3((ix - 0.5) * (tam.x + 0.12), tam.y * 0.5, (iz - (filas - 1) * 0.5) * (tam.z + 0.18))
			cont.add_child(mi)


func _crear_contenedor(cont: Node3D) -> void:
	var mat_cont := StandardMaterial3D.new()
	mat_cont.albedo_color = Color(0.13, 0.33, 0.54)
	mat_cont.roughness = 0.45
	mat_cont.metallic = 0.35
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.36, 2.35, 9.2)
	mi.mesh = box
	mi.material_override = mat_cont
	mi.position = Vector3(0.0, 1.175, 0.0)
	cont.add_child(mi)


func _crear_maquinaria(cont: Node3D) -> void:
	var mat_cat := StandardMaterial3D.new()
	mat_cat.albedo_color = Color(0.90, 0.65, 0.12)
	mat_cat.roughness = 0.38
	mat_cat.metallic = 0.4
	var mat_acero := StandardMaterial3D.new()
	mat_acero.albedo_color = Color(0.18, 0.20, 0.22)
	mat_acero.roughness = 0.5
	mat_acero.metallic = 0.65

	var base := MeshInstance3D.new()
	var b_m := BoxMesh.new()
	b_m.size = Vector3(2.2, 0.55, 5.2)
	base.mesh = b_m
	base.material_override = mat_acero
	base.position = Vector3(0.0, 0.275, 0.0)
	cont.add_child(base)

	var cuerpo := MeshInstance3D.new()
	var c_m := BoxMesh.new()
	c_m.size = Vector3(1.95, 1.45, 4.4)
	cuerpo.mesh = c_m
	cuerpo.material_override = mat_cat
	cuerpo.position = Vector3(0.0, 1.25, 0.0)
	cont.add_child(cuerpo)
