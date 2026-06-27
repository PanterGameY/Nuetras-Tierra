extends ColorRect

@export var nombre_pedal: String = "acelerador"
@export var sensibilidad_retorno: float = 8.0
@export var sensibilidad_presion: float = 12.0

var presion_actual: float = 0.0
var presion_objetivo: float = 0.0
var _dedo_activo: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if material is ShaderMaterial:
		var mat := material as ShaderMaterial
		var es_freno: bool = nombre_pedal.to_lower().contains("freno")
		if es_freno:
			var tex := load("res://scenes/gui/UIVehiculo/imagenes/UIPrincipal/Freno.png")
			mat.set_shader_parameter("pedal_texture", tex)
			mat.set_shader_parameter("color_presion", Color(1.0, 0.15, 0.05, 1.0))
			mat.set_shader_parameter("presion_tinte", 0.45)
			mat.set_shader_parameter("presion_oscuridad", 0.35)
			mat.set_shader_parameter("presion_escala", 0.10)
		else:
			var tex := load("res://scenes/gui/UIVehiculo/imagenes/UIPrincipal/Acelerador.png")
			mat.set_shader_parameter("pedal_texture", tex)
			mat.set_shader_parameter("color_presion", Color(0.1, 0.9, 0.2, 1.0))
			mat.set_shader_parameter("presion_tinte", 0.40)
			mat.set_shader_parameter("presion_oscuridad", 0.20)
			mat.set_shader_parameter("presion_escala", 0.08)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _dedo_activo == -1:
				var local_pos = event.position - global_position
				if Rect2(Vector2.ZERO, size).has_point(local_pos):
					_dedo_activo = event.index
					_calcular_objetivo(local_pos)
					get_viewport().set_input_as_handled()
		else:
			if event.index == _dedo_activo:
				_dedo_activo = -1
				presion_objetivo = 0.0
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _dedo_activo:
			var local_pos = event.position - global_position
			_calcular_objetivo(local_pos)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _dedo_activo == -1:
					var local_pos = event.position - global_position
					if Rect2(Vector2.ZERO, size).has_point(local_pos):
						_dedo_activo = 0
						_calcular_objetivo(local_pos)
			else:
				if _dedo_activo == 0:
					_dedo_activo = -1
					presion_objetivo = 0.0
	elif event is InputEventMouseMotion:
		if _dedo_activo == 0:
			var local_pos = event.position - global_position
			_calcular_objetivo(local_pos)

func _calcular_objetivo(pos_local: Vector2) -> void:
	presion_objetivo = 1.0

func _process(delta: float) -> void:
	var tocando: bool = (_dedo_activo != -1)
	presion_actual = 1.0 if tocando else 0.0

	if material is ShaderMaterial:
		material.set_shader_parameter("intensidad_presion", presion_actual)

	if is_instance_valid(InputVehiculo):
		var valor: float = presion_actual
		if nombre_pedal.to_lower().contains("aceler"):
			InputVehiculo.set_gas(valor)
		elif nombre_pedal.to_lower().contains("freno"):
			InputVehiculo.set_freno(valor)

func reset_pedal():
	presion_actual = 0.0
	presion_objetivo = 0.0
	_dedo_activo = -1