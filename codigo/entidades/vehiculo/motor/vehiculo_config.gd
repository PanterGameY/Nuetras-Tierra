# VehiculoConfig.gd - Recurso de configuración técnica de vehículos
class_name VehiculoConfig
extends Resource

@export var nombre: String = ""
@export var masa_kg: float = 1500.0
@export var centro_de_masa: Vector3 = Vector3.ZERO
@export var coef_arrastre: float = 0.35
@export var area_frontal_m2: float = 2.6
@export var torque_antiroll: float = 25000.0
@export var amort_antiroll: float = 6000.0
@export var fuerza_enderezado: float = 80000.0
@export var amort_enderezado: float = 10000.0
@export var umbral_enderezado: float = 0.85
@export var pitch_intensidad: float = 15.0
@export var pitch_amort: float = 12000.0
@export var pitch_suavizado: float = 5.0
@export var pitch_acel_max: float = 8.0
@export var fuerza_freno_mano: float = 12000.0
@export var bias_delantero: float = 0.65
@export var bias_trasero: float = 0.35
@export var vel_umbral_parado: float = 0.15
@export var omega_umbral_parado: float = 0.05
@export var angulo_max_giro: float = 0.55
@export var wheelbase: float = 2.67
@export var track_width: float = 1.57
@export var suavizado_volante: float = 4.0
@export var suavizado_movil: float = 12.0
@export var motor_config: Resource = null
