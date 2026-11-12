@tool
extends Node3D
class_name VientoArboles

## VientoArboles.gd
##
## Asigna este script a cualquier árbol o modelo 3D (MeshInstance3D o nodo padre).
## Aplica el viento a todas las superficies preservando texturas y recortado de hojas (Alpha Scissor).

@export_group("Herramientas")
## Haz clic en esta casilla en el Inspector si deseas forzar la re-aplicación del viento
@export var recargar_viento: bool = false:
	set(val):
		if val:
			recargar_viento = false
			_preparar_arboles()

@export_group("Fuerza y Velocidad del Viento")
## Intensidad del balanceo del viento
@export_range(0.0, 5.0, 0.05) var fuerza_viento: float = 0.6:
	set(val):
		fuerza_viento = val
		_actualizar_parametros_shader()

## Velocidad de oscilación del viento
@export_range(0.0, 10.0, 0.2) var velocidad_viento: float = 3.0:
	set(val):
		velocidad_viento = val
		_actualizar_parametros_shader()

@export_group("Recortado de Hojas (Alpha Scissor)")
## Umbral de transparencia Alpha Scissor para recortar el fondo de las texturas de hojas (0.1 a 0.9)
@export_range(0.0, 1.0, 0.05) var umbral_alpha: float = 0.45:
	set(val):
		umbral_alpha = val
		_actualizar_parametros_shader()

@export_group("Sensibilidad y Altura")
## Altura mínima local en metros (Y=0 por defecto, donde las raíces no se mueven)
@export var altura_minima: float = 0.0:
	set(val):
		altura_minima = val
		_actualizar_parametros_shader()

## Sensibilidad al movimiento según la altura
@export_range(0.1, 3.0, 0.1) var sensibilidad_altura: float = 0.8:
	set(val):
		sensibilidad_altura = val
		_actualizar_parametros_shader()

var _materiales_shader: Array[ShaderMaterial] = []
var _inicializado: bool = false

func _ready() -> void:
	call_deferred("_preparar_arboles")

func _preparar_arboles() -> void:
	var shader_res = load("res://shaders/viento_arboles.gdshader")
	if not shader_res:
		return

	_materiales_shader.clear()

	# Buscar todas las mallas MeshInstance3D (este nodo o sus hijos)
	var mallas: Array[MeshInstance3D] = []
	var mi_nodo: Node = self
	if mi_nodo is MeshInstance3D:
		mallas.append(mi_nodo as MeshInstance3D)
	
	_buscar_mallas_recursivo(self, mallas)

	for mesh_node in mallas:
		if not is_instance_valid(mesh_node) or not mesh_node.mesh:
			continue

		var cant_superficies = mesh_node.mesh.get_surface_count()
		for i in range(cant_superficies):
			# Obtener el material original de la superficie o override
			var mat_original: Material = mesh_node.get_surface_override_material(i)
			if not mat_original:
				mat_original = mesh_node.mesh.surface_get_material(i)
			if not mat_original and mesh_node.material_override:
				mat_original = mesh_node.material_override
			if not mat_original and mesh_node.get_active_material(i):
				mat_original = mesh_node.get_active_material(i)

			var mat_shader: ShaderMaterial = null
			if mat_original is ShaderMaterial and (mat_original as ShaderMaterial).shader == shader_res:
				mat_shader = mat_original as ShaderMaterial
			else:
				mat_shader = ShaderMaterial.new()
				mat_shader.shader = shader_res

				# Transferir la textura Albedo y color del material original si existía
				if mat_original is StandardMaterial3D:
					var std_mat = mat_original as StandardMaterial3D
					if std_mat.albedo_texture:
						mat_shader.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
					mat_shader.set_shader_parameter("color_albedo", std_mat.albedo_color)
					mat_shader.set_shader_parameter("rugosidad", std_mat.roughness)

				mesh_node.set_surface_override_material(i, mat_shader)

			if not _materiales_shader.has(mat_shader):
				_materiales_shader.append(mat_shader)

	_inicializado = true
	_actualizar_parametros_shader()

func _buscar_mallas_recursivo(nodo: Node, resultado: Array[MeshInstance3D]) -> void:
	for child in nodo.get_children():
		if child is MeshInstance3D and not resultado.has(child):
			resultado.append(child as MeshInstance3D)
		_buscar_mallas_recursivo(child, resultado)

func _actualizar_parametros_shader() -> void:
	if not is_inside_tree() or not _inicializado:
		return

	for mat in _materiales_shader:
		if is_instance_valid(mat):
			mat.set_shader_parameter("fuerza_viento", fuerza_viento)
			mat.set_shader_parameter("velocidad_viento", velocidad_viento)
			mat.set_shader_parameter("umbral_alpha", umbral_alpha)
			mat.set_shader_parameter("altura_minima", altura_minima)
			mat.set_shader_parameter("sensibilidad_altura", sensibilidad_altura)
