extends Control

signal loaded

# --- Referencias de nodos (via node_paths exportados en escena) ---
@export var progress_bar: ProgressBar
@export var shimmer: ColorRect
@export var lbl_percent: Label
@export var news_image: TextureRect
@export var lbl_caption: Label
@export var lbl_slide_num: Label
@export var btn_prev: Button
@export var btn_next: Button
@export var dot1: Panel
@export var dot2: Panel
@export var dot3: Panel

# --- Datos del slideshow ---
var slides: Array = [
	{"caption": "Novedades del mundo NuestraTierra", "image": null},
	{"caption": "Nuevos vehiculos y mapas proximamente", "image": null},
	{"caption": "Participa en eventos y gana recompensas", "image": null},
]
var _current_slide: int = 0
var _slide_timer: float = 0.0
var _sty_dot_on: StyleBoxFlat
var _sty_dot_off: StyleBoxFlat
const SLIDE_INTERVAL: float = 5.0

# --- AdMob ---
var _ad_view: AdView = null
@onready var ad_preview: Control = get_node_or_null("MainVBox/ContentHBox/AdPanel/AdMargen/AdVBox/AdPreview")

func _ready() -> void:
	_build_dot_styles()
	_show_slide(0)
	_animate_progress(4.0)
	_shimmer_loop()
	_pulse_loop()
	# Signals de navegacion conectadas desde la escena (TSCN)
	# Inicializar AdMob (no-op en escritorio, funciona en Android/iOS)
	_initialize_admob()
	# Mostrar placeholder en editor/PC, ocultar en mobile (si el plugin muestra ad nativo)
	if ad_preview:
		var os_name := OS.get_name()
		if os_name == "Android" or os_name == "iOS":
			ad_preview.visible = false
		else:
			ad_preview.visible = true

func _process(delta: float) -> void:
	# Actualizar label de porcentaje
	if lbl_percent and progress_bar:
		lbl_percent.text = str(int(progress_bar.value)) + "%"
	# Avance automatico del slideshow
	_slide_timer += delta
	if _slide_timer >= SLIDE_INTERVAL:
		_slide_timer = 0.0
		_current_slide = (_current_slide + 1) % slides.size()
		_show_slide(_current_slide)

# =============================================================================
# AdMob - Test Banner (AdPosition.Values.TOP_LEFT cubre el AdPanel izquierdo)
# =============================================================================

func _initialize_admob() -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_admob_initialized
	MobileAds.initialize(listener)

func _on_admob_initialized(_status) -> void:
	_load_test_banner()

func _load_test_banner() -> void:
	# Test banner ID de Google AdMob
	const TEST_BANNER_ID := "ca-app-pub-3940256099942544/2934735716"
	var ad_size := AdSize.MEDIUM_RECTANGLE  # 300x250 dp
	_ad_view = AdView.new(TEST_BANNER_ID, ad_size, AdPosition.Values.TOP_LEFT)
	var listener := AdListener.new()
	listener.on_ad_loaded = _on_banner_loaded
	listener.on_ad_failed_to_load = func(err: LoadAdError) -> void:
		print("[AdMob] Banner fallo al cargar: " + err.message)
	_ad_view.ad_listener = listener
	_ad_view.load_ad(AdRequest.new())

func _on_banner_loaded() -> void:
	if _ad_view:
		# Ocultar el preview si el banner nativo se muestra
		if ad_preview:
			ad_preview.visible = false
		_ad_view.show()

func _destroy_ad() -> void:
	if _ad_view:
		_ad_view.destroy()
		_ad_view = null
	# restablecer preview si aplicable
	if ad_preview:
		ad_preview.visible = true

# =============================================================================
# Slideshow
# =============================================================================

func _build_dot_styles() -> void:
	_sty_dot_on = StyleBoxFlat.new()
	_sty_dot_on.bg_color = Color(0.25, 0.4, 0.9, 1.0)
	_sty_dot_on.corner_radius_top_left = 6
	_sty_dot_on.corner_radius_top_right = 6
	_sty_dot_on.corner_radius_bottom_right = 6
	_sty_dot_on.corner_radius_bottom_left = 6
	_sty_dot_off = StyleBoxFlat.new()
	_sty_dot_off.bg_color = Color(0.3, 0.3, 0.3, 0.6)
	_sty_dot_off.corner_radius_top_left = 6
	_sty_dot_off.corner_radius_top_right = 6
	_sty_dot_off.corner_radius_bottom_right = 6
	_sty_dot_off.corner_radius_bottom_left = 6

func _show_slide(idx: int) -> void:
	if lbl_caption:
		lbl_caption.text = slides[idx].get("caption", "")
	if lbl_slide_num:
		lbl_slide_num.text = str(idx + 1) + " / " + str(slides.size())
	if news_image:
		var tex = slides[idx].get("image", null)
		news_image.texture = tex
	var dots: Array = [dot1, dot2, dot3]
	for i in dots.size():
		if dots[i]:
			dots[i].add_theme_stylebox_override("panel", _sty_dot_on if i == idx else _sty_dot_off)

func _on_prev() -> void:
	_current_slide = (_current_slide - 1 + slides.size()) % slides.size()
	_slide_timer = 0.0
	_show_slide(_current_slide)

func _on_next() -> void:
	_current_slide = (_current_slide + 1) % slides.size()
	_slide_timer = 0.0
	_show_slide(_current_slide)

# =============================================================================
# Barra de progreso
# =============================================================================

func _animate_progress(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(progress_bar, "value", 100.0, duration).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_on_progress_done)

func _on_progress_done() -> void:
	_destroy_ad()
	loaded.emit()

func set_progress(value: float) -> void:
	if progress_bar:
		progress_bar.value = value
	if lbl_percent:
		lbl_percent.text = str(int(value)) + "%"

# =============================================================================
# Efectos visuales
# =============================================================================

func _shimmer_loop() -> void:
	if not shimmer or not progress_bar:
		return
	var bar_w: float = progress_bar.size.x
	var shim_w: float = shimmer.size.x if shimmer.size.x > 0 else 240.0
	shimmer.position = Vector2(-shim_w, 0.0)
	while is_inside_tree():
		var tw := create_tween()
		tw.tween_property(shimmer, "position:x", bar_w, 1.4)
		await tw.finished
		shimmer.position = Vector2(-shim_w, 0.0)
		await get_tree().create_timer(0.5).timeout

func _pulse_loop() -> void:
	if not progress_bar:
		return
	while is_inside_tree():
		var tw := create_tween()
		tw.tween_property(progress_bar, "modulate:a", 0.7, 0.6)
		tw.tween_property(progress_bar, "modulate:a", 1.0, 0.6)
		await tw.finished
