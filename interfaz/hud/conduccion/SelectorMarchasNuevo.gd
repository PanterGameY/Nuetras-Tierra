extends Control

# ═══════════════════════════════════════════════════════════════════════
# SelectorMarchasNuevo.gd — Selector de Transmisión Automotriz Sobrio (D / N / R)
# Cero dependencias estáticas de compilación (resolución vía /root/InputVehiculo)
# ═══════════════════════════════════════════════════════════════════════

signal marcha_cambiada(marcha: String)

const MARCHA_REVERSA: int = 1
const MARCHA_NEUTRO: int = 2
const MARCHA_DRIVE: int = 3

var marcha_actual: String = "N"
var _iv_cache: Node = null

@onready var btn_d: Button = get_node_or_null("BtnDelante") as Button
@onready var btn_n: Button = get_node_or_null("BtnNeutro") as Button
@onready var btn_r: Button = get_node_or_null("BtnReversa") as Button

var _style_normal: StyleBoxFlat
var _style_d_activo: StyleBoxFlat
var _style_n_activo: StyleBoxFlat
var _style_r_activo: StyleBoxFlat

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

func _ready() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.08, 0.09, 0.11, 0.72)
	_style_normal.border_width_left = 1
	_style_normal.border_width_top = 1
	_style_normal.border_width_right = 1
	_style_normal.border_width_bottom = 1
	_style_normal.border_color = Color(1.0, 1.0, 1.0, 0.10)
	_style_normal.corner_radius_top_left = 6
	_style_normal.corner_radius_top_right = 6
	_style_normal.corner_radius_bottom_left = 6
	_style_normal.corner_radius_bottom_right = 6

	_style_d_activo = _style_normal.duplicate()
	_style_d_activo.bg_color = Color(0.16, 0.19, 0.23, 0.94)
	_style_d_activo.border_width_bottom = 2
	_style_d_activo.border_color = Color(0.88, 0.70, 0.32, 0.92)

	_style_n_activo = _style_normal.duplicate()
	_style_n_activo.bg_color = Color(0.15, 0.16, 0.19, 0.94)
	_style_n_activo.border_width_bottom = 2
	_style_n_activo.border_color = Color(0.78, 0.82, 0.86, 0.85)

	_style_r_activo = _style_normal.duplicate()
	_style_r_activo.bg_color = Color(0.24, 0.11, 0.11, 0.94)
	_style_r_activo.border_width_bottom = 2
	_style_r_activo.border_color = Color(0.82, 0.32, 0.30, 0.92)

	if btn_d and not btn_d.pressed.is_connected(_on_marcha_seleccionada):
		btn_d.pressed.connect(_on_marcha_seleccionada.bind("D"))
	if btn_n and not btn_n.pressed.is_connected(_on_marcha_seleccionada):
		btn_n.pressed.connect(_on_marcha_seleccionada.bind("N"))
	if btn_r and not btn_r.pressed.is_connected(_on_marcha_seleccionada):
		btn_r.pressed.connect(_on_marcha_seleccionada.bind("R"))

	_actualizar_visuales()

func _process(_delta: float) -> void:
	var iv = _get_iv()
	if is_instance_valid(iv) and "marcha" in iv and iv.marcha != marcha_actual:
		set_marcha_visual(str(iv.marcha))

func _on_marcha_seleccionada(id: String) -> void:
	marcha_actual = id
	var iv = _get_iv()
	if is_instance_valid(iv):
		match id:
			"D":
				if iv.has_method("set_marcha_enum"):
					iv.call("set_marcha_enum", MARCHA_DRIVE)
				if iv.has_method("set_fmano"):
					iv.call("set_fmano", false)
			"N":
				if iv.has_method("set_marcha_enum"):
					iv.call("set_marcha_enum", MARCHA_NEUTRO)
			"R":
				if iv.has_method("set_marcha_enum"):
					iv.call("set_marcha_enum", MARCHA_REVERSA)
				if iv.has_method("set_fmano"):
					iv.call("set_fmano", false)
	_actualizar_visuales()
	marcha_cambiada.emit(marcha_actual)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(30)

func _actualizar_visuales() -> void:
	if btn_d:
		var st_d = _style_d_activo if marcha_actual == "D" else _style_normal
		btn_d.add_theme_stylebox_override("normal", st_d)
		btn_d.add_theme_stylebox_override("hover", st_d)
		btn_d.add_theme_stylebox_override("pressed", _style_d_activo)
		btn_d.add_theme_color_override("font_color", Color(0.95, 0.80, 0.42, 1.0) if marcha_actual == "D" else Color(0.55, 0.58, 0.64, 0.75))
	if btn_n:
		var st_n = _style_n_activo if marcha_actual == "N" else _style_normal
		btn_n.add_theme_stylebox_override("normal", st_n)
		btn_n.add_theme_stylebox_override("hover", st_n)
		btn_n.add_theme_stylebox_override("pressed", _style_n_activo)
		btn_n.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 1.0) if marcha_actual == "N" else Color(0.55, 0.58, 0.64, 0.75))
	if btn_r:
		var st_r = _style_r_activo if marcha_actual == "R" else _style_normal
		btn_r.add_theme_stylebox_override("normal", st_r)
		btn_r.add_theme_stylebox_override("hover", st_r)
		btn_r.add_theme_stylebox_override("pressed", _style_r_activo)
		btn_r.add_theme_color_override("font_color", Color(0.95, 0.45, 0.42, 1.0) if marcha_actual == "R" else Color(0.55, 0.58, 0.64, 0.75))

func set_marcha_visual(marcha: String) -> void:
	if marcha in ["R", "N", "D"]:
		marcha_actual = marcha
	else:
		marcha_actual = "N"
	_actualizar_visuales()
