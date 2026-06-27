extends RigidBody3D

@export var engine_power: float = 2500.0
@export var steering_angle: float = 0.5

var input_accel: float = 0.0
var input_steer: float = 0.0

@onready var ruedas = [$Suspension/RayFL, $Suspension/RayFR, $Suspension/RayRL, $Suspension/RayRR]

func _ready():
	add_to_group("vehiculo")
	# Ajuste de centro de masa para que el camión no se vuelque fácil
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.5, 0) 

func _process(delta: float):
	# Intentar obtener InputVehiculo (autoload o nodo en /root)
	var iv = null
	if has_node("/root/InputVehiculo"):
		iv = get_node("/root/InputVehiculo")
	elif Engine.has_singleton("InputVehiculo"):
		iv = InputVehiculo

	if iv and is_instance_valid(iv):
		# Usar valores procesados por InputVehiculo y respetar motor/marcha
		input_steer = iv.direccion
		input_accel = iv.gas if iv.puede_moverse() else 0.0
	else:
		# Fallback: entrada directa del teclado (útil en pruebas)
		input_accel = Input.get_axis("ui_down", "ui_up")
		input_steer = Input.get_axis("ui_right", "ui_left")

	# Le decimos a las ruedas delanteras cuánto girar
	var target_steer = input_steer * steering_angle
	for rueda in ruedas:
		if rueda.has_method("actualizar_giro"):
			rueda.actualizar_giro(target_steer)