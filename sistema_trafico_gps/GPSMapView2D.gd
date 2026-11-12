extends PanelContainer
class_name GPSMapView2D

## ══════════════════════════════════════════════════════════════════════════════
##  GPSMapView2D.gd
##  Interfaz Gráfica UI 2D de GPS y Mapa de Tráfico estilo Glassmorphic Cyberpunk.
##  Cumple estrictamente con el manual de diseño UI (RULE[AGENTS.md]).
## ══════════════════════════════════════════════════════════════════════════════

signal route_requested(destination_3d: Vector3)

@export var gps_manager: GPSManager2D = null

# Referencias a la fuente Moderniz.otf
const FONT_MODERNIZ_PATH = "res://recursos/fonts/Moderniz.otf"
var loaded_font: Font = null

# Elementos de la interfaz UI
var title_label: Label = null
var instruction_label: Label = null
var distance_label: Label = null
var map_viewport_container: Control = null
var btn_calculate_route: Button = null
var btn_center_map: Button = null
var btn_close: Button = null

# Variables del Mapa 2D
var player_pos_2d: Vector2 = Vector2(300, 300)
var player_rotation_rad: float = 0.0
var destination_pos_2d: Vector2 = Vector2.ZERO
var has_active_destination: bool = false
var current_route_2d: PackedVector2Array = PackedVector2Array()

# Desplazamiento y Zoom del mapa 2D
var view_center_offset: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0

func _ready() -> void:
	_load_custom_font()
	_apply_glassmorphic_style()
	_build_ui_layout()
	
	if gps_manager:
		gps_manager.gps_route_updated.connect(_on_route_updated)
		gps_manager.vehicle_position_updated.connect(_on_vehicle_position_updated)
		
	# Animación de Entrada Suave (RULE[AGENTS.md])
	animate_open()

func _load_custom_font() -> void:
	if ResourceLoader.exists(FONT_MODERNIZ_PATH):
		loaded_font = load(FONT_MODERNIZ_PATH) as Font

func _apply_glassmorphic_style() -> void:
	custom_minimum_size = Vector2(1100, 680)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.90)  # Vidrio oscuro esmerilado
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.00, 0.45, 0.00, 0.80) # Naranja Neón alta visibilidad
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 35
	style.content_margin_bottom = 35
	
	add_theme_stylebox_override("panel", style)

func _build_ui_layout() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# 1. CABECERA CON TÍTULO 48PX
	title_label = Label.new()
	title_label.text = "SISTEMA GPS Y TRÁFICO VIAL 2D"
	title_label.add_theme_color_override("font_color", Color(1.00, 0.45, 0.00, 1.0))
	title_label.add_theme_font_size_override("font_size", 48)
	if loaded_font:
		title_label.add_theme_font_override("font", loaded_font)
	main_vbox.add_child(title_label)
	
	# 2. ÁREA CENTRAL (MAPA 2D + PANEL INFORMACIÓN)
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 25)
	main_vbox.add_child(content_hbox)
	
	# Lienzo de Renderizado del Mapa 2D
	map_viewport_container = Control.new()
	map_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_viewport_container.size_flags_stretch_ratio = 2.0
	map_viewport_container.custom_minimum_size = Vector2(600, 420)
	map_viewport_container.clip_contents = true
	map_viewport_container.draw.connect(_on_map_draw)
	content_hbox.add_child(map_viewport_container)
	
	# Panel Lateral de Telemetría e Instrucciones (Texto >= 28px)
	var info_panel = VBoxContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.add_theme_constant_override("separation", 15)
	content_hbox.add_child(info_panel)
	
	var inst_header = Label.new()
	inst_header.text = "INDICACIÓN DE RUTA:"
	inst_header.add_theme_font_size_override("font_size", 28)
	inst_header.add_theme_color_override("font_color", Color(0.20, 0.60, 1.00, 1.0))
	if loaded_font:
		inst_header.add_theme_font_override("font", loaded_font)
	info_panel.add_child(inst_header)
	
	instruction_label = Label.new()
	instruction_label.text = "• Inicie navegación o seleccione destino"
	instruction_label.add_theme_font_size_override("font_size", 28)
	instruction_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90, 1.0))
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(instruction_label)
	
	distance_label = Label.new()
	distance_label.text = "Distancia Total: --- km"
	distance_label.add_theme_font_size_override("font_size", 28)
	distance_label.add_theme_color_override("font_color", Color(1.00, 0.84, 0.00, 1.0))
	info_panel.add_child(distance_label)
	
	# 3. BOTONES DE ACCIÓN (Altura 80px, Esquinas 12px, Texto 32px Moderniz)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(btn_hbox)
	
	btn_calculate_route = _create_action_button("CALCULAR RUTA", Color(1.00, 0.45, 0.00, 1.0))
	btn_calculate_route.pressed.connect(_on_btn_calculate_pressed)
	btn_hbox.add_child(btn_calculate_route)
	
	btn_center_map = _create_action_button("CENTRAR MAPA", Color(0.20, 0.60, 1.00, 1.0))
	btn_center_map.pressed.connect(_on_btn_center_pressed)
	btn_hbox.add_child(btn_center_map)
	
	btn_close = _create_action_button("CERRAR GPS", Color(0.90, 0.30, 0.30, 1.0))
	btn_close.pressed.connect(animate_close)
	btn_hbox.add_child(btn_close)

func _create_action_button(text: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_st = StyleBoxFlat.new()
	btn_st.bg_color = bg_color
	btn_st.corner_radius_top_left = 12
	btn_st.corner_radius_top_right = 12
	btn_st.corner_radius_bottom_left = 12
	btn_st.corner_radius_bottom_right = 12
	
	var btn_hover = btn_st.duplicate() as StyleBoxFlat
	btn_hover.bg_color = bg_color.lightened(0.15)
	
	btn.add_theme_stylebox_override("normal", btn_st)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_st)
	btn.add_theme_font_size_override("font_size", 32)
	
	if loaded_font:
		btn.add_theme_font_override("font", loaded_font)
		
	return btn

func animate_open() -> void:
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	pivot_offset = size * 0.5
	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

func animate_close() -> void:
	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.20)
	tw.chain().tween_callback(queue_free)

func _process(_delta: float) -> void:
	if map_viewport_container:
		map_viewport_container.queue_redraw()

func _on_map_draw() -> void:
	if not map_viewport_container:
		return
		
	var center = map_viewport_container.size * 0.5 + view_center_offset
	
	# Fondo del mapa (Malla Cyberpunk)
	map_viewport_container.draw_rect(Rect2(Vector2.ZERO, map_viewport_container.size), Color(0.04, 0.04, 0.06, 1.0), true)
	
	# Dibujar cuadrícula de coordenadas 2D
	var step = 50.0 * zoom_level
	for x in range(0, int(map_viewport_container.size.x), int(step)):
		map_viewport_container.draw_line(Vector2(x, 0), Vector2(x, map_viewport_container.size.y), Color(0.12, 0.14, 0.20, 0.5), 1.0)
	for y in range(0, int(map_viewport_container.size.y), int(step)):
		map_viewport_container.draw_line(Vector2(0, y), Vector2(map_viewport_container.size.x, y), Color(0.12, 0.14, 0.20, 0.5), 1.0)
		
	# Dibujar Red Vial de Carriles (Líneas 2D)
	if gps_manager:
		var lanes_2d = gps_manager.get_lanes_2d_polylines()
		for lane_pts in lanes_2d:
			if lane_pts.size() >= 2:
				var transformed_pts = PackedVector2Array()
				for pt in lane_pts:
					transformed_pts.append(center + (pt - player_pos_2d) * zoom_level)
				map_viewport_container.draw_polyline(transformed_pts, Color(0.20, 0.50, 0.80, 0.7), 4.0 * zoom_level, true)
				
	# Dibujar Ruta de Navegación Activa (Resplandor Neón Naranja/Azul)
	if not current_route_2d.is_empty():
		var route_trans = PackedVector2Array()
		for pt in current_route_2d:
			route_trans.append(center + (pt - player_pos_2d) * zoom_level)
		map_viewport_container.draw_polyline(route_trans, Color(1.00, 0.45, 0.00, 0.9), 8.0 * zoom_level, true)
		map_viewport_container.draw_polyline(route_trans, Color(1.00, 0.84, 0.00, 1.0), 3.0 * zoom_level, true)

	# Dibujar Marcador de Destino
	if has_active_destination:
		var dest_draw_pos = center + (destination_pos_2d - player_pos_2d) * zoom_level
		map_viewport_container.draw_circle(dest_draw_pos, 12.0, Color(1.00, 0.84, 0.00, 1.0))
		map_viewport_container.draw_arc(dest_draw_pos, 18.0, 0, TAU, 32, Color(1.00, 0.45, 0.00, 0.9), 3.0)

	# Dibujar Icono del Vehículo / Jugador (Triángulo orientado en 2D)
	var arrow_size = 14.0 * zoom_level
	var p1 = center + Vector2(0, -arrow_size).rotated(player_rotation_rad)
	var p2 = center + Vector2(-arrow_size * 0.7, arrow_size).rotated(player_rotation_rad)
	var p3 = center + Vector2(arrow_size * 0.7, arrow_size).rotated(player_rotation_rad)
	var pts = PackedVector2Array([p1, p2, p3])
	map_viewport_container.draw_polygon(pts, PackedColorArray([Color(0.00, 1.00, 0.80, 1.0), Color(0.00, 1.00, 0.80, 1.0), Color(0.00, 1.00, 0.80, 1.0)]))

func _on_vehicle_position_updated(_vehicle_id: String, pos_2d: Vector2, rotation_rad: float) -> void:
	player_pos_2d = pos_2d
	player_rotation_rad = rotation_rad

func _on_route_updated(points_2d: PackedVector2Array, total_dist_m: float, instructions: Array) -> void:
	current_route_2d = points_2d
	distance_label.text = "Distancia Total: %.2f km" % (total_dist_m / 1000.0)
	
	if not instructions.is_empty():
		var first_inst = instructions[0]
		instruction_label.text = "• " + first_inst["instruction"]
		if points_2d.size() > 0:
			destination_pos_2d = points_2d[-1]
			has_active_destination = true
	else:
		instruction_label.text = "• Ruta no disponible o sin maniobras."

func _on_btn_calculate_pressed() -> void:
	# Emitir solicitud de cálculo hacia destino o punto de prueba
	if gps_manager and gps_manager.tracked_target_3d:
		var start_3d = gps_manager.tracked_target_3d.global_position
		# Destino de prueba a +100m en Z
		var dest_3d = start_3d + Vector3(80, 0, -120)
		gps_manager.calculate_route(start_3d, dest_3d)

func _on_btn_center_pressed() -> void:
	view_center_offset = Vector2.ZERO
	zoom_level = 1.0
