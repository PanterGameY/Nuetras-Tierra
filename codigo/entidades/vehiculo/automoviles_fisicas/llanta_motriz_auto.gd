extends RayCast3D

static var _stream_chillido: AudioStream = null

@export_group("Suspensión Turismo")
@export var largo_reposo: float = 0.28
@export var radio_rueda: float = 0.38
@export var rigidez_muelle: float = 26000.0
@export var amortiguacion: float = 2200.0
@export var extra_largo_rayo: float = 0.18
@export var coeficiente_geometria: float = 0.05 # Anti-squat

@export_group("Neumático")
@export var agarre_longitudinal: float = 9.0
@export var agarre_lateral: float = 14.0
@export var grip_multiplier: float = 1.15
@export var resistencia_rodadura: float = 12.0
@export var respuesta_lateral: float = 450.0
@export var respuesta_longitudinal_reposo: float = 1200.0
@export var umbral_vel_reposo: float = 0.2

var coche: RigidBody3D = null
var rueda_visual: Node3D = null
var polvo_emisor: CPUParticles3D = null
var audio_chillido: AudioStreamPlayer3D = null

# Variables internas de física y sonido
var compresion_anterior: float = 0.0
var velocidad_suspension: float = 0.0
var fuerza_normal_anterior: float = 0.0
var _resultant_force: Vector3 = Vector3.ZERO
var aceleracion_longitudinal_coche: float = 0.0
var _vol_objetivo_db: float = -40.0

# Variables visuales
var vel_rodado_visual: float = 0.0
var angulo_rodado_visual: float = 0.0
var rotacion_visual_base: Quaternion = Quaternion.IDENTITY
var _primer_frame: bool = true

# API de compatibilidad
var es_tractriz: bool = true
var es_directriz: bool = false
var es_freno_mano: bool = true
var angulo_direccion: float = 0.0

func _ready() -> void:
	var p = get_parent()
	while p and not p is RigidBody3D:
		p = p.get_parent()
	coche = p as RigidBody3D
	
	if coche:
		add_exception(coche)
	
	enabled = true
	target_position = Vector3(0.0, -(largo_reposo + radio_rueda + extra_largo_rayo), 0.0)
	
	# Forzar detección en el primer frame de carga
	force_raycast_update()

	if get_child_count() > 0:
		rueda_visual = get_child(0)
		rotacion_visual_base = rueda_visual.quaternion

	_crear_sistema_polvo()
	_crear_sistema_sonido()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not coche:
		if rueda_visual:
			rueda_visual.position = Vector3.DOWN * largo_reposo
		return

	force_raycast_update()

	if is_colliding():
		var col_point = get_collision_point()
		var col_normal = get_collision_normal()
		var profundidad = global_position.distance_to(col_point)
		
		# Hooke + Amortiguación
		var compresion = clampf((largo_reposo + radio_rueda) - profundidad, 0.0, largo_reposo + radio_rueda)
		compresion_anterior = compresion
		
		var radio_vec = col_point - coche.global_position
		var v_punto = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
		var vel_vertical = col_normal.dot(v_punto)
		
		var factor_peso = maxf(coche.mass / 1400.0, 1.0)
		var f_muelle = compresion * (rigidez_muelle * factor_peso)
		var f_amort = -vel_vertical * (amortiguacion * factor_peso)
		var f_susp_base = f_muelle + f_amort
		
		# Anti-geometría
		var car_basis = coche.global_transform.basis.orthonormalized()
		var vel_local = car_basis.inverse() * coche.linear_velocity
		var accel_coche = (vel_local.z - aceleracion_longitudinal_coche) / delta if delta > 0.0 else 0.0
		aceleracion_longitudinal_coche = vel_local.z
		
		var f_anti_geom = accel_coche * coche.mass * coeficiente_geometria
		var f_normal_total = clampf(f_susp_base + f_anti_geom, 0.0, 50000.0)
		fuerza_normal_anterior = f_normal_total

		# Aplicar fuerzas físicas en el punto de contacto
		_aplicar_fuerzas_contacto(col_point, col_normal, f_normal_total, delta)
		
		if rueda_visual:
			var target_y = -profundidad + radio_rueda
			if _primer_frame:
				rueda_visual.position.y = target_y
			else:
				rueda_visual.position.y = lerp(rueda_visual.position.y, target_y, delta * 18.0)
	else:
		compresion_anterior = 0.0
		aceleracion_longitudinal_coche = 0.0
		if rueda_visual:
			var target_y = -largo_reposo
			if _primer_frame:
				rueda_visual.position.y = target_y
			else:
				rueda_visual.position.y = lerp(rueda_visual.position.y, target_y, delta * 12.0)

	_primer_frame = false
	_actualizar_visual(delta)

func _aplicar_fuerzas_contacto(col_point: Vector3, col_normal: Vector3, f_normal: float, delta: float) -> void:
	var radio_vec = col_point - coche.global_position
	var v_rueda = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
	var car_basis = coche.global_transform.basis.orthonormalized()
	
	# Direcciones alineadas al chasis
	var dir_adelante = -car_basis.z.normalized()
	var dir_lateral = car_basis.x.normalized()
	
	# Proyectar paralelo al suelo
	var dir_lateral_suelo = dir_adelante.cross(col_normal).normalized()
	dir_adelante = col_normal.cross(dir_lateral_suelo).normalized()
	dir_lateral = dir_lateral_suelo
	
	var vel_forward = v_rueda.dot(dir_adelante)
	var vel_lateral = v_rueda.dot(dir_lateral)

	var fuerza_total_rueda = col_normal * f_normal
	
	# 1. TRACCIÓN LONGITUDINAL (Cálculo T800)
	var par_motor = 0.0
	var motor = coche.get_node_or_null("Motor")
	if coche.activo and motor:
		# Multiplicador de marchas
		var marcha_ok = true
		var iv = get_node_or_null("/root/InputVehiculo")
		if iv:
			var m = iv.get("marcha_actual")
			if m == iv.get("Marcha").NEUTRO or m == iv.get("Marcha").PARQUEO:
				marcha_ok = false
		if marcha_ok:
			par_motor = motor.get("fuerza_ruedas") if motor.get("fuerza_ruedas") != null else 0.0
			
	var fuerza_traccion = 0.0
	if absf(par_motor) > 0.1:
		var f_teorica = par_motor / maxf(radio_rueda, 0.05)
		var limite_tracc = agarre_longitudinal * grip_multiplier * f_normal
		fuerza_traccion = clampf(f_teorica, -limite_tracc, limite_tracc)

	# Freno y freno de mano
	var freno_total = 0.0
	if coche.activo:
		var iv = get_node_or_null("/root/InputVehiculo")
		if iv:
			freno_total = iv.get("freno") * 3500.0
			if es_freno_mano and iv.get("freno_mano") == true:
				freno_total += 8000.0
	else:
		freno_total = 8000.0 # Estacionado

	if freno_total > 0.1 and absf(vel_forward) > 0.1:
		var limite_freno = agarre_longitudinal * grip_multiplier * f_normal * 1.5
		var f_aplic = minf(freno_total, limite_freno)
		fuerza_traccion -= signf(vel_forward) * f_aplic

	# Resistencia rodadura
	if absf(vel_forward) > 0.02:
		var f_rod = -signf(vel_forward) * minf(absf(vel_forward) * resistencia_rodadura, agarre_longitudinal * grip_multiplier * f_normal)
		fuerza_traccion += f_rod

	# Fricción reposo longitudinal
	var par_motor_final = par_motor
	var sin_gas = absf(par_motor_final) < 0.1 and freno_total < 0.1
	if sin_gas and absf(vel_forward) < umbral_vel_reposo:
		var f_rep_long = clampf(-vel_forward * respuesta_longitudinal_reposo, -agarre_longitudinal * grip_multiplier * f_normal, agarre_longitudinal * grip_multiplier * f_normal)
		fuerza_traccion += f_rep_long

	fuerza_total_rueda += dir_adelante * fuerza_traccion

	# 2. FRICCIÓN LATERAL (Cálculo T800 con reducción dinámica de agarre por frenado)
	var fn_lateral = maxf(f_normal, 1200.0)
	var agarre_lat_efectivo = agarre_lateral
	
	# Si se aplica freno fuerte a velocidad, se reduce el agarre lateral para permitir el derrape de la cola
	if freno_total > 1500.0 and absf(vel_forward) > 5.0:
		agarre_lat_efectivo *= 0.35
		
	var fuerza_lateral = -vel_lateral * respuesta_lateral * (fn_lateral / 1000.0)
	var limite_lateral = fn_lateral * agarre_lat_efectivo * grip_multiplier
	fuerza_lateral = clampf(fuerza_lateral, -limite_lateral, limite_lateral)
	fuerza_total_rueda += dir_lateral * fuerza_lateral

	# Aplicar fuerza física al RigidBody
	coche.apply_force(fuerza_total_rueda, radio_vec)
	_resultant_force = fuerza_total_rueda

	# Emisión de partículas de polvo al derrapar o en caminos de tierra
	var derrapando = false
	if is_colliding():
		var col = get_collider()
		var en_tierra = _is_ground_tierra(col)
		var deslizando_lateral = absf(vel_lateral) > 2.2
		var frenando_fuerte = (freno_total > 2000.0 and absf(vel_forward) > 3.0)
		var avanzando_en_tierra = en_tierra and (absf(vel_forward) > 0.8 or absf(vel_lateral) > 0.8)
		
		derrapando = avanzando_en_tierra or deslizando_lateral or frenando_fuerte
		
	if polvo_emisor:
		polvo_emisor.emitting = derrapando

	# Control de audio del derrape con fade suave (Limitado a eje motriz trasero y frenados finales)
	if audio_chillido:
		var chillando = false
		if is_colliding():
			# Chillido por derrape lateral trasero
			var deslizamiento_cola = absf(vel_lateral) > 3.2
			# Chillido leve casi al terminar el frenado fuerte (entre 3 y 20 km/h)
			var frenado_final = (freno_total > 2400.0 and absf(vel_forward) > 1.2 and absf(vel_forward) < 5.5)
			chillando = deslizamiento_cola or frenado_final
			
		if chillando:
			_vol_objetivo_db = 0.0
			if not audio_chillido.playing:
				audio_chillido.play()
		else:
			_vol_objetivo_db = -40.0
		
		# Interpolación suave del volumen de audio (Fade)
		audio_chillido.volume_db = lerpf(audio_chillido.volume_db, _vol_objetivo_db, delta * 9.0)
		if not chillando and audio_chillido.volume_db <= -38.0:
			audio_chillido.stop()

func _is_ground_tierra(collider: Node) -> bool:
	if not collider:
		return false
	var n_name = collider.name.to_lower()
	var p_name = collider.get_parent().name.to_lower() if collider.get_parent() else ""
	
	var keywords = ["tierra", "dirt", "terreno", "barro", "mud", "sand", "arena", "pasto", "grass", "trocha", "hierba", "gridmap"]
	for kw in keywords:
		if kw in n_name or kw in p_name:
			return true
	return false

func _actualizar_visual(delta: float) -> void:
	if not rueda_visual:
		return
	var vel_local = coche.global_transform.basis.inverse() * coche.linear_velocity
	var speed_ms = -vel_local.z
	vel_rodado_visual = lerp(vel_rodado_visual, speed_ms, clamp(delta * 6.0, 0.0, 1.0))
	
	# Sentido visual por lateral
	var factor_rot = -1.0 if position.x > 0.0 else 1.0
	angulo_rodado_visual += vel_rodado_visual * factor_rot * delta / max(radio_rueda, 0.05)
	angulo_rodado_visual = wrapf(angulo_rodado_visual, -PI, PI)
	
	rueda_visual.quaternion = rotacion_visual_base * Quaternion(Vector3.RIGHT, angulo_rodado_visual)

func get_resultant_force() -> Vector3:
	return _resultant_force

func _crear_sistema_polvo() -> void:
	polvo_emisor = CPUParticles3D.new()
	polvo_emisor.name = "PolvoParticulas"
	add_child(polvo_emisor)
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.4, 0.4)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.55, 0.52, 0.48, 0.25)
	
	quad_mesh.material = mat
	polvo_emisor.mesh = quad_mesh

	polvo_emisor.emitting = false
	polvo_emisor.amount = 20
	polvo_emisor.lifetime = 0.6
	polvo_emisor.one_shot = false
	polvo_emisor.randomness = 0.5
	polvo_emisor.local_coords = false
	polvo_emisor.direction = Vector3(0, 0.35, 1)
	polvo_emisor.spread = 28.0
	polvo_emisor.gravity = Vector3(0, 1.2, 0)
	polvo_emisor.initial_velocity_min = 1.2
	polvo_emisor.initial_velocity_max = 3.8
	
	var gradiente = Gradient.new()
	gradiente.set_color(0, Color(0.40, 0.40, 0.40, 0.40))
	gradiente.set_color(1, Color(0.20, 0.20, 0.20, 0.0))
	polvo_emisor.color_ramp = gradiente
	
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.6))
	polvo_emisor.scale_amount_curve = curve
	polvo_emisor.scale_amount_min = 0.5
	polvo_emisor.scale_amount_max = 1.4

func _crear_sistema_sonido() -> void:
	audio_chillido = AudioStreamPlayer3D.new()
	audio_chillido.name = "ChillidoNeumatico"
	add_child(audio_chillido)
	
	if not _stream_chillido:
		_stream_chillido = load("res://recursos/sonidos_vehiculo/motor/automovil/Carro_Frenando_Efecto_De_Sonido.mp3")
	
	if _stream_chillido:
		audio_chillido.stream = _stream_chillido
		
	audio_chillido.volume_db = -40.0
	audio_chillido.max_db = 0.0
	audio_chillido.unit_size = 5.0
	audio_chillido.max_distance = 60.0
	audio_chillido.panning_strength = 1.5
	audio_chillido.autoplay = false
