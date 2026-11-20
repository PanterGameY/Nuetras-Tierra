# cam_interna.gd
# Cámara en primera persona para el conductor (Mouse Libre / Cabina).
# Optimizada para bajo consumo de CPU y máxima fluidez en Android y PC.
extends Camera3D

# ─────────────────────────────────────────────────────────────
#  CONFIGURACIÓN EXPORTADA (ORGANIZADA POR GRUPOS)
# ─────────────────────────────────────────────────────────────
@export_group("Referencias")
## Nodo del controlador de chasis para compensación de balanceo
@export var controlador_chasis: Node3D
## Ruta al nodo del motor del vehículo
@export var motor_nodo: NodePath

@export_group("Control y Límites de Mirada")
## Sensibilidad del movimiento táctil / mouse al rotar la cabeza
@export var sensibilidad: float = 0.14
## Límites de ángulo vertical (pitch) en grados (mínimo, máximo)
@export var limite_v: Vector2 = Vector2(-65.0,  65.0)
## Límites de ángulo horizontal (yaw) en grados (izquierda, derecha)
@export var limite_h: Vector2 = Vector2(-145.0, 145.0)
## Duración en segundos de la animación de centrado tras doble clic en pantalla
@export var duracion_centrado_doble_click: float = 0.35

@export_group("Inclinación de Mirada (Head Tilt)")
## Inclinación biomecánica lateral de la cabeza al girar el cuello hacia los lados (en grados)
@export var inclinacion_mirada_lateral_deg: float = 4.2
## Velocidad de suavizado del ladeo de la cabeza
@export var inclinacion_mirada_suavizado: float = 8.0
## Invierte el sentido del ladeo de la cabeza al mirar a los lados
@export var invertir_inclinacion_cabeza: bool = false

@export_group("Desenfoque por Movimiento (Motion Blur)")
## Activa el efecto de desenfoque cinemático al girar la cámara rápidamente
@export var desenfoque_movimiento_activo: bool = true
## Intensidad máxima del desenfoque al realizar giros rápidos
@export_range(0.0, 2.0, 0.05) var intensidad_desenfoque: float = 0.5
## Velocidad angular de giro (grados/segundo) a partir de la cual inicia el desenfoque
@export_range(30.0, 300.0, 5.0) var umbral_velocidad_desenfoque: float = 90.0
## Velocidad de suavizado y desvanecimiento del desenfoque
@export_range(2.0, 25.0, 0.5) var suavizado_desenfoque: float = 10.0
## Muestras del shader de desenfoque (3 a 8; 5 es ideal para balance rendimiento/calidad)
@export_range(3, 8, 1) var muestras_desenfoque: int = 5
## Material shader personalizado para el desenfoque (opcional; si está vacío usa el shader por defecto)
@export var material_desenfoque_custom: ShaderMaterial = null

@export_group("Asomarse a Ventana y Espejos")
## Ángulo horizontal mínimo para comenzar a asomarse por la ventana
@export var angulo_asomarse: float = 65.0
## Distancia en metros que se desplaza la cabeza hacia el exterior/espejo
@export var distancia_asomada: float = 0.50
## Lado del conductor: -1 = volante a la izquierda, 1 = volante a la derecha
@export var asomarse_lado_conductor: int = -1
## Enfoque y zoom sutil del FOV al mirar espejos laterales para máxima claridad
@export var enfoque_espejos_activado: bool = true
## Grados de zoom que se reduce el FOV al enfocar un espejo lateral
@export var zoom_enfoque_espejos_deg: float = 5.0
## Ángulo horizontal a partir del cual inicia el zoom a espejos
@export var angulo_inicio_enfoque: float = 35.0

@export_group("Asiento Neumático (Air-Ride)")
## Simulación de suspensión neumática del asiento del conductor frente a baches e inercias
@export var asiento_neumatico_activo: bool = true
## Rigidez elástica del asiento
@export var rigidez_asiento: float = 45.0
## Amortiguación de rebote del asiento neumático
@export var amortiguacion_asiento_neumatico: float = 7.5
## Recorrido vertical máximo del asiento en metros
@export var recorrido_asiento_max: float = 0.045
## Amortiguación secundaria / alternativa del asiento
@export var amortiguacion_asiento: float = 0.02

@export_group("Dinámica de Conducción e Inercia")
## Intensidad global de fuerzas G percibidas en la cabeza
@export var intensidad_g: float = 1.0
## Suavizado de respuesta a fuerzas G
@export var suavizado_g: float = 12.0
## Elevación/descenso de la mirada por aceleración longitudinal
@export var altura_aceleracion: float = 0.0
## Inclinación vertical (pitch) al acelerar o frenar
@export var intensidad_pitch_aceleracion: float = 2.5
## Suavizado de inclinación por aceleración/frenado
@export var suavizado_pitch: float = 4.0
## Inclinación lateral (roll) al tomar curvas
@export var intensidad_roll_giro: float = 1.8
## Suavizado de inclinación lateral en curvas
@export var suavizado_roll: float = 3.5
## Anticipación de mirada hacia la curva según rotación del vehículo
@export var look_ahead_curvas: float = 0.0
## Grados de anticipación de mirada en dirección del giro
@export var anticipacion_direccion_deg: float = 0.5
## Multiplicador de anticipación según posición del volante
@export var anticipacion_volante_mult: float = 0.5
## Multiplicador de anticipación según ángulo de ruedas directrices
@export var anticipacion_ruedas_mult: float = 0.3
## Suavizado de la anticipación de dirección
@export var anticipacion_suavizado: float = 4.0

@export_group("Vibraciones del Motor")
## Pulsación armónica realista de combustión diésel transmitida al habitáculo
@export var vibracion_diesel_activa: bool = true
## Amplitud de la vibración diésel en ralentí/conducción
@export var intensidad_vibracion_diesel: float = 0.0016
## Intensidad de vibración adicional genérica
@export var intensidad_vibracion: float = 0.0
## Vibración mínima por RPM de motor
@export var vibracion_rpm_min: float = 0.0
## Vibración máxima por RPM de motor
@export var vibracion_rpm_max: float = 0.0

@export_group("FOV y Óptica")
## Campo de visión (FOV) base de la cámara en reposo
@export var fov_base: float = 72.0
## Campo de visión máximo con velocidad
@export var fov_max: float = 82.0
## Factor de expansión de FOV según la velocidad del vehículo
@export var fov_velocidad_factor: float = 0.08

@export_group("Gestión y Sistema")
## Forzar que esta cámara sea la activa cuando el vehículo esté en uso
@export var force_make_current_when_active: bool = true
## Limpiar cámara externa al activarse esta cámara
@export var clear_external_on_activate: bool = true
## Imprimir información de depuración en consola
@export var debug: bool = false

# ─────────────────────────────────────────────────────────────
#  ESTADO INTERNO
# ─────────────────────────────────────────────────────────────
var rot_x: float = 0.0
var rot_y: float = 0.0
var _vel_previa: Vector3 = Vector3.ZERO
var _pos_original: Vector3
var _tiempo_sin_mouse: float = 0.0
var _offset_cabeza: Vector3 = Vector3.ZERO
var _salto_asiento_y: float = 0.0
var _asiento_pos_y: float = 0.0
var _asiento_vel_y: float = 0.0
var _roll_mirada: float = 0.0
var _yaw_anticipation_current: float = 0.0
var _pitch_dinamico: float = 0.0
var _roll_dinamico: float = 0.0
var _ultimo_tiempo_click: int = 0
var _ultima_pos_click: Vector2 = Vector2(-999.0, -999.0)
var _tween_centrado: Tween = null

# Estado interno para Desenfoque por Movimiento (Motion Blur)
var _canvas_layer_blur: CanvasLayer = null
var _color_rect_blur: ColorRect = null
var _mat_blur: ShaderMaterial = null
var _prev_rotacion_cam: Vector3 = Vector3.ZERO
var _intensidad_blur_actual: float = 0.0
var _dir_blur_actual: Vector2 = Vector2.RIGHT
var _era_current: bool = false

@onready var coche: RigidBody3D = get_owner()
var _motor_nodo_ref: Node = null
var _camera_manager_ref: Node = null
var _audio_motor: AudioStreamPlayer3D = null
var _ctrl_llantas: Node = null
var _llantas_directrices: Array = []

# Diccionario reciclable para evitar Garbage Collection en cada frame
var _estado_cache: Dictionary = {
	"position": Vector3.ZERO,
	"rotation": Vector3.ZERO,
	"fov": 72.0
}

# ─────────────────────────────────────────────────────────────
#  BÚSQUEDA Y CONFIGURACIÓN INICIAL
# ─────────────────────────────────────────────────────────────
func _find_coche_owner() -> RigidBody3D:
	var cand = get_owner()
	if cand and cand is RigidBody3D:
		return cand
	var p: Node = get_parent()
	while p:
		if p is RigidBody3D:
			return p
		p = p.get_parent()
	return null

func _find_camera_manager() -> Node:
	var p: Node = get_parent()
	while p:
		if p.has_method("seleccionar_camara") or p.has_method("alternar_camara") or p.has_method("clear_external_camera"):
			return p
		p = p.get_parent()
	return null

func _actualizar_referencias_cacheadas() -> void:
	if coche:
		_ctrl_llantas = coche.get_node_or_null("ControladorLlantas")
		if _ctrl_llantas:
			var directrices = _ctrl_llantas.get("llantas_directrices")
			if directrices != null and directrices is Array and directrices.size() > 0:
				_llantas_directrices = directrices
			else:
				_llantas_directrices.clear()
				for child in _ctrl_llantas.get_children():
					if child.get("angulo_direccion") != null:
						_llantas_directrices.append(child)

	if _motor_nodo_ref:
		_audio_motor = null
		for hijo in _motor_nodo_ref.get_children():
			if hijo is AudioStreamPlayer3D:
				_audio_motor = hijo
				break

# ─────────────────────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_pos_original = position
	_estado_cache["position"] = position
	_estado_cache["rotation"] = rotation
	_estado_cache["fov"] = fov
	_prev_rotacion_cam = rotation

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if motor_nodo:
		_motor_nodo_ref = get_node_or_null(motor_nodo)

	if not coche:
		coche = _find_coche_owner()
		if not coche:
			push_warning("cam_interna.gd: no pude encontrar un RigidBody3D padre/owner para la cámara")

	_actualizar_referencias_cacheadas()
	_camera_manager_ref = _find_camera_manager()

	fov = clampf(fov if fov > 0.0 else fov_base, 40.0, 95.0)

	if coche:
		_vel_previa = coche.linear_velocity

	if desenfoque_movimiento_activo:
		_inicializar_efecto_desenfoque()

	if debug:
		print("[cam_interna] ready: initial_fov=", fov, " owner=", get_owner(), " coche=", coche)

	set_physics_process(true)

# ─────────────────────────────────────────────────────────────
#  ENTRADA DE ROTACIÓN (señal desde ZonaCamara / UI)
# ─────────────────────────────────────────────────────────────
func _manejar_rotacion_libre(relative: Vector2) -> void:
	if _tween_centrado and _tween_centrado.is_valid():
		_tween_centrado.kill()
	_tiempo_sin_mouse = 0.0
	rot_y -= relative.x * sensibilidad
	rot_x -= relative.y * sensibilidad
	rot_x = clampf(rot_x, limite_v.x,  limite_v.y)
	rot_y = clampf(rot_y, limite_h.x, limite_h.y)

# ─────────────────────────────────────────────────────────────
#  CENTRADO SUAVE
# ─────────────────────────────────────────────────────────────
func centrar_camara(duracion: float = -1.0) -> void:
	var d: float = duracion_centrado_doble_click if duracion <= 0.0 else duracion
	if _tween_centrado and _tween_centrado.is_valid():
		_tween_centrado.kill()
	_tween_centrado = create_tween()
	_tween_centrado.set_parallel(true)
	_tween_centrado.set_trans(Tween.TRANS_SINE)
	_tween_centrado.set_ease(Tween.EASE_OUT)
	_tween_centrado.tween_property(self, "rot_y", 0.0, d)
	_tween_centrado.tween_property(self, "rot_x", 0.0, d)
	_tween_centrado.chain().tween_callback(func(): _tiempo_sin_mouse = 0.0)

# ─────────────────────────────────────────────────────────────
#  DETECCIÓN DE DOBLE CLIC / DOBLE TOQUE EN PANTALLA
# ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not current:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.double_click or _verificar_doble_clic(event.position):
				centrar_camara()
	elif event is InputEventScreenTouch:
		if event.pressed and event.index == 0:
			if (event.get("double_tap") == true) or _verificar_doble_clic(event.position):
				centrar_camara()

func _verificar_doble_clic(pos: Vector2) -> bool:
	var ahora: int = Time.get_ticks_msec()
	var dt: int = ahora - _ultimo_tiempo_click
	var dist: float = pos.distance_to(_ultima_pos_click)
	_ultimo_tiempo_click = ahora
	_ultima_pos_click = pos
	if dt <= 350 and dist <= 50.0:
		_ultimo_tiempo_click = 0
		_ultima_pos_click = Vector2(-999.0, -999.0)
		return true
	return false

# ─────────────────────────────────────────────────────────────
#  CONTROL DE ACTIVIDAD (Ahorro de CPU)
# ─────────────────────────────────────────────────────────────
func _debe_procesar_completo() -> bool:
	# Si la cámara es la activa en pantalla, debe procesar.
	if current:
		return true
	# Si hay un CameraManager y tiene asignado un target externo (espejo retrovisor)
	if _camera_manager_ref != null:
		if _camera_manager_ref.get("external_camera_target") != null:
			return true
		var idx = _camera_manager_ref.get("indice_actual")
		if idx != null and int(idx) == 1:
			return true
	return false

# ─────────────────────────────────────────────────────────────
#  LOOP PRINCIPAL DE FÍSICA
# ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not coche:
		return

	# Si no está en uso y no se necesita proyectar, hibernar cálculos pesados
	if not _debe_procesar_completo():
		_vel_previa = coche.linear_velocity
		if is_instance_valid(_canvas_layer_blur) and _canvas_layer_blur.visible:
			_canvas_layer_blur.visible = false
		_intensidad_blur_actual = 0.0
		_prev_rotacion_cam = rotation
		return

	var state: Dictionary = compute_local_state(delta)

	# Suavizado de posición independiente del framerate
	var pos_factor: float = 1.0 - exp(-30.0 * delta)
	position = position.lerp(state["position"], pos_factor)

	# Suavizado de rotación seguro con lerp_angle (evita gimbal lock / giros de 360°)
	var rot_factor: float = 1.0 - exp(-20.0 * delta)
	var target_rot: Vector3 = state["rotation"]
	rotation.x = lerp_angle(rotation.x, target_rot.x, rot_factor)
	rotation.y = lerp_angle(rotation.y, target_rot.y, rot_factor)
	rotation.z = lerp_angle(rotation.z, target_rot.z, rot_factor)

	# Suavizado de FOV (ágil para enfoque de espejos)
	var fov_factor: float = 1.0 - exp(-6.0 * delta)
	fov = lerpf(fov, state["fov"], fov_factor)

	# Gestión con CameraManager
	var veh_activo: bool = (coche and is_instance_valid(coche) and coche.get("activo") == true)
	if veh_activo:
		var manager_idx: int = -1
		if _camera_manager_ref and typeof(_camera_manager_ref.indice_actual) != TYPE_NIL:
			manager_idx = int(_camera_manager_ref.indice_actual)

		var should_force_current: bool = force_make_current_when_active and (manager_idx == 1)
		if should_force_current and not current:
			make_current()

		if clear_external_on_activate and _camera_manager_ref and _camera_manager_ref.has_method("clear_external_camera"):
			if manager_idx != 0:
				_camera_manager_ref.clear_external_camera()
	else:
		if current:
			current = false

	# Actualización del efecto de desenfoque por movimiento rápido de cámara
	_actualizar_efecto_desenfoque(delta)

# ─────────────────────────────────────────────────────────────
#  CÁLCULO DE ESTADO DINÁMICO
# ─────────────────────────────────────────────────────────────
func compute_local_state(delta: float) -> Dictionary:
	if not coche or delta <= 0.0:
		_estado_cache["position"] = position
		_estado_cache["rotation"] = rotation
		_estado_cache["fov"] = fov
		return _estado_cache

	# Registro de tiempo sin interacción (sin auto-centrado pasivo; solo manual por doble clic)
	_tiempo_sin_mouse += delta

	# ── TRANSFORMACIÓN LOCAL ULTRA-RÁPIDA (Transpuesta ortonormal) ──
	var inv_basis: Basis = coche.global_transform.basis.orthonormalized().transposed()

	# ── FUERZAS G Y PROTECCIÓN CONTRA PICOS ──────────────────
	var raw_acc: Vector3 = (coche.linear_velocity - _vel_previa) / delta
	_vel_previa = coche.linear_velocity

	# Limitar picos extremos para evitar sacudidas violentas por lag o choques
	raw_acc.x = clampf(raw_acc.x, -50.0, 50.0)
	raw_acc.y = clampf(raw_acc.y, -50.0, 50.0)
	raw_acc.z = clampf(raw_acc.z, -50.0, 50.0)

	var acc_local: Vector3 = inv_basis * raw_acc

	# 1. Asiento neumático / amortiguación vertical de asiento (Air-Ride)
	if asiento_neumatico_activo:
		var aceleracion_y_chasis: float = acc_local.y
		var fuerza_resorte: float = -_asiento_pos_y * rigidez_asiento - _asiento_vel_y * amortiguacion_asiento_neumatico
		var fuerza_inercial: float = -aceleracion_y_chasis * 0.003
		_asiento_vel_y += (fuerza_resorte + fuerza_inercial) * delta
		_asiento_pos_y += _asiento_vel_y * delta
		_asiento_pos_y = clampf(_asiento_pos_y, -recorrido_asiento_max, recorrido_asiento_max)
		_salto_asiento_y = _asiento_pos_y
	elif amortiguacion_asiento > 0.0001:
		var target_salto: float = clampf(-acc_local.y * amortiguacion_asiento * 0.003, -0.06, 0.06)
		_salto_asiento_y = lerpf(_salto_asiento_y, target_salto, 1.0 - exp(-12.0 * delta))
	else:
		_salto_asiento_y = 0.0

	var rise_accel: float = clampf(-acc_local.z * altura_aceleracion * 0.004, -0.08, 0.08)
	var target_offset := Vector3(
		clampf(-acc_local.x * 0.0045 * intensidad_g, -0.055, 0.055),
		clampf((-absf(acc_local.x) * 0.0012) + rise_accel + _salto_asiento_y, -0.06, 0.06),
		clampf(acc_local.z * 0.0055 * intensidad_g, -0.065, 0.065)
	)
	var g_smooth_t: float = 1.0 - exp(-suavizado_g * delta)
	_offset_cabeza = _offset_cabeza.lerp(target_offset, g_smooth_t)

	# 2. Vibración de motor (armónicos diésel orgánicos + vibración general)
	var vibracion := Vector3.ZERO
	if vibracion_diesel_activa and is_instance_valid(InputVehiculo) and InputVehiculo.get("motor_encendido") == true:
		var rpm_n: float = _obtener_rpm_normalizado()
		var t_vib: float = Time.get_ticks_msec() * 0.001
		var freq_combustion: float = lerpf(12.0, 36.0, rpm_n)
		var osc_x: float = sin(t_vib * freq_combustion * TAU) * 0.6 + sin(t_vib * freq_combustion * 0.5 * TAU + 1.2) * 0.4
		var osc_y: float = cos(t_vib * freq_combustion * TAU * 0.8) * 0.5 + sin(t_vib * (freq_combustion * 1.5) * TAU) * 0.3
		var amp_vib: float = lerpf(intensidad_vibracion_diesel, intensidad_vibracion_diesel * 0.60, rpm_n)
		vibracion.x += osc_x * amp_vib
		vibracion.y += osc_y * amp_vib

	if intensidad_vibracion > 0.0001:
		var pitch_actual: float = _obtener_pitch_motor()
		var factor_vib: float = clampf(pitch_actual * 0.08 + coche.linear_velocity.length() * 0.005, 0.0, 1.0)
		vibracion.x += randf_range(-intensidad_vibracion, intensidad_vibracion) * factor_vib
		vibracion.y += randf_range(-intensidad_vibracion, intensidad_vibracion) * factor_vib

	# 3. Posición (Asomarse por ventana ergonómico y ajuste de espejos)
	var target_pos: Vector3 = _pos_original + _offset_cabeza + vibracion
	target_pos = _aplicar_asomarse(target_pos)
	if is_instance_valid(controlador_chasis):
		target_pos = controlador_chasis.transform * target_pos

	# 4. Rotación dinámica base
	var rot_final: Vector3 = _calcular_rotacion(delta, inv_basis)

	# 5. FOV dinámico + Enfoque al mirar espejos laterales
	var kmh: float = coche.linear_velocity.length() * 3.6
	var target_fov: float = fov_base + clampf(kmh * fov_velocidad_factor, 0.0, maxf(fov_max - fov_base, 0.0))
	if enfoque_espejos_activado:
		var factor_enfoque: float = clampf((absf(rot_y) - angulo_inicio_enfoque) / 45.0, 0.0, 1.0)
		target_fov -= factor_enfoque * zoom_enfoque_espejos_deg
	target_fov = clampf(target_fov, 40.0, fov_max)

	# 6. Inclinación de cabeza por fuerzas longitudinales y laterales
	var dir_input: float = 0.0
	if is_instance_valid(InputVehiculo):
		dir_input = InputVehiculo.direccion

	var target_pitch: float = clampf(acc_local.z * intensidad_pitch_aceleracion * 0.08, -3.5, 3.5)
	_pitch_dinamico = lerpf(_pitch_dinamico, target_pitch, 1.0 - exp(-suavizado_pitch * delta))

	var target_roll: float = clampf(-acc_local.x * intensidad_roll_giro * 0.08, -2.8, 2.8)
	_roll_dinamico = lerpf(_roll_dinamico, target_roll, 1.0 - exp(-suavizado_roll * delta))

	# 7. Inclinación biomecánica lateral al girar la mirada (Head Tilt / Dutch Angle)
	var factor_cuello: float = sin(deg_to_rad(clampf(rot_y, -110.0, 110.0)))
	# Sentido corregido por defecto (invertido respecto a la versión previa para un ladeo natural)
	var signo_inclinacion: float = 1.0 if invertir_inclinacion_cabeza else -1.0
	var target_roll_mirada: float = factor_cuello * inclinacion_mirada_lateral_deg * signo_inclinacion
	_roll_mirada = lerpf(_roll_mirada, target_roll_mirada, 1.0 - exp(-inclinacion_mirada_suavizado * delta))

	rot_final.x += deg_to_rad(_pitch_dinamico)
	rot_final.z += deg_to_rad(_roll_dinamico + _roll_mirada)
	if is_instance_valid(controlador_chasis):
		rot_final.x += controlador_chasis.rotation.x
		rot_final.z += controlador_chasis.rotation.z

	# 8. Vibración adicional por RPM de motor si está configurada
	if is_instance_valid(InputVehiculo) and InputVehiculo.get("motor_encendido") == true:
		if vibracion_rpm_max > 0.0001:
			var rpm_factor: float = _obtener_rpm_normalizado()
			var vib_rpm: float = lerpf(vibracion_rpm_min, vibracion_rpm_max, rpm_factor)
			vibracion.x += randf_range(-vib_rpm, vib_rpm)
			vibracion.y += randf_range(-vib_rpm, vib_rpm)

	_estado_cache["position"] = target_pos + vibracion
	_estado_cache["rotation"] = rot_final
	_estado_cache["fov"]      = target_fov
	return _estado_cache

# ─────────────────────────────────────────────────────────────
#  HELPERS PRIVADOS OPTIMIZADOS
# ─────────────────────────────────────────────────────────────
func _obtener_pitch_motor() -> float:
	if is_instance_valid(_audio_motor):
		return _audio_motor.pitch_scale
	return 1.0

func _obtener_rpm_normalizado() -> float:
	if not _motor_nodo_ref and coche:
		_motor_nodo_ref = coche.get_node_or_null("Motor")
	if not _motor_nodo_ref:
		return 0.0
	var rpm_val = _motor_nodo_ref.get("rpm_motor")
	if rpm_val != null:
		var rpm: float = float(rpm_val)
		var rpm_max: float = 3000.0
		var cfg = _motor_nodo_ref.get("config")
		if cfg and cfg.get("rpm_maximas"):
			rpm_max = float(cfg.rpm_maximas)
		elif _motor_nodo_ref.get("rpm_limite_pesado") != null:
			rpm_max = float(_motor_nodo_ref.get("rpm_limite_pesado"))
		return clampf(rpm / maxf(rpm_max, 1.0), 0.0, 1.0)
	return 0.0

func _aplicar_asomarse(pos: Vector3) -> Vector3:
	# En cabinas con timón a la izquierda (asomarse_lado_conductor = -1):
	# rot_y > angulo_asomarse (mira hacia la izquierda/espejo conductor):
	# Se inclina hacia la ventana, hacia adelante y ligeramente hacia afuera
	if rot_y > angulo_asomarse:
		var f: float = clampf((rot_y - angulo_asomarse) / 45.0, 0.0, 1.0)
		pos.x += asomarse_lado_conductor * distancia_asomada * f
		pos.z -= distancia_asomada * 0.35 * f # Adelante hacia el marco del espejo
		pos.y -= distancia_asomada * 0.08 * f # Leve descenso natural
	elif rot_y < -angulo_asomarse:
		var f: float = clampf((-rot_y - angulo_asomarse) / 45.0, 0.0, 1.0)
		# Movimiento contenido hacia el centro de la cabina para ver claro el espejo derecho
		pos.x -= asomarse_lado_conductor * (distancia_asomada * 0.40) * f
		pos.z -= (distancia_asomada * 0.20) * f # Adelante hacia el parabrisas
	return pos

func _calcular_rotacion(delta: float, inv_basis: Basis) -> Vector3:
	# Anticipación de mirada en curvas por velocidad angular del chasis
	var angular_local: Vector3 = inv_basis * coche.angular_velocity
	var rot_obj_y: float = rot_y - angular_local.y * rad_to_deg(look_ahead_curvas)

	# Anticipación combinada volante e inclinación de ruedas directrices
	var dir_input: float = 0.0
	if is_instance_valid(InputVehiculo):
		dir_input = InputVehiculo.direccion

	var wheel_angle_avg_rad: float = _angulo_medio_ruedas()
	var volante_frac: float = absf(dir_input)
	var wheel_frac: float = 0.0
	if _ctrl_llantas:
		var ang_max_val = _ctrl_llantas.get("angulo_max_giro")
		var ang_max: float = float(ang_max_val) if ang_max_val != null else 35.0
		if ang_max > 0.0001:
			wheel_frac = clampf(absf(wheel_angle_avg_rad) / ang_max, 0.0, 1.0)

	var anticipation_scale: float = maxf(
		volante_frac * anticipacion_volante_mult,
		wheel_frac   * anticipacion_ruedas_mult
	)
	var yaw_target: float = dir_input * anticipacion_direccion_deg * anticipation_scale
	var smooth_anticipacion: float = 1.0 - exp(-anticipacion_suavizado * delta)
	_yaw_anticipation_current = lerpf(_yaw_anticipation_current, yaw_target, smooth_anticipacion)
	rot_obj_y -= _yaw_anticipation_current

	var rot_final := Vector3(deg_to_rad(rot_x), deg_to_rad(rot_obj_y), 0.0)

	# Compensación de balanceo de cabina/chasis (reflejo vestíbulo-ocular)
	if controlador_chasis:
		var bal: Vector3 = controlador_chasis.rotation
		rot_final.z = -bal.z * 0.55
		rot_final.x -= bal.x * 0.25

	return rot_final

func _angulo_medio_ruedas() -> float:
	if _llantas_directrices.is_empty():
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for l in _llantas_directrices:
		if is_instance_valid(l):
			var ang = l.get("angulo_direccion")
			if ang != null:
				total += float(ang)
				count += 1
	return total / count if count > 0 else 0.0

# ─────────────────────────────────────────────────────────────
#  EFECTO DE DESENFOQUE POR GIRO RÁPIDO (MOTION BLUR)
# ─────────────────────────────────────────────────────────────
const _CODIGO_SHADER_DESENFOQUE := """// Shader de post-procesamiento para desenfoque direccional (Motion Blur)
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 direccion = vec2(1.0, 0.0);
uniform float intensidad : hint_range(0.0, 1.0) = 0.0;
uniform int muestras : hint_range(3, 12) = 5;

void fragment() {
	if (intensidad <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec4 col = vec4(0.0);
		float f_muestras = float(muestras);
		vec2 paso = direccion * (intensidad * 0.032) / f_muestras;
		
		for (int i = 0; i < muestras; i++) {
			float offset = float(i) - (f_muestras - 1.0) * 0.5;
			vec2 uv = clamp(SCREEN_UV + paso * offset, vec2(0.001), vec2(0.999));
			col += texture(screen_texture, uv);
		}
		COLOR = col / f_muestras;
	}
}
"""

func _inicializar_efecto_desenfoque() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_canvas_layer_blur):
		return

	_canvas_layer_blur = CanvasLayer.new()
	_canvas_layer_blur.name = "MotionBlurCamInterna"
	# Capa 1: se proyecta sobre el mundo 3D pero por debajo de la interfaz del usuario (layer 10)
	_canvas_layer_blur.layer = 1
	_canvas_layer_blur.visible = false

	_color_rect_blur = ColorRect.new()
	_color_rect_blur.name = "ColorRectBlur"
	_color_rect_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_rect_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if material_desenfoque_custom:
		_mat_blur = material_desenfoque_custom
	else:
		_mat_blur = ShaderMaterial.new()
		if ResourceLoader.exists("res://shaders/desenfoque_movimiento.gdshader"):
			_mat_blur.shader = load("res://shaders/desenfoque_movimiento.gdshader")
		else:
			var sh := Shader.new()
			sh.code = _CODIGO_SHADER_DESENFOQUE
			_mat_blur.shader = sh

	_color_rect_blur.material = _mat_blur
	_canvas_layer_blur.add_child(_color_rect_blur)
	add_child(_canvas_layer_blur)

func _actualizar_efecto_desenfoque(delta: float) -> void:
	if not desenfoque_movimiento_activo or delta <= 0.0:
		if is_instance_valid(_canvas_layer_blur) and _canvas_layer_blur.visible:
			_canvas_layer_blur.visible = false
		_intensidad_blur_actual = 0.0
		_prev_rotacion_cam = rotation
		return

	if not current:
		if is_instance_valid(_canvas_layer_blur) and _canvas_layer_blur.visible:
			_canvas_layer_blur.visible = false
		_intensidad_blur_actual = 0.0
		_era_current = false
		_prev_rotacion_cam = rotation
		return

	if not _era_current:
		_era_current = true
		_prev_rotacion_cam = rotation

	if not is_instance_valid(_canvas_layer_blur):
		_inicializar_efecto_desenfoque()

	# Calcular desplazamiento angular entre frames
	var diff_y: float = wrapf(rotation.y - _prev_rotacion_cam.y, -PI, PI)
	var diff_x: float = wrapf(rotation.x - _prev_rotacion_cam.x, -PI, PI)
	_prev_rotacion_cam = rotation

	var vel_ang_rad: float = Vector2(diff_y, diff_x).length() / delta
	var vel_ang_deg: float = rad_to_deg(vel_ang_rad)

	var target_intensidad: float = 0.0
	var dir_blur := Vector2.ZERO

	if vel_ang_deg > umbral_velocidad_desenfoque:
		var exceso: float = clampf((vel_ang_deg - umbral_velocidad_desenfoque) / 250.0, 0.0, 1.0)
		target_intensidad = exceso * intensidad_desenfoque
		# La estela de desenfoque va en la dirección del movimiento en pantalla
		dir_blur = Vector2(-diff_y, diff_x).normalized()

	var smooth_t: float = 1.0 - exp(-suavizado_desenfoque * delta)
	_intensidad_blur_actual = lerpf(_intensidad_blur_actual, target_intensidad, smooth_t)

	if _intensidad_blur_actual > 0.005:
		if is_instance_valid(_canvas_layer_blur) and not _canvas_layer_blur.visible:
			_canvas_layer_blur.visible = true
		if is_instance_valid(_mat_blur):
			if dir_blur != Vector2.ZERO:
				_dir_blur_actual = _dir_blur_actual.lerp(dir_blur, 0.4).normalized()
			_mat_blur.set_shader_parameter("direccion", _dir_blur_actual)
			_mat_blur.set_shader_parameter("intensidad", _intensidad_blur_actual)
			_mat_blur.set_shader_parameter("muestras", muestras_desenfoque)
	else:
		if is_instance_valid(_canvas_layer_blur) and _canvas_layer_blur.visible:
			_canvas_layer_blur.visible = false

func _exit_tree() -> void:
	if is_instance_valid(_canvas_layer_blur):
		_canvas_layer_blur.queue_free()
		_canvas_layer_blur = null

