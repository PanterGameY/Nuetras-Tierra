extends Button

@export var hover_color: Color = Color("#f5ca20") # Dorado
var original_color: Color

func _ready():
	original_color = get_theme_color("font_color")
	
	# Conectamos señales por código para que sea automático
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func _on_mouse_entered():
	# Efecto de escala pequeña y cambio de color
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	add_theme_color_override("font_color", hover_color)

func _on_mouse_exited():
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	add_theme_color_override("font_color", original_color)

func _on_pressed():
	# Efecto de "clic" rápido
	scale = Vector2(0.95, 0.95)
	create_tween().tween_property(self, "scale", Vector2(1.05, 1.05), 0.05)