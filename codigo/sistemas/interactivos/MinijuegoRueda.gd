# MinijuegoRueda.gd - Minijuego interactivo de cambio de rueda para camión pesado
# Desarrollado para Nuestra Tierra 2.0 (Godot 4.7) - Panter Studio
extends Control

signal minijuego_completado()
signal minijuego_cancelado()

enum Paso { AFLOJAR_PERNOS, RETIRAR_RUEDA, MONTAR_REPUESTO, APRETAR_PERNOS, BAJAR_GATO }
var paso_actual: Paso = Paso.AFLOJAR_PERNOS

const NUM_PERNOS: int = 8
var pernos_aflojados: Array[bool] = []
var pernos_apretados: Array[bool] = []
var botones_pernos: Array[Button] = []

var panel_fondo: Panel = null
var label_instruccion: Label = null
var label_paso: Label = null
var barra_progreso: ProgressBar = null
var contenedor_rin: Control = null
var btn_accion_centro: Button = null

var _font: FontFile = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	
	for i in range(NUM_PERNOS):
		pernos_aflojados.append(false)
		pernos_apretados.append(false)
		
	_construir_interfaz()

func _construir_interfaz() -> void:
	# Fondo oscurecido con viñeta
	panel_fondo = Panel.new()
	panel_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st_bg = StyleBoxFlat.new()
	st_bg.bg_color = Color(0.04, 0.05, 0.08, 0.94)
	panel_fondo.add_theme_stylebox_override("panel", st_bg)
	add_child(panel_fondo)
	
	# Marco central
	var marco = PanelContainer.new()
	marco.custom_minimum_size = Vector2(650, 720)
	marco.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var st_marco = StyleBoxFlat.new()
	st_marco.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	st_marco.border_width_left = 2; st_marco.border_width_top = 2
	st_marco.border_width_right = 2; st_marco.border_width_bottom = 2
	st_marco.border_color = Color(0.20, 0.55, 0.95, 0.60)
	st_marco.corner_radius_top_left = 20; st_marco.corner_radius_top_right = 20
	st_marco.corner_radius_bottom_left = 20; st_marco.corner_radius_bottom_right = 20
	st_marco.shadow_color = Color(0, 0, 0, 0.8)
	st_marco.shadow_size = 25
	marco.add_theme_stylebox_override("panel", st_marco)
	panel_fondo.add_child(marco)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	marco.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	
	# Encabezado
	var h_top = HBoxContainer.new()
	vbox.add_child(h_top)
	
	var titulo = Label.new()
	titulo.text = "🔧 CAMBIO DE NEUMÁTICO PESADO"
	if _font: titulo.add_theme_font_override("font", _font)
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_top.add_child(titulo)
	
	var btn_cerrar = Button.new()
	btn_cerrar.text = "✖ Cancelar"
	btn_cerrar.flat = true
	btn_cerrar.add_theme_font_size_override("font_size", 16)
	btn_cerrar.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	btn_cerrar.pressed.connect(func(): emit_signal("minijuego_cancelado"))
	h_top.add_child(btn_cerrar)
	
	# Etiqueta de paso
	label_paso = Label.new()
	label_paso.text = "PASO 1 DE 5: AFLOJAR PERNOS DEL RIN"
	if _font: label_paso.add_theme_font_override("font", _font)
	label_paso.add_theme_font_size_override("font_size", 16)
	label_paso.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
	vbox.add_child(label_paso)
	
	label_instruccion = Label.new()
	label_instruccion.text = "Toca cada uno de los 8 pernos para desenroscarlos con la cruceta de impacto."
	label_instruccion.add_theme_font_size_override("font_size", 14)
	label_instruccion.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	label_instruccion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label_instruccion)
	
	# Barra de progreso
	barra_progreso = ProgressBar.new()
	barra_progreso.custom_minimum_size = Vector2(0, 16)
	barra_progreso.max_value = 100.0
	barra_progreso.value = 0.0
	vbox.add_child(barra_progreso)
	
	# Contenedor del rin interactivo circular
	contenedor_rin = Control.new()
	contenedor_rin.custom_minimum_size = Vector2(420, 420)
	contenedor_rin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(contenedor_rin)
	
	_dibujar_rin_y_pernos()

func _dibujar_rin_y_pernos() -> void:
	botones_pernos.clear()
	for c in contenedor_rin.get_children():
		c.queue_free()
		
	# Fondo del rin metálico (círculo)
	var rin_bg = Panel.new()
	rin_bg.custom_minimum_size = Vector2(380, 380)
	rin_bg.position = Vector2(20, 20)
	var st_rin = StyleBoxFlat.new()
	st_rin.bg_color = Color(0.18, 0.20, 0.25, 1.0)
	st_rin.border_width_left = 18; st_rin.border_width_top = 18
	st_rin.border_width_right = 18; st_rin.border_width_bottom = 18
	st_rin.border_color = Color(0.12, 0.13, 0.15) # Banda de rodamiento negra
	st_rin.corner_radius_top_left = 190; st_rin.corner_radius_top_right = 190
	st_rin.corner_radius_bottom_left = 190; st_rin.corner_radius_bottom_right = 190
	rin_bg.add_theme_stylebox_override("panel", st_rin)
	contenedor_rin.add_child(rin_bg)
	
	# Centro del rin
	var centro = Panel.new()
	centro.custom_minimum_size = Vector2(160, 160)
	centro.position = Vector2(130, 130)
	var st_cen = StyleBoxFlat.new()
	st_cen.bg_color = Color(0.10, 0.12, 0.16)
	st_cen.corner_radius_top_left = 80; st_cen.corner_radius_top_right = 80
	st_cen.corner_radius_bottom_left = 80; st_cen.corner_radius_bottom_right = 80
	st_cen.border_width_left = 4; st_cen.border_width_top = 4
	st_cen.border_width_right = 4; st_cen.border_width_bottom = 4
	st_cen.border_color = Color(0.4, 0.45, 0.55)
	centro.add_theme_stylebox_override("panel", st_cen)
	contenedor_rin.add_child(centro)
	
	# Botón de acción central (Retirar llanta / Poner repuesto / Bajar gato)
	btn_accion_centro = Button.new()
	btn_accion_centro.custom_minimum_size = Vector2(140, 140)
	btn_accion_centro.position = Vector2(140, 140)
	btn_accion_centro.flat = true
	btn_accion_centro.visible = false
	btn_accion_centro.pressed.connect(_on_accion_centro_pressed)
	contenedor_rin.add_child(btn_accion_centro)
	
	# Crear los 8 pernos dispuestos en círculo de radio 120 px
	var centro_pos = Vector2(210, 210)
	var radio_pernos = 125.0
	
	for i in range(NUM_PERNOS):
		var angulo = (float(i) / float(NUM_PERNOS)) * TAU
		var p_pos = centro_pos + Vector2(cos(angulo), sin(angulo)) * radio_pernos - Vector2(24, 24)
		
		var btn_perno = Button.new()
		btn_perno.custom_minimum_size = Vector2(48, 48)
		btn_perno.position = p_pos
		btn_perno.text = str(i + 1)
		btn_perno.add_theme_font_size_override("font_size", 14)
		
		var st_p = StyleBoxFlat.new()
		st_p.bg_color = Color(0.85, 0.70, 0.20) # Dorado metálico
		st_p.corner_radius_top_left = 24; st_p.corner_radius_top_right = 24
		st_p.corner_radius_bottom_left = 24; st_p.corner_radius_bottom_right = 24
		st_p.border_width_left = 2; st_p.border_width_top = 2
		st_p.border_width_right = 2; st_p.border_width_bottom = 2
		st_p.border_color = Color.WHITE
		btn_perno.add_theme_stylebox_override("normal", st_p)
		
		var idx = i
		btn_perno.pressed.connect(func(): _on_perno_click(idx))
		contenedor_rin.add_child(btn_perno)
		botones_pernos.append(btn_perno)

func _on_perno_click(idx: int) -> void:
	if paso_actual == Paso.AFLOJAR_PERNOS:
		if pernos_aflojados[idx]:
			return
		pernos_aflojados[idx] = true
		
		# Animar extracción del perno
		var b = botones_pernos[idx]
		var tw = create_tween()
		tw.tween_property(b, "scale", Vector2(1.25, 1.25), 0.1)
		tw.tween_property(b, "scale", Vector2(0.6, 0.6), 0.15)
		tw.tween_property(b, "modulate:a", 0.2, 0.1)
		
		var cont = 0
		for a in pernos_aflojados:
			if a: cont += 1
		barra_progreso.value = (float(cont) / float(NUM_PERNOS)) * 25.0
		
		if cont == NUM_PERNOS:
			_avanzar_paso(Paso.RETIRAR_RUEDA)
			
	elif paso_actual == Paso.APRETAR_PERNOS:
		if pernos_apretados[idx]:
			return
		pernos_apretados[idx] = true
		
		var b = botones_pernos[idx]
		var tw = create_tween()
		tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.15)
		tw.tween_property(b, "modulate:a", 1.0, 0.15)
		
		var cont = 0
		for a in pernos_apretados:
			if a: cont += 1
		barra_progreso.value = 50.0 + (float(cont) / float(NUM_PERNOS)) * 30.0
		
		if cont == NUM_PERNOS:
			_avanzar_paso(Paso.BAJAR_GATO)

func _avanzar_paso(nuevo_paso: Paso) -> void:
	paso_actual = nuevo_paso
	match paso_actual:
		Paso.RETIRAR_RUEDA:
			label_paso.text = "PASO 2 DE 5: RETIRAR RUEDA PINCHADA"
			label_instruccion.text = "Toca el centro del rin para desmontar y retirar la llanta averiada del eje."
			barra_progreso.value = 35.0
			btn_accion_centro.visible = true
			btn_accion_centro.text = "🔴\nRETIRAR\nLLANTA"
			for b in botones_pernos: b.visible = false
			
		Paso.MONTAR_REPUESTO:
			label_paso.text = "PASO 3 DE 5: MONTAR RUEDA DE REPUESTO"
			label_instruccion.text = "Toca el centro para encajar la rueda de repuesto en los espárragos del eje."
			barra_progreso.value = 50.0
			btn_accion_centro.visible = true
			btn_accion_centro.text = "🟢\nMONTAR\nREPUESTO"
			
		Paso.APRETAR_PERNOS:
			label_paso.text = "PASO 4 DE 5: APRETAR PERNOS EN ESTRELLA"
			label_instruccion.text = "Toca los 8 pernos para apretarlos firmemente con el torque adecuado."
			btn_accion_centro.visible = false
			for i in range(NUM_PERNOS):
				var b = botones_pernos[i]
				b.visible = true
				b.modulate.a = 0.3
				b.scale = Vector2(0.6, 0.6)
				
		Paso.BAJAR_GATO:
			label_paso.text = "PASO 5 DE 5: BAJAR GATO HIDRÁULICO"
			label_instruccion.text = "Toca el botón central para liberar la válvula del gato y asentar el camión."
			barra_progreso.value = 90.0
			btn_accion_centro.visible = true
			btn_accion_centro.text = "⬇️\nBAJAR\nGATO"
			for b in botones_pernos: b.visible = true

func _on_accion_centro_pressed() -> void:
	if paso_actual == Paso.RETIRAR_RUEDA:
		var tw = create_tween()
		tw.tween_property(contenedor_rin, "modulate:a", 0.3, 0.25)
		tw.tween_property(contenedor_rin, "modulate:a", 1.0, 0.25)
		tw.tween_callback(func(): _avanzar_paso(Paso.MONTAR_REPUESTO))
	elif paso_actual == Paso.MONTAR_REPUESTO:
		var tw = create_tween()
		tw.tween_property(contenedor_rin, "scale", Vector2(1.05, 1.05), 0.2)
		tw.tween_property(contenedor_rin, "scale", Vector2(1.0, 1.0), 0.2)
		tw.tween_callback(func(): _avanzar_paso(Paso.APRETAR_PERNOS))
	elif paso_actual == Paso.BAJAR_GATO:
		barra_progreso.value = 100.0
		label_instruccion.text = "¡Operación completada! El camión ha quedado apoyado sobre su nueva rueda."
		btn_accion_centro.visible = false
		var tw = create_tween()
		tw.tween_interval(0.8)
		tw.tween_callback(func(): emit_signal("minijuego_completado"))
