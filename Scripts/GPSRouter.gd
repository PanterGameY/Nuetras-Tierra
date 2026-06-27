@tool
extends Node
class_name GPSRouter
# ══════════════════════════════════════════════════════════════════════════════
#  GPSRouter.gd  —  Router direccional con waypoints editables en el Inspector
#
#  INSTRUCCIONES:
#  1. Selecciona este nodo en la escena → Inspector → sección "Red Vial".
#  2. En "Waypoint Positions" agrega posiciones Vector3 de tus intersecciones.
#  3. En "Connections" agrega Vector2i(indice_origen, indice_destino).
#     Ejemplo: Vector2i(0, 1) → solo se puede ir del waypoint 0 al 1.
#     Para doble via necesitas AMBAS: Vector2i(0,1) Y Vector2i(1,0).
#  4. Activa "Show Debug Gizmos" para ver los puntos en el editor.
#
#  TRUCO PARA ENCONTRAR COORDENADAS:
#  Selecciona cualquier objeto en la escena → Inspector → Node3D → Position
#  Esas son las coordenadas que debes poner en Waypoint Positions.
# ══════════════════════════════════════════════════════════════════════════════

signal route_ready(path: PackedVector3Array)
signal route_failed()

## Posiciones 3D de cada interseccion / punto clave de la ciudad.
## El indice en este array es el ID del waypoint (0, 1, 2...).
@export var waypoint_positions: Array[Vector3] = [
	Vector3(  0.0, 0.0,  120.0),   # 0  norte_1
	Vector3(  0.0, 0.0,   80.0),   # 1  norte_2
	Vector3(  0.0, 0.0,   40.0),   # 2  cruce_centro_n
	Vector3(  0.0, 1.5,  -60.0),   # 3  centro
	Vector3(  0.0, 0.0, -100.0),   # 4  cruce_centro_s
	Vector3(  0.0, 0.0, -150.0),   # 5  sur_1
	Vector3(-120.0,0.0,    0.0),   # 6  oeste_1
	Vector3( -60.0,0.0,    0.0),   # 7  cruce_o  (gasolinera lado)
	Vector3(  60.0,0.0,    0.0),   # 8  cruce_e
	Vector3( 120.0,0.0,    0.0),   # 9  este_1
	Vector3(  0.0, 0.0,    0.0),   # 10 interseccion central
	Vector3(-25.0, 0.0,  -10.0),   # 11 taller_rines
	Vector3( 45.0, 0.0,   20.0),   # 12 zona_carga
	Vector3(-80.0, 0.0,   45.0),   # 13 gasolinera
	Vector3( 30.0, 0.0,  -90.0),   # 14 policia
	Vector3(-50.0, 0.0,  -35.0),   # 15 taller_mecanico
	Vector3( 12.0, 0.0,   80.0),   # 16 mercado
]

## Conexiones entre waypoints.
## Cada Vector2i(A, B) significa que se puede viajar del waypoint A al B.
## Para doble via agrega AMBAS direcciones: Vector2i(A,B) y Vector2i(B,A).
## Para una sola via agrega solo Vector2i(A,B).
@export var connections: Array[Vector2i] = [
	# Eje Norte-Sur (doble via → pares de conexiones)
	Vector2i(0, 1),  Vector2i(1, 0),
	Vector2i(1, 2),  Vector2i(2, 1),
	Vector2i(2,10),  Vector2i(10,2),
	Vector2i(10,3),  Vector2i(3,10),
	Vector2i(3, 4),  Vector2i(4, 3),
	Vector2i(4, 5),  Vector2i(5, 4),

	# Eje Este-Oeste (doble via)
	Vector2i(6,13),  Vector2i(13,6),
	Vector2i(13,7),  Vector2i(7,13),
	Vector2i(7,10),  Vector2i(10,7),
	Vector2i(10,8),  Vector2i(8,10),
	Vector2i(8,12),  Vector2i(12,8),
	Vector2i(12,9),  Vector2i(9,12),

	# Conexiones a destinos (doble via)
	Vector2i(10,11), Vector2i(11,10),
	Vector2i(10,16), Vector2i(16,10),
	Vector2i(3,14),  Vector2i(14,3),
	Vector2i(4,15),  Vector2i(15,4),
	Vector2i(7,15),  Vector2i(15,7),
	Vector2i(1,16),  Vector2i(16,1),

	# EJEMPLO UNA SOLA VIA (solo de 0 hacia 16, no al reves):
	# Vector2i(0, 16),
]

## Mostrar esferas de waypoints y lineas de conexion en el editor 3D.
@export var show_debug_gizmos: bool = true

## Color de los waypoints en el editor.
@export var gizmo_waypoint_color: Color = Color(0.0, 1.0, 0.4, 0.9)

## Color de las conexiones en el editor.
@export var gizmo_connection_color: Color = Color(1.0, 0.8, 0.0, 0.7)

# ─── AStar interno ───────────────────────────────────────────────────────────
var _astar: AStar3D = AStar3D.new()
var _built: bool = false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_graph()

func _build_graph() -> void:
	_astar = AStar3D.new()
	_built = false

	# Agregar todos los puntos
	for i in range(waypoint_positions.size()):
		_astar.add_point(i, waypoint_positions[i])

	# Agregar conexiones dirigidas
	for conn in connections:
		var a: int = conn.x
		var b: int = conn.y
		if a < 0 or a >= waypoint_positions.size():
			push_warning("[GPSRouter] Conexion con indice invalido: " + str(conn))
			continue
		if b < 0 or b >= waypoint_positions.size():
			push_warning("[GPSRouter] Conexion con indice invalido: " + str(conn))
			continue
		# AStar3D conecta de forma bidireccional por defecto.
		# Usamos bidirectional=false y agregamos solo la direccion deseada.
		if not _astar.are_points_connected(a, b):
			_astar.connect_points(a, b, false)
		# Si ya existe la conexion en sentido contrario, la doble via ya esta
		# cubierta. Si no, solo existira A→B.

	_built = true
	print("[GPSRouter] Grafo construido: ", waypoint_positions.size(),
		" waypoints, ", connections.size(), " conexiones.")

# ─────────────────────────────────────────────────────────────────────────────
#  API PUBLICA
# ─────────────────────────────────────────────────────────────────────────────

## Devuelve la ruta desde [from_pos] hasta [to_pos] respetando sentidos viales.
func get_route(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	if not _built:
		_build_graph()

	var id_start := _nearest_waypoint(from_pos)
	var id_end   := _nearest_waypoint(to_pos)

	if id_start == -1 or id_end == -1:
		push_warning("[GPSRouter] No hay waypoints definidos.")
		route_failed.emit()
		return PackedVector3Array()

	var id_path: PackedInt64Array = _astar.get_id_path(id_start, id_end)

	if id_path.is_empty():
		push_warning("[GPSRouter] Sin ruta entre " + str(id_start) + " y " + str(id_end))
		route_failed.emit()
		return PackedVector3Array()

	var result := PackedVector3Array()
	result.append(from_pos)
	for id in id_path:
		result.append(waypoint_positions[id])
	result.append(to_pos)

	route_ready.emit(result)
	return result

func _nearest_waypoint(pos: Vector3) -> int:
	var best_id   := -1
	var best_dist := INF
	for i in range(waypoint_positions.size()):
		var d = pos.distance_squared_to(waypoint_positions[i])
		if d < best_dist:
			best_dist = d
			best_id   = i
	return best_id

# ─────────────────────────────────────────────────────────────────────────────
#  GIZMOS DE EDITOR  (visibles cuando show_debug_gizmos = true)
# ─────────────────────────────────────────────────────────────────────────────
func _get_configuration_warnings() -> PackedStringArray:
	var warns := PackedStringArray()
	if waypoint_positions.is_empty():
		warns.append("No hay waypoints definidos. Agrega posiciones en 'Waypoint Positions'.")
	if connections.is_empty():
		warns.append("No hay conexiones definidas. Agrega pares en 'Connections'.")
	return warns
