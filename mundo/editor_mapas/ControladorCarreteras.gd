class_name ControladorCarreteras
extends Node3D

const RoadSegment = preload("res://addons/road-generator/nodes/road_segment.gd")

## ControladorCarreteras.gd — Generador y editor interactivo de carreteras (Road Generator)
## Permite trazar calles, avenidas y autopistas con mallas 3D, colisiones automáticas
## y terraformado dinámico para que el terreno NUNCA traspase la calzada.

signal carretera_actualizada()
signal tramo_finalizado()
signal cruce_seleccionado_cambiado(cruce: RoadIntersection)
signal ramal_cruce_seleccionado_cambiado(ramal: RoadPoint)
signal punto_carretera_seleccionado_cambiado(rp: RoadPoint)

enum TipoVia {
	CALLE_2_VIAS,
	AVENIDA_4_VIAS,
	AUTOPISTA_6_VIAS,
	TROCHA
}

const RUTA_MATERIAL_TROCHA: String = "res://materiales/Mapa/Trocha/Trocha.tres"
const RUTA_KIT_TROCHA_GLB: String = "res://mundo/editor_mapas/modelos/trocha_rural_latinoamericana.glb"

@export var tipo_via_actual: TipoVia = TipoVia.CALLE_2_VIAS
@export var elevacion_sobre_terreno: float = 0.25

var road_manager: Node3D
var equipamiento_controller: Node = null
var road_container: RoadContainer
var controlador_terreno: Node3D = null # Referencia inyectada a ControladorTerreno

var _mat_trocha_via: ShaderMaterial = null
var _mat_trocha_cruce: ShaderMaterial = null
var _mat_trocha_talud: StandardMaterial3D = null
var _mallas_kit_trocha: Dictionary = {}
var _kit_trocha_cargado: bool = false
var _actualizando_trochas: bool = false

var _ultimo_road_point: RoadPoint = null
var _puntos_creados: Array[RoadPoint] = []
var _historial_acciones: Array = []
var _marcador_preview: MeshInstance3D
var _marcador_seleccion_conexion: MeshInstance3D
var _marcador_cruce_seleccionado: Node3D = null
var _mesh_anillo_cruce: MeshInstance3D = null
var _mesh_disco_cruce: MeshInstance3D = null
var _nodo_ramales_cruce: Node3D = null
var _mat_anillo_cruce: StandardMaterial3D = null
var _mat_disco_cruce: StandardMaterial3D = null
var _mat_overlay_cruce: StandardMaterial3D = null
var _marcador_ramal_seleccionado: MeshInstance3D = null
var _linea_preview: ImmediateMesh
var _linea_instance: MeshInstance3D

var modo_conectar_activo: bool = false
var punto_snap_detectado: RoadPoint = null
var _punto_origen_conexion: RoadPoint = null
var rotacion_cruce_grados: float = 0.0
var subherramienta_via_actual: String = "calle_2"
var _marcador_preview_cruce: Node3D = null
var cruce_seleccionado: RoadIntersection = null
var ramal_cruce_seleccionado: RoadPoint = null
var punto_carretera_seleccionado: RoadPoint = null
var _contenedor_seleccionadores_puntos: Node3D = null
var _marcador_punto_seleccionado: Node3D = null
var _dict_marcadores_puntos: Dictionary = {}
var _rp_hover_actual: RoadPoint = null

func _ready() -> void:
	_inicializar_road_generator()
	_crear_marcador_preview()
	_crear_marcador_seleccion_conexion()
	_crear_marcador_preview_cruce()
	_crear_marcador_cruce_seleccionado()
	_crear_marcador_ramal_seleccionado()
	_crear_contenedor_seleccionadores()
	_crear_marcador_punto_seleccionado()

func _inicializar_road_generator() -> void:
	road_container = RoadContainer.new()
	road_container.name = "RoadContainer_Editor"
	road_container.create_geo = true
	road_container.density = 0.85 # Mayor densidad geométrica (0.85m por bucle) para curvas continuas y suaves
	road_container.underside_thickness = 0.60 # Faldón inferior sólido para evitar huecos en pendientes
	
	var mat_path = "res://addons/road-generator/resources/road_texture.tres"
	if not ResourceLoader.exists(mat_path):
		mat_path = "res://addons/road-generator/resources/road_texture.material"
	if ResourceLoader.exists(mat_path):
		road_container.material_resource = load(mat_path)
		
	# Material del faldón inferior (concreto/asfalto oscuro)
	var mat_under := StandardMaterial3D.new()
	mat_under.albedo_color = Color(0.18, 0.20, 0.22)
	mat_under.roughness = 0.92
	road_container.material_underside = mat_under
	road_container.on_road_updated.connect(_on_road_container_updated)
	carretera_actualizada.connect(_actualizar_segmentos_trocha)
		
	add_child(road_container)

func _crear_marcador_preview() -> void:
	_marcador_preview = MeshInstance3D.new()
	_marcador_preview.name = "MarcadorPreviewVia"
	
	var cyl = CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 2.0
	cyl.height = 0.25
	_marcador_preview.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.88, 0.68, 0.28, 0.85) # Automotive Instrument Amber
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marcador_preview.material_override = mat
	_marcador_preview.visible = false
	add_child(_marcador_preview)
	
	# Línea guía visual entre el último punto y el cursor
	_linea_instance = MeshInstance3D.new()
	_linea_instance.name = "LineaPreviewVia"
	_linea_preview = ImmediateMesh.new()
	_linea_instance.mesh = _linea_preview
	var mat_linea = StandardMaterial3D.new()
	mat_linea.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_linea.albedo_color = Color(0.88, 0.68, 0.28, 0.90)
	_linea_instance.material_override = mat_linea
	_linea_instance.visible = false
	add_child(_linea_instance)

func _crear_marcador_seleccion_conexion() -> void:
	_marcador_seleccion_conexion = MeshInstance3D.new()
	_marcador_seleccion_conexion.name = "MarcadorSeleccionConexion"
	var torus := TorusMesh.new()
	torus.inner_radius = 2.4
	torus.outer_radius = 2.8
	torus.rings = 36
	torus.ring_segments = 6
	_marcador_seleccion_conexion.mesh = torus
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.95) # Cyan brillante
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marcador_seleccion_conexion.material_override = mat
	_marcador_seleccion_conexion.visible = false
	add_child(_marcador_seleccion_conexion)

func _crear_marcador_preview_cruce() -> void:
	_marcador_preview_cruce = Node3D.new()
	_marcador_preview_cruce.name = "MarcadorPreviewCruce"
	
	var mat_cruce := StandardMaterial3D.new()
	mat_cruce.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_cruce.albedo_color = Color(0.88, 0.68, 0.28, 0.70)
	mat_cruce.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Centro del cruce
	var centro := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 4.0
	cyl.height = 0.25
	centro.mesh = cyl
	centro.material_override = mat_cruce
	_marcador_preview_cruce.add_child(centro)
	
	# Brazo Norte (adelante)
	var b_norte := MeshInstance3D.new()
	b_norte.name = "BrazoNorte"
	var box_n := BoxMesh.new()
	box_n.size = Vector3(3.6, 0.25, 11.0)
	b_norte.mesh = box_n
	b_norte.position = Vector3(0, 0, -5.5)
	b_norte.material_override = mat_cruce
	_marcador_preview_cruce.add_child(b_norte)
	
	# Brazo Sur (atrás - se oculta en cruce en T)
	var b_sur := MeshInstance3D.new()
	b_sur.name = "BrazoSur"
	var box_s := BoxMesh.new()
	box_s.size = Vector3(3.6, 0.25, 11.0)
	b_sur.mesh = box_s
	b_sur.position = Vector3(0, 0, 5.5)
	b_sur.material_override = mat_cruce
	_marcador_preview_cruce.add_child(b_sur)
	
	# Brazo Este (derecha)
	var b_este := MeshInstance3D.new()
	b_este.name = "BrazoEste"
	var box_e := BoxMesh.new()
	box_e.size = Vector3(11.0, 0.25, 3.6)
	b_este.mesh = box_e
	b_este.position = Vector3(5.5, 0, 0)
	b_este.material_override = mat_cruce
	_marcador_preview_cruce.add_child(b_este)
	
	# Brazo Oeste (izquierda)
	var b_oeste := MeshInstance3D.new()
	b_oeste.name = "BrazoOeste"
	var box_o := BoxMesh.new()
	box_o.size = Vector3(11.0, 0.25, 3.6)
	b_oeste.mesh = box_o
	b_oeste.position = Vector3(-5.5, 0, 0)
	b_oeste.material_override = mat_cruce
	_marcador_preview_cruce.add_child(b_oeste)
	
	_marcador_preview_cruce.visible = false
	add_child(_marcador_preview_cruce)

func _crear_marcador_cruce_seleccionado() -> void:
	_marcador_cruce_seleccionado = Node3D.new()
	_marcador_cruce_seleccionado.name = "MarcadorCruceSeleccionado"
	
	# 1. Anillo perimetral ámbar resplandeciente
	_mesh_anillo_cruce = MeshInstance3D.new()
	_mesh_anillo_cruce.name = "AnilloExterior"
	var torus := TorusMesh.new()
	torus.inner_radius = 5.6
	torus.outer_radius = 6.4
	torus.rings = 48
	torus.ring_segments = 24
	_mesh_anillo_cruce.mesh = torus
	
	_mat_anillo_cruce = StandardMaterial3D.new()
	_mat_anillo_cruce.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_anillo_cruce.albedo_color = Color(1.0, 0.78, 0.28, 0.95)
	_mat_anillo_cruce.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_anillo_cruce.material_override = _mat_anillo_cruce
	_marcador_cruce_seleccionado.add_child(_mesh_anillo_cruce)
	
	# 2. Disco holográfico semi-translúcido sobre el núcleo del cruce
	_mesh_disco_cruce = MeshInstance3D.new()
	_mesh_disco_cruce.name = "DiscoHolografico"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 5.4
	cyl.bottom_radius = 5.4
	cyl.height = 0.05
	_mesh_disco_cruce.mesh = cyl
	
	_mat_disco_cruce = StandardMaterial3D.new()
	_mat_disco_cruce.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_disco_cruce.albedo_color = Color(0.88, 0.68, 0.28, 0.25)
	_mat_disco_cruce.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_disco_cruce.material_override = _mat_disco_cruce
	_marcador_cruce_seleccionado.add_child(_mesh_disco_cruce)
	
	# 3. Contenedor de marcadores para los ramales/salidas del cruce
	_nodo_ramales_cruce = Node3D.new()
	_nodo_ramales_cruce.name = "ContenedorRamales"
	_marcador_cruce_seleccionado.add_child(_nodo_ramales_cruce)
	
	# 4. Material de overlay para teñir el asfalto del cruce seleccionado
	_mat_overlay_cruce = StandardMaterial3D.new()
	_mat_overlay_cruce.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_overlay_cruce.albedo_color = Color(0.92, 0.72, 0.25, 0.22)
	_mat_overlay_cruce.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_marcador_cruce_seleccionado.visible = false
	add_child(_marcador_cruce_seleccionado)

func _process(_delta: float) -> void:
	if is_instance_valid(cruce_seleccionado) and _marcador_cruce_seleccionado and _marcador_cruce_seleccionado.visible:
		var t = Time.get_ticks_msec() * 0.005
		var pulse_alpha = sin(t) * 0.12 + 0.88
		if _mat_anillo_cruce:
			_mat_anillo_cruce.albedo_color.a = 0.95 * pulse_alpha
		if _mat_disco_cruce:
			_mat_disco_cruce.albedo_color.a = 0.25 * pulse_alpha
			
	if is_instance_valid(punto_carretera_seleccionado) and _marcador_punto_seleccionado and _marcador_punto_seleccionado.visible:
		var t2 = Time.get_ticks_msec() * 0.007
		var pulse = sin(t2) * 0.10 + 1.0
		_marcador_punto_seleccionado.scale = Vector3(pulse, 1.0, pulse)

func _crear_contenedor_seleccionadores() -> void:
	_contenedor_seleccionadores_puntos = Node3D.new()
	_contenedor_seleccionadores_puntos.name = "ContenedorSeleccionadoresPuntos"
	add_child(_contenedor_seleccionadores_puntos)

func _crear_instancia_marcador_punto() -> Node3D:
	var nodo := Node3D.new()
	nodo.name = "MarcadorPuntoVia"
	
	# Anillo a nivel de rasante
	var mesh_anillo := MeshInstance3D.new()
	mesh_anillo.name = "Anillo"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.45
	torus.rings = 24
	torus.ring_segments = 12
	mesh_anillo.mesh = torus
	var mat_anillo := StandardMaterial3D.new()
	mat_anillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_anillo.albedo_color = Color(0.88, 0.68, 0.28, 0.85) # Ámbar cabina
	mat_anillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_anillo.material_override = mat_anillo
	nodo.add_child(mesh_anillo)
	
	# Disco interior oscuro
	var mesh_disco := MeshInstance3D.new()
	mesh_disco.name = "Disco"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.04
	mesh_disco.mesh = cyl
	var mat_disco := StandardMaterial3D.new()
	mat_disco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_disco.albedo_color = Color(0.09, 0.10, 0.12, 0.65) # Dark glass
	mat_disco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_disco.material_override = mat_disco
	nodo.add_child(mesh_disco)
	
	# Baliza vertical / pin
	var mesh_pin := MeshInstance3D.new()
	mesh_pin.name = "Pin"
	var pin_cyl := CylinderMesh.new()
	pin_cyl.top_radius = 0.05
	pin_cyl.bottom_radius = 0.08
	pin_cyl.height = 1.6
	mesh_pin.mesh = pin_cyl
	mesh_pin.position.y = 0.8
	var mat_pin := StandardMaterial3D.new()
	mat_pin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_pin.albedo_color = Color(0.88, 0.68, 0.28, 0.90)
	mat_pin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_pin.material_override = mat_pin
	nodo.add_child(mesh_pin)
	
	# Cabeza reflectiva
	var mesh_cabeza := MeshInstance3D.new()
	mesh_cabeza.name = "Cabeza"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	mesh_cabeza.mesh = sphere
	mesh_cabeza.position.y = 1.6
	var mat_cabeza := StandardMaterial3D.new()
	mat_cabeza.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_cabeza.albedo_color = Color(1.0, 0.82, 0.35, 0.95)
	mesh_cabeza.material_override = mat_cabeza
	nodo.add_child(mesh_cabeza)
	
	return nodo

func _crear_marcador_punto_seleccionado() -> void:
	_marcador_punto_seleccionado = Node3D.new()
	_marcador_punto_seleccionado.name = "MarcadorPuntoSeleccionado"
	
	# Anillo exterior cian neón
	var mesh_anillo := MeshInstance3D.new()
	mesh_anillo.name = "AnilloPulsante"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.8
	torus.rings = 32
	torus.ring_segments = 16
	mesh_anillo.mesh = torus
	var mat_anillo := StandardMaterial3D.new()
	mat_anillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_anillo.albedo_color = Color(0.2, 0.85, 1.0, 0.95)
	mat_anillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_anillo.material_override = mat_anillo
	_marcador_punto_seleccionado.add_child(mesh_anillo)
	
	# Anillo interior ámbar
	var mesh_inner := MeshInstance3D.new()
	mesh_inner.name = "AnilloInterior"
	var torus_in := TorusMesh.new()
	torus_in.inner_radius = 0.8
	torus_in.outer_radius = 1.15
	mesh_inner.mesh = torus_in
	var mat_in := StandardMaterial3D.new()
	mat_in.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_in.albedo_color = Color(1.0, 0.78, 0.25, 0.95)
	mat_in.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inner.material_override = mat_in
	_marcador_punto_seleccionado.add_child(mesh_inner)
	
	# Columna vertical holográfica
	var mesh_haz := MeshInstance3D.new()
	mesh_haz.name = "HazVertical"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.14
	cyl.height = 3.2
	mesh_haz.mesh = cyl
	mesh_haz.position.y = 1.6
	var mat_haz := StandardMaterial3D.new()
	mat_haz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_haz.albedo_color = Color(0.2, 0.85, 1.0, 0.75)
	mat_haz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_haz.material_override = mat_haz
	_marcador_punto_seleccionado.add_child(mesh_haz)
	
	_marcador_punto_seleccionado.visible = false
	add_child(_marcador_punto_seleccionado)

func _crear_marcador_ramal_seleccionado() -> void:
	_marcador_ramal_seleccionado = MeshInstance3D.new()
	_marcador_ramal_seleccionado.name = "MarcadorRamalSeleccionado"
	
	var torus := TorusMesh.new()
	torus.inner_radius = 2.4
	torus.outer_radius = 2.9
	torus.rings = 32
	torus.ring_segments = 16
	_marcador_ramal_seleccionado.mesh = torus
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.85, 1.0, 0.95) # Cyan brillante para salida seleccionada
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marcador_ramal_seleccionado.material_override = mat
	_marcador_ramal_seleccionado.visible = false
	add_child(_marcador_ramal_seleccionado)

func rotar_cruce(paso: float = 45.0) -> float:
	rotacion_cruce_grados = fmod(rotacion_cruce_grados + paso, 360.0)
	if _marcador_preview_cruce:
		_marcador_preview_cruce.rotation_degrees.y = rotacion_cruce_grados
	return rotacion_cruce_grados

func activar_modo_conexion() -> void:
	modo_conectar_activo = true
	_ultimo_road_point = null
	_punto_origen_conexion = null
	if _marcador_seleccion_conexion:
		_marcador_seleccion_conexion.visible = false
	if _linea_instance:
		_linea_instance.visible = false
	carretera_actualizada.emit()

func desactivar_modo_conexion() -> void:
	modo_conectar_activo = false
	_punto_origen_conexion = null
	if _marcador_seleccion_conexion:
		_marcador_seleccion_conexion.visible = false
	if _linea_instance:
		_linea_instance.visible = false

func buscar_punto_cercano_snap(pos_mundo: Vector3, radio_snap: float = 6.0, solo_extremos: bool = false) -> RoadPoint:
	var punto_cercano: RoadPoint = null
	var menor_dist: float = radio_snap
	for rp in _puntos_creados:
		if not is_instance_valid(rp):
			continue
		if solo_extremos:
			if not (rp.is_bare_edge(RoadPoint.PointInit.NEXT) or rp.is_bare_edge(RoadPoint.PointInit.PRIOR)):
				continue
		var d = rp.global_position.distance_to(pos_mundo)
		if d < menor_dist:
			menor_dist = d
			punto_cercano = rp
	return punto_cercano

func actualizar_cursor_via(pos_mundo: Vector3, visible_en_pantalla: bool) -> void:
	var target_pos := Vector3(pos_mundo.x, pos_mundo.y + elevacion_sobre_terreno + 0.05, pos_mundo.z)
	var es_cruce = subherramienta_via_actual in ["cruce_4", "cruce_t"]
	
	if not visible_en_pantalla:
		if _contenedor_seleccionadores_puntos:
			_contenedor_seleccionadores_puntos.visible = false
		if _linea_instance:
			_linea_instance.visible = false
		if _marcador_preview:
			_marcador_preview.visible = false
		if _marcador_preview_cruce:
			_marcador_preview_cruce.visible = false
		if _marcador_seleccion_conexion and _punto_origen_conexion == null:
			_marcador_seleccion_conexion.visible = false
		punto_snap_detectado = null
		return
		
	if _contenedor_seleccionadores_puntos:
		_contenedor_seleccionadores_puntos.visible = true
		
	if es_cruce:
		if _marcador_preview:
			_marcador_preview.visible = false
		if _linea_instance:
			_linea_instance.visible = false
		if _marcador_preview_cruce:
			_marcador_preview_cruce.visible = true
			_marcador_preview_cruce.global_position = target_pos
			_marcador_preview_cruce.rotation_degrees.y = rotacion_cruce_grados
			var b_sur = _marcador_preview_cruce.get_node_or_null("BrazoSur")
			if b_sur:
				b_sur.visible = (subherramienta_via_actual == "cruce_4")
		return
		
	if _marcador_preview_cruce:
		_marcador_preview_cruce.visible = false
		
	if not _marcador_preview:
		return
	_marcador_preview.visible = visible_en_pantalla
	
	var punto_snap = buscar_punto_cercano_snap(pos_mundo, 6.0, not modo_conectar_activo)
	punto_snap_detectado = punto_snap
	
	var es_snap_valido = (punto_snap != null and punto_snap != _ultimo_road_point and punto_snap != _punto_origen_conexion)
	
	if es_snap_valido:
		target_pos = punto_snap.global_position + Vector3(0, 0.1, 0)
		# Feedback visual de acople / snap (Cian brillante)
		if _marcador_preview.material_override:
			_marcador_preview.material_override.albedo_color = Color(0.2, 0.85, 1.0, 0.95)
	else:
		# Cursor normal (Ámbar)
		if _marcador_preview.material_override:
			_marcador_preview.material_override.albedo_color = Color(0.88, 0.68, 0.28, 0.85)
			
	_marcador_preview.global_position = target_pos
	
	# Si hay un punto de referencia activo (último punto trazado o primer punto de conexión), actualizar línea guía
	var ref_pt: RoadPoint = _punto_origen_conexion if modo_conectar_activo else _ultimo_road_point
	if ref_pt and is_instance_valid(ref_pt) and _linea_preview:
		_linea_instance.visible = true
		_linea_preview.clear_surfaces()
		_linea_preview.surface_begin(Mesh.PRIMITIVE_LINES)
		_linea_preview.surface_add_vertex(ref_pt.global_position + Vector3(0, 0.1, 0))
		_linea_preview.surface_add_vertex(target_pos)
		_linea_preview.surface_end()
		
		# Feedback si se detecta un cruce inminente entre vías
		var datos_cruce_prev = buscar_cruce_entre_tramos(ref_pt.global_position, target_pos, ref_pt, punto_snap if modo_conectar_activo else null)
		if datos_cruce_prev.get("hay_cruce", false) and not es_snap_valido:
			if _marcador_preview.material_override:
				_marcador_preview.material_override.albedo_color = Color(1.0, 0.52, 0.12, 0.95) # Naranja cruce
	else:
		if _linea_instance:
			_linea_instance.visible = false
			
	# Feedback hover sobre seleccionadores de puntos
	var rp_hover = buscar_punto_carretera_cercano(pos_mundo, 5.0)
	if rp_hover != _rp_hover_actual:
		if is_instance_valid(_rp_hover_actual) and _dict_marcadores_puntos.has(_rp_hover_actual):
			var m_old = _dict_marcadores_puntos[_rp_hover_actual]
			if is_instance_valid(m_old):
				m_old.scale = Vector3.ONE
				var an = m_old.get_node_or_null("Anillo")
				if an and an.material_override:
					an.material_override.albedo_color = Color(0.88, 0.68, 0.28, 0.85)
		_rp_hover_actual = rp_hover
		if is_instance_valid(rp_hover) and _dict_marcadores_puntos.has(rp_hover) and rp_hover != punto_carretera_seleccionado:
			var m_new = _dict_marcadores_puntos[rp_hover]
			if is_instance_valid(m_new):
				m_new.scale = Vector3(1.25, 1.25, 1.25)
				var an = m_new.get_node_or_null("Anillo")
				if an and an.material_override:
					an.material_override.albedo_color = Color(0.2, 0.85, 1.0, 0.95)

func _actualizar_orientaciones_y_curvaturas() -> void:
	if not road_container or not is_instance_valid(road_container):
		return
		
	var rps: Array = road_container.get_roadpoints()
	if rps.is_empty():
		return

	# Cada RoadPoint evalúa sus conexiones reales en el grafo (prior/next),
	# evitando cualquier contaminación de tangentes entre tramos diferentes.
	for obj in rps:
		var rp: RoadPoint = obj as RoadPoint
		if not is_instance_valid(rp):
			continue
			
		var p_prior: RoadPoint = null
		var inter_prior: RoadIntersection = null
		if not rp.prior_pt_init.is_empty():
			var n = rp.get_node_or_null(rp.prior_pt_init)
			if is_instance_valid(n):
				if n is RoadPoint:
					p_prior = n
				elif n.has_method("is_road_intersection"):
					inter_prior = n as RoadIntersection
				
		var p_next: RoadPoint = null
		var inter_next: RoadIntersection = null
		if not rp.next_pt_init.is_empty():
			var n = rp.get_node_or_null(rp.next_pt_init)
			if is_instance_valid(n):
				if n is RoadPoint:
					p_next = n
				elif n.has_method("is_road_intersection"):
					inter_next = n as RoadIntersection
					
		var inter_node: RoadIntersection = inter_prior if inter_prior != null else inter_next
				
		var t_dir: Vector3
		if inter_node != null and p_prior == null and p_next == null:
			# Brazo de cruce sin conexión externa: tangente apunta estrictamente radial hacia afuera
			t_dir = (rp.global_position - inter_node.global_position)
			t_dir.y = 0.0
			t_dir = t_dir.normalized()
			rp.prior_mag = 1.0
			rp.next_mag = 1.0
		elif inter_node != null and (p_prior != null or p_next != null):
			# Brazo de cruce conectado a una carretera entrante/saliente:
			# La tangente DEBE ser estrictamente radial hacia afuera del cruce para que el corte
			# de la calzada (basis.x) sea 100% recto y perpendicular, sin sesgos diagonales ni quiebres.
			var p_ext: RoadPoint = p_prior if p_prior != null else p_next
			var dir_radial = (rp.global_position - inter_node.global_position)
			dir_radial.y = 0.0
			t_dir = dir_radial.normalized()
			if t_dir.length_squared() < 0.001:
				t_dir = (p_ext.global_position - rp.global_position).normalized()
				t_dir.y = 0.0
				
			var dist_ext = rp.global_position.distance_to(p_ext.global_position)
			var mag_ext = clampf(dist_ext * 0.32, 1.0, 16.0)
			
			# En el extremo que conecta con el cruce, la magnitud debe ser fija y corta (1.0)
			# para que el generador de mallas una la parada sin bucles ni deformaciones Bezier.
			if inter_prior != null:
				rp.prior_mag = 1.0
				rp.next_mag = mag_ext
			else:
				rp.next_mag = 1.0
				rp.prior_mag = mag_ext
		elif p_prior == null and p_next != null:
			# Inicio de tramo: la tangente sale apuntando directamente hacia el siguiente punto
			t_dir = (p_next.global_position - rp.global_position).normalized()
			var dist = rp.global_position.distance_to(p_next.global_position)
			rp.next_mag = clamp(dist * 0.35, 1.0, 30.0)
			rp.prior_mag = rp.next_mag
		elif p_prior != null and p_next == null:
			# Fin de tramo: la tangente continúa recta perpendicular al tramo entrante
			t_dir = (rp.global_position - p_prior.global_position).normalized()
			var dist = p_prior.global_position.distance_to(rp.global_position)
			rp.prior_mag = clamp(dist * 0.35, 1.0, 30.0)
			rp.next_mag = rp.prior_mag
		elif p_prior != null and p_next != null:
			# Punto intermedio: curvatura continua Bezier suave en 3D
			var v_in = (rp.global_position - p_prior.global_position)
			var v_out = (p_next.global_position - rp.global_position)
			var d_in = v_in.normalized()
			var d_out = v_out.normalized()
			
			# Tangente angular continua (bisectriz suave de entrada y salida)
			t_dir = (d_in + d_out).normalized()
			if t_dir.length_squared() < 0.001:
				t_dir = d_out
				
			var dist_prev = v_in.length()
			var dist_next = v_out.length()
			
			# Factor de curvatura adaptativo: en curvas fluidas (~0.36) genera arcos Bezier perfectos
			# y en giros más pronunciados modera la magnitud armónicamente para evitar sobregiro/S-bend
			var dot = clamp(d_in.dot(d_out), -1.0, 1.0)
			var turn_factor = lerp(0.18, 0.36, (dot + 1.0) * 0.5)
			
			rp.prior_mag = clamp(dist_prev * turn_factor, 1.0, 30.0)
			rp.next_mag = clamp(dist_next * turn_factor, 1.0, 30.0)
		else:
			# Punto aislado no conectado
			continue
			
		var fwd = Vector3(t_dir.x, 0.0, t_dir.z).normalized()
		if fwd.length_squared() > 0.001:
			var up_ref = Vector3.UP
			if absf(fwd.dot(up_ref)) > 0.96:
				up_ref = Vector3.FORWARD
			rp.global_transform.basis = Basis.looking_at(-fwd, up_ref)
			if rp.has_meta("peralte_grados"):
				rp.rotation_degrees.z = float(rp.get_meta("peralte_grados", 0.0))

func _ajustar_altura_a_terreno(pos: Vector3) -> Vector3:
	if controlador_terreno and is_instance_valid(controlador_terreno):
		var h = (controlador_terreno as ControladorTerreno).obtener_altura(pos)
		return Vector3(pos.x, h + elevacion_sobre_terreno, pos.z)
	return Vector3(pos.x, pos.y + elevacion_sobre_terreno, pos.z)

func _crear_nodo_road_point(pos_mundo: Vector3) -> RoadPoint:
	var rp := RoadPoint.new()
	rp.name = "RP_%d" % (_puntos_creados.size() + 1)
	road_container.add_child(rp)
	rp.container = road_container
	rp.global_position = pos_mundo
	_configurar_tipo_via(rp)
	_puntos_creados.append(rp)
	return rp

func conectar_dos_puntos(rp_a: RoadPoint, rp_b: RoadPoint) -> bool:
	if not is_instance_valid(rp_a) or not is_instance_valid(rp_b):
		return false
	if rp_a == rp_b:
		return false
	if not road_container or rp_a.container != road_container or rp_b.container != road_container:
		return false
		
	var dir_a: int = -1
	if rp_a.is_bare_edge(RoadPoint.PointInit.NEXT):
		dir_a = RoadPoint.PointInit.NEXT
	elif rp_a.is_bare_edge(RoadPoint.PointInit.PRIOR):
		dir_a = RoadPoint.PointInit.PRIOR
		
	var dir_b: int = -1
	if rp_b.is_bare_edge(RoadPoint.PointInit.PRIOR):
		dir_b = RoadPoint.PointInit.PRIOR
	elif rp_b.is_bare_edge(RoadPoint.PointInit.NEXT):
		dir_b = RoadPoint.PointInit.NEXT
		
	# Si alguno no tiene extremos libres directos, buscar el extremo libre más cercano en su rama
	if dir_a == -1:
		var alt_a = _buscar_extremo_libre_cercano(rp_a, rp_b)
		if alt_a:
			rp_a = alt_a
			dir_a = RoadPoint.PointInit.NEXT if rp_a.is_bare_edge(RoadPoint.PointInit.NEXT) else RoadPoint.PointInit.PRIOR
	if dir_b == -1:
		var alt_b = _buscar_extremo_libre_cercano(rp_b, rp_a)
		if alt_b:
			rp_b = alt_b
			dir_b = RoadPoint.PointInit.PRIOR if rp_b.is_bare_edge(RoadPoint.PointInit.PRIOR) else RoadPoint.PointInit.NEXT
			
	if dir_a != -1 and dir_b != -1 and rp_a != rp_b:
		var ok = rp_a.connect_roadpoint(dir_a, rp_b, dir_b)
		if ok:
			if road_container:
				road_container.update_edges()
			_actualizar_orientaciones_y_curvaturas()
			road_container.rebuild_segments(true)
			nivelar_terreno_bajo_carreteras()
			carretera_actualizada.emit()
			actualizar_seleccionadores_puntos()
			return true
			
	return false

func _buscar_extremo_libre_cercano(origen: RoadPoint, ignorar: RoadPoint = null) -> RoadPoint:
	var mejor_rp: RoadPoint = null
	var menor_dist: float = 999999.0
	for rp in _puntos_creados:
		if not is_instance_valid(rp) or rp == origen or rp == ignorar:
			continue
		if rp.is_bare_edge(RoadPoint.PointInit.NEXT) or rp.is_bare_edge(RoadPoint.PointInit.PRIOR):
			var d = rp.global_position.distance_squared_to(origen.global_position)
			if d < menor_dist:
				menor_dist = d
				mejor_rp = rp
	return mejor_rp

# ── DETECCIÓN E INTERSECCIÓN PROCEDURAL DE CARRETERAS ──────────────────

## Calcula la intersección matemática 2D en el plano XZ entre dos segmentos: (p1 -> p2) y (p3 -> p4)
func _interseccion_segmentos_2d(p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3) -> Dictionary:
	var x1 = p1.x
	var z1 = p1.z
	var x2 = p2.x
	var z2 = p2.z
	var x3 = p3.x
	var z3 = p3.z
	var x4 = p4.x
	var z4 = p4.z

	var denom = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
	if absf(denom) < 0.00001:
		return {"hay_interseccion": false, "punto": Vector3.ZERO, "t": 0.0, "u": 0.0}

	var t = ((x1 - x3) * (z3 - z4) - (z1 - z3) * (x3 - x4)) / denom
	var u = -((x1 - x2) * (z1 - z3) - (z1 - z2) * (x1 - x3)) / denom

	if t >= -0.001 and t <= 1.001 and u >= -0.001 and u <= 1.001:
		var pos_x = x1 + t * (x2 - x1)
		var pos_z = z1 + t * (z2 - z1)
		var pos_y = lerpf(p1.y, p2.y, t)
		return {
			"hay_interseccion": true,
			"punto": Vector3(pos_x, pos_y, pos_z),
			"t": clampf(t, 0.0, 1.0),
			"u": clampf(u, 0.0, 1.0)
		}

	return {"hay_interseccion": false, "punto": Vector3.ZERO, "t": t, "u": u}

## Desconecta limpiamente dos RoadPoints que comparten un tramo
func _desconectar_puntos(rp_a: RoadPoint, rp_b: RoadPoint) -> bool:
	if not is_instance_valid(rp_a) or not is_instance_valid(rp_b):
		return false
	var dir_a: int = -1
	var dir_b: int = -1
	
	if rp_a.next_pt_init and rp_a.get_node_or_null(rp_a.next_pt_init) == rp_b:
		dir_a = RoadPoint.PointInit.NEXT
	elif rp_a.prior_pt_init and rp_a.get_node_or_null(rp_a.prior_pt_init) == rp_b:
		dir_a = RoadPoint.PointInit.PRIOR
		
	if rp_b.next_pt_init and rp_b.get_node_or_null(rp_b.next_pt_init) == rp_a:
		dir_b = RoadPoint.PointInit.NEXT
	elif rp_b.prior_pt_init and rp_b.get_node_or_null(rp_b.prior_pt_init) == rp_a:
		dir_b = RoadPoint.PointInit.PRIOR
		
	if dir_a != -1 and dir_b != -1:
		return rp_a.disconnect_roadpoint(dir_a, dir_b)
	return false

## Crea y configura un ramal (RoadPoint) perteneciente a una RoadIntersection apuntando hacia un objetivo exterior
func _obtener_ancho_total_via(tipo: TipoVia) -> float:
	match tipo:
		TipoVia.AVENIDA_4_VIAS:
			return 4.0 * 3.5 + 2.0 * 1.2 # 16.4m
		TipoVia.AUTOPISTA_6_VIAS:
			return 6.0 * 3.6 + 2.0 * 1.8 # 25.2m
		TipoVia.TROCHA:
			return 2.0 * 2.8 + 2.0 * 0.9 # 7.4m
		_:
			return 2.0 * 3.6 + 2.0 * 0.8 # 8.8m

## Calcula la distancia mínima matemáticamente necesaria para que los hombros/bordes de dos vías en ángulo agudo jamás colisionen ni inviertan su polígono
func _calcular_distancia_segura_ramales(dir1: Vector3, dir2: Vector3, ancho_1: float, ancho_2: float) -> float:
	var d1 = Vector3(dir1.x, 0, dir1.z).normalized()
	var d2 = Vector3(dir2.x, 0, dir2.z).normalized()
	var dot = clampf(d1.dot(d2), -1.0, 1.0)
	var ang_rad = acos(dot)
	
	# Ángulo agudo entre las dos rectas
	var theta = ang_rad
	if theta > PI * 0.5:
		theta = PI - theta
		
	var half_theta = maxf(theta * 0.5, deg_to_rad(14.0)) # Mínimo ~14° para evitar división por cero
	var max_half_width = maxf(ancho_1, ancho_2) * 0.5
	
	# Geometría del cruce: distancia al vértice exterior + margen holgado para las líneas de parada
	var dist_teorica = (max_half_width / sin(half_theta)) + 3.0
	return clampf(dist_teorica, 12.0, 26.0)

## Crea y configura un ramal (RoadPoint) perteneciente a una RoadIntersection apuntando exactamente a lo largo de dir_forzada o hacia un objetivo
func _crear_brazo_hacia(inter: RoadIntersection, target_world: Vector3, dist: float, tipo: TipoVia, dir_forzada: Vector3 = Vector3.ZERO) -> RoadPoint:
	var norm_dir = dir_forzada
	if norm_dir.length_squared() < 0.001:
		var dir_out = (target_world - inter.global_position)
		dir_out.y = 0.0
		norm_dir = dir_out.normalized()
	if norm_dir.length_squared() < 0.001:
		norm_dir = Vector3.FORWARD
		
	var pos_brazo = _ajustar_altura_a_terreno(inter.global_position + norm_dir * dist)
	
	var rp := RoadPoint.new()
	rp.name = "%s_B%d" % [inter.name, inter.edge_points.size() + 1]
	rp.container = road_container
	road_container.add_child(rp)
	rp.global_position = pos_brazo
	
	var up_ref = Vector3.UP
	if absf(norm_dir.dot(up_ref)) > 0.96:
		up_ref = Vector3.FORWARD
	rp.global_transform.basis = Basis.looking_at(-norm_dir, up_ref)
	
	_aplicar_tipo_via_a_punto(rp, tipo)
	
	inter.add_branch(rp)
	_puntos_creados.append(rp)
	return rp

## Busca si la trayectoria (p_inicio -> p_fin) cruza algún tramo (RoadSegment) existente en la escena
func buscar_cruce_entre_tramos(p_inicio: Vector3, p_fin: Vector3, ignorar_punto: RoadPoint = null, ignorar_destino: RoadPoint = null) -> Dictionary:
	var res_default = {"hay_cruce": false}
	if not road_container or not is_instance_valid(road_container):
		return res_default
		
	var segmentos = road_container.get_segments()
	if segmentos.is_empty():
		return res_default
		
	var mejor_cruce: Dictionary = res_default
	var menor_t: float = 999.0
	
	for obj in segmentos:
		var seg = obj as RoadSegment
		if not is_instance_valid(seg):
			continue
		var sp = seg.start_point
		var ep = seg.end_point
		if not is_instance_valid(sp) or not is_instance_valid(ep):
			continue
			
		# Ignorar segmentos que conectan directamente con los puntos de origen/fin
		if sp == ignorar_punto or ep == ignorar_punto:
			continue
		if ignorar_destino != null and (sp == ignorar_destino or ep == ignorar_destino):
			continue
			
		var inter_detectada := false
		var punto_encontrado := Vector3.ZERO
		var t_val := 0.0
		
		# 1. Probar intersección directa entre los extremos del tramo (rápido y exacto)
		var test_directo = _interseccion_segmentos_2d(p_inicio, p_fin, sp.global_position, ep.global_position)
		if test_directo.hay_interseccion:
			inter_detectada = true
			punto_encontrado = test_directo.punto
			t_val = test_directo.t
		elif seg.curve and seg.curve.get_baked_length() > 6.0:
			# 2. Si es una curva pronunciada y el acorde directo no intersectó, evaluar a lo largo de la curva
			var curve = seg.curve
			var total_len = curve.get_baked_length()
			var pasos = clampi(int(total_len / 5.0), 3, 16)
			var dt = total_len / float(pasos)
			var p_anterior = seg.to_global(curve.sample_baked(0.0))
			for i in range(1, pasos + 1):
				var p_actual = seg.to_global(curve.sample_baked(i * dt))
				var test = _interseccion_segmentos_2d(p_inicio, p_fin, p_anterior, p_actual)
				if test.hay_interseccion:
					inter_detectada = true
					punto_encontrado = test.punto
					t_val = test.t
					break
				p_anterior = p_actual
				
		if inter_detectada:
			# Validar distancias mínimas para no crear cruces empalmados sobre puntos existentes
			var d_sp = punto_encontrado.distance_to(sp.global_position)
			var d_ep = punto_encontrado.distance_to(ep.global_position)
			var d_orig = punto_encontrado.distance_to(p_inicio)
			var d_fin = punto_encontrado.distance_to(p_fin)
			
			if d_sp > 6.0 and d_ep > 6.0 and d_orig > 6.0:
				if t_val < menor_t:
					menor_t = t_val
					var es_t = (d_fin < 6.5)
					mejor_cruce = {
						"hay_cruce": true,
						"punto_cruce": punto_encontrado,
						"segmento": seg,
						"start_point": sp,
						"end_point": ep,
						"es_cruce_t": es_t,
						"t": t_val
					}
					
	return mejor_cruce

## Genera automáticamente un RoadIntersection procedural dividiendo el tramo atravesado y conectando todos los ramales
func crear_cruce_automatico_en_interseccion(p_origen: RoadPoint, pos_destino_mundo: Vector3, datos_cruce: Dictionary, punto_destino_existente: RoadPoint = null) -> RoadIntersection:
	if not road_container or not datos_cruce.get("hay_cruce", false):
		return null
		
	var pos_cruce: Vector3 = _ajustar_altura_a_terreno(datos_cruce.punto_cruce)
	var sp: RoadPoint = datos_cruce.start_point
	var ep: RoadPoint = datos_cruce.end_point
	
	if not is_instance_valid(sp) or not is_instance_valid(ep) or not is_instance_valid(p_origen):
		return null
		
	var tipo_sp = _obtener_tipo_via_de_punto(sp)
	var tipo_ep = _obtener_tipo_via_de_punto(ep)
	var tipo_origen = _obtener_tipo_via_de_punto(p_origen)
	
	# 1. Dirección limpia y colineal de la vía atravesada (Vía 1: sp -> ep)
	var dir1 = (ep.global_position - sp.global_position)
	dir1.y = 0.0
	var d1 = dir1.normalized()
	if d1.length_squared() < 0.001:
		d1 = Vector3.FORWARD
		
	# 2. Dirección limpia y colineal de la nueva vía que cruza (Vía 2: p_origen -> destino)
	var pos_ref_dest = punto_destino_existente.global_position if punto_destino_existente != null else pos_destino_mundo
	var dir2 = (pos_ref_dest - p_origen.global_position)
	dir2.y = 0.0
	var d2 = dir2.normalized()
	if d2.length_squared() < 0.001:
		d2 = Vector3.RIGHT
		
	# 3. Calcular distancia mínima matemáticamente segura para que los hombros/bordes nunca colisionen
	var ancho_1 = _obtener_ancho_total_via(tipo_sp)
	var ancho_2 = _obtener_ancho_total_via(tipo_origen)
	var r_seguro = _calcular_distancia_segura_ramales(d1, d2, ancho_1, ancho_2)
	
	var dist_a_sp = pos_cruce.distance_to(sp.global_position)
	var dist_a_ep = pos_cruce.distance_to(ep.global_position)
	var dist_a_orig = pos_cruce.distance_to(p_origen.global_position)
	
	# Las ramas no deben sobrepasar el 65% del espacio disponible hacia los extremos existentes
	var r_sp = clampf(r_seguro, 8.0, maxf(dist_a_sp * 0.65, 8.0))
	var r_ep = clampf(r_seguro, 8.0, maxf(dist_a_ep * 0.65, 8.0))
	var r_orig = clampf(r_seguro, 8.0, maxf(dist_a_orig * 0.65, 8.0))
	var r_dest = r_seguro
	
	# 4. Desconectar los dos puntos del tramo existente atravesado
	_desconectar_puntos(sp, ep)
	
	# 5. Instanciar el nodo RoadIntersection procedural
	var inter := RoadIntersection.new()
	inter.name = "Cruce_Auto_%d" % (_puntos_creados.size() + 1)
	inter.container = road_container
	road_container.add_child(inter)
	inter.global_position = pos_cruce
	
	# 6. Ramal hacia sp (-d1) y conectar
	var b_sp = _crear_brazo_hacia(inter, sp.global_position, r_sp, tipo_sp, -d1)
	conectar_dos_puntos(b_sp, sp)
	
	# 7. Ramal hacia ep (+d1) y conectar
	var b_ep = _crear_brazo_hacia(inter, ep.global_position, r_ep, tipo_ep, d1)
	conectar_dos_puntos(b_ep, ep)
	
	# 8. Ramal hacia p_origen (-d2) y conectar
	var b_orig = _crear_brazo_hacia(inter, p_origen.global_position, r_orig, tipo_origen, -d2)
	conectar_dos_puntos(b_orig, p_origen)
	
	# 9. Ramal 4 o terminación
	var es_t = datos_cruce.get("es_cruce_t", false) and (punto_destino_existente == null)
	var dist_a_dest_clic = pos_cruce.distance_to(pos_destino_mundo)
	
	if punto_destino_existente != null and is_instance_valid(punto_destino_existente):
		var dist_a_dest_pt = pos_cruce.distance_to(punto_destino_existente.global_position)
		var r_dest_pt = clampf(r_seguro, 8.0, maxf(dist_a_dest_pt * 0.65, 8.0))
		var tipo_dest = _obtener_tipo_via_de_punto(punto_destino_existente)
		var b_dest = _crear_brazo_hacia(inter, punto_destino_existente.global_position, r_dest_pt, tipo_dest, d2)
		conectar_dos_puntos(b_dest, punto_destino_existente)
		_ultimo_road_point = punto_destino_existente
	elif not es_t:
		# Ramal saliente hacia adelante (+d2)
		var b_dest = _crear_brazo_hacia(inter, pos_cruce + d2 * r_dest, r_dest, tipo_via_actual, d2)
		
		# Si el usuario hizo clic lo suficientemente lejos (más de r_seguro + 8m), crear el punto intermedio.
		# Si hizo clic justo pasando el cruce (como suele ocurrir al cruzar vías), b_dest es el punto activo
		# para seguir trazando fluidamente sin crear muñones de 2 metros.
		if dist_a_dest_clic >= (r_dest + 8.0):
			var rp_dest = _crear_nodo_road_point(_ajustar_altura_a_terreno(pos_destino_mundo))
			conectar_dos_puntos(b_dest, rp_dest)
			_ultimo_road_point = rp_dest
			_historial_acciones.append(rp_dest)
		else:
			_ultimo_road_point = b_dest
			_historial_acciones.append(b_dest)
	else:
		_ultimo_road_point = null
		
	_actualizar_orientaciones_y_curvaturas()
	road_container.rebuild_segments(true)
	nivelar_terreno_bajo_carreteras()
	carretera_actualizada.emit()
	actualizar_seleccionadores_puntos()
	return inter

func ejecutar_paso_conexion(pos_mundo: Vector3) -> Dictionary:
	var punto = buscar_punto_cercano_snap(pos_mundo, 6.5, false)
	if not punto:
		return {"exito": false, "mensaje": "Acércate a un extremo o punto de vía para conectar"}
		
	if _punto_origen_conexion == null:
		_punto_origen_conexion = punto
		if _marcador_seleccion_conexion:
			_marcador_seleccion_conexion.global_position = punto.global_position + Vector3(0, 0.15, 0)
			_marcador_seleccion_conexion.visible = true
		return {
			"exito": true,
			"mensaje": "Primer extremo seleccionado. Ahora acércate a la segunda vía para unirlas",
			"origen_fijado": true
		}
	else:
		if punto == _punto_origen_conexion:
			return {"exito": false, "mensaje": "Selecciona un punto de vía diferente"}
			
		var origen = _punto_origen_conexion
		
		# Comprobar si entre origen y punto hay un tramo de vía intermedio que se cruza
		var datos_cruce = buscar_cruce_entre_tramos(origen.global_position, punto.global_position, origen, punto)
		var ok = false
		var creo_cruce = false
		
		if datos_cruce.get("hay_cruce", false):
			var inter = crear_cruce_automatico_en_interseccion(origen, punto.global_position, datos_cruce, punto)
			if inter:
				ok = true
				creo_cruce = true
		else:
			ok = conectar_dos_puntos(origen, punto)
		
		_punto_origen_conexion = null
		if _marcador_seleccion_conexion:
			_marcador_seleccion_conexion.visible = false
		if _linea_instance:
			_linea_instance.visible = false
			
		if creo_cruce:
			return {"exito": true, "mensaje": "¡Cruce creado automáticamente en la intersección!", "conectado": true, "cruce_creado": true}
		elif ok:
			return {"exito": true, "mensaje": "¡Vías conectadas exitosamente!", "conectado": true}
		else:
			return {"exito": false, "mensaje": "No se pudieron conectar las vías (ambos extremos podrían estar ocupados)"}

func agregar_punto_carretera(pos_mundo: Vector3) -> RoadPoint:
	if not road_container:
		return null
		
	var punto_snap = buscar_punto_cercano_snap(pos_mundo, 6.0, true)
	
	# Si no hay tramo activo y hace clic en un extremo existente, continuar desde ahí
	if _ultimo_road_point == null:
		if punto_snap:
			_ultimo_road_point = punto_snap
			carretera_actualizada.emit()
			return punto_snap
	else:
		# Si hay tramo activo y hace clic cerca de un extremo existente que no sea el mismo punto actual
		if punto_snap and punto_snap != _ultimo_road_point:
			# Verificar si la conexión cruza algún tramo intermedio antes de acoplar
			var datos_cruce_snap = buscar_cruce_entre_tramos(_ultimo_road_point.global_position, punto_snap.global_position, _ultimo_road_point, punto_snap)
			if datos_cruce_snap.get("hay_cruce", false):
				var inter = crear_cruce_automatico_en_interseccion(_ultimo_road_point, punto_snap.global_position, datos_cruce_snap, punto_snap)
				if inter:
					return _ultimo_road_point
			
			var conectado = conectar_dos_puntos(_ultimo_road_point, punto_snap)
			if conectado:
				_ultimo_road_point = punto_snap
				return punto_snap

	# Verificar si el nuevo tramo trazado atraviesa alguna vía existente en su camino
	if _ultimo_road_point != null and is_instance_valid(_ultimo_road_point):
		var datos_cruce = buscar_cruce_entre_tramos(_ultimo_road_point.global_position, pos_mundo, _ultimo_road_point)
		if datos_cruce.get("hay_cruce", false):
			var inter = crear_cruce_automatico_en_interseccion(_ultimo_road_point, pos_mundo, datos_cruce)
			if inter:
				return _ultimo_road_point

	var target_pos := _ajustar_altura_a_terreno(pos_mundo)
	var offset_prev: float = 0.0
	if _ultimo_road_point != null and is_instance_valid(_ultimo_road_point):
		offset_prev = float(_ultimo_road_point.get_meta("offset_y", 0.0))
		target_pos.y += offset_prev
	var rp := _crear_nodo_road_point(target_pos)
	if absf(offset_prev) > 0.01:
		rp.set_meta("offset_y", offset_prev)
	
	if _ultimo_road_point != null and is_instance_valid(_ultimo_road_point):
		_actualizar_orientaciones_y_curvaturas()
		var dir_origen = RoadPoint.PointInit.NEXT
		if _ultimo_road_point.is_bare_edge(RoadPoint.PointInit.NEXT):
			dir_origen = RoadPoint.PointInit.NEXT
		elif _ultimo_road_point.is_bare_edge(RoadPoint.PointInit.PRIOR):
			dir_origen = RoadPoint.PointInit.PRIOR
			
		_ultimo_road_point.connect_roadpoint(dir_origen, rp, RoadPoint.PointInit.PRIOR)
		_actualizar_orientaciones_y_curvaturas()
		road_container.rebuild_segments(true)
		nivelar_terreno_bajo_carreteras()
	else:
		# Primer punto de la vía
		rp.global_transform.basis = Basis.IDENTITY
		
	_ultimo_road_point = rp
	_historial_acciones.append(rp)
	
	carretera_actualizada.emit()
	actualizar_seleccionadores_puntos()
	return rp

func crear_cruce(pos_mundo: Vector3, tipo: String = "cruce_4", rotacion_grados: float = 0.0) -> RoadIntersection:
	if not road_container:
		return null
		
	var target_pos := _ajustar_altura_a_terreno(pos_mundo)
	
	var inter := RoadIntersection.new()
	inter.name = "Cruce_%d" % (_puntos_creados.size() + 1)
	inter.container = road_container
	road_container.add_child(inter)
	inter.global_position = target_pos
	inter.rotation_degrees.y = rotacion_grados
	
	var rot_rad = deg_to_rad(rotacion_grados)
	var dist_brazo = clampf(_obtener_ancho_total_via(tipo_via_actual) * 1.4, 13.0, 24.0)
	
	var offsets: Array[Vector3] = []
	if tipo == "cruce_t":
		offsets = [
			Vector3(0, 0, -dist_brazo).rotated(Vector3.UP, rot_rad), # Recto adelante
			Vector3(dist_brazo, 0, 0).rotated(Vector3.UP, rot_rad),  # Lateral derecha
			Vector3(-dist_brazo, 0, 0).rotated(Vector3.UP, rot_rad) # Lateral izquierda
		]
	else: # cruce_4
		offsets = [
			Vector3(0, 0, -dist_brazo).rotated(Vector3.UP, rot_rad), # Norte
			Vector3(0, 0, dist_brazo).rotated(Vector3.UP, rot_rad),  # Sur
			Vector3(dist_brazo, 0, 0).rotated(Vector3.UP, rot_rad),  # Este
			Vector3(-dist_brazo, 0, 0).rotated(Vector3.UP, rot_rad) # Oeste
		]
		
	for i in range(offsets.size()):
		var p_pos = _ajustar_altura_a_terreno(target_pos + offsets[i])
		var rp := RoadPoint.new()
		rp.name = "%s_P%d" % [inter.name, i + 1]
		rp.container = road_container
		road_container.add_child(rp)
		rp.global_position = p_pos
		var dir_out = (p_pos - target_pos)
		dir_out.y = 0.0
		if dir_out.length_squared() > 0.001:
			var fwd = dir_out.normalized()
			var up_ref = Vector3.UP
			if absf(fwd.dot(up_ref)) > 0.96:
				up_ref = Vector3.FORWARD
			rp.global_transform.basis = Basis.looking_at(-fwd, up_ref)
		_configurar_tipo_via(rp)
		
		inter.add_branch(rp)
		_puntos_creados.append(rp)
		
	_actualizar_orientaciones_y_curvaturas()
	road_container.rebuild_segments(true)
	nivelar_terreno_bajo_carreteras()
	carretera_actualizada.emit()
	actualizar_seleccionadores_puntos()
	return inter

# ── GESTIÓN DE SELECCIONADORES Y MODIFICACIÓN DE CARRETERAS ──────────

func actualizar_seleccionadores_puntos() -> void:
	if not road_container or not is_instance_valid(road_container):
		return
	if not _contenedor_seleccionadores_puntos:
		return
		
	var rps: Array = road_container.get_roadpoints()
	var puntos_validos: Dictionary = {}
	
	for obj in rps:
		var rp = obj as RoadPoint
		if not is_instance_valid(rp) or rp.is_queued_for_deletion():
			continue
		puntos_validos[rp] = true
		
		var marker: Node3D = _dict_marcadores_puntos.get(rp, null)
		if not is_instance_valid(marker):
			marker = _crear_instancia_marcador_punto()
			_contenedor_seleccionadores_puntos.add_child(marker)
			_dict_marcadores_puntos[rp] = marker
			
		marker.global_position = rp.global_position + Vector3(0, 0.15, 0)
		
		# Si este punto está actualmente seleccionado, el marcador dedicado lo resalta
		if rp == punto_carretera_seleccionado:
			marker.visible = false
		else:
			marker.visible = true
			
	# Limpiar marcadores obsoletos
	var a_borrar: Array = []
	for rp in _dict_marcadores_puntos.keys():
		if not puntos_validos.has(rp) or not is_instance_valid(rp):
			var m = _dict_marcadores_puntos[rp]
			if is_instance_valid(m):
				m.queue_free()
			a_borrar.append(rp)
			
	for rp in a_borrar:
		_dict_marcadores_puntos.erase(rp)

func buscar_punto_carretera_cercano(pos_mundo: Vector3, radio_max: float = 7.0) -> RoadPoint:
	if not road_container or not is_instance_valid(road_container):
		return null
	var rps = road_container.get_roadpoints()
	var mejor_rp: RoadPoint = null
	var menor_dist = radio_max
	for obj in rps:
		var rp = obj as RoadPoint
		if not is_instance_valid(rp) or rp.is_queued_for_deletion():
			continue
		var dist_2d = Vector2(rp.global_position.x, rp.global_position.z).distance_to(Vector2(pos_mundo.x, pos_mundo.z))
		if dist_2d < menor_dist:
			menor_dist = dist_2d
			mejor_rp = rp
	return mejor_rp

func seleccionar_punto_carretera(rp: RoadPoint) -> void:
	if punto_carretera_seleccionado == rp and rp != null:
		return
		
	if is_instance_valid(cruce_seleccionado):
		deseleccionar_cruce()
		
	punto_carretera_seleccionado = rp
	if is_instance_valid(rp):
		if _marcador_punto_seleccionado:
			_marcador_punto_seleccionado.global_position = rp.global_position + Vector3(0, 0.2, 0)
			_marcador_punto_seleccionado.visible = true
	else:
		if _marcador_punto_seleccionado:
			_marcador_punto_seleccionado.visible = false
			
	actualizar_seleccionadores_puntos()
	punto_carretera_seleccionado_cambiado.emit(rp)

func deseleccionar_todo() -> void:
	deseleccionar_punto_carretera()
	deseleccionar_cruce()
	deseleccionar_ramal_cruce()

func deseleccionar_punto_carretera() -> void:
	if punto_carretera_seleccionado == null:
		return
	punto_carretera_seleccionado = null
	if _marcador_punto_seleccionado:
		_marcador_punto_seleccionado.visible = false
	actualizar_seleccionadores_puntos()
	punto_carretera_seleccionado_cambiado.emit(null)

func mover_punto_carretera(rp: RoadPoint, nueva_pos_mundo: Vector3, es_arrastre_temporal: bool = false) -> void:
	if not is_instance_valid(rp):
		return
		
	var target_pos = _ajustar_altura_a_terreno(nueva_pos_mundo)
	var offset_y = float(rp.get_meta("offset_y", 0.0))
	target_pos.y += offset_y
	rp.global_position = target_pos
	
	if is_instance_valid(_marcador_punto_seleccionado) and rp == punto_carretera_seleccionado:
		_marcador_punto_seleccionado.global_position = target_pos + Vector3(0, 0.2, 0)
	if _dict_marcadores_puntos.has(rp) and is_instance_valid(_dict_marcadores_puntos[rp]):
		_dict_marcadores_puntos[rp].global_position = target_pos + Vector3(0, 0.15, 0)
		
	# Identificar si es rama de un cruce
	var inter: RoadIntersection = null
	if not rp.prior_pt_init.is_empty():
		var n = rp.get_node_or_null(rp.prior_pt_init)
		if is_instance_valid(n) and n.has_method("is_road_intersection"):
			inter = n as RoadIntersection
	if inter == null and not rp.next_pt_init.is_empty():
		var n = rp.get_node_or_null(rp.next_pt_init)
		if is_instance_valid(n) and n.has_method("is_road_intersection"):
			inter = n as RoadIntersection
			
	_actualizar_orientaciones_y_curvaturas()
	
	if es_arrastre_temporal:
		rp.emit_transform(true)
		if inter and is_instance_valid(inter):
			inter.emit_transform()
	else:
		rp.emit_transform(false)
		if inter and is_instance_valid(inter):
			inter.emit_transform()
		if road_container:
			road_container.rebuild_segments(true)
		nivelar_terreno_bajo_carreteras()
		actualizar_seleccionadores_puntos()
		if equipamiento_controller and equipamiento_controller.has_method("actualizar_puentes_y_tuneles_automaticos"):
			equipamiento_controller.actualizar_puentes_y_tuneles_automaticos()
		carretera_actualizada.emit()

func eliminar_punto_carretera_seleccionado() -> bool:
	if not is_instance_valid(punto_carretera_seleccionado):
		return false
	var rp = punto_carretera_seleccionado
	deseleccionar_punto_carretera()
	
	var p_prior: RoadPoint = null
	var p_next: RoadPoint = null
	
	if not rp.prior_pt_init.is_empty():
		var n = rp.get_node_or_null(rp.prior_pt_init)
		if is_instance_valid(n) and n is RoadPoint:
			p_prior = n as RoadPoint
	if not rp.next_pt_init.is_empty():
		var n = rp.get_node_or_null(rp.next_pt_init)
		if is_instance_valid(n) and n is RoadPoint:
			p_next = n as RoadPoint
			
	if rp.is_prior_connected():
		rp.disconnect_roadpoint(RoadPoint.PointInit.PRIOR, RoadPoint.PointInit.NEXT)
	if rp.is_next_connected():
		rp.disconnect_roadpoint(RoadPoint.PointInit.NEXT, RoadPoint.PointInit.PRIOR)
		
	# Si unía dos tramos, reconectar directamente prior y next
	if is_instance_valid(p_prior) and is_instance_valid(p_next) and p_prior != p_next:
		conectar_dos_puntos(p_prior, p_next)
		
	var idx = _puntos_creados.find(rp)
	if idx != -1:
		_puntos_creados.remove_at(idx)
	if _ultimo_road_point == rp:
		_ultimo_road_point = _puntos_creados.back() if not _puntos_creados.is_empty() else null
		
	rp.queue_free()
	
	_actualizar_orientaciones_y_curvaturas()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	nivelar_terreno_bajo_carreteras()
	actualizar_seleccionadores_puntos()
	carretera_actualizada.emit()
	return true

func cambiar_tipo_via_punto_seleccionado(tipo: TipoVia) -> void:
	if not is_instance_valid(punto_carretera_seleccionado):
		return
	_aplicar_tipo_via_a_punto(punto_carretera_seleccionado, tipo)
	_actualizar_orientaciones_y_curvaturas()
	if road_container:
		road_container.rebuild_segments(true)
	carretera_actualizada.emit()

func fijar_peralte_punto_seleccionado(grados: float) -> void:
	if not is_instance_valid(punto_carretera_seleccionado):
		return
	var rp = punto_carretera_seleccionado
	rp.rotation_degrees.z = grados
	rp.set_meta("peralte_grados", grados)
	
	# Compensar elevación para que el borde peraltado no se hunda en el terreno
	var ancho = _obtener_ancho_via_punto(rp)
	var caida_borde = absf(sin(deg_to_rad(grados))) * (ancho * 0.5)
	var alt_suelo = 0.0
	if controlador_terreno:
		alt_suelo = (controlador_terreno as ControladorTerreno).obtener_altura(rp.global_position)
	var offset_y = float(rp.get_meta("offset_y", 0.0))
	rp.global_position.y = alt_suelo + elevacion_sobre_terreno + caida_borde + offset_y
	
	rp.emit_transform(false)
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	nivelar_terreno_bajo_carreteras()
	if equipamiento_controller and equipamiento_controller.has_method("actualizar_puentes_y_tuneles_automaticos"):
		equipamiento_controller.actualizar_puentes_y_tuneles_automaticos()
	carretera_actualizada.emit()

func establecer_altura_punto_seleccionado(nuevo_offset_y: float) -> void:
	var rp: RoadPoint = punto_carretera_seleccionado
	if not is_instance_valid(rp):
		rp = _ultimo_road_point
	if not is_instance_valid(rp):
		return
	rp.set_meta("offset_y", nuevo_offset_y)
	var pos_actual: Vector3 = rp.global_position if rp.is_inside_tree() else rp.position
	var alt_suelo = 0.0
	if controlador_terreno:
		alt_suelo = (controlador_terreno as ControladorTerreno).obtener_altura(pos_actual)
	var peralte_deg = float(rp.get_meta("peralte_grados", 0.0))
	var caida_borde = absf(sin(deg_to_rad(peralte_deg))) * (_obtener_ancho_via_punto(rp) * 0.5)
	
	var target_y = alt_suelo + elevacion_sobre_terreno + caida_borde + nuevo_offset_y
	if rp.is_inside_tree():
		rp.global_position.y = target_y
	else:
		rp.position.y = target_y
		
	if is_instance_valid(_marcador_punto_seleccionado) and rp == punto_carretera_seleccionado:
		if _marcador_punto_seleccionado.is_inside_tree() and rp.is_inside_tree():
			_marcador_punto_seleccionado.global_position = rp.global_position + Vector3(0, 0.2, 0)
		else:
			_marcador_punto_seleccionado.position = rp.position + Vector3(0, 0.2, 0)
	if _dict_marcadores_puntos.has(rp) and is_instance_valid(_dict_marcadores_puntos[rp]):
		var m_pt: Node3D = _dict_marcadores_puntos[rp]
		if m_pt.is_inside_tree() and rp.is_inside_tree():
			m_pt.global_position = rp.global_position + Vector3(0, 0.15, 0)
		else:
			m_pt.position = rp.position + Vector3(0, 0.15, 0)
			
	_actualizar_orientaciones_y_curvaturas()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	if absf(nuevo_offset_y) <= 0.8:
		nivelar_terreno_bajo_carreteras()
	actualizar_seleccionadores_puntos()
	if equipamiento_controller and equipamiento_controller.has_method("actualizar_puentes_y_tuneles_automaticos"):
		equipamiento_controller.actualizar_puentes_y_tuneles_automaticos()
	carretera_actualizada.emit()

func obtener_datos_punto_seleccionado() -> Dictionary:
	if not is_instance_valid(punto_carretera_seleccionado):
		return {}
	var rp = punto_carretera_seleccionado
	var tipo = _obtener_tipo_via_de_punto(rp)
	return {
		"nombre": rp.name,
		"tipo": tipo,
		"posicion": rp.global_position,
		"peralte": rp.get_meta("peralte_grados", rp.rotation_degrees.z),
		"elevacion": float(rp.get_meta("offset_y", 0.0))
	}

# ── OPCIONES Y EDICIÓN PROCEDURAL DE CRUCES ──────────────────────────

func buscar_cruce_cercano(pos_mundo: Vector3, radio_max: float = 14.0) -> RoadIntersection:
	if not road_container or not is_instance_valid(road_container):
		return null
	var intersections = road_container.get_intersections()
	var mejor_inter: RoadIntersection = null
	var menor_dist: float = 999999.0
	for obj in intersections:
		var inter = obj as RoadIntersection
		if not is_instance_valid(inter):
			continue
		var radio_cruce = _calcular_radio_cruce(inter)
		var umbral_dist = maxf(radio_cruce + 4.0, radio_max)
		
		# Comprobar distancia al centro del cruce
		var dist_centro = inter.global_position.distance_to(pos_mundo)
		if dist_centro <= umbral_dist and dist_centro < menor_dist:
			menor_dist = dist_centro
			mejor_inter = inter
			
		# También comprobar si se tocó directamente alguno de sus ramales salientes
		for rp in inter.edge_points:
			if is_instance_valid(rp):
				var dist_rp = rp.global_position.distance_to(pos_mundo)
				if dist_rp <= 7.0 and dist_rp < menor_dist:
					menor_dist = dist_rp
					mejor_inter = inter
					
	return mejor_inter

func seleccionar_cruce(inter: RoadIntersection) -> void:
	if cruce_seleccionado == inter and inter != null:
		return
	if is_instance_valid(cruce_seleccionado) and is_instance_valid(cruce_seleccionado._mesh):
		cruce_seleccionado._mesh.material_overlay = null
		
	cruce_seleccionado = inter
	if is_instance_valid(punto_carretera_seleccionado):
		deseleccionar_punto_carretera()
	deseleccionar_ramal_cruce()
	if _marcador_cruce_seleccionado:
		if is_instance_valid(inter):
			_marcador_cruce_seleccionado.global_position = inter.global_position + Vector3(0, 0.25, 0)
			var r = _calcular_radio_cruce(inter)
			var esc = (r / 6.0)
			_marcador_cruce_seleccionado.scale = Vector3(esc, 1.0, esc)
			_marcador_cruce_seleccionado.visible = true
			if is_instance_valid(inter._mesh):
				inter._mesh.material_overlay = _mat_overlay_cruce
			_actualizar_marcadores_ramales_en_cruce()
		else:
			_marcador_cruce_seleccionado.visible = false
	cruce_seleccionado_cambiado.emit(inter)

func deseleccionar_cruce() -> void:
	if is_instance_valid(cruce_seleccionado) and is_instance_valid(cruce_seleccionado._mesh):
		cruce_seleccionado._mesh.material_overlay = null
	cruce_seleccionado = null
	deseleccionar_ramal_cruce()
	if _marcador_cruce_seleccionado:
		_marcador_cruce_seleccionado.visible = false
	_limpiar_marcadores_ramales()
	cruce_seleccionado_cambiado.emit(null)

func _limpiar_marcadores_ramales() -> void:
	if not _nodo_ramales_cruce:
		return
	for c in _nodo_ramales_cruce.get_children():
		_nodo_ramales_cruce.remove_child(c)
		c.queue_free()

func _actualizar_marcadores_ramales_en_cruce() -> void:
	_limpiar_marcadores_ramales()
	if not is_instance_valid(cruce_seleccionado) or not _nodo_ramales_cruce:
		return
	for rp in cruce_seleccionado.edge_points:
		if not is_instance_valid(rp):
			continue
		var m := MeshInstance3D.new()
		m.name = "RamalMarker_%s" % rp.name
		var torus := TorusMesh.new()
		torus.inner_radius = 2.0
		torus.outer_radius = 2.6
		torus.rings = 24
		torus.ring_segments = 12
		m.mesh = torus
		
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if rp == ramal_cruce_seleccionado:
			mat.albedo_color = Color(0.2, 0.85, 1.0, 0.98) # Cyan para salida activa
		else:
			mat.albedo_color = Color(1.0, 0.78, 0.28, 0.85) # Amber para las demás salidas
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		
		_nodo_ramales_cruce.add_child(m)
		m.global_position = rp.global_position + Vector3(0, 0.28, 0)

func seleccionar_ramal_cruce(rp: RoadPoint) -> void:
	ramal_cruce_seleccionado = rp
	_actualizar_marcadores_ramales_en_cruce()
	if _marcador_ramal_seleccionado:
		if is_instance_valid(rp):
			_marcador_ramal_seleccionado.global_position = rp.global_position + Vector3(0, 0.35, 0)
			_marcador_ramal_seleccionado.visible = true
		else:
			_marcador_ramal_seleccionado.visible = false
	ramal_cruce_seleccionado_cambiado.emit(rp)

func deseleccionar_ramal_cruce() -> void:
	ramal_cruce_seleccionado = null
	_actualizar_marcadores_ramales_en_cruce()
	if _marcador_ramal_seleccionado:
		_marcador_ramal_seleccionado.visible = false
	ramal_cruce_seleccionado_cambiado.emit(null)

func seleccionar_ramal_por_indice(indice: int) -> void:
	if not is_instance_valid(cruce_seleccionado):
		deseleccionar_ramal_cruce()
		return
	if indice < 0 or indice >= cruce_seleccionado.edge_points.size():
		deseleccionar_ramal_cruce()
	else:
		seleccionar_ramal_cruce(cruce_seleccionado.edge_points[indice])

func buscar_ramal_cruce_cercano(pos_mundo: Vector3, radio_max: float = 6.0) -> RoadPoint:
	if not is_instance_valid(cruce_seleccionado):
		return null
	var mejor_rp: RoadPoint = null
	var menor_dist: float = radio_max
	for rp in cruce_seleccionado.edge_points:
		if not is_instance_valid(rp):
			continue
		var dist = rp.global_position.distance_to(pos_mundo)
		if dist < menor_dist:
			menor_dist = dist
			mejor_rp = rp
	return mejor_rp

func _obtener_etiqueta_cardinal(centro: Vector3, pos_ramal: Vector3) -> String:
	var delta = pos_ramal - centro
	delta.y = 0.0
	var ang_deg = rad_to_deg(atan2(delta.x, -delta.z)) # 0° es -Z (Norte), 90° es +X (Este)
	ang_deg = fposmod(ang_deg, 360.0)
	if ang_deg >= 315.0 or ang_deg < 45.0:
		return "Norte"
	elif ang_deg >= 45.0 and ang_deg < 135.0:
		return "Este"
	elif ang_deg >= 135.0 and ang_deg < 225.0:
		return "Sur"
	else:
		return "Oeste"

func _obtener_tipo_via_de_punto(rp: RoadPoint) -> TipoVia:
	if not is_instance_valid(rp):
		return TipoVia.CALLE_2_VIAS
	if bool(rp.get_meta("es_trocha", false)) or int(rp.get_meta("tipo_via", -1)) == int(TipoVia.TROCHA):
		return TipoVia.TROCHA
	if rp.traffic_dir.size() >= 6:
		return TipoVia.AUTOPISTA_6_VIAS
	elif rp.traffic_dir.size() >= 4:
		return TipoVia.AVENIDA_4_VIAS
	else:
		return TipoVia.CALLE_2_VIAS

func obtener_datos_ramales_cruce() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if not is_instance_valid(cruce_seleccionado):
		return lista
	var centro = cruce_seleccionado.global_position
	for i in range(cruce_seleccionado.edge_points.size()):
		var rp = cruce_seleccionado.edge_points[i]
		if not is_instance_valid(rp):
			continue
		var etiqueta = _obtener_etiqueta_cardinal(centro, rp.global_position)
		var tipo = _obtener_tipo_via_de_punto(rp)
		var num_carriles = rp.traffic_dir.size()
		lista.append({
			"indice": i,
			"nodo": rp,
			"etiqueta": etiqueta,
			"nombre": rp.name,
			"tipo_via": tipo,
			"num_carriles": num_carriles,
			"seleccionado": (rp == ramal_cruce_seleccionado)
		})
	return lista

func _calcular_radio_cruce(inter: RoadIntersection) -> float:
	if not is_instance_valid(inter) or inter.edge_points.is_empty():
		return 11.0
	var sum_dist: float = 0.0
	var count: int = 0
	for rp in inter.edge_points:
		if is_instance_valid(rp):
			var d = (rp.global_position - inter.global_position)
			d.y = 0.0
			sum_dist += d.length()
			count += 1
	if count > 0:
		return sum_dist / float(count)
	return 11.0

func _obtener_tipo_via_de_puntos(puntos: Array[RoadPoint]) -> TipoVia:
	for rp in puntos:
		if is_instance_valid(rp):
			if bool(rp.get_meta("es_trocha", false)) or int(rp.get_meta("tipo_via", -1)) == int(TipoVia.TROCHA):
				return TipoVia.TROCHA
			if rp.traffic_dir.size() >= 6:
				return TipoVia.AUTOPISTA_6_VIAS
			elif rp.traffic_dir.size() >= 4:
				return TipoVia.AVENIDA_4_VIAS
			else:
				return TipoVia.CALLE_2_VIAS
	return TipoVia.CALLE_2_VIAS

func obtener_datos_cruce_seleccionado() -> Dictionary:
	if not is_instance_valid(cruce_seleccionado):
		return {}
	return {
		"nombre": cruce_seleccionado.name,
		"posicion": cruce_seleccionado.global_position,
		"rotacion": cruce_seleccionado.rotation_degrees.y,
		"radio": _calcular_radio_cruce(cruce_seleccionado),
		"num_brazos": cruce_seleccionado.edge_points.size(),
		"tipo_via": _obtener_tipo_via_de_puntos(cruce_seleccionado.edge_points),
		"flatten_terrain": cruce_seleccionado.flatten_terrain
	}

func modificar_radio_cruce(nuevo_radio: float) -> void:
	if not is_instance_valid(cruce_seleccionado):
		return
	var radio_clamped = clampf(nuevo_radio, 8.0, 35.0)
	var centro = cruce_seleccionado.global_position
	
	for rp in cruce_seleccionado.edge_points:
		if not is_instance_valid(rp):
			continue
		var delta = rp.global_position - centro
		delta.y = 0.0
		var dir = delta.normalized()
		if dir.length_squared() < 0.001:
			dir = Vector3.FORWARD
		var nueva_pos = centro + dir * radio_clamped
		nueva_pos = _ajustar_altura_a_terreno(nueva_pos)
		rp.global_position = nueva_pos
		
	_actualizar_orientaciones_y_curvaturas()
	cruce_seleccionado.emit_transform()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	if cruce_seleccionado.flatten_terrain:
		nivelar_terreno_bajo_carreteras()
	if _marcador_cruce_seleccionado and _marcador_cruce_seleccionado.visible:
		_marcador_cruce_seleccionado.global_position = cruce_seleccionado.global_position + Vector3(0, 0.25, 0)
		var esc = (radio_clamped / 6.0)
		_marcador_cruce_seleccionado.scale = Vector3(esc, 1.0, esc)
		_actualizar_marcadores_ramales_en_cruce()
		if is_instance_valid(cruce_seleccionado._mesh):
			cruce_seleccionado._mesh.material_overlay = _mat_overlay_cruce
	if _marcador_ramal_seleccionado and _marcador_ramal_seleccionado.visible and is_instance_valid(ramal_cruce_seleccionado):
		_marcador_ramal_seleccionado.global_position = ramal_cruce_seleccionado.global_position + Vector3(0, 0.35, 0)
	carretera_actualizada.emit()

func rotar_cruce_seleccionado(nuevo_angulo_grados: float) -> void:
	if not is_instance_valid(cruce_seleccionado):
		return
	var ang_actual = cruce_seleccionado.rotation_degrees.y
	var delta_deg = nuevo_angulo_grados - ang_actual
	rotar_cruce_seleccionado_delta(delta_deg)

func rotar_cruce_seleccionado_delta(delta_deg: float) -> void:
	if not is_instance_valid(cruce_seleccionado):
		return
	var centro = cruce_seleccionado.global_position
	var delta_rad = deg_to_rad(delta_deg)
	
	cruce_seleccionado.rotation_degrees.y = fposmod(cruce_seleccionado.rotation_degrees.y + delta_deg, 360.0)
	
	for rp in cruce_seleccionado.edge_points:
		if not is_instance_valid(rp):
			continue
		var offset = rp.global_position - centro
		offset.y = 0.0
		var dist = offset.length()
		var nuevo_offset = offset.rotated(Vector3.UP, delta_rad)
		var nueva_pos = centro + nuevo_offset
		nueva_pos = _ajustar_altura_a_terreno(nueva_pos)
		rp.global_position = nueva_pos
		var dir_out = nuevo_offset.normalized()
		if dir_out.length_squared() > 0.001:
			var fwd = dir_out.normalized()
			var up_ref = Vector3.UP
			if absf(fwd.dot(up_ref)) > 0.96:
				up_ref = Vector3.FORWARD
			rp.global_transform.basis = Basis.looking_at(-fwd, up_ref)
			
	_actualizar_orientaciones_y_curvaturas()
	cruce_seleccionado.emit_transform()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	if cruce_seleccionado.flatten_terrain:
		nivelar_terreno_bajo_carreteras()
	if _marcador_cruce_seleccionado and _marcador_cruce_seleccionado.visible:
		_actualizar_marcadores_ramales_en_cruce()
		if is_instance_valid(cruce_seleccionado._mesh):
			cruce_seleccionado._mesh.material_overlay = _mat_overlay_cruce
	if _marcador_ramal_seleccionado and _marcador_ramal_seleccionado.visible and is_instance_valid(ramal_cruce_seleccionado):
		_marcador_ramal_seleccionado.global_position = ramal_cruce_seleccionado.global_position + Vector3(0, 0.35, 0)
	carretera_actualizada.emit()

func cambiar_tipo_via_cruce(tipo: TipoVia) -> void:
	if not is_instance_valid(cruce_seleccionado):
		return
	for rp in cruce_seleccionado.edge_points:
		if not is_instance_valid(rp):
			continue
		_aplicar_tipo_via_a_punto(rp, tipo)
				
	_actualizar_orientaciones_y_curvaturas()
	cruce_seleccionado.emit_transform()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	if cruce_seleccionado.flatten_terrain:
		nivelar_terreno_bajo_carreteras()
	if _marcador_cruce_seleccionado and _marcador_cruce_seleccionado.visible:
		_actualizar_marcadores_ramales_en_cruce()
		if is_instance_valid(cruce_seleccionado._mesh):
			cruce_seleccionado._mesh.material_overlay = _mat_overlay_cruce
	carretera_actualizada.emit()

func cambiar_tipo_via_ramal(rp: RoadPoint, tipo: TipoVia) -> void:
	if not is_instance_valid(rp) or not is_instance_valid(cruce_seleccionado):
		return
	_aplicar_tipo_via_a_punto(rp, tipo)
	_actualizar_orientaciones_y_curvaturas()
	cruce_seleccionado.emit_transform()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	if cruce_seleccionado.flatten_terrain:
		nivelar_terreno_bajo_carreteras()
	if _marcador_cruce_seleccionado and _marcador_cruce_seleccionado.visible:
		_actualizar_marcadores_ramales_en_cruce()
		if is_instance_valid(cruce_seleccionado._mesh):
			cruce_seleccionado._mesh.material_overlay = _mat_overlay_cruce
	carretera_actualizada.emit()

func cambiar_tipo_via_ramal_seleccionado_o_todos(tipo: TipoVia) -> void:
	if not is_instance_valid(cruce_seleccionado):
		return
	if is_instance_valid(ramal_cruce_seleccionado):
		cambiar_tipo_via_ramal(ramal_cruce_seleccionado, tipo)
	else:
		cambiar_tipo_via_cruce(tipo)

func cambiar_configuracion_brazos_cruce(num_brazos: int) -> void:
	if not is_instance_valid(cruce_seleccionado) or not road_container:
		return
	var actual = cruce_seleccionado.edge_points.size()
	if actual == num_brazos:
		return
		
	var radio = _calcular_radio_cruce(cruce_seleccionado)
	var rot_rad = deg_to_rad(cruce_seleccionado.rotation_degrees.y)
	var dir_sur_norm = Vector3(0, 0, 1).rotated(Vector3.UP, rot_rad)
	
	if num_brazos == 4 and actual < 4:
		# Añadir brazo hacia el Sur (180°)
		var offset_sur = dir_sur_norm * radio
		var p_pos = _ajustar_altura_a_terreno(cruce_seleccionado.global_position + offset_sur)
		var rp := RoadPoint.new()
		rp.name = "%s_P%d" % [cruce_seleccionado.name, cruce_seleccionado.edge_points.size() + 1]
		road_container.add_child(rp)
		rp.container = road_container
		rp.global_position = p_pos
		var dir_out = offset_sur.normalized()
		if dir_out.length_squared() > 0.001:
			var fwd = dir_out.normalized()
			var up_ref = Vector3.UP
			if absf(fwd.dot(up_ref)) > 0.96:
				up_ref = Vector3.FORWARD
			rp.global_transform.basis = Basis.looking_at(-fwd, up_ref)
		var tipo_actual = _obtener_tipo_via_de_puntos(cruce_seleccionado.edge_points)
		_aplicar_tipo_via_a_punto(rp, tipo_actual)
		cruce_seleccionado.add_branch(rp)
		_puntos_creados.append(rp)
	elif num_brazos == 3 and actual >= 4:
		# Retirar el brazo más cercano al Sur
		var mejor_rp: RoadPoint = null
		var max_dot: float = -2.0
		var centro = cruce_seleccionado.global_position
		for rp in cruce_seleccionado.edge_points:
			if not is_instance_valid(rp):
				continue
			var d = (rp.global_position - centro)
			d.y = 0.0
			var dot = d.normalized().dot(dir_sur_norm)
			if dot > max_dot:
				max_dot = dot
				mejor_rp = rp
		if mejor_rp:
			var tiene_otra = false
			if not mejor_rp.prior_pt_init.is_empty() and mejor_rp.get_node_or_null(mejor_rp.prior_pt_init) != cruce_seleccionado:
				tiene_otra = true
			if not mejor_rp.next_pt_init.is_empty() and mejor_rp.get_node_or_null(mejor_rp.next_pt_init) != cruce_seleccionado:
				tiene_otra = true
			if not tiene_otra:
				cruce_seleccionado.remove_branch(mejor_rp)
				var idx = _puntos_creados.find(mejor_rp)
				if idx != -1:
					_puntos_creados.remove_at(idx)
				mejor_rp.queue_free()
				
	_actualizar_orientaciones_y_curvaturas()
	cruce_seleccionado.emit_transform()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	if cruce_seleccionado.flatten_terrain:
		nivelar_terreno_bajo_carreteras()
	carretera_actualizada.emit()

func cambiar_aplanar_cruce(aplanar: bool) -> void:
	if not is_instance_valid(cruce_seleccionado):
		return
	cruce_seleccionado.flatten_terrain = aplanar
	if aplanar:
		nivelar_terreno_bajo_carreteras()

func eliminar_cruce_seleccionado() -> void:
	if not is_instance_valid(cruce_seleccionado):
		return
	var inter = cruce_seleccionado
	deseleccionar_cruce()
	
	var edges = inter.edge_points.duplicate()
	for rp in edges:
		if not is_instance_valid(rp):
			continue
		inter.remove_branch(rp)
		var tiene_otra = false
		if not rp.prior_pt_init.is_empty() and rp.get_node_or_null(rp.prior_pt_init) != inter:
			tiene_otra = true
		if not rp.next_pt_init.is_empty() and rp.get_node_or_null(rp.next_pt_init) != inter:
			tiene_otra = true
			
		if not tiene_otra:
			var idx = _puntos_creados.find(rp)
			if idx != -1:
				_puntos_creados.remove_at(idx)
			rp.queue_free()
			
	inter.queue_free()
	_actualizar_orientaciones_y_curvaturas()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	carretera_actualizada.emit()

func _configurar_tipo_via(rp: RoadPoint) -> void:
	_aplicar_tipo_via_a_punto(rp, tipo_via_actual)

func _aplicar_tipo_via_a_punto(rp: RoadPoint, tipo: TipoVia) -> void:
	rp.gutter_profile = Vector2(0.0, 0.0) # Desactiva zanja que causaba muescas triangulares negras en curvas
	rp.set_meta("tipo_via", int(tipo))
	rp.set_meta("es_trocha", tipo == TipoVia.TROCHA)
	match tipo:
		TipoVia.CALLE_2_VIAS:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 3.6
			rp.shoulder_width_l = 0.8
			rp.shoulder_width_r = 0.8
		TipoVia.AVENIDA_4_VIAS:
			var dirs: Array[RoadPoint.LaneDir] = [
				RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.REVERSE,
				RoadPoint.LaneDir.FORWARD, RoadPoint.LaneDir.FORWARD
			]
			rp.traffic_dir = dirs
			rp.lane_width = 3.5
			rp.shoulder_width_l = 1.2
			rp.shoulder_width_r = 1.2
		TipoVia.AUTOPISTA_6_VIAS:
			var dirs: Array[RoadPoint.LaneDir] = [
				RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.REVERSE,
				RoadPoint.LaneDir.FORWARD, RoadPoint.LaneDir.FORWARD, RoadPoint.LaneDir.FORWARD
			]
			rp.traffic_dir = dirs
			rp.lane_width = 3.8
			rp.shoulder_width_l = 1.8
			rp.shoulder_width_r = 1.8
		TipoVia.TROCHA:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 2.8
			rp.shoulder_width_l = 0.9
			rp.shoulder_width_r = 0.9

func _asegurar_recursos_trocha() -> void:
	if not _mat_trocha_via and ResourceLoader.exists(RUTA_MATERIAL_TROCHA):
		var base_mat := load(RUTA_MATERIAL_TROCHA) as ShaderMaterial
		if base_mat:
			_mat_trocha_via = base_mat.duplicate() as ShaderMaterial
			_mat_trocha_via.set_shader_parameter("modo_via_procedural", true)
			_mat_trocha_via.set_shader_parameter("rotar_camino_90", false)
			_mat_trocha_via.set_shader_parameter("usar_coordenadas_mundo", false)
			_mat_trocha_via.set_shader_parameter("activar_huellones", true)
			_mat_trocha_via.set_shader_parameter("activar_camellon_central", true)
			_mat_trocha_via.set_shader_parameter("fuerza_labrado_llantas", 0.65)

			_mat_trocha_cruce = base_mat.duplicate() as ShaderMaterial
			_mat_trocha_cruce.set_shader_parameter("modo_via_procedural", false)
			_mat_trocha_cruce.set_shader_parameter("activar_huellones", false)
			_mat_trocha_cruce.set_shader_parameter("activar_maleza_bordes", false)
			_mat_trocha_cruce.set_shader_parameter("usar_coordenadas_mundo", true)
			_mat_trocha_cruce.set_shader_parameter("escala_uv", Vector2(0.25, 0.25))
			_mat_trocha_cruce.set_shader_parameter("escala_piedras_uv", Vector2(0.35, 0.35))

	if not _mat_trocha_talud:
		_mat_trocha_talud = StandardMaterial3D.new()
		_mat_trocha_talud.albedo_color = Color(0.38, 0.28, 0.18)
		_mat_trocha_talud.roughness = 0.94

	if not _kit_trocha_cargado:
		_kit_trocha_cargado = true
		if ResourceLoader.exists(RUTA_KIT_TROCHA_GLB):
			var escena_kit := load(RUTA_KIT_TROCHA_GLB) as PackedScene
			if escena_kit:
				var inst := escena_kit.instantiate()
				for nombre_nodo in ["Poste_Cerca_Rural", "Roca_Orilla_Trocha", "Alcantarilla_Rustica"]:
					var n := inst.find_child(nombre_nodo, true, false) as MeshInstance3D
					if n and n.mesh:
						var mat_p: Material = n.get_active_material(0)
						if not mat_p and n.mesh.get_surface_count() > 0:
							mat_p = n.mesh.surface_get_material(0)
						_mallas_kit_trocha[nombre_nodo] = {
							"mesh": n.mesh.duplicate(),
							"material": mat_p
						}
				inst.free()

func _on_road_container_updated(_updated_segments: Array) -> void:
	if _actualizando_trochas:
		return
	_actualizar_segmentos_trocha()

func _actualizar_segmentos_trocha() -> void:
	if _actualizando_trochas or not road_container or not is_instance_valid(road_container):
		return
	_actualizando_trochas = true
	_asegurar_recursos_trocha()

	for obj in road_container.get_segments():
		var seg := obj as RoadSegment
		if not is_instance_valid(seg):
			continue
		var sp_trocha: bool = is_instance_valid(seg.start_point) and _obtener_tipo_via_de_punto(seg.start_point) == TipoVia.TROCHA
		var ep_trocha: bool = is_instance_valid(seg.end_point) and _obtener_tipo_via_de_punto(seg.end_point) == TipoVia.TROCHA
		var es_seg_trocha: bool = sp_trocha or ep_trocha

		if es_seg_trocha:
			_aplicar_uvs_y_material_trocha_a_segmento(seg)
			_instanciar_detalles_rurales_trocha(seg)
		else:
			var det_prev := seg.get_node_or_null("DetallesTrocha3D")
			if det_prev:
				seg.remove_child(det_prev)
				det_prev.queue_free()
			if _mat_trocha_via and seg.material == _mat_trocha_via:
				seg.material = road_container.material_resource
				seg.material_underside = road_container.material_underside
				seg.is_dirty = true
				seg.check_rebuild()

	for obj_i in road_container.get_intersections():
		var inter := obj_i as RoadIntersection
		if not is_instance_valid(inter) or not is_instance_valid(inter._mesh):
			continue
		var tiene_trocha: bool = false
		for rp_b in inter.edge_points:
			if is_instance_valid(rp_b) and _obtener_tipo_via_de_punto(rp_b) == TipoVia.TROCHA:
				tiene_trocha = true
				break
		if tiene_trocha and _mat_trocha_cruce:
			inter._mesh.set_surface_override_material(0, _mat_trocha_cruce)
		else:
			if inter._mesh.get_surface_override_material(0) == _mat_trocha_cruce:
				inter._mesh.set_surface_override_material(0, road_container.material_resource)

	_actualizando_trochas = false

func _aplicar_uvs_y_material_trocha_a_segmento(seg: RoadSegment) -> void:
	if not _mat_trocha_via or not is_instance_valid(seg.road_mesh) or not (seg.road_mesh.mesh is ArrayMesh):
		return
	seg.material = _mat_trocha_via
	seg.material_underside = _mat_trocha_talud
	seg.set_meta("es_trocha", true)
	seg.road_mesh.set_meta("es_trocha", true)

	var arr_mesh := seg.road_mesh.mesh as ArrayMesh
	if arr_mesh.get_surface_count() == 0 or not seg.curve:
		return

	var curve_len: float = seg.curve.get_baked_length()
	if curve_len <= 0.05:
		return

	var arrays_0: Array = arr_mesh.surface_get_arrays(0)
	if arrays_0.is_empty():
		return
	var verts: PackedVector3Array = arrays_0[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays_0[Mesh.ARRAY_TEX_UV]
	if verts.is_empty() or uvs.size() != verts.size():
		return

	var firma_actual: String = "%d_%.2f" % [verts.size(), curve_len]
	if str(arr_mesh.get_meta("firma_uv_trocha", "")) != firma_actual:
		var w_start: float = maxf(_obtener_ancho_via_punto(seg.start_point), 2.0) if is_instance_valid(seg.start_point) else 7.4
		var w_end: float = maxf(_obtener_ancho_via_punto(seg.end_point), 2.0) if is_instance_valid(seg.end_point) else 7.4

		for i in range(verts.size()):
			var v_loc: Vector3 = verts[i]
			var s: float = seg.curve.get_closest_offset(v_loc)
			var t_norm: float = clampf(s / curve_len, 0.0, 1.0)
			var c_pt: Vector3 = seg.curve.sample_baked(s)
			var lat_vec: Vector3 = seg._normal_for_offset(seg.curve, t_norm)
			var w_here: float = maxf(lerpf(w_start, w_end, t_norm), 1.0)
			var lat_dist: float = (v_loc - c_pt).dot(lat_vec)
			var u_coord: float = clampf((lat_dist / w_here) + 0.5, 0.0, 1.0)
			var v_coord: float = s / 8.0
			uvs[i] = Vector2(u_coord, v_coord)

		arrays_0[Mesh.ARRAY_TEX_UV] = uvs
		var tiene_surf_1: bool = arr_mesh.get_surface_count() > 1
		var arrays_1: Array = arr_mesh.surface_get_arrays(1) if tiene_surf_1 else []

		arr_mesh.clear_surfaces()
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_0)
		arr_mesh.surface_set_material(0, _mat_trocha_via)
		if tiene_surf_1 and not arrays_1.is_empty():
			arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_1)
			arr_mesh.surface_set_material(1, _mat_trocha_talud)
		arr_mesh.set_meta("firma_uv_trocha", firma_actual)

	seg.road_mesh.set_surface_override_material(0, _mat_trocha_via)
	if arr_mesh.get_surface_count() > 1 and _mat_trocha_talud:
		seg.road_mesh.set_surface_override_material(1, _mat_trocha_talud)

func _instanciar_detalles_rurales_trocha(seg: RoadSegment) -> void:
	if _mallas_kit_trocha.is_empty() or not seg.curve:
		return
	var curve_len: float = seg.curve.get_baked_length()
	if curve_len < 4.0:
		return

	# No colocar estacones de potrero si el tramo es un viaducto elevado (> 1.8m)
	var off_s: float = float(seg.start_point.get_meta("offset_y", 0.0)) if is_instance_valid(seg.start_point) else 0.0
	var off_e: float = float(seg.end_point.get_meta("offset_y", 0.0)) if is_instance_valid(seg.end_point) else 0.0
	var det_existente := seg.get_node_or_null("DetallesTrocha3D") as Node3D
	if absf(off_s) > 1.8 or absf(off_e) > 1.8:
		if det_existente:
			seg.remove_child(det_existente)
			det_existente.queue_free()
		return

	var firma_det: String = "%.1f_%d" % [curve_len, int(seg.get_instance_id() % 997)]
	if det_existente and str(det_existente.get_meta("firma_det", "")) == firma_det:
		return
	if det_existente:
		seg.remove_child(det_existente)
		det_existente.queue_free()

	var cont := Node3D.new()
	cont.name = "DetallesTrocha3D"
	cont.set_meta("firma_det", firma_det)
	seg.add_child(cont)

	var w_start: float = _obtener_ancho_via_punto(seg.start_point) if is_instance_valid(seg.start_point) else 7.4
	var w_end: float = _obtener_ancho_via_punto(seg.end_point) if is_instance_valid(seg.end_point) else 7.4
	var paso_postes: float = 4.5
	var num_pasos: int = maxi(1, int(floor(curve_len / paso_postes)))

	for i in range(1, num_pasos):
		var s: float = float(i) * paso_postes
		var t: float = clampf(s / curve_len, 0.0, 1.0)
		var pt_c: Vector3 = seg.curve.sample_baked(s)
		var pt_next: Vector3 = seg.curve.sample_baked(minf(s + 0.35, curve_len))
		var fwd: Vector3 = (pt_next - pt_c).normalized()
		if fwd.length_squared() < 0.001:
			fwd = Vector3.FORWARD
		var lat: Vector3 = seg._normal_for_offset(seg.curve, t).normalized()
		var up: Vector3 = lat.cross(fwd).normalized()
		if up.y < 0.0:
			up = -up
		var half_w: float = lerpf(w_start, w_end, t) * 0.5

		# Estacones de cerca rural a ambos lados de la trocha
		if _mallas_kit_trocha.has("Poste_Cerca_Rural"):
			var info_p: Dictionary = _mallas_kit_trocha["Poste_Cerca_Rural"]
			for signo_lado in [-1.0, 1.0]:
				var mi_p := MeshInstance3D.new()
				mi_p.mesh = info_p["mesh"]
				if info_p["material"]:
					mi_p.material_override = info_p["material"]
				var pos_p: Vector3 = pt_c + lat * (signo_lado * (half_w + 0.25)) - up * 0.12
				var basis_p := Basis(lat * signo_lado, up, fwd * signo_lado).orthonormalized()
				mi_p.transform = Transform3D(basis_p, pos_p)
				cont.add_child(mi_p)

		# Rocas andinas sueltas en las orillas cada 2 pasos
		if (i % 2 == 0) and _mallas_kit_trocha.has("Roca_Orilla_Trocha"):
			var info_r: Dictionary = _mallas_kit_trocha["Roca_Orilla_Trocha"]
			var signo_roca: float = 1.0 if ((i + int(seg.get_instance_id())) % 2 == 0) else -1.0
			var mi_r := MeshInstance3D.new()
			mi_r.mesh = info_r["mesh"]
			if info_r["material"]:
				mi_r.material_override = info_r["material"]
			var esc_r: float = 0.75 + float((i * 37) % 5) * 0.10
			var pos_r: Vector3 = pt_c + lat * (signo_roca * (half_w - 0.15)) - up * 0.05
			var basis_r := Basis(lat, up, fwd).orthonormalized().scaled(Vector3(esc_r, esc_r, esc_r))
			mi_r.transform = Transform3D(basis_r, pos_r)
			cont.add_child(mi_r)

	# Cabezal de alcantarilla rústica de drenaje a mitad de tramos largos (> 14m)
	if curve_len >= 14.0 and _mallas_kit_trocha.has("Alcantarilla_Rustica"):
		var info_a: Dictionary = _mallas_kit_trocha["Alcantarilla_Rustica"]
		var s_mid: float = curve_len * 0.5
		var pt_m: Vector3 = seg.curve.sample_baked(s_mid)
		var pt_m2: Vector3 = seg.curve.sample_baked(minf(s_mid + 0.35, curve_len))
		var fwd_m: Vector3 = (pt_m2 - pt_m).normalized()
		var lat_m: Vector3 = seg._normal_for_offset(seg.curve, 0.5).normalized()
		var up_m: Vector3 = lat_m.cross(fwd_m).normalized()
		if up_m.y < 0.0:
			up_m = -up_m
		var half_wm: float = lerpf(w_start, w_end, 0.5) * 0.5
		var mi_a := MeshInstance3D.new()
		mi_a.mesh = info_a["mesh"]
		if info_a["material"]:
			mi_a.material_override = info_a["material"]
		var pos_a: Vector3 = pt_m + lat_m * (half_wm + 0.18) - up_m * 0.35
		var basis_a := Basis(lat_m, up_m, fwd_m).orthonormalized()
		mi_a.transform = Transform3D(basis_a, pos_a)
		cont.add_child(mi_a)

# ── TERRAFORMADO: NIVELACIÓN DEL TERRENO BAJO LAS CARRETERAS ────────

func obtener_segmentos_de_punto(rp: RoadPoint) -> Array:
	var res: Array = []
	if not rp or not is_instance_valid(rp) or not road_container:
		return res
	var segs = road_container.get_segments() if road_container.has_method("get_segments") else []
	for seg in segs:
		if seg.start_point == rp or seg.end_point == rp:
			res.append(seg)
	return res

func adaptar_terreno_en_tramo(segmentos: Array) -> bool:
	if not controlador_terreno or not is_instance_valid(controlador_terreno):
		return false
	var terrain = (controlador_terreno as ControladorTerreno).terrain
	if not terrain or not is_instance_valid(terrain) or not terrain.data:
		return false
	var modificado := false
	for seg in segmentos:
		var s = seg as RoadSegment
		if not s or not is_instance_valid(s) or not s.curve:
			continue
		if _nivelar_segmento(s, terrain, true):
			modificado = true
	if modificado:
		terrain.data.update_maps(0)
		terrain.data.calc_height_range()
		if (controlador_terreno as ControladorTerreno).has_signal("terreno_modificado"):
			(controlador_terreno as ControladorTerreno).terreno_modificado.emit()
	if equipamiento_controller and equipamiento_controller.has_method("actualizar_puentes_y_tuneles_automaticos"):
		equipamiento_controller.actualizar_puentes_y_tuneles_automaticos()
	return modificado

func nivelar_terreno_bajo_carreteras() -> void:
	if not controlador_terreno or not is_instance_valid(controlador_terreno):
		return
	var terrain = (controlador_terreno as ControladorTerreno).terrain
	if not terrain or not is_instance_valid(terrain) or not terrain.data:
		return
	if not road_container or not is_instance_valid(road_container):
		return
		
	var segs = road_container.get_segments()
	if segs.is_empty():
		return
		
	var modificado := false
	for seg in segs:
		if not is_instance_valid(seg) or not seg.curve:
			continue
		# No deformar el terreno automáticamente bajo viaductos elevados ni túneles
		var off_start := float(seg.start_point.get_meta("offset_y", 0.0)) if is_instance_valid(seg.start_point) else 0.0
		var off_end := float(seg.end_point.get_meta("offset_y", 0.0)) if is_instance_valid(seg.end_point) else 0.0
		if absf(off_start) >= 1.2 or absf(off_end) >= 1.2:
			continue
		if _nivelar_segmento(seg, terrain, false):
			modificado = true
			
	if modificado:
		terrain.data.update_maps(0) # 0 = TERRAIN_3D_MAPTYPE_HEIGHT
		terrain.data.calc_height_range()
		if (controlador_terreno as ControladorTerreno).has_signal("terreno_modificado"):
			(controlador_terreno as ControladorTerreno).terreno_modificado.emit()

func _flatten_curve(curve: Curve3D, normalization_value: float) -> void:
	for i in range(curve.point_count):
		var pos: Vector3 = curve.get_point_position(i)
		var pos_in: Vector3 = curve.get_point_in(i)
		var pos_out: Vector3 = curve.get_point_out(i)
		pos.y /= normalization_value 
		pos_in.y /= normalization_value 
		pos_out.y /= normalization_value 
		curve.set_point_position(i, pos)
		curve.set_point_in(i, pos_in)
		curve.set_point_out(i, pos_out)

func _obtener_ancho_via_punto(rp: RoadPoint) -> float:
	var n_lanes = rp.lanes.size() if rp.lanes.size() > 0 else rp.traffic_dir.size()
	return rp.gutter_profile.x * 2.0 + rp.shoulder_width_l + rp.shoulder_width_r + rp.lane_width * n_lanes

func _nivelar_segmento(seg: RoadSegment, terrain: Terrain3D, forzar_adaptacion: bool = false) -> bool:
	var curve: Curve3D = seg.curve
	if not curve or curve.get_baked_length() <= 0.001:
		return false
		
	var start_width := _obtener_ancho_via_punto(seg.start_point)
	var end_width := _obtener_ancho_via_punto(seg.end_point)
	var vertex_spacing: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0

	var edge_margin := 0.8
	var edge_falloff := 3.5
	var offset_y := -0.30 # Nivelar a 30 cm por debajo de la superficie de rodadura

	# Curva aplanada para proyección precisa en el plano XZ sin sesgo de altura 3D
	var flattened_curve: Curve3D = curve.duplicate(true)
	var norm_factor := 10000.0
	_flatten_curve(flattened_curve, norm_factor)

	# Bounding Box ampliado para abarcar calzada, bermas y taludes
	var offsets := Vector3(edge_margin + edge_falloff + 2.0, 0.0, edge_margin + edge_falloff + 2.0)
	var aabb: AABB
	if is_instance_valid(seg.road_mesh) and seg.road_mesh.mesh:
		aabb = seg.road_mesh.global_transform * seg.road_mesh.get_aabb()
	else:
		aabb = AABB(seg.start_point.global_position, Vector3.ZERO).expand(seg.end_point.global_position)
	var aabb_min := aabb.position - offsets
	var aabb_max := aabb.position + aabb.size + offsets

	# Alinear límites a la cuadrícula de vértices de Terrain3D
	var min_xz := Vector3(aabb_min.x, 0.0, aabb_min.z).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing))
	var max_xz := Vector3(aabb_max.x, 0.0, aabb_max.z).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing)) + Vector3(vertex_spacing, 0.0, vertex_spacing)

	var world_to_local := seg.global_transform.inverse()
	var curve_len := flattened_curve.get_baked_length()
	var modificado := false

	# Bucle sobre cada vértice de la cuadrícula: elimina por completo el traspaso o aletas de terreno
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var world_pos := Vector3(x, 0.0, z)
			if terrain.data.has_regionp(world_pos):
				var local_pos := world_to_local * world_pos
				var closest_offset := flattened_curve.get_closest_offset(local_pos)

				# Ignorar vértices más allá de los extremos del segmento
				var descartar := false
				if closest_offset <= 0.001:
					var off_start := world_pos - seg.start_point.global_position
					var z_dist := absf(seg.start_point.global_transform.basis.z.dot(off_start))
					if z_dist > vertex_spacing:
						descartar = true
				elif closest_offset >= curve_len - 0.001:
					var off_end := world_pos - seg.end_point.global_position
					var z_dist := absf(seg.end_point.global_transform.basis.z.dot(off_end))
					if z_dist > vertex_spacing:
						descartar = true

				if not descartar:
					var curve_pt := flattened_curve.sample_baked(closest_offset)
					curve_pt.y *= norm_factor
					var world_curve_pt := seg.global_transform * curve_pt

					var sample_pos := clampf(closest_offset / curve_len, 0.0, 1.0)
					var lateral_basis: Vector3 = seg.global_transform.basis * seg._normal_for_offset(seg.curve, sample_pos)
					var lat_horizontal := Vector2(lateral_basis.x, lateral_basis.z)
					var lat_len_sq := lat_horizontal.length_squared()

					if lat_len_sq > 0.0001:
						var lat_offset := Vector2(x - world_curve_pt.x, z - world_curve_pt.z).dot(lat_horizontal) / lat_len_sq
						var width := lerpf(start_width, end_width, sample_pos)
						var half_w := width * 0.5
						var lat_dist := absf(lat_offset)

						var road_lat_offset := clampf(lat_offset, -half_w, half_w)
						var target_road_bed := world_curve_pt.y + lateral_basis.y * road_lat_offset + offset_y

						var curr_h = terrain.data.get_height(world_pos)
						if not is_nan(curr_h):
							if forzar_adaptacion:
								# El usuario pidió explícitamente adaptar el terreno (subir terraplén o excavar trinchera)
								if lat_dist <= half_w + edge_margin:
									if absf(curr_h - target_road_bed) > 0.02:
										terrain.data.set_height(world_pos, target_road_bed)
										modificado = true
								elif lat_dist <= half_w + edge_margin + edge_falloff:
									var factor: float = (lat_dist - (half_w + edge_margin)) / edge_falloff
									var desired := lerpf(target_road_bed, curr_h, factor)
									if absf(curr_h - desired) > 0.02:
										terrain.data.set_height(world_pos, desired)
										modificado = true
							else:
								# Si la montaña está más de 2.2m por encima de la carretera, es un TÚNEL: no destruir la montaña
								if curr_h <= target_road_bed + 2.2:
									if lat_dist <= half_w + edge_margin:
										if curr_h > target_road_bed:
											terrain.data.set_height(world_pos, target_road_bed)
											modificado = true
									elif lat_dist <= half_w + edge_margin + edge_falloff:
										var factor: float = (lat_dist - (half_w + edge_margin)) / edge_falloff
										var desired := lerpf(target_road_bed, curr_h, factor)
										if curr_h > desired:
											terrain.data.set_height(world_pos, desired)
											modificado = true

			z += vertex_spacing
		x += vertex_spacing

	return modificado

func finalizar_tramo_actual() -> void:
	_ultimo_road_point = null
	_punto_origen_conexion = null
	if _marcador_seleccion_conexion:
		_marcador_seleccion_conexion.visible = false
	if _linea_instance:
		_linea_instance.visible = false
	_actualizar_orientaciones_y_curvaturas()
	if road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
	nivelar_terreno_bajo_carreteras()
	tramo_finalizado.emit()

func deshacer_ultimo_punto() -> void:
	if _historial_acciones.is_empty():
		# Fallback por si acaso la lista de historial estuviera vacía pero hay puntos
		if not _puntos_creados.is_empty():
			var rp = _puntos_creados.pop_back()
			if is_instance_valid(rp):
				if rp.is_prior_connected():
					rp.disconnect_roadpoint(RoadPoint.PointInit.PRIOR, RoadPoint.PointInit.NEXT)
				rp.queue_free()
			_ultimo_road_point = _puntos_creados.back() if not _puntos_creados.is_empty() else null
			if road_container:
				road_container.update_edges()
				_actualizar_orientaciones_y_curvaturas()
				road_container.rebuild_segments(true)
				nivelar_terreno_bajo_carreteras()
			carretera_actualizada.emit()
		return

	var accion = _historial_acciones.pop_back()
	if accion is RoadPoint:
		var rp = accion as RoadPoint
		if is_instance_valid(rp):
			var idx = _puntos_creados.find(rp)
			if idx != -1:
				_puntos_creados.remove_at(idx)
			if rp.is_prior_connected():
				rp.disconnect_roadpoint(RoadPoint.PointInit.PRIOR, RoadPoint.PointInit.NEXT)
			if rp.is_next_connected():
				rp.disconnect_roadpoint(RoadPoint.PointInit.NEXT, RoadPoint.PointInit.PRIOR)
			rp.queue_free()
	elif accion is Dictionary:
		var puntos_a_eliminar: Array = accion.get("puntos", [])
		for rp in puntos_a_eliminar:
			if is_instance_valid(rp):
				var idx = _puntos_creados.find(rp)
				if idx != -1:
					_puntos_creados.remove_at(idx)
				if rp.is_prior_connected():
					rp.disconnect_roadpoint(RoadPoint.PointInit.PRIOR, RoadPoint.PointInit.NEXT)
				if rp.is_next_connected():
					rp.disconnect_roadpoint(RoadPoint.PointInit.NEXT, RoadPoint.PointInit.PRIOR)
				rp.queue_free()

		var p_prev = accion.get("prev_modificado", null)
		if is_instance_valid(p_prev) and accion.has("pos_original_prev") and accion["pos_original_prev"] != Vector3.ZERO:
			p_prev.global_position = accion["pos_original_prev"]

	if not _puntos_creados.is_empty():
		_ultimo_road_point = _puntos_creados.back()
	else:
		_ultimo_road_point = null

	if road_container:
		road_container.update_edges()
		_actualizar_orientaciones_y_curvaturas()
		road_container.rebuild_segments(true)
		nivelar_terreno_bajo_carreteras()
	carretera_actualizada.emit()

func limpiar_todas_las_carreteras() -> void:
	for rp in _puntos_creados:
		if is_instance_valid(rp):
			rp.queue_free()
	_puntos_creados.clear()
	_historial_acciones.clear()
	_ultimo_road_point = null
	if _linea_instance:
		_linea_instance.visible = false
	if road_container:
		road_container.rebuild_segments(true)
	carretera_actualizada.emit()

func serializar_carreteras() -> Array:
	var lista: Array = []
	for rp in _puntos_creados:
		if is_instance_valid(rp):
			lista.append({
				"nombre": rp.name,
				"posicion": [rp.global_position.x, rp.global_position.y, rp.global_position.z],
				"rotacion": [rp.rotation.x, rp.rotation.y, rp.rotation.z],
				"tipo_via": _obtener_tipo_via_de_punto(rp)
			})
	return lista
