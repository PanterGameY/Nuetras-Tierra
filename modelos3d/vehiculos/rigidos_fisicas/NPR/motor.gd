extends Node3D

# ═══════════════════════════════════════════════════════════════════════
# motor.gd — Sistema simple de motor y transmisión
# ═══════════════════════════════════════════════════════════════════════

@export_group("Configuración")
@export var config: MotorConfig = null

@export_group("Asistencias")
@export var auto_hold_habilitado: bool = true
@export var auto_hold_velocidad_ms: float = 1.0
@export var auto_hold_freno: float = 0.9

@export_group("Combustible")
@export var tipo_combustible: String = "diesel"
@export var capacidad_combustible_l: float = 400.0
@export var nivel_combustible_l: float = 200.0
@export var consumo_l_por_s_a_full: float = 0.02

@export_group("Debug")
@export var debug_transmission: bool = false

# ─── Estado ──────────────────────────────────────────────────────────
var rpm_motor: float = 0.0
var par_actual: float = 0.0
var freno_suavizado: float = 0.0
var gas_suavizado: float = 0.0
var audio_freno_motor: AudioStreamPlayer = null
var stream_freno_motor: AudioStream = null
var freno_motor_activo: bool = false
var _enganche_node: Node = null
var _con_remolque: bool = false

# ─── Marcha ──────────────────────────────────────────────────────────
var _current_gear: int = 0
var current_gear: int:
	get: return _current_gear
var _time_in_gear: float = 0.0

# ─── Cambio ──────────────────────────────────────────────────────────
var _shifting: bool = false
var _shift_timer: float = 0.0
var _shift_target_gear: int = -1

@onready var coche: RigidBody3D = _get_rigidbody_parent(get_parent())
@onready var llantas_ctrl: Node3D = null
@onready var rpm_logic: ControladorRPM = $ControladorRPM


func _ready() -> void:
	# Cargar el sonido de freno de motor una sola vez al inicio para evitar lag/demora al sonar
	stream_freno_motor = load("res://recursos/sonidos_vehiculo/freno_motor/FrenoM1.wav")
	if stream_freno_motor:
		if "loop_mode" in stream_freno_motor:
			stream_freno_motor.set("loop_mode", 1) # LOOP_FORWARD es 1 en Godot 4
		elif "loop" in stream_freno_motor:
			stream_freno_motor.set("loop", true)
	
	if coche:
		llantas_ctrl = coche.get_node_or_null("ControladorLlantas")
		if not llantas_ctrl:
			llantas_ctrl = coche.get_node_or_null("ControladosRuedas")
		_enganche_node = coche.find_child("Enganche", true, false)

func _get_iv() -> Node:
	# Intentar obtener el singleton/autoload por su nombre en /root
	var n = get_node_or_null("/root/InputVehiculo")
	if n:
		return n
	# Si el autoload está disponible como variable global (project autoload), úsala
	if is_instance_valid(InputVehiculo):
		return InputVehiculo
	return null

func set_config(cfg: MotorConfig) -> void:
	config = cfg

func set_info_combustible(tipo: String, capacidad_l: float, nivel_l: float) -> void:
	tipo_combustible = tipo
	capacidad_combustible_l = capacidad_l
	nivel_combustible_l = nivel_l


# ═══════════════════════════════════════════════════════════════════════
# PROCESO PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if not config or not coche or not coche.get("activo") or not llantas_ctrl:
		return

	var c: MotorConfig = config

	# ── Velocidad actual ─────────────────────────────────────────────
	var vel_local: Vector3 = coche.global_transform.basis.inverse() * coche.linear_velocity
	var speed_ms: float    = -vel_local.z
	var speed_kmh: float   = abs(speed_ms) * 3.6

	# Acceso seguro a InputVehiculo (autoload o nodo en /root)
	var iv = _get_iv()

	# ── Entradas ─────────────────────────────────────────────────────
	var pedal_raw: float = 0.0
	var _freno_in: float = 0.0
	var marcha = 0
	var motor_on: bool = false
	if iv:
		pedal_raw = clamp(iv.gas, 0.0, 1.0)
		_freno_in = clamp(iv.freno, 0.0, 1.0)
		marcha = iv.marcha_actual
		motor_on = iv.motor_encendido

	# Suavizar la respuesta del acelerador para simular la inercia del motor de un camión pesado
	# Subida progresiva (p.ej. tarda más en llegar a full torque), bajada más rápida (a ralentí)
	var ritmo_subida: float = 0.45
	var ritmo_bajada: float = 1.2
	if pedal_raw > gas_suavizado:
		gas_suavizado = move_toward(gas_suavizado, pedal_raw, delta * ritmo_subida)
	else:
		gas_suavizado = move_toward(gas_suavizado, pedal_raw, delta * ritmo_bajada)
	
	var gas: float = gas_suavizado

	if motor_on and nivel_combustible_l <= 0.0:
		motor_on = false

	var en_drive: bool = false
	var en_reversa: bool = false
	if iv:
		en_drive = (marcha == iv.Marcha.DRIVE)
		en_reversa = (marcha == iv.Marcha.REVERSA)
	var en_neutro: bool = not en_drive and not en_reversa

	# ── Detectar remolque ────────────────────────────────────────────
	if _enganche_node:
		_con_remolque = _enganche_node.get("conectado") == true

	# ── Resetear al salir de Drive ──────────────────────────────────
	if not en_drive and not en_reversa and (_current_gear != 0 or _shifting):
		_current_gear    = 0
		_shifting        = false
		_shift_timer     = 0.0
		_shift_target_gear = -1
		_time_in_gear    = 0.0

	# ── Tiempo en marcha ─────────────────────────────────────────────
	_time_in_gear += delta

	# ── Procesar cambio ──────────────────────────────────────────────
	if _shifting:
		_shift_timer -= delta
		if _shift_timer <= 0.0:
			_completar_cambio()

	# ── Evaluar cambio automático (solo con gas pisado) ──────────────
	if en_drive and motor_on and not _shifting and gas > 0.1:
		_evaluar_cambio(c, speed_kmh)

	# ── Bajar marcha al frenar, soltar gas o por pérdida de fuerza/RPM en subida ──────────
	if en_drive and motor_on and not _shifting:
		_evaluar_bajar_marcha(c, speed_kmh)

	# ── Calcular fuerza ──────────────────────────────────────────────
	var fuerza: float = 0.0
	if motor_on:
		if en_reversa:
			fuerza = _calcular_fuerza_reversa(c, pedal_raw, speed_kmh)
		elif en_drive:
			fuerza = _calcular_fuerza_drive(c, pedal_raw, speed_kmh)

	var frenando_motor = false
	if motor_on and en_drive and iv and iv.get("freno_motor") and pedal_raw < 0.05 and coche.linear_velocity.length() > 0.1:
		frenando_motor = true
		var factor_rpm = clamp(rpm_motor / c.rpm_maximas, 0.2, 1.0)
		# Freno de motor sin factor_peso_rep para una desaceleración suave y realista
		var fuerza_freno_motor = -c.fuerza_motor * 0.35 * factor_rpm
		var mult_marcha: float = 1.0
		var total = c.velocidad_marchas.size()
		if total > 1:
			mult_marcha = lerpf(1.0, 0.25, float(_current_gear) / float(total - 1))
		fuerza = fuerza_freno_motor * mult_marcha

	freno_motor_activo = frenando_motor
	_actualizar_sonido_freno_motor(frenando_motor)
	
	if iv and iv.get("freno_motor") and Engine.get_frames_drawn() % 30 == 0:
		print("[Motor Debug] Freno Motor Activado | motor_on:", motor_on, " | en_drive:", en_drive, " | pedal:", pedal_raw, " | vel:", coche.linear_velocity.length() if coche else 0.0, " | frenando:", frenando_motor)

	# ── Aplicar fuerza a las ruedas ──────────────────────────────────
	var par_motor_aplicar = fuerza
	# Si el freno de mano está activo, permitir torque si el jugador pisa con cierta fuerza.
	# Umbral reducido para evitar bloquear movimiento con pulsaciones normales.
	if iv and iv.freno_mano and gas < 0.05:
		par_motor_aplicar = 0.0
			
	llantas_ctrl.recibir_par_motor(par_motor_aplicar)
	
	# ── Frenos ───────────────────────────────────────────────────────
	var freno_obj: float = 0.0
	if gas < 0.1:
		if iv:
			freno_obj = clamp(iv.freno, 0.0, 1.0)
	var vel_fr: float    = 4.0 if freno_obj > freno_suavizado else 12.0
	freno_suavizado      = move_toward(freno_suavizado, freno_obj, vel_fr * delta)
	var auto_hold: bool  = auto_hold_habilitado and gas < 0.02 and abs(speed_ms) < auto_hold_velocidad_ms
	llantas_ctrl.aplicar_freno(max(freno_suavizado, auto_hold_freno if auto_hold else 0.0))

	# ── RPM visual ───────────────────────────────────────────────────
	_actualizar_rpm_visual(c, speed_kmh, gas, motor_on, en_neutro)

	# ── Combustible ──────────────────────────────────────────────────
	_procesar_combustible(delta, motor_on, gas)


# ═══════════════════════════════════════════════════════════════════════

func _evaluar_cambio(c: MotorConfig, speed_kmh: float) -> void:
	var total: int = c.velocidad_marchas.size()
	if total == 0 or _current_gear >= total:
		return

	var velocidad_objetivo: float = c.velocidad_marchas[_current_gear]
	# Subir marcha si el camión alcanza al menos el 95% de la velocidad objetivo de la marcha actual.
	# Esto permite exprimir todo el torque del motor y evitar subidas de marcha prematuras.
	if speed_kmh >= velocidad_objetivo * 0.95:
		if _current_gear < total - 1:
			_iniciar_cambio(_current_gear + 1)


func _evaluar_bajar_marcha(c: MotorConfig, speed_kmh: float) -> void:
	if _current_gear <= 0:
		return

	# Evitar rebajes de marcha rápidos o bucles inmediatamente después de cambiar de marcha
	# (da 0.8 segundos para que las RPM y la velocidad se estabilicen)
	if _time_in_gear < 0.8:
		return

	var velocidad_marcha_anterior: float = c.velocidad_marchas[_current_gear - 1]
	
	# Si estamos acelerando (gas > 0.15) pero la velocidad cae, bajamos marcha antes (96%)
	# para recuperar torque rápido en pendientes.
	# También forzamos el rebaje si las RPM caen cerca de ralentí (evita ahogarse en subida)
	var iv = _get_iv()
	var gas_in: float = iv.gas if iv else 0.0
	var limite_bajada = 0.96 if gas_in > 0.15 else 0.90
	
	if speed_kmh < velocidad_marcha_anterior * limite_bajada or rpm_motor < c.rpm_minimas + 80.0:
		_iniciar_cambio(_current_gear - 1)


func _iniciar_cambio(marcha_destino: int) -> void:
	_shift_target_gear = marcha_destino
	_shifting          = true
	_shift_timer       = config.tiempo_cambio if config else 0.5
	_time_in_gear      = 0.0

	var sonidos = get_node_or_null("Sonidos")
	if sonidos and sonidos.has_method("set_shifting"):
		sonidos.set_shifting(true)


func _completar_cambio() -> void:
	_shifting = false
	_shift_timer = 0.0
	_current_gear = _shift_target_gear
	_shift_target_gear = -1

	var sonidos = get_node_or_null("Sonidos")
	if sonidos and sonidos.has_method("set_shifting"):
		sonidos.set_shifting(false)
	if sonidos and sonidos.has_method("reproducir_cambio"):
		var iv = _get_iv()
		var gas_val: float = 0.0
		if iv:
			gas_val = clamp(iv.gas, 0.0, 1.0)
		sonidos.reproducir_cambio(_current_gear, config.velocidad_marchas.size(), gas_val, 0.5)


# ═══════════════════════════════════════════════════════════════════════
# CÁLCULO DE FUERZA
# ═══════════════════════════════════════════════════════════════════════

func _calcular_fuerza_drive(c: MotorConfig, gas: float, speed_kmh: float) -> float:
	var total: int = c.velocidad_marchas.size()
	if total == 0 or _current_gear >= total:
		return 0.0

	var velocidad_objetivo: float = c.velocidad_marchas[_current_gear]

	# Fuerza base escalada por marcha (mayor torque en marchas bajas, menos torque en marchas altas)
	var mult_marcha: float = 1.0
	if total > 1:
		# Aumentado el límite de fuerza mínima en marchas altas a 0.70 (antes 0.25)
		# Esto evita que el camión se quede sin fuerza y se tranque a 40-45 km/h
		mult_marcha = lerpf(1.0, 0.70, float(_current_gear) / float(total - 1))
	
	# Escalar la fuerza según el peso del chasis, pero dosificando más fuerza principalmente en subidas
	# para evitar aceleraciones exageradas de deportivo en plano mientras mantenemos fuerza de arrastre y trepada
	var factor_peso_rep: float = 1.0
	if coche:
		var peso_base = max(coche.mass / 1400.0, 1.0)
		var inclinacion: float = 0.0
		var dir_adelante = -coche.global_transform.basis.z
		inclinacion = dir_adelante.y # Positivo en subidas, negativo en bajadas
		var inclinacion_subida = clamp(inclinacion, 0.0, 0.5)
		
		# En plano (inclinación = 0) la fuerza es moderada (se escala solo un 30% del peso para simular torque de camión pesado sin acelerar como deportivo)
		# En subidas, se escala gradualmente hasta el 100% del peso para vencer la gravedad
		factor_peso_rep = lerpf(1.0 + (peso_base - 1.0) * 0.30, peso_base, inclinacion_subida * 3.5)
	
	var fuerza: float = c.fuerza_motor * gas * mult_marcha * factor_peso_rep

	# Simular el acople del convertidor de torque/embrague a baja velocidad en marchas bajas
	if _current_gear == 0 and speed_kmh < 15.0:
		var factor_acople: float = lerpf(0.55, 1.0, speed_kmh / 15.0)
		fuerza *= factor_acople

	# Si ya alcanzó la velocidad objetivo, mantener velocidad
	if speed_kmh >= velocidad_objetivo:
		return fuerza * 0.1 

	# Boost por remolque
	if _con_remolque:
		fuerza *= c.fuerza_remolque_mult

	# Reducir durante el cambio
	if _shifting:
		fuerza *= c.fuerza_durante_cambio

	# Reducir si frena
	var freno: float = 0.0
	var iv = _get_iv()
	if iv:
		freno = clamp(iv.freno, 0.0, 1.0)
	if freno > 0.05:
		fuerza *= clamp(1.0 - freno * 1.2, 0.0, 1.0)

	return fuerza


func _calcular_fuerza_reversa(c: MotorConfig, gas: float, speed_kmh: float) -> float:
	# Limitar velocidad en reversa
	if speed_kmh >= c.velocidad_max_reversa:
		return 0.0

	# Fuerza negativa para ir hacia atrás - RESTAURADA
	var factor_peso_rep: float = 1.0
	if coche:
		factor_peso_rep = max(coche.mass / 1400.0, 1.0)
	var fuerza: float = -c.fuerza_reversa * gas * factor_peso_rep

	if _con_remolque:
		fuerza *= c.fuerza_remolque_mult

	return fuerza


# ═══════════════════════════════════════════════════════════════════════
# RPM VISUAL
# ═══════════════════════════════════════════════════════════════════════

func _actualizar_rpm_visual(c: MotorConfig, speed_kmh: float, gas: float,
		motor_on: bool, en_neutro: bool) -> void:

	if not rpm_logic:
		return

	if not motor_on:
		rpm_motor = move_toward(rpm_motor, 0.0, 500.0 * get_physics_process_delta_time())
		rpm_logic.set_rpm(rpm_motor, 0.0)
		return

	var rpm_obj: float

	if en_neutro:
		rpm_obj = c.rpm_minimas + gas * (c.rpm_maximas - c.rpm_minimas)
	elif _shifting:
		rpm_obj = c.rpm_minimas + 200.0
	else:
		var total: int = c.velocidad_marchas.size()
		if total > 0 and _current_gear < total:
			var vel_max_marcha: float = c.velocidad_marchas[_current_gear]
			var ratio: float = clamp(speed_kmh / max(vel_max_marcha, 1.0), 0.0, 1.0)
			rpm_obj = c.rpm_minimas + ratio * (c.rpm_maximas - c.rpm_minimas)
		else:
			rpm_obj = c.rpm_minimas

	rpm_motor = lerp(rpm_motor, rpm_obj, 0.1)
	rpm_logic.set_rpm(rpm_motor, 0.0 if _shifting else get_physics_process_delta_time())


# ═══════════════════════════════════════════════════════════════════════
# COMBUSTIBLE
# ═══════════════════════════════════════════════════════════════════════

func _procesar_combustible(delta: float, motor_on: bool, gas: float) -> void:
	if not motor_on:
		return

	var consumo: float = consumo_l_por_s_a_full * max(gas, 0.05)
	nivel_combustible_l = max(nivel_combustible_l - consumo * delta, 0.0)

	var iv = _get_iv()
	if capacidad_combustible_l > 0.0 and iv:
		iv.combustible = clamp(nivel_combustible_l / capacidad_combustible_l * 100.0, 0.0, 100.0)

	if nivel_combustible_l <= 0.0:
		if iv:
			iv.motor_encendido = false
		var sd: Node = null
		if coche:
			sd = coche.get_node_or_null("Sonido_dual")
			if not sd:
				sd = coche.get_node_or_null("Sonidos")
		if not sd:
			sd = get_node_or_null("Sonido_dual")
		if sd and sd.has_method("reproducir_apagar"):
			sd.reproducir_apagar()


# ═══════════════════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════════════════

func _get_rigidbody_parent(n: Node) -> RigidBody3D:
	if n == null or n is RigidBody3D:
		return n
	return _get_rigidbody_parent(n.get_parent())


func _actualizar_sonido_freno_motor(debe_sonar: bool) -> void:
	if debe_sonar:
		if not audio_freno_motor:
			audio_freno_motor = AudioStreamPlayer.new()
			audio_freno_motor.stream = stream_freno_motor
			audio_freno_motor.volume_db = 16.0 # Máximo volumen global (duro duro)
			audio_freno_motor.bus = &"Master"
			add_child(audio_freno_motor)
		
		# Modula el pitch según las RPM del motor
		if config and config.rpm_maximas > 0.0:
			audio_freno_motor.pitch_scale = lerp(0.65, 1.35, rpm_motor / config.rpm_maximas)
		
		if not audio_freno_motor.playing:
			audio_freno_motor.play()
	else:
		if audio_freno_motor and audio_freno_motor.playing:
			audio_freno_motor.stop()
