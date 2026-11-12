class_name VisualizadorHuesos
extends Node3D

## Visualizador y seleccionador 3D para huesos de Skeleton3D.
## Dibuja la estructura del rig en tiempo real y permite seleccionar huesos
## haciendo clic directamente sobre ellos en el visor 3D.

signal hueso_seleccionado_en_3d(nombre_hueso: String, indice_hueso: int)

@export var esqueleto: Skeleton3D
@export var camara: Camera3D
@export var mostrar_huesos: bool = true:
	set(val):
		mostrar_huesos = val
		visible = val
		set_process(val)

@export var radio_clic_pixeles: float = 22.0
@export var color_hueso_normal: Color = Color(0.28, 0.72, 0.95, 0.85)
@export var color_hueso_seleccionado: Color = Color(0.95, 0.72, 0.22, 1.0)
@export var color_articulacion: Color = Color(0.85, 0.90, 0.98, 0.95)

var hueso_seleccionado_idx: int = -1
var _mesh_instancia: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _material_lineas: StandardMaterial3D

func _ready():
	_crear_malla_inmediata()

func _crear_malla_inmediata():
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instancia = MeshInstance3D.new()
	_mesh_instancia.mesh = _immediate_mesh
	_mesh_instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	_material_lineas = StandardMaterial3D.new()
	_material_lineas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_lineas.vertex_color_use_as_albedo = true
	_material_lineas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_lineas.no_depth_test = true
	_mesh_instancia.material_override = _material_lineas
	
	add_child(_mesh_instancia)

func asignar_esqueleto(nuevo_esqueleto: Skeleton3D):
	esqueleto = nuevo_esqueleto
	hueso_seleccionado_idx = -1

func seleccionar_hueso(idx: int):
	hueso_seleccionado_idx = idx

func _process(_delta: float):
	if not mostrar_huesos or not esqueleto or not is_instance_valid(esqueleto):
		if _immediate_mesh and _immediate_mesh.get_surface_count() > 0:
			_immediate_mesh.clear_surfaces()
		return
		
	_dibujar_esqueleto()

func _dibujar_esqueleto():
	if not _immediate_mesh:
		return
		
	_immediate_mesh.clear_surfaces()
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var skel_trans = esqueleto.global_transform
	var bone_count = esqueleto.get_bone_count()
	
	for i in range(bone_count):
		var pos_hueso_global = skel_trans * esqueleto.get_bone_global_pose(i).origin
		var parent_idx = esqueleto.get_bone_parent(i)
		
		var es_sel = (i == hueso_seleccionado_idx)
		var col_linea = color_hueso_seleccionado if es_sel else color_hueso_normal
		
		# Dibujar línea hacia el hueso padre
		if parent_idx >= 0:
			var pos_padre_global = skel_trans * esqueleto.get_bone_global_pose(parent_idx).origin
			_immediate_mesh.surface_set_color(col_linea)
			_immediate_mesh.surface_add_vertex(pos_padre_global)
			_immediate_mesh.surface_set_color(col_linea)
			_immediate_mesh.surface_add_vertex(pos_hueso_global)
			
		# Dibujar articulación (pequeño rombo/cruz)
		var s = 0.024 if not es_sel else 0.045
		var col_joint = color_hueso_seleccionado if es_sel else color_articulacion
		_dibujar_rombo_articulacion(pos_hueso_global, s, col_joint)
		
	_immediate_mesh.surface_end()

func _dibujar_rombo_articulacion(pos: Vector3, s: float, col: Color):
	_immediate_mesh.surface_set_color(col)
	# Eje X
	_immediate_mesh.surface_add_vertex(pos - Vector3(s, 0, 0))
	_immediate_mesh.surface_add_vertex(pos + Vector3(s, 0, 0))
	# Eje Y
	_immediate_mesh.surface_add_vertex(pos - Vector3(0, s, 0))
	_immediate_mesh.surface_add_vertex(pos + Vector3(0, s, 0))
	# Eje Z
	_immediate_mesh.surface_add_vertex(pos - Vector3(0, 0, s))
	_immediate_mesh.surface_add_vertex(pos + Vector3(0, 0, s))

func _unhandled_input(event: InputEvent):
	if not mostrar_huesos or not esqueleto or not camara:
		return
		
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hueso_encontrado = _buscar_hueso_bajo_cursor(mb.position)
			if hueso_encontrado >= 0:
				hueso_seleccionado_idx = hueso_encontrado
				var nombre = esqueleto.get_bone_name(hueso_encontrado)
				hueso_seleccionado_en_3d.emit(nombre, hueso_encontrado)

func _buscar_hueso_bajo_cursor(pos_mouse: Vector2) -> int:
	if not esqueleto or not camara:
		return -1
		
	var skel_trans = esqueleto.global_transform
	var mejor_idx = -1
	var menor_dist_sq = radio_clic_pixeles * radio_clic_pixeles
	var menor_profundidad = 99999.0
	
	for i in range(esqueleto.get_bone_count()):
		var pos_global = skel_trans * esqueleto.get_bone_global_pose(i).origin
		if camara.is_position_behind(pos_global):
			continue
			
		var pos_2d = camara.unproject_position(pos_global)
		var dist_sq = pos_mouse.distance_squared_to(pos_2d)
		
		if dist_sq <= menor_dist_sq:
			var prof = camara.global_position.distance_to(pos_global)
			if prof < menor_profundidad:
				menor_profundidad = prof
				menor_dist_sq = dist_sq
				mejor_idx = i
				
	return mejor_idx
