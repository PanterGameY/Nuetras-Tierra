extends Node3D
class_name TrafficNetworkManager3D

## ══════════════════════════════════════════════════════════════════════════════
##  TrafficNetworkManager3D.gd
##  Gestor Global de Red Vial de Tráfico IA, A* Pathfinding y Pool de Tráfico Denso.
##  Mantiene una flota densa y fluida sobre los Path3D mediante Object Pooling
##  y concentración inteligente por proximidad alrededor del jugador (240m).
## ══════════════════════════════════════════════════════════════════════════════

signal network_rebuilt()

const ESCENAS_DEFAULT: Array[String] = [
	"res://modelos3d/TraficoIA/Cascadia_IA/Cascadia_IA.tscn",
	"res://modelos3d/TraficoIA/T680_IA/T680_IA.tscn",
	"res://modelos3d/TraficoIA/Escenas_IA/Furgon1.tscn",
	"res://modelos3d/TraficoIA/Transit_IA.tscn",
	"res://modelos3d/TraficoIA/Moto_IA/Moto_IA.tscn",
]

@export_group("Configuración de Tráfico y Pool")
@export var auto_scan_children: bool = true
@export var spawn_traffic_on_start: bool = true
@export_range(10, 60, 1) var max_ai_vehicles: int = 35
@export var spawn_radius: float = 240.0
@export var despawn_radius: float = 320.0
@export var separacion_minima: float = 45.0
@export var intervalo_reciclaje: float = 2.5
@export var vehicle_scenes: Array[PackedScene] = []

var lanes: Array[TrafficLane3D] = []
var all_paths: Array[Path3D] = []
var intersections: Array[TrafficIntersection3D] = []

# A* Pathfinding para GPS
var _astar: AStar3D = AStar3D.new()
var _lane_to_id: Dictionary = {}
var _id_to_lane: Dictionary = {}
var _graph_built: bool = false

# Pool de Vehículos IA
var _pool_vehiculos: Array[Node3D] = []
var _pool_path_follows: Array[PathFollow3D] = []
var _pool_caminos_asignados: Array[Path3D] = []
var _cached_player: Node3D = null
var _timer_reciclaje: Timer = null
var _salidas_rotonda: Dictionary = {}
var _entradas_rotonda: Dictionary = {}
var _salidas_calculadas: bool = false
var _es_movil: bool = false


func _ready() -> void:
	_es_movil = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
	if _es_movil:
		var ram_mb: int = int(float(OS.get_memory_info().get("physical", 0)) / 1048576.0)
		var es_ram_baja: bool = ram_mb > 0 and ram_mb <= 3900
		max_ai_vehicles = mini(max_ai_vehicles, 10 if es_ram_baja else 16)
		spawn_radius = minf(spawn_radius, 140.0 if es_ram_baja else 175.0)
		despawn_radius = minf(despawn_radius, 190.0 if es_ram_baja else 240.0)
	add_to_group("traffic_network_manager")
	if Engine.is_editor_hint():
		return

	if auto_scan_children:
		scan_network_nodes()
	build_network_graph()

	if spawn_traffic_on_start:
		call_deferred("_iniciar_pool_trafico")


func scan_network_nodes() -> void:
	lanes.clear()
	all_paths.clear()
	intersections.clear()

	for child in get_children():
		_procesar_nodo_vial(child)

	# Si lanes está vacío pero all_paths tiene nodos, registrarlos
	if lanes.is_empty() and not all_paths.is_empty():
		for p in all_paths:
			var tl := p as TrafficLane3D
			if tl:
				lanes.append(tl)


func _procesar_nodo_vial(node: Node) -> void:
	if node is TrafficLane3D:
		if not lanes.has(node):
			lanes.append(node as TrafficLane3D)
		if not all_paths.has(node):
			all_paths.append(node as Path3D)
	elif node is Path3D:
		if (node as Path3D).curve != null and not all_paths.has(node):
			all_paths.append(node as Path3D)
	elif node is TrafficIntersection3D:
		if not intersections.has(node):
			intersections.append(node as TrafficIntersection3D)

	for sub in node.get_children():
		_procesar_nodo_vial(sub)


func build_network_graph() -> void:
	_astar.clear()
	_lane_to_id.clear()
	_id_to_lane.clear()

	var id_counter = 0
	for lane in lanes:
		if not lane or not lane.is_active:
			continue

		var mid_point = lane.sample_point_at_distance(lane.get_total_length() * 0.5)
		_astar.add_point(id_counter, mid_point)
		_lane_to_id[lane] = id_counter
		_id_to_lane[id_counter] = lane
		id_counter += 1

	for lane in lanes:
		if not _lane_to_id.has(lane):
			continue
		var from_id = _lane_to_id[lane]

		for next_lane in lane.next_lanes:
			if _lane_to_id.has(next_lane):
				var to_id = _lane_to_id[next_lane]
				_astar.connect_points(from_id, to_id, false)

	_graph_built = true
	network_rebuilt.emit()


# ══════════════════════════════════════════════════════════════════════════════
#  INICIALIZACIÓN Y POOL DE TRÁFICO DENSO SOBRE PATH3D
# ══════════════════════════════════════════════════════════════════════════════

func _iniciar_pool_trafico() -> void:
	if all_paths.is_empty():
		scan_network_nodes()
	if all_paths.is_empty():
		push_warning("[TrafficNetworkManager3D] No se encontraron Path3D para el tráfico de IA.")
		return

	var escenas_disponibles := _obtener_escenas_validas()
	if escenas_disponibles.is_empty():
		push_warning("[TrafficNetworkManager3D] No se pudieron cargar escenas de vehículos.")
		return

	_pool_vehiculos.clear()
	_pool_path_follows.clear()
	_pool_caminos_asignados.clear()

	# Intentar detectar posición del jugador para poblar primero las vías cercanas
	var player := _find_player()
	var player_pos := player.global_position if player else Vector3.ZERO

	# Filtrar caminos válidos con longitud significativa (sin spawnear dentro de rotondas)
	var caminos_utilizables: Array[Path3D] = []
	for p in all_paths:
		if p != null and p.curve != null and p.curve.get_baked_length() > 20.0 and not _es_rotonda(p):
			caminos_utilizables.append(p)

	if caminos_utilizables.is_empty():
		return

	# Separar caminos prioritarios (cercanos al jugador)
	var caminos_cercanos: Array[Path3D] = []
	if player:
		for p in caminos_utilizables:
			var mid := p.to_global(p.curve.sample_baked(p.curve.get_baked_length() * 0.5))
			if player_pos.distance_to(mid) < spawn_radius * 1.5:
				caminos_cercanos.append(p)

	var flota_total := max_ai_vehicles

	for i in range(flota_total):
		# Elegir camino: alternar entre caminos cercanos al jugador y red general
		var camino: Path3D
		if not caminos_cercanos.is_empty() and (i % 3 != 0):
			camino = caminos_cercanos[i % caminos_cercanos.size()]
		else:
			camino = caminos_utilizables[i % caminos_utilizables.size()]

		var escena: PackedScene = escenas_disponibles[i % escenas_disponibles.size()]
		var inst = escena.instantiate()
		var vehiculo := inst as VehiculoTraficoIA

		if vehiculo == null:
			if inst is Node3D:
				add_child(inst)
			continue

		var pf := PathFollow3D.new()
		pf.loop = false
		pf.rotation_mode = PathFollow3D.ROTATION_NONE
		camino.add_child(pf)

		var camino_len := camino.curve.get_baked_length()
		var base_prog: float = 0.0

		if player and camino in caminos_cercanos:
			# Desfasar lejos del jugador (>= 130m) para no spawnear encima de su vista
			var local_p := camino.to_local(player_pos)
			var off_player := camino.curve.get_closest_offset(local_p)
			var offset_rel := 130.0 + float(i) * separacion_minima
			base_prog = fposmod(off_player + offset_rel, camino_len)
		else:
			base_prog = fmod(float(i) * separacion_minima * 2.0, camino_len)

		pf.progress = base_prog
		pf.add_child(vehiculo)

		vehiculo.position = Vector3(0.0, vehiculo.offset_y, 0.0)
		vehiculo.velocidad_actual = vehiculo.velocidad_crucero * randf_range(0.9, 1.15)
		vehiculo.path_follow = pf
		vehiculo.network_manager = self
		vehiculo._cruzando_interseccion = false
		vehiculo._cruce_camino_destino = null
		_alinear_vehiculo_a_camino(vehiculo, camino, base_prog)
		vehiculo.visible = true
		vehiculo.set_physics_process(true)
		vehiculo.aplicar_apariencia_aleatoria()
		vehiculo._actualizar_contacto_suelo(1.0)

		_pool_vehiculos.append(vehiculo)
		_pool_path_follows.append(pf)
		_pool_caminos_asignados.append(camino)

	print("[TrafficNetworkManager3D] Pool de tráfico denso creado: %d vehículos en %d caminos." % [_pool_vehiculos.size(), caminos_utilizables.size()])

	# Iniciar temporizador de reciclaje por proximidad para mantener densidad continua
	if _timer_reciclaje == null:
		_timer_reciclaje = Timer.new()
		_timer_reciclaje.wait_time = intervalo_reciclaje
		_timer_reciclaje.autostart = true
		_timer_reciclaje.timeout.connect(_actualizar_proximidad_pool)
		add_child(_timer_reciclaje)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _pool_vehiculos.is_empty():
		return
	if _es_movil and (Engine.get_physics_frames() & 1) != 0:
		return

	if not _salidas_calculadas:
		_inicializar_salidas_rotonda()

	var ahora := Time.get_ticks_msec() * 0.001
	var player := _find_player()
	var player_pos: Vector3 = player.global_position if player != null and is_instance_valid(player) else Vector3.ZERO
	var has_player: bool = player != null and is_instance_valid(player)

	# Agrupar vehículos válidos por camino
	var por_camino: Dictionary = {}
	for i in range(_pool_vehiculos.size()):
		var veh := _pool_vehiculos[i] as VehiculoTraficoIA
		var pf := _pool_path_follows[i]
		if not is_instance_valid(veh) or not is_instance_valid(pf) or not veh.visible:
			continue

		# Actualizar distancia al jugador para el sistema de LOD de alto rendimiento
		if has_player:
			veh.distancia_al_jugador = veh.global_position.distance_to(player_pos)
		else:
			veh.distancia_al_jugador = 20.0

		var camino: Path3D = pf.get_parent() as Path3D
		if camino == null or camino.curve == null:
			continue

		# Salida natural de rotondas hacia carreteras conectadas (nunca fuera de la vía)
		if _salidas_rotonda.has(camino) and not veh._cruzando_interseccion:
			var salidas: Array = _salidas_rotonda[camino]
			if not salidas.is_empty() and ahora >= float(veh.get_meta("rotonda_cd", 0.0)):
				for s in salidas:
					if absf(pf.progress - float(s["offset"])) <= 3.5:
						veh.set_meta("rotonda_cd", ahora + 3.5)
						if randf() < 0.55:
							var p_sal: Path3D = s["path"]
							var off_sal: float = float(s["offset_salida"])
							var pt_sal: Vector3 = s["pt_salida"]
							if not _espacio_libre_entrada_rotonda(p_sal, pt_sal, 11.0, veh):
								break
							if veh.global_position.distance_to(pt_sal) > 3.5 and veh.has_method("iniciar_cruce_interseccion"):
								veh.iniciar_cruce_interseccion(p_sal, off_sal, pt_sal)
							else:
								finalizar_cruce_camino(veh, p_sal, off_sal)
							break

		# Los vehículos que están cruzando una intersección ya abandonaron su Path3D previo:
		# no deben generar bloqueo fantasma sobre quienes vienen detrás en el carril anterior
		if veh._cruzando_interseccion:
			veh.distancia_lider = INF
			continue

		if not por_camino.has(camino):
			por_camino[camino] = []
		por_camino[camino].append({"veh": veh, "pf": pf, "prog": pf.progress})

	# Calcular hueco hacia el líder precedente mediante ordenamiento O(N log N)
	for camino in por_camino.keys():
		var lista: Array = por_camino[camino]
		var c_len: float = (camino as Path3D).curve.get_baked_length()
		var n_veh: int = lista.size()
		if c_len <= 0.0 or n_veh == 0:
			continue

		var curva := (camino as Path3D).curve
		var es_cerrado: bool = curva.sample_baked(0.0).distance_to(curva.sample_baked(c_len)) < 15.0

		if n_veh == 1:
			lista[0]["veh"].distancia_lider = INF
		else:
			# Ordenar vehículos por progreso longitudinal
			lista.sort_custom(func(a, b): return a["prog"] < b["prog"])

			for idx in range(n_veh):
				var item: Dictionary = lista[idx]
				var veh: VehiculoTraficoIA = item["veh"]
				var pf: PathFollow3D = item["pf"]
				var prog: float = item["prog"]
				var menor_gap: float = INF

				for other_idx in range(n_veh):
					if other_idx == idx:
						continue
					var otro: Dictionary = lista[other_idx]
					var otro_veh: VehiculoTraficoIA = otro["veh"]
					var otro_pf: PathFollow3D = otro["pf"]

					# Ignorar vehículos en sentido contrario
					if otro_veh.sentido != veh.sentido:
						continue

					# Si los dos vehículos están en carriles distintos (desfase lateral diff > 1.8m), no se bloquean
					if absf(veh._desfase_lateral_actual - otro_veh._desfase_lateral_actual) > 1.8:
						continue

					var otro_prog: float = otro["prog"]
					var dist_adelante: float
					if es_cerrado:
						dist_adelante = fposmod((otro_prog - prog) * float(veh.sentido), c_len)
					else:
						dist_adelante = (otro_prog - prog) * float(veh.sentido)
						if dist_adelante <= 0.0:
							continue

					# Solo considerar líder hacia adelante en la dirección del flujo de la vía
					var max_rango_lider := minf(c_len * 0.45, 60.0) if es_cerrado else 60.0
					if dist_adelante < max_rango_lider:
						var mitad_muras: float = (veh.longitud_vehiculo * 0.5 + otro_veh.longitud_vehiculo * 0.5)
						var gap: float = maxf(dist_adelante - mitad_muras, 0.0)
						if gap < menor_gap:
							menor_gap = gap

				veh.distancia_lider = menor_gap

		# Ceda el paso al aproximarse a una rotonda ocupada (prelación de quien ya circula dentro)
		var info_entrada: Dictionary = _entradas_rotonda.get(camino, {})
		var lider_cediendo_rotonda: bool = false
		if not info_entrada.is_empty():
			var rotonda_dest: Path3D = info_entrada["rotonda"]
			var pt_ent: Vector3 = info_entrada["pt_entrada"]
			for item_e in lista:
				var veh_e: VehiculoTraficoIA = item_e["veh"]
				if veh_e._cruzando_interseccion or veh_e.sentido < 0:
					continue
				var dist_fin: float = c_len - float(item_e["prog"])
				if dist_fin >= -1.0 and dist_fin <= 9.0:
					if not _espacio_libre_entrada_rotonda(rotonda_dest, pt_ent, 11.5, veh_e):
						var hueco_ceda := maxf(dist_fin - 0.2, 0.2)
						veh_e.distancia_lider = minf(veh_e.distancia_lider, hueco_ceda)
						lider_cediendo_rotonda = true

		# Desbloqueo prioritario de cabeza de fila solo en vías abiertas (sin invadir rotondas ocupadas)
		if not es_cerrado and n_veh >= 2 and not lider_cediendo_rotonda:
			var lider_grupo: VehiculoTraficoIA = lista[n_veh - 1]["veh"]
			var todos_detenidos := true
			for item_v in lista:
				if item_v["veh"].velocidad_actual > 1.2:
					todos_detenidos = false
					break
			if todos_detenidos and is_instance_valid(lider_grupo):
				lider_grupo.distancia_lider = INF


## Indica si hay un vehículo detenido/frenando o el jugador bloqueando la vía delante de `veh`
func hay_vehiculo_detenido_o_bloqueo_adelante(veh: VehiculoTraficoIA, max_dist: float = 55.0) -> bool:
	if not is_instance_valid(veh):
		return false

	var dir_veh: Vector3 = -veh.global_transform.basis.z
	dir_veh.y = 0.0
	if dir_veh.length_squared() > 0.001:
		dir_veh = dir_veh.normalized()

	# 1. Revisar si el jugador o su vehículo conducido están bloqueando por delante
	var player := _find_player()
	if player != null and is_instance_valid(player):
		var rel_p: Vector3 = player.global_position - veh.global_position
		rel_p.y = 0.0
		var d_p: float = rel_p.length()
		if d_p > 0.1 and d_p <= max_dist and dir_veh.length_squared() > 0.5:
			var fwd_p: float = rel_p.dot(dir_veh)
			var lat_p: float = absf(rel_p.cross(dir_veh).y)
			if fwd_p > 0.0 and lat_p <= 5.0:
				return true

	var idx := _pool_vehiculos.find(veh)
	if idx == -1 or idx >= _pool_path_follows.size():
		return false
	var pf := _pool_path_follows[idx]
	if not is_instance_valid(pf):
		return false
	var camino := pf.get_parent() as Path3D
	if camino == null or camino.curve == null:
		return false

	var c_len := camino.curve.get_baked_length()
	var es_cerrado := c_len > 0.0 and camino.curve.sample_baked(0.0).distance_to(camino.curve.sample_baked(c_len)) < 15.0
	var prog := pf.progress

	for i in range(_pool_vehiculos.size()):
		var otro := _pool_vehiculos[i] as VehiculoTraficoIA
		if not is_instance_valid(otro) or otro == veh or not otro.visible:
			continue
		var otro_pf := _pool_path_follows[i]
		if not is_instance_valid(otro_pf) or otro_pf.get_parent() != camino:
			continue
		if otro.sentido != veh.sentido:
			continue
		if absf(veh._desfase_lateral_actual - otro._desfase_lateral_actual) > 2.2:
			continue

		var dist_adelante: float
		if es_cerrado:
			dist_adelante = fposmod((otro_pf.progress - prog) * float(veh.sentido), c_len)
		else:
			dist_adelante = (otro_pf.progress - prog) * float(veh.sentido)
			if dist_adelante <= 0.0:
				continue

		if dist_adelante <= max_dist:
			if otro.velocidad_actual < 4.5 or otro.luces_stop or otro._tiempo_detenido > 0.1 or otro.frenar_por_semaforo or otro._es_jugador_o_camion_jugador(otro._ultimo_col_ray):
				return true

	return false


func _punto_sobre_asfalto(space: PhysicsDirectSpaceState3D, pt: Vector3) -> bool:
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(pt + Vector3(0.0, 4.0, 0.0), pt - Vector3(0.0, 4.0, 0.0), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var col_obj: Object = hit["collider"]
	var col_name: String = str(col_obj.get_parent().name).to_lower() if (col_obj is Node and col_obj.get_parent()) else str(col_obj).to_lower()
	return col_name.contains("carretera") or col_name.contains("asfalto") or col_name.contains("calle") or col_name.contains("rotonda") or col_name.contains("trocha")


func carril_paralelo_despejado(cam: Path3D, offset_p: float, ignorar_veh: VehiculoTraficoIA) -> bool:
	if not is_instance_valid(cam) or cam.curve == null:
		return false
	var c_len := cam.curve.get_baked_length()
	var es_cerrado := _es_rotonda(cam) or cam.curve.sample_baked(0.0).distance_to(cam.curve.sample_baked(c_len)) < 15.0
	var pt_ref := cam.to_global(cam.curve.sample_baked(offset_p))
	var pt_ref_fwd := cam.to_global(cam.curve.sample_baked(minf(offset_p + 4.0, c_len)))
	var dir_cam := pt_ref_fwd - pt_ref
	dir_cam.y = 0.0
	dir_cam = dir_cam.normalized() if dir_cam.length_squared() > 0.001 else Vector3.FORWARD

	# Solo bloquear el carril paralelo si el jugador o su vehículo ocupan físicamente ese corredor o tocan el coche
	var player := _find_player()
	if player != null and is_instance_valid(player):
		var objetivos_pl: Array[Node3D] = [player]
		var p_veh = player.get("_vehiculo_actual")
		if p_veh is Node3D and is_instance_valid(p_veh):
			objetivos_pl.append(p_veh as Node3D)
		for obj_pl in objetivos_pl:
			if is_instance_valid(ignorar_veh) and obj_pl.global_position.distance_to(ignorar_veh.global_position) < 5.5:
				return false
			var rel_pl := obj_pl.global_position - pt_ref
			rel_pl.y = 0.0
			var fwd_pl := rel_pl.dot(dir_cam)
			var lat_pl := absf(rel_pl.cross(dir_cam).y)
			if fwd_pl >= -10.0 and fwd_pl <= 38.0 and lat_pl <= 3.6:
				return false

	for i in range(_pool_vehiculos.size()):
		var v := _pool_vehiculos[i] as VehiculoTraficoIA
		var pf := _pool_path_follows[i]
		if not is_instance_valid(v) or not is_instance_valid(pf) or not v.visible or v == ignorar_veh:
			continue
		var en_cam: bool = (pf.get_parent() == cam or v._cruce_camino_destino == cam)
		var reservando_cam: bool = (v._carril_destino_cambio == cam and (v._estado_carril == VehiculoTraficoIA.EstadoCarril.PREPARANDO_CAMBIO or v._estado_carril == VehiculoTraficoIA.EstadoCarril.CAMBIANDO))
		if not en_cam and not reservando_cam:
			continue
		var v_off: float = pf.progress if pf.get_parent() == cam else cam.curve.get_closest_offset(cam.to_local(v.global_position))
		var diff_signed: float = v_off - offset_p
		if es_cerrado and c_len > 0.0:
			diff_signed = fposmod(diff_signed + c_len * 0.5, c_len) - c_len * 0.5
		if diff_signed >= -20.0 and diff_signed <= 38.0:
			return false
	return true


func completar_cambio_carril_a_camino(veh: VehiculoTraficoIA, camino_dest: Path3D) -> bool:
	if not is_instance_valid(veh) or not is_instance_valid(camino_dest) or camino_dest.curve == null:
		return false
	var idx := _pool_vehiculos.find(veh)
	if idx == -1 or idx >= _pool_path_follows.size():
		return false
	var pf := _pool_path_follows[idx]
	if not is_instance_valid(pf):
		return false

	var pos_mundo := veh.global_position
	var rot_mundo := veh.global_transform.basis
	var nuevo_offset := camino_dest.curve.get_closest_offset(camino_dest.to_local(pos_mundo))

	if pf.get_parent() != camino_dest:
		pf.reparent(camino_dest, false)
	_pool_caminos_asignados[idx] = camino_dest
	pf.h_offset = 0.0
	pf.progress = nuevo_offset
	veh.sentido = 1
	veh.position = Vector3(0.0, veh.position.y, 0.0)
	veh.global_transform.basis = rot_mundo
	return true


## Determina si existe un carril paralelo contiguo en la misma dirección hacia donde se puede adelantar
func obtener_info_carril_paralelo(camino_origen: Path3D, pos_global: Vector3, dir_adelante: Vector3, ignorar_veh: VehiculoTraficoIA = null, solo_lado: float = 0.0) -> Dictionary:
	var mejor_candidato: Dictionary = {"encontrado": false}
	var menor_dist: float = INF

	var mundo := get_world_3d()
	var space: PhysicsDirectSpaceState3D = mundo.direct_space_state if mundo else null

	for p in all_paths:
		if not is_instance_valid(p) or p == camino_origen or p.curve == null or not p.is_inside_tree() or _es_rotonda(p):
			continue

		var loc := p.to_local(pos_global)
		var offset_p := p.curve.get_closest_offset(loc)
		var c_len := p.curve.get_baked_length()
		if c_len - offset_p < 35.0:
			continue
		var pt_p := p.to_global(p.curve.sample_baked(offset_p))
		var d_3d := pos_global.distance_to(pt_p)

		# Un carril paralelo contiguo en la red vial típicamente se encuentra entre 2.5m y 6.8m
		if d_3d >= 2.5 and d_3d <= 6.8 and d_3d < menor_dist:
			var off_adelante := minf(offset_p + 4.0, c_len)
			var pt_adelante := p.to_global(p.curve.sample_baked(off_adelante))
			var dir_p := (pt_adelante - pt_p).normalized()
			var dot_val := dir_adelante.dot(dir_p)

			if dot_val > 0.88 and carril_paralelo_despejado(p, offset_p, ignorar_veh):
				var to_other := (pt_p - pos_global)
				var cross_y := dir_adelante.cross(to_other).y
				# En Godot, cross(forward, right).y < 0; si cross_y > 0 está a la izquierda
				var lado: float = -1.0 if cross_y > 0.0 else 1.0 # -1 izquierda, +1 derecha
				if solo_lado != 0.0 and signf(lado) != signf(solo_lado):
					continue

				# Verificar que tanto el punto destino como 18m más adelante pisen asfalto real (nunca acera ni muro)
				var pt_p_fwd := p.to_global(p.curve.sample_baked(minf(offset_p + 18.0, c_len)))
				if not _punto_sobre_asfalto(space, pt_p) or not _punto_sobre_asfalto(space, pt_p_fwd):
					continue

				menor_dist = d_3d
				mejor_candidato = {
					"encontrado": true,
					"path": p,
					"offset": offset_p,
					"distancia": d_3d,
					"lado": lado,
					"punto": pt_p
				}

	return mejor_candidato


func _obtener_escenas_validas() -> Array[PackedScene]:
	var resultado: Array[PackedScene] = []
	for sc in vehicle_scenes:
		if sc != null:
			resultado.append(sc)

	if resultado.is_empty():
		for ruta in ESCENAS_DEFAULT:
			if ResourceLoader.exists(ruta):
				var cargada = load(ruta) as PackedScene
				if cargada != null:
					resultado.append(cargada)

	return resultado


func _actualizar_proximidad_pool() -> void:
	if _pool_vehiculos.is_empty():
		return

	var player := _find_player()
	if player == null or not is_instance_valid(player):
		return

	var player_pos := player.global_position

	# Identificar caminos cercanos al jugador
	var caminos_cercanos: Array[Path3D] = []
	for p in all_paths:
		if is_instance_valid(p) and p.curve != null:
			var loc := p.to_local(player_pos)
			var nearest_off := p.curve.get_closest_offset(loc)
			var pt_world := p.to_global(p.curve.sample_baked(nearest_off))
			if player_pos.distance_to(pt_world) < spawn_radius * 1.4:
				caminos_cercanos.append(p)

	if caminos_cercanos.is_empty():
		return

	for i in range(_pool_vehiculos.size()):
		var veh := _pool_vehiculos[i]
		var pf := _pool_path_follows[i]
		if not is_instance_valid(veh) or not is_instance_valid(pf):
			continue

		var dist := player_pos.distance_to(veh.global_position)

		# Si el vehículo se alejó demasiado del jugador (> despawn_radius), reciclarlo fuera de su vista directa
		if dist > despawn_radius:
			var spawn_info := _buscar_punto_spawn_oculto(caminos_cercanos, player_pos, true, 165.0)
			var nuevo_camino: Path3D = spawn_info["camino"]
			var nuevo_prog: float = spawn_info["prog"]
			_reubicar_vehiculo_en_camino(veh, pf, i, nuevo_camino, nuevo_prog)


## Reciclaje inteligente tipo ATS/ETS2 cuando un vehículo queda bloqueado o termina una vía sin salida
func _reciclar_vehiculo_atascado(veh: VehiculoTraficoIA) -> void:
	var idx := _pool_vehiculos.find(veh)
	if idx == -1 or idx >= _pool_path_follows.size():
		return
	var pf: PathFollow3D = _pool_path_follows[idx]
	var camino_actual: Path3D = _pool_caminos_asignados[idx]
	if not is_instance_valid(pf) or all_paths.is_empty():
		return

	var player := _find_player()
	var has_player := player != null and is_instance_valid(player)
	var player_pos := player.global_position if has_player else Vector3.ZERO

	var candidatos: Array[Path3D] = []
	for p in all_paths:
		if is_instance_valid(p) and p.curve != null and p.curve.get_baked_length() > 20.0 and not _es_rotonda(p):
			candidatos.append(p)
	if candidatos.is_empty():
		if is_instance_valid(camino_actual):
			candidatos.append(camino_actual)
		else:
			return

	var spawn_info := _buscar_punto_spawn_oculto(candidatos, player_pos, has_player, 165.0)
	_reubicar_vehiculo_en_camino(veh, pf, idx, spawn_info["camino"], spawn_info["prog"])


func _reubicar_vehiculo_en_camino(veh: VehiculoTraficoIA, pf: PathFollow3D, idx: int, nuevo_camino: Path3D, nuevo_prog: float) -> void:
	if not is_instance_valid(nuevo_camino) or nuevo_camino.curve == null:
		return
	if pf.get_parent() != nuevo_camino:
		pf.reparent(nuevo_camino, false)
	_pool_caminos_asignados[idx] = nuevo_camino
	pf.progress = nuevo_prog
	pf.h_offset = 0.0
	veh.sentido = 1
	veh._cruzando_interseccion = false
	veh._cruce_camino_destino = null
	veh._desfase_lateral_actual = 0.0
	veh._desfase_lateral_objetivo = 0.0
	veh.position = Vector3(0.0, veh.offset_y, 0.0)
	_alinear_vehiculo_a_camino(veh, nuevo_camino, nuevo_prog)
	veh.velocidad_actual = veh.velocidad_crucero * randf_range(0.85, 1.1)
	veh.distancia_lider = INF
	veh._distancia_ray_cache = INF
	veh.frenar_por_semaforo = false
	veh.luces_stop = false
	veh.visible = true
	veh.set_physics_process(true)
	veh._actualizar_contacto_suelo(1.0)


func _alinear_vehiculo_a_camino(veh: VehiculoTraficoIA, camino: Path3D, prog: float) -> void:
	if not is_instance_valid(veh) or not is_instance_valid(camino) or camino.curve == null:
		return
	var c_len := camino.curve.get_baked_length()
	if c_len <= 0.5:
		return
	var p0 := camino.to_global(camino.curve.sample_baked(clampf(prog, 0.0, c_len)))
	var prog1 := clampf(prog + 3.0 * float(veh.sentido), 0.0, c_len)
	if absf(prog1 - prog) < 0.2:
		prog1 = clampf(prog - 3.0 * float(veh.sentido), 0.0, c_len)
	var p1 := camino.to_global(camino.curve.sample_baked(prog1))
	var dir := (p1 - p0) if prog1 >= prog else (p0 - p1)
	if veh.sentido < 0:
		dir = -dir
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		veh.global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)


func _inicializar_salidas_rotonda() -> void:
	_salidas_calculadas = true
	_salidas_rotonda.clear()
	_entradas_rotonda.clear()
	for r in all_paths:
		if not _es_rotonda(r):
			continue
		var r_len := r.curve.get_baked_length()
		var lista_salidas: Array = []
		for p in all_paths:
			if not is_instance_valid(p) or p == r or _es_rotonda(p) or p.curve == null or not p.is_inside_tree():
				continue
			var p_len := p.curve.get_baked_length()
			if p_len < 10.0:
				continue
			var pt_ini := p.to_global(p.curve.sample_baked(0.0))
			var off_r := r.curve.get_closest_offset(r.to_local(pt_ini))
			var pt_r := r.to_global(r.curve.sample_baked(off_r))
			if pt_ini.distance_to(pt_r) <= 14.0:
				var saltar_salida := (r.name == "Path3D2" and p.name == "Path3D5") or (r.name == "Path3D8" and p.name == "Path3D4")
				if not saltar_salida:
					var dir_p := p.to_global(p.curve.sample_baked(minf(3.0, p_len))) - pt_ini
					dir_p.y = 0.0
					var dir_r := r.to_global(r.curve.sample_baked(fposmod(off_r + 3.0, r_len))) - pt_r
					dir_r.y = 0.0
					if dir_p.length_squared() > 0.001 and dir_r.length_squared() > 0.001:
						if dir_r.normalized().dot(dir_p.normalized()) >= 0.30:
							var off_sal := minf(8.0, p_len * 0.5)
							var pt_sal := p.to_global(p.curve.sample_baked(off_sal))
							lista_salidas.append({"path": p, "offset": off_r, "offset_salida": off_sal, "pt_salida": pt_sal})

			# Registrar también entradas hacia la rotonda para Ceda el Paso anticipado
			if (p.name == "Path3D6" and r.name == "Path3D2") or (p.name == "TrafficLane3D2" and r.name == "Path3D8"):
				continue
			var pt_fin_p := p.to_global(p.curve.sample_baked(p_len))
			var off_ent_r := r.curve.get_closest_offset(r.to_local(pt_fin_p))
			var pt_ent_r := r.to_global(r.curve.sample_baked(off_ent_r))
			if pt_fin_p.distance_to(pt_ent_r) <= 22.0:
				var dir_fin_p := pt_fin_p - p.to_global(p.curve.sample_baked(maxf(p_len - 3.0, 0.0)))
				dir_fin_p.y = 0.0
				var dir_ent_r := r.to_global(r.curve.sample_baked(fposmod(off_ent_r + 3.0, r_len))) - pt_ent_r
				dir_ent_r.y = 0.0
				if dir_fin_p.length_squared() > 0.001 and dir_ent_r.length_squared() > 0.001:
					if dir_fin_p.normalized().dot(dir_ent_r.normalized()) >= 0.35:
						var prev_ent: Dictionary = _entradas_rotonda.get(p, {})
						var d_ent := pt_fin_p.distance_to(pt_ent_r)
						if prev_ent.is_empty() or d_ent < float(prev_ent["dist"]):
							_entradas_rotonda[p] = {"rotonda": r, "pt_entrada": pt_ent_r, "dist": d_ent}
		if not lista_salidas.is_empty():
			_salidas_rotonda[r] = lista_salidas


func _es_rotonda(cam: Path3D) -> bool:
	if not is_instance_valid(cam) or cam.curve == null:
		return false
	var c_len := cam.curve.get_baked_length()
	if c_len < 10.0 or c_len >= 400.0:
		return false
	var pt_ini := cam.to_global(cam.curve.sample_baked(0.0))
	var pt_end := cam.to_global(cam.curve.sample_baked(c_len))
	return pt_ini.distance_to(pt_end) < 15.0


func _esta_en_zona_rotonda(pt: Vector3, radio_exclusion: float = 75.0) -> bool:
	for r in all_paths:
		if not _es_rotonda(r):
			continue
		var off := r.curve.get_closest_offset(r.to_local(pt))
		var pt_r := r.to_global(r.curve.sample_baked(off))
		if pt.distance_to(pt_r) < radio_exclusion:
			return true
	return false


func _buscar_punto_spawn_oculto(caminos: Array[Path3D], player_pos: Vector3, has_player: bool, min_dist_player: float) -> Dictionary:
	var caminos_spawn: Array[Path3D] = []
	for c in caminos:
		if not _es_rotonda(c):
			caminos_spawn.append(c)
	if caminos_spawn.is_empty():
		caminos_spawn = caminos

	var mejor_camino: Path3D = caminos_spawn[0]
	var mejor_prog: float = 0.0
	var mejor_score: float = -1.0

	for _intento in range(28):
		var cam: Path3D = caminos_spawn.pick_random()
		if not is_instance_valid(cam) or cam.curve == null:
			continue
		var c_len := cam.curve.get_baked_length()
		if c_len <= 15.0:
			continue
		var prog := randf_range(0.0, maxf(c_len - 10.0, 0.0))
		var pt := cam.to_global(cam.curve.sample_baked(prog))

		# Nunca generar coches dentro de la rotonda ni en sus entradas/salidas cercanas
		if _esta_en_zona_rotonda(pt, 75.0):
			continue

		var dist_p := pt.distance_to(player_pos) if has_player else min_dist_player
		if has_player and dist_p > despawn_radius * 0.92:
			continue

		var cerca_otro := false
		for v in _pool_vehiculos:
			if is_instance_valid(v) and v.visible and v.global_position.distance_squared_to(pt) < 625.0:
				cerca_otro = true
				break

		if not has_player and not cerca_otro:
			return {"camino": cam, "prog": prog}
		if has_player and dist_p >= min_dist_player and not cerca_otro:
			return {"camino": cam, "prog": prog}

		var score := dist_p - (500.0 if cerca_otro else 0.0)
		if score > mejor_score:
			mejor_score = score
			mejor_camino = cam
			mejor_prog = prog

	return {"camino": mejor_camino, "prog": mejor_prog}


func _espacio_libre_entrada_rotonda(camino_dest: Path3D, pt_destino: Vector3, radio: float, ignorar_veh: VehiculoTraficoIA) -> bool:
	for i in range(_pool_vehiculos.size()):
		var v := _pool_vehiculos[i] as VehiculoTraficoIA
		var pf := _pool_path_follows[i]
		if not is_instance_valid(v) or not is_instance_valid(pf) or not v.visible or v == ignorar_veh:
			continue
		var esta_en_dest := (pf.get_parent() == camino_dest and not v._cruzando_interseccion) or (v._cruce_camino_destino == camino_dest)
		if not esta_en_dest:
			continue
		var dist := v.global_position.distance_to(pt_destino)
		if dist < radio:
			# Si el vehículo ya superó el punto de entrada y se aleja hacia adelante (> 7 m), no bloquea la incorporación
			var fwd_v := -v.global_transform.basis.z
			fwd_v.y = 0.0
			var rel := v.global_position - pt_destino
			rel.y = 0.0
			if dist > 7.0 and rel.dot(fwd_v) > 0.0:
				continue
			return false
	return true


func _hay_vehiculo_cerca_en_camino(cam: Path3D, prog_objetivo: float, radio: float, ignorar_veh: VehiculoTraficoIA) -> bool:
	if not is_instance_valid(cam) or cam.curve == null:
		return false
	var c_len := cam.curve.get_baked_length()
	var es_cerrado := _es_rotonda(cam) or cam.curve.sample_baked(0.0).distance_to(cam.curve.sample_baked(c_len)) < 15.0
	for i in range(_pool_vehiculos.size()):
		var v := _pool_vehiculos[i] as VehiculoTraficoIA
		var pf := _pool_path_follows[i]
		if not is_instance_valid(v) or not is_instance_valid(pf) or not v.visible or v == ignorar_veh:
			continue
		if pf.get_parent() != cam:
			continue
		var diff := absf(pf.progress - prog_objetivo)
		if es_cerrado and c_len > 0.0:
			diff = minf(diff, c_len - diff)
		if diff < radio:
			return true
	return false


## Empalme y traspaso automático de vehículos entre nodos Path3D de la red vial
func traspasar_vehiculo_siguiente_camino(veh: VehiculoTraficoIA, camino_actual: Path3D, prog_nuevo: float, c_len: float) -> bool:
	var idx := _pool_vehiculos.find(veh)
	if idx == -1 or idx >= _pool_path_follows.size():
		return false
	var pf: PathFollow3D = _pool_path_follows[idx]
	if not is_instance_valid(pf):
		return false

	var saliendo_por_fin: bool = (veh.sentido >= 0)
	var dist_salida: float = c_len if saliendo_por_fin else 0.0
	var pt_fin := camino_actual.to_global(camino_actual.curve.sample_baked(dist_salida))
	var pt_antes := camino_actual.to_global(camino_actual.curve.sample_baked(clampf(dist_salida - 3.0 * float(veh.sentido), 0.0, c_len)))
	var dir_salida := (pt_fin - pt_antes)
	dir_salida.y = 0.0
	if dir_salida.length_squared() > 0.001:
		dir_salida = dir_salida.normalized()
	else:
		dir_salida = -veh.global_transform.basis.z
		dir_salida.y = 0.0
		dir_salida = dir_salida.normalized()

	var mejor_camino: Path3D = null
	var target_offset: float = 0.0
	var menor_score: float = INF

	# 0. Si ya está en una rotonda, continuar siempre dando la vuelta en SU MISMO anillo (evita saltos entre Path3D8 y Path3D2)
	if _es_rotonda(camino_actual):
		pf.progress = fposmod(prog_nuevo, maxf(c_len, 1.0))
		return true

	# 1. Si es TrafficLane3D con conexiones explícitas
	var tl := camino_actual as TrafficLane3D
	if tl != null and not tl.next_lanes.is_empty():
		var candidatos: Array[TrafficLane3D] = []
		for nxt in tl.next_lanes:
			if is_instance_valid(nxt) and nxt.is_active and nxt.curve != null:
				candidatos.append(nxt)
		if not candidatos.is_empty():
			mejor_camino = candidatos.pick_random()
			target_offset = maxf(prog_nuevo - c_len, 0.0) if saliendo_por_fin else mejor_camino.curve.get_baked_length()

	# 2. Empalme automático: inicios (0.0) de Path3D adelante, o puntos intermedios de bucles cerrados (rotondas)
	if mejor_camino == null:
		var right_salida := Vector3(-dir_salida.z, 0.0, dir_salida.x)
		for p in all_paths:
			if not is_instance_valid(p) or p == camino_actual or p.curve == null or not p.is_inside_tree():
				continue
			var p_len := p.curve.get_baked_length()
			if p_len < 10.0:
				continue

			var pt_ini := p.to_global(p.curve.sample_baked(0.0))
			var pt_end := p.to_global(p.curve.sample_baked(p_len))
			var es_bucle_cerrado := pt_ini.distance_to(pt_end) < 15.0

			if es_bucle_cerrado:
				# Emparejar carril interior (Path3D6) con rotonda pequeña (Path3D8) y exterior con grande (Path3D2)
				if camino_actual.name == "Path3D6" and p.name == "Path3D2":
					continue
				if camino_actual.name == "TrafficLane3D2" and p.name == "Path3D8":
					continue
				# Incorporación a rotondas o anillos cerrados en el punto más cercano de la circunferencia
				var off_cercano := p.curve.get_closest_offset(p.to_local(pt_fin))
				var pt_cercano := p.to_global(p.curve.sample_baked(off_cercano))
				var to_cercano := pt_cercano - pt_fin
				to_cercano.y = 0.0
				var d_cercano := to_cercano.length()
				if d_cercano <= 22.0:
					if d_cercano <= 1.5 or dir_salida.dot(to_cercano / d_cercano) >= 0.0:
						var pt_fwd_ring := p.to_global(p.curve.sample_baked(fposmod(off_cercano + 3.0, p_len)))
						var dir_ring := pt_fwd_ring - pt_cercano
						dir_ring.y = 0.0
						if dir_ring.length_squared() > 0.001 and dir_salida.dot(dir_ring.normalized()) >= 0.35:
							var desvio_ring := absf(right_salida.dot(to_cercano))
							if desvio_ring <= 12.0:
								var score_ring := d_cercano + desvio_ring * 2.5
								if score_ring < menor_score:
									menor_score = score_ring
									mejor_camino = p
									target_offset = fposmod(off_cercano + 6.0, p_len)
				continue

			var to_ini := pt_ini - pt_fin
			to_ini.y = 0.0
			var d_ini := to_ini.length()
			if d_ini > 45.0:
				continue

			# Debe estar en un cono frontal delante del vehículo (no a un lado ni atrás)
			if d_ini > 0.5:
				var dir_al_ini := to_ini / d_ini
				if dir_salida.dot(dir_al_ini) < 0.75:
					continue

			# La vía de adelante debe ir en la misma dirección de flujo
			var pt_fwd := p.to_global(p.curve.sample_baked(minf(3.0, p_len)))
			var dir_p := pt_fwd - pt_ini
			dir_p.y = 0.0
			if dir_p.length_squared() > 0.001:
				if dir_salida.dot(dir_p.normalized()) < 0.60:
					continue

			# Penalizar desvío lateral para que cada carril empalme con su carril correspondiente adelante
			var desvio_lat := absf(right_salida.dot(to_ini))
			var score := d_ini + desvio_lat * 4.0
			if score < menor_score:
				menor_score = score
				mejor_camino = p
				target_offset = 0.0

	if mejor_camino != null and mejor_camino.curve != null:
		var clamped_off := clampf(target_offset, 0.0, mejor_camino.curve.get_baked_length())
		var pt_destino := mejor_camino.to_global(mejor_camino.curve.sample_baked(clamped_off))
		if _es_rotonda(mejor_camino) and not _espacio_libre_entrada_rotonda(mejor_camino, pt_destino, 9.0, veh):
			# Esperar al borde de entrada sin invadir la rotonda ni reciclar
			pf.progress = c_len if saliendo_por_fin else 0.0
			veh.velocidad_actual = 0.0
			veh.luces_stop = true
			return true
		if pt_fin.distance_to(pt_destino) > 3.5 and veh.has_method("iniciar_cruce_interseccion"):
			veh.iniciar_cruce_interseccion(mejor_camino, clamped_off, pt_destino)
			return true
		finalizar_cruce_camino(veh, mejor_camino, clamped_off)
		return true

	# 3. Fin de vía sin continuación: reciclar limpiamente sin trompos ni levitaciones
	_reciclar_vehiculo_atascado(veh)
	return true


func finalizar_cruce_camino(veh: VehiculoTraficoIA, mejor_camino: Path3D, target_offset: float) -> void:
	var idx := _pool_vehiculos.find(veh)
	if idx == -1 or idx >= _pool_path_follows.size():
		return
	var pf: PathFollow3D = _pool_path_follows[idx]
	if not is_instance_valid(pf) or not is_instance_valid(mejor_camino) or mejor_camino.curve == null:
		return
	var basis_prev := veh.global_transform.basis
	pf.reparent(mejor_camino, false)
	_pool_caminos_asignados[idx] = mejor_camino
	pf.progress = clampf(target_offset, 0.0, mejor_camino.curve.get_baked_length())
	pf.h_offset = 0.0
	veh.sentido = 1
	veh.position = Vector3(0.0, veh.offset_y, 0.0)
	veh.global_transform.basis = basis_prev
	veh._desfase_lateral_actual = 0.0
	veh._desfase_lateral_objetivo = 0.0
	veh._actualizar_contacto_suelo(1.0)


func _find_player() -> Node3D:
	if is_instance_valid(_cached_player) and _cached_player.is_inside_tree():
		return _cached_player

	# 1. Buscar vehículo activo conducido por el jugador
	if is_inside_tree():
		for v in get_tree().get_nodes_in_group("Vehiculo"):
			if v is Node3D and is_instance_valid(v) and v.get("activo") == true:
				_cached_player = v
				return _cached_player

	# 2. Buscar personaje a pie
	if is_inside_tree():
		for g in ["jugador", "player"]:
			var p = get_tree().get_first_node_in_group(g) as Node3D
			if p and is_instance_valid(p):
				_cached_player = p
				return _cached_player

	# 3. Fallback a la cámara 3D activa
	var cam = get_viewport().get_camera_3d() if get_viewport() else null
	if cam and is_instance_valid(cam):
		var par = cam.get_parent() as Node3D
		if par:
			return par

	return null


# ══════════════════════════════════════════════════════════════════════════════
#  MÉTODOS PÚBLICOS DE COMPATIBILIDAD (GPS Y SPAWN MANUAL)
# ══════════════════════════════════════════════════════════════════════════════

func find_route_lanes(start_pos: Vector3, target_pos: Vector3) -> Array[TrafficLane3D]:
	if not _graph_built:
		build_network_graph()

	var result: Array[TrafficLane3D] = []
	var start_lane = get_nearest_lane(start_pos)
	var target_lane = get_nearest_lane(target_pos)

	if not start_lane or not target_lane or not _lane_to_id.has(start_lane) or not _lane_to_id.has(target_lane):
		return result

	var start_id = _lane_to_id[start_lane]
	var target_id = _lane_to_id[target_lane]

	var id_path = _astar.get_id_path(start_id, target_id)
	for id in id_path:
		if _id_to_lane.has(id):
			result.append(_id_to_lane[id])

	return result


func find_route_points(start_pos: Vector3, target_pos: Vector3) -> PackedVector3Array:
	var route_lanes = find_route_lanes(start_pos, target_pos)
	var points = PackedVector3Array()

	if route_lanes.is_empty():
		return points

	points.append(start_pos)
	for lane in route_lanes:
		var sampled = lane.get_sampled_points(3.0)
		for pt in sampled:
			points.append(pt)
	points.append(target_pos)
	return points


func get_nearest_lane(pos: Vector3) -> TrafficLane3D:
	var best_lane: TrafficLane3D = null
	var best_dist = INF

	for lane in lanes:
		if not lane or not lane.is_active:
			continue
		var l_len = lane.get_total_length()
		var mid = lane.sample_point_at_distance(l_len * 0.5)
		var dist = pos.distance_squared_to(mid)
		if dist < best_dist:
			best_dist = dist
			best_lane = lane

	return best_lane


func spawn_vehicle(vehicle_scene: PackedScene = null, spawn_lane: TrafficLane3D = null) -> Node:
	var escenas := _obtener_escenas_validas()
	if escenas.is_empty() and vehicle_scene == null:
		return null

	var scene_to_use = vehicle_scene if vehicle_scene else escenas.pick_random()
	var instance = scene_to_use.instantiate()

	var target_path: Path3D = spawn_lane
	if target_path == null and not all_paths.is_empty():
		target_path = all_paths.pick_random()

	if target_path != null:
		var pf := PathFollow3D.new()
		pf.loop = true
		pf.rotation_mode = PathFollow3D.ROTATION_NONE
		target_path.add_child(pf)
		pf.progress = randf_range(0.0, target_path.curve.get_baked_length())
		pf.add_child(instance)

		if instance is VehiculoTraficoIA:
			var veh = instance as VehiculoTraficoIA
			veh.position = Vector3(0.0, veh.offset_y, 0.0)
			veh.rotation = Vector3.ZERO
			veh.path_follow = pf
			veh.visible = true
			veh.set_physics_process(true)
			veh._actualizar_contacto_suelo(1.0)
	else:
		add_child(instance)

	return instance
