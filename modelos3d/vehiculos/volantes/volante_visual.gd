# volante_visual.gd - Sistema de Simulación Visual de Volante de Alta Fidelidad
# Soporta: Camiones Pesados (T800, T680), Autobuses y Automóviles
# Incluye: Selección de eje en tiempo real en Inspector, prueba interactiva en editor,
# inercia hidráulica, autocentrado por velocidad (caster) y microvibración de motor diésel.
@tool
extends Node3D

enum EspacioRotacion {
	LOCAL = 0,          ## Rota sobre los ejes locales del propio volante (Recomendado)
	VEHICULO_PADRE = 1  ## Rota sobre los ejes del vehículo / padre (ej. eje Z del camión)
}

enum TipoEje {
	EJE_Z = 0,          ## Vector3(0, 0, 1) - Normal típica del disco del volante
	EJE_X = 1,          ## Vector3(1, 0, 0)
	EJE_Y = 2,          ## Vector3(0, 1, 0)
	PERSONALIZADO = 3   ## Vector definido en 'ejes_de_giro'
}

@export_group("Configuración de Eje en Inspector")
## Selecciona si el giro se aplica en el espacio LOCAL del volante o en el espacio del VEHÍCULO / PADRE
@export var espacio_eje: EspacioRotacion = EspacioRotacion.LOCAL:
	set(val):
		espacio_eje = val
		_recalcular_eje_y_actualizar()

## Selecciona directamente el eje de giro (Z, X, Y o Personalizado). Se actualiza al instante en el editor.
@export var tipo_eje: TipoEje = TipoEje.EJE_Z:
	set(val):
		tipo_eje = val
		_recalcular_eje_y_actualizar()

## Vector de rotación manual si seleccionas PERSONALIZADO (o fallback)
@export var ejes_de_giro: Vector3 = Vector3(0, 0, 1):
	set(val):
		ejes_de_giro = val
		_recalcular_eje_y_actualizar()

## Invierte el sentido del giro (horario / antihorario) para coincidir con la vista del conductor
@export var invertir_giro: bool = true:
	set(val):
		invertir_giro = val
		_recalcular_eje_y_actualizar()

## Relación de vueltas: 2.0 a 3.0 para camiones y tractomulas (múltiples vueltas completas reales)
@export var steering_wheel_ratio: float = 2.5:
	set(val):
		steering_wheel_ratio = val
		_recalcular_eje_y_actualizar()

## Suavizado de giro que simula la masa del aro y la asistencia hidráulica
@export var suavizado: float = 14.0

## Rotación máxima permitida en grados (ej. 900° = 2.5 vueltas de tope a tope)
@export var max_rotation_deg: float = 900.0

## Velocidad base de retorno hacia el centro
@export var return_speed: float = 8.0

## Zona muerta de entrada para evitar jitter o micro-desviaciones
@export var deadzone_input: float = 0.015

@export_group("Prueba en Vivo en el Editor")
## Mueve este control en el Inspector para ver girar el volante en tiempo real en la vista 3D de Godot
@export_range(-1.0, 1.0, 0.01) var probar_giro_editor: float = 0.0:
	set(val):
		probar_giro_editor = val
		rotacion_actual = val
		_actualizar_transform(0.016)

## Pulsa esta casilla para capturar la pose actual como reposo original si recolocas el volante
@export var recalibrar_pose_original: bool = false:
	set(val):
		if val:
			_pose_original_guardada = false
			_asegurar_pose_base()
			rotacion_actual = 0.0
			probar_giro_editor = 0.0
			_actualizar_transform(0.016)

@export_group("Física y Realismo de Conducción")
## Activa el retorno dinámico (Caster effect): en marcha el retorno es rápido; en parado es pesado por fricción de neumáticos.
@export var habilitar_retorno_dinamico: bool = true
## Velocidad de retorno con el vehículo detenido (resistencia de neumáticos en seco)
@export var retorno_en_parado: float = 3.5
## Velocidad de retorno a velocidad de carretera (auto-alineación ágil y firme)
@export var retorno_en_carretera: float = 16.0

@export_group("Vibración de Motor Diésel")
## Microvibración mecánica transmitida por los cilindros del motor diésel
@export var habilitar_vibracion_motor: bool = true
## Amplitud de la vibración en radianes (sutil y orgánica)
@export var intensidad_vibracion: float = 0.002
## Frecuencia de los pulsos del motor diésel (RPM de ralentí)
@export var frecuencia_vibracion: float = 24.0

@export_group("Dependencias y UI")
## RayCast3D opcional (solo si se usa una columna física externa calibrada)
@export var raycast_direccion: RayCast3D:
	set(val):
		raycast_direccion = val
		_recalcular_eje_y_actualizar()

## Nodo del volante táctil en pantalla (TextureRect con volante.gd). Se autodetecta si no está asignado.
@export var volante_ui: Node

var rotacion_actual: float = 0.0
var _pose_original_guardada: bool = false
var _transform_base: Transform3D
var _tiempo_vibracion: float = 0.0
var _nodo_vehiculo: Node = null
var _controlador_llantas: Node = null
var _ui_conectada: bool = false
var _rotacion_ui_activa: bool = false
var _rotacion_ui_valor: float = 0.0

func _ready() -> void:
	_pose_original_guardada = false
	_asegurar_pose_base()
	_buscar_dependencias()
	_actualizar_transform(0.016)

func _asegurar_pose_base() -> void:
	if not _pose_original_guardada:
		_transform_base = self.transform
		_pose_original_guardada = true

func _obtener_vector_eje_activo() -> Vector3:
	# Si hay un RayCast calibrado explícito:
	if is_instance_valid(raycast_direccion):
		var target_custom := (raycast_direccion.target_position != Vector3.DOWN and raycast_direccion.target_position != Vector3.ZERO)
		var no_es_hijo_default := (raycast_direccion.get_parent() != self or raycast_direccion.rotation != Vector3.ZERO or target_custom)
		if target_custom or no_es_hijo_default:
			var ray_dir := raycast_direccion.target_position.normalized() if raycast_direccion.target_position != Vector3.ZERO else Vector3.DOWN
			return ray_dir

	match tipo_eje:
		TipoEje.EJE_Z:
			return Vector3(0, 0, 1)
		TipoEje.EJE_X:
			return Vector3(1, 0, 0)
		TipoEje.EJE_Y:
			return Vector3(0, 1, 0)
		TipoEje.PERSONALIZADO:
			return ejes_de_giro if ejes_de_giro != Vector3.ZERO else Vector3(0, 0, 1)
	return Vector3(0, 0, 1)

func _recalcular_eje_y_actualizar() -> void:
	_asegurar_pose_base()
	_actualizar_transform(0.016)

func _buscar_dependencias() -> void:
	if not is_instance_valid(_nodo_vehiculo):
		var curr: Node = get_parent()
		while curr:
			if curr.is_in_group("vehiculo") or curr is RigidBody3D:
				_nodo_vehiculo = curr
				break
			curr = curr.get_parent()

	if not is_instance_valid(_controlador_llantas) and is_instance_valid(_nodo_vehiculo):
		_controlador_llantas = _nodo_vehiculo.get_node_or_null("ControladorLlantas")
		if not _controlador_llantas:
			_controlador_llantas = _nodo_vehiculo.find_child("ControladorLlantas", true, false)

	if not _ui_conectada:
		if not is_instance_valid(volante_ui) and is_instance_valid(_nodo_vehiculo):
			var ui_v = _nodo_vehiculo.get("ui_vehiculo")
			if is_instance_valid(ui_v):
				volante_ui = ui_v.find_child("Volante", true, false)
			if not is_instance_valid(volante_ui):
				volante_ui = _nodo_vehiculo.find_child("volante", true, false)

		if is_instance_valid(volante_ui) and volante_ui.has_signal("rotacion_cambiada"):
			if not volante_ui.rotacion_cambiada.is_connected(_on_rotacion_ui_cambiada):
				volante_ui.rotacion_cambiada.connect(_on_rotacion_ui_cambiada)
			_ui_conectada = true

func _on_rotacion_ui_cambiada(valor: float) -> void:
	_rotacion_ui_activa = true
	_rotacion_ui_valor = valor

func _process(delta: float) -> void:
	# En el editor de Godot no procesar lógica de juego para no interferir con la edición
	if Engine.is_editor_hint():
		return

	if not _ui_conectada or not is_instance_valid(_nodo_vehiculo):
		_buscar_dependencias()

	var target_input := _obtener_input_giro()

	if invertir_giro:
		target_input *= -1.0

	var dz: float = float(deadzone_input)
	if absf(target_input) < dz:
		target_input = 0.0

	if absf(target_input) > 0.001:
		rotacion_actual = lerp(rotacion_actual, target_input, clampf(suavizado * delta, 0.0, 1.0))
	else:
		var speed_retorno := return_speed
		if habilitar_retorno_dinamico:
			var vel_kmh := _obtener_velocidad_kmh()
			speed_retorno = lerpf(retorno_en_parado, retorno_en_carretera, clampf(vel_kmh / 35.0, 0.0, 1.0))

		if absf(rotacion_actual) > 0.001:
			rotacion_actual = move_toward(rotacion_actual, 0.0, speed_retorno * delta)
		else:
			rotacion_actual = 0.0

	_actualizar_transform(delta)

func _obtener_input_giro() -> float:
	# 1. Volante UI táctil directo
	if _rotacion_ui_activa:
		if is_instance_valid(volante_ui) and "tocando" in volante_ui and not volante_ui.tocando:
			_rotacion_ui_activa = false
		else:
			return _rotacion_ui_valor

	if is_instance_valid(volante_ui) and "rotacion_actual" in volante_ui:
		var r_ui = float(volante_ui.rotacion_actual)
		if absf(r_ui) > 0.005:
			return r_ui

	# 2. Singleton global InputVehiculo (conecta teclado, joystick, móvil)
	var iv = get_node_or_null("/root/InputVehiculo")
	if is_instance_valid(iv) and "direccion" in iv:
		var dir_iv = float(iv.direccion)
		if absf(dir_iv) > 0.005:
			return dir_iv

	# 3. Controlador de Llantas y ruedas directrices físicas
	if is_instance_valid(_controlador_llantas):
		if _controlador_llantas.has_method("get_direccion_normalizada"):
			var norm = float(_controlador_llantas.get_direccion_normalizada())
			if absf(norm) > 0.005:
				return norm
		if "llantas_directrices" in _controlador_llantas:
			var wheels: Array = _controlador_llantas.llantas_directrices
			if wheels.size() > 0:
				var sum_angle := 0.0
				var count := 0
				for l in wheels:
					if is_instance_valid(l):
						if "angulo_direccion" in l:
							sum_angle += float(l.angulo_direccion)
							count += 1
						elif "_angulo_actual" in l:
							sum_angle += float(l.get("_angulo_actual"))
							count += 1
				if count > 0:
					var ang_max: float = float(_controlador_llantas.get("angulo_max_giro")) if "angulo_max_giro" in _controlador_llantas else 0.61
					return clampf(-sum_angle / (float(count) * maxf(ang_max, 0.001)), -1.0, 1.0)

	# 4. Fallback de entrada de teclado / joystick directo (funciona siempre al probar escenas con F6)
	var in_left_right := Input.get_axis("ui_left", "ui_right")
	if absf(in_left_right) > 0.02:
		return in_left_right

	var in_izq_der := Input.get_axis("izquierda", "derecha")
	if absf(in_izq_der) > 0.02:
		return in_izq_der

	return 0.0

func _obtener_velocidad_kmh() -> float:
	if is_instance_valid(_nodo_vehiculo) and _nodo_vehiculo is RigidBody3D:
		return float(_nodo_vehiculo.linear_velocity.length() * 3.6)
	if not is_inside_tree():
		return 0.0
	var iv = get_node_or_null("/root/InputVehiculo")
	if is_instance_valid(iv) and "velocidad_actual_kmh" in iv:
		return float(iv.velocidad_actual_kmh)
	return 0.0

func _vehiculo_encendido() -> bool:
	if not is_inside_tree():
		return false
	var iv = get_node_or_null("/root/InputVehiculo")
	if is_instance_valid(iv) and "motor_encendido" in iv:
		return bool(iv.motor_encendido)
	if is_instance_valid(_nodo_vehiculo) and "activo" in _nodo_vehiculo:
		return bool(_nodo_vehiculo.activo)
	return true

func _actualizar_transform(delta: float) -> void:
	_asegurar_pose_base()

	var angulo_final_rad: float = rotacion_actual * PI * steering_wheel_ratio
	var max_rad: float = deg_to_rad(max_rotation_deg)
	angulo_final_rad = clampf(angulo_final_rad, -max_rad, max_rad)

	# Microvibración orgánica diésel
	var vibracion: float = 0.0
	if not Engine.is_editor_hint() and habilitar_vibracion_motor and _vehiculo_encendido():
		_tiempo_vibracion += delta * frecuencia_vibracion
		var vel_kmh := _obtener_velocidad_kmh()
		var factor_rumble := clampf(1.0 - (vel_kmh / 70.0) * 0.5, 0.4, 1.0)
		var onda1 := sin(_tiempo_vibracion)
		var onda2 := sin(_tiempo_vibracion * 2.37) * 0.4
		vibracion = (onda1 + onda2) * intensidad_vibracion * factor_rumble

	var eje_dir := _obtener_vector_eje_activo().normalized()
	var angulo_total := angulo_final_rad + vibracion

	if espacio_eje == EspacioRotacion.LOCAL:
		# Rotación directa en el espacio local del volante
		var q_rot := Quaternion(eje_dir, angulo_total)
		self.transform.basis = _transform_base.basis * Basis(q_rot)
	else:
		# Rotación en el espacio del vehículo / padre
		var q_rot := Quaternion(eje_dir, angulo_total)
		self.transform.basis = Basis(q_rot) * _transform_base.basis

	self.transform.origin = _transform_base.origin

func _on_tween_retorno_step(v: float) -> void:
	rotacion_actual = v
	_actualizar_transform(0.016)

func retorno_automatico() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_method(_on_tween_retorno_step, rotacion_actual, 0.0, 0.45)
