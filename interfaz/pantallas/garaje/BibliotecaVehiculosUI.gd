extends Control
class_name BibliotecaVehiculosUI

# ==============================================================================
# BIBLIOTECA_VEHICULOS_UI.GD — Visor de Catálogo y Garaje de Vehículos
# Sistema "Nuestra Tierra 2.0" - Glassmorphism Automotriz
# ==============================================================================

signal vehiculo_seleccionado(id_vehiculo: String)
signal personalizar_solicitado()
signal volver_solicitado()

# --- TOKENS DE DISEÑO (Glassmorphism Automotriz) ---
const C_BG_GLASS_DARK := Color(0.06, 0.07, 0.08, 0.95)
const C_BG_PANEL := Color(0.06, 0.07, 0.08, 0.85)
const C_SURFACE_CARD := Color(0.09, 0.10, 0.12, 0.92)
const C_SURFACE_ELEVATED := Color(0.12, 0.14, 0.17, 0.96)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.25)
const C_BORDER_SUBTLE := Color(0.78, 0.81, 0.85, 0.15)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.92)
const C_AMBER_GLOW := Color(0.88, 0.68, 0.28, 0.40)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_CRIMSON_HOVER := Color(0.90, 0.32, 0.30, 0.98)
const C_TEXT_PRIMARY := Color(0.92, 0.94, 0.96, 0.98)
const C_TEXT_MUTED := Color(0.60, 0.64, 0.70, 0.90)

const RUTA_FONT_MODERNIZ := "res://recursos/fonts/Moderniz.otf"
const RUTA_ICONO_PERSONALIZAR := "res://recursos/botones/fa_personalizar.svg"
const ESCENA_DIVISAS := preload("res://interfaz/componentes/divisas/BarraDivisas.tscn")

const FILTRO_MARCAS := ["TODAS", "KENWORTH", "CHEVROLET", "RENAULT", "TOYOTA"]
const FILTRO_TIPOS := ["TODOS", "TRACTOCAMION", "AUTOMOVIL", "SUV", "VAN"]
const FILTRO_PRECIOS := ["TODOS", "HASTA $ 60.000", "$ 60.001 - $ 120.000", "MAS DE $ 120.000"]
const FILTRO_ESTADOS := ["TODOS", "COMPRADOS", "BLOQUEADOS"]
const VEHICULO_INICIAL := "T800_A"

# Catálogo oficial de vehículos en el orden solicitado por el usuario:
# 1. T800_A, 2. Mespark, 3. Duster, 4. Hiage
const LISTA_VEHICULOS := [
	{
		"id": "T800_A",
		"nombre": "Kenworth T800 Alargada",
		"nombre_corto": "T800_A",
		"categoria": "TRACTOCAMIÓN PESADO",
		"marca": "Kenworth",
		"tipo_vehiculo": "TRACTOCAMION",
		"precio": 150000,
		"tipo": "Articulado 6x4",
		"motor": "Cummins ISX 500 HP",
		"traccion": "6x4 Doble Troque",
		"velocidad": "120 km/h",
		"peso": "9,850 kg",
		"capacidad": "48,000 kg (Arrastre)",
		"descripcion": "El titán por excelencia de la geografía colombiana. Chasis alargado con camarote de lujo y parachoques cromado de trabajo pesado para conquistar La Línea y el Alto de Minas.",
		"icono_num": "01",
		"preview_img": "res://recursos/imagenes/vehiculos_preview/t800_a.png"
	},
	{
		"id": "Mespark",
		"nombre": "Chevrolet Spark GT",
		"nombre_corto": "Mespark",
		"categoria": "AUTOMÓVIL URBANO",
		"marca": "Chevrolet",
		"tipo_vehiculo": "AUTOMOVIL",
		"precio": 45000,
		"tipo": "Hatchback 5P",
		"motor": "1.2L DOHC 16V 80 HP",
		"traccion": "Delantera (FWD)",
		"velocidad": "165 km/h",
		"peso": "965 kg",
		"capacidad": "5 Pasajeros",
		"descripcion": "Compacto ligero y eficiente, diseñado para el tráfico denso de las capitales y callejones estrechos con óptimo rendimiento de combustible.",
		"icono_num": "02",
		"preview_img": "res://recursos/imagenes/vehiculos_preview/mespark.png"
	},
	{
		"id": "Duster",
		"nombre": "Renault Duster 4x4",
		"nombre_corto": "Duster",
		"categoria": "SUV TODOTERRENO",
		"marca": "Renault",
		"tipo_vehiculo": "SUV",
		"precio": 95000,
		"tipo": "Camioneta 4WD",
		"motor": "2.0L 16V 143 HP",
		"traccion": "Total 4WD con Bloqueo",
		"velocidad": "178 km/h",
		"peso": "1,350 kg",
		"capacidad": "5 Pasajeros + Carga",
		"descripcion": "Auténtica camioneta de trocha preparada para el barro, vías destapadas y terrenos de alta montaña gracias a su despeje táctico al suelo.",
		"icono_num": "03",
		"preview_img": "res://recursos/imagenes/vehiculos_preview/duster.png"
	},
	{
		"id": "ToyotaHiace",
		"nombre": "Toyota HiAce Van",
		"nombre_corto": "Hiage",
		"categoria": "VANS & INTERMUNICIPAL",
		"marca": "Toyota",
		"tipo_vehiculo": "VAN",
		"precio": 120000,
		"tipo": "Van Colectivo / Reparto",
		"motor": "2.8L Turbo Diesel 174 HP",
		"traccion": "Trasera (RWD)",
		"velocidad": "150 km/h",
		"peso": "2,150 kg",
		"capacidad": "14 Pasajeros / Carga",
		"descripcion": "El transporte por excelencia del transporte intermunicipal y distribución de paquetería express en carreteras andinas.",
		"icono_num": "04",
		"preview_img": "res://recursos/imagenes/vehiculos_preview/hiage.png"
	},
	{
		"id": "Pardo",
		"nombre": "Toyota Land Cruiser Prado",
		"nombre_corto": "Pardo",
		"categoria": "CAMIONETA 4X4 DE LUJO",
		"marca": "Toyota",
		"tipo_vehiculo": "SUV",
		"precio": 220000,
		"tipo": "SUV Todoterreno 4WD",
		"motor": "4.0L V6 Dual VVT-i 271 HP",
		"traccion": "4x4 Permanente con Reductora",
		"velocidad": "185 km/h",
		"peso": "2,165 kg",
		"capacidad": "7 Pasajeros",
		"descripcion": "La camioneta todoterreno por excelencia de las carreteras colombianas. Potencia implacable, parrilla cromada y tracción total para dominar tanto el asfalto como las trochas más exigentes.",
		"icono_num": "05",
		"preview_img": "res://recursos/imagenes/vehiculos_preview/pardo.png"
	}
]

var id_vehiculo_actual: String = VEHICULO_INICIAL
var font_moderniz: Font = null
var icono_personalizar: Texture2D = null

# Filtros del catalogo
var filtro_marca: String = "TODAS"
var filtro_tipo: String = "TODOS"
var filtro_precio: String = "TODOS"
var filtro_estado: String = "TODOS"
var _opciones_filtro: Dictionary = {}
var _t_refresco_divisas: float = 0.0

# Controles UI
var root_layer: Control
var header_bar: PanelContainer
var btn_volver: Button
var lbl_titulo: Label
var lbl_subtitulo: Label
var barra_divisas: BarraDivisas = null
var lbl_dock_tit: Label = null
var _dialogo_garaje: AcceptDialog = null

var spec_card: PanelContainer
var lbl_spec_cat: Label
var lbl_spec_nombre: Label
var lbl_spec_sub: Label
var lbl_spec_precio: Label
var lbl_spec_estado: Label
var grid_specs: GridContainer
var lbl_spec_desc: Label

var bottom_dock: PanelContainer
var scroll_vehiculos: ScrollContainer
var hbox_cards: HBoxContainer
var cards_dict: Dictionary = {}

var btn_personalizar: Button
var hint_control: Label

func _ready() -> void:
	# El contenedor raíz pasa eventos de mouse para que la cámara 3D reciba arrastres
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_cargar_recursos()
	_asegurar_propietario_inicial()
	_construir_interfaz()
	_seleccionar_vehiculo(id_vehiculo_actual, false)
	_animar_entrada()


func _process(delta: float) -> void:
	if barra_divisas == null:
		return
	_t_refresco_divisas += delta
	if _t_refresco_divisas >= 0.5:
		_t_refresco_divisas = 0.0
		barra_divisas.refrescar(true)
func _cargar_recursos() -> void:
	if ResourceLoader.exists(RUTA_FONT_MODERNIZ):
		font_moderniz = load(RUTA_FONT_MODERNIZ)
	
	# Cargar icono oficial de FontAwesome descargado de la web
	var global_svg = ProjectSettings.globalize_path(RUTA_ICONO_PERSONALIZAR)
	if FileAccess.file_exists(global_svg):
		var img = Image.load_from_file(global_svg)
		if img:
			icono_personalizar = ImageTexture.create_from_image(img)
	if not icono_personalizar and ResourceLoader.exists(RUTA_ICONO_PERSONALIZAR):
		icono_personalizar = load(RUTA_ICONO_PERSONALIZAR)

func _asegurar_propietario_inicial() -> void:
	if not DatosUsuario:
		return
	if not (DatosUsuario.vehiculos_comprados is Dictionary):
		DatosUsuario.vehiculos_comprados = {}
	var comprados: Dictionary = DatosUsuario.vehiculos_comprados
	if not comprados.is_empty():
		return

	var personalizados = DatosUsuario.vehiculos_personalizados
	if personalizados is Dictionary:
		for clave in (personalizados as Dictionary).keys():
			var id_personalizado := _normalizar_id(str(clave))
			if id_personalizado != "" and not _datos_vehiculo(id_personalizado).is_empty():
				comprados[id_personalizado] = true

	var actual := str(DatosUsuario.guardado_player_vehiculo_nombre)
	var id_actual := _normalizar_id(actual)
	if id_actual != "" and not _datos_vehiculo(id_actual).is_empty():
		comprados[id_actual] = true

	if comprados.is_empty():
		return
	DatosUsuario.vehiculos_comprados = comprados
	DatosUsuario.save_local(true)


func _normalizar_id(id: String) -> String:
	if id == "T800_Alargada":
		return "T800_A"
	if id == "Hiage":
		return "ToyotaHiace"
	return id


func _construir_interfaz() -> void:
	root_layer = Control.new()
	root_layer.name = "RootLayer"
	root_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_layer)

	_crear_header()
	_crear_filtros()
	_crear_ficha_tecnica()
	_crear_boton_personalizar()
	_crear_carrusel_vehiculos()
	_crear_hint_camara()

# --- 1. CABECERA SUPERIOR ---
func _crear_header() -> void:
	header_bar = PanelContainer.new()
	header_bar.name = "HeaderBar"
	header_bar.anchor_left = 0.0
	header_bar.anchor_top = 0.0
	header_bar.anchor_right = 1.0
	header_bar.anchor_bottom = 0.0
	header_bar.offset_bottom = 110.0
	header_bar.mouse_filter = Control.MOUSE_FILTER_PASS

	var sb_header = StyleBoxFlat.new()
	sb_header.bg_color = C_BG_GLASS_DARK
	sb_header.border_width_bottom = 2
	sb_header.border_color = C_BORDER_FROST
	sb_header.shadow_color = Color(0, 0, 0, 0.55)
	sb_header.shadow_size = 12
	sb_header.shadow_offset = Vector2(0, 4)
	header_bar.add_theme_stylebox_override("panel", sb_header)
	root_layer.add_child(header_bar)

	var hbox = HBoxContainer.new()
	hbox.name = "HBoxHeader"
	hbox.add_theme_constant_override("separation", 28)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.add_child(hbox)
	header_bar.add_child(margin)

	# Botón Volver al Menú Principal (Technical Crimson con tipografía ampliada)
	btn_volver = Button.new()
	btn_volver.name = "BtnVolverMenu"
	btn_volver.text = "VOLVER AL MENU"
	btn_volver.custom_minimum_size = Vector2(280, 68)
	btn_volver.focus_mode = Control.FOCUS_NONE
	if font_moderniz:
		btn_volver.add_theme_font_override("font", font_moderniz)
	btn_volver.add_theme_font_size_override("font_size", 24)
	btn_volver.add_theme_color_override("font_color", C_TEXT_PRIMARY)

	var sb_v_norm = StyleBoxFlat.new()
	sb_v_norm.bg_color = Color(0.14, 0.08, 0.08, 0.88)
	sb_v_norm.set_border_width_all(2)
	sb_v_norm.border_color = C_CRIMSON
	sb_v_norm.set_corner_radius_all(12)
	sb_v_norm.shadow_color = Color(0, 0, 0, 0.40)
	sb_v_norm.shadow_size = 6

	var sb_v_hov = sb_v_norm.duplicate()
	sb_v_hov.bg_color = Color(0.28, 0.10, 0.10, 0.98)
	sb_v_hov.border_color = C_CRIMSON_HOVER

	var sb_v_pre = sb_v_norm.duplicate()
	sb_v_pre.bg_color = C_CRIMSON

	btn_volver.add_theme_stylebox_override("normal", sb_v_norm)
	btn_volver.add_theme_stylebox_override("hover", sb_v_hov)
	btn_volver.add_theme_stylebox_override("pressed", sb_v_pre)
	btn_volver.pressed.connect(_on_volver_pressed)
	hbox.add_child(btn_volver)

	# Título Central con jerarquía de tamaño grande
	var vbox_titulos = VBoxContainer.new()
	vbox_titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_titulos.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox_titulos)

	lbl_titulo = Label.new()
	lbl_titulo.text = "BIBLIOTECA DE VEHICULOS"
	if font_moderniz:
		lbl_titulo.add_theme_font_override("font", font_moderniz)
	lbl_titulo.add_theme_font_size_override("font_size", 44)
	lbl_titulo.add_theme_color_override("font_color", C_TEXT_PRIMARY)
	vbox_titulos.add_child(lbl_titulo)

	lbl_subtitulo = Label.new()
	lbl_subtitulo.text = "EXHIBICION Y CATALOGO OFICIAL - NUESTRA TIERRA 2.0"
	lbl_subtitulo.add_theme_font_size_override("font_size", 18)
	lbl_subtitulo.add_theme_color_override("font_color", C_AMBER)
	vbox_titulos.add_child(lbl_subtitulo)

	# Badge de Estado / Hangar
	var panel_badge = PanelContainer.new()
	var sb_badge = StyleBoxFlat.new()
	sb_badge.bg_color = Color(0.12, 0.14, 0.17, 0.94)
	sb_badge.set_border_width_all(2)
	sb_badge.border_color = C_AMBER
	sb_badge.set_corner_radius_all(10)
	sb_badge.content_margin_left = 22
	sb_badge.content_margin_right = 22
	sb_badge.content_margin_top = 10
	sb_badge.content_margin_bottom = 10
	panel_badge.add_theme_stylebox_override("panel", sb_badge)

	var lbl_badge = Label.new()
	lbl_badge.text = "FLOTA COCKPIT ACTIVA"
	if font_moderniz:
		lbl_badge.add_theme_font_override("font", font_moderniz)
	lbl_badge.add_theme_font_size_override("font_size", 20)
	lbl_badge.add_theme_color_override("font_color", C_AMBER)
	panel_badge.add_child(lbl_badge)
	hbox.add_child(panel_badge)

	# Bloque unificado de dinero y esmeraldas
	var instancia_divisas: Control = ESCENA_DIVISAS.instantiate()
	barra_divisas = instancia_divisas as BarraDivisas
	if barra_divisas:
		barra_divisas.compacta = true
		barra_divisas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(barra_divisas)

# --- 1B. BARRA DE FILTROS DEL CATALOGO ---
func _crear_filtros() -> void:
	var contenedor := PanelContainer.new()
	contenedor.name = "BarraFiltros"
	contenedor.anchor_right = 1.0
	contenedor.offset_left = 36.0
	contenedor.offset_top = 132.0
	contenedor.offset_right = -600.0
	contenedor.offset_bottom = 224.0
	contenedor.mouse_filter = Control.MOUSE_FILTER_PASS

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = C_BORDER_FROST
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	contenedor.add_theme_stylebox_override("panel", sb)
	root_layer.add_child(contenedor)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	contenedor.add_child(hbox)

	hbox.add_child(_crear_grupo_filtro("MARCA", FILTRO_MARCAS, "marca"))
	hbox.add_child(_crear_grupo_filtro("TIPO", FILTRO_TIPOS, "tipo"))
	hbox.add_child(_crear_grupo_filtro("PRECIO", FILTRO_PRECIOS, "precio"))
	hbox.add_child(_crear_grupo_filtro("ESTADO", FILTRO_ESTADOS, "estado"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var btn_limpiar := Button.new()
	btn_limpiar.text = "LIMPIAR"
	btn_limpiar.custom_minimum_size = Vector2(128, 42)
	btn_limpiar.focus_mode = Control.FOCUS_NONE
	btn_limpiar.size_flags_vertical = Control.SIZE_SHRINK_END
	btn_limpiar.add_theme_font_size_override("font_size", 16)
	btn_limpiar.add_theme_color_override("font_color", C_AMBER)
	btn_limpiar.add_theme_stylebox_override("normal", _estilo_filtro(Color(0.14, 0.12, 0.08, 0.90), C_AMBER, 10))
	btn_limpiar.add_theme_stylebox_override("hover", _estilo_filtro(Color(0.22, 0.18, 0.09, 0.98), Color(1.0, 0.84, 0.38, 1.0), 10))
	btn_limpiar.add_theme_stylebox_override("pressed", _estilo_filtro(Color(0.24, 0.20, 0.10, 1.0), C_AMBER, 10))
	btn_limpiar.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_limpiar.pressed.connect(_limpiar_filtros)
	hbox.add_child(btn_limpiar)


func _crear_grupo_filtro(titulo: String, opciones: Array, clave: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	var lbl := Label.new()
	lbl.text = titulo
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_TEXT_MUTED)
	vbox.add_child(lbl)

	var opcion := OptionButton.new()
	opcion.custom_minimum_size = Vector2(196, 40)
	opcion.focus_mode = Control.FOCUS_NONE
	opcion.fit_to_longest_item = false
	opcion.add_theme_font_size_override("font_size", 15)
	opcion.add_theme_color_override("font_color", C_TEXT_PRIMARY)
	opcion.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82, 1.0))
	opcion.add_theme_stylebox_override("normal", _estilo_filtro(C_SURFACE_CARD, C_BORDER_FROST, 9))
	opcion.add_theme_stylebox_override("hover", _estilo_filtro(Color(0.12, 0.13, 0.16, 0.96), C_AMBER, 9))
	opcion.add_theme_stylebox_override("pressed", _estilo_filtro(Color(0.16, 0.15, 0.11, 0.98), C_AMBER, 9))
	opcion.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for texto in opciones:
		opcion.add_item(str(texto))
	opcion.item_selected.connect(_on_filtro_seleccionado.bind(clave))
	_opciones_filtro[clave] = opcion
	vbox.add_child(opcion)
	return vbox


func _estilo_filtro(fondo: Color, borde: Color, radio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(1)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _on_filtro_seleccionado(indice: int, clave: String) -> void:
	match clave:
		"marca":
			filtro_marca = FILTRO_MARCAS[indice]
		"tipo":
			filtro_tipo = FILTRO_TIPOS[indice]
		"precio":
			filtro_precio = FILTRO_PRECIOS[indice]
		"estado":
			filtro_estado = FILTRO_ESTADOS[indice]
	_aplicar_filtros()


func _limpiar_filtros() -> void:
	filtro_marca = "TODAS"
	filtro_tipo = "TODOS"
	filtro_precio = "TODOS"
	filtro_estado = "TODOS"
	for clave in _opciones_filtro.keys():
		var opcion = _opciones_filtro[clave]
		if opcion is OptionButton:
			(opcion as OptionButton).select(0)
	_aplicar_filtros()


# --- 2. FICHA TÉCNICA (Tarjeta Flotante Derecha con Letras Grandes) ---
func _crear_ficha_tecnica() -> void:
	spec_card = PanelContainer.new()
	spec_card.name = "FichaTecnicaCard"
	spec_card.anchor_left = 1.0
	spec_card.anchor_top = 0.0
	spec_card.anchor_right = 1.0
	spec_card.anchor_bottom = 0.0
	spec_card.offset_left = -540.0
	spec_card.offset_top = 130.0
	spec_card.offset_right = -36.0
	spec_card.offset_bottom = 696.0
	spec_card.mouse_filter = Control.MOUSE_FILTER_PASS

	var sb_card = StyleBoxFlat.new()
	sb_card.bg_color = C_SURFACE_CARD
	sb_card.set_border_width_all(2)
	sb_card.border_color = C_BORDER_FROST
	sb_card.set_corner_radius_all(16)
	sb_card.shadow_color = Color(0, 0, 0, 0.55)
	sb_card.shadow_size = 14
	sb_card.shadow_offset = Vector2(0, 6)
	sb_card.content_margin_left = 28
	sb_card.content_margin_right = 28
	sb_card.content_margin_top = 26
	sb_card.content_margin_bottom = 26
	spec_card.add_theme_stylebox_override("panel", sb_card)
	root_layer.add_child(spec_card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	spec_card.add_child(vbox)

	# Categoría Tag
	lbl_spec_cat = Label.new()
	lbl_spec_cat.text = "TRACTOCAMIÓN PESADO"
	if font_moderniz:
		lbl_spec_cat.add_theme_font_override("font", font_moderniz)
	lbl_spec_cat.add_theme_font_size_override("font_size", 22)
	lbl_spec_cat.add_theme_color_override("font_color", C_AMBER)
	vbox.add_child(lbl_spec_cat)

	# Nombre del Vehículo
	lbl_spec_nombre = Label.new()
	lbl_spec_nombre.text = "Kenworth T800 Alargada"
	if font_moderniz:
		lbl_spec_nombre.add_theme_font_override("font", font_moderniz)
	lbl_spec_nombre.add_theme_font_size_override("font_size", 32)
	lbl_spec_nombre.add_theme_color_override("font_color", C_TEXT_PRIMARY)
	lbl_spec_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_spec_nombre)

	# Subtítulo ID
	lbl_spec_sub = Label.new()
	lbl_spec_sub.text = "CONFIGURACIÓN: T800_A"
	lbl_spec_sub.add_theme_font_size_override("font_size", 18)
	lbl_spec_sub.add_theme_color_override("font_color", C_TEXT_MUTED)
	vbox.add_child(lbl_spec_sub)

	# Precio y estado de propiedad
	var hbox_precio_estado = HBoxContainer.new()
	hbox_precio_estado.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox_precio_estado)

	lbl_spec_precio = Label.new()
	lbl_spec_precio.text = "PRECIO: $ 0"
	lbl_spec_precio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_moderniz:
		lbl_spec_precio.add_theme_font_override("font", font_moderniz)
	lbl_spec_precio.add_theme_font_size_override("font_size", 26)
	lbl_spec_precio.add_theme_color_override("font_color", C_AMBER)
	hbox_precio_estado.add_child(lbl_spec_precio)

	lbl_spec_estado = Label.new()
	lbl_spec_estado.text = "BLOQUEADO"
	lbl_spec_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_spec_estado.add_theme_font_size_override("font_size", 22)
	lbl_spec_estado.add_theme_color_override("font_color", C_CRIMSON)
	hbox_precio_estado.add_child(lbl_spec_estado)

	# Separador sutil
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = C_BORDER_SUBTLE
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Grilla de Telemetría
	grid_specs = GridContainer.new()
	grid_specs.columns = 2
	grid_specs.add_theme_constant_override("h_separation", 20)
	grid_specs.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid_specs)

	# Separador 2
	var sep2 = HSeparator.new()
	sep2.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep2)

	# Descripción
	lbl_spec_desc = Label.new()
	lbl_spec_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_spec_desc.add_theme_font_size_override("font_size", 19)
	lbl_spec_desc.add_theme_color_override("font_color", C_TEXT_MUTED)
	lbl_spec_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(lbl_spec_desc)

# --- 3. BOTÓN PERSONALIZAR (FontAwesome Oficial Descargado + Tamaño Grande) ---
func _crear_boton_personalizar() -> void:
	btn_personalizar = Button.new()
	btn_personalizar.name = "BtnPersonalizar"
	btn_personalizar.text = "   PERSONALIZAR"
	btn_personalizar.anchor_left = 1.0
	btn_personalizar.anchor_top = 0.0
	btn_personalizar.anchor_right = 1.0
	btn_personalizar.anchor_bottom = 0.0
	btn_personalizar.offset_left = -540.0
	btn_personalizar.offset_top = 708.0
	btn_personalizar.offset_right = -36.0
	btn_personalizar.offset_bottom = 786.0
	btn_personalizar.custom_minimum_size = Vector2(504, 78)
	btn_personalizar.focus_mode = Control.FOCUS_NONE

	if font_moderniz:
		btn_personalizar.add_theme_font_override("font", font_moderniz)
	btn_personalizar.add_theme_font_size_override("font_size", 30)
	btn_personalizar.add_theme_color_override("font_color", C_TEXT_PRIMARY)
	btn_personalizar.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85, 1.0))
	btn_personalizar.add_theme_color_override("font_pressed_color", Color(0.06, 0.07, 0.08, 1.0))

	# Icono oficial de FontAwesome descargado de la web (screwdriver-wrench)
	if icono_personalizar:
		btn_personalizar.icon = icono_personalizar
		btn_personalizar.expand_icon = true
		btn_personalizar.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Estilo Glassmorphism con Acento Ámbar Instrumental
	var sb_norm = StyleBoxFlat.new()
	sb_norm.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	sb_norm.set_border_width_all(2)
	sb_norm.border_color = C_AMBER
	sb_norm.set_corner_radius_all(14)
	sb_norm.shadow_color = C_AMBER_GLOW
	sb_norm.shadow_size = 10
	sb_norm.shadow_offset = Vector2(0, 4)
	sb_norm.content_margin_left = 28
	sb_norm.content_margin_right = 28

	var sb_hov = sb_norm.duplicate()
	sb_hov.bg_color = Color(0.20, 0.18, 0.14, 0.98)
	sb_hov.border_color = Color(1.0, 0.84, 0.38, 1.0)
	sb_hov.shadow_size = 18
	sb_hov.shadow_color = Color(0.88, 0.68, 0.28, 0.65)

	var sb_pre = sb_norm.duplicate()
	sb_pre.bg_color = C_AMBER
	sb_pre.border_color = Color.WHITE

	var sb_dis = sb_norm.duplicate()
	sb_dis.bg_color = Color(0.08, 0.09, 0.10, 0.86)
	sb_dis.border_color = Color(0.78, 0.81, 0.85, 0.15)
	sb_dis.shadow_size = 0

	btn_personalizar.add_theme_stylebox_override("normal", sb_norm)
	btn_personalizar.add_theme_stylebox_override("hover", sb_hov)
	btn_personalizar.add_theme_stylebox_override("pressed", sb_pre)
	btn_personalizar.add_theme_stylebox_override("disabled", sb_dis)
	btn_personalizar.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62, 0.80))

	btn_personalizar.pressed.connect(_on_personalizar_pressed)
	root_layer.add_child(btn_personalizar)

# --- 4. CARRUSEL INFERIOR DE VEHÍCULOS (Tarjetas con Vista Frontal sin Fondo) ---
func _crear_carrusel_vehiculos() -> void:
	bottom_dock = PanelContainer.new()
	bottom_dock.name = "BottomDock"
	bottom_dock.anchor_left = 0.0
	bottom_dock.anchor_top = 1.0
	bottom_dock.anchor_right = 1.0
	bottom_dock.anchor_bottom = 1.0
	bottom_dock.offset_left = 36.0
	bottom_dock.offset_top = -276.0
	bottom_dock.offset_right = -36.0
	bottom_dock.offset_bottom = -24.0
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_PASS

	var sb_dock = StyleBoxFlat.new()
	sb_dock.bg_color = Color(0.06, 0.07, 0.08, 0.90)
	sb_dock.set_border_width_all(2)
	sb_dock.border_color = C_BORDER_FROST
	sb_dock.set_corner_radius_all(18)
	sb_dock.shadow_color = Color(0, 0, 0, 0.60)
	sb_dock.shadow_size = 14
	sb_dock.shadow_offset = Vector2(0, 5)
	sb_dock.content_margin_left = 22
	sb_dock.content_margin_right = 22
	sb_dock.content_margin_top = 14
	sb_dock.content_margin_bottom = 14
	bottom_dock.add_theme_stylebox_override("panel", sb_dock)
	root_layer.add_child(bottom_dock)

	var vbox_carrusel = VBoxContainer.new()
	vbox_carrusel.add_theme_constant_override("separation", 10)
	bottom_dock.add_child(vbox_carrusel)

	# Encabezado del carrusel
	var hbox_tit = HBoxContainer.new()
	vbox_carrusel.add_child(hbox_tit)

	lbl_dock_tit = Label.new()
	lbl_dock_tit.text = "FLOTA DISPONIBLE EN EL GARAJE"
	if font_moderniz:
		lbl_dock_tit.add_theme_font_override("font", font_moderniz)
	lbl_dock_tit.add_theme_font_size_override("font_size", 18)
	lbl_dock_tit.add_theme_color_override("font_color", C_TEXT_MUTED)
	hbox_tit.add_child(lbl_dock_tit)

	scroll_vehiculos = ScrollContainer.new()
	scroll_vehiculos.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_vehiculos.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_vehiculos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_carrusel.add_child(scroll_vehiculos)

	hbox_cards = HBoxContainer.new()
	hbox_cards.add_theme_constant_override("separation", 20)
	hbox_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_vehiculos.add_child(hbox_cards)

	# Generar las tarjetas segun los filtros activos
	_aplicar_filtros()

func _construir_tarjeta_vehiculo(datos: Dictionary) -> Button:
	var btn_card = Button.new()
	btn_card.name = "Card_" + datos["id"]
	btn_card.custom_minimum_size = Vector2(340, 176)
	btn_card.focus_mode = Control.FOCUS_NONE
	btn_card.tooltip_text = str(datos.get("nombre_corto", ""))

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	btn_card.add_child(margin)

	# Marco interior que recibe el tono verde o rojo segun la propiedad
	var marco = PanelContainer.new()
	marco.name = "MarcoPreview"
	marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_theme_stylebox_override("panel", _estilo_marco_preview(false))
	margin.add_child(marco)

	var tex_rect = TextureRect.new()
	tex_rect.name = "TexturePreview"
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Cargar textura frontal recortada y sin fondo directamente desde el archivo más reciente
	var ruta_img = datos.get("preview_img", "")
	var tex: Texture2D = null
	var global_p = ProjectSettings.globalize_path(ruta_img)
	if FileAccess.file_exists(global_p):
		var img_data = Image.load_from_file(global_p)
		if img_data:
			tex = ImageTexture.create_from_image(img_data)
	if not tex and ResourceLoader.exists(ruta_img):
		tex = load(ruta_img) as Texture2D

	if tex:
		tex_rect.texture = tex

	marco.add_child(tex_rect)

	# Sello circular de estado: verde si es nuestro, rojo si esta bloqueado
	var sello = PanelContainer.new()
	sello.name = "SelloEstado"
	sello.custom_minimum_size = Vector2(16, 16)
	sello.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sello.offset_left = -28.0
	sello.offset_top = 8.0
	sello.offset_right = -12.0
	sello.offset_bottom = 24.0
	sello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sello.add_theme_stylebox_override("panel", _estilo_sello(false))
	btn_card.add_child(sello)

	# Conectar toque para seleccionar
	btn_card.pressed.connect(func(): _seleccionar_vehiculo(datos["id"], true))

	_aplicar_tono_tarjeta(btn_card, _es_propietario(str(datos["id"])))
	return btn_card


func _estilo_marco_preview(propietario: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.11, 0.07, 0.80) if propietario else Color(0.12, 0.04, 0.04, 0.80)
	sb.set_corner_radius_all(11)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.28, 0.86, 0.50, 0.55) if propietario else Color(0.88, 0.30, 0.28, 0.55)
	return sb


func _estilo_sello(propietario: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.94, 0.58, 1.0) if propietario else Color(0.95, 0.34, 0.30, 1.0)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.80, 1.0, 0.86, 0.95) if propietario else Color(1.0, 0.82, 0.80, 0.95)
	sb.shadow_color = Color(0.28, 0.86, 0.50, 0.45) if propietario else Color(0.88, 0.30, 0.28, 0.45)
	sb.shadow_size = 6
	return sb


func _aplicar_tono_tarjeta(card: Button, propietario: bool) -> void:
	if not is_instance_valid(card):
		return
	card.set_meta("propietario", propietario)

	var marco = card.find_child("MarcoPreview", true, false) as PanelContainer
	if marco:
		marco.add_theme_stylebox_override("panel", _estilo_marco_preview(propietario))

	var tex = card.find_child("TexturePreview", true, false) as TextureRect
	if tex:
		tex.modulate = Color(0.74, 1.0, 0.80, 1.0) if propietario else Color(1.0, 0.72, 0.72, 0.92)

	var sello = card.find_child("SelloEstado", true, false) as PanelContainer
	if sello:
		sello.add_theme_stylebox_override("panel", _estilo_sello(propietario))

	_actualizar_estilo_tarjeta(card, str(card.name) == "Card_" + id_vehiculo_actual)


func _actualizar_estilo_tarjeta(card: Button, es_activo: bool) -> void:
	var propietario := bool(card.get_meta("propietario", false))
	var verde := Color(0.30, 0.86, 0.52, 0.95)
	var rojo := C_CRIMSON

	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(14)

	if es_activo:
		sb.bg_color = Color(0.09, 0.15, 0.12, 0.98) if propietario else Color(0.16, 0.09, 0.09, 0.98)
		sb.set_border_width_all(3)
		sb.border_color = C_AMBER
		sb.shadow_color = C_AMBER_GLOW
		sb.shadow_size = 18
	else:
		sb.bg_color = Color(0.06, 0.10, 0.08, 0.96) if propietario else Color(0.11, 0.06, 0.06, 0.96)
		sb.set_border_width_all(2)
		sb.border_color = verde if propietario else rojo
		sb.shadow_color = Color(0.26, 0.80, 0.48, 0.30) if propietario else Color(0.78, 0.28, 0.26, 0.30)
		sb.shadow_size = 8

	var sb_hov = sb.duplicate()
	if not es_activo:
		sb_hov.bg_color = Color(0.09, 0.15, 0.11, 0.98) if propietario else Color(0.16, 0.08, 0.08, 0.98)
		sb_hov.border_color = Color(0.55, 1.0, 0.70, 0.95) if propietario else Color(1.0, 0.48, 0.44, 0.95)
		sb_hov.shadow_size = 14

	card.add_theme_stylebox_override("normal", sb)
	card.add_theme_stylebox_override("hover", sb_hov)
	card.add_theme_stylebox_override("pressed", sb)

# --- 5. HINT DE CÁMARA ORBITAL TÁCTIL ---
func _crear_hint_camara() -> void:
	hint_control = Label.new()
	hint_control.name = "CameraHint"
	hint_control.anchor_left = 0.0
	hint_control.anchor_top = 0.0
	hint_control.offset_left = 38.0
	hint_control.offset_top = 238.0
	hint_control.text = "DESLIZA EN PANTALLA PARA ROTAR - PELLIZCA PARA ZOOM"
	hint_control.add_theme_font_size_override("font_size", 18)
	hint_control.add_theme_color_override("font_color", C_TEXT_MUTED)
	root_layer.add_child(hint_control)

# --- SELECCIÓN Y ACTUALIZACIÓN ---
func _seleccionar_vehiculo(id_vehiculo: String, emitir_senial: bool = true) -> void:
	id_vehiculo_actual = id_vehiculo

	# Buscar datos del vehículo
	var datos_encontrados: Dictionary = {}
	for d in LISTA_VEHICULOS:
		if d["id"] == id_vehiculo:
			datos_encontrados = d
			break

	if datos_encontrados.is_empty():
		var primero := _primer_id_visible()
		if primero == "":
			id_vehiculo_actual = ""
			_mostrar_ficha_vacia()
			return
		id_vehiculo_actual = primero
		datos_encontrados = _datos_vehiculo(primero)

	# Actualizar estilos de las tarjetas
	for id_k in cards_dict.keys():
		var c = cards_dict[id_k]
		_actualizar_estilo_tarjeta(c, id_k == id_vehiculo_actual)

	# Actualizar Ficha Técnica
	_actualizar_ficha_tecnica(datos_encontrados)

	if emitir_senial and _es_propietario(id_vehiculo_actual):
		emit_signal("vehiculo_seleccionado", id_vehiculo_actual)

func _actualizar_ficha_tecnica(datos: Dictionary) -> void:
	if not spec_card:
		return

	lbl_spec_cat.text = datos.get("categoria", "")
	lbl_spec_nombre.text = datos.get("nombre", "")
	lbl_spec_sub.text = "ID: " + datos.get("nombre_corto", "") + " - " + datos.get("tipo", "")
	lbl_spec_desc.text = datos.get("descripcion", "")

	var propietario := _es_propietario(str(datos.get("id", "")))
	lbl_spec_precio.visible = not propietario
	lbl_spec_precio.text = "" if propietario else "PRECIO: " + _formatear_precio(int(datos.get("precio", 0)))
	lbl_spec_estado.text = "EN TU FLOTA" if propietario else "BLOQUEADO"
	lbl_spec_estado.add_theme_color_override("font_color", Color(0.32, 0.90, 0.58, 1.0) if propietario else C_CRIMSON)
	_actualizar_boton_accion(datos)

	# Limpiar y reconstruir grilla de especificaciones
	for c in grid_specs.get_children():
		c.queue_free()

	_agregar_fila_spec("POTENCIA:", datos.get("motor", "-"))
	_agregar_fila_spec("TRACCIÓN:", datos.get("traccion", "-"))
	_agregar_fila_spec("VEL. MÁX:", datos.get("velocidad", "-"))
	_agregar_fila_spec("PESO:", datos.get("peso", "-"))

	# Micro animación de actualización suave
	var tw = create_tween()
	spec_card.modulate.a = 0.6
	tw.tween_property(spec_card, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _actualizar_boton_accion(datos: Dictionary) -> void:
	if not btn_personalizar:
		return
	var propietario := _es_propietario(str(datos.get("id", "")))
	var precio := int(datos.get("precio", 0))
	btn_personalizar.disabled = false
	if propietario:
		btn_personalizar.text = "   PERSONALIZAR"
		btn_personalizar.icon = icono_personalizar
		btn_personalizar.add_theme_font_size_override("font_size", 30)
	else:
		btn_personalizar.text = "COMPRAR " + _formatear_precio(precio)
		btn_personalizar.icon = null
		btn_personalizar.add_theme_font_size_override("font_size", 28)


func _mostrar_ficha_vacia() -> void:
	if not spec_card:
		return
	lbl_spec_cat.text = "SIN RESULTADOS"
	lbl_spec_nombre.text = "Ajusta los filtros"
	lbl_spec_sub.text = "No hay vehiculos que coincidan."
	lbl_spec_precio.visible = true
	lbl_spec_precio.text = ""
	lbl_spec_estado.text = ""
	lbl_spec_desc.text = "Cambia la marca, el tipo, el precio o el estado para volver a ver la flota."
	for c in grid_specs.get_children():
		c.queue_free()
	btn_personalizar.disabled = true
	btn_personalizar.text = "   SIN SELECCION"
	btn_personalizar.icon = null


func _datos_vehiculo(id: String) -> Dictionary:
	for datos in LISTA_VEHICULOS:
		if str(datos.get("id", "")) == id:
			return datos
	return {}


func _primer_id_visible() -> String:
	for id in cards_dict.keys():
		return str(id)
	return ""


# --- FILTROS Y PROPIEDAD ---
func _aplicar_filtros() -> void:
	if not hbox_cards:
		return
	for hijo in hbox_cards.get_children():
		hbox_cards.remove_child(hijo)
		hijo.queue_free()
	cards_dict.clear()

	var visibles: Array = []
	for datos in LISTA_VEHICULOS:
		if _vehiculo_pasa_filtros(datos):
			visibles.append(datos)

	for datos in visibles:
		var card = _construir_tarjeta_vehiculo(datos)
		hbox_cards.add_child(card)
		cards_dict[datos["id"]] = card

	if lbl_dock_tit:
		if visibles.is_empty():
			lbl_dock_tit.text = "FLOTA DISPONIBLE (0) - AJUSTA LOS FILTROS"
		else:
			lbl_dock_tit.text = "FLOTA DISPONIBLE (%d) - TOCA UNA TARJETA PARA VER" % visibles.size()

	if visibles.is_empty():
		id_vehiculo_actual = ""
		_mostrar_ficha_vacia()
		return

	var seleccion_valida := false
	for datos in visibles:
		if str(datos.get("id", "")) == id_vehiculo_actual:
			seleccion_valida = true
			break
	if not seleccion_valida:
		id_vehiculo_actual = str(visibles[0].get("id", ""))
		_seleccionar_vehiculo(id_vehiculo_actual, true)
	else:
		_seleccionar_vehiculo(id_vehiculo_actual, false)


func _vehiculo_pasa_filtros(datos: Dictionary) -> bool:
	if filtro_marca != "TODAS" and str(datos.get("marca", "")).to_upper() != filtro_marca:
		return false
	if filtro_tipo != "TODOS" and str(datos.get("tipo_vehiculo", "")).to_upper() != filtro_tipo:
		return false

	var precio := int(datos.get("precio", 0))
	if filtro_precio == FILTRO_PRECIOS[1] and precio > 60000:
		return false
	if filtro_precio == FILTRO_PRECIOS[2] and (precio <= 60000 or precio > 120000):
		return false
	if filtro_precio == FILTRO_PRECIOS[3] and precio <= 120000:
		return false

	var propietario := _es_propietario(str(datos.get("id", "")))
	if filtro_estado == "COMPRADOS" and not propietario:
		return false
	if filtro_estado == "BLOQUEADOS" and propietario:
		return false
	return true


func _es_propietario(id: String) -> bool:
	if id == VEHICULO_INICIAL:
		return true
	if not DatosUsuario:
		return true
	var comprados = DatosUsuario.vehiculos_comprados
	if comprados is Dictionary and (comprados as Dictionary).has(id):
		return bool((comprados as Dictionary)[id])
	return false


func _formatear_precio(valor: int) -> String:
	var negativo := valor < 0
	var digitos := str(absi(valor))
	var salida := ""
	for i in range(digitos.length()):
		if i > 0 and (digitos.length() - i) % 3 == 0:
			salida += "."
		salida += digitos[i]
	return ("-" if negativo else "") + "$ " + salida


func _comprar_vehiculo_actual() -> void:
	var datos := _datos_vehiculo(id_vehiculo_actual)
	if datos.is_empty() or _es_propietario(id_vehiculo_actual):
		return

	var precio := int(datos.get("precio", 0))
	var saldo := 0.0
	if DatosUsuario:
		saldo = float(DatosUsuario.dinero)
	if saldo < float(precio):
		_mostrar_dialogo(
			"SALDO INSUFICIENTE",
			"Necesitas %s para comprar este vehiculo.\nTu saldo actual es %s." % [
				_formatear_precio(precio), _formatear_precio(int(saldo))
			]
		)
		return

	if DatosUsuario:
		DatosUsuario.dinero = maxf(0.0, saldo - float(precio))
		if not (DatosUsuario.vehiculos_comprados is Dictionary):
			DatosUsuario.vehiculos_comprados = {}
		DatosUsuario.vehiculos_comprados[id_vehiculo_actual] = true
		DatosUsuario.save_local(true)

	emit_signal("vehiculo_seleccionado", id_vehiculo_actual)

	if barra_divisas:
		barra_divisas.refrescar(true)

	if filtro_estado != "TODOS":
		_aplicar_filtros()
	else:
		_actualizar_propiedad_tarjetas()
		_actualizar_ficha_tecnica(datos)

	_celebrar_compra(datos)


func _celebrar_compra(datos: Dictionary) -> void:
	var capa := Control.new()
	capa.name = "CelebracionCompra"
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	capa.z_index = 100
	capa.modulate.a = 1.0
	add_child(capa)
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fondo := ColorRect.new()
	fondo.color = Color(0.01, 0.01, 0.02, 0.0)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.86, 0.45, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 2
	capa.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.z_index = 1
	capa.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 440)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.pivot_offset = Vector2(390, 220)
	panel.scale = Vector2(0.72, 0.72)
	panel.modulate.a = 0.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.09, 0.98)
	sb.set_border_width_all(3)
	sb.border_color = C_AMBER
	sb.set_corner_radius_all(22)
	sb.shadow_color = C_AMBER_GLOW
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 0)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 34
	sb.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var lbl_eyebrow := Label.new()
	lbl_eyebrow.text = "ADQUISICION DE CALIDAD"
	lbl_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_moderniz:
		lbl_eyebrow.add_theme_font_override("font", font_moderniz)
	lbl_eyebrow.add_theme_font_size_override("font_size", 22)
	lbl_eyebrow.add_theme_color_override("font_color", C_AMBER)
	vbox.add_child(lbl_eyebrow)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "VEHICULO ADQUIRIDO"
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_moderniz:
		lbl_titulo.add_theme_font_override("font", font_moderniz)
	lbl_titulo.add_theme_font_size_override("font_size", 46)
	lbl_titulo.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
	vbox.add_child(lbl_titulo)

	var linea := ColorRect.new()
	linea.color = C_AMBER
	linea.custom_minimum_size = Vector2(0, 2)
	linea.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(linea)

	var lbl_nombre := Label.new()
	lbl_nombre.text = str(datos.get("nombre", ""))
	lbl_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_moderniz:
		lbl_nombre.add_theme_font_override("font", font_moderniz)
	lbl_nombre.add_theme_font_size_override("font_size", 54)
	lbl_nombre.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	vbox.add_child(lbl_nombre)

	var lbl_sub := Label.new()
	lbl_sub.text = "NUEVO EN TU FLOTA  -  CALIDAD PREMIUM"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 21)
	lbl_sub.add_theme_color_override("font_color", Color(0.42, 0.92, 0.62, 0.98))
	vbox.add_child(lbl_sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn_seguir := Button.new()
	btn_seguir.text = "CONTINUAR"
	btn_seguir.custom_minimum_size = Vector2(300, 68)
	btn_seguir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_seguir.focus_mode = Control.FOCUS_NONE
	if font_moderniz:
		btn_seguir.add_theme_font_override("font", font_moderniz)
	btn_seguir.add_theme_font_size_override("font_size", 26)
	btn_seguir.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 1.0))
	btn_seguir.add_theme_color_override("font_hover_color", Color(0.06, 0.07, 0.08, 1.0))
	var sb_btn := StyleBoxFlat.new()
	sb_btn.bg_color = C_AMBER
	sb_btn.set_corner_radius_all(12)
	sb_btn.set_border_width_all(1)
	sb_btn.border_color = Color(1.0, 0.86, 0.44, 1.0)
	sb_btn.shadow_color = C_AMBER_GLOW
	sb_btn.shadow_size = 12
	var sb_btn_hov := sb_btn.duplicate()
	sb_btn_hov.bg_color = Color(0.98, 0.80, 0.38, 1.0)
	sb_btn_hov.shadow_size = 20
	btn_seguir.add_theme_stylebox_override("normal", sb_btn)
	btn_seguir.add_theme_stylebox_override("hover", sb_btn_hov)
	btn_seguir.add_theme_stylebox_override("pressed", sb_btn)
	btn_seguir.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_seguir.pressed.connect(func(): _cerrar_celebracion(capa))
	vbox.add_child(btn_seguir)

	centro.add_child(panel)

	# Destellos dorados alrededor del panel
	var view_size := get_viewport_rect().size
	var origen := view_size * 0.5 + Vector2(0, 160)
	for i in range(26):
		var chispa := ColorRect.new()
		var ancho := randf_range(3.0, 6.0)
		var alto := randf_range(10.0, 24.0)
		chispa.color = Color(randf_range(0.95, 1.0), randf_range(0.70, 0.90), randf_range(0.22, 0.42), 1.0)
		chispa.size = Vector2(ancho, alto)
		chispa.pivot_offset = chispa.size * 0.5
		chispa.position = origen + Vector2(randf_range(-70.0, 70.0), randf_range(-20.0, 20.0))
		chispa.rotation = randf_range(-0.6, 0.6)
		chispa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.add_child(chispa)
		var destino := chispa.position + Vector2(randf_range(-460.0, 460.0), randf_range(-360.0, -40.0))
		var giro := randf_range(-3.0, 3.0)
		var t_chispa := chispa.create_tween().set_parallel(true)
		t_chispa.tween_property(chispa, "position", destino, randf_range(0.7, 1.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_chispa.tween_property(chispa, "rotation", chispa.rotation + giro, randf_range(0.7, 1.3))
		t_chispa.tween_property(chispa, "modulate:a", 0.0, randf_range(0.8, 1.4)).set_delay(randf_range(0.1, 0.4))

	var t_entrada := capa.create_tween()
	t_entrada.tween_property(fondo, "color:a", 0.82, 0.28)
	t_entrada.parallel().tween_property(flash, "color:a", 0.55, 0.10)
	t_entrada.parallel().tween_property(panel, "modulate:a", 1.0, 0.30)
	t_entrada.parallel().tween_property(panel, "scale", Vector2.ONE, 0.60).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_entrada.tween_property(flash, "color:a", 0.0, 0.50)

	var pulso := panel.create_tween().set_loops()
	pulso.tween_property(sb, "shadow_size", 48, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulso.tween_property(sb, "shadow_size", 24, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var t_auto := capa.create_tween()
	t_auto.tween_interval(6.0)
	t_auto.tween_callback(func(): _cerrar_celebracion(capa))


func _cerrar_celebracion(capa: Control) -> void:
	if not is_instance_valid(capa) or bool(capa.get_meta("cerrando", false)):
		return
	capa.set_meta("cerrando", true)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := capa.create_tween()
	tw.tween_property(capa, "modulate:a", 0.0, 0.32)
	tw.tween_callback(capa.queue_free)


func _actualizar_propiedad_tarjetas() -> void:
	for id in cards_dict.keys():
		var card = cards_dict[id]
		if not is_instance_valid(card):
			continue
		_aplicar_tono_tarjeta(card, _es_propietario(str(id)))


func _mostrar_dialogo(titulo: String, mensaje: String) -> void:
	if _dialogo_garaje == null:
		_dialogo_garaje = AcceptDialog.new()
		_dialogo_garaje.title = "GARAJE"
		_dialogo_garaje.dialog_autowrap = true
		add_child(_dialogo_garaje)
	_dialogo_garaje.dialog_text = mensaje
	_dialogo_garaje.popup_centered(Vector2i(640, 220))

func _agregar_fila_spec(titulo: String, valor: String) -> void:
	var lbl_t = Label.new()
	lbl_t.text = titulo
	if font_moderniz:
		lbl_t.add_theme_font_override("font", font_moderniz)
	lbl_t.add_theme_font_size_override("font_size", 18)
	lbl_t.add_theme_color_override("font_color", C_AMBER)
	grid_specs.add_child(lbl_t)

	var lbl_v = Label.new()
	lbl_v.text = valor
	lbl_v.add_theme_font_size_override("font_size", 20)
	lbl_v.add_theme_color_override("font_color", C_TEXT_PRIMARY)
	grid_specs.add_child(lbl_v)

# --- ANIMACIONES Y EVENTOS ---
func _animar_entrada() -> void:
	root_layer.modulate.a = 0.0
	root_layer.scale = Vector2(0.96, 0.96)
	root_layer.pivot_offset = size / 2.0

	var tw = create_tween().set_parallel(true)
	tw.tween_property(root_layer, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(root_layer, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animar_salida(on_complete: Callable) -> void:
	var tw = create_tween().set_parallel(true)
	tw.tween_property(root_layer, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(root_layer, "scale", Vector2(0.96, 0.96), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(on_complete)

func _on_personalizar_pressed() -> void:
	if _es_propietario(id_vehiculo_actual):
		emit_signal("personalizar_solicitado")
	else:
		_comprar_vehiculo_actual()

func _on_volver_pressed() -> void:
	emit_signal("volver_solicitado")
