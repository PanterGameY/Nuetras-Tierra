@tool
extends Camera3D

# Camera orbital para el main menu.
# Coloca `target_path` al nodo a rodear (por ejemplo un `Node3D` llamado "CameraTarget").

## Nodo objetivo a rodear; si está vacío intenta buscar "CameraTarget" en la escena
@export var target_path: NodePath = NodePath("")
## Radio de la órbita (distancia al objetivo)
@export var radius: float = 10.0
## Altura (offset vertical) de la cámara respecto al origen del objetivo
@export var height_offset: float = 2.0
## Altura del punto al que mira la cámara (relativa al objetivo)
@export var look_at_height: float = 1.5
## Velocidad de rotación (grados por segundo)
@export var rotation_speed_deg: float = 10.0
## Ángulo inicial de la órbita (grados)
@export var initial_angle_deg: float = 0.0
## Suavizado del movimiento de la cámara (mayor = más rápido; 0 = sin suavizado)
@export var smooth_speed: float = 5.0
## Si true la cámara rota automáticamente
@export var auto_rotate: bool = true
## Gira en sentido horario cuando es true
@export var orbit_clockwise: bool = false
## Si true la cámara mira al objetivo (look_at)
@export var look_at_target: bool = true

## --- Movimiento dinámico: opciones para darle una firma única a la cámara ---
## Activar variaciones orgánicas (ruido, bob, cambios de radio)
@export var enable_dynamic: bool = true
## Amplitud de variación del radio (metros)
@export var radius_variation_amplitude: float = 1.0
## Velocidad de la variación del radio (escala del ángulo)
@export var radius_variation_speed: float = 1.0
## Amplitud de la variación de altura (metros)
@export var height_variation_amplitude: float = 0.6
## Velocidad de la variación de altura
@export var height_variation_speed: float = 0.5
## Movimiento de 'bobbing' vertical (simula flotación)
@export var bob_amplitude: float = 0.15
@export var bob_speed: float = 1.6
## Excentricidad de la órbita (1.0 = círculo)
@export var eccentricity_x: float = 1.0
@export var eccentricity_z: float = 0.9
## Fuerza del ruido (OpenSimplex)
@export var noise_strength: float = 0.35
## Semilla para el ruido (0 = aleatorio si `randomize_seed` true)
@export var noise_seed: int = 0
@export var randomize_seed: bool = true
@export var noise_octaves: int = 3
@export var noise_period: float = 10.0
@export var noise_persistence: float = 0.7

## Alejamiento cuando la cámara pasa por la parte frontal (-Z) del objetivo
@export var front_backoff_enabled: bool = true
@export var front_backoff_amount: float = 2.0
@export var front_backoff_smooth: float = 6.0

## Suavizado de la mirada (look_at)
@export var look_at_lerp_speed: float = 6.0

## --- Control Manual Interactivo ---
## Sensibilidad del arrastre
@export var drag_sensitivity: float = 0.2
## Si el auto_rotate se pausa al arrastrar
@export var pause_auto_rotate_on_drag: bool = true
## Tiempo que espera para reanudar auto_rotate tras soltar (segundos)
@export var resume_delay: float = 3.0

## Eventos: ráfagas/swoops (pequeñas explosiones de movimiento)
@export var enable_swoops: bool = true
@export var swoop_chance_per_minute: float = 0.2
@export var swoop_duration: float = 1.2
@export var swoop_radius_mult: float = 1.6

var _target: Node3D = null
var _angle_rad: float = 0.0
var _noise_layers: Array = []
var _noise_total_amp: float = 1.0
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_look_pos: Vector3 = Vector3.ZERO
var _swoop_timer: float = 0.0
var _swoop_active: bool = false
var _swoop_mul: float = 1.0
var _current_effective_radius: float = 0.0

var _resume_timer: float = 0.0
var _is_dragging: bool = false

func _ready() -> void:
	# Asegurarnos de que el modo de procesamiento de input sea correcto si se usara unhandled
	# set_process_unhandled_input(true)
	
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		var scene = get_tree().get_current_scene()
		if scene:
			_target = scene.get_node_or_null("CameraTarget") as Node3D

	_angle_rad = deg_to_rad(initial_angle_deg)

	# Inicializar ruido y RNG
	if randomize_seed:
		_rng.randomize()
	else:
		_rng.seed = noise_seed

	# Construir capas de ruido simples (sum of sines) para evitar dependencias de API
	_noise_layers.clear()
	var total_amp: float = 0.0
	var period = max(noise_period, 0.0001)
	var base_freq = 1.0 / period
	var octaves = max(1, noise_octaves)
	for i in range(octaves):
		var freq = base_freq * pow(2.0, i) * max(radius_variation_speed, 0.0001)
		var amp = pow(noise_persistence, i) * noise_strength
		var phase_t = _rng.randf() * TAU
		var phase_a = _rng.randf() * TAU
		_noise_layers.append({"freq": freq, "amp": amp, "phase_t": phase_t, "phase_a": phase_a})
		total_amp += amp

	_noise_total_amp = total_amp if total_amp > 0.0 else 1.0

	# Inicial radius smoothing value
	_current_effective_radius = radius

	if _target and look_at_target:
		var look_pos = _target.global_transform.origin + Vector3(0.0, look_at_height, 0.0)
		_current_look_pos = look_pos
		look_at(_current_look_pos, Vector3.UP)


func _sample_noise_2d(x: float, y: float) -> float:
	# Generador de ruido simple compuesto por capas de senos (retorna -1..1 aprox)
	if _noise_layers.is_empty():
		return 0.0
	var s: float = 0.0
	for layer in _noise_layers:
		s += layer["amp"] * sin(layer["freq"] * x + layer["phase_t"]) * cos(layer["freq"] * y + layer["phase_a"])
	return s / _noise_total_amp

func _process(delta: float) -> void:
	if _target == null:
		return

	_t += delta
	
	# Gestionar timers de control manual
	if _resume_timer > 0:
		_resume_timer -= delta

	var dir = -1.0 if orbit_clockwise else 1.0

	# Ruido y modulación
	var noise_val: float = _sample_noise_2d(_t * 0.3, _angle_rad * 0.2) if enable_dynamic else 0.0

	# Rotación principal (con modulación suave)
	if auto_rotate and _resume_timer <= 0:
		var speed_mod = 1.0
		if enable_dynamic:
			speed_mod += noise_val * 0.15
		_angle_rad += dir * deg_to_rad(rotation_speed_deg) * delta * speed_mod

	var target_pos: Vector3 = _target.global_transform.origin

	# Swoop aleatorio
	if enable_swoops and not _swoop_active:
		var chance_per_sec = swoop_chance_per_minute / 60.0
		if _rng.randf() < chance_per_sec * delta:
			_swoop_active = true
			_swoop_timer = swoop_duration
			_swoop_mul = 1.0 + _rng.randf() * (swoop_radius_mult - 1.0)
	if _swoop_active:
		_swoop_timer -= delta
		if _swoop_timer <= 0.0:
			_swoop_active = false

	# Radio dinámico
	var radius_mod: float = 0.0
	if enable_dynamic:
		radius_mod = sin(_angle_rad * radius_variation_speed + _t * 0.6) * radius_variation_amplitude + noise_val * noise_strength
	var radius_scale: float = _swoop_mul if _swoop_active else 1.0
	var base_effective_radius: float = max(0.1, (radius + radius_mod) * radius_scale)

	# Ajuste para alejarse cuando la cámara pasa por la parte frontal (-Z) del objetivo
	var target_effective_radius: float = base_effective_radius
	if front_backoff_enabled:
		var front_factor: float = max(0.0, -sin(_angle_rad))
		target_effective_radius += front_backoff_amount * front_factor

	# Suavizado del radio actual hacia el target
	var radius_smooth_t: float = 1.0
	if front_backoff_smooth > 0.0:
		radius_smooth_t = clamp(front_backoff_smooth * delta, 0.0, 1.0)
	# Interpolación numérica segura (evita errores de tipo con la función global lerp)
	if typeof(_current_effective_radius) in [TYPE_FLOAT, TYPE_INT]:
		_current_effective_radius = float(_current_effective_radius) * (1.0 - radius_smooth_t) + float(target_effective_radius) * radius_smooth_t
	else:
		_current_effective_radius = float(target_effective_radius)
	var effective_radius: float = _current_effective_radius

	# Posición elíptica / excéntrica
	var px: float = cos(_angle_rad) * effective_radius * eccentricity_x
	var pz: float = sin(_angle_rad) * effective_radius * eccentricity_z
	var desired_pos: Vector3 = target_pos + Vector3(px, 0.0, pz)

	# Altura: offset base + bobbing + variaciones + ruido
	var height_noise: float = _sample_noise_2d(_t * height_variation_speed, _angle_rad * 0.12) if enable_dynamic else 0.0
	desired_pos.y = height_offset
	if enable_dynamic:
		desired_pos.y += sin(_t * bob_speed) * bob_amplitude
		desired_pos.y += sin(_angle_rad * height_variation_speed) * height_variation_amplitude
		desired_pos.y += height_noise * noise_strength

	# Interpolación suave de posición
	var current_pos: Vector3 = global_transform.origin
	var t_smooth: float = 1.0
	if smooth_speed > 0.0:
		t_smooth = clamp(smooth_speed * delta, 0.0, 1.0)

	var new_pos: Vector3 = current_pos.lerp(desired_pos, t_smooth)
	var gt = global_transform
	gt.origin = new_pos
	global_transform = gt

	# Look-at suavizado (el punto de mira también puede variar con ruido)
	if look_at_target:
		var desired_look: Vector3 = target_pos + Vector3(0.0, look_at_height, 0.0)
		if enable_dynamic:
			desired_look.y += _sample_noise_2d(_t * 0.6, _angle_rad * 0.08) * (noise_strength * 0.35)
		var look_t: float = clamp(look_at_lerp_speed * delta, 0.0, 1.0)
		if _current_look_pos == null:
			_current_look_pos = desired_look
		else:
			_current_look_pos = _current_look_pos.lerp(desired_look, look_t)
		look_at(_current_look_pos, Vector3.UP)

## Método público para rotar la cámara desde el exterior (UI/Input)
func rotate_from_input(relative_x: float) -> void:
	_angle_rad -= relative_x * (drag_sensitivity * 0.01)
	if pause_auto_rotate_on_drag:
		_resume_timer = resume_delay
