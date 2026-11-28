extends Node3D
class_name HumoEscapePesado

## HumoEscapePesado.gd
## Emisor dual de humo diésel para los escapes verticales de tractomulas (T800).
## Se integra automáticamente con motor_pesado.gd usando los Marker3D de Exostos.

const RUTA_SHADER_HUMO := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800/particula_humo.gdshader"

var marker_escape: Node3D = null
var marker_escape_der: Node3D = null
var humo_habilitado: bool = true
var escape_doble: bool = true
var separacion_escapes: float = 1.6
var offset_escape: Vector3 = Vector3(0.0, 2.85, -1.95)
var color_nucleo: Color = Color(0.10, 0.10, 0.12, 0.85)
var color_borde: Color = Color(0.22, 0.23, 0.25, 0.65)

var _coche: Node3D = null
var _emisor_izq: CPUParticles3D = null
var _emisor_der: CPUParticles3D = null
var _intensidad_suave: float = 0.0
var _bocanada: float = 0.0
var _inicializado: bool = false


func set_coche(c: Node3D) -> void:
	_coche = c


func _asegurar_emisores() -> void:
	if _inicializado:
		return
	_inicializado = true
	_emisor_izq = _crear_emisor("HumoEscapeIzq")
	add_child(_emisor_izq)
	if escape_doble:
		_emisor_der = _crear_emisor("HumoEscapeDer")
		add_child(_emisor_der)


func _crear_emisor(nombre: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nombre
	p.emitting = false
	p.amount = 52
	p.lifetime = 2.4
	p.lifetime_randomness = 0.38
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.03
	p.direction = Vector3(0.0, 1.0, 0.12)
	p.spread = 10.0
	p.gravity = Vector3(0.0, 0.85, 0.0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.1
	p.damping_min = 1.8
	p.damping_max = 2.9
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -55.0
	p.angular_velocity_max = 55.0

	var curve_scale := Curve.new()
	curve_scale.add_point(Vector2(0.0, 0.18))
	curve_scale.add_point(Vector2(0.20, 0.72))
	curve_scale.add_point(Vector2(0.58, 1.65))
	curve_scale.add_point(Vector2(1.0, 2.85))
	p.scale_amount_curve = curve_scale

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	grad.add_point(0.10, Color(1.0, 1.0, 1.0, 0.56))
	grad.add_point(0.45, Color(1.0, 1.0, 1.0, 0.28))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = grad

	var quad := QuadMesh.new()
	quad.size = Vector2(0.72, 0.72)
	if ResourceLoader.exists(RUTA_SHADER_HUMO):
		var mat := ShaderMaterial.new()
		mat.shader = load(RUTA_SHADER_HUMO)
		mat.set_shader_parameter("velocidad_turbulencia", 0.75)
		mat.set_shader_parameter("escala_ruido", 3.3)
		mat.set_shader_parameter("deformacion", 0.28)
		mat.set_shader_parameter("dureza_borde", 0.10)
		mat.set_shader_parameter("suavizado_borde", 0.44)
		mat.set_shader_parameter("contraste_detalle", 0.24)
		quad.material = mat
	else:
		var std := StandardMaterial3D.new()
		std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		std.vertex_color_use_as_albedo = true
		quad.material = std
	p.mesh = quad
	return p


func disparar_bocanada(fuerza: float = 0.7) -> void:
	_bocanada = maxf(_bocanada, clampf(fuerza, 0.2, 1.0))


func actualizar(gas: float, speed_kmh: float, encendido: bool, delta: float, _extra: bool = false) -> void:
	_asegurar_emisores()
	_bocanada = maxf(0.0, _bocanada - delta * 2.4)

	var activo_humo := humo_habilitado and encendido
	if is_instance_valid(_emisor_izq):
		_emisor_izq.emitting = activo_humo
	if is_instance_valid(_emisor_der):
		_emisor_der.emitting = activo_humo and escape_doble
	if not activo_humo:
		_intensidad_suave = move_toward(_intensidad_suave, 0.0, delta * 3.0)
		return

	# Posicionar en los Marker3D de los escapes o por offset respecto al chasis
	if is_instance_valid(marker_escape) and is_instance_valid(_emisor_izq):
		_emisor_izq.global_transform = marker_escape.global_transform
	elif is_instance_valid(_coche) and is_instance_valid(_emisor_izq):
		var off_i := Vector3(-separacion_escapes * 0.5, offset_escape.y, offset_escape.z)
		_emisor_izq.global_position = _coche.global_transform * off_i
		_emisor_izq.global_rotation = _coche.global_rotation

	if is_instance_valid(marker_escape_der) and is_instance_valid(_emisor_der):
		_emisor_der.global_transform = marker_escape_der.global_transform
	elif is_instance_valid(_coche) and is_instance_valid(_emisor_der):
		var off_d := Vector3(separacion_escapes * 0.5, offset_escape.y, offset_escape.z)
		_emisor_der.global_position = _coche.global_transform * off_d
		_emisor_der.global_rotation = _coche.global_rotation

	var carga_baja_vel := clampf(1.0 - (speed_kmh / 55.0), 0.35, 1.0)
	var objetivo := clampf(0.14 + gas * 0.78 * carga_baja_vel + _bocanada * 0.65, 0.14, 1.0)
	_intensidad_suave = lerpf(_intensidad_suave, objetivo, clampf(delta * 6.0, 0.0, 1.0))

	var col_idle := Color(0.56, 0.58, 0.62, 0.15)
	var col_diesel := Color(0.06, 0.06, 0.08, 0.86)
	var col_actual := col_idle.lerp(col_diesel, smoothstep(0.16, 0.82, _intensidad_suave))
	var vel_min := lerpf(1.5, 5.4, _intensidad_suave)
	var vel_max := lerpf(2.4, 7.8, _intensidad_suave)
	var scale_mult := lerpf(0.52, 1.48, _intensidad_suave)
	var arrastre_z := clampf(0.08 + speed_kmh * 0.036, 0.08, 2.35)
	var spread_actual := lerpf(9.0, 20.0, _intensidad_suave)
	var speed_sc := lerpf(0.75, 1.55, _intensidad_suave)

	for em in [_emisor_izq, _emisor_der]:
		if not is_instance_valid(em):
			continue
		em.color = col_actual
		em.scale_amount_min = scale_mult * 0.82
		em.scale_amount_max = scale_mult * 1.18
		em.initial_velocity_min = vel_min
		em.initial_velocity_max = vel_max
		em.spread = spread_actual
		em.speed_scale = speed_sc
		em.direction = Vector3(0.0, 1.0, arrastre_z).normalized()
