# Script modular para controlar SubViewports de los espejos hijos
# Estructura esperada: Nodo `Espejos` (Node3D) -> hijos (MeshInstance3D) -> SubViewport -> Camera3D
# - Exportados para ajustar resolución y FPS desde el Inspector.
# - Soporta actualización manual por timer (limitar FPS) o automática (UPDATE_WHEN_VISIBLE).
extends Node3D

@export var resolucion: Vector2i = Vector2i(512, 256)
@export var fps_mirrors: int = 30 # 0 = sin límite (UPDATE_WHEN_VISIBLE)
@export var viewport_node_name: String = "SubViewport"
@export var auto_connect_vehicle_signals: bool = true
@export var active_by_default: bool = true
@export var auto_assign_materials: bool = true

var _viewports: Array[SubViewport] = []
var _activos: bool = false
var _timer: Timer = null
@export var debug_espejos: bool = false

func _ready() -> void:
	# Recolectar SubViewports dentro de los hijos directos
	for espejo in get_children():
		var vp: SubViewport = espejo.get_node_or_null(viewport_node_name) as SubViewport
		if vp:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			vp.size = resolucion
			_viewports.append(vp)
			# Intentar asignar un World3D propio al SubViewport para aislar cámaras
			if vp.has_method("set_world_3d"):
				var new_world := World3D.new()
				vp.set_world_3d(new_world)
				if debug_espejos:
					print("[Espejos] Assigned new World3D to", vp.get_path())
			else:
					if debug_espejos:
						print("[Espejos] SubViewport has no set_world_3d(), skipping world assignment for", vp.get_path())
			# Desactivar procesamiento de la cámara hija para ahorrar culling
			var cam = _find_camera_in_viewport(vp)
			if cam:
				cam.set_process(false)
				cam.set_physics_process(false)

	# Timer para limitar FPS (si corresponde)
	if fps_mirrors > 0:
		_timer = Timer.new()
		_timer.wait_time = 1.0 / float(fps_mirrors)
		_timer.one_shot = false
		add_child(_timer)
		_timer.timeout.connect(_on_timer_timeout)

	# Conectar con señales del vehículo padre (si las tiene)
	if auto_connect_vehicle_signals:
		var vehiculo := _get_vehiculo_parent(get_parent())
		if vehiculo:
			if vehiculo.has_signal("jugador_subio"):
				vehiculo.jugador_subio.connect(_activar)
			if vehiculo.has_signal("jugador_bajo"):
				vehiculo.jugador_bajo.connect(_desactivar)

	# Estado inicial según export
	_aplicar_estado(active_by_default)

	# Forzar re-render diferido para evitar capturas prematuras
	call_deferred("_post_ready_setup")

	# Si se solicita, asignar la textura del SubViewport al material del mesh espejo
	if auto_assign_materials:
		for vp in _viewports:
			if is_instance_valid(vp):
				var parent_mesh := vp.get_parent() as MeshInstance3D
				if parent_mesh:
					var tex := vp.get_texture()
					var mat := StandardMaterial3D.new()
					if tex:
						mat.albedo_texture = tex
					else:
						var vt := ViewportTexture.new()
						vt.viewport_path = vp.get_path()
						mat.albedo_texture = vt
					parent_mesh.material_override = mat

	# Diagnostics: print info about found viewports and cameras
	for vp in _viewports:
		if is_instance_valid(vp):
			var cam := _find_camera_in_viewport(vp)
			if cam:
				if debug_espejos:
					print("[Espejos] Viewport:", vp.get_path(), " size:", vp.size, " parent:", vp.get_parent().get_path())
					print("[Espejos]  -> Camera:", cam.get_path(), " parent:", cam.get_parent().get_path())
					print("[Espejos]  -> cam global pos:", cam.global_transform.origin, " current:", cam.current)
				# If the viewport reports a different camera, print that too
				var reported := vp.get_camera_3d()
				if reported:
					if debug_espejos:
						print("[Espejos]  -> get_camera_3d():", reported.get_path(), " equal:", reported == cam)
				else:
					if debug_espejos:
						print("[Espejos]  -> get_camera_3d(): NONE")

func _find_camera_in_viewport(vp: SubViewport) -> Camera3D:
	for c in vp.get_children():
		if c is Camera3D:
			return c
	return null

func _on_timer_timeout() -> void:
	# Renderiza una vez por cada timeout (UPDATE_ONCE)
	for vp in _viewports:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE

# API pública
func _activar() -> void:
	_aplicar_estado(true)

func _desactivar() -> void:
	_aplicar_estado(false)

# Lógica central
func _aplicar_estado(activo: bool) -> void:
	_activos = activo
	if fps_mirrors > 0:
		if activo:
			if _timer:
				_timer.start()
			# Activar procesamiento de cámaras y forzar un primer render
			for vp in _viewports:
				if is_instance_valid(vp):
						var cam := _find_camera_in_viewport(vp)
						if cam:
							cam.set_process(true)
							cam.set_physics_process(true)
							cam.make_current()
						# Render inmediato
						vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			if _timer:
				_timer.stop()
			for vp in _viewports:
				if is_instance_valid(vp):
					vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
					var cam := _find_camera_in_viewport(vp)
					if cam:
						cam.set_process(false)
						cam.set_physics_process(false)
	else:
		var modo: int = SubViewport.UPDATE_WHEN_VISIBLE if activo else SubViewport.UPDATE_DISABLED
		for vp in _viewports:
			if is_instance_valid(vp):
				vp.render_target_update_mode = modo
				var cam = _find_camera_in_viewport(vp)
				if cam:
					cam.set_process(activo)
					cam.set_physics_process(activo)
					if activo:
						cam.make_current()

# Utilidad: busca el nodo RigidBody3D padre (vehículo)
func _get_vehiculo_parent(n: Node) -> Node:
	if n == null:
		return null
	if n is RigidBody3D:
		return n
	return _get_vehiculo_parent(n.get_parent())


func _post_ready_setup() -> void:
	# Esperar un pequeño retraso para que otras cámaras y scripts terminen de inicializarse
	await get_tree().create_timer(0.05).timeout
	for vp in _viewports:
		if is_instance_valid(vp):
			var cam := _find_camera_in_viewport(vp)
			if cam:
				cam.make_current()
			# Forzar un render tras el retraso
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Otra pasada un poco más tarde por si la primera no alcanza
	await get_tree().create_timer(0.2).timeout
	for vp in _viewports:
		if is_instance_valid(vp):
			var cam := _find_camera_in_viewport(vp)
			if cam:
				cam.make_current()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
