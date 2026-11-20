extends TextureRect

## Emitida cada vez que rotacion_actual cambia (señal síncrona → latencia cero).
signal rotacion_cambiada(valor: float)

@export_group("Configuración Visual")
@export var sensibilidad: float = 0.72
@export var velocidad_retorno: float = 4.0
@export var vueltas_totales: float = 1.5
@export var retorno_automatico: bool = true
@export var zona_muerta_centro: float = 24.0

@export_group("Opacidad Dinámica")
@export_range(0.0, 1.0) var opacidad_reposo: float = 0.82
@export_range(0.0, 1.0) var opacidad_activa: float = 1.0
@export var velocidad_fade: float = 10.0

var _btn_encender: Control = null
var _iv_cache: Node = null
var _actualizando_desde_iv: bool = false

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

var _rotacion_actual: float = 0.0
var rotacion_actual: float = 0.0:
	set(v):
		_rotacion_actual = clampf(v, -1.0, 1.0)
		emit_signal("rotacion_cambiada", _rotacion_actual)
		_actualizar_visual_y_fisica()
	get:
		return _rotacion_actual

var tocando: bool = false
var angulo_anterior: float = 0.0
var dedo_activo: int = -1
var ya_vibro: bool = false

func _ready() -> void:
	# Permitir que el volante capture los eventos táctiles directamente
	mouse_filter = Control.MOUSE_FILTER_STOP
	self_modulate.a = opacidad_reposo
	await get_tree().process_frame
	var canvas = _get_canvas_layer()
	if canvas:
		_btn_encender = canvas.find_child("BtnEncender", true, false) as Control

func _get_canvas_layer() -> CanvasLayer:
	var n = get_parent()
	while n:
		if n is CanvasLayer:
			return n as CanvasLayer
		n = n.get_parent()
	return null

func _a_local(pos_global: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * pos_global

func _usar_solo_screen_touch(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false):
		return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if tocando:
			_soltar_volante()
		return

	# ─── PANTALLA TÁCTIL (Móvil y Emulación Touch en PC) ───
	if event is InputEventScreenTouch:
		if event.pressed:
			if dedo_activo == -1:
				# Excluir botón de bocina si se pulsa en el centro
				var boton_bocina = get_node_or_null("Bocina") as Control
				if boton_bocina and boton_bocina.is_visible_in_tree():
					if boton_bocina.get_global_rect().has_point(event.position):
						return

				# Excluir botón de encender si estuviera visible
				if _btn_encender and _btn_encender.is_visible_in_tree():
					if _btn_encender.get_global_rect().has_point(event.position):
						return

				var pos_local: Vector2 = _a_local(event.position)
				if _zona_valida(pos_local):
					dedo_activo = event.index
					tocando = true
					angulo_anterior = _obtener_angulo(pos_local)
					var iv = _get_iv()
					if is_instance_valid(iv) and iv.has_method("set_direccion_tactil"):
						iv.set_direccion_tactil(rotacion_actual)
					get_viewport().set_input_as_handled()
		else:
			if event.index == dedo_activo:
				_soltar_volante()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if event.index == dedo_activo and tocando:
			var pos_local: Vector2 = _a_local(event.position)
			_procesar_giro_circular(pos_local)
			get_viewport().set_input_as_handled()

	# ─── RATÓN (Fallback exclusivo cuando emulate_touch_from_mouse está desactivado) ───
	elif event is InputEventMouseButton:
		if _usar_solo_screen_touch(event):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if dedo_activo == -1:
					var boton_bocina = get_node_or_null("Bocina") as Control
					if boton_bocina and boton_bocina.is_visible_in_tree():
						if boton_bocina.get_global_rect().has_point(event.position):
							return
					var pos_local: Vector2 = _a_local(event.position)
					if _zona_valida(pos_local):
						dedo_activo = -2
						tocando = true
						angulo_anterior = _obtener_angulo(pos_local)
						var iv = _get_iv()
						if is_instance_valid(iv) and iv.has_method("set_direccion_tactil"):
							iv.set_direccion_tactil(rotacion_actual)
						get_viewport().set_input_as_handled()
			else:
				if dedo_activo == -2:
					_soltar_volante()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _usar_solo_screen_touch(event):
			return
		if dedo_activo == -2 and tocando:
			var pos_local: Vector2 = _a_local(event.position)
			_procesar_giro_circular(pos_local)
			get_viewport().set_input_as_handled()

func _procesar_giro_circular(pos_local: Vector2) -> void:
	var centro = size / 2.0
	var dist = pos_local.distance_to(centro)
	# Ignorar jitter microscópico exactamente en el punto cero
	if dist < 6.0:
		return

	var angulo_nuevo = _obtener_angulo(pos_local)
	var delta_rad = wrapf(angulo_nuevo - angulo_anterior, -PI, PI)

	# Relación de giro circular proporcional al arco recorrido:
	# Un giro angular completo de 2*PI en radianes equivale a (1.0 / vueltas_totales) de giro.
	# La sensibilidad escala la rapidez con que responde la mano al trazo circular.
	var cambio = (delta_rad / (PI * vueltas_totales)) * sensibilidad
	rotacion_actual = clampf(rotacion_actual + cambio, -1.0, 1.0)
	angulo_anterior = angulo_nuevo

func _soltar_volante() -> void:
	tocando = false
	dedo_activo = -1
	var iv = _get_iv()
	if is_instance_valid(iv) and iv.has_method("liberar_direccion_tactil"):
		iv.liberar_direccion_tactil()

func _zona_valida(local_pos: Vector2) -> bool:
	var centro = size / 2.0
	var dist = local_pos.distance_to(centro)
	# Permitir interacción en todo el disco del volante con margen cómodo para pulgar móvil
	var radio_max = max(size.x, size.y) * 0.60
	return dist > zona_muerta_centro and dist <= radio_max

func _obtener_angulo(pos: Vector2) -> float:
	return (pos - (size / 2.0)).angle()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if tocando:
			_soltar_volante()
		return

	var iv = _get_iv()
	if tocando and is_instance_valid(iv):
		if iv.has_method("set_direccion_tactil"):
			iv.set_direccion_tactil(rotacion_actual)
		else:
			iv.set_direccion(rotacion_actual)
	elif not tocando:
		var dir_teclado: float = Input.get_axis("izquierda", "derecha")
		if absf(dir_teclado) > 0.02 and is_instance_valid(iv):
			_actualizando_desde_iv = true
			rotacion_actual = float(iv.get("direccion"))
			_actualizando_desde_iv = false
		elif retorno_automatico and absf(rotacion_actual) > 0.001:
			rotacion_actual = move_toward(rotacion_actual, 0.0, velocidad_retorno * delta)
			if is_instance_valid(iv):
				iv.set_direccion(rotacion_actual)

	var target_alpha = opacidad_activa if tocando else opacidad_reposo
	self_modulate.a = lerpf(self_modulate.a, target_alpha, delta * velocidad_fade)

func _actualizar_visual_y_fisica() -> void:
	if material is ShaderMaterial:
		var rotacion_shader = rotacion_actual * PI * vueltas_totales
		material.set_shader_parameter("rotacion", rotacion_shader)

	if not _actualizando_desde_iv:
		var iv = _get_iv()
		if is_instance_valid(iv):
			if tocando and iv.has_method("set_direccion_tactil"):
				iv.set_direccion_tactil(rotacion_actual)
			elif tocando:
				iv.set_direccion(rotacion_actual)

	if absf(rotacion_actual) >= 0.99:
		if not ya_vibro:
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(25)
			ya_vibro = true
	else:
		ya_vibro = false

func centrar_volante() -> void:
	_soltar_volante()
	var dur: float = 0.35
	var t = create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotacion_actual", 0.0, dur)
	var iv = _get_iv()
	if is_instance_valid(iv) and iv.has_method("centrar_direccion"):
		iv.centrar_direccion()