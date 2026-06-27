extends CanvasLayer
# FPScontador.gd
# Este script crea y gestiona un contador de FPS premium en la parte inferior de la pantalla.
# Puedes instanciar esta escena o simplemente añadir este script a un nodo CanvasLayer en tu escena.
var fps_label: Label
func _ready() -> void:
	# Ajustar la capa para asegurar que esté por encima de otros elementos de la interfaz
	layer = 128
	
	# Crear un contenedor de control para posicionar el contador
	var UI_container = Control.new()
	UI_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI_container)
	
	# Crear un panel de fondo sutil (Glassmorphic style)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Posicionarlo un poco separado del borde inferior
	panel.position.y -= 20
	UI_container.add_child(panel)
	
	# Estilo del panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.6) # Fondo negro semi-transparente
	style_box.corner_detail = 8
	style_box.set_corner_radius_all(10)
	style_box.set_content_margin_all(8)
	style_box.shadow_color = Color(0, 0, 0, 0.3)
	style_box.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Crear la etiqueta para mostrar los FPS
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Ajustar tamaño de fuente a 15
	fps_label.add_theme_constant_override("font_size", 30)

	# Sombra de texto para legibilidad premium
	fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	fps_label.add_theme_constant_override("shadow_offset_x", 1)
	fps_label.add_theme_constant_override("shadow_offset_y", 1)
	fps_label.add_theme_constant_override("shadow_outline_size", 2)
	
	panel.add_child(fps_label)
func _process(_delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	
	# Cambiar dinámicamente el color del texto según los FPS
	if fps >= 50:
		fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4)) # Verde (Estable)
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Amarillo/Naranja (Aceptable)
	else:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Rojo (Bajo rendimiento)
