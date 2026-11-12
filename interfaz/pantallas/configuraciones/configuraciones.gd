extends CanvasLayer

const SAVE_PATH = "user://settings.cfg"
const FONT = preload("res://recursos/fonts/Moderniz.otf")
const VOLANTE_TEX = preload("res://interfaz/hud/conduccion/imagenes/volante2.png")

# --- SONIDOS PARA EL AUDIO TESTER ---
const SND_CLAXON = preload("res://recursos/sonidos_vehiculo/motor/automovil/claxon 1.mp3")
const SND_MOTOR = preload("res://recursos/sonidos_vehiculo/motor/automovil/encendido_automovil.mp3")
const SND_FRENO = preload("res://recursos/sonidos_vehiculo/efectos/Hidraulico.mp3")

# --- REFERENCIAS A NODOS BASE ---
@onready var opt_calidad: OptionButton = find_child("OptCalidad", true, false)
@onready var opt_cielo: OptionButton = find_child("OptCielo", true, false)
@onready var opt_sombras: OptionButton = find_child("OptSombras", true, false)
@onready var opt_aa: OptionButton = find_child("OptAA", true, false)
@onready var chk_vsync: CheckButton = find_child("ChkVsync", true, false)
@onready var slider_render: HSlider = find_child("SliderRender", true, false)
@onready var lbl_render_val: Label = find_child("LblRenderVal", true, false)
@onready var opt_fps: OptionButton = find_child("OptFPS", true, false)

@onready var slider_vol: HSlider = find_child("SliderVolGen", true, false)
@onready var lbl_vol: Label = find_child("LblVolGenVal", true, false)
@onready var slider_musica: HSlider = find_child("SliderMusica", true, false)
@onready var lbl_musica: Label = find_child("LblMusicaVal", true, false)
@onready var slider_efectos: HSlider = find_child("SliderEfectos", true, false)
@onready var lbl_efectos: Label = find_child("LblEfectosVal", true, false)

@onready var btn_aplicar: Button = find_child("BtnAplicar", true, false)
@onready var btn_volver: Button = find_child("BtnVolver", true, false)
@onready var btn_salir_menu: Button = find_child("BtnSalirMenu", true, false)
@onready var btn_restablecer: Button = find_child("BtnRestablecer", true, false)

@onready var btn_tab_graficos: Button = find_child("BtnTabGraficos", true, false)
@onready var btn_tab_sonido: Button = find_child("BtnTabSonido", true, false)
@onready var btn_tab_controles: Button = find_child("BtnTabControles", true, false)
@onready var btn_tab_demas: Button = find_child("BtnTabDemas", true, false)

@onready var pagina_graficos: VBoxContainer = find_child("PaginaGraficos", true, false)
@onready var pagina_sonido: VBoxContainer = find_child("PaginaSonido", true, false)
@onready var pagina_controles: VBoxContainer = find_child("PaginaControles", true, false)
@onready var pagina_demas: VBoxContainer = find_child("PaginaDemas", true, false)
@onready var scroll_contenido: ScrollContainer = find_child("ScrollContenido", true, false)

@onready var vbox_inspector: VBoxContainer = find_child("VBoxInspector", true, false)
@onready var audio_tester: AudioStreamPlayer = get_node_or_null("AudioTesterPlayer")

# --- VARIABLES DE CONTROLES DINAMICOS ---
var slider_volante: HSlider = null
var lbl_volante_val: Label = null
var slider_suavizado_dir: HSlider = null
var lbl_suavizado_dir_val: Label = null
var slider_retorno_vol: HSlider = null
var lbl_retorno_vol_val: Label = null
var slider_suavizado_ped: HSlider = null
var lbl_suavizado_ped_val: Label = null

var chk_city_opt: CheckButton = null
var slider_city_dist: HSlider = null
var lbl_city_dist_val: Label = null
var row_city_dist_container: Control = null

var chk_ssao: CheckButton = null
var chk_glow: CheckButton = null
var chk_sdfgi: CheckButton = null

# --- DICCIONARIO DE SELECTORES PILL ---
var pill_groups: Dictionary = {}

# --- INSPECTOR NODES ---
var inspector_graficos: VBoxContainer = null
var inspector_audio: VBoxContainer = null
var inspector_controles: VBoxContainer = null
var inspector_demas: VBoxContainer = null

# Inspector Graficos Elements
var bar_gpu_load: ProgressBar = null
var lbl_gpu_score: Label = null
var badge_target_fps: PanelContainer = null
var lbl_target_fps: Label = null
var badge_battery: PanelContainer = null
var lbl_battery: Label = null
var lbl_active_preset_name: Label = null
var lbl_active_preset_info: Label = null
var list_checklist: VBoxContainer = null

# Inspector Audio Elements
var vu_bars: Array[ColorRect] = []
var vu_timer: float = 0.0
var vu_anim_active: bool = false

# Inspector Controles Elements
var wheel_rect: TextureRect = null
var wheel_angle: float = 0.0
var wheel_target_angle: float = 0.0
var wheel_is_dragging: bool = false
var lbl_wheel_angle: Label = null
var bar_test_brake: ProgressBar = null
var bar_test_accel: ProgressBar = null

# Inspector Opt Elements
var lbl_radar_dist: Label = null
var lbl_mem_savings: Label = null

func _ready() -> void:
	if not visible:
		return
	
	_populate_options()
	_construir_dashboard_interactivo()
	_construir_panel_inspector()
	_style_tab_buttons()
	_style_scrollbar()
	_load_settings()
	_apply_settings()
	_connect_signals()
	_apply_controls_settings()
	_switch_tab(0)
	
	# Transicion suave de entrada
	var panel_princ = find_child("PanelPrincipal", true, false) as Control
	if panel_princ:
		panel_princ.scale = Vector2(0.95, 0.95)
		panel_princ.pivot_offset = panel_princ.size * 0.5
		panel_princ.modulate.a = 0.0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(panel_princ, "scale", Vector2.ONE, 0.28)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
		tw.tween_property(panel_princ, "modulate:a", 1.0, 0.22)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	# Animar medidor VU si hay sonido en reproduccion
	if vu_anim_active and vu_bars.size() > 0:
		vu_timer += delta * 15.0
		for i in range(vu_bars.size()):
			var noise_val = sin(vu_timer + i * 0.4) * 0.5 + 0.5
			var bar_h = clamp(noise_val * 48.0, 6.0, 48.0)
			vu_bars[i].custom_minimum_size.y = bar_h
			
			# Color degradado acustico: Verde -> Ambar -> Rojo
			if i < 8:
				vu_bars[i].color = Color(0.2, 0.85, 0.4, 0.9)
			elif i < 12:
				vu_bars[i].color = Color(0.88, 0.68, 0.28, 0.95)
			else:
				vu_bars[i].color = Color(0.88, 0.32, 0.28, 1.0)
	elif not vu_anim_active and vu_bars.size() > 0:
		for bar in vu_bars:
			bar.custom_minimum_size.y = 6.0
			bar.color = Color(0.25, 0.28, 0.32, 0.5)

	# Fisica de retorno para el volante interactivo
	if wheel_rect and not wheel_is_dragging:
		var k_retorno = slider_retorno_vol.value if slider_retorno_vol else 3.5
		wheel_angle = lerp(wheel_angle, 0.0, clamp(delta * k_retorno * 1.5, 0.0, 1.0))
		wheel_rect.rotation_degrees = wheel_angle
		if lbl_wheel_angle:
			lbl_wheel_angle.text = "GIRO: %.1f DEG" % wheel_angle

func _populate_options() -> void:
	if opt_calidad.item_count == 0:
		opt_calidad.add_item("BAJA")
		opt_calidad.add_item("MEDIA")
		opt_calidad.add_item("ALTA")
		opt_calidad.add_item("ULTRA")

	if opt_cielo.item_count == 0:
		opt_cielo.add_item("MOVIL")
		opt_cielo.add_item("MEDIO")
		opt_cielo.add_item("ALTO")
		opt_cielo.add_item("ULTRA")

	if opt_sombras.item_count == 0:
		opt_sombras.add_item("DESACTIVADAS")
		opt_sombras.add_item("BAJA")
		opt_sombras.add_item("MEDIA")
		opt_sombras.add_item("ALTA")

	if opt_aa.item_count == 0:
		opt_aa.add_item("OFF")
		opt_aa.add_item("FXAA")
		opt_aa.add_item("2X")
		opt_aa.add_item("4X")
		opt_aa.add_item("8X")

	if opt_fps.item_count == 0:
		opt_fps.add_item("30")
		opt_fps.add_item("60")
		opt_fps.add_item("90")
		opt_fps.add_item("120")
		opt_fps.add_item("MAX")

# =======================================================================
# CONSTRUCCION DE LA COLUMNA IZQUIERDA: TARJETAS Y SELECTORES TACTILES
# =======================================================================
func _construir_dashboard_interactivo() -> void:
	for pagina in [pagina_graficos, pagina_sonido, pagina_controles, pagina_demas]:
		if pagina:
			for child in pagina.get_children():
				child.queue_free()

	var grabber_tex = _crear_textura_grabber(20, Color(0.88, 0.68, 0.28), Color(0.78, 0.81, 0.85))

	for ctrl in [opt_calidad, opt_cielo, opt_sombras, opt_aa, chk_vsync, slider_render, lbl_render_val, opt_fps, slider_vol, lbl_vol, slider_musica, lbl_musica, slider_efectos, lbl_efectos]:
		if ctrl and ctrl.get_parent():
			ctrl.get_parent().remove_child(ctrl)

	# --- PAGINA 1: GRAFICOS ---
	# 1. Presets Globales
	var presets_pills = _crear_selector_pills("presets", ["BAJO", "MEDIO", "ALTO", "ULTRA"], 1, func(idx):
		_aplicar_preset_global(idx)
	)
	var card_presets = _crear_tarjeta("AJUSTES PREESTABLECIDOS RAPIDOS", "PRESETS", [presets_pills])
	pagina_graficos.add_child(card_presets)

	# 2. Pantalla y Motor Grafico
	var p_calidad = _crear_fila_con_pills("Calidad General", "Nivel base de shaders y geometria", "calidad", ["BAJA", "MEDIA", "ALTA", "ULTRA"], opt_calidad.selected, func(idx):
		opt_calidad.selected = idx
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var p_fps = _crear_fila_con_pills("Limite de Cuadros", "Tasa maxima de refresco en Hz", "fps", ["30 FPS", "60 FPS", "90 FPS", "120 FPS", "MAXIMO"], opt_fps.selected, func(idx):
		opt_fps.selected = idx
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var p_vsync = _crear_fila_con_toggle("Sincronizacion Vertical (VSync)", "Elimina artefactos de corte de pantalla", chk_vsync.button_pressed, func(pressed):
		chk_vsync.button_pressed = pressed
		chk_vsync.text = "ACTIVO" if pressed else "DESACT."
		_actualizar_telemetria_graficos()
	)
	var p_scale = _crear_fila_slider("Escala de Renderizado (FSR 2.0)", "Resolucion 3D interna para balancear nitidez y GPU", slider_render, lbl_render_val)

	var card_motor = _crear_tarjeta("PANTALLA & RENDIMIENTO", "MOTOR 3D", [p_calidad, p_fps, p_vsync, p_scale])
	pagina_graficos.add_child(card_motor)

	# 3. Entorno e Iluminacion
	var p_cielo = _crear_fila_con_pills("Calidad del Cielo", "Resolucion de nubes y boveda celeste", "cielo", ["MOVIL", "MEDIO", "ALTO", "ULTRA"], opt_cielo.selected, func(idx):
		opt_cielo.selected = idx
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var p_sombras = _crear_fila_con_pills("Calidad de Sombras", "Filtrado suave y resolucion proyectada", "sombras", ["OFF", "BAJA", "MEDIA", "ALTA"], opt_sombras.selected, func(idx):
		opt_sombras.selected = idx
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var p_aa = _crear_fila_con_pills("Anti-Aliasing", "Suavizado de bordes aserrados", "aa", ["OFF", "FXAA", "2X", "4X", "8X"], opt_aa.selected, func(idx):
		opt_aa.selected = idx
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var card_env = _crear_tarjeta("ILUMINACION & AMBIENTACION", "ENTORNO", [p_cielo, p_sombras, p_aa])
	pagina_graficos.add_child(card_env)

	# 4. Postprocesado Optico
	if not chk_ssao: chk_ssao = CheckButton.new()
	if not chk_glow: chk_glow = CheckButton.new()
	if not chk_sdfgi: chk_sdfgi = CheckButton.new()

	var p_ssao = _crear_fila_con_toggle("Oclusion Ambiental (SSAO)", "Sombras de contacto realistas en hendiduras", chk_ssao.button_pressed, func(pressed):
		chk_ssao.button_pressed = pressed
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var p_glow = _crear_fila_con_toggle("Resplandor Optico (Glow)", "Destellos luminicos en faros de tractomulas", chk_glow.button_pressed, func(pressed):
		chk_glow.button_pressed = pressed
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var p_sdfgi = _crear_fila_con_toggle("Iluminacion Global (SDFGI)", "Rebote de luz indirecta de alta fidelidad", chk_sdfgi.button_pressed, func(pressed):
		chk_sdfgi.button_pressed = pressed
		_verificar_preset_activo()
		_actualizar_telemetria_graficos()
	)
	var card_post = _crear_tarjeta("EFECTOS Y POSTPROCESADO", "OPTICA", [p_ssao, p_glow, p_sdfgi])
	pagina_graficos.add_child(card_post)

	# --- PAGINA 2: AUDIO ---
	var p_vol_gen = _crear_fila_slider("Volumen Maestro / General", "Nivel global de audio de todo el simulador", slider_vol, lbl_vol)
	var p_vol_mus = _crear_fila_slider("Musica de Radio y Menus", "Volumen de bandas sonoras y emisoras", slider_musica, lbl_musica)
	var p_vol_sfx = _crear_fila_slider("Efectos de Sonido (SFX)", "Motores diesel, frenos de aire y bocinas", slider_efectos, lbl_efectos)
	var card_audio = _crear_tarjeta("CANALES DE AUDIO & VOLUMEN", "ACUSTICA", [p_vol_gen, p_vol_mus, p_vol_sfx])
	pagina_sonido.add_child(card_audio)

	# --- PAGINA 3: CONTROLES ---
	if not slider_volante:
		slider_volante = HSlider.new()
		slider_volante.min_value = 50
		slider_volante.max_value = 300
		slider_volante.value = 150
		lbl_volante_val = Label.new()
		lbl_volante_val.text = "150%"

	if not slider_suavizado_dir:
		slider_suavizado_dir = HSlider.new()
		slider_suavizado_dir.min_value = 1.0
		slider_suavizado_dir.max_value = 25.0
		slider_suavizado_dir.step = 0.5
		slider_suavizado_dir.value = 10.0
		lbl_suavizado_dir_val = Label.new()
		lbl_suavizado_dir_val.text = "10.0"

	if not slider_retorno_vol:
		slider_retorno_vol = HSlider.new()
		slider_retorno_vol.min_value = 1.0
		slider_retorno_vol.max_value = 10.0
		slider_retorno_vol.step = 0.5
		slider_retorno_vol.value = 3.5
		lbl_retorno_vol_val = Label.new()
		lbl_retorno_vol_val.text = "3.5"

	if not slider_suavizado_ped:
		slider_suavizado_ped = HSlider.new()
		slider_suavizado_ped.min_value = 1.0
		slider_suavizado_ped.max_value = 10.0
		slider_suavizado_ped.step = 0.5
		slider_suavizado_ped.value = 3.5
		lbl_suavizado_ped_val = Label.new()
		lbl_suavizado_ped_val.text = "3.5"

	var p_sens = _crear_fila_slider("Sensibilidad del Giro", "Multiplicador de respuesta del volante", slider_volante, lbl_volante_val)
	var p_suav_dir = _crear_fila_slider("Suavizado de Direccion", "Filtra movimientos bruscos para giros progresivos", slider_suavizado_dir, lbl_suavizado_dir_val)
	var p_ret = _crear_fila_slider("Fuerza de Autocentrado", "Velocidad de retorno automatico del volante", slider_retorno_vol, lbl_retorno_vol_val)
	var card_vol = _crear_tarjeta("CALIBRACION DEL VOLANTE", "DIRECCION", [p_sens, p_suav_dir, p_ret])
	pagina_controles.add_child(card_vol)

	var p_ped = _crear_fila_slider("Suavizado de Aceleracion y Freno", "Progresion de frenada para evitar bloqueos", slider_suavizado_ped, lbl_suavizado_ped_val)
	var card_ped = _crear_tarjeta("RESPUESTA DE PEDALES", "TRACCION", [p_ped])
	pagina_controles.add_child(card_ped)

	# --- PAGINA 4: OPTIMIZACION ---
	if not chk_city_opt: chk_city_opt = CheckButton.new()
	if not slider_city_dist:
		slider_city_dist = HSlider.new()
		slider_city_dist.min_value = 50
		slider_city_dist.max_value = 600
		slider_city_dist.step = 10
		slider_city_dist.value = 200
		lbl_city_dist_val = Label.new()
		lbl_city_dist_val.text = "200m"

	var p_chunk = _crear_fila_con_toggle("Carga Modular Urbana (Chunks)", "Descarga edificios distantes para ahorrar memoria RAM", chk_city_opt.button_pressed, func(pressed):
		chk_city_opt.button_pressed = pressed
		chk_city_opt.text = "ACTIVO" if pressed else "DESACT."
		if row_city_dist_container:
			row_city_dist_container.visible = pressed
		_actualizar_telemetria_opt()
	)
	var p_dist = _crear_fila_slider("Distancia de Carga de Objetos", "Radio de dibujado de elementos 3D en el mapa", slider_city_dist, lbl_city_dist_val)
	row_city_dist_container = p_dist

	var card_opt = _crear_tarjeta("GESTION DE MEMORIA Y MAPA", "STREAMING", [p_chunk, p_dist])
	pagina_demas.add_child(card_opt)

	# Estilizar masivamente todos los sliders
	for sl in [slider_render, slider_vol, slider_musica, slider_efectos, slider_volante, slider_suavizado_dir, slider_retorno_vol, slider_suavizado_ped, slider_city_dist]:
		if sl:
			_estilizar_slider(sl, grabber_tex)

# =======================================================================
# CONSTRUCCION DE LA COLUMNA DERECHA: PANEL INSPECTOR INTERACTIVO
# =======================================================================
func _construir_panel_inspector() -> void:
	if not vbox_inspector:
		return
	for c in vbox_inspector.get_children():
		c.queue_free()

	# --- 1. INSPECTOR: GRAFICOS (Telemetria de Carga GPU / Bateria) ---
	inspector_graficos = VBoxContainer.new()
	inspector_graficos.add_theme_constant_override("separation", 16)
	
	var h_title_g = _crear_header_inspector("TELEMETRIA GRAFICA", "HARDWARE")
	inspector_graficos.add_child(h_title_g)

	# Medidor de Rendimiento Estimado
	var box_gpu := PanelContainer.new()
	var sb_gpu := StyleBoxFlat.new()
	sb_gpu.bg_color = Color(0.10, 0.12, 0.15, 0.75)
	sb_gpu.set_border_width_all(1)
	sb_gpu.border_color = Color(0.78, 0.81, 0.85, 0.15)
	sb_gpu.set_corner_radius_all(10)
	sb_gpu.set_content_margin_all(16)
	box_gpu.add_theme_stylebox_override("panel", sb_gpu)

	var v_gpu := VBoxContainer.new()
	v_gpu.add_theme_constant_override("separation", 10)

	var h_lbl_gpu := HBoxContainer.new()
	var lbl_g1 := Label.new()
	lbl_g1.text = "CARGA ESTIMADA GPU"
	lbl_g1.add_theme_font_override("font", FONT)
	lbl_g1.add_theme_font_size_override("font_size", 19)
	lbl_g1.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.9))
	lbl_g1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_lbl_gpu.add_child(lbl_g1)

	lbl_gpu_score = Label.new()
	lbl_gpu_score.text = "58%"
	lbl_gpu_score.add_theme_font_override("font", FONT)
	lbl_gpu_score.add_theme_font_size_override("font_size", 24)
	lbl_gpu_score.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	h_lbl_gpu.add_child(lbl_gpu_score)
	v_gpu.add_child(h_lbl_gpu)

	bar_gpu_load = ProgressBar.new()
	bar_gpu_load.custom_minimum_size = Vector2(0, 20)
	bar_gpu_load.value = 58
	bar_gpu_load.show_percentage = false
	var sb_bar_bg = StyleBoxFlat.new()
	sb_bar_bg.bg_color = Color(0.14, 0.16, 0.19, 0.9)
	sb_bar_bg.set_corner_radius_all(4)
	var sb_bar_fg = StyleBoxFlat.new()
	sb_bar_fg.bg_color = Color(0.88, 0.68, 0.28, 0.95)
	sb_bar_fg.set_corner_radius_all(4)
	bar_gpu_load.add_theme_stylebox_override("background", sb_bar_bg)
	bar_gpu_load.add_theme_stylebox_override("fill", sb_bar_fg)
	v_gpu.add_child(bar_gpu_load)

	# Badges de FPS y Bateria
	var h_badges := HBoxContainer.new()
	h_badges.add_theme_constant_override("separation", 10)

	badge_target_fps = _crear_badge_inspector("60 FPS FLUIDO", Color(0.88, 0.68, 0.28))
	lbl_target_fps = badge_target_fps.get_child(0) as Label
	badge_battery = _crear_badge_inspector("BATERIA: OPTIMA", Color(0.3, 0.85, 0.5))
	lbl_battery = badge_battery.get_child(0) as Label
	h_badges.add_child(badge_target_fps)
	h_badges.add_child(badge_battery)
	v_gpu.add_child(h_badges)

	box_gpu.add_child(v_gpu)
	inspector_graficos.add_child(box_gpu)

	# Tarjeta de Preset Activo
	var box_preset_info := PanelContainer.new()
	box_preset_info.add_theme_stylebox_override("panel", sb_gpu)
	var v_pinfo := VBoxContainer.new()
	v_pinfo.add_theme_constant_override("separation", 8)

	lbl_active_preset_name = Label.new()
	lbl_active_preset_name.text = "PERFIL: MEDIO (RECOMENDADO)"
	lbl_active_preset_name.add_theme_font_override("font", FONT)
	lbl_active_preset_name.add_theme_font_size_override("font_size", 21)
	lbl_active_preset_name.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	v_pinfo.add_child(lbl_active_preset_name)

	lbl_active_preset_info = Label.new()
	lbl_active_preset_info.text = "Balance optimo entre nitidez visual, estabilidad de frames y autonomia de bateria."
	lbl_active_preset_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_active_preset_info.add_theme_font_size_override("font_size", 17)
	lbl_active_preset_info.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78, 0.90))
	v_pinfo.add_child(lbl_active_preset_info)

	var sep_p := HSeparator.new()
	sep_p.modulate = Color(0.78, 0.81, 0.85, 0.15)
	v_pinfo.add_child(sep_p)

	list_checklist = VBoxContainer.new()
	list_checklist.add_theme_constant_override("separation", 6)
	v_pinfo.add_child(list_checklist)

	box_preset_info.add_child(v_pinfo)
	inspector_graficos.add_child(box_preset_info)

	vbox_inspector.add_child(inspector_graficos)

	# --- 2. INSPECTOR: AUDIO (Probador de Sonidos y VU-Meter) ---
	inspector_audio = VBoxContainer.new()
	inspector_audio.add_theme_constant_override("separation", 16)
	inspector_audio.visible = false

	var h_title_a = _crear_header_inspector("PROBADOR DE AUDIO EN VIVO", "ACUSTICA")
	inspector_audio.add_child(h_title_a)

	# Ecualizador / VU-Meter Visual
	var box_vu := PanelContainer.new()
	box_vu.add_theme_stylebox_override("panel", sb_gpu)
	var v_vu := VBoxContainer.new()
	v_vu.add_theme_constant_override("separation", 10)

	var lbl_vu_t := Label.new()
	lbl_vu_t.text = "VUMETRO DE SALIDA DE AUDIO"
	lbl_vu_t.add_theme_font_override("font", FONT)
	lbl_vu_t.add_theme_font_size_override("font_size", 19)
	lbl_vu_t.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.9))
	v_vu.add_child(lbl_vu_t)

	var h_vu_bars := HBoxContainer.new()
	h_vu_bars.custom_minimum_size = Vector2(0, 58)
	h_vu_bars.alignment = BoxContainer.ALIGNMENT_CENTER
	h_vu_bars.add_theme_constant_override("separation", 6)

	vu_bars.clear()
	for i in range(16):
		var bar = ColorRect.new()
		bar.custom_minimum_size = Vector2(18, 8)
		bar.color = Color(0.25, 0.28, 0.32, 0.5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		h_vu_bars.add_child(bar)
		vu_bars.append(bar)

	v_vu.add_child(h_vu_bars)
	box_vu.add_child(v_vu)
	inspector_audio.add_child(box_vu)

	# Botones de Prueba de Sonido
	var box_snd_btns := PanelContainer.new()
	box_snd_btns.add_theme_stylebox_override("panel", sb_gpu)
	var v_snd := VBoxContainer.new()
	v_snd.add_theme_constant_override("separation", 10)

	var lbl_snd_t := Label.new()
	lbl_snd_t.text = "TEST DE EFECTOS DE CABINA"
	lbl_snd_t.add_theme_font_override("font", FONT)
	lbl_snd_t.add_theme_font_size_override("font_size", 19)
	lbl_snd_t.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	v_snd.add_child(lbl_snd_t)

	var btn_play_horn = _crear_boton_inspector("TOCAR BOCINA / CLAXON", func():
		_reproducir_test_audio(SND_CLAXON)
	)
	var btn_play_eng = _crear_boton_inspector("ENCENDER MOTOR DIESEL", func():
		_reproducir_test_audio(SND_MOTOR)
	)
	var btn_play_brake = _crear_boton_inspector("FRENO DE AIRE HIDRAULICO", func():
		_reproducir_test_audio(SND_FRENO)
	)

	v_snd.add_child(btn_play_horn)
	v_snd.add_child(btn_play_eng)
	v_snd.add_child(btn_play_brake)

	box_snd_btns.add_child(v_snd)
	inspector_audio.add_child(box_snd_btns)
	vbox_inspector.add_child(inspector_audio)

	# --- 3. INSPECTOR: CONTROLES (Simulador Interactivo de Volante & Pedales) ---
	inspector_controles = VBoxContainer.new()
	inspector_controles.add_theme_constant_override("separation", 16)
	inspector_controles.visible = false

	var h_title_c = _crear_header_inspector("SIMULADOR TACTIL DE DIRECCION", "TELEMETRIA")
	inspector_controles.add_child(h_title_c)

	var box_wheel := PanelContainer.new()
	box_wheel.add_theme_stylebox_override("panel", sb_gpu)
	var v_wheel := VBoxContainer.new()
	v_wheel.add_theme_constant_override("separation", 10)
	v_wheel.alignment = BoxContainer.ALIGNMENT_CENTER

	lbl_wheel_angle = Label.new()
	lbl_wheel_angle.text = "GIRO: 0.0 DEG"
	lbl_wheel_angle.add_theme_font_override("font", FONT)
	lbl_wheel_angle.add_theme_font_size_override("font_size", 24)
	lbl_wheel_angle.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	lbl_wheel_angle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_wheel.add_child(lbl_wheel_angle)

	# Volante interactivo rotable
	var wheel_center_box := CenterContainer.new()
	wheel_center_box.custom_minimum_size = Vector2(0, 180)

	wheel_rect = TextureRect.new()
	wheel_rect.texture = VOLANTE_TEX
	wheel_rect.custom_minimum_size = Vector2(170, 170)
	wheel_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wheel_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wheel_rect.pivot_offset = Vector2(85, 85)
	wheel_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	
	wheel_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
			wheel_is_dragging = true
			var sens = (slider_volante.value if slider_volante else 150.0) / 100.0
			wheel_angle = clamp(wheel_angle + event.relative.x * sens * 0.8, -180.0, 180.0)
			wheel_rect.rotation_degrees = wheel_angle
			lbl_wheel_angle.text = "GIRO: %.1f DEG" % wheel_angle
		elif event is InputEventMouseButton and not event.pressed:
			wheel_is_dragging = false
		elif event is InputEventScreenTouch and not event.pressed:
			wheel_is_dragging = false
	)
	wheel_center_box.add_child(wheel_rect)
	v_wheel.add_child(wheel_center_box)

	var lbl_wheel_hint := Label.new()
	lbl_wheel_hint.text = "Arrastra el volante para probar la sensibilidad y retorno"
	lbl_wheel_hint.add_theme_font_size_override("font_size", 16)
	lbl_wheel_hint.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70, 0.85))
	lbl_wheel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_wheel.add_child(lbl_wheel_hint)

	# Probador de Pedales
	var h_ped_test := HBoxContainer.new()
	h_ped_test.add_theme_constant_override("separation", 10)

	var btn_test_freno = _crear_boton_pedal("PROBAR FRENO", Color(0.85, 0.35, 0.32), func():
		_reproducir_test_audio(SND_FRENO)
		wheel_angle = lerp(wheel_angle, 0.0, 0.5)
		wheel_rect.rotation_degrees = wheel_angle
	)
	var btn_test_gas = _crear_boton_pedal("PROBAR ACELERADOR", Color(0.3, 0.85, 0.5), func():
		_reproducir_test_audio(SND_MOTOR)
	)
	h_ped_test.add_child(btn_test_freno)
	h_ped_test.add_child(btn_test_gas)
	v_wheel.add_child(h_ped_test)

	box_wheel.add_child(v_wheel)
	inspector_controles.add_child(box_wheel)
	vbox_inspector.add_child(inspector_controles)

	# --- 4. INSPECTOR: OPTIMIZACION (Radar de Chunks y Memoria) ---
	inspector_demas = VBoxContainer.new()
	inspector_demas.add_theme_constant_override("separation", 16)
	inspector_demas.visible = false

	var h_title_o = _crear_header_inspector("MONITOR DE STREAMING MUNDO", "OPTIMIZACION")
	inspector_demas.add_child(h_title_o)

	var box_radar := PanelContainer.new()
	box_radar.add_theme_stylebox_override("panel", sb_gpu)
	var v_radar := VBoxContainer.new()
	v_radar.add_theme_constant_override("separation", 12)

	lbl_radar_dist = Label.new()
	lbl_radar_dist.text = "RADIO ACTIVO: 200 METROS"
	lbl_radar_dist.add_theme_font_override("font", FONT)
	lbl_radar_dist.add_theme_font_size_override("font_size", 23)
	lbl_radar_dist.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	v_radar.add_child(lbl_radar_dist)

	lbl_mem_savings = Label.new()
	lbl_mem_savings.text = "AHORRO ESTIMADO DE MEMORIA: ~42%"
	lbl_mem_savings.add_theme_font_override("font", FONT)
	lbl_mem_savings.add_theme_font_size_override("font_size", 20)
	lbl_mem_savings.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5, 1.0))
	v_radar.add_child(lbl_mem_savings)

	var lbl_desc_radar := Label.new()
	lbl_desc_radar.text = "El sistema de particionamiento modular descarga de forma inteligente los bloques de la ciudad y trafico que quedan fuera de la vision de la tractomula, garantizando que el juego no se ralentice ni se cierre por falta de memoria RAM."
	lbl_desc_radar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc_radar.add_theme_font_size_override("font_size", 17)
	lbl_desc_radar.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78, 0.90))
	v_radar.add_child(lbl_desc_radar)

	box_radar.add_child(v_radar)
	inspector_demas.add_child(box_radar)
	vbox_inspector.add_child(inspector_demas)

# =======================================================================
# HELPERS DE CREACION DE WIDGETS TACTILES Y TARJETAS
# =======================================================================
func _crear_selector_pills(group_name: String, items: Array, selected_idx: int, on_selected: Callable) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_list: Array[Button] = []
	for i in range(items.size()):
		var btn := Button.new()
		btn.text = items[i]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", FONT)
		btn.add_theme_font_size_override("font_size", 20)
		
		var idx_capture = i
		btn.pressed.connect(func():
			_seleccionar_pill(group_name, idx_capture)
			on_selected.call(idx_capture)
		)
		hbox.add_child(btn)
		btn_list.append(btn)
		
	pill_groups[group_name] = btn_list
	_seleccionar_pill(group_name, selected_idx)
	return hbox

func _seleccionar_pill(group_name: String, active_idx: int) -> void:
	if not pill_groups.has(group_name):
		return
	var buttons: Array = pill_groups[group_name]
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		
		if i == active_idx:
			style.bg_color = Color(0.18, 0.20, 0.24, 0.94)
			style.border_color = Color(0.88, 0.68, 0.28, 0.92)
			style.border_width_bottom = 2
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
			btn.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
		else:
			style.bg_color = Color(0.08, 0.09, 0.11, 0.78)
			style.border_color = Color(0.78, 0.81, 0.85, 0.18)
			
			var hover := StyleBoxFlat.new()
			hover.set_corner_radius_all(6)
			hover.set_border_width_all(1)
			hover.bg_color = Color(0.14, 0.16, 0.19, 0.90)
			hover.border_color = Color(0.85, 0.88, 0.92, 0.38)
			
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82, 0.85))

func _crear_fila_con_pills(titulo: String, desc: String, group_name: String, items: Array, initial_idx: int, on_selected: Callable) -> PanelContainer:
	var row = _crear_panel_fila()
	var v_main := VBoxContainer.new()
	v_main.add_theme_constant_override("separation", 8)
	v_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var h_top := HBoxContainer.new()
	var v_text := VBoxContainer.new()
	v_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl_t := Label.new()
	lbl_t.text = titulo
	lbl_t.add_theme_font_override("font", FONT)
	lbl_t.add_theme_font_size_override("font_size", 22)
	lbl_t.add_theme_color_override("font_color", Color(0.88, 0.90, 0.93, 0.95))
	v_text.add_child(lbl_t)

	if desc != "":
		var lbl_d := Label.new()
		lbl_d.text = desc
		lbl_d.add_theme_font_size_override("font_size", 16)
		lbl_d.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62, 0.85))
		v_text.add_child(lbl_d)

	h_top.add_child(v_text)
	v_main.add_child(h_top)

	var pills = _crear_selector_pills(group_name, items, initial_idx, on_selected)
	v_main.add_child(pills)

	row.add_child(v_main)
	return row

func _crear_fila_con_toggle(titulo: String, desc: String, initial_val: bool, on_toggled: Callable) -> PanelContainer:
	var row = _crear_panel_fila()
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v_text := VBoxContainer.new()
	v_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var lbl_t := Label.new()
	lbl_t.text = titulo
	lbl_t.add_theme_font_override("font", FONT)
	lbl_t.add_theme_font_size_override("font_size", 22)
	lbl_t.add_theme_color_override("font_color", Color(0.88, 0.90, 0.93, 0.95))
	v_text.add_child(lbl_t)

	if desc != "":
		var lbl_d := Label.new()
		lbl_d.text = desc
		lbl_d.add_theme_font_size_override("font_size", 16)
		lbl_d.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62, 0.85))
		v_text.add_child(lbl_d)
	hbox.add_child(v_text)

	var btn_toggle := Button.new()
	btn_toggle.custom_minimum_size = Vector2(195, 48)
	btn_toggle.add_theme_font_override("font", FONT)
	btn_toggle.add_theme_font_size_override("font_size", 20)
	
	var is_on = initial_val
	var actualizar_visual = func():
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		if is_on:
			style.bg_color = Color(0.18, 0.20, 0.24, 0.94)
			style.border_color = Color(0.88, 0.68, 0.28, 0.92)
			style.border_width_bottom = 2
			btn_toggle.text = "ACTIVADO"
			btn_toggle.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
		else:
			style.bg_color = Color(0.08, 0.09, 0.11, 0.78)
			style.border_color = Color(0.78, 0.81, 0.85, 0.18)
			btn_toggle.text = "DESACTIVADO"
			btn_toggle.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62, 0.85))
		btn_toggle.add_theme_stylebox_override("normal", style)
		btn_toggle.add_theme_stylebox_override("hover", style)
		btn_toggle.add_theme_stylebox_override("pressed", style)

	actualizar_visual.call()

	btn_toggle.pressed.connect(func():
		is_on = not is_on
		actualizar_visual.call()
		on_toggled.call(is_on)
	)

	hbox.add_child(btn_toggle)
	row.add_child(hbox)
	return row

func _crear_fila_slider(titulo: String, desc: String, slider_node: HSlider, val_label: Label) -> PanelContainer:
	var row = _crear_panel_fila()
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v_text := VBoxContainer.new()
	v_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var lbl_t := Label.new()
	lbl_t.text = titulo
	lbl_t.add_theme_font_override("font", FONT)
	lbl_t.add_theme_font_size_override("font_size", 22)
	lbl_t.add_theme_color_override("font_color", Color(0.88, 0.90, 0.93, 0.95))
	v_text.add_child(lbl_t)

	if desc != "":
		var lbl_d := Label.new()
		lbl_d.text = desc
		lbl_d.add_theme_font_size_override("font_size", 16)
		lbl_d.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62, 0.85))
		v_text.add_child(lbl_d)
	hbox.add_child(v_text)

	if slider_node:
		if slider_node.get_parent():
			slider_node.get_parent().remove_child(slider_node)
		slider_node.custom_minimum_size = Vector2(320, 44)
		slider_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var h_sl_box := HBoxContainer.new()
		h_sl_box.add_theme_constant_override("separation", 10)
		h_sl_box.add_child(slider_node)

		if val_label:
			if val_label.get_parent():
				val_label.get_parent().remove_child(val_label)
			var badge := PanelContainer.new()
			var sb_b := StyleBoxFlat.new()
			sb_b.bg_color = Color(0.11, 0.13, 0.16, 0.95)
			sb_b.set_border_width_all(1)
			sb_b.border_color = Color(0.88, 0.68, 0.28, 0.45)
			sb_b.set_corner_radius_all(6)
			badge.add_theme_stylebox_override("panel", sb_b)
			badge.custom_minimum_size = Vector2(100, 44)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			val_label.add_theme_font_override("font", FONT)
			val_label.add_theme_font_size_override("font_size", 21)
			val_label.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
			val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_child(val_label)
			h_sl_box.add_child(badge)

		hbox.add_child(h_sl_box)

	row.add_child(hbox)
	return row

func _crear_tarjeta(titulo_texto: String, badge_texto: String, filas: Array) -> PanelContainer:
	var tarjeta := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.88)
	style.set_border_width_all(1)
	style.border_color = Color(0.78, 0.81, 0.85, 0.18)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.set_content_margin_all(16)
	tarjeta.add_theme_stylebox_override("panel", style)

	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 12)

	var h_header := HBoxContainer.new()
	h_header.add_theme_constant_override("separation", 10)

	var bar_acento := ColorRect.new()
	bar_acento.custom_minimum_size = Vector2(5, 24)
	bar_acento.color = Color(0.88, 0.68, 0.28, 0.95)
	bar_acento.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h_header.add_child(bar_acento)

	var lbl_title := Label.new()
	lbl_title.text = titulo_texto.to_upper()
	lbl_title.add_theme_font_override("font", FONT)
	lbl_title.add_theme_font_size_override("font_size", 25)
	lbl_title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 1.0))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_header.add_child(lbl_title)

	if badge_texto != "":
		var lbl_badge := Label.new()
		lbl_badge.text = "[ " + badge_texto + " ]"
		lbl_badge.add_theme_font_override("font", FONT)
		lbl_badge.add_theme_font_size_override("font_size", 16)
		lbl_badge.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70, 0.85))
		lbl_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_header.add_child(lbl_badge)

	v_box.add_child(h_header)

	var sep := HSeparator.new()
	sep.modulate = Color(0.78, 0.81, 0.85, 0.15)
	v_box.add_child(sep)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.add_theme_constant_override("separation", 10)
	for fila in filas:
		rows_vbox.add_child(fila)
	v_box.add_child(rows_vbox)

	tarjeta.add_child(v_box)
	return tarjeta

func _crear_panel_fila() -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.10, 0.11, 0.14, 0.55)
	row_style.set_border_width_all(1)
	row_style.border_color = Color(0.78, 0.81, 0.85, 0.08)
	row_style.set_corner_radius_all(8)
	row_style.content_margin_left = 16
	row_style.content_margin_right = 16
	row_style.content_margin_top = 10
	row_style.content_margin_bottom = 10
	row_panel.add_theme_stylebox_override("panel", row_style)
	return row_panel

func _crear_header_inspector(titulo: String, tag: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)

	var dot := Label.new()
	dot.text = ">"
	dot.add_theme_font_override("font", FONT)
	dot.add_theme_font_size_override("font_size", 18)
	dot.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	h.add_child(dot)

	var l := Label.new()
	l.text = titulo
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97, 1.0))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)

	var t := Label.new()
	t.text = "[ " + tag + " ]"
	t.add_theme_font_override("font", FONT)
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 0.85))
	h.add_child(t)
	return h

func _crear_badge_inspector(texto: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.85)
	s.set_border_width_all(1)
	s.border_color = color
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _crear_boton_inspector(texto: String, on_click: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 20)
	
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.14, 0.18, 0.85)
	sb_n.set_border_width_all(1)
	sb_n.border_color = Color(0.78, 0.81, 0.85, 0.20)
	sb_n.set_corner_radius_all(8)
	
	var sb_p = StyleBoxFlat.new()
	sb_p.bg_color = Color(0.18, 0.22, 0.28, 0.95)
	sb_p.set_border_width_all(1)
	sb_p.border_color = Color(0.88, 0.68, 0.28, 0.92)
	sb_p.border_width_bottom = 2
	sb_p.set_corner_radius_all(8)

	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_p)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_color_override("font_color", Color(0.88, 0.90, 0.93, 0.95))
	b.pressed.connect(on_click)
	return b

func _crear_boton_pedal(texto: String, color: Color, on_click: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.8)
	sb.set_border_width_all(1)
	sb.border_color = color
	sb.set_corner_radius_all(6)

	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	b.pressed.connect(on_click)
	return b

func _reproducir_test_audio(stream: AudioStream) -> void:
	if not audio_tester:
		return
	audio_tester.stream = stream
	audio_tester.play()
	vu_anim_active = true
	var tw = create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func(): vu_anim_active = false)

func _crear_textura_grabber(radio: int, color_centro: Color, color_borde: Color) -> ImageTexture:
	var size = radio * 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centro = Vector2(radio, radio)
	for x in range(size):
		for y in range(size):
			var dist = centro.distance_to(Vector2(x, y))
			if dist <= radio:
				var alpha = 1.0
				if dist > radio - 1.5:
					alpha = radio - dist
				if dist > radio - 3.5:
					img.set_pixel(x, y, Color(color_borde, alpha))
				elif dist > radio - 5.5:
					img.set_pixel(x, y, Color(0.06, 0.07, 0.09, alpha))
				elif dist < 4.0:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
				else:
					img.set_pixel(x, y, Color(color_centro, alpha))
	return ImageTexture.create_from_image(img)

func _estilizar_slider(slider: HSlider, grabber_tex: ImageTexture) -> void:
	if not slider:
		return
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	
	var sb_track = StyleBoxFlat.new()
	sb_track.bg_color = Color(0.14, 0.15, 0.17, 0.88)
	sb_track.set_border_width_all(1)
	sb_track.border_color = Color(0.78, 0.81, 0.85, 0.15)
	sb_track.set_corner_radius_all(4)
	sb_track.expand_margin_top = 4
	sb_track.expand_margin_bottom = 4
	
	var sb_area = StyleBoxFlat.new()
	sb_area.bg_color = Color(0.88, 0.68, 0.28, 0.92)
	sb_area.set_corner_radius_all(4)
	sb_area.expand_margin_top = 4
	sb_area.expand_margin_bottom = 4
	
	slider.add_theme_stylebox_override("slider", sb_track)
	slider.add_theme_stylebox_override("grabber_area", sb_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", sb_area)

# =======================================================================
# LOGICA DE TELEMETRIA DINAMICA DEL INSPECTOR
# =======================================================================
func _actualizar_telemetria_graficos() -> void:
	if not bar_gpu_load:
		return
	var score: int = 25
	# Calidad
	score += opt_calidad.selected * 15
	# Sombras
	score += opt_sombras.selected * 10
	# AA
	score += opt_aa.selected * 5
	# Render Scale
	score += int((slider_render.value - 50.0) * 0.4)
	# Postprocesado
	if chk_ssao and chk_ssao.button_pressed: score += 12
	if chk_glow and chk_glow.button_pressed: score += 6
	if chk_sdfgi and chk_sdfgi.button_pressed: score += 18

	score = clamp(score, 15, 100)
	bar_gpu_load.value = score
	lbl_gpu_score.text = "%d%%" % score

	# Color dinamico de carga
	var fg: StyleBoxFlat = bar_gpu_load.get_theme_stylebox("fill").duplicate()
	if score < 50:
		fg.bg_color = Color(0.2, 0.85, 0.4, 0.95)
		if lbl_battery: lbl_battery.text = "BATERIA: OPTIMA"
	elif score < 75:
		fg.bg_color = Color(0.88, 0.68, 0.28, 0.95)
		if lbl_battery: lbl_battery.text = "BATERIA: MODERADA"
	else:
		fg.bg_color = Color(0.88, 0.32, 0.28, 0.95)
		if lbl_battery: lbl_battery.text = "BATERIA: ALTA DEMANDA"
	bar_gpu_load.add_theme_stylebox_override("fill", fg)

	# Target FPS badge
	if lbl_target_fps:
		match opt_fps.selected:
			0: lbl_target_fps.text = "30 FPS AHORRO"
			1: lbl_target_fps.text = "60 FPS FLUIDO"
			2: lbl_target_fps.text = "90 FPS ELEVADO"
			3: lbl_target_fps.text = "120 FPS MAXIMO"
			4: lbl_target_fps.text = "FPS ILIMITADOS"
	# Actualizar checklist en tiempo real
	if list_checklist:
		for c in list_checklist.get_children():
			c.queue_free()
		var items = [
			["Escala FSR 2.0", "%d%%" % int(slider_render.value), true],
			["Sombras 3D", ["OFF", "BAJAS", "MEDIAS", "ALTAS"][opt_sombras.selected], opt_sombras.selected > 0],
			["Anti-Aliasing", ["OFF", "FXAA", "2X", "4X", "8X"][opt_aa.selected], opt_aa.selected > 0],
			["Oclusion SSAO", "ACTIVO" if (chk_ssao and chk_ssao.button_pressed) else "OFF", (chk_ssao and chk_ssao.button_pressed)],
			["Resplandor Glow", "ACTIVO" if (chk_glow and chk_glow.button_pressed) else "OFF", (chk_glow and chk_glow.button_pressed)]
		]
		for item in items:
			var h := HBoxContainer.new()
			var l_icon := Label.new()
			l_icon.text = "[OK]" if item[2] else "[--]"
			l_icon.add_theme_font_override("font", FONT)
			l_icon.add_theme_font_size_override("font_size", 17)
			l_icon.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28) if item[2] else Color(0.5, 0.55, 0.6))
			h.add_child(l_icon)

			var l_name := Label.new()
			l_name.text = " " + item[0] + ":"
			l_name.add_theme_font_size_override("font_size", 16)
			l_name.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
			l_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l_name)

			var l_val := Label.new()
			l_val.text = item[1]
			l_val.add_theme_font_override("font", FONT)
			l_val.add_theme_font_size_override("font_size", 17)
			l_val.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28) if item[2] else Color(0.5, 0.55, 0.6))
			h.add_child(l_val)
			list_checklist.add_child(h)

func _actualizar_telemetria_opt() -> void:
	if lbl_radar_dist and slider_city_dist:
		lbl_radar_dist.text = "RADIO ACTIVO: %d METROS" % int(slider_city_dist.value)
	if lbl_mem_savings and chk_city_opt:
		if chk_city_opt.button_pressed:
			var dist_factor = (600.0 - slider_city_dist.value) / 550.0
			var pct = int(25.0 + dist_factor * 35.0)
			lbl_mem_savings.text = "AHORRO ESTIMADO DE MEMORIA: ~%d%%" % pct
			lbl_mem_savings.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5, 1.0))
		else:
			lbl_mem_savings.text = "CIUDAD COMPLETA EN MEMORIA (0% AHORRO)"
			lbl_mem_savings.add_theme_color_override("font_color", Color(0.88, 0.4, 0.35, 1.0))

# =======================================================================
# NAVEGACION ENTRE PESTANAS
# =======================================================================
func _switch_tab(idx: int) -> void:
	pagina_graficos.visible = (idx == 0)
	pagina_sonido.visible = (idx == 1)
	pagina_controles.visible = (idx == 2)
	pagina_demas.visible = (idx == 3)
	
	btn_tab_graficos.button_pressed = (idx == 0)
	btn_tab_sonido.button_pressed = (idx == 1)
	btn_tab_controles.button_pressed = (idx == 2)
	btn_tab_demas.button_pressed = (idx == 3)

	# Cambiar tambien el panel del inspector
	if inspector_graficos: inspector_graficos.visible = (idx == 0)
	if inspector_audio: inspector_audio.visible = (idx == 1)
	if inspector_controles: inspector_controles.visible = (idx == 2)
	if inspector_demas: inspector_demas.visible = (idx == 3)
	
	if scroll_contenido:
		scroll_contenido.scroll_vertical = 0

	if idx == 0: _actualizar_telemetria_graficos()
	elif idx == 3: _actualizar_telemetria_opt()

func _style_tab_buttons() -> void:
	var tabs = [btn_tab_graficos, btn_tab_sonido, btn_tab_controles, btn_tab_demas]
	for btn in tabs:
		if not btn:
			continue
		btn.add_theme_font_override("font", FONT)
		btn.add_theme_font_size_override("font_size", 24)
		_aplicar_estilo_boton_tab(btn)

func _aplicar_estilo_boton_tab(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.09, 0.11, 0.78)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.78, 0.81, 0.85, 0.20)
	normal.set_corner_radius_all(10)
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.14, 0.16, 0.19, 0.90)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.85, 0.88, 0.92, 0.42)
	hover.set_corner_radius_all(10)
	
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.18, 0.20, 0.24, 0.94)
	pressed.set_border_width_all(1)
	pressed.border_width_bottom = 2
	pressed.border_color = Color(0.88, 0.68, 0.28, 0.92)
	pressed.set_corner_radius_all(10)
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", pressed)
	btn.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(0.88, 0.68, 0.28, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.92, 0.94, 0.97, 1.0))

func _style_scrollbar() -> void:
	if not scroll_contenido:
		return
	var vbar := scroll_contenido.get_v_scroll_bar()
	vbar.custom_minimum_size = Vector2(12, 0)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.06, 0.07, 0.08, 0.80)
	track.set_corner_radius_all(6)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.78, 0.81, 0.85, 0.35)
	grabber.set_corner_radius_all(6)

	var grabber_hl := StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.88, 0.68, 0.28, 0.85)
	grabber_hl.set_corner_radius_all(6)

	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("scroll_focus", track)
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_hl)

# =======================================================================
# LOGICA DE PRESETS Y SINCRONIZACION DE PILLS
# =======================================================================
func _aplicar_preset_global(idx: int) -> void:
	match idx:
		0: # BAJO
			opt_calidad.selected = 0
			opt_cielo.selected = 0
			opt_sombras.selected = 0
			opt_aa.selected = 0
			slider_render.value = 60
			opt_fps.selected = 0
			chk_ssao.button_pressed = false
			chk_glow.button_pressed = false
			chk_sdfgi.button_pressed = false
		1: # MEDIO
			opt_calidad.selected = 1
			opt_cielo.selected = 1
			opt_sombras.selected = 1
			opt_aa.selected = 1
			slider_render.value = 75
			opt_fps.selected = 1
			chk_ssao.button_pressed = false
			chk_glow.button_pressed = false
			chk_sdfgi.button_pressed = false
		2: # ALTO
			opt_calidad.selected = 2
			opt_cielo.selected = 2
			opt_sombras.selected = 2
			opt_aa.selected = 1
			slider_render.value = 85
			opt_fps.selected = 1
			chk_ssao.button_pressed = false
			chk_glow.button_pressed = true
			chk_sdfgi.button_pressed = false
		3: # ULTRA
			opt_calidad.selected = 3
			opt_cielo.selected = 3
			opt_sombras.selected = 3
			opt_aa.selected = 2
			slider_render.value = 100
			opt_fps.selected = 1
			chk_ssao.button_pressed = true
			chk_glow.button_pressed = true
			chk_sdfgi.button_pressed = false

	_sincronizar_pills_desde_opciones()
	lbl_render_val.text = "%d%%" % int(slider_render.value)
	_seleccionar_pill("presets", idx)
	_actualizar_telemetria_graficos()

func _verificar_preset_activo() -> void:
	_seleccionar_pill("presets", -1)
	if not opt_calidad or not opt_cielo or not opt_sombras or not opt_aa or not slider_render:
		return
		
	if (opt_calidad.selected == 0 and opt_cielo.selected == 0 and opt_sombras.selected == 0
		and opt_aa.selected == 0 and int(slider_render.value) == 60 and not chk_ssao.button_pressed
		and not chk_glow.button_pressed and not chk_sdfgi.button_pressed):
		_seleccionar_pill("presets", 0)
		return
		
	if (opt_calidad.selected == 1 and opt_cielo.selected == 1 and opt_sombras.selected == 1
		and opt_aa.selected == 1 and int(slider_render.value) == 75 and not chk_ssao.button_pressed
		and not chk_glow.button_pressed and not chk_sdfgi.button_pressed):
		_seleccionar_pill("presets", 1)
		return
		
	if (opt_calidad.selected == 2 and opt_cielo.selected == 2 and opt_sombras.selected == 2
		and opt_aa.selected == 1 and int(slider_render.value) == 85 and not chk_ssao.button_pressed
		and chk_glow.button_pressed and not chk_sdfgi.button_pressed):
		_seleccionar_pill("presets", 2)
		return
		
	if (opt_calidad.selected == 3 and opt_cielo.selected == 3 and opt_sombras.selected == 3
		and opt_aa.selected == 2 and int(slider_render.value) == 100 and chk_ssao.button_pressed
		and chk_glow.button_pressed and not chk_sdfgi.button_pressed):
		_seleccionar_pill("presets", 3)
		return

func _sincronizar_pills_desde_opciones() -> void:
	_seleccionar_pill("calidad", opt_calidad.selected)
	_seleccionar_pill("cielo", opt_cielo.selected)
	_seleccionar_pill("sombras", opt_sombras.selected)
	_seleccionar_pill("aa", opt_aa.selected)
	_seleccionar_pill("fps", opt_fps.selected)

# =======================================================================
# CARGA, GUARDADO Y APLICACION DE AJUSTES
# =======================================================================
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_apply_defaults()
		return

	opt_calidad.selected = cfg.get_value("graficos", "calidad", 1)
	opt_cielo.selected = cfg.get_value("graficos", "cielo_calidad", 1)
	opt_sombras.selected = cfg.get_value("graficos", "sombras", 1)
	opt_aa.selected = cfg.get_value("graficos", "aa", 1)
	chk_vsync.button_pressed = cfg.get_value("graficos", "vsync", true)
	
	slider_render.value = cfg.get_value("graficos", "render_scale", 75)
	lbl_render_val.text = "%d%%" % int(slider_render.value)
	opt_fps.selected = cfg.get_value("graficos", "fps", 1)

	slider_vol.value = cfg.get_value("audio", "vol_general", 100)
	lbl_vol.text = "%d%%" % int(slider_vol.value)
	slider_musica.value = cfg.get_value("audio", "musica", 80)
	lbl_musica.text = "%d%%" % int(slider_musica.value)
	slider_efectos.value = cfg.get_value("audio", "efectos", 100)
	lbl_efectos.text = "%d%%" % int(slider_efectos.value)

	var sv: int = int(cfg.get_value("controles", "sensibilidad_volante", 150))
	if slider_volante:
		slider_volante.value = sv
		if lbl_volante_val: lbl_volante_val.text = "%d%%" % sv

	if slider_suavizado_dir:
		slider_suavizado_dir.value = float(cfg.get_value("controles", "suavizado_direccion", 10.0))
		if lbl_suavizado_dir_val: lbl_suavizado_dir_val.text = "%.1f" % slider_suavizado_dir.value
	if slider_retorno_vol:
		slider_retorno_vol.value = float(cfg.get_value("controles", "retorno_volante", 3.5))
		if lbl_retorno_vol_val: lbl_retorno_vol_val.text = "%.1f" % slider_retorno_vol.value
	if slider_suavizado_ped:
		slider_suavizado_ped.value = float(cfg.get_value("controles", "suavizado_pedales", 3.5))
		if lbl_suavizado_ped_val: lbl_suavizado_ped_val.text = "%.1f" % slider_suavizado_ped.value

	var opt_enabled = cfg.get_value("graficos", "city_optimizer_enabled", true)
	if chk_city_opt:
		chk_city_opt.button_pressed = opt_enabled
	var opt_dist = cfg.get_value("graficos", "city_optimizer_dist", 200.0)
	if slider_city_dist:
		slider_city_dist.value = opt_dist
		if lbl_city_dist_val: lbl_city_dist_val.text = "%dm" % int(opt_dist)
		if row_city_dist_container: row_city_dist_container.visible = opt_enabled

	var ssao_val = cfg.get_value("graficos", "ssao_enabled", true)
	if chk_ssao: chk_ssao.button_pressed = ssao_val
	var glow_val = cfg.get_value("graficos", "glow_enabled", true)
	if chk_glow: chk_glow.button_pressed = glow_val
	var sdfgi_val = cfg.get_value("graficos", "sdfgi_enabled", false)
	if chk_sdfgi: chk_sdfgi.button_pressed = sdfgi_val
		
	_sincronizar_pills_desde_opciones()
	_verificar_preset_activo()

func _apply_defaults() -> void:
	opt_calidad.selected = 1
	opt_cielo.selected = 1
	opt_sombras.selected = 1
	opt_aa.selected = 1
	chk_vsync.button_pressed = true
	slider_render.value = 75
	opt_fps.selected = 1
	
	slider_vol.value = 100
	slider_musica.value = 80
	slider_efectos.value = 100
	
	if slider_volante: slider_volante.value = 150
	if slider_suavizado_dir: slider_suavizado_dir.value = 10.0
	if slider_retorno_vol: slider_retorno_vol.value = 3.5
	if slider_suavizado_ped: slider_suavizado_ped.value = 3.5
	
	if chk_ssao: chk_ssao.button_pressed = false
	if chk_glow: chk_glow.button_pressed = true
	if chk_sdfgi: chk_sdfgi.button_pressed = false
	if chk_city_opt: chk_city_opt.button_pressed = true
	if slider_city_dist: slider_city_dist.value = 200.0
	
	_sincronizar_pills_desde_opciones()
	_actualizar_ui_completa()

func _actualizar_ui_completa() -> void:
	lbl_render_val.text = "%d%%" % int(slider_render.value)
	lbl_vol.text = "%d%%" % int(slider_vol.value)
	lbl_musica.text = "%d%%" % int(slider_musica.value)
	lbl_efectos.text = "%d%%" % int(slider_efectos.value)
	if slider_volante and lbl_volante_val: lbl_volante_val.text = "%d%%" % int(slider_volante.value)
	if slider_suavizado_dir and lbl_suavizado_dir_val: lbl_suavizado_dir_val.text = "%.1f" % slider_suavizado_dir.value
	if slider_retorno_vol and lbl_retorno_vol_val: lbl_retorno_vol_val.text = "%.1f" % slider_retorno_vol.value
	if slider_suavizado_ped and lbl_suavizado_ped_val: lbl_suavizado_ped_val.text = "%.1f" % slider_suavizado_ped.value
	if slider_city_dist and lbl_city_dist_val: lbl_city_dist_val.text = "%dm" % int(slider_city_dist.value)
	_verificar_preset_activo()
	_actualizar_telemetria_graficos()
	_actualizar_telemetria_opt()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graficos", "calidad", opt_calidad.selected)
	cfg.set_value("graficos", "cielo_calidad", opt_cielo.selected)
	cfg.set_value("graficos", "sombras", opt_sombras.selected)
	cfg.set_value("graficos", "aa", opt_aa.selected)
	cfg.set_value("graficos", "vsync", chk_vsync.button_pressed)
	cfg.set_value("graficos", "render_scale", int(slider_render.value))
	cfg.set_value("graficos", "fps", opt_fps.selected)
	cfg.set_value("audio", "vol_general", int(slider_vol.value))
	cfg.set_value("audio", "musica", int(slider_musica.value))
	cfg.set_value("audio", "efectos", int(slider_efectos.value))

	var sv_val := 150
	if slider_volante: sv_val = int(slider_volante.value)
	cfg.set_value("controles", "sensibilidad_volante", sv_val)
	cfg.set_value("controles", "suavizado_direccion", slider_suavizado_dir.value if slider_suavizado_dir else 10.0)
	cfg.set_value("controles", "retorno_volante", slider_retorno_vol.value if slider_retorno_vol else 3.5)
	cfg.set_value("controles", "suavizado_pedales", slider_suavizado_ped.value if slider_suavizado_ped else 3.5)
	
	cfg.set_value("graficos", "city_optimizer_enabled", chk_city_opt.button_pressed if chk_city_opt else true)
	cfg.set_value("graficos", "city_optimizer_dist", slider_city_dist.value if slider_city_dist else 200.0)
	cfg.set_value("graficos", "ssao_enabled", chk_ssao.button_pressed if chk_ssao else true)
	cfg.set_value("graficos", "glow_enabled", chk_glow.button_pressed if chk_glow else true)
	cfg.set_value("graficos", "sdfgi_enabled", chk_sdfgi.button_pressed if chk_sdfgi else false)

	cfg.save(SAVE_PATH)

func _apply_settings() -> void:
	var vp := get_viewport()
	match opt_aa.selected:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		1:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		3:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		4:
			vp.msaa_3d = Viewport.MSAA_8X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	if chk_vsync.button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var sombras_idx: int = opt_sombras.selected
	var atlas_size = 0
	match sombras_idx:
		0, 1:
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			atlas_size = 1024
		2:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			atlas_size = 2048
		3:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			atlas_size = 4096

	vp.positional_shadow_atlas_size = atlas_size

	var d_lights = []
	_find_directional_lights(get_tree().root, d_lights)
	for dl in d_lights:
		if dl is DirectionalLight3D:
			dl.shadow_enabled = (sombras_idx > 0)
			match sombras_idx:
				1:
					dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
					dl.directional_shadow_max_distance = 80.0
					dl.directional_shadow_blend_splits = false
				2:
					dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
					dl.directional_shadow_max_distance = 140.0
					dl.directional_shadow_blend_splits = true
				3:
					dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					dl.directional_shadow_max_distance = 200.0
					dl.directional_shadow_blend_splits = true
		elif dl is Light3D:
			dl.shadow_enabled = (sombras_idx >= 2)

	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	vp.scaling_3d_scale = slider_render.value / 100.0

	var fps_values: Array[int] = [30, 60, 90, 120, 0]
	Engine.max_fps = fps_values[opt_fps.selected]

	_set_bus_volume(0, slider_vol.value / 100.0)
	_set_bus_volume(1, slider_musica.value / 100.0)
	_set_bus_volume(2, slider_efectos.value / 100.0)

	var env = vp.find_world_3d().environment if vp.find_world_3d() else null
	if env:
		env.ssao_enabled = chk_ssao.button_pressed if chk_ssao else true
		env.glow_enabled = chk_glow.button_pressed if chk_glow else true
		env.sdfgi_enabled = chk_sdfgi.button_pressed if chk_sdfgi else false

	var optimizers = get_tree().get_nodes_in_group("city_optimizer")
	for opt in optimizers:
		if opt.has_method("update_settings_from_config"):
			opt.update_settings_from_config()

	_apply_controls_settings()
	_aplicar_calidad_cielo(opt_cielo.selected)

func _set_bus_volume(bus_idx: int, linear: float) -> void:
	if bus_idx >= AudioServer.get_bus_count():
		return
	var db := linear_to_db(linear) if linear > 0.001 else -80.0
	AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_controls_settings() -> void:
	var cfg := ConfigFile.new()
	var sv: int = 150
	var s_dir: float = 10.0
	var r_vol: float = 3.5
	var s_ped: float = 3.5
	
	if cfg.load(SAVE_PATH) == OK:
		sv = int(cfg.get_value("controles", "sensibilidad_volante", 150))
		s_dir = float(cfg.get_value("controles", "suavizado_direccion", 10.0))
		r_vol = float(cfg.get_value("controles", "retorno_volante", 3.5))
		s_ped = float(cfg.get_value("controles", "suavizado_pedales", 3.5))

	_apply_volante_sensitivity(float(sv) / 100.0)
	
	var input_veh = get_node_or_null("/root/InputVehiculo")
	if input_veh:
		input_veh.suavizado_direccion = s_dir
		input_veh.retorno_volante = r_vol
		input_veh.suavizado_pedales = s_ped

func _apply_volante_sensitivity(s: float) -> void:
	var root := get_tree().get_root()
	_apply_volante_sensitivity_recursive(root, s)

func _apply_volante_sensitivity_recursive(node: Node, s: float) -> void:
	for child in node.get_children():
		var scr = child.get_script()
		if scr and typeof(scr) == TYPE_OBJECT:
			var path = str(scr.resource_path)
			if path.find("volante") != -1:
				if child.has_method("set"):
					child.set("sensibilidad", s)
				else:
					child.sensibilidad = s
		_apply_volante_sensitivity_recursive(child, s)

func _find_directional_lights(node: Node, result: Array) -> void:
	if node is Light3D:
		result.append(node)
	for child in node.get_children():
		_find_directional_lights(child, result)

func _aplicar_calidad_cielo(perfil: int) -> void:
	var cielo = _buscar_cielo(get_tree().root)
	if cielo and "perfil_calidad" in cielo:
		cielo.perfil_calidad = perfil

func _buscar_cielo(node: Node) -> Node:
	if node.name == "CieloSistema" or node.has_method("clima_despejado"):
		return node
	for child in node.get_children():
		var found = _buscar_cielo(child)
		if found:
			return found
	return null

# =======================================================================
# CONEXION DE SENALES Y CALLBACKS
# =======================================================================
func _connect_signals() -> void:
	if not slider_render.value_changed.is_connected(_on_render_changed):
		slider_render.value_changed.connect(_on_render_changed)
	if not slider_vol.value_changed.is_connected(_on_vol_changed):
		slider_vol.value_changed.connect(_on_vol_changed)
	if not slider_musica.value_changed.is_connected(_on_musica_changed):
		slider_musica.value_changed.connect(_on_musica_changed)
	if not slider_efectos.value_changed.is_connected(_on_efectos_changed):
		slider_efectos.value_changed.connect(_on_efectos_changed)
		
	if btn_aplicar and not btn_aplicar.pressed.is_connected(_on_aplicar_pressed):
		btn_aplicar.pressed.connect(_on_aplicar_pressed)
	if btn_volver and not btn_volver.pressed.is_connected(_on_volver_pressed):
		btn_volver.pressed.connect(_on_volver_pressed)
	if btn_salir_menu and not btn_salir_menu.pressed.is_connected(_on_salir_menu_pressed):
		btn_salir_menu.pressed.connect(_on_salir_menu_pressed)
	if btn_restablecer and not btn_restablecer.pressed.is_connected(_on_restablecer_pressed):
		btn_restablecer.pressed.connect(_on_restablecer_pressed)
	
	if btn_tab_graficos and not btn_tab_graficos.pressed.is_connected(func(): _switch_tab(0)):
		btn_tab_graficos.pressed.connect(func(): _switch_tab(0))
	if btn_tab_sonido and not btn_tab_sonido.pressed.is_connected(func(): _switch_tab(1)):
		btn_tab_sonido.pressed.connect(func(): _switch_tab(1))
	if btn_tab_controles and not btn_tab_controles.pressed.is_connected(func(): _switch_tab(2)):
		btn_tab_controles.pressed.connect(func(): _switch_tab(2))
	if btn_tab_demas and not btn_tab_demas.pressed.is_connected(func(): _switch_tab(3)):
		btn_tab_demas.pressed.connect(func(): _switch_tab(3))

	if slider_city_dist and not slider_city_dist.value_changed.is_connected(_on_city_dist_changed):
		slider_city_dist.value_changed.connect(_on_city_dist_changed)
	if slider_volante and not slider_volante.value_changed.is_connected(_on_volante_changed):
		slider_volante.value_changed.connect(_on_volante_changed)
	if slider_suavizado_dir and not slider_suavizado_dir.value_changed.is_connected(_on_suavizado_dir_changed):
		slider_suavizado_dir.value_changed.connect(_on_suavizado_dir_changed)
	if slider_retorno_vol and not slider_retorno_vol.value_changed.is_connected(_on_retorno_vol_changed):
		slider_retorno_vol.value_changed.connect(_on_retorno_vol_changed)
	if slider_suavizado_ped and not slider_suavizado_ped.value_changed.is_connected(_on_suavizado_ped_changed):
		slider_suavizado_ped.value_changed.connect(_on_suavizado_ped_changed)

func _on_aplicar_pressed() -> void:
	_save_settings()
	_apply_settings()
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").apply_all_settings()

func _on_restablecer_pressed() -> void:
	_apply_defaults()
	_save_settings()
	_apply_settings()
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").apply_all_settings()

func _on_volver_pressed() -> void:
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").return_from_settings()
	else:
		get_tree().change_scene_to_file("res://interfaz/pantallas/perfil/Perfil_Menu.tscn")

func _on_salir_menu_pressed() -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.next_scene = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
	get_tree().paused = false
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").return_from_settings()
	get_tree().change_scene_to_file("res://interfaz/sistema/escena_carga.tscn")

func _on_render_changed(val: float) -> void:
	lbl_render_val.text = "%d%%" % int(val)
	_verificar_preset_activo()
	_actualizar_telemetria_graficos()

func _on_vol_changed(val: float) -> void:
	lbl_vol.text = "%d%%" % int(val)
	_set_bus_volume(0, val / 100.0)

func _on_musica_changed(val: float) -> void:
	lbl_musica.text = "%d%%" % int(val)
	_set_bus_volume(1, val / 100.0)

func _on_efectos_changed(val: float) -> void:
	lbl_efectos.text = "%d%%" % int(val)
	_set_bus_volume(2, val / 100.0)

func _on_city_dist_changed(val: float) -> void:
	if lbl_city_dist_val:
		lbl_city_dist_val.text = "%dm" % int(val)
	_actualizar_telemetria_opt()

func _on_volante_changed(val: float) -> void:
	if lbl_volante_val:
		lbl_volante_val.text = "%d%%" % int(val)
	_apply_volante_sensitivity(float(val) / 100.0)

func _on_suavizado_dir_changed(val: float) -> void:
	if lbl_suavizado_dir_val:
		lbl_suavizado_dir_val.text = "%.1f" % val

func _on_retorno_vol_changed(val: float) -> void:
	if lbl_retorno_vol_val:
		lbl_retorno_vol_val.text = "%.1f" % val

func _on_suavizado_ped_changed(val: float) -> void:
	if lbl_suavizado_ped_val:
		lbl_suavizado_ped_val.text = "%.1f" % val
