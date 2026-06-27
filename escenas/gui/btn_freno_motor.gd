extends Button

# ═══════════════════════════════════════════════════════════════════════
# btn_freno_motor.gd — Control visual y funcional del Freno de Motor
# ═══════════════════════════════════════════════════════════════════════

@export var color_activo: Color = Color(1.0, 0.88, 0.0, 1.0) # Amarillo cool
@export var color_inactivo: Color = Color(1.0, 1.0, 1.0, 1.0) # Blanco normal
@export var velocidad_transicion: float = 8.0

# Para micro-animaciones
var _scale_target: Vector2 = Vector2.ONE

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Asegurar que el punto de pivote esté en el centro para las animaciones de escala
	pivot_offset = size / 2.0
	
	# Establecer estado inicial
	_actualizar_estilo(1.0)

func _process(delta: float) -> void:
	# Asegurar pivot_offset dinámico por si cambia el tamaño
	pivot_offset = size / 2.0
	
	# Micro-animación de escala
	scale = scale.lerp(_scale_target, delta * 12.0)
	
	# Transición suave de color
	_actualizar_estilo(delta * velocidad_transicion)

func _gui_input(event: InputEvent) -> void:
	# Manejar clicks de mouse y toques táctiles directamente
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		on_buton_pressed()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	# Permitir tecla de acceso rápido en PC (Tecla B)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			# Evitar activar si el jugador está escribiendo en el chat o menú si existe
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
				return
			on_buton_pressed()

func on_buton_pressed() -> void:
	if is_instance_valid(InputVehiculo):
		InputVehiculo.freno_motor = !InputVehiculo.freno_motor
		print("[BtnFrenoMotor] Freno de motor clickeado/presionado. Nuevo estado en InputVehiculo: ", InputVehiculo.freno_motor)
		
		# Feedback de click (micro-escala física de compresión)
		scale = Vector2(0.85, 0.85)

func _on_mouse_entered() -> void:
	_scale_target = Vector2(1.08, 1.08) # Ligero zoom al pasar el cursor

func _on_mouse_exited() -> void:
	_scale_target = Vector2.ONE

func _actualizar_estilo(factor: float) -> void:
	var activo = InputVehiculo.freno_motor if is_instance_valid(InputVehiculo) else false
	
	# Solo cambiar la propiedad si difiere para evitar romper el foco de Godot
	if button_pressed != activo:
		button_pressed = activo
	
	if material is ShaderMaterial:
		material.set_shader_parameter("activo", activo)
	
	# Interpolación de color suave (lerp)
	var color_target = color_activo if activo else color_inactivo
	self_modulate = self_modulate.lerp(color_target, factor)
