#Este script controla el botón de agacharse en la interfaz de usuario. Cambia el estado del jugador y actualiza el shader para reflejar si el jugador está agachado o no.
extends ColorRect

var jugador: CharacterBody3D = null
var esta_agachado: bool = false
var _touch_index: int = -1

func _ready() -> void:
	if material:
		material.set_shader_parameter("agachado", 0.0)
		material.set_shader_parameter("tiempo_juego", 0.0)
	await get_tree().process_frame
	jugador = get_tree().get_first_node_in_group("jugador")

func _process(_delta: float) -> void:
	if material:
		material.set_shader_parameter("tiempo_juego", float(Time.get_ticks_msec()) / 1000.0)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().abs().has_point(event.position):
				var joystick = get_tree().get_first_node_in_group("joystick")
				if joystick and joystick._touch_index == event.index:
					return
				_touch_index = event.index
				esta_agachado = !esta_agachado
				if jugador:
					jugador.esta_agachado = esta_agachado
				if material:
					material.set_shader_parameter("agachado", 1.0 if esta_agachado else 0.0)
				get_viewport().set_input_as_handled()
		else:
			if event.index == _touch_index:
				_touch_index = -1
