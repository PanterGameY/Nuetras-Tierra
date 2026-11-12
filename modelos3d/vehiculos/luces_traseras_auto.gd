# luces_traseras_auto.gd - Exclusivo para Luces Traseras y Freno (stop y coculloT)
@tool
extends Node3D

@export_group("Configuración Luces Traseras")
## Si es verdadero, creará las luces por código en la posición de cada Marker3D asignado.
@export var crear_luces_automaticas: bool = true

## Color de la luz trasera / stop (Rojo puro)
@export var color_luz: Color = Color(1.0, 0.04, 0.02, 1.0)

## Rango de proyección de la luz trasera hacia atrás (metros)
@export var rango_luz: float = 3.5

## Energía de luz de posición nocturna (se activa cuando los faros delanteros están encendidos)
@export var energia_posicion: float = 0.6

## Energía de luz al frenar
@export var energia_freno: float = 8.0

## Velocidad de ráfaga estroboscópica de los coculloT al frenar (Hz)
@export var velocidad_estroboscopica: float = 14.0

## Umbral de pedal de freno para activar stop
@export var umbral_freno: float = 0.05

## Estado de presencia del conductor en el vehículo
@export var conductor_presente: bool = false

@export_group("Selección de Nodos (Inspector)")
## Asigna aquí los Marker3D / Nodos de las Luces de Stop / Posición Traseras (ej. TD, TI)
@export var luces_stop: Array[NodePath] = []

## Asigna aquí los Marker3D / Nodos de los Cocullos Traseros (coculloT estroboscópicos)
@export var luces_cocullos_traseros: Array[NodePath] = []

var _luces_stop: Array[Light3D] = []
var _cocullot_lights: Array[Light3D] = []

var _energia_actual: float = 0.0
var _strobe_timer: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if crear_luces_automaticas:
		_crear_luces_por_codigo()
	_actualizar_luces(0.0, 0.0)

func _limpiar_luces_existentes() -> void:
	for s in _luces_stop: if is_instance_valid(s): s.queue_free()
	for cs in _cocullot_lights: if is_instance_valid(cs): cs.queue_free()
		
	_luces_stop.clear()
	_cocullot_lights.clear()

func _resolver_marker(path: NodePath) -> Marker3D:
	var nodo := get_node_or_null(path)
	if is_instance_valid(nodo) and nodo is Marker3D:
		return nodo as Marker3D
	var nombre_base := str(path).get_file()
	if not nombre_base.is_empty():
		var child := find_child(nombre_base, true, false)
		if is_instance_valid(child) and child is Marker3D:
			return child as Marker3D
	return null

func _crear_luces_por_codigo() -> void:
	_limpiar_luces_existentes()

	var stop_markers: Array[Marker3D] = []
	var cocullo_markers: Array[Marker3D] = []

	# 1. Resolver desde la configuración manual del Inspector si se asignaron NodePaths
	for path in luces_stop:
		if not path.is_empty():
			var node := _resolver_marker(path)
			if is_instance_valid(node) and not stop_markers.has(node):
				stop_markers.append(node)

	for path in luces_cocullos_traseros:
		if not path.is_empty():
			var node := _resolver_marker(path)
			if is_instance_valid(node) and not cocullo_markers.has(node):
				cocullo_markers.append(node)

	# 2. Fallback: Autodetección de Marker3D si los arrays del Inspector están vacíos
	if stop_markers.is_empty() and cocullo_markers.is_empty():
		var all_children: Array[Node] = find_children("*", "Marker3D", true, false)
		if all_children.is_empty():
			for child in get_children():
				if child is Marker3D:
					all_children.append(child)

		for child in all_children:
			var m := child as Marker3D
			var n := m.name.to_lower().strip_edges()
			if n.contains("cocullo"):
				cocullo_markers.append(m)
			else:
				stop_markers.append(m)

	# 3. Instanciar composición de luces en los marcadores de stop
	for m in stop_markers:
		var spot := SpotLight3D.new()
		spot.name = "LuzStop_" + m.name
		spot.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		spot.position = Vector3(0.0, 0.0, 0.05)
		spot.light_color = color_luz
		spot.light_energy = 0.0
		spot.spot_range = rango_luz
		spot.spot_angle = 65.0
		spot.shadow_enabled = false
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 25.0
		spot.distance_fade_length = 10.0
		
		var omni := OmniLight3D.new()
		omni.name = "Resplandor_" + m.name
		omni.position = Vector3(0.0, 0.0, 0.05)
		omni.light_color = color_luz
		omni.light_energy = 0.0
		omni.omni_range = 1.0
		omni.shadow_enabled = false

		m.add_child(spot)
		m.add_child(omni)

		_luces_stop.append(spot)
		_luces_stop.append(omni)

	# 4. Instanciar composición de luces en los cocullos traseros
	for m in cocullo_markers:
		var spot_strobe := SpotLight3D.new()
		spot_strobe.name = "LuzStrobe_" + m.name
		spot_strobe.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		spot_strobe.position = Vector3(0.0, 0.0, 0.05)
		spot_strobe.light_color = color_luz
		spot_strobe.light_energy = 0.0
		spot_strobe.spot_range = 4.0
		spot_strobe.spot_angle = 65.0
		spot_strobe.shadow_enabled = false

		var omni_strobe := OmniLight3D.new()
		omni_strobe.name = "ResplandorStrobe_" + m.name
		omni_strobe.position = Vector3(0.0, 0.0, 0.05)
		omni_strobe.light_color = color_luz
		omni_strobe.light_energy = 0.0
		omni_strobe.omni_range = 1.2
		omni_strobe.shadow_enabled = false

		m.add_child(spot_strobe)
		m.add_child(omni_strobe)

		_cocullot_lights.append(spot_strobe)
		_cocullot_lights.append(omni_strobe)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var frenando: bool = false
	var iv = get_node_or_null("/root/InputVehiculo")
	
	if conductor_presente and is_instance_valid(iv):
		var val_freno: float = iv.get("freno") if "freno" in iv else 0.0
		var val_freno_mano: bool = iv.get("freno_mano") if "freno_mano" in iv else false
		frenando = val_freno > umbral_freno or val_freno_mano

	# Comprobar si los faros delanteros están encendidos
	var faros_delanteros_on: bool = false
	var del_node: Node = get_node_or_null("../Luces delanteras")
	if del_node == null:
		del_node = get_node_or_null("../luces delanteras")
	if del_node == null and get_parent():
		del_node = get_parent().find_child("*delanteras*", true, false)
	if del_node == null and get_parent():
		del_node = get_parent().find_child("*Delanteras*", true, false)
	if is_instance_valid(del_node) and "modo_luces" in del_node:
		faros_delanteros_on = (del_node.modo_luces > 0)

	# 1. Energía de posición / stop estático
	var reposo_efectivo: float = (energia_posicion if faros_delanteros_on else 0.0)
	var energia_objetivo: float = 0.0
	if conductor_presente:
		energia_objetivo = energia_freno if frenando else reposo_efectivo
	else:
		energia_objetivo = 0.0

	_energia_actual = lerpf(_energia_actual, energia_objetivo, delta * 18.0)

	# 2. Parpadeo estroboscópico sincronizado para coculloT
	var energia_strobe: float = 0.0
	if conductor_presente and frenando:
		_strobe_timer += delta * velocidad_estroboscopica
		var fase := fmod(_strobe_timer, 1.0)
		var flash_activo := (fase < 0.5)
		energia_strobe = (energia_freno * 1.25) if flash_activo else 0.0
	else:
		_strobe_timer = 0.0
		energia_strobe = 0.0

	_actualizar_luces(_energia_actual, energia_strobe)

func _actualizar_luces(energia_stop: float, energia_strobe: float) -> void:
	for luz in _luces_stop:
		if is_instance_valid(luz):
			luz.visible = (energia_stop > 0.01)
			if luz is SpotLight3D: luz.light_energy = energia_stop
			elif luz is OmniLight3D: luz.light_energy = energia_stop * 0.40

	for luz_c in _cocullot_lights:
		if is_instance_valid(luz_c):
			luz_c.visible = (energia_strobe > 0.01)
			if luz_c is SpotLight3D: luz_c.light_energy = energia_strobe
			elif luz_c is OmniLight3D: luz_c.light_energy = energia_strobe * 0.35

func set_conductor_presente(presente: bool) -> void:
	conductor_presente = presente
	if not conductor_presente:
		_energia_actual = 0.0
		_strobe_timer = 0.0
		_actualizar_luces(0.0, 0.0)
