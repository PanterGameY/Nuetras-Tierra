extends ColorRect

var jugador: CharacterBody3D = null

var presionado:     bool  = false
var tension_actual: float = 0.0
var touch_index:    int   = -1

const VELOCIDAD_CARGA: float = 0.9  # segundos en llegar al maximo
const FUERZA_MIN:      float = 2.0
const FUERZA_MAX:      float = 5.5
const IMPULSO_HORIZ:   float = 2.5

func _ready() -> void:
	_update_shader(0.0, 1.0)
	await get_tree().process_frame
	jugador = get_tree().get_first_node_in_group("jugador")

func _process(delta: float) -> void:
	if not jugador or not material: return

	var en_suelo: float = 1.0 if jugador.is_on_floor() else 0.0
	material.set_shader_parameter("en_suelo",     en_suelo)
	material.set_shader_parameter("tiempo_juego", float(Time.get_ticks_msec()) / 1000.0)

	# Cargar tension mientras esta presionado
	if presionado and jugador.is_on_floor():
		tension_actual = move_toward(tension_actual, 1.0, delta / VELOCIDAD_CARGA)
		material.set_shader_parameter("tension", tension_actual)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if get_global_rect().abs().has_point(event.position):
				# Verificar que el joystick no tenga ese dedo
				var joystick = get_tree().get_first_node_in_group("joystick")
				if joystick and joystick._touch_index == event.index:
					return
				presionado   = true
				touch_index  = event.index
				tension_actual = 0.0
				get_viewport().set_input_as_handled()
		else:
			if event.index == touch_index:
				if presionado:
					_ejecutar_salto()
				presionado     = false
				touch_index    = -1
				tension_actual = 0.0
				_update_shader(0.0, 1.0 if jugador and jugador.is_on_floor() else 0.0)
				get_viewport().set_input_as_handled()

func _ejecutar_salto() -> void:
	if not jugador or not jugador.is_on_floor(): return

	var fuerza_v: float = lerp(FUERZA_MIN, FUERZA_MAX, tension_actual)

	var dir_horiz := Vector3.ZERO
	var joystick   = _buscar_joystick()
	if joystick and joystick.get("direccion") != null:
		var d2: Vector2 = joystick.direccion
		if d2.length() > 0.1:
			dir_horiz = (jugador.transform.basis * Vector3(d2.x, 0.0, d2.y)).normalized()

	jugador.velocity.y  = fuerza_v
	jugador.velocity.x += dir_horiz.x * IMPULSO_HORIZ * tension_actual
	jugador.velocity.z += dir_horiz.z * IMPULSO_HORIZ * tension_actual

	var hud = _buscar_hud()
	if hud and hud.get("notificaciones") != null:
		if tension_actual >= 0.9:
			hud.notificaciones.notificar_texto("¡A volar, parce!", Color(0.95, 0.72, 0.15))
		elif tension_actual >= 0.5:
			hud.notificaciones.notificar_texto("¡Buen salto!", Color(0.8, 0.75, 0.4))

func _buscar_joystick():
	if jugador:
		return jugador.get_node_or_null("UIpie/Controles/JoystickIzq")
	return null

func _buscar_hud():
	if jugador:
		return jugador.get_node_or_null("HUD")
	return null

func _update_shader(t: float, suelo: float) -> void:
	if material:
		material.set_shader_parameter("tension",      t)
		material.set_shader_parameter("en_suelo",     suelo)
		material.set_shader_parameter("tiempo_juego", float(Time.get_ticks_msec()) / 1000.0)
