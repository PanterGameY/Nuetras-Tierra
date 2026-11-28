extends Control
class_name ColorWheelPicker

signal color_changed(color: Color)

# ═══════════════════════════════════════════════════════════════════════
# ColorWheelPicker — Selector de color personalizado y ultra-responsivo
# - Renderizado matemático por Shader (sin texturas externas).
# - Cursor interactivo que se expande al tocar.
# - Burbuja flotante de vista previa que sigue el dedo.
# ═══════════════════════════════════════════════════════════════════════

@onready var cursor_dot: Panel = $CursorDot
@onready var bubble_preview: Panel = $BubblePreview

var is_touching: bool = false
var current_hue: float = 0.0
var current_saturation: float = 0.0
var current_value: float = 1.0 # Brillo por defecto

func _ready() -> void:
	if bubble_preview:
		bubble_preview.visible = false
	
	# Colocar cursor en el centro al inicio
	if cursor_dot:
		cursor_dot.position = (size / 2.0) - (cursor_dot.size / 2.0)
		cursor_dot.pivot_offset = cursor_dot.size / 2.0

func _gui_input(event: InputEvent) -> void:
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	var is_touch = event is InputEventScreenTouch
	var is_drag = event is InputEventMouseMotion or event is InputEventScreenDrag

	if is_click or is_touch:
		accept_event()
		var pressed = event.pressed if (is_click or is_touch) else false
		if pressed:
			is_touching = true
			_expand_cursor(true)
			if bubble_preview:
				bubble_preview.visible = true
			_procesar_toque(event.position)
		else:
			is_touching = false
			_expand_cursor(false)
			if bubble_preview:
				bubble_preview.visible = false
			# Emitir color final al soltar
			emit_signal("color_changed", get_selected_color())
			
	elif is_drag and is_touching:
		accept_event()
		_procesar_toque(event.position)

func _procesar_toque(pos: Vector2) -> void:
	var center = size / 2.0
	var offset = pos - center
	var max_radius = size.x / 2.0
	
	# Calcular ángulo y distancia
	var dist = offset.length()
	var angle = atan2(offset.y, offset.x)
	if angle < 0:
		angle += TAU
		
	# Clampar distancia al radio del círculo
	if dist > max_radius:
		dist = max_radius
		
	# Actualizar valores HSV (asegurar brillo visible al elegir en la rueda)
	current_hue = angle / TAU
	current_saturation = dist / max_radius
	if current_value < 0.85:
		current_value = 1.0
	
	# Actualizar posición del cursor
	var cursor_pos = center + Vector2(cos(angle), sin(angle)) * dist
	if cursor_dot:
		cursor_dot.position = cursor_pos - (cursor_dot.size / 2.0)
		
	# Actualizar burbuja flotante
	if bubble_preview:
		# Posicionar burbuja arriba del dedo
		bubble_preview.position = pos - Vector2(bubble_preview.size.x / 2.0, bubble_preview.size.y + 35)
		
		# Cambiar color de la burbuja en tiempo real
		var col = get_selected_color()
		var sb = bubble_preview.get_theme_stylebox("panel")
		if sb:
			var nuevo_sb = sb.duplicate() as StyleBoxFlat
			nuevo_sb.bg_color = col
			bubble_preview.add_theme_stylebox_override("panel", nuevo_sb)
			
	# Emitir cambio de color en tiempo real
	emit_signal("color_changed", get_selected_color())

func _expand_cursor(expand: bool) -> void:
	if not cursor_dot:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	var target_scale = Vector2(1.8, 1.8) if expand else Vector2(1.0, 1.0)
	tween.tween_property(cursor_dot, "scale", target_scale, 0.15)

func set_color_hsv(h: float, s: float, v: float) -> void:
	current_hue = h
	current_saturation = s
	current_value = v
	
	# Actualizar posición física del cursor según HSV
	var center = size / 2.0
	var max_radius = size.x / 2.0
	var angle = h * TAU
	var dist = s * max_radius
	var cursor_pos = center + Vector2(cos(angle), sin(angle)) * dist
	
	if cursor_dot:
		cursor_dot.position = cursor_pos - (cursor_dot.size / 2.0)

func get_selected_color() -> Color:
	return Color.from_hsv(current_hue, current_saturation, current_value)
