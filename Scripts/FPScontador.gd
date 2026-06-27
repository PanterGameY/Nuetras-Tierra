extends CanvasLayer
# FPScontador.gd
# Este script crea y gestiona un contador de FPS premium en la parte inferior de la pantalla.

# ==========================================
# CONFIGURACIÓN (Variables exportadas)
# ==========================================
@export_group("Apariencia")
@export var font_size: int = 24
@export var font_path: String = "res://recursos/fonts/Moderniz.otf"
@export var shadow_offset: Vector2 = Vector2(2, 2)
@export var shadow_outline_size: int = 3

@export_group("Colores")
@export var color_stable: Color = Color(0.2, 1.0, 0.4)    # Verde para FPS altos (>= 50)
@export var color_warning: Color = Color(1.0, 0.8, 0.2)   # Amarillo para FPS medios (30 - 49)
@export var color_danger: Color = Color(1.0, 0.2, 0.2)    # Rojo para FPS bajos (< 30)

@export_group("Diseño")
@export var bottom_offset: float = -20.0                  # Separación desde el borde inferior

# ==========================================

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
	# Posicionarlo separado del borde inferior
	panel.position.y += bottom_offset
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
	
	# Cargar la fuente personalizada si existe
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)
		fps_label.add_theme_font_override("font", custom_font)
	else:
		push_warning("No se encontró la fuente en la ruta: " + font_path)
	
	# Aplicar el tamaño de la fuente
	fps_label.add_theme_font_size_override("font_size", font_size)
	
	# Sombra de texto para legibilidad premium
	fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	fps_label.add_theme_constant_override("shadow_offset_x", shadow_offset.x)
	fps_label.add_theme_constant_override("shadow_offset_y", shadow_offset.y)
	fps_label.add_theme_constant_override("shadow_outline_size", shadow_outline_size)
	
	panel.add_child(fps_label)

func _process(_delta: float) -> void:
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	
	# Cambiar dinámicamente el color del texto según los FPS
	if fps >= 50:
		fps_label.add_theme_color_override("font_color", color_stable)
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", color_warning)
	else:
		fps_label.add_theme_color_override("font_color", color_danger)
