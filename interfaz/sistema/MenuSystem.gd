extends Node

# Autoload: MenuSystem
# Gestor Global de Menús y Sistema de Pausa mediante la Tableta/Celular (Nuestra Tierra 2.0)

const MENU_SCENE = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
var _menu_actual: Node = null

var menu_abierto: bool:
	get:
		var celular = _obtener_celular()
		var cel_abierto = celular and celular.get("is_open") == true
		return _menu_actual != null or cel_abierto

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[MenuSystem] Listo con soporte para Pausa Integrada en Tableta/Celular.")

func _obtener_celular() -> Node:
	var cel = get_tree().get_first_node_in_group("celular")
	if not cel and CelularUI.instance:
		cel = CelularUI.instance
	if not cel and get_tree().current_scene:
		cel = get_tree().current_scene.find_child("CelularUI", true, false)
	if not cel:
		var curr = get_tree().current_scene
		if curr and not curr.name.to_lower().contains("menu") and not curr.name.to_lower().contains("login") and not curr.name.to_lower().contains("intro"):
			var scene_path = "res://interfaz/celular/sistema/CelularUI.tscn"
			if ResourceLoader.exists(scene_path):
				var scn = load(scene_path)
				if scn:
					var cel_inst = scn.instantiate()
					cel_inst.name = "CelularUI"
					curr.add_child(cel_inst)
					print("[MenuSystem] CelularUI instanciado automáticamente en escena de juego.")
					return cel_inst
	return cel

func abrir_pausa() -> void:
	var cel = _obtener_celular()
	if cel and cel.has_method("open_phone"):
		cel.call("open_phone")

func cerrar_pausa() -> void:
	var cel = _obtener_celular()
	if cel and cel.has_method("close_phone"):
		cel.call("close_phone")

func alternar_pausa() -> void:
	var cel = _obtener_celular()
	if cel and cel.has_method("toggle_phone"):
		cel.call("toggle_phone")
	else:
		if _menu_actual != null:
			cerrar_menu()
		else:
			abrir_menu()

func abrir_menu() -> void:
	_abrir_menu_impl()

func cerrar_menu() -> void:
	_cerrar_menu_impl()

func es_menu_abierto() -> bool:
	return menu_abierto

func _abrir_menu_impl() -> void:
	if _menu_actual != null:
		return

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("GuardarScreenshot"):
			gm.call("GuardarScreenshot")
		if gm.has_method("AbrirPantalla"):
			gm.call("AbrirPantalla", "menu")

	var scene = load(MENU_SCENE)
	if scene == null:
		push_error("[MenuSystem] No se pudo cargar MainMenuModerno.tscn en " + MENU_SCENE)
		return

	_menu_actual = scene.instantiate()
	get_tree().root.add_child(_menu_actual)
	print("[MenuSystem] Menú principal abierto")

func _cerrar_menu_impl() -> void:
	if _menu_actual:
		_menu_actual.queue_free()
		_menu_actual = null
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("CerrarPantalla"):
		gm.call("CerrarPantalla")
	print("[MenuSystem] Menú cerrado -> volviendo al juego")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		var escena_actual = get_tree().current_scene
		var es_juego_activo = escena_actual and not escena_actual.name.to_lower().contains("menu") and not escena_actual.name.to_lower().contains("login")

		if es_juego_activo:
			alternar_pausa()
		else:
			if _menu_actual != null:
				cerrar_menu()
			else:
				abrir_menu()

		get_viewport().set_input_as_handled()
