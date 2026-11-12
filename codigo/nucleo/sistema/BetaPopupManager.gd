extends CanvasLayer

# --- CONFIGURACION ---
const RUTA_FUENTE = "res://recursos/fonts/Moderniz.otf"
const TITULO_MENSAJE = "¡BIENVENIDO A LA BETA!"

# Texto modificado para no usar tildes 
const TEXTO_MENSAJE = "Esperamos que te encuentres muy bien.\n\nEsta version de Nuestra Tierra Job Simulator esta enfocada exclusivamente en pruebas para las mecanicas del trabajo de mensajero.\n\nTu feedback es vital para nosotros, asi que cualquier comentario o sugerencia sera de gran ayuda. Ademas, si eres creador de contenido, ¡nos encantaria ver tus videos jugando esta version!\n\n¡Gracias por tu apoyo y a rodar!"
const COLOR_FONDO_TRASLUCIDO = Color(0, 0, 0, 0.85) 

var _boton_cerrar: Button

func _ready():
	layer = 128 
	visible = false 
	process_mode = Node.PROCESS_MODE_ALWAYS

	var fuente_personalizada = load(RUTA_FUENTE)
	if not fuente_personalizada:
		push_warning("No se encontro la fuente en la ruta: " + RUTA_FUENTE)

	# 1. Crear el nodo de control principal
	var control_nodo = Control.new()
	control_nodo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(control_nodo)

	# 2. Fondo negro traslucido
	var color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = COLOR_FONDO_TRASLUCIDO
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP 
	control_nodo.add_child(color_rect)

	# 3. Margen principal adaptativo
	var margen_pantalla = MarginContainer.new()
	margen_pantalla.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Margenes un poco mas amplios para que no ocupe toda, toda la pantalla
	margen_pantalla.add_theme_constant_override("margin_left", 60)
	margen_pantalla.add_theme_constant_override("margin_right", 60)
	margen_pantalla.add_theme_constant_override("margin_top", 100)
	margen_pantalla.add_theme_constant_override("margin_bottom", 100)
	control_nodo.add_child(margen_pantalla)

	# 4. Crear el Panel Central
	var panel_central = PanelContainer.new()
	panel_central.size_flags_vertical = Control.SIZE_SHRINK_CENTER 
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14, 1.0) 
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.4, 0.7, 1.0, 0.5) 
	panel_style.corner_radius_top_left = 25
	panel_style.corner_radius_top_right = 25
	panel_style.corner_radius_bottom_left = 25
	panel_style.corner_radius_bottom_right = 25
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 20
	panel_central.add_theme_stylebox_override("panel", panel_style)
	
	margen_pantalla.add_child(panel_central)

	# 5. Margenes internos del texto
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_top", 40)
	margin_container.add_theme_constant_override("margin_bottom", 40)
	margin_container.add_theme_constant_override("margin_left", 40)
	margin_container.add_theme_constant_override("margin_right", 40)
	panel_central.add_child(margin_container)
	
	var vbox_content = VBoxContainer.new()
	vbox_content.add_theme_constant_override("separation", 35) 
	margin_container.add_child(vbox_content)

	# 6. Titulo - Tamaño equilibrado
	var label_titulo = Label.new()
	label_titulo.text = TITULO_MENSAJE
	label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_titulo.add_theme_font_override("font", fuente_personalizada)
	label_titulo.add_theme_font_size_override("font_size", 40) # Ajustado (antes 65)
	label_titulo.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) 
	vbox_content.add_child(label_titulo)

	var separador = HSeparator.new()
	vbox_content.add_child(separador)

	# 7. Texto Principal - Tamaño comodo para leer en movil
	var label_texto = Label.new()
	label_texto.text = TEXTO_MENSAJE
	label_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_texto.add_theme_font_override("font", fuente_personalizada)
	label_texto.add_theme_font_size_override("font_size", 28) # Ajustado (antes 40)
	label_texto.add_theme_constant_override("line_spacing", 10)
	vbox_content.add_child(label_texto)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_content.add_child(spacer)

	# 8. Boton - Mantiene buen grosor pero sin exagerar
	_boton_cerrar = Button.new()
	_boton_cerrar.text = "ENTENDIDO, A RODAR" # Sin signos de exclamacion iniciales por si la fuente falla
	_boton_cerrar.custom_minimum_size = Vector2(0, 80) # Altura ajustada (antes 120)
	_boton_cerrar.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	_boton_cerrar.add_theme_font_override("font", fuente_personalizada)
	_boton_cerrar.add_theme_font_size_override("font_size", 30) # Ajustado (antes 45)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.5, 0.8, 1.0) 
	btn_normal.corner_radius_top_left = 15
	btn_normal.corner_radius_top_right = 15
	btn_normal.corner_radius_bottom_left = 15
	btn_normal.corner_radius_bottom_right = 15
	_boton_cerrar.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.3, 0.6, 0.9, 1.0) 
	_boton_cerrar.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.4, 0.7, 1.0) 
	_boton_cerrar.add_theme_stylebox_override("pressed", btn_pressed)

	vbox_content.add_child(_boton_cerrar)
	_boton_cerrar.pressed.connect(_on_boton_cerrar_pressed)

	call_deferred("mostrar_mensaje_beta")

# --- FUNCIONES ---

func mostrar_mensaje_beta():
	if visible: return 
	
	visible = true
	get_tree().paused = true
	_boton_cerrar.grab_focus()

func _on_boton_cerrar_pressed():
	visible = false
	get_tree().paused = false