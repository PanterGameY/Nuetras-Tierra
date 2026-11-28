class_name SistemaDanoColision
extends Node

## Sistema optimizado de daños por colisión basado 100% en shader (sin modificación de vértices).
## Adjunta un único ShaderMaterial compartido como `next_pass` a los materiales exteriores del vehículo.

const SHADER_DANO := preload("res://shaders/vehiculo/dano_colision.gdshader")
const MAX_IMPACTOS: int = 8

@export var umbral_velocidad_min: float = 2.5   # m/s (~9 km/h) mínimo para marcar daño
@export var velocidad_dano_maximo: float = 22.0 # m/s (~79 km/h) para daño máximo (1.0)
@export var radio_minimo: float = 0.40
@export var radio_maximo: float = 1.20
@export var cooldown_entre_impactos: float = 0.12

var _vehiculo: RigidBody3D = null
var _material_dano: ShaderMaterial = null
var _impactos: Array[Vector4] = []
var _radios: Array[float] = []
var _next_slot: int = 0
var _vel_previa: Vector3 = Vector3.ZERO
var _ultimo_impacto_ms: int = 0
var _inicializado: bool = false


func _ready() -> void:
	_vehiculo = get_parent() as RigidBody3D
	if not is_instance_valid(_vehiculo):
		set_physics_process(false)
		return

	_vehiculo.contact_monitor = true
	if _vehiculo.max_contacts_reported < 6:
		_vehiculo.max_contacts_reported = 6

	if not _vehiculo.body_entered.is_connected(_on_vehiculo_body_entered):
		_vehiculo.body_entered.connect(_on_vehiculo_body_entered)

	_preparar_shader_en_carroceria()


func _preparar_shader_en_carroceria() -> void:
	if _inicializado or not is_instance_valid(_vehiculo):
		return
	_inicializado = true

	_material_dano = ShaderMaterial.new()
	_material_dano.shader = SHADER_DANO

	_impactos.resize(MAX_IMPACTOS)
	_radios.resize(MAX_IMPACTOS)
	for i in range(MAX_IMPACTOS):
		_impactos[i] = Vector4.ZERO
		_radios[i] = 0.5

	_sincronizar_uniforms(0)
	_aplicar_next_pass_recursivo(_vehiculo)


func _aplicar_next_pass_recursivo(raiz: Node) -> void:
	var stack: Array[Node] = [raiz]
	var mats_procesados: Dictionary = {}

	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if not is_instance_valid(n):
			continue

		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var nom := mi.name.to_lower()
			var padre := mi.get_parent().name.to_lower() if mi.get_parent() else ""

			# Excluir vidrios, luces, ruedas e interiores
			var excluir := nom.contains("vidrio") or nom.contains("glass") or nom.contains("parabrisas") \
				or nom.contains("ventana") or nom.contains("faro") or nom.contains("luz") \
				or nom.contains("stop") or nom.contains("llanta") or nom.contains("rueda") \
				or nom.contains("wheel") or nom.contains("interior") or nom.contains("asiento") \
				or nom.contains("tablero") or nom.contains("volante") or nom.contains("pedal") \
				or padre.contains("interior") or padre.contains("cabina_int") or padre.contains("rueda")

			if not excluir and mi.mesh:
				if mi.material_override is BaseMaterial3D:
					var mat_ov := _clonar_y_enlazar_material(mi.material_override as BaseMaterial3D, mats_procesados)
					if mat_ov:
						mi.material_override = mat_ov
				else:
					for s in range(mi.mesh.get_surface_count()):
						var mat_act: Material = mi.get_active_material(s)
						if mat_act is BaseMaterial3D:
							var mat_nuevo := _clonar_y_enlazar_material(mat_act as BaseMaterial3D, mats_procesados)
							if mat_nuevo:
								mi.set_surface_override_material(s, mat_nuevo)

		for c in n.get_children():
			stack.append(c)


func _clonar_y_enlazar_material(orig: BaseMaterial3D, cache: Dictionary) -> BaseMaterial3D:
	if not orig or orig.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	var id := orig.get_instance_id()
	if cache.has(id):
		return cache[id] as BaseMaterial3D

	var dup := orig.duplicate(false) as BaseMaterial3D
	if dup:
		dup.next_pass = _material_dano
		cache[id] = dup
	return dup


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_vehiculo):
		return
	_vel_previa = _vehiculo.linear_velocity
	if _material_dano and _impactos_activos() > 0:
		_material_dano.set_shader_parameter("veh_inv_matrix", _vehiculo.global_transform.affine_inverse())


func _on_vehiculo_body_entered(body: Node) -> void:
	if not is_instance_valid(_vehiculo) or not _material_dano:
		return
	var ahora_ms := Time.get_ticks_msec()
	if (ahora_ms - _ultimo_impacto_ms) < int(cooldown_entre_impactos * 1000.0):
		return

	var vel_rel: float = _vel_previa.length()
	if body is RigidBody3D:
		vel_rel = (_vel_previa - (body as RigidBody3D).linear_velocity).length()

	if vel_rel < umbral_velocidad_min:
		return

	_ultimo_impacto_ms = ahora_ms
	var intensidad: float = clampf((vel_rel - umbral_velocidad_min) / maxf(velocidad_dano_maximo - umbral_velocidad_min, 0.1), 0.15, 1.0)
	var radio: float = lerpf(radio_minimo, radio_maximo, intensidad)

	var pos_local := _obtener_punto_contacto_local(body)
	registrar_impacto_local(pos_local, intensidad, radio)


func _obtener_punto_contacto_local(body: Node) -> Vector3:
	var state := PhysicsServer3D.body_get_direct_state(_vehiculo.get_rid())
	if state and state.get_contact_count() > 0:
		var p_world := state.get_contact_collider_position(0)
		return _vehiculo.to_local(p_world)
	if body is Node3D:
		var dir_local := _vehiculo.to_local((body as Node3D).global_position)
		if dir_local.length_squared() > 0.001:
			return dir_local.normalized() * 1.2
	return Vector3(0.0, 0.8, -1.8)


func registrar_impacto_local(pos_local: Vector3, intensidad: float, radio: float) -> void:
	if not _material_dano:
		return

	# Fusionar si ya hay un impacto muy cercano (< 0.45m) para ahorrar slots
	var count := _impactos_activos()
	for i in range(count):
		var p_prev := Vector3(_impactos[i].x, _impactos[i].y, _impactos[i].z)
		if p_prev.distance_to(pos_local) < 0.45:
			_impactos[i].w = clampf(maxf(_impactos[i].w, intensidad) + intensidad * 0.25, 0.0, 1.0)
			_radios[i] = maxf(_radios[i], radio)
			_sincronizar_uniforms(count)
			return

	_impactos[_next_slot] = Vector4(pos_local.x, pos_local.y, pos_local.z, clampf(intensidad, 0.0, 1.0))
	_radios[_next_slot] = radio
	_next_slot = (_next_slot + 1) % MAX_IMPACTOS

	var nuevo_count := mini(count + 1, MAX_IMPACTOS)
	_sincronizar_uniforms(nuevo_count)


func reparar_todo() -> void:
	for i in range(MAX_IMPACTOS):
		_impactos[i] = Vector4.ZERO
		_radios[i] = 0.5
	_next_slot = 0
	if _material_dano:
		_sincronizar_uniforms(0)


func _impactos_activos() -> int:
	if not _material_dano:
		return 0
	return int(_material_dano.get_shader_parameter("impact_count"))


func _sincronizar_uniforms(count: int) -> void:
	if not _material_dano:
		return
	_material_dano.set_shader_parameter("impact_count", count)
	_material_dano.set_shader_parameter("impactos", _impactos)
	_material_dano.set_shader_parameter("radios", _radios)
	if is_instance_valid(_vehiculo):
		_material_dano.set_shader_parameter("veh_inv_matrix", _vehiculo.global_transform.affine_inverse())
