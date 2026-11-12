extends Button

@export var default_count: int = 4
@export var name_patterns: Array = ["puert", "door"]

var _last_door_nodes: Array = []

func populate_buttons(container: Node, style_source: Node = null) -> void:
	if not container:
		push_warning("BotonPuertas: container nulo")
		return

	# Asegurar que el contenedor reciba eventos y esté en primer plano
	if container is Control:
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		var p = container.get_parent()
		if p:
			p.move_child(container, p.get_child_count() - 1)

	# Limpiar contenedor
	for child in container.get_children():
		child.queue_free()

	# Detectar vehículo ascendentemente
	var veh = _find_vehicle()
	var door_nodes: Array = []
	if veh:
		_collect_door_nodes(veh, door_nodes)

	var count = door_nodes.size()
	if count <= 0:
		count = default_count

	_last_door_nodes = door_nodes

	for i in range(count):
		var b = Button.new()
		b.name = "Puerta_%d" % i
		if i < door_nodes.size():
			b.text = door_nodes[i].name
		else:
			b.text = "Puerta %d" % (i + 1)

		# Copiar material/modulate desde style_source si existe
		if style_source and style_source is Control:
			if style_source.material and style_source.material is ShaderMaterial:
				b.material = style_source.material.duplicate()
			else:
				# Intentar copiar modulate si está disponible
				if "self_modulate" in style_source:
					b.self_modulate = style_source.self_modulate

		# Asegurar que el botón responda a clicks y pueda recibir foco
		if b is Control:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.focus_mode = Control.FOCUS_ALL

		var cb = Callable(self, "_on_puerta_pressed").bind(i)
		if not b.pressed.is_connected(cb):
			b.pressed.connect(cb)
		container.add_child(b)


func _on_puerta_pressed(idx: int) -> void:
	if idx < _last_door_nodes.size():
		var door = _last_door_nodes[idx]
		if door and door.has_method("toggle_door"):
			door.toggle_door()
			return
		print("BotonPuertas: puerta encontrada -> %s" % door.name if door else "nil")
	else:
		print("BotonPuertas: botón %d presionado (sin nodo asociado)" % (idx + 1))


func _find_vehicle() -> Node:
	var node: Node = self
	while node:
		var v = node.get("vehiculo")
		if v and v is Node:
			return v
		var vp = node.get("vehiculo_path")
		if vp:
			var resolved = node.get_node_or_null(vp)
			if resolved and resolved is Node:
				return resolved
		node = node.get_parent()
	return null


func _collect_door_nodes(node: Node, out_array: Array) -> void:
	for child in node.get_children():
		if not child:
			continue
		var lname = child.name.to_lower()
		var matched = false
		for p in name_patterns:
			if lname.find(p) != -1:
				matched = true
				break
		if matched:
			out_array.append(child)
		else:
			_collect_door_nodes(child, out_array)


