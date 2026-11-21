# coche_auto.gd - Chasis independiente para automóviles ligeros
extends RigidBody3D

# --- Parámetros de Configuración del Chasis ---
@export var config: Resource
@export var activo: bool = false
@export var jugador_cerca: bool = false
@export var jugador_ref: Node3D = null
@export var debug_vehiculo: bool = false

@export_group("Chasis Automóvil")
@export var masa_kg: float = 1550.0
@export var centro_de_masa: Vector3 = Vector3(0.0, -0.48, 0.0)
@export var torque_antiroll: float = 18000.0
@export var amort_antiroll: float = 5000.0

# --- Referencias a Componentes Internos ---
var motor: Node3D = null
var spring_arm: SpringArm3D = null
var camera_manager: Node3D = null
var ui_vehiculo: CanvasLayer = null
var icono_entrada: Node3D = null

@export_group("Icono Entrada Diegético")
## Offset manual para calibrar la posición 3D del botón de entrada (ej: Vector3(0, 0.2, 0))
@export var offset_icono_entrada: Vector3 = Vector3.ZERO

# --- Variables de API de Compatibilidad ---
var luces_emergencia: bool = false
var direccional_izquierda: bool = false
var direccional_derecha: bool = false
var luz_stop_node: Node = null
var luz_delantera_node: Node = null
var luz_direccional_node: Node = null
var retrovisores_node: Node = null

var llantas_todas: Array[RayCast3D] = []
var llantas_directrices: Array[RayCast3D] = []
var llantas_motrices: Array[RayCast3D] = []

# --- Variables de Control y Estado ---
var _ruedas_todas: Array[RayCast3D] = []
var _vel_previa: Vector3 = Vector3.ZERO
var _pos_segura_mapa: Vector3 = Vector3.ZERO
var _jugador_cam_node: Camera3D = null
var _jugador_cam_original_parent: Node = null
var _jugador_cam_original_global_transform: Transform3D = Transform3D()
var salida_offset_vertical: float = 0.5
var salida_offset_lateral: float = 1.6

func _ready() -> void:
	add_to_group("vehiculo")
	# Localización de nodos internos y componentes bajo la raíz del chasis
	motor = get_node_or_null("Motor")
	spring_arm = find_child("SpringArm3D", true, false) as SpringArm3D
	camera_manager = find_child("CameraManager", true, false)
	luz_stop_node = find_child("*traseras*", true, false)
	if luz_stop_node == null:
		luz_stop_node = find_child("*Traseras*", true, false)
	if luz_stop_node == null:
		luz_stop_node = find_child("*stop*", true, false)
	if luz_stop_node == null:
		luz_stop_node = find_child("*Stop*", true, false)

	luz_delantera_node = find_child("*delanteras*", true, false)
	if luz_delantera_node == null:
		luz_delantera_node = find_child("*Delanteras*", true, false)

	luz_direccional_node = find_child("*direccionales*", true, false)
	if luz_direccional_node == null:
		luz_direccional_node = find_child("*Direccionales*", true, false)

	retrovisores_node = find_child("*retrovisores*", true, false)
	if retrovisores_node == null:
		retrovisores_node = find_child("*Retrovisores*", true, false)

	# Recolección recursiva de ruedas en el árbol de nodos
	_ruedas_todas.clear()
	_buscar_ruedas_recursivo(self)

	# Configuración de propiedades físicas del RigidBody3D
	mass = masa_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = centro_de_masa
	linear_damp = 0.05
	angular_damp = 1.2
	
	# Desactivación inicial de procesamiento físico
	_alternar_sistemas(false)
	_activar_luces(false)
	_conectar_deteccion()
	add_to_group("vehiculo")
	add_to_group("vehiculo_jugador")
	var gv_ini := get_node_or_null("/root/GestorVehiculos")
	if gv_ini and gv_ini.has_method("restaurar_ubicacion_vehiculo"):
		gv_ini.call("restaurar_ubicacion_vehiculo", self)
	freeze = false
	can_sleep = false


func _buscar_ruedas_recursivo(node: Node) -> void:
	# Recorrido recursivo para clasificar las ruedas del vehículo
	for child in node.get_children():
		if child is RayCast3D:
			_ruedas_todas.append(child)
			llantas_todas.append(child)
			if child.get("es_directriz") == true:
				llantas_directrices.append(child)
			else:
				llantas_motrices.append(child)
		_buscar_ruedas_recursivo(child)

func _physics_process(delta: float) -> void:
	var gv_seg = get_node_or_null("/root/GestorVehiculos")
	if gv_seg and gv_seg.has_method("asegurar_vehiculo_sobre_mapa"):
		_pos_segura_mapa = gv_seg.asegurar_vehiculo_sobre_mapa(self, _pos_segura_mapa)
	if not activo:
		return
	
	# Estabilización anti-vuelco (Antiroll) basada en la inclinación local del chasis
	var local_up = global_transform.basis.y
	var dot_up = local_up.dot(Vector3.UP)
	if dot_up < 0.998:
		var angulo_roll = acos(clamp(dot_up, -1.0, 1.0))
		var eje_roll = Vector3.UP.cross(local_up).normalized()
		if eje_roll.length_squared() > 0.001:
			var decay = clamp((dot_up - 0.25) / 0.70, 0.0, 1.0)
			var torque_muelle = -eje_roll * (torque_antiroll * angulo_roll * decay)
			var omega_roll = angular_velocity.dot(eje_roll)
			var torque_amort = -eje_roll * (amort_antiroll * omega_roll * decay)
			apply_torque(torque_muelle + torque_amort)

	# Control dinámico de distancia de cámara basado en la aceleración del chasis
	if spring_arm and activo:
		var accel: float = (linear_velocity - _vel_previa).length() / maxf(delta, 0.001)
		var intensidad: float = clamp(accel * 0.008, -0.25, 0.25)
		spring_arm.position.z = lerp(spring_arm.position.z, intensidad, clamp(delta * 4.0, 0.0, 1.0))

	_vel_previa = linear_velocity

func subir_jugador(p_jugador: Node3D) -> void:
	# Transición de control al abordar el vehículo
	if activo:
		return
	activo = true
	jugador_ref = p_jugador
	if is_instance_valid(icono_entrada) and icono_entrada.has_method("ocultar"):
		icono_entrada.ocultar()
	GestorVehiculos.subir_jugador_a_vehiculo(p_jugador, self)
	
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Creación e inyección de la interfaz gráfica de conducción
	if not ui_vehiculo:
		var ui_scene := load("res://interfaz/hud/conduccion/UIVehiculo.tscn") as PackedScene
		if ui_scene:
			ui_vehiculo = ui_scene.instantiate() as CanvasLayer
			add_child(ui_vehiculo)

	if ui_vehiculo:
		ui_vehiculo.set("vehiculo", self)
		ui_vehiculo.visible = true
		var speed_max_kmh = 180.0
		var rpm_max_val = 6000.0
		ui_vehiculo.set("velocidad_maxima", speed_max_kmh)
		ui_vehiculo.set("rpm_maxima", rpm_max_val)
		
		var dash = ui_vehiculo.find_child("Dashboard", true, false)
		if dash:
			dash.set("vehicle", self)
			dash.set("speedometer_max", speed_max_kmh)
			if dash.has_method("_ensure_rpm_source"):
				dash.call("_ensure_rpm_source")

	# Activación de banderas de entrada del conductor en el singleton
	var iv = _get_iv()
	if iv:
		iv.set("conduciendo", true)
		iv.call("set_marcha_enum", iv.get("Marcha").NEUTRO)
		iv.set("freno_mano", false)
		iv.set("motor_encendido", true)

	_alternar_sistemas(true)
	_activar_luces(true)

	# Vinculación de la cámara del jugador al SpringArm del coche
	p_jugador.process_mode = Node.PROCESS_MODE_INHERIT
	var cam_p: Camera3D = p_jugador.find_child("Camera3D", true, false) as Camera3D
	if cam_p:
		cam_p.current = false

	_conectar_senales_ui()
	activar_camara(0)

func bajar_jugador() -> void:
	# Transición de control al abandonar el vehículo
	if not activo:
		return
	activo = false

	# Restablecimiento de los valores de entrada en el singleton
	var iv = _get_iv()
	if iv:
		iv.set("conduciendo", false)
		iv.set("gas", 0.0)
		iv.set("freno", 0.0)
		iv.set("direccion", 0.0)
		iv.set("freno_mano", true)

	if is_instance_valid(jugador_ref):
		var zona = find_child("ZonaEntrada", true, false) as Area3D
		var posicion_salida: Vector3
		if zona and is_instance_valid(zona):
			posicion_salida = zona.global_position - global_transform.basis.x.normalized() * 0.6
			posicion_salida.y = zona.global_position.y + 0.1
		else:
			posicion_salida = global_position - global_transform.basis.x.normalized() * salida_offset_lateral
			posicion_salida.y = global_position.y + salida_offset_vertical

		GestorVehiculos.bajar_jugador_de_vehiculo(jugador_ref, self, posicion_salida)
		if GestorVehiculos.has_method("guardar_ubicacion_vehiculo"):
			GestorVehiculos.guardar_ubicacion_vehiculo(self)
		jugador_ref = null

	_alternar_sistemas(false)
	_activar_luces(false)

	if camera_manager and camera_manager.has_method("desactivar_camaras"):
		camera_manager.call("desactivar_camaras")
	elif spring_arm:
		var c = spring_arm.find_child("Camera3D", true, false) as Camera3D
		if c: c.current = false

	freeze = false

func activar_camara(cam_id: int) -> void:
	if camera_manager:
		if camera_manager.has_method("_conectar_ui"):
			camera_manager.call("_conectar_ui")
		if camera_manager.has_method("activar_camaras"):
			camera_manager.call("activar_camaras", cam_id)
		elif camera_manager.has_method("seleccionar_camara"):
			camera_manager.call("seleccionar_camara", cam_id, true)
		elif camera_manager.has_method("activar_camara"):
			camera_manager.call("activar_camara", cam_id)
	elif spring_arm:
		var c = spring_arm.find_child("Camera3D", true, false) as Camera3D
		if c: c.make_current()

func _alternar_sistemas(estado: bool) -> void:
	# Encendido o apagado de los procesos de ruedas y motor
	if is_instance_valid(motor):
		motor.set_physics_process(estado)
	for rueda in _ruedas_todas:
		if is_instance_valid(rueda):
			rueda.set_physics_process(true) # Suspensión activa para colisiones y caídas de coche desocupado

func _activar_luces(presente: bool) -> void:
	if is_instance_valid(luz_stop_node) and luz_stop_node.has_method("set_conductor_presente"):
		luz_stop_node.set_conductor_presente(presente)
	if is_instance_valid(luz_delantera_node) and luz_delantera_node.has_method("set_conductor_presente"):
		luz_delantera_node.set_conductor_presente(presente)
	if is_instance_valid(luz_direccional_node) and luz_direccional_node.has_method("set_conductor_presente"):
		luz_direccional_node.set_conductor_presente(presente)
	if is_instance_valid(retrovisores_node) and retrovisores_node.has_method("set_conductor_presente"):
		retrovisores_node.set_conductor_presente(presente)

func _asegurar_icono_entrada(zona: Area3D) -> void:
	if is_instance_valid(icono_entrada):
		return
	icono_entrada = find_child("IconoEntradaVehiculo", true, false)
	if not icono_entrada and zona:
		var icono_script = load("res://codigo/entidades/vehiculo/icono_entrada_vehiculo.gd")
		if icono_script:
			var icono_inst = icono_script.new()
			icono_inst.name = "IconoEntradaVehiculo"
			zona.add_child(icono_inst)
			if offset_icono_entrada != Vector3.ZERO:
				icono_inst.offset_posicion = offset_icono_entrada
			icono_inst.configurar(self, zona)
			icono_entrada = icono_inst

func _conectar_deteccion() -> void:
	var zona: Area3D = find_child("ZonaEntrada", true, false) as Area3D
	if zona:
		if not zona.body_entered.is_connected(_on_body_entered):
			zona.body_entered.connect(_on_body_entered)
		if not zona.body_exited.is_connected(_on_body_exited):
			zona.body_exited.connect(_on_body_exited)
		_asegurar_icono_entrada(zona)

func _on_body_entered(body: Node3D) -> void:
	if body and body.is_in_group("jugador") and not activo:
		jugador_cerca = true
		jugador_ref = body
		if is_instance_valid(icono_entrada) and icono_entrada.has_method("mostrar"):
			icono_entrada.mostrar(body)
		if body.has_method("notificar_vehiculo_cerca"):
			body.notificar_vehiculo_cerca(self)

func _on_body_exited(body: Node3D) -> void:
	if body == jugador_ref and not activo:
		jugador_cerca = false
		jugador_ref = null
		if is_instance_valid(icono_entrada) and icono_entrada.has_method("ocultar"):
			icono_entrada.ocultar()
		if body.has_method("notificar_vehiculo_lejos"):
			body.notificar_vehiculo_lejos(self)

func _conectar_senales_ui() -> void:
	if not is_instance_valid(ui_vehiculo):
		return
	var zona_cam: Node = ui_vehiculo.find_child("ZonaCamara", true, false)
	if not zona_cam:
		return
	if zona_cam.has_method("_buscar_brazo"):
		zona_cam.call("_buscar_brazo")
	if not zona_cam.is_connected("camara_movida", _on_camara_movida):
		zona_cam.connect("camara_movida", _on_camara_movida)

func _on_camara_movida(vector: Vector2) -> void:
	# Enlace de señales táctiles hacia el gestor de cámara
	if camera_manager:
		if camera_manager.has_method("mover_camara"):
			var idx = camera_manager.get("indice_actual")
			camera_manager.call("mover_camara", idx if idx != null else 0, vector)
		elif camera_manager.has_method("_distribuir_entrada_camara"):
			camera_manager.call("_distribuir_entrada_camara", vector)
	elif spring_arm and spring_arm.has_method("rotar_camara"):
		spring_arm.call("rotar_camara", vector)

func _get_iv() -> Node:
	var n = get_node_or_null("/root/InputVehiculo")
	if n: return n
	if is_instance_valid(InputVehiculo): return InputVehiculo
	return null
