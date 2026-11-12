extends Node3D
class_name GPSRutaLinea

# ═══════════════════════════════════════════════════════════════════════
# GPSRutaLinea.gd — Solo calcula la ruta GPS via NavigationServer3D
# Los visuales (linea, marcador del jugador) se dibujan en 2D dentro
# del GPS del celular por CelularUI.gd — NO hay objetos 3D visibles aqui.
# ═══════════════════════════════════════════════════════════════════════

var active: bool = false
var target_position: Vector3 = Vector3.ZERO
var player: CharacterBody3D = null

# Optimización: Temporizador para no recalcular la ruta en cada fotograma
var path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.3 # 3 veces por segundo
var last_path: PackedVector3Array = PackedVector3Array()

@export var vertical_offset: float = 0.18

func _ready() -> void:
	# Buscar jugador
	player = get_parent() as CharacterBody3D
	if not player:
		player = get_tree().get_first_node_in_group("jugador")

# ─── API publica ──────────────────────────────────────────────────────
func set_destination(dest: Vector3) -> void:
	target_position = dest
	active  = true

func clear_route() -> void:
	active = false
	last_path = PackedVector3Array()

# ─── Physics process — solo calcula el path de navegacion ─────────────
func _physics_process(delta: float) -> void:
	if not player or not active:
		return

	var world_3d = player.get_world_3d()
	if not world_3d:
		return

	var map_rid = world_3d.navigation_map
	if not map_rid.is_valid():
		return

	# Posicion de inicio para el calculo del path
	var start_pos = player.global_position
	if player.get("_conduciendo") == true and is_instance_valid(player.get("_vehiculo_actual")):
		var veh = player.get("_vehiculo_actual")
		if veh is Node3D:
			start_pos = veh.global_position

	path_update_timer += delta

	if path_update_timer >= PATH_UPDATE_INTERVAL or last_path.is_empty():
		path_update_timer = 0.0
		last_path = NavigationServer3D.map_get_path(
			map_rid,
			start_pos,
			target_position,
			true
		)
