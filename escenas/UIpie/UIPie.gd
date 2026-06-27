extends CanvasLayer

signal camara_movida(relative_vector: Vector2)
signal camara_pinch(delta_dist)

# Joystick state (kept on root for compatibility)
var direccion: Vector2 = Vector2.ZERO
var corriendo: bool = false
var run_mode_actual: float = 0.0
const TIEMPO_PARA_CORRER: float = 0.22
const RUN_TRANSITION: float = 5.0
const UMBRAL_CORRER_VERTICAL: float = -0.72
const UMBRAL_CORRER_MAGNITUD: float = 0.75
var tiempo_en_limite: float = 0.0
var _touch_index: int = -1
@export var permitir_correr_cualquier_angulo: bool = true

# Zona cam
var _toques: Dictionary = {}
var _distancia_pellizco_prev: float = -1.0
var _toques_init: Dictionary = {}
var _zona_cam_active: Dictionary = {}
const ZONA_CAM_DRAG_THRESHOLD: float = 10.0

# Boton salto
var presionado_salto: bool = false
var tension_actual: float = 0.0
var touch_index_salto: int = -1
const VELOCIDAD_CARGA: float = 0.9
const FUERZA_MIN: float = 2.0
const FUERZA_MAX: float = 5.5
const IMPULSO_HORIZ: float = 2.5

# Agachar
var esta_agachado: bool = false
var touch_index_agachar: int = -1

# Node refs
var controles: Control = null
var joystick_node: ColorRect = null
var zona_cam_node: Control = null
var boton_salto_node: ColorRect = null
var boton_agachar_node: ColorRect = null
var interactuar_button: Button = null
var configuraciones_button: Button = null

var jugador: Node = null

func _ready() -> void:
	controles = get_node_or_null("Controles") as Control
	if controles:
		joystick_node = controles.get_node_or_null("JoystickIzq") as ColorRect
		zona_cam_node = controles.get_node_or_null("ZonaCamara") as Control
		boton_salto_node = controles.get_node_or_null("BotonSalto") as ColorRect
		boton_agachar_node = controles.get_node_or_null("BotonAgachar") as ColorRect
		interactuar_button = controles.get_node_or_null("Interactuar") as Button
		configuraciones_button = controles.get_node_or_null("Configuraciones") as Button
		if not configuraciones_button:
			configuraciones_button = controles.get_node_or_null("Salir") as Button

	# Exponer comportamiento por grupos para compatibilidad con código existente
	add_to_group("joystick")
	add_to_group("zona_camara")

	if configuraciones_button:
		if not configuraciones_button.is_connected("pressed", Callable(self, "_on_config_pressed")):
			configuraciones_button.pressed.connect(_on_config_pressed)

	# delay to allow other nodes (jugador) to exist
	await get_tree().process_frame
	jugador = get_tree().get_first_node_in_group("jugador")

	# Initialize shader params if present
	if joystick_node and joystick_node.material:
		joystick_node.material.set_shader_parameter("joy_position", Vector2(0.5, 0.5))
		joystick_node.material.set_shader_parameter("limit_pulse", 0.0)
		joystick_node.material.set_shader_parameter("run_mode", 0.0)
	if boton_agachar_node and boton_agachar_node.material:
		boton_agachar_node.material.set_shader_parameter("agachado", 0.0)
	if boton_salto_node and boton_salto_node.material:
		boton_salto_node.material.set_shader_parameter("tension", 0.0)
		boton_salto_node.material.set_shader_parameter("en_suelo", 1.0)

func get_finger_id() -> int:
	if _toques.is_empty():
		return -1
	return int(_toques.keys()[-1]) # Usar el último dedo registrado (el más reciente)

func get_joystick_direction() -> Vector2:
	return direccion

func _input(event) -> void:
	# Touch input
	if event is InputEventScreenTouch:
		if event.pressed:
			# PRIORIDAD: Botones de Acción (Salto/Agachar) primero para no ser capturados por la cámara
			if boton_salto_node and boton_salto_node.get_global_rect().abs().has_point(event.position):
				presionado_salto = true
				touch_index_salto = event.index
				tension_actual = 0.0
				get_viewport().set_input_as_handled()
				return

			if boton_agachar_node and boton_agachar_node.get_global_rect().abs().has_point(event.position):
				touch_index_agachar = event.index
				esta_agachado = not esta_agachado
				if jugador:
					if jugador.has_method("_set_agachado"):
						jugador._set_agachado(esta_agachado)
					elif "esta_agachado" in jugador:
						jugador.esta_agachado = esta_agachado
				if boton_agachar_node and boton_agachar_node.material:
					boton_agachar_node.material.set_shader_parameter("agachado", 1.0 if esta_agachado else 0.0)
				get_viewport().set_input_as_handled()
				return

			# Botones de UI
			if configuraciones_button and configuraciones_button.get_global_rect().abs().has_point(event.position):
				return
			if interactuar_button and interactuar_button.get_global_rect().abs().has_point(event.position):
				return

			# Joystick press
			if joystick_node and _touch_index == -1 and joystick_node.get_global_rect().abs().has_point(event.position):
				_touch_index = event.index
				_procesar_movimiento(event.position)
				get_viewport().set_input_as_handled()
				return

			# Zona cam (si no es ninguno de los anteriores) En la mitad derecha de la pantalla
			if event.position.x > get_viewport().get_visible_rect().size.x / 3.0: # Aumentamos el área a 2/3 de pantalla
				# No registrar si cae sobre botones de acción o cualquier control bloqueante
				if _touch_over_action_buttons(event.position) or _is_over_blocking_control(event.position):
					return

				# Registrar toque pero no activarlo hasta que el usuario arrastre
				_toques[event.index] = event.position
				_toques_init[event.index] = event.position
				_zona_cam_active[event.index] = false
				if _toques.size() >= 2:
					var k = _toques.keys()
					_distancia_pellizco_prev = _toques[k[0]].distance_to(_toques[k[1]])
				# No marcamos handled aún; esperamos al arrastre
				return
		else:
			if event.index == _touch_index:
				_touch_index = -1
				_reset_joystick()
				get_viewport().set_input_as_handled()
				return
			if event.index == touch_index_salto:
				if presionado_salto:
					_ejecutar_salto()
				presionado_salto = false
				touch_index_salto = -1
				tension_actual = 0.0
				if boton_salto_node and boton_salto_node.material:
					boton_salto_node.material.set_shader_parameter("tension", 0.0)
					var en_suelo: float = 1.0 if jugador and jugador.is_on_floor() else 0.0
					boton_salto_node.material.set_shader_parameter("en_suelo", en_suelo)
				get_viewport().set_input_as_handled()
				return
			if event.index == touch_index_agachar:
				touch_index_agachar = -1
				get_viewport().set_input_as_handled()
				return
			if _toques.has(event.index):
				var was_active = _zona_cam_active.get(event.index, false)
				_toques.erase(event.index)
				_toques_init.erase(event.index)
				_zona_cam_active.erase(event.index)
				if _toques.size() < 2:
					_distancia_pellizco_prev = -1.0
				if was_active:
					get_viewport().set_input_as_handled()
				return

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_procesar_movimiento(event.position)
			get_viewport().set_input_as_handled()
			return
		elif _toques.has(event.index):
			var init_pos = _toques_init.get(event.index, _toques[event.index])
			var moved = init_pos.distance_to(event.position)
			if not _zona_cam_active.get(event.index, false):
				if moved >= ZONA_CAM_DRAG_THRESHOLD:
					_zona_cam_active[event.index] = true
					# ahora que es un drag, bloqueamos el input
					get_viewport().set_input_as_handled()
				else:
					# actualizar posición para futuras comparaciones, pero no emitir
					_toques[event.index] = event.position
					return

			# Si llegamos aquí, el toque está activo como drag
			_toques[event.index] = event.position
			if _toques.size() >= 2:
				var keys = _toques.keys()
				var dist: float = (_toques[keys[0]] as Vector2).distance_to(_toques[keys[1]] as Vector2)
				if _distancia_pellizco_prev > 0.0:
					var delta_dist: float = dist - _distancia_pellizco_prev
					emit_signal("camara_pinch", delta_dist)
				_distancia_pellizco_prev = dist
				get_viewport().set_input_as_handled()
				return
			else:
				# Arrastre simple (Mirar)
				emit_signal("camara_movida", event.relative)
				get_viewport().set_input_as_handled()
				# Mouse support for editor/PC
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _touch_index == -1 and joystick_node and joystick_node.get_global_rect().abs().has_point(event.position):
					_touch_index = -2
					_procesar_movimiento(event.position)
					get_viewport().set_input_as_handled()
					return
				if touch_index_salto == -1 and boton_salto_node and boton_salto_node.get_global_rect().abs().has_point(event.position):
					presionado_salto = true
					touch_index_salto = -2
					tension_actual = 0.0
					get_viewport().set_input_as_handled()
					return
				if touch_index_agachar == -1 and boton_agachar_node and boton_agachar_node.get_global_rect().abs().has_point(event.position):
					touch_index_agachar = -2
					esta_agachado = not esta_agachado
					if jugador:
						if jugador.has_method("_set_agachado"):
							jugador._set_agachado(esta_agachado)
						elif "esta_agachado" in jugador:
							jugador.esta_agachado = esta_agachado
					if boton_agachar_node and boton_agachar_node.material:
						boton_agachar_node.material.set_shader_parameter("agachado", 1.0 if esta_agachado else 0.0)
					get_viewport().set_input_as_handled()
					return
				
				# Solo iniciar arrastre de cámara si el click es en la zona derecha y NO sobre ningún botón
				if event.position.x > get_viewport().get_visible_rect().size.x / 3.0:
					if not _touch_over_action_buttons(event.position) and not _is_over_blocking_control(event.position):
						_toques[-2] = event.position
						_toques_init[-2] = event.position
						_zona_cam_active[-2] = false
						# No consumimos el evento inmediatamente aquí para permitir interactuar con objetos del mundo
						return
			else:
				if _touch_index == -2:
					_touch_index = -1
					_reset_joystick()
					get_viewport().set_input_as_handled()
					return
				if touch_index_salto == -2:
					if presionado_salto:
						_ejecutar_salto()
					presionado_salto = false
					touch_index_salto = -1
					tension_actual = 0.0
					if boton_salto_node and boton_salto_node.material:
						boton_salto_node.material.set_shader_parameter("tension", 0.0)
					get_viewport().set_input_as_handled()
					return
				if touch_index_agachar == -2:
					touch_index_agachar = -1
					get_viewport().set_input_as_handled()
					return
				if _toques.has(-2):
					var was_active_mouse = _zona_cam_active.get(-2, false)
					_toques.erase(-2)
					_toques_init.erase(-2)
					_zona_cam_active.erase(-2)
					if _toques.size() < 2:
						_distancia_pellizco_prev = -1.0
					if was_active_mouse:
						get_viewport().set_input_as_handled()
					return
	elif event is InputEventMouseMotion:
		if _touch_index == -2:
			_procesar_movimiento(event.position)
			get_viewport().set_input_as_handled()
			return
 
		# Mouse-based camera drag (require threshold)
		if _toques.has(-2):
			var init_pos_mouse = _toques_init.get(-2, _toques[-2])
			var moved_mouse = init_pos_mouse.distance_to(event.position)
			if not _zona_cam_active.get(-2, false):
				if moved_mouse >= ZONA_CAM_DRAG_THRESHOLD:
					_zona_cam_active[-2] = true
					get_viewport().set_input_as_handled()
				else:
					# No es drag aún, no consumimos el evento
					return
 
			emit_signal("camara_movida", event.relative)
			get_viewport().set_input_as_handled()
			return

func _process(delta: float) -> void:
	# Run detection
	var magnitud_suficiente := direccion.length() >= UMBRAL_CORRER_MAGNITUD
	var empuje_hacia_arriba := direccion.y <= UMBRAL_CORRER_VERTICAL and magnitud_suficiente
	var debe_intentar_correr := magnitud_suficiente if permitir_correr_cualquier_angulo else empuje_hacia_arriba
	if debe_intentar_correr:
		tiempo_en_limite += delta
		if tiempo_en_limite >= TIEMPO_PARA_CORRER:
			corriendo = true
	else:
		tiempo_en_limite = 0.0
		corriendo = false

	if corriendo:
		if not Input.is_action_pressed("run"):
			Input.action_press("run")
	else:
		if Input.is_action_pressed("run"):
			Input.action_release("run")

	if jugador and jugador.get("velocidad_actual") != null:
		jugador.set("velocidad_actual", jugador.VELOCIDAD_CORRER if corriendo else jugador.VELOCIDAD_CAMINAR)

	var objetivo_run = 1.0 if corriendo else 0.0
	run_mode_actual = move_toward(run_mode_actual, objetivo_run, delta * RUN_TRANSITION)
	if joystick_node and joystick_node.material:
		joystick_node.material.set_shader_parameter("run_mode", run_mode_actual)

	# Salto tension
	if presionado_salto and jugador and jugador.is_on_floor():
		tension_actual = move_toward(tension_actual, 1.0, delta / VELOCIDAD_CARGA)
		if boton_salto_node and boton_salto_node.material:
			boton_salto_node.material.set_shader_parameter("tension", tension_actual)

	# Shaders time params
	if boton_salto_node and boton_salto_node.material:
		var en_suelo: float = 1.0 if jugador and jugador.is_on_floor() else 0.0
		boton_salto_node.material.set_shader_parameter("en_suelo", en_suelo)
		boton_salto_node.material.set_shader_parameter("tiempo_juego", float(Time.get_ticks_msec()) / 1000.0)
	if boton_agachar_node and boton_agachar_node.material:
		boton_agachar_node.material.set_shader_parameter("tiempo_juego", float(Time.get_ticks_msec()) / 1000.0)

func _procesar_movimiento(pos_global: Vector2) -> void:
	if not joystick_node: return
	var centro = joystick_node.size / 2.0
	var m_pos = pos_global - joystick_node.global_position
	var diff = m_pos - centro
	var radio_max = joystick_node.size.x / 2.0
	var limite = radio_max * 0.65
	var clamped_diff = diff.limit_length(limite)

	direccion = clamped_diff / limite

	var joy_pos_shader = (clamped_diff / joystick_node.size) + Vector2(0.5, 0.5)
	var pulse_amount = 0.0
	if clamped_diff.length() >= limite * 0.95:
		pulse_amount = (clamped_diff.length() - (limite * 0.95)) / (limite * 0.05)
		pulse_amount = clamp(pulse_amount, 0.0, 1.0)

	_update_shader(joy_pos_shader, pulse_amount, run_mode_actual)

func _reset_joystick() -> void:
	direccion = Vector2.ZERO
	corriendo = false
	tiempo_en_limite = 0.0
	if Input.is_action_pressed("run"):
		Input.action_release("run")
	if jugador and jugador.get("velocidad_actual") != null:
		jugador.set("velocidad_actual", jugador.VELOCIDAD_CAMINAR)
	_update_shader(Vector2(0.5, 0.5), 0.0, 0.0)

func _update_shader(pos: Vector2, pulse: float, run: float) -> void:
	if joystick_node and joystick_node.material:
		joystick_node.material.set_shader_parameter("joy_position", pos)
		joystick_node.material.set_shader_parameter("limit_pulse", pulse)
		joystick_node.material.set_shader_parameter("run_mode", run)

func _ejecutar_salto() -> void:
	var j = jugador if jugador else get_tree().get_first_node_in_group("jugador")
	if not j or not j.is_on_floor(): return

	var fuerza_v: float = lerp(FUERZA_MIN, FUERZA_MAX, tension_actual)

	var dir_horiz := Vector3.ZERO
	if direccion != null and direccion.length() > 0.1:
		var d2: Vector2 = direccion
		dir_horiz = (j.transform.basis * Vector3(d2.x, 0.0, d2.y)).normalized()

	j.velocity.y = fuerza_v
	j.velocity.x += dir_horiz.x * IMPULSO_HORIZ * tension_actual
	j.velocity.z += dir_horiz.z * IMPULSO_HORIZ * tension_actual

	var hud = null
	if j.has_node("HUD"):
		hud = j.get_node_or_null("HUD")
	if hud and hud.get("notificaciones") != null:
		if tension_actual >= 0.9:
			hud.notificaciones.notificar_texto("¡A volar, parce!", Color(0.95, 0.72, 0.15))
		elif tension_actual >= 0.5:
			hud.notificaciones.notificar_texto("¡Buen salto!", Color(0.8, 0.75, 0.4))

func _touch_over_action_buttons(pos: Vector2) -> bool:
	# Excluir botones de acción para que la zona de cámara no los capture
	if configuraciones_button and configuraciones_button.get_global_rect().abs().has_point(pos):
		return true
	if interactuar_button and interactuar_button.get_global_rect().abs().has_point(pos):
		return true
	if boton_salto_node and boton_salto_node.get_global_rect().abs().has_point(pos):
		return true
	if boton_agachar_node and boton_agachar_node.get_global_rect().abs().has_point(pos):
		return true
	return false

func _control_at_pos(node: Node, pos: Vector2) -> Control:
	if not node:
		return null
	if node is Control:
		var ctrl = node as Control
		if ctrl.visible and ctrl.is_visible_in_tree() and ctrl.get_global_rect().abs().has_point(pos):
			return ctrl
	for i in range(node.get_child_count()):
		var child = node.get_child(i)
		var found = _control_at_pos(child, pos)
		if found:
			return found
	return null

func _is_over_blocking_control(pos: Vector2) -> bool:
	if not controles:
		controles = get_node_or_null("Controles") as Control
	if not controles:
		return false
	for child in controles.get_children():
		var found = _control_at_pos(child, pos)
		if found:
			# Ignorar los controles específicos que permiten la interacción con la cámara
			if found == zona_cam_node or found == joystick_node:
				continue
			if found == boton_salto_node or found == boton_agachar_node or found == interactuar_button or found == configuraciones_button:
				continue
			return true
	return false

func _on_config_pressed() -> void:
	print("[UIPie] Botón configuraciones presionado")
	
	# Guardar datos antes de salir
	if DatosUsuario:
		if DatosUsuario.has_method("save_local"):
			DatosUsuario.save_local()
			print("[UIPie] Datos guardados (save_local) antes de abrir configuraciones")
		elif DatosUsuario.has_method("guardar_datos"):
			DatosUsuario.guardar_datos()
			print("[UIPie] Datos guardados (guardar_datos) antes de abrir configuraciones")
		
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").change_to_settings()
	elif ResourceLoader.exists("res://escenas/configuraciones/configuraciones.tscn"):
		get_tree().change_scene_to_file("res://escenas/configuraciones/configuraciones.tscn")
	else:
		print("UIPie: escena de configuraciones no encontrada.")
