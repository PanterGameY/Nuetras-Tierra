# zona_camara_vehiculo.gd - Zona táctil para rotar la cámara del vehículo
# Usa _input() con rastreo multi-dedo y exclusión de controles vehiculares
extends Control

signal camara_movida(relative_vector)
signal camara_pinch(delta_dist)

var toques_activos: Dictionary = {}
var mouse_presionado: bool = false
var brazo_camara: Node3D = null
var _distancia_pellizco_prev: float = -1.0
@export var sensibilidad_pellizco: float = 0.02

var _controles_vehiculo: Array[String] = [
	"Acelerador", "Freno", "Volante",
	"BotonFrenoMano", "BotonSalir", "BotonCamara",
	"BtnDir_der", "BtnDir_izq", "Bocina",
	"PanelMarchas", "BtnReversa", "BtnDelante",
	"MotorSwitch", "BtnEncender",
]

var _nodos_control_cache: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("zona_camara")
	await get_tree().process_frame
	_buscar_brazo()
	_precargar_controles()

func get_finger_id() -> int:
	if toques_activos.is_empty():
		return -1
	return toques_activos.keys()[0] as int

func has_finger(index: int) -> bool:
	return toques_activos.has(index)

func _buscar_brazo() -> void:
	# IMPORTANTE: Buscar el CameraManager primero.
	# Si existe un CameraManager que maneja la entrada centralmente,
	# NO conectar directamente al BrazoCamara para evitar doble rotación.
	var p = get_parent()
	while p != null:
		if p.is_in_group("vehiculo"):
			# Preferir CameraManager como receptor centralizado
			var cam_mgr = p.get_node_or_null("CameraManager")
			if cam_mgr and cam_mgr.has_method("_distribuir_entrada_camara"):
				# El CameraManager manejará todo — no conectar al brazo directamente
				print("ZonaCamara: CameraManager detectado, delegando entrada a él.")
				# Asegurarse que CameraManager no tiene ya la señal conectada aquí
				# (CameraManager se conecta a sí mismo en _conectar_ui)
				brazo_camara = null
				return

			# Fallback: conectar directamente al brazo si no hay CameraManager
			brazo_camara = p.get_node_or_null("BrazoCamara")
			if not brazo_camara:
				brazo_camara = p.get_node_or_null("CameraManager/BrazoCamara")
			break
		p = p.get_parent()

	if brazo_camara:
		if brazo_camara.has_method("_on_camara_movida"):
			var cb_movida := Callable(brazo_camara, "_on_camara_movida")
			if not camara_movida.is_connected(cb_movida):
				camara_movida.connect(cb_movida)
		# Conectar pinch si el brazo expone el handler
		if brazo_camara.has_method("_on_camara_pinch"):
			var cb_pinch := Callable(brazo_camara, "_on_camara_pinch")
			if not camara_pinch.is_connected(cb_pinch):
				camara_pinch.connect(cb_pinch)
		print("ZonaCamara vehiculo conectada a BrazoCamara directamente.")
	else:
		push_warning("ZonaCamara vehiculo: ni CameraManager ni BrazoCamara encontrado")

func _precargar_controles() -> void:
	_nodos_control_cache.clear()
	var raiz = get_parent()
	if not raiz: return
	
	for nombre in _controles_vehiculo:
		var n = raiz.find_child(nombre, true, false)
		if n and n is Control:
			_nodos_control_cache.append(n)

func _toque_sobre_control_vehiculo(posicion: Vector2) -> bool:
	for nodo in _nodos_control_cache:
		if is_instance_valid(nodo) and nodo.visible and nodo.is_visible_in_tree():
			if nodo.get_global_rect().has_point(posicion):
				return true
				
	# Evitar consumir clicks destinados a la interfaz de CelularUI
	var cel = get_tree().current_scene.find_child("CelularUI", true, false)
	if is_instance_valid(cel):
		# Botón para abrir el celular
		var btn = cel.get("open_button") as Control
		if is_instance_valid(btn) and btn.visible and btn.is_visible_in_tree():
			if btn.get_global_rect().has_point(posicion):
				return true
		# Cuerpo/pantalla del celular cuando está abierto
		var frame = cel.get("phone_frame") as Control
		if is_instance_valid(frame) and frame.visible and frame.is_visible_in_tree() and cel.get("is_open"):
			if frame.get_global_rect().has_point(posicion):
				return true
				
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	# --- MOUSE ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if get_global_rect().has_point(event.position) and not _toque_sobre_control_vehiculo(event.position):
					mouse_presionado = true
					get_viewport().set_input_as_handled()
			else:
				mouse_presionado = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if get_global_rect().has_point(event.position) and not _toque_sobre_control_vehiculo(event.position):
				emit_signal("camara_pinch", 5.0)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if get_global_rect().has_point(event.position) and not _toque_sobre_control_vehiculo(event.position):
				emit_signal("camara_pinch", -5.0)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and mouse_presionado:
		emit_signal("camara_movida", event.relative)
		_crear_efecto(event.position - global_position)
		get_viewport().set_input_as_handled()

	# --- TÁCTIL ---

	elif event is InputEventScreenTouch:
		if event.pressed:
			if not toques_activos.has(event.index):
				if get_global_rect().has_point(event.position) and not _toque_sobre_control_vehiculo(event.position):
					toques_activos[event.index] = event.position
					# Si hay dos toques, inicializar referencia de pellizco
					if toques_activos.size() >= 2:
						var k = toques_activos.keys()
						_distancia_pellizco_prev = (toques_activos[k[0]] as Vector2).distance_to(toques_activos[k[1]] as Vector2)
					get_viewport().set_input_as_handled()
		else:
			if toques_activos.has(event.index):
				toques_activos.erase(event.index)
				# Reiniciar referencia de pellizco si hay menos de dos dedos
				if toques_activos.size() < 2:
					_distancia_pellizco_prev = -1.0
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if toques_activos.has(event.index):
			toques_activos[event.index] = event.position
			# Si hay exactamente dos toques, procesar pellizco
			if toques_activos.size() == 2:
				var keys = toques_activos.keys()
				var dist: float = (toques_activos[keys[0]] as Vector2).distance_to(toques_activos[keys[1]] as Vector2)
				if _distancia_pellizco_prev > 0.0:
					var delta_dist: float = dist - _distancia_pellizco_prev
					emit_signal("camara_pinch", delta_dist)
				_distancia_pellizco_prev = dist
			else:
				# Movimiento de cámara por un dedo
				emit_signal("camara_movida", event.relative)
				_crear_efecto(event.position - global_position)
			get_viewport().set_input_as_handled()

func _crear_efecto(pos_local: Vector2) -> void:
	var ripple = TouchRipple.new(pos_local)
	add_child(ripple)

# ════════════════════════════════════════════════════════════════════
#  TouchRipple
# ════════════════════════════════════════════════════════════════════

class TouchRipple extends Node2D:
	var lifetime: float = 0.0
	var max_life: float = 0.45

	func _init(pos: Vector2) -> void:
		position = pos

	func _process(delta: float) -> void:
		lifetime += delta
		if lifetime >= max_life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t: float = lifetime / max_life
		var ease_t: float = 1.0 - pow(1.0 - t, 3)
		var radio_ext: float = lerp(8.0, 38.0, ease_t)
		var alpha_ext: float = lerp(0.35, 0.0, ease_t)
		draw_arc(Vector2.ZERO, radio_ext, 0, TAU, 32,
			Color(1.0, 1.0, 1.0, alpha_ext), 1.2, true)
		var largo: float = lerp(5.0, 10.0, ease_t)
		var alpha_cruz: float = lerp(0.5, 0.0, ease_t)
		draw_line(Vector2(-largo, 0), Vector2(largo, 0), Color(1.0, 1.0, 1.0, alpha_cruz), 0.8)
		draw_line(Vector2(0, -largo), Vector2(0, largo), Color(1.0, 1.0, 1.0, alpha_cruz), 0.8)
		var alpha_dot: float = max(lerp(0.6, 0.0, ease_t) * (1.0 - ease_t * 2.0), 0.0)
		draw_circle(Vector2.ZERO, 2.5, Color(1.0, 1.0, 1.0, alpha_dot))
