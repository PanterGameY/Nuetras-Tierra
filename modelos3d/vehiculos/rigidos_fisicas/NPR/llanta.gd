extends RayCast3D

# ═══════════════════════════════════════════════════════════════════════
# Llanta — Física de suspensión y neumático por rueda
# Se configura directamente en el Inspector de cada rueda.
# ═══════════════════════════════════════════════════════════════════════

@export_group("Suspensión")
## Distancia del anclaje (pivote) al centro de la rueda cuando la suspensión está totalmente extendida (sin carga) en metros. SUV ≈ 0.30m, camiones ≈ 0.40m.
@export var largo_reposo: float = 0.28
## Radio total del neumático en metros. Rueda de coche común ≈ 0.33m, SUV/Rueda 16" ≈ 0.38m, camiones ≈ 0.55m.
@export var radio_rueda: float = 0.38
## Rigidez (dureza) del resorte de la suspensión en N/m. Valores altos evitan que el chasis toque el suelo. SUV ≈ 180,000 N/m, camiones ≈ 600,000 N/m.
@export var rigidez_muelle: float = 180000.0
## Amortiguación de la suspensión en N·s/m. Controla el rebote del resorte. Valores muy bajos causan balanceo excesivo; muy altos causan rigidez extrema. SUV ≈ 10,000 N·s/m, camiones ≈ 45,000 N·s/m.
@export var amortiguacion: float = 10000.0
## Límite de fuerza vertical máxima que puede aplicar la suspensión en Newtons. Evita fuerzas absurdas en impactos fuertes. SUV ≈ 350,000 N, camiones ≈ 900,000 N.
@export var fuerza_suspension_max: float = 50000.0
## Margen de longitud adicional que tiene el RayCast por debajo de la rueda en metros. Permite detectar baches profundos o suelo antes de la extensión total. Normalmente no requiere modificación.
@export var extra_largo_rayo: float = 0.18
## Si está activo, reproduce el sonido de golpe metálico y notifica cuando la suspensión sufre un impacto fuerte.
@export var activar_sonido_golpe: bool = true

@export_group("Suspensión Asimétrica (Rigs of Rods)")
## Rigidez en compresión/bump (N/m). Si es 0.0, toma rigidez_muelle automáticamente.
@export var rigidez_compresion: float = 0.0
## Rigidez en rebote/rebound (N/m). Si es 0.0, toma 82% de rigidez_compresion.
@export var rigidez_rebote: float = 0.0
## Amortiguación en compresión/bump (N*s/m). Suave para absorber baches. Si es 0.0, toma amortiguacion.
@export var amortiguacion_compresion: float = 0.0
## Amortiguación en rebote/rebound (N*s/m). 2.4x más alto para eliminar balanceo y rebotes oscilatorios. Si es 0.0, toma 2.4 * amortiguacion_compresion.
@export var amortiguacion_rebote: float = 0.0
## Rigidez de la barra estabilizadora analítica inter-eje (N/m) conectada a la rueda opuesta.
@export var rigidez_barra_estabilizadora: float = 35000.0

@export_group("Neumático")
## Coeficiente de fricción/agarre longitudinal (aceleración y frenado directo). A mayor valor, menor derrape longitudinal. SUV ≈ 8.0, camiones ≈ 12.0.
@export var agarre_longitudinal: float = 8.0
## Coeficiente de fricción/agarre lateral en curvas. Controla la tracción lateral; a mayor valor, el vehículo derrapa menos en curvas cerradas. SUV ≈ 22.0, camiones ≈ 30.0.
@export var agarre_lateral: float = 22.0
## Multiplicador global del agarre del neumático. Facilita ajustar la adherencia de forma dinámica o global (1.0 = estándar).
@export var grip_multiplier: float = 1.25
## Fuerza de frenado máxima que puede aplicar esta rueda en Newtons al accionar el freno normal. SUV ≈ 15,000 N, camiones ≈ 30,000 N.
@export var fuerza_max_freno: float = 15000.0
## Resistencia al rodar del neumático. Simula la fricción interna y rugosidad sin duplicar físicas globales del coche. 0 para desactivar, o valores entre 5 y 30.
@export var resistencia_rodadura: float = 15.0
## Fuerza de respuesta y corrección lateral de derrape. Aumenta la estabilidad para re-alinear el neumático al deslizar. SUV ≈ 500.0, camiones ≈ 400.0.
@export var respuesta_lateral: float = 500.0
## Inercia rotacional de la rueda (resistencia a cambiar su velocidad de giro) en kg·m². Influye en qué tan rápido gira o se detiene la rueda visualmente. SUV ≈ 1.5, camiones ≈ 4.0.
@export var inertia_rueda: float = 1.5

@export_group("Estabilidad a Baja Velocidad")
## Fuerza estabilizadora para contrarrestar el deslizamiento lateral cuando el vehículo está casi detenido. Evita que el coche se deslice en rampas.
@export var respuesta_lateral_reposo: float = 1400.0
## Fuerza estabilizadora para contrarrestar el deslizamiento longitudinal (hacia adelante/atrás) cuando el vehículo está casi detenido.
@export var respuesta_longitudinal_reposo: float = 1100.0
## Umbral de velocidad (en m/s) por debajo del cual se activan las fuerzas estabilizadoras de reposo.
@export var umbral_vel_reposo: float = 0.2
## Fuerza de resistencia aplicada al girar las ruedas directrices en reposo (simula la fricción de la dirección asistida contra el suelo).
@export var fuerza_guiado_direccion: float = 2200.0

@export_group("Rol de la Rueda")
## Indica si la rueda recibe potencia/torque del motor (Tracción FWD, RWD o AWD).
@export var es_tractriz: bool = true
## Indica si esta rueda se bloquea al activar el freno de mano (típicamente las ruedas traseras).
@export var es_freno_mano: bool = false
## Indica si la rueda gira al accionar la dirección/volante (típicamente las ruedas delanteras).
@export var es_directriz: bool = false
## Factor de geometría de suspensión anti-hundimiento (anti-dive/squat) para mitigar que el morro baje al frenar o suba al acelerar. (Típico ≈ 0.05).
@export var coeficiente_geometria: float = 0.05
## Si está activo, aplica un torque de asistencia para auto-alinear la dirección del vehículo según la velocidad de giro.
@export var usar_torque_asistencia_direccion: bool = false
## Magnitud de la fuerza de torque de asistencia para alinear la dirección en curvas rápidas.
@export var torque_asistencia_direccion: float = 15000.0

@export_group("Visual")
## Si está activo, sincroniza la rotación visual de la rueda con la velocidad lineal del chasis en lugar de la inercia interna.
@export var visual_sync_to_velocity: bool = true
## Suavizado de la transición y rotación visual de la rueda. Valores altos reducen el lag visual.
@export var visual_smooth: float = 6.0
## Invierte la dirección de rotación visual. Útil para corregir ruedas en el lateral opuesto del modelo 3D.
@export var invertir_rotacion_visual: bool = false

# ─── Estado interno ──────────────────────────────────────────────────
static var _ultimo_tiempo_aviso_golpe: float = 0.0
var coche: RigidBody3D
var rueda_visual: Node3D

var torque_drive: float = 0.0
var fuerza_freno: float = 0.0
var fuerza_freno_mano: float = 0.0
var angulo_direccion: float = 0.0
var _resultant_force: Vector3 = Vector3.ZERO

var vel_rodado_visual: float = 0.0
var angulo_rodado_visual: float = 0.0
var rotacion_visual_base: Quaternion = Quaternion.IDENTITY

var punto_contacto: Vector3 = Vector3.ZERO
var radio_vec: Vector3 = Vector3.ZERO

var polvo_emisor: CPUParticles3D = null
var audio_player_golpe: AudioStreamPlayer3D = null


var compresion_anterior: float = 0.0
var velocidad_suspension: float = 0.0
var fuerza_normal_anterior: float = 0.0
var aceleracion_longitudinal_coche: float = 0.0
var velocidad_angular_rueda: float = 0.0
var friccion_suelo_actual: float = 1.0
var rueda_opuesta: Node = null

@export_group("Personalización Física")
## Ángulo de inclinación de la rueda (Camber/Caída) en grados. Valores negativos inclinan la parte superior hacia adentro.
@export var camber_deg: float = 0.0
## Desplazamiento lateral (offset) de la rueda hacia afuera en metros. Modifica la posición física del eje.
@export var offset_rueda: float = 0.0
var base_pos_x: float = 0.0

@export_group("Depuración (Debug)")
## Activa el modo de depuración visual e imprime información en consola para esta rueda específica.
@export var debug_llanta: bool = false

func _ready() -> void:
	base_pos_x = position.x
	if offset_rueda != 0.0:
		aplicar_offset(offset_rueda)
	coche = _buscar_coche(get_parent())
	if coche:
		add_exception(coche)

	enabled = true
	target_position = Vector3(0.0, -(largo_reposo + radio_rueda + extra_largo_rayo), 0.0)

	if get_child_count() > 0:
		rueda_visual = get_child(0)
		rotacion_visual_base = rueda_visual.quaternion

	_crear_sistema_polvo()

func aplicar_offset(val: float) -> void:
	offset_rueda = val
	position.x = base_pos_x + (val * sign(base_pos_x))



func _physics_process(delta: float) -> void:
	if not coche or coche.freeze:
		return

	force_raycast_update()

	if not is_colliding():
		_aplicar_suspension_libre(delta)
		return

	punto_contacto = get_collision_point()
	radio_vec = punto_contacto - coche.global_position

	var collider = get_collider()
	var en_tierra = false
	if collider and _is_ground_tierra(collider):
		en_tierra = true
		if coche and coche.has_method("notificar_suciedad"):
			var vel_factor = clamp(coche.linear_velocity.length() / 10.0, 0.1, 1.5)
			coche.notificar_suciedad(delta * 0.04 * vel_factor)

	# Controlar partículas de polvo
	if polvo_emisor:
		if en_tierra and coche and coche.linear_velocity.length() > 0.8:
			polvo_emisor.global_position = punto_contacto
			polvo_emisor.emitting = true
			
			# Alinear dirección de emisión opuesta al movimiento
			var dir_atras = -coche.linear_velocity.normalized()
			var local_dir = to_local(global_position + dir_atras) - to_local(global_position)
			local_dir.y = 0.5
			polvo_emisor.direction = local_dir.normalized()
			polvo_emisor.initial_velocity_min = max(0.5, coche.linear_velocity.length() * 0.1)
			polvo_emisor.initial_velocity_max = max(1.5, coche.linear_velocity.length() * 0.25)
		else:
			polvo_emisor.emitting = false



	var car_basis: Basis = coche.global_transform.basis.orthonormalized()
	var forward: Vector3 = -car_basis.z.normalized()
	var right: Vector3 = car_basis.x.normalized()
	var wheel_basis: Basis = global_transform.basis.orthonormalized()
	var up: Vector3 = wheel_basis.y.normalized()

	if es_directriz and abs(angulo_direccion) > 0.001:
		forward = forward.rotated(up, -angulo_direccion)
		right = right.rotated(up, -angulo_direccion)

	# Calcular distancia directa del anclaje al punto de contacto (más robusto ante rotaciones)
	var distancia: float = global_position.distance_to(punto_contacto)
	var recorrido_actual: float = max(distancia - radio_rueda, 0.0)
	var compresion: float = clamp(largo_reposo - recorrido_actual, 0.0, largo_reposo)

	# Si la suspensión está totalmente extendida (la rueda se despega del suelo),
	# no se aplican fuerzas espurias y se procesa como suspensión libre
	if compresion <= 0.0001:
		_aplicar_suspension_libre(delta)
		return

	velocidad_suspension = (compresion - compresion_anterior) / delta if delta > 0 else 0.0
	compresion_anterior = compresion

	var vel_punto: Vector3 = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
	var vel_vertical: float = up.dot(vel_punto)

	var peso_remolque: float = 0.0
	if coche and coche.has_method("obtener_peso_remolque"):
		peso_remolque = coche.obtener_peso_remolque()

	var masa_efectiva: float = coche.mass if coche else 1400.0
	if not es_directriz and peso_remolque > 0.0:
		# La quinta rueda transfiere aproximadamente el 35% del peso del remolque a los ejes traseros
		masa_efectiva += peso_remolque * 0.35

	var factor_peso_rep: float = max(masa_efectiva / 1400.0, 1.0)
	var k_comp: float = (rigidez_compresion if rigidez_compresion > 0.0 else rigidez_muelle) * factor_peso_rep
	var k_reb: float = (rigidez_rebote if rigidez_rebote > 0.0 else k_comp * 0.82) * factor_peso_rep
	var d_comp: float = (amortiguacion_compresion if amortiguacion_compresion > 0.0 else amortiguacion) * factor_peso_rep
	var d_reb: float = (amortiguacion_rebote if amortiguacion_rebote > 0.0 else d_comp * 2.4) * factor_peso_rep

	# 1. Amortiguación Asimétrica de RoR (Rebound vs Bump)
	var k_actual: float = k_comp if velocidad_suspension >= 0.0 else k_reb
	var d_actual: float = d_comp if velocidad_suspension >= 0.0 else d_reb

	# Progresión cuadrática en topes de suspensión (evita topes secos y simula ballestas pesadas)
	var factor_progresivo: float = pow(compresion / maxf(largo_reposo, 0.05), 2.0)
	k_actual *= (1.0 + 1.2 * factor_progresivo)

	var fuerza_muelle: float = compresion * k_actual
	var fuerza_amortiguador: float = velocidad_suspension * d_actual
	var fuerza_suspension_base: float = fuerza_muelle + fuerza_amortiguador

	# 2. Barra Estabilizadora Analítica Inter-Eje (Anti-Roll Bar)
	if is_instance_valid(rueda_opuesta) and "compresion_anterior" in rueda_opuesta:
		var comp_opuesta: float = float(rueda_opuesta.compresion_anterior)
		var dif_compresion: float = compresion - comp_opuesta
		fuerza_suspension_base += dif_compresion * rigidez_barra_estabilizadora * factor_peso_rep

	var inv_basis = coche.global_transform.basis.inverse()
	var vel_local = inv_basis * coche.linear_velocity
	var aceleracion_coche = (vel_local.z - aceleracion_longitudinal_coche) / delta if delta > 0 else 0.0
	aceleracion_longitudinal_coche = vel_local.z

	var fuerza_anti_geometrica: float = 0.0
	if es_directriz:
		fuerza_anti_geometrica = -aceleracion_coche * coche.mass * coeficiente_geometria
	else:
		fuerza_anti_geometrica = aceleracion_coche * coche.mass * coeficiente_geometria

	var f_max_dinamica: float = maxf(fuerza_suspension_max, (masa_efectiva * 9.81) * 2.5)
	var fuerza_normal_total: float = clamp(fuerza_suspension_base + fuerza_anti_geometrica, 0.0, f_max_dinamica)
	fuerza_normal_anterior = fuerza_normal_total

	# Detectar golpe fuerte en la suspension: si el vehiculo va a 40 km/h o mas y hay una compresion drastica (>= 1.8 m/s)
	var vel_kmh = coche.linear_velocity.length() * 3.6 if coche else 0.0
	if activar_sonido_golpe and vel_kmh >= 40.0 and velocidad_suspension >= 1.8:
		_reproducir_golpe_metal()
		var tiempo_actual = Time.get_ticks_msec() / 1000.0
		if tiempo_actual - _ultimo_tiempo_aviso_golpe > 5.0:
			_ultimo_tiempo_aviso_golpe = tiempo_actual
			if has_node("/root/NotificationManager"):
				get_node("/root/NotificationManager").notificar_alerta_gigante("⚠️ ¡LA SUSPENSION HA SUFRIDO UN GOLPE FUERTE!")

	var fuerza_total_rueda: Vector3 = Vector3.ZERO
	fuerza_total_rueda += up * fuerza_normal_total

	var vel_forward: float = forward.dot(vel_punto)

	var multiplicador_motor: float = 0.0
	var bloqueo_parking: bool = false
	if is_instance_valid(InputVehiculo):
		match InputVehiculo.marcha_actual:
			InputVehiculo.Marcha.PARQUEO:
				bloqueo_parking = true
				multiplicador_motor = 0.0
			InputVehiculo.Marcha.REVERSA:
				multiplicador_motor = 1.0
			InputVehiculo.Marcha.NEUTRO:
				multiplicador_motor = 0.0
			InputVehiculo.Marcha.DRIVE:
				multiplicador_motor = 1.0

	var par_motor_final: float = torque_drive * multiplicador_motor

	var fuerza_traccion: float = 0.0
	if es_tractriz and not bloqueo_parking:
		var fuerza_teorica: float = 0.0
		if abs(par_motor_final) > 0.1:
			fuerza_teorica = par_motor_final / max(radio_rueda, 0.05)
		var limite_traccion: float = agarre_longitudinal * grip_multiplier * fuerza_normal_total
		fuerza_traccion = clamp(fuerza_teorica, -limite_traccion, limite_traccion)

	var fuerza_freno_total: float = fuerza_freno + (fuerza_freno_mano if es_freno_mano else 0.0)
	if bloqueo_parking:
		fuerza_freno_total = max(fuerza_freno_total, fuerza_max_freno * 2.0)

	var fuerza_rodadura: float = 0.0

	if fuerza_freno_total > 0.01 and abs(vel_forward) > 0.1:
		var limite_freno: float = agarre_longitudinal * grip_multiplier * fuerza_normal_total * 1.5
		var signo_vel: float = sign(vel_forward)
		var f_aplic: float = min(fuerza_freno_total, limite_freno)
		fuerza_traccion -= signo_vel * f_aplic

	if abs(vel_forward) > 0.02:
		fuerza_rodadura = -sign(vel_forward) * min(abs(vel_forward) * resistencia_rodadura, agarre_longitudinal * grip_multiplier * fuerza_normal_total)
		fuerza_traccion += fuerza_rodadura

	var sin_entrada_longitudinal: bool = abs(torque_drive) < 0.1 and fuerza_freno_total < 0.05
	if sin_entrada_longitudinal and abs(vel_forward) < umbral_vel_reposo:
		var fuerza_reposo_long: float = clamp(
			-vel_forward * respuesta_longitudinal_reposo * factor_peso_rep,
			-agarre_longitudinal * grip_multiplier * fuerza_normal_total,
			agarre_longitudinal * grip_multiplier * fuerza_normal_total
		)
		fuerza_traccion += fuerza_reposo_long

	fuerza_total_rueda += forward * fuerza_traccion

	var vel_lateral: float = right.dot(vel_punto)
	# Garantizar una fuerza normal mínima para el cálculo lateral (evita pérdida de dirección al levantarse el chasis)
	var fn_lateral: float = max(fuerza_normal_total, 1200.0)
	# Eliminamos la atenuación basada en vel_forward para evitar deslizamientos laterales no deseados al estar parados en aceras/rampas
	var fuerza_lateral: float = -vel_lateral * respuesta_lateral * factor_peso_rep * (fn_lateral / 1000.0)
	var limite_lateral: float = fn_lateral * agarre_lateral * grip_multiplier
	fuerza_lateral = clamp(fuerza_lateral, -limite_lateral, limite_lateral)
	fuerza_total_rueda += right * fuerza_lateral

	if usar_torque_asistencia_direccion and es_directriz and abs(angulo_direccion) > 0.01 and abs(vel_forward) > 0.5:
		var velocidad_factor: float = min(abs(vel_forward) / 10.0, 1.0)
		var torque_direccion: float = angulo_direccion * torque_asistencia_direccion * velocidad_factor * (fuerza_normal_total / 10000.0)
		coche.apply_torque(up * torque_direccion)

	coche.apply_force(fuerza_total_rueda, radio_vec)

	_resultant_force = fuerza_total_rueda

	var torque_rodadura: float = -fuerza_rodadura * radio_rueda
	var torque_resist: float = (fuerza_freno_total * radio_rueda) + torque_rodadura
	var torque_net: float = par_motor_final - torque_resist
	velocidad_angular_rueda += (torque_net / max(inertia_rueda, 0.0001)) * delta
	velocidad_angular_rueda = lerp(velocidad_angular_rueda, velocidad_angular_rueda * 0.995, clamp(delta * 60.0, 0.0, 1.0))

	var target_linear_speed: float = velocidad_angular_rueda * radio_rueda
	if visual_sync_to_velocity and is_colliding():
		target_linear_speed = vel_forward
	vel_rodado_visual = lerp(vel_rodado_visual, target_linear_speed, clamp(delta * visual_smooth, 0.0, 1.0))

	_actualizar_visual(delta)

func _aplicar_suspension_libre(delta: float) -> void:
	compresion_anterior = 0.0
	velocidad_suspension = 0.0
	fuerza_normal_anterior = 0.0
	_resultant_force = Vector3.ZERO

	if polvo_emisor:
		polvo_emisor.emitting = false

	# En el aire desacelerar suavemente el rodado de la rueda
	vel_rodado_visual = lerp(vel_rodado_visual, 0.0, clamp(delta * 2.5, 0.0, 1.0))
	_actualizar_visual(delta)

func _actualizar_visual(delta: float) -> void:
	if not rueda_visual:
		return

	var ty: float = -largo_reposo
	if is_colliding():
		# Usar coordenadas locales del punto de colisión para determinar la altura
		var local_punto: Vector3 = to_local(get_collision_point())
		# El tope físico inferior de la suspensión es -largo_reposo.
		# Clampear a -largo_reposo permite que cuando el chasis se levante, la rueda no baje más
		# de su límite mecánico y se separe visiblemente del suelo.
		ty = maxf(local_punto.y + radio_rueda, -largo_reposo)

	var velocidad_lerp := 12.0 if ty < rueda_visual.position.y else 6.0
	rueda_visual.position.y = lerp(rueda_visual.position.y, ty, delta * velocidad_lerp)

	var q_direccion: Quaternion = Quaternion(Vector3.UP, -angulo_direccion)

	var factor_rot: float = -1.0 if invertir_rotacion_visual else 1.0
	angulo_rodado_visual -= vel_rodado_visual * factor_rot * delta / max(radio_rueda, 0.05)
	angulo_rodado_visual = wrapf(angulo_rodado_visual, -PI, PI)
	var q_rodado: Quaternion = Quaternion(Vector3.RIGHT, angulo_rodado_visual)

	var q_camber := Quaternion(Vector3.FORWARD, deg_to_rad(camber_deg * sign(position.x)))
	rueda_visual.quaternion = q_direccion * rotacion_visual_base * q_camber * q_rodado

func set_drive_torque(t: float) -> void:
	torque_drive = t

func set_brake(intensidad: float, mano: bool) -> void:
	intensidad = clamp(intensidad, 0.0, 1.0)
	if mano:
		fuerza_freno_mano = intensidad * fuerza_max_freno * 1.5
		fuerza_freno = 0.0
	else:
		fuerza_freno = intensidad * fuerza_max_freno
		fuerza_freno_mano = 0.0

func set_grip_multiplier(m: float) -> void:
	grip_multiplier = max(m, 0.0)

func get_resultant_force() -> Vector3:
	return _resultant_force

func aplicar_angulo_direccion(angulo: float) -> void:
	angulo_direccion = angulo

func _buscar_coche(n: Node) -> RigidBody3D:
	if n == null or n is RigidBody3D:
		return n
	return _buscar_coche(n.get_parent())

func _is_ground_tierra(collider: Node) -> bool:
	if not collider:
		return false
	var n_name = collider.name.to_lower()
	var p_name = collider.get_parent().name.to_lower() if collider.get_parent() else ""
	
	# Imprimir depuración si coche.debug_vehiculo está activo
	if coche and "debug_vehiculo" in coche and coche.debug_vehiculo:
		print("[Llanta Debug] Colisiona con: ", n_name, " | Padre: ", p_name)
	
	var keywords = ["tierra", "dirt", "terreno", "barro", "mud", "sand", "arena", "pasto", "grass", "suelo", "road", "trocha", "via", "ruta", "hierba", "weed", "foliage", "gridmap"]
	for kw in keywords:
		if kw in n_name or kw in p_name:
			return true
			
	if collider.get_parent():
		for sibling in collider.get_parent().get_children():
			if sibling is MeshInstance3D:
				var s_name = sibling.name.to_lower()
				for kw in keywords:
					if kw in s_name:
						return true
				var max_surfaces = sibling.mesh.get_surface_count() if sibling.mesh else 0
				for i in range(max_surfaces):
					var mat = sibling.get_active_material(i)
					if mat:
						var m_name = mat.resource_name.to_lower()
						var m_path = mat.resource_path.to_lower()
						for kw in keywords:
							if kw in m_name or kw in m_path:
								return true
								
	if "physics_material_override" in collider and collider.physics_material_override:
		var phys_mat = collider.physics_material_override
		var pm_name = phys_mat.resource_name.to_lower()
		for kw in keywords:
			if kw in pm_name:
				return true
				
	return false


func _crear_sistema_polvo() -> void:
	polvo_emisor = CPUParticles3D.new()
	polvo_emisor.name = "PolvoParticulas"
	add_child(polvo_emisor)
	
	polvo_emisor.emitting = false
	polvo_emisor.amount = 24
	polvo_emisor.lifetime = 1.2
	polvo_emisor.one_shot = false
	polvo_emisor.explosiveness = 0.0
	polvo_emisor.randomness = 0.6
	polvo_emisor.local_coords = false # IMPORTANTE: dejar las partículas en el mundo (rastro)
	
	polvo_emisor.direction = Vector3(0, 0.4, 1)
	polvo_emisor.spread = 35.0
	polvo_emisor.gravity = Vector3(0, 0.6, 0) # El polvo flota hacia arriba suavemente
	polvo_emisor.initial_velocity_min = 1.0
	polvo_emisor.initial_velocity_max = 3.5
	
	# Curva de tamaño para mobiles
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.15, 1.5))
	curve.add_point(Vector2(1.0, 3.0))
	polvo_emisor.scale_amount_curve = curve
	polvo_emisor.scale_amount_min = 0.8
	polvo_emisor.scale_amount_max = 2.5
	
	# Degradado de desvanecimiento con mayor opacidad
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.48, 0.40, 0.32, 0.0))
	gradient.add_point(0.15, Color(0.48, 0.40, 0.32, 0.55))
	gradient.add_point(1.0, Color(0.48, 0.40, 0.32, 0.0))
	polvo_emisor.color_ramp = gradient
	
	# Material de cartelera de partículas (Billboard)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	polvo_emisor.material_override = mat
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.8, 0.8)
	polvo_emisor.mesh = mesh


func _reproducir_golpe_metal() -> void:
	if not audio_player_golpe:
		audio_player_golpe = AudioStreamPlayer3D.new()
		audio_player_golpe.stream = load("res://recursos/sonidos_vehiculo/efectos/golpe_metal.mp3")
		audio_player_golpe.unit_size = 25.0
		audio_player_golpe.max_distance = 60.0
		audio_player_golpe.bus = &"Master"
		add_child(audio_player_golpe)
	
	audio_player_golpe.play()
