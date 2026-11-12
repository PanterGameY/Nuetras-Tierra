@tool
extends Node3D
class_name TrafficIntersection3D

## ══════════════════════════════════════════════════════════════════════════════
##  TrafficIntersection3D.gd
##  Gestor de Cruces, Intersecciones, Retornos y Semáforos de Tráfico 3D.
## ══════════════════════════════════════════════════════════════════════════════

signal light_state_changed(phase_index: int, state: String)

enum IntersectionType {
	CRUCE_4_VIAS,
	CRUCE_3_VIAS_T,
	RETORNO_U_TURN,
	ROTONDA,
	INCORPORACION
}

enum LightState {
	GREEN,
	YELLOW,
	RED
}

@export var intersection_name: String = "Interseccion_01"
@export var type: IntersectionType = IntersectionType.CRUCE_4_VIAS

## Carriles que ingresan a la intersección.
@export var incoming_lanes: Array[TrafficLane3D] = []

## Carriles que salen de la intersección.
@export var outgoing_lanes: Array[TrafficLane3D] = []

## Carriles internos de retorno (U-Turn) específicos.
@export var u_turn_lanes: Array[TrafficLane3D] = []

## Control de Semáforo:
@export var has_traffic_lights: bool = true
@export var green_duration: float = 10.0
@export var yellow_duration: float = 3.0
@export var red_duration: float = 2.0

## Fases del semáforo (Grupos de carriles habilitados en cada fase).
## Ej: Fase 0 = Carriles Eje N-S, Fase 1 = Carriles Eje E-O.
@export var phase_incoming_groups: Array[Array] = []

var current_phase: int = 0
var current_light_state: LightState = LightState.GREEN
var phase_timer: float = 0.0

func _ready() -> void:
	if phase_incoming_groups.is_empty() and not incoming_lanes.is_empty():
		# Crear 2 fases por defecto dividiendo carriles
		var half = incoming_lanes.size() / 2
		phase_incoming_groups.append(incoming_lanes.slice(0, half))
		phase_incoming_groups.append(incoming_lanes.slice(half))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not has_traffic_lights or phase_incoming_groups.is_empty():
		return
		
	phase_timer += delta
	var current_limit = _get_current_duration()
	
	if phase_timer >= current_limit:
		phase_timer = 0.0
		_advance_traffic_light()

func _advance_traffic_light() -> void:
	match current_light_state:
		LightState.GREEN:
			current_light_state = LightState.YELLOW
		LightState.YELLOW:
			current_light_state = LightState.RED
		LightState.RED:
			current_light_state = LightState.GREEN
			current_phase = (current_phase + 1) % phase_incoming_groups.size()
			
	light_state_changed.emit(current_phase, get_light_state_string())

func get_light_state_string() -> String:
	match current_light_state:
		LightState.GREEN: return "GREEN"
		LightState.YELLOW: return "YELLOW"
		LightState.RED: return "RED"
	return "GREEN"

func can_lane_proceed(lane: TrafficLane3D) -> bool:
	if not has_traffic_lights:
		return true
		
	if phase_incoming_groups.is_empty():
		return true
		
	var active_group = phase_incoming_groups[current_phase]
	if active_group.has(lane):
		return current_light_state == LightState.GREEN or current_light_state == LightState.YELLOW
	return false

func is_u_turn(from_lane: TrafficLane3D, to_lane: TrafficLane3D) -> bool:
	if u_turn_lanes.has(to_lane) or from_lane.lane_type == TrafficLane3D.LaneType.RETORNO:
		return true
	# Si la dirección inversa del vector inicial y final difieren casi 180 grados
	if from_lane.curve and to_lane.curve:
		var dir_from = (from_lane.sample_point_at_distance(from_lane.get_total_length()) - from_lane.sample_point_at_distance(0.0)).normalized()
		var dir_to = (to_lane.sample_point_at_distance(to_lane.get_total_length()) - to_lane.sample_point_at_distance(0.0)).normalized()
		if dir_from.dot(dir_to) < -0.7:
			return true
	return false

func get_maneuver_name(from_lane: TrafficLane3D, to_lane: TrafficLane3D) -> String:
	if is_u_turn(from_lane, to_lane):
		return "RETORNO EN U"
		
	if not from_lane.curve or not to_lane.curve:
		return "SIGA RECTO"
		
	var dir_from = (from_lane.sample_point_at_distance(from_lane.get_total_length()) - from_lane.sample_point_at_distance(from_lane.get_total_length() - 2.0)).normalized()
	var dir_to = (to_lane.sample_point_at_distance(2.0) - to_lane.sample_point_at_distance(0.0)).normalized()
	
	var cross_y = dir_from.cross(dir_to).y
	var dot = dir_from.dot(dir_to)
	
	if dot > 0.7:
		return "SIGA RECTO"
	elif cross_y > 0.2:
		return "GIRE A LA IZQUIERDA"
	elif cross_y < -0.2:
		return "GIRE A LA DERECHA"
		
	return "CONTINUE POR EL CARRIL"

func _get_current_duration() -> float:
	match current_light_state:
		LightState.GREEN: return green_duration
		LightState.YELLOW: return yellow_duration
		LightState.RED: return red_duration
	return 5.0
