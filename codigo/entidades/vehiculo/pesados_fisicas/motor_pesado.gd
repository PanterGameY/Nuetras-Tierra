# motor_pesado.gd - Motor y transmisión diésel para vehículos pesados y tractocamiones
# Calibrado con curva de par diésel real, freno de motor (Jake Brake / Retarder),
# Auto-Hold en pendiente, consumo de combustible y sincronización acústica con Sonido_dual.
extends Node3D

@export_group("Configuración Opcional")
@export var config: Resource = null

@export_group("Combustible y Tanque Diésel")
@export var capacidad_combustible_l: float = 400.0
@export var nivel_combustible_l: float = 400.0
@export var consumo_ralenti_l_s: float = 0.012
@export var consumo_plena_carga_l_s: float = 0.16

@export_group("Potencia y Rendimiento")
## Fuerza base de tracción total repartida entre las ruedas motrices (N)
@export var fuerza_aceleracion_pesado: float = 24000.0
@export var rpm_limite_pesado: float = 2200.0
@export var rpm_idle: float = 650.0
@export var velocidad_maxima_kmh: float = 125.0
## Fuerza de retención del Freno de Motor / Retarder (Jake Brake)
@export var torque_retardador: float = 16500.0

@export_group("Transmisión y Embrague")
@export var tiempo_cambio: float = 0.52
@export var fuerza_durante_cambio: float = 0.72
@export var acople_arranque_min: float = 0.42
@export var auto_hold_pendiente: bool = true

@export_group("Sistema de Daños")
@export var motor_danado: bool = false:
	set(val):
		motor_danado = val
		_actualizar_estado_dano()

@export_range(0.0, 0.9, 0.05) var reduccion_potencia_dano: float = 0.40

@export var offset_humo: Vector3 = Vector3(0.0, 0.0, 0.0):
	set(val):
		offset_humo = val
		if is_instance_valid(_humo_dano):
			_humo_dano.position = offset_humo

@export var tamano_area_humo: Vector3 = Vector3(0.65, 0.08, 0.65):
	set(val):
		tamano_area_humo = val
		if is_instance_valid(_humo_dano):
			_humo_dano.emission_box_extents = tamano_area_humo

@export_group("Humo de Escape y Aceleración")
@export var marker_escape: Node3D = null:
	set(val):
		marker_escape = val
		if is_instance_valid(_humo_aceleracion) and "marker_escape" in _humo_aceleracion:
			_humo_aceleracion.marker_escape = val

@export var marker_escape_der: Node3D = null:
	set(val):
		marker_escape_der = val
		if is_instance_valid(_humo_aceleracion) and "marker_escape_der" in _humo_aceleracion:
			_humo_aceleracion.marker_escape_der = val

@export var humo_aceleracion_habilitado: bool = true:
	set(val):
		humo_aceleracion_habilitado = val
		if is_instance_valid(_humo_aceleracion) and "humo_habilitado" in _humo_aceleracion:
			_humo_aceleracion.humo_habilitado = val

@export var escape_doble: bool = true:
	set(val):
		escape_doble = val
		if is_instance_valid(_humo_aceleracion) and "escape_doble" in _humo_aceleracion:
			_humo_aceleracion.escape_doble = val

@export var separacion_escapes: float = 1.6:
	set(val):
		separacion_escapes = val
		if is_instance_valid(_humo_aceleracion) and "separacion_escapes" in _humo_aceleracion:
			_humo_aceleracion.separacion_escapes = val

@export var offset_escape: Vector3 = Vector3(0.0, 2.85, -1.95):
	set(val):
		offset_escape = val
		if is_instance_valid(_humo_aceleracion) and "offset_escape" in _humo_aceleracion:
			_humo_aceleracion.offset_escape = val

@export var color_escape_nucleo: Color = Color(0.12, 0.12, 0.14, 0.85):
	set(val):
		color_escape_nucleo = val
		if is_instance_valid(_humo_aceleracion) and "color_nucleo" in _humo_aceleracion:
			_humo_aceleracion.color_nucleo = val

@export var color_escape_borde: Color = Color(0.20, 0.21, 0.23, 0.85):
	set(val):
		color_escape_borde = val
		if is_instance_valid(_humo_aceleracion) and "color_borde" in _humo_aceleracion:
			_humo_aceleracion.color_borde = val

# --- Referencias a Componentes ---
var coche: RigidBody3D = null
var rpm_logic: Node = null
var sonidos_nodo: Node = null
var _humo_dano: CPUParticles3D = null
var _humo_aceleracion: Node = null
var _iv_cache: Node = null

# --- Variables de Estado Interno (API Pública leída por llanta_pesada, Sonido_dual y UIVehiculo) ---
var gas_suavizado: float = 0.0
var rpm_motor: float = 0.0
var fuerza_ruedas: float = 0.0
var freno_motor_activo: bool = false
var auto_hold_activo: bool = false

var _current_gear: int = 0
var current_gear: int:
	get:
		return _current_gear

var _shifting: bool = false
var _shift_timer: float = 0.0
var _shift_target_gear: int = 0
var _time_in_gear: float = 0.0
var _factor_embrague: float = 1.0
var _motor_estaba_encendido: bool = false

# --- Compatibilidad con Sistemas de Falla / Diagnóstico ---
var temperatura_motor: float = 85.0
var falla_motor_activa: bool = false
var tipo_falla: String = ""
var _alerta_sin_combustible_emitida: bool = false

# --- Mapeo de Transmisión de 10 Marchas Diésel Pesadas ---
const MULT_MARCHAS: Array[float] = [
	2.15,  # 1ª: Arranque pesado y pendientes fuertes
	1.72,  # 2ª: Salida con carga
	1.42,  # 3ª: Transición baja
	1.20,  # 4ª: Media baja
	1.04,  # 5ª: Media
	0.92,  # 6ª: Media alta
	0.82,  # 7ª: Ruta secundaria
	0.74,  # 8ª: Crucero de ascenso
	0.67,  # 9ª: Autopista
	0.60   # 10ª: Overdrive crucero (110-125 km/h)
]

const VEL_SUBIDA: Array[float] = [
	13.0,  # 1ª -> 2ª
	24.0,  # 2ª -> 3ª
	36.0,  # 3ª -> 4ª
	49.0,  # 4ª -> 5ª
	63.0,  # 5ª -> 6ª
	77.0,  # 6ª -> 7ª
	91.0,  # 7ª -> 8ª
	104.0, # 8ª -> 9ª
	116.0  # 9ª -> 10ª
]

const VEL_BAJADA: Array[float] = [
	0.0,   # 1ª
	7.5,   # 2ª -> 1ª
	16.0,  # 3ª -> 2ª
	26.0,  # 4ª -> 3ª
	37.0,  # 5ª -> 4ª
	49.0,  # 6ª -> 5ª
	61.0,  # 7ª -> 6ª
	73.0,  # 8ª -> 7ª
	85.0,  # 9ª -> 8ª
	96.0   # 10ª -> 9ª
]

func _ready() -> void:
	coche = get_parent() as RigidBody3D
	if not coche:
		var p = get_parent()
		while p and not (p is RigidBody3D):
			p = p.get_parent()
		coche = p as RigidBody3D

	# Localizar ControladorRPM (puede ser hijo de Motor o hermano bajo coche)
	rpm_logic = get_node_or_null("ControladorRPM")
	if not rpm_logic and coche:
		rpm_logic = coche.get_node_or_null("ControladorRPM")
		if not rpm_logic:
			rpm_logic = coche.find_child("ControladorRPM", true, false)

	if rpm_logic:
		if "audio_gestionado_externamente" in rpm_logic:
			rpm_logic.audio_gestionado_externamente = true
		if rpm_logic.has_method("configurar_limites_motor"):
			rpm_logic.call("configurar_limites_motor", rpm_idle, rpm_limite_pesado)

	_buscar_nodo_sonidos()
	_crear_humo_dano()
	_actualizar_estado_dano()
	_crear_humo_aceleracion()

func _buscar_nodo_sonidos() -> void:
	sonidos_nodo = get_node_or_null("SonidoVehiculoPesado")
	if not sonidos_nodo:
		sonidos_nodo = get_node_or_null("SonidoVehiculo")
	if not sonidos_nodo:
		sonidos_nodo = get_node_or_null("Sonidos")
	if not sonidos_nodo:
		sonidos_nodo = get_node_or_null("Sonido_dual")
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.get_node_or_null("SonidoVehiculoPesado")
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.get_node_or_null("SonidoVehiculo")
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.get_node_or_null("Sonidos")
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.get_node_or_null("Sonido_dual")
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.find_child("SonidoVehiculoPesado", true, false)
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.find_child("SonidoVehiculo", true, false)
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.find_child("Sonidos", true, false)
	if not sonidos_nodo and coche:
		sonidos_nodo = coche.find_child("Sonido_dual", true, false)

	# Autoinstanciación transparente: Si la escena no tiene nodo acústico, se crea automáticamente
	if not sonidos_nodo:
		var nuevo_sonido = SonidoVehiculoPesado.new()
		nuevo_sonido.name = "SonidoVehiculoPesado"
		add_child(nuevo_sonido)
		sonidos_nodo = nuevo_sonido

func _crear_humo_dano() -> void:
	if is_instance_valid(_humo_dano):
		return

	_humo_dano = get_node_or_null("HumoDanoMotor") as CPUParticles3D
	if not _humo_dano:
		_humo_dano = CPUParticles3D.new()
		_humo_dano.name = "HumoDanoMotor"
		add_child(_humo_dano)

	_humo_dano.position = offset_humo
	_humo_dano.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_humo_dano.emission_box_extents = tamano_area_humo

	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.95, 0.95)

	var shader_humo = load("res://shaders/humo_motor_realista.gdshader")
	if shader_humo:
		var mat_shader = ShaderMaterial.new()
		mat_shader.shader = shader_humo
		mat_shader.set_shader_parameter("color_humo", Color(0.06, 0.06, 0.07, 1.0))
		mat_shader.set_shader_parameter("opacidad_maxima", 0.65)
		quad_mesh.material = mat_shader
	else:
		var mat_base = StandardMaterial3D.new()
		mat_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_base.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_base.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat_base.vertex_color_use_as_albedo = true
		quad_mesh.material = mat_base

	_humo_dano.mesh = quad_mesh
	_humo_dano.emitting = motor_danado
	_humo_dano.amount = 30
	_humo_dano.lifetime = 1.05
	_humo_dano.one_shot = false
	_humo_dano.randomness = 0.50
	_humo_dano.local_coords = false
	_humo_dano.direction = Vector3(0.0, 1.0, 0.0)
	_humo_dano.spread = 32.0
	_humo_dano.gravity = Vector3(0.0, 0.32, 0.0)
	_humo_dano.initial_velocity_min = 0.20
	_humo_dano.initial_velocity_max = 0.60

	var gradiente = Gradient.new()
	gradiente.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradiente.add_point(0.15, Color(1.0, 1.0, 1.0, 0.85))
	gradiente.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_humo_dano.color_ramp = gradiente

	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.65))
	curve.add_point(Vector2(1.0, 2.30))
	_humo_dano.scale_amount_curve = curve

func _actualizar_estado_dano() -> void:
	falla_motor_activa = motor_danado
	if not is_instance_valid(_humo_dano):
		_crear_humo_dano()
	if is_instance_valid(_humo_dano):
		_humo_dano.emitting = motor_danado

func _crear_humo_aceleracion() -> void:
	if is_instance_valid(_humo_aceleracion):
		return

	if coche:
		_humo_aceleracion = coche.find_child("HumoAceleracion", true, false)
	if not _humo_aceleracion:
		_humo_aceleracion = get_node_or_null("HumoAceleracion")

	if not is_instance_valid(_humo_aceleracion) and humo_aceleracion_habilitado:
		var script_humo = preload("res://codigo/entidades/vehiculo/pesados_fisicas/humo_escape_pesado.gd")
		var humo_inst: Node3D = script_humo.new()
		humo_inst.name = "HumoAceleracion"
		add_child(humo_inst)
		_humo_aceleracion = humo_inst

	if not is_instance_valid(_humo_aceleracion):
		return

	if _humo_aceleracion.has_method("set_coche"):
		_humo_aceleracion.set_coche(coche)
	if "marker_escape" in _humo_aceleracion:
		_humo_aceleracion.marker_escape = marker_escape
	if "marker_escape_der" in _humo_aceleracion:
		_humo_aceleracion.marker_escape_der = marker_escape_der
	if "humo_habilitado" in _humo_aceleracion:
		_humo_aceleracion.humo_habilitado = humo_aceleracion_habilitado
	if "escape_doble" in _humo_aceleracion:
		_humo_aceleracion.escape_doble = escape_doble
	if "separacion_escapes" in _humo_aceleracion:
		_humo_aceleracion.separacion_escapes = separacion_escapes
	if "offset_escape" in _humo_aceleracion:
		_humo_aceleracion.offset_escape = offset_escape
	if "color_nucleo" in _humo_aceleracion:
		_humo_aceleracion.color_nucleo = color_escape_nucleo
	if "color_borde" in _humo_aceleracion:
		_humo_aceleracion.color_borde = color_escape_borde

func _calcular_curva_par_diesel(rpm: float) -> float:
	var rpm_stall: float = 350.0
	if rpm < rpm_stall:
		return 0.10
	elif rpm < rpm_idle:
		return lerpf(0.35, 0.65, (rpm - rpm_stall) / maxf(rpm_idle - rpm_stall, 1.0))
	elif rpm < 1150.0:
		# Spool de turbo y aumento de torque desde ralentí (RoR)
		return lerpf(0.65, 1.0, (rpm - rpm_idle) / (1150.0 - rpm_idle))
	elif rpm <= 1550.0:
		# Meseta de par máximo diésel (2400 Nm Cummins/CAT sweet spot)
		return 1.0
	elif rpm <= 1850.0:
		# Zona de máxima potencia en caballos de fuerza (HP peak)
		return lerpf(1.0, 0.84, (rpm - 1550.0) / 300.0)
	elif rpm <= rpm_limite_pesado:
		# Caída hacia el corte de inyección
		return lerpf(0.84, 0.58, (rpm - 1850.0) / maxf(rpm_limite_pesado - 1850.0, 1.0))
	else:
		# Corte del gobernador de inyección electrónica
		return clampf(lerpf(0.58, 0.0, (rpm - rpm_limite_pesado) / 150.0), 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if not coche or not coche.activo or (coche.has_method("es_autoridad_local") and not coche.es_autoridad_local()):
		fuerza_ruedas = 0.0
		freno_motor_activo = false
		auto_hold_activo = false
		if is_instance_valid(_humo_dano):
			_humo_dano.emitting = motor_danado and (coche.activo if coche else false)
		if is_instance_valid(_humo_aceleracion) and _humo_aceleracion.has_method("actualizar"):
			var vel_remota = coche.linear_velocity.length() * 3.6 if coche else 0.0
			var act_remoto = coche.activo if coche else false
			_humo_aceleracion.actualizar(0.4 if act_remoto and vel_remota > 2.0 else 0.0, vel_remota, act_remoto, delta, false)
		return

	var iv = _get_iv()
	var pedal_raw: float = 0.0
	var freno_raw: float = 0.0
	var freno_mano: bool = false
	var sw_freno_motor: bool = false
	var marcha_pedida: int = 2
	var encendido: bool = false

	if iv:
		pedal_raw = clampf(float(iv.get("gas")) if iv.get("gas") != null else 0.0, 0.0, 1.0)
		freno_raw = clampf(float(iv.get("freno")) if iv.get("freno") != null else 0.0, 0.0, 1.0)
		freno_mano = iv.get("freno_mano") == true
		sw_freno_motor = iv.get("freno_motor") == true
		marcha_pedida = int(iv.get("marcha_actual")) if iv.get("marcha_actual") != null else 2
		encendido = iv.get("motor_encendido") == true

	# Consumo dinámico de combustible diésel
	if encendido:
		if nivel_combustible_l > 0.0:
			var factor_rpm = clampf((rpm_motor - rpm_idle) / maxf(rpm_limite_pesado - rpm_idle, 1.0), 0.0, 1.0)
			var tasa_consumo = lerpf(consumo_ralenti_l_s, consumo_plena_carga_l_s, clampf(pedal_raw * 0.72 + factor_rpm * 0.28, 0.0, 1.0))
			nivel_combustible_l = maxf(0.0, nivel_combustible_l - tasa_consumo * delta)
			if iv and "combustible" in iv:
				iv.combustible = (nivel_combustible_l / maxf(capacidad_combustible_l, 1.0)) * 100.0
		if nivel_combustible_l <= 0.0:
			encendido = false
			if iv:
				iv.set("motor_encendido", false)
			if not _alerta_sin_combustible_emitida:
				_alerta_sin_combustible_emitida = true
				var cel = get_tree().get_first_node_in_group("celular_ui")
				if not cel and has_node("/root/CelularUI"):
					cel = get_node("/root/CelularUI")
				if cel and cel.has_method("notificar"):
					cel.call("notificar", "🚨 ¡TE QUEDASTE SIN COMBUSTIBLE! Llama al Auxilio Mecánico desde la Tableta.", "alerta")
		elif nivel_combustible_l > 25.0:
			_alerta_sin_combustible_emitida = false

	# Detectar transición de encendido/apagado para efectos de sonido
	if not is_instance_valid(sonidos_nodo):
		_buscar_nodo_sonidos()
	if encendido != _motor_estaba_encendido:
		_motor_estaba_encendido = encendido
		if is_instance_valid(sonidos_nodo):
			if encendido and sonidos_nodo.has_method("reproducir_encender"):
				sonidos_nodo.call("reproducir_encender")
			elif not encendido and sonidos_nodo.has_method("reproducir_apagar"):
				sonidos_nodo.call("reproducir_apagar")
	elif encendido and is_instance_valid(sonidos_nodo) and "motor_encendido" in sonidos_nodo and not bool(sonidos_nodo.get("motor_encendido")):
		if sonidos_nodo.has_method("encender_motor"):
			sonidos_nodo.call("encender_motor")

	if is_instance_valid(_humo_dano):
		_humo_dano.emitting = motor_danado and encendido

	# Respuesta progresiva del acelerador diésel
	var ritmo_subida = 2.8
	var ritmo_bajada = 4.2
	if not encendido or pedal_raw <= 0.02:
		gas_suavizado = move_toward(gas_suavizado, 0.0, delta * 8.0)
	elif pedal_raw > gas_suavizado:
		gas_suavizado = move_toward(gas_suavizado, pedal_raw, delta * ritmo_subida)
	else:
		gas_suavizado = move_toward(gas_suavizado, pedal_raw, delta * ritmo_bajada)

	# Velocidades con signo (avance positivo, retroceso negativo)
	var car_basis = coche.global_transform.basis.orthonormalized()
	var vel_local = car_basis.inverse() * coche.linear_velocity
	var speed_ms: float = -vel_local.z
	var speed_abs_kmh: float = absf(speed_ms) * 3.6
	var speed_fwd_kmh: float = maxf(0.0, speed_ms * 3.6)
	var speed_rev_kmh: float = maxf(0.0, -speed_ms * 3.6)

	if is_instance_valid(_humo_aceleracion) and _humo_aceleracion.has_method("actualizar"):
		_humo_aceleracion.actualizar(gas_suavizado, speed_abs_kmh, encendido, delta, false)

	# Modos de transmisión (0: P, 1: R, 2: N, 3: D)
	var en_drive: bool = (marcha_pedida == 3)
	var en_reversa: bool = (marcha_pedida == 1)
	var en_neutro: bool = not en_drive and not en_reversa

	if not en_drive:
		_current_gear = 0
		_shifting = false
		_shift_timer = 0.0
		_shift_target_gear = 0
		_time_in_gear = 0.0
	elif speed_fwd_kmh < 2.5 and _current_gear != 0 and not _shifting:
		_current_gear = 0
		_time_in_gear = 0.0

	_time_in_gear += delta

	if _shifting:
		_shift_timer -= delta
		var dur_cambio: float = maxf(tiempo_cambio, 0.001)
		var t_transcurrido: float = dur_cambio - _shift_timer
		var mitad_tiempo: float = dur_cambio * 0.5
		if t_transcurrido < mitad_tiempo:
			var t_norm: float = t_transcurrido / mitad_tiempo
			_factor_embrague = pow(1.0 - t_norm, 2.0)
		else:
			var t_norm: float = (t_transcurrido - mitad_tiempo) / mitad_tiempo
			_factor_embrague = sqrt(clampf(t_norm, 0.0, 1.0))

		if _shift_timer <= 0.0:
			_completar_cambio()
	else:
		_factor_embrague = move_toward(_factor_embrague, 1.0, delta * 4.5)

	# Evaluación de cambios automáticos usando exclusivamente la velocidad de avance real
	if en_drive and encendido and not _shifting:
		if gas_suavizado > 0.08:
			_evaluar_subir_marcha(speed_fwd_kmh)
		_evaluar_bajar_marcha(speed_fwd_kmh)

	# --- CÁLCULO DE FUERZA DE TRACCIÓN Y RETARDADOR ---
	fuerza_ruedas = 0.0
	freno_motor_activo = false
	auto_hold_activo = false

	# Auto-Hold inteligente solo en pendientes pronunciadas casi detenido; en llano o rodando por inercia
	# permite cambiar entre R y D manteniendo la dirección de marcha hasta pisar el acelerador.
	var inclinacion_abs := absf((-car_basis.z).dot(Vector3.UP))
	if auto_hold_pendiente and encendido and not en_neutro and not freno_mano and inclinacion_abs > 0.08:
		if en_drive and speed_ms < -0.15 and speed_ms > -0.85 and gas_suavizado < 0.15:
			auto_hold_activo = true
		elif en_reversa and speed_ms > 0.15 and speed_ms < 0.85 and gas_suavizado < 0.15:
			auto_hold_activo = true

	if encendido and not en_neutro and not freno_mano:
		var peso_rem: float = 0.0
		if coche.has_method("obtener_peso_remolque"):
			peso_rem = coche.obtener_peso_remolque()

		# Compensación progresiva por carga de remolque y pendiente
		var factor_carga: float = 1.0
		if peso_rem > 1000.0:
			var boost_marcha = lerpf(0.65, 0.18, float(_current_gear) / 9.0)
			factor_carga = 1.0 + clampf(peso_rem / 38000.0, 0.0, 1.6) * boost_marcha

		var dir_adelante = -car_basis.z
		var inclinacion_subida: float = clampf(dir_adelante.dot(Vector3.UP), 0.0, 0.45)
		var factor_pendiente: float = 1.0 + inclinacion_subida * 1.35

		var factor_par_rpm: float = _calcular_curva_par_diesel(rpm_motor)

		var acople_arranque: float = 1.0
		if speed_abs_kmh < 10.0:
			var t_arr = clampf(speed_abs_kmh / 10.0, 0.0, 1.0)
			acople_arranque = lerpf(acople_arranque_min, 1.0, t_arr)

		if pedal_raw > 0.02:
			if en_reversa:
				var mult_rev: float = 1.45
				var factor_vel_rev: float = clampf((22.0 - speed_rev_kmh) / 6.0, 0.0, 1.0) if speed_rev_kmh > 16.0 else 1.0
				fuerza_ruedas = -fuerza_aceleracion_pesado * mult_rev * gas_suavizado * factor_par_rpm * factor_carga * factor_vel_rev * acople_arranque
			elif en_drive:
				var mult_marcha: float = MULT_MARCHAS[_current_gear]
				var fuerza_base: float = fuerza_aceleracion_pesado * gas_suavizado * mult_marcha * factor_par_rpm * factor_carga * factor_pendiente

				if _current_gear == 9 and speed_fwd_kmh > velocidad_maxima_kmh - 8.0:
					var factor_tope = clampf((velocidad_maxima_kmh - speed_fwd_kmh) / 8.0, 0.0, 1.0)
					fuerza_base *= factor_tope

				fuerza_ruedas = fuerza_base * _factor_embrague * acople_arranque

		if motor_danado:
			var factor_potencia = clampf(1.0 - reduccion_potencia_dano, 0.15, 1.0)
			var fluctuacion_dano = 0.94 + sin(Time.get_ticks_msec() * 0.015) * 0.06
			fuerza_ruedas *= factor_potencia * fluctuacion_dano

	# Freno de Motor / Retarder (Jake Brake):
	# Se activa cuando el interruptor `freno_motor` (botón RETARDER o tecla B) está activo
	# y el conductor suelta el acelerador a más de 5 km/h.
	if encendido and not en_neutro and sw_freno_motor and gas_suavizado < 0.06 and speed_abs_kmh > 5.0:
		freno_motor_activo = true
		var mult_freno_ret = lerpf(1.40, 0.60, float(_current_gear) / 9.0)
		var ratio_rpm_jake = clampf((rpm_motor - rpm_idle) / maxf(rpm_limite_pesado - rpm_idle, 1.0), 0.20, 1.0)
		var factor_rpm_ret = lerpf(0.40, 1.15, pow(ratio_rpm_jake, 1.2))
		var mag_retarder = torque_retardador * factor_rpm_ret * mult_freno_ret
		fuerza_ruedas += -signf(speed_ms) * mag_retarder

	# --- SIMULACIÓN DE RPM DIÉSEL REALISTA ---
	var rpm_obj: float = 0.0
	if not encendido:
		rpm_obj = 0.0
		rpm_motor = move_toward(rpm_motor, 0.0, delta * 900.0)
	else:
		if en_neutro or freno_mano:
			rpm_obj = lerpf(rpm_idle, rpm_limite_pesado, gas_suavizado)
		elif _shifting:
			rpm_obj = lerpf(1150.0, 1380.0, gas_suavizado)
		elif en_reversa:
			var ratio_rev = clampf(speed_rev_kmh / 20.0, 0.0, 1.0)
			rpm_obj = lerpf(rpm_idle, 2000.0, ratio_rev) + (gas_suavizado * 180.0)
		else:
			var vel_min = 0.0 if _current_gear == 0 else VEL_BAJADA[_current_gear]
			var vel_max = VEL_SUBIDA[_current_gear] if _current_gear < 9 else velocidad_maxima_kmh
			var progreso = clampf((speed_fwd_kmh - vel_min) / maxf(vel_max - vel_min, 1.0), 0.0, 1.0)
			var rpm_base_marcha = rpm_idle if (_current_gear == 0 and speed_fwd_kmh < 2.0) else 1080.0
			var rpm_marcha = lerpf(rpm_base_marcha, 2050.0, progreso)
			rpm_obj = rpm_marcha + (gas_suavizado * 160.0)

		rpm_obj = clampf(rpm_obj, rpm_idle, rpm_limite_pesado)
		rpm_motor = lerpf(rpm_motor, rpm_obj, clampf(delta * 9.5, 0.0, 1.0))

	var rpm_norm = clampf((rpm_motor - rpm_idle) / maxf(rpm_limite_pesado - rpm_idle, 1.0), 0.0, 1.0) if encendido else 0.0

	if rpm_logic and rpm_logic.has_method("set_rpm"):
		rpm_logic.call("set_rpm", rpm_motor, delta)

	if is_instance_valid(sonidos_nodo):
		if sonidos_nodo.has_method("set_freno_motor"):
			sonidos_nodo.call("set_freno_motor", freno_motor_activo)
		if sonidos_nodo.has_method("set_freno_servicio"):
			sonidos_nodo.call("set_freno_servicio", freno_raw > 0.08 and absf(speed_fwd_kmh) > 1.5, freno_raw)
		if sonidos_nodo.has_method("activar_reversa"):
			sonidos_nodo.call("activar_reversa", en_reversa)
		if sonidos_nodo.has_method("procesar_audio"):
			sonidos_nodo.call("procesar_audio", rpm_norm, gas_suavizado, delta)

func _evaluar_subir_marcha(speed_fwd_kmh: float) -> void:
	if _current_gear >= 9 or _time_in_gear < 1.15:
		return

	var vel_requerida = VEL_SUBIDA[_current_gear]
	var factor_carga_umbral = 1.0
	if coche and coche.has_method("obtener_peso_remolque") and coche.obtener_peso_remolque() > 8000.0:
		factor_carga_umbral = 1.04

	if speed_fwd_kmh >= vel_requerida * factor_carga_umbral or (rpm_motor >= 2080.0 and speed_fwd_kmh >= vel_requerida * 0.88):
		_iniciar_cambio(_current_gear + 1)

func _evaluar_bajar_marcha(speed_fwd_kmh: float) -> void:
	if _current_gear <= 0 or _time_in_gear < 1.15:
		return

	var vel_rebaje = VEL_BAJADA[_current_gear]
	if speed_fwd_kmh < vel_rebaje:
		_iniciar_cambio(_current_gear - 1)
		return

	if gas_suavizado > 0.75 and _time_in_gear > 0.9:
		var vel_max_marcha_inferior = VEL_SUBIDA[_current_gear - 1]
		if speed_fwd_kmh < vel_max_marcha_inferior * 0.92 and rpm_motor < 1500.0:
			_iniciar_cambio(_current_gear - 1)
			return

func _iniciar_cambio(nueva_marcha: int) -> void:
	_shift_target_gear = nueva_marcha
	_shifting = true
	_shift_timer = tiempo_cambio
	_time_in_gear = 0.0

	if is_instance_valid(sonidos_nodo):
		if sonidos_nodo.has_method("set_shifting"):
			sonidos_nodo.call("set_shifting", true)
		if sonidos_nodo.has_method("set_recovering"):
			sonidos_nodo.call("set_recovering", false)

func _completar_cambio() -> void:
	_shifting = false
	_shift_timer = 0.0
	_current_gear = _shift_target_gear

	var rpm_norm = clampf((rpm_motor - rpm_idle) / maxf(rpm_limite_pesado - rpm_idle, 1.0), 0.0, 1.0)

	if is_instance_valid(sonidos_nodo):
		if sonidos_nodo.has_method("set_shifting"):
			sonidos_nodo.call("set_shifting", false)
		if sonidos_nodo.has_method("set_recovering"):
			sonidos_nodo.call("set_recovering", true)
			if get_tree():
				get_tree().create_timer(0.35).timeout.connect(func():
					if is_instance_valid(sonidos_nodo) and sonidos_nodo.has_method("set_recovering"):
						sonidos_nodo.call("set_recovering", false)
				)
		if sonidos_nodo.has_method("reproducir_cambio"):
			sonidos_nodo.call("reproducir_cambio", _current_gear, 10, gas_suavizado, rpm_norm)

	if is_instance_valid(_humo_aceleracion) and _humo_aceleracion.has_method("disparar_bocanada"):
		_humo_aceleracion.disparar_bocanada(0.7)

func danar_motor() -> void:
	motor_danado = true

func reparar_motor() -> void:
	motor_danado = false
	tipo_falla = ""
	temperatura_motor = 85.0

func provocar_falla(tipo: String = "mecanica") -> void:
	motor_danado = true
	tipo_falla = tipo

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache
