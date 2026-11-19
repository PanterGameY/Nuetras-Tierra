extends Node

## SupabaseManager.gd — Cliente oficial de Supabase Auth (OAuth PKCE Google & Discord) y PostgREST (`public.perfiles`)

signal auth_exito(usuario: Dictionary)
signal auth_error(mensaje: String)
signal sesion_refrescada(exito: bool)
signal perfil_cargado(perfil: Dictionary)
signal perfil_guardado(ok: bool)

const SUPABASE_URL := "https://hndlwmvezampajbmpqae.supabase.co"
const SUPABASE_KEY := "sb_publishable_Cw95N8YDQNhc4zDGTE__Yg_C_Xj0IP4"
const LOCAL_CALLBACK_PORT := 54321
const PC_REDIRECT_URL := "http://127.0.0.1:54321/callback"
const MOBILE_REDIRECT_URL := "nuestratierra://auth/callback"
const SESSION_PATH := "user://supabase_session.cfg"

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var user_email: String = ""
var user_provider: String = ""
var user_metadata: Dictionary = {}

var _pkce_verifier: String = ""
var _oauth_provider_pendiente: String = ""
var _tcp_server: TCPServer = null
var _tcp_clients: Array[StreamPeerTCP] = []
var _http_auth: HTTPRequest = null
var _http_rest: HTTPRequest = null
var sesion_cerrada_manualmente: bool = false
var _sincronizando_desde_nube: bool = false
var _sync_pendiente: bool = false

func _ready() -> void:
	_http_auth = HTTPRequest.new()
	_http_auth.name = "SupabaseAuthHTTP"
	add_child(_http_auth)

	_http_rest = HTTPRequest.new()
	_http_rest.name = "SupabaseRestHTTP"
	add_child(_http_rest)

	_cargar_sesion_local()

func _process(_delta: float) -> void:
	if _tcp_server == null or not _tcp_server.is_listening():
		return

	while _tcp_server.is_connection_available():
		var cli := _tcp_server.take_connection()
		if cli:
			_tcp_clients.append(cli)

	for i in range(_tcp_clients.size() - 1, -1, -1):
		var cli := _tcp_clients[i]
		cli.poll()
		if cli.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var avail := cli.get_available_bytes()
			if avail > 0:
				var req_str := cli.get_utf8_string(avail)
				_tcp_clients.remove_at(i)
				_manejar_http_callback_local(cli, req_str)
				if _tcp_server == null:
					return
		elif cli.get_status() != StreamPeerTCP.STATUS_CONNECTING:
			_tcp_clients.remove_at(i)

func esta_autenticado() -> bool:
	return not access_token.is_empty() and not user_id.is_empty()

# ── OAUTH PKCE (GOOGLE & DISCORD) ─────────────────────────────────────────

func iniciar_sesion_oauth(proveedor: String) -> void:
	var prov := proveedor.strip_edges().to_lower()
	if prov != "google" and prov != "discord":
		auth_error.emit("Proveedor OAuth no soportado: " + prov)
		return

	_oauth_provider_pendiente = prov
	_pkce_verifier = _generar_pkce_verifier()
	var challenge := _generar_pkce_challenge(_pkce_verifier)

	var redirect_uri := MOBILE_REDIRECT_URL if _es_movil() else PC_REDIRECT_URL
	if not _es_movil():
		_iniciar_servidor_local()

	var url := "%s/auth/v1/authorize?provider=%s&redirect_to=%s&code_challenge=%s&code_challenge_method=s256" % [
		SUPABASE_URL,
		prov.uri_encode(),
		redirect_uri.uri_encode(),
		challenge.uri_encode()
	]
	if prov == "google":
		url += "&query_params=" + "prompt=select_account".uri_encode()

	var err := OS.shell_open(url)
	if err != OK:
		_detener_servidor_local()
		auth_error.emit("No se pudo abrir el navegador para iniciar sesión con %s." % prov.capitalize())

func procesar_callback_url(callback_url: String) -> void:
	if callback_url.is_empty():
		return
	var code := _extraer_parametro_url(callback_url, "code")
	if not code.is_empty():
		_intercambiar_codigo_pkce(code)
		return
	var err_desc := _extraer_parametro_url(callback_url, "error_description")
	if not err_desc.is_empty():
		auth_error.emit(err_desc.uri_decode())
		return
	var tok := _extraer_parametro_url(callback_url, "access_token")
	if not tok.is_empty():
		access_token = tok
		refresh_token = _extraer_parametro_url(callback_url, "refresh_token")
		_obtener_usuario_actual()

func cerrar_sesion() -> void:
	sesion_cerrada_manualmente = true
	access_token = ""
	refresh_token = ""
	user_id = ""
	user_email = ""
	user_provider = ""
	user_metadata = {}
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	if has_node("/root/DatosUsuario"):
		var du := get_node("/root/DatosUsuario")
		du.id_usuario = ""
		du.firebase_uid = ""
		du.id_publico_numero = 0
		du.email_usuario = ""
		du.discord_username = ""
		du.proveedor_auth = ""
		du.save_local()

func cancelar_oauth_pendiente() -> void:
	_oauth_provider_pendiente = ""
	_pkce_verifier = ""
	_detener_servidor_local()

func refrescar_sesion() -> void:
	if refresh_token.is_empty():
		sesion_refrescada.emit(false)
		return
	var url := "%s/auth/v1/token?grant_type=refresh_token" % SUPABASE_URL
	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]
	var body := JSON.stringify({"refresh_token": refresh_token})
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if status >= 200 and status < 300 and json is Dictionary and json.has("access_token"):
			sesion_cerrada_manualmente = false
			_aplicar_respuesta_sesion(json)
			sesion_refrescada.emit(true)
		else:
			if status == 400 or status == 401:
				cerrar_sesion()
			sesion_refrescada.emit(false)
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		sesion_refrescada.emit(false)

func _es_movil() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

func _iniciar_servidor_local() -> void:
	_detener_servidor_local()
	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(LOCAL_CALLBACK_PORT, "127.0.0.1")
	if err != OK:
		push_warning("[SupabaseManager] No se pudo abrir puerto local %d (err=%d)" % [LOCAL_CALLBACK_PORT, err])

func _detener_servidor_local() -> void:
	for c in _tcp_clients:
		if c:
			c.disconnect_from_host()
	_tcp_clients.clear()
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null

func _manejar_http_callback_local(cli: StreamPeerTCP, req_str: String) -> void:
	var primera_linea := req_str.split("\n")[0] if not req_str.is_empty() else ""
	var partes := primera_linea.split(" ")
	var ruta := partes[1] if partes.size() >= 2 else "/"

	# Ignorar peticiones del favicon
	if ruta.begins_with("/favicon"):
		cli.put_data("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n".to_utf8_buffer())
		cli.disconnect_from_host()
		return

	var code := _extraer_parametro_url(ruta, "code")
	var err_msg := _extraer_parametro_url(ruta, "error_description")

	var html := ""
	if not code.is_empty():
		html = "<html><body style='background:#0f1114;color:#e0e5ec;font-family:sans-serif;text-align:center;padding:60px'><h2>&#x2705; Sesi&oacute;n iniciada en Nuestra Tierra</h2><p>Ya puedes cerrar esta pesta&ntilde;a y volver al juego.</p><script>setTimeout(()=>window.close(),1200)</script></body></html>"
	else:
		html = "<html><body style='background:#0f1114;color:#e0706c;font-family:sans-serif;text-align:center;padding:60px'><h2>Error al iniciar sesi&oacute;n</h2><p>Puedes cerrar esta pesta&ntilde;a e intentar de nuevo.</p></body></html>"

	var body_bytes := html.to_utf8_buffer()
	var resp := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body_bytes.size()
	cli.put_data(resp.to_utf8_buffer() + body_bytes)
	cli.disconnect_from_host()
	_detener_servidor_local()

	if not code.is_empty():
		_intercambiar_codigo_pkce(code)
	elif not err_msg.is_empty():
		auth_error.emit(err_msg.uri_decode())
	else:
		auth_error.emit("No se recibió el código de autorización de Supabase.")

func _intercambiar_codigo_pkce(code: String) -> void:
	var url := "%s/auth/v1/token?grant_type=pkce" % SUPABASE_URL
	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]
	var body := JSON.stringify({
		"auth_code": code,
		"code_verifier": _pkce_verifier
	})

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		var txt := resp_body.get_string_from_utf8()
		var json = JSON.parse_string(txt)
		if status >= 200 and status < 300 and json is Dictionary and json.has("access_token"):
			print("[SupabaseManager] Sesión PKCE iniciada correctamente.")
			_aplicar_respuesta_sesion(json)
		else:
			var msg := "Error de autenticación (%d)" % status
			if json is Dictionary:
				msg = str(json.get("error_description", json.get("msg", json.get("error", msg))))
			push_warning("[SupabaseManager] Error PKCE (%d): %s" % [status, txt])
			auth_error.emit(msg)
	)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		auth_error.emit("Error de red al intercambiar token PKCE.")

func _obtener_usuario_actual() -> void:
	var url := "%s/auth/v1/user" % SUPABASE_URL
	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token
	]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if status >= 200 and status < 300 and json is Dictionary and json.has("id"):
			_aplicar_datos_usuario(json)
		else:
			auth_error.emit("No se pudo obtener el usuario de Supabase.")
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _aplicar_respuesta_sesion(json: Dictionary) -> void:
	access_token = str(json.get("access_token", ""))
	refresh_token = str(json.get("refresh_token", ""))
	var usr = json.get("user", {})
	if usr is Dictionary and usr.has("id"):
		_aplicar_datos_usuario(usr)
	else:
		_obtener_usuario_actual()

func _aplicar_datos_usuario(usr: Dictionary) -> void:
	user_id = str(usr.get("id", ""))
	user_email = str(usr.get("email", ""))
	var app_meta = usr.get("app_metadata", {})
	if app_meta is Dictionary:
		user_provider = str(app_meta.get("provider", _oauth_provider_pendiente))
	if user_provider.is_empty():
		user_provider = _oauth_provider_pendiente
	var meta = usr.get("user_metadata", {})
	user_metadata = meta if meta is Dictionary else {}
	_guardar_sesion_local()

	var nombre := str(user_metadata.get("full_name", user_metadata.get("name", user_metadata.get("preferred_username", ""))))
	if nombre.is_empty():
		nombre = user_email.split("@")[0] if not user_email.is_empty() else "Conductor"

	var discord_handle := ""
	if user_provider == "discord":
		var claims = user_metadata.get("custom_claims", {})
		if claims is Dictionary:
			discord_handle = str(claims.get("global_name", claims.get("username", "")))
		if discord_handle.is_empty():
			discord_handle = str(user_metadata.get("preferred_username", user_metadata.get("name", user_metadata.get("full_name", ""))))

	var avatar := str(user_metadata.get("avatar_url", user_metadata.get("picture", "")))
	if not avatar.is_empty():
		descargar_y_aplicar_avatar(avatar)

	# Sincronizar con DatosUsuario (manteniendo nombre editable y correo/Discord debajo)
	if has_node("/root/DatosUsuario"):
		var du := get_node("/root/DatosUsuario")
		var uid_anterior := str(du.firebase_uid)
		var cambio_cuenta: bool = (not uid_anterior.is_empty() and uid_anterior != user_id)
		if cambio_cuenta:
			du.dinero = 0.0
			du.esmeraldas = 0
			du.experiencia = 0
			du.nivel = 0
			du.vehiculos_comprados = {}
			du.vehiculos_personalizados = {}
			du.remolques_activos = {}
			du.id_usuario = ""
			du.id_publico_numero = 0
		du.tutorial_completado = true
		du.firebase_uid = user_id
		du.email_usuario = user_email
		if not discord_handle.is_empty():
			du.discord_username = discord_handle
		du.proveedor_auth = "supabase_" + user_provider
		var nombre_actual := str(du.nombre_usuario).strip_edges()
		if nombre_actual.is_empty() or nombre_actual == "Conductor":
			du.nombre_usuario = nombre
		if du.has_method("needs_public_id_assignment") and du.needs_public_id_assignment():
			du.set_public_id_number(1, false, false)
		_sincronizando_desde_nube = true
		du.save_local()
		_sincronizando_desde_nube = false

	auth_exito.emit({
		"id": user_id,
		"email": user_email,
		"nombre": nombre,
		"avatar_url": avatar,
		"provider": user_provider
	})
	obtener_perfil()

# ── BASE DE DATOS POSTGREST (public.perfiles) ─────────────────────────────

func obtener_perfil() -> void:
	if not esta_autenticado():
		return
	var url := "%s/rest/v1/perfiles?id=eq.%s&select=*" % [SUPABASE_URL, user_id.uri_encode()]
	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token
	]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		var json = JSON.parse_string(resp_body.get_string_from_utf8())
		if status >= 200 and status < 300 and json is Array and json.size() > 0:
			var p: Dictionary = json[0]
			_sincronizar_perfil_a_datos_usuario(p)
			perfil_cargado.emit(p)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func programar_guardado_perfil() -> void:
	if _sincronizando_desde_nube or not esta_autenticado():
		return
	if _sync_pendiente:
		return
	_sync_pendiente = true
	var tree := get_tree()
	if tree:
		await tree.create_timer(2.0).timeout
	_sync_pendiente = false
	if esta_autenticado():
		guardar_perfil()

func guardar_perfil(campos: Dictionary = {}) -> void:
	if not esta_autenticado():
		return
	var payload := campos.duplicate()
	if payload.is_empty() and has_node("/root/DatosUsuario"):
		var du := get_node("/root/DatosUsuario")
		payload = {
			"nombre": du.nombre_usuario,
			"correo": du.email_usuario,
			"discord_usuario": du.discord_username,
			"proveedor": du.proveedor_auth,
			"monedas": int(du.dinero),
			"esmeraldas": int(du.esmeraldas),
			"nivel": int(du.nivel),
			"experiencia": int(du.experiencia),
			"pase_elite_activo": bool(du.pase_elite_activo),
			"pase_elite_desde": str(du.pase_elite_desde),
			"pase_elite_ultimo_reclamo": str(du.pase_elite_ultimo_reclamo),
			"pase_elite_dias_reclamados": int(du.pase_elite_dias_reclamados),
			"vehiculos_comprados": du.vehiculos_comprados,
			"vehiculos_personalizados": du.vehiculos_personalizados,
			"licencias": {
				"automovil": bool(du.licencia_automovil),
				"camion": bool(du.licencia_camion),
				"carga_delicada": bool(du.licencia_carga_delicada),
				"carga_sobredimensionada": bool(du.licencia_carga_sobredimensionada),
				"c1": bool(du.licencia_c1),
				"c2": bool(du.licencia_c2),
				"c3": bool(du.licencia_c3)
			}
		}
	payload["actualizado_en"] = Time.get_datetime_string_from_system(true)

	var url := "%s/rest/v1/perfiles?id=eq.%s" % [SUPABASE_URL, user_id.uri_encode()]
	var headers := [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=representation"
	]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, _resp_body: PackedByteArray):
		http.queue_free()
		perfil_guardado.emit(status >= 200 and status < 300)
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))

func _sincronizar_perfil_a_datos_usuario(p: Dictionary) -> void:
	if not has_node("/root/DatosUsuario"):
		return
	_sincronizando_desde_nube = true
	var du := get_node("/root/DatosUsuario")
	var num_id := int(p.get("numero_id", p.get("id_numerico", p.get("public_id_number", 0))))
	if num_id > 0 and du.has_method("set_public_id_number"):
		du.set_public_id_number(num_id, false, false)
	if p.has("nombre") and p["nombre"] != null and not str(p["nombre"]).is_empty():
		du.nombre_usuario = str(p["nombre"])
	if p.has("correo") and p["correo"] != null and not str(p["correo"]).is_empty():
		du.email_usuario = str(p["correo"])
	if p.has("discord_usuario") and p["discord_usuario"] != null and not str(p["discord_usuario"]).is_empty():
		du.discord_username = str(p["discord_usuario"])
	if p.has("monedas") and p["monedas"] != null:
		du.dinero = float(p["monedas"])
	if p.has("esmeraldas") and p["esmeraldas"] != null:
		du.esmeraldas = int(p["esmeraldas"])
	if p.has("nivel") and p["nivel"] != null:
		du.nivel = int(p["nivel"])
	if p.has("experiencia") and p["experiencia"] != null:
		du.experiencia = int(p["experiencia"])
	if p.has("pase_elite_activo") and p["pase_elite_activo"] != null:
		du.pase_elite_activo = bool(p["pase_elite_activo"])
	if p.has("pase_elite_desde") and p["pase_elite_desde"] != null:
		du.pase_elite_desde = str(p["pase_elite_desde"])
	if p.has("pase_elite_ultimo_reclamo") and p["pase_elite_ultimo_reclamo"] != null:
		du.pase_elite_ultimo_reclamo = str(p["pase_elite_ultimo_reclamo"])
	if p.has("pase_elite_dias_reclamados") and p["pase_elite_dias_reclamados"] != null:
		du.pase_elite_dias_reclamados = int(p["pase_elite_dias_reclamados"])
	if p.has("vehiculos_comprados") and p["vehiculos_comprados"] is Dictionary:
		du.vehiculos_comprados = p["vehiculos_comprados"]
	if p.has("vehiculos_personalizados") and p["vehiculos_personalizados"] is Dictionary:
		du.vehiculos_personalizados = p["vehiculos_personalizados"]
	if p.has("licencias") and p["licencias"] is Dictionary:
		var lic: Dictionary = p["licencias"]
		du.licencia_automovil = bool(lic.get("automovil", du.licencia_automovil))
		du.licencia_camion = bool(lic.get("camion", du.licencia_camion))
		du.licencia_carga_delicada = bool(lic.get("carga_delicada", du.licencia_carga_delicada))
		du.licencia_carga_sobredimensionada = bool(lic.get("carga_sobredimensionada", du.licencia_carga_sobredimensionada))
		du.licencia_c1 = bool(lic.get("c1", du.licencia_c1))
		du.licencia_c2 = bool(lic.get("c2", du.licencia_c2))
		du.licencia_c3 = bool(lic.get("c3", du.licencia_c3))
	if p.has("avatar_url") and p["avatar_url"] != null and not str(p["avatar_url"]).is_empty() and du.avatar_path.is_empty():
		descargar_y_aplicar_avatar(str(p["avatar_url"]))
	du.save_local()
	_sincronizando_desde_nube = false

func descargar_y_aplicar_avatar(url_avatar: String) -> void:
	var url_limpia := url_avatar.strip_edges()
	if url_limpia.is_empty():
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if status < 200 or status >= 300 or body.is_empty():
			return
		var img := _decodificar_imagen_avatar(body)
		if img == null or img.is_empty():
			return
		var local_path := "user://avatar_oauth.png"
		img.save_png(local_path)
		var tex := ImageTexture.create_from_image(img)
		if has_node("/root/DatosUsuario"):
			var du := get_node("/root/DatosUsuario")
			du.avatar_path = local_path
			if du.has_method("set_avatar_texture"):
				du.set_avatar_texture(tex, false)
			else:
				du.avatar_texture = tex
				if du.has_signal("avatar_cambiada"):
					du.avatar_cambiada.emit(tex)
			if du.has_method("save_local"):
				du.save_local()
	)
	http.request(url_limpia, [], HTTPClient.METHOD_GET)

func _decodificar_imagen_avatar(body: PackedByteArray) -> Image:
	var img := Image.new()
	if body.size() >= 8 and body[0] == 0x89 and body[1] == 0x50 and body[2] == 0x4E and body[3] == 0x47:
		if img.load_png_from_buffer(body) == OK:
			return img
	if body.size() >= 3 and body[0] == 0xFF and body[1] == 0xD8 and body[2] == 0xFF:
		if img.load_jpg_from_buffer(body) == OK:
			return img
	if body.size() >= 12 and body.slice(0, 4).get_string_from_ascii() == "RIFF" and body.slice(8, 12).get_string_from_ascii() == "WEBP":
		if img.load_webp_from_buffer(body) == OK:
			return img
	if img.load_png_from_buffer(body) == OK:
		return img
	if img.load_webp_from_buffer(body) == OK:
		return img
	if img.load_jpg_from_buffer(body) == OK:
		return img
	return null

# ── PERSISTENCIA LOCAL DE SESIÓN Y UTILIDADES PKCE ────────────────────────

func _guardar_sesion_local() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("supabase", "access_token", access_token)
	cfg.set_value("supabase", "refresh_token", refresh_token)
	cfg.set_value("supabase", "user_id", user_id)
	cfg.set_value("supabase", "email", user_email)
	cfg.set_value("supabase", "provider", user_provider)
	cfg.save(SESSION_PATH)

func _cargar_sesion_local() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return
	access_token = str(cfg.get_value("supabase", "access_token", ""))
	refresh_token = str(cfg.get_value("supabase", "refresh_token", ""))
	user_id = str(cfg.get_value("supabase", "user_id", ""))
	user_email = str(cfg.get_value("supabase", "email", ""))
	user_provider = str(cfg.get_value("supabase", "provider", ""))

func _generar_pkce_verifier() -> String:
	var bytes := Crypto.new().generate_random_bytes(32)
	return _base64url(bytes)

func _generar_pkce_challenge(verifier: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(verifier.to_utf8_buffer())
	var digest := ctx.finish()
	return _base64url(digest)

func _base64url(bytes: PackedByteArray) -> String:
	var b64 := Marshalls.raw_to_base64(bytes)
	return b64.replace("+", "-").replace("/", "_").replace("=", "")

func _extraer_parametro_url(url_o_ruta: String, clave: String) -> String:
	var idx_q := url_o_ruta.find("?")
	var idx_h := url_o_ruta.find("#")
	var query := ""
	if idx_q != -1:
		query = url_o_ruta.substr(idx_q + 1)
	elif idx_h != -1:
		query = url_o_ruta.substr(idx_h + 1)
	if query.is_empty():
		return ""
	for par in query.split("&"):
		var kv := par.split("=", true, 1)
		if kv.size() == 2 and kv[0] == clave:
			return kv[1].uri_decode()
	return ""
