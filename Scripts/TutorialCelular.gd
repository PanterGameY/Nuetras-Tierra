extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
#  TutorialCelular.gd  —  Tutorial interactivo del celular
#  Posiciona el bubble y el anillo RELATIVO al phone_frame real en pantalla.
#  Estilo identico al sistema de personalizacion del juego.
# ══════════════════════════════════════════════════════════════════════════════

signal tutorial_terminado

# ─── Paleta del juego ─────────────────────────────────────────────────────────
const C_BG     := Color(0.04, 0.04, 0.06, 0.92)
const C_GOLD   := Color(0.95, 0.80, 0.00, 1.00)
const C_TEXT   := Color(0.92, 0.92, 0.95, 1.00)

# ─── Nodos ────────────────────────────────────────────────────────────────────
var _root_ctrl:  Control        = null
var _overlay_left:   ColorRect  = null
var _overlay_right:  ColorRect  = null
var _overlay_top:    ColorRect  = null
var _overlay_bottom: ColorRect  = null
var _bubble:     PanelContainer = null
var _title_lbl:  Label          = null
var _desc_lbl:   Label          = null
var _next_btn:   Button         = null
var _step_lbl:   Label          = null
var _skip_btn:   Button         = null
var _pulse_ring: Panel          = null
var _blink_panel: Panel         = null
var _arrow:      Panel          = null

var _pulse_tween: Tween         = null
var _blink_tween: Tween         = null
var _current_step: int          = 0
var _font: FontFile             = null

# Referencia al phone_frame de CelularUI para calcular posicion real
var _phone_frame: Control       = null

var _steps: Array = []

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 200
	_font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	# Buscar el phone_frame en el padre (CelularUI)
	var celular_ui = get_parent()
	if celular_ui:
		_phone_frame = celular_ui.get_node_or_null("PhoneFrame")

	_define_steps()
	_build_ui()

	# Esperar un frame para que el phone_frame tenga su tamano real calculado
	await get_tree().process_frame
	_show_step(0)

# ─── PASOS ────────────────────────────────────────────────────────────────────
# target_anchor: posicion RELATIVA al phone_frame (0=izq/top, 1=der/bottom)
func _define_steps() -> void:
	_steps = [
		{
			"title": "BIENVENIDO AL CELULAR",
			"desc":  "Este es tu celular en el juego.\nDesde aqui podras navegar, ver\ntu cuenta, musica y mas.",
			"next":  "SIGUIENTE",
			"show_pulse": false,
			"target": Vector2(0.5, 0.5),
		},
		{
			"title": "PANTALLA DE INICIO",
			"desc":  "Esta es la pantalla principal.\nToca los iconos de las apps\npara abrirlas.",
			"next":  "SIGUIENTE",
			"show_pulse": true,
			"target": Vector2(0.5, 0.38),
		},
		{
			"title": "GPS Y NAVEGACION",
			"desc":  "El icono de mapa abre el GPS.\nEscribe un destino y sigue\nla ruta naranja en el mapa.",
			"next":  "SIGUIENTE",
			"show_pulse": true,
			"target": Vector2(0.22, 0.26),
		},
		{
			"title": "BUSCADOR DEL GPS",
			"desc":  "Dentro del GPS, escribe aqui\nel nombre del lugar al que\nquieres ir.",
			"next":  "SIGUIENTE",
			"show_pulse": true,
			"target": Vector2(0.5, 0.14),
		},
		{
			"title": "BANCO",
			"desc":  "Desde aqui puedes ver tu\ndinero y esmeraldas acumulados\nen el juego.",
			"next":  "SIGUIENTE",
			"show_pulse": true,
			"target": Vector2(0.50, 0.26),
		},
		{
			"title": "MUSICA",
			"desc":  "Controla la musica que suena\nmientras conduces por\nNuestra Tierra.",
			"next":  "SIGUIENTE",
			"show_pulse": true,
			"target": Vector2(0.78, 0.26),
		},
		{
			"title": "CERRAR EL CELULAR",
			"desc":  "Toca este boton para cerrar\nel celular y volver al juego.",
			"next":  "ENTENDIDO",
			"show_pulse": true,
			"target": Vector2(0.83, 0.93),
		},
	]

# ─── CONSTRUCCION DE LA UI ────────────────────────────────────────────────────
func _build_ui() -> void:
	_root_ctrl = Control.new()
	_root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_ctrl)

	# 4 rectángulos de oscurecimiento dinámico para no tapar el celular
	_overlay_left = ColorRect.new()
	_overlay_left.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_overlay_left)

	_overlay_right = ColorRect.new()
	_overlay_right.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_overlay_right)

	_overlay_top = ColorRect.new()
	_overlay_top.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_overlay_top)

	_overlay_bottom = ColorRect.new()
	_overlay_bottom.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_overlay_bottom)

	# Flecha del globo (Tooltip Arrow) - Dibujado como un diamante de 32x32 detrás del globo
	_arrow = Panel.new()
	_arrow.custom_minimum_size = Vector2(32, 32)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ar_st = StyleBoxFlat.new()
	ar_st.bg_color = C_BG
	ar_st.border_width_left = 2; ar_st.border_width_top = 2
	ar_st.border_width_right = 2; ar_st.border_width_bottom = 2
	ar_st.border_color = C_GOLD
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		ar_st.set("corner_radius_" + c, 4)
	_arrow.add_theme_stylebox_override("panel", ar_st)
	_arrow.rotation_degrees = 45.0
	_root_ctrl.add_child(_arrow)

	# Panel de parpadeo de aplicacion enfocada (highlight)
	_blink_panel = Panel.new()
	_blink_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl_st = StyleBoxFlat.new()
	bl_st.bg_color = Color(0.95, 0.8, 0.0, 0.35)
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		bl_st.set("corner_radius_" + c, 22)
	_blink_panel.add_theme_stylebox_override("panel", bl_st)
	_root_ctrl.add_child(_blink_panel)

	# ── Anillo pulsante dorado ─────────────────────────────────────────────────
	_pulse_ring = Panel.new()
	_pulse_ring.custom_minimum_size = Vector2(72, 72)
	_pulse_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pr_st = StyleBoxFlat.new()
	pr_st.bg_color     = Color(0, 0, 0, 0)
	pr_st.border_width_left  = 3; pr_st.border_width_top    = 3
	pr_st.border_width_right = 3; pr_st.border_width_bottom = 3
	pr_st.border_color = C_GOLD
	pr_st.shadow_color = Color(0.95, 0.8, 0.0, 0.30)
	pr_st.shadow_size  = 8
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		pr_st.set("corner_radius_" + c, 36)
	_pulse_ring.add_theme_stylebox_override("panel", pr_st)
	_root_ctrl.add_child(_pulse_ring)

	# ── TARJETA principal (Globo Tooltip Gigante) ───────────────────────────────
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var b_st = StyleBoxFlat.new()
	b_st.bg_color = C_BG
	b_st.border_width_left  = 2; b_st.border_width_top    = 2
	b_st.border_width_right = 2; b_st.border_width_bottom = 2
	b_st.border_color = C_GOLD
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		b_st.set("corner_radius_" + c, 24)
	b_st.shadow_color = Color(0, 0, 0, 0.60)
	b_st.shadow_size  = 25
	b_st.content_margin_left   = 28; b_st.content_margin_right  = 28
	b_st.content_margin_top    = 24; b_st.content_margin_bottom = 24
	_bubble.add_theme_stylebox_override("panel", b_st)
	_root_ctrl.add_child(_bubble)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bubble.add_child(vbox)

	# Titulo dorado (Gigante)
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 32)
	_title_lbl.add_theme_color_override("font_color", C_GOLD)
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	_title_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font: _title_lbl.add_theme_font_override("font", _font)
	vbox.add_child(_title_lbl)

	# Separador sutil
	var sep = Panel.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_st = StyleBoxFlat.new()
	sep_st.bg_color    = Color(0.95, 0.8, 0.0, 0.7)
	sep.add_theme_stylebox_override("panel", sep_st)
	vbox.add_child(sep)

	# Descripcion (Gigante y super legible)
	_desc_lbl = Label.new()
	_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.custom_minimum_size = Vector2(0, 110)
	_desc_lbl.add_theme_font_size_override("font_size", 25)
	_desc_lbl.add_theme_color_override("font_color", C_TEXT)
	_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font: _desc_lbl.add_theme_font_override("font", _font)
	vbox.add_child(_desc_lbl)

	# Fila de control inferior (Progress label + Saltar + Siguiente)
	var bot_hbox = HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 18)
	vbox.add_child(bot_hbox)

	_step_lbl = Label.new()
	_step_lbl.add_theme_font_size_override("font_size", 24)
	_step_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	if _font: _step_lbl.add_theme_font_override("font", _font)
	bot_hbox.add_child(_step_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_hbox.add_child(spacer)

	# Boton SALTAR integrado (estilo plano, rojo)
	_skip_btn = Button.new()
	_skip_btn.text = "SALTAR"
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.flat = true
	_skip_btn.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	_skip_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5))
	_skip_btn.add_theme_font_size_override("font_size", 24)
	if _font: _skip_btn.add_theme_font_override("font", _font)
	_skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_btn.pressed.connect(_finish)
	bot_hbox.add_child(_skip_btn)

	# Boton Siguiente (dorado, gigante)
	_next_btn = Button.new()
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.custom_minimum_size = Vector2(120, 48)
	var nb_n = StyleBoxFlat.new()
	nb_n.bg_color = C_GOLD
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		nb_n.set("corner_radius_" + c, 12)
	var nb_h = nb_n.duplicate() as StyleBoxFlat
	nb_h.bg_color = Color(1.0, 0.88, 0.10)
	_next_btn.add_theme_stylebox_override("normal",  nb_n)
	_next_btn.add_theme_stylebox_override("hover",   nb_h)
	_next_btn.add_theme_stylebox_override("pressed", nb_n)
	_next_btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.07))
	_next_btn.add_theme_font_size_override("font_size", 24)
	if _font: _next_btn.add_theme_font_override("font", _font)
	_next_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_next_btn.pressed.connect(_on_next)
	bot_hbox.add_child(_next_btn)

# ─── OBTENER RECT DEL PHONE FRAME EN PANTALLA ────────────────────────────────
func _get_phone_rect() -> Rect2:
	if _phone_frame and is_instance_valid(_phone_frame):
		var gp = _phone_frame.global_position
		var sz = _phone_frame.size
		return Rect2(gp, sz)
	var vp = get_viewport().get_visible_rect().size
	return Rect2(Vector2(vp.x - 545, vp.y - 890), Vector2(520, 860))

# ─── MOSTRAR PASO ─────────────────────────────────────────────────────────────
func _show_step(index: int) -> void:
	if index >= _steps.size():
		_finish()
		return

	_current_step = index
	var step  = _steps[index]
	var phone = _get_phone_rect()          # Rect real del celular en pantalla
	var vp    = get_viewport().get_visible_rect().size

	_title_lbl.text = step["title"]
	_desc_lbl.text  = step["desc"]
	_next_btn.text  = step["next"]
	_step_lbl.text  = str(index + 1) + "/" + str(_steps.size())

	# Actualizar los 4 rectangulos de overlay para dejar el celular brillante
	_overlay_left.position = Vector2.ZERO
	_overlay_left.size     = Vector2(max(0, phone.position.x), vp.y)

	_overlay_right.position = Vector2(phone.position.x + phone.size.x, 0)
	_overlay_right.size     = Vector2(max(0, vp.x - (phone.position.x + phone.size.x)), vp.y)

	_overlay_top.position = Vector2(phone.position.x, 0)
	_overlay_top.size     = Vector2(phone.size.x, max(0, phone.position.y))

	_overlay_bottom.position = Vector2(phone.position.x, phone.position.y + phone.size.y)
	_overlay_bottom.size     = Vector2(phone.size.x, max(0, vp.y - (phone.position.y + phone.size.y)))

	# ── Anillo pulsante — posicion relativa al phone_frame ────────────────────
	var show_pulse: bool = step.get("show_pulse", false)
	_pulse_ring.visible = show_pulse
	var pulse_world := Vector2.ZERO

	if show_pulse:
		var anchor: Vector2 = step.get("target", Vector2(0.5, 0.5))
		pulse_world = Vector2(
			phone.position.x + phone.size.x * anchor.x,
			phone.position.y + phone.size.y * anchor.y
		)
		var rs: float = 70.0
		_pulse_ring.size     = Vector2(rs, rs)
		_pulse_ring.position = pulse_world - Vector2(rs * 0.5, rs * 0.5)
		_start_pulse()

	# ── Parpadeo de aplicacion / highlight ────────────────────────────────────
	if _blink_tween:
		_blink_tween.kill()

	if show_pulse:
		var bs: float = 114.0
		_blink_panel.size = Vector2(bs, bs)
		_blink_panel.position = pulse_world - Vector2(bs * 0.5, bs * 0.5)
		_blink_panel.visible = true

		_blink_panel.modulate.a = 0.0
		_blink_tween = create_tween().set_loops()
		_blink_tween.tween_property(_blink_panel, "modulate:a", 0.5, 0.25).set_ease(Tween.EASE_OUT)
		_blink_tween.tween_property(_blink_panel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	else:
		_blink_panel.visible = false

	# ── Globo Tooltip Gigante (Posicionado al lado del elemento) ─────────────
	var bubble_w: float = 720.0
	var bubble_h: float = 320.0
	var bubble_x: float = max(20.0, phone.position.x - bubble_w - 30.0)
	var bubble_y: float = 0.0

	if phone.position.x - bubble_w - 30.0 >= 15.0:
		# Hay espacio a la izquierda: alinear verticalmente con el punto pulsante o centro
		if show_pulse:
			bubble_y = pulse_world.y - bubble_h * 0.5
		else:
			bubble_y = phone.position.y + (phone.size.y - bubble_h) * 0.5
		bubble_y = clamp(bubble_y, 20.0, vp.y - bubble_h - 20.0)

		# Flecha apuntando a la derecha
		_arrow.visible = true
		_arrow.rotation_degrees = 45.0
		var target_arrow_y = pulse_world.y if show_pulse else phone.position.y + phone.size.y * 0.5
		_arrow.position = Vector2(
			bubble_x + bubble_w - 16.0,
			clamp(target_arrow_y - 16.0, bubble_y + 24.0, bubble_y + bubble_h - 40.0)
		)
	else:
		# Fallback: pantalla angosta, poner encima o debajo del celular
		bubble_w = phone.size.x - 20.0
		bubble_x = phone.position.x + 10.0
		var side = "top" if (not show_pulse or pulse_world.y > phone.position.y + phone.size.y * 0.4) else "bottom"
		if side == "top":
			var space_above = phone.position.y
			if space_above >= bubble_h + 8:
				bubble_y = phone.position.y - bubble_h - 8
			else:
				bubble_y = phone.position.y + 54
			# Flecha apuntando hacia abajo
			_arrow.visible = true
			_arrow.rotation_degrees = 45.0
			_arrow.position = Vector2(
				bubble_x + bubble_w * 0.5 - 16.0,
				bubble_y + bubble_h - 16.0
			)
		else:
			bubble_y = pulse_world.y + 46 if show_pulse else phone.position.y + phone.size.y * 0.5
			bubble_y = min(bubble_y, vp.y - bubble_h - 8)
			# Flecha apuntando hacia arriba
			_arrow.visible = true
			_arrow.rotation_degrees = 45.0
			_arrow.position = Vector2(
				bubble_x + bubble_w * 0.5 - 16.0,
				bubble_y - 16.0
			)

	_bubble.position = Vector2(bubble_x, bubble_y)
	_bubble.size     = Vector2(bubble_w, bubble_h)

	# Fade in en paralelo del globo y la flecha
	_bubble.modulate.a = 0.0
	_arrow.modulate.a = 0.0
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.18)
	tw.tween_property(_arrow, "modulate:a", 1.0, 0.18)

# ─── ANIMACION PULSANTE ───────────────────────────────────────────────────────
func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_pulse_ring, "modulate:a", 0.15, 0.50).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_pulse_ring, "modulate:a", 1.00, 0.50).set_ease(Tween.EASE_IN_OUT)

# ─── CALLBACKS ────────────────────────────────────────────────────────────────
func _on_next() -> void:
	_show_step(_current_step + 1)

func _finish() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	if _blink_tween:
		_blink_tween.kill()
	var DU = get_node_or_null("/root/DatosUsuario")
	if DU:
		DU.tutorial_celular_completado = true
		DU.save_local()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		tutorial_terminado.emit()
		queue_free()
	)
