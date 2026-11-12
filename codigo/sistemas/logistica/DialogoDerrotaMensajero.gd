# DialogoDerrotaMensajero.gd - Panel modal interactivo de derrota premium con estética Glassmorphic Neon
extends CanvasLayer

signal opcion_seleccionada(opcion: String)

# --- Elementos Visuales del Diálogo ---
var panel_fondo: PanelContainer = null
var moderniz_font: Font = null

func _ready() -> void:
	# Cargar la tipografía corporativa Moderniz
	var path_font = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(path_font):
		moderniz_font = load(path_font)

	# Control de velo oscurecedor de fondo
	var velo = ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.0, 0.65)
	velo.anchors_preset = Control.PRESET_FULL_RECT
	add_child(velo)

	# Contenedor principal del diálogo interactivo
	panel_fondo = PanelContainer.new()
	panel_fondo.custom_minimum_size = Vector2(1100, 680)
	panel_fondo.anchors_preset = Control.PRESET_CENTER
	panel_fondo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_fondo.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Estilo Glassmorphic con bordes Naranja Neon de Nuestra Tierra
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.90) # Fondo oscuro traslúcido
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(1.00, 0.45, 0.00, 0.80) # Naranja Neon
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(1.00, 0.45, 0.00, 0.15)
	style.shadow_size = 35
	panel_fondo.add_theme_stylebox_override("panel", style)
	add_child(panel_fondo)

	# Margen de espaciado interno
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 50)
	margin_container.add_theme_constant_override("margin_top", 50)
	margin_container.add_theme_constant_override("margin_right", 50)
	margin_container.add_theme_constant_override("margin_bottom", 50)
	panel_fondo.add_child(margin_container)

	# Distribución vertical del contenido
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 35)
	margin_container.add_child(vbox)

	# Título principal de Derrota (Legibilidad móvil alta de 48px)
	var label_titulo = Label.new()
	label_titulo.text = "TRABAJO FALLIDO"
	label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titulo.add_theme_color_override("font_color", Color(1.00, 0.35, 0.00))
	if moderniz_font:
		label_titulo.add_theme_font_override("font", moderniz_font)
	label_titulo.add_theme_font_size_override("font_size", 54)
	vbox.add_child(label_titulo)

	# Mensaje descriptivo (Cuerpo de texto grande de 28px)
	var label_desc = Label.new()
	label_desc.text = "El límite de tiempo para retornar el vehículo a la base de mensajería ha expirado.\nEl furgón ha sido remolcado y el despacho ha sido penalizado."
	label_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.93))
	label_desc.add_theme_font_size_override("font_size", 28)
	vbox.add_child(label_desc)

	# Espacio de separación
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Distribución de botones de acción
	var vbox_btn = VBoxContainer.new()
	vbox_btn.add_theme_constant_override("separation", 20)
	vbox.add_child(vbox_btn)

	# 1. Botón REINTENTAR RUTA
	var btn_retry = _crear_boton_accion("REINTENTAR RUTA", Color(0.12, 0.58, 0.95, 0.15), Color(0.12, 0.58, 0.95))
	btn_retry.pressed.connect(func(): _seleccionar("REINTENTAR"))
	vbox_btn.add_child(btn_retry)

	# 2. Botón VOLVER A LA BASE (Con costo de remolque)
	var btn_tow = _crear_boton_accion("RETORNAR CON GRUA (-$100)", Color(0.95, 0.70, 0.00, 0.15), Color(0.95, 0.70, 0.00))
	btn_tow.pressed.connect(func(): _seleccionar("RECOGER"))
	vbox_btn.add_child(btn_tow)

	# 3. Botón CANCELAR TRABAJO
	var btn_cancel = _crear_boton_accion("ABANDONAR RUTA", Color(0.95, 0.15, 0.12, 0.15), Color(0.95, 0.15, 0.12))
	btn_cancel.pressed.connect(func(): _seleccionar("CANCELAR"))
	vbox_btn.add_child(btn_cancel)

	# --- Animación de Entrada Suave (Tween) ---
	panel_fondo.modulate.a = 0.0
	panel_fondo.scale = Vector2(0.85, 0.85)
	panel_fondo.pivot_offset = panel_fondo.custom_minimum_size / 2.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel_fondo, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_fondo, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _crear_boton_accion(texto: String, color_fondo: Color, color_borde: Color) -> Button:
	var btn = Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(0, 80) # Altura de 80px requerida por diseño UI
	
	# Estilo por defecto
	var style = StyleBoxFlat.new()
	style.bg_color = color_fondo
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color_borde
	style.corner_radius_top_left = 12 # Radio de 12px por diseño UI
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)
	
	# Estilo al pasar el cursor (Hover)
	var style_hover = style.duplicate() as StyleBoxFlat
	style_hover.bg_color = color_borde
	style_hover.bg_color.a = 0.35
	btn.add_theme_stylebox_override("hover", style_hover)
	
	# Estilo presionado
	var style_pressed = style.duplicate() as StyleBoxFlat
	style_pressed.bg_color = color_borde
	style_pressed.bg_color.a = 0.60
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# Fuente Moderniz a 32px
	if moderniz_font:
		btn.add_theme_font_override("font", moderniz_font)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	
	return btn

func _seleccionar(opcion: String) -> void:
	# Animación de salida suave antes de destruir el diálogo
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel_fondo, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel_fondo, "scale", Vector2(0.85, 0.85), 0.25).set_trans(Tween.TRANS_SINE)
	await tween.finished
	emit_signal("opcion_seleccionada", opcion)
	queue_free()
