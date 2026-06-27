# ui_menu_button.gd - Botón para abrir el menú principal
# Sistema completamente nuevo - simple y efectivo
extends Button

var _touch_index: int = -1

# ════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ════════════════════════════════════════════════════════════════
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	focus_mode = FocusMode.FOCUS_NONE
	pressed.connect(_on_pressed)

# ════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().abs().has_point(event.position):
				_touch_index = event.index
				_on_pressed()
				get_tree().root.set_input_as_handled()
		else:
			if event.index == _touch_index:
				_touch_index = -1
				get_tree().root.set_input_as_handled()

	if event.is_action_pressed("ui_select"):
		_on_pressed()
		get_tree().root.set_input_as_handled()

# ════════════════════════════════════════════════════════════════
# EVENTOS
# ════════════════════════════════════════════════════════════════
func _on_pressed() -> void:
	if self.disabled:
		return

	# Protección anti-reentrada
	self.disabled = true

	var root = get_tree().root
	# Buscar instancias existentes del menú de opciones
	var existing := []
	for child in root.get_children():
		if child.is_in_group("OpcionesUI") or child.name == "CelularUI":
			existing.append(child)

	if existing.size() > 0:
		for node in existing:
			node.queue_free()
		print("[movil.gd] Opciones cerradas")
		await get_tree().create_timer(0.3).timeout
		self.disabled = false
		return

	# Instanciar el menú de opciones
	var opciones_scene = load("res://scenes/configuraciones/opciones.tscn")
	if opciones_scene:
		var instancia = opciones_scene.instantiate()
		# Marcar instancia para futuras búsquedas
		instancia.add_to_group("OpcionesUI")
		root.add_child(instancia)
		print("[movil.gd] Opciones instanciado correctamente")
	else:
		print("[movil.gd] No se pudo cargar la escena de opciones")

	# Esperar un breve tiempo antes de reactivar el botón
	await get_tree().create_timer(0.3).timeout
	self.disabled = false
	print("[movil.gd] Botón reactivado")
