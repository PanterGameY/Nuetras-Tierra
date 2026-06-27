@tool
extends CanvasLayer
class_name CelularUI

# ══════════════════════════════════════════════════════════════════════════════
#  CelularUI.gd  |  Nuestra Tierra — Movil Premium UI v3.0
#  Diseno: iOS 17 / Material You  |  Glassmorphism dark
# ══════════════════════════════════════════════════════════════════════════════

# ─── Paleta de colores global ───────────────────────────────────────────────
const C_BG          := Color(0.05, 0.05, 0.08, 0.97)
const C_SURFACE     := Color(0.10, 0.10, 0.14, 0.98)
const C_SURFACE2    := Color(0.14, 0.14, 0.19, 1.00)
const C_BORDER      := Color(0.25, 0.25, 0.32, 0.70)
const C_ACCENT      := Color(0.20, 0.60, 1.00, 1.00)   # azul electrico
const C_ACCENT2     := Color(0.55, 0.25, 1.00, 1.00)   # violeta
const C_GREEN       := Color(0.14, 0.85, 0.45, 1.00)
const C_YELLOW      := Color(1.00, 0.78, 0.10, 1.00)
const C_RED         := Color(0.95, 0.22, 0.22, 1.00)
const C_ORANGE      := Color(1.00, 0.50, 0.10, 1.00)
const C_TEXT        := Color(0.95, 0.95, 1.00, 1.00)
const C_TEXT_DIM    := Color(0.55, 0.55, 0.65, 1.00)
const C_SHADOW      := Color(0.00, 0.00, 0.00, 0.70)

# ─── Referencias ────────────────────────────────────────────────────────────
var player: CharacterBody3D = null
var gps_line = null  # GPSRutaLinea — sin tipo para evitar error si el script tiene problemas

# ─── Estado celular ──────────────────────────────────────────────────────────
var is_open: bool          = false
var current_app: String    = "home"
var target_y_offset: float = 1200.0
var current_y_offset: float= 1200.0
var phone_scale: float     = 1.0

# ─── Nodos principales ───────────────────────────────────────────────────────
var phone_frame: PanelContainer
var status_time_label: Label
var status_battery_label: Label
var open_button: Button
var open_button_icon: TextureRect = null
var screen_panel: Panel

# ─── Contenedores de apps ────────────────────────────────────────────────────
var app_container_home: Control
var app_container_waze: Control
var app_container_settings: Control
var app_container_bank: Control
var app_container_music: Control
var app_container_garage: Control
var app_container_jobs: Control

# ─── GPS & UI Waze ───────────────────────────────────────────────────────────
var minimap_viewport: SubViewport  = null
var minimap_camera: Camera3D       = null
var follow_player_camera: bool     = true
var recenter_button: Button        = null
var search_line_edit: LineEdit     = null
var search_dropdown_container: ScrollContainer = null
var search_dropdown_list: VBoxContainer        = null
var _gps_heading: float = 0.0

# NUEVO: Referencias para trazar la ruta sobre el minimapa 3D
var ruta_activa_3d: PackedVector3Array = PackedVector3Array()
var linea_gps_2d: Line2D = null
var dest_marker_2d: Panel = null
var player_dot_2d: Panel = null  # Marcador 2D de posicion del jugador en el GPS

# Optimizaciones de CPU
var _gps_update_timer: float = 0.0
const GPS_UPDATE_INTERVAL: float = 0.08 # Actualizar línea 2D ~12 veces por segundo

# ─── Labels de datos ─────────────────────────────────────────────────────────
var bank_money_label: Label
var bank_emeralds_label: Label
var music_track_label: Label
var music_artist_label: Label
var music_progress_bar: ProgressBar

# ─── Destinos ────────────────────────────────────────────────────────────────
var destinations: Dictionary = {
	"Taller de Rines"   : Vector3(-25.0, 0.0, -10.0),
	"Centro Ciudad"     : Vector3(0.0,   1.5, -60.0),
	"Zona de Carga"     : Vector3(45.0,  0.0,  20.0),
	"Gasolinera Norte"  : Vector3(-80.0, 0.0,  45.0),
	"Estacion de Policia": Vector3(30.0, 0.0, -90.0),
	"Taller Mecanico"   : Vector3(-50.0, 0.0, -35.0),
	"Mercado Central"   : Vector3(12.0,  0.0,  80.0),
	"Mensajero"         : Vector3(45.0,  0.0,  20.0),
}

# Musica de ejemplo (con archivos reales en el proyecto)
var music_tracks: Array = [
	{"title":"Aire de Son", "artist":"Nuestra Tierra", "file":"res://recursos/Musica/Aire-de-son.mp3"},
	{"title":"Puya Vallenata", "artist":"Nuestra Tierra", "file":"res://recursos/Musica/Puya-vallenata.mp3"},
]
var current_track_idx: int = 0
var is_playing_music: bool = false
var tiene_audifonos: bool = false
var music_player: AudioStreamPlayer = null
var play_btn: Button = null
var play_btn_texture: TextureRect = null
var t_start: Label = null
var t_end: Label = null
var visualizer_bars: Array[Control] = []
var music_headphones_warning: Label = null
var music_headphones_btn: Button = null
var is_horizontal: bool = false
var is_rotating: bool = false
var original_phone_position: Vector2 = Vector2.ZERO
var original_phone_rotation: float = 0.0
var original_phone_scale: Vector2 = Vector2.ONE

# Pantalla de Carga (Splash Screen)
var splash_screen: Panel = null
# Cache UI
var ui_pie: CanvasLayer = null

# Fuente global Moderniz
var _font: FontFile = null

# ═════════════════════════════════════════════════════════════════════════════
#  INICIALIZACION
# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = 15 # Aumentado a 15 (mayor que UIVehiculo que es 10) para estar encima del HUD del coche
	player = get_parent() as CharacterBody3D

	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	_font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	if player:
		gps_line = player.get_node_or_null("GPSRutaLinea")
		if not gps_line:
			var gps_script = load("res://Scripts/GPSRutaLinea.gd")
			gps_line = gps_script.new()
			gps_line.name = "GPSRutaLinea"
			player.add_child(gps_line)
		var main_cam = player.get("_camera") as Camera3D
		if main_cam:
			main_cam.cull_mask = main_cam.cull_mask & ~2

	_setup_ui()
	
	if minimap_camera:
		minimap_camera.cull_mask = 2
	
	call_deferred("_configurar_carreteras_minimapa")
	_update_app_visibility()

	if _font and screen_panel:
		_apply_font_recursive(screen_panel)

	var size_y = get_viewport().get_visible_rect().size.y
	target_y_offset  = size_y + 200
	current_y_offset = target_y_offset
	phone_frame.position.y = current_y_offset

func _apply_font_recursive(node: Node, skip_scale: bool = false) -> void:
	if not _font:
		return
	var current_skip = skip_scale or (node.name == "AppJobs")
	for child in node.get_children():
		if child is Label:
			var lbl := child as Label
			lbl.add_theme_font_override("font", _font)
			var fs = lbl.get_theme_font_size("font_size")
			if fs > 0:
				var target_fs = fs if current_skip else max(8, int(fs * 0.70))
				lbl.add_theme_font_size_override("font_size", target_fs)
		elif child is Button:
			var btn := child as Button
			btn.add_theme_font_override("font", _font)
			var fs = btn.get_theme_font_size("font_size")
			if fs > 0:
				var target_fs = fs if current_skip else max(8, int(fs * 0.70))
				btn.add_theme_font_size_override("font_size", target_fs)
		elif child is LineEdit:
			var le := child as LineEdit
			le.add_theme_font_override("font", _font)
			var fs = le.get_theme_font_size("font_size")
			if fs > 0:
				var target_fs = fs if current_skip else max(8, int(fs * 0.70))
				le.add_theme_font_size_override("font_size", target_fs)
		if child.get_child_count() > 0:
			_apply_font_recursive(child, current_skip)

# ═════════════════════════════════════════════════════════════════════════════
#  CONSTRUCCION PRINCIPAL
# ═════════════════════════════════════════════════════════════════════════════
func _setup_ui() -> void:
	phone_frame = get_node("PhoneFrame") as PanelContainer
	screen_panel = get_node("PhoneFrame/RootVBox/ScreenWrap/ScreenPanel") as Panel
	var screen_content = get_node("PhoneFrame/RootVBox/ScreenWrap/ScreenPanel/ScreenContent") as Control
	status_time_label = get_node("PhoneFrame/RootVBox/StatusBar/HBox/TimeLabel") as Label
	status_battery_label = get_node("PhoneFrame/RootVBox/StatusBar/HBox/BatteryLabel") as Label

	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color            = C_BG
	frame_style.border_width_left   = 2
	frame_style.border_width_top    = 8
	frame_style.border_width_right  = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color        = Color(0.30, 0.30, 0.40, 0.6)
	frame_style.corner_radius_top_left    = 42
	frame_style.corner_radius_top_right   = 42
	frame_style.corner_radius_bottom_left = 42
	frame_style.corner_radius_bottom_right= 42
	frame_style.shadow_color = C_SHADOW
	frame_style.shadow_size  = 32
	frame_style.shadow_offset= Vector2(0, 8)
	phone_frame.add_theme_stylebox_override("panel", frame_style)

	var pill = get_node("PhoneFrame/RootVBox/NotchBar/Pill") as Panel
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.22, 0.22, 0.30, 0.9)
	ps.corner_radius_top_left     = 4
	ps.corner_radius_top_right    = 4
	ps.corner_radius_bottom_left  = 4
	ps.corner_radius_bottom_right = 4
	pill.add_theme_stylebox_override("panel", ps)

	var status_signal = get_node("PhoneFrame/RootVBox/StatusBar/HBox/SignalLabel") as Label
	status_signal.add_theme_color_override("font_color", C_TEXT_DIM)
	status_time_label.add_theme_color_override("font_color", C_TEXT)
	status_battery_label.add_theme_color_override("font_color", C_GREEN)

	var sp_style = StyleBoxFlat.new()
	sp_style.bg_color              = C_SURFACE
	sp_style.corner_radius_top_left    = 20
	sp_style.corner_radius_top_right   = 20
	sp_style.corner_radius_bottom_left = 20
	sp_style.corner_radius_bottom_right= 20
	screen_panel.add_theme_stylebox_override("panel", sp_style)

	app_container_home = screen_content.get_node("AppHome")
	app_container_waze = screen_content.get_node("AppWaze")
	app_container_settings = screen_content.get_node("AppSettings")
	app_container_bank = screen_content.get_node("AppBank")
	app_container_music = screen_content.get_node("AppMusic")
	app_container_garage = screen_content.get_node("AppGarage")
	app_container_jobs = screen_content.get_node("AppJobs")

	_setup_app_home(screen_content)
	_setup_app_waze(screen_content)
	_setup_app_settings(screen_content)
	_setup_app_bank(screen_content)
	_setup_app_music(screen_content)
	_setup_app_garage(screen_content)
	_setup_app_jobs(screen_content)

	var nav = get_node("PhoneFrame/RootVBox/NavBar") as HBoxContainer
	_configure_nav_bar(nav)

	var swipe_bar = get_node("PhoneFrame/RootVBox/SwipeRow/SwipeBar") as Panel
	var sw_style = StyleBoxFlat.new()
	sw_style.bg_color              = Color(0.5, 0.5, 0.6, 0.5)
	sw_style.corner_radius_top_left    = 3
	sw_style.corner_radius_top_right   = 3
	sw_style.corner_radius_bottom_left = 3
	sw_style.corner_radius_bottom_right= 3
	swipe_bar.add_theme_stylebox_override("panel", sw_style)

	_setup_hud_button()

func _configure_nav_bar(bar: HBoxContainer) -> void:
	bar.custom_minimum_size = Vector2(0, 68)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 40)
	for child in bar.get_children():
		child.queue_free()

	var back_btn = _make_nav_btn("←", "_back")
	back_btn.pressed.disconnect(back_btn.pressed.get_connections()[0]["callable"])
	back_btn.pressed.connect(func(): _switch_app("home"))
	bar.add_child(back_btn)
	bar.add_child(_make_nav_btn("⌂", "home"))

	var close_btn = _make_nav_btn("✕", "_close")
	close_btn.pressed.disconnect(close_btn.pressed.get_connections()[0]["callable"])
	close_btn.pressed.connect(func(): close_phone())
	bar.add_child(close_btn)

func _make_nav_btn(icon: String, app: String) -> Button:
	var btn = Button.new()
	btn.text = icon
	btn.flat = true
	btn.custom_minimum_size = Vector2(52, 52)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pivot_offset = Vector2(26, 26)
	
	var empty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_font_size_override("font_size", 28)
	
	if icon == "✕":
		btn.add_theme_color_override("font_color", Color(0.95, 0.22, 0.22))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.35, 0.35))
	else:
		btn.add_theme_color_override("font_color", Color(0.12, 0.15, 0.22))
		btn.add_theme_color_override("font_hover_color", Color(0.12, 0.64, 0.88))
	
	btn.pressed.connect(func(): _switch_app(app))
	
	btn.mouse_entered.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)
	return btn

func _setup_hud_button() -> void:
	open_button = get_node("OpenButton") as Button
	open_button.custom_minimum_size = Vector2(80, 80)
	open_button_icon = TextureRect.new()
	open_button_icon.texture = load("res://escenas/gui/UIVehiculo/imagenes/telefono.png") as Texture2D
	open_button_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	open_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	open_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_button.add_child(open_button_icon)
	
	open_button_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	open_button_icon.offset_left = 12
	open_button_icon.offset_top = 12
	open_button_icon.offset_right = -12
	open_button_icon.offset_bottom = -12

	var n = StyleBoxFlat.new()
	n.bg_color    = Color(0.06, 0.06, 0.10, 0.90)
	n.border_width_left   = 2; n.border_width_top    = 2
	n.border_width_right  = 2; n.border_width_bottom = 2
	n.border_color        = C_ACCENT
	n.corner_radius_top_left     = 40; n.corner_radius_top_right    = 40
	n.corner_radius_bottom_left  = 40; n.corner_radius_bottom_right = 40
	n.shadow_color = C_SHADOW; n.shadow_size = 10

	var h = n.duplicate() as StyleBoxFlat
	h.bg_color    = Color(0.12, 0.18, 0.30, 0.95)
	h.border_color= C_ACCENT

	open_button.add_theme_stylebox_override("normal",  n)
	open_button.add_theme_stylebox_override("hover",   h)
	open_button.add_theme_stylebox_override("pressed", n)
	open_button.add_theme_font_size_override("font_size", 34)
	open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	for conn in open_button.pressed.get_connections():
		open_button.pressed.disconnect(conn["callable"])
	open_button.pressed.connect(func(): toggle_phone())

# ═════════════════════════════════════════════════════════════════════════════
#  APP: HOME SCREEN
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_home(_parent: Control) -> void:
	var wallpaper_rect = app_container_home.get_node_or_null("WallpaperRect") as TextureRect
	if not wallpaper_rect:
		wallpaper_rect = TextureRect.new()
		wallpaper_rect.name = "WallpaperRect"
		app_container_home.add_child(wallpaper_rect)
		app_container_home.move_child(wallpaper_rect, 0)
	
	wallpaper_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wallpaper_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper_rect.stretch_mode = TextureRect.STRETCH_SCALE
	
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.94, 0.96, 0.99, 1.0),
		Color(0.97, 0.94, 0.96, 1.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	wallpaper_rect.texture = grad_tex

	var root = app_container_home.get_node("RootVBox") as VBoxContainer
	var header = root.get_node("Header") as Control
	if header: header.visible = false
	var sep = root.get_node("Sep") as Control
	if sep: sep.custom_minimum_size = Vector2(0, 24)
	
	var grid = root.get_node("GridMargin/Grid") as GridContainer
	var dock_bg = root.get_node("DockMargin/DockBG") as Panel
	var dock_hbox = dock_bg.get_node("DockHBox") as HBoxContainer

	for child in grid.get_children():
		child.queue_free()

	var apps = [
		["res://recursos/iconos app/app_mapa.png",    "GPS Waze", C_ACCENT,                func(): _switch_app("waze")],
		["res://recursos/iconos app/app_banco.png",   "Banco",    Color(0.10, 0.72, 0.32), func(): _switch_app("bank")],
		["res://recursos/iconos app/app_musica.png",  "Musica",   C_ACCENT2,               func(): _switch_app("music")],
		["🔧",                                        "Garage",   C_ORANGE,                func(): _switch_app("garage")],
		["🪪",                                        "Trabajos", Color(0.12, 0.64, 0.88), func(): _switch_app("jobs")],
		["res://recursos/iconos app/app_ajustes.png", "Ajustes",  Color(0.30, 0.32, 0.40), func(): _switch_app("settings")],
		["💾",                                        "Guardar",  Color(0.60, 0.15, 0.20), func(): _save_game()],
	]
	for app_data in apps:
		grid.add_child(_create_app_icon(app_data[0], app_data[1], app_data[2], app_data[3]))

	var dock_st = StyleBoxFlat.new()
	dock_st.bg_color = Color(1.0, 1.0, 1.0, 0.45)
	dock_st.corner_radius_top_left=26;dock_st.corner_radius_top_right=26
	dock_st.corner_radius_bottom_left=26;dock_st.corner_radius_bottom_right=26
	dock_st.border_width_left=1;dock_st.border_width_top=1
	dock_st.border_width_right=1;dock_st.border_width_bottom=1
	dock_st.border_color = Color(1.0, 1.0, 1.0, 0.7)
	dock_st.shadow_color = Color(0.08, 0.10, 0.18, 0.06)
	dock_st.shadow_size = 14
	dock_bg.add_theme_stylebox_override("panel", dock_st)

	for child in dock_hbox.get_children():
		child.queue_free()

	var quick_apps = [
		["📞", "Llamar"],
		["📸", "Camara"],
		["res://recursos/iconos app/app_mapa.png", "GPS"],
		["💬", "Mensajes"],
	]
	for qa in quick_apps:
		var qbtn = Button.new()
		qbtn.flat  = true
		qbtn.custom_minimum_size = Vector2(56, 56)
		
		var d_holder = Panel.new()
		d_holder.custom_minimum_size = Vector2(56, 56)
		var dh_st = StyleBoxFlat.new()
		dh_st.bg_color = Color(1.0, 1.0, 1.0, 0.75)
		dh_st.corner_radius_top_left = 16; dh_st.corner_radius_top_right = 16
		dh_st.corner_radius_bottom_left = 16; dh_st.corner_radius_bottom_right = 16
		dh_st.border_width_left = 1; dh_st.border_width_top = 1
		dh_st.border_width_right = 1; dh_st.border_width_bottom = 1
		dh_st.border_color = Color(1.0, 1.0, 1.0, 0.9)
		d_holder.add_theme_stylebox_override("panel", dh_st)
		d_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qbtn.add_child(d_holder)
		d_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		if qa[0].begins_with("res://"):
			var rect = TextureRect.new()
			rect.texture = load(qa[0]) as Texture2D
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.custom_minimum_size = Vector2(34, 34)
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			d_holder.add_child(rect)
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rect.offset_left = 11; rect.offset_top = 11
			rect.offset_right = -11; rect.offset_bottom = -11
		else:
			var elbl = Label.new()
			elbl.text  = qa[0]
			elbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			elbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			elbl.add_theme_font_size_override("font_size", 24)
			elbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			d_holder.add_child(elbl)
			elbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		if qa[1] == "GPS":
			qbtn.pressed.connect(func(): _switch_app("waze"))
		
		qbtn.mouse_entered.connect(func():
			var tw = qbtn.create_tween()
			tw.tween_property(qbtn, "modulate", Color(1.15, 1.15, 1.15, 1.0), 0.1)
		)
		qbtn.mouse_exited.connect(func():
			var tw = qbtn.create_tween()
			tw.tween_property(qbtn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
		)
		dock_hbox.add_child(qbtn)

func _save_game() -> void:
	if player and player.has_method("guardar_progreso_conductor"):
		player.guardar_progreso_conductor()

func _create_app_icon(icon: String, title: String, color: Color, action: Callable) -> Button:
	var btn = Button.new()
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(130, 140)

	var empty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.pressed.connect(action)

	btn.mouse_entered.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "modulate", Color(1.15, 1.15, 1.15, 1.0), 0.12)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var holder = Panel.new()
	holder.custom_minimum_size = Vector2(106, 106)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h_st = StyleBoxFlat.new()
	
	if icon.begins_with("res://"):
		h_st.bg_color = Color(1.0, 1.0, 1.0, 0.65)
		h_st.border_color = Color(0.85, 0.88, 0.93, 1.0)
	else:
		h_st.bg_color = color.lightened(0.25)
		h_st.border_color = Color(1.0, 1.0, 1.0, 0.9)

	h_st.border_width_left = 1; h_st.border_width_top = 1
	h_st.border_width_right = 1; h_st.border_width_bottom = 1
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		h_st.set("corner_radius_" + c, 30)
	h_st.shadow_color = Color(0.08, 0.10, 0.18, 0.04)
	h_st.shadow_size = 10
	holder.add_theme_stylebox_override("panel", h_st)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(holder)

	if icon.begins_with("res://"):
		var rect = TextureRect.new()
		rect.texture = load(icon) as Texture2D
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.offset_left = 22; rect.offset_top = 22
		rect.offset_right = -22; rect.offset_bottom = -22
	else:
		var emoji_lbl = Label.new()
		emoji_lbl.text = icon
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(emoji_lbl)
		emoji_lbl.add_theme_font_size_override("font_size", 52)
		emoji_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lbl = Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		lbl.add_theme_font_override("font", _font)
	vbox.add_child(lbl)

	return btn

# ═════════════════════════════════════════════════════════════════════════════
#  APP: GPS WAZE  (pantalla completa dentro del movil)
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_waze(_parent: Control) -> void:
	for child in app_container_waze.get_children():
		child.queue_free()

	# 1. Viewport Container
	var vp_container = SubViewportContainer.new()
	vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	app_container_waze.add_child(vp_container)
	vp_container.gui_input.connect(_on_minimap_gui_input)

	minimap_viewport = SubViewport.new()
	minimap_viewport.size    = Vector2(500, 780)
	minimap_viewport.msaa_3d = Viewport.MSAA_2X
	vp_container.add_child(minimap_viewport)

	minimap_camera = Camera3D.new()
	minimap_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	minimap_camera.fov        = 55.0
	minimap_camera.far        = 500.0
	minimap_camera.rotation   = Vector3(-PI / 2.0, 0.0, 0.0)
	minimap_camera.cull_mask  = 2 # Corregido: Solo capa 2 para el mapa
	minimap_viewport.add_child(minimap_camera)

	# ─── AGREGADO MAGICO: DIBUJAR LINEA 2D SOBRE EL VIEWPORT 3D ─────────
	linea_gps_2d = Line2D.new()
	linea_gps_2d.width = 10.0
	linea_gps_2d.default_color = Color(0.20, 0.60, 1.00, 0.85) # Azul Waze brillante
	linea_gps_2d.joint_mode = Line2D.LINE_JOINT_ROUND
	linea_gps_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
	linea_gps_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
	linea_gps_2d.antialiased = true
	app_container_waze.add_child(linea_gps_2d)

	dest_marker_2d = Panel.new()
	dest_marker_2d.custom_minimum_size = Vector2(24, 24)
	dest_marker_2d.visible = false
	var dm_style = StyleBoxFlat.new()
	dm_style.bg_color = Color(0.95, 0.22, 0.22, 1.0) # Rojo
	dm_style.border_width_left = 3
	dm_style.border_width_top = 3
	dm_style.border_width_right = 3
	dm_style.border_width_bottom = 3
	dm_style.border_color = Color.WHITE
	dm_style.corner_radius_top_left = 12
	dm_style.corner_radius_top_right = 12
	dm_style.corner_radius_bottom_left = 12
	dm_style.corner_radius_bottom_right = 12
	dest_marker_2d.add_theme_stylebox_override("panel", dm_style)
	app_container_waze.add_child(dest_marker_2d)

	# Marcador 2D del jugador (punto azul con borde blanco)
	player_dot_2d = Panel.new()
	player_dot_2d.custom_minimum_size = Vector2(20, 20)
	player_dot_2d.visible = false
	var pd_style = StyleBoxFlat.new()
	pd_style.bg_color = Color(0.10, 0.55, 1.0, 1.0)  # Azul GPS
	pd_style.border_width_left = 3
	pd_style.border_width_top = 3
	pd_style.border_width_right = 3
	pd_style.border_width_bottom = 3
	pd_style.border_color = Color(1.0, 1.0, 1.0, 0.95)
	pd_style.corner_radius_top_left = 10
	pd_style.corner_radius_top_right = 10
	pd_style.corner_radius_bottom_left = 10
	pd_style.corner_radius_bottom_right = 10
	pd_style.shadow_color = Color(0.0, 0.3, 0.9, 0.5)
	pd_style.shadow_size = 8
	player_dot_2d.add_theme_stylebox_override("panel", pd_style)
	player_dot_2d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_container_waze.add_child(player_dot_2d)
	# ──────────────────────────────────────────────────────────────────────

	var map_env = Environment.new()
	map_env.background_mode  = Environment.BG_COLOR
	map_env.background_color = Color(0.96, 0.97, 0.99, 1.0)
	map_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	map_env.ambient_light_color  = Color(0.95, 0.95, 1.00)
	map_env.ambient_light_energy = 1.6
	map_env.adjustment_enabled    = true
	map_env.adjustment_brightness = 1.10
	map_env.adjustment_contrast   = 1.15
	map_env.adjustment_saturation = 0.90
	map_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	minimap_camera.environment = map_env

	# 2a. Viñeta suave en los bordes
	var vignette = Panel.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_style = StyleBoxFlat.new()
	vig_style.bg_color            = Color(0, 0, 0, 0)
	vig_style.border_width_left   = 40
	vig_style.border_width_right  = 40
	vig_style.border_width_top    = 40
	vig_style.border_width_bottom = 40
	vig_style.border_color        = Color(0.90, 0.92, 0.96, 0.40)
	vig_style.corner_radius_top_left     = 20
	vig_style.corner_radius_top_right    = 20
	vig_style.corner_radius_bottom_left  = 20
	vig_style.corner_radius_bottom_right = 20
	vignette.add_theme_stylebox_override("panel", vig_style)
	app_container_waze.add_child(vignette)

	# 2b. Grilla sutil
	var grid_root = Control.new()
	grid_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_container_waze.add_child(grid_root)
	for gx in range(1, 5):
		var gl = ColorRect.new()
		gl.color       = Color(0.10, 0.30, 0.60, 0.04)
		gl.anchor_left = float(gx) / 5.0; gl.anchor_right  = float(gx) / 5.0
		gl.anchor_top  = 0.0;             gl.anchor_bottom  = 1.0
		gl.offset_right= 1
		gl.mouse_filter= Control.MOUSE_FILTER_IGNORE
		grid_root.add_child(gl)
	for gy in range(1, 8):
		var gl = ColorRect.new()
		gl.color        = Color(0.10, 0.30, 0.60, 0.04)
		gl.anchor_top   = float(gy) / 8.0; gl.anchor_bottom = float(gy) / 8.0
		gl.anchor_left  = 0.0;             gl.anchor_right   = 1.0
		gl.offset_bottom= 1
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_root.add_child(gl)

	# 2c. Brujula
	var compass_panel = Panel.new()
	compass_panel.custom_minimum_size = Vector2(68, 68)
	compass_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	compass_panel.offset_left   = -86
	compass_panel.offset_top    = -86
	compass_panel.offset_right  = -14
	compass_panel.offset_bottom = -14
	compass_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var comp_st = StyleBoxFlat.new()
	comp_st.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	comp_st.corner_radius_top_left=34;comp_st.corner_radius_top_right=34
	comp_st.corner_radius_bottom_left=34;comp_st.corner_radius_bottom_right=34
	comp_st.border_width_left=1;comp_st.border_width_top=1
	comp_st.border_width_right=1;comp_st.border_width_bottom=1
	comp_st.border_color = Color(0.85, 0.88, 0.92)
	comp_st.shadow_color = Color(0, 0, 0, 0.06); comp_st.shadow_size=10
	compass_panel.add_theme_stylebox_override("panel", comp_st)
	app_container_waze.add_child(compass_panel)

	var compass_lbl = Label.new()
	compass_lbl.text = "N"
	compass_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	compass_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	compass_lbl.add_theme_font_size_override("font_size", 26)
	compass_lbl.add_theme_color_override("font_color", Color(0.95, 0.22, 0.22))
	compass_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_child(compass_lbl)

	# 2d. Coordenadas GPS
	var coords_bg = Panel.new()
	coords_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	coords_bg.offset_left   = 12
	coords_bg.offset_top    = -58
	coords_bg.offset_bottom = -12
	coords_bg.offset_right  = 185
	coords_bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var cb_st = StyleBoxFlat.new()
	cb_st.bg_color = Color(1.0, 1.0, 1.0, 0.92)
	cb_st.corner_radius_top_left=10;cb_st.corner_radius_top_right=10
	cb_st.corner_radius_bottom_left=10;cb_st.corner_radius_bottom_right=10
	cb_st.border_width_left=1;cb_st.border_width_top=1
	cb_st.border_width_right=1;cb_st.border_width_bottom=1
	cb_st.border_color = Color(0.88, 0.90, 0.94)
	cb_st.content_margin_left=10;cb_st.content_margin_top=6
	cb_st.content_margin_bottom=6;cb_st.content_margin_right=10
	cb_st.shadow_color = Color(0,0,0,0.04); cb_st.shadow_size=6
	coords_bg.add_theme_stylebox_override("panel", cb_st)
	app_container_waze.add_child(coords_bg)

	var coords_label = Label.new()
	coords_label.name = "CoordsLabel"
	coords_label.text = "LAT 5.3170\nLON -73.9390"
	coords_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coords_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	coords_label.add_theme_font_size_override("font_size", 20)
	coords_label.add_theme_color_override("font_color", Color(0.12, 0.15, 0.22))
	coords_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coords_bg.add_child(coords_label)

	# 2e. Badge "EN VIVO"
	var live_badge = Panel.new()
	live_badge.custom_minimum_size = Vector2(90, 26)
	live_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	live_badge.offset_left   = -108
	live_badge.offset_right  = -14
	live_badge.offset_top    = 14
	live_badge.offset_bottom = 40
	live_badge.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var lb_st = StyleBoxFlat.new()
	lb_st.bg_color = Color(0.95, 0.22, 0.22, 1.0)
	lb_st.corner_radius_top_left=12;lb_st.corner_radius_top_right=12
	lb_st.corner_radius_bottom_left=12;lb_st.corner_radius_bottom_right=12
	lb_st.shadow_color = Color(0,0,0,0.08); lb_st.shadow_size=4
	live_badge.add_theme_stylebox_override("panel", lb_st)
	app_container_waze.add_child(live_badge)

	var live_lbl = Label.new()
	live_lbl.text = "● EN VIVO"
	live_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	live_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	live_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	live_lbl.add_theme_font_size_override("font_size", 20)
	live_lbl.add_theme_color_override("font_color", Color.WHITE)
	live_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live_badge.add_child(live_lbl)

	# 2f. Banda superior clara
	var top_overlay = Panel.new()
	var to_style = StyleBoxFlat.new()
	to_style.bg_color = Color(0.96, 0.97, 0.99, 0.88)
	top_overlay.add_theme_stylebox_override("panel", to_style)
	top_overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_overlay.offset_bottom = 88
	top_overlay.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	app_container_waze.add_child(top_overlay)

	# 3. Buscador
	var search_margin = MarginContainer.new()
	search_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	search_margin.offset_left  = 14
	search_margin.offset_right = -14
	search_margin.offset_top   = 14
	search_margin.offset_bottom= 72
	app_container_waze.add_child(search_margin)

	search_line_edit = LineEdit.new()
	search_line_edit.name = "SearchLineEdit"
	search_line_edit.placeholder_text = "  🔍  Buscar destino..."
	search_line_edit.add_theme_font_size_override("font_size", 22)
	search_line_edit.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	search_line_edit.add_theme_color_override("placeholder_color", Color(0.48, 0.50, 0.58, 0.70))

	var sl_style = StyleBoxFlat.new()
	sl_style.bg_color = Color.WHITE
	sl_style.border_width_left=1;sl_style.border_width_top=1
	sl_style.border_width_right=1;sl_style.border_width_bottom=1
	sl_style.border_color = Color(0.85, 0.88, 0.92)
	sl_style.corner_radius_top_left=16;sl_style.corner_radius_top_right=16
	sl_style.corner_radius_bottom_left=16;sl_style.corner_radius_bottom_right=16
	sl_style.content_margin_left=18;sl_style.content_margin_top=10;sl_style.content_margin_bottom=10
	sl_style.shadow_color=Color(0,0,0,0.06);sl_style.shadow_size=8
	search_line_edit.add_theme_stylebox_override("normal", sl_style)
	search_margin.add_child(search_line_edit)

	search_line_edit.text_changed.connect(_on_search_text_changed)
	search_line_edit.focus_entered.connect(_show_search_dropdown)

	# 4. Dropdown
	search_dropdown_container = ScrollContainer.new()
	search_dropdown_container.visible = false
	search_dropdown_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	search_dropdown_container.offset_left  = 14
	search_dropdown_container.offset_right = -14
	search_dropdown_container.offset_top   = 76
	search_dropdown_container.offset_bottom= 340
	app_container_waze.add_child(search_dropdown_container)

	var dd_bg = StyleBoxFlat.new()
	dd_bg.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	dd_bg.border_width_left=1;dd_bg.border_width_top=1
	dd_bg.border_width_right=1;dd_bg.border_width_bottom=1
	dd_bg.border_color = Color(0.85, 0.88, 0.92)
	dd_bg.corner_radius_bottom_left=16;dd_bg.corner_radius_bottom_right=16
	dd_bg.content_margin_left=10;dd_bg.content_margin_right=10
	dd_bg.content_margin_top=8;dd_bg.content_margin_bottom=8
	dd_bg.shadow_color=Color(0,0,0,0.08);dd_bg.shadow_size=10
	search_dropdown_container.add_theme_stylebox_override("panel", dd_bg)

	search_dropdown_list = VBoxContainer.new()
	search_dropdown_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_dropdown_list.add_theme_constant_override("separation", 6)
	search_dropdown_container.add_child(search_dropdown_list)

	# 5. Boton Re-centrar
	recenter_button = Button.new()
	recenter_button.text    = " 🎯 Centrar "
	recenter_button.visible = false
	recenter_button.custom_minimum_size = Vector2(150, 52)
	app_container_waze.add_child(recenter_button)
	recenter_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	recenter_button.offset_bottom = -28
	recenter_button.offset_top    = -80

	var rc_style = StyleBoxFlat.new()
	rc_style.bg_color = C_ACCENT2
	rc_style.corner_radius_top_left=26;rc_style.corner_radius_top_right=26
	rc_style.corner_radius_bottom_left=26;rc_style.corner_radius_bottom_right=26
	rc_style.shadow_color=Color(0,0,0,0.08);rc_style.shadow_size=10
	recenter_button.add_theme_stylebox_override("normal",  rc_style)
	recenter_button.add_theme_stylebox_override("hover",   rc_style)
	recenter_button.add_theme_stylebox_override("pressed", rc_style)
	recenter_button.add_theme_font_size_override("font_size", 20)
	recenter_button.add_theme_color_override("font_color", Color.WHITE)
	recenter_button.pressed.connect(func():
		follow_player_camera = true
		recenter_button.visible = false
	)

	# 6. Boton Cancelar navegacion
	var cancel_btn = Button.new()
	cancel_btn.text = " ✕ Cancelar "
	cancel_btn.custom_minimum_size = Vector2(130, 48)
	app_container_waze.add_child(cancel_btn)
	cancel_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cancel_btn.offset_right = -14
	cancel_btn.offset_top   = 80
	cancel_btn.offset_left  = -160
	cancel_btn.offset_bottom= 130

	var cl_style = StyleBoxFlat.new()
	cl_style.bg_color = C_RED
	cl_style.corner_radius_top_left=20;cl_style.corner_radius_top_right=20
	cl_style.corner_radius_bottom_left=20;cl_style.corner_radius_bottom_right=20
	cl_style.shadow_color=Color(0,0,0,0.08);cl_style.shadow_size=6
	cancel_btn.add_theme_stylebox_override("normal",  cl_style)
	cancel_btn.add_theme_stylebox_override("hover",   cl_style)
	cancel_btn.add_theme_stylebox_override("pressed", cl_style)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	cancel_btn.pressed.connect(func():
		if gps_line:
			gps_line.clear_route()
		search_line_edit.text = ""
		limpiar_ruta_mapa() # Limpiar la línea 2D al cancelar
	)

# ─── API PARA ACTUALIZAR GPS DESDE MENSAJERO.GD ──────────────────────────

func trazar_ruta_mapa(ruta_3d: PackedVector3Array) -> void:
	ruta_activa_3d = ruta_3d
	if linea_gps_2d:
		linea_gps_2d.visible = true

func limpiar_ruta_mapa() -> void:
	ruta_activa_3d.clear()
	if linea_gps_2d:
		linea_gps_2d.clear_points()
		linea_gps_2d.visible = false

# ─── Arrastre de camara GPS ──────────────────────────────────────────────────
func _on_minimap_gui_input(event: InputEvent) -> void:
	var is_drag = (event is InputEventScreenDrag) or \
		(event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if is_drag:
		follow_player_camera = false
		recenter_button.visible = true
		var factor = minimap_camera.size / minimap_viewport.size.x
		minimap_camera.global_position.x -= event.relative.x * factor
		minimap_camera.global_position.z -= event.relative.y * factor

func _show_search_dropdown() -> void:
	search_dropdown_container.visible = true
	_populate_dropdown("")

func _on_search_text_changed(t: String) -> void:
	_populate_dropdown(t)

func _populate_dropdown(filter: String) -> void:
	for c in search_dropdown_list.get_children():
		c.queue_free()
	var q = filter.to_lower().strip_edges()
	for dest_name in destinations.keys():
		if q != "" and not dest_name.to_lower().contains(q):
			continue
		var btn = Button.new()
		btn.text      = "📍  " + dest_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", C_TEXT)
		var s = StyleBoxFlat.new()
		s.bg_color = C_SURFACE2
		s.content_margin_left=18;s.content_margin_top=12;s.content_margin_bottom=12
		s.corner_radius_top_left=10;s.corner_radius_top_right=10
		s.corner_radius_bottom_left=10;s.corner_radius_bottom_right=10
		btn.add_theme_stylebox_override("normal", s)
		var sh = s.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.20, 0.30, 0.50, 0.95)
		btn.add_theme_stylebox_override("hover",  sh)
		var coords = destinations[dest_name]
		btn.pressed.connect(func():
			if gps_line:
				gps_line.set_destination(coords)
			search_line_edit.text = dest_name
			search_dropdown_container.visible = false
			search_line_edit.release_focus()
		)
		search_dropdown_list.add_child(btn)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if search_dropdown_container and search_dropdown_container.visible:
			if not search_dropdown_container.get_global_rect().has_point(event.position) and \
			   not search_line_edit.get_global_rect().has_point(event.position):
				search_dropdown_container.visible = false

# ═════════════════════════════════════════════════════════════════════════════
#  APP: BANCO
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_bank(_parent: Control) -> void:
	var bg_panel = app_container_bank.get_node("BGPanel") as Panel
	var root = app_container_bank.get_node("RootVBox") as VBoxContainer
	var back = root.get_node("Header/HBox/BackButton") as Button
	var title_lbl = root.get_node("Header/HBox/TitleLabel") as Label
	var card = root.get_node("ContentMargin/ContentVBox/BalanceCard") as Panel
	var card_vbox = card.get_node("VBox") as VBoxContainer
	var bank_icon = card_vbox.get_node("BankIcon") as Label
	var cc1 = card_vbox.get_node("CC1") as Label
	bank_money_label = card_vbox.get_node("MoneyLabel") as Label
	bank_emeralds_label = card_vbox.get_node("EmeraldsLabel") as Label
	var amount_le = root.get_node("ContentMargin/ContentVBox/AmountLineEdit") as LineEdit
	var send_btn = root.get_node("ContentMargin/ContentVBox/SendMoneyBtn") as Button

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.96, 0.97, 0.99, 1.0)
	bg_style.corner_radius_top_left = 20
	bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20
	bg_style.corner_radius_bottom_right = 20
	bg_panel.add_theme_stylebox_override("panel", bg_style)

	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", C_ACCENT2)
	for conn in back.pressed.get_connections():
		back.pressed.disconnect(conn["callable"])
	back.pressed.connect(func(): _switch_app("home"))
	
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))

	var cov_st = StyleBoxFlat.new()
	cov_st.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	cov_st.corner_radius_top_left=28;cov_st.corner_radius_top_right=28
	cov_st.corner_radius_bottom_left=28;cov_st.corner_radius_bottom_right=28
	cov_st.border_width_left=1;cov_st.border_width_top=1
	cov_st.border_width_right=1;cov_st.border_width_bottom=1
	cov_st.border_color=Color(0.88, 0.90, 0.94)
	cov_st.shadow_color=Color(0.08, 0.10, 0.18, 0.08)
	cov_st.shadow_size=16
	cov_st.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", cov_st)

	bank_icon.add_theme_font_size_override("font_size", 64)
	cc1.add_theme_font_size_override("font_size", 28)
	cc1.add_theme_color_override("font_color", Color(0.48, 0.50, 0.58))
	bank_money_label.add_theme_font_size_override("font_size", 56)
	bank_money_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	bank_emeralds_label.add_theme_font_size_override("font_size", 32)
	bank_emeralds_label.add_theme_color_override("font_color", C_GREEN)

	amount_le.add_theme_font_size_override("font_size", 28)
	amount_le.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	amount_le.add_theme_color_override("placeholder_color", Color(0.48, 0.50, 0.58, 0.70))
	var le_st = StyleBoxFlat.new()
	le_st.bg_color = Color.WHITE
	le_st.corner_radius_top_left = 14; le_st.corner_radius_top_right = 14
	le_st.corner_radius_bottom_left = 14; le_st.corner_radius_bottom_right = 14
	le_st.border_width_left = 1; le_st.border_width_top = 1
	le_st.border_width_right = 1; le_st.border_width_bottom = 1
	le_st.border_color = Color(0.85, 0.88, 0.92)
	le_st.content_margin_left = 12; le_st.content_margin_right = 12
	amount_le.add_theme_stylebox_override("normal", le_st)
	amount_le.add_theme_stylebox_override("focus", le_st)

	send_btn.add_theme_font_size_override("font_size", 28)
	send_btn.add_theme_color_override("font_color", Color.WHITE)
	var btn_st = StyleBoxFlat.new()
	btn_st.bg_color = C_ACCENT2
	btn_st.corner_radius_top_left = 28; btn_st.corner_radius_top_right = 28
	btn_st.corner_radius_bottom_left = 28; btn_st.corner_radius_bottom_right = 28
	btn_st.shadow_color = Color(0.55, 0.25, 1.00, 0.2)
	btn_st.shadow_size = 10
	btn_st.shadow_offset = Vector2(0, 4)
	var btn_st_h = btn_st.duplicate() as StyleBoxFlat
	btn_st_h.bg_color = C_ACCENT2 * 1.1
	send_btn.add_theme_stylebox_override("normal", btn_st)
	send_btn.add_theme_stylebox_override("hover", btn_st_h)
	send_btn.add_theme_stylebox_override("pressed", btn_st)
	send_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	for conn in send_btn.pressed.get_connections():
		send_btn.pressed.disconnect(conn["callable"])
	send_btn.pressed.connect(func():
		var amount_text = amount_le.text.strip_edges()
		if amount_text.is_empty() or not amount_text.is_valid_int():
			return
		var amt = int(amount_text)
		if amt > 0 and DatosUsuario:
			if DatosUsuario.dinero >= amt:
				DatosUsuario.dinero -= amt
				_update_bank_display()
				amount_le.text = ""
				if DatosUsuario.has_method("guardar_progreso"):
					DatosUsuario.guardar_progreso()
	)

	_update_bank_display()

func _update_bank_display() -> void:
	if DatosUsuario:
		if bank_money_label:
			bank_money_label.text = _formatear_pesos_colombianos(DatosUsuario.dinero)
		if bank_emeralds_label:
			bank_emeralds_label.text = "💎 " + str(DatosUsuario.esmeraldas) + " Esmeraldas"

func _formatear_pesos_colombianos(valor: float) -> String:
	var entero = int(round(valor))
	var texto = str(entero)
	var longitud = texto.length()
	var formateado = ""
	
	for i in range(longitud):
		var pos_desde_derecha = longitud - 1 - i
		formateado = texto[pos_desde_derecha] + formateado
		if i < longitud - 1 and (i + 1) % 3 == 0:
			formateado = "." + formateado
			
	return "$ " + formateado + " COP"

# ═════════════════════════════════════════════════════════════════════════════
#  APP: MUSICA
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_music(_parent: Control) -> void:
	var bg_panel = app_container_music.get_node("BGPanel") as Panel
	var root = app_container_music.get_node("RootVBox") as VBoxContainer
	var back = root.get_node("Header/HBox/BackButton") as Button
	var title_lbl = root.get_node("Header/HBox/TitleLabel") as Label
	var cover = root.get_node("ContentMargin/ContentVBox/CoverCard") as Panel
	var center_viz = cover.get_node("CenterViz") as CenterContainer
	var viz_hbox = center_viz.get_node("VizHBox") as HBoxContainer
	music_track_label = root.get_node("ContentMargin/ContentVBox/TrackLabel") as Label
	music_artist_label = root.get_node("ContentMargin/ContentVBox/ArtistLabel") as Label
	music_progress_bar = root.get_node("ContentMargin/ContentVBox/ProgressBar") as ProgressBar
	t_start = root.get_node("ContentMargin/ContentVBox/TimeHBox/StartLabel") as Label
	t_end = root.get_node("ContentMargin/ContentVBox/TimeHBox/EndLabel") as Label
	
	var prev_btn = root.get_node("ContentMargin/ContentVBox/ControlsCenter/ControlsHBox/PrevButton") as Button
	play_btn = root.get_node("ContentMargin/ContentVBox/ControlsCenter/ControlsHBox/PlayPauseButton") as Button
	var next_btn = root.get_node("ContentMargin/ContentVBox/ControlsCenter/ControlsHBox/NextButton") as Button
	
	var hp_card = root.get_node("ContentMargin/ContentVBox/HeadphonesCard") as PanelContainer
	var warning_lbl = hp_card.get_node("Margin/VBox/WarningLabel") as Label
	var test_btn = hp_card.get_node("Margin/VBox/TestBtn") as Button
	music_headphones_warning = warning_lbl
	music_headphones_btn = test_btn

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.96, 0.97, 0.99, 1.0)
	bg_style.corner_radius_top_left = 20
	bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20
	bg_style.corner_radius_bottom_right = 20
	bg_panel.add_theme_stylebox_override("panel", bg_style)

	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", C_ACCENT2)
	for conn in back.pressed.get_connections():
		back.pressed.disconnect(conn["callable"])
	back.pressed.connect(func(): _switch_app("home"))
	
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))

	var cov_st = StyleBoxFlat.new()
	cov_st.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	cov_st.corner_radius_top_left=22;cov_st.corner_radius_top_right=22
	cov_st.corner_radius_bottom_left=22;cov_st.corner_radius_bottom_right=22
	cov_st.border_width_left=1;cov_st.border_width_top=1
	cov_st.border_width_right=1;cov_st.border_width_bottom=1
	cov_st.border_color=Color(0.88, 0.90, 0.94)
	cov_st.shadow_color=Color(0.08, 0.10, 0.18, 0.06)
	cov_st.shadow_size=12
	cov_st.shadow_offset = Vector2(0, 6)
	cover.add_theme_stylebox_override("panel", cov_st)

	for child in viz_hbox.get_children():
		child.queue_free()
	visualizer_bars.clear()
	for i in range(12):
		var bar = Panel.new()
		bar.custom_minimum_size = Vector2(8, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var bar_style = StyleBoxFlat.new()
		var ratio = float(i) / 11.0
		bar_style.bg_color = C_ACCENT2.lerp(C_ACCENT, ratio)
		bar_style.corner_radius_top_left = 4
		bar_style.corner_radius_top_right = 4
		bar_style.corner_radius_bottom_left = 4
		bar_style.corner_radius_bottom_right = 4
		bar.add_theme_stylebox_override("panel", bar_style)
		
		viz_hbox.add_child(bar)
		visualizer_bars.append(bar)

	music_track_label.text = music_tracks[0]["title"]
	music_track_label.add_theme_font_size_override("font_size", 32)
	music_track_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	
	music_artist_label.text = music_tracks[0]["artist"]
	music_artist_label.add_theme_font_size_override("font_size", 24)
	music_artist_label.add_theme_color_override("font_color", Color(0.48, 0.50, 0.58))

	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.88, 0.90, 0.94)
	pb_bg.corner_radius_top_left = 4; pb_bg.corner_radius_top_right = 4
	pb_bg.corner_radius_bottom_left = 4; pb_bg.corner_radius_bottom_right = 4
	var pb_fg = StyleBoxFlat.new()
	pb_fg.bg_color = C_ACCENT2
	pb_fg.corner_radius_top_left = 4; pb_fg.corner_radius_top_right = 4
	pb_fg.corner_radius_bottom_left = 4; pb_fg.corner_radius_bottom_right = 4
	music_progress_bar.add_theme_stylebox_override("background", pb_bg)
	music_progress_bar.add_theme_stylebox_override("fill", pb_fg)

	t_start.add_theme_font_size_override("font_size", 20)
	t_start.add_theme_color_override("font_color", Color(0.48, 0.50, 0.58))
	t_end.add_theme_font_size_override("font_size", 20)
	t_end.add_theme_color_override("font_color", Color(0.48, 0.50, 0.58))

	_configure_music_btn_png(prev_btn, "res://recursos/botones/play.png", func():
		var prev_idx = current_track_idx - 1
		if prev_idx < 0:
			prev_idx = music_tracks.size() - 1
		_load_track(prev_idx)
	, true)
	
	var st_prev = StyleBoxFlat.new()
	st_prev.bg_color = Color.WHITE
	st_prev.corner_radius_top_left=30;st_prev.corner_radius_top_right=30
	st_prev.corner_radius_bottom_left=30;st_prev.corner_radius_bottom_right=30
	st_prev.border_width_left=1;st_prev.border_width_top=1
	st_prev.border_width_right=1;st_prev.border_width_bottom=1
	st_prev.border_color = Color(0.88, 0.90, 0.94)
	st_prev.shadow_color = Color(0, 0, 0, 0.04)
	st_prev.shadow_size = 6
	prev_btn.add_theme_stylebox_override("normal", st_prev)
	prev_btn.add_theme_stylebox_override("hover", st_prev)
	prev_btn.add_theme_stylebox_override("pressed", st_prev)

	for conn in play_btn.pressed.get_connections():
		play_btn.pressed.disconnect(conn["callable"])
	play_btn.pressed.connect(_toggle_music_playback)
	
	var st_play = StyleBoxFlat.new()
	st_play.bg_color = Color.WHITE
	st_play.corner_radius_top_left=42;st_play.corner_radius_top_right=42
	st_play.corner_radius_bottom_left=42;st_play.corner_radius_bottom_right=42
	st_play.border_width_left=1;st_play.border_width_top=1
	st_play.border_width_right=1;st_play.border_width_bottom=1
	st_play.border_color = Color(0.88, 0.90, 0.94)
	st_play.shadow_color = Color(0, 0, 0, 0.08)
	st_play.shadow_size = 10
	st_play.shadow_offset = Vector2(0, 4)
	play_btn.add_theme_stylebox_override("normal",  st_play)
	play_btn.add_theme_stylebox_override("hover",   st_play)
	play_btn.add_theme_stylebox_override("pressed", st_play)
	play_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	
	play_btn_texture = play_btn.get_node_or_null("PlayTexture") as TextureRect
	if not play_btn_texture:
		play_btn_texture = TextureRect.new()
		play_btn_texture.name = "PlayTexture"
		play_btn.add_child(play_btn_texture)
	play_btn_texture.texture = load("res://recursos/botones/play.png") as Texture2D
	play_btn_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	play_btn_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	play_btn_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_btn_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_btn_texture.offset_left = 16
	play_btn_texture.offset_right = -16
	play_btn_texture.offset_top = 16
	play_btn_texture.offset_bottom = -16

	play_btn.pivot_offset = play_btn.custom_minimum_size / 2
	for conn in play_btn.mouse_entered.get_connections():
		play_btn.mouse_entered.disconnect(conn["callable"])
	play_btn.mouse_entered.connect(func():
		var tw = play_btn.create_tween().set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2(1.12, 1.12), 0.1)
		tw.tween_property(play_btn, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
	)
	for conn in play_btn.mouse_exited.get_connections():
		play_btn.mouse_exited.disconnect(conn["callable"])
	play_btn.mouse_exited.connect(func():
		var tw = play_btn.create_tween().set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.1)
		tw.tween_property(play_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	)

	_configure_music_btn_png(next_btn, "res://recursos/botones/play.png", func():
		var next_idx = (current_track_idx + 1) % music_tracks.size()
		_load_track(next_idx)
	, false)
	var st_next = st_prev.duplicate() as StyleBoxFlat
	next_btn.add_theme_stylebox_override("normal", st_next)
	next_btn.add_theme_stylebox_override("hover", st_next)
	next_btn.add_theme_stylebox_override("pressed", st_next)

	var hp_st = StyleBoxFlat.new()
	hp_st.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	hp_st.corner_radius_top_left = 22
	hp_st.corner_radius_top_right = 22
	hp_st.corner_radius_bottom_left = 22
	hp_st.corner_radius_bottom_right = 22
	hp_st.border_width_left = 1; hp_st.border_width_top = 1
	hp_st.border_width_right = 1; hp_st.border_width_bottom = 1
	hp_st.border_color = Color(0.88, 0.90, 0.94)
	hp_st.shadow_color = Color(0.08, 0.10, 0.18, 0.04)
	hp_st.shadow_size = 8
	hp_st.shadow_offset = Vector2(0, 4)
	hp_card.add_theme_stylebox_override("panel", hp_st)

	warning_lbl.add_theme_font_size_override("font_size", 20)

	test_btn.add_theme_font_size_override("font_size", 20)
	var test_btn_st = StyleBoxFlat.new()
	test_btn_st.bg_color = C_ACCENT2
	test_btn_st.corner_radius_top_left = 16
	test_btn_st.corner_radius_top_right = 16
	test_btn_st.corner_radius_bottom_left = 16
	test_btn_st.corner_radius_bottom_right = 16
	test_btn_st.shadow_color = Color(0.55, 0.25, 1.00, 0.15)
	test_btn_st.shadow_size = 6
	test_btn_st.shadow_offset = Vector2(0, 2)
	var test_btn_st_h = test_btn_st.duplicate() as StyleBoxFlat
	test_btn_st_h.bg_color = C_ACCENT2 * 1.1
	test_btn.add_theme_stylebox_override("normal", test_btn_st)
	test_btn.add_theme_stylebox_override("hover", test_btn_st_h)
	test_btn.add_theme_stylebox_override("pressed", test_btn_st)
	test_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	test_btn.add_theme_color_override("font_color", Color.WHITE)
	
	for conn in test_btn.pressed.get_connections():
		test_btn.pressed.disconnect(conn["callable"])
	test_btn.pressed.connect(func():
		tiene_audifonos = !tiene_audifonos
		if DatosUsuario:
			if "tiene_audifonos" in DatosUsuario:
				DatosUsuario.tiene_audifonos = tiene_audifonos
			else:
				DatosUsuario.set("tiene_audifonos", tiene_audifonos)
		_update_music_display()
	)

	_update_music_display()
	
	if _font:
		_apply_font_recursive(app_container_music)
	
	music_track_label.add_theme_font_size_override("font_size", 42)
	music_artist_label.add_theme_font_size_override("font_size", 28)
	t_start.add_theme_font_size_override("font_size", 22)
	t_end.add_theme_font_size_override("font_size", 22)

func _configure_music_btn_png(btn: Button, png_path: String, action: Callable, is_flipped: bool = false) -> void:
	btn.flat = true
	for child in btn.get_children():
		child.queue_free()
	
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(action)

	var rect = TextureRect.new()
	rect.texture = load(png_path) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.flip_h = is_flipped
	btn.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 12
	rect.offset_right = -12
	rect.offset_top = 12
	rect.offset_bottom = -12

	btn.pivot_offset = btn.custom_minimum_size / 2
	for conn in btn.mouse_entered.get_connections():
		btn.mouse_entered.disconnect(conn["callable"])
	btn.mouse_entered.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.1)
		tw.tween_property(btn, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
	)
	for conn in btn.mouse_exited.get_connections():
		btn.mouse_exited.disconnect(conn["callable"])
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	)

func _toggle_music_playback() -> void:
	if not music_player:
		return
	is_playing_music = !is_playing_music
	if is_playing_music:
		if not music_player.playing:
			if not music_player.stream:
				_load_track(current_track_idx)
			else:
				music_player.play()
		else:
			music_player.stream_paused = false
		if play_btn_texture:
			play_btn_texture.texture = load("res://recursos/iconos app/pausa.png") as Texture2D
	else:
		if music_player.playing:
			music_player.stream_paused = true
		if play_btn_texture:
			play_btn_texture.texture = load("res://recursos/botones/play.png") as Texture2D

func _load_track(idx: int) -> void:
	if not music_player:
		return
	current_track_idx = idx
	var track = music_tracks[current_track_idx]
	if track.has("file"):
		var stream = load(track["file"])
		music_player.stream = stream
		if is_playing_music:
			music_player.play()
			music_player.stream_paused = false
			if play_btn_texture:
				play_btn_texture.texture = load("res://recursos/iconos app/pausa.png") as Texture2D
		else:
			music_player.stop()
			if play_btn_texture:
				play_btn_texture.texture = load("res://recursos/botones/play.png") as Texture2D
	_update_music_display()

func _update_music_display() -> void:
	if music_track_label:
		music_track_label.text  = music_tracks[current_track_idx]["title"]
	if music_artist_label:
		music_artist_label.text = music_tracks[current_track_idx]["artist"]
	if music_player and music_player.stream:
		var length = music_player.stream.get_length()
		if music_progress_bar:
			music_progress_bar.max_value = length
		if t_end:
			t_end.text = _format_time(length)
	else:
		if music_progress_bar:
			music_progress_bar.max_value = 100
		if t_end:
			t_end.text = "0:00"
			
	if music_headphones_warning:
		music_headphones_warning.add_theme_font_size_override("font_size", 14)
		if _player_has_headphones():
			music_headphones_warning.text = "🎧 AUDIFONOS CONECTADOS\nAudio de alta fidelidad"
			music_headphones_warning.add_theme_color_override("font_color", Color(0.15, 0.65, 0.35))
		else:
			music_headphones_warning.text = "⚠ CONECTA AUDIFONOS\nPara escuchar con el celular cerrado"
			music_headphones_warning.add_theme_color_override("font_color", Color(0.85, 0.45, 0.15))

	if music_headphones_btn:
		music_headphones_btn.add_theme_font_size_override("font_size", 14)
		if _player_has_headphones():
			music_headphones_btn.text = "Desconectar Audifonos (Test)"
		else:
			music_headphones_btn.text = "Conectar Audifonos (Test)"

func _player_has_headphones() -> bool:
	if DatosUsuario and "tiene_audifonos" in DatosUsuario:
		return DatosUsuario.tiene_audifonos
	if player and "tiene_audifonos" in player:
		return player.tiene_audifonos
	return tiene_audifonos

func _format_time(secs: float) -> String:
	var m = int(secs / 60.0)
	var s = int(secs) % 60
	return "%d:%02d" % [m, s]

# ═════════════════════════════════════════════════════════════════════════════
#  APP: GARAGE / TALLER
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_garage(_parent: Control) -> void:
	for child in app_container_garage.get_children():
		child.queue_free()

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	app_container_garage.add_child(root)

	var hdr = _make_app_header("Garage 🔧", C_ORANGE, "⬅ Home", func(): _switch_app("home"))
	root.add_child(hdr)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top",   16)
	vbox.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)

	var services = [
		["🛞", "Taller de Rines",     "Cambio y personalizacion de rines",  C_ORANGE],
		["🔩", "Mecanico General",     "Motor, frenos y transmision",        C_ACCENT],
		["🎨", "Pintura Custom",       "Colores y viniles exclusivos",        C_ACCENT2],
		["💡", "Luces y Neon",         "Iluminacion interior y exterior",     C_YELLOW],
		["🏎️", "Rendimiento",          "Turbo, escape y suspension",          C_RED],
		["🧼", "Lavado Premium",       "Detailing completo del vehiculo",     C_GREEN],
	]

	for svc in services:
		var row = _make_garage_item(svc[0], svc[1], svc[2], svc[3])
		inner.add_child(row)

func _make_garage_item(icon: String, name_: String, desc: String, color: Color) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, 78)
	var st = StyleBoxFlat.new()
	st.bg_color = C_SURFACE2
	st.corner_radius_top_left=16;st.corner_radius_top_right=16
	st.corner_radius_bottom_left=16;st.corner_radius_bottom_right=16
	st.border_width_left=3;st.border_width_top=0
	st.border_width_right=0;st.border_width_bottom=0
	st.border_color = color
	st.shadow_color = C_SHADOW; st.shadow_size = 4
	card.add_theme_stylebox_override("panel", st)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var pad = MarginContainer.new()
	pad.add_theme_constant_override("margin_left",  14)
	pad.add_theme_constant_override("margin_right", 0)
	pad.add_theme_constant_override("margin_top",   10)
	pad.add_theme_constant_override("margin_bottom",10)
	hbox.add_child(pad)

	var icon_lbl = Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 34)
	pad.add_child(icon_lbl)

	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_lbl = Label.new()
	title_lbl.text = name_
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", C_TEXT)
	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	text_vbox.add_child(title_lbl)
	text_vbox.add_child(desc_lbl)
	hbox.add_child(text_vbox)

	var arrow = Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 32)
	arrow.add_theme_color_override("font_color", color)
	var arrow_m = MarginContainer.new()
	arrow_m.add_theme_constant_override("margin_right", 14)
	arrow_m.add_child(arrow)
	hbox.add_child(arrow_m)

	return card

# ═════════════════════════════════════════════════════════════════════════════
#  APP: AJUSTES
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_settings(_parent: Control) -> void:
	for child in app_container_settings.get_children():
		child.queue_free()

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	app_container_settings.add_child(root)

	var hdr = _make_app_header("Ajustes ⚙️", Color(0.35,0.37,0.48), "⬅ Home", func(): _switch_app("home"))
	root.add_child(hdr)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top",   16)
	margin.add_theme_constant_override("margin_bottom",16)
	vbox.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	margin.add_child(inner)

	var sens_section = _make_settings_section("Control de Camara")
	inner.add_child(sens_section)

	var sens_label = Label.new()
	sens_label.text = "Sensibilidad: Normal"
	sens_label.add_theme_font_size_override("font_size", 20)
	sens_label.add_theme_color_override("font_color", C_TEXT)
	sens_section.add_child(sens_label)

	var sens_slider = HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.008
	sens_slider.step = 0.0005
	sens_slider.custom_minimum_size = Vector2(0, 32)
	if player:
		sens_slider.value = player.sensibilidad_raton
	sens_slider.value_changed.connect(func(v):
		if player:
			player.sensibilidad_raton = v
		sens_label.text = "Sensibilidad: " + str(snapped(v, 0.0001))
	)
	sens_section.add_child(sens_slider)

	var view_section = _make_settings_section("Vista del Jugador")
	inner.add_child(view_section)

	var cam_btn = _make_settings_button("🎥  Alternar 1a / 3a Persona", func():
		if player and player.has_method("_set_primera_persona"):
			player.call("_set_primera_persona", not player.get("_primera_persona"))
	)
	view_section.add_child(cam_btn)

	var adv_section = _make_settings_section("Avanzado")
	inner.add_child(adv_section)

	var adv_btn = _make_settings_button("🛠️  Configuraciones Completas", func():
		var path = "res://escenas/configuraciones/configuraciones.tscn"
		if ResourceLoader.exists(path):
			var s = load(path)
			if s:
				get_tree().current_scene.add_child(s.instantiate())
				close_phone()
	)
	adv_section.add_child(adv_btn)

func _make_settings_section(title: String) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	var lbl = Label.new()
	lbl.text = title.to_upper()
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	vbox.add_child(lbl)
	return vbox

func _make_settings_button(text_: String, action: Callable) -> Button:
	var btn = Button.new()
	btn.text = text_
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.custom_minimum_size = Vector2(0, 56)
	var st = StyleBoxFlat.new()
	st.bg_color = C_SURFACE2
	st.corner_radius_top_left=14;st.corner_radius_top_right=14
	st.corner_radius_bottom_left=14;st.corner_radius_bottom_right=14
	st.content_margin_left=18;st.content_margin_top=12;st.content_margin_bottom=12
	st.border_width_bottom=2;st.border_color=C_BORDER
	var sh = st.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.22, 0.32, 0.95)
	btn.add_theme_stylebox_override("normal",  st)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", st)
	btn.pressed.connect(action)
	return btn

# ═════════════════════════════════════════════════════════════════════════════
#  UTILIDADES
# ═════════════════════════════════════════════════════════════════════════════
func _make_app_header(title: String, accent: Color, back_text: String, back_action: Callable) -> Control:
	var hdr = MarginContainer.new()
	hdr.custom_minimum_size = Vector2(0, 62)
	hdr.add_theme_constant_override("margin_left",  14)
	hdr.add_theme_constant_override("margin_right", 14)
	hdr.add_theme_constant_override("margin_top",   10)
	hdr.add_theme_constant_override("margin_bottom",6)

	var hdr_bg = StyleBoxFlat.new()
	hdr_bg.bg_color   = C_SURFACE
	hdr_bg.border_width_bottom = 1
	hdr_bg.border_color        = C_BORDER

	var hbox = HBoxContainer.new()
	hdr.add_child(hbox)

	var back = Button.new()
	back.text = back_text
	back.flat = true
	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", accent)
	back.pressed.connect(back_action)
	hbox.add_child(back)

	var fill = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(fill)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", C_TEXT)
	hbox.add_child(title_lbl)

	var fill2 = Control.new()
	fill2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(fill2)

	return hdr

# ═════════════════════════════════════════════════════════════════════════════
#  CONTROL DE APPS Y ANIMACION
# ═════════════════════════════════════════════════════════════════════════════
func _switch_app(app_name: String) -> void:
	if app_name == "_back" or app_name == "_close":
		return
	if app_name != "jobs" and is_horizontal:
		toggle_phone_orientation(false)
	current_app = app_name
	_update_app_visibility()
	_show_app_splash(app_name)

func _show_app_splash(app_name: String) -> void:
	if app_name == "home" or not screen_panel:
		return
		
	var logo_rect: TextureRect = null
	var logo_emoji: Label = null
	var app_title: Label = null
		
	if not splash_screen:
		splash_screen = Panel.new()
		splash_screen.name = "SplashScreen"
		screen_panel.add_child(splash_screen)
		splash_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		var sp_style = StyleBoxFlat.new()
		sp_style.bg_color = Color(0.98, 0.98, 0.99)
		sp_style.corner_radius_top_left = 20
		sp_style.corner_radius_top_right = 20
		sp_style.corner_radius_bottom_left = 20
		sp_style.corner_radius_bottom_right = 20
		splash_screen.add_theme_stylebox_override("panel", sp_style)
		
		var center = CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		splash_screen.add_child(center)
		
		var logo_box = VBoxContainer.new()
		logo_box.alignment = BoxContainer.ALIGNMENT_CENTER
		logo_box.add_theme_constant_override("separation", 18)
		center.add_child(logo_box)
		
		logo_rect = TextureRect.new()
		logo_rect.name = "LogoRect"
		logo_rect.custom_minimum_size = Vector2(120, 120)
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_box.add_child(logo_rect)
		
		logo_emoji = Label.new()
		logo_emoji.name = "LogoEmoji"
		logo_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		logo_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		logo_emoji.add_theme_font_size_override("font_size", 84)
		logo_box.add_child(logo_emoji)
		
		app_title = Label.new()
		app_title.name = "AppTitle"
		app_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		app_title.add_theme_font_size_override("font_size", 22)
		app_title.add_theme_color_override("font_color", Color(0.48, 0.50, 0.58))
		if _font:
			app_title.add_theme_font_override("font", _font)
		logo_box.add_child(app_title)

	screen_panel.move_child(splash_screen, screen_panel.get_child_count() - 1)
	splash_screen.visible = true
	splash_screen.modulate.a = 1.0

	logo_rect = splash_screen.find_child("LogoRect", true, false) as TextureRect
	logo_emoji = splash_screen.find_child("LogoEmoji", true, false) as Label
	app_title = splash_screen.find_child("AppTitle", true, false) as Label
	
	logo_rect.visible = false
	logo_emoji.visible = false
	
	var app_icon = ""
	var app_label = ""
	var emoji_color = Color.WHITE
	
	match app_name:
		"waze":
			app_icon = "res://recursos/iconos app/app_mapa.png"
			app_label = "WAZE GPS"
		"bank":
			app_icon = "res://recursos/iconos app/app_banco.png"
			app_label = "BANCO NT"
		"music":
			app_icon = "res://recursos/iconos app/app_musica.png"
			app_label = "NT MÚSICA"
		"garage":
			app_icon = "🔧"
			app_label = "GARAGE"
			emoji_color = C_ORANGE
		"jobs":
			app_icon = "🪪"
			app_label = "TRABAJOS Y LICENCIAS"
			emoji_color = Color(0.12, 0.64, 0.88)
		"settings":
			app_icon = "res://recursos/iconos app/app_ajustes.png"
			app_label = "AJUSTES"
			
	app_title.text = app_label
	
	if app_icon.begins_with("res://"):
		logo_rect.texture = load(app_icon) as Texture2D
		logo_rect.visible = true
	else:
		logo_emoji.text = app_icon
		logo_emoji.add_theme_color_override("font_color", emoji_color)
		logo_emoji.visible = true
		
	var tw = create_tween()
	tw.tween_interval(0.35) 
	tw.tween_property(splash_screen, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): splash_screen.visible = false)

func _update_app_visibility() -> void:
	if app_container_home:     app_container_home.visible     = (current_app == "home")
	if app_container_waze:     app_container_waze.visible     = (current_app == "waze")
	if app_container_settings: app_container_settings.visible = (current_app == "settings")
	if app_container_bank:     app_container_bank.visible     = (current_app == "bank")
	if app_container_music:    app_container_music.visible    = (current_app == "music")
	if app_container_garage:   app_container_garage.visible   = (current_app == "garage")
	if app_container_jobs:     app_container_jobs.visible     = (current_app == "jobs")

	_actualizar_material_carreteras(current_app == "waze")

	if current_app == "bank" and DatosUsuario:
		if bank_money_label:    bank_money_label.text    = _formatear_pesos_colombianos(DatosUsuario.dinero)
		if bank_emeralds_label: bank_emeralds_label.text = "💎 " + str(DatosUsuario.esmeraldas) + " Esmeraldas"

func toggle_phone() -> void:
	if is_open: close_phone()
	else:       open_phone()

func open_phone() -> void:
	is_open = true
	if is_instance_valid(phone_frame):
		phone_frame.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Mostrar cursor de mouse al abrir celular
	target_y_offset = get_viewport().get_visible_rect().size.y - 860 - 30
	_switch_app("home")
	if open_button:
		open_button.text = "✕"
		if open_button_icon:
			open_button_icon.visible = false

	var DU = get_node_or_null("/root/DatosUsuario")
	if DU and not DU.tutorial_celular_completado:
		await get_tree().process_frame
		await get_tree().process_frame
		_launch_tutorial_celular()

func _launch_tutorial_celular() -> void:
	if get_node_or_null("TutorialCelular"):
		return
	var tutorial_script = load("res://Scripts/TutorialCelular.gd")
	if not tutorial_script:
		push_warning("[CelularUI] No se encontro TutorialCelular.gd")
		return
	var tutorial = tutorial_script.new()
	tutorial.name = "TutorialCelular"
	add_child(tutorial)


func close_phone() -> void:
	is_open = false
	if is_horizontal:
		toggle_phone_orientation(false)
	target_y_offset = get_viewport().get_visible_rect().size.y + 200
	if open_button:
		open_button.text = ""
		if open_button_icon:
			open_button_icon.visible = true

# ═════════════════════════════════════════════════════════════════════════════
#  PROCESS  — animacion + reloj + camara GPS + reposicion HUD
# ═════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	# Ocultar la capa 2 de cualquier cámara activa que no sea la del minimapa
	var active_cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if active_cam and active_cam != minimap_camera:
		if active_cam.cull_mask & 2:
			active_cam.cull_mask = active_cam.cull_mask & ~2

	if not is_horizontal and not is_rotating:
		current_y_offset = lerp(current_y_offset, target_y_offset, delta * 14.0)
		phone_frame.position.y = current_y_offset

	var t = Time.get_time_dict_from_system()
	status_time_label.text = "%02d:%02d" % [t.hour, t.minute]

	if music_player:
		var playing_active = music_player.playing and not music_player.stream_paused
		if playing_active:
			var pos = music_player.get_playback_position()
			if music_progress_bar:
				music_progress_bar.value = pos
			if t_start:
				t_start.text = _format_time(pos)
		elif not music_player.playing and is_playing_music and not music_player.stream_paused:
			var next_idx = (current_track_idx + 1) % music_tracks.size()
			_load_track(next_idx)

		var target_vol = 0.0
		var target_pitch = 1.0
		if not is_open:
			if not _player_has_headphones():
				target_vol = -24.0 
				target_pitch = 0.82 
			else:
				target_vol = 0.0
				target_pitch = 1.0
		else:
			target_vol = 0.0
			target_pitch = 1.0
			
		music_player.volume_db = lerp(music_player.volume_db, target_vol, delta * 8.0)
		music_player.pitch_scale = lerp(music_player.pitch_scale, target_pitch, delta * 8.0)

		if visualizer_bars.size() > 0:
			for i in range(visualizer_bars.size()):
				var bar = visualizer_bars[i]
				var target_height = 12.0
				if playing_active:
					var time_scale = Time.get_ticks_msec() * 0.006
					target_height = 10.0 + sin(time_scale + i * 1.3) * 15.0 + randf_range(0.0, 15.0)
					target_height = clamp(target_height, 12.0, 50.0) 
				bar.custom_minimum_size = Vector2(8, lerp(bar.custom_minimum_size.y, target_height, delta * 12.0))

	# ─── LÓGICA DEL MAPA 3D ──────────────────────────────────────────────────
	if minimap_camera and player and follow_player_camera:
		var target_node = player
		if player.get("_conduciendo") == true and player.get("_vehiculo_actual") != null:
			target_node = player.get("_vehiculo_actual")
			
		var vel = target_node.velocity if "velocity" in target_node else (target_node.linear_velocity if "linear_velocity" in target_node else Vector3.ZERO)
		if vel.length_squared() > 1.0:
			var target_heading = atan2(vel.x, vel.z) + PI
			var diff = fmod(target_heading - _gps_heading + PI, TAU) - PI
			_gps_heading += diff * delta * 2.5 
		
		var offset_distance := 35.0
		var offset_height := 18.0   
		var offset_dir = Vector3(sin(_gps_heading), 0, cos(_gps_heading))
		
		var target_pos = target_node.global_position + (offset_dir * offset_distance) + Vector3(0, offset_height, 0)
		minimap_camera.global_position = minimap_camera.global_position.lerp(target_pos, delta * 12.0)

		var look_target = target_node.global_position - (offset_dir * 10.0)
		minimap_camera.look_at(look_target, Vector3.UP)

	# ─── AGREGADO MAGICO: CONVERTIR RUTA 3D A LINEA 2D SOBRE EL VIEWPORT ────
	_gps_update_timer += delta
	if current_app == "waze" and is_instance_valid(linea_gps_2d) and is_instance_valid(minimap_camera):
		if _gps_update_timer >= GPS_UPDATE_INTERVAL:
			_gps_update_timer = 0.0
			linea_gps_2d.clear_points()
			
			# Usar ruta dinámica (gps_line.last_path) si está activo, de lo contrario la estática
			var ruta_actual = ruta_activa_3d
			if is_instance_valid(gps_line) and gps_line.get("active") == true:
				var path_3d = gps_line.get("last_path")
				if path_3d and not path_3d.is_empty():
					ruta_actual = path_3d
					
			if not ruta_actual.is_empty():
				for i in range(ruta_actual.size()):
					var p3d = ruta_actual[i]
					# Solo dibuja el punto si no está "a espaldas" de la cámara
					if not minimap_camera.is_position_behind(p3d):
						# unproject_position nos da exactamente las coordenadas 2D correspondientes de la ventana!
						var p2d = minimap_camera.unproject_position(p3d)
						linea_gps_2d.add_point(p2d)
				
				# Mostrar marcador de destino final en la pantalla (clampeado a los bordes si está fuera de pantalla)
				if is_instance_valid(dest_marker_2d):
					var final_dest = ruta_actual[ruta_actual.size() - 1]
					var p2d = minimap_camera.unproject_position(final_dest)
					
					# Si está detrás de la cámara, invertimos la proyección proyectada para indicar dirección correcta
					if minimap_camera.is_position_behind(final_dest):
						var cam_forward = -minimap_camera.global_transform.basis.z
						var to_dest = (final_dest - minimap_camera.global_position).normalized()
						var reflected = cam_forward + to_dest * 10.0
						p2d = minimap_camera.unproject_position(minimap_camera.global_position + reflected)
					
					var margin = 18.0
					var screen_size = app_container_waze.size
					if screen_size.x <= 0 or screen_size.y <= 0:
						screen_size = Vector2(400, 700) # Fallback razonable
					
					var half_size = dest_marker_2d.custom_minimum_size / 2
					var clamped_x = clamp(p2d.x, margin + half_size.x, screen_size.x - margin - half_size.x)
					var clamped_y = clamp(p2d.y, margin + half_size.y, screen_size.y - margin - half_size.y)
					
					dest_marker_2d.position = Vector2(clamped_x, clamped_y) - half_size
					dest_marker_2d.visible = true
			else:
				if is_instance_valid(dest_marker_2d):
					dest_marker_2d.visible = false

		# Marcador 2D del jugador en el GPS
		if is_instance_valid(player_dot_2d) and player:
			var player_world_pos = player.global_position
			if player.get("_conduciendo") == true and is_instance_valid(player.get("_vehiculo_actual")):
				player_world_pos = player.get("_vehiculo_actual").global_position
			if not minimap_camera.is_position_behind(player_world_pos):
				var dot_2d = minimap_camera.unproject_position(player_world_pos)
				player_dot_2d.position = dot_2d - player_dot_2d.custom_minimum_size / 2
				player_dot_2d.visible = true
			else:
				player_dot_2d.visible = false
	else:
		_gps_update_timer = 0.0
		if is_instance_valid(player_dot_2d):
			player_dot_2d.visible = false
	# ────────────────────────────────────────────────────────────────────────

	if player and current_app == "waze" and app_container_waze:
		var coords_lbl = app_container_waze.get_node_or_null("CoordsLabel") as Label
		if coords_lbl:
			var lat = 5.317 + player.global_position.z * 0.000009
			var lon = -73.939 + player.global_position.x * 0.000009
			coords_lbl.text = "LAT %.4f\nLON %.4f" % [lat, lon]

	_reposicionar_boton_celular()

func _reposicionar_boton_celular() -> void:
	pass

func _configurar_carreteras_minimapa() -> void:
	var root_scene = get_tree().current_scene
	if not root_scene:
		return
	
	var mat_gris = StandardMaterial3D.new()
	mat_gris.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_gris.albedo_color = Color(0.24, 0.26, 0.30, 1.0) 

	# 1. Buscar nodos con nombre 'gps' (como el NavigationRegion3D) y procesar todas sus meshes hijas
	var nodos_gps: Array[Node] = []
	_buscar_nodos_por_nombre_flexible(root_scene, "gps", nodos_gps)
	
	var duplicados_count = 0
	for nodo_gps in nodos_gps:
		var meshes: Array[MeshInstance3D] = []
		_obtener_meshes_recursivo(nodo_gps, meshes)
		for mesh in meshes:
			_duplicar_carretera_para_minimapa(mesh, mat_gris)
			duplicados_count += 1
			
	# 2. Si no se encontró nada bajo el nodo GPS, buscamos nodos que contengan "carretera" en su nombre
	if duplicados_count == 0:
		var carreteras: Array[Node] = []
		_buscar_nodos_por_nombre_flexible(root_scene, "carretera", carreteras)
		for nodo_carretera in carreteras:
			_duplicar_carretera_para_minimapa(nodo_carretera, mat_gris)

func _buscar_nodos_por_nombre_flexible(node: Node, target_name: String, result: Array[Node]) -> void:
	var n_name := node.name.to_lower()
	if n_name == target_name or n_name.contains(target_name):
		result.append(node)
	for child in node.get_children():
		_buscar_nodos_por_nombre_flexible(child, target_name, result)

func _obtener_meshes_recursivo(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_obtener_meshes_recursivo(child, result)

func _duplicar_carretera_para_minimapa(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		# Evitar duplicar si ya tiene un duplicado para el minimapa
		var ya_duplicado = false
		for child in mi.get_children():
			if child is MeshInstance3D and child.layers == 2:
				ya_duplicado = true
				break
		if not ya_duplicado:
			mi.layers = 1
			var duplicado = mi.duplicate() as MeshInstance3D
			duplicado.layers = 2
			duplicado.material_override = mat
			mi.add_child(duplicado)
			duplicado.transform = Transform3D.IDENTITY
		return
		
	for child in node.get_children():
		if not child.name.ends_with("@") and not child.get_parent() is MeshInstance3D:
			_duplicar_carretera_para_minimapa(child, mat)

func _actualizar_material_carreteras(_activado: bool) -> void:
	pass

# ═════════════════════════════════════════════════════════════════════════════
#  APP: LICENCIAS & TRABAJOS
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_jobs(_parent: Control) -> void:
	if not app_container_jobs:
		return

	var bg_panel = app_container_jobs.get_node("BGPanel") as Panel
	var portrait_view = app_container_jobs.get_node("PortraitView") as VBoxContainer
	
	var back = portrait_view.get_node("Header/HBox/BackButton") as Button
	var title_lbl = portrait_view.get_node("Header/HBox/TitleLabel") as Label
	var card = portrait_view.get_node("ContentMargin/ContentVBox/BalanceCard") as Panel
	var card_vbox = card.get_node("VBox") as VBoxContainer
	var badge_icon = card_vbox.get_node("BadgeIcon") as Label
	var level_lbl = card_vbox.get_node("LevelLabel") as Label
	var status_lbl = card_vbox.get_node("StatusLabel") as Label
	var ver_btn = portrait_view.get_node("ContentMargin/ContentVBox/VerContenidoBtn") as Button
	
	var landscape_view = app_container_jobs.get_node("LandscapeView") as Panel
	var land_vbox = landscape_view.get_node("LandMargin/LandVBox") as VBoxContainer
	var land_title = land_vbox.get_node("TopHBox/TitleLabel") as Label
	var cerrar_btn = land_vbox.get_node("TopHBox/CerrarBtn") as Button
	var main_hbox = land_vbox.get_node("MainHBox") as HBoxContainer
	
	var col1 = main_hbox.get_node("Col1") as VBoxContainer
	var col1_title = col1.get_node("Col1Title") as Label
	
	var col2 = main_hbox.get_node("Col2") as VBoxContainer
	var col2_title = col2.get_node("Col2Title") as Label

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.96, 0.97, 0.99, 1.0)
	bg_style.corner_radius_top_left = 20
	bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20
	bg_style.corner_radius_bottom_right = 20
	bg_panel.add_theme_stylebox_override("panel", bg_style)

	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", Color(0.12, 0.64, 0.88))
	for conn in back.pressed.get_connections():
		back.pressed.disconnect(conn["callable"])
	back.pressed.connect(func(): _switch_app("home"))
	
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))

	var card_st = StyleBoxFlat.new()
	card_st.bg_color = Color.WHITE
	card_st.corner_radius_top_left = 20; card_st.corner_radius_top_right = 20
	card_st.corner_radius_bottom_left = 20; card_st.corner_radius_bottom_right = 20
	card_st.border_width_left = 1; card_st.border_width_top = 1
	card_st.border_width_right = 1; card_st.border_width_bottom = 1
	card_st.border_color = Color(0.88, 0.90, 0.94)
	card_st.shadow_color = Color(0.08, 0.10, 0.18, 0.04)
	card_st.shadow_size = 12
	card.add_theme_stylebox_override("panel", card_st)

	badge_icon.add_theme_font_size_override("font_size", 48)
	level_lbl.add_theme_font_size_override("font_size", 20)
	level_lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.add_theme_color_override("font_color", C_GREEN)

	var btn_st = StyleBoxFlat.new()
	btn_st.bg_color = Color(0.12, 0.64, 0.88)
	btn_st.corner_radius_top_left = 20; btn_st.corner_radius_top_right = 20
	btn_st.corner_radius_bottom_left = 20; btn_st.corner_radius_bottom_right = 20
	btn_st.shadow_color = Color(0.12, 0.64, 0.88, 0.15)
	btn_st.shadow_size = 10
	btn_st.shadow_offset = Vector2(0, 4)
	var btn_st_h = btn_st.duplicate() as StyleBoxFlat
	btn_st_h.bg_color = Color(0.12, 0.64, 0.88) * 1.1
	ver_btn.add_theme_stylebox_override("normal", btn_st)
	ver_btn.add_theme_stylebox_override("hover", btn_st_h)
	ver_btn.add_theme_stylebox_override("pressed", btn_st)
	ver_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	ver_btn.add_theme_color_override("font_color", Color.WHITE)
	ver_btn.add_theme_font_size_override("font_size", 22)
	for conn in ver_btn.pressed.get_connections():
		ver_btn.pressed.disconnect(conn["callable"])
	ver_btn.pressed.connect(func(): toggle_phone_orientation(true))

	var land_st = StyleBoxFlat.new()
	land_st.bg_color = Color(0.96, 0.97, 0.99, 1.0)
	land_st.corner_radius_top_left = 20; land_st.corner_radius_top_right = 20
	land_st.corner_radius_bottom_left = 20; land_st.corner_radius_bottom_right = 20
	landscape_view.add_theme_stylebox_override("panel", land_st)

	land_title.add_theme_font_size_override("font_size", 22)
	land_title.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))

	var cls_st = StyleBoxFlat.new()
	cls_st.bg_color = Color(0.95, 0.22, 0.22)
	cls_st.corner_radius_top_left = 12; cls_st.corner_radius_top_right = 12
	cls_st.corner_radius_bottom_left = 12; cls_st.corner_radius_bottom_right = 12
	cerrar_btn.add_theme_stylebox_override("normal", cls_st)
	cerrar_btn.add_theme_stylebox_override("hover", cls_st)
	cerrar_btn.add_theme_stylebox_override("pressed", cls_st)
	cerrar_btn.add_theme_color_override("font_color", Color.WHITE)
	cerrar_btn.add_theme_font_size_override("font_size", 16)
	for conn in cerrar_btn.pressed.get_connections():
		cerrar_btn.pressed.disconnect(conn["callable"])
	cerrar_btn.pressed.connect(func(): toggle_phone_orientation(false))

	col1_title.add_theme_font_size_override("font_size", 16)
	col1_title.add_theme_color_override("font_color", Color(0.12, 0.64, 0.88))

	var row_st = StyleBoxFlat.new()
	row_st.bg_color = Color.WHITE
	row_st.corner_radius_top_left = 10; row_st.corner_radius_top_right = 10
	row_st.corner_radius_bottom_left = 10; row_st.corner_radius_bottom_right = 10
	row_st.border_width_left = 1; row_st.border_width_top = 1
	row_st.border_width_right = 1; row_st.border_width_bottom = 1
	row_st.border_color = Color(0.88, 0.90, 0.94)

	var lic_code_st = StyleBoxFlat.new()
	lic_code_st.bg_color = Color(0.12, 0.64, 0.88)
	lic_code_st.corner_radius_top_left = 6; lic_code_st.corner_radius_top_right = 6
	lic_code_st.corner_radius_bottom_left = 6; lic_code_st.corner_radius_bottom_right = 6

	for row_name in ["LicRow1", "LicRow2", "LicRow3"]:
		var r = col1.get_node(row_name) as Panel
		r.add_theme_stylebox_override("panel", row_st)
		var r_code = r.get_node("HBox/Code") as Label
		r_code.add_theme_stylebox_override("normal", lic_code_st)
		r_code.add_theme_font_size_override("font_size", 16)
		r_code.add_theme_color_override("font_color", Color.WHITE)
		var r_name = r.get_node("HBox/Name") as Label
		r_name.add_theme_font_size_override("font_size", 15)
		r_name.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
		var r_status = r.get_node("HBox/Status") as Label
		r_status.add_theme_font_size_override("font_size", 14)
		r_status.add_theme_color_override("font_color", C_GREEN)

	col2_title.add_theme_font_size_override("font_size", 16)
	col2_title.add_theme_color_override("font_color", Color(0.12, 0.64, 0.88))

	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.88, 0.90, 0.94)
	pb_bg.corner_radius_top_left = 5; pb_bg.corner_radius_top_right = 5
	pb_bg.corner_radius_bottom_left = 5; pb_bg.corner_radius_bottom_right = 5
	var pb_fg = StyleBoxFlat.new()
	pb_fg.bg_color = Color(0.12, 0.64, 0.88)
	pb_fg.corner_radius_top_left = 5; pb_fg.corner_radius_top_right = 5
	pb_fg.corner_radius_bottom_left = 5; pb_fg.corner_radius_bottom_right = 5

	for job_name in ["Job1", "Job2", "Job3"]:
		var j = col2.get_node(job_name) as VBoxContainer
		var j_title = j.get_node("HBox/Title") as Label
		j_title.add_theme_font_size_override("font_size", 14)
		j_title.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
		var j_pct = j.get_node("HBox/Pct") as Label
		j_pct.add_theme_font_size_override("font_size", 14)
		j_pct.add_theme_color_override("font_color", Color(0.12, 0.64, 0.88))
		var j_pbar = j.get_node("PBar") as ProgressBar
		j_pbar.add_theme_stylebox_override("background", pb_bg)
		j_pbar.add_theme_stylebox_override("fill", pb_fg)

func toggle_phone_orientation(horizontal: bool) -> void:
	if is_rotating or is_horizontal == horizontal:
		return
	is_rotating = true
	is_horizontal = horizontal
	
	var port_view = app_container_jobs.get_node_or_null("PortraitView") as Control
	var land_view = app_container_jobs.get_node_or_null("LandscapeView") as Control
	
	if is_horizontal:
		original_phone_position = phone_frame.position
		original_phone_scale = phone_frame.scale
		
		phone_frame.pivot_offset = Vector2(520, 860) / 2
		
		var viewport_size = get_viewport().get_visible_rect().size
		var target_pos = viewport_size / 2
		
		var target_scale_factor = (viewport_size.y * 0.85) / 520.0
		target_scale_factor = clamp(target_scale_factor, 1.0, 1.6)
		var target_scale = Vector2(target_scale_factor, target_scale_factor)
		
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(phone_frame, "rotation", deg_to_rad(90.0), 0.5)
		tw.tween_property(phone_frame, "scale", target_scale, 0.5)
		
		var target_position = target_pos - (Vector2(520, 860) / 2)
		tw.tween_property(phone_frame, "position", target_position, 0.5)
		
		if land_view:
			land_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
			land_view.custom_minimum_size = Vector2(816, 504)
			land_view.size = Vector2(816, 504)
			land_view.pivot_offset = Vector2(816, 504) / 2
			land_view.position = Vector2(252 - 408, 408 - 252)
			land_view.rotation = deg_to_rad(-90.0)
		
		if port_view: port_view.visible = false
		if land_view: land_view.visible = true
		
		if open_button:
			open_button.visible = true
			
		tw.chain().tween_callback(func():
			is_rotating = false
		)
	else:
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(phone_frame, "rotation", 0.0, 0.5)
		tw.tween_property(phone_frame, "scale", Vector2.ONE, 0.5)
		
		var size_y = get_viewport().get_visible_rect().size.y
		var target_pos = Vector2(get_viewport().get_visible_rect().size.x - 520 - 25, size_y - 860 - 30)
		tw.tween_property(phone_frame, "position", target_pos, 0.5)
		
		if land_view:
			land_view.rotation = 0.0
			land_view.set_anchors_preset(Control.PRESET_FULL_RECT)
			land_view.position = Vector2.ZERO
			land_view.custom_minimum_size = Vector2.ZERO
		
		if port_view: port_view.visible = true
		if land_view: land_view.visible = false
		
		if open_button:
			open_button.visible = true
			
		tw.chain().tween_callback(func():
			is_rotating = false
			var size_y_now = get_viewport().get_visible_rect().size.y
			target_y_offset = size_y_now - 860 - 30
			current_y_offset = target_y_offset
		)
		