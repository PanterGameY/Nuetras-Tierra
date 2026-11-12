@tool
extends Node3D
class_name BibliotecaPuntosCarga

## BibliotecaPuntosCarga.gd
##
## Contenedor y Gestor de la Librería de Puntos de Carga y Descarga.
## Permite organizar, listar y reordenar puntos de carga/descarga en la escena,
## facilitando la creación de rutas, misiones de transporte y navegación por GPS.

@export_group("Librería de Puntos")
## Lista ordenada de los puntos de carga y descarga administrados por esta librería
@export var lista_puntos: Array[PuntoCargaDescarga] = []

@export_group("Herramientas del Editor")
## Activa esta casilla en el Inspector para buscar automáticamente todos los sub-nodos PuntoCargaDescarga
@export var auto_detectar_hijos: bool = false:
	set(val):
		if val:
			auto_detectar_hijos = false
			sincronizar_puntos_hijos()

## Activa esta casilla en el Inspector para reasignar el índice numérico (0, 1, 2...) según el orden de la lista
@export var reordenar_indices: bool = false:
	set(val):
		if val:
			reordenar_indices = false
			reordenar_indices_lista()

## Carga y aplica la configuración de puntos desde el archivo JSON
@export var cargar_desde_json: bool = false:
	set(val):
		if val:
			cargar_desde_json = false
			aplicar_configuracion_desde_json()

## Guarda la configuración actual de los puntos hacia el archivo JSON
@export var guardar_hacia_json: bool = false:
	set(val):
		if val:
			guardar_hacia_json = false
			guardar_puntos_actuales_en_json(Engine.is_editor_hint())

signal puntos_actualizados()

func _ready() -> void:
	if Engine.is_editor_hint():
		sincronizar_puntos_hijos()
	else:
		add_to_group("biblioteca_puntos_carga")
		# Limpiar referencias nulas por si algún nodo fue eliminado
		_limpiar_nulos()
		# Si hay configuración en JSON, sincronizar datos automáticamente en runtime
		aplicar_configuracion_desde_json()

## Busca todos los nodos PuntoCargaDescarga que sean hijos directos o descendientes
func sincronizar_puntos_hijos() -> void:
	_limpiar_nulos()
	var encontrados: Array[PuntoCargaDescarga] = []
	_buscar_puntos_recursivo(self, encontrados)
	
	# Preservar orden existente si ya estaban en la lista, agregar nuevos al final
	for p in encontrados:
		if not lista_puntos.has(p):
			lista_puntos.append(p)
			
	# Remover los que ya no existen como hijos
	var lista_filtrada: Array[PuntoCargaDescarga] = []
	for p in lista_puntos:
		if is_instance_valid(p) and encontrados.has(p):
			lista_filtrada.append(p)
			
	lista_puntos = lista_filtrada
	reordenar_indices_lista()
	print("[BibliotecaPuntosCarga] Sincronización completada. Puntos encontrados: ", lista_puntos.size())

func _buscar_puntos_recursivo(nodo: Node, resultado: Array[PuntoCargaDescarga]) -> void:
	for child in nodo.get_children():
		if child is PuntoCargaDescarga:
			resultado.append(child)
		_buscar_puntos_recursivo(child, resultado)

## Actualiza la variable 'orden_indice' de cada punto según la secuencia actual de la lista
func reordenar_indices_lista() -> void:
	_limpiar_nulos()
	for i in range(lista_puntos.size()):
		if is_instance_valid(lista_puntos[i]):
			lista_puntos[i].orden_indice = i

## Mueve un punto de posición dentro de la lista (ej: de posición 3 a posición 1)
func mover_punto(de_indice: int, a_indice: int) -> void:
	_limpiar_nulos()
	if de_indice < 0 or de_indice >= lista_puntos.size():
		return
	if a_indice < 0 or a_indice >= lista_puntos.size():
		return
		
	var item = lista_puntos[de_indice]
	lista_puntos.remove_at(de_indice)
	lista_puntos.insert(a_indice, item)
	reordenar_indices_lista()

# ── Métodos de Consulta y Búsqueda (API) ──

## Devuelve todos los puntos registrados en la librería
func obtener_todos() -> Array[PuntoCargaDescarga]:
	_limpiar_nulos()
	return lista_puntos

## Devuelve solo los puntos que admiten Carga (CARGA o AMBOS)
func obtener_puntos_carga() -> Array[PuntoCargaDescarga]:
	_limpiar_nulos()
	var res: Array[PuntoCargaDescarga] = []
	for p in lista_puntos:
		if p.es_punto_de_carga():
			res.append(p)
	return res

## Devuelve solo los puntos que admiten Descarga (DESCARGA o AMBOS)
func obtener_puntos_descarga() -> Array[PuntoCargaDescarga]:
	_limpiar_nulos()
	var res: Array[PuntoCargaDescarga] = []
	for p in lista_puntos:
		if p.es_punto_de_descarga():
			res.append(p)
	return res

## Busca un punto por su identificador único (id_punto)
func obtener_por_id(id_buscado: String) -> PuntoCargaDescarga:
	_limpiar_nulos()
	for p in lista_puntos:
		if p.id_punto == id_buscado:
			return p
	return null

## Busca el punto más cercano a una posición Vector3 global en el mundo 3D
## solo_tipo: -1 para cualquier tipo, o un valor de PuntoCargaDescarga.TipoPunto
func obtener_mas_cercano(pos_global: Vector3, solo_tipo: int = -1) -> PuntoCargaDescarga:
	_limpiar_nulos()
	var candidato: PuntoCargaDescarga = null
	var min_dist: float = 999999.0
	
	for p in lista_puntos:
		if solo_tipo != -1:
			if solo_tipo == PuntoCargaDescarga.TipoPunto.CARGA and not p.es_punto_de_carga():
				continue
			if solo_tipo == PuntoCargaDescarga.TipoPunto.DESCARGA and not p.es_punto_de_descarga():
				continue
				
		var dist = p.global_position.distance_to(pos_global)
		if dist < min_dist:
			min_dist = dist
			candidato = p
			
	return candidato

func _limpiar_nulos() -> void:
	var limpia: Array[PuntoCargaDescarga] = []
	for p in lista_puntos:
		if is_instance_valid(p):
			limpia.append(p)
	lista_puntos = limpia

## Sincroniza la lista de nodos con la configuración JSON
func aplicar_configuracion_desde_json() -> void:
	_limpiar_nulos()
	var datos = GestorPuntosCarga.cargar_datos()
	var puntos_json: Array = datos.get("puntos", [])
	if puntos_json.is_empty():
		return

	# Mapa indexado por id_punto para actualización rápida
	var mapa_existentes: Dictionary = {}
	for p in lista_puntos:
		if is_instance_valid(p):
			mapa_existentes[p.id_punto] = p

	for data_p in puntos_json:
		var id_p = str(data_p.get("id_punto", ""))
		if mapa_existentes.has(id_p):
			GestorPuntosCarga.aplicar_datos_a_nodo(mapa_existentes[id_p], data_p)
		else:
			# Si no existe, crear el nodo en la escena si estamos en juego o editor
			var nuevo_nodo = PuntoCargaDescarga.new()
			nuevo_nodo.name = id_p
			add_child(nuevo_nodo)
			if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
				nuevo_nodo.owner = get_tree().edited_scene_root
			GestorPuntosCarga.aplicar_datos_a_nodo(nuevo_nodo, data_p)
			lista_puntos.append(nuevo_nodo)

	reordenar_indices_lista()
	puntos_actualizados.emit()
	print("[BibliotecaPuntosCarga] Sincronizados %d puntos desde JSON" % lista_puntos.size())

## Guarda la configuración actual de todos los nodos hacia el archivo JSON
func guardar_puntos_actuales_en_json(guardar_en_res: bool = false) -> bool:
	_limpiar_nulos()
	var datos = GestorPuntosCarga.cargar_datos()
	var lista_dict: Array = []
	for p in lista_puntos:
		if is_instance_valid(p):
			lista_dict.append(GestorPuntosCarga.extraer_datos_de_nodo(p))
	datos["puntos"] = lista_dict
	var exito = GestorPuntosCarga.guardar_datos(datos, guardar_en_res)
	if exito:
		print("[BibliotecaPuntosCarga] Puntos guardados en JSON exitosamente (%d puntos)" % lista_dict.size())
	return exito

## Instancia y abre la interfaz gráfica de configuración dinámica en pantalla
func abrir_configurador_ui() -> void:
	var instancia = ConfiguradorPuntosCarga.new()
	if instancia:
		var canvas = CanvasLayer.new()
		canvas.layer = 100
		canvas.add_child(instancia)
		get_tree().root.add_child(canvas)
		instancia.configuracion_guardada.connect(aplicar_configuracion_desde_json)
		instancia.configuracion_cerrada.connect(canvas.queue_free)
