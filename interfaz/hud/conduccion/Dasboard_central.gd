# script para controlar el panel central del dashboard, que muestra información de consumo, velocidad, etc.
extends PanelContainer

@export var vehicle_path: NodePath
@export var speed_in_m_s: bool = true # si true, convierte de m/s a km/h multiplicando por 3.6
@export var decimals: int = 0
@export var unit: String = "km/h"
@export var speedometer_max: float = 240.0
@export var auto_cancel_direccionales: bool = true
@export var auto_cancel_threshold: float = 0.12 # umbral normalizado para considerar el volante centrado/opuesto

@onready var label_velocidad = $Margin/VBoxMain/LblVelocidad/LblVelValue
@onready var label_unit = $Margin/VBoxMain/LblVelocidad/LblVelUnit
@onready var gear_label = $Margin/VBoxMain/HBoxContainer/MarchaSection/MarchaPanel/GearLabel
@onready var vehicle = get_node_or_null(vehicle_path)
@onready var velocimetro = null
@onready var revoluciones = null
@onready var rpm_source = null
@onready var dash_dir_left = $Margin/VBoxMain/HBoxContainer/DireccionalIzquierda
@onready var dash_dir_right = $Margin/VBoxMain/HBoxContainer/DireccionalDerecha
@onready var vehicle_direccionales = null
@onready var gas_bar = get_node_or_null("Margin/VBoxMain/BarrasSection/GasContainer/GasolinaBar")
var _prev_steer: float = 0.0
var _steer_initialized: bool = false

func _ready() -> void:
	if vehicle == null and vehicle_path and vehicle_path != NodePath(""):
		vehicle = get_node_or_null(vehicle_path)
	if vehicle == null:
		vehicle = _auto_find_vehicle()
	set_process(true)

	# Buscar y conectar el selector de marchas en la UI para recibir cambios directos
	var selector = _find_selector_marchas_node()
	if selector:
		var cb = Callable(self, "_on_selector_marcha_cambiada")
		if not selector.is_connected("marcha_cambiada", cb):
			selector.connect("marcha_cambiada", cb)
		# Estado inicial si el selector ya tiene marcha
		var m = selector.get("marcha_actual")
		if m != null and gear_label:
			gear_label.text = str(m)

	# Buscar velocimetro en la escena (ColorRect con shader)
	velocimetro = _search_node_by_name(get_tree().get_root(), "Velocimetro")
	if velocimetro:
		# Asegurarnos que el material del velocimetro tenga el max correcto
		var mat = null
		if velocimetro.has_method("get"):
			mat = velocimetro.get("material")
		if mat and mat.has_method("set_shader_parameter"):
			mat.set_shader_parameter("max_rpm", speedometer_max)
	# Buscar revoluciones (ColorRect con shader externo)
	revoluciones = _search_node_by_name(get_tree().get_root(), "revoluciones")
	if revoluciones:
		var mat_r = null
		if revoluciones.has_method("get"):
			mat_r = revoluciones.get("material")
		if mat_r and mat_r.has_method("set_shader_parameter"):
			# Dejar max_rpm por defecto; si encontramos el controlador de RPM lo actualizaremos
			pass

func _process(_delta: float) -> void:
	# Asegurar fuente de RPM disponible
	_ensure_rpm_source()
	if vehicle:
		var raw_speed = _get_vehicle_speed(vehicle)
		if raw_speed >= 0.0:
			_update_label_from_raw(raw_speed)

	# Mostrar marcha desde InputVehiculo directamente
	if gear_label and is_instance_valid(InputVehiculo):
		gear_label.text = _marcha_display()

	# Sincronizar direccionales del dashboard con las del vehículo
	_ensure_vehicle_direccionales()
	var left_on: bool = false
	var right_on: bool = false
	var tiempo_parp: float = -1.0
	if vehicle_direccionales != null and is_instance_valid(vehicle_direccionales):
		var vleft = vehicle_direccionales.get("parpadeando_izquierda") if vehicle_direccionales.has_method("get") else null
		var vright = vehicle_direccionales.get("parpadeando_derecha") if vehicle_direccionales.has_method("get") else null
		if vleft != null:
			left_on = bool(vleft)
		if vright != null:
			right_on = bool(vright)
		var t = vehicle_direccionales.get("tiempo_parpadeo") if vehicle_direccionales.has_method("get") else null
		if t != null:
			tiempo_parp = float(t)

	# --- Auto-cancel: apagar direccionales cuando el volante vuelve hacia el centro/opuesto ---
	var steer_norm: float = _get_steering_norm()
	# Solo evaluar si la feature está activa y hay un nodo de direccionales
	if auto_cancel_direccionales and vehicle_direccionales != null and is_instance_valid(vehicle_direccionales):
		# Cancelar izquierda si antes girábamos a la izquierda y ahora volvemos hacia el centro/opuesto
		if left_on:
			if _steer_initialized and _prev_steer < -0.01 and steer_norm >= -auto_cancel_threshold:
				if vehicle_direccionales.has_method("desactivar_izquierda"):
					vehicle_direccionales.call("desactivar_izquierda")
				else:
					vehicle_direccionales.set("parpadeando_izquierda", false)
		# Cancelar derecha si antes girábamos a la derecha y ahora volvemos hacia el centro/opuesto
		if right_on:
			if _steer_initialized and _prev_steer > 0.01 and steer_norm <= auto_cancel_threshold:
				if vehicle_direccionales.has_method("desactivar_derecha"):
					vehicle_direccionales.call("desactivar_derecha")
				else:
					vehicle_direccionales.set("parpadeando_derecha", false)
	# Actualizar previo
	_prev_steer = steer_norm
	_steer_initialized = true

	# Actualizar materiales del dashboard
	if dash_dir_left != null and dash_dir_left.has_method("get"):
		var mat_l = dash_dir_left.get("material")
		if mat_l and mat_l.has_method("set_shader_parameter"):
			mat_l.set_shader_parameter("is_on", left_on)
			if tiempo_parp > 0.0:
				mat_l.set_shader_parameter("blink_speed", clamp(2.5 / tiempo_parp, 0.1, 10.0))
	if dash_dir_right != null and dash_dir_right.has_method("get"):
		var mat_rh = dash_dir_right.get("material")
		if mat_rh and mat_rh.has_method("set_shader_parameter"):
			mat_rh.set_shader_parameter("is_on", right_on)
			if tiempo_parp > 0.0:
				mat_rh.set_shader_parameter("blink_speed", clamp(2.5 / tiempo_parp, 0.1, 10.0))
	# Actualizar indicador de revoluciones (RPM)
	if rpm_source != null and revoluciones != null:
		var rpm_value: float = -1.0
		var cfg = null
		var have_actual = rpm_source.get("rpm_actual") if rpm_source.has_method("get") else null
		if have_actual != null:
			rpm_value = float(have_actual)
		elif rpm_source.has_method("get_rpm_norm"):
			var rpm_norm = float(rpm_source.call("get_rpm_norm"))
			cfg = rpm_source.get("config") if rpm_source.has_method("get") else null
			if cfg != null and cfg.has_method("get"):
				var rpm_min_cfg = cfg.get("rpm_minimas") if cfg.get("rpm_minimas") != null else cfg.get("rpm_idle")
				var rpm_max_cfg = cfg.get("rpm_maximas") if cfg.get("rpm_maximas") != null else cfg.get("rpm_maximas")
				if rpm_min_cfg != null and rpm_max_cfg != null:
					rpm_value = float(rpm_min_cfg) + rpm_norm * float(rpm_max_cfg - rpm_min_cfg)
				else:
					rpm_value = rpm_norm * 8000.0
			else:
				rpm_value = rpm_norm * 8000.0
		if rpm_value >= 0.0:
			var mat_r = null
			if revoluciones.has_method("get"):
				mat_r = revoluciones.get("material")
			if mat_r and mat_r.has_method("set_shader_parameter"):
				mat_r.set_shader_parameter("rpm", rpm_value)
				if cfg != null and cfg.rpm_maximas != null:
					mat_r.set_shader_parameter("max_rpm", float(cfg.rpm_maximas))

	# Actualizar barra de gasolina (value 0.0..1.0)
	if gas_bar != null and gas_bar.has_method("get"):
		var mat_g = gas_bar.get("material")
		if mat_g and mat_g.has_method("set_shader_parameter"):
			var fuel_norm: float = 0.0
			# Intentar leer desde el Motor del vehículo
			var nivel = null
			var capacidad = null
			if vehicle != null:
				var m = vehicle.get_node_or_null("Motor")
				if not m:
					m = _search_node_by_name(vehicle, "Motor")
				if m != null and m.has_method("get"):
					nivel = m.get("nivel_combustible_l")
					capacidad = m.get("capacidad_combustible_l")
				# Fallback: leer desde la configuración del vehículo
				if (nivel == null or capacidad == null) and vehicle.has_method("get"):
					var cfgf = vehicle.get("config") if vehicle.has_method("get") else null
					if cfgf != null:
						if nivel == null and cfgf.has_method("get"):
							nivel = cfgf.get("nivel_combustible_l")
						elif nivel == null:
							nivel = cfgf.nivel_combustible_l
						if capacidad == null and cfgf.has_method("get"):
							capacidad = cfgf.get("capacidad_combustible_l")
						elif capacidad == null:
							capacidad = cfgf.capacidad_combustible_l
				# Calcular normalizado
				if capacidad != null and capacidad > 0 and nivel != null:
					fuel_norm = clamp(float(nivel) / float(capacidad), 0.0, 1.0)
			mat_g.set_shader_parameter("value", fuel_norm)

func _update_label_from_raw(raw_speed: float) -> void:
	var display = raw_speed
	if speed_in_m_s:
		display = display * 3.6
	var factor = pow(10, max(0, decimals))
	var rounded = round(display * factor) / factor
	if label_velocidad:
		if decimals > 0:
			label_velocidad.text = str(rounded)
		else:
			label_velocidad.text = str(int(round(rounded)))
	if label_unit:
		label_unit.text = unit

	# Actualizar velocimetro (usar display en km/h si corresponde)
	_update_speedometer(display)

func set_speed(value: float) -> void:
	# Método público para que otro script le pase la velocidad directamente (en m/s si speed_in_m_s=true)
	_update_label_from_raw(value)

func _get_vehicle_speed(node: Node) -> float:
	# Devuelve la velocidad en la unidad que usa el vehículo (por convención m/s). Retorna -1 si no pudo obtenerla.
	if node == null:
		return -1.0
	if node.has_method("get_speed"):
		return float(node.call("get_speed"))
	var s = node.get("speed")
	if s != null:
		return float(s)
	var lv = node.get("linear_velocity")
	if lv != null:
		if typeof(lv) == TYPE_VECTOR2 or typeof(lv) == TYPE_VECTOR3:
			return lv.length()
	var v = node.get("velocity")
	if v != null:
		if typeof(v) == TYPE_VECTOR2 or typeof(v) == TYPE_VECTOR3:
			return v.length()
	return -1.0

func _update_speedometer(value: float) -> void:
	if not velocimetro:
		return
	var mat = null
	if velocimetro.has_method("get"):
		mat = velocimetro.get("material")
	if mat and mat.has_method("set_shader_parameter"):
		var v = clamp(value, 0.0, max(0.0, speedometer_max))
		mat.set_shader_parameter("rpm", v)
		mat.set_shader_parameter("max_rpm", speedometer_max)

func _find_selector_marchas_node() -> Node:
	var root = get_tree().get_root()
	return _search_node_by_name(root, "SelectorMarchas")

func _ensure_rpm_source() -> void:
	# Localiza el nodo ControladorRPM dentro del vehículo o en la escena
	if rpm_source and is_instance_valid(rpm_source):
		return
	if vehicle:
		rpm_source = _search_node_by_name(vehicle, "ControladorRPM")
	if rpm_source == null:
		rpm_source = _search_node_by_name(get_tree().get_root(), "ControladorRPM")
	# Si encontramos la fuente y el nodo revoluciones, sincronizamos max_rpm desde la config
	if rpm_source != null and revoluciones != null:
		var cfg = rpm_source.get("config") if rpm_source.has_method("get") else null
		if cfg != null:
			var rpm_max_cfg = null
			if cfg.has_method("get"):
				var tmp = cfg.get("rpm_maximas")
				if tmp != null:
					rpm_max_cfg = tmp
				else:
					tmp = cfg.get("rpm_max")
					if tmp != null:
						rpm_max_cfg = tmp
			# Si encontramos un valor válido, actualizar el shader
			if rpm_max_cfg != null:
				var mat_r = null
				if revoluciones.has_method("get"):
					mat_r = revoluciones.get("material")
				if mat_r and mat_r.has_method("set_shader_parameter"):
					mat_r.set_shader_parameter("max_rpm", float(rpm_max_cfg))

func _ensure_vehicle_direccionales() -> void:
	# Localiza el nodo Direccionales dentro del vehículo o en la escena
	if vehicle_direccionales and is_instance_valid(vehicle_direccionales):
		return
	if vehicle:
		vehicle_direccionales = _search_node_by_name(vehicle, "Direccionales")
	if vehicle_direccionales == null:
		vehicle_direccionales = _search_node_by_name(get_tree().get_root(), "Direccionales")

func _search_node_by_name(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child == self:
			continue
		if child.name == target_name:
			return child
		var found = _search_node_by_name(child, target_name)
		if found:
			return found
	return null

func _on_selector_marcha_cambiada(marcha: String) -> void:
	if gear_label:
		gear_label.text = marcha

func _auto_find_vehicle() -> Node:
	var root = get_tree().get_root()
	return _search_node_for_speed(root)

func _get_vehicle_gear(node: Node) -> String:
	if node == null:
		return ""
	var val = null
	if node.has_method("get_gear"):
		val = node.call("get_gear")
	elif node.has_method("get_gear_state"):
		val = node.call("get_gear_state")
	else:
		var keys = ["gear", "current_gear", "gear_position", "gear_state", "transmission", "gearbox", "drive_mode", "state"]
		for k in keys:
			if node.has_method(k):
				val = node.call(k)
				break
			var v = node.get(k)
			if v != null:
				val = v
				break

	if val == null:
		return ""

	var t = typeof(val)
	if t == TYPE_STRING:
		var s = str(val).strip_edges().to_upper()
		if s.begins_with("P") or s.find("PARK") != -1:
			return "P"
		if s.begins_with("R") or s.find("REVERSE") != -1:
			return "R"
		if s.begins_with("N") or s.find("NEUTRAL") != -1:
			return "N"
		if s.begins_with("D") or s.find("DRIVE") != -1:
			return "D"
		return s
	elif t == TYPE_INT or t == TYPE_FLOAT:
		var n = int(val)
		if n < 0:
			return "R"
		if n == 0:
			return "N"
		# If vehicle exposes an automatic flag, prefer D for >=1
		var is_auto = false
		var ia = node.get("is_automatic")
		if ia != null and ia == true:
			is_auto = true
		var ia2 = node.get("automatic")
		if ia2 != null and ia2 == true:
			is_auto = true
		if is_auto:
			return "D"
		return str(n)
	else:
		return str(val)

func _get_steering_norm() -> float:
	# Intenta obtener un valor normalizado de dirección (-1..1) desde varias fuentes
	# 1) Propiedades/métodos del vehículo
	if vehicle and is_instance_valid(vehicle):
		var v = vehicle.get("input_steer")
		if v != null:
			return _to_float_safe(v)
		var keys = ["input_steer", "steering_input", "steer_input", "steer", "steering", "steering_angle"]
		for k in keys:
			var val = vehicle.get(k)
			if val != null:
				return _to_float_safe(val)
		var methods = ["get_steer", "get_steering_input", "get_input_steer", "get_direccion_normalizada", "get_direction_normalized"]
		for m in methods:
			if vehicle.has_method(m):
				var ret = vehicle.call(m)
				if ret != null:
					return _to_float_safe(ret)

	# 2) Nodo Volante en la UI (si existe)
	var volante = _search_node_by_name(get_tree().get_root(), "Volante")
	if volante != null:
		if volante.has_method("_obtener_input_desde_controlador"):
			var v2 = volante.call("_obtener_input_desde_controlador")
			if v2 != null:
				return _to_float_safe(v2)
		var rv = volante.get("rotacion_actual")
		if rv != null:
			return _to_float_safe(rv)
		var possible = ["rotacion_actual", "rotation_value", "angle", "rotation", "steer", "input_steer"]
		for p in possible:
			var pv = volante.get(p)
			if pv != null:
				return _to_float_safe(pv)

	# 3) Controlador de llantas/directrices
	var ctrl = _search_node_by_name(get_tree().get_root(), "ControladorLlantas")
	if ctrl != null and ctrl.has_method("get_direccion_normalizada"):
		var ctrlv = ctrl.call("get_direccion_normalizada")
		if ctrlv != null:
			return _to_float_safe(ctrlv)

	# 4) Fallback: input global (convención: ui_right = +, ui_left = -)
	return Input.get_axis("ui_right", "ui_left")

func _to_float_safe(val) -> float:
	# Convierte variantes comunes a float de forma segura sin asumir la existencia
	# del constructor `float()` (puede no estar disponible en algunas versiones).
	if val == null:
		return 0.0
	var t = typeof(val)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return val + 0.0
	if t == TYPE_VECTOR2:
		return val.x + 0.0
	if t == TYPE_VECTOR3:
		return val.x + 0.0
	if t == TYPE_BOOL:
		return 1.0 if bool(val) else 0.0
	if t == TYPE_STRING:
		return str(val).to_float()
	return 0.0

func _search_node_for_speed(node: Node) -> Node:
	for child in node.get_children():
		if child == self:
			continue
		if child.has_method("get_speed"):
			return child
		if child.get("speed") != null:
			return child
		if child.get("linear_velocity") != null:
			return child
		var found = _search_node_for_speed(child)
		if found:
			return found
	return null

func _marcha_display() -> String:
	match InputVehiculo.marcha_actual:
		InputVehiculo.Marcha.REVERSA:
			return "R"
		InputVehiculo.Marcha.DRIVE:
			return "D"
		InputVehiculo.Marcha.NEUTRO:
			return "N"
		InputVehiculo.Marcha.PARQUEO:
			return "P"
	return "N"
