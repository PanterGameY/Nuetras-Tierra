extends Button
# Script para botones del vehículo con shader dinámico

@export var color_activo: Color = Color.YELLOW
@export var color_inactivo: Color = Color.WHITE
@export var brillo_activo: float = 1.4

var _material: ShaderMaterial

func _ready() -> void:
	# Crear material con shader
	_material = ShaderMaterial.new()
	_material.shader = load("res://scenes/gui/BotonVehiculo.gdshader")
	
	# Aplicar configuración inicial
	_material.set_shader_parameter("color_activo", color_activo)
	_material.set_shader_parameter("color_inactivo", color_inactivo)
	_material.set_shader_parameter("brillo_activo", brillo_activo)
	_material.set_shader_parameter("activo", button_pressed)
	
	self_modulate = Color.WHITE
	
	# Usar TextureButton o CustomButton con el material
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.YELLOW)
	
	# Conectar cambios de estado
	toggled.connect(_on_button_toggled)

func _process(_delta: float) -> void:
	if _material:
		_material.set_shader_parameter("activo", button_pressed)

func _on_button_toggled(state: bool) -> void:
	if _material:
		_material.set_shader_parameter("activo", state)
