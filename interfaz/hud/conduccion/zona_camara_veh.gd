# zona_camara_veh.gd - Zona táctil optimizada para rotar la cámara del vehículo
# Soporta mouse, multitáctil, pinch-to-zoom, inercia suave y exclusión de controles.
extends Control

signal camara_movida(relative_vector: Vector2)
signal camara_pinch(delta_dist: float)

# ─────────────────────────────────────────────────────────────
#  EXPORTADAS Y CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────
@export_group("Sensibilidad y Control")
@export var sensibilidad_rotacion: float = 1.0
@export var sensibilidad_pellizco: float = 1.0
@export var deadzone_tactil: float = 0.3

@export_group("Inercia (Momentum)")
@export var inercia_habilitada: bool = true
@export var friccion_inercia: float = 8.5
@export var max_velocidad_inercia: float = 1500.0

@export_group("Feedback Visual")
@export var feedback_visual_toque: bool = true

# ─────────────────────────────────────────────────────────────
#  ESTADO INTERNO
# ─────────────────────────────────────────────────────────────
var toques_activos: Dictionary = {}
var mouse_presionado: bool = false
var brazo_camara: Node3D = null
var _distancia_pellizco_prev: float = -1.0

var _velocidad_inercia: Vector2 = Vector2.ZERO
var _ultima_velocidad_arrastre: Vector2 = Vector2.ZERO
var _ultimo_tiempo_drag: int = 0

var _controles_vehiculo: Array[String] = [
	"Acelerador", "Freno", "Volante",
	"BotonFrenoMano", "BotonSalir", "BotonCamara", "BotonOcultarHUD",
	"BtnDir_der", "BtnDir_izq", "BtnEmergencia", "BotonCentrar", "Bocina",
	"PanelMarchas", "BtnReversa", "BtnNeutro", "BtnDelante",
	"MotorSwitch", "BtnEncender", "BtnFrenoMotor",
	"BtnLuces", "BtnCrucero", "BtnLimpiabrisas", "BtnDesengancharCabina",
	"BtnDiferencial", "BotonBaul", "BtnToggleGPS", "TabMenu", "BtnCerrarMenu",
	"PanelContenido", "BarraRapidaSuperior", "BarraDireccionalesBg",
	"ConsolaVolante", "FilaFrenosAux", "PanelVelocimetro", "PanelGPSHUD"
]

var _nodos_control_cache: Array[Control] = []
var _celular_ui_cache: Control = null
var _celular_btn_cache: Control = null
var _celular_frame_cache: Control = null

# ─────────────────────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("zona_camara")
	set_process(true)
	await get_tree().process_frame
	_buscar_brazo()
	_precargar_controles()

func get_finger_id() -> int:
	if toques_activos.is_empty():
		return -1
	return toques_activos.keys()[0] as int

func has_finger(index: int) -> bool:
	return toques_activos.has(index)

# ─────────────────────────────────────────────────────────────
#  CONEXIÓN CON VEHÍCULO / CAMERA MANAGER
# ─────────────────────────────────────────────────────────────
func _buscar_brazo() -> void:
	var veh: Node = null
	var p: Node = get_parent()
	while p != null:
		if p is RigidBody3D or p.is_in_group("vehiculo") or p.has_node("CameraManager"):
			veh = p
			break
		p = p.get_parent()

	if not veh and get_tree():
		for v in get_tree().get_nodes_in_group("vehiculo"):
			if v.get("activo") == true:
				veh = v
				break
		if not veh and get_tree().current_scene:
			for child in get_tree().current_scene.get_children():
				if child is RigidBody3D and child.get("activo") == true:
					veh = child
					break

	if veh:
		if veh.has_method("_on_camara_movida"):
			var cb_movida := Callable(veh, "_on_camara_movida")
			if not camara_movida.is_connected(cb_movida):
				camara_movida.connect(cb_movida)

		var cam_mgr: Node = veh.find_child("CameraManager", true, false)
		if cam_mgr:
			if cam_mgr.has_method("_distribuir_entrada_camara"):
				var cb_mgr := Callable(cam_mgr, "_distribuir_entrada_camara")
				if not camara_movida.is_connected(cb_mgr) and not veh.has_method("_on_camara_movida"):
					camara_movida.connect(cb_mgr)
			if cam_mgr.has_method("_distribuir_pinch"):
				var cb_pinch := Callable(cam_mgr, "_distribuir_pinch")
				if not camara_pinch.is_connected(cb_pinch):
					camara_pinch.connect(cb_pinch)
		return
	push_warning("ZonaCamara vehiculo: no se encontró un nodo vehiculo activo")

# ─────────────────────────────────────────────────────────────
#  CACHE DE INTERFACES Y BOTONES EXCLUIDOS
# ─────────────────────────────────────────────────────────────
func _precargar_controles() -> void:
	_nodos_control_cache.clear()
	var raiz: Node = get_parent()
	if not raiz:
		return

	for nombre in _controles_vehiculo:
		var n: Node = raiz.find_child(nombre, true, false)
		if n and n is Control:
			_nodos_control_cache.append(n as Control)

func _obtener_celular_ui() -> Control:
	if is_instance_valid(_celular_ui_cache):
		return _celular_ui_cache
	if get_tree() and get_tree().current_scene:
		var cel = get_tree().current_scene.find_child("CelularUI", true, false)
		if is_instance_valid(cel) and cel is Control:
			_celular_ui_cache = cel as Control
			_celular_btn_cache = _celular_ui_cache.get("open_button") as Control
			_celular_frame_cache = _celular_ui_cache.get("phone_frame") as Control
	return _celular_ui_cache

func _toque_sobre_control_vehiculo(posicion_global: Vector2, _event: InputEvent = null) -> bool:
	# Comprobación de Rect2 directa: cero allocations y orden de magnitud más rápido
	for nodo in _nodos_control_cache:
		if is_instance_valid(nodo) and nodo.visible and nodo.is_visible_in_tree():
			if nodo.get_global_rect().has_point(posicion_global):
				return true

	var cel = _obtener_celular_ui()
	if is_instance_valid(cel):
		if is_instance_valid(_celular_btn_cache) and _celular_btn_cache.visible and _celular_btn_cache.is_visible_in_tree():
			if _celular_btn_cache.get_global_rect().has_point(posicion_global):
				return true
		if is_instance_valid(_celular_frame_cache) and _celular_frame_cache.visible and _celular_frame_cache.is_visible_in_tree() and cel.get("is_open") == true:
			if _celular_frame_cache.get_global_rect().has_point(posicion_global):
				return true

	return false

# ─────────────────────────────────────────────────────────────
#  INERCIA / MOMENTUM DE CÁMARA
# ─────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not inercia_habilitada:
		return

	# Solo aplicar inercia si no hay toques activos ni mouse presionado
	if toques_activos.is_empty() and not mouse_presionado:
		if _velocidad_inercia.length_squared() > 1.0:
			var step: Vector2 = _velocidad_inercia * delta
			emit_signal("camara_movida", step)
			var decay: float = 1.0 - exp(-friccion_inercia * delta)
			_velocidad_inercia = _velocidad_inercia.lerp(Vector2.ZERO, decay)
		else:
			_velocidad_inercia = Vector2.ZERO

func _usar_solo_screen_touch(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false):
		return true
	return false

# ─────────────────────────────────────────────────────────────
#  GESTIÓN DE ENTRADAS (GUI INPUT)
# ─────────────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	# ── MOUSE ────────────────────────────────────────────────
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _usar_solo_screen_touch(event):
				return
			if event.pressed:
				var pos = event.global_position if "global_position" in event else event.position
				if not _toque_sobre_control_vehiculo(pos, event):
					mouse_presionado = true
					_velocidad_inercia = Vector2.ZERO
					_ultima_velocidad_arrastre = Vector2.ZERO
					_ultimo_tiempo_drag = Time.get_ticks_msec()
					_crear_efecto(event.position)
					get_viewport().set_input_as_handled()
			else:
				if mouse_presionado:
					mouse_presionado = false
					if inercia_habilitada and (Time.get_ticks_msec() - _ultimo_tiempo_drag) < 120:
						_velocidad_inercia = _ultima_velocidad_arrastre.clamp(
							Vector2(-max_velocidad_inercia, -max_velocidad_inercia),
							Vector2(max_velocidad_inercia, max_velocidad_inercia)
						)
					else:
						_velocidad_inercia = Vector2.ZERO
					get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var pos = event.global_position if "global_position" in event else event.position
			if not _toque_sobre_control_vehiculo(pos, event):
				emit_signal("camara_pinch", 25.0 * sensibilidad_pellizco)
				get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var pos = event.global_position if "global_position" in event else event.position
			if not _toque_sobre_control_vehiculo(pos, event):
				emit_signal("camara_pinch", -25.0 * sensibilidad_pellizco)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _usar_solo_screen_touch(event):
			return
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			mouse_presionado = false

		if mouse_presionado:
			var rel: Vector2 = event.relative * sensibilidad_rotacion
			if rel.length_squared() > (deadzone_tactil * deadzone_tactil):
				emit_signal("camara_movida", rel)
				var now: int = Time.get_ticks_msec()
				var dt: float = maxf((now - _ultimo_tiempo_drag) / 1000.0, 0.001)
				_ultimo_tiempo_drag = now
				_ultima_velocidad_arrastre = _ultima_velocidad_arrastre.lerp(rel / dt, 0.6)
			get_viewport().set_input_as_handled()

	# ── TÁCTIL (Móvil) ───────────────────────────────────────
	elif event is InputEventScreenTouch:
		if event.pressed:
			var pos = event.global_position if "global_position" in event else event.position
			if not _toque_sobre_control_vehiculo(pos, event):
				toques_activos[event.index] = event.position
				_velocidad_inercia = Vector2.ZERO
				_ultima_velocidad_arrastre = Vector2.ZERO
				_ultimo_tiempo_drag = Time.get_ticks_msec()

				# Feedback visual solo al tocar la pantalla
				_crear_efecto(event.position)

				if toques_activos.size() >= 2:
					var k = toques_activos.keys()
					_distancia_pellizco_prev = (toques_activos[k[0]] as Vector2).distance_to(toques_activos[k[1]] as Vector2)
				get_viewport().set_input_as_handled()
		else:
			if toques_activos.has(event.index):
				toques_activos.erase(event.index)
				if toques_activos.is_empty():
					_distancia_pellizco_prev = -1.0
					if inercia_habilitada and (Time.get_ticks_msec() - _ultimo_tiempo_drag) < 120:
						_velocidad_inercia = _ultima_velocidad_arrastre.clamp(
							Vector2(-max_velocidad_inercia, -max_velocidad_inercia),
							Vector2(max_velocidad_inercia, max_velocidad_inercia)
						)
					else:
						_velocidad_inercia = Vector2.ZERO
				elif toques_activos.size() < 2:
					_distancia_pellizco_prev = -1.0
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if not toques_activos.has(event.index):
			var pos = event.position
			if not _toque_sobre_control_vehiculo(pos, event):
				toques_activos[event.index] = event.position
				_velocidad_inercia = Vector2.ZERO

		if toques_activos.has(event.index):
			toques_activos[event.index] = event.position

			# Si hay exactamente dos dedos, procesar pellizco (zoom)
			if toques_activos.size() == 2:
				var keys = toques_activos.keys()
				var p0: Vector2 = toques_activos[keys[0]] as Vector2
				var p1: Vector2 = toques_activos[keys[1]] as Vector2
				var dist: float = p0.distance_to(p1)
				if _distancia_pellizco_prev > 0.0:
					var delta_dist: float = (dist - _distancia_pellizco_prev) * sensibilidad_pellizco
					emit_signal("camara_pinch", delta_dist)
				_distancia_pellizco_prev = dist
			else:
				# Movimiento con un dedo
				var rel: Vector2 = event.relative * sensibilidad_rotacion
				if rel.length_squared() > (deadzone_tactil * deadzone_tactil):
					emit_signal("camara_movida", rel)
					var now: int = Time.get_ticks_msec()
					var dt: float = maxf((now - _ultimo_tiempo_drag) / 1000.0, 0.001)
					_ultimo_tiempo_drag = now
					_ultima_velocidad_arrastre = _ultima_velocidad_arrastre.lerp(rel / dt, 0.6)
			get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────────────────────
#  FEEDBACK VISUAL LIVIANO Y OPTIMIZADO
# ─────────────────────────────────────────────────────────────
func _crear_efecto(pos_local: Vector2) -> void:
	if not feedback_visual_toque:
		return

	# Mantener como máximo 2 efectos simultáneos en el SceneTree
	var ripple_count: int = 0
	for child in get_children():
		if child is TouchRipple:
			ripple_count += 1
			if ripple_count >= 2:
				child.queue_free()

	var ripple = TouchRipple.new(pos_local)
	add_child(ripple)

# ════════════════════════════════════════════════════════════════════
#  TouchRipple (Efecto sutil de onda táctil optimizado)
# ════════════════════════════════════════════════════════════════════
class TouchRipple extends Node2D:
	var lifetime: float = 0.0
	var max_life: float = 0.32

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
		var radio_ext: float = lerpf(6.0, 32.0, ease_t)
		var alpha_ext: float = lerpf(0.35, 0.0, ease_t)
		draw_arc(Vector2.ZERO, radio_ext, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, alpha_ext), 1.2, true)
		var largo: float = lerpf(4.0, 8.0, ease_t)
		var alpha_cruz: float = lerpf(0.45, 0.0, ease_t)
		draw_line(Vector2(-largo, 0), Vector2(largo, 0), Color(1.0, 1.0, 1.0, alpha_cruz), 0.8)
		draw_line(Vector2(0, -largo), Vector2(0, largo), Color(1.0, 1.0, 1.0, alpha_cruz), 0.8)
		var alpha_dot: float = maxf(lerpf(0.5, 0.0, ease_t) * (1.0 - ease_t * 2.0), 0.0)
		draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, alpha_dot))
