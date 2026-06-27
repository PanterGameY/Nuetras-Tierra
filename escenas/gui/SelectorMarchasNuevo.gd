extends Control

signal marcha_cambiada(marcha: String)

var marcha_actual: String = "N"

@onready var btn_r: Button = $BtnReversa
@onready var btn_d: Button = $BtnDelante

var _style_normal: StyleBoxFlat
var _style_r_activo: StyleBoxFlat
var _style_d_activo: StyleBoxFlat

func _ready() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	_style_normal.corner_radius_top_left = 30
	_style_normal.corner_radius_top_right = 30
	_style_normal.corner_radius_bottom_left = 30
	_style_normal.corner_radius_bottom_right = 30

	_style_r_activo = _style_normal.duplicate()
	_style_r_activo.bg_color = Color(0.75, 0.05, 0.05, 1.0)

	_style_d_activo = _style_normal.duplicate()
	_style_d_activo.bg_color = Color(0.05, 0.55, 0.05, 1.0)

	if btn_r:
		btn_r.pressed.connect(_on_marcha_seleccionada.bind("R"))
	if btn_d:
		btn_d.pressed.connect(_on_marcha_seleccionada.bind("D"))

	_actualizar_visuales()

func _on_marcha_seleccionada(id: String) -> void:
	marcha_actual = id
	if is_instance_valid(InputVehiculo):
		match id:
			"R":
				InputVehiculo.set_marcha_enum(InputVehiculo.Marcha.REVERSA)
				InputVehiculo.set_fmano(false)
			"D":
				InputVehiculo.set_marcha_enum(InputVehiculo.Marcha.DRIVE)
				InputVehiculo.set_fmano(false)
	_actualizar_visuales()
	marcha_cambiada.emit(marcha_actual)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(50)

func _actualizar_visuales() -> void:
	if btn_r:
		btn_r.add_theme_stylebox_override("normal",   _style_r_activo if marcha_actual == "R" else _style_normal)
		btn_r.add_theme_stylebox_override("hover",    _style_r_activo if marcha_actual == "R" else _style_normal)
		btn_r.add_theme_stylebox_override("pressed",  _style_r_activo)
		btn_r.add_theme_color_override("font_color",
			Color(1, 1, 1, 1) if marcha_actual == "R" else Color(0.5, 0.5, 0.5, 0.8))
	if btn_d:
		btn_d.add_theme_stylebox_override("normal",   _style_d_activo if marcha_actual == "D" else _style_normal)
		btn_d.add_theme_stylebox_override("hover",    _style_d_activo if marcha_actual == "D" else _style_normal)
		btn_d.add_theme_stylebox_override("pressed",  _style_d_activo)
		btn_d.add_theme_color_override("font_color",
			Color(1, 1, 1, 1) if marcha_actual == "D" else Color(0.5, 0.5, 0.5, 0.8))

func set_marcha_visual(marcha: String) -> void:
	if marcha in ["R", "D"]:
		marcha_actual = marcha
	else:
		marcha_actual = "N"
	_actualizar_visuales()
