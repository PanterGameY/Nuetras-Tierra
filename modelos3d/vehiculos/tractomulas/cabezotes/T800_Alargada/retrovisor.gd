extends Node3D

@onready var retrovisor_viewport: SubViewport = $SubViewport
@onready var retrovisor_camara: Camera3D = get_node_or_null("Camera3D") as Camera3D # Tu cámara física externa (opcional)
@onready var retrovisor_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
@export var debug_retrovisor: bool = false

func _ready() -> void:
	# Esperamos a que el motor inicialice los entornos gráficos (un frame)
	await get_tree().process_frame

	if not is_instance_valid(retrovisor_viewport):
		if debug_retrovisor:
			print("[retrovisor] SubViewport no encontrado en:", get_path(), "SubViewport")
		return

	# Compartir world_3d si el SubViewport lo expone
	if "world_3d" in retrovisor_viewport:
		retrovisor_viewport.world_3d = get_world_3d()
		if debug_retrovisor:
			print("[retrovisor] Asignado world_3d a", retrovisor_viewport.get_path())
	else:
		if debug_retrovisor:
			print("[retrovisor] SubViewport no expone property world_3d, se omite asignación")

	# Resolver la cámara: preferimos la exportada; si no existe, buscar dentro del SubViewport
	var cam: Camera3D = null
	if is_instance_valid(retrovisor_camara):
		cam = retrovisor_camara
	else:
		cam = retrovisor_viewport.get_camera_3d()
		if cam == null:
			for c in retrovisor_viewport.get_children():
				if c is Camera3D:
					cam = c
					break

	if cam:
		cam.current = true
		if debug_retrovisor:
			print("[retrovisor] Cámara usada:", cam.get_path(), "pos:", cam.global_transform.origin)
	else:
		if debug_retrovisor:
			print("[retrovisor] No se encontró cámara para el retrovisor. Revisa nombres/jerarquía.")

	# Obtener la textura viva del SubViewport (o crear ViewportTexture si hace falta)
	var textura_viva = retrovisor_viewport.get_texture()
	if textura_viva == null:
		var vt := ViewportTexture.new()
		vt.viewport_path = retrovisor_viewport.get_path()
		textura_viva = vt

	# Asignar textura al material (usar material_override si no existe uno activo)
	if not is_instance_valid(retrovisor_mesh):
		if debug_retrovisor:
			print("[retrovisor] MeshInstance3D no encontrado en:", get_path())
		return

	var mat := retrovisor_mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		retrovisor_mesh.material_override = mat

	mat.albedo_texture = textura_viva

	# Evitar bucle de retroalimentación de textura en Vulkan (error de framebuffer y uniform)
	# Mover el mesh del espejo a la Capa 2 y ocultarlo en la cámara del retrovisor
	retrovisor_mesh.set_layer_mask_value(1, false)
	retrovisor_mesh.set_layer_mask_value(2, true)
	if cam:
		cam.set_cull_mask_value(2, false)

	if debug_retrovisor:
		print("[retrovisor] Textura asignada al material del espejo")
