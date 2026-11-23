extends RayCast3D

static var _stream_chillido: AudioStream = null

@export_group("Suspensión Pesada")
@export var largo_reposo: float = 0.35
@export var radio_rueda: float = 0.52
@export var rigidez_muelle: float = 140000.0
@export var amortiguacion: float = 18000.0
@export var extra_largo_rayo: float = 0.20
@export var coeficiente_geometria: float = 0.03

@export_group("Suspensión Asimétrica (Rigs of Rods)")
@export var rigidez_compresion: float = 140000.0 ## N/m (Bump)
@export var rigidez_rebote: float = 115000.0     ## N/m (Rebound)
@export var amortiguacion_compresion: float = 10000.0 ## N*s/m (Bump suave)
@export var amortiguacion_rebote: float = 24000.0   ## N*s/m (2.4x rebound damping)
@export var rigidez_barra_estabilizadora: float = 38000.0 ## Rigidez anti-vuelco (N/m)
@export var rigidez_balancin_tandem: float = 28000.0 ## Rigidez de compensación tándem walking beam (N/m)
var rueda_opuesta: Node = null
var rueda_tandem: Node = null

@export_group("Neumático y Carga")
@export var es_directriz: bool = false
@export var es_tractriz: bool = true
@export var es_doble_rueda: bool = false
@export var rotar_invertido: bool = false
@export var agarre_longitudinal: float = 16.0
@export var agarre_lateral: float = 18.0
@export var grip_multiplier: float = 1.30
@export var resistencia_rodadura: float = 10.0
@export var respuesta_lateral: float = 1650.0
@export var respuesta_longitudinal_reposo: float = 3500.0
@export var umbral_vel_reposo: float = 0.18

@export_group("Dirección (Solo Directriz)")
@export var angulo_giro_max: float = 35.0
@export var velocidad_giro_volante: float = 90.0
@export var torque_asistencia_direccion: float = 32000.0

var coche: RigidBody3D = null
var rueda_visual: Node3D = null
var _iv_cache: Node = null

# Propiedades de compatibilidad con controlador_llantas_pesado.gd
var fuerza_freno: float = 0.0
var fuerza_freno_mano: float = 0.0

# Variables internas
var compresion_anterior: float = 0.0
var fuerza_normal_anterior: float = 0.0
var _resultant_force: Vector3 = Vector3.ZERO
var aceleracion_longitudinal_coche: float = 0.0
var _angulo_actual: float = 0.0
var angulo_direccion: float:
	get: return _angulo_actual
	set(val): _angulo_actual = val
var freno_aire_suavizado: float = 0.0

# Variables visuales
var vel_rodado_visual: float = 0.0
var angulo_rodado_visual: float = 0.0
var polvo_emisor: CPUParticles3D = null
var audio_chillido: AudioStreamPlayer3D = null
var derrapando: bool = false
var deslizamiento_lateral: float = 0.0
var _vol_objetivo_db: float = -40.0
var rotacion_visual_base: Quaternion = Quaternion.IDENTITY
var _primer_frame: bool = true

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

func _ready() -> void:
	var p = get_parent()
	while p and not p is RigidBody3D:
		p = p.get_parent()
	coche = p as RigidBody3D
	
	if coche:
		add_exception(coche)
	
	enabled = true
	target_position = Vector3(0.0, -(largo_reposo + radio_rueda + extra_largo_rayo), 0.0)
	force_raycast_update()

	if get_child_count() > 0:
		rueda_visual = get_child(0)
		rotacion_visual_base = rueda_visual.quaternion

	call_deferred("_crear_sistema_sonido")

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not coche:
		if rueda_visual:
			rueda_visual.position = Vector3.DOWN * largo_reposo
		return

	if coche.has_method("es_autoridad_local") and not coche.es_autoridad_local():
		if es_directriz and "angulo_direccion_red" in coche:
			_angulo_actual = lerp(_angulo_actual, float(coche.angulo_direccion_red), delta * 12.0)
		var car_b = coche.global_transform.basis.orthonormalized()
		var v_loc = car_b.inverse() * coche.linear_velocity
		vel_rodado_visual = -v_loc.z
		_actualizar_visual(delta)
		return

	force_raycast_update()

	var iv = _get_iv()

	# Dirección Ackermann con dureza dinámica por velocidad
	if es_directriz:
		var steer_input = float(iv.get("direccion")) * -1.0 if (iv and coche.activo and iv.get("direccion") != null) else 0.0
		var vel_kmh = coche.linear_velocity.length() * 3.6
		var dureza_giro = clampf(velocidad_giro_volante * (1.0 - (vel_kmh / 180.0)), 38.0, velocidad_giro_volante)
		var factor_limite_giro = clampf(1.0 - (maxf(vel_kmh - 15.0, 0.0) / 95.0) * 0.78, 0.22, 1.0)
		var angulo_base_rad = absf(steer_input) * deg_to_rad(angulo_giro_max) * factor_limite_giro
		var angulo_obj = 0.0
		
		if angulo_base_rad > 0.001:
			var batalla_pesado = 5.4
			var trocha_pesado = 2.45
			var radio_giro = batalla_pesado / tan(angulo_base_rad)
			var es_derecha = position.x > 0.0
			var es_interna = (steer_input < 0.0 and es_derecha) or (steer_input > 0.0 and not es_derecha)
			if es_interna:
				angulo_obj = atan(batalla_pesado / maxf(radio_giro - (trocha_pesado / 2.0), 0.5))
			else:
				angulo_obj = atan(batalla_pesado / maxf(radio_giro + (trocha_pesado / 2.0), 0.5))
			angulo_obj *= signf(steer_input)
		
		var vel_actual_giro = velocidad_giro_volante if absf(steer_input) < 0.01 else dureza_giro
		_angulo_actual = move_toward(_angulo_actual, angulo_obj, delta * deg_to_rad(vel_actual_giro))
		if "angulo_direccion_red" in coche:
			coche.angulo_direccion_red = _angulo_actual
	else:
		_angulo_actual = 0.0

	if is_colliding():
		var col_point = get_collision_point()
		var col_normal = get_collision_normal()
		var profundidad = global_position.distance_to(col_point)
		var largo_max_contacto = largo_reposo + radio_rueda + 0.15
		var compresion = clampf((largo_reposo + radio_rueda) - profundidad, 0.0, largo_reposo + radio_rueda)
		
		if profundidad > largo_max_contacto:
			compresion_anterior = 0.0
			aceleracion_longitudinal_coche = 0.0
			derrapando = false
			deslizamiento_lateral = 0.0
			if polvo_emisor:
				polvo_emisor.emitting = false
			if audio_chillido and audio_chillido.playing:
				_vol_objetivo_db = -40.0
				audio_chillido.stop()
			if rueda_visual:
				var target_y = -largo_reposo
				rueda_visual.position.y = target_y if _primer_frame else lerp(rueda_visual.position.y, target_y, delta * 15.0)
			_primer_frame = false
			_actualizar_visual(delta)
			return

		var radio_vec = col_point - coche.global_position
		var v_punto = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
		var vel_vertical = col_normal.dot(v_punto)

		var factor_peso = maxf(coche.mass / 8500.0, 1.0)
		if not es_directriz and coche.has_method("obtener_peso_remolque"):
			var p_rem = coche.obtener_peso_remolque()
			if p_rem > 0.0:
				factor_peso = maxf((coche.mass + p_rem * 0.50) / 8500.0, 1.0)

		# Cálculo analítico de velocidad de suspensión (estilo Rigs of Rods CalcShocks2)
		# Evita picos en el primer frame de aterrizaje cuando compresion_anterior era 0
		var v_ray_delta: float = -vel_vertical
		if compresion_anterior > 0.0 and delta > 0.0:
			v_ray_delta = clampf((compresion - compresion_anterior) / delta, -20.0, 20.0)
		compresion_anterior = compresion
		var v_suspension: float = (-vel_vertical * 0.70) + (v_ray_delta * 0.30)

		var k_actual: float = (rigidez_compresion if v_suspension >= 0.0 else rigidez_rebote) * factor_peso
		var d_actual: float = (amortiguacion_compresion if v_suspension >= 0.0 else amortiguacion_rebote) * factor_peso

		# Progresión controlada y tope hidráulico (absorbe caídas altas sin rebotar como resorte)
		var comp_ratio: float = clampf(compresion / maxf(largo_reposo, 0.05), 0.0, 1.35)
		var factor_progresivo: float = pow(comp_ratio, 2.0)
		if v_suspension >= 0.0:
			k_actual *= (1.0 + 1.35 * factor_progresivo)
			# Amortiguación hidráulica extra al comprimirse rápido o cerca del tope para evitar que el chasis toque el suelo
			var extra_bump_damping: float = 1.0 + clampf((comp_ratio - 0.45) * 2.8, 0.0, 2.8) + clampf((v_suspension - 1.5) * 0.45, 0.0, 2.8)
			d_actual *= extra_bump_damping
		else:
			# En rebote, suavizar resorte y aumentar retención para evitar rebote violento
			var atenuacion_rebote: float = 0.72 if comp_ratio > 0.45 else 1.0
			k_actual *= (atenuacion_rebote + 0.25 * factor_progresivo)
			d_actual *= (1.75 + clampf(comp_ratio * 1.1, 0.0, 1.2))

		var comp_efectiva: float = minf(compresion, largo_reposo * 1.15)
		var f_muelle = comp_efectiva * k_actual
		var f_amort = v_suspension * d_actual
		var f_susp_base = f_muelle + f_amort

		# Barra Estabilizadora Analítica Inter-Eje
		if is_instance_valid(rueda_opuesta) and "compresion_anterior" in rueda_opuesta:
			var dif_compresion: float = compresion - float(rueda_opuesta.compresion_anterior)
			f_susp_base += dif_compresion * rigidez_barra_estabilizadora * factor_peso

		# Balancín Compensador de Eje Tándem Trasero (Hendrickson Walking Beam - Rigs of Rods)
		if is_instance_valid(rueda_tandem) and "compresion_anterior" in rueda_tandem:
			var dif_tandem: float = compresion - float(rueda_tandem.compresion_anterior)
			f_susp_base += dif_tandem * rigidez_balancin_tandem * factor_peso
		
		var car_basis = coche.global_transform.basis.orthonormalized()
		var vel_local = car_basis.inverse() * coche.linear_velocity
		var speed_forward = -vel_local.z
		var raw_accel = (speed_forward - aceleracion_longitudinal_coche) / maxf(delta, 0.001)
		aceleracion_longitudinal_coche = lerpf(aceleracion_longitudinal_coche, speed_forward, clampf(delta * 10.0, 0.0, 1.0))
		var accel_coche = clampf(raw_accel, -18.0, 18.0)
		
		var factor_inclinacion = 0.04
		var fuerza_anti_geometrica: float = (-accel_coche if es_directriz else accel_coche) * coche.mass * factor_inclinacion
		var limite_inclinacion_max = rigidez_muelle * 0.12
		fuerza_anti_geometrica = clampf(fuerza_anti_geometrica, -limite_inclinacion_max, limite_inclinacion_max)
			
		var mult_max_normal: float = (1.45 if es_doble_rueda else 1.15) if v_suspension >= 0.0 else (0.40 if es_doble_rueda else 0.32)
		var f_normal_max = (coche.mass * 9.82) * mult_max_normal * factor_peso
		var f_normal_total = clampf(f_susp_base + fuerza_anti_geometrica, 0.0, f_normal_max)
		fuerza_normal_anterior = f_normal_total

		_aplicar_fuerzas_contacto(col_point, col_normal, f_normal_total, delta)
		
		if rueda_visual:
			var target_y = clampf(-profundidad + radio_rueda, -largo_reposo, 0.08)
			rueda_visual.position.y = target_y if _primer_frame else lerp(rueda_visual.position.y, target_y, delta * 15.0)
	else:
		compresion_anterior = 0.0
		aceleracion_longitudinal_coche = 0.0
		derrapando = false
		deslizamiento_lateral = 0.0
		if polvo_emisor:
			polvo_emisor.emitting = false
		if audio_chillido:
			_vol_objetivo_db = -40.0
			audio_chillido.volume_db = lerpf(audio_chillido.volume_db, -40.0, delta * 9.0)
			if audio_chillido.volume_db <= -38.0:
				audio_chillido.stop()
		if rueda_visual:
			var target_y = -largo_reposo
			rueda_visual.position.y = target_y if _primer_frame else lerp(rueda_visual.position.y, target_y, delta * 15.0)

	_primer_frame = false
	_actualizar_visual(delta)

func _aplicar_fuerzas_contacto(col_point: Vector3, col_normal: Vector3, f_normal: float, delta: float) -> void:
	var radio_vec = col_point - coche.global_position
	var v_rueda = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
	var car_basis = coche.global_transform.basis.orthonormalized()
	
	var dir_adelante = -car_basis.z.normalized()
	var dir_lateral = car_basis.x.normalized()
	var dir_up_rueda = car_basis.y.normalized()
	
	if es_directriz:
		dir_adelante = dir_adelante.rotated(dir_up_rueda, _angulo_actual).normalized()
		dir_lateral = dir_lateral.rotated(dir_up_rueda, _angulo_actual).normalized()
	
	var dir_lateral_suelo = dir_adelante.cross(col_normal).normalized()
	dir_adelante = col_normal.cross(dir_lateral_suelo).normalized()
	dir_lateral = dir_lateral_suelo
	
	var vel_forward = v_rueda.dot(dir_adelante)
	var vel_lateral = v_rueda.dot(dir_lateral)
	deslizamiento_lateral = vel_lateral

	var fuerza_total_rueda = col_normal * f_normal
	var mult_pacha = 1.8 if es_doble_rueda else 1.0
	var iv = _get_iv()
	var dif_lock: bool = (coche.get("bloqueo_diferencial") == true) or (iv != null and iv.get("bloqueo_diferencial") == true)
	var mult_dif = 1.35 if dif_lock else 1.0

	# 1. TRACCIÓN LONGITUDINAL REPARTIDA ENTRE RUEDAS MOTRICES
	var fuerza_motor_rueda = 0.0
	var motor = coche.get_node_or_null("Motor")
	var auto_hold_motor: bool = false
	if coche.activo and motor:
		auto_hold_motor = motor.get("auto_hold_activo") == true
		if es_tractriz and not es_directriz:
			var marcha_ok = true
			if iv:
				var m = int(iv.get("marcha_actual")) if iv.get("marcha_actual") != null else 2
				if m == 0 or m == 2: # PARQUEO o NEUTRO
					marcha_ok = false
			if marcha_ok:
				var f_total_motor = float(motor.get("fuerza_ruedas")) if motor.get("fuerza_ruedas") != null else 0.0
				var num_motrices: int = max(1, coche.llantas_motrices.size()) if "llantas_motrices" in coche else 4
				# Repartir la fuerza del motor equitativamente entre las ruedas motrices
				fuerza_motor_rueda = (f_total_motor / float(num_motrices)) / maxf(radio_rueda, 0.35)

	# Sensibilidad de carga analítica Pacejka (reducción sutil del coeficiente a sobrecarga extrema - RoR)
	var factor_sat_carga = clampf(1.0 - (f_normal / 180000.0) * 0.15, 0.85, 1.0)
	var fuerza_traccion = 0.0
	if absf(fuerza_motor_rueda) > 0.1:
		var limite_tracc = agarre_longitudinal * grip_multiplier * f_normal * mult_pacha * mult_dif * factor_sat_carga
		fuerza_traccion = clampf(fuerza_motor_rueda, -limite_tracc, limite_tracc)

	# 2. FRENO DE AIRE + FRENO DE ESTACIONAMIENTO + AUTO-HOLD EN PENDIENTE
	var freno_total = 0.0
	var f_input = 0.0
	if coche.activo:
		if iv:
			f_input = float(iv.get("freno")) if iv.get("freno") != null else 0.0
			freno_aire_suavizado = move_toward(freno_aire_suavizado, f_input, delta * 3.8)
			freno_total = freno_aire_suavizado * 20000.0 + fuerza_freno
			if iv.get("freno_mano") == true or fuerza_freno_mano > 0.0:
				freno_total += 38000.0
			elif auto_hold_motor:
				freno_total += 28000.0
	else:
		freno_total = 38000.0

	if freno_total > 0.1 and absf(vel_forward) > 0.06:
		var limite_freno = agarre_longitudinal * grip_multiplier * f_normal * mult_pacha * 1.6 * factor_sat_carga
		var f_aplic = minf(freno_total, limite_freno)
		fuerza_traccion -= signf(vel_forward) * f_aplic

	if absf(vel_forward) > 0.02:
		# Resistencia de rodadura física proporcional a la deformación del neumático bajo carga (RoR)
		var f_rod_carga = (resistencia_rodadura * 1.5) + (f_normal * 0.012)
		var f_rod = -signf(vel_forward) * minf(absf(vel_forward) * f_rod_carga, agarre_longitudinal * grip_multiplier * f_normal)
		fuerza_traccion += f_rod

	var sin_gas = absf(fuerza_motor_rueda) < 0.5 and (freno_total > 0.1 or absf(vel_forward) < umbral_vel_reposo)
	if sin_gas and absf(vel_forward) < umbral_vel_reposo:
		var f_rep_long = clampf(-vel_forward * respuesta_longitudinal_reposo * 1.5, -agarre_longitudinal * grip_multiplier * f_normal * mult_pacha, agarre_longitudinal * grip_multiplier * f_normal * mult_pacha)
		fuerza_traccion += f_rep_long

	fuerza_total_rueda += dir_adelante * fuerza_traccion

	# 3. FRICCIÓN LATERAL Y AGARRE
	var fn_lateral = maxf(f_normal, 3000.0)
	var agarre_lat_efectivo = agarre_lateral
	var respuesta_lat_efectiva = respuesta_lateral

	if es_directriz:
		agarre_lat_efectivo *= 1.25
		respuesta_lat_efectiva *= 1.55
		derrapando = false
	else:
		var iv_fm = (iv != null and iv.get("freno_mano") == true) if coche.activo else false
		var frenando_fuerte = f_input > 0.6 or (freno_total > 20000.0)
		var velocidad_deslizamiento = absf(vel_lateral)
		
		if iv_fm and absf(vel_forward) > 2.0:
			agarre_lat_efectivo *= 0.45
			derrapando = true
		elif frenando_fuerte and velocidad_deslizamiento > 2.2:
			agarre_lat_efectivo *= 0.65
			derrapando = true
		elif velocidad_deslizamiento > 5.2:
			var factor_derrape = clampf((velocidad_deslizamiento - 5.2) / 3.0, 0.0, 1.0)
			agarre_lat_efectivo = lerpf(agarre_lat_efectivo, agarre_lat_efectivo * 0.72, factor_derrape)
			derrapando = true
		else:
			derrapando = false

		if absf(coche.angular_velocity.y) > 0.65 and absf(vel_forward) > 2.0:
			respuesta_lat_efectiva *= 0.90

	var fuerza_lateral = -vel_lateral * respuesta_lat_efectiva * (fn_lateral / 1000.0) * mult_pacha
	var limite_lateral = fn_lateral * agarre_lat_efectivo * grip_multiplier * mult_pacha
	fuerza_lateral = clampf(fuerza_lateral, -limite_lateral, limite_lateral)
	fuerza_total_rueda += dir_lateral * fuerza_lateral

	# 4. ASISTENCIA HIDRÁULICA DE DIRECCIÓN PESADA
	if es_directriz and absf(_angulo_actual) > 0.005 and absf(vel_forward) > 0.2:
		var factor_vel_dir = clampf(vel_forward / 5.0, -1.0, 1.0)
		var factor_peso_asist = clampf(f_normal / 20000.0, 0.6, 2.0)
		var peso_remolque: float = coche.obtener_peso_remolque() if coche.has_method("obtener_peso_remolque") else 0.0
		var factor_asistencia_trailer = 0.12
		if peso_remolque > 5000.0:
			factor_asistencia_trailer = clampf(peso_remolque / 35000.0, 0.12, 1.0)
		var vel_kmh_coche = absf(vel_forward) * 3.6
		var factor_estabilidad_alta_vel = clampf(1.0 - (vel_kmh_coche / 120.0), 0.2, 1.0)
		var torque_dir = (_angulo_actual * 0.5) * torque_asistencia_direccion * factor_vel_dir * factor_peso_asist * factor_asistencia_trailer * factor_estabilidad_alta_vel
		coche.apply_torque(dir_up_rueda * torque_dir)

	var fuerza_contacto_suelo = col_normal * f_normal + dir_lateral * fuerza_lateral
	coche.apply_force(fuerza_contacto_suelo, radio_vec)
	
	var fuerza_longitudinal = dir_adelante * fuerza_traccion
	coche.apply_central_force(fuerza_longitudinal)

	_resultant_force = fuerza_contacto_suelo + fuerza_longitudinal

	if polvo_emisor:
		polvo_emisor.emitting = false

	if audio_chillido:
		var chillando = derrapando and absf(vel_forward) > 1.5
		if chillando:
			_vol_objetivo_db = 0.0
			if not audio_chillido.playing:
				audio_chillido.play()
		else:
			_vol_objetivo_db = -40.0
		audio_chillido.volume_db = lerpf(audio_chillido.volume_db, _vol_objetivo_db, delta * 9.0)
		if not chillando and audio_chillido.volume_db <= -38.0:
			audio_chillido.stop()

func _actualizar_visual(delta: float) -> void:
	if not rueda_visual:
		return
	var q_direccion = Quaternion(Vector3.UP, _angulo_actual) if es_directriz else Quaternion.IDENTITY
	var vel_local = coche.global_transform.basis.inverse() * coche.linear_velocity
	var speed_ms = -vel_local.z
	vel_rodado_visual = lerp(vel_rodado_visual, speed_ms, clamp(delta * 8.0, 0.0, 1.0))
	
	var factor_rot = -1.0 if position.x > 0.0 else 1.0
	var mult_inv = -1.0 if rotar_invertido else 1.0
	angulo_rodado_visual += vel_rodado_visual * factor_rot * mult_inv * delta / max(radio_rueda, 0.05)
	angulo_rodado_visual = wrapf(angulo_rodado_visual, -PI, PI)
	
	var q_rodado = Quaternion(Vector3.RIGHT, angulo_rodado_visual)
	rueda_visual.quaternion = q_direccion * rotacion_visual_base * q_rodado

func _crear_sistema_sonido() -> void:
	audio_chillido = AudioStreamPlayer3D.new()
	audio_chillido.name = "ChillidoNeumatico"
	if not audio_chillido.is_inside_tree():
		call_deferred("add_child", audio_chillido)
	
	if not _stream_chillido:
		_stream_chillido = load("res://recursos/sonidos_vehiculo/motor/automovil/Carro_Frenando_Efecto_de_Sonido.mp3")
	if _stream_chillido:
		audio_chillido.stream = _stream_chillido
		
	audio_chillido.volume_db = -40.0
	audio_chillido.max_db = 0.0
	audio_chillido.unit_size = 5.0
	audio_chillido.max_distance = 60.0
	audio_chillido.panning_strength = 1.5
	audio_chillido.autoplay = false

func get_resultant_force() -> Vector3:
	return _resultant_force
