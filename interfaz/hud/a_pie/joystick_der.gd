extends ColorRect

var direccion: Vector2 = Vector2.ZERO
var jugador: CharacterBody3D = null
var run_mode_actual: float = 0.0
const TIEMPO_PARA_CORRER: float = 0.22
const RUN_TRANSITION: float = 5.0
const UMBRAL_CORRER_VERTICAL: float = -0.72
const UMBRAL_CORRER_MAGNITUD: float = 0.75
var tiempo_en_limite: float = 0.0
var corriendo: bool = false
var _touch_index: int = -1
@export var permitir_correr_cualquier_angulo: bool = true

func _ready() -> void:
	add_to_group("joystick")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_shader(Vector2(0.5, 0.5), 0.0, 0.0)
	await get_tree().process_frame
	jugador = get_tree().get_first_node_in_group("jugador")

	# Este joystick pertenece a `UIpie` (jugador a pie): permitir correr en cualquier ángulo por defecto.

func _process(delta: float) -> void:
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

	# Algunos jugadores (jugador3D.gd) no exponen `velocidad_actual`.
	# Solo asignar si la propiedad existe para evitar errores en CharacterBody3D base.
	if jugador.get("velocidad_actual") != null:
		jugador.set("velocidad_actual", jugador.VELOCIDAD_CORRER if corriendo else jugador.VELOCIDAD_CAMINAR)
	var objetivo_run = 1.0 if corriendo else 0.0
	run_mode_actual = move_toward(run_mode_actual, objetivo_run, delta * RUN_TRANSITION)
	if material:
		material.set_shader_parameter("run_mode", run_mode_actual)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().abs().has_point(event.position):
				# Verificar que ningún botón de acción tenga ese dedo
				var zona_cam = get_tree().get_first_node_in_group("zona_camara")
				if zona_cam and zona_cam.has_method("get_finger_id") and zona_cam.get_finger_id() == event.index:
					return
				
				# Verificar que el botón Interactuar no esté siendo tocado
				var boton_interactuar = get_tree().get_first_node_in_group("ui_root")
				if boton_interactuar == null:
					boton_interactuar = get_parent()
				if boton_interactuar:
					var btn = boton_interactuar.get_node_or_null("Interactuar") if boton_interactuar is Control else null
					if btn and btn is Button and btn.get_global_rect().abs().has_point(event.position):
						return
				
				_touch_index = event.index
				_procesar_movimiento(event.position)
				get_viewport().set_input_as_handled()
		else:
			if event.index == _touch_index:
				_touch_index = -1
				_reset_joystick()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_procesar_movimiento(event.position)
			get_viewport().set_input_as_handled()

	# Soporte básico con mouse para probar en editor/PC
	elif event is InputEventMouseButton:
		# Usamos _touch_index = -2 para indicar que es el ratón
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _touch_index == -1 and get_global_rect().abs().has_point(event.position):
					_touch_index = -2
					_procesar_movimiento(event.position)
					get_viewport().set_input_as_handled()
			else:
				if _touch_index == -2:
					_touch_index = -1
					_reset_joystick()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _touch_index == -2:
			_procesar_movimiento(event.position)
			get_viewport().set_input_as_handled()

func _procesar_movimiento(pos_global: Vector2) -> void:
	var centro       = size / 2.0
	var m_pos        = pos_global - global_position
	var diff         = m_pos - centro
	var radio_max    = size.x / 2.0
	var limite       = radio_max * 0.65
	var clamped_diff = diff.limit_length(limite)

	direccion = clamped_diff / limite

	var joy_pos_shader = (clamped_diff / size) + Vector2(0.5, 0.5)
	var pulse_amount   = 0.0
	if clamped_diff.length() >= limite * 0.95:
		pulse_amount = (clamped_diff.length() - (limite * 0.95)) / (limite * 0.05)
		pulse_amount = clamp(pulse_amount, 0.0, 1.0)

	_update_shader(joy_pos_shader, pulse_amount, run_mode_actual)

func _reset_joystick() -> void:
	direccion        = Vector2.ZERO
	corriendo        = false
	tiempo_en_limite = 0.0
	if Input.is_action_pressed("run"):
		Input.action_release("run")
	# Restaurar velocidad solo si la propiedad existe en el jugador
	if jugador and jugador.get("velocidad_actual") != null:
		jugador.set("velocidad_actual", jugador.VELOCIDAD_CAMINAR)
	_update_shader(Vector2(0.5, 0.5), 0.0, 0.0)

func _exit_tree() -> void:
	if Input.is_action_pressed("run"):
		Input.action_release("run")

func _update_shader(pos: Vector2, pulse: float, run: float) -> void:
	if material:
		material.set_shader_parameter("joy_position", pos)
		material.set_shader_parameter("limit_pulse",  pulse)
		material.set_shader_parameter("run_mode",     run)
