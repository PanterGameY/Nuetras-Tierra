class_name TalanqueraParqueo
extends Node3D

@export var angulo_abierto_deg: float = 72.0
@export var velocidad_brazo: float = 4.5
@export var radio_deteccion: float = 5.5

var _brazo: Node3D = null
var _area: Area3D = null
var _vehiculos_en_zona: int = 0
var _angulo_actual: float = 0.0

func _ready() -> void:
	_brazo = find_child("BrazoTalanquera", true, false) as Node3D
	_configurar_sensor()

func _configurar_sensor() -> void:
	_area = Area3D.new()
	_area.name = "SensorVehiculo"
	_area.monitoring = true
	_area.monitorable = false
	_area.collision_layer = 0
	_area.collision_mask = 0xFFFFFFFF
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.5, 3.2, 7.0)
	cs.shape = box
	cs.position = Vector3(1.5, 1.4, 0.0)
	_area.add_child(cs)
	add_child(_area)

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _es_vehiculo_o_jugador(body: Node) -> bool:
	if body == null:
		return false
	if body is VehicleBody3D or body is CharacterBody3D:
		return true
	if body.is_in_group("vehiculo") or body.is_in_group("jugador") or body.is_in_group("player"):
		return true
	var n := body.name.to_lower()
	return n.contains("vehiculo") or n.contains("camion") or n.contains("tracto") or n.contains("carro") or n.contains("player") or n.contains("jugador")

func _on_body_entered(body: Node) -> void:
	if _es_vehiculo_o_jugador(body):
		_vehiculos_en_zona += 1

func _on_body_exited(body: Node) -> void:
	if _es_vehiculo_o_jugador(body):
		_vehiculos_en_zona = maxi(0, _vehiculos_en_zona - 1)

func _physics_process(delta: float) -> void:
	if _brazo == null:
		return
	var objetivo_rad := deg_to_rad(angulo_abierto_deg) if _vehiculos_en_zona > 0 else 0.0
	_angulo_actual = move_toward(_angulo_actual, objetivo_rad, velocidad_brazo * delta)
	_brazo.rotation.z = _angulo_actual
