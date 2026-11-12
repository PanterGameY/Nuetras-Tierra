# controlador_rpm.gd — Controlador de tacómetro y normalización de RPM
extends Node
class_name ControladorRPM

@export var config: Resource = null

var rpm_actual: float = 650.0
var rpm_normalizada: float = 0.0
var en_reversa: bool = false
var en_parqueo: bool = false
var audio_gestionado_externamente: bool = false

var _rpm_min_override: float = -1.0
var _rpm_max_override: float = -1.0
var _gas_suavizado: float = 0.0
var sistema_audio: Node3D = null

func configurar_limites_motor(min_rpm: float, max_rpm: float) -> void:
	_rpm_min_override = min_rpm
	_rpm_max_override = max_rpm

func _cfg_get_float(names: Array, default: float) -> float:
	if config:
		for n in names:
			var v = config.get(n) if config.has_method("get") else null
			if v != null:
				return float(v)
	var p = get_parent()
	if p:
		for n in names:
			var vp = p.get(n) if p.has_method("get") else null
			if vp != null:
				return float(vp)
	return default

func _rpm_min() -> float:
	if _rpm_min_override > 0.0:
		return _rpm_min_override
	return _cfg_get_float(["rpm_minimas", "rpm_idle"], 650.0)

func _rpm_max() -> float:
	if _rpm_max_override > 0.0:
		return _rpm_max_override
	return _cfg_get_float(["rpm_maximas", "rpm_limite_pesado"], 2200.0)

func _inercia_cfg() -> float:
	return _cfg_get_float(["inercia_motor"], 0.15)

func _ready() -> void:
	rpm_actual = _rpm_min()
	var parent = get_parent()
	if parent:
		sistema_audio = parent.get_node_or_null("Sonido_dual")
		if not sistema_audio:
			sistema_audio = parent.get_node_or_null("Sonidos")
		if not sistema_audio and parent.get_parent():
			sistema_audio = parent.get_parent().get_node_or_null("Sonido_dual")
			if not sistema_audio:
				sistema_audio = parent.get_parent().get_node_or_null("Sonidos")

func _get_iv() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/InputVehiculo")

func _physics_process(delta: float) -> void:
	if audio_gestionado_externamente:
		return
	if sistema_audio and sistema_audio.has_method("procesar_audio"):
		var iv = _get_iv()
		var gas_actual = float(iv.get("gas")) if (iv and iv.get("gas") != null) else 0.0
		sistema_audio.procesar_audio(rpm_normalizada, gas_actual, delta)

func actualizar(gas: float, _freno: float, _fmano: bool, _vel_ms: float, delta: float) -> void:
	_gas_suavizado = lerp(_gas_suavizado, gas, delta * 3.0)

func set_rpm(rpm: float, delta: float = 0.0) -> void:
	var r_min = _rpm_min()
	var r_max = maxf(_rpm_max(), r_min + 100.0)
	var rpm_objetivo = clampf(rpm, 0.0, r_max)
	if delta > 0.0 and _inercia_cfg() > 0.0:
		rpm_actual = lerpf(rpm_actual, rpm_objetivo, clampf(delta / _inercia_cfg(), 0.0, 1.0))
	else:
		rpm_actual = rpm_objetivo
	if rpm_actual < r_min * 0.5:
		rpm_normalizada = 0.0
	else:
		rpm_normalizada = clampf((rpm_actual - r_min) / (r_max - r_min), 0.0, 1.0)

func get_rpm_norm() -> float:
	return clampf(rpm_normalizada, 0.0, 1.0)
