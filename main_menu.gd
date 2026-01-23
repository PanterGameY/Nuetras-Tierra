extends Control

@onready var settings_panel = $"../Configuraciones"
@onready var main_buttons = $"../VBoxContainer"

func _ready():
	# Aseguramos que el ratón sea visible en el menú
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_panel.visible = false

# --- Botones Principales ---

func _on_btn_iniciar_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

func _on_btn_config_pressed():
	main_buttons.visible = false
	settings_panel.visible = true

func _on_btn_salir_pressed():
	get_tree().quit()

# --- Panel de Configuración ---

func _on_btn_back_pressed():
	settings_panel.visible = false
	main_buttons.visible = true

func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))


func _on_btn_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
