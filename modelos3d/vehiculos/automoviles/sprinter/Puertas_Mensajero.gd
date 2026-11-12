extends Node3D

# Puertas_Mensajero.gd
# Este script controla las puertas de la Sprinter y la busqueda del paquete.
# El boton cambia dinamicamente de "ABRIR PUERTAS" a "BUSCAR PAQUETE" y no hace nada automatico.

@export var puerta_izquierda: Node3D
@export var puerta_derecha: Node3D
@export var punto_apertura: Marker3D
@export var velocidad_apertura: float = 2.0
@export var angulo_apertura: float = 90.0
@export var tiempo_busqueda: float = 5.0 # Segundos requeridos para buscar el paquete

var abierto: bool = false
var angulo_actual: float = 0.0
var jugador_adentro: bool = false

# UI local autogestionada
var canvas_ui: CanvasLayer
var panel_ui: PanelContainer
var label_notif: Label
var label_progreso: Label
var progress_bar: ProgressBar
var btn_accion: Button

# Control del estado de la busqueda
var buscando: bool = false
var progreso_acumulado: float = 0.0
var hide_timer: Timer

func _ready() -> void:
	# Verificacion de referencias
	if not puerta_izquierda or not puerta_derecha:
		push_warning("[Puertas_Mensajero] Referencias a puertas no asignadas.")
	if not punto_apertura:
		push_warning("[Puertas_Mensajero] Referencia a punto_apertura no asignada.")
	
	_inicializar_ui_local()

func _process(delta: float) -> void:
	# Buscar al jugador en el grupo correspondiente
	var jugador = get_tree().get_first_node_in_group("jugador")
	
	if jugador and is_instance_valid(punto_apertura):
		var distancia = punto_apertura.global_position.distance_to(jugador.global_position)
		
		# Solo si el jugador esta directamente en el marker (menos de 2.0 metros)
		if distancia < 2.0:
			if not jugador_adentro:
				jugador_adentro = true
				canvas_ui.visible = true
				_actualizar_estado_boton()
		else:
			# Si el jugador se aleja del marker (cierre automatico)
			if jugador_adentro:
				jugador_adentro = false
				abierto = false # Cerrar automaticamente al alejarse
				_cancelar_busqueda()
				mostrar_mensaje_local("PUERTAS TRASERAS: CERRADAS")
				
				# Iniciar temporizador para ocultar la UI despues del aviso
				if is_instance_valid(hide_timer):
					hide_timer.start(2.0)

	# Incrementar progreso si esta buscando
	if buscando:
		progreso_acumulado += delta
		var porcentaje = (progreso_acumulado / tiempo_busqueda) * 100.0
		if is_instance_valid(progress_bar):
			progress_bar.value = porcentaje
		
		if progreso_acumulado >= tiempo_busqueda:
			_completar_busqueda()

	# Interpolacion de angulo suave para abrir/cerrar puertas
	var objetivo_angulo = angulo_apertura if abierto else 0.0
	angulo_actual = lerp(angulo_actual, objetivo_angulo, delta * velocidad_apertura * 3.0)

	if is_instance_valid(puerta_izquierda):
		puerta_izquierda.rotation_degrees.y = -angulo_actual
	if is_instance_valid(puerta_derecha):
		puerta_derecha.rotation_degrees.y = angulo_actual

# Accion del boton multifuncion
func _on_btn_accion_pressed() -> void:
	var mensajero = _find_mensajero_node()
	var tiene_paquete = mensajero.get("tiene_paquete") if mensajero else true
	var estado = mensajero.get("estado_actual") if mensajero else 0
	var en_reparto = (estado == 3) # EstadoTrabajo.ENTREGANDO es 3
	var cargando = (estado == 1)   # EstadoTrabajo.CARGANDO es 1
	var jugador = get_tree().get_first_node_in_group("jugador")
	var tiene_caja = jugador.get("caja_agarrada") != null if jugador else false

	if not abierto:
		# Accion 1: Abrir las puertas
		abierto = true
		mostrar_mensaje_local("PUERTAS ABIERTAS")
		_actualizar_estado_boton()
	elif abierto and cargando and tiene_caja:
		# Accion: Soltar/cargar la caja en el vehículo
		if mensajero and jugador:
			var zc_pos = global_position
			var zona_carga = get_parent().find_child("ZonaCajas", true, false)
			if not zona_carga:
				zona_carga = get_parent().find_child("ZonaCarga", true, false)
			if zona_carga:
				zc_pos = zona_carga.global_position
			mensajero.call("cargar_caja_desde_area", jugador, zc_pos)
		_actualizar_estado_boton()
	elif abierto and en_reparto and not tiene_paquete and not buscando:
		# Accion 2: Buscar paquete (solo si estan abiertas, en reparto y no se ha recogido)
		_iniciar_busqueda()
	elif abierto:
		# Accion 3: Cerrar manualmente
		abierto = false
		mostrar_mensaje_local("PUERTAS CERRADAS")
		_actualizar_estado_boton()

# Actualiza el texto y visibilidad del boton segun el estado
func _actualizar_estado_boton() -> void:
	if not is_instance_valid(btn_accion):
		return
		
	var mensajero = _find_mensajero_node()
	var tiene_paquete = mensajero.get("tiene_paquete") if mensajero else true
	var estado = mensajero.get("estado_actual") if mensajero else 0
	var en_reparto = (estado == 3)
	var cargando = (estado == 1)
	var jugador = get_tree().get_first_node_in_group("jugador")
	var tiene_caja = jugador.get("caja_agarrada") != null if jugador else false
	
	btn_accion.visible = true
	
	if not abierto:
		btn_accion.text = "ABRIR PUERTAS"
		if not buscando:
			if tiene_caja and cargando:
				label_notif.text = "ABRE LAS PUERTAS PARA CARGAR LA CAJA"
			else:
				label_notif.text = "PRESIONA EL BOTON PARA ABRIR"
	else:
		if tiene_caja and cargando:
			btn_accion.text = "SOLTAR CAJA"
			if not buscando:
				label_notif.text = "PUERTAS ABIERTAS: LISTO PARA DEPOSITAR"
		elif not en_reparto:
			btn_accion.visible = false
			if not buscando:
				label_notif.text = "PUERTAS ABIERTAS (CARGA EN PROCESO)"
		elif not tiene_paquete:
			btn_accion.text = "BUSCAR PAQUETE"
			if not buscando:
				label_notif.text = "PUERTAS ABIERTAS"
		else:
			btn_accion.visible = false
			if not buscando:
				label_notif.text = "PAQUETE YA RECOGIDO"

# Metodo publico compatible con botonpuertas.gd
func toggle_door() -> void:
	abierto = not abierto
	mostrar_mensaje_local("PUERTAS TRASERAS: " + ("ABIERTAS" if abierto else "CERRADAS"))
	_actualizar_estado_boton()
	if not abierto:
		_cancelar_busqueda()

# Muestra un mensaje temporal en la UI local
func mostrar_mensaje_local(msg: String, mostrar_barra: bool = false) -> void:
	if not is_instance_valid(canvas_ui):
		return
		
	label_notif.text = msg
	label_progreso.visible = mostrar_barra
	progress_bar.visible = mostrar_barra
	
	if is_instance_valid(hide_timer):
		hide_timer.stop()
		
	if not mostrar_barra and not jugador_adentro:
		hide_timer.start(2.0)

# --- Inicializacion de la Interfaz Grafica ---

func _inicializar_ui_local() -> void:
	canvas_ui = CanvasLayer.new()
	canvas_ui.layer = 125
	canvas_ui.visible = false
	add_child(canvas_ui)
	
	# Temporizador para ocultar la UI completa
	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.timeout.connect(func(): canvas_ui.visible = false)
	add_child(hide_timer)
	
	# Contenedor del panel flotante
	panel_ui = PanelContainer.new()
	panel_ui.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel_ui.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_ui.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel_ui.position.y -= 140 # Posicion elevada y clara
	canvas_ui.add_child(panel_ui)
	
	# Estilo del fondo (Glassmorphism oscuro de alto contraste)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.04, 0.04, 0.07, 0.9) # Negro azulado profundo
	style_box.corner_detail = 12
	style_box.set_corner_radius_all(14)
	style_box.set_content_margin_all(18)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.2, 0.75, 1.0, 0.4) # Borde celeste neon
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 10
	panel_ui.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel_ui.add_child(vbox)
	
	# Fuente del proyecto
	var font_path = "res://recursos/fonts/Moderniz.otf"
	var custom_font = null
	if ResourceLoader.exists(font_path):
		custom_font = load(font_path)
		
	# 1. Titulo / Notificacion
	label_notif = Label.new()
	label_notif.text = ""
	label_notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_notif.add_theme_font_size_override("font_size", 20)
	label_notif.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0)) # Amarillo Dorado Neon
	label_notif.add_theme_color_override("font_shadow_color", Color.BLACK)
	label_notif.add_theme_constant_override("shadow_outline_size", 4)
	if custom_font:
		label_notif.add_theme_font_override("font", custom_font)
	vbox.add_child(label_notif)
	
	# 2. Etiqueta de Progreso
	label_progreso = Label.new()
	label_progreso.text = "BUSCANDO PAQUETE..."
	label_progreso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_progreso.add_theme_font_size_override("font_size", 14)
	label_progreso.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0)) # Blanco Azulado
	label_progreso.add_theme_color_override("font_shadow_color", Color.BLACK)
	label_progreso.add_theme_constant_override("shadow_outline_size", 3)
	if custom_font:
		label_progreso.add_theme_font_override("font", custom_font)
	label_progreso.visible = false
	vbox.add_child(label_progreso)
	
	# 3. Barra de progreso GIGANTE
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(380, 26)
	progress_bar.show_percentage = true
	progress_bar.value = 0.0
	progress_bar.add_theme_font_size_override("font_size", 13)
	progress_bar.add_theme_color_override("font_color", Color.WHITE)
	progress_bar.add_theme_color_override("font_outline_color", Color.BLACK)
	progress_bar.add_theme_constant_override("outline_size", 3)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.16, 1.0)
	bg_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.0, 0.75, 1.0, 1.0) # Celeste Neon
	fg_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("fill", fg_style)
	progress_bar.visible = false
	vbox.add_child(progress_bar)
	
	# 4. Boton multifuncion grande
	btn_accion = Button.new()
	btn_accion.text = "ABRIR PUERTAS"
	btn_accion.custom_minimum_size = Vector2(320, 52)
	btn_accion.focus_mode = Control.FOCUS_NONE
	btn_accion.add_theme_font_size_override("font_size", 15)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.05, 0.45, 0.7, 0.85)
	btn_normal.set_corner_radius_all(10)
	btn_normal.set_content_margin_all(10)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.2, 0.85, 1.0, 0.6)
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.07, 0.55, 0.85, 0.95)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.9)
	
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.02, 0.3, 0.5, 0.95)
	
	btn_accion.add_theme_stylebox_override("normal", btn_normal)
	btn_accion.add_theme_stylebox_override("hover", btn_hover)
	btn_accion.add_theme_stylebox_override("pressed", btn_pressed)
	
	if custom_font:
		btn_accion.add_theme_font_override("font", custom_font)
	btn_accion.pressed.connect(_on_btn_accion_pressed)
	vbox.add_child(btn_accion)

# --- Metodos de ciclo de busqueda ---

func _iniciar_busqueda() -> void:
	buscando = true
	progreso_acumulado = 0.0
	if is_instance_valid(progress_bar):
		progress_bar.value = 0.0
	if is_instance_valid(btn_accion):
		btn_accion.visible = false # Ocultar boton durante la carga
	mostrar_mensaje_local("BUSCANDO PAQUETE", true)

func _cancelar_busqueda() -> void:
	if buscando:
		buscando = false
		progreso_acumulado = 0.0
		mostrar_mensaje_local("BUSQUEDA CANCELADA")
		_actualizar_estado_boton()

func _completar_busqueda() -> void:
	buscando = false
	mostrar_mensaje_local("PAQUETE RECUPERADO CON EXITO")
	_actualizar_estado_boton()
	
	if is_instance_valid(hide_timer):
		hide_timer.start(1.5)
	
	var mensajero = _find_mensajero_node()
	if mensajero and mensajero.has_method("recoger_paquete"):
		mensajero.call("recoger_paquete")

func _find_mensajero_node() -> Node:
	var root = get_tree().current_scene
	if root:
		return root.find_child("Mensajero", true, false)
	return null

func _exit_tree() -> void:
	if is_instance_valid(canvas_ui):
		canvas_ui.queue_free()
