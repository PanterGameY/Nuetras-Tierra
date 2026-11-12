# rpm_config.gd
extends Resource
class_name RPMConfig

@export_group("RPM")
@export var rpm_idle: float = 650.0
@export var rpm_maximas: float = 2200.0
@export var inercia_motor: float = 0.15

@export_group("Audio")
@export var pitch_min: float = 0.78
@export var pitch_max: float = 1.38
@export var suavizado_subida: float = 16.0
@export var suavizado_bajada: float = 12.0
