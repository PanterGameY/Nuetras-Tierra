# rpm_config.gd
extends Resource
class_name RPMConfig

@export_group("RPM")
@export var rpm_idle: float = 600.0         # RPM en reposo (debe coincidir con rpm_minimas en motor)
@export var rpm_maximas: float = 3200.0     # RPM máximo (debe coincidir con rpm_maximas en motor)
@export var inercia_motor: float = 0.8      # Tiempo de suavizado de RPM en segundos

@export_group("Audio")
@export var pitch_min: float = 0.5           # Pitch mínimo del sonido
@export var pitch_max: float = 2.0           # Pitch máximo del sonido
@export var suavizado_subida: float = 12.0   # Velocidad de subida de pitch
@export var suavizado_bajada: float = 5.0    # Velocidad de bajada de pitch
