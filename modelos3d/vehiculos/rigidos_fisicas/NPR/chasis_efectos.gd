extends Node3D

@export_group("Física de Suspensión (Masa)")
@export var rigidez: float = 5.0      # Cuánta fuerza opone el chasis al inclinarse
@export var amortiguacion: float = 2.5 # Qué tan rápido deja de oscilar (evita que parezca gelatina)
@export var masa_chasis: float = 1.2   # Multiplicador de inercia

@export_group("Límites y Factores")
@export var factor_roll: float = 0.8   # Inclinación lateral en curvas
@export var factor_pitch: float = 0.5  # Inclinación al frenar/arrancar
@export var max_angulo: float = 4.5    # Un NPR no debería inclinarse más de esto
@export var factor_lateral: float = 0.8 # Factor aplicado a la fuerza centrífuga (giro)

@export_group("Vibración Diésel")
@export var vib_base: float = 0.002    # Vibración casi imperceptible en ralentí
@export var vib_gas: float = 0.008     # Aumenta al acelerar
@export var suavizado_motor: float = 5.0

@export_group("Debug")
@export var debug_show_gear_accel: bool = true

# Variables de estado físico
var _coche: RigidBody3D
var _motor: Node = null
var _vel_angular_chasis: Vector3 = Vector3.ZERO
var _rot_actual: Vector3 = Vector3.ZERO
var _prev_vel_lineal: Vector3 = Vector3.ZERO
var _vibe_fuerza: float = 0.0

func _ready() -> void:
	_coche = get_parent() as RigidBody3D
	# Intentar localizar automáticamente el nodo del motor (script motor.gd)
	if is_instance_valid(_coche):
		for c in _coche.get_children():
			if c and c.get_script() and typeof(c.get_script()) == TYPE_OBJECT:
				var sp = str(c.get_script())
				if sp.find("motor.gd") != -1:
					_motor = c
					break
	# El chasis visual no debe tener colisiones propias para no interferir
	top_level = false 

func _physics_process(delta: float) -> void:
	if not _coche or _coche.freeze or delta <= 0: return

	# 1. CALCULAR ACELERACIONES LOCALES (Fuerzas G)
	var inv_basis = _coche.global_transform.basis.inverse()
	var vel_local = inv_basis * _coche.linear_velocity
	
	# Aceleración = (VelActual - VelPrevia) / Tiempo
	var aceleracion = (vel_local - _prev_vel_lineal) / delta
	_prev_vel_lineal = vel_local

	# Debug: mostrar marcha y aceleración frontal (m/s^2)
	if debug_show_gear_accel:
		var _accel_forward: float = -aceleracion.z
		# Mostrar etiqueta legible si está disponible en InputVehiculo
		var _gear_label: String = "?"
		if is_instance_valid(InputVehiculo):
			if InputVehiculo.has_method("marcha"):
				_gear_label = str(InputVehiculo.marcha)
			else:
				_gear_label = str(InputVehiculo.marcha_actual)
		# Intentar leer la marcha interna del motor (índice de marcha automática)
		var _internal_gear: String = "?"
		if is_instance_valid(_motor):
			var g = _motor.get("_current_gear")
			if g != null:
				_internal_gear = str(g)
		# debug prints removed per user request

	# 2. CALCULAR OBJETIVOS (Hacia dónde quiere ir el chasis por la inercia)
	# Nota: Al acelerar adelante (Z negativo), el chasis se inclina atrás (Pitch positivo)
	var target_pitch = clamp(-aceleracion.z * factor_pitch, -max_angulo, max_angulo)

	# 1) Giro local del vehículo (eje Y) para calcular efecto centrífugo
	var vel_giro: float = (inv_basis * _coche.angular_velocity).y
	var forward_speed: float = -vel_local.z
	var a_centrip: float = vel_giro * forward_speed

	# 2) Convertir aceleraciones laterales a ángulos físicos (atan(a/g)) y combinar
	var roll_from_accel: float = rad_to_deg(atan((-aceleracion.x) / 9.81)) * factor_roll
	var roll_from_centrif: float = rad_to_deg(atan(a_centrip / 9.81)) * factor_lateral
	# Invertir signo para que el chasis se incline hacia el exterior de la curva
	var target_roll: float = clamp(-(roll_from_accel + roll_from_centrif), -max_angulo, max_angulo)
	# Reacción de torsión de cabina por alto par motor arrastrando carga pesada
	if _coche and "_torsion_par_suave" in _coche:
		var extra_twist = _coche.get("_torsion_par_suave") * 3.5
		target_roll = clamp(target_roll + extra_twist, -max_angulo * 1.6, max_angulo * 1.6)
	var target_pose = Vector3(target_pitch, 0, target_roll)

	# 3. SISTEMA DE MUELLE (Spring-Damper)
	# Esto hace que el chasis tenga "rebote" realista y peso
	var fuerza_muelle = (target_pose - _rot_actual) * rigidez
	var fuerza_amortiguacion = _vel_angular_chasis * amortiguacion
	
	var aceleracion_chasis = (fuerza_muelle - fuerza_amortiguacion) / masa_chasis
	_vel_angular_chasis += aceleracion_chasis * delta
	_rot_actual += _vel_angular_chasis * delta

	# 4. VIBRACIÓN DEL MOTOR DESACTIVADA (Para turismos suaves y NPR sin temblor molesto)
	_vibe_fuerza = 0.0
	var motor_offset = Vector3.ZERO

	# 5. APLICAR ROTACIÓN FINAL
	rotation_degrees = _rot_actual + motor_offset