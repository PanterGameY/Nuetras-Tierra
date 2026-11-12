## Controlador de humo de escape para el T800.
## Todos los @export se aplican en tiempo real desde el inspector.
## Asigna "nodo_particulas" en el inspector, o añade un hijo CPUParticles3D
## llamado exactamente "CPUParticles3D" como fallback.
extends Node3D

# ═══════════════════════════════════════════════════════════════════════════════
#  NODOS
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Nodos")
## Nodo CPUParticles3D que emite el humo. Arrástralo desde la escena.
@export var nodo_particulas: CPUParticles3D

# ═══════════════════════════════════════════════════════════════════════════════
#  EMISIÓN
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Emisión")
## Partículas activas al mínimo de gas.
@export_range(1, 30) var cantidad_min: int = 6
## Partículas activas al máximo de gas.
@export_range(1, 200) var cantidad_max: int = 80
## speed_scale al mínimo de gas.
@export_range(0.05, 1.0, 0.01) var emision_min: float = 0.30
## speed_scale al máximo de gas.
@export_range(0.1, 5.0, 0.05) var emision_max: float = 2.20

# ═══════════════════════════════════════════════════════════════════════════════
#  VELOCIDAD
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Velocidad")
## Velocidad mínima de salida (m/s), con gas mínimo.
@export_range(0.1, 5.0, 0.05) var velocidad_min: float = 0.6
## Velocidad máxima de salida (m/s), con gas total.
@export_range(0.1, 10.0, 0.1) var velocidad_max: float = 3.5
## Dispersión aleatoria (0 = uniforme, 1 = muy caótico).
@export_range(0.0, 1.0, 0.01) var aleatoriedad_vel: float = 0.28

# ═══════════════════════════════════════════════════════════════════════════════
#  DIRECCIÓN
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Dirección")
## Dirección principal del penacho en espacio local. (0,1,0) = arriba.
@export var direccion: Vector3 = Vector3(0.0, 1.0, 0.0)
## Apertura del cono en grados. 0 = recto, 90 = hemisferio.
@export_range(0.0, 90.0, 0.5) var esparcimiento: float = 14.0
## Apertura extra con aceleración fuerte (simula presión del escape).
@export_range(0.0, 45.0, 0.5) var esparcimiento_extra_gas: float = 12.0

# ═══════════════════════════════════════════════════════════════════════════════
#  FÍSICA
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Física")
## Tiempo de vida de cada partícula (largo del penacho).
@export_range(0.3, 10.0, 0.1) var vida: float = 3.2
## Gravedad. Y negativo = el humo sube. Y positivo = cae.
@export var gravedad: Vector3 = Vector3(0.0, -0.10, 0.0)
## Rozamiento mínimo del aire.
@export_range(0.0, 2.0, 0.01) var amort_min: float = 0.08
## Rozamiento máximo del aire.
@export_range(0.0, 2.0, 0.01) var amort_max: float = 0.24
## Rotación mínima por partícula (grados/s).
@export_range(-180.0, 0.0, 1.0) var vel_angular_min: float = -30.0
## Rotación máxima por partícula (grados/s).
@export_range(0.0, 180.0, 1.0) var vel_angular_max: float = 30.0

# ═══════════════════════════════════════════════════════════════════════════════
#  TAMAÑO
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Tamaño")
## Escala al nacer (nube concentrada).
@export_range(0.01, 2.0, 0.01) var tamano_inicio: float = 0.12
## Escala en vida media.
@export_range(0.05, 5.0, 0.05) var tamano_medio: float = 0.40
## Escala al morir (nube dispersa).
@export_range(0.1, 8.0, 0.1) var tamano_final: float = 0.90

# ═══════════════════════════════════════════════════════════════════════════════
#  COLOR
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Color")
## Color en ralentí: gris claro, casi transparente.
@export var color_ralenti: Color     = Color(0.78, 0.78, 0.78, 0.22)
## Color al acelerar: negro opaco (diesel quemando).
@export var color_aceleracion: Color = Color(0.06, 0.06, 0.06, 0.80)
## Color intermedio (vida media de la partícula).
@export var color_medio: Color       = Color(0.45, 0.45, 0.45, 0.20)
## Color al desvanecerse (borde final).
@export var color_final: Color       = Color(0.70, 0.70, 0.70, 0.00)

# ═══════════════════════════════════════════════════════════════════════════════
#  SHADER
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Shader")
## Velocidad de la turbulencia interna. 0 = estático.
@export_range(0.0, 4.0, 0.01) var turbulencia: float = 0.55
## Escala del ruido. Alto = nubes más finas y detalladas.
@export_range(0.5, 8.0, 0.05) var escala_ruido: float = 3.2
## Retorcimiento interior (da volumen/esponjosidad).
@export_range(0.0, 0.5, 0.005) var deformacion: float = 0.18
## Dureza del borde interior (0 = difuso, 1 = núcleo sólido).
@export_range(0.0, 1.0, 0.01) var dureza_borde: float = 0.22
## Suavizado del borde exterior.
@export_range(0.05, 0.5, 0.005) var suavizado_borde: float = 0.28
## Contraste de volumen interno.
@export_range(0.0, 1.0, 0.01) var contraste_detalle: float = 0.18

# ═══════════════════════════════════════════════════════════════════════════════
#  RALENTÍ
# ═══════════════════════════════════════════════════════════════════════════════
@export_group("Ralentí")
## Partículas con motor encendido y sin gas.
@export_range(1, 20) var cantidad_ralenti: int = 4
## Velocidad de salida en ralentí (m/s).
@export_range(0.05, 3.0, 0.05) var velocidad_ralenti: float = 0.45

# ═══════════════════════════════════════════════════════════════════════════════
#  INTERNAS
# ═══════════════════════════════════════════════════════════════════════════════
var _p:        CPUParticles3D
var _mat:      ShaderMaterial
var _grad:     Gradient
var _curva:    Curve
var _last_gas: float = -1.0

const _GAS_UMBRAL := 0.025
const _COLOR_THR  := 0.035

# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_p = nodo_particulas if nodo_particulas else get_node_or_null("CPUParticles3D")
	if not _p:
		push_error("humo.gd: asigna 'nodo_particulas' en el inspector o añade un hijo CPUParticles3D")
		return

	_mat        = ShaderMaterial.new()
	_mat.shader = load("res://modelos3d/vehiculos/tractomulas/cabezotes/T800/particula_humo.gdshader")
	_p.material_override = _mat

	_grad  = Gradient.new()
	_curva = Curve.new()

	_aplicar_todos_los_exports()
	_p.emitting = false

# ─── Aplica TODOS los exports al nodo y al shader ─────────────────────────────
func _aplicar_todos_los_exports() -> void:
	if not _p or not _mat:
		return

	# Física base
	_p.lifetime             = vida
	_p.direction            = direccion.normalized()
	_p.spread               = esparcimiento
	_p.gravity              = gravedad
	_p.damping_min          = amort_min
	_p.damping_max          = amort_max
	_p.angular_velocity_min = vel_angular_min
	_p.angular_velocity_max = vel_angular_max
	_p.initial_velocity_min = maxf(0.01, velocidad_min * (1.0 - aleatoriedad_vel))
	_p.initial_velocity_max = velocidad_max * (1.0 + aleatoriedad_vel)

	# Tamaño base
	_p.scale_amount_min = tamano_inicio
	_p.scale_amount_max = tamano_medio

	# Curva de escala: nace pequeño → crece → se dispersa
	_curva.clear_points()
	_curva.add_point(Vector2(0.00, 0.05))
	_curva.add_point(Vector2(0.15, 0.30))
	_curva.add_point(Vector2(0.45, 0.72))
	_curva.add_point(Vector2(0.75, 0.95))
	_curva.add_point(Vector2(1.00, tamano_final / maxf(tamano_medio, 0.001)))
	_p.scale_amount_curve = _curva

	# Gradiente de color por ciclo de vida
	_grad.offsets = PackedFloat32Array([0.0, 0.25, 0.60, 1.0])
	_grad.colors  = PackedColorArray([
		color_ralenti,
		color_medio,
		Color(color_final.r, color_final.g, color_final.b, 0.06),
		color_final,
	])
	_p.color_ramp = _grad

	# Parámetros del shader
	_mat.set_shader_parameter("velocidad_turbulencia", turbulencia)
	_mat.set_shader_parameter("escala_ruido",          escala_ruido)
	_mat.set_shader_parameter("deformacion",           deformacion)
	_mat.set_shader_parameter("dureza_borde",          dureza_borde)
	_mat.set_shader_parameter("suavizado_borde",       suavizado_borde)
	_mat.set_shader_parameter("contraste_detalle",     contraste_detalle)

# ─── Detecta cambios desde el inspector y los aplica inmediatamente ───────────
func _set(property: StringName, _value) -> bool:
	_aplicar_todos_los_exports()
	return false  # false = Godot también guarda el valor normalmente

# ═══════════════════════════════════════════════════════════════════════════════
func _process(_delta: float) -> void:
	if not _p or not _mat:
		return

	var iv = get_node_or_null("/root/InputVehiculo") if is_inside_tree() else null
	if not is_instance_valid(iv):
		return

	var gas: float     = iv.gas
	var motor_on: bool = iv.motor_encendido

	_p.direction = direccion.normalized()

	# Motor apagado
	if not motor_on:
		_p.emitting = false
		_last_gas   = -1.0
		return

	_p.emitting = true

	# Con gas
	if gas > _GAS_UMBRAL:
		var t := gas

		_p.speed_scale = lerpf(emision_min, emision_max, t)
		_p.amount      = maxi(1, int(lerpf(float(cantidad_min), float(cantidad_max), t)))

		var vel_base := lerpf(velocidad_min, velocidad_max, t)
		_p.initial_velocity_min = maxf(0.01, vel_base * (1.0 - aleatoriedad_vel))
		_p.initial_velocity_max = vel_base * (1.0 + aleatoriedad_vel)

		# Esparcimiento crece con el gas
		_p.spread = esparcimiento + esparcimiento_extra_gas * t

		if absf(t - _last_gas) > _COLOR_THR:
			_last_gas = t
			_grad.set_color(0, color_ralenti.lerp(color_aceleracion, t))
			var alpha_medio := lerpf(color_medio.a * 0.5, color_medio.a, t)
			_grad.set_color(1, Color(color_medio.r, color_medio.g, color_medio.b, alpha_medio))

	# Ralentí
	else:
		_p.speed_scale          = emision_min
		_p.amount               = maxi(1, cantidad_ralenti)
		_p.spread               = esparcimiento
		_p.initial_velocity_min = maxf(0.01, velocidad_ralenti * (1.0 - aleatoriedad_vel))
		_p.initial_velocity_max = velocidad_ralenti * (1.0 + aleatoriedad_vel)

		if absf(_last_gas) > _COLOR_THR:
			_last_gas = 0.0
			_grad.set_color(0, color_ralenti)
			_grad.set_color(1, color_medio)

