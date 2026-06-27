extends Node3D

@export_group("Ajustes de Puerta")
@export var grupo_jugador: String = "jugador"
@export var angulo_apertura: float = 90.0
@export var tiempo_animacion: float = 0.6
@export var invertir: bool = false
@export var keep_rb_static_when_open: bool = true

# Nodos según TU árbol real
@onready var zona_proximidad: Area3D = $Area3D
@onready var icono_visual: Sprite3D = $Manija/Sprite3D
@onready var area_manija: Area3D = $Manija

var esta_abierta: bool = false
var jugador_cerca: bool = false
var _rigidbody: RigidBody3D = null
var _rb_original_freeze: bool = false
var _last_toggle_time: int = 0
const TOGGLE_COOLDOWN_MS: int = 400
@export var blink_interval: float = 0.5
var _blink_timer: Timer = null
var _zona_entrada: Area3D = null
var _jugador_en_zona_entrada: bool = false
@export var debug_puerta: bool = false

func _ready() -> void:
	if icono_visual:
		icono_visual.hide()
	# Fallbacks resilientes: si el árbol de nodos cambia entre puertas,
	# buscamos 'Manija' y el Sprite dentro en tiempo de ejecución.
	if not area_manija:
		area_manija = get_node_or_null("Manija")
		if not area_manija:
			area_manija = find_child("Manija", true, false) as Area3D
		if area_manija:
			if debug_puerta:
				print("puerta.gd: Manija encontrada por fallback ->", area_manija.get_path())
		else:
			if debug_puerta:
				print("puerta.gd: Manija NO encontrada en ", get_path())

	if area_manija and not icono_visual:
		# intentar obtener Sprite3D que sirva como icono dentro de la manija
		icono_visual = area_manija.get_node_or_null("Sprite3D") as Sprite3D
		if not icono_visual:
			icono_visual = area_manija.find_child("Sprite3D", true, false) as Sprite3D
			if icono_visual:
				if debug_puerta:
					print("puerta.gd: Icono manija encontrado ->", icono_visual.get_path())
			else:
				if debug_puerta:
					print("puerta.gd: Icono manija NO encontrado en manija")

	if zona_proximidad:
		zona_proximidad.body_entered.connect(_on_body_entered)
		zona_proximidad.body_exited.connect(_on_body_exited)
		if debug_puerta:
			print("Area3D conectada:", zona_proximidad.name)
	# Preparar la manija para recibir input desde el area
	if area_manija:
		area_manija.input_ray_pickable = true
		if not area_manija.is_connected("input_event", Callable(self, "_on_manija_input_event")):
			area_manija.connect("input_event", Callable(self, "_on_manija_input_event"))
			if debug_puerta:
				print("Manija preparada para input:", area_manija.name)

	# Crear timer para parpadeo
	if not _blink_timer:
		_blink_timer = Timer.new()
		_blink_timer.wait_time = blink_interval
		_blink_timer.one_shot = false
		add_child(_blink_timer)
		_blink_timer.connect("timeout", Callable(self, "_on_blink_timeout"))

	_rigidbody = _find_rigidbody(self)
	if _rigidbody:
		_rb_original_freeze = _rigidbody.freeze

		# Buscar y conectar ZonaEntrada dentro del vehículo para habilitar 'subir' cuando corresponda
		_zona_entrada = _rigidbody.get_node_or_null("ZonaEntrada") as Area3D
		if not _zona_entrada:
			_zona_entrada = _rigidbody.find_child("ZonaEntrada", true, false) as Area3D
		if _zona_entrada:
			_zona_entrada.body_entered.connect(_on_zona_entrada_body_entered)
			_zona_entrada.body_exited.connect(_on_zona_entrada_body_exited)
			if debug_puerta:
				print("ZonaEntrada conectada:", _zona_entrada.get_path())
		else:
			if debug_puerta:
				print("ZonaEntrada NO encontrada en vehículo:", _rigidbody.get_path())


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(grupo_jugador):
		jugador_cerca = true
		_start_blinking()
		if debug_puerta:
			print("Jugador entró al área")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(grupo_jugador):
		jugador_cerca = false
		_stop_blinking()
		if debug_puerta:
			print("Jugador salió del área")


func _on_zona_entrada_body_entered(body: Node) -> void:
	if not body:
		return
	if body.is_in_group(grupo_jugador):
		_jugador_en_zona_entrada = true
		# Si la puerta está abierta, exponer el flag en el vehículo para que el Player muestre el botón
		if esta_abierta and _rigidbody:
			_rigidbody.set("jugador_cerca", true)
			if debug_puerta:
				print("puerta.gd: jugador en ZonaEntrada y puerta abierta -> activando jugador_cerca")


func _on_zona_entrada_body_exited(body: Node) -> void:
	if not body:
		return
	if body.is_in_group(grupo_jugador):
		_jugador_en_zona_entrada = false
		if _rigidbody:
			_rigidbody.set("jugador_cerca", false)
			if debug_puerta:
				print("puerta.gd: jugador salió ZonaEntrada -> desactivando jugador_cerca")


# El jugador llama este método cuando presiona "interactuar"
func intentar_abrir() -> void:
	if jugador_cerca:
		toggle_puerta()
	else:
		if debug_puerta:
			print("Jugador no está cerca")

func _on_manija_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	var click_o_toque = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch)
	if click_o_toque and event.is_pressed():
		if jugador_cerca:
			var now = Time.get_ticks_msec()
			if now - _last_toggle_time < TOGGLE_COOLDOWN_MS:
				if debug_puerta:
					print("Toggle ignorado (cooldown) desde manija")
				return
			_last_toggle_time = now
			toggle_puerta()
		else:
			if debug_puerta:
				print("Intento de apertura fallido: Jugador lejos.")


func _start_blinking() -> void:
	if not icono_visual:
		return
	icono_visual.show()
	if _blink_timer:
		_blink_timer.start()


func _stop_blinking() -> void:
	if _blink_timer:
		_blink_timer.stop()
	if icono_visual:
		icono_visual.hide()


func _on_blink_timeout() -> void:
	if icono_visual:
		icono_visual.visible = not icono_visual.visible


func _unhandled_input(event: InputEvent) -> void:
	if not jugador_cerca:
		return

	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch = event is InputEventScreenTouch and event.pressed
	var is_key_e = event is InputEventKey and event.pressed and event.keycode == KEY_E

	# Si es click/touch, comprobar que el raycast impactó la manija cuando la puerta está abierta
	if is_click or is_touch:
		var pos: Vector2 = event.position
		var cam = get_viewport().get_camera_3d()
		if not cam:
			return
		var col = _ray_hit_collider(pos, cam)
		if esta_abierta:
			# Solo permitir toggle si el raycast golpeó el Area de la manija
			if col != area_manija and not _is_parent_of(area_manija, col):
				return

		var now = Time.get_ticks_msec()
		if now - _last_toggle_time < TOGGLE_COOLDOWN_MS:
			if debug_puerta:
				print("Toggle ignorado (cooldown)")
			return
		_last_toggle_time = now
		toggle_puerta()

	elif is_key_e:
		var now2 = Time.get_ticks_msec()
		if now2 - _last_toggle_time < TOGGLE_COOLDOWN_MS:
			if debug_puerta:
				print("Toggle ignorado (cooldown)")
			return
		_last_toggle_time = now2
		toggle_puerta()


func toggle_puerta() -> void:
	esta_abierta = !esta_abierta
	var direccion = -1.0 if invertir else 1.0
	var angulo_final = (angulo_apertura * direccion) if esta_abierta else 0.0

	if _rigidbody:
		_rigidbody.freeze = true
		_rigidbody.linear_velocity = Vector3.ZERO
		_rigidbody.angular_velocity = Vector3.ZERO

	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", angulo_final, tiempo_animacion) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_tween_done)
	if debug_puerta:
		print("Puerta toggled →", "abierta" if esta_abierta else "cerrada")
	if debug_puerta:
		print("Puerta toggled →", "abierta" if esta_abierta else "cerrada")

	# Exponer bandera para que el jugador vea el botón sólo si está en ZonaEntrada
	if _rigidbody:
		if esta_abierta:
			if _jugador_en_zona_entrada:
				_rigidbody.set("jugador_cerca", true)
		else:
			_rigidbody.set("jugador_cerca", false)


func _on_tween_done() -> void:
	if not _rigidbody:
		return
	if esta_abierta and keep_rb_static_when_open:
		_rigidbody.freeze = true
		_rigidbody.linear_velocity = Vector3.ZERO
		_rigidbody.angular_velocity = Vector3.ZERO
	else:
		_rigidbody.freeze = _rb_original_freeze


func _process(delta: float) -> void:
	# Si el jugador ya está montado en el vehículo, cerrar la puerta automáticamente
	if _rigidbody:
		var jugador_ref = _rigidbody.get("jugador_ref")
		if jugador_ref and esta_abierta:
			# Cerrar puerta si el jugador se ha subido
			if debug_puerta:
				print("puerta.gd: jugador detectado en vehiculo -> cerrando puerta automáticamente")
			toggle_puerta()


func _find_rigidbody(node: Node) -> RigidBody3D:
	var n = node.get_parent()
	while n:
		if n is RigidBody3D:
			return n
		n = n.get_parent()
	return null


func _is_parent_of(ancestor: Node, node: Node) -> bool:
	if ancestor == null or node == null:
		return false
	var p = node.get_parent()
	while p:
		if p == ancestor:
			return true
		p = p.get_parent()
	return false

func _ray_hit_collider(pos: Vector2, cam: Camera3D) -> Node:
	var from = cam.project_ray_origin(pos)
	var dir = cam.project_ray_normal(pos)
	var to = from + dir * 2000.0
	var space = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = from
	ray_params.to = to
	ray_params.collide_with_areas = true
	ray_params.collide_with_bodies = true
	var result = space.intersect_ray(ray_params)
	if result:
		return result.get("collider", null)
	return null
