extends Node3D

@export_group("Configuración")
@export var config: MotorConfig = preload("res://Scripts/vehiculos/motor/recursos/Camion_Pesado.tres")
@export_group("Asistencias")
@export var auto_hold_habilitado: bool = true
@export var auto_hold_velocidad_ms: float = 0.55
@export var auto_hold_freno: float = 0.18
@export_group("Frenado Progresivo")
@export var freno_curva: float = 1.55 # >1 reduce la mordida inicial del pedal.
@export var rampa_subida_freno: float = 1.35 # Unidades/segundo al pisar.
@export var rampa_bajada_freno: float = 2.8  # Unidades/segundo al soltar.

@onready var coche: RigidBody3D = _get_rigidbody_parent(get_parent())
@onready var llantas_ctrl: Node3D = coche.get_node_or_null("ControladorLlantas")
@onready var rpm_logic: ControladorRPM = $ControladorRPM

var rpm_motor: float = 0.0
var freno_suavizado: float = 0.0

func _physics_process(delta: float) -> void:
	if not coche or not coche.activo or not config or not llantas_ctrl:
		return

	var gas: float = clamp(InputVehiculo.gas, 0.0, 1.0)
	var freno: float = clamp(InputVehiculo.freno, 0.0, 1.0)
	var freno_mano: bool = InputVehiculo.freno_mano

	# Motor apagado: solo permitimos freno y freno de mano, sin par de motor.
	if not InputVehiculo.motor_encendido:
		gas = 0.0
	
	# Si está en Parqueo o Neutro, no hay torque
	if InputVehiculo.marcha_actual == InputVehiculo.Marcha.PARQUEO or InputVehiculo.marcha_actual == InputVehiculo.Marcha.NEUTRO:
		gas = 0.0
		if InputVehiculo.marcha_actual == InputVehiculo.Marcha.PARQUEO:
			freno_mano = true

	var vel_local: Vector3 = coche.global_transform.basis.inverse() * coche.linear_velocity
	var speed_ms: float = -vel_local.z
	var speed_kmh: float = abs(speed_ms) * 3.6

	# Determinar dirección de movimiento basado en la marcha
	var direccion_movimiento: float = 1.0
	if InputVehiculo.esta_en_reversa():
		direccion_movimiento = -1.0
	elif InputVehiculo.esta_en_drive():
		direccion_movimiento = 1.0
	else:
		direccion_movimiento = 0.0

	# Usar relación de transmisión única simplificada
	var relacion_total: float = config.relacion_diferencial
	
	# Cálculo de RPM motor
	var rueda_rpm: float = 0.0
	if abs(speed_ms) > 0.1 and config.radio_rueda > 0.01:
		rueda_rpm = (abs(speed_ms) / config.radio_rueda) / TAU * 60.0

	var rpm_vel: float = rueda_rpm * relacion_total
	var rpm_pedal: float = lerp(config.rpm_minimas, config.rpm_maximas, gas)
	var rpm_obj: float = max(rpm_pedal, rpm_vel)
	if rpm_motor <= 0.0:
		rpm_motor = config.rpm_minimas
	
	# Limitar la aceleración de RPM para subida gradual
	var delta_rpm_max: float = config.aceleracion_rpm_max * delta
	var rpm_target: float = rpm_motor + clamp(rpm_obj - rpm_motor, -delta_rpm_max, delta_rpm_max)
	
	# Interpolación suave con inercia del motor
	rpm_motor = lerp(rpm_motor, rpm_target, delta / max(config.inercia_motor, 0.05))

	# Par de motor según curva diésel
	var factor_par: float = config.get_factor_par(rpm_motor)
	var par_motor: float = config.par_maximo * factor_par * gas * direccion_movimiento
	
	# DEBUG: Imprimir valores importantes
	if gas > 0.1 and Engine.get_frames_drawn() % 60 == 0:  # Cada 60 frames
		print("Motor - Gas: %.2f, Dir: %.1f, RPM: %.0f, Par: %.0f, Marcha: %s" % [gas, direccion_movimiento, rpm_motor, par_motor, InputVehiculo.marcha])

	# Convertir a torque en ruedas
	var torque_ruedas: float = par_motor * relacion_total * config.eficiencia_transmision
	
	# DEBUG: Ver torque en ruedas
	if gas > 0.1 and Engine.get_frames_drawn() % 60 == 0:
		print("Torque ruedas: %.0f N·m, Velocidad: %.1f km/h" % [torque_ruedas, speed_kmh])

	# Limitador de velocidad muy suave
	if speed_kmh > config.velocidad_maxima_kmh:
		torque_ruedas *= 0.3

	# Enviar a llantas
	llantas_ctrl.recibir_par_motor(torque_ruedas if not freno_mano else 0.0)

	# Frenado progresivo: menos brusco al inicio y con rampa de entrada/salida.
	var freno_objetivo: float = 1.0 if freno_mano else pow(clamp(freno, 0.0, 1.0), freno_curva)
	var velocidad_rampa := rampa_subida_freno if freno_objetivo > freno_suavizado else rampa_bajada_freno
	freno_suavizado = move_toward(freno_suavizado, freno_objetivo, velocidad_rampa * delta)
	
	var presion_freno: float = freno_suavizado
	if auto_hold_habilitado and not freno_mano and gas < 0.03 and abs(speed_ms) < auto_hold_velocidad_ms:
		presion_freno = max(presion_freno, auto_hold_freno)
	llantas_ctrl.aplicar_freno(presion_freno)

	# RPM a HUD/sonido
	if rpm_logic:
		rpm_logic.set_rpm(rpm_motor, delta)

func _get_rigidbody_parent(n: Node) -> RigidBody3D:
	if n == null or n is RigidBody3D:
		return n
	return _get_rigidbody_parent(n.get_parent())
