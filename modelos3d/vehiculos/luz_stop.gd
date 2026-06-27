# Sistema de luces de freno (stop).
# Se activan cuando el jugador frena (pedal o freno de mano).

@tool
extends Node3D

@export_group("Luces de Freno", "luz_")
## Luces OmniLight3D/SpotLight3D que se encienden al frenar.
@export var luces: Array[NodePath] = []
## Mallas (MeshInstance3D) cuya emisión se intensifica al frenar.
@export var mallas: Array[NodePath] = []
## Umbral de presión de freno (0-1) para encender las luces. Evita parpadeos con toque leve.
@export var umbral_freno: float = 0.05
## Si el conductor está en el vehículo. Se setea desde coche.gd al subir/bajar.
@export var conductor_presente: bool = false

@export_group("Energía — Luces", "energia_")
## Energía de la luz (Light3D) cuando está frenando.
@export var energia_encendida: float = 10.0
## Energía de la luz cuando no está frenando (luz de posición tenue). 0 = apagada.
@export var energia_apagada: float = 0.5

@export_group("Emisión — Mallas", "emision_")
## Multiplicador de emisión del material al frenar.
@export var emision_encendida: float = 6.0
## Multiplicador de emisión del material en reposo (luz de posición). 0 = sin emisión.
@export var emision_apagada: float = 0.3

var _encendidas: bool = false
var _mallas_listas: bool = false


func _ready() -> void:
	_hacer_materiales_unicos()
	_aplicar(false)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var frenando: bool = false
	if conductor_presente:
		if is_instance_valid(InputVehiculo):
			frenando = InputVehiculo.freno > umbral_freno or InputVehiculo.freno_mano

	_aplicar(frenando)


func _hacer_materiales_unicos() -> void:
	for path in mallas:
		var mesh: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			continue
		var mat: Material = mesh.get_surface_override_material(0)
		if mat:
			mesh.set_surface_override_material(0, mat.duplicate())
		elif mesh.mesh and mesh.mesh.get_surface_count() > 0:
			mesh.set_surface_override_material(0, mesh.mesh.surface_get_material(0).duplicate())
	_mallas_listas = true


func _aplicar(encendido: bool) -> void:
	if _encendidas == encendido:
		return
	_encendidas = encendido

	for path in luces:
		var nodo: Light3D = get_node_or_null(path) as Light3D
		if nodo == null:
			continue
		nodo.visible = true
		nodo.light_energy = energia_encendida if encendido else energia_apagada

	if not _mallas_listas:
		_hacer_materiales_unicos()

	for path in mallas:
		var mesh: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			continue
		var mat: StandardMaterial3D = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat == null:
			continue
		mat.emission_enabled = true
		mat.emission_energy_multiplier = emision_encendida if encendido else emision_apagada


func set_conductor_presente(presente: bool) -> void:
	conductor_presente = presente
	if not conductor_presente:
		_aplicar(false)


func forzar_encendido() -> void:
	_aplicar(true)


func forzar_apagado() -> void:
	_aplicar(false)