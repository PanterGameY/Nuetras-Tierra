extends Button

func _ready() -> void:
	pressed.connect(_on_salir)

func _on_salir() -> void:
	# Abrir la ventana de configuraciones
	if ResourceLoader.exists("res://escenas/configuraciones/configuraciones.tscn"):
		get_tree().change_scene_to_file("res://escenas/configuraciones/configuraciones.tscn")
	else:
		print("salir.gd: escena de configuraciones no encontrada.")