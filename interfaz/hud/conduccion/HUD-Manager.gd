extends Control

@export var vehiculo_path: NodePath
var vehiculo: RigidBody3D

@onready var mat_velocimetro = $Velocimetro.material

func _ready():
	vehiculo = get_node(vehiculo_path)

func _process(_delta):
	if not vehiculo: return
	
	# 1. Calcular velocidad lineal
	var speed = vehiculo.linear_velocity.length()
	var speed_max = 30.0 # Ajusta según tu coche
	var speed_ratio = clamp(speed / speed_max, 0.0, 1.0)
	
	# 2. Enviar al Shader
	mat_velocimetro.set_shader_parameter("valor", speed_ratio)
	
	# 3. Efecto de "Glow" si va muy rápido
	if speed_ratio > 0.8:
		mat_velocimetro.set_shader_parameter("color_brillo", Color(1.0, 0.3, 0.2)) # Rojo alerta
	else:
		mat_velocimetro.set_shader_parameter("color_brillo", Color(0.85, 0.7, 0.4)) # Dorado normal
