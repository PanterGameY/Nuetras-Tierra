extends Node3D



# Tipos de combustible posibles: "gasolina", "diesel", "electrico", etc.
@export var tipo_combustible: String = "diesel"
@export var combustible_max: float = 100.0
@export var combustible_actual: float = 100.0
# Consumo por segundo cuando el vehículo se mueve
@export var consumo_por_segundo: float = 2.0

# Variable para indicar si el vehículo está en movimiento
var en_movimiento: bool = false

func _ready() -> void:
	# Inicialización si es necesario
	combustible_actual = combustible_max


# Llamar a esto cada frame
func _process(delta: float) -> void:
	if en_movimiento and combustible_actual > 0.0:
		combustible_actual -= consumo_por_segundo * delta
		if combustible_actual < 0.0:
			combustible_actual = 0.0

# Método para recargar combustible
func recargar_cantidad(cantidad: float) -> void:
	combustible_actual += cantidad
	if combustible_actual > combustible_max:
		combustible_actual = combustible_max

# Método para establecer si el vehículo está en movimiento
func set_en_movimiento(moviendo: bool) -> void:
	en_movimiento = moviendo
