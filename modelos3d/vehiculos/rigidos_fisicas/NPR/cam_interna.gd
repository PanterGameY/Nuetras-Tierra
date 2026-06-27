# cam_interna.gd
# Cámara en primera persona para el conductor (Mouse Libre).
extends Camera3D

# ─────────────────────────────────────────────────────────────
#  EXPORTADAS
# ─────────────────────────────────────────────────────────────
@export_group("Referencias")
@export var controlador_chasis: Node3D
@export var motor_nodo: NodePath

@export_group("Límites de Mirada")
@export var sensibilidad: float = 0.14
@export var limite_v: Vector2 = Vector2(-65.0,  65.0)
@export var limite_h: Vector2 = Vector2(-145.0, 145.0)
@export var auto_centrado_fuerza: float = 4.0

@export_group("Asomarse por Ventana")
@export var angulo_asomarse: float   = 95.0
@export var distancia_asomada: float = 0.4

@export_group("Efectos Dinámicos")
@export var intensidad_vibracion: float        = 0.001
@export var look_ahead_curvas: float           = 0.0
@export var intensidad_g: float                = 0.0
@export var suavizado_g: float                 = 12.0
@export var anticipacion_direccion_deg: float  = 0.5
@export var anticipacion_volante_mult: float   = 0.5
@export var anticipacion_ruedas_mult: float    = 0.3
@export var anticipacion_suavizado: float      = 4.0
@export var altura_aceleracion: float          = 0.0
@export var debug: bool = false

@export_group("Realismo Camara")
@export var fov_base: float = 95.0
@export var fov_max: float = 115.0
@export var fov_velocidad_factor: float = 0.35
@export var intensidad_pitch_aceleracion: float = 2.5
@export var suavizado_pitch: float = 4.0
@export var intensidad_roll_giro: float = 1.8
@export var suavizado_roll: float = 3.5
@export var vibracion_rpm_min: float = 0.003
@export var vibracion_rpm_max: float = 0.018

# ─────────────────────────────────────────────────────────────
#  ESTADO INTERNO
# ─────────────────────────────────────────────────────────────
var rot_x: float = 0.0
var rot_y: float = 0.0
var _vel_previa: Vector3 = Vector3.ZERO
var _pos_original: Vector3
var _tiempo_sin_mouse: float = 0.0
var _offset_cabeza: Vector3 = Vector3.ZERO
var _yaw_anticipation_current: float = 0.0
var _pitch_dinamico: float = 0.0
var _roll_dinamico: float = 0.0

@onready var coche: RigidBody3D = get_owner()
var _motor_nodo_ref: Node
var _camera_manager_ref: Node = null
@export var force_make_current_when_active: bool = true
@export var clear_external_on_activate: bool = true

func _find_coche_owner() -> RigidBody3D:
	var cand = get_owner()
	if cand and cand is RigidBody3D:
		return cand
	var p = get_parent()
	while p:
		if p is RigidBody3D:
			return p
		p = p.get_parent()
	return null

func _find_camera_manager() -> Node:
	var p = get_parent()
	while p:
		if p.has_method("seleccionar_camara") or p.has_method("alternar_camara") or p.has_method("clear_external_camera"):
			return p
		p = p.get_parent()
	return null

# ─────────────────────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_pos_original = position
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if motor_nodo:
		_motor_nodo_ref = get_node_or_null(motor_nodo)

	# Asegurar referencia al RigidBody3D del coche (owner o padre)
	if not coche:
		coche = _find_coche_owner()
		if not coche:
			push_warning("cam_interna.gd: no pude encontrar un RigidBody3D padre/owner para la cámara")

	# Asegurar un FOV inicial razonable
	fov = clamp(fov if fov > 0.0 else 72.0, 40.0, 95.0)

	if debug:
		print("[cam_interna] ready: initial_fov=", fov, " owner=", get_owner(), " coche=", coche)

	# Localizar el CameraManager padre (si existe)
	_camera_manager_ref = _find_camera_manager()
	if debug:
		print("[cam_interna] camera_manager_ref=", _camera_manager_ref)

	# Asegurar que el nodo procese física si queremos forzar estado
	set_physics_process(true)

# ─────────────────────────────────────────────────────────────
#  ENTRADA DE ROTACIÓN (señal desde ZonaCamara)
# ─────────────────────────────────────────────────────────────
func _manejar_rotacion_libre(relative: Vector2) -> void:
	_tiempo_sin_mouse = 0.0
	rot_y -= relative.x * sensibilidad
	rot_x -= relative.y * sensibilidad
	rot_x = clamp(rot_x, limite_v.x,  limite_v.y)
	rot_y = clamp(rot_y, limite_h.x, limite_h.y)

# ─────────────────────────────────────────────────────────────
#  CENTRADO SUAVE
# ─────────────────────────────────────────────────────────────
func centrar_camara(duracion: float = 0.5) -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rot_y", 0.0, duracion)
	t.tween_property(self, "rot_x", 0.0, duracion)
	t.chain().tween_callback(func(): _tiempo_sin_mouse = 0.0)

# ─────────────────────────────────────────────────────────────
#  LOOP PRINCIPAL  →  _physics_process usa compute_local_state
#  para evitar duplicar lógica.
# ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Ejecutar actualización aunque la cámara no sea `current` para
	# mantener FOV/efectos preparados al activarse.
	if not coche:
		return

	var state := compute_local_state(delta)

	# Suavizado de posición: coeficiente conservador para no teletransportar.
	# exp(-k*delta) da una curva independiente del framerate.
	position = position.lerp(state["position"], 1.0 - exp(-30.0 * delta))
	rotation = rotation.lerp(state["rotation"], 1.0 - exp(-20.0 * delta))
	fov      = lerp(fov, state["fov"],           1.0 - exp(-1.5  * delta))

	# Forzar cámara actual y limpiar external target si el vehículo está activo
	var veh_activo := false
	if coche and coche.has_method("get"):
		veh_activo = (coche.get("activo") == true)

	if veh_activo:
		# Determinar si el CameraManager existe y qué cámara tiene seleccionada.
		var manager_idx: int = -1
		if _camera_manager_ref:
			if typeof(_camera_manager_ref.indice_actual) != TYPE_NIL:
				manager_idx = int(_camera_manager_ref.indice_actual)

		# Forzar current SOLO si no hay CameraManager o si el manager indica
		# que la cámara interna (índice 1) está seleccionada.
		var should_force_current: bool = force_make_current_when_active and (manager_idx == -1 or manager_idx == 1)
		if should_force_current:
			if not current:
				make_current()

		# Limpiar objetivo externo SOLO si el CameraManager no tiene la cámara
		# externa seleccionada (evitar borrar external target cuando está activo).
		if clear_external_on_activate and _camera_manager_ref and _camera_manager_ref.has_method("clear_external_camera"):
			if manager_idx != 0:
				_camera_manager_ref.clear_external_camera()



# ─────────────────────────────────────────────────────────────
#  CÁLCULO DE ESTADO  (sin efectos secundarios visibles,
#  excepto los que deben persistir entre frames: _vel_previa,
#  _offset_cabeza, _yaw_anticipation_current, _tiempo_sin_mouse)
# ─────────────────────────────────────────────────────────────
func compute_local_state(delta: float) -> Dictionary:
	var result := {
		"position": position,
		"rotation": rotation,
		"fov": fov
	}

	if not coche or delta <= 0.0:
		return result

	# ── AUTO-CENTRADO ────────────────────────────────────────
	_tiempo_sin_mouse += delta
	if _tiempo_sin_mouse > 1.8:
		rot_y = lerp(rot_y, 0.0, delta * auto_centrado_fuerza)
		rot_x = lerp(rot_x, 0.0, delta * auto_centrado_fuerza * 0.5)

	# ── BASIS INVERSA (reutilizada) ──────────────────────────
	var inv_basis: Basis = coche.global_transform.basis.inverse()

	# ── FUERZAS G ────────────────────────────────────────────
	var acc_local: Vector3 = inv_basis * ((coche.linear_velocity - _vel_previa) / delta)
	_vel_previa = coche.linear_velocity

	var rise_accel: float = clamp(-acc_local.z * altura_aceleracion * 0.004, -0.08, 0.08)
	var target_offset := Vector3(
		-acc_local.x * 0.0008 * intensidad_g,
		-abs(acc_local.x) * 0.0004 + rise_accel,
		 acc_local.z * 0.0012 * intensidad_g
	)
	_offset_cabeza = _offset_cabeza.lerp(target_offset, delta * suavizado_g)

	# ── VIBRACIÓN DE MOTOR ───────────────────────────────────
	var pitch_actual: float = _obtener_pitch_motor()
	var factor_vib: float = clamp(
		pitch_actual * 0.08 + coche.linear_velocity.length() * 0.005, 0.0, 1.0
	)
	var vibracion := Vector3(
		randf_range(-intensidad_vibracion, intensidad_vibracion) * factor_vib,
		randf_range(-intensidad_vibracion, intensidad_vibracion) * factor_vib,
		0.0
	)

	# ── POSICIÓN (asomarse por ventana) ──────────────────────
	var target_pos: Vector3 = _pos_original + _offset_cabeza + vibracion
	target_pos = _aplicar_asomarse(target_pos)

	# ── ROTACIÓN ─────────────────────────────────────────────
	var rot_final: Vector3 = _calcular_rotacion(delta, inv_basis)

	# ── FOV DINÁMICO (más realista, aumenta con velocidad) ──
	var kmh: float = coche.linear_velocity.length() * 3.6
	var target_fov: float = fov_base + clamp(kmh * fov_velocidad_factor, 0.0, fov_max - fov_base)
	target_fov = clamp(target_fov, 60.0, fov_max)

	# ── INPUT DIRECCIÓN (para roll y otras cosas) ──
	var dir_input: float = 0.0
	if is_instance_valid(InputVehiculo):
		dir_input = InputVehiculo.direccion

	# ── PITCH DINÁMICO (cabeza se inclina al acelerar/frenar) ──
	var acc_local_z: float = acc_local.z
	var target_pitch: float = clamp(acc_local_z * intensidad_pitch_aceleracion * 0.01, -3.0, 3.0)
	_pitch_dinamico = lerp(_pitch_dinamico, target_pitch, delta * suavizado_pitch)

	# ── ROLL DINÁMICO (balanceo lateral al girar) ──
	var vel_local: Vector3 = inv_basis * coche.linear_velocity
	var giro_factor: float = -vel_local.x * intensidad_roll_giro * 0.02
	var target_roll: float = clamp(giro_factor + (dir_input * intensidad_roll_giro * 0.3), -4.0, 4.0)
	_roll_dinamico = lerp(_roll_dinamico, target_roll, delta * suavizado_roll)

	rot_final.x += deg_to_rad(_pitch_dinamico)
	rot_final.z += deg_to_rad(_roll_dinamico)

	# ── VIBRACIÓN POR RPM ──
	var motor_on: bool = is_instance_valid(InputVehiculo) and InputVehiculo.get("motor_encendido") == true
	var rpm_factor: float = _obtener_rpm_normalizado()
	var vib_rpm: float = lerp(vibracion_rpm_min, vibracion_rpm_max, rpm_factor)
	if motor_on:
		vibracion.x += randf_range(-vib_rpm, vib_rpm)
		vibracion.y += randf_range(-vib_rpm, vib_rpm)

	result["position"] = target_pos + vibracion
	result["rotation"] = rot_final
	result["fov"]      = target_fov
	return result

# ─────────────────────────────────────────────────────────────
#  HELPERS PRIVADOS
# ─────────────────────────────────────────────────────────────

func _obtener_pitch_motor() -> float:
	if not _motor_nodo_ref:
		return 1.0
	for hijo in _motor_nodo_ref.get_children():
		if hijo is AudioStreamPlayer3D:
			return hijo.pitch_scale
	return 1.0

func _obtener_rpm_normalizado() -> float:
	if not _motor_nodo_ref:
		return 0.0
	if _motor_nodo_ref.get("rpm_motor") != null:
		var rpm: float = float(_motor_nodo_ref.get("rpm_motor"))
		var rpm_max: float = 3000.0
		if _motor_nodo_ref.get("config") != null:
			var cfg = _motor_nodo_ref.get("config")
			if cfg and cfg.get("rpm_maximas"):
				rpm_max = float(cfg.rpm_maximas)
		return clamp(rpm / rpm_max, 0.0, 1.0)
	return 0.0


func _aplicar_asomarse(pos: Vector3) -> Vector3:
	if rot_y > angulo_asomarse:
		var f: float = clamp((rot_y - angulo_asomarse) / 45.0, 0.0, 1.0)
		pos.x -= distancia_asomada * f
		pos.z += distancia_asomada * 0.25 * f
	elif rot_y < -angulo_asomarse:
		var f: float = clamp((-rot_y - angulo_asomarse) / 45.0, 0.0, 1.0)
		pos.x += distancia_asomada * f
		pos.z += distancia_asomada * 0.25 * f
	return pos


func _calcular_rotacion(delta: float, inv_basis: Basis) -> Vector3:
	# Look-ahead por velocidad angular del coche
	var angular_local: Vector3 = inv_basis * coche.angular_velocity
	var rot_obj_y: float = rot_y - angular_local.y * rad_to_deg(look_ahead_curvas)

	# Anticipación combinada volante + ruedas
	var dir_input: float = 0.0
	if is_instance_valid(InputVehiculo):
		dir_input = InputVehiculo.direccion

	var ctrl = coche.get_node_or_null("ControladorLlantas")
	var wheel_angle_avg_rad: float = _angulo_medio_ruedas(ctrl)
	var volante_frac: float = abs(dir_input)
	var wheel_frac: float = 0.0
	if ctrl:
		var ang_max: float = float(ctrl.angulo_max_giro)
		if ang_max > 0.0001:
			wheel_frac = clamp(abs(wheel_angle_avg_rad) / ang_max, 0.0, 1.0)

	var anticipation_scale: float = max(
		volante_frac * anticipacion_volante_mult,
		wheel_frac   * anticipacion_ruedas_mult
	)
	var yaw_target: float = dir_input * anticipacion_direccion_deg * anticipation_scale
	_yaw_anticipation_current = lerp(
		_yaw_anticipation_current, yaw_target,
		clamp(anticipacion_suavizado * delta, 0.0, 1.0)
	)
	rot_obj_y -= _yaw_anticipation_current

	var rot_final := Vector3(deg_to_rad(rot_x), deg_to_rad(rot_obj_y), 0.0)

	# Balanceo del chasis
	if controlador_chasis:
		var bal: Vector3 = controlador_chasis.rotation
		rot_final.z = -bal.z * 0.55
		rot_final.x -= bal.x * 0.25

	return rot_final


func _angulo_medio_ruedas(ctrl) -> float:
	if not ctrl:
		return 0.0
	var total: float = 0.0
	var count: int   = 0
	var lista = ctrl.llantas_directrices if (ctrl.llantas_directrices and ctrl.llantas_directrices.size() > 0) \
				else ctrl.get_children()
	for l in lista:
		if is_instance_valid(l) and (not (l is Node) or l.get("angulo_direccion") != null):
			total += l.angulo_direccion
			count += 1
	return total / count if count > 0 else 0.0
