class_name UIEditorMapas
extends CanvasLayer

## UIEditorMapas.gd — Rediseño Completo de Interfaz para el Editor de Mapas
## Nuestra Tierra 2.0 — Estética Dark Glassmorphism Profesional con Acentos Amarillo Dorado
## Optimizado para resolución nativa 2392 x 1080 (FHD+ Táctil Móvil, Tablets y PC)

const GeneradorModelosCiudad = preload("res://mundo/editor_mapas/GeneradorModelosCiudad.gd")
const CargadorBiblioteca = preload("res://mundo/editor_mapas/CargadorBiblioteca.gd")

# ── TOKENS DE COLOR Y DISEÑO (GLASSMORPHISM AUTOMOTRIZ) ──────────────
const COLOR_FONDO_PRINCIPAL := Color(0.090, 0.098, 0.114, 0.96) # #17191D
const COLOR_PANEL           := Color(0.133, 0.145, 0.169, 0.95) # #22252B
const COLOR_PANEL_SEC       := Color(0.161, 0.176, 0.204, 0.94) # #292D34
const COLOR_BORDE           := Color(0.224, 0.239, 0.271, 0.85) # #393D45
const COLOR_BORDE_ACTIVO    := Color(1.000, 0.773, 0.180, 0.98) # #FFC52E
const COLOR_AMARILLO_PRI    := Color(0.898, 0.698, 0.247, 1.00) # #E5B23F
const COLOR_AMARILLO_SEL    := Color(1.000, 0.773, 0.180, 1.00) # #FFC52E
const COLOR_TEXTO_PRI       := Color(0.953, 0.953, 0.953, 1.00) # #F3F3F3
const COLOR_TEXTO_SEC       := Color(0.647, 0.659, 0.686, 1.00) # #A5A8AF
const COLOR_VERDE_ACTIVO    := Color(0.180, 0.800, 0.440, 1.00) # #2ECC71
const COLOR_CRIMSON_SALIR   := Color(0.780, 0.280, 0.260, 0.95) # Technical Crimson

# ── JERARQUÍA TIPOGRÁFICA EQUILIBRADA (PUNTO MEDIO ÓPTIMO TÁCTIL / DESKTOP) ─────
const FONT_TITULO_PRINCIPAL := 30 # Título principal de tarjeta contextual (ej. "Elevar Terreno")
const FONT_TITULO_SUB       := 26 # Títulos de subsección y opciones de menú
const FONT_BOTON_ACCION     := 24 # Botón maestro "Aplicar", "Colocar", "Finalizar"
const FONT_BOTON_MEDIO      := 21 # Botones de categorías ("Terreno", "Vías", "Salir")
const FONT_READOUT_VALOR    := 21 # Lectura numérica de sliders ("25 m", "0.40")
const FONT_LABEL_SLIDER     := 21 # Etiquetas de parámetros ("Radio del pincel", "Fuerza")
const FONT_BOTON_GRID       := 17 # Etiquetas de botones 3x3 ("Elevar", "Bajar", "Aplanar")
const FONT_ESTADO_HUD       := 18 # Barra de estado inferior y FPS
const FONT_TEXTO_INFO       := 18 # Descripciones contextuales
const FONT_BADGE            := 14 # Píldoras de estado ("● Activo")

# ── SEÑALES PÚBLICAS REQUERIDAS POR EL EDITOR ───────────────────────
signal categoria_cambiada(categoria: String)
signal subherramienta_seleccionada(id_herramienta: String)
signal radio_pincel_cambiado(nuevo_radio: float)
signal fuerza_pincel_cambiada(nueva_fuerza: float)
signal perfil_pincel_cambiado(nuevo_perfil: int)
signal demolicion_alternada(activa: bool)
signal rotar_objeto_solicitado()
signal snap_cuadricula_alternado(activo: bool)
signal terminar_tramo_via_solicitado()
signal conectar_vias_solicitado()
signal deshacer_punto_via_solicitado()
signal rehacer_solicitado()
signal nivelar_terreno_vias_solicitado()
signal alternar_modo_spawn_solicitado()
signal guardar_mapa_solicitado()
signal cargar_mapa_solicitado()
signal iniciar_prueba_solicitado()
signal accion_colocar_solicitada()

# Señales de cruces procedurales
signal cruce_radio_cambiado(nuevo_radio: float)
signal cruce_rotacion_cambiada(angulo_grados: float)
signal cruce_rotar_rapido_solicitado(delta_grados: float)
signal cruce_tipo_via_cambiado(tipo: int)
signal cruce_ramal_seleccionado(indice: int)
signal cruce_num_brazos_cambiado(num_brazos: int)
signal cruce_aplanar_alternado(activo: bool)
signal cruce_eliminar_solicitado()
signal cruce_edicion_cerrada()

# Señales de puntos de rasante de carretera
signal punto_via_eliminado_solicitado()
signal hora_dia_cambiada(hora: int)
signal modo_dispersion_vegetacion_alternado(activo: bool)
signal radio_dispersion_vegetacion_cambiado(radio: float)
signal densidad_dispersion_vegetacion_cambiada(densidad: int)
signal borrar_dispersion_vegetacion_solicitado()
signal punto_via_tipo_cambiado(tipo: int)
signal punto_via_peralte_cambiado(grados: float)
signal punto_via_altura_cambiada(altura: float)
signal adaptar_terreno_tramo_solicitado()
signal punto_via_edicion_cerrada()

# Señales de equipamiento vial
signal equipamiento_tipo_cambiado(tipo: int)
signal equipamiento_lado_cambiado(lado: int)
signal equipamiento_ancho_cambiado(ancho: float)
signal equipamiento_tipo_acera_cambiado(tipo_acera: int)
signal equipamiento_modo_arboles_cambiado(modo: int)
signal equipamiento_arboles_seleccionados_cambiados(arboles: Array)
signal equipamiento_aplicar_solicitado()
signal equipamiento_limpiar_solicitado()
signal equipamiento_cancelar_solicitado()

# Señales de objetos
signal objeto_rotacion_delta(delta_grados: float)
signal objeto_rotacion_fijada(grados: float)
signal objeto_altura_delta(delta_y: float)
signal objeto_altura_reset()
signal objeto_eliminar_solicitado()
signal objeto_reemplazar_solicitado()
signal objeto_mover_alternado(activo: bool)
signal objeto_edicion_cerrada()

# Señales de cámara
signal camara_pan_solicitado(direccion: Vector2)
signal camara_zoom_solicitado(factor: float)
signal camara_orbita_solicitada(grados: float)
signal camara_pitch_solicitada(grados: float)
signal camara_cenital_solicitada()

# ── ESTADO INTERNO ──────────────────────────────────────────────────
var _fuente_ui: Font = null
var _fuente_moderniz: Font = null
var _categoria_activa: String = "terreno"
var _subherramienta_activa: String = "elevar"
var _id_item_activo: String = "elevar"
var _perfil_pincel_activo: int = 0 # 0: Suave, 1: Medio, 2: Fuerte
var _radio_pincel: float = 25.0
var _fuerza_pincel: float = 0.40
var _altura_objetivo_terreno: float = 12.0
var _opacidad_textura: float = 0.85
var _radio_lago: float = 24.0
var _profundidad_lago: float = 3.5
var _ancho_rio: float = 8.0
var _densidad_dispersion: int = 12
var _radio_dispersion: float = 20.0

var _modo_demolicion_activo: bool = false
var _snap_grid_activo: bool = false
var _modo_cenital_activo: bool = false
var _modo_dispersion_activo: bool = false
var _modo_mover_objeto_ui: bool = false
var _hora_solar_idx: int = 1 # Mediodía
var _rotacion_objeto_actual: float = 0.0
var _altura_objeto_actual: float = 0.0

# Para carreteras y cruces
var _tipo_equip_ui_actual: int = 0
var _lado_equip_ui_actual: int = 0
var _ancho_equip_ui_actual: float = 1.8
var _tipo_acera_ui_actual: int = 0
var _modo_distribucion_arboles_ui: int = 0
var _arboles_seleccionados_ui: Array[String] = ["arbol_sabanero", "arbol_roble_3d"]
var _seccion_biblioteca_activa: String = "01_Residencial"
var _subapartado_biblioteca_activa: String = "todos"

# Textura cacheada para sliders
var _textura_grabber: Texture2D = null

# ── REFERENCIAS DE NODOS DE INTERFAZ ────────────────────────────────
var _contenedor_raiz: Control

# Barra superior
var _hud_superior: PanelContainer
var _box_categorias_hud: HBoxContainer
var _dict_botones_categoria: Dictionary = {}
var _btn_deshacer_hud: Button
var _btn_rehacer_hud: Button
var _btn_menu_sistema: Button

# Panel flotante de herramientas (Izquierda)
var _panel_herramientas: PanelContainer
var _btn_colapsar_herramientas: Button
var _esta_colapsado_herramientas: bool = false
var _grid_herramientas: GridContainer
var _dict_botones_herramientas: Dictionary = {}

# Panel contextual de propiedades (Derecha)
var _panel_propiedades: PanelContainer
var _btn_colapsar_propiedades: Button
var _esta_colapsado_propiedades: bool = false
var _lbl_prop_titulo: Label
var _lbl_prop_badge: Label
var _ico_prop_header: TextureRect
var _box_prop_contenido: VBoxContainer
var _btn_prop_aplicar: Button
var _btn_prop_restablecer: Button

# Referencias para sliders y lecturas dinámicas
var _dict_sliders: Dictionary = {}
var _dict_readouts: Dictionary = {}
var _dict_botones_perfil: Dictionary = {}

# HUD Inferior
var _hud_inferior_izquierdo: HBoxContainer
var _widget_brujula: Control
var _panel_telemetria: PanelContainer
var _lbl_fps: Label
var _lbl_mapa_res: Label
var _hud_barra_estado: PanelContainer
var _lbl_modo_estado: Label

# Popup de sistema y opciones
var _popup_sistema: PanelContainer
var _panel_toast_flotante: PanelContainer
var _toast_hud: Label

# Objeto compatibilidad: Botón colocar grande histórico
var _btn_colocar_grande: Button

# ── INICIALIZACIÓN ──────────────────────────────────────────────────
func _ready() -> void:
	if ResourceLoader.exists("res://recursos/fonts/nexa/Nexa-Heavy.ttf"):
		_fuente_ui = load("res://recursos/fonts/nexa/Nexa-Heavy.ttf")
	if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
		_fuente_moderniz = load("res://recursos/fonts/Moderniz.otf")
	_construir_interfaz_completa()
	seleccionar_categoria("terreno")
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _process(_delta: float) -> void:
	# Rotar aguja de la brújula con la orientación yaw de la cámara activa
	var cam := get_viewport().get_camera_3d()
	if cam and is_instance_valid(cam) and _widget_brujula:
		var yaw := cam.global_rotation.y
		if _widget_brujula.has_method("set_rotacion_camara"):
			_widget_brujula.call("set_rotacion_camara", yaw)
		else:
			_widget_brujula.queue_redraw()

# ── HELPER DE CARGA DE ICONOS SVG ────────────────────────────────────
func _cargar_icono_svg(nombre: String) -> Texture2D:
	var ruta := "res://recursos/iconos_editor/" + nombre + ".svg"
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	return null

# ── CONSTRUCCIÓN COMPLETA DE LA INTERFAZ ─────────────────────────────
func _construir_interfaz_completa() -> void:
	_contenedor_raiz = Control.new()
	_contenedor_raiz.name = "RootUI"
	_contenedor_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contenedor_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_contenedor_raiz)

	_construir_barra_superior_hud(_contenedor_raiz)
	_construir_panel_herramientas(_contenedor_raiz)
	_construir_panel_propiedades(_contenedor_raiz)
	_construir_hud_inferior_izquierdo(_contenedor_raiz)
	_construir_hud_barra_estado(_contenedor_raiz)
	_construir_popup_sistema(_contenedor_raiz)
	_construir_toast_flotante(_contenedor_raiz)

# ── 1. BARRA SUPERIOR DE NAVEGACIÓN (ZONA A) ─────────────────────────
func _construir_barra_superior_hud(padre: Control) -> void:
	_hud_superior = PanelContainer.new()
	_hud_superior.name = "HUDSuperior"
	_hud_superior.anchor_left = 0.0
	_hud_superior.anchor_right = 1.0
	_hud_superior.anchor_top = 0.0
	_hud_superior.anchor_bottom = 0.0
	_hud_superior.offset_left = 20.0
	_hud_superior.offset_right = -20.0
	_hud_superior.offset_top = 12.0
	_hud_superior.offset_bottom = 86.0 # 74px de altura óptima para interacción táctil y desktop
	_hud_superior.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_hud_superior, COLOR_PANEL, COLOR_BORDE, 16.0, 8.0)
	padre.add_child(_hud_superior)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	_hud_superior.add_child(hbox)

	# Logo "NUESTRA TIERRA 2.0"
	var box_logo := HBoxContainer.new()
	box_logo.alignment = BoxContainer.ALIGNMENT_CENTER
	box_logo.add_theme_constant_override("separation", 10)
	hbox.add_child(box_logo)

	var tex_logo := _cargar_icono_svg("logo_nuestra_tierra_editor")
	if tex_logo:
		var rect_logo := TextureRect.new()
		rect_logo.texture = tex_logo
		rect_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect_logo.custom_minimum_size = Vector2(48, 38)
		box_logo.add_child(rect_logo)

	var vbox_brand := VBoxContainer.new()
	vbox_brand.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_brand.add_theme_constant_override("separation", -4)
	box_logo.add_child(vbox_brand)

	var lbl_nuestra := Label.new()
	lbl_nuestra.text = "NUESTRA"
	lbl_nuestra.add_theme_font_size_override("font_size", 14)
	lbl_nuestra.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_nuestra.add_theme_font_override("font", _fuente_ui)
	elif _fuente_moderniz:
		lbl_nuestra.add_theme_font_override("font", _fuente_moderniz)
	vbox_brand.add_child(lbl_nuestra)

	var lbl_tierra := Label.new()
	lbl_tierra.text = "TIERRA 2.0"
	lbl_tierra.add_theme_font_size_override("font_size", 20)
	lbl_tierra.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui:
		lbl_tierra.add_theme_font_override("font", _fuente_ui)
	elif _fuente_moderniz:
		lbl_tierra.add_theme_font_override("font", _fuente_moderniz)
	vbox_brand.add_child(lbl_tierra)

	# Separador vertical
	var sep1 := VSeparator.new()
	sep1.add_theme_constant_override("separation", 12)
	hbox.add_child(sep1)

	# Categorías principales (Scroll táctil horizontal para móvil)
	var scroll_cat := ScrollContainer.new()
	scroll_cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_cat.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_cat.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hbox.add_child(scroll_cat)

	_box_categorias_hud = HBoxContainer.new()
	_box_categorias_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	_box_categorias_hud.add_theme_constant_override("separation", 10)
	scroll_cat.add_child(_box_categorias_hud)

	var cats = [
		{"id": "terreno", "nombre": "Terreno", "ico": "cat_terreno"},
		{"id": "vias", "nombre": "Vías", "ico": "cat_vias"},
		{"id": "ciudad", "nombre": "Ciudad", "ico": "cat_ciudad"},
		{"id": "vegetacion", "nombre": "Naturaleza", "ico": "cat_vegetacion"},
		{"id": "agua", "nombre": "Agua", "ico": "cat_agua"},
		{"id": "spawn", "nombre": "Spawn", "ico": "cat_spawn"}
	]

	for c in cats:
		var btn := Button.new()
		btn.text = " " + c["nombre"]
		btn.custom_minimum_size = Vector2(144, 52)
		btn.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
		if _fuente_ui:
			btn.add_theme_font_override("font", _fuente_ui)
		_estilar_boton_pildora(btn, false)

		var ico := _cargar_icono_svg(c["ico"])
		if ico:
			btn.icon = ico
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 26)

		var cat_id: String = c["id"]
		btn.pressed.connect(func(): seleccionar_categoria(cat_id))
		_box_categorias_hud.add_child(btn)
		_dict_botones_categoria[cat_id] = btn

	# Separador vertical
	var sep2 := VSeparator.new()
	sep2.add_theme_constant_override("separation", 12)
	hbox.add_child(sep2)

	# Acciones rápidas a la derecha
	var box_derecha := HBoxContainer.new()
	box_derecha.alignment = BoxContainer.ALIGNMENT_CENTER
	box_derecha.add_theme_constant_override("separation", 10)
	hbox.add_child(box_derecha)

	# Deshacer (↶)
	_btn_deshacer_hud = Button.new()
	_btn_deshacer_hud.tooltip_text = "Deshacer última acción"
	_btn_deshacer_hud.custom_minimum_size = Vector2(52, 52)
	_estilar_boton(_btn_deshacer_hud, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	var ico_des := _cargar_icono_svg("act_deshacer")
	if ico_des:
		_btn_deshacer_hud.icon = ico_des
		_btn_deshacer_hud.expand_icon = true
		_btn_deshacer_hud.add_theme_constant_override("icon_max_width", 26)
	else:
		_btn_deshacer_hud.text = "↶"
		_btn_deshacer_hud.add_theme_font_size_override("font_size", 24)
	_btn_deshacer_hud.pressed.connect(func(): deshacer_punto_via_solicitado.emit())
	box_derecha.add_child(_btn_deshacer_hud)

	# Rehacer (↷)
	_btn_rehacer_hud = Button.new()
	_btn_rehacer_hud.tooltip_text = "Rehacer acción"
	_btn_rehacer_hud.custom_minimum_size = Vector2(52, 52)
	_estilar_boton(_btn_rehacer_hud, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	var ico_reh := _cargar_icono_svg("act_rehacer")
	if ico_reh:
		_btn_rehacer_hud.icon = ico_reh
		_btn_rehacer_hud.expand_icon = true
		_btn_rehacer_hud.add_theme_constant_override("icon_max_width", 26)
	else:
		_btn_rehacer_hud.text = "↷"
		_btn_rehacer_hud.add_theme_font_size_override("font_size", 24)
	_btn_rehacer_hud.pressed.connect(func(): rehacer_solicitado.emit())
	box_derecha.add_child(_btn_rehacer_hud)

	# Opciones / Sistema (⚙)
	_btn_menu_sistema = Button.new()
	_btn_menu_sistema.tooltip_text = "Configuración, Hora Solar, Cuadrícula, Guardar y Cargar"
	_btn_menu_sistema.custom_minimum_size = Vector2(52, 52)
	_estilar_boton(_btn_menu_sistema, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	var ico_opc := _cargar_icono_svg("act_opciones")
	if ico_opc:
		_btn_menu_sistema.icon = ico_opc
		_btn_menu_sistema.expand_icon = true
		_btn_menu_sistema.add_theme_constant_override("icon_max_width", 26)
	else:
		_btn_menu_sistema.text = "⚙"
		_btn_menu_sistema.add_theme_font_size_override("font_size", 24)
	_btn_menu_sistema.pressed.connect(_alternar_popup_sistema)
	box_derecha.add_child(_btn_menu_sistema)

	# Salir (Botón con icono y etiqueta en amarillo ámbar o crimson)
	var btn_salir := Button.new()
	btn_salir.text = " Salir"
	btn_salir.custom_minimum_size = Vector2(120, 52)
	_estilar_boton(btn_salir, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	btn_salir.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	btn_salir.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	if _fuente_ui:
		btn_salir.add_theme_font_override("font", _fuente_ui)
	var ico_sal := _cargar_icono_svg("act_salir")
	if ico_sal:
		btn_salir.icon = ico_sal
		btn_salir.expand_icon = true
		btn_salir.add_theme_constant_override("icon_max_width", 24)
		btn_salir.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_salir.pressed.connect(func(): get_tree().change_scene_to_file("res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"))
	box_derecha.add_child(btn_salir)

# ── 2. PANEL FLOTANTE DE HERRAMIENTAS (ZONA C — IZQUIERDA) ───────────
func _construir_panel_herramientas(padre: Control) -> void:
	_panel_herramientas = PanelContainer.new()
	_panel_herramientas.name = "PanelHerramientasFlotante"
	_panel_herramientas.anchor_left = 0.0
	_panel_herramientas.anchor_right = 0.0
	_panel_herramientas.anchor_top = 0.0
	_panel_herramientas.anchor_bottom = 0.0
	_panel_herramientas.offset_left = 20.0
	_panel_herramientas.offset_top = 100.0
	_panel_herramientas.offset_right = 368.0 # Ancho 348px equilibrado para cuadrícula táctil 3x3 de 100px
	_panel_herramientas.offset_bottom = 458.0
	_panel_herramientas.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_panel_herramientas, COLOR_PANEL, COLOR_BORDE, 18.0, 10.0)
	padre.add_child(_panel_herramientas)

	# Botón de colapso/expansión en el borde derecho
	_btn_colapsar_herramientas = Button.new()
	_btn_colapsar_herramientas.name = "BtnColapsarHerramientas"
	_btn_colapsar_herramientas.text = "❮"
	_btn_colapsar_herramientas.custom_minimum_size = Vector2(28, 60)
	_btn_colapsar_herramientas.position = Vector2(348, 20)
	_estilar_boton(_btn_colapsar_herramientas, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
	_btn_colapsar_herramientas.add_theme_font_size_override("font_size", 18)
	_btn_colapsar_herramientas.pressed.connect(_alternar_colapso_herramientas)
	_panel_herramientas.add_child(_btn_colapsar_herramientas)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel_herramientas.add_child(margin)

	_grid_herramientas = GridContainer.new()
	_grid_herramientas.columns = 3
	_grid_herramientas.add_theme_constant_override("h_separation", 8)
	_grid_herramientas.add_theme_constant_override("v_separation", 8)
	margin.add_child(_grid_herramientas)

func _alternar_colapso_herramientas() -> void:
	_esta_colapsado_herramientas = not _esta_colapsado_herramientas
	_btn_colapsar_herramientas.text = "❯" if _esta_colapsado_herramientas else "❮"
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _esta_colapsado_herramientas:
		tween.tween_property(_panel_herramientas, "offset_left", -340.0, 0.25)
		tween.parallel().tween_property(_panel_herramientas, "offset_right", 20.0, 0.25)
	else:
		tween.tween_property(_panel_herramientas, "offset_left", 20.0, 0.25)
		tween.parallel().tween_property(_panel_herramientas, "offset_right", 368.0, 0.25)

# ── 3. PANEL CONTEXTUAL DE PROPIEDADES (ZONA D — DERECHA) ─────────────
func _construir_panel_propiedades(padre: Control) -> void:
	_panel_propiedades = PanelContainer.new()
	_panel_propiedades.name = "PanelPropiedadesFlotante"
	_panel_propiedades.anchor_left = 1.0
	_panel_propiedades.anchor_right = 1.0
	_panel_propiedades.anchor_top = 0.0
	_panel_propiedades.anchor_bottom = 0.0
	_panel_propiedades.offset_left = -480.0 # Ancho 460px punto medio óptimo para legibilidad y control táctil
	_panel_propiedades.offset_right = -20.0
	_panel_propiedades.offset_top = 100.0
	_panel_propiedades.offset_bottom = 690.0
	_panel_propiedades.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_panel_propiedades, COLOR_PANEL, COLOR_BORDE, 18.0, 16.0)
	padre.add_child(_panel_propiedades)

	var vbox_main := VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 16)
	_panel_propiedades.add_child(vbox_main)

	# Encabezado del Panel Contextual
	var hbox_header := HBoxContainer.new()
	hbox_header.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_header.add_theme_constant_override("separation", 12)
	vbox_main.add_child(hbox_header)

	_ico_prop_header = TextureRect.new()
	_ico_prop_header.custom_minimum_size = Vector2(36, 36)
	_ico_prop_header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ico_prop_header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_header.add_child(_ico_prop_header)

	_lbl_prop_titulo = Label.new()
	_lbl_prop_titulo.text = "Elevar Terreno"
	_lbl_prop_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_prop_titulo.add_theme_font_size_override("font_size", FONT_TITULO_PRINCIPAL) # 30px
	_lbl_prop_titulo.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		_lbl_prop_titulo.add_theme_font_override("font", _fuente_ui)
	hbox_header.add_child(_lbl_prop_titulo)

	# Badge "● Activo"
	var badge_panel := PanelContainer.new()
	var sb_badge := StyleBoxFlat.new()
	sb_badge.bg_color = Color(0.08, 0.22, 0.14, 0.90)
	sb_badge.border_width_left = 1
	sb_badge.border_width_top = 1
	sb_badge.border_width_right = 1
	sb_badge.border_width_bottom = 1
	sb_badge.border_color = COLOR_VERDE_ACTIVO
	sb_badge.corner_radius_top_left = 10
	sb_badge.corner_radius_top_right = 10
	sb_badge.corner_radius_bottom_right = 10
	sb_badge.corner_radius_bottom_left = 10
	sb_badge.content_margin_left = 12
	sb_badge.content_margin_right = 12
	sb_badge.content_margin_top = 4
	sb_badge.content_margin_bottom = 4
	badge_panel.add_theme_stylebox_override("panel", sb_badge)
	hbox_header.add_child(badge_panel)

	_lbl_prop_badge = Label.new()
	_lbl_prop_badge.text = "● Activo"
	_lbl_prop_badge.add_theme_font_size_override("font_size", FONT_BADGE) # 14px
	_lbl_prop_badge.add_theme_color_override("font_color", COLOR_VERDE_ACTIVO)
	badge_panel.add_child(_lbl_prop_badge)

	# Botón colapsar propiedades (⌃ / ⌵)
	_btn_colapsar_propiedades = Button.new()
	_btn_colapsar_propiedades.text = "⌃"
	_btn_colapsar_propiedades.custom_minimum_size = Vector2(36, 36)
	_estilar_boton(_btn_colapsar_propiedades, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
	_btn_colapsar_propiedades.add_theme_font_size_override("font_size", 20)
	_btn_colapsar_propiedades.pressed.connect(_alternar_colapso_propiedades)
	hbox_header.add_child(_btn_colapsar_propiedades)

	# Contenedor dinámico de controles de la herramienta activa
	_box_prop_contenido = VBoxContainer.new()
	_box_prop_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box_prop_contenido.add_theme_constant_override("separation", 16)
	vbox_main.add_child(_box_prop_contenido)

func _alternar_colapso_propiedades() -> void:
	_esta_colapsado_propiedades = not _esta_colapsado_propiedades
	_btn_colapsar_propiedades.text = "⌵" if _esta_colapsado_propiedades else "⌃"
	_box_prop_contenido.visible = not _esta_colapsado_propiedades
	var altura_obj := 64.0 if _esta_colapsado_propiedades else 590.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel_propiedades, "offset_bottom", _panel_propiedades.offset_top + altura_obj, 0.25)

# ── ACTUALIZACIÓN DINÁMICA DEL PANEL CONTEXTUAL ─────────────────────
func _actualizar_panel_contextual(categoria: String, subherramienta: String) -> void:
	_categoria_activa = categoria
	_subherramienta_activa = subherramienta
	_id_item_activo = subherramienta

	for child in _box_prop_contenido.get_children():
		child.queue_free()

	var info_tool = _obtener_metadatos_herramienta(categoria, subherramienta)
	_lbl_prop_titulo.text = info_tool["titulo"]
	var tex_ico = _cargar_icono_svg(info_tool["icono"])
	if tex_ico:
		_ico_prop_header.texture = tex_ico

	match categoria:
		"terreno":
			match subherramienta:
				"elevar", "bajar", "suavizar":
					_construir_vista_esculpido_terreno(subherramienta)
				"aplanar":
					_construir_vista_aplanar_terreno()
				"cesped", "tierra", "roca":
					_construir_vista_pintar_textura(subherramienta)
				"agua", "lago":
					_construir_vista_lago()
				"rio":
					_construir_vista_rio()
				_:
					_construir_vista_esculpido_terreno("elevar")
		"vias":
			_construir_vista_vias_general(subherramienta)
		"ciudad":
			_construir_vista_ciudad()
		"vegetacion":
			_construir_vista_vegetacion()
		"agua":
			if subherramienta == "rio":
				_construir_vista_rio()
			else:
				_construir_vista_lago()
		"spawn":
			_construir_vista_spawn()

	_actualizar_etiqueta_estado()

# ── VISTAS CONTEXTUALES ESPECÍFICAS CON TIPOGRAFÍA ~50PX ─────────────

# A. Esculpido de Terreno (Elevar, Bajar, Suavizar) — Fiel a la Imagen
func _construir_vista_esculpido_terreno(tipo_accion: String) -> void:
	# 1. Radio del pincel
	_crear_fila_slider("Radio del pincel", "ico_pincel_radio", 3.0, 150.0, _radio_pincel, "m", 1.0, func(val):
		_radio_pincel = val
		radio_pincel_cambiado.emit(val)
	)

	# 2. Fuerza
	_crear_fila_slider("Fuerza", "ico_fuerza", 0.05, 1.0, _fuerza_pincel, "", 0.01, func(val):
		_fuerza_pincel = val
		fuerza_pincel_cambiada.emit(val)
	)

	# 3. Perfil de elevación (Suave, Medio, Fuerte)
	var vbox_perfil := VBoxContainer.new()
	vbox_perfil.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(vbox_perfil)

	var hbox_etq := HBoxContainer.new()
	hbox_etq.add_theme_constant_override("separation", 10)
	vbox_perfil.add_child(hbox_etq)

	var ico_perf := TextureRect.new()
	ico_perf.texture = _cargar_icono_svg("ico_perfil")
	ico_perf.custom_minimum_size = Vector2(26, 26)
	ico_perf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico_perf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_etq.add_child(ico_perf)

	var lbl_perf := Label.new()
	lbl_perf.text = "Perfil"
	lbl_perf.add_theme_font_size_override("font_size", FONT_LABEL_SLIDER) # 21px
	lbl_perf.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_perf.add_theme_font_override("font", _fuente_ui)
	hbox_etq.add_child(lbl_perf)

	var hbox_btns_perfil := HBoxContainer.new()
	hbox_btns_perfil.add_theme_constant_override("separation", 10)
	vbox_perfil.add_child(hbox_btns_perfil)

	_dict_botones_perfil.clear()
	var perfiles = [
		{"idx": 0, "nombre": "Suave", "ico": "ico_curva_suave"},
		{"idx": 1, "nombre": "Medio", "ico": "ico_curva_medio"},
		{"idx": 2, "nombre": "Fuerte", "ico": "ico_curva_fuerte"}
	]

	for p in perfiles:
		var btn_p := Button.new()
		btn_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_p.custom_minimum_size = Vector2(0, 76)
		btn_p.text = p["nombre"]
		btn_p.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_p.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn_p.add_theme_font_size_override("font_size", FONT_BOTON_GRID) # 17px
		if _fuente_ui:
			btn_p.add_theme_font_override("font", _fuente_ui)

		var ico_c := _cargar_icono_svg(p["ico"])
		if ico_c:
			btn_p.icon = ico_c
			btn_p.expand_icon = true
			btn_p.add_theme_constant_override("icon_max_width", 44)

		var p_idx: int = p["idx"]
		btn_p.pressed.connect(func(): _seleccionar_perfil(p_idx))
		hbox_btns_perfil.add_child(btn_p)
		_dict_botones_perfil[p_idx] = btn_p

	_actualizar_estilo_botones_perfil()

	# 4. Botones de Acción: Restablecer y Aplicar (Estándar ~50px)
	_crear_botones_accion_inferiores(
		func():
			_radio_pincel = 25.0
			_fuerza_pincel = 0.40
			_perfil_pincel_activo = 0
			_actualizar_slider_val("Radio del pincel", 25.0)
			_actualizar_slider_val("Fuerza", 0.40)
			_seleccionar_perfil(0)
			radio_pincel_cambiado.emit(25.0)
			fuerza_pincel_cambiada.emit(0.40)
			mostrar_notificacion("Parámetros de pincel restablecidos."),
		func():
			accion_colocar_solicitada.emit()
	)

func _seleccionar_perfil(idx: int) -> void:
	_perfil_pincel_activo = idx
	_actualizar_estilo_botones_perfil()
	perfil_pincel_cambiado.emit(idx)

func _actualizar_estilo_botones_perfil() -> void:
	for p_idx in _dict_botones_perfil:
		var btn: Button = _dict_botones_perfil[p_idx]
		var es_activo: bool = (p_idx == _perfil_pincel_activo)
		if es_activo:
			_estilar_boton(btn, COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO, 16.0, 2)
			btn.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_normal_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_hover_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_pressed_color", COLOR_AMARILLO_SEL)
		else:
			_estilar_boton(btn, COLOR_PANEL_SEC, COLOR_BORDE, 16.0, 1)
			btn.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
			btn.add_theme_color_override("icon_normal_color", COLOR_TEXTO_SEC)
			btn.add_theme_color_override("icon_hover_color", COLOR_TEXTO_SEC)
			btn.add_theme_color_override("icon_pressed_color", COLOR_TEXTO_SEC)

# B. Aplanar Terreno
func _construir_vista_aplanar_terreno() -> void:
	_crear_fila_slider("Radio del pincel", "ico_pincel_radio", 3.0, 150.0, _radio_pincel, "m", 1.0, func(val):
		_radio_pincel = val
		radio_pincel_cambiado.emit(val)
	)
	_crear_fila_slider("Fuerza", "ico_fuerza", 0.05, 1.0, _fuerza_pincel, "", 0.01, func(val):
		_fuerza_pincel = val
		fuerza_pincel_cambiada.emit(val)
	)
	_crear_fila_slider("Altura meta", "act_nivelar", -20.0, 80.0, _altura_objetivo_terreno, "m", 0.5, func(val):
		_altura_objetivo_terreno = val
	)
	_crear_botones_accion_inferiores(
		func():
			_radio_pincel = 25.0
			_fuerza_pincel = 0.50
			_altura_objetivo_terreno = 10.0
			_actualizar_slider_val("Radio del pincel", 25.0)
			_actualizar_slider_val("Fuerza", 0.50)
			_actualizar_slider_val("Altura meta", 10.0),
		func():
			accion_colocar_solicitada.emit()
	)

# C. Pintar Textura
func _construir_vista_pintar_textura(id_textura: String) -> void:
	_crear_fila_slider("Radio del pincel", "ico_pincel_radio", 3.0, 150.0, _radio_pincel, "m", 1.0, func(val):
		_radio_pincel = val
		radio_pincel_cambiado.emit(val)
	)
	_crear_fila_slider("Opacidad de pintura", "ico_fuerza", 0.1, 1.0, _opacidad_textura, "", 0.05, func(val):
		_opacidad_textura = val
		fuerza_pincel_cambiada.emit(val)
	)
	_crear_botones_accion_inferiores(
		func():
			_radio_pincel = 30.0
			_opacidad_textura = 0.85
			_actualizar_slider_val("Radio del pincel", 30.0)
			_actualizar_slider_val("Opacidad de pintura", 0.85),
		func():
			accion_colocar_solicitada.emit()
	)

# D. Lago / Embalse
func _construir_vista_lago() -> void:
	_crear_fila_slider("Radio del lago", "ico_pincel_radio", 6.0, 80.0, _radio_lago, "m", 1.0, func(val):
		_radio_lago = val
	)
	_crear_fila_slider("Profundidad", "ico_fuerza", 1.0, 15.0, _profundidad_lago, "m", 0.5, func(val):
		_profundidad_lago = val
	)
	_crear_botones_accion_inferiores(
		func():
			_radio_lago = 24.0
			_profundidad_lago = 3.5
			_actualizar_slider_val("Radio del lago", 24.0)
			_actualizar_slider_val("Profundidad", 3.5),
		func():
			accion_colocar_solicitada.emit(),
		"Restablecer",
		"Crear Lago Aquí"
	)

# E. Río / Quebrada
func _construir_vista_rio() -> void:
	_crear_fila_slider("Ancho de calzada río", "ico_pincel_radio", 3.0, 30.0, _ancho_rio, "m", 0.5, func(val):
		_ancho_rio = val
	)

	var hbox_acts := HBoxContainer.new()
	hbox_acts.add_theme_constant_override("separation", 14)
	_box_prop_contenido.add_child(hbox_acts)

	var btn_limpiar := Button.new()
	btn_limpiar.text = "Limpiar trazo"
	btn_limpiar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_limpiar.custom_minimum_size = Vector2(0, 52)
	btn_limpiar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_limpiar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_limpiar.add_theme_font_override("font", _fuente_ui)
	btn_limpiar.pressed.connect(func():
		mostrar_notificacion("Trazo de río reiniciado.")
	)
	hbox_acts.add_child(btn_limpiar)

	var btn_fin := Button.new()
	btn_fin.text = "Finalizar río"
	btn_fin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_fin.custom_minimum_size = Vector2(0, 52)
	btn_fin.add_theme_font_size_override("font_size", FONT_BOTON_ACCION) # 24px
	_estilar_boton(btn_fin, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	btn_fin.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	if _fuente_ui:
		btn_fin.add_theme_font_override("font", _fuente_ui)
	btn_fin.pressed.connect(func():
		accion_colocar_solicitada.emit()
	)
	hbox_acts.add_child(btn_fin)

# F. Vías General
func _construir_vista_vias_general(tipo_via: String) -> void:
	var lbl_desc := Label.new()
	lbl_desc.text = "Toca o arrastra sobre el terreno para crear tramos viales continuos con peralte y rasante inteligente."
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", FONT_TEXTO_INFO) # 18px
	lbl_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_desc.add_theme_font_override("font", _fuente_ui)
	_box_prop_contenido.add_child(lbl_desc)

	var vbox_acciones := VBoxContainer.new()
	vbox_acciones.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(vbox_acciones)

	var btn_terminar := Button.new()
	btn_terminar.text = "✓ Finalizar Tramo de Vía"
	btn_terminar.custom_minimum_size = Vector2(0, 54)
	btn_terminar.add_theme_font_size_override("font_size", FONT_BOTON_ACCION) # 24px
	_estilar_boton(btn_terminar, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	btn_terminar.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	if _fuente_ui:
		btn_terminar.add_theme_font_override("font", _fuente_ui)
	btn_terminar.pressed.connect(func(): terminar_tramo_via_solicitado.emit())
	vbox_acciones.add_child(btn_terminar)

	var btn_conectar := Button.new()
	btn_conectar.text = "☍ Conectar Tramos Viales"
	btn_conectar.custom_minimum_size = Vector2(0, 50)
	btn_conectar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_conectar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_conectar.add_theme_font_override("font", _fuente_ui)
	btn_conectar.pressed.connect(func(): conectar_vias_solicitado.emit())
	vbox_acciones.add_child(btn_conectar)

	var btn_nivelar := Button.new()
	btn_nivelar.text = "⊞ Nivelar Terreno Bajo Carreteras"
	btn_nivelar.custom_minimum_size = Vector2(0, 50)
	btn_nivelar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_nivelar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_nivelar.add_theme_font_override("font", _fuente_ui)
	btn_nivelar.pressed.connect(func(): nivelar_terreno_vias_solicitado.emit())
	vbox_acciones.add_child(btn_nivelar)

	var btn_deshacer_pto := Button.new()
	btn_deshacer_pto.text = "↶ Deshacer Último Punto"
	btn_deshacer_pto.custom_minimum_size = Vector2(0, 50)
	btn_deshacer_pto.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_deshacer_pto, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_deshacer_pto.add_theme_font_override("font", _fuente_ui)
	btn_deshacer_pto.pressed.connect(func(): deshacer_punto_via_solicitado.emit())
	vbox_acciones.add_child(btn_deshacer_pto)

# G. Ciudad (Catálogo y Opciones)
func _construir_vista_ciudad() -> void:
	var hbox_filtros := HBoxContainer.new()
	hbox_filtros.add_theme_constant_override("separation", 8)
	_box_prop_contenido.add_child(hbox_filtros)

	var secciones = ["Residencial", "Comercial", "Institucional", "Histórico"]
	for s in secciones:
		var btn_s := Button.new()
		btn_s.text = s
		btn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_s.custom_minimum_size = Vector2(0, 44)
		btn_s.add_theme_font_size_override("font_size", 17)
		if _fuente_ui:
			btn_s.add_theme_font_override("font", _fuente_ui)
		var es_act := (_seccion_biblioteca_activa.findn(s) != -1)
		_estilar_boton(btn_s, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if es_act else COLOR_BORDE, 10.0, 2 if es_act else 1)
		btn_s.pressed.connect(func():
			_seccion_biblioteca_activa = "01_" + s
			_construir_vista_ciudad()
		)
		hbox_filtros.add_child(btn_s)

	# Grid de tarjetas de modelos
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box_prop_contenido.add_child(scroll)

	var grid_modelos := GridContainer.new()
	grid_modelos.columns = 2
	grid_modelos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_modelos.add_theme_constant_override("h_separation", 10)
	grid_modelos.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid_modelos)

	CargadorBiblioteca.inicializar()
	var items = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", _seccion_biblioteca_activa, "todos")
	if items.is_empty():
		items = CargadorBiblioteca.obtener_items_por_categoria("01_Edificaciones")

	for it in items:
		var it_id: String = it.get("id", "")
		var it_nom: String = it.get("nombre", it_id)
		var btn_item := Button.new()
		btn_item.text = it_nom
		btn_item.custom_minimum_size = Vector2(0, 50)
		btn_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_item.add_theme_font_size_override("font_size", 17)
		if _fuente_ui:
			btn_item.add_theme_font_override("font", _fuente_ui)
		var es_sel := (_id_item_activo == it_id)
		_estilar_boton(btn_item, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if es_sel else COLOR_BORDE, 10.0, 2 if es_sel else 1)
		if es_sel:
			btn_item.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
		btn_item.pressed.connect(func():
			_id_item_activo = it_id
			subherramienta_seleccionada.emit(it_id)
			_actualizar_panel_contextual("ciudad", it_id)
		)
		grid_modelos.add_child(btn_item)

	_crear_botones_accion_inferiores(
		func():
			_modo_demolicion_activo = not _modo_demolicion_activo
			demolicion_alternada.emit(_modo_demolicion_activo)
			_actualizar_panel_contextual("ciudad", _subherramienta_activa),
		func():
			accion_colocar_solicitada.emit(),
		"Demoler" if not _modo_demolicion_activo else "Modo Colocar",
		"Colocar Objeto"
	)

# H. Vegetación
func _construir_vista_vegetacion() -> void:
	var hbox_modo := HBoxContainer.new()
	hbox_modo.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_modo)

	var btn_ind := Button.new()
	btn_ind.text = "Árbol Individual"
	btn_ind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ind.custom_minimum_size = Vector2(0, 50)
	btn_ind.add_theme_font_size_override("font_size", 18)
	if _fuente_ui:
		btn_ind.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_ind, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if not _modo_dispersion_activo else COLOR_BORDE, 10.0)
	btn_ind.pressed.connect(func():
		_modo_dispersion_activo = false
		modo_dispersion_vegetacion_alternado.emit(false)
		_construir_vista_vegetacion()
	)
	hbox_modo.add_child(btn_ind)

	var btn_disp := Button.new()
	btn_disp.text = "Pincel de Bosque"
	btn_disp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_disp.custom_minimum_size = Vector2(0, 50)
	btn_disp.add_theme_font_size_override("font_size", 18)
	if _fuente_ui:
		btn_disp.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_disp, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _modo_dispersion_activo else COLOR_BORDE, 10.0)
	btn_disp.pressed.connect(func():
		_modo_dispersion_activo = true
		modo_dispersion_vegetacion_alternado.emit(true)
		_construir_vista_vegetacion()
	)
	hbox_modo.add_child(btn_disp)

	if _modo_dispersion_activo:
		_crear_fila_slider("Radio dispersión", "ico_pincel_radio", 5.0, 60.0, _radio_dispersion, "m", 1.0, func(val):
			_radio_dispersion = val
			radio_dispersion_vegetacion_cambiado.emit(val)
		)
		_crear_fila_slider("Densidad de árboles", "ico_fuerza", 4.0, 40.0, float(_densidad_dispersion), "", 1.0, func(val):
			_densidad_dispersion = int(val)
			densidad_dispersion_vegetacion_cambiada.emit(int(val))
		)

	_crear_botones_accion_inferiores(
		func():
			borrar_dispersion_vegetacion_solicitado.emit(),
		func():
			accion_colocar_solicitada.emit(),
		"Borrar en radio",
		"Dispersar Árboles" if _modo_dispersion_activo else "Colocar Árbol"
	)

# I. Spawn
func _construir_vista_spawn() -> void:
	var lbl_info := Label.new()
	lbl_info.text = "Selecciona el punto y orientación de inicio para vehículos o peatones al comenzar la simulación."
	lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_info.add_theme_font_size_override("font_size", FONT_TEXTO_INFO) # 18px
	lbl_info.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_info.add_theme_font_override("font", _fuente_ui)
	_box_prop_contenido.add_child(lbl_info)

	var hbox_spw := HBoxContainer.new()
	hbox_spw.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_spw)

	var btn_tipo := Button.new()
	btn_tipo.text = "🔄 Alternar Tipo de Spawn"
	btn_tipo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tipo.custom_minimum_size = Vector2(0, 52)
	btn_tipo.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_tipo, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_tipo.add_theme_font_override("font", _fuente_ui)
	btn_tipo.pressed.connect(func(): alternar_modo_spawn_solicitado.emit())
	hbox_spw.add_child(btn_tipo)

	_crear_botones_accion_inferiores(
		func(): rotar_objeto_solicitado.emit(),
		func(): accion_colocar_solicitada.emit(),
		"Rotar Spawn",
		"Fijar Spawn Aquí"
	)

# ── HELPER DE SLIDERS MODERNOS CON READOUT EN VIVO ───────────────────
func _crear_fila_slider(titulo: String, nombre_icono: String, min_val: float, max_val: float, val_defecto: float, sufijo: String, paso: float, callback: Callable) -> void:
	var vbox_item := VBoxContainer.new()
	vbox_item.add_theme_constant_override("separation", 8)
	_box_prop_contenido.add_child(vbox_item)

	var hbox_top := HBoxContainer.new()
	hbox_top.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_top.add_theme_constant_override("separation", 10)
	vbox_item.add_child(hbox_top)

	var tex_ico := _cargar_icono_svg(nombre_icono)
	if tex_ico:
		var rect_ico := TextureRect.new()
		rect_ico.texture = tex_ico
		rect_ico.custom_minimum_size = Vector2(28, 28)
		rect_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox_top.add_child(rect_ico)

	var lbl_tit := Label.new()
	lbl_tit.text = titulo
	lbl_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_tit.add_theme_font_size_override("font_size", FONT_LABEL_SLIDER) # 21px
	lbl_tit.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_tit.add_theme_font_override("font", _fuente_ui)
	hbox_top.add_child(lbl_tit)

	# Readout en badge oscuro como en la imagen de referencia ("25 m", "0.40")
	var badge_readout := PanelContainer.new()
	var sb_readout := StyleBoxFlat.new()
	sb_readout.bg_color = COLOR_FONDO_PRINCIPAL
	sb_readout.border_width_left = 1
	sb_readout.border_width_top = 1
	sb_readout.border_width_right = 1
	sb_readout.border_width_bottom = 1
	sb_readout.border_color = COLOR_BORDE
	sb_readout.corner_radius_top_left = 8
	sb_readout.corner_radius_top_right = 8
	sb_readout.corner_radius_bottom_right = 8
	sb_readout.corner_radius_bottom_left = 8
	sb_readout.content_margin_left = 14
	sb_readout.content_margin_right = 14
	sb_readout.content_margin_top = 4
	sb_readout.content_margin_bottom = 4
	badge_readout.add_theme_stylebox_override("panel", sb_readout)
	hbox_top.add_child(badge_readout)

	var lbl_val := Label.new()
	lbl_val.text = _formatear_valor_readout(val_defecto, sufijo, paso)
	lbl_val.add_theme_font_size_override("font_size", FONT_READOUT_VALOR) # 21px
	lbl_val.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_val.add_theme_font_override("font", _fuente_ui)
	badge_readout.add_child(lbl_val)
	_dict_readouts[titulo] = lbl_val

	# Slider con estilo moderno táctil
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = paso
	slider.value = val_defecto
	slider.custom_minimum_size = Vector2(0, 32)
	_estilar_slider_moderno(slider)

	slider.value_changed.connect(func(nuevo_v):
		lbl_val.text = _formatear_valor_readout(nuevo_v, sufijo, paso)
		callback.call(nuevo_v)
	)
	vbox_item.add_child(slider)
	_dict_sliders[titulo] = slider

func _formatear_valor_readout(val: float, sufijo: String, paso: float) -> String:
	var txt := ""
	if paso >= 1.0:
		txt = "%d" % int(round(val))
	elif paso >= 0.1:
		txt = "%.1f" % val
	else:
		txt = "%.2f" % val
	if sufijo != "":
		txt += " " + sufijo
	return txt

func _actualizar_slider_val(titulo: String, nuevo_val: float) -> void:
	if _dict_sliders.has(titulo):
		_dict_sliders[titulo].value = nuevo_val

# ── BOTONES DE ACCIÓN INFERIORES ("Restablecer" y "Aplicar") ──────────
func _crear_botones_accion_inferiores(callback_reset: Callable, callback_aplicar: Callable, texto_reset: String = "Restablecer", texto_aplicar: String = "Aplicar") -> void:
	var hbox_acts := HBoxContainer.new()
	hbox_acts.add_theme_constant_override("separation", 12)
	_box_prop_contenido.add_child(hbox_acts)

	# Botón Restablecer
	_btn_prop_restablecer = Button.new()
	_btn_prop_restablecer.text = " " + texto_reset
	_btn_prop_restablecer.custom_minimum_size = Vector2(160, 56)
	_estilar_boton(_btn_prop_restablecer, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	_btn_prop_restablecer.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	if _fuente_ui:
		_btn_prop_restablecer.add_theme_font_override("font", _fuente_ui)
	var ico_rst := _cargar_icono_svg("act_restablecer")
	if ico_rst:
		_btn_prop_restablecer.icon = ico_rst
		_btn_prop_restablecer.expand_icon = true
		_btn_prop_restablecer.add_theme_constant_override("icon_max_width", 24)
	_btn_prop_restablecer.pressed.connect(callback_reset)
	hbox_acts.add_child(_btn_prop_restablecer)

	# Botón Aplicar (Amarillo Dorado)
	_btn_prop_aplicar = Button.new()
	_btn_prop_aplicar.text = " " + texto_aplicar
	_btn_prop_aplicar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_prop_aplicar.custom_minimum_size = Vector2(0, 56)
	_estilar_boton(_btn_prop_aplicar, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	_btn_prop_aplicar.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	_btn_prop_aplicar.add_theme_font_size_override("font_size", FONT_BOTON_ACCION) # 24px
	if _fuente_ui:
		_btn_prop_aplicar.add_theme_font_override("font", _fuente_ui)
	var ico_apl := _cargar_icono_svg("act_aplicar")
	if ico_apl:
		_btn_prop_aplicar.icon = ico_apl
		_btn_prop_aplicar.expand_icon = true
		_btn_prop_aplicar.add_theme_constant_override("icon_max_width", 26)

	_btn_colocar_grande = _btn_prop_aplicar

	_btn_prop_aplicar.pressed.connect(func():
		var tween = create_tween()
		tween.tween_property(_btn_prop_aplicar, "scale", Vector2(0.96, 0.96), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_btn_prop_aplicar, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		callback_aplicar.call()
	)
	hbox_acts.add_child(_btn_prop_aplicar)

# ── LLENADO DE LA CUADRÍCULA DE HERRAMIENTAS (ZONA C) ─────────────────
func _refrescar_grid_herramientas(cat_id: String) -> void:
	for child in _grid_herramientas.get_children():
		child.queue_free()
	_dict_botones_herramientas.clear()

	var lista_tools: Array = []
	match cat_id:
		"terreno":
			lista_tools = [
				{"id": "elevar", "nombre": "Elevar", "ico": "terreno_elevar"},
				{"id": "bajar", "nombre": "Bajar", "ico": "terreno_bajar"},
				{"id": "aplanar", "nombre": "Aplanar", "ico": "terreno_aplanar"},
				{"id": "suavizar", "nombre": "Suavizar", "ico": "terreno_suavizar"},
				{"id": "cesped", "nombre": "Césped", "ico": "terreno_cesped"},
				{"id": "tierra", "nombre": "Tierra", "ico": "terreno_tierra"},
				{"id": "roca", "nombre": "Roca", "ico": "terreno_roca"},
				{"id": "agua", "nombre": "Agua", "ico": "terreno_agua"},
				{"id": "rio", "nombre": "Río", "ico": "terreno_rio"}
			]
		"vias":
			lista_tools = [
				{"id": "calle_2", "nombre": "Calle 2C", "ico": "via_calle_2"},
				{"id": "avenida_4", "nombre": "Avenida 4C", "ico": "via_avenida_4"},
				{"id": "autopista_6", "nombre": "Autopista", "ico": "via_autopista_6"},
				{"id": "trocha", "nombre": "Trocha", "ico": "via_calle_2"},
				{"id": "conectar", "nombre": "Conectar", "ico": "via_conectar"},
				{"id": "cruce_t", "nombre": "Cruce en T", "ico": "via_cruce_t"},
				{"id": "cruce_4", "nombre": "Cruce Cruz", "ico": "via_cruce_4"},
				{"id": "equipamiento", "nombre": "Equipar", "ico": "via_equipamiento"},
				{"id": "nivelar", "nombre": "Nivelar", "ico": "act_nivelar"}
			]
		"ciudad":
			lista_tools = [
				{"id": "res", "nombre": "Viviendas", "ico": "cat_ciudad"},
				{"id": "com", "nombre": "Comercio", "ico": "cat_ciudad"},
				{"id": "inst", "nombre": "Público", "ico": "cat_ciudad"},
				{"id": "hist", "nombre": "Patrimonio", "ico": "cat_ciudad"},
				{"id": "ind", "nombre": "Industria", "ico": "cat_ciudad"},
				{"id": "rotar", "nombre": "Rotar", "ico": "act_rotar"},
				{"id": "demoler", "nombre": "Demoler", "ico": "act_demoler"},
				{"id": "mover", "nombre": "Mover", "ico": "act_colocar"},
				{"id": "grid", "nombre": "Cuadrícula", "ico": "act_grid"}
			]
		"vegetacion":
			lista_tools = [
				{"id": "arbol_sabanero", "nombre": "Sabanero", "ico": "cat_vegetacion"},
				{"id": "arbol_roble_3d", "nombre": "Roble", "ico": "cat_vegetacion"},
				{"id": "guayacan", "nombre": "Guayacán", "ico": "cat_vegetacion"},
				{"id": "palma_cera", "nombre": "Palma Cera", "ico": "cat_vegetacion"},
				{"id": "dispersion", "nombre": "Pincel", "ico": "act_colocar"},
				{"id": "borrar", "nombre": "Borrar", "ico": "act_demoler"},
				{"id": "rotar", "nombre": "Rotar", "ico": "act_rotar"},
				{"id": "snap", "nombre": "Snap", "ico": "act_grid"},
				{"id": "catalogo", "nombre": "Especies", "ico": "cat_vegetacion"}
			]
		"agua":
			lista_tools = [
				{"id": "lago", "nombre": "Lago", "ico": "terreno_agua"},
				{"id": "rio", "nombre": "Río", "ico": "terreno_rio"},
				{"id": "cuenca", "nombre": "Cuenca", "ico": "terreno_aplanar"},
				{"id": "nivel", "nombre": "Nivel", "ico": "act_nivelar"},
				{"id": "limpiar", "nombre": "Limpiar", "ico": "act_demoler"}
			]
		"spawn":
			lista_tools = [
				{"id": "vehiculo", "nombre": "Vehículo", "ico": "cat_spawn"},
				{"id": "jugador", "nombre": "Jugador", "ico": "cat_spawn"},
				{"id": "rotar", "nombre": "Rotar", "ico": "act_rotar"}
			]

	for t in lista_tools:
		var btn_t := Button.new()
		btn_t.custom_minimum_size = Vector2(100, 100)
		btn_t.text = t["nombre"]
		btn_t.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_t.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn_t.add_theme_font_size_override("font_size", FONT_BOTON_GRID) # 17px
		if _fuente_ui:
			btn_t.add_theme_font_override("font", _fuente_ui)

		var ico := _cargar_icono_svg(t["ico"])
		if ico:
			btn_t.icon = ico
			btn_t.expand_icon = true
			btn_t.add_theme_constant_override("icon_max_width", 42)

		var tool_id: String = t["id"]
		btn_t.pressed.connect(func():
			_seleccionar_subherramienta(tool_id)
		)
		_grid_herramientas.add_child(btn_t)
		_dict_botones_herramientas[tool_id] = btn_t

	_actualizar_estilo_botones_herramientas()

func _seleccionar_subherramienta(tool_id: String) -> void:
	_subherramienta_activa = tool_id
	_id_item_activo = tool_id

	match tool_id:
		"rotar":
			rotar_objeto_solicitado.emit()
			return
		"demoler":
			_modo_demolicion_activo = not _modo_demolicion_activo
			demolicion_alternada.emit(_modo_demolicion_activo)
			_actualizar_panel_contextual(_categoria_activa, tool_id)
			return
		"grid", "snap":
			_snap_grid_activo = not _snap_grid_activo
			snap_cuadricula_alternado.emit(_snap_grid_activo)
			mostrar_notificacion("Snap a cuadrícula: " + ("ACTIVADO" if _snap_grid_activo else "DESACTIVADO"))
			return
		"conectar":
			conectar_vias_solicitado.emit()
			return
		"nivelar":
			nivelar_terreno_vias_solicitado.emit()
			return
		"dispersion":
			_modo_dispersion_activo = not _modo_dispersion_activo
			modo_dispersion_vegetacion_alternado.emit(_modo_dispersion_activo)
			_actualizar_panel_contextual(_categoria_activa, tool_id)
			return
		"borrar":
			borrar_dispersion_vegetacion_solicitado.emit()
			return

	_actualizar_estilo_botones_herramientas()
	subherramienta_seleccionada.emit(tool_id)
	_actualizar_panel_contextual(_categoria_activa, tool_id)

func _actualizar_estilo_botones_herramientas() -> void:
	for t_id in _dict_botones_herramientas:
		var btn: Button = _dict_botones_herramientas[t_id]
		var es_activo: bool = (t_id == _subherramienta_activa)
		if es_activo:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.20, 0.18, 0.12, 0.95)
			sb.border_width_left = 3
			sb.border_width_top = 3
			sb.border_width_right = 3
			sb.border_width_bottom = 3
			sb.border_color = COLOR_BORDE_ACTIVO
			sb.corner_radius_top_left = 16
			sb.corner_radius_top_right = 16
			sb.corner_radius_bottom_right = 16
			sb.corner_radius_bottom_left = 16
			sb.shadow_color = Color(1.0, 0.77, 0.18, 0.35)
			sb.shadow_size = 10
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_stylebox_override("pressed", sb)
			btn.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_normal_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_hover_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_pressed_color", COLOR_AMARILLO_SEL)
		else:
			_estilar_boton(btn, COLOR_PANEL_SEC, COLOR_BORDE, 16.0, 1)
			btn.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
			btn.add_theme_color_override("icon_normal_color", COLOR_TEXTO_PRI)
			btn.add_theme_color_override("icon_hover_color", COLOR_TEXTO_PRI)
			btn.add_theme_color_override("icon_pressed_color", COLOR_TEXTO_PRI)

# ── 4. HUD INFERIOR IZQUIERDO: BRÚJULA / MINIMAPA Y TELEMETRÍA ───────
func _construir_hud_inferior_izquierdo(padre: Control) -> void:
	_hud_inferior_izquierdo = HBoxContainer.new()
	_hud_inferior_izquierdo.name = "HUDInferiorIzquierdo"
	_hud_inferior_izquierdo.anchor_left = 0.0
	_hud_inferior_izquierdo.anchor_right = 0.0
	_hud_inferior_izquierdo.anchor_top = 1.0
	_hud_inferior_izquierdo.anchor_bottom = 1.0
	_hud_inferior_izquierdo.offset_left = 20.0
	_hud_inferior_izquierdo.offset_right = 340.0
	_hud_inferior_izquierdo.offset_top = -116.0
	_hud_inferior_izquierdo.offset_bottom = -20.0
	_hud_inferior_izquierdo.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_inferior_izquierdo.add_theme_constant_override("separation", 12)
	padre.add_child(_hud_inferior_izquierdo)

	# Widget de Brújula circular
	_widget_brujula = Control.new()
	_widget_brujula.name = "WidgetBrujula"
	_widget_brujula.custom_minimum_size = Vector2(88, 88)
	_widget_brujula.draw.connect(_dibujar_brujula_fallback)
	_hud_inferior_izquierdo.add_child(_widget_brujula)

	# Card de Telemetría
	_panel_telemetria = PanelContainer.new()
	_panel_telemetria.custom_minimum_size = Vector2(170, 68)
	_estilar_panel_glass(_panel_telemetria, COLOR_PANEL, COLOR_BORDE, 14.0, 8.0)
	_hud_inferior_izquierdo.add_child(_panel_telemetria)

	var vbox_tel := VBoxContainer.new()
	vbox_tel.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_tel.add_theme_constant_override("separation", 2)
	_panel_telemetria.add_child(vbox_tel)

	_lbl_fps = Label.new()
	_lbl_fps.text = "FPS: 60"
	_lbl_fps.add_theme_font_size_override("font_size", FONT_ESTADO_HUD) # 18px
	_lbl_fps.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		_lbl_fps.add_theme_font_override("font", _fuente_ui)
	vbox_tel.add_child(_lbl_fps)

	var hbox_map := HBoxContainer.new()
	hbox_map.add_theme_constant_override("separation", 6)
	vbox_tel.add_child(hbox_map)

	var lbl_ico_net := Label.new()
	lbl_ico_net.text = "📶"
	lbl_ico_net.add_theme_font_size_override("font_size", 15)
	lbl_ico_net.add_theme_color_override("font_color", COLOR_VERDE_ACTIVO)
	hbox_map.add_child(lbl_ico_net)

	_lbl_mapa_res = Label.new()
	_lbl_mapa_res.text = "Mapa: 1024 x 1024"
	_lbl_mapa_res.add_theme_font_size_override("font_size", 15)
	_lbl_mapa_res.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		_lbl_mapa_res.add_theme_font_override("font", _fuente_ui)
	hbox_map.add_child(_lbl_mapa_res)

func _dibujar_brujula_fallback() -> void:
	var r := 40.0
	var c := Vector2(44, 44)
	_widget_brujula.draw_circle(c, r, COLOR_PANEL)
	_widget_brujula.draw_arc(c, r, 0.0, TAU, 36, COLOR_BORDE, 2.0)
	_widget_brujula.draw_arc(c, r * 0.72, 0.0, TAU, 24, Color(COLOR_BORDE.r, COLOR_BORDE.g, COLOR_BORDE.b, 0.4), 1.2)
	_widget_brujula.draw_string(ThemeDB.fallback_font, c + Vector2(-6, -r + 20), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, COLOR_TEXTO_PRI)

	var cam := get_viewport().get_camera_3d()
	var yaw: float = cam.global_rotation.y if cam else 0.0
	var p_top := c + Vector2(0, -22).rotated(-yaw)
	var p_der := c + Vector2(8, 12).rotated(-yaw)
	var p_not := c + Vector2(0, 6).rotated(-yaw)
	var p_izq := c + Vector2(-8, 12).rotated(-yaw)
	_widget_brujula.draw_colored_polygon(PackedVector2Array([p_top, p_der, p_not, p_izq]), COLOR_TEXTO_PRI)

# ── 5. HUD INFERIOR DERECHO: BARRA DE ESTADO CAPSULE ─────────────────
func _construir_hud_barra_estado(padre: Control) -> void:
	_hud_barra_estado = PanelContainer.new()
	_hud_barra_estado.name = "HUDBarraEstado"
	_hud_barra_estado.anchor_left = 1.0
	_hud_barra_estado.anchor_right = 1.0
	_hud_barra_estado.anchor_top = 1.0
	_hud_barra_estado.anchor_bottom = 1.0
	_hud_barra_estado.offset_left = -480.0
	_hud_barra_estado.offset_right = -20.0
	_hud_barra_estado.offset_top = -68.0
	_hud_barra_estado.offset_bottom = -20.0 # Altura 48px
	_hud_barra_estado.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_hud_barra_estado, COLOR_PANEL, COLOR_BORDE, 14.0, 8.0)
	padre.add_child(_hud_barra_estado)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	_hud_barra_estado.add_child(hbox)

	var lbl_i := Label.new()
	lbl_i.text = "ℹ"
	lbl_i.add_theme_font_size_override("font_size", 20)
	lbl_i.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	hbox.add_child(lbl_i)

	_lbl_modo_estado = Label.new()
	_lbl_modo_estado.text = "Modo: Edición de Terreno"
	_lbl_modo_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_modo_estado.add_theme_font_size_override("font_size", FONT_ESTADO_HUD) # 18px
	_lbl_modo_estado.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		_lbl_modo_estado.add_theme_font_override("font", _fuente_ui)
	hbox.add_child(_lbl_modo_estado)

	var sep := VSeparator.new()
	hbox.add_child(sep)

	var lbl_capas := Label.new()
	lbl_capas.text = "≡ Capas: 1"
	lbl_capas.add_theme_font_size_override("font_size", 15)
	lbl_capas.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_capas.add_theme_font_override("font", _fuente_ui)
	hbox.add_child(lbl_capas)

func _actualizar_etiqueta_estado() -> void:
	if not _lbl_modo_estado:
		return
	var nom := _subherramienta_activa.capitalize()
	match _categoria_activa:
		"terreno":
			_lbl_modo_estado.text = "Modo: Terreno (%s)" % nom
		"vias":
			_lbl_modo_estado.text = "Modo: Trazado Vías (%s)" % nom
		"ciudad":
			_lbl_modo_estado.text = "Modo: Ciudad (%s)" % nom
		"vegetacion":
			_lbl_modo_estado.text = "Modo: Naturaleza (%s)" % nom
		"agua":
			_lbl_modo_estado.text = "Modo: Agua (%s)" % nom
		"spawn":
			_lbl_modo_estado.text = "Modo: Spawn"

# ── 6. POPUP DE SISTEMA Y CONFIGURACIÓN (⚙) ───────────────────────────
func _construir_popup_sistema(padre: Control) -> void:
	_popup_sistema = PanelContainer.new()
	_popup_sistema.name = "PopupSistema"
	_popup_sistema.visible = false
	_popup_sistema.anchor_left = 1.0
	_popup_sistema.anchor_right = 1.0
	_popup_sistema.anchor_top = 0.0
	_popup_sistema.anchor_bottom = 0.0
	_popup_sistema.offset_left = -480.0
	_popup_sistema.offset_right = -20.0
	_popup_sistema.offset_top = 100.0
	_popup_sistema.offset_bottom = 500.0
	_popup_sistema.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_popup_sistema, COLOR_PANEL, COLOR_BORDE, 16.0, 14.0)
	padre.add_child(_popup_sistema)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_popup_sistema.add_child(vbox)

	var lbl_pop_tit := Label.new()
	lbl_pop_tit.text = "OPCIONES Y ENTORNO"
	lbl_pop_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pop_tit.add_theme_font_size_override("font_size", FONT_TITULO_SUB) # 26px
	lbl_pop_tit.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui:
		lbl_pop_tit.add_theme_font_override("font", _fuente_ui)
	vbox.add_child(lbl_pop_tit)

	# Ciclo solar
	var btn_solar := Button.new()
	btn_solar.text = "☀️ Hora Solar: Mediodía"
	btn_solar.custom_minimum_size = Vector2(0, 48)
	btn_solar.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_solar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_solar.add_theme_font_override("font", _fuente_ui)
	btn_solar.pressed.connect(func():
		_hora_solar_idx = (_hora_solar_idx + 1) % 4
		var nombres = ["🌅 Hora: Amanecer (06:00)", "☀️ Hora: Mediodía (12:00)", "🌇 Hora: Atardecer (18:00)", "🌙 Hora: Noche (22:00)"]
		btn_solar.text = nombres[_hora_solar_idx]
		hora_dia_cambiada.emit(_hora_solar_idx)
	)
	vbox.add_child(btn_solar)

	# Grid Snap y Vista Cenital
	var hbox_toggles := HBoxContainer.new()
	hbox_toggles.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox_toggles)

	var btn_snap := Button.new()
	btn_snap.text = "⊞ Cuadrícula"
	btn_snap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_snap.custom_minimum_size = Vector2(0, 48)
	btn_snap.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_snap, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_snap.add_theme_font_override("font", _fuente_ui)
	btn_snap.pressed.connect(func():
		_snap_grid_activo = not _snap_grid_activo
		snap_cuadricula_alternado.emit(_snap_grid_activo)
		_estilar_boton(btn_snap, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _snap_grid_activo else COLOR_BORDE, 12.0)
	)
	hbox_toggles.add_child(btn_snap)

	var btn_cen := Button.new()
	btn_cen.text = "🎥 Vista 2D/3D"
	btn_cen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cen.custom_minimum_size = Vector2(0, 48)
	btn_cen.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_cen, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_cen.add_theme_font_override("font", _fuente_ui)
	btn_cen.pressed.connect(func():
		_modo_cenital_activo = not _modo_cenital_activo
		camara_cenital_solicitada.emit()
		_estilar_boton(btn_cen, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _modo_cenital_activo else COLOR_BORDE, 12.0)
	)
	hbox_toggles.add_child(btn_cen)

	# Guardar y Cargar
	var hbox_arch := HBoxContainer.new()
	hbox_arch.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox_arch)

	var btn_guardar := Button.new()
	btn_guardar.text = "💾 Guardar Mapa"
	btn_guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_guardar.custom_minimum_size = Vector2(0, 48)
	btn_guardar.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_guardar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_guardar.add_theme_font_override("font", _fuente_ui)
	btn_guardar.pressed.connect(func():
		_popup_sistema.visible = false
		guardar_mapa_solicitado.emit()
	)
	hbox_arch.add_child(btn_guardar)

	var btn_cargar := Button.new()
	btn_cargar.text = "📂 Cargar Mapa"
	btn_cargar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cargar.custom_minimum_size = Vector2(0, 48)
	btn_cargar.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_cargar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_cargar.add_theme_font_override("font", _fuente_ui)
	btn_cargar.pressed.connect(func():
		_popup_sistema.visible = false
		cargar_mapa_solicitado.emit()
	)
	hbox_arch.add_child(btn_cargar)

	# Botón Probar Mapa
	var btn_probar := Button.new()
	btn_probar.text = "▶ PROBAR MAPA EN VIVO"
	btn_probar.custom_minimum_size = Vector2(0, 54)
	btn_probar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_probar, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	btn_probar.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	if _fuente_ui:
		btn_probar.add_theme_font_override("font", _fuente_ui)
	btn_probar.pressed.connect(func():
		_popup_sistema.visible = false
		iniciar_prueba_solicitado.emit()
	)
	vbox.add_child(btn_probar)

func _alternar_popup_sistema() -> void:
	_popup_sistema.visible = not _popup_sistema.visible

# ── 7. TOAST NOTIFICACIONES FLOTANTES ────────────────────────────────
func _construir_toast_flotante(padre: Control) -> void:
	_panel_toast_flotante = PanelContainer.new()
	_panel_toast_flotante.name = "ToastFlotante"
	_panel_toast_flotante.anchor_left = 0.5
	_panel_toast_flotante.anchor_right = 0.5
	_panel_toast_flotante.anchor_top = 0.0
	_panel_toast_flotante.anchor_bottom = 0.0
	_panel_toast_flotante.offset_left = -260.0
	_panel_toast_flotante.offset_right = 260.0
	_panel_toast_flotante.offset_top = 100.0
	_panel_toast_flotante.offset_bottom = 154.0
	_panel_toast_flotante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_toast_flotante.modulate.a = 0.0
	_estilar_panel_glass(_panel_toast_flotante, COLOR_FONDO_PRINCIPAL, COLOR_AMARILLO_PRI, 14.0, 10.0)
	padre.add_child(_panel_toast_flotante)

	_toast_hud = Label.new()
	_toast_hud.text = "NOTIFICACIÓN"
	_toast_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_hud.add_theme_font_size_override("font_size", 18)
	_toast_hud.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui:
		_toast_hud.add_theme_font_override("font", _fuente_ui)
	_panel_toast_flotante.add_child(_toast_hud)

func mostrar_notificacion(texto: String) -> void:
	if not _toast_hud or not _panel_toast_flotante:
		return
	_toast_hud.text = texto
	var tween = create_tween()
	tween.tween_property(_panel_toast_flotante, "modulate:a", 1.0, 0.20)
	tween.tween_interval(2.2)
	tween.tween_property(_panel_toast_flotante, "modulate:a", 0.0, 0.35)

# ── 8. MÉTODOS PÚBLICOS DE COMPATIBILIDAD CON EditorMapas.gd ─────────
func seleccionar_categoria(cat_id: String) -> void:
	_categoria_activa = cat_id
	categoria_cambiada.emit(cat_id)

	for c_id in _dict_botones_categoria:
		var btn: Button = _dict_botones_categoria[c_id]
		_estilar_boton_pildora(btn, c_id == cat_id)

	_refrescar_grid_herramientas(cat_id)

	var sub_defecto := "elevar"
	match cat_id:
		"terreno": sub_defecto = "elevar"
		"vias": sub_defecto = "calle_2"
		"ciudad": sub_defecto = "res"
		"vegetacion": sub_defecto = "arbol_sabanero"
		"agua": sub_defecto = "lago"
		"spawn": sub_defecto = "vehiculo"

	_seleccionar_subherramienta(sub_defecto)

func esta_sobre_interfaz(pos_pantalla: Vector2) -> bool:
	if _hud_superior and _hud_superior.visible and _hud_superior.get_global_rect().has_point(pos_pantalla):
		return true
	if _panel_herramientas and _panel_herramientas.visible and _panel_herramientas.get_global_rect().has_point(pos_pantalla):
		return true
	if _panel_propiedades and _panel_propiedades.visible and _panel_propiedades.get_global_rect().has_point(pos_pantalla):
		return true
	if _popup_sistema and _popup_sistema.visible and _popup_sistema.get_global_rect().has_point(pos_pantalla):
		return true
	if _hud_inferior_izquierdo and _hud_inferior_izquierdo.visible and _hud_inferior_izquierdo.get_global_rect().has_point(pos_pantalla):
		return true
	if _hud_barra_estado and _hud_barra_estado.visible and _hud_barra_estado.get_global_rect().has_point(pos_pantalla):
		return true
	return false

func actualizar_telemetria(fps: int, total_objetos: int, pos_x: float, pos_z: float) -> void:
	if _lbl_fps:
		_lbl_fps.text = "FPS: %d" % fps
	if _lbl_mapa_res:
		_lbl_mapa_res.text = "Obj: %d | [X:%.0f, Z:%.0f]" % [total_objetos, pos_x, pos_z]

func actualizar_posicion_cursor(_pos_mundo: Vector3, _es_valido: bool) -> void:
	pass

func actualizar_estado_boton_colocar(categoria: String, subherramienta: String = "", modo_demolicion: bool = false, _snap_conexion: bool = false, _origen_conexion_fijado: bool = false, _sobre_cruce_existente: bool = false, _sobre_punto_existente: bool = false, punto_seleccionado: bool = false) -> void:
	_categoria_activa = categoria
	_subherramienta_activa = subherramienta
	_modo_demolicion_activo = modo_demolicion

	if not _btn_colocar_grande or not is_instance_valid(_btn_colocar_grande):
		return

	if modo_demolicion:
		_btn_colocar_grande.text = "  Demoler Aquí"
		_estilar_boton(_btn_colocar_grande, COLOR_CRIMSON_SALIR, Color(1, 1, 1, 0.4), 18.0)
		_btn_colocar_grande.add_theme_color_override("font_color", Color.WHITE)
	elif punto_seleccionado:
		_btn_colocar_grande.text = "  Mover Punto Aquí"
		_estilar_boton(_btn_colocar_grande, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 18.0)
		_btn_colocar_grande.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	else:
		_btn_colocar_grande.text = "  Aplicar"
		_estilar_boton(_btn_colocar_grande, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 18.0)
		_btn_colocar_grande.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)

func actualizar_boton_modo_conectar(_activo: bool) -> void:
	pass

func resaltar_tarjeta(_id_tarjeta: String) -> void:
	pass

func obtener_radio_lago() -> float:
	return _radio_lago

func obtener_profundidad_lago() -> float:
	return _profundidad_lago

func obtener_ancho_rio() -> float:
	return _ancho_rio

# ── 9. INSPECTORES CONTEXTUALES DE CRUCES, PUNTOS Y OBJETOS ──────────
func mostrar_panel_edicion_cruce(datos: Dictionary, datos_ramales: Array = []) -> void:
	_lbl_prop_titulo.text = "Editar Cruce Vial"
	_lbl_prop_badge.text = "● Cruce"
	for child in _box_prop_contenido.get_children():
		child.queue_free()

	_crear_fila_slider("Radio de Cruce", "ico_pincel_radio", 8.0, 45.0, float(datos.get("radio", 16.0)), "m", 1.0, func(v):
		cruce_radio_cambiado.emit(v)
	)
	_crear_fila_slider("Rotación Cruce", "act_rotar", 0.0, 360.0, float(datos.get("rotacion", 0.0)), "°", 5.0, func(v):
		cruce_rotacion_cambiada.emit(v)
	)

	var hbox_brazos := HBoxContainer.new()
	hbox_brazos.add_theme_constant_override("separation", 8)
	_box_prop_contenido.add_child(hbox_brazos)

	var btn_b3 := Button.new()
	btn_b3.text = "Cruce en T (3)"
	btn_b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_b3.custom_minimum_size = Vector2(0, 36)
	btn_b3.add_theme_font_size_override("font_size", 12)
	_estilar_boton(btn_b3, COLOR_PANEL_SEC, COLOR_BORDE, 8.0)
	if _fuente_ui:
		btn_b3.add_theme_font_override("font", _fuente_ui)
	btn_b3.pressed.connect(func(): cruce_num_brazos_cambiado.emit(3))
	hbox_brazos.add_child(btn_b3)

	var btn_b4 := Button.new()
	btn_b4.text = "Cruce en Cruz (4)"
	btn_b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_b4.custom_minimum_size = Vector2(0, 36)
	btn_b4.add_theme_font_size_override("font_size", 17)
	_estilar_boton(btn_b4, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
	if _fuente_ui:
		btn_b4.add_theme_font_override("font", _fuente_ui)
	btn_b4.pressed.connect(func(): cruce_num_brazos_cambiado.emit(4))
	hbox_brazos.add_child(btn_b4)

	_crear_botones_accion_inferiores(
		func(): cruce_eliminar_solicitado.emit(),
		func(): cruce_edicion_cerrada.emit(),
		"Eliminar Cruce",
		"Cerrar Edición"
	)

func actualizar_datos_panel_cruce(_datos: Dictionary) -> void:
	pass

func actualizar_seccion_ramales(_datos_ramales: Array) -> void:
	pass

func ocultar_panel_edicion_cruce() -> void:
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func _seleccionar_boton_tipo_via(_tipo: int) -> void:
	pass

func mostrar_panel_edicion_punto_via(datos: Dictionary) -> void:
	_lbl_prop_titulo.text = "Editar Rasante de Vía"
	_lbl_prop_badge.text = "● Rasante"
	for child in _box_prop_contenido.get_children():
		child.queue_free()

	_crear_fila_slider("Altura Rasante", "act_nivelar", -10.0, 35.0, float(datos.get("altura", 0.0)), "m", 0.5, func(v):
		punto_via_altura_cambiada.emit(v)
	)
	_crear_fila_slider("Peralte Curva", "act_rotar", -15.0, 15.0, float(datos.get("peralte", 0.0)), "°", 0.5, func(v):
		punto_via_peralte_cambiado.emit(v)
	)

	var btn_adaptar := Button.new()
	btn_adaptar.text = "⊞ Adaptar Terreno al Tramo"
	btn_adaptar.custom_minimum_size = Vector2(0, 50)
	btn_adaptar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_adaptar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_adaptar.add_theme_font_override("font", _fuente_ui)
	btn_adaptar.pressed.connect(func(): adaptar_terreno_tramo_solicitado.emit())
	_box_prop_contenido.add_child(btn_adaptar)

	_crear_botones_accion_inferiores(
		func(): punto_via_eliminado_solicitado.emit(),
		func(): punto_via_edicion_cerrada.emit(),
		"Eliminar Punto",
		"Finalizar Edición"
	)

func actualizar_datos_panel_punto_via(_datos: Dictionary) -> void:
	pass

func ocultar_panel_edicion_punto_via() -> void:
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func _seleccionar_boton_tipo_via_punto(_tipo: int) -> void:
	pass

func mostrar_panel_equipamiento_vias(_datos: Dictionary = {}) -> void:
	_lbl_prop_titulo.text = "Equipamiento Vial"
	_lbl_prop_badge.text = "● Aceras"
	for child in _box_prop_contenido.get_children():
		child.queue_free()

	_crear_fila_slider("Ancho de Acera/Berma", "ico_pincel_radio", 1.0, 5.0, _ancho_equip_ui_actual, "m", 0.2, func(v):
		_ancho_equip_ui_actual = v
		equipamiento_ancho_cambiado.emit(v)
	)

	_crear_botones_accion_inferiores(
		func(): equipamiento_cancelar_solicitado.emit(),
		func(): equipamiento_aplicar_solicitado.emit(),
		"Cancelar",
		"Aplicar a Tramo"
	)

func actualizar_datos_panel_equipamiento(_datos: Dictionary) -> void:
	pass

func ocultar_panel_equipamiento_vias() -> void:
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func mostrar_panel_edicion_objeto(datos: Dictionary) -> void:
	_lbl_prop_titulo.text = "Inspector: " + str(datos.get("nombre", "Objeto"))
	_lbl_prop_badge.text = "● Objeto"
	for child in _box_prop_contenido.get_children():
		child.queue_free()

	var rot := float(datos.get("rotacion_y", 0.0))
	_crear_fila_slider("Rotación Objeto", "act_rotar", 0.0, 360.0, rot, "°", 5.0, func(v):
		objeto_rotacion_fijada.emit(v)
	)

	var hbox_acts := HBoxContainer.new()
	hbox_acts.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_acts)

	var btn_mov := Button.new()
	btn_mov.text = "Mover Objeto"
	btn_mov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mov.custom_minimum_size = Vector2(0, 50)
	btn_mov.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_mov, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
	if _fuente_ui:
		btn_mov.add_theme_font_override("font", _fuente_ui)
	btn_mov.pressed.connect(func():
		_modo_mover_objeto_ui = not _modo_mover_objeto_ui
		objeto_mover_alternado.emit(_modo_mover_objeto_ui)
	)
	hbox_acts.add_child(btn_mov)

	_crear_botones_accion_inferiores(
		func(): objeto_eliminar_solicitado.emit(),
		func(): objeto_edicion_cerrada.emit(),
		"Demoler Objeto",
		"Cerrar Inspector"
	)

func actualizar_datos_panel_objeto(_datos: Dictionary) -> void:
	pass

func ocultar_panel_edicion_objeto() -> void:
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

# ── 10. HELPERS DE ESTILO GLASSMORPHISM ──────────────────────────────
func _estilar_panel_glass(panel: PanelContainer, color_fondo: Color, color_borde: Color = COLOR_BORDE, radio: float = 20.0, margen: float = 16.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color_fondo
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = color_borde
	sb.corner_radius_top_left = int(radio)
	sb.corner_radius_top_right = int(radio)
	sb.corner_radius_bottom_right = int(radio)
	sb.corner_radius_bottom_left = int(radio)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	sb.content_margin_left = margen
	sb.content_margin_right = margen
	sb.content_margin_top = margen
	sb.content_margin_bottom = margen
	panel.add_theme_stylebox_override("panel", sb)

func _estilar_boton(btn: Button, color_fondo: Color, color_borde: Color = COLOR_BORDE, radio: float = 16.0, grosor: int = 1) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = color_fondo
	sb_normal.border_width_left = grosor
	sb_normal.border_width_top = grosor
	sb_normal.border_width_right = grosor
	sb_normal.border_width_bottom = grosor
	sb_normal.border_color = color_borde
	sb_normal.corner_radius_top_left = int(radio)
	sb_normal.corner_radius_top_right = int(radio)
	sb_normal.corner_radius_bottom_right = int(radio)
	sb_normal.corner_radius_bottom_left = int(radio)
	sb_normal.shadow_color = Color(0, 0, 0, 0.30)
	sb_normal.shadow_size = 6
	btn.add_theme_stylebox_override("normal", sb_normal)

	var sb_hover := sb_normal.duplicate()
	sb_hover.border_color = COLOR_AMARILLO_SEL
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = color_fondo.lightened(0.12)
	sb_pressed.border_color = COLOR_AMARILLO_SEL
	btn.add_theme_stylebox_override("pressed", sb_pressed)

func _estilar_boton_pildora(btn: Button, activo: bool) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_right = 16
	sb.corner_radius_bottom_left = 16

	if activo:
		sb.bg_color = COLOR_AMARILLO_SEL
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = COLOR_AMARILLO_PRI
		sb.shadow_color = Color(1.0, 0.77, 0.18, 0.35)
		sb.shadow_size = 8
		btn.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
		btn.add_theme_color_override("icon_normal_color", COLOR_FONDO_PRINCIPAL)
		btn.add_theme_color_override("icon_hover_color", COLOR_FONDO_PRINCIPAL)
		btn.add_theme_color_override("icon_pressed_color", COLOR_FONDO_PRINCIPAL)
	else:
		sb.bg_color = COLOR_PANEL_SEC
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = COLOR_BORDE
		btn.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
		btn.add_theme_color_override("icon_normal_color", COLOR_TEXTO_PRI)
		btn.add_theme_color_override("icon_hover_color", COLOR_TEXTO_PRI)
		btn.add_theme_color_override("icon_pressed_color", COLOR_TEXTO_PRI)

	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	if not activo:
		sb_h.border_color = COLOR_AMARILLO_SEL
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb)

func _estilar_slider_moderno(slider: HSlider) -> void:
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = COLOR_FONDO_PRINCIPAL
	sb_bg.border_width_left = 1
	sb_bg.border_width_top = 1
	sb_bg.border_width_right = 1
	sb_bg.border_width_bottom = 1
	sb_bg.border_color = COLOR_BORDE
	sb_bg.corner_radius_top_left = 4
	sb_bg.corner_radius_top_right = 4
	sb_bg.corner_radius_bottom_right = 4
	sb_bg.corner_radius_bottom_left = 4
	sb_bg.content_margin_top = 3
	sb_bg.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", sb_bg)

	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = COLOR_AMARILLO_SEL
	sb_grab.corner_radius_top_left = 4
	sb_grab.corner_radius_top_right = 4
	sb_grab.corner_radius_bottom_right = 4
	sb_grab.corner_radius_bottom_left = 4
	sb_grab.content_margin_top = 3
	sb_grab.content_margin_bottom = 3
	slider.add_theme_stylebox_override("grabber_area", sb_grab)
	slider.add_theme_stylebox_override("grabber_area_highlight", sb_grab)

	if not _textura_grabber:
		_textura_grabber = _crear_textura_grabber()
	slider.add_theme_icon_override("grabber", _textura_grabber)
	slider.add_theme_icon_override("grabber_highlight", _textura_grabber)

func _crear_textura_grabber() -> Texture2D:
	var dim := 28
	var img := Image.create_empty(dim, dim, false, Image.FORMAT_RGBA8)
	var centro := Vector2(dim * 0.5, dim * 0.5)
	var r_fill := 9.0
	var r_anti := 12.0
	for x in dim:
		for y in dim:
			var d := centro.distance_to(Vector2(x, y))
			if d <= r_fill:
				img.set_pixel(x, y, COLOR_AMARILLO_SEL)
			elif d <= r_anti:
				var a: float = clamp(1.0 - (d - r_fill) / (r_anti - r_fill), 0.0, 1.0)
				img.set_pixel(x, y, Color(COLOR_AMARILLO_SEL.r, COLOR_AMARILLO_SEL.g, COLOR_AMARILLO_SEL.b, a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

# ── 11. RESPONSIVE Y REDIMENSIONADO ──────────────────────────────────
func _on_viewport_size_changed() -> void:
	var vp_size: Vector2i = get_viewport().size
	if vp_size.x < 1200:
		if _panel_propiedades and not _esta_colapsado_propiedades:
			_panel_propiedades.offset_left = -420.0
		if _panel_herramientas and not _esta_colapsado_herramientas:
			_panel_herramientas.offset_right = 340.0
	else:
		if _panel_propiedades and not _esta_colapsado_propiedades:
			_panel_propiedades.offset_left = -480.0
		if _panel_herramientas and not _esta_colapsado_herramientas:
			_panel_herramientas.offset_right = 368.0

func _obtener_metadatos_herramienta(categoria: String, subherramienta: String) -> Dictionary:
	var dict_nombres = {
		"elevar": {"titulo": "Elevar Terreno", "icono": "terreno_elevar"},
		"bajar": {"titulo": "Bajar Terreno", "icono": "terreno_bajar"},
		"aplanar": {"titulo": "Aplanar Terreno", "icono": "terreno_aplanar"},
		"suavizar": {"titulo": "Suavizar Terreno", "icono": "terreno_suavizar"},
		"cesped": {"titulo": "Pintar Césped", "icono": "terreno_cesped"},
		"tierra": {"titulo": "Pintar Tierra", "icono": "terreno_tierra"},
		"roca": {"titulo": "Pintar Roca", "icono": "terreno_roca"},
		"agua": {"titulo": "Lago / Embalse", "icono": "terreno_agua"},
		"lago": {"titulo": "Lago / Embalse", "icono": "terreno_agua"},
		"rio": {"titulo": "Río / Quebrada", "icono": "terreno_rio"},
		"calle_2": {"titulo": "Calle 2 Carriles", "icono": "via_calle_2"},
		"avenida_4": {"titulo": "Avenida 4 Carriles", "icono": "via_avenida_4"},
		"autopista_6": {"titulo": "Autopista 6 Carriles", "icono": "via_autopista_6"},
		"trocha": {"titulo": "Trocha Rural", "icono": "via_calle_2"},
		"res": {"titulo": "Zona Residencial", "icono": "cat_ciudad"},
		"com": {"titulo": "Zona Comercial", "icono": "cat_ciudad"},
		"inst": {"titulo": "Zona Institucional", "icono": "cat_ciudad"},
		"arbol_sabanero": {"titulo": "Árbol Sabanero", "icono": "cat_vegetacion"},
		"vehiculo": {"titulo": "Spawn Vehículo", "icono": "cat_spawn"},
		"jugador": {"titulo": "Spawn Jugador", "icono": "cat_spawn"}
	}
	if dict_nombres.has(subherramienta):
		return dict_nombres[subherramienta]
	return {"titulo": subherramienta.capitalize() + " (" + categoria.capitalize() + ")", "icono": "cat_" + categoria}
