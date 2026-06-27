# Visual de volante: Versión con RayCast e integración de jerarquía dinámica.
@tool
extends Node3D

@export_group("Configuración de Giro")
@export var ejes_de_giro: Vector3 = Vector3(0, 1, 0)
@export var steering_wheel_ratio: float = 4.0
@export var suavizado: float = 12.0
@export var invertir_giro: bool = false
@export var max_rotation_deg: float = 720.0
@export var return_speed: float = 12.0 # Velocidad (en unidades normalizadas por segundo) al volver al centro
@export var deadzone_input: float = 0.02 # Umbral para considerar que no hay input y empezar la devolución

@export_group("Dependencias")
## RayCast que influye en el cálculo del giro (opcional)
@export var raycast_direccion: RayCast3D

@export_group("Sincronización UI")
## Asigna aquí el nodo Volante (volante.gd / TextureRect) del UIVehiculo.
## Cuando está conectado, la rotación se aplica en el mismo ciclo de input → latencia ~0 ms.
@export var volante_ui: Node

var rotacion_actual: float = 0.0
var transform_original: Transform3D

func _ready() -> void:
	# Importante: Guardamos el transform relativo al padre actual
	transform_original = self.transform

	if ejes_de_giro == Vector3.ZERO:
		ejes_de_giro = Vector3.UP

	# Conectar señal directa del volante UI para latencia cero
	if is_instance_valid(volante_ui) and volante_ui.has_signal("rotacion_cambiada"):
		if not volante_ui.rotacion_cambiada.is_connected(_on_rotacion_ui_cambiada):
			volante_ui.rotacion_cambiada.connect(_on_rotacion_ui_cambiada)

## Callback síncrono: se ejecuta en el mismo ciclo de input, antes del siguiente _process.
func _on_rotacion_ui_cambiada(valor: float) -> void:
	var v := valor * (-1.0 if invertir_giro else 1.0)
	rotacion_actual = v
	_actualizar_transform()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# ── MODO UI DIRECTO ────────────────────────────────────────────────────────
	# Cuando volante_ui está asignado, toda la rotación llega por la señal
	# rotacion_cambiada (síncrona). _on_rotacion_ui_cambiada() ya llama
	# _actualizar_transform(), así que aquí no hacemos nada.
	# El retorno al centro también viaja por la señal (volante.gd lo anima
	# en su propio _process mediante move_toward → setter → emit).
	if is_instance_valid(volante_ui):
		return

	# ── MODO FALLBACK (sin UI / vehículo autónomo) ─────────────────────────────
	var target_input: float = _obtener_input_desde_controlador()

	if invertir_giro:
		target_input *= -1.0

	var dz: float = float(deadzone_input)
	if abs(target_input) < dz:
		target_input = 0.0

	if abs(target_input) > 0.0001:
		rotacion_actual = lerp(rotacion_actual, target_input, clamp(suavizado * delta, 0.0, 1.0))
	else:
		# Retorno suave (decay exponencial): nunca produce salto brusco al centro
		if abs(rotacion_actual) > 0.001:
			rotacion_actual = lerp(rotacion_actual, 0.0, clamp(return_speed * delta, 0.0, 1.0))
		else:
			rotacion_actual = 0.0

	_actualizar_transform()

func _obtener_input_desde_controlador() -> float:
	# Buscamos el controlador subiendo por la jerarquía de padres (muy útil para modelos anidados)
	var controlador = null
	var curr: Node = self
	while curr != null:
		controlador = curr.get_node_or_null("ControladorLlantas")
		if controlador:
			break
		controlador = curr.find_child("ControladorLlantas", true, false)
		if controlador:
			break
		curr = curr.get_parent()
	
	# Caso A: El controlador tiene un método directo
	if controlador and controlador.has_method("get_direccion_normalizada"):
		return float(controlador.get_direccion_normalizada())
	
	# Caso B: Acceso por llantas directrices
	if controlador and "llantas_directrices" in controlador:
		var wheels = controlador.llantas_directrices
		if wheels.size() > 0:
			var sum_angle: float = 0.0
			for l in wheels:
				if is_instance_valid(l) and "angulo_direccion" in l:
					sum_angle += float(l.angulo_direccion)
			
			var ang_max = controlador.get("angulo_max_giro") if "angulo_max_giro" in controlador else 0.55
			return clamp((sum_angle / wheels.size()) / (ang_max if ang_max != 0 else 0.001), -1.0, 1.0)

	# Caso C: Fallback a Input de dirección si es controlado por el jugador directamente
	return Input.get_axis("ui_left", "ui_right")

func _actualizar_transform() -> void:
	# 3. Cálculo de rotación final
	var angulo_final_rad: float = rotacion_actual * PI * steering_wheel_ratio
	var max_rad: float = deg_to_rad(max_rotation_deg)
	angulo_final_rad = clamp(angulo_final_rad, -max_rad, max_rad)

	# 4. APLICACIÓN DE TRANSFORM PROFESIONAL
	# Usamos el transform_original como base y aplicamos la rotación sobre su propio eje local.
	# Esto respeta la posición y escala que le diste en el editor.
	var eje_normalizado = ejes_de_giro.normalized()
	
	# Creamos una base rotada pura
	var basis_rotada = Basis(eje_normalizado, angulo_final_rad)
	
	# Aplicamos al transform: Posición original + (Rotación original * Rotación nueva)
	self.transform.basis = transform_original.basis * basis_rotada

## Retorna suavemente al centro con animación SINE/EASE_OUT (nunca brusco).
func retorno_automatico() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	var inicio := rotacion_actual
	t.tween_method(
		func(v: float) -> void:
			rotacion_actual = v
			_actualizar_transform(),
		inicio, 0.0, 0.45
	)
