extends Node3D
class_name TrafficVehiclePoolManager

## ══════════════════════════════════════════════════════════════════════════════
##  TrafficVehiclePoolManager.gd
##  Sistema de Object Pooling y Generación de Tráfico por Proximidad (200m).
## ══════════════════════════════════════════════════════════════════════════════

signal vehicle_spawned_from_pool(vehicle: TrafficVehicleAgent3D)
signal vehicle_recycled_to_pool(vehicle: TrafficVehicleAgent3D)

@export var pool_size: int = 25
@export var spawn_radius: float = 200.0
@export var despawn_radius: float = 240.0
@export var max_active_vehicles: int = 12
@export var vehicle_scenes: Array[PackedScene] = []

## Referencia al jugador u objeto respecto al cual se calcula la proximidad de 200m.
@export var tracked_player: Node3D = null

## Intervalo en segundos entre cada chequeo de reciclaje / generación.
@export var update_interval: float = 0.4

var network_manager: TrafficNetworkManager3D = null
var _inactive_pool: Array[TrafficVehicleAgent3D] = []
var _active_vehicles: Array[TrafficVehicleAgent3D] = []
var _timer: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return

func initialize_pool(manager: TrafficNetworkManager3D) -> void:
	network_manager = manager
	_clear_pool()
	
	if vehicle_scenes.is_empty():
		push_warning("[TrafficVehiclePoolManager] No hay vehicle_scenes configuradas en el Pool.")
		return

	for i in range(pool_size):
		var scene = vehicle_scenes.pick_random()
		var inst = scene.instantiate()
		if inst is TrafficVehicleAgent3D:
			add_child(inst)
			_deactivate_vehicle(inst)
			_inactive_pool.append(inst)

func _clear_pool() -> void:
	for v in _active_vehicles:
		if is_instance_valid(v):
			v.queue_free()
	for v in _inactive_pool:
		if is_instance_valid(v):
			v.queue_free()
	_active_vehicles.clear()
	_inactive_pool.clear()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not tracked_player or not network_manager:
		return
		
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_update_proximity_pooling()

func _update_proximity_pooling() -> void:
	var player_pos = tracked_player.global_position
	
	# 1. Reciclar vehículos activos que se hayan alejado > despawn_radius (ej: >240m)
	var i = _active_vehicles.size() - 1
	while i >= 0:
		var v = _active_vehicles[i]
		if not is_instance_valid(v):
			_active_vehicles.remove_at(i)
			i -= 1
			continue
			
		var dist = player_pos.distance_to(v.global_position)
		if dist > despawn_radius:
			recycle_vehicle(v)
		i -= 1
		
	# 2. Generar nuevos vehículos si estamos por debajo del límite de activos
	while _active_vehicles.size() < max_active_vehicles and not _inactive_pool.is_empty():
		var spawned = _spawn_vehicle_in_radius(player_pos)
		if not spawned:
			break

func _spawn_vehicle_in_radius(player_pos: Vector3) -> bool:
	if _inactive_pool.is_empty() or not network_manager or network_manager.lanes.is_empty():
		return false
		
	# Buscar un carril y punto que esté dentro del rango de generación (ej: 120m a 190m del jugador)
	var valid_lane: TrafficLane3D = null
	var spawn_dist_on_lane: float = 0.0
	var spawn_point_3d: Vector3 = Vector3.ZERO
	
	var candidates: Array[TrafficLane3D] = []
	for lane in network_manager.lanes:
		if not lane or not lane.is_active:
			continue
		var mid_pt = lane.sample_point_at_distance(lane.get_total_length() * 0.5)
		var d = player_pos.distance_to(mid_pt)
		if d <= spawn_radius and d >= 50.0:
			candidates.append(lane)
			
	if candidates.is_empty():
		valid_lane = network_manager.lanes.pick_random()
	else:
		valid_lane = candidates.pick_random()
		
	spawn_dist_on_lane = randf_range(0.0, valid_lane.get_total_length())
	spawn_point_3d = valid_lane.sample_point_at_distance(spawn_dist_on_lane)
	
	# Tomar vehículo del pool inactivo
	var vehicle = _inactive_pool.pop_back() as TrafficVehicleAgent3D
	_active_vehicles.append(vehicle)
	
	_activate_vehicle(vehicle, valid_lane, spawn_dist_on_lane, spawn_point_3d)
	vehicle_spawned_from_pool.emit(vehicle)
	return true

func recycle_vehicle(vehicle: TrafficVehicleAgent3D) -> void:
	if _active_vehicles.has(vehicle):
		_active_vehicles.erase(vehicle)
		_deactivate_vehicle(vehicle)
		_inactive_pool.append(vehicle)
		vehicle_recycled_to_pool.emit(vehicle)

func _activate_vehicle(vehicle: TrafficVehicleAgent3D, lane: TrafficLane3D, distance_on_lane: float, pos_3d: Vector3) -> void:
	vehicle.process_mode = PROCESS_MODE_INHERIT
	vehicle.visible = true
	vehicle.global_position = pos_3d
	if vehicle.has_method("reset_for_pool"):
		vehicle.reset_for_pool(network_manager, lane, distance_on_lane)
	else:
		vehicle.setup_vehicle(network_manager, lane)

func _deactivate_vehicle(vehicle: TrafficVehicleAgent3D) -> void:
	vehicle.process_mode = PROCESS_MODE_DISABLED
	vehicle.visible = false
	vehicle.global_position = Vector3(0, -9999, 0) # Mover fuera de la vista
