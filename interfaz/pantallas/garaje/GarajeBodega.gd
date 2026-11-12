extends Node3D

# ==============================================================================
# GARAJE_BODEGA.GD - Taller y Biblioteca de Vehículos en Bodega 3D
# Sistema "Nuestra Tierra 2.0" - Glassmorphism Automotriz
# ==============================================================================

const RUTA_BODEGA := "res://modelos3d/mapa/bodega/bodega.tscn"
const RUTA_MENU_UI := "res://interfaz/pantallas/tienda/MenuPersonalizacion.tscn"
const RUTA_BIBLIOTECA_UI := "res://interfaz/pantallas/garaje/BibliotecaVehiculosUI.tscn"
const RUTA_MAIN_MENU := "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"

# Catálogo oficial de vehículos instanciables
const CATALOGO_VEHICULOS := {
	"T800_A": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T800_Alargada": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"Mespark": "res://modelos3d/vehiculos/automoviles/Mespark/mespark.tscn",
	"Duster": "res://modelos3d/vehiculos/automoviles/Duster/duster.tscn",
	"ToyotaHiace": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Hiage": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Pardo": "res://modelos3d/vehiculos/automoviles/Pardo/pardo.tscn",
	"T800": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800/t800.tscn",
	"800_Modular": "res://modelos3d/vehiculos/tractomulas/cabezotes/t800_modular/800_Modular.tscn",
	"T680": "res://modelos3d/vehiculos/tractomulas/cabezotes/T680/T680.tscn",
	"Kodiak": "res://modelos3d/vehiculos/tractomulas/cabezotes/KODIAK/kodiak.tscn",
	"NPR": "res://modelos3d/vehiculos/NPR/npr.tscn",
	"Sprinter": "res://modelos3d/vehiculos/automoviles/sprinter/sprinter_repartidor.tscn",
	"Marcopolo": "res://modelos3d/vehiculos/Buses/MarcopoloG8-1200/MarcopoloG8-1200.tscn"
}

# Distancias y alturas óptimas de cámara por tipo de vehículo
const AJUSTES_CAMARA := {
	"T800_A": {"dist": 9.2, "altura": 1.6},
	"T800_Alargada": {"dist": 9.2, "altura": 1.6},
	"Mespark": {"dist": 5.2, "altura": 0.95},
	"Duster": {"dist": 6.2, "altura": 1.15},
	"ToyotaHiace": {"dist": 6.8, "altura": 1.3},
	"Hiage": {"dist": 6.8, "altura": 1.3},
	"Pardo": {"dist": 6.4, "altura": 1.15, "rot_y": 0.0}
}

# --- ESTADO DE INTERACCIÓN Y CÁMARA ---
var vehiculo_dentro: Node3D = null
var vehiculo_activo: Node3D = null
var customizer_component: Node = null
var bodega_inst: Node3D = null

var biblioteca_ui_inst: Control = null
var menu_ui_inst: Control = null
var id_vehiculo_actual: String = "T800_A"

var spawn_pos: Vector3 = Vector3(0.0, 0.05, -2.0)
var spawn_rot: Vector3 = Vector3(0.0, PI, 0.0)

# Rig de cámara orbital interactiva
var camera_pivot: Node3D = null
var dynamic_camera: Camera3D = null

var target_yaw: float = -45.0
var target_pitch: float = -15.0
var current_yaw: float = -45.0
var current_pitch: float = -15.0

var target_distance: float = 9.0
var current_distance: float = 9.0
var camera_distance: float = 9.0 # Compatibilidad

var target_pivot_pos: Vector3 = Vector3.ZERO
var current_pivot_pos: Vector3 = Vector3.ZERO

var camera_sensitivity: float = 0.2
var selection_mode: bool = false
var editando: bool = false

@onready var ui_canvas_layer: CanvasLayer = $CanvasLayer

func _ready() -> void:
	_cargar_bodega()
	_cargar_ultimo_vehiculo()
	_crear_camara_orbital()
	_crear_zona_tactil()
	_cargar_menu_personalizacion()
	_cargar_biblioteca_ui()

func _process(delta: float) -> void:
	# Controles de teclado opcionales para rotar la cámara (PC)
	var rot_speed = delta * 120.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		target_yaw += rot_speed
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		target_yaw -= rot_speed
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		target_pitch -= rot_speed
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		target_pitch += rot_speed
	target_pitch = clamp(target_pitch, -60.0, 20.0)

	# Interpolación ultra suave (damping) de la cámara orbital
	if camera_pivot and dynamic_camera:
		current_yaw = lerp_angle(current_yaw, deg_to_rad(target_yaw), 0.12)
		current_pitch = lerp(current_pitch, deg_to_rad(target_pitch), 0.12)
		camera_pivot.rotation.y = current_yaw
		camera_pivot.rotation.x = current_pitch

		current_distance = lerp(current_distance, target_distance, 0.12)
		dynamic_camera.position.z = current_distance

		current_pivot_pos = current_pivot_pos.lerp(target_pivot_pos, 0.12)
		camera_pivot.global_position = current_pivot_pos

func _cargar_bodega() -> void:
	if ResourceLoader.exists(RUTA_BODEGA):
		var bodega_scene = load(RUTA_BODEGA)
		if bodega_scene:
			bodega_inst = bodega_scene.instantiate()
			add_child(bodega_inst)
			# Desactivar la cámara previa de la bodega para que use nuestra cámara de taller
			var cam_prev = bodega_inst.find_child("Camera3D", true, false)
			if cam_prev and cam_prev is Camera3D:
				cam_prev.current = false
			print("[GarajeBodega] Bodega 3D cargada exitosamente.")

func _get_datos_usuario() -> Node:
	if has_node("/root/DatosUsuario"):
		return get_node("/root/DatosUsuario")
	return null

func _cargar_ultimo_vehiculo() -> void:
	if not bodega_inst:
		return

	# Obtener el nombre del último vehículo guardado en DatosUsuario
	var nombre_vehiculo = ""
	var datos = _get_datos_usuario()
	if datos:
		if "guardado_player_vehiculo_nombre" in datos and datos.guardado_player_vehiculo_nombre != "":
			nombre_vehiculo = datos.guardado_player_vehiculo_nombre
		elif "vehiculo_actual" in datos and datos.vehiculo_actual != "":
			nombre_vehiculo = datos.vehiculo_actual
		elif "vehiculos_personalizados" in datos and datos.vehiculos_personalizados is Dictionary and datos.vehiculos_personalizados.size() > 0:
			nombre_vehiculo = str(datos.vehiculos_personalizados.keys()[0])

	# Fallback a T800_A
	if nombre_vehiculo == "" or not CATALOGO_VEHICULOS.has(nombre_vehiculo):
		var encontrado = false
		for k in CATALOGO_VEHICULOS.keys():
			if k.to_lower() in nombre_vehiculo.to_lower() or nombre_vehiculo.to_lower() in k.to_lower():
				nombre_vehiculo = k
				encontrado = true
				break
		if not encontrado:
			nombre_vehiculo = "T800_A"

	id_vehiculo_actual = nombre_vehiculo
	print("[GarajeBodega] Vehículo inicial a cargar: ", id_vehiculo_actual)

	var vehiculo_default = bodega_inst.get_node_or_null("T800_Alargada")
	if not vehiculo_default:
		vehiculo_default = bodega_inst.find_child("*T800*", true, false)

	if vehiculo_default:
		spawn_pos = vehiculo_default.transform.origin
		spawn_rot = vehiculo_default.rotation
		if (id_vehiculo_actual == "T800_A" or id_vehiculo_actual == "T800_Alargada") and ("T800" in vehiculo_default.name):
			vehiculo_activo = vehiculo_default
		else:
			vehiculo_default.queue_free()
			vehiculo_activo = null

	if not vehiculo_activo:
		var ruta_escena = CATALOGO_VEHICULOS.get(id_vehiculo_actual, CATALOGO_VEHICULOS["T800_A"])
		if ResourceLoader.exists(ruta_escena):
			var escena_veh = load(ruta_escena)
			if escena_veh:
				vehiculo_activo = escena_veh.instantiate()
				bodega_inst.add_child(vehiculo_activo)
				vehiculo_activo.transform.origin = spawn_pos
				vehiculo_activo.rotation = spawn_rot
				print("[GarajeBodega] Vehículo instanciado: ", ruta_escena)

	if not vehiculo_activo:
		push_error("[GarajeBodega] No se pudo instanciar ningún vehículo en la bodega.")
		return

	if vehiculo_activo is RigidBody3D:
		vehiculo_activo.freeze = true
		vehiculo_activo.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		vehiculo_activo.linear_velocity = Vector3.ZERO
		vehiculo_activo.angular_velocity = Vector3.ZERO
	elif "freeze" in vehiculo_activo:
		vehiculo_activo.freeze = true

	vehiculo_dentro = vehiculo_activo

	# Asegurar que el vehículo tenga CustomizerComponent
	_vincular_customizer()

func _vincular_customizer() -> void:
	if not vehiculo_activo:
		return
	customizer_component = vehiculo_activo.get_node_or_null("CustomizerComponent")
	if not customizer_component:
		customizer_component = vehiculo_activo.find_child("CustomizerComponent", true, false)
	if not customizer_component:
		var script_comp = load("res://codigo/sistemas/taller/customizer_component.gd")
		if script_comp:
			customizer_component = Node.new()
			customizer_component.set_script(script_comp)
			customizer_component.name = "CustomizerComponent"
			vehiculo_activo.add_child(customizer_component)
			print("[GarajeBodega] CustomizerComponent añadido al vehículo.")

	if customizer_component and customizer_component.has_method("cargar_personalizacion"):
		customizer_component.cargar_personalizacion()

func cambiar_vehiculo(nombre_nuevo: String) -> void:
	if not bodega_inst:
		return
	if not CATALOGO_VEHICULOS.has(nombre_nuevo):
		push_warning("[GarajeBodega] Clave de vehículo desconocida: " + nombre_nuevo)
		return

	id_vehiculo_actual = nombre_nuevo

	# Eliminar vehículo previo
	if vehiculo_activo and is_instance_valid(vehiculo_activo):
		vehiculo_activo.queue_free()
		vehiculo_activo = null

	var ruta_escena = CATALOGO_VEHICULOS[id_vehiculo_actual]
	if ResourceLoader.exists(ruta_escena):
		var escena_veh = load(ruta_escena)
		if escena_veh:
			vehiculo_activo = escena_veh.instantiate()
			bodega_inst.add_child(vehiculo_activo)
			vehiculo_activo.transform.origin = spawn_pos
			vehiculo_activo.rotation = spawn_rot

			if vehiculo_activo is RigidBody3D:
				vehiculo_activo.freeze = true
				vehiculo_activo.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
				vehiculo_activo.linear_velocity = Vector3.ZERO
				vehiculo_activo.angular_velocity = Vector3.ZERO
			elif "freeze" in vehiculo_activo:
				vehiculo_activo.freeze = true

			print("[GarajeBodega] Vehículo activo cambiado a: ", id_vehiculo_actual)

	if not vehiculo_activo:
		push_error("[GarajeBodega] Fallo al instanciar el nuevo vehículo.")
		return

	vehiculo_dentro = vehiculo_activo
	_vincular_customizer()

	# Guardar preferencia en DatosUsuario
	var datos = _get_datos_usuario()
	if datos:
		if "guardado_player_vehiculo_nombre" in datos:
			datos.guardado_player_vehiculo_nombre = id_vehiculo_actual
		if "vehiculo_actual" in datos:
			datos.vehiculo_actual = id_vehiculo_actual
		if datos.has_method("guardar_progreso"):
			datos.guardar_progreso()

	# Reajustar cámara según proporciones del vehículo
	_ajustar_camara_segun_vehiculo(id_vehiculo_actual)

	# Actualizar el taller de personalización si ya existe
	if menu_ui_inst and menu_ui_inst.has_method("configurar_taller"):
		menu_ui_inst.configurar_taller(self, customizer_component)

func _ajustar_camara_segun_vehiculo(id_vehiculo: String) -> void:
	var cfg = AJUSTES_CAMARA.get(id_vehiculo, {"dist": 8.0, "altura": 1.4})
	target_distance = cfg["dist"]
	if vehiculo_activo:
		target_pivot_pos = vehiculo_activo.global_position + Vector3(0, cfg["altura"], 0)
	else:
		target_pivot_pos = spawn_pos + Vector3(0, cfg["altura"], 0)
	target_yaw = -45.0
	target_pitch = -12.0

func _crear_camara_orbital() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "GarajeCameraPivot"
	add_child(camera_pivot)

	var cfg = AJUSTES_CAMARA.get(id_vehiculo_actual, {"dist": 9.0, "altura": 1.5})
	target_distance = cfg["dist"]
	current_distance = target_distance

	if vehiculo_activo:
		target_pivot_pos = vehiculo_activo.global_position + Vector3(0, cfg["altura"], 0)
	else:
		target_pivot_pos = spawn_pos + Vector3(0, cfg["altura"], 0)

	current_pivot_pos = target_pivot_pos
	camera_pivot.global_position = current_pivot_pos

	dynamic_camera = Camera3D.new()
	dynamic_camera.name = "GarajeOrbitCamera"
	camera_pivot.add_child(dynamic_camera)
	dynamic_camera.position = Vector3(0, 0, current_distance)

	target_yaw = -45.0
	target_pitch = -14.0
	current_yaw = deg_to_rad(target_yaw)
	current_pitch = deg_to_rad(target_pitch)

	camera_pivot.rotation.y = current_yaw
	camera_pivot.rotation.x = current_pitch

	dynamic_camera.make_current()

func _crear_zona_tactil() -> void:
	var zona = Control.new()
	zona.name = "GarajeZonaTactil"
	zona.set_anchors_preset(Control.PRESET_FULL_RECT)
	zona.mouse_filter = Control.MOUSE_FILTER_PASS

	var zona_script = GDScript.new()
	zona_script.source_code = """extends Control
signal camara_movida(rel)
signal camara_pan(rel)
signal camara_pinch(delta_dist)
signal tap(pos)

var toques = {}
var start_pos = {}
var last_dist = -1.0
var is_touching: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				toques[-1] = event.position
				start_pos[-1] = event.position
				is_touching = true
			else:
				var s = start_pos.get(-1, null)
				if s != null and s.distance_to(event.position) < 8.0:
					emit_signal("tap", event.position)
				toques.erase(-1)
				start_pos.erase(-1)
				is_touching = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				toques[-2] = event.position
				start_pos[-2] = event.position
				is_touching = true
			else:
				var s2 = start_pos.get(-2, null)
				if s2 != null and s2.distance_to(event.position) < 8.0:
					emit_signal("tap", event.position)
				toques.erase(-2)
				start_pos.erase(-2)
				is_touching = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			emit_signal("camara_pinch", 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			emit_signal("camara_pinch", -6.0)

	elif event is InputEventMouseMotion:
		if toques.has(-1):
			var rel = event.position - toques[-1]
			toques[-1] = event.position
			emit_signal("camara_movida", rel)
		elif toques.has(-2):
			var rel = event.position - toques[-2]
			toques[-2] = event.position
			emit_signal("camara_pan", rel)

	elif event is InputEventScreenTouch:
		if event.pressed:
			toques[event.index] = event.position
			start_pos[event.index] = event.position
			is_touching = true
		else:
			var s = start_pos.get(event.index, null)
			if s != null and s.distance_to(event.position) < 16.0:
				emit_signal("tap", event.position)
			toques.erase(event.index)
			start_pos.erase(event.index)
			if toques.size() < 2:
				last_dist = -1.0
			if toques.is_empty():
				is_touching = false

	elif event is InputEventScreenDrag:
		if toques.has(event.index):
			toques[event.index] = event.position
			if toques.size() == 2:
				var keys = toques.keys()
				var d = toques[keys[0]].distance_to(toques[keys[1]])
				if last_dist > 0.0:
					emit_signal("camara_pinch", d - last_dist)
				last_dist = d
			elif toques.size() == 1:
				var rel = event.relative
				emit_signal("camara_movida", rel)
"""
	zona_script.reload()
	zona.set_script(zona_script)
	zona.connect("camara_movida", Callable(self, "_on_camara_movida"))
	zona.connect("camara_pan", Callable(self, "_on_camara_pan"))
	zona.connect("camara_pinch", Callable(self, "_on_camara_pinch"))
	zona.connect("tap", Callable(self, "_on_tap"))

	ui_canvas_layer.add_child(zona)
	ui_canvas_layer.move_child(zona, 0)

func _on_camara_movida(relative: Vector2) -> void:
	target_yaw -= relative.x * camera_sensitivity
	target_pitch -= relative.y * camera_sensitivity
	target_pitch = clamp(target_pitch, -60.0, 20.0)

func _on_camara_pan(relative: Vector2) -> void:
	if not dynamic_camera:
		return
	var cam_basis = dynamic_camera.global_transform.basis
	var pan_speed := 0.006
	var pan_offset = (-cam_basis.x * relative.x + cam_basis.y * relative.y) * pan_speed
	target_pivot_pos += pan_offset

func _on_camara_pinch(delta_dist: float) -> void:
	target_distance = clamp(target_distance - delta_dist * 0.06, 2.0, 20.0)

func _on_tap(pos: Vector2) -> void:
	if not selection_mode or not dynamic_camera:
		return
	var from = dynamic_camera.project_ray_origin(pos)
	var to = from + dynamic_camera.project_ray_normal(pos) * 1000.0
	var espacio: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [])
	var resultado: Dictionary = espacio.intersect_ray(params)
	if resultado and resultado.has("collider"):
		var collider = resultado["collider"]
		var mesh = collider if collider is MeshInstance3D else _find_first_mesh(collider)
		if mesh and is_instance_valid(mesh) and customizer_component:
			if customizer_component.has_method("seleccionar_mesh"):
				customizer_component.seleccionar_mesh(mesh, self)
	selection_mode = false

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if not node:
		return null
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var f = _find_first_mesh(c)
		if f:
			return f
	return null

# --- 1. CARGA DE LA BIBLIOTECA DE VEHÍCULOS ---
func _cargar_biblioteca_ui() -> void:
	if not ResourceLoader.exists(RUTA_BIBLIOTECA_UI):
		push_error("[GarajeBodega] No se encontró BibliotecaVehiculosUI.tscn")
		return

	var scene_biblio = load(RUTA_BIBLIOTECA_UI)
	if scene_biblio:
		biblioteca_ui_inst = scene_biblio.instantiate()
		ui_canvas_layer.add_child(biblioteca_ui_inst)

		biblioteca_ui_inst.connect("vehiculo_seleccionado", Callable(self, "_on_vehiculo_seleccionado_biblioteca"))
		biblioteca_ui_inst.connect("personalizar_solicitado", Callable(self, "abrir_personalizacion"))
		biblioteca_ui_inst.connect("volver_solicitado", Callable(self, "salir_al_menu_principal"))

		# Sincronizar selección inicial
		if biblioteca_ui_inst.has_method("_seleccionar_vehiculo"):
			biblioteca_ui_inst._seleccionar_vehiculo(id_vehiculo_actual, false)

		print("[GarajeBodega] Interfaz de Biblioteca de Vehículos conectada exitosamente.")

func _on_vehiculo_seleccionado_biblioteca(id_vehiculo: String) -> void:
	cambiar_vehiculo(id_vehiculo)

# --- 2. CARGA DEL MENÚ DE PERSONALIZACIÓN ---
func _cargar_menu_personalizacion() -> void:
	if not ResourceLoader.exists(RUTA_MENU_UI):
		push_error("[GarajeBodega] No se encontró MenuPersonalizacion.tscn")
		return

	var scene_ui = load(RUTA_MENU_UI)
	if scene_ui:
		menu_ui_inst = scene_ui.instantiate()
		ui_canvas_layer.add_child(menu_ui_inst)

		if menu_ui_inst is Control:
			menu_ui_inst.mouse_filter = Control.MOUSE_FILTER_PASS

		if menu_ui_inst.has_method("configurar_taller"):
			menu_ui_inst.configurar_taller(self, customizer_component)

		# Comienza oculto hasta que el usuario pulse "Personalizar"
		menu_ui_inst.visible = false
		print("[GarajeBodega] Menú de personalización preparado en segundo plano.")

# --- TRANSICIÓN: BIBLIOTECA <-> PERSONALIZACIÓN ---
func abrir_personalizacion() -> void:
	if not menu_ui_inst:
		return

	editando = true
	if biblioteca_ui_inst:
		if biblioteca_ui_inst.has_method("animar_salida"):
			biblioteca_ui_inst.animar_salida(func():
				biblioteca_ui_inst.visible = false
				_mostrar_pantalla_personalizacion()
			)
		else:
			biblioteca_ui_inst.visible = false
			_mostrar_pantalla_personalizacion()
	else:
		_mostrar_pantalla_personalizacion()

func _mostrar_pantalla_personalizacion() -> void:
	if not menu_ui_inst:
		return

	if menu_ui_inst.has_method("configurar_taller"):
		menu_ui_inst.configurar_taller(self, customizer_component)

	menu_ui_inst.visible = true
	menu_ui_inst.modulate.a = 0.0
	menu_ui_inst.scale = Vector2(0.95, 0.95)
	menu_ui_inst.pivot_offset = menu_ui_inst.size / 2.0

	var tw = create_tween().set_parallel(true)
	tw.tween_property(menu_ui_inst, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(menu_ui_inst, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	enfocar_carroceria()

func cerrar_taller() -> void:
	if menu_ui_inst and menu_ui_inst.visible:
		# Volver del taller de personalización a la Biblioteca de Vehículos
		editando = false
		var tw = create_tween().set_parallel(true)
		tw.tween_property(menu_ui_inst, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(menu_ui_inst, "scale", Vector2(0.95, 0.95), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func():
			menu_ui_inst.visible = false
			if biblioteca_ui_inst:
				biblioteca_ui_inst.visible = true
				if biblioteca_ui_inst.has_method("_animar_entrada"):
					biblioteca_ui_inst._animar_entrada()
			_ajustar_camara_segun_vehiculo(id_vehiculo_actual)
		)
	else:
		salir_al_menu_principal()

func salir_al_menu_principal() -> void:
	var datos = _get_datos_usuario()
	if datos and datos.has_method("guardar_progreso"):
		datos.guardar_progreso()
	if datos and datos.has_method("cambiar_escena"):
		datos.cambiar_escena(RUTA_MAIN_MENU)
	else:
		get_tree().change_scene_to_file(RUTA_MAIN_MENU)

# --- PRESETS Y MÉTODOS REQUERIDOS POR MENUPERSONALIZACION ---
func set_selection_mode(enabled: bool) -> void:
	selection_mode = enabled

func enfocar_carroceria() -> void:
	if not vehiculo_dentro: return
	var cfg = AJUSTES_CAMARA.get(id_vehiculo_actual, {"dist": 9.0, "altura": 1.5})
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, cfg["altura"], 0)
	target_distance = cfg["dist"]
	target_yaw = -45.0
	target_pitch = -15.0

func enfocar_rines() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(-1.2, 0.4, 1.6)
	target_distance = 3.6
	target_yaw = -82.0
	target_pitch = -8.0

func enfocar_placas() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0.0, 0.8, 3.2)
	target_distance = 2.8
	target_yaw = 0.0
	target_pitch = -12.0

func enfocar_neon() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 0.2, 0)
	target_distance = 8.5
	target_yaw = -35.0
	target_pitch = -32.0

func enfocar_frontal() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 1.2, 2.5)
	target_distance = 4.5
	target_yaw = 0.0
	target_pitch = -10.0

func enfocar_trasera() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 1.2, -2.5)
	target_distance = 4.5
	target_yaw = 180.0
	target_pitch = -10.0

func enfocar_lateral() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 1.2, 0)
	target_distance = 6.0
	target_yaw = 90.0
	target_pitch = -10.0

func enfocar_motor() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(0, 1.2, 1.5)
	target_distance = 3.0
	target_yaw = -30.0
	target_pitch = -25.0

func enfocar_interior() -> void:
	if not vehiculo_dentro: return
	target_pivot_pos = vehiculo_dentro.global_position + Vector3(-0.4, 1.6, 0.2)
	target_distance = 2.0
	target_yaw = 0.0
	target_pitch = -5.0

func enfocar_nodo(nodo: Node3D, distance: float = 3.0, yaw: float = -45.0, pitch: float = -15.0, offset: Vector3 = Vector3.ZERO) -> void:
	if not nodo or not is_instance_valid(nodo):
		return
	target_pivot_pos = nodo.global_position + offset
	target_distance = distance
	target_yaw = yaw
	target_pitch = pitch
