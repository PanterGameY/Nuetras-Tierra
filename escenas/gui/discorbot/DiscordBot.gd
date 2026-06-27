extends Node

# --- CONFIGURACIÓN ---
const BOT_TOKEN = "MTQ4NDkxODczNzA5MzAwNTQ5NA.GTegnN.F6IU_v4ztK6GXaLtztixVSTxKeAkNqXjBOIFMA"
const CANAL_ID = "1480375010945270013"

var http_request: HTTPRequest
var usuarios_online: int = 0

func _ready() -> void:
	# Creamos el nodo HTTP dinámicamente para evitar errores de escena
	http_request = HTTPRequest.new()
	add_child(http_request)
	if not http_request.request_completed.is_connected(_on_request_completed):
		http_request.request_completed.connect(_on_request_completed)

func enviar_anuncio_pro(nombre_jugador: String) -> void:
	usuarios_online += 1
	var url = "https://discord.com/api/v10/channels/%s/messages" % CANAL_ID
	
	# --- ESTRUCTURA DEL EMBED ULTRA-LLAMATIVO ---
	var embed = {
		"title": "🚛 NUESTRA TIERRA | SYSTEM LOG",
		"description": "Se ha validado el ingreso de un nuevo jugador al simulador.",
		"color": 2067276, # Verde esmeralda (representando Online)
		"fields": [
			{
				"name": "📡 ESTADO DEL JUEGO",
				"value": "🟢 **ONLINE**",
				"inline": true
			},
			{
				"name": "👤 IDENTIDAD DEL OPERADOR",
				"value": "```fix\n" + nombre_jugador + "\n```",
				"inline": false
			}
		],
		"footer": {
			"text": "Nuestra Tierra Job Simulator • PanterStudio",
		},
		"timestamp": Time.get_datetime_string_from_system(false, true)
	}

	var cuerpo = JSON.stringify({"embeds": [embed]})
	var cabeceras = [
		"Authorization: Bot " + BOT_TOKEN,
		"Content-Type: application/json",
		"User-Agent: GodotEngine/4.x"
	]

	http_request.request(url, cabeceras, HTTPClient.METHOD_POST, cuerpo)

func _on_request_completed(_result, response_code, _headers, _body) -> void:
	if response_code in [200, 201]:
		print("[DiscordBot] Mensaje enviado correctamente.")
	else:
		print("[DiscordBot] Error de Discord. Código: ", response_code)