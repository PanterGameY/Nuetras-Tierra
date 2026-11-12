# selector_marchas.gd
extends Node

var rpm_ref: ControladorRPM
var motor_ref: Node3D # Referencia al script motor.gd
var _marcha_visual_previa: String = ""
@export var debug_selector_marchas: bool = false

func _process(_delta: float) -> void:
	# 1. Buscar referencias si faltan
	if not rpm_ref:
		rpm_ref = get_parent().find_child("ControladorRPM", true, false)
	if not motor_ref:
		motor_ref = get_parent() # El padre ES el nodo Motor (motor.gd)
	
	if not rpm_ref or not motor_ref: return

	# 2. Determinar qué letra mostrar en la UI basándonos en el estado del motor
	var marcha_texto = "N"
	var vel_local = motor_ref.coche.linear_velocity.length()
	
	if is_instance_valid(InputVehiculo) and InputVehiculo.esta_en_reversa():
		marcha_texto = "R"
		rpm_ref.en_reversa = true
		rpm_ref.en_parqueo = false
	elif vel_local < 0.1 and InputVehiculo.gas < 0.1 and InputVehiculo.freno < 0.1:
		marcha_texto = "N"
		rpm_ref.en_reversa = false
		rpm_ref.en_parqueo = true
	else:
		marcha_texto = "D"
		rpm_ref.en_reversa = false
		rpm_ref.en_parqueo = false

	# 3. Actualizar Singleton y Sonido solo si cambió
	if marcha_texto != _marcha_visual_previa:
		_marcha_visual_previa = marcha_texto
		InputVehiculo.marcha = marcha_texto
		_reproducir_sonido_cambio()

func _reproducir_sonido_cambio() -> void:
	# Un pequeño cambio automático
	pass
