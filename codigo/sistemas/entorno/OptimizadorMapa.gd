# OptimizadorMapa.gd
# ═══════════════════════════════════════════════════════════════════════════════
# Optimizador Ligero y Dinámico de Mapa basado en Occluder 3D y Rangos Nativos
# Desarrollado para "Nuestra Tierra 2.0"
#
# Arquitectura:
#   1. Aprovecha el OccluderInstance3D nativo de Godot 4 para culling por oclusión en C++.
#   2. Protege carreteras, asfalto y terreno base (ignore_occlusion_culling = true)
#      evitando parpadeos o huecos bajo las ruedas.
#   3. Asigna visibility_range_end nativo en props y vegetación para culling por
#      distancia sin costo de CPU en GDScript (sin bucles _process).
#   4. Optimiza el pase de sombras (Shadow Pass) apagando sombras en objetos menores.
# ═══════════════════════════════════════════════════════════════════════════════
@tool
class_name OptimizadorMapa
extends Node3D

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────
@export_group("⚡ Estado")
## Activa o desactiva el optimizador al cargar.
@export var activo: bool = true

@export_group("👁️ Occluder 3D")
## Ruta al nodo OccluderInstance3D (si se deja vacío, se busca automáticamente).
@export var occluder_path: NodePath = NodePath("")
## Si está activo, protege carreteras, suelo y terreno para que nunca sean ocluidos por error.
@export var proteger_suelo_y_vias: bool = true

@export_group("📏 Rangos de Visibilidad Nativos (Culling por Distancia)")
## Si está activo, configura visibility_range_end en props y vegetación.
@export var aplicar_visibility_ranges: bool = true
## Distancia máxima para árboles y vegetación (metros).
@export var distancia_arboles: float = 220.0
## Distancia máxima para postes, señales, vallas y faroles (metros).
@export var distancia_props_medianos: float = 130.0
## Distancia máxima para cajas, basura, conos y detalles pequeños (metros).
@export var distancia_props_pequenos: float = 65.0

@export_group("☀️ Optimización de Sombras")
## Si está activo, apaga la proyección de sombras en props pequeños y vegetación baja.
@export var optimizar_sombras: bool = true

@export_group("🛠️ Depuración")
## Muestra el resumen de mallas procesadas y estado del Occluder en la consola.
@export var modo_debug: bool = true


# ─────────────────────────────────────────────────────────────────────────────
# CICLO DE VIDA
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# En el editor de Godot no aplicamos modificaciones destructivas
	if Engine.is_editor_hint():
		return

	# No necesitamos procesamiento por cuadro; la GPU y el motor C++ hacen todo
	set_process(false)
	set_physics_process(false)

	if not activo:
		return

	# Ejecutar tras cargar la escena completamente
	call_deferred("_aplicar_optimizacion")


# ─────────────────────────────────────────────────────────────────────────────
# OPTIMIZACIÓN PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────
func _aplicar_optimizacion() -> void:
	if not is_inside_tree():
		return

	var raiz_mapa: Node = _obtener_nodo_mapa()
	if not raiz_mapa:
		if modo_debug:
			push_warning("[OptimizadorMapa] No se encontró el nodo del mapa para optimizar.")
		return

	# 1. Verificar y validar OccluderInstance3D
	var occluder_inst = _obtener_occluder(raiz_mapa)
	var occluder_valido: bool = false
	if is_instance_valid(occluder_inst):
		occluder_inst.visible = true
		if occluder_inst.occluder != null:
			occluder_valido = true
			if modo_debug:
				print("[OptimizadorMapa] ✅ OccluderInstance3D activo y funcionando correctamente.")
		else:
			push_warning("[OptimizadorMapa] OccluderInstance3D encontrado pero no tiene recurso 'occluder' asignado.")
	else:
		if modo_debug:
			print("[OptimizadorMapa] ℹ️ No se detectó OccluderInstance3D en la jerarquía del mapa.")

	# 2. Recolectar todas las instancias geométricas
	var mallas: Array[GeometryInstance3D] = []
	_recolectar_mallas(raiz_mapa, mallas)

	# 3. Clasificar y optimizar cada malla
	var contador_protegidas: int = 0
	var contador_arboles: int = 0
	var contador_medianos: int = 0
	var contador_pequenos: int = 0
	var contador_estructuras: int = 0

	for malla in mallas:
		# Asegurar visibilidad inicial y modo de proceso activo
		malla.visible = true

		var nombre: String = malla.name.to_lower()
		var padre_nombre: String = malla.get_parent().name.to_lower() if malla.get_parent() else ""

		# A. Carreteras, suelo, terreno y montañas (Protección de Oclusión)
		if _es_suelo_o_carretera(nombre, padre_nombre):
			if proteger_suelo_y_vias:
				malla.ignore_occlusion_culling = true
				malla.extra_cull_margin = 2.0
			malla.visibility_range_end = 0.0
			contador_protegidas += 1
			continue

		# B. Árboles y Vegetación
		if _es_vegetacion(nombre, padre_nombre):
			if aplicar_visibility_ranges:
				malla.visibility_range_end = distancia_arboles
			if optimizar_sombras:
				# Si son mallas secundarias o follaje, apagar sombra directa
				if nombre.contains("hoja") or nombre.contains("leaf") or nombre.contains("cesped") or nombre.contains("pasto"):
					malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			contador_arboles += 1
			continue

		# C. Props Pequeños
		if _es_prop_pequeno(nombre, padre_nombre):
			if aplicar_visibility_ranges:
				malla.visibility_range_end = distancia_props_pequenos
			if optimizar_sombras:
				malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			contador_pequenos += 1
			continue

		# D. Props Medianos
		if _es_prop_mediano(nombre, padre_nombre):
			if aplicar_visibility_ranges:
				malla.visibility_range_end = distancia_props_medianos
			if optimizar_sombras:
				malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			contador_medianos += 1
			continue

		# E. Edificios, Casas y Estructuras (Participan libremente en el Occluder)
		malla.ignore_occlusion_culling = false
		malla.visibility_range_end = 0.0
		contador_estructuras += 1

	# 4. Evitar traspaso en mallas de vías/suelo de grosor cero habilitando backface_collision
	var contador_colisiones_suelo: int = _asegurar_colision_doble_cara_suelo(raiz_mapa)

	if modo_debug:
		print("═══════════════════════════════════════════════════════════════")
		print("[OptimizadorMapa] Optimización aplicada con éxito:")
		print("  -> Occluder activo: %s" % ("SÍ" if occluder_valido else "NO"))
		print("  -> Vías y terrenos protegidos: %d" % contador_protegidas)
		print("  -> Colisiones de suelo reforzadas (doble cara): %d" % contador_colisiones_suelo)
		print("  -> Árboles y vegetación con LOD (%0.0fm): %d" % [distancia_arboles, contador_arboles])
		print("  -> Props medianos con LOD (%0.0fm): %d" % [distancia_props_medianos, contador_medianos])
		print("  -> Props pequeños con LOD (%0.0fm): %d" % [distancia_props_pequenos, contador_pequenos])
		print("  -> Estructuras / Casas en oclusión: %d" % contador_estructuras)
		print("  -> Total mallas optimizadas: %d" % mallas.size())
		print("═══════════════════════════════════════════════════════════════")


# ─────────────────────────────────────────────────────────────────────────────
# IDENTIFICACIÓN Y FILTRADO DE MALLAS
# ─────────────────────────────────────────────────────────────────────────────
func _es_suelo_o_carretera(n: String, p: String) -> bool:
	return (
		n.contains("carretera") or p.contains("carretera") or
		n.contains("trocha") or p.contains("trocha") or
		n.contains("acera") or p.contains("acera") or
		n.contains("asfalto") or p.contains("asfalto") or
		n.contains("suelo") or p.contains("suelo") or
		n.contains("piso") or p.contains("piso") or
		n.contains("terreno") or p.contains("terreno") or
		n.contains("montana") or n.contains("montaña") or p.contains("montana") or
		n.contains("cliff") or p.contains("cliff") or
		n.contains("agua") or p.contains("agua") or
		n.contains("rio") or p.contains("rio")
	)


func _es_colision_doble_cara(n: String, p: String) -> bool:
	return _es_suelo_o_carretera(n, p) or n.contains("grid") or p.contains("grid") or n.contains("edificio_base") or p.contains("edificio_base")


func _asegurar_colision_doble_cara_suelo(raiz: Node) -> int:
	if not raiz:
		return 0
	var count: int = 0
	var pila: Array[Node] = [raiz]
	while not pila.is_empty():
		var nodo: Node = pila.pop_back()
		for hijo in nodo.get_children():
			pila.append(hijo)
		if nodo is CollisionShape3D:
			var cs: CollisionShape3D = nodo as CollisionShape3D
			if cs.shape is ConcavePolygonShape3D:
				var conc: ConcavePolygonShape3D = cs.shape as ConcavePolygonShape3D
				if not conc.backface_collision:
					var padre: Node = cs.get_parent()
					var abuelo: Node = padre.get_parent() if padre else null
					var nom_p: String = padre.name.to_lower() if padre else ""
					var nom_a: String = abuelo.name.to_lower() if abuelo else ""
					if _es_colision_doble_cara(nom_p, nom_a):
						conc.backface_collision = true
						count += 1
	return count


func _es_vegetacion(n: String, p: String) -> bool:
	return (
		n.contains("arbol") or p.contains("arbol") or
		n.contains("tree") or p.contains("tree") or
		n.contains("palma") or p.contains("palma") or
		n.contains("bush") or p.contains("bush") or
		n.contains("arbusto") or p.contains("arbusto") or
		n.contains("cesped") or p.contains("cesped") or
		n.contains("pasto") or p.contains("pasto") or
		n.contains("hierba") or p.contains("hierba") or
		n.contains("leaf") or n.contains("hoja") or
		n.contains("planta") or p.contains("planta")
	)


func _es_prop_pequeno(n: String, p: String) -> bool:
	return (
		n.contains("basura") or p.contains("basura") or
		n.contains("trash") or p.contains("trash") or
		n.contains("cono") or p.contains("cono") or
		n.contains("caja") or p.contains("caja") or
		n.contains("barril") or p.contains("barril") or
		n.contains("escombro") or p.contains("escombro") or
		n.contains("debris") or p.contains("debris") or
		n.contains("bolsa") or p.contains("bolsa") or
		n.contains("piedra") or p.contains("piedra")
	)


func _es_prop_mediano(n: String, p: String) -> bool:
	return (
		n.contains("poste") or p.contains("poste") or
		n.contains("pole") or p.contains("pole") or
		n.contains("valla") or p.contains("valla") or
		n.contains("fence") or p.contains("fence") or
		n.contains("señal") or n.contains("senal") or p.contains("señal") or p.contains("senal") or
		n.contains("sign") or p.contains("sign") or
		n.contains("semaforo") or p.contains("semaforo") or
		n.contains("lampara") or p.contains("lampara") or
		n.contains("farol") or p.contains("farol") or
		n.contains("banca") or p.contains("banca") or
		n.contains("hidrante") or p.contains("hidrante")
	)


# ─────────────────────────────────────────────────────────────────────────────
# MÉTODOS AUXILIARES
# ─────────────────────────────────────────────────────────────────────────────
func _obtener_nodo_mapa() -> Node:
	# Si este script está en el mapa mismo o tiene N3D_Mapa como hijo
	if get_node_or_null("N3D_Mapa") != null or name.to_lower().contains("mapa"):
		return self

	# Si es un nodo auxiliar independiente, buscar en los hermanos
	if get_parent():
		var hermano = get_parent().get_node_or_null("mapa")
		if hermano:
			return hermano

	return self


func _obtener_occluder(raiz: Node) -> OccluderInstance3D:
	if not occluder_path.is_empty():
		var nodo = get_node_or_null(occluder_path)
		if nodo is OccluderInstance3D:
			return nodo as OccluderInstance3D

	# Buscar en los hijos directos de la raíz
	for hijo in raiz.get_children():
		if hijo is OccluderInstance3D:
			return hijo as OccluderInstance3D

	# Búsqueda recursiva
	return _buscar_occluder_recursivo(raiz)


func _buscar_occluder_recursivo(nodo: Node) -> OccluderInstance3D:
	for hijo in nodo.get_children():
		if hijo is OccluderInstance3D:
			return hijo as OccluderInstance3D
		var encontrado = _buscar_occluder_recursivo(hijo)
		if encontrado:
			return encontrado
	return null


func _recolectar_mallas(nodo: Node, lista: Array[GeometryInstance3D]) -> void:
	if not nodo:
		return

	if nodo is GeometryInstance3D and not (nodo is OccluderInstance3D):
		lista.append(nodo as GeometryInstance3D)

	for hijo in nodo.get_children():
		_recolectar_mallas(hijo, lista)
