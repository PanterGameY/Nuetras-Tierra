extends Node
class_name HealthComponent

signal salud_actualizada(nueva_salud)

@export var salud_maxima: int = 100
@onready var salud_actual: int = salud_maxima

func recibir_daño(cantidad: int):
	salud_actual -= cantidad
	salud_actual = clamp(salud_actual, 0, salud_maxima)
	
	# Emitimos la señal para que el Player la escuche
	salud_actualizada.emit(salud_actual)
	
	print("Componente: Recibido ", cantidad, " de daño. Salud: ", salud_actual)
	
	if salud_actual <= 0:
		morir()

func morir():
	print("Jugador muerto")
	get_tree().reload_current_scene()
