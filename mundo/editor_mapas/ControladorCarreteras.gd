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
signal telemetria_trazo_actualizada(activa: bool, distancia_m: float, pendiente_pct: float)

enum TipoVia {
	CALLE_2_VIAS,
	AVENIDA_4_VIAS,
	AUTOPISTA_6_VIAS,
	TROCHA,
	CALLE_1_CARRIL,
	CARRETERA_NACIONAL,
	DOBLE_CALZADA_8C,
	VIA_ADOQUINADA,
	VIA_RECEBO,
	CICLOVIA_PEATONAL
}

const RUTA_MATERIAL_TROCHA: String = "res://materiales/Mapa/Trocha/Trocha.tres"
const RUTA_KIT_TROCHA_GLB: String = "res://mundo/editor_mapas/modelos/trocha_rural_latinoamericana.glb"
const RUTA_SHADER_VIA_PERS: String = "res://mundo/editor_mapas/via_superficie_personalizada.gdshader"

@export var tipo_via_actual: TipoVia = TipoVia.CALLE_2_VIAS
@export var elevacion_sobre_terreno: float = 0.25
@export var auto_nivelar_al_trazar: bool = true
@export var umbral_altura_puente: float = 3.0

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
var snap_angulo_activo: bool = true
var modo_mejorar_via: bool = false
var angulo_trazo_actual: float = 0.0
var _angulo_snap_activo_actual: bool = false
var _pos_cursor_snapped: Vector3 = Vector3.ZERO
var _punto_origen_conexion: RoadPoint = null
var rotacion_cruce_grados: float = 0.0
var subherramienta_via_actual: String = "calle_2"
var rotonda_salidas: int = 4
var _marcador_preview_cruce: Node3D = null
var _marcador_preview_rotonda: Node3D = null
var _salidas_preview_rotonda: int = 0
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
	_crear_marcador_preview_rotonda()
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

func _crear_marcador_preview_rotonda() -> void:
	if _marcador_preview_rotonda and is_instance_valid(_marcador_preview_rotonda):
		_marcador_preview_rotonda.queue_free()
	_marcador_preview_rotonda = Node3D.new()
	_marcador_preview_rotonda.name = "MarcadorPreviewRotonda"

	var n_sal: int = clampi(rotonda_salidas, 3, 6)
	_salidas_preview_rotonda = n_sal

	var mat_ghost := StandardMaterial3D.new()
	mat_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_ghost.albedo_color = Color(0.88, 0.68, 0.28, 0.45)
	mat_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_ghost.no_depth_test = true
	mat_ghost.render_priority = 10

	var ruta_glb := "res://mundo/editor_mapas/modelos/rotonda_%d_salidas.glb" % n_sal
	if ResourceLoader.exists(ruta_glb):
		var esc_rot := load(ruta_glb) as PackedScene
		if esc_rot:
			var inst := esc_rot.instantiate()
			_aplicar_material_fantasma_recursivo(inst, mat_ghost)
			_marcador_preview_rotonda.add_child(inst)

	# Indicadores de acceso radiales para ver dónde quedarán los puntos de conexión
	var ancho_via: float = _obtener_ancho_total_via(tipo_via_actual)
	var r_outer: float = 18.0 + ancho_via * 0.5
	for i in range(n_sal):
		var ang: float = float(i) * (TAU / float(n_sal))
		var rad := Vector3(cos(ang), 0.0, -sin(ang))
		var mi_acc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6
		cyl.bottom_radius = 1.6
		cyl.height = 0.25
		mi_acc.mesh = cyl
		mi_acc.material_override = mat_ghost
		mi_acc.position = rad * (r_outer + 11.5)
		_marcador_preview_rotonda.add_child(mi_acc)

	_marcador_preview_rotonda.visible = false
	add_child(_marcador_preview_rotonda)

func _aplicar_material_fantasma_recursivo(nodo: Node, mat: Material) -> void:
	if nodo is MeshInstance3D:
		(nodo as MeshInstance3D).material_override = mat
	for hijo in nodo.get_children():
		_aplicar_material_fantasma_recursivo(hijo, mat)

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

func iniciar_conexion_desde_punto(rp: RoadPoint) -> bool:
	if not is_instance_valid(rp):
		return false
	activar_modo_conexion()
	_punto_origen_conexion = rp
	seleccionar_punto_carretera(null)
	if _marcador_seleccion_conexion:
		_marcador_seleccion_conexion.global_position = rp.global_position + Vector3(0, 0.15, 0)
		_marcador_seleccion_conexion.visible = true
	carretera_actualizada.emit()
	return true

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
	var es_rotonda = (subherramienta_via_actual == "rotonda")
	
	if not visible_en_pantalla:
		if _contenedor_seleccionadores_puntos:
			_contenedor_seleccionadores_puntos.visible = false
		if _linea_instance:
			_linea_instance.visible = false
		if _marcador_preview:
			_marcador_preview.visible = false
		if _marcador_preview_cruce:
			_marcador_preview_cruce.visible = false
		if _marcador_preview_rotonda:
			_marcador_preview_rotonda.visible = false
		if _marcador_seleccion_conexion and _punto_origen_conexion == null:
			_marcador_seleccion_conexion.visible = false
		punto_snap_detectado = null
		telemetria_trazo_actualizada.emit(false, 0.0, 0.0)
		return
		
	if _contenedor_seleccionadores_puntos:
		_contenedor_seleccionadores_puntos.visible = true

	if es_rotonda:
		if _marcador_preview:
			_marcador_preview.visible = false
		if _linea_instance:
			_linea_instance.visible = false
		if _marcador_preview_cruce:
			_marcador_preview_cruce.visible = false
		if _salidas_preview_rotonda != clampi(rotonda_salidas, 3, 6) or not is_instance_valid(_marcador_preview_rotonda):
			_crear_marcador_preview_rotonda()
		if _marcador_preview_rotonda:
			_marcador_preview_rotonda.visible = true
			_marcador_preview_rotonda.global_position = target_pos + Vector3(0.0, 0.25, 0.0)
		telemetria_trazo_actualizada.emit(false, 0.0, 0.0)
		return

	if _marcador_preview_rotonda:
		_marcador_preview_rotonda.visible = false
		
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
	_angulo_snap_activo_actual = false
	
	var es_snap_valido = (punto_snap != null and punto_snap != _ultimo_road_point and punto_snap != _punto_origen_conexion)
	var ref_pt: RoadPoint = _punto_origen_conexion if modo_conectar_activo else _ultimo_road_point
	
	if es_snap_valido:
		target_pos = punto_snap.global_position + Vector3(0, 0.1, 0)
		# Feedback visual de acople / snap (Cian brillante)
		if _marcador_preview.material_override:
			_marcador_preview.material_override.albedo_color = Color(0.2, 0.85, 1.0, 0.95)
	else:
		if snap_angulo_activo and ref_pt and is_instance_valid(ref_pt):
			var snapped_xz := _aplicar_snap_angulo(ref_pt.global_position, target_pos)
			if snapped_xz != target_pos:
				target_pos = snapped_xz
				_angulo_snap_activo_actual = true
		# Cursor normal (Ámbar) o Esmeralda si está alineado a 45°/90°
		if _marcador_preview.material_override:
			_marcador_preview.material_override.albedo_color = Color(0.25, 0.92, 0.55, 0.95) if _angulo_snap_activo_actual else Color(0.88, 0.68, 0.28, 0.85)
			
	_pos_cursor_snapped = target_pos
	_marcador_preview.global_position = target_pos
	
	# Si hay un punto de referencia activo (último punto trazado o primer punto de conexión), actualizar línea guía
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
		var dist_h: float = Vector2(target_pos.x - ref_pt.global_position.x, target_pos.z - ref_pt.global_position.z).length()
		var dy: float = absf(target_pos.y - ref_pt.global_position.y)
		var pend_pct: float = (dy / maxf(dist_h, 0.5)) * 100.0
		telemetria_trazo_actualizada.emit(true, dist_h, pend_pct)
	else:
		if _linea_instance:
			_linea_instance.visible = false
		telemetria_trazo_actualizada.emit(false, 0.0, 0.0)
			
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
		TipoVia.CALLE_1_CARRIL:
			return 1.0 * 4.0 + 2.0 * 0.4 # 4.8m
		TipoVia.CARRETERA_NACIONAL:
			return 2.0 * 4.0 + 2.0 * 2.2 # 12.4m
		TipoVia.AVENIDA_4_VIAS:
			return 4.0 * 3.5 + 2.0 * 1.2 # 16.4m
		TipoVia.AUTOPISTA_6_VIAS:
			return 6.0 * 3.6 + 2.0 * 1.8 # 25.2m
		TipoVia.DOBLE_CALZADA_8C:
			return 8.0 * 3.6 + 2.0 * 2.2 # 33.2m
		TipoVia.VIA_ADOQUINADA:
			return 2.0 * 3.3 + 2.0 * 0.6 # 7.8m
		TipoVia.VIA_RECEBO:
			return 2.0 * 3.4 + 2.0 * 0.6 # 8.0m
		TipoVia.CICLOVIA_PEATONAL:
			return 1.0 * 2.6 + 2.0 * 0.3 # 3.2m
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

func continuar_trazo_desde_punto(rp: RoadPoint) -> bool:
	if not is_instance_valid(rp):
		return false
	var tiene_puerto_libre: bool = rp.prior_pt_init.is_empty() or rp.next_pt_init.is_empty()
	if not tiene_puerto_libre:
		return false
	tipo_via_actual = _obtener_tipo_via_de_punto(rp)
	_ultimo_road_point = rp
	seleccionar_punto_carretera(null)
	carretera_actualizada.emit()
	return true

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
		if auto_nivelar_al_trazar:
			adaptar_terreno_en_tramo(obtener_segmentos_de_punto(rp))
		else:
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
	if rp.has_meta("tipo_via"):
		var tv := int(rp.get_meta("tipo_via", 0))
		if tv >= 0 and tv <= int(TipoVia.CICLOVIA_PEATONAL):
			return tv as TipoVia
	if bool(rp.get_meta("es_trocha", false)):
		return TipoVia.TROCHA
	if rp.traffic_dir.size() >= 8:
		return TipoVia.DOBLE_CALZADA_8C
	elif rp.traffic_dir.size() >= 6:
		return TipoVia.AUTOPISTA_6_VIAS
	elif rp.traffic_dir.size() >= 4:
		return TipoVia.AVENIDA_4_VIAS
	elif rp.traffic_dir.size() == 1:
		return TipoVia.CALLE_1_CARRIL
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
			return _obtener_tipo_via_de_punto(rp)
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
		"flatten_terrain": cruce_seleccionado.flatten_terrain,
		"control_trafico": str(cruce_seleccionado.get_meta("control_trafico", "semaforo"))
	}

func establecer_control_cruce_seleccionado(modo: String) -> void:
	if is_instance_valid(cruce_seleccionado):
		cruce_seleccionado.set_meta("control_trafico", modo)

func _aplicar_snap_angulo(origen: Vector3, destino: Vector3) -> Vector3:
	var dv := Vector2(destino.x - origen.x, destino.z - origen.z)
	var dist := dv.length()
	if dist < 2.0:
		return destino
	var ang := atan2(dv.y, dv.x)
	var paso := PI * 0.25 # 45 grados
	var ang_snap := roundf(ang / paso) * paso
	if absf(wrapf(ang - ang_snap, -PI, PI)) <= deg_to_rad(6.5):
		angulo_trazo_actual = wrapf(rad_to_deg(ang_snap), 0.0, 360.0)
		var nuevo := Vector3(origen.x + cos(ang_snap) * dist, destino.y, origen.z + sin(ang_snap) * dist)
		if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
			nuevo.y = float(controlador_terreno.obtener_altura(nuevo)) + elevacion_sobre_terreno + 0.05
		return nuevo
	angulo_trazo_actual = wrapf(rad_to_deg(ang), 0.0, 360.0)
	return destino

func obtener_posicion_trazo_snapped(pos_mundo: Vector3) -> Vector3:
	if _angulo_snap_activo_actual and _pos_cursor_snapped != Vector3.ZERO:
		return _pos_cursor_snapped
	return pos_mundo

func cambiar_elevacion_paso(delta_m: float) -> float:
	elevacion_sobre_terreno = clampf(elevacion_sobre_terreno + delta_m, -15.0, 24.0)
	return elevacion_sobre_terreno

func resetear_elevacion() -> float:
	elevacion_sobre_terreno = 0.0
	return 0.0

func mejorar_segmento_en_posicion(pos_mundo: Vector3, nuevo_tipo: int) -> bool:
	if not road_container or not is_instance_valid(road_container):
		return false
	var mejor_seg: RoadSegment = null
	var mejor_d := 12.0
	for obj in road_container.get_segments():
		var seg := obj as RoadSegment
		if not is_instance_valid(seg) or not seg.curve:
			continue
		var loc := seg.to_local(pos_mundo) if seg.is_inside_tree() else (pos_mundo - seg.position)
		var cl := seg.curve.get_closest_point(loc)
		var w_cl := seg.to_global(cl) if seg.is_inside_tree() else (seg.position + cl)
		var d := pos_mundo.distance_to(w_cl)
		if d < mejor_d:
			mejor_d = d
			mejor_seg = seg
	if mejor_seg:
		var arr: Array[RoadSegment] = [mejor_seg]
		cambiar_tipo_via_segmentos(arr, nuevo_tipo)
		return true
	return false

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
		TipoVia.CALLE_1_CARRIL:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 4.0
			rp.shoulder_width_l = 0.4
			rp.shoulder_width_r = 0.4
		TipoVia.CALLE_2_VIAS:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 3.6
			rp.shoulder_width_l = 0.8
			rp.shoulder_width_r = 0.8
		TipoVia.CARRETERA_NACIONAL:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 4.0
			rp.shoulder_width_l = 2.2
			rp.shoulder_width_r = 2.2
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
		TipoVia.DOBLE_CALZADA_8C:
			var dirs: Array[RoadPoint.LaneDir] = [
				RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.REVERSE,
				RoadPoint.LaneDir.FORWARD, RoadPoint.LaneDir.FORWARD, RoadPoint.LaneDir.FORWARD, RoadPoint.LaneDir.FORWARD
			]
			rp.traffic_dir = dirs
			rp.lane_width = 3.6
			rp.shoulder_width_l = 2.2
			rp.shoulder_width_r = 2.2
		TipoVia.VIA_ADOQUINADA:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 3.3
			rp.shoulder_width_l = 0.6
			rp.shoulder_width_r = 0.6
			if not rp.has_meta("superficie_via"):
				rp.set_meta("superficie_via", 3)
			if not rp.has_meta("demarcacion_via"):
				rp.set_meta("demarcacion_via", 3)
		TipoVia.VIA_RECEBO:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.REVERSE, RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 3.4
			rp.shoulder_width_l = 0.6
			rp.shoulder_width_r = 0.6
			if not rp.has_meta("superficie_via"):
				rp.set_meta("superficie_via", 4)
			if not rp.has_meta("demarcacion_via"):
				rp.set_meta("demarcacion_via", 3)
		TipoVia.CICLOVIA_PEATONAL:
			var dirs: Array[RoadPoint.LaneDir] = [RoadPoint.LaneDir.FORWARD]
			rp.traffic_dir = dirs
			rp.lane_width = 2.6
			rp.shoulder_width_l = 0.3
			rp.shoulder_width_r = 0.3
			if not rp.has_meta("superficie_via"):
				rp.set_meta("superficie_via", 5)
			if not rp.has_meta("demarcacion_via"):
				rp.set_meta("demarcacion_via", 3)
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
			var sup := 0
			var dem := 0
			if is_instance_valid(seg.start_point):
				sup = int(seg.start_point.get_meta("superficie_via", 0))
				dem = int(seg.start_point.get_meta("demarcacion_via", 0))
			if (sup == 0 and dem == 0) and is_instance_valid(seg.end_point):
				sup = int(seg.end_point.get_meta("superficie_via", 0))
				dem = int(seg.end_point.get_meta("demarcacion_via", 0))
			if sup > 0 or dem > 0:
				_aplicar_estilo_personalizado_a_segmento(seg, sup, dem)
			elif (_mat_trocha_via and seg.material == _mat_trocha_via) or seg.has_meta("estilo_pers_aplicado"):
				seg.remove_meta("estilo_pers_aplicado")
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
	_normalizar_uvs_curva_segmento(seg, _mat_trocha_via, _mat_trocha_talud)

func _aplicar_estilo_personalizado_a_segmento(seg: RoadSegment, superficie: int, _demarcacion: int) -> void:
	if not is_instance_valid(seg.road_mesh):
		return
	if superficie <= 0:
		if seg.has_meta("estilo_pers_aplicado"):
			seg.remove_meta("estilo_pers_aplicado")
			seg.material = road_container.material_resource
			seg.road_mesh.set_surface_override_material(0, road_container.material_resource)
		return
	var mat_p := StandardMaterial3D.new()
	mat_p.uv1_triplanar = true
	mat_p.uv1_world_triplanar = true
	mat_p.uv1_scale = Vector3(0.22, 0.22, 0.22)
	var ruta_alb := "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris.png"
	var ruta_nrm := "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris_normal.png"
	match superficie:
		1: # Asfalto Nuevo
			mat_p.albedo_color = Color(0.18, 0.19, 0.21)
			mat_p.roughness = 0.68
		2: # Asfalto Desgastado
			mat_p.albedo_color = Color(0.45, 0.46, 0.47)
			mat_p.roughness = 0.88
		3: # Adoquín
			mat_p.albedo_color = Color(0.72, 0.66, 0.58)
			mat_p.roughness = 0.85
			mat_p.uv1_scale = Vector3(0.35, 0.35, 0.35)
		4: # Recebo
			ruta_alb = "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cascajo_recebo.png"
			ruta_nrm = "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cascajo_recebo_normal.png"
			mat_p.albedo_color = Color(0.92, 0.88, 0.82)
			mat_p.roughness = 0.94
		5: # Ciclovía
			ruta_alb = "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/barro_arcilla.png"
			ruta_nrm = "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/barro_arcilla_normal.png"
			mat_p.albedo_color = Color(0.72, 0.32, 0.24)
			mat_p.roughness = 0.78
	if ResourceLoader.exists(ruta_alb):
		mat_p.albedo_texture = load(ruta_alb)
	if ResourceLoader.exists(ruta_nrm):
		mat_p.normal_enabled = true
		mat_p.normal_texture = load(ruta_nrm)
		mat_p.normal_scale = 0.65
	seg.material = mat_p
	seg.set_meta("estilo_pers_aplicado", true)
	seg.road_mesh.set_surface_override_material(0, mat_p)

func _normalizar_uvs_curva_segmento(seg: RoadSegment, mat_surf0: Material, mat_surf1: Material) -> void:
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
		arr_mesh.surface_set_material(0, mat_surf0)
		if tiene_surf_1 and not arrays_1.is_empty():
			arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_1)
			if mat_surf1:
				arr_mesh.surface_set_material(1, mat_surf1)
		arr_mesh.set_meta("firma_uv_trocha", firma_actual)

	seg.road_mesh.set_surface_override_material(0, mat_surf0)
	if arr_mesh.get_surface_count() > 1 and mat_surf1:
		seg.road_mesh.set_surface_override_material(1, mat_surf1)

func cambiar_tipo_via_segmentos(segs: Array[RoadSegment], nuevo_tipo: int) -> void:
	if not road_container or segs.is_empty():
		return
	var tipo_enum: TipoVia = clampi(nuevo_tipo, 0, int(TipoVia.CICLOVIA_PEATONAL)) as TipoVia
	var puntos_editados: Array[RoadPoint] = []
	for seg in segs:
		if not is_instance_valid(seg):
			continue
		for rp in [seg.start_point, seg.end_point]:
			if is_instance_valid(rp) and not (rp in puntos_editados):
				rp.remove_meta("superficie_via")
				rp.remove_meta("demarcacion_via")
				_aplicar_tipo_via_a_punto(rp, tipo_enum)
				puntos_editados.append(rp)
	if not puntos_editados.is_empty():
		road_container.update_edges()
		road_container.rebuild_segments(true)
		_actualizar_segmentos_trocha()
		carretera_actualizada.emit()

func aplicar_estilo_segmentos(segs: Array[RoadSegment], superficie: int, demarcacion: int) -> void:
	if not road_container or segs.is_empty():
		return
	for seg in segs:
		if not is_instance_valid(seg):
			continue
		for rp in [seg.start_point, seg.end_point]:
			if is_instance_valid(rp):
				if superficie >= 0:
					rp.set_meta("superficie_via", superficie)
				if demarcacion >= 0:
					rp.set_meta("demarcacion_via", demarcacion)
	_actualizar_segmentos_trocha()
	carretera_actualizada.emit()

func buscar_segmento_por_posicion(pos_mundo: Vector3, max_dist: float = 12.0) -> RoadSegment:
	if not road_container or not is_instance_valid(road_container):
		return null
	var mejor_seg: RoadSegment = null
	var mejor_dist := max_dist
	for obj in road_container.get_segments():
		var seg := obj as RoadSegment
		if not is_instance_valid(seg) or not seg.curve:
			continue
		var local_p := seg.to_local(pos_mundo) if seg.is_inside_tree() else (pos_mundo - seg.position)
		var closest_local := seg.curve.get_closest_point(local_p)
		var closest_world := seg.to_global(closest_local) if seg.is_inside_tree() else (seg.position + closest_local)
		var d := Vector2(pos_mundo.x - closest_world.x, pos_mundo.z - closest_world.z).length()
		var ancho := _obtener_ancho_via_punto(seg.start_point) if is_instance_valid(seg.start_point) else 8.8
		var umbral := maxf(max_dist, ancho * 0.65)
		if d < umbral and d < mejor_dist:
			mejor_dist = d
			mejor_seg = seg
	return mejor_seg

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

	var edge_margin := 1.1
	var edge_falloff := 4.5
	var offset_y := -0.08 # Nivelar a 8 cm por debajo del borde superior de la calzada

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
							# Si la montaña supera los 12.0m por encima de la vía, conservar la montaña intacta para generar túnel
							var es_montana_tunel: bool = (curr_h >= target_road_bed + 12.0)
							# Si la vía va en viaducto (umbral_altura_puente+ sobre el terreno), no rellenar el valle salvo que se fuerce
							var es_valle_puente: bool = (not forzar_adaptacion) and (target_road_bed - curr_h >= umbral_altura_puente)
							if not es_montana_tunel and not es_valle_puente:
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
			if rp.get_parent() == road_container:
				road_container.remove_child(rp)
			rp.queue_free()
	_puntos_creados.clear()
	if road_container and is_instance_valid(road_container):
		for child in road_container.get_children().duplicate():
			if child is RoadPoint or child is RoadIntersection or child is RoadSegment or child.is_in_group("rotonda_islas"):
				road_container.remove_child(child)
				child.queue_free()
	_historial_acciones.clear()
	_ultimo_road_point = null
	cruce_seleccionado = null
	ramal_cruce_seleccionado = null
	punto_carretera_seleccionado = null
	if _linea_instance:
		_linea_instance.visible = false
	if road_container:
		road_container.rebuild_segments(true)
	actualizar_seleccionadores_puntos()
	carretera_actualizada.emit()

func crear_rotonda(pos_mundo: Vector3, radio: float = 18.0, num_salidas: int = -1) -> Dictionary:
	if not road_container:
		return {"exito": false}
	var centro := _ajustar_altura_a_terreno(pos_mundo)
	var r: float = clampf(radio, 14.0, 40.0)
	var n_sal: int = clampi(num_salidas if num_salidas >= 3 else rotonda_salidas, 3, 6)
	var ancho_via: float = _obtener_ancho_total_via(tipo_via_actual)
	var r_outer: float = r + ancho_via * 0.5
	var rps_ext: Array[RoadPoint] = []
	var todos_rps: Array[RoadPoint] = []
	var base_idx := _puntos_creados.size() + 1

	for i in range(n_sal):
		var ang: float = float(i) * (TAU / float(n_sal))
		# Mapeo exacto Blender (X, Y) -> Godot (X, -Z) tras export_yup=True
		var rad := Vector3(cos(ang), 0.0, -sin(ang))
		var rp_in := RoadPoint.new()
		rp_in.name = "Rotonda_%d_In_%d" % [base_idx, i + 1]
		rp_in.container = road_container
		road_container.add_child(rp_in)
		rp_in.global_position = centro + rad * (r_outer + 3.8)
		rp_in.global_transform.basis = Basis.looking_at(-rad, Vector3.UP)
		_configurar_tipo_via(rp_in)
		rp_in.set_meta("es_rotonda", true)
		_puntos_creados.append(rp_in)
		todos_rps.append(rp_in)

		var rp_out := RoadPoint.new()
		rp_out.name = "Rotonda_%d_Acceso_%d" % [base_idx, i + 1]
		rp_out.container = road_container
		road_container.add_child(rp_out)
		rp_out.global_position = centro + rad * (r_outer + 11.5)
		rp_out.global_transform.basis = Basis.looking_at(-rad, Vector3.UP)
		_configurar_tipo_via(rp_out)
		rp_out.set_meta("es_rotonda", true)
		_puntos_creados.append(rp_out)
		todos_rps.append(rp_out)
		rps_ext.append(rp_out)

		rp_in.connect_roadpoint(RoadPoint.PointInit.NEXT, rp_out, RoadPoint.PointInit.PRIOR)

	_crear_isla_rotonda(centro, r, n_sal)
	_actualizar_orientaciones_y_curvaturas()
	road_container.rebuild_segments(true)
	if auto_nivelar_al_trazar:
		for rp in todos_rps:
			adaptar_terreno_en_tramo(obtener_segmentos_de_punto(rp))
	else:
		nivelar_terreno_bajo_carreteras()
	actualizar_seleccionadores_puntos()
	carretera_actualizada.emit()
	return {"exito": true, "centro": centro, "puntos": todos_rps, "accesos": rps_ext}

func _crear_isla_rotonda(centro: Vector3, radio_anillo: float, num_salidas: int = 4) -> void:
	if not road_container:
		return
	var ancho_via: float = maxf(8.0, _obtener_ancho_total_via(tipo_via_actual))
	var r_in: float = maxf(6.0, radio_anillo - ancho_via * 0.5)
	var r_out: float = radio_anillo + ancho_via * 0.5
	var n_sal: int = clampi(num_salidas, 3, 6)

	var isla := StaticBody3D.new()
	isla.name = "IslaRotonda_%d" % (_puntos_creados.size())
	isla.add_to_group("rotonda_islas")
	isla.set_meta("radio_anillo", radio_anillo)
	isla.set_meta("salidas", n_sal)
	road_container.add_child(isla)
	isla.global_position = centro

	# Usar modelo procedural de alta calidad creado en Blender (3, 4, 5 o 6 salidas)
	var ruta_glb := "res://mundo/editor_mapas/modelos/rotonda_%d_salidas.glb" % n_sal
	if not ResourceLoader.exists(ruta_glb):
		ruta_glb = "res://mundo/editor_mapas/modelos/rotonda_procedural.glb"
	if ResourceLoader.exists(ruta_glb):
		var escena_rotonda := load(ruta_glb) as PackedScene
		if escena_rotonda:
			var modelo := escena_rotonda.instantiate()
			var esc: float = radio_anillo / 18.0
			if modelo is Node3D:
				(modelo as Node3D).scale = Vector3(esc, 1.0, esc)
			isla.add_child(modelo)
			# Colisión de calzada + isla central para conducción vehicular
			var col_calzada := CollisionShape3D.new()
			var shp_calzada := CylinderShape3D.new()
			shp_calzada.radius = 23.0 * esc
			shp_calzada.height = 0.08
			col_calzada.shape = shp_calzada
			col_calzada.position = Vector3(0.0, 0.0, 0.0)
			isla.add_child(col_calzada)

			var col_isla := CollisionShape3D.new()
			var shp_isla := CylinderShape3D.new()
			shp_isla.radius = 12.6 * esc
			shp_isla.height = 1.2
			col_isla.shape = shp_isla
			col_isla.position = Vector3(0.0, 0.6, 0.0)
			isla.add_child(col_isla)
			return

	# 1. Anillo circular perfecto de asfalto (48 segmentos)
	var st_asf := SurfaceTool.new()
	st_asf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 48
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p_in0 := Vector3(cos(a0) * r_in, 0.04, sin(a0) * r_in)
		var p_in1 := Vector3(cos(a1) * r_in, 0.04, sin(a1) * r_in)
		var p_out0 := Vector3(cos(a0) * r_out, 0.04, sin(a0) * r_out)
		var p_out1 := Vector3(cos(a1) * r_out, 0.04, sin(a1) * r_out)
		st_asf.set_normal(Vector3.UP)
		st_asf.add_vertex(p_in0); st_asf.add_vertex(p_out0); st_asf.add_vertex(p_out1)
		st_asf.set_normal(Vector3.UP)
		st_asf.add_vertex(p_in0); st_asf.add_vertex(p_out1); st_asf.add_vertex(p_in1)
	var mesh_asf := st_asf.commit()
	var mi_asf := MeshInstance3D.new()
	mi_asf.mesh = mesh_asf
	var mat_asf := StandardMaterial3D.new()
	mat_asf.albedo_color = Color(0.39, 0.40, 0.42)
	mat_asf.roughness = 0.88
	mi_asf.material_override = mat_asf
	isla.add_child(mi_asf)

	# 1b. Empalmes abocinados curvos en las 4 entradas (N, E, S, O) para transición suave sin cortes rectangulares
	var st_apr := SurfaceTool.new()
	st_apr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w: float = ancho_via * 0.5
	var angs_ent := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for ang_c: float in angs_ent:
		var fwd := Vector3(cos(ang_c), 0.0, sin(ang_c))
		var lat := Vector3(-fwd.z, 0.0, fwd.x)
		var pasos_f: int = 8
		for k in range(pasos_f):
			var t0: float = float(k) / float(pasos_f)
			var t1: float = float(k + 1) / float(pasos_f)
			var dist0: float = lerpf(r_out - 0.5, r_out + 4.1, t0)
			var dist1: float = lerpf(r_out - 0.5, r_out + 4.1, t1)
			var w0: float = lerpf(half_w + 5.2, half_w + 0.05, pow(t0, 0.55))
			var w1: float = lerpf(half_w + 5.2, half_w + 0.05, pow(t1, 0.55))
			var a0 := fwd * dist0 - lat * w0 + Vector3(0, 0.042, 0)
			var b0 := fwd * dist0 + lat * w0 + Vector3(0, 0.042, 0)
			var a1 := fwd * dist1 - lat * w1 + Vector3(0, 0.042, 0)
			var b1 := fwd * dist1 + lat * w1 + Vector3(0, 0.042, 0)
			st_apr.set_normal(Vector3.UP)
			st_apr.add_vertex(a0); st_apr.add_vertex(b0); st_apr.add_vertex(b1)
			st_apr.set_normal(Vector3.UP)
			st_apr.add_vertex(a0); st_apr.add_vertex(b1); st_apr.add_vertex(a1)
	var mi_apr := MeshInstance3D.new()
	mi_apr.mesh = st_apr.commit()
	mi_apr.material_override = mat_asf
	isla.add_child(mi_apr)

	# Colisión del anillo para conducir encima
	var col_asf := CollisionShape3D.new()
	var cyl_col := CylinderShape3D.new()
	cyl_col.radius = r_out
	cyl_col.height = 0.16
	col_asf.shape = cyl_col
	col_asf.position.y = -0.02
	isla.add_child(col_asf)

	# 2. Línea amarilla interior y trazos blancos discontinuos del carril
	var mat_amarillo := StandardMaterial3D.new()
	mat_amarillo.albedo_color = Color(0.95, 0.78, 0.18)
	mat_amarillo.roughness = 0.6
	var mat_blanco := StandardMaterial3D.new()
	mat_blanco.albedo_color = Color(0.94, 0.95, 0.96)
	mat_blanco.roughness = 0.65

	var st_lin := SurfaceTool.new()
	st_lin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r_l0: float = r_in + 0.35
	var r_l1: float = r_in + 0.55
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		st_lin.set_normal(Vector3.UP)
		st_lin.add_vertex(Vector3(cos(a0) * r_l0, 0.055, sin(a0) * r_l0))
		st_lin.add_vertex(Vector3(cos(a0) * r_l1, 0.055, sin(a0) * r_l1))
		st_lin.add_vertex(Vector3(cos(a1) * r_l1, 0.055, sin(a1) * r_l1))
		st_lin.set_normal(Vector3.UP)
		st_lin.add_vertex(Vector3(cos(a0) * r_l0, 0.055, sin(a0) * r_l0))
		st_lin.add_vertex(Vector3(cos(a1) * r_l1, 0.055, sin(a1) * r_l1))
		st_lin.add_vertex(Vector3(cos(a1) * r_l0, 0.055, sin(a1) * r_l0))
	var mi_lin := MeshInstance3D.new()
	mi_lin.mesh = st_lin.commit()
	mi_lin.material_override = mat_amarillo
	isla.add_child(mi_lin)

	# Línea discontinua central del anillo
	var st_dash := SurfaceTool.new()
	st_dash.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r_d0: float = radio_anillo - 0.12
	var r_d1: float = radio_anillo + 0.12
	for i in range(segs):
		if i % 2 == 1:
			continue
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 0.65) / float(segs)) * TAU
		st_dash.set_normal(Vector3.UP)
		st_dash.add_vertex(Vector3(cos(a0) * r_d0, 0.055, sin(a0) * r_d0))
		st_dash.add_vertex(Vector3(cos(a0) * r_d1, 0.055, sin(a0) * r_d1))
		st_dash.add_vertex(Vector3(cos(a1) * r_d1, 0.055, sin(a1) * r_d1))
		st_dash.set_normal(Vector3.UP)
		st_dash.add_vertex(Vector3(cos(a0) * r_d0, 0.055, sin(a0) * r_d0))
		st_dash.add_vertex(Vector3(cos(a1) * r_d1, 0.055, sin(a1) * r_d1))
		st_dash.add_vertex(Vector3(cos(a1) * r_d0, 0.055, sin(a1) * r_d0))
	var mi_dash := MeshInstance3D.new()
	mi_dash.mesh = st_dash.commit()
	mi_dash.material_override = mat_blanco
	isla.add_child(mi_dash)

	# Líneas blancas de Ceda el Paso en cada una de las 4 entradas
	var st_ceda := SurfaceTool.new()
	st_ceda.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ang_c: float in [-PI * 0.5, 0.0, PI * 0.5, PI]:
		var fwd := Vector3(cos(ang_c), 0.0, sin(ang_c))
		var lat := Vector3(-fwd.z, 0.0, fwd.x)
		var base_c := fwd * (r_out + 0.6) + Vector3(0, 0.058, 0)
		var num_c := 5
		for ci in range(num_c):
			var u := -half_w * 0.85 + (float(ci) / float(num_c - 1)) * (half_w * 1.7)
			var p_c := base_c + lat * u
			var c0 := p_c - lat * 0.35 - fwd * 0.18
			var c1 := p_c + lat * 0.35 - fwd * 0.18
			var c2 := p_c + lat * 0.35 + fwd * 0.18
			var c3 := p_c - lat * 0.35 + fwd * 0.18
			st_ceda.set_normal(Vector3.UP)
			st_ceda.add_vertex(c0); st_ceda.add_vertex(c1); st_ceda.add_vertex(c2)
			st_ceda.set_normal(Vector3.UP)
			st_ceda.add_vertex(c0); st_ceda.add_vertex(c2); st_ceda.add_vertex(c3)
	var mi_ceda := MeshInstance3D.new()
	mi_ceda.mesh = st_ceda.commit()
	mi_ceda.material_override = mat_blanco
	isla.add_child(mi_ceda)

	# 3. Bordillo elevado e isla central con textura realista de césped
	var bordillo := MeshInstance3D.new()
	var cyl_b := CylinderMesh.new()
	cyl_b.top_radius = r_in - 0.1
	cyl_b.bottom_radius = r_in + 0.25
	cyl_b.height = 0.28
	cyl_b.radial_segments = 48
	bordillo.mesh = cyl_b
	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.68, 0.70, 0.72)
	mat_b.roughness = 0.85
	bordillo.material_override = mat_b
	bordillo.position.y = 0.14
	isla.add_child(bordillo)

	var cesped := MeshInstance3D.new()
	var cyl_c := CylinderMesh.new()
	cyl_c.top_radius = maxf(3.0, r_in - 0.55)
	cyl_c.bottom_radius = maxf(3.0, r_in - 0.45)
	cyl_c.height = 0.22
	cyl_c.radial_segments = 48
	cesped.mesh = cyl_c
	var mat_c := StandardMaterial3D.new()
	var tex_cesped := "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde.png"
	if ResourceLoader.exists(tex_cesped):
		mat_c.albedo_texture = load(tex_cesped)
		mat_c.albedo_color = Color(0.76, 0.82, 0.72)
		mat_c.uv1_scale = Vector3(3.0, 3.0, 3.0)
	else:
		mat_c.albedo_color = Color(0.22, 0.42, 0.17)
	mat_c.roughness = 0.95
	cesped.material_override = mat_c
	cesped.position.y = 0.20
	isla.add_child(cesped)

	# Monumento / jardinera central sutil para darle carácter urbano
	var base_mon := MeshInstance3D.new()
	var cyl_m := CylinderMesh.new()
	cyl_m.top_radius = 2.2
	cyl_m.bottom_radius = 2.6
	cyl_m.height = 0.55
	cyl_m.radial_segments = 24
	base_mon.mesh = cyl_m
	base_mon.material_override = mat_b
	base_mon.position.y = 0.48
	isla.add_child(base_mon)

func buscar_segmento_cercano(pos_mundo: Vector3, radio_max: float = 9.0) -> Dictionary:
	if not road_container or not is_instance_valid(road_container):
		return {}
	var mejor_seg: RoadSegment = null
	var mejor_dist: float = radio_max
	var mejor_pos: Vector3 = pos_mundo
	for seg in road_container.get_segments():
		if not is_instance_valid(seg) or not seg.curve:
			continue
		var local_p: Vector3 = seg.to_local(pos_mundo)
		var offset: float = seg.curve.get_closest_offset(local_p)
		var punto_curva: Vector3 = seg.to_global(seg.curve.sample_baked(offset))
		var d: float = Vector2(punto_curva.x - pos_mundo.x, punto_curva.z - pos_mundo.z).length()
		if d < mejor_dist:
			mejor_dist = d
			mejor_seg = seg
			mejor_pos = punto_curva
	if mejor_seg:
		return {"segmento": mejor_seg, "posicion": mejor_pos, "distancia": mejor_dist}
	return {}

func insertar_punto_en_segmento(seg: RoadSegment, pos_mundo: Vector3) -> RoadPoint:
	if not road_container or not is_instance_valid(seg):
		return null
	var rp_a: RoadPoint = seg.start_point
	var rp_b: RoadPoint = seg.end_point
	if not is_instance_valid(rp_a) or not is_instance_valid(rp_b):
		return null

	var tipo_seg := _obtener_tipo_via_de_punto(rp_a)
	var pos_exacta := pos_mundo
	if seg.curve:
		var off: float = seg.curve.get_closest_offset(seg.to_local(pos_mundo))
		pos_exacta = seg.to_global(seg.curve.sample_baked(off))

	var a_era_next := (rp_a.get_node_or_null(rp_a.next_pt_init) == rp_b)
	_desconectar_puntos(rp_a, rp_b)

	var nuevo_rp := _crear_nodo_road_point(pos_exacta)
	_aplicar_tipo_via_a_punto(nuevo_rp, tipo_seg)

	if a_era_next:
		rp_a.connect_roadpoint(RoadPoint.PointInit.NEXT, nuevo_rp, RoadPoint.PointInit.PRIOR)
		nuevo_rp.connect_roadpoint(RoadPoint.PointInit.NEXT, rp_b, RoadPoint.PointInit.PRIOR)
	else:
		rp_a.connect_roadpoint(RoadPoint.PointInit.PRIOR, nuevo_rp, RoadPoint.PointInit.NEXT)
		nuevo_rp.connect_roadpoint(RoadPoint.PointInit.PRIOR, rp_b, RoadPoint.PointInit.NEXT)

	_actualizar_orientaciones_y_curvaturas()
	road_container.rebuild_segments(true)
	actualizar_seleccionadores_puntos()
	carretera_actualizada.emit()
	return nuevo_rp

func serializar_carreteras() -> Array:
	var puntos_data: Array = []
	for rp in _puntos_creados:
		if not is_instance_valid(rp):
			continue
		var prior_n := ""
		if not rp.prior_pt_init.is_empty():
			var np = rp.get_node_or_null(rp.prior_pt_init)
			if is_instance_valid(np):
				prior_n = np.name
		var next_n := ""
		if not rp.next_pt_init.is_empty():
			var nn = rp.get_node_or_null(rp.next_pt_init)
			if is_instance_valid(nn):
				next_n = nn.name
		puntos_data.append({
			"nombre": rp.name,
			"posicion": [rp.position.x, rp.position.y, rp.position.z],
			"rotacion": [rp.rotation.x, rp.rotation.y, rp.rotation.z],
			"prior_mag": rp.prior_mag,
			"next_mag": rp.next_mag,
			"tipo_via": int(_obtener_tipo_via_de_punto(rp)),
			"prior": prior_n,
			"next": next_n,
			"offset_y": float(rp.get_meta("offset_y", 0.0)),
			"peralte_grados": float(rp.get_meta("peralte_grados", 0.0)),
			"superficie_via": int(rp.get_meta("superficie_via", 0)),
			"demarcacion_via": int(rp.get_meta("demarcacion_via", 0)),
			"es_rotonda": bool(rp.get_meta("es_rotonda", false))
		})

	var inter_data: Array = []
	var islas_data: Array = []
	if road_container and is_instance_valid(road_container):
		for child in road_container.get_children():
			if child is RoadIntersection:
				var inter := child as RoadIntersection
				var ramales_nombres: Array = []
				for rp_ep in inter.edge_points:
					if is_instance_valid(rp_ep):
						ramales_nombres.append(rp_ep.name)
				inter_data.append({
					"nombre": inter.name,
					"posicion": [inter.position.x, inter.position.y, inter.position.z],
					"rotacion": [inter.rotation.x, inter.rotation.y, inter.rotation.z],
					"ramales": ramales_nombres
				})
			elif child.is_in_group("rotonda_islas"):
				islas_data.append({
					"posicion": [child.global_position.x, child.global_position.y, child.global_position.z],
					"radio": float(child.get_meta("radio_anillo", 18.0)),
					"salidas": int(child.get_meta("salidas", 4))
				})

	return [{
		"formato": 2,
		"puntos": puntos_data,
		"intersecciones": inter_data,
		"islas_rotonda": islas_data
	}]

func deserializar_carreteras(datos: Array) -> void:
	if not road_container or not is_instance_valid(road_container):
		return
	limpiar_todas_las_carreteras()
	if datos.is_empty():
		return

	var puntos_data: Array = datos
	var inter_data: Array = []
	var islas_data: Array = []
	if datos[0] is Dictionary and int(datos[0].get("formato", 1)) == 2:
		puntos_data = datos[0].get("puntos", [])
		inter_data = datos[0].get("intersecciones", [])
		islas_data = datos[0].get("islas_rotonda", [])

	var mapa_rps: Dictionary = {}
	var faltan_tangentes := false
	for item in puntos_data:
		if not (item is Dictionary):
			continue
		var rp := RoadPoint.new()
		var nombre_item := str(item.get("nombre", "RP_%d" % (_puntos_creados.size() + 1)))
		rp.name = nombre_item
		rp.container = road_container
		var pos_arr: Array = item.get("posicion", [0.0, 0.0, 0.0])
		if pos_arr.size() >= 3:
			rp.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		var rot_arr: Array = item.get("rotacion", [0.0, 0.0, 0.0])
		if rot_arr.size() >= 3:
			rp.rotation = Vector3(float(rot_arr[0]), float(rot_arr[1]), float(rot_arr[2]))
		if item.has("prior_mag"):
			rp.prior_mag = float(item["prior_mag"])
		else:
			faltan_tangentes = true
		if item.has("next_mag"):
			rp.next_mag = float(item["next_mag"])
		else:
			faltan_tangentes = true
		road_container.add_child(rp)
		var tipo_v := int(item.get("tipo_via", 0)) as TipoVia
		_aplicar_tipo_via_a_punto(rp, tipo_v)
		var off_y := float(item.get("offset_y", 0.0))
		if absf(off_y) > 0.001:
			rp.set_meta("offset_y", off_y)
		var peralte := float(item.get("peralte_grados", 0.0))
		if absf(peralte) > 0.001:
			rp.set_meta("peralte_grados", peralte)
		if item.has("superficie_via"):
			rp.set_meta("superficie_via", int(item["superficie_via"]))
		if item.has("demarcacion_via"):
			rp.set_meta("demarcacion_via", int(item["demarcacion_via"]))
		if bool(item.get("es_rotonda", false)):
			rp.set_meta("es_rotonda", true)
		_puntos_creados.append(rp)
		mapa_rps[nombre_item] = rp

	for item in puntos_data:
		if not (item is Dictionary):
			continue
		var rp_src: RoadPoint = mapa_rps.get(str(item.get("nombre", "")))
		if not rp_src:
			continue
		var next_n := str(item.get("next", ""))
		if not next_n.is_empty() and mapa_rps.has(next_n):
			var rp_n: RoadPoint = mapa_rps[next_n]
			rp_src.next_pt_init = rp_src.get_path_to(rp_n)
		var prior_n := str(item.get("prior", ""))
		if not prior_n.is_empty() and mapa_rps.has(prior_n):
			var rp_p: RoadPoint = mapa_rps[prior_n]
			rp_src.prior_pt_init = rp_src.get_path_to(rp_p)

	for i_item in inter_data:
		if not (i_item is Dictionary):
			continue
		var inter := RoadIntersection.new()
		inter.name = str(i_item.get("nombre", "Cruce_%d" % (_puntos_creados.size() + 1)))
		inter.container = road_container
		road_container.add_child(inter)
		var pos_arr: Array = i_item.get("posicion", [0.0, 0.0, 0.0])
		if pos_arr.size() >= 3:
			inter.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		var rot_arr: Array = i_item.get("rotacion", [0.0, 0.0, 0.0])
		if rot_arr.size() >= 3:
			inter.rotation = Vector3(float(rot_arr[0]), float(rot_arr[1]), float(rot_arr[2]))
		for r_nombre in i_item.get("ramales", []):
			var rp_ramal: RoadPoint = mapa_rps.get(str(r_nombre))
			if rp_ramal:
				inter.add_branch(rp_ramal)

	for isla in islas_data:
		if isla is Dictionary:
			var pa: Array = isla.get("posicion", [0.0, 0.0, 0.0])
			if pa.size() >= 3:
				_crear_isla_rotonda(Vector3(float(pa[0]), float(pa[1]), float(pa[2])), float(isla.get("radio", 18.0)), int(isla.get("salidas", 4)))

	if faltan_tangentes:
		_actualizar_orientaciones_y_curvaturas()
	road_container.update_edges()
	road_container.rebuild_segments(true)
	actualizar_seleccionadores_puntos()
	carretera_actualizada.emit()
