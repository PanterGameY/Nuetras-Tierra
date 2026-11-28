extends CanvasLayer
class_name PantallaCargaOnline

## PantallaCargaOnline.gd — Pantalla de carga Glassmorphic para Online WebRTC
## Muestra un contador grande de 10 a 1 mientras carga la escena en segundo plano,
## oscurece suavemente la pantalla al terminar y revela el juego ya listo.

const FONT_MODERNIZ := preload("res://recursos/fonts/Moderniz.otf")

var _escena_destino: String = ""
var _nombre_mapa: String = ""
var _tiempo_restante: float = 10.0
var _ultimo_numero: int = 10
var _escena_cargada: bool = false
var _escena_cambiada: bool = false
var _frames_post_cambio: int = 0
var _finalizando: bool = false
var _precarga_rutas: Array[String] = []
var _precarga_refs: Array = []

var _fondo: ColorRect = null
var _panel: PanelContainer = null
var _lbl_titulo: Label = null
var _lbl_subtitulo: Label = null
var _lbl_contador: Label = null
var _lbl_estado: Label = null
var _barra: ProgressBar = null
var _cortina_negra: ColorRect = null

func iniciar_carga(escena_destino: String, nombre_mapa: String = "") -> void:
	_escena_destino = escena_destino
	_nombre_mapa = nombre_mapa.strip_edges()
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_ui()

	if _escena_destino != "":
		var err := ResourceLoader.load_threaded_request(_escena_destino, "", true)
		if err != OK:
			push_warning("[PantallaCargaOnline] Fallback a carga directa (err=%d)" % err)
			_escena_cargada = true
			get_tree().change_scene_to_file(_escena_destino)
			_escena_cambiada = true
		for extra in [
			"res://modelos3d/personajes/Jugador/Jugador.tscn",
			"res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
			"res://modelos3d/personajes/Jugador/jugador_voxel_remoto.glb"
		]:
			if ResourceLoader.exists(extra) and ResourceLoader.load_threaded_request(extra, "", true) == OK:
				_precarga_rutas.append(extra)

func _construir_ui() -> void:
	_fondo = ColorRect.new()
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.color = Color(0.04, 0.05, 0.06, 1.0)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(920, 480)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.94)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.81, 0.85, 0.24)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0, 0, 0, 0.70)
	sb.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 42)
	mc.add_theme_constant_override("margin_right", 42)
	mc.add_theme_constant_override("margin_top", 34)
	mc.add_theme_constant_override("margin_bottom", 34)
	_panel.add_child(mc)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	mc.add_child(vb)

	_lbl_titulo = Label.new()
	_lbl_titulo.text = "CARGANDO RUTA MULTIJUGADOR"
	_lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_titulo.add_theme_font_override("font", FONT_MODERNIZ)
	_lbl_titulo.add_theme_font_size_override("font_size", 36)
	_lbl_titulo.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	vb.add_child(_lbl_titulo)

	_lbl_subtitulo = Label.new()
	_lbl_subtitulo.text = ("MAPA: " + _nombre_mapa.to_upper()) if _nombre_mapa != "" else "MUNDO PRINCIPAL • WEBRTC P2P"
	_lbl_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_subtitulo.add_theme_font_override("font", FONT_MODERNIZ)
	_lbl_subtitulo.add_theme_font_size_override("font_size", 22)
	_lbl_subtitulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
	vb.add_child(_lbl_subtitulo)

	_lbl_contador = Label.new()
	_lbl_contador.text = "10"
	_lbl_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_contador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_contador.custom_minimum_size = Vector2(0, 170)
	_lbl_contador.add_theme_font_override("font", FONT_MODERNIZ)
	_lbl_contador.add_theme_font_size_override("font_size", 132)
	_lbl_contador.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	_lbl_contador.pivot_offset = Vector2(418, 85)
	vb.add_child(_lbl_contador)

	_barra = ProgressBar.new()
	_barra.min_value = 0.0
	_barra.max_value = 100.0
	_barra.value = 0.0
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(0, 14)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.11, 0.13, 0.16, 0.95)
	sb_bg.corner_radius_top_left = 7; sb_bg.corner_radius_top_right = 7
	sb_bg.corner_radius_bottom_left = 7; sb_bg.corner_radius_bottom_right = 7
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.88, 0.68, 0.28, 0.95)
	sb_fill.corner_radius_top_left = 7; sb_fill.corner_radius_top_right = 7
	sb_fill.corner_radius_bottom_left = 7; sb_fill.corner_radius_bottom_right = 7
	_barra.add_theme_stylebox_override("background", sb_bg)
	_barra.add_theme_stylebox_override("fill", sb_fill)
	vb.add_child(_barra)

	_lbl_estado = Label.new()
	_lbl_estado.text = "Cargando mapa y recursos en segundo plano..."
	_lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_estado.add_theme_font_size_override("font_size", 20)
	_lbl_estado.add_theme_color_override("font_color", Color(0.75, 0.79, 0.84, 0.92))
	vb.add_child(_lbl_estado)

	_cortina_negra = ColorRect.new()
	_cortina_negra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina_negra.color = Color(0.0, 0.0, 0.0, 1.0)
	_cortina_negra.modulate.a = 0.0
	_cortina_negra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina_negra)

	# Transición suave de entrada
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.pivot_offset = Vector2(460, 240)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _finalizando:
		return

	# 1. Consultar progreso real en segundo plano (con sub-hilos para evitar tirones)
	for ruta_ex in _precarga_rutas.duplicate():
		var st_ex := ResourceLoader.load_threaded_get_status(ruta_ex)
		if st_ex == ResourceLoader.THREAD_LOAD_LOADED:
			_precarga_refs.append(ResourceLoader.load_threaded_get(ruta_ex))
			_precarga_rutas.erase(ruta_ex)
		elif st_ex == ResourceLoader.THREAD_LOAD_FAILED or st_ex == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_precarga_rutas.erase(ruta_ex)

	if not _escena_cargada and _escena_destino != "":
		var prog := []
		var status := ResourceLoader.load_threaded_get_status(_escena_destino, prog)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_escena_cargada = true
			var packed := ResourceLoader.load_threaded_get(_escena_destino) as PackedScene
			if packed and not _escena_cambiada:
				_escena_cambiada = true
				get_tree().change_scene_to_packed(packed)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_escena_cargada = true
			if not _escena_cambiada:
				_escena_cambiada = true
				get_tree().change_scene_to_file(_escena_destino)

	if _escena_cambiada:
		_frames_post_cambio += 1

	# 2. Avanzar contador de 10 a 1 (si aún está cargando al llegar a 1, espera en "1" hasta terminar)
	var paso := clampf(delta, 0.0, 0.05)
	if _tiempo_restante > 1.0 or (_escena_cargada and _escena_cambiada and _frames_post_cambio >= 10):
		_tiempo_restante = maxf(0.0, _tiempo_restante - paso)

	var num_actual := clampi(int(ceilf(_tiempo_restante)), 1, 10)
	if num_actual != _ultimo_numero:
		_ultimo_numero = num_actual
		_lbl_contador.text = str(num_actual)
		_lbl_contador.scale = Vector2(1.22, 1.22)
		var tw_num := create_tween()
		tw_num.tween_property(_lbl_contador, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		if num_actual >= 7:
			_lbl_estado.text = "Cargando escenario y vehículos en segundo plano..."
		elif num_actual >= 4:
			_lbl_estado.text = "Sincronizando jugadores y terreno P2P..."
		elif num_actual >= 2:
			_lbl_estado.text = "Estabilizando físicas y cámara..."
		else:
			_lbl_estado.text = "¡Casi listo! Preparando entrada a la ruta..."

	_barra.value = clampf(((10.0 - _tiempo_restante) / 10.0) * 100.0, 0.0, 100.0)

	# 3. Cuando terminó el conteo (0.0s) Y la escena ya cargó, oscurecer y revelar el juego
	if _tiempo_restante <= 0.0 and _escena_cargada and _escena_cambiada and _frames_post_cambio >= 10:
		_finalizar_con_oscurecimiento()

func _finalizar_con_oscurecimiento() -> void:
	_finalizando = true
	_barra.value = 100.0
	_lbl_estado.text = "¡Ruta lista!"
	var tw := create_tween()
	# Oscurece la pantalla por completo encima de la tarjeta
	tw.tween_property(_cortina_negra, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if is_instance_valid(_fondo):
			_fondo.visible = false
	)
	tw.tween_interval(0.15)
	# Desvanece el negro para revelar el juego ya cargado debajo
	tw.tween_property(_cortina_negra, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		queue_free()
	)
