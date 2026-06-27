extends TextureRect

## Emitida cada vez que rotacion_actual cambia (señal síncrona → latencia cero).
signal rotacion_cambiada(valor: float)

@export_group("Configuración Visual")
@export var sensibilidad: float = 1.5
@export var velocidad_retorno: float = 4.0
@export var vueltas_totales: float = 1.5
@export var retorno_automatico: bool = true
@export var zona_muerta_centro: float = 48.0

@export_group("Opacidad Dinámica")
@export_range(0.0, 1.0) var opacidad_reposo: float = 0.4
@export_range(0.0, 1.0) var opacidad_activa: float = 0.9
@export var velocidad_fade: float = 10.0

var _btn_encender: Control = null
var _rotacion_actual: float = 0.0
var rotacion_actual: float = 0.0:
	set(v):
		_rotacion_actual = clamp(v, -1.0, 1.0)
		emit_signal("rotacion_cambiada", _rotacion_actual)
		_actualizar_visual_y_fisica()
	get:
		return _rotacion_actual

var tocando: bool = false
var angulo_anterior: float = 0.0
var dedo_activo: int = -1
var ya_vibro: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate.a = opacidad_reposo
	# Buscar BtnEncender para excluirlo de la captura de touch
	await get_tree().process_frame
	var canvas = _get_canvas_layer()
	if canvas:
		_btn_encender = canvas.get_node_or_null("BtnEncender") as Control

func _get_canvas_layer() -> CanvasLayer:
	var n = get_parent()
	while n:
		if n is CanvasLayer:
			return n as CanvasLayer
		n = n.get_parent()
	return null

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if dedo_activo == -1:
				# No capturar si el toque está sobre la bocina
				var boton_bocina = get_node_or_null("Bocina")
				if boton_bocina and boton_bocina is Control and boton_bocina.visible:
					if boton_bocina.get_global_rect().has_point(event.position):
						return
				# No capturar si el toque está sobre BtnEncender
				if _btn_encender and _btn_encender.is_visible_in_tree():
					if _btn_encender.get_global_rect().has_point(event.position):
						return
				# Iniciar seguimiento del toque
				var local_pos = event.position - global_position
				if _zona_valida(local_pos):
					dedo_activo = event.index
					tocando = true
					angulo_anterior = _obtener_angulo(local_pos)
					get_viewport().set_input_as_handled()
		else:
			if event.index == dedo_activo:
				tocando = false
				dedo_activo = -1
				if is_instance_valid(InputVehiculo) and InputVehiculo.has_method("liberar_direccion_tactil"):
					InputVehiculo.liberar_direccion_tactil()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if event.index == dedo_activo and tocando:
			var local_pos = event.position - global_position
			var angulo_nuevo = _obtener_angulo(local_pos)
			var delta = wrapf(angulo_nuevo - angulo_anterior, -PI, PI)
			var factor_sensibilidad = sensibilidad * 1.2
			var cambio = (delta / PI) * factor_sensibilidad
			rotacion_actual = clamp(rotacion_actual + cambio, -1.0, 1.0)
			angulo_anterior = angulo_nuevo
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if dedo_activo == -1:
					var local_pos = event.position - global_position
					if _zona_valida(local_pos):
						dedo_activo = 0
						tocando = true
						angulo_anterior = _obtener_angulo(local_pos)
			else:
				if dedo_activo == 0:
					tocando = false
					dedo_activo = -1
					if is_instance_valid(InputVehiculo) and InputVehiculo.has_method("liberar_direccion_tactil"):
						InputVehiculo.liberar_direccion_tactil()

	elif event is InputEventMouseMotion:
		if tocando and dedo_activo == 0:
			var local_pos = event.position - global_position
			var angulo_nuevo = _obtener_angulo(local_pos)
			var delta = wrapf(angulo_nuevo - angulo_anterior, -PI, PI)
			var cambio = (delta / PI) * sensibilidad * 1.2
			rotacion_actual = clamp(rotacion_actual + cambio, -1.0, 1.0)
			angulo_anterior = angulo_nuevo

func _zona_valida(local_pos: Vector2) -> bool:
	var centro = size / 2.0
	var dist = local_pos.distance_to(centro)
	var radio_max = min(size.x, size.y) * 0.5
	return dist > zona_muerta_centro and dist < radio_max

func _obtener_angulo(pos: Vector2) -> float:
	return (pos - size / 2.0).angle()

func _process(delta: float) -> void:
	if tocando and is_instance_valid(InputVehiculo):
		InputVehiculo.set_direccion(rotacion_actual)

	if retorno_automatico and not tocando and abs(rotacion_actual) > 0.001:
		rotacion_actual = move_toward(rotacion_actual, 0.0, velocidad_retorno * delta)

	var target_alpha = opacidad_activa if tocando else opacidad_reposo
	self_modulate.a = lerp(self_modulate.a, target_alpha, delta * velocidad_fade)

func _actualizar_visual_y_fisica():
	if material is ShaderMaterial:
		var rotacion_shader = rotacion_actual * PI * vueltas_totales
		material.set_shader_parameter("rotacion", rotacion_shader)

	if is_instance_valid(InputVehiculo):
		InputVehiculo.set_direccion(rotacion_actual)

	if abs(rotacion_actual) >= 0.99:
		if not ya_vibro:
			Input.vibrate_handheld(25)
			ya_vibro = true
	else:
		ya_vibro = false

func centrar_volante() -> void:
	tocando = false
	dedo_activo = -1
	var dur: float = 0.45
	var t = create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotacion_actual", 0.0, dur)