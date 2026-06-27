# controlador_rpm.gd
# controlador_rpm.gd
extends Node
class_name ControladorRPM

@export var config: Resource = null

# Variables de salida
var rpm_actual: float = 600.0
var rpm_normalizada: float = 0.0 # Valor de 0.0 a 1.0 para el sonido
# Flags que la UI puede leer/escribir para ajustar sonidos/estados visuales
var en_reversa: bool = false
var en_parqueo: bool = false

# Variables internas
var _gas_suavizado: float = 0.0

# Referencia al sistema de audio
var sistema_audio: Node3D = null

func _cfg_get_float(names: Array, default: float) -> float:
	if not config:
		return default
	for n in names:
		var v = config.get(n) if config.has_method("get") else null
		if v != null:
			return float(v)
	return default

func _rpm_min() -> float:
	return _cfg_get_float(["rpm_minimas", "rpm_idle"], 600.0)

func _rpm_max() -> float:
	return _cfg_get_float(["rpm_maximas", "rpm_maximas"], 3200.0)

func _inercia_cfg() -> float:
	return _cfg_get_float(["inercia_motor"], 0.8)

func _ready() -> void:
	if not config:
		push_error("ControladorRPM: No hay configuración RPM asignada")
		return

	rpm_actual = _rpm_min()

	# Buscar el nodo de sonidos hermano
	var parent = get_parent()
	if parent:
		sistema_audio = parent.get_node_or_null("Sonido_dual")
		if not sistema_audio:
			sistema_audio = parent.get_node_or_null("Sonidos")
		if not sistema_audio:
			push_warning("ControladorRPM: No se encontró nodo 'Sonido_dual' ni 'Sonidos' hermano para el audio del motor")

func _physics_process(delta: float) -> void:
	# Actualizar el audio si existe y tiene el método correcto
	if sistema_audio and sistema_audio.has_method("procesar_audio"):
		var gas_actual = InputVehiculo.gas if is_instance_valid(InputVehiculo) else 0.0
		sistema_audio.procesar_audio(rpm_normalizada, gas_actual, delta)

func actualizar(gas: float, _freno: float, _fmano: bool, vel_ms: float, delta: float) -> void:
	if not config:
		return

	# 1. Suavizamos la entrada del acelerador para un efecto diesel pesado
	_gas_suavizado = lerp(_gas_suavizado, gas, delta * 3.0)

	# 2. Calculamos las RPM basadas en la velocidad del vehículo
	# Simulamos una relación de transmisión fija
	var ratio_transmision = 4.0
	var velocidad_rpm = abs(vel_ms) * ratio_transmision * 30.0

	# 3. Calculamos las RPM basadas en el pedal (Efecto "vacío")
	# Esto permite que el motor ruja incluso si el camión apenas se está moviendo
	var pedal_rpm = _gas_suavizado * (_rpm_max() - _rpm_min())

	# 4. Combinamos ambos factores
	# El motor nunca baja de idle y sube por velocidad o por pedal
	var rpm_obj = _rpm_min() + pedal_rpm + (velocidad_rpm * 0.5)

	# Aplicamos un límite máximo
	rpm_obj = clamp(rpm_obj, _rpm_min(), _rpm_max())

	# 5. Aplicamos la inercia (Suavizado final de la aguja/sonido)
	rpm_actual = lerp(rpm_actual, rpm_obj, delta / _inercia_cfg())

	# 6. Calculamos el valor normalizado para el reproductor de audio
	rpm_normalizada = (rpm_actual - _rpm_min()) / (_rpm_max() - _rpm_min())


func set_rpm(rpm: float, delta: float = 0.0) -> void:
	# Permite que un sistema de motor externo marque directamente las RPM reales.
	if not config:
		return
	var rpm_objetivo = clamp(rpm, _rpm_min(), _rpm_max())
	if delta > 0.0 and _inercia_cfg() > 0.0:
		rpm_actual = lerp(rpm_actual, rpm_objetivo, delta / _inercia_cfg())
	else:
		rpm_actual = rpm_objetivo
	rpm_normalizada = (rpm_actual - _rpm_min()) / (_rpm_max() - _rpm_min())

	# Actualizar sonido si está disponible
	if sistema_audio and sistema_audio.has_method("procesar_audio"):
		var gas_actual = InputVehiculo.gas if is_instance_valid(InputVehiculo) else 0.0
		sistema_audio.procesar_audio(rpm_normalizada, gas_actual, delta)

func get_rpm_norm() -> float:
	return clamp(rpm_normalizada, 0.0, 1.0)
