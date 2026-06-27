#script para ver el funcionamiento del motor.
#este script saca un boton cuando el jugador esta cerca de el vehiculo,
#y al presionar debe aparecer los recursos del motor y su estado.

extends Area3D

@export var detection_radius: float = 3.0
@export_node_path("Control") var boton_interaccion_path: NodePath = NodePath("")
@export var prefer_zona_entrada: bool = true
@export var vehicle_flag_property: String = "jugador_cerca"
@export var interact_action: String = "interactuar"
@export var create_button_if_missing: bool = true
@export var button_text: String = "Interactuar"

var jugador: Node3D
var boton_interaccion: Control
var panel_estado
var aceite_litros: float = 4.5
var refrigerante_porcentaje: int = 80
var motor_estado: String = "Desconocido"
@export var debug: bool = false
var _was_near: bool = false
var _vehiculo: Node = null

func _ready():
	jugador = _buscar_jugador_por_grupo()
	if not jugador:
		jugador = _buscar_nodo_global("Jugador")
	# Priorizar botón especificado por Path en el Inspector
	if boton_interaccion_path != NodePath(""):
		boton_interaccion = get_node_or_null(boton_interaccion_path) as Control
	if not boton_interaccion:
		boton_interaccion = _buscar_boton_interactuar(jugador)
	# Crear botón desde script si no se encontró y está habilitado
	if not boton_interaccion and create_button_if_missing:
		_crear_boton_interaccion()
	if boton_interaccion:
		boton_interaccion.visible = false
	panel_estado = _buscar_nodo_global("PanelEstadoMotor")
	if not panel_estado:
		_crear_panel_estado()
	# Referencia al rigidbody del vehículo que contiene este Area3D
	_vehiculo = _find_rigidbody(self)
	if debug:
		print("deteccion_motor: jugador=", jugador, " boton=", boton_interaccion, " vehiculo=", _vehiculo)

func _buscar_jugador_por_grupo():
	if not get_tree():
		return null
	var nodes := get_tree().get_nodes_in_group("jugador")
	for n in nodes:
		if n and n is Node3D:
			return n
	return null

func _find_rigidbody(node: Node) -> RigidBody3D:
	var n = node.get_parent()
	while n:
		if n is RigidBody3D:
			return n
		n = n.get_parent()
	return null

func _buscar_boton_interactuar(jugador_node):
	# Intentar localizar el botón dentro del nodo del jugador (UIpie)
	if jugador_node:
		if jugador_node.has_node("UIpie"):
			var ui_pie = jugador_node.get_node_or_null("UIpie")
			if ui_pie:
				var btn = ui_pie.get_node_or_null("Controles/Interactuar")
				if btn:
					return btn
				btn = ui_pie.get_node_or_null("Controles/BotonInteractuar")
				if btn:
					return btn
	# Búsqueda global por nombres comunes
	var root = get_tree().get_root() if get_tree() else null
	if root and root.has_method("find_node"):
		var f = root.find_node("Interactuar", true, false)
		if f:
			return f
		f = root.find_node("BotonInteractuar", true, false)
		if f:
			return f
	# Búsqueda por subcadena en todo el árbol (case-insensitive)
	return _buscar_nodo_global_por_subcadena(["interact", "interactuar", "botoninteractu", "botoninteraccion"]) 

func _buscar_nodo_global_por_subcadena(subs: Array):
	var root = get_tree().get_root() if get_tree() else null
	if not root:
		return null
	var scene_root = get_tree().get_current_scene() if get_tree().has_method("get_current_scene") else null
	if not scene_root:
		if root and root.has_method("get_child_count") and root.get_child_count() > 0:
			scene_root = root.get_child(0)
	var queue := []
	if scene_root:
		queue.append(scene_root)
	else:
		queue.append(root)
	while queue.size() > 0:
		var n = queue.pop_front()
		if n and n is Node:
			var lname = str(n.name).to_lower()
			for s in subs:
				if lname.find(str(s).to_lower()) != -1:
					if n is Control:
						return n
			if n.has_method("get_child_count"):
				for j in range(n.get_child_count()):
					queue.append(n.get_child(j))
	return null

func _crear_boton_interaccion():
	# Intentar colocar el botón en UIpie/Controles si existe
	var ui_parent = null
	if jugador and jugador.has_node("UIpie"):
		ui_parent = jugador.get_node_or_null("UIpie")
	if not ui_parent:
		var scene_root2 = get_tree().get_current_scene() if get_tree().has_method("get_current_scene") else null
		if scene_root2:
			ui_parent = scene_root2.get_node_or_null("UIpie")
	if not ui_parent:
		# fallback: buscar cualquier CanvasLayer llamado UIpie en el árbol
		ui_parent = _buscar_nodo_global("UIpie")

	var controles: Node = null
	if ui_parent and ui_parent is Node:
		controles = ui_parent.get_node_or_null("Controles")
		if not controles:
			controles = HBoxContainer.new()
			controles.name = "Controles"
			ui_parent.add_child(controles)
	else:
		# fallback: añadir a la escena principal
		var root2 = get_tree().get_current_scene() if get_tree().has_method("get_current_scene") else null
		if root2:
			controles = root2.get_node_or_null("Controles")
			if not controles:
				controles = HBoxContainer.new()
				controles.name = "Controles"
				root2.add_child(controles)

	if controles:
		var btn = Button.new()
		btn.name = "Interactuar"
		btn.text = button_text
		btn.visible = false
		controles.add_child(btn)
		boton_interaccion = btn
		if debug:
			print("deteccion_motor: boton Interactuar creado en", controles.get_path())
	elif debug:
		print("deteccion_motor: no se pudo crear boton Interactuar; no se encontró contenedor UI")
	

func _buscar_nodo_global(nombre: String):
	var root = get_tree().get_root()
	var scene_root = null
	if get_tree().has_method("get_current_scene"):
		scene_root = get_tree().get_current_scene()
	if not scene_root and root and root.has_method("get_child_count") and root.get_child_count() > 0:
		for i in range(root.get_child_count()):
			var candidate = root.get_child(i)
			if candidate and candidate.has_method("get_child_count"):
				scene_root = candidate
				break
	if not scene_root:
		if root and root.has_method("find_node"):
			return root.find_node(nombre, true, false)
		return null
	var queue := [scene_root]
	while queue.size() > 0:
		var n = queue.pop_front()
		if n.name == nombre:
			return n
		if n.has_method("get_child_count"):
			for j in range(n.get_child_count()):
				queue.append(n.get_child(j))
	return null

func _process(_delta):
	if not jugador:
		return

	var distancia = global_transform.origin.distance_to(jugador.global_transform.origin)
	var near: bool = distancia < detection_radius
	# Si la ZonaEntrada del vehículo está activa, preferimos esa lógica y no mostramos nuestro botón
	if prefer_zona_entrada and _vehiculo:
		if _vehiculo.has_method("get"):
			var flag = _vehiculo.get(vehicle_flag_property)
			if flag == true:
				if boton_interaccion:
					boton_interaccion.visible = false
				if debug:
					print("deteccion_motor: ZonaEntrada activa en vehículo; omitiendo detección de motor")
				_was_near = false
				return

	if near:
		if boton_interaccion:
			boton_interaccion.visible = true
		if debug and not _was_near:
			print("deteccion_motor: jugador entró a rango. distancia=", distancia)
		if Input.is_action_just_pressed(interact_action):
			_mostrar_estado_motor()
	else:
		if boton_interaccion:
			boton_interaccion.visible = false
		if debug and _was_near:
			print("deteccion_motor: jugador salió de rango. distancia=", distancia)

	_was_near = near

func _crear_panel_estado():
	# Creamos un diálogo simple para mostrar el estado del motor si no existe
	var dialog := AcceptDialog.new()
	dialog.name = "PanelEstadoMotor"
	dialog.title = "Estado del motor"
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxEstadoMotor"
	var aceite_lbl := Label.new()
	aceite_lbl.name = "LabelAceite"
	aceite_lbl.text = ""
	var refr_lbl := Label.new()
	refr_lbl.name = "LabelRefrigerante"
	refr_lbl.text = ""
	var fuel_lbl := Label.new()
	fuel_lbl.name = "LabelCombustible"
	fuel_lbl.text = ""
	vbox.add_child(aceite_lbl)
	vbox.add_child(refr_lbl)
	vbox.add_child(fuel_lbl)
	dialog.add_child(vbox)
	var parent = null
	if get_tree().has_method("get_current_scene"):
		parent = get_tree().get_current_scene()
	else:
		var root = get_tree().get_root()
		if root and root.has_method("get_child_count") and root.get_child_count() > 0:
			parent = root.get_child(0)
	if parent:
		parent.add_child(dialog)
	else:
		add_child(dialog)
	panel_estado = dialog

func _mostrar_estado_motor():
	# Evaluamos el estado básico a partir de los valores y actualizamos la UI
	if aceite_litros <= 1.0:
		motor_estado = "Bajo nivel de aceite"
	elif aceite_litros <= 3.0:
		motor_estado = "Nivel de aceite medio"
	else:
		motor_estado = "Aceite OK"

	if refrigerante_porcentaje < 50:
		motor_estado += " / Refrigerante bajo"
	elif refrigerante_porcentaje < 75:
		motor_estado += " / Refrigerante medio"
	else:
		motor_estado += " / Refrigerante OK"

	if not panel_estado:
		_crear_panel_estado()

	var aceite_lbl := panel_estado.get_node("VBoxEstadoMotor/LabelAceite") as Label
	var refr_lbl := panel_estado.get_node("VBoxEstadoMotor/LabelRefrigerante") as Label
	var fuel_lbl := panel_estado.get_node("VBoxEstadoMotor/LabelCombustible") as Label
	if aceite_lbl:
		aceite_lbl.text = "Aceite: %s L" % str(aceite_litros)
	if refr_lbl:
		refr_lbl.text = "Refrigerante: %s%%" % str(refrigerante_porcentaje)

	# Intentar leer combustible desde el nodo Motor del vehículo
	var fuel_type_str: String = "Desconocido"
	var fuel_level_str: String = "N/A"
	if _vehiculo:
		var m = _vehiculo.get_node_or_null("Motor")
		if not m:
			m = _vehiculo.get_node_or_null("motor")
		if not m:
			for c in _vehiculo.get_children():
				if typeof(c.name) == TYPE_STRING and str(c.name).to_lower().find("motor") != -1:
					m = c
					break
		if m:
			if m.has_method("get"):
				# Leer propiedades expuestas en motor.gd (nuevos nombres en español)
				if m.get("tipo_combustible") != null:
					fuel_type_str = str(m.get("tipo_combustible"))
				if m.get("nivel_combustible_l") != null:
					fuel_level_str = str(m.get("nivel_combustible_l"))
	if fuel_lbl:
		fuel_lbl.text = "Combustible: %s — %s L" % [fuel_type_str, fuel_level_str]

	# Mostrar el diálogo centrado si soportado
	if panel_estado.has_method("popup_centered"):
		panel_estado.popup_centered()
	else:
		panel_estado.visible = true
