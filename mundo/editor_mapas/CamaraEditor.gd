class_name CamaraEditor
extends Node3D

## CamaraEditor.gd — Cámara orbital estilo RTS / Cities: Skylines
## Diseñada específicamente para dispositivos móviles con soporte táctil y controles en pantalla.

signal modo_cenital_cambiado(es_cenital: bool)

@export var objetivo: Vector3 = Vector3(0.0, 5.0, 0.0)
@export var distancia_actual: float = 65.0
@export var distancia_minima: float = 1.5
@export var distancia_maxima: float = 800.0

@export var angulo_yaw: float = -45.0  # Rotación horizontal en grados
@export var angulo_pitch: float = -40.0 # Rotación vertical en grados (-89 a +15)
@export var velocidad_paneo: float = 1.0
@export var suavizado: float = 14.5

var es_cenital: bool = false
var _pitch_guardado: float = -40.0
@export var activa: bool = true

var _camara: Camera3D
var _pivot_yaw: Node3D
var _pivot_pitch: Node3D

# Manejo de entrada táctil
var _toques_activos: Dictionary = {}
var _distancia_toques_inicial: float = 0.0
var _distancia_camara_inicial: float = 0.0
var _angulo_toques_inicial: float = 0.0
var _yaw_inicial: float = 0.0
var _pos_toque_unipersonal_inicial: Vector2 = Vector2.ZERO
var _centro_toques_anterior: Vector2 = Vector2.ZERO
var _objetivo_inicial: Vector3 = Vector3.ZERO
var arrastre_camara_habilitado: bool = false
var _vel_inercia_pan: Vector3 = Vector3.ZERO
var _vel_inercia_yaw: float = 0.0

func _ready() -> void:
	_construir_jerarquia_camara()
	_actualizar_transformaciones(true)

func _input(event: InputEvent) -> void:
	if not activa or not is_visible_in_tree():
		return
	# Limpiar siempre toques liberados aunque el dedo termine sobre un panel UI
	if event is InputEventScreenTouch and not event.pressed:
		_toques_activos.erase(event.index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_toques_activos.clear()

func _construir_jerarquia_camara() -> void:
	_pivot_yaw = Node3D.new()
	_pivot_yaw.name = "PivotYaw"
	add_child(_pivot_yaw)
	
	_pivot_pitch = Node3D.new()
	_pivot_pitch.name = "PivotPitch"
	_pivot_yaw.add_child(_pivot_pitch)
	
	_camara = Camera3D.new()
	_camara.name = "Camera3D"
	_camara.current = true
	_camara.fov = 55.0
	_camara.near = 0.5
	_camara.far = 600.0
	_pivot_pitch.add_child(_camara)


func set_distancia_renderizado(dist: float) -> void:
	if _camara:
		_camara.far = clampf(dist, 150.0, 2500.0)

func _process(delta: float) -> void:
	if not activa or not is_visible_in_tree():
		return
	_procesar_teclado_pc(delta)
	_aplicar_inercia_tactil(delta)
	_actualizar_transformaciones(false, delta)


func _aplicar_inercia_tactil(delta: float) -> void:
	if not _toques_activos.is_empty():
		return
	if _vel_inercia_pan.length_squared() > 0.0001:
		objetivo += _vel_inercia_pan * delta
		_vel_inercia_pan *= exp(-8.5 * delta)
	else:
		_vel_inercia_pan = Vector3.ZERO
	if absf(_vel_inercia_yaw) > 0.05:
		rotar_orbita(_vel_inercia_yaw * delta)
		_vel_inercia_yaw *= exp(-9.0 * delta)
	else:
		_vel_inercia_yaw = 0.0

func _procesar_teclado_pc(delta: float) -> void:
	# Navegación estilo aplicación 3D: WASD + Q/E (subir/bajar o rotar) + Shift para acelerar
	var foco = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if foco is LineEdit or foco is TextEdit:
		return

	var vel_mult: float = 2.4 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var modo_vuelo: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	var dir_teclado := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir_teclado.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir_teclado.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir_teclado.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir_teclado.x += 1.0

	if dir_teclado != Vector2.ZERO:
		if modo_vuelo and _camara:
			var fwd_3d: Vector3 = -_camara.global_transform.basis.z
			var right_3d: Vector3 = _camara.global_transform.basis.x
			var step: float = maxf(18.0, distancia_actual * 0.75) * velocidad_paneo * vel_mult * delta
			objetivo += (right_3d * dir_teclado.x + fwd_3d * (-dir_teclado.y)).normalized() * step
		else:
			panear_direccion(dir_teclado.normalized() * vel_mult, delta)

	if Input.is_key_pressed(KEY_E):
		if modo_vuelo:
			objetivo.y += maxf(12.0, distancia_actual * 0.45) * vel_mult * delta
		else:
			rotar_orbita(95.0 * delta)
	elif Input.is_key_pressed(KEY_Q):
		if modo_vuelo:
			objetivo.y -= maxf(12.0, distancia_actual * 0.45) * vel_mult * delta
		else:
			rotar_orbita(-95.0 * delta)

func _actualizar_transformaciones(inmediato: bool, delta: float = 0.0) -> void:
	if not _pivot_yaw or not _pivot_pitch or not _camara:
		return
	
	distancia_actual = clamp(distancia_actual, distancia_minima, distancia_maxima)
	angulo_pitch = clamp(angulo_pitch, -89.0, 15.0)
	
	if inmediato:
		global_position = objetivo
		_pivot_yaw.rotation_degrees.y = angulo_yaw
		_pivot_pitch.rotation_degrees.x = angulo_pitch
		_camara.position = Vector3(0, 0, distancia_actual)
	else:
		var peso: float = 1.0 - exp(-suavizado * delta)
		global_position = global_position.lerp(objetivo, peso)
		_pivot_yaw.rotation_degrees.y = lerp_angle(deg_to_rad(_pivot_yaw.rotation_degrees.y), deg_to_rad(angulo_yaw), peso) * (180.0 / PI)
		_pivot_pitch.rotation_degrees.x = lerp(_pivot_pitch.rotation_degrees.x, angulo_pitch, peso)
		_camara.position.z = lerp(_camara.position.z, distancia_actual, peso)

# ── API DE CONTROL MÓVIL Y BOTONES EN PANTALLA ───────────────────────

func panear_direccion(vector_pantalla: Vector2, delta: float = 0.016) -> void:
	var forward = -_camara.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var right = _camara.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	
	var factor_escala = (distancia_actual / 50.0) * velocidad_paneo * 40.0 * delta
	var movimiento = (right * vector_pantalla.x + forward * (-vector_pantalla.y)) * factor_escala
	objetivo += movimiento

func panear_por_arrastre(delta_pixeles: Vector2) -> void:
	if not _camara:
		return
	var forward = -_camara.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var right = _camara.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	
	var factor_escala = (distancia_actual / 850.0)
	var movimiento = (right * delta_pixeles.x - forward * delta_pixeles.y) * factor_escala
	objetivo -= movimiento

func rotar_orbita(grados_yaw: float) -> void:
	angulo_yaw += grados_yaw
	if angulo_yaw > 180.0:
		angulo_yaw -= 360.0
	elif angulo_yaw < -180.0:
		angulo_yaw += 360.0

func inclinar_pitch(grados_pitch: float) -> void:
	if es_cenital:
		alternar_cenital()
	angulo_pitch = clamp(angulo_pitch + grados_pitch, -89.0, 15.0)

func zoom(factor: float) -> void:
	distancia_actual = clamp(distancia_actual * factor, distancia_minima, distancia_maxima)

func alternar_cenital() -> void:
	es_cenital = not es_cenital
	if es_cenital:
		_pitch_guardado = angulo_pitch
		angulo_pitch = -88.0
	else:
		angulo_pitch = _pitch_guardado
	modo_cenital_cambiado.emit(es_cenital)

func enfocar_punto(pos: Vector3, distancia: float = -1.0) -> void:
	objetivo = pos
	if distancia > 0.0:
		distancia_actual = distancia

func obtener_camara() -> Camera3D:
	return _camara

func proyectar_rayo_origen(screen_pos: Vector2) -> Vector3:
	if _camara:
		return _camara.project_ray_origin(screen_pos)
	return Vector3.ZERO

func proyectar_rayo_direccion(screen_pos: Vector2) -> Vector3:
	if _camara:
		return _camara.project_ray_normal(screen_pos)
	return Vector3.DOWN

# ── GESTOS TÁCTILES MÓVILES (PINCH TO ZOOM / TWIST / DRAG) ───────────

func _obtener_puntos_ordenados() -> Array[Vector2]:
	var keys := _toques_activos.keys()
	keys.sort()
	var res: Array[Vector2] = []
	for k in keys:
		res.append(_toques_activos[k] as Vector2)
	return res


func manejar_evento_pantalla(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_vel_inercia_pan = Vector3.ZERO
			_vel_inercia_yaw = 0.0
			if _toques_activos.size() >= 2:
				_toques_activos.clear()
			_toques_activos[event.index] = event.position
			if _toques_activos.size() == 2:
				var puntos := _obtener_puntos_ordenados()
				_distancia_toques_inicial = puntos[0].distance_to(puntos[1])
				_distancia_camara_inicial = distancia_actual
				_angulo_toques_inicial = puntos[0].angle_to_point(puntos[1])
				_yaw_inicial = angulo_yaw
				_centro_toques_anterior = (puntos[0] + puntos[1]) * 0.5
			elif _toques_activos.size() == 1 and arrastre_camara_habilitado:
				_pos_toque_unipersonal_inicial = event.position
				_objetivo_inicial = objetivo
		else:
			_toques_activos.erase(event.index)
			if _toques_activos.size() == 1 and arrastre_camara_habilitado:
				for k in _toques_activos:
					_pos_toque_unipersonal_inicial = _toques_activos[k]
					_objetivo_inicial = objetivo
		return _toques_activos.size() >= 2

	elif event is InputEventMagnifyGesture:
		if event.factor > 0.01:
			zoom(clampf(1.0 / event.factor, 0.88, 1.14))
			return true
		
	elif event is InputEventScreenDrag:
		if _toques_activos.has(event.index):
			_toques_activos[event.index] = event.position
			
		# Dos dedos: Pinch to zoom + Paneo 3D + Rotación simultánea
		if _toques_activos.size() == 2:
			var puntos := _obtener_puntos_ordenados()
			var dist_actual: float = puntos[0].distance_to(puntos[1])
			var centro_actual: Vector2 = (puntos[0] + puntos[1]) * 0.5
			var delta_centro: Vector2 = centro_actual - _centro_toques_anterior
			_centro_toques_anterior = centro_actual
			if _camara and delta_centro.length_squared() > 0.01:
				var right_t: Vector3 = _camara.global_transform.basis.x.normalized()
				var up_t: Vector3 = _camara.global_transform.basis.y.normalized()
				var esc_t: float = maxf(0.015, distancia_actual * 0.0016)
				var mov_pan := (-right_t * delta_centro.x + up_t * delta_centro.y) * esc_t
				objetivo += mov_pan
				_vel_inercia_pan = _vel_inercia_pan.lerp(mov_pan * 18.0, 0.45)
			if _distancia_toques_inicial > 5.0 and dist_actual > 5.0:
				var ratio: float = _distancia_toques_inicial / dist_actual
				distancia_actual = clamp(_distancia_camara_inicial * ratio, distancia_minima, distancia_maxima)

				# Giro natural con dos dedos (sin inversión y sin saltos en +-180°)
				var angulo_actual: float = puntos[0].angle_to_point(puntos[1])
				var delta_angulo: float = rad_to_deg(angle_difference(_angulo_toques_inicial, angulo_actual))
				var nuevo_yaw: float = wrapf(_yaw_inicial + delta_angulo, -180.0, 180.0)
				var dif_yaw: float = rad_to_deg(angle_difference(deg_to_rad(angulo_yaw), deg_to_rad(nuevo_yaw)))
				_vel_inercia_yaw = lerpf(_vel_inercia_yaw, dif_yaw * 16.0, 0.4)
				angulo_yaw = nuevo_yaw
			return true
			
		# Un dedo en modo navegación de cámara
		elif _toques_activos.size() == 1 and arrastre_camara_habilitado:
			var delta_pos = event.position - _pos_toque_unipersonal_inicial
			var forward = -_camara.global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right = _camara.global_transform.basis.x
			right.y = 0.0
			right = right.normalized()
			var escala = (distancia_actual / 800.0)
			objetivo = _objetivo_inicial - (right * delta_pos.x - forward * delta_pos.y) * escala
			return true

	# Soporte ratón de escritorio estilo app 3D (Blender / Godot)
	elif event is InputEventMouseButton:
		if not event.pressed:
			return false
		var paso_base: float = 0.94 if not Input.is_key_pressed(KEY_SHIFT) else 0.88
		var mult: float = clampf(event.factor, 0.25, 1.5) if event.factor > 0.0 else 1.0
		var paso_zoom: float = pow(paso_base, mult)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(paso_zoom)
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0 / paso_zoom)
			return true
	elif event is InputEventMouseMotion:
		var orbitar_mouse: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_key_pressed(KEY_ALT))
		var panear_mouse: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		if orbitar_mouse:
			rotar_orbita(-event.relative.x * 0.28)
			inclinar_pitch(-event.relative.y * 0.24)
			return true
		elif panear_mouse and _camara:
			var right_3d: Vector3 = _camara.global_transform.basis.x.normalized()
			var up_3d: Vector3 = _camara.global_transform.basis.y.normalized()
			var factor: float = maxf(0.015, distancia_actual * 0.00145)
			objetivo += (-right_3d * event.relative.x + up_3d * event.relative.y) * factor
			return true

	return false
