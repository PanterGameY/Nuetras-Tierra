# luces_delanteras_auto.gd - Sistema Profesional y Realista de Faros Delanteros y Cocullos (Tecla Z)
@tool
extends Node3D

@export_group("Configuración Faros Delanteros")
## Si es verdadero, creará la composición de luces por código en la posición de cada Marker3D asignado.
@export var crear_luces_automaticas: bool = true

## Color principal de la luz (Blanco Neutro / Xenón de alta visibilidad)
@export var color_luz: Color = Color(0.96, 0.98, 1.0, 1.0)

## Color para los cocullos / cuartos de posición (Ámbar cálido realista)
@export var color_cocullos: Color = Color(1.0, 0.72, 0.20, 1.0)

## Alcance del haz principal en metros (Luces Bajas)
@export var alcance_bajas: float = 45.0

## Alcance del haz principal en metros (Luces Altas)
@export var alcance_altas: float = 95.0

## Energía de iluminación (Luces Bajas)
@export var energia_bajas: float = 18.0

## Energía de iluminación (Luces Altas)
@export var energia_altas: float = 42.0

## Tecla para alternar encendido de faros (Z por defecto)
@export var tecla_activacion: Key = KEY_Z

## Estado del conductor en el vehículo
@export var conductor_presente: bool = false

## Estado actual de los faros: 0 = Apagadas, 1 = Bajas, 2 = Altas
@export_enum("Apagadas:0", "Luces Bajas:1", "Luces Altas:2") var modo_luces: int = 0

@export_group("Selección de Nodos (Inspector)")
## Asigna aquí los Marker3D / Nodos de los Faros Delanteros Principales (ej. DD, DI)
@export var luces_principales: Array[NodePath] = []

## Asigna aquí los Marker3D / Nodos de los Cocullos Delanteros (ej. Cocullo1, Cocullo2)
@export var luces_cocullos: Array[NodePath] = []

var _luces_spot: Array[SpotLight3D] = []
var _luces_ancho: Array[SpotLight3D] = []
var _luces_omni: Array[OmniLight3D] = []

var _cocullo_spot: Array[SpotLight3D] = []
var _cocullo_omni: Array[OmniLight3D] = []

var _energia_actual: float = 0.0
var _energia_cocullo_actual: float = 0.0
var _pitch_actual: float = -3.2
var _angulo_actual: float = 36.0
var _rango_actual: float = 45.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if crear_luces_automaticas:
		_crear_luces_por_codigo()
	_rango_actual = alcance_bajas
	_actualizar_luces(0.0, 0.0, alcance_bajas, deg_to_rad(-3.2), 36.0)

func _limpiar_luces_existentes() -> void:
	for s in _luces_spot: if is_instance_valid(s): s.queue_free()
	for a in _luces_ancho: if is_instance_valid(a): a.queue_free()
	for o in _luces_omni: if is_instance_valid(o): o.queue_free()
	for cs in _cocullo_spot: if is_instance_valid(cs): cs.queue_free()
	for co in _cocullo_omni: if is_instance_valid(co): co.queue_free()

	_luces_spot.clear()
	_luces_ancho.clear()
	_luces_omni.clear()
	_cocullo_spot.clear()
	_cocullo_omni.clear()

func _crear_luces_por_codigo() -> void:
	_limpiar_luces_existentes()

	var main_markers: Array[Marker3D] = []
	var cocullo_markers: Array[Marker3D] = []

	# 1. Resolver desde la configuración del Inspector si se asignaron NodePaths
	for path in luces_principales:
		if not path.is_empty():
			var node := get_node_or_null(path) as Marker3D
			if is_instance_valid(node) and not main_markers.has(node):
				main_markers.append(node)

	for path in luces_cocullos:
		if not path.is_empty():
			var node := get_node_or_null(path) as Marker3D
			if is_instance_valid(node) and not cocullo_markers.has(node):
				cocullo_markers.append(node)

	# 2. Fallback: Autodetección de Marker3D si los arrays del Inspector están vacíos
	if main_markers.is_empty() and cocullo_markers.is_empty():
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
				main_markers.append(m)

	# 3. Instanciar luces principales en los marcadores de faros
	for m in main_markers:
		# Haz Principal (Proyector con sombras suaves y penetración a distancia)
		var spot := SpotLight3D.new()
		spot.name = "HazPrincipal_" + m.name
		spot.light_color = color_luz
		spot.light_energy = 0.0
		spot.spot_range = alcance_bajas
		spot.spot_angle = 36.0
		spot.spot_angle_attenuation = 1.15
		spot.shadow_enabled = true
		spot.shadow_blur = 1.8
		spot.shadow_bias = 0.08
		spot.shadow_normal_bias = 1.2
		spot.light_volumetric_fog_energy = 1.25
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 60.0
		spot.distance_fade_length = 25.0
		spot.position = Vector3(0.0, 0.0, -0.04)
		spot.rotation.x = deg_to_rad(-3.2)

		# Haz Ancho de Carretera (Inundación perimetral y asfalto próximo)
		var spot_ancho := SpotLight3D.new()
		spot_ancho.name = "HazCarretera_" + m.name
		spot_ancho.light_color = color_luz.lerp(Color(1.0, 0.94, 0.85), 0.25)
		spot_ancho.light_energy = 0.0
		spot_ancho.spot_range = 18.0
		spot_ancho.spot_angle = 70.0
		spot_ancho.spot_angle_attenuation = 1.35
		spot_ancho.shadow_enabled = false
		spot_ancho.position = Vector3(0.0, -0.04, -0.04)
		spot_ancho.rotation.x = deg_to_rad(-6.5)

		# Resplandor de la Óptica (Ilumina el cuerpo del faro para cámaras y terceros)
		var omni := OmniLight3D.new()
		omni.name = "ResplandorFaro_" + m.name
		omni.light_color = color_luz
		omni.light_energy = 0.0
		omni.omni_range = 1.3
		omni.omni_attenuation = 1.5
		omni.shadow_enabled = false
		omni.position = Vector3(0.0, 0.0, -0.02)

		m.add_child(spot)
		m.add_child(spot_ancho)
		m.add_child(omni)

		_luces_spot.append(spot)
		_luces_ancho.append(spot_ancho)
		_luces_omni.append(omni)

	# 4. Instanciar luces en marcadores de cocullos / cuartos de posición
	for m in cocullo_markers:
		var spot_c := SpotLight3D.new()
		spot_c.name = "LuzCocullo_" + m.name
		spot_c.light_color = color_cocullos
		spot_c.light_energy = 0.0
		spot_c.spot_range = 25.0
		spot_c.spot_angle = 50.0
		spot_c.spot_angle_attenuation = 1.2
		spot_c.shadow_enabled = false
		spot_c.position = Vector3(0.0, 0.0, -0.03)

		var omni_c := OmniLight3D.new()
		omni_c.name = "ResplandorCocullo_" + m.name
		omni_c.light_color = color_cocullos
		omni_c.light_energy = 0.0
		omni_c.omni_range = 1.5
		omni_c.omni_attenuation = 1.4
		omni_c.shadow_enabled = false
		omni_c.position = Vector3(0.0, 0.0, -0.02)

		m.add_child(spot_c)
		m.add_child(omni_c)

		_cocullo_spot.append(spot_c)
		_cocullo_omni.append(omni_c)

func esta_activo() -> bool:
	if conductor_presente:
		return true
	# Comprobar si el vehículo propietario está en estado activo
	var p := get_parent()
	while p:
		if "activo" in p and p.activo:
			return true
		p = p.get_parent()
	return false

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not esta_activo():
		return

	var focus_owner = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := event as InputEventKey
		if k.keycode == tecla_activacion or k.physical_keycode == tecla_activacion:
			alternar_luces()
			get_viewport().set_input_as_handled()

func alternar_luces() -> void:
	modo_luces = (modo_luces + 1) % 3

func encender_luces(modo: int) -> void:
	modo_luces = clampi(modo, 0, 2)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var obj_spot_energy: float = 0.0
	var obj_cocullo_energy: float = 0.0
	var obj_range: float = alcance_bajas
	var obj_pitch: float = -3.2
	var obj_angle: float = 36.0
	
	if esta_activo():
		if modo_luces == 1: # Luces Bajas: inclinadas al asfalto, haz amplio
			obj_spot_energy = energia_bajas
			obj_range = alcance_bajas
			obj_pitch = -3.2
			obj_angle = 36.0
			obj_cocullo_energy = energia_bajas * 0.35
		elif modo_luces == 2: # Luces Altas: haz recto penetrante a larga distancia + cocullos
			obj_spot_energy = energia_altas
			obj_range = alcance_altas
			obj_pitch = -0.5
			obj_angle = 28.0
			obj_cocullo_energy = energia_bajas * 0.50

	# Interpolación suave y orgánica para encendido y cambio de haz
	_energia_actual = lerpf(_energia_actual, obj_spot_energy, delta * 15.0)
	_energia_cocullo_actual = lerpf(_energia_cocullo_actual, obj_cocullo_energy, delta * 15.0)
	_rango_actual = lerpf(_rango_actual, obj_range, delta * 8.0)
	_pitch_actual = lerpf(_pitch_actual, obj_pitch, delta * 8.0)
	_angulo_actual = lerpf(_angulo_actual, obj_angle, delta * 8.0)

	_actualizar_luces(_energia_actual, _energia_cocullo_actual, _rango_actual, deg_to_rad(_pitch_actual), _angulo_actual)

func _actualizar_luces(energia_faros: float, energia_cocullo: float, rango_obj: float, pitch_rad: float, angulo_deg: float) -> void:
	var faros_visibles := (energia_faros > 0.05)
	for s in _luces_spot:
		if is_instance_valid(s):
			s.visible = faros_visibles
			s.light_energy = energia_faros
			s.spot_range = rango_obj
			s.rotation.x = pitch_rad
			s.spot_angle = angulo_deg

	for a in _luces_ancho:
		if is_instance_valid(a):
			a.visible = faros_visibles
			a.light_energy = energia_faros * 0.40

	for o in _luces_omni:
		if is_instance_valid(o):
			o.visible = faros_visibles
			o.light_energy = energia_faros * 0.30

	var cocullos_visibles := (energia_cocullo > 0.05)
	for cs in _cocullo_spot:
		if is_instance_valid(cs):
			cs.visible = cocullos_visibles
			cs.light_energy = energia_cocullo

	for co in _cocullo_omni:
		if is_instance_valid(co):
			co.visible = cocullos_visibles
			co.light_energy = energia_cocullo * 0.35

func set_conductor_presente(presente: bool) -> void:
	conductor_presente = presente
	if not conductor_presente:
		modo_luces = 0
		_energia_actual = 0.0
		_energia_cocullo_actual = 0.0
		_actualizar_luces(0.0, 0.0, alcance_bajas, deg_to_rad(-3.2), 36.0)
