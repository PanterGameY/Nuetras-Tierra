extends Control

# Script para el panel del vehículo.
# Muestra la marcha actual en el Label hijo del Panel "marcha visual".
# P = Parqueo, R = Reversa, N = Neutro, 1-5 = marcha en Drive.

@export var label_marcha: Label

var _motor: Node = null

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	_ensure_motor()
	if label_marcha == null:
		return
	label_marcha.text = _get_gear_text()

func _get_gear_text() -> String:
	if InputVehiculo.marcha_actual == InputVehiculo.Marcha.REVERSA:
		return "R"
	if _motor != null and is_instance_valid(_motor):
		return str(_motor.current_gear + 1)
	return "-"

func _ensure_motor() -> void:
	if _motor != null and is_instance_valid(_motor):
		return
	_motor = _search_node_by_name(get_tree().get_root(), "Motor")

func _search_node_by_name(node: Node, target: String) -> Node:
	for child in node.get_children():
		if child.name == target:
			return child
		var found = _search_node_by_name(child, target)
		if found:
			return found
	return null
