class_name CamaraEditor
extends Node3D

## CamaraEditor.gd — Cámara orbital estilo RTS / Cities: Skylines
## Diseñada específicamente para dispositivos móviles con soporte táctil y controles en pantalla.

signal modo_cenital_cambiado(es_cenital: bool)

@export var objetivo: Vector3 = Vector3(0.0, 5.0, 0.0)
@export var distancia_actual: float = 65.0
@export var distancia_minima: float = 8.0
@export var distancia_maxima: float = 400.0

@export var angulo_yaw: float = -45.0  # Rotación horizontal en grados
@export var angulo_pitch: float = -40.0 # Rotación vertical en grados (-85 a -10)
@export var velocidad_paneo: float = 1.0
@export var suavizado: float = 12.0

var es_cenital: bool = false
var _pitch_guardado: float = -40.0

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
var _objetivo_inicial: Vector3 = Vector3.ZERO
var arrastre_camara_habilitado: bool = false

func _ready() -> void:
	_construir_jerarquia_camara()
	_actualizar_transformaciones(true)

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
	_camara.far = 2500.0
	_pivot_pitch.add_child(_camara)

func _process(delta: float) -> void:
	_procesar_teclado_pc(delta)
	_actualizar_transformaciones(false, delta)

func _procesar_teclado_pc(delta: float) -> void:
	# Soporte híbrido PC: navegación fluida de cámara con teclas WASD / flechas y Q/E
	var foco = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if foco is LineEdit or foco is TextEdit:
		return
		
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
		panear_direccion(dir_teclado.normalized(), delta)
		
	if Input.is_key_pressed(KEY_Q):
		rotar_orbita(-90.0 * delta)
	elif Input.is_key_pressed(KEY_E):
		rotar_orbita(90.0 * delta)

func _actualizar_transformaciones(inmediato: bool, delta: float = 0.0) -> void:
	if not _pivot_yaw or not _pivot_pitch or not _camara:
		return
	
	distancia_actual = clamp(distancia_actual, distancia_minima, distancia_maxima)
	angulo_pitch = clamp(angulo_pitch, -88.0, -10.0)
	
	if inmediato:
		global_position = objetivo
		_pivot_yaw.rotation_degrees.y = angulo_yaw
		_pivot_pitch.rotation_degrees.x = angulo_pitch
		_camara.position = Vector3(0, 0, distancia_actual)
	else:
		var peso = clamp(suavizado * delta, 0.0, 1.0)
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
	angulo_pitch = clamp(angulo_pitch + grados_pitch, -85.0, -15.0)

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

func manejar_evento_pantalla(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_toques_activos[event.index] = event.position
			if _toques_activos.size() == 2:
				var puntos = _toques_activos.values()
				_distancia_toques_inicial = puntos[0].distance_to(puntos[1])
				_distancia_camara_inicial = distancia_actual
				_angulo_toques_inicial = puntos[0].angle_to_point(puntos[1])
				_yaw_inicial = angulo_yaw
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
		
	elif event is InputEventScreenDrag:
		if _toques_activos.has(event.index):
			_toques_activos[event.index] = event.position
			
		# Dos dedos: Pinch to zoom y rotación simultánea
		if _toques_activos.size() == 2:
			var puntos = _toques_activos.values()
			var dist_actual = puntos[0].distance_to(puntos[1])
			if _distancia_toques_inicial > 5.0 and dist_actual > 5.0:
				var ratio = _distancia_toques_inicial / dist_actual
				distancia_actual = clamp(_distancia_camara_inicial * ratio, distancia_minima, distancia_maxima)
				
				# Giro con dos dedos
				var angulo_actual = puntos[0].angle_to_point(puntos[1])
				var delta_angulo = rad_to_deg(angulo_actual - _angulo_toques_inicial)
				angulo_yaw = _yaw_inicial - delta_angulo
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

	# Soporte ratón de escritorio para testing rápido
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(0.85)
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.18)
			return true
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			rotar_orbita(-event.relative.x * 0.3)
			inclinar_pitch(event.relative.y * 0.25)
			return true
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var forward = -_camara.global_transform.basis.z
			forward.y = 0.0
			var right = _camara.global_transform.basis.x
			right.y = 0.0
			var factor = distancia_actual * 0.002
			objetivo += (-right * event.relative.x + forward * event.relative.y) * factor
			return true

	return false
