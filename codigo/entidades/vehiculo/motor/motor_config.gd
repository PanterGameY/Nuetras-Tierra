# motor_config.gd — Recurso unificado de configuración de motor diésel y gasolina
extends Resource
class_name MotorConfig

@export_group("Motor Diésel / Gasolina")
@export var fuerza_motor: float = 24000.0
@export var par_maximo: float = 2800.0
@export var rpm_par_maximo: float = 1350.0
@export var rpm_minimas: float = 650.0
@export var rpm_maximas: float = 2200.0
@export var inercia_motor: float = 0.20
@export var aceleracion_rpm_max: float = 2000.0
@export var tiempo_cambio: float = 0.25
@export var fuerza_durante_cambio: float = 0.72
@export var fuerza_remolque_mult: float = 1.25
@export var freno_motor_fuerza: float = 0.35
@export var fuerza_reversa: float = 12000.0
@export var velocidad_max_reversa: float = 20.0

@export_group("Frenado")
@export var inercia_freno: float = 0.25

@export_group("Transmisión")
@export var relaciones_caja: Array[float] = [14.0, 10.0, 7.5, 5.8, 4.5, 3.2, 2.5, 1.8, 1.3, 1.0]
@export var duracion_marchas: Array[float] = [4.0, 4.0, 4.0, 4.0, 5.0, 5.0, 6.0]
@export var velocidad_marchas: Array[float] = [14.0, 25.0, 38.0, 52.0, 66.0, 80.0, 94.0, 108.0, 120.0, 128.0]
@export var relacion_diferencial: float = 3.8
@export var radio_rueda: float = 0.52
@export var eficiencia_transmision: float = 0.92
@export var velocidad_maxima_kmh: float = 125.0

@export_group("Cambio Automático")
@export var rpm_subir_marcha: float = 1950.0
@export var rpm_bajar_marcha: float = 1150.0

func get_factor_par(rpm: float) -> float:
	if rpm < rpm_minimas:
		return 0.65
	if rpm > rpm_maximas:
		return 0.0
	var t: float = (rpm - rpm_minimas) / maxf(rpm_maximas - rpm_minimas, 1.0)
	var pico_norm: float = (rpm_par_maximo - rpm_minimas) / maxf(rpm_maximas - rpm_minimas, 1.0)
	if t <= pico_norm:
		return lerpf(0.72, 1.0, pow(t / maxf(pico_norm, 0.01), 0.5))
	else:
		return lerpf(1.0, 0.68, (t - pico_norm) / maxf(1.0 - pico_norm, 0.01))
