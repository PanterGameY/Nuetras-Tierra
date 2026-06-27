extends Node3D
class_name Parabrisas

# Parabrisas.gd
# Este script gestiona el estado dinamico del parabrisas del vehiculo (danos, suciedad, lluvia)
# y crea particulas fisicas (pequeños cristales) cuando ocurre un impacto fuerte.

@export var mesh_parabrisas: MeshInstance3D
@export var material_index: int = 0

# Parametros del material controlados dinamicamente
@export_range(0.0, 1.0) var nivel_suciedad: float = 0.0:
	set(val):
		nivel_suciedad = clamp(val, 0.0, 1.0)
		_actualizar_material()

@export_range(0.0, 1.0) var nivel_lluvia: float = 0.0:
	set(val):
		nivel_lluvia = clamp(val, 0.0, 1.0)
		_actualizar_material()

@export_range(0.0, 1.0) var nivel_dano: float = 0.0:
	set(val):
		nivel_dano = clamp(val, 0.0, 1.0)
		_actualizar_material()

@export var punto_impacto: Vector2 = Vector2(0.5, 0.5):
	set(val):
		punto_impacto = val
		_actualizar_material()

# Sistema de particulas para fragmentos de cristal
var _particles: GPUParticles3D

func _ready() -> void:
	# Intentar auto-localizar la malla si no esta asignada
	if not mesh_parabrisas:
		for child in get_parent().get_children():
			if child is MeshInstance3D and (child.name.to_lower().find("parabrisas") != -1 or child.name.to_lower().find("vidrio") != -1):
				mesh_parabrisas = child
				break
	
	_crear_sistema_particulas()
	_actualizar_material()

func _input(event: InputEvent) -> void:
	# Boton para reparar el parabrisas con fines de pruebas (tecla P)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			reparar_parabrisas()

func reparar_parabrisas() -> void:
	self.nivel_dano = 0.0
	punto_impacto = Vector2(0.5, 0.5)

func _actualizar_material() -> void:
	if not is_instance_valid(mesh_parabrisas):
		return
	
	var mat = mesh_parabrisas.material_override
	if not mat:
		mat = mesh_parabrisas.get_active_material(material_index)
	
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("dirt_level", nivel_suciedad)
		mat.set_shader_parameter("rain_intensity", nivel_lluvia)
		mat.set_shader_parameter("damage_level", nivel_dano)
		mat.set_shader_parameter("damage_center", punto_impacto)

# Metodo publico invocado desde coche.gd al impactar
func check_collision_impact(fuerza: float, local_collision_point: Vector3 = Vector3.ZERO) -> void:
	if fuerza >= 6.0:
		# Dano fuerte
		var incremento = clamp((fuerza - 6.0) * 0.08, 0.15, 0.6)
		self.nivel_dano += incremento
		
		# Proyectar el punto local 3D al plano UV (estimacion basica)
		if local_collision_point != Vector3.ZERO:
			punto_impacto = Vector2(
				clamp(local_collision_point.x + 0.5, 0.0, 1.0),
				clamp(local_collision_point.y + 0.5, 0.0, 1.0)
			)
		
		emitir_fragmentos_cristal()

# Emision de pequenos fragmentos 3D cubicos de cristal reflectante
func emitir_fragmentos_cristal() -> void:
	if is_instance_valid(_particles):
		_particles.emitting = true

func _crear_sistema_particulas() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "FragmentosParabrisas"
	_particles.amount = 45
	_particles.lifetime = 1.2
	_particles.one_shot = true
	_particles.explosiveness = 0.95
	_particles.fixed_fps = 60
	
	# Proceso de particulas
	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0.0, 0.5, 1.0).normalized()
	process_mat.spread = 45.0
	process_mat.initial_velocity_min = 2.5
	process_mat.initial_velocity_max = 6.0
	process_mat.gravity = Vector3(0.0, -9.81, 0.0)
	
	# Escala aleatoria de los cristales
	process_mat.scale_min = 0.01
	process_mat.scale_max = 0.04
	
	_particles.process_material = process_mat
	
	# Malla del fragmento (un pequeno cubo translucido brillante)
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.1, 0.1, 0.1)
	
	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.6)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.metallic = 0.9
	box_mesh.material = glass_mat
	
	_particles.draw_pass_1 = box_mesh
	add_child(_particles)
