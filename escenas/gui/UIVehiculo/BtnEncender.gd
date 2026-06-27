extends Button

var _input_vehiculo = null
var _sonido_dual: Node3D = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_input_vehiculo = InputVehiculo
	pressed.connect(_on_boton_pulsado)
	await get_tree().process_frame
	_sonido_dual = _buscar_nodo_recursivo(get_tree().get_root(), "Sonido_dual")
	if _sonido_dual == null:
		_sonido_dual = _buscar_nodo_recursivo(get_tree().get_root(), "Sonidos")

func _buscar_nodo_recursivo(nodo: Node, nombre: String) -> Node:
	if nodo == null:
		return null
	if nodo.name == nombre:
		return nodo
	for hijo in nodo.get_children():
		var encontrado = _buscar_nodo_recursivo(hijo, nombre)
		if encontrado:
			return encontrado
	return null

func _on_boton_pulsado() -> void:
	if _input_vehiculo == null:
		_input_vehiculo = InputVehiculo
	if not is_instance_valid(_input_vehiculo):
		return

	# Búsqueda perezosa: si aún no se encontró el nodo de audio, reintentarlo ahora.
	if _sonido_dual == null or not is_instance_valid(_sonido_dual):
		_sonido_dual = _buscar_nodo_recursivo(get_tree().get_root(), "Sonido_dual")
		if _sonido_dual == null:
			_sonido_dual = _buscar_nodo_recursivo(get_tree().get_root(), "Sonidos")

	var encender = not _input_vehiculo.motor_encendido

	if encender:
		if _sonido_dual and _sonido_dual.has_method("solicitar_encendido"):
			_sonido_dual.solicitar_encendido()
		else:
			_input_vehiculo.motor_encendido = true
		if _input_vehiculo.freno_mano:
			_input_vehiculo.set_fmano(false)
	else:
		_input_vehiculo.motor_encendido = false
		if _sonido_dual and _sonido_dual.has_method("reproducir_apagar"):
			_sonido_dual.reproducir_apagar()
