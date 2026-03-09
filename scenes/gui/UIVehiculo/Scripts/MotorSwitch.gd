extends Control

signal toggled(activo: bool)

@export var activo: bool = false
@export var color_activo: Color = Color(1.0, 0.85, 0.2, 0.95)
@export var color_inactivo: Color = Color(0.22, 0.25, 0.3, 0.92)

@onready var fondo: ColorRect = $Fondo

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_aplicar_visual()

func _gui_input(event: InputEvent) -> void:
	if not _es_presion_primaria(event):
		return
	set_activo(not activo)
	toggled.emit(activo)
	accept_event()

func set_activo(estado: bool) -> void:
	activo = estado
	_aplicar_visual()

func get_activo() -> bool:
	return activo

func _aplicar_visual() -> void:
	if fondo:
		fondo.color = color_activo if activo else color_inactivo

func _es_presion_primaria(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false
