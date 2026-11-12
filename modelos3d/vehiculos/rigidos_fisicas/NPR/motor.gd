extends Node3D

# ═══════════════════════════════════════════════════════════════════════
# motor.gd — Sistema simple de motor y transmisión
# ═══════════════════════════════════════════════════════════════════════

@export_group("Configuración")
@export var config: Resource = null

@export_group("Asistencias")
@export var auto_hold_habilitado: bool = true
@export var auto_hold_velocidad_ms: float = 1.0
@export var auto_hold_freno: float = 0.9

@export_group("Combustible")
@export var tipo_combustible: String = "diesel"
@export var capacidad_combustible_l: float = 400.0
@export var nivel_combustible_l: float = 200.0
@export var consumo_l_por_s_a_full: float = 0.02

@export_group("Física Analítica Pesada (Rigs of Rods)")
@export var habilitar_fisica_analitica: bool = true
@export var torque_max_nm: float = 2400.0         ## Torque máximo (Nm) típicamente 2000-2800 en camiones pesados
@export var rpm_idle: float = 600.0              ## Ralentí
@export var rpm_min_trabajo: float = 1100.0      ## Entrada de turbo
@export var rpm_max: float = 2300.0              ## Corte de inyección diésel pesado
@export var rpm_stall: float = 350.0             ## Calado de motor
@export var inercia_volante: float = 18.0        ## Inercia rotacional del cigüeñal (kg*m^2)
@export var relaciones_caja: Array[float] = [
	-13.8,  # R
	0.0,    # N
	14.4,   # 1ra
	10.8,   # 2da
	7.8,    # 3ra
	5.7,    # 4ta
	4.1,    # 5ta
	3.0,    # 6ta
	2.2,    # 7ma
	1.6,    # 8va
	1.2,    # 9na
	0.86    # 10ma (Sobremarcha)
]
@export var relacion_diferencial: float = 3.73
@export var tiempo_cambio_analitico: float = 0.55 ## Segundos que toma engranar marcha neumática
@export var torque_jake_max: float = 2100.0      ## Capacidad máxima de absorción del freno de compresión
@export var fuerza_frenos_servicio: float = 32000.0 ## Freno neumático de servicio (N)
var estado_embrague: float = 1.0 # 0.0 = desacoplado, 1.0 = acoplado
var reloj_cambio: float = 0.0

@export_group("Debug")
@export var debug_transmission: bool = false

# ─── Estado ──────────────────────────────────────────────────────────
var rpm_motor: float = 0.0
var par_actual: float = 0.0
var freno_suavizado: float = 0.0
var gas_suavizado: float = 0.0
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

var _velocidad_marchas: Array = [20.0, 35.0, 50.0, 65.0, 80.0, 100.0, 120.0]

func _ready() -> void:
	if coche:
		llantas_ctrl = coche.get_node_or_null("ControladorLlantas")
		if not llantas_ctrl:
			llantas_ctrl = coche.get_node_or_null("ControladosRuedas")
		_enganche_node = coche.find_child("Enganche", true, false)
	# Propagar config al controlador de RPM para que use los límites correctos del vehículo
	if rpm_logic and config:
		rpm_logic.config = config
	_actualizar_velocidad_marchas()

func _get_iv() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/InputVehiculo")

func _actualizar_velocidad_marchas() -> void:
	if config:
		var arr = config.get("velocidad_marchas")
		if arr != null and not arr.is_empty():
			_velocidad_marchas = arr
		else:
			_velocidad_marchas = [20.0, 35.0, 50.0, 65.0, 80.0, 100.0, 120.0]

func set_config(cfg: Resource) -> void:
	config = cfg
	# Propagar al ControladorRPM para que use los límites correctos (rpm_minimas, rpm_maximas)
	if rpm_logic:
		rpm_logic.config = cfg
	_actualizar_velocidad_marchas()

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

	var c: Resource = config

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
		reloj_cambio += delta
		var dur_cambio: float = tiempo_cambio_analitico if habilitar_fisica_analitica else (config.tiempo_cambio if config else 0.5)
		var mitad_tiempo: float = dur_cambio * 0.5
		if reloj_cambio < mitad_tiempo:
			var t_norm: float = reloj_cambio / maxf(mitad_tiempo, 0.001)
			estado_embrague = pow(1.0 - t_norm, 2.0)
		else:
			_current_gear = _shift_target_gear
			var t_norm: float = (reloj_cambio - mitad_tiempo) / maxf(mitad_tiempo, 0.001)
			estado_embrague = sqrt(clampf(t_norm, 0.0, 1.0))

		if _shift_timer <= 0.0 or reloj_cambio >= dur_cambio:
			_completar_cambio()
	else:
		estado_embrague = 1.0
		reloj_cambio = 0.0

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
		if habilitar_fisica_analitica:
			var idx_m = clamp(_current_gear + 2, 2, relaciones_caja.size() - 1)
			var ratio_caja = absf(relaciones_caja[idx_m]) * relacion_diferencial
			var factor_rpm = clampf((rpm_motor - rpm_idle) / maxf(rpm_max - rpm_idle, 1.0), 0.35, 1.0)
			var torque_retardo = (torque_jake_max + (torque_max_nm * 0.20)) * factor_rpm * ratio_caja * 0.35
			fuerza = -signf(speed_ms) * torque_retardo
		else:
			var factor_rpm = clamp(rpm_motor / c.rpm_maximas, 0.2, 1.0)
			# Freno de motor sin factor_peso_rep para una desaceleración suave y realista
			var fuerza_freno_motor = -c.fuerza_motor * 0.35 * factor_rpm
			var mult_marcha: float = 1.0
			var total = _velocidad_marchas.size()
			if total > 1:
				mult_marcha = lerpf(1.0, 0.25, float(_current_gear) / float(total - 1))
			fuerza = fuerza_freno_motor * mult_marcha

	freno_motor_activo = frenando_motor
	# Delegar el sonido de freno de motor al nodo Sonidos (respeta el stream asignado en escena)
	var _sonidos = get_node_or_null("Sonidos")
	if _sonidos and _sonidos.has_method("set_freno_motor"):
		_sonidos.set_freno_motor(frenando_motor)

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

func _evaluar_cambio(_c, speed_kmh: float) -> void:
	var total: int = _velocidad_marchas.size()
	if total == 0 or _current_gear >= total:
		return

	var velocidad_objetivo: float = _velocidad_marchas[_current_gear]
	# Subir marcha si el camión alcanza al menos el 95% de la velocidad objetivo de la marcha actual.
	# Con remolque pesado, debe estirar más la marcha (98.5%) antes de cambiar para no perder impulso.
	var factor_umbral_cambio: float = 0.95
	if coche and coche.has_method("obtener_peso_remolque") and coche.obtener_peso_remolque() > 6000.0:
		factor_umbral_cambio = 0.985

	if speed_kmh >= velocidad_objetivo * factor_umbral_cambio:
		if _current_gear < total - 1:
			_iniciar_cambio(_current_gear + 1)


func _evaluar_bajar_marcha(c, speed_kmh: float) -> void:
	if _current_gear <= 0:
		return

	# Evitar rebajes de marcha rápidos o bucles inmediatamente después de cambiar de marcha
	# (da 0.8 segundos para que las RPM y la velocidad se estabilicen)
	if _time_in_gear < 0.8:
		return

	var velocidad_marcha_anterior: float = _velocidad_marchas[_current_gear - 1]
	
	# Si estamos acelerando (gas > 0.15) pero la velocidad cae, bajamos marcha antes (96%)
	# para recuperar torque rápido en pendientes. Con remolque pesado, el límite es 98%
	# También forzamos el rebaje si las RPM caen cerca de ralentí (evita ahogarse en subida)
	var iv = _get_iv()
	var gas_in: float = iv.gas if iv else 0.0
	var limite_bajada = 0.96 if gas_in > 0.15 else 0.90
	if coche and coche.has_method("obtener_peso_remolque") and coche.obtener_peso_remolque() > 6000.0:
		limite_bajada = 0.98
	
	if speed_kmh < velocidad_marcha_anterior * limite_bajada or rpm_motor < c.rpm_minimas + 80.0:
		_iniciar_cambio(_current_gear - 1)


func _iniciar_cambio(marcha_destino: int) -> void:
	_shift_target_gear = marcha_destino
	_shifting          = true
	_shift_timer       = tiempo_cambio_analitico if habilitar_fisica_analitica else (config.tiempo_cambio if config else 0.5)
	_time_in_gear      = 0.0
	reloj_cambio       = 0.0

	var sonidos = get_node_or_null("Sonidos")
	if sonidos and sonidos.has_method("set_shifting"):
		sonidos.set_shifting(true)


func _completar_cambio() -> void:
	_shifting = false
	_shift_timer = 0.0
	reloj_cambio = 0.0
	estado_embrague = 1.0
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
		sonidos.reproducir_cambio(_current_gear, _velocidad_marchas.size(), gas_val, 0.5)


# ═══════════════════════════════════════════════════════════════════════
# CÁLCULO DE FUERZA
# ═══════════════════════════════════════════════════════════════════════

# FÓRMULA DE CURVA DE TORQUE DIÉSEL (RoR Spline Approximation)
func _calcular_factor_torque_diesel(rpm: float) -> float:
	if rpm < rpm_stall:
		return 0.1
	elif rpm < rpm_idle:
		return lerpf(0.3, 0.75, (rpm - rpm_stall) / maxf(rpm_idle - rpm_stall, 1.0))
	elif rpm <= 1800.0:
		# Meseta de torque máximo diésel entre 1100 y 1800 RPM
		return 1.0
	elif rpm <= rpm_max:
		# Caída de torque suave post-meseta
		return lerpf(1.0, 0.70, (rpm - 1800.0) / maxf(rpm_max - 1800.0, 1.0))
	else:
		# Corte por inyección
		return clampf(lerpf(0.70, 0.0, (rpm - rpm_max) / 250.0), 0.0, 1.0)

func _calcular_fuerza_drive(c: Resource, gas: float, speed_kmh: float) -> float:
	var total: int = _velocidad_marchas.size()
	if total == 0 or _current_gear >= total:
		return 0.0

	var velocidad_objetivo: float = _velocidad_marchas[_current_gear]

	if habilitar_fisica_analitica:
		var idx_marcha = clamp(_current_gear + 2, 2, relaciones_caja.size() - 1)
		var ratio_caja = relaciones_caja[idx_marcha] * relacion_diferencial
		var factor_diesel = _calcular_factor_torque_diesel(rpm_motor)
		var fuerza_analitica: float = torque_max_nm * factor_diesel * gas * ratio_caja * estado_embrague
		
		# Compensación por remolque acoplado
		if _con_remolque and coche and coche.has_method("obtener_peso_remolque"):
			var p_rem = coche.obtener_peso_remolque()
			if p_rem > 5000.0:
				fuerza_analitica *= (1.0 + clampf(p_rem / 40000.0, 0.0, 0.50))
		
		if speed_kmh >= velocidad_objetivo:
			fuerza_analitica *= 0.15

		var freno: float = 0.0
		var iv = _get_iv()
		if iv:
			freno = clamp(iv.freno, 0.0, 1.0)
		if freno > 0.05:
			fuerza_analitica *= clamp(1.0 - freno * 1.2, 0.0, 1.0)

		return fuerza_analitica

	# Fuerza base escalada por marcha (mayor torque en marchas bajas, menos torque en marchas altas)
	var mult_marcha: float = 1.0
	if total > 1:
		# Aumentado el límite de fuerza mínima en marchas altas a 0.70 (antes 0.25)
		# Esto evita que el camión se quede sin fuerza y se tranque a 40-45 km/h
		mult_marcha = lerpf(1.0, 0.70, float(_current_gear) / float(total - 1))
	
	# Escalar la fuerza según el peso total del conjunto (camión + remolque)
	var factor_peso_rep: float = 1.0
	var masa_total_arrastre: float = coche.mass if coche else 1400.0
	if coche:
		if coche.has_method("obtener_peso_remolque"):
			var p_rem: float = coche.obtener_peso_remolque()
			if p_rem > 0.0:
				masa_total_arrastre += p_rem
		elif _con_remolque and _enganche_node:
			var remoto = _enganche_node.get("enganche_remoto")
			if remoto and _enganche_node.has_method("_buscar_cuerpo"):
				var b = _enganche_node._buscar_cuerpo(remoto)
				if b and "mass" in b:
					masa_total_arrastre += b.mass

		var peso_base = max(masa_total_arrastre / 1400.0, 1.0)
		var dir_adelante = -coche.global_transform.basis.z
		var inclinacion_subida: float = clampf(dir_adelante.dot(Vector3.UP), 0.0, 1.0)
		# Escala de fuerza en función del peso total arrastrado:
		# En marchas bajas (1ª y 2ª), el camión cuenta con suficiente torque para arrancar
		# con soltura llevando 20, 30 y 40 toneladas, y arrastrar con fuerza 50 toneladas.
		var mult_torque_peso: float = 0.88 if _current_gear <= 1 else 0.70
		factor_peso_rep = lerpf(1.0 + (peso_base - 1.0) * mult_torque_peso, peso_base, inclinacion_subida * 3.0)
	
	var fuerza: float = c.fuerza_motor * gas * mult_marcha * factor_peso_rep

	# Simular el acople del convertidor de torque/embrague a baja velocidad en marchas bajas
	if _current_gear == 0 and speed_kmh < 15.0:
		var acople_base: float = 0.80 if _con_remolque else 0.60
		var factor_acople: float = lerpf(acople_base, 1.0, speed_kmh / 15.0)
		fuerza *= factor_acople

	# Si ya alcanzó la velocidad objetivo, mantener velocidad
	if speed_kmh >= velocidad_objetivo:
		return fuerza * 0.1 

	# Multiplicador de potencia por remolque
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


func _calcular_fuerza_reversa(c: Resource, gas: float, speed_kmh: float) -> float:
	# Limitar velocidad en reversa
	var max_rev = c.get("velocidad_max_reversa")
	if max_rev == null:
		max_rev = 15.0
	if speed_kmh >= max_rev:
		return 0.0

	if habilitar_fisica_analitica:
		var ratio_rev = relaciones_caja[0] * relacion_diferencial
		var factor_diesel = _calcular_factor_torque_diesel(rpm_motor)
		var torque_motor = torque_max_nm * factor_diesel * gas * ratio_rev * estado_embrague
		if _con_remolque:
			torque_motor *= 1.2
		return torque_motor

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

func _actualizar_rpm_visual(c: Resource, speed_kmh: float, gas: float,
		motor_on: bool, en_neutro: bool) -> void:

	if not rpm_logic:
		return

	if not motor_on:
		rpm_motor = move_toward(rpm_motor, 0.0, 500.0 * get_physics_process_delta_time())
		rpm_logic.set_rpm(rpm_motor, 0.0)
		return

	if habilitar_fisica_analitica:
		var delta_t = get_physics_process_delta_time()
		if en_neutro:
			var torque_comb = torque_max_nm * _calcular_factor_torque_diesel(rpm_motor) * gas
			var torque_fric = (torque_max_nm * 0.20) * (rpm_motor / rpm_max) * (1.0 - gas)
			var delta_rpm = ((torque_comb - torque_fric) / inercia_volante) * delta_t * 9.54929
			rpm_motor = clampf(rpm_motor + delta_rpm, rpm_idle, rpm_max + 200.0)
		elif _shifting:
			rpm_motor = lerpf(rpm_motor, lerpf(1150.0, 1380.0, gas), clampf(delta_t * 8.0, 0.0, 1.0))
		else:
			var idx_m = clamp(_current_gear + 2, 2, relaciones_caja.size() - 1)
			var ratio_rpm = absf(relaciones_caja[idx_m]) * relacion_diferencial
			var speed_ms = (speed_kmh / 3.6)
			var radio_r = 0.52
			var vel_rueda_rad = (speed_ms / maxf(radio_r, 0.1))
			var rpm_transmision = vel_rueda_rad * ratio_rpm * 9.54929
			var rpm_obj = clampf(maxf(rpm_idle, rpm_transmision) + (gas * 140.0), rpm_idle, rpm_max)
			var vel_inercia = 10.0 * (18.0 / maxf(inercia_volante, 1.0))
			rpm_motor = lerpf(rpm_motor, rpm_obj, clampf(delta_t * vel_inercia, 0.0, 1.0))
		
		rpm_logic.set_rpm(rpm_motor, 0.0)
		return

	var rpm_obj: float

	if en_neutro:
		rpm_obj = c.rpm_minimas + gas * (c.rpm_maximas - c.rpm_minimas)
	elif _shifting:
		rpm_obj = c.rpm_minimas + 200.0
	else:
		var total: int = _velocidad_marchas.size()
		if total > 0 and _current_gear < total:
			var vel_max_marcha: float = _velocidad_marchas[_current_gear]
			var ratio: float = clamp(speed_kmh / max(vel_max_marcha, 1.0), 0.0, 1.0)
			rpm_obj = c.rpm_minimas + ratio * (c.rpm_maximas - c.rpm_minimas)
		else:
			rpm_obj = c.rpm_minimas

	rpm_motor = lerp(rpm_motor, rpm_obj, 0.12)
	rpm_logic.set_rpm(rpm_motor, 0.0)


# -----------------------------------------------------------------------
# COMBUSTIBLE
# -----------------------------------------------------------------------

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


# -----------------------------------------------------------------------
# UTILIDADES
# -----------------------------------------------------------------------

func _get_rigidbody_parent(n: Node) -> RigidBody3D:
	if n == null or n is RigidBody3D:
		return n
	return _get_rigidbody_parent(n.get_parent())
