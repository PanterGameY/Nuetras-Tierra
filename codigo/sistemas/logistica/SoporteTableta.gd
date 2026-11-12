extends Marker3D

# ═══════════════════════════════════════════════════════════════════════
# SoporteTableta - Administra de forma autónoma la detección del jugador,
# el botón táctil de colocación, y el ajuste 3D de la tableta.
# ═══════════════════════════════════════════════════════════════════════

@export var interact_distance: float = 4.0

var tableta_en_soporte: Node3D = null
var ajustando_tableta: bool = false
var offset_pos: Vector3 = Vector3.ZERO
var offset_rot: Vector3 = Vector3.ZERO

# Interfaces táctiles dinámicas
var _btn_colocar_cl: CanvasLayer = null
var _panel_ajuste_cl: CanvasLayer = null
var _player_ref: Node3D = null
var _area_click_connected: bool = false

func _ready() -> void:
	# Crear área de detección para el jugador de forma automática
	var area_det = Area3D.new()
	area_det.name = "AreaDeteccion"
	add_child(area_det)
	var col_det = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = interact_distance
	col_det.shape = sphere
	area_det.add_child(col_det)
	
	area_det.body_entered.connect(_on_body_entered)
	area_det.body_exited.connect(_on_body_exited)
	
	# Cargar offsets guardados
	_cargar_offsets()

func _process(_delta: float) -> void:
	# Intentar auto-buscar al jugador si no está asignado o conducirá
	if not is_instance_valid(_player_ref):
		var p = get_tree().get_first_node_in_group("jugador")
		if p:
			_player_ref = p
			
	if not is_instance_valid(_player_ref):
		_destruir_interfaces()
		return
		
	# Verificar si el jugador está conduciendo (sin importar qué vehículo sea)
	var conduciendo = false
	if _player_ref.get("_conduciendo") == true or _player_ref.get("conduciendo") == true:
		conduciendo = true
		
	if not conduciendo:
		_destruir_interfaces()
		return
		
	# Si ya está colocada la tableta
	if is_instance_valid(tableta_en_soporte):
		_destruir_boton_colocar()
		_inicializar_click_tableta()
		
		if ajustando_tableta:
			_crear_panel_ajuste()
		else:
			_destruir_panel_ajuste()
	else:
		# Si no está colocada, buscar si el jugador la tiene en su inventario
		var tableta_inst = _buscar_tableta_en_inventario()
		if is_instance_valid(tableta_inst):
			_crear_boton_colocar(tableta_inst)
		else:
			_destruir_boton_colocar()

func _buscar_tableta_en_inventario() -> Node3D:
	if not is_instance_valid(_player_ref):
		return null
	var inv = _player_ref.get("inventario")
	if inv and inv.get("items"):
		for it in inv.get("items"):
			if it.has("nombre") and it["nombre"].to_lower().contains("tableta"):
				return it.get("ref")
	return null

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		_player_ref = body

func _on_body_exited(_body: Node3D) -> void:
	pass

func colocar_tableta(tableta: Node3D) -> void:
	if not is_instance_valid(tableta):
		return
		
	# Remover del inventario del jugador
	if is_instance_valid(_player_ref):
		var inv = _player_ref.get("inventario")
		if inv and inv.get("items"):
			var items_list = inv.get("items")
			for i in range(items_list.size()):
				if items_list[i].get("ref") == tableta:
					inv.call("remover_item", i)
					break
					
	if tableta.get_parent():
		tableta.get_parent().remove_child(tableta)
		
	tableta_en_soporte = tableta
	add_child(tableta)
	
	tableta.visible = true
	tableta.position = offset_pos
	tableta.rotation_degrees = offset_rot
	
	if tableta is RigidBody3D:
		tableta.freeze = true
		
	if tableta.has_method("_find_player"):
		tableta.call("_ready")

func _crear_boton_colocar(tableta: Node3D) -> void:
	if is_instance_valid(_btn_colocar_cl):
		return
		
	_btn_colocar_cl = CanvasLayer.new()
	_btn_colocar_cl.layer = 110
	add_child(_btn_colocar_cl)
	
	var btn = Button.new()
	btn.text = "POSICIONAR TABLETA"
	btn.custom_minimum_size = Vector2(280, 80)
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.anchor_top = 0.75
	btn.anchor_bottom = 0.75
	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.75, 0.35, 0.9)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_font_size_override("font_size", 24)
	
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		btn.add_theme_font_override("font", load(font_path))
		
	btn.pressed.connect(func():
		colocar_tableta(tableta)
		_destruir_boton_colocar()
	)
	_btn_colocar_cl.add_child(btn)

func _destruir_boton_colocar() -> void:
	if is_instance_valid(_btn_colocar_cl):
		_btn_colocar_cl.queue_free()
	_btn_colocar_cl = null

func _inicializar_click_tableta() -> void:
	if _area_click_connected or not is_instance_valid(tableta_en_soporte):
		return
		
	var area = tableta_en_soporte.get_node_or_null("AreaClick")
	if not area:
		area = Area3D.new()
		area.name = "AreaClick"
		tableta_en_soporte.add_child(area)
		
		var collision = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.5, 0.8, 0.2)
		collision.shape = box
		area.add_child(collision)
		
	if not area.input_event.is_connected(_on_tableta_input_event):
		area.input_event.connect(_on_tableta_input_event)
	_area_click_connected = true

func _on_tableta_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	var click_o_touch = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if click_o_touch:
		if not ajustando_tableta:
			ajustando_tableta = true
			offset_pos = tableta_en_soporte.position
			offset_rot = tableta_en_soporte.rotation_degrees

func _crear_panel_ajuste() -> void:
	if is_instance_valid(_panel_ajuste_cl):
		return
		
	_panel_ajuste_cl = CanvasLayer.new()
	_panel_ajuste_cl.layer = 110
	add_child(_panel_ajuste_cl)
	
	var panel = PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.70
	panel.anchor_bottom = 0.95
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", sb)
	_panel_ajuste_cl.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "AJUSTAR TABLETA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		title.add_theme_font_override("font", load(font_path))
	vbox.add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)
	
	var btns = [
		{"label": "<- X", "action": func(): offset_pos.x -= 0.02},
		{"label": "X ->", "action": func(): offset_pos.x += 0.02},
		{"label": "v Y", "action": func(): offset_pos.y -= 0.02},
		{"label": "^ Y", "action": func(): offset_pos.y += 0.02},
		{"label": "Forward", "action": func(): offset_pos.z -= 0.02},
		{"label": "Back", "action": func(): offset_pos.z += 0.02},
		{"label": "Rot -", "action": func(): offset_rot.y -= 5.0},
		{"label": "Rot +", "action": func(): offset_rot.y += 5.0}
	]
	
	for btn_info in btns:
		var b = Button.new()
		b.text = btn_info["label"]
		b.custom_minimum_size = Vector2(80, 50)
		b.pressed.connect(func():
			btn_info["action"].call()
			_actualizar_temp()
		)
		hbox.add_child(b)
		
	var btn_save = Button.new()
	btn_save.text = "GUARDAR"
	btn_save.custom_minimum_size = Vector2(120, 50)
	var sb_save = StyleBoxFlat.new()
	sb_save.bg_color = Color(0.1, 0.6, 0.8, 1.0)
	btn_save.add_theme_stylebox_override("normal", sb_save)
	if ResourceLoader.exists(font_path):
		btn_save.add_theme_font_override("font", load(font_path))
	btn_save.pressed.connect(func():
		ajustando_tableta = false
		_destruir_panel_ajuste()
		_guardar_offsets()
	)
	hbox.add_child(btn_save)

func _actualizar_temp() -> void:
	if is_instance_valid(tableta_en_soporte):
		tableta_en_soporte.position = offset_pos
		tableta_en_soporte.rotation_degrees = offset_rot

func _destruir_panel_ajuste() -> void:
	if is_instance_valid(_panel_ajuste_cl):
		_panel_ajuste_cl.queue_free()
	_panel_ajuste_cl = null

func _destruir_interfaces() -> void:
	_destruir_boton_colocar()
	_destruir_panel_ajuste()
	_area_click_connected = false

func _cargar_offsets() -> void:
	var config_file = ConfigFile.new()
	if config_file.load("user://tablet_offsets.cfg") == OK:
		offset_pos = config_file.get_value("tablet", "position", Vector3.ZERO)
		offset_rot = config_file.get_value("tablet", "rotation", Vector3.ZERO)

func _guardar_offsets() -> void:
	var config_file = ConfigFile.new()
	config_file.set_value("tablet", "position", offset_pos)
	config_file.set_value("tablet", "rotation", offset_rot)
	config_file.save("user://tablet_offsets.cfg")
