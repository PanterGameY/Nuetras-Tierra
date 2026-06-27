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
var _baul_abierto: bool = false
var _menu_desplegado: bool = false
var _ultimo_toggle_menu_ms: int = 0
const COOLDOWN_MENU_MS: int = 400
var _anim_player_baul: AnimationPlayer
var _audio_motor_baul: AudioStreamPlayer3D

# --- NODOS DE UI ---
@onready var label_marcha     = find_child("DisplayMarcha", true, false)
@onready var boton_motor      = find_child("BotonMotor", true, false) as Button
@onready var boton_freno_mano = find_child("BotonFrenoMano", true, false) as Button
@onready var boton_baul       = find_child("BotonBaul", true, false) as Button
@onready var boton_salir      = find_child("BotonSalir", true, false) as Button
@onready var boton_camara     = find_child("BotonCamara", true, false) as Button
@onready var boton_dir_izq    = find_child("BtnDir_izq", true, false) as Button
@onready var boton_dir_der    = find_child("BtnDir_der", true, false) as Button
@onready var boton_bocina     = find_child("Bocina", true, false) as Button


# --- REFERENCIA A DIRECCIONALES DEL VEHÍCULO ---
var _direccionales: Node = null
var _bocina_ref: Node = null

# Menú desplegable
@onready var tab_menu         = find_child("TabMenu", true, false)
@onready var panel_contenido  = find_child("PanelContenido", true, false)

# Nuevo selector de marchas con 4 botones
@onready var selector_marchas = find_child("PanelMarchas", true, false)
@onready var boton_centrar    = find_child("BotonCentrar", true, false)
@onready var volante_control  = find_child("Volante", true, false)

# Shader para botones
@export var color_boton_activo: Color = Color.YELLOW
@export var color_boton_inactivo: Color = Color.WHITE
@export var brillo_boton_activo: float = 1.4

# Configuración del menú desplegable
@export var duracion_animacion: float = 0.25

# Velocímetro
@export var velocidad_maxima: float = 180.0
@export var rpm_maxima: float = 3200.0
@onready var _velo_rect:    ColorRect = get_node_or_null("PanelVelocimetro/VeloRect")
@onready var _label_vel:    Label     = get_node_or_null("PanelVelocimetro/LabelVel")
@onready var _label_rpm:    Label     = get_node_or_null("PanelVelocimetro/LabelRPM")

# Medidor de combustible
@onready var _comb_rect:   ColorRect = get_node_or_null("PanelVelocimetro/FuelBarRect")

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

	# Conectar controles táctiles/click
	if boton_camara:
		if not boton_camara.pressed.is_connected(_on_cambiar_camara):
			boton_camara.pressed.connect(_on_cambiar_camara)

	if boton_motor:
		# Encendido desactivado temporalmente: ocultar control para evitar confusión.
		boton_motor.visible = false
		boton_motor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if boton_freno_mano:
		if not boton_freno_mano.gui_input.is_connected(_on_boton_freno_mano_input):
			boton_freno_mano.gui_input.connect(_on_boton_freno_mano_input)

	if boton_baul:
		if not boton_baul.gui_input.is_connected(_on_boton_baul_input):
			boton_baul.gui_input.connect(_on_boton_baul_input)

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
	# Conectar botón de bocina (presionar/soltar)
	if boton_bocina:
		if not boton_bocina.gui_input.is_connected(_on_bocina_input):
			boton_bocina.gui_input.connect(_on_bocina_input)


	# Crear/registrar botón 'Puertas' dentro de BotonesVehiculo y contenedor dinámico
	# (si no existen, se crean en tiempo de ejecución)
	var botones_vehiculo = panel_contenido.get_node_or_null("BotonesVehiculo") if panel_contenido else null
	if botones_vehiculo:
		var btn_puertas = botones_vehiculo.get_node_or_null("BotonPuertas")
		if not btn_puertas:
			btn_puertas = Button.new()
			btn_puertas.name = "BotonPuertas"
			btn_puertas.text = "Puertas"
			# Intentar asignar script especializado si existe
			var bp_script = load("res://scenes/gui/botonpuertas.gd")
			if bp_script:
				btn_puertas.set_script(bp_script)
			botones_vehiculo.add_child(btn_puertas)
		else:
			# Si el botón ya existe, asegurar que tenga el script
			if not btn_puertas.get_script():
				var bp_script = load("res://scenes/gui/botonpuertas.gd")
				if bp_script:
					btn_puertas.set_script(bp_script)
		if not btn_puertas.pressed.is_connected(_on_boton_puertas_pressed):
			btn_puertas.pressed.connect(_on_boton_puertas_pressed)

	# Configurar menú desplegable
	_configurar_menu_desplegable()

func _on_visibility_changed() -> void:
	if not visible:
		_apagar_bocina()
		if boton_freno_mano and boton_freno_mano.button_pressed:
			boton_freno_mano.button_pressed = false
			_freno_mano_activo = false
			_on_freno_mano_up()

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

	# Mostrar Marcha Actual
	if label_marcha:
		label_marcha.text = _get_texto_marcha()
	# Actualizar color del botón de motor
	_actualizar_color_botones()
	# Velocímetro
	_actualizar_velocimetro()
	# RPM
	_actualizar_rpm()
	# Combustible
	_actualizar_combustible()

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
	# Preferir una fuente dedicada de RPM (ControladorRPM) si existe bajo el Motor
	var rpm_val: float = 0.0
	var rpm_src = null
	if _motor_ref and _motor_ref.has_node("ControladorRPM"):
		rpm_src = _motor_ref.get_node_or_null("ControladorRPM")
	elif _motor_ref:
		# intentar buscar por nombre dentro del motor
		rpm_src = _motor_ref.find_child("ControladorRPM", true, false)
	if rpm_src and rpm_src.has_method("get"):
		var tmp = rpm_src.get("rpm_actual")
		if tmp != null:
			rpm_val = float(tmp)
		elif rpm_src.has_method("get_rpm_norm"):
			# si solo hay normalizado disponible, escalar por rpm_maxima
			rpm_val = float(rpm_src.call("get_rpm_norm")) * rpm_maxima
	else:
		var tmp2 = _motor_ref.get("rpm_motor") if _motor_ref.has_method("get") else null
		if tmp2 != null:
			rpm_val = float(tmp2)
		else:
			# fallback directo a propiedad si existe
			if typeof(_motor_ref.rpm_motor) != TYPE_NIL:
				rpm_val = float(_motor_ref.rpm_motor)
	# Leer rpm_maximas desde motor_config si está disponible
	var rpm_max: float = rpm_maxima
	var cfg = _motor_ref.get("config")
	if cfg and cfg.get("rpm_maximas") != null:
		rpm_max = max(float(cfg.get("rpm_maximas")), 1.0)
	var rpm_n: float = clamp(rpm_val / rpm_max, 0.0, 1.0)
	if _velo_rect:
		var mat := _velo_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("rpm_norm", rpm_n)
	if _label_rpm:
		_label_rpm.text = str(int(rpm_val)) + " rpm"

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
	# Debug: estado antes de intentar salida
	if vehiculo:
		var jref_debug = null
		if vehiculo.has_method("get"):
			jref_debug = vehiculo.get("jugador_ref")
		print("UIVehiculo: vehiculo.jugador_ref=", jref_debug)
		if jref_debug:
			print("UIVehiculo: jugador visible=", jref_debug.visible if jref_debug.has_method("visible") else "n/a", " process_mode=", jref_debug.process_mode if jref_debug.has_method("process_mode") else "n/a")
	var jugador = null
	if vehiculo:
		# Intentar obtener la referencia al jugador registrada en el vehículo
		if vehiculo.has_method("get"):
			jugador = vehiculo.get("jugador_ref")

	# Intentar que el jugador maneje la salida solo si expone el método completo `salir_del_vehiculo`.
	var jugador_manejo: bool = false
	if jugador and jugador.has_method("salir_del_vehiculo"):
		jugador.salir_del_vehiculo()
		jugador_manejo = true

	# Si el jugador no realiza la salida completa, pedir al vehículo que lo haga (fallback seguro).
	if not jugador_manejo:
		if vehiculo and vehiculo.has_method("bajar_jugador"):
			vehiculo.bajar_jugador()
			# Si el jugador solo expone la función visual `salir_vehiculo`, ejecútala para consistencia.
			if jugador and jugador.has_method("salir_vehiculo"):
				jugador.salir_vehiculo()
		else:
			push_warning("UIVehiculo: No se encontró método para bajar al jugador desde UI.")

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
	if is_instance_valid(InputVehiculo):
		InputVehiculo.centrar_direccion()

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
	if is_instance_valid(InputVehiculo):
		if InputVehiculo.has_method("set_direccional"):
			InputVehiculo.set_direccional("izquierda")

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
	if is_instance_valid(InputVehiculo):
		if InputVehiculo.has_method("set_direccional"):
			InputVehiculo.set_direccional("derecha")

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
		var ui_pie = jugador.find_child("UIpie", true, false)
		if ui_pie:
			ui_pie.visible = true

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

		# Restaurar cámara si existe
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
		boton_puertas_node = panel_contenido.get_node_or_null("BotonesVehiculo/BotonPuertas")

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
			btn_encender.modulate = Color(0.0, 1.0, 0.5, 1.0) # Verde neón encendido
		else:
			btn_encender.modulate = Color(1.0, 1.0, 1.0, 1.0) # Blanco neutro apagado

	# Actualizar shader del botón de freno mano
	if boton_freno_mano and boton_freno_mano.material is ShaderMaterial:
		boton_freno_mano.material.set_shader_parameter("activo", _freno_mano_activo)

	# Actualizar shader del botón del baúl
	if boton_baul and boton_baul.material is ShaderMaterial:
		boton_baul.material.set_shader_parameter("activo", _baul_abierto)

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
		# Leer el estado real en el singleton y reflejarlo en la UI
		_motor_activo = !!InputVehiculo.motor_encendido
	else:
		_motor_activo = false

# ════════════════════════════════════════════════════════════════════
#  MENÚ DESPLEGABLE
# ════════════════════════════════════════════════════════════════════

func _configurar_menu_desplegable() -> void:
	if not panel_contenido or not tab_menu:
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



