class_name CamaraEstudio
extends Camera3D

## Cámara de órbita y estudio 3D para inspección y animación cómoda.
## Soporta rotación orbital, paneo, zoom con rueda y enfoque en huesos con 'F'.

@export var objetivo_pivot: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var distancia: float = 3.0
@export var distancia_min: float = 0.4
@export var distancia_max: float = 12.0
@export var sensibilidad_rotacion: float = 0.005
@export var sensibilidad_paneo: float = 0.003
@export var sensibilidad_zoom: float = 0.3
@export var suavizado: float = 18.0

var _yaw: float = 0.0
var _pitch: float = 0.15
var _distancia_objetivo: float = 3.0
var _pivot_actual: Vector3 = Vector3(0.0, 1.0, 0.0)

var _arrastrando_orbita: bool = false
var _arrastrando_paneo: bool = false
var _pos_mouse_anterior: Vector2 = Vector2.ZERO

func _ready():
	_distancia_objetivo = distancia
	_pivot_actual = objetivo_pivot
	_actualizar_transformacion(true)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_arrastrando_orbita = true
				_pos_mouse_anterior = mb.position
			else:
				_arrastrando_orbita = false
				
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_arrastrando_paneo = true
				_pos_mouse_anterior = mb.position
			else:
				_arrastrando_paneo = false
				
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_distancia_objetivo = clampf(_distancia_objetivo - sensibilidad_zoom, distancia_min, distancia_max)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_distancia_objetivo = clampf(_distancia_objetivo + sensibilidad_zoom, distancia_min, distancia_max)

	elif event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		var delta = mm.position - _pos_mouse_anterior
		_pos_mouse_anterior = mm.position
		
		# Si se presiona Shift + RMB o MMB -> Paneo
		var shift_pulsado = Input.is_key_pressed(KEY_SHIFT)
		if _arrastrando_paneo or (_arrastrando_orbita and shift_pulsado):
			var cam_basis = global_transform.basis
			var offset = (-cam_basis.x * delta.x + cam_basis.y * delta.y) * sensibilidad_paneo * (_distancia_objetivo * 0.4)
			objetivo_pivot += offset
			
		elif _arrastrando_orbita:
			_yaw -= delta.x * sensibilidad_rotacion
			_pitch = clampf(_pitch - delta.y * sensibilidad_rotacion, -PI * 0.48, PI * 0.48)
			
	elif event is InputEventKey:
		var ek = event as InputEventKey
		if ek.pressed and ek.keycode == KEY_F and not ek.echo:
			# El controlador principal puede emitir o actualizar el objetivo_pivot
			pass

func _process(delta: float):
	_pivot_actual = _pivot_actual.lerp(objetivo_pivot, delta * suavizado)
	distancia = lerpf(distancia, _distancia_objetivo, delta * suavizado)
	_actualizar_transformacion(false)

func _actualizar_transformacion(_inmediato: bool):
	var rot_basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	var dir = rot_basis * Vector3.BACK
	global_position = _pivot_actual + dir * distancia
	look_at(_pivot_actual, Vector3.UP)

func enfocar_posicion(pos_3d: Vector3, dist_sugerida: float = -1.0):
	objetivo_pivot = pos_3d
	if dist_sugerida > 0.0:
		_distancia_objetivo = clampf(dist_sugerida, distancia_min, distancia_max)

func vista_frente():
	_yaw = 0.0
	_pitch = 0.0

func vista_lateral():
	_yaw = PI * 0.5
	_pitch = 0.0

func vista_atras():
	_yaw = PI
	_pitch = 0.0

func vista_arriba():
	_pitch = PI * 0.48

func vista_perspectiva():
	_yaw = deg_to_rad(-35.0)
	_pitch = deg_to_rad(15.0)
	_distancia_objetivo = 2.6
	objetivo_pivot = Vector3(0.0, 1.0, 0.0)

func reset_camara():
	vista_perspectiva()
