class_name ModoPrueba
extends Node

## ModoPrueba.gd — Modo de prueba de conducción y exploración del mapa en tiempo real
## Instancia la tractomula T800_A y al personaje Jugador en el punto de spawn para probar el mapa creado.

signal prueba_iniciada()
signal prueba_finalizada()

const PATH_T800 := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn"
const PATH_JUGADOR := "res://modelos3d/personajes/Jugador/Jugador.tscn"
const RUTA_FUENTE_MODERNIZ := "res://recursos/fonts/Moderniz.otf"
const TrafficNetworkManager3D = preload("res://sistema_trafico_gps/TrafficNetworkManager3D.gd")
const TrafficLane3D = preload("res://sistema_trafico_gps/TrafficLane3D.gd")
const RoadSegment = preload("res://addons/road-generator/nodes/road_segment.gd")

var en_prueba: bool = false
var _instancia_vehiculo: Node3D = null
var _instancia_jugador: Node3D = null
var _canvas_hud_prueba: CanvasLayer = null
var _nodo_padre_ref: Node3D = null
var _instancia_trafico: TrafficNetworkManager3D = null

func iniciar_prueba(nodo_padre: Node3D, transform_spawn: Transform3D, _modo_spawn: String = "vehiculo") -> void:
	if en_prueba:
		return
	en_prueba = true
	_nodo_padre_ref = nodo_padre

	# 1. Crear HUD flotante de salida y estado (Glassmorphic)
	_crear_hud_prueba()

	# 2. Instanciar la tractomula T800_A en el punto de spawn
	_iniciar_t800(nodo_padre, transform_spawn)

	# 3. Instanciar el personaje Jugador al lado de la T800 (puerta del conductor)
	_iniciar_jugador(nodo_padre, transform_spawn)

	# 4. Generar Red de Tráfico IA y sincronizar con GPS
	var ctrl_carr = nodo_padre.find_child("ControladorCarreteras", true, false)
	if ctrl_carr and "road_container" in ctrl_carr and ctrl_carr.road_container:
		_generar_red_trafico_ia(ctrl_carr.road_container)

	prueba_iniciada.emit()

func finalizar_prueba() -> void:
	if not en_prueba:
		return
	en_prueba = false

	# 1. Si el jugador está dentro de la T800, bajarlo de forma segura
	if is_instance_valid(_instancia_vehiculo):
		if _instancia_vehiculo.get("activo") == true and _instancia_vehiculo.has_method("bajar_jugador"):
			_instancia_vehiculo.bajar_jugador()
		# Detener sonidos del motor
		var motor = _instancia_vehiculo.get("motor")
		if motor and "sonidos_nodo" in motor and is_instance_valid(motor.sonidos_nodo):
			if motor.sonidos_nodo.has_method("detener_todos_los_sonidos"):
				motor.sonidos_nodo.call("detener_todos_los_sonidos")
		_instancia_vehiculo.queue_free()
		_instancia_vehiculo = null

	# 2. Liberar el personaje Jugador
	if is_instance_valid(_instancia_jugador):
		_instancia_jugador.queue_free()
		_instancia_jugador = null

	# 3. Limpiar cualquier capa HUD o interfaz residual creada dinámicamente
	var capas_a_limpiar := ["UIpie", "UIVehiculo", "CelularUI", "InventarioUI"]
	if is_instance_valid(_nodo_padre_ref):
		for child in _nodo_padre_ref.get_children():
			if child.name in capas_a_limpiar:
				child.queue_free()

	if get_tree() and get_tree().current_scene:
		for child in get_tree().current_scene.get_children():
			if child.name in capas_a_limpiar:
				child.queue_free()

	# 4. Limpiar Red de Tráfico IA
	if _instancia_trafico and is_instance_valid(_instancia_trafico):
		_instancia_trafico.queue_free()
		_instancia_trafico = null

	# 5. Eliminar el HUD del modo prueba
	if _canvas_hud_prueba and is_instance_valid(_canvas_hud_prueba):
		_canvas_hud_prueba.queue_free()
		_canvas_hud_prueba = null

	_nodo_padre_ref = null
	prueba_finalizada.emit()

func _iniciar_t800(nodo_padre: Node3D, transform_spawn: Transform3D) -> void:
	if not ResourceLoader.exists(PATH_T800):
		push_error("No se encontró la escena de T800_A en: " + PATH_T800)
		return

	var escena_t800 = load(PATH_T800) as PackedScene
	if not escena_t800:
		return

	_instancia_vehiculo = escena_t800.instantiate() as Node3D
	_instancia_vehiculo.name = "T800_Prueba"
	nodo_padre.add_child(_instancia_vehiculo)

	# Ubicación en el spawn con una ligera elevación para asentamiento de suspensión
	var xf := transform_spawn
	xf.origin.y += 0.45
	_instancia_vehiculo.global_transform = xf

	if _instancia_vehiculo is RigidBody3D:
		var rb := _instancia_vehiculo as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO

func _iniciar_jugador(nodo_padre: Node3D, transform_spawn: Transform3D) -> void:
	if not ResourceLoader.exists(PATH_JUGADOR):
		push_error("No se encontró la escena de Jugador en: " + PATH_JUGADOR)
		return

	var escena_jugador = load(PATH_JUGADOR) as PackedScene
	if not escena_jugador:
		return

	_instancia_jugador = escena_jugador.instantiate() as Node3D
	_instancia_jugador.name = "JugadorPrueba"
	nodo_padre.add_child(_instancia_jugador)

	# Posicionar al lado izquierdo de la cabina (puerta del conductor)
	# En T800_A la ZonaEntrada está en X ~ -1.36, Z ~ -2.53 relativo al origen del camión
	var fwd := -transform_spawn.basis.z.normalized()
	var right := transform_spawn.basis.x.normalized()
	var offset_local := Vector3(-2.6, 0.25, -2.2) # A la izquierda y a la altura de la cabina
	var pos_jugador := transform_spawn.origin + (right * offset_local.x) + (Vector3.UP * offset_local.y) + (fwd * -offset_local.z)

	_instancia_jugador.global_position = pos_jugador
	# Orientar al personaje mirando ligeramente hacia la puerta del camión
	var rot_y: float = transform_spawn.basis.get_euler().y + deg_to_rad(45.0)
	_instancia_jugador.rotation.y = rot_y

	# Notificar al jugador que el camión está cerca para que se active la interacción si lo desea
	if is_instance_valid(_instancia_vehiculo) and _instancia_jugador.has_method("notificar_vehiculo_cerca"):
		_instancia_jugador.notificar_vehiculo_cerca(_instancia_vehiculo)

func _unhandled_input(event: InputEvent) -> void:
	if not en_prueba:
		return
	if event.is_action_pressed("ui_cancel"):
		finalizar_prueba()

# ── INTERFAZ HUD DE PRUEBA (GLASSMORPHIC COCKPIT) ────────────────────

func _crear_hud_prueba() -> void:
	_canvas_hud_prueba = CanvasLayer.new()
	_canvas_hud_prueba.name = "HUD_PruebaConduccion"
	_canvas_hud_prueba.layer = 120 # Por encima de cualquier otra UI
	add_child(_canvas_hud_prueba)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_hud_prueba.add_child(root_ctrl)

	# Botón Flotante "✕ VOLVER AL EDITOR" (Technical Crimson Glassmorphic)
	var btn_volver := Button.new()
	btn_volver.text = "✕ VOLVER AL EDITOR"
	btn_volver.custom_minimum_size = Vector2(280, 72)
	btn_volver.position = Vector2(40, 30)
	_estilar_boton_crimson(btn_volver)
	btn_volver.pressed.connect(finalizar_prueba)
	root_ctrl.add_child(btn_volver)

	# Banner informativo Glassmorphic superior (Centro)
	var panel_info := PanelContainer.new()
	panel_info.custom_minimum_size = Vector2(480, 60)
	panel_info.position = Vector2(956, 30) # Centrado para 2392x1080
	_estilar_panel_glass(panel_info)
	root_ctrl.add_child(panel_info)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_info.add_child(hbox)

	var lbl_info := Label.new()
	lbl_info.text = "🚜 T800 & CONDUCTOR LISTOS"
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_info.add_theme_font_size_override("font_size", 22)
	lbl_info.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95)) # Automotive Amber
	if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
		lbl_info.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))
	hbox.add_child(lbl_info)

func _estilar_boton_crimson(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
		btn.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.78, 0.28, 0.26, 0.95) # Technical Crimson
	sbox.border_color = Color(0.78, 0.81, 0.85, 0.35)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(12)
	sbox.shadow_size = 6
	sbox.shadow_color = Color(0, 0, 0, 0.5)

	btn.add_theme_stylebox_override("normal", sbox)

	var sbox_p := sbox.duplicate() as StyleBoxFlat
	sbox_p.bg_color = Color(0.90, 0.34, 0.32, 0.98)
	btn.add_theme_stylebox_override("pressed", sbox_p)

func _estilar_panel_glass(panel: PanelContainer) -> void:
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.06, 0.07, 0.08, 0.90)
	sbox.border_color = Color(0.78, 0.81, 0.85, 0.25)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(12)
	sbox.shadow_size = 8
	sbox.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", sbox)


func _generar_red_trafico_ia(road_container: Node3D) -> void:
	if not road_container or not _nodo_padre_ref:
		return
		
	var traffic_mgr := TrafficNetworkManager3D.new()
	traffic_mgr.name = "TrafficNetworkManager3D_Prueba"
	traffic_mgr.max_ai_vehicles = 10
	traffic_mgr.spawn_radius = 220.0
	traffic_mgr.despawn_radius = 300.0
	_nodo_padre_ref.add_child(traffic_mgr)
	_instancia_trafico = traffic_mgr
	
	# Recorrer todos los segmentos de carretera
	for child in road_container.get_children():
		var seg = child as RoadSegment
		if not seg or not seg.curve or seg.curve.get_point_count() < 2:
			continue
			
		var lane := TrafficLane3D.new()
		lane.name = "TrafficLane_%s" % seg.name
		lane.curve = seg.curve.duplicate()
		lane.speed_limit = 60.0
		lane.global_transform = seg.global_transform
		traffic_mgr.add_child(lane)
		traffic_mgr.lanes.append(lane)
		traffic_mgr.all_paths.append(lane)
		
	# Conectar carriles continuos
	for lane_a in traffic_mgr.lanes:
		if lane_a.curve.get_point_count() < 2:
			continue
		var fin_a = lane_a.to_global(lane_a.curve.get_point_position(lane_a.curve.get_point_count() - 1))
		for lane_b in traffic_mgr.lanes:
			if lane_a == lane_b or lane_b.curve.get_point_count() < 2:
				continue
			var ini_b = lane_b.to_global(lane_b.curve.get_point_position(0))
			if fin_a.distance_to(ini_b) < 6.0:
				lane_a.next_lanes.append(lane_b)
				
	traffic_mgr.build_network_graph()
	traffic_mgr.call_deferred("_iniciar_pool_trafico")
