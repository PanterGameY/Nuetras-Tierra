extends Node3D
class_name Semaforo
## Semáforo con ciclo automático. GestorTrafico.gd lo consulta cada frame
## (vía esta_en_verde()) para decidir si los vehículos cercanos deben
## frenar. No tiene física ni colisión: es solo estado + luces.

enum Estado { VERDE, AMARILLO, ROJO }

@export var duracion_verde: float = 8.0
@export var duracion_amarillo: float = 2.0
@export var duracion_rojo: float = 6.0

@onready var _luz_roja: MeshInstance3D = get_node_or_null("LuzRoja") as MeshInstance3D
@onready var _luz_amarilla: MeshInstance3D = get_node_or_null("LuzAmarilla") as MeshInstance3D
@onready var _luz_verde: MeshInstance3D = get_node_or_null("LuzVerde") as MeshInstance3D

var estado: Estado = Estado.VERDE

var _temporizador: Timer


func _ready() -> void:
	_temporizador = Timer.new()
	_temporizador.one_shot = true
	_temporizador.timeout.connect(_siguiente_estado)
	add_child(_temporizador)
	_entrar_estado(Estado.VERDE)


func esta_en_verde() -> bool:
	return estado == Estado.VERDE


func _entrar_estado(nuevo: Estado) -> void:
	estado = nuevo
	_actualizar_luces()
	match estado:
		Estado.VERDE:
			_temporizador.start(duracion_verde)
		Estado.AMARILLO:
			_temporizador.start(duracion_amarillo)
		Estado.ROJO:
			_temporizador.start(duracion_rojo)


func _siguiente_estado() -> void:
	match estado:
		Estado.VERDE:
			_entrar_estado(Estado.AMARILLO)
		Estado.AMARILLO:
			_entrar_estado(Estado.ROJO)
		Estado.ROJO:
			_entrar_estado(Estado.VERDE)


func _actualizar_luces() -> void:
	_set_brillo(_luz_roja, estado == Estado.ROJO)
	_set_brillo(_luz_amarilla, estado == Estado.AMARILLO)
	_set_brillo(_luz_verde, estado == Estado.VERDE)


func _set_brillo(luz: MeshInstance3D, encendida: bool) -> void:
	if luz == null or not is_instance_valid(luz):
		return
	var material := luz.get_active_material(0) as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = 4.0 if encendida else 0.05
