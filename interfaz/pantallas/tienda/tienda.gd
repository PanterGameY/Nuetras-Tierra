extends Control
# Tienda del menu principal - Glassmorphism Automotriz
# Layout cockpit de 2 columnas: catalogo (65%) + inspector en vivo (35%).

signal compra_realizada(item: Dictionary)

const C_TEXT_PRIMARY := Color(0.88, 0.90, 0.93, 0.95)
const C_TEXT_MUTED := Color(0.50, 0.54, 0.58, 0.95)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.92)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_SURFACE_CARD := Color(0.09, 0.10, 0.12, 0.90)
const C_STEEL := Color(0.62, 0.72, 0.82, 1.0)

const ARCHIVO_COMPRAS := "user://tienda_compras.cfg"
const RUTA_FUENTE_CUERPO := "res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf"

const CATEGORIAS := [
	{"id": "vehiculos", "nombre": "VEHICULOS"},
	{"id": "licencias", "nombre": "LICENCIAS"},
	{"id": "mejoras", "nombre": "MEJORAS"},
	{"id": "estilos", "nombre": "PERSONALIZACION"},
	{"id": "packs", "nombre": "PACKS"},
	{"id": "esmeraldas", "nombre": "ESMERALDAS"}
]

# Catalogo completo de la Tienda
const CATALOGO := {
	"vehiculos": [],
	"licencias": [
		{
			"id": "licencia_c1",
			"licencia_cat": "C1",
			"codigo": "LIC-C1",
			"nombre": "Licencia C1",
			"tipo": "Livianos y Camionetas",
			"desc": "Habilita automóviles, camionetas y carga liviana.",
			"imagen": "res://recursos/iconos_tienda/licencia_c1.jpg",
			"precio_monedas": 150000,
			"precio_esmeraldas": 0,
			"rating": 0.45,
			"specs": [["Categoría", "C1"], ["Vehículos", "Autos y Camionetas"], ["Fletes", "Carga Liviana"]]
		},
		{
			"id": "licencia_c2",
			"licencia_cat": "C2",
			"codigo": "LIC-C2",
			"nombre": "Licencia C2",
			"tipo": "Camión Rígido",
			"desc": "Autoriza camiones rígidos y carga comercial media.",
			"imagen": "res://recursos/iconos_tienda/licencia_c2.jpg",
			"precio_monedas": 450000,
			"precio_esmeraldas": 0,
			"rating": 0.75,
			"specs": [["Categoría", "C2"], ["Vehículos", "Camiones Rígidos"], ["Incluye", "Categoría C1"]]
		},
		{
			"id": "licencia_c3",
			"licencia_cat": "C3",
			"codigo": "LIC-C3",
			"nombre": "Licencia C3",
			"tipo": "Tractomula Pesada",
			"desc": "Máxima categoría para tractocamiones y tráileres.",
			"imagen": "res://recursos/iconos_tienda/licencia_c3.jpg",
			"precio_monedas": 900000,
			"precio_esmeraldas": 0,
			"rating": 1.0,
			"specs": [["Categoría", "C3"], ["Vehículos", "Tractomulas y Tráileres"], ["Incluye", "C1 y C2"]]
		}
	],
	"mejoras": [],
	"estilos": [],
	"packs": [],
	"esmeraldas": []
}

@onready var main_container: MarginContainer = $MainContainer
@onready var barra_divisas: BarraDivisas = %Divisas
@onready var btn_salir: Button = %BtnSalir

@onready var pills_box: HBoxContainer = %PillsBox
@onready var label_conteo: Label = %LabelConteo
@onready var scroll_items: ScrollContainer = %ScrollItems
@onready var grid_items: GridContainer = %GridItems

@onready var ins_codigo: Label = %InsCodigo
@onready var ins_tipo: Label = %InsTipo
@onready var ins_categoria: Label = %InsCategoria
@onready var ins_nombre: Label = %InsNombre
@onready var ins_precio: Label = %InsPrecio
@onready var ins_desc: Label = %InsDesc
@onready var ins_specs: VBoxContainer = %InsSpecs
@onready var ins_rendimiento_box: VBoxContainer = %InsRendimientoBox
@onready var ins_barra: ProgressBar = %InsBarra
@onready var ins_valor_rendimiento: Label = %InsValorRendimiento
@onready var ins_disp_valor: Label = %InsDispValor
@onready var ins_costo_valor: Label = %InsCostoValor
@onready var btn_comprar: Button = %BtnComprar
@onready var ins_estado: Label = %InsEstado
@onready var vbox_inspector: VBoxContainer = %VBoxInspector
@onready var ins_tile: PanelContainer = %InsTile

@onready var toast: PanelContainer = %Toast
@onready var label_toast: Label = %LabelToast

@onready var modal_compra: Control = %ModalCompra
@onready var panel_compra: PanelContainer = %PanelCompra
@onready var modal_eyebrow: Label = %ModalEyebrow
@onready var modal_titulo: Label = %ModalTitulo
@onready var modal_tipo: Label = %ModalTipo
@onready var modal_desc: Label = %ModalDesc
@onready var modal_precio: Label = %ModalPrecio
@onready var modal_saldo_actual: Label = %ModalSaldoActual
@onready var modal_saldo_despues: Label = %ModalSaldoDespues
@onready var modal_incluye: Label = %ModalIncluye
@onready var modal_alerta: Label = %ModalAlerta
@onready var modal_confirmar: Button = %BtnConfirmar
@onready var modal_cancelar: Button = %BtnCancelar
@onready var dim: ColorRect = %Dim

var _item_seleccionado: Dictionary = {}
var _categoria_actual: String = "vehiculos"
var _cards: Dictionary = {}
var _pills: Dictionary = {}
var _compras: Dictionary = {}
var _modal_tween: Tween = null
var _toast_tween: Tween = null
var _audio_compra: AudioStreamPlayer = null
var _pago_en_curso: bool = false
var _fuente_cuerpo: Font = null


func _ready() -> void:
	if ResourceLoader.exists(RUTA_FUENTE_CUERPO):
		_fuente_cuerpo = load(RUTA_FUENTE_CUERPO) as Font
	_aplicar_estilo_cuerpo_inspector()
	_cargar_compras()
	modal_compra.visible = false
	toast.visible = false

	btn_salir.pressed.connect(_on_btn_volver_pressed)
	btn_comprar.pressed.connect(_on_btn_comprar_pressed)
	modal_confirmar.pressed.connect(_on_confirmar_compra)
	modal_cancelar.pressed.connect(_ocultar_modal_compra)
	dim.gui_input.connect(_on_dim_gui_input)

	_construir_pills()
	_actualizar_divisas()
	_cambiar_categoria("vehiculos")
	_animar_entrada()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if modal_compra.visible:
			_ocultar_modal_compra()
		else:
			_on_btn_volver_pressed()


# ---------------------------------------------------------------------------
# Construccion de la interfaz
# ---------------------------------------------------------------------------

func _construir_pills() -> void:
	for hijo in pills_box.get_children():
		hijo.free()
	_pills.clear()

	for categoria in CATEGORIAS:
		var id: String = str(categoria["id"])
		var lista: Array = CATALOGO.get(id, [])
		var btn := Button.new()
		btn.text = "%s   %02d" % [str(categoria["nombre"]), lista.size()]
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_cambiar_categoria.bind(id))
		pills_box.add_child(btn)
		_pills[id] = btn

	_actualizar_pills()


func _actualizar_pills() -> void:
	for categoria in CATEGORIAS:
		var id: String = str(categoria["id"])
		if not _pills.has(id):
			continue
		var btn: Button = _pills[id]
		var activo: bool = id == _categoria_actual
		btn.add_theme_stylebox_override("normal", _estilo_pill(activo, false))
		btn.add_theme_stylebox_override("hover", _estilo_pill(true, true))
		btn.add_theme_stylebox_override("pressed", _estilo_pill(true, false))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", C_AMBER if activo else C_TEXT_MUTED)
		btn.add_theme_color_override("font_hover_color", C_AMBER if activo else C_TEXT_PRIMARY)
		btn.add_theme_color_override("font_pressed_color", C_AMBER)


func _estilo_pill(activo: bool, hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(1)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	if activo:
		sb.bg_color = Color(0.88, 0.68, 0.28, 0.16)
		sb.border_color = Color(0.88, 0.68, 0.28, 0.70)
	elif hover:
		sb.bg_color = Color(0.14, 0.16, 0.19, 0.90)
		sb.border_color = Color(0.85, 0.88, 0.92, 0.38)
	else:
		sb.bg_color = Color(0.08, 0.09, 0.11, 0.72)
		sb.border_color = Color(0.78, 0.81, 0.85, 0.18)
	return sb


func _cambiar_categoria(cat: String) -> void:
	_categoria_actual = cat
	_actualizar_pills()
	_cargar_categoria(cat)
	scroll_items.scroll_vertical = 0


func _cargar_categoria(cat: String) -> void:
	for hijo in grid_items.get_children():
		hijo.free()
	_cards.clear()

	var items: Array = CATALOGO.get(cat, [])
	label_conteo.text = "%d ARTICULOS" % items.size()

	var tiene_imagenes := false
	for it in items:
		if str(it.get("imagen", "")) != "":
			tiene_imagenes = true
			break

	if tiene_imagenes:
		grid_items.columns = 3
		grid_items.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid_items.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		grid_items.columns = 2
		grid_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_items.size_flags_vertical = Control.SIZE_FILL

	for i in range(items.size()):
		var item: Dictionary = items[i]
		_crear_tarjeta(item, cat, i, cat == "esmeraldas")

	if items.is_empty():
		var lbl_vacio := Label.new()
		lbl_vacio.text = "No hay artículos disponibles por ahora."
		lbl_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_vacio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_vacio.custom_minimum_size = Vector2(0, 200)
		lbl_vacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_vacio.add_theme_font_size_override("font_size", 22)
		lbl_vacio.add_theme_color_override("font_color", C_TEXT_MUTED)
		grid_items.add_child(lbl_vacio)
		_item_seleccionado = {}
		_mostrar_inspector_vacio()
		return

	_item_seleccionado = items[0]
	_seleccionar_item(_item_seleccionado, false)
	_animar_grid()


func _crear_tarjeta(item: Dictionary, cat: String, indice: int, compacto: bool = false) -> void:
	var id: String = str(item.get("id", ""))
	var acento := _color_categoria(cat)
	var acento_suave := Color(acento.r, acento.g, acento.b, 0.55)

	var card := Button.new()
	card.text = ""
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.custom_minimum_size = Vector2(0, 108 if compacto else 158)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true

	var normal := _estilo_tarjeta(C_SURFACE_CARD, C_FROST, 1)
	var hover := _estilo_tarjeta(Color(0.11, 0.12, 0.14, 0.94), Color(0.85, 0.88, 0.92, 0.40), 1)
	var seleccionada := _estilo_tarjeta(Color(0.16, 0.15, 0.11, 0.96), Color(0.88, 0.68, 0.28, 0.80), 1)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", seleccionada)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if compacto:
		var franja_compacta := ColorRect.new()
		franja_compacta.color = acento_suave
		franja_compacta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(franja_compacta)
		franja_compacta.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		franja_compacta.offset_right = 3.0

		var margen_compacto := MarginContainer.new()
		margen_compacto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margen_compacto.add_theme_constant_override("margin_left", 18)
		margen_compacto.add_theme_constant_override("margin_top", 14)
		margen_compacto.add_theme_constant_override("margin_right", 16)
		margen_compacto.add_theme_constant_override("margin_bottom", 14)
		margen_compacto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(margen_compacto)

		var fila_compacta := HBoxContainer.new()
		fila_compacta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila_compacta.add_theme_constant_override("separation", 12)
		margen_compacto.add_child(fila_compacta)

		var lbl_nombre_compacto := Label.new()
		lbl_nombre_compacto.text = str(item.get("nombre", ""))
		lbl_nombre_compacto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_nombre_compacto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_nombre_compacto.clip_text = true
		lbl_nombre_compacto.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_nombre_compacto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_nombre_compacto.add_theme_font_size_override("font_size", 18)
		lbl_nombre_compacto.add_theme_color_override("font_color", C_TEXT_PRIMARY)
		fila_compacta.add_child(lbl_nombre_compacto)

		var lbl_precio_compacto := Label.new()
		lbl_precio_compacto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_precio_compacto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_precio_compacto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_precio_compacto.add_theme_font_size_override("font_size", 18)
		lbl_precio_compacto.add_theme_color_override("font_color", C_AMBER)
		lbl_precio_compacto.text = _texto_precio(item, true)
		fila_compacta.add_child(lbl_precio_compacto)

		card.pressed.connect(_on_card_pressed.bind(item))
		grid_items.add_child(card)
		_cards[id] = {
			"button": card,
			"normal": normal,
			"hover": hover,
			"selected": seleccionada,
			"precio": lbl_precio_compacto,
			"item": item
		}

		card.modulate.a = 0.0
		var tw_compacto := create_tween()
		tw_compacto.tween_interval(0.025 * float(indice))
		tw_compacto.tween_property(card, "modulate:a", 1.0, 0.20)
		return

	# Franja de color por categoria
	var franja := ColorRect.new()
	franja.color = acento_suave
	franja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(franja)
	franja.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	franja.offset_right = 3.0

	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_theme_constant_override("margin_left", 18)
	margen.add_theme_constant_override("margin_top", 14)
	margen.add_theme_constant_override("margin_right", 16)
	margen.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margen)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ruta_img := str(item.get("imagen", ""))
	var tiene_img := ruta_img != "" and ResourceLoader.exists(ruta_img)
	if tiene_img and not compacto:
		card.custom_minimum_size = Vector2(390, 390)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		margen.add_theme_constant_override("margin_left", 10)
		margen.add_theme_constant_override("margin_top", 10)
		margen.add_theme_constant_override("margin_right", 10)
		margen.add_theme_constant_override("margin_bottom", 10)
		var cont_v := VBoxContainer.new()
		cont_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cont_v.add_theme_constant_override("separation", 8)
		margen.add_child(cont_v)

		var lbl_nombre_img := Label.new()
		lbl_nombre_img.text = str(item.get("nombre", ""))
		lbl_nombre_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_nombre_img.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_nombre_img.clip_text = true
		lbl_nombre_img.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_nombre_img.add_theme_font_size_override("font_size", 22)
		lbl_nombre_img.add_theme_color_override("font_color", C_TEXT_PRIMARY)
		cont_v.add_child(lbl_nombre_img)

		var preview_panel := PanelContainer.new()
		preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_panel.clip_contents = true
		var pv_sb := StyleBoxFlat.new()
		pv_sb.bg_color = Color(0.05, 0.06, 0.08, 0.90)
		pv_sb.set_border_width_all(1)
		pv_sb.border_color = Color(acento.r, acento.g, acento.b, 0.28)
		pv_sb.set_corner_radius_all(10)
		preview_panel.add_theme_stylebox_override("panel", pv_sb)
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(ruta_img) as Texture2D
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_panel.add_child(tex_rect)
		cont_v.add_child(preview_panel)

		var lbl_precio_img := Label.new()
		lbl_precio_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl_precio_img.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_precio_img.add_theme_font_size_override("font_size", 26)
		lbl_precio_img.add_theme_color_override("font_color", C_AMBER)
		cont_v.add_child(lbl_precio_img)

		card.pressed.connect(_on_card_pressed.bind(item))
		grid_items.add_child(card)
		_cards[id] = {
			"button": card,
			"normal": normal,
			"hover": hover,
			"selected": seleccionada,
			"precio": lbl_precio_img,
			"item": item
		}

		card.modulate.a = 0.0
		var tw_img := create_tween()
		tw_img.tween_interval(0.025 * float(indice))
		tw_img.tween_property(card, "modulate:a", 1.0, 0.20)
		return

	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 14)
	margen.add_child(fila)

	# Insignia tipografica del producto
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(58, 58)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.clip_contents = true
	var tile_sb := StyleBoxFlat.new()
	tile_sb.bg_color = Color(acento.r, acento.g, acento.b, 0.14)
	tile_sb.set_border_width_all(1)
	tile_sb.border_color = Color(acento.r, acento.g, acento.b, 0.34)
	tile_sb.set_corner_radius_all(10)
	tile.add_theme_stylebox_override("panel", tile_sb)
	var lbl_codigo := Label.new()
	lbl_codigo.text = str(item.get("codigo", "--"))
	lbl_codigo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_codigo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_codigo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_codigo.add_theme_font_size_override("font_size", 17)
	lbl_codigo.add_theme_color_override("font_color", acento)
	tile.add_child(lbl_codigo)
	fila.add_child(tile)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	fila.add_child(vbox)

	var lbl_nombre := Label.new()
	lbl_nombre.text = str(item.get("nombre", ""))
	lbl_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_nombre.clip_text = true
	lbl_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_nombre.add_theme_font_size_override("font_size", 19)
	lbl_nombre.add_theme_color_override("font_color", C_TEXT_PRIMARY)
	vbox.add_child(lbl_nombre)

	var lbl_tipo := Label.new()
	lbl_tipo.text = str(item.get("tipo", "")).to_upper()
	lbl_tipo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_tipo.add_theme_font_size_override("font_size", 11)
	lbl_tipo.add_theme_color_override("font_color", C_TEXT_MUTED)
	vbox.add_child(lbl_tipo)

	var lbl_desc := Label.new()
	lbl_desc.text = str(item.get("desc", ""))
	lbl_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.max_lines_visible = 2
	lbl_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_desc.add_theme_font_size_override("font_size", 13)
	lbl_desc.add_theme_color_override("font_color", C_TEXT_MUTED)
	vbox.add_child(lbl_desc)

	var pie := HBoxContainer.new()
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_theme_constant_override("separation", 10)
	vbox.add_child(pie)

	var specs: Array = item.get("specs", [])
	var lbl_specs := Label.new()
	lbl_specs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_specs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_specs.clip_text = true
	lbl_specs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if specs.size() >= 2:
		lbl_specs.text = "%s  /  %s" % [str(specs[0][1]), str(specs[1][1])]
	elif specs.size() == 1:
		lbl_specs.text = str(specs[0][1])
	lbl_specs.add_theme_font_size_override("font_size", 12)
	lbl_specs.add_theme_color_override("font_color", C_TEXT_MUTED)
	pie.add_child(lbl_specs)

	var lbl_precio := Label.new()
	lbl_precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_precio.add_theme_font_size_override("font_size", 14)
	lbl_precio.add_theme_color_override("font_color", C_AMBER)
	pie.add_child(lbl_precio)

	card.pressed.connect(_on_card_pressed.bind(item))
	grid_items.add_child(card)

	_cards[id] = {
		"button": card,
		"normal": normal,
		"hover": hover,
		"selected": seleccionada,
		"precio": lbl_precio,
		"item": item
	}

	card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.025 * float(indice))
	tw.tween_property(card, "modulate:a", 1.0, 0.20)


func _estilo_tarjeta(bg: Color, borde: Color, radio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = borde
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	return sb


func _on_card_pressed(item: Dictionary) -> void:
	_seleccionar_item(item, true)


func _seleccionar_item(item: Dictionary, animar: bool) -> void:
	_item_seleccionado = item
	_actualizar_tarjetas()
	_actualizar_inspector()

	if animar and _cards.has(str(item.get("id", ""))):
		var card: Button = _cards[str(item.get("id", ""))]["button"]
		card.pivot_offset = card.size * 0.5
		var tw := create_tween()
		tw.tween_property(card, "scale", Vector2(0.985, 0.985), 0.06)
		tw.tween_property(card, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animar_grid() -> void:
	for i in range(grid_items.get_child_count()):
		var card: Control = grid_items.get_child(i)
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.02 * float(i))
		tw.tween_property(card, "modulate:a", 1.0, 0.18)


# ---------------------------------------------------------------------------
# Inspector en vivo
# ---------------------------------------------------------------------------

func _actualizar_inspector() -> void:
	var item := _item_seleccionado
	if item.is_empty():
		_mostrar_inspector_vacio()
		return

	var acento := _color_categoria(_categoria_actual)
	ins_codigo.text = str(item.get("codigo", "--"))
	ins_codigo.add_theme_color_override("font_color", acento)
	ins_tipo.text = str(item.get("tipo", "")).to_upper()
	ins_categoria.text = _nombre_categoria(_categoria_actual).to_upper()
	ins_nombre.text = str(item.get("nombre", ""))
	ins_precio.text = _texto_precio(item, false)
	ins_desc.text = str(item.get("desc", ""))

	var tile_sb := StyleBoxFlat.new()
	tile_sb.bg_color = Color(acento.r, acento.g, acento.b, 0.12)
	tile_sb.set_border_width_all(1)
	tile_sb.border_color = Color(acento.r, acento.g, acento.b, 0.32)
	tile_sb.set_corner_radius_all(10)
	ins_tile.add_theme_stylebox_override("panel", tile_sb)
	var ins_img := ins_tile.get_node_or_null("InsImg") as TextureRect
	var margen_tile := ins_tile.get_node_or_null("MargenTile") as Control
	var ruta_img_ins := str(item.get("imagen", ""))
	var tiene_img_ins := ruta_img_ins != "" and ResourceLoader.exists(ruta_img_ins)
	if tiene_img_ins:
		ins_tile.custom_minimum_size = Vector2(0, 320)
		if margen_tile:
			margen_tile.visible = false
		if ins_img == null:
			ins_img = TextureRect.new()
			ins_img.name = "InsImg"
			ins_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ins_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ins_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ins_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ins_tile.add_child(ins_img)
		ins_img.texture = load(ruta_img_ins) as Texture2D
		ins_img.visible = true
		ins_codigo.visible = false
	else:
		ins_tile.custom_minimum_size = Vector2(0, 120)
		if margen_tile:
			margen_tile.visible = true
		if ins_img:
			ins_img.visible = false
		ins_codigo.visible = true

	for hijo in ins_specs.get_children():
		hijo.free()
	var specs: Array = item.get("specs", [])
	for spec in specs:
		ins_specs.add_child(_crear_fila_spec(str(spec[0]), str(spec[1])))

	var paquete_usd := _es_paquete_usd(item)
	var es_licencia := item.has("licencia_cat")
	var ocultar_detalle := paquete_usd or tiene_img_ins
	ins_specs.visible = not ocultar_detalle
	ins_rendimiento_box.visible = not ocultar_detalle
	var specs_titulo := ins_specs.get_parent().find_child("InsSpecsTitulo", false, false)
	if specs_titulo is Label:
		(specs_titulo as Label).visible = not ocultar_detalle

	var fila_disp := vbox_inspector.get_node_or_null("InsDisponibleFila") as Control
	var fila_costo := vbox_inspector.get_node_or_null("InsCostoFila") as Control
	var div2_ctrl := vbox_inspector.get_node_or_null("InsDivisor2") as Control
	if fila_disp: fila_disp.visible = not es_licencia
	if fila_costo: fila_costo.visible = not es_licencia
	if div2_ctrl: div2_ctrl.visible = not es_licencia

	# Empujar el bloque de precio/disponible/botón hacia abajo cuando hay imagen grande
	var scroll_ins := vbox_inspector.get_parent() as ScrollContainer
	if tiene_img_ins and scroll_ins:
		vbox_inspector.custom_minimum_size.y = maxf(scroll_ins.size.y - 4.0, 0.0)
	else:
		vbox_inspector.custom_minimum_size.y = 0.0
	vbox_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL if tiene_img_ins else Control.SIZE_FILL
	var spacer_inf := vbox_inspector.get_node_or_null("InsBottomSpacer") as Control
	if tiene_img_ins:
		if spacer_inf == null:
			spacer_inf = Control.new()
			spacer_inf.name = "InsBottomSpacer"
			spacer_inf.size_flags_vertical = Control.SIZE_EXPAND_FILL
			spacer_inf.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox_inspector.add_child(spacer_inf)
			var div2 := vbox_inspector.get_node_or_null("InsDivisor2")
			if div2:
				vbox_inspector.move_child(spacer_inf, div2.get_index())
		spacer_inf.visible = true
	elif spacer_inf:
		spacer_inf.visible = false

	if paquete_usd:
		ins_barra.value = 0.0
		ins_valor_rendimiento.text = ""
	else:
		var rating: float = float(item.get("rating", 0.5))
		ins_barra.value = rating * 100.0
		ins_valor_rendimiento.text = "%d%%" % int(round(rating * 100.0))

	_actualizar_balance_inspector()
	_actualizar_estado_compra()

	vbox_inspector.modulate.a = 0.55
	create_tween().tween_property(vbox_inspector, "modulate:a", 1.0, 0.18)


func _aplicar_estilo_cuerpo_inspector() -> void:
	if ins_desc:
		ins_desc.add_theme_font_size_override("font_size", 28)
		ins_desc.add_theme_color_override("font_color", Color(0.84, 0.87, 0.91, 0.95))
		if _fuente_cuerpo:
			ins_desc.add_theme_font_override("font", _fuente_cuerpo)
	var lbl_disp := vbox_inspector.find_child("LabelDisponible", true, false) as Label
	var lbl_costo := vbox_inspector.find_child("LabelCosto", true, false) as Label
	for lbl in [lbl_disp, lbl_costo]:
		if lbl:
			lbl.add_theme_font_size_override("font_size", 20)
			if _fuente_cuerpo:
				lbl.add_theme_font_override("font", _fuente_cuerpo)
	for lbl_val in [ins_disp_valor, ins_costo_valor]:
		if lbl_val:
			lbl_val.add_theme_font_size_override("font_size", 22)
			if _fuente_cuerpo:
				lbl_val.add_theme_font_override("font", _fuente_cuerpo)
	if ins_estado:
		ins_estado.add_theme_font_size_override("font_size", 20)
		if _fuente_cuerpo:
			ins_estado.add_theme_font_override("font", _fuente_cuerpo)

	# Agrandar cabecera de catálogo y barra inferior de pasos para legibilidad en celular
	var col_cat := main_container.find_child("ColCatalogo", true, false) as Control
	if col_cat:
		var lbl_cat := col_cat.find_child("LabelCatalogo", true, false) as Label
		if lbl_cat:
			lbl_cat.add_theme_font_size_override("font_size", 18)
		if label_conteo:
			label_conteo.add_theme_font_size_override("font_size", 18)
		for titulo_paso in ["TituloPaso1", "TituloPaso2", "TituloPaso3"]:
			var tp := col_cat.find_child(titulo_paso, true, false) as Label
			if tp:
				tp.add_theme_font_size_override("font_size", 17)
		for desc_paso in ["DescPaso1", "DescPaso2", "DescPaso3"]:
			var dp := col_cat.find_child(desc_paso, true, false) as Label
			if dp:
				dp.add_theme_font_size_override("font_size", 18)
				dp.add_theme_color_override("font_color", Color(0.72, 0.76, 0.81, 0.95))
				if _fuente_cuerpo:
					dp.add_theme_font_override("font", _fuente_cuerpo)
	var scroll_ins := vbox_inspector.get_parent() as ScrollContainer
	if scroll_ins and not scroll_ins.resized.is_connected(_on_inspector_resized):
		scroll_ins.resized.connect(_on_inspector_resized)


func _on_inspector_resized() -> void:
	var scroll_ins := vbox_inspector.get_parent() as ScrollContainer
	if scroll_ins and str(_item_seleccionado.get("imagen", "")) != "":
		vbox_inspector.custom_minimum_size.y = maxf(scroll_ins.size.y - 4.0, 0.0)


func _crear_fila_spec(clave: String, valor: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 10)

	var lbl_clave := Label.new()
	lbl_clave.text = clave
	lbl_clave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_clave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_clave.add_theme_font_size_override("font_size", 11)
	lbl_clave.add_theme_color_override("font_color", C_TEXT_MUTED)

	var lbl_valor := Label.new()
	lbl_valor.text = valor
	lbl_valor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_valor.add_theme_font_size_override("font_size", 13)
	lbl_valor.add_theme_color_override("font_color", C_TEXT_PRIMARY)

	fila.add_child(lbl_clave)
	fila.add_child(lbl_valor)
	return fila


func _actualizar_balance_inspector() -> void:
	ins_disp_valor.text = "$ %s  /  %d ESM" % [_formato_entero(_dinero_actual()), _esmeraldas_actuales()]
	ins_costo_valor.text = _texto_precio(_item_seleccionado, true)


func _actualizar_estado_compra() -> void:
	var item := _item_seleccionado
	if item.is_empty():
		return

	var paquete_usd := _es_paquete_usd(item)
	var adquirido := _esta_comprado(str(item.get("id", ""))) and not paquete_usd
	var puede := _puede_pagar(item)

	if paquete_usd:
		btn_comprar.disabled = false
		btn_comprar.text = "COMPRAR POR " + _texto_precio(item, true)
		ins_estado.text = "MODO PRUEBA: no se realiza ningun cobro real."
		ins_estado.add_theme_color_override("font_color", C_AMBER)
	elif adquirido:
		btn_comprar.disabled = true
		btn_comprar.text = "ADQUIRIDO"
		ins_estado.text = "Este articulo ya forma parte de tu operacion."
		ins_estado.add_theme_color_override("font_color", C_AMBER)
	elif not puede:
		btn_comprar.disabled = true
		btn_comprar.text = "SALDO INSUFICIENTE"
		ins_estado.text = _texto_faltante(item)
		ins_estado.add_theme_color_override("font_color", Color(0.78, 0.42, 0.40, 0.95))
	else:
		btn_comprar.disabled = false
		if item.has("licencia_cat"):
			btn_comprar.text = "ADQUIRIR Y PROBAR"
			ins_estado.text = "Ir a la pista para realizar la prueba de manejo."
		else:
			btn_comprar.text = "COMPRAR AHORA"
			ins_estado.text = "Se descuenta al confirmar la operacion."
		ins_estado.add_theme_color_override("font_color", C_TEXT_MUTED)


func _mostrar_inspector_vacio() -> void:
	ins_codigo.text = "--"
	ins_tipo.text = "TIENDA VACÍA"
	ins_categoria.text = ""
	ins_nombre.text = "Sin artículos"
	ins_precio.text = ""
	ins_desc.text = "No hay artículos disponibles en la tienda en este momento."
	for hijo in ins_specs.get_children():
		hijo.free()
	ins_specs.visible = true
	ins_rendimiento_box.visible = true
	var specs_titulo := ins_specs.get_parent().find_child("InsSpecsTitulo", false, false)
	if specs_titulo is Label:
		(specs_titulo as Label).visible = true
	ins_barra.value = 0.0
	ins_valor_rendimiento.text = "0%"
	ins_disp_valor.text = ""
	ins_costo_valor.text = ""
	btn_comprar.disabled = true
	btn_comprar.text = "COMPRAR AHORA"
	ins_estado.text = ""


# ---------------------------------------------------------------------------
# Divisas y formato
# ---------------------------------------------------------------------------

func _actualizar_divisas() -> void:
	if barra_divisas:
		barra_divisas.refrescar(true)


func _dinero_actual() -> int:
	if not DatosUsuario:
		return 0
	return int(round(float(DatosUsuario.dinero)))


func _esmeraldas_actuales() -> int:
	if not DatosUsuario:
		return 0
	return int(DatosUsuario.esmeraldas)


func _puede_pagar(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if _es_paquete_usd(item):
		return true
	return _dinero_actual() >= int(item.get("precio_monedas", 0)) \
		and _esmeraldas_actuales() >= int(item.get("precio_esmeraldas", 0))


func _es_paquete_usd(item: Dictionary) -> bool:
	return float(item.get("precio_usd", 0.0)) > 0.0


func _formato_usd(valor: float) -> String:
	var centavos := int(round(valor * 100.0))
	var entero := int(floor(float(centavos) / 100.0))
	var decimales := centavos % 100
	return "$ %s,%02d USD" % [_formato_entero(entero), decimales]


func _texto_precio(item: Dictionary, compacto: bool) -> String:
	if _es_paquete_usd(item):
		return _formato_usd(float(item.get("precio_usd", 0.0)))
	var partes := PackedStringArray()
	var monedas := int(item.get("precio_monedas", 0))
	var esmeraldas := int(item.get("precio_esmeraldas", 0))
	if monedas > 0:
		partes.append("$ " + _formato_entero(monedas))
	if esmeraldas > 0:
		if compacto:
			partes.append("%d ESM" % esmeraldas)
		else:
			partes.append("%d Esmeraldas" % esmeraldas)
	return " + ".join(partes)


func _texto_recompensa(item: Dictionary) -> String:
	var partes := PackedStringArray()
	var incluye := str(item.get("incluye", ""))
	if incluye != "":
		partes.append(incluye)
	var monedas := int(item.get("recompensa_monedas", 0))
	var esmeraldas := int(item.get("recompensa_esmeraldas", 0))
	if monedas > 0:
		partes.append("$ " + _formato_entero(monedas))
	if esmeraldas > 0:
		partes.append("%d esmeraldas" % esmeraldas)
	return " + ".join(partes)


func _texto_faltante(item: Dictionary) -> String:
	if _es_paquete_usd(item):
		return ""
	var faltantes := PackedStringArray()
	var monedas := int(item.get("precio_monedas", 0)) - _dinero_actual()
	if monedas > 0:
		faltantes.append("$ " + _formato_entero(monedas))
	var esmeraldas := int(item.get("precio_esmeraldas", 0)) - _esmeraldas_actuales()
	if esmeraldas > 0:
		faltantes.append("%d esmeraldas" % esmeraldas)
	if faltantes.is_empty():
		return ""
	return "Te faltan " + " y ".join(faltantes) + " para esta compra."


func _texto_saldo() -> String:
	return "$ %s  /  %d ESM" % [_formato_entero(_dinero_actual()), _esmeraldas_actuales()]


func _formato_entero(valor: int) -> String:
	var negativo := valor < 0
	var digitos := str(absi(valor))
	var salida := ""
	var contador := 0
	for i in range(digitos.length() - 1, -1, -1):
		salida = digitos[i] + salida
		contador += 1
		if contador % 3 == 0 and i > 0:
			salida = "." + salida
	return ("-" if negativo else "") + salida


func _nombre_categoria(cat: String) -> String:
	for categoria in CATEGORIAS:
		if str(categoria["id"]) == cat:
			return str(categoria["nombre"])
	return cat.to_upper()


func _color_categoria(cat: String) -> Color:
	if cat == "vehiculos":
		return C_AMBER
	elif cat == "mejoras":
		return C_STEEL
	elif cat == "estilos":
		return Color(0.78, 0.28, 0.26, 1.0)
	elif cat == "packs":
		return Color(0.94, 0.80, 0.46, 1.0)
	elif cat == "esmeraldas":
		return C_STEEL
	return C_AMBER


# ---------------------------------------------------------------------------
# Estados de las tarjetas
# ---------------------------------------------------------------------------

func _actualizar_tarjetas() -> void:
	var id_seleccionado := str(_item_seleccionado.get("id", ""))

	for id in _cards:
		var datos: Dictionary = _cards[id]
		var card: Button = datos["button"]
		var item: Dictionary = datos["item"]
		var activo: bool = str(id) == id_seleccionado
		card.add_theme_stylebox_override("normal", datos["selected"] if activo else datos["normal"])
		card.add_theme_stylebox_override("hover", datos["selected"] if activo else datos["hover"])

		var precio: Label = datos["precio"]
		var es_usd := _es_paquete_usd(item)
		if _esta_comprado(str(id)) and not es_usd:
			precio.text = "ADQUIRIDO"
			precio.add_theme_color_override("font_color", C_AMBER)
		else:
			precio.text = _texto_precio(item, true)
			if _puede_pagar(item):
				precio.add_theme_color_override("font_color", C_AMBER)
			else:
				precio.add_theme_color_override("font_color", Color(0.72, 0.42, 0.40, 0.95))


# ---------------------------------------------------------------------------
# Modal de confirmacion
# ---------------------------------------------------------------------------

func _on_btn_comprar_pressed() -> void:
	if _item_seleccionado.is_empty():
		return
	if _esta_comprado(str(_item_seleccionado.get("id", ""))) and not _es_paquete_usd(_item_seleccionado):
		return
	_mostrar_modal_compra()


func _mostrar_modal_compra() -> void:
	var item := _item_seleccionado
	if item.is_empty():
		return

	var paquete_usd := _es_paquete_usd(item)
	modal_titulo.text = str(item.get("nombre", ""))
	modal_tipo.text = str(item.get("tipo", "")).to_upper()
	modal_desc.text = str(item.get("desc", ""))
	modal_precio.text = _texto_precio(item, false)
	modal_eyebrow.text = "PAGO SIMULADO" if paquete_usd else "CONFIRMAR OPERACION"

	if paquete_usd:
		modal_saldo_actual.text = "%d ESM" % _esmeraldas_actuales()
		modal_saldo_despues.text = "%d ESM" % (_esmeraldas_actuales() + int(item.get("recompensa_esmeraldas", 0)))
		modal_saldo_despues.add_theme_color_override("font_color", C_AMBER)
		modal_incluye.visible = true
		modal_incluye.text = "INCLUYE: +%d ESMERALDAS" % int(item.get("recompensa_esmeraldas", 0))
		modal_alerta.visible = true
		modal_alerta.text = "MODO PRUEBA: NO SE REALIZA NINGUN COBRO REAL."
		modal_confirmar.disabled = false
		modal_confirmar.text = "CONFIRMAR PAGO SIMULADO"
	else:
		modal_saldo_actual.text = _texto_saldo()
		var puede := _puede_pagar(item)
		var dinero_final := _dinero_actual() - int(item.get("precio_monedas", 0)) + int(item.get("recompensa_monedas", 0))
		var esm_final := _esmeraldas_actuales() - int(item.get("precio_esmeraldas", 0)) + int(item.get("recompensa_esmeraldas", 0))
		if puede:
			modal_saldo_despues.text = "$ %s  /  %d ESM" % [_formato_entero(dinero_final), esm_final]
			modal_saldo_despues.add_theme_color_override("font_color", C_AMBER)
		else:
			modal_saldo_despues.text = "SALDO INSUFICIENTE"
			modal_saldo_despues.add_theme_color_override("font_color", C_CRIMSON)

		var recompensa := _texto_recompensa(item)
		modal_incluye.visible = recompensa != ""
		modal_incluye.text = "INCLUYE: " + recompensa

		modal_alerta.visible = not puede
		modal_confirmar.disabled = not puede
		modal_confirmar.text = "CONFIRMAR COMPRA" if puede else "SALDO INSUFICIENTE"
		if not puede:
			modal_alerta.text = _texto_faltante(item)

	modal_compra.visible = true
	modal_compra.modulate.a = 0.0
	create_tween().tween_property(modal_compra, "modulate:a", 1.0, 0.16)

	await get_tree().process_frame
	panel_compra.pivot_offset = panel_compra.size * 0.5
	panel_compra.scale = Vector2(0.94, 0.94)
	panel_compra.modulate.a = 0.0

	if _modal_tween and _modal_tween.is_valid():
		_modal_tween.kill()
	_modal_tween = create_tween().set_parallel(true)
	_modal_tween.tween_property(panel_compra, "scale", Vector2.ONE, 0.30)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	_modal_tween.tween_property(panel_compra, "modulate:a", 1.0, 0.20)


func _ocultar_modal_compra() -> void:
	if not modal_compra.visible:
		return
	if _modal_tween and _modal_tween.is_valid():
		_modal_tween.kill()
	_modal_tween = create_tween().set_parallel(true)
	_modal_tween.tween_property(panel_compra, "scale", Vector2(0.96, 0.96), 0.14)
	_modal_tween.tween_property(panel_compra, "modulate:a", 0.0, 0.14)
	_modal_tween.tween_property(modal_compra, "modulate:a", 0.0, 0.16)
	_modal_tween.set_parallel(false)
	_modal_tween.tween_callback(func() -> void:
		modal_compra.visible = false
		modal_compra.modulate.a = 1.0
	)


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_ocultar_modal_compra()
			get_viewport().set_input_as_handled()


func _on_confirmar_compra() -> void:
	var item := _item_seleccionado
	if item.is_empty():
		return
	if _es_paquete_usd(item):
		_procesar_compra_esmeraldas(item)
		return
	if _esta_comprado(str(item.get("id", ""))):
		_ocultar_modal_compra()
		return
	if not _puede_pagar(item):
		modal_alerta.text = _texto_faltante(item)
		modal_alerta.visible = true
		return

	var costo_monedas := int(item.get("precio_monedas", 0))
	var costo_esmeraldas := int(item.get("precio_esmeraldas", 0))

	if DatosUsuario:
		DatosUsuario.dinero = maxf(0.0, float(DatosUsuario.dinero) - float(costo_monedas))
		DatosUsuario.esmeraldas = maxi(0, int(DatosUsuario.esmeraldas) - costo_esmeraldas)
		DatosUsuario.dinero += float(item.get("recompensa_monedas", 0))
		DatosUsuario.esmeraldas += int(item.get("recompensa_esmeraldas", 0))
		if item.has("licencia_cat"):
			DatosUsuario.licencia_prueba_pendiente = str(item.get("licencia_cat", ""))
			DatosUsuario.next_scene = "res://mundo/pruebas/pista_pruebas_pesados.tscn"
			DatosUsuario.save_local()
			_ocultar_modal_compra()
			_reproducir_sonido_compra()
			var carga_path := "res://interfaz/sistema/escena_carga.tscn"
			if ResourceLoader.exists(carga_path):
				get_tree().change_scene_to_file(carga_path)
			else:
				get_tree().change_scene_to_file("res://mundo/pruebas/pista_pruebas_pesados.tscn")
			return
		else:
			DatosUsuario.save_local()

	_registrar_compra(item)
	compra_realizada.emit(item.duplicate(true))
	_actualizar_divisas()
	_actualizar_tarjetas()
	_actualizar_balance_inspector()
	_actualizar_estado_compra()
	_ocultar_modal_compra()
	_mostrar_toast("COMPRA CONFIRMADA: " + str(item.get("nombre", "")))
	_reproducir_sonido_compra()


func _procesar_compra_esmeraldas(item: Dictionary) -> void:
	if _pago_en_curso:
		return
	_pago_en_curso = true
	var recompensa := int(item.get("recompensa_esmeraldas", 0))
	if DatosUsuario:
		DatosUsuario.esmeraldas += recompensa
		DatosUsuario.save_local()
	_registrar_compra_usd(item)
	compra_realizada.emit(item.duplicate(true))
	_actualizar_divisas()
	_actualizar_tarjetas()
	_actualizar_balance_inspector()
	_actualizar_estado_compra()
	_ocultar_modal_compra()
	_mostrar_toast("COMPRA SIMULADA: +%d ESMERALDAS" % recompensa)
	if barra_divisas:
		barra_divisas.pulsar_esmeraldas()
	_reproducir_sonido_compra()
	_pago_en_curso = false


func _pulsar_panel(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.10)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Aviso flotante
# ---------------------------------------------------------------------------

func _mostrar_toast(mensaje: String) -> void:
	label_toast.text = mensaje
	toast.visible = true
	toast.modulate.a = 0.0
	var destino_y := toast.position.y
	toast.position.y = destino_y + 10.0

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_property(toast, "position:y", destino_y, 0.26)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	_toast_tween.set_parallel(false)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.30)
	_toast_tween.tween_callback(func() -> void:
		toast.visible = false
	)


# ---------------------------------------------------------------------------
# Registro de compras
# ---------------------------------------------------------------------------

func _esta_comprado(id: String) -> bool:
	if _compras.has(id):
		return true
	if DatosUsuario and id.begins_with("licencia_") and DatosUsuario.has_method("tiene_licencia"):
		var cat := id.trim_prefix("licencia_").to_upper()
		return DatosUsuario.tiene_licencia(cat)
	return false


func _registrar_compra(item: Dictionary) -> void:
	var id := str(item.get("id", ""))
	if id == "":
		return
	_compras[id] = {
		"nombre": str(item.get("nombre", "")),
		"categoria": _categoria_actual,
		"fecha": Time.get_datetime_string_from_system(),
		"precio_monedas": int(item.get("precio_monedas", 0)),
		"precio_esmeraldas": int(item.get("precio_esmeraldas", 0))
	}
	_guardar_compras()


func _cargar_compras() -> void:
	_compras.clear()
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_COMPRAS) != OK:
		return
	if not cfg.has_section("compras"):
		return
	for key in cfg.get_section_keys("compras"):
		_compras[str(key)] = cfg.get_value("compras", key, {})


func _guardar_compras() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_COMPRAS)
	if cfg.has_section("compras"):
		cfg.erase_section("compras")
	for id in _compras:
		cfg.set_value("compras", str(id), _compras[id])
	var err := cfg.save(ARCHIVO_COMPRAS)
	if err != OK:
		push_warning("[Tienda] No se pudo guardar el registro de compras: %s" % err)


func _registrar_compra_usd(item: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_COMPRAS)
	var numero := int(cfg.get_value("historial_usd", "numero", 0)) + 1
	cfg.set_value("historial_usd", "numero", numero)
	cfg.set_value("historial_usd", "compra_%d" % numero, {
		"id": str(item.get("id", "")),
		"nombre": str(item.get("nombre", "")),
		"esmeraldas": int(item.get("recompensa_esmeraldas", 0)),
		"precio_usd": float(item.get("precio_usd", 0.0)),
		"fecha": Time.get_datetime_string_from_system()
	})
	var err := cfg.save(ARCHIVO_COMPRAS)
	if err != OK:
		push_warning("[Tienda] No se pudo guardar el historial USD: %s" % err)


func get_historial_esmeraldas() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_COMPRAS) != OK:
		return []
	var salida: Array = []
	for key in cfg.get_section_keys("historial_usd"):
		if str(key).begins_with("compra_"):
			salida.append(cfg.get_value("historial_usd", key, {}))
	return salida


func get_compras() -> Dictionary:
	return _compras.duplicate(true)


# ---------------------------------------------------------------------------
# Entrada y salida
# ---------------------------------------------------------------------------

func _animar_entrada() -> void:
	main_container.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(main_container, "modulate:a", 1.0, 0.30)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


func _reproducir_sonido_compra() -> void:
	if not ResourceLoader.exists("res://recursos/efectos/money.mp3"):
		return
	if _audio_compra == null:
		_audio_compra = AudioStreamPlayer.new()
		_audio_compra.stream = load("res://recursos/efectos/money.mp3")
		add_child(_audio_compra)
	_audio_compra.play()


func _on_btn_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn")
