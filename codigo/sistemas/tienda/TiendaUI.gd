# TiendaUI.gd
# Interfaz de usuario para la tienda de suministros y parador de ruta en Nuestra Tierra 2.0.
# Basada 100% en el Sistema de Diseño Glassmorphic Cockpit (Dark Slate, Instrument Amber y Technical Crimson).
class_name TiendaUI
extends CanvasLayer

signal tienda_abierta
signal tienda_cerrada
signal producto_comprado(item_id: String)

@onready var panel_fondo: PanelContainer
@onready var label_saldo: Label
@onready var grid_productos: GridContainer
@onready var contenedor_tabs: HBoxContainer
@onready var btn_cerrar: Button
@onready var banner_notif: PanelContainer
@onready var label_notif: Label

var categoria_seleccionada: int = TiendaItems.Categoria.TODOS
var _moderniz_font: Font = null
var jugador_ref: CharacterBody3D = null
var _audio_money: AudioStreamPlayer = null
var _tw_notif: Tween = null

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Cargar fuente oficial Moderniz
	var font_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		_moderniz_font = load(font_path)

	_crear_reproductor_audio()
	_construir_interfaz()
	cerrar_tienda(false)

func _crear_reproductor_audio() -> void:
	_audio_money = AudioStreamPlayer.new()
	_audio_money.bus = "Master"
	var snd_path := "res://recursos/efectos/money.mp3"
	if ResourceLoader.exists(snd_path):
		_audio_money.stream = load(snd_path)
	add_child(_audio_money)

func abrir_tienda(p_jugador: CharacterBody3D = null) -> void:
	if p_jugador:
		jugador_ref = p_jugador
	elif not jugador_ref:
		jugador_ref = get_tree().get_first_node_in_group("jugador") as CharacterBody3D

	# Bono de cortesía para pruebas si el usuario no tiene dinero
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and datos.dinero <= 0.0:
		datos.dinero = 50000.0

	visible = true
	_actualizar_saldo_ui()
	_poblar_catalogo()

	emit_signal("tienda_abierta")

	# Animación suave Automotive Glassmorphism (scale 0.94 -> 1.0, alpha 0.0 -> 1.0)
	panel_fondo.scale = Vector2(0.94, 0.94)
	panel_fondo.modulate.a = 0.0
	panel_fondo.pivot_offset = panel_fondo.size * 0.5

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_fondo, "scale", Vector2.ONE, 0.28)
	tw.tween_property(panel_fondo, "modulate:a", 1.0, 0.28)

func cerrar_tienda(animar: bool = true) -> void:
	if not visible:
		return

	if animar and is_instance_valid(panel_fondo):
		panel_fondo.pivot_offset = panel_fondo.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(panel_fondo, "scale", Vector2(0.95, 0.95), 0.18)
		tw.tween_property(panel_fondo, "modulate:a", 0.0, 0.18)
		await tw.finished

	visible = false
	emit_signal("tienda_cerrada")

func toggle_tienda() -> void:
	if visible:
		cerrar_tienda(true)
	else:
		abrir_tienda()

# ─────────────────────────────────────────────────────────────
#  CONSTRUCCIÓN DE LA INTERFAZ GLASSMORPHIC COCKPIT
# ─────────────────────────────────────────────────────────────

func _construir_interfaz() -> void:
	# 1. Overlay oscuro de fondo con tinte de cabina
	var overlay := ColorRect.new()
	overlay.name = "FondoOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.04, 0.75)
	add_child(overlay)

	# 2. Panel Central Cockpit Grande (Alineado al tamaño y estética del Celular/Tablet)
	panel_fondo = PanelContainer.new()
	panel_fondo.name = "PanelTienda"
	panel_fondo.set_anchors_preset(Control.PRESET_CENTER)
	panel_fondo.custom_minimum_size = Vector2(1620, 920)
	panel_fondo.offset_left = -810
	panel_fondo.offset_top = -460
	panel_fondo.offset_right = 810
	panel_fondo.offset_bottom = 460

	var sb_cockpit := StyleBoxFlat.new()
	sb_cockpit.bg_color = Color(0.06, 0.07, 0.08, 0.96) # Dark Slate Glass
	sb_cockpit.border_width_left = 1
	sb_cockpit.border_width_top = 1
	sb_cockpit.border_width_right = 1
	sb_cockpit.border_width_bottom = 1
	sb_cockpit.border_color = Color(0.78, 0.81, 0.85, 0.28) # Frost Metallic 1px
	sb_cockpit.corner_radius_top_left = 16
	sb_cockpit.corner_radius_top_right = 16
	sb_cockpit.corner_radius_bottom_left = 16
	sb_cockpit.corner_radius_bottom_right = 16
	sb_cockpit.shadow_size = 24
	sb_cockpit.shadow_color = Color(0, 0, 0, 0.65)
	panel_fondo.add_theme_stylebox_override("panel", sb_cockpit)
	add_child(panel_fondo)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel_fondo.add_child(margin)

	var vbox_principal := VBoxContainer.new()
	vbox_principal.add_theme_constant_override("separation", 20)
	margin.add_child(vbox_principal)

	# 3. Top Telemetry Strip
	var strip_telemetry := HBoxContainer.new()
	strip_telemetry.add_theme_constant_override("separation", 8)
	vbox_principal.add_child(strip_telemetry)

	var dot_led := Label.new()
	dot_led.text = "●"
	_aplicar_estilo_texto(dot_led, 18, Color(0.88, 0.68, 0.28, 0.95))
	strip_telemetry.add_child(dot_led)

	var lbl_strip := Label.new()
	lbl_strip.text = "ESTACIÓN DE SERVICIO & TIENDA RUTA 45  •  SERVICIO OFICIAL 24/7"
	_aplicar_estilo_texto(lbl_strip, 16, Color(0.78, 0.81, 0.85, 0.70))
	strip_telemetry.add_child(lbl_strip)

	# 4. Header Bar: Título grande, Tarjeta de Saldo y Botón Cerrar Carmesí
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 24)
	vbox_principal.add_child(header)

	var vbox_titulos := VBoxContainer.new()
	vbox_titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(vbox_titulos)

	var label_titulo := Label.new()
	label_titulo.text = "TIENDA DE CARRETERA"
	_aplicar_estilo_texto(label_titulo, 38, Color(0.92, 0.94, 0.97))
	vbox_titulos.add_child(label_titulo)

	var label_sub := Label.new()
	label_sub.text = "Suministros, provisiones de ruta y herramientas tácticas en mano"
	_aplicar_estilo_texto(label_sub, 18, Color(0.60, 0.65, 0.72))
	vbox_titulos.add_child(label_sub)

	# Tarjeta de Saldo en Ámbar
	var card_saldo := PanelContainer.new()
	var sb_saldo := StyleBoxFlat.new()
	sb_saldo.bg_color = Color(0.10, 0.12, 0.15, 0.92)
	sb_saldo.border_width_left = 1
	sb_saldo.border_width_top = 1
	sb_saldo.border_width_right = 1
	sb_saldo.border_width_bottom = 1
	sb_saldo.border_color = Color(0.88, 0.68, 0.28, 0.65) # Borde ámbar
	sb_saldo.corner_radius_top_left = 10
	sb_saldo.corner_radius_top_right = 10
	sb_saldo.corner_radius_bottom_left = 10
	sb_saldo.corner_radius_bottom_right = 10
	sb_saldo.content_margin_left = 22
	sb_saldo.content_margin_right = 22
	sb_saldo.content_margin_top = 8
	sb_saldo.content_margin_bottom = 8
	card_saldo.add_theme_stylebox_override("panel", sb_saldo)
	header.add_child(card_saldo)

	label_saldo = Label.new()
	label_saldo.text = "SALDO: $ 0 COP"
	_aplicar_estilo_texto(label_saldo, 26, Color(0.88, 0.68, 0.28, 0.98))
	card_saldo.add_child(label_saldo)

	# Botón Cerrar (Technical Crimson)
	btn_cerrar = Button.new()
	btn_cerrar.text = "✕ CERRAR"
	btn_cerrar.custom_minimum_size = Vector2(150, 50)
	_estilizar_boton_accion(btn_cerrar, Color(0.78, 0.28, 0.26, 0.95), Color(0.78, 0.28, 0.26, 0.35))
	btn_cerrar.pressed.connect(func(): cerrar_tienda(true))
	header.add_child(btn_cerrar)

	# Separador metálico fino de 1px
	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color(0.78, 0.81, 0.85, 0.18)
	sep.add_theme_stylebox_override("separator", sep_sb)
	vbox_principal.add_child(sep)

	# 5. Barra de Categorías / Pestañas
	contenedor_tabs = HBoxContainer.new()
	contenedor_tabs.add_theme_constant_override("separation", 14)
	vbox_principal.add_child(contenedor_tabs)

	_crear_tab_categoria("TODOS LOS PRODUCTOS", TiendaItems.Categoria.TODOS)
	_crear_tab_categoria("☕ BEBIDAS Y VÍVERES", TiendaItems.Categoria.BEBIDAS_Y_SNACKS)
	_crear_tab_categoria("🔧 HERRAMIENTAS MECÁNICAS", TiendaItems.Categoria.HERRAMIENTAS)
	_crear_tab_categoria("📦 EQUIPAMIENTO & CARGA", TiendaItems.Categoria.EQUIPAMIENTO)

	# 6. Scroll Container y Cuadrícula de Productos
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox_principal.add_child(scroll)

	grid_productos = GridContainer.new()
	grid_productos.columns = 3
	grid_productos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_productos.add_theme_constant_override("h_separation", 24)
	grid_productos.add_theme_constant_override("v_separation", 24)
	scroll.add_child(grid_productos)

	# 7. Banner Flotante de Notificación de Compra
	banner_notif = PanelContainer.new()
	banner_notif.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	banner_notif.anchor_top = 1.0
	banner_notif.anchor_bottom = 1.0
	banner_notif.offset_left = 60
	banner_notif.offset_right = -60
	banner_notif.offset_top = -80
	banner_notif.offset_bottom = -20

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.15, 0.19, 0.96)
	sb_n.border_width_left = 2
	sb_n.border_width_top = 2
	sb_n.border_width_right = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = Color(0.88, 0.68, 0.28, 0.95) # Amber Glow
	sb_n.corner_radius_top_left = 12
	sb_n.corner_radius_top_right = 12
	sb_n.corner_radius_bottom_left = 12
	sb_n.corner_radius_bottom_right = 12
	sb_n.shadow_size = 14
	sb_n.shadow_color = Color(0, 0, 0, 0.6)
	banner_notif.add_theme_stylebox_override("panel", sb_n)
	add_child(banner_notif)

	label_notif = Label.new()
	label_notif.text = "✓ ¡COMPRA EXITOSA! Objeto equipado en tu mano derecha."
	label_notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_notif.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aplicar_estilo_texto(label_notif, 22, Color(0.92, 0.94, 0.97))
	banner_notif.add_child(label_notif)
	banner_notif.visible = false

# ─────────────────────────────────────────────────────────────
#  POBLADO DEL CATÁLOGO Y COMPRA
# ─────────────────────────────────────────────────────────────

func _crear_tab_categoria(titulo: String, cat: int) -> void:
	var btn := Button.new()
	btn.text = titulo
	btn.custom_minimum_size = Vector2(230, 48)
	_estilizar_boton_tab(btn, cat == categoria_seleccionada)
	btn.pressed.connect(func():
		categoria_seleccionada = cat
		for child in contenedor_tabs.get_children():
			if child is Button:
				_estilizar_boton_tab(child, child == btn)
		_poblar_catalogo()
	)
	contenedor_tabs.add_child(btn)

func _poblar_catalogo() -> void:
	for c in grid_productos.get_children():
		c.queue_free()

	var catalogo := TiendaItems.get_catalogo()
	for item in catalogo:
		if categoria_seleccionada != TiendaItems.Categoria.TODOS and item["categoria"] != categoria_seleccionada:
			continue
		var card := _crear_tarjeta_producto(item)
		grid_productos.add_child(card)

func _crear_tarjeta_producto(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(470, 360)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Estilo Card Glassmorphic Premium
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.12, 0.94) # Dark Slate Card Glass
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.81, 0.85, 0.22) # Frost Metallic 1px
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.4)
	card.add_theme_stylebox_override("panel", sb)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_bottom", 18)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)

	# 1. Fila de Badge y Categoría
	var row_badge := HBoxContainer.new()
	vbox.add_child(row_badge)

	var badge_chip := Label.new()
	badge_chip.text = item.get("badge", "★ PRODUCTO RUTA")
	_aplicar_estilo_texto(badge_chip, 14, Color(0.88, 0.68, 0.28, 0.95))
	row_badge.add_child(badge_chip)

	# 2. Nombre del Producto en Moderniz
	var lbl_nom := Label.new()
	lbl_nom.text = item.get("nombre", "")
	lbl_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aplicar_estilo_texto(lbl_nom, 24, Color(0.92, 0.94, 0.97))
	vbox.add_child(lbl_nom)

	# 3. Descripción con buen contraste y tamaño
	var lbl_desc := Label.new()
	lbl_desc.text = item.get("descripcion", "")
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aplicar_estilo_texto(lbl_desc, 18, Color(0.68, 0.72, 0.78))
	vbox.add_child(lbl_desc)

	# 4. Fila de Precio y Acción
	var row_bot := HBoxContainer.new()
	row_bot.alignment = BoxContainer.ALIGNMENT_CENTER
	row_bot.add_theme_constant_override("separation", 16)
	vbox.add_child(row_bot)

	var lbl_precio := Label.new()
	lbl_precio.text = "$ " + _formatear_moneda(item.get("precio", 0.0)) + " COP"
	lbl_precio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aplicar_estilo_texto(lbl_precio, 26, Color(0.88, 0.68, 0.28, 0.98)) # Vibrant Amber
	row_bot.add_child(lbl_precio)

	# Botón de Compra Grande
	var btn_comprar := Button.new()
	btn_comprar.text = "COMPRAR Y EQUIPAR"
	btn_comprar.custom_minimum_size = Vector2(210, 52)
	_estilizar_boton_accion(btn_comprar, Color(0.88, 0.68, 0.28, 0.95), Color(0.88, 0.68, 0.28, 0.25))
	btn_comprar.pressed.connect(func(): _intentar_compra(item))
	row_bot.add_child(btn_comprar)

	return card

func _intentar_compra(item: Dictionary) -> void:
	var costo: float = float(item.get("precio", 0.0))
	var datos = get_node_or_null("/root/DatosUsuario")
	var saldo_actual: float = datos.dinero if datos else 0.0

	# Comprobación de saldo
	if saldo_actual < costo:
		_mostrar_notificacion_temporal("Saldo insuficiente. Necesitas $ " + _formatear_moneda(costo) + " COP", true)
		return

	# Deducción y guardado del estado
	if datos:
		datos.dinero -= costo
		if datos.has_method("save_local"):
			datos.save_local()

	_actualizar_saldo_ui()

	if _audio_money:
		_audio_money.play()

	# Equipar inmediatamente el item 3D en la mano del jugador
	var item_id: String = item.get("id", "")
	
	# Caso especial Gato Hidráulico: Iniciar directamente el sistema de colocación diegético frente a la cámara
	if item_id == "gato_hidraulico":
		var gato_escena := load("res://modelos3d/inventario/Gato-Hidraulico/gato_hidraulico.tscn") as PackedScene
		if gato_escena:
			var gato_inst := gato_escena.instantiate() as Node3D
			if gato_inst:
				var root_mundo: Node = get_tree().current_scene
				if not root_mundo:
					root_mundo = get_tree().root
				root_mundo.add_child(gato_inst)
				if gato_inst.has_method("iniciar_modo_colocacion"):
					gato_inst.call("iniciar_modo_colocacion")
				cerrar_tienda(true)
				emit_signal("producto_comprado", item_id)
				_mostrar_notificacion_temporal("✓ ¡Gato Hidráulico listo para colocar! Ajusta la posición y toca 'Listo'.", false)
				return

	if jugador_ref and jugador_ref.has_method("equipar_item_en_mano"):
		jugador_ref.equipar_item_en_mano(item_id)

	emit_signal("producto_comprado", item_id)
	_mostrar_notificacion_temporal("✓ ¡" + item.get("nombre", "") + " adquirido y equipado en tu mano derecha!", false)

func _mostrar_notificacion_temporal(texto: String, es_error: bool) -> void:
	if not banner_notif or not label_notif:
		return

	label_notif.text = texto
	var col_borde: Color = Color(0.78, 0.28, 0.26, 0.95) if es_error else Color(0.88, 0.68, 0.28, 0.95)
	var sb := banner_notif.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = col_borde

	banner_notif.visible = true
	banner_notif.modulate.a = 0.0

	if _tw_notif and _tw_notif.is_valid():
		_tw_notif.kill()

	_tw_notif = create_tween()
	_tw_notif.tween_property(banner_notif, "modulate:a", 1.0, 0.2)
	_tw_notif.tween_interval(2.6)
	_tw_notif.tween_property(banner_notif, "modulate:a", 0.0, 0.3)
	_tw_notif.tween_callback(func(): banner_notif.visible = false)

func _actualizar_saldo_ui() -> void:
	if not label_saldo:
		return
	var datos = get_node_or_null("/root/DatosUsuario")
	var saldo: float = datos.dinero if datos else 0.0
	label_saldo.text = "SALDO: $ " + _formatear_moneda(saldo) + " COP"

func _formatear_moneda(val: float) -> String:
	var s := str(int(val))
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res

# ─────────────────────────────────────────────────────────────
#  ESTILIZADO VISUAL AUTOMOTIVE GLASSMORPHISM
# ─────────────────────────────────────────────────────────────

func _aplicar_estilo_texto(lbl: Label, size: int, col: Color) -> void:
	if _moderniz_font:
		lbl.add_theme_font_override("font", _moderniz_font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)

func _estilizar_boton_tab(btn: Button, activo: bool) -> void:
	if _moderniz_font:
		btn.add_theme_font_override("font", _moderniz_font)
	btn.add_theme_font_size_override("font_size", 20)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10

	if activo:
		sb.bg_color = Color(0.18, 0.16, 0.12, 0.95)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 2
		sb.border_color = Color(0.88, 0.68, 0.28, 0.95) # Amber
		btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	else:
		sb.bg_color = Color(0.08, 0.09, 0.11, 0.80)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.78, 0.81, 0.85, 0.20)
		btn.add_theme_color_override("font_color", Color(0.65, 0.70, 0.76))

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)

func _estilizar_boton_accion(btn: Button, col_texto: Color, col_borde: Color) -> void:
	if _moderniz_font:
		btn.add_theme_font_override("font", _moderniz_font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", col_texto)

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.08, 0.09, 0.11, 0.85)
	sb_normal.border_width_left = 1
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 1
	sb_normal.border_color = col_borde
	sb_normal.corner_radius_top_left = 10
	sb_normal.corner_radius_top_right = 10
	sb_normal.corner_radius_bottom_left = 10
	sb_normal.corner_radius_bottom_right = 10
	sb_normal.shadow_size = 5
	sb_normal.shadow_color = Color(0, 0, 0, 0.35)
	btn.add_theme_stylebox_override("normal", sb_normal)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color(col_borde.r, col_borde.g, col_borde.b, 0.4)
	sb_pressed.border_width_left = 1
	sb_pressed.border_width_top = 1
	sb_pressed.border_width_right = 1
	sb_pressed.border_width_bottom = 2
	sb_pressed.border_color = col_texto
	sb_pressed.corner_radius_top_left = 10
	sb_pressed.corner_radius_top_right = 10
	sb_pressed.corner_radius_bottom_left = 10
	sb_pressed.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_normal)
