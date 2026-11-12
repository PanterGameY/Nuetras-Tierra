extends Control
class_name ConfiguradorPuntosCarga

## ConfiguradorPuntosCarga.gd
##
## Panel de Administración Logística y Configuración de Puntos de Carga / Descarga.
## Diseño moderno, sobrio y neutro con paleta slate/charcoal de alta legibilidad,
## layout completamente responsivo que se adapta a cualquier resolución de pantalla.

signal configuracion_guardada()
signal configuracion_cerrada()

# ── Paleta de Colores Neutros y Profesionales ──
const COLOR_BG_BACKDROP: Color = Color(0.05, 0.06, 0.07, 0.85)
const COLOR_SURFACE_MAIN: Color = Color(0.10, 0.11, 0.13, 0.98)
const COLOR_SURFACE_ELEVATED: Color = Color(0.14, 0.15, 0.18, 1.0)
const COLOR_SURFACE_HOVER: Color = Color(0.18, 0.20, 0.24, 1.0)
const COLOR_SURFACE_INPUT: Color = Color(0.08, 0.09, 0.11, 1.0)
const COLOR_BORDER_DEFAULT: Color = Color(0.22, 0.24, 0.28, 1.0)
const COLOR_BORDER_FOCUS: Color = Color(0.38, 0.50, 0.68, 1.0)
const COLOR_ACCENT_PRIMARY: Color = Color(0.24, 0.44, 0.72, 1.0)
const COLOR_ACCENT_HOVER: Color = Color(0.30, 0.52, 0.84, 1.0)
const COLOR_ACCENT_MUTED: Color = Color(0.18, 0.22, 0.28, 1.0)

const COLOR_TEXT_PRIMARY: Color = Color(0.92, 0.93, 0.95, 1.0)
const COLOR_TEXT_SECONDARY: Color = Color(0.62, 0.65, 0.70, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.44, 0.47, 0.52, 1.0)

# Estados de tipo de punto (tonos sobrios, desaturados)
const COLOR_TIPO_CARGA_BG: Color = Color(0.12, 0.18, 0.15, 1.0)
const COLOR_TIPO_CARGA_BORDER: Color = Color(0.24, 0.38, 0.28, 1.0)
const COLOR_TIPO_CARGA_TEXT: Color = Color(0.60, 0.85, 0.70, 1.0)

const COLOR_TIPO_DESCARGA_BG: Color = Color(0.18, 0.13, 0.13, 1.0)
const COLOR_TIPO_DESCARGA_BORDER: Color = Color(0.38, 0.24, 0.24, 1.0)
const COLOR_TIPO_DESCARGA_TEXT: Color = Color(0.88, 0.62, 0.62, 1.0)

const COLOR_TIPO_AMBOS_BG: Color = Color(0.13, 0.16, 0.22, 1.0)
const COLOR_TIPO_AMBOS_BORDER: Color = Color(0.26, 0.34, 0.46, 1.0)
const COLOR_TIPO_AMBOS_TEXT: Color = Color(0.65, 0.78, 0.92, 1.0)

# ── Datos en Memoria ──
var _datos: Dictionary = {}
var _puntos: Array = []
var _catalogo: Array = []
var _indice_actual: int = -1
var _punto_actual: Dictionary = {}
var _filtro_texto: String = ""
var _filtro_tipo: int = -1

# ── Elementos UI ──
var _contenedor_raiz: Control
var _ventana_panel: PanelContainer
var _lista_vbox: VBoxContainer
var _input_buscar: LineEdit
var _lbl_conteo_total: Label
var _toast_panel: PanelContainer
var _toast_lbl: Label

# Header de Edición
var _lbl_punto_titulo: Label
var _lbl_punto_sub: Label
var _badge_tipo: Label

# Pestañas
var _tab_container: TabContainer

# Inputs del Formulario
var _input_id: LineEdit
var _input_nombre: LineEdit
var _opt_tipo: OptionButton
var _spin_tarifa: SpinBox
var _spin_tiempo: SpinBox
var _chk_area: CheckBox
var _opt_forma: OptionButton
var _spin_radio: SpinBox
var _spin_ancho: SpinBox
var _spin_largo: SpinBox
var _spin_altura: SpinBox
var _spin_pos_x: SpinBox
var _spin_pos_y: SpinBox
var _spin_pos_z: SpinBox
var _spin_rot_y: SpinBox
var _spin_grosor: SpinBox
var _spin_esquinas: SpinBox
var _spin_vel_trail: SpinBox
var _spin_vel_pulso: SpinBox
var _chk_color_pers: CheckBox
var _btn_color_pers: ColorPickerButton
var _spin_opacidad: SpinBox
var _chk_etiqueta_3d: CheckBox

# Cargas
var _grid_cargas: GridContainer
var _input_nueva_carga_id: LineEdit
var _input_nueva_carga_nom: LineEdit
var _spin_nueva_carga_tarifa: SpinBox

# Contenedores dinámicos
var _caja_radio: HBoxContainer
var _caja_dimensiones_rect: HBoxContainer

# Preview 3D
var _viewport_preview: SubViewport
var _nodo_preview_punto: PuntoCargaDescarga
var _pivot_camara: Node3D

func _ready() -> void:
	_construir_interfaz()
	_cargar_datos()
	_animar_aparicion()

	if _puntos.size() > 0:
		seleccionar_punto(0)

func _cargar_datos() -> void:
	_datos = GestorPuntosCarga.cargar_datos()
	_catalogo = _datos.get("catalogo_cargas", [])
	_puntos = _datos.get("puntos", [])
	_refrescar_lista()
	_refrescar_grilla_cargas()

# ═══════════════════════════════════════════════════════════════════════
# MAQUETACIÓN RESPONSIVA Y MODERNA
# ═══════════════════════════════════════════════════════════════════════
func _construir_interfaz() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BOTH

	# 1. Fondo Oscurecedor
	var bg = ColorRect.new()
	bg.color = COLOR_BG_BACKDROP
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# 2. Margen de Pantalla (Evita que nada toque los bordes físicos o se desborde)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	# 3. Ventana Principal Elevada
	_ventana_panel = PanelContainer.new()
	_ventana_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_ventana_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_ventana_panel.add_theme_stylebox_override("panel", _crear_stylebox(COLOR_SURFACE_MAIN, COLOR_BORDER_DEFAULT, 10, 1, 20))
	margin.add_child(_ventana_panel)

	var layout_v = VBoxContainer.new()
	layout_v.add_theme_constant_override("separation", 16)
	layout_v.size_flags_horizontal = SIZE_EXPAND_FILL
	layout_v.size_flags_vertical = SIZE_EXPAND_FILL
	_ventana_panel.add_child(layout_v)

	# ── Top Bar / Cabecera ──
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 48)
	layout_v.add_child(top_bar)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = SIZE_EXPAND_FILL
	top_bar.add_child(title_box)

	var lbl_breadcrumb = Label.new()
	lbl_breadcrumb.text = "SISTEMA LOGÍSTICO  /  PUNTOS DE CARGA Y DESCARGA"
	lbl_breadcrumb.add_theme_font_size_override("font_size", 14)
	lbl_breadcrumb.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	title_box.add_child(lbl_breadcrumb)

	var lbl_main_title = Label.new()
	lbl_main_title.text = "Configuración de Operaciones y Mercancías"
	lbl_main_title.add_theme_font_size_override("font_size", 22)
	lbl_main_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_box.add_child(lbl_main_title)

	var top_actions = HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_actions)

	var btn_guardar = Button.new()
	btn_guardar.text = "Guardar Cambios"
	btn_guardar.custom_minimum_size = Vector2(160, 42)
	_estilar_boton_primario(btn_guardar)
	btn_guardar.pressed.connect(_on_guardar_click)
	top_actions.add_child(btn_guardar)

	var btn_sincronizar = Button.new()
	btn_sincronizar.text = "Sincronizar Mapa"
	btn_sincronizar.custom_minimum_size = Vector2(160, 42)
	_estilar_boton_secundario(btn_sincronizar)
	btn_sincronizar.pressed.connect(_on_sincronizar_click)
	top_actions.add_child(btn_sincronizar)

	var btn_cerrar = Button.new()
	btn_cerrar.text = "Cerrar"
	btn_cerrar.custom_minimum_size = Vector2(110, 42)
	_estilar_boton_secundario(btn_cerrar)
	btn_cerrar.pressed.connect(_on_cerrar_click)
	top_actions.add_child(btn_cerrar)

	# Separador sutil
	layout_v.add_child(_crear_separador_horizontal())

	# ── Cuerpo Central: Dos Columnas (Lista | Detalle) ──
	var split_cuerpo = HBoxContainer.new()
	split_cuerpo.size_flags_vertical = SIZE_EXPAND_FILL
	split_cuerpo.add_theme_constant_override("separation", 20)
	layout_v.add_child(split_cuerpo)

	# ── COLUMNA IZQUIERDA: LISTA Y HERRAMIENTAS ──
	var col_izq = VBoxContainer.new()
	col_izq.custom_minimum_size = Vector2(380, 0)
	col_izq.add_theme_constant_override("separation", 12)
	split_cuerpo.add_child(col_izq)

	# Buscador
	_input_buscar = LineEdit.new()
	_input_buscar.placeholder_text = "Filtrar por nombre o ID..."
	_input_buscar.custom_minimum_size = Vector2(0, 40)
	_estilar_input(_input_buscar)
	_input_buscar.text_changed.connect(_on_buscar_texto_changed)
	col_izq.add_child(_input_buscar)

	# Filtro Segmentado
	var seg_box = HBoxContainer.new()
	seg_box.add_theme_constant_override("separation", 4)
	col_izq.add_child(seg_box)

	var btn_f_todos = _crear_boton_filtro("Todos", -1)
	var btn_f_carga = _crear_boton_filtro("Carga", 0)
	var btn_f_descarga = _crear_boton_filtro("Descarga", 1)
	var btn_f_ambos = _crear_boton_filtro("Ambos", 2)
	seg_box.add_child(btn_f_todos)
	seg_box.add_child(btn_f_carga)
	seg_box.add_child(btn_f_descarga)
	seg_box.add_child(btn_f_ambos)

	# Scroll de Lista de Puntos
	var scroll_lista = ScrollContainer.new()
	scroll_lista.size_flags_vertical = SIZE_EXPAND_FILL
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_izq.add_child(scroll_lista)

	_lista_vbox = VBoxContainer.new()
	_lista_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	_lista_vbox.add_theme_constant_override("separation", 6)
	scroll_lista.add_child(_lista_vbox)

	# Barra de Control de Lista
	var barra_lista = HBoxContainer.new()
	barra_lista.add_theme_constant_override("separation", 8)
	col_izq.add_child(barra_lista)

	var btn_nuevo = Button.new()
	btn_nuevo.text = "+ Nuevo Punto"
	btn_nuevo.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_nuevo.custom_minimum_size = Vector2(0, 38)
	_estilar_boton_secundario(btn_nuevo)
	btn_nuevo.pressed.connect(_on_nuevo_click)
	barra_lista.add_child(btn_nuevo)

	var btn_duplicar = Button.new()
	btn_duplicar.text = "Duplicar"
	btn_duplicar.custom_minimum_size = Vector2(85, 38)
	_estilar_boton_secundario(btn_duplicar)
	btn_duplicar.pressed.connect(_on_duplicar_click)
	barra_lista.add_child(btn_duplicar)

	var btn_subir = Button.new()
	btn_subir.text = "▲"
	btn_subir.custom_minimum_size = Vector2(40, 38)
	_estilar_boton_secundario(btn_subir)
	btn_subir.pressed.connect(_on_subir_click)
	barra_lista.add_child(btn_subir)

	var btn_bajar = Button.new()
	btn_bajar.text = "▼"
	btn_bajar.custom_minimum_size = Vector2(40, 38)
	_estilar_boton_secundario(btn_bajar)
	btn_bajar.pressed.connect(_on_bajar_click)
	barra_lista.add_child(btn_bajar)

	var btn_eliminar = Button.new()
	btn_eliminar.text = "Eliminar"
	btn_eliminar.custom_minimum_size = Vector2(80, 38)
	_estilar_boton_peligro(btn_eliminar)
	btn_eliminar.pressed.connect(_on_eliminar_click)
	barra_lista.add_child(btn_eliminar)

	# ── Separador Vertical Sutil ──
	var v_div = VSeparator.new()
	var v_div_st = StyleBoxLine.new()
	v_div_st.color = COLOR_BORDER_DEFAULT
	v_div_st.thickness = 1
	v_div_st.vertical = true
	v_div.add_theme_stylebox_override("separator", v_div_st)
	split_cuerpo.add_child(v_div)

	# ── COLUMNA DERECHA: DETALLE Y CONFIGURACIÓN ──
	var col_der = VBoxContainer.new()
	col_der.size_flags_horizontal = SIZE_EXPAND_FILL
	col_der.size_flags_vertical = SIZE_EXPAND_FILL
	col_der.add_theme_constant_override("separation", 14)
	split_cuerpo.add_child(col_der)

	# Header de selección
	var sel_header = HBoxContainer.new()
	sel_header.add_theme_constant_override("separation", 12)
	col_der.add_child(sel_header)

	var sel_vbox = VBoxContainer.new()
	sel_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	sel_header.add_child(sel_vbox)

	_lbl_punto_titulo = Label.new()
	_lbl_punto_titulo.text = "Seleccione un punto de la lista"
	_lbl_punto_titulo.add_theme_font_size_override("font_size", 20)
	_lbl_punto_titulo.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	sel_vbox.add_child(_lbl_punto_titulo)

	_lbl_punto_sub = Label.new()
	_lbl_punto_sub.text = "Edite los parámetros en las pestañas inferiores"
	_lbl_punto_sub.add_theme_font_size_override("font_size", 14)
	_lbl_punto_sub.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	sel_vbox.add_child(_lbl_punto_sub)

	_badge_tipo = Label.new()
	_badge_tipo.text = "CARGA"
	_badge_tipo.add_theme_font_size_override("font_size", 13)
	sel_header.add_child(_badge_tipo)

	# Pestañas Organizadas
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	_tab_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_estilar_tab_container(_tab_container)
	col_der.add_child(_tab_container)

	# Pestaña 1: Operación y Datos Básicos
	_tab_container.add_child(_crear_pestana_operacion())

	# Pestaña 2: Mercancías Aceptadas
	_tab_container.add_child(_crear_pestana_mercancias())

	# Pestaña 3: Geometría y Ubicación 3D
	_tab_container.add_child(_crear_pestana_geometria())

	# Pestaña 4: Visuales y Previsualización 3D
	_tab_container.add_child(_crear_pestana_visuales())

	# Toast Notificaciones
	_crear_toast()

# ═══════════════════════════════════════════════════════════════════════
# PESTAÑAS DETALLADAS DEL FORMULARIO
# ═══════════════════════════════════════════════════════════════════════
func _crear_pestana_operacion() -> Control:
	var scroll = ScrollContainer.new()
	scroll.name = "Operación y Datos"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	# ID
	grid.add_child(_crear_label_campo("Identificador Interno (ID):", "Código único de referencia en el código o misiones."))
	_input_id = LineEdit.new()
	_estilar_input(_input_id)
	_input_id.text_changed.connect(_on_campo_actualizado)
	grid.add_child(_input_id)

	# Nombre
	grid.add_child(_crear_label_campo("Nombre Descriptivo:", "Nombre legible visible en el GPS y la interfaz."))
	_input_nombre = LineEdit.new()
	_estilar_input(_input_nombre)
	_input_nombre.text_changed.connect(_on_campo_actualizado)
	grid.add_child(_input_nombre)

	# Modo
	grid.add_child(_crear_label_campo("Modalidad de Operación:", "Determina si el punto es de carga, descarga o multiuso."))
	_opt_tipo = OptionButton.new()
	_opt_tipo.add_item("Solo Carga", 0)
	_opt_tipo.add_item("Solo Descarga", 1)
	_opt_tipo.add_item("Carga y Descarga (Ambos)", 2)
	_opt_tipo.custom_minimum_size = Vector2(0, 40)
	_opt_tipo.item_selected.connect(func(_i): _on_campo_actualizado(""))
	grid.add_child(_opt_tipo)

	# Tarifa
	grid.add_child(_crear_label_campo("Tarifa Base de Transporte ($):", "Remuneración base calculada para viajes desde/hacia este punto."))
	_spin_tarifa = SpinBox.new()
	_spin_tarifa.min_value = 0
	_spin_tarifa.max_value = 100000
	_spin_tarifa.step = 50
	_spin_tarifa.custom_minimum_size = Vector2(0, 40)
	_spin_tarifa.value_changed.connect(func(_v): _on_campo_actualizado(""))
	grid.add_child(_spin_tarifa)

	# Tiempo
	grid.add_child(_crear_label_campo("Tiempo de Proceso (segundos):", "Duración requerida en la zona para completar la maniobra."))
	_spin_tiempo = SpinBox.new()
	_spin_tiempo.min_value = 1.0
	_spin_tiempo.max_value = 120.0
	_spin_tiempo.step = 0.5
	_spin_tiempo.custom_minimum_size = Vector2(0, 40)
	_spin_tiempo.value_changed.connect(func(_v): _on_campo_actualizado(""))
	grid.add_child(_spin_tiempo)

	# Área física
	grid.add_child(_crear_label_campo("Zona de Detección Física:", "Crea un nodo Area3D con colisión para registrar vehículos."))
	_chk_area = CheckBox.new()
	_chk_area.text = "Activar colisión y eventos automáticos de entrada/salida"
	_chk_area.toggled.connect(func(_b): _on_campo_actualizado(""))
	grid.add_child(_chk_area)

	return scroll

func _crear_pestana_mercancias() -> Control:
	var scroll = ScrollContainer.new()
	scroll.name = "Mercancías Aceptadas"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Barra de herramientas superior
	var top_cargas = HBoxContainer.new()
	top_cargas.add_theme_constant_override("separation", 10)
	vbox.add_child(top_cargas)

	var lbl_desc = Label.new()
	lbl_desc.text = "Seleccione los tipos de carga autorizados en este punto logístico:"
	lbl_desc.add_theme_font_size_override("font_size", 14)
	lbl_desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	lbl_desc.size_flags_horizontal = SIZE_EXPAND_FILL
	top_cargas.add_child(lbl_desc)

	var btn_sel_todas = Button.new()
	btn_sel_todas.text = "Seleccionar Todas"
	btn_sel_todas.custom_minimum_size = Vector2(140, 36)
	_estilar_boton_secundario(btn_sel_todas, 13)
	btn_sel_todas.pressed.connect(_on_seleccionar_todas_cargas)
	top_cargas.add_child(btn_sel_todas)

	var btn_des_todas = Button.new()
	btn_des_todas.text = "Deseleccionar Todas"
	btn_des_todas.custom_minimum_size = Vector2(150, 36)
	_estilar_boton_secundario(btn_des_todas, 13)
	btn_des_todas.pressed.connect(_on_deseleccionar_todas_cargas)
	top_cargas.add_child(btn_des_todas)

	# Grilla de Cargas (2 columnas limpias)
	_grid_cargas = GridContainer.new()
	_grid_cargas.columns = 2
	_grid_cargas.add_theme_constant_override("h_separation", 12)
	_grid_cargas.add_theme_constant_override("v_separation", 8)
	_grid_cargas.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_child(_grid_cargas)

	# Separador
	vbox.add_child(_crear_separador_horizontal())

	# Panel para añadir nueva categoría de carga al catálogo
	var pnl_add = PanelContainer.new()
	pnl_add.add_theme_stylebox_override("panel", _crear_stylebox(COLOR_SURFACE_ELEVATED, COLOR_BORDER_DEFAULT, 8, 1, 14))
	vbox.add_child(pnl_add)

	var v_add = VBoxContainer.new()
	v_add.add_theme_constant_override("separation", 10)
	pnl_add.add_child(v_add)

	var lbl_add_title = Label.new()
	lbl_add_title.text = "Registrar Nueva Categoría en el Catálogo General"
	lbl_add_title.add_theme_font_size_override("font_size", 14)
	lbl_add_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	v_add.add_child(lbl_add_title)

	var h_add = HBoxContainer.new()
	h_add.add_theme_constant_override("separation", 10)
	v_add.add_child(h_add)

	_input_nueva_carga_id = LineEdit.new()
	_input_nueva_carga_id.placeholder_text = "ID (ej: cemento)"
	_input_nueva_carga_id.custom_minimum_size = Vector2(150, 38)
	_estilar_input(_input_nueva_carga_id)
	h_add.add_child(_input_nueva_carga_id)

	_input_nueva_carga_nom = LineEdit.new()
	_input_nueva_carga_nom.placeholder_text = "Nombre Descriptivo (ej: Cemento a Granel)"
	_input_nueva_carga_nom.size_flags_horizontal = SIZE_EXPAND_FILL
	_input_nueva_carga_nom.custom_minimum_size = Vector2(0, 38)
	_estilar_input(_input_nueva_carga_nom)
	h_add.add_child(_input_nueva_carga_nom)

	_spin_nueva_carga_tarifa = SpinBox.new()
	_spin_nueva_carga_tarifa.min_value = 500
	_spin_nueva_carga_tarifa.max_value = 50000
	_spin_nueva_carga_tarifa.value = 1600
	_spin_nueva_carga_tarifa.step = 100
	_spin_nueva_carga_tarifa.custom_minimum_size = Vector2(120, 38)
	h_add.add_child(_spin_nueva_carga_tarifa)

	var btn_add_carga = Button.new()
	btn_add_carga.text = "+ Añadir Categoría"
	btn_add_carga.custom_minimum_size = Vector2(160, 38)
	_estilar_boton_secundario(btn_add_carga)
	btn_add_carga.pressed.connect(_on_crear_categoria_carga)
	h_add.add_child(btn_add_carga)

	return scroll

func _crear_pestana_geometria() -> Control:
	var scroll = ScrollContainer.new()
	scroll.name = "Geometría 3D"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	# Forma
	grid.add_child(_crear_label_campo("Forma de la Zona:", "Geometría del marco en el suelo y del volumen de colisión."))
	_opt_forma = OptionButton.new()
	_opt_forma.add_item("Cilíndrica / Circular", 0)
	_opt_forma.add_item("Rectangular / Caja", 1)
	_opt_forma.custom_minimum_size = Vector2(0, 40)
	_opt_forma.item_selected.connect(_on_forma_cambiada)
	grid.add_child(_opt_forma)

	# Radio
	_caja_radio = HBoxContainer.new()
	_caja_radio.add_theme_constant_override("separation", 10)
	grid.add_child(_crear_label_campo("Radio (metros):", "Distancia desde el centro hasta el borde circular."))
	_spin_radio = SpinBox.new()
	_spin_radio.min_value = 0.5
	_spin_radio.max_value = 60.0
	_spin_radio.step = 0.5
	_spin_radio.custom_minimum_size = Vector2(0, 40)
	_spin_radio.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_radio.value_changed.connect(func(_v): _on_campo_actualizado(""))
	_caja_radio.add_child(_spin_radio)
	grid.add_child(_caja_radio)

	# Dimensiones Caja
	_caja_dimensiones_rect = HBoxContainer.new()
	_caja_dimensiones_rect.add_theme_constant_override("separation", 12)
	grid.add_child(_crear_label_campo("Dimensiones (Ancho x Largo):", "Extensión transversal (X) y longitudinal (Z) en metros."))

	var l_w = Label.new()
	l_w.text = "X:"
	l_w.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_caja_dimensiones_rect.add_child(l_w)

	_spin_ancho = SpinBox.new()
	_spin_ancho.min_value = 0.5
	_spin_ancho.max_value = 60.0
	_spin_ancho.step = 0.5
	_spin_ancho.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_ancho.custom_minimum_size = Vector2(0, 40)
	_spin_ancho.value_changed.connect(func(_v): _on_campo_actualizado(""))
	_caja_dimensiones_rect.add_child(_spin_ancho)

	var l_l = Label.new()
	l_l.text = "Z:"
	l_l.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_caja_dimensiones_rect.add_child(l_l)

	_spin_largo = SpinBox.new()
	_spin_largo.min_value = 0.5
	_spin_largo.max_value = 60.0
	_spin_largo.step = 0.5
	_spin_largo.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_largo.custom_minimum_size = Vector2(0, 40)
	_spin_largo.value_changed.connect(func(_v): _on_campo_actualizado(""))
	_caja_dimensiones_rect.add_child(_spin_largo)

	grid.add_child(_caja_dimensiones_rect)

	# Altura
	grid.add_child(_crear_label_campo("Altura de Detección (Y):", "Espacio vertical sobre el suelo donde el vehículo es detectado."))
	_spin_altura = SpinBox.new()
	_spin_altura.min_value = 0.5
	_spin_altura.max_value = 20.0
	_spin_altura.step = 0.5
	_spin_altura.custom_minimum_size = Vector2(0, 40)
	_spin_altura.value_changed.connect(func(_v): _on_campo_actualizado(""))
	grid.add_child(_spin_altura)

	# Coordenadas 3D
	grid.add_child(_crear_label_campo("Posición Mundial (X, Y, Z):", "Ubicación en el sistema de coordenadas del mapa 3D."))
	var h_pos = HBoxContainer.new()
	h_pos.add_theme_constant_override("separation", 10)

	_spin_pos_x = SpinBox.new()
	_spin_pos_x.min_value = -10000.0
	_spin_pos_x.max_value = 10000.0
	_spin_pos_x.step = 0.1
	_spin_pos_x.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_pos_x.custom_minimum_size = Vector2(0, 40)
	_spin_pos_x.value_changed.connect(func(_v): _on_campo_actualizado(""))
	h_pos.add_child(_spin_pos_x)

	_spin_pos_y = SpinBox.new()
	_spin_pos_y.min_value = -500.0
	_spin_pos_y.max_value = 2000.0
	_spin_pos_y.step = 0.1
	_spin_pos_y.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_pos_y.custom_minimum_size = Vector2(0, 40)
	_spin_pos_y.value_changed.connect(func(_v): _on_campo_actualizado(""))
	h_pos.add_child(_spin_pos_y)

	_spin_pos_z = SpinBox.new()
	_spin_pos_z.min_value = -10000.0
	_spin_pos_z.max_value = 10000.0
	_spin_pos_z.step = 0.1
	_spin_pos_z.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_pos_z.custom_minimum_size = Vector2(0, 40)
	_spin_pos_z.value_changed.connect(func(_v): _on_campo_actualizado(""))
	h_pos.add_child(_spin_pos_z)

	grid.add_child(h_pos)

	# Rotación Y
	grid.add_child(_crear_label_campo("Orientación Angular (Y):", "Giro horizontal en grados respecto al eje del mundo."))
	_spin_rot_y = SpinBox.new()
	_spin_rot_y.min_value = -180.0
	_spin_rot_y.max_value = 180.0
	_spin_rot_y.step = 1.0
	_spin_rot_y.custom_minimum_size = Vector2(0, 40)
	_spin_rot_y.value_changed.connect(func(_v): _on_campo_actualizado(""))
	grid.add_child(_spin_rot_y)

	return scroll

func _crear_pestana_visuales() -> Control:
	var scroll = ScrollContainer.new()
	scroll.name = "Visuales y Preview"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	# Grosor
	grid.add_child(_crear_label_campo("Grosor de Línea:", "Anchura de la franja perimetral proyectada en el suelo."))
	_spin_grosor = SpinBox.new()
	_spin_grosor.min_value = 0.01
	_spin_grosor.max_value = 0.30
	_spin_grosor.step = 0.01
	_spin_grosor.custom_minimum_size = Vector2(0, 40)
	_spin_grosor.value_changed.connect(func(_v): _on_campo_actualizado(""))
	grid.add_child(_spin_grosor)

	# Curvatura
	grid.add_child(_crear_label_campo("Curvatura de Esquinas:", "Suavizado en los vértices del rectángulo (forma caja)."))
	_spin_esquinas = SpinBox.new()
	_spin_esquinas.min_value = 0.05
	_spin_esquinas.max_value = 0.50
	_spin_esquinas.step = 0.05
	_spin_esquinas.custom_minimum_size = Vector2(0, 40)
	_spin_esquinas.value_changed.connect(func(_v): _on_campo_actualizado(""))
	grid.add_child(_spin_esquinas)

	# Velocidades
	grid.add_child(_crear_label_campo("Velocidad de Efectos:", "Velocidad del haz lumínico perimetral y ritmo de pulsación."))
	var h_vel = HBoxContainer.new()
	h_vel.add_theme_constant_override("separation", 12)

	_spin_vel_trail = SpinBox.new()
	_spin_vel_trail.min_value = 0.0
	_spin_vel_trail.max_value = 10.0
	_spin_vel_trail.step = 0.5
	_spin_vel_trail.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_vel_trail.custom_minimum_size = Vector2(0, 40)
	_spin_vel_trail.value_changed.connect(func(_v): _on_campo_actualizado(""))
	h_vel.add_child(_spin_vel_trail)

	_spin_vel_pulso = SpinBox.new()
	_spin_vel_pulso.min_value = 0.0
	_spin_vel_pulso.max_value = 10.0
	_spin_vel_pulso.step = 0.5
	_spin_vel_pulso.size_flags_horizontal = SIZE_EXPAND_FILL
	_spin_vel_pulso.custom_minimum_size = Vector2(0, 40)
	_spin_vel_pulso.value_changed.connect(func(_v): _on_campo_actualizado(""))
	h_vel.add_child(_spin_vel_pulso)

	grid.add_child(h_vel)

	# Color
	grid.add_child(_crear_label_campo("Color Personalizado:", "Sobrescribe la coloración predeterminada según el tipo."))
	var h_col = HBoxContainer.new()
	h_col.add_theme_constant_override("separation", 12)

	_chk_color_pers = CheckBox.new()
	_chk_color_pers.text = "Activar"
	_chk_color_pers.toggled.connect(func(_b): _on_campo_actualizado(""))
	h_col.add_child(_chk_color_pers)

	_btn_color_pers = ColorPickerButton.new()
	_btn_color_pers.custom_minimum_size = Vector2(80, 36)
	_btn_color_pers.color = Color(0.35, 0.55, 0.85, 0.85)
	_btn_color_pers.color_changed.connect(func(_c): _on_campo_actualizado(""))
	h_col.add_child(_btn_color_pers)

	grid.add_child(h_col)

	# Opacidad y Etiqueta 3D
	grid.add_child(_crear_label_campo("Visibilidad en Mundo:", "Transparencia del suelo y activación de la etiqueta flotante."))
	var h_vis = HBoxContainer.new()
	h_vis.add_theme_constant_override("separation", 16)

	_spin_opacidad = SpinBox.new()
	_spin_opacidad.min_value = 0.1
	_spin_opacidad.max_value = 1.0
	_spin_opacidad.step = 0.05
	_spin_opacidad.custom_minimum_size = Vector2(100, 40)
	_spin_opacidad.value_changed.connect(func(_v): _on_campo_actualizado(""))
	h_vis.add_child(_spin_opacidad)

	_chk_etiqueta_3d = CheckBox.new()
	_chk_etiqueta_3d.text = "Mostrar texto 3D sobre la zona"
	_chk_etiqueta_3d.toggled.connect(func(_b): _on_campo_actualizado(""))
	h_vis.add_child(_chk_etiqueta_3d)

	grid.add_child(h_vis)

	# Separador
	vbox.add_child(_crear_separador_horizontal())

	# SubViewport Preview 3D
	var lbl_preview = Label.new()
	lbl_preview.text = "Previsualización 3D en Tiempo Real:"
	lbl_preview.add_theme_font_size_override("font_size", 14)
	lbl_preview.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(lbl_preview)

	_crear_preview_subviewport(vbox)

	return scroll

func _crear_preview_subviewport(parent: Control) -> void:
	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 200)
	frame.add_theme_stylebox_override("panel", _crear_stylebox(Color(0.06, 0.07, 0.09), COLOR_BORDER_DEFAULT, 8, 1, 0))
	parent.add_child(frame)

	var sub_cont = SubViewportContainer.new()
	sub_cont.stretch = true
	sub_cont.size_flags_horizontal = SIZE_EXPAND_FILL
	sub_cont.size_flags_vertical = SIZE_EXPAND_FILL
	frame.add_child(sub_cont)

	_viewport_preview = SubViewport.new()
	_viewport_preview.own_world_3d = true
	_viewport_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_preview.msaa_3d = Viewport.MSAA_4X
	sub_cont.add_child(_viewport_preview)

	var root_3d = Node3D.new()
	_viewport_preview.add_child(root_3d)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.34)

	var we = WorldEnvironment.new()
	we.environment = env
	root_3d.add_child(we)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 45, 0)
	light.light_energy = 0.7
	root_3d.add_child(light)

	var floor_m = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(35, 35)
	floor_m.mesh = plane
	var mat_fl = StandardMaterial3D.new()
	mat_fl.albedo_color = Color(0.10, 0.11, 0.13)
	mat_fl.roughness = 0.9
	floor_m.material_override = mat_fl
	root_3d.add_child(floor_m)

	_pivot_camara = Node3D.new()
	root_3d.add_child(_pivot_camara)

	var cam = Camera3D.new()
	_pivot_camara.add_child(cam)
	cam.look_at_from_position(Vector3(0, 9, 15), Vector3.ZERO, Vector3.UP)

	_nodo_preview_punto = PuntoCargaDescarga.new()
	root_3d.add_child(_nodo_preview_punto)

func _process(delta: float) -> void:
	if is_instance_valid(_pivot_camara):
		_pivot_camara.rotate_y(delta * 0.15)

# ═══════════════════════════════════════════════════════════════════════
# ACTUALIZACIÓN DE DATOS Y ESTADOS
# ═══════════════════════════════════════════════════════════════════════
func _refrescar_lista() -> void:
	for c in _lista_vbox.get_children():
		c.queue_free()

	var termino = _filtro_texto.to_lower().strip_edges()

	for i in range(_puntos.size()):
		var p_data = _puntos[i]
		var id_p = str(p_data.get("id_punto", ""))
		var nom_p = str(p_data.get("nombre_punto", ""))
		var tipo_p = int(p_data.get("tipo_punto", 0))

		if _filtro_tipo != -1 and tipo_p != _filtro_tipo:
			continue
		if termino != "" and not (termino in id_p.to_lower() or termino in nom_p.to_lower()):
			continue

		var item = _crear_item_lista(i, p_data, i == _indice_actual)
		_lista_vbox.add_child(item)

func _crear_item_lista(indice: int, datos: Dictionary, seleccionado: bool) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 58)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL

	var bg_col = COLOR_SURFACE_HOVER if seleccionado else COLOR_SURFACE_ELEVATED
	var border_col = COLOR_BORDER_FOCUS if seleccionado else COLOR_BORDER_DEFAULT
	btn.add_theme_stylebox_override("normal", _crear_stylebox(bg_col, border_col, 6, 1, 10))
	btn.add_theme_stylebox_override("hover", _crear_stylebox(COLOR_SURFACE_HOVER, COLOR_BORDER_FOCUS, 6, 1, 10))
	btn.add_theme_stylebox_override("pressed", _crear_stylebox(bg_col, border_col, 6, 1, 10))

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(PRESET_FULL_RECT)
	hbox.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)

	var v_text = VBoxContainer.new()
	v_text.size_flags_horizontal = SIZE_EXPAND_FILL
	v_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(v_text)

	var l_nom = Label.new()
	l_nom.text = "%d. %s" % [indice + 1, datos.get("nombre_punto", "Punto")]
	l_nom.add_theme_font_size_override("font_size", 15)
	l_nom.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY if seleccionado else COLOR_TEXT_SECONDARY)
	v_text.add_child(l_nom)

	var cargas: Array = datos.get("cargas_permitidas", [])
	var l_id = Label.new()
	l_id.text = "%s  •  %d categorías" % [datos.get("id_punto", ""), cargas.size()]
	l_id.add_theme_font_size_override("font_size", 12)
	l_id.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	v_text.add_child(l_id)

	# Tag de Modo
	var tipo = int(datos.get("tipo_punto", 0))
	var tag = _crear_badge_modo(tipo)
	hbox.add_child(tag)

	btn.pressed.connect(func(): seleccionar_punto(indice))
	return btn

func _crear_badge_modo(tipo: int) -> Control:
	var pnl = PanelContainer.new()
	var txt = "CARGA" if tipo == 0 else ("DESCARGA" if tipo == 1 else "AMBOS")
	var bg = COLOR_TIPO_CARGA_BG if tipo == 0 else (COLOR_TIPO_DESCARGA_BG if tipo == 1 else COLOR_TIPO_AMBOS_BG)
	var brd = COLOR_TIPO_CARGA_BORDER if tipo == 0 else (COLOR_TIPO_DESCARGA_BORDER if tipo == 1 else COLOR_TIPO_AMBOS_BORDER)
	var col = COLOR_TIPO_CARGA_TEXT if tipo == 0 else (COLOR_TIPO_DESCARGA_TEXT if tipo == 1 else COLOR_TIPO_AMBOS_TEXT)

	pnl.add_theme_stylebox_override("panel", _crear_stylebox(bg, brd, 4, 1, 6))

	var l = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", col)
	pnl.add_child(l)
	return pnl

func seleccionar_punto(idx: int) -> void:
	if idx < 0 or idx >= _puntos.size():
		return

	_indice_actual = idx
	_punto_actual = _puntos[idx]
	_poblar_formulario(_punto_actual)
	_refrescar_lista()
	_actualizar_preview()

func _poblar_formulario(d: Dictionary) -> void:
	_lbl_punto_titulo.text = d.get("nombre_punto", "Punto sin nombre")
	_lbl_punto_sub.text = "Identificador: %s  •  Índice de secuencia: %d" % [d.get("id_punto", ""), d.get("orden_indice", 0)]

	var tipo = int(d.get("tipo_punto", 0))
	_badge_tipo.text = "CARGA" if tipo == 0 else ("DESCARGA" if tipo == 1 else "CARGA Y DESCARGA")
	_badge_tipo.add_theme_color_override("font_color", COLOR_TIPO_CARGA_TEXT if tipo == 0 else (COLOR_TIPO_DESCARGA_TEXT if tipo == 1 else COLOR_TIPO_AMBOS_TEXT))

	_input_id.text = str(d.get("id_punto", ""))
	_input_nombre.text = str(d.get("nombre_punto", ""))
	_opt_tipo.selected = tipo
	_spin_tarifa.value = float(d.get("tarifa_base", 1500))
	_spin_tiempo.value = float(d.get("tiempo_operacion", 5.0))
	_chk_area.button_pressed = bool(d.get("generar_area_deteccion", true))

	var forma = int(d.get("forma_zona", 1))
	_opt_forma.selected = forma
	_spin_radio.value = float(d.get("radio", 3.5))
	_spin_ancho.value = float(d.get("ancho", 5.0))
	_spin_largo.value = float(d.get("largo", 12.0))
	_spin_altura.value = float(d.get("altura", 3.0))
	_on_forma_cambiada(forma)

	var pos = d.get("posicion", [0.0, 0.0, 0.0])
	if typeof(pos) == TYPE_ARRAY and pos.size() == 3:
		_spin_pos_x.value = pos[0]
		_spin_pos_y.value = pos[1]
		_spin_pos_z.value = pos[2]

	_spin_rot_y.value = float(d.get("rotacion_y", 0.0))
	_spin_grosor.value = float(d.get("grosor_linea", 0.02))
	_spin_esquinas.value = float(d.get("radio_esquinas", 0.25))
	_spin_vel_trail.value = float(d.get("velocidad_animacion", 3.5))
	_spin_vel_pulso.value = float(d.get("velocidad_pulsacion", 2.0))

	_chk_color_pers.button_pressed = bool(d.get("usar_color_personalizado", false))
	var col_arr = d.get("color_personalizado", [0.35, 0.55, 0.85, 0.85])
	if typeof(col_arr) == TYPE_ARRAY and col_arr.size() >= 3:
		var a = col_arr[3] if col_arr.size() >= 4 else 1.0
		_btn_color_pers.color = Color(col_arr[0], col_arr[1], col_arr[2], a)

	_spin_opacidad.value = float(d.get("opacidad_zona", 0.85))
	_chk_etiqueta_3d.button_pressed = bool(d.get("mostrar_etiqueta_3d", true))

	_refrescar_grilla_cargas()

func _on_forma_cambiada(idx: int) -> void:
	var es_cilindro = (idx == 0)
	_caja_radio.visible = es_cilindro
	_caja_dimensiones_rect.visible = not es_cilindro
	_on_campo_actualizado("")

func _refrescar_grilla_cargas() -> void:
	for c in _grid_cargas.get_children():
		c.queue_free()

	var cargas_asignadas: Array = _punto_actual.get("cargas_permitidas", [])

	for cat in _catalogo:
		var c_id = str(cat.get("id", ""))
		var c_nom = str(cat.get("nombre", ""))
		var c_desc = str(cat.get("descripcion", ""))
		var c_tar = float(cat.get("tarifa_sugerida", 1500))

		var activa = cargas_asignadas.has(c_id)

		var item_card = PanelContainer.new()
		item_card.size_flags_horizontal = SIZE_EXPAND_FILL
		var bg = COLOR_SURFACE_HOVER if activa else COLOR_SURFACE_INPUT
		var brd = COLOR_BORDER_FOCUS if activa else COLOR_BORDER_DEFAULT
		item_card.add_theme_stylebox_override("panel", _crear_stylebox(bg, brd, 6, 1, 10))

		var h_box = HBoxContainer.new()
		h_box.add_theme_constant_override("separation", 10)
		item_card.add_child(h_box)

		var chk = CheckBox.new()
		chk.button_pressed = activa
		chk.toggled.connect(func(estado): _on_chk_carga_toggled(c_id, estado, item_card))
		h_box.add_child(chk)

		var v_info = VBoxContainer.new()
		v_info.size_flags_horizontal = SIZE_EXPAND_FILL
		h_box.add_child(v_info)

		var l_title = Label.new()
		l_title.text = c_nom
		l_title.add_theme_font_size_override("font_size", 14)
		l_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY if activa else COLOR_TEXT_SECONDARY)
		v_info.add_child(l_title)

		var l_sub = Label.new()
		l_sub.text = "%s  •  Tarifa: $%d" % [c_desc, c_tar]
		l_sub.add_theme_font_size_override("font_size", 12)
		l_sub.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		v_info.add_child(l_sub)

		_grid_cargas.add_child(item_card)

func _on_chk_carga_toggled(id_carga: String, activa: bool, card_panel: PanelContainer) -> void:
	if _indice_actual < 0 or _indice_actual >= _puntos.size():
		return

	var lista: Array = _punto_actual.get("cargas_permitidas", [])
	if activa and not lista.has(id_carga):
		lista.append(id_carga)
	elif not activa and lista.has(id_carga):
		lista.erase(id_carga)

	_punto_actual["cargas_permitidas"] = lista
	_puntos[_indice_actual]["cargas_permitidas"] = lista

	var bg = COLOR_SURFACE_HOVER if activa else COLOR_SURFACE_INPUT
	var brd = COLOR_BORDER_FOCUS if activa else COLOR_BORDER_DEFAULT
	card_panel.add_theme_stylebox_override("panel", _crear_stylebox(bg, brd, 6, 1, 10))

	_actualizar_preview()

func _on_seleccionar_todas_cargas() -> void:
	if _indice_actual < 0 or _indice_actual >= _puntos.size():
		return
	var todas: Array = []
	for c in _catalogo:
		todas.append(str(c.get("id", "")))
	_punto_actual["cargas_permitidas"] = todas
	_puntos[_indice_actual]["cargas_permitidas"] = todas
	_refrescar_grilla_cargas()
	_actualizar_preview()
	_mostrar_toast("Todas las categorías fueron habilitadas.")

func _on_deseleccionar_todas_cargas() -> void:
	if _indice_actual < 0 or _indice_actual >= _puntos.size():
		return
	_punto_actual["cargas_permitidas"] = []
	_puntos[_indice_actual]["cargas_permitidas"] = []
	_refrescar_grilla_cargas()
	_actualizar_preview()
	_mostrar_toast("Todas las categorías fueron deshabilitadas.")

func _on_crear_categoria_carga() -> void:
	var id_c = _input_nueva_carga_id.text.to_lower().strip_edges()
	var nom_c = _input_nueva_carga_nom.text.strip_edges()
	var tarifa_c = _spin_nueva_carga_tarifa.value

	if id_c == "" or nom_c == "":
		_mostrar_toast("Ingrese un identificador y nombre para la categoría.", true)
		return

	var exito = GestorPuntosCarga.registrar_tipo_carga(id_c, nom_c, "", nom_c, tarifa_c, Engine.is_editor_hint())
	if exito:
		_catalogo = GestorPuntosCarga.obtener_catalogo_cargas()
		_input_nueva_carga_id.text = ""
		_input_nueva_carga_nom.text = ""
		_refrescar_grilla_cargas()
		_mostrar_toast("Categoría '%s' registrada en el catálogo." % nom_c)
	else:
		_mostrar_toast("Error al guardar la categoría.", true)

func _on_campo_actualizado(_v: String) -> void:
	if _indice_actual < 0 or _indice_actual >= _puntos.size():
		return

	_punto_actual["id_punto"] = _input_id.text.strip_edges()
	_punto_actual["nombre_punto"] = _input_nombre.text.strip_edges()
	_punto_actual["tipo_punto"] = _opt_tipo.selected
	_punto_actual["tarifa_base"] = _spin_tarifa.value
	_punto_actual["tiempo_operacion"] = _spin_tiempo.value
	_punto_actual["generar_area_deteccion"] = _chk_area.button_pressed
	_punto_actual["forma_zona"] = _opt_forma.selected
	_punto_actual["radio"] = _spin_radio.value
	_punto_actual["ancho"] = _spin_ancho.value
	_punto_actual["largo"] = _spin_largo.value
	_punto_actual["altura"] = _spin_altura.value
	_punto_actual["posicion"] = [_spin_pos_x.value, _spin_pos_y.value, _spin_pos_z.value]
	_punto_actual["rotacion_y"] = _spin_rot_y.value
	_punto_actual["grosor_linea"] = _spin_grosor.value
	_punto_actual["radio_esquinas"] = _spin_esquinas.value
	_punto_actual["velocidad_animacion"] = _spin_vel_trail.value
	_punto_actual["velocidad_pulsacion"] = _spin_vel_pulso.value
	_punto_actual["usar_color_personalizado"] = _chk_color_pers.button_pressed

	var c = _btn_color_pers.color
	_punto_actual["color_personalizado"] = [c.r, c.g, c.b, c.a]
	_punto_actual["opacidad_zona"] = _spin_opacidad.value
	_punto_actual["mostrar_etiqueta_3d"] = _chk_etiqueta_3d.button_pressed

	_puntos[_indice_actual] = _punto_actual
	_lbl_punto_titulo.text = _punto_actual["nombre_punto"]
	_actualizar_preview()

func _actualizar_preview() -> void:
	if is_instance_valid(_nodo_preview_punto) and not _punto_actual.is_empty():
		GestorPuntosCarga.aplicar_datos_a_nodo(_nodo_preview_punto, _punto_actual)

func _on_buscar_texto_changed(t: String) -> void:
	_filtro_texto = t
	_refrescar_lista()

func _crear_boton_filtro(texto: String, tipo: int) -> Button:
	var b = Button.new()
	b.text = texto
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 32)
	_estilar_boton_secundario(b, 12)
	b.pressed.connect(func():
		_filtro_tipo = tipo
		_refrescar_lista()
	)
	return b

# ═══════════════════════════════════════════════════════════════════════
# ACCIONES DE EDICIÓN Y PERSISTENCIA
# ═══════════════════════════════════════════════════════════════════════
func _on_nuevo_click() -> void:
	var nuevo_id = "punto_%02d" % (_puntos.size() + 1)
	var d = GestorPuntosCarga.crear_nuevo_punto_dict(nuevo_id, "Punto Logístico %d" % (_puntos.size() + 1))
	d["orden_indice"] = _puntos.size()
	_puntos.append(d)
	_refrescar_lista()
	seleccionar_punto(_puntos.size() - 1)
	_mostrar_toast("Nuevo punto registrado.")

func _on_duplicar_click() -> void:
	if _indice_actual < 0 or _indice_actual >= _puntos.size():
		return
	var orig = _puntos[_indice_actual]
	var copia: Dictionary = orig.duplicate(true)
	copia["id_punto"] = str(orig["id_punto"]) + "_copia"
	copia["nombre_punto"] = str(orig["nombre_punto"]) + " (Copia)"
	copia["orden_indice"] = _puntos.size()

	var pos = copia.get("posicion", [0.0, 0.0, 0.0])
	if typeof(pos) == TYPE_ARRAY and pos.size() == 3:
		copia["posicion"] = [pos[0] + 5.0, pos[1], pos[2] + 5.0]

	_puntos.append(copia)
	_refrescar_lista()
	seleccionar_punto(_puntos.size() - 1)
	_mostrar_toast("Punto duplicado.")

func _on_subir_click() -> void:
	if _indice_actual <= 0:
		return
	var item = _puntos[_indice_actual]
	_puntos.remove_at(_indice_actual)
	_puntos.insert(_indice_actual - 1, item)
	_reordenar_indices()
	seleccionar_punto(_indice_actual - 1)

func _on_bajar_click() -> void:
	if _indice_actual < 0 or _indice_actual >= _puntos.size() - 1:
		return
	var item = _puntos[_indice_actual]
	_puntos.remove_at(_indice_actual)
	_puntos.insert(_indice_actual + 1, item)
	_reordenar_indices()
	seleccionar_punto(_indice_actual + 1)

func _on_eliminar_click() -> void:
	if _indice_actual < 0 or _indice_actual >= _puntos.size():
		return
	var id_borrado = _puntos[_indice_actual].get("id_punto", "")
	_puntos.remove_at(_indice_actual)
	_reordenar_indices()

	if _puntos.size() > 0:
		var n_idx = mini(_indice_actual, _puntos.size() - 1)
		seleccionar_punto(n_idx)
	else:
		_indice_actual = -1
		_punto_actual = {}
		_refrescar_lista()

	_mostrar_toast("Punto '%s' eliminado." % id_borrado)

func _reordenar_indices() -> void:
	for i in range(_puntos.size()):
		_puntos[i]["orden_indice"] = i

func _on_guardar_click() -> void:
	_reordenar_indices()
	_datos["puntos"] = _puntos
	_datos["catalogo_cargas"] = _catalogo

	var exito = GestorPuntosCarga.guardar_datos(_datos, Engine.is_editor_hint())
	if exito:
		_mostrar_toast("Configuración guardada exitosamente.")
		configuracion_guardada.emit()
	else:
		_mostrar_toast("Error al guardar en el archivo de configuración.", true)

func _on_sincronizar_click() -> void:
	_on_guardar_click()

	var biblio = get_tree().get_first_node_in_group("biblioteca_puntos_carga") as BibliotecaPuntosCarga
	if is_instance_valid(biblio):
		biblio.aplicar_configuracion_desde_json()
		_mostrar_toast("Sincronización completada con BibliotecaPuntosCarga.")
		return

	var raiz = get_tree().current_scene
	if is_instance_valid(raiz):
		var nodo_p = raiz.find_child("Puntos", true, false)
		if is_instance_valid(nodo_p):
			for c in nodo_p.get_children():
				if c is PuntoCargaDescarga:
					var d = GestorPuntosCarga.obtener_punto_por_id(c.id_punto)
					if not d.is_empty():
						GestorPuntosCarga.aplicar_datos_a_nodo(c, d)
			_mostrar_toast("Puntos actualizados en la escena activa.")
			return

	_mostrar_toast("Guardado en disco. Se cargará al abrir la escena del mapa.")

func _on_cerrar_click() -> void:
	configuracion_cerrada.emit()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_ventana_panel, "modulate:a", 0.0, 0.2)
	tw.tween_property(_ventana_panel, "scale", Vector2(0.96, 0.96), 0.2)
	tw.chain().tween_callback(queue_free)

# ═══════════════════════════════════════════════════════════════════════
# ESTILOS Y COMPONENTES VISUALES
# ═══════════════════════════════════════════════════════════════════════
func _animar_aparicion() -> void:
	_ventana_panel.modulate.a = 0.0
	_ventana_panel.scale = Vector2(0.96, 0.96)
	_ventana_panel.pivot_offset = _ventana_panel.size * 0.5
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_ventana_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_ventana_panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _crear_stylebox(bg: Color, border: Color, radius: int = 6, border_width: int = 1, pad: int = 8) -> StyleBoxFlat:
	var st = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.border_width_left = border_width
	st.border_width_top = border_width
	st.border_width_right = border_width
	st.border_width_bottom = border_width
	st.corner_radius_top_left = radius
	st.corner_radius_top_right = radius
	st.corner_radius_bottom_left = radius
	st.corner_radius_bottom_right = radius
	st.content_margin_left = pad
	st.content_margin_top = pad
	st.content_margin_right = pad
	st.content_margin_bottom = pad
	return st

func _estilar_input(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", _crear_stylebox(COLOR_SURFACE_INPUT, COLOR_BORDER_DEFAULT, 6, 1, 10))
	input.add_theme_stylebox_override("focus", _crear_stylebox(COLOR_SURFACE_INPUT, COLOR_BORDER_FOCUS, 6, 1, 10))
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func _estilar_boton_primario(b: Button, font_size: int = 14) -> void:
	b.add_theme_stylebox_override("normal", _crear_stylebox(COLOR_ACCENT_PRIMARY, COLOR_ACCENT_HOVER, 6, 1, 12))
	b.add_theme_stylebox_override("hover", _crear_stylebox(COLOR_ACCENT_HOVER, COLOR_BORDER_FOCUS, 6, 1, 12))
	b.add_theme_stylebox_override("pressed", _crear_stylebox(COLOR_ACCENT_PRIMARY, COLOR_BORDER_FOCUS, 6, 1, 12))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func _estilar_boton_secundario(b: Button, font_size: int = 14) -> void:
	b.add_theme_stylebox_override("normal", _crear_stylebox(COLOR_SURFACE_ELEVATED, COLOR_BORDER_DEFAULT, 6, 1, 10))
	b.add_theme_stylebox_override("hover", _crear_stylebox(COLOR_SURFACE_HOVER, COLOR_BORDER_FOCUS, 6, 1, 10))
	b.add_theme_stylebox_override("pressed", _crear_stylebox(COLOR_SURFACE_ELEVATED, COLOR_BORDER_DEFAULT, 6, 1, 10))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

func _estilar_boton_peligro(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _crear_stylebox(COLOR_TIPO_DESCARGA_BG, COLOR_TIPO_DESCARGA_BORDER, 6, 1, 8))
	b.add_theme_stylebox_override("hover", _crear_stylebox(Color(0.25, 0.16, 0.16), COLOR_TIPO_DESCARGA_BORDER, 6, 1, 8))
	b.add_theme_stylebox_override("pressed", _crear_stylebox(COLOR_TIPO_DESCARGA_BG, COLOR_TIPO_DESCARGA_BORDER, 6, 1, 8))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", COLOR_TIPO_DESCARGA_TEXT)

func _estilar_tab_container(tabs: TabContainer) -> void:
	var st_tab_sel = _crear_stylebox(COLOR_SURFACE_MAIN, COLOR_BORDER_FOCUS, 6, 1, 12)
	var st_tab_unsel = _crear_stylebox(COLOR_SURFACE_ELEVATED, COLOR_BORDER_DEFAULT, 6, 1, 12)
	tabs.add_theme_stylebox_override("tab_selected", st_tab_sel)
	tabs.add_theme_stylebox_override("tab_unselected", st_tab_unsel)
	tabs.add_theme_stylebox_override("tab_hovered", st_tab_sel)
	tabs.add_theme_stylebox_override("panel", _crear_stylebox(COLOR_SURFACE_MAIN, COLOR_BORDER_DEFAULT, 8, 1, 16))
	tabs.add_theme_font_size_override("font_size", 14)
	tabs.add_theme_color_override("font_selected_color", COLOR_TEXT_PRIMARY)
	tabs.add_theme_color_override("font_unselected_color", COLOR_TEXT_SECONDARY)

func _crear_separador_horizontal() -> HSeparator:
	var sep = HSeparator.new()
	var st = StyleBoxLine.new()
	st.color = COLOR_BORDER_DEFAULT
	st.thickness = 1
	sep.add_theme_stylebox_override("separator", st)
	return sep

func _crear_label_campo(titulo: String, tooltip: String = "") -> VBoxContainer:
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(240, 0)
	box.add_theme_constant_override("separation", 2)

	var l = Label.new()
	l.text = titulo
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	box.add_child(l)

	if tooltip != "":
		var sub = Label.new()
		sub.text = tooltip
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		box.add_child(sub)

	return box

func _crear_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.custom_minimum_size = Vector2(360, 40)
	_toast_panel.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_toast_panel.position = Vector2(0, -60)
	_toast_panel.modulate.a = 0.0
	_toast_panel.add_theme_stylebox_override("panel", _crear_stylebox(COLOR_SURFACE_ELEVATED, COLOR_BORDER_FOCUS, 8, 1, 12))
	_ventana_panel.add_child(_toast_panel)

	_toast_lbl = Label.new()
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.add_theme_font_size_override("font_size", 13)
	_toast_lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_toast_panel.add_child(_toast_lbl)

func _mostrar_toast(mensaje: String, es_error: bool = false) -> void:
	if not is_instance_valid(_toast_panel):
		return
	_toast_lbl.text = mensaje
	_toast_lbl.add_theme_color_override("font_color", COLOR_TIPO_DESCARGA_TEXT if es_error else COLOR_TEXT_PRIMARY)

	var tw = create_tween()
	tw.tween_property(_toast_panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.2)
	tw.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)
