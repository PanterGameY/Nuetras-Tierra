class_name ModoPrueba
extends Node

## ModoPrueba.gd — Modo de prueba de conducción y exploración del mapa en tiempo real
## Instancia la tractomula T800_A y al personaje Jugador en el punto de spawn para probar el mapa creado.

signal prueba_iniciada()
signal prueba_finalizada()

const PATH_T800 := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn"
const PATH_JUGADOR := "res://modelos3d/personajes/Jugador/Jugador.tscn"
const RUTA_FUENTE_MODERNIZ := "res://recursos/fonts/Moderniz.otf"
const RUTA_MENU_PERSONALIZACION := "res://interfaz/pantallas/tienda/MenuPersonalizacion.tscn"
const VEHICULOS_GARAJE := [
	{"nombre": "T800 Alargada", "categoria": "TRACTOMULA", "ruta": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn"},
	{"nombre": "Chevrolet Kodiak", "categoria": "CAMIÓN", "ruta": "res://modelos3d/vehiculos/tractomulas/cabezotes/KODIAK/kodiak.tscn"},
	{"nombre": "Chevrolet NPR", "categoria": "CAMIÓN LIGERO", "ruta": "res://modelos3d/vehiculos/NPR/npr.tscn"},
	{"nombre": "Marcopolo G8 1200", "categoria": "BUS", "ruta": "res://modelos3d/vehiculos/Buses/MarcopoloG8-1200/MarcopoloG8-1200.tscn"},
	{"nombre": "Renault Duster", "categoria": "SUV", "ruta": "res://modelos3d/vehiculos/automoviles/Duster/duster.tscn"},
	{"nombre": "Chevrolet Spark", "categoria": "AUTOMÓVIL", "ruta": "res://modelos3d/vehiculos/automoviles/Mespark/mespark.tscn"},
]
const TrafficNetworkManager3D = preload("res://sistema_trafico_gps/TrafficNetworkManager3D.gd")
const TrafficLane3D = preload("res://sistema_trafico_gps/TrafficLane3D.gd")
const RoadSegment = preload("res://addons/road-generator/nodes/road_segment.gd")

var en_prueba: bool = false
var _instancia_vehiculo: Node3D = null
var _instancia_jugador: Node3D = null
var _canvas_hud_prueba: CanvasLayer = null
var _nodo_padre_ref: Node3D = null
var _instancia_trafico: TrafficNetworkManager3D = null
var _lbl_info_banner: Label = null
var _hbox_botones_taller: HBoxContainer = null
var _btn_abrir_garaje: Button = null
var _btn_personalizar_taller: Button = null
var _panel_garaje_modal: PanelContainer = null
var _menu_personalizacion_inst: Control = null
var _taller_bridge: _TallerPruebaBridge = null
var _en_personalizacion: bool = false
var _cam_previa_taller: Camera3D = null
var _huds_ocultos_taller: Array[CanvasLayer] = []
var _garaje_activo: Node3D = null
var _mouse_mode_previo: int = Input.MOUSE_MODE_VISIBLE

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

	# 3b. Vincular colisión dinámica de Terrain3D al jugador en prueba
	_configurar_colision_terreno(nodo_padre, _instancia_jugador)

	# 4. Generar Red de Tráfico IA y sincronizar con GPS
	var ctrl_carr = nodo_padre.find_child("ControladorCarreteras", true, false)
	if ctrl_carr and "road_container" in ctrl_carr and ctrl_carr.road_container:
		_generar_red_trafico_ia(ctrl_carr.road_container)

	prueba_iniciada.emit()

func finalizar_prueba() -> void:
	if not en_prueba:
		return
	if _en_personalizacion:
		_cerrar_taller_personalizacion()
	en_prueba = false
	if is_instance_valid(_nodo_padre_ref):
		var ctrl_terr = _nodo_padre_ref.find_child("ControladorTerreno", true, false)
		if ctrl_terr and "bloqueado_en_prueba" in ctrl_terr:
			ctrl_terr.bloqueado_en_prueba = false

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

	if is_instance_valid(_nodo_padre_ref):
		_configurar_colision_terreno(_nodo_padre_ref, null)

	# 5. Eliminar el HUD del modo prueba y puente de personalización
	if is_instance_valid(_menu_personalizacion_inst):
		_menu_personalizacion_inst.queue_free()
		_menu_personalizacion_inst = null
	if is_instance_valid(_taller_bridge):
		_taller_bridge.queue_free()
		_taller_bridge = null
	if _canvas_hud_prueba and is_instance_valid(_canvas_hud_prueba):
		_canvas_hud_prueba.queue_free()
		_canvas_hud_prueba = null
	_lbl_info_banner = null
	_hbox_botones_taller = null
	_btn_abrir_garaje = null
	_btn_personalizar_taller = null
	_panel_garaje_modal = null
	_garaje_activo = null
	_en_personalizacion = false
	_cam_previa_taller = null
	_huds_ocultos_taller.clear()

	_nodo_padre_ref = null
	prueba_finalizada.emit()

const CATALOGO_VEHICULOS_MAPA := {
	"T800_A": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T800_Alargada": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T800": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"800_Modular": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T680": "res://modelos3d/vehiculos/tractomulas/cabezotes/T680/T680.tscn",
	"Kodiak": "res://modelos3d/vehiculos/tractomulas/cabezotes/KODIAK/kodiak.tscn",
	"NPR": "res://modelos3d/vehiculos/NPR/npr.tscn",
	"Marcopolo": "res://modelos3d/vehiculos/Buses/MarcopoloG8-1200/MarcopoloG8-1200.tscn",
	"Duster": "res://modelos3d/vehiculos/automoviles/Duster/duster.tscn",
	"Mespark": "res://modelos3d/vehiculos/automoviles/Mespark/mespark.tscn",
	"ToyotaHiace": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Hiage": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Pardo": "res://modelos3d/vehiculos/automoviles/Pardo/pardo.tscn",
	"Sprinter": "res://modelos3d/vehiculos/automoviles/sprinter/sprinter_repartidor.tscn"
}

func _obtener_vehiculo_seleccionado() -> Dictionary:
	var id_veh := "T800_A"
	var du := get_node_or_null("/root/DatosUsuario")
	if du:
		if "guardado_player_vehiculo_nombre" in du and str(du.guardado_player_vehiculo_nombre) != "":
			id_veh = str(du.guardado_player_vehiculo_nombre)
		elif "vehiculo_actual" in du and str(du.vehiculo_actual) != "":
			id_veh = str(du.vehiculo_actual)
	if not CATALOGO_VEHICULOS_MAPA.has(id_veh):
		for k in CATALOGO_VEHICULOS_MAPA.keys():
			if k.to_lower() in id_veh.to_lower() or id_veh.to_lower() in k.to_lower():
				id_veh = k
				break
		if not CATALOGO_VEHICULOS_MAPA.has(id_veh):
			id_veh = "T800_A"
	return {"id": id_veh, "ruta": CATALOGO_VEHICULOS_MAPA.get(id_veh, PATH_T800)}

func _iniciar_t800(nodo_padre: Node3D, transform_spawn: Transform3D) -> void:
	var sel := _obtener_vehiculo_seleccionado()
	var id_veh: String = sel["id"]
	var ruta_veh: String = sel["ruta"]
	if not ResourceLoader.exists(ruta_veh):
		ruta_veh = PATH_T800
	if not ResourceLoader.exists(ruta_veh):
		push_error("No se encontró la escena de vehículo en: " + ruta_veh)
		return

	var escena_veh = load(ruta_veh) as PackedScene
	if not escena_veh:
		return

	_instancia_vehiculo = escena_veh.instantiate() as Node3D
	_instancia_vehiculo.name = id_veh + "_Prueba"
	_instancia_vehiculo.set_meta("modelo_id", id_veh)
	nodo_padre.add_child(_instancia_vehiculo)

	var cust: Node = _instancia_vehiculo.get_node_or_null("CustomizerComponent")
	if not cust:
		cust = _instancia_vehiculo.find_child("CustomizerComponent", true, false)
	if not cust:
		var cust_script := load("res://codigo/sistemas/taller/customizer_component.gd")
		if cust_script:
			cust = Node.new()
			cust.set_script(cust_script)
			cust.name = "CustomizerComponent"
			_instancia_vehiculo.add_child(cust)
	if cust and cust.has_method("cargar_personalizacion"):
		cust.cargar_personalizacion()

	# Ubicación en el spawn ajustada a la altura real de terreno/carretera
	var xf := transform_spawn
	xf.origin.y = _obtener_altura_suelo_segura(nodo_padre, xf.origin) + 0.45
	_instancia_vehiculo.global_transform = xf

	if _instancia_vehiculo is RigidBody3D:
		var rb := _instancia_vehiculo as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		# Congelar brevemente mientras Terrain3D genera su colisión dinámica en el primer tick
		rb.freeze = true
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(rb):
				rb.freeze = false
		)

func _iniciar_jugador(nodo_padre: Node3D, transform_spawn: Transform3D) -> void:
	if not ResourceLoader.exists(PATH_JUGADOR):
		push_error("No se encontró la escena de Jugador en: " + PATH_JUGADOR)
		return

	var escena_jugador = load(PATH_JUGADOR) as PackedScene
	if not escena_jugador:
		return

	_instancia_jugador = escena_jugador.instantiate() as Node3D
	_instancia_jugador.name = "JugadorPrueba"
	_instancia_jugador.set_meta("en_modo_prueba", true)
	nodo_padre.add_child(_instancia_jugador)

	# Posicionar al lado izquierdo de la cabina (puerta del conductor)
	# En T800_A la ZonaEntrada está en X ~ -1.36, Z ~ -2.53 relativo al origen del camión
	var fwd := -transform_spawn.basis.z.normalized()
	var right := transform_spawn.basis.x.normalized()
	var offset_local := Vector3(-2.6, 0.25, -2.2) # A la izquierda y a la altura de la cabina
	var pos_jugador := transform_spawn.origin + (right * offset_local.x) + (fwd * -offset_local.z)
	pos_jugador.y = _obtener_altura_suelo_segura(nodo_padre, Vector3(pos_jugador.x, transform_spawn.origin.y, pos_jugador.z)) + 0.25

	_instancia_jugador.global_position = pos_jugador
	# Orientar al personaje mirando ligeramente hacia la puerta del camión
	var rot_y: float = transform_spawn.basis.get_euler().y + deg_to_rad(45.0)
	_instancia_jugador.rotation.y = rot_y

	# Notificar al jugador que el camión está cerca para que se active la interacción si lo desea
	if is_instance_valid(_instancia_vehiculo) and _instancia_jugador.has_method("notificar_vehiculo_cerca"):
		_instancia_jugador.notificar_vehiculo_cerca(_instancia_vehiculo)

func _configurar_colision_terreno(nodo_padre: Node3D, objetivo: Node3D) -> void:
	if not is_instance_valid(nodo_padre):
		return
	var ctrl_terr = nodo_padre.find_child("ControladorTerreno", true, false)
	if ctrl_terr:
		if "bloqueado_en_prueba" in ctrl_terr:
			ctrl_terr.bloqueado_en_prueba = (objetivo != null)
		if "terrain" in ctrl_terr and is_instance_valid(ctrl_terr.terrain):
			var t = ctrl_terr.terrain
			if objetivo != null:
				t.collision_mode = 1
				t.collision_radius = 96
				t.collision_target = objetivo
				var cam_activa := nodo_padre.get_viewport().get_camera_3d() if nodo_padre.get_viewport() else null
				if is_instance_valid(cam_activa):
					t.set_camera(cam_activa)
					t.set_clipmap_target(cam_activa)
			else:
				t.collision_target = null
				t.set_clipmap_target(null)

func _obtener_altura_suelo_segura(nodo_padre: Node3D, pos: Vector3) -> float:
	var mejor_y: float = pos.y
	var encontro: bool = false

	# 1. Consultar altura directa de Terrain3DData (funciona incluso antes de construir colisión dinámica)
	var ctrl_terr = nodo_padre.find_child("ControladorTerreno", true, false)
	if ctrl_terr and "terrain" in ctrl_terr and is_instance_valid(ctrl_terr.terrain) and ctrl_terr.terrain.data:
		var h_terr: float = ctrl_terr.terrain.data.get_height(pos)
		if not is_nan(h_terr) and not is_inf(h_terr):
			mejor_y = h_terr
			encontro = true

	# 2. Raycast físico hacia abajo (detecta carreteras, puentes, rotondas y edificios)
	var space: PhysicsDirectSpaceState3D = nodo_padre.get_world_3d().direct_space_state if nodo_padre.get_world_3d() else null
	if space:
		var orig := Vector3(pos.x, pos.y + 80.0, pos.z)
		var dest := Vector3(pos.x, pos.y - 80.0, pos.z)
		var q := PhysicsRayQueryParameters3D.create(orig, dest)
		var res := space.intersect_ray(q)
		if not res.is_empty():
			var ray_y: float = res["position"].y
			if not encontro or ray_y > mejor_y:
				mejor_y = ray_y
				encontro = true

	return mejor_y

func _physics_process(_delta: float) -> void:
	if not en_prueba or not is_instance_valid(_nodo_padre_ref):
		return
	# Mantener el clipmap LOD y la colisión de Terrain3D centrados en la cámara y objetivo activos
	var ctrl_terr = _nodo_padre_ref.find_child("ControladorTerreno", true, false)
	if ctrl_terr and "terrain" in ctrl_terr and is_instance_valid(ctrl_terr.terrain):
		var t = ctrl_terr.terrain
		var cam_activa := get_viewport().get_camera_3d() if get_viewport() else null
		if is_instance_valid(cam_activa):
			var dist_render: float = 600.0
			if "_distancia_renderizado" in _nodo_padre_ref:
				dist_render = float(_nodo_padre_ref.get("_distancia_renderizado"))
			if not is_equal_approx(cam_activa.far, dist_render):
				cam_activa.far = dist_render
			if t.get_camera() != cam_activa:
				t.set_camera(cam_activa)
			if t.get_clipmap_target() != cam_activa:
				t.set_clipmap_target(cam_activa)
		var conduciendo: bool = is_instance_valid(_instancia_jugador) and bool(_instancia_jugador.get("_conduciendo"))
		if conduciendo and is_instance_valid(_instancia_vehiculo):
			if t.collision_target != _instancia_vehiculo:
				t.collision_target = _instancia_vehiculo
		elif not conduciendo and is_instance_valid(_instancia_jugador):
			if t.collision_target != _instancia_jugador:
				t.collision_target = _instancia_jugador
	# Red de seguridad anti-caída al vacío si Terrain3D tarda 1-2 frames en construir colisión dinámica (solo consulta terreno, no techos)
	if is_instance_valid(_instancia_jugador) and not _instancia_jugador.get("_conduciendo"):
		if ctrl_terr and "terrain" in ctrl_terr and is_instance_valid(ctrl_terr.terrain) and ctrl_terr.terrain.data:
			var h_terr: float = ctrl_terr.terrain.data.get_height(_instancia_jugador.global_position)
			if not is_nan(h_terr) and not is_inf(h_terr) and _instancia_jugador.global_position.y < h_terr - 2.5:
				_instancia_jugador.global_position.y = h_terr + 0.35
				if _instancia_jugador is CharacterBody3D:
					(_instancia_jugador as CharacterBody3D).velocity.y = 0.0

	_actualizar_deteccion_garaje()

func _unhandled_input(event: InputEvent) -> void:
	if not en_prueba:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if _en_personalizacion:
			return
		if is_instance_valid(_panel_garaje_modal) and _panel_garaje_modal.visible:
			_cerrar_modal_garaje()
			get_viewport().set_input_as_handled()
			return
		elif is_instance_valid(_garaje_activo):
			_abrir_modal_garaje()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		if _en_personalizacion:
			_cerrar_taller_personalizacion()
			get_viewport().set_input_as_handled()
			return
		elif is_instance_valid(_garaje_activo) and is_instance_valid(_instancia_vehiculo) and (not is_instance_valid(_panel_garaje_modal) or not _panel_garaje_modal.visible):
			_abrir_taller_personalizacion()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		if _en_personalizacion:
			_cerrar_taller_personalizacion()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(_panel_garaje_modal) and _panel_garaje_modal.visible:
			_cerrar_modal_garaje()
			get_viewport().set_input_as_handled()
			return
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

	# Barra superior centrada (evita tapar el velocímetro arriba-izquierda y controles arriba-derecha)
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 14)
	top_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_bar.offset_left = -410.0
	top_bar.offset_right = 410.0
	top_bar.offset_top = 18.0
	top_bar.offset_bottom = 82.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(top_bar)

	# Banner informativo Glassmorphic
	var panel_info := PanelContainer.new()
	panel_info.custom_minimum_size = Vector2(440, 60)
	_estilar_panel_glass(panel_info)
	top_bar.add_child(panel_info)

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
	_lbl_info_banner = lbl_info

	# Botón "✕ VOLVER AL EDITOR" (Technical Crimson Glassmorphic)
	var btn_volver := Button.new()
	btn_volver.text = "✕ VOLVER AL EDITOR"
	btn_volver.custom_minimum_size = Vector2(260, 60)
	_estilar_boton_crimson(btn_volver)
	btn_volver.pressed.connect(finalizar_prueba)
	top_bar.add_child(btn_volver)

	# Contenedor flotante de botones del Taller (aparece al acercarse a un garaje)
	_hbox_botones_taller = HBoxContainer.new()
	_hbox_botones_taller.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox_botones_taller.add_theme_constant_override("separation", 18)
	_hbox_botones_taller.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hbox_botones_taller.offset_left = -360.0
	_hbox_botones_taller.offset_right = 360.0
	_hbox_botones_taller.offset_top = -140.0
	_hbox_botones_taller.offset_bottom = -64.0
	_hbox_botones_taller.visible = false
	_hbox_botones_taller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_hbox_botones_taller)

	_btn_abrir_garaje = Button.new()
	_btn_abrir_garaje.text = "🚛 ABRIR GARAJE (G)"
	_btn_abrir_garaje.custom_minimum_size = Vector2(320, 74)
	_estilar_boton_amber(_btn_abrir_garaje)
	_btn_abrir_garaje.pressed.connect(_abrir_modal_garaje)
	_hbox_botones_taller.add_child(_btn_abrir_garaje)

	_btn_personalizar_taller = Button.new()
	_btn_personalizar_taller.text = "🎨 PERSONALIZAR (P)"
	_btn_personalizar_taller.custom_minimum_size = Vector2(320, 74)
	_estilar_boton_glass_amber(_btn_personalizar_taller)
	_btn_personalizar_taller.pressed.connect(_abrir_taller_personalizacion)
	_hbox_botones_taller.add_child(_btn_personalizar_taller)

	_construir_modal_garaje(root_ctrl)

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

func _estilar_boton_glass_amber(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.98))
	if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
		btn.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.08, 0.09, 0.11, 0.86)
	sbox.border_color = Color(0.88, 0.68, 0.28, 0.55)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(12)
	sbox.shadow_size = 6
	sbox.shadow_color = Color(0, 0, 0, 0.5)
	btn.add_theme_stylebox_override("normal", sbox)

	var sbox_h := sbox.duplicate() as StyleBoxFlat
	sbox_h.bg_color = Color(0.14, 0.16, 0.20, 0.92)
	sbox_h.border_color = Color(0.88, 0.68, 0.28, 0.90)
	btn.add_theme_stylebox_override("hover", sbox_h)

	var sbox_p := sbox.duplicate() as StyleBoxFlat
	sbox_p.bg_color = Color(0.88, 0.68, 0.28, 0.92)
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

# ── SISTEMA DE GARAJE Y SELECTOR DE VEHÍCULOS ──────────────────────────

func _estilar_boton_amber(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 0.98))
	if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
		btn.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.88, 0.68, 0.28, 0.92) # Automotive Instrument Amber
	sbox.border_color = Color(0.98, 0.85, 0.50, 0.70)
	sbox.set_border_width_all(1)
	sbox.set_corner_radius_all(10)
	sbox.shadow_size = 5
	sbox.shadow_color = Color(0, 0, 0, 0.45)
	btn.add_theme_stylebox_override("normal", sbox)

	var sbox_h := sbox.duplicate() as StyleBoxFlat
	sbox_h.bg_color = Color(0.95, 0.75, 0.35, 0.98)
	btn.add_theme_stylebox_override("hover", sbox_h)

	var sbox_p := sbox.duplicate() as StyleBoxFlat
	sbox_p.bg_color = Color(0.75, 0.56, 0.20, 0.98)
	btn.add_theme_stylebox_override("pressed", sbox_p)

func _construir_modal_garaje(root_ctrl: Control) -> void:
	_panel_garaje_modal = PanelContainer.new()
	_panel_garaje_modal.name = "ModalGarajeVehiculos"
	_panel_garaje_modal.custom_minimum_size = Vector2(1100, 680)
	_panel_garaje_modal.set_anchors_preset(Control.PRESET_CENTER)
	_panel_garaje_modal.offset_left = -550.0
	_panel_garaje_modal.offset_right = 550.0
	_panel_garaje_modal.offset_top = -340.0
	_panel_garaje_modal.offset_bottom = 340.0
	_panel_garaje_modal.pivot_offset = Vector2(550.0, 340.0)
	_panel_garaje_modal.visible = false
	_panel_garaje_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var sbox_modal := StyleBoxFlat.new()
	sbox_modal.bg_color = Color(0.06, 0.07, 0.08, 0.94)
	sbox_modal.border_color = Color(0.78, 0.81, 0.85, 0.25)
	sbox_modal.set_border_width_all(1)
	sbox_modal.set_corner_radius_all(12)
	sbox_modal.shadow_size = 10
	sbox_modal.shadow_color = Color(0, 0, 0, 0.65)
	sbox_modal.content_margin_left = 28
	sbox_modal.content_margin_right = 28
	sbox_modal.content_margin_top = 24
	sbox_modal.content_margin_bottom = 24
	_panel_garaje_modal.add_theme_stylebox_override("panel", sbox_modal)
	root_ctrl.add_child(_panel_garaje_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_panel_garaje_modal.add_child(vbox)

	# Cabecera
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "🚛 GARAJE DE VEHÍCULOS"
	lbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_titulo.add_theme_font_size_override("font_size", 36)
	lbl_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
	if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
		lbl_titulo.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))
	header.add_child(lbl_titulo)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕ CERRAR"
	btn_cerrar.custom_minimum_size = Vector2(180, 56)
	_estilar_boton_crimson(btn_cerrar)
	btn_cerrar.pressed.connect(_cerrar_modal_garaje)
	header.add_child(btn_cerrar)

	var lbl_sub := Label.new()
	lbl_sub.text = "Selecciona un vehículo para sacarlo del garaje y probarlo en tu mapa:"
	lbl_sub.add_theme_font_size_override("font_size", 22)
	lbl_sub.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.85))
	if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
		lbl_sub.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))
	vbox.add_child(lbl_sub)

	# Lista desplazable de tarjetas
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 12)
	scroll.add_child(lista)

	for veh in VEHICULOS_GARAJE:
		var ruta: String = veh["ruta"]
		if not ResourceLoader.exists(ruta):
			continue
		var card := PanelContainer.new()
		var sbox_card := StyleBoxFlat.new()
		sbox_card.bg_color = Color(0.09, 0.10, 0.12, 0.90)
		sbox_card.border_color = Color(0.78, 0.81, 0.85, 0.22)
		sbox_card.set_border_width_all(1)
		sbox_card.set_corner_radius_all(10)
		sbox_card.content_margin_left = 20
		sbox_card.content_margin_right = 20
		sbox_card.content_margin_top = 14
		sbox_card.content_margin_bottom = 14
		card.add_theme_stylebox_override("panel", sbox_card)
		lista.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)

		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 4)
		row.add_child(info_col)

		var lbl_cat := Label.new()
		lbl_cat.text = veh["categoria"]
		lbl_cat.add_theme_font_size_override("font_size", 16)
		lbl_cat.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.90))
		if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
			lbl_cat.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))
		info_col.add_child(lbl_cat)

		var lbl_nom := Label.new()
		lbl_nom.text = veh["nombre"]
		lbl_nom.add_theme_font_size_override("font_size", 26)
		lbl_nom.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ):
			lbl_nom.add_theme_font_override("font", load(RUTA_FUENTE_MODERNIZ))
		info_col.add_child(lbl_nom)

		var btn_sacar := Button.new()
		btn_sacar.text = "SACAR VEHÍCULO"
		btn_sacar.custom_minimum_size = Vector2(260, 56)
		_estilar_boton_amber(btn_sacar)
		btn_sacar.pressed.connect(_sacar_vehiculo_de_garaje.bind(veh["nombre"], ruta))
		row.add_child(btn_sacar)

func _actualizar_deteccion_garaje() -> void:
	if not is_instance_valid(_hbox_botones_taller) or not get_tree():
		return
	var ref_pos := Vector3.ZERO
	var tiene_ref := false
	if is_instance_valid(_instancia_jugador) and not _instancia_jugador.get("_conduciendo"):
		ref_pos = _instancia_jugador.global_position
		tiene_ref = true
	elif is_instance_valid(_instancia_vehiculo):
		ref_pos = _instancia_vehiculo.global_position
		tiene_ref = true

	var nuevo_garaje: Node3D = null
	if tiene_ref:
		var mejor_dist := 3.8
		for nodo in get_tree().get_nodes_in_group("zona_garaje_prueba"):
			var zona := nodo as Area3D
			if not is_instance_valid(zona):
				continue
			var dentro := false
			if is_instance_valid(_instancia_jugador) and zona.overlaps_body(_instancia_jugador):
				dentro = true
			elif is_instance_valid(_instancia_vehiculo) and zona.overlaps_body(_instancia_vehiculo):
				dentro = true
			var d := ref_pos.distance_to(zona.global_position)
			if dentro or d < mejor_dist:
				mejor_dist = d
				nuevo_garaje = zona.get_parent() as Node3D

	_garaje_activo = nuevo_garaje
	var modal_abierto := is_instance_valid(_panel_garaje_modal) and _panel_garaje_modal.visible
	var mostrar_btns := is_instance_valid(_garaje_activo) and not modal_abierto and not _en_personalizacion
	if _hbox_botones_taller.visible != mostrar_btns:
		_hbox_botones_taller.visible = mostrar_btns
	if is_instance_valid(_btn_personalizar_taller):
		_btn_personalizar_taller.visible = is_instance_valid(_instancia_vehiculo)

func _abrir_modal_garaje() -> void:
	if not is_instance_valid(_panel_garaje_modal) or not is_instance_valid(_garaje_activo) or _en_personalizacion:
		return
	_mouse_mode_previo = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_hbox_botones_taller):
		_hbox_botones_taller.visible = false
	_panel_garaje_modal.visible = true
	_panel_garaje_modal.scale = Vector2(0.92, 0.92)
	_panel_garaje_modal.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel_garaje_modal, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel_garaje_modal, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _cerrar_modal_garaje() -> void:
	if not is_instance_valid(_panel_garaje_modal) or not _panel_garaje_modal.visible:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel_garaje_modal, "scale", Vector2(0.94, 0.94), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel_garaje_modal, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if is_instance_valid(_panel_garaje_modal):
			_panel_garaje_modal.visible = false
		Input.mouse_mode = _mouse_mode_previo
	)

func _sacar_vehiculo_de_garaje(nombre_vehiculo: String, ruta_escena: String) -> void:
	_cerrar_modal_garaje()
	if not is_instance_valid(_nodo_padre_ref) or not is_instance_valid(_garaje_activo):
		return
	if not ResourceLoader.exists(ruta_escena):
		push_error("No se encontró la escena del vehículo: " + ruta_escena)
		return

	var punto_spawn := _garaje_activo.get_node_or_null("PuntoSpawnGaraje") as Marker3D
	var xf_spawn := punto_spawn.global_transform if is_instance_valid(punto_spawn) else _garaje_activo.global_transform

	# 1. Bajar al jugador si estaba conduciendo y liberar el vehículo anterior
	if is_instance_valid(_instancia_vehiculo):
		if _instancia_vehiculo.get("activo") == true and _instancia_vehiculo.has_method("bajar_jugador"):
			_instancia_vehiculo.bajar_jugador()
		var motor = _instancia_vehiculo.get("motor")
		if motor and "sonidos_nodo" in motor and is_instance_valid(motor.sonidos_nodo):
			if motor.sonidos_nodo.has_method("detener_todos_los_sonidos"):
				motor.sonidos_nodo.call("detener_todos_los_sonidos")
		_instancia_vehiculo.queue_free()
		_instancia_vehiculo = null

	# 2. Instanciar el vehículo seleccionado en el punto de spawn del garaje
	var escena_veh := load(ruta_escena) as PackedScene
	if not escena_veh:
		return
	var nuevo_veh := escena_veh.instantiate() as Node3D
	if not nuevo_veh:
		return
	nuevo_veh.name = "VehiculoGaraje_%s" % nombre_vehiculo.replace(" ", "_")
	_nodo_padre_ref.add_child(nuevo_veh)

	# Usar la altura exacta de PuntoSpawnGaraje (interior) sin raycast desde el cielo (que golpearía el techo)
	xf_spawn.origin.y += 0.35
	nuevo_veh.global_transform = xf_spawn

	if nuevo_veh is RigidBody3D:
		var rb := nuevo_veh as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.freeze = true
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(rb):
				rb.freeze = false
		)

	_instancia_vehiculo = nuevo_veh

	# 3. Reubicar al jugador junto a la puerta del conductor dentro de la bahía y activar icono de subida
	if is_instance_valid(_instancia_jugador):
		var zona_ent := nuevo_veh.find_child("ZonaEntrada", true, false) as Area3D
		var pos_lado: Vector3 = xf_spawn.origin - xf_spawn.basis.x * 2.6
		if is_instance_valid(zona_ent):
			var pz := zona_ent.global_position
			pos_lado = Vector3(pz.x, xf_spawn.origin.y - 0.15, pz.z) - xf_spawn.basis.x * 0.65
		else:
			pos_lado.y = xf_spawn.origin.y - 0.15
		_instancia_jugador.global_position = pos_lado
		if _instancia_jugador.has_method("notificar_vehiculo_cerca"):
			_instancia_jugador.notificar_vehiculo_cerca(_instancia_vehiculo)
		var icono_ent := nuevo_veh.find_child("IconoEntradaVehiculo", true, false)
		if is_instance_valid(icono_ent) and icono_ent.has_method("mostrar"):
			icono_ent.call_deferred("mostrar", _instancia_jugador)

	if is_instance_valid(_lbl_info_banner):
		_lbl_info_banner.text = "🚛 %s LISTO" % nombre_vehiculo.to_upper()

# ── TALLER DE PERSONALIZACIÓN EN TIEMPO REAL ─────────────────────────

func _obtener_o_crear_customizer(vehiculo: Node3D) -> Node:
	if not is_instance_valid(vehiculo):
		return null
	var comp := vehiculo.get_node_or_null("CustomizerComponent")
	if not comp:
		comp = vehiculo.find_child("CustomizerComponent", true, false)
	if not comp:
		var script_comp := load("res://codigo/sistemas/taller/customizer_component.gd")
		if script_comp:
			comp = Node.new()
			comp.set_script(script_comp)
			comp.name = "CustomizerComponent"
			vehiculo.add_child(comp)
			if comp.has_method("detectar_materiales_personalizables"):
				comp.detectar_materiales_personalizables()
			if comp.has_method("detectar_meshes_personalizables"):
				comp.detectar_meshes_personalizables()
	return comp

func _abrir_taller_personalizacion() -> void:
	if _en_personalizacion or not is_instance_valid(_instancia_vehiculo) or not is_instance_valid(_canvas_hud_prueba):
		return
	if not ResourceLoader.exists(RUTA_MENU_PERSONALIZACION):
		push_error("No se encontró MenuPersonalizacion.tscn en: " + RUTA_MENU_PERSONALIZACION)
		return

	_en_personalizacion = true
	_mouse_mode_previo = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if is_instance_valid(_hbox_botones_taller):
		_hbox_botones_taller.visible = false
	if is_instance_valid(_panel_garaje_modal) and _panel_garaje_modal.visible:
		_panel_garaje_modal.visible = false

	# Ocultar temporalmente otros HUDs activos (UIpie / UIVehiculo / CelularUI)
	_huds_ocultos_taller.clear()
	for hud_name in ["UIpie", "UIVehiculo", "CelularUI"]:
		var h := _nodo_padre_ref.find_child(hud_name, true, false) if is_instance_valid(_nodo_padre_ref) else null
		if not h and get_tree() and get_tree().current_scene:
			h = get_tree().current_scene.find_child(hud_name, true, false)
		if h is CanvasLayer and h.visible:
			h.visible = false
			_huds_ocultos_taller.append(h)

	var customizer := _obtener_o_crear_customizer(_instancia_vehiculo)

	# Crear puente de cámara orbital y selección de piezas
	if not is_instance_valid(_taller_bridge):
		_taller_bridge = _TallerPruebaBridge.new()
		_taller_bridge.name = "TallerPruebaBridge"
		add_child(_taller_bridge)
	_taller_bridge.configurar(self, _instancia_vehiculo, customizer)

	_cam_previa_taller = get_viewport().get_camera_3d() if get_viewport() else null
	_taller_bridge.activar_camara()

	# Instanciar o reutilizar MenuPersonalizacion
	if not is_instance_valid(_menu_personalizacion_inst):
		var escena_menu := load(RUTA_MENU_PERSONALIZACION) as PackedScene
		if escena_menu:
			_menu_personalizacion_inst = escena_menu.instantiate() as Control
			_menu_personalizacion_inst.mouse_filter = Control.MOUSE_FILTER_PASS
			_canvas_hud_prueba.add_child(_menu_personalizacion_inst)

	if is_instance_valid(_menu_personalizacion_inst):
		if _menu_personalizacion_inst.has_method("configurar_taller"):
			_menu_personalizacion_inst.configurar_taller(_taller_bridge, customizer)
		_menu_personalizacion_inst.visible = true
		_menu_personalizacion_inst.modulate.a = 0.0
		_menu_personalizacion_inst.scale = Vector2(0.95, 0.95)
		_menu_personalizacion_inst.pivot_offset = _menu_personalizacion_inst.size / 2.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_menu_personalizacion_inst, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_menu_personalizacion_inst, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _cerrar_taller_personalizacion() -> void:
	if not _en_personalizacion:
		return
	_en_personalizacion = false

	if is_instance_valid(_instancia_vehiculo):
		var comp := _instancia_vehiculo.get_node_or_null("CustomizerComponent")
		if comp and comp.has_method("desactivar_xray"):
			comp.desactivar_xray()

	if is_instance_valid(_taller_bridge):
		_taller_bridge.selection_mode = false
		_taller_bridge.desactivar_camara()

	if is_instance_valid(_cam_previa_taller):
		_cam_previa_taller.make_current()
	_cam_previa_taller = null

	if is_instance_valid(_menu_personalizacion_inst):
		_menu_personalizacion_inst.visible = false

	for h in _huds_ocultos_taller:
		if is_instance_valid(h):
			h.visible = true
	_huds_ocultos_taller.clear()

	Input.mouse_mode = _mouse_mode_previo

class _TallerPruebaBridge extends Node:
	var _modo_prueba: ModoPrueba = null
	var vehiculo_dentro: Node3D = null
	var _customizer: Node = null
	var _camara: Camera3D = null

	var target_distance: float = 8.5
	var target_yaw: float = -45.0
	var target_pitch: float = -15.0
	var target_pivot_pos: Vector3 = Vector3.ZERO
	var selection_mode: bool = false

	var _curr_distance: float = 8.5
	var _curr_yaw: float = -45.0
	var _curr_pitch: float = -15.0
	var _curr_pivot: Vector3 = Vector3.ZERO
	var _arrastrando: bool = false
	var _ultimo_toque: Vector2 = Vector2.ZERO

	func configurar(mp: ModoPrueba, veh: Node3D, comp: Node) -> void:
		_modo_prueba = mp
		vehiculo_dentro = veh
		_customizer = comp
		if not is_instance_valid(_camara):
			_camara = Camera3D.new()
			_camara.name = "CamaraTallerPrueba"
			_camara.fov = 52.0
			_camara.near = 0.2
			_camara.far = 1500.0
			add_child(_camara)
		enfocar_carroceria()
		_curr_distance = target_distance
		_curr_yaw = target_yaw
		_curr_pitch = target_pitch
		_curr_pivot = target_pivot_pos

	func activar_camara() -> void:
		if is_instance_valid(_camara):
			_actualizar_camara(true, 0.016)
			_camara.make_current()

	func desactivar_camara() -> void:
		if is_instance_valid(_camara):
			_camara.current = false

	func cerrar_taller() -> void:
		if is_instance_valid(_modo_prueba):
			_modo_prueba._cerrar_taller_personalizacion()

	func set_selection_mode(enabled: bool) -> void:
		selection_mode = enabled

	func enfocar_carroceria() -> void:
		if not is_instance_valid(vehiculo_dentro):
			return
		target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 1.35, 0.0)
		target_distance = 8.5
		target_yaw = -42.0
		target_pitch = -14.0

	func enfocar_rines() -> void:
		if not is_instance_valid(vehiculo_dentro):
			return
		target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 0.65, 0.0)
		target_distance = 4.6
		target_yaw = -85.0
		target_pitch = -8.0

	func enfocar_techo() -> void:
		if not is_instance_valid(vehiculo_dentro):
			return
		target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 2.2, 0.0)
		target_distance = 6.5
		target_yaw = -30.0
		target_pitch = -35.0

	func enfocar_frente() -> void:
		if not is_instance_valid(vehiculo_dentro):
			return
		target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 1.2, 0.0)
		target_distance = 6.2
		target_yaw = 180.0
		target_pitch = -10.0

	func enfocar_atras() -> void:
		if not is_instance_valid(vehiculo_dentro):
			return
		target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 1.3, 0.0)
		target_distance = 6.5
		target_yaw = 0.0
		target_pitch = -12.0

	func enfocar_interior() -> void:
		if not is_instance_valid(vehiculo_dentro):
			return
		target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 1.7, -0.4)
		target_distance = 3.2
		target_yaw = -55.0
		target_pitch = -10.0

	func enfocar_nodo(nodo: Node3D, dist: float = 3.0, yaw: float = -45.0, pitch: float = -15.0, offset: Vector3 = Vector3.ZERO) -> void:
		if not is_instance_valid(nodo):
			return
		target_pivot_pos = nodo.global_position + offset
		target_distance = dist
		target_yaw = yaw
		target_pitch = pitch

	func _process(delta: float) -> void:
		if not is_instance_valid(_modo_prueba) or not _modo_prueba._en_personalizacion:
			return
		_actualizar_camara(false, delta)

	func _actualizar_camara(inmediato: bool, delta: float) -> void:
		if not is_instance_valid(_camara):
			return
		var t: float = 1.0 if inmediato else clampf(delta * 8.0, 0.0, 1.0)
		_curr_distance = lerpf(_curr_distance, target_distance, t)
		_curr_yaw = lerpf(_curr_yaw, target_yaw, t)
		_curr_pitch = lerpf(_curr_pitch, target_pitch, t)
		_curr_pivot = _curr_pivot.lerp(target_pivot_pos, t)

		var yaw_rad := deg_to_rad(_curr_yaw)
		var pitch_rad := deg_to_rad(_curr_pitch)
		var dir := Vector3(
			cos(pitch_rad) * sin(yaw_rad),
			-sin(pitch_rad),
			cos(pitch_rad) * cos(yaw_rad)
		)
		var pos_cam := _curr_pivot + dir * _curr_distance
		_camara.global_position = pos_cam
		_camara.look_at(_curr_pivot, Vector3.UP)

	func _unhandled_input(event: InputEvent) -> void:
		if not is_instance_valid(_modo_prueba) or not _modo_prueba._en_personalizacion or not is_instance_valid(_camara):
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				target_distance = clampf(target_distance - 0.6, 2.0, 20.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				target_distance = clampf(target_distance + 0.6, 2.0, 20.0)
			elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
				_arrastrando = mb.pressed
				_ultimo_toque = mb.position
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if selection_mode:
					_intentar_seleccionar_pieza(mb.position)
				else:
					_arrastrando = true
					_ultimo_toque = mb.position
			elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_arrastrando = false
		elif event is InputEventMouseMotion and _arrastrando:
			var mm := event as InputEventMouseMotion
			target_yaw -= mm.relative.x * 0.35
			target_pitch = clampf(target_pitch - mm.relative.y * 0.3, -65.0, 15.0)
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed and selection_mode:
				_intentar_seleccionar_pieza(st.position)
			_arrastrando = st.pressed
			_ultimo_toque = st.position
		elif event is InputEventScreenDrag and _arrastrando:
			var sd := event as InputEventScreenDrag
			target_yaw -= sd.relative.x * 0.35
			target_pitch = clampf(target_pitch - sd.relative.y * 0.3, -65.0, 15.0)

	func _intentar_seleccionar_pieza(screen_pos: Vector2) -> void:
		if not is_instance_valid(_camara) or not is_instance_valid(_customizer):
			return
		var space := _camara.get_world_3d().direct_space_state if _camara.get_world_3d() else null
		if not space:
			return
		var orig := _camara.project_ray_origin(screen_pos)
		var dir := _camara.project_ray_normal(screen_pos)
		var q := PhysicsRayQueryParameters3D.create(orig, orig + dir * 100.0)
		var res := space.intersect_ray(q)
		if res and res.has("collider"):
			var col = res["collider"]
			var mesh: MeshInstance3D = col as MeshInstance3D if col is MeshInstance3D else _buscar_primer_mesh(col)
			if is_instance_valid(mesh) and _customizer.has_method("seleccionar_mesh"):
				_customizer.seleccionar_mesh(mesh, self)
				selection_mode = false

	func _buscar_primer_mesh(node: Node) -> MeshInstance3D:
		if not is_instance_valid(node):
			return null
		if node is MeshInstance3D:
			return node as MeshInstance3D
		for c in node.get_children():
			var found := _buscar_primer_mesh(c)
			if found:
				return found
		return null
