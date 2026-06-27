extends CanvasLayer

const SAVE_PATH = "user://settings.cfg"
const FONT = preload("res://recursos/fonts/Moderniz.otf")

@onready var opt_calidad: OptionButton = find_child("OptCalidad", true, false)
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

@onready var btn_tab_graficos: Button = find_child("BtnTabGraficos", true, false)
@onready var btn_tab_sonido: Button = find_child("BtnTabSonido", true, false)
@onready var btn_tab_controles: Button = find_child("BtnTabControles", true, false)
@onready var btn_tab_demas: Button = find_child("BtnTabDemas", true, false)

@onready var pagina_graficos: VBoxContainer = find_child("PaginaGraficos", true, false)
@onready var pagina_sonido: VBoxContainer = find_child("PaginaSonido", true, false)
@onready var pagina_controles: VBoxContainer = find_child("PaginaControles", true, false)
@onready var pagina_demas: VBoxContainer = find_child("PaginaDemas", true, false)
@onready var scroll_contenido: ScrollContainer = find_child("ScrollContenido", true, false)

@onready var slider_volante: HSlider = null
@onready var lbl_volante_val: Label = null

var slider_suavizado_dir: HSlider = null
var lbl_suavizado_dir_val: Label = null

var slider_retorno_vol: HSlider = null
var lbl_retorno_vol_val: Label = null

var slider_suavizado_ped: HSlider = null
var lbl_suavizado_ped_val: Label = null

var chk_city_opt: CheckButton = null
var slider_city_dist: HSlider = null
var lbl_city_dist_val: Label = null
var chk_ssao: CheckButton = null
var chk_glow: CheckButton = null
var chk_sdfgi: CheckButton = null

var btn_salir_menu: Button = null

func _style_buttons() -> void:
	# Agrandar botones de pestañas y botones de acción para mejor feedback táctil
	var tabs = [btn_tab_graficos, btn_tab_sonido, btn_tab_controles, btn_tab_demas]
	for btn in tabs:
		if btn:
			btn.custom_minimum_size.y = 95
			btn.add_theme_font_size_override("font_size", 30)
			_aplicar_estilo_boton_tab(btn)
	
	for btn in [btn_aplicar, btn_volver]:
		if btn:
			btn.custom_minimum_size.y = 115
			btn.add_theme_font_size_override("font_size", 34)

func _aplicar_estilo_boton_tab(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.1, 0.18, 0.6)
	normal.border_width_bottom = 2
	normal.border_color = Color(0.15, 0.22, 0.38, 0.8)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.008, 0.43, 0.8, 0.3)
	hover.border_width_bottom = 4
	hover.border_color = Color(0.008, 0.43, 0.8, 1.0)
	hover.corner_radius_top_left = 12
	hover.corner_radius_top_right = 12
	
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.008, 0.43, 0.8, 0.75)
	pressed.border_width_bottom = 4
	pressed.border_color = Color(0.0, 0.7, 1.0, 1.0)
	pressed.corner_radius_top_left = 12
	pressed.corner_radius_top_right = 12
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", pressed)

func _ready() -> void:
	if not visible:
		return
	_populate_options()
	_style_buttons()
	_style_option_buttons()
	_style_scrollbar()
	_ensure_demas_ui() # Asegurar controles de la pestaña "Otros"
	_load_settings()
	_apply_settings()
	_connect_signals()
	_ensure_controls_ui()
	_apply_controls_settings()
	
	# Mejorar zona táctil del scroll container
	if scroll_contenido:
		scroll_contenido.scroll_deadzone = 25
		
	# Separaciones de páginas de scroll
	for pagina in [pagina_graficos, pagina_sonido, pagina_controles, pagina_demas]:
		if pagina:
			pagina.add_theme_constant_override("separation", 28)
	
	# Crear botón para salir al menú principal
	if btn_volver:
		var parent = btn_volver.get_parent()
		if parent:
			btn_salir_menu = Button.new()
			btn_salir_menu.name = "BtnSalirMenu"
			btn_salir_menu.text = "SALIR AL MENÚ"
			parent.add_child(btn_salir_menu)
			
			btn_salir_menu.custom_minimum_size = Vector2(0, 115)
			btn_salir_menu.add_theme_font_override("font", FONT)
			btn_salir_menu.add_theme_font_size_override("font_size", 34)
			
			for stylebox_name in ["normal", "hover", "pressed", "disabled", "focus"]:
				if btn_volver.has_theme_stylebox(stylebox_name):
					var stylebox = btn_volver.get_theme_stylebox(stylebox_name)
					btn_salir_menu.add_theme_stylebox_override(stylebox_name, stylebox)
			
			btn_salir_menu.pressed.connect(_on_salir_menu_pressed)

func _style_scrollbar() -> void:
	var vbar := scroll_contenido.get_v_scroll_bar()
	vbar.custom_minimum_size = Vector2(16, 0)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.06, 0.06, 0.12, 0.75)
	track.corner_radius_top_left = 8
	track.corner_radius_top_right = 8
	track.corner_radius_bottom_right = 8
	track.corner_radius_bottom_left = 8
	track.content_margin_left = 4.0
	track.content_margin_right = 4.0

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.007843138, 0.43137255, 0.8, 0.72)
	grabber.corner_radius_top_left = 8
	grabber.corner_radius_top_right = 8
	grabber.corner_radius_bottom_right = 8
	grabber.corner_radius_bottom_left = 8

	var grabber_hl := StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.18, 0.6, 1.0, 0.9)
	grabber_hl.corner_radius_top_left = 8
	grabber_hl.corner_radius_top_right = 8
	grabber_hl.corner_radius_bottom_right = 8
	grabber_hl.corner_radius_bottom_left = 8

	var grabber_pressed := StyleBoxFlat.new()
	grabber_pressed.bg_color = Color(0.55, 0.87, 1.0, 1.0)
	grabber_pressed.corner_radius_top_left = 8
	grabber_pressed.corner_radius_top_right = 8
	grabber_pressed.corner_radius_bottom_right = 8
	grabber_pressed.corner_radius_bottom_left = 8

	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("scroll_focus", track)
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)

func _style_option_buttons() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.16, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.008, 0.43, 0.8, 0.8)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_bottom = 10.0

	var item_hover := StyleBoxFlat.new()
	item_hover.bg_color = Color(0.007843138, 0.43137255, 0.8, 0.5)
	item_hover.corner_radius_top_left = 8
	item_hover.corner_radius_top_right = 8
	item_hover.corner_radius_bottom_right = 8
	item_hover.corner_radius_bottom_left = 8
	item_hover.content_margin_left = 12.0
	item_hover.content_margin_right = 12.0
	item_hover.content_margin_top = 12.0
	item_hover.content_margin_bottom = 12.0

	for opt: OptionButton in [opt_calidad, opt_sombras, opt_aa, opt_fps]:
		opt.custom_minimum_size = Vector2(0, 95) # Más alto y cómodo para touch
		opt.add_theme_font_override("font", FONT)
		opt.add_theme_font_size_override("font_size", 32) # Más grande
		
		var popup := opt.get_popup()
		if popup:
			popup.add_theme_stylebox_override("panel", panel_style)
			popup.add_theme_stylebox_override("hover", item_hover)
			popup.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
			popup.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
			popup.add_theme_font_override("font", FONT)
			popup.add_theme_font_size_override("font_size", 34)
			popup.add_theme_constant_override("v_separation", 24)

	if chk_vsync:
		chk_vsync.custom_minimum_size = Vector2(0, 95)
		chk_vsync.add_theme_font_override("font", FONT)
		chk_vsync.add_theme_font_size_override("font_size", 32)

	# Slider Grabber Texture más grande (radio 22 -> 44px diámetro)
	var grabber_tex = _crear_textura_grabber(22, Color(0.06, 0.08, 0.15), Color(0.008, 0.43, 0.8))
	for slider: HSlider in [slider_render, slider_vol, slider_musica, slider_efectos]:
		if slider:
			_estilizar_slider(slider, grabber_tex)

func _populate_options() -> void:
	opt_calidad.add_item("BAJA")
	opt_calidad.add_item("MEDIA")
	opt_calidad.add_item("ALTA")
	opt_calidad.add_item("ULTRA")

	opt_sombras.add_item("DESACTIVADAS")
	opt_sombras.add_item("BAJA")
	opt_sombras.add_item("MEDIA")
	opt_sombras.add_item("ALTA")

	opt_aa.add_item("NINGUNO")
	opt_aa.add_item("FXAA")
	opt_aa.add_item("MSAA 2x")
	opt_aa.add_item("MSAA 4x")
	opt_aa.add_item("MSAA 8x")

	opt_fps.add_item("30 FPS")
	opt_fps.add_item("60 FPS")
	opt_fps.add_item("90 FPS")
	opt_fps.add_item("120 FPS")
	opt_fps.add_item("SIN LÍMITE")

func _connect_signals() -> void:
	if not slider_render.value_changed.is_connected(_on_render_changed):
		slider_render.value_changed.connect(_on_render_changed)
	if not slider_vol.value_changed.is_connected(_on_vol_changed):
		slider_vol.value_changed.connect(_on_vol_changed)
	if not slider_musica.value_changed.is_connected(_on_musica_changed):
		slider_musica.value_changed.connect(_on_musica_changed)
	if not slider_efectos.value_changed.is_connected(_on_efectos_changed):
		slider_efectos.value_changed.connect(_on_efectos_changed)
	if not btn_aplicar.pressed.is_connected(_on_aplicar_pressed):
		btn_aplicar.pressed.connect(_on_aplicar_pressed)
	if not btn_volver.pressed.is_connected(_on_volver_pressed):
		btn_volver.pressed.connect(_on_volver_pressed)
	
	if not btn_tab_graficos.pressed.is_connected(_on_tab_graficos_pressed):
		btn_tab_graficos.pressed.connect(_on_tab_graficos_pressed)
	if not btn_tab_sonido.pressed.is_connected(_on_tab_sonido_pressed):
		btn_tab_sonido.pressed.connect(_on_tab_sonido_pressed)
	if not btn_tab_controles.pressed.is_connected(_on_tab_controles_pressed):
		btn_tab_controles.pressed.connect(_on_tab_controles_pressed)
	if not btn_tab_demas.pressed.is_connected(_on_tab_demas_pressed):
		btn_tab_demas.pressed.connect(_on_tab_demas_pressed)
	
	if not chk_vsync.toggled.is_connected(_on_vsync_toggled):
		chk_vsync.toggled.connect(_on_vsync_toggled)

	if slider_volante and not slider_volante.value_changed.is_connected(_on_volante_changed):
		slider_volante.value_changed.connect(_on_volante_changed)

func _on_tab_graficos_pressed(): _switch_tab(0)
func _on_tab_sonido_pressed(): _switch_tab(1)
func _on_tab_controles_pressed(): _switch_tab(2)
func _on_tab_demas_pressed(): _switch_tab(3)

func _on_vsync_toggled(pressed: bool) -> void:
	chk_vsync.text = "ACTIVO" if pressed else "DESACT."

func _switch_tab(idx: int) -> void:
	pagina_graficos.visible = (idx == 0)
	pagina_sonido.visible = (idx == 1)
	pagina_controles.visible = (idx == 2)
	pagina_demas.visible = (idx == 3)
	btn_tab_graficos.button_pressed = (idx == 0)
	btn_tab_sonido.button_pressed = (idx == 1)
	btn_tab_controles.button_pressed = (idx == 2)
	btn_tab_demas.button_pressed = (idx == 3)

func _on_render_changed(val: float) -> void:
	lbl_render_val.text = str(int(val)) + "%"

func _on_vol_changed(val: float) -> void:
	lbl_vol.text = str(int(val)) + "%"

func _on_musica_changed(val: float) -> void:
	lbl_musica.text = str(int(val)) + "%"

func _on_efectos_changed(val: float) -> void:
	lbl_efectos.text = str(int(val)) + "%"

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_apply_defaults()
		return

	opt_calidad.selected = cfg.get_value("graficos", "calidad", 2)
	opt_sombras.selected = cfg.get_value("graficos", "sombras", 2)
	opt_aa.selected = cfg.get_value("graficos", "aa", 0)
	chk_vsync.button_pressed = cfg.get_value("graficos", "vsync", true)
	slider_render.value = cfg.get_value("graficos", "render_scale", 100)
	lbl_render_val.text = str(int(slider_render.value)) + "%"
	opt_fps.selected = cfg.get_value("graficos", "fps", 1)

	slider_vol.value = cfg.get_value("audio", "vol_general", 100)
	lbl_vol.text = str(int(slider_vol.value)) + "%"
	slider_musica.value = cfg.get_value("audio", "musica", 80)
	lbl_musica.text = str(int(slider_musica.value)) + "%"
	slider_efectos.value = cfg.get_value("audio", "efectos", 100)
	lbl_efectos.text = str(int(slider_efectos.value)) + "%"

	var sv: int = int(cfg.get_value("controles", "sensibilidad_volante", 150))
	if slider_volante:
		slider_volante.value = sv
		lbl_volante_val.text = str(int(sv)) + "%"

	if slider_suavizado_dir:
		slider_suavizado_dir.value = float(cfg.get_value("controles", "suavizado_direccion", 10.0))
		lbl_suavizado_dir_val.text = "%.1f" % slider_suavizado_dir.value
	if slider_retorno_vol:
		slider_retorno_vol.value = float(cfg.get_value("controles", "retorno_volante", 3.5))
		lbl_retorno_vol_val.text = "%.1f" % slider_retorno_vol.value
	if slider_suavizado_ped:
		slider_suavizado_ped.value = float(cfg.get_value("controles", "suavizado_pedales", 3.5))
		lbl_suavizado_ped_val.text = "%.1f" % slider_suavizado_ped.value

	# Cargar ciudad optimizada y gráficos
	var opt_enabled = cfg.get_value("graficos", "city_optimizer_enabled", true)
	if chk_city_opt:
		chk_city_opt.button_pressed = opt_enabled
		chk_city_opt.text = "ACTIVO" if opt_enabled else "DESACT."
	var opt_dist = cfg.get_value("graficos", "city_optimizer_dist", 200.0)
	if slider_city_dist:
		slider_city_dist.value = opt_dist
		lbl_city_dist_val.text = str(int(opt_dist)) + "m"
		slider_city_dist.get_parent().visible = opt_enabled
	var ssao_val = cfg.get_value("graficos", "ssao_enabled", true)
	if chk_ssao:
		chk_ssao.button_pressed = ssao_val
		chk_ssao.text = "ACTIVO" if ssao_val else "DESACT."
	var glow_val = cfg.get_value("graficos", "glow_enabled", true)
	if chk_glow:
		chk_glow.button_pressed = glow_val
		chk_glow.text = "ACTIVO" if glow_val else "DESACT."
	var sdfgi_val = cfg.get_value("graficos", "sdfgi_enabled", false)
	if chk_sdfgi:
		chk_sdfgi.button_pressed = sdfgi_val
		chk_sdfgi.text = "ACTIVO" if sdfgi_val else "DESACT."

func _apply_defaults() -> void:
	opt_calidad.selected = 2
	opt_sombras.selected = 2
	opt_aa.selected = 0
	chk_vsync.button_pressed = true
	slider_render.value = 100
	lbl_render_val.text = "100%"
	opt_fps.selected = 1
	slider_vol.value = 100
	lbl_vol.text = "100%"
	slider_musica.value = 80
	lbl_musica.text = "80%"
	slider_efectos.value = 100
	lbl_efectos.text = "100%"

func _on_aplicar_pressed() -> void:
	_apply_settings()
	_save_settings()
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").apply_all_settings()

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

	var atlas_size = 0
	match opt_sombras.selected:
		0:
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 0)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 0)
			atlas_size = 0
		1:
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 1024)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 1024)
			atlas_size = 1024
		2:
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 2048)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 2048)
			atlas_size = 2048
		3:
			ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", 4096)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
			atlas_size = 4096

	vp.positional_shadow_atlas_size = atlas_size

	# Aplicar el cambio a todas las luces direccionales en tiempo real
	var d_lights = []
	_find_directional_lights(get_tree().root, d_lights)
	for dl in d_lights:
		if dl is DirectionalLight3D:
			dl.shadow_enabled = (opt_sombras.selected > 0)

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

func _set_bus_volume(bus_idx: int, linear: float) -> void:
	if bus_idx >= AudioServer.get_bus_count():
		return
	var db := linear_to_db(linear) if linear > 0.001 else -80.0
	AudioServer.set_bus_volume_db(bus_idx, db)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graficos", "calidad", opt_calidad.selected)
	cfg.set_value("graficos", "sombras", opt_sombras.selected)
	cfg.set_value("graficos", "aa", opt_aa.selected)
	cfg.set_value("graficos", "vsync", chk_vsync.button_pressed)
	cfg.set_value("graficos", "render_scale", int(slider_render.value))
	cfg.set_value("graficos", "fps", opt_fps.selected)
	cfg.set_value("audio", "vol_general", int(slider_vol.value))
	cfg.set_value("audio", "musica", int(slider_musica.value))
	cfg.set_value("audio", "efectos", int(slider_efectos.value))

	var sv_val := 150
	if slider_volante:
		sv_val = int(slider_volante.value)
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

# =======================================================================
# LÓGICA DE DIBUJO ESTRUCTURADO (TARJETAS/FILAS PARA DRAGGING FÁCIL)
# =======================================================================
func _crear_tarjeta_fila(label_text: String, control_node: Control, value_label: Label = null) -> PanelContainer:
	var card := PanelContainer.new()
	
	# Tarjetas de vidrio más grandes, redondeadas y bonitas (vidrio templado premium)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.05) # Vidrio un poco más brillante
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.corner_radius_top_left = 22 # Más redondeado
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.content_margin_left = 32 # Más espacio
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 32) # Letras grandes y legibles
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)
	
	if control_node:
		control_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(control_node)
		
	if value_label:
		value_label.add_theme_font_override("font", FONT)
		value_label.add_theme_font_size_override("font_size", 32) # Valores grandes
		value_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0)) # Color dorado destacado
		value_label.custom_minimum_size = Vector2(120, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(value_label)
		
	card.add_child(hbox)
	return card

# =======================================================================
# CONTROLES Y OPTIMIZACIÓN UI
# =======================================================================
func _ensure_controls_ui() -> void:
	if not pagina_controles:
		return
		
	for child in pagina_controles.get_children():
		child.queue_free()
		
	# Slider Grabber Texture más grande (radio 22 -> 44px diámetro)
	var grabber_tex = _crear_textura_grabber(22, Color(0.06, 0.08, 0.15), Color(0.008, 0.43, 0.8))
	
	# 1. Sensibilidad Volante
	slider_volante = HSlider.new()
	slider_volante.min_value = 50
	slider_volante.max_value = 300
	slider_volante.value = 150
	slider_volante.custom_minimum_size = Vector2(350, 60)
	_estilizar_slider(slider_volante, grabber_tex)
	
	lbl_volante_val = Label.new()
	lbl_volante_val.text = "150%"
	
	var t_sens = _crear_tarjeta_fila("Sensibilidad Volante", slider_volante, lbl_volante_val)
	pagina_controles.add_child(t_sens)
	slider_volante.value_changed.connect(_on_volante_changed)
	
	# 2. Suavizado Dirección
	slider_suavizado_dir = HSlider.new()
	slider_suavizado_dir.min_value = 1.0
	slider_suavizado_dir.max_value = 25.0
	slider_suavizado_dir.step = 0.5
	slider_suavizado_dir.value = 10.0
	slider_suavizado_dir.custom_minimum_size = Vector2(350, 60)
	_estilizar_slider(slider_suavizado_dir, grabber_tex)
	
	lbl_suavizado_dir_val = Label.new()
	lbl_suavizado_dir_val.text = "10.0"
	
	var t_suav_dir = _crear_tarjeta_fila("Suavizado Direccion", slider_suavizado_dir, lbl_suavizado_dir_val)
	pagina_controles.add_child(t_suav_dir)
	slider_suavizado_dir.value_changed.connect(func(v):
		lbl_suavizado_dir_val.text = "%.1f" % v
	)
	
	# 3. Retorno Volante
	slider_retorno_vol = HSlider.new()
	slider_retorno_vol.min_value = 1.0
	slider_retorno_vol.max_value = 10.0
	slider_retorno_vol.step = 0.5
	slider_retorno_vol.value = 3.5
	slider_retorno_vol.custom_minimum_size = Vector2(350, 60)
	_estilizar_slider(slider_retorno_vol, grabber_tex)
	
	lbl_retorno_vol_val = Label.new()
	lbl_retorno_vol_val.text = "3.5"
	
	var t_ret = _crear_tarjeta_fila("Retorno Volante", slider_retorno_vol, lbl_retorno_vol_val)
	pagina_controles.add_child(t_ret)
	slider_retorno_vol.value_changed.connect(func(v):
		lbl_retorno_vol_val.text = "%.1f" % v
	)
	
	# 4. Suavizado Pedales
	slider_suavizado_ped = HSlider.new()
	slider_suavizado_ped.min_value = 1.0
	slider_suavizado_ped.max_value = 10.0
	slider_suavizado_ped.step = 0.5
	slider_suavizado_ped.value = 3.5
	slider_suavizado_ped.custom_minimum_size = Vector2(350, 60)
	_estilizar_slider(slider_suavizado_ped, grabber_tex)
	
	lbl_suavizado_ped_val = Label.new()
	lbl_suavizado_ped_val.text = "3.5"
	
	var t_ped = _crear_tarjeta_fila("Suavizado Pedales", slider_suavizado_ped, lbl_suavizado_ped_val)
	pagina_controles.add_child(t_ped)
	slider_suavizado_ped.value_changed.connect(func(v):
		lbl_suavizado_ped_val.text = "%.1f" % v
	)

func _ensure_demas_ui() -> void:
	if not pagina_demas:
		return
		
	for child in pagina_demas.get_children():
		child.queue_free()
		
	# Slider Grabber Texture más grande (radio 22 -> 44px diámetro)
	var grabber_tex = _crear_textura_grabber(22, Color(0.06, 0.08, 0.15), Color(0.008, 0.43, 0.8))
	
	var lbl_titulo := Label.new()
	lbl_titulo.text = "OPTIMIZACION Y DETALLES"
	lbl_titulo.add_theme_font_override("font", FONT)
	lbl_titulo.add_theme_font_size_override("font_size", 38) # Título más imponente
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pagina_demas.add_child(lbl_titulo)
	
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 30)
	pagina_demas.add_child(sep)
	
	# 1. Chk Optimizador Ciudad
	chk_city_opt = CheckButton.new()
	chk_city_opt.custom_minimum_size = Vector2(0, 95)
	chk_city_opt.add_theme_font_override("font", FONT)
	chk_city_opt.add_theme_font_size_override("font_size", 32)
	var t_opt = _crear_tarjeta_fila("Optimizar Ciudad (Chunks)", chk_city_opt)
	pagina_demas.add_child(t_opt)
	
	# 2. Slider Distancia Carga Ciudad
	slider_city_dist = HSlider.new()
	slider_city_dist.min_value = 50
	slider_city_dist.max_value = 600
	slider_city_dist.step = 10
	slider_city_dist.value = 200
	slider_city_dist.custom_minimum_size = Vector2(350, 60)
	_estilizar_slider(slider_city_dist, grabber_tex)
	
	lbl_city_dist_val = Label.new()
	lbl_city_dist_val.text = "200m"
	
	var t_dist = _crear_tarjeta_fila("Distancia de Carga (m)", slider_city_dist, lbl_city_dist_val)
	pagina_demas.add_child(t_dist)
	
	slider_city_dist.value_changed.connect(func(v):
		lbl_city_dist_val.text = str(int(v)) + "m"
	)
	
	chk_city_opt.toggled.connect(func(pressed: bool):
		chk_city_opt.text = "ACTIVO" if pressed else "DESACT."
		t_dist.visible = pressed
	)
	
	# 3. Chk SSAO
	chk_ssao = CheckButton.new()
	chk_ssao.custom_minimum_size = Vector2(0, 95)
	chk_ssao.add_theme_font_override("font", FONT)
	chk_ssao.add_theme_font_size_override("font_size", 32)
	chk_ssao.toggled.connect(func(p): chk_ssao.text = "ACTIVO" if p else "DESACT.")
	var t_ssao = _crear_tarjeta_fila("Sombras SSAO (Contacto)", chk_ssao)
	pagina_demas.add_child(t_ssao)
	
	# 4. Chk Glow
	chk_glow = CheckButton.new()
	chk_glow.custom_minimum_size = Vector2(0, 95)
	chk_glow.add_theme_font_override("font", FONT)
	chk_glow.add_theme_font_size_override("font_size", 32)
	chk_glow.toggled.connect(func(p): chk_glow.text = "ACTIVO" if p else "DESACT.")
	var t_glow = _crear_tarjeta_fila("Resplandor (Glow/Brillo)", chk_glow)
	pagina_demas.add_child(t_glow)
	
	# 5. Chk SDFGI
	chk_sdfgi = CheckButton.new()
	chk_sdfgi.custom_minimum_size = Vector2(0, 95)
	chk_sdfgi.add_theme_font_override("font", FONT)
	chk_sdfgi.add_theme_font_size_override("font_size", 32)
	chk_sdfgi.toggled.connect(func(p): chk_sdfgi.text = "ACTIVO" if p else "DESACT.")
	var t_sdfgi = _crear_tarjeta_fila("Iluminacion Global (SDFGI)", chk_sdfgi)
	pagina_demas.add_child(t_sdfgi)

func _on_volante_changed(val: float) -> void:
	if lbl_volante_val:
		lbl_volante_val.text = str(int(val)) + "%"
	_apply_volante_sensitivity(float(val) / 100.0)

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
		
	if slider_volante:
		slider_volante.value = sv
		if lbl_volante_val:
			lbl_volante_val.text = str(int(sv)) + "%"
	if slider_suavizado_dir:
		slider_suavizado_dir.value = s_dir
		if lbl_suavizado_dir_val:
			lbl_suavizado_dir_val.text = "%.1f" % s_dir
	if slider_retorno_vol:
		slider_retorno_vol.value = r_vol
		if lbl_retorno_vol_val:
			lbl_retorno_vol_val.text = "%.1f" % r_vol
	if slider_suavizado_ped:
		slider_suavizado_ped.value = s_ped
		if lbl_suavizado_ped_val:
			lbl_suavizado_ped_val.text = "%.1f" % s_ped

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

func _on_volver_pressed() -> void:
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").return_from_settings()
	else:
		get_tree().change_scene_to_file("res://escenas/Perfil_Menu/Perfil_Menu.tscn")

func _crear_textura_grabber(radio: int, color_centro: Color, color_borde: Color) -> ImageTexture:
	var size = radio * 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centro = Vector2(radio, radio)
	for x in range(size):
		for y in range(size):
			var dist = centro.distance_to(Vector2(x, y))
			if dist <= radio:
				var alpha = 1.0
				if dist > radio - 1.0:
					alpha = radio - dist
				
				if dist > radio - 4.0:
					img.set_pixel(x, y, Color(color_borde, alpha))
				elif dist > radio - 6.0:
					img.set_pixel(x, y, Color(0.1, 0.1, 0.15, alpha))
				elif dist < 4.0:
					img.set_pixel(x, y, Color(color_borde, alpha))
				else:
					img.set_pixel(x, y, Color(color_centro, alpha))
	return ImageTexture.create_from_image(img)

func _estilizar_slider(slider: HSlider, grabber_tex: ImageTexture) -> void:
	if not slider:
		return
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_tex)
	
	var sb_track = StyleBoxFlat.new()
	sb_track.bg_color = Color(0.06, 0.07, 0.12, 0.95)
	sb_track.border_width_left = 1
	sb_track.border_width_top = 1
	sb_track.border_width_right = 1
	sb_track.border_width_bottom = 1
	sb_track.border_color = Color(0.12, 0.18, 0.3, 0.8)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb_track.set("corner_radius_" + corner, 8)
	sb_track.expand_margin_top = 8 # Pista más gruesa
	sb_track.expand_margin_bottom = 8
	
	var sb_area = StyleBoxFlat.new()
	sb_area.bg_color = Color(0.008, 0.43, 0.8, 1.0)
	sb_area.set("corner_radius_top_left", 8)
	sb_area.set("corner_radius_bottom_left", 8)
	sb_area.expand_margin_top = 8
	sb_area.expand_margin_bottom = 8
	
	slider.add_theme_stylebox_override("slider", sb_track)
	slider.add_theme_stylebox_override("grabber_area", sb_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", sb_area)
	
	var parent = slider.get_parent()
	var scroll: ScrollContainer = null
	while parent:
		if parent is ScrollContainer:
			scroll = parent
			break
		parent = parent.get_parent()
		
	if scroll:
		var original_v_mode = scroll.vertical_scroll_mode
		var original_h_mode = scroll.horizontal_scroll_mode
		
		slider.drag_started.connect(func():
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		)
		slider.drag_ended.connect(func(changed):
			scroll.vertical_scroll_mode = original_v_mode
			scroll.horizontal_scroll_mode = original_h_mode
		)

func _on_salir_menu_pressed() -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.next_scene = "res://escenas/main menu/Main-Menu.tscn"
	
	get_tree().paused = false
	
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").return_from_settings()
		
	get_tree().change_scene_to_file("res://escenas/gui/escena_carga.tscn")

func _find_directional_lights(node: Node, result: Array) -> void:
	if node is DirectionalLight3D:
		result.append(node)
	for child in node.get_children():
		_find_directional_lights(child, result)
