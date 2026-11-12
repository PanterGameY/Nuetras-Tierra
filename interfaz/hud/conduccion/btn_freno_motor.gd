extends Button

# ═══════════════════════════════════════════════════════════════════════
# btn_freno_motor.gd — Control sobrio del Freno de Motor (Retarder / Jake)
# Cero dependencias estáticas en tiempo de compilación
# ═══════════════════════════════════════════════════════════════════════

@export var color_activo: Color = Color(0.90, 0.74, 0.36, 1.0)
@export var color_inactivo: Color = Color(0.84, 0.86, 0.88, 0.95)
@export var velocidad_transicion: float = 8.0

var _scale_target: Vector2 = Vector2.ONE
var _iv_cache: Node = null

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if not pressed.is_connected(on_buton_pressed):
		pressed.connect(on_buton_pressed)
	pivot_offset = size / 2.0
	_actualizar_estilo(1.0)

func _process(delta: float) -> void:
	pivot_offset = size / 2.0
	scale = scale.lerp(_scale_target, delta * 12.0)
	_actualizar_estilo(delta * velocidad_transicion)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			var focus_owner = get_viewport().gui_get_focus_owner()
			if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
				return
			on_buton_pressed()

func on_buton_pressed() -> void:
	var iv = _get_iv()
	if is_instance_valid(iv) and "freno_motor" in iv:
		iv.freno_motor = not iv.freno_motor
		scale = Vector2(0.92, 0.92)

func _on_mouse_entered() -> void:
	_scale_target = Vector2(1.04, 1.04)

func _on_mouse_exited() -> void:
	_scale_target = Vector2.ONE

func _actualizar_estilo(factor: float) -> void:
	var iv = _get_iv()
	var activo: bool = bool(iv.get("freno_motor")) if is_instance_valid(iv) else false
	if button_pressed != activo:
		set_pressed_no_signal(activo)
	if material is ShaderMaterial:
		material.set_shader_parameter("activo", activo)
	var color_target = color_activo if activo else color_inactivo
	self_modulate = self_modulate.lerp(color_target, factor)
