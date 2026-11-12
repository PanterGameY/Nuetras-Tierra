@tool
extends Area3D
class_name TallerPersonalizacion

# ═══════════════════════════════════════════════════════════════════════
# TallerPersonalizacion — Controla la zona de personalización de vehículos
# ═══════════════════════════════════════════════════════════════════════

@export_group("Dimensiones de Zona")
## Dimensiones del área de detección (Ancho, Alto, Largo)
@export var dimensiones_zona: Vector3 = Vector3(8.0, 4.0, 12.0):
	set(val):
		dimensiones_zona = val
		_update_preview_and_shape()

## Mostrar caja de previsualización semi-transparente en el editor para posicionarla
@export var mostrar_previsualizacion: bool = true:
	set(val):
		mostrar_previsualizacion = val
		_update_preview_and_shape()

@export_group("Cámara de Taller (Opcional)")
## Si no se define, se creará una cámara órbita giratoria con control táctil
@export var camara_taller: Camera3D

@export_group("UI de Interacción (Opcional)")
## Si no se define, se creará un botón flotante dinámico con estilo premium
@export var letrero_interactuar: Control

@export_group("Debug")
@export var debug_taller: bool = true   # activar para ver prints en consola

# Estado interno de interacción y cámara
var vehiculo_dentro: Node3D = null
var editando: bool = false
var camara_previa: Camera3D = null

# Nodos dinámicos creados en tiempo de ejecución
var collision_node: CollisionShape3D = null
var ui_layer: CanvasLayer = null
var interaction_btn: Button = null
var instruction_lbl: Label = null

# Sistema de cámara orbital táctil y de teclado
var camera_pivot: Node3D = null
var dynamic_camera: Camera3D = null

# Destinos de interpolación (damping) para transiciones ultra suaves
var target_yaw: float = -45.0
var target_pitch: float = -15.0
var current_yaw: float = -45.0
var current_pitch: float = -15.0

var target_distance: float = 9.0
var current_distance: float = 9.0
var camera_distance: float = 9.0 # compatibilidad

var target_pivot_pos: Vector3 = Vector3.ZERO
var current_pivot_pos: Vector3 = Vector3.ZERO

var camera_sensitivity: float = 0.2
var time_passed: float = 0.0
var selection_mode: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview_and_shape()
		return

	# 1. Crear la colisión física real primero
	_crear_colision_real()

	# 2. Conectar señales
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	# 3. Crear la UI de interacción dinámica si no se proveyó una externa
	if not letrero_interactuar:
		_crear_ui_interaccion_dinamica()
	else:
		letrero_interactuar.visible = false

	# 4. Eliminar malla de previsualización al iniciar el juego
	var preview = get_node_or_null("PreviewMesh")
	if preview:
		preview.queue_free()

	# Colisión con todo para no perderse ningún cuerpo
	collision_mask = 0xFFFFFFFF
	collision_layer = 0

	# 5. Activar el monitoreo del Area3D de forma segura
	monitoring = false
	monitorable = false
	await get_tree().physics_frame # Esperar un frame de física
	monitoring = true
	monitorable = true

	if debug_taller:
		print("[TallerPersonalizacion] Listo en posición: ", global_position)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Control del letrero / botón de interacción
	if vehiculo_dentro and not editando:
		var is_activo: bool = vehiculo_dentro.get("activo") == true
		if is_activo:
			_mostrar_instruccion_bajar(true)
			_mostrar_letrero(false)
		else:
			_mostrar_instruccion_bajar(false)
			var vel: float = 0.0
			if "linear_velocity" in vehiculo_dentro:
				vel = vehiculo_dentro.linear_velocity.length()
			if vel < 0.5:
				_mostrar_letrero(true)
				# Tecla física alternativa para interactuar
				if Input.is_action_just_pressed("interactuar"):
					abrir_taller()
			else:
				_mostrar_letrero(false)
	else:
		_mostrar_instruccion_bajar(false)
		_mostrar_letrero(false)

	# Efecto de pulso en el botón interactivo (micro-animación)
	if interaction_btn and interaction_btn.visible:
		time_passed += delta * 4.0
		var scale_val = 1.0 + sin(time_passed) * 0.03
		interaction_btn.scale = Vector2(scale_val, scale_val)
		interaction_btn.pivot_offset = interaction_btn.size / 2.0

	# Teclado alternativo para rotar la cámara en PC
	if editando:
		var rot_speed = delta * 120.0
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			target_yaw += rot_speed
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			target_yaw -= rot_speed
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
			target_pitch -= rot_speed
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			target_pitch += rot_speed
		target_pitch = clamp(target_pitch, -60.0, 20.0)

	# Interpolación de rotación, posición y zoom de la cámara orbital (Damping suave)
	if editando and camera_pivot and dynamic_camera:
		# Interpolación de ángulos
		current_yaw = lerp_angle(current_yaw, deg_to_rad(target_yaw), 0.12)
		current_pitch = lerp(current_pitch, deg_to_rad(target_pitch), 0.12)
		camera_pivot.rotation.y = current_yaw
		camera_pivot.rotation.x = current_pitch
		
		# Interpolación del zoom
		current_distance = lerp(current_distance, target_distance, 0.12)
		dynamic_camera.position.z = current_distance
		
		# Interpolación del pivote (enfoque de presets y panning)
		current_pivot_pos = current_pivot_pos.lerp(target_pivot_pos, 0.12)
		camera_pivot.global_position = current_pivot_pos

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if not editando or not camera_pivot:
		return

	# Soporte alternativo para arrastrar sin ZonaCamara activa
	var is_drag = event is InputEventScreenDrag or \
				  (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if is_drag and not ui_layer.get_node("TallerZonaCamara").is_touching:
		target_yaw -= event.relative.x * camera_sensitivity
		target_pitch -= event.relative.y * camera_sensitivity
		target_pitch = clamp(target_pitch, -60.0, 20.0)

func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return

	if debug_taller:
		print("[TallerPersonalizacion] Body entered: ", body.name)

	var current_node: Node = body
	var found_vehiculo: Node3D = null
	while current_node != null:
		if current_node is Node3D:
			var is_veh := current_node.is_in_group("vehiculo") \
						or current_node.has_method("subir_jugador") \
						or "activo" in current_node \
						or current_node is RigidBody3D \
						or current_node is VehicleBody3D
			if is_veh:
				found_vehiculo = current_node as Node3D
				break
		current_node = current_node.get_parent()

	if found_vehiculo:
		vehiculo_dentro = found_vehiculo
		if debug_taller:
			print("[TallerPersonalizacion] ✔ Vehículo detectado: ", found_vehiculo.name)

func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return

	var current_node: Node = body
	var found_vehiculo: Node3D = null
	while current_node != null:
		if current_node is Node3D:
			var is_veh := current_node.is_in_group("vehiculo") \
						or current_node.has_method("subir_jugador") \
						or "activo" in current_node \
						or current_node is RigidBody3D \
						or current_node is VehicleBody3D
			if is_veh:
				found_vehiculo = current_node as Node3D
				break
		current_node = current_node.get_parent()

	if found_vehiculo == vehiculo_dentro:
		vehiculo_dentro = null
		_mostrar_letrero(false)
		if debug_taller:
			print("[TallerPersonalizacion] Vehículo salió de la zona")

func _mostrar_letrero(visible_state: bool) -> void:
	if letrero_interactuar:
		letrero_interactuar.visible = visible_state
	elif interaction_btn:
		interaction_btn.visible = visible_state

func _crear_ui_interaccion_dinamica() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "TallerUILayer"
	ui_layer.layer = 15  # Capa alta por encima de otras interfaces
	add_child(ui_layer)

	# Crear botón de interactuar
	interaction_btn = Button.new()
	interaction_btn.name = "BtnInteractuar"
	interaction_btn.text = "🔧  PERSONALIZAR VEHÍCULO"
	interaction_btn.focus_mode = Control.FOCUS_NONE
	interaction_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Posicionamiento en el centro inferior de pantalla
	interaction_btn.custom_minimum_size = Vector2(420, 75)
	interaction_btn.anchor_left = 0.5
	interaction_btn.anchor_top = 1.0
	interaction_btn.anchor_right = 0.5
	interaction_btn.anchor_bottom = 1.0
	interaction_btn.offset_left = -210
	interaction_btn.offset_right = 210
	interaction_btn.offset_top = -120
	interaction_btn.offset_bottom = -45
	interaction_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	interaction_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# Fuente opcional
	var font_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		var font = load(font_path)
		interaction_btn.add_theme_font_override("font", font)
		
	interaction_btn.add_theme_font_size_override("font_size", 22)

	# Estilo visual moderno
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	for side in ["left", "top", "right", "bottom"]:
		style_normal.set("border_width_" + side, 3)
	style_normal.border_color = Color(0.95, 0.8, 0.0, 1.0)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		style_normal.set("corner_radius_" + corner, 18)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.12, 0.12, 0.16, 0.95)

	interaction_btn.add_theme_stylebox_override("normal", style_normal)
	interaction_btn.add_theme_stylebox_override("hover", style_hover)
	interaction_btn.add_theme_stylebox_override("pressed", style_normal)
	interaction_btn.add_theme_color_override("font_color", Color(0.95, 0.8, 0.0, 1.0))

	interaction_btn.visible = false

	# Conectar el botón
	if not interaction_btn.pressed.is_connected(abrir_taller):
		interaction_btn.pressed.connect(abrir_taller)

	ui_layer.add_child(interaction_btn)

	# Crear etiqueta de instrucción para bajarse
	instruction_lbl = Label.new()
	instruction_lbl.name = "LblInstruccionBajar"
	instruction_lbl.text = "⚠️  BÁJATE DEL VEHÍCULO PARA PODER PERSONALIZARLO"
	instruction_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Posicionamiento
	instruction_lbl.custom_minimum_size = Vector2(880, 85)
	instruction_lbl.anchor_left = 0.5
	instruction_lbl.anchor_top = 1.0
	instruction_lbl.anchor_right = 0.5
	instruction_lbl.anchor_bottom = 1.0
	instruction_lbl.offset_left = -440
	instruction_lbl.offset_right = 440
	instruction_lbl.offset_top = -240
	instruction_lbl.offset_bottom = -155
	instruction_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	instruction_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN

	if ResourceLoader.exists(font_path):
		var font = load(font_path)
		instruction_lbl.add_theme_font_override("font", font)
	instruction_lbl.add_theme_font_size_override("font_size", 22)
	instruction_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))

	var style_lbl = StyleBoxFlat.new()
	style_lbl.bg_color = Color(0.08, 0.01, 0.01, 0.88)
	style_lbl.border_color = Color(1.0, 0.25, 0.25, 0.8)
	style_lbl.set("border_width_left", 5)
	for side in ["top", "right", "bottom"]:
		style_lbl.set("border_width_" + side, 0)
	style_lbl.content_margin_left = 20
	style_lbl.content_margin_right = 20
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		style_lbl.set("corner_radius_" + corner, 8)
	instruction_lbl.add_theme_stylebox_override("normal", style_lbl)

	instruction_lbl.visible = false
	ui_layer.add_child(instruction_lbl)

func _mostrar_instruccion_bajar(visible_state: bool) -> void:
	if instruction_lbl:
		instruction_lbl.visible = visible_state

func abrir_taller() -> void:
	if not is_instance_valid(vehiculo_dentro) or editando:
		return

	editando = true
	_mostrar_letrero(false)

	# Ocultar y desactivar jugador/personaje
	var jugador = null
	if get_tree():
		jugador = get_tree().get_first_node_in_group("jugador")
	if not jugador and vehiculo_dentro:
		jugador = vehiculo_dentro.get("jugador_ref")
	if not jugador and get_tree() and get_tree().get_root():
		jugador = get_tree().get_root().find_child("Jugador", true, false)
		if not jugador:
			jugador = get_tree().get_root().find_child("Jugador3D", true, false)
			
	if jugador and is_instance_valid(jugador):
		jugador.visible = false
		jugador.process_mode = PROCESS_MODE_DISABLED

	# Ocultar uipie (el panel táctil global)
	var uipie = null
	if get_tree() and get_tree().get_root():
		uipie = get_tree().get_root().find_child("*UIpie*", true, false)
		if not uipie:
			uipie = get_tree().get_root().find_child("*uipie*", true, false)
	if uipie:
		uipie.visible = false

	# Desactivar controles de conducción mediante el autoload
	var iv = get_node_or_null("/root/InputVehiculo")
	if iv:
		if "conduciendo" in iv:
			iv.conduciendo = false
		if "freno_mano" in iv:
			iv.freno_mano = true
		if "motor_encendido" in iv:
			iv.motor_encendido = false
		if iv.has_method("_reset_inputs_instant"):
			iv._reset_inputs_instant()

	# Ocultar la UI estándar del vehículo
	var ui_veh = vehiculo_dentro.get_node_or_null("UIVehiculo")
	if not ui_veh and get_tree() and get_tree().get_root():
		var root = get_tree().get_root()
		if root:
			ui_veh = root.find_child("UIVehiculo", true, false)
	if ui_veh:
		ui_veh.visible = false

	# Guardar cámara actual y activar la de taller
	camara_previa = get_viewport().get_camera_3d()

	if camara_taller and is_instance_valid(camara_taller):
		camara_taller.make_current()
	else:
		_crear_camara_orbital()

	# Crear una ZonaCamara táctil dedicada para rotar y panear la cámara
	var taller_zona_camara = Control.new()
	taller_zona_camara.name = "TallerZonaCamara"
	taller_zona_camara.anchor_left = 0.0
	taller_zona_camara.anchor_top = 0.0
	taller_zona_camara.anchor_right = 1.0
	taller_zona_camara.anchor_bottom = 1.0
	taller_zona_camara.grow_horizontal = Control.GROW_DIRECTION_BOTH
	taller_zona_camara.grow_vertical = Control.GROW_DIRECTION_BOTH
	taller_zona_camara.mouse_filter = Control.MOUSE_FILTER_STOP

	var dynamic_script = GDScript.new()
	dynamic_script.source_code = """
extends Control

signal camara_movida(relative)
signal camara_pan(relative)
signal camara_pinch(delta_dist)
signal tap(pos)

var toques = {}
var start_pos = {}
var last_dist = -1.0
var is_touching: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				toques[-1] = event.position
				start_pos[-1] = event.position
				is_touching = true
			else:
				var s = start_pos.get(-1, null)
				if s != null and s.distance_to(event.position) < 8.0:
					emit_signal("tap", event.position)
				toques.erase(-1)
				start_pos.erase(-1)
				is_touching = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				toques[-2] = event.position
				start_pos[-2] = event.position
				is_touching = true
			else:
				var s2 = start_pos.get(-2, null)
				if s2 != null and s2.distance_to(event.position) < 8.0:
					emit_signal("tap", event.position)
				toques.erase(-2)
				start_pos.erase(-2)
				is_touching = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			emit_signal("camara_pinch", 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			emit_signal("camara_pinch", -6.0)

	elif event is InputEventMouseMotion:
		if toques.has(-1):
			var rel = event.position - toques[-1]
			toques[-1] = event.position
			emit_signal("camara_movida", rel)
		elif toques.has(-2):
			var rel = event.position - toques[-2]
			toques[-2] = event.position
			emit_signal("camara_pan", rel)

	elif event is InputEventScreenTouch:
		if event.pressed:
			toques[event.index] = event.position
			start_pos[event.index] = event.position
			is_touching = true
		else:
			var s = start_pos.get(event.index, null)
			if s != null and s.distance_to(event.position) < 16.0:
				emit_signal("tap", event.position)
			toques.erase(event.index)
			start_pos.erase(event.index)
			if toques.size() < 2:
				last_dist = -1.0
			if toques.is_empty():
				is_touching = false

	elif event is InputEventScreenDrag:
		if toques.has(event.index):
			toques[event.index] = event.position
			if toques.size() == 2:
				var keys = toques.keys()
				var d = toques[keys[0]].distance_to(toques[keys[1]])
				if last_dist > 0.0:
					emit_signal("camara_pinch", d - last_dist)
				last_dist = d
			elif toques.size() == 1:
				var rel = event.relative
				emit_signal("camara_movida", rel)
"""
	dynamic_script.reload()
	taller_zona_camara.set_script(dynamic_script)
	taller_zona_camara.connect("camara_movida", _on_taller_camara_movida)
	taller_zona_camara.connect("camara_pan", _on_taller_camara_pan)
	taller_zona_camara.connect("camara_pinch", _on_taller_camara_pinch)
	# Tap (selección): conectar al manejador
	taller_zona_camara.connect("tap", _on_taller_tap)

	# Añadirla al CanvasLayer del taller como fondo
	if ui_layer:
		ui_layer.add_child(taller_zona_camara)
		ui_layer.move_child(taller_zona_camara, 0) # Mandar al fondo

	# Asegurar que el vehículo tenga el CustomizerComponent
	var customizer = vehiculo_dentro.get_node_or_null("CustomizerComponent")
	if not customizer:
		customizer = CustomizerComponent.new()
		customizer.name = "CustomizerComponent"
		vehiculo_dentro.add_child(customizer)

	# Cargar e instanciar el menú de personalización
	var menu_path := "res://interfaz/pantallas/tienda/MenuPersonalizacion.tscn"
	if ResourceLoader.exists(menu_path):
		var menu_scene = load(menu_path)
		if menu_scene:
			var menu_inst = menu_scene.instantiate()
			if ui_layer:
				ui_layer.add_child(menu_inst)
			else:
				add_child(menu_inst)
				
			if menu_inst is Control:
				# Allow touches to pass through empty areas so the TallerZonaCamara can receive touch input
				menu_inst.mouse_filter = Control.MOUSE_FILTER_PASS
				
			if menu_inst.has_method("configurar_taller"):
				menu_inst.configurar_taller(self, customizer)
	else:
		_crear_menu_debug(customizer)

func _crear_menu_debug(_customizer: Node) -> void:
	var layer = CanvasLayer.new()
	layer.name = "TallerDebugPanel"
	add_child(layer)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -100
	panel.offset_bottom = 100

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var label = Label.new()
	label.text = "TALLER ACTIVO\n" + vehiculo_dentro.name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var btn_cerrar = Button.new()
	btn_cerrar.text = "Cerrar"
	btn_cerrar.pressed.connect(func():
		layer.queue_free()
		cerrar_taller()
	)
	vbox.add_child(btn_cerrar)

	layer.add_child(panel)

func cerrar_taller() -> void:
	if not editando:
		return

	editando = false

	# Restaurar cámara previa
	if camara_previa and is_instance_valid(camara_previa):
		camara_previa.make_current()

	# Eliminar cámara orbital dinámica si se creó
	if camera_pivot and is_instance_valid(camera_pivot):
		camera_pivot.queue_free()
		camera_pivot = null
		dynamic_camera = null

	# Eliminar la zona de cámara de taller
	if ui_layer:
		var zc = ui_layer.get_node_or_null("TallerZonaCamara")
		if zc:
			zc.queue_free()

	# Restaurar controles de conducción
	var iv = get_node_or_null("/root/InputVehiculo")
	if iv:
		if "conduciendo" in iv:
			iv.conduciendo = true
		if "freno_mano" in iv:
			iv.freno_mano = false

	# Detectar si el jugador está conduciendo
	var jugador_conduciendo = false
	var jugador = null
	if get_tree():
		jugador = get_tree().get_first_node_in_group("jugador")
	if not jugador and vehiculo_dentro and is_instance_valid(vehiculo_dentro):
		jugador = vehiculo_dentro.get("jugador_ref")
	if not jugador and get_tree() and get_tree().get_root():
		jugador = get_tree().get_root().find_child("Jugador", true, false)
		if not jugador:
			jugador = get_tree().get_root().find_child("Jugador3D", true, false)
			
	if jugador and is_instance_valid(jugador):
		jugador_conduciendo = jugador.get("_conduciendo") == true or jugador.get("conduciendo") == true
		# Mostrar y activar jugador/personaje nuevamente
		jugador.visible = true
		jugador.process_mode = PROCESS_MODE_INHERIT

	# Mostrar de nuevo la UI estándar del vehículo solo si está conduciendo
	if vehiculo_dentro and is_instance_valid(vehiculo_dentro):
		var ui_veh = vehiculo_dentro.get_node_or_null("UIVehiculo")
		if not ui_veh and get_tree() and get_tree().get_root():
			ui_veh = get_tree().get_root().find_child("UIVehiculo", true, false)
		if ui_veh:
			ui_veh.visible = jugador_conduciendo

	# Mostrar uipie de nuevo solo si el jugador no está conduciendo (caminando)
	var uipie = null
	if get_tree() and get_tree().get_root():
		uipie = get_tree().get_root().find_child("*UIpie*", true, false)
		if not uipie:
			uipie = get_tree().get_root().find_child("*uipie*", true, false)
	if uipie:
		uipie.visible = not jugador_conduciendo

	if debug_taller:
		print("[TallerPersonalizacion] Taller cerrado")

func _on_taller_camara_movida(relative: Vector2) -> void:
	target_yaw -= relative.x * camera_sensitivity
	target_pitch -= relative.y * camera_sensitivity
	target_pitch = clamp(target_pitch, -60.0, 20.0)

func _on_taller_camara_pan(relative: Vector2) -> void:
	if not camera_pivot or not dynamic_camera:
		return
		
	# Mover el pivote basado en los vectores derecha y arriba locales de la cámara
	var cam_basis = dynamic_camera.global_transform.basis
	var right_vec = cam_basis.x
	var up_vec = cam_basis.y
	
	# Desplazamiento inverso
	var pan_speed := 0.006
	var pan_offset = (-right_vec * relative.x + up_vec * relative.y) * pan_speed
	target_pivot_pos += pan_offset

func _on_taller_camara_pinch(delta_dist: float) -> void:
	target_distance = clamp(target_distance - delta_dist * 0.06, 2.0, 20.0)

func _crear_camara_orbital() -> void:
	if not vehiculo_dentro:
		return

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraOrbitPivot"
	add_child(camera_pivot)
	
	# Configurar posiciones de pivote iniciales
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 1.5, 0)
	current_pivot_pos = target_pivot_pos
	camera_pivot.global_position = current_pivot_pos

	dynamic_camera = Camera3D.new()
	dynamic_camera.name = "OrbitCamera"
	camera_pivot.add_child(dynamic_camera)
	
	# Valores de zoom
	target_distance = 9.0
	current_distance = target_distance
	dynamic_camera.position = Vector3(0, 0, current_distance)

	target_yaw = -45.0
	target_pitch = -15.0
	current_yaw = deg_to_rad(target_yaw)
	current_pitch = deg_to_rad(target_pitch)

	camera_pivot.rotation.y = current_yaw
	camera_pivot.rotation.x = current_pitch

	dynamic_camera.make_current()

func set_selection_mode(enabled: bool) -> void:
	selection_mode = enabled
	if debug_taller:
		print("[TallerPersonalizacion] Selection mode:", selection_mode)

func _find_first_mesh_in_node(node: Node) -> MeshInstance3D:
	if not node:
		return null
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var found = _find_first_mesh_in_node(c)
		if found:
			return found
	return null

func _on_taller_tap(pos: Vector2) -> void:
	if not selection_mode:
		return
	var cam = dynamic_camera if dynamic_camera and is_instance_valid(dynamic_camera) else (camara_taller if camara_taller and is_instance_valid(camara_taller) else null)
	if not cam:
		return

	var from = cam.project_ray_origin(pos)
	var to = from + cam.project_ray_normal(pos) * 1000.0
	var espacio: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [])
	var resultado: Dictionary = espacio.intersect_ray(params)
	if resultado and resultado.has("collider"):
		var collider = resultado["collider"]
		var mesh = null
		if collider is MeshInstance3D:
			mesh = collider
		else:
			mesh = _find_first_mesh_in_node(collider)
		if mesh and is_instance_valid(mesh) and vehiculo_dentro:
			var customizer = vehiculo_dentro.get_node_or_null("CustomizerComponent")
			if customizer:
				customizer.seleccionar_mesh(mesh, self)

	# Desactivar modo selección automáticamente
	selection_mode = false

## Métodos de presets de enfoque llamados por la UI ═════════════════════

func enfocar_carroceria() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 1.5, 0)
	target_distance = 9.0
	target_yaw = -45.0
	target_pitch = -15.0

func enfocar_rines() -> void:
	if not vehiculo_dentro: return
	# Enfoque lateral inferior hacia las llantas delanteras del camión/coche
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(-1.2, 0.4, 1.6)
	target_distance = 3.6
	target_yaw = -82.0
	target_pitch = -8.0

func enfocar_placas() -> void:
	if not vehiculo_dentro: return
	# Enfoque cercano frontal hacia la placa
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 0.8, 3.2)
	target_distance = 2.8
	target_yaw = 0.0
	target_pitch = -12.0

func enfocar_neon() -> void:
	if not vehiculo_dentro: return
	# Enfoque desde abajo, mostrando el neón
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 0.2, 0)
	target_distance = 8.5
	target_yaw = -35.0
	target_pitch = -32.0

func enfocar_nodo(nodo: Node3D, distance: float = 3.0, yaw: float = -45.0, pitch: float = -15.0, offset: Vector3 = Vector3.ZERO) -> void:
	# Enfoca la cámara orbital hacia un nodo específico (utilizado por CustomizerComponent)
	if not nodo or not is_instance_valid(nodo):
		return
	target_pivot_pos = nodo.global_position + offset
	target_distance = distance
	target_yaw = yaw
	target_pitch = pitch

func _update_preview_and_shape() -> void:
	if not Engine.is_editor_hint():
		return

	var mesh_node = get_node_or_null("PreviewMesh") as MeshInstance3D
	if not mesh_node:
		mesh_node = MeshInstance3D.new()
		mesh_node.name = "PreviewMesh"
		add_child(mesh_node)
		if get_tree() and get_tree().edited_scene_root:
			mesh_node.owner = get_tree().edited_scene_root

	if mostrar_previsualizacion:
		mesh_node.visible = true
		var box = BoxMesh.new()
		box.size = dimensiones_zona
		mesh_node.mesh = box
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.95, 0.8, 0.0, 0.25)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_node.material_override = mat
	else:
		mesh_node.visible = false

func _crear_colision_real() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()

	collision_node = CollisionShape3D.new()
	collision_node.name = "TallerCollisionShape"

	var box_shape = BoxShape3D.new()
	box_shape.size = dimensiones_zona
	collision_node.shape = box_shape

	add_child(collision_node)
