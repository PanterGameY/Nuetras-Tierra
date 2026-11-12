# luces_direccionales_auto.gd - Controlador Exclusivo de Direccionales y Estacionarias Sincronizadas
@tool
extends Node3D

@export_group("Marcadores / Nodos en Inspector")
## Selecciona en el Inspector los nodos/marcadores de la IZQUIERDA (TI, DI)
@export var luces_izquierda: Array[NodePath] = []:
	set(v):
		luces_izquierda = v
		if is_node_ready():
			_crear_luces_por_codigo()

## Selecciona en el Inspector los nodos/marcadores de la DERECHA (TD, DD)
@export var luces_derecha: Array[NodePath] = []:
	set(v):
		luces_derecha = v
		if is_node_ready():
			_crear_luces_por_codigo()

@export_group("Configuración Visual")
## Color del destello (Ámbar / Naranja oficial)
@export var color_direccional: Color = Color(1.0, 0.55, 0.0, 1.0):
	set(v):
		color_direccional = v
		_actualizar_colores()

## Alcance de la iluminación proyectada al suelo/pared (metros)
@export var rango_luz: float = 2.8

## Energía del destello proyectado
@export var energia_destello: float = 8.0

## Frecuencia de parpadeo (Hz)
@export var frecuencia_parpadeo: float = 4.0

## Imprimir mensajes de diagnóstico en la consola/output
@export var activar_debug: bool = false

var _direccional_izq_lights: Array[Light3D] = []
var _direccional_der_lights: Array[Light3D] = []

var _parpadeando_izq: bool = false
var _parpadeando_der: bool = false
var _estacionarias_activas: bool = false

var _blink_timer: float = 0.0
var _energia_dir_izq: float = 0.0
var _energia_dir_der: float = 0.0

var _key_q_was_pressed: bool = false
var _key_e_was_pressed: bool = false
var _key_c_was_pressed: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if luces_izquierda.is_empty() and luces_derecha.is_empty():
		_autodetectar_rutas_inspector()

	_crear_luces_por_codigo()
	_actualizar_luces(0.0, 0.0)

func _autodetectar_rutas_inspector() -> void:
	luces_izquierda.clear()
	luces_derecha.clear()
	
	for child in get_children():
		var n := child.name.to_lower()
		var p := get_path_to(child)
		if n.contains("ti") or n.contains("di") or n.contains("izq") or child.position.x < 0.0:
			luces_izquierda.append(p)
		elif n.contains("td") or n.contains("dd") or n.contains("der") or child.position.x > 0.0:
			luces_derecha.append(p)

func _crear_luces_por_codigo() -> void:
	for li in _direccional_izq_lights:
		if is_instance_valid(li): li.queue_free()
	for ld in _direccional_der_lights:
		if is_instance_valid(ld): ld.queue_free()
		
	_direccional_izq_lights.clear()
	_direccional_der_lights.clear()

	_procesar_lista_rutas(luces_izquierda, _direccional_izq_lights, "IZQUIERDA")
	_procesar_lista_rutas(luces_derecha, _direccional_der_lights, "DERECHA")

func _resolver_nodo(path: NodePath) -> Node:
	var nodo := get_node_or_null(path)
	if is_instance_valid(nodo):
		return nodo
	var nombre_base := str(path).get_file()
	if not nombre_base.is_empty():
		nodo = find_child(nombre_base, true, false)
		if is_instance_valid(nodo):
			return nodo
		if get_parent():
			nodo = get_parent().find_child(nombre_base, true, false)
			if is_instance_valid(nodo):
				return nodo
	return null

func _procesar_lista_rutas(rutas: Array[NodePath], destino_luces: Array[Light3D], etiqueta: String) -> void:
	for path in rutas:
		var nodo := _resolver_nodo(path)
		if not is_instance_valid(nodo):
			if activar_debug:
				print("[LucesDireccionales] WARNING: Ruta no resuelta [", etiqueta, "]: ", path)
			continue

		if nodo is Light3D:
			destino_luces.append(nodo as Light3D)
		elif nodo is Marker3D or nodo is Node3D:
			# Limpiar focos anteriores
			for child in nodo.get_children():
				if child.name.begins_with("LuzDirInst_") or child.name.begins_with("ResplandorDirInst_"):
					child.queue_free()

			# Haz proyectado orientado según la rotación del marcador (ángulo cerrado 50° para evitar sangrado)
			var spot_dir := SpotLight3D.new()
			spot_dir.name = "LuzDirInst_" + nodo.name
			spot_dir.position = Vector3(0.0, 0.0, 0.05)
			spot_dir.light_color = color_direccional
			spot_dir.light_energy = 0.0
			spot_dir.spot_range = rango_luz
			spot_dir.spot_angle = 50.0
			spot_dir.shadow_enabled = false

			# Resplandor envolvente restringido exclusivamente a la tulipa exterior (0.45m máximo)
			var omni_dir := OmniLight3D.new()
			omni_dir.name = "ResplandorDirInst_" + nodo.name
			omni_dir.position = Vector3(0.0, 0.0, 0.05)
			omni_dir.light_color = color_direccional
			omni_dir.light_energy = 0.0
			omni_dir.omni_range = 0.45
			omni_dir.shadow_enabled = false

			nodo.add_child(spot_dir)
			nodo.add_child(omni_dir)

			destino_luces.append(spot_dir)
			destino_luces.append(omni_dir)

func _actualizar_colores() -> void:
	for l in _direccional_izq_lights:
		if is_instance_valid(l): l.light_color = color_direccional
	for l in _direccional_der_lights:
		if is_instance_valid(l): l.light_color = color_direccional

func toggle_direccional_izquierda() -> void:
	_estacionarias_activas = false
	_parpadeando_der = false
	_parpadeando_izq = not _parpadeando_izq
	_blink_timer = 0.0

func toggle_derecha() -> void:
	_estacionarias_activas = false
	_parpadeando_izq = false
	_parpadeando_der = not _parpadeando_der
	_blink_timer = 0.0

func toggle_estacionarias() -> void:
	_parpadeando_izq = false
	_parpadeando_der = false
	_estacionarias_activas = not _estacionarias_activas
	_blink_timer = 0.0

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var q_down := Input.is_physical_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_Q) or Input.is_action_pressed("inclin-izq")
	var e_down := Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E) or Input.is_action_pressed("inclin-der")
	var c_down := Input.is_physical_key_pressed(KEY_C) or Input.is_key_pressed(KEY_C) or Input.is_action_pressed("crouch")

	if q_down and not _key_q_was_pressed:
		toggle_direccional_izquierda()
	_key_q_was_pressed = q_down

	if e_down and not _key_e_was_pressed:
		toggle_derecha()
	_key_e_was_pressed = e_down

	if c_down and not _key_c_was_pressed:
		toggle_estacionarias()
	_key_c_was_pressed = c_down

	if _parpadeando_izq or _parpadeando_der or _estacionarias_activas:
		_blink_timer += delta * frecuencia_parpadeo
		var flash_on := fmod(_blink_timer, 1.0) < 0.5
		
		var izq_on := (flash_on and (_estacionarias_activas or _parpadeando_izq))
		var der_on := (flash_on and (_estacionarias_activas or _parpadeando_der))
		
		_energia_dir_izq = (energia_destello if izq_on else 0.0)
		_energia_dir_der = (energia_destello if der_on else 0.0)
	else:
		_blink_timer = 0.0
		_energia_dir_izq = 0.0
		_energia_dir_der = 0.0

	_actualizar_luces(_energia_dir_izq, _energia_dir_der)

func _actualizar_luces(dir_izq: float, dir_der: float) -> void:
	for l_izq in _direccional_izq_lights:
		if is_instance_valid(l_izq):
			l_izq.visible = (dir_izq > 0.01)
			if l_izq is SpotLight3D: l_izq.light_energy = dir_izq
			elif l_izq is OmniLight3D: l_izq.light_energy = dir_izq * 0.20

	for l_der in _direccional_der_lights:
		if is_instance_valid(l_der):
			l_der.visible = (dir_der > 0.01)
			if l_der is SpotLight3D: l_der.light_energy = dir_der
			elif l_der is OmniLight3D: l_der.light_energy = dir_der * 0.20

func set_conductor_presente(presente: bool) -> void:
	if not presente:
		_parpadeando_izq = false
		_parpadeando_der = false
		_estacionarias_activas = false
		_actualizar_luces(0.0, 0.0)
