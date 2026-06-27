extends Resource
class_name VehiculoConfig

# ═══════════════════════════════════════════════════════════════════════
# VehiculoConfig — Configuración centralizada de un vehículo.
# Un recurso .tres por vehículo. Asignar en coche.gd y listo.
# Las ruedas se configuran individualmente en el Inspector (llanta.gd).
# ═══════════════════════════════════════════════════════════════════════

@export_group("Identidad")
@export var nombre: String = "Vehículo"

@export_group("Chasis")
@export var masa_kg: float = 1400.0
@export var centro_de_masa: Vector3 = Vector3(0.0, -0.35, 0.0)
@export var coef_arrastre: float = 0.40
@export var area_frontal_m2: float = 2.6

@export_group("Estabilidad")
@export var torque_antiroll: float = 25000.0
@export var amort_antiroll: float = 6000.0
@export var fuerza_enderezado: float = 80000.0
@export var amort_enderezado: float = 10000.0
@export var umbral_enderezado: float = 0.85

@export_group("Cabeceo")
@export var pitch_intensidad: float = 15.0
@export var pitch_amort: float = 12000.0
@export var pitch_suavizado: float = 5.0
@export var pitch_acel_max: float = 8.0
@export var cambio_impulso: float = 12.0
@export var cambio_decaimiento: float = 4.0

@export_group("Frenado")
@export var fuerza_freno_mano: float = 12000.0
@export var bias_delantero: float = 0.65
@export var bias_trasero: float = 0.35
@export var vel_umbral_parado: float = 0.15
@export var omega_umbral_parado: float = 0.05

@export_group("Dirección")
@export var angulo_max_giro: float = 0.55
@export var wheelbase: float = 2.5
@export var track_width: float = 1.6
@export var suavizado_volante: float = 4.0
@export var suavizado_movil: float = 12.0

@export_group("Motor y Transmisión")
@export var motor_config: MotorConfig
@export_group("Combustible")
@export var tipo_combustible: String = "diesel" # "gasolina" or "diesel"
@export var capacidad_combustible_l: float = 400.0
@export var nivel_combustible_l: float = 200.0