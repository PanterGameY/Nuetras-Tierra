extends RayCast3D
class_name RuedaTrailer

static var _stream_chillido: AudioStream = null

@export var debug_raycast: bool = false

# ════════════════════════════════════════════════════════════════════
# FÍSICA SIMPLIFICADA PARA REMOLQUES
# ════════════════════════════════════════════════════════════════════

@export_group("Suspensión")
@export var largo_reposo: float = 0.12
@export var radio_rueda: float = 0.55
@export var rigidez_muelle: float = 180000.0
@export var amortiguacion: float = 14000.0
@export var fuerza_suspension_max: float = 300000.0

@export_group("Fricción Lateral")
@export var agarre_lateral: float = 24.0
@export var respuesta_lateral: float = 2200.0

var coche: RigidBody3D
@export_group("Visuales")
@export var tipo_rueda_id: String = ""
@export var rueda_visual: Node3D
@export var color_rin: Color = Color(0, 0, 0, 0)
@export var metallic_rin: float = -1.0
@export var roughness_rin: float = -1.0
var rotacion_visual_base: Quaternion = Quaternion.IDENTITY
var angulo_rodado_visual: float = 0.0
var _visual_generado_dinamico: bool = false

# Efectos dinámicos
var polvo_emisor: CPUParticles3D = null
var audio_chillido: AudioStreamPlayer3D = null
var derrapando: bool = false
var deslizamiento_lateral: float = 0.0
var _vol_objetivo_db: float = -40.0

func _ready() -> void:
	coche = _buscar_coche(get_parent())
	if coche:
		add_exception(coche)

	if tipo_rueda_id != "":
		aplicar_tipo_rueda(tipo_rueda_id)
	else:
		if not rueda_visual and get_child_count() > 0:
			rueda_visual = get_child(0)
		if rueda_visual:
			rotacion_visual_base = rueda_visual.quaternion

	hit_from_inside = true
	hit_back_faces = true
	target_position = Vector3(0, -(largo_reposo + radio_rueda + 0.45), 0)
	enabled = true
	if (int(collision_mask) & 1) == 0:
		collision_mask = int(collision_mask) | 1

	_crear_sistema_sonido()

	force_raycast_update()
	if debug_raycast:
		print("RuedaTrailer ready: ", name, " | mask=", collision_mask, " | cast_to=", target_position)

## Cambia dinámicamente el modelo visual de la rueda por uno del catálogo de trailers
func aplicar_tipo_rueda(id_tipo: String) -> void:
	tipo_rueda_id = id_tipo
	var config = CatalogoRuedasTrailer.obtener_config(id_tipo)
	if config.is_empty():
		return

	# Si es tipo original y ya tenemos un visual estático que no fue generado por script, conservarlo
	if id_tipo == "original_carpado" and rueda_visual and not _visual_generado_dinamico:
		rotacion_visual_base = rueda_visual.quaternion
		return

	# Limpiar el visual previo si existía
	if rueda_visual and is_instance_valid(rueda_visual):
		rueda_visual.queue_free()
		rueda_visual = null

	var nuevo_visual = CatalogoRuedasTrailer.instanciar_nodo_visual(id_tipo)
	if nuevo_visual:
		nuevo_visual.name = "VisualRuedaTrailer"
		add_child(nuevo_visual)
		rueda_visual = nuevo_visual
		_visual_generado_dinamico = true
		rotacion_visual_base = nuevo_visual.quaternion

	# Actualizar parámetros físicos si están en el config
	if config.has("radio_rueda"):
		radio_rueda = float(config["radio_rueda"])
	if config.has("largo_reposo"):
		largo_reposo = float(config["largo_reposo"])

	target_position = Vector3(0, -(largo_reposo + radio_rueda + 0.45), 0)

	# Aplicar color y acabado si se especificó
	if color_rin.a > 0.001 or metallic_rin >= 0.0 or roughness_rin >= 0.0:
		aplicar_color_rin(color_rin, metallic_rin, roughness_rin)
	elif config.has("acabado_defecto"):
		var def_finish = config["acabado_defecto"] as Dictionary
		if def_finish:
			aplicar_color_rin(def_finish.get("color", Color.WHITE), def_finish.get("metallic", 0.8), def_finish.get("roughness", 0.2))

## Permite personalizar el acabado y color de los rines de la rueda (ignora cauchos/neumáticos)
func aplicar_color_rin(col: Color, met: float = -1.0, rough: float = -1.0) -> void:
	color_rin = col
	metallic_rin = met
	roughness_rin = rough
	if not rueda_visual:
		return
	_aplicar_color_rin_recursivo(rueda_visual, col, met, rough)

func _aplicar_color_rin_recursivo(nodo: Node, col: Color, met: float, rough: float) -> void:
	if nodo is MeshInstance3D:
		var m_name = nodo.name.to_lower()
		if not ("n1" in m_name or "n2" in m_name or "tire" in m_name or "caucho" in m_name or "neumatico" in m_name or "llanta" in m_name):
			# Material override o superficies
			if nodo.material_override and nodo.material_override is StandardMaterial3D:
				var m = nodo.material_override.duplicate() as StandardMaterial3D
				if col.a > 0.001:
					m.albedo_color = col
				if met >= 0.0:
					m.metallic = met
				if rough >= 0.0:
					m.roughness = rough
				nodo.material_override = m
			for i in range(nodo.get_surface_override_material_count()):
				var sm = nodo.get_surface_override_material(i)
				if sm and sm is StandardMaterial3D:
					var m2 = sm.duplicate() as StandardMaterial3D
					if col.a > 0.001:
						m2.albedo_color = col
					if met >= 0.0:
						m2.metallic = met
					if rough >= 0.0:
						m2.roughness = rough
					nodo.set_surface_override_material(i, m2)
	for hijo in nodo.get_children():
		_aplicar_color_rin_recursivo(hijo, col, met, rough)


func _physics_process(delta: float) -> void:
	force_raycast_update()

	# Los visuales se actualizan siempre (suspensión + giro)
	_actualizar_visual(delta)

	if not coche:
		return
	if not is_colliding():
		if polvo_emisor:
			polvo_emisor.emitting = false
		if audio_chillido and audio_chillido.playing:
			_vol_objetivo_db = -40.0
			audio_chillido.volume_db = lerpf(audio_chillido.volume_db, _vol_objetivo_db, delta * 9.0)
			if audio_chillido.volume_db <= -38.0:
				audio_chillido.stop()
		return

	_aplicar_fisica_remolque(delta)

func _aplicar_fisica_remolque(delta: float) -> void:
	# No aplicar fuerzas si el cuerpo está congelado o durmiendo.
	if coche.freeze or coche.sleeping:
		return
	var punto_contacto: Vector3 = get_collision_point()
	var radio_vec: Vector3 = punto_contacto - coche.global_position

	var basis_ortho: Basis = coche.global_transform.basis.orthonormalized()
	var up: Vector3    = basis_ortho.y
	var right: Vector3 = basis_ortho.x
	var forward: Vector3 = -basis_ortho.z

	# — Suspensión con Tope Duro Anti-Hundimiento —
	var distancia: float   = global_position.distance_to(punto_contacto)
	var recorrido_actual: float = maxf(distancia - radio_rueda, 0.0)
	var compresion: float  = clampf(largo_reposo - recorrido_actual, 0.0, largo_reposo)

	var vel_punto: Vector3  = coche.linear_velocity + coche.angular_velocity.cross(radio_vec)
	var vel_vertical: float = up.dot(vel_punto)

	var f_suspension: float = (compresion * rigidez_muelle) - (vel_vertical * amortiguacion)

	# TOPE DURO (BUMP STOP): Si el suelo penetra más allá del recorrido del muelle (distancia < radio_rueda),
	# el neumático y el chasis hacen tope físico. Aplicamos fuerza progresiva multiplicada
	# y neutralizamos la velocidad de caída para que NUNCA atraviese el mapa.
	if distancia < radio_rueda:
		var sobre_penetracion: float = radio_rueda - distancia
		f_suspension += sobre_penetracion * rigidez_muelle * 6.0
		if vel_vertical < 0.0:
			f_suspension -= vel_vertical * amortiguacion * 3.0

	var f_max_dinamica: float = maxf(fuerza_suspension_max, 500000.0)
	f_suspension = clampf(f_suspension, 0.0, f_max_dinamica)

	coche.apply_force(up * f_suspension, radio_vec)

	# — Fricción lateral con agarre firme de servicio pesado —
	var vel_lateral: float = right.dot(vel_punto)
	deslizamiento_lateral = vel_lateral
	
	var fn_lateral = maxf(f_suspension, 2000.0)
	var agarre_lat_efectivo = agarre_lateral
	
	# Detectar derrape solo en deslizamientos laterales severos (> 5.5 m/s o ~20 km/h)
	if absf(vel_lateral) > 5.5:
		derrapando = true
		agarre_lat_efectivo *= 0.85 # Caída suave y predecible, sin pérdida descontrolada
	else:
		derrapando = false

	var f_lateral: float   = -vel_lateral * respuesta_lateral * (fn_lateral / 1000.0)
	var limite_lat: float  = fn_lateral * agarre_lat_efectivo
	f_lateral = clamp(f_lateral, -limite_lat, limite_lat)

	coche.apply_force(right * f_lateral, radio_vec)

	# — Fricción longitudinal / Frenos —
	var vel_forward: float = forward.dot(vel_punto)
	var freno_activo: bool = true
	if coche.has_method("tiene_patas_abajo") and coche.tiene_patas_abajo():
		freno_activo = true
	elif coche.has_method("esta_enganchado"):
		freno_activo = not coche.esta_enganchado()
	elif coche.get("_cuerpo_camion") != null:
		freno_activo = false
		
	var fuerza_traccion: float = 0.0
	var atenuacion_baja_vel: float = clamp(abs(vel_forward) / 0.1, 0.0, 1.0)
	
	if freno_activo:
		var fuerza_freno_total: float = 38000.0
		var limite_freno: float = f_suspension * 8.0
		fuerza_traccion = -sign(vel_forward) * min(fuerza_freno_total, limite_freno) * atenuacion_baja_vel
	else:
		var resistencia_rodadura: float = 32.0
		fuerza_traccion = -sign(vel_forward) * min(abs(vel_forward) * resistencia_rodadura, f_suspension * 6.0) * atenuacion_baja_vel

	coche.apply_force(forward * fuerza_traccion, radio_vec)

	# Partículas de polvo (Solo emite si el trailer realmente se desplaza por encima de 1.2 m/s en el mundo real)
	if polvo_emisor:
		polvo_emisor.emitting = false

	# Chillido de neumáticos (solo ante derrapes reales con velocidad y deriva lateral acusada)
	if audio_chillido:
		var chillando = derrapando and absf(vel_forward) > 3.5 and absf(vel_lateral) > 5.0
		if chillando:
			_vol_objetivo_db = -4.0
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

	# — Posición de la suspensión (viaje del muelle) —
	var ty: float = -largo_reposo
	if is_colliding():
		# Centro de rueda apoyado directamente sobre el punto de contacto
		var local_punto: Vector3 = to_local(get_collision_point())
		ty = maxf(local_punto.y + radio_rueda, -largo_reposo)

	rueda_visual.position.y = lerp(rueda_visual.position.y, ty, delta * 25.0)

	# — Rotación por movimiento —
	# Usa la velocidad del cuerpo padre proyectada sobre su eje de avance.
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

	# Si la rueda está invertida (lado derecho con rotación Y de 180°),
	# su vector RIGHT local apunta hacia la izquierda en el chasis del coche.
	# Detectamos esto comparando el eje RIGHT de la rueda contra el eje RIGHT del coche:
	var factor_lado: float = 1.0
	if coche:
		var wheel_right = global_transform.basis.x.normalized()
		var car_right = coche.global_transform.basis.x.normalized()
		if wheel_right.dot(car_right) < 0.0:
			factor_lado = -1.0

	angulo_rodado_visual -= (velocidad_avance * factor_lado * delta) / max(radio_rueda, 0.01)
	angulo_rodado_visual  = wrapf(angulo_rodado_visual, -PI, PI)

	rueda_visual.quaternion = rotacion_visual_base * Quaternion(Vector3.RIGHT, angulo_rodado_visual)

func _crear_sistema_polvo() -> void:
	polvo_emisor = CPUParticles3D.new()
	polvo_emisor.name = "PolvoTrailer"
	add_child(polvo_emisor)
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.5, 0.5)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.68, 0.62, 0.54, 0.28)
	
	quad_mesh.material = mat
	polvo_emisor.mesh = quad_mesh

	polvo_emisor.emitting = false
	polvo_emisor.amount = 25
	polvo_emisor.lifetime = 1.0
	polvo_emisor.one_shot = false
	polvo_emisor.randomness = 0.5
	polvo_emisor.local_coords = false
	polvo_emisor.direction = Vector3(0, 0.3, 1)
	polvo_emisor.spread = 35.0
	polvo_emisor.gravity = Vector3(0, 0.8, 0)
	polvo_emisor.initial_velocity_min = 1.5
	polvo_emisor.initial_velocity_max = 4.0
	
	var gradiente = Gradient.new()
	gradiente.set_color(0, Color(0.24, 0.24, 0.24, 0.65))
	gradiente.set_color(1, Color(0.12, 0.12, 0.12, 0.0))
	polvo_emisor.color_ramp = gradiente
	
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 3.5))
	polvo_emisor.scale_amount_curve = curve
	polvo_emisor.scale_amount_min = 0.5
	polvo_emisor.scale_amount_max = 2.0

func _crear_sistema_sonido() -> void:
	audio_chillido = AudioStreamPlayer3D.new()
	audio_chillido.name = "ChillidoTrailer"
	add_child(audio_chillido)
	
	if not _stream_chillido:
		_stream_chillido = load("res://recursos/sonidos_vehiculo/motor/automovil/Carro_Frenando_Efecto_De_Sonido.mp3")
	
	if _stream_chillido:
		audio_chillido.stream = _stream_chillido
		
	audio_chillido.volume_db = -40.0
	audio_chillido.max_db = 0.0
	audio_chillido.unit_size = 4.0
	audio_chillido.max_distance = 50.0
	audio_chillido.panning_strength = 1.5
	audio_chillido.autoplay = false

func configurar_desde_masa(masa_total: float, num_ruedas: int) -> void:
	var peso_por_rueda: float = masa_total * 9.81 / max(num_ruedas, 1)
	# Suspensión rígida de servicio pesado para remolques de carga (recorrido calibrado de 16cm)
	# En reposo se comprime ~28% de su carrera (~4.5cm), garantizando firmeza y soporte sin sobre-penetración
	var compresion_repo: float = 0.28
	largo_reposo = 0.16
	rigidez_muelle = peso_por_rueda / maxf(compresion_repo * largo_reposo, 0.001)
	amortiguacion = rigidez_muelle * 0.075
	fuerza_suspension_max = peso_por_rueda * 8.0
	hit_from_inside = true
	hit_back_faces = true
	target_position = Vector3(0, -(largo_reposo + radio_rueda + 0.35), 0)
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