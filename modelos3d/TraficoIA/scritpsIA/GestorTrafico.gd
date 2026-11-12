extends Node3D
class_name GestorTrafico

## ══════════════════════════════════════════════════════════════════════════════
##  GestorTrafico.gd
##  Gestor de Tráfico Inteligente con Object Pooling y Soporte de Red Vial.
##  Detecta automáticamente:
##    • TrafficNetworkManager3D y sus carriles TrafficLane3D.
##    • Nodos en grupo "traffic_lanes" y cualquier Path3D en la escena del mapa.
##    • Tránsito entre carriles interconectados mediante next_lanes.
##    • Auto-detección del vehículo del jugador y generación en burbuja (200m).
## ══════════════════════════════════════════════════════════════════════════════

@export_group("Referencias de Vía y Jugador")
@export_node_path("Path3D") var path: NodePath
@export_node_path("Node3D") var target_node: NodePath            # auto del jugador (auto-detectado si está vacío)
@export_node_path("Node3D") var network_manager_path: NodePath   # opcional TrafficNetworkManager3D
@export_node_path("Semaforo") var semaforo: NodePath             # opcional
@export var auto_detectar_caminos: bool = true                   # busca TrafficNetworkManager3D y TrafficLane3D del mapa

@export_group("Flota de Vehículos")
@export var escena_vehiculo: PackedScene                         # vehículo por defecto
@export var escenas_vehiculo: Array[PackedScene] = []            # tipos de vehículos (Cascadia, T680, Furgon, Transit...)
@export var pesos_vehiculo: Array[float] = []                    # frecuencias relativas de cada tipo

@export_group("Pool y Burbuja de Tráfico")
@export var pista_en_bucle: bool = false                         # true para circuito cerrado, false para red abierta
@export var tamano_pool: int = 16
@export var distancia_spawn: float = 140.0                       # m, alcance máximo al que aparecen autos
@export var distancia_spawn_minima: float = 40.0                 # m, distancia mínima de aparición
@export var distancia_despawn: float = 160.0                     # m por detrás del jugador
@export var distancia_despawn_adelante: float = 200.0            # m por delante del jugador
@export var distancia_despawn_maxima: float = 400.0              # m, reciclaje forzoso
@export var aparecer_fuera_de_camara: bool = true
@export var reciclar_solo_fuera_de_camara: bool = true
@export var separacion_spawn: float = 28.0                       # m mínimos entre vehículos en el mismo carril
@export var intervalo_revision_spawn: float = 0.5                # segundos entre chequeos de spawn

@export_group("Carriles y Doble Sentido")
@export_range(0.0, 1.0) var proporcion_sentido_contrario: float = 0.35
@export var desfase_carril: float = 2.2                          # m del centro al carril (si la vía es bidireccional)
@export var ancho_deteccion_jugador: float = 2.5
@export var semi_largo_jugador: float = 3.0

@export_group("Semáforo y Variedad")
@export var zona_frenado_semaforo: float = 25.0
@export_range(0.0, 0.4) var variacion_velocidad: float = 0.15
@export var mostrar_velocidades: bool = false

# ── Red vial y referencias internas ──────────────────────────────────────────
var _caminos: Array[Path3D] = []
var _network_manager: Node = null
var _objetivo: Node3D = null
var _semaforo: Semaforo = null

var _progreso_jugador: float = 0.0
var _lateral_jugador: float = 0.0
var _sentido_jugador: int = 1
var _jugador_valido: bool = false
var _camino_jugador: Path3D = null

# ── Estructura de Object Pooling ──────────────────────────────────────────────
var _pool: Array[VehiculoTraficoIA] = []
var _path_follows: Array[PathFollow3D] = []
var _inactivos: Array[int] = []
var _activos: Array[int] = []

var _temporizador_spawn: Timer


func _ready() -> void:
	_resolver_referencias()
	_recopilar_caminos()

	if not _caminos.is_empty() and (escena_vehiculo != null or not escenas_vehiculo.is_empty()):
		_construir_pool()


func _resolver_referencias() -> void:
	# 1. Camino directo asignado
	if path != NodePath("") and has_node(path):
		var p := get_node(path) as Path3D
		if p != null and not _caminos.has(p):
			_caminos.append(p)

	# 2. TrafficNetworkManager3D asignado
	if network_manager_path != NodePath("") and has_node(network_manager_path):
		_network_manager = get_node(network_manager_path)

	# 3. Jugador asignado o auto-detectado
	if target_node != NodePath("") and has_node(target_node):
		_objetivo = get_node(target_node) as Node3D
	else:
		_auto_detectar_jugador()

	# 4. Semáforo opcional
	if semaforo != NodePath("") and has_node(semaforo):
		_semaforo = get_node(semaforo) as Semaforo


func _auto_detectar_jugador() -> void:
	if not is_inside_tree():
		return
	# Intentar por grupos convencionales del proyecto
	for g in ["Vehiculo", "jugador", "player", "coche_jugador"]:
		var nodo = get_tree().get_first_node_in_group(g) as Node3D
		if nodo != null:
			_objetivo = nodo
			return

	# Intentar por la cámara principal activa
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var parent = cam.get_parent() as Node3D
		if parent != null:
			_objetivo = parent


func _recopilar_caminos() -> void:
	if not auto_detectar_caminos:
		return

	# A) Buscar TrafficNetworkManager3D en la escena
	if _network_manager == null:
		_network_manager = get_tree().get_first_node_in_group("traffic_network_manager") if get_tree() else null

	if _network_manager != null:
		var lanes = _network_manager.get("lanes")
		if lanes is Array:
			for l in lanes:
				var path_lane := l as Path3D
				if path_lane != null and _es_camino_valido(path_lane) and not _caminos.has(path_lane):
					_caminos.append(path_lane)

	# B) Buscar por grupo "traffic_lanes"
	if get_tree():
		for nodo in get_tree().get_nodes_in_group("traffic_lanes"):
			var p := nodo as Path3D
			if p != null and _es_camino_valido(p) and not _caminos.has(p):
				_caminos.append(p)

	# C) Si aún no hay caminos, escanear recursivamente la escena mapa
	if _caminos.is_empty() and get_tree():
		var root = get_tree().current_scene
		if root != null:
			_buscar_paths_recursivo(root)


func _buscar_paths_recursivo(nodo: Node) -> void:
	if nodo is Path3D and _es_camino_valido(nodo as Path3D):
		if not _caminos.has(nodo):
			_caminos.append(nodo as Path3D)
	for child in nodo.get_children():
		_buscar_paths_recursivo(child)


func _es_camino_valido(p: Path3D) -> bool:
	return p != null and p.curve != null and p.curve.get_baked_length() > 10.0


## Inicialización manual por código
func inicializar(caminos: Array[Path3D], nuevo_objetivo: Node3D = null, escenas: Array[PackedScene] = []) -> void:
	_caminos = caminos
	if nuevo_objetivo != null:
		_objetivo = nuevo_objetivo
	if not escenas.is_empty():
		escenas_vehiculo = escenas
	if _pool.is_empty() and not _caminos.is_empty():
		_construir_pool()


func _construir_pool() -> void:
	if _caminos.is_empty():
		push_warning("GestorTrafico: No hay caminos disponibles para construir el pool.")
		return

	var camino_base := _caminos[0]

	for i in tamano_pool:
		var escena := _elegir_escena()
		if escena == null:
			continue

		var path_follow := PathFollow3D.new()
		path_follow.loop = pista_en_bucle
		path_follow.rotation_mode = PathFollow3D.ROTATION_XY
		camino_base.add_child(path_follow)

		var inst = escena.instantiate()
		var vehiculo := inst as VehiculoTraficoIA
		if vehiculo == null:
			# Fallback si el script no está asignado como VehiculoTraficoIA en la escena
			push_warning("GestorTrafico: la escena %s no es VehiculoTraficoIA." % escena.resource_path)
			inst.queue_free()
			continue

		vehiculo.mostrar_velocidad = mostrar_velocidades
		path_follow.add_child(vehiculo)
		vehiculo.visible = false
		vehiculo.set_physics_process(false)
		_set_colision_vehiculo(vehiculo, false)

		_pool.append(vehiculo)
		_path_follows.append(path_follow)
		_inactivos.append(_pool.size() - 1)

	_actualizar_jugador()
	_poblar_inicial()

	_temporizador_spawn = Timer.new()
	_temporizador_spawn.wait_time = intervalo_revision_spawn
	_temporizador_spawn.autostart = true
	_temporizador_spawn.timeout.connect(_revisar_spawn)
	add_child(_temporizador_spawn)


func _physics_process(_delta: float) -> void:
	if _caminos.is_empty() or _pool.is_empty():
		return

	_actualizar_jugador()
	if _activos.is_empty():
		return

	_revisar_transiciones_de_carril()
	_revisar_despawn()
	_actualizar_lideres()


# ── Posición y carril del jugador respecto a la red vial ──────────────────────
func _actualizar_jugador() -> void:
	_jugador_valido = false
	if _objetivo == null or not is_instance_valid(_objetivo):
		_auto_detectar_jugador()
		if _objetivo == null:
			return

	var pos_jugador := _objetivo.global_position

	# Buscar el camino más cercano al jugador
	var menor_dist := INF
	var camino_cercano: Path3D = null
	var progreso_cercano: float = 0.0

	for camino in _caminos:
		if not is_instance_valid(camino) or camino.curve == null:
			continue
		var pos_local := camino.to_local(pos_jugador)
		var prog := camino.curve.get_closest_offset(pos_local)
		var pt := camino.curve.sample_baked(prog)
		var dist := pos_local.distance_to(pt)
		if dist < menor_dist:
			menor_dist = dist
			camino_cercano = camino
			progreso_cercano = prog

	if camino_cercano != null and menor_dist < 45.0:
		_camino_jugador = camino_cercano
		_progreso_jugador = progreso_cercano
		_jugador_valido = true

		var long := _camino_jugador.curve.get_baked_length()
		var tang := _tangente_en(_camino_jugador, _progreso_jugador, long)
		var mira := -_objetivo.global_transform.basis.z
		var alineado := mira.x * tang.x + mira.z * tang.y
		if alineado > 0.35:
			_sentido_jugador = 1
		elif alineado < -0.35:
			_sentido_jugador = -1

		var pos_loc := _camino_jugador.to_local(pos_jugador)
		var pt_curva := _camino_jugador.curve.sample_baked(_progreso_jugador)
		var dx := pos_loc.x - pt_curva.x
		var dz := pos_loc.z - pt_curva.z
		_lateral_jugador = dx * (-tang.y) + dz * tang.x
	else:
		_camino_jugador = null
		_jugador_valido = false


func _tangente_en(camino: Path3D, despl: float, long: float) -> Vector2:
	if camino == null or camino.curve == null or long <= 0.0:
		return Vector2(0.0, -1.0)
	var a := camino.curve.sample_baked(clampf(despl - 1.0, 0.0, long))
	var b := camino.curve.sample_baked(clampf(despl + 1.0, 0.0, long))
	var t := Vector2(b.x - a.x, b.z - a.z)
	return t.normalized() if t.length() > 0.0001 else Vector2(0.0, -1.0)


# ── Generación y Poblado Inteligente por Caminos ──────────────────────────────
func _poblar_inicial() -> void:
	if _caminos.is_empty():
		return

	var reserva := 2
	var caminos_candidatos := _obtener_caminos_cercanos_a_jugador(distancia_spawn * 1.5)
	if caminos_candidatos.is_empty():
		caminos_candidatos = _caminos

	for camino in caminos_candidatos:
		if _inactivos.size() <= reserva:
			break
		var longitud := camino.curve.get_baked_length()
		var slots := int(clampf(longitud / separacion_spawn, 1.0, 5.0))
		for s in range(slots):
			if _inactivos.size() <= reserva:
				break
			var prog := randf_range(distancia_spawn_minima, minf(longitud - 10.0, distancia_spawn))
			var sentido := 1 if randf() > proporcion_sentido_contrario else -1
			if _hay_espacio(camino, prog, sentido):
				_spawnear_en_camino(camino, prog, sentido)


func _revisar_spawn() -> void:
	if _inactivos.is_empty() or _caminos.is_empty():
		return

	var caminos_candidatos := _obtener_caminos_cercanos_a_jugador(distancia_spawn * 1.3)
	if caminos_candidatos.is_empty():
		caminos_candidatos = _caminos

	var camino_elegido: Path3D = caminos_candidatos.pick_random()
	if camino_elegido == null or camino_elegido.curve == null:
		return

	var longitud := camino_elegido.curve.get_baked_length()
	var sentido := 1 if randf() > proporcion_sentido_contrario else -1
	var prog_spawn := _elegir_progreso_spawn_camino(camino_elegido, sentido)

	if prog_spawn >= 0.0 and _hay_espacio(camino_elegido, prog_spawn, sentido):
		_spawnear_en_camino(camino_elegido, prog_spawn, sentido)


func _obtener_caminos_cercanos_a_jugador(radio_max: float) -> Array[Path3D]:
	var result: Array[Path3D] = []
	var centro := _objetivo.global_position if is_instance_valid(_objetivo) else global_position

	for c in _caminos:
		if not is_instance_valid(c) or c.curve == null:
			continue
		var pos_local := c.to_local(centro)
		var prog := c.curve.get_closest_offset(pos_local)
		var pt := c.to_global(c.curve.sample_baked(prog))
		if centro.distance_to(pt) <= radio_max:
			result.append(c)
	return result


func _elegir_progreso_spawn_camino(camino: Path3D, sentido: int) -> float:
	var long := camino.curve.get_baked_length()
	if long <= 20.0:
		return -1.0

	var camara := get_viewport().get_camera_3d()
	var pos_ref := _objetivo.global_position if is_instance_valid(_objetivo) else global_position

	# Si es el camino donde viaja el jugador, spawnear por delante o detrás
	if camino == _camino_jugador and _jugador_valido:
		var dir := float(_sentido_jugador)
		for paso in 5:
			var d := lerpf(distancia_spawn_minima, distancia_spawn, float(paso) / 4.0)
			var prog := clampf(_progreso_jugador + dir * d, 5.0, long - 5.0)
			var pt_world := camino.to_global(camino.curve.sample_baked(prog))
			if not aparecer_fuera_de_camara or camara == null or not _punto_se_ve(camara, pt_world):
				return prog
		return -1.0

	# Para otros caminos del mapa, buscar puntos dentro del radio de spawn fuera de cámara
	for intento in 6:
		var prog := randf_range(10.0, long - 10.0)
		var pt_world := camino.to_global(camino.curve.sample_baked(prog))
		var dist := pos_ref.distance_to(pt_world)
		if dist >= distancia_spawn_minima and dist <= distancia_spawn:
			if not aparecer_fuera_de_camara or camara == null or not _punto_se_ve(camara, pt_world):
				return prog
	return -1.0


func _hay_espacio(camino: Path3D, progreso: float, sentido: int) -> bool:
	for idx in _activos:
		var pf := _path_follows[idx]
		if pf.get_parent() != camino:
			continue
		var otro_vehiculo := _pool[idx]
		if otro_vehiculo.sentido != sentido:
			continue
		if absf(pf.progress - progreso) < separacion_spawn:
			return false
	return true


func _spawnear_en_camino(camino: Path3D, progreso: float, sentido: int) -> void:
	if _inactivos.is_empty():
		return
	var pos_idx := randi() % _inactivos.size()
	var indice: int = _inactivos[pos_idx]
	_inactivos.remove_at(pos_idx)

	var pf := _path_follows[indice]
	# Reparentar al camino correspondiente si es distinto
	if pf.get_parent() != camino:
		pf.reparent(camino)

	_activar(indice, progreso, sentido)
	_activos.append(indice)


# ── Transición Dinámica de Carriles (next_lanes en TrafficLane3D) ──────────────
func _revisar_transiciones_de_carril() -> void:
	for idx in _activos:
		var pf := _path_follows[idx]
		var camino := pf.get_parent() as Path3D
		if camino == null or camino.curve == null:
			continue

		var longitud := camino.curve.get_baked_length()
		var vehiculo := _pool[idx]

		# Si el vehículo llegó al final del carril en sentido positivo
		if vehiculo.sentido > 0 and pf.progress >= longitud - 1.5:
			_tratar_salida_carril(idx, camino, pf, 1)
		elif vehiculo.sentido < 0 and pf.progress <= 1.5:
			_tratar_salida_carril(idx, camino, pf, -1)


func _tratar_salida_carril(idx: int, camino_actual: Path3D, pf: PathFollow3D, _sentido: int) -> void:
	# Si es TrafficLane3D y tiene next_lanes disponibles
	var next_lanes = camino_actual.get("next_lanes")
	if next_lanes is Array and not next_lanes.is_empty():
		var validos: Array[Path3D] = []
		for l in next_lanes:
			var lane := l as Path3D
			if lane != null and lane.curve != null:
				validos.append(lane)

		if not validos.is_empty():
			var sig_lane: Path3D = validos.pick_random()
			pf.reparent(sig_lane)
			pf.progress = 0.0
			return

	# Si es una vía cerrada con bucle activo
	if pista_en_bucle:
		pf.progress = 0.0
		return

	# Si es una vía abierta y no tiene salidas conectadas: devolver al pool
	_desactivar(idx)
	_activos.erase(idx)
	_inactivos.append(idx)


# ── Reciclaje y Despawn por Proximidad ─────────────────────────────────────────
func _revisar_despawn() -> void:
	var siguen_activos: Array[int] = []
	var camara := get_viewport().get_camera_3d()
	var pos_jugador := _objetivo.global_position if is_instance_valid(_objetivo) else global_position

	for idx in _activos:
		var vehiculo := _pool[idx]
		var dist := pos_jugador.distance_to(vehiculo.global_position)
		var debe_despawn := (dist > distancia_despawn_maxima)

		if not debe_despawn and dist > distancia_despawn:
			# Verificar si la cámara aún lo está viendo
			if reciclar_solo_fuera_de_camara and camara != null:
				debe_despawn = not _punto_se_ve(camara, vehiculo.global_position)
			else:
				debe_despawn = true

		if debe_despawn:
			_desactivar(idx)
			_inactivos.append(idx)
		else:
			siguen_activos.append(idx)

	_activos = siguen_activos


# ── Detección de Líderes por Carril ───────────────────────────────────────────
func _actualizar_lideres() -> void:
	for idx in _activos:
		var vehiculo := _pool[idx]
		var pf := _path_follows[idx]
		var camino := pf.get_parent() as Path3D
		if camino == null or camino.curve == null:
			continue

		var longitud := camino.curve.get_baked_length()
		var progreso := pf.progress
		var sentido := vehiculo.sentido
		var mejor_hueco := INF

		for otro_idx in _activos:
			if otro_idx == idx:
				continue
			var otro_pf := _path_follows[otro_idx]
			if otro_pf.get_parent() != camino:
				continue # Están en caminos distintos

			var otro_vehiculo := _pool[otro_idx]
			if otro_vehiculo.sentido != sentido:
				continue

			var sep := _separacion_en_sentido(progreso, otro_pf.progress, sentido, longitud)
			var hueco := sep - (vehiculo.longitud_vehiculo + otro_vehiculo.longitud_vehiculo) * 0.5
			mejor_hueco = minf(mejor_hueco, hueco)

		# Evaluar proximidad con el jugador si comparte este camino
		if _jugador_valido and _camino_jugador == camino:
			var carril := desfase_carril * float(sentido)
			if absf(_lateral_jugador - carril) <= ancho_deteccion_jugador:
				var sep_jug := _separacion_en_sentido(progreso, _progreso_jugador, sentido, longitud)
				var hueco_jug := sep_jug - (vehiculo.longitud_vehiculo * 0.5 + semi_largo_jugador)
				mejor_hueco = minf(mejor_hueco, hueco_jug)

		vehiculo.distancia_lider = maxf(mejor_hueco, 0.0) if mejor_hueco < INF else INF


func _separacion_en_sentido(desde: float, hasta: float, sentido: int, longitud: float) -> float:
	if sentido >= 0:
		if pista_en_bucle:
			return fmod(hasta - desde + longitud, longitud)
		return hasta - desde if hasta >= desde else INF
	else:
		if pista_en_bucle:
			return fmod(desde - hasta + longitud, longitud)
		return desde - hasta if desde >= hasta else INF


# ── Activar / Desactivar ──────────────────────────────────────────────────────
func _activar(indice: int, progreso_inicial: float, sentido: int) -> void:
	var vehiculo := _pool[indice]
	_set_colision_vehiculo(vehiculo, true)
	vehiculo.multiplicador_velocidad = randf_range(1.0 - variacion_velocidad, 1.0 + variacion_velocidad)
	vehiculo.activar(_path_follows[indice], progreso_inicial, sentido, desfase_carril)


func _desactivar(indice: int) -> void:
	var vehiculo := _pool[indice]
	vehiculo.desactivar()
	_set_colision_vehiculo(vehiculo, false)
	_path_follows[indice].progress = 0.0


func _set_colision_vehiculo(vehiculo: VehiculoTraficoIA, activa: bool) -> void:
	for hijo in vehiculo.get_children():
		var col := hijo as CollisionShape3D
		if col != null:
			col.disabled = not activa


func _elegir_escena() -> PackedScene:
	if escenas_vehiculo.is_empty():
		return escena_vehiculo
	var total := 0.0
	for k in escenas_vehiculo.size():
		total += _peso_tipo(k)
	var tirada := randf() * total
	for k in escenas_vehiculo.size():
		tirada -= _peso_tipo(k)
		if tirada <= 0.0:
			return escenas_vehiculo[k]
	return escenas_vehiculo[escenas_vehiculo.size() - 1]


func _peso_tipo(k: int) -> float:
	return maxf(pesos_vehiculo[k], 0.0) if k < pesos_vehiculo.size() else 1.0


func _punto_se_ve(camara: Camera3D, punto: Vector3) -> bool:
	return camara.is_position_in_frustum(punto + Vector3.UP)
