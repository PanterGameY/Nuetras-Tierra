@tool
extends Node3D
class_name ConcesionarioSpawnPoint

@export_group("Visuales del Checkpoint")
@export var checkpoint_color: Color = Color(1.0, 0.65, 0.0, 0.45):
	set(val):
		checkpoint_color = val
		_update_visuals()
@export var checkpoint_radius: float = 1.8:
	set(val):
		checkpoint_radius = val
		_update_visuals()
@export var checkpoint_height: float = 3.5:
	set(val):
		checkpoint_height = val
		_update_visuals()
@export var pulse_speed: float = 1.5:
	set(val):
		pulse_speed = val
		_update_visuals()
@export var pulse_strength: float = 0.08:
	set(val):
		pulse_strength = val
		_update_visuals()
@export var scan_speed: float = 2.5:
	set(val):
		scan_speed = val
		_update_visuals()

@export_group("Teleportacion y Spawn")
@export var teleport_target: Marker3D = null
@export var vehicle_spawn_marker: Marker3D = null

@export_group("Vehiculos en Venta")
@export var vehiculos_en_venta: Array[ConcesionarioVehiculo] = []

var label_3d: Label3D = null
var player_inside: bool = false
var dialogue_ui: CanvasLayer = null

var selected_vehicle: ConcesionarioVehiculo = null
var preview_viewport: SubViewport = null
var preview_anchor: Node3D = null
var preview_camera: Camera3D = null
var preview_model: Node3D = null
var preview_rotation_speed: float = 0.6


func _ready() -> void:
	var legacy_visual = get_node_or_null("_EditorVisual")
	if legacy_visual:
		legacy_visual.queue_free()
	_update_visuals()
	if not Engine.is_editor_hint():
		add_to_group("ConcesionarioSpawnPoint")
		print("[ConcesionarioSpawnPoint] Registrado en escena en: ", global_position)


func _update_visuals() -> void:
	if not is_inside_tree():
		return

	var marker_node = get_node_or_null("Marker3D") as Marker3D
	if not marker_node:
		marker_node = Marker3D.new()
		marker_node.name = "Marker3D"
		add_child(marker_node)
		if Engine.is_editor_hint():
			marker_node.owner = get_tree().edited_scene_root

	var checkpoint_mesh = marker_node.get_node_or_null("CheckpointVisual") as MeshInstance3D
	if not checkpoint_mesh:
		checkpoint_mesh = MeshInstance3D.new()
		checkpoint_mesh.name = "CheckpointVisual"
		marker_node.add_child(checkpoint_mesh)
		if Engine.is_editor_hint():
			checkpoint_mesh.owner = get_tree().edited_scene_root

	var cylinder = CylinderMesh.new()
	cylinder.top_radius = checkpoint_radius
	cylinder.bottom_radius = checkpoint_radius
	cylinder.height = checkpoint_height
	cylinder.radial_segments = 32
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	checkpoint_mesh.mesh = cylinder
	checkpoint_mesh.position = Vector3(0, checkpoint_height / 2.0, 0)

	var shader_res = load("res://shaders/checkpoint.gdshader")
	if shader_res:
		var mat = ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("color_albedo", checkpoint_color)
		mat.set_shader_parameter("scale_pulse_speed", pulse_speed)
		mat.set_shader_parameter("scale_pulse_strength", pulse_strength)
		mat.set_shader_parameter("speed", scan_speed)
		checkpoint_mesh.material_override = mat
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = checkpoint_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		checkpoint_mesh.material_override = mat

	var label_node = get_node_or_null("TextoConcesionario") as Label3D
	if not label_node:
		label_node = Label3D.new()
		label_node.name = "TextoConcesionario"
		label_node.text = "Concesionario"
		label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_node.font_size = 48
		label_node.outline_modulate = Color.BLACK
		label_node.outline_size = 12
		add_child(label_node)
		if Engine.is_editor_hint():
			label_node.owner = get_tree().edited_scene_root

	label_node.modulate = Color(checkpoint_color.r, checkpoint_color.g, checkpoint_color.b)
	label_node.position = Vector3(0, checkpoint_height + 0.5, 0)

	if Engine.is_editor_hint():
		label_node.visible = true
	else:
		label_node.visible = false

	label_3d = label_node


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var players = get_tree().get_nodes_in_group("jugador")
	var player = players[0] if players.size() > 0 else null
	if not player:
		var root = get_tree().current_scene if get_tree() else null
		if root:
			player = root.find_child("Jugador2", true, false)
			if not player:
				for child in root.get_children():
					if (child.name.to_int() > 0 or child.name.begins_with("Jugador_")) and child is Node3D:
						player = child
						break
	if not player:
		return

	var checkpoint_pos = global_position
	var marker = get_node_or_null("Marker3D") as Marker3D
	if marker:
		checkpoint_pos = marker.global_position

	var player_pos_2d = Vector2(player.global_position.x, player.global_position.z)
	var self_pos_2d = Vector2(checkpoint_pos.x, checkpoint_pos.z)
	var dist_2d = player_pos_2d.distance_to(self_pos_2d)
	var height_diff = abs(player.global_position.y - checkpoint_pos.y)

	if dist_2d < (checkpoint_radius + 2.2) and height_diff < (checkpoint_height + 2.0):
		if not player_inside:
			player_inside = true
			print("[ConcesionarioSpawnPoint DEBUG] Player entered zone. dist: ", dist_2d, " | Opening shop automatically...")
			_abrir_tienda()
	else:
		if player_inside:
			player_inside = false
			print("[ConcesionarioSpawnPoint DEBUG] Player exited zone. dist: ", dist_2d, " | Closing shop...")
			_cerrar_tienda()

	var gps_dirigido := false
	var gps_line = player.get_node_or_null("GPSRutaLinea")
	if gps_line and gps_line.get("active") == true:
		var target_pos = gps_line.get("target_position")
		if target_pos.distance_to(checkpoint_pos) < 3.0:
			gps_dirigido = true

	if is_instance_valid(label_3d) and label_3d.visible != gps_dirigido:
		label_3d.visible = gps_dirigido

	if is_instance_valid(preview_anchor) and preview_viewport:
		preview_anchor.rotate_y(preview_rotation_speed * delta)


func _abrir_tienda() -> void:
	_cerrar_tienda()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var canvas = CanvasLayer.new()
	canvas.name = "ConcesionarioOverlay"
	canvas.layer = 95
	get_tree().current_scene.add_child(canvas)
	dialogue_ui = canvas

	# Fondo oscuro para aislar la vista
	var dimmer = ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.5)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(dimmer)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.90)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.00, 0.45, 0.00, 0.80)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 50
	style.content_margin_right = 50
	style.content_margin_top = 45
	style.content_margin_bottom = 45
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(1300, 850)
	panel.pivot_offset = Vector2(650, 425)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	panel.add_child(vbox)

	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	var title_lbl = Label.new()
	title_lbl.text = "CONCESIONARIO"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	if font:
		title_lbl.add_theme_font_override("font", font)
	vbox.add_child(title_lbl)

	var hsplit = HBoxContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_theme_constant_override("separation", 35)
	vbox.add_child(hsplit)

	# Panel izquierdo: Listado de tarjetas de vehículos
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(520, 0)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 15)
	hsplit.add_child(left_vbox)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)

	var list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 15)
	scroll.add_child(list_container)

	# Panel derecho: Detalles + Previsualizador 3D + Botón de Acción
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 20)
	hsplit.add_child(right_vbox)

	# SubViewport para el previsualizador 3D dentro de un marco decorativo con borde neón
	var view_border_panel = PanelContainer.new()
	var view_style = StyleBoxFlat.new()
	view_style.bg_color = Color(0, 0, 0, 0.25)
	view_style.border_width_left = 2
	view_style.border_width_top = 2
	view_style.border_width_right = 2
	view_style.border_width_bottom = 2
	view_style.border_color = Color(1.0, 0.45, 0.0, 0.6)
	view_style.corner_radius_top_left = 12
	view_style.corner_radius_top_right = 12
	view_style.corner_radius_bottom_left = 12
	view_style.corner_radius_bottom_right = 12
	view_border_panel.add_theme_stylebox_override("panel", view_style)
	right_vbox.add_child(view_border_panel)

	var view_container = SubViewportContainer.new()
	view_container.custom_minimum_size = Vector2(0, 380)
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_container.stretch = true
	view_border_panel.add_child(view_container)

	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view_container.add_child(viewport)
	preview_viewport = viewport

	var preview_world = Node3D.new()
	viewport.add_child(preview_world)

	var light = DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.9)
	light.light_energy = 1.4
	light.position = Vector3(6, 12, 6)
	light.rotation_degrees = Vector3(-45, 45, 0)
	preview_world.add_child(light)

	var light2 = DirectionalLight3D.new()
	light2.light_color = Color(0.2, 0.5, 1.0)
	light2.light_energy = 0.9
	light2.position = Vector3(-6, 6, -6)
	light2.rotation_degrees = Vector3(30, -135, 0)
	preview_world.add_child(light2)

	var anchor = Node3D.new()
	preview_world.add_child(anchor)
	preview_anchor = anchor

	var camera = Camera3D.new()
	camera.current = true
	camera.fov = 48
	preview_world.add_child(camera)
	preview_camera = camera

	var details_container = VBoxContainer.new()
	details_container.name = "DetallesVehiculo"
	details_container.add_theme_constant_override("separation", 15)
	right_vbox.add_child(details_container)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var close_btn = Button.new()
	close_btn.text = "SALIR DEL CONCESIONARIO"
	close_btn.custom_minimum_size = Vector2(0, 80)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.35, 0.12, 0.15)
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_font_size_override("font_size", 32)
	if font:
		close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(func():
		_cerrar_tienda()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)
	vbox.add_child(close_btn)

	# Seleccionar primer vehículo por defecto sin cargar el 3D inmediatamente
	if vehiculos_en_venta.size() > 0:
		_seleccionar_vehiculo(vehiculos_en_venta[0], right_vbox, font, false)

	_dibujar_tarjetas_vehiculos(list_container, right_vbox, font)

	# Animación de entrada suave
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var anim_tw = get_tree().create_tween().set_parallel(true)
	anim_tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tw.tween_property(panel, "modulate:a", 1.0, 0.35)

	# Deferir la instanciación del modelo 3D un instante después para abrir la UI inmediatamente sin lag
	if vehiculos_en_venta.size() > 0:
		var timer = get_tree().create_timer(0.20)
		timer.timeout.connect(func():
			if is_instance_valid(dialogue_ui) and selected_vehicle == vehiculos_en_venta[0]:
				_cargar_modelo_3d(vehiculos_en_venta[0])
		)


func _dibujar_tarjetas_vehiculos(container: VBoxContainer, right_vbox: VBoxContainer, font: FontFile) -> void:
	for child in container.get_children():
		child.queue_free()

	for v in vehiculos_en_venta:
		if not v:
			continue

		var ya_posee = _jugador_posee_vehiculo(v)
		var es_seleccionado = selected_vehicle == v

		var card = Button.new()
		card.custom_minimum_size = Vector2(0, 110)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.12, 0.12, 0.16, 0.6)
		style_normal.border_width_left = 6 if es_seleccionado else 1
		style_normal.border_color = Color(1.0, 0.45, 0.0) if es_seleccionado else Color(0.2, 0.2, 0.25)
		style_normal.corner_radius_top_left = 10
		style_normal.corner_radius_top_right = 10
		style_normal.corner_radius_bottom_left = 10
		style_normal.corner_radius_bottom_right = 10
		style_normal.content_margin_left = 25
		style_normal.content_margin_right = 25

		var style_hover = style_normal.duplicate() as StyleBoxFlat
		style_hover.bg_color = Color(0.18, 0.18, 0.24, 0.8)
		style_hover.border_color = Color(1.0, 0.45, 0.0, 0.8)

		card.add_theme_stylebox_override("normal", style_normal)
		card.add_theme_stylebox_override("hover", style_hover)
		card.add_theme_stylebox_override("pressed", style_hover)
		card.add_theme_stylebox_override("focus", style_normal)

		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(hbox)

		var text_vbox = VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(text_vbox)

		var name_lbl = Label.new()
		name_lbl.text = v.nombre
		name_lbl.add_theme_font_size_override("font_size", 28)
		if font:
			name_lbl.add_theme_font_override("font", font)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if ya_posee else Color.WHITE)
		text_vbox.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = "PROPIO (Gratis)" if ya_posee else ("Precio: $%.0f" % v.precio)
		desc_lbl.add_theme_font_size_override("font_size", 22)
		desc_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4) if ya_posee else Color(0.7, 0.7, 0.75))
		text_vbox.add_child(desc_lbl)

		var current_v = v
		card.pressed.connect(func():
			_seleccionar_vehiculo(current_v, right_vbox, font, true)
			_dibujar_tarjetas_vehiculos(container, right_vbox, font)
		)

		container.add_child(card)


func _seleccionar_vehiculo(v: ConcesionarioVehiculo, right_vbox: VBoxContainer, font: FontFile, cargar_modelo: bool = true) -> void:
	selected_vehicle = v

	# Limpiar el preview anterior
	if is_instance_valid(preview_model):
		preview_model.queue_free()
		preview_model = null

	if cargar_modelo:
		_cargar_modelo_3d(v)

	_actualizar_detalles_derecha(right_vbox, font)


func _cargar_modelo_3d(v: ConcesionarioVehiculo) -> void:
	if not is_instance_valid(preview_anchor):
		return

	if is_instance_valid(preview_model):
		preview_model.queue_free()
		preview_model = null

	if v.escena:
		var instance = v.escena.instantiate() as Node3D
		if instance:
			instance.process_mode = Node.PROCESS_MODE_DISABLED
			preview_anchor.add_child(instance)
			preview_model = instance

			# Auto-enfocar cámara usando AABB
			var aabb = _calculate_aabb(instance)
			var center = aabb.get_center()
			instance.position = -center
			var size = aabb.size.length()
			if size <= 0.1:
				size = 5.0
			preview_camera.position = Vector3(0, size * 0.40, size * 1.05)
			preview_camera.look_at(Vector3.ZERO)


func _actualizar_detalles_derecha(right_vbox: VBoxContainer, font: FontFile) -> void:
	var details_container = right_vbox.get_node_or_null("DetallesVehiculo") as VBoxContainer
	if not details_container:
		return

	for child in details_container.get_children():
		child.queue_free()

	var v = selected_vehicle
	if not v:
		return

	var datos = get_node_or_null("/root/DatosUsuario")
	if not datos:
		return

	var name_lbl = Label.new()
	name_lbl.text = v.nombre.to_upper()
	name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	if font:
		name_lbl.add_theme_font_override("font", font)
	details_container.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = v.descripcion
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 28)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	details_container.add_child(desc_lbl)

	var level = datos.get("nivel") as int
	var money = datos.get("dinero") as float
	var has_auto = datos.get("licencia_automovil") as bool
	var has_truck = datos.get("licencia_camion") as bool

	var req_lbl = Label.new()
	var lvl_ok = level >= v.requisito_nivel
	var lic_ok = true

	var req_text = "Requisitos:\n • Nivel: %d %s" % [v.requisito_nivel, "(OK)" if lvl_ok else "(Requerido)"]
	if v.requisito_licencia != "":
		if v.requisito_licencia == "automovil":
			lic_ok = has_auto
		elif v.requisito_licencia == "camion":
			lic_ok = has_truck
		req_text += "\n • Licencia: %s %s" % [v.requisito_licencia.capitalize(), "(Poseída)" if lic_ok else "(Requerida)"]
	else:
		req_text += "\n • Licencia: Ninguna"

	req_lbl.text = req_text
	req_lbl.add_theme_font_size_override("font_size", 28)
	
	var cumple_req = lvl_ok and lic_ok
	req_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4) if cumple_req else Color(0.9, 0.3, 0.3))
	details_container.add_child(req_lbl)

	var ya_posee = _jugador_posee_vehiculo(v)

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(0, 80)
	
	var btn_st = StyleBoxFlat.new()
	btn_st.corner_radius_top_left = 12
	btn_st.corner_radius_top_right = 12
	btn_st.corner_radius_bottom_left = 12
	btn_st.corner_radius_bottom_right = 12

	if font:
		buy_btn.add_theme_font_override("font", font)
	buy_btn.add_theme_font_size_override("font_size", 32)

	if ya_posee:
		buy_btn.text = "SPAWNEAR VEHICULO"
		btn_st.bg_color = Color(0.2, 0.6, 1.0)
		buy_btn.pressed.connect(func():
			_spawnear_vehiculo_poseido(v)
		)
	else:
		if cumple_req:
			buy_btn.text = "COMPRAR POR $%.0f" % v.precio
			if money >= v.precio:
				btn_st.bg_color = Color(1.0, 0.45, 0.0)
				buy_btn.pressed.connect(func():
					_comprar_vehiculo(v)
				)
			else:
				btn_st.bg_color = Color(0.3, 0.3, 0.3)
				buy_btn.disabled = true
				buy_btn.text += " (Dinero Insuficiente)"
		else:
			buy_btn.text = "REQUISITOS NO CUMPLIDOS"
			btn_st.bg_color = Color(0.25, 0.25, 0.25)
			buy_btn.disabled = true

	buy_btn.add_theme_stylebox_override("normal", btn_st)
	details_container.add_child(buy_btn)


func _calculate_aabb(node: Node) -> AABB:
	var aabb = AABB()
	var first = true
	var stack = [node]
	while stack.size() > 0:
		var curr = stack.pop_back()
		if curr is VisualInstance3D:
			var mi_aabb = curr.get_aabb()
			var tf = curr.transform
			var parent = curr.get_parent()
			while parent and parent != node:
				tf = parent.transform * tf
				parent = parent.get_parent()
			var trans_aabb = tf * mi_aabb
			if first:
				aabb = trans_aabb
				first = false
			else:
				aabb = aabb.merge(trans_aabb)
		for child in curr.get_children():
			stack.push_back(child)
	return aabb


func _jugador_posee_vehiculo(v: ConcesionarioVehiculo) -> bool:
	var datos = get_node_or_null("/root/DatosUsuario")
	if not datos:
		return false
	var poseidos = datos.get("vehiculos_personalizados") as Dictionary
	if not poseidos:
		return false
	var ruta = v.escena.resource_path if v.escena else ""
	return ruta != "" and poseidos.has(ruta)


func _comprar_vehiculo(v: ConcesionarioVehiculo) -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if not datos:
		return

	if datos.dinero < v.precio:
		_notificar("Dinero insuficiente.", "error")
		return

	datos.dinero -= v.precio

	var poseidos = datos.get("vehiculos_personalizados") as Dictionary
	if poseidos == null:
		poseidos = {}
	var ruta = v.escena.resource_path if v.escena else ""
	if ruta != "":
		poseidos[ruta] = true
		datos.set("vehiculos_personalizados", poseidos)

	datos.save_local()

	var sfx = AudioStreamPlayer.new()
	var money_stream = load("res://recursos/efectos/money.mp3")
	if money_stream:
		sfx.stream = money_stream
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

	_notificar(v.nombre + " adquirido! Dirígete al spawn para verlo.", "exito")

	var player = _find_player()
	if player:
		_ejecutar_fade_y_spawnear(player, v.escena)
	_cerrar_tienda()


func _spawnear_vehiculo_poseido(v: ConcesionarioVehiculo) -> void:
	_notificar("Vehículo " + v.nombre + " spawneado.", "exito")
	var player = _find_player()
	if player:
		_ejecutar_fade_y_spawnear(player, v.escena)
	_cerrar_tienda()


func _find_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("jugador")
	if players.size() > 0:
		return players[0] as Node3D
	var root = get_tree().current_scene if get_tree() else null
	if root:
		var p = root.find_child("Jugador2", true, false)
		if p and p is Node3D:
			return p
		for child in root.get_children():
			if (child.name.to_int() > 0 or child.name.begins_with("Jugador_")) and child is Node3D:
				return child
	return null


func _ejecutar_fade_y_spawnear(player: Node3D, escena: PackedScene) -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "FadeConcesionario"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)

	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)

	rect.modulate.a = 0.0
	var tw = get_tree().create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.35)

	tw.tween_callback(func():
		if player and player is Node3D and teleport_target:
			player.global_transform = teleport_target.global_transform

		if escena and vehicle_spawn_marker:
			# Limpiar vehículos anteriores en la zona de spawn si los hay
			var current_scene = get_tree().current_scene
			for child in current_scene.get_children():
				if child is RigidBody3D and child.global_position.distance_to(vehicle_spawn_marker.global_position) < 8.0:
					child.queue_free()

			var instancia = escena.instantiate() as Node3D
			if instancia:
				current_scene.add_child(instancia)
				var spawn_tf = vehicle_spawn_marker.global_transform
				spawn_tf.origin.y += 0.28
				instancia.global_transform = spawn_tf
				if instancia is RigidBody3D:
					instancia.freeze = true

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)

	tw.tween_property(rect, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		canvas.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)


func _notificar(msg: String, tipo: String) -> void:
	var celular = get_node_or_null("/root/CelularUI")
	if celular:
		celular.call("notificar", msg, tipo)
	else:
		print("[Concesionario] ", msg)


func _cerrar_tienda() -> void:
	preview_viewport = null
	preview_anchor = null
	preview_camera = null
	preview_model = null
	if is_instance_valid(dialogue_ui):
		dialogue_ui.queue_free()
		dialogue_ui = null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
