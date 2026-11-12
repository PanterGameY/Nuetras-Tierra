@tool
class_name PlacaMeshController
extends MeshInstance3D

## Fuente personalizada para la placa (.otf / .ttf)
@export var fuente: Font = preload("res://recursos/fonts/Moderniz.otf"):
	set(v):
		fuente = v
		_actualizar_shader()

## Texto de la placa en formato "ABC 123" o 6 caracteres (ej: "HDE 050")
@export var placa_texto: String = "HDE 050":
	set(val):
		placa_texto = val
		_actualizar_shader()

## Ciudad o texto inferior de la placa
@export var ciudad: String = "COLOMBIA":
	set(val):
		ciudad = val
		_actualizar_shader()

## Tipo de placa oficial colombiana
@export_enum("Personalizada:0", "Particular (Amarilla):1", "Público (Blanca):2", "Oficial (Amarilla):3", "Diplomático (Azul/Blanca):4", "Importación Temporal (Roja):5", "Remolque / Semiremolque (Verde):6", "Antiguo / Clásico (Azul/Blanca):7") var tipo_placa: int = 1:
	set(val):
		tipo_placa = val
		_actualizar_shader()

## Nivel de suciedad acumulado en la placa (0.0 = Limpia, 1.0 = Muy sucia)
@export_range(0.0, 1.0) var suciedad_nivel: float = 0.0:
	set(val):
		suciedad_nivel = val
		_actualizar_shader()

## Color de fondo (solo si tipo_placa es Personalizada:0)
@export var color_fondo: Color = Color(0.988, 0.73, 0.086, 1.0):
	set(val):
		color_fondo = val
		_actualizar_shader()

## Color del texto y bordes
@export var color_texto: Color = Color(0.08, 0.08, 0.08, 1.0):
	set(val):
		color_texto = val
		_actualizar_shader()

## Si es true, generará una placa aleatoria automáticamente al iniciar
@export var aleatorio_al_iniciar: bool = true

const SHADER_PLACA := preload("res://shaders/placa_colombiana.gdshader")

func _ready() -> void:
	_asegurar_material()
	if aleatorio_al_iniciar and not Engine.is_editor_hint():
		var coche := _buscar_coche_padre(self)
		if coche and coche.has_meta("placa_vehiculo_texto"):
			placa_texto = coche.get_meta("placa_vehiculo_texto")
			ciudad = coche.get_meta("placa_vehiculo_ciudad", "COLOMBIA")
			tipo_placa = coche.get_meta("placa_vehiculo_tipo", 1)
			suciedad_nivel = coche.get_meta("placa_vehiculo_suciedad", 0.0)
			_actualizar_shader()
		else:
			generar_placa_aleatoria()
	else:
		_actualizar_shader()

func _asegurar_material() -> ShaderMaterial:
	var mat: ShaderMaterial = get_surface_override_material(0) as ShaderMaterial
	if not mat:
		mat = material_override as ShaderMaterial
	if not mat or mat.shader != SHADER_PLACA:
		mat = ShaderMaterial.new()
		mat.shader = SHADER_PLACA
		set_surface_override_material(0, mat)
	return mat

func _actualizar_shader() -> void:
	var mat := _asegurar_material()
	if not mat:
		return

	# Limpiar espacios y pasar a mayúsculas
	var texto_limpio := placa_texto.replace(" ", "").strip_edges().to_upper()
	
	var letras := "ABC"
	var numeros := "123"
	
	if texto_limpio.length() >= 6:
		letras = texto_limpio.substr(0, 3)
		numeros = texto_limpio.substr(3, 3)
	elif texto_limpio.length() >= 3:
		letras = texto_limpio.substr(0, 3)

	var c1 := _char_to_index(letras, 0)
	var c2 := _char_to_index(letras, 1)
	var c3 := _char_to_index(letras, 2)

	var n1 := _num_to_index(numeros, 0)
	var n2 := _num_to_index(numeros, 1)
	var n3 := _num_to_index(numeros, 2)

	mat.set_shader_parameter("tipo_placa", tipo_placa)
	mat.set_shader_parameter("color_fondo", color_fondo)
	mat.set_shader_parameter("color_texto", color_texto)
	mat.set_shader_parameter("suciedad_nivel", suciedad_nivel)
	mat.set_shader_parameter("char_1", c1)
	mat.set_shader_parameter("char_2", c2)
	mat.set_shader_parameter("char_3", c3)
	mat.set_shader_parameter("num_1", n1)
	mat.set_shader_parameter("num_2", n2)
	mat.set_shader_parameter("num_3", n3)

func _char_to_index(s: String, idx: int) -> int:
	if idx < s.length():
		var code := s.unicode_at(idx)
		if code >= 65 and code <= 90: # A-Z
			return code - 65
	return 0

func _num_to_index(s: String, idx: int) -> int:
	if idx < s.length():
		var code := s.unicode_at(idx)
		if code >= 48 and code <= 57: # 0-9
			return code - 48
	return 0

## Genera y aplica una placa colombiana aleatoria
func generar_placa_aleatoria(tipo: int = -1) -> String:
	const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var p_letras := ""
	var p_numeros := ""
	for _i in 3:
		p_letras += LETRAS[rng.randi() % 26]
	for _i in 3:
		p_numeros += str(rng.randi() % 10)

	placa_texto = p_letras + " • " + p_numeros
	tipo_placa = tipo if tipo >= 0 else 1
	
	var coche := _buscar_coche_padre(self)
	if coche:
		coche.set_meta("placa_vehiculo_texto", placa_texto)
		coche.set_meta("placa_vehiculo_ciudad", ciudad)
		coche.set_meta("placa_vehiculo_tipo", tipo_placa)
		coche.set_meta("placa_vehiculo_suciedad", suciedad_nivel)
		_sincronizar_placas_hermanas(coche)

	_actualizar_shader()
	return placa_texto

func _buscar_coche_padre(nodo: Node) -> Node:
	var actual := nodo.get_parent()
	while actual:
		if actual is RigidBody3D or actual.name.to_lower().contains("coche") or actual.name.to_lower().contains("vehiculo"):
			return actual
		actual = actual.get_parent()
	return null

func _sincronizar_placas_hermanas(coche: Node) -> void:
	if not is_instance_valid(coche):
		return
	var placas := coche.find_children("*", "PlacaMeshController", true, false)
	for p in placas:
		if p != self and p is PlacaMeshController:
			p.placa_texto = placa_texto
			p.ciudad = ciudad
			p.tipo_placa = tipo_placa
			p.suciedad_nivel = suciedad_nivel
