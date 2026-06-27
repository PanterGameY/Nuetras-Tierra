@tool
extends Resource
class_name MotorConfig

## MotorConfig — Sistema simple de motor y transmisión.
## Cada marcha tiene una duración (segundos) y una velocidad objetivo (km/h).

@export_group("Motor")
## Fuerza base del motor. Aumentar para más aceleración.
@export var fuerza_motor: float = 8000.0
## RPM en ralentí.
@export var rpm_minimas: float = 600.0
## RPM máximas.
@export var rpm_maximas: float = 2200.0
## Fuerza del freno motor (0-1).
@export var freno_motor_fuerza: float = 0.35

@export_group("Marchas")
## Duración de cada marcha en segundos [1ª, 2ª, 3ª, ...]
@export var duracion_marchas: Array[float] = [2.0, 2.0, 2.0, 2.0, 2.5, 2.5, 3.0]
## Velocidad objetivo de cada marcha en km/h [1ª, 2ª, 3ª, ...]
@export var velocidad_marchas: Array[float] = [20.0, 35.0, 50.0, 65.0, 80.0, 100.0, 120.0]
## Velocidad máxima del vehículo (km/h).
@export var velocidad_maxima_kmh: float = 120.0
## Fuerza en reversa.
@export var fuerza_reversa: float = 4000.0
## Velocidad máxima en reversa (km/h).
@export var velocidad_max_reversa: float = 15.0

@export_group("Cambio")
## Tiempo que dura el cambio de marcha (segundos).
@export var tiempo_cambio: float = 0.5
## Fuerza durante el cambio (0-1, 0 = sin fuerza, 1 = fuerza completa).
@export var fuerza_durante_cambio: float = 0.3

@export_group("Remolque")
## Multiplicador de fuerza cuando hay remolque enganchado.
@export var fuerza_remolque_mult: float = 1.5


func get_factor_par(rpm: float) -> float:
	if rpm < rpm_minimas:
		return 0.8
	if rpm > rpm_maximas:
		return 0.0
	return 1.0
