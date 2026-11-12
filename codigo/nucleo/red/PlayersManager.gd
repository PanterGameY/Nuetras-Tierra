extends Node

# ═══════════════════════════════════════════════════════════════════════
# PlayersManager.gd — Autoload de Gestión de Jugadores en Partida (Máx 5)
# ═══════════════════════════════════════════════════════════════════════

signal lista_jugadores_cambiada(jugadores: Dictionary)

const MAX_JUGADORES_PARTIDA: int = 5

var player_name: String = "Conductor"
var jugadores_conectados: Dictionary = {} # peer_id (int) -> { "nombre": String, "slot": int, "es_host": bool }

func _ready() -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and "nombre_usuario" in datos and String(datos.nombre_usuario).strip_edges() != "":
		player_name = String(datos.nombre_usuario).strip_edges()

func obtener_nombre_local() -> String:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and "nombre_usuario" in datos and String(datos.nombre_usuario).strip_edges() != "":
		player_name = String(datos.nombre_usuario).strip_edges()
	return player_name

func registrar_jugador(peer_id: int, nombre: String, slot: int = -1, es_host: bool = false) -> void:
	if jugadores_conectados.size() >= MAX_JUGADORES_PARTIDA and not jugadores_conectados.has(peer_id):
		return
	var slot_asignado = slot if slot >= 0 else _obtener_siguiente_slot_libre()
	jugadores_conectados[peer_id] = {
		"nombre": nombre if nombre.strip_edges() != "" else ("JUGADOR " + str(peer_id)),
		"slot": slot_asignado,
		"es_host": es_host or (peer_id == 1)
	}
	lista_jugadores_cambiada.emit(jugadores_conectados)

func eliminar_jugador(peer_id: int) -> void:
	if jugadores_conectados.has(peer_id):
		jugadores_conectados.erase(peer_id)
		lista_jugadores_cambiada.emit(jugadores_conectados)

func limpiar() -> void:
	jugadores_conectados.clear()
	lista_jugadores_cambiada.emit(jugadores_conectados)

func obtener_nombre(peer_id: int) -> String:
	if jugadores_conectados.has(peer_id):
		return String(jugadores_conectados[peer_id].get("nombre", "JUGADOR " + str(peer_id)))
	var red = get_node_or_null("/root/RedManager")
	if red and "nombres_jugadores" in red and red.nombres_jugadores.has(peer_id):
		return String(red.nombres_jugadores[peer_id])
	return "JUGADOR " + str(peer_id)

func obtener_slot(peer_id: int) -> int:
	if jugadores_conectados.has(peer_id):
		return int(jugadores_conectados[peer_id].get("slot", 0))
	return 0

func _obtener_siguiente_slot_libre() -> int:
	var usados: Array[int] = []
	for info in jugadores_conectados.values():
		usados.append(int(info.get("slot", 0)))
	for i in range(MAX_JUGADORES_PARTIDA):
		if not usados.has(i):
			return i
	return 0
