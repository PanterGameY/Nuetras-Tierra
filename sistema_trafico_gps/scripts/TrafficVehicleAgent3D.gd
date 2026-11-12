extends CharacterBody3D
class_name TrafficVehicleAgent3D

## ══════════════════════════════════════════════════════════════════════════════
##  TrafficVehicleAgent3D.gd
##  Controlador de IA Vehicular con doble RayCast (25m progresivo + 6m emergencia)
##  Detecta otros agentes IA, camiones del jugador (RigidBody3D) y peatones (CharacterBody3D)
## ══════════════════════════════════════════════════════════════════════════════

signal lane_changed(new_lane: TrafficLane3D)
signal destination_reached()

@export var max_speed: float = 60.0 # en km/h
@export var acceleration: float = 8.0
@export var braking: float = 18.0
@export var safe_distance: float = 7.0
@export var long_detection_distance: float = 26.0
@export var rotation_speed: float = 10.0

var current_lane: TrafficLane3D = null
var current_distance: float = 0.0
var current_speed: float = 0.0 # en m/s

var route_lanes: Array[TrafficLane3D] = []
var route_index: int = 0

var network_manager: TrafficNetworkManager3D = null
var raycast_front: RayCast3D = null
var raycast_long: RayCast3D = null

func _ready() -> void:
	_setup_sensors()

func _setup_sensors() -> void:
	# Sensor corto (parada de emergencia)
	raycast_front = RayCast3D.new()
	raycast_front.name = "RayCastEmergencia"
	raycast_front.position = Vector3(0.0, 0.8, 0.0)
	raycast_front.target_position = Vector3(0.0, 0.0, -safe_distance)
	raycast_front.enabled = true
	add_child(raycast_front)

	# Sensor largo (desaceleración progresiva en carretera)
	raycast_long = RayCast3D.new()
	raycast_long.name = "RayCastPreventivo"
	raycast_long.position = Vector3(0.0, 0.8, 0.0)
	raycast_long.target_position = Vector3(0.0, 0.0, -long_detection_distance)
	raycast_long.enabled = true
	add_child(raycast_long)

func setup_vehicle(manager: TrafficNetworkManager3D, start_lane: TrafficLane3D) -> void:
	network_manager = manager
	current_lane = start_lane
	_update_cached_intersection()
	if current_lane:
		current_distance = 0.0
		global_transform = current_lane.sample_transform_at_distance(current_distance)

func reset_for_pool(manager: TrafficNetworkManager3D, start_lane: TrafficLane3D, start_distance: float = 0.0) -> void:
	network_manager = manager
	current_lane = start_lane
	current_distance = start_distance
	current_speed = 0.0
	route_lanes.clear()
	route_index = 0
	_update_cached_intersection()
	if current_lane:
		global_transform = current_lane.sample_transform_at_distance(current_distance)

func set_destination(target_pos: Vector3) -> void:
	if network_manager and current_lane:
		route_lanes = network_manager.find_route_lanes(global_position, target_pos)
		route_index = 0

func _physics_process(delta: float) -> void:
	if not current_lane or not current_lane.curve:
		return

	var target_speed_ms = (min(max_speed, current_lane.speed_limit) * 1000.0) / 3600.0
	var obstacle_factor = _check_obstacles()
	target_speed_ms *= obstacle_factor

	if current_speed < target_speed_ms:
		current_speed = move_toward(current_speed, target_speed_ms, acceleration * delta)
	else:
		var decel = braking * (1.6 if obstacle_factor <= 0.05 else 1.0)
		current_speed = move_toward(current_speed, target_speed_ms, decel * delta)

	current_distance += current_speed * delta
	var lane_length = current_lane.get_total_length()

	if current_distance >= lane_length:
		_on_lane_completed()
	else:
		var target_transform = current_lane.sample_transform_at_distance(current_distance)
		global_position = target_transform.origin

		var look_target = current_lane.sample_point_at_distance(current_distance + 1.5)
		var dir = (look_target - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			var target_rot = Transform3D().looking_at(dir, Vector3.UP).basis
			global_transform.basis = global_transform.basis.slerp(target_rot, rotation_speed * delta)

var _current_intersection: TrafficIntersection3D = null

func _update_cached_intersection() -> void:
	_current_intersection = null
	if current_lane:
		var p = current_lane.get_parent()
		while p:
			if p is TrafficIntersection3D:
				_current_intersection = p
				break
			p = p.get_parent()

func _es_obstaculo_valido(col: Object) -> bool:
	if col == null or col == self:
		return false
	if col is TrafficVehicleAgent3D or col is RigidBody3D or col is CharacterBody3D:
		return true
	return false

func _check_obstacles() -> float:
	# 1. Parada de emergencia (RayCast corto)
	if raycast_front and raycast_front.is_colliding():
		var col = raycast_front.get_collider()
		if _es_obstaculo_valido(col):
			return 0.0

	# 2. Semáforo en intersección
	if current_lane and (current_lane.get_total_length() - current_distance) < safe_distance:
		if _current_intersection and not _current_intersection.can_lane_proceed(current_lane):
			return 0.0

	# 3. Frenado progresivo a distancia (RayCast largo 26m)
	if raycast_long and raycast_long.is_colliding():
		var col_long = raycast_long.get_collider()
		if _es_obstaculo_valido(col_long):
			var dist = global_position.distance_to(raycast_long.get_collision_point())
			return clampf((dist - safe_distance) / maxf(long_detection_distance - safe_distance, 1.0), 0.0, 0.85)

	return 1.0

func _on_lane_completed() -> void:
	var next_lane: TrafficLane3D = null
	if not route_lanes.is_empty() and route_index < route_lanes.size() - 1:
		route_index += 1
		next_lane = route_lanes[route_index]
	elif not current_lane.next_lanes.is_empty():
		next_lane = current_lane.next_lanes.pick_random()

	if next_lane:
		current_lane = next_lane
		current_distance = 0.0
		_update_cached_intersection()
		lane_changed.emit(current_lane)
	else:
		current_speed = 0.0
		destination_reached.emit()
