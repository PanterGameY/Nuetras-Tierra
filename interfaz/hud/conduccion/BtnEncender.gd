extends Button

var _input_vehiculo: Node = null
var _sonido_dual: Node = null

func _get_iv() -> Node:
	if _input_vehiculo and is_instance_valid(_input_vehiculo):
		return _input_vehiculo
	if is_inside_tree():
		_input_vehiculo = get_node_or_null("/root/InputVehiculo")
	return _input_vehiculo

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_input_vehiculo = _get_iv()
	pressed.connect(_on_boton_pulsado)

func _obtener_vehiculo() -> Node:
	# 1. Buscar en ancestros directos (UIVehiculo suele ser hijo directo o tener propiedad vehiculo)
	var nodo: Node = get_parent()
	while nodo != null:
		if "vehiculo" in nodo and nodo.vehiculo != null and is_instance_valid(nodo.vehiculo):
			return nodo.vehiculo
		if nodo is RigidBody3D:
			return nodo
		nodo = nodo.get_parent()

	# 2. Si InputVehiculo conoce el vehículo actual
	var iv = _get_iv()
	if iv and "vehiculo_actual" in iv and is_instance_valid(iv.vehiculo_actual):
		return iv.vehiculo_actual

	# 3. Fallback: buscar el vehículo activo en la escena
	var tree = get_tree()
	if tree and tree.get_root():
		for v in tree.get_root().find_children("*", "RigidBody3D", true, false):
			if v.get("activo") == true:
				return v
	return null

func _obtener_sonido(veh: Node) -> Node:
	if not veh or not is_instance_valid(veh):
		return null
	var motor = veh.get_node_or_null("Motor")
	if motor:
		var s = motor.get_node_or_null("Sonidos")
		if s: return s
		s = motor.get_node_or_null("Sonido_dual")
		if s: return s
	var s2 = veh.get_node_or_null("Sonidos")
	if s2: return s2
	s2 = veh.get_node_or_null("Sonido_dual")
	if s2: return s2
	return _buscar_nodo_recursivo(veh, "Sonidos")

func _buscar_nodo_recursivo(nodo: Node, nombre: String) -> Node:
	if nodo == null or not is_instance_valid(nodo) or not nodo.is_inside_tree():
		return null
	if nodo.name == nombre:
		return nodo
	for hijo in nodo.get_children():
		var encontrado = _buscar_nodo_recursivo(hijo, nombre)
		if encontrado:
			return encontrado
	return null

func _on_boton_pulsado() -> void:
	var iv = _get_iv()
	if not iv:
		return

	var vehiculo = _obtener_vehiculo()
	var sonido = _obtener_sonido(vehiculo)

	var encender = not iv.get("motor_encendido") == true

	if encender:
		# Encendido garantizado e inmediato en el singleton
		iv.set("motor_encendido", true)
		if iv.get("freno_mano") == true and iv.has_method("set_fmano"):
			iv.call("set_fmano", false)
		if sonido:
			if sonido.has_method("reproducir_encender"):
				sonido.reproducir_encender()
			elif sonido.has_method("solicitar_encendido"):
				sonido.solicitar_encendido()
	else:
		iv.set("motor_encendido", false)
		if sonido and sonido.has_method("reproducir_apagar"):
			sonido.reproducir_apagar()
