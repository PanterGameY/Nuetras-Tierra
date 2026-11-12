extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════
# IntroCinematic.gd — Cinemática inicial de historia y tutorial de UIPie
# ═══════════════════════════════════════════════════════════════════════

var player: CharacterBody3D = null
var ui_pie: CanvasLayer = null

# Estado
var state: int = 0 # 0: Intro/Cine, 1: Tutorial Joystick, 2: Tutorial Camara, 3: Tutorial Salto, 4: Fin
var elapsed_time: float = 0.0
var state_elapsed_time: float = 0.0
var text_timer: float = 0.0
var current_text_index: int = 0
var type_index: float = 0.0

var story_texts = [
	"BIENVENIDO A NUESTRA TIERRA!",
	"ACABAS DE LLEGAR A LA GRAN CIUDAD...",
	"DESPUES DE HABER PASADO POR MOMENTOS MUY DIFICILES EN LA VIDA...",
	"DECIDES QUE ES HORA DE RETOMAR EL RUMBO Y PROBAR NUEVAS FORMAS DE TRABAJO.",
	"ESTE ES TU NUEVO COMIENZO, ADELANTE!"
]

# Nodos de UI creados programáticamente
var overlay: ColorRect
var subtitle_label: Label
var tutorial_panel: PanelContainer
var tutorial_label: Label
var pointer_guide: ColorRect
var _font: FontFile = null

# Detección para el tutorial
var initial_yaw: float = 0.0
var joystick_moved: bool = false
var camera_moved: bool = false
var player_jumped: bool = false

func _ready() -> void:
	print("[IntroCinematic] _ready() inicializado.")
	_font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	player = get_parent() as CharacterBody3D
	if not player:
		print("[IntroCinematic] ERROR: El padre del nodo no es de tipo CharacterBody3D.")
		queue_free()
		return
	
	# Activar flag de cinemática activa en el jugador
	player.set_meta("cinematic_active", true)
	player.permitir_teclado_movimiento = false
	
	# Buscar el UIPie en el jugador o la escena
	ui_pie = player.get("ui_pie") as CanvasLayer
	if not ui_pie:
		ui_pie = get_tree().current_scene.find_child("UIpie", true, false) as CanvasLayer
	print("[IntroCinematic] UIPie encontrado: ", ui_pie != null)
	
	# Ocultar la UI táctil durante la cinemática
	if ui_pie:
		ui_pie.visible = false

	# Crear la interfaz de usuario de la cinemática
	_setup_ui()

	# Configurar cámara inicial
	if player.get("spring_arm"):
		player.spring_arm.spring_length = 4.5
		player.set("_camara_pitch", -0.15) # Mirar levemente hacia abajo

func _setup_ui() -> void:
	layer = 10 # Asegurar que esté por encima de la UI del juego
	print("[IntroCinematic DEBUG] Configurando UI...")
	
	# 1. Overlay oscuro (Cinebars y desvanecimiento) - AHORA MUCHO MÁS CLARO
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.18) # Menos oscuro para que la ciudad sea visible
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	print("[IntroCinematic DEBUG] Overlay agregado y posicionado. Size: ", overlay.size)

	# 2. Franjas cinematográficas (Arriba y Abajo)
	var bar_top = ColorRect.new()
	bar_top.color = Color(0, 0, 0, 0.9) # Sutil transparencia en las barras
	bar_top.custom_minimum_size = Vector2(0, 90)
	overlay.add_child(bar_top)
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	
	var bar_bottom = ColorRect.new()
	bar_bottom.color = Color(0, 0, 0, 0.9)
	bar_bottom.custom_minimum_size = Vector2(0, 120)
	overlay.add_child(bar_bottom)
	bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

	# 3. Label para subtítulos narrativos (con estilo dorado y Moderniz)
	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	subtitle_label.add_theme_font_size_override("font_size", 28)
	subtitle_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.00)) # Oro del juego
	subtitle_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	subtitle_label.add_theme_constant_override("shadow_offset_x", 3)
	subtitle_label.add_theme_constant_override("shadow_offset_y", 3)
	subtitle_label.add_theme_constant_override("shadow_outline_size", 2)
	if _font:
		subtitle_label.add_theme_font_override("font", _font)
	
	overlay.add_child(subtitle_label)
	subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_label.offset_left = 0
	subtitle_label.offset_right = 0
	subtitle_label.offset_top = -110
	subtitle_label.offset_bottom = -10

	# 4. Panel de tutorial (diseño oscuro/dorado igual que taller y celular)
	tutorial_panel = PanelContainer.new()
	tutorial_panel.visible = false
	add_child(tutorial_panel)
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tutorial_panel.offset_top = 130
	tutorial_panel.custom_minimum_size = Vector2(700, 110)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.92) # Fondo oscuro
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.80, 0.00, 1.00) # Borde dorado
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.60)
	style.shadow_size = 25
	tutorial_panel.add_theme_stylebox_override("panel", style)

	tutorial_label = Label.new()
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.add_theme_font_size_override("font_size", 25)
	tutorial_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	tutorial_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	tutorial_label.add_theme_constant_override("shadow_offset_x", 1)
	tutorial_label.add_theme_constant_override("shadow_offset_y", 1)
	if _font:
		tutorial_label.add_theme_font_override("font", _font)
	tutorial_panel.add_child(tutorial_label)

	# 5. Puntero guía visual tipo radar/holo (táctil)
	pointer_guide = ColorRect.new()
	pointer_guide.visible = false
	pointer_guide.custom_minimum_size = Vector2(80, 80)
	pointer_guide.color = Color(0, 0, 0, 0) # Transparente al fondo
	add_child(pointer_guide)
	
	# Anillo principal (grosor y color)
	var p_style = StyleBoxFlat.new()
	p_style.draw_center = false
	p_style.border_width_left = 3
	p_style.border_width_top = 3
	p_style.border_width_right = 3
	p_style.border_width_bottom = 3
	p_style.border_color = Color(0.95, 0.80, 0.00, 1.00) # Dorado del juego
	p_style.corner_radius_top_left = 40
	p_style.corner_radius_top_right = 40
	p_style.corner_radius_bottom_left = 40
	p_style.corner_radius_bottom_right = 40
	p_style.shadow_color = Color(0.95, 0.80, 0.00, 0.35)
	p_style.shadow_size = 8
	
	# Anillo interno decorativo
	var p_style_inner = StyleBoxFlat.new()
	p_style_inner.draw_center = true
	p_style_inner.bg_color = Color(0.95, 0.80, 0.00, 0.15)
	p_style_inner.border_width_left = 1
	p_style_inner.border_width_top = 1
	p_style_inner.border_width_right = 1
	p_style_inner.border_width_bottom = 1
	p_style_inner.border_color = Color(1.0, 1.0, 1.0, 0.4)
	p_style_inner.corner_radius_top_left = 30
	p_style_inner.corner_radius_top_right = 30
	p_style_inner.corner_radius_bottom_left = 30
	p_style_inner.corner_radius_bottom_right = 30
	
	var p_panel_inner = Panel.new()
	pointer_guide.add_child(p_panel_inner)
	p_panel_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_panel_inner.offset_left = 8
	p_panel_inner.offset_top = 8
	p_panel_inner.offset_right = -8
	p_panel_inner.offset_bottom = -8
	p_panel_inner.add_theme_stylebox_override("panel", p_style_inner)
	
	var p_panel = Panel.new()
	pointer_guide.add_child(p_panel)
	p_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_panel.add_theme_stylebox_override("panel", p_style)
	print("[IntroCinematic DEBUG] UI completamente configurada.")

func _process(delta: float) -> void:
	elapsed_time += delta
	state_elapsed_time += delta
	
	# Rotación lenta de cámara durante la cinemática
	if state == 0:
		var current_yaw = player.get("_camara_yaw") as float
		player.set("_camara_yaw", current_yaw + delta * 0.18) # Velocidad suave
		_procesar_subtitulos(delta)
	
	elif state == 1:
		# Tutorial de Joystick
		_animar_guia(delta)
		var idir = player.call("_get_idir") as Vector2
		if idir.length() > 0.25:
			joystick_moved = true
			_avanzar_estado()

	elif state == 2:
		# Tutorial de Cámara
		_animar_guia(delta)
		var yaw = player.get("_camara_yaw") as float
		if abs(yaw - initial_yaw) > 0.4:
			camera_moved = true
			_avanzar_estado()

	elif state == 3:
		# Tutorial de Salto
		_animar_guia(delta)
		if not player.is_on_floor() or player.velocity.y > 1.5:
			player_jumped = true
			_avanzar_estado()

func _procesar_subtitulos(delta: float) -> void:
	text_timer += delta
	var current_text = story_texts[current_text_index]
	
	# Efecto máquina de escribir
	if type_index < current_text.length():
		type_index += delta * 38.0 # Velocidad de las letras
		subtitle_label.text = current_text.substr(0, int(type_index))
	
	# Pausa entre textos
	if text_timer > 3.8:
		text_timer = 0.0
		type_index = 0.0
		current_text_index += 1
		
		# Fin de la cinemática
		if current_text_index >= story_texts.size():
			_avanzar_estado()

func _avanzar_estado() -> void:
	state += 1
	print("[IntroCinematic DEBUG] Estado avanzado a: ", state)
	text_timer = 0.0
	type_index = 0.0
	state_elapsed_time = 0.0
	
	if state == 1:
		# Iniciar tutorial: quitar overlay cinemático y encender UI
		overlay.visible = false
		if ui_pie:
			ui_pie.visible = true
		
		# Activar controles pero mantener deshabilitada la cámara libre
		player.permitir_teclado_movimiento = true
		
		tutorial_panel.visible = true
		tutorial_label.text = "USA EL JOYSTICK (ABAJO IZQUIERDA) PARA MOVERTE"
		
		# Posicionar la guía visual sobre el joystick
		pointer_guide.visible = true
		_posicionar_guia_joystick()
		
	elif state == 2:
		# Habilitar cámara libre para el tutorial de cámara
		player.remove_meta("cinematic_active")
		initial_yaw = player.get("_camara_yaw") as float
		
		tutorial_label.text = "DESLIZA EN LA PARTE DERECHA PARA MOVER LA CAMARA"
		_posicionar_guia_camara()
		
	elif state == 3:
		# Tutorial de salto
		tutorial_label.text = "MANTEN PRESIONADO Y SUELTA EL BOTON DE SALTO"
		_posicionar_guia_salto()
		
	elif state == 4:
		# Fin del tutorial
		pointer_guide.visible = false
		if is_instance_valid(tutorial_panel):
			tutorial_panel.visible = false
		
		# Guardar progreso
		if DatosUsuario:
			DatosUsuario.tutorial_completado = true
			DatosUsuario.dinero += 200.0
			DatosUsuario.esmeraldas += 10
			DatosUsuario.save_local()
			
			# Mostrar notificación llamativa
			if is_instance_valid(CelularUI.instance):
				CelularUI.instance.notificar("🏆 ¡TUTORIAL COMPLETADO! Ganaste: +$200.00 COP y +10 Esmeraldas", "exito")
			print("[IntroCinematic] Primera vez completada, recompensas otorgadas y guardado local exitoso.")
		
		# Mostrar el mensaje flotante exitoso de trofeo en el centro
		_mostrar_mensaje_trofeo()
		
		# Desvanecer panel tras unos segundos
		var t = get_tree().create_timer(3.5)
		t.timeout.connect(func():
			queue_free()
		)

func _posicionar_guia_joystick() -> void:
	if ui_pie:
		var joy = ui_pie.get_node_or_null("Controles/JoystickIzq") as Control
		if joy:
			pointer_guide.global_position = joy.global_position + (joy.size / 2.0) - (pointer_guide.custom_minimum_size / 2.0)
			return
	# Fallback si no encuentra el nodo
	var size = get_viewport().get_visible_rect().size
	pointer_guide.global_position = Vector2(size.x * 0.15, size.y * 0.72)

func _posicionar_guia_camara() -> void:
	# La zona de cámara cubre el lado derecho
	var size = get_viewport().get_visible_rect().size
	pointer_guide.global_position = Vector2(size.x * 0.65, size.y * 0.5)

func _posicionar_guia_salto() -> void:
	if ui_pie:
		var btn = ui_pie.get_node_or_null("Controles/BotonSalto") as Control
		if btn:
			pointer_guide.global_position = btn.global_position + (btn.size / 2.0) - (pointer_guide.custom_minimum_size / 2.0)
			return
	var size = get_viewport().get_visible_rect().size
	pointer_guide.global_position = Vector2(size.x * 0.85, size.y * 0.6)

func _animar_guia(delta: float) -> void:
	pointer_guide.pivot_offset = pointer_guide.custom_minimum_size / 2.0
	
	# Efecto de enfoque rápido tipo cámara (Lock-On Zoom) en los primeros 0.5 segundos del estado
	if state_elapsed_time < 0.5:
		var t = state_elapsed_time / 0.5
		# Curva de desaceleración suave (ease out)
		var factor = 1.0 - (1.0 - t) * (1.0 - t)
		var zoom_scale = lerp(5.0, 1.0, factor)
		pointer_guide.scale = Vector2(zoom_scale, zoom_scale)
		pointer_guide.modulate.a = lerp(0.0, 1.0, factor)
	else:
		# Animación continua de radar/pulsación
		var cycle_time = state_elapsed_time - 0.5
		var pulse = 1.0 + sin(cycle_time * 5.0) * 0.16
		pointer_guide.scale = Vector2(pulse, pulse)
		pointer_guide.modulate.a = 0.7 + sin(cycle_time * 5.0) * 0.3

func _mostrar_mensaje_trofeo() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "TrophyOverlay"
	canvas.layer = 100
	add_child(canvas)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	# Icono de Trofeo
	var emoji_lbl = Label.new()
	emoji_lbl.text = "🏆"
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", 120)
	vbox.add_child(emoji_lbl)
	
	# Título: ¡TUTORIAL COMPLETADO!
	var title_lbl = Label.new()
	title_lbl.text = "¡TUTORIAL COMPLETADO!"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 52)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1)) # Dorado
	title_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 12)
	if _font:
		title_lbl.add_theme_font_override("font", _font)
	vbox.add_child(title_lbl)
	
	# Recompensas
	var reward_lbl = Label.new()
	reward_lbl.text = "GANASTE\n+$200.00 COP\n+10 Esmeraldas"
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_size_override("font_size", 32)
	reward_lbl.add_theme_color_override("font_color", Color(0.14, 0.85, 0.45)) # Verde brillante
	reward_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	reward_lbl.add_theme_constant_override("shadow_offset_x", 2)
	reward_lbl.add_theme_constant_override("shadow_offset_y", 2)
	reward_lbl.add_theme_constant_override("shadow_outline_size", 10)
	if _font:
		reward_lbl.add_theme_font_override("font", _font)
	vbox.add_child(reward_lbl)
	
	# Animación de entrada
	vbox.scale = Vector2(0.5, 0.5)
	vbox.pivot_offset = Vector2(350, 200) # Estimado de pivote central
	var tw = create_tween().set_parallel(true)
	tw.tween_property(vbox, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animación de salida (desvanecer)
	var fade_tw = create_tween()
	fade_tw.tween_interval(2.8)
	fade_tw.tween_property(vbox, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(func():
		canvas.queue_free()
	)
