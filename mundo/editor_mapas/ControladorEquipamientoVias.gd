class_name ControladorEquipamientoVias
extends Node3D

const RoadSegment = preload("res://addons/road-generator/nodes/road_segment.gd")

## ControladorEquipamientoVias.gd
## Administra la selección de tramos de carreteras (de Punto A a Punto B) y la generación
## procedural de Aceras (andenes con sardinel), Bermas, Barreras de contención (guardrails),
## Postes de alumbrado público y Árboles de bulevar a lo largo de las curvas viales.

signal tramo_seleccionado_cambiado(hay_tramo: bool, datos: Dictionary)
signal equipamiento_actualizado()

enum LadoEquipamiento {
	AMBOS,
	IZQUIERDA,
	DERECHA
}

enum TipoEquipamiento {
	ACERA,              # Andén de concreto elevado (+18cm) con bordillo/sardinel
	BERMA,              # Hombro de asfalto/grava a nivel de calzada
	BARRERA,            # Baranda de seguridad / Guardrail metálico W-Beam
	POSTE_LUZ,          # Luminaria vial con foco SpotLight3D
	ARBOLES,            # Hileras de árboles de bulevar
	REDUCTOR_VELOCIDAD, # Resalto vial / "Policía acostado" con franjas amarillo y negro
	PUENTE_VIADUCTO,    # Pilares y soportes estructurales de viaducto (>2.5m de elevación)
	TUNEL_MONTANA,      # Portales modulares de túnel al atravesar laderas
	PASO_PEATONAL,      # Cebra peatonal y línea de pare
	SENAL_TRANSITO,     # Señalización vertical (Pare / Límite / Curva)
	SEMAFORO,           # Semáforos viales en extremos del tramo
	OJOS_DE_GATO        # Tachas reflectivas nocturnas en bordes de calzada
}

enum TipoAcera {
	CONCRETO,      # Gris urbano clásico
	ADOQUIN,       # Adoquín terracota
	FRANJA_VERDE,  # Césped / franja verde
	GRANITO        # Granito pulido oscuro
}

enum ModoDistribucionArboles {
	INTERCALADOS,  # Alternando especies seleccionadas
	ALEATORIOS,    # Distribución pseudo-aleatoria
	UNICO          # Una sola especie fija
}

var road_container: RoadContainer = null
var controlador_carreteras: ControladorCarreteras = null
var tipo_senal_actual: int = 0 # 0: Pare, 1: Limite, 2: Curva
var _registro_equipamiento_serializable: Dictionary = {}

# Estado de selección del tramo
var punto_inicio: RoadPoint = null
var punto_fin: RoadPoint = null
var tramo_puntos: Array[RoadPoint] = []
var tramo_segmentos: Array[RoadSegment] = []
var distancia_total_tramo: float = 0.0

# Opciones configuradas por el usuario en interfaz
var tipo_equipamiento_actual: TipoEquipamiento = TipoEquipamiento.ACERA
var lado_actual: LadoEquipamiento = LadoEquipamiento.AMBOS
var ancho_actual: float = 1.8 # Metros
var tipo_acera_actual: TipoAcera = TipoAcera.CONCRETO
var modo_distribucion_arboles: ModoDistribucionArboles = ModoDistribucionArboles.INTERCALADOS
var arboles_seleccionados: Array[String] = ["arbol_sabanero", "arbol_roble_3d"]

# Nodos visuales de marcadores y resaltado
var _marcador_punto_a: Node3D = null
var _marcador_punto_b: Node3D = null
var _linea_resaltado_mesh: ImmediateMesh = null
var _linea_resaltado_instance: MeshInstance3D = null
var _mat_resaltado: StandardMaterial3D = null

# Contenedor raíz donde residen todas las geometrías generadas
var _contenedor_equipamiento: Node3D = null

# Registro de elementos creados por clave canónica de tramo ("P1__P2") -> Array[Node3D]
var _nodos_por_clave_segmento: Dictionary = {}

# Configuración persistente de equipamiento por clave canónica ("P1__P2") -> Dictionary
var _equipamiento_por_clave: Dictionary = {}
var _posiciones_pilares_viaducto: Array[Vector3] = []

func _ready() -> void:
	_inicializar_contenedor_equipamiento()
	if not _marcador_punto_a:
		_crear_marcadores_seleccion()
	if not _linea_resaltado_mesh:
		_crear_linea_resaltado()

func _process(_delta: float) -> void:
	# Pulso visual en los marcadores de selección A y B
	if (is_instance_valid(punto_inicio) and _marcador_punto_a and _marcador_punto_a.visible) or (is_instance_valid(punto_fin) and _marcador_punto_b and _marcador_punto_b.visible):
		var t = Time.get_ticks_msec() * 0.007
		var pulse = sin(t) * 0.12 + 1.0
		if _marcador_punto_a and _marcador_punto_a.visible:
			_marcador_punto_a.scale = Vector3(pulse, 1.0, pulse)
		if _marcador_punto_b and _marcador_punto_b.visible:
			_marcador_punto_b.scale = Vector3(pulse, 1.0, pulse)

# ── INICIALIZACIÓN DE COMPONENTES VISUALES ───────────────────────────

func _inicializar_contenedor_equipamiento() -> void:
	if _contenedor_equipamiento != null:
		return
	_contenedor_equipamiento = Node3D.new()
	_contenedor_equipamiento.name = "EquipamientoVial_Instancias"
	add_child(_contenedor_equipamiento)

func _crear_marcadores_seleccion() -> void:
	_marcador_punto_a = _construir_marcador_baliza("Inicio (A)", Color(0.2, 0.85, 1.0, 0.95)) # Cyan
	add_child(_marcador_punto_a)
	_marcador_punto_a.visible = false
	
	_marcador_punto_b = _construir_marcador_baliza("Fin (B)", Color(0.88, 0.68, 0.28, 0.95)) # Ámbar
	add_child(_marcador_punto_b)
	_marcador_punto_b.visible = false

func _construir_marcador_baliza(etiqueta: String, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Marcador_" + etiqueta
	
	var mesh_anillo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.3
	torus.outer_radius = 1.8
	torus.rings = 24
	torus.ring_segments = 12
	mesh_anillo.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_anillo.material_override = mat
	root.add_child(mesh_anillo)
	
	var mesh_columna := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = 3.2
	mesh_columna.mesh = cyl
	mesh_columna.position.y = 1.6
	mesh_columna.material_override = mat
	root.add_child(mesh_columna)
	
	var mesh_esfera := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.35
	sph.height = 0.70
	mesh_esfera.mesh = sph
	mesh_esfera.position.y = 3.2
	mesh_esfera.material_override = mat
	root.add_child(mesh_esfera)
	
	return root

func _crear_linea_resaltado() -> void:
	_linea_resaltado_mesh = ImmediateMesh.new()
	_linea_resaltado_instance = MeshInstance3D.new()
	_linea_resaltado_instance.name = "CintaResaltadoTramo"
	_linea_resaltado_instance.mesh = _linea_resaltado_mesh
	
	_mat_resaltado = StandardMaterial3D.new()
	_mat_resaltado.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_resaltado.albedo_color = Color(0.2, 0.85, 1.0, 0.45)
	_mat_resaltado.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_resaltado.cull_mode = BaseMaterial3D.CULL_DISABLED
	_linea_resaltado_instance.material_override = _mat_resaltado
	_linea_resaltado_instance.visible = false
	add_child(_linea_resaltado_instance)

# ── SELECCIÓN DE TRAMO INTERACTIVA (PUNTO A -> PUNTO B) ──────────────

func procesar_clic_punto(rp: RoadPoint) -> Dictionary:
	if not is_instance_valid(rp):
		return {"exito": false, "mensaje": "Punto de vía no válido"}
		
	if punto_inicio == null:
		# Fijar extremo A
		fijar_punto_inicio(rp)
		return {
			"exito": true,
			"paso": 1,
			"mensaje": "Inicio fijado en %s. Ahora toca el punto donde termina el tramo." % rp.name,
			"punto_inicio": rp
		}
	else:
		# Fijar extremo B
		if rp == punto_inicio:
			# Si toca el mismo punto, reiniciar selección
			limpiar_seleccion_tramo()
			return {"exito": true, "paso": 0, "mensaje": "Selección reiniciada. Toca el punto inicial."}
			
		var res = fijar_punto_fin(rp)
		if res.get("exito", false):
			return {
				"exito": true,
				"paso": 2,
				"mensaje": "¡Tramo seleccionado! Longitud: %.1fm (%d puntos)." % [distancia_total_tramo, tramo_puntos.size()],
				"punto_inicio": punto_inicio,
				"punto_fin": punto_fin,
				"distancia": distancia_total_tramo
			}
		else:
			return {
				"exito": false,
				"paso": 1,
				"mensaje": "No hay camino directo entre %s y %s (vías desconectadas). Elige otro punto." % [punto_inicio.name, rp.name]
			}

func fijar_punto_inicio(rp: RoadPoint) -> void:
	limpiar_seleccion_tramo()
	punto_inicio = rp
	if _marcador_punto_a:
		_marcador_punto_a.global_position = rp.global_position + Vector3(0, 0.2, 0)
		_marcador_punto_a.visible = true
	tramo_seleccionado_cambiado.emit(false, {"paso": 1, "inicio": rp.name})

func fijar_punto_fin(rp: RoadPoint) -> Dictionary:
	if punto_inicio == null:
		fijar_punto_inicio(rp)
		return {"exito": false, "mensaje": "Punto inicial fijado"}
		
	punto_fin = rp
	var res_camino = encontrar_camino_entre_puntos(punto_inicio, punto_fin)
	if not res_camino.get("exito", false):
		punto_fin = null
		return {"exito": false}
		
	tramo_puntos = res_camino["puntos"]
	tramo_segmentos = res_camino["segmentos"]
	distancia_total_tramo = res_camino["distancia"]
	
	if _marcador_punto_b:
		_marcador_punto_b.global_position = rp.global_position + Vector3(0, 0.2, 0)
		_marcador_punto_b.visible = true
		
	_actualizar_cinta_resaltado()
	
	var datos_tramo = {
		"paso": 2,
		"inicio": punto_inicio.name,
		"fin": punto_fin.name,
		"num_puntos": tramo_puntos.size(),
		"distancia": distancia_total_tramo
	}
	tramo_seleccionado_cambiado.emit(true, datos_tramo)
	return {"exito": true, "distancia": distancia_total_tramo}

func limpiar_seleccion_tramo() -> void:
	punto_inicio = null
	punto_fin = null
	tramo_puntos.clear()
	tramo_segmentos.clear()
	distancia_total_tramo = 0.0
	
	if _marcador_punto_a:
		_marcador_punto_a.visible = false
	if _marcador_punto_b:
		_marcador_punto_b.visible = false
	if _linea_resaltado_instance:
		_linea_resaltado_instance.visible = false
		
	tramo_seleccionado_cambiado.emit(false, {})

# ── PATHFINDING SOBRE EL GRAFO DE CARRETERAS (BFS) ───────────────────

func encontrar_camino_entre_puntos(p_inicio: RoadPoint, p_fin: RoadPoint) -> Dictionary:
	var visitados: Dictionary = {}
	var cola: Array = [[p_inicio, [p_inicio]]]
	visitados[p_inicio] = true
	
	while not cola.is_empty():
		var elem = cola.pop_front()
		var actual: RoadPoint = elem[0]
		var camino_pts: Array = elem[1]
		
		if actual == p_fin:
			var pts_tipados: Array[RoadPoint] = []
			for p in camino_pts:
				if p is RoadPoint:
					pts_tipados.append(p)
					
			var segs_tipados: Array[RoadSegment] = []
			var dist = 0.0
			for idx in range(pts_tipados.size() - 1):
				var p_a = pts_tipados[idx]
				var p_b = pts_tipados[idx + 1]
				var seg = _obtener_segmento_entre(p_a, p_b)
				if is_instance_valid(seg):
					if not segs_tipados.has(seg):
						segs_tipados.append(seg)
					var c = _obtener_curva_segmento(seg)
					if c:
						dist += c.get_baked_length()
					else:
						dist += p_a.global_position.distance_to(p_b.global_position)
						
			return {"exito": true, "puntos": pts_tipados, "segmentos": segs_tipados, "distancia": dist}
			
		# Explorar vecino PRIOR
		if not actual.prior_pt_init.is_empty():
			var n = actual.get_node_or_null(actual.prior_pt_init)
			if is_instance_valid(n) and n is RoadPoint and not visitados.has(n):
				visitados[n] = true
				var nuevos_pts: Array = camino_pts.duplicate()
				nuevos_pts.append(n)
				cola.append([n, nuevos_pts])
				
		# Explorar vecino NEXT
		if not actual.next_pt_init.is_empty():
			var n = actual.get_node_or_null(actual.next_pt_init)
			if is_instance_valid(n) and n is RoadPoint and not visitados.has(n):
				visitados[n] = true
				var nuevos_pts: Array = camino_pts.duplicate()
				nuevos_pts.append(n)
				cola.append([n, nuevos_pts])
				
	return {"exito": false, "puntos": [], "segmentos": [], "distancia": 0.0}

func _obtener_segmento_entre(p1: RoadPoint, p2: RoadPoint) -> RoadSegment:
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		return null
	if is_instance_valid(p1.next_seg) and (p1.next_seg == p2.prior_seg or p1.next_seg == p2.next_seg):
		return p1.next_seg
	if is_instance_valid(p1.prior_seg) and (p1.prior_seg == p2.prior_seg or p1.prior_seg == p2.next_seg):
		return p1.prior_seg
	if is_instance_valid(p1.next_seg):
		return p1.next_seg
	if is_instance_valid(p1.prior_seg):
		return p1.prior_seg
	if is_instance_valid(p2.prior_seg):
		return p2.prior_seg
	if is_instance_valid(p2.next_seg):
		return p2.next_seg
	return null

func _obtener_curva_segmento(seg: RoadSegment) -> Curve3D:
	if not is_instance_valid(seg):
		return null
	if seg.curve and seg.curve.get_baked_length() >= 1.0:
		return seg.curve
	# Fallback si seg.curve aún no ha horneado
	if is_instance_valid(seg.start_point) and is_instance_valid(seg.end_point):
		var c := Curve3D.new()
		var p0: Vector3 = seg.to_local(seg.start_point.global_position) if seg.is_inside_tree() and seg.start_point.is_inside_tree() else (seg.start_point.position - seg.position)
		var p1: Vector3 = seg.to_local(seg.end_point.global_position) if seg.is_inside_tree() and seg.end_point.is_inside_tree() else (seg.end_point.position - seg.position)
		if p0.distance_to(p1) > 0.5:
			c.add_point(p0)
			c.add_point(p1)
			return c
	return null

func _actualizar_cinta_resaltado() -> void:
	if not _linea_resaltado_mesh or tramo_segmentos.is_empty():
		if _linea_resaltado_instance:
			_linea_resaltado_instance.visible = false
		return
		
	_linea_resaltado_mesh.clear_surfaces()
	_linea_resaltado_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for seg in tramo_segmentos:
		if not is_instance_valid(seg):
			continue
		var curve = _obtener_curva_segmento(seg)
		if not curve:
			continue
		var clen = curve.get_baked_length()
		var pasos = clampi(int(clen / 1.5), 2, 80)
		var dt = clen / float(pasos)
		
		for i in range(pasos):
			var s0 = i * dt
			var s1 = minf((i + 1) * dt, clen)
			
			var p0 = seg.to_global(curve.sample_baked(s0)) + Vector3(0, 0.22, 0)
			var p1 = seg.to_global(curve.sample_baked(s1)) + Vector3(0, 0.22, 0)
			
			var fwd0 = (seg.to_global(curve.sample_baked(minf(s0 + 0.5, clen))) - p0).normalized()
			if fwd0.is_zero_approx() or absf(fwd0.dot(Vector3.UP)) > 0.95:
				fwd0 = Vector3.FORWARD
			var right0 = Vector3.UP.cross(fwd0).normalized()
			if right0.is_zero_approx():
				right0 = Vector3.RIGHT
			
			var fwd1 = (p1 - seg.to_global(curve.sample_baked(maxf(s1 - 0.5, 0.0)))).normalized()
			if fwd1.is_zero_approx() or absf(fwd1.dot(Vector3.UP)) > 0.95:
				fwd1 = fwd0
			var right1 = Vector3.UP.cross(fwd1).normalized()
			if right1.is_zero_approx():
				right1 = right0
			
			var w = 4.2
			var v0_l = p0 - right0 * w
			var v0_r = p0 + right0 * w
			var v1_l = p1 - right1 * w
			var v1_r = p1 + right1 * w
			
			# Triángulo 1
			_linea_resaltado_mesh.surface_add_vertex(v0_l)
			_linea_resaltado_mesh.surface_add_vertex(v0_r)
			_linea_resaltado_mesh.surface_add_vertex(v1_r)
			
			# Triángulo 2
			_linea_resaltado_mesh.surface_add_vertex(v0_l)
			_linea_resaltado_mesh.surface_add_vertex(v1_r)
			_linea_resaltado_mesh.surface_add_vertex(v1_l)
			
	_linea_resaltado_mesh.surface_end()
	_linea_resaltado_instance.visible = true

func _actualizar_segmentos_del_tramo() -> void:
	if tramo_puntos.size() < 2:
		return
	tramo_segmentos.clear()
	for idx in range(tramo_puntos.size() - 1):
		var p_a = tramo_puntos[idx]
		var p_b = tramo_puntos[idx + 1]
		var seg = _obtener_segmento_entre(p_a, p_b)
		if is_instance_valid(seg) and not tramo_segmentos.has(seg):
			tramo_segmentos.append(seg)

# ── APLICACIÓN PROCEDURAL DE ELEMENTOS AL TRAMO ──────────────────────

func aplicar_equipamiento_actual() -> Dictionary:
	_inicializar_contenedor_equipamiento()
	if tramo_segmentos.is_empty():
		_actualizar_segmentos_del_tramo()
	if tramo_segmentos.is_empty():
		return {"exito": false, "mensaje": "Primero selecciona el tramo de vía (toca una carretera o Punto A → B)"}
		
	match tipo_equipamiento_actual:
		TipoEquipamiento.ACERA:
			aplicar_aceras(tramo_segmentos, lado_actual, ancho_actual)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Aceras y sardineles aplicados con éxito!"}
		TipoEquipamiento.BERMA:
			aplicar_bermas(tramo_puntos, tramo_segmentos, lado_actual, ancho_actual)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Bermas viales configuradas con éxito!"}
		TipoEquipamiento.BARRERA:
			aplicar_barreras(tramo_segmentos, lado_actual)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Barreras de seguridad (guardrails) instaladas!"}
		TipoEquipamiento.POSTE_LUZ:
			aplicar_postes_luz(tramo_segmentos, lado_actual, 25.0)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, 25.0)
			return {"exito": true, "mensaje": "¡Alumbrado público instalado cada 25m!"}
		TipoEquipamiento.ARBOLES:
			aplicar_arboles(tramo_segmentos, lado_actual, 18.0)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, 18.0)
			return {"exito": true, "mensaje": "¡Árboles de bulevar plantados a lo largo del tramo!"}
		TipoEquipamiento.REDUCTOR_VELOCIDAD:
			aplicar_reductores_velocidad(tramo_segmentos)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Reductor de velocidad instalado en el tramo!"}
		TipoEquipamiento.PUENTE_VIADUCTO:
			aplicar_puentes_viaductos(tramo_segmentos)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Puentes y viaductos estructurales generados con éxito!"}
		TipoEquipamiento.TUNEL_MONTANA:
			aplicar_tuneles(tramo_segmentos)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Portales de túnel y revestimiento instalados!"}
		TipoEquipamiento.PASO_PEATONAL:
			aplicar_pasos_peatonales(tramo_segmentos)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Pasos peatonales (cebra) pintados en el tramo!"}
		TipoEquipamiento.SENAL_TRANSITO:
			aplicar_senales_transito(tramo_segmentos, lado_actual, tipo_senal_actual)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, float(tipo_senal_actual))
			return {"exito": true, "mensaje": "¡Señalización vertical instalada!"}
		TipoEquipamiento.SEMAFORO:
			aplicar_semaforos(tramo_segmentos)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Semáforos instalados en los extremos del tramo!"}
		TipoEquipamiento.OJOS_DE_GATO:
			aplicar_ojos_de_gato(tramo_segmentos, lado_actual)
			_registrar_equipamiento_serializable(tramo_segmentos, tipo_equipamiento_actual, lado_actual, ancho_actual)
			return {"exito": true, "mensaje": "¡Tachas reflectivas (ojos de gato) instaladas!"}
			
	return {"exito": false, "mensaje": "Opción no reconocida"}

# 1. ACERAS (ANDENES CON SARDINEL Y COLISIÓN) ──────────────────────────

func aplicar_aceras(segmentos: Array[RoadSegment], lado: LadoEquipamiento, ancho: float = 1.8) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
			
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			_equipamiento_por_clave[clave] = {}
		_equipamiento_por_clave[clave]["acera_activa"] = true
		_equipamiento_por_clave[clave]["acera_lado"] = lado
		_equipamiento_por_clave[clave]["acera_ancho"] = ancho
		_equipamiento_por_clave[clave]["acera_tipo"] = tipo_acera_actual
		
		_limpiar_subtipo_en_segmento(seg, "Acera")
		
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA:
			_generar_malla_acera(seg, true, ancho)
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA:
			_generar_malla_acera(seg, false, ancho)
			
	# Re-adaptar elementos complementarios (como barreras o postes) si ya estaban instalados
	_readaptar_complementos_en_segmentos(segmentos)
	equipamiento_actualizado.emit()

func _muestrear_estaciones_curva(seg: RoadSegment, curve: Curve3D, clen: float, pasos: int, es_izquierda: bool, w_start: float, w_end: float) -> Array[Dictionary]:
	var estaciones: Array[Dictionary] = []
	var sp: RoadPoint = seg.start_point
	var ep: RoadPoint = seg.end_point
	var en_arbol: bool = seg.is_inside_tree()
	for k in range(pasos + 1):
		var t: float = float(k) / float(pasos)
		var s: float = t * clen
		var c: Vector3 = seg.to_global(curve.sample_baked(s)) if en_arbol else (seg.position + curve.sample_baked(s))
		var s_prev: float = maxf(s - 0.5, 0.0)
		var s_next: float = minf(s + 0.5, clen)
		var p_prev: Vector3 = seg.to_global(curve.sample_baked(s_prev)) if en_arbol else (seg.position + curve.sample_baked(s_prev))
		var p_next: Vector3 = seg.to_global(curve.sample_baked(s_next)) if en_arbol else (seg.position + curve.sample_baked(s_next))
		var fwd: Vector3 = (p_next - p_prev).normalized()
		if k == 0 and is_instance_valid(sp):
			var rp_fwd: Vector3 = sp.global_transform.basis.z.normalized()
			if rp_fwd.dot(fwd) < 0.0:
				rp_fwd = -rp_fwd
			if not rp_fwd.is_zero_approx() and absf(rp_fwd.dot(Vector3.UP)) <= 0.95:
				fwd = rp_fwd
		elif k == pasos and is_instance_valid(ep):
			var rp_fwd_e: Vector3 = ep.global_transform.basis.z.normalized()
			if rp_fwd_e.dot(fwd) < 0.0:
				rp_fwd_e = -rp_fwd_e
			if not rp_fwd_e.is_zero_approx() and absf(rp_fwd_e.dot(Vector3.UP)) <= 0.95:
				fwd = rp_fwd_e
		if fwd.is_zero_approx() or absf(fwd.dot(Vector3.UP)) > 0.95:
			fwd = Vector3.FORWARD
		var right_vec: Vector3 = Vector3.UP.cross(fwd).normalized()
		if right_vec.is_zero_approx():
			right_vec = Vector3.RIGHT
		var lat: Vector3 = -right_vec if es_izquierda else right_vec
		var dist_e: float = lerpf(w_start, w_end, t)
		estaciones.append({
			"s": s,
			"c": c,
			"e": c + lat * dist_e,
			"fwd": fwd,
			"lat": lat,
			"dir_calzada": -lat
		})
	return estaciones

func _generar_malla_acera(seg: RoadSegment, es_izquierda: bool, ancho: float) -> void:
	_inicializar_contenedor_equipamiento()
	var curve = _obtener_curva_segmento(seg)
	if not curve:
		return
	var clen = curve.get_baked_length()
	if clen < 1.0:
		return
		
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat_concreto := StandardMaterial3D.new()
	mat_concreto.cull_mode = BaseMaterial3D.CULL_DISABLED
	var nombre_tex_estilo := "concreto_latino"
	match tipo_acera_actual:
		TipoAcera.CONCRETO:
			nombre_tex_estilo = "concreto_latino"
			mat_concreto.albedo_color = Color(0.96, 0.96, 0.96)
			mat_concreto.roughness = 0.84
		TipoAcera.ADOQUIN:
			nombre_tex_estilo = "adoquin_latino"
			mat_concreto.albedo_color = Color(0.96, 0.94, 0.92)
			mat_concreto.roughness = 0.78
		TipoAcera.FRANJA_VERDE:
			nombre_tex_estilo = "franja_verde_latino"
			mat_concreto.albedo_color = Color(0.95, 0.97, 0.95)
			mat_concreto.roughness = 0.88
		TipoAcera.GRANITO:
			nombre_tex_estilo = "granito_latino"
			mat_concreto.albedo_color = Color(0.94, 0.95, 0.97)
			mat_concreto.metallic = 0.12
			mat_concreto.roughness = 0.48
			
	var ruta_alb := "res://recursos/texturas/mapas/02_vias_urbanismo/aceras_bordillos/acera_%s_albedo.png" % nombre_tex_estilo
	var ruta_nrm := "res://recursos/texturas/mapas/02_vias_urbanismo/aceras_bordillos/acera_%s_normal.png" % nombre_tex_estilo
	var tex_alb: Texture2D = _cargar_textura_segura(ruta_alb)
	var tex_nrm: Texture2D = _cargar_textura_segura(ruta_nrm)
	if tex_alb:
		mat_concreto.albedo_texture = tex_alb
	if tex_nrm:
		mat_concreto.normal_enabled = true
		mat_concreto.normal_scale = 1.15
		mat_concreto.normal_texture = tex_nrm
	
	var pasos = clampi(int(clen / 0.75), 6, 180)
	var h_bordillo = 0.18 # 18cm de altura de sardinel prefabricado A10
	var bisel = 0.035 # 3.5cm de chaflán a 45°
	var ancho_cuneta = 0.12 # Cuneta de concreto junto al borde asfáltico
	var off_podo_ini = clampf(ancho * 0.42, 0.36, maxf(0.40, ancho - 0.45))
	var off_podo_fin = minf(off_podo_ini + 0.28, maxf(0.55, ancho - 0.20))
	var off_cenefa = maxf(off_podo_fin + 0.08, ancho - 0.16)
	
	var sp = seg.start_point
	var ep = seg.end_point
	var w_start = _obtener_offset_borde_calzada(seg, sp, es_izquierda)
	var w_end = _obtener_offset_borde_calzada(seg, ep, es_izquierda)
	var estaciones: Array[Dictionary] = _muestrear_estaciones_curva(seg, curve, clen, pasos, es_izquierda, w_start, w_end)
	
	for i in range(pasos):
		var st0: Dictionary = estaciones[i]
		var st1: Dictionary = estaciones[i + 1]
		var v0: float = float(st0["s"]) / 2.0
		var v1: float = float(st1["s"]) / 2.0
		var fwd0: Vector3 = st0["fwd"]
		var fwd1: Vector3 = st1["fwd"]
		var lat0: Vector3 = st0["lat"]
		var lat1: Vector3 = st1["lat"]
		var dir_calzada0: Vector3 = st0["dir_calzada"]
		var dir_calzada1: Vector3 = st1["dir_calzada"]
		var e0: Vector3 = st0["e"]
		var e1: Vector3 = st1["e"]
		
		# Perfil transversal latinoamericano de 9 puntos en corte s0 (con UVs mapeados al atlas PBR de Blender)
		var p0_cuneta = e0
		var p0_base = e0 + lat0 * ancho_cuneta
		var p0_bisel_inf = e0 + lat0 * ancho_cuneta + Vector3(0, h_bordillo - bisel, 0)
		var p0_bisel_sup = e0 + lat0 * (ancho_cuneta + bisel) + Vector3(0, h_bordillo, 0)
		var p0_podo_in = e0 + lat0 * off_podo_ini + Vector3(0, h_bordillo - 0.004, 0)
		var p0_podo_out = e0 + lat0 * off_podo_fin + Vector3(0, h_bordillo + 0.004, 0)
		var p0_cenefa = e0 + lat0 * off_cenefa + Vector3(0, h_bordillo - 0.012, 0)
		var p0_ext = e0 + lat0 * ancho + Vector3(0, h_bordillo - 0.015, 0)
		var p0_suelo = e0 + lat0 * (ancho + 0.08) - Vector3(0, 0.35, 0)
		
		# Perfil transversal latinoamericano de 9 puntos en corte s1
		var p1_cuneta = e1
		var p1_base = e1 + lat1 * ancho_cuneta
		var p1_bisel_inf = e1 + lat1 * ancho_cuneta + Vector3(0, h_bordillo - bisel, 0)
		var p1_bisel_sup = e1 + lat1 * (ancho_cuneta + bisel) + Vector3(0, h_bordillo, 0)
		var p1_podo_in = e1 + lat1 * off_podo_ini + Vector3(0, h_bordillo - 0.004, 0)
		var p1_podo_out = e1 + lat1 * off_podo_fin + Vector3(0, h_bordillo + 0.004, 0)
		var p1_cenefa = e1 + lat1 * off_cenefa + Vector3(0, h_bordillo - 0.012, 0)
		var p1_ext = e1 + lat1 * ancho + Vector3(0, h_bordillo - 0.015, 0)
		var p1_suelo = e1 + lat1 * (ancho + 0.08) - Vector3(0, 0.35, 0)
		
		# Franja 0: Cuneta pluvial de concreto junto al asfalto (U: 0.00 -> 0.08)
		_agregar_quad_con_uv_y_normal(st, p0_cuneta, p1_cuneta, p1_base, p0_base, Vector2(0.00, v0), Vector2(0.00, v1), Vector2(0.08, v1), Vector2(0.08, v0), Vector3.UP)
		
		# Franja 1: Cara vertical del sardinel A10 con pintura amarilla/blanca (U: 0.08 -> 0.20)
		var norm_sardinel = (dir_calzada0 + dir_calzada1).normalized()
		_agregar_quad_con_uv_y_normal(st, p0_base, p1_base, p1_bisel_inf, p0_bisel_inf, Vector2(0.08, v0), Vector2(0.08, v1), Vector2(0.20, v1), Vector2(0.20, v0), norm_sardinel)
		
		# Franja 2: Chaflán a 45° del sardinel (U: 0.20 -> 0.28)
		var norm_bisel = (norm_sardinel + Vector3.UP).normalized()
		_agregar_quad_con_uv_y_normal(st, p0_bisel_inf, p1_bisel_inf, p1_bisel_sup, p0_bisel_sup, Vector2(0.20, v0), Vector2(0.20, v1), Vector2(0.28, v1), Vector2(0.28, v0), norm_bisel)
		
		# Franja 3: Loseta peatonal interior (U: 0.28 -> 0.56)
		_agregar_quad_con_uv_y_normal(st, p0_bisel_sup, p1_bisel_sup, p1_podo_in, p0_podo_in, Vector2(0.28, v0), Vector2(0.28, v1), Vector2(0.56, v1), Vector2(0.56, v0), Vector3.UP)
		
		# Franja 4: Loseta podotáctil amarilla de guía en relieve (U: 0.56 -> 0.70)
		_agregar_quad_con_uv_y_normal(st, p0_podo_in, p1_podo_in, p1_podo_out, p0_podo_out, Vector2(0.56, v0), Vector2(0.56, v1), Vector2(0.70, v1), Vector2(0.70, v0), Vector3.UP)
		
		# Franja 5: Loseta peatonal exterior / Franja verde (U: 0.70 -> 0.92)
		_agregar_quad_con_uv_y_normal(st, p0_podo_out, p1_podo_out, p1_cenefa, p0_cenefa, Vector2(0.70, v0), Vector2(0.70, v1), Vector2(0.92, v1), Vector2(0.92, v0), Vector3.UP)
		
		# Franja 6: Cenefa exterior de adoquín / bordillo de confinamiento (U: 0.92 -> 0.97)
		_agregar_quad_con_uv_y_normal(st, p0_cenefa, p1_cenefa, p1_ext, p0_ext, Vector2(0.92, v0), Vector2(0.92, v1), Vector2(0.97, v1), Vector2(0.97, v0), Vector3.UP)
		
		# Franja 7: Faldón exterior hacia el terreno (U: 0.92 -> 1.00)
		var norm_ext = (lat0 + lat1).normalized()
		_agregar_quad_con_uv_y_normal(st, p0_ext, p1_ext, p1_suelo, p0_suelo, Vector2(0.92, v0), Vector2(0.92, v1), Vector2(1.00, v1), Vector2(1.00, v0), norm_ext)
		
		# Tapas de extremos al inicio y al final
		if i == 0:
			var norm_tapa_ini = -fwd0
			_agregar_quad_con_uv_y_normal(st, p0_base, p0_bisel_inf, p0_bisel_sup, p0_ext, Vector2(0.30, 0.10), Vector2(0.30, 0.30), Vector2(0.35, 0.35), Vector2(0.52, 0.35), norm_tapa_ini)
			_agregar_tri_uv(st, p0_base, p0_ext, p0_suelo, Vector2(0.30, 0.10), Vector2(0.52, 0.35), Vector2(0.52, 0.05), norm_tapa_ini)
		if i == pasos - 1:
			var norm_tapa_fin = fwd1
			_agregar_quad_con_uv_y_normal(st, p1_base, p1_bisel_inf, p1_bisel_sup, p1_ext, Vector2(0.30, 0.10), Vector2(0.30, 0.30), Vector2(0.35, 0.35), Vector2(0.52, 0.35), norm_tapa_fin)
			_agregar_tri_uv(st, p1_base, p1_ext, p1_suelo, Vector2(0.30, 0.10), Vector2(0.52, 0.35), Vector2(0.52, 0.05), norm_tapa_fin)
			
	st.generate_normals()
	st.generate_tangents()
	
	var clave_seg := _obtener_clave_segmento(seg)
	var mi := MeshInstance3D.new()
	mi.name = "Acera_%s_%s" % ["Izq" if es_izquierda else "Der", seg.name]
	mi.set_meta("subtipo_equip", "Acera")
	mi.set_meta("clave_seg", clave_seg)
	mi.mesh = st.commit()
	mi.material_override = mat_concreto
	_contenedor_equipamiento.add_child(mi)
	mi.create_trimesh_collision()
	_registrar_nodo_segmento(seg, mi)
	
	# Instanciar mobiliario y detalles 3D modulares del kit de Blender (tapas de registro, sumideros, rampas y bolardos)
	_instanciar_detalles_acera_latinoamericana(mi, seg, curve, clen, es_izquierda, ancho, w_start, w_end, h_bordillo)

func _cargar_textura_segura(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		var res = load(ruta)
		if res is Texture2D:
			return res
	var ruta_abs := ProjectSettings.globalize_path(ruta)
	if FileAccess.file_exists(ruta_abs):
		var img := Image.load_from_file(ruta_abs)
		if img and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null

func _crear_material_prop_acera(nombre_prop_tex: String, roughness_val: float, metallic_val: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var t_alb := _cargar_textura_segura("res://recursos/texturas/mapas/02_vias_urbanismo/aceras_bordillos/%s_albedo.png" % nombre_prop_tex)
	var t_nrm := _cargar_textura_segura("res://recursos/texturas/mapas/02_vias_urbanismo/aceras_bordillos/%s_normal.png" % nombre_prop_tex)
	if t_alb:
		mat.albedo_texture = t_alb
	if t_nrm:
		mat.normal_enabled = true
		mat.normal_scale = 1.2
		mat.normal_texture = t_nrm
	mat.roughness = roughness_val
	mat.metallic = metallic_val
	return mat

func _instanciar_detalles_acera_latinoamericana(nodo_acera: Node3D, seg: RoadSegment, curve: Curve3D, clen: float, es_izquierda: bool, ancho: float, w_start: float, w_end: float, h_bordillo: float) -> void:
	const RUTA_KIT_ACERA := "res://mundo/editor_mapas/modelos/acera_latinoamericana.glb"
	if clen < 5.0:
		return
	var raiz_kit: Node3D = null
	if ResourceLoader.exists(RUTA_KIT_ACERA):
		var escena_kit: PackedScene = load(RUTA_KIT_ACERA) as PackedScene
		if escena_kit:
			raiz_kit = escena_kit.instantiate() as Node3D
	if not raiz_kit:
		var ruta_abs := ProjectSettings.globalize_path(RUTA_KIT_ACERA)
		if FileAccess.file_exists(ruta_abs):
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(ruta_abs, state) == OK:
				raiz_kit = doc.generate_scene(state) as Node3D
	if not raiz_kit:
		return
		
	var mat_hierro := _crear_material_prop_acera("prop_mat_hierro_fundido_vial", 0.45, 0.72)
	var mat_tactil := _crear_material_prop_acera("prop_mat_loseta_tactil_alerta", 0.58, 0.0)
	var mat_bolardo := _crear_material_prop_acera("prop_mat_bolardo_urbano_latino", 0.38, 0.60)
	var mat_concreto_prop := _crear_material_prop_acera("acera_concreto_latino", 0.84, 0.0)
		
	var proto_tapa: MeshInstance3D = raiz_kit.find_child("02_Tapa_Registro_Servicios", true, false) as MeshInstance3D
	var proto_sumidero: MeshInstance3D = raiz_kit.find_child("03_Sumidero_Pluvial", true, false) as MeshInstance3D
	var proto_rampa: MeshInstance3D = raiz_kit.find_child("04_Rampa_Peatonal_Tactil", true, false) as MeshInstance3D
	var proto_bolardo: MeshInstance3D = raiz_kit.find_child("05_Bolardo_Urbano", true, false) as MeshInstance3D
	
	# 1. Rampas peatonales táctiles y bolardos urbanos en los extremos del tramo (si el tramo mide al menos 8m y ancho >= 1.3m)
	if clen >= 8.0 and ancho >= 1.3:
		var offsets_extremos: Array[float] = [1.5, clen - 1.5]
		for idx_ext in range(offsets_extremos.size()):
			var s_ext: float = offsets_extremos[idx_ext]
			var pose_ext: Dictionary = _calcular_pose_borde_acera(seg, curve, clen, s_ext, es_izquierda, w_start, w_end)
			var e_pos: Vector3 = pose_ext["borde"]
			var lat_v: Vector3 = pose_ext["lat"]
			var fwd_v: Vector3 = pose_ext["fwd"]
			var basis_prop := Basis(lat_v, Vector3.UP, fwd_v).orthonormalized()
			
			if proto_rampa and proto_rampa.mesh:
				var inst_rampa := MeshInstance3D.new()
				inst_rampa.name = "RampaPeatonal_%d" % idx_ext
				inst_rampa.mesh = proto_rampa.mesh
				if inst_rampa.mesh.get_surface_count() >= 1:
					inst_rampa.set_surface_override_material(0, mat_concreto_prop)
				if inst_rampa.mesh.get_surface_count() >= 2:
					inst_rampa.set_surface_override_material(1, mat_tactil)
				nodo_acera.add_child(inst_rampa)
				var pos_rampa := e_pos + lat_v * 0.12 + Vector3(0, 0.008, 0)
				if inst_rampa.is_inside_tree():
					inst_rampa.global_transform = Transform3D(basis_prop, pos_rampa)
				else:
					inst_rampa.transform = Transform3D(basis_prop, pos_rampa)
					
			if proto_bolardo and proto_bolardo.mesh:
				for delta_b in [-0.72, 0.72]:
					var s_bol := clampf(s_ext + delta_b, 0.4, clen - 0.4)
					var pose_bol: Dictionary = _calcular_pose_borde_acera(seg, curve, clen, s_bol, es_izquierda, w_start, w_end)
					var pos_bol: Vector3 = pose_bol["borde"] + (pose_bol["lat"] as Vector3) * 0.34 + Vector3(0, h_bordillo - 0.005, 0)
					var inst_bol := MeshInstance3D.new()
					inst_bol.name = "BolardoUrbano_%.0f" % (s_bol * 10.0)
					inst_bol.mesh = proto_bolardo.mesh
					inst_bol.material_override = mat_bolardo
					nodo_acera.add_child(inst_bol)
					if inst_bol.is_inside_tree():
						inst_bol.global_transform = Transform3D(basis_prop, pos_bol)
					else:
						inst_bol.transform = Transform3D(basis_prop, pos_bol)
						
	# 2. Tapas de registro de servicios públicos (Acueducto / Energía) cada 14 metros
	if proto_tapa and proto_tapa.mesh and ancho >= 1.35:
		var s_tapa: float = 5.5
		var off_lat_tapa: float = clampf(ancho * 0.74, 0.85, ancho - 0.42)
		while s_tapa <= clen - 4.5:
			var pose_t: Dictionary = _calcular_pose_borde_acera(seg, curve, clen, s_tapa, es_izquierda, w_start, w_end)
			var lat_t: Vector3 = pose_t["lat"]
			var fwd_t: Vector3 = pose_t["fwd"]
			var basis_t := Basis(lat_t, Vector3.UP, fwd_t).orthonormalized()
			var pos_t: Vector3 = (pose_t["borde"] as Vector3) + lat_t * off_lat_tapa + Vector3(0, h_bordillo - 0.010, 0)
			var inst_tapa := MeshInstance3D.new()
			inst_tapa.name = "TapaRegistro_%.0f" % s_tapa
			inst_tapa.mesh = proto_tapa.mesh
			if inst_tapa.mesh.get_surface_count() >= 1:
				inst_tapa.set_surface_override_material(0, mat_hierro)
			if inst_tapa.mesh.get_surface_count() >= 2:
				inst_tapa.set_surface_override_material(1, mat_concreto_prop)
			nodo_acera.add_child(inst_tapa)
			if inst_tapa.is_inside_tree():
				inst_tapa.global_transform = Transform3D(basis_t, pos_t)
			else:
				inst_tapa.transform = Transform3D(basis_t, pos_t)
			s_tapa += 14.0
			
	# 3. Sumideros pluviales de cuneta y sardinel cada 18 metros
	if proto_sumidero and proto_sumidero.mesh:
		var s_sum: float = 9.0
		while s_sum <= clen - 4.5:
			var pose_s: Dictionary = _calcular_pose_borde_acera(seg, curve, clen, s_sum, es_izquierda, w_start, w_end)
			var lat_s: Vector3 = pose_s["lat"]
			var fwd_s: Vector3 = pose_s["fwd"]
			var basis_s := Basis(lat_s, Vector3.UP, fwd_s).orthonormalized()
			var pos_s: Vector3 = (pose_s["borde"] as Vector3) + lat_s * 0.12 + Vector3(0, 0.005, 0)
			var inst_sum := MeshInstance3D.new()
			inst_sum.name = "SumideroPluvial_%.0f" % s_sum
			inst_sum.mesh = proto_sumidero.mesh
			if inst_sum.mesh.get_surface_count() >= 1:
				inst_sum.set_surface_override_material(0, mat_hierro)
			if inst_sum.mesh.get_surface_count() >= 2:
				inst_sum.set_surface_override_material(1, mat_concreto_prop)
			nodo_acera.add_child(inst_sum)
			if inst_sum.is_inside_tree():
				inst_sum.global_transform = Transform3D(basis_s, pos_s)
			else:
				inst_sum.transform = Transform3D(basis_s, pos_s)
			s_sum += 18.0
			
	raiz_kit.free()

func _calcular_pose_borde_acera(seg: RoadSegment, curve: Curve3D, clen: float, s: float, es_izquierda: bool, w_start: float, w_end: float) -> Dictionary:
	var s_clamped := clampf(s, 0.0, clen)
	var t := s_clamped / maxf(0.01, clen)
	var c := seg.to_global(curve.sample_baked(s_clamped)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_clamped))
	var s_next := minf(s_clamped + 0.5, clen)
	var s_prev := maxf(s_clamped - 0.5, 0.0)
	var p_next := seg.to_global(curve.sample_baked(s_next)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_next))
	var p_prev := seg.to_global(curve.sample_baked(s_prev)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_prev))
	var fwd := (p_next - p_prev)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	var right_vec := Vector3.UP.cross(fwd).normalized()
	if right_vec.is_zero_approx():
		right_vec = Vector3.RIGHT
	var lat := -right_vec if es_izquierda else right_vec
	var dist_e := lerpf(w_start, w_end, t)
	return {
		"borde": c + lat * dist_e,
		"lat": lat,
		"fwd": fwd
	}

# 2. BERMAS (HOMBROS DE ASFALTO Y GRAVA) ───────────────────────────────

func aplicar_bermas(puntos: Array[RoadPoint], segmentos: Array[RoadSegment], lado: LadoEquipamiento, ancho: float = 1.8) -> void:
	for rp in puntos:
		if not is_instance_valid(rp):
			continue
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA:
			rp.shoulder_width_l = ancho
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA:
			rp.shoulder_width_r = ancho
		rp.emit_transform(false)
		
	if road_container:
		road_container.rebuild_segments(true)
	if controlador_carreteras:
		controlador_carreteras.nivelar_terreno_bajo_carreteras()
		
	# Re-actualizar segmentos y re-adaptar automáticamente aceras, guardrails y postes a las nuevas bermas
	_actualizar_segmentos_del_tramo()
	_readaptar_equipamiento_tramo()
	
	equipamiento_actualizado.emit()

# 3. BARRERAS DE CONTENCIÓN (GUARDRAILS METÁLICOS) ─────────────────────

func aplicar_barreras(segmentos: Array[RoadSegment], lado: LadoEquipamiento) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
			
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			_equipamiento_por_clave[clave] = {}
		_equipamiento_por_clave[clave]["barrera_activa"] = true
		_equipamiento_por_clave[clave]["barrera_lado"] = lado
		
		_limpiar_subtipo_en_segmento(seg, "Barrera")
		
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA:
			_generar_barrera_guardrail(seg, true)
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA:
			_generar_barrera_guardrail(seg, false)
			
	equipamiento_actualizado.emit()

func _generar_barrera_guardrail(seg: RoadSegment, es_izquierda: bool) -> void:
	_inicializar_contenedor_equipamiento()
	var curve = _obtener_curva_segmento(seg)
	if not curve:
		return
	var clen = curve.get_baked_length()
	if clen < 2.0:
		return
		
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Material de chapa de acero galvanizado brillante con specular y roughness correcta
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.86, 0.88, 0.91)
	mat_metal.metallic = 0.95
	mat_metal.roughness = 0.28
	mat_metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Material del poste I-Beam (acero gris industrial)
	var mat_poste_metal := StandardMaterial3D.new()
	mat_poste_metal.albedo_color = Color(0.48, 0.50, 0.53)
	mat_poste_metal.metallic = 0.85
	mat_poste_metal.roughness = 0.45
	
	# Material del catadióptrico/ojo de gato reflectivo
	var mat_reflector := StandardMaterial3D.new()
	mat_reflector.albedo_color = Color(1.0, 0.72, 0.12) # Ámbar reflectivo
	mat_reflector.emission_enabled = true
	mat_reflector.emission = Color(1.0, 0.70, 0.10)
	mat_reflector.emission_energy_multiplier = 0.6
	mat_reflector.roughness = 0.15
	
	var pasos = clampi(int(clen / 0.75), 6, 180)
	
	var sp = seg.start_point
	var ep = seg.end_point
	var acera_w = _obtener_ancho_acera_en_lado(seg, es_izquierda)
	var w_start = _obtener_offset_borde_calzada(seg, sp, es_izquierda) + acera_w + 0.35
	var w_end = _obtener_offset_borde_calzada(seg, ep, es_izquierda) + acera_w + 0.35
	var estaciones: Array[Dictionary] = _muestrear_estaciones_curva(seg, curve, clen, pasos, es_izquierda, w_start, w_end)
	
	var nodo_grupo := Node3D.new()
	nodo_grupo.name = "Barrera_%s_%s" % ["Izq" if es_izquierda else "Der", seg.name]
	_contenedor_equipamiento.add_child(nodo_grupo)
	_registrar_nodo_segmento(seg, nodo_grupo)
	
	# Dimensiones auténticas de bionda W-Beam (AASHTO M180 estándar 312mm de alto)
	var y_top = 0.80
	var y_crest_high = 0.71
	var y_groove = 0.62
	var y_crest_low = 0.53
	var y_bot = 0.44
	var depth_corrugation = 0.082 # 8.2 cm de corrugación convexa hacia la calzada
	
	# 1. GENERACIÓN DE LA BIONDA CORRUGADA CONTINUA (W-BEAM)
	for i in range(pasos):
		var st0: Dictionary = estaciones[i]
		var st1: Dictionary = estaciones[i + 1]
		var fwd0: Vector3 = st0["fwd"]
		var fwd1: Vector3 = st1["fwd"]
		var dir_calzada0: Vector3 = st0["dir_calzada"]
		var dir_calzada1: Vector3 = st1["dir_calzada"]
		var base0: Vector3 = st0["e"]
		var base1: Vector3 = st1["e"]
		
		# Vértices del perfil W a s0
		var w0_top = base0 + Vector3(0, y_top, 0)
		var w0_cr_hi = base0 + Vector3(0, y_crest_high, 0) + dir_calzada0 * depth_corrugation
		var w0_grv = base0 + Vector3(0, y_groove, 0) + dir_calzada0 * 0.015
		var w0_cr_lo = base0 + Vector3(0, y_crest_low, 0) + dir_calzada0 * depth_corrugation
		var w0_bot = base0 + Vector3(0, y_bot, 0)
		var w0_back_top = base0 + Vector3(0, y_top, 0) - dir_calzada0 * 0.02
		var w0_back_bot = base0 + Vector3(0, y_bot, 0) - dir_calzada0 * 0.02
		
		# Vértices del perfil W a s1
		var w1_top = base1 + Vector3(0, y_top, 0)
		var w1_cr_hi = base1 + Vector3(0, y_crest_high, 0) + dir_calzada1 * depth_corrugation
		var w1_grv = base1 + Vector3(0, y_groove, 0) + dir_calzada1 * 0.015
		var w1_cr_lo = base1 + Vector3(0, y_crest_low, 0) + dir_calzada1 * depth_corrugation
		var w1_bot = base1 + Vector3(0, y_bot, 0)
		var w1_back_top = base1 + Vector3(0, y_top, 0) - dir_calzada1 * 0.02
		var w1_back_bot = base1 + Vector3(0, y_bot, 0) - dir_calzada1 * 0.02
		
		var dir_front = (dir_calzada0 + dir_calzada1).normalized()
		var dir_back = -dir_front
		
		# Faceta 1: Borde superior a Cresta Alta
		var n1 = (dir_front + Vector3.UP * 0.6).normalized()
		_agregar_quad_con_normal(st, w0_top, w1_top, w1_cr_hi, w0_cr_hi, n1)
		
		# Faceta 2: Cresta Alta a Valle central
		var n2 = (dir_front - Vector3.UP * 0.6).normalized()
		_agregar_quad_con_normal(st, w0_cr_hi, w1_cr_hi, w1_grv, w0_grv, n2)
		
		# Faceta 3: Valle central a Cresta Baja
		var n3 = (dir_front + Vector3.UP * 0.6).normalized()
		_agregar_quad_con_normal(st, w0_grv, w1_grv, w1_cr_lo, w0_cr_lo, n3)
		
		# Faceta 4: Cresta Baja a Borde inferior
		var n4 = (dir_front - Vector3.UP * 0.6).normalized()
		_agregar_quad_con_normal(st, w0_cr_lo, w1_cr_lo, w1_bot, w0_bot, n4)
		
		# Faceta 5: Espalda trasera (placa posterior cerrada)
		_agregar_quad_con_normal(st, w0_back_bot, w1_back_bot, w1_back_top, w0_back_top, dir_back)
		
		# Faceta 6: Pestaña superior
		_agregar_quad_con_normal(st, w0_back_top, w1_back_top, w1_top, w0_top, Vector3.UP)
		
		# Faceta 7: Pestaña inferior
		_agregar_quad_con_normal(st, w0_bot, w1_bot, w1_back_bot, w0_back_bot, Vector3.DOWN)
		
		# Tapas finales en extremos del tramo
		if i == 0:
			var n_cap_ini = -fwd0
			_agregar_quad_con_normal(st, w0_bot, w0_cr_lo, w0_cr_hi, w0_top, n_cap_ini)
			_agregar_quad_con_normal(st, w0_top, w0_back_top, w0_back_bot, w0_bot, n_cap_ini)
		if i == pasos - 1:
			var n_cap_fin = fwd1
			_agregar_quad_con_normal(st, w1_bot, w1_cr_lo, w1_cr_hi, w1_top, n_cap_fin)
			_agregar_quad_con_normal(st, w1_top, w1_back_top, w1_back_bot, w1_bot, n_cap_fin)
			
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Bionda_WBeam"
	mi.mesh = st.commit()
	mi.material_override = mat_metal
	nodo_grupo.add_child(mi)
	mi.create_trimesh_collision()
	
	# 2. GENERACIÓN DE POSTES DE SOPORTE TIPO I-BEAM, SEPARADORES Y CATADIÓPTRICOS
	var espaciado_postes = 3.2 # metros
	var num_postes = clampi(int(clen / espaciado_postes), 2, 60)
	var dt_poste = clen / float(num_postes)
	
	for p in range(num_postes + 1):
		var s = minf(p * dt_poste, clen)
		var t = s / clen
		var c = seg.to_global(curve.sample_baked(s))
		var fwd = (seg.to_global(curve.sample_baked(minf(s + 0.5, clen))) - c).normalized()
		if fwd.is_zero_approx() or absf(fwd.dot(Vector3.UP)) > 0.95:
			fwd = Vector3.FORWARD
		var right_vec = Vector3.UP.cross(fwd).normalized()
		if right_vec.is_zero_approx():
			right_vec = Vector3.RIGHT
		var lat = -right_vec if es_izquierda else right_vec
		var dist = lerpf(w_start, w_end, t)
		
		# Posición del poste montado detrás de la bionda
		var pos_poste = c + lat * (dist + 0.05)
		
		var nodo_poste := Node3D.new()
		nodo_poste.name = "PosteIBeam_%d" % p
		# Orientar el poste de forma continua con los ejes tangenciales de la curva
		nodo_poste.transform = Transform3D(Basis(lat, Vector3.UP, fwd), pos_poste)
		nodo_grupo.add_child(nodo_poste)
		
		# Pilar principal vertical (perfil I-Beam metálico)
		var m_pilar := MeshInstance3D.new()
		var box_pilar := BoxMesh.new()
		box_pilar.size = Vector3(0.08, 0.82, 0.12)
		m_pilar.mesh = box_pilar
		m_pilar.position = Vector3(0, 0.41, 0)
		m_pilar.material_override = mat_poste_metal
		nodo_poste.add_child(m_pilar)
		
		# Bloque separador de impacto (offset hacia la calzada, en espacio local es -X)
		var m_separador := MeshInstance3D.new()
		var box_sep := BoxMesh.new()
		box_sep.size = Vector3(0.08, 0.22, 0.10)
		m_separador.mesh = box_sep
		m_separador.position = Vector3(-0.06, 0.62, 0)
		m_separador.material_override = mat_poste_metal
		nodo_poste.add_child(m_separador)
		
		# Placa base de fijación en el suelo
		var m_base := MeshInstance3D.new()
		var box_base := BoxMesh.new()
		box_base.size = Vector3(0.18, 0.03, 0.18)
		m_base.mesh = box_base
		m_base.position = Vector3(0, 0.015, 0)
		m_base.material_override = mat_poste_metal
		nodo_poste.add_child(m_base)
		
		# Catadióptrico reflectivo (Ojo de gato de carretera) en postes alternos
		if p % 2 == 0:
			var m_refl := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.06, 0.08, 0.04)
			m_refl.mesh = prism
			m_refl.position = Vector3(-0.08, 0.84, 0)
			m_refl.rotation_degrees = Vector3(0, 90.0, 0)
			m_refl.material_override = mat_reflector
			nodo_poste.add_child(m_refl)

# 4. POSTES DE ALUMBRADO PÚBLICO (LUMINARIAS LED) ──────────────────────

func aplicar_postes_luz(segmentos: Array[RoadSegment], lado: LadoEquipamiento, espaciado: float = 25.0) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
			
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			_equipamiento_por_clave[clave] = {}
		_equipamiento_por_clave[clave]["postes_activa"] = true
		_equipamiento_por_clave[clave]["postes_lado"] = lado
		_equipamiento_por_clave[clave]["postes_espaciado"] = espaciado
		
		_limpiar_subtipo_en_segmento(seg, "PosteLuz")
		
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA:
			_generar_postes_luz_lado(seg, true, espaciado)
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA:
			_generar_postes_luz_lado(seg, false, espaciado)
			
	equipamiento_actualizado.emit()

func _generar_postes_luz_lado(seg: RoadSegment, es_izquierda: bool, espaciado: float) -> void:
	_inicializar_contenedor_equipamiento()
	var curve = _obtener_curva_segmento(seg)
	if not curve:
		return
	var clen = curve.get_baked_length()
	if clen < 5.0:
		return
		
	var sp = seg.start_point
	var ep = seg.end_point
	var acera_w = _obtener_ancho_acera_en_lado(seg, es_izquierda)
	var w_start = _obtener_offset_borde_calzada(seg, sp, es_izquierda) + acera_w + 0.45
	var w_end = _obtener_offset_borde_calzada(seg, ep, es_izquierda) + acera_w + 0.45
	
	var mat_poste := StandardMaterial3D.new()
	mat_poste.albedo_color = Color(0.35, 0.38, 0.42)
	mat_poste.metallic = 0.80
	mat_poste.roughness = 0.35
	
	var mat_luz := StandardMaterial3D.new()
	mat_luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_luz.albedo_color = Color(1.0, 0.98, 0.88)
	
	var nodo_grupo := Node3D.new()
	nodo_grupo.name = "PosteLuz_%s_%s" % ["Izq" if es_izquierda else "Der", seg.name]
	_contenedor_equipamiento.add_child(nodo_grupo)
	_registrar_nodo_segmento(seg, nodo_grupo)
	
	var num_postes = max(1, int(clen / espaciado))
	var dt = clen / float(num_postes)
	
	for p in range(num_postes + 1):
		var s = minf(p * dt + (dt * 0.2 if p > 0 else 2.0), clen - 1.0)
		var t = s / clen
		var c = seg.to_global(curve.sample_baked(s))
		var fwd = (seg.to_global(curve.sample_baked(minf(s + 0.5, clen))) - c).normalized()
		if fwd.is_zero_approx() or absf(fwd.dot(Vector3.UP)) > 0.95:
			fwd = Vector3.FORWARD
		var right_vec = Vector3.UP.cross(fwd).normalized()
		if right_vec.is_zero_approx():
			right_vec = Vector3.RIGHT
		var lat = -right_vec if es_izquierda else right_vec
		var dist = lerpf(w_start, w_end, t)
		var pos_base = c + lat * dist
		
		# Estructura del poste
		var nodo_farola := Node3D.new()
		nodo_farola.name = "Farola_%d" % p
		nodo_farola.position = pos_base
		nodo_grupo.add_child(nodo_farola)
		
		# Mástil vertical (6.5m)
		var mastil := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.16
		cyl.height = 6.5
		mastil.mesh = cyl
		mastil.position.y = 3.25
		mastil.material_override = mat_poste
		nodo_farola.add_child(mastil)
		
		# Brazo hacia la vía (-lat)
		var dir_hacia_via = -lat
		var brazo := MeshInstance3D.new()
		var box_brazo := BoxMesh.new()
		box_brazo.size = Vector3(0.1, 0.1, 2.2)
		brazo.mesh = box_brazo
		brazo.position = Vector3(0, 6.4, 0) + dir_hacia_via * 1.1
		brazo.material_override = mat_poste
		nodo_farola.add_child(brazo)
		
		# Luminaria LED emisiva
		var lum := MeshInstance3D.new()
		var box_lum := BoxMesh.new()
		box_lum.size = Vector3(0.25, 0.08, 0.5)
		lum.mesh = box_lum
		lum.position = Vector3(0, 6.35, 0) + dir_hacia_via * 2.0
		lum.material_override = mat_luz
		nodo_farola.add_child(lum)
		
		# SpotLight3D iluminando la calzada
		var spot := SpotLight3D.new()
		spot.position = lum.position - Vector3(0, 0.1, 0)
		spot.rotation_degrees = Vector3(-80.0, 0, 0)
		spot.light_color = Color(1.0, 0.95, 0.85)
		spot.light_energy = 1.6
		spot.spot_range = 18.0
		spot.spot_angle = 48.0
		nodo_farola.add_child(spot)

# 5. ÁRBOLES DE BULEVAR ────────────────────────────────────────────────

func aplicar_arboles(segmentos: Array[RoadSegment], lado: LadoEquipamiento, espaciado: float = 18.0) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
			
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			_equipamiento_por_clave[clave] = {}
		_equipamiento_por_clave[clave]["arboles_activa"] = true
		_equipamiento_por_clave[clave]["arboles_lado"] = lado
		_equipamiento_por_clave[clave]["arboles_espaciado"] = espaciado
		_equipamiento_por_clave[clave]["arboles_seleccionados"] = arboles_seleccionados.duplicate()
		_equipamiento_por_clave[clave]["modo_arboles"] = modo_distribucion_arboles
		
		_limpiar_subtipo_en_segmento(seg, "ArbolBulevar")
		
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA:
			_generar_arboles_lado(seg, true, espaciado)
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA:
			_generar_arboles_lado(seg, false, espaciado)
			
	equipamiento_actualizado.emit()

func _generar_arboles_lado(seg: RoadSegment, es_izquierda: bool, espaciado: float) -> void:
	_inicializar_contenedor_equipamiento()
	var curve = _obtener_curva_segmento(seg)
	if not curve:
		return
	var clen = curve.get_baked_length()
	if clen < 8.0:
		return
		
	var sp = seg.start_point
	var ep = seg.end_point
	var acera_w = _obtener_ancho_acera_en_lado(seg, es_izquierda)
	var w_start = _obtener_offset_borde_calzada(seg, sp, es_izquierda) + acera_w + 1.2
	var w_end = _obtener_offset_borde_calzada(seg, ep, es_izquierda) + acera_w + 1.2
	
	var nodo_grupo := Node3D.new()
	nodo_grupo.name = "ArbolBulevar_%s_%s" % ["Izq" if es_izquierda else "Der", seg.name]
	_contenedor_equipamiento.add_child(nodo_grupo)
	_registrar_nodo_segmento(seg, nodo_grupo)
	
	var num_arboles = max(1, int(clen / espaciado))
	var dt = clen / float(num_arboles)
	var pool: Array[String] = arboles_seleccionados if not arboles_seleccionados.is_empty() else ["arbol_sabanero"]
	
	for a in range(num_arboles):
		var s = a * dt + dt * 0.5
		var t = s / clen
		var c = seg.to_global(curve.sample_baked(s))
		var fwd = (seg.to_global(curve.sample_baked(minf(s + 0.5, clen))) - c).normalized()
		if fwd.is_zero_approx() or absf(fwd.dot(Vector3.UP)) > 0.95:
			fwd = Vector3.FORWARD
		var right_vec = Vector3.UP.cross(fwd).normalized()
		if right_vec.is_zero_approx():
			right_vec = Vector3.RIGHT
		var lat = -right_vec if es_izquierda else right_vec
		var dist = lerpf(w_start, w_end, t)
		var pos_arbol = c + lat * dist
		
		var modelo_elegido = pool[0]
		match modo_distribucion_arboles:
			ModoDistribucionArboles.INTERCALADOS:
				modelo_elegido = pool[a % pool.size()]
			ModoDistribucionArboles.ALEATORIOS:
				modelo_elegido = pool[(a * 13 + 7) % pool.size()]
			ModoDistribucionArboles.UNICO:
				modelo_elegido = pool[0]
		
		var arbol = GeneradorModelosCiudad.crear_instancia_objeto(modelo_elegido)
		if arbol:
			arbol.position = pos_arbol
			arbol.rotation_degrees.y = fmod(a * 45.0 + 17.0, 360.0)
			nodo_grupo.add_child(arbol)

# 6. REDUCTORES DE VELOCIDAD ("POLICÍAS ACOSTADOS" / RESALTOS) ─────────

func aplicar_reductores_velocidad(segmentos: Array[RoadSegment]) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			_equipamiento_por_clave[clave] = {}
		_equipamiento_por_clave[clave]["reductor_activo"] = true
		
		_limpiar_subtipo_en_segmento(seg, "ReductorVelocidad")
		_generar_reductor_en_segmento(seg)
		
	equipamiento_actualizado.emit()

func _generar_reductor_en_segmento(seg: RoadSegment) -> void:
	_inicializar_contenedor_equipamiento()
	var curve = _obtener_curva_segmento(seg)
	if not curve:
		return
	var clen = curve.get_baked_length()
	if clen < 4.0:
		return
		
	var sp = seg.start_point
	var w_left = _obtener_offset_borde_calzada(seg, sp, true)
	var w_right = _obtener_offset_borde_calzada(seg, sp, false)
	var ancho_total = w_left + w_right
	
	var nodo_grupo := Node3D.new()
	nodo_grupo.name = "ReductorVelocidad_%s" % seg.name
	_contenedor_equipamiento.add_child(nodo_grupo)
	_registrar_nodo_segmento(seg, nodo_grupo)
	
	# Punto central del tramo vial
	var s = clen * 0.5
	var c = seg.to_global(curve.sample_baked(s))
	var fwd = (seg.to_global(curve.sample_baked(minf(s + 0.5, clen))) - c).normalized()
	if fwd.is_zero_approx() or absf(fwd.dot(Vector3.UP)) > 0.95:
		fwd = Vector3.FORWARD
	var right_vec = Vector3.UP.cross(fwd).normalized()
	if right_vec.is_zero_approx():
		right_vec = Vector3.RIGHT
		
	var body := StaticBody3D.new()
	body.name = "ResaltoFisico"
	nodo_grupo.add_child(body)
	body.global_position = c
	
	# Malla del resalto reflectivo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat_resalto := StandardMaterial3D.new()
	mat_resalto.albedo_color = Color(0.96, 0.78, 0.12) # Amarillo tránsito reflectivo
	mat_resalto.roughness = 0.50
	mat_resalto.metallic = 0.10
	mat_resalto.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var h_apex = 0.08 # 8cm de elevación
	var semi_l = 0.45 # 90cm de ancho longitudinal
	var pasos_ancho = 16
	var dt_w = ancho_total / float(pasos_ancho)
	var x_start = -w_left
	
	for i in range(pasos_ancho):
		var xl0 = x_start + i * dt_w
		var xl1 = x_start + (i + 1) * dt_w
		
		var p0_left = right_vec * xl0
		var p1_left = right_vec * xl1
		
		var v_b0 = p0_left - fwd * semi_l
		var v_b1 = p1_left - fwd * semi_l
		var v_c0 = p0_left + Vector3(0, h_apex, 0)
		var v_c1 = p1_left + Vector3(0, h_apex, 0)
		var v_f0 = p0_left + fwd * semi_l
		var v_f1 = p1_left + fwd * semi_l
		
		# Rampa frontal
		var norm_up = (Vector3.UP * 0.85 - fwd * 0.15).normalized()
		_agregar_quad_con_normal(st, v_b0, v_b1, v_c1, v_c0, norm_up)
		
		# Rampa trasera
		var norm_down = (Vector3.UP * 0.85 + fwd * 0.15).normalized()
		_agregar_quad_con_normal(st, v_c0, v_c1, v_f1, v_f0, norm_down)
		
	st.generate_normals()
	
	var mi := MeshInstance3D.new()
	mi.name = "MallaResalto"
	mi.mesh = st.commit()
	mi.material_override = mat_resalto
	body.add_child(mi)
	
	# Colisión física para respuesta de amortiguación
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ancho_total, h_apex, semi_l * 1.8)
	col.shape = box
	col.position = Vector3(0, h_apex * 0.5, 0)
	body.add_child(col)

# ── MÉTODOS DE LIMPIEZA Y REGISTRO ───────────────────────────────────

func limpiar_equipamiento_tramo() -> Dictionary:
	_actualizar_segmentos_del_tramo()
	if tramo_segmentos.is_empty() and tramo_puntos.is_empty():
		return {"exito": false, "mensaje": "No hay tramo seleccionado para limpiar"}
		
	match tipo_equipamiento_actual:
		TipoEquipamiento.ACERA:
			for seg in tramo_segmentos:
				var clave = _obtener_clave_segmento(seg)
				if _equipamiento_por_clave.has(clave):
					_equipamiento_por_clave[clave]["acera_activa"] = false
				_limpiar_subtipo_en_segmento(seg, "Acera")
			_readaptar_complementos_en_segmentos(tramo_segmentos)
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Aceras removidas del tramo!"}
			
		TipoEquipamiento.BERMA:
			for rp in tramo_puntos:
				if is_instance_valid(rp):
					rp.shoulder_width_l = 0.0
					rp.shoulder_width_r = 0.0
					rp.emit_transform(false)
			if road_container:
				road_container.rebuild_segments(true)
			if controlador_carreteras:
				controlador_carreteras.nivelar_terreno_bajo_carreteras()
			_actualizar_segmentos_del_tramo()
			_readaptar_equipamiento_tramo()
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Bermas removidas y aceras adaptadas al borde vial!"}
			
		TipoEquipamiento.BARRERA:
			for seg in tramo_segmentos:
				var clave = _obtener_clave_segmento(seg)
				if _equipamiento_por_clave.has(clave):
					_equipamiento_por_clave[clave]["barrera_activa"] = false
				_limpiar_subtipo_en_segmento(seg, "Barrera")
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Barreras metálicas removidas del tramo!"}
			
		TipoEquipamiento.POSTE_LUZ:
			for seg in tramo_segmentos:
				var clave = _obtener_clave_segmento(seg)
				if _equipamiento_por_clave.has(clave):
					_equipamiento_por_clave[clave]["postes_activa"] = false
				_limpiar_subtipo_en_segmento(seg, "PosteLuz")
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Alumbrado público removido del tramo!"}
			
		TipoEquipamiento.ARBOLES:
			for seg in tramo_segmentos:
				var clave = _obtener_clave_segmento(seg)
				if _equipamiento_por_clave.has(clave):
					_equipamiento_por_clave[clave]["arboles_activa"] = false
				_limpiar_subtipo_en_segmento(seg, "ArbolBulevar")
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Árboles removidos del tramo!"}
			
		TipoEquipamiento.REDUCTOR_VELOCIDAD:
			for seg in tramo_segmentos:
				var clave = _obtener_clave_segmento(seg)
				if _equipamiento_por_clave.has(clave):
					_equipamiento_por_clave[clave]["reductor_activo"] = false
				_limpiar_subtipo_en_segmento(seg, "ReductorVelocidad")
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Reductores de velocidad removidos del tramo!"}
		TipoEquipamiento.PUENTE_VIADUCTO:
			for seg in tramo_segmentos:
				var clave = _obtener_clave_segmento(seg)
				if _equipamiento_por_clave.has(clave):
					_equipamiento_por_clave[clave]["puente_activo"] = false
				_limpiar_subtipo_en_segmento(seg, "PuenteViaducto")
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Estructuras de viaducto y pilares removidos!"}
		TipoEquipamiento.TUNEL_MONTANA:
			for seg in tramo_segmentos:
				var clave = _obtener_clave_segmento(seg)
				if _equipamiento_por_clave.has(clave):
					_equipamiento_por_clave[clave]["tunel_activo"] = false
				_limpiar_subtipo_en_segmento(seg, "TunelMontana")
			equipamiento_actualizado.emit()
			return {"exito": true, "mensaje": "¡Portales de túnel removidos del tramo!"}
			
	return {"exito": false, "mensaje": "Opción no reconocida"}

func _readaptar_equipamiento_tramo() -> void:
	for seg in tramo_segmentos:
		if not is_instance_valid(seg):
			continue
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			continue
		var cfg: Dictionary = _equipamiento_por_clave[clave]
		
		# 1. Si tenía aceras activas, re-generarlas con el nuevo borde de calzada / berma
		if cfg.get("acera_activa", false):
			var lado: LadoEquipamiento = cfg.get("acera_lado", LadoEquipamiento.AMBOS)
			var ancho: float = cfg.get("acera_ancho", 1.8)
			var old_t = tipo_acera_actual
			if cfg.has("acera_tipo"):
				tipo_acera_actual = cfg["acera_tipo"]
			_limpiar_subtipo_en_segmento(seg, "Acera")
			if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA:
				_generar_malla_acera(seg, true, ancho)
			if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA:
				_generar_malla_acera(seg, false, ancho)
			tipo_acera_actual = old_t
				
		# 2. Si tenía barreras de seguridad activas
		if cfg.get("barrera_activa", false):
			var lado_b: LadoEquipamiento = cfg.get("barrera_lado", LadoEquipamiento.AMBOS)
			_limpiar_subtipo_en_segmento(seg, "Barrera")
			if lado_b == LadoEquipamiento.AMBOS or lado_b == LadoEquipamiento.IZQUIERDA:
				_generar_barrera_guardrail(seg, true)
			if lado_b == LadoEquipamiento.AMBOS or lado_b == LadoEquipamiento.DERECHA:
				_generar_barrera_guardrail(seg, false)
				
		# 3. Si tenía alumbrado público activo
		if cfg.get("postes_activa", false):
			var lado_p: LadoEquipamiento = cfg.get("postes_lado", LadoEquipamiento.AMBOS)
			var esp_p: float = cfg.get("postes_espaciado", 25.0)
			_limpiar_subtipo_en_segmento(seg, "PosteLuz")
			if lado_p == LadoEquipamiento.AMBOS or lado_p == LadoEquipamiento.IZQUIERDA:
				_generar_postes_luz_lado(seg, true, esp_p)
			if lado_p == LadoEquipamiento.AMBOS or lado_p == LadoEquipamiento.DERECHA:
				_generar_postes_luz_lado(seg, false, esp_p)
				
		# 4. Si tenía árboles activos
		if cfg.get("arboles_activa", false):
			var lado_a: LadoEquipamiento = cfg.get("arboles_lado", LadoEquipamiento.AMBOS)
			var esp_a: float = cfg.get("arboles_espaciado", 18.0)
			var old_arb = arboles_seleccionados
			var old_m = modo_distribucion_arboles
			if cfg.has("arboles_seleccionados"):
				arboles_seleccionados = cfg["arboles_seleccionados"]
			if cfg.has("modo_arboles"):
				modo_distribucion_arboles = cfg["modo_arboles"]
			_limpiar_subtipo_en_segmento(seg, "ArbolBulevar")
			if lado_a == LadoEquipamiento.AMBOS or lado_a == LadoEquipamiento.IZQUIERDA:
				_generar_arboles_lado(seg, true, esp_a)
			if lado_a == LadoEquipamiento.AMBOS or lado_a == LadoEquipamiento.DERECHA:
				_generar_arboles_lado(seg, false, esp_a)
			arboles_seleccionados = old_arb
			modo_distribucion_arboles = old_m
			
		# 5. Si tenía reductores de velocidad activos
		if cfg.get("reductor_activo", false):
			_limpiar_subtipo_en_segmento(seg, "ReductorVelocidad")
			_generar_reductor_en_segmento(seg)
			
		# 6. Si tenía puentes / viaductos activos
		if cfg.get("puente_activo", false):
			_limpiar_subtipo_en_segmento(seg, "PuenteViaducto")
			_generar_puente_en_segmento(seg)
			
		# 7. Si tenía túneles activos
		if cfg.get("tunel_activo", false):
			_limpiar_subtipo_en_segmento(seg, "TunelMontana")
			_generar_tunel_en_segmento(seg)

func _readaptar_complementos_en_segmentos(segmentos: Array[RoadSegment]) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			continue
		var cfg: Dictionary = _equipamiento_por_clave[clave]
		if cfg.get("barrera_activa", false):
			var lado_b: LadoEquipamiento = cfg.get("barrera_lado", LadoEquipamiento.AMBOS)
			_limpiar_subtipo_en_segmento(seg, "Barrera")
			if lado_b == LadoEquipamiento.AMBOS or lado_b == LadoEquipamiento.IZQUIERDA:
				_generar_barrera_guardrail(seg, true)
			if lado_b == LadoEquipamiento.AMBOS or lado_b == LadoEquipamiento.DERECHA:
				_generar_barrera_guardrail(seg, false)
		if cfg.get("postes_activa", false):
			var lado_p: LadoEquipamiento = cfg.get("postes_lado", LadoEquipamiento.AMBOS)
			var esp_p: float = cfg.get("postes_espaciado", 25.0)
			_limpiar_subtipo_en_segmento(seg, "PosteLuz")
			if lado_p == LadoEquipamiento.AMBOS or lado_p == LadoEquipamiento.IZQUIERDA:
				_generar_postes_luz_lado(seg, true, esp_p)
			if lado_p == LadoEquipamiento.AMBOS or lado_p == LadoEquipamiento.DERECHA:
				_generar_postes_luz_lado(seg, false, esp_p)
		if cfg.get("arboles_activa", false):
			var lado_a: LadoEquipamiento = cfg.get("arboles_lado", LadoEquipamiento.AMBOS)
			var esp_a: float = cfg.get("arboles_espaciado", 18.0)
			var old_arb = arboles_seleccionados
			var old_m = modo_distribucion_arboles
			if cfg.has("arboles_seleccionados"):
				arboles_seleccionados = cfg["arboles_seleccionados"]
			if cfg.has("modo_arboles"):
				modo_distribucion_arboles = cfg["modo_arboles"]
			_limpiar_subtipo_en_segmento(seg, "ArbolBulevar")
			if lado_a == LadoEquipamiento.AMBOS or lado_a == LadoEquipamiento.IZQUIERDA:
				_generar_arboles_lado(seg, true, esp_a)
			if lado_a == LadoEquipamiento.AMBOS or lado_a == LadoEquipamiento.DERECHA:
				_generar_arboles_lado(seg, false, esp_a)
			arboles_seleccionados = old_arb
			modo_distribucion_arboles = old_m
			
		# 5. Si tenía reductores de velocidad activos
		if cfg.get("reductor_activo", false):
			_limpiar_subtipo_en_segmento(seg, "ReductorVelocidad")
			_generar_reductor_en_segmento(seg)
			
		# 6. Si tenía puentes / viaductos activos
		if cfg.get("puente_activo", false):
			_limpiar_subtipo_en_segmento(seg, "PuenteViaducto")
			_generar_puente_en_segmento(seg)
			
		# 7. Si tenía túneles activos
		if cfg.get("tunel_activo", false):
			_limpiar_subtipo_en_segmento(seg, "TunelMontana")
			_generar_tunel_en_segmento(seg)

func _obtener_clave_segmento(seg: RoadSegment) -> String:
	if not is_instance_valid(seg):
		return ""
	var p_a = seg.start_point
	var p_b = seg.end_point
	if not is_instance_valid(p_a) or not is_instance_valid(p_b):
		return seg.name
	var id_a = p_a.name
	var id_b = p_b.name
	if id_a < id_b:
		return "%s__%s" % [id_a, id_b]
	else:
		return "%s__%s" % [id_b, id_a]

func _limpiar_subtipo_en_segmento(seg: RoadSegment, prefijo_tipo: String) -> void:
	var clave = _obtener_clave_segmento(seg)
	if _nodos_por_clave_segmento.has(clave):
		var lista: Array = _nodos_por_clave_segmento[clave]
		var restantes: Array = []
		for nodo in lista:
			if is_instance_valid(nodo):
				var n_name: String = str(nodo.name)
				var es_tipo = n_name.begins_with(prefijo_tipo) or n_name.contains(prefijo_tipo) or str(nodo.get_meta("subtipo_equip", "")) == prefijo_tipo
				if es_tipo:
					if nodo.get_parent():
						nodo.get_parent().remove_child(nodo)
					nodo.queue_free()
				else:
					restantes.append(nodo)
		_nodos_por_clave_segmento[clave] = restantes
		
	# Limpiar también cualquier nodo huérfano o duplicado en _contenedor_equipamiento para esta clave o tipo
	if is_instance_valid(_contenedor_equipamiento):
		for h in _contenedor_equipamiento.get_children():
			if is_instance_valid(h):
				var h_name: String = str(h.name)
				var coincide_clave = clave.is_empty() or h_name.contains(clave) or str(h.get_meta("clave_seg", "")) == clave
				var coincide_tipo = h_name.contains(prefijo_tipo) or str(h.get_meta("subtipo_equip", "")) == prefijo_tipo
				if coincide_tipo and coincide_clave:
					_contenedor_equipamiento.remove_child(h)
					h.queue_free()

func _registrar_nodo_segmento(seg: RoadSegment, nodo: Node3D) -> void:
	var clave = _obtener_clave_segmento(seg)
	if not _nodos_por_clave_segmento.has(clave):
		_nodos_por_clave_segmento[clave] = []
	_nodos_por_clave_segmento[clave].append(nodo)

func _agregar_tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, normal_esperada: Vector3 = Vector3.ZERO) -> void:
	if normal_esperada != Vector3.ZERO:
		var n = (b - a).cross(c - a)
		if n.dot(normal_esperada) < 0.0:
			var temp_v = b
			b = c
			c = temp_v
			var temp_uv = uvb
			uvb = uvc
			uvc = temp_uv
	st.set_uv(uva)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.add_vertex(c)

func _agregar_quad_con_uv_y_normal(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2, normal_esperada: Vector3) -> void:
	_agregar_tri_uv(st, a, b, c, uva, uvb, uvc, normal_esperada)
	_agregar_tri_uv(st, a, c, d, uva, uvc, uvd, normal_esperada)

func _agregar_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal_esperada: Vector3 = Vector3.ZERO) -> void:
	if normal_esperada != Vector3.ZERO:
		var n = (b - a).cross(c - a)
		if n.dot(normal_esperada) < 0.0:
			var temp = b
			b = c
			c = temp
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _agregar_quad_con_normal(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal_esperada: Vector3) -> void:
	# Quad definido en orden cíclico a -> b -> c -> d
	_agregar_tri(st, a, b, c, normal_esperada)
	_agregar_tri(st, a, c, d, normal_esperada)

func _obtener_offset_borde_calzada(seg: RoadSegment, rp: RoadPoint, es_izquierda: bool) -> float:
	if not is_instance_valid(rp):
		return 3.6
	var n_lanes: int = rp.lanes.size() if (rp.lanes and not rp.lanes.is_empty()) else (rp.traffic_dir.size() if (rp.traffic_dir and not rp.traffic_dir.is_empty()) else 2)
	if n_lanes <= 0:
		n_lanes = 2
	var lw: float = rp.lane_width if rp.lane_width > 0.0 else 3.6
	var half_lanes: float = (n_lanes * lw) * 0.5
	
	var shoulder: float = rp.shoulder_width_l if es_izquierda else rp.shoulder_width_r
	var gutter_x: float = rp.gutter_profile.x if rp.gutter_profile else 0.0
	
	return half_lanes + shoulder + gutter_x

func _obtener_ancho_acera_en_lado(seg: RoadSegment, es_izquierda: bool) -> float:
	var clave = _obtener_clave_segmento(seg)
	if _equipamiento_por_clave.has(clave):
		var cfg: Dictionary = _equipamiento_por_clave[clave]
		if cfg.get("acera_activa", false):
			var lado: int = cfg.get("acera_lado", LadoEquipamiento.AMBOS)
			if lado == LadoEquipamiento.AMBOS or (lado == LadoEquipamiento.IZQUIERDA and es_izquierda) or (lado == LadoEquipamiento.DERECHA and not es_izquierda):
				return cfg.get("acera_ancho", 1.8)
	return 0.0

func _obtener_ancho_via(rp: RoadPoint) -> float:
	if not is_instance_valid(rp):
		return 7.2
	var num_lanes = rp.lanes.size() if (rp.lanes and not rp.lanes.is_empty()) else (rp.traffic_dir.size() if (rp.traffic_dir and not rp.traffic_dir.is_empty()) else 2)
	if num_lanes <= 0:
		num_lanes = 2
	var lw = rp.lane_width if rp.lane_width > 0.0 else 3.6
	return num_lanes * lw


# 6. PUENTES Y VIADUCTOS PROCEDURALES (PILISTAS, VIGAS CABEZAL Y BARANDAS) ─────

func aplicar_puentes_viaductos(segmentos: Array[RoadSegment]) -> void:
	_posiciones_pilares_viaducto.clear()
	# Si el usuario aplica viaducto manualmente a un tramo a ras de suelo, elevar los puntos a +6.0m
	var elevo_puntos := false
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
		for rp in [seg.start_point, seg.end_point]:
			if is_instance_valid(rp):
				var off_actual := float(rp.get_meta("offset_y", 0.0))
				if off_actual < 5.0:
					rp.set_meta("offset_y", 6.0)
					var alt_suelo := 0.0
					if controlador_carreteras and controlador_carreteras.controlador_terreno:
						alt_suelo = controlador_carreteras.controlador_terreno.obtener_altura(rp.global_position)
					var target_y := alt_suelo + (controlador_carreteras.elevacion_sobre_terreno if controlador_carreteras else 0.08) + 6.0
					if rp.is_inside_tree():
						rp.global_position.y = target_y
					else:
						rp.position.y = target_y
					elevo_puntos = true
	if elevo_puntos and road_container:
		road_container.update_edges()
		road_container.rebuild_segments(true)
		if controlador_carreteras:
			controlador_carreteras.actualizar_seleccionadores_puntos()
		_actualizar_segmentos_del_tramo()
		segmentos = tramo_segmentos

	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			_equipamiento_por_clave[clave] = {}
		_equipamiento_por_clave[clave]["puente_activo"] = true
		_limpiar_subtipo_en_segmento(seg, "PuenteViaducto")
		_generar_puente_en_segmento(seg)
	equipamiento_actualizado.emit()

func _generar_puente_en_segmento(seg: RoadSegment) -> void:
	_inicializar_contenedor_equipamiento()
	var curve = _obtener_curva_segmento(seg)
	if not curve:
		return
	var clen = curve.get_baked_length()
	if clen < 2.0:
		return
		
	var clave_seg := _obtener_clave_segmento(seg)
	var nodo_puente := Node3D.new()
	nodo_puente.name = "PuenteViaducto_%s" % clave_seg
	nodo_puente.set_meta("subtipo_equip", "PuenteViaducto")
	nodo_puente.set_meta("clave_seg", clave_seg)
	_contenedor_equipamiento.add_child(nodo_puente)
	_registrar_nodo_segmento(seg, nodo_puente)
	
	# Materiales de alta fidelidad arquitectónica e ingeniería civil
	var mat_concreto := StandardMaterial3D.new()
	mat_concreto.albedo_color = Color(0.86, 0.87, 0.88)
	mat_concreto.roughness = 0.88
	var tex_conc_alb := _cargar_textura_segura("res://mundo/editor_mapas/modelos/texturas/concreto_puente_albedo.png")
	var tex_conc_nrm := _cargar_textura_segura("res://mundo/editor_mapas/modelos/texturas/concreto_puente_normal.png")
	var tex_conc_rgh := _cargar_textura_segura("res://mundo/editor_mapas/modelos/texturas/concreto_puente_roughness.png")
	if tex_conc_alb:
		mat_concreto.albedo_texture = tex_conc_alb
		mat_concreto.uv1_triplanar = true
		mat_concreto.uv1_scale = Vector3(0.35, 0.35, 0.35)
	if tex_conc_nrm:
		mat_concreto.normal_enabled = true
		mat_concreto.normal_texture = tex_conc_nrm
		mat_concreto.normal_scale = 0.75
	if tex_conc_rgh:
		mat_concreto.roughness_texture = tex_conc_rgh
	
	var mat_zapata := StandardMaterial3D.new()
	mat_zapata.albedo_color = Color(0.46, 0.48, 0.50) # Cimentación / zapatas con tono de suelo
	mat_zapata.roughness = 0.92
	
	var mat_neopreno := StandardMaterial3D.new()
	mat_neopreno.albedo_color = Color(0.14, 0.15, 0.16) # Neopreno elastomérico oscuro para apoyos
	mat_neopreno.roughness = 0.65
	
	# Separación civil reglamentaria entre pilas (mínimo 18m entre cualquier par de pilares)
	const DIST_MIN_ENTRE_PILARES: float = 26.0
	
	# Muestreo de candidatos a lo largo de la curva para ubicar vanos
	var candidatos_s: Array[float] = []
	var paso_muestreo: float = 3.0
	var s_iter: float = 3.0
	while s_iter <= clen - 2.5:
		candidatos_s.append(s_iter)
		s_iter += paso_muestreo
	if candidatos_s.is_empty():
		candidatos_s.append(clen * 0.5)
		
	var pilares_creados: int = 0
	var mejor_s_fallback: float = clen * 0.5
	var mejor_delta_fallback: float = -999.0
	
	for s in candidatos_s:
		var p_local = curve.sample_baked(s)
		var p_mundo = seg.to_global(p_local) if seg.is_inside_tree() else (seg.position + p_local)
		
		var alt_terreno: float = 0.0
		if controlador_carreteras and controlador_carreteras.controlador_terreno:
			alt_terreno = controlador_carreteras.controlador_terreno.obtener_altura(p_mundo)
		
		var delta_h: float = p_mundo.y - alt_terreno
		if delta_h > mejor_delta_fallback:
			mejor_delta_fallback = delta_h
			mejor_s_fallback = s
		
		# Solo crear pilares si la vía tiene gálibo estructural (>= 2.8m sobre el terreno)
		if delta_h < 2.8:
			continue
		
		# Filtro de distancia mínima global: evitar pilares apiñados entre tramos contiguos
		var demasiado_cerca := false
		for pos_existente in _posiciones_pilares_viaducto:
			var d_xz := Vector2(p_mundo.x - pos_existente.x, p_mundo.z - pos_existente.z).length()
			if d_xz < DIST_MIN_ENTRE_PILARES:
				demasiado_cerca = true
				break
		if demasiado_cerca:
			continue
		
		pilares_creados += 1
		_posiciones_pilares_viaducto.append(p_mundo)
		_instanciar_pilar_en_curva(nodo_puente, seg, curve, clen, s, p_mundo, alt_terreno, delta_h, pilares_creados, mat_concreto, mat_zapata, mat_neopreno)
		
	# Fallback garantizado: si el tramo alcanzó cota elevada pero ningún candidato superó el filtro, colocar 1 pilar en la cota máxima
	if pilares_creados == 0 and mejor_delta_fallback >= 2.0:
		var p_local_fb = curve.sample_baked(mejor_s_fallback)
		var p_mundo_fb = seg.to_global(p_local_fb) if seg.is_inside_tree() else (seg.position + p_local_fb)
		var cerca_fb := false
		for pos_existente in _posiciones_pilares_viaducto:
			var d_xz := Vector2(p_mundo_fb.x - pos_existente.x, p_mundo_fb.z - pos_existente.z).length()
			if d_xz < (DIST_MIN_ENTRE_PILARES * 0.75):
				cerca_fb = true
				break
		if not cerca_fb:
			var alt_terr_fb: float = 0.0
			if controlador_carreteras and controlador_carreteras.controlador_terreno:
				alt_terr_fb = controlador_carreteras.controlador_terreno.obtener_altura(p_mundo_fb)
			_posiciones_pilares_viaducto.append(p_mundo_fb)
			_instanciar_pilar_en_curva(nodo_puente, seg, curve, clen, mejor_s_fallback, p_mundo_fb, alt_terr_fb, p_mundo_fb.y - alt_terr_fb, 1, mat_concreto, mat_zapata, mat_neopreno)

	# Pretiles / barandas New Jersey perfilados en el borde exterior + baranda metálica + postes Blender
	if pilares_creados > 0 or mejor_delta_fallback >= 2.0:
		var st_p := SurfaceTool.new()
		st_p.begin(Mesh.PRIMITIVE_TRIANGLES)
		var st_rail := SurfaceTool.new()
		st_rail.begin(Mesh.PRIMITIVE_TRIANGLES)
		var paso_p := 2.0
		var num_p := maxi(3, int(ceil(clen / paso_p)) + 1)

		var add_tri_cw := func(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n_esp: Vector3) -> void:
			# En Godot 4, las caras frontales son horarias (CW): (b - a).cross(c - a) apunta opuesto a n_esp
			if (b - a).cross(c - a).dot(n_esp) > 0.0:
				var tmp := b
				b = c
				c = tmp
			st.set_normal(n_esp)
			st.add_vertex(a)
			st.set_normal(n_esp)
			st.add_vertex(b)
			st.set_normal(n_esp)
			st.add_vertex(c)

		var add_quad_cw := func(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n_esp: Vector3) -> void:
			add_tri_cw.call(st, a, b, c, n_esp)
			add_tri_cw.call(st, a, c, d, n_esp)

		var esc_poste: PackedScene = null
		const RUTA_POSTE_GLB := "res://mundo/editor_mapas/modelos/poste_baranda_puente.glb"
		if ResourceLoader.exists(RUTA_POSTE_GLB):
			esc_poste = load(RUTA_POSTE_GLB) as PackedScene

		for lado_p: float in [-1.0, 1.0]:
			var es_izq: bool = (lado_p < 0.0)
			var off_ini: float = _obtener_offset_borde_calzada(seg, seg.start_point, es_izq) + _obtener_ancho_acera_en_lado(seg, es_izq)
			var off_fin: float = _obtener_offset_borde_calzada(seg, seg.end_point, es_izq) + _obtener_ancho_acera_en_lado(seg, es_izq)
			var dist_poste_acc: float = 1.5
			for i in range(num_p - 1):
				var s0 := minf(float(i) * (clen / float(num_p - 1)), clen)
				var s1 := minf(float(i + 1) * (clen / float(num_p - 1)), clen)
				var t0 := clampf(s0 / clen, 0.0, 1.0)
				var t1 := clampf(s1 / clen, 0.0, 1.0)
				var edge_0: float = lerpf(off_ini, off_fin, t0)
				var edge_1: float = lerpf(off_ini, off_fin, t1)

				var p0 := seg.to_global(curve.sample_baked(s0)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s0))
				var p1 := seg.to_global(curve.sample_baked(s1)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s1))
				var dir_3d := (p1 - p0)
				if dir_3d.length_squared() < 0.0001:
					continue
				dir_3d = dir_3d.normalized()
				var dir_h := Vector3(dir_3d.x, 0.0, dir_3d.z)
				dir_h = dir_h.normalized() if dir_h.length_squared() > 0.0001 else Vector3.FORWARD
				var lat_p := dir_h.cross(Vector3.UP).normalized()
				var out_v := lat_p * lado_p
				var in_v := -out_v

				# Posicionado exactamente en el borde exterior de la vía (sin invadir la línea blanca ni la berma)
				var c0 := p0 + out_v * edge_0
				var c1 := p1 + out_v * edge_1
				var prof0: Array[Vector3] = [
					c0 + Vector3(0, -0.28, 0),
					c0 + Vector3(0, 0.14, 0),
					c0 + out_v * 0.14 + Vector3(0, 0.38, 0),
					c0 + out_v * 0.20 + Vector3(0, 0.82, 0),
					c0 + out_v * 0.38 + Vector3(0, 0.82, 0),
					c0 + out_v * 0.38 + Vector3(0, -0.28, 0)
				]
				var prof1: Array[Vector3] = [
					c1 + Vector3(0, -0.28, 0),
					c1 + Vector3(0, 0.14, 0),
					c1 + out_v * 0.14 + Vector3(0, 0.38, 0),
					c1 + out_v * 0.20 + Vector3(0, 0.82, 0),
					c1 + out_v * 0.38 + Vector3(0, 0.82, 0),
					c1 + out_v * 0.38 + Vector3(0, -0.28, 0)
				]
				var norms: Array[Vector3] = [
					in_v,
					(in_v + Vector3(0, 0.58, 0)).normalized(),
					(in_v + Vector3(0, 0.14, 0)).normalized(),
					Vector3.UP,
					out_v
				]
				for k in range(5):
					add_quad_cw.call(st_p, prof0[k], prof1[k], prof1[k + 1], prof0[k + 1], norms[k])

				# Tapas en extremos del puente para evitar huecos abiertos
				if i == 0:
					add_quad_cw.call(st_p, prof0[0], prof0[1], prof0[4], prof0[5], -dir_h)
					add_quad_cw.call(st_p, prof0[1], prof0[2], prof0[3], prof0[4], -dir_h)
				if i == num_p - 2:
					add_quad_cw.call(st_p, prof1[5], prof1[4], prof1[1], prof1[0], dir_h)
					add_quad_cw.call(st_p, prof1[4], prof1[3], prof1[2], prof1[1], dir_h)

				# Pasamanos metálico superior continuo (y = 1.09m a 1.17m) centrado sobre la corona del pretil
				var rc0 := c0 + out_v * 0.29
				var rc1 := c1 + out_v * 0.29
				var r_in := in_v * 0.045
				var r_out := out_v * 0.045
				var ry_b := Vector3(0, 1.09, 0)
				var ry_t := Vector3(0, 1.17, 0)
				add_quad_cw.call(st_rail, rc0 + r_in + ry_b, rc1 + r_in + ry_b, rc1 + r_in + ry_t, rc0 + r_in + ry_t, in_v)
				add_quad_cw.call(st_rail, rc0 + r_in + ry_t, rc1 + r_in + ry_t, rc1 + r_out + ry_t, rc0 + r_out + ry_t, Vector3.UP)
				add_quad_cw.call(st_rail, rc1 + r_out + ry_b, rc0 + r_out + ry_b, rc0 + r_out + ry_t, rc1 + r_out + ry_t, out_v)
				add_quad_cw.call(st_rail, rc1 + r_in + ry_b, rc0 + r_in + ry_b, rc0 + r_out + ry_b, rc1 + r_out + ry_b, Vector3.DOWN)

				# Postes modulares Blender con reflector cada 4.0m
				dist_poste_acc += (s1 - s0)
				if esc_poste and dist_poste_acc >= 4.0:
					dist_poste_acc = 0.0
					var poste := esc_poste.instantiate()
					if poste is Node3D:
						var p3d := poste as Node3D
						p3d.position = rc0 + Vector3(0, 0.82, 0)
						p3d.basis = Basis(lat_p, Vector3.UP, -dir_h).orthonormalized()
					nodo_puente.add_child(poste)

		var mesh_pretiles := st_p.commit()
		if mesh_pretiles:
			var mi_pret := MeshInstance3D.new()
			mi_pret.name = "PretilesViaducto"
			mi_pret.mesh = mesh_pretiles
			mi_pret.material_override = mat_concreto
			nodo_puente.add_child(mi_pret)
			mi_pret.create_trimesh_collision()

		var mesh_rail := st_rail.commit()
		if mesh_rail:
			var mat_rail := StandardMaterial3D.new()
			mat_rail.albedo_color = Color(0.62, 0.65, 0.68)
			mat_rail.metallic = 0.85
			mat_rail.roughness = 0.35
			var mi_rail := MeshInstance3D.new()
			mi_rail.name = "BarandaAceroPuente"
			mi_rail.mesh = mesh_rail
			mi_rail.material_override = mat_rail
			nodo_puente.add_child(mi_rail)

func _instanciar_pilar_en_curva(nodo_puente: Node3D, seg: RoadSegment, curve: Curve3D, clen: float, s: float, p_mundo: Vector3, alt_terreno: float, delta_h: float, indice_pilar: int, mat_concreto: StandardMaterial3D, mat_zapata: StandardMaterial3D, mat_neopreno: StandardMaterial3D) -> void:
	var pilar_body := StaticBody3D.new()
	pilar_body.name = "Pilar_%d" % indice_pilar
	nodo_puente.add_child(pilar_body)
	
	# Despeje vertical bajo la rasante para garantizar que jamás corte el asfalto de la vía
	const DESPEJE_BAJO_RASANTE: float = 0.42
	var cota_tope: float = p_mundo.y - DESPEJE_BAJO_RASANTE
	var h_total: float = maxf(1.8, cota_tope - alt_terreno)
	
	# Vector tangente longitudinal y lateral de la calzada
	var s_prev: float = maxf(0.0, s - 1.0)
	var s_next: float = minf(clen, s + 1.0)
	var p_prev: Vector3 = seg.to_global(curve.sample_baked(s_prev)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_prev))
	var p_next: Vector3 = seg.to_global(curve.sample_baked(s_next)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_next))
	
	var fwd_3d: Vector3 = (p_next - p_prev).normalized()
	var fwd_h: Vector3 = Vector3(fwd_3d.x, 0.0, fwd_3d.z)
	if fwd_h.length_squared() < 0.001:
		fwd_h = Vector3.FORWARD
	else:
		fwd_h = fwd_h.normalized()
		
	var derecha_h: Vector3 = fwd_h.cross(Vector3.UP).normalized()
	if derecha_h.length_squared() < 0.001:
		derecha_h = Vector3.RIGHT
		
	# Ubicar el StaticBody en la base (suelo) con orientación transversal perpendicular a la vía
	var b := Basis()
	b.x = derecha_h
	b.y = Vector3.UP
	b.z = fwd_h
	var xf := Transform3D(b.orthonormalized(), Vector3(p_mundo.x, alt_terreno, p_mundo.z))
	if pilar_body.is_inside_tree():
		pilar_body.global_transform = xf
	else:
		pilar_body.transform = xf
		
	var ancho_deck: float = _obtener_ancho_via(seg.start_point if seg.start_point else null)
	var ancho_cabezal: float = maxf(3.2, ancho_deck - 0.40)
	
	# Intentar instanciar el modelo 3D profesional de Blender (Pilar_Viaducto_4G)
	const RUTA_MODELO_PILAR_4G := "res://mundo/editor_mapas/modelos/pilar_viaducto_4g.glb"
	var escena_pilar_4g: PackedScene = load(RUTA_MODELO_PILAR_4G) if ResourceLoader.exists(RUTA_MODELO_PILAR_4G) else null
	if escena_pilar_4g:
		var inst_pilar: Node3D = escena_pilar_4g.instantiate() as Node3D
		if inst_pilar:
			inst_pilar.name = "Modelo_Pilar_Viaducto_4G"
			pilar_body.add_child(inst_pilar)
			
			var nodo_zapata: Node3D = inst_pilar.find_child("01_Cimentacion_Zapata", true, false) as Node3D
			var nodo_fuste: Node3D = inst_pilar.find_child("02_Fuste_Columna", true, false) as Node3D
			var nodo_capitel: Node3D = inst_pilar.find_child("03_Capitel_Martillo", true, false) as Node3D
			
			var escala_x_cap: float = clampf(ancho_cabezal / 8.60, 0.55, 2.20)
			if nodo_zapata and nodo_fuste and nodo_capitel:
				const H_CAP_MESH := 2.32
				const H_ZAP_MESH := 1.20
				const H_FUSTE_MESH := 4.60
				
				var h_cap: float = clampf(h_total * 0.28, 1.20, H_CAP_MESH)
				var sy_cap: float = h_cap / H_CAP_MESH
				var y_base_cap: float = maxf(0.80, h_total - h_cap)
				nodo_capitel.position = Vector3(0.0, y_base_cap, 0.0)
				nodo_capitel.scale = Vector3(escala_x_cap, sy_cap, 1.0)
				
				var h_zap: float = clampf(h_total * 0.18, 0.50, H_ZAP_MESH)
				var sy_zap: float = h_zap / H_ZAP_MESH
				nodo_zapata.position = Vector3.ZERO
				nodo_zapata.scale = Vector3(clampf(escala_x_cap, 0.75, 1.35), sy_zap, 1.0)
				
				var h_fuste_real: float = maxf(0.20, y_base_cap - h_zap)
				var sy_fuste: float = h_fuste_real / H_FUSTE_MESH
				nodo_fuste.position = Vector3(0.0, h_zap, 0.0)
				nodo_fuste.scale = Vector3(clampf(escala_x_cap, 0.80, 1.30), sy_fuste, 1.0)
			else:
				inst_pilar.scale = Vector3(escala_x_cap, h_total / 8.0, 1.0)
				
			var col_shape_4g := CollisionShape3D.new()
			var box_shape_4g := BoxShape3D.new()
			box_shape_4g.size = Vector3(ancho_cabezal, h_total, 2.2)
			col_shape_4g.shape = box_shape_4g
			col_shape_4g.position = Vector3(0, h_total * 0.5, 0)
			pilar_body.add_child(col_shape_4g)
			return
	
	# 1. ZAPATA ESCALONADA (Plinto de cimentación a nivel de tierra - Fallback procedural)
	var zapata_base := MeshInstance3D.new()
	var box_zb := BoxMesh.new()
	box_zb.size = Vector3(minf(ancho_cabezal + 0.6, 4.4), 0.60, 3.2)
	zapata_base.mesh = box_zb
	zapata_base.position = Vector3(0, 0.30, 0)
	zapata_base.material_override = mat_zapata
	pilar_body.add_child(zapata_base)
	
	var zapata_pedestal := MeshInstance3D.new()
	var box_zp := BoxMesh.new()
	box_zp.size = Vector3(minf(ancho_cabezal, 3.4), 0.40, 2.4)
	zapata_pedestal.mesh = box_zp
	zapata_pedestal.position = Vector3(0, 0.80, 0)
	zapata_pedestal.material_override = mat_zapata
	pilar_body.add_child(zapata_pedestal)
	
	var h_cimentacion: float = 1.0
	var h_remate: float = 1.1 # Cabezal + ménsulas + apoyos
	var h_col: float = maxf(0.5, h_total - h_cimentacion - h_remate)
	var y_centro_col: float = h_cimentacion + (h_col * 0.5)
	
	# 2. FUSTE / COLUMNA ESTRUCTURAL
	if ancho_deck >= 13.5:
		# Viaductos anchos: Doble columna cilíndrica aerodinámica (bipilar)
		var d_offset: float = ancho_cabezal * 0.28
		for sign_col in [-1.0, 1.0]:
			var col_bi := MeshInstance3D.new()
			var cyl_bi := CylinderMesh.new()
			cyl_bi.top_radius = 0.95
			cyl_bi.bottom_radius = 1.15
			cyl_bi.height = h_col
			col_bi.mesh = cyl_bi
			col_bi.position = Vector3(sign_col * d_offset, y_centro_col, 0)
			col_bi.material_override = mat_concreto
			pilar_body.add_child(col_bi)
	else:
		# Viaductos estándar: Columna monolítica redondeada / biselada de alta esbeltez
		var col_mono := MeshInstance3D.new()
		var box_mono := BoxMesh.new()
		box_mono.size = Vector3(2.4, h_col, 1.8)
		col_mono.mesh = box_mono
		col_mono.position = Vector3(0, y_centro_col, 0)
		col_mono.material_override = mat_concreto
		pilar_body.add_child(col_mono)
		
		# Aletas/bordes semicilíndricos para acabado arquitectónico curvo
		for sign_edge in [-1.0, 1.0]:
			var borde_col := MeshInstance3D.new()
			var cyl_borde := CylinderMesh.new()
			cyl_borde.top_radius = 0.90
			cyl_borde.bottom_radius = 0.90
			cyl_borde.height = h_col
			borde_col.mesh = cyl_borde
			borde_col.position = Vector3(sign_edge * 1.2, y_centro_col, 0)
			borde_col.material_override = mat_concreto
			pilar_body.add_child(borde_col)
			
	# 3. CAPITEL EN MARTILLO Y MÉNSULAS EN VOLADIZO (Hammerhead Cantilever)
	# Transición ensanchada bajo la viga transversal
	var mensula_inf := MeshInstance3D.new()
	var box_minf := BoxMesh.new()
	box_minf.size = Vector3(ancho_cabezal * 0.70, 0.35, 1.4)
	mensula_inf.mesh = box_minf
	mensula_inf.position = Vector3(0, h_total - 0.75, 0)
	mensula_inf.material_override = mat_concreto
	pilar_body.add_child(mensula_inf)
	
	# Viga transversal superior completa
	var viga_sup := MeshInstance3D.new()
	var box_vsup := BoxMesh.new()
	box_vsup.size = Vector3(ancho_cabezal, 0.35, 1.3)
	viga_sup.mesh = box_vsup
	viga_sup.position = Vector3(0, h_total - 0.40, 0)
	viga_sup.material_override = mat_concreto
	pilar_body.add_child(viga_sup)
	
	# 4. ALMOHADILLAS DE NEOPRENO ELASTOMÉRICO (Apoyos estructurales de vigas)
	var offsets_apoyos: Array[float] = [-ancho_cabezal * 0.32, ancho_cabezal * 0.32]
	if ancho_cabezal >= 10.0:
		offsets_apoyos.append(-ancho_cabezal * 0.11)
		offsets_apoyos.append(ancho_cabezal * 0.11)
		
	for ox in offsets_apoyos:
		var pad := MeshInstance3D.new()
		var box_pad := BoxMesh.new()
		box_pad.size = Vector3(0.65, 0.08, 0.55)
		pad.mesh = box_pad
		pad.position = Vector3(ox, h_total - 0.18, 0)
		pad.material_override = mat_neopreno
		pilar_body.add_child(pad)
		
	# 5. COLISIONADOR FÍSICO INTEGRADO
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(ancho_cabezal, h_total, 2.0)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0, h_total * 0.5, 0)
	pilar_body.add_child(col_shape)

# 7. TÚNELES DE MONTAÑA PROCEDURALES (PORTALES MODULARES E ILUMINACIÓN) ───────

func aplicar_tuneles(segmentos: Array[RoadSegment]) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg):
			continue
		var clave = _obtener_clave_segmento(seg)
		if not _equipamiento_por_clave.has(clave):
			_equipamiento_por_clave[clave] = {}
		_equipamiento_por_clave[clave]["tunel_activo"] = true
		_limpiar_subtipo_en_segmento(seg, "TunelMontana")
		_generar_tunel_en_segmento(seg)
	equipamiento_actualizado.emit()

func _generar_tunel_en_segmento(seg: RoadSegment) -> void:
	_inicializar_contenedor_equipamiento()
	var curve = _obtener_curva_segmento(seg)
	if not curve:
		return
	var clen = curve.get_baked_length()
	if clen < 4.0:
		return
		
	var clave_seg_t := _obtener_clave_segmento(seg)
	var nodo_tunel := Node3D.new()
	nodo_tunel.name = "TunelMontana_%s" % clave_seg_t
	nodo_tunel.set_meta("subtipo_equip", "TunelMontana")
	nodo_tunel.set_meta("clave_seg", clave_seg_t)
	_contenedor_equipamiento.add_child(nodo_tunel)
	_registrar_nodo_segmento(seg, nodo_tunel)
	
	var ancho_via: float = _obtener_ancho_via(seg.start_point if seg.start_point else null)
	var mat_portal := StandardMaterial3D.new()
	mat_portal.albedo_color = Color(0.25, 0.26, 0.28) # Concreto oscuro / roca excavada
	mat_portal.roughness = 0.95
	
	var mat_franjas := StandardMaterial3D.new()
	mat_franjas.albedo_color = Color(0.92, 0.72, 0.15) # Franja amarilla reflectiva
	mat_franjas.emission_enabled = true
	mat_franjas.emission = Color(0.92, 0.72, 0.15)
	mat_franjas.emission_energy_multiplier = 0.6
	
	# Construir portal en boca de entrada (s = 1.5m) y salida (s = clen - 1.5m)
	for s_portal in [1.5, clen - 1.5]:
		var p_local = curve.sample_baked(s_portal)
		var p_mundo = seg.to_global(p_local) if seg.is_inside_tree() else (seg.position + p_local)
		var dir := Vector3.FORWARD
		if s_portal < clen * 0.5:
			var p_sig = seg.to_global(curve.sample_baked(minf(s_portal + 1.0, clen))) if seg.is_inside_tree() else (seg.position + curve.sample_baked(minf(s_portal + 1.0, clen)))
			dir = (p_sig - p_mundo)
		else:
			var p_ant = seg.to_global(curve.sample_baked(maxf(s_portal - 1.0, 0.0))) if seg.is_inside_tree() else (seg.position + curve.sample_baked(maxf(s_portal - 1.0, 0.0)))
			dir = (p_mundo - p_ant)
		dir.y = 0.0
		dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD
		var lat := dir.cross(Vector3.UP).normalized()
		if lat.length_squared() < 0.001:
			lat = Vector3.RIGHT
		
		var portal_body := StaticBody3D.new()
		portal_body.name = "Portal_%.0f" % s_portal
		nodo_tunel.add_child(portal_body)
		
		var b := Basis()
		b.x = lat
		b.y = Vector3.UP
		b.z = dir
		var xf_portal := Transform3D(b.orthonormalized(), p_mundo)
		if portal_body.is_inside_tree():
			portal_body.global_transform = xf_portal
		else:
			portal_body.transform = xf_portal
		
		# Arco superior del portal
		var arco_mesh := MeshInstance3D.new()
		var box_arco := BoxMesh.new()
		box_arco.size = Vector3(ancho_via + 2.4, 1.4, 2.5)
		arco_mesh.mesh = box_arco
		arco_mesh.position = Vector3(0, 5.8, 0)
		arco_mesh.material_override = mat_portal
		portal_body.add_child(arco_mesh)
		
		# Franja reflectiva superior de gálibo
		var franja_mesh := MeshInstance3D.new()
		var box_franja := BoxMesh.new()
		box_franja.size = Vector3(ancho_via + 2.0, 0.4, 2.6)
		franja_mesh.mesh = box_franja
		franja_mesh.position = Vector3(0, 5.0, 0)
		franja_mesh.material_override = mat_franjas
		portal_body.add_child(franja_mesh)
		
		# Columnas laterales del portal
		for lado_col in [-1.0, 1.0]:
			var col_m := MeshInstance3D.new()
			var col_b := BoxMesh.new()
			col_b.size = Vector3(1.2, 6.0, 2.5)
			col_m.mesh = col_b
			col_m.position = Vector3(lado_col * ((ancho_via * 0.5) + 0.6), 3.0, 0)
			col_m.material_override = mat_portal
			portal_body.add_child(col_m)
			
			var c_shape := CollisionShape3D.new()
			var b_shape := BoxShape3D.new()
			b_shape.size = Vector3(1.2, 6.0, 2.5)
			c_shape.shape = b_shape
			c_shape.position = col_m.position
			portal_body.add_child(c_shape)
		
	# Tubo del túnel (paredes laterales y techo) a lo largo del trayecto subterráneo
	var s_tubo: float = 2.0
	while s_tubo <= clen - 2.0:
		var p_local = curve.sample_baked(s_tubo)
		var p_mundo = seg.to_global(p_local) if seg.is_inside_tree() else (seg.position + p_local)
		var dir := Vector3.FORWARD
		if s_tubo + 1.0 <= clen:
			var p_sig_t = seg.to_global(curve.sample_baked(s_tubo + 1.0)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_tubo + 1.0))
			dir = (p_sig_t - p_mundo)
		dir.y = 0.0
		dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD
		var lat := dir.cross(Vector3.UP).normalized()
		if lat.length_squared() < 0.001:
			lat = Vector3.RIGHT
		
		var seccion := StaticBody3D.new()
		seccion.name = "TuboSec_%.0f" % s_tubo
		nodo_tunel.add_child(seccion)
		var b := Basis()
		b.x = lat
		b.y = Vector3.UP
		b.z = dir
		var xf_sec := Transform3D(b.orthonormalized(), p_mundo)
		if seccion.is_inside_tree():
			seccion.global_transform = xf_sec
		else:
			seccion.transform = xf_sec
		
		# Techo
		var techo := MeshInstance3D.new()
		var box_t := BoxMesh.new()
		box_t.size = Vector3(ancho_via + 2.0, 0.8, 4.2)
		techo.mesh = box_t
		techo.position = Vector3(0, 5.8, 0)
		techo.material_override = mat_portal
		seccion.add_child(techo)
		
		# Pared izquierda y derecha
		for lado in [-1.0, 1.0]:
			var pared := MeshInstance3D.new()
			var box_p := BoxMesh.new()
			box_p.size = Vector3(1.0, 5.6, 4.2)
			pared.mesh = box_p
			pared.position = Vector3(lado * ((ancho_via * 0.5) + 0.5), 2.8, 0)
			pared.material_override = mat_portal
			seccion.add_child(pared)
			
		s_tubo += 4.0
	
	# Luces de sodio en el interior del túnel cada 16m
	var s_luz: float = 12.0
	while s_luz <= clen - 12.0:
		var p_luz_base = seg.to_global(curve.sample_baked(s_luz)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_luz))
		var p_luz = p_luz_base + Vector3(0, 5.2, 0)
		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0, 0.82, 0.45) # Ámbar sodio
		omni.light_energy = 1.2
		omni.omni_range = 14.0
		omni.omni_attenuation = 1.2
		nodo_tunel.add_child(omni)
		if omni.is_inside_tree():
			omni.global_position = p_luz
		else:
			omni.position = p_luz
		s_luz += 16.0


# ── SISTEMA AUTOMÁTICO DE PUENTES, VIADUCTOS Y TÚNELES ───────────────

func actualizar_puentes_y_tuneles_automaticos() -> void:
	if not is_instance_valid(road_container) and controlador_carreteras and is_instance_valid(controlador_carreteras.road_container):
		road_container = controlador_carreteras.road_container
	if not is_instance_valid(road_container):
		return
	_inicializar_contenedor_equipamiento()
	_posiciones_pilares_viaducto.clear()
	
	# Barrido global inmediato de todos los puentes y túneles previos para impedir duplicación (@Node3D@...)
	if is_instance_valid(_contenedor_equipamiento):
		for h in _contenedor_equipamiento.get_children():
			if not is_instance_valid(h):
				continue
			var st_meta := str(h.get_meta("subtipo_equip", ""))
			var es_puente_o_tunel := st_meta in ["PuenteViaducto", "TunelMontana"] or h.name.begins_with("PuenteViaducto") or h.name.begins_with("TunelMontana")
			if not es_puente_o_tunel and h.name.begins_with("@Node3D@"):
				for sub in h.get_children():
					if sub.name.begins_with("Pilar_") or sub.name.begins_with("Portal_") or sub.name.begins_with("TuboSec_"):
						es_puente_o_tunel = true
						break
			if es_puente_o_tunel:
				_contenedor_equipamiento.remove_child(h)
				h.queue_free()
	
	var segs = road_container.get_segments() if road_container.has_method('get_segments') else []
	for seg in segs:
		if not seg or not is_instance_valid(seg):
			continue
			
		var curve = _obtener_curva_segmento(seg)
		if not curve:
			continue
		var clen = curve.get_baked_length()
		if clen < 2.0:
			continue
			
		var max_elevacion: float = -999.0
		var min_elevacion: float = 999.0
		
		# Evaluar también los puntos extremos del segmento directamente (offset_y y altura real)
		for rp_ext in [seg.start_point, seg.end_point]:
			if is_instance_valid(rp_ext):
				var off_meta := float(rp_ext.get_meta("offset_y", 0.0))
				max_elevacion = maxf(max_elevacion, off_meta)
				min_elevacion = minf(min_elevacion, off_meta)
				var pos_rp: Vector3 = rp_ext.global_position if rp_ext.is_inside_tree() else rp_ext.position
				var alt_t_rp: float = 0.0
				if controlador_carreteras and controlador_carreteras.controlador_terreno:
					alt_t_rp = controlador_carreteras.controlador_terreno.obtener_altura(pos_rp)
				var delta_rp: float = pos_rp.y - alt_t_rp
				max_elevacion = maxf(max_elevacion, delta_rp)
				min_elevacion = minf(min_elevacion, delta_rp)
		
		# Muestrear de extremo a extremo (0.0 a clen) sin omitir las puntas
		var num_muestras: int = maxi(8, int(ceil(clen / 2.5)))
		for i in range(num_muestras + 1):
			var s: float = (float(i) / float(num_muestras)) * clen
			var p_mundo = seg.to_global(curve.sample_baked(s)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s))
			var alt_terr: float = 0.0
			if controlador_carreteras and controlador_carreteras.controlador_terreno:
				alt_terr = controlador_carreteras.controlador_terreno.obtener_altura(p_mundo)
			var delta = p_mundo.y - alt_terr
			max_elevacion = maxf(max_elevacion, delta)
			min_elevacion = minf(min_elevacion, delta)
			
		# Limpiar nodos automáticos previos
		_limpiar_subtipo_en_segmento(seg, "PuenteViaducto")
		_limpiar_subtipo_en_segmento(seg, "TunelMontana")
		
		var clave = _obtener_clave_segmento(seg)
		var puente_forzado: bool = _equipamiento_por_clave.get(clave, {}).get("puente_activo", false)
		var tunel_forzado: bool = _equipamiento_por_clave.get(clave, {}).get("tunel_activo", false)
		
		# Si la vía se eleva umbral_altura_puente (por defecto 3.0m) o más -> Generar pilares de viaducto
		var umbral_p: float = controlador_carreteras.umbral_altura_puente if controlador_carreteras else 3.0
		if max_elevacion >= umbral_p or puente_forzado:
			_generar_puente_en_segmento(seg)
			
		# Si la montaña pasa 12.0m o más por encima de la vía -> Generar portales y tubo de túnel
		if min_elevacion <= -12.0 or tunel_forzado:
			_generar_tunel_en_segmento(seg)

func colocar_reductor_en_posicion_mundo(pos_mundo: Vector3) -> bool:
	if not road_container:
		return false
	_inicializar_contenedor_equipamiento()
	
	var mejor_seg: RoadSegment = null
	var mejor_dist: float = 12.0
	var mejor_s: float = 0.0
	
	var segs = road_container.get_segments() if road_container.has_method('get_segments') else []
	for seg in segs:
		if not seg or not is_instance_valid(seg):
			continue
		var curve = _obtener_curva_segmento(seg)
		if not curve or curve.get_baked_length() < 3.0:
			continue
			
		var local_pos = seg.to_local(pos_mundo)
		var s_offset = curve.get_closest_offset(local_pos)
		var pt_curve = seg.to_global(curve.sample_baked(s_offset))
		var d = pos_mundo.distance_to(pt_curve)
		if d < mejor_dist:
			mejor_dist = d
			mejor_seg = seg
			mejor_s = s_offset
			
	if not mejor_seg:
		return false
		
	var curve = _obtener_curva_segmento(mejor_seg)
	var clen = curve.get_baked_length()
	var sp = mejor_seg.start_point
	var w_left = _obtener_offset_borde_calzada(mejor_seg, sp, true)
	var w_right = _obtener_offset_borde_calzada(mejor_seg, sp, false)
	var ancho_total = w_left + w_right
	
	var nodo_grupo := Node3D.new()
	nodo_grupo.name = "ReductorVelocidad_%s_%.0f" % [mejor_seg.name, mejor_s]
	_contenedor_equipamiento.add_child(nodo_grupo)
	_registrar_nodo_segmento(mejor_seg, nodo_grupo)
	
	var c = mejor_seg.to_global(curve.sample_baked(mejor_s))
	var fwd = (mejor_seg.to_global(curve.sample_baked(minf(mejor_s + 0.5, clen))) - c).normalized()
	if fwd.is_zero_approx() or absf(fwd.dot(Vector3.UP)) > 0.95:
		fwd = Vector3.FORWARD
	var right_vec = Vector3.UP.cross(fwd).normalized()
	
	var sb := StaticBody3D.new()
	sb.name = "ResaltoFisico"
	nodo_grupo.add_child(sb)
	var basis_sb := Basis()
	basis_sb.x = right_vec
	basis_sb.y = Vector3.UP
	basis_sb.z = fwd
	var xf_sb := Transform3D(basis_sb.orthonormalized(), c + Vector3(0, 0.04, 0))
	if sb.is_inside_tree():
		sb.global_transform = xf_sb
	else:
		sb.transform = xf_sb
	
	# Malla del resalto con franjas amarillo reflectivo y asfalto
	var mi := MeshInstance3D.new()
	var prism := BoxMesh.new()
	prism.size = Vector3(ancho_total, 0.09, 0.9)
	mi.mesh = prism
	
	var mat_resalto := StandardMaterial3D.new()
	mat_resalto.albedo_color = Color(0.92, 0.75, 0.12)
	mat_resalto.roughness = 0.55
	mi.material_override = mat_resalto
	sb.add_child(mi)
	
	# Colisión física real
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(ancho_total, 0.09, 0.9)
	col.shape = box_col
	sb.add_child(col)
	
	equipamiento_actualizado.emit()
	return true

# ── NUEVOS EQUIPAMIENTOS: CEBRAS, SEÑALES, SEMÁFOROS, PRESETS Y SERIALIZACIÓN ──

func aplicar_pasos_peatonales(segmentos: Array[RoadSegment]) -> void:
	_inicializar_contenedor_equipamiento()
	for seg in segmentos:
		if not is_instance_valid(seg): continue
		_limpiar_subtipo_en_segmento(seg, "PasoPeatonal")
		var curve := _obtener_curva_segmento(seg)
		if not curve: continue
		var clen := curve.get_baked_length()
		if clen < 6.0: continue
		var clave_seg := _obtener_clave_segmento(seg)
		var grupo := Node3D.new()
		grupo.name = "PasoPeatonal_%s" % clave_seg
		grupo.set_meta("subtipo_equip", "PasoPeatonal")
		grupo.set_meta("clave_seg", clave_seg)
		_contenedor_equipamiento.add_child(grupo)
		_registrar_nodo_segmento(seg, grupo)

		var ancho_via := _obtener_ancho_via(seg.start_point if seg.start_point else null)
		var mat_blanca := StandardMaterial3D.new()
		mat_blanca.albedo_color = Color(0.95, 0.96, 0.98)
		mat_blanca.roughness = 0.7

		for s_pos: float in [3.2, clen - 3.2]:
			var p_c := seg.to_global(curve.sample_baked(s_pos)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_pos))
			var p_sig := seg.to_global(curve.sample_baked(minf(s_pos + 0.8, clen))) if seg.is_inside_tree() else (seg.position + curve.sample_baked(minf(s_pos + 0.8, clen)))
			var fwd := (p_sig - p_c)
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
			var right_v := Vector3.UP.cross(fwd).normalized()
			var b := Basis(right_v, Vector3.UP, fwd).orthonormalized()

			var cont_cebra := Node3D.new()
			grupo.add_child(cont_cebra)
			cont_cebra.global_transform = Transform3D(b, p_c + Vector3(0, 0.03, 0))
			var num_franjas := maxi(4, int(floor(ancho_via / 1.1)))
			for i in range(num_franjas):
				var x_off := -ancho_via * 0.42 + (float(i) / maxf(1.0, float(num_franjas - 1))) * (ancho_via * 0.84)
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.45, 0.02, 2.6)
				mi.mesh = bm
				mi.position = Vector3(x_off, 0.0, 0.0)
				mi.material_override = mat_blanca
				cont_cebra.add_child(mi)
	equipamiento_actualizado.emit()

func _obtener_ancho_total_con_berma(rp: RoadPoint) -> float:
	var base_w := _obtener_ancho_via(rp)
	if is_instance_valid(rp):
		base_w += maxf(rp.shoulder_width_l, 0.0) + maxf(rp.shoulder_width_r, 0.0)
	return base_w

func aplicar_senales_transito(segmentos: Array[RoadSegment], lado: LadoEquipamiento, tipo_senal: int = 0) -> void:
	_inicializar_contenedor_equipamiento()
	for seg in segmentos:
		if not is_instance_valid(seg): continue
		_limpiar_subtipo_en_segmento(seg, "SenalTransito")
		var curve := _obtener_curva_segmento(seg)
		if not curve: continue
		var clen := curve.get_baked_length()
		if clen < 3.0: continue
		var clave_seg := _obtener_clave_segmento(seg)
		var grupo := Node3D.new()
		grupo.name = "SenalTransito_%s" % clave_seg
		grupo.set_meta("subtipo_equip", "SenalTransito")
		grupo.set_meta("clave_seg", clave_seg)
		_contenedor_equipamiento.add_child(grupo)
		_registrar_nodo_segmento(seg, grupo)

		var ancho_via := _obtener_ancho_total_con_berma(seg.start_point if seg.start_point else null)
		var mat_poste := StandardMaterial3D.new()
		mat_poste.albedo_color = Color(0.68, 0.70, 0.73)
		mat_poste.metallic = 0.6
		mat_poste.roughness = 0.45

		var mat_placa := StandardMaterial3D.new()
		match tipo_senal:
			0: mat_placa.albedo_color = Color(0.82, 0.14, 0.14)
			1, 5: mat_placa.albedo_color = Color(0.95, 0.95, 0.95)
			_: mat_placa.albedo_color = Color(0.95, 0.72, 0.10)
		mat_placa.roughness = 0.4

		var lados: Array[bool] = []
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA: lados.append(false)
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA: lados.append(true)

		var offsets_s: Array[float] = []
		if clen > 80.0:
			var s_it := 14.0
			while s_it < clen - 10.0:
				offsets_s.append(s_it)
				s_it += 75.0
		if offsets_s.is_empty():
			offsets_s.append(clen * 0.25)

		for es_izq in lados:
			for s_base in offsets_s:
				var s_pos := s_base if not es_izq else clampf(clen - s_base, 2.0, clen - 2.0)
				var p_c := seg.to_global(curve.sample_baked(s_pos)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_pos))
				var p_sig := seg.to_global(curve.sample_baked(minf(s_pos + 0.8, clen))) if seg.is_inside_tree() else (seg.position + curve.sample_baked(minf(s_pos + 0.8, clen)))
				var fwd := (p_sig - p_c)
				fwd.y = 0.0
				fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
				var lat := fwd.cross(Vector3.UP).normalized()
				var signo := -1.0 if es_izq else 1.0
				var pos_poste := p_c + lat * signo * (ancho_via * 0.5 + 1.15)
				if controlador_carreteras and controlador_carreteras.controlador_terreno:
					var h_terr: float = controlador_carreteras.controlador_terreno.obtener_altura(pos_poste)
					if absf(h_terr - p_c.y) < 2.8:
						pos_poste.y = h_terr

				var nodo_s := Node3D.new()
				grupo.add_child(nodo_s)
				var b := Basis(lat, Vector3.UP, fwd).orthonormalized()
				nodo_s.global_transform = Transform3D(b, pos_poste)
				if ancho_via > 14.0:
					nodo_s.scale = Vector3(1.18, 1.18, 1.18)

				const RUTAS_SENALES := [
					"res://modelos3d/mapa/senales/senal_pare.glb",
					"res://modelos3d/mapa/senales/senal_vel_60.glb",
					"res://modelos3d/mapa/senales/senal_curva.glb",
					"res://modelos3d/mapa/senales/senal_ceda.glb",
					"res://modelos3d/mapa/senales/senal_escolar.glb",
					"res://modelos3d/mapa/senales/senal_vel_80.glb"
				]
				var idx_senal := clampi(tipo_senal, 0, RUTAS_SENALES.size() - 1)
				var ruta_glb: String = RUTAS_SENALES[idx_senal]
				var glb_cargado := false
				if ResourceLoader.exists(ruta_glb):
					var esc := load(ruta_glb) as PackedScene
					if esc:
						var inst := esc.instantiate()
						if inst:
							inst.rotation_degrees.y = 180.0 if not es_izq else 0.0
							nodo_s.add_child(inst)
							glb_cargado = true
				if not glb_cargado:
					var mast := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					cyl.top_radius = 0.05
					cyl.bottom_radius = 0.06
					cyl.height = 2.6
					mast.mesh = cyl
					mast.position.y = 1.3
					mast.material_override = mat_poste
					nodo_s.add_child(mast)

					var placa := MeshInstance3D.new()
					var cyl_p := CylinderMesh.new()
					cyl_p.top_radius = 0.38
					cyl_p.bottom_radius = 0.38
					cyl_p.height = 0.06
					cyl_p.radial_segments = 8 if tipo_senal == 0 else (4 if tipo_senal == 2 else 20)
					placa.mesh = cyl_p
					placa.position = Vector3(0, 2.35, 0)
					placa.rotation_degrees = Vector3(90, 0, 0)
					placa.material_override = mat_placa
					nodo_s.add_child(placa)
	equipamiento_actualizado.emit()

func aplicar_ojos_de_gato(segmentos: Array[RoadSegment], lado: LadoEquipamiento) -> void:
	_inicializar_contenedor_equipamiento()
	var mat_ambar := StandardMaterial3D.new()
	mat_ambar.albedo_color = Color(1.0, 0.72, 0.12)
	mat_ambar.emission_enabled = true
	mat_ambar.emission = Color(1.0, 0.68, 0.10)
	mat_ambar.emission_energy_multiplier = 2.2
	mat_ambar.roughness = 0.25

	var mat_blanco := StandardMaterial3D.new()
	mat_blanco.albedo_color = Color(0.95, 0.97, 1.0)
	mat_blanco.emission_enabled = true
	mat_blanco.emission = Color(0.92, 0.96, 1.0)
	mat_blanco.emission_energy_multiplier = 1.8
	mat_blanco.roughness = 0.25

	var box_tacha := BoxMesh.new()
	box_tacha.size = Vector3(0.14, 0.04, 0.16)

	for seg in segmentos:
		if not is_instance_valid(seg): continue
		_limpiar_subtipo_en_segmento(seg, "OjosDeGato")
		var curve := _obtener_curva_segmento(seg)
		if not curve: continue
		var clen := curve.get_baked_length()
		if clen < 3.0: continue
		var clave_seg := _obtener_clave_segmento(seg)
		var grupo := Node3D.new()
		grupo.name = "OjosDeGato_%s" % clave_seg
		grupo.set_meta("subtipo_equip", "OjosDeGato")
		grupo.set_meta("clave_seg", clave_seg)
		_contenedor_equipamiento.add_child(grupo)
		_registrar_nodo_segmento(seg, grupo)

		var ancho_via := _obtener_ancho_via(seg.start_point if seg.start_point else null)
		var lados: Array[bool] = []
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.DERECHA: lados.append(false)
		if lado == LadoEquipamiento.AMBOS or lado == LadoEquipamiento.IZQUIERDA: lados.append(true)

		var paso := 6.0
		var s := 2.0
		while s < clen - 1.5:
			var p_c := seg.to_global(curve.sample_baked(s)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s))
			var p_sig := seg.to_global(curve.sample_baked(minf(s + 0.6, clen))) if seg.is_inside_tree() else (seg.position + curve.sample_baked(minf(s + 0.6, clen)))
			var fwd := (p_sig - p_c)
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
			var lat := fwd.cross(Vector3.UP).normalized()
			for es_izq in lados:
				var signo := -1.0 if es_izq else 1.0
				var pos_t := p_c + lat * signo * (ancho_via * 0.46) + Vector3(0, 0.025, 0)
				var mi := MeshInstance3D.new()
				mi.mesh = box_tacha
				mi.material_override = mat_blanco if not es_izq else mat_ambar
				grupo.add_child(mi)
				mi.global_transform = Transform3D(Basis(lat, Vector3.UP, fwd).orthonormalized(), pos_t)
			s += paso
	equipamiento_actualizado.emit()

func limpiar_equipamiento_segmentos(segmentos: Array[RoadSegment]) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg): continue
		for st in ["Acera", "Berma", "Barrera", "PosteLuz", "Arboles", "ReductorVelocidad", "PasoPeatonal", "SenalTransito", "Semaforo", "OjosDeGato"]:
			_limpiar_subtipo_en_segmento(seg, st)
		var clave := _obtener_clave_segmento(seg)
		if _registro_equipamiento_serializable.has(clave):
			_registro_equipamiento_serializable.erase(clave)
	equipamiento_actualizado.emit()

func obtener_datos_tramo_seleccionado() -> Dictionary:
	if tramo_segmentos.is_empty():
		return {"paso": 0}
	var dist := 0.0
	for s in tramo_segmentos:
		if is_instance_valid(s):
			var c := _obtener_curva_segmento(s)
			if c:
				dist += c.get_baked_length()
	return {
		"paso": 2,
		"inicio": punto_inicio.name if is_instance_valid(punto_inicio) else "",
		"fin": punto_fin.name if is_instance_valid(punto_fin) else "",
		"num_puntos": maxi(tramo_puntos.size(), tramo_segmentos.size() + 1),
		"distancia": dist
	}

func seleccionar_segmentos_directo(segs: Array[RoadSegment]) -> void:
	if segs.is_empty() or not is_instance_valid(segs[0]):
		return
	var seg0 := segs[0]
	punto_inicio = seg0.start_point
	punto_fin = seg0.end_point
	tramo_puntos.clear()
	if is_instance_valid(punto_inicio):
		tramo_puntos.append(punto_inicio)
	if is_instance_valid(punto_fin) and punto_fin != punto_inicio:
		tramo_puntos.append(punto_fin)
	tramo_segmentos = segs.duplicate()
	if _marcador_punto_a and is_instance_valid(punto_inicio):
		_marcador_punto_a.global_position = punto_inicio.global_position + Vector3(0, 0.2, 0)
		_marcador_punto_a.visible = true
	if _marcador_punto_b and is_instance_valid(punto_fin):
		_marcador_punto_b.global_position = punto_fin.global_position + Vector3(0, 0.2, 0)
		_marcador_punto_b.visible = true
	_actualizar_cinta_resaltado()
	tramo_seleccionado_cambiado.emit(true, obtener_datos_tramo_seleccionado())

func aplicar_semaforos(segmentos: Array[RoadSegment]) -> void:
	_inicializar_contenedor_equipamiento()
	for seg in segmentos:
		if not is_instance_valid(seg): continue
		_limpiar_subtipo_en_segmento(seg, "Semaforo")
		var curve := _obtener_curva_segmento(seg)
		if not curve: continue
		var clen := curve.get_baked_length()
		if clen < 6.0: continue
		var clave_seg := _obtener_clave_segmento(seg)
		var grupo := Node3D.new()
		grupo.name = "Semaforo_%s" % clave_seg
		grupo.set_meta("subtipo_equip", "Semaforo")
		grupo.set_meta("clave_seg", clave_seg)
		_contenedor_equipamiento.add_child(grupo)
		_registrar_nodo_segmento(seg, grupo)

		var ancho_via := _obtener_ancho_via(seg.start_point if seg.start_point else null)
		var mat_negro := StandardMaterial3D.new()
		mat_negro.albedo_color = Color(0.14, 0.15, 0.17)
		mat_negro.metallic = 0.5
		mat_negro.roughness = 0.45

		var colores_luz := [Color(0.95, 0.18, 0.15), Color(0.98, 0.72, 0.12), Color(0.18, 0.88, 0.35)]
		for s_pos: float in [2.0, clen - 2.0]:
			var es_fin: bool = (s_pos > clen * 0.5)
			var p_c := seg.to_global(curve.sample_baked(s_pos)) if seg.is_inside_tree() else (seg.position + curve.sample_baked(s_pos))
			var p_sig := seg.to_global(curve.sample_baked(minf(s_pos + 0.8, clen))) if seg.is_inside_tree() else (seg.position + curve.sample_baked(minf(s_pos + 0.8, clen)))
			var fwd := (p_sig - p_c)
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
			var lat := fwd.cross(Vector3.UP).normalized()
			var signo := 1.0 if es_fin else -1.0
			var pos_base := p_c + lat * signo * (ancho_via * 0.5 + 1.0)

			var sem := Node3D.new()
			grupo.add_child(sem)
			var b := Basis(lat * signo, Vector3.UP, fwd * signo).orthonormalized()
			sem.global_transform = Transform3D(b, pos_base)

			var poste := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.09
			cyl.bottom_radius = 0.12
			cyl.height = 5.2
			poste.mesh = cyl
			poste.position.y = 2.6
			poste.material_override = mat_negro
			sem.add_child(poste)

			var brazo := MeshInstance3D.new()
			var box_b := BoxMesh.new()
			box_b.size = Vector3(2.8, 0.14, 0.14)
			brazo.mesh = box_b
			brazo.position = Vector3(-1.3, 5.0, 0)
			brazo.material_override = mat_negro
			sem.add_child(brazo)

			var caja := MeshInstance3D.new()
			var box_c := BoxMesh.new()
			box_c.size = Vector3(0.42, 1.1, 0.36)
			caja.mesh = box_c
			caja.position = Vector3(-2.3, 4.7, 0)
			caja.material_override = mat_negro
			sem.add_child(caja)

			for li in range(3):
				var foco := MeshInstance3D.new()
				var sph := SphereMesh.new()
				sph.radius = 0.11
				sph.height = 0.22
				foco.mesh = sph
				foco.position = Vector3(-2.3, 5.05 - li * 0.35, -0.16)
				var mat_l := StandardMaterial3D.new()
				mat_l.albedo_color = colores_luz[li]
				mat_l.emission_enabled = true
				mat_l.emission = colores_luz[li]
				mat_l.emission_energy_multiplier = 2.2 if li == 2 else 0.45
				foco.material_override = mat_l
				sem.add_child(foco)
	equipamiento_actualizado.emit()

func aplicar_preset_via(id_preset: String) -> Dictionary:
	_inicializar_contenedor_equipamiento()
	_actualizar_segmentos_del_tramo()
	if tramo_segmentos.is_empty():
		return {"exito": false, "mensaje": "Primero selecciona el tramo (Punto A y Punto B)"}
	match id_preset:
		"urbana":
			tipo_acera_actual = TipoAcera.CONCRETO
			aplicar_aceras(tramo_segmentos, LadoEquipamiento.AMBOS, 1.8)
			aplicar_postes_luz(tramo_segmentos, LadoEquipamiento.AMBOS, 25.0)
			aplicar_arboles(tramo_segmentos, LadoEquipamiento.AMBOS, 20.0)
			aplicar_pasos_peatonales(tramo_segmentos)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.ACERA, LadoEquipamiento.AMBOS, 1.8)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.POSTE_LUZ, LadoEquipamiento.AMBOS, 25.0)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.ARBOLES, LadoEquipamiento.AMBOS, 20.0)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.PASO_PEATONAL, LadoEquipamiento.AMBOS, 1.8)
			return {"exito": true, "mensaje": "¡Preset Vía Urbana aplicado!"}
		"carretera":
			aplicar_bermas(tramo_puntos, tramo_segmentos, LadoEquipamiento.AMBOS, 1.8)
			aplicar_barreras(tramo_segmentos, LadoEquipamiento.AMBOS)
			aplicar_postes_luz(tramo_segmentos, LadoEquipamiento.DERECHA, 35.0)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.BERMA, LadoEquipamiento.AMBOS, 1.8)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.BARRERA, LadoEquipamiento.AMBOS, 1.8)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.POSTE_LUZ, LadoEquipamiento.DERECHA, 35.0)
			return {"exito": true, "mensaje": "¡Preset Carretera aplicado!"}
		"montana":
			aplicar_barreras(tramo_segmentos, LadoEquipamiento.AMBOS)
			aplicar_senales_transito(tramo_segmentos, LadoEquipamiento.DERECHA, 2)
			aplicar_puentes_viaductos(tramo_segmentos)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.BARRERA, LadoEquipamiento.AMBOS, 1.8)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.SENAL_TRANSITO, LadoEquipamiento.DERECHA, 2.0)
			_registrar_equipamiento_serializable(tramo_segmentos, TipoEquipamiento.PUENTE_VIADUCTO, LadoEquipamiento.AMBOS, 1.8)
			return {"exito": true, "mensaje": "¡Preset Ruta de Montaña aplicado!"}
	return {"exito": false, "mensaje": "Preset desconocido"}

func _registrar_equipamiento_serializable(segmentos: Array[RoadSegment], tipo: TipoEquipamiento, lado: LadoEquipamiento, valor: float) -> void:
	for seg in segmentos:
		if not is_instance_valid(seg) or not is_instance_valid(seg.start_point) or not is_instance_valid(seg.end_point):
			continue
		var clave := "%s->%s" % [seg.start_point.name, seg.end_point.name]
		if not _registro_equipamiento_serializable.has(clave):
			_registro_equipamiento_serializable[clave] = {
				"inicio": seg.start_point.name,
				"fin": seg.end_point.name,
				"items": []
			}
		var items: Array = _registro_equipamiento_serializable[clave]["items"]
		var filtrado: Array = []
		for it in items:
			if int(it.get("tipo", -1)) != int(tipo):
				filtrado.append(it)
		filtrado.append({
			"tipo": int(tipo),
			"lado": int(lado),
			"valor": valor,
			"tipo_acera": int(tipo_acera_actual)
		})
		_registro_equipamiento_serializable[clave]["items"] = filtrado

func serializar_equipamiento() -> Array:
	return _registro_equipamiento_serializable.values().duplicate(true)

func deserializar_equipamiento(datos: Array) -> void:
	_registro_equipamiento_serializable.clear()
	if not road_container or not is_instance_valid(road_container) or datos.is_empty():
		return
	for entry in datos:
		if not (entry is Dictionary): continue
		var rp_a := road_container.get_node_or_null(str(entry.get("inicio", ""))) as RoadPoint
		var rp_b := road_container.get_node_or_null(str(entry.get("fin", ""))) as RoadPoint
		if not rp_a or not rp_b: continue
		var seg := _obtener_segmento_entre(rp_a, rp_b)
		if not seg: continue
		var segs: Array[RoadSegment] = [seg]
		for it in entry.get("items", []):
			if not (it is Dictionary): continue
			var tipo := int(it.get("tipo", 0)) as TipoEquipamiento
			var lado := int(it.get("lado", 0)) as LadoEquipamiento
			var val := float(it.get("valor", 1.8))
			tipo_acera_actual = int(it.get("tipo_acera", 0)) as TipoAcera
			match tipo:
				TipoEquipamiento.ACERA: aplicar_aceras(segs, lado, val)
				TipoEquipamiento.BERMA: aplicar_bermas([rp_a, rp_b], segs, lado, val)
				TipoEquipamiento.BARRERA: aplicar_barreras(segs, lado)
				TipoEquipamiento.POSTE_LUZ: aplicar_postes_luz(segs, lado, val)
				TipoEquipamiento.ARBOLES: aplicar_arboles(segs, lado, val)
				TipoEquipamiento.REDUCTOR_VELOCIDAD: aplicar_reductores_velocidad(segs)
				TipoEquipamiento.PUENTE_VIADUCTO: aplicar_puentes_viaductos(segs)
				TipoEquipamiento.TUNEL_MONTANA: aplicar_tuneles(segs)
				TipoEquipamiento.PASO_PEATONAL: aplicar_pasos_peatonales(segs)
				TipoEquipamiento.SENAL_TRANSITO: aplicar_senales_transito(segs, lado, int(val))
				TipoEquipamiento.SEMAFORO: aplicar_semaforos(segs)
				TipoEquipamiento.OJOS_DE_GATO: aplicar_ojos_de_gato(segs, lado)
			_registrar_equipamiento_serializable(segs, tipo, lado, val)
