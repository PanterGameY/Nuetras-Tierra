extends Control

const UI_FONT_SIZE := 55
const TITLE_FONT_SIZE := 90

# Paleta Moderna: Cyber-Amber, Dark-Slate & Royal-Blue
var _amber := Color(1.0, 0.75, 0.0, 1.0) # Ámbar vibrante
var _royal_blue := Color(0.25, 0.41, 0.88, 1.0) # Azul Rey
var _royal_glow := Color(0.4, 0.6, 1.0, 1.0)
var _dark_bg := Color(0.05, 0.05, 0.06, 0.98) 
var _dark_slate := Color(0.12, 0.12, 0.14, 1.0)
var _texto := Color(1.0, 1.0, 1.0, 1.0)

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var scroll: ScrollContainer = %Scroll
@onready var lbl_res: Label = %LblRes
@onready var lbl_porcentaje: Label = %ValPorc
@onready var btn_bajo: Button = %BtnBajo
@onready var btn_medio: Button = %BtnMedio
@onready var btn_alto: Button = %BtnAlto
@onready var check_sombras: CheckBox = %CheckSombras
@onready var check_sombra_vol: CheckBox = %CheckSombraVol
@onready var btn_restaurar: Button = %BtnRestaurar
@onready var btn_volver: Button = %BtnVolver
@onready var sep1: HSeparator = %Sep1
@onready var sep2: HSeparator = %Sep2
@onready var lbl_vol: Label = %LblVol
@onready var lbl_val_vol: Label = %ValVol
@onready var mute_box: CheckBox = %MuteBox
@onready var slider_vol: HSlider = %SldVol

func _ready() -> void:
	_aplicar_estilo()
	_cargar_configuracion()
	_connect_signals()

func _aplicar_estilo() -> void:
	_estilizar_panel()
	_estilizar_label(title_label, TITLE_FONT_SIZE, _amber)
	_estilizar_label(lbl_res, UI_FONT_SIZE, _texto)
	_estilizar_label(lbl_porcentaje, UI_FONT_SIZE, _amber)
	_estilizar_label(lbl_vol, UI_FONT_SIZE, _texto)
	_estilizar_label(lbl_val_vol, UI_FONT_SIZE, _royal_blue)
	_estilizar_checkbox_moderno(check_sombras)
	_estilizar_checkbox_moderno(check_sombra_vol)
	_estilizar_checkbox_mute_visual(mute_box)
	_estilizar_boton_moderno(btn_bajo, _dark_slate)
	_estilizar_boton_moderno(btn_medio, _dark_slate)
	_estilizar_boton_moderno(btn_alto, _amber)
	_estilizar_slider_ultragrueso(slider_vol)
	_estilizar_boton_moderno(btn_restaurar, _amber)
	_estilizar_boton_moderno(btn_volver, _dark_slate)
	_estilizar_separador(sep1)
	_estilizar_separador(sep2)
	_estilizar_scrollbar()

func _estilizar_panel() -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = _dark_bg
	sb.border_width_left = 6
	sb.border_color = _royal_blue
	sb.set_corner_radius_all(24)
	sb.corner_radius_top_left = 0
	sb.corner_radius_bottom_left = 0
	sb.content_margin_left = 60
	sb.content_margin_right = 60
	sb.content_margin_top = 50
	sb.content_margin_bottom = 50
	panel.add_theme_stylebox_override("panel", sb)

func _estilizar_boton_moderno(btn: Button, color: Color) -> void:
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = color
	sb_n.set_corner_radius_all(15)
	sb_n.content_margin_top = 22
	sb_n.content_margin_bottom = 22
	
	var sb_h = sb_n.duplicate()
	sb_h.bg_color = color.lightened(0.15)
	sb_h.border_width_bottom = 4
	sb_h.border_color = _royal_blue if color != _amber else _amber.lightened(0.3)
	
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_n)
	btn.add_theme_font_size_override("font_size", 50)
	btn.add_theme_color_override("font_color", _texto if color != _amber else _dark_bg)

func _estilizar_slider_ultragrueso(slider: HSlider) -> void:
	slider.custom_minimum_size = Vector2(0, 180)

	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = _royal_blue
	sb_fill.set_corner_radius_all(30)
	sb_fill.expand_margin_top = 35
	sb_fill.expand_margin_bottom = 35

	var sb_track = StyleBoxFlat.new()
	sb_track.bg_color = Color(0.08, 0.08, 0.1)
	sb_track.set_corner_radius_all(30)
	sb_track.expand_margin_top = 35
	sb_track.expand_margin_bottom = 35
	sb_track.border_width_left = 3
	sb_track.border_width_top = 3
	sb_track.border_width_right = 3
	sb_track.border_width_bottom = 3
	sb_track.border_color = Color(1,1,1,0.08)

	slider.add_theme_stylebox_override("fill", sb_fill)
	slider.add_theme_stylebox_override("slider", sb_track)
	slider.add_theme_stylebox_override("grabber_area", sb_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", sb_fill)
	
	# Usar una textura o color para que el punto sea más llamativo
	slider.add_theme_color_override("grabber_color", _royal_glow)
	slider.add_theme_color_override("grabber_highlight_color", Color.WHITE)

func _estilizar_checkbox_moderno(cb: CheckBox) -> void:
	cb.add_theme_font_size_override("font_size", 55)
	cb.custom_minimum_size.y = 120
	
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = Color(1, 1, 1, 0.03)
	sb_n.content_margin_left = 25
	sb_n.set_corner_radius_all(15)
	
	var sb_h = sb_n.duplicate()
	sb_h.bg_color = Color(1, 1, 1, 0.08)
	sb_h.border_width_left = 6
	sb_h.border_color = _royal_blue
	
	cb.add_theme_stylebox_override("normal", sb_n)
	cb.add_theme_stylebox_override("hover", sb_h)
	cb.add_theme_stylebox_override("pressed", sb_n)
	cb.add_theme_color_override("font_hover_color", _royal_glow)

func _estilizar_checkbox_mute_visual(cb: CheckBox) -> void:
	_estilizar_checkbox_moderno(cb)
	cb.custom_minimum_size.y = 140
	
	var update_text = func(pressed):
		if pressed:
			cb.text = "SONIDO: ACTIVADO [ON]"
			cb.add_theme_color_override("font_color", _royal_glow)
		else:
			cb.text = "SONIDO: SILENCIADO [OFF]"
			cb.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	cb.toggled.connect(update_text)
	update_text.call(cb.button_pressed)

func _estilizar_label(label: Label, p_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", p_size)
	label.add_theme_color_override("font_color", color)

func _estilizar_separador(sep: HSeparator) -> void:
	sep.add_theme_color_override("color", Color(_royal_blue.r, _royal_blue.g, _royal_blue.b, 0.3))

func _estilizar_scrollbar() -> void:
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0, 0, 0, 0.0)

	var sb_grabber = StyleBoxFlat.new()
	sb_grabber.bg_color = _dark_slate # Usando la nueva paleta
	sb_grabber.corner_radius_top_left = 6
	sb_grabber.corner_radius_top_right = 6
	sb_grabber.corner_radius_bottom_right = 6
	sb_grabber.corner_radius_bottom_left = 6

	scroll.add_theme_stylebox_override("bg", sb_bg)
	scroll.add_theme_stylebox_override("grabber", sb_grabber)
	scroll.add_theme_constant_override("scrollbar_width", 12)

func _estilizar_boton(btn: Button, color: Color) -> void:
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = _dark_slate # Usando la nueva paleta
	sb_n.border_width_left = 2
	sb_n.border_width_top = 2
	sb_n.border_width_right = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = Color(color.r, color.g, color.b, 0.45)
	sb_n.corner_radius_top_left = 14
	sb_n.corner_radius_top_right = 14
	sb_n.corner_radius_bottom_right = 14
	sb_n.corner_radius_bottom_left = 14
	sb_n.content_margin_top = 14
	sb_n.content_margin_bottom = 14
	sb_n.content_margin_left = 28
	sb_n.content_margin_right = 28

	var sb_h = StyleBoxFlat.new()
	sb_h.bg_color = Color(color.r, color.g, color.b, 0.15)
	sb_h.border_width_left = 2
	sb_h.border_width_top = 2
	sb_h.border_width_right = 2
	sb_h.border_width_bottom = 2
	sb_h.border_color = color
	sb_h.corner_radius_top_left = 14
	sb_h.corner_radius_top_right = 14
	sb_h.corner_radius_bottom_right = 14
	sb_h.corner_radius_bottom_left = 14
	sb_h.content_margin_top = 14
	sb_h.content_margin_bottom = 14
	sb_h.content_margin_left = 28
	sb_h.content_margin_right = 28

	var sb_p = sb_h.duplicate()
	sb_p.bg_color = Color(color.r, color.g, color.b, 0.25)
	sb_p.border_color = Color(color.r, color.g, color.b, 0.8)

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", _texto)
	btn.add_theme_font_size_override("font_size", UI_FONT_SIZE)

func _connect_signals() -> void:
	btn_bajo.pressed.connect(func(): _on_escala_resolucion(30))
	btn_medio.pressed.connect(func(): _on_escala_resolucion(70))
	btn_alto.pressed.connect(func(): _on_escala_resolucion(100))
	slider_vol.value_changed.connect(_on_volumen_changed)
	mute_box.toggled.connect(_on_mute_toggled)
	check_sombras.toggled.connect(_on_sombras)
	check_sombra_vol.toggled.connect(_on_sombra_vol)
	btn_restaurar.pressed.connect(_on_restaurar_pressed)
	btn_volver.pressed.connect(_on_volver_pressed)

func _cargar_configuracion() -> void:
	var cm = _get_cm()
	if not cm:
		_on_escala_resolucion(100)
		check_sombras.button_pressed = true
		check_sombra_vol.button_pressed = true
		slider_vol.value = 80
		lbl_val_vol.text = "80%"
		mute_box.button_pressed = true
		return

	var escala_val = cm.obtener("graficos", "escala_resolucion")
	if escala_val != null:
		_on_escala_resolucion(int(escala_val))
	else:
		_on_escala_resolucion(100)

	var vol_val = cm.obtener("audio", "volumen_general")
	if vol_val != null:
		slider_vol.value = int(vol_val)
		lbl_val_vol.text = str(int(vol_val)) + "%"
	else:
		slider_vol.value = 80
		lbl_val_vol.text = "80%"

	var mute_val = cm.obtener("audio", "mute")
	# Si mute_val es true, el checkbox debe estar DESMARCADO (porque el checkbox es "Sonido Activado")
	mute_box.button_pressed = not (mute_val == true)

	check_sombras.button_pressed = cm.obtener("graficos", "sombras") != false
	check_sombra_vol.button_pressed = cm.obtener("graficos", "sombra_volumetrica") == true

func _get_cm() -> Node:
	return get_tree().root.get_node_or_null("ConfigManager")

func _on_escala_resolucion(valor: float) -> void:
	var porc = int(valor)
	lbl_porcentaje.text = str(porc) + "%"
	
	# Actualizar estado visual de los botones
	_actualizar_botones_resolucion(porc)
	
	var cm = _get_cm()
	if cm:
		cm.establecer("graficos", "escala_resolucion", porc)
	
	# Aplicar escala 3D
	get_tree().root.scaling_3d_scale = maxf(0.25, porc / 100.0)

func _actualizar_botones_resolucion(porc_actual: int) -> void:
	# Definimos los estilos para estado activo e inactivo
	var sb_activo = StyleBoxFlat.new()
	sb_activo.bg_color = _amber
	sb_activo.set_corner_radius_all(15)
	sb_activo.border_width_bottom = 6
	sb_activo.border_color = _royal_blue
	
	var sb_inactivo = StyleBoxFlat.new()
	sb_inactivo.bg_color = _dark_slate
	sb_inactivo.set_corner_radius_all(15)
	
	# Aplicar a cada botón según el porcentaje
	btn_bajo.add_theme_stylebox_override("normal", sb_activo if porc_actual == 30 else sb_inactivo)
	btn_medio.add_theme_stylebox_override("normal", sb_activo if porc_actual == 70 else sb_inactivo)
	btn_alto.add_theme_stylebox_override("normal", sb_activo if porc_actual == 100 else sb_inactivo)
	
	# Color de fuente
	btn_bajo.add_theme_color_override("font_color", _dark_bg if porc_actual == 30 else _texto)
	btn_medio.add_theme_color_override("font_color", _dark_bg if porc_actual == 70 else _texto)
	btn_alto.add_theme_color_override("font_color", _dark_bg if porc_actual == 100 else _texto)

func _on_volumen_changed(valor: float) -> void:
	var porc = int(valor)
	lbl_val_vol.text = str(porc) + "%"
	var cm = _get_cm()
	if cm:
		cm.establecer("audio", "volumen_general", porc)
		if mute_box.button_pressed:
			cm._aplicar_audio()

func _on_mute_toggled(activado: bool) -> void:
	var cm = _get_cm()
	if activado: # Checkbox marcado = Sonido Activado
		AudioServer.set_bus_mute(0, false)
		if cm:
			cm.establecer("audio", "mute", false)
			cm._aplicar_audio()
	else: # Checkbox desmarcado = Mute
		AudioServer.set_bus_mute(0, true)
		if cm: cm.establecer("audio", "mute", true)

func _on_sombras(pressed: bool) -> void:
	var cm = _get_cm()
	if cm:
		cm.establecer("graficos", "sombras", pressed)
	_aplicar_sombras(pressed)

func _on_sombra_vol(pressed: bool) -> void:
	var cm = _get_cm()
	if cm:
		cm.establecer("graficos", "sombra_volumetrica", pressed)
	_aplicar_sombra_vol(pressed)

func _on_restaurar_pressed() -> void:
	var cm = _get_cm()
	if cm:
		cm.restaurar_defectos()
	_cargar_configuracion()

func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _aplicar_sombras(enabled: bool) -> void:
	var d_lights = []
	_find_directional_lights(get_tree().root, d_lights)
	for dl in d_lights:
		if dl is DirectionalLight3D:
			dl.shadow_enabled = enabled
	get_viewport().positional_shadow_atlas_size = 2048 if enabled else 0

func _aplicar_sombra_vol(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("world_environment"):
		if node is WorldEnvironment and node.environment:
			node.environment.volumetric_fog_enabled = enabled

func _find_directional_lights(node: Node, result: Array) -> void:
	if node is DirectionalLight3D:
		result.append(node)
	for child in node.get_children():
		_find_directional_lights(child, result)
