extends Node

# Autoload: MenuSystem
# Reemplazo de MenuSystem.cs para eliminar dependencia de .NET

const MENU_SCENE = "res://escenas/main menu/Main-Menu.tscn"
var _menu_actual: Node = null

# Getter para compatibilidad con C# si alguien llamaba a la propiedad
var menu_abierto: bool:
	get:
		return _menu_actual != null

func _ready() -> void:
	print("[MenuSystem] Listo (GDScript)")

# Wrappers snake_case para llamadas externas
func obtener_screenshot():
	return _obtener_screenshot_impl()

func abrir_menu() -> void:
	_abrir_menu_impl()

func cerrar_menu() -> void:
	_cerrar_menu_impl()

func salir_como_esc() -> void:
	cerrar_menu()

func es_menu_abierto() -> bool:
	return _menu_actual != null

# Lógica principal
func _abrir_menu_impl() -> void:
	if _menu_actual != null:
		return

	# Screenshot antes de pausar (GameManager es Autoload)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("GuardarScreenshot"):
			gm.call("GuardarScreenshot")
		if gm.has_method("AbrirPantalla"):
			gm.call("AbrirPantalla", "menu")

	var scene = load(MENU_SCENE)
	if scene == null:
		push_error("[MenuSystem] No se pudo cargar Main-Menu.tscn en " + MENU_SCENE)
		return

	_menu_actual = scene.instantiate()
	get_tree().root.add_child(_menu_actual)
	print("[MenuSystem] Menú abierto")

func _cerrar_menu_impl() -> void:
	if _menu_actual:
		_menu_actual.queue_free()
		_menu_actual = null
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("CerrarPantalla"):
		gm.call("CerrarPantalla")
	print("[MenuSystem] Menú cerrado -> volviendo al juego")

func _obtener_screenshot_impl():
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return null
	if gm.has_method("ObtenerScreenshot"):
		return gm.call("ObtenerScreenshot")
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit"):
		if _menu_actual != null:
			cerrar_menu()
		else:
			abrir_menu()

		get_viewport().set_input_as_handled()
