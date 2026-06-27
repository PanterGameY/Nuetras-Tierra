extends RayCast3D
class_name RuedaTrailer

@export var debug_raycast: bool = false

# ════════════════════════════════════════════════════════════════════
# FÍSICA SIMPLIFICADA PARA REMOLQUES
# ════════════════════════════════════════════════════════════════════

@export_group("Suspensión")
@export var largo_reposo: float = 0.28
@export var radio_rueda: float = 0.55
@export var rigidez_muelle: float = 170000.0
@export var amortiguacion: float = 21000.0
@export var fuerza_suspension_max: float = 300000.0

@export_group("Fricción Lateral")
@export var agarre_lateral: float = 15.0
@export var respuesta_lateral: float = 600.0

var coche: RigidBody3D
@export_group("Visuales")
@export var rueda_visual: Node3D
var rotacion_visual_base: Quaternion = Quaternion.IDENTITY
var angulo_rodado_visual: float = 0.0

func _ready() -> void:
	coche = _buscar_coche(get_parent())
	if coche:
		add_exception(coche)

	if not rueda_visual and get_child_count() > 0:
		rueda_visual = get_child(0)
	if rueda_visual:
		rotacion_visual_base = rueda_visual.quaternion

	target_position = Vector3(0, -(largo_reposo + radio_rueda), 0)
	enabled = true
	if (int(collision_mask) & 1) == 0:
		collision_mask = int(collision_mask) | 1

	force_raycast_update()
	if debug_raycast:
		print("RuedaTrailer ready: ", name, " | mask=", collision_mask, " | cast_to=", target_position)

func _physics_process(delta: float) -> void:
	force_raycast_update()

	# Los visuales se actualizan siempre (suspensión + giro)
	_actualizar_visual(delta)

	if not coche:
		return
	if not is_colliding():
		return

	_aplicar_fisica_remolque()

func _aplicar_fisica_remolque() -> void:
	# No aplicar fuerzas si el cuerpo está congelado o durmiendo.
	# En Godot 4, apply_force despierta/descongela un RigidBody,
	# anulando la protección del freeze=true en carpado1.
	if coche.freeze or coche.sleeping:
		return
	var punto_contacto: Vector3 = get_collision_point()
	var centro_masa: Vector3   = coche.global_position + coche.global_transform.basis * coche.center_of_mass
	var radio_vec: Vector3     = punto_contacto - centro_masa

	var basis_ortho: Basis = coche.global_transform.basis.orthonormalized()
	var up: Vector3    = basis_ortho.y
	var right: Vector3 = basis_ortho.x
	var forward: Vector3 = -basis_ortho.z

	# — Suspensión —
	var distancia: float   = global_position.distance_to(punto_contacto)
	var compresion: float  = clamp(largo_reposo - (distancia - radio_rueda), 0.0, largo_reposo)

	var vel_punto: Vector3  = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
	var vel_vertical: float = up.dot(vel_punto)

	var f_suspension: float = (compresion * rigidez_muelle) - (vel_vertical * amortiguacion)
	f_suspension = clamp(f_suspension, 0.0, fuerza_suspension_max)

	coche.apply_force(up * f_suspension, radio_vec)

	# — Fricción lateral —
	var vel_lateral: float = right.dot(vel_punto)
	var f_lateral: float   = -vel_lateral * respuesta_lateral * (f_suspension / 1000.0)
	var limite_lat: float  = f_suspension * agarre_lateral
	f_lateral = clamp(f_lateral, -limite_lat, limite_lat)

	coche.apply_force(right * f_lateral, radio_vec)

	# — Fricción longitudinal / Frenos —
	var vel_forward: float = forward.dot(vel_punto)
	var freno_activo: bool = true
	if coche.has_method("esta_enganchado"):
		freno_activo = not coche.esta_enganchado()
	elif coche.get("_cuerpo_camion") != null:
		freno_activo = false
	var fuerza_traccion: float = 0.0
	var atenuacion_baja_vel: float = clamp(abs(vel_forward) / 0.1, 0.0, 1.0)
	
	if freno_activo:
		var fuerza_freno_total: float = 20000.0
		var limite_freno: float = f_suspension * 8.0
		fuerza_traccion = -sign(vel_forward) * min(fuerza_freno_total, limite_freno) * atenuacion_baja_vel
		
		# Agregar peso virtual descendente en las ruedas del trailer para mantenerlas en el suelo y evitar que el trailer cabecee hacia adelante
		var fuerza_peso_rueda: Vector3 = Vector3.DOWN * (coche.mass * 9.81 / 6.0) * 0.75
		coche.apply_force(fuerza_peso_rueda, radio_vec)
	else:
		var resistencia_rodadura: float = 25.0
		fuerza_traccion = -sign(vel_forward) * min(abs(vel_forward) * resistencia_rodadura, f_suspension * 8.0) * atenuacion_baja_vel

	coche.apply_force(forward * fuerza_traccion, radio_vec)

func _actualizar_visual(delta: float) -> void:
	if not rueda_visual:
		return

	# — Posición de la suspensión (viaje del muelle) —
	var ty: float
	if is_colliding():
		# Centro de rueda = punto de contacto + radio hacia arriba (en espacio local)
		ty = to_local(get_collision_point()).y + radio_rueda
	else:
		# Suspensión extendida al máximo: eje de rueda a -largo_reposo del punto de anclaje
		ty = -largo_reposo

	rueda_visual.position.y = lerp(rueda_visual.position.y, ty, delta * 15.0)

	# — Rotación por movimiento —
	# Usa la velocidad del cuerpo padre proyectada sobre su eje de avance.
	# Funciona tanto en el suelo como en el aire.
	var velocidad_avance: float = 0.0
	if coche:
		var forward: Vector3 = -coche.global_transform.basis.orthonormalized().z
		# Si está en el suelo, usamos la velocidad en el punto de contacto (más precisa)
		if is_colliding():
			var centro_masa: Vector3 = coche.global_position + coche.global_transform.basis * coche.center_of_mass
			var radio_vec: Vector3   = get_collision_point() - centro_masa
			var vel_punto: Vector3   = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
			velocidad_avance = forward.dot(vel_punto)
		else:
			velocidad_avance = forward.dot(coche.linear_velocity)

	angulo_rodado_visual -= (velocidad_avance * delta) / max(radio_rueda, 0.01)
	angulo_rodado_visual  = wrapf(angulo_rodado_visual, -PI, PI)

	rueda_visual.quaternion = rotacion_visual_base * Quaternion(Vector3.RIGHT, angulo_rodado_visual)

func configurar_desde_masa(masa_total: float, num_ruedas: int) -> void:
	var peso_por_rueda: float = masa_total * 9.81 / max(num_ruedas, 1)
	var compresion_repo: float = 0.5
	largo_reposo = 0.30
	rigidez_muelle = peso_por_rueda / (compresion_repo * largo_reposo)
	amortiguacion = rigidez_muelle * 0.08
	fuerza_suspension_max = peso_por_rueda * 4.0
	target_position = Vector3(0, -(largo_reposo + radio_rueda), 0)
	if debug_raycast:
		print("RuedaTrailer configurada: masa=", masa_total, " ruedas=", num_ruedas,
			" rigidez=", rigidez_muelle, " amort=", amortiguacion,
			" fmax=", fuerza_suspension_max, " target=", target_position)

func _buscar_coche(n: Node) -> RigidBody3D:
	if n == null:
		return null
	if n is RigidBody3D:
		return n as RigidBody3D
	return _buscar_coche(n.get_parent())