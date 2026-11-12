extends Control

signal camara_movida(relative_vector: Vector2)
signal camara_pinch(delta_dist)

var _toques: Dictionary = {}
var _distancia_pellizco_prev: float = -1.0
var _mouse_presionado: bool = false

# `controles` puede no apuntar correctamente según la jerarquía (CanvasLayer padre),
# por eso lo dejamos nullable y resolvemos nodos por nombre como fallback.
var controles: Control = null

func _toque_sobre_control(nombre: String, posicion_global: Vector2) -> bool:
	var control: Control = null
	if controles and controles.has_node(nombre):
		control = controles.get_node_or_null(nombre) as Control
	else:
		var root_scene = get_tree().get_current_scene()
		if root_scene:
			control = _buscar_nodo_recursivo(root_scene, nombre) as Control
		else:
			control = null
			var root = get_tree().get_root()
			if root and root.has_method("get_child_count"):
				control = _buscar_nodo_recursivo(root, nombre) as Control
	if not control or not control.visible:
		return false
	return control.get_global_rect().abs().has_point(posicion_global)


func _buscar_nodo_recursivo(n: Node, nombre: String) -> Node:
	if n == null:
		return null
	if n.name == nombre:
		return n
	if not n.has_method("get_child_count"):
		return null
	for i in range(n.get_child_count()):
		var c = n.get_child(i)
		var found = _buscar_nodo_recursivo(c, nombre)
		if found:
			return found
	return null

func _toque_sobre_boton_accion(posicion_global: Vector2) -> bool:
	# Además de los botones de acción, ignorar controles de pedales para
	# evitar que la zona de cámara capture sus toques.
	return _toque_sobre_control("Interactuar", posicion_global) \
		or _toque_sobre_control("BotonSalto", posicion_global) \
		or _toque_sobre_control("BotonAgachar", posicion_global) \
		or _toque_sobre_control("Acelerador", posicion_global) \
		or _toque_sobre_control("Freno", posicion_global)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("zona_camara")

func get_finger_id() -> int:
	if _toques.is_empty():
		return -1
	return _toques.keys()[0] as int

func _gui_input(event):
	if not is_visible_in_tree():
		return
	# --- MOUSE ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Ignorar clicks sobre botones
				if _toque_sobre_boton_accion(event.global_position):
					return
				_mouse_presionado = true
				get_viewport().set_input_as_handled()
			else:
				_mouse_presionado = false
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not _toque_sobre_boton_accion(event.global_position):
				emit_signal("camara_pinch", 5.0)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not _toque_sobre_boton_accion(event.global_position):
				emit_signal("camara_pinch", -5.0)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _mouse_presionado:
		camara_movida.emit(event.relative)
		get_viewport().set_input_as_handled()

	# --- TÁCTIL ---
	elif event is InputEventScreenTouch:
		if event.pressed:
			var pos = event.global_position if "global_position" in event else event.position
			# Ignorar toques sobre botones de acción
			if _toque_sobre_boton_accion(pos):
				return
			# Verificar que el joystick no tenga ese dedo
			var joystick = get_tree().get_first_node_in_group("joystick")
			if joystick and joystick.get("_touch_index") == event.index:
				return
			# Registrar toque
			_toques[event.index] = event.position
			# Si hay dos dedos, inicializar referencia de pellizco
			if _toques.size() >= 2:
				var k = _toques.keys()
				_distancia_pellizco_prev = (_toques[k[0]] as Vector2).distance_to(_toques[k[1]] as Vector2)
			get_viewport().set_input_as_handled()
		else:
			if _toques.has(event.index):
				_toques.erase(event.index)
				if _toques.size() < 2:
					_distancia_pellizco_prev = -1.0
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if _toques.has(event.index):
			_toques[event.index] = event.position
			# Si hay exactamente dos toques, procesar pellizco
			if _toques.size() == 2:
				var keys = _toques.keys()
				var dist: float = (_toques[keys[0]] as Vector2).distance_to(_toques[keys[1]] as Vector2)
				if _distancia_pellizco_prev > 0.0:
					var delta_dist: float = dist - _distancia_pellizco_prev
					emit_signal("camara_pinch", delta_dist)
				_distancia_pellizco_prev = dist
				get_viewport().set_input_as_handled()
			else:
				# Movimiento de un dedo: emitir rotación
				if event.index == get_finger_id():
					camara_movida.emit(event.relative)
					get_viewport().set_input_as_handled()
