extends CharacterBody3D

const SENSIBILIDAD_1P = 0.0015
const PITCH_MIN = -PI/4.0
const PITCH_MAX = PI/3.5
const LERP_ROTACION = 10.0
const LERP_ROTACION_1P = 3.5
const ZOOM_MIN = 1.8
const ZOOM_MAX = 6.5
const FOV_1P = 72.0
const TILT_MAX = 0.045
const TILT_LERP = 8.0
const BOB_FREQ_CAMINAR = 1.8
const BOB_FREQ_CORRER = 2.6
const BOB_AMP_Y = 0.025
const BOB_AMP_X = 0.015
const COYOTE_TIME = 0.12
const LERP_AGACHAR = 12.0
const BLEND_LOCOMOCION = 0.2
const BLEND_OTROS = 0.1
const CAM_1P_OFFSET = Vector3(0, 1.65, 0.05)
const CAM_1P_FORWARD = 0.22
const YAW_1P_MAX = PI * 0.72
const ZOOM_1P = 0.0
const AUTO_CENTER_DELAY = 3.0
const AUTO_CENTER_LERP = 2.5

const ANIM_IDLE = "Idle"
const ANIM_CAMINAR = "caminar"
const ANIM_CORRER = "Correr"
const ANIM_SALTAR = "Saltar Corriendo"
const ANIM_AGACHARSE = "Agacharse"
const ANIM_CONDUCIR = "Conducir"

@export_group("Nodos")
@export var spring_arm_path: NodePath = ^"SpringArm3D"
@export var ui_pie_path: NodePath = ^"UIpie"

@export_group("Velocidades de Movimiento")
@export_range(1.0, 10.0, 0.1) var v_caminar: float = 4.0
@export_range(5.0, 20.0, 0.1) var v_correr: float = 7.5
@export_range(1.0, 10.0, 0.1) var v_salto: float = 5.0
@export_range(0.0, 10.0, 0.1) var impulso_salto_fwd: float = 2.5
@export_range(1.0, 10.0, 0.1) var v_agachado: float = 2.0

@export_group("Fisicas y Control")
@export_range(1.0, 50.0, 0.5) var aceleracion: float = 18.0
@export_range(1.0, 50.0, 0.5) var friccion: float = 14.0
@export_range(0.1, 1.0, 0.05) var control_aire: float = 0.35
@export_range(0.0, 1.0, 0.05) var altura_paso: float = 0.4
@export var permitir_teclado_movimiento: bool = true

@export_group("Camara y Sensibilidad")
@export var solo_touch_camara: bool = true
@export_range(0.0001, 0.01, 0.0001) var sensibilidad_raton: float = 0.003
@export_range(1.0, 10.0, 0.1) var zoom_default: float = 3.0
@export_range(50.0, 95.0, 1.0) var fov_base: float = 72.0
## Aumento dinámico suave del FOV al correr (sprint)
@export_range(0.0, 10.0, 0.5) var fov_sprint_boost: float = 3.5

@export_group("Configuracion Vehiculo")
@export var asiento_offset_pos: Vector3 = Vector3.ZERO
@export var asiento_offset_rot: Vector3 = Vector3.ZERO
@export var ocultar_modelo_conduciendo: bool = true

@export_group("Agarre de Caja")
## Posición de la caja respecto al jugador
@export var caja_offset_pos: Vector3 = Vector3(0.06, 1.285, -0.475)
## Rotación de la caja respecto al jugador
@export var caja_offset_rot: Vector3 = Vector3(15.49, 0.0, 0.0)
## Ajuste de posición de la mano izquierda respecto a su punto base
@export var mano_izq_offset_pos: Vector3 = Vector3(-0.02, 0.055, 0.08)
## Rotación (en grados) de la mano izquierda respecto a la caja
@export var mano_izq_offset_rot: Vector3 = Vector3(88.345, 54.225, 87.93)
## Ajuste de posición de la mano derecha respecto a su punto base
@export var mano_der_offset_pos: Vector3 = Vector3(0.055, 0.04, 0.165)
## Rotación (en grados) de la mano derecha respecto a la caja
@export var mano_der_offset_rot: Vector3 = Vector3(-109.915, 112.13, 113.8)
## Si es verdadero, el IK forzará la rotación de la muñeca al objetivo del Marker3D. Si es falso, se usará rotación manual por código.
@export var ik_override_tip_basis: bool = false
## Hueso raíz para el IK del brazo izquierdo (ej: mixamorig_LeftShoulder o mixamorig_LeftArm)
@export var ik_izq_root_bone: String = "mixamorig_LeftShoulder"
## Hueso raíz para el IK del brazo derecho (ej: mixamorig_RightShoulder o mixamorig_RightArm)
@export var ik_der_root_bone: String = "mixamorig_RightShoulder"
## Rotación extra (en grados) para el hombro izquierdo
@export var hombro_izq_offset_rot: Vector3 = Vector3.ZERO
## Rotación extra (en grados) para el hombro derecho
@export var hombro_der_offset_rot: Vector3 = Vector3.ZERO

@export_group("Posicionamiento Tableta")
## Posición local de la tableta cuando el jugador la lleva en las manos
@export var tableta_offset_pos: Vector3 = Vector3(0.06, 1.285, -0.475)
## Rotación local de la tableta (grados) cuando el jugador la lleva en las manos
@export var tableta_offset_rot: Vector3 = Vector3(15.49, 0.0, 0.0)

var _modelo: Node3D
var _camera: Camera3D
var _camara_1p: Camera3D
var _cabeza: Node
var _skeleton: Skeleton3D
var _cabeza_bone_idx = -1
var _hips_bone_idx = -1
var _spine_bone_idx = -1
var _hips_offset_y: float = 0.0
var _spine_rot_x: float = 0.0
var _vigneta_layer: CanvasLayer
var _collision_shape: CollisionShape3D

@onready var spring_arm = get_node_or_null(spring_arm_path) as SpringArm3D
@onready var ui_pie = get_node_or_null(ui_pie_path) as CanvasLayer
@onready var firestore = null
var anim_player: AnimationPlayer
@export var debug_interaction: bool = false

var _camara_yaw = 0.0
var _camara_pitch = 0.0
var _camara_tilt = 0.0
var _bob_tiempo = 0.0
var _bob_offset = Vector3.ZERO
var _auto_center_timer = 0.0
var _shake_mag = 0.0
var _spring_arm_pos_base = Vector3.ZERO
var _vel_horizontal = Vector3.ZERO
var _en_aire = false
var _coyote_timer = 0.0
var _anim_actual = ""
var _agachado = false
var esta_agachado: bool:
	get:
		return _agachado
	set(value):
		_set_agachado(value)
var _primera_persona = true
var _agachado_t = 0.0
var _anim_lock = false
var _reproduciendo_agachado_reverso = false
var _zona_camara_activa = false
var _zoom_guardado = 3.5
var _conduciendo = false
var _recien_bajado_timer: float = 0.0
var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL: float = 15.0
var _vehiculo_actual: Node3D
var _vehiculo_cerca: Node3D
var _asiento_cache: Node3D
var _ui_boton_interactuar: Button
var _ui_joystick: Node
var _pos_objetivo: Vector3 = Vector3.ZERO
var _rot_y_objetivo: float = 0.0
var celular: CanvasLayer = null
var inventario: CanvasLayer = null
var item_en_mano_ctrl: ControladorItemEnMano = null
var tienda_ui: TiendaUI = null
var mano_izq_ik: SkeletonIK3D = null
var mano_der_ik: SkeletonIK3D = null
var caja_agarrada: Node3D = null
var _mano_izq_base_rot: Vector3 = Vector3.ZERO
var _mano_der_base_rot: Vector3 = Vector3.ZERO
var _mano_izq_base_pos: Vector3 = Vector3.ZERO
var _mano_der_base_pos: Vector3 = Vector3.ZERO


func _recursive_find_by_name(node: Node, target: String) -> Node:
	if node == null:
		return null
	if node.name == target:
		return node
	for child in node.get_children():
		if child is Node:
			var res = _recursive_find_by_name(child, target)
			if res:
				return res
	return null

func _ready():
	add_to_group("jugador")
	# Configuración para subir aceras/escalones automáticamente
	floor_constant_speed = true
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(65.0)
	
	for h in get_children():
		if h is Node3D and not (h is SpringArm3D or h is CollisionShape3D):
			_modelo = h
			break
	
	_skeleton = _buscar_nodo_tipo(self, "Skeleton3D")
	if _skeleton:
		_cabeza_bone_idx = _skeleton.find_bone("mixamorig_Head")
		_hips_bone_idx = _skeleton.find_bone("mixamorig_Hips")
		_spine_bone_idx = _skeleton.find_bone("mixamorig_Spine")
		
		# Crear nodos IK de las manos para agarrar cajas programáticamente
		mano_izq_ik = SkeletonIK3D.new()
		mano_izq_ik.name = "ManoIzquierdaIK"
		mano_izq_ik.root_bone = &"mixamorig_LeftShoulder"
		mano_izq_ik.tip_bone = &"mixamorig_LeftHand"
		mano_izq_ik.override_tip_basis = false # Desactivado para rotar la muñeca manualmente sin bugs
		_skeleton.add_child(mano_izq_ik)
		
		mano_der_ik = SkeletonIK3D.new()
		mano_der_ik.name = "ManoDerechaIK"
		mano_der_ik.root_bone = &"mixamorig_RightShoulder"
		mano_der_ik.tip_bone = &"mixamorig_RightHand"
		mano_der_ik.override_tip_basis = false # Desactivado para rotar la muñeca manualmente sin bugs
		_skeleton.add_child(mano_der_ik)
	
	anim_player = _buscar_nodo_tipo(self, "AnimationPlayer")
	if anim_player:
		_reproducir_anim(ANIM_IDLE)
		anim_player.animation_finished.connect(_on_animation_finished)
	
	if not spring_arm:
		spring_arm = _buscar_nodo_tipo(self, "SpringArm3D")
	
	if spring_arm:
		_camera = spring_arm.get_node_or_null("Camera3D")
		_camara_yaw = rotation.y + spring_arm.rotation.y
		_camara_pitch = spring_arm.rotation.x
		_spring_arm_pos_base = spring_arm.position
		spring_arm.spring_length = zoom_default
		_zoom_guardado = zoom_default
	
	if not _camera:
		for h in get_children():
			if h is Camera3D:
				_camera = h
				break
	
	if not _camera:
		# En modo multijugador NO buscar en toda la escena — podria capturar
		# la camara de otro jugador y luego perderla cuando ese jugador sea liberado.
		if not multiplayer.has_multiplayer_peer():
			_camera = _find_closest_camera()
	
	if _camera:
		_camera.fov = fov_base
		# Asegurar que la cámara del jugador NUNCA renderice la capa 2 (GPS/Minimapa)
		_camera.cull_mask = _camera.cull_mask & ~2
	
	var root = get_tree().current_scene if (get_tree() and get_tree().current_scene) else self
	_camara_1p = root.find_child("PrimeraPersona", true, false)
	if _camara_1p:
		_camara_1p.fov = fov_base
	if _camara_1p:
		# Asegurar que la cámara de 1ª persona tampoco renderice la capa 2 (GPS/Minimapa)
		_camara_1p.cull_mask = _camara_1p.cull_mask & ~2
	_cabeza = root.find_child("Cabeza", true, false)
	_collision_shape = _buscar_nodo_tipo(self, "CollisionShape3D")
	
	# Evitar que el jugador absorba velocidades de cuerpos cinemáticos (tráfico) y salga despedido
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	platform_floor_layers = 1
	
	_pos_objetivo = global_position
	_rot_y_objetivo = rotation.y

	# Esperar un frame para dar tiempo a que la UI se instancie
	await get_tree().process_frame

	var datos = get_node_or_null("/root/DatosUsuario")
	if not get_meta("en_modo_prueba", false) and datos and datos.guardado_player_scene != "":
		var current_scene_path = get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else ""
		if current_scene_path == datos.guardado_player_scene:
			if datos.guardado_player_pos != Vector3.ZERO:
				global_position = datos.guardado_player_pos
				rotation.y = datos.guardado_player_rot_y
				_pos_objetivo = global_position
				_rot_y_objetivo = rotation.y
				print("[jugador3D] Cargada posición guardada: ", global_position)

	# Instanciar UIPie dinámicamente si no está presente en la escena (solo si somos autoridad local)
	var ui_node = ui_pie if ui_pie else null
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		if not ui_node:
			if get_tree() and get_tree().has_method("get_current_scene"):
				var cs = get_tree().get_current_scene()
				if cs:
					ui_node = cs.find_child("UIpie", true, false)
		
		if not ui_node:
			var uipie_scene_path = "res://interfaz/hud/a_pie/UiPie.tscn"
			if ResourceLoader.exists(uipie_scene_path):
				var uipie_scene = load(uipie_scene_path)
				if uipie_scene:
					ui_node = uipie_scene.instantiate()
					# Añadirlo al root o a la escena actual para que no sea afectado por transformaciones 3D
					if get_tree() and get_tree().current_scene:
						get_tree().current_scene.add_child.call_deferred(ui_node)
					else:
						add_child(ui_node)
					print("[jugador3D] UIpie instanciada e integrada por código dinámicamente.")
			else:
				printerr("[jugador3D] No se encontró el archivo de escena: ", uipie_scene_path)

	if ui_node:
		# Aceptar tanto CanvasLayer (UIPie) como Control (zona específica)
		if ui_node is CanvasLayer:
			ui_pie = ui_node as CanvasLayer
			ui_pie.visible = not _conduciendo  # Asegurar visibilidad según el estado
		else:
			# si el nodo encontrado es la zona de cámara directamente, dejarlo en su lugar
			# y el código de conexión usará `z` más abajo
			pass

		# Intentar localizar el botón de interactuar de forma compatible
		if ui_pie:
			_ui_boton_interactuar = ui_pie.get_node_or_null("Controles/GridContainer/BotonEntrar")
			if not _ui_boton_interactuar:
				_ui_boton_interactuar = ui_pie.get_node_or_null("Controles/Interactuar")
			if not _ui_boton_interactuar:
				_ui_boton_interactuar = ui_pie.get_node_or_null("Controles/BotonInteractuar")
			if _ui_boton_interactuar:
				var cb_press = Callable(self, "_on_boton_entrar_pressed")
				if not _ui_boton_interactuar.pressed.is_connected(cb_press):
					_ui_boton_interactuar.pressed.connect(_on_boton_entrar_pressed)

		# Conectar señales de cámara: preferir el CanvasLayer `ui_pie`, fallback a la zona
		var z = null
		if ui_pie and ui_pie.has_signal("camara_movida"):
			if not ui_pie.is_connected("camara_movida", Callable(self, "_manejar_camara_tactil")):
				ui_pie.connect("camara_movida", Callable(self, "_manejar_camara_tactil"))
				_zona_camara_activa = true
			if ui_pie.has_signal("camara_pinch") and not ui_pie.is_connected("camara_pinch", Callable(self, "_on_camara_pinch")):
				ui_pie.connect("camara_pinch", Callable(self, "_on_camara_pinch"))
		else:
			# buscar zona interna o por grupo
			if ui_pie:
				z = ui_pie.get_node_or_null("Controles/ZonaCamara")
			if not z:
				z = get_tree().get_first_node_in_group("zona_camara")
			if z:
				if not z.is_connected("camara_movida", Callable(self, "_manejar_camara_tactil")):
					z.connect("camara_movida", Callable(self, "_manejar_camara_tactil"))
					_zona_camara_activa = true
				if z.has_signal("camara_pinch") and not z.is_connected("camara_pinch", Callable(self, "_on_camara_pinch")):
					z.connect("camara_pinch", Callable(self, "_on_camara_pinch"))

	# Conectar dinámicamente las zonas de entrada de vehículos al jugador
	# para que entrar en la collision de la puerta habilite la interacción.
	await get_tree().process_frame
	_connect_zonas_entrada()
	# Escuchar nodos añadidos para detectar ZonaEntrada instanciadas tarde
	if get_tree():
		var cb = Callable(self, "_on_node_added")
		if not get_tree().node_added.is_connected(cb):
			get_tree().node_added.connect(cb)
			if debug_interaction:
				print("jugador3D: conectado a node_added")
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Juego táctil: nunca capturar el mouse
	_crear_vigneta()

	# Firestore: buscar nodo en la escena (o en /root) y conectar señales si está presente
	var tree = get_tree()
	var firebase_node = null
	if tree:
		var current = tree.current_scene
		if current:
			# Preferir Firestore/ Firebase dentro de la escena actual
			firebase_node = _recursive_find_by_name(current, "Firebase")
			if firebase_node:
				firestore = _recursive_find_by_name(firebase_node, "Firestore")
			else:
				firestore = _recursive_find_by_name(current, "Firestore")

		# Si no se encontró en la escena activa, buscar en el root (autoloads)
	if not firestore and tree:
		root = tree.get_root()
		firebase_node = _recursive_find_by_name(root, "Firebase")
		if firebase_node:
			firestore = _recursive_find_by_name(firebase_node, "Firestore")
		else:
			firestore = _recursive_find_by_name(root, "Firestore")
			
	if firestore:
		var cb_written = Callable(self, "_on_document_written")
		if firestore.has_signal("document_written") and not firestore.is_connected("document_written", cb_written):
			firestore.document_written.connect(cb_written)
		var cb_failed = Callable(self, "_on_document_write_failed")
		if firestore.has_signal("document_write_failed") and not firestore.is_connected("document_write_failed", cb_failed):
			firestore.document_write_failed.connect(cb_failed)
		# módulo alternativo: conectar write_task_completed si existe
		if firestore.has_signal("write_task_completed") and not firestore.is_connected("write_task_completed", cb_written):
			firestore.write_task_completed.connect(cb_written)

	if multiplayer.has_multiplayer_peer():
		_screen_log("[jugador3D] " + name + ": Iniciando chequeo de autoridad... is_multiplayer_authority antes = " + str(is_multiplayer_authority()) + ", auth = " + str(get_multiplayer_authority()))
		# IMPORTANTE: esperar un frame para que el MultiplayerSpawner haya asignado
		# la autoridad correcta (la asigna en la señal 'spawned' DESPUES de _ready()).
		await get_tree().process_frame
		_screen_log("[jugador3D] " + name + ": is_multiplayer_authority despues = " + str(is_multiplayer_authority()) + ", auth = " + str(get_multiplayer_authority()) + ", unique_id = " + str(multiplayer.get_unique_id()))
		if not is_multiplayer_authority():
			_screen_log("[jugador3D] " + name + ": No es authority. Liberando camaras y UI...")
			var cam = find_child("Camera3D", true, false)
			if cam: 
				_screen_log("[jugador3D] " + name + ": Liberando camara remota.")
				cam.queue_free()
			var cam1p = find_child("Camara1P", true, false)
			if cam1p: 
				_screen_log("[jugador3D] " + name + ": Liberando camara 1P remota.")
				cam1p.queue_free()
			var ui = find_child("UIpie", true, false)
			if ui: 
				_screen_log("[jugador3D] " + name + ": Liberando UIpie remota.")
				ui.queue_free()
		else:
			_screen_log("[jugador3D] " + name + ": SI ES AUTHORITY! Configurando camara local...")
			# Este es nuestro propio jugador — obtener camara fresca desde SpringArm3D
			# y hacerla activa. Usamos una referencia fresca en vez de _camera porque
			# _camera podria haber quedado invalida por los awaits anteriores.
			var cam_propia: Camera3D = null
			if spring_arm:
				cam_propia = spring_arm.get_node_or_null("Camera3D") as Camera3D
			if not cam_propia:
				cam_propia = find_child("Camera3D", true, false) as Camera3D
			if cam_propia:
				_camera = cam_propia
				_camera.cull_mask = _camera.cull_mask & ~2  # Nunca mostrar capa 2 (GPS/Minimapa) en cámara principal
				_camera.fov = fov_base
				_camera.make_current()
				_screen_log("[jugador3D] Camara activada para peer local: " + str(multiplayer.get_unique_id()) + " en nodo " + name)
			else:
				_screen_log("[jugador3D] " + name + ": ERROR: No se encontro camara propia!")

	# Esperar a que todo esté cargado y listo
	await get_tree().process_frame

	# Cargar tutorial/cinemática si es primera vez y no estamos en multijugador
	var debug_info = ""
	var datos_usuario = get_node_or_null("/root/DatosUsuario")
	if datos_usuario:
		var tutor_comp = datos_usuario.tutorial_completado
		var is_multi = multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		debug_info += "DatosUsuario: OK\n"
		debug_info += "tutorial_completado: " + str(tutor_comp) + "\n"
		debug_info += "es_multijugador: " + str(is_multi) + "\n"
		
		print("[jugador3D DEBUG] DatosUsuario detectado. tutorial_completado = ", tutor_comp, ", es_multijugador = ", is_multi)
		
		# Resetear temporalmente a false para pruebas si el usuario quiere probar de inmediato
		# DatosUsuario.tutorial_completado = false
		
		if not tutor_comp and not is_multi:
			var intro_script_path = "res://codigo/sistemas/narrativa/IntroCinematic.gd"
			var exists = ResourceLoader.exists(intro_script_path)
			debug_info += "Existe IntroCinematic.gd: " + str(exists) + "\n"
			print("[jugador3D DEBUG] ¿Existe el script en la ruta '", intro_script_path, "'? ", exists)
			
			if exists:
				var intro_script = load(intro_script_path)
				debug_info += "Script cargado: " + str(intro_script != null) + "\n"
				print("[jugador3D DEBUG] ¿Script cargado con éxito? ", intro_script != null)
				if intro_script:
					var intro_node = CanvasLayer.new()
					intro_node.set_script(intro_script)
					intro_node.name = "IntroCinematic"
					add_child(intro_node)
					debug_info += "IntroCinematic instanciada y agregada al jugador.\n"
					print("[jugador3D DEBUG] Nodo IntroCinematic instanciado y agregado como hijo de jugador3D.")
		else:
			if tutor_comp:
				debug_info += "Tutorial ya estaba completado. Omitiendo intro.\n"
				print("[jugador3D DEBUG] El tutorial ya está completado, no se muestra la cinemática.")
			if is_multi:
				debug_info += "Modo multijugador activo. Omitiendo intro.\n"
				print("[jugador3D DEBUG] Modo multijugador activo, omitiendo la cinemática.")
	else:
		debug_info += "ERROR: Autoload DatosUsuario no encontrado!\n"
		print("[jugador3D DEBUG] ERROR: Autoload DatosUsuario no encontrado.")

	# Instanciar el celular para el jugador local
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		var celular_scene_path = "res://interfaz/celular/sistema/CelularUI.tscn"
		if not ResourceLoader.exists(celular_scene_path):
			celular_scene_path = "res://interfaz/celular/CelularUI.tscn"
		if ResourceLoader.exists(celular_scene_path):
			var scene = load(celular_scene_path)
			if scene:
				var cel_node = scene.instantiate()
				cel_node.name = "CelularUI"
				add_child(cel_node)
				celular = cel_node
				print("[jugador3D] CelularUI instanciado desde escena visual para el jugador local.")
				
		var inv_scene_path = "res://interfaz/sistema/InventarioUI.tscn"
		if not ResourceLoader.exists(inv_scene_path):
			inv_scene_path = "res://interfaz/inventario/InventarioUI.tscn"
		if ResourceLoader.exists(inv_scene_path):
			var scene = load(inv_scene_path)
			if scene:
				var inv_node = scene.instantiate()
				inv_node.name = "InventarioUI"
				add_child(inv_node)
				inventario = inv_node
				print("[jugador3D] InventarioUI instanciado para el jugador local.")

		# Instanciar el controlador de item en mano / viewmodel para primera persona (estilo Minecraft)
		item_en_mano_ctrl = ControladorItemEnMano.new()
		item_en_mano_ctrl.name = "ControladorItemEnMano"
		add_child(item_en_mano_ctrl)
		var cam_init: Camera3D = get_camara_activa()
		if cam_init:
			item_en_mano_ctrl.vincular_jugador(self, cam_init)

		# Instanciar TiendaUI para el jugador
		tienda_ui = TiendaUI.new()
		tienda_ui.name = "TiendaUI"
		add_child(tienda_ui)
		tienda_ui.jugador_ref = self

		# Equipar Bloque de Provisiones estilo Minecraft por defecto
		equipar_item_en_mano("bloque_suministros")

	# A pie: forzar primera persona y ocultar modelo 3D
	_set_primera_persona(true)
	if _modelo:
		_modelo.hide()



func get_camara_activa() -> Camera3D:
	if is_instance_valid(_camera):
		return _camera
	if is_instance_valid(_camara_1p):
		return _camara_1p
	return get_viewport().get_camera_3d()

func _input(e):
	if has_meta("cinematic_active") and get_meta("cinematic_active"):
		return
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
	# Abrir/cerrar celular con la tecla P en PC/Editor
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_P:
			if celular and celular.has_method("toggle_phone"):
				celular.toggle_phone()
				get_viewport().set_input_as_handled()
		elif e.keycode == KEY_T:
			if tienda_ui:
				tienda_ui.toggle_tienda()
				get_viewport().set_input_as_handled()
		elif e.keycode == KEY_I:
			if inventario and inventario.has_method("toggle_inventario"):
				inventario.toggle_inventario()
				get_viewport().set_input_as_handled()
		elif e.keycode == KEY_G:
			if item_en_mano_ctrl and item_en_mano_ctrl.tiene_item_equipado():
				item_en_mano_ctrl.guardar_en_inventario()
				get_viewport().set_input_as_handled()
		elif e.keycode == KEY_E:
			if item_en_mano_ctrl and item_en_mano_ctrl.tiene_item_equipado() and (not tienda_ui or not tienda_ui.visible):
				item_en_mano_ctrl.usar_item()
				get_viewport().set_input_as_handled()

	# Clic izquierdo para golpear / usar el objeto en mano (estilo Minecraft)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if item_en_mano_ctrl and item_en_mano_ctrl.tiene_item_equipado():
			if not (tienda_ui and tienda_ui.visible) and not (celular and celular.visible):
				item_en_mano_ctrl.usar_item()
	if _conduciendo:
		return
	if e is InputEventMouseMotion and not (_zona_camara_activa or solo_touch_camara):
		_camara_yaw -= e.relative.x * sensibilidad_raton
		_camara_pitch = clamp(_camara_pitch - e.relative.y * sensibilidad_raton, PITCH_MIN, PITCH_MAX)
		_auto_center_timer = 0
	elif e is InputEventMouseButton and e.pressed and not solo_touch_camara:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_ajustar_zoom(-0.35)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_ajustar_zoom(0.35)
	elif e.is_action_pressed("quit"): # Esc: no capturar el mouse, solo asegurar que está visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if _accion_event(e, ["crouch"]): # Solo crouch (tecla C)
		_set_agachado(not _agachado)
	if _accion_event(e, ["first_person"]): # first_person (tecla O)
		pass # 3ra persona a pie desactivada

func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
		
	# Actualizar posición y rotación de agarre en vivo para depuración en el Inspector
	if is_instance_valid(caja_agarrada) and (not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()):
		var es_tableta = caja_agarrada.name.to_lower().contains("tableta")
		if es_tableta:
			caja_agarrada.visible = false
			caja_agarrada.position = tableta_offset_pos
			caja_agarrada.rotation_degrees = tableta_offset_rot
			if mano_izq_ik and mano_izq_ik.is_running():
				mano_izq_ik.stop()
			if mano_der_ik and mano_der_ik.is_running():
				mano_der_ik.stop()
		else:
			caja_agarrada.position = caja_offset_pos
			caja_agarrada.rotation_degrees = caja_offset_rot
			
			if mano_izq_ik:
				mano_izq_ik.override_tip_basis = ik_override_tip_basis
				if mano_izq_ik.root_bone != ik_izq_root_bone:
					var was_running = mano_izq_ik.is_running()
					if was_running:
						mano_izq_ik.stop()
					mano_izq_ik.root_bone = ik_izq_root_bone
					if was_running:
						mano_izq_ik.start()
						
			if mano_der_ik:
				mano_der_ik.override_tip_basis = ik_override_tip_basis
				if mano_der_ik.root_bone != ik_der_root_bone:
					var was_running = mano_der_ik.is_running()
					if was_running:
						mano_der_ik.stop()
					mano_der_ik.root_bone = ik_der_root_bone
					if was_running:
						mano_der_ik.start()
				
			var marker_izq = caja_agarrada.get_node_or_null("SoporteManoIzquierda")
			if marker_izq and mano_izq_ik:
				marker_izq.position = Vector3(-0.2905, 0.065, 0.035) + mano_izq_offset_pos
				marker_izq.rotation_degrees = _mano_izq_base_rot + mano_izq_offset_rot
				
			var marker_der = caja_agarrada.get_node_or_null("SoporteManoDerecha")
			if marker_der and mano_der_ik:
				marker_der.position = Vector3(0.2035, 0.065, 0.035) + mano_der_offset_pos
				marker_der.rotation_degrees = _mano_der_base_rot + mano_der_offset_rot
				
			# Modificar directamente las muñecas/manos (tip bones) y hombros en el esqueleto
			if _skeleton:
				var left_hand_idx = _skeleton.find_bone("mixamorig_LeftHand")
				if left_hand_idx >= 0:
					var q = Quaternion.from_euler(mano_izq_offset_rot * (PI / 180.0))
					_skeleton.set_bone_pose_rotation(left_hand_idx, q)
					
				var right_hand_idx = _skeleton.find_bone("mixamorig_RightHand")
				if right_hand_idx >= 0:
					var q = Quaternion.from_euler(mano_der_offset_rot * (PI / 180.0))
					_skeleton.set_bone_pose_rotation(right_hand_idx, q)
					
				var left_shoulder_idx = _skeleton.find_bone("mixamorig_LeftShoulder")
				if left_shoulder_idx >= 0:
					var q = Quaternion.from_euler(hombro_izq_offset_rot * (PI / 180.0))
					_skeleton.set_bone_pose_rotation(left_shoulder_idx, q)
					
				var right_shoulder_idx = _skeleton.find_bone("mixamorig_RightShoulder")
				if right_shoulder_idx >= 0:
					var q = Quaternion.from_euler(hombro_der_offset_rot * (PI / 180.0))
					_skeleton.set_bone_pose_rotation(right_shoulder_idx, q)

	# Auto-save player position & current scene path
	if not get_meta("en_modo_prueba", false) and (not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()):
		_autosave_timer += delta
		if _autosave_timer >= AUTOSAVE_INTERVAL:
			_autosave_timer = 0.0
			_guardar_posicion_rapida()

	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		global_position = global_position.lerp(_pos_objetivo, delta * 20.0)
		rotation.y = lerp_angle(rotation.y, _rot_y_objetivo, delta * 20.0)
		if anim_player and _anim_actual != "":
			anim_player.play(_anim_actual)
		return
	if _conduciendo:
		if _vehiculo_actual:
			_manterner_en_vehiculo(_vehiculo_actual)
			# Cambiado para salir usando la tecla ESC (ui_cancel) o el boton interactuar para evitar conflictos con S (freno)
			if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("interactuar"):
				_salir_del_vehiculo()
		return
	
	if _recien_bajado_timer > 0.0:
		_recien_bajado_timer -= delta
	
	_actualizar_boton_interactuar()
	_procesar_interaccion_vehiculo()
	
	var suelo = is_on_floor()
	var recien_aterrizado = _en_aire and suelo
	_en_aire = not suelo
	_coyote_timer = COYOTE_TIME if suelo else max(_coyote_timer - delta, 0)
	
	if _en_aire:
		velocity += get_gravity() * delta
		# Empuje constante "oculto" mientras el jugador gana altura en el aire
		if velocity.y > 0.1:
			var fwd_dir = Vector3(-sin(_camara_yaw), 0, -cos(_camara_yaw)).normalized()
			velocity += fwd_dir * (impulso_salto_fwd * 2.0 * delta)
	
	if _accion_just_pressed(["jump"]) and _coyote_timer > 0:
		_recien_bajado_timer = 0.0
		velocity.y = v_salto
		# Impulso para compensar animaciones con desplazamiento (Root Motion)
		var fwd_jump = Vector3(-sin(_camara_yaw), 0, -cos(_camara_yaw)).normalized()
		var impulso = fwd_jump * impulso_salto_fwd
		_vel_horizontal += impulso # Aplicamos a _vel_horizontal para que persista
		
		_coyote_timer = 0
		_en_aire = true
	
	var idir = _get_idir()
	var fwd = Vector3(-sin(_camara_yaw), 0, -cos(_camara_yaw))
	var side = Vector3(cos(_camara_yaw), 0, -sin(_camara_yaw))
	var dir = (side * idir.x + fwd * -idir.y).normalized()
	
	var run = (_accion_presionada(["run"]) or Input.is_key_pressed(KEY_SHIFT)) and idir.length() > 0.1 and not _agachado and not is_instance_valid(caja_agarrada)
	var v_obj = v_agachado if _agachado else (v_correr if run else v_caminar)
	var f_acc = control_aire if _en_aire else 1.0
	
	if _primera_persona:
		rotation.y = lerp_angle(rotation.y, _camara_yaw, delta * LERP_ROTACION_1P)
		_vel_horizontal = _vel_horizontal.lerp(dir * v_obj, delta * aceleracion * f_acc)
	elif dir.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * LERP_ROTACION)
		_vel_horizontal = _vel_horizontal.lerp(dir * v_obj, delta * aceleracion * f_acc)
	else:
		# Si estamos en el aire con impulso, reducimos drásticamente la fricción
		var friccion_aire = friccion * 0.05 if _en_aire else friccion
		_vel_horizontal = _vel_horizontal.lerp(Vector3.ZERO, delta * friccion_aire * f_acc)
	
	velocity.x = _vel_horizontal.x
	velocity.z = _vel_horizontal.z
	_agachado_t = lerp(_agachado_t, float(_agachado), delta * LERP_AGACHAR)
	_aplicar_camara(delta, idir, run)
	
	# Clamp de seguridad física anti-expulsión astronómica
	velocity.y = clampf(velocity.y, -45.0, 15.0)
	velocity.x = clampf(velocity.x, -25.0, 25.0)
	velocity.z = clampf(velocity.z, -25.0, 25.0)

	# Lógica para subir aceras/escalones
	if suelo and idir.length() > 0.1:
		move_and_slide()
		# Si colisionamos con una pared/acera horizontalmente estando en el suelo
		if is_on_wall():
			# Validar si el obstáculo es lo suficientemente bajo para subirlo (como un escalón o acera)
			# Lanzamos un rayo desde "altura_paso" (0.4m) hacia adelante. Si está libre, es un escalón.
			var espacio = get_world_3d().direct_space_state
			if espacio:
				var origen_rayo = global_position + Vector3(0.0, altura_paso + 0.05, 0.0)
				var destino_rayo = origen_rayo + dir * 0.75
				var query = PhysicsRayQueryParameters3D.create(origen_rayo, destino_rayo, 4294967295, [self])
				var result = espacio.intersect_ray(query)
				
				# Si el rayo no chocó con nada arriba, significa que el obstáculo es bajo
				if result.is_empty():
					velocity.y = v_salto * 0.65
					velocity.x = dir.x * v_obj
					velocity.z = dir.z * v_obj
					move_and_slide()
	else:
		move_and_slide()
		
	# Limitar velocidad resultante después de colisiones con cuerpos rígidos
	velocity.y = clampf(velocity.y, -45.0, 15.0)
	velocity.x = clampf(velocity.x, -25.0, 25.0)
	velocity.z = clampf(velocity.z, -25.0, 25.0)
		
	_anim_loco(idir, run, suelo)
	
	# Animación sutil y realista de salto/aterrizaje por código en los huesos del humanoide
	if is_instance_valid(_skeleton):
		if not suelo:
			# En el aire: Cadera baja levemente y la espalda se inclina al caer rápido
			_hips_offset_y = lerp(_hips_offset_y, clamp(-velocity.y * 0.015, -0.22, 0.05), delta * 8.0)
			_spine_rot_x = lerp(_spine_rot_x, clamp(-velocity.y * 0.018, -0.05, 0.15), delta * 6.0)
		else:
			# En el suelo:
			if recien_aterrizado:
				# Impacto de caída: bajar cadera (doblar rodillas) e inclinar columna adelante
				_hips_offset_y = -0.35
				_spine_rot_x = 0.28
			else:
				# Recuperar postura original de la animación
				_hips_offset_y = lerp(_hips_offset_y, 0.0, delta * 9.0)
				_spine_rot_x = lerp(_spine_rot_x, 0.0, delta * 9.0)
		
		# Aplicar modificaciones directamente en el esqueleto
		if _hips_bone_idx >= 0:
			var default_pos = _skeleton.get_bone_pose_position(_hips_bone_idx)
			default_pos.y += _hips_offset_y
			_skeleton.set_bone_pose_position(_hips_bone_idx, default_pos)
			
		if _spine_bone_idx >= 0:
			var default_rot = _skeleton.get_bone_pose_rotation(_spine_bone_idx)
			var tilt_offset = Quaternion(Vector3.RIGHT, _spine_rot_x)
			_skeleton.set_bone_pose_rotation(_spine_bone_idx, default_rot * tilt_offset)
			
	# Asegurar escala e inclinación base del modelo limpias
	if is_instance_valid(_modelo):
		_modelo.scale = Vector3.ONE
		_modelo.rotation.x = 0.0
	
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		actualizar_transform_remoto.rpc(global_position, rotation.y, velocity, _anim_actual, _conduciendo)

func _anim_loco(idir, run, suelo):
	if _anim_lock: return
	
	# Si acaba de bajarse, evitar animaciones de caída/salto durante el tiempo de seguridad
	if _recien_bajado_timer > 0.0:
		if idir.length() > 0.1:
			_reproducir_anim(ANIM_CORRER if run else ANIM_CAMINAR)
		else:
			_reproducir_anim(ANIM_IDLE)
		return
			
	if not suelo:
		# En el aire dejamos correr o caminar para que la transición sea fluida
		if idir.length() > 0.1:
			_reproducir_anim(ANIM_CORRER if run else ANIM_CAMINAR)
		else:
			_reproducir_anim(ANIM_IDLE)
	elif idir.length() > 0.1:
		_reproducir_anim(ANIM_CORRER if run else ANIM_CAMINAR)
	else:
		_reproducir_anim(ANIM_IDLE)

func _aplicar_camara(delta, idir, run):
	if not spring_arm: return
	
	if not _en_aire and velocity.length() > 0.5:
		_bob_tiempo += delta * (BOB_FREQ_CORRER if run else BOB_FREQ_CAMINAR) * TAU
		_bob_offset = Vector3(cos(_bob_tiempo*0.5)*BOB_AMP_X, sin(_bob_tiempo)*BOB_AMP_Y, 0)
	else:
		_bob_offset = _bob_offset.lerp(Vector3.ZERO, delta * 5)
	
	_shake_mag = move_toward(_shake_mag, 0, delta)
	var s = Vector3(randf_range(-1,1), randf_range(-1,1), 0) * _shake_mag
	var lean_axis := Input.get_axis("inclin-izq", "inclin-der")
	_camara_tilt = lerp(_camara_tilt, -lean_axis * 0.22 - idir.x * TILT_MAX * (1.5 if run else 1.0), delta * TILT_LERP)
	var off_h = _bob_offset.x + s.x + lean_axis * 0.38
	var off_v = _bob_offset.y + s.y
	
	if _camera:
		_camera.h_offset = off_h
		_camera.v_offset = off_v
	if _camara_1p:
		_camara_1p.h_offset = off_h
		_camara_1p.v_offset = off_v

	# FOV Dinámico suave al caminar y correr (sprint)
	var target_fov: float = fov_base + (fov_sprint_boost if (run and velocity.length() > 2.0) else 0.0)
	var cam_activa: Camera3D = get_camara_activa()
	if is_instance_valid(cam_activa):
		var nuevo_fov: float = lerpf(cam_activa.fov, target_fov, delta * 5.0)
		cam_activa.fov = nuevo_fov
		if _camera and _camera != cam_activa:
			_camera.fov = nuevo_fov
		if _camara_1p and _camara_1p != cam_activa:
			_camara_1p.fov = nuevo_fov

	if _primera_persona:
		spring_arm.rotation.y = clamp(wrapf(_camara_yaw - rotation.y, -PI, PI), -YAW_1P_MAX, YAW_1P_MAX)
		spring_arm.rotation.x = _camara_pitch
		spring_arm.rotation.z = _camara_tilt
		spring_arm.spring_length = ZOOM_1P
		var fwd = Vector3(-sin(_camara_yaw), 0, -cos(_camara_yaw))
		if _skeleton and _cabeza_bone_idx >= 0:
			spring_arm.global_position = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_cabeza_bone_idx)).origin + fwd * CAM_1P_FORWARD
		else:
			spring_arm.position = CAM_1P_OFFSET + fwd * CAM_1P_FORWARD - Vector3(0.0, _agachado_t * 0.5, 0.0)
		if _camara_1p and _camera:
			_camara_1p.global_transform = _camera.global_transform
		if _cabeza:
			_cabeza.visible = false
		if is_instance_valid(caja_agarrada) and not caja_agarrada.name.to_lower().contains("tableta"):
			if _modelo and not _modelo.visible:
				_modelo.show()
	else:
		if _cabeza:
			_cabeza.visible = true
		spring_arm.rotation = Vector3(_camara_pitch, _camara_yaw - rotation.y, _camara_tilt)
		
		# Solo centrar la cámara si el jugador está rotando hacia la dirección de movimiento
		# El bug ocurría porque _camara_yaw intentaba alinearse con rotation.y infinitamente
		if Vector2(velocity.x, velocity.z).length() > 0.5 and idir.length() > 0.1:
			_auto_center_timer += delta
			if _auto_center_timer >= AUTO_CENTER_DELAY:
				# Suavizamos el centrado para evitar giros bruscos
				_camara_yaw = lerp_angle(_camara_yaw, rotation.y + PI, delta * AUTO_CENTER_LERP)
		else:
			_auto_center_timer = 0.0

func _set_agachado(v):
	if v == _agachado: return
	_agachado = v
	if _agachado:
		_reproducir_anim(ANIM_AGACHARSE)
	else:
		if anim_player and anim_player.has_animation(ANIM_AGACHARSE):
			_reproduciendo_agachado_reverso = true
			_anim_lock = true
			anim_player.play(ANIM_AGACHARSE, -1, -1, true)

func _set_primera_persona(v):
	# Modo primera persona obligatorio a pie: sin modelo 3D bloqueando la vista
	_primera_persona = true
	if spring_arm:
		_zoom_guardado = spring_arm.spring_length
	var cam_activa: Camera3D = get_camara_activa()
	if is_instance_valid(cam_activa):
		cam_activa.fov = fov_base
		cam_activa.make_current()
	if _camera:
		_camera.fov = fov_base
	if _camara_1p:
		_camara_1p.fov = fov_base
	if _cabeza:
		_cabeza.visible = false
	if _modelo and not _conduciendo and not is_instance_valid(caja_agarrada):
		_modelo.hide()
	if _vigneta_layer:
		_vigneta_layer.hide()

func _subir_al_vehiculo(v):
	_conduciendo = true
	_vehiculo_actual = v
	_asiento_cache = v.find_child("AsientoConductor", true, false)
	velocity = Vector3.ZERO
	if item_en_mano_ctrl:
		item_en_mano_ctrl.visible = false
	if tienda_ui and tienda_ui.visible:
		tienda_ui.cerrar_tienda(false)
	if _collision_shape: _collision_shape.disabled = true
	
	ocultar_interfaz_pie()
	
	if _modelo and ocultar_modelo_conduciendo: _modelo.hide()
	_reproducir_anim(ANIM_CONDUCIR)
	if v.has_method("subir_jugador"): v.subir_jugador(self)

func _salir_del_vehiculo():
	if not _vehiculo_actual: return
	var v = _vehiculo_actual
	_conduciendo = false
	_vehiculo_actual = null
	_asiento_cache = null
	_set_primera_persona(true)
	
	mostrar_interfaz_pie()
	var cam_activa: Camera3D = get_camara_activa()
	if item_en_mano_ctrl:
		item_en_mano_ctrl.visible = true
		if is_instance_valid(cam_activa):
			item_en_mano_ctrl.vincular_jugador(self, cam_activa)
			
	if v.has_method("bajar_jugador"): v.bajar_jugador()
	if _collision_shape: _collision_shape.disabled = false
	_recien_bajado_timer = 1.0 # Previene animaciones de caída/salto temporalmente (tiempo de seguridad)
	_reproducir_anim(ANIM_IDLE)

func salir_del_vehiculo():
	_salir_del_vehiculo()

## Llamado por GestorVehiculos al descender del vehiculo para restaurar la camara 1P limpia
func restaurar_camara_salida_vehiculo() -> void:
	_conduciendo = false
	_vehiculo_actual = null
	_asiento_cache = null
	_set_primera_persona(true)
	var cam_activa: Camera3D = get_camara_activa()
	if is_instance_valid(cam_activa):
		cam_activa.fov = fov_base
		cam_activa.make_current()
	mostrar_interfaz_pie()
	if item_en_mano_ctrl:
		item_en_mano_ctrl.visible = true
		if is_instance_valid(cam_activa):
			item_en_mano_ctrl.vincular_jugador(self, cam_activa)

func equipar_item_en_mano(item_id: String) -> void:
	if not item_en_mano_ctrl:
		item_en_mano_ctrl = ControladorItemEnMano.new()
		item_en_mano_ctrl.name = "ControladorItemEnMano"
		add_child(item_en_mano_ctrl)
	var cam_activa: Camera3D = get_camara_activa()
	if cam_activa:
		item_en_mano_ctrl.vincular_jugador(self, cam_activa)
	item_en_mano_ctrl.equipar_item(item_id)

func desequipar_item_en_mano() -> void:
	if item_en_mano_ctrl:
		item_en_mano_ctrl.desequipar_item(true)

func abrir_tienda() -> void:
	if tienda_ui:
		tienda_ui.abrir_tienda(self)

func ocultar_interfaz_pie() -> void:
	if is_instance_valid(ui_pie):
		ui_pie.visible = false
		ui_pie.process_mode = Node.PROCESS_MODE_DISABLED
		var walk_controls = ui_pie.get_node_or_null("Controles")
		if walk_controls:
			walk_controls.visible = false

	var tree := get_tree()
	if tree and tree.get_root():
		for pat in ["*UIpie*", "*UiPie*", "*uipie*", "*UIPie*"]:
			var encontrados = tree.get_root().find_children(pat, "", true, false)
			for n in encontrados:
				if is_instance_valid(n) and (n is CanvasLayer or n is Control):
					n.visible = false
					n.process_mode = Node.PROCESS_MODE_DISABLED
					var c = n.get_node_or_null("Controles")
					if c:
						c.visible = false

func mostrar_interfaz_pie() -> void:
	if is_instance_valid(ui_pie):
		ui_pie.process_mode = Node.PROCESS_MODE_INHERIT
		ui_pie.visible = true
		var walk_controls = ui_pie.get_node_or_null("Controles")
		if walk_controls:
			walk_controls.visible = true

	var tree := get_tree()
	if tree and tree.get_root():
		for pat in ["*UIpie*", "*UiPie*", "*uipie*", "*UIPie*"]:
			var encontrados = tree.get_root().find_children(pat, "", true, false)
			for n in encontrados:
				if is_instance_valid(n) and (n is CanvasLayer or n is Control):
					n.process_mode = Node.PROCESS_MODE_INHERIT
					n.visible = true
					var c = n.get_node_or_null("Controles")
					if c:
						c.visible = true

func guardar_progreso_conductor() -> void:
	# Guardado robusto: construir un diccionario de datos y usar la API pública del plugin cuando sea posible.
	var datos = get_node_or_null("/root/DatosUsuario")
	var doc_id: String = ""
	var auth_node = null
	var tree = get_tree()
	if tree:
		var current = tree.current_scene
		var firebase_node = null
		if current:
			firebase_node = _recursive_find_by_name(current, "Firebase")
			if firebase_node:
				auth_node = _recursive_find_by_name(firebase_node, "Auth")
			else:
				auth_node = _recursive_find_by_name(current, "Auth")

		if not auth_node:
			var root = tree.get_root()
			firebase_node = _recursive_find_by_name(root, "Firebase")
			if firebase_node:
				auth_node = _recursive_find_by_name(firebase_node, "Auth")
			else:
				auth_node = _recursive_find_by_name(root, "Auth")

	if auth_node and auth_node.has_method("is_signed_in") and auth_node.is_signed_in():
		var user_data = null
		if auth_node.has_method("get_current_user_data"):
			user_data = auth_node.get_current_user_data()
		if typeof(user_data) == TYPE_DICTIONARY:
			doc_id = str(user_data.get("id", user_data.get("uid", "")))
		else:
			# Fallback: si el objeto devuelve otra estructura, intentar string
			doc_id = str(user_data)
	else:
		# No hay sesión: guardar localmente y salir
		print("guardar_progreso_conductor: usuario no autenticado. Guardando localmente en vez de Firestore.")
		if datos and datos.has_method("guardar_progreso"):
			datos.guardar_progreso()
		elif datos and datos.has_method("save_local"):
			datos.save_local()
		return

	# Construir el diccionario de datos a enviar
	var doc_map = {}
	doc_map["dinero"] = datos.dinero if datos else 0
	doc_map["nombre_usuario"] = datos.nombre_usuario if datos else ""
	doc_map["vehiculo_actual"] = str(_vehiculo_actual.name) if _vehiculo_actual else ""
	doc_map["region_desbloqueada"] = "Fusagasugá"

	# Intentar enviar usando la API expuesta por 'firestore' (autoload o plugin)
	if firestore:
		# API más común: set_document(collection, id, data)
		if firestore.has_method("set_document"):
			firestore.set_document("conductores", doc_id, doc_map)
		elif firestore.has_method("firestoreSetDocument"):
			firestore.firestoreSetDocument("conductores", doc_id, doc_map)
		elif firestore.has_method("setDocument"):
			firestore.setDocument("conductores", doc_id, doc_map)
		elif firestore.has_method("add_document"):
			# add_document suele recibir (collection, data)
			firestore.add_document("conductores", doc_map)
		else:
			print("guardar_progreso_conductor: API de Firestore no reconocida en el nodo 'firestore'.")
		print("guardar_progreso_conductor: enviado a Firestore")
	else:
		print("guardar_progreso_conductor: Firestore no disponible — guardando localmente")
		if datos and datos.has_method("guardar_progreso"):
			datos.guardar_progreso()
		elif datos and datos.has_method("save_local"):
			datos.save_local()


func _on_document_written(_resultado) -> void:
	print("Progreso guardado correctamente en la nube.")
	# Backup local
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and datos.has_method("save_local"):
		datos.save_local()


func _on_document_write_failed(error) -> void:
	printerr("Error al guardar progreso en Firestore:", error)
	# Fallback a guardado local
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and datos.has_method("save_local"):
		datos.save_local()

func _procesar_interaccion_vehiculo():
	if _vehiculo_cerca and not _conduciendo:
		if _accion_just_pressed(["interactuar"]): # Cambiado a la acción definida en project.godot
			_subir_al_vehiculo(_vehiculo_cerca)

func puede_interactuar() -> bool:
	if _conduciendo:
		return false
	if is_instance_valid(_vehiculo_cerca):
		return true
	for v in get_tree().get_nodes_in_group("vehiculo"):
		if v and v.get("jugador_cerca") == true:
			_vehiculo_cerca = v
			return true
	return false

func interactuar_contextual() -> void:
	if _conduciendo:
		_salir_del_vehiculo()
		return
	if not is_instance_valid(_vehiculo_cerca):
		for v in get_tree().get_nodes_in_group("vehiculo"):
			if v and v.get("jugador_cerca") == true:
				_vehiculo_cerca = v
				break
	if is_instance_valid(_vehiculo_cerca):
		_subir_al_vehiculo(_vehiculo_cerca)

func ejecutar_salto_tactil(fuerza_v: float, impulso_h: Vector3 = Vector3.ZERO) -> void:
	if _conduciendo:
		return
	if is_on_floor() or _coyote_timer > 0.0:
		_recien_bajado_timer = 0.0
		velocity.y = maxf(fuerza_v, v_salto)
		var fwd_jump := Vector3(-sin(_camara_yaw), 0.0, -cos(_camara_yaw)).normalized()
		var side_jump := Vector3(cos(_camara_yaw), 0.0, -sin(_camara_yaw)).normalized()
		if impulso_h.length() > 0.05:
			_vel_horizontal += (side_jump * impulso_h.x + fwd_jump * -impulso_h.z)
		else:
			_vel_horizontal += fwd_jump * impulso_salto_fwd
		_coyote_timer = 0.0
		_en_aire = true
		if _agachado:
			_set_agachado(false)

func alternar_linterna_jugador(estado: Variant = null) -> bool:
	var luz := find_child("LinternaJugador", true, false) as SpotLight3D
	if not luz and _camera:
		luz = SpotLight3D.new()
		luz.name = "LinternaJugador"
		luz.light_energy = 2.8
		luz.spot_range = 28.0
		luz.spot_angle = 38.0
		luz.shadow_enabled = false
		luz.visible = false
		_camera.add_child(luz)
	if not luz:
		return false
	if estado is bool:
		luz.visible = estado
	else:
		luz.visible = not luz.visible
	return luz.visible

func ajustar_fov_suave(nuevo_fov: float) -> void:
	var fov_clamped := clampf(nuevo_fov, 45.0, 95.0)
	fov_base = fov_clamped
	var cam_activa: Camera3D = get_camara_activa()
	if is_instance_valid(cam_activa):
		var tw: Tween = create_tween()
		tw.tween_property(cam_activa, "fov", fov_clamped, 0.2)
		if _camera and _camera != cam_activa:
			_camera.fov = fov_clamped
		if _camara_1p and _camara_1p != cam_activa:
			_camara_1p.fov = fov_clamped

func saludar() -> void:
	if _conduciendo or _anim_lock:
		return
	if anim_player:
		for candidate in ["Saludar", "saludar", "Wave", "wave"]:
			if anim_player.has_animation(candidate):
				anim_player.play(candidate, BLEND_OTROS)
				return

func _on_camara_pinch(delta_dist: float) -> void:
	if _conduciendo:
		return
	_ajustar_zoom(-delta_dist * 0.01)

func _actualizar_boton_interactuar():
	if _ui_boton_interactuar:
		_ui_boton_interactuar.visible = puede_interactuar()

func _on_boton_entrar_pressed():
	interactuar_contextual()

func _on_zona_entrada_body_entered(b, veh = null):
	# Handler flexible: puede recibir (body) o (body, veh) cuando se conecta con bind
	# Si recibimos el vehículo por bind, úsalo directamente (no dependemos de grupos)
	if veh != null and veh is Node:
		if debug_interaction:
			print("_on_zona_entrada_body_entered: bound veh ->", veh.get_path())
		_vehiculo_cerca = veh
		return
	# Si no hay bind, intentar inferirlo desde el body entrante
	if b and b is Node and b.is_in_group("vehiculo"):
		_vehiculo_cerca = b

func _on_zona_entrada_body_exited(b, veh = null):
	if veh != null and veh is Node:
		if _vehiculo_cerca == veh:
			_vehiculo_cerca = null
		return
	if b == _vehiculo_cerca:
		_vehiculo_cerca = null

# Métodos que coche.gd llama cuando el jugador entra/sale de la zona de un vehículo
func notificar_vehiculo_cerca(veh: Node3D) -> void:
	_vehiculo_cerca = veh

func notificar_vehiculo_lejos(veh: Node3D = null) -> void:
	if veh == null or _vehiculo_cerca == veh:
		_vehiculo_cerca = null


func _on_animation_finished(n):
	if n == ANIM_AGACHARSE and _reproduciendo_agachado_reverso:
		_reproduciendo_agachado_reverso = false
		_anim_lock = false

func _manterner_en_vehiculo(v):
	if _asiento_cache:
		global_transform = _asiento_cache.global_transform
		translate_object_local(asiento_offset_pos)
		rotate_object_local(Vector3.UP, deg_to_rad(asiento_offset_rot.y))
	else:
		global_position = v.global_position + Vector3.UP * 1.5

func _reproducir_anim(n, b = BLEND_LOCOMOCION):
	if anim_player and not _anim_lock and _anim_actual != n and anim_player.has_animation(n):
		anim_player.play(n, b)
		_anim_actual = n

func _get_idir():
	# Preferir la API nueva del UIPie
	if ui_pie and ui_pie.has_method("get_joystick_direction"):
		var d = ui_pie.get_joystick_direction()
		if d is Vector2 and d.length() > 0.1: return d.limit_length(1)
	if _ui_joystick:
		var d = _ui_joystick.get("direccion")
		if d is Vector2 and d.length() > 0.1: return d.limit_length(1)
	
	if not permitir_teclado_movimiento: return Vector2.ZERO
	
	# Usar estrictamente las acciones del Input Map del proyecto
	var x = Input.get_axis("izquierda", "derecha")
	var y = Input.get_axis("acelerar", "frenar")
	
	return Vector2(x, y).limit_length(1.0)

func _buscar_nodo_tipo(n, t):
	for h in n.get_children():
		if h.get_class() == t: return h
		var r = _buscar_nodo_tipo(h, t)
		if r: return r
	return null

func _find_closest_camera():
	var r = get_tree().current_scene if get_tree() else self
	var c = []
	_coll_c(r, c)
	if c.is_empty(): return null
	c.sort_custom(func(a,b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	return c[0]

func _coll_c(n, a):
	for h in n.get_children():
		if h is Camera3D: a.append(h)
		_coll_c(h, a)

func _manejar_camara_tactil(r):
	if has_meta("cinematic_active") and get_meta("cinematic_active"):
		return
	var s = SENSIBILIDAD_1P if _primera_persona else sensibilidad_raton
	_camara_yaw -= r.x * s
	_camara_pitch = clamp(_camara_pitch - r.y * s, PITCH_MIN, PITCH_MAX)
	_auto_center_timer = 0

func _ajustar_zoom(d):
	# Desactivado zoom hacia 3ra persona a pie
	return

func _crear_vigneta():
	# Filtro oscuro plano eliminado por completo para máxima nitidez y pureza de imagen
	if is_instance_valid(_vigneta_layer):
		_vigneta_layer.queue_free()
		_vigneta_layer = null

func _accion_just_pressed(a):
	for x in a:
		if Input.is_action_just_pressed(x): return true
	return false

func _accion_presionada(a):
	for x in a:
		if Input.is_action_pressed(x): return true
	return false

func _accion_event(e, a):
	for x in a:
		if e.is_action_pressed(x): return true
	return false


func _connect_zonas_entrada():
	var scene_root = get_tree().get_current_scene() if get_tree().has_method("get_current_scene") else null
	if not scene_root:
		if debug_interaction:
			print("_connect_zonas_entrada: no current_scene")
		return
	var zonas = []
	_collect_zona_areas(scene_root, zonas)
	if debug_interaction:
		print("_connect_zonas_entrada: found %d ZonaEntrada(s)" % zonas.size())
	for area in zonas:
		if not area:
			continue
		var apath = str(area.get_path()) if area.has_method("get_path") else str(area.name)
		if debug_interaction:
			print("_connect_zonas_entrada: area:", apath)
		# evitar múltiples conexiones
		if area.has_meta("conectado_a_jugador") and area.get_meta("conectado_a_jugador"):
			if debug_interaction:
				print("_connect_zonas_entrada: already connected:", apath)
			continue
		var veh = _find_rigidbody_from_node(area)
		if debug_interaction:
			print("_connect_zonas_entrada: vehicle for area %s -> %s" % [apath, str(veh.get_path()) if veh else "<NULL>"])
		# Godot 4: usar signal.connect(callable.bind(arg))
		area.body_entered.connect(_on_zona_entrada_body_entered.bind(veh))
		area.body_exited.connect(_on_zona_entrada_body_exited.bind(veh))
		area.set_meta("conectado_a_jugador", true)
		if debug_interaction:
			print("_connect_zonas_entrada: connected", apath)


func _collect_zona_areas(node: Node, out_arr: Array) -> void:
	for c in node.get_children():
		if c is Area3D and c.name == "ZonaEntrada":
			out_arr.append(c)
		_collect_zona_areas(c, out_arr)


func _on_node_added(node: Node) -> void:
	if not node:
		return

	# Conectar automáticamente zonas de cámara o UI que se instancien tarde
	var cb_cam = Callable(self, "_manejar_camara_tactil")
	if (node is CanvasLayer or node is Control) and node.has_signal("camara_movida"):
		if not node.is_connected("camara_movida", cb_cam):
			node.connect("camara_movida", cb_cam)
			_zona_camara_activa = true
			if debug_interaction:
				print("jugador3D: conectado camara_movida a", node.get_path())
	elif node.is_in_group("zona_camara"):
		if node.has_signal("camara_movida") and not node.is_connected("camara_movida", cb_cam):
			node.connect("camara_movida", cb_cam)
			_zona_camara_activa = true

	# Si el nodo expone pellizco y el jugador tiene handler, conectarlo
	if node.has_signal("camara_pinch") and has_method("_on_camara_pinch"):
		var cb_pinch = Callable(self, "_on_camara_pinch")
		if not node.is_connected("camara_pinch", cb_pinch):
			node.connect("camara_pinch", cb_pinch)

	if node is Area3D and node.name == "ZonaEntrada":
		var apath = str(node.get_path()) if node.has_method("get_path") else str(node.name)
		if debug_interaction:
			print("_on_node_added: ZonaEntrada added:", apath)
		if node.has_meta("conectado_a_jugador") and node.get_meta("conectado_a_jugador"):
			if debug_interaction:
				print("_on_node_added: already connected:", apath)
			return
		var veh = _find_rigidbody_from_node(node)
		if debug_interaction:
			print("_on_node_added: vehicle bind ->", str(veh.get_path()) if veh else "<NULL>")
		node.body_entered.connect(_on_zona_entrada_body_entered.bind(veh))
		node.body_exited.connect(_on_zona_entrada_body_exited.bind(veh))
		node.set_meta("conectado_a_jugador", true)
		if debug_interaction:
			print("_on_node_added: connected", apath)


func _find_rigidbody_from_node(node: Node) -> Node:
	var n = node.get_parent()
	while n:
		if n is RigidBody3D:
			return n
		n = n.get_parent()
	return null

func _screen_log(txt: String) -> void:
	print(txt)
	var mgr = get_node_or_null("/root/Main/MultiplayerManager")
	if mgr and mgr.has_method("_print_on_screen"):
		mgr._print_on_screen(txt)

@rpc("any_peer", "unreliable")
func actualizar_transform_remoto(pos: Vector3, rot_y: float, vel: Vector3, anim: String, cond: bool) -> void:
	if not is_multiplayer_authority():
		_pos_objetivo = pos
		_rot_y_objetivo = rot_y
		velocity = vel
		_anim_actual = anim
		_conduciendo = cond

func _guardar_posicion_rapida() -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		var pos = global_position
		var rot_y = rotation.y
		if _conduciendo and _vehiculo_actual:
			pos = _vehiculo_actual.global_position
			rot_y = _vehiculo_actual.rotation.y
		datos.guardado_player_pos = pos
		datos.guardado_player_rot_y = rot_y
		var current_scene_path = get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else ""
		datos.guardado_player_scene = current_scene_path
		datos.save_local()

func agarrar_caja(caja: Node3D):
	if not caja:
		return
		
	var es_tableta = caja.name.to_lower().contains("tableta")
	
	# Si es una caja común, intentamos agregarla al inventario
	if not es_tableta and inventario:
		var agregado = inventario.call("agregar_item", caja.name, caja)
		if agregado:
			# Ocultar del mundo y deshabilitar colisiones
			if caja.get_parent():
				caja.get_parent().remove_child(caja)
			add_child(caja)
			caja.visible = false
			var col = caja.get_node_or_null("CollisionShape3D")
			if not col:
				col = caja.find_child("CollisionShape3D", true, false)
			if col and col is CollisionShape3D:
				col.disabled = true
			if caja is RigidBody3D:
				caja.freeze = true
			print("[jugador3D] Caja agregada directamente al inventario de mochila.")
			return
			
	if is_instance_valid(caja_agarrada):
		push_warning("[Jugador3D] Ya tienes un objeto en las manos!")
		return
		
	caja_agarrada = caja
	
	# Desactivar física si es un RigidBody3D o similar
	if caja is RigidBody3D:
		caja.freeze = true
		
	# Desactivar colisiones de la caja para que no empuje físicamente al jugador
	var col = caja.get_node_or_null("CollisionShape3D")
	if not col:
		col = caja.find_child("CollisionShape3D", true, false)
	if col and col is CollisionShape3D:
		col.disabled = true
	
	# Cambiar padre de la caja al jugador
	if caja.get_parent():
		caja.get_parent().remove_child(caja)
	add_child(caja)
	
	# Posición delantera relativa al jugador (según exports)
	caja.position = caja_offset_pos
	caja.rotation_degrees = caja_offset_rot
	
	# Asignar Marker3D de la caja a los SkeletonIK3D con offsets de inspector
	var marker_izq = caja.get_node_or_null("SoporteManoIzquierda")
	var marker_der = caja.get_node_or_null("SoporteManoDerecha")
	
	if marker_izq:
		_mano_izq_base_rot = marker_izq.rotation_degrees
		marker_izq.position = Vector3(-0.2905, 0.065, 0.035) + mano_izq_offset_pos
		marker_izq.rotation_degrees = _mano_izq_base_rot + mano_izq_offset_rot
		
	if marker_der:
		_mano_der_base_rot = marker_der.rotation_degrees
		marker_der.position = Vector3(0.2035, 0.065, 0.035) + mano_der_offset_pos
		marker_der.rotation_degrees = _mano_der_base_rot + mano_der_offset_rot
		
	if mano_izq_ik and marker_izq:
		mano_izq_ik.target_node = marker_izq.get_path()
		mano_izq_ik.start()
		
	if mano_der_ik and marker_der:
		mano_der_ik.target_node = marker_der.get_path()
		mano_der_ik.start()

func soltar_caja() -> Node3D:
	if not caja_agarrada:
		return null
	if caja_agarrada.name.to_lower().contains("tableta"):
		return null # No se permite soltar la tableta en zonas de cajas
		
	# Apagar los IK
	if mano_izq_ik:
		mano_izq_ik.stop()
	if mano_der_ik:
		mano_der_ik.stop()
		
	var caja = caja_agarrada
	caja_agarrada = null
	
	# Re-activar colisiones antes de soltarla
	var col = caja.get_node_or_null("CollisionShape3D")
	if not col:
		col = caja.find_child("CollisionShape3D", true, false)
	if col and col is CollisionShape3D:
		col.disabled = false
		
	# Remover del jugador y devolver a la escena
	remove_child(caja)
	get_tree().current_scene.add_child(caja)
	caja.global_position = global_position - global_transform.basis.z * 1.0
	
	if caja is RigidBody3D:
		caja.freeze = false
		
	return caja
