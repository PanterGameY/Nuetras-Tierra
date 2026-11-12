extends Control
class_name GaleriaRuedasTrailer

# ═══════════════════════════════════════════════════════════════════════
# GaleriaRuedasTrailer — Diálogo y Galería Visual de Ruedas para Remolques
# Cumple rigurosamente el Design System (Glassmorphic, Moderniz, 80px botones)
# ═══════════════════════════════════════════════════════════════════════

signal rueda_seleccionada(id_rueda: String, acabado: Dictionary)
signal cerrada()

@export var trailer_objetivo: Node = null

# Nodos de UI principales
var panel_fondo: PanelContainer = null
var vbox_principal: VBoxContainer = null
var scroll_tarjetas: ScrollContainer = null
var hbox_tarjetas: HBoxContainer = null
var btn_equipar: Button = null
var btn_cerrar: Button = null

var id_seleccionado: String = "rin_t2_cromo"
var acabado_actual: Dictionary = {
	"color": Color.WHITE,
	"metallic": 0.9,
	"roughness": 0.15
}

var tarjetas_map: Dictionary = {}
var fuente_moderniz: Font = null

func _ready() -> void:
	fuente_moderniz = load("res://recursos/fonts/Moderniz.otf") as Font
	_construir_interfaz()
	_poblar_galeria()
	_animar_apertura()

## Abre la galería vinculada a un trailer específico para previsualizar y equipar en vivo
func abrir_para_trailer(trailer: Node) -> void:
	trailer_objetivo = trailer
	if trailer and "tipo_ruedas" in trailer and trailer.tipo_ruedas != "":
		id_seleccionado = trailer.tipo_ruedas
	_actualizar_seleccion_visual()
	visible = true
	_animar_apertura()

func _construir_interfaz() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo oscurecido general
	var dimmer = ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.65)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)

	# Panel Principal Glassmorphic
	panel_fondo = PanelContainer.new()
	panel_fondo.custom_minimum_size = Vector2(1100, 680)
	panel_fondo.size = Vector2(1100, 680)
	panel_fondo.pivot_offset = Vector2(550, 340)

	# Centrar en pantalla
	panel_fondo.set_anchors_preset(Control.PRESET_CENTER)
	panel_fondo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_fondo.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style_glass = StyleBoxFlat.new()
	style_glass.bg_color = Color(0.06, 0.06, 0.08, 0.92) # Fondo vidrio oscuro
	style_glass.border_width_left = 3
	style_glass.border_width_top = 3
	style_glass.border_width_right = 3
	style_glass.border_width_bottom = 3
	style_glass.border_color = Color(1.00, 0.45, 0.00, 0.85) # Naranja Neón
	style_glass.corner_radius_top_left = 16
	style_glass.corner_radius_top_right = 16
	style_glass.corner_radius_bottom_left = 16
	style_glass.corner_radius_bottom_right = 16
	style_glass.content_margin_left = 45
	style_glass.content_margin_right = 45
	style_glass.content_margin_top = 40
	style_glass.content_margin_bottom = 40
	panel_fondo.add_theme_stylebox_override("panel", style_glass)
	add_child(panel_fondo)

	vbox_principal = VBoxContainer.new()
	vbox_principal.add_theme_constant_override("separation", 24)
	panel_fondo.add_child(vbox_principal)

	# 1. Cabecera (Título y descripción)
	var lbl_titulo = Label.new()
	lbl_titulo.text = "GALERÍA DE RUEDAS DE TRAILER"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_color_override("font_color", Color(1.00, 0.45, 0.00, 1.0))
	lbl_titulo.add_theme_font_size_override("font_size", 44)
	if fuente_moderniz:
		lbl_titulo.add_theme_font_override("font", fuente_moderniz)
	vbox_principal.add_child(lbl_titulo)

	var lbl_sub = Label.new()
	lbl_sub.text = "Selecciona el conjunto de rines y neumáticos para equipar en los ejes del remolque"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90, 1.0))
	lbl_sub.add_theme_font_size_override("font_size", 24)
	vbox_principal.add_child(lbl_sub)

	# 2. Contenedor de Tarjetas de Ruedas
	scroll_tarjetas = ScrollContainer.new()
	scroll_tarjetas.custom_minimum_size = Vector2(0, 310)
	scroll_tarjetas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_tarjetas.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_tarjetas.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox_principal.add_child(scroll_tarjetas)

	hbox_tarjetas = HBoxContainer.new()
	hbox_tarjetas.add_theme_constant_override("separation", 20)
	hbox_tarjetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_tarjetas.add_child(hbox_tarjetas)

	# 3. Selector de Acabado de Rin Rápido
	var hbox_acabados = HBoxContainer.new()
	hbox_acabados.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_acabados.add_theme_constant_override("separation", 16)
	vbox_principal.add_child(hbox_acabados)

	var lbl_acabado = Label.new()
	lbl_acabado.text = "ACABADO:"
	lbl_acabado.add_theme_font_size_override("font_size", 22)
	lbl_acabado.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	if fuente_moderniz:
		lbl_acabado.add_theme_font_override("font", fuente_moderniz)
	hbox_acabados.add_child(lbl_acabado)

	var opciones_acabado = [
		{"nombre": "Cromo Espejo", "color": Color(0.96, 0.96, 0.98), "met": 0.95, "rough": 0.12},
		{"nombre": "Aluminio Pulido", "color": Color(0.85, 0.88, 0.92), "met": 0.85, "rough": 0.28},
		{"nombre": "Negro Satinado", "color": Color(0.12, 0.12, 0.14), "met": 0.30, "rough": 0.50},
		{"nombre": "Oro Colombiano", "color": Color(0.95, 0.78, 0.25), "met": 0.88, "rough": 0.22}
	]

	for opt in opciones_acabado:
		var btn_opt = Button.new()
		btn_opt.text = opt["nombre"]
		btn_opt.custom_minimum_size = Vector2(160, 48)
		btn_opt.add_theme_font_size_override("font_size", 18)
		var st_btn = StyleBoxFlat.new()
		st_btn.bg_color = Color(0.12, 0.14, 0.18, 0.85)
		st_btn.border_width_left = 2
		st_btn.border_width_right = 2
		st_btn.border_width_top = 2
		st_btn.border_width_bottom = 2
		st_btn.border_color = Color(0.20, 0.60, 1.00, 0.6)
		st_btn.corner_radius_top_left = 8
		st_btn.corner_radius_top_right = 8
		st_btn.corner_radius_bottom_left = 8
		st_btn.corner_radius_bottom_right = 8
		btn_opt.add_theme_stylebox_override("normal", st_btn)
		btn_opt.pressed.connect(func(): _seleccionar_acabado(opt))
		hbox_acabados.add_child(btn_opt)

	# 4. Botones de Acción (Móvil: 80px alto, Moderniz 32px)
	var hbox_botones = HBoxContainer.new()
	hbox_botones.add_theme_constant_override("separation", 25)
	vbox_principal.add_child(hbox_botones)

	btn_cerrar = Button.new()
	btn_cerrar.text = "CERRAR"
	btn_cerrar.custom_minimum_size = Vector2(0, 80)
	btn_cerrar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_cerrar = StyleBoxFlat.new()
	st_cerrar.bg_color = Color(0.18, 0.18, 0.22, 0.9)
	st_cerrar.border_width_left = 2
	st_cerrar.border_width_right = 2
	st_cerrar.border_width_top = 2
	st_cerrar.border_width_bottom = 2
	st_cerrar.border_color = Color(0.4, 0.4, 0.45, 0.8)
	st_cerrar.corner_radius_top_left = 12
	st_cerrar.corner_radius_top_right = 12
	st_cerrar.corner_radius_bottom_left = 12
	st_cerrar.corner_radius_bottom_right = 12
	btn_cerrar.add_theme_stylebox_override("normal", st_cerrar)
	btn_cerrar.add_theme_font_size_override("font_size", 30)
	if fuente_moderniz:
		btn_cerrar.add_theme_font_override("font", fuente_moderniz)
	btn_cerrar.pressed.connect(_on_btn_cerrar_pressed)
	hbox_botones.add_child(btn_cerrar)

	btn_equipar = Button.new()
	btn_equipar.text = "EQUIPAR EN TRAILER"
	btn_equipar.custom_minimum_size = Vector2(0, 80)
	btn_equipar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_equipar = StyleBoxFlat.new()
	st_equipar.bg_color = Color(1.00, 0.45, 0.00, 1.0) # Naranja neón principal
	st_equipar.corner_radius_top_left = 12
	st_equipar.corner_radius_top_right = 12
	st_equipar.corner_radius_bottom_left = 12
	st_equipar.corner_radius_bottom_right = 12
	btn_equipar.add_theme_stylebox_override("normal", st_equipar)
	btn_equipar.add_theme_font_size_override("font_size", 30)
	if fuente_moderniz:
		btn_equipar.add_theme_font_override("font", fuente_moderniz)
	btn_equipar.pressed.connect(_on_btn_equipar_pressed)
	hbox_botones.add_child(btn_equipar)

func _poblar_galeria() -> void:
	for c in hbox_tarjetas.get_children():
		c.queue_free()
	tarjetas_map.clear()

	var presets = CatalogoRuedasTrailer.obtener_todos()
	for p in presets:
		var card = _crear_tarjeta_rueda(p)
		hbox_tarjetas.add_child(card)
		tarjetas_map[p["id"]] = card

	_actualizar_seleccion_visual()

func _crear_tarjeta_rueda(preset: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 290)

	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.11, 0.15, 0.90)
	st.border_width_left = 2
	st.border_width_right = 2
	st.border_width_top = 2
	st.border_width_bottom = 2
	st.border_color = Color(0.25, 0.30, 0.40, 0.6)
	st.corner_radius_top_left = 12
	st.corner_radius_top_right = 12
	st.corner_radius_bottom_left = 12
	st.corner_radius_bottom_right = 12
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", st)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Etiqueta de Estilo (Badge)
	var badge = Label.new()
	badge.text = "[" + preset.get("estilo", "ESTÁNDAR").to_upper() + "]"
	badge.add_theme_color_override("font_color", Color(0.20, 0.60, 1.00, 1.0))
	badge.add_theme_font_size_override("font_size", 16)
	vbox.add_child(badge)

	# Nombre de la Rueda
	var lbl_name = Label.new()
	lbl_name.text = preset.get("nombre", "")
	lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl_name.add_theme_font_size_override("font_size", 20)
	if fuente_moderniz:
		lbl_name.add_theme_font_override("font", fuente_moderniz)
	vbox.add_child(lbl_name)

	# Descripción técnica
	var lbl_desc = Label.new()
	lbl_desc.text = preset.get("descripcion", "")
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_desc.add_theme_color_override("font_color", Color(0.70, 0.72, 0.78, 1.0))
	lbl_desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_desc)

	# Especificación de Radio
	var lbl_rad = Label.new()
	lbl_rad.text = "Radio: %.2f m | Dual Remolque" % float(preset.get("radio_rueda", 0.52))
	lbl_rad.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 0.9))
	lbl_rad.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_rad)

	# Botón de selección dentro de la tarjeta
	var btn_sel = Button.new()
	btn_sel.text = "ELEGIR"
	btn_sel.custom_minimum_size = Vector2(0, 48)
	var st_btn = StyleBoxFlat.new()
	st_btn.bg_color = Color(0.18, 0.22, 0.28, 0.9)
	st_btn.corner_radius_top_left = 8
	st_btn.corner_radius_top_right = 8
	st_btn.corner_radius_bottom_left = 8
	st_btn.corner_radius_bottom_right = 8
	btn_sel.add_theme_stylebox_override("normal", st_btn)
	btn_sel.add_theme_font_size_override("font_size", 18)
	var cur_id: String = preset.get("id", "")
	btn_sel.pressed.connect(func(): _on_tarjeta_seleccionada(cur_id))
	vbox.add_child(btn_sel)

	return card

func _on_tarjeta_seleccionada(id_tipo: String) -> void:
	id_seleccionado = id_tipo
	_actualizar_seleccion_visual()

	# Previsualización inmediata en el tráiler si está en escena
	if trailer_objetivo and is_instance_valid(trailer_objetivo):
		if trailer_objetivo.has_method("aplicar_tipo_ruedas"):
			trailer_objetivo.call("aplicar_tipo_ruedas", id_seleccionado)
		if trailer_objetivo.has_method("aplicar_color_rines"):
			trailer_objetivo.call("aplicar_color_rines", acabado_actual.get("color", Color.WHITE), acabado_actual.get("metallic", 0.9), acabado_actual.get("roughness", 0.15))

func _seleccionar_acabado(acabado: Dictionary) -> void:
	acabado_actual = acabado
	if trailer_objetivo and is_instance_valid(trailer_objetivo) and trailer_objetivo.has_method("aplicar_color_rines"):
		trailer_objetivo.call("aplicar_color_rines", acabado.get("color", Color.WHITE), acabado.get("metallic", 0.9), acabado.get("roughness", 0.15))

func _actualizar_seleccion_visual() -> void:
	for id in tarjetas_map.keys():
		var card = tarjetas_map[id] as PanelContainer
		if not card:
			continue
		var st = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if id == id_seleccionado:
			st.border_color = Color(1.00, 0.45, 0.00, 1.0) # Naranja Neón activo
			st.border_width_left = 4
			st.border_width_right = 4
			st.border_width_top = 4
			st.border_width_bottom = 4
			st.bg_color = Color(0.18, 0.12, 0.08, 0.95)
		else:
			st.border_color = Color(0.25, 0.30, 0.40, 0.6)
			st.border_width_left = 2
			st.border_width_right = 2
			st.border_width_top = 2
			st.border_width_bottom = 2
			st.bg_color = Color(0.10, 0.11, 0.15, 0.90)
		card.add_theme_stylebox_override("panel", st)

func _animar_apertura() -> void:
	if not panel_fondo:
		return
	modulate.a = 0.0
	panel_fondo.scale = Vector2(0.8, 0.8)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_fondo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animar_cierre() -> void:
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(panel_fondo, "scale", Vector2(0.85, 0.85), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	visible = false
	emit_signal("cerrada")

func _on_btn_cerrar_pressed() -> void:
	_animar_cierre()

func _on_btn_equipar_pressed() -> void:
	if trailer_objetivo and is_instance_valid(trailer_objetivo):
		if trailer_objetivo.has_method("aplicar_tipo_ruedas"):
			trailer_objetivo.call("aplicar_tipo_ruedas", id_seleccionado)
		if trailer_objetivo.has_method("aplicar_color_rines"):
			trailer_objetivo.call("aplicar_color_rines", acabado_actual.get("color", Color.WHITE), acabado_actual.get("metallic", 0.9), acabado_actual.get("roughness", 0.15))
	emit_signal("rueda_seleccionada", id_seleccionado, acabado_actual)
	_animar_cierre()
