@tool
class_name PlacaVehiculo
extends Node3D

## Fuente personalizada para la placa (.otf / .ttf)
@export var fuente: Font = preload("res://recursos/fonts/Moderniz.otf"):
	set(v):
		fuente = v
		_update_labels()

## Texto de la placa (formato colombiano automático: "AAA • 123" o "LMN • 234")
@export var plate_text: String = "HDE • 050":
	set(v):
		plate_text = _formatear_texto_colombiano(v)
		_update_labels()

## Ciudad o país en la parte inferior de la placa (MEDELLÍN, BOGOTÁ D.C., CALI, MANIZALES, COLOMBIA)
@export var ciudad: String = "COLOMBIA":
	set(v):
		ciudad = v
		_update_labels()

## Tipo de placa oficial según normativa colombiana
@export_enum("Personalizada:0", "Particular (Amarilla):1", "Público (Blanca):2", "Oficial (Amarilla):3", "Diplomático (Azul/Blanca):4", "Importación Temporal (Roja):5", "Remolque / Semiremolque (Verde):6", "Antiguo / Clásico (Azul/Blanca):7") var tipo_placa: int = 1:
	set(v):
		tipo_placa = v
		publico = (tipo_placa == 2)
		_update_labels()
		_update_shader()

## Compatibilidad: Vehículo de servicio público → tipo_placa = 2
@export var publico: bool = false:
	set(v):
		publico = v
		if publico and tipo_placa == 1:
			tipo_placa = 2
		_update_shader()

## Nivel de suciedad/barro acumulado en la placa (0.0 = Limpia, 1.0 = Muy Sucia / Barro)
@export_range(0.0, 1.0) var suciedad_nivel: float = 0.0:
	set(v):
		suciedad_nivel = v
		_update_shader()

## Color del barro o suciedad
@export var suciedad_color: Color = Color(0.25, 0.17, 0.11, 1.0):
	set(v):
		suciedad_color = v
		_update_shader()

## Color de fondo personalizado (aplica cuando tipo_placa = Personalizada)
@export var color_fondo: Color = Color(0.988, 0.76, 0.05, 1.0):
	set(v):
		color_fondo = v
		_update_shader()

## Color del texto y bordes personalizados
@export var color_texto: Color = Color(0.08, 0.08, 0.08, 1.0):
	set(v):
		color_texto = v
		_update_shader()

## Genera una placa aleatoria automáticamente al iniciar en juego
@export var aleatorio_al_iniciar: bool = true

const SHADER_PLACA := preload("res://shaders/placa_colombiana.gdshader")

func _ready() -> void:
	_inicializar_viewport()
	
	if aleatorio_al_iniciar and not Engine.is_editor_hint():
		var coche := _buscar_coche_padre(self)
		if coche:
			if coche.has_meta("placa_vehiculo_texto"):
				# Copiar la misma placa generada por la primera placa del vehículo
				plate_text = coche.get_meta("placa_vehiculo_texto")
				ciudad = coche.get_meta("placa_vehiculo_ciudad", "COLOMBIA")
				tipo_placa = coche.get_meta("placa_vehiculo_tipo", 1)
				suciedad_nivel = coche.get_meta("placa_vehiculo_suciedad", 0.0)
				_update_labels()
			else:
				generar_placa_aleatoria(2 if publico else -1)
		else:
			generar_placa_aleatoria(2 if publico else -1)
	else:
		_update_labels()

func _inicializar_viewport() -> void:
	var vp := get_node_or_null("ViewportText") as SubViewport
	if vp:
		vp.transparent_bg = true
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

## Formatea automáticamente textos como "LMN234" a formato oficial "LMN • 234"
func _formatear_texto_colombiano(input: String) -> String:
	var s := input.strip_edges().to_upper()
	if s.contains("•"):
		return s
	
	s = s.replace("-", "").replace(" ", "")
	
	if s.length() == 6:
		var parte1 := s.substr(0, 3)
		var parte2 := s.substr(3, 3)
		if _es_alfabetico(parte1) and _es_numerico(parte2):
			return parte1 + " • " + parte2
			
	return input

func _es_alfabetico(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 65 or c > 90:
			return false
	return true

func _es_numerico(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true

func _update_labels() -> void:
	if not is_inside_tree():
		return
		
	var vp := get_node_or_null("ViewportText") as SubViewport
	if vp:
		var lbl_num := vp.get_node_or_null("ControlRoot/LabelNumero") as Label
		if lbl_num:
			lbl_num.text = plate_text
			if fuente:
				lbl_num.add_theme_font_override("font", fuente)
				
			if tipo_placa == 5 or tipo_placa == 6:
				lbl_num.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 1.0))
			else:
				lbl_num.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
			
			var len_text := plate_text.length()
			var target_size := 300
			if len_text > 9:
				target_size = int(300.0 * (9.0 / float(len_text)))
			lbl_num.add_theme_font_size_override("font_size", clamp(target_size, 150, 300))
				
		var lbl_city := vp.get_node_or_null("ControlRoot/LabelCiudad") as Label
		if lbl_city:
			if tipo_placa == 7:
				lbl_city.text = "CLASICO\n" + ciudad
			else:
				lbl_city.text = ciudad
				
			if fuente:
				lbl_city.add_theme_font_override("font", fuente)
				
			if tipo_placa == 5 or tipo_placa == 6:
				lbl_city.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 1.0))
			else:
				lbl_city.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
				
			lbl_city.add_theme_font_size_override("font_size", 80)
				
	_update_shader()

func _update_shader() -> void:
	if not is_inside_tree():
		return
		
	var mesh_node := get_node_or_null("PlacaMesh") as MeshInstance3D
	if not mesh_node:
		return
		
	var mat := mesh_node.material_override as ShaderMaterial
	if not mat or mat.shader != SHADER_PLACA:
		mat = ShaderMaterial.new()
		mat.shader = SHADER_PLACA
		mesh_node.material_override = mat

	var vp := get_node_or_null("ViewportText") as SubViewport
	if vp:
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var tex := vp.get_texture()
		if tex:
			mat.set_shader_parameter("texto_texture", tex)
			mat.set_shader_parameter("usar_textura_fuente", true)
	else:
		mat.set_shader_parameter("usar_textura_fuente", false)

	mat.set_shader_parameter("tipo_placa", tipo_placa)
	mat.set_shader_parameter("color_fondo", color_fondo)
	mat.set_shader_parameter("color_texto", color_texto)
	mat.set_shader_parameter("suciedad_nivel", suciedad_nivel)
	mat.set_shader_parameter("suciedad_color", suciedad_color)

## Cambia la placa y ciudad desde código en runtime
func set_plate(new_plate: String, new_city: String = "COLOMBIA") -> void:
	plate_text = new_plate
	ciudad = new_city
	
	var coche := _buscar_coche_padre(self)
	if coche:
		coche.set_meta("placa_vehiculo_texto", plate_text)
		coche.set_meta("placa_vehiculo_ciudad", ciudad)
		_sincronizar_placas_hermanas(coche)

## Cambia el nivel de suciedad (0.0 = limpia, 1.0 = muy sucia)
func set_suciedad(nivel: float) -> void:
	suciedad_nivel = clamp(nivel, 0.0, 1.0)
	var coche := _buscar_coche_padre(self)
	if coche:
		coche.set_meta("placa_vehiculo_suciedad", suciedad_nivel)
		_sincronizar_placas_hermanas(coche)

## Cambia el color de la placa a personalizado
func set_custom_color(new_bg: Color, new_text: Color = Color(0.08, 0.08, 0.08, 1.0)) -> void:
	tipo_placa = 0
	color_fondo = new_bg
	color_texto = new_text

## Genera una placa colombiana aleatoria y la sincroniza en todas las placas del vehículo
func generar_placa_aleatoria(tipo: int = -1) -> String:
	const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	const CIUDADES := ["BOGOTÁ D.C.", "MEDELLÍN", "CALI", "BARRANQUILLA", "BUCARAMANGA", "MANIZALES", "ENVIGADO", "PEREIRA", "CÚCUTA", "SABANETA"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var p_letras := ""
	var p_numeros := ""
	for _i in 3:
		p_letras += LETRAS[rng.randi() % 26]
	for _i in 3:
		p_numeros += str(rng.randi() % 10)

	if tipo >= 0:
		tipo_placa = tipo
	else:
		var r_tipo := rng.randf()
		if r_tipo < 0.70:
			tipo_placa = 1 # Particular
		elif r_tipo < 0.90:
			tipo_placa = 2 # Público
		else:
			tipo_placa = rng.randi_range(3, 7)

	if tipo_placa == 5: # Importación Temporal ("T • 0123")
		plate_text = "T • " + str(rng.randi_range(100, 9999))
		ciudad = "COLOMBIA"
	elif tipo_placa == 6: # Remolque ("R • 12345")
		plate_text = "R • " + str(rng.randi_range(1000, 99999))
		ciudad = "COLOMBIA"
	elif tipo_placa == 4: # Diplomático ("D ES • 567")
		plate_text = "D " + LETRAS[rng.randi() % 26] + LETRAS[rng.randi() % 26] + " • " + str(rng.randi_range(100, 999))
		ciudad = "COLOMBIA"
	else:
		plate_text = p_letras + " • " + p_numeros
		ciudad = CIUDADES[rng.randi() % CIUDADES.size()]

	# Guardar en metadatos del vehículo y sincronizar todas sus placas
	var coche := _buscar_coche_padre(self)
	if coche:
		coche.set_meta("placa_vehiculo_texto", plate_text)
		coche.set_meta("placa_vehiculo_ciudad", ciudad)
		coche.set_meta("placa_vehiculo_tipo", tipo_placa)
		coche.set_meta("placa_vehiculo_suciedad", suciedad_nivel)
		_sincronizar_placas_hermanas(coche)

	_update_labels()
	return plate_text

## Busca el nodo raíz del vehículo padre
func _buscar_coche_padre(nodo: Node) -> Node:
	var actual := nodo.get_parent()
	while actual:
		if actual is RigidBody3D or actual.name.to_lower().contains("coche") or actual.name.to_lower().contains("vehiculo"):
			return actual
		actual = actual.get_parent()
	return null

## Sincroniza todas las placas hijas del vehículo para que sean idénticas
func _sincronizar_placas_hermanas(coche: Node) -> void:
	if not is_instance_valid(coche):
		return
	var placas := coche.find_children("*", "PlacaVehiculo", true, false)
	for p in placas:
		if p != self and p is PlacaVehiculo:
			p.plate_text = plate_text
			p.ciudad = ciudad
			p.tipo_placa = tipo_placa
			p.suciedad_nivel = suciedad_nivel

## Método estático para generar texto de placa aleatoria colombiana (formato "AAA • 123")
static func generar_placa_colombiana() -> String:
	const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var letras: String = ""
	var numeros: String = ""
	for _i in 3:
		letras += LETRAS[rng.randi() % 26]
	for _i in 3:
		numeros += str(rng.randi() % 10)
	return letras + " • " + numeros
