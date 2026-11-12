# retrovisores_auto.gd - Controlador Dinámico de Retrovisores (Espejos) en 3D
@tool
extends Node3D

@export_group("Configuración Espejos")
## Resolución de renderizado de cada espejo en píxeles (optimizado para rendimiento)
@export var resolucion_espejo: Vector2i = Vector2i(256, 128)

## Campo de visión de las cámaras de los retrovisores
@export var fov_camaras: float = 48.0

## Si es verdadero, invierte horizontalmente la imagen del espejo para simular un reflejo óptico real
@export var invertir_reflejo_optico: bool = true

## Estado del conductor (si no hay conductor, desactiva el render para optimizar rendimiento)
@export var conductor_presente: bool = false

@export_group("Nodos")
@export var subviewport_izq: SubViewport
@export var subviewport_der: SubViewport
@export var camara_izq: Camera3D
@export var camara_der: Camera3D
@export var mesh_izq: MeshInstance3D
@export var mesh_der: MeshInstance3D

func _ready() -> void:
	# Retrovisores desactivados temporalmente por solicitud del usuario
	set_process(false)
	set_physics_process(false)
	return

func _conectar_camara_manager() -> void:
	var parent_veh := get_parent()
	if is_instance_valid(parent_veh):
		var cam_mgr = parent_veh.find_child("CameraManager", true, false)
		if cam_mgr and cam_mgr.has_signal("camara_cambiada"):
			if not cam_mgr.camara_cambiada.is_connected(_on_camara_cambiada):
				cam_mgr.camara_cambiada.connect(_on_camara_cambiada)
			# Si ya hay un índice actual registrado
			var idx = cam_mgr.get("indice_actual")
			if idx != null:
				_camara_es_interna = (idx == 1)
				_actualizar_estado_espejos()

var _camara_es_interna: bool = false

func _on_camara_cambiada(indice: int) -> void:
	# Indice 1: Cámara Interna (Cabina). Las demás (0: Externa, 2+: Aérea/Paragolpes) no ven los espejos
	_camara_es_interna = (indice == 1)
	_actualizar_estado_espejos()

func _actualizar_estado_espejos() -> void:
	# En vista externa (3a persona), los espejos NO se renderizan para ahorrar 2 pases 3D completos
	var activo: bool = (conductor_presente and _camara_es_interna) or Engine.is_editor_hint()
	var update_mode := SubViewport.UPDATE_ALWAYS if activo else SubViewport.UPDATE_DISABLED
	if is_instance_valid(subviewport_izq):
		subviewport_izq.render_target_update_mode = update_mode
	if is_instance_valid(subviewport_der):
		subviewport_der.render_target_update_mode = update_mode

func _configurar_viewports() -> void:
	_actualizar_estado_espejos()

	if is_instance_valid(subviewport_izq):
		subviewport_izq.size = resolucion_espejo
		subviewport_izq.msaa_3d = SubViewport.MSAA_DISABLED
		subviewport_izq.positional_shadow_atlas_size = 0

	if is_instance_valid(subviewport_der):
		subviewport_der.size = resolucion_espejo
		subviewport_der.msaa_3d = SubViewport.MSAA_DISABLED
		subviewport_der.positional_shadow_atlas_size = 0

	if is_instance_valid(camara_izq):
		camara_izq.fov = fov_camaras
		camara_izq.set_cull_mask_value(2, false)

	if is_instance_valid(camara_der):
		camara_der.fov = fov_camaras
		camara_der.set_cull_mask_value(2, false)

func _configurar_materiales() -> void:
	if is_instance_valid(subviewport_izq) and is_instance_valid(mesh_izq):
		_aplicar_material_espejo(mesh_izq, subviewport_izq)

	if is_instance_valid(subviewport_der) and is_instance_valid(mesh_der):
		_aplicar_material_espejo(mesh_der, subviewport_der)

func _aplicar_material_espejo(mesh: MeshInstance3D, viewport: SubViewport) -> void:
	var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
	if not mat:
		mat = mesh.material_override as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		mat.resource_local_to_scene = true
		mesh.set_surface_override_material(0, mat)

	mat.albedo_texture = viewport.get_texture()
	mat.roughness = 0.08
	mat.metallic = 0.85
	
	if invertir_reflejo_optico:
		mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
		mat.uv1_offset = Vector3(1.0, 0.0, 0.0)

	# Evitar bucle de retroalimentación de textura en Vulkan (error de framebuffer y uniform)
	# Mover el mesh del espejo a la Capa 2 y ocultarlo en la cámara del retrovisor
	mesh.set_layer_mask_value(1, false)
	mesh.set_layer_mask_value(2, true)
	for child in viewport.get_children():
		if child is Camera3D:
			child.set_cull_mask_value(2, false)

func set_conductor_presente(presente: bool) -> void:
	conductor_presente = presente
	_conectar_camara_manager()
	_actualizar_estado_espejos()
