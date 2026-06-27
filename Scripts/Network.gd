extends Node

# ═══════════════════════════════════════════════════════════════════════
# Network.gd — Singleton de Conectividad de Red ENet Automatizado
# ═══════════════════════════════════════════════════════════════════════

const VPS_IP: String = "2.25.71.102"
const BASE_PORT: int = 10000
const MAX_PORT_OFFSET: int = 5000

var enet_peer: ENetMultiplayerPeer

# Calcula un puerto dinámico único de 5 dígitos basado en el código numérico de la sala
func _calcular_puerto(room_code: String) -> int:
	var num_code = int(room_code)
	if num_code <= 0:
		# Si el código no es numérico, generar uno con un hash simple
		num_code = room_code.hash()
	
	# Mapear el puerto en el rango de 10000 a 15000
	return BASE_PORT + (abs(num_code) % MAX_PORT_OFFSET)

# Inicia un servidor ENet en la máquina actual (local o VPS dedicado) usando el código de sala
func start_server_for_room(room_code: String) -> void:
	var port = _calcular_puerto(room_code)
	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(port, 10) # Máximo 10 jugadores
	if error != OK:
		print("[Network] Error al iniciar el servidor en el puerto ", port, ": ", error)
		return
	
	multiplayer.multiplayer_peer = enet_peer
	print("[Network] Servidor de la Sala (", room_code, ") corriendo en el puerto: ", port)

# Conecta al cliente de forma transparente a la IP de la VPS en el puerto de la sala
func start_client_for_room(room_code: String) -> void:
	var port = _calcular_puerto(room_code)
	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_client(VPS_IP, port)
	if error != OK:
		print("[Network] Error al intentar conectar con la VPS en ", VPS_IP, ":", port, ". Error: ", error)
		return
	
	multiplayer.multiplayer_peer = enet_peer
	print("[Network] Intentando conectar de forma automática a la VPS en: ", VPS_IP, ":", port)

func get_ip_address() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and ip.split(".").size() > 1 and int(ip.split(".")[1]) >= 16 and int(ip.split(".")[1]) <= 31):
			return ip
	return "127.0.0.1"
