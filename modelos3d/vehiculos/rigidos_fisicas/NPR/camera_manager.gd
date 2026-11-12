extends Node3D

# =======================================================================
# CameraManager — Gestiona y crea dinámicamente las cámaras del vehículo.
# Crea por código las cámaras: Libre (Orbital 360°), Interna, Paragolpes, Aérea y Cinemática.
# Soporta detección dinámica de remolques/tráilers, exclusión de colisiones
# y adaptación automática de distancia/encuadre para convoyes largos.
# Índice 0: Libre (Orbital 360°), Índice 1: Interna (Cabina)
# =======================================================================

@export_group("Configuración Inicial")
@export var camara_inicial: int = 0  # 0=Libre (Orbital 360°), 1=Interna
@export var auto_centrado_libre: bool = false # Si es false, la cámara libre no se auto-centra al conducir

@export_group("Debug")
@export var debug_camera_manager: bool = true

# --- Mejora: opciones "épicas" ------------------------------------------------
@export_group("Mejoras")
@export var transicion_suave: float = 0.45 # segundos para blend entre cámaras
@export var occlusion_enabled: bool = true
@export var occlusion_mask: int = 1 # Capa 1 por defecto (Mundo/Estáticos)
@export var auto_fov_enabled: bool = true
@export var fov_min: float = 60.0
@export var fov_max: float = 85.0
@export var fov_speed_factor: float = 0.45 # Factor de aumento de FOV con velocidad
@export var orbit_damping: float = 8.0
@export var shake_enabled: bool = true
@export var shake_decay: float = 4.0
@export var shake_strength: float = 0.06

# --- LISTA CENTRALIZADA DE CÁMARAS ---
var listado_camaras: Array[Camera3D] = []
var nombres_camaras: Array[String] = []
var indice_actual: int = -1

# Referencias de cámaras
var cam_interna: Camera3D = null
var cam_externa_camera: Camera3D = null
var cam_externa_brazo: Node3D = null
var cam_externa_spring: SpringArm3D = null

# Nodos dinámicos de soporte
var _brazo_aereo_node: Node3D = null
var _brazo_cine_node: Node3D = null

# Parámetros e historial de la órbita (Cámara Libre)
var _brazo_yaw: float = 0.0
var _brazo_pitch: float = -12.0
var _brazo_sensibilidad: float = 0.18
var _brazo_limite_pitch: Vector2 = Vector2(-45.0, 30.0)
var _last_input_time: float = 0.0

# Parámetros de Cámara Cinemática
var _cine_yaw_auto: float = 0.0

# Espejo de cámara externa (opcional)
var external_camera_target: Camera3D = null
var _user_zoom_offset: float = 0.0

# Estado de tráiler / remolque acoplado
var _remolque_actual: RigidBody3D = null
var _remolque_rids_excluidos: Array[RID] = []
var _extra_distancia_remolque: float = 0.0
var _remolque_check_timer: float = 0.0

signal camara_cambiada(indice: int)

# Estado de transición / shake
var _blending: bool = false
var _blend_timer: float = 0.0
var _blend_duration: float = 0.0
var _blend_from: Transform3D = Transform3D()
var _blend_to: Transform3D = Transform3D()
var _blend_cam: Camera3D = null

var _shake_velocity: Vector3 = Vector3.ZERO

var _blend_target_cam: Camera3D = null
var _blend_from_fov: float = 0.0
var _blend_to_fov: float = 0.0
var _vehicle_radius: float = 3.0

func _start_camera_blend(from_cam: Camera3D, to_cam: Camera3D, duration: float) -> void:
	if not from_cam or not to_cam:
		if to_cam and is_instance_valid(to_cam):
			to_cam.make_current()
		return
	if _blend_cam == null:
		_blend_cam = Camera3D.new()
		_blend_cam.name = "CameraBlend_Temp"
		add_child(_blend_cam)
	_blend_from = from_cam.global_transform
	_blend_to = to_cam.global_transform
	_blend_from_fov = from_cam.fov
	_blend_to_fov = to_cam.fov
	_blend_target_cam = to_cam
	_blend_cam.global_transform = _blend_from
	_blend_cam.fov = _blend_from_fov
	_blend_cam.current = true
	from_cam.current = false
	to_cam.current = false
	_blending = true
	_blend_timer = 0.0
	_blend_duration = max(0.001, duration)

func aplicar_sacudida(intensidad: float) -> void:
	if not shake_enabled:
		return
	var rnd = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
	_shake_velocity += rnd * max(0.0, float(intensidad))

func _ready() -> void:
	_detectar_camara_interna_de_escena()
	_crear_camaras_codigo()
	_conectar_ui()

	var veh := get_parent()
	var activo: bool = veh != null and veh.get("activo") == true
	if activo:
		seleccionar_camara(camara_inicial, true)
	else:
		desactivar_camaras()

func _detectar_camara_interna_de_escena() -> void:
	var todas_cams: Array[Camera3D] = []
	_buscar_cams_recursivo(self, todas_cams)
	
	for cam in todas_cams:
		var n := cam.name.to_lower()
		var pn := cam.get_parent().name.to_lower() if cam.get_parent() else ""
		var is_internal := n.contains("intern") or n.contains("cabina") or n.contains("driver") or n.contains("cockpit") \
						or pn.contains("intern") or pn.contains("cabina")
		if is_internal:
			cam_interna = cam
			break
			
	if not cam_interna and todas_cams.size() > 0:
		cam_interna = todas_cams[0]

func _buscar_cams_recursivo(nodo: Node, cams: Array[Camera3D]) -> void:
	for hijo in nodo.get_children():
		if hijo is Camera3D:
			cams.append(hijo)
		_buscar_cams_recursivo(hijo, cams)

func _crear_camaras_codigo() -> void:
	listado_camaras.clear()
	nombres_camaras.clear()

	var vehicle := get_parent()
	var pivot: Vector3 = vehicle.global_transform.origin if vehicle else global_transform.origin
	var radius: float = 3.0
	if vehicle:
		var maxd: float = 0.0
		var stack: Array = [vehicle]
		while stack.size() > 0:
			var n = stack.pop_back()
			if n is MeshInstance3D and n.mesh:
				var m_aabb: AABB = n.mesh.get_aabb()
				var local_min = m_aabb.position
				var local_max = m_aabb.position + m_aabb.size
				var corners := [
					Vector3(local_min.x, local_min.y, local_min.z),
					Vector3(local_min.x, local_min.y, local_max.z),
					Vector3(local_min.x, local_max.y, local_min.z),
					Vector3(local_min.x, local_max.y, local_max.z),
					Vector3(local_max.x, local_min.y, local_min.z),
					Vector3(local_max.x, local_min.y, local_max.z),
					Vector3(local_max.x, local_max.y, local_min.z),
					Vector3(local_max.x, local_max.y, local_max.z),
				]
				for c in corners:
					var world_c: Vector3 = n.global_transform * c
					var d: float = pivot.distance_to(world_c)
					if d > maxd:
						maxd = d
			for ch in n.get_children():
				stack.append(ch)
		if maxd > 0.01:
			radius = max(maxd, 1.0)
	_vehicle_radius = radius

	# ---- 0. CÁMARA LIBRE (ORBITAL 360° INTERACTIVA) — PRIMERA CÁMARA ----
	cam_externa_brazo = Node3D.new()
	cam_externa_brazo.name = "BrazoCamara_Dinamico"
	cam_externa_brazo.set_as_top_level(true)
	add_child(cam_externa_brazo)
	cam_externa_brazo.global_position = pivot + Vector3(0.0, radius * 0.25, 0.0)

	cam_externa_spring = SpringArm3D.new()
	cam_externa_spring.name = "SpringArm_Dinamico"
	cam_externa_spring.collision_mask = occlusion_mask if occlusion_enabled else 0
	cam_externa_spring.margin = 0.25
	cam_externa_spring.spring_length = clamp(radius * 2.2 + 1.0, 3.0, 80.0)
	cam_externa_spring.position = Vector3.ZERO
	cam_externa_brazo.add_child(cam_externa_spring)
	
	if vehicle and vehicle.has_method("get_rid"):
		cam_externa_spring.add_excluded_object(vehicle.get_rid())

	cam_externa_camera = Camera3D.new()
	cam_externa_camera.name = "CameraLibre_Dinamica"
	cam_externa_camera.position = Vector3.ZERO
	cam_externa_camera.fov = clamp((fov_max + fov_min) * 0.5, 55.0, 120.0)
	cam_externa_spring.add_child(cam_externa_camera)

	listado_camaras.append(cam_externa_camera)
	nombres_camaras.append("Libre")

	# ---- 1. CÁMARA INTERNA (CABINA) ----
	if cam_interna:
		listado_camaras.append(cam_interna)
		nombres_camaras.append("Interna")
		if debug_camera_manager:
			print("[CameraManager] Registrada Cámara Interna desde escena: ", cam_interna.name)
	else:
		var fallback_cabina = Camera3D.new()
		fallback_cabina.name = "CamCabina_Dinamica"
		fallback_cabina.position = Vector3(0.0, 1.45, -0.6)
		fallback_cabina.fov = 72.0
		add_child(fallback_cabina)
		cam_interna = fallback_cabina
		listado_camaras.append(fallback_cabina)
		nombres_camaras.append("Interna")

	# ---- 2. CÁMARA PARAGOLPES (BUMPER) ----
	var cam_paragolpes = Camera3D.new()
	cam_paragolpes.name = "CamParagolpes_Dinamica"
	add_child(cam_paragolpes)
	var bp_pos: Vector3 = pivot + Vector3(0.0, max(_vehicle_radius * 0.18, 0.5), -_vehicle_radius * 0.95)
	cam_paragolpes.global_position = bp_pos
	cam_paragolpes.look_at(pivot, Vector3.UP)

	listado_camaras.append(cam_paragolpes)
	nombres_camaras.append("Paragolpes")

	# ---- 3. CÁMARA AÉREA (SKY DRONE) ----
	_brazo_aereo_node = Node3D.new()
	_brazo_aereo_node.name = "BrazoAereo_Dinamico"
	_brazo_aereo_node.set_as_top_level(true)
	add_child(_brazo_aereo_node)
	_brazo_aereo_node.global_position = pivot

	var cam_aerea = Camera3D.new()
	cam_aerea.name = "CamAerea_Dinamica"
	_brazo_aereo_node.add_child(cam_aerea)
	cam_aerea.global_position = pivot + Vector3(0.0, _vehicle_radius * 3.2, _vehicle_radius * 1.2)
	cam_aerea.look_at(pivot, Vector3.UP)

	listado_camaras.append(cam_aerea)
	nombres_camaras.append("Aérea")

	# ---- 4. CÁMARA CINEMÁTICA (AUTO-ÓRBITA) ----
	_brazo_cine_node = Node3D.new()
	_brazo_cine_node.name = "BrazoCine_Dinamico"
	_brazo_cine_node.set_as_top_level(true)
	add_child(_brazo_cine_node)
	_brazo_cine_node.global_position = pivot

	var cam_cine = Camera3D.new()
	cam_cine.name = "CamCine_Dinamica"
	_brazo_cine_node.add_child(cam_cine)
	cam_cine.global_position = pivot + Vector3(0.0, _vehicle_radius * 0.6, _vehicle_radius * 2.2)
	cam_cine.look_at(pivot + Vector3(0.0, _vehicle_radius * 0.15, 0.0), Vector3.UP)

	listado_camaras.append(cam_cine)
	nombres_camaras.append("Cinemática")

	# ---- 5. CÁMARAS ADICIONALES DE ESCENA ----
	var todas_cams: Array[Camera3D] = []
	_buscar_cams_recursivo(self, todas_cams)
	for cam in todas_cams:
		if cam != cam_interna and not cam.name.contains("_Dinamica"):
			# Omitir cámaras de SpringArms o Brazos existentes en la escena para no duplicar la cámara Libre
			var p_name = cam.get_parent().name.to_lower() if cam.get_parent() else ""
			if p_name.contains("spring") or p_name.contains("brazo") or p_name.contains("pivot"):
				continue
			listado_camaras.append(cam)
			var label_cam = cam.name.replace("Camara", "").replace("Cam", "").strip_edges()
			if label_cam.is_empty():
				label_cam = cam.name
			nombres_camaras.append(label_cam)
			if debug_camera_manager:
				print("[CameraManager] Registrada Cámara adicional desde escena: ", cam.name, " como: ", label_cam)

	# Verificar remolque inicial si ya estuviera acoplado
	_actualizar_deteccion_remolque()

func _conectar_ui() -> void:
	var ui_veh = null
	if get_owner():
		ui_veh = get_owner().find_child("UIVehiculo", true, false)
	if not ui_veh:
		ui_veh = get_tree().get_root().find_child("UIVehiculo", true, false)
	if not ui_veh:
		return

	var zona = ui_veh.find_child("ZonaCamara", true, false)
	if zona:
		if zona.has_signal("camara_movida"):
			if not zona.camara_movida.is_connected(_distribuir_entrada_camara):
				zona.camara_movida.connect(_distribuir_entrada_camara)
		if zona.has_signal("camara_pinch"):
			if not zona.camara_pinch.is_connected(_distribuir_pinch):
				zona.camara_pinch.connect(_distribuir_pinch)

func alternar_camara() -> void:
	if listado_camaras.is_empty():
		_crear_camaras_codigo()
	if listado_camaras.is_empty():
		return
	var siguiente := (indice_actual + 1) % listado_camaras.size()
	seleccionar_camara(siguiente)

func activar_camara(id: int) -> void:
	activar_camaras(id)

func seleccionar_camara(indice: int, forzar: bool = false) -> void:
	if listado_camaras.is_empty():
		_crear_camaras_codigo()
	if listado_camaras.is_empty():
		return

	indice = clamp(indice, 0, listado_camaras.size() - 1)
	var nueva_cam: Camera3D = listado_camaras[indice]
	
	if not forzar and indice == indice_actual and is_instance_valid(nueva_cam) and nueva_cam.current:
		return

	var previo_idx := indice_actual
	var previo_cam: Camera3D = null
	if previo_idx >= 0 and previo_idx < listado_camaras.size():
		previo_cam = listado_camaras[previo_idx]

	indice_actual = indice

	if not forzar and transicion_suave > 0.01 and previo_cam and is_instance_valid(previo_cam) and nueva_cam and is_instance_valid(nueva_cam) and previo_cam != nueva_cam:
		_start_camera_blend(previo_cam, nueva_cam, transicion_suave)
	else:
		_blending = false
		if _blend_cam and is_instance_valid(_blend_cam):
			_blend_cam.current = false
		for c in listado_camaras:
			if is_instance_valid(c):
				c.current = false
		if is_instance_valid(nueva_cam):
			nueva_cam.make_current()

	if debug_camera_manager:
		print("[CameraManager] Cámara activa cambiada a: ", nombres_camaras[indice_actual], " (Indice: ", indice_actual, ")")

	if indice_actual != 1:
		external_camera_target = null
	if indice_actual == 1:
		if cam_interna and cam_interna.has_method("centrar_camara"):
			cam_interna.centrar_camara(0.4)

	# Al seleccionar la Cámara Libre por primera vez, alinear detrás del vehículo
	if indice_actual == 0:
		var vehicle = get_parent()
		if vehicle:
			var veh_yaw = rad_to_deg(vehicle.global_transform.basis.get_euler().y)
			_brazo_yaw = veh_yaw + 180.0
			_brazo_pitch = -12.0

	emit_signal("camara_cambiada", indice_actual)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distribuir_pinch(25.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distribuir_pinch(-25.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_distribuir_entrada_camara(event.relative)

func _desactivar_todas_las_camaras() -> void:
	for c in listado_camaras:
		if is_instance_valid(c):
			c.current = false

func _distribuir_entrada_camara(relative: Vector2) -> void:
	_last_input_time = Time.get_ticks_msec()
	if indice_actual == 0 or indice_actual < 0:
		_rotar_camara_externa(relative)
	elif indice_actual == 1:
		if cam_interna and cam_interna.has_method("_manejar_rotacion_libre"):
			cam_interna._manejar_rotacion_libre(relative)

func _distribuir_pinch(delta_dist: float) -> void:
	var cam_idx := 0 if indice_actual < 0 else indice_actual
	if cam_idx == 0:
		var base_length: float = clamp(_vehicle_radius * 2.2 + 1.0 + _extra_distancia_remolque, 3.0, 120.0)
		_user_zoom_offset = clamp(_user_zoom_offset - (delta_dist * 0.15), -(base_length * 0.85), base_length * 3.0)
		if cam_externa_spring:
			var desired_length: float = clamp(base_length + _user_zoom_offset, 2.0, 140.0)
			cam_externa_spring.spring_length = desired_length

func _rotar_camara_externa(relative: Vector2) -> void:
	_brazo_yaw -= relative.x * _brazo_sensibilidad
	_brazo_pitch -= relative.y * _brazo_sensibilidad
	_brazo_pitch = clamp(_brazo_pitch, _brazo_limite_pitch.x, _brazo_limite_pitch.y)

func centrar_camara_detras() -> void:
	var vehicle = get_parent()
	if vehicle:
		var veh_yaw = rad_to_deg(vehicle.global_transform.basis.get_euler().y)
		_brazo_yaw = veh_yaw + 180.0
		_brazo_pitch = -12.0

func set_external_camera(cam: Camera3D) -> void:
	external_camera_target = cam

func clear_external_camera() -> void:
	external_camera_target = null

func desactivar_camaras() -> void:
	clear_external_camera()
	_blending = false
	if _blend_cam and is_instance_valid(_blend_cam):
		_blend_cam.current = false
	for cam in listado_camaras:
		if is_instance_valid(cam):
			cam.current = false
	var p = get_parent()
	if p and is_instance_valid(p):
		for child in p.find_children("*", "Camera3D", true, false):
			if is_instance_valid(child):
				child.current = false
	indice_actual = -1
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)

func activar_camaras(cam_id: int = -1) -> void:
	set_physics_process(true)
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	if listado_camaras.is_empty():
		_crear_camaras_codigo()
	var target_idx := cam_id if cam_id >= 0 else (indice_actual if indice_actual >= 0 else camara_inicial)
	seleccionar_camara(target_idx, true)

func mover_camara(indice: int, relative: Vector2) -> void:
	if indice != indice_actual:
		seleccionar_camara(indice)
	_distribuir_entrada_camara(relative)

# ════════════════════════════════════════════════════════════════════════════
# DETECCIÓN DINÁMICA Y EXCLUSIÓN DE COLISIONES DE REMOLQUES / TRÁILERS
# ════════════════════════════════════════════════════════════════════════════

func _actualizar_deteccion_remolque() -> void:
	var vehicle := get_parent()
	if not vehicle or not is_instance_valid(vehicle):
		return

	var remolque: RigidBody3D = null
	var enganche = vehicle.find_child("Enganche", true, false)
	if enganche and enganche.get("conectado") == true:
		var remoto = enganche.get("enganche_remoto")
		if remoto and is_instance_valid(remoto):
			if enganche.has_method("_buscar_cuerpo"):
				remolque = enganche.call("_buscar_cuerpo", remoto) as RigidBody3D
			elif remoto.has_method("_buscar_cuerpo"):
				remolque = remoto.call("_buscar_cuerpo", remoto) as RigidBody3D
			elif remoto.get_parent() is RigidBody3D:
				remolque = remoto.get_parent() as RigidBody3D

	if remolque != _remolque_actual:
		_remolque_actual = remolque
		_configurar_remolque_acoplado()

func _configurar_remolque_acoplado() -> void:
	if _remolque_actual and is_instance_valid(_remolque_actual):
		# Recolectar todos los CollisionObject3D del remolque (RigidBody, Patas/StaticBody, etc.)
		var stack: Array[Node] = [_remolque_actual]
		while stack.size() > 0:
			var n = stack.pop_back()
			if n is CollisionObject3D:
				var rid: RID = n.get_rid()
				if not _remolque_rids_excluidos.has(rid):
					_remolque_rids_excluidos.append(rid)
					if cam_externa_spring and is_instance_valid(cam_externa_spring):
						cam_externa_spring.add_excluded_object(rid)
					# Excluir también en cualquier SpringArm3D de la escena (ej. BrazoCamara)
					for sa in find_children("*", "SpringArm3D", true, false):
						if is_instance_valid(sa):
							sa.add_excluded_object(rid)
			for ch in n.get_children():
				stack.append(ch)

		# Calcular longitud aproximada del remolque para adaptar la distancia de la cámara
		var t_radius: float = 12.0
		var m_stack: Array[Node] = [_remolque_actual]
		var max_dist: float = 0.0
		while m_stack.size() > 0:
			var mn = m_stack.pop_back()
			if mn is MeshInstance3D and mn.mesh:
				var aabb: AABB = mn.mesh.get_aabb()
				var sz = aabb.size.length()
				if sz > max_dist:
					max_dist = sz
			for ch in mn.get_children():
				m_stack.append(ch)
		if max_dist > 4.0:
			t_radius = clamp(max_dist * 0.9, 9.0, 20.0)

		_extra_distancia_remolque = t_radius
		if debug_camera_manager:
			print("[CameraManager] Tráiler detectado y configurado: ", _remolque_actual.name, " (Excluidos ", _remolque_rids_excluidos.size(), " RIDs, Distancia extra: ", _extra_distancia_remolque, ")")
	else:
		_remolque_rids_excluidos.clear()
		_extra_distancia_remolque = 0.0
		if debug_camera_manager:
			print("[CameraManager] Tráiler desacoplado. Restaurando distancia estándar.")

# ════════════════════════════════════════════════════════════════════════════
# FÍSICAS Y ACTUALIZACIÓN POR FRAME
# ════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	var vehicle := get_parent()
	if not vehicle or not is_instance_valid(vehicle):
		return

	# Monitorear acople / desacople de tráiler
	_remolque_check_timer += delta
	if _remolque_check_timer >= 0.20:
		_remolque_check_timer = 0.0
		_actualizar_deteccion_remolque()

	var speed: float = 0.0
	if typeof(vehicle.linear_velocity) != TYPE_NIL:
		speed = vehicle.linear_velocity.length()

	# 1. Seguimiento del Brazo Externo (Cámara Libre - Índice 0)
	if cam_externa_brazo:
		var target_pos: Vector3 = vehicle.global_transform.origin

		# Si hay tráiler acoplado, desplazar el pivote suavemente hacia el centro del convoy
		# para que tanto el cabezote como el remolque queden perfectamente encuadrados al rotar
		if _remolque_actual and is_instance_valid(_remolque_actual):
			var remolque_pos: Vector3 = _remolque_actual.global_transform.origin
			target_pos = target_pos.lerp(remolque_pos, 0.40)

		var up_offset: float = _vehicle_radius if _vehicle_radius > 0.0 else 1.0
		var altura_extra: float = 0.8 if _extra_distancia_remolque > 0.0 else 0.0
		cam_externa_brazo.global_position = target_pos + Vector3(0.0, max(up_offset * 0.25, 0.5) + altura_extra, 0.0)

		# Auto-centrado opcional (por defecto desactivado para dar control 100% libre)
		if auto_centrado_libre:
			var time_since_input = (Time.get_ticks_msec() - _last_input_time) / 1000.0
			var veh_yaw = rad_to_deg(vehicle.global_transform.basis.get_euler().y)
			if speed > 1.0 and time_since_input > 2.5:
				var target_yaw = veh_yaw
				var local_vel = vehicle.global_transform.basis.inverse() * vehicle.linear_velocity
				if local_vel.z > 0.5:
					target_yaw = veh_yaw + 180.0
				_brazo_yaw = rad_to_deg(lerp_angle(deg_to_rad(_brazo_yaw), deg_to_rad(target_yaw), delta * 2.0))

		var desired_pitch: float = _brazo_pitch
		var desired_yaw: float = _brazo_yaw
		var smooth_t: float = 1.0 - exp(-orbit_damping * delta)
		var cur_rot: Vector3 = cam_externa_brazo.rotation_degrees
		var smoothed_x: float = rad_to_deg(lerp_angle(deg_to_rad(cur_rot.x), deg_to_rad(desired_pitch), smooth_t))
		var smoothed_y: float = rad_to_deg(lerp_angle(deg_to_rad(cur_rot.y), deg_to_rad(desired_yaw), smooth_t))

		var shake_rot_vec: Vector3 = Vector3.ZERO
		if shake_enabled:
			_shake_velocity = _shake_velocity.lerp(Vector3.ZERO, clamp(shake_decay * delta, 0.0, 1.0))
			var current_shake: Vector3 = _shake_velocity * shake_strength
			shake_rot_vec = Vector3(current_shake.x * 2.0, current_shake.y * 2.0, 0.0)
			
		cam_externa_brazo.rotation_degrees = Vector3(smoothed_x, smoothed_y, 0.0) + shake_rot_vec

		if auto_fov_enabled and cam_externa_camera:
			var desired_fov: float = clamp(fov_min + speed * fov_speed_factor, fov_min, fov_max)
			cam_externa_camera.fov = lerp(cam_externa_camera.fov, desired_fov, delta * 3.0)

		if cam_externa_spring:
			var base_length: float = clamp(_vehicle_radius * 2.2 + 1.0 + _extra_distancia_remolque, 3.0, 120.0)
			var desired_length: float = clamp(base_length + _user_zoom_offset + (speed * 0.08), 2.0, 140.0)
			cam_externa_spring.spring_length = lerpf(cam_externa_spring.spring_length, desired_length, clamp(6.0 * delta, 0.0, 1.0))

	# 2. Seguimiento de la Cámara Aérea
	if _brazo_aereo_node:
		var target_pos_aerea: Vector3 = vehicle.global_transform.origin
		if _remolque_actual and is_instance_valid(_remolque_actual):
			target_pos_aerea = target_pos_aerea.lerp(_remolque_actual.global_transform.origin, 0.40)
		_brazo_aereo_node.global_position = target_pos_aerea + Vector3(0.0, 1.5, 0.0)
		var veh_yaw = vehicle.global_transform.basis.get_euler().y
		_brazo_aereo_node.rotation.y = lerp_angle(_brazo_aereo_node.rotation.y, veh_yaw, 1.0 - exp(-6.0 * delta))

	# 3. Seguimiento y auto-órbita de la Cámara Cinemática
	if _brazo_cine_node:
		var target_pos_cine: Vector3 = vehicle.global_transform.origin
		if _remolque_actual and is_instance_valid(_remolque_actual):
			target_pos_cine = target_pos_cine.lerp(_remolque_actual.global_transform.origin, 0.40)
		_brazo_cine_node.global_position = target_pos_cine + Vector3(0.0, 1.5, 0.0)
		_cine_yaw_auto += 8.0 * delta
		_brazo_cine_node.rotation_degrees = Vector3(-10.0, _cine_yaw_auto, 0.0)

	# Espejo de cabina
	if external_camera_target and cam_interna:
		if cam_interna.has_method("compute_local_state"):
			var st: Dictionary = cam_interna.call("compute_local_state", delta)
			var p: Node = cam_interna.get_parent()
			if p:
				var rot_v: Vector3 = st.get("rotation", Vector3.ZERO)
				var pos_v: Vector3 = st.get("position", Vector3.ZERO)
				var fov_v: float = float(st.get("fov", external_camera_target.fov))
				var local_xform := Transform3D(Basis(), pos_v)
				local_xform = local_xform.rotated(Vector3.RIGHT, rot_v.x)
				local_xform = local_xform.rotated(Vector3.UP, rot_v.y)
				local_xform = local_xform.rotated(Vector3(0, 0, 1), rot_v.z)
				external_camera_target.global_transform = p.global_transform * local_xform
				external_camera_target.fov = fov_v
				if not external_camera_target.current:
					external_camera_target.make_current()

	# --- Manejo de blending entre cámaras ---
	if _blending and _blend_cam:
		_blend_timer += delta
		var t: float = clamp(_blend_timer / _blend_duration, 0.0, 1.0)
		var blend_ease: float = 1.0 - pow(1.0 - t, 3)
		
		var from_basis := _blend_from.basis
		var to_basis := _blend_to.basis
		var interp_basis := from_basis.slerp(to_basis, blend_ease)
		var interp_origin := _blend_from.origin.lerp(_blend_to.origin, blend_ease)
		
		_blend_cam.global_transform = Transform3D(interp_basis, interp_origin)
		_blend_cam.fov = lerp(_blend_from_fov, _blend_to_fov, blend_ease)
		
		if t >= 1.0:
			_blending = false
			if _blend_target_cam and is_instance_valid(_blend_target_cam):
				_blend_target_cam.make_current()
			if _blend_cam and is_instance_valid(_blend_cam):
				_blend_cam.current = false
