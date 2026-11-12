# llanta_auto.gd - Heredero limpio de llanta.gd adaptado a turismos
extends "res://modelos3d/vehiculos/rigidos_fisicas/NPR/llanta.gd"

func _ready() -> void:
	# Ajustar muelle y amortiguación de camión pesado a turismo ligero
	rigidez_muelle = 26000.0   # Muelle suave y progresivo
	amortiguacion = 2200.0     # Amortiguación óptima
	fuerza_suspension_max = 45000.0
	
	# Ajustar el largo de la suspensión y el radio a la Duster
	largo_reposo = 0.28
	radio_rueda = 0.38
	extra_largo_rayo = 0.18
	
	# Parámetros de agarre de turismo
	agarre_lateral = 14.0
	agarre_longitudinal = 9.0
	resistencia_rodadura = 12.0

	# Llamar a la inicialización original de la llanta padre
	super._ready()

func _physics_process(delta: float) -> void:
	# El padre llanta.gd procesa toda la física de forma idéntica a la T800
	super._physics_process(delta)
