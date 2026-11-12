# PuntoTienda.gd
# Estación interactiva en el mundo 3D (Area3D) para tiendas de carretera, paradores y estaciones de servicio.
# Permite al jugador interactuar para abrir el menú de la tienda y adquirir productos.
class_name PuntoTienda
extends Area3D

@export var nombre_tienda: String = "Tienda & Parador"
@export var radio_interaccion: float = 3.2
@export var mostrar_mostrador_3d: bool = true

var _jugador_en_rango: CharacterBody3D = null
var _tienda_ui: TiendaUI = null
var _cartel_label: Label3D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Capa del jugador
	monitorable = false
	monitoring = true

	# Crear CollisionShape3D si no existe
	if not has_node("CollisionShape3D"):
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radio_interaccion
		col.shape = sphere
		add_child(col)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if mostrar_mostrador_3d:
		_construir_stand_visual()

	_obtener_o_crear_tienda_ui()

func _obtener_o_crear_tienda_ui() -> TiendaUI:
	if is_instance_valid(_tienda_ui):
		return _tienda_ui

	# Buscar en la escena actual
	var root := get_tree().current_scene if get_tree() else null
	if root:
		_tienda_ui = root.find_child("TiendaUI", true, false) as TiendaUI

	if not _tienda_ui:
		_tienda_ui = TiendaUI.new()
		_tienda_ui.name = "TiendaUI"
		if root:
			root.add_child(_tienda_ui)
		else:
			add_child(_tienda_ui)

	return _tienda_ui

func _construir_stand_visual() -> void:
	# Mostrador estilizado
	var mostrador := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 0.95, 0.65)
	mostrador.mesh = box
	mostrador.position = Vector3(0.0, 0.475, 0.0)

	var mat_m := StandardMaterial3D.new()
	mat_m.albedo_color = Color(0.12, 0.14, 0.16)
	mat_m.roughness = 0.5
	mostrador.material_override = mat_m
	add_child(mostrador)

	# Tira LED ámbar en el frontal del mostrador
	var tira_led := MeshInstance3D.new()
	var box_led := BoxMesh.new()
	box_led.size = Vector3(1.5, 0.04, 0.02)
	tira_led.mesh = box_led
	tira_led.position = Vector3(0.0, 0.85, 0.33)

	var mat_led := StandardMaterial3D.new()
	mat_led.albedo_color = Color(0.88, 0.68, 0.28)
	mat_led.emission_enabled = true
	mat_led.emission = Color(0.88, 0.68, 0.28)
	mat_led.emission_energy_multiplier = 3.0
	tira_led.material_override = mat_led
	add_child(tira_led)

	# Cartel 3D flotante visible a distancia
	_cartel_label = Label3D.new()
	_cartel_label.text = "🏪 " + nombre_tienda.to_upper()
	_cartel_label.position = Vector3(0.0, 1.8, 0.0)
	_cartel_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cartel_label.no_depth_test = false
	_cartel_label.modulate = Color(0.88, 0.68, 0.28, 0.95)
	_cartel_label.font_size = 28
	_cartel_label.outline_size = 6
	_cartel_label.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
	add_child(_cartel_label)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		_jugador_en_rango = body as CharacterBody3D
		if _cartel_label:
			_cartel_label.text = "🏪 " + nombre_tienda.to_upper() + "\n[Toca o pulsa E para Comprar]"
			_cartel_label.modulate = Color(1.0, 0.85, 0.40)

func _on_body_exited(body: Node3D) -> void:
	if body == _jugador_en_rango:
		_jugador_en_rango = null
		if _cartel_label:
			_cartel_label.text = "🏪 " + nombre_tienda.to_upper()
			_cartel_label.modulate = Color(0.88, 0.68, 0.28, 0.95)
		if _tienda_ui and _tienda_ui.visible:
			_tienda_ui.cerrar_tienda(true)

func _unhandled_input(event: InputEvent) -> void:
	if _jugador_en_rango == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_T:
			var ui := _obtener_o_crear_tienda_ui()
			if ui:
				ui.toggle_tienda()
				get_viewport().set_input_as_handled()
