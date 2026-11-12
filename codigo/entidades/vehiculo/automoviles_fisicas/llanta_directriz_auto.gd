# llanta_directriz_auto.gd - Rueda delantera directriz independiente y estable para automóviles
extends RayCast3D

@export_group("Suspensión Turismo")
@export var largo_reposo: float = 0.28
@export var radio_rueda: float = 0.38
@export var rigidez_muelle: float = 26000.0
@export var amortiguacion: float = 2200.0
@export var extra_largo_rayo: float = 0.18
@export var coeficiente_geometria: float = 0.05 # Anti-dive

@export_group("Neumático")
@export var agarre_longitudinal: float = 9.0
@export var agarre_lateral: float = 14.0
@export var grip_multiplier: float = 1.15
@export var resistencia_rodadura: float = 12.0
@export var respuesta_lateral: float = 550.0
@export var respuesta_longitudinal_reposo: float = 1200.0
@export var umbral_vel_reposo: float = 0.2

@export_group("Dirección")
@export var angulo_giro_max: float = 38.0
@export var velocidad_giro_volante: float = 140.0
@export var torque_asistencia_direccion: float = 8500.0
@export var es_inversion_giro: bool = false

var coche: RigidBody3D = null
var rueda_visual: Node3D = null

# Variables internas de física y sonido
var compresion_anterior: float = 0.0
var velocidad_suspension: float = 0.0
var fuerza_normal_anterior: float = 0.0
var _resultant_force: Vector3 = Vector3.ZERO
var aceleracion_longitudinal_coche: float = 0.0
var _angulo_actual: float = 0.0

# Variables visuales
var vel_rodado_visual: float = 0.0
var angulo_rodado_visual: float = 0.0
var rotacion_visual_base: Quaternion = Quaternion.IDENTITY
var _primer_frame: bool = true

# API de compatibilidad
var es_tractriz: bool = true
var es_directriz: bool = true
var es_freno_mano: bool = false
var angulo_direccion: float = 0.0

func _ready() -> void:
	var p = get_parent()
	while p and not p is RigidBody3D:
		p = p.get_parent()
	coche = p as RigidBody3D
	
	if coche:
		add_exception(coche)
	
	enabled = true
	target_position = Vector3(0.0, -(largo_reposo + radio_rueda + extra_largo_rayo), 0.0)
	
	# Forzar detección en el primer frame de carga
	force_raycast_update()

	if get_child_count() > 0:
		rueda_visual = get_child(0)
		rotacion_visual_base = rueda_visual.quaternion

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not coche:
		if rueda_visual:
			rueda_visual.position = Vector3.DOWN * largo_reposo
		return

	force_raycast_update()

	# Obtener ángulo del volante Ackermann (Invertido para alinear física y visual de la Duster)
	var iv = get_node_or_null("/root/InputVehiculo")
	var dir_sign = 1.0 if es_inversion_giro else -1.0
	var steer_input = iv.get("direccion") * dir_sign if iv and coche.activo else 0.0
	
	var angulo_obj = steer_input * deg_to_rad(angulo_giro_max)
	_angulo_actual = move_toward(_angulo_actual, angulo_obj, delta * deg_to_rad(velocidad_giro_volante))
	angulo_direccion = _angulo_actual

	if is_colliding():
		var col_point = get_collision_point()
		var col_normal = get_collision_normal()
		var profundidad = global_position.distance_to(col_point)
		
		# Cálculo de velocidad de suspensión proyectando la velocidad del chasis sobre la normal
		var compresion = clampf((largo_reposo + radio_rueda) - profundidad, 0.0, largo_reposo + radio_rueda)
		compresion_anterior = compresion

		var radio_vec = col_point - coche.global_position
		var v_punto = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
		var vel_vertical = col_normal.dot(v_punto)

		var factor_peso = maxf(coche.mass / 1400.0, 1.0)
		var f_muelle = compresion * (rigidez_muelle * factor_peso)
		var f_amort = -vel_vertical * (amortiguacion * factor_peso)
		var f_susp_base = f_muelle + f_amort
		
		# Anti-geometría
		var car_basis = coche.global_transform.basis.orthonormalized()
		var vel_local = car_basis.inverse() * coche.linear_velocity
		var accel_coche = (vel_local.z - aceleracion_longitudinal_coche) / delta if delta > 0.0 else 0.0
		aceleracion_longitudinal_coche = vel_local.z
		
		var f_anti_geom = -accel_coche * coche.mass * coeficiente_geometria
		var f_normal_total = clampf(f_susp_base + f_anti_geom, 0.0, 50000.0)
		fuerza_normal_anterior = f_normal_total

		# Aplicar fuerzas físicas en el punto de contacto
		_aplicar_fuerzas_contacto(col_point, col_normal, f_normal_total, delta)
		
		if rueda_visual:
			rueda_visual.position.y = -profundidad + radio_rueda
	else:
		compresion_anterior = 0.0
		aceleracion_longitudinal_coche = 0.0
		if rueda_visual:
			rueda_visual.position.y = -largo_reposo

	_actualizar_visual(delta)

func _aplicar_fuerzas_contacto(col_point: Vector3, col_normal: Vector3, f_normal: float, delta: float) -> void:
	var radio_vec = col_point - coche.global_position
	var v_rueda = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
	var car_basis = coche.global_transform.basis.orthonormalized()
	
	# Direcciones de la rueda directriz rotadas en el eje Y del chasis
	var dir_adelante = -car_basis.z.normalized()
	var dir_lateral = car_basis.x.normalized()
	var dir_up_rueda = car_basis.y.normalized()
	
	dir_adelante = dir_adelante.rotated(dir_up_rueda, _angulo_actual).normalized()
	dir_lateral = dir_lateral.rotated(dir_up_rueda, _angulo_actual).normalized()
	
	# Proyectar paralelo al suelo
	var dir_lateral_suelo = dir_adelante.cross(col_normal).normalized()
	dir_adelante = col_normal.cross(dir_lateral_suelo).normalized()
	dir_lateral = dir_lateral_suelo
	
	var vel_forward = v_rueda.dot(dir_adelante)
	var vel_lateral = v_rueda.dot(dir_lateral)

	var fuerza_total_rueda = col_normal * f_normal
	
	# 1. TRACCIÓN LONGITUDINAL (Cálculo T800 FWD/AWD)
	var par_motor = 0.0
	var motor = coche.get_node_or_null("Motor")
	if coche.activo and motor:
		var marcha_ok = true
		var iv = get_node_or_null("/root/InputVehiculo")
		if iv:
			var m = iv.get("marcha_actual")
			if m == iv.get("Marcha").NEUTRO or m == iv.get("Marcha").PARQUEO:
				marcha_ok = false
		if marcha_ok:
			par_motor = motor.get("fuerza_ruedas") if motor.get("fuerza_ruedas") != null else 0.0
			
	var fuerza_traccion = 0.0
	if absf(par_motor) > 0.1:
		var f_teorica = par_motor / maxf(radio_rueda, 0.05)
		var limite_tracc = agarre_longitudinal * grip_multiplier * f_normal
		fuerza_traccion = clampf(f_teorica, -limite_tracc, limite_tracc)

	# Freno
	var freno_total = 0.0
	if coche.activo:
		var iv = get_node_or_null("/root/InputVehiculo")
		if iv:
			freno_total = iv.get("freno") * 3500.0
	else:
		freno_total = 8000.0

	if freno_total > 0.1 and absf(vel_forward) > 0.1:
		var limite_freno = agarre_longitudinal * grip_multiplier * f_normal * 1.5
		var f_aplic = minf(freno_total, limite_freno)
		fuerza_traccion -= signf(vel_forward) * f_aplic

	# Resistencia rodadura
	if absf(vel_forward) > 0.02:
		var f_rod = -signf(vel_forward) * minf(absf(vel_forward) * resistencia_rodadura, agarre_longitudinal * grip_multiplier * f_normal)
		fuerza_traccion += f_rod

	# Fricción reposo longitudinal
	var sin_gas = absf(par_motor) < 0.1 and freno_total < 0.1
	if sin_gas and absf(vel_forward) < umbral_vel_reposo:
		var f_rep_long = clampf(-vel_forward * respuesta_longitudinal_reposo, -agarre_longitudinal * grip_multiplier * f_normal, agarre_longitudinal * grip_multiplier * f_normal)
		fuerza_traccion += f_rep_long

	fuerza_total_rueda += dir_adelante * fuerza_traccion

	# 2. FRICCIÓN LATERAL (Cálculo T800 con reducción dinámica de agarre por frenado)
	var fn_lateral = maxf(f_normal, 1200.0)
	var agarre_lat_efectivo = agarre_lateral
	
	# Si se aplica freno fuerte a velocidad, se reduce el agarre lateral para permitir el derrape
	if freno_total > 1500.0 and absf(vel_forward) > 5.0:
		agarre_lat_efectivo *= 0.35
		
	var fuerza_lateral = -vel_lateral * respuesta_lateral * (fn_lateral / 1000.0)
	var limite_lateral = fn_lateral * agarre_lat_efectivo * grip_multiplier
	fuerza_lateral = clampf(fuerza_lateral, -limite_lateral, limite_lateral)
	fuerza_total_rueda += dir_lateral * fuerza_lateral

	# 3. ASISTENCIA DE GIRO POR TORQUE (Cálculo T800)
	if absf(_angulo_actual) > 0.01 and absf(vel_forward) > 0.5:
		var factor_velocidad = minf(absf(vel_forward) / 10.0, 1.0)
		var torque_dir = _angulo_actual * torque_asistencia_direccion * factor_velocidad * (f_normal / 10000.0)
		# Invertimos el signo para que el torque gire el chasis a la derecha con input positivo
		coche.apply_torque(-dir_up_rueda * torque_dir)

	# Aplicar fuerza física al RigidBody
	coche.apply_force(fuerza_total_rueda, radio_vec)
	_resultant_force = fuerza_total_rueda

func _actualizar_visual(delta: float) -> void:
	if not rueda_visual:
		return
	
	# Rotación visual del neumático alineada con el volante
	var q_direccion: Quaternion = Quaternion(Vector3.UP, _angulo_actual)

	var vel_local = coche.global_transform.basis.inverse() * coche.linear_velocity
	var speed_ms = -vel_local.z
	vel_rodado_visual = lerp(vel_rodado_visual, speed_ms, clamp(delta * 6.0, 0.0, 1.0))
	
	# Sentido visual por lateral
	var factor_rot = -1.0 if position.x > 0.0 else 1.0
	angulo_rodado_visual += vel_rodado_visual * factor_rot * delta / max(radio_rueda, 0.05)
	angulo_rodado_visual = wrapf(angulo_rodado_visual, -PI, PI)
	
	var q_rodado: Quaternion = Quaternion(Vector3.RIGHT, angulo_rodado_visual)

	rueda_visual.quaternion = q_direccion * rotacion_visual_base * q_rodado

func get_resultant_force() -> Vector3:
	return _resultant_force
