extends CharacterBody3D

# --- Exportaciones para personalizar desde el Inspector ---
@export var dialogo_recurso: DialogueData
@export_range(0.1, 5.0) var velocidad_escritura: float = 1.0
@export var distancia_interaccion: float = 4.0

# --- Nodos ---
@onready var ui_container = $CanvasLayer/Control2
@onready var label = $CanvasLayer/Control2/RichTextLabel
@onready var options_container = $CanvasLayer/Control2/Options
@onready var anim_player: AnimationPlayer = $npc1/AnimationPlayer

# --- Variables de Control ---
var esta_hablando: bool = false
var anim_idle: String = ""
var anim_talk: String = ""
var dialog_history: Array = []
var _current_raw_text: String = ""
var _current_con_opciones: bool = false
var _current_group: String = ""

func _ready():
	_setup_ui()
	_analyze_animations()
	_connect_signals()

func _setup_ui():
	ui_container.hide()
	
	# Forzar el posicionamiento del contenedor de diálogo en la parte inferior centrado, al estilo premium
	if ui_container is Control:
		ui_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		ui_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
		ui_container.custom_minimum_size = Vector2(0, 360)
		# Añadir margen inferior
		ui_container.offset_bottom = -40
		ui_container.offset_left = 120
		ui_container.offset_right = -120
		ui_container.offset_top = -400

	# Buscar elementos de fondo por defecto (como texturas azules o NinePatch) para ocultarlos o re-estilizarlos
	var bg_patch = ui_container.get_node_or_null("NinePatchRect")
	if bg_patch and bg_patch is NinePatchRect:
		bg_patch.visible = false
	var bg_tex = ui_container.get_node_or_null("TextureRect")
	if bg_tex and bg_tex is TextureRect:
		bg_tex.visible = false

	# Crear o re-estilizar un panel de fondo oscuro semi-transparente premium con borde dorado neón
	var custom_bg = ui_container.get_node_or_null("CustomPremiumBG")
	if not custom_bg:
		var panel = Panel.new()
		panel.name = "CustomPremiumBG"
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.show_behind_parent = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.06, 0.94) # Negro azulado profundo
		style.border_color = Color(0.95, 0.80, 0.00, 1.00) # Dorado neón
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.corner_radius_bottom_right = 20
		style.corner_radius_bottom_left = 20
		style.set_content_margin_all(24)
		panel.add_theme_stylebox_override("panel", style)
		
		ui_container.add_child(panel)
		ui_container.move_child(panel, 0)

	# Configuración crítica para RichTextLabel
	label.bbcode_enabled = true
	label.selection_enabled = false
	label.deselect_on_focus_loss_enabled = false
	# Ajustar posición del texto dentro del nuevo panel
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 40
	label.offset_right = -40
	label.offset_top = 40
	label.offset_bottom = 180
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Forzar color blanco para el texto sobre el fondo oscuro premium
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.98))

	# Ajustar posición del contenedor de opciones
	if options_container is Control:
		options_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		options_container.offset_left = 60
		options_container.offset_right = -60
		options_container.offset_bottom = -30
		options_container.offset_top = -140

	# Aseguramos que el contenedor de opciones esté limpio
	for child in options_container.get_children():
		child.hide()

func _analyze_animations():
	if not anim_player: return
	var list = anim_player.get_animation_list()
	for a in list:
		var n = a.to_lower()
		if n.contains("talk") or n.contains("habl"): anim_talk = a
		if n.contains("idle") or n.contains("espera"): anim_idle = a
	
	if anim_idle: anim_player.play(anim_idle)

func _connect_signals():
	# Conexión automática por Area3D
	var area = $Area3D
	area.body_entered.connect(Callable(self, "_on_player_enter"))
	area.body_exited.connect(Callable(self, "_on_player_exit"))

# --- Lógica de Interacción ---

func _on_player_enter(body):
	# Si este NPC tiene el controlador de mensajería, dejar que BaseMensajero maneje los diálogos y abortar
	if has_node("BaseMensajero") or get_node_or_null("BaseMensajero") != null:
		return
		
	if body.is_in_group("jugador") and dialogo_recurso:
		# iniciar en el grupo inicial definido en el recurso
		_current_group = ""
		if dialogo_recurso and dialogo_recurso.opcion_inicial_grupo:
			_current_group = dialogo_recurso.opcion_inicial_grupo
		iniciar_dialogo(dialogo_recurso.texto_inicial, true)

func _on_player_exit(body):
	if has_node("BaseMensajero") or get_node_or_null("BaseMensajero") != null:
		return
	if body.is_in_group("jugador"):
		cerrar_dialogo()

func iniciar_dialogo(texto: String, con_opciones: bool):
	esta_hablando = true
	ui_container.show()
	
	# Formateo Pro con fuente Moderniz.otf
	var font_path = "res://recursos/fonts/Moderniz.otf"
	var font_tag = "[font=\"%s\"]" % font_path if ResourceLoader.exists(font_path) else ""
	var font_end = "[/font]" if font_tag != "" else ""

	var npc_nombre_val = "NPC"
	if dialogo_recurso:
		npc_nombre_val = dialogo_recurso.npc_nombre

	var header = "[center][b]%s[font_size=56]%s[/font_size]%s[/b][/center]\n" % [font_tag, npc_nombre_val, font_end]
	var body = "[center]%s[font_size=46]%s[/font_size]%s[/center]" % [font_tag, texto, font_end]
	label.text = header + body

	# Guardar estado actual para poder retroceder
	_current_raw_text = texto
	_current_con_opciones = con_opciones
	
	# Reiniciar Animaciones de UI
	label.visible_ratio = 0.0
	options_container.hide()
	
	# Tween de entrada (Pop y Escritura)
	var t = create_tween().set_parallel(true)
	ui_container.scale = Vector2(0.7, 0.7)
	var _cur_mod = ui_container.modulate
	_cur_mod.a = 0.0
	ui_container.modulate = _cur_mod

	t.tween_property(ui_container, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	var _target_mod = Color(ui_container.modulate.r, ui_container.modulate.g, ui_container.modulate.b, 1.0)
	t.tween_property(ui_container, "modulate", _target_mod, 0.3)
	
	var t_text = create_tween()
	var dur = (texto.length() * 0.03) / velocidad_escritura
	# Animar sólo la etiqueta principal (texto negro)
	t_text.tween_property(label, "visible_ratio", 1.0, dur)
	
	# Animación del 3D
	if anim_talk: anim_player.play(anim_talk)
	
	await t_text.finished
	if con_opciones:
		_mostrar_opciones()
	if anim_idle: anim_player.play(anim_idle, 0.5) # Transición suave a idle

func _mostrar_opciones():
	# Limpiar botones viejos
	for child in options_container.get_children():
		child.queue_free()
	
	options_container.show()
	
	# Crear botones dinámicamente según el Recurso
	# Mejor organización: agrupar botones en una columna dentro del contenedor
	var vbox = VBoxContainer.new()
	vbox.name = "OptionsVBox"
	vbox.custom_minimum_size = Vector2(300, 0)

	# Estilos reutilizables para los botones
	var sb_btn_n = StyleBoxFlat.new()
	sb_btn_n.bg_color = Color(0.94, 0.94, 0.94, 1)
	sb_btn_n.border_width_left = 1
	sb_btn_n.border_width_top = 1
	sb_btn_n.border_width_right = 1
	sb_btn_n.border_width_bottom = 1
	sb_btn_n.border_color = Color(0, 0, 0, 0.12)
	sb_btn_n.corner_radius_top_left = 10
	sb_btn_n.corner_radius_top_right = 10
	sb_btn_n.corner_radius_bottom_right = 10
	sb_btn_n.corner_radius_bottom_left = 10
	sb_btn_n.content_margin_left = 12
	sb_btn_n.content_margin_right = 12
	sb_btn_n.content_margin_top = 8
	sb_btn_n.content_margin_bottom = 8

	var sb_btn_h = StyleBoxFlat.new()
	sb_btn_h.bg_color = Color(0.88, 0.88, 0.9, 1)
	sb_btn_h.border_width_left = 1
	sb_btn_h.border_width_top = 1
	sb_btn_h.border_width_right = 1
	sb_btn_h.border_width_bottom = 1
	sb_btn_h.border_color = Color(0, 0, 0, 0.18)
	sb_btn_h.corner_radius_top_left = 10
	sb_btn_h.corner_radius_top_right = 10
	sb_btn_h.corner_radius_bottom_right = 10
	sb_btn_h.corner_radius_bottom_left = 10

	# Crear botón de "Volver" si hay historial
	if dialog_history.size() > 0:
		var back_btn = Button.new()
		back_btn.text = "Volver"
		back_btn.custom_minimum_size = Vector2(0, 64)
		back_btn.add_theme_font_size_override("font_size", 30)
		back_btn.add_theme_color_override("font_color", Color(0, 0, 0))
		back_btn.add_theme_stylebox_override("normal", sb_btn_n)
		back_btn.add_theme_stylebox_override("hover", sb_btn_h)
		back_btn.add_theme_stylebox_override("pressed", sb_btn_h)
		back_btn.focus_mode = Control.FOCUS_ALL
		back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		back_btn.pressed.connect(Callable(self, "_on_back_pressed"))
		vbox.add_child(back_btn)

	# Obtener lista de opciones según el grupo actual (si está definido)
	var opciones_list: Array = []
	if _current_group != "" and dialogo_recurso.opciones_por_grupo.has(_current_group):
		opciones_list = dialogo_recurso.opciones_por_grupo[_current_group]
	else:
		opciones_list = dialogo_recurso.opciones.keys()

	for opcion_texto in opciones_list:
		var btn = Button.new()
		btn.text = opcion_texto
		# Estilo para móvil
		btn.custom_minimum_size = Vector2(0, 84)
		btn.add_theme_font_size_override("font_size", 34)
		btn.add_theme_color_override("font_color", Color(0, 0, 0))
		# Asegurar que el botón responda a clicks y pueda recibir foco
		if btn is Control:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.focus_mode = Control.FOCUS_ALL
		# Aplicar estilo
		btn.add_theme_stylebox_override("normal", sb_btn_n)
		btn.add_theme_stylebox_override("hover", sb_btn_h)
		btn.add_theme_stylebox_override("pressed", sb_btn_h)
		# Conectar usando la forma clásica: bindear el argumento en el Callable
		btn.pressed.connect(Callable(self, "_on_option_selected").bind(opcion_texto))
		vbox.add_child(btn)
		print_debug("[NPC] Botón creado:", opcion_texto)

	# Añadir la columna de botones al contenedor de opciones
	options_container.add_child(vbox)

func _on_option_selected(opcion_nombre: String):
	print("[NPC] _on_option_selected ->", opcion_nombre)
	# Guardar estado actual para poder volver atras (incluye grupo)
	dialog_history.append({"texto": _current_raw_text, "con_opciones": _current_con_opciones, "group": _current_group})
	var respuesta = ""
	if dialogo_recurso.opciones.has(opcion_nombre):
		respuesta = dialogo_recurso.opciones[opcion_nombre]
	# Si la opción define un siguiente grupo, navega a él y muestra opciones
	if dialogo_recurso.siguiente_grupo_por_opcion.has(opcion_nombre):
		_current_group = dialogo_recurso.siguiente_grupo_por_opcion[opcion_nombre]
		iniciar_dialogo(respuesta, true)
	else:
		iniciar_dialogo(respuesta, false)
	# Disparar acciones del trabajo de mensajería si la opción seleccionada coincide
	var base_mensajero = get_node_or_null("BaseMensajero")
	if not base_mensajero:
		# Buscar en los hijos
		for child in get_children():
			if child is BaseMensajero:
				base_mensajero = child
				break
	
	if base_mensajero:
		var opt_lower = opcion_nombre.to_lower()
		if opt_lower.contains("iniciar") or opt_lower.contains("aceptar") or opt_lower.contains("comenzar"):
			print("[NPC Dialogue Action] Disparando dialog_accion_iniciar()")
			base_mensajero.call("dialog_accion_iniciar")
		elif opt_lower.contains("cobrar") or opt_lower.contains("entregar") or opt_lower.contains("terminar") or opt_lower.contains("reclamar"):
			print("[NPC Dialogue Action] Disparando dialog_accion_cobrar()")
			base_mensajero.call("dialog_accion_cobrar")
		elif opt_lower.contains("cancelar"):
			print("[NPC Dialogue Action] Disparando dialog_accion_cancelar()")
			base_mensajero.call("dialog_accion_cancelar")


func _on_back_pressed():
	if dialog_history.size() == 0:
		return
	var last = dialog_history.pop_back()
	if "group" in last:
		_current_group = last["group"]
	iniciar_dialogo(last["texto"], last["con_opciones"])

func cerrar_dialogo():
	esta_hablando = false
	var t = create_tween()
	t.tween_property(ui_container, "scale", Vector2(0.8, 0.8), 0.2)
	var _close_mod = Color(ui_container.modulate.r, ui_container.modulate.g, ui_container.modulate.b, 0.0)
	t.parallel().tween_property(ui_container, "modulate", _close_mod, 0.2)
	await t.finished
	ui_container.hide()
	if anim_idle: anim_player.play(anim_idle, 0.5)
