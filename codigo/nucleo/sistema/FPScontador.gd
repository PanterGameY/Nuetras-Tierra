extends CanvasLayer
# FPScontador.gd
# Este script crea y gestiona un contador de FPS premium, compacto y no intrusivo en la esquina inferior izquierda.

# ==========================================
# CONFIGURACIÓN (Variables exportadas)
# ==========================================
@export_group("Apariencia")
@export var font_size: int = 14
@export var font_path: String = "res://recursos/fonts/Moderniz.otf"
@export var shadow_offset: Vector2 = Vector2(1, 1)
@export var shadow_outline_size: int = 1

@export_group("Colores")
@export var color_stable: Color = Color(0.2, 1.0, 0.4)    # Verde para FPS altos (>= 50)
@export var color_warning: Color = Color(1.0, 0.8, 0.2)   # Amarillo para FPS medios (30 - 49)
@export var color_danger: Color = Color(1.0, 0.2, 0.2)    # Rojo para FPS bajos (< 30)

@export_group("Diseño")
@export var margin_left: float = 16.0                      # Separación desde el borde izquierdo
@export var margin_bottom: float = 14.0                    # Separación desde el borde inferior
@export var bottom_offset: float = -14.0                   # Compatibilidad hacia atrás

# ==========================================

var fps_label: Label
var _update_timer: float = 0.0

func _ready() -> void:
	# Ajustar la capa para asegurar que esté por encima de otros elementos de la interfaz
	layer = 128
	
	# Crear un contenedor de control a pantalla completa que no intercepte clics ni toques
	var UI_container = Control.new()
	UI_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI_container)
	
	# Contenedor de margen anclado a la esquina inferior izquierda
	var margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin_container.grow_horizontal = Control.GROW_DIRECTION_END
	margin_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_theme_constant_override("margin_left", int(margin_left))
	margin_container.add_theme_constant_override("margin_bottom", int(margin_bottom))
	UI_container.add_child(margin_container)
	
	# Crear un panel de fondo sutil y compacto (Glassmorphic style)
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_child(panel)
	
	# Estilo del panel pequeño y no intrusivo
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.04, 0.04, 0.06, 0.6) # Fondo negro semi-transparente discreto
	style_box.corner_detail = 6
	style_box.set_corner_radius_all(6)
	style_box.content_margin_left = 7
	style_box.content_margin_right = 7
	style_box.content_margin_top = 2
	style_box.content_margin_bottom = 2
	style_box.shadow_color = Color(0, 0, 0, 0.25)
	style_box.shadow_size = 2
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Crear la etiqueta para mostrar los FPS
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Cargar la fuente personalizada si existe
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)
		fps_label.add_theme_font_override("font", custom_font)
	else:
		push_warning("No se encontró la fuente en la ruta: " + font_path)
	
	# Aplicar el tamaño compacto de la fuente
	fps_label.add_theme_font_size_override("font_size", font_size)
	
	# Sombra de texto para legibilidad premium
	fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	fps_label.add_theme_constant_override("shadow_offset_x", shadow_offset.x)
	fps_label.add_theme_constant_override("shadow_offset_y", shadow_offset.y)
	fps_label.add_theme_constant_override("shadow_outline_size", shadow_outline_size)
	
	panel.add_child(fps_label)

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < 0.12:
		return
	_update_timer = 0.0

	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	
	# Cambiar dinámicamente el color del texto según los FPS
	if fps >= 50:
		fps_label.add_theme_color_override("font_color", color_stable)
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", color_warning)
	else:
		fps_label.add_theme_color_override("font_color", color_danger)
