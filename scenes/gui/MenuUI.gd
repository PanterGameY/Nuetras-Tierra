# MenuUI.gd - Escena del menú con screenshot de fondo
extends Control

const PHONE_ASPECT_RATIO: float = 9.0 / 19.5

# ════════════════════════════════════════════════════════════════
# REFERENCIAS
# ════════════════════════════════════════════════════════════════
@onready var texture_screenshot: TextureRect = $FondoScreenshot/TextureScreenshot
@onready var panel_movil: PanelContainer = $SafeArea/PanelMovil
@onready var grid_botones: GridContainer = $SafeArea/PanelMovil/PanelMargin/VBox/GridBotones
@onready var lbl_dinero: Label = $SafeArea/PanelMovil/PanelMargin/VBox/DineroHora/LblDinero
@onready var lbl_hora: Label = $SafeArea/PanelMovil/PanelMargin/VBox/DineroHora/LblHora
@onready var btn_cerrar: ColorRect = $SafeArea/PanelMovil/PanelMargin/VBox/Header/BtnCerrarX
@onready var btn_volver: ColorRect = $SafeArea/PanelMovil/PanelMargin/VBox/BtnVolver

# ════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ════════════════════════════════════════════════════════════════
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ajustar_layout_movil()
	
	var menu_system = get_node_or_null("/root/MenuSystem")
	if menu_system == null:
		push_error("[MenuUI] No se encontró /root/MenuSystem")
		return
	
	# Cargar screenshot
	var screenshot = menu_system.obtener_screenshot()
	if screenshot:
		texture_screenshot.texture = screenshot
		print("[MenuUI] Screenshot cargado")
	else:
		print("[MenuUI] No hay screenshot")
	
	# Conectar controles táctiles/click en ColorRect
	if btn_cerrar:
		btn_cerrar.gui_input.connect(_on_rect_input.bind("BtnCerrarX", "✕"))
	if btn_volver:
		btn_volver.gui_input.connect(_on_rect_input.bind("BtnVolver", "← VOLVER AL JUEGO"))

	for child in grid_botones.get_children():
		if child is ColorRect:
			var app_rect := child as ColorRect
			var texto := _texto_rect(app_rect)
			app_rect.gui_input.connect(_on_rect_input.bind(app_rect.name, texto))
	
	# Actualizar información
	_actualizar_datos()

# ════════════════════════════════════════════════════════════════
# ACTUALIZAR DATOS
# ════════════════════════════════════════════════════════════════
func _actualizar_datos() -> void:
	if GameManager:
		var dinero = GameManager.obtener_dinero()
		lbl_dinero.text = "Dinero: $%.2f" % dinero
		
		var hora = GameManager.obtener_hora_formateada(Time.get_ticks_msec() / 1000.0)
		lbl_hora.text = "Hora: " + hora

# ════════════════════════════════════════════════════════════════
# EVENTOS
# ════════════════════════════════════════════════════════════════
func _on_cerrar_presionado() -> void:
	var menu_system = get_node_or_null("/root/MenuSystem")
	if menu_system:
		menu_system.cerrar_menu()

func _on_salir_como_esc_presionado() -> void:
	var menu_system = get_node_or_null("/root/MenuSystem")
	if menu_system:
		menu_system.salir_como_esc()

func _process(_delta: float) -> void:
	_actualizar_datos()

func _on_app_presionada(nombre: String, texto: String) -> void:
	print("[MenuUI] App presionada: %s (%s)" % [nombre, texto])
	
	# Abrir diferentes escenas según el botón
	match nombre:
		"BtnOpciones":
			_abrir_opciones()
		"BtnMapa":
			print("[MenuUI] Abriendo Mapa...")
		"BtnInventario":
			print("[MenuUI] Abriendo Inventario...")
		"BtnCamara":
			print("[MenuUI] Abriendo Cámara...")
		"BtnMensajes":
			print("[MenuUI] Abriendo Mensajes...")
		"BtnTienda":
			print("[MenuUI] Abriendo Tienda...")
		"BtnMisiones":
			print("[MenuUI] Abriendo Misiones...")
		"BtnContactos":
			print("[MenuUI] Abriendo Contactos...")
		"BtnRadio":
			print("[MenuUI] Abriendo Radio...")

func _on_rect_input(event: InputEvent, nombre: String, texto: String) -> void:
	if not _es_presion_primaria(event):
		return

	if nombre == "BtnCerrarX":
		_on_salir_como_esc_presionado()
		get_viewport().set_input_as_handled()
		return

	if nombre == "BtnVolver":
		_on_cerrar_presionado()
		get_viewport().set_input_as_handled()
		return

	_on_app_presionada(nombre, texto)
	get_viewport().set_input_as_handled()

func _texto_rect(rect: ColorRect) -> String:
	var label := rect.get_node_or_null("Texto") as Label
	if label:
		return label.text
	return rect.name

func _es_presion_primaria(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

func _abrir_opciones() -> void:
	var opciones_scene = load("res://scenes/gui/Opciones.tscn")
	if opciones_scene:
		var opciones_instance = opciones_scene.instantiate()
		get_tree().root.add_child(opciones_instance)
		print("[MenuUI] Opciones abierta")
	else:
		push_error("[MenuUI] No se pudo cargar Opciones.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit"):
		_on_salir_como_esc_presionado()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_ajustar_layout_movil()

func _ajustar_layout_movil() -> void:
	# SafeArea y MarginContainer ya manejan el layout
	# Esta función se mantiene por compatibilidad
	pass
