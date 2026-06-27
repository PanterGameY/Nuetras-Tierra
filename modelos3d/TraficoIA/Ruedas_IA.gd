# Script para controlar las ruedas del vehículo IA y simular suspensión simple.
# No depende de llanta.gd ni de InputVehiculo — funciona de forma autónoma.

extends Node3D

# ── Definición de ruedas ──────────────────────────────────────────────────────
@export var ruedas_traccion: Array[Node3D] = []
@export var ruedas_direccion: Array[Node3D] = []

# ── Giro visual de ruedas delanteras ─────────────────────────────────────────
@export var angulo_giro: float = 30.0
@export var suavizado_giro: float = 5.0
@export var suavizado_retorno: float = 8.0
@export var velocidad_retorno: float = 5.0
@export var direccion_giro: Vector3 = Vector3(0, 1, 0)
## Distancia entre ejes del vehículo (metros). Camión Cascadia ≈ 4.5
@export var distancia_ejes: float = 4.5

# ── Rodadura de ruedas ────────────────────────────────────────────────────────
## Eje local alrededor del cual gira la rueda al avanzar.
## Si las ruedas giran al revés, invierte el signo: Vector3(-1, 0, 0).
@export var eje_rodadura: Vector3 = Vector3(1, 0, 0)
## Factor de amplificación del ángulo de dirección.
## Con el modelo bicicleta el ángulo ya es físicamente correcto; deja en 1.0.
## Solo sube si ves que las ruedas giran poco visualmente.
@export var multiplicador_steering: float = 1.0
@export var steer_fallback_node: NodePath = NodePath("")
@export var steer_fallback_multiplier: float = 1.0

# ── Cabeceo ────────────────────────────────────────────────────────────────────
## NodePath al nodo visual raíz del modelo (ej. truck0). Si está vacío, se busca automáticamente.
@export var nodo_visual_path: NodePath = NodePath("")
## Máximo ángulo de cabeceo en grados al acelerar (nose up = positivo).
@export var cabeceo_aceleracion_deg: float = 4.0
## Máximo ángulo de cabeceo en grados al frenar (nose down = negativo).
@export var cabeceo_frenada_deg: float = 6.0
## Aceleración máxima de referencia (m/s²) para normalizar el cabeceo.
@export var cabeceo_accel_ref: float = 3.0
## Velocidad de suavizado del cabeceo (mayor = más rápido).
@export var cabeceo_suavizado: float = 4.0
## Cuánto del cabeceo se basa en la aceleración real (0 = solo suspensión, 1 = mitad y mitad).
@export_range(0.0, 1.0, 0.05) var cabeceo_accel_blend: float = 0.6
## Máximo ángulo de balanceo lateral en grados en curva (carrocería se inclina al exterior).
@export var balanceo_max_deg: float = 5.0
## Aceleración lateral de referencia (m/s²) para el 100% del balanceo. ≈3-5 para camión.
@export var balanceo_accel_ref: float = 4.0
## Velocidad de suavizado del balanceo (mayor = más rápido).
@export var balanceo_suavizado: float = 2.5

# ── Suspensión IA ─────────────────────────────────────────────────────────────
## Activa la creación automática de rayos de suspensión en _ready().
@export var auto_agregar_llanta: bool = true
## Radio del neumático en metros. Cascadia ≈ 0.52.
@export var llanta_radio_rueda: float = 0.52
## Recorrido de suspensión en reposo (m). Camión ≈ 0.38.
@export var llanta_largo_reposo: float = 0.38
## Margen extra del rayo para no perder contacto. Aumentar si sigue hundiéndose.
@export var llanta_extra_largo_rayo: float = 0.25
## Si es true, calcula rigidez/amortiguación automáticamente desde la masa del vehículo.
## Desactivar solo si quieres controlar los valores manualmente.
@export var llanta_auto_rigidez: bool = true
## Rigidez del muelle (N/m). Solo se usa si llanta_auto_rigidez = false.
@export var llanta_rigidez_muelle: float = 50000.0
## Amortiguación (N·s/m). Solo se usa si llanta_auto_rigidez = false.
@export var llanta_amortiguacion: float = 8000.0
## Fuerza máxima de suspensión por rueda (N). Solo se usa si llanta_auto_rigidez = false.
@export var llanta_fuerza_suspension_max: float = 100000.0
## --- Balanceo de suspensión en curvas -------------------------------------
## Fuerza con la que la suspensión exterior se refuerza en curvas (0-1.5).
@export var suspension_balance_strength: float = 0.6
## Aceleración lateral de referencia (m/s²) que representa 100% de efecto.
@export var suspension_balance_accel_ref: float = 4.0

# ── Estado interno ────────────────────────────────────────────────────────────
var coche: RigidBody3D = null
var _rayos: Array = []          # Array de RayCast3D creados
var _rot_ruedas: float = 0.0    # Acumulador de rotación de rodadura (radianes)
var _angulo_steering_actual: float = 0.0  # Ángulo de dirección actual suavizado (radianes)
var _vel_anterior: float = 0.0  # Velocidad del frame anterior para calcular aceleración
var _vel_lateral_anterior: float = 0.0 # Velocidad lateral anterior (m/s)
var _lat_acc: float = 0.0      # Aceleración lateral actual (m/s²)
var _cabeceo_actual: float = 0.0  # Ángulo de cabeceo visual actual (radianes)
var _balanceo_actual: float = 0.0 # Ángulo de balanceo lateral visual actual (radianes)
var _nodo_visual: Node3D = null   # truck0 u otro nodo visual raíz
var _orig_basis: Dictionary = {}  # instance_id -> Basis (rotation-only)
var _orig_transform: Dictionary = {} # instance_id -> Transform3D (original local transform)
var _susp_pitch_target: float = 0.0
var _susp_roll_target: float = 0.0
var _susp_avg_comp: float = 0.0
var _phys_vel_prev: float = 0.0   # velocidad longitudinal del frame físico anterior (para aceleración)
var _steer_fallback_node: Node3D = null

# ─────────────────────────────────────────────────────────────────────────────

func _apply_basis_preserve_scale(node: Node3D, delta_basis: Basis, offset_local: Vector3 = Vector3(0,0,0)) -> void:
	if not is_instance_valid(node):
		return
	var prev_scale: Vector3 = node.scale
	var id: int = node.get_instance_id()
	var orig_rot: Basis = node.transform.basis.orthonormalized()
	var orig_tr: Transform3D = node.transform
	if _orig_basis.has(id):
		orig_rot = _orig_basis[id]
	else:
		_orig_basis[id] = orig_rot
	if _orig_transform.has(id):
		orig_tr = _orig_transform[id]
	else:
		_orig_transform[id] = node.transform

	# Aplicar rotación relativa sobre la base original y preservar scale y posición local (origin)
	var final_basis: Basis = orig_rot * delta_basis
	var final_origin: Vector3 = orig_tr.origin + offset_local
	node.transform = Transform3D(final_basis, final_origin)
	node.scale = prev_scale

func _record_orig_basis(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var id: int = node.get_instance_id()
	if not _orig_basis.has(id):
		_orig_basis[id] = node.transform.basis.orthonormalized()
	if not _orig_transform.has(id):
		_orig_transform[id] = node.transform


func _ready() -> void:
	# No forzamos la rotación inicial de las ruedas desde código: respetar la rotación del editor
	# (registramos las bases originales más abajo para aplicar deltas sobre la orientación en escena)

	# Buscar RigidBody3D ancestro — SIEMPRE, independientemente de auto_agregar_llanta
	var n: Node = self
	while n != null:
		if n is RigidBody3D:
			coche = n as RigidBody3D
			break
		n = n.get_parent()

	if not coche:
		push_warning("Ruedas_IA: no se encontró RigidBody3D ancestro.")
		return

	if auto_agregar_llanta:
		call_deferred("_setup_rayos")

	# Buscar nodo visual (truck0)
	if nodo_visual_path and str(nodo_visual_path) != "":
		_nodo_visual = get_node_or_null(nodo_visual_path) as Node3D
	if not _nodo_visual:
		# Buscar primer hijo Node3D del coche que no sea CollisionShape ni RayCast
		for child in coche.get_children():
			if child is Node3D and not (child is CollisionShape3D) and not (child is RayCast3D):
				_nodo_visual = child as Node3D
				break

	# Registrar bases originales (rotación) para respetar rotación local al aplicar deltas
	if is_instance_valid(_nodo_visual):
		_record_orig_basis(_nodo_visual)
	for r in ruedas_traccion:
		if is_instance_valid(r):
			_record_orig_basis(r)
	for r in ruedas_direccion:
		if is_instance_valid(r) and not _orig_basis.has(r.get_instance_id()):
			_record_orig_basis(r)

	# Configurar nodo fallback para steering si se exportó uno
	if steer_fallback_node and str(steer_fallback_node) != "":
		_steer_fallback_node = get_node_or_null(steer_fallback_node) as Node3D
		if is_instance_valid(_steer_fallback_node):
			_record_orig_basis(_steer_fallback_node)

func _setup_rayos() -> void:
	if not is_instance_valid(coche):
		return

	# Reunir ruedas a procesar
	var ruedas_a_procesar: Array = []
	ruedas_a_procesar.append_array(ruedas_traccion)
	for r in ruedas_direccion:
		if not ruedas_a_procesar.has(r):
			ruedas_a_procesar.append(r)
	if ruedas_a_procesar.is_empty():
		ruedas_a_procesar = _detectar_ruedas_automaticas()

	if ruedas_a_procesar.is_empty():
		push_warning("Ruedas_IA: no se encontraron ruedas para la suspensión.")
		return

	# Registrar bases originales para ruedas detectadas automáticamente
	for r in ruedas_a_procesar:
		if is_instance_valid(r):
			_record_orig_basis(r)

	# ── Auto-cálculo de parámetros de suspensión desde la masa real ───────────
	if llanta_auto_rigidez:
		var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		var n_ruedas: int = ruedas_a_procesar.size()
		# Fuerza estática por rueda para sostener el vehículo en reposo
		var peso_por_rueda: float = coche.mass * gravedad / float(n_ruedas)
		# Target: el muelle se comprime ~30% del largo_reposo en reposo normal
		var compresion_objetivo: float = llanta_largo_reposo * 0.3
		llanta_rigidez_muelle       = peso_por_rueda / compresion_objetivo
		# Amortiguación crítica × 0.4 (subamortiguado: rebota levemente pero no vuela)
		llanta_amortiguacion        = 2.0 * sqrt(llanta_rigidez_muelle * (coche.mass / float(n_ruedas))) * 0.4
		# Fuerza máx = 4× el peso estático por rueda
		llanta_fuerza_suspension_max = peso_por_rueda * 4.0

	var ray_len: float = llanta_largo_reposo + llanta_radio_rueda + llanta_extra_largo_rayo
	var up: Vector3 = coche.global_transform.basis.y.normalized()

	for rueda in ruedas_a_procesar:
		if not is_instance_valid(rueda):
			continue

		var ray_name := "SuspRay_" + str(rueda.name)

		# Reusar si ya existe
		var existente = coche.get_node_or_null(ray_name)
		if is_instance_valid(existente) and existente is RayCast3D:
			_rayos.append(existente)
			continue

		var ray := RayCast3D.new()
		ray.name = ray_name
		ray.target_position = Vector3(0.0, -ray_len, 0.0)
		ray.enabled = true
		ray.exclude_parent = true

		coche.add_child(ray)
		ray.add_exception(coche)

		# Pivote encima del centro de la rueda (largo_reposo más arriba)
		ray.global_position = rueda.global_position + up * llanta_largo_reposo

		_rayos.append(ray)

func _process(delta: float) -> void:
	if not is_instance_valid(coche):
		return

	# ── Cálculo del ángulo de dirección desde TraficoAI ─────────────────────
	var forward_local: Vector3 = -coche.global_transform.basis.z
	var max_rad: float  = deg_to_rad(angulo_giro)
	var target_steering: float = 0.0
	var angulo_ia = coche.get("angulo_ruedas")
	if angulo_ia != null:
		target_steering = clamp(float(angulo_ia) * multiplicador_steering, -max_rad, max_rad)
	_angulo_steering_actual = lerp(_angulo_steering_actual, target_steering,
			clamp(suavizado_giro * delta, 0.0, 1.0))

	# ── Cabeceo + Balanceo lateral: pitch X + roll Z sobre el nodo visual ──────
	if is_instance_valid(_nodo_visual):
		var vel_actual: float = coche.linear_velocity.dot(forward_local)
		var _aceleracion: float = (vel_actual - _vel_anterior) / max(delta, 0.001)
		_vel_anterior = vel_actual

		# calcular velocidad lateral y aceleración lateral para balanceo de suspensión
		var right_local: Vector3 = coche.global_transform.basis.x
		var vel_lateral: float = coche.linear_velocity.dot(right_local)
		_lat_acc = (vel_lateral - _vel_lateral_anterior) / max(delta, 0.001)
		_vel_lateral_anterior = vel_lateral

		# Usar targets derivados de la suspensión física calculada en _physics_process
		_cabeceo_actual = lerp(_cabeceo_actual, _susp_pitch_target,
				clamp(cabeceo_suavizado * delta, 0.0, 1.0))
		_balanceo_actual = lerp(_balanceo_actual, _susp_roll_target,
				clamp(balanceo_suavizado * delta, 0.0, 1.0))

		# ─ Componer pitch + roll sin Euler: Basis(pitch_X) * Basis(roll_Z) ──────
		var basis_pitch := Basis(Vector3(1, 0, 0), _cabeceo_actual)
		var basis_roll_viz := Basis(Vector3(0, 0, 1), _balanceo_actual)
		# Aplicar también un desplazamiento vertical local basado en la compresión promedio
		var offset_local: Vector3 = Vector3(0.0, -_susp_avg_comp, 0.0)
		_apply_basis_preserve_scale(_nodo_visual, basis_roll_viz * basis_pitch, offset_local)

	# ── Rodadura: rotar todas las ruedas según velocidad del vehículo ────────
	var vel_adelante: float = coche.linear_velocity.dot(forward_local)
	var omega: float = vel_adelante / llanta_radio_rueda
	_rot_ruedas += omega * delta
	var eje: Vector3 = eje_rodadura.normalized()
	# Basis de rodadura (roll): rotar alrededor del eje de rodadura
	var basis_roll := Basis(eje, _rot_ruedas)
	# Vector 'up' para cálculos de offset cuando las ruedas están fuera del nodo visual
	var up: Vector3 = coche.global_transform.basis.y.normalized()

	for rueda in ruedas_traccion:
		if is_instance_valid(rueda):
			# Determinar si, en ausencia de ruedas_direccion, aplicamos steering
			var delta_basis: Basis = basis_roll
			if not _has_valid_ruedas_direccion():
				# comprobar si esta rueda es delantera (z local < 0)
				var local_pos_rueda: Vector3 = coche.to_local(rueda.global_transform.origin)
				var es_delantera: bool = local_pos_rueda.z < 0.0
				if es_delantera:
					var steer_axis: Vector3 = direccion_giro
					if steer_axis == Vector3.ZERO:
						steer_axis = Vector3.UP
					else:
						steer_axis = steer_axis.normalized()
					var basis_steer := Basis(steer_axis, _angulo_steering_actual)
					delta_basis = basis_steer * basis_roll
			var offset_local: Vector3 = Vector3(0.0, 0.0, 0.0)
			# Si la rueda NO está bajo el nodo visual, aplicamos el offset vertical de suspensión
			var p = rueda.get_parent()
			var is_child_of_visual: bool = false
			while p != null:
				if p == _nodo_visual:
					is_child_of_visual = true
					break
				p = p.get_parent()
			if not is_child_of_visual:
				var offset_world = up * -_susp_avg_comp
				var parent = rueda.get_parent()
				if parent:
					var orig_parent_local = parent.to_local(rueda.global_transform.origin)
					var offset_parent_local = parent.to_local(rueda.global_transform.origin + offset_world)
					offset_local = offset_parent_local - orig_parent_local
				else:
					offset_local = Vector3(0.0, -_susp_avg_comp, 0.0)
			_apply_basis_preserve_scale(rueda, delta_basis, offset_local)

	# Fallback: si no hay ruedas_direccion válidas y se proporcionó un nodo de fallback,
	# aplicar solo el giro de dirección a ese nodo para simular el steering visual.
	if not _has_valid_ruedas_direccion() and is_instance_valid(_steer_fallback_node):
		var steer_axis: Vector3 = direccion_giro
		if steer_axis == Vector3.ZERO:
			steer_axis = Vector3.UP
		else:
			steer_axis = steer_axis.normalized()
		var basis_steer := Basis(steer_axis, _angulo_steering_actual * steer_fallback_multiplier)
		_apply_basis_preserve_scale(_steer_fallback_node, basis_steer)

	for rueda in ruedas_direccion:
		if is_instance_valid(rueda):
			# Primero steering (giro en el eje configurado), luego roll encima.
			var steer_axis: Vector3 = direccion_giro
			if steer_axis == Vector3.ZERO:
				steer_axis = Vector3.UP
			else:
				steer_axis = steer_axis.normalized()
			var basis_steer := Basis(steer_axis, _angulo_steering_actual)
			var delta_basis: Basis = basis_steer * basis_roll
			var offset_local: Vector3 = Vector3(0.0, 0.0, 0.0)
			var p = rueda.get_parent()
			var is_child_of_visual: bool = false
			while p != null:
				if p == _nodo_visual:
					is_child_of_visual = true
					break
				p = p.get_parent()
			if not is_child_of_visual:
				var offset_world = up * -_susp_avg_comp
				var parent = rueda.get_parent()
				if parent:
					var orig_parent_local = parent.to_local(rueda.global_transform.origin)
					var offset_parent_local = parent.to_local(rueda.global_transform.origin + offset_world)
					offset_local = offset_parent_local - orig_parent_local
				else:
					offset_local = Vector3(0.0, -_susp_avg_comp, 0.0)
			_apply_basis_preserve_scale(rueda, delta_basis, offset_local)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(coche) or _rayos.is_empty():
		return
	var _delta: float = delta  # alias para compatibilidad con el código existente

	var up: Vector3 = coche.global_transform.basis.y.normalized()
	var full_len: float = llanta_largo_reposo + llanta_radio_rueda

	# Recolectar compresiones por rueda para calcular pitch/roll visual desde suspensión
	var wheel_samples: Array = []
	for ray in _rayos:
		if not is_instance_valid(ray):
			continue

		# Ignorar rayos que aún no están completamente dentro del mundo
		if not ray.is_inside_tree():
			# registrar con compresión 0 pero con posición local conocida
			var local_pos_missing: Vector3 = coche.to_local(ray.global_position)
			wheel_samples.append({"comp": 0.0, "local_pos": local_pos_missing})
			continue

		ray.force_raycast_update()

		var local_pos: Vector3 = coche.to_local(ray.global_position)
		if not ray.is_colliding():
			wheel_samples.append({"comp": 0.0, "local_pos": local_pos})
			continue

		var hit_pos: Vector3 = ray.get_collision_point()
		var dist: float = ray.global_position.distance_to(hit_pos)
		var compresion: float = full_len - dist
		if compresion <= 0.0:
			wheel_samples.append({"comp": 0.0, "local_pos": local_pos})
			continue

		# Velocidad del punto de contacto en la dirección vertical del vehículo
		var radio_vec: Vector3 = ray.global_position - coche.global_position
		var vel_punto: Vector3 = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
		var vel_vertical: float = up.dot(vel_punto)

		# Fuerza de muelle + amortiguador
		var f_muelle: float = compresion * llanta_rigidez_muelle
		var f_amort: float  = -vel_vertical * llanta_amortiguacion
		var f_total: float  = clamp(f_muelle + f_amort, 0.0, llanta_fuerza_suspension_max)

		# ── Ajuste por balanceo lateral: comprimir más la suspensión del lado exterior
		# side: +1 = rueda derecha, -1 = rueda izquierda (en espacio local del coche)
		var side: float = 1.0 if local_pos.x >= 0.0 else -1.0
		var roll_offset: float = clamp(_lat_acc / suspension_balance_accel_ref, -1.0, 1.0)
		var mult: float = clamp(1.0 + side * roll_offset * suspension_balance_strength, 0.4, 1.6)
		f_total = clamp(f_total * mult, 0.0, llanta_fuerza_suspension_max)

		coche.apply_force(up * f_total, radio_vec)
		wheel_samples.append({"comp": compresion, "local_pos": local_pos})

	# Analizar muestras para derivar pitch/roll desde la suspensión
	var front_sum: float = 0.0; var front_count: int = 0; var front_z_sum: float = 0.0
	var rear_sum: float = 0.0; var rear_count: int = 0; var rear_z_sum: float = 0.0
	var left_sum: float = 0.0; var left_count: int = 0; var left_x_sum: float = 0.0
	var right_sum: float = 0.0; var right_count: int = 0; var right_x_sum: float = 0.0
	var total_sum: float = 0.0; var total_count: int = 0
	for s in wheel_samples:
		var comp: float = float(s["comp"])
		var lp: Vector3 = s["local_pos"]
		total_sum += comp; total_count += 1
		if lp.z < 0.0:
			front_sum += comp; front_z_sum += lp.z; front_count += 1
		else:
			rear_sum += comp; rear_z_sum += lp.z; rear_count += 1
		if lp.x >= 0.0:
			right_sum += comp; right_x_sum += lp.x; right_count += 1
		else:
			left_sum += comp; left_x_sum += lp.x; left_count += 1

	var front_avg: float = front_sum / max(front_count, 1)
	var rear_avg: float = rear_sum / max(rear_count, 1)
	var right_avg: float = right_sum / max(right_count, 1)
	var left_avg: float = left_sum / max(left_count, 1)
	_susp_avg_comp = total_sum / max(total_count, 1)

	var front_z_avg: float = front_z_sum / max(front_count, 1)
	var rear_z_avg: float = rear_z_sum / max(rear_count, 1)
	var wheelbase: float = abs(front_z_avg - rear_z_avg)
	if wheelbase < 0.1:
		wheelbase = distancia_ejes

	var right_x_avg: float = right_x_sum / max(right_count, 1)
	var left_x_avg: float = left_x_sum / max(left_count, 1)
	var track_width: float = abs(right_x_avg - left_x_avg)
	if track_width < 0.1:
		track_width = 2.0

	var pitch_target: float = atan2(front_avg - rear_avg, wheelbase)
	var roll_target: float = atan2(right_avg - left_avg, track_width)

	# Limitar magnitudes a los máximos configurados
	var max_cabeceo_deg: float = max(cabeceo_aceleracion_deg, cabeceo_frenada_deg)
	pitch_target = clamp(pitch_target, -deg_to_rad(max_cabeceo_deg), deg_to_rad(max_cabeceo_deg))
	roll_target = clamp(roll_target, -deg_to_rad(balanceo_max_deg), deg_to_rad(balanceo_max_deg))

	# Componente de cabeceo basado en aceleración real del vehículo (más reactivo que la suspensión)
	var fwd_phys: Vector3 = -coche.global_transform.basis.z.normalized()
	var vel_now_phys: float = coche.linear_velocity.dot(fwd_phys)
	var phys_accel: float = (vel_now_phys - _phys_vel_prev) / max(_delta, 0.001)
	_phys_vel_prev = vel_now_phys
	# Frenada: nose-down (ángulo positivo en X), aceleración: nose-up (ángulo negativo en X)
	var accel_pitch: float = clamp(
		-phys_accel * deg_to_rad(cabeceo_frenada_deg) / max(cabeceo_accel_ref, 0.01),
		-deg_to_rad(cabeceo_frenada_deg), deg_to_rad(cabeceo_aceleracion_deg))
	# Mezclar: parte de suspensión + parte de aceleración directa
	_susp_pitch_target = lerp(pitch_target, accel_pitch, cabeceo_accel_blend)
	_susp_roll_target = roll_target

func _detectar_ruedas_automaticas() -> Array:
	var encontrados: Array = []
	if not coche:
		return encontrados
	# 1) Buscar descendientes directos del RigidBody (lo más común)
	var stack: Array = [coche]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
			if c is Node3D:
				var lname: String = c.name.to_lower()
				if "rueda" in lname or "wheel" in lname or "llanta" in lname or "tyre" in lname or "tire" in lname:
					encontrados.append(c)
	# 2) Si no encontramos nada, buscar en toda la escena nodos cercanos que parezcan ruedas
	if encontrados.is_empty():
		var scene = get_tree().get_current_scene()
		if scene:
			var center: Vector3 = coche.global_position
			var max_dist: float = max(distancia_ejes * 2.0, 6.0)
			_search_ruedas_global(scene, encontrados, center, max_dist)
	return encontrados

func _search_ruedas_global(node: Node, result: Array, center: Vector3, max_dist: float) -> void:
	if not node:
		return
	for c in node.get_children():
		if c is Node3D:
			var lname: String = c.name.to_lower()
			if "rueda" in lname or "wheel" in lname or "llanta" in lname or "tyre" in lname or "tire" in lname:
				if center.distance_to((c as Node3D).global_position) <= max_dist:
					result.append(c)
		_search_ruedas_global(c, result, center, max_dist)

func _has_valid_ruedas_direccion() -> bool:
	for r in ruedas_direccion:
		if is_instance_valid(r):
			return true
	return false
