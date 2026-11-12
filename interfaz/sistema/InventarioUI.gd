extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════
# InventarioUI - Premium Sci-Fi Holographic Cargo Inventory
# ═══════════════════════════════════════════════════════════════════════

signal inventario_abierto
signal inventario_cerrado

@onready var panel_container: PanelContainer = $PanelContainer
@onready var items_grid: GridContainer = $PanelContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var cap_label: Label = $PanelContainer/VBoxContainer/HeaderBar/CapacidadLabel
@onready var toggle_btn: Button = $ToggleBtn
@onready var moch_status_btn: Button = $PanelContainer/VBoxContainer/HeaderBar/MochilaStatusBtn

var tiene_mochila: bool = false:
	set(val):
		tiene_mochila = val
		_actualizar_capacidad_ui()
		_actualizar_items_ui()

var items: Array[Dictionary] = [] # Formato: {"nombre": String, "icono": Texture2D, "ref": Node3D}

func _ready() -> void:
	panel_container.visible = false
	_actualizar_capacidad_ui()
	_actualizar_items_ui()
	
	_customizar_boton_toggle(toggle_btn)
	_customizar_panel_inventario()
	
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		var moderniz_font = load(font_path)
		var title_node = panel_container.get_node_or_null("VBoxContainer/HeaderBar/Title")
		if title_node:
			title_node.add_theme_font_override("font", moderniz_font)
			title_node.add_theme_font_size_override("font_size", 34)
		if cap_label:
			cap_label.add_theme_font_override("font", moderniz_font)
			cap_label.add_theme_font_size_override("font_size", 20)
		if moch_status_btn:
			moch_status_btn.add_theme_font_override("font", moderniz_font)
			moch_status_btn.add_theme_font_size_override("font_size", 14)

func toggle_inventario() -> void:
	panel_container.visible = !panel_container.visible
	if panel_container.visible:
		emit_signal("inventario_abierto")
		_actualizar_items_ui()
		# Animación simple de escala al abrir
		panel_container.scale = Vector2(0.85, 0.85)
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel_container, "scale", Vector2.ONE, 0.25)
	else:
		emit_signal("inventario_cerrado")

func _actualizar_capacidad_ui() -> void:
	var cap_max = 10 if tiene_mochila else 2
	if cap_label:
		cap_label.text = "SLOTS: %d / %d" % [items.size(), cap_max]
	if moch_status_btn:
		moch_status_btn.text = "MOCHILA EQUIPADA" if tiene_mochila else "SIN MOCHILA"
		
		# Estilo holográfico brillante para el indicador de mochila
		var sb = StyleBoxFlat.new()
		if tiene_mochila:
			sb.bg_color = Color(0.0, 0.9, 0.6, 0.15)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.0, 1.0, 0.7, 0.8)
			moch_status_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.7))
		else:
			sb.bg_color = Color(0.9, 0.2, 0.3, 0.1)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(1.0, 0.3, 0.4, 0.6)
			moch_status_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.5))
			
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		moch_status_btn.add_theme_stylebox_override("normal", sb)
		moch_status_btn.add_theme_stylebox_override("hover", sb)
		moch_status_btn.add_theme_stylebox_override("pressed", sb)

func agregar_item(nombre: String, ref_nodo: Node3D = null) -> bool:
	var cap_max = 10 if tiene_mochila else 2
	if items.size() >= cap_max:
		_mostrar_notificacion_local("Inventario lleno! Consigue una mochila para cargar mas.")
		return false
		
	var icono = load("res://icon.svg")
	items.append({
		"nombre": nombre,
		"icono": icono,
		"ref": ref_nodo
	})
	_actualizar_capacidad_ui()
	_actualizar_items_ui()
	return true

func remover_item(index: int) -> Dictionary:
	if index >= 0 and index < items.size():
		var it = items[index]
		items.remove_at(index)
		_actualizar_capacidad_ui()
		_actualizar_items_ui()
		return it
	return {}

func _actualizar_items_ui() -> void:
	if not items_grid:
		return
		
	for c in items_grid.get_children():
		c.queue_free()
		
	var cap_max = 10 if tiene_mochila else 2
	
	for i in range(cap_max):
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(120, 130)
		
		var sb_slot = StyleBoxFlat.new()
		sb_slot.bg_color = Color(0.04, 0.05, 0.08, 0.85)
		sb_slot.border_width_left = 2
		sb_slot.border_width_top = 2
		sb_slot.border_width_right = 2
		sb_slot.border_width_bottom = 2
		sb_slot.border_color = Color(0.0, 0.45, 0.6, 0.4)
		sb_slot.corner_radius_top_left = 12
		sb_slot.corner_radius_top_right = 12
		sb_slot.corner_radius_bottom_left = 12
		sb_slot.corner_radius_bottom_right = 12
		slot.add_theme_stylebox_override("panel", sb_slot)
		
		# Contenedor con márgenes
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		slot.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)
		
		if i < items.size():
			var it = items[i]
			
			# Efecto de brillo si contiene un item
			sb_slot.border_color = Color(0.0, 0.8, 1.0, 0.85)
			sb_slot.shadow_size = 4
			sb_slot.shadow_color = Color(0.0, 0.8, 1.0, 0.15)
			
			var texture_rect = TextureRect.new()
			texture_rect.texture = it["icono"]
			texture_rect.custom_minimum_size = Vector2(60, 60)
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Color holográfico cyan para el icono por defecto
			texture_rect.modulate = Color(0.0, 0.9, 1.0, 0.9)
			vbox.add_child(texture_rect)
			
			var name_lbl = Label.new()
			name_lbl.text = it["nombre"].replace("_", " ").to_upper().left(12)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
			var font_path = "res://recursos/fonts/Moderniz.otf"
			if ResourceLoader.exists(font_path):
				name_lbl.add_theme_font_override("font", load(font_path))
			vbox.add_child(name_lbl)
			
			var action_btn = Button.new()
			action_btn.text = "SOLTAR"
			action_btn.custom_minimum_size = Vector2(0, 24)
			action_btn.add_theme_font_size_override("font_size", 10)
			
			var sb_btn = StyleBoxFlat.new()
			sb_btn.bg_color = Color(0.8, 0.15, 0.25, 0.85)
			sb_btn.corner_radius_top_left = 6
			sb_btn.corner_radius_top_right = 6
			sb_btn.corner_radius_bottom_left = 6
			sb_btn.corner_radius_bottom_right = 6
			action_btn.add_theme_stylebox_override("normal", sb_btn)
			action_btn.add_theme_stylebox_override("hover", sb_btn)
			
			if ResourceLoader.exists(font_path):
				action_btn.add_theme_font_override("font", load(font_path))
				
			var item_index = i
			action_btn.pressed.connect(func():
				_soltar_item_al_mundo(item_index)
			)
			vbox.add_child(action_btn)
		else:
			# Slot vacío
			var empty_icon = Label.new()
			empty_icon.text = "[ + ]"
			empty_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_icon.add_theme_color_override("font_color", Color(0.18, 0.25, 0.35, 0.4))
			empty_icon.add_theme_font_size_override("font_size", 20)
			vbox.add_child(empty_icon)
			
			var empty_lbl = Label.new()
			empty_lbl.text = "DISPONIBLE"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_color_override("font_color", Color(0.18, 0.25, 0.35, 0.4))
			empty_lbl.add_theme_font_size_override("font_size", 10)
			var font_path = "res://recursos/fonts/Moderniz.otf"
			if ResourceLoader.exists(font_path):
				empty_lbl.add_theme_font_override("font", load(font_path))
			vbox.add_child(empty_lbl)
			
		items_grid.add_child(slot)

func _soltar_item_al_mundo(index: int) -> void:
	var it = remover_item(index)
	if it.has("ref") and is_instance_valid(it["ref"]):
		var node = it["ref"]
		var player = get_tree().get_first_node_in_group("jugador")
		if player:
			if node.get_parent():
				node.get_parent().remove_child(node)
			get_tree().current_scene.add_child(node)
			node.global_position = player.global_position - player.global_transform.basis.z * 1.5 + Vector3.UP * 0.5
			if node is RigidBody3D:
				node.freeze = false
			var col = node.get_node_or_null("CollisionShape3D")
			if not col:
				col = node.find_child("CollisionShape3D", true, false)
			if col and col is CollisionShape3D:
				col.disabled = false
			_mostrar_notificacion_local("Objeto liberado: %s" % it["nombre"])

func _customizar_boton_toggle(btn: Button) -> void:
	# Botón circular/holográfico de Inventario flotante
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = Color(0.04, 0.08, 0.15, 0.85)
	sb_n.border_width_left = 2
	sb_n.border_width_top = 2
	sb_n.border_width_right = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = Color(0.0, 0.8, 1.0, 0.9)
	sb_n.corner_radius_top_left = 30
	sb_n.corner_radius_top_right = 30
	sb_n.corner_radius_bottom_left = 30
	sb_n.corner_radius_bottom_right = 30
	sb_n.shadow_size = 8
	sb_n.shadow_color = Color(0.0, 0.8, 1.0, 0.25)
	
	var sb_p = sb_n.duplicate()
	sb_p.bg_color = Color(0.0, 0.6, 0.8, 1.0)
	
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_n)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	btn.add_theme_font_size_override("font_size", 14)
	
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		btn.add_theme_font_override("font", load(font_path))

func _customizar_panel_inventario() -> void:
	# Estilo Glassmorphism con bordes brillantes y sombreado pesado
	var sb_panel = StyleBoxFlat.new()
	sb_panel.bg_color = Color(0.03, 0.05, 0.08, 0.94)
	sb_panel.border_width_left = 3
	sb_panel.border_width_top = 3
	sb_panel.border_width_right = 3
	sb_panel.border_width_bottom = 3
	sb_panel.border_color = Color(0.0, 0.75, 1.0, 0.85)
	sb_panel.corner_radius_top_left = 20
	sb_panel.corner_radius_top_right = 20
	sb_panel.corner_radius_bottom_left = 20
	sb_panel.corner_radius_bottom_right = 20
	sb_panel.shadow_size = 25
	sb_panel.shadow_color = Color(0, 0.3, 0.4, 0.25)
	panel_container.add_theme_stylebox_override("panel", sb_panel)

func _mostrar_notificacion_local(texto: String) -> void:
	var mensajero = get_tree().current_scene.find_child("Mensajero", true, false)
	if mensajero and mensajero.has_method("_mostrar_notificacion"):
		mensajero.call("_mostrar_notificacion", texto)
	else:
		print("[Inventario] %s" % texto)

func _on_toggle_btn_pressed() -> void:
	toggle_inventario()

func _on_mochila_status_btn_pressed() -> void:
	tiene_mochila = !tiene_mochila
	_mostrar_notificacion_local("Mochila " + ("equipada - 10 slots" if tiene_mochila else "desequipada - 2 slots"))
