@tool
extends Path3D
class_name TrafficLane3D

## ══════════════════════════════════════════════════════════════════════════════
##  TrafficLane3D.gd
##  Sistema de Tráfico por Carriles — Nodo individual de carril basado en Path3D.
## ══════════════════════════════════════════════════════════════════════════════

enum LaneType {
	NORMAL,
	RETORNO,     # U-Turn
	CRUCE,       # Intersección
	ACELERACION, # Entrada / Incorporación
	SALIDA       # Desvío
}

@export var lane_id: String = ""
@export var speed_limit: float = 60.0 # en km/h
@export var lane_width: float = 3.5   # ancho del carril en metros
@export var lane_type: LaneType = LaneType.NORMAL

## Carriles siguientes a los que este carril da paso directamente.
@export var next_lanes: Array[TrafficLane3D] = []

## Indica si el carril está activo para el tráfico de IA.
@export var is_active: bool = true

## Color de depuración visual en el editor 3D.
@export var debug_color: Color = Color(0.0, 0.8, 1.0, 0.9):
	set(val):
		debug_color = val
		if Engine.is_editor_hint():
			_update_debug_mesh()

var _debug_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("traffic_lanes")
	if lane_id.is_empty():
		lane_id = name
	
	if Engine.is_editor_hint():
		_setup_debug_visuals()

func get_total_length() -> float:
	if curve:
		return curve.get_baked_length()
	return 0.0

func sample_point_at_distance(distance: float) -> Vector3:
	if not curve:
		return global_position
	var local_pt = curve.sample_baked(distance)
	return to_global(local_pt)

func sample_transform_at_distance(distance: float) -> Transform3D:
	if not curve:
		return global_transform
	var local_trans = curve.sample_baked_with_rotation(distance)
	return global_transform * local_trans

func get_sampled_points(step: float = 2.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not curve:
		return result
	
	var length = curve.get_baked_length()
	if length <= 0:
		return result
		
	var curr = 0.0
	while curr <= length:
		result.append(to_global(curve.sample_baked(curr)))
		curr += step
	if result.is_empty() or result[-1].distance_to(to_global(curve.sample_baked(length))) > 0.1:
		result.append(to_global(curve.sample_baked(length)))
	return result

func connect_to_lane(target_lane: TrafficLane3D) -> void:
	if target_lane and not next_lanes.has(target_lane):
		next_lanes.append(target_lane)

func _setup_debug_visuals() -> void:
	_debug_mesh = get_node_or_null("LaneDebugMesh") as MeshInstance3D
	if not _debug_mesh:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.name = "LaneDebugMesh"
		add_child(_debug_mesh)
	_update_debug_mesh()

func _update_debug_mesh() -> void:
	if not curve or not _debug_mesh:
		return
	
	var points = curve.get_baked_points()
	if points.size() < 2:
		_debug_mesh.mesh = null
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = debug_color
	mat.use_point_size = true
	st.set_material(mat)
	
	for i in range(points.size() - 1):
		st.set_color(debug_color)
		st.add_vertex(points[i])
		st.set_color(debug_color)
		st.add_vertex(points[i + 1])
		
	_debug_mesh.mesh = st.commit()
