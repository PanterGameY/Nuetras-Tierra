extends Control

## ComunidadModal.gd — Panel de Comunidad y Jugadores Conectados (Glassmorphism Automotriz)
## Diseñado para consumir mínimos recursos: sin WebSocket permanente ni _process() activo.

const FONT := preload("res://recursos/fonts/Moderniz.otf")
const DISCORD_ICON_PATH := "res://recursos/redes sociales/Discord.png"
const GOOGLE_ICON_PATH := "res://interfaz/pantallas/menu_principal/imagenes/Google__G__logo.svg.webp"
const DISCORD_INVITE_URL := "https://discord.com/invite/8xqXfR54EW"

const C_BG_OVERLAY := Color(0.02, 0.03, 0.04, 0.78)
const C_BG_PANEL := Color(0.06, 0.07, 0.08, 0.95)
const C_BG_SIDEBAR := Color(0.08, 0.09, 0.11, 0.92)
const C_BG_CARD := Color(0.09, 0.10, 0.12, 0.90)
const C_BG_CARD_SELF := Color(0.13, 0.11, 0.08, 0.94)
const C_BG_DISCORD_CARD := Color(0.10, 0.12, 0.21, 0.94)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_BORDER_SUBTLE := Color(0.78, 0.81, 0.85, 0.12)
const C_BORDER_BRIGHT := Color(0.85, 0.88, 0.92, 0.42)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.92)
const C_AMBER_BRIGHT := Color(1.0, 0.80, 0.40, 1.0)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_ONLINE := Color(0.28, 0.88, 0.54, 1.0)
const C_DISCORD := Color(0.35, 0.44, 0.95, 1.0)
const C_DISCORD_LIGHT := Color(0.62, 0.69, 1.0, 1.0)
const C_GOOGLE := Color(0.26, 0.52, 0.96, 1.0)
const C_TEXT_MAIN := Color(0.92, 0.94, 0.96, 1.0)
const C_TEXT_MUTED := Color(0.56, 0.60, 0.66, 0.92)

const REFRESH_COOLDOWN_SEC := 5.0
const MAX_AVATAR_CACHE := 50

var _panel: PanelContainer = null
var _lbl_contador: Label = null
var _lbl_lista_titulo: Label = null
var _lbl_estado: Label = null
var _btn_actualizar: Button = null
var _btn_cerrar: Button = null
var _lista_vbox: VBoxContainer = null
var _perfil_local_slot: VBoxContainer = null
var _http_server: HTTPRequest = null

var _tex_discord: Texture2D = null
var _tex_google: Texture2D = null

var _jugadores_supabase: Array = []
var _jugadores_servidor: Array = []
var _avatar_cache: Dictionary = {} # url -> Texture2D
var _avatares_descargando: Dictionary = {} # url -> Array[Dictionary{rect, inicial}]
var _material_circular: ShaderMaterial = null
var _consultas_pendientes: int = 0
var _ultimo_refresco_unix: float = 0.0
var _cerrando: bool = false


func _ready() -> void:
	set_process(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_tex_discord = _cargar_textura(DISCORD_ICON_PATH)
	_tex_google = _cargar_textura(GOOGLE_ICON_PATH)

	_construir_ui()

	var sb := get_node_or_null("/root/SupabaseManager")
	if sb and sb.has_signal("comunidad_actualizada") and not sb.comunidad_actualizada.is_connected(_on_supabase_comunidad):
		sb.comunidad_actualizada.connect(_on_supabase_comunidad)


func _cargar_textura(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		var res := load(ruta)
		if res is Texture2D:
			return res
	return null


func abrir() -> void:
	_cerrando = false
	visible = true
	modulate.a = 0.0
	if _panel:
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.92, 0.92)
		_panel.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _panel:
		tw.tween_property(_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_renderizar_lista()
	actualizar_conectados(true)


func cerrar() -> void:
	if _cerrando or not visible:
		return
	_cerrando = true

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _panel:
		tw.tween_property(_panel, "scale", Vector2(0.94, 0.94), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(self):
		visible = false
		_cerrando = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cerrar()


func actualizar_conectados(forzar: bool = false) -> void:
	var ahora := Time.get_unix_time_from_system()
	if not forzar and (ahora - _ultimo_refresco_unix) < REFRESH_COOLDOWN_SEC:
		if _lbl_estado:
			_lbl_estado.text = "ESPERA UNOS SEGUNDOS PARA VOLVER A ACTUALIZAR"
		return

	_ultimo_refresco_unix = ahora
	_consultas_pendientes = 0
	if _lbl_estado:
		_lbl_estado.text = "CONSULTANDO CONDUCTORES EN LINEA..."
	if _btn_actualizar:
		_btn_actualizar.disabled = true

	var sb := get_node_or_null("/root/SupabaseManager")
	if sb and sb.has_method("actualizar_presencia") and sb.has_method("obtener_jugadores_conectados"):
		_consultas_pendientes += 1
		sb.actualizar_presencia()
		sb.obtener_jugadores_conectados(3)

	var url_presencia := _obtener_url_presencia_http()
	if not url_presencia.is_empty():
		_consultas_pendientes += 1
		_consultar_servidor_ligero(url_presencia)

	if _consultas_pendientes == 0:
		_finalizar_consulta()


func _obtener_url_presencia_http() -> String:
	var net := get_node_or_null("/root/Network")
	if not net or not ("vps_signaling_url" in net):
		return ""
	var ws_url := str(net.vps_signaling_url).strip_edges()
	if ws_url.is_empty():
		return ""
	var base := ws_url.replace("wss://", "https://").replace("ws://", "http://")
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	return base + "/presence"


func _consultar_servidor_ligero(url: String) -> void:
	if is_instance_valid(_http_server):
		_http_server.queue_free()
	_http_server = HTTPRequest.new()
	_http_server.timeout = 6.0
	add_child(_http_server)

	var info_local := _datos_jugador_local()
	var body := JSON.stringify({
		"id": info_local["id"],
		"name": info_local["nombre"],
		"level": info_local["nivel"],
		"discord": info_local["discord"],
		"provider": info_local["provider"],
		"avatar_url": info_local["avatar_url"],
		"status": "En menu"
	})
	var headers := ["Content-Type: application/json"]

	_http_server.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, resp_body: PackedByteArray) -> void:
		if is_instance_valid(_http_server):
			_http_server.queue_free()
			_http_server = null
		if status >= 200 and status < 300:
			var parsed = JSON.parse_string(resp_body.get_string_from_utf8())
			if parsed is Dictionary and parsed.get("players") is Array:
				_jugadores_servidor = parsed["players"]
		_consultas_pendientes = maxi(_consultas_pendientes - 1, 0)
		_renderizar_lista()
		if _consultas_pendientes == 0:
			_finalizar_consulta()
	)
	var err := _http_server.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		if is_instance_valid(_http_server):
			_http_server.queue_free()
			_http_server = null
		_consultas_pendientes = maxi(_consultas_pendientes - 1, 0)
		if _consultas_pendientes == 0:
			_finalizar_consulta()


func _on_supabase_comunidad(jugadores: Array, ok: bool) -> void:
	if ok:
		_jugadores_supabase = jugadores
	_consultas_pendientes = maxi(_consultas_pendientes - 1, 0)
	_renderizar_lista()
	if _consultas_pendientes == 0:
		_finalizar_consulta()


func _finalizar_consulta() -> void:
	if _btn_actualizar:
		_btn_actualizar.disabled = false
	if _lbl_estado:
		var hora := Time.get_time_string_from_system().substr(0, 5)
		_lbl_estado.text = "SINCRONIZACION LIGERA ACTIVA · ACTUALIZADO %s" % hora


func _normalizar_proveedor(raw: String) -> String:
	var p := raw.strip_edges().to_lower()
	if p.contains("google"):
		return "google"
	if p.contains("discord"):
		return "discord"
	return ""


func _datos_jugador_local() -> Dictionary:
	var nombre := "Conductor"
	var nivel := 0
	var discord := ""
	var provider := ""
	var id_val := "local"
	var avatar_url := ""
	var avatar_tex: Texture2D = null

	var du := get_node_or_null("/root/DatosUsuario")
	if du:
		var n := str(du.nombre_usuario).strip_edges()
		if not n.is_empty():
			nombre = n
		nivel = int(du.nivel)
		discord = str(du.discord_username).strip_edges()
		if "proveedor_auth" in du:
			provider = _normalizar_proveedor(str(du.proveedor_auth))
		if "avatar_texture" in du and du.avatar_texture is Texture2D:
			avatar_tex = du.avatar_texture
		if not str(du.firebase_uid).strip_edges().is_empty():
			id_val = str(du.firebase_uid).strip_edges()
		elif not str(du.id_usuario).strip_edges().is_empty():
			id_val = str(du.id_usuario).strip_edges()

	var sb := get_node_or_null("/root/SupabaseManager")
	if sb:
		if not str(sb.user_id).strip_edges().is_empty():
			id_val = str(sb.user_id).strip_edges()
		if provider.is_empty() and "user_provider" in sb:
			provider = _normalizar_proveedor(str(sb.user_provider))
		if "user_metadata" in sb and sb.user_metadata is Dictionary:
			avatar_url = str(sb.user_metadata.get("avatar_url", sb.user_metadata.get("picture", ""))).strip_edges()

	return {
		"id": id_val,
		"nombre": nombre,
		"nivel": nivel,
		"discord": discord,
		"provider": provider,
		"avatar_url": avatar_url,
		"avatar_tex": avatar_tex,
		"status": "En menu",
		"es_local": true
	}


func _combinar_jugadores() -> Array[Dictionary]:
	var mapa: Dictionary = {}
	var orden: Array[String] = []

	var local := _datos_jugador_local()
	var clave_local := _clave_jugador(local["id"], local["nombre"])
	mapa[clave_local] = local
	orden.append(clave_local)

	for item in _jugadores_servidor:
		if not (item is Dictionary):
			continue
		var entry := {
			"id": str(item.get("id", "")),
			"nombre": str(item.get("name", "Conductor")).strip_edges(),
			"nivel": int(item.get("level", 0)),
			"discord": str(item.get("discord", "")).strip_edges(),
			"provider": _normalizar_proveedor(str(item.get("provider", ""))),
			"avatar_url": str(item.get("avatar_url", "")).strip_edges(),
			"status": str(item.get("status", "En linea")).strip_edges(),
			"es_local": false
		}
		if entry["nombre"].is_empty():
			entry["nombre"] = "Conductor"
		var clave := _clave_jugador(entry["id"], entry["nombre"])
		if clave == clave_local:
			mapa[clave_local]["status"] = entry["status"]
			continue
		if not mapa.has(clave):
			mapa[clave] = entry
			orden.append(clave)

	for item in _jugadores_supabase:
		if not (item is Dictionary):
			continue
		var entry := {
			"id": str(item.get("id", "")),
			"nombre": str(item.get("nombre", "Conductor")).strip_edges(),
			"nivel": int(item.get("nivel", 0)),
			"discord": str(item.get("discord_usuario", "")).strip_edges(),
			"provider": _normalizar_proveedor(str(item.get("proveedor", ""))),
			"avatar_url": str(item.get("avatar_url", "")).strip_edges(),
			"status": "En linea",
			"es_local": false
		}
		if entry["nombre"].is_empty():
			entry["nombre"] = "Conductor"
		var clave := _clave_jugador(entry["id"], entry["nombre"])
		if clave == clave_local:
			if str(mapa[clave_local].get("avatar_url", "")).is_empty() and not entry["avatar_url"].is_empty():
				mapa[clave_local]["avatar_url"] = entry["avatar_url"]
			if str(mapa[clave_local].get("provider", "")).is_empty() and not entry["provider"].is_empty():
				mapa[clave_local]["provider"] = entry["provider"]
			continue
		if not mapa.has(clave):
			mapa[clave] = entry
			orden.append(clave)
		else:
			if str(mapa[clave].get("discord", "")).is_empty() and not entry["discord"].is_empty():
				mapa[clave]["discord"] = entry["discord"]
			if str(mapa[clave].get("provider", "")).is_empty() and not entry["provider"].is_empty():
				mapa[clave]["provider"] = entry["provider"]
			if str(mapa[clave].get("avatar_url", "")).is_empty() and not entry["avatar_url"].is_empty():
				mapa[clave]["avatar_url"] = entry["avatar_url"]

	var resultado: Array[Dictionary] = []
	for k in orden:
		resultado.append(mapa[k])
	return resultado


func _clave_jugador(id_str: String, nombre_str: String) -> String:
	var id_limpio := id_str.strip_edges().to_lower()
	if not id_limpio.is_empty() and id_limpio != "local":
		return "id:" + id_limpio
	return "name:" + nombre_str.strip_edges().to_lower()


func _tiene_discord(j: Dictionary) -> bool:
	return str(j.get("provider", "")) == "discord" or not str(j.get("discord", "")).strip_edges().is_empty()


func _tiene_google(j: Dictionary) -> bool:
	return str(j.get("provider", "")) == "google"


func _renderizar_lista() -> void:
	if not _lista_vbox:
		return
	for child in _lista_vbox.get_children():
		child.queue_free()

	var jugadores := _combinar_jugadores()
	for j in jugadores:
		if bool(j.get("es_local", false)):
			_actualizar_perfil_local_sidebar(j)

	if _lbl_contador:
		var sufijo := "CONDUCTOR ACTIVO" if jugadores.size() == 1 else "CONDUCTORES ACTIVOS"
		_lbl_contador.text = "%d %s" % [jugadores.size(), sufijo]

	if _lbl_lista_titulo:
		_lbl_lista_titulo.text = "CONDUCTORES CONECTADOS (%d)" % jugadores.size()

	if jugadores.is_empty():
		_lista_vbox.add_child(_crear_estado_vacio())
		return

	for j in jugadores:
		_lista_vbox.add_child(_crear_tarjeta_jugador(j))


func _actualizar_perfil_local_sidebar(j: Dictionary) -> void:
	if not is_instance_valid(_perfil_local_slot):
		return
	for c in _perfil_local_slot.get_children():
		c.queue_free()

	var avatar_grande := _crear_avatar_widget(j, 148.0, true)
	avatar_grande.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_perfil_local_slot.add_child(avatar_grande)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.add_theme_constant_override("separation", 4)
	_perfil_local_slot.add_child(info_vb)

	var lbl_nom := Label.new()
	lbl_nom.text = str(j.get("nombre", "Conductor")).to_upper()
	lbl_nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_nom.add_theme_font_override("font", FONT)
	lbl_nom.add_theme_font_size_override("font_size", 28)
	lbl_nom.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	info_vb.add_child(lbl_nom)

	var nivel := int(j.get("nivel", 0))
	var rango := RangoConductor.obtener_rango(nivel)
	var lbl_rng := Label.new()
	lbl_rng.text = "NV. %d · %s" % [nivel, str(rango.get("nombre", "Novato")).to_upper()]
	lbl_rng.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_rng.add_theme_font_override("font", FONT)
	lbl_rng.add_theme_font_size_override("font_size", 19)
	lbl_rng.add_theme_color_override("font_color", C_TEXT_MUTED)
	info_vb.add_child(lbl_rng)

	var badges_hb := HBoxContainer.new()
	badges_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	badges_hb.add_theme_constant_override("separation", 10)
	_perfil_local_slot.add_child(badges_hb)

	var tiene_g := _tiene_google(j)
	var tiene_d := _tiene_discord(j)
	if tiene_g:
		badges_hb.add_child(_crear_badge_plataforma("google", "GOOGLE", false))
	if tiene_d:
		var d_user := str(j.get("discord", "")).strip_edges().trim_prefix("@")
		var d_txt := d_user if not d_user.is_empty() else "DISCORD"
		badges_hb.add_child(_crear_badge_plataforma("discord", d_txt, false))
	if not tiene_g and not tiene_d:
		var lbl_sin := Label.new()
		lbl_sin.text = "CUENTA INVITADO · SIN VINCULAR"
		lbl_sin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sin.add_theme_font_override("font", FONT)
		lbl_sin.add_theme_font_size_override("font_size", 17)
		lbl_sin.add_theme_color_override("font_color", C_TEXT_MUTED)
		badges_hb.add_child(lbl_sin)


func _crear_estado_vacio() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 140)
	var sb := _crear_estilo(C_BG_CARD, C_BORDER_SUBTLE, 14, 1, 4)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var lbl := Label.new()
	lbl.text = "NO HAY CONDUCTORES EN ESTE FILTRO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", C_TEXT_MAIN)
	vb.add_child(lbl)

	var lbl_sub := Label.new()
	lbl_sub.text = "Cambia a TODOS para ver a todos los conductores conectados."
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_override("font", FONT)
	lbl_sub.add_theme_font_size_override("font_size", 20)
	lbl_sub.add_theme_color_override("font_color", C_TEXT_MUTED)
	vb.add_child(lbl_sub)
	return card


func _crear_avatar_widget(j: Dictionary, tam: float, es_local: bool) -> Control:
	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(tam, tam)
	avatar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var radio := int(tam * 0.5)
	var marco := Panel.new()
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb_marco := StyleBoxFlat.new()
	sb_marco.bg_color = Color(0.11, 0.13, 0.16, 0.95)
	sb_marco.set_border_width_all(2)
	sb_marco.border_color = C_AMBER if es_local else Color(0.78, 0.81, 0.85, 0.35)
	sb_marco.set_corner_radius_all(radio)
	marco.add_theme_stylebox_override("panel", sb_marco)
	avatar_wrap.add_child(marco)

	var nombre_base := str(j.get("nombre", "Conductor")).strip_edges()
	var inicial := nombre_base.substr(0, 1).to_upper() if not nombre_base.is_empty() else "?"
	var lbl_inicial := Label.new()
	lbl_inicial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_inicial.text = inicial
	lbl_inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_inicial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_inicial.add_theme_font_override("font", FONT)
	lbl_inicial.add_theme_font_size_override("font_size", int(tam * 0.38))
	lbl_inicial.add_theme_color_override("font_color", C_AMBER_BRIGHT if es_local else C_TEXT_MAIN)
	avatar_wrap.add_child(lbl_inicial)

	var avatar_rect := TextureRect.new()
	avatar_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar_rect.offset_left = 3.0
	avatar_rect.offset_top = 3.0
	avatar_rect.offset_right = -3.0
	avatar_rect.offset_bottom = -3.0
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_rect.material = _obtener_material_circular()
	avatar_wrap.add_child(avatar_rect)

	_aplicar_avatar_en_tarjeta(j, avatar_rect, lbl_inicial)

	var dot_sz := 26.0 if tam >= 130.0 else (22.0 if tam >= 100.0 else (18.0 if tam >= 64.0 else 15.0))
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(dot_sz, dot_sz)
	dot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dot.offset_left = -dot_sz
	dot.offset_top = -dot_sz
	dot.offset_right = 0.0
	dot.offset_bottom = 0.0
	var sb_dot := StyleBoxFlat.new()
	sb_dot.bg_color = C_ONLINE
	sb_dot.set_border_width_all(2)
	sb_dot.border_color = Color(0.06, 0.07, 0.08, 1.0)
	sb_dot.set_corner_radius_all(int(ceil(dot_sz * 0.5)))
	sb_dot.shadow_color = Color(C_ONLINE.r, C_ONLINE.g, C_ONLINE.b, 0.55)
	sb_dot.shadow_size = 5
	dot.add_theme_stylebox_override("panel", sb_dot)
	avatar_wrap.add_child(dot)

	return avatar_wrap


func _crear_badge_plataforma(tipo: String, etiqueta: String, clickable: bool = false) -> PanelContainer:
	var es_discord := tipo == "discord"
	var fondo := Color(0.16, 0.20, 0.36, 0.72) if es_discord else Color(0.13, 0.16, 0.21, 0.85)
	var borde := Color(0.45, 0.54, 0.98, 0.55) if es_discord else Color(0.78, 0.81, 0.85, 0.32)
	var color_txt := C_DISCORD_LIGHT if es_discord else C_TEXT_MAIN
	var tex := _tex_discord if es_discord else _tex_google

	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := _crear_estilo(fondo, borde, 10, 1, 0)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	pill.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(hb)

	if tex:
		hb.add_child(_crear_icono_desbordado(tex, Vector2(34, 24), 38.0))

	var lbl := Label.new()
	lbl.text = etiqueta
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", color_txt)
	hb.add_child(lbl)

	if clickable and es_discord and not etiqueta.is_empty() and etiqueta != "DISCORD":
		pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pill.tooltip_text = "Toca para copiar usuario de Discord"
		pill.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				DisplayServer.clipboard_set(etiqueta)
				if _lbl_estado:
					_lbl_estado.text = "USUARIO COPIADO AL PORTAPAPELES: %s" % etiqueta
		)

	return pill


func _crear_tarjeta_jugador(j: Dictionary) -> PanelContainer:
	var es_local := bool(j.get("es_local", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 134)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var borde := C_AMBER if es_local else C_BORDER_FROST
	var fondo := C_BG_CARD_SELF if es_local else C_BG_CARD
	var sb := _crear_estilo(fondo, borde, 14, 1, 6)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(hbox)

	# Avatar circular con punto verde en línea
	hbox.add_child(_crear_avatar_widget(j, 82.0, es_local))

	# Info central: Nombre + Badges de Google / Discord / Estado
	var vbox_info := VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox_info.add_theme_constant_override("separation", 10)
	vbox_info.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(vbox_info)

	var nombre_row := HBoxContainer.new()
	nombre_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre_row.add_theme_constant_override("separation", 12)
	nombre_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox_info.add_child(nombre_row)

	var lbl_nombre := Label.new()
	lbl_nombre.text = str(j.get("nombre", "Conductor")).to_upper()
	lbl_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_nombre.add_theme_font_override("font", FONT)
	lbl_nombre.add_theme_font_size_override("font_size", 30)
	lbl_nombre.add_theme_color_override("font_color", C_AMBER_BRIGHT if es_local else C_TEXT_MAIN)
	nombre_row.add_child(lbl_nombre)

	if es_local:
		var pill_tu := PanelContainer.new()
		pill_tu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb_tu := _crear_estilo(Color(0.88, 0.68, 0.28, 0.18), C_AMBER, 6, 1, 0)
		sb_tu.content_margin_left = 10.0
		sb_tu.content_margin_right = 10.0
		sb_tu.content_margin_top = 3.0
		sb_tu.content_margin_bottom = 3.0
		pill_tu.add_theme_stylebox_override("panel", sb_tu)
		var lbl_tu := Label.new()
		lbl_tu.text = "TU"
		lbl_tu.add_theme_font_override("font", FONT)
		lbl_tu.add_theme_font_size_override("font_size", 16)
		lbl_tu.add_theme_color_override("font_color", C_AMBER_BRIGHT)
		pill_tu.add_child(lbl_tu)
		nombre_row.add_child(pill_tu)

	# Fila inferior: Logos de Google y/o Discord + estado
	var badges_row := HBoxContainer.new()
	badges_row.add_theme_constant_override("separation", 10)
	vbox_info.add_child(badges_row)

	var tiene_g := _tiene_google(j)
	var tiene_d := _tiene_discord(j)
	var discord_txt := str(j.get("discord", "")).strip_edges()

	if tiene_g:
		badges_row.add_child(_crear_badge_plataforma("google", "GOOGLE", false))
	if tiene_d:
		var d_limpio := discord_txt.trim_prefix("@")
		var d_label := d_limpio if not d_limpio.is_empty() else "DISCORD"
		badges_row.add_child(_crear_badge_plataforma("discord", d_label, true))

	var status_txt := str(j.get("status", "En linea")).strip_edges()
	if status_txt.is_empty():
		status_txt = "En linea"
	if not tiene_g and not tiene_d:
		var lbl_sub := Label.new()
		lbl_sub.text = "● " + status_txt.to_upper()
		lbl_sub.add_theme_font_override("font", FONT)
		lbl_sub.add_theme_font_size_override("font_size", 18)
		lbl_sub.add_theme_color_override("font_color", C_TEXT_MUTED)
		badges_row.add_child(lbl_sub)
	else:
		var lbl_st := Label.new()
		lbl_st.text = "· " + status_txt.to_upper()
		lbl_st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl_st.add_theme_font_override("font", FONT)
		lbl_st.add_theme_font_size_override("font_size", 17)
		lbl_st.add_theme_color_override("font_color", C_TEXT_MUTED)
		badges_row.add_child(lbl_st)

	# Nivel y rango a la derecha
	var nivel := int(j.get("nivel", 0))
	var rango := RangoConductor.obtener_rango(nivel)
	var color_rango: Color = rango.get("color", C_AMBER)

	var pill_nivel := PanelContainer.new()
	pill_nivel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_niv := _crear_estilo(
		Color(color_rango.r, color_rango.g, color_rango.b, 0.14),
		Color(color_rango.r, color_rango.g, color_rango.b, 0.72),
		10, 1, 0
	)
	sb_niv.content_margin_left = 18.0
	sb_niv.content_margin_right = 18.0
	sb_niv.content_margin_top = 10.0
	sb_niv.content_margin_bottom = 10.0
	pill_nivel.add_theme_stylebox_override("panel", sb_niv)
	hbox.add_child(pill_nivel)

	var lbl_nivel := Label.new()
	lbl_nivel.text = "NV. %d · %s" % [nivel, str(rango.get("nombre", "Novato")).to_upper()]
	lbl_nivel.add_theme_font_override("font", FONT)
	lbl_nivel.add_theme_font_size_override("font_size", 21)
	lbl_nivel.add_theme_color_override("font_color", color_rango.lightened(0.2))
	pill_nivel.add_child(lbl_nivel)

	return card


func _obtener_material_circular() -> ShaderMaterial:
	if _material_circular == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float alpha = 1.0 - smoothstep(0.47, 0.5, length(d));
	vec4 col = texture(TEXTURE, UV) * COLOR;
	col.a *= alpha;
	COLOR = col;
}"""
		_material_circular = ShaderMaterial.new()
		_material_circular.shader = sh
	return _material_circular


func _aplicar_avatar_en_tarjeta(j: Dictionary, rect: TextureRect, lbl_inicial: Label) -> void:
	var tex_local = j.get("avatar_tex", null)
	if tex_local is Texture2D:
		rect.texture = tex_local
		lbl_inicial.visible = false
		return

	var url := str(j.get("avatar_url", "")).strip_edges()
	if url.is_empty():
		return

	if _avatar_cache.has(url):
		var cached = _avatar_cache[url]
		if cached is Texture2D:
			rect.texture = cached
			lbl_inicial.visible = false
		return

	if _avatares_descargando.has(url):
		_avatares_descargando[url].append({"rect": rect, "inicial": lbl_inicial})
		return

	_avatares_descargando[url] = [{"rect": rect, "inicial": lbl_inicial}]
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	http.request_completed.connect(func(_res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var targets: Array = _avatares_descargando.get(url, [])
		_avatares_descargando.erase(url)
		if status < 200 or status >= 300 or body.is_empty():
			return
		var img := _decodificar_avatar(body)
		if img == null or img.is_empty():
			return
		if img.get_width() > 128 or img.get_height() > 128:
			img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		var tex := ImageTexture.create_from_image(img)
		if _avatar_cache.size() >= MAX_AVATAR_CACHE:
			var first_key = _avatar_cache.keys()[0]
			_avatar_cache.erase(first_key)
		_avatar_cache[url] = tex
		for t in targets:
			var r = t.get("rect")
			var l = t.get("inicial")
			if is_instance_valid(r):
				r.texture = tex
			if is_instance_valid(l):
				l.visible = false
	)
	if http.request(url, [], HTTPClient.METHOD_GET) != OK:
		http.queue_free()
		_avatares_descargando.erase(url)


func _decodificar_avatar(body: PackedByteArray) -> Image:
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


func _construir_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = C_BG_OVERLAY
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cerrar()
	)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1140, 700)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_panel := _crear_estilo(C_BG_PANEL, C_BORDER_FROST, 16, 1, 16)
	sb_panel.content_margin_left = 32.0
	sb_panel.content_margin_right = 32.0
	sb_panel.content_margin_top = 26.0
	sb_panel.content_margin_bottom = 22.0
	_panel.add_theme_stylebox_override("panel", sb_panel)
	margin.add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 18)
	_panel.add_child(root_vbox)

	# ── Header ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 4)
	header.add_child(title_vbox)

	var lbl_eyebrow := Label.new()
	lbl_eyebrow.text = "● RED DE CONDUCTORES · NUESTRA TIERRA 2.0"
	lbl_eyebrow.add_theme_font_override("font", FONT)
	lbl_eyebrow.add_theme_font_size_override("font_size", 18)
	lbl_eyebrow.add_theme_color_override("font_color", C_AMBER)
	title_vbox.add_child(lbl_eyebrow)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "COMUNIDAD EN LINEA"
	lbl_titulo.add_theme_font_override("font", FONT)
	lbl_titulo.add_theme_font_size_override("font_size", 46)
	lbl_titulo.add_theme_color_override("font_color", C_TEXT_MAIN)
	title_vbox.add_child(lbl_titulo)

	# Pill contador en vivo
	var pill_count := PanelContainer.new()
	pill_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_count := _crear_estilo(Color(0.28, 0.88, 0.54, 0.12), Color(0.28, 0.88, 0.54, 0.55), 12, 1, 0)
	sb_count.content_margin_left = 20.0
	sb_count.content_margin_right = 20.0
	sb_count.content_margin_top = 14.0
	sb_count.content_margin_bottom = 14.0
	pill_count.add_theme_stylebox_override("panel", sb_count)
	header.add_child(pill_count)

	_lbl_contador = Label.new()
	_lbl_contador.text = "1 CONDUCTOR ACTIVO"
	_lbl_contador.add_theme_font_override("font", FONT)
	_lbl_contador.add_theme_font_size_override("font_size", 22)
	_lbl_contador.add_theme_color_override("font_color", C_ONLINE)
	pill_count.add_child(_lbl_contador)

	# Botón Actualizar
	_btn_actualizar = _crear_boton_cockpit("ACTUALIZAR", C_AMBER, 240, 68, 24, true, null, false)
	_btn_actualizar.pressed.connect(func() -> void:
		actualizar_conectados(false)
	)
	header.add_child(_btn_actualizar)

	# Botón Cerrar
	_btn_cerrar = _crear_boton_cockpit("CERRAR", C_CRIMSON, 185, 68, 24, false, null, false)
	_btn_cerrar.pressed.connect(cerrar)
	header.add_child(_btn_cerrar)

	var sep := HSeparator.new()
	var sb_sep := StyleBoxLine.new()
	sb_sep.color = C_BORDER_FROST
	sb_sep.thickness = 1
	sep.add_theme_stylebox_override("separator", sb_sep)
	root_vbox.add_child(sep)

	# ── Cuerpo Cockpit 2 Columnas ──
	var body_split := HBoxContainer.new()
	body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.add_theme_constant_override("separation", 24)
	root_vbox.add_child(body_split)

	_construir_sidebar_izquierda(body_split)
	_construir_panel_jugadores(body_split)

	# ── Footer ──
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root_vbox.add_child(footer)

	_lbl_estado = Label.new()
	_lbl_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_estado.text = "SINCRONIZACION LIGERA ACTIVA"
	_lbl_estado.add_theme_font_override("font", FONT)
	_lbl_estado.add_theme_font_size_override("font_size", 18)
	_lbl_estado.add_theme_color_override("font_color", C_TEXT_MUTED)
	footer.add_child(_lbl_estado)

	var lbl_tip := Label.new()
	lbl_tip.text = "TOCA UN USUARIO DE DISCORD PARA COPIAR"
	lbl_tip.add_theme_font_override("font", FONT)
	lbl_tip.add_theme_font_size_override("font_size", 18)
	lbl_tip.add_theme_color_override("font_color", C_AMBER)
	footer.add_child(lbl_tip)


func _construir_sidebar_izquierda(parent: HBoxContainer) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(440, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 16)
	parent.add_child(sidebar)

	# 1. Tarjeta de Tu Perfil Local
	var card_perfil := PanelContainer.new()
	var sb_perfil := _crear_estilo(C_BG_SIDEBAR, C_BORDER_FROST, 14, 1, 8)
	sb_perfil.content_margin_left = 20.0
	sb_perfil.content_margin_right = 20.0
	sb_perfil.content_margin_top = 18.0
	sb_perfil.content_margin_bottom = 18.0
	card_perfil.add_theme_stylebox_override("panel", sb_perfil)
	sidebar.add_child(card_perfil)

	var vb_p := VBoxContainer.new()
	vb_p.add_theme_constant_override("separation", 12)
	card_perfil.add_child(vb_p)

	var lbl_sec_tu := Label.new()
	lbl_sec_tu.text = "TU PERFIL DE CONDUCTOR"
	lbl_sec_tu.add_theme_font_override("font", FONT)
	lbl_sec_tu.add_theme_font_size_override("font_size", 18)
	lbl_sec_tu.add_theme_color_override("font_color", C_AMBER)
	vb_p.add_child(lbl_sec_tu)

	_perfil_local_slot = VBoxContainer.new()
	_perfil_local_slot.add_theme_constant_override("separation", 12)
	vb_p.add_child(_perfil_local_slot)

	# 2. Tarjeta Hero de Discord Oficial
	var card_discord := PanelContainer.new()
	card_discord.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_disc := _crear_estilo(C_BG_DISCORD_CARD, Color(0.45, 0.54, 0.98, 0.55), 14, 1, 10)
	sb_disc.content_margin_left = 22.0
	sb_disc.content_margin_right = 22.0
	sb_disc.content_margin_top = 20.0
	sb_disc.content_margin_bottom = 20.0
	card_discord.add_theme_stylebox_override("panel", sb_disc)
	sidebar.add_child(card_discord)

	var vb_d := VBoxContainer.new()
	vb_d.add_theme_constant_override("separation", 14)
	card_discord.add_child(vb_d)

	var top_d := HBoxContainer.new()
	top_d.add_theme_constant_override("separation", 16)
	vb_d.add_child(top_d)

	if _tex_discord:
		var logo_wrap := PanelContainer.new()
		logo_wrap.custom_minimum_size = Vector2(74, 74)
		logo_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb_logo := _crear_estilo(Color(0.08, 0.10, 0.18, 0.95), Color(0.45, 0.54, 0.98, 0.65), 16, 1, 4)
		sb_logo.content_margin_left = 3.0
		sb_logo.content_margin_right = 3.0
		sb_logo.content_margin_top = 3.0
		sb_logo.content_margin_bottom = 3.0
		logo_wrap.add_theme_stylebox_override("panel", sb_logo)
		top_d.add_child(logo_wrap)

		var ico_d := TextureRect.new()
		ico_d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ico_d.texture = _tex_discord
		ico_d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico_d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico_d.modulate = Color.WHITE
		logo_wrap.add_child(ico_d)

	var d_titles := VBoxContainer.new()
	d_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d_titles.add_theme_constant_override("separation", 4)
	top_d.add_child(d_titles)

	var lbl_d_tag := Label.new()
	lbl_d_tag.text = "COMUNIDAD OFICIAL"
	lbl_d_tag.add_theme_font_override("font", FONT)
	lbl_d_tag.add_theme_font_size_override("font_size", 17)
	lbl_d_tag.add_theme_color_override("font_color", C_DISCORD_LIGHT)
	d_titles.add_child(lbl_d_tag)

	var lbl_d_tit := Label.new()
	lbl_d_tit.text = "DISCORD NT 2.0"
	lbl_d_tit.add_theme_font_override("font", FONT)
	lbl_d_tit.add_theme_font_size_override("font_size", 30)
	lbl_d_tit.add_theme_color_override("font_color", C_TEXT_MAIN)
	d_titles.add_child(lbl_d_tit)

	var lbl_d_desc := Label.new()
	lbl_d_desc.text = "Unete para organizar convoyes, reportar rutas, pedir soporte y enterarte de actualizaciones."
	lbl_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_d_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_d_desc.add_theme_font_override("font", FONT)
	lbl_d_desc.add_theme_font_size_override("font_size", 19)
	lbl_d_desc.add_theme_color_override("font_color", C_TEXT_MUTED)
	vb_d.add_child(lbl_d_desc)

	var btn_discord := _crear_boton_cockpit("UNIRSE AL DISCORD", C_DISCORD, 0, 68, 24, true, _tex_discord, true)
	btn_discord.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_discord.pressed.connect(func() -> void:
		OS.shell_open(_obtener_url_discord())
	)
	vb_d.add_child(btn_discord)


func _construir_panel_jugadores(parent: HBoxContainer) -> void:
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 12)
	parent.add_child(right_vbox)

	var list_header := HBoxContainer.new()
	list_header.add_theme_constant_override("separation", 10)
	right_vbox.add_child(list_header)

	_lbl_lista_titulo = Label.new()
	_lbl_lista_titulo.text = "CONDUCTORES CONECTADOS"
	_lbl_lista_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_lista_titulo.add_theme_font_override("font", FONT)
	_lbl_lista_titulo.add_theme_font_size_override("font_size", 24)
	_lbl_lista_titulo.add_theme_color_override("font_color", C_TEXT_MAIN)
	list_header.add_child(_lbl_lista_titulo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.scroll_deadzone = 12
	_estilizar_scrollbar_tactil(scroll.get_v_scroll_bar())
	right_vbox.add_child(scroll)

	_lista_vbox = VBoxContainer.new()
	_lista_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_lista_vbox)


func _estilizar_scrollbar_tactil(vbar: VScrollBar) -> void:
	if not is_instance_valid(vbar):
		return
	vbar.custom_minimum_size = Vector2(30, 0)

	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.05, 0.06, 0.08, 0.80)
	sb_track.set_border_width_all(1)
	sb_track.border_color = C_BORDER_SUBTLE
	sb_track.set_corner_radius_all(14)
	sb_track.content_margin_left = 6.0
	sb_track.content_margin_right = 6.0

	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color(0.55, 0.60, 0.68, 0.65)
	sb_grab.set_corner_radius_all(12)
	sb_grab.content_margin_left = 4.0
	sb_grab.content_margin_right = 4.0

	var sb_grab_hl := StyleBoxFlat.new()
	sb_grab_hl.bg_color = C_AMBER
	sb_grab_hl.set_corner_radius_all(12)

	var sb_grab_pr := StyleBoxFlat.new()
	sb_grab_pr.bg_color = C_AMBER_BRIGHT
	sb_grab_pr.set_corner_radius_all(12)

	vbar.add_theme_stylebox_override("scroll", sb_track)
	vbar.add_theme_stylebox_override("grabber", sb_grab)
	vbar.add_theme_stylebox_override("grabber_highlight", sb_grab_hl)
	vbar.add_theme_stylebox_override("grabber_pressed", sb_grab_pr)


func _obtener_url_discord() -> String:
	if ProjectSettings.has_setting("nuestra_tierra/comunidad/discord_invite_url"):
		var u := str(ProjectSettings.get_setting("nuestra_tierra/comunidad/discord_invite_url")).strip_edges()
		if not u.is_empty():
			return u
	return DISCORD_INVITE_URL


func _crear_boton_cockpit(
	texto: String,
	acento: Color,
	ancho: float,
	alto: float,
	font_sz: int,
	destacado: bool = false,
	icono_tex: Texture2D = null,
	icono_color_original: bool = true
) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(ancho, alto)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var fondo_norm := Color(acento.r, acento.g, acento.b, 0.22) if destacado else Color(0.08, 0.09, 0.11, 0.82)
	var borde_norm := Color(acento.r, acento.g, acento.b, 0.72) if destacado else Color(acento.r, acento.g, acento.b, 0.42)
	var normal := _crear_estilo(fondo_norm, borde_norm, 12, 1, 5)
	var hover := _crear_estilo(Color(acento.r, acento.g, acento.b, 0.32), acento.lightened(0.15), 12, 1, 8)
	var pressed := _crear_estilo(Color(acento.r, acento.g, acento.b, 0.44), acento.lightened(0.25), 12, 1, 10)
	pressed.border_width_bottom = 2
	var focus := hover.duplicate()

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", _crear_estilo(Color(0.07, 0.08, 0.10, 0.55), Color(0.5, 0.5, 0.5, 0.2), 12, 1, 0))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)

	if icono_tex:
		var tinte := Color.WHITE if icono_color_original else acento.lightened(0.25)
		hbox.add_child(_crear_icono_desbordado(icono_tex, Vector2(40, 28), 46.0, tinte))

	var lbl := Label.new()
	lbl.text = texto
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", acento.lightened(0.35) if destacado else C_TEXT_MAIN)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	hbox.add_child(lbl)

	btn.resized.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
	)
	btn.mouse_entered.connect(func() -> void:
		_animar_escala_boton(btn, 1.03, 0.14)
		lbl.add_theme_color_override("font_color", acento.lightened(0.40))
	)
	btn.mouse_exited.connect(func() -> void:
		_animar_escala_boton(btn, 1.0, 0.16)
		lbl.add_theme_color_override("font_color", acento.lightened(0.35) if destacado else C_TEXT_MAIN)
	)
	btn.button_down.connect(func() -> void:
		_animar_escala_boton(btn, 0.95, 0.08)
	)
	btn.button_up.connect(func() -> void:
		_animar_escala_boton(btn, 1.0, 0.16)
	)
	return btn


func _animar_escala_boton(btn: Control, factor: float, duracion: float) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	if btn.has_meta("tw_escala"):
		var prev = btn.get_meta("tw_escala")
		if prev is Tween and prev.is_valid():
			prev.kill()
	var tw := btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(factor, factor), duracion)
	btn.set_meta("tw_escala", tw)


func _crear_icono_desbordado(tex: Texture2D, slot_sz: Vector2, icon_sz: float, tinte: Color = Color.WHITE) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = slot_sz
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ico := TextureRect.new()
	ico.set_anchors_preset(Control.PRESET_CENTER)
	var half := icon_sz * 0.5
	ico.offset_left = -half
	ico.offset_top = -half
	ico.offset_right = half
	ico.offset_bottom = half
	ico.texture = tex
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ico.modulate = tinte
	slot.add_child(ico)
	return slot


func _crear_estilo(fondo: Color, borde: Color, radio: int, grosor: int = 1, sombra: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(grosor)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = sombra
	sb.shadow_offset = Vector2(0, 3)
	return sb
