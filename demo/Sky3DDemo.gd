extends Node3D

# ═══════════════════════════════════════════════════════════════════════
# Sky3DDemo.gd — Controlador multijugador de la escena principal (Mundo)
# Maneja el spawn e instanciación de jugadores conectados por red.
# ═══════════════════════════════════════════════════════════════════════

const JUGADOR_SCENE = preload("res://modelos3d/personajes/Jugador/Jugador.tscn")

@onready var jugador_default: CharacterBody3D = $Jugador2

func _ready() -> void:
	if multiplayer.has_multiplayer_peer():
		# Ocultar o eliminar el jugador por defecto/single-player de la escena
		if jugador_default:
			jugador_default.queue_free()
		
		# Conectar señales para spawnear clientes que se unan o salgan
		multiplayer.peer_connected.connect(_spawn_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		
		# Instanciar nuestro propio jugador local en el servidor/cliente
		_spawn_player(multiplayer.get_unique_id())
		
		# Si somos cliente, solicitar al servidor spawnear los jugadores que ya estaban conectados
		if not multiplayer.is_server():
			print("[Sky3DDemo] Cliente listo en la red.")
	else:
		print("[Sky3DDemo] Modo Singleplayer activo (sin red).")

func _spawn_player(id: int) -> void:
	# Prevenir duplicados
	if has_node(str(id)):
		return
		
	var player = JUGADOR_SCENE.instantiate()
	player.name = str(id)
	
	# Asignar la autoridad de red de este nodo del personaje
	player.set_multiplayer_authority(id)
	
	# Posición de spawn inicial predeterminada (cerca de la posición original de Jugador2)
	player.position = Vector3(-57, 3, 975) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
	
	add_child(player)
	print("[Sky3DDemo] Jugador instanciado con ID: ", id)

func _remove_player(id: int) -> void:
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
		print("[Sky3DDemo] Jugador eliminado con ID: ", id)
