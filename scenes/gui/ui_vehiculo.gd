# ui_vehiculo.gd
extends CanvasLayer

@export var vehiculo_path: NodePath

# --- VARIABLES DE ESTADO ---
var vehiculo: RigidBody3D
var _motor_ref: Node
const COOLDOWN_CAMARA_MS: int = 180
var _ultimo_cambio_camara_ms: int = -10000
var _motor_activo: bool = false
var _freno_mano_activo: bool = false
var _menu_desplegado: bool = false
var _ultimo_toggle_menu_ms: int = 0
const COOLDOWN_MENU_MS: int = 400

# --- NODOS DE UI ---
@onready var label_marcha     = get_node_or_null("SafeArea/Interface/DisplayMarcha")
@onready var label_velocidad  = $SafeArea/Interface/DisplayVelocidad
@onready var boton_motor      = %BotonMotor
@onready var boton_freno_mano = %BotonFrenoMano
@onready var boton_salir      = %BotonSalir
@onready var boton_camara     = %BotonCamara

# Menú desplegable
@onready var tab_menu         = %TabMenu
@onready var panel_contenido  = %PanelContenido

# Nuevo selector de marchas con 4 botones
@onready var selector_marchas = $SafeArea/Interface/SelectorMarchas
@onready var boton_centrar    = get_node_or_null("SafeArea/Interface/PanelVolante/BotonCentrar")
@onready var volante_control  = $SafeArea/Interface/PanelVolante/Volante

# Shader para botones
@export var color_boton_activo: Color = Color.YELLOW
@export var color_boton_inactivo: Color = Color.WHITE
@export var brillo_boton_activo: float = 1.4

# Configuración del menú desplegable
@export var duracion_animacion: float = 0.25

# ════════════════════════════════════════════════════════════════════
#  INICIALIZACIÓN
# ════════════════════════════════════════════════════════════════════

func _ready() -> void:
	self.visible = false

	# Localizar el vehículo
	if vehiculo_path and not vehiculo_path.is_empty():
		vehiculo = get_node(vehiculo_path)
	elif get_parent() is RigidBody3D:
		vehiculo = get_parent()

	if vehiculo:
		_motor_ref = vehiculo.get_node_or_null("Motor")
		if not _motor_ref:
			push_warning("UIVehiculo: No se encontró el nodo 'Motor' en el vehículo.")

	# Aplicar shader a los botones
	_aplicar_shader_botones()
	_sincronizar_estado_motor()
	_motor_activo = true

	# Conectar controles táctiles/click
	if boton_camara:
		if not boton_camara.gui_input.is_connected(_on_boton_camara_input):
			boton_camara.gui_input.connect(_on_boton_camara_input)

	if boton_motor:
		# Encendido desactivado temporalmente: ocultar control para evitar confusión.
		boton_motor.visible = false
		boton_motor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if boton_freno_mano:
		if not boton_freno_mano.gui_input.is_connected(_on_boton_freno_mano_input):
			boton_freno_mano.gui_input.connect(_on_boton_freno_mano_input)

	if boton_salir:
		if not boton_salir.gui_input.is_connected(_on_boton_salir_input):
			boton_salir.gui_input.connect(_on_boton_salir_input)
	
	# Conectar botón de centrar volante
	if boton_centrar:
		if not boton_centrar.pressed.is_connected(_on_centrar_volante):
			boton_centrar.pressed.connect(_on_centrar_volante)
	
	# Configurar menú desplegable
	_configurar_menu_desplegable()

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

	# Mostrar Marcha Actual
	if label_marcha:
		label_marcha.text = _get_texto_marcha()

	# Velocidad en KM/H
	var kmh: int = int(vehiculo.linear_velocity.length() * 3.6)
	if label_velocidad:
		label_velocidad.text = str(kmh) + " km/h"
	
	# Actualizar color del botón de motor
	_actualizar_color_botones()

# ════════════════════════════════════════════════════════════════════
#  EVENTOS DE BOTONES
# ════════════════════════════════════════════════════════════════════

func _on_cambiar_camara() -> void:
	var ahora_ms: int = Time.get_ticks_msec()
	if ahora_ms - _ultimo_cambio_camara_ms < COOLDOWN_CAMARA_MS:
		return
	_ultimo_cambio_camara_ms = ahora_ms
	if GameManager and GameManager.has_method("cambiar_camara_global"):
		GameManager.cambiar_camara_global()

func _on_boton_motor_toggle(activo: bool) -> void:
	_motor_activo = true
	if not is_instance_valid(InputVehiculo):
		return
	InputVehiculo.set_motor_encendido(true)

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

func _on_boton_freno_mano_input(event: InputEvent) -> void:
	if _es_inicio_presion(event):
		_freno_mano_activo = true
		_on_freno_mano_down()
		get_viewport().set_input_as_handled()
		return
	if _es_fin_presion(event):
		_freno_mano_activo = false
		_on_freno_mano_up()
		get_viewport().set_input_as_handled()

func _on_freno_mano_down() -> void:
	if not is_instance_valid(InputVehiculo):
		return
	InputVehiculo.freno_mano = true

func _on_freno_mano_up() -> void:
	if not is_instance_valid(InputVehiculo):
		return
	InputVehiculo.freno_mano = false

func _on_boton_salir() -> void:
	if vehiculo:
		var jugador = vehiculo.get("jugador_ref")
		if jugador and jugador.has_method("salir_del_vehiculo"):
			jugador.salir_del_vehiculo()
			return
	if vehiculo and vehiculo.has_method("bajar_jugador"):
		vehiculo.bajar_jugador()

func _on_centrar_volante() -> void:
	if is_instance_valid(InputVehiculo):
		InputVehiculo.centrar_direccion()
	if volante_control and volante_control.has_method("centrar_volante"):
		volante_control.centrar_volante()

# ════════════════════════════════════════════════════════════════════
#  UTILIDADES
# ════════════════════════════════════════════════════════════════════

func _actualizar_color_botones() -> void:
	# Actualizar estado visual del nuevo MotorSwitch
	if boton_motor and boton_motor.has_method("set_activo"):
		boton_motor.set_activo(_motor_activo)
	
	# Actualizar shader del botón de freno mano
	if boton_freno_mano and boton_freno_mano.material is ShaderMaterial:
		boton_freno_mano.material.set_shader_parameter("activo", _freno_mano_activo)

func _es_presion_primaria(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _es_inicio_presion(event: InputEvent) -> bool:
	return _es_presion_primaria(event)

func _es_fin_presion(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	return false

func _get_texto_marcha() -> String:
	if not is_instance_valid(InputVehiculo):
		return "N"
	return InputVehiculo.marcha

func _sincronizar_estado_motor() -> void:
	if is_instance_valid(InputVehiculo):
		_motor_activo = true
		InputVehiculo.motor_encendido = true

# ════════════════════════════════════════════════════════════════════
#  MENÚ DESPLEGABLE
# ════════════════════════════════════════════════════════════════════

func _configurar_menu_desplegable() -> void:
	if not panel_contenido or not tab_menu:
		push_warning("UIVehiculo: No se encontraron los nodos del menú desplegable.")
		return
	
	print("UIVehiculo: Configurando menú desplegable...")
	print("  - TabMenu encontrado: ", tab_menu != null)
	print("  - PanelContenido encontrado: ", panel_contenido != null)
	
	# Inicialmente ocultar el panel
	panel_contenido.visible = false
	panel_contenido.modulate.a = 0.0
	panel_contenido.scale = Vector2(0.8, 0.8)
	_menu_desplegado = false
	
	# Conectar el evento de clic en el tab
	if not tab_menu.gui_input.is_connected(_on_tab_menu_input):
		tab_menu.gui_input.connect(_on_tab_menu_input)
		print("  - Evento gui_input conectado al TabMenu")

func _on_tab_menu_input(event: InputEvent) -> void:
	# Solo procesar cuando se PRESIONA, no cuando se suelta
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var ahora_ms = Time.get_ticks_msec()
			if ahora_ms - _ultimo_toggle_menu_ms < COOLDOWN_MENU_MS:
				print("UIVehiculo: Cooldown activo, ignorando click")
				return
			_ultimo_toggle_menu_ms = ahora_ms
			print("UIVehiculo: Tab menu presionado! Estado actual: ", _menu_desplegado)
			_toggle_menu()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var ahora_ms = Time.get_ticks_msec()
			if ahora_ms - _ultimo_toggle_menu_ms < COOLDOWN_MENU_MS:
				print("UIVehiculo: Cooldown activo, ignorando toque")
				return
			_ultimo_toggle_menu_ms = ahora_ms
			print("UIVehiculo: Tab menu tocado! Estado actual: ", _menu_desplegado)
			_toggle_menu()
			get_viewport().set_input_as_handled()

func _toggle_menu() -> void:
	_menu_desplegado = not _menu_desplegado
	print("UIVehiculo: Cambiando estado del menú a: ", "ABIERTO" if _menu_desplegado else "CERRADO")
	_animar_menu()

func _animar_menu() -> void:
	if not panel_contenido:
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	
	if _menu_desplegado:
		# Mostrar el menú con animación
		panel_contenido.visible = true
		tween.tween_property(panel_contenido, "modulate:a", 1.0, duracion_animacion)
		tween.tween_property(panel_contenido, "scale", Vector2(1.0, 1.0), duracion_animacion)
	else:
		# Ocultar el menú con animación
		tween.tween_property(panel_contenido, "modulate:a", 0.0, duracion_animacion)
		tween.tween_property(panel_contenido, "scale", Vector2(0.8, 0.8), duracion_animacion)
		tween.chain().tween_callback(func(): panel_contenido.visible = false)

