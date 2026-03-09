# coche.gd
extends RigidBody3D

@export_group("Componentes")
@onready var motor = $Motor
@onready var llantas_controlador = $ControladorLlantas
@onready var ui_vehiculo = $UIVehiculo
@onready var chasis_visual = $Cuerpo2/Plane

# Cámaras hardcodeadas según tu árbol de escena
@onready var cam_externa  = $Cams_pivot/Cam_Externa
@onready var cam_interna  = $AsientoConductor/Cam_Interna
@onready var cam_brazo    = $BrazoCamara/SpringArm3D/Camera3D
@onready var brazo_camara = $BrazoCamara
@onready var spring_arm   = $BrazoCamara/SpringArm3D

@export_group("Física")
@export var masa_kg: float = 2500.0  # Reducido de 8500 a 2500kg
@export var centro_de_masa: Vector3 = Vector3(0, -0.3, 0.2)  # Más bajo y centrado
@export var estabilizacion_trasera: float = 0.8
@export var arrastre_cuadratico: float = 0.8
@export var velocidad_min_arrastre: float = 1.0
@export var umbral_enderezado: float = 0.7
@export var torque_enderezado: float = 50000.0
@export var umbral_deslizamiento_lateral: float = 0.1
@export var velocidad_min_estabilizacion: float = 0.5
@export var brazo_estabilizacion_trasera: float = 2.0
@export var salida_offset_lateral_desde_zona: float = 1.25
@export var salida_offset_vertical: float = 0.15

var activo: bool = false
var jugador_ref: Node3D = null
var jugador_cerca: bool = false
var nivel_suciedad: float = 0.0
var nivel_barro: float = 0.0
var nivel_mojado: float = 0.0
var indice_camara: int = 0

func _ready() -> void:
	add_to_group("vehiculo")
	mass = masa_kg

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = centro_de_masa

	freeze = true

	if ui_vehiculo:
		ui_vehiculo.visible = false

	_alternar_sistemas(false)
	_conectar_deteccion()

	# Conectar señal del GameManager
	GameManager.camara_cambiada.connect(_al_cambiar_camara)

	if chasis_visual:
		chasis_visual.set_instance_shader_parameter("dirt_amount", 0.0)
		chasis_visual.set_instance_shader_parameter("mud_amount",  0.0)
		chasis_visual.set_instance_shader_parameter("wet_amount",  0.0)

# ════════════════════════════════════════════════════════════════════
#  CÁMARAS
# ════════════════════════════════════════════════════════════════════

func _al_cambiar_camara(id: int) -> void:
	indice_camara = id

	match id:
		0:
			# Cámara externa fija en Cams_pivot
			if cam_externa:
				cam_externa.make_current()
				spring_arm.set_process(false)
			else:
				push_warning("coche.gd: cam_externa no existe, usando cámara alternativa")
				if cam_interna:
					cam_interna.make_current()

		1:
			# Cámara interna del conductor
			if cam_interna:
				cam_interna.make_current()
				spring_arm.set_process(false)
			else:
				push_warning("coche.gd: cam_interna no existe")

		2:
			# Cámara del BrazoCamara con SpringArm (orbital)
			if cam_brazo and spring_arm:
				cam_brazo.make_current()
				spring_arm.set_process(true)
			else:
				push_warning("coche.gd: cam_brazo o spring_arm no existe")

func _on_camara_movida(relative: Vector2) -> void:
	if not activo: return

	var sensibilidad = 0.2

	match indice_camara:
		0:
			# Cámara externa: rota el pivot
			$Cams_pivot.rotation_degrees.y -= relative.x * sensibilidad
			$Cams_pivot.rotation_degrees.x -= relative.y * sensibilidad
			$Cams_pivot.rotation_degrees.x  = clamp($Cams_pivot.rotation_degrees.x, -50.0, 25.0)
		1:
			# Cámara interna: rota la cámara directamente
			cam_interna.rotation_degrees.y -= relative.x * (sensibilidad * 0.7)
			cam_interna.rotation_degrees.x -= relative.y * (sensibilidad * 0.7)
			cam_interna.rotation_degrees.x  = clamp(cam_interna.rotation_degrees.x, -45.0, 45.0)
			cam_interna.rotation_degrees.y  = clamp(cam_interna.rotation_degrees.y, -110.0, 110.0)
		2:
			# BrazoCamara: rota el SpringArm
			spring_arm.rotation_degrees.y -= relative.x * sensibilidad
			spring_arm.rotation_degrees.x -= relative.y * sensibilidad
			spring_arm.rotation_degrees.x  = clamp(spring_arm.rotation_degrees.x, -50.0, 25.0)

# ════════════════════════════════════════════════════════════════════
#  SUBIR / BAJAR
# ════════════════════════════════════════════════════════════════════

func subir_jugador(p_jugador: Node3D) -> void:
	if activo: return
	activo = true
	freeze = false
	jugador_ref = p_jugador

	var ui_pie = p_jugador.find_child("UIpie", true, false)
	if ui_pie:
		ui_pie.visible = false

	if ui_vehiculo:
		ui_vehiculo.visible = true

	# Usar el nuevo sistema de InputVehiculo
	InputVehiculo.start_driving()
	# NO encender motor ni cambiar marcha automáticamente
	# El jugador debe arrancar manualmente después de subir

	p_jugador.hide()
	p_jugador.process_mode = Node.PROCESS_MODE_DISABLED

	_conectar_senales_ui()
	_alternar_sistemas(true)

	# Iniciar con cámara externa al subir
	GameManager.indice_camara = 0
	_al_cambiar_camara(0)

func bajar_jugador() -> void:
	if not activo: return
	activo = false

	if is_instance_valid(jugador_ref):
		var posicion_salida: Vector3 = global_position + (global_transform.basis.x * 3.5)
		var zona_entrada: Node3D = get_node_or_null("ZonaEntrada") as Node3D
		if zona_entrada:
			var dir_menos_x: Vector3 = -global_transform.basis.x.normalized()
			posicion_salida = zona_entrada.global_position + (dir_menos_x * salida_offset_lateral_desde_zona)
			posicion_salida.y += salida_offset_vertical

		var ui_pie = jugador_ref.find_child("UIpie", true, false)
		if ui_pie: ui_pie.visible = true

		jugador_ref.show()
		jugador_ref.process_mode = Node.PROCESS_MODE_INHERIT
		jugador_ref.global_position = posicion_salida

		var cam_p = jugador_ref.find_child("Camera3D", true, false)
		if cam_p: cam_p.make_current()

	if ui_vehiculo:
		ui_vehiculo.visible = false

	# Usar el nuevo sistema de InputVehiculo
	InputVehiculo.stop_driving()
	spring_arm.set_process(false)
	_alternar_sistemas(false)

# ════════════════════════════════════════════════════════════════════
#  SUCIEDAD
# ════════════════════════════════════════════════════════════════════

func notificar_impacto_vidrio(fuerza: float) -> void:
	for hijo in get_children():
		if hijo.has_method("check_collision_impact"):
			hijo.check_collision_impact(fuerza)

func notificar_suciedad(incremento: float) -> void:
	nivel_suciedad = clamp(nivel_suciedad + incremento, 0.0, 1.0)
	if chasis_visual:
		chasis_visual.set_instance_shader_parameter("dirt_amount", nivel_suciedad)

func notificar_barro(incremento: float) -> void:
	nivel_barro    = clamp(nivel_barro + incremento, 0.0, 1.0)
	nivel_suciedad = clamp(nivel_suciedad - incremento * 0.5, 0.0, 1.0)
	if chasis_visual:
		chasis_visual.set_instance_shader_parameter("mud_amount",  nivel_barro)
		chasis_visual.set_instance_shader_parameter("dirt_amount", nivel_suciedad)

func notificar_mojado(valor: float) -> void:
	nivel_mojado = clamp(valor, 0.0, 1.0)
	if chasis_visual:
		chasis_visual.set_instance_shader_parameter("wet_amount", nivel_mojado)

func limpiar_suciedad(cantidad: float) -> void:
	nivel_suciedad = clamp(nivel_suciedad - cantidad, 0.0, 1.0)
	nivel_barro    = clamp(nivel_barro    - cantidad, 0.0, 1.0)
	if chasis_visual:
		chasis_visual.set_instance_shader_parameter("dirt_amount", nivel_suciedad)
		chasis_visual.set_instance_shader_parameter("mud_amount",  nivel_barro)

# ════════════════════════════════════════════════════════════════════
#  DETECCIÓN
# ════════════════════════════════════════════════════════════════════

func _conectar_deteccion() -> void:
	for hijo in get_children():
		if hijo is Area3D:
			hijo.body_entered.connect(_on_body_entered)
			hijo.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		jugador_cerca = true
		jugador_ref   = body

func _on_body_exited(body: Node3D) -> void:
	if body == jugador_ref and not activo:
		jugador_cerca = false
		jugador_ref   = null

# ════════════════════════════════════════════════════════════════════
#  SISTEMAS INTERNOS
# ════════════════════════════════════════════════════════════════════

func _alternar_sistemas(estado: bool) -> void:
	if is_instance_valid(motor):
		motor.set_physics_process(estado)
	if is_instance_valid(llantas_controlador):
		llantas_controlador.set_physics_process(estado)

func _conectar_senales_ui() -> void:
	if not ui_vehiculo: return

	var zona_cam = ui_vehiculo.find_child("ZonaCamara", true, false)
	if zona_cam and zona_cam.has_signal("camara_movida"):
		if not zona_cam.camara_movida.is_connected(_on_camara_movida):
			zona_cam.camara_movida.connect(_on_camara_movida)

# ════════════════════════════════════════════════════════════════════
#  FÍSICA
# ════════════════════════════════════════════════════════════════════

func _physics_process(_delta: float) -> void:
	if not activo: return

	var v_vel = linear_velocity.length()
	
	# Arrastre aerodinámico
	if v_vel > velocidad_min_arrastre:
		var f_drag = -linear_velocity.normalized() * (v_vel * v_vel * arrastre_cuadratico)
		apply_central_force(f_drag)

	# Sistema de enderezado automático
	var up_actual   = global_transform.basis.y
	var inclinacion = up_actual.dot(Vector3.UP)
	if inclinacion < umbral_enderezado:
		var eje_correccion = up_actual.cross(Vector3.UP)
		apply_torque(eje_correccion * (1.0 - inclinacion) * torque_enderezado)

	# Estabilización trasera contra derrapes
	var inv_basis = global_transform.basis.inverse()
	var vel_local = inv_basis * linear_velocity
	var v_lateral = vel_local.x

	if abs(v_lateral) > umbral_deslizamiento_lateral and v_vel > velocidad_min_estabilizacion:
		var punto_trasero = global_transform.basis * Vector3(0, 0, brazo_estabilizacion_trasera)
		var fuerza_estab  = -global_transform.basis.x * v_lateral * masa_kg * estabilizacion_trasera
		apply_force(fuerza_estab, punto_trasero)

# ════════════════════════════════════════════════════════════════════
#  DEBUG
# ════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_U:
			notificar_suciedad(0.1)
		if event.keycode == KEY_B:
			notificar_barro(0.1)
		if event.keycode == KEY_M:
			notificar_mojado(min(nivel_mojado + 0.1, 1.0))
		if event.keycode == KEY_I:
			nivel_suciedad = 0.0
			nivel_barro    = 0.0
			nivel_mojado   = 0.0
			if chasis_visual:
				chasis_visual.set_instance_shader_parameter("dirt_amount", 0.0)
				chasis_visual.set_instance_shader_parameter("mud_amount",  0.0)
				chasis_visual.set_instance_shader_parameter("wet_amount",  0.0)
