@tool
extends MeshInstance3D
class_name AguaRealista

## AguaRealista.gd
##
## Asigna este script a cualquier MeshInstance3D (un PlaneMesh, BoxMesh, etc.)
## para aplicarle un shader de agua realista AAA con interacción dinámica en tiempo real
## para vehículos y jugador (ondas de choque, espuma de estela y turbulencia).

@export_group("Interacción con Vehículos y Jugador")
## Detectar automáticamente los nodos de las clases/grupos 'jugador' y 'vehiculo' al entrar al agua
@export var auto_detectar_jugador_y_vehiculos: bool = true

## Fuerza de las ondas de deformación generadas al paso del vehículo
@export_range(0.0, 1.0, 0.05) var fuerza_onda_interaccion: float = 0.35:
	set(val):
		fuerza_onda_interaccion = val
		_actualizar_material()

## Lista manual de nodos Node3D que interactuarán con el agua si se desea especificar
@export var nodos_interactivos_manuales: Array[Node3D] = []

@export_group("Texturas de Agua y Normales")
## Primer mapa de normales para el oleaje principal. Si está vacío, se genera automáticamente.
@export var textura_normal1: Texture2D = null:
	set(val):
		textura_normal1 = val
		_actualizar_material()

## Segundo mapa de normales para el oleaje cruzado. Si está vacío, se genera automáticamente.
@export var textura_normal2: Texture2D = null:
	set(val):
		textura_normal2 = val
		_actualizar_material()

## Textura de espuma para la orilla. Si está vacía, se genera automáticamente.
@export var textura_espuma: Texture2D = null:
	set(val):
		textura_espuma = val
		_actualizar_material()

## Fuerza del relieve del mapa de normales en la superficie
@export_range(0.0, 3.0, 0.1) var fuerza_normal: float = 1.2:
	set(val):
		fuerza_normal = val
		_actualizar_material()

@export_group("Colores Naturales del Agua")
## Color turquesa de las aguas poco profundas u orilla
@export var color_orilla: Color = Color(0.12, 0.42, 0.45, 0.50):
	set(val):
		color_orilla = val
		_actualizar_material()

## Color verdoso/azul profundo del centro o zonas hondas
@export var color_profundo: Color = Color(0.02, 0.12, 0.22, 0.95):
	set(val):
		color_profundo = val
		_actualizar_material()

## Color de la espuma blanca que se genera al chocar con la orilla o terrenos
@export var color_espuma: Color = Color(0.95, 0.98, 1.00, 0.95):
	set(val):
		color_espuma = val
		_actualizar_material()

@export_group("Espuma Avanzada (Orilla y Crestas)")
## Distancia desde el objeto donde comienza a dibujarse la espuma de choque
@export_range(0.1, 5.0, 0.1) var distancia_espuma_orilla: float = 1.2:
	set(val):
		distancia_espuma_orilla = val
		_actualizar_material()

## Velocidad de movimiento del oleaje de espuma contra la orilla
@export_range(0.0, 5.0, 0.1) var velocidad_espuma: float = 1.8:
	set(val):
		velocidad_espuma = val
		_actualizar_material()

## Intensidad/brillo de la espuma
@export_range(0.1, 3.0, 0.1) var intensidad_espuma: float = 1.5:
	set(val):
		intensidad_espuma = val
		_actualizar_material()

## Escala de detalle de las burbujas Voronoi en la espuma
@export_range(1.0, 30.0, 1.0) var escala_burbujas_espuma: float = 12.0:
	set(val):
		escala_burbujas_espuma = val
		_actualizar_material()

## Cantidad de espuma que se forma en las crestas/picos de las olas en mar abierto
@export_range(0.0, 1.0, 0.05) var espuma_cresta_olas: float = 0.45:
	set(val):
		espuma_cresta_olas = val
		_actualizar_material()

@export_group("Olas y Movimiento 3D")
## Velocidad del oleaje general
@export_range(0.0, 5.0, 0.1) var velocidad_olas: float = 1.0:
	set(val):
		velocidad_olas = val
		_actualizar_material()

## Altura/amplitud de las olas en el eje Y
@export_range(0.0, 1.5, 0.02) var altura_olas: float = 0.12:
	set(val):
		altura_olas = val
		_actualizar_material()

## Escala del patrón de las olas
@export_range(0.1, 20.0, 0.5) var escala_olas: float = 3.5:
	set(val):
		escala_olas = val
		_actualizar_material()

@export_group("Acabado y Reflexión PBR")
## Rugosidad del agua (Menor = reflejos más pulidos)
@export_range(0.0, 1.0, 0.02) var rugosidad: float = 0.05:
	set(val):
		rugosidad = val
		_actualizar_material()

## Propiedad metálica para reflejo especular
@export_range(0.0, 1.0, 0.02) var metalico: float = 0.05:
	set(val):
		metalico = val
		_actualizar_material()

## Intensidad del efecto Fresnel (reflejo de la luz en ángulos rasantes)
@export_range(0.5, 8.0, 0.5) var fresnel_potencia: float = 3.5:
	set(val):
		fresnel_potencia = val
		_actualizar_material()

var _material: ShaderMaterial = null
var _noise_gen_1: NoiseTexture2D = null
var _noise_gen_2: NoiseTexture2D = null
var _noise_espuma_gen: NoiseTexture2D = null

func _ready() -> void:
	_garantizar_texturas_procedurales()
	_inicializar_material()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_actualizar_posiciones_interactivas()

func _actualizar_posiciones_interactivas() -> void:
	if not _material:
		return

	var candidatos: Array[Node3D] = []

	# 1. Agregar nodos manuales
	for n in nodos_interactivos_manuales:
		if is_instance_valid(n) and n is Node3D:
			candidatos.append(n)

	# 2. Buscar automáticamente jugador y vehículos en escena
	if auto_detectar_jugador_y_vehiculos:
		for grp in ["jugador", "vehiculo", "vehiculos"]:
			for n in get_tree().get_nodes_in_group(grp):
				if n is Node3D and is_instance_valid(n) and not candidatos.has(n):
					candidatos.append(n)

	# Filtrar los 8 más cercanos a esta malla de agua
	var pos_agua = global_position
	candidatos.sort_custom(func(a, b): return a.global_position.distance_to(pos_agua) < b.global_position.distance_to(pos_agua))

	var array_vec4: Array[Vector4] = []
	var cantidad = 0

	for i in range(min(8, candidatos.size())):
		var nodo = candidatos[i]
		var pos = nodo.global_position
		
		# Estimar radio de influencia según el tipo de objeto
		var radio: float = 1.5
		if nodo is RigidBody3D or "vehiculo" in nodo.name.to_lower():
			radio = 2.8
			
		array_vec4.append(Vector4(pos.x, pos.y, pos.z, radio))
		cantidad += 1

	# Rellenar hasta 8 para evitar errores de uniform array
	while array_vec4.size() < 8:
		array_vec4.append(Vector4(0, 0, 0, 0))

	_material.set_shader_parameter("objetos_interactivos", array_vec4)
	_material.set_shader_parameter("cantidad_objetos", cantidad)
	_material.set_shader_parameter("fuerza_onda_interaccion", fuerza_onda_interaccion)

func _garantizar_texturas_procedurales() -> void:
	if not textura_normal1:
		if not _noise_gen_1:
			var noise1 = FastNoiseLite.new()
			noise1.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise1.frequency = 0.02
			noise1.fractal_octaves = 3
			
			_noise_gen_1 = NoiseTexture2D.new()
			_noise_gen_1.as_normal_map = true
			_noise_gen_1.bump_strength = 6.0
			_noise_gen_1.noise = noise1
		textura_normal1 = _noise_gen_1

	if not textura_normal2:
		if not _noise_gen_2:
			var noise2 = FastNoiseLite.new()
			noise2.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise2.frequency = 0.03
			noise2.cellular_jitter = 0.85
			
			_noise_gen_2 = NoiseTexture2D.new()
			_noise_gen_2.as_normal_map = true
			_noise_gen_2.bump_strength = 8.0
			_noise_gen_2.noise = noise2
		textura_normal2 = _noise_gen_2

	if not textura_espuma:
		if not _noise_espuma_gen:
			var noise_f = FastNoiseLite.new()
			noise_f.noise_type = FastNoiseLite.TYPE_PERLIN
			noise_f.frequency = 0.04
			
			_noise_espuma_gen = NoiseTexture2D.new()
			_noise_espuma_gen.noise = noise_f
		textura_espuma = _noise_espuma_gen

func _inicializar_material() -> void:
	var shader_res = load("res://shaders/agua_realista.gdshader")
	if not shader_res:
		push_error("[AguaRealista] No se encontró el archivo de shader: res://shaders/agua_realista.gdshader")
		return

	if material_override is ShaderMaterial and (material_override as ShaderMaterial).shader == shader_res:
		_material = material_override as ShaderMaterial
	else:
		_material = ShaderMaterial.new()
		_material.shader = shader_res
		material_override = _material

	_actualizar_material()

func _actualizar_material() -> void:
	if not is_inside_tree():
		return
		
	if not _material:
		_inicializar_material()
		return

	_garantizar_texturas_procedurales()
		
	_material.set_shader_parameter("textura_normal1", textura_normal1)
	_material.set_shader_parameter("textura_normal2", textura_normal2)
	_material.set_shader_parameter("textura_espuma", textura_espuma)
	_material.set_shader_parameter("fuerza_normal", fuerza_normal)
	_material.set_shader_parameter("color_orilla", color_orilla)
	_material.set_shader_parameter("color_profundo", color_profundo)
	_material.set_shader_parameter("color_espuma", color_espuma)
	_material.set_shader_parameter("distancia_espuma_orilla", distancia_espuma_orilla)
	_material.set_shader_parameter("velocidad_espuma", velocidad_espuma)
	_material.set_shader_parameter("intensidad_espuma", intensidad_espuma)
	_material.set_shader_parameter("escala_burbujas_espuma", escala_burbujas_espuma)
	_material.set_shader_parameter("espuma_cresta_olas", espuma_cresta_olas)
	_material.set_shader_parameter("velocidad_olas", velocidad_olas)
	_material.set_shader_parameter("altura_olas", altura_olas)
	_material.set_shader_parameter("escala_olas", escala_olas)
	_material.set_shader_parameter("rugosidad", rugosidad)
	_material.set_shader_parameter("metalico", metalico)
	_material.set_shader_parameter("fresnel_potencia", fresnel_potencia)
	_material.set_shader_parameter("fuerza_onda_interaccion", fuerza_onda_interaccion)
