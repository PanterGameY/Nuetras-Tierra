@tool
extends CanvasLayer
class_name CelularUI

static var instance: CelularUI = null

# ══════════════════════════════════════════════════════════════════════════════
#  CelularUI.gd  |  Nuestra Tierra — Movil Premium UI v3.0
#  Diseno: iOS 17 / Material You  |  Glassmorphism dark
# ══════════════════════════════════════════════════════════════════════════════

# ─── Paleta de colores global (Estilo Glassmorphism UIVehiculo) ────────────────
const C_BG          := Color(0.06, 0.07, 0.08, 0.95)   # Dark slate glass de UIVehiculo
const C_SURFACE     := Color(0.08, 0.09, 0.11, 0.85)   # Panel vidrio oscuro
const C_SURFACE2    := Color(0.11, 0.12, 0.15, 0.90)   # Tarjetas secundarias
const C_BORDER      := Color(0.78, 0.81, 0.85, 0.20)   # Borde metalico/frosty sutil (1px)
const C_ACCENT      := Color(0.20, 0.60, 1.00, 1.00)   # Azul electrico neón
const C_ACCENT2     := Color(0.55, 0.25, 1.00, 1.00)   # Violeta
const C_GREEN       := Color(0.14, 0.85, 0.45, 1.00)   # Verde esmeralda estado
const C_YELLOW      := Color(1.00, 0.78, 0.10, 1.00)
const C_RED         := Color(0.95, 0.22, 0.22, 1.00)
const C_ORANGE      := Color(1.00, 0.50, 0.10, 1.00)
const C_AMBER       := Color(0.88, 0.68, 0.28, 0.92)   # Ámbar dorado UIVehiculo
const C_TEXT        := Color(0.95, 0.96, 0.98, 1.00)   # Blanco nítido de alto contraste
const C_TEXT_DIM    := Color(0.68, 0.72, 0.76, 0.90)   # Gris metálico legible
const C_SHADOW      := Color(0.00, 0.00, 0.00, 0.65)

# ─── Referencias ────────────────────────────────────────────────────────────
var player: CharacterBody3D = null
var gps_line = null  # GPSRutaLinea — sin tipo para evitar error si el script tiene problemas

# ─── Estado celular ──────────────────────────────────────────────────────────
var is_open: bool          = false
var _ready_msec: int       = 0
var current_app: String    = "home"
var target_y_offset: float = 1200.0
var current_y_offset: float= 1200.0
var phone_scale: float     = 1.0

# ─── Exported UI Settings (Editor & Runtime Configurable) ────────────────────

@export_group("Bateria y Carga 🔋")
@export var battery_discharge_speed: float = 1.0
@export var battery_charge_speed: float = 1.0

@export_group("Vista Previa en Editor 👁️")
@export var mostrar_en_editor: bool = true:
	set(val):
		mostrar_en_editor = val
		if Engine.is_editor_hint() and is_instance_valid(phone_frame):
			phone_frame.visible = val
			phone_frame.modulate.a = 1.0 if val else 0.0
			_actualizar_posicion_tableta()

@export_enum("home", "waze", "bank", "fletes", "music", "garage", "jobs", "missions", "soporte", "settings") var vista_previa_app: String = "home":
	set(val):
		vista_previa_app = val
		current_app = val
		if is_inside_tree():
			_switch_app(val)

@export_group("App Home (Pantalla Principal)")
@export var home_icon_size: float = 150.0:
	set(val):
		home_icon_size = val
		if is_inside_tree() and current_app == "home":
			_switch_app("home")

@export var home_grid_columns: int = 3:
	set(val):
		home_grid_columns = val
		if is_inside_tree() and current_app == "home":
			_switch_app("home")

@export var home_grid_h_separation: int = 16:
	set(val):
		home_grid_h_separation = val
		if is_inside_tree() and current_app == "home":
			_switch_app("home")

@export var home_grid_v_separation: int = 16:
	set(val):
		home_grid_v_separation = val
		if is_inside_tree() and current_app == "home":
			_switch_app("home")

@export_group("App Banco - Canje")
@export var bank_canje_button_height: float = 135.0:
	set(val):
		bank_canje_button_height = val
		if is_inside_tree() and bank_active_tab == "cambio":
			_switch_bank_tab("cambio")

@export var bank_canje_h_separation: int = 12:
	set(val):
		bank_canje_h_separation = val
		if is_inside_tree() and bank_active_tab == "cambio":
			_switch_bank_tab("cambio")

@export var bank_canje_v_separation: int = 12:
	set(val):
		bank_canje_v_separation = val
		if is_inside_tree() and bank_active_tab == "cambio":
			_switch_bank_tab("cambio")

@export_group("App Música")
@export var music_font_size: int = 20:
	set(val):
		music_font_size = val
		if is_inside_tree() and current_app == "music":
			_switch_app("music")

@export var music_song_item_height: float = 54.0:
	set(val):
		music_song_item_height = val
		if is_inside_tree() and current_app == "music":
			_switch_app("music")

@export_group("App Waze GPS")
@export var waze_search_bar_height: float = 48.0:
	set(val):
		waze_search_bar_height = val
		if is_inside_tree() and current_app == "waze":
			_switch_app("waze")

@export_group("App Garaje")
@export var garage_card_height: float = 120.0:
	set(val):
		garage_card_height = val
		if is_inside_tree() and current_app == "garage":
			_switch_app("garage")

@export_group("App Trabajos")
@export var jobs_card_height: float = 110.0:
	set(val):
		jobs_card_height = val
		if is_inside_tree() and current_app == "jobs":
			_switch_app("jobs")

# ─── Nodos principales ───────────────────────────────────────────────────────
var phone_frame: PanelContainer
var status_time_label: Label
var status_battery_label: Label
var status_signal_label: Label
var open_button: Button
var open_button_icon: TextureRect = null
var screen_panel: Panel

# ─── Estado de Senal Movil 3G/4G/5G ─────────────────────────────────────────
var signal_type: String = "5G"       # "5G", "4G", "3G", "E", "SIN SENAL"
var signal_bars: int = 4             # 1 a 4 barras
var _signal_timer: float = 0.0
var _signal_change_interval: float = 4.0

# ─── Contenedores de apps ────────────────────────────────────────────────────
var app_container_home: Control
var app_container_waze: Control
var app_container_settings: Control
var app_container_bank: Control
var app_container_music: Control
var app_container_garage: Control
var app_container_jobs: Control
var app_container_fletes: Control = null
var app_container_missions: Control = null
var app_container_support: Control = null
var _soporte_unread_count: int = 0
var _home_soporte_badge: Control = null
var _hud_open_button_badge: Control = null
var _hud_blink_tween: Tween = null

# ─── GPS & UI Waze ───────────────────────────────────────────────────────────
var minimap_viewport: SubViewport  = null
var minimap_camera: Camera3D       = null
var follow_player_camera: bool     = true
var recenter_button: Button        = null
var search_line_edit: LineEdit     = null
var search_dropdown_container: ScrollContainer = null
var search_dropdown_list: VBoxContainer        = null
var active_waze_category: String   = "TODOS"
var _gps_heading: float = 0.0

# NUEVO: Referencias para trazar la ruta sobre el minimapa 3D
var ruta_activa_3d: PackedVector3Array = PackedVector3Array()
var linea_gps_2d: Line2D = null
var dest_marker_2d: Panel = null
var player_dot_2d: Panel = null  # Marcador 2D de posicion del jugador en el GPS
var _red_vial_container: Control = null # Contenedor para dibujo de carriles Path3D de la ciudad
var _red_vial_lines: Dictionary = {} # lane_node -> Line2D
var _cached_waze_lanes: Array = []
var _waze_lane_scan_timer: float = 0.0

# Optimizaciones de CPU
var _gps_update_timer: float = 0.0
const GPS_UPDATE_INTERVAL: float = 0.08 # Actualizar línea 2D ~12 veces por segundo
var _last_minute: int = -1
var _last_battery_pct: int = -1
var _last_is_charging: bool = false
var _gps_dest_check_timer: float = 0.0
var _coords_label_cache: Label = null
var _last_vp_size: Vector2 = Vector2.ZERO
var _cam_cull_check_timer: float = 0.0

# ─── Labels de datos ─────────────────────────────────────────────────────────
var bank_money_label: Label
var bank_emeralds_label: Label
var bank_inv_label: Label
var bank_loan_label: Label
var bank_nav_hbox: HBoxContainer
var bank_active_tab: String = "cambio"
var music_track_label: Label
var music_artist_label: Label
var music_progress_bar: ProgressBar

# ─── Estado de Bateria y Carga ───────────────────────────────────────────────
var battery_level: float = 100.0
var is_charging: bool = false
var is_battery_dead: bool = false
var dead_battery_overlay: PanelContainer = null
var charging_banner: PanelContainer = null
var charger_hud_button: Button = null
var charger_cable_container: Control = null

# ─── Estado de Tarjetas VIP ───────────────────────────────────────────────────
var bank_equipped_card: String = "clasica" # "clasica", "reciclaje", "obsidian"
var bank_purchased_cards: Array = ["clasica"]

# ─── Helpers Banco ────────────────────────────────────────────────────────────
func _obtener_dinero_jugador() -> int:
	if is_instance_valid(player) and "dinero_conductor" in player:
		return int(player.dinero_conductor)
	return 0

func _modificar_dinero_jugador(monto: int) -> void:
	if is_instance_valid(player):
		if player.has_method("agregar_dinero_conductor"):
			player.agregar_dinero_conductor(monto)
		elif "dinero_conductor" in player:
			player.dinero_conductor += monto
	if is_inside_tree() and current_app == "bank":
		_switch_app("bank")

func _mostrar_notificacion_banco(msg: String) -> void:
	if is_inside_tree() and is_instance_valid(app_container_bank):
		_mostrar_toast_canje(app_container_bank, msg)

func _mostrar_toast_canje(parent: Control, msg: String) -> void:
	if not is_instance_valid(parent): return
	var toast = PanelContainer.new()
	toast.custom_minimum_size = Vector2(0, 60)
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.10, 0.18, 0.95)
	st.corner_radius_top_left = 14; st.corner_radius_top_right = 14
	st.corner_radius_bottom_left = 14; st.corner_radius_bottom_right = 14
	st.border_width_left = 2; st.border_width_top = 2; st.border_width_right = 2; st.border_width_bottom = 2
	st.border_color = Color(1.00, 0.45, 0.00, 0.90)
	toast.add_theme_stylebox_override("panel", st)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16); margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8); margin.add_theme_constant_override("margin_bottom", 8)
	toast.add_child(margin)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	if _font: lbl.add_theme_font_override("font", _font)
	margin.add_child(lbl)
	
	parent.add_child(toast)
	toast.scale = Vector2(0.8, 0.8)
	toast.pivot_offset = Vector2(300, 30)
	var tw = toast.create_tween().set_parallel(true)
	tw.tween_property(toast, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw_fade = toast.create_tween()
	tw_fade.tween_interval(2.5)
	tw_fade.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw_fade.tween_callback(func(): toast.queue_free())

# ─── Destinos GPS (Nuestra Tierra) ──────────────────────────────────────────
var destinations: Dictionary = {
	"📍 Casa / Residencia"        : Vector3(0.0,   1.5,   0.0),
	"⛽ Gasolinera Norte"          : Vector3(-80.0, 0.0,  45.0),
	"🛠️ Taller Mecanico"         : Vector3(-50.0, 0.0, -35.0),
	"🛞 Taller de Rines"           : Vector3(-25.0, 0.0, -10.0),
	"🏢 Concesionario Central"    : Vector3(35.0,  0.0, -40.0),
	"🏙️ Centro de la Ciudad"      : Vector3(0.0,   1.5, -60.0),
	"📦 Mensajeria y Carga"       : Vector3(45.0,  0.0,  20.0),
	"🏪 Mercado Principal"        : Vector3(12.0,  0.0,  80.0),
	"🏥 Hospital General"         : Vector3(-30.0, 0.0,  90.0),
	"🚓 Estacion de Policia"      : Vector3(30.0,  0.0, -90.0),
	"🏦 Banco Nuestra Tierra"     : Vector3(-15.0, 0.0, -70.0),
	"🏫 Academia de Conduccion"   : Vector3(60.0,  0.0, -15.0)
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
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("celular")
	layer = 90 # Layer 90 para estar visible por encima de HUD (80) y UIVehiculo (2)
	player = get_parent() as CharacterBody3D

	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	_font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	_cargar_playlist_guardada()

	if player:
		gps_line = player.get_node_or_null("GPSRutaLinea")
		if not gps_line:
			var gps_script = load("res://codigo/celular/GPSRutaLinea.gd")
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

	if Engine.is_editor_hint():
		phone_frame.visible = mostrar_en_editor
		phone_frame.scale = Vector2.ONE
		phone_frame.modulate.a = 1.0 if mostrar_en_editor else 0.0
		_actualizar_posicion_tableta()
		_switch_app(vista_previa_app)
	else:
		is_open = false
		_ready_msec = Time.get_ticks_msec()
		phone_frame.visible = false
		phone_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phone_frame.scale = Vector2(0.8, 0.8)
		phone_frame.modulate.a = 0.0
		if is_instance_valid(app_container_support):
			app_container_support.visible = false
			app_container_support.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(app_container_missions):
			app_container_missions.visible = false
			app_container_missions.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_actualizar_posicion_tableta()

	if not Engine.is_editor_hint():
		var vp = get_viewport()
		if vp and not vp.size_changed.is_connected(_on_viewport_size_changed):
			vp.size_changed.connect(_on_viewport_size_changed)

	_actualizar_ui_bateria(true)
	if not Engine.is_editor_hint():
		_load_bank_config()
		_verificar_mora_y_recordatorio_nequi(true)

func _on_viewport_size_changed() -> void:
	if is_open or Engine.is_editor_hint():
		_actualizar_posicion_tableta()

func _actualizar_ui_bateria(forzar: bool = false) -> void:
	if not is_instance_valid(status_battery_label):
		return
	var pct_int = int(battery_level)
	if not forzar and pct_int == _last_battery_pct and is_charging == _last_is_charging:
		return
	_last_battery_pct = pct_int
	_last_is_charging = is_charging

	if is_charging:
		status_battery_label.text = str(pct_int) + "% ⚡"
		status_battery_label.add_theme_color_override("font_color", C_YELLOW)
	else:
		status_battery_label.text = str(pct_int) + "% 🔋"
		if pct_int <= 20:
			status_battery_label.add_theme_color_override("font_color", C_RED)
		else:
			status_battery_label.add_theme_color_override("font_color", C_GREEN)

func _procesar_simulacion_senal(delta: float) -> void:
	_signal_timer += delta
	if _signal_timer < _signal_change_interval:
		return
		
	_signal_timer = 0.0
	_signal_change_interval = randf_range(3.5, 7.5)

	# Simulación de cobertura móvil realista (5G prevaleciente, 4G, 3G ocasional en zonas aisladas)
	var roll = randf()
	if roll < 0.55:
		signal_type = "5G"
		signal_bars = randi_range(3, 4)
	elif roll < 0.82:
		signal_type = "4G"
		signal_bars = randi_range(2, 4)
	elif roll < 0.94:
		signal_type = "3G"
		signal_bars = randi_range(1, 3)
	elif roll < 0.98:
		signal_type = "E"
		signal_bars = 1
	else:
		signal_type = "SIN SENAL"
		signal_bars = 0

	_actualizar_ui_senal()

func _actualizar_ui_senal() -> void:
	if not is_instance_valid(status_signal_label):
		return
		
	var bar_str = ""
	match signal_bars:
		4: bar_str = "▂▄▆█"
		3: bar_str = "▂▄▆_"
		2: bar_str = "▂▄__"
		1: bar_str = "▂___"
		_: bar_str = "____"
		
	if signal_type == "SIN SENAL":
		status_signal_label.text = "🚫 SIN RED  |  📟 TABLETA DIGITAL"
		status_signal_label.add_theme_color_override("font_color", C_RED)
	else:
		status_signal_label.text = "NT-" + signal_type + " " + bar_str + "  |  📟 TABLETA DIGITAL"
		if signal_type == "5G":
			status_signal_label.add_theme_color_override("font_color", Color(0.20, 0.65, 1.00)) # Azul neón 5G
		elif signal_type == "4G":
			status_signal_label.add_theme_color_override("font_color", Color(0.14, 0.85, 0.45)) # Verde neón 4G
		elif signal_type == "3G":
			status_signal_label.add_theme_color_override("font_color", Color(1.00, 0.78, 0.10)) # Amarillo 3G
		else:
			status_signal_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.10)) # Naranja E

func _mostrar_pantalla_bateria_agotada() -> void:
	is_battery_dead = true
	if not is_instance_valid(dead_battery_overlay):
		_crear_overlay_bateria_agotada()
	if is_instance_valid(dead_battery_overlay):
		dead_battery_overlay.visible = true
		dead_battery_overlay.modulate.a = 0.0
		dead_battery_overlay.scale = Vector2(0.8, 0.8)
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(dead_battery_overlay, "scale", Vector2(1.0, 1.0), 0.35)
		tw.tween_property(dead_battery_overlay, "modulate:a", 1.0, 0.35)

func _crear_overlay_bateria_agotada() -> void:
	if not is_instance_valid(screen_panel):
		return
	
	dead_battery_overlay = PanelContainer.new()
	dead_battery_overlay.name = "DeadBatteryOverlay"
	dead_battery_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dead_battery_overlay.pivot_offset = Vector2(500, 350)
	
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.06, 0.06, 0.08, 0.96) # Glassmorphic dark
	overlay_style.border_width_left = 3
	overlay_style.border_width_top = 3
	overlay_style.border_width_right = 3
	overlay_style.border_width_bottom = 3
	overlay_style.border_color = Color(1.00, 0.45, 0.00, 0.90) # Orange Neon
	overlay_style.corner_radius_top_left = 20
	overlay_style.corner_radius_top_right = 20
	overlay_style.corner_radius_bottom_left = 20
	overlay_style.corner_radius_bottom_right = 20
	overlay_style.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	overlay_style.shadow_size = 30
	dead_battery_overlay.add_theme_stylebox_override("panel", overlay_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	dead_battery_overlay.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)
	
	var icon_lbl = Label.new()
	icon_lbl.text = "🪫"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 96)
	vbox.add_child(icon_lbl)
	
	var title_lbl = Label.new()
	title_lbl.text = "BATERIA AGOTADA"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font: title_lbl.add_theme_font_override("font", _font)
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.22, 0.22, 1.0))
	vbox.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "El dispositivo se ha quedado sin bateria.\nConecta el cargador para reactivarlo."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font: desc_lbl.add_theme_font_override("font", _font)
	desc_lbl.add_theme_font_size_override("font_size", 28)
	desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.80, 1.0))
	vbox.add_child(desc_lbl)
	
	var charge_btn = Button.new()
	charge_btn.text = "⚡ CONECTAR CARGADOR"
	charge_btn.custom_minimum_size = Vector2(480, 80)
	charge_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	charge_btn.pivot_offset = Vector2(240, 40)
	if _font: charge_btn.add_theme_font_override("font", _font)
	charge_btn.add_theme_font_size_override("font_size", 32)
	charge_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.14, 0.85, 0.45, 0.90) # Green accent
	btn_normal.corner_radius_top_left = 12; btn_normal.corner_radius_top_right = 12
	btn_normal.corner_radius_bottom_left = 12; btn_normal.corner_radius_bottom_right = 12
	btn_normal.border_width_left = 2; btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2; btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.6)
	btn_normal.shadow_color = Color(0.14, 0.85, 0.45, 0.4)
	btn_normal.shadow_size = 15
	
	var btn_hover = btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.18, 0.95, 0.50, 1.0)
	btn_hover.shadow_size = 22
	
	var btn_pressed = btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.10, 0.65, 0.35, 1.0)
	
	charge_btn.add_theme_stylebox_override("normal", btn_normal)
	charge_btn.add_theme_stylebox_override("hover", btn_hover)
	charge_btn.add_theme_stylebox_override("pressed", btn_pressed)
	charge_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	charge_btn.pressed.connect(func(): _conectar_cargador())
	charge_btn.mouse_entered.connect(func():
		var tw = charge_btn.create_tween().set_parallel(true)
		tw.tween_property(charge_btn, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	charge_btn.mouse_exited.connect(func():
		var tw = charge_btn.create_tween().set_parallel(true)
		tw.tween_property(charge_btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	vbox.add_child(charge_btn)
	
	screen_panel.add_child(dead_battery_overlay)

func _conectar_cargador() -> void:
	if is_charging:
		return
	is_charging = true
	_actualizar_estilo_charger_hud_button()

	# 1. Simulación visual del cable de carga entrando desde el borde derecho de la pantalla
	_animar_cable_cargador_derecha()

	# 2. Desbloquear la pantalla inmediatamente para seguir usando la tableta
	is_battery_dead = false
	if is_instance_valid(dead_battery_overlay):
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(dead_battery_overlay, "scale", Vector2(0.8, 0.8), 0.25)
		tw.tween_property(dead_battery_overlay, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(func():
			if is_instance_valid(dead_battery_overlay):
				dead_battery_overlay.visible = false
		)

	# 3. Mostrar banner flotante de "CARGANDO..." en la parte superior
	_mostrar_banner_cargando()
	notificar("⚡ Cargador conectado. Puedes seguir usando el dispositivo.", "exito")

func _animar_cable_cargador_derecha() -> void:
	if not is_instance_valid(phone_frame):
		return

	if is_instance_valid(charger_cable_container):
		charger_cable_container.queue_free()

	charger_cable_container = Control.new()
	charger_cable_container.name = "ChargerCableContainer"
	charger_cable_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charger_cable_container.z_index = -1 # Se renderiza POR DETRAS del marco del celular

	# Agregar como hermano inmediatamente antes de phone_frame o al root CelularUI con z_index=-1
	add_child(charger_cable_container)
	move_child(charger_cable_container, max(0, phone_frame.get_index()))

	var vp_size = get_viewport().get_visible_rect().size
	var right_screen_x = vp_size.x
	# Se adentra varios píxeles por DETRÁS del teléfono para simular que está enchufado en el marco trasero
	var target_phone_right_x = phone_frame.position.x + phone_frame.size.x - 35.0
	var cable_y = phone_frame.position.y + (phone_frame.size.y * 0.60)

	# Cable mucho más grueso y vistoso (width 28px)
	var cable_line = Line2D.new()
	cable_line.width = 28.0
	cable_line.default_color = Color(0.18, 0.20, 0.26, 0.98) # Negro/Gris carbón mate
	cable_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	cable_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Puntos del cable trazando curva prominente desde el borde derecho hasta detrás del teléfono
	var p0 = Vector2(right_screen_x + 180.0, cable_y + 120.0)
	var p1 = Vector2(right_screen_x - 40.0, cable_y + 90.0)
	var p2 = Vector2(target_phone_right_x + 120.0, cable_y + 20.0)
	var p3 = Vector2(target_phone_right_x, cable_y)

	cable_line.add_point(p0)
	cable_line.add_point(p1)
	cable_line.add_point(p2)
	cable_line.add_point(p3)
	charger_cable_container.add_child(cable_line)

	# Cable interior neón incandescente
	var cable_glow = Line2D.new()
	cable_glow.width = 10.0
	cable_glow.default_color = Color(1.00, 0.78, 0.10, 0.85) # Rayo Neón dorado central
	cable_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	cable_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	cable_glow.add_point(p0)
	cable_glow.add_point(p1)
	cable_glow.add_point(p2)
	cable_glow.add_point(p3)
	charger_cable_container.add_child(cable_glow)

	# Conector del cargador (Plug USB-C grande y robusto detrás de la pantalla)
	var plug = Panel.new()
	plug.custom_minimum_size = Vector2(90, 48)
	plug.size = Vector2(90, 48)
	plug.pivot_offset = Vector2(45, 24)

	var plug_st = StyleBoxFlat.new()
	plug_st.bg_color = Color(0.12, 0.14, 0.20, 1.0)
	plug_st.border_width_left = 3; plug_st.border_width_top = 3
	plug_st.border_width_right = 3; plug_st.border_width_bottom = 3
	plug_st.border_color = Color(1.00, 0.78, 0.10, 1.0) # Borde Neón dorado
	plug_st.corner_radius_top_left = 12; plug_st.corner_radius_bottom_left = 12
	plug_st.shadow_color = Color(1.00, 0.78, 0.10, 0.9)
	plug_st.shadow_size = 20
	plug.add_theme_stylebox_override("panel", plug_st)

	var icon_lbl = Label.new()
	icon_lbl.text = "⚡ ENCHUFADO"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font: icon_lbl.add_theme_font_override("font", _font)
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.add_theme_color_override("font_color", Color(1.00, 0.85, 0.20))
	icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plug.add_child(icon_lbl)

	charger_cable_container.add_child(plug)

	# Posicionar conector entrando justo por detrás del borde del celular
	plug.position = p3 - Vector2(45, 24)

	# Animar la entrada fluida del cable desde la derecha deslizándose por detrás
	charger_cable_container.modulate.a = 0.0
	charger_cable_container.position.x = 200.0

	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(charger_cable_container, "position:x", 0.0, 0.45)
	tw.tween_property(charger_cable_container, "modulate:a", 1.0, 0.35)

func _mostrar_banner_cargando() -> void:
	if not is_instance_valid(screen_panel):
		return
		
	if is_instance_valid(charging_banner):
		charging_banner.visible = true
		charging_banner.modulate.a = 1.0
		return
		
	charging_banner = PanelContainer.new()
	charging_banner.name = "ChargingBanner"
	charging_banner.custom_minimum_size = Vector2(0, 48)
	
	var b_st = StyleBoxFlat.new()
	b_st.bg_color = Color(0.08, 0.10, 0.16, 0.94)
	b_st.border_width_bottom = 2
	b_st.border_color = Color(1.00, 0.78, 0.10, 0.90) # Amarillo neón
	b_st.corner_radius_top_left = 16
	b_st.corner_radius_top_right = 16
	charging_banner.add_theme_stylebox_override("panel", b_st)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	charging_banner.add_child(hbox)
	
	var lbl = Label.new()
	lbl.text = "⚡ CARGANDO DISPOSITIVO..."
	if _font: lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.00, 0.85, 0.20))
	hbox.add_child(lbl)
	
	screen_panel.add_child(charging_banner)
	charging_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	charging_banner.position.y = 0
	
	charging_banner.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(charging_banner, "modulate:a", 1.0, 0.3)

func _restaurar_pantalla_bateria() -> void:
	is_battery_dead = false
	_actualizar_estilo_charger_hud_button()
	if is_instance_valid(dead_battery_overlay):
		dead_battery_overlay.visible = false
		
	if is_instance_valid(charging_banner):
		var tw = create_tween()
		tw.tween_property(charging_banner, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			if is_instance_valid(charging_banner):
				charging_banner.visible = false
		)

	if is_instance_valid(charger_cable_container):
		var tw_cable = create_tween()
		tw_cable.tween_property(charger_cable_container, "modulate:a", 0.0, 0.4)
		tw_cable.tween_callback(func():
			if is_instance_valid(charger_cable_container):
				charger_cable_container.queue_free()
		)
		
	notificar("🔋 Bateria completada al 100%", "exito")

func _apply_font_recursive(node: Node, skip_scale: bool = false) -> void:
	if not _font or not node:
		return
	for child in node.get_children():
		if child is Label:
			var lbl := child as Label
			lbl.add_theme_font_override("font", _font)
		elif child is Button:
			var btn := child as Button
			btn.add_theme_font_override("font", _font)
		elif child is LineEdit:
			var le := child as LineEdit
			le.add_theme_font_override("font", _font)
		if child.get_child_count() > 0:
			_apply_font_recursive(child, skip_scale)

# ═════════════════════════════════════════════════════════════════════════════
#  CONSTRUCCION PRINCIPAL
# ═════════════════════════════════════════════════════════════════════════════
func _setup_ui() -> void:
	phone_frame = get_node_or_null("PhoneFrame") as PanelContainer
	if not phone_frame:
		return
	screen_panel = get_node_or_null("PhoneFrame/RootVBox/ScreenWrap/ScreenPanel") as Panel
	if not screen_panel:
		return
	var screen_content = get_node_or_null("PhoneFrame/RootVBox/ScreenWrap/ScreenPanel/ScreenContent") as Control
	if not screen_content:
		return

	status_time_label = get_node_or_null("PhoneFrame/RootVBox/StatusBar/HBox/TimeLabel") as Label
	status_battery_label = get_node_or_null("PhoneFrame/RootVBox/StatusBar/HBox/BatteryLabel") as Label
	status_signal_label = get_node_or_null("PhoneFrame/RootVBox/StatusBar/HBox/SignalLabel") as Label

	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color            = Color(0.06, 0.07, 0.08, 0.95)
	frame_style.border_width_left   = 1
	frame_style.border_width_top    = 1
	frame_style.border_width_right  = 1
	frame_style.border_width_bottom = 1
	frame_style.border_color        = Color(0.82, 0.85, 0.90, 0.28)
	frame_style.corner_radius_top_left    = 14
	frame_style.corner_radius_top_right   = 14
	frame_style.corner_radius_bottom_left = 14
	frame_style.corner_radius_bottom_right= 14
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	frame_style.shadow_size  = 24
	frame_style.shadow_offset= Vector2(0, 6)
	frame_style.content_margin_left   = 10
	frame_style.content_margin_top    = 8
	frame_style.content_margin_right  = 10
	frame_style.content_margin_bottom = 8
	phone_frame.add_theme_stylebox_override("panel", frame_style)

	var notch_bar = get_node_or_null("PhoneFrame/RootVBox/NotchBar") as Control
	if notch_bar:
		notch_bar.visible = false

	var status_signal = get_node_or_null("PhoneFrame/RootVBox/StatusBar/HBox/SignalLabel") as Label
	if status_signal:
		status_signal.text = "NT-5G ▲  |  📟 TABLETA DIGITAL"
		status_signal.add_theme_color_override("font_color", Color(0.20, 0.60, 1.00))
	if status_time_label:
		status_time_label.add_theme_color_override("font_color", C_TEXT)
	if status_battery_label:
		status_battery_label.add_theme_color_override("font_color", C_GREEN)

	var sp_style = StyleBoxFlat.new()
	sp_style.bg_color              = Color(0.06, 0.07, 0.09, 0.98)
	sp_style.border_width_left     = 1
	sp_style.border_width_top      = 1
	sp_style.border_width_right    = 1
	sp_style.border_width_bottom   = 1
	sp_style.border_color          = Color(0.78, 0.81, 0.85, 0.15)
	sp_style.corner_radius_top_left    = 12
	sp_style.corner_radius_top_right   = 12
	sp_style.corner_radius_bottom_left = 12
	sp_style.corner_radius_bottom_right= 12
	screen_panel.add_theme_stylebox_override("panel", sp_style)

	app_container_home = screen_content.get_node_or_null("AppHome")
	app_container_waze = screen_content.get_node_or_null("AppWaze")
	app_container_settings = screen_content.get_node_or_null("AppSettings")
	app_container_bank = screen_content.get_node_or_null("AppBank")
	app_container_music = screen_content.get_node_or_null("AppMusic")
	app_container_garage = screen_content.get_node_or_null("AppGarage")
	app_container_jobs = screen_content.get_node_or_null("AppJobs")

	# Cargar e instanciar dinámicamente la app de Misiones en pantalla completa (directamente en el root de CelularUI)
	var misiones_scene = load("res://interfaz/celular/sistema/MisionesUI.tscn")
	if misiones_scene:
		app_container_missions = misiones_scene.instantiate()
		add_child(app_container_missions)
		app_container_missions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app_container_missions.visible = false
		app_container_missions.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if app_container_missions.has_signal("volver_pressed"):
			app_container_missions.connect("volver_pressed", func(): _switch_app("home"))

	# Cargar e instanciar dinámicamente la app de Soporte Técnico en tiempo real
	var soporte_scene = load("res://interfaz/soporte/SoporteUI.tscn")
	if soporte_scene:
		app_container_support = soporte_scene.instantiate()
		app_container_support.visible = false
		app_container_support.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(app_container_support)
		app_container_support.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if app_container_support.has_signal("volver_pressed"):
			app_container_support.connect("volver_pressed", func(): _switch_app("home"))
		if app_container_support.has_signal("mensaje_soporte_recibido"):
			app_container_support.connect("mensaje_soporte_recibido", _on_mensaje_soporte_recibido)

	app_container_fletes = screen_content.get_node_or_null("AppFletes") as Control
	if not app_container_fletes:
		app_container_fletes = Control.new()
		app_container_fletes.name = "AppFletes"
		app_container_fletes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app_container_fletes.visible = false
		screen_content.add_child(app_container_fletes)

	_setup_app_home(screen_content)
	_setup_app_waze(screen_content)
	_setup_app_settings(screen_content)
	_setup_app_bank(screen_content)
	_setup_app_fletes(screen_content)
	_setup_app_music(screen_content)
	_setup_app_garage(screen_content)
	_setup_app_jobs(screen_content)

	var nav = get_node_or_null("PhoneFrame/RootVBox/NavBar") as HBoxContainer
	if nav:
		_configure_nav_bar(nav)

	var swipe_bar = get_node_or_null("PhoneFrame/RootVBox/SwipeRow/SwipeBar") as Panel
	if swipe_bar:
		var sw_style = StyleBoxFlat.new()
		sw_style.bg_color              = Color(0.5, 0.5, 0.6, 0.5)
		sw_style.corner_radius_top_left    = 3
		sw_style.corner_radius_top_right   = 3
		sw_style.corner_radius_bottom_left = 3
		sw_style.corner_radius_bottom_right= 3
		swipe_bar.add_theme_stylebox_override("panel", sw_style)

	_setup_hud_button()

func _configure_nav_bar(bar: HBoxContainer) -> void:
	bar.custom_minimum_size = Vector2(0, 78)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 36)
	for child in bar.get_children():
		child.queue_free()

	var back_btn = _make_nav_btn("◀   REGRESAR", "_back", C_ACCENT)
	back_btn.pressed.connect(func(): _switch_app("home"))
	bar.add_child(back_btn)

	var home_btn = _make_nav_btn("⌂   INICIO", "home", C_ORANGE)
	bar.add_child(home_btn)

func _make_nav_btn(text_label: String, app: String, accent_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text_label
	btn.custom_minimum_size = Vector2(280, 58)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pivot_offset = Vector2(140, 29)
	
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.90, 0.92, 0.95, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", C_AMBER)
	
	var n_st = StyleBoxFlat.new()
	n_st.bg_color = Color(0.08, 0.09, 0.11, 0.85)
	n_st.border_width_left   = 1; n_st.border_width_top    = 1
	n_st.border_width_right  = 1; n_st.border_width_bottom = 1
	n_st.border_color        = Color(0.78, 0.81, 0.85, 0.22)
	n_st.corner_radius_top_left     = 8; n_st.corner_radius_top_right    = 8
	n_st.corner_radius_bottom_left  = 8; n_st.corner_radius_bottom_right = 8
	n_st.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	n_st.shadow_size  = 6
	n_st.shadow_offset = Vector2(0, 2)

	var h_st = n_st.duplicate() as StyleBoxFlat
	h_st.bg_color     = Color(0.14, 0.16, 0.19, 0.92)
	h_st.border_color = Color(0.85, 0.88, 0.92, 0.45)
	h_st.shadow_size  = 8

	var p_st = n_st.duplicate() as StyleBoxFlat
	p_st.bg_color            = Color(0.18, 0.20, 0.24, 0.95)
	p_st.border_width_bottom = 2
	p_st.border_color        = C_AMBER

	btn.add_theme_stylebox_override("normal", n_st)
	btn.add_theme_stylebox_override("hover", h_st)
	btn.add_theme_stylebox_override("pressed", p_st)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if app != "_back" and app != "_close":
		btn.pressed.connect(func(): _switch_app(app))

	btn.mouse_entered.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	return btn

func _setup_hud_button() -> void:
	open_button = get_node_or_null("OpenButton") as Button
	if not is_instance_valid(open_button):
		open_button = Button.new()
		open_button.name = "OpenButton"
		open_button.custom_minimum_size = Vector2(190, 64)
		open_button.anchors_preset = Control.PRESET_TOP_RIGHT
		open_button.anchor_left = 1.0
		open_button.anchor_right = 1.0
		open_button.offset_left = -215.0
		open_button.offset_top = 20.0
		open_button.offset_right = -25.0
		open_button.offset_bottom = 84.0
		open_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		add_child(open_button)

	open_button.custom_minimum_size = Vector2(190, 64)
	open_button.pivot_offset = Vector2(95, 32)
	open_button.visible = true
	open_button.z_index = 50
	
	if _font:
		open_button.add_theme_font_override("font", _font)
	open_button.add_theme_font_size_override("font_size", 16)
	open_button.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	open_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

	_actualizar_estilo_hud_boton(false)

	open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.focus_mode = Control.FOCUS_NONE
	
	for conn in open_button.pressed.get_connections():
		open_button.pressed.disconnect(conn["callable"])
	open_button.pressed.connect(func(): toggle_phone())

	open_button.mouse_entered.connect(func():
		var tw = open_button.create_tween().set_parallel(true)
		tw.tween_property(open_button, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	open_button.mouse_exited.connect(func():
		var tw = open_button.create_tween().set_parallel(true)
		tw.tween_property(open_button, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

	_setup_charger_hud_button()

func _setup_charger_hud_button() -> void:
	if not is_instance_valid(phone_frame):
		return
		
	if is_instance_valid(charger_hud_button):
		_actualizar_posicion_boton_cargador()
		return
		
	charger_hud_button = Button.new()
	charger_hud_button.name = "ChargerBottomButton"
	charger_hud_button.custom_minimum_size = Vector2(360, 80)
	charger_hud_button.pivot_offset = Vector2(180, 40)
	charger_hud_button.visible = is_open
	charger_hud_button.focus_mode = Control.FOCUS_NONE
	
	if _font:
		charger_hud_button.add_theme_font_override("font", _font)
	charger_hud_button.add_theme_font_size_override("font_size", 22)
	charger_hud_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	
	_actualizar_estilo_charger_hud_button()

	charger_hud_button.pressed.connect(func(): _conectar_cargador())
	charger_hud_button.mouse_entered.connect(func():
		if is_instance_valid(charger_hud_button):
			var tw = charger_hud_button.create_tween().set_parallel(true)
			tw.tween_property(charger_hud_button, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	charger_hud_button.mouse_exited.connect(func():
		if is_instance_valid(charger_hud_button):
			var tw = charger_hud_button.create_tween().set_parallel(true)
			tw.tween_property(charger_hud_button, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

	add_child(charger_hud_button)
	_actualizar_posicion_boton_cargador()

func _actualizar_posicion_boton_cargador() -> void:
	if not is_instance_valid(charger_hud_button):
		return
		
	charger_hud_button.visible = is_open
	if not is_open:
		return
		
	if is_instance_valid(phone_frame):
		var btn_w = 360.0
		var btn_h = 80.0
		var center_x = phone_frame.position.x + (phone_frame.size.x / 2.0) - (btn_w / 2.0)
		var bottom_y = phone_frame.position.y + phone_frame.size.y + 16.0
		
		# Ajuste por si sobresale del margen inferior de la pantalla
		var vp_h = get_viewport().get_visible_rect().size.y
		if bottom_y + btn_h > vp_h - 10.0:
			bottom_y = phone_frame.position.y + phone_frame.size.y - btn_h - 16.0
			
		charger_hud_button.position = Vector2(center_x, bottom_y)
		charger_hud_button.z_index = 100

func _actualizar_estilo_charger_hud_button() -> void:
	if not is_instance_valid(charger_hud_button):
		return
		
	if is_charging:
		charger_hud_button.text = "⚡ CARGANDO"
	else:
		charger_hud_button.text = "⚡ CARGADOR"
		
	var border_col = Color(0.14, 0.85, 0.45, 0.90) if not is_charging else C_AMBER
	var bg_col = Color(0.08, 0.12, 0.09, 0.90) if not is_charging else Color(0.14, 0.12, 0.08, 0.92)
	
	var n = StyleBoxFlat.new()
	n.bg_color            = bg_col
	n.border_width_left   = 1; n.border_width_top    = 1
	n.border_width_right  = 1; n.border_width_bottom = 2
	n.border_color        = border_col
	n.corner_radius_top_left     = 8; n.corner_radius_top_right    = 8
	n.corner_radius_bottom_left  = 8; n.corner_radius_bottom_right = 8
	n.shadow_color = Color(0, 0, 0, 0.35)
	n.shadow_size  = 6
	n.shadow_offset= Vector2(0, 2)

	var h = n.duplicate() as StyleBoxFlat
	h.bg_color     = bg_col.lightened(0.08)
	h.border_color = border_col.lightened(0.15)
	h.shadow_size  = 8

	charger_hud_button.add_theme_stylebox_override("normal",  n)
	charger_hud_button.add_theme_stylebox_override("hover",   h)
	charger_hud_button.add_theme_stylebox_override("pressed", n)
	charger_hud_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _actualizar_estilo_hud_boton(abierto: bool) -> void:
	if not is_instance_valid(open_button):
		return
		
	if not abierto:
		if _soporte_unread_count > 0:
			open_button.text = "💬  MENSAJE (" + str(_soporte_unread_count) + ")"
		else:
			open_button.text = "📟  TABLETA"
	else:
		open_button.text = "✕  CERRAR"
	
	var n = StyleBoxFlat.new()
	n.content_margin_left = 10.0; n.content_margin_top = 6.0
	n.content_margin_right = 12.0; n.content_margin_bottom = 6.0
	n.corner_radius_top_left = 8; n.corner_radius_top_right = 8
	n.corner_radius_bottom_left = 8; n.corner_radius_bottom_right = 8
	n.shadow_color = Color(0, 0, 0, 0.40)
	n.shadow_size = 6
	n.shadow_offset = Vector2(0, 2)
	
	if not abierto:
		n.bg_color = Color(0.08, 0.09, 0.11, 0.85)
		n.border_width_left = 1; n.border_width_top = 1
		n.border_width_right = 1; n.border_width_bottom = 1
		n.border_color = Color(0.78, 0.81, 0.85, 0.25)
	else:
		n.bg_color = Color(0.24, 0.11, 0.11, 0.94)
		n.border_width_left = 1; n.border_width_top = 1
		n.border_width_right = 1; n.border_width_bottom = 2
		n.border_color = Color(0.78, 0.28, 0.26, 0.92)

	var h = n.duplicate() as StyleBoxFlat
	if not abierto:
		h.bg_color = Color(0.14, 0.16, 0.19, 0.92)
		h.border_color = Color(0.85, 0.88, 0.92, 0.45)
		h.shadow_size = 8
	else:
		h.bg_color = Color(0.30, 0.13, 0.13, 0.95)

	open_button.add_theme_stylebox_override("normal",  n)
	open_button.add_theme_stylebox_override("hover",   h)
	open_button.add_theme_stylebox_override("pressed", n)
	open_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	_actualizar_notificaciones_soporte()

func _on_mensaje_soporte_recibido(autor: String, mensaje: String) -> void:
	if not is_open or current_app != "soporte":
		_soporte_unread_count += 1
		_actualizar_notificaciones_soporte()
		print("[CelularUI] Mensaje nuevo de soporte de ", autor, " (No leídos: ", _soporte_unread_count, ")")

func _actualizar_notificaciones_soporte() -> void:
	if not is_instance_valid(open_button):
		return

	if _soporte_unread_count > 0:
		if not is_open:
			open_button.text = "💬  MENSAJE (" + str(_soporte_unread_count) + ")"
			_iniciar_titileo_boton_tableta()
		else:
			_detener_titileo_boton_tableta()

		if not is_instance_valid(_hud_open_button_badge):
			_hud_open_button_badge = PanelContainer.new()
			_hud_open_button_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hud_open_button_badge.custom_minimum_size = Vector2(30, 30)
			var b_st = StyleBoxFlat.new()
			b_st.bg_color = Color(1.0, 0.15, 0.22, 1.0)
			b_st.border_width_left = 2; b_st.border_width_top = 2
			b_st.border_width_right = 2; b_st.border_width_bottom = 2
			b_st.border_color = Color.WHITE
			for c in ["top_left", "top_right", "bottom_left", "bottom_right"]:
				b_st.set("corner_radius_" + c, 15)
			b_st.shadow_color = Color(1.0, 0.1, 0.1, 0.6)
			b_st.shadow_size = 10
			_hud_open_button_badge.add_theme_stylebox_override("panel", b_st)

			var b_lbl = Label.new()
			b_lbl.name = "CountLabel"
			b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b_lbl.add_theme_font_size_override("font_size", 16)
			b_lbl.add_theme_color_override("font_color", Color.WHITE)
			_hud_open_button_badge.add_child(b_lbl)

			open_button.add_child(_hud_open_button_badge)
			_hud_open_button_badge.position = Vector2(open_button.custom_minimum_size.x - 20, -10)

		var lbl = _hud_open_button_badge.get_node_or_null("CountLabel") as Label
		if lbl:
			lbl.text = str(_soporte_unread_count)
		_hud_open_button_badge.visible = not is_open
	else:
		if is_instance_valid(_hud_open_button_badge):
			_hud_open_button_badge.visible = false
		_detener_titileo_boton_tableta()
		if not is_open:
			open_button.text = "📟  TABLETA"

	# Actualizar badge en la app de soporte dentro del home
	if is_instance_valid(_home_soporte_badge):
		_home_soporte_badge.visible = (_soporte_unread_count > 0)
		var h_lbl = _home_soporte_badge.get_node_or_null("CountLabel") as Label
		if h_lbl:
			h_lbl.text = str(_soporte_unread_count)

func _iniciar_titileo_boton_tableta() -> void:
	if _hud_blink_tween and _hud_blink_tween.is_valid():
		return
	if not is_instance_valid(open_button):
		return
	_hud_blink_tween = create_tween().set_loops()
	_hud_blink_tween.tween_property(open_button, "modulate", Color(2.0, 0.35, 0.25, 1.0), 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hud_blink_tween.tween_property(open_button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _detener_titileo_boton_tableta() -> void:
	if _hud_blink_tween:
		_hud_blink_tween.kill()
		_hud_blink_tween = null
	if is_instance_valid(open_button):
		open_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
		Color(0.08, 0.09, 0.14, 1.0),
		Color(0.04, 0.05, 0.09, 1.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	wallpaper_rect.texture = grad_tex

	var root = app_container_home.get_node_or_null("RootVBox") as VBoxContainer
	if not root:
		return
	var header = root.get_node_or_null("Header") as Control
	if header:
		header.visible = true
		var greet1 = header.get_node_or_null("HBox/GreetVBox/Greet1") as Label
		if greet1:
			greet1.text = "Bienvenido, Conductor"
			greet1.add_theme_color_override("font_color", C_TEXT)
			greet1.add_theme_font_size_override("font_size", 16)
		var greet2 = header.get_node_or_null("HBox/GreetVBox/Greet2") as Label
		if greet2:
			greet2.text = "NT-OS v2.0 • Sistema Operativo"
			greet2.add_theme_color_override("font_color", C_ACCENT)
			greet2.add_theme_font_size_override("font_size", 12)

	var sep = root.get_node_or_null("Sep") as Control
	if sep: sep.custom_minimum_size = Vector2(0, 12)
	
	var grid = root.get_node_or_null("GridMargin/Grid") as GridContainer
	if grid:
		grid.columns = home_grid_columns
		grid.add_theme_constant_override("h_separation", home_grid_h_separation)
		grid.add_theme_constant_override("v_separation", home_grid_v_separation)

	var dock_margin = root.get_node_or_null("DockMargin") as Control
	if dock_margin:
		dock_margin.visible = false

	for child in grid.get_children():
		child.queue_free()

	var apps = [
		["res://recursos/iconos app/app_mapa.png",    "GPS Waze",  C_ACCENT,                func(): _switch_app("waze")],
		["res://recursos/iconos app/app_banco.png",   "Banco",     Color(0.08, 0.38, 0.92), func(): _switch_app("bank")],
		["🚛",                                        "Fletes NT", Color(0.12, 0.48, 0.96), func(): _switch_app("fletes")],
		["🎯",                                        "Misiones",  Color(1.0, 0.78, 0.10),  func(): _switch_app("missions")],
		["🔧",                                        "Garage",    C_ORANGE,                func(): _switch_app("garage")],
		["res://recursos/iconos app/app_musica.png",  "Musica",    C_ACCENT2,               func(): _switch_app("music")],
		["🎧",                                        "Soporte",   Color(1.0, 0.45, 0.0),   func(): _switch_app("soporte")],
		["res://recursos/iconos app/app_ajustes.png", "Ajustes",   Color(0.30, 0.32, 0.40), func(): _switch_app("settings")],
	]
	for app_data in apps:
		grid.add_child(_create_app_icon(app_data[0], app_data[1], app_data[2], app_data[3]))

func _save_game() -> void:
	if player and player.has_method("guardar_progreso_conductor"):
		player.guardar_progreso_conductor()

func _create_app_icon(icon: String, title: String, color: Color, action: Callable) -> Button:
	var btn = Button.new()
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var icon_w = home_icon_size + 60.0
	var icon_h = home_icon_size + 70.0
	btn.custom_minimum_size = Vector2(icon_w, icon_h)
	btn.pivot_offset = Vector2(icon_w, icon_h) / 2.0

	var empty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.pressed.connect(action)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var holder = Panel.new()
	holder.custom_minimum_size = Vector2(home_icon_size, home_icon_size)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var h_st = StyleBoxFlat.new()
	h_st.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	h_st.border_width_left = 1; h_st.border_width_top = 1
	h_st.border_width_right = 1; h_st.border_width_bottom = 2
	h_st.border_color = Color(0.78, 0.81, 0.85, 0.25)
	for c in ["top_left","top_right","bottom_left","bottom_right"]:
		h_st.set("corner_radius_" + c, 20)
	h_st.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	h_st.shadow_size = 10
	h_st.shadow_offset = Vector2(0, 4)
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
		emoji_lbl.add_theme_font_size_override("font_size", 72)
		emoji_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lbl = Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		lbl.add_theme_font_override("font", _font)
	vbox.add_child(lbl)

	if title == "Soporte":
		_home_soporte_badge = PanelContainer.new()
		_home_soporte_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_home_soporte_badge.custom_minimum_size = Vector2(36, 36)
		var badge_st = StyleBoxFlat.new()
		badge_st.bg_color = Color(1.0, 0.15, 0.22, 1.0)
		badge_st.border_width_left = 2; badge_st.border_width_top = 2
		badge_st.border_width_right = 2; badge_st.border_width_bottom = 2
		badge_st.border_color = Color.WHITE
		for c in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			badge_st.set("corner_radius_" + c, 18)
		badge_st.shadow_color = Color(1.0, 0.1, 0.1, 0.6)
		badge_st.shadow_size = 10
		_home_soporte_badge.add_theme_stylebox_override("panel", badge_st)
		
		var b_lbl = Label.new()
		b_lbl.name = "CountLabel"
		b_lbl.text = str(_soporte_unread_count)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b_lbl.add_theme_font_size_override("font_size", 20)
		b_lbl.add_theme_color_override("font_color", Color.WHITE)
		_home_soporte_badge.add_child(b_lbl)

		holder.add_child(_home_soporte_badge)
		_home_soporte_badge.position = Vector2(home_icon_size - 24, -10)
		_home_soporte_badge.visible = (_soporte_unread_count > 0)

	btn.mouse_entered.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

	return btn

# ═════════════════════════════════════════════════════════════════════════════
#  APP: GPS WAZE  (pantalla completa dentro del movil)
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_waze(_parent: Control) -> void:
	if not app_container_waze:
		return
	for child in app_container_waze.get_children():
		child.queue_free()

	# 1. Viewport Container
	var vp_container = SubViewportContainer.new()
	vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	app_container_waze.add_child(vp_container)
	vp_container.gui_input.connect(_on_minimap_gui_input)

	minimap_viewport = SubViewport.new()
	minimap_viewport.size    = Vector2i(500, 780)
	minimap_viewport.msaa_3d = Viewport.MSAA_2X
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp_container.add_child(minimap_viewport)

	minimap_camera = Camera3D.new()
	minimap_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	minimap_camera.fov        = 55.0
	minimap_camera.far        = 500.0
	minimap_camera.rotation   = Vector3(-PI / 2.0, 0.0, 0.0)
	minimap_camera.cull_mask  = 2 # Corregido: Solo capa 2 para el mapa
	minimap_viewport.add_child(minimap_camera)

	# ─── AGREGADO MAGICO: DIBUJAR RED VIAL Y LINEA 2D SOBRE EL VIEWPORT 3D ─────────
	_red_vial_container = Control.new()
	_red_vial_container.name = "RedVialContainer"
	_red_vial_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_red_vial_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_container_waze.add_child(_red_vial_container)
	_red_vial_lines.clear()

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
	comp_st.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	comp_st.corner_radius_top_left=8;comp_st.corner_radius_top_right=8
	comp_st.corner_radius_bottom_left=8;comp_st.corner_radius_bottom_right=8
	comp_st.border_width_left=1;comp_st.border_width_top=1
	comp_st.border_width_right=1;comp_st.border_width_bottom=1
	comp_st.border_color = Color(0.78, 0.81, 0.85, 0.20)
	comp_st.shadow_color = Color(0, 0, 0, 0.35); comp_st.shadow_size=8
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
	cb_st.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	cb_st.corner_radius_top_left=8;cb_st.corner_radius_top_right=8
	cb_st.corner_radius_bottom_left=8;cb_st.corner_radius_bottom_right=8
	cb_st.border_width_left=1;cb_st.border_width_top=1
	cb_st.border_width_right=1;cb_st.border_width_bottom=1
	cb_st.border_color = Color(0.78, 0.81, 0.85, 0.20)
	cb_st.content_margin_left=10;cb_st.content_margin_top=6
	cb_st.content_margin_bottom=6;cb_st.content_margin_right=10
	cb_st.shadow_color = Color(0,0,0,0.35); cb_st.shadow_size=6
	coords_bg.add_theme_stylebox_override("panel", cb_st)
	app_container_waze.add_child(coords_bg)

	var coords_label = Label.new()
	coords_label.name = "CoordsLabel"
	coords_label.text = "LAT 5.3170\nLON -73.9390"
	coords_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coords_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	coords_label.add_theme_font_size_override("font_size", 20)
	coords_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95))
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
	lb_st.bg_color = Color(0.78, 0.20, 0.20, 0.92)
	lb_st.border_width_left = 1; lb_st.border_width_top = 1
	lb_st.border_width_right = 1; lb_st.border_width_bottom = 1
	lb_st.border_color = Color(0.95, 0.40, 0.40, 0.80)
	lb_st.corner_radius_top_left=8;lb_st.corner_radius_top_right=8
	lb_st.corner_radius_bottom_left=8;lb_st.corner_radius_bottom_right=8
	lb_st.shadow_color = Color(0,0,0,0.3); lb_st.shadow_size=4
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

	# 2f. Banda superior glassmorphic amplia
	var top_overlay = Panel.new()
	var to_style = StyleBoxFlat.new()
	to_style.bg_color = Color(0.06, 0.07, 0.08, 0.85) # Dark glassmorphic background
	to_style.border_width_bottom = 1
	to_style.border_color = Color(0.78, 0.81, 0.85, 0.20)
	top_overlay.add_theme_stylebox_override("panel", to_style)
	top_overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_overlay.offset_bottom = 145
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
	search_line_edit.placeholder_text = "  🔍  Buscar destino en Nuestra Tierra..."
	if _font: search_line_edit.add_theme_font_override("font", _font)
	search_line_edit.add_theme_font_size_override("font_size", 22)
	search_line_edit.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	search_line_edit.add_theme_color_override("placeholder_color", Color(0.60, 0.62, 0.72, 0.80))

	var sl_style = StyleBoxFlat.new()
	sl_style.bg_color = Color(0.08, 0.09, 0.12, 0.90)
	sl_style.border_width_left = 1; sl_style.border_width_top = 1
	sl_style.border_width_right = 1; sl_style.border_width_bottom = 1
	sl_style.border_color = Color(0.78, 0.81, 0.85, 0.25)
	sl_style.corner_radius_top_left = 8; sl_style.corner_radius_top_right = 8
	sl_style.corner_radius_bottom_left = 8; sl_style.corner_radius_bottom_right = 8
	sl_style.content_margin_left = 18; sl_style.content_margin_top = 10; sl_style.content_margin_bottom = 10
	sl_style.shadow_color = Color(0, 0, 0, 0.35); sl_style.shadow_size = 8
	search_line_edit.add_theme_stylebox_override("normal", sl_style)
	search_line_edit.add_theme_stylebox_override("normal", sl_style)
	search_margin.add_child(search_line_edit)

	search_line_edit.text_changed.connect(_on_search_text_changed)
	search_line_edit.focus_entered.connect(_show_search_dropdown)

	# 3b. Barra de Filtros de Categoria (Pills horizontal)
	var filter_scroll = ScrollContainer.new()
	filter_scroll.set_anchors_preset(Control.PRESET_TOP_WIDE)
	filter_scroll.offset_left = 14
	filter_scroll.offset_right = -14
	filter_scroll.offset_top = 80
	filter_scroll.offset_bottom = 135
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app_container_waze.add_child(filter_scroll)

	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 10)
	filter_scroll.add_child(filter_hbox)

	var categories = [
		["🌐 TODOS", "TODOS"],
		["⛽ GASOLINERAS", "GASOLINERA"],
		["🛠️ TALLERES", "TALLER"],
		["🏢 SERVICIOS", "SERVICIOS"],
		["📍 PROPIEDADES", "PROPIEDADES"]
	]

	for cat_info in categories:
		var pill_btn = Button.new()
		pill_btn.text = cat_info[0]
		pill_btn.custom_minimum_size = Vector2(0, 42)
		if _font: pill_btn.add_theme_font_override("font", _font)
		pill_btn.add_theme_font_size_override("font_size", 16)
		
		var cat_key = cat_info[1]
		_aplicar_estilo_pill_filtro(pill_btn, active_waze_category == cat_key)
		
		pill_btn.pressed.connect(func():
			active_waze_category = cat_key
			search_dropdown_container.visible = true
			_populate_dropdown(search_line_edit.text)
			for child in filter_hbox.get_children():
				if child is Button:
					var child_cat = child.get_meta("cat_key") if child.has_meta("cat_key") else ""
					_aplicar_estilo_pill_filtro(child, child_cat == active_waze_category)
		)
		pill_btn.set_meta("cat_key", cat_key)
		filter_hbox.add_child(pill_btn)

	# 4. Dropdown
	search_dropdown_container = ScrollContainer.new()
	search_dropdown_container.visible = false
	search_dropdown_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	search_dropdown_container.offset_left  = 14
	search_dropdown_container.offset_right = -14
	search_dropdown_container.offset_top   = 140
	search_dropdown_container.offset_bottom= 420
	app_container_waze.add_child(search_dropdown_container)

	var dd_bg = StyleBoxFlat.new()
	dd_bg.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	dd_bg.border_width_left = 1; dd_bg.border_width_top = 1
	dd_bg.border_width_right = 1; dd_bg.border_width_bottom = 1
	dd_bg.border_color = Color(0.78, 0.81, 0.85, 0.25)
	dd_bg.corner_radius_bottom_left = 10; dd_bg.corner_radius_bottom_right = 10
	dd_bg.content_margin_left = 10; dd_bg.content_margin_right = 10
	dd_bg.content_margin_top = 8; dd_bg.content_margin_bottom = 8
	dd_bg.shadow_color = Color(0, 0, 0, 0.40); dd_bg.shadow_size = 12
	search_dropdown_container.add_theme_stylebox_override("panel", dd_bg)

	search_dropdown_list = VBoxContainer.new()
	search_dropdown_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_dropdown_list.add_theme_constant_override("separation", 6)
	search_dropdown_container.add_child(search_dropdown_list)

	# 5. Boton Re-centrar
	recenter_button = Button.new()
	recenter_button.text    = " 🎯 Centrar "
	recenter_button.visible = false
	recenter_button.custom_minimum_size = Vector2(150, 48)
	app_container_waze.add_child(recenter_button)
	recenter_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	recenter_button.offset_bottom = -28
	recenter_button.offset_top    = -76

	var rc_style = StyleBoxFlat.new()
	rc_style.bg_color = Color(0.08, 0.09, 0.11, 0.85)
	rc_style.border_width_left = 1; rc_style.border_width_top = 1
	rc_style.border_width_right = 1; rc_style.border_width_bottom = 2
	rc_style.border_color = C_AMBER
	rc_style.corner_radius_top_left=8;rc_style.corner_radius_top_right=8
	rc_style.corner_radius_bottom_left=8;rc_style.corner_radius_bottom_right=8
	rc_style.shadow_color=Color(0,0,0,0.35);rc_style.shadow_size=6
	recenter_button.add_theme_stylebox_override("normal",  rc_style)
	recenter_button.add_theme_stylebox_override("hover",   rc_style)
	recenter_button.add_theme_stylebox_override("pressed", rc_style)
	recenter_button.add_theme_font_size_override("font_size", 18)
	recenter_button.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	recenter_button.pressed.connect(func():
		follow_player_camera = true
		recenter_button.visible = false
	)

	# 6. Boton Cancelar navegacion
	var cancel_btn = Button.new()
	cancel_btn.text = " ✕ Cancelar "
	cancel_btn.custom_minimum_size = Vector2(130, 44)
	app_container_waze.add_child(cancel_btn)
	cancel_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cancel_btn.offset_right = -14
	cancel_btn.offset_top   = 80
	cancel_btn.offset_left  = -150
	cancel_btn.offset_bottom= 124

	var cl_style = StyleBoxFlat.new()
	cl_style.bg_color = Color(0.24, 0.11, 0.11, 0.94)
	cl_style.border_width_left = 1; cl_style.border_width_top = 1
	cl_style.border_width_right = 1; cl_style.border_width_bottom = 2
	cl_style.border_color = Color(0.78, 0.28, 0.26, 0.92)
	cl_style.corner_radius_top_left=8;cl_style.corner_radius_top_right=8
	cl_style.corner_radius_bottom_left=8;cl_style.corner_radius_bottom_right=8
	cl_style.shadow_color=Color(0,0,0,0.35);cl_style.shadow_size=6
	cancel_btn.add_theme_stylebox_override("normal",  cl_style)
	cancel_btn.add_theme_stylebox_override("hover",   cl_style)
	cancel_btn.add_theme_stylebox_override("pressed", cl_style)
	cancel_btn.add_theme_font_size_override("font_size", 16)
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

func _actualizar_red_vial_waze_2d() -> void:
	if not is_open or current_app != "waze" or not is_instance_valid(minimap_camera) or not is_instance_valid(_red_vial_container):
		return
		
	# Escanear nodos de carriles cada 3 segundos en lugar de cada tick
	_waze_lane_scan_timer += GPS_UPDATE_INTERVAL
	if _cached_waze_lanes.is_empty() or _waze_lane_scan_timer >= 3.0:
		_waze_lane_scan_timer = 0.0
		_cached_waze_lanes.clear()
		var group_lanes = get_tree().get_nodes_in_group("traffic_lanes")
		if not group_lanes.is_empty():
			_cached_waze_lanes.append_array(group_lanes)
		else:
			for node in get_tree().get_nodes_in_group("traffic_network_manager"):
				if node and "lanes" in node:
					_cached_waze_lanes.append_array(node.lanes)

	var cam_pos = minimap_camera.global_position

	for lane in _cached_waze_lanes:
		if not is_instance_valid(lane) or not "curve" in lane or not lane.curve:
			continue
			
		var line_2d: Line2D = _red_vial_lines.get(lane, null)
		if not is_instance_valid(line_2d):
			line_2d = Line2D.new()
			line_2d.width = 4.0
			line_2d.default_color = Color(0.18, 0.48, 0.82, 0.45) # Azul Waze suave para carril
			line_2d.joint_mode = Line2D.LINE_JOINT_ROUND
			line_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
			line_2d.antialiased = true
			_red_vial_container.add_child(line_2d)
			_red_vial_lines[lane] = line_2d
			
		# Culling por distancia a la cámara del minimapa (> 160m)
		if lane.global_position.distance_to(cam_pos) > 160.0:
			line_2d.visible = false
			continue
			
		line_2d.visible = true
		line_2d.clear_points()
		
		# Obtener puntos muestreados con paso amplio (8m)
		var sampled_pts: PackedVector3Array
		if lane.has_method("get_sampled_points"):
			sampled_pts = lane.get_sampled_points(8.0)
		else:
			var curve: Curve3D = lane.curve
			sampled_pts = curve.get_baked_points()
		
		var step_stride = 1
		if sampled_pts.size() > 16:
			step_stride = 2
			
		for i in range(0, sampled_pts.size(), step_stride):
			var world_pt = lane.to_global(sampled_pts[i])
			if not minimap_camera.is_position_behind(world_pt):
				var p2d = minimap_camera.unproject_position(world_pt)
				line_2d.add_point(p2d)

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

func _aplicar_estilo_pill_filtro(btn: Button, activo: bool) -> void:
	if not is_instance_valid(btn):
		return
	var bg_col = Color(1.00, 0.45, 0.00, 0.90) if activo else Color(0.12, 0.14, 0.20, 0.90)
	var text_col = Color(1.0, 1.0, 1.0) if activo else Color(0.70, 0.72, 0.82)
	var border_col = Color(1.00, 0.60, 0.10, 1.0) if activo else Color(0.25, 0.28, 0.38, 0.60)

	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var st = StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_width_left = 2; st.border_width_top = 2
	st.border_width_right = 2; st.border_width_bottom = 2
	st.border_color = border_col
	st.corner_radius_top_left = 16; st.corner_radius_top_right = 16
	st.corner_radius_bottom_left = 16; st.corner_radius_bottom_right = 16
	st.content_margin_left = 14; st.content_margin_right = 14
	st.content_margin_top = 6; st.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", st)

	var h_st = st.duplicate() as StyleBoxFlat
	h_st.bg_color = Color(1.00, 0.50, 0.10, 1.0) if activo else Color(0.18, 0.22, 0.32, 0.95)
	btn.add_theme_stylebox_override("hover", h_st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _populate_dropdown(filter: String) -> void:
	# Buscar si existe CasaSpawnPoint en la escena actual para registrar "Casa" en el GPS
	var spawn_casa = get_tree().current_scene.find_child("CasaSpawnPoint", true, false) if get_tree() and get_tree().current_scene else null
	if not spawn_casa and get_tree() and get_tree().current_scene:
		# Fallback por si acaso find_child no la detecta
		for child in get_tree().current_scene.get_children():
			if child.name.begins_with("CasaSpawnPoint") or child.get_script() and child.get_script().get_global_name() == "CasaSpawnPoint":
				spawn_casa = child
				break
	if spawn_casa:
		destinations["📍 Casa / Residencia"] = spawn_casa.global_position

	for c in search_dropdown_list.get_children():
		c.queue_free()
	var q = filter.to_lower().strip_edges()
	for dest_name in destinations.keys():
		# Filtrado por Categoria activa pill
		if active_waze_category != "TODOS":
			var matches_cat = false
			if active_waze_category == "GASOLINERA" and ("gasolina" in dest_name.to_lower() or "⛽" in dest_name):
				matches_cat = true
			elif active_waze_category == "TALLER" and ("taller" in dest_name.to_lower() or "🛠️" in dest_name or "🛞" in dest_name):
				matches_cat = true
			elif active_waze_category == "SERVICIOS" and ("hospital" in dest_name.to_lower() or "policia" in dest_name.to_lower() or "banco" in dest_name.to_lower() or "concesionario" in dest_name.to_lower() or "academia" in dest_name.to_lower() or "mensajeria" in dest_name.to_lower() or "mercado" in dest_name.to_lower()):
				matches_cat = true
			elif active_waze_category == "PROPIEDADES" and ("casa" in dest_name.to_lower() or "residencia" in dest_name.to_lower() or "📍" in dest_name):
				matches_cat = true
				
			if not matches_cat:
				continue

		# Filtrado por búsqueda de texto
		if q != "" and not dest_name.to_lower().contains(q):
			continue
		var btn = Button.new()
		btn.text = dest_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		if _font: btn.add_theme_font_override("font", _font)

		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.10, 0.12, 0.18, 0.95) # Dark glassmorphic surface
		s.border_width_left = 2; s.border_width_top = 2
		s.border_width_right = 2; s.border_width_bottom = 2
		s.border_color = Color(0.20, 0.60, 1.00, 0.40) # Neon blue border
		s.content_margin_left = 18; s.content_margin_top = 10; s.content_margin_bottom = 10
		s.corner_radius_top_left = 12; s.corner_radius_top_right = 12
		s.corner_radius_bottom_left = 12; s.corner_radius_bottom_right = 12
		btn.add_theme_stylebox_override("normal", s)

		var sh = s.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.18, 0.24, 0.38, 0.98)
		sh.border_color = Color(1.00, 0.45, 0.00, 0.90) # Orange neon hover
		btn.add_theme_stylebox_override("hover", sh)

		var coords = destinations[dest_name]
		btn.pressed.connect(func():
			if gps_line:
				gps_line.set_destination(coords)
			search_line_edit.text = dest_name
			search_dropdown_container.visible = false
			search_line_edit.release_focus()
			
			# Calcular distancia estimada en metros/km para feedback inmediato
			var check_pos = player.global_position if is_instance_valid(player) else Vector3.ZERO
			var dist_m = check_pos.distance_to(coords)
			var dist_text = " (%.1f km)" % (dist_m / 1000.0) if dist_m >= 1000.0 else " (%d m)" % int(dist_m)
			notificar("🗺️ Ruta calculada a " + dest_name + dist_text, "exito")
		)
		search_dropdown_list.add_child(btn)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB)):
		if not is_open and Time.get_ticks_msec() - _ready_msec < 500:
			return
		toggle_phone()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		# Jamás procesar la barra espaciadora en el Celular/Tableta (reservada para el salto del jugador)
		if is_instance_valid(open_button) and open_button.has_focus():
			open_button.release_focus()
		if is_instance_valid(charger_hud_button) and charger_hud_button.has_focus():
			charger_hud_button.release_focus()
		return

	if event is InputEventScreenTouch and event.pressed:
		if search_dropdown_container and search_dropdown_container.visible:
			if not search_dropdown_container.get_global_rect().has_point(event.position) and \
			   not search_line_edit.get_global_rect().has_point(event.position):
				search_dropdown_container.visible = false

var bank_transactions: Array = [
	{"type": "in", "desc": "Bono de Bienvenida Banco", "amount": 150000, "date": "Hoy"},
]
var bank_investment_balance: float = 0.0
var bank_loan_balance: float = 0.0
var bank_interactive_container: MarginContainer = null

# ── Variables de Préstamo de Libre Inversión por Días Reales y Score Financiero ──
var nequi_loan_state: Dictionary = {
	"activo": false,
	"monto_original": 0.0,
	"saldo_pendiente": 0.0,
	"plazo_dias": 10,
	"cuota_diaria": 0.0,
	"cuotas_pagadas": 0,
	"dia_real_inicio": 0,
	"ultimo_dia_pago": -1,
	"ultimo_dia_evaluado": 0,
	"dias_mora_actuales": 0,
	"dias_mora_historicos": 0,
	"score_financiero": 550
}
var _plazo_seleccionado_dias: int = 10
var _recordatorio_nequi_timer: float = 0.0
var _recordatorio_mostrado_sesion: bool = false
var _bank_score_label: Label = null
var _bank_cupo_label: Label = null
var _bank_mora_label: Label = null

# Paleta Nequi Azul y Blanco
const NEQUI_BG_LIGHT     := Color(0.06, 0.07, 0.09, 0.96) # Dark glass base de UIVehiculo
const NEQUI_CARD_WHITE   := Color(0.08, 0.09, 0.12, 0.85) # Tarjeta vidrio oscuro
const NEQUI_BLUE_PRIMARY := Color(0.20, 0.60, 1.00, 1.00) # Azul neon acento
const NEQUI_BLUE_DEEP    := Color(0.95, 0.96, 0.98, 1.00) # Titulo claro de alto contraste
const NEQUI_BLUE_ACCENT  := Color(0.30, 0.70, 1.00, 1.00) # Azul brillante
const NEQUI_BORDER_SOFT  := Color(0.78, 0.81, 0.85, 0.20) # Borde metalico translucido (1px)
const NEQUI_TEXT_DARK    := Color(0.95, 0.96, 0.98, 1.00) # Texto claro legible
const NEQUI_TEXT_MUTED   := Color(0.68, 0.72, 0.76, 0.90) # Texto secundario claro

func _obtener_dia_real_actual() -> int:
	var unix_col: int = int(Time.get_unix_time_from_system()) - (5 * 3600)
	return int(floor(float(unix_col) / 86400.0))

func _obtener_fecha_hora_texto() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%02d/%02d %02d:%02d" % [
		int(dt.get("day", 1)),
		int(dt.get("month", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0))
	]

func _calcular_cupo_maximo_nequi() -> float:
	var score: int = int(nequi_loan_state.get("score_financiero", 550))
	var mora_hist: int = int(nequi_loan_state.get("dias_mora_historicos", 0))
	var cupo_base: float = 100000.0
	if score >= 800:
		cupo_base = 3500000.0
	elif score >= 700:
		cupo_base = 1500000.0
	elif score >= 600:
		cupo_base = 600000.0
	elif score >= 500:
		cupo_base = 250000.0
	elif score >= 400:
		cupo_base = 100000.0
	else:
		cupo_base = 50000.0

	var factor_mora: float = clampf(1.0 - (float(mora_hist) * 0.12), 0.20, 1.0)
	var cupo_final: float = round(cupo_base * factor_mora / 10000.0) * 10000.0
	return maxf(cupo_final, 20000.0)

func registrar_movimiento_nequi(tipo: String, descripcion: String, monto: float) -> void:
	_load_bank_config()
	bank_transactions.push_front({
		"type": tipo,
		"desc": descripcion,
		"amount": round(absf(monto)),
		"date": _obtener_fecha_hora_texto()
	})
	if bank_transactions.size() > 60:
		bank_transactions.resize(60)
	_save_bank_config()
	_update_bank_display()

func _verificar_mora_y_recordatorio_nequi(mostrar_notificacion_inicio: bool = false) -> void:
	if not nequi_loan_state.get("activo", false):
		return

	var dia_actual: int = _obtener_dia_real_actual()
	var dia_inicio: int = int(nequi_loan_state.get("dia_real_inicio", dia_actual))
	var ultimo_eval: int = int(nequi_loan_state.get("ultimo_dia_evaluado", dia_inicio))
	var cuotas_pagadas: int = int(nequi_loan_state.get("cuotas_pagadas", 0))
	var plazo: int = max(int(nequi_loan_state.get("plazo_dias", 10)), 1)

	var dias_transcurridos: int = max(0, dia_actual - dia_inicio)
	var cuotas_exigibles: int = clampi(dias_transcurridos, 0, plazo)

	if dia_actual > ultimo_eval:
		var deficit: int = max(0, cuotas_exigibles - cuotas_pagadas)
		if deficit > 0:
			var nuevos_mora: int = mini(deficit, dia_actual - ultimo_eval)
			nequi_loan_state["dias_mora_actuales"] = int(nequi_loan_state.get("dias_mora_actuales", 0)) + nuevos_mora
			nequi_loan_state["dias_mora_historicos"] = int(nequi_loan_state.get("dias_mora_historicos", 0)) + nuevos_mora
			nequi_loan_state["score_financiero"] = clampi(int(nequi_loan_state.get("score_financiero", 550)) - (nuevos_mora * 25), 300, 850)
		nequi_loan_state["ultimo_dia_evaluado"] = dia_actual
		_save_bank_config()

	var ultimo_pago: int = int(nequi_loan_state.get("ultimo_dia_pago", -1))
	var cuota_hoy_pendiente: bool = (ultimo_pago < dia_actual) and (cuotas_pagadas < plazo)
	var mora_actual: int = int(nequi_loan_state.get("dias_mora_actuales", 0))
	var valor_cuota: float = float(nequi_loan_state.get("cuota_diaria", 10000.0))

	if mostrar_notificacion_inicio and (cuota_hoy_pendiente or mora_actual > 0):
		var tree = get_tree()
		if tree:
			tree.create_timer(3.5, true).timeout.connect(func():
				if mora_actual > 0:
					notificar("🔔 Banco: Tienes %d día(s) de mora. Paga tu cuota de %s para no afectar tu cupo." % [mora_actual, _formatear_pesos_colombianos(valor_cuota)], "alerta")
				else:
					notificar("🔔 Recordatorio Banco: Recuerda pagar hoy tu cuota diaria de %s." % _formatear_pesos_colombianos(valor_cuota), "info")
			, CONNECT_ONE_SHOT)

func _procesar_recordatorios_nequi(delta: float) -> void:
	if not nequi_loan_state.get("activo", false):
		return
	_recordatorio_nequi_timer += delta
	if _recordatorio_nequi_timer >= 240.0: # Recordatorio cada 4 minutos si sigue pendiente
		_recordatorio_nequi_timer = 0.0
		var dia_actual: int = _obtener_dia_real_actual()
		var ultimo_pago: int = int(nequi_loan_state.get("ultimo_dia_pago", -1))
		var mora_actual: int = int(nequi_loan_state.get("dias_mora_actuales", 0))
		var valor_cuota: float = float(nequi_loan_state.get("cuota_diaria", 10000.0))
		if ultimo_pago < dia_actual or mora_actual > 0:
			notificar("🔔 Banco: Cuota diaria pendiente (%s). Evita acumular días de mora." % _formatear_pesos_colombianos(valor_cuota), "info")

func _load_bank_config() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://banco_nt.cfg") == OK:
		bank_investment_balance = float(cfg.get_value("banco", "inversion", 0.0))
		bank_loan_balance = float(cfg.get_value("banco", "prestamo", 0.0))
		bank_equipped_card = str(cfg.get_value("banco", "equipped_card", "clasica"))
		var purchased = cfg.get_value("banco", "purchased_cards", ["clasica"])
		if purchased is Array:
			bank_purchased_cards = purchased
		var hist = cfg.get_value("banco", "historial", [])
		if hist is Array and not hist.is_empty():
			bank_transactions = hist
		var saved_loan = cfg.get_value("banco", "nequi_loan_state", {})
		if typeof(saved_loan) == TYPE_DICTIONARY and not saved_loan.is_empty():
			for k in saved_loan.keys():
				nequi_loan_state[k] = saved_loan[k]
			bank_loan_balance = float(nequi_loan_state.get("saldo_pendiente", 0.0))

func _save_bank_config() -> void:
	var cfg = ConfigFile.new()
	nequi_loan_state["saldo_pendiente"] = bank_loan_balance
	cfg.set_value("banco", "inversion", bank_investment_balance)
	cfg.set_value("banco", "prestamo", bank_loan_balance)
	cfg.set_value("banco", "equipped_card", bank_equipped_card)
	cfg.set_value("banco", "purchased_cards", bank_purchased_cards)
	cfg.set_value("banco", "historial", bank_transactions)
	cfg.set_value("banco", "nequi_loan_state", nequi_loan_state)
	cfg.save("user://banco_nt.cfg")

# ═════════════════════════════════════════════════════════════════════════════
#  APP: NEQUI BANCO — DISEÑO AZUL Y BLANCO CON PRÉSTAMOS POR DÍAS REALES
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_bank(_parent: Control) -> void:
	if not app_container_bank:
		return
	_load_bank_config()
	_verificar_mora_y_recordatorio_nequi(false)

	var bg_panel = app_container_bank.get_node_or_null("BGPanel") as Panel
	if not bg_panel:
		bg_panel = Panel.new()
		bg_panel.name = "BGPanel"
		bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app_container_bank.add_child(bg_panel)
		app_container_bank.move_child(bg_panel, 0)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = NEQUI_BG_LIGHT
	bg_style.corner_radius_top_left = 20; bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20; bg_style.corner_radius_bottom_right = 20
	bg_panel.add_theme_stylebox_override("panel", bg_style)

	var root = app_container_bank.get_node_or_null("RootVBox") as VBoxContainer
	if not root:
		root = VBoxContainer.new()
		root.name = "RootVBox"
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_theme_constant_override("separation", 0)
		app_container_bank.add_child(root)

	var header = root.get_node_or_null("Header") as MarginContainer
	if not header:
		header = MarginContainer.new()
		header.name = "Header"
		header.custom_minimum_size = Vector2(0, 62)
		root.add_child(header)

	var header_hbox = header.get_node_or_null("HBox") as HBoxContainer
	if not header_hbox:
		header_hbox = HBoxContainer.new()
		header_hbox.name = "HBox"
		header.add_child(header_hbox)

	var back = header_hbox.get_node_or_null("BackButton") as Button
	if back:
		back.visible = true
		back.text = "⬅ Inicio"
		back.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
		for conn in back.pressed.get_connections():
			back.pressed.disconnect(conn["callable"])
		back.pressed.connect(func(): _switch_app("home"))

	var title_lbl = header_hbox.get_node_or_null("TitleLabel") as Label
	if not title_lbl:
		title_lbl = Label.new()
		title_lbl.name = "TitleLabel"
		header_hbox.add_child(title_lbl)

	title_lbl.text = "BANCO 💳"
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)

	header.add_theme_constant_override("margin_top", 14)
	header.add_theme_constant_override("margin_bottom", 6)
	header.add_theme_constant_override("margin_left", 20)
	header.add_theme_constant_override("margin_right", 20)

	var content_margin = root.get_node_or_null("ContentMargin") as MarginContainer
	if not content_margin:
		content_margin = MarginContainer.new()
		content_margin.name = "ContentMargin"
		content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(content_margin)

	var old_content_vbox = content_margin.get_node_or_null("ContentVBox") as VBoxContainer
	if old_content_vbox:
		old_content_vbox.visible = false

	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_bottom", 16)

	var main_hbox = content_margin.get_node_or_null("MainHBox") as HBoxContainer
	if not main_hbox:
		main_hbox = HBoxContainer.new()
		main_hbox.name = "MainHBox"
		main_hbox.add_theme_constant_override("separation", 20)
		main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margin.add_child(main_hbox)

	var left_vbox = main_hbox.get_node_or_null("LeftVBox") as VBoxContainer
	if not left_vbox:
		left_vbox = VBoxContainer.new()
		left_vbox.name = "LeftVBox"
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vbox.size_flags_stretch_ratio = 0.90
		left_vbox.add_theme_constant_override("separation", 12)
		main_hbox.add_child(left_vbox)

	for child in left_vbox.get_children():
		child.queue_free()

	# 1. Tarjeta Principal Nequi Dark Glass
	var card = PanelContainer.new()
	card.name = "NequiBlueCard"
	card.custom_minimum_size = Vector2(0, 235)

	var card_st = StyleBoxFlat.new()
	card_st.bg_color = Color(0.08, 0.12, 0.18, 0.92)
	card_st.corner_radius_top_left = 12; card_st.corner_radius_top_right = 12
	card_st.corner_radius_bottom_left = 12; card_st.corner_radius_bottom_right = 12
	card_st.border_width_left = 1; card_st.border_width_top = 1
	card_st.border_width_right = 1; card_st.border_width_bottom = 2
	card_st.border_color = Color(0.20, 0.60, 1.00, 0.60)
	card_st.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	card_st.shadow_size = 12
	card_st.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", card_st)

	var card_m = MarginContainer.new()
	card_m.add_theme_constant_override("margin_left", 20)
	card_m.add_theme_constant_override("margin_right", 20)
	card_m.add_theme_constant_override("margin_top", 16)
	card_m.add_theme_constant_override("margin_bottom", 16)
	card.add_child(card_m)

	var cvbox = VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 8)
	card_m.add_child(cvbox)

	var c_hdr = HBoxContainer.new()
	var c_title = Label.new()
	c_title.text = "CUENTA BANCO CONDUCTOR"
	c_title.add_theme_font_size_override("font_size", 16)
	c_title.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	c_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var c_num = Label.new()
	c_num.text = "ACTIVA ••92"
	c_num.add_theme_font_size_override("font_size", 14)
	c_num.add_theme_color_override("font_color", Color.WHITE)
	c_hdr.add_child(c_title); c_hdr.add_child(c_num)
	cvbox.add_child(c_hdr)

	var m_lbl_title = Label.new()
	m_lbl_title.text = "DISPONIBLE"
	m_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_lbl_title.add_theme_font_size_override("font_size", 14)
	m_lbl_title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	cvbox.add_child(m_lbl_title)

	bank_money_label = Label.new()
	bank_money_label.name = "MoneyLabel"
	bank_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank_money_label.add_theme_font_size_override("font_size", 54)
	bank_money_label.add_theme_color_override("font_color", Color.WHITE)
	cvbox.add_child(bank_money_label)

	var e_hdr = HBoxContainer.new()
	e_hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	bank_emeralds_label = Label.new()
	bank_emeralds_label.name = "EmeraldsLabel"
	bank_emeralds_label.add_theme_font_size_override("font_size", 16)
	bank_emeralds_label.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	e_hdr.add_child(bank_emeralds_label)
	cvbox.add_child(e_hdr)

	left_vbox.add_child(card)

	# 2. Panel Blanco de Situación Financiera (Score, Cupo, Deuda y Mora)
	var metrics_panel = PanelContainer.new()
	metrics_panel.name = "MetricsPanel"
	var met_st = StyleBoxFlat.new()
	met_st.bg_color = NEQUI_CARD_WHITE
	met_st.corner_radius_top_left = 16; met_st.corner_radius_top_right = 16
	met_st.corner_radius_bottom_left = 16; met_st.corner_radius_bottom_right = 16
	met_st.border_width_left = 1; met_st.border_width_top = 1
	met_st.border_width_right = 1; met_st.border_width_bottom = 1
	met_st.border_color = NEQUI_BORDER_SOFT
	metrics_panel.add_theme_stylebox_override("panel", met_st)

	var met_m = MarginContainer.new()
	met_m.add_theme_constant_override("margin_left", 16); met_m.add_theme_constant_override("margin_right", 16)
	met_m.add_theme_constant_override("margin_top", 12); met_m.add_theme_constant_override("margin_bottom", 12)
	metrics_panel.add_child(met_m)

	var met_grid = GridContainer.new()
	met_grid.columns = 2
	met_grid.add_theme_constant_override("h_separation", 16)
	met_grid.add_theme_constant_override("v_separation", 10)
	met_m.add_child(met_grid)

	# Box Deuda Activa
	var loan_v = VBoxContainer.new()
	loan_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var loan_t = Label.new(); loan_t.text = "💳 DEUDA PRÉSTAMO"; loan_t.add_theme_font_size_override("font_size", 12); loan_t.add_theme_color_override("font_color", NEQUI_TEXT_MUTED)
	bank_loan_label = Label.new()
	bank_loan_label.add_theme_font_size_override("font_size", 22)
	bank_loan_label.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	loan_v.add_child(loan_t); loan_v.add_child(bank_loan_label)
	met_grid.add_child(loan_v)

	# Box Cupo Disponible
	var cupo_v = VBoxContainer.new()
	cupo_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cupo_t = Label.new(); cupo_t.text = "🏦 CUPO APROBADO"; cupo_t.add_theme_font_size_override("font_size", 12); cupo_t.add_theme_color_override("font_color", NEQUI_TEXT_MUTED)
	_bank_cupo_label = Label.new()
	_bank_cupo_label.add_theme_font_size_override("font_size", 22)
	_bank_cupo_label.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
	cupo_v.add_child(cupo_t); cupo_v.add_child(_bank_cupo_label)
	met_grid.add_child(cupo_v)

	# Box Score Financiero
	var score_v = VBoxContainer.new()
	score_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var score_t = Label.new(); score_t.text = "📈 SCORE FINANCIERO"; score_t.add_theme_font_size_override("font_size", 12); score_t.add_theme_color_override("font_color", NEQUI_TEXT_MUTED)
	_bank_score_label = Label.new()
	_bank_score_label.add_theme_font_size_override("font_size", 18)
	_bank_score_label.add_theme_color_override("font_color", NEQUI_TEXT_DARK)
	score_v.add_child(score_t); score_v.add_child(_bank_score_label)
	met_grid.add_child(score_v)

	# Box Días de Mora
	var mora_v = VBoxContainer.new()
	mora_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mora_t = Label.new(); mora_t.text = "⏰ ESTADO DE MORA"; mora_t.add_theme_font_size_override("font_size", 12); mora_t.add_theme_color_override("font_color", NEQUI_TEXT_MUTED)
	_bank_mora_label = Label.new()
	_bank_mora_label.add_theme_font_size_override("font_size", 18)
	_bank_mora_label.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
	mora_v.add_child(mora_t); mora_v.add_child(_bank_mora_label)
	met_grid.add_child(mora_v)

	left_vbox.add_child(metrics_panel)

	# 3. Tarjeta Blanca de Recordatorios y Salud Financiera
	var info_panel = PanelContainer.new()
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var info_st = StyleBoxFlat.new()
	info_st.bg_color = NEQUI_CARD_WHITE
	info_st.corner_radius_top_left = 16; info_st.corner_radius_top_right = 16
	info_st.corner_radius_bottom_left = 16; info_st.corner_radius_bottom_right = 16
	info_st.border_width_left = 2; info_st.border_width_top = 2
	info_st.border_width_right = 2; info_st.border_width_bottom = 2
	info_st.border_color = NEQUI_BLUE_ACCENT
	info_panel.add_theme_stylebox_override("panel", info_st)

	var info_m = MarginContainer.new()
	info_m.add_theme_constant_override("margin_left", 16); info_m.add_theme_constant_override("margin_right", 16)
	info_m.add_theme_constant_override("margin_top", 12); info_m.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_m)

	var info_v = VBoxContainer.new()
	info_v.add_theme_constant_override("separation", 8)
	info_m.add_child(info_v)

	var info_hdr = Label.new()
	info_hdr.text = "🔔 RECORDATORIO DE PAGOS DIARIOS"
	info_hdr.add_theme_font_size_override("font_size", 15)
	info_hdr.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
	info_v.add_child(info_hdr)

	var info_txt = Label.new()
	info_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_txt.add_theme_font_size_override("font_size", 13)
	info_txt.add_theme_color_override("font_color", NEQUI_TEXT_DARK)
	if nequi_loan_state.get("activo", false):
		var c_diaria: float = float(nequi_loan_state.get("cuota_diaria", 0.0))
		var pagadas: int = int(nequi_loan_state.get("cuotas_pagadas", 0))
		var plazo_tot: int = int(nequi_loan_state.get("plazo_dias", 10))
		info_txt.text = "Préstamo activo: Cuota diaria de %s (%d/%d días reales pagados). Paga a tiempo cada día real para subir tu cupo." % [_formatear_pesos_colombianos(c_diaria), pagadas, plazo_tot]
	else:
		info_txt.text = "No tienes cuotas pendientes hoy. Pide un Préstamo de Libre Inversión y págalo por días reales para subir tu Score Financiero."
	info_v.add_child(info_txt)

	left_vbox.add_child(info_panel)

	# ─── COLUMNA DERECHA: NAVEGACIÓN AZUL Y BLANCO ───
	var right_vbox = main_hbox.get_node_or_null("RightVBox") as VBoxContainer
	if not right_vbox:
		right_vbox = VBoxContainer.new()
		right_vbox.name = "RightVBox"
		right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.size_flags_stretch_ratio = 1.10
		right_vbox.add_theme_constant_override("separation", 12)
		main_hbox.add_child(right_vbox)

	var nav_capsule = right_vbox.get_node_or_null("NavCapsule") as PanelContainer
	if nav_capsule:
		nav_capsule.queue_free()

	nav_capsule = PanelContainer.new()
	nav_capsule.name = "NavCapsule"
	var cap_st = StyleBoxFlat.new()
	cap_st.bg_color = NEQUI_CARD_WHITE
	cap_st.border_width_left = 1; cap_st.border_width_top = 1
	cap_st.border_width_right = 1; cap_st.border_width_bottom = 1
	cap_st.border_color = NEQUI_BORDER_SOFT
	cap_st.corner_radius_top_left = 14; cap_st.corner_radius_top_right = 14
	cap_st.corner_radius_bottom_left = 14; cap_st.corner_radius_bottom_right = 14
	nav_capsule.add_theme_stylebox_override("panel", cap_st)

	var cap_margin = MarginContainer.new()
	cap_margin.add_theme_constant_override("margin_left", 6); cap_margin.add_theme_constant_override("margin_right", 6)
	cap_margin.add_theme_constant_override("margin_top", 6); cap_margin.add_theme_constant_override("margin_bottom", 6)
	nav_capsule.add_child(cap_margin)

	bank_nav_hbox = HBoxContainer.new()
	bank_nav_hbox.name = "NavHBox"
	bank_nav_hbox.add_theme_constant_override("separation", 6)
	cap_margin.add_child(bank_nav_hbox)

	var tabs = [
		["PRÉSTAMOS", "prestamo"],
		["MOVIMIENTOS", "historial"],
		["MEJORA FINANCIERA", "inversion"],
		["CANJE", "cambio"]
	]

	for t in tabs:
		var btn = Button.new()
		btn.name = "Tab_" + t[1]
		btn.text = t[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 15)
		var tab_id = str(t[1])
		btn.pressed.connect(func(): _switch_bank_tab(tab_id))
		bank_nav_hbox.add_child(btn)

	right_vbox.add_child(nav_capsule)
	right_vbox.move_child(nav_capsule, 0)

	bank_interactive_container = right_vbox.get_node_or_null("InteractiveMargin") as MarginContainer
	if not bank_interactive_container:
		bank_interactive_container = MarginContainer.new()
		bank_interactive_container.name = "InteractiveMargin"
		bank_interactive_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_vbox.add_child(bank_interactive_container)

	if bank_active_tab == "" or bank_active_tab == "inversion":
		bank_active_tab = "prestamo"
	_update_bank_display()
	_switch_bank_tab(bank_active_tab)

	if _font:
		_apply_font_recursive(app_container_bank)

func _switch_bank_tab(tab_name: String) -> void:
	bank_active_tab = tab_name

	if is_instance_valid(bank_nav_hbox):
		for child in bank_nav_hbox.get_children():
			if child is Button:
				var is_active = child.name == ("Tab_" + tab_name)
				var st = StyleBoxFlat.new()
				st.corner_radius_top_left = 10; st.corner_radius_top_right = 10
				st.corner_radius_bottom_left = 10; st.corner_radius_bottom_right = 10
				if is_active:
					st.bg_color = Color(0.18, 0.20, 0.24, 0.94)
					st.border_width_left = 1; st.border_width_top = 1
					st.border_width_right = 1; st.border_width_bottom = 2
					st.border_color = C_AMBER
					child.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
				else:
					st.bg_color = Color.TRANSPARENT
					child.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76, 0.90))
				child.add_theme_stylebox_override("normal", st)
				child.add_theme_stylebox_override("hover", st)
				child.add_theme_stylebox_override("pressed", st)
				child.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if is_instance_valid(bank_interactive_container):
		for c in bank_interactive_container.get_children():
			c.queue_free()

		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var p_st = StyleBoxFlat.new()
		p_st.bg_color = NEQUI_CARD_WHITE
		p_st.border_width_left = 1; p_st.border_width_top = 1
		p_st.border_width_right = 1; p_st.border_width_bottom = 1
		p_st.border_color = NEQUI_BORDER_SOFT
		p_st.corner_radius_top_left = 16; p_st.corner_radius_top_right = 16
		p_st.corner_radius_bottom_left = 16; p_st.corner_radius_bottom_right = 16
		panel.add_theme_stylebox_override("panel", p_st)
		bank_interactive_container.add_child(panel)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		panel.add_child(margin)

		match tab_name:
			"prestamo":
				_build_bank_tab_prestamo(margin)
			"historial":
				_build_bank_tab_historial(margin)
			"inversion":
				_build_bank_tab_inversion(margin)
			"cambio":
				_build_bank_tab_cambio(margin)

	if _font and is_instance_valid(bank_interactive_container):
		_apply_font_recursive(bank_interactive_container)

func _build_bank_tab_prestamo(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "💳 PRÉSTAMO DE LIBRE INVERSIÓN"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	vbox.add_child(title)

	var cupo_max: float = _calcular_cupo_maximo_nequi()

	if nequi_loan_state.get("activo", false):
		# Mostrar estado detallado del préstamo activo y botones de pago diario
		var monto_orig: float = float(nequi_loan_state.get("monto_original", 100000.0))
		var cuota_d: float = float(nequi_loan_state.get("cuota_diaria", 10000.0))
		var plazo_d: int = int(nequi_loan_state.get("plazo_dias", 10))
		var pagadas_d: int = int(nequi_loan_state.get("cuotas_pagadas", 0))
		var mora_d: int = int(nequi_loan_state.get("dias_mora_actuales", 0))

		var box_info = PanelContainer.new()
		var bi_st = StyleBoxFlat.new()
		bi_st.bg_color = NEQUI_BG_LIGHT
		bi_st.border_width_left = 2; bi_st.border_width_top = 2
		bi_st.border_width_right = 2; bi_st.border_width_bottom = 2
		bi_st.border_color = NEQUI_BLUE_PRIMARY
		bi_st.corner_radius_top_left = 12; bi_st.corner_radius_top_right = 12
		bi_st.corner_radius_bottom_left = 12; bi_st.corner_radius_bottom_right = 12
		bi_st.content_margin_left = 14; bi_st.content_margin_right = 14
		bi_st.content_margin_top = 12; bi_st.content_margin_bottom = 12
		box_info.add_theme_stylebox_override("panel", bi_st)

		var bi_vbox = VBoxContainer.new()
		bi_vbox.add_theme_constant_override("separation", 6)
		box_info.add_child(bi_vbox)

		var l1 = Label.new()
		l1.text = "Monto Prestado: %s  |  Plazo: %d días reales" % [_formatear_pesos_colombianos(monto_orig), plazo_d]
		l1.add_theme_font_size_override("font_size", 16)
		l1.add_theme_color_override("font_color", NEQUI_TEXT_DARK)
		bi_vbox.add_child(l1)

		var l2 = Label.new()
		l2.text = "Cuota Diaria Fija: %s  |  Progreso: %d / %d cuotas pagadas" % [_formatear_pesos_colombianos(cuota_d), pagadas_d, plazo_d]
		l2.add_theme_font_size_override("font_size", 16)
		l2.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
		bi_vbox.add_child(l2)

		var l3 = Label.new()
		if mora_d > 0:
			l3.text = "⚠️ Días de mora acumulados: %d día(s). Paga hoy para no reducir tu cupo." % mora_d
			l3.add_theme_color_override("font_color", Color(0.85, 0.18, 0.22))
		else:
			l3.text = "✅ Estás al día con tus pagos diarios (0 días en mora)."
			l3.add_theme_color_override("font_color", Color(0.10, 0.62, 0.34))
		l3.add_theme_font_size_override("font_size", 15)
		bi_vbox.add_child(l3)

		vbox.add_child(box_info)

		# Botón Pagar Cuota Diaria
		var btn_cuota = Button.new()
		btn_cuota.text = "💳 PAGAR CUOTA DIARIA (%s)" % _formatear_pesos_colombianos(cuota_d)
		btn_cuota.custom_minimum_size = Vector2(0, 56)
		btn_cuota.add_theme_font_size_override("font_size", 19)
		btn_cuota.add_theme_color_override("font_color", Color.WHITE)
		var st_c = StyleBoxFlat.new()
		st_c.bg_color = NEQUI_BLUE_PRIMARY
		st_c.corner_radius_top_left = 12; st_c.corner_radius_top_right = 12
		st_c.corner_radius_bottom_left = 12; st_c.corner_radius_bottom_right = 12
		btn_cuota.add_theme_stylebox_override("normal", st_c)
		btn_cuota.pressed.connect(func(): _pagar_cuota_diaria_nequi())
		vbox.add_child(btn_cuota)

		# Botón Pagar Deuda Total
		var btn_total = Button.new()
		btn_total.text = "✅ LIQUIDAR DEUDA TOTAL (%s)" % _formatear_pesos_colombianos(bank_loan_balance)
		btn_total.custom_minimum_size = Vector2(0, 50)
		btn_total.add_theme_font_size_override("font_size", 17)
		btn_total.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
		var st_t = StyleBoxFlat.new()
		st_t.bg_color = NEQUI_BG_LIGHT
		st_t.border_width_left = 2; st_t.border_width_top = 2
		st_t.border_width_right = 2; st_t.border_width_bottom = 2
		st_t.border_color = NEQUI_BLUE_PRIMARY
		st_t.corner_radius_top_left = 12; st_t.corner_radius_top_right = 12
		st_t.corner_radius_bottom_left = 12; st_t.corner_radius_bottom_right = 12
		btn_total.add_theme_stylebox_override("normal", st_t)
		btn_total.pressed.connect(func(): _pagar_totalidad_prestamo_nequi())
		vbox.add_child(btn_total)
	else:
		# Selector de Plazo en Días Reales (5, 10, 15, 30 días)
		var lbl_plazo = Label.new()
		lbl_plazo.text = "1. Selecciona el plazo de pago (en días reales):"
		lbl_plazo.add_theme_font_size_override("font_size", 16)
		lbl_plazo.add_theme_color_override("font_color", NEQUI_TEXT_DARK)
		vbox.add_child(lbl_plazo)

		var hbox_plazos = HBoxContainer.new()
		hbox_plazos.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox_plazos)

		for d_opt in [5, 10, 15, 30]:
			var b_plazo = Button.new()
			b_plazo.text = "%d Días" % d_opt
			b_plazo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b_plazo.custom_minimum_size = Vector2(0, 42)
			b_plazo.add_theme_font_size_override("font_size", 15)
			var st_p = StyleBoxFlat.new()
			st_p.corner_radius_top_left = 10; st_p.corner_radius_top_right = 10
			st_p.corner_radius_bottom_left = 10; st_p.corner_radius_bottom_right = 10
			if _plazo_seleccionado_dias == d_opt:
				st_p.bg_color = NEQUI_BLUE_PRIMARY
				b_plazo.add_theme_color_override("font_color", Color.WHITE)
			else:
				st_p.bg_color = NEQUI_BG_LIGHT
				st_p.border_width_left = 1; st_p.border_width_top = 1
				st_p.border_width_right = 1; st_p.border_width_bottom = 1
				st_p.border_color = NEQUI_BORDER_SOFT
				b_plazo.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
			b_plazo.add_theme_stylebox_override("normal", st_p)
			var d_val = d_opt
			b_plazo.pressed.connect(func():
				_plazo_seleccionado_dias = d_val
				_switch_bank_tab("prestamo")
			)
			hbox_plazos.add_child(b_plazo)

		var lbl_monto = Label.new()
		lbl_monto.text = "2. Elige el monto a desembolsar (Cupo máximo actual: %s):" % _formatear_pesos_colombianos(cupo_max)
		lbl_monto.add_theme_font_size_override("font_size", 16)
		lbl_monto.add_theme_color_override("font_color", NEQUI_TEXT_DARK)
		vbox.add_child(lbl_monto)

		var montos_candidatos: Array[float] = [50000.0, 100000.0, 250000.0, 500000.0, 1000000.0, 2500000.0]
		for m_val in montos_candidatos:
			if m_val > cupo_max and m_val > 100000.0:
				continue
			var habilitado: bool = (m_val <= cupo_max)
			var cuota_calc: float = round(m_val / float(_plazo_seleccionado_dias))
			var btn = Button.new()
			btn.disabled = not habilitado
			btn.text = "Pedir %s  ➔  Cuota: %s / día (%d días)" % [
				_formatear_pesos_colombianos(m_val),
				_formatear_pesos_colombianos(cuota_calc),
				_plazo_seleccionado_dias
			]
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 52)
			btn.add_theme_font_size_override("font_size", 17)
			btn.add_theme_color_override("font_color", Color.WHITE if habilitado else NEQUI_TEXT_MUTED)

			var st = StyleBoxFlat.new()
			st.bg_color = NEQUI_BLUE_PRIMARY if habilitado else NEQUI_BG_LIGHT
			st.corner_radius_top_left = 12; st.corner_radius_top_right = 12
			st.corner_radius_bottom_left = 12; st.corner_radius_bottom_right = 12
			btn.add_theme_stylebox_override("normal", st)

			var monto_elegido = m_val
			btn.pressed.connect(func():
				_solicitar_prestamo_nequi(monto_elegido, _plazo_seleccionado_dias)
			)
			vbox.add_child(btn)

func _solicitar_prestamo_nequi(monto: float, dias: int) -> void:
	if nequi_loan_state.get("activo", false) or bank_loan_balance > 0.0:
		notificar("Ya tienes un préstamo activo en curso.", "alerta")
		return

	var cupo: float = _calcular_cupo_maximo_nequi()
	if monto > cupo:
		notificar("El monto supera tu cupo disponible actual (%s)." % _formatear_pesos_colombianos(cupo), "alerta")
		return

	var cuota_d: float = round(monto / float(max(dias, 1)))
	var hoy: int = _obtener_dia_real_actual()

	nequi_loan_state["activo"] = true
	nequi_loan_state["monto_original"] = monto
	nequi_loan_state["saldo_pendiente"] = monto
	nequi_loan_state["plazo_dias"] = dias
	nequi_loan_state["cuota_diaria"] = cuota_d
	nequi_loan_state["cuotas_pagadas"] = 0
	nequi_loan_state["dia_real_inicio"] = hoy
	nequi_loan_state["ultimo_dia_pago"] = -1
	nequi_loan_state["ultimo_dia_evaluado"] = hoy
	nequi_loan_state["dias_mora_actuales"] = 0

	bank_loan_balance = monto
	if DatosUsuario:
		DatosUsuario.dinero += monto
		if DatosUsuario.has_method("save_local"):
			DatosUsuario.save_local()

	registrar_movimiento_nequi("in", "Desembolso Libre Inversión (%d días)" % dias, monto)
	_setup_app_bank(null)
	notificar("¡Desembolso exitoso de %s! Cuota diaria: %s durante %d días." % [
		_formatear_pesos_colombianos(monto),
		_formatear_pesos_colombianos(cuota_d),
		dias
	], "exito")

func _pagar_cuota_diaria_nequi() -> void:
	if not nequi_loan_state.get("activo", false) or bank_loan_balance <= 0.0:
		notificar("No tienes cuotas pendientes.", "info")
		return

	var cuota_d: float = minf(float(nequi_loan_state.get("cuota_diaria", 10000.0)), bank_loan_balance)
	if not DatosUsuario or DatosUsuario.dinero < cuota_d:
		notificar("Saldo insuficiente en tu cuenta para pagar la cuota de %s." % _formatear_pesos_colombianos(cuota_d), "alerta")
		return

	DatosUsuario.dinero -= cuota_d
	bank_loan_balance = maxf(0.0, bank_loan_balance - cuota_d)
	nequi_loan_state["saldo_pendiente"] = bank_loan_balance
	nequi_loan_state["cuotas_pagadas"] = int(nequi_loan_state.get("cuotas_pagadas", 0)) + 1
	nequi_loan_state["ultimo_dia_pago"] = _obtener_dia_real_actual()

	# Si tenía días de mora actuales, cada cuota pagada descuenta mora y mejora el score
	var mora_act: int = int(nequi_loan_state.get("dias_mora_actuales", 0))
	if mora_act > 0:
		nequi_loan_state["dias_mora_actuales"] = max(0, mora_act - 1)
	nequi_loan_state["score_financiero"] = clampi(int(nequi_loan_state.get("score_financiero", 550)) + 18, 300, 850)

	if bank_loan_balance <= 1.0 or int(nequi_loan_state.get("cuotas_pagadas", 0)) >= int(nequi_loan_state.get("plazo_dias", 10)):
		bank_loan_balance = 0.0
		nequi_loan_state["activo"] = false
		nequi_loan_state["saldo_pendiente"] = 0.0
		nequi_loan_state["dias_mora_actuales"] = 0
		nequi_loan_state["score_financiero"] = clampi(int(nequi_loan_state.get("score_financiero", 550)) + 45, 300, 850)
		notificar("🎉 ¡Préstamo pagado por completo! Tu Score Financiero y cupo han subido.", "exito")
	else:
		notificar("✅ Cuota diaria pagada (%s). ¡Tu historial financiero mejora!" % _formatear_pesos_colombianos(cuota_d), "exito")

	if DatosUsuario.has_method("save_local"):
		DatosUsuario.save_local()
	registrar_movimiento_nequi("out", "Pago Cuota Diaria Préstamo", cuota_d)
	_setup_app_bank(null)

func _pagar_totalidad_prestamo_nequi() -> void:
	if not nequi_loan_state.get("activo", false) or bank_loan_balance <= 0.0:
		return
	if not DatosUsuario or DatosUsuario.dinero < bank_loan_balance:
		notificar("No tienes saldo suficiente para liquidar %s." % _formatear_pesos_colombianos(bank_loan_balance), "alerta")
		return

	var total_pagado: float = bank_loan_balance
	DatosUsuario.dinero -= total_pagado
	bank_loan_balance = 0.0
	nequi_loan_state["activo"] = false
	nequi_loan_state["saldo_pendiente"] = 0.0
	nequi_loan_state["dias_mora_actuales"] = 0
	nequi_loan_state["score_financiero"] = clampi(int(nequi_loan_state.get("score_financiero", 550)) + 60, 300, 850)

	if DatosUsuario.has_method("save_local"):
		DatosUsuario.save_local()
	registrar_movimiento_nequi("out", "Liquidación Total de Préstamo", total_pagado)
	_setup_app_bank(null)
	notificar("🎉 ¡Liquidaste la totalidad de tu préstamo! Cupo crediticio ampliado.", "exito")

func _build_bank_tab_inversion(parent: Control) -> void:
	# Pestaña de Mejoramiento de la Situación Financiera y Bolsillo de Ahorro
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "📈 MEJORAMIENTO DE SITUACIÓN FINANCIERA"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	vbox.add_child(title)

	var score_act: int = int(nequi_loan_state.get("score_financiero", 550))
	var mora_hist: int = int(nequi_loan_state.get("dias_mora_historicos", 0))
	var cupo_act: float = _calcular_cupo_maximo_nequi()

	var desc = Label.new()
	desc.text = "Score actual: %d / 850 pts  |  Días de mora históricos: %d  |  Cupo actual: %s
Limpia tu historial de mora o ahorra en tu Colchón Financiero para desbloquear préstamos de hasta $ 3.500.000." % [
		score_act, mora_hist, _formatear_pesos_colombianos(cupo_act)
	]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", NEQUI_TEXT_DARK)
	vbox.add_child(desc)

	# Botón de Saneamiento de Mora (Rehabilitación Financiera)
	var btn_sanear = Button.new()
	var costo_saneamiento: float = maxf(float(mora_hist) * 15000.0, 25000.0)
	btn_sanear.text = "🛡️ Plan de Rehabilitación Crediticia (%s)" % _formatear_pesos_colombianos(costo_saneamiento)
	btn_sanear.custom_minimum_size = Vector2(0, 52)
	btn_sanear.add_theme_font_size_override("font_size", 17)
	btn_sanear.add_theme_color_override("font_color", Color.WHITE)
	var st_s = StyleBoxFlat.new()
	st_s.bg_color = NEQUI_BLUE_PRIMARY
	st_s.corner_radius_top_left = 12; st_s.corner_radius_top_right = 12
	st_s.corner_radius_bottom_left = 12; st_s.corner_radius_bottom_right = 12
	btn_sanear.add_theme_stylebox_override("normal", st_s)
	btn_sanear.pressed.connect(func():
		if not DatosUsuario or DatosUsuario.dinero < costo_saneamiento:
			notificar("Necesitas %s para ejecutar el plan de saneamiento." % _formatear_pesos_colombianos(costo_saneamiento), "alerta")
			return
		DatosUsuario.dinero -= costo_saneamiento
		nequi_loan_state["dias_mora_historicos"] = 0
		nequi_loan_state["dias_mora_actuales"] = 0
		nequi_loan_state["score_financiero"] = clampi(int(nequi_loan_state.get("score_financiero", 550)) + 85, 300, 850)
		if DatosUsuario.has_method("save_local"):
			DatosUsuario.save_local()
		registrar_movimiento_nequi("out", "Plan de Mejoramiento Financiero", costo_saneamiento)
		_setup_app_bank(null)
		_switch_bank_tab("inversion")
		notificar("¡Historial de mora saneado! Tu Score y cupo crediticio han subido.", "exito")
	)
	vbox.add_child(btn_sanear)

	# Colchón de Ahorro Banco
	var lbl_colchon = Label.new()
	lbl_colchon.text = "💰 Colchón de Ahorro Banco: %s" % _formatear_pesos_colombianos(bank_investment_balance)
	lbl_colchon.add_theme_font_size_override("font_size", 17)
	lbl_colchon.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	vbox.add_child(lbl_colchon)

	var btn_ahorrar = Button.new()
	btn_ahorrar.text = "➕ Guardar $ 50.000 en el Colchón (+20 Score)"
	btn_ahorrar.custom_minimum_size = Vector2(0, 48)
	btn_ahorrar.add_theme_font_size_override("font_size", 16)
	btn_ahorrar.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
	var st_a = StyleBoxFlat.new()
	st_a.bg_color = NEQUI_BG_LIGHT
	st_a.border_width_left = 1; st_a.border_width_top = 1
	st_a.border_width_right = 1; st_a.border_width_bottom = 1
	st_a.border_color = NEQUI_BLUE_PRIMARY
	st_a.corner_radius_top_left = 10; st_a.corner_radius_top_right = 10
	st_a.corner_radius_bottom_left = 10; st_a.corner_radius_bottom_right = 10
	btn_ahorrar.add_theme_stylebox_override("normal", st_a)
	btn_ahorrar.pressed.connect(func():
		if DatosUsuario and DatosUsuario.dinero >= 50000.0:
			DatosUsuario.dinero -= 50000.0
			bank_investment_balance += 50000.0
			nequi_loan_state["score_financiero"] = clampi(int(nequi_loan_state.get("score_financiero", 550)) + 20, 300, 850)
			if DatosUsuario.has_method("save_local"):
				DatosUsuario.save_local()
			registrar_movimiento_nequi("out", "Depósito a Colchón Banco", 50000.0)
			_setup_app_bank(null)
			_switch_bank_tab("inversion")
			notificar("Guardaste $ 50.000 en tu Colchón (+20 pts de Score).", "exito")
		else:
			notificar("Saldo insuficiente para guardar en el Colchón.", "alerta")
	)
	vbox.add_child(btn_ahorrar)

	if bank_investment_balance > 0.0:
		var btn_retirar = Button.new()
		btn_retirar.text = "↩️ Retirar Todo del Colchón (%s)" % _formatear_pesos_colombianos(bank_investment_balance)
		btn_retirar.custom_minimum_size = Vector2(0, 46)
		btn_retirar.add_theme_font_size_override("font_size", 15)
		btn_retirar.add_theme_color_override("font_color", Color.WHITE)
		btn_retirar.add_theme_stylebox_override("normal", st_s)
		btn_retirar.pressed.connect(func():
			var monto_ret = bank_investment_balance
			bank_investment_balance = 0.0
			if DatosUsuario:
				DatosUsuario.dinero += monto_ret
				if DatosUsuario.has_method("save_local"):
					DatosUsuario.save_local()
			registrar_movimiento_nequi("in", "Retiro desde Colchón Banco", monto_ret)
			_setup_app_bank(null)
			_switch_bank_tab("inversion")
			notificar("Retiraste %s a tu saldo disponible." % _formatear_pesos_colombianos(monto_ret), "exito")
		)
		vbox.add_child(btn_retirar)

func _build_bank_tab_cambio(parent: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	parent.add_child(vbox)

	var title = Label.new()
	title.text = "💎 CANJE DE ESMERALDAS A SALDO BANCO"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	vbox.add_child(title)

	var packs = [
		[1, 25000.0, "💎 1 Esmeralda  ➔  $ 25.000"],
		[5, 140000.0, "💎 5 Esmeraldas  ➔  $ 140.000"],
		[15, 450000.0, "💎 15 Esmeraldas  ➔  $ 450.000"]
	]
	for pk in packs:
		var b = Button.new()
		b.text = pk[2]
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Color.WHITE)
		var st = StyleBoxFlat.new()
		st.bg_color = NEQUI_BLUE_PRIMARY
		st.corner_radius_top_left = 12; st.corner_radius_top_right = 12
		st.corner_radius_bottom_left = 12; st.corner_radius_bottom_right = 12
		b.add_theme_stylebox_override("normal", st)
		var req_e: int = pk[0]
		var recomp: float = pk[1]
		b.pressed.connect(func():
			if DatosUsuario and DatosUsuario.esmeraldas >= req_e:
				DatosUsuario.esmeraldas -= req_e
				DatosUsuario.dinero += recomp
				if DatosUsuario.has_method("save_local"):
					DatosUsuario.save_local()
				registrar_movimiento_nequi("in", "Canje de %d Esmeralda(s)" % req_e, recomp)
				_update_bank_display()
				notificar("¡Canje exitoso! Se abonaron %s a tu cuenta." % _formatear_pesos_colombianos(recomp), "exito")
			else:
				notificar("No tienes suficientes Esmeraldas para este canje.", "alerta")
		)
		vbox.add_child(b)

func _build_bank_tab_historial(parent: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	parent.add_child(vbox)

	var title = Label.new()
	title.text = "📜 MOVIMIENTOS Y TRANSACCIONES"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	vbox.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var h_vbox = VBoxContainer.new()
	h_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(h_vbox)

	for item in bank_transactions:
		var card_p = PanelContainer.new()
		var card_st = StyleBoxFlat.new()
		card_st.bg_color = NEQUI_BG_LIGHT
		card_st.border_width_left = 1; card_st.border_width_top = 1
		card_st.border_width_right = 1; card_st.border_width_bottom = 1
		card_st.border_color = NEQUI_BORDER_SOFT
		card_st.corner_radius_top_left = 10; card_st.corner_radius_top_right = 10
		card_st.corner_radius_bottom_left = 10; card_st.corner_radius_bottom_right = 10
		card_p.add_theme_stylebox_override("panel", card_st)

		var card_m = MarginContainer.new()
		card_m.add_theme_constant_override("margin_left", 14)
		card_m.add_theme_constant_override("margin_right", 14)
		card_m.add_theme_constant_override("margin_top", 8)
		card_m.add_theme_constant_override("margin_bottom", 8)
		card_p.add_child(card_m)

		var row_h = HBoxContainer.new()
		card_m.add_child(row_h)

		var is_in: bool = (item.get("type", "in") == "in")
		var desc_lbl = Label.new()
		var fecha_str: String = str(item.get("date", ""))
		desc_lbl.text = ( "⬆️ " if is_in else "⬇️ " ) + str(item.get("desc", "Movimiento")) + ("  •  " + fecha_str if fecha_str != "" else "")
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", NEQUI_TEXT_DARK)
		row_h.add_child(desc_lbl)

		var amt_lbl = Label.new()
		var sign_str: String = "+ " if is_in else "- "
		amt_lbl.text = sign_str + _formatear_pesos_colombianos(float(item.get("amount", 0)))
		amt_lbl.add_theme_font_size_override("font_size", 17)
		amt_lbl.add_theme_color_override("font_color", Color(0.08, 0.62, 0.32) if is_in else NEQUI_BLUE_PRIMARY)
		row_h.add_child(amt_lbl)

		h_vbox.add_child(card_p)

func _update_bank_display() -> void:
	if DatosUsuario:
		if bank_money_label:
			bank_money_label.text = _formatear_pesos_colombianos(DatosUsuario.dinero)
		if bank_emeralds_label:
			bank_emeralds_label.text = "💎 " + str(DatosUsuario.esmeraldas) + " Esmeraldas"

	if is_instance_valid(bank_loan_label):
		bank_loan_label.text = _formatear_pesos_colombianos(bank_loan_balance)
	if is_instance_valid(_bank_cupo_label):
		_bank_cupo_label.text = _formatear_pesos_colombianos(_calcular_cupo_maximo_nequi())
	if is_instance_valid(_bank_score_label):
		_bank_score_label.text = "%d / 850 pts" % int(nequi_loan_state.get("score_financiero", 550))
	if is_instance_valid(_bank_mora_label):
		var m_act: int = int(nequi_loan_state.get("dias_mora_actuales", 0))
		_bank_mora_label.text = ("%d día(s) en mora" % m_act) if m_act > 0 else "Al día (0 mora)"

func _formatear_pesos_colombianos(valor: float) -> String:
	var entero = int(round(absf(valor)))
	var texto = str(entero)
	var longitud = texto.length()
	var formateado = ""

	for i in range(longitud):
		var pos_desde_derecha = longitud - 1 - i
		formateado = texto[pos_desde_derecha] + formateado
		if i < longitud - 1 and (i + 1) % 3 == 0:
			formateado = "." + formateado

	return "$ " + formateado

# ═════════════════════════════════════════════════════════════════════════════
#  APP INDEPENDIENTE: FLETES NT (CARGA PESADA Y LOGÍSTICA C1 / C2 / C3)
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_fletes(_parent: Control) -> void:
	if not app_container_fletes:
		return
	for child in app_container_fletes.get_children():
		child.queue_free()

	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_st = StyleBoxFlat.new()
	bg_st.bg_color = NEQUI_BG_LIGHT
	bg_st.corner_radius_top_left = 20; bg_st.corner_radius_top_right = 20
	bg_st.corner_radius_bottom_left = 20; bg_st.corner_radius_bottom_right = 20
	bg.add_theme_stylebox_override("panel", bg_st)
	app_container_fletes.add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	app_container_fletes.add_child(root)

	var hdr = _make_app_header("Fletes NT 🚛", NEQUI_BLUE_PRIMARY, "⬅ Inicio", func(): _switch_app("home"))
	root.add_child(hdr)

	var margin = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 14)
	root.add_child(margin)

	var main_v = VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 10)
	margin.add_child(main_v)

	# Barra de estado de licencias del conductor (C1, C2, C3)
	var lic_bar = PanelContainer.new()
	var lb_st = StyleBoxFlat.new()
	lb_st.bg_color = NEQUI_CARD_WHITE
	lb_st.border_width_left = 1; lb_st.border_width_top = 1
	lb_st.border_width_right = 1; lb_st.border_width_bottom = 1
	lb_st.border_color = NEQUI_BORDER_SOFT
	lb_st.corner_radius_top_left = 12; lb_st.corner_radius_top_right = 12
	lb_st.corner_radius_bottom_left = 12; lb_st.corner_radius_bottom_right = 12
	lb_st.content_margin_left = 14; lb_st.content_margin_right = 14
	lb_st.content_margin_top = 8; lb_st.content_margin_bottom = 8
	lic_bar.add_theme_stylebox_override("panel", lb_st)

	var lic_h = HBoxContainer.new()
	lic_bar.add_child(lic_h)

	var tiene_c1: bool = DatosUsuario.tiene_licencia("C1") if (DatosUsuario and DatosUsuario.has_method("tiene_licencia")) else false
	var tiene_c2: bool = DatosUsuario.tiene_licencia("C2") if (DatosUsuario and DatosUsuario.has_method("tiene_licencia")) else false
	var tiene_c3: bool = DatosUsuario.tiene_licencia("C3") if (DatosUsuario and DatosUsuario.has_method("tiene_licencia")) else false

	var lic_lbl = Label.new()
	lic_lbl.text = "🪪 Tus Licencias:   [C1 Camionetas: %s]   [C2 Rígidos: %s]   [C3 Tractomula: %s]" % [
		"✅" if tiene_c1 else "🎓 Tutorial C1",
		"✅" if tiene_c2 else "🔒 Academia",
		"✅" if tiene_c3 else "🔒 Academia"
	]
	lic_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lic_lbl.add_theme_font_size_override("font_size", 15)
	lic_lbl.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	lic_h.add_child(lic_lbl)

	var btn_ref = Button.new()
	btn_ref.text = "🔄 Actualizar Bolsa"
	btn_ref.custom_minimum_size = Vector2(150, 34)
	btn_ref.add_theme_font_size_override("font_size", 14)
	btn_ref.add_theme_color_override("font_color", Color.WHITE)
	var st_r = StyleBoxFlat.new()
	st_r.bg_color = NEQUI_BLUE_PRIMARY
	st_r.corner_radius_top_left = 8; st_r.corner_radius_top_right = 8
	st_r.corner_radius_bottom_left = 8; st_r.corner_radius_bottom_right = 8
	btn_ref.add_theme_stylebox_override("normal", st_r)
	btn_ref.pressed.connect(func():
		var sf = get_tree().get_first_node_in_group("sistema_fletes") if get_tree() else null
		if not sf and SistemaFletesPesados.instance:
			sf = SistemaFletesPesados.instance
		if sf and sf.has_method("generar_bolsa_de_fletes"):
			sf.call("generar_bolsa_de_fletes")
		_setup_app_fletes(null)
	)
	lic_h.add_child(btn_ref)
	main_v.add_child(lic_bar)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_v.add_child(scroll)

	var list_v = VBoxContainer.new()
	list_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_v.add_theme_constant_override("separation", 10)
	scroll.add_child(list_v)

	var sist_fletes = get_tree().get_first_node_in_group("sistema_fletes") if get_tree() else null
	if not sist_fletes and SistemaFletesPesados.instance:
		sist_fletes = SistemaFletesPesados.instance
	if not sist_fletes:
		sist_fletes = get_node_or_null("SistemaFletesPesados")
	if not sist_fletes:
		sist_fletes = SistemaFletesPesados.new()
		sist_fletes.name = "SistemaFletesPesados"
		add_child(sist_fletes)

	var flete_act: Dictionary = sist_fletes.obtener_flete_activo() if sist_fletes.has_method("obtener_flete_activo") else {}
	if not flete_act.is_empty():
		var act_card = _crear_tarjeta_flete_ui(flete_act, true, sist_fletes)
		list_v.add_child(act_card)

	var disponibles: Array = sist_fletes.obtener_fletes_disponibles() if sist_fletes.has_method("obtener_fletes_disponibles") else []
	for f in disponibles:
		list_v.add_child(_crear_tarjeta_flete_ui(f, false, sist_fletes))

func _crear_tarjeta_flete_ui(flete: Dictionary, es_activo: bool, gestor: Node) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st = StyleBoxFlat.new()
	st.bg_color = NEQUI_CARD_WHITE
	st.border_width_left = 2; st.border_width_top = 2
	st.border_width_right = 2; st.border_width_bottom = 2
	st.border_color = Color(0.12, 0.72, 0.38) if es_activo else NEQUI_BORDER_SOFT
	st.corner_radius_top_left = 14; st.corner_radius_top_right = 14
	st.corner_radius_bottom_left = 14; st.corner_radius_bottom_right = 14
	st.content_margin_left = 16; st.content_margin_right = 16
	st.content_margin_top = 12; st.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var top_h = HBoxContainer.new()
	vb.add_child(top_h)

	var cat_lic: String = str(flete.get("licencia_requerida", "C3"))
	var tit = Label.new()
	tit.text = ("🟢 [EN CURSO] " if es_activo else "") + "[Lic. %s]  %s" % [cat_lic, str(flete.get("titulo", "Flete"))]
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tit.add_theme_font_size_override("font_size", 18)
	tit.add_theme_color_override("font_color", NEQUI_BLUE_DEEP)
	top_h.add_child(tit)

	var pago_lbl = Label.new()
	var monto_p: float = float(flete.get("pago_cop", 2500000.0))
	pago_lbl.text = _formatear_pesos_colombianos(monto_p)
	pago_lbl.add_theme_font_size_override("font_size", 20)
	pago_lbl.add_theme_color_override("font_color", NEQUI_BLUE_PRIMARY)
	top_h.add_child(pago_lbl)

	var ruta_lbl = Label.new()
	ruta_lbl.text = "📍 Origen: %s   ➔   🏁 Destino: %s  (%.1f km)  |  %s" % [
		str(flete.get("origen_nombre", "Fusagasugá")),
		str(flete.get("destino_nombre", "Silvania")),
		float(flete.get("distancia_km", 10.0)),
		str(flete.get("remolque_requerido", "Tráiler"))
	]
	ruta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ruta_lbl.add_theme_font_size_override("font_size", 14)
	ruta_lbl.add_theme_color_override("font_color", NEQUI_TEXT_MUTED)
	vb.add_child(ruta_lbl)

	var btn_h = HBoxContainer.new()
	btn_h.add_theme_constant_override("separation", 10)
	vb.add_child(btn_h)

	if es_activo:
		var btn_gps = Button.new()
		btn_gps.text = "📍 Trazar Destino en Waze GPS"
		btn_gps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_gps.custom_minimum_size = Vector2(0, 40)
		btn_gps.add_theme_color_override("font_color", Color.WHITE)
		var st_g = StyleBoxFlat.new()
		st_g.bg_color = NEQUI_BLUE_PRIMARY
		st_g.corner_radius_top_left = 10; st_g.corner_radius_top_right = 10
		st_g.corner_radius_bottom_left = 10; st_g.corner_radius_bottom_right = 10
		btn_gps.add_theme_stylebox_override("normal", st_g)
		btn_gps.pressed.connect(func():
			var pos_obj: Vector3 = flete.get("destino_pos", flete.get("origen_pos", Vector3.ZERO))
			if gps_line and gps_line.has_method("set_destination"):
				gps_line.call("set_destination", pos_obj)
			_switch_app("waze")
		)
		btn_h.add_child(btn_gps)

		var btn_canc = Button.new()
		btn_canc.text = "✖ Cancelar"
		btn_canc.custom_minimum_size = Vector2(120, 40)
		btn_canc.pressed.connect(func():
			if gestor and gestor.has_method("cancelar_flete_activo"):
				gestor.call("cancelar_flete_activo")
			_setup_app_fletes(null)
		)
		btn_h.add_child(btn_canc)
	else:
		var btn_aceptar = Button.new()
		btn_aceptar.text = "🚛 Aceptar Flete (Lic. %s)" % cat_lic
		btn_aceptar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_aceptar.custom_minimum_size = Vector2(0, 40)
		btn_aceptar.add_theme_color_override("font_color", Color.WHITE)
		var st_a = StyleBoxFlat.new()
		st_a.bg_color = NEQUI_BLUE_PRIMARY
		st_a.corner_radius_top_left = 10; st_a.corner_radius_top_right = 10
		st_a.corner_radius_bottom_left = 10; st_a.corner_radius_bottom_right = 10
		btn_aceptar.add_theme_stylebox_override("normal", st_a)
		var fid: String = str(flete.get("id", ""))
		btn_aceptar.pressed.connect(func():
			if gestor and gestor.has_method("aceptar_flete"):
				if gestor.call("aceptar_flete", fid):
					_setup_app_fletes(null)
		)
		btn_h.add_child(btn_aceptar)

	return card

# ═════════════════════════════════════════════════════════════════════════════
#  APP: MUSICA — DESIGN SYSTEM V3 GLASSMORPHIC CYBER
# ═════════════════════════════════════════════════════════════════════════════
var playlist_vbox: VBoxContainer = null

func _setup_app_music(_parent: Control) -> void:
	if not app_container_music:
		return

	var bg_panel = app_container_music.get_node_or_null("BGPanel") as Panel
	if not bg_panel:
		bg_panel = Panel.new()
		bg_panel.name = "BGPanel"
		bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app_container_music.add_child(bg_panel)
		app_container_music.move_child(bg_panel, 0)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.07, 0.12, 0.98)
	bg_style.corner_radius_top_left = 20; bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20; bg_style.corner_radius_bottom_right = 20
	bg_panel.add_theme_stylebox_override("panel", bg_style)

	var root = app_container_music.get_node_or_null("RootVBox") as VBoxContainer
	if not root:
		root = VBoxContainer.new()
		root.name = "RootVBox"
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_theme_constant_override("separation", 0)
		app_container_music.add_child(root)

	var header = root.get_node_or_null("Header") as MarginContainer
	if not header:
		header = MarginContainer.new()
		header.name = "Header"
		header.custom_minimum_size = Vector2(0, 62)
		root.add_child(header)

	var header_hbox = header.get_node_or_null("HBox") as HBoxContainer
	if not header_hbox:
		header_hbox = HBoxContainer.new()
		header_hbox.name = "HBox"
		header.add_child(header_hbox)

	var back = header_hbox.get_node_or_null("BackButton") as Button
	if back:
		back.visible = false

	var title_lbl = header_hbox.get_node_or_null("TitleLabel") as Label
	if not title_lbl:
		title_lbl = Label.new()
		title_lbl.name = "TitleLabel"
		header_hbox.add_child(title_lbl)

	title_lbl.text = "MUSICA 🎵"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.75, 0.45, 1.0))

	header.add_theme_constant_override("margin_top", 16)
	header.add_theme_constant_override("margin_bottom", 6)
	header.add_theme_constant_override("margin_left", 20)
	header.add_theme_constant_override("margin_right", 20)

	var content_margin = root.get_node_or_null("ContentMargin") as MarginContainer
	if not content_margin:
		content_margin = MarginContainer.new()
		content_margin.name = "ContentMargin"
		content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(content_margin)

	var old_content_vbox = content_margin.get_node_or_null("ContentVBox") as VBoxContainer
	if old_content_vbox:
		old_content_vbox.queue_free()

	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_bottom", 16)

	# Estructura WIDESCREEN TABLET: 2 COLUMNAS (MainHBox)
	var main_hbox = content_margin.get_node_or_null("MainHBox") as HBoxContainer
	if not main_hbox:
		main_hbox = HBoxContainer.new()
		main_hbox.name = "MainHBox"
		main_hbox.add_theme_constant_override("separation", 24)
		main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margin.add_child(main_hbox)

	# Columna Izquierda: Reproductor Principal (~45% ancho)
	var left_vbox = main_hbox.get_node_or_null("LeftVBox") as VBoxContainer
	if not left_vbox:
		left_vbox = VBoxContainer.new()
		left_vbox.name = "LeftVBox"
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vbox.size_flags_stretch_ratio = 0.90
		left_vbox.add_theme_constant_override("separation", 12)
		main_hbox.add_child(left_vbox)

	# Columna Derecha: Playlist + Audifonos (~55% ancho)
	var right_vbox = main_hbox.get_node_or_null("RightVBox") as VBoxContainer
	if not right_vbox:
		right_vbox = VBoxContainer.new()
		right_vbox.name = "RightVBox"
		right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.size_flags_stretch_ratio = 1.10
		right_vbox.add_theme_constant_override("separation", 12)
		main_hbox.add_child(right_vbox)

	# ─── COLUMNA IZQUIERDA: TARJETA DE REPRODUCTOR PRINCIPAL ───

	# 1. Carátula / Equalizer Box (`cover`)
	var cover = left_vbox.get_node_or_null("CoverCard") as Panel
	if not cover:
		cover = Panel.new()
		cover.name = "CoverCard"
		cover.custom_minimum_size = Vector2(0, 160)
		left_vbox.add_child(cover)

	var cov_st = StyleBoxFlat.new()
	cov_st.bg_color = Color(0.09, 0.10, 0.16, 0.95)
	cov_st.corner_radius_top_left = 22; cov_st.corner_radius_top_right = 22
	cov_st.corner_radius_bottom_left = 22; cov_st.corner_radius_bottom_right = 22
	cov_st.border_width_left = 2; cov_st.border_width_top = 2
	cov_st.border_width_right = 2; cov_st.border_width_bottom = 2
	cov_st.border_color = Color(0.55, 0.25, 1.00, 0.85)
	cov_st.shadow_color = Color(0.55, 0.25, 1.00, 0.25)
	cov_st.shadow_size = 20
	cov_st.shadow_offset = Vector2(0, 6)
	cover.add_theme_stylebox_override("panel", cov_st)

	var center_viz = cover.get_node_or_null("CenterViz") as CenterContainer
	if not center_viz:
		center_viz = CenterContainer.new()
		center_viz.name = "CenterViz"
		center_viz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cover.add_child(center_viz)

	var viz_hbox = center_viz.get_node_or_null("VizHBox") as HBoxContainer
	if not viz_hbox:
		viz_hbox = HBoxContainer.new()
		viz_hbox.name = "VizHBox"
		viz_hbox.add_theme_constant_override("separation", 8)
		center_viz.add_child(viz_hbox)

	# Equalizer 16 Bars
	for child in viz_hbox.get_children():
		child.queue_free()
	visualizer_bars.clear()
	for i in range(16):
		var bar = Panel.new()
		bar.custom_minimum_size = Vector2(10, 24)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var bar_style = StyleBoxFlat.new()
		var ratio = float(i) / 15.0
		bar_style.bg_color = Color(1.0, 0.45, 0.10).lerp(Color(0.65, 0.25, 1.00), ratio)
		bar_style.corner_radius_top_left = 4; bar_style.corner_radius_top_right = 4
		bar_style.corner_radius_bottom_left = 4; bar_style.corner_radius_bottom_right = 4
		bar.add_theme_stylebox_override("panel", bar_style)
		
		viz_hbox.add_child(bar)
		visualizer_bars.append(bar)

	# 2. Track & Artist Labels
	music_track_label = left_vbox.get_node_or_null("TrackLabel") as Label
	if not music_track_label:
		music_track_label = Label.new()
		music_track_label.name = "TrackLabel"
		left_vbox.add_child(music_track_label)

	music_track_label.add_theme_font_size_override("font_size", 30)
	music_track_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	music_track_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	music_track_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	music_track_label.clip_text = true

	music_artist_label = left_vbox.get_node_or_null("ArtistLabel") as Label
	if not music_artist_label:
		music_artist_label = Label.new()
		music_artist_label.name = "ArtistLabel"
		left_vbox.add_child(music_artist_label)

	music_artist_label.add_theme_font_size_override("font_size", 20)
	music_artist_label.add_theme_color_override("font_color", Color(0.40, 0.75, 1.00))
	music_artist_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	music_artist_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	music_artist_label.clip_text = true

	# 3. High tech Progress Bar & Time Labels
	music_progress_bar = left_vbox.get_node_or_null("ProgressBar") as ProgressBar
	if not music_progress_bar:
		music_progress_bar = ProgressBar.new()
		music_progress_bar.name = "ProgressBar"
		music_progress_bar.show_percentage = false
		left_vbox.add_child(music_progress_bar)

	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.14, 0.16, 0.24, 0.9)
	pb_bg.corner_radius_top_left = 6; pb_bg.corner_radius_top_right = 6
	pb_bg.corner_radius_bottom_left = 6; pb_bg.corner_radius_bottom_right = 6
	var pb_fg = StyleBoxFlat.new()
	pb_fg.bg_color = Color(0.60, 0.30, 1.00, 1.0)
	pb_fg.corner_radius_top_left = 6; pb_fg.corner_radius_top_right = 6
	pb_fg.corner_radius_bottom_left = 6; pb_fg.corner_radius_bottom_right = 6
	music_progress_bar.custom_minimum_size = Vector2(0, 12)
	music_progress_bar.add_theme_stylebox_override("background", pb_bg)
	music_progress_bar.add_theme_stylebox_override("fill", pb_fg)

	var time_hbox = left_vbox.get_node_or_null("TimeHBox") as HBoxContainer
	if not time_hbox:
		time_hbox = HBoxContainer.new()
		time_hbox.name = "TimeHBox"
		left_vbox.add_child(time_hbox)

	t_start = time_hbox.get_node_or_null("StartLabel") as Label
	if not t_start:
		t_start = Label.new()
		t_start.name = "StartLabel"
		t_start.text = "0:00"
		time_hbox.add_child(t_start)

	var time_fill = Control.new()
	time_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_hbox.add_child(time_fill)

	t_end = time_hbox.get_node_or_null("EndLabel") as Label
	if not t_end:
		t_end = Label.new()
		t_end.name = "EndLabel"
		t_end.text = "0:00"
		time_hbox.add_child(t_end)

	t_start.add_theme_font_size_override("font_size", 18)
	t_start.add_theme_color_override("font_color", Color(0.70, 0.72, 0.82))
	t_end.add_theme_font_size_override("font_size", 18)
	t_end.add_theme_color_override("font_color", Color(0.70, 0.72, 0.82))

	# 4. Controls HBox (Prev, Play/Pause, Next)
	var controls_center = left_vbox.get_node_or_null("ControlsCenter") as CenterContainer
	if not controls_center:
		controls_center = CenterContainer.new()
		controls_center.name = "ControlsCenter"
		left_vbox.add_child(controls_center)

	var controls_hbox = controls_center.get_node_or_null("ControlsHBox") as HBoxContainer
	if not controls_hbox:
		controls_hbox = HBoxContainer.new()
		controls_hbox.name = "ControlsHBox"
		controls_hbox.add_theme_constant_override("separation", 24)
		controls_center.add_child(controls_hbox)

	var prev_btn = controls_hbox.get_node_or_null("PrevButton") as Button
	if not prev_btn:
		prev_btn = Button.new()
		prev_btn.name = "PrevButton"
		controls_hbox.add_child(prev_btn)

	prev_btn.flat = true
	prev_btn.custom_minimum_size = Vector2(64, 64)
	_configure_music_btn_png(prev_btn, "res://recursos/botones/play.png", func():
		var prev_idx = current_track_idx - 1
		if prev_idx < 0:
			prev_idx = music_tracks.size() - 1
		_load_track(prev_idx)
	, true)

	play_btn = controls_hbox.get_node_or_null("PlayPauseButton") as Button
	if not play_btn:
		play_btn = Button.new()
		play_btn.name = "PlayPauseButton"
		controls_hbox.add_child(play_btn)

	play_btn.flat = true
	play_btn.custom_minimum_size = Vector2(80, 80)
	play_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	play_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	play_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	play_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	for conn in play_btn.pressed.get_connections():
		play_btn.pressed.disconnect(conn["callable"])
	play_btn.pressed.connect(_toggle_music_playback)

	play_btn_texture = play_btn.get_node_or_null("PlayTexture") as TextureRect
	if not play_btn_texture:
		play_btn_texture = TextureRect.new()
		play_btn_texture.name = "PlayTexture"
		play_btn.add_child(play_btn_texture)
	play_btn_texture.texture = load("res://recursos/botones/play.png") as Texture2D

	var mat_play = ShaderMaterial.new()
	mat_play.shader = load("res://shaders/ui/IconoBlanco.gdshader") as Shader
	mat_play.set_shader_parameter("icon_color", Color(1.0, 1.0, 1.0, 1.0))
	play_btn_texture.material = mat_play
	play_btn_texture.modulate = Color.WHITE
	play_btn_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	play_btn_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	play_btn_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_btn_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	play_btn.pivot_offset = Vector2(40, 40)
	for conn in play_btn.mouse_entered.get_connections():
		play_btn.mouse_entered.disconnect(conn["callable"])
	play_btn.mouse_entered.connect(func():
		var tw = play_btn.create_tween().set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	for conn in play_btn.mouse_exited.get_connections():
		play_btn.mouse_exited.disconnect(conn["callable"])
	play_btn.mouse_exited.connect(func():
		var tw = play_btn.create_tween().set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

	var next_btn = controls_hbox.get_node_or_null("NextButton") as Button
	if not next_btn:
		next_btn = Button.new()
		next_btn.name = "NextButton"
		controls_hbox.add_child(next_btn)

	next_btn.flat = true
	next_btn.custom_minimum_size = Vector2(64, 64)
	_configure_music_btn_png(next_btn, "res://recursos/botones/play.png", func():
		var next_idx = (current_track_idx + 1) % music_tracks.size()
		_load_track(next_idx)
	, false)

	# 5. Boton Agregar Musica Local
	var add_music_btn = left_vbox.get_node_or_null("AddMusicBtn") as Button
	if not add_music_btn:
		add_music_btn = Button.new()
		add_music_btn.name = "AddMusicBtn"
		add_music_btn.text = "➕ AGREGAR MÚSICA LOCAL (.MP3, .OGG, .WAV)"
		add_music_btn.custom_minimum_size = Vector2(0, 48)
		add_music_btn.add_theme_font_size_override("font_size", 18)
		add_music_btn.add_theme_color_override("font_color", Color.WHITE)
		
		var add_st = StyleBoxFlat.new()
		add_st.bg_color = Color(0.12, 0.16, 0.28, 0.90)
		add_st.border_width_left = 2; add_st.border_width_top = 2
		add_st.border_width_right = 2; add_st.border_width_bottom = 2
		add_st.border_color = Color(0.40, 0.75, 1.00, 0.85)
		add_st.corner_radius_top_left = 12; add_st.corner_radius_top_right = 12
		add_st.corner_radius_bottom_left = 12; add_st.corner_radius_bottom_right = 12
		add_music_btn.add_theme_stylebox_override("normal", add_st)
		
		var add_st_h = add_st.duplicate() as StyleBoxFlat
		add_st_h.bg_color = Color(0.18, 0.24, 0.40, 0.95)
		add_st_h.border_color = Color(0.50, 0.85, 1.00)
		add_music_btn.add_theme_stylebox_override("hover", add_st_h)
		add_music_btn.pressed.connect(_abrir_dialogo_agregar_musica_local)
		left_vbox.add_child(add_music_btn)

	# ─── COLUMNA DERECHA: PLAYLIST DE CANCIONES Y AUDIFONOS ───

	# 1. Contenedor Playlist
	var playlist_panel = right_vbox.get_node_or_null("PlaylistPanel") as PanelContainer
	if not playlist_panel:
		playlist_panel = PanelContainer.new()
		playlist_panel.name = "PlaylistPanel"
		playlist_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var pl_st = StyleBoxFlat.new()
		pl_st.bg_color = Color(0.07, 0.08, 0.14, 0.75)
		pl_st.corner_radius_top_left = 18; pl_st.corner_radius_top_right = 18
		pl_st.corner_radius_bottom_left = 18; pl_st.corner_radius_bottom_right = 18
		pl_st.border_width_left = 1; pl_st.border_width_top = 1
		pl_st.border_width_right = 1; pl_st.border_width_bottom = 1
		pl_st.border_color = Color(0.30, 0.20, 0.45, 0.50)
		playlist_panel.add_theme_stylebox_override("panel", pl_st)
		
		var pl_margin = MarginContainer.new()
		pl_margin.add_theme_constant_override("margin_left", 14); pl_margin.add_theme_constant_override("margin_right", 14)
		pl_margin.add_theme_constant_override("margin_top", 12); pl_margin.add_theme_constant_override("margin_bottom", 12)
		playlist_panel.add_child(pl_margin)
		
		var pl_vbox = VBoxContainer.new()
		pl_vbox.add_theme_constant_override("separation", 10)
		pl_margin.add_child(pl_vbox)
		
		var pl_title = Label.new()
		pl_title.text = "📋 LISTA DE CANCIONES"
		pl_title.add_theme_font_size_override("font_size", 20)
		pl_title.add_theme_color_override("font_color", Color(0.75, 0.45, 1.00))
		pl_vbox.add_child(pl_title)
		
		var pl_scroll = ScrollContainer.new()
		pl_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pl_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pl_vbox.add_child(pl_scroll)
		
		playlist_vbox = VBoxContainer.new()
		playlist_vbox.name = "PlaylistVBox"
		playlist_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		playlist_vbox.add_theme_constant_override("separation", 8)
		pl_scroll.add_child(playlist_vbox)
		
		right_vbox.add_child(playlist_panel)
	else:
		playlist_vbox = playlist_panel.find_child("PlaylistVBox", true, false) as VBoxContainer

	# 2. Headphones Card Dark Glass Styling
	var hp_card = right_vbox.get_node_or_null("HeadphonesCard") as PanelContainer
	if not hp_card:
		hp_card = PanelContainer.new()
		hp_card.name = "HeadphonesCard"
		
		var hp_st = StyleBoxFlat.new()
		hp_st.bg_color = Color(0.08, 0.10, 0.16, 0.90)
		hp_st.corner_radius_top_left = 18; hp_st.corner_radius_top_right = 18
		hp_st.corner_radius_bottom_left = 18; hp_st.corner_radius_bottom_right = 18
		hp_st.border_width_left = 1; hp_st.border_width_top = 1
		hp_st.border_width_right = 1; hp_st.border_width_bottom = 1
		hp_st.border_color = Color(0.20, 0.60, 1.00, 0.5)
		hp_card.add_theme_stylebox_override("panel", hp_st)
		
		var hp_m = MarginContainer.new()
		hp_m.add_theme_constant_override("margin_left", 14); hp_m.add_theme_constant_override("margin_right", 14)
		hp_m.add_theme_constant_override("margin_top", 10); hp_m.add_theme_constant_override("margin_bottom", 10)
		hp_card.add_child(hp_m)
		
		var hp_vbox = VBoxContainer.new()
		hp_vbox.add_theme_constant_override("separation", 8)
		hp_m.add_child(hp_vbox)
		
		music_headphones_warning = Label.new()
		music_headphones_warning.name = "WarningLabel"
		music_headphones_warning.add_theme_font_size_override("font_size", 16)
		hp_vbox.add_child(music_headphones_warning)
		
		music_headphones_btn = Button.new()
		music_headphones_btn.name = "TestBtn"
		music_headphones_btn.custom_minimum_size = Vector2(0, 44)
		music_headphones_btn.add_theme_font_size_override("font_size", 16)
		
		var test_btn_st = StyleBoxFlat.new()
		test_btn_st.bg_color = C_ACCENT2
		test_btn_st.corner_radius_top_left = 12; test_btn_st.corner_radius_top_right = 12
		test_btn_st.corner_radius_bottom_left = 12; test_btn_st.corner_radius_bottom_right = 12
		var test_btn_st_h = test_btn_st.duplicate() as StyleBoxFlat
		test_btn_st_h.bg_color = C_ACCENT2 * 1.15
		music_headphones_btn.add_theme_stylebox_override("normal", test_btn_st)
		music_headphones_btn.add_theme_stylebox_override("hover", test_btn_st_h)
		music_headphones_btn.add_theme_stylebox_override("pressed", test_btn_st)
		music_headphones_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		music_headphones_btn.add_theme_color_override("font_color", Color.WHITE)
		
		music_headphones_btn.pressed.connect(func():
			tiene_audifonos = !tiene_audifonos
			if DatosUsuario:
				if "tiene_audifonos" in DatosUsuario:
					DatosUsuario.tiene_audifonos = tiene_audifonos
				else:
					DatosUsuario.set("tiene_audifonos", tiene_audifonos)
			_update_music_display()
		)
		hp_vbox.add_child(music_headphones_btn)
		
		right_vbox.add_child(hp_card)

	_update_music_display()
	
	if _font:
		_apply_font_recursive(app_container_music)

func _configure_music_btn_png(btn: Button, png_path: String, action: Callable, is_flipped: bool = false) -> void:
	if not btn:
		return
	btn.flat = true
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

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
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/ui/IconoBlanco.gdshader") as Shader
	mat.set_shader_parameter("icon_color", Color(1.0, 1.0, 1.0, 1.0))
	rect.material = mat
	rect.modulate = Color.WHITE

	btn.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 4; rect.offset_right = -4
	rect.offset_top = 4; rect.offset_bottom = -4

	btn.pivot_offset = btn.custom_minimum_size / 2
	for conn in btn.mouse_entered.get_connections():
		btn.mouse_entered.disconnect(conn["callable"])
	btn.mouse_entered.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	for conn in btn.mouse_exited.get_connections():
		btn.mouse_exited.disconnect(conn["callable"])
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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

func _abrir_dialogo_agregar_musica_local() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.filters = PackedStringArray([
		"*.mp3 ; Archivos MP3 (*.mp3)",
		"*.ogg ; Archivos OGG (*.ogg)",
		"*.wav ; Archivos WAV (*.wav)"
	])
	file_dialog.title = "Seleccionar Canciones Locales (MP3, OGG, WAV)"
	file_dialog.use_native_dialog = true
	file_dialog.size = Vector2i(900, 650)
	file_dialog.files_selected.connect(_on_archivos_musica_seleccionados)
	add_child(file_dialog)
	file_dialog.popup_centered()

func _limpiar_uri_ruta(path: String) -> String:
	var p = path.uri_decode()
	if "primary:" in p:
		p = p.rsplit("primary:", false, 1)[-1]
	elif "primary/" in p:
		p = p.rsplit("primary/", false, 1)[-1]
	elif "raw:" in p:
		p = p.rsplit("raw:", false, 1)[-1]
		
	p = p.replace("\\", "/")
	if "?" in p:
		p = p.split("?")[0]
		
	var fname = p.get_file()
	if fname.is_empty():
		var parts = p.rsplit("/", false, 1)
		if parts.size() > 0:
			fname = parts[-1]
	return fname

func _parsear_nombre_cancion(path: String) -> Dictionary:
	var raw_file_name = _limpiar_uri_ruta(path)
	var raw_name = raw_file_name.get_basename().strip_edges()
	var clean_name = raw_name
	
	# 1. Limpiar numero de pista al inicio (ej: "01 - ", "1. ", "02_")
	var regex_track = RegEx.new()
	if regex_track.compile("^\\d{1,3}[\\.\\-_\\s]+") == OK:
		clean_name = regex_track.sub(clean_name, "").strip_edges()
		
	# 2. Limpiar etiquetas comunes de descargas (ej: (Official Video), [Audio HD], etc.)
	var regex_clean = RegEx.new()
	if regex_clean.compile("(?i)\\([^)]*(video|audio|lyric|letra|oficial|official|hd|4k|remix|ft|feat)[^)]*\\)|\\[[^\\]]*(video|audio|lyric|letra|oficial|official|hd|4k|remix|ft|feat)[^\\]]*\\]") == OK:
		clean_name = regex_clean.sub(clean_name, "", true).strip_edges()
		
	if clean_name.is_empty():
		clean_name = raw_name
		
	var title = clean_name
	var artist = "Musica Local"
	
	# 3. Detectar separador entre Autor y Cancion (ej: "Artista - Cancion")
	var sep = ""
	if " - " in clean_name:
		sep = " - "
	elif " – " in clean_name:
		sep = " – "
	elif " — " in clean_name:
		sep = " — "
	elif " _ " in clean_name:
		sep = " _ "
	elif "-" in clean_name and not clean_name.begins_with("-"):
		sep = "-"
		
	if sep != "":
		var parts = clean_name.split(sep, false, 2)
		if parts.size() >= 2:
			var p1 = parts[0].strip_edges()
			var p2 = parts[1].strip_edges()
			if not p1.is_empty() and not p2.is_empty():
				artist = p1
				title = p2
				
	return {
		"title": title,
		"artist": artist
	}

const PLAYLIST_SAVE_PATH: String = "user://playlist.cfg"

func _cargar_playlist_guardada() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(PLAYLIST_SAVE_PATH) == OK:
		var saved_tracks = cfg.get_value("playlist", "tracks", [])
		if saved_tracks is Array and not saved_tracks.is_empty():
			var default_files = ["res://recursos/Musica/Aire-de-son.mp3", "res://recursos/Musica/Puya-vallenata.mp3"]
			var temp_tracks: Array = [
				{"title":"Aire de Son", "artist":"Nuestra Tierra", "file":"res://recursos/Musica/Aire-de-son.mp3"},
				{"title":"Puya Vallenata", "artist":"Nuestra Tierra", "file":"res://recursos/Musica/Puya-vallenata.mp3"},
			]
			for item in saved_tracks:
				if item is Dictionary and item.has("file"):
					var file_path = str(item["file"])
					if file_path in default_files:
						continue
					if file_path.begins_with("res://") or FileAccess.file_exists(file_path):
						temp_tracks.append({
							"title": str(item.get("title", "Cancion Local")),
							"artist": str(item.get("artist", "Musica Local")),
							"file": file_path
						})
			music_tracks = temp_tracks

func _guardar_playlist_local() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("playlist", "tracks", music_tracks)
	cfg.save(PLAYLIST_SAVE_PATH)

func _on_archivos_musica_seleccionados(paths: PackedStringArray) -> void:
	var agregadas: int = 0
	for path in paths:
		var parsed = _parsear_nombre_cancion(path)
		var title = parsed["title"]
		var artist = parsed["artist"]
		
		var ya_existe = false
		for trk in music_tracks:
			if trk.has("file") and trk["file"] == path:
				ya_existe = true
				break
		if not ya_existe:
			music_tracks.append({
				"title": title,
				"artist": artist,
				"file": path
			})
			agregadas += 1
			
	if agregadas > 0:
		_guardar_playlist_local()
		_update_music_display()
		var new_idx = music_tracks.size() - agregadas
		is_playing_music = true
		_load_track(new_idx)
		notificar("¡" + str(agregadas) + " cancion(es) agregada(s) a la playlist!", "exito")
	else:
		notificar("Las canciones seleccionadas ya estan en la playlist", "alerta")

func _cargar_audio_local(path: String) -> AudioStream:
	var ext = path.get_extension().to_lower()
	if ext == "mp3":
		var mp3 = AudioStreamMP3.new()
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			mp3.data = file.get_buffer(file.get_length())
			file.close()
			return mp3
	elif ext == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	elif ext == "wav":
		var wav = AudioStreamWAV.new()
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			wav.data = file.get_buffer(file.get_length())
			file.close()
			return wav
	return null

func _load_track(idx: int) -> void:
	if not music_player or music_tracks.is_empty():
		return
	current_track_idx = clamp(idx, 0, music_tracks.size() - 1)
	var track = music_tracks[current_track_idx]
	if track.has("file"):
		var path = track["file"]
		var stream: AudioStream = null
		if path.begins_with("res://"):
			stream = load(path) as AudioStream
		else:
			stream = _cargar_audio_local(path)
			
		if stream:
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
		else:
			notificar("No se pudo cargar el archivo local: " + path.get_file(), "alerta")
	_update_music_display()

func _update_music_display() -> void:
	if music_track_label:
		music_track_label.text  = music_tracks[current_track_idx]["title"]
	if music_artist_label:
		music_artist_label.text = "🎵 " + music_tracks[current_track_idx]["artist"]
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
			
	if is_instance_valid(playlist_vbox):
		for child in playlist_vbox.get_children():
			child.queue_free()
		for idx in range(music_tracks.size()):
			var trk = music_tracks[idx]
			var is_current = (idx == current_track_idx)
			
			var row_hbox = HBoxContainer.new()
			row_hbox.add_theme_constant_override("separation", 6)
			
			var trk_btn = Button.new()
			trk_btn.text = (" ▶  " if is_current else " 🎵 ") + str(idx + 1) + ". " + trk["title"] + "  —  " + trk["artist"]
			trk_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			trk_btn.custom_minimum_size = Vector2(0, 56)
			trk_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trk_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			trk_btn.clip_text = true
			
			var st = StyleBoxFlat.new()
			st.bg_color = Color(0.18, 0.12, 0.32, 0.95) if is_current else Color(0.09, 0.10, 0.16, 0.80)
			st.border_width_left = 3 if is_current else 1
			st.border_color = Color(0.65, 0.35, 1.00) if is_current else Color(0.20, 0.25, 0.35, 0.5)
			st.corner_radius_top_left = 12; st.corner_radius_top_right = 12
			st.corner_radius_bottom_left = 12; st.corner_radius_bottom_right = 12
			st.content_margin_left = 14; st.content_margin_right = 14
			trk_btn.add_theme_stylebox_override("normal", st)
			
			var st_h = st.duplicate() as StyleBoxFlat
			st_h.bg_color = Color(0.25, 0.18, 0.42, 0.95)
			st_h.border_color = Color(0.75, 0.45, 1.00)
			trk_btn.add_theme_stylebox_override("hover", st_h)
			
			trk_btn.add_theme_font_size_override("font_size", 24)
			trk_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if is_current else Color(0.70, 0.72, 0.82))
			if _font:
				trk_btn.add_theme_font_override("font", _font)
				
			var target_idx = idx
			trk_btn.pressed.connect(func():
				is_playing_music = true
				_load_track(target_idx)
			)
			row_hbox.add_child(trk_btn)

			var file_path = str(trk.get("file", ""))
			if not file_path.begins_with("res://recursos/Musica/"):
				var del_btn = Button.new()
				del_btn.text = "🗑"
				del_btn.custom_minimum_size = Vector2(52, 56)
				del_btn.add_theme_font_size_override("font_size", 20)
				
				var del_st = StyleBoxFlat.new()
				del_st.bg_color = Color(0.35, 0.08, 0.12, 0.85)
				del_st.border_width_left = 1; del_st.border_width_top = 1
				del_st.border_width_right = 1; del_st.border_width_bottom = 1
				del_st.border_color = Color(0.85, 0.20, 0.30, 0.8)
				del_st.corner_radius_top_left = 12; del_st.corner_radius_top_right = 12
				del_st.corner_radius_bottom_left = 12; del_st.corner_radius_bottom_right = 12
				del_btn.add_theme_stylebox_override("normal", del_st)
				
				var del_st_h = del_st.duplicate() as StyleBoxFlat
				del_st_h.bg_color = Color(0.55, 0.12, 0.18, 0.95)
				del_btn.add_theme_stylebox_override("hover", del_st_h)
				del_btn.add_theme_stylebox_override("pressed", del_st)
				del_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
				
				var del_target = idx
				del_btn.pressed.connect(func():
					if del_target < music_tracks.size():
						music_tracks.remove_at(del_target)
						_guardar_playlist_local()
						if current_track_idx >= music_tracks.size():
							current_track_idx = max(0, music_tracks.size() - 1)
						_update_music_display()
						notificar("Cancion eliminada de la playlist", "alerta")
				)
				row_hbox.add_child(del_btn)
				
			playlist_vbox.add_child(row_hbox)

	if music_headphones_warning:
		music_headphones_warning.add_theme_font_size_override("font_size", 16)
		if _player_has_headphones():
			music_headphones_warning.text = "🎧 AUDIFONOS CONECTADOS\nAudio de alta fidelidad HD"
			music_headphones_warning.add_theme_color_override("font_color", Color(0.20, 0.85, 0.45))
		else:
			music_headphones_warning.text = "⚠ MODO ALTAVOZ VEHICULO\nConecta audifonos para escuchar en segundo plano"
			music_headphones_warning.add_theme_color_override("font_color", Color(1.00, 0.60, 0.10))

	if music_headphones_btn:
		music_headphones_btn.add_theme_font_size_override("font_size", 16)
		if _player_has_headphones():
			music_headphones_btn.text = "Desconectar Audifonos"
		else:
			music_headphones_btn.text = "Conectar Audifonos"

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
	if not app_container_garage:
		return
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
		["🛠️", "Auxilio Vial 24/7",    "Combustible, llantas, grúa y rescate", C_ORANGE, func(): _abrir_panel_asistencia_mecanica()],
		["🔩", "Mecanico General",     "Motor, inyección, frenos y transmisión", C_ACCENT, func(): _abrir_panel_asistencia_mecanica()],
		["🛞", "Taller de Rines",     "Cambio y personalización de rines",  Color(0.25, 0.75, 1.0), Callable()],
		["🎨", "Pintura Custom",       "Colores y viniles exclusivos",        C_ACCENT2, Callable()],
		["💡", "Luces y Neon",         "Iluminación interior y exterior",     C_YELLOW, Callable()],
		["🏎️", "Rendimiento",          "Turbo, escape y suspensión",          C_RED, Callable()],
		["🧼", "Lavado Premium",       "Detailing completo del vehículo",     C_GREEN, Callable()],
	]

	for svc in services:
		var row = _make_garage_item(svc[0], svc[1], svc[2], svc[3], svc[4])
		inner.add_child(row)

func _make_garage_item(icon: String, name_: String, desc: String, color: Color, action: Callable = Callable()) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, 82)
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	st.corner_radius_top_left=8;st.corner_radius_top_right=8
	st.corner_radius_bottom_left=8;st.corner_radius_bottom_right=8
	st.border_width_left=3;st.border_width_top=1
	st.border_width_right=1;st.border_width_bottom=1
	st.border_color = Color(0.78, 0.81, 0.85, 0.20)
	st.shadow_color = Color(0, 0, 0, 0.35); st.shadow_size = 5
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
	desc_lbl.add_theme_font_size_override("font_size", 18)
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

	if action.is_valid():
		var click_btn = Button.new()
		click_btn.flat = true
		click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		click_btn.focus_mode = Control.FOCUS_NONE
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		click_btn.pressed.connect(action)
		card.add_child(click_btn)
		click_btn.mouse_entered.connect(func():
			var sh = st.duplicate() as StyleBoxFlat
			sh.bg_color = Color(0.12, 0.14, 0.18, 0.95)
			sh.border_color = color
			card.add_theme_stylebox_override("panel", sh)
		)
		click_btn.mouse_exited.connect(func():
			card.add_theme_stylebox_override("panel", st)
		)

	return card

# ═════════════════════════════════════════════════════════════════════════════
#  APP: AJUSTES
# ═════════════════════════════════════════════════════════════════════════════
func _setup_app_settings(_parent: Control) -> void:
	if not app_container_settings:
		return
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
		var sm = get_node_or_null("/root/SettingsManager")
		if sm and sm.has_method("change_to_settings"):
			sm.change_to_settings()
		else:
			var path = "res://interfaz/pantallas/configuraciones/configuraciones.tscn"
			if ResourceLoader.exists(path):
				var s = load(path)
				if s:
					get_tree().current_scene.add_child(s.instantiate())
					close_phone()
	)
	adv_section.add_child(adv_btn)

	var rescue_section = _make_settings_section("🚨  Auxilio Vial y Asistencia en Carretera")
	inner.add_child(rescue_section)

	var mecano_btn = _make_settings_button("🛠️  Solicitar Auxilio Mecánico en Carretera (24/7)", func():
		_abrir_panel_asistencia_mecanica()
	)
	rescue_section.add_child(mecano_btn)

	var grua_btn = _make_settings_button("🏗️  Remolque de Emergencia / Grúa al Taller (-$ 85.000)", func():
		_ejecutar_servicio_grua_tableta()
	)
	rescue_section.add_child(grua_btn)

	var save_section = _make_settings_section("💾  Gestión de Partida")
	inner.add_child(save_section)

	var save_btn = _make_settings_button("💾  Guardar Partida", func():
		var datos = get_node_or_null("/root/DatosUsuario")
		if datos and datos.has_method("save_local"):
			datos.save_local()
			notificar("¡Partida guardada exitosamente!", "exito")
	)
	save_section.add_child(save_btn)

	var exit_btn = _make_settings_button("🏠  Salir al Menú Principal", func():
		get_tree().paused = false
		var menu_path = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
		if ResourceLoader.exists(menu_path):
			get_tree().change_scene_to_file(menu_path)
		else:
			get_tree().quit()
	)
	save_section.add_child(exit_btn)

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
	st.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	st.corner_radius_top_left=8;st.corner_radius_top_right=8
	st.corner_radius_bottom_left=8;st.corner_radius_bottom_right=8
	st.content_margin_left=18;st.content_margin_top=12;st.content_margin_bottom=12
	st.border_width_left=1;st.border_width_top=1;st.border_width_right=1;st.border_width_bottom=2
	st.border_color=Color(0.78, 0.81, 0.85, 0.20)
	var sh = st.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.14, 0.16, 0.19, 0.92)
	sh.border_color = Color(0.85, 0.88, 0.92, 0.42)
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

	var hbox = HBoxContainer.new()
	hdr.add_child(hbox)

	var back = Button.new()
	back.text = back_text
	back.custom_minimum_size = Vector2(130, 42)
	if _font: back.add_theme_font_override("font", _font)
	back.add_theme_font_size_override("font_size", 16)
	back.add_theme_color_override("font_color", Color(0.90, 0.92, 0.95, 1.0))
	
	var b_st = StyleBoxFlat.new()
	b_st.content_margin_left = 10.0; b_st.content_margin_top = 6.0
	b_st.content_margin_right = 12.0; b_st.content_margin_bottom = 6.0
	b_st.bg_color = Color(0.08, 0.09, 0.11, 0.78)
	b_st.border_width_left = 1; b_st.border_width_top = 1
	b_st.border_width_right = 1; b_st.border_width_bottom = 1
	b_st.border_color = Color(0.78, 0.81, 0.85, 0.22)
	b_st.corner_radius_top_left = 8; b_st.corner_radius_top_right = 8
	b_st.corner_radius_bottom_left = 8; b_st.corner_radius_bottom_right = 8
	b_st.shadow_color = Color(0, 0, 0, 0.35); b_st.shadow_size = 5
	var b_sth = b_st.duplicate() as StyleBoxFlat
	b_sth.bg_color = Color(0.14, 0.16, 0.19, 0.90)
	b_sth.border_color = Color(0.85, 0.88, 0.92, 0.42)
	back.add_theme_stylebox_override("normal", b_st)
	back.add_theme_stylebox_override("hover", b_sth)
	back.add_theme_stylebox_override("pressed", b_sth)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(back_action)
	hbox.add_child(back)

	var fill = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(fill)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font: title_lbl.add_theme_font_override("font", _font)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
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
	if app_name == "soporte":
		_actualizar_datos_soporte()
		_soporte_unread_count = 0
		_actualizar_notificaciones_soporte()
	current_app = app_name
	_update_app_visibility()
	_show_app_splash(app_name)

func _actualizar_datos_soporte() -> void:
	if is_instance_valid(app_container_support):
		if app_container_support.has_method("asignar_actividades_recientes"):
			app_container_support.call("asignar_actividades_recientes", bank_transactions)

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
	
	if logo_rect: logo_rect.visible = false
	if logo_emoji: logo_emoji.visible = false
	
	var app_icon = ""
	var app_label = ""
	var emoji_color = Color.WHITE
	
	match app_name:
		"waze":
			app_icon = "res://recursos/iconos app/app_mapa.png"
			app_label = "WAZE GPS"
		"bank":
			app_icon = "res://recursos/iconos app/app_banco.png"
			app_label = "BANCO"
		"fletes":
			app_icon = "🚛"
			app_label = "FLETES NT"
			emoji_color = NEQUI_BLUE_PRIMARY
		"music":
			app_icon = "res://recursos/iconos app/app_musica.png"
			app_label = "NT MUSICA"
		"garage":
			app_icon = "🔧"
			app_label = "GARAGE"
			emoji_color = C_ORANGE
		"jobs":
			app_icon = "🪪"
			app_label = "TRABAJOS Y LICENCIAS"
			emoji_color = Color(0.12, 0.64, 0.88)
		"missions":
			app_icon = "🎯"
			app_label = "MISIONES"
			emoji_color = Color(1.0, 0.78, 0.10)
		"soporte":
			app_icon = "🎧"
			app_label = "SOPORTE EN VIVO"
			emoji_color = Color(1.0, 0.45, 0.0)
		"settings":
			app_icon = "res://recursos/iconos app/app_ajustes.png"
			app_label = "AJUSTES"
			
	if app_title: app_title.text = app_label
	
	if app_icon.begins_with("res://"):
		if logo_rect:
			logo_rect.texture = load(app_icon) as Texture2D
			logo_rect.visible = true
	else:
		if logo_emoji:
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
	if app_container_bank:
		app_container_bank.visible = (current_app == "bank")
		if app_container_bank.visible:
			_setup_app_bank(null)
	if app_container_fletes:
		app_container_fletes.visible = (current_app == "fletes")
		if app_container_fletes.visible:
			_setup_app_fletes(null)
	if app_container_music:    app_container_music.visible    = (current_app == "music")
	if app_container_garage:   app_container_garage.visible   = (current_app == "garage")
	if app_container_jobs:     app_container_jobs.visible     = (current_app == "jobs")
	var tablet_activa := is_open or (Engine.is_editor_hint() and mostrar_en_editor)
	if app_container_missions:
		app_container_missions.visible = tablet_activa and (current_app == "missions")
		if app_container_missions.visible and app_container_missions.has_method("actualizar_lista"):
			app_container_missions.call("actualizar_lista")
	if app_container_support:
		app_container_support.visible = tablet_activa and (current_app == "soporte")

	if is_instance_valid(phone_frame):
		phone_frame.visible = tablet_activa and (current_app != "soporte" and current_app != "missions")

	_actualizar_material_carreteras(current_app == "waze")
	_actualizar_minimap_viewport_state()

	if current_app == "bank" and DatosUsuario:
		if bank_money_label:    bank_money_label.text    = _formatear_pesos_colombianos(DatosUsuario.dinero)
		if bank_emeralds_label: bank_emeralds_label.text = "💎 " + str(DatosUsuario.esmeraldas) + " Esmeraldas"

func _actualizar_minimap_viewport_state() -> void:
	if is_instance_valid(minimap_viewport):
		if is_open and current_app == "waze":
			minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			minimap_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func toggle_phone() -> void:
	if is_open: close_phone()
	else:       open_phone()

func open_phone() -> void:
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(phone_frame):
		phone_frame.mouse_filter = Control.MOUSE_FILTER_STOP
		phone_frame.visible = true
		_actualizar_posicion_tableta()
		phone_frame.pivot_offset = phone_frame.size / 2.0
		phone_frame.scale = Vector2(0.8, 0.8)
		phone_frame.modulate.a = 0.0
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(phone_frame, "scale", Vector2(1.0, 1.0), 0.35)
		tw.tween_property(phone_frame, "modulate:a", 1.0, 0.25)
		
	_switch_app("home")
	_actualizar_estilo_hud_boton(true)
	_actualizar_posicion_boton_cargador()
	_actualizar_minimap_viewport_state()
	_actualizar_ui_bateria(true)

	if is_battery_dead:
		_mostrar_pantalla_bateria_agotada()

	var DU = get_node_or_null("/root/DatosUsuario")
	if DU and not DU.tutorial_celular_completado:
		await get_tree().process_frame
		await get_tree().process_frame
		_launch_tutorial_celular()

func _launch_tutorial_celular() -> void:
	if get_node_or_null("TutorialCelular"):
		return
	var tutorial_script = load("res://codigo/celular/TutorialCelular.gd")
	if not tutorial_script:
		push_warning("[CelularUI] No se encontro TutorialCelular.gd")
		return
	var tutorial = tutorial_script.new()
	tutorial.name = "TutorialCelular"
	add_child(tutorial)

func close_phone() -> void:
	is_open = false
	get_tree().paused = false
	_actualizar_minimap_viewport_state()
	
	# BUG-006 FIX: Desactivar captura de toques fantasma de inmediato en todos los contenedores
	if is_instance_valid(phone_frame):
		phone_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(app_container_missions):
		app_container_missions.visible = false
		app_container_missions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(app_container_support):
		app_container_support.visible = false
		app_container_support.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(splash_screen):
		splash_screen.visible = false
		splash_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	current_app = "home"
	
	if is_horizontal:
		toggle_phone_orientation(false)
	if is_instance_valid(charger_cable_container):
		charger_cable_container.queue_free()
	if is_instance_valid(phone_frame):
		phone_frame.pivot_offset = phone_frame.size / 2.0
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(phone_frame, "scale", Vector2(0.8, 0.8), 0.20)
		tw.tween_property(phone_frame, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(func():
			if not is_open and is_instance_valid(phone_frame):
				phone_frame.visible = false
		)
	_actualizar_estilo_hud_boton(false)
	_actualizar_posicion_boton_cargador()

func _actualizar_posicion_tableta() -> void:
	if not is_instance_valid(phone_frame):
		return
	var vp_size: Vector2
	if Engine.is_editor_hint():
		vp_size = Vector2(2392.0, 1080.0)
	else:
		var vp_rect = get_viewport().get_visible_rect()
		vp_size = vp_rect.size

	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(2392.0, 1080.0)

	_last_vp_size = vp_size

	# Tableta moderna amplia (94% de ancho y 90% de alto de la pantalla)
	var target_w = clamp(vp_size.x * 0.94, 1280.0, 1720.0)
	var target_h = clamp(vp_size.y * 0.90, 760.0, 1040.0)
	if vp_size.x < 1320.0 and not Engine.is_editor_hint():
		target_w = max(340.0, vp_size.x - 30.0)
	if vp_size.y < 780.0 and not Engine.is_editor_hint():
		target_h = max(500.0, vp_size.y - 30.0)

	phone_frame.custom_minimum_size = Vector2(target_w, target_h)
	phone_frame.size = Vector2(target_w, target_h)
	phone_frame.position = (vp_size - Vector2(target_w, target_h)) / 2.0
	phone_frame.pivot_offset = Vector2(target_w, target_h) / 2.0
	_actualizar_posicion_boton_cargador()

# ═════════════════════════════════════════════════════════════════════════════
#  PROCESS  — animacion + reloj + camara GPS + reposicion HUD
# ═════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if mostrar_en_editor and is_instance_valid(phone_frame):
			phone_frame.visible = true
			phone_frame.modulate.a = 1.0
			phone_frame.scale = Vector2.ONE
			_actualizar_posicion_tableta()
		return

	# Gestion de descarga / carga de bateria (parametros realistas)
	if is_charging:
		battery_level += delta * 4.5 * battery_charge_speed
		if battery_level >= 100.0:
			battery_level = 100.0
			is_charging = false
			_restaurar_pantalla_bateria()
	else:
		# Descarga realista: ~25 min en uso continuo abierta, >2h en reposo cerrada
		var drain_rate = (0.065 if is_open else 0.012) * battery_discharge_speed
		battery_level -= delta * drain_rate
		if battery_level <= 0.0:
			battery_level = 0.0
			if not is_battery_dead:
				_mostrar_pantalla_bateria_agotada()

	_actualizar_ui_bateria()

	if is_open:
		_procesar_simulacion_senal(delta)
	_procesar_recordatorios_nequi(delta)

	# Comprobación de cull mask periódica (cada 0.5s) en lugar de cada frame
	_cam_cull_check_timer += delta
	if _cam_cull_check_timer >= 0.5:
		_cam_cull_check_timer = 0.0
		var active_cam = get_viewport().get_camera_3d() if is_inside_tree() else null
		if active_cam and active_cam != minimap_camera:
			if active_cam.cull_mask & 2:
				active_cam.cull_mask = active_cam.cull_mask & ~2

	# Actualizar tamaño del viewport de Waze solo si cambia
	if is_open and current_app == "waze" and minimap_viewport and screen_panel:
		var sp_size := Vector2i(screen_panel.size)
		if sp_size.x > 0 and sp_size.y > 0 and minimap_viewport.size != sp_size:
			minimap_viewport.size = sp_size

	# Reloj de barra de estado: solo actualizar si cambia el minuto
	if is_open and is_instance_valid(status_time_label):
		var t = Time.get_time_dict_from_system()
		if t.minute != _last_minute:
			_last_minute = t.minute
			status_time_label.text = "%02d:%02d" % [t.hour, t.minute]

	# Reproductor de música
	if music_player:
		var playing_active = music_player.playing and not music_player.stream_paused
		if playing_active:
			var pos = music_player.get_playback_position()
			if is_open and current_app == "music":
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

		# Animar visualizador SOLO si el celular está abierto y en la app de música
		if is_open and current_app == "music" and visualizer_bars.size() > 0:
			for i in range(visualizer_bars.size()):
				var bar = visualizer_bars[i]
				var target_height = 12.0
				if playing_active:
					var time_scale = Time.get_ticks_msec() * 0.006
					target_height = 10.0 + sin(time_scale + i * 1.3) * 15.0 + randf_range(0.0, 15.0)
					target_height = clamp(target_height, 12.0, 50.0) 
				bar.custom_minimum_size = Vector2(10, lerp(bar.custom_minimum_size.y, target_height, delta * 12.0))

	# ─── LÓGICA DEL MAPA 3D (Solo si el celular está abierto y en Waze) ────────
	if is_open and current_app == "waze" and minimap_camera and player and follow_player_camera:
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

	# Comprobar llegada al destino final del GPS (Throttling a 4 Hz)
	if is_instance_valid(gps_line) and gps_line.get("active") == true:
		_gps_dest_check_timer += delta
		if _gps_dest_check_timer >= 0.25:
			_gps_dest_check_timer = 0.0
			var check_node = player
			if player.get("_conduciendo") == true and is_instance_valid(player.get("_vehiculo_actual")):
				check_node = player.get("_vehiculo_actual")
			if check_node:
				var target_pos = gps_line.get("target_position")
				var dist = check_node.global_position.distance_to(target_pos)
				if dist <= 10.0: # 10 metros
					gps_line.call("clear_route")
					gps_line.set("active", false)
					if is_instance_valid(search_line_edit):
						search_line_edit.text = "Llegaste a tu destino"
					if is_instance_valid(linea_gps_2d):
						linea_gps_2d.clear_points()
					if is_instance_valid(dest_marker_2d):
						dest_marker_2d.visible = false
					notificar("¡Llegaste a tu destino!", "exito")

	# ─── PROYECCIÓN DE RUTA 3D A LÍNEA 2D (Solo si el celular está abierto y en Waze) ────
	if is_open and current_app == "waze" and is_instance_valid(linea_gps_2d) and is_instance_valid(minimap_camera):
		_gps_update_timer += delta
		if _gps_update_timer >= GPS_UPDATE_INTERVAL:
			_gps_update_timer = 0.0
			_actualizar_red_vial_waze_2d()
			linea_gps_2d.clear_points()
			
			var ruta_actual = ruta_activa_3d
			if is_instance_valid(gps_line) and gps_line.get("active") == true:
				var path_3d = gps_line.get("last_path")
				if path_3d and not path_3d.is_empty():
					ruta_actual = path_3d
					
			if not ruta_actual.is_empty():
				for i in range(ruta_actual.size()):
					var p3d = ruta_actual[i]
					if not minimap_camera.is_position_behind(p3d):
						var p2d = minimap_camera.unproject_position(p3d)
						linea_gps_2d.add_point(p2d)
				
				if is_instance_valid(dest_marker_2d):
					var final_dest = ruta_actual[ruta_actual.size() - 1]
					var p2d = minimap_camera.unproject_position(final_dest)
					
					if minimap_camera.is_position_behind(final_dest):
						var cam_forward = -minimap_camera.global_transform.basis.z
						var to_dest = (final_dest - minimap_camera.global_position).normalized()
						var reflected = cam_forward + to_dest * 10.0
						p2d = minimap_camera.unproject_position(minimap_camera.global_position + reflected)
					
					var margin = 18.0
					var screen_size = app_container_waze.size
					if screen_size.x <= 0 or screen_size.y <= 0:
						screen_size = Vector2(400, 700)
					
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

	# Coordenadas en pantalla Waze (cacheando referencia a CoordsLabel)
	if is_open and player and current_app == "waze" and app_container_waze:
		if not is_instance_valid(_coords_label_cache):
			_coords_label_cache = app_container_waze.get_node_or_null("CoordsLabel") as Label
		if is_instance_valid(_coords_label_cache):
			var lat = 5.317 + player.global_position.z * 0.000009
			var lon = -73.939 + player.global_position.x * 0.000009
			_coords_label_cache.text = "LAT %.4f\nLON %.4f" % [lat, lon]

	_reposicionar_boton_celular()

func _reposicionar_boton_celular() -> void:
	pass

var _carreteras_minimapa_configuradas: bool = false

func _configurar_carreteras_minimapa() -> void:
	if _carreteras_minimapa_configuradas:
		return
	_carreteras_minimapa_configuradas = true

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
			# Crear SOLO una malla visual limpia (sin duplicar colisiones ni StaticBody3D a Jolt Physics)
			var duplicado = MeshInstance3D.new()
			duplicado.name = "MinimapLayer2Mesh"
			duplicado.mesh = mi.mesh
			duplicado.skin = mi.skin
			duplicado.skeleton = mi.skeleton
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

	var bg_panel = app_container_jobs.get_node_or_null("BGPanel") as Panel
	var portrait_view = app_container_jobs.get_node_or_null("PortraitView") as VBoxContainer
	if not portrait_view:
		return
	
	var back = portrait_view.get_node_or_null("Header/HBox/BackButton") as Button
	var title_lbl = portrait_view.get_node_or_null("Header/HBox/TitleLabel") as Label
	var card = portrait_view.get_node_or_null("ContentMargin/ContentVBox/BalanceCard") as Panel
	var card_vbox = card.get_node_or_null("VBox") as VBoxContainer if card else null
	var badge_icon = card_vbox.get_node_or_null("BadgeIcon") as Label if card_vbox else null
	var level_lbl = card_vbox.get_node_or_null("LevelLabel") as Label if card_vbox else null
	var status_lbl = card_vbox.get_node_or_null("StatusLabel") as Label if card_vbox else null
	var ver_btn = portrait_view.get_node_or_null("ContentMargin/ContentVBox/VerContenidoBtn") as Button
	
	var landscape_view = app_container_jobs.get_node_or_null("LandscapeView") as Panel
	var land_vbox = landscape_view.get_node_or_null("LandMargin/LandVBox") as VBoxContainer if landscape_view else null
	var land_title = land_vbox.get_node_or_null("TopHBox/TitleLabel") as Label if land_vbox else null
	var cerrar_btn = land_vbox.get_node_or_null("TopHBox/CerrarBtn") as Button if land_vbox else null
	var main_hbox = land_vbox.get_node_or_null("MainHBox") as HBoxContainer if land_vbox else null
	
	var col1 = main_hbox.get_node_or_null("Col1") as VBoxContainer if main_hbox else null
	var col1_title = col1.get_node_or_null("Col1Title") as Label if col1 else null
	
	var col2 = main_hbox.get_node_or_null("Col2") as VBoxContainer if main_hbox else null
	var col2_title = col2.get_node_or_null("Col2Title") as Label if col2 else null

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	bg_style.corner_radius_top_left = 16
	bg_style.corner_radius_top_right = 16
	bg_style.corner_radius_bottom_left = 16
	bg_style.corner_radius_bottom_right = 16
	if bg_panel:
		bg_panel.add_theme_stylebox_override("panel", bg_style)

	if back:
		back.add_theme_font_size_override("font_size", 20)
		back.add_theme_color_override("font_color", Color(0.20, 0.60, 1.00))
		for conn in back.pressed.get_connections():
			back.pressed.disconnect(conn["callable"])
		back.pressed.connect(func(): _switch_app("home"))
	
	if title_lbl:
		title_lbl.add_theme_font_size_override("font_size", 24)
		title_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))

	if card:
		var card_st = StyleBoxFlat.new()
		card_st.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		card_st.corner_radius_top_left = 12; card_st.corner_radius_top_right = 12
		card_st.corner_radius_bottom_left = 12; card_st.corner_radius_bottom_right = 12
		card_st.border_width_left = 1; card_st.border_width_top = 1
		card_st.border_width_right = 1; card_st.border_width_bottom = 1
		card_st.border_color = Color(0.78, 0.81, 0.85, 0.20)
		card_st.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
		card_st.shadow_size = 8
		card.add_theme_stylebox_override("panel", card_st)

	if badge_icon:
		badge_icon.add_theme_font_size_override("font_size", 48)
	if level_lbl:
		level_lbl.add_theme_font_size_override("font_size", 20)
		level_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	if status_lbl:
		status_lbl.add_theme_font_size_override("font_size", 14)
		status_lbl.add_theme_color_override("font_color", C_GREEN)

	if ver_btn:
		var btn_st = StyleBoxFlat.new()
		btn_st.content_margin_left = 10.0; btn_st.content_margin_top = 6.0
		btn_st.content_margin_right = 12.0; btn_st.content_margin_bottom = 6.0
		btn_st.bg_color = Color(0.08, 0.09, 0.11, 0.78)
		btn_st.border_width_left = 1; btn_st.border_width_top = 1
		btn_st.border_width_right = 1; btn_st.border_width_bottom = 1
		btn_st.border_color = Color(0.78, 0.81, 0.85, 0.25)
		btn_st.corner_radius_top_left = 8; btn_st.corner_radius_top_right = 8
		btn_st.corner_radius_bottom_left = 8; btn_st.corner_radius_bottom_right = 8
		btn_st.shadow_color = Color(0, 0, 0, 0.35)
		btn_st.shadow_size = 5
		btn_st.shadow_offset = Vector2(0, 2)
		var btn_st_h = btn_st.duplicate() as StyleBoxFlat
		btn_st_h.bg_color = Color(0.14, 0.16, 0.19, 0.90)
		btn_st_h.border_color = Color(0.85, 0.88, 0.92, 0.42)
		ver_btn.add_theme_stylebox_override("normal", btn_st)
		ver_btn.add_theme_stylebox_override("hover", btn_st_h)
		ver_btn.add_theme_stylebox_override("pressed", btn_st)
		ver_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		ver_btn.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		ver_btn.add_theme_font_size_override("font_size", 22)
		for conn in ver_btn.pressed.get_connections():
			ver_btn.pressed.disconnect(conn["callable"])
		ver_btn.pressed.connect(func(): toggle_phone_orientation(true))

	if landscape_view:
		var land_st = StyleBoxFlat.new()
		land_st.bg_color = Color(0.06, 0.07, 0.09, 0.96)
		land_st.corner_radius_top_left = 16; land_st.corner_radius_top_right = 16
		land_st.corner_radius_bottom_left = 16; land_st.corner_radius_bottom_right = 16
		land_st.border_width_left = 1; land_st.border_width_top = 1
		land_st.border_width_right = 1; land_st.border_width_bottom = 1
		land_st.border_color = Color(0.78, 0.81, 0.85, 0.20)
		landscape_view.add_theme_stylebox_override("panel", land_st)

	if land_title:
		land_title.add_theme_font_size_override("font_size", 22)
		land_title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))

	if cerrar_btn:
		var cls_st = StyleBoxFlat.new()
		cls_st.content_margin_left = 10.0; cls_st.content_margin_top = 6.0
		cls_st.content_margin_right = 12.0; cls_st.content_margin_bottom = 6.0
		cls_st.bg_color = Color(0.24, 0.11, 0.11, 0.94)
		cls_st.border_width_left = 1; cls_st.border_width_top = 1
		cls_st.border_width_right = 1; cls_st.border_width_bottom = 2
		cls_st.border_color = Color(0.78, 0.28, 0.26, 0.92)
		cls_st.corner_radius_top_left = 8; cls_st.corner_radius_top_right = 8
		cls_st.corner_radius_bottom_left = 8; cls_st.corner_radius_bottom_right = 8
		cerrar_btn.add_theme_stylebox_override("normal", cls_st)
		cerrar_btn.add_theme_stylebox_override("hover", cls_st)
		cerrar_btn.add_theme_stylebox_override("pressed", cls_st)
		cerrar_btn.add_theme_color_override("font_color", Color.WHITE)
		cerrar_btn.add_theme_font_size_override("font_size", 16)
		for conn in cerrar_btn.pressed.get_connections():
			cerrar_btn.pressed.disconnect(conn["callable"])
		cerrar_btn.pressed.connect(func(): toggle_phone_orientation(false))

	if col1_title:
		col1_title.add_theme_font_size_override("font_size", 16)
		col1_title.add_theme_color_override("font_color", C_AMBER)

	var row_st = StyleBoxFlat.new()
	row_st.bg_color = Color(0.08, 0.09, 0.12, 0.78)
	row_st.corner_radius_top_left = 8; row_st.corner_radius_top_right = 8
	row_st.corner_radius_bottom_left = 8; row_st.corner_radius_bottom_right = 8
	row_st.border_width_left = 1; row_st.border_width_top = 1
	row_st.border_width_right = 1; row_st.border_width_bottom = 1
	row_st.border_color = Color(0.78, 0.81, 0.85, 0.18)

	var lic_code_st = StyleBoxFlat.new()
	lic_code_st.bg_color = Color(0.11, 0.12, 0.14, 0.92)
	lic_code_st.border_width_left = 1; lic_code_st.border_width_top = 1
	lic_code_st.border_width_right = 1; lic_code_st.border_width_bottom = 1
	lic_code_st.border_color = Color(0.88, 0.68, 0.28, 0.70)
	lic_code_st.corner_radius_top_left = 6; lic_code_st.corner_radius_top_right = 6
	lic_code_st.corner_radius_bottom_left = 6; lic_code_st.corner_radius_bottom_right = 6

	if col1:
		for row_name in ["LicRow1", "LicRow2", "LicRow3"]:
			var r = col1.get_node_or_null(row_name) as Panel
			if r:
				r.add_theme_stylebox_override("panel", row_st)
				var r_code = r.get_node_or_null("HBox/Code") as Label
				if r_code:
					r_code.add_theme_stylebox_override("normal", lic_code_st)
					r_code.add_theme_font_size_override("font_size", 16)
					r_code.add_theme_color_override("font_color", Color.WHITE)
				var r_name = r.get_node_or_null("HBox/Name") as Label
				if r_name:
					r_name.add_theme_font_size_override("font_size", 15)
					r_name.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
				var r_status = r.get_node_or_null("HBox/Status") as Label
				if r_status:
					r_status.add_theme_font_size_override("font_size", 14)
					r_status.add_theme_color_override("font_color", C_GREEN)

	if col2_title:
		col2_title.add_theme_font_size_override("font_size", 16)
		col2_title.add_theme_color_override("font_color", C_AMBER)

	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.14, 0.15, 0.17, 0.88)
	pb_bg.corner_radius_top_left = 3; pb_bg.corner_radius_top_right = 3
	pb_bg.corner_radius_bottom_left = 3; pb_bg.corner_radius_bottom_right = 3
	var pb_fg = StyleBoxFlat.new()
	pb_fg.bg_color = Color(0.88, 0.68, 0.28, 0.92)
	pb_fg.corner_radius_top_left = 3; pb_fg.corner_radius_top_right = 3
	pb_fg.corner_radius_bottom_left = 3; pb_fg.corner_radius_bottom_right = 3

	if col2:
		for job_name in ["Job1", "Job2", "Job3"]:
			var j = col2.get_node_or_null(job_name) as VBoxContainer
			if j:
				var j_title = j.get_node_or_null("HBox/Title") as Label
				if j_title:
					j_title.add_theme_font_size_override("font_size", 14)
					j_title.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
				var j_pct = j.get_node_or_null("HBox/Pct") as Label
				if j_pct:
					j_pct.add_theme_font_size_override("font_size", 14)
					j_pct.add_theme_color_override("font_color", C_AMBER)
				var j_pbar = j.get_node_or_null("PBar") as ProgressBar
				if j_pbar:
					j_pbar.add_theme_stylebox_override("background", pb_bg)
					j_pbar.add_theme_stylebox_override("fill", pb_fg)

func toggle_phone_orientation(horizontal: bool) -> void:
	if not is_instance_valid(phone_frame) or not app_container_jobs:
		return
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

func notificar(mensaje: String, tipo: String = "info") -> void:
	# Crear una notificación flotante premium en la pantalla
	var notif_panel = PanelContainer.new()
	var notif_label = Label.new()
	
	# Configurar el texto
	notif_label.text = mensaje
	notif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notif_label.custom_minimum_size = Vector2(400, 60)
	
	# Usar fuente Moderniz si está cargada
	if _font:
		notif_label.add_theme_font_override("font", _font)
	notif_label.add_theme_font_size_override("font_size", 20)
	
	# Colores basados en tipo
	var bg_col = Color(0.04, 0.06, 0.12, 0.9)
	var border_col = Color(0.20, 0.60, 1.00, 0.9) # Azul Waze
	if tipo == "exito":
		border_col = Color(0.14, 0.85, 0.45, 0.9) # Verde éxito
	elif tipo == "alerta":
		border_col = Color(0.95, 0.22, 0.22, 0.9) # Rojo alerta
		
	# Estilo Glassmorphism premium
	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_col
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	notif_panel.add_theme_stylebox_override("panel", style)
	notif_panel.add_child(notif_label)
	add_child(notif_panel)
	
	# Posicionamiento: centrado horizontalmente en la parte superior del viewport
	notif_panel.anchors_preset = Control.PRESET_CENTER_TOP
	notif_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	var viewport_size = get_viewport().get_visible_rect().size
	notif_panel.position = Vector2((viewport_size.x - notif_panel.size.x) / 2.0, -100) # Inicia arriba fuera de la pantalla
	
	# Animar entrada (fade in + slide down)
	var tween = create_tween().set_parallel(true)
	notif_panel.modulate.a = 0.0
	var target_y = 50.0
	# Si el celular está abierto, posicionar para no tapar la cámara del celular
	if is_open:
		target_y = 80.0
		
	tween.tween_property(notif_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(notif_panel, "position:y", target_y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Esperar duración
	await get_tree().create_timer(3.0).timeout
	
	# Animar salida (fade out + slide up)
	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_property(notif_panel, "modulate:a", 0.0, 0.3)
	tween_out.tween_property(notif_panel, "position:y", -100.0, 0.3)
	await tween_out.finished
	notif_panel.queue_free()

		


func _ejecutar_servicio_grua_tableta() -> void:
	var vehiculo_a_rescatar: Node3D = null
	var remolque_acoplado: RigidBody3D = null

	if has_node("/root/InputVehiculo"):
		var iv = get_node("/root/InputVehiculo")
		if "vehiculo_actual" in iv and is_instance_valid(iv.vehiculo_actual):
			vehiculo_a_rescatar = iv.vehiculo_actual as Node3D

	if not vehiculo_a_rescatar:
		var t800 = get_tree().current_scene.find_child("T800_A", true, false) as Node3D if get_tree() and get_tree().current_scene else null
		if not t800 and get_tree() and get_tree().current_scene:
			t800 = get_tree().current_scene.find_child("T800_Alargada", true, false) as Node3D
		vehiculo_a_rescatar = t800

	if not vehiculo_a_rescatar:
		var pl = get_tree().get_first_node_in_group("jugador") as Node3D if get_tree() else null
		if not pl and get_tree() and get_tree().current_scene:
			pl = get_tree().current_scene.find_child("Jugador", true, false) as Node3D
		vehiculo_a_rescatar = pl

	if not vehiculo_a_rescatar:
		notificar("No se encontró ningún vehículo para remolcar.", "error")
		return

	var hitch = vehiculo_a_rescatar.find_child("Enganche", true, false)
	if hitch and "conectado" in hitch and hitch.conectado and hitch.get("enganche_remoto"):
		if hitch.has_method("_buscar_cuerpo"):
			remolque_acoplado = hitch.call("_buscar_cuerpo", hitch.enganche_remoto) as RigidBody3D

	var puntos_rescate: Array[Vector3] = [
		Vector3(-42.41, 0.65, 132.81),
		Vector3(-140.30, 5.45, 478.24),
		Vector3(408.04, 2.05, 761.47),
	]
	var pos_actual = vehiculo_a_rescatar.global_position
	var punto_destino = puntos_rescate[0]
	var menor_distancia = 999999.0
	for pt in puntos_rescate:
		var d = pos_actual.distance_to(pt)
		if d < menor_distancia:
			menor_distancia = d
			punto_destino = pt

	var costo = 85000.0
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.dinero -= costo
		if datos.has_method("save_local"):
			datos.save_local()
	registrar_movimiento_nequi("out", "Auxilio Vial / Grúa Mecánica", costo)

	if vehiculo_a_rescatar is RigidBody3D:
		var rb = vehiculo_a_rescatar as RigidBody3D
		rb.freeze = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.global_position = punto_destino + Vector3(0, 0.25, 0)
		rb.rotation = Vector3.ZERO
	else:
		vehiculo_a_rescatar.global_position = punto_destino + Vector3(0, 0.25, 0)
		vehiculo_a_rescatar.rotation.y = 0.0

	if is_instance_valid(remolque_acoplado):
		remolque_acoplado.freeze = true
		remolque_acoplado.linear_velocity = Vector3.ZERO
		remolque_acoplado.angular_velocity = Vector3.ZERO
		remolque_acoplado.rotation = Vector3.ZERO
		remolque_acoplado.global_position = punto_destino + Vector3(0, 0.25, 7.5)

	var tree = get_tree()
	if tree:
		tree.create_timer(0.35, true).timeout.connect(func():
			if is_instance_valid(vehiculo_a_rescatar) and vehiculo_a_rescatar is RigidBody3D:
				(vehiculo_a_rescatar as RigidBody3D).freeze = false
				(vehiculo_a_rescatar as RigidBody3D).linear_velocity = Vector3.ZERO
			if is_instance_valid(remolque_acoplado):
				remolque_acoplado.freeze = false
				remolque_acoplado.linear_velocity = Vector3.ZERO
		, CONNECT_ONE_SHOT)

	notificar("¡Asistencia completada! Vehículo enderezado (-$ 85.000)", "exito")
	close_phone()

# ═════════════════════════════════════════════════════════════════════════════
# PANEL MODAL: ASISTENCIA MECÁNICA EN CARRETERA 24/7 (GLASSMORPHIC COCKPIT)
# ═════════════════════════════════════════════════════════════════════════════
func _abrir_panel_asistencia_mecanica() -> void:
	if not is_instance_valid(phone_frame):
		return

	# Eliminar modal anterior si existiera
	var anterior = phone_frame.get_node_or_null("ModalAsistenciaMecanica")
	if is_instance_valid(anterior):
		anterior.queue_free()

	var modal = PanelContainer.new()
	modal.name = "ModalAsistenciaMecanica"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo Glassmorphic Cockpit
	var st_bg = StyleBoxFlat.new()
	st_bg.bg_color = Color(0.06, 0.07, 0.08, 0.96)
	st_bg.border_width_left = 2; st_bg.border_width_top = 2
	st_bg.border_width_right = 2; st_bg.border_width_bottom = 2
	st_bg.border_color = Color(0.88, 0.68, 0.28, 0.75) # Instrument Amber
	st_bg.corner_radius_top_left = 12; st_bg.corner_radius_top_right = 12
	st_bg.corner_radius_bottom_left = 12; st_bg.corner_radius_bottom_right = 12
	st_bg.shadow_color = Color(0, 0, 0, 0.8)
	st_bg.shadow_size = 18
	modal.add_theme_stylebox_override("panel", st_bg)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	modal.add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# Encabezado
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "🛠️ AUXILIO MECÁNICO 24/7"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 1.0))
	header_hbox.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕ CERRAR"
	close_btn.custom_minimum_size = Vector2(120, 42)
	var st_close = StyleBoxFlat.new()
	st_close.bg_color = Color(0.78, 0.28, 0.26, 0.90)
	st_close.corner_radius_top_left = 8; st_close.corner_radius_top_right = 8
	st_close.corner_radius_bottom_left = 8; st_close.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", st_close)
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.pressed.connect(func():
		var tw_close = modal.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_close.tween_property(modal, "modulate:a", 0.0, 0.18)
		tw_close.parallel().tween_property(modal, "scale", Vector2(0.94, 0.94), 0.18)
		tw_close.tween_callback(modal.queue_free)
	)
	header_hbox.add_child(close_btn)

	var sub_lbl = Label.new()
	sub_lbl.text = "Despacho satelital de vehículo de auxilio con mecánico a tu ubicación actual en carretera."
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82, 0.90))
	root_vbox.add_child(sub_lbl)

	var sep = HSeparator.new()
	root_vbox.add_child(sep)

	# Scroll y Lista de Tarjetas
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var cards_vbox = VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(cards_vbox)

	var opciones = [
		{
			"tipo": ServicioMecanicoCarretera.TipoServicio.COMBUSTIBLE,
			"icono": "⛽",
			"titulo": "Suministro de Combustible Diésel / Gasolina",
			"desc": "El mecánico arriba con un bidón y suministra 140 L directo al tanque si te quedaste varado.",
			"tarifa": 60000,
			"color": Color(1.0, 0.65, 0.15)
		},
		{
			"tipo": ServicioMecanicoCarretera.TipoServicio.PINCHAZO,
			"icono": "🛞",
			"titulo": "Cambio de Llanta Ponchada / Pinchazo",
			"desc": "El mecánico usa gato hidráulico y llave neumática para montar y calibrar un neumático a 110 PSI.",
			"tarifa": 85000,
			"color": Color(0.25, 0.75, 1.0)
		},
		{
			"tipo": ServicioMecanicoCarretera.TipoServicio.AVERIA_MECANICA,
			"icono": "🔧",
			"titulo": "Reparación de Avería Mecánica / Motor",
			"desc": "Diagnóstico de inyección, circuitos y temperatura para dejar el camión operativo.",
			"tarifa": 120000,
			"color": Color(1.0, 0.80, 0.20)
		},
		{
			"tipo": ServicioMecanicoCarretera.TipoServicio.DESVOLCAR_RESCATE,
			"icono": "🏗️",
			"titulo": "Rescate y Desvolcado con Winche",
			"desc": "Maniobra pesada de estabilización y tracción con winche hidráulico si te volcaste o saliste de la vía.",
			"tarifa": 150000,
			"color": Color(0.92, 0.35, 0.35)
		}
	]

	for opc in opciones:
		var card = _crear_tarjeta_servicio_mecanico(opc, modal)
		cards_vbox.add_child(card)

	phone_frame.add_child(modal)

	# Transición suave (fade + scale)
	modal.pivot_offset = phone_frame.size / 2.0
	modal.scale = Vector2(0.92, 0.92)
	modal.modulate.a = 0.0
	var tw_in = modal.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(modal, "scale", Vector2(1.0, 1.0), 0.28)
	tw_in.parallel().tween_property(modal, "modulate:a", 1.0, 0.24)

func _crear_tarjeta_servicio_mecanico(data: Dictionary, modal: Control) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 95)
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.10, 0.13, 0.92)
	st.border_width_left = 3; st.border_width_top = 1
	st.border_width_right = 1; st.border_width_bottom = 2
	st.border_color = data["color"]
	st.corner_radius_top_left = 8; st.corner_radius_top_right = 8
	st.corner_radius_bottom_left = 8; st.corner_radius_bottom_right = 8
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 6
	panel.add_theme_stylebox_override("panel", st)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var icon_lbl = Label.new()
	icon_lbl.text = data["icono"]
	icon_lbl.add_theme_font_size_override("font_size", 38)
	hbox.add_child(icon_lbl)

	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(text_vbox)

	var title_lbl = Label.new()
	title_lbl.text = data["titulo"]
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	text_vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.75, 0.80))
	text_vbox.add_child(desc_lbl)

	# Botón de llamada con precio
	var btn_call = Button.new()
	btn_call.text = "LLAMAR\n$ %s" % _formatear_pesos_colombianos(data["tarifa"])
	btn_call.custom_minimum_size = Vector2(150, 60)
	btn_call.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var st_btn = StyleBoxFlat.new()
	st_btn.bg_color = Color(0.10, 0.12, 0.16, 0.90)
	st_btn.border_width_left = 1; st_btn.border_width_top = 1
	st_btn.border_width_right = 1; st_btn.border_width_bottom = 2
	st_btn.border_color = Color(0.88, 0.68, 0.28, 0.85) # Amber border
	st_btn.corner_radius_top_left = 8; st_btn.corner_radius_top_right = 8
	st_btn.corner_radius_bottom_left = 8; st_btn.corner_radius_bottom_right = 8
	st_btn.shadow_color = Color(0.88, 0.68, 0.28, 0.2)
	st_btn.shadow_size = 4
	btn_call.add_theme_stylebox_override("normal", st_btn)
	
	var st_btn_hover = st_btn.duplicate() as StyleBoxFlat
	st_btn_hover.bg_color = Color(0.88, 0.68, 0.28, 0.85)
	btn_call.add_theme_stylebox_override("hover", st_btn_hover)
	btn_call.add_theme_font_size_override("font_size", 17)
	btn_call.add_theme_color_override("font_color", Color.WHITE)

	btn_call.pressed.connect(func():
		modal.queue_free()
		close_phone()
		ServicioMecanicoCarretera.solicitar_servicio(data["tipo"])
	)
	hbox.add_child(btn_call)

	return panel
