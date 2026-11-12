@tool
extends ColorRect

## Control de pedal progresivo de alta fidelidad para dispositivos móviles y PC.
## Soporta modulación analógica por altura de toque (deslizamiento vertical),
## curva de aceleración progresiva por tiempo y respuesta háptica al fondo.

@export var nombre_pedal: String = "freno"

@export_group("Prueba en Inspector / Debug")
## Arrastra este deslizador en el Inspector para probar el llenado visual, glow y shader en vivo
@export_range(0.0, 1.0, 0.01) var probar_presion: float = 0.0:
	set(val):
		probar_presion = val
		presion_actual = val
		presion_objetivo = val
		_actualizar_shader_visual()
		if not Engine.is_editor_hint():
			var iv = _get_iv()
			if is_instance_valid(iv):
				if nombre_pedal.to_lower().contains("aceler"):
					iv.set_gas(presion_actual)
				else:
					iv.set_freno(presion_actual)

@export_group("Comportamiento Progresivo")
## Velocidad con que la presión sube hacia el objetivo al presionar
@export var velocidad_presion: float = 5.0
## Velocidad de retorno elástico a 0 al soltar el pedal
@export var velocidad_retorno: float = 10.0
## Si es verdadero, tocar o deslizar verticalmente modula la presión (arriba = suave, abajo = a fondo)
@export var modular_por_posicion_y: bool = true
## Presión base al tocar en la zona superior (da respuesta inmediata y controlable)
@export_range(0.1, 0.8) var presion_minima_toque: float = 0.35
## Si es verdadero, genera una breve pulsación háptica al llegar al 100% de presión en móvil
@export var vibrar_al_limite: bool = true

@export_group("Estética y Color de Acento")
## Opcional: define un color de realce personalizado para este pedal (si es transparente, usa el del shader)
@export var color_acento_personalizado: Color = Color(0, 0, 0, 0):
	set(val):
		color_acento_personalizado = val
		if val.a > 0.05 and material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("accent_color", val)

var presion_actual: float = 0.0
var presion_objetivo: float = 0.0
var _dedo_activo: int = -1
var _ya_vibro: bool = false
var _iv_cache: Node = null

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if nombre_pedal == "freno" and name.to_lower().contains("aceler"):
		nombre_pedal = "acelerador"

	if material is ShaderMaterial and color_acento_personalizado.a > 0.05:
		(material as ShaderMaterial).set_shader_parameter("accent_color", color_acento_personalizado)

func _usar_solo_screen_touch(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false):
		return true
	return false

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	_manejar_input(event)

func _manejar_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if _dedo_activo != -1:
			reset_pedal()
		return

	# ─── PANTALLA TÁCTIL (Móvil y Emulación Touch en PC) ───
	if event is InputEventScreenTouch:
		if event.pressed:
			if _dedo_activo == -1:
				if get_global_rect().has_point(event.position):
					_dedo_activo = event.index
					_actualizar_presion(event.position - global_position)
					get_viewport().set_input_as_handled()
		else:
			if event.index == _dedo_activo:
				_soltar_pedal()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if event.index == _dedo_activo:
			_actualizar_presion(event.position - global_position)
			get_viewport().set_input_as_handled()

	# ─── RATÓN (Fallback cuando emulate_touch_from_mouse está desactivado) ───
	elif event is InputEventMouseButton:
		if _usar_solo_screen_touch(event):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _dedo_activo == -1:
					if get_global_rect().has_point(event.position):
						_dedo_activo = -2
						_actualizar_presion(event.position - global_position)
						get_viewport().set_input_as_handled()
			else:
				if _dedo_activo == -2:
					_soltar_pedal()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _usar_solo_screen_touch(event):
			return
		if _dedo_activo == -2:
			_actualizar_presion(event.position - global_position)

func _actualizar_presion(pos_local: Vector2) -> void:
	if modular_por_posicion_y and size.y > 10.0:
		var factor_y: float = clampf(pos_local.y / size.y, 0.0, 1.0)
		presion_objetivo = lerpf(presion_minima_toque, 1.0, pow(factor_y, 0.85))
	else:
		presion_objetivo = 1.0

func _soltar_pedal() -> void:
	_dedo_activo = -1
	presion_objetivo = 0.0
	_ya_vibro = false

func _actualizar_shader_visual() -> void:
	if material is ShaderMaterial:
		var mat := material as ShaderMaterial
		mat.set_shader_parameter("amount", presion_actual)
		mat.set_shader_parameter("intensidad_presion", presion_actual)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_visible_in_tree():
		if _dedo_activo != -1:
			reset_pedal()
		return

	# Curva de progresión suave
	if _dedo_activo != -1:
		presion_actual = move_toward(presion_actual, presion_objetivo, velocidad_presion * delta)
		if vibrar_al_limite and presion_actual >= 0.98:
			if not _ya_vibro:
				if OS.has_feature("mobile"):
					Input.vibrate_handheld(20)
				_ya_vibro = true
		else:
			if presion_actual < 0.90:
				_ya_vibro = false
	else:
		presion_actual = move_toward(presion_actual, 0.0, velocidad_retorno * delta)
		_ya_vibro = false

	# Sincronizar visualmente con el shader
	_actualizar_shader_visual()

	# Transmitir a la física del vehículo
	var iv = _get_iv()
	if is_instance_valid(iv):
		if nombre_pedal.to_lower().contains("aceler"):
			iv.set_gas(presion_actual)
		else:
			iv.set_freno(presion_actual)

func reset_pedal() -> void:
	presion_actual = 0.0
	presion_objetivo = 0.0
	_dedo_activo = -1
	_ya_vibro = false
	_actualizar_shader_visual()
	var iv = _get_iv()
	if is_instance_valid(iv):
		if nombre_pedal.to_lower().contains("aceler"):
			iv.set_gas(0.0)
		else:
			iv.set_freno(0.0)