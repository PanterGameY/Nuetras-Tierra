# notification_manager.gd - Sistema de notificaciones flotantes
# NUEVO - Completamente diferente al sistema anterior
extends CanvasLayer

# ════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ════════════════════════════════════════════════════════════════
# const NOTIF_SCENE = preload("res://scenes/gui/Notification.tscn")  # No necesitamos escena precompilada
const DURACION_NOTIF: float = 3.0
const ESPACIO_VERTICAL: float = 100.0

# ════════════════════════════════════════════════════════════════
# VARIABLES
# ════════════════════════════════════════════════════════════════
var _notificaciones_activas: Array[Node] = []

# ════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ════════════════════════════════════════════════════════════════
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ════════════════════════════════════════════════════════════════
# API PÚBLICA - Mostrar notificaciones
# ════════════════════════════════════════════════════════════════

## Mostrar notificación simple
func notificar(mensaje: String, tipo: String = "info", duracion: float = DURACION_NOTIF) -> void:
	_crear_notificacion(mensaje, tipo, duracion)

## Notificación de dinero
func notificar_dinero(cantidad: float, operacion: String = "ganado") -> void:
	var _signo = "+" if cantidad > 0 else ""
	var mensaje = "%s $%.2f" % [operacion.capitalize(), abs(cantidad)]
	var tipo = "ganancia" if cantidad > 0 else "perdida"
	_crear_notificacion(mensaje, tipo, 2.5)

## Notificación de alerta
func notificar_alerta(mensaje: String) -> void:
	_crear_notificacion(mensaje, "alerta", 4.0)

## Notificación de alerta gigante (centrada y con font grande de 38)
func notificar_alerta_gigante(mensaje: String, duracion: float = 3.5) -> void:
	var panel = PanelContainer.new()
	var label = Label.new()
	
	label.text = mensaje
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(800, 80)
	
	# Estilo visual rojo y negro semi-transparente premium
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.01, 0.01, 0.9)
	style.border_color = Color(1.0, 0.25, 0.25, 0.95)
	style.set("border_width_left", 6)
	for side in ["top", "right", "bottom"]:
		style.set("border_width_" + side, 0)
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.set_content_margin_all(16)
	
	var theme = Theme.new()
	theme.set_stylebox("panel", "PanelContainer", style)
	
	var font_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	
	panel.theme = theme
	panel.add_child(label)
	add_child(panel)
	
	# Posicionamiento: centrado horizontalmente en la parte superior de la pantalla
	panel.anchor_left = 0.5
	panel.anchor_top = 0.15
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.15
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position.x = get_viewport().get_visible_rect().size.x / 2.0 - 400
	panel.position.y = 120
	
	# Animar entrada (fade in + slide down leve)
	var tween = create_tween().set_parallel(true)
	panel.modulate.a = 0.0
	panel.position.y = 90
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "position:y", 120, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(duracion).timeout
	
	# Animar salida (fade out)
	var tween_out = create_tween()
	tween_out.tween_property(panel, "modulate:a", 0.0, 0.25)
	await tween_out.finished
	panel.queue_free()

## Notificación de éxito
func notificar_exito(mensaje: String) -> void:
	_crear_notificacion(mensaje, "exito", 2.0)

# ════════════════════════════════════════════════════════════════
# CREACIÓN DE NOTIFICACIÓN
# ════════════════════════════════════════════════════════════════
func _crear_notificacion(mensaje: String, tipo: String, duracion: float) -> void:
	var panel = PanelContainer.new()
	var label = Label.new()
	
	# Configurar label
	label.text = mensaje
	label.custom_minimum_size = Vector2(500, 80) # Caja grande y legible
	label.modulate = Color.WHITE
	
	# Agregar estilos según tipo
	_aplicar_estilo(panel, tipo)
	
	# Ensamblar
	panel.add_child(label)
	add_child(panel)
	
	# Posicionar en la parte inferior centrado, idéntico al cuadro de diálogo principal
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(0, 320)
	panel.offset_bottom = -40
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = -360
	
	# Guardar referencia
	_notificaciones_activas.append(panel)
	
	# Animar entrada
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	
	# Animar salida tras duracion
	await get_tree().create_timer(duracion).timeout
	
	var tween_out = create_tween()
	tween_out.set_trans(Tween.TRANS_QUAD)
	tween_out.set_ease(Tween.EASE_IN)
	tween_out.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween_out.finished
	
	# Limpiar
	_notificaciones_activas.erase(panel)
	panel.queue_free()
	
	# Reorganizar otras notificaciones
	_reorganizar_notificaciones()

# ════════════════════════════════════════════════════════════════
# APLICAR ESTILOS SEGÚN TIPO
# ════════════════════════════════════════════════════════════════
func _aplicar_estilo(panel: PanelContainer, _tipo: String) -> void:
	var color_bg = Color(0.04, 0.04, 0.06, 0.95) # Negro azulado profundo premium
	var color_text = Color(0.95, 0.95, 0.98) # Blanco suave
	
	# Crear StyleBox Premium con Borde Dorado Neón
	var style = StyleBoxFlat.new()
	style.bg_color = color_bg
	style.border_color = Color(0.95, 0.80, 0.00, 1.00) # Dorado neón
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.set_content_margin_all(20)
	
	# Crear Theme
	var theme = Theme.new()
	theme.set_stylebox("panel", "PanelContainer", style)
	
	# Obtener label hijo
	if panel.get_child_count() > 0:
		var label = panel.get_child(0)
		label.add_theme_color_override("font_color", color_text)
		
		# Cargar la fuente Moderniz
		var font_path = "res://recursos/fonts/Moderniz.otf"
		if ResourceLoader.exists(font_path):
			label.add_theme_font_override("font", load(font_path))
			
		label.add_theme_font_size_override("font_size", 34) # Tamaño idéntico al diálogo del mensajero
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	panel.theme = theme

# ════════════════════════════════════════════════════════════════
# REORGANIZAR NOTIFICACIONES AL ELIMINAR UNA
# ════════════════════════════════════════════════════════════════
func _reorganizar_notificaciones() -> void:
	for i in range(_notificaciones_activas.size()):
		var notif = _notificaciones_activas[i]
		var pos_y = 50 + (i * ESPACIO_VERTICAL)
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(notif, "position:y", pos_y, 0.3)
