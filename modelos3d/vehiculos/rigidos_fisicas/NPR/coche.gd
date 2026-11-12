@tool
extends RigidBody3D

static var _stream_choque_leve: AudioStream = null

# ═══════════════════════════════════════════════════════════════════════
# coche.gd — Sistema de física vehicular
# Toda la configuración viene de VehiculoConfig (un recurso .tres por vehículo).
# ═══════════════════════════════════════════════════════════════════════

@export_group("Configuración")
@export var config: Resource = null # Se deja genérico por si VehiculoConfig no se carga a tiempo en el editor

@export_group("Componentes")
@onready var motor: Node               = get_node_or_null("Motor")
@onready var llantas_controlador: Node = null
@onready var ui_vehiculo: CanvasLayer  = get_node_or_null("UIVehiculo")
var icono_entrada: Node3D = null
@onready var spring_arm: SpringArm3D   = get_node_or_null("BrazoCamara/SpringArm3D")
@onready var luz_stop_node: Node3D     = get_node_or_null("Luces/LuzStop")

@export_group("Debug")
@export var debug_vehiculo: bool = false

@export_group("Salida del Vehículo")
@export var salida_offset_lateral: float  = 1.30
@export var salida_offset_vertical: float = 0.12

@export_group("Chasis", "chasis_")
@export var masa_kg: float = 1400.0
@export var centro_de_masa: Vector3 = Vector3(0.0, -0.10, 0.0) # Subido el centro de masa para permitir transferencia de peso realista
@export var coef_arrastre: float = 0.40
@export var area_frontal_m2: float = 2.6
@export var resistencia_rodadura: float = 0.015

@export_group("Estabilidad", "estabilidad_")
@export var torque_antiroll: float = 15000.0 # Reducida de 25000 para que la suspensión actúe de forma más blanda y natural
@export var amort_antiroll: float = 4000.0
@export var fuerza_enderezado: float = 12000.0 # Más baja para que no regrese mágicamente a estar plano
@export var amort_enderezado: float = 2000.0
@export var umbral_enderezado: float = 0.25 # Solo asiste cuando el coche ya está casi totalmente sobre su techo (<15 grados de volteado completo)

@export_group("Cabeceo", "pitch_")
@export var pitch_intensidad: float = 18.0 # Ligeramente subido para acentuar el frenado y aceleración
@export var pitch_amort: float = 10000.0
@export var pitch_suavizado: float = 5.0
@export var pitch_acel_max: float = 8.0

@export_group("Sacudida Cambio", "cambio_")
@export var cambio_impulso: float = 12.0
@export var cambio_decaimiento: float = 4.0

@export_group("Freno de Mano", "freno_")
@export var fuerza_freno_mano: float = 12000.0
@export var vel_umbral_parado: float = 0.15
@export var omega_umbral_parado: float = 0.05

@export_group("Torsión de Chasis Lateral (Torque Twist)")
## Habilita la inclinación lateral del chasis al acelerar con carga pesada.
@export var habilitar_torque_twist: bool = true
## Intensidad de la inclinación lateral (roll) del chasis.
@export var intensidad_torsion_roll: float = 10000.0
## Desvío lateral leve en el frontal al hacer fuerza.
@export var intensidad_desvio_frontal: float = 2500.0

@export_group("Levantamiento Frontal Carga Pesada (Wheelie)")
## Habilita el levantamiento dinámico de la trompa al arrancar bajo sobrecarga extrema.
@export var habilitar_levantamiento_carga: bool = true
## Masa mínima de remolque/carga en kg para activar el despegue de ruedas delanteras.
## Por defecto 42,000 kg: el camión soporta fácilmente hasta 40 toneladas sin despegar las ruedas.
@export var peso_umbral_levantamiento_kg: float = 42000.0
## Masa de remolque/carga en kg donde el despegue alcanza su plenitud (ej. 50,000 kg).
@export var peso_pleno_levantamiento_kg: float = 50000.0
## Fuerza vertical aplicada en el parachoques delantero (Newtons) para elevar suavemente el eje directriz.
@export var fuerza_elevacion_frontal: float = 22000.0
## Par de cabeceo (Pitch-up en Nm) para inclinar el chasis sobre el eje trasero.
@export var torque_levantamiento_frontal: float = 38000.0
## Velocidad máxima en km/h hasta la que se mantiene levantado el morro antes de asentarse al ganar fuerza.
@export var velocidad_fin_levantamiento_kmh: float = 18.0
## Ángulo máximo de inclinación hacia arriba (en radianes, ~9.5 grados) para mantener estabilidad y seguridad.
@export var max_angulo_levantamiento_rad: float = 0.165

var _torsion_par_suave: float = 0.0
var _levantamiento_trompa_suave: float = 0.0

# ─── Estado interno ───────────────────────────────────────────────────
var activo: bool             = false
var jugador_ref: Node3D      = null
var jugador_cerca: bool      = false
var indice_camara: int       = 0
var _jugador_cam_node: Node  = null

# Variables para la tableta en el vehículo
var tableta_en_vehiculo: Node3D = null
var ajustando_tableta: bool = false
var tableta_offset_pos: Vector3 = Vector3.ZERO
var tableta_offset_rot: Vector3 = Vector3.ZERO
var _tablet_ui_label: Label = null
var _jugador_cam_original_parent: Node = null
var _jugador_cam_original_global_transform: Transform3D = Transform3D()

var nivel_suciedad: float = 0.0:
	set(val):
		nivel_suciedad = clamp(val, 0.0, 1.0)
		_actualizar_suciedad_materiales(nivel_suciedad)

var _materiales_sucios_cache: Array[Material] = []
var nivel_barro: float    = 0.0
var nivel_mojado: float   = 0.0
var _factor_grip: float   = 1.0

var _freno_mano_activo: bool = false
var camera_manager: Node = null
var _local_cameras: Array[Camera3D] = []
var _active_camera_idx: int = 0
var peso_carga_actual: float = 0.0
var _pitch_acel_suave: float = 0.0
var _forward_dir: Vector3 = Vector3.FORWARD
var _vel_previa: Vector3 = Vector3.ZERO
var _impulso_cambio: float = 0.0

# ─── Luces de señalización (leídas por IA de tráfico) ────────────────
var luces_emergencia: bool     = false
var direccional_izquierda: bool = false
var direccional_derecha: bool   = false

@export_group("Icono Entrada Diegético")
## Offset manual para calibrar la posición 3D del botón de entrada (ej: Vector3(0, 0.2, 0))
@export var offset_icono_entrada: Vector3 = Vector3.ZERO

var _pos_objetivo: Vector3 = Vector3.ZERO
var _rot_objetivo: Vector3 = Vector3.ZERO


# ═══════════════════════════════════════════════════════════════════════
# APLICAR CONFIG
# ═══════════════════════════════════════════════════════════════════════

func _aplicar_config() -> void:
	if config == null:
		return
	masa_kg                = config.get("masa_kg") if config.get("masa_kg") != null else masa_kg
	centro_de_masa         = config.get("centro_de_masa") if config.get("centro_de_masa") != null else centro_de_masa
	coef_arrastre          = config.get("coef_arrastre") if config.get("coef_arrastre") != null else coef_arrastre
	area_frontal_m2        = config.get("area_frontal_m2") if config.get("area_frontal_m2") != null else area_frontal_m2
	torque_antiroll        = config.get("torque_antiroll") if config.get("torque_antiroll") != null else torque_antiroll
	amort_antiroll         = config.get("amort_antiroll") if config.get("amort_antiroll") != null else amort_antiroll
	fuerza_enderezado      = config.get("fuerza_enderezado") if config.get("fuerza_enderezado") != null else fuerza_enderezado
	amort_enderezado       = config.get("amort_enderezado") if config.get("amort_enderezado") != null else amort_enderezado
	umbral_enderezado      = config.get("umbral_enderezado") if config.get("umbral_enderezado") != null else umbral_enderezado
	pitch_intensidad       = config.get("pitch_intensidad") if config.get("pitch_intensidad") != null else pitch_intensidad
	pitch_amort            = config.get("pitch_amort") if config.get("pitch_amort") != null else pitch_amort
	pitch_suavizado        = config.get("pitch_suavizado") if config.get("pitch_suavizado") != null else pitch_suavizado
	pitch_acel_max         = config.get("pitch_acel_max") if config.get("pitch_acel_max") != null else pitch_acel_max
	cambio_impulso         = config.get("cambio_impulso") if config.get("cambio_impulso") != null else cambio_impulso
	cambio_decaimiento     = config.get("cambio_decaimiento") if config.get("cambio_decaimiento") != null else cambio_decaimiento
	fuerza_freno_mano      = config.get("fuerza_freno_mano") if config.get("fuerza_freno_mano") != null else fuerza_freno_mano
	vel_umbral_parado      = config.get("vel_umbral_parado") if config.get("vel_umbral_parado") != null else vel_umbral_parado
	omega_umbral_parado    = config.get("omega_umbral_parado") if config.get("omega_umbral_parado") != null else omega_umbral_parado

	mass = masa_kg + peso_carga_actual
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	
	# LÍMITE FÍSICO DURO: Asegurar que el centro de masas en el eje Y no sea inferior a -0.10.
	# Si el recurso .tres tiene un valor muy bajo como -0.35 o -0.50, esto actuaba como un giroscopio
	# mágico de tentetieso impidiendo físicamente cualquier volcado.
	var centro_real: Vector3 = centro_de_masa
	if centro_real.y < -0.10:
		centro_real.y = -0.10
	center_of_mass = centro_real

func _propagar_config_async() -> void:
	_aplicar_config()
	_propagar_config_direccion()
	_propagar_config_motor()

func _propagar_config_direccion() -> void:
	if config == null or not is_instance_valid(llantas_controlador):
		return
	if llantas_controlador.has_method("configurar_desde_vehiculo"):
		llantas_controlador.configurar_desde_vehiculo(config)

func _propagar_config_motor() -> void:
	if config == null or not is_instance_valid(motor):
		return
	var mcfg = config.get("motor_config")
	if mcfg != null and motor.has_method("set_config"):
		motor.set_config(mcfg)
	# Propagar información de combustible desde VehiculoConfig al motor
	if config and motor.has_method("set_info_combustible"):
		var ft = config.get("tipo_combustible")
		var cap = config.get("capacidad_combustible_l")
		var lvl = config.get("nivel_combustible_l")
		if ft != null and cap != null and lvl != null:
			motor.set_info_combustible(ft, cap, lvl)

# ═══════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")

func _find_seat_node() -> Node3D:
	var cand = get_node_or_null("AsientoConductor")
	if cand and cand is Node3D:
		return cand
	cand = get_node_or_null("Asiento Conductor")
	if cand and cand is Node3D:
		return cand
	var stack: Array = [self]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n and typeof(n.name) == TYPE_STRING:
			if n.name.to_lower().find("asiento") != -1 and n is Node3D:
				return n
		for c in n.get_children():
			stack.append(c)
	return null

func _conectar_gamemanger() -> void:
	var gm: Node = _gm()
	if gm == null:
		return
	if gm.has_signal("CamaraCambiada") and not gm.CamaraCambiada.is_connected(_al_cambiar_camara):
		gm.CamaraCambiada.connect(_al_cambiar_camara)


# ═══════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ═══════════════════════════════════════════════════════════════════════

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("vehiculo")

	_pos_objetivo = global_position
	_rot_objetivo = global_rotation

	# Optimizar mallas internas, sombras e iluminación del vehículo
	_optimizar_mallas_e_iluminacion(self)

	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		# Desactivar cámaras y UI para vehículos remotos
		if ui_vehiculo:
			ui_vehiculo.queue_free()
		if spring_arm:
			spring_arm.queue_free()
		freeze = true
		freeze_mode = FREEZE_MODE_KINEMATIC
		set_process(false)
		return

func _optimizar_mallas_e_iluminacion(raiz: Node) -> void:
	if not is_instance_valid(raiz):
		return
	var stack: Array[Node] = [raiz]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if not is_instance_valid(n):
			continue
		
		if n is MeshInstance3D:
			var mesh_node := n as MeshInstance3D
			var nombre_l := mesh_node.name.to_lower()
			var padre_name := mesh_node.get_parent().name.to_lower() if mesh_node.get_parent() else ""
			
			if nombre_l.contains("asiento") or nombre_l.contains("interior") or nombre_l.contains("motor") \
				or nombre_l.contains("tablero") or nombre_l.contains("palanca") or nombre_l.contains("volante") \
				or nombre_l.contains("pedal") or nombre_l.contains("accesorio") or nombre_l.contains("detalles") \
				or padre_name.contains("interior") or padre_name.contains("cabina"):
				
				mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mesh_node.visibility_range_end = 45.0
				mesh_node.visibility_range_end_margin = 5.0
				mesh_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			else:
				mesh_node.visibility_range_end = 350.0
				mesh_node.visibility_range_end_margin = 25.0
				mesh_node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

		elif n is Light3D:
			var luz := n as Light3D
			var luz_nombre := luz.name.to_lower()
			if luz_nombre.contains("interior") or luz_nombre.contains("cabina") or luz_nombre.contains("tablero") or luz_nombre.contains("stop") or luz_nombre.contains("direccional"):
				luz.shadow_enabled = false
			if luz is SpotLight3D:
				var spot := luz as SpotLight3D
				if spot.spot_range > 45.0:
					spot.spot_range = 45.0

		for c in n.get_children():
			stack.append(c)

	camera_manager = _detect_camera_manager()
	_collect_local_cameras()

	# Compatibilidad: algunas escenas usan el nombre "ControladosRuedas"
	if llantas_controlador == null:
		llantas_controlador = get_node_or_null("ControladorLlantas")
		if llantas_controlador == null:
			llantas_controlador = get_node_or_null("ControladosRuedas")

	add_to_group("vehiculo")

	mass = masa_kg + peso_carga_actual
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = centro_de_masa

	freeze = true

	if ui_vehiculo:
		ui_vehiculo.visible = false

	_alternar_sistemas(false)
	_conectar_deteccion()
	_conectar_gamemanger()

	# Cachear materiales sucios (optimización móvil)
	_cachear_materiales_sucios.call_deferred()

	# Configurar monitor de contactos para detección de choques
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_coche_body_entered)

	# Propagar config después de que los hijos estén listos
	_propagar_config_async.call_deferred()

func _exit_tree() -> void:
	# RESCATE CRÍTICO: Si el vehículo se destruye mientras el jugador está adentro (Ej: Cancelar trabajo de mensajería)
	if activo and is_instance_valid(jugador_ref):
		bajar_jugador()


# ═══════════════════════════════════════════════════════════════════════
# FÍSICA PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		global_position = global_position.lerp(_pos_objetivo, delta * 20.0)
		global_rotation.x = lerp_angle(global_rotation.x, _rot_objetivo.x, delta * 20.0)
		global_rotation.y = lerp_angle(global_rotation.y, _rot_objetivo.y, delta * 20.0)
		global_rotation.z = lerp_angle(global_rotation.z, _rot_objetivo.z, delta * 20.0)
		return

	if not activo:
		return

	var vel_vec: Vector3 = linear_velocity
	var vel_escalar: float = vel_vec.length()

	_procesar_freno_mano(vel_escalar, delta)
	_aplicar_aerodinamica(vel_vec, vel_escalar)
	_aplicar_resistencia_rodamiento(vel_vec, vel_escalar)
	_aplicar_antiroll(delta)
	_aplicar_correccion_volcado(delta)
	_aplicar_cabeceo(delta)
	_aplicar_torsion_chasis_carga(delta)
	_limpiar_microvelocidades(vel_escalar)

	if spring_arm and activo:
		var accel: float = (vel_vec - _vel_previa).length() / maxf(delta, 0.001)
		var intensidad: float = clamp(accel * 0.01, -0.3, 0.3)
		spring_arm.position.z = lerp(spring_arm.position.z, intensidad, clamp(delta * 4.0, 0.0, 1.0))

	_vel_previa = vel_vec
	
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		actualizar_transform_vehiculo.rpc(global_position, global_rotation, linear_velocity, angular_velocity)


# ─── Input para luces de señalización (solo cuando el jugador conduce) ───
func _process(delta: float) -> void:
	if not activo:
		return
	# Luces de emergencia / parqueo (ambas direccionales a la vez) — tecla H por defecto
	if Input.is_action_just_pressed("luces_emergencia"):
		luces_emergencia = not luces_emergencia
		direccional_izquierda = luces_emergencia
		direccional_derecha   = luces_emergencia
	# Direccional izquierda — tecla Z por defecto
	if Input.is_action_just_pressed("direccional_izquierda"):
		direccional_izquierda = not direccional_izquierda
		if direccional_izquierda:
			direccional_derecha = false
			luces_emergencia    = false
	# Direccional derecha — tecla X por defecto
	if Input.is_action_just_pressed("direccional_derecha"):
		direccional_derecha = not direccional_derecha
		if direccional_derecha:
			direccional_izquierda = false
			luces_emergencia      = false


func _procesar_freno_mano(vel: float, delta: float) -> void:
	var freno_pedido: bool = false
	# Validar existencia de InputVehiculo Global
	if is_instance_valid(get_node_or_null("/root/InputVehiculo")):
		var InputVehiculo = get_node("/root/InputVehiculo")
		freno_pedido = InputVehiculo.get("freno_mano") or \
			(InputVehiculo.get("marcha_actual") == InputVehiculo.get("Marcha").PARQUEO if InputVehiculo.get("Marcha") else false)

	_freno_mano_activo = freno_pedido

	if not _freno_mano_activo:
		return

	if vel < vel_umbral_parado:
		# Solo congelar si NO estamos acelerando fuerte
		if is_instance_valid(get_node_or_null("/root/InputVehiculo")) and get_node("/root/InputVehiculo").get("gas") < 0.05:
			linear_velocity  = Vector3.ZERO
			angular_velocity = Vector3.ZERO
		return

	var dir_mov: Vector3 = vel_vec_plano(linear_velocity)
	if dir_mov.length_squared() > 0.001:
		var fuerza_fm: Vector3 = -dir_mov.normalized() * fuerza_freno_mano
		apply_central_force(fuerza_fm)

	angular_velocity *= (1.0 - delta * 4.0)


func _aplicar_aerodinamica(vel_vec: Vector3, vel: float) -> void:
	if vel < 0.5:
		return
	var magnitud: float = 0.5 * 1.225 * vel * vel * coef_arrastre * area_frontal_m2
	var fuerza: Vector3 = -vel_vec.normalized() * magnitud
	apply_central_force(fuerza)


func _aplicar_resistencia_rodamiento(vel_vec: Vector3, vel: float) -> void:
	if vel < 0.05:
		return
	var crr: float = resistencia_rodadura + nivel_barro * 0.05 + nivel_mojado * 0.008
	var masa_total: float = masa_kg + peso_carga_actual
	var fuerza: Vector3 = -vel_vec.normalized() * crr * masa_total * 9.81
	apply_central_force(fuerza)


func _aplicar_antiroll(_delta: float) -> void:
	var local_up: Vector3 = global_transform.basis.y
	var dot_up: float     = local_up.dot(Vector3.UP)

	# Si está casi plano, se estabiliza normalmente.
	# Pero si pasa de un ángulo medio, el antiroll decae para permitir el volcado real.
	if dot_up > 0.998:
		return

	var angulo_roll: float = acos(clamp(dot_up, -1.0, 1.0))
	var eje_roll: Vector3 = Vector3.UP.cross(local_up).normalized()
	if eje_roll.length_squared() < 0.001:
		return

	# Atenuador de antiroll: decae progresivamente a partir de inclinación moderada (dot_up <= 0.94 / ~20 grados)
	# y llega a cero total cuando se acerca al umbral de volcado (0.25).
	# Forzamos los límites en código para saltarnos los valores sobreescritos por el recurso .tres
	var umbral_real: float = 0.25
	var factor_atenuacion: float = clamp((dot_up - umbral_real) / (0.94 - umbral_real), 0.0, 1.0)

	var torque_antiroll_real: float = minf(torque_antiroll, 15000.0)
	var amort_antiroll_real: float = minf(amort_antiroll, 4000.0)

	var torque_muelle: Vector3 = -eje_roll * (torque_antiroll_real * angulo_roll * factor_atenuacion)
	var omega_roll: float      = angular_velocity.dot(eje_roll)
	var torque_amort: Vector3  = -eje_roll * (amort_antiroll_real * omega_roll * factor_atenuacion)

	apply_torque(torque_muelle + torque_amort)


func _aplicar_correccion_volcado(_delta: float) -> void:
	var local_up: Vector3 = global_transform.basis.y
	var dot_up: float     = local_up.dot(Vector3.UP)

	# LÍMITE FÍSICO DURO: Forzar que el umbral de asistencia sea de 0.25 (15 grados sobre su techo)
	# para ignorar configs viejos o exagerados del archivo .tres que mantendrían el vehículo plano.
	var umbral_real: float = 0.25
	if dot_up >= umbral_real:
		return

	var eje_corr: Vector3 = local_up.cross(Vector3.UP).normalized()
	if eje_corr.length_squared() < 0.001:
		return

	var intensidad: float = clamp((1.0 - dot_up) / (1.0 - umbral_real), 0.0, 1.0)

	# Capar fuerza máxima de auto-enderezado a 12000.0 para que sea una asistencia sutil en lugar de un giro mágico
	var fuerza_real: float = minf(fuerza_enderezado, 12000.0)
	var amort_real: float = minf(amort_enderezado, 2000.0)

	var torque_corr: Vector3 = eje_corr * fuerza_real * intensidad
	var omega_corr: float    = angular_velocity.dot(eje_corr)
	var torque_am: Vector3   = -eje_corr * amort_real * omega_corr

	apply_torque(torque_corr + torque_am)


func aplicar_impulso_cambio(intensidad: float) -> void:
	# Permitir impulsos mayores para vehículos pesados (p.ej. T800)
	_impulso_cambio = clampf(intensidad, 0.0, 5.0)

func _aplicar_cabeceo(delta: float) -> void:
	if pitch_intensidad < 0.01:
		return
	var vel_plana: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if vel_plana.length_squared() > 0.25:
		var fwd_candidate: Vector3 = -global_transform.basis.z
		if fwd_candidate.dot(vel_plana.normalized()) < 0.0:
			fwd_candidate = global_transform.basis.z
		_forward_dir = fwd_candidate.normalized()
	var forward: Vector3 = _forward_dir
	var acel_raw: float = (linear_velocity - _vel_previa).dot(forward) / maxf(delta, 0.001)
	var acel_long: float = clamp(acel_raw, -pitch_acel_max, pitch_acel_max)
	if acel_long < 0.0:
		acel_long *= 0.20 # Reducir cabeceo al frenar para evitar que se levante la cola
	_pitch_acel_suave = lerpf(_pitch_acel_suave, acel_long, minf(delta * pitch_suavizado, 1.0))
	var eje_pitch: Vector3 = global_transform.basis.x.normalized()
	# Escalar el cabeceo artificial de manera que disminuya proporcionalmente cuando el camión lleva carga pesada
	var factor_masa: float = masa_kg / maxf(mass, 1.0)
	var torque_cabeceo: Vector3 = eje_pitch * _pitch_acel_suave * pitch_intensidad * factor_masa
	var pitch_actual: float = angular_velocity.dot(eje_pitch)
	var torque_amort: Vector3 = -eje_pitch * pitch_amort * pitch_actual
	apply_torque(torque_cabeceo + torque_amort)

	if _impulso_cambio > 0.01:
		apply_torque(-eje_pitch * (cambio_impulso * factor_masa) * _impulso_cambio)
		_impulso_cambio = lerpf(_impulso_cambio, 0.0, delta * cambio_decaimiento)
		if _impulso_cambio < 0.01:
			_impulso_cambio = 0.0


func _limpiar_microvelocidades(vel: float) -> void:
	if vel > vel_umbral_parado:
		return
	if angular_velocity.length() > omega_umbral_parado:
		return

	var hay_aceleracion: bool = false
	if is_instance_valid(get_node_or_null("/root/InputVehiculo")):
		var iv = get_node("/root/InputVehiculo")
		hay_aceleracion = absf(iv.get("gas")) > 0.05 or absf(iv.get("freno")) > 0.05

	if not hay_aceleracion:
		linear_velocity  = linear_velocity.lerp(Vector3.ZERO, 0.3)
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, 0.3)


# ═══════════════════════════════════════════════════════════════════════
# CARGA DINÁMICA
# ═══════════════════════════════════════════════════════════════════════

func actualizar_carga(peso_carga: float) -> void:
	peso_carga_actual = maxf(peso_carga, 0.0)
	mass              = masa_kg + peso_carga_actual
	center_of_mass.y   = centro_de_masa.y + (peso_carga_actual * 0.0001)


## Obtiene la referencia física al remolque actualmente conectado a la quinta rueda
func obtener_remolque() -> RigidBody3D:
	var enganche = find_child("Enganche", true, false)
	if enganche and enganche.get("conectado") == true:
		var remoto = enganche.get("enganche_remoto")
		if remoto and enganche.has_method("_buscar_cuerpo"):
			return enganche._buscar_cuerpo(remoto) as RigidBody3D
	return null


## Devuelve la masa física total en kg del remolque conectado (tara + peso de carga)
func obtener_peso_remolque() -> float:
	var remolque = obtener_remolque()
	if is_instance_valid(remolque):
		return remolque.mass
	return 0.0


## Aplica la torsión de par motor (Torque Twist) y levantamiento de trompa cuando el camión arranca o hace fuerza con carga pesada
func _aplicar_torsion_chasis_carga(delta: float) -> void:
	if not activo:
		_torsion_par_suave = move_toward(_torsion_par_suave, 0.0, delta * 3.0)
		_levantamiento_trompa_suave = move_toward(_levantamiento_trompa_suave, 0.0, delta * 3.0)
		return

	var peso_remolque: float = obtener_peso_remolque()
	var masa_arrastrada: float = peso_remolque + peso_carga_actual

	var iv = is_instance_valid(get_node_or_null("/root/InputVehiculo"))
	var gas: float = 0.0
	if iv:
		gas = clampf(get_node("/root/InputVehiculo").get("gas"), 0.0, 1.0)
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

	# 2. Levantamiento de Trompa (Wheelie):
	# El camión soporta fácilmente hasta 40 toneladas sin despegar las ruedas directrices.
	# A partir de peso_umbral_levantamiento_kg (por defecto 42,000 kg, pleno hacia 50,000 kg),
	# el camión hace su esfuerzo de tracción y las ruedas delanteras se levantan sutilmente,
	# manteniéndose en el aire hasta que el camión coge impulso y velocidad (> velocidad_fin_levantamiento_kmh).
	if habilitar_levantamiento_carga and masa_arrastrada >= peso_umbral_levantamiento_kg:
		var factor_gas_full: float = pow(gas, 1.2)
		var factor_vel_trompa: float = clampf((velocidad_fin_levantamiento_kmh - vel_kmh) / velocidad_fin_levantamiento_kmh, 0.0, 1.0)
		var rango_peso: float = maxf(peso_pleno_levantamiento_kg - peso_umbral_levantamiento_kg, 1000.0)
		var factor_sobrecarga: float = clampf((masa_arrastrada - peso_umbral_levantamiento_kg) / rango_peso, 0.0, 1.3)

		# Límite de seguridad de pitch para que el morro no sobrepase un ángulo seguro
		var inclinacion_frontal_rad: float = -global_transform.basis.z.dot(Vector3.UP)
		var factor_seguridad_pitch: float = clampf((max_angulo_levantamiento_rad - inclinacion_frontal_rad) / max_angulo_levantamiento_rad, 0.0, 1.0)

		var target_lift: float = factor_gas_full * factor_vel_trompa * factor_sobrecarga * factor_seguridad_pitch
		var vel_lift_lerp: float = 5.0 if target_lift > _levantamiento_trompa_suave else 3.0
		_levantamiento_trompa_suave = lerpf(_levantamiento_trompa_suave, target_lift, clampf(delta * vel_lift_lerp, 0.0, 1.0))

		if _levantamiento_trompa_suave > 0.005:
			# Torque de cabeceo hacia arriba (pitch-up)
			var eje_pitch: Vector3 = global_transform.basis.x.normalized()
			var torque_lift: Vector3 = -eje_pitch * (torque_levantamiento_frontal * _levantamiento_trompa_suave * factor_seguridad_pitch)
			apply_torque(torque_lift)

			# Asistencia vertical en el frontal: eleva suavemente el eje delantero separando las ruedas del suelo
			# sin restar peso ni adherencia al eje motriz trasero
			var fuerza_arriba: Vector3 = global_transform.basis.y * (fuerza_elevacion_frontal * _levantamiento_trompa_suave * factor_seguridad_pitch)
			var pos_morro_local: Vector3 = Vector3(0.0, 0.1, -2.4)
			var pos_morro_global: Vector3 = global_transform.basis * pos_morro_local
			apply_force(fuerza_arriba, pos_morro_global)
	else:
		_levantamiento_trompa_suave = move_toward(_levantamiento_trompa_suave, 0.0, delta * 3.0)


# ═══════════════════════════════════════════════════════════════════════
# SUBIR / BAJAR JUGADOR
# ═══════════════════════════════════════════════════════════════════════

func subir_jugador(p_jugador: Node3D) -> void:
	var vehs: Array = []
	if get_tree() != null:
		vehs = get_tree().get_nodes_in_group("vehiculo")
	for ov in vehs:
		if ov != self and ov != null:
			if "activo" in ov and ov.activo:
				if ov.has_method("bajar_jugador"):
					ov.bajar_jugador()
				else:
					ov.activo = false

	if activo:
		return
	activo      = true
	jugador_ref = p_jugador
	if is_instance_valid(icono_entrada) and icono_entrada.has_method("ocultar"):
		icono_entrada.ocultar()
	GestorVehiculos.subir_jugador_a_vehiculo(p_jugador, self)

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass      = centro_de_masa
	linear_velocity     = Vector3.ZERO
	angular_velocity    = Vector3.ZERO
	freeze              = false
	_vel_previa         = Vector3.ZERO

	if p_jugador.has_method("ocultar_interfaz_pie"):
		p_jugador.ocultar_interfaz_pie()
	var root_node = get_tree().get_root() if get_tree() else null
	if root_node:
		for pat in ["*UIpie*", "*UiPie*", "*uipie*", "*UIPie*"]:
			for pie in root_node.find_children(pat, "", true, false):
				if is_instance_valid(pie) and (pie is CanvasLayer or pie is Control):
					pie.visible = false
					pie.process_mode = Node.PROCESS_MODE_DISABLED

	# Instanciar UIVehiculo de forma segura
	if not ui_vehiculo:
		var ui_scene := load("res://interfaz/hud/conduccion/UIVehiculo.tscn") as PackedScene
		if ui_scene:
			ui_vehiculo = ui_scene.instantiate() as CanvasLayer
			add_child(ui_vehiculo)

	if ui_vehiculo:
		ui_vehiculo.set("vehiculo", self)
		ui_vehiculo.visible = true

	# Conectar configuración del vehículo (velocidad máxima / rpm) a la UI
	if ui_vehiculo:
		var speed_max_kmh: float = ui_vehiculo.get("velocidad_maxima") if ui_vehiculo.has_method("get") else 180.0
		var rpm_max_val: float = ui_vehiculo.get("rpm_maxima") if ui_vehiculo.has_method("get") else 3200.0
		
		if config != null and config.get("motor_config") != null:
			var mcfg = config.get("motor_config")
			if mcfg.has_method("get"):
				if mcfg.get("velocidad_maxima_kmh") != null:
					speed_max_kmh = float(mcfg.get("velocidad_maxima_kmh"))
				elif mcfg.get("velocidad_marchas") != null:
					var arr = mcfg.get("velocidad_marchas")
					if arr and arr.size() > 0:
						speed_max_kmh = float(arr[arr.size() - 1])
				if mcfg.get("rpm_maximas") != null:
					rpm_max_val = float(mcfg.get("rpm_maximas"))
		else:
			var mnode = get_node_or_null("Motor")
			if mnode and mnode.has_method("get"):
				if mnode.get("config") != null:
					var mc2 = mnode.get("config")
					if mc2.get("velocidad_maxima_kmh") != null:
						speed_max_kmh = float(mc2.get("velocidad_maxima_kmh"))
					if mc2.get("rpm_maximas") != null:
						rpm_max_val = float(mc2.get("rpm_maximas"))

		if ui_vehiculo.has_method("set"):
			ui_vehiculo.set("velocidad_maxima", speed_max_kmh)
			ui_vehiculo.set("rpm_maxima", rpm_max_val)

	_cachear_materiales_sucios()

	if is_instance_valid(get_node_or_null("/root/InputVehiculo")):
		var iv = get_node("/root/InputVehiculo")
		iv.conduciendo = true
		iv.set_marcha_enum(iv.Marcha.NEUTRO)
		iv.freno_mano = true
		# Leer si el motor del vehículo ya estaba físicamente activo o sincronizado
		if motor:
			iv.motor_encendido = motor.get("motor_encendido") == true or motor.get("encendido") == true
		else:
			iv.motor_encendido = iv.motor_encendido

	_collect_local_cameras()
	if camera_manager and camera_manager.has_method("activar_camaras"):
		camera_manager.activar_camaras()
	if debug_vehiculo:
		print("coche.gd: subir_jugador -> camera_manager=", camera_manager, " local_cams=", _local_cameras.size())

	if debug_vehiculo and motor:
		if typeof(motor.get("debug_transmission")) != TYPE_NIL:
			motor.set("debug_transmission", true)

	var llc := get_node_or_null("ControladorLlantas")
	if not llc:
		llc = get_node_or_null("ControladosRuedas")
	if llc and debug_vehiculo:
		if typeof(llc.get("debug_finder")) != TYPE_NIL:
			llc.set("debug_finder", true)
		if typeof(llc.get("llantas_todas")) != TYPE_NIL:
			for rueda in llc.get("llantas_todas"):
				if rueda and typeof(rueda.get("debug_llanta")) != TYPE_NIL:
					rueda.set("debug_llanta", true)

	var seat: Node3D = _find_seat_node()
	if seat and is_instance_valid(p_jugador):
		var offset_pos: Vector3 = p_jugador.get("asiento_offset_pos") if p_jugador.get("asiento_offset_pos") != null else Vector3.ZERO
		var offset_rot: Vector3 = p_jugador.get("asiento_offset_rot") if p_jugador.get("asiento_offset_rot") != null else Vector3.ZERO
		p_jugador.global_position = seat.global_position + seat.global_transform.basis * offset_pos
		p_jugador.global_rotation = seat.global_rotation + deg_to_rad(1.0) * offset_rot

	p_jugador.process_mode = Node.PROCESS_MODE_INHERIT

	var cam_p: Camera3D = p_jugador.find_child("Camera3D", true, false) as Camera3D
	if cam_p:
		cam_p.current = false

	_conectar_senales_ui()
	
	if ui_vehiculo:
		var dash = ui_vehiculo.find_child("Dashboard", true, false)
		if dash:
			dash.set("vehicle", self)
			if ui_vehiculo.has_method("get"):
				var ui_speed_max = ui_vehiculo.get("velocidad_maxima")
				if ui_speed_max != null:
					dash.set("speedometer_max", float(ui_speed_max))
			if dash.has_method("_ensure_rpm_source"):
				dash.call("_ensure_rpm_source")
			if dash.has_method("set_speed"):
				dash.call("set_speed", linear_velocity.length())

	_alternar_sistemas(true)
	_activar_luces(true)

	var gm: Node = _gm()
	if gm:
		if gm.has_method("CambiarCamaraGlobal"):
			gm.call("CambiarCamaraGlobal", 1)
		elif gm.has_method("cambiar_camara_global"):
			gm.call("cambiar_camara_global")
		else:
			activar_camara(1)
			_force_make_current(1)
	else:
		activar_camara(1)
		_force_make_current(1)
	_al_cambiar_camara(1)


func bajar_jugador() -> void:
	if debug_vehiculo:
		print("coche.gd: bajar_jugador() llamado. jugador_ref=", jugador_ref)
	if not activo:
		return
	activo = false

	if is_instance_valid(jugador_ref):
		var seat: Node3D = _find_seat_node()
		var posicion_salida: Vector3 = global_position
		
		var zona_entrada: Area3D = find_child("ZonaEntrada", true, false) as Area3D
		if zona_entrada and is_instance_valid(zona_entrada):
			posicion_salida = zona_entrada.global_position + Vector3.UP * salida_offset_vertical
		else:
			var anchor: Vector3 = global_position
			var right_vec: Vector3 = global_transform.basis.x.normalized()
			if seat and is_instance_valid(seat):
				anchor = seat.global_position
				right_vec = seat.global_transform.basis.x.normalized()

			var cand1: Vector3 = anchor + right_vec * salida_offset_lateral
			var cand2: Vector3 = anchor - right_vec * salida_offset_lateral

			var dist1: float = cand1.distance_to(global_position)
			var dist2: float = cand2.distance_to(global_position)
			posicion_salida = cand1 if dist1 > dist2 else cand2

			var espacio: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
			if espacio:
				var parametros: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
					posicion_salida + Vector3.UP * 3.0,
					posicion_salida - Vector3.UP * 3.0,
					0xFFFFFFFF,
					[self]
				)
				var resultado: Dictionary = espacio.intersect_ray(parametros)
				if resultado and resultado.has("position"):
					posicion_salida = resultado["position"] + Vector3.UP * salida_offset_vertical
				else:
					posicion_salida.y = global_position.y + salida_offset_vertical

		GestorVehiculos.bajar_jugador_de_vehiculo(jugador_ref, self, posicion_salida)
		jugador_ref = null

		_jugador_cam_node = null
		_jugador_cam_original_parent = null
		_jugador_cam_original_global_transform = Transform3D()

		if is_instance_valid(ui_vehiculo):
			ui_vehiculo.visible = false
			var dash_clear = ui_vehiculo.find_child("Dashboard", true, false)
			if dash_clear:
				dash_clear.set("vehicle", null)
				if dash_clear.has_method("set_speed"):
					dash_clear.call("set_speed", 0.0)

		if is_instance_valid(get_node_or_null("/root/InputVehiculo")):
			# NO llamar a stop_driving() completo porque apaga el motor. 
			# En su lugar, desactivar el flag conduciendo y resetear inputs temporales sin apagar el motor.
			var iv = get_node("/root/InputVehiculo")
			iv.conduciendo = false
			iv.gas = 0.0
			iv.freno = 0.0
			iv.direccion = 0.0

	if spring_arm:
		spring_arm.set_process(false)

	if camera_manager and camera_manager.has_method("desactivar_camaras"):
		camera_manager.call("desactivar_camaras")
		
	_alternar_sistemas(false)
	_activar_luces(false)

	if is_instance_valid(get_node_or_null("/root/InputVehiculo")):
		get_node("/root/InputVehiculo").set("freno_mano", true)

	if linear_velocity.length() < 0.5:
		linear_velocity  = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true


# ═══════════════════════════════════════════════════════════════════════
# SUCIEDAD / CONDICIONES DE SUPERFICIE
# ═══════════════════════════════════════════════════════════════════════

func notificar_impacto_vidrio(fuerza: float) -> void:
	# Buscar recursivamente el nodo Parabrisas en todo el arbol del vehiculo
	_buscar_y_notificar_parabrisas(self, fuerza)

func _buscar_y_notificar_parabrisas(nodo: Node, fuerza: float) -> void:
	for hijo in nodo.get_children():
		if hijo.has_method("check_collision_impact"):
			hijo.check_collision_impact(fuerza)
		if hijo.get_child_count() > 0:
			_buscar_y_notificar_parabrisas(hijo, fuerza)

func notificar_suciedad(incremento: float) -> void:
	if _materiales_sucios_cache.is_empty():
		_cachear_materiales_sucios()
	self.nivel_suciedad = clamp(nivel_suciedad + incremento, 0.0, 1.0)

func notificar_barro(incremento: float) -> void:
	nivel_barro    = clamp(nivel_barro    + incremento, 0.0, 1.0)
	self.nivel_suciedad = clamp(nivel_suciedad - incremento * 0.5, 0.0, 1.0)

func notificar_mojado(valor: float) -> void:
	nivel_mojado = clamp(valor, 0.0, 1.0)
	_factor_grip = 1.0 - nivel_barro * 0.55 - nivel_mojado * 0.20
	_factor_grip = clamp(_factor_grip, 0.25, 1.0)

func limpiar_suciedad(cantidad: float) -> void:
	self.nivel_suciedad = clamp(nivel_suciedad - cantidad, 0.0, 1.0)
	nivel_barro    = clamp(nivel_barro    - cantidad, 0.0, 1.0)


# ═══════════════════════════════════════════════════════════════════════
# DETECCIÓN DE JUGADOR
# ═══════════════════════════════════════════════════════════════════════

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
		jugador_ref   = body
		if is_instance_valid(icono_entrada) and icono_entrada.has_method("mostrar"):
			icono_entrada.mostrar(body)
		if body.has_method("notificar_vehiculo_cerca"):
			body.notificar_vehiculo_cerca(self)

func _on_body_exited(body: Node3D) -> void:
	if body == jugador_ref and not activo:
		jugador_cerca = false
		jugador_ref   = null
		if is_instance_valid(icono_entrada) and icono_entrada.has_method("ocultar"):
			icono_entrada.ocultar()
		if body.has_method("notificar_vehiculo_lejos"):
			body.notificar_vehiculo_lejos(self)


# ═══════════════════════════════════════════════════════════════════════
# SISTEMAS INTERNOS
# ═══════════════════════════════════════════════════════════════════════

func _alternar_sistemas(estado: bool) -> void:
	if is_instance_valid(motor):
		motor.set_physics_process(estado)
	if is_instance_valid(llantas_controlador):
		llantas_controlador.set_physics_process(estado)

func _activar_luces(presente: bool) -> void:
	if not presente:
		luces_emergencia      = false
		direccional_izquierda = false
		direccional_derecha   = false
	if is_instance_valid(luz_stop_node) and luz_stop_node.has_method("set_conductor_presente"):
		luz_stop_node.set_conductor_presente(presente)
	var dir_node: Node = get_node_or_null("Luces/Direccionales")
	if is_instance_valid(dir_node) and dir_node.has_method("set_conductor_presente"):
		dir_node.set_conductor_presente(presente)

func _conectar_senales_ui() -> void:
	if not is_instance_valid(ui_vehiculo):
		return
	var zona_cam: Node = ui_vehiculo.find_child("ZonaCamara", true, false)
	if not zona_cam:
		return
	# Reconectar el brazo/camara en caso de que ZonaCamara se haya inicializado
	# antes de que UIVehiculo fuera hijo del vehículo (timing de instancia dinámica)
	if zona_cam.has_method("_buscar_brazo"):
		zona_cam.call("_buscar_brazo")
	# Conexión directa de respaldo — coche.gd redirige al CameraManager si existe
	if zona_cam.has_signal("camara_movida"):
		if not zona_cam.camara_movida.is_connected(_on_camara_movida):
			zona_cam.camara_movida.connect(_on_camara_movida)
	# Conectar pinch al CameraManager si existe, de lo contrario al vehículo
	if zona_cam.has_signal("camara_pinch") and camera_manager and camera_manager.has_method("_distribuir_pinch"):
		if not zona_cam.camara_pinch.is_connected(camera_manager._distribuir_pinch):
			zona_cam.camara_pinch.connect(camera_manager._distribuir_pinch)


# ═══════════════════════════════════════════════════════════════════════
# CÁMARAS
# ═══════════════════════════════════════════════════════════════════════

func _al_cambiar_camara(id: int) -> void:
	if not activo:
		return
	indice_camara = id
	if camera_manager:
		if camera_manager.has_method("activar_camara"):
			camera_manager.activar_camara(id)
		elif camera_manager.has_method("seleccionar_camara"):
			camera_manager.seleccionar_camara(id)
	if is_instance_valid(jugador_ref) and jugador_ref.has_method("activar_camara_conduccion"):
		jugador_ref.activar_camara_conduccion(id)
	_force_make_current(id)

func _on_camara_movida(relative: Vector2) -> void:
	if not activo:
		return
	if camera_manager and camera_manager.has_method("mover_camara"):
		var idx: int = camera_manager.get("indice_actual") if typeof(camera_manager.get("indice_actual")) != TYPE_NIL else indice_camara
		camera_manager.mover_camara(idx, relative)
		return
	# Fallback: sin CameraManager, enviar directamente al BrazoCamara
	var brazo: Node = get_node_or_null("BrazoCamara")
	if brazo and brazo.has_method("_on_camara_movida"):
		brazo._on_camara_movida(relative)
		return
	# Último recurso: usar la cámara activa local
	if _local_cameras.size() > 0:
		var cam := _local_cameras[clamp(_active_camera_idx, 0, _local_cameras.size() - 1)]
		if cam and cam.get_parent() and cam.get_parent().has_method("_on_camara_movida"):
			cam.get_parent()._on_camara_movida(relative)

func _collect_local_cameras() -> void:
	_local_cameras.clear()
	for n in get_children():
		_collect_cameras_recursive(n)
	if _local_cameras.size() == 0 and camera_manager:
		_collect_cameras_recursive(camera_manager)

	_local_cameras.sort_custom(_compare_camera_priority)

func _collect_cameras_recursive(n: Node) -> void:
	if n is Camera3D:
		_local_cameras.append(n)
	for c in n.get_children():
		_collect_cameras_recursive(c)

func _camera_priority(cam: Camera3D) -> int:
	if not cam: return 0
	var cam_name := cam.name.to_lower() if typeof(cam.name) == TYPE_STRING else ""
	var parent_name := cam.get_parent().name.to_lower() if (cam.get_parent() and typeof(cam.get_parent().name) == TYPE_STRING) else ""
	if cam_name.find("intern") != -1 or cam_name.find("driver") != -1 or cam_name.find("cockpit") != -1 or cam_name.find("inside") != -1:
		return 1
	if cam_name.find("extern") != -1 or cam_name.find("follow") != -1 or cam_name.find("third") != -1 or parent_name.find("brazo") != -1 or parent_name.find("spring") != -1:
		return 0
	return 0

func _compare_camera_priority(a, b) -> bool:
	return _camera_priority(a) < _camera_priority(b)

func activar_camara(id: int) -> void:
	if camera_manager and camera_manager.has_method("activar_camara"):
		camera_manager.activar_camara(id)
		return
	if _local_cameras.size() == 0:
		return
	_active_camera_idx = clamp(id, 0, _local_cameras.size() - 1)
	for i in range(_local_cameras.size()):
		var cam = _local_cameras[i]
		if cam is Camera3D:
			cam.current = (i == _active_camera_idx)

func _force_make_current(id: int) -> void:
	if camera_manager:
		return
	_collect_local_cameras()
	if _local_cameras.size() == 0:
		return
	var idx: int = clamp(id, 0, _local_cameras.size() - 1)
	var cam: Camera3D = _local_cameras[idx]
	if cam and cam is Camera3D:
		cam.make_current()
		return
	for c in _local_cameras:
		if c and c is Camera3D:
			c.make_current()
			return

func mover_camara(indice: int, relative: Vector2) -> void:
	if camera_manager and camera_manager.has_method("mover_camara"):
		camera_manager.mover_camara(indice, relative)
		return
	if _local_cameras.size() == 0:
		return
	var cam: Camera3D = _local_cameras[clamp(indice, 0, _local_cameras.size() - 1)]
	if cam == null:
		return
	if cam.has_method("_manejar_rotacion_libre"):
		cam._manejar_rotacion_libre(relative)
		return
	var p: Node = cam.get_parent()
	if p and p.has_method("_on_camara_movida"):
		p.call("_on_camara_movida", relative)

func _detect_camera_manager() -> Node:
	var local_names: Array[String] = ["CameraManager", "CameraManeger"]
	for nombre in local_names:
		var cand: Node = get_node_or_null(nombre)
		if cand and (cand.has_method("activar_camara") or cand.has_method("seleccionar_camara") or cand.has_method("mover_camara")):
			return cand
	var stack_local: Array[Node] = [self]
	while stack_local.size() > 0:
		var n_local = stack_local.pop_back()
		if n_local == null:
			continue
		if n_local != self and (n_local.has_method("activar_camara") or n_local.has_method("seleccionar_camara") or n_local.has_method("mover_camara")):
			return n_local
		for hijo in n_local.get_children():
			stack_local.append(hijo)
	return null

# ==========================================
# UTILIDADES
# ==========================================

func vel_vec_plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

# ==========================================
# DEBUG
# ==========================================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var focus_owner = get_viewport().gui_get_focus_owner() if get_viewport() else null
	if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
		return
	match event.keycode:
		KEY_U: notificar_suciedad(0.1)
		KEY_B: notificar_barro(0.1)
		KEY_M: notificar_mojado(minf(nivel_mojado + 0.1, 1.0))
		KEY_I:
			self.nivel_suciedad = 0.0
			nivel_barro    = 0.0
			nivel_mojado   = 0.0
			_factor_grip   = 1.0

		KEY_F2:
			print("[coche] vel=%.2f m/s | grip=%.2f | masa=%.0f kg" % [
				linear_velocity.length(),
				_factor_grip,
				masa_kg + peso_carga_actual
			])

func _cachear_materiales_sucios() -> void:
	_materiales_sucios_cache.clear()
	_recopilar_materiales_sucios_recursivo(self)

func _recopilar_materiales_sucios_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var n_name = nodo.name.to_lower()
		var es_nodo_cromado = "cromo" in n_name or "metal" in n_name or "rin" in n_name or "rim" in n_name or "exhaust" in n_name or "bumper" in n_name or "tubo" in n_name or "tanque" in n_name or "espejo" in n_name or "plato" in n_name or "quinta" in n_name
		
		var mat_over = nodo.material_override
		if mat_over:
			_evaluar_y_cachear_material(mat_over, es_nodo_cromado)
		for i in range(nodo.get_surface_override_material_count()):
			var mat = nodo.get_surface_override_material(i)
			if mat:
				_evaluar_y_cachear_material(mat, es_nodo_cromado)
		if nodo.mesh:
			for i in range(nodo.mesh.get_surface_count()):
				var mat = nodo.get_active_material(i)
				if mat:
					_evaluar_y_cachear_material(mat, es_nodo_cromado)
	for hijo in nodo.get_children():
		_recopilar_materiales_sucios_recursivo(hijo)

func _evaluar_y_cachear_material(mat: Material, es_nodo_cromado: bool) -> void:
	if _materiales_sucios_cache.has(mat):
		return
		
	# PROTECCIÓN: Si el material se crea por código, su ruta o nombre puede ser nulo
	var m_name = mat.resource_name.to_lower() if mat.resource_name else ""
	var path = mat.resource_path.to_lower() if mat.resource_path else ""
	
	if mat is ShaderMaterial:
		if "cromo" in m_name or "cromo" in path or "carroceria" in m_name or "carroceria" in path or "cristal" in m_name or "cristal" in path or "vidrio" in m_name or "vidrio" in path or es_nodo_cromado or mat.get_shader_parameter("dirt_amount") != null or mat.get_shader_parameter("dirt_intensity") != null:
			_materiales_sucios_cache.append(mat)
	elif mat is StandardMaterial3D:
		if "cromo" in m_name or "metal" in m_name or "rin" in m_name or "rim" in m_name or "cromo" in path or "metal" in path or es_nodo_cromado:
			if not mat.has_meta("original_albedo"):
				mat.set_meta("original_albedo", mat.albedo_color)
				mat.set_meta("original_roughness", mat.roughness)
				mat.set_meta("original_metallic", mat.metallic)
			_materiales_sucios_cache.append(mat)

func _actualizar_suciedad_materiales(valor: float) -> void:
	for mat in _materiales_sucios_cache:
		if not is_instance_valid(mat):
			continue
		if mat is ShaderMaterial:
			if mat.get_shader_parameter("dirt_amount") != null:
				mat.set_shader_parameter("dirt_amount", valor)
			if mat.get_shader_parameter("dirt_intensity") != null:
				mat.set_shader_parameter("dirt_intensity", valor)
		elif mat is StandardMaterial3D:
			var orig_color = mat.get_meta("original_albedo")
			var orig_rough = mat.get_meta("original_roughness")
			var orig_metal = mat.get_meta("original_metallic")
			var color_tierra = Color(0.35, 0.27, 0.18)
			mat.albedo_color = orig_color.lerp(color_tierra, valor * 0.7)
			mat.roughness = lerp(orig_rough, 0.7, valor)
			mat.metallic = lerp(orig_metal, 0.15, valor)

@rpc("any_peer", "unreliable")
func actualizar_transform_vehiculo(pos: Vector3, rot: Vector3, lin_vel: Vector3, ang_vel: Vector3) -> void:
	if not is_multiplayer_authority():
		_pos_objetivo = pos
		_rot_objetivo = rot
		linear_velocity = lin_vel
		angular_velocity = ang_vel

func _on_coche_body_entered(body: Node) -> void:
	# NOTA: linear_velocity ya fue modificada por la fisica al momento del signal.
	# Usamos _vel_previa (velocidad del frame anterior al impacto) para medir la fuerza real.
	var fuerza_choque: float = _vel_previa.length()

	print("[CHOQUE] body_entered | body='%s' | fuerza=%.2f m/s | _vel_previa=%.2f" % [
		body.name, fuerza_choque, _vel_previa.length()])

	# Reportar impacto al trabajo de Mensajero si está activo
	var mensajero = get_tree().current_scene.find_child("Mensajero", true, false)
	if mensajero and mensajero.has_method("registrar_impacto_vehiculo"):
		mensajero.call("registrar_impacto_vehiculo", fuerza_choque)

	# Choque suave (entre 1.5 m/s y 4.0 m/s): solo sonido
	if fuerza_choque >= 1.5 and fuerza_choque < 4.0:
		if not _stream_choque_leve:
			_stream_choque_leve = load("res://recursos/sonidos_vehiculo/efectos/choque_leve.mp3")
			
		var audio_choque = AudioStreamPlayer3D.new()
		audio_choque.stream = _stream_choque_leve
		audio_choque.volume_db = 5.0
		audio_choque.unit_size = 15.0
		add_child(audio_choque)
		audio_choque.play()
		audio_choque.finished.connect(func(): audio_choque.queue_free())

	# Choque fuerte (>= 4.0 m/s): dano en parabrisas + deformacion visual
	elif fuerza_choque >= 4.0:
		print("[CHOQUE] Choque FUERTE detectado! Notificando dano...")
		notificar_impacto_vidrio(fuerza_choque)

# ─── Tablet Placement & Configuration ───────────────────────────────────

func _cargar_tablet_offsets() -> void:
	var config_file = ConfigFile.new()
	if config_file.load("user://tablet_offsets.cfg") == OK:
		tableta_offset_pos = config_file.get_value("tablet", "position", Vector3.ZERO)
		tableta_offset_rot = config_file.get_value("tablet", "rotation", Vector3.ZERO)
	else:
		tableta_offset_pos = Vector3.ZERO
		tableta_offset_rot = Vector3.ZERO

func _guardar_tablet_offsets() -> void:
	var config_file = ConfigFile.new()
	config_file.set_value("tablet", "position", tableta_offset_pos)
	config_file.set_value("tablet", "rotation", tableta_offset_rot)
	config_file.save("user://tablet_offsets.cfg")

func colocar_tableta(tableta: Node3D) -> void:
	if not is_instance_valid(tableta):
		return
		
	if is_instance_valid(jugador_ref):
		jugador_ref.set("caja_agarrada", null)
		if "mano_izq_ik" in jugador_ref and jugador_ref.mano_izq_ik:
			jugador_ref.mano_izq_ik.stop()
		if "mano_der_ik" in jugador_ref and jugador_ref.mano_der_ik:
			jugador_ref.mano_der_ik.stop()
			
		# Remover tableta del inventario
		var inv = jugador_ref.get("inventario")
		if inv and inv.get("items"):
			var items_list = inv.get("items")
			for i in range(items_list.size()):
				if items_list[i].get("ref") == tableta:
					inv.call("remover_item", i)
					break
			
	if tableta.get_parent():
		tableta.get_parent().remove_child(tableta)
	
	var pos_marker = find_child("pos_tableta", true, false)
	var parent_node = pos_marker if pos_marker else self
	
	tableta_en_vehiculo = tableta
	parent_node.add_child(tableta)
	
	tableta.visible = true
	
	_cargar_tablet_offsets()
	
	tableta.position = tableta_offset_pos
	tableta.rotation_degrees = tableta_offset_rot
	
	if tableta is RigidBody3D:
		tableta.freeze = true
	
	if tableta.has_method("_find_player"):
		tableta.call("_ready")

func _mostrar_tablet_prompt(texto: String) -> void:
	if not _tablet_ui_label:
		var cl = CanvasLayer.new()
		cl.layer = 100
		add_child(cl)
		_tablet_ui_label = Label.new()
		_tablet_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tablet_ui_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tablet_ui_label.add_theme_font_size_override("font_size", 28)
		_tablet_ui_label.add_theme_color_override("font_color", Color.YELLOW)
		_tablet_ui_label.anchor_left = 0.0
		_tablet_ui_label.anchor_right = 1.0
		_tablet_ui_label.anchor_top = 0.8
		_tablet_ui_label.anchor_bottom = 0.9
		cl.add_child(_tablet_ui_label)
	_tablet_ui_label.text = texto
	_tablet_ui_label.visible = true

func _ocultar_tablet_prompt() -> void:
	if _tablet_ui_label:
		_tablet_ui_label.visible = false

# ─── Mobile Touch Interactions for Tablet ──────────────────────────────

var _btn_colocar_cl: CanvasLayer = null
var _panel_ajuste_cl: CanvasLayer = null
var _tablet_touch_connected: bool = false

func _crear_boton_colocar_tableta(tableta: Node3D) -> void:
	if is_instance_valid(_btn_colocar_cl):
		return
		
	_btn_colocar_cl = CanvasLayer.new()
	_btn_colocar_cl.layer = 110
	add_child(_btn_colocar_cl)
	
	var btn = Button.new()
	btn.text = "POSICIONAR TABLETA"
	btn.custom_minimum_size = Vector2(280, 80)
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.anchor_top = 0.75
	btn.anchor_bottom = 0.75
	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.75, 0.35, 0.9)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_font_size_override("font_size", 24)
	
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		btn.add_theme_font_override("font", load(font_path))
		
	btn.pressed.connect(func():
		colocar_tableta(tableta)
		_destruir_boton_colocar_tableta()
	)
	_btn_colocar_cl.add_child(btn)

func _destruir_boton_colocar_tableta() -> void:
	if is_instance_valid(_btn_colocar_cl):
		_btn_colocar_cl.queue_free()
	_btn_colocar_cl = null

func _inicializar_interaccion_tactil_tableta() -> void:
	if _tablet_touch_connected or not is_instance_valid(tableta_en_vehiculo):
		return
		
	# Para poder detectar clicks o toques en la tableta 3D, necesitamos un Area3D.
	# Si no existe, creamos un Area3D con un CollisionShape3D dinámicamente alrededor de la tableta.
	var area = tableta_en_vehiculo.get_node_or_null("AreaClick")
	if not area:
		area = Area3D.new()
		area.name = "AreaClick"
		tableta_en_vehiculo.add_child(area)
		
		var collision = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.5, 0.8, 0.1) # Dimensiones típicas de la tableta
		collision.shape = box
		area.add_child(collision)
		
	if not area.input_event.is_connected(_on_tableta_input_event):
		area.input_event.connect(_on_tableta_input_event)
		
	_tablet_touch_connected = true

func _on_tableta_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if not ajustando_tableta:
			ajustando_tableta = true
			tableta_offset_pos = tableta_en_vehiculo.position
			tableta_offset_rot = tableta_en_vehiculo.rotation_degrees

func _crear_panel_ajuste_tableta() -> void:
	if is_instance_valid(_panel_ajuste_cl):
		return
		
	_panel_ajuste_cl = CanvasLayer.new()
	_panel_ajuste_cl.layer = 110
	add_child(_panel_ajuste_cl)
	
	# Panel de fondo difuminado/oscuro para albergar controles
	var panel = PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.70
	panel.anchor_bottom = 0.95
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", sb)
	_panel_ajuste_cl.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "AJUSTAR TABLETA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		title.add_theme_font_override("font", load(font_path))
	vbox.add_child(title)
	
	# Fila de botones para movimiento (X, Y, Z, R)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var btn_left = Button.new()
	btn_left.text = "<- X"
	btn_left.custom_minimum_size = Vector2(80, 50)
	btn_left.pressed.connect(func(): tableta_offset_pos.x -= 0.03; _actualizar_tablet_temp())
	hbox.add_child(btn_left)
	
	var btn_right = Button.new()
	btn_right.text = "X ->"
	btn_right.custom_minimum_size = Vector2(80, 50)
	btn_right.pressed.connect(func(): tableta_offset_pos.x += 0.03; _actualizar_tablet_temp())
	hbox.add_child(btn_right)
	
	var btn_down = Button.new()
	btn_down.text = "v Y"
	btn_down.custom_minimum_size = Vector2(80, 50)
	btn_down.pressed.connect(func(): tableta_offset_pos.y -= 0.03; _actualizar_tablet_temp())
	hbox.add_child(btn_down)
	
	var btn_up = Button.new()
	btn_up.text = "^ Y"
	btn_up.custom_minimum_size = Vector2(80, 50)
	btn_up.pressed.connect(func(): tableta_offset_pos.y += 0.03; _actualizar_tablet_temp())
	hbox.add_child(btn_up)
	
	var btn_in = Button.new()
	btn_in.text = "Z Forward"
	btn_in.custom_minimum_size = Vector2(90, 50)
	btn_in.pressed.connect(func(): tableta_offset_pos.z -= 0.03; _actualizar_tablet_temp())
	hbox.add_child(btn_in)
	
	var btn_out = Button.new()
	btn_out.text = "Z Back"
	btn_out.custom_minimum_size = Vector2(90, 50)
	btn_out.pressed.connect(func(): tableta_offset_pos.z += 0.03; _actualizar_tablet_temp())
	hbox.add_child(btn_out)
	
	var btn_rot_l = Button.new()
	btn_rot_l.text = "Rot Left"
	btn_rot_l.custom_minimum_size = Vector2(90, 50)
	btn_rot_l.pressed.connect(func(): tableta_offset_rot.y -= 5.0; _actualizar_tablet_temp())
	hbox.add_child(btn_rot_l)
	
	var btn_rot_r = Button.new()
	btn_rot_r.text = "Rot Right"
	btn_rot_r.custom_minimum_size = Vector2(90, 50)
	btn_rot_r.pressed.connect(func(): tableta_offset_rot.y += 5.0; _actualizar_tablet_temp())
	hbox.add_child(btn_rot_r)
	
	var btn_save = Button.new()
	btn_save.text = "GUARDAR"
	btn_save.custom_minimum_size = Vector2(120, 50)
	var sb_save = StyleBoxFlat.new()
	sb_save.bg_color = Color(0.1, 0.6, 0.8, 1.0)
	btn_save.add_theme_stylebox_override("normal", sb_save)
	btn_save.pressed.connect(func():
		ajustando_tableta = false
		_destruir_panel_ajuste_tableta()
		_guardar_tablet_offsets()
	)
	hbox.add_child(btn_save)

func _actualizar_tablet_temp() -> void:
	if is_instance_valid(tableta_en_vehiculo):
		tableta_en_vehiculo.position = tableta_offset_pos
		tableta_en_vehiculo.rotation_degrees = tableta_offset_rot

func _destruir_panel_ajuste_tableta() -> void:
	if is_instance_valid(_panel_ajuste_cl):
		_panel_ajuste_cl.queue_free()
	_panel_ajuste_cl = null

func _destruir_botones_tactiles_tableta() -> void:
	_destruir_boton_colocar_tableta()
	_destruir_panel_ajuste_tableta()
	_tablet_touch_connected = false
