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
const FUERZA_MIN: float = 4.6
const FUERZA_MAX: float = 6.0
const IMPULSO_HORIZ: float = 2.5

# Agachar
var esta_agachado: bool = false
var touch_index_agachar: int = -1
var _run_pulsado_por_ui: bool = false
var _linterna_encendida: bool = false

# Node refs
var controles: Control = null
var joystick_node: ColorRect = null
var zona_cam_node: Control = null
var boton_salto_node: ColorRect = null
var boton_agachar_node: ColorRect = null
var interactuar_button: Button = null

var boton_correr: Button = null
var btn_linterna: Button = null
var btn_camara: Button = null
var btn_silbato: Button = null
var btn_asomar_izq: Button = null
var btn_asomar_der: Button = null
var barra_inclinacion: HBoxContainer = null
var dock_superior: PanelContainer = null
var _tw_entrada: Tween = null
var correr_bloqueado: bool = false
var _modo_fov_idx: int = 0
const FOV_MODOS: Array[float] = [75.0, 60.0, 90.0]
const FOV_NOMBRES: Array[String] = ["VISTA NORMAL", "VISTA ZOOM", "VISTA AMPLIA"]

var jugador: Node = null

func _ready() -> void:
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	controles = get_node_or_null("Controles") as Control
	if controles:
		if not controles.visibility_changed.is_connected(_on_visibility_changed):
			controles.visibility_changed.connect(_on_visibility_changed)
		joystick_node = controles.find_child("JoystickIzq", true, false) as ColorRect
		zona_cam_node = controles.find_child("ZonaCamara", true, false) as Control
		boton_salto_node = controles.find_child("BotonSalto", true, false) as ColorRect
		boton_agachar_node = controles.find_child("BotonAgachar", true, false) as ColorRect
		interactuar_button = controles.find_child("Interactuar", true, false) as Button

		boton_correr = controles.find_child("BotonCorrer", true, false) as Button
		btn_linterna = controles.find_child("BtnLinterna", true, false) as Button
		btn_camara = controles.find_child("BtnCamaraPie", true, false) as Button
		btn_silbato = controles.find_child("BtnSilbato", true, false) as Button
		btn_asomar_izq = controles.find_child("BtnAsomarIzq", true, false) as Button
		btn_asomar_der = controles.find_child("BtnAsomarDer", true, false) as Button
		barra_inclinacion = controles.find_child("BarraInclinacion", true, false) as HBoxContainer
		dock_superior = controles.find_child("DockSuperior", true, false) as PanelContainer

		if interactuar_button and not interactuar_button.pressed.is_connected(_on_interactuar_pressed):
			interactuar_button.pressed.connect(_on_interactuar_pressed)
		if btn_linterna and not btn_linterna.pressed.is_connected(_on_linterna_pressed):
			btn_linterna.pressed.connect(_on_linterna_pressed)
		if btn_camara and not btn_camara.pressed.is_connected(_on_camara_fov_pressed):
			btn_camara.pressed.connect(_on_camara_fov_pressed)
		if btn_silbato and not btn_silbato.pressed.is_connected(_on_silbato_pressed):
			btn_silbato.pressed.connect(_on_silbato_pressed)
		if boton_correr and not boton_correr.toggled.is_connected(_on_correr_toggled):
			boton_correr.toggled.connect(_on_correr_toggled)
		if btn_asomar_izq:
			if not btn_asomar_izq.button_down.is_connected(_on_asomar_izq_down):
				btn_asomar_izq.button_down.connect(_on_asomar_izq_down)
			if not btn_asomar_izq.button_up.is_connected(_on_asomar_up):
				btn_asomar_izq.button_up.connect(_on_asomar_up)
		if btn_asomar_der:
			if not btn_asomar_der.button_down.is_connected(_on_asomar_der_down):
				btn_asomar_der.button_down.connect(_on_asomar_der_down)
			if not btn_asomar_der.button_up.is_connected(_on_asomar_up):
				btn_asomar_der.button_up.connect(_on_asomar_up)

	# Exponer comportamiento por grupos para compatibilidad con cÃ³digo existente
	add_to_group("joystick")
	add_to_group("zona_camara")

	# Conectar Modo PC desde SettingsManager
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		if sm.has_signal("modo_pc_cambiado") and not sm.modo_pc_cambiado.is_connected(aplicar_modo_pc):
			sm.modo_pc_cambiado.connect(aplicar_modo_pc)
		aplicar_modo_pc(bool(sm.get("modo_pc")))

	# delay to allow other nodes (jugador) to exist
	await get_tree().process_frame
	_asegurar_jugador_ref()

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

	_animar_entrada()

func _asegurar_jugador_ref() -> Node:
	if is_instance_valid(jugador):
		return jugador
	var parent = get_parent()
	if parent and parent.is_in_group("jugador"):
		jugador = parent
		return jugador
	if get_tree():
		for j in get_tree().get_nodes_in_group("jugador"):
			if not j.has_method("es_autoridad_local") or j.es_autoridad_local():
				jugador = j
				return jugador
		jugador = get_tree().get_first_node_in_group("jugador")
	return jugador

func aplicar_modo_pc(activo: bool) -> void:
	if not controles:
		return
	if activo:
		controles.visible = false
		controles.process_mode = Node.PROCESS_MODE_DISABLED
		_limpiar_estados_tactiles()
	else:
		controles.process_mode = Node.PROCESS_MODE_INHERIT
		if visible:
			controles.visible = true

func _on_visibility_changed() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm and bool(sm.get("modo_pc")):
		if controles:
			controles.visible = false
			controles.process_mode = Node.PROCESS_MODE_DISABLED
		_limpiar_estados_tactiles()
		return
	if not visible or (controles and not controles.visible):
		_limpiar_estados_tactiles()
		return
	_animar_entrada()

func _limpiar_estados_tactiles() -> void:
	_touch_index = -1
	_toques.clear()
	_toques_init.clear()
	_zona_cam_active.clear()
	_distancia_pellizco_prev = -1.0
	presionado_salto = false
	touch_index_salto = -1
	touch_index_agachar = -1
	tension_actual = 0.0
	_reset_joystick()
	_on_asomar_up()

func _actualizar_pivote(control: Control) -> void:
	control.pivot_offset = control.size * 0.5

func _animar_entrada() -> void:
	var piezas: Array[Control] = []
	for nodo in [
		joystick_node,
		barra_inclinacion,
		dock_superior,
		boton_salto_node,
		boton_agachar_node,
	]:
		if nodo is Control:
			piezas.append(nodo)
	if piezas.is_empty():
		return
	if _tw_entrada and _tw_entrada.is_valid():
		_tw_entrada.kill()
	_tw_entrada = create_tween().set_parallel(true)
	for i in piezas.size():
		var pieza: Control = piezas[i]
		pieza.modulate.a = 0.0
		_tw_entrada.tween_property(pieza, "modulate:a", 1.0, 0.34).set_delay(
			0.03 * float(i)
		).set_trans(Tween.TRANS_SINE)

func _marcar_icono(boton: Button, activo: bool) -> void:
	if boton == null:
		return
	var icono := boton.get_node_or_null("Icono") as ColorRect
	if icono and icono.material:
		icono.material.set_shader_parameter("activo", 1.0 if activo else 0.0)

func _pop_boton(boton: Control) -> void:
	if not boton:
		return
	_actualizar_pivote(boton)
	boton.scale = Vector2(0.96, 0.96)
	create_tween().tween_property(boton, "scale", Vector2.ONE, 0.24).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)

func _usar_solo_screen_touch(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false):
		return true
	return false

func get_finger_id() -> int:
	if _toques.is_empty():
		return -1
	return int(_toques.keys()[-1]) # Usar el Ãºltimo dedo registrado (el mÃ¡s reciente)

func get_joystick_direction() -> Vector2:
	return direccion

func _input(event) -> void:
	if not visible or (controles and not controles.visible):
		return
	# Touch input (MÃ³vil nativo y emulaciÃ³n tÃ¡ctil en PC)
	if event is InputEventScreenTouch:
		if event.pressed:
			# PRIORIDAD: Botones de AcciÃ³n (Salto/Agachar) primero para no ser capturados por la cÃ¡mara
			if boton_salto_node and boton_salto_node.get_global_rect().abs().has_point(event.position):
				presionado_salto = true
				touch_index_salto = event.index
				tension_actual = 0.0
				get_viewport().set_input_as_handled()
				return

			if boton_agachar_node and boton_agachar_node.get_global_rect().abs().has_point(event.position):
				touch_index_agachar = event.index
				esta_agachado = not esta_agachado
				_asegurar_jugador_ref()
				if jugador:
					if jugador.has_method("_set_agachado"):
						jugador._set_agachado(esta_agachado)
					elif "esta_agachado" in jugador:
						jugador.esta_agachado = esta_agachado
				if boton_agachar_node and boton_agachar_node.material:
					boton_agachar_node.material.set_shader_parameter("agachado", 1.0 if esta_agachado else 0.0)
				get_viewport().set_input_as_handled()
				return

			# Si toca sobre cualquiera de los botones de UI (Interactuar, Correr, Linterna, Vista, Saludo, Asomar),
			# dejar que el sistema GUI de Godot procese el Button normalmente.
			if _touch_over_action_buttons(event.position):
				return

			# Joystick press
			if joystick_node and _touch_index == -1 and joystick_node.get_global_rect().abs().has_point(event.position):
				_touch_index = event.index
				_procesar_movimiento(event.position)
				get_viewport().set_input_as_handled()
				return

			# Zona cam (si no es ninguno de los anteriores) En los 2/3 derechos de la pantalla
			if event.position.x > get_viewport().get_visible_rect().size.x / 3.0:
				if _is_over_blocking_control(event.position):
					return

				# Registrar toque pero no consumir aÃºn hasta confirmar arrastre
				_toques[event.index] = event.position
				_toques_init[event.index] = event.position
				_zona_cam_active[event.index] = false
				if _toques.size() >= 2:
					var k = _toques.keys()
					_distancia_pellizco_prev = (_toques[k[0]] as Vector2).distance_to(_toques[k[1]] as Vector2)
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
					get_viewport().set_input_as_handled()
				else:
					_toques[event.index] = event.position
					return

			# Si llegamos aquÃ­, el toque estÃ¡ activo como drag
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
				return

	# Mouse fallback exclusivo para PC cuando emulate_touch_from_mouse estÃ¡ desactivado
	elif event is InputEventMouseButton:
		if _usar_solo_screen_touch(event):
			return
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
					_asegurar_jugador_ref()
					if jugador:
						if jugador.has_method("_set_agachado"):
							jugador._set_agachado(esta_agachado)
						elif "esta_agachado" in jugador:
							jugador.esta_agachado = esta_agachado
					if boton_agachar_node and boton_agachar_node.material:
						boton_agachar_node.material.set_shader_parameter("agachado", 1.0 if esta_agachado else 0.0)
					get_viewport().set_input_as_handled()
					return
				
				if event.position.x > get_viewport().get_visible_rect().size.x / 3.0:
					if not _touch_over_action_buttons(event.position) and not _is_over_blocking_control(event.position):
						_toques[-2] = event.position
						_toques_init[-2] = event.position
						_zona_cam_active[-2] = false
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
		if _usar_solo_screen_touch(event):
			return
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
					return
 
			emit_signal("camara_movida", event.relative)
			get_viewport().set_input_as_handled()
			return

func _process(delta: float) -> void:
	if not visible or (controles and not controles.visible):
		return
	_asegurar_jugador_ref()

	# BotÃ³n contextual Interactuar
	if interactuar_button and is_instance_valid(jugador):
		if jugador.has_method("puede_interactuar"):
			interactuar_button.visible = bool(jugador.puede_interactuar())
		elif "_vehiculo_cerca" in jugador:
			interactuar_button.visible = (jugador.get("_vehiculo_cerca") != null and not bool(jugador.get("_conduciendo")))

	# Sincronizar estado visual de agachado si cambiÃ³ desde el jugador (ej. al saltar o correr)
	if is_instance_valid(jugador) and "esta_agachado" in jugador:
		var ag_jug := bool(jugador.get("esta_agachado"))
		if ag_jug != esta_agachado:
			esta_agachado = ag_jug
			if boton_agachar_node and boton_agachar_node.material:
				boton_agachar_node.material.set_shader_parameter("agachado", 1.0 if esta_agachado else 0.0)

	# Run detection
	var magnitud_suficiente := direccion.length() >= UMBRAL_CORRER_MAGNITUD
	var empuje_hacia_arriba := direccion.y <= UMBRAL_CORRER_VERTICAL and magnitud_suficiente
	var debe_intentar_correr := magnitud_suficiente if permitir_correr_cualquier_angulo else empuje_hacia_arriba
	if correr_bloqueado or debe_intentar_correr:
		tiempo_en_limite += delta
		if correr_bloqueado or tiempo_en_limite >= TIEMPO_PARA_CORRER:
			corriendo = true
	else:
		tiempo_en_limite = 0.0
		corriendo = false

	if corriendo:
		if not Input.is_action_pressed("run"):
			Input.action_press("run")
		_run_pulsado_por_ui = true
	elif _run_pulsado_por_ui:
		if Input.is_action_pressed("run"):
			Input.action_release("run")
		_run_pulsado_por_ui = false

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
	if _run_pulsado_por_ui:
		if Input.is_action_pressed("run"):
			Input.action_release("run")
		_run_pulsado_por_ui = false
	if jugador and jugador.get("velocidad_actual") != null:
		jugador.set("velocidad_actual", jugador.VELOCIDAD_CAMINAR)
	_update_shader(Vector2(0.5, 0.5), 0.0, 0.0)

func _update_shader(pos: Vector2, pulse: float, run: float) -> void:
	if joystick_node and joystick_node.material:
		joystick_node.material.set_shader_parameter("joy_position", pos)
		joystick_node.material.set_shader_parameter("limit_pulse", pulse)
		joystick_node.material.set_shader_parameter("run_mode", run)

func _ejecutar_salto() -> void:
	var j = _asegurar_jugador_ref()
	if not j:
		return

	var puede_saltar: bool = j.is_on_floor() or (j.get("_coyote_timer") != null and float(j.get("_coyote_timer")) > 0.0)
	if not puede_saltar:
		return

	var fuerza_v: float = lerp(FUERZA_MIN, FUERZA_MAX, tension_actual)

	var dir_horiz := Vector3.ZERO
	if direccion != null and direccion.length() > 0.1:
		var d2: Vector2 = direccion
		if "_camara_yaw" in j:
			var yaw: float = float(j.get("_camara_yaw"))
			var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var side := Vector3(cos(yaw), 0.0, -sin(yaw))
			dir_horiz = (side * d2.x + fwd * -d2.y).normalized()
		else:
			dir_horiz = (j.transform.basis * Vector3(d2.x, 0.0, d2.y)).normalized()

	var factor_impulso: float = maxf(tension_actual, 0.35)
	if j.has_method("ejecutar_salto_tactil"):
		j.ejecutar_salto_tactil(fuerza_v, dir_horiz * IMPULSO_HORIZ * factor_impulso)
	else:
		j.velocity.y = fuerza_v
		j.velocity.x += dir_horiz.x * IMPULSO_HORIZ * factor_impulso
		j.velocity.z += dir_horiz.z * IMPULSO_HORIZ * factor_impulso
		if j.has_method("_set_agachado"):
			j._set_agachado(false)
		elif "esta_agachado" in j:
			j.esta_agachado = false

	var hud = null
	if j.has_node("HUD"):
		hud = j.get_node_or_null("HUD")
	if hud and hud.get("notificaciones") != null:
		if tension_actual >= 0.9:
			hud.notificaciones.notificar_texto("A volar, parce!", Color(0.95, 0.72, 0.15))
		elif tension_actual >= 0.5:
			hud.notificaciones.notificar_texto("Buen salto!", Color(0.8, 0.75, 0.4))

func _touch_over_action_buttons(pos: Vector2) -> bool:
	# Excluir botones de accion para que la zona de camara no los capture
	if interactuar_button and interactuar_button.visible and interactuar_button.get_global_rect().abs().has_point(pos):
		return true
	if boton_salto_node and boton_salto_node.get_global_rect().abs().has_point(pos):
		return true
	if boton_agachar_node and boton_agachar_node.get_global_rect().abs().has_point(pos):
		return true
	if boton_correr and boton_correr.get_global_rect().abs().has_point(pos):
		return true
	if btn_linterna and btn_linterna.get_global_rect().abs().has_point(pos):
		return true
	if btn_camara and btn_camara.get_global_rect().abs().has_point(pos):
		return true
	if btn_silbato and btn_silbato.get_global_rect().abs().has_point(pos):
		return true
	if btn_asomar_izq and btn_asomar_izq.get_global_rect().abs().has_point(pos):
		return true
	if btn_asomar_der and btn_asomar_der.get_global_rect().abs().has_point(pos):
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
			# Ignorar los controles especÃ­ficos que permiten la interacciÃ³n con la cÃ¡mara
			if found == zona_cam_node or found == joystick_node:
				continue
			if found == boton_salto_node or found == boton_agachar_node or found == interactuar_button:
				continue
			return true
	return false

func _on_interactuar_pressed() -> void:
	_asegurar_jugador_ref()
	if jugador and jugador.has_method("interactuar_contextual"):
		jugador.interactuar_contextual()
	elif jugador and jugador.has_method("_on_boton_entrar_pressed"):
		jugador._on_boton_entrar_pressed()

func _on_linterna_pressed() -> void:
	_asegurar_jugador_ref()
	_linterna_encendida = not _linterna_encendida
	if jugador and jugador.has_method("alternar_linterna_jugador"):
		var res = jugador.call("alternar_linterna_jugador", _linterna_encendida)
		if typeof(res) == TYPE_BOOL:
			_linterna_encendida = res
	if btn_linterna:
		btn_linterna.text = "ON" if _linterna_encendida else "LUZ"
		if btn_linterna.toggle_mode and btn_linterna.button_pressed != _linterna_encendida:
			btn_linterna.set_pressed_no_signal(_linterna_encendida)
		_pop_boton(btn_linterna)

func _on_camara_fov_pressed() -> void:
	_asegurar_jugador_ref()
	_modo_fov_idx = (_modo_fov_idx + 1) % FOV_MODOS.size()
	if btn_camara:
		btn_camara.text = FOV_NOMBRES[_modo_fov_idx]
	if jugador and jugador.has_method("ajustar_fov_suave"):
		jugador.ajustar_fov_suave(FOV_MODOS[_modo_fov_idx])

func _on_silbato_pressed() -> void:
	_asegurar_jugador_ref()
	if jugador and jugador.has_method("saludar"):
		jugador.saludar()
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(30)

func _on_correr_toggled(activo: bool) -> void:
	correr_bloqueado = activo
	if boton_correr:
		_marcar_icono(boton_correr, activo)
		_pop_boton(boton_correr)

func _on_asomar_izq_down() -> void:
	_marcar_icono(btn_asomar_izq, true)
	Input.action_press("inclin-izq")

func _on_asomar_der_down() -> void:
	_marcar_icono(btn_asomar_der, true)
	Input.action_press("inclin-der")

func _on_asomar_up() -> void:
	_marcar_icono(btn_asomar_izq, false)
	_marcar_icono(btn_asomar_der, false)
	Input.action_release("inclin-izq")
	Input.action_release("inclin-der")

