extends Node3D

signal enganche_conectado(camion: Node, remolque: Node)

## true  → este Enganche está en el REMOLQUE (receptor, no inicia nada)
## false → este Enganche está en el CAMIÓN  (iniciador de la conexión)
@export var es_remolque: bool = false

var area:   Area3D              = null
var joint:  Joint3D  = null
var marker: Marker3D            = null

var enganche_remoto: Node       = null
var conectado:       bool       = false
var _recien_conectado: bool     = false
@export var debug_enganche: bool = false

var audio_player: AudioStreamPlayer3D = null
var audio_player_crash: AudioStreamPlayer3D = null

@export_group("Dimensiones de Detección")
@export var area_extents: Vector3 = Vector3(1.0, 0.6, 1.0) ## Dimensiones de la caja de detección
@export var area_offset: Vector3 = Vector3(0.0, 0.01, 0.0) ## Compensación local de la caja de detección

@export_group("Realismo del Enganche")
@export var limite_velocidad_acople: float = 2.5 ## Velocidad relativa máxima en m/s (2.5 m/s ≈ 9 km/h)
@export var fuerza_impacto_suspension: float = 0.08 ## Factor de fuerza del peso del remolque transmitido como impacto
@export var duracion_alineacion: float = 0.25 ## Tiempo que dura la alineación suave (snap)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# ── Inicialización y Creación por Código de Componentes de Colisión y Junta ──
	area = get_node_or_null("Area3D")
	if not area:
		area = Area3D.new()
		area.name = "Area3D"
		add_child(area)
		
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		box.size = area_extents
		collision_shape.shape = box
		collision_shape.position = area_offset
		area.add_child(collision_shape)
	
	joint = get_node_or_null("PinJoint3D")
	if not joint:
		joint = PinJoint3D.new()
		joint.name = "PinJoint3D"
		add_child(joint)
		
	marker = get_node_or_null("Marker3D")
	if not marker:
		marker = Marker3D.new()
		marker.name = "Marker3D"
		add_child(marker)
	
	# Instanciar el reproductor de audio dinámicamente para el acople/desacople
	audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = load("res://recursos/sonidos_vehiculo/sonidos_metalicos/clank.mp3")
	audio_player.unit_size = 12.0
	audio_player.max_distance = 80.0
	audio_player.bus = &"Master"
	add_child(audio_player)
	
	# Instanciar el reproductor de audio dinámicamente para el choque
	audio_player_crash = AudioStreamPlayer3D.new()
	audio_player_crash.stream = load("res://recursos/sonidos_vehiculo/sonidos_metalicos/car_crash.mp3")
	audio_player_crash.unit_size = 15.0
	audio_player_crash.max_distance = 100.0
	audio_player_crash.bus = &"Master"
	add_child(audio_player_crash)

	area.monitoring  = true
	area.monitorable = true
	# Remolque: visible en capa 8. Camión: detecta capa 8.
	if es_remolque:
		area.collision_layer = 8
		area.collision_mask  = 0
		area.monitoring      = false
		area.monitorable     = true
		add_to_group("enganche_remolque")
	else:
		area.collision_layer = 0
		area.collision_mask  = 8
		area.monitoring      = true
		area.monitorable     = false
	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)

# ─────────────────────────────────────────────────────────────────────────────
func _on_area_entered(otra_area: Area3D) -> void:
	# Solo el camión inicia; el remolque nunca llega aquí (monitoring=false)
	if conectado or es_remolque:
		return

	var otro = otra_area.get_parent()
	if not otro or otro.get("es_remolque") != true:
		return

	# Verificar límite de velocidad de impacto para realismo
	var cuerpo_propio := _buscar_cuerpo(self)
	var cuerpo_remolque := _buscar_cuerpo(otro)
	if cuerpo_propio and cuerpo_remolque:
		var vel_relativa = (cuerpo_propio.linear_velocity - cuerpo_remolque.linear_velocity).length()
		if vel_relativa > limite_velocidad_acople:
			# Si va muy rápido, el enganche falla y reproduce el sonido de choque
			if audio_player_crash:
				audio_player_crash.pitch_scale = randf_range(0.9, 1.1)
				audio_player_crash.play()
			if debug_enganche:
				print("Enganche fallido: Demasiado rápido (", vel_relativa, " m/s)")
			return

	_conectar_a(otro)

func _on_area_exited(otra_area: Area3D) -> void:
	if not conectado or _recien_conectado:
		return
	var otro = otra_area.get_parent()
	if otro == enganche_remoto:
		soltar()

# ─────────────────────────────────────────────────────────────────────────────
func _conectar_a(otro_enganche: Node) -> void:
	var cuerpo_propio   := _buscar_cuerpo(self)
	var cuerpo_remolque := _buscar_cuerpo(otro_enganche)

	if not cuerpo_propio or not cuerpo_remolque:
		push_warning("Enganche: no se encontró RigidBody3D en uno de los lados")
		return

	conectado        = true
	_recien_conectado = true
	enganche_remoto  = otro_enganche
	
	# Excepción de colisión para evitar empuje físico entre ambos cuerpos
	cuerpo_propio.add_collision_exception_with(cuerpo_remolque)
	cuerpo_remolque.add_collision_exception_with(cuerpo_propio)
	
	# Alinear la posición instantáneamente para centrar el punto de enganche exactamente
	var target_basis = cuerpo_propio.global_transform.basis
	var local_offset = cuerpo_remolque.to_local(otro_enganche.global_position)
	var desired_origin: Vector3 = marker.global_position - target_basis * local_offset
	cuerpo_remolque.global_position = desired_origin
	
	# Activar la junta física directamente
	_activar_joint(cuerpo_propio, cuerpo_remolque)
	
	# Ejecutar efecto visual en el indicador
	_ejecutar_efecto_enganche()
	if otro_enganche.has_method("_ejecutar_efecto_enganche"):
		otro_enganche.call("_ejecutar_efecto_enganche")
	
	# Aplicar impacto físico y compresión de suspensión en la conexión (Impulso único de impacto)
	var pos_local_camion = cuerpo_propio.to_local(marker.global_position)
	var masa_impacto = cuerpo_remolque.mass * fuerza_impacto_suspension
	cuerpo_propio.apply_impulse(Vector3.DOWN * masa_impacto, pos_local_camion)
	
	# Reproducir sonido de enganche
	if audio_player:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()
		
	get_tree().create_timer(0.5).timeout.connect(func(): _recien_conectado = false, CONNECT_ONE_SHOT)

	if has_node("/root/NotificationManager"):
		get_node("/root/NotificationManager").notificar_exito("Remolque Enganchado")

	if cuerpo_remolque.has_method("desactivar_patas"):
		cuerpo_remolque.desactivar_patas()
	if cuerpo_remolque.has_method("enganchado_a"):
		cuerpo_remolque.enganchado_a(cuerpo_propio)

	if debug_enganche:
		print("Enganchado: ", cuerpo_propio.name, " <-> ", cuerpo_remolque.name)
	enganche_conectado.emit(cuerpo_propio, cuerpo_remolque)

func _activar_joint(cuerpo_a: PhysicsBody3D, cuerpo_b: PhysicsBody3D) -> void:
	if not conectado:
		return
	# Colocar el joint exactamente en el punto de enganche
	joint.global_transform = marker.global_transform
	joint.node_a = cuerpo_a.get_path()
	joint.node_b = cuerpo_b.get_path()

func soltar() -> void:
	if not conectado:
		return

	var cuerpo_propio   := _buscar_cuerpo(self)
	var cuerpo_remolque := _buscar_cuerpo(enganche_remoto) if enganche_remoto else null

	joint.node_a = NodePath("")
	joint.node_b = NodePath("")

	if cuerpo_propio and cuerpo_remolque:
		cuerpo_propio.remove_collision_exception_with(cuerpo_remolque)
		cuerpo_remolque.remove_collision_exception_with(cuerpo_propio)
		if cuerpo_remolque.has_method("activar_patas"):
			cuerpo_remolque.activar_patas()
		if cuerpo_remolque.has_method("desenganchado_de"):
			cuerpo_remolque.desenganchado_de(cuerpo_propio)
			
		# Al soltar, también reproducir el sonido metálico de desacople
		if audio_player:
			audio_player.pitch_scale = randf_range(0.85, 0.95)
			audio_player.play()

		if has_node("/root/NotificationManager"):
			get_node("/root/NotificationManager").notificar("Remolque Desenganchado", "info")

	conectado         = false
	enganche_remoto   = null
	_recien_conectado = false
	if debug_enganche:
		print("Desenganchado")

# ─────────────────────────────────────────────────────────────────────────────
## Sube por el árbol desde 'nodo' hasta encontrar el primer RigidBody3D.
func _buscar_cuerpo(nodo: Node) -> PhysicsBody3D:
	var n := nodo
	while n != null:
		if n is PhysicsBody3D:
			return n as PhysicsBody3D
		n = n.get_parent()
	return null

# ─── Indicador Visual de Enganche Cercano ───
var _indicador: MeshInstance3D = null

func _crear_indicador() -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.name = "IndicadorEnganche"
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	mi.mesh = quad
	
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = "shader_type spatial;\n" + \
		"render_mode unshaded, depth_test_disabled, cull_disabled;\n" + \
		"uniform vec4 color : source_color = vec4(0.0, 0.95, 0.4, 1.0);\n" + \
		"uniform float speed = 5.0;\n" + \
		"void vertex() {\n" + \
		"	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);\n" + \
		"}\n" + \
		"void fragment() {\n" + \
		"	vec2 uv = UV - vec2(0.5);\n" + \
		"	float dist = length(uv);\n" + \
		"	float ring = smoothstep(0.48, 0.44, dist) * smoothstep(0.30, 0.34, dist);\n" + \
		"	float pulse = 0.3 + 0.7 * sin(TIME * speed);\n" + \
		"	ALBEDO = color.rgb;\n" + \
		"	ALPHA = ring * color.a * pulse;\n" + \
		"}"
	mat.shader = sh
	mi.material_override = mat
	mi.position = Vector3(0, 0.15, 0)
	return mi

func _ejecutar_efecto_enganche() -> void:
	if not _indicador:
		return
	var mat = _indicador.material_override as ShaderMaterial
	if mat:
		# Destello de color cian brillante
		mat.set_shader_parameter("color", Color(0.2, 1.0, 1.0, 2.0))
		mat.set_shader_parameter("speed", 12.0)
	
	var tween = create_tween().set_parallel(true)
	# Expandir tamaño
	tween.tween_property(_indicador, "scale", Vector3(3.5, 3.5, 3.5), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Desvanecer modulando el color
	if mat:
		tween.tween_method(func(val: float):
			mat.set_shader_parameter("color", Color(0.2, 1.0, 1.0, val))
		, 2.0, 0.0, 0.4)
	
	tween.set_parallel(false)
	tween.tween_callback(func():
		_set_indicador_visible(false)
		_indicador.scale = Vector3(1.0, 1.0, 1.0)
	)

func _set_indicador_visible(estado: bool) -> void:
	if estado:
		if not _indicador:
			_indicador = _crear_indicador()
			add_child(_indicador)
		_indicador.visible = true
	else:
		if _indicador:
			_indicador.visible = false

func _process(_delta: float) -> void:
	if es_remolque:
		return
		
	if conectado:
		_set_indicador_visible(false)
		if is_instance_valid(enganche_remoto) and enganche_remoto.has_method("_set_indicador_visible"):
			enganche_remoto.call("_set_indicador_visible", false)
		return
		
	var remolques = get_tree().get_nodes_in_group("enganche_remolque")
	var mas_cercano: Node3D = null
	var dist_min: float = 12.0 # Activar cuando estén a 12 metros o menos
	
	for r in remolques:
		if r is Node3D:
			var d = global_position.distance_to(r.global_position)
			if d < dist_min:
				dist_min = d
				mas_cercano = r
				
	if mas_cercano:
		_set_indicador_visible(true)
		if mas_cercano.has_method("_set_indicador_visible"):
			mas_cercano.call("_set_indicador_visible", true)
	else:
		_set_indicador_visible(false)
		for r in remolques:
			if r.has_method("_set_indicador_visible"):
				r.call("_set_indicador_visible", false)
