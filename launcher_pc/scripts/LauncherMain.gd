extends Control

# ══════════════════════════════════════════════════════════════════════════════
# LauncherMain.gd — Launcher PC Oficial (Nuestra Tierra 2.0)
# Estilo: Automotive Glassmorphism (diseño.md / manual_diseno_ui.md)
# ══════════════════════════════════════════════════════════════════════════════

const FONT_MODERNIZ := preload("res://recursos/Moderniz.otf")
const ICON_APP := preload("res://recursos/icon.svg")
const CONFIG_JSON_PATH := "res://launcher_config.json"
const LAUNCHER_STATE_PATH := "user://launcher_state.cfg"

# ── Paleta Automotive Glassmorphism ───────────────────────────────────────────
const C_BG_DARK := Color(0.05, 0.06, 0.07, 1.0)
const C_GLASS := Color(0.06, 0.07, 0.08, 0.90)
const C_CARD := Color(0.09, 0.10, 0.12, 0.92)
const C_BTN := Color(0.08, 0.09, 0.11, 0.85)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.95)
const C_AMBER_DIM := Color(0.88, 0.68, 0.28, 0.25)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_GREEN := Color(0.24, 0.78, 0.45, 0.95)
const C_TEXT := Color(0.95, 0.96, 0.98, 1.0)
const C_TEXT_MUTED := Color(0.58, 0.62, 0.67, 0.90)

# ── Configuración del launcher ────────────────────────────────────────────────
var _cfg_app: Dictionary = {
	"game_name": "Nuestra Tierra 2.0",
	"game_app_userdata_folder": "NuestraTierra2.0",
	"game_exe_name": "NuestraTierra.exe",
	"game_pck_name": "NuestraTierra.pck",
	"manifest_url": "",
	"default_version": "0.0.2",
}

var _game_dir: String = ""
var _local_version: String = "0.0.2"
var _remote_manifest: Dictionary = {}
var _update_available: bool = false
var _is_downloading: bool = false
var _auto_download_on_manifest: bool = false
var _download_target_path: String = ""
var _download_is_zip: bool = false

# ── Nodos UI ──────────────────────────────────────────────────────────────────
var _root_card: PanelContainer
var _lbl_version_local: Label
var _lbl_version_remota: Label
var _lbl_estado: Label
var _lbl_ruta_juego: Label
var _lbl_notas: RichTextLabel
var _progress_bar: ProgressBar
var _lbl_progreso: Label

var _btn_accion_principal: Button
var _btn_buscar_updates: Button
var _btn_reparar: Button
var _btn_ubicar: Button
var _btn_abrir_carpeta: Button
var _btn_modo_pc: Button
var _preset_buttons: Array[Button] = []

var _http_manifest: HTTPRequest
var _http_download: HTTPRequest
var _file_dialog: FileDialog

var _modo_pc_activo: bool = true
var _calidad_actual: int = 2


func _ready() -> void:
	_cargar_launcher_config()
	_detectar_ruta_juego()
	_leer_version_local()
	_cargar_ajustes_juego()
	_construir_ui()
	_configurar_red()
	_animar_entrada()
	_actualizar_estado_ui()
	_consultar_manifest_remoto()


# ── Configuración y Rutas ─────────────────────────────────────────────────────

func _cargar_launcher_config() -> void:
	if FileAccess.file_exists(CONFIG_JSON_PATH):
		var txt := FileAccess.get_file_as_string(CONFIG_JSON_PATH)
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in parsed.keys():
				_cfg_app[k] = parsed[k]


func _detectar_ruta_juego() -> void:
	var exe_name := str(_cfg_app.get("game_exe_name", "NuestraTierra.exe"))
	var st := ConfigFile.new()
	if st.load(LAUNCHER_STATE_PATH) == OK:
		var saved_dir := str(st.get_value("paths", "game_dir", ""))
		if not saved_dir.is_empty() and FileAccess.file_exists(saved_dir.path_join(exe_name)):
			_game_dir = saved_dir
			return

	var base_dir := OS.get_executable_path().get_base_dir()
	var candidatos: Array[String] = [
		base_dir,
		base_dir.path_join("game"),
		ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir().path_join("Nuestra tierra_pc"),
	]
	for dir_cand in candidatos:
		if FileAccess.file_exists(dir_cand.path_join(exe_name)):
			_game_dir = dir_cand
			return

	_game_dir = base_dir.path_join("game")


func _guardar_ruta_juego(dir_path: String) -> void:
	_game_dir = dir_path
	var st := ConfigFile.new()
	st.load(LAUNCHER_STATE_PATH)
	st.set_value("paths", "game_dir", _game_dir)
	st.save(LAUNCHER_STATE_PATH)


func _leer_version_local() -> void:
	var ver_path := _game_dir.path_join("version.txt")
	if FileAccess.file_exists(ver_path):
		var v := FileAccess.get_file_as_string(ver_path).strip_edges()
		if not v.is_empty():
			_local_version = v
			return
	_local_version = str(_cfg_app.get("default_version", "0.0.2"))


func _escribir_version_local(ver: String) -> void:
	_local_version = ver
	var f := FileAccess.open(_game_dir.path_join("version.txt"), FileAccess.WRITE)
	if f:
		f.store_string(ver)
		f.close()


func _ruta_settings_juego() -> String:
	var app_folder := str(_cfg_app.get("game_app_userdata_folder", "NuestraTierra2.0"))
	var parent_userdata := OS.get_user_data_dir().get_base_dir()
	return parent_userdata.path_join(app_folder).path_join("settings.cfg")


func _cargar_ajustes_juego() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_ruta_settings_juego()) == OK:
		_modo_pc_activo = bool(cfg.get_value("controles", "modo_pc", true))
		_calidad_actual = int(cfg.get_value("graficos", "calidad", 2))
	else:
		_modo_pc_activo = true
		_calidad_actual = 2


func _guardar_ajustes_juego() -> void:
	var ruta := _ruta_settings_juego()
	var dir_path := ruta.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var cfg := ConfigFile.new()
	cfg.load(ruta)
	cfg.set_value("controles", "modo_pc", _modo_pc_activo)

	match _calidad_actual:
		0:
			cfg.set_value("graficos", "calidad", 0)
			cfg.set_value("graficos", "cielo_calidad", 2)
			cfg.set_value("graficos", "sombras", 0)
			cfg.set_value("graficos", "aa", 0)
			cfg.set_value("graficos", "render_scale", 60)
			cfg.set_value("graficos", "fps", 0)
			cfg.set_value("graficos", "ssao_enabled", false)
			cfg.set_value("graficos", "glow_enabled", false)
			cfg.set_value("graficos", "sdfgi_enabled", false)
		1:
			cfg.set_value("graficos", "calidad", 1)
			cfg.set_value("graficos", "cielo_calidad", 1)
			cfg.set_value("graficos", "sombras", 1)
			cfg.set_value("graficos", "aa", 1)
			cfg.set_value("graficos", "render_scale", 75)
			cfg.set_value("graficos", "fps", 1)
			cfg.set_value("graficos", "ssao_enabled", false)
			cfg.set_value("graficos", "glow_enabled", false)
			cfg.set_value("graficos", "sdfgi_enabled", false)
		2:
			cfg.set_value("graficos", "calidad", 2)
			cfg.set_value("graficos", "cielo_calidad", 0)
			cfg.set_value("graficos", "sombras", 2)
			cfg.set_value("graficos", "aa", 1)
			cfg.set_value("graficos", "render_scale", 85)
			cfg.set_value("graficos", "fps", 1)
			cfg.set_value("graficos", "ssao_enabled", false)
			cfg.set_value("graficos", "glow_enabled", true)
			cfg.set_value("graficos", "sdfgi_enabled", false)
		3:
			cfg.set_value("graficos", "calidad", 3)
			cfg.set_value("graficos", "cielo_calidad", 0)
			cfg.set_value("graficos", "sombras", 3)
			cfg.set_value("graficos", "aa", 2)
			cfg.set_value("graficos", "render_scale", 100)
			cfg.set_value("graficos", "fps", 1)
			cfg.set_value("graficos", "ssao_enabled", true)
			cfg.set_value("graficos", "glow_enabled", true)
			cfg.set_value("graficos", "sdfgi_enabled", false)

	cfg.save(ruta)


# ── Construcción de Interfaz (Automotive Glassmorphism) ───────────────────────

func _construir_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	_root_card = PanelContainer.new()
	_root_card.add_theme_stylebox_override("panel", _estilo_panel(C_GLASS, C_BORDER_FROST, 14, 1, 6))
	margin.add_child(_root_card)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 28)
	inner_margin.add_theme_constant_override("margin_right", 28)
	inner_margin.add_theme_constant_override("margin_top", 24)
	inner_margin.add_theme_constant_override("margin_bottom", 24)
	_root_card.add_child(inner_margin)

	var vbox_main := VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 18)
	inner_margin.add_child(vbox_main)

	# ── Header ──
	var hbox_top := HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 16)
	vbox_main.add_child(hbox_top)

	var icon_rect := TextureRect.new()
	icon_rect.texture = ICON_APP
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_top.add_child(icon_rect)

	var vbox_title := VBoxContainer.new()
	vbox_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_top.add_child(vbox_title)

	var lbl_titulo := _crear_label("NUESTRA TIERRA 2.0  ·  PC LAUNCHER", 32, C_TEXT)
	vbox_title.add_child(lbl_titulo)

	var lbl_sub := _crear_label("SISTEMA DE ACTUALIZACION Y ARRANQUE DIRECTO", 14, C_AMBER)
	vbox_title.add_child(lbl_sub)

	var vbox_ver := VBoxContainer.new()
	vbox_ver.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_top.add_child(vbox_ver)

	_lbl_version_local = _crear_label("LOCAL: v" + _local_version, 15, C_TEXT)
	_lbl_version_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox_ver.add_child(_lbl_version_local)

	_lbl_version_remota = _crear_label("REMOTA: --", 14, C_TEXT_MUTED)
	_lbl_version_remota.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox_ver.add_child(_lbl_version_remota)

	# ── Cuerpo Principal (Izquierda: Notas | Derecha: Pre-ajustes PC) ──
	var hbox_body := HBoxContainer.new()
	hbox_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox_body.add_theme_constant_override("separation", 18)
	vbox_main.add_child(hbox_body)

	# Panel Izquierdo: Notas de parche y ruta
	var card_notas := PanelContainer.new()
	card_notas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_notas.size_flags_stretch_ratio = 1.45
	card_notas.add_theme_stylebox_override("panel", _estilo_panel(C_CARD, C_BORDER_FROST, 12, 1, 4))
	hbox_body.add_child(card_notas)

	var m_notas := MarginContainer.new()
	m_notas.add_theme_constant_override("margin_left", 20)
	m_notas.add_theme_constant_override("margin_right", 20)
	m_notas.add_theme_constant_override("margin_top", 18)
	m_notas.add_theme_constant_override("margin_bottom", 18)
	card_notas.add_child(m_notas)

	var v_notas := VBoxContainer.new()
	v_notas.add_theme_constant_override("separation", 10)
	m_notas.add_child(v_notas)

	v_notas.add_child(_crear_label("NOTAS DE LA VERSION / NOVEDADES", 20, C_AMBER))

	_lbl_notas = RichTextLabel.new()
	_lbl_notas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_notas.bbcode_enabled = true
	_lbl_notas.add_theme_font_override("normal_font", FONT_MODERNIZ)
	_lbl_notas.add_theme_font_size_override("normal_font_size", 16)
	_lbl_notas.add_theme_color_override("default_color", C_TEXT)
	_lbl_notas.text = "• Modo PC disponible: oculta controles tactiles manteniendo interfaces.\n• Configuraciones sincronizadas entre Menu Principal, partida y Modo Prueba.\n• Listo para iniciar o recibir parches (.pck / .zip)."
	v_notas.add_child(_lbl_notas)

	_lbl_ruta_juego = _crear_label("RUTA: " + _game_dir, 13, C_TEXT_MUTED)
	_lbl_ruta_juego.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v_notas.add_child(_lbl_ruta_juego)

	# Panel Derecho: Pre-ajustes PC y herramientas
	var card_pc := PanelContainer.new()
	card_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_pc.size_flags_stretch_ratio = 1.0
	card_pc.add_theme_stylebox_override("panel", _estilo_panel(C_CARD, C_BORDER_FROST, 12, 1, 4))
	hbox_body.add_child(card_pc)

	var m_pc := MarginContainer.new()
	m_pc.add_theme_constant_override("margin_left", 20)
	m_pc.add_theme_constant_override("margin_right", 20)
	m_pc.add_theme_constant_override("margin_top", 18)
	m_pc.add_theme_constant_override("margin_bottom", 18)
	card_pc.add_child(m_pc)

	var v_pc := VBoxContainer.new()
	v_pc.add_theme_constant_override("separation", 14)
	m_pc.add_child(v_pc)

	v_pc.add_child(_crear_label("PRE-AJUSTES PARA PC", 20, C_AMBER))
	v_pc.add_child(_crear_label("Se guardan directo en settings.cfg antes de abrir el juego.", 13, C_TEXT_MUTED))

	_btn_modo_pc = _crear_boton("", 18, false)
	_btn_modo_pc.custom_minimum_size.y = 48
	_btn_modo_pc.pressed.connect(_on_toggle_modo_pc)
	v_pc.add_child(_btn_modo_pc)

	v_pc.add_child(_crear_label("CALIDAD GRAFICA INICIAL", 15, C_TEXT))
	var hbox_presets := HBoxContainer.new()
	hbox_presets.add_theme_constant_override("separation", 8)
	v_pc.add_child(hbox_presets)

	var nombres_preset := ["BAJO", "MEDIO", "ALTO", "ULTRA"]
	for i in range(nombres_preset.size()):
		var b := _crear_boton(nombres_preset[i], 15, false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 42
		b.pressed.connect(func(): _on_select_preset(i))
		hbox_presets.add_child(b)
		_preset_buttons.append(b)

	var sep := HSeparator.new()
	v_pc.add_child(sep)

	v_pc.add_child(_crear_label("UTILIDADES DE INSTALACION", 15, C_TEXT))

	var grid_tools := GridContainer.new()
	grid_tools.columns = 2
	grid_tools.add_theme_constant_override("h_separation", 8)
	grid_tools.add_theme_constant_override("v_separation", 8)
	v_pc.add_child(grid_tools)

	_btn_buscar_updates = _crear_boton("BUSCAR PARCHES", 14, false)
	_btn_buscar_updates.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_buscar_updates.custom_minimum_size.y = 42
	_btn_buscar_updates.pressed.connect(_consultar_manifest_remoto)
	grid_tools.add_child(_btn_buscar_updates)

	_btn_reparar = _crear_boton("VERIFICAR / REPARAR", 14, false)
	_btn_reparar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_reparar.custom_minimum_size.y = 42
	_btn_reparar.pressed.connect(_on_reparar_pressed)
	grid_tools.add_child(_btn_reparar)

	_btn_ubicar = _crear_boton("UBICAR .EXE", 14, false)
	_btn_ubicar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_ubicar.custom_minimum_size.y = 42
	_btn_ubicar.pressed.connect(_on_ubicar_exe_pressed)
	grid_tools.add_child(_btn_ubicar)

	_btn_abrir_carpeta = _crear_boton("ABRIR CARPETA", 14, false)
	_btn_abrir_carpeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_abrir_carpeta.custom_minimum_size.y = 42
	_btn_abrir_carpeta.pressed.connect(_on_abrir_carpeta_pressed)
	grid_tools.add_child(_btn_abrir_carpeta)

	# ── Footer: Progreso + Botón JUGAR ──
	var card_footer := PanelContainer.new()
	card_footer.add_theme_stylebox_override("panel", _estilo_panel(C_CARD, C_BORDER_FROST, 12, 1, 4))
	vbox_main.add_child(card_footer)

	var m_foot := MarginContainer.new()
	m_foot.add_theme_constant_override("margin_left", 20)
	m_foot.add_theme_constant_override("margin_right", 20)
	m_foot.add_theme_constant_override("margin_top", 14)
	m_foot.add_theme_constant_override("margin_bottom", 14)
	card_footer.add_child(m_foot)

	var hbox_foot := HBoxContainer.new()
	hbox_foot.add_theme_constant_override("separation", 18)
	m_foot.add_child(hbox_foot)

	var vbox_prog := VBoxContainer.new()
	vbox_prog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_prog.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_prog.add_theme_constant_override("separation", 6)
	hbox_foot.add_child(vbox_prog)

	var hbox_status := HBoxContainer.new()
	vbox_prog.add_child(hbox_status)

	_lbl_estado = _crear_label("LISTO", 15, C_TEXT)
	_lbl_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_status.add_child(_lbl_estado)

	_lbl_progreso = _crear_label("", 14, C_AMBER)
	_lbl_progreso.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox_status.add_child(_lbl_progreso)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 14
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 100.0
	_progress_bar.value = 100.0
	_estilar_progressbar(_progress_bar)
	vbox_prog.add_child(_progress_bar)

	_btn_accion_principal = _crear_boton("JUGAR", 24, true)
	_btn_accion_principal.custom_minimum_size = Vector2(240, 58)
	_btn_accion_principal.pressed.connect(_on_accion_principal_pressed)
	hbox_foot.add_child(_btn_accion_principal)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.exe ; Ejecutable del juego"])
	_file_dialog.file_selected.connect(_on_exe_seleccionado)
	add_child(_file_dialog)

	_refrescar_botones_pc()


func _configurar_red() -> void:
	_http_manifest = HTTPRequest.new()
	_http_manifest.timeout = 10.0
	_http_manifest.request_completed.connect(_on_manifest_recibido)
	add_child(_http_manifest)

	_http_download = HTTPRequest.new()
	_http_download.use_threads = true
	_http_download.request_completed.connect(_on_descarga_completada)
	add_child(_http_download)


func _animar_entrada() -> void:
	if not _root_card:
		return
	_root_card.pivot_offset = _root_card.size * 0.5
	_root_card.scale = Vector2(0.95, 0.95)
	_root_card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root_card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if _is_downloading and _http_download:
		var total := _http_download.get_body_size()
		var bajado := _http_download.get_downloaded_bytes()
		if total > 0:
			var pct := clampf(float(bajado) / float(total) * 100.0, 0.0, 100.0)
			_progress_bar.value = pct
			_lbl_progreso.text = "%.1f / %.1f MB (%.0f%%)" % [bajado / 1048576.0, total / 1048576.0, pct]
		else:
			_lbl_progreso.text = "%.1f MB..." % (bajado / 1048576.0)


# ── Lógica de Actualización y Verificación ────────────────────────────────────

func _consultar_manifest_remoto() -> void:
	var url := str(_cfg_app.get("manifest_url", "")).strip_edges()
	if url.is_empty():
		_lbl_version_remota.text = "REMOTA: MODO LOCAL"
		_actualizar_estado_ui()
		return
	_lbl_estado.text = "BUSCANDO ACTUALIZACIONES..."
	_http_manifest.cancel_request()
	var err := _http_manifest.request(url)
	if err != OK:
		_lbl_estado.text = "SIN CONEXION (MODO LOCAL)"


func _on_manifest_recibido(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_lbl_version_remota.text = "REMOTA: SIN CONEXION"
		_auto_download_on_manifest = false
		_actualizar_estado_ui()
		if result != HTTPRequest.RESULT_SUCCESS or response_code == 404:
			_lbl_estado.text = "NO SE ENCONTRO EL MANIFEST EN EL SERVIDOR (HTTP %d)" % response_code
		return

	var txt := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		_lbl_version_remota.text = "REMOTA: MANIFEST INVALIDO"
		_auto_download_on_manifest = false
		_actualizar_estado_ui()
		return

	_remote_manifest = parsed
	var remote_ver := str(_remote_manifest.get("version", _local_version))
	_lbl_version_remota.text = "REMOTA: v" + remote_ver

	var notas = _remote_manifest.get("notas_parche", [])
	if typeof(notas) == TYPE_ARRAY and notas.size() > 0:
		var lines: PackedStringArray = []
		for n in notas:
			lines.append("• " + str(n))
		_lbl_notas.text = "\n".join(lines)
	elif typeof(notas) == TYPE_STRING and not str(notas).is_empty():
		_lbl_notas.text = str(notas)

	var exe_exists := FileAccess.file_exists(_game_dir.path_join(str(_cfg_app.get("game_exe_name", "NuestraTierra.exe"))))
	_update_available = (not exe_exists) or _version_es_mayor(remote_ver, _local_version)
	_actualizar_estado_ui()
	if _auto_download_on_manifest:
		_auto_download_on_manifest = false
		_iniciar_descarga_actualizacion()


func _version_es_mayor(remota: String, local: String) -> bool:
	var r := remota.strip_edges().split(".")
	var l := local.strip_edges().split(".")
	var max_len := maxi(r.size(), l.size())
	for i in range(max_len):
		var rv := int(r[i]) if i < r.size() else 0
		var lv := int(l[i]) if i < l.size() else 0
		if rv > lv:
			return true
		if rv < lv:
			return false
	return false


func _iniciar_descarga_actualizacion() -> void:
	if _is_downloading:
		return
	var zip_url := str(_remote_manifest.get("zip_url", "")).strip_edges()
	var pck_url := str(_remote_manifest.get("pck_url", "")).strip_edges()
	var url_final := zip_url if not zip_url.is_empty() else pck_url
	if url_final.is_empty():
		_lbl_estado.text = "NO HAY URL DE DESCARGA EN EL MANIFEST"
		return

	_download_is_zip = not zip_url.is_empty()
	var ext := ".zip.tmp" if _download_is_zip else ".pck.tmp"
	_download_target_path = _game_dir.path_join("update_download" + ext)
	DirAccess.make_dir_recursive_absolute(_game_dir)

	_http_download.download_file = _download_target_path
	_is_downloading = true
	_btn_accion_principal.disabled = true
	_progress_bar.value = 0.0
	_lbl_estado.text = "DESCARGANDO ACTUALIZACION..."
	var err := _http_download.request(url_final)
	if err != OK:
		_is_downloading = false
		_btn_accion_principal.disabled = false
		_lbl_estado.text = "ERROR AL INICIAR DESCARGA (%d)" % err


func _on_descarga_completada(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_is_downloading = false
	_btn_accion_principal.disabled = false
	_lbl_progreso.text = ""

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_lbl_estado.text = "DESCARGA FALLIDA (HTTP %d)" % response_code
		return

	var expected_sha := str(_remote_manifest.get("sha256", "")).strip_edges().to_lower()
	if not expected_sha.is_empty():
		var actual_sha := _calcular_sha256(_download_target_path)
		if actual_sha != expected_sha:
			DirAccess.remove_absolute(_download_target_path)
			_lbl_estado.text = "ERROR DE INTEGRIDAD (SHA-256 NO COINCIDE)"
			return

	if _download_is_zip:
		if not _extraer_zip(_download_target_path, _game_dir):
			_lbl_estado.text = "ERROR AL DESCOMPRIMIR ACTUALIZACION"
			return
		DirAccess.remove_absolute(_download_target_path)
	else:
		var pck_dest := _game_dir.path_join(str(_cfg_app.get("game_pck_name", "NuestraTierra.pck")))
		if FileAccess.file_exists(pck_dest):
			DirAccess.remove_absolute(pck_dest)
		DirAccess.rename_absolute(_download_target_path, pck_dest)

	var new_ver := str(_remote_manifest.get("version", _local_version))
	_escribir_version_local(new_ver)
	_update_available = false
	_progress_bar.value = 100.0
	_actualizar_estado_ui()
	_lbl_estado.text = "ACTUALIZADO A v" + new_ver


func _calcular_sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(65536))
	f.close()
	return ctx.finish().hex_encode().to_lower()


func _extraer_zip(zip_path: String, dest_dir: String) -> bool:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return false
	for entry in reader.get_files():
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(dest_dir.path_join(entry))
			continue
		var out_path := dest_dir.path_join(entry)
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var data := reader.read_file(entry)
		var out_f := FileAccess.open(out_path, FileAccess.WRITE)
		if out_f:
			out_f.store_buffer(data)
			out_f.close()
	reader.close()
	return true


# ── Acciones de Botones ───────────────────────────────────────────────────────

func _actualizar_estado_ui() -> void:
	_lbl_version_local.text = "LOCAL: v" + _local_version
	_lbl_ruta_juego.text = "RUTA: " + _game_dir

	var exe_exists := FileAccess.file_exists(_game_dir.path_join(str(_cfg_app.get("game_exe_name", "NuestraTierra.exe"))))
	if not exe_exists:
		_btn_accion_principal.text = "DESCARGAR JUEGO"
		_lbl_estado.text = "JUEGO NO INSTALADO — LISTO PARA DESCARGAR"
		_progress_bar.value = 0.0
	elif _update_available:
		_btn_accion_principal.text = "ACTUALIZAR"
		_lbl_estado.text = "NUEVA VERSION DISPONIBLE"
		_progress_bar.value = 0.0
	else:
		_btn_accion_principal.text = "JUGAR"
		_lbl_estado.text = "LISTO PARA JUGAR"
		_progress_bar.value = 100.0


func _on_accion_principal_pressed() -> void:
	var exe_path := _game_dir.path_join(str(_cfg_app.get("game_exe_name", "NuestraTierra.exe")))
	var exe_exists := FileAccess.file_exists(exe_path)
	if not exe_exists or _update_available:
		if _remote_manifest.is_empty():
			var url := str(_cfg_app.get("manifest_url", "")).strip_edges()
			if url.is_empty():
				_lbl_estado.text = "FALTA CONFIGURAR manifest_url EN launcher_config.json"
				return
			_auto_download_on_manifest = true
			_consultar_manifest_remoto()
			return
		_iniciar_descarga_actualizacion()
		return
	_lanzar_juego(exe_path)


func _lanzar_juego(exe_path: String) -> void:
	_guardar_ajustes_juego()
	var pid := OS.create_process(exe_path, [])
	if pid <= 0:
		_lbl_estado.text = "NO SE PUDO INICIAR EL EJECUTABLE"
		return
	get_tree().quit()


func _on_toggle_modo_pc() -> void:
	_modo_pc_activo = not _modo_pc_activo
	_guardar_ajustes_juego()
	_refrescar_botones_pc()


func _on_select_preset(idx: int) -> void:
	_calidad_actual = idx
	_guardar_ajustes_juego()
	_refrescar_botones_pc()


func _refrescar_botones_pc() -> void:
	if _btn_modo_pc:
		_btn_modo_pc.text = "MODO PC (SIN TACTIL): ACTIVADO" if _modo_pc_activo else "MODO PC (SIN TACTIL): DESACTIVADO"
		var borde := C_GREEN if _modo_pc_activo else C_BORDER_FROST
		_btn_modo_pc.add_theme_stylebox_override("normal", _estilo_panel(C_BTN, borde, 8, 1, 2))
		_btn_modo_pc.add_theme_color_override("font_color", C_GREEN if _modo_pc_activo else C_TEXT_MUTED)

	for i in range(_preset_buttons.size()):
		var activo := (i == _calidad_actual)
		var bg := C_AMBER_DIM if activo else C_BTN
		var br := C_AMBER if activo else C_BORDER_FROST
		_preset_buttons[i].add_theme_stylebox_override("normal", _estilo_panel(bg, br, 8, 1, 2))
		_preset_buttons[i].add_theme_color_override("font_color", C_AMBER if activo else C_TEXT)


func _on_reparar_pressed() -> void:
	var exe_ok := FileAccess.file_exists(_game_dir.path_join(str(_cfg_app.get("game_exe_name", "NuestraTierra.exe"))))
	var pck_ok := FileAccess.file_exists(_game_dir.path_join(str(_cfg_app.get("game_pck_name", "NuestraTierra.pck"))))
	if exe_ok and pck_ok:
		var sha := str(_remote_manifest.get("sha256", "")).strip_edges().to_lower()
		if not sha.is_empty():
			var pck_path := _game_dir.path_join(str(_cfg_app.get("game_pck_name", "NuestraTierra.pck")))
			if _calcular_sha256(pck_path) != sha:
				_lbl_estado.text = "ARCHIVO .PCK CORRUPTO — RE-DESCARGANDO..."
				_iniciar_descarga_actualizacion()
				return
		_lbl_estado.text = "ARCHIVOS VERIFICADOS CORRECTAMENTE"
	else:
		_lbl_estado.text = "FALTAN ARCHIVOS (.EXE O .PCK) EN LA RUTA"


func _on_ubicar_exe_pressed() -> void:
	if _file_dialog:
		_file_dialog.current_dir = _game_dir
		_file_dialog.popup_centered(Vector2i(760, 480))


func _on_exe_seleccionado(path: String) -> void:
	_cfg_app["game_exe_name"] = path.get_file()
	_guardar_ruta_juego(path.get_base_dir())
	_leer_version_local()
	_actualizar_estado_ui()


func _on_abrir_carpeta_pressed() -> void:
	if DirAccess.dir_exists_absolute(_game_dir):
		OS.shell_open(_game_dir)


# ── Helpers de Estilo ─────────────────────────────────────────────────────────

func _crear_label(texto: String, tamano: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", FONT_MODERNIZ)
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	return l


func _crear_boton(texto: String, tamano: int, es_primario: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_override("font", FONT_MODERNIZ)
	b.add_theme_font_size_override("font_size", tamano)
	var bg_n := C_AMBER if es_primario else C_BTN
	var bg_h := Color(0.96, 0.76, 0.34, 1.0) if es_primario else Color(0.14, 0.16, 0.19, 0.95)
	var fg := Color(0.08, 0.07, 0.05, 1.0) if es_primario else C_TEXT
	b.add_theme_stylebox_override("normal", _estilo_panel(bg_n, C_AMBER if es_primario else C_BORDER_FROST, 10, 1, 4))
	b.add_theme_stylebox_override("hover", _estilo_panel(bg_h, C_AMBER, 10, 1, 5))
	b.add_theme_stylebox_override("pressed", _estilo_panel(C_AMBER, C_AMBER, 10, 1, 2))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.05, 0.04, 1.0) if es_primario else C_TEXT)
	b.add_theme_color_override("font_pressed_color", Color(0.06, 0.05, 0.04, 1.0))
	return b


func _estilo_panel(bg: Color, border: Color, radius: int, border_w: int, shadow: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = shadow
	return sb


func _estilar_progressbar(pb: ProgressBar) -> void:
	pb.add_theme_stylebox_override("background", _estilo_panel(Color(0.04, 0.05, 0.06, 0.95), C_BORDER_FROST, 6, 1, 0))
	pb.add_theme_stylebox_override("fill", _estilo_panel(C_AMBER, C_AMBER, 6, 0, 0))
