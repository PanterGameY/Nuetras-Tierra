# ui_vehiculo.gd
extends CanvasLayer

@export var vehiculo_path: NodePath

# --- VARIABLES DE ESTADO ---
var _iv_cache: Node = null
var _gv_cache: Node = null

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

func _get_gv() -> Node:
	if is_instance_valid(_gv_cache):
		return _gv_cache
	if is_inside_tree():
		_gv_cache = get_node_or_null("/root/GestorVehiculos")
	return _gv_cache

var vehiculo: RigidBody3D
var _motor_ref: Node
const COOLDOWN_CAMARA_MS: int = 180
var _ultimo_cambio_camara_ms: int = -10000
var _motor_activo: bool = false
var _freno_mano_activo: bool = false
var _baul_abierto: bool = false
var _menu_desplegado: bool = false
var _ultimo_toggle_menu_ms: int = 0
const COOLDOWN_MENU_MS: int = 400
var _anim_player_baul: AnimationPlayer
var _audio_motor_baul: AudioStreamPlayer3D

# --- NODOS DE UI ---
@onready var label_marcha     = find_child("DisplayMarcha", true, false)
@onready var boton_motor      = (find_child("BtnEncender", true, false) if find_child("BtnEncender", true, false) else find_child("BotonMotor", true, false)) as Button
@onready var btn_delante      = find_child("BtnDelante", true, false) as Button
@onready var btn_neutro       = find_child("BtnNeutro", true, false) as Button
@onready var btn_reversa      = find_child("BtnReversa", true, false) as Button
@onready var boton_freno_motor = find_child("BtnFrenoMotor", true, false) as Button
@onready var boton_freno_mano = find_child("BotonFrenoMano", true, false) as Button
@onready var boton_baul       = find_child("BotonBaul", true, false) as Button
@onready var boton_salir      = find_child("BotonSalir", true, false) as Button
@onready var boton_camara     = find_child("BotonCamara", true, false) as Button
@onready var boton_dir_izq    = find_child("BtnDir_izq", true, false) as Button
@onready var boton_dir_der    = find_child("BtnDir_der", true, false) as Button
@onready var boton_bocina     = find_child("Bocina", true, false) as Button
@onready var boton_emergencia = find_child("BtnEmergencia", true, false) as Button
@onready var boton_luces      = find_child("BtnLuces", true, false) as Button
@onready var boton_crucero    = find_child("BtnCrucero", true, false) as Button
@onready var boton_plumillas  = find_child("BtnLimpiabrisas", true, false) as Button
@onready var boton_remolque   = find_child("BtnDesengancharCabina", true, false) as Button
@onready var boton_diferencial = find_child("BtnDiferencial", true, false) as Button
@onready var boton_toggle_gps  = find_child("BtnToggleGPS", true, false) as Button
@onready var boton_cerrar_menu = find_child("BtnCerrarMenu", true, false) as Button
@onready var testigo_motor     = find_child("TestigoMotor", true, false) as Label
@onready var testigo_fmano     = find_child("TestigoFrenoMano", true, false) as Label
@onready var testigo_crucero   = find_child("TestigoCrucero", true, false) as Label
@onready var testigo_luces     = find_child("TestigoLuces", true, false) as Label

var _crucero_activo: bool = false
var _vel_crucero_kmh: float = 0.0
var _luces_activas: bool = true
var _emergencia_activa: bool = false
var _plumillas_activas: bool = false
var _diferencial_activo: bool = false
var _gps_visible: bool = true


# --- REFERENCIA A DIRECCIONALES DEL VEHÍCULO ---
var _direccionales: Node = null
var _bocina_ref: Node = null

# --- OPACIDAD Y MODO CINE / GRABACIÓN ---
const OPACIDAD_PRESETS: Array[float] = [1.0, 0.50, 0.20, 0.0]
var _indice_preset_opacidad: int = 0
var _opacidad_actual: float = 1.0
var _tiempo_presion_ocultar_ms: int = 0
var _tween_opacidad: Tween = null
var _tween_toast: Tween = null

@onready var boton_ocultar_hud: Button        = find_child("BotonOcultarHUD", true, false) as Button
@onready var boton_restaurar_hud: Button      = find_child("BotonRestaurarHUD", true, false) as Button
@onready var panel_opacidad_hud: Control      = find_child("PanelOpacidadHUD", true, false) as Control
@onready var slider_opacidad: HSlider         = find_child("SliderOpacidadHUD", true, false) as HSlider
@onready var label_porcentaje_opacidad: Label = find_child("LabelPorcentajeOpacidad", true, false) as Label
@onready var label_toast_hud: Label           = find_child("LabelToastHUD", true, false) as Label

# Menú desplegable
@onready var tab_menu         = find_child("TabMenu", true, false)
@onready var panel_contenido  = find_child("PanelContenido", true, false)

# Nuevo selector de marchas con 4 botones
@onready var selector_marchas = find_child("PanelMarchas", true, false)
@onready var boton_centrar    = find_child("BotonCentrar", true, false)
@onready var volante_control  = find_child("Volante", true, false)
@onready var zona_direccion: Control = find_child("ZonaDireccion", true, false) as Control
@onready var zona_pedales: Control   = find_child("ZonaPedales", true, false) as Control

# Shader para botones
@export var color_boton_activo: Color = Color.YELLOW
@export var color_boton_inactivo: Color = Color.WHITE
@export var brillo_boton_activo: float = 1.4

# Configuración del menú desplegable
@export var duracion_animacion: float = 0.25

# Velocímetro
@export var velocidad_maxima: float = 180.0
@export var rpm_maxima: float = 3200.0
@onready var _velo_rect:    ColorRect   = find_child("VeloRect", true, false) as ColorRect
@onready var _label_vel:    Label       = find_child("LabelVel", true, false) as Label
@onready var _label_rpm:    Label       = find_child("LabelRPM", true, false) as Label
@onready var _bar_rpm:      ProgressBar = find_child("ProgressBarRPM", true, false) as ProgressBar
@onready var _bar_gas:      ProgressBar = find_child("ProgressBarGas", true, false) as ProgressBar
@onready var _label_gas:    Label       = find_child("LabelGas", true, false) as Label

# Medidor de combustible
@onready var _comb_rect:   ColorRect = find_child("FuelBarRect", true, false) as ColorRect

# GPS HUD
@onready var _panel_gps:     PanelContainer = find_child("PanelGPSHUD", true, false) as PanelContainer
@onready var _gps_viewport:  SubViewport    = find_child("SubViewport_GPS", true, false) as SubViewport
@onready var _gps_camera:    Camera3D       = find_child("CameraGPSHUD", true, false) as Camera3D
@onready var _icono_veh_gps: Label          = find_child("IconoVehiculo", true, false) as Label
var _linea_gps_hud: Line2D                  = null
var _cel_ui_ref: Node                       = null

# ════════════════════════════════════════════════════════════════════
#  INICIALIZACIÓN
# ════════════════════════════════════════════════════════════════════

func _ready() -> void:
	self.visible = false
	visibility_changed.connect(_on_visibility_changed)

	# Localizar el vehículo
	if vehiculo_path and not vehiculo_path.is_empty():
		vehiculo = get_node(vehiculo_path)
	elif get_parent() is RigidBody3D:
		vehiculo = get_parent()

	if vehiculo:
		_motor_ref = vehiculo.get_node_or_null("Motor")
		if not _motor_ref:
			push_warning("UIVehiculo: No se encontró el nodo 'Motor' en el vehículo.")
		_anim_player_baul = vehiculo.get_node_or_null("AnimationPlayer") as AnimationPlayer
		_audio_motor_baul = vehiculo.get_node_or_null("Motor_encendido_baul") as AudioStreamPlayer3D

	# Aplicar shader a los botones
	_aplicar_shader_botones()
	_sincronizar_estado_motor()
	_configurar_gps_hud_inicial()

	# Conectar controles táctiles/click
	if boton_camara:
		if not boton_camara.pressed.is_connected(_on_cambiar_camara):
			boton_camara.pressed.connect(_on_cambiar_camara)

	if boton_motor:
		boton_motor.visible = true
		boton_motor.mouse_filter = Control.MOUSE_FILTER_STOP
		if not boton_motor.has_method("_on_boton_pulsado"):
			if not boton_motor.pressed.is_connected(_on_boton_motor_pressed):
				boton_motor.pressed.connect(_on_boton_motor_pressed)

	if boton_freno_motor:
		boton_freno_motor.mouse_filter = Control.MOUSE_FILTER_STOP
		if not boton_freno_motor.has_method("on_buton_pressed"):
			if not boton_freno_motor.toggled.is_connected(_on_freno_motor_toggled):
				boton_freno_motor.toggled.connect(_on_freno_motor_toggled)

	if not (selector_marchas and selector_marchas.has_method("_on_marcha_seleccionada")):
		if btn_delante and not btn_delante.pressed.is_connected(_cambiar_marcha_directa.bind("D")):
			btn_delante.pressed.connect(_cambiar_marcha_directa.bind("D"))
		if btn_neutro and not btn_neutro.pressed.is_connected(_cambiar_marcha_directa.bind("N")):
			btn_neutro.pressed.connect(_cambiar_marcha_directa.bind("N"))
		if btn_reversa and not btn_reversa.pressed.is_connected(_cambiar_marcha_directa.bind("R")):
			btn_reversa.pressed.connect(_cambiar_marcha_directa.bind("R"))

	if boton_freno_mano:
		if not boton_freno_mano.toggled.is_connected(_on_boton_freno_mano_toggled):
			boton_freno_mano.toggled.connect(_on_boton_freno_mano_toggled)

	if boton_baul:
		if not boton_baul.pressed.is_connected(_toggle_baul):
			boton_baul.pressed.connect(_toggle_baul)

	if boton_salir:
		# Conectar al evento `pressed` para manejar clicks/taps de forma fiable
		if not boton_salir.pressed.is_connected(_on_boton_salir):
			boton_salir.pressed.connect(_on_boton_salir)
	
	# Conectar botón de centrar volante
	if boton_centrar:
		if not boton_centrar.pressed.is_connected(_on_centrar_volante):
			boton_centrar.pressed.connect(_on_centrar_volante)
	
	# Conectar botones de direccionales
	if boton_dir_izq:
		if not boton_dir_izq.pressed.is_connected(_on_direccional_izquierda):
			boton_dir_izq.pressed.connect(_on_direccional_izquierda)
	if boton_dir_der:
		if not boton_dir_der.pressed.is_connected(_on_direccional_derecha):
			boton_dir_der.pressed.connect(_on_direccional_derecha)
	# Conectar botón de bocina (presionar/soltar nativo sin doble disparo táctil)
	if boton_bocina:
		if not boton_bocina.button_down.is_connected(_on_bocina_down):
			boton_bocina.button_down.connect(_on_bocina_down)
		if not boton_bocina.button_up.is_connected(_on_bocina_up):
			boton_bocina.button_up.connect(_on_bocina_up)

	# Conectar nuevos botones de consola y cabina
	if boton_emergencia and not boton_emergencia.toggled.is_connected(_on_emergencia_toggled):
		boton_emergencia.toggled.connect(_on_emergencia_toggled)
	if boton_luces and not boton_luces.toggled.is_connected(_on_luces_toggled):
		boton_luces.toggled.connect(_on_luces_toggled)
	if boton_crucero and not boton_crucero.toggled.is_connected(_on_crucero_toggled):
		boton_crucero.toggled.connect(_on_crucero_toggled)
	if boton_plumillas and not boton_plumillas.toggled.is_connected(_on_plumillas_toggled):
		boton_plumillas.toggled.connect(_on_plumillas_toggled)
	if boton_remolque and not boton_remolque.pressed.is_connected(_on_remolque_cabina_pressed):
		boton_remolque.pressed.connect(_on_remolque_cabina_pressed)
	if boton_diferencial and not boton_diferencial.toggled.is_connected(_on_diferencial_toggled):
		boton_diferencial.toggled.connect(_on_diferencial_toggled)
	if boton_toggle_gps and not boton_toggle_gps.pressed.is_connected(_on_toggle_gps_pressed):
		boton_toggle_gps.pressed.connect(_on_toggle_gps_pressed)
	if boton_cerrar_menu and not boton_cerrar_menu.pressed.is_connected(_cerrar_menu_cabina):
		boton_cerrar_menu.pressed.connect(_cerrar_menu_cabina)


	# Crear/registrar botón 'Puertas' dentro de BotonesVehiculo y contenedor dinámico
	# (si no existen, se crean en tiempo de ejecución)
	var botones_vehiculo = panel_contenido.find_child("BotonesVehiculo", true, false) if panel_contenido else null
	if botones_vehiculo:
		var btn_puertas = botones_vehiculo.get_node_or_null("BotonPuertas")
		if not btn_puertas:
			btn_puertas = Button.new()
			btn_puertas.name = "BotonPuertas"
			btn_puertas.text = "Puertas"
			# Intentar asignar script especializado si existe
			var bp_script = load("res://interfaz/hud/conduccion/botonpuertas.gd")
			if bp_script:
				btn_puertas.set_script(bp_script)
			botones_vehiculo.add_child(btn_puertas)
		else:
			# Si el botón ya existe, asegurar que tenga el script
			if not btn_puertas.get_script():
				var bp_script = load("res://interfaz/hud/conduccion/botonpuertas.gd")
				if bp_script:
					btn_puertas.set_script(bp_script)
		if not btn_puertas.pressed.is_connected(_on_boton_puertas_pressed):
			btn_puertas.pressed.connect(_on_boton_puertas_pressed)

	# Configurar menú desplegable
	_configurar_menu_desplegable()
	
	# Configurar opacidad y modo cine
	_configurar_opacidad_hud()

	# Conectar Modo PC desde SettingsManager
	var sm := get_node_or_null("/root/SettingsManager")
	if sm:
		if sm.has_signal("modo_pc_cambiado") and not sm.modo_pc_cambiado.is_connected(aplicar_modo_pc):
			sm.modo_pc_cambiado.connect(aplicar_modo_pc)
		aplicar_modo_pc(bool(sm.get("modo_pc")))

func aplicar_modo_pc(activo: bool) -> void:
	if activo:
		if zona_direccion:
			zona_direccion.visible = false
			zona_direccion.process_mode = Node.PROCESS_MODE_DISABLED
		if zona_pedales:
			zona_pedales.visible = false
			zona_pedales.process_mode = Node.PROCESS_MODE_DISABLED
		_apagar_bocina()
	else:
		if zona_direccion:
			zona_direccion.visible = true
			zona_direccion.process_mode = Node.PROCESS_MODE_INHERIT
		if zona_pedales:
			zona_pedales.visible = true
			zona_pedales.process_mode = Node.PROCESS_MODE_INHERIT

func _on_visibility_changed() -> void:
	if visible:
		_desactivar_ui_pie()
		var sm := get_node_or_null("/root/SettingsManager")
		if sm:
			aplicar_modo_pc(bool(sm.get("modo_pc")))
	else:
		_reactivar_ui_pie()
		_apagar_bocina()
		if boton_freno_mano and boton_freno_mano.button_pressed:
			boton_freno_mano.button_pressed = false
			_freno_mano_activo = false
			_on_freno_mano_up()
		if panel_opacidad_hud and panel_opacidad_hud.visible:
			panel_opacidad_hud.visible = false

func _on_boton_motor_pressed() -> void:
	var iv = _get_iv()
	if is_instance_valid(iv):
		var nuevo_estado: bool = not bool(iv.get("motor_encendido"))
		iv.set("motor_encendido", nuevo_estado)
		if nuevo_estado and iv.get("freno_mano") == true and iv.has_method("set_fmano"):
			iv.call("set_fmano", false)
	_sincronizar_estado_motor()

func _on_freno_motor_toggled(activo: bool) -> void:
	var iv = _get_iv()
	if is_instance_valid(iv) and "freno_motor" in iv:
		iv.freno_motor = activo

func _cambiar_marcha_directa(m: String) -> void:
	var iv = _get_iv()
	if is_instance_valid(iv):
		match m:
			"D":
				if iv.has_method("set_marcha_enum"):
					iv.call("set_marcha_enum", 3)
				if iv.has_method("set_fmano"):
					iv.call("set_fmano", false)
			"N":
				if iv.has_method("set_marcha_enum"):
					iv.call("set_marcha_enum", 2)
			"R":
				if iv.has_method("set_marcha_enum"):
					iv.call("set_marcha_enum", 1)
				if iv.has_method("set_fmano"):
					iv.call("set_fmano", false)

func _desactivar_ui_pie() -> void:
	var root = get_tree().get_root() if get_tree() else null
	if not root: return
	for pattern in ["*UIpie*", "*UiPie*", "*uipie*", "*UIPie*", "*Uipie*"]:
		var ui_pies = root.find_children(pattern, "", true, false)
		for pie in ui_pies:
			if is_instance_valid(pie) and (pie is CanvasLayer or pie is Control):
				pie.visible = false
				pie.process_mode = Node.PROCESS_MODE_DISABLED
				var controles = pie.get_node_or_null("Controles")
				if controles:
					controles.visible = false

func _reactivar_ui_pie() -> void:
	var root = get_tree().get_root() if get_tree() else null
	if not root: return
	for pattern in ["*UIpie*", "*UiPie*", "*uipie*", "*UIPie*", "*Uipie*"]:
		var ui_pies = root.find_children(pattern, "", true, false)
		for pie in ui_pies:
			if is_instance_valid(pie) and (pie is CanvasLayer or pie is Control):
				pie.process_mode = Node.PROCESS_MODE_INHERIT
				pie.visible = true
				var controles = pie.get_node_or_null("Controles")
				if controles:
					controles.visible = true

func _apagar_bocina() -> void:
	if _bocina_ref and is_instance_valid(_bocina_ref) and _bocina_ref.has_method("set_bocina"):
		_bocina_ref.set_bocina(false)

# ════════════════════════════════════════════════════════════════════
#  APLICAR SHADER BOTONES
# ════════════════════════════════════════════════════════════════════

func _aplicar_shader_botones() -> void:
	# El botón de motor se maneja con MotorSwitch.gd (visual+toggle propio).
	if boton_freno_mano:
		boton_freno_mano.self_modulate = Color.WHITE

# ════════════════════════════════════════════════════════════════════
#  ACTUALIZACIÓN DE UI
# ════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	_sincronizar_estado_motor()

	if not visible or not vehiculo:
		return

	# Mostrar Marcha Actual (ej: N, R, D1..D10)
	if label_marcha:
		label_marcha.text = _get_texto_marcha()
	_procesar_control_crucero(_delta)
	_actualizar_testigos_tablero()
	# Actualizar color del botón de motor
	_actualizar_color_botones()
	# Velocímetro
	_actualizar_velocimetro()
	# RPM
	_actualizar_rpm()
	# Combustible
	_actualizar_combustible()
	# GPS HUD
	_actualizar_gps_hud(_delta)

func _configurar_gps_hud_inicial() -> void:
	if _gps_camera:
		# OPTIMIZACIÓN MÁXIMA DE FPS: Renderizar ÚNICAMENTE la capa 2 (carreteras planas sin sombreado).
		# Ignora 100% de los modelos 3D pesados, vegetación, vehículos, sombras y luces del mundo principal.
		_gps_camera.cull_mask = 2
		_gps_camera.far = 500.0
		_gps_camera.near = 1.0
		_gps_camera.fov = 50.0
		
		# Environment ultra ligero sin sombras ni post-procesado
		var map_env = Environment.new()
		map_env.background_mode = Environment.BG_COLOR
		map_env.background_color = Color(0.07, 0.08, 0.11, 1.0)
		map_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		map_env.ambient_light_color = Color(0.85, 0.90, 0.95)
		map_env.ambient_light_energy = 1.2
		_gps_camera.environment = map_env

	if _gps_viewport:
		_gps_viewport.msaa_3d = Viewport.MSAA_DISABLED

	if _panel_gps:
		var overlay = _panel_gps.get_node_or_null("Overlay")
		if overlay and not _linea_gps_hud:
			_linea_gps_hud = Line2D.new()
			_linea_gps_hud.name = "LineaRutaHUD"
			_linea_gps_hud.width = 6.0
			_linea_gps_hud.default_color = Color(0.88, 0.70, 0.32, 0.90)
			_linea_gps_hud.joint_mode = Line2D.LINE_JOINT_ROUND
			_linea_gps_hud.begin_cap_mode = Line2D.LINE_CAP_ROUND
			_linea_gps_hud.end_cap_mode = Line2D.LINE_CAP_ROUND
			_linea_gps_hud.antialiased = true
			overlay.add_child(_linea_gps_hud)
			overlay.move_child(_linea_gps_hud, 0)

func _actualizar_gps_hud(delta: float) -> void:
	if not _gps_camera or not vehiculo or not is_instance_valid(vehiculo):
		return
		
	# Vincular el SubViewport del CanvasLayer al World3D de la escena principal
	if _gps_viewport and not _gps_viewport.world_3d and vehiculo.get_world_3d():
		_gps_viewport.world_3d = vehiculo.get_world_3d()
		
	# Sincronización con CelularUI (Ruta Waze)
	if not is_instance_valid(_cel_ui_ref):
		_cel_ui_ref = get_node_or_null("/root/CelularUI")
		if not _cel_ui_ref and get_tree() and get_tree().current_scene:
			_cel_ui_ref = get_tree().current_scene.find_child("CelularUI", true, false)

	var pos_target = vehiculo.global_position + Vector3(0.0, 70.0, 0.0)
	_gps_camera.global_position = _gps_camera.global_position.lerp(pos_target, delta * 12.0)
	_gps_camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	
	if _icono_veh_gps:
		var rot_deg = deg_to_rad(-vehiculo.rotation_degrees.y)
		_icono_veh_gps.rotation = rot_deg

	_actualizar_linea_ruta_hud(_cel_ui_ref)

func _actualizar_linea_ruta_hud(cel_ui: Node) -> void:
	if not _linea_gps_hud or not _gps_camera:
		return
		
	var path_3d: PackedVector3Array = []
	if cel_ui and is_instance_valid(cel_ui):
		var route_val = cel_ui.get("waze_route")
		if route_val and route_val is PackedVector3Array:
			path_3d = route_val
			
	if path_3d.is_empty():
		var gps_line_node = vehiculo.find_child("GPSRutaLinea", true, false)
		if not gps_line_node and get_tree() and get_tree().current_scene:
			gps_line_node = get_tree().current_scene.find_child("GPSRutaLinea", true, false)
		if gps_line_node and gps_line_node.get("active") == true:
			var lp = gps_line_node.get("last_path")
			if lp and lp is PackedVector3Array:
				path_3d = lp

	if path_3d.is_empty() and get_tree() and get_tree().root.has_meta("destino_gps_mapa"):
		var dest_meta = get_tree().root.get_meta("destino_gps_mapa")
		if dest_meta is Dictionary and dest_meta.has("pos") and is_instance_valid(vehiculo):
			var p_dest: Vector3 = dest_meta["pos"]
			path_3d = PackedVector3Array([vehiculo.global_position + Vector3(0, 1.0, 0), p_dest + Vector3(0, 1.0, 0)])
			_actualizar_etiqueta_destino_gps(dest_meta, vehiculo.global_position.distance_to(p_dest))
	elif _panel_gps:
		var lbl_dest := _panel_gps.get_node_or_null("LblDestinoGPS") as Label
		if lbl_dest:
			lbl_dest.visible = false

	if path_3d.size() < 2:
		_linea_gps_hud.clear_points()
		return

	var points_2d: Array[Vector2] = []
	for p3d in path_3d:
		if not _gps_camera.is_position_behind(p3d):
			var p2d = _gps_camera.unproject_position(p3d)
			points_2d.append(p2d)
			
	_linea_gps_hud.points = PackedVector2Array(points_2d)


func _actualizar_etiqueta_destino_gps(dest_meta: Dictionary, dist_m: float) -> void:
	if not _panel_gps:
		return
	var lbl := _panel_gps.get_node_or_null("LblDestinoGPS") as Label
	if not lbl:
		lbl = Label.new()
		lbl.name = "LblDestinoGPS"
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.offset_top = -26.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("outline_size", 4)
		_panel_gps.add_child(lbl)
	lbl.visible = true
	var dist_txt := ("%.1f km" % (dist_m / 1000.0)) if dist_m >= 1000.0 else ("%d m" % int(round(dist_m)))
	lbl.text = "🏁 %s · %s" % [str(dest_meta.get("nombre", "Descarga")), dist_txt]

func _actualizar_velocimetro() -> void:
	var vel_kmh: float = vehiculo.linear_velocity.length() * 3.6
	var vel_norm: float = clamp(vel_kmh / velocidad_maxima, 0.0, 1.0)
	if _velo_rect:
		var mat := _velo_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("velocidad", vel_norm)
	if _label_vel:
		_label_vel.text = str(int(vel_kmh))

func _actualizar_rpm() -> void:
	if not _motor_ref:
		return
	var rpm_val: float = 0.0
	var rpm_src: Node = null

	# Buscar ControladorRPM bajo el nodo Motor
	if _motor_ref.has_node("ControladorRPM"):
		rpm_src = _motor_ref.get_node_or_null("ControladorRPM")
	else:
		rpm_src = _motor_ref.find_child("ControladorRPM", true, false)

	# Leer rpm_maximas desde la config del motor PRIMERO (fuente más fiable)
	var rpm_max: float = rpm_maxima  # fallback al export
	var cfg = null
	if _motor_ref.has_method("get"):
		cfg = _motor_ref.get("config")
	if cfg != null:
		var v = cfg.get("rpm_maximas") if cfg.has_method("get") else null
		if v != null:
			rpm_max = max(float(v), 1.0)
	elif rpm_src != null and rpm_src.has_method("get"):
		# Intentar leer desde el config del controlador_rpm
		var src_cfg = rpm_src.get("config")
		if src_cfg != null:
			var v = src_cfg.get("rpm_maximas") if src_cfg.has_method("get") else null
			if v != null:
				rpm_max = max(float(v), 1.0)

	# Leer valor actual de RPM
	if rpm_src != null and rpm_src.has_method("get"):
		var tmp = rpm_src.get("rpm_actual")
		if tmp != null:
			rpm_val = float(tmp)
		elif rpm_src.has_method("get_rpm_norm"):
			rpm_val = float(rpm_src.call("get_rpm_norm")) * rpm_max
	else:
		# Fallback directo a motor.rpm_motor
		var tmp2 = _motor_ref.get("rpm_motor") if _motor_ref.has_method("get") else null
		if tmp2 != null:
			rpm_val = float(tmp2)

	# Normalizar — siempre clamp para que el shader nunca reciba >1.0 (causa loop visual)
	var rpm_n: float = clamp(rpm_val / max(rpm_max, 1.0), 0.0, 1.0)

	if _velo_rect:
		var mat := _velo_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("rpm_norm", rpm_n)
	if _bar_rpm:
		_bar_rpm.value = rpm_n * 100.0
	if _label_rpm:
		_label_rpm.text = str(int(rpm_val))
		if rpm_n > 0.85:
			_label_rpm.modulate = Color(0.88, 0.42, 0.35, 1.0)
		else:
			_label_rpm.modulate = Color(0.82, 0.85, 0.88, 0.95)

func _actualizar_combustible() -> void:
	# Usa nivel_combustible_l / capacidad_combustible_l si el motor lo expone.
	var nivel: float = 1.0
	if _motor_ref:
		var lts: Variant  = _motor_ref.get("nivel_combustible_l")
		var cap: Variant  = _motor_ref.get("capacidad_combustible_l")
		if lts != null and cap != null and float(cap) > 0.0:
			nivel = clamp(float(lts) / float(cap), 0.0, 1.0)
		elif _motor_ref.get("combustible") != null:
			nivel = clamp(float(_motor_ref.get("combustible")), 0.0, 1.0)
	elif vehiculo.get("combustible") != null:
		nivel = clamp(float(vehiculo.get("combustible")), 0.0, 1.0)
	if _comb_rect:
		var mat := _comb_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("combustible", nivel)
	if _bar_gas:
		_bar_gas.value = nivel * 100.0
	if _label_gas:
		_label_gas.text = str(int(nivel * 100.0)) + "%"
		if nivel < 0.20:
			_label_gas.modulate = Color(0.88, 0.55, 0.30, 1.0)
		else:
			_label_gas.modulate = Color(0.82, 0.85, 0.88, 0.95)

# ════════════════════════════════════════════════════════════════════
#  EVENTOS DE BOTONES
# ════════════════════════════════════════════════════════════════════

func _on_cambiar_camara() -> void:
	var ahora_ms: int = Time.get_ticks_msec()
	if ahora_ms - _ultimo_cambio_camara_ms < COOLDOWN_CAMARA_MS:
		return
	_ultimo_cambio_camara_ms = ahora_ms
	# Preferir delegar a la referencia `camera_manager` del vehículo (propiedad/script),
	# si no existe, intentar buscar un nodo hijo llamado 'CameraManager'.
	if vehiculo:
		var cm: Node = null
		var maybe_cm = null
		if vehiculo.has_method("get"):
			maybe_cm = vehiculo.get("camera_manager")
			# También admitir nombre alternativo en camelcase
			if maybe_cm == null:
				maybe_cm = vehiculo.get("CameraManager") if vehiculo.has_method("get") else null
			if maybe_cm != null:
				cm = maybe_cm
			else:
				cm = vehiculo.get_node_or_null("CameraManager")

		if cm:
			if cm.has_method("alternar_camara"):
				cm.alternar_camara()
				return
			# Compatibilidad amplia: activar/seleccionar/mover
			if cm.has_method("activar_camara"):
				cm.activar_camara(0)
				return

	# Fallback a GameManager global (soporta GDScript o C#)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("CambiarCamaraGlobal"):
			gm.call("CambiarCamaraGlobal", 0)
		elif gm.has_method("cambiar_camara_global"):
			gm.call("cambiar_camara_global")
		else:
			push_warning("UIVehiculo: GameManager no expone método para cambiar cámara.")

func _on_boton_motor_toggle(_activo: bool) -> void:
	# Handler obsoleto: ya no fuerza el motor; el toggle real es BtnCorriente.
	pass

func _on_boton_camara_input(event: InputEvent) -> void:
	if not _es_presion_primaria(event):
		return
	_on_cambiar_camara()
	get_viewport().set_input_as_handled()

func _on_boton_salir_input(event: InputEvent) -> void:
	if not _es_presion_primaria(event):
		return
	_on_boton_salir()
	get_viewport().set_input_as_handled()

func _on_boton_freno_mano_toggled(activo: bool) -> void:
	_freno_mano_activo = activo
	if is_instance_valid(_get_iv()):
		_get_iv().freno_mano = _freno_mano_activo

func _on_boton_freno_mano_input(event: InputEvent) -> void:
	if _es_inicio_presion(event):
		if is_instance_valid(_get_iv()):
			_freno_mano_activo = not _get_iv().freno_mano
			_get_iv().freno_mano = _freno_mano_activo
		else:
			_freno_mano_activo = not _freno_mano_activo
		get_viewport().set_input_as_handled()

func _on_freno_mano_down() -> void:
	if not is_instance_valid(_get_iv()):
		return
	_get_iv().freno_mano = true

func _on_freno_mano_up() -> void:
	if not is_instance_valid(_get_iv()):
		return
	_get_iv().freno_mano = false

func _on_boton_baul_input(event: InputEvent) -> void:
	if not _es_presion_primaria(event):
		return
	_toggle_baul()
	get_viewport().set_input_as_handled()

func _toggle_baul() -> void:
	if _anim_player_baul == null:
		push_warning("UIVehiculo: no se encontró AnimationPlayer para controlar el baúl.")
		return

	if _anim_player_baul.is_playing() and _anim_player_baul.current_animation == "abrir_baul":
		return

	if not _baul_abierto:
		_baul_abierto = true
		_anim_player_baul.play("abrir_baul")
		if _anim_player_baul.has_animation("motor_encendido"):
			_anim_player_baul.queue("motor_encendido")
	else:
		_baul_abierto = false
		_detener_motor_baul()
		_anim_player_baul.play_backwards("abrir_baul")

func _detener_motor_baul() -> void:
	if _anim_player_baul:
		if _anim_player_baul.current_animation == "motor_encendido":
			_anim_player_baul.stop(true)

	if _audio_motor_baul and _audio_motor_baul.playing:
		_audio_motor_baul.stop()

func _on_boton_salir() -> void:
	print("UIVehiculo: BotonSalir presionado. Vehiculo=", vehiculo)
	var jugador = null
	if vehiculo and vehiculo.has_method("get"):
		jugador = vehiculo.get("jugador_ref")

	if vehiculo and vehiculo.has_method("bajar_jugador"):
		vehiculo.bajar_jugador()
	elif jugador and jugador.has_method("salir_del_vehiculo"):
		jugador.salir_del_vehiculo()
	elif is_instance_valid(jugador):
		if _get_gv() and _get_gv().has_method("bajar_jugador_de_vehiculo"): _get_gv().bajar_jugador_de_vehiculo(jugador, vehiculo)

	visible = false

	# Asegurar que, después de un frame (para que el vehículo termine su lógica),
	# la cámara se restaure al jugador si existe una Camera3D bajo su nodo.
	await get_tree().process_frame
	if jugador and is_instance_valid(jugador):
		var cam = jugador.find_child("Camera3D", true, false)
		if cam and cam is Camera3D:
			cam.make_current()
			print("UIVehiculo: Cámara restaurada al jugador ->", cam.get_path())
	# Lanzar verificación post-salida que fuerce restauración de estado del jugador
	call_deferred("_asegurar_salida_post", jugador, vehiculo)

func _on_centrar_volante() -> void:
	# If there's a physical/screen steering control, let it perform a smooth centering
	# and update InputVehiculo itself via its setter. Avoid forcing InputVehiculo
	# immediately to prevent conflicting, abrupt changes.
	if volante_control and volante_control.has_method("centrar_volante"):
		volante_control.centrar_volante()
		return

	# Fallback: if no volante control exists, center input directly.
	if is_instance_valid(_get_iv()):
		_get_iv().centrar_direccion()

func _on_direccional_izquierda() -> void:
	_ensure_direccionales()
	if _direccionales and is_instance_valid(_direccionales):
		if _direccionales.has_method("toggle_izquierda"):
			_direccionales.toggle_izquierda()
		elif _direccionales.has_method("activar_izquierda"):
			if _direccionales.get("parpadeando_izquierda"):
				_direccionales.call("desactivar_izquierda")
			else:
				_direccionales.call("activar_izquierda")
	if is_instance_valid(_get_iv()):
		if _get_iv().has_method("set_direccional"):
			_get_iv().set_direccional("izquierda")

func _on_direccional_derecha() -> void:
	_ensure_direccionales()
	if _direccionales and is_instance_valid(_direccionales):
		if _direccionales.has_method("toggle_derecha"):
			_direccionales.toggle_derecha()
		elif _direccionales.has_method("activar_derecha"):
			if _direccionales.get("parpadeando_derecha"):
				_direccionales.call("desactivar_derecha")
			else:
				_direccionales.call("activar_derecha")
	if is_instance_valid(_get_iv()):
		if _get_iv().has_method("set_direccional"):
			_get_iv().set_direccional("derecha")

func _on_bocina_down() -> void:
	_ensure_bocina()
	if _bocina_ref and is_instance_valid(_bocina_ref) and _bocina_ref.has_method("set_bocina"):
		_bocina_ref.set_bocina(true)

func _on_bocina_up() -> void:
	_ensure_bocina()
	if _bocina_ref and is_instance_valid(_bocina_ref) and _bocina_ref.has_method("set_bocina"):
		_bocina_ref.set_bocina(false)

func _on_bocina_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_ensure_bocina()
		if event.pressed:
			if _bocina_ref and is_instance_valid(_bocina_ref) and _bocina_ref.has_method("set_bocina"):
				_bocina_ref.set_bocina(true)
		else:
			if _bocina_ref and is_instance_valid(_bocina_ref) and _bocina_ref.has_method("set_bocina"):
				_bocina_ref.set_bocina(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if _usar_solo_screen_touch(event):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_ensure_bocina()
			if event.pressed:
				if _bocina_ref and is_instance_valid(_bocina_ref) and _bocina_ref.has_method("set_bocina"):
					_bocina_ref.set_bocina(true)
			else:
				if _bocina_ref and is_instance_valid(_bocina_ref) and _bocina_ref.has_method("set_bocina"):
					_bocina_ref.set_bocina(false)
			get_viewport().set_input_as_handled()

func _ensure_bocina() -> void:
	if _bocina_ref and is_instance_valid(_bocina_ref):
		return
	if vehiculo:
		_bocina_ref = _buscar_nodo_recursivo(vehiculo, "Sonidos")
	if _bocina_ref == null:
		_bocina_ref = _buscar_nodo_recursivo(vehiculo, "Sonido_dual")
	if _bocina_ref == null:
		_bocina_ref = _buscar_nodo_recursivo(get_tree().get_root(), "Sonidos")
	if _bocina_ref == null:
		_bocina_ref = _buscar_nodo_recursivo(get_tree().get_root(), "Sonido_dual")

func _ensure_direccionales() -> void:
	if _direccionales and is_instance_valid(_direccionales):
		return
	if vehiculo:
		_direccionales = _buscar_nodo_recursivo(vehiculo, "Direccionales")
	if _direccionales == null:
		_direccionales = _buscar_nodo_recursivo(get_tree().get_root(), "Direccionales")

func _buscar_nodo_recursivo(nodo: Node, nombre: String) -> Node:
	if nodo == null:
		return null
	if nodo.name == nombre:
		return nodo
	for hijo in nodo.get_children():
		var encontrado = _buscar_nodo_recursivo(hijo, nombre)
		if encontrado:
			return encontrado
	return null


func _asegurar_salida_post(jugador: Node, _vehiculo_ref: Node) -> void:
	# Esperar un par de frames cortos para dejar que ambos hijos terminen su lógica
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout
	if jugador and is_instance_valid(jugador):
		# Asegurar UI
		_reactivar_ui_pie()
		if jugador.has_method("mostrar_interfaz_pie"):
			jugador.mostrar_interfaz_pie()

		# Mostrar el jugador
		if jugador.has_method("show"):
			jugador.show()

		# Re-habilitar procesamiento (CharacterBody3D y nodos en general)
		if jugador is Node:
			jugador.process_mode = Node.PROCESS_MODE_INHERIT

		# Reactivar collision shapes si existen
		var cs3 = jugador.find_child("CollisionShape3D", true, false)
		if cs3:
			cs3.set_deferred("disabled", false)
		var cs2 = jugador.find_child("CollisionShape2D", true, false)
		if cs2:
			cs2.set_deferred("disabled", false)

		# Remover excepciones de colisión con el vehículo si el jugador lo soporta
		if jugador.has_method("remove_collision_exception_with") and vehiculo and is_instance_valid(vehiculo):
			jugador.remove_collision_exception_with(vehiculo)

		# Restaurar cámara limpia del jugador
		if jugador.has_method("restaurar_camara_salida_vehiculo"):
			jugador.restaurar_camara_salida_vehiculo()
		else:
			var cam = jugador.find_child("Camera3D", true, false)
			if cam and cam is Camera3D:
				cam.make_current()

		# Forzar re-habilitación inmediata de colisiones y procesamiento del jugador
		if cs3:
			cs3.disabled = false
		if cs2:
			cs2.disabled = false

		# Asegurar process_mode activo
		if jugador and jugador is Node:
			jugador.process_mode = Node.PROCESS_MODE_INHERIT

		# Intentar remover excepciones de colisión con el vehículo si aplica
		if jugador.has_method("remove_collision_exception_with") and vehiculo and is_instance_valid(vehiculo):
			jugador.remove_collision_exception_with(vehiculo)
	else:
		# Si no tenemos referencia al jugador, intentar recuperarla desde el vehículo
		if vehiculo and vehiculo.has_method("get"):
			var jref = vehiculo.get("jugador_ref")
			if jref and jref != jugador:
				call_deferred("_asegurar_salida_post", jref, vehiculo)


func _on_boton_puertas_pressed() -> void:
	# Ubicar contenedor objetivo junto al TabMenu (botón de configuración)
	var menu_parent: Node = null
	if tab_menu:
		menu_parent = tab_menu.get_parent()
	else:
		menu_parent = get_node_or_null("SafeArea/Interface")

	if not menu_parent:
		push_warning("UIVehiculo: no se pudo ubicar la interfaz para mostrar 'Puertas'.")
		return

	var doors = menu_parent.get_node_or_null("PuertasFloating")
	if not doors:
		doors = VBoxContainer.new()
		doors.name = "PuertasFloating"
		doors.visible = true
		doors.custom_minimum_size = Vector2(220, 0)
		menu_parent.add_child(doors)

		# Posicionar junto al TabMenu si está disponible
		if tab_menu and tab_menu is Control and doors is Control:
			# Colocar ligeramente a la derecha del TabMenu
			doors.position = tab_menu.position + Vector2(48, 0)
		elif doors is Control:
			doors.position = Vector2(10, 10)

		# Asegurar que el contenedor reciba eventos y esté en frente
		if doors is Control:
			doors.mouse_filter = Control.MOUSE_FILTER_STOP
			var pd = doors.get_parent()
			if pd:
				pd.move_child(doors, pd.get_child_count() - 1)

	# Delegar creación de botones al script de BotonPuertas si está disponible
	var boton_puertas_node = null
	if panel_contenido:
		boton_puertas_node = panel_contenido.find_child("BotonPuertas", true, false)

	if boton_puertas_node and boton_puertas_node.has_method("populate_buttons"):
		boton_puertas_node.populate_buttons(doors, tab_menu)


func _on_puerta_pressed(idx: int) -> void:
	print("Puerta %d presionada" % (idx + 1))

# ════════════════════════════════════════════════════════════════════
#  UTILIDADES
# ════════════════════════════════════════════════════════════════════

func _actualizar_color_botones() -> void:
	# Actualizar estado visual del nuevo MotorSwitch
	if boton_motor and boton_motor.has_method("set_activo"):
		boton_motor.set_activo(_motor_activo)
		
	# Actualizar color/modulación del BtnEncender real según el estado del motor
	var btn_encender = find_child("BtnEncender", true, false) as Button
	if btn_encender:
		if _motor_activo:
			btn_encender.modulate = Color(0.92, 0.76, 0.42, 1.0) # Ámbar automotriz encendido
		else:
			btn_encender.modulate = Color(1.0, 1.0, 1.0, 1.0) # Blanco neutro apagado

	# Actualizar shader del botón de freno mano
	if boton_freno_mano and boton_freno_mano.material is ShaderMaterial:
		boton_freno_mano.material.set_shader_parameter("activo", _freno_mano_activo)

	# Actualizar shader del botón del baúl
	if boton_baul and boton_baul.material is ShaderMaterial:
		boton_baul.material.set_shader_parameter("activo", _baul_abierto)

func _usar_solo_screen_touch(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false):
		return true
	return false

func _es_presion_primaria(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if _usar_solo_screen_touch(event):
			return false
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _es_inicio_presion(event: InputEvent) -> bool:
	return _es_presion_primaria(event)

func _es_fin_presion(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if _usar_solo_screen_touch(event):
			return false
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	return false

func _get_texto_marcha() -> String:
	if not is_instance_valid(_get_iv()):
		return "N"
	var m_base: String = _get_iv().marcha
	if m_base == "D" and _motor_ref and "_current_gear" in _motor_ref:
		return "D" + str(int(_motor_ref._current_gear) + 1)
	return m_base

func _actualizar_testigos_tablero() -> void:
	if testigo_motor:
		testigo_motor.text = "IGN"
		testigo_motor.add_theme_color_override("font_color", Color(0.90, 0.74, 0.36, 1.0) if _motor_activo else Color(0.42, 0.45, 0.48, 0.45))
	var fm = _get_iv().freno_mano if is_instance_valid(_get_iv()) else _freno_mano_activo
	_freno_mano_activo = fm
	if boton_freno_mano and boton_freno_mano.toggle_mode and boton_freno_mano.button_pressed != fm:
		boton_freno_mano.set_pressed_no_signal(fm)
	if testigo_fmano:
		testigo_fmano.text = "PRK"
		testigo_fmano.add_theme_color_override("font_color", Color(0.85, 0.35, 0.32, 1.0) if fm else Color(0.42, 0.45, 0.48, 0.45))
	if testigo_crucero:
		testigo_crucero.text = ("CRZ %d" % int(_vel_crucero_kmh)) if _crucero_activo else "CRZ"
		testigo_crucero.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94, 1.0) if _crucero_activo else Color(0.42, 0.45, 0.48, 0.45))
	if testigo_luces:
		testigo_luces.text = "LUX"
		testigo_luces.add_theme_color_override("font_color", Color(0.90, 0.74, 0.36, 1.0) if _luces_activas else Color(0.42, 0.45, 0.48, 0.45))

func _procesar_control_crucero(_delta: float) -> void:
	if not _crucero_activo or not is_instance_valid(vehiculo) or not is_instance_valid(_get_iv()):
		return
	if _get_iv().freno > 0.1 or _get_iv().freno_mano or not _motor_activo or _get_iv().marcha != "D":
		_crucero_activo = false
		if boton_crucero:
			boton_crucero.set_pressed_no_signal(false)
			boton_crucero.text = "CRUCERO"
		return
	var vel_actual = vehiculo.linear_velocity.length() * 3.6
	if vel_actual < _vel_crucero_kmh - 0.5:
		var err = clampf((_vel_crucero_kmh - vel_actual) / 12.0, 0.25, 0.95)
		_get_iv().set_gas(err)

func _on_emergencia_toggled(activo: bool) -> void:
	_emergencia_activa = activo
	if vehiculo and "luces_emergencia" in vehiculo:
		vehiculo.luces_emergencia = activo
	_ensure_direccionales()
	if _direccionales and is_instance_valid(_direccionales):
		if _direccionales.has_method("set_emergencia"):
			_direccionales.call("set_emergencia", activo)
		elif _direccionales.has_method("toggle_emergencia"):
			_direccionales.call("toggle_emergencia")

func _on_luces_toggled(activo: bool) -> void:
	_luces_activas = activo
	if vehiculo and vehiculo.has_method("_activar_luces"):
		vehiculo.call("_activar_luces", activo)
	if boton_luces:
		boton_luces.text = "LUCES: ON" if activo else "LUCES: OFF"

func _on_diferencial_toggled(activo: bool) -> void:
	_diferencial_activo = activo
	if vehiculo and "bloqueo_diferencial" in vehiculo:
		vehiculo.set("bloqueo_diferencial", activo)
	if is_instance_valid(_get_iv()) and "bloqueo_diferencial" in _get_iv():
		_get_iv().set("bloqueo_diferencial", activo)
	if boton_diferencial:
		boton_diferencial.text = "DIF. 6x4: LOCK" if activo else "DIF. 6x4"
	if label_toast_hud:
		label_toast_hud.text = "DIFERENCIAL 6x4: BLOQUEADO" if activo else "DIFERENCIAL 6x4: LIBRE"
		label_toast_hud.visible = true
		if _tween_toast and _tween_toast.is_valid():
			_tween_toast.kill()
		_tween_toast = create_tween()
		_tween_toast.tween_property(label_toast_hud, "modulate:a", 1.0, 0.15)
		_tween_toast.tween_interval(1.4)
		_tween_toast.tween_property(label_toast_hud, "modulate:a", 0.0, 0.35)
		_tween_toast.tween_callback(func(): label_toast_hud.visible = false)

func _on_toggle_gps_pressed() -> void:
	_gps_visible = not _gps_visible
	if _panel_gps:
		_panel_gps.visible = _gps_visible
	if _gps_viewport:
		_gps_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _gps_visible else SubViewport.UPDATE_DISABLED
	if boton_toggle_gps:
		boton_toggle_gps.text = "MAPA" if _gps_visible else "+ MAPA"

func _cerrar_menu_cabina() -> void:
	if _menu_desplegado:
		_menu_desplegado = false
		_animar_menu()

func _on_crucero_toggled(activo: bool) -> void:
	if not vehiculo or not is_instance_valid(_get_iv()):
		return
	var vel_actual = vehiculo.linear_velocity.length() * 3.6
	if activo and vel_actual >= 15.0 and _get_iv().marcha == "D" and _motor_activo:
		_crucero_activo = true
		_vel_crucero_kmh = roundf(vel_actual)
		if boton_crucero:
			boton_crucero.text = "CRZ: %d KM/H" % int(_vel_crucero_kmh)
	else:
		_crucero_activo = false
		if boton_crucero:
			boton_crucero.set_pressed_no_signal(false)
			boton_crucero.text = "CRUCERO"

func _on_plumillas_toggled(activo: bool) -> void:
	_plumillas_activas = activo
	if InputVehiculo:
		InputVehiculo.plumillas = activo
	if is_instance_valid(vehiculo) and vehiculo.has_method("set_plumillas"):
		vehiculo.call("set_plumillas", activo)
	if boton_plumillas:
		boton_plumillas.text = "PLUMILLAS: ON" if activo else "PLUMILLAS"

func _on_remolque_cabina_pressed() -> void:
	if not vehiculo:
		return
	var eng = vehiculo.find_child("Enganche", true, false)
	if not eng:
		eng = vehiculo.find_child("QuintaRueda", true, false)
	if eng and "conectado" in eng:
		if eng.conectado:
			if eng.has_method("soltar"):
				eng.call("soltar")
		else:
			if has_node("/root/NotificationManager"):
				get_node("/root/NotificationManager").notificar_exito("Retrocede suave hacia el Kingpin del tráiler para acoplar la quinta rueda.")

func _sincronizar_estado_motor() -> void:
	if is_instance_valid(_get_iv()):
		# Leer el estado real en el singleton y reflejarlo en la UI
		_motor_activo = bool(_get_iv().get("motor_encendido"))
	else:
		_motor_activo = false

# ════════════════════════════════════════════════════════════════════
#  MENÚ DESPLEGABLE
# ════════════════════════════════════════════════════════════════════

func _configurar_menu_desplegable() -> void:
	if not panel_contenido or not tab_menu:
		return
	
	# Inicialmente ocultar el panel
	panel_contenido.visible = false
	panel_contenido.modulate.a = 0.0
	panel_contenido.scale = Vector2(0.8, 0.8)
	_menu_desplegado = false
	
	# Si tab_menu es un botón, usar su señal nativa `pressed`
	if tab_menu is BaseButton:
		if not tab_menu.pressed.is_connected(_toggle_menu):
			tab_menu.pressed.connect(_toggle_menu)
	elif not tab_menu.gui_input.is_connected(_on_tab_menu_input):
		tab_menu.gui_input.connect(_on_tab_menu_input)

func _on_tab_menu_input(event: InputEvent) -> void:
	if _es_inicio_presion(event):
		var ahora_ms = Time.get_ticks_msec()
		if ahora_ms - _ultimo_toggle_menu_ms < COOLDOWN_MENU_MS:
			return
		_ultimo_toggle_menu_ms = ahora_ms
		_toggle_menu()
		get_viewport().set_input_as_handled()

func _toggle_menu() -> void:
	_menu_desplegado = not _menu_desplegado
	_animar_menu()

func _animar_menu() -> void:
	if not panel_contenido:
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	
	if tab_menu and tab_menu is Control:
		(tab_menu as Control).modulate = Color(1.0, 0.85, 0.55, 1.0) if _menu_desplegado else Color(1.0, 1.0, 1.0, 1.0)
	if _menu_desplegado:
		# Mostrar el menú con animación
		panel_contenido.visible = true
		tween.tween_property(panel_contenido, "modulate:a", 1.0, duracion_animacion)
		tween.tween_property(panel_contenido, "scale", Vector2(1.0, 1.0), duracion_animacion)
	else:
		# Ocultar el menú con animación
		tween.tween_property(panel_contenido, "modulate:a", 0.0, duracion_animacion)
		tween.tween_property(panel_contenido, "scale", Vector2(0.85, 0.85), duracion_animacion)
		tween.chain().tween_callback(func(): panel_contenido.visible = false)


# ════════════════════════════════════════════════════════════════════
#  SISTEMA DE OPACIDAD Y MODO CINE / GRABACIÓN DE VIDEO
# ════════════════════════════════════════════════════════════════════

func _configurar_opacidad_hud() -> void:
	if boton_ocultar_hud:
		if not boton_ocultar_hud.gui_input.is_connected(_on_boton_ocultar_hud_gui_input):
			boton_ocultar_hud.gui_input.connect(_on_boton_ocultar_hud_gui_input)
	
	if boton_restaurar_hud:
		if not boton_restaurar_hud.pressed.is_connected(_on_boton_restaurar_hud_pressed):
			boton_restaurar_hud.pressed.connect(_on_boton_restaurar_hud_pressed)
		if not boton_restaurar_hud.mouse_entered.is_connected(_on_boton_restaurar_mouse_entered):
			boton_restaurar_hud.mouse_entered.connect(_on_boton_restaurar_mouse_entered)
		if not boton_restaurar_hud.mouse_exited.is_connected(_on_boton_restaurar_mouse_exited):
			boton_restaurar_hud.mouse_exited.connect(_on_boton_restaurar_mouse_exited)

	if slider_opacidad:
		if not slider_opacidad.value_changed.is_connected(_on_slider_opacidad_changed):
			slider_opacidad.value_changed.connect(_on_slider_opacidad_changed)

	var btn_p100 = find_child("BtnPreset100", true, false) as Button
	if btn_p100 and not btn_p100.pressed.is_connected(_on_btn_preset_100):
		btn_p100.pressed.connect(_on_btn_preset_100)
	var btn_p50 = find_child("BtnPreset50", true, false) as Button
	if btn_p50 and not btn_p50.pressed.is_connected(_on_btn_preset_50):
		btn_p50.pressed.connect(_on_btn_preset_50)
	var btn_p20 = find_child("BtnPreset20", true, false) as Button
	if btn_p20 and not btn_p20.pressed.is_connected(_on_btn_preset_20):
		btn_p20.pressed.connect(_on_btn_preset_20)
	var btn_p0 = find_child("BtnPreset0", true, false) as Button
	if btn_p0 and not btn_p0.pressed.is_connected(_on_btn_preset_0):
		btn_p0.pressed.connect(_on_btn_preset_0)

	var btn_cerrar = find_child("BtnCerrarOpacidad", true, false) as Button
	if btn_cerrar and not btn_cerrar.pressed.is_connected(_cerrar_panel_opacidad):
		btn_cerrar.pressed.connect(_cerrar_panel_opacidad)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		var cel = get_tree().get_first_node_in_group("celular")
		if not cel and CelularUI.instance:
			cel = CelularUI.instance
		if cel and cel.has_method("toggle_phone"):
			cel.call("toggle_phone")
		elif has_node("/root/MenuSystem"):
			get_node("/root/MenuSystem").call("alternar_pausa")
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H or event.keycode == KEY_F1:
			_alternar_modo_grabacion()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_O and event.ctrl_pressed:
			_toggle_panel_opacidad()
			get_viewport().set_input_as_handled()

func _on_boton_ocultar_hud_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_toggle_panel_opacidad()
			get_viewport().set_input_as_handled()
			return
		if _usar_solo_screen_touch(event):
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_tiempo_presion_ocultar_ms = Time.get_ticks_msec()
			else:
				var duracion = Time.get_ticks_msec() - _tiempo_presion_ocultar_ms
				if duracion >= 450:
					_toggle_panel_opacidad()
				else:
					_ciclar_preset_opacidad()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_tiempo_presion_ocultar_ms = Time.get_ticks_msec()
		else:
			var duracion = Time.get_ticks_msec() - _tiempo_presion_ocultar_ms
			if duracion >= 450:
				_toggle_panel_opacidad()
			else:
				_ciclar_preset_opacidad()
			get_viewport().set_input_as_handled()

func _alternar_modo_grabacion() -> void:
	if _opacidad_actual <= 0.05:
		aplicar_opacidad_hud(1.0, true)
	else:
		aplicar_opacidad_hud(0.0, true)

func _ciclar_preset_opacidad() -> void:
	_indice_preset_opacidad = (_indice_preset_opacidad + 1) % OPACIDAD_PRESETS.size()
	aplicar_opacidad_hud(OPACIDAD_PRESETS[_indice_preset_opacidad], true)

func _on_btn_preset_100() -> void:
	aplicar_opacidad_hud(1.0, true)

func _on_btn_preset_50() -> void:
	aplicar_opacidad_hud(0.50, true)

func _on_btn_preset_20() -> void:
	aplicar_opacidad_hud(0.20, true)

func _on_btn_preset_0() -> void:
	aplicar_opacidad_hud(0.0, true)
	_cerrar_panel_opacidad()

func _on_slider_opacidad_changed(value: float) -> void:
	aplicar_opacidad_hud(value / 100.0, false)

func _on_boton_restaurar_hud_pressed() -> void:
	aplicar_opacidad_hud(1.0, true)

func _on_boton_restaurar_mouse_entered() -> void:
	if boton_restaurar_hud and boton_restaurar_hud.visible:
		var t = create_tween()
		t.tween_property(boton_restaurar_hud, "modulate:a", 0.9, 0.15)

func _on_boton_restaurar_mouse_exited() -> void:
	if boton_restaurar_hud and boton_restaurar_hud.visible and _opacidad_actual <= 0.05:
		var t = create_tween()
		t.tween_property(boton_restaurar_hud, "modulate:a", 0.25, 0.2)

func aplicar_opacidad_hud(valor: float, animar: bool = true) -> void:
	_opacidad_actual = clampf(valor, 0.0, 1.0)
	
	if slider_opacidad and not slider_opacidad.has_focus():
		slider_opacidad.set_value_no_signal(roundi(_opacidad_actual * 100.0))
	if label_porcentaje_opacidad:
		label_porcentaje_opacidad.text = "Opacidad actual: %d%%" % roundi(_opacidad_actual * 100.0)
	
	for i in range(OPACIDAD_PRESETS.size()):
		if is_equal_approx(_opacidad_actual, OPACIDAD_PRESETS[i]):
			_indice_preset_opacidad = i
			break
	
	# Recopilar contenedor principal del HUD para modular sin duplicar alpha en nodos hijos
	var nodos_hud: Array[CanvasItem] = []
	var sa = get_node_or_null("SafeArea") as CanvasItem
	if sa:
		nodos_hud.append(sa)
	
	var duracion = 0.25 if animar else 0.0
	if _tween_opacidad and _tween_opacidad.is_valid():
		_tween_opacidad.kill()
	
	if animar:
		_tween_opacidad = create_tween()
		_tween_opacidad.set_parallel(true)
		_tween_opacidad.set_ease(Tween.EASE_OUT)
		_tween_opacidad.set_trans(Tween.TRANS_QUAD)
		for nodo in nodos_hud:
			if is_instance_valid(nodo):
				_tween_opacidad.tween_property(nodo, "modulate:a", _opacidad_actual, duracion)
	else:
		for nodo in nodos_hud:
			if is_instance_valid(nodo):
				nodo.modulate.a = _opacidad_actual
	
	# Botón de restauración flotante para salir del modo grabación
	if boton_restaurar_hud:
		if _opacidad_actual <= 0.05:
			boton_restaurar_hud.visible = true
			if animar:
				var t_btn = create_tween()
				t_btn.tween_property(boton_restaurar_hud, "modulate:a", 0.25, 0.3)
			else:
				boton_restaurar_hud.modulate.a = 0.25
		else:
			boton_restaurar_hud.visible = false
			boton_restaurar_hud.modulate.a = 0.0
	
	# Control de clicks accidentales en botones secundarios si está 100% oculto
	var menu_ctrl = get_node_or_null("Control") as Control
	if menu_ctrl:
		menu_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE if _opacidad_actual <= 0.05 else Control.MOUSE_FILTER_PASS

	_mostrar_toast_hud()

func _mostrar_toast_hud() -> void:
	if not label_toast_hud:
		return
	
	var porcentaje = roundi(_opacidad_actual * 100.0)
	var mensaje = ""
	if porcentaje <= 0:
		mensaje = "INTERFAZ OCULTA (Presiona H o toca HUD para restaurar)"
	elif porcentaje <= 20:
		mensaje = "OPACIDAD HUD: %d%%" % porcentaje
	elif porcentaje <= 55:
		mensaje = "OPACIDAD HUD: %d%%" % porcentaje
	else:
		mensaje = "OPACIDAD HUD: %d%%" % porcentaje
	
	label_toast_hud.text = mensaje
	label_toast_hud.visible = true
	
	if _tween_toast and _tween_toast.is_valid():
		_tween_toast.kill()
		
	_tween_toast = create_tween()
	_tween_toast.tween_property(label_toast_hud, "modulate:a", 1.0, 0.2)
	_tween_toast.tween_interval(1.8)
	_tween_toast.tween_property(label_toast_hud, "modulate:a", 0.0, 0.4)
	_tween_toast.tween_callback(func(): label_toast_hud.visible = false)

func _toggle_panel_opacidad() -> void:
	if not panel_opacidad_hud:
		return
	if panel_opacidad_hud.visible:
		_cerrar_panel_opacidad()
	else:
		_abrir_panel_opacidad()

func _abrir_panel_opacidad() -> void:
	if not panel_opacidad_hud:
		return
	panel_opacidad_hud.visible = true
	panel_opacidad_hud.modulate.a = 0.0
	panel_opacidad_hud.scale = Vector2(0.85, 0.85)
	if slider_opacidad:
		slider_opacidad.set_value_no_signal(roundi(_opacidad_actual * 100.0))
	if label_porcentaje_opacidad:
		label_porcentaje_opacidad.text = "Opacidad actual: %d%%" % roundi(_opacidad_actual * 100.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel_opacidad_hud, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel_opacidad_hud, "scale", Vector2(1.0, 1.0), 0.25)

func _cerrar_panel_opacidad() -> void:
	if not panel_opacidad_hud or not panel_opacidad_hud.visible:
		return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel_opacidad_hud, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel_opacidad_hud, "scale", Vector2(0.85, 0.85), 0.2)
	tween.chain().tween_callback(func(): panel_opacidad_hud.visible = false)




