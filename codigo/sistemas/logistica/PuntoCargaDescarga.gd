@tool
extends Marker3D
class_name PuntoCargaDescarga

## PuntoCargaDescarga.gd
##
## Nodo de referencia Marker3D para definir puntos de Carga, Descarga o Ambos en la escena.
## Funciona idealmente como destino para GPS y rutas, incluyendo previsualización en el editor
## con @tool (cilindro o caja), etiquetas flotantes 3D y zona Area3D de detección opcional.

enum TipoPunto {
	CARGA,
	DESCARGA,
	AMBOS
}

enum FormaZona {
	CILINDRO,
	CAJA
}

# ── Exportaciones de Identificación ──
@export_group("Identificación del Punto")
## Identificador único para referenciar este punto por código o misiones
@export var id_punto: String = "punto_01":
	set(val):
		id_punto = val
		_actualizar_visuales()

## Nombre descriptivo visible en el HUD o GPS (ej: "Muelle A - Puerto")
@export var nombre_punto: String = "Punto de Carga A":
	set(val):
		nombre_punto = val
		_actualizar_visuales()

## Posición o número de orden en la secuencia/lista
@export var orden_indice: int = 0:
	set(val):
		orden_indice = val
		_actualizar_visuales()

# ── Exportaciones de Configuración ──
@export_group("Modo y Operación")
## Determina si el punto es de Carga, Descarga o ambos usos
@export var tipo_punto: TipoPunto = TipoPunto.CARGA:
	set(val):
		tipo_punto = val
		_actualizar_visuales()

## Activa la generación de una zona de detección física Area3D en este Marker3D
@export var generar_area_deteccion: bool = true:
	set(val):
		generar_area_deteccion = val
		_actualizar_visuales()

## Tipos de mercancía o carga aceptados en este punto (ej: ["cajas", "combustible", "general"])
@export var cargas_permitidas: Array[String] = ["general"]:
	set(val):
		cargas_permitidas = val
		_actualizar_visuales()

## Tarifa o recompensa base para misiones en este punto
@export var tarifa_base: float = 1500.0

## Tiempo en segundos requerido para completar el proceso de carga o descarga
@export var tiempo_operacion: float = 5.0

# ── Exportaciones de Forma y Dimensiones ──
@export_group("Forma y Dimensiones")
## Forma geométrica del área de la zona
@export var forma_zona: FormaZona = FormaZona.CILINDRO:
	set(val):
		forma_zona = val
		_actualizar_visuales()

## Radio del área (solo para forma Cilindro)
@export var radio: float = 3.5:
	set(val):
		radio = max(0.5, val)
		_actualizar_visuales()

## Ancho (Eje X, solo para forma Caja)
@export var ancho: float = 5.0:
	set(val):
		ancho = max(0.5, val)
		_actualizar_visuales()

## Largo (Eje Z, solo para forma Caja)
@export var largo: float = 8.0:
	set(val):
		largo = max(0.5, val)
		_actualizar_visuales()

## Altura de la zona (Eje Y)
@export var altura: float = 3.0:
	set(val):
		altura = max(0.5, val)
		_actualizar_visuales()

# ── Exportaciones Visuales ──
@export_group("Apariencia en Editor y Juego")
## Grosor del marco/línea de límite en el suelo (de 0.02 a 0.3)
@export_range(0.02, 0.3, 0.01) var grosor_linea: float = 0.06:
	set(val):
		grosor_linea = val
		_actualizar_visuales()

## Radio de curvatura para las esquinas redondeadas del marco rectangular
@export_range(0.05, 0.5, 0.05) var radio_esquinas: float = 0.25:
	set(val):
		radio_esquinas = val
		_actualizar_visuales()

## Velocidad de la animación del trail/resplandor a lo largo del marco
@export_range(0.0, 10.0, 0.5) var velocidad_animacion: float = 3.5:
	set(val):
		velocidad_animacion = val
		_actualizar_visuales()

## Velocidad del efecto de respiración/pulsación neón
@export_range(0.0, 10.0, 0.5) var velocidad_pulsacion: float = 2.0:
	set(val):
		velocidad_pulsacion = val
		_actualizar_visuales()

## Si es verdadero, usa el color personalizado en vez del predeterminado por TipoPunto
@export var usar_color_personalizado: bool = false:
	set(val):
		usar_color_personalizado = val
		_actualizar_visuales()

## Color personalizado para el área y el texto flotante
@export var color_personalizado: Color = Color(0.2, 0.8, 1.0, 0.9):
	set(val):
		color_personalizado = val
		_actualizar_visuales()

## Transparencia general del marco de la zona
@export_range(0.1, 1.0, 0.05) var opacidad_zona: float = 0.9:
	set(val):
		opacidad_zona = val
		_actualizar_visuales()

## Muestra u oculta la etiqueta flotante 3D con el nombre del punto
@export var mostrar_etiqueta_3d: bool = true:
	set(val):
		mostrar_etiqueta_3d = val
		_actualizar_visuales()

# ── Señales ──
signal vehiculo_entro(cuerpo: Node, punto: PuntoCargaDescarga)
signal vehiculo_salio(cuerpo: Node, punto: PuntoCargaDescarga)

# Referencias a sub-nodos internos
var _area_node: Area3D = null
var _mesh_node: MeshInstance3D = null
var _collision_node: CollisionShape3D = null
var _label_node: Label3D = null

func _ready() -> void:
	_garantizar_nodos_internos()
	_actualizar_visuales()
	
	if not Engine.is_editor_hint():
		add_to_group("puntos_carga_descarga")

func _garantizar_nodos_internos() -> void:
	# 1. Area3D (Detección interna)
	if generar_area_deteccion:
		_area_node = get_node_or_null("AreaDeteccion") as Area3D
		if not _area_node:
			_area_node = Area3D.new()
			_area_node.name = "AreaDeteccion"
			add_child(_area_node)
			if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
				_area_node.owner = get_tree().edited_scene_root

		# CollisionShape3D dentro del Area3D
		_collision_node = _area_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not _collision_node:
			_collision_node = CollisionShape3D.new()
			_collision_node.name = "CollisionShape3D"
			_area_node.add_child(_collision_node)
			if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
				_collision_node.owner = get_tree().edited_scene_root
				
		if not Engine.is_editor_hint():
			if not _area_node.body_entered.is_connected(_on_body_entered):
				_area_node.body_entered.connect(_on_body_entered)
			if not _area_node.body_exited.is_connected(_on_body_exited):
				_area_node.body_exited.connect(_on_body_exited)
	else:
		if is_instance_valid(_area_node):
			_area_node.queue_free()
			_area_node = null
			_collision_node = null

	# 2. MeshInstance3D (Visual del Editor / Zona)
	_mesh_node = get_node_or_null("VisualZona") as MeshInstance3D
	if not _mesh_node:
		_mesh_node = MeshInstance3D.new()
		_mesh_node.name = "VisualZona"
		add_child(_mesh_node)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			_mesh_node.owner = get_tree().edited_scene_root

	# 3. Label3D (Texto Informativo)
	_label_node = get_node_or_null("EtiquetaPunto") as Label3D
	if not _label_node:
		_label_node = Label3D.new()
		_label_node.name = "EtiquetaPunto"
		_label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label_node.font_size = 42
		_label_node.outline_size = 10
		_label_node.outline_modulate = Color.BLACK
		_label_node.no_depth_test = true
		add_child(_label_node)
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			_label_node.owner = get_tree().edited_scene_root

func _obtener_color_base() -> Color:
	if usar_color_personalizado:
		return color_personalizado
	
	match tipo_punto:
		TipoPunto.CARGA:
			return Color(0.20, 0.85, 0.35) # Verde neón para Carga
		TipoPunto.DESCARGA:
			return Color(1.00, 0.30, 0.25) # Rojo/Naranja neón para Descarga
		TipoPunto.AMBOS:
			return Color(0.20, 0.65, 1.00) # Azul/Cian neón para Carga/Descarga
	return Color.WHITE

func _actualizar_visuales() -> void:
	if not is_inside_tree():
		return
		
	_garantizar_nodos_internos()
	
	var color_base = _obtener_color_base()
	var color_final = Color(color_base.r, color_base.g, color_base.b, opacidad_zona)
	var es_circulo = (forma_zona == FormaZona.CILINDRO)
	
	# ── Configurar Malla y Colisión ──
	if es_circulo:
		# Actualizar CollisionShape (CylinderShape3D)
		if _collision_node:
			var cyl_shape = _collision_node.shape as CylinderShape3D
			if not cyl_shape:
				cyl_shape = CylinderShape3D.new()
				_collision_node.shape = cyl_shape
			cyl_shape.radius = radio
			cyl_shape.height = altura
			_collision_node.position = Vector3(0, altura / 2.0, 0)
		
		# Plano para el marco circular
		var plane_mesh = _mesh_node.mesh as PlaneMesh
		if not plane_mesh:
			plane_mesh = PlaneMesh.new()
			_mesh_node.mesh = plane_mesh
		plane_mesh.size = Vector2(radio * 2.0, radio * 2.0)
		_mesh_node.position = Vector3(0, 0.02, 0)

	else: # FormaZona.CAJA
		# Actualizar CollisionShape (BoxShape3D)
		if _collision_node:
			var box_shape = _collision_node.shape as BoxShape3D
			if not box_shape:
				box_shape = BoxShape3D.new()
				_collision_node.shape = box_shape
			box_shape.size = Vector3(ancho, altura, largo)
			_collision_node.position = Vector3(0, altura / 2.0, 0)
		
		# Plano para el marco rectangular
		var plane_mesh = _mesh_node.mesh as PlaneMesh
		if not plane_mesh:
			plane_mesh = PlaneMesh.new()
			_mesh_node.mesh = plane_mesh
		plane_mesh.size = Vector2(ancho, largo)
		_mesh_node.position = Vector3(0, 0.02, 0)

	# ── Aplicar Shader del Marco Delgado con Esquinas Redondeadas y Trail Animado ──
	var shader_res = load("res://shaders/marco_zona_suelo.gdshader")
	if shader_res:
		var mat = ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("line_color", color_final)
		mat.set_shader_parameter("line_thickness", grosor_linea)
		mat.set_shader_parameter("corner_radius", radio_esquinas)
		mat.set_shader_parameter("trail_speed", velocidad_animacion)
		mat.set_shader_parameter("pulse_speed", velocidad_pulsacion)
		mat.set_shader_parameter("es_circulo", es_circulo)
		_mesh_node.material_override = mat
	else:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color_final
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mesh_node.material_override = mat

	# ── Label 3D Informativo ──
	if _label_node:
		_label_node.visible = mostrar_etiqueta_3d
		var str_tipo = "CARGA" if tipo_punto == TipoPunto.CARGA else ("DESCARGA" if tipo_punto == TipoPunto.DESCARGA else "CARGA y DESCARGA")
		var str_cargas = obtener_resumen_cargas()
		if str_cargas != "":
			_label_node.text = "[%d] %s\n(%s)\n%s" % [orden_indice, nombre_punto, str_tipo, str_cargas]
		else:
			_label_node.text = "[%d] %s\n(%s)" % [orden_indice, nombre_punto, str_tipo]
		_label_node.modulate = Color(color_base.r, color_base.g, color_base.b, 1.0)
		_label_node.position = Vector3(0, 1.8, 0)

# ── Handlers de Colisión ──
func _on_body_entered(body: Node) -> void:
	vehiculo_entro.emit(body, self)

func _on_body_exited(body: Node) -> void:
	vehiculo_salio.emit(body, self)

## Método de consulta rápido para saber si acepta un tipo de operación
func es_punto_de_carga() -> bool:
	return tipo_punto == TipoPunto.CARGA or tipo_punto == TipoPunto.AMBOS

func es_punto_de_descarga() -> bool:
	return tipo_punto == TipoPunto.DESCARGA or tipo_punto == TipoPunto.AMBOS

## Verifica si este punto acepta un tipo de carga específico
func acepta_carga(tipo: String) -> bool:
	if cargas_permitidas.has("general") and tipo == "general":
		return true
	return cargas_permitidas.has(tipo)

## Determina si se puede cargar la mercancía indicada
func puede_cargar(tipo: String) -> bool:
	return es_punto_de_carga() and acepta_carga(tipo)

## Determina si se puede descargar la mercancía indicada
func puede_descargar(tipo: String) -> bool:
	return es_punto_de_descarga() and acepta_carga(tipo)

## Obtiene una cadena breve con las cargas aceptadas
func obtener_resumen_cargas() -> String:
	if cargas_permitidas.is_empty():
		return "Sin cargas asignadas"
	if cargas_permitidas.size() <= 3:
		return ", ".join(cargas_permitidas)
	var primeros = [cargas_permitidas[0], cargas_permitidas[1]]
	return "%s +%d más" % [", ".join(primeros), cargas_permitidas.size() - 2]

## Método para calcular si un punto o vehículo está dentro de la distancia de radio/caja manualmente
func esta_en_rango(pos_global: Vector3) -> bool:
	var local_pos = to_local(pos_global)
	if abs(local_pos.y) > altura:
		return false
	if forma_zona == FormaZona.CILINDRO:
		var dist_2d = Vector2(local_pos.x, local_pos.z).length()
		return dist_2d <= radio
	else:
		return abs(local_pos.x) <= (ancho / 2.0) and abs(local_pos.z) <= (largo / 2.0)

## Carga toda la configuración desde un diccionario
func cargar_desde_diccionario(datos: Dictionary) -> void:
	GestorPuntosCarga.aplicar_datos_a_nodo(self, datos)

## Exporta toda la configuración a un diccionario serializable
func exportar_a_diccionario() -> Dictionary:
	return GestorPuntosCarga.extraer_datos_de_nodo(self)

