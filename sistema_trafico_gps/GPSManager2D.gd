extends Node
class_name GPSManager2D

## ══════════════════════════════════════════════════════════════════════════════
##  GPSManager2D.gd
##  Sistema de Mapeo 3D -> 2D, Enrutamiento GPS e Instrucciones de Navegación.
## ══════════════════════════════════════════════════════════════════════════════

signal gps_route_updated(points_2d: PackedVector2Array, total_distance: float, instructions: Array)
signal vehicle_position_updated(vehicle_id: String, pos_2d: Vector2, rotation_rad: float)

@export var network_manager: TrafficNetworkManager3D = null

## Escala de conversión de metros 3D a píxeles/unidades 2D del mapa.
@export var map_scale: float = 2.0

## Desplazamiento del centro del mapa en 2D.
@export var map_offset: Vector2 = Vector2.ZERO

## Objeto o vehículo rastreado como origen del GPS (Jugador o vehículo principal).
@export var tracked_target_3d: Node3D = null

var active_route_3d: PackedVector3Array = PackedVector3Array()
var active_route_2d: PackedVector2Array = PackedVector2Array()
var active_instructions: Array[Dictionary] = []

func _process(_delta: float) -> void:
	if tracked_target_3d and is_instance_valid(tracked_target_3d):
		var pos_2d = world_to_gps(tracked_target_3d.global_position)
		var rot = tracked_target_3d.global_rotation.y
		vehicle_position_updated.emit("PLAYER", pos_2d, rot)

func world_to_gps(world_pos: Vector3) -> Vector2:
	# En Godot 3D: X = Este/Oeste, Z = Sur/Norte (-Z es Norte).
	# Mapeamos X 3D -> X 2D, Z 3D -> Y 2D
	return Vector2(world_pos.x, world_pos.z) * map_scale + map_offset

func gps_to_world(gps_pos: Vector2, height_y: float = 0.0) -> Vector3:
	var unscaled = (gps_pos - map_offset) / map_scale
	return Vector3(unscaled.x, height_y, unscaled.y)

func calculate_route(start_pos_3d: Vector3, destination_pos_3d: Vector3) -> void:
	if not network_manager:
		network_manager = get_tree().get_first_node_in_group("traffic_network_manager") as TrafficNetworkManager3D
		
	if not network_manager:
		push_warning("[GPSManager2D] No se encontró TrafficNetworkManager3D.")
		return
		
	var lanes_route = network_manager.find_route_lanes(start_pos_3d, destination_pos_3d)
	active_route_3d.clear()
	active_route_2d.clear()
	active_instructions.clear()
	
	if lanes_route.is_empty():
		gps_route_updated.emit(active_route_2d, 0.0, active_instructions)
		return
		
	active_route_3d.append(start_pos_3d)
	active_route_2d.append(world_to_gps(start_pos_3d))
	
	var total_dist = 0.0
	
	for i in range(lanes_route.size()):
		var lane = lanes_route[i]
		total_dist += lane.get_total_length()
		var pts = lane.get_sampled_points(4.0)
		
		for pt in pts:
			active_route_3d.append(pt)
			active_route_2d.append(world_to_gps(pt))
			
		# Generar instrucciones de maniobra en intersecciones
		if i < lanes_route.size() - 1:
			var next_lane = lanes_route[i + 1]
			var maneuver = _get_maneuver_instruction(lane, next_lane)
			active_instructions.append({
				"distance": total_dist,
				"instruction": maneuver,
				"position_2d": world_to_gps(lane.sample_point_at_distance(lane.get_total_length()))
			})
			
	active_route_3d.append(destination_pos_3d)
	active_route_2d.append(world_to_gps(destination_pos_3d))
	
	gps_route_updated.emit(active_route_2d, total_dist, active_instructions)

func get_lanes_2d_polylines() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not network_manager:
		return result
		
	for lane in network_manager.lanes:
		if not lane:
			continue
		var pts_3d = lane.get_sampled_points(5.0)
		var pts_2d = PackedVector2Array()
		for pt in pts_3d:
			pts_2d.append(world_to_gps(pt))
		result.append(pts_2d)
		
	return result

func _get_maneuver_instruction(from_lane: TrafficLane3D, to_lane: TrafficLane3D) -> String:
	if not from_lane.curve or not to_lane.curve:
		return "CONTINÚE RECTO"
		
	var parent_intersection = _find_intersection_between(from_lane, to_lane)
	if parent_intersection:
		return parent_intersection.get_maneuver_name(from_lane, to_lane)
		
	return "SITÚESE EN EL CARRIL"

func _find_intersection_between(a: TrafficLane3D, b: TrafficLane3D) -> TrafficIntersection3D:
	var p = a.get_parent()
	while p:
		if p is TrafficIntersection3D:
			return p
		p = p.get_parent()
	return null
