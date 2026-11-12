# controlador_llantas_auto.gd - Puente de compatibilidad API de luces y UI
extends Node3D

# --- Arrays de Compatibilidad Requeridos por Luces y Sonido ---
var llantas_todas: Array[RayCast3D] = []
var llantas_directrices: Array[RayCast3D] = []
var llantas_motrices: Array[RayCast3D] = []

var angulo_max_giro: float = 0.66
var wheelbase: float = 2.5

func _ready() -> void:
	# Búsqueda y enlace con el chasis padre del vehículo
	var coche = get_parent()
	if coche:
		await get_tree().process_frame
		if "llantas_todas" in coche:
			llantas_todas = coche.get("llantas_todas")
		if "llantas_directrices" in coche:
			llantas_directrices = coche.get("llantas_directrices")
		if "llantas_motrices" in coche:
			llantas_motrices = coche.get("llantas_motrices")

func set_fuerza_freno(freno: float) -> void:
	# Distribución de la fuerza de frenado a todas las ruedas
	for rueda in llantas_todas:
		if is_instance_valid(rueda):
			rueda.fuerza_freno = freno

func set_freno_mano(activo_fm: bool) -> void:
	# Distribución del freno de mano a todas las ruedas
	for rueda in llantas_todas:
		if is_instance_valid(rueda) and "fuerza_freno_mano" in rueda:
			rueda.fuerza_freno_mano = 8000.0 if activo_fm else 0.0
