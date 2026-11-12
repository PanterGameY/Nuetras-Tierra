# motor_auto.gd - Motor y transmisión independiente para automóviles turismos
extends Node3D

# --- Parámetros de Configuración del Motor ---
@export var fuerza_aceleracion_auto: float = 1050.0
@export var rpm_limite_auto: float = 6200.0

# --- Referencias a Componentes ---
var coche: RigidBody3D = null
var rpm_logic: Node = null

# --- Variables de Estado Interno ---
var gas_suavizado: float = 0.0
var rpm_motor: float = 800.0
var fuerza_ruedas: float = 0.0
var _current_gear: int = 0
var _shifting: bool = false
var _shift_timer: float = 0.0

func _ready() -> void:
	coche = get_parent()
	rpm_logic = coche.get_node_or_null("ControladorRPM")

func _physics_process(delta: float) -> void:
	if not coche or not coche.activo:
		return

	# Lectura centralizada de entradas desde el singleton del juego
	var iv = _get_iv()
	var pedal_raw: float = 0.0
	var freno_raw: float = 0.0
	var marcha_pedida = 0
	var encendido: bool = true
	if iv:
		pedal_raw = clampf(iv.get("gas"), 0.0, 1.0)
		freno_raw = clampf(iv.get("freno"), 0.0, 1.0)
		marcha_pedida = iv.get("marcha_actual")
		encendido = iv.get("motor_encendido") == true

	# Suavizado de gas rápido de automóvil (Inercia aumentada a 1.6 para sensación pesada)
	gas_suavizado = move_toward(gas_suavizado, pedal_raw, delta * 1.6)

	# Cálculo de la velocidad del vehículo
	var vel_local = coche.global_transform.basis.inverse() * coche.linear_velocity
	var speed_ms = -vel_local.z
	var speed_kmh = abs(speed_ms) * 3.6

	# Selección de marchas automáticas
	var en_drive: bool = false
	var en_reversa: bool = false
	if iv:
		en_drive = (marcha_pedida == iv.get("Marcha").DRIVE)
		en_reversa = (marcha_pedida == iv.get("Marcha").REVERSA)
	var en_neutro = not en_drive and not en_reversa

	if _shifting:
		_shift_timer -= delta
		if _shift_timer <= 0.0:
			_shifting = false

	# Transmisión automática de 5 marchas progresivas
	var velocidades_cambio = [0.0, 30.0, 60.0, 95.0, 140.0, 200.0]
	if en_drive and encendido and not _shifting:
		var target_g = _current_gear
		if speed_kmh > velocidades_cambio[_current_gear + 1] and _current_gear < 4:
			target_g += 1
		elif speed_kmh < velocidades_cambio[_current_gear] * 0.85 and _current_gear > 0:
			target_g -= 1
			
		if target_g != _current_gear:
			_current_gear = target_g
			_shifting = true
			_shift_timer = 0.15

	# Cálculo de fuerza de empuje longitudinal
	fuerza_ruedas = 0.0
	if encendido and not en_neutro:
		if en_reversa:
			fuerza_ruedas = -fuerza_aceleracion_auto * 0.8 * gas_suavizado
		else:
			var mult_marcha = lerpf(1.0, 0.40, float(_current_gear) / 4.0)
			fuerza_ruedas = fuerza_aceleracion_auto * gas_suavizado * mult_marcha

	# Simulación de revoluciones del motor
	var rpm_idle = 800.0
	var rpm_obj = rpm_idle

	if en_neutro:
		rpm_obj = rpm_idle + gas_suavizado * (rpm_limite_auto - rpm_idle)
	elif _shifting:
		rpm_obj = rpm_idle + (rpm_limite_auto - rpm_idle) * 0.3
	else:
		if en_reversa:
			rpm_obj = rpm_idle + (speed_kmh / 40.0) * (rpm_limite_auto - rpm_idle)
		else:
			var rango_vel = velocidades_cambio[_current_gear + 1] - velocidades_cambio[_current_gear]
			var progreso = (speed_kmh - velocidades_cambio[_current_gear]) / maxf(rango_vel, 1.0)
			progreso = clampf(progreso, 0.0, 1.0)
			rpm_obj = rpm_idle + (0.3 + 0.7 * progreso) * (rpm_limite_auto - rpm_idle)
			
	# Limitador de RPM
	if rpm_obj >= rpm_limite_auto - 100.0:
		rpm_obj = rpm_limite_auto - 200.0 if (Time.get_ticks_msec() / 50) % 2 == 0 else rpm_limite_auto

	rpm_motor = lerpf(rpm_motor, rpm_obj, delta * 12.0)
	
	if rpm_logic and rpm_logic.has_method("set_rpm"):
		rpm_logic.call("set_rpm", rpm_motor, 0.0)

func _get_iv() -> Node:
	var n = get_node_or_null("/root/InputVehiculo")
	if n: return n
	if is_instance_valid(InputVehiculo): return InputVehiculo
	return null
