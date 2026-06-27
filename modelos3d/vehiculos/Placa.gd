@tool
extends Node3D

## Texto de la placa (formato colombiano: "ABC 123")
@export var plate_text: String = "ABC 123":
	set(v):
		plate_text = v
		_update_labels()

## Ciudad o municipio de la placa
@export var city: String = "BOGOTÁ":
	set(v):
		city = v
		_update_labels()

## Vehículo de servicio público → placa blanca con texto negro
## Vehículo particular → placa amarilla con texto negro
@export var publico: bool = false:
	set(v):
		publico = v
		_update_color()

func _ready() -> void:
	_update_labels()
	_update_color()

func _update_labels() -> void:
	if not is_inside_tree():
		return
	if has_node("LabelNumero"):
		$LabelNumero.text = plate_text
	if has_node("LabelCiudad"):
		$LabelCiudad.text = city

func _update_color() -> void:
	if not is_inside_tree():
		return
	if has_node("Face"):
		var mat: StandardMaterial3D = $Face.material_override
		if mat:
			mat = mat.duplicate() as StandardMaterial3D
			mat.albedo_color = Color(0.96, 0.96, 0.96, 1) if publico else Color(0.988, 0.82, 0.086, 1)
			$Face.material_override = mat

## Cambia placa y ciudad desde código en runtime
func set_plate(new_plate: String, new_city: String) -> void:
	plate_text = new_plate  # dispara setter → _update_labels()
	city = new_city          # dispara setter → _update_labels()

## Genera una placa colombiana aleatoria (formato "ABC 123")
static func generar_placa_colombiana() -> String:
	const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var r := RandomNumberGenerator.new()
	r.randomize()
	var letras: String = ""
	var numeros: String = ""
	for _i in 3:
		letras += LETRAS[r.randi() % 26]
	for _i in 3:
		numeros += str(r.randi() % 10)
	return letras + " " + numeros
