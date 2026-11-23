# coche_pesado.gd - Chasis independiente para vehículos pesados y tractocamiones
extends RigidBody3D

# --- Parámetros de Configuración del Chasis ---
@export var config: Resource
@export var activo: bool = false
@export var jugador_cerca: bool = false
@export var jugador_ref: Node3D = null

@export_group("Chasis Pesado")
@export var masa_pesado_kg: float = 8500.0
@export var centro_de_masa_pesado: Vector3 = Vector3(0.0, -0.20, -0.80) # Centro de masa bajo y equilibrado sobre los ejes
@export var torque_antiroll: float = 140000.0 # Firme y progresivo para mantener el camión plantado
@export var amort_antiroll: float = 18000.0
## Ángulo máximo de inclinación (roll) en curva para efecto estético de suspensión pesada
@export var angulo_max_ladeo_curva: float = 9.0

@export_group("Física en el Aire (Saltos)")
@export var gravedad_extra_aire_subida: float = 4.5
@export var gravedad_extra_aire_caida: float = 6.5
@export var torque_cabeceo_aire_pesado: float = 8000.0

@export_group("Torsión de Chasis Lateral (Torque Twist)")
## Habilita la inclinación lateral del chasis al acelerar con carga pesada.
@export var habilitar_torque_twist: bool = true
## Intensidad de la inclinación lateral (roll) del chasis.
@export var intensidad_torsion_roll: float = 12000.0
## Desvío lateral leve en el frontal al hacer fuerza.
@export var intensidad_desvio_frontal: float = 3000.0

@export_group("Levantamiento Frontal Carga Pesada (Wheelie)")
## Habilita el levantamiento dinámico de la trompa al arrancar bajo sobrecarga extrema.
@export var habilitar_levantamiento_carga: bool = false
## Masa mínima de remolque/carga en kg para activar el despegue de ruedas delanteras.
## Con 38,000 kg los remolques pesados (40t a 50t) activan el despegue inicial con fuerza moderada.
@export var peso_umbral_levantamiento_kg: float = 38000.0
## Masa de remolque/carga en kg donde el despegue alcanza su plenitud (ej. 48,000 kg).
@export var peso_pleno_levantamiento_kg: float = 48000.0
## Fuerza vertical aplicada en el parachoques delantero (calibrada a 6,000 N para evitar catapultas).
@export var fuerza_elevacion_frontal: float = 6000.0
## Par de cabeceo (Pitch-up calibrado a 8,000 Nm para evitar despegues descontrolados).
@export var torque_levantamiento_frontal: float = 8000.0
## Velocidad máxima en km/h hasta la que se aplica el esfuerzo inicial de arranque antes de asentarse por inercia y gravedad.
@export var velocidad_fin_levantamiento_kmh: float = 3.5
## Ángulo máximo de inclinación hacia arriba (en radianes, ~5 grados) para mantener estabilidad y realismo visual.
@export var max_angulo_levantamiento_rad: float = 0.088

var _torsion_par_suave: float = 0.0
var _levantamiento_trompa_suave: float = 0.0
var _vel_forward_previa: float = 0.0
var _cabeceo_suave: float = 0.0
var _ladeo_suave: float = 0.0

@export_group("Icono Entrada Diegético")
## Offset manual para calibrar la posición 3D del botón de entrada (ej: Vector3(0, 0.2, 0))
@export var offset_icono_entrada: Vector3 = Vector3.ZERO

# --- Referencias a Componentes Internos ---
var motor: Node3D = null
var spring_arm: SpringArm3D = null
var camera_manager: Node3D = null
var ui_vehiculo: CanvasLayer = null
var icono_entrada: Node3D = null
var enganche_nodo: Node3D = null # Para trailer / quinta rueda

# --- Variables de API de Compatibilidad ---
var luces_emergencia: bool = false
var direccional_izquierda: bool = false
var direccional_derecha: bool = false
var angulo_direccion_red: float = 0.0
var bloqueo_diferencial: bool = false
const SonidoChoqueScript = preload("res://codigo/entidades/vehiculo/sonido_choque_vehiculo.gd")

var _iv_cache: Node = null
var _gv_cache: Node = null
var _sonido_choque: Node3D = null
var _tiempo_en_aire: float = 0.0
var _factor_apoyo_suave: float = 1.0

func es_autoridad_local() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return true
	return is_multiplayer_authority()
var luz_stop_node: Node = null
var luz_delantera_node: Node = null
var luz_direccional_node: Node = null

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
var salida_offset_vertical: float = 1.0
var salida_offset_lateral: float = 2.2 # Más ancho debido al cabezote

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
	if luz_stop_node == null:
		luz_stop_node = get_node_or_null("Luces/LuzStop")

	luz_delantera_node = find_child("*delanteras*", true, false)
	if luz_delantera_node == null:
		luz_delantera_node = find_child("*Delanteras*", true, false)
	if luz_delantera_node == null:
		luz_delantera_node = find_child("*Faros*", true, false)
	if luz_delantera_node == null:
		luz_delantera_node = find_child("*faros*", true, false)

	luz_direccional_node = find_child("*direccionales*", true, false)
	if luz_direccional_node == null:
		luz_direccional_node = find_child("*Direccionales*", true, false)

	enganche_nodo = find_child("Enganche", true, false)
	if not enganche_nodo:
		enganche_nodo = find_child("QuintaRueda", true, false)

	# Recolección recursiva de ruedas en el árbol de nodos
	_ruedas_todas.clear()
	_buscar_ruedas_recursivo(self)

	# Configuración de propiedades físicas del RigidBody3D
	mass = masa_pesado_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = centro_de_masa_pesado
	inertia = Vector3(42000.0, 56000.0, 62000.0) # Inercia rotacional equilibrada para tractocamión pesado (kg*m^2)
	linear_damp = 0.04
	angular_damp = 0.35
	
	# Desactivación inicial de procesamiento físico y desactivación de congelamiento de físicas
	if not es_autoridad_local():
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		can_sleep = false
		_alternar_sistemas(false)
		_activar_luces(activo)
		return

	freeze = false
	can_sleep = false
	continuous_cd = true
	add_to_group("vehiculo_jugador")
	var gv_ini = _get_gv()
	if gv_ini and gv_ini.has_method("restaurar_ubicacion_vehiculo"):
		gv_ini.call("restaurar_ubicacion_vehiculo", self)
	_alternar_sistemas(false)
	_activar_luces(activo)
	_conectar_deteccion()
	_sonido_choque = SonidoChoqueScript.new()
	_sonido_choque.name = "SonidoChoqueVehiculo"
	add_child(_sonido_choque)
	_sonido_choque.configurar(self)

func _buscar_ruedas_recursivo(node: Node) -> void:
	for child in node.get_children():
		if child is RayCast3D:
			_ruedas_todas.append(child)
			llantas_todas.append(child)
			if child.get("es_directriz") == true:
				llantas_directrices.append(child)
			else:
				llantas_motrices.append(child)
		_buscar_ruedas_recursivo(child)

func _contar_ruedas_en_suelo() -> int:
	var en_suelo: int = 0
	for rueda in _ruedas_todas:
		if is_instance_valid(rueda) and rueda.is_colliding():
			if "compresion_anterior" in rueda:
				if float(rueda.get("compresion_anterior")) > 0.0:
					en_suelo += 1
			else:
				en_suelo += 1
	return en_suelo

func _aplicar_fisica_aire(delta: float, ruedas_suelo: int) -> void:
	if ruedas_suelo > 0:
		_tiempo_en_aire = 0.0
		return
	_tiempo_en_aire += delta
	# Histéresis de 0.18s para evitar activación intermitente durante micro-rebotes al aterrizar
	if _tiempo_en_aire <= 0.18:
		return
	var factor_aire: float = clampf((_tiempo_en_aire - 0.18) / 0.25, 0.0, 1.0)
	var g_extra: float = gravedad_extra_aire_caida if linear_velocity.y < 0.0 else gravedad_extra_aire_subida
	apply_central_force(Vector3.DOWN * (mass * g_extra * factor_aire))
	var dot_up: float = global_transform.basis.y.dot(Vector3.UP)
	var pitch_frontal: float = (-global_transform.basis.z).dot(Vector3.UP)
	if dot_up > 0.50 and pitch_frontal > -0.12:
		apply_torque(-global_transform.basis.x.normalized() * (torque_cabeceo_aire_pesado * factor_aire))

func _physics_process(delta: float) -> void:
	if not es_autoridad_local():
		_activar_luces(activo)
		return

	# Failsafe anti-abismo / anti-traspaso bajo vías sobre suelo estático real
	var gv_seg = _get_gv()
	if gv_seg and gv_seg.has_method("asegurar_vehiculo_sobre_mapa"):
		_pos_segura_mapa = gv_seg.asegurar_vehiculo_sobre_mapa(self, _pos_segura_mapa)
	elif global_position.y < -12.0:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		global_position.y = 2.0

	var ruedas_suelo: int = _contar_ruedas_en_suelo()
	_aplicar_fisica_aire(delta, ruedas_suelo)
	if _sonido_choque:
		_sonido_choque.actualizar(delta, ruedas_suelo)

	if not activo:
		return
	
	# Estabilización anti-vuelco adaptada a tractocamiones pesados (solo en conducción normal, sin enderezar volcados)
	var factor_apoyo_obj: float = clampf(float(ruedas_suelo - 1) / 2.0, 0.0, 1.0)
	_factor_apoyo_suave = lerpf(_factor_apoyo_suave, factor_apoyo_obj, clampf(delta * 10.0, 0.0, 1.0))
	var factor_apoyo: float = _factor_apoyo_suave
	var local_up = global_transform.basis.y
	var dot_up = local_up.dot(Vector3.UP)
	
	# Dinámica en curva y balanceo visual estético
	var car_basis = global_transform.basis.orthonormalized()
	var vel_local = car_basis.inverse() * linear_velocity
	var vel_forward = -vel_local.z
	var velocidad_angular_y = angular_velocity.y
	
	# Aceleración centrífuga en curva (a_c = v * omega)
	# Si avanza y gira a la izquierda (omega_y > 0), a_c > 0 (ladeo a la derecha / exterior)
	var acel_centrifuga = vel_forward * velocidad_angular_y
	var factor_ladeo_obj = clampf(acel_centrifuga / 3.8, -1.0, 1.0)
	_ladeo_suave = lerpf(_ladeo_suave, factor_ladeo_obj, clampf(delta * 6.0, 0.0, 1.0))
	var max_torque_ladeo = torque_antiroll * deg_to_rad(angulo_max_ladeo_curva) * 2.1
	var torque_ladeo_obj = _ladeo_suave * max_torque_ladeo

	# Barra estabilizadora anti-vuelco firme:
	# Mantiene el camión pegado al suelo en curvas y permite ladeo estético progresivo de hasta ~5.5°.
	# Solo permite vuelco si el ángulo de inclinación supera los 25° (dot_up < 0.90) por causas extremas.
	if factor_apoyo > 0.0 and dot_up > 0.86:
		if dot_up < 0.999:
			var angulo_roll = acos(clamp(dot_up, -1.0, 1.0))
			var eje_roll = Vector3.UP.cross(local_up).normalized()
			if eje_roll.length_squared() > 0.0001:
				var decay = clamp((dot_up - 0.86) / 0.10, 0.0, 1.0) * factor_apoyo
				
				var torque_muelle = -eje_roll * (torque_antiroll * angulo_roll * decay)
				var omega_roll = angular_velocity.dot(eje_roll)
				var torque_amort = -eje_roll * (amort_antiroll * omega_roll * decay)
				
				# Aplicar ladeo suave hacia el exterior de la curva
				var torque_balanceo = -car_basis.z.normalized() * (torque_ladeo_obj * decay)
				
				apply_torque(torque_muelle + torque_amort + torque_balanceo)
		else:
			# En posición casi vertical, aplicar inicio sutil del balanceo centrífugo
			var torque_balanceo = -car_basis.z.normalized() * (torque_ladeo_obj * factor_apoyo)
			apply_torque(torque_balanceo)

	# Estabilización activa de cabeceo (Anti-Pitch):
	# Contrarresta el levantamiento excesivo al acelerar para que las ruedas delanteras nunca se despeguen del suelo
	var inclinacion_frontal_rad: float = -global_transform.basis.z.dot(Vector3.UP)
	if factor_apoyo > 0.0 and inclinacion_frontal_rad > deg_to_rad(2.5):
		var eje_pitch: Vector3 = global_transform.basis.x.normalized()
		var exceso_pitch = inclinacion_frontal_rad - deg_to_rad(2.5)
		var torque_mag = clampf(exceso_pitch * 120000.0, 0.0, 90000.0) * factor_apoyo
		var torque_anti_pitch: Vector3 = -eje_pitch * torque_mag
		var omega_pitch = angular_velocity.dot(eje_pitch)
		var amort_pitch: Vector3 = -eje_pitch * clampf(omega_pitch * 30000.0 * factor_apoyo, -35000.0, 35000.0)
		apply_torque(torque_anti_pitch + amort_pitch)

	# Control dinámico de distancia de cámara basado en la aceleración del chasis pesado
	if spring_arm and activo:
		var accel: float = (linear_velocity - _vel_previa).length() / maxf(delta, 0.001)
		var intensidad: float = clamp(accel * 0.005, -0.4, 0.4)
		spring_arm.position.z = lerp(spring_arm.position.z, intensidad, clamp(delta * 2.5, 0.0, 1.0))

	# Torsión dinámica de par motor y cabeceo realista (solo estable con >= 3 ruedas en suelo)
	var accel_long: float = 0.0
	if ruedas_suelo >= 3:
		accel_long = clampf((vel_forward - _vel_forward_previa) / maxf(delta, 0.001), -8.0, 8.0)
	_vel_forward_previa = vel_forward

	var iv_cab = _get_iv()
	var gas_cab: float = clampf(float(iv_cab.get("gas")), 0.0, 1.0) if (iv_cab and iv_cab.get("gas") != null) else 0.0
	var freno_cab: float = clampf(float(iv_cab.get("freno")), 0.0, 1.0) if (iv_cab and iv_cab.get("freno") != null) else 0.0
	var marcha_cab: int = int(iv_cab.get("marcha_actual")) if (iv_cab and iv_cab.get("marcha_actual") != null) else 2

	var impulso_input: float = 0.0
	var factor_arranque := clampf(1.0 - (absf(vel_forward) / 14.0), 0.25, 1.0)
	if marcha_cab >= 3 and gas_cab > 0.05: # Drive / marchas adelante (asentamiento firme al acelerar)
		impulso_input += gas_cab * 0.72 * factor_arranque
	elif marcha_cab == 1 and gas_cab > 0.05: # Reversa
		impulso_input -= gas_cab * 0.50 * factor_arranque
	if freno_cab > 0.05 and absf(vel_forward) > 0.4:
		impulso_input -= signf(vel_forward) * freno_cab * 0.90

	var target_cabeceo: float = clampf((accel_long / 4.5) + impulso_input, -1.0, 1.0) * factor_apoyo
	_cabeceo_suave = lerpf(_cabeceo_suave, target_cabeceo, clampf(delta * 8.5, 0.0, 1.0))
	if factor_apoyo > 0.0 and absf(_cabeceo_suave) > 0.01:
		var fuerza_pitch: float = 165000.0 if _cabeceo_suave > 0.0 else 230000.0
		apply_torque(global_transform.basis.x.normalized() * (_cabeceo_suave * fuerza_pitch))

	_aplicar_torsion_chasis_carga(delta)

	# Arrastre aerodinámico cuadrático analítico (Rigs of Rods Aerodynamic Drag)
	var v_len = linear_velocity.length()
	if v_len > 0.5:
		var area_frontal: float = 9.2 if obtener_peso_remolque() > 1000.0 else 6.8
		var coef_arrastre: float = 0.68
		var f_aero_mag: float = 0.5 * 1.225 * coef_arrastre * area_frontal * (v_len * v_len)
		apply_central_force(-linear_velocity.normalized() * minf(f_aero_mag, 25000.0))

	_vel_previa = linear_velocity

## Retorna la masa del remolque acoplado al camión
func obtener_peso_remolque() -> float:
	if not enganche_nodo:
		enganche_nodo = find_child("Enganche", true, false)
		if not enganche_nodo:
			enganche_nodo = find_child("QuintaRueda", true, false)
	if enganche_nodo and "conectado" in enganche_nodo and enganche_nodo.conectado:
		var remolque = enganche_nodo.get("enganche_remoto")
		if remolque and enganche_nodo.has_method("_buscar_cuerpo"):
			var cuerpo = enganche_nodo._buscar_cuerpo(remolque)
			if cuerpo and "mass" in cuerpo:
				return cuerpo.mass
	return 0.0

## Aplica la torsión de par motor (Torque Twist) y levantamiento de trompa cuando el camión arranca o hace fuerza con carga pesada
func _aplicar_torsion_chasis_carga(delta: float) -> void:
	if not activo:
		_torsion_par_suave = move_toward(_torsion_par_suave, 0.0, delta * 3.0)
		_levantamiento_trompa_suave = move_toward(_levantamiento_trompa_suave, 0.0, delta * 3.0)
		return

	var peso_remolque: float = obtener_peso_remolque()
	var masa_arrastrada: float = peso_remolque

	var iv = _get_iv()
	var gas: float = 0.0
	if iv:
		gas = clampf(iv.get("gas") if iv.get("gas") != null else 0.0, 0.0, 1.0)
	elif motor and "gas_suavizado" in motor:
		gas = motor.gas_suavizado

	if gas < 0.05:
		_torsion_par_suave = move_toward(_torsion_par_suave, 0.0, delta * 5.0)
		_levantamiento_trompa_suave = move_toward(_levantamiento_trompa_suave, 0.0, delta * 5.0)
		return

	var vel_kmh: float = linear_velocity.length() * 3.6

	# 1. Torsión lateral (Roll del chasis y desvío sutil al arrancar con carga)
	if habilitar_torque_twist and masa_arrastrada >= 12000.0:
		var factor_baja_vel: float = clampf((24.0 - vel_kmh) / 24.0, 0.0, 1.0)
		var factor_peso_twist: float = clampf((masa_arrastrada - 12000.0) / 38000.0, 0.0, 1.0)
		var target_twist: float = gas * factor_baja_vel * factor_peso_twist
		var vel_lerp: float = 5.0 if target_twist > _torsion_par_suave else 3.0
		_torsion_par_suave = lerpf(_torsion_par_suave, target_twist, clampf(delta * vel_lerp, 0.0, 1.0))

		if _torsion_par_suave > 0.005:
			var eje_roll: Vector3 = global_transform.basis.z.normalized()
			var torque_roll: Vector3 = eje_roll * (intensidad_torsion_roll * _torsion_par_suave)
			apply_torque(torque_roll)

			var pos_frontal_local: Vector3 = Vector3(0.0, 0.1, -2.4)
			var pos_frontal_global: Vector3 = global_transform.basis * pos_frontal_local
			var dir_lateral: Vector3 = global_transform.basis.x.normalized()
			var fuerza_lateral: Vector3 = dir_lateral * (intensidad_desvio_frontal * _torsion_par_suave)
			apply_force(fuerza_lateral, pos_frontal_global)
	else:
		_torsion_par_suave = move_toward(_torsion_par_suave, 0.0, delta * 3.0)

	# 2. Levantamiento de Trompa (Wheelie) - DESACTIVADO MOMENTÁNEAMENTE A PETICIÓN
	_levantamiento_trompa_suave = 0.0

func subir_jugador(p_jugador: Node3D) -> void:
	if activo:
		return
	activo = true
	jugador_ref = p_jugador
	if is_instance_valid(icono_entrada) and icono_entrada.has_method("ocultar"):
		icono_entrada.ocultar()
	var gv = _get_gv()
	if gv and gv.has_method("subir_jugador_a_vehiculo"):
		gv.subir_jugador_a_vehiculo(p_jugador, self)
	if gv and gv.has_method("guardar_ubicacion_vehiculo"):
		gv.guardar_ubicacion_vehiculo(self)
	
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
		var speed_max_kmh = 120.0 # Límite menor para tractocamión
		var rpm_max_val = 2500.0 # Límite menor típico de motor diésel pesado
		ui_vehiculo.set("velocidad_maxima", speed_max_kmh)
		ui_vehiculo.set("rpm_maxima", rpm_max_val)
		
		var dash = ui_vehiculo.find_child("Dashboard", true, false)
		if dash:
			dash.set("vehicle", self)
			dash.set("speedometer_max", speed_max_kmh)
			if dash.has_method("_ensure_rpm_source"):
				dash.call("_ensure_rpm_source")

	# Activación de banderas de entrada del conductor en el singleton (BUG-011 corregido: inicia apagado y con freno de mano)
	var iv = _get_iv()
	if iv:
		iv.set("conduciendo", true)
		if iv.has_method("set_marcha_enum"):
			iv.call("set_marcha_enum", 2) # NEUTRO
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

		var gv = _get_gv()
		if gv and gv.has_method("bajar_jugador_de_vehiculo"):
			gv.bajar_jugador_de_vehiculo(jugador_ref, self, posicion_salida)
		if gv and gv.has_method("guardar_ubicacion_vehiculo"):
			gv.guardar_ubicacion_vehiculo(self)
		jugador_ref = null

	if ui_vehiculo:
		ui_vehiculo.visible = false
		var dash_clear = ui_vehiculo.find_child("Dashboard", true, false)
		if dash_clear:
			dash_clear.set("vehicle", null)

	if motor and "sonidos_nodo" in motor and is_instance_valid(motor.sonidos_nodo):
		if motor.sonidos_nodo.has_method("detener_todos_los_sonidos"):
			motor.sonidos_nodo.call("detener_todos_los_sonidos")
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
	if is_instance_valid(motor):
		motor.set_physics_process(estado)
	for rueda in _ruedas_todas:
		if is_instance_valid(rueda):
			rueda.set_physics_process(true) # Suspensión activa para colisiones y caídas de camión desocupado

func _activar_luces(presente: bool) -> void:
	if is_instance_valid(luz_stop_node) and luz_stop_node.has_method("set_conductor_presente"):
		luz_stop_node.set_conductor_presente(presente)
	if is_instance_valid(luz_delantera_node) and luz_delantera_node.has_method("set_conductor_presente"):
		luz_delantera_node.set_conductor_presente(presente)
	if is_instance_valid(luz_direccional_node) and luz_direccional_node.has_method("set_conductor_presente"):
		luz_direccional_node.set_conductor_presente(presente)

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
	if not es_autoridad_local():
		return
	if body and body.is_in_group("jugador") and (not body.has_method("es_autoridad_local") or body.es_autoridad_local()) and not activo:
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
	if camera_manager:
		if camera_manager.has_method("mover_camara"):
			var idx = camera_manager.get("indice_actual")
			camera_manager.call("mover_camara", idx if idx != null else 0, vector)
		elif camera_manager.has_method("_distribuir_entrada_camara"):
			camera_manager.call("_distribuir_entrada_camara", vector)
	elif spring_arm and spring_arm.has_method("rotar_camara"):
		spring_arm.call("rotar_camara", vector)

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
