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
const FONT_TITULO_PRINCIPAL := 34 # Título principal de tarjeta contextual (ej. "Elevar Terreno")
const FONT_TITULO_SUB       := 29 # Títulos de subsección y opciones de menú
const FONT_BOTON_ACCION     := 26 # Botón maestro "Aplicar", "Colocar", "Finalizar"
const FONT_BOTON_MEDIO      := 23 # Botones de categorías ("Terreno", "Vías", "Salir")
const FONT_READOUT_VALOR    := 23 # Lectura numérica de sliders ("25 m", "0.40")
const FONT_LABEL_SLIDER     := 23 # Etiquetas de parámetros ("Radio del pincel", "Fuerza")
const FONT_BOTON_GRID       := 19 # Etiquetas de botones 3x3 ("Elevar", "Bajar", "Aplanar")
const FONT_ESTADO_HUD       := 20 # Barra de estado inferior y FPS
const FONT_TEXTO_INFO       := 20 # Descripciones contextuales
const FONT_BADGE            := 16 # Píldoras de estado ("● Activo")

# ── SEÑALES PÚBLICAS REQUERIDAS POR EL EDITOR ───────────────────────
signal categoria_cambiada(categoria: String)
signal subherramienta_seleccionada(id_herramienta: String)
signal radio_pincel_cambiado(nuevo_radio: float)
signal fuerza_pincel_cambiada(nueva_fuerza: float)
signal perfil_pincel_cambiado(nuevo_perfil: int)
signal altura_objetivo_terreno_cambiada(nueva_altura: float)
signal material_pintura_cambiado(id_material: String)
signal suavizado_borde_cambiado(nuevo_suavizado: float)
signal demolicion_alternada(activa: bool)
signal rotar_objeto_solicitado()
signal snap_cuadricula_alternado(activo: bool)
signal terminar_tramo_via_solicitado()
signal rotonda_salidas_cambiada(salidas: int)
signal seguir_carretera_desde_punto_solicitado()
signal seleccionar_tramo_desde_punto_solicitado()
signal umbral_altura_puente_cambiado(nuevo_umbral: float)
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
signal distancia_renderizado_cambiada(distancia: float)
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
signal preset_equipamiento_solicitado(id_preset: String)
signal auto_nivelar_vias_alternado(activo: bool)

# Señales de objetos
signal objeto_rotacion_delta(delta_grados: float)
signal objeto_rotacion_fijada(grados: float)
signal objeto_inclinacion_fijada(grados: float)
signal objeto_altura_delta(delta_y: float)
signal objeto_altura_reset()
signal objeto_eliminar_solicitado()
signal objeto_reemplazar_solicitado()
signal objeto_mover_alternado(activo: bool)
signal objeto_edicion_cerrada()
signal disenador_casa_solicitado(editar_seleccionada: bool)

# Señales de cámara
signal camara_pan_solicitado(direccion: Vector2)
signal camara_zoom_solicitado(factor: float)
signal camara_orbita_solicitada(grados: float)
signal camara_pitch_solicitada(grados: float)
signal camara_cenital_solicitada()
signal centrar_camara_seleccion_solicitado()
signal listo_seleccion_solicitado()
signal modo_camara_movil_cambiado(modo: String)

# Señales de muros modulares
signal muro_tipo_cambiado(id_muro: String)
signal muro_escala_altura_cambiada(escala: float)
signal muro_finalizar_tramo_solicitado()
signal muro_deshacer_solicitado()
signal muro_borrar_solicitado()

# Señales de vías avanzadas (tramos, superficie, demarcación y señalización)
signal tramo_cambiar_tipo_via_solicitado(nuevo_tipo: int)
signal tramo_estilo_cambiado(superficie: int, demarcacion: int)
signal tramo_limpiar_equipamiento_solicitado()
signal equipamiento_ojos_gato_solicitado(lado: int)
signal equipamiento_tipo_senal_cambiado(tipo_senal: int)

# Señales de estacionamientos procedurales
signal parqueo_tipo_cambiado(tipo: int)
signal parqueo_color_lineas_cambiado(color_idx: int)
signal parqueo_iluminacion_cambiada(activa: bool)
signal parqueo_arbolado_cambiado(activo: bool)
signal parqueo_finalizar_solicitado()
signal parqueo_editar_esquinas_solicitado()
signal parqueo_unir_carretera_solicitado()
signal parqueo_nivelar_solicitado()
signal parqueo_eliminar_solicitado()
signal parqueo_rotacion_cambiada(angulo: float)
signal parqueo_rotacion_delta_solicitada(delta: float)
signal parqueo_adaptar_terreno_cambiado(activo: bool)
signal concreto_acabado_cambiado(acabado: int)
signal concreto_altura_cambiada(altura: float)
signal concreto_bordillo_cambiado(activo: bool)
signal concreto_adaptar_terreno_cambiado(activo: bool)
signal concreto_agregar_punto_solicitado()
signal concreto_subdividir_solicitado()
signal concreto_eliminar_punto_solicitado()
signal concreto_finalizar_solicitado()
signal concreto_editar_puntos_solicitado()
signal concreto_nivelar_solicitado()
signal concreto_eliminar_solicitado()
signal concreto_rotacion_delta_solicitada(delta: float)
signal agua_rio_limpiar_solicitado()
signal agua_rio_finalizar_solicitado()
signal agua_nivel_delta_solicitado(delta: float)
signal agua_limpiar_todo_solicitado()
signal info_vista_cambiada(modo: int)
signal via_snap_angulo_cambiado(activo: bool)
signal via_elevacion_paso_solicitada(delta_m: float)
signal via_elevacion_reset_solicitada()
signal via_mejorar_alternado(activo: bool)
signal cruce_control_trafico_cambiado(modo: String)
signal snap_via_ciudad_alternado(activo: bool)
signal pipeta_solicitada()
signal zona_tipo_cambiado(tipo: int)
signal zona_desarrollar_solicitado()
signal zona_limpiar_solicitado()
signal zona_auto_construir_cambiado(activo: bool)
signal variacion_garaje_cambiada(nuevo_id: String)

const VARIACIONES_GARAJE := [
	{"id": "garaje_camiones", "nom": "Clásico 1 Bahía"},
	{"id": "garaje_doble", "nom": "Doble Bahía XL"},
	{"id": "garaje_terminal", "nom": "Nave Pasante XL"},
	{"id": "garaje_moderno", "nom": "Centro Moderno"}
]
var _panel_variaciones_garaje: PanelContainer = null
var _lbl_var_garaje: Label = null
var _idx_var_garaje: int = 0
signal zona_radio_cambiado(radio: float)
signal zona_filas_cambiado(filas: int)
signal auto_casas_seccion_cambiada(seccion_id: String)
signal auto_casas_modo_cambiado(modo: String)
signal auto_casas_radio_cambiado(radio: float)
signal auto_casas_cantidad_cambiada(cantidad: int)
signal follaje_pintura_cambiado(id_follaje: String)
signal densidad_follaje_cambiada(densidad: float)
signal escala_follaje_cambiada(escala_pct: float)
signal borrar_follaje_alternado(borrar: bool)

# ── ESTADO INTERNO ──────────────────────────────────────────────────
var _tipo_senal_ui_actual: int = 0
var _info_vista_actual: int = 0
var _via_snap_angulo_ui: bool = true
var _via_mejorar_ui: bool = false
var _snap_via_ciudad_ui: bool = true
var _zona_tipo_ui: int = 1
var _zona_auto_construir_ui: bool = true
var _zona_radio_ui: float = 5.5
var _zona_filas_ui: int = 1
var _auto_casas_seccion_ui: String = "01_Residencial"
var _auto_casas_modo_ui: String = "pincel"
var _auto_casas_radio_ui: float = 35.0
var _auto_casas_cantidad_ui: int = 8
var _sup_via_ui_actual: int = 0
var _dem_via_ui_actual: int = 0
var _tab_equip_tramo: String = "equipar"
var _fuente_ui: Font = null
var _fuente_moderniz: Font = null
var _categoria_activa: String = "terreno"
var _subherramienta_activa: String = "elevar"
var _rotonda_salidas_activa: int = 4
var _seccion_vias_library: String = "vias"
var _btn_flotante_rotonda: Button = null
var _id_item_activo: String = "elevar"
var _perfil_pincel_activo: int = 0 # 0: Suave, 1: Medio, 2: Fuerte
var _filtro_categoria_material: String = "todos"
var _filtro_categoria_follaje: String = "todos"
var _follaje_pintura_activo: String = "follaje_cesped_fino"
var _densidad_follaje: float = 0.85
var _escala_follaje: float = 100.0
var _borrar_follaje_activo: bool = false
var _radio_pincel: float = 25.0
var _fuerza_pincel: float = 0.40
var _altura_objetivo_terreno: float = 12.0
var _opacidad_textura: float = 0.85
var _suavizado_borde_pintura: float = 0.30
var _material_pintura_activo: String = "cesped_verde"
var _radio_lago: float = 24.0
var _profundidad_lago: float = 3.5
var _ancho_rio: float = 8.0
var _densidad_dispersion: int = 12
var _radio_dispersion: float = 20.0

var _modo_demolicion_activo: bool = false
var _snap_grid_activo: bool = false
var _auto_nivelar_vias_activo: bool = true
var _umbral_puente_vias: float = 3.0
var _equip_tipo_ui_actual: int = 0
var _paso_equipamiento_actual: int = 0
var _equip_lado_ui_actual: int = 0
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
var _box_herramientas: VBoxContainer
var _grid_herramientas: GridContainer
var _dict_botones_herramientas: Dictionary = {}

# Panel contextual de propiedades (Derecha)
var _panel_propiedades: PanelContainer
var _btn_colapsar_propiedades: Button
var _esta_colapsado_propiedades: bool = false
var _lbl_prop_titulo: Label
var _lbl_prop_badge: Label
var _ico_prop_header: TextureRect
var _scroll_prop_contenido: ScrollContainer
var _box_prop_contenido: VBoxContainer
var _panel_sliders: PanelContainer
var _box_sliders_contenido: VBoxContainer
var _btn_prop_aplicar: Button
var _btn_prop_restablecer: Button

# Referencias para sliders y lecturas dinámicas
var _dict_sliders: Dictionary = {}
var _dict_readouts: Dictionary = {}
var _dict_botones_perfil: Dictionary = {}
var _dict_botones_material: Dictionary = {}
var _preview_mat_tex: TextureRect = null
var _preview_mat_nombre: Label = null
var _preview_mat_tipo: Label = null
var _preview_mat_desc: Label = null
var _especie_vegetacion_activa: String = "arbol_sabanero"
var _preview_veg_tex: TextureRect = null
var _preview_veg_nombre: Label = null
var _preview_veg_desc: Label = null
var _dict_botones_especie: Dictionary = {}
var _muro_activo: String = "muro_ladrillo"
var _muro_filtro_cat: String = "urbano"
var _muro_escala_altura: float = 1.0
var _preview_muro_tex: TextureRect = null
var _preview_muro_nombre: Label = null
var _preview_muro_desc: Label = null
var _dict_botones_muro: Dictionary = {}

# HUD Inferior
var _hud_inferior_izquierdo: HBoxContainer
var _panel_camara_movil: PanelContainer
var _botones_camara_movil: Dictionary = {}
var _modo_camara_movil: String = ""
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
var _btn_centrar_seleccion: Button = null
var _btn_listo_seleccion: Button = null
var _btn_flotante_finalizar_muro: Button = null
var _hbox_flotante_inferior: HBoxContainer = null

# ── INICIALIZACIÓN ──────────────────────────────────────────────────
func _ready() -> void:
	if ResourceLoader.exists("res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf"):
		_fuente_ui = load("res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf")
	elif ResourceLoader.exists("res://recursos/fonts/nexa/Nexa-Heavy.ttf"):
		_fuente_ui = load("res://recursos/fonts/nexa/Nexa-Heavy.ttf")
	if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
		_fuente_moderniz = load("res://recursos/fonts/Moderniz.otf")
	_construir_interfaz_completa()
	seleccionar_categoria("terreno")
	if get_viewport():
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
		var tex := load(ruta) as Texture2D
		if tex:
			return tex
	if FileAccess.file_exists(ruta):
		var svg_str := FileAccess.get_file_as_string(ruta)
		if not svg_str.is_empty():
			var img := Image.new()
			if img.load_svg_from_string(svg_str, 2.0) == OK:
				return ImageTexture.create_from_image(img)
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
	_construir_panel_sliders(_contenedor_raiz)
	_construir_hud_inferior_izquierdo(_contenedor_raiz)
	_construir_dock_camara_movil(_contenedor_raiz)
	_construir_hud_barra_estado(_contenedor_raiz)
	_construir_boton_flotante_rotonda(_contenedor_raiz)
	_construir_boton_centrar_seleccion(_contenedor_raiz)
	_construir_popup_sistema(_contenedor_raiz)
	_construir_toast_flotante(_contenedor_raiz)

func _asegurar_hbox_flotante_inferior(padre: Control) -> void:
	if is_instance_valid(_hbox_flotante_inferior):
		return
	_hbox_flotante_inferior = HBoxContainer.new()
	_hbox_flotante_inferior.name = "HBoxFlotanteInferior"
	_hbox_flotante_inferior.anchor_left = 0.5
	_hbox_flotante_inferior.anchor_right = 0.5
	_hbox_flotante_inferior.anchor_top = 1.0
	_hbox_flotante_inferior.anchor_bottom = 1.0
	_hbox_flotante_inferior.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hbox_flotante_inferior.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hbox_flotante_inferior.offset_top = -98.0
	_hbox_flotante_inferior.offset_bottom = -32.0
	_hbox_flotante_inferior.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox_flotante_inferior.add_theme_constant_override("separation", 14)
	_hbox_flotante_inferior.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox_flotante_inferior.visible = false
	padre.add_child(_hbox_flotante_inferior)

func _construir_boton_centrar_seleccion(padre: Control) -> void:
	_btn_centrar_seleccion = Button.new()
	_btn_centrar_seleccion.name = "BtnCentrarSeleccion"
	_btn_centrar_seleccion.text = "Centrar Camara"
	_btn_centrar_seleccion.anchor_left = 0.5
	_btn_centrar_seleccion.anchor_right = 0.5
	_btn_centrar_seleccion.anchor_top = 0.0
	_btn_centrar_seleccion.anchor_bottom = 0.0
	_btn_centrar_seleccion.offset_left = -212.0
	_btn_centrar_seleccion.offset_top = 98.0
	_btn_centrar_seleccion.offset_right = 16.0
	_btn_centrar_seleccion.offset_bottom = 160.0
	_btn_centrar_seleccion.custom_minimum_size = Vector2(228, 62)
	_btn_centrar_seleccion.add_theme_font_size_override("font_size", 20)
	if _fuente_ui:
		_btn_centrar_seleccion.add_theme_font_override("font", _fuente_ui)
	elif _fuente_moderniz:
		_btn_centrar_seleccion.add_theme_font_override("font", _fuente_moderniz)
	_estilar_boton(_btn_centrar_seleccion, COLOR_PANEL, COLOR_AMARILLO_SEL, 12.0)
	_btn_centrar_seleccion.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	_btn_centrar_seleccion.add_theme_color_override("icon_normal_color", COLOR_AMARILLO_SEL)
	var ico_c := _cargar_icono_svg("act_centrar_camara")
	if ico_c:
		_btn_centrar_seleccion.icon = ico_c
		_btn_centrar_seleccion.expand_icon = true
		_btn_centrar_seleccion.add_theme_constant_override("icon_max_width", 26)
	_btn_centrar_seleccion.pressed.connect(func():
		centrar_camara_seleccion_solicitado.emit()
	)
	_btn_centrar_seleccion.visible = false
	padre.add_child(_btn_centrar_seleccion)

	_btn_listo_seleccion = Button.new()
	_btn_listo_seleccion.name = "BtnListoSeleccion"
	_btn_listo_seleccion.text = "✓ Listo"
	_btn_listo_seleccion.anchor_left = 0.5
	_btn_listo_seleccion.anchor_right = 0.5
	_btn_listo_seleccion.anchor_top = 0.0
	_btn_listo_seleccion.anchor_bottom = 0.0
	_btn_listo_seleccion.offset_left = 28.0
	_btn_listo_seleccion.offset_top = 98.0
	_btn_listo_seleccion.offset_right = 208.0
	_btn_listo_seleccion.offset_bottom = 160.0
	_btn_listo_seleccion.custom_minimum_size = Vector2(180, 62)
	_btn_listo_seleccion.add_theme_font_size_override("font_size", 22)
	if _fuente_ui:
		_btn_listo_seleccion.add_theme_font_override("font", _fuente_ui)
	elif _fuente_moderniz:
		_btn_listo_seleccion.add_theme_font_override("font", _fuente_moderniz)
	_estilar_boton(_btn_listo_seleccion, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	_btn_listo_seleccion.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	_btn_listo_seleccion.pressed.connect(func():
		listo_seleccion_solicitado.emit()
	)
	_btn_listo_seleccion.visible = false
	padre.add_child(_btn_listo_seleccion)

	_asegurar_hbox_flotante_inferior(padre)

	_btn_flotante_finalizar_muro = Button.new()
	_btn_flotante_finalizar_muro.name = "BtnFlotanteFinalizarMuro"
	_btn_flotante_finalizar_muro.text = "✓ FINALIZAR"
	_btn_flotante_finalizar_muro.custom_minimum_size = Vector2(210, 66)
	_btn_flotante_finalizar_muro.add_theme_font_size_override("font_size", 21)
	if _fuente_moderniz:
		_btn_flotante_finalizar_muro.add_theme_font_override("font", _fuente_moderniz)
	elif _fuente_ui:
		_btn_flotante_finalizar_muro.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(_btn_flotante_finalizar_muro, COLOR_PANEL, COLOR_AMARILLO_SEL, 14.0)
	_btn_flotante_finalizar_muro.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	_btn_flotante_finalizar_muro.pressed.connect(func():
		muro_finalizar_tramo_solicitado.emit()
	)
	_btn_flotante_finalizar_muro.visible = false
	_hbox_flotante_inferior.add_child(_btn_flotante_finalizar_muro)

func mostrar_boton_centrar_seleccion(activo: bool) -> void:
	if is_instance_valid(_btn_centrar_seleccion):
		_btn_centrar_seleccion.visible = activo
	if is_instance_valid(_btn_listo_seleccion):
		_btn_listo_seleccion.visible = activo

func _construir_boton_flotante_rotonda(padre: Control) -> void:
	_asegurar_hbox_flotante_inferior(padre)
	_btn_flotante_rotonda = Button.new()
	_btn_flotante_rotonda.name = "BtnFlotanteColocarRotonda"
	_btn_flotante_rotonda.text = "＋ ROTONDA"
	_btn_flotante_rotonda.custom_minimum_size = Vector2(220, 66)
	_btn_flotante_rotonda.add_theme_font_size_override("font_size", 21)
	if _fuente_moderniz:
		_btn_flotante_rotonda.add_theme_font_override("font", _fuente_moderniz)
	elif _fuente_ui:
		_btn_flotante_rotonda.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(_btn_flotante_rotonda, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 14.0)
	_btn_flotante_rotonda.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	var ico_rot := _cargar_icono_svg("via_rotonda")
	if ico_rot:
		_btn_flotante_rotonda.icon = ico_rot
		_btn_flotante_rotonda.expand_icon = true
		_btn_flotante_rotonda.add_theme_constant_override("icon_max_width", 26)
	_btn_flotante_rotonda.pressed.connect(func():
		if _btn_flotante_rotonda.is_inside_tree():
			var tw := _btn_flotante_rotonda.create_tween()
			if tw:
				tw.tween_property(_btn_flotante_rotonda, "scale", Vector2(0.95, 0.95), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(_btn_flotante_rotonda, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		accion_colocar_solicitada.emit()
	)
	_btn_flotante_rotonda.visible = false
	_hbox_flotante_inferior.add_child(_btn_flotante_rotonda)
	_hbox_flotante_inferior.move_child(_btn_flotante_rotonda, 0)

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
		{"id": "muros", "nombre": "Muros", "ico": "cat_muros"},
		{"id": "parqueo", "nombre": "Parqueos", "ico": "cat_parqueo"},
		{"id": "concreto", "nombre": "Concreto", "ico": "cat_ciudad"},
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

	# Guardar Mapa directo (siempre visible en barra superior)
	var btn_guardar_hud := Button.new()
	btn_guardar_hud.name = "BtnGuardarMapaHUD"
	btn_guardar_hud.text = " Guardar"
	btn_guardar_hud.tooltip_text = "Guardar mapa actual"
	btn_guardar_hud.custom_minimum_size = Vector2(138, 52)
	btn_guardar_hud.add_theme_font_size_override("font_size", 18)
	if _fuente_ui:
		btn_guardar_hud.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_guardar_hud, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 12.0)
	btn_guardar_hud.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	btn_guardar_hud.add_theme_color_override("icon_normal_color", COLOR_AMARILLO_SEL)
	var ico_g := _cargar_icono_svg("act_guardar")
	if ico_g:
		btn_guardar_hud.icon = ico_g
		btn_guardar_hud.expand_icon = true
		btn_guardar_hud.add_theme_constant_override("icon_max_width", 24)
	btn_guardar_hud.pressed.connect(func(): guardar_mapa_solicitado.emit())
	box_derecha.add_child(btn_guardar_hud)

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
	btn_salir.pressed.connect(func(): get_tree().change_scene_to_file("res://mundo/editor_mapas/HubEditorMapas.tscn"))
	box_derecha.add_child(btn_salir)

# ── 2. PANEL FLOTANTE DE HERRAMIENTAS (ZONA C — IZQUIERDA) ───────────
func _construir_panel_herramientas(padre: Control) -> void:
	_panel_herramientas = PanelContainer.new()
	_panel_herramientas.name = "PanelHerramientasFlotante"
	_panel_herramientas.anchor_left = 0.0
	_panel_herramientas.anchor_right = 0.0
	_panel_herramientas.anchor_top = 1.0
	_panel_herramientas.anchor_bottom = 1.0
	_panel_herramientas.offset_left = 20.0
	_panel_herramientas.offset_top = -410.0
	_panel_herramientas.offset_right = 280.0
	_panel_herramientas.offset_bottom = -132.0
	_panel_herramientas.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_panel_herramientas, COLOR_PANEL, COLOR_BORDE, 18.0, 10.0)
	padre.add_child(_panel_herramientas)

	# Botón de colapso/expansión en el borde derecho (hermano del PanelContainer para no ser estirado)
	_btn_colapsar_herramientas = Button.new()
	_btn_colapsar_herramientas.name = "BtnColapsarHerramientas"
	_btn_colapsar_herramientas.text = "❮"
	_btn_colapsar_herramientas.anchor_left = 0.0
	_btn_colapsar_herramientas.anchor_right = 0.0
	_btn_colapsar_herramientas.anchor_top = 1.0
	_btn_colapsar_herramientas.anchor_bottom = 1.0
	_btn_colapsar_herramientas.offset_left = 284.0
	_btn_colapsar_herramientas.offset_right = 312.0
	_btn_colapsar_herramientas.offset_top = -300.0
	_btn_colapsar_herramientas.offset_bottom = -240.0
	_btn_colapsar_herramientas.custom_minimum_size = Vector2(28, 60)
	_estilar_boton(_btn_colapsar_herramientas, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
	_btn_colapsar_herramientas.add_theme_font_size_override("font_size", 18)
	_btn_colapsar_herramientas.pressed.connect(_alternar_colapso_herramientas)
	padre.add_child(_btn_colapsar_herramientas)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel_herramientas.add_child(margin)

	_box_herramientas = VBoxContainer.new()
	_box_herramientas.add_theme_constant_override("separation", 10)
	margin.add_child(_box_herramientas)

	_grid_herramientas = GridContainer.new()
	_grid_herramientas.columns = 3
	_grid_herramientas.add_theme_constant_override("h_separation", 10)
	_grid_herramientas.add_theme_constant_override("v_separation", 10)
	_box_herramientas.add_child(_grid_herramientas)

func _ajustar_tamano_panel_herramientas() -> void:
	if not is_instance_valid(_panel_herramientas) or _esta_colapsado_herramientas:
		return
	var min_sz := _panel_herramientas.get_combined_minimum_size()
	_panel_herramientas.anchor_top = 1.0
	_panel_herramientas.anchor_bottom = 1.0
	_panel_herramientas.offset_left = 20.0
	_panel_herramientas.offset_right = 20.0 + min_sz.x
	_panel_herramientas.offset_bottom = -132.0
	_panel_herramientas.offset_top = -132.0 - min_sz.y
	if is_instance_valid(_btn_colapsar_herramientas):
		var cy := -132.0 - (min_sz.y * 0.5)
		_btn_colapsar_herramientas.offset_left = 20.0 + min_sz.x + 4.0
		_btn_colapsar_herramientas.offset_right = _btn_colapsar_herramientas.offset_left + 28.0
		_btn_colapsar_herramientas.offset_top = cy - 30.0
		_btn_colapsar_herramientas.offset_bottom = cy + 30.0
	_posicionar_dock_camara_movil()

func _alternar_colapso_herramientas() -> void:
	_esta_colapsado_herramientas = not _esta_colapsado_herramientas
	_btn_colapsar_herramientas.text = "❯" if _esta_colapsado_herramientas else "❮"
	var ancho := _panel_herramientas.size.x
	if ancho < 50.0:
		ancho = _panel_herramientas.offset_right - _panel_herramientas.offset_left
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _esta_colapsado_herramientas:
		tween.tween_property(_panel_herramientas, "offset_left", 20.0 - ancho, 0.25)
		tween.parallel().tween_property(_panel_herramientas, "offset_right", 20.0, 0.25)
		tween.parallel().tween_property(_btn_colapsar_herramientas, "offset_left", 24.0, 0.25)
		tween.parallel().tween_property(_btn_colapsar_herramientas, "offset_right", 52.0, 0.25)
	else:
		tween.tween_property(_panel_herramientas, "offset_left", 20.0, 0.25)
		tween.parallel().tween_property(_panel_herramientas, "offset_right", 20.0 + ancho, 0.25)
		tween.parallel().tween_property(_btn_colapsar_herramientas, "offset_left", 24.0 + ancho, 0.25)
		tween.parallel().tween_property(_btn_colapsar_herramientas, "offset_right", 52.0 + ancho, 0.25)
	_posicionar_dock_camara_movil()

# ── 3. PANEL CONTEXTUAL DE PROPIEDADES (ZONA D — DERECHA) ─────────────
func _construir_panel_propiedades(padre: Control) -> void:
	_panel_propiedades = PanelContainer.new()
	_panel_propiedades.name = "PanelPropiedadesFlotante"
	_panel_propiedades.anchor_left = 1.0
	_panel_propiedades.anchor_right = 1.0
	_panel_propiedades.anchor_top = 0.0
	_panel_propiedades.anchor_bottom = 1.0
	_panel_propiedades.offset_left = -480.0
	_panel_propiedades.offset_right = -20.0
	_panel_propiedades.offset_top = 96.0
	_panel_propiedades.offset_bottom = -78.0
	_panel_propiedades.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_panel_propiedades, COLOR_PANEL, COLOR_BORDE, 18.0, 16.0)
	padre.add_child(_panel_propiedades)

	var vbox_main := VBoxContainer.new()
	vbox_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_main.add_theme_constant_override("separation", 14)
	_panel_propiedades.add_child(vbox_main)

	# Encabezado del Panel Contextual
	var hbox_header := HBoxContainer.new()
	hbox_header.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_theme_constant_override("separation", 10)
	vbox_main.add_child(hbox_header)

	_ico_prop_header = TextureRect.new()
	_ico_prop_header.custom_minimum_size = Vector2(32, 32)
	_ico_prop_header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ico_prop_header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_header.add_child(_ico_prop_header)

	_lbl_prop_titulo = Label.new()
	_lbl_prop_titulo.text = "Elevar Terreno"
	_lbl_prop_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_prop_titulo.clip_text = true
	_lbl_prop_titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_prop_titulo.add_theme_font_size_override("font_size", FONT_TITULO_SUB) # 26px
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
	sb_badge.content_margin_left = 10
	sb_badge.content_margin_right = 10
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
	_btn_colapsar_propiedades.custom_minimum_size = Vector2(32, 32)
	_estilar_boton(_btn_colapsar_propiedades, COLOR_PANEL_SEC, COLOR_BORDE, 8.0)
	_btn_colapsar_propiedades.add_theme_font_size_override("font_size", 18)
	_btn_colapsar_propiedades.pressed.connect(_alternar_colapso_propiedades)
	hbox_header.add_child(_btn_colapsar_propiedades)

	# Contenedor con scroll para evitar desbordes verticales en pantallas pequeñas o contenido largo
	_scroll_prop_contenido = ScrollContainer.new()
	_scroll_prop_contenido.name = "ScrollPropiedades"
	_scroll_prop_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_prop_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_prop_contenido.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_prop_contenido.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox_main.add_child(_scroll_prop_contenido)

	# Contenedor dinámico de controles de la herramienta activa
	_box_prop_contenido = VBoxContainer.new()
	_box_prop_contenido.name = "BoxPropContenido"
	_box_prop_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box_prop_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box_prop_contenido.add_theme_constant_override("separation", 16)
	_scroll_prop_contenido.add_child(_box_prop_contenido)

func _construir_panel_sliders(padre: Control) -> void:
	_panel_sliders = PanelContainer.new()
	_panel_sliders.name = "PanelSlidersSuperiorIzq"
	_panel_sliders.anchor_left = 0.0
	_panel_sliders.anchor_right = 0.0
	_panel_sliders.anchor_top = 0.0
	_panel_sliders.anchor_bottom = 0.0
	_panel_sliders.offset_left = 20.0
	_panel_sliders.offset_right = 430.0
	_panel_sliders.offset_top = 96.0
	_panel_sliders.offset_bottom = 260.0
	_panel_sliders.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_panel_sliders, COLOR_PANEL, COLOR_BORDE, 18.0, 14.0)
	_panel_sliders.visible = false
	padre.add_child(_panel_sliders)

	var vbox_s := VBoxContainer.new()
	vbox_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_s.add_theme_constant_override("separation", 10)
	_panel_sliders.add_child(vbox_s)

	var lbl_s := Label.new()
	lbl_s.text = "CONFIGURACIÓN DE PINCEL / PARÁMETROS"
	lbl_s.add_theme_font_size_override("font_size", 16)
	lbl_s.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui:
		lbl_s.add_theme_font_override("font", _fuente_ui)
	vbox_s.add_child(lbl_s)

	_box_sliders_contenido = VBoxContainer.new()
	_box_sliders_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box_sliders_contenido.add_theme_constant_override("separation", 12)
	vbox_s.add_child(_box_sliders_contenido)

func _limpiar_sliders_contenido() -> void:
	_dict_sliders.clear()
	_dict_readouts.clear()
	if is_instance_valid(_box_sliders_contenido):
		for c in _box_sliders_contenido.get_children():
			_box_sliders_contenido.remove_child(c)
			c.queue_free()

func _actualizar_panel_sliders() -> void:
	if not is_instance_valid(_panel_sliders) or not is_instance_valid(_box_sliders_contenido):
		return
	var tiene_sliders: bool = false
	for c in _box_sliders_contenido.get_children():
		if c is Control and not (c as Control).is_queued_for_deletion():
			tiene_sliders = true
			break
	_panel_sliders.visible = tiene_sliders
	if tiene_sliders:
		var h_tot: float = 54.0 + _box_sliders_contenido.get_combined_minimum_size().y
		_panel_sliders.custom_minimum_size.y = h_tot
		_panel_sliders.offset_bottom = _panel_sliders.offset_top + h_tot
		_panel_sliders.size.y = h_tot

func _asegurar_panel_propiedades_visible_y_expandido() -> void:
	if _panel_propiedades:
		_panel_propiedades.visible = true
		if _esta_colapsado_propiedades:
			_esta_colapsado_propiedades = false
			if _btn_colapsar_propiedades:
				_btn_colapsar_propiedades.text = "⌃"
			if _scroll_prop_contenido:
				_scroll_prop_contenido.visible = true
		call_deferred("_ajustar_tamano_panel_propiedades")

func _alternar_colapso_propiedades() -> void:
	_esta_colapsado_propiedades = not _esta_colapsado_propiedades
	_btn_colapsar_propiedades.text = "⌵" if _esta_colapsado_propiedades else "⌃"
	if _scroll_prop_contenido:
		_scroll_prop_contenido.visible = not _esta_colapsado_propiedades

	var vp_h: float = float(get_viewport().size.y) if get_viewport() else 720.0
	if is_inside_tree():
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if _esta_colapsado_propiedades:
			_panel_propiedades.custom_minimum_size.y = 0.0
			_panel_propiedades.anchor_bottom = 0.0
			_panel_propiedades.offset_bottom = vp_h - 78.0
			tween.tween_property(_panel_propiedades, "offset_bottom", _panel_propiedades.offset_top + 64.0, 0.25)
		else:
			_ajustar_tamano_panel_propiedades()
	else:
		if _esta_colapsado_propiedades:
			_panel_propiedades.custom_minimum_size.y = 0.0
			_panel_propiedades.anchor_bottom = 0.0
			_panel_propiedades.offset_bottom = _panel_propiedades.offset_top + 64.0
		else:
			_ajustar_tamano_panel_propiedades()

# ── ACTUALIZACIÓN DINÁMICA DEL PANEL CONTEXTUAL ─────────────────────
func _actualizar_panel_contextual(categoria: String, subherramienta: String) -> void:
	_categoria_activa = categoria
	_subherramienta_activa = subherramienta
	_id_item_activo = subherramienta
	if _btn_flotante_rotonda:
		var mostrar_btn_via: bool = (categoria == "vias") and (subherramienta in ["rotonda", "calle_1", "calle_2", "nacional", "avenida_4", "autopista_6", "doble_8", "adoquin", "recebo", "trocha", "ciclovia", "cruce_4", "cruce_t", "dividir"])
		var mostrar_btn_muro: bool = (categoria == "muros")
		var mostrar_btn_fin_parqueo: bool = (categoria == "parqueo") and _parqueo_hay_seleccion and (not _parqueo_finalizado)
		var mostrar_btn_parqueo: bool = (categoria == "parqueo") and (subherramienta in ["parqueo_crear", "parqueo_nivelar", "parqueo_borrar"]) and (not mostrar_btn_fin_parqueo)
		var mostrar_btn_fin_concreto: bool = (categoria == "concreto") and _concreto_hay_seleccion and (not _concreto_finalizado)
		var mostrar_btn_concreto: bool = (categoria == "concreto") and (subherramienta in ["concreto_crear", "concreto_nivelar", "concreto_borrar"]) and (not mostrar_btn_fin_concreto)
		var mostrar_btn_agua: bool = (categoria == "agua")
		var mostrar_btn_fin_rio: bool = (categoria == "agua") and (subherramienta == "rio")
		var mostrar_btn_auto_casas: bool = (categoria == "ciudad") and (subherramienta == "auto_casas")
		_btn_flotante_rotonda.visible = mostrar_btn_via or mostrar_btn_muro or mostrar_btn_parqueo or mostrar_btn_concreto or mostrar_btn_agua or mostrar_btn_auto_casas
		if _btn_flotante_finalizar_muro:
			_btn_flotante_finalizar_muro.visible = mostrar_btn_muro or mostrar_btn_fin_parqueo or mostrar_btn_fin_concreto or mostrar_btn_fin_rio
			_btn_flotante_finalizar_muro.text = "✓ FINALIZAR"
		if _hbox_flotante_inferior:
			_hbox_flotante_inferior.visible = _btn_flotante_rotonda.visible or (_btn_flotante_finalizar_muro != null and _btn_flotante_finalizar_muro.visible)
		if mostrar_btn_auto_casas:
			_btn_flotante_rotonda.text = "🏠 GENERAR CASAS"
			var ico_ac := _cargar_icono_svg("cat_ciudad")
			if ico_ac:
				_btn_flotante_rotonda.icon = ico_ac
		elif mostrar_btn_muro:
			_btn_flotante_rotonda.text = "＋ PUNTO"
			var ico_m := _cargar_icono_svg("cat_muros")
			if ico_m:
				_btn_flotante_rotonda.icon = ico_m
		elif mostrar_btn_agua:
			match subherramienta:
				"rio": _btn_flotante_rotonda.text = "＋ PUNTO RÍO"
				"cuenca": _btn_flotante_rotonda.text = "⬇ EXCAVAR CUENCA"
				"nivel": _btn_flotante_rotonda.text = "↕ SUBIR NIVEL"
				"limpiar": _btn_flotante_rotonda.text = "✕ BORRAR AGUA"
				_: _btn_flotante_rotonda.text = "＋ CREAR LAGO"
			var ico_a := _cargar_icono_svg("cat_agua")
			if ico_a:
				_btn_flotante_rotonda.icon = ico_a
		elif mostrar_btn_concreto:
			if subherramienta == "concreto_nivelar":
				_btn_flotante_rotonda.text = "⫶ NIVELAR"
			elif subherramienta == "concreto_borrar":
				_btn_flotante_rotonda.text = "✕ BORRAR"
			else:
				_btn_flotante_rotonda.text = "＋ CREAR CONCRETO"
			var ico_c := _cargar_icono_svg("cat_ciudad")
			if ico_c:
				_btn_flotante_rotonda.icon = ico_c
		elif mostrar_btn_parqueo:
			if subherramienta == "parqueo_nivelar":
				_btn_flotante_rotonda.text = "⫶ NIVELAR"
			elif subherramienta == "parqueo_borrar":
				_btn_flotante_rotonda.text = "✕ BORRAR"
			else:
				_btn_flotante_rotonda.text = "＋ CREAR PARQUEO"
			var ico_p := _cargar_icono_svg("cat_parqueo")
			if ico_p:
				_btn_flotante_rotonda.icon = ico_p
		elif mostrar_btn_via:
			var ico_id := "act_colocar"
			if subherramienta == "rotonda":
				_btn_flotante_rotonda.text = "＋ ROTONDA"
				ico_id = "via_rotonda"
			elif subherramienta in ["cruce_4", "cruce_t"]:
				_btn_flotante_rotonda.text = "＋ CRUCE"
				ico_id = "via_" + subherramienta
			elif subherramienta == "dividir":
				_btn_flotante_rotonda.text = "＋ INSERTAR NODO"
				ico_id = "via_dividir"
			else:
				_btn_flotante_rotonda.text = "＋ PUNTO DE VÍA"
				ico_id = "act_colocar"
			var ico_b := _cargar_icono_svg(ico_id)
			if ico_b:
				_btn_flotante_rotonda.icon = ico_b

	for child in _box_prop_contenido.get_children():
		_box_prop_contenido.remove_child(child)
		child.queue_free()
	_limpiar_sliders_contenido()
	mostrar_boton_centrar_seleccion(false)

	var info_tool = _obtener_metadatos_herramienta(categoria, subherramienta)
	_lbl_prop_titulo.text = info_tool["titulo"]
	var tex_ico = _cargar_icono_svg(info_tool["icono"])
	if tex_ico:
		_ico_prop_header.texture = tex_ico

	match categoria:
		"terreno":
			if subherramienta == "follaje":
				_construir_vista_pintar_follaje()
			elif subherramienta.begins_with("pintar") or subherramienta in ["cesped", "tierra", "roca"]:
				_construir_vista_pintar_textura(subherramienta)
			else:
				match subherramienta:
					"elevar", "bajar", "suavizar", "pendiente":
						_construir_vista_esculpido_terreno(subherramienta)
					"aplanar":
						_construir_vista_aplanar_terreno()
					"agua", "lago":
						_construir_vista_lago()
					"rio":
						_construir_vista_rio()
					_:
						_construir_vista_esculpido_terreno("elevar")
		"vias":
			_construir_vista_vias_general(subherramienta)
		"ciudad":
			match subherramienta:
				"res": _seccion_biblioteca_activa = "01_Residencial"
				"com": _seccion_biblioteca_activa = "02_Comercial"
				"ind": _seccion_biblioteca_activa = "03_Industrial_Logistica"
				"inst": _seccion_biblioteca_activa = "04_Servicios_Publicos"
				"zonas": _seccion_biblioteca_activa = "05_Zonas_Logistica"
				"hist": _seccion_biblioteca_activa = "todos"
			_construir_vista_ciudad()
		"vegetacion":
			_construir_vista_vegetacion()
		"muros":
			_construir_vista_muros()
		"parqueo":
			_construir_vista_parqueo()
			mostrar_boton_centrar_seleccion(_parqueo_hay_seleccion)
		"concreto":
			_construir_vista_concreto()
			mostrar_boton_centrar_seleccion(_concreto_hay_seleccion)
		"agua":
			match subherramienta:
				"rio": _construir_vista_rio()
				"cuenca": _construir_vista_cuenca()
				"nivel": _construir_vista_nivel_agua()
				"limpiar": _construir_vista_limpiar_agua()
				_: _construir_vista_lago()
		"spawn":
			_construir_vista_spawn()
	call_deferred("_ajustar_tamano_panel_propiedades")

func _ajustar_tamano_panel_propiedades() -> void:
	if not is_instance_valid(_panel_propiedades) or _esta_colapsado_propiedades:
		return
	var vp_h: float = _contenedor_raiz.size.y if (is_instance_valid(_contenedor_raiz) and _contenedor_raiz.size.y > 100.0) else (get_viewport().get_visible_rect().size.y if get_viewport() else 720.0)
	var max_panel_h: float = maxf(260.0, vp_h - _panel_propiedades.offset_top - 84.0)
	var header_y_margenes: float = 132.0
	var max_scroll_h: float = maxf(120.0, max_panel_h - header_y_margenes)

	var box_h: float = 0.0
	if is_instance_valid(_box_prop_contenido):
		if not _box_prop_contenido.minimum_size_changed.is_connected(_ajustar_tamano_panel_propiedades):
			_box_prop_contenido.minimum_size_changed.connect(_ajustar_tamano_panel_propiedades)
		var sep: float = float(_box_prop_contenido.get_theme_constant("separation"))
		var vis_count: int = 0
		for c in _box_prop_contenido.get_children():
			if c is Control and (c as Control).visible and not (c as Control).is_queued_for_deletion():
				box_h += (c as Control).get_combined_minimum_size().y
				vis_count += 1
		if vis_count > 1:
			box_h += sep * float(vis_count - 1)
		box_h = maxf(box_h, _box_prop_contenido.get_combined_minimum_size().y) + 10.0

	var necesita_scroll: bool = (box_h > max_scroll_h)
	var scroll_h: float = max_scroll_h if necesita_scroll else maxf(60.0, box_h)
	if is_instance_valid(_scroll_prop_contenido):
		_scroll_prop_contenido.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if necesita_scroll else ScrollContainer.SCROLL_MODE_DISABLED
		_scroll_prop_contenido.custom_minimum_size.y = scroll_h

	var target_h: float = clampf(scroll_h + header_y_margenes, 200.0, max_panel_h)
	_panel_propiedades.anchor_bottom = 0.0
	_panel_propiedades.custom_minimum_size.y = target_h
	_panel_propiedades.offset_bottom = _panel_propiedades.offset_top + target_h
	_panel_propiedades.size.y = target_h

	_actualizar_panel_sliders()
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

	# 3B. Vistas de Información Topográfica (estilo CS2)
	var lbl_iv := Label.new()
	lbl_iv.text = "Info Vista (Topografía)"
	lbl_iv.add_theme_font_size_override("font_size", FONT_LABEL_SLIDER)
	lbl_iv.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_iv.add_theme_font_override("font", _fuente_ui)
	_box_prop_contenido.add_child(lbl_iv)

	var hbox_iv := HBoxContainer.new()
	hbox_iv.add_theme_constant_override("separation", 6)
	_box_prop_contenido.add_child(hbox_iv)
	for iv in [
		{"id": 0, "nom": "Normal"},
		{"id": 1, "nom": "Curvas"},
		{"id": 2, "nom": "Pend.%"},
		{"id": 3, "nom": "Altura"}
	]:
		var btn_iv := Button.new()
		btn_iv.text = iv["nom"]
		btn_iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_iv.custom_minimum_size = Vector2(0, 44)
		btn_iv.add_theme_font_size_override("font_size", 17)
		var act_iv: bool = (_info_vista_actual == int(iv["id"]))
		_estilar_boton(btn_iv, COLOR_AMARILLO_SEL if act_iv else COLOR_PANEL_SEC, COLOR_AMARILLO_PRI if act_iv else COLOR_BORDE, 8.0)
		btn_iv.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL if act_iv else COLOR_TEXTO_PRI)
		if _fuente_ui:
			btn_iv.add_theme_font_override("font", _fuente_ui)
		var iv_id := int(iv["id"])
		btn_iv.pressed.connect(func():
			_info_vista_actual = iv_id
			info_vista_cambiada.emit(iv_id)
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		hbox_iv.add_child(btn_iv)

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

func _aplicar_estilo_boton_opcion(btn: Button, es_activo: bool) -> void:
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

func _actualizar_estilo_botones_perfil() -> void:
	for p_idx in _dict_botones_perfil:
		_aplicar_estilo_boton_opcion(_dict_botones_perfil[p_idx], p_idx == _perfil_pincel_activo)

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
		altura_objetivo_terreno_cambiada.emit(val)
	)
	_crear_botones_accion_inferiores(
		func():
			_radio_pincel = 25.0
			_fuerza_pincel = 0.50
			_altura_objetivo_terreno = 10.0
			_actualizar_slider_val("Radio del pincel", 25.0)
			_actualizar_slider_val("Fuerza", 0.50)
			_actualizar_slider_val("Altura meta", 10.0)
			radio_pincel_cambiado.emit(25.0)
			fuerza_pincel_cambiada.emit(0.50)
			altura_objetivo_terreno_cambiada.emit(10.0),
		func():
			accion_colocar_solicitada.emit()
	)

# C. Pintar Textura (Pincel general con selector de material del suelo)
func _construir_vista_pintar_textura(id_textura: String) -> void:
	var ids_validos: Array[String] = []
	for m in ControladorTerreno.MATERIALES_PINTURA:
		ids_validos.append(m["id"])
	if id_textura in ids_validos:
		_material_pintura_activo = id_textura

	# 1. Selector de Material del suelo (Cuadrícula 3x3 con vista previa real)
	var vbox_mat := VBoxContainer.new()
	vbox_mat.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(vbox_mat)

	var hbox_etq_mat := HBoxContainer.new()
	hbox_etq_mat.add_theme_constant_override("separation", 10)
	vbox_mat.add_child(hbox_etq_mat)

	var ico_mat := TextureRect.new()
	ico_mat.texture = _cargar_icono_svg("terreno_pintar")
	ico_mat.custom_minimum_size = Vector2(26, 26)
	ico_mat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico_mat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox_etq_mat.add_child(ico_mat)

	var lbl_mat := Label.new()
	lbl_mat.text = "Biblioteca de Materiales"
	lbl_mat.add_theme_font_size_override("font_size", FONT_LABEL_SLIDER)
	lbl_mat.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_mat.add_theme_font_override("font", _fuente_ui)
	hbox_etq_mat.add_child(lbl_mat)

	var hbox_filt_mat := HBoxContainer.new()
	hbox_filt_mat.add_theme_constant_override("separation", 6)
	vbox_mat.add_child(hbox_filt_mat)
	for f_cat in [
		{"id": "todos", "nom": "Todos"},
		{"id": "pastos", "nom": "Pastos"},
		{"id": "suelos", "nom": "Suelos"},
		{"id": "rocas", "nom": "Rocas"}
	]:
		var btn_fc := Button.new()
		btn_fc.text = f_cat["nom"]
		btn_fc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_fc.custom_minimum_size = Vector2(0, 42)
		btn_fc.add_theme_font_size_override("font_size", 16)
		if _fuente_ui:
			btn_fc.add_theme_font_override("font", _fuente_ui)
		var cat_id: String = f_cat["id"]
		var act_fc: bool = (_filtro_categoria_material == cat_id)
		_estilar_boton(btn_fc, COLOR_AMARILLO_SEL if act_fc else COLOR_PANEL_SEC, COLOR_AMARILLO_PRI if act_fc else COLOR_BORDE, 8.0)
		btn_fc.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL if act_fc else COLOR_TEXTO_PRI)
		btn_fc.pressed.connect(func():
			_filtro_categoria_material = cat_id
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		hbox_filt_mat.add_child(btn_fc)

	var grid_btns_mat := GridContainer.new()
	grid_btns_mat.columns = 3
	grid_btns_mat.add_theme_constant_override("h_separation", 8)
	grid_btns_mat.add_theme_constant_override("v_separation", 8)
	vbox_mat.add_child(grid_btns_mat)

	_dict_botones_material.clear()
	for m in ControladorTerreno.MATERIALES_PINTURA:
		if _filtro_categoria_material != "todos" and str(m.get("categoria", "")) != _filtro_categoria_material:
			continue
		var btn_m := Button.new()
		btn_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_m.custom_minimum_size = Vector2(0, 124)
		btn_m.text = m["nombre"]
		btn_m.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_m.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn_m.clip_text = true
		btn_m.add_theme_font_size_override("font_size", 18)
		if _fuente_ui:
			btn_m.add_theme_font_override("font", _fuente_ui)

		var tex_prev: Texture2D = null
		if ResourceLoader.exists(m["albedo"]):
			tex_prev = load(m["albedo"]) as Texture2D
		elif ResourceLoader.exists(m["fallback"]):
			tex_prev = load(m["fallback"]) as Texture2D
		if tex_prev:
			btn_m.icon = tex_prev
			btn_m.expand_icon = true
			btn_m.add_theme_constant_override("icon_max_width", 74)

		var mat_id: String = m["id"]
		btn_m.pressed.connect(func(): _seleccionar_material_pintura(mat_id))
		grid_btns_mat.add_child(btn_m)
		_dict_botones_material[mat_id] = btn_m

	_actualizar_estilo_botones_material()

	# 1.5 Vista previa cuadrada ampliada del material seleccionado
	var vbox_prev := VBoxContainer.new()
	vbox_prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_prev.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_prev.add_theme_constant_override("separation", 8)
	_box_prop_contenido.add_child(vbox_prev)

	var marco_tex := PanelContainer.new()
	marco_tex.custom_minimum_size = Vector2(260, 260)
	marco_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_estilar_panel_glass(marco_tex, Color(0.05, 0.06, 0.08, 1.0), COLOR_BORDE_ACTIVO, 16.0, 8.0)
	vbox_prev.add_child(marco_tex)

	_preview_mat_tex = TextureRect.new()
	_preview_mat_tex.custom_minimum_size = Vector2(244, 244)
	_preview_mat_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_mat_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	marco_tex.add_child(_preview_mat_tex)

	_preview_mat_nombre = Label.new()
	_preview_mat_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_mat_nombre.add_theme_font_size_override("font_size", 25)
	_preview_mat_nombre.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui:
		_preview_mat_nombre.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(_preview_mat_nombre)

	_preview_mat_tipo = Label.new()
	_preview_mat_tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_mat_tipo.add_theme_font_size_override("font_size", 16)
	_preview_mat_tipo.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		_preview_mat_tipo.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(_preview_mat_tipo)

	_preview_mat_desc = Label.new()
	_preview_mat_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_mat_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_mat_desc.add_theme_font_size_override("font_size", 15)
	_preview_mat_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		_preview_mat_desc.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(_preview_mat_desc)

	_actualizar_preview_material_pintura()

	# 2. Parámetros del pincel
	_crear_fila_slider("Radio del pincel", "ico_pincel_radio", 3.0, 150.0, _radio_pincel, "m", 1.0, func(val):
		_radio_pincel = val
		radio_pincel_cambiado.emit(val)
	)
	_crear_fila_slider("Opacidad de pintura", "ico_fuerza", 0.1, 1.0, _opacidad_textura, "", 0.05, func(val):
		_opacidad_textura = val
		fuerza_pincel_cambiada.emit(val)
	)
	_crear_fila_slider("Suavizado de borde", "ico_curva_suave", 0.0, 1.0, _suavizado_borde_pintura, "", 0.05, func(val):
		_suavizado_borde_pintura = val
		suavizado_borde_cambiado.emit(val)
	)
	_crear_botones_accion_inferiores(
		func():
			_radio_pincel = 30.0
			_opacidad_textura = 0.85
			_suavizado_borde_pintura = 0.30
			_actualizar_slider_val("Radio del pincel", 30.0)
			_actualizar_slider_val("Opacidad de pintura", 0.85)
			_actualizar_slider_val("Suavizado de borde", 0.30)
			radio_pincel_cambiado.emit(30.0)
			fuerza_pincel_cambiada.emit(0.85)
			suavizado_borde_cambiado.emit(0.30)
			_seleccionar_material_pintura("cesped_verde"),
		func():
			accion_colocar_solicitada.emit()
	)

func _seleccionar_material_pintura(mat_id: String) -> void:
	_material_pintura_activo = mat_id
	_actualizar_estilo_botones_material()
	_actualizar_preview_material_pintura()
	_actualizar_etiqueta_estado()
	material_pintura_cambiado.emit(mat_id)

func _actualizar_preview_material_pintura() -> void:
	if not is_instance_valid(_preview_mat_tex):
		return
	for m in ControladorTerreno.MATERIALES_PINTURA:
		if m["id"] == _material_pintura_activo:
			var tex: Texture2D = null
			if ResourceLoader.exists(m["albedo"]):
				tex = load(m["albedo"]) as Texture2D
			elif ResourceLoader.exists(m["fallback"]):
				tex = load(m["fallback"]) as Texture2D
			_preview_mat_tex.texture = tex
			if is_instance_valid(_preview_mat_nombre):
				_preview_mat_nombre.text = m["nombre"]
			if is_instance_valid(_preview_mat_tipo):
				_preview_mat_tipo.text = "Tipo: " + m.get("tipo", "Terreno")
			if is_instance_valid(_preview_mat_desc):
				_preview_mat_desc.text = m.get("descripcion", "")
			return

func _actualizar_estilo_botones_material() -> void:
	for mat_id in _dict_botones_material:
		var btn: Button = _dict_botones_material[mat_id]
		_aplicar_estilo_boton_opcion(btn, mat_id == _material_pintura_activo)
		# Mantener las miniaturas de textura en su color real sin teñirlas
		btn.add_theme_color_override("icon_normal_color", Color.WHITE)
		btn.add_theme_color_override("icon_hover_color", Color.WHITE)
		btn.add_theme_color_override("icon_pressed_color", Color.WHITE)

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
		agua_rio_limpiar_solicitado.emit()
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
		agua_rio_finalizar_solicitado.emit()
	)
	hbox_acts.add_child(btn_fin)

func _construir_vista_cuenca() -> void:
	_crear_fila_slider("Radio de cuenca", "ico_pincel_radio", 6.0, 80.0, _radio_lago, "m", 1.0, func(val):
		_radio_lago = val
	)
	_crear_fila_slider("Profundidad excavación", "ico_fuerza", 1.0, 18.0, _profundidad_lago, "m", 0.5, func(val):
		_profundidad_lago = val
	)
	var lbl := Label.new()
	lbl.text = "Toca el terreno para excavar una cuenca seca lista para llenar con agua."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl.add_theme_font_override("font", _fuente_ui)
	_box_prop_contenido.add_child(lbl)

func _construir_vista_nivel_agua() -> void:
	var lbl := Label.new()
	lbl.text = "Toca un lago o río para seleccionarlo y ajusta su altura de superficie:"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl.add_theme_font_override("font", _fuente_ui)
	_box_prop_contenido.add_child(lbl)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox)
	for paso in [{"t": "-1.0m", "d": -1.0}, {"t": "-0.25m", "d": -0.25}, {"t": "+0.25m", "d": 0.25}, {"t": "+1.0m", "d": 1.0}]:
		var b := Button.new()
		b.text = paso["t"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		b.add_theme_font_size_override("font_size", 20)
		_estilar_boton(b, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
		if _fuente_ui:
			b.add_theme_font_override("font", _fuente_ui)
		var dv: float = float(paso["d"])
		b.pressed.connect(func(): agua_nivel_delta_solicitado.emit(dv))
		hbox.add_child(b)

func _construir_vista_limpiar_agua() -> void:
	var lbl := Label.new()
	lbl.text = "Toca sobre cualquier lago o río en el mapa para eliminarlo, o usa el botón inferior para limpiar toda el agua."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl.add_theme_font_override("font", _fuente_ui)
	_box_prop_contenido.add_child(lbl)

	var btn_all := Button.new()
	btn_all.text = "✕ Eliminar Toda el Agua"
	btn_all.custom_minimum_size = Vector2(0, 58)
	btn_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_all.add_theme_font_size_override("font_size", 21)
	_estilar_boton(btn_all, COLOR_CRIMSON_SALIR, Color(1.0, 0.45, 0.45, 0.7), 10.0)
	btn_all.add_theme_color_override("font_color", Color.WHITE)
	if _fuente_ui:
		btn_all.add_theme_font_override("font", _fuente_ui)
	btn_all.pressed.connect(func(): agua_limpiar_todo_solicitado.emit())
	_box_prop_contenido.add_child(btn_all)

# E2. Pintar Follaje 3D (Terrain3DInstancer)
func _construir_vista_pintar_follaje() -> void:
	var vbox_fol := VBoxContainer.new()
	vbox_fol.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(vbox_fol)

	var lbl_tit := Label.new()
	lbl_tit.text = "Biblioteca de Follaje 3D"
	lbl_tit.add_theme_font_size_override("font_size", FONT_LABEL_SLIDER)
	lbl_tit.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_tit.add_theme_font_override("font", _fuente_ui)
	vbox_fol.add_child(lbl_tit)

	var hbox_filt := HBoxContainer.new()
	hbox_filt.add_theme_constant_override("separation", 6)
	vbox_fol.add_child(hbox_filt)
	for f_cat in [
		{"id": "todos", "nom": "Todos"},
		{"id": "pastos", "nom": "Césped 3D"},
		{"id": "flores", "nom": "Flores"},
		{"id": "arbustos", "nom": "Arbustos"}
	]:
		var btn_fc := Button.new()
		btn_fc.text = f_cat["nom"]
		btn_fc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_fc.custom_minimum_size = Vector2(0, 42)
		btn_fc.add_theme_font_size_override("font_size", 15)
		if _fuente_ui:
			btn_fc.add_theme_font_override("font", _fuente_ui)
		var cat_id: String = f_cat["id"]
		var act_fc: bool = (_filtro_categoria_follaje == cat_id)
		_estilar_boton(btn_fc, COLOR_AMARILLO_SEL if act_fc else COLOR_PANEL_SEC, COLOR_AMARILLO_PRI if act_fc else COLOR_BORDE, 8.0)
		btn_fc.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL if act_fc else COLOR_TEXTO_PRI)
		btn_fc.pressed.connect(func():
			_filtro_categoria_follaje = cat_id
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		hbox_filt.add_child(btn_fc)

	var grid_fol := GridContainer.new()
	grid_fol.columns = 3
	grid_fol.add_theme_constant_override("h_separation", 8)
	grid_fol.add_theme_constant_override("v_separation", 8)
	vbox_fol.add_child(grid_fol)

	var info_sel: Dictionary = ControladorTerreno.FOLLAJE_CATALOGO[0]
	for f_info in ControladorTerreno.FOLLAJE_CATALOGO:
		if f_info["id"] == _follaje_pintura_activo:
			info_sel = f_info
		if _filtro_categoria_follaje != "todos" and str(f_info.get("categoria", "")) != _filtro_categoria_follaje:
			continue
		var btn_f := Button.new()
		btn_f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_f.custom_minimum_size = Vector2(0, 122)
		btn_f.text = f_info["nombre"]
		btn_f.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_f.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn_f.clip_text = true
		btn_f.add_theme_font_size_override("font_size", 17)
		if _fuente_ui:
			btn_f.add_theme_font_override("font", _fuente_ui)
		if ResourceLoader.exists(f_info["tex"]):
			btn_f.icon = load(f_info["tex"]) as Texture2D
			btn_f.expand_icon = true
			btn_f.add_theme_constant_override("icon_max_width", 72)
		var fid: String = f_info["id"]
		var es_sel: bool = (fid == _follaje_pintura_activo)
		_estilar_boton(btn_f, Color(0.18, 0.14, 0.07, 0.94) if es_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if es_sel else COLOR_BORDE, 10.0)
		btn_f.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if es_sel else COLOR_TEXTO_PRI)
		btn_f.pressed.connect(func():
			_follaje_pintura_activo = fid
			_escala_follaje = float(f_info.get("escala", 100.0))
			follaje_pintura_cambiado.emit(fid)
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		grid_fol.add_child(btn_f)

	# Tarjeta de vista previa grande del follaje seleccionado
	var card_prev := PanelContainer.new()
	_estilar_panel_glass(card_prev, Color(0.08, 0.09, 0.11, 0.92), COLOR_BORDE_ACTIVO, 14.0, 12.0)
	_box_prop_contenido.add_child(card_prev)
	var vbox_prev_f := VBoxContainer.new()
	vbox_prev_f.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_prev_f.add_theme_constant_override("separation", 8)
	card_prev.add_child(vbox_prev_f)

	var marco_f := PanelContainer.new()
	marco_f.custom_minimum_size = Vector2(256, 256)
	marco_f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_estilar_panel_glass(marco_f, Color(0.05, 0.06, 0.08, 1.0), Color(0.88, 0.68, 0.28, 0.55), 14.0, 8.0)
	vbox_prev_f.add_child(marco_f)

	var tex_prev := TextureRect.new()
	tex_prev.custom_minimum_size = Vector2(240, 240)
	tex_prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(str(info_sel["tex"])):
		tex_prev.texture = load(str(info_sel["tex"])) as Texture2D
	marco_f.add_child(tex_prev)

	var lbl_nom := Label.new()
	lbl_nom.text = str(info_sel["nombre"])
	lbl_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nom.add_theme_font_size_override("font_size", 24)
	lbl_nom.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui:
		lbl_nom.add_theme_font_override("font", _fuente_ui)
	vbox_prev_f.add_child(lbl_nom)

	var lbl_tipo := Label.new()
	lbl_tipo.text = str(info_sel.get("tipo", ""))
	lbl_tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tipo.add_theme_font_size_override("font_size", 18)
	lbl_tipo.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_tipo.add_theme_font_override("font", _fuente_ui)
	vbox_prev_f.add_child(lbl_tipo)

	var lbl_desc := Label.new()
	lbl_desc.text = str(info_sel.get("descripcion", ""))
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", 17)
	lbl_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_desc.add_theme_font_override("font", _fuente_ui)
	vbox_prev_f.add_child(lbl_desc)

	# Modo Pintar / Borrar
	var hbox_modo := HBoxContainer.new()
	hbox_modo.add_theme_constant_override("separation", 8)
	_box_prop_contenido.add_child(hbox_modo)
	for m_cfg in [{"borrar": false, "nom": "＋ Pintar Follaje"}, {"borrar": true, "nom": "✕ Borrar Follaje"}]:
		var btn_md := Button.new()
		btn_md.text = m_cfg["nom"]
		btn_md.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_md.custom_minimum_size = Vector2(0, 54)
		btn_md.add_theme_font_size_override("font_size", 20)
		if _fuente_ui:
			btn_md.add_theme_font_override("font", _fuente_ui)
		var es_b: bool = bool(m_cfg["borrar"])
		var act_md: bool = (_borrar_follaje_activo == es_b)
		var col_b := COLOR_CRIMSON_SALIR if (es_b and act_md) else (COLOR_AMARILLO_SEL if act_md else COLOR_PANEL_SEC)
		var brd_b := Color(1.0, 0.45, 0.45, 0.85) if (es_b and act_md) else (COLOR_AMARILLO_PRI if act_md else COLOR_BORDE)
		_estilar_boton(btn_md, col_b, brd_b, 10.0)
		btn_md.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL if (act_md and not es_b) else Color.WHITE)
		btn_md.pressed.connect(func():
			_borrar_follaje_activo = es_b
			borrar_follaje_alternado.emit(es_b)
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		hbox_modo.add_child(btn_md)

	_crear_fila_slider("Radio del pincel", "ico_pincel_radio", 3.0, 150.0, _radio_pincel, "m", 1.0, func(val):
		_radio_pincel = val
		radio_pincel_cambiado.emit(val)
	)
	_crear_fila_slider("Densidad follaje", "ico_pincel_fuerza", 10.0, 100.0, _densidad_follaje * 100.0, "%", 5.0, func(val):
		_densidad_follaje = val / 100.0
		densidad_follaje_cambiada.emit(_densidad_follaje)
	)
	_crear_fila_slider("Escala follaje", "act_rotar", 40.0, 250.0, _escala_follaje, "%", 5.0, func(val):
		_escala_follaje = val
		escala_follaje_cambiada.emit(val)
	)

# F. Vías General
func _construir_vista_vias_general(tipo_via: String) -> void:
	var lbl_desc := Label.new()
	if tipo_via == "rotonda":
		lbl_desc.text = "Elige el número de salidas, ubica la vista previa en el terreno y pulsa 'COLOCAR ROTONDA'."
	elif tipo_via in ["cruce_4", "cruce_t"]:
		lbl_desc.text = "Ubica la vista previa del cruce sobre el terreno y pulsa 'Colocar Cruce'."
	elif tipo_via == "dividir":
		lbl_desc.text = "Apunta sobre un tramo de vía existente para insertar un nuevo nodo intermedio."
	elif tipo_via == "conectar":
		lbl_desc.text = "Toca dos puntos finales de vía para unirlos automáticamente."
	elif tipo_via == "nivelar":
		lbl_desc.text = "Ajusta la altura del terreno bajo todas las vías existentes."
	else:
		lbl_desc.text = "Toca o arrastra sobre el terreno para orientar la vía y pulsa 'Colocar Punto de Vía' para trazar tramos continuos."
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", FONT_TEXTO_INFO) # 18px
	lbl_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_desc.add_theme_font_override("font", _fuente_ui)
	_box_prop_contenido.add_child(lbl_desc)

	var vbox_acciones := VBoxContainer.new()
	vbox_acciones.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(vbox_acciones)

	if tipo_via == "rotonda":
		var lbl_sal := Label.new()
		lbl_sal.text = "Salidas de la Rotonda"
		lbl_sal.add_theme_font_size_override("font_size", 18)
		lbl_sal.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
		if _fuente_ui:
			lbl_sal.add_theme_font_override("font", _fuente_ui)
		vbox_acciones.add_child(lbl_sal)

		var hbox_sal := HBoxContainer.new()
		hbox_sal.add_theme_constant_override("separation", 8)
		vbox_acciones.add_child(hbox_sal)
		var botones_sal: Array[Button] = []
		for n_sal: int in [3, 4, 5, 6]:
			var btn_sal := Button.new()
			btn_sal.text = "%d" % n_sal
			btn_sal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _fuente_ui:
				btn_sal.add_theme_font_override("font", _fuente_ui)
			var es_sel: bool = (n_sal == _rotonda_salidas_activa)
			btn_sal.custom_minimum_size = Vector2(0, 54)
			btn_sal.add_theme_font_size_override("font_size", FONT_BOTON_ACCION) # 24px
			_estilar_boton(btn_sal, COLOR_AMARILLO_SEL if es_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_PRI if es_sel else COLOR_BORDE, 10.0)
			btn_sal.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL if es_sel else COLOR_TEXTO_PRI)
			btn_sal.set_meta("salidas", n_sal)
			btn_sal.pressed.connect(func():
				_rotonda_salidas_activa = n_sal
				for b_item: Button in botones_sal:
					var b_n: int = int(b_item.get_meta("salidas", 4))
					var b_act: bool = (b_n == _rotonda_salidas_activa)
					_estilar_boton(b_item, COLOR_AMARILLO_SEL if b_act else COLOR_PANEL_SEC, COLOR_AMARILLO_PRI if b_act else COLOR_BORDE, 10.0)
					b_item.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL if b_act else COLOR_TEXTO_PRI)
				rotonda_salidas_cambiada.emit(_rotonda_salidas_activa)
			)
			hbox_sal.add_child(btn_sal)
			botones_sal.append(btn_sal)

	# El botón principal de colocación está centrado en la parte inferior (_btn_flotante_rotonda)

	var es_trazo_via: bool = tipo_via in ["calle_1", "calle_2", "nacional", "avenida_4", "autopista_6", "doble_8", "adoquin", "recebo", "trocha", "ciclovia"]
	var es_cruce: bool = tipo_via in ["cruce_4", "cruce_t"]

	if es_trazo_via:
		var ruta_prev_via := "res://recursos/iconos_editor/vias/via_%s.png" % tipo_via
		if ResourceLoader.exists(ruta_prev_via):
			var panel_pv := PanelContainer.new()
			var sb_pv := StyleBoxFlat.new()
			sb_pv.bg_color = Color(0.08, 0.09, 0.11, 0.90)
			sb_pv.border_color = COLOR_BORDE
			sb_pv.set_border_width_all(1)
			sb_pv.set_corner_radius_all(12)
			sb_pv.set_content_margin_all(8)
			panel_pv.add_theme_stylebox_override("panel", sb_pv)
			var hbox_pv := HBoxContainer.new()
			hbox_pv.add_theme_constant_override("separation", 10)
			panel_pv.add_child(hbox_pv)
			var tex_pv := TextureRect.new()
			tex_pv.texture = load(ruta_prev_via)
			tex_pv.custom_minimum_size = Vector2(92, 92)
			tex_pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox_pv.add_child(tex_pv)
			var info_vias := {
				"calle_1": ["Calle 1 Carril", "1 carril unidireccional (4.8 m). Ideal para callejones y accesos."],
				"calle_2": ["Calle Urbana 2C", "2 carriles (8.8 m) con berma estándar y línea discontinua."],
				"nacional": ["Carretera Nacional", "2 carriles anchos (12.4 m), berma amplia y doble línea amarilla."],
				"avenida_4": ["Avenida 4 Carriles", "4 carriles (16.4 m) urbanos de alto flujo."],
				"autopista_6": ["Autopista 6 Carriles", "6 carriles (25.2 m) con bermas amplias."],
				"doble_8": ["Doble Calzada 8C", "8 carriles (33.2 m) de gran capacidad y doble amarilla."],
				"adoquin": ["Vía Adoquinada", "2 carriles (7.8 m) estilo pueblo colonial en adoquín."],
				"recebo": ["Vía en Recebo", "2 carriles (8.0 m) en grava compactada sin demarcación."],
				"trocha": ["Trocha Rural", "2 carriles (7.4 m) en tierra con huellones 3D."],
				"ciclovia": ["Ciclovía / Sendero", "1 carril (3.2 m) en superficie terracota para bicicletas."]
			}
			var d_via: Array = info_vias.get(tipo_via, ["Vía", "Selecciona puntos sobre el terreno para trazar."])
			var vb_txt := VBoxContainer.new()
			vb_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vb_txt.alignment = BoxContainer.ALIGNMENT_CENTER
			var lbl_t := Label.new()
			lbl_t.text = str(d_via[0])
			lbl_t.add_theme_font_size_override("font_size", 18)
			lbl_t.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
			if _fuente_ui: lbl_t.add_theme_font_override("font", _fuente_ui)
			vb_txt.add_child(lbl_t)
			var lbl_d := Label.new()
			lbl_d.text = str(d_via[1])
			lbl_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl_d.add_theme_font_size_override("font_size", 14)
			lbl_d.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
			if _fuente_ui: lbl_d.add_theme_font_override("font", _fuente_ui)
			vb_txt.add_child(lbl_d)
			hbox_pv.add_child(vb_txt)
			vbox_acciones.add_child(panel_pv)

	if es_trazo_via or tipo_via == "nivelar":
		_crear_fila_slider("Altura Puente / Pilares", "act_nivelar", 1.5, 10.0, _umbral_puente_vias, "m", 0.5, func(v: float):
			_umbral_puente_vias = v
			umbral_altura_puente_cambiado.emit(v)
		)

	# 2. ACCIONES CONTEXTUALES ESTRICTAS SEGÚN LA HERRAMIENTA ACTIVA
	if es_trazo_via:
		var btn_terminar := Button.new()
		btn_terminar.text = "✓ Finalizar Tramo de Vía"
		btn_terminar.custom_minimum_size = Vector2(0, 50)
		btn_terminar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
		_estilar_boton(btn_terminar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
		if _fuente_ui:
			btn_terminar.add_theme_font_override("font", _fuente_ui)
		btn_terminar.pressed.connect(func(): terminar_tramo_via_solicitado.emit())
		vbox_acciones.add_child(btn_terminar)

		var btn_deshacer_pto := Button.new()
		btn_deshacer_pto.text = "↶ Deshacer Último Punto"
		btn_deshacer_pto.custom_minimum_size = Vector2(0, 50)
		btn_deshacer_pto.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
		_estilar_boton(btn_deshacer_pto, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
		if _fuente_ui:
			btn_deshacer_pto.add_theme_font_override("font", _fuente_ui)
		btn_deshacer_pto.pressed.connect(func(): deshacer_punto_via_solicitado.emit())
		vbox_acciones.add_child(btn_deshacer_pto)
	elif es_cruce:
		var btn_rotar_cruce := Button.new()
		btn_rotar_cruce.text = "↻ Rotar Cruce (45°)"
		btn_rotar_cruce.custom_minimum_size = Vector2(0, 50)
		btn_rotar_cruce.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
		_estilar_boton(btn_rotar_cruce, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
		if _fuente_ui:
			btn_rotar_cruce.add_theme_font_override("font", _fuente_ui)
		btn_rotar_cruce.pressed.connect(func(): rotar_objeto_solicitado.emit())
		vbox_acciones.add_child(btn_rotar_cruce)
	elif tipo_via == "conectar":
		var btn_conectar := Button.new()
		btn_conectar.text = "☍ Conectar Tramos Viales"
		btn_conectar.custom_minimum_size = Vector2(0, 50)
		btn_conectar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
		_estilar_boton(btn_conectar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
		if _fuente_ui:
			btn_conectar.add_theme_font_override("font", _fuente_ui)
		btn_conectar.pressed.connect(func(): conectar_vias_solicitado.emit())
		vbox_acciones.add_child(btn_conectar)
	elif tipo_via == "nivelar":
		var btn_nivelar := Button.new()
		btn_nivelar.text = "⊞ Nivelar Terreno Bajo Carreteras"
		btn_nivelar.custom_minimum_size = Vector2(0, 50)
		btn_nivelar.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
		_estilar_boton(btn_nivelar, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
		if _fuente_ui:
			btn_nivelar.add_theme_font_override("font", _fuente_ui)
		btn_nivelar.pressed.connect(func(): nivelar_terreno_vias_solicitado.emit())
		vbox_acciones.add_child(btn_nivelar)

	# Controles estilo CS2: Snap de ángulo, Elevación por pasos (-3m / 0m / +3m) y Mejorar Vía
	var hbox_cs2_via := HBoxContainer.new()
	hbox_cs2_via.add_theme_constant_override("separation", 8)
	_box_prop_contenido.add_child(hbox_cs2_via)

	var btn_snap_ang := Button.new()
	btn_snap_ang.text = "📐 Ángulo 45°/90°: " + ("SÍ" if _via_snap_angulo_ui else "NO")
	btn_snap_ang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_snap_ang.custom_minimum_size = Vector2(0, 48)
	btn_snap_ang.add_theme_font_size_override("font_size", 17)
	_estilar_boton(btn_snap_ang, Color(0.18, 0.15, 0.08, 0.92) if _via_snap_angulo_ui else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _via_snap_angulo_ui else COLOR_BORDE, 10.0)
	if _fuente_ui:
		btn_snap_ang.add_theme_font_override("font", _fuente_ui)
	btn_snap_ang.pressed.connect(func():
		_via_snap_angulo_ui = not _via_snap_angulo_ui
		via_snap_angulo_cambiado.emit(_via_snap_angulo_ui)
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	hbox_cs2_via.add_child(btn_snap_ang)

	var btn_upg := Button.new()
	btn_upg.text = "🔧 Mejorar Vía"
	btn_upg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_upg.custom_minimum_size = Vector2(0, 48)
	btn_upg.add_theme_font_size_override("font_size", 17)
	_estilar_boton(btn_upg, Color(0.18, 0.15, 0.08, 0.92) if _via_mejorar_ui else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _via_mejorar_ui else COLOR_BORDE, 10.0)
	if _fuente_ui:
		btn_upg.add_theme_font_override("font", _fuente_ui)
	btn_upg.pressed.connect(func():
		_via_mejorar_ui = not _via_mejorar_ui
		via_mejorar_alternado.emit(_via_mejorar_ui)
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	hbox_cs2_via.add_child(btn_upg)

	var hbox_elev := HBoxContainer.new()
	hbox_elev.add_theme_constant_override("separation", 6)
	_box_prop_contenido.add_child(hbox_elev)
	for el_cfg in [{"t": "⬇ -3m", "d": -3.0}, {"t": "0m Suelo", "d": 0.0}, {"t": "⬆ +3m", "d": 3.0}]:
		var btn_el := Button.new()
		btn_el.text = el_cfg["t"]
		btn_el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_el.custom_minimum_size = Vector2(0, 44)
		btn_el.add_theme_font_size_override("font_size", 17)
		_estilar_boton(btn_el, COLOR_PANEL_SEC, COLOR_BORDE, 8.0)
		if _fuente_ui:
			btn_el.add_theme_font_override("font", _fuente_ui)
		var dv: float = float(el_cfg["d"])
		btn_el.pressed.connect(func():
			if absf(dv) < 0.01:
				via_elevacion_reset_solicitada.emit()
			else:
				via_elevacion_paso_solicitada.emit(dv)
		)
		hbox_elev.add_child(btn_el)

# G. Ciudad (Catálogo y Opciones)
func _construir_vista_ciudad() -> void:
	var btn_disenador := Button.new()
	btn_disenador.text = "🏗️ Diseñador Modular (Edificios/Casas)"
	btn_disenador.custom_minimum_size = Vector2(0, 58)
	btn_disenador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_disenador.add_theme_font_size_override("font_size", 20)
	if _fuente_ui:
		btn_disenador.add_theme_font_override("font", _fuente_ui)
	var es_mod_act := (_id_item_activo == "casa_modular")
	_estilar_boton(btn_disenador, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0, 2 if es_mod_act else 1)
	btn_disenador.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	btn_disenador.pressed.connect(func():
		_id_item_activo = "casa_modular"
		disenador_casa_solicitado.emit(false)
	)
	_box_prop_contenido.add_child(btn_disenador)

	var hbox_cs2_c := HBoxContainer.new()
	hbox_cs2_c.add_theme_constant_override("separation", 8)
	_box_prop_contenido.add_child(hbox_cs2_c)

	var btn_snap_via := Button.new()
	btn_snap_via.text = "🧲 Snap Vía: " + ("SÍ" if _snap_via_ciudad_ui else "NO")
	btn_snap_via.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_snap_via.custom_minimum_size = Vector2(0, 46)
	btn_snap_via.add_theme_font_size_override("font_size", 17)
	_estilar_boton(btn_snap_via, Color(0.18, 0.15, 0.08, 0.92) if _snap_via_ciudad_ui else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _snap_via_ciudad_ui else COLOR_BORDE, 10.0)
	if _fuente_ui:
		btn_snap_via.add_theme_font_override("font", _fuente_ui)
	btn_snap_via.pressed.connect(func():
		_snap_via_ciudad_ui = not _snap_via_ciudad_ui
		snap_via_ciudad_alternado.emit(_snap_via_ciudad_ui)
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	hbox_cs2_c.add_child(btn_snap_via)

	var btn_pipeta := Button.new()
	btn_pipeta.text = "💧 Pipeta (I)"
	btn_pipeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pipeta.custom_minimum_size = Vector2(0, 46)
	btn_pipeta.add_theme_font_size_override("font_size", 17)
	_estilar_boton(btn_pipeta, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
	if _fuente_ui:
		btn_pipeta.add_theme_font_override("font", _fuente_ui)
	btn_pipeta.pressed.connect(func(): pipeta_solicitada.emit())
	hbox_cs2_c.add_child(btn_pipeta)

	if _subherramienta_activa == "auto_casas":
		var card_ac := PanelContainer.new()
		_estilar_panel_glass(card_ac, Color(0.09, 0.10, 0.12, 0.92), COLOR_AMARILLO_SEL, 12.0, 14.0)
		_box_prop_contenido.add_child(card_ac)
		var vbox_ac := VBoxContainer.new()
		vbox_ac.add_theme_constant_override("separation", 10)
		card_ac.add_child(vbox_ac)

		var lbl_ac := Label.new()
		lbl_ac.text = "CREACIÓN AUTOMÁTICA DE CASAS"
		lbl_ac.add_theme_font_size_override("font_size", 20)
		lbl_ac.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
		if _fuente_ui:
			lbl_ac.add_theme_font_override("font", _fuente_ui)
		vbox_ac.add_child(lbl_ac)

		var lbl_ac_desc := Label.new()
		lbl_ac_desc.text = "Elige la sección deseada y toca el terreno (o una vía) para generar casas automáticamente."
		lbl_ac_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_ac_desc.add_theme_font_size_override("font_size", 17)
		lbl_ac_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
		if _fuente_ui:
			lbl_ac_desc.add_theme_font_override("font", _fuente_ui)
		vbox_ac.add_child(lbl_ac_desc)

		var grid_sec := GridContainer.new()
		grid_sec.columns = 2
		grid_sec.add_theme_constant_override("h_separation", 6)
		grid_sec.add_theme_constant_override("v_separation", 6)
		vbox_ac.add_child(grid_sec)
		for sec_it in [
			{"id": "01_Residencial", "nom": "🏠 Residencial"},
			{"id": "modulares", "nom": "✨ Modulares Variadas"},
			{"id": "02_Comercial", "nom": "🏪 Comercial"},
			{"id": "03_Industrial_Logistica", "nom": "🏭 Industrial"},
			{"id": "04_Servicios_Publicos", "nom": "🏛️ Servicios"}
		]:
			var bs := Button.new()
			bs.text = sec_it["nom"]
			bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bs.custom_minimum_size = Vector2(0, 46)
			bs.add_theme_font_size_override("font_size", 16)
			var sid := str(sec_it["id"])
			var act_s := (_auto_casas_seccion_ui == sid)
			_estilar_boton(bs, Color(0.18, 0.15, 0.08, 0.92) if act_s else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if act_s else COLOR_BORDE, 8.0)
			bs.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if act_s else COLOR_TEXTO_PRI)
			if _fuente_ui:
				bs.add_theme_font_override("font", _fuente_ui)
			bs.pressed.connect(func():
				_auto_casas_seccion_ui = sid
				auto_casas_seccion_cambiada.emit(sid)
				_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
			)
			grid_sec.add_child(bs)

		var hbox_mod := HBoxContainer.new()
		hbox_mod.add_theme_constant_override("separation", 8)
		vbox_ac.add_child(hbox_mod)
		for m_it in [{"id": "pincel", "nom": "⭕ Pincel"}, {"id": "via", "nom": "🛣️ Borde Vía"}, {"id": "cuadra", "nom": "🏘️ Cuadra"}]:
			var bm := Button.new()
			bm.text = m_it["nom"]
			bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bm.custom_minimum_size = Vector2(0, 46)
			bm.add_theme_font_size_override("font_size", 17)
			var mid := str(m_it["id"])
			var act_m := (_auto_casas_modo_ui == mid)
			_estilar_boton(bm, Color(0.18, 0.15, 0.08, 0.92) if act_m else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if act_m else COLOR_BORDE, 8.0)
			if _fuente_ui:
				bm.add_theme_font_override("font", _fuente_ui)
			bm.pressed.connect(func():
				_auto_casas_modo_ui = mid
				auto_casas_modo_cambiado.emit(mid)
				_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
			)
			hbox_mod.add_child(bm)

		_crear_fila_slider("Radio de Zona", "ico_pincel_radio", 15.0, 90.0, _auto_casas_radio_ui, "m", 5.0, func(v):
			_auto_casas_radio_ui = v
			auto_casas_radio_cambiado.emit(v)
		)
		_crear_fila_slider("Cantidad de Casas", "cat_ciudad", 3.0, 25.0, float(_auto_casas_cantidad_ui), "", 1.0, func(v):
			_auto_casas_cantidad_ui = int(round(v))
			auto_casas_cantidad_cambiada.emit(_auto_casas_cantidad_ui)
		)

	if _subherramienta_activa == "zonificar":
		var card_z := PanelContainer.new()
		_estilar_panel_glass(card_z, Color(0.09, 0.10, 0.12, 0.92), COLOR_AMARILLO_SEL, 12.0, 12.0)
		_box_prop_contenido.add_child(card_z)
		var vbox_z := VBoxContainer.new()
		vbox_z.add_theme_constant_override("separation", 8)
		card_z.add_child(vbox_z)
		var lbl_z := Label.new()
		lbl_z.text = "ZONIFICACIÓN AUTOMÁTICA (CS2)"
		lbl_z.add_theme_font_size_override("font_size", 19)
		lbl_z.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
		if _fuente_ui:
			lbl_z.add_theme_font_override("font", _fuente_ui)
		vbox_z.add_child(lbl_z)
		var grid_z := GridContainer.new()
		grid_z.columns = 2
		grid_z.add_theme_constant_override("h_separation", 6)
		grid_z.add_theme_constant_override("v_separation", 6)
		vbox_z.add_child(grid_z)
		for z_it in [
			{"id": 1, "nom": "🟩 Residencial"},
			{"id": 5, "nom": "✨ Modulares"},
			{"id": 2, "nom": "🟦 Comercial"},
			{"id": 3, "nom": "🟨 Industrial"},
			{"id": 4, "nom": "🟪 Mixto"},
			{"id": 0, "nom": "✕ Quitar Zona"}
		]:
			var bz := Button.new()
			bz.text = z_it["nom"]
			bz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bz.custom_minimum_size = Vector2(0, 44)
			bz.add_theme_font_size_override("font_size", 16)
			var zid := int(z_it["id"])
			var act_z := (_zona_tipo_ui == zid)
			_estilar_boton(bz, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if act_z else COLOR_BORDE, 8.0)
			if _fuente_ui:
				bz.add_theme_font_override("font", _fuente_ui)
			bz.pressed.connect(func():
				_zona_tipo_ui = zid
				zona_tipo_cambiado.emit(zid)
				_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
			)
			grid_z.add_child(bz)
		var hbox_z_act := HBoxContainer.new()
		hbox_z_act.add_theme_constant_override("separation", 8)
		vbox_z.add_child(hbox_z_act)
		var b_des := Button.new()
		b_des.text = "⚡ Desarrollar"
		b_des.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_des.custom_minimum_size = Vector2(0, 48)
		b_des.add_theme_font_size_override("font_size", 18)
		_estilar_boton(b_des, Color(0.14, 0.56, 0.30, 0.95), Color(0.35, 0.90, 0.52, 0.95), 10.0)
		b_des.add_theme_color_override("font_color", Color.WHITE)
		if _fuente_ui:
			b_des.add_theme_font_override("font", _fuente_ui)
		b_des.pressed.connect(func(): zona_desarrollar_solicitado.emit())
		hbox_z_act.add_child(b_des)
		var b_cl := Button.new()
		b_cl.text = "Limpiar"
		b_cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_cl.custom_minimum_size = Vector2(0, 48)
		b_cl.add_theme_font_size_override("font_size", 18)
		_estilar_boton(b_cl, COLOR_CRIMSON_SALIR, COLOR_BORDE, 10.0)
		if _fuente_ui:
			b_cl.add_theme_font_override("font", _fuente_ui)
		b_cl.pressed.connect(func(): zona_limpiar_solicitado.emit())
		hbox_z_act.add_child(b_cl)

		var btn_auto_c := Button.new()
		btn_auto_c.text = "🏠 Auto-Construir al Pintar: " + ("SÍ" if _zona_auto_construir_ui else "NO")
		btn_auto_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_auto_c.custom_minimum_size = Vector2(0, 44)
		btn_auto_c.add_theme_font_size_override("font_size", 16)
		_estilar_boton(btn_auto_c, Color(0.18, 0.15, 0.08, 0.92) if _zona_auto_construir_ui else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _zona_auto_construir_ui else COLOR_BORDE, 8.0)
		if _fuente_ui:
			btn_auto_c.add_theme_font_override("font", _fuente_ui)
		btn_auto_c.pressed.connect(func():
			_zona_auto_construir_ui = not _zona_auto_construir_ui
			zona_auto_construir_cambiado.emit(_zona_auto_construir_ui)
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		vbox_z.add_child(btn_auto_c)

		var hbox_filas := HBoxContainer.new()
		hbox_filas.add_theme_constant_override("separation", 6)
		vbox_z.add_child(hbox_filas)
		for f_it in [{"f": 1, "nom": "1 Fila (Línea)"}, {"f": 2, "nom": "2 Filas"}]:
			var bf := Button.new()
			bf.text = f_it["nom"]
			bf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bf.custom_minimum_size = Vector2(0, 42)
			bf.add_theme_font_size_override("font_size", 16)
			var fv := int(f_it["f"])
			var act_f := (_zona_filas_ui == fv)
			_estilar_boton(bf, Color(0.18, 0.15, 0.08, 0.92) if act_f else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if act_f else COLOR_BORDE, 8.0)
			if _fuente_ui:
				bf.add_theme_font_override("font", _fuente_ui)
			bf.pressed.connect(func():
				_zona_filas_ui = fv
				zona_filas_cambiado.emit(fv)
				_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
			)
			hbox_filas.add_child(bf)

		_crear_fila_slider("Radio Pincel Zona", "ico_pincel_radio", 3.0, 45.0, _zona_radio_ui, "m", 0.5, func(v):
			_zona_radio_ui = v
			zona_radio_cambiado.emit(v)
		)

	var grid_filtros := GridContainer.new()
	grid_filtros.columns = 2
	grid_filtros.add_theme_constant_override("h_separation", 8)
	grid_filtros.add_theme_constant_override("v_separation", 8)
	_box_prop_contenido.add_child(grid_filtros)

	var secciones_ciudad := [
		{"id": "01_Residencial", "nom": "🏠 Residencial", "sub": "res"},
		{"id": "02_Comercial", "nom": "🏪 Comercial", "sub": "com"},
		{"id": "03_Industrial_Logistica", "nom": "🏭 Industrial", "sub": "ind"},
		{"id": "04_Servicios_Publicos", "nom": "🏛️ Servicios", "sub": "inst"},
		{"id": "05_Zonas_Logistica", "nom": "📍 Zonas/Puntos", "sub": "zonas"}
	]
	for s_info in secciones_ciudad:
		var btn_s := Button.new()
		btn_s.text = s_info["nom"]
		btn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_s.custom_minimum_size = Vector2(0, 46)
		btn_s.add_theme_font_size_override("font_size", 17)
		if _fuente_ui:
			btn_s.add_theme_font_override("font", _fuente_ui)
		var sid_sec: String = s_info["id"]
		var sub_sec: String = s_info["sub"]
		var es_act := (_seccion_biblioteca_activa == sid_sec)
		_estilar_boton(btn_s, Color(0.18, 0.14, 0.07, 0.94) if es_act else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if es_act else COLOR_BORDE, 10.0, 2 if es_act else 1)
		btn_s.pressed.connect(func():
			_subherramienta_activa = sub_sec
			_seccion_biblioteca_activa = sid_sec
			_actualizar_panel_contextual("ciudad", sub_sec)
		)
		grid_filtros.add_child(btn_s)

	CargadorBiblioteca.inicializar()
	var items = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", _seccion_biblioteca_activa, "todos")
	if items.is_empty():
		items = CargadorBiblioteca.obtener_items_por_categoria("01_Edificaciones")

	# Tarjeta de previsualización del elemento seleccionado
	var item_activo_info: Dictionary = {}
	for it_c in items:
		if it_c.get("id", "") == _id_item_activo:
			item_activo_info = it_c
			break
	if item_activo_info.is_empty() and not items.is_empty():
		item_activo_info = items[0]

	if not item_activo_info.is_empty():
		var card_prev := PanelContainer.new()
		_estilar_panel_glass(card_prev, Color(0.09, 0.10, 0.12, 0.92), COLOR_BORDE, 12.0, 10.0)
		_box_prop_contenido.add_child(card_prev)

		var vbox_prev := VBoxContainer.new()
		vbox_prev.add_theme_constant_override("separation", 6)
		card_prev.add_child(vbox_prev)

		var lbl_prev_tag := Label.new()
		lbl_prev_tag.text = "PREVISUALIZACIÓN"
		lbl_prev_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_prev_tag.add_theme_font_size_override("font_size", 12)
		lbl_prev_tag.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
		if _fuente_ui:
			lbl_prev_tag.add_theme_font_override("font", _fuente_ui)
		vbox_prev.add_child(lbl_prev_tag)

		var ruta_tex_prev: String = str(item_activo_info.get("icono_textura", ""))
		if ruta_tex_prev != "" and ResourceLoader.exists(ruta_tex_prev):
			var tex_prev := TextureRect.new()
			tex_prev.custom_minimum_size = Vector2(0, 140)
			tex_prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_prev.texture = load(ruta_tex_prev) as Texture2D
			vbox_prev.add_child(tex_prev)

		var lbl_prev_nom := Label.new()
		lbl_prev_nom.text = "%s %s" % [str(item_activo_info.get("icono", "🏢")), str(item_activo_info.get("nombre", ""))]
		lbl_prev_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_prev_nom.add_theme_font_size_override("font_size", 20)
		lbl_prev_nom.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
		if _fuente_ui:
			lbl_prev_nom.add_theme_font_override("font", _fuente_ui)
		vbox_prev.add_child(lbl_prev_nom)

		var tam_prev: Vector3 = item_activo_info.get("tamano", Vector3.ZERO)
		var desc_prev: String = str(item_activo_info.get("descripcion", ""))
		var lbl_prev_desc := Label.new()
		lbl_prev_desc.text = "%s\n📐 %.1fm × %.1fm × %.1fm" % [desc_prev, tam_prev.x, tam_prev.z, tam_prev.y]
		lbl_prev_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_prev_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_prev_desc.add_theme_font_size_override("font_size", 14)
		lbl_prev_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
		if _fuente_ui:
			lbl_prev_desc.add_theme_font_override("font", _fuente_ui)
		vbox_prev.add_child(lbl_prev_desc)

	# Lista en 1 columna amplia (legible en móvil, sin corte de texto)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box_prop_contenido.add_child(scroll)

	var grid_modelos := GridContainer.new()
	grid_modelos.columns = 1
	grid_modelos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_modelos.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid_modelos)

	for it in items:
		var it_id: String = it.get("id", "")
		var it_nom: String = it.get("nombre", it_id)
		var it_ico: String = str(it.get("icono", "🏢"))
		var it_tex: String = str(it.get("icono_textura", ""))
		var btn_item := Button.new()
		btn_item.text = "  %s %s" % [it_ico, it_nom]
		btn_item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_item.custom_minimum_size = Vector2(0, 58)
		btn_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_item.add_theme_font_size_override("font_size", 19)
		if it_tex != "" and ResourceLoader.exists(it_tex):
			btn_item.icon = load(it_tex) as Texture2D
			btn_item.expand_icon = true
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
		"Demoler" if not _modo_demolicion_activo else "Colocar",
		"Colocar"
	)

# H. Vegetación
func _obtener_especies_vegetacion() -> Array[Dictionary]:
	return [
		{"id": "arbol_sabanero", "nombre": "Arbol Sabanero", "corto": "Sabanero", "tex": "res://recursos/iconos_editor/arboles/arbol_sabanero.png", "desc": "Copa amplia de sabana (8 x 11.5m)"},
		{"id": "arbol_roble_3d", "nombre": "Roble 3D", "corto": "Roble", "tex": "res://recursos/iconos_editor/arboles/arbol_roble_3d.png", "desc": "Tronco robusto andino (8 x 12m)"},
		{"id": "arbol_palmera", "nombre": "Palmera", "corto": "Palmera", "tex": "res://recursos/iconos_editor/arboles/arbol_palmera.png", "desc": "Palma alta tropical (5 x 14m)"},
		{"id": "arbol_alto_silvestre", "nombre": "Silvestre Alto", "corto": "Silvestre", "tex": "res://recursos/iconos_editor/arboles/arbol_alto_silvestre.png", "desc": "Arbol alto de ladera (7 x 13m)"},
		{"id": "arbol_frondoso", "nombre": "Arbol Frondoso", "corto": "Frondoso", "tex": "res://recursos/iconos_editor/arboles/arbol_frondoso.png", "desc": "Follaje denso verde (9 x 10.5m)"},
		{"id": "arboleda_grupo", "nombre": "Arboleda", "corto": "Arboleda", "tex": "res://recursos/iconos_editor/arboles/arboleda_grupo.png", "desc": "Grupo natural de arboles"}
	]

func _actualizar_preview_especie_vegetacion() -> void:
	var especies := _obtener_especies_vegetacion()
	var info: Dictionary = especies[0]
	for sp in especies:
		if sp["id"] == _especie_vegetacion_activa:
			info = sp
			break
	if is_instance_valid(_preview_veg_tex):
		var ruta_tex: String = info.get("tex", "")
		if ResourceLoader.exists(ruta_tex):
			_preview_veg_tex.texture = load(ruta_tex) as Texture2D
		else:
			_preview_veg_tex.texture = null
	if is_instance_valid(_preview_veg_nombre):
		_preview_veg_nombre.text = info.get("nombre", _especie_vegetacion_activa)
	if is_instance_valid(_preview_veg_desc):
		var modo_txt: String = "Pincel de bosque" if _modo_dispersion_activo else "Colocacion individual"
		_preview_veg_desc.text = "%s\nModo: %s" % [info.get("desc", ""), modo_txt]
	for sp_id in _dict_botones_especie:
		var btn: Button = _dict_botones_especie[sp_id]
		if is_instance_valid(btn):
			var es_sel: bool = (sp_id == _especie_vegetacion_activa)
			_estilar_boton(btn, Color(0.18, 0.14, 0.07, 0.94) if es_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if es_sel else COLOR_BORDE, 10.0)

func _construir_vista_vegetacion() -> void:
	_dict_botones_especie.clear()

	# Tarjeta de previsualizacion grande de la especie activa
	var card_prev := PanelContainer.new()
	_estilar_panel_glass(card_prev, Color(0.09, 0.10, 0.12, 0.90), COLOR_BORDE, 12.0, 12.0)
	_box_prop_contenido.add_child(card_prev)

	var vbox_prev := VBoxContainer.new()
	vbox_prev.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_prev.add_theme_constant_override("separation", 8)
	card_prev.add_child(vbox_prev)

	var lbl_tag := Label.new()
	lbl_tag.text = "PREVISUALIZACION"
	lbl_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tag.add_theme_font_size_override("font_size", 13)
	lbl_tag.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_tag.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(lbl_tag)

	var marco_tex := PanelContainer.new()
	marco_tex.custom_minimum_size = Vector2(220, 220)
	marco_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_estilar_panel_glass(marco_tex, Color(0.06, 0.07, 0.08, 0.92), Color(0.88, 0.68, 0.28, 0.45), 12.0, 8.0)
	vbox_prev.add_child(marco_tex)

	_preview_veg_tex = TextureRect.new()
	_preview_veg_tex.custom_minimum_size = Vector2(204, 204)
	_preview_veg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_veg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco_tex.add_child(_preview_veg_tex)

	_preview_veg_nombre = Label.new()
	_preview_veg_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_veg_nombre.add_theme_font_size_override("font_size", 22)
	_preview_veg_nombre.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	_preview_veg_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _fuente_ui:
		_preview_veg_nombre.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(_preview_veg_nombre)

	_preview_veg_desc = Label.new()
	_preview_veg_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_veg_desc.add_theme_font_size_override("font_size", 15)
	_preview_veg_desc.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	_preview_veg_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _fuente_ui:
		_preview_veg_desc.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(_preview_veg_desc)

	# Selector visual de especies con miniaturas
	var grid_especies := GridContainer.new()
	grid_especies.columns = 3
	grid_especies.add_theme_constant_override("h_separation", 8)
	grid_especies.add_theme_constant_override("v_separation", 8)
	_box_prop_contenido.add_child(grid_especies)

	for sp in _obtener_especies_vegetacion():
		var sp_id: String = sp["id"]
		var btn_sp := Button.new()
		btn_sp.text = sp["corto"]
		btn_sp.custom_minimum_size = Vector2(0, 74)
		btn_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_sp.add_theme_font_size_override("font_size", 14)
		btn_sp.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_sp.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn_sp.expand_icon = true
		btn_sp.add_theme_constant_override("icon_max_width", 44)
		if _fuente_ui:
			btn_sp.add_theme_font_override("font", _fuente_ui)
		if ResourceLoader.exists(sp["tex"]):
			btn_sp.icon = load(sp["tex"]) as Texture2D
		btn_sp.pressed.connect(func():
			_especie_vegetacion_activa = sp_id
			_subherramienta_activa = sp_id
			_id_item_activo = sp_id
			_actualizar_preview_especie_vegetacion()
			_actualizar_estilo_botones_herramientas()
			subherramienta_seleccionada.emit(sp_id)
		)
		grid_especies.add_child(btn_sp)
		_dict_botones_especie[sp_id] = btn_sp

	_actualizar_preview_especie_vegetacion()

	var hbox_modo := HBoxContainer.new()
	hbox_modo.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_modo)

	var btn_ind := Button.new()
	btn_ind.text = "Arbol Individual"
	btn_ind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ind.custom_minimum_size = Vector2(0, 50)
	btn_ind.add_theme_font_size_override("font_size", 18)
	if _fuente_ui:
		btn_ind.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_ind, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if not _modo_dispersion_activo else COLOR_BORDE, 10.0)
	btn_ind.pressed.connect(func():
		_modo_dispersion_activo = false
		modo_dispersion_vegetacion_alternado.emit(false)
		_actualizar_panel_contextual(_categoria_activa, _especie_vegetacion_activa)
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
		_actualizar_panel_contextual(_categoria_activa, _especie_vegetacion_activa)
	)
	hbox_modo.add_child(btn_disp)

	if _modo_dispersion_activo:
		_crear_fila_slider("Radio dispersion", "ico_pincel_radio", 5.0, 60.0, _radio_dispersion, "m", 1.0, func(val):
			_radio_dispersion = val
			radio_dispersion_vegetacion_cambiado.emit(val)
		)
		_crear_fila_slider("Densidad de arboles", "ico_fuerza", 4.0, 40.0, float(_densidad_dispersion), "", 1.0, func(val):
			_densidad_dispersion = int(val)
			densidad_dispersion_vegetacion_cambiada.emit(int(val))
		)

	_crear_botones_accion_inferiores(
		func():
			borrar_dispersion_vegetacion_solicitado.emit(),
		func():
			accion_colocar_solicitada.emit(),
		"Borrar en radio",
		"Dispersar Arboles" if _modo_dispersion_activo else "Colocar Arbol"
	)

# H2. Muros y Cercas Modulares (Blender Atlas PBR)
const _ControladorMurosRef = preload("res://mundo/editor_mapas/ControladorMuros.gd")

func _actualizar_preview_muro() -> void:
	var catalogo := _ControladorMurosRef.obtener_catalogo_muros()
	var info: Dictionary = catalogo[0]
	for item in catalogo:
		if item["id"] == _muro_activo:
			info = item
			break
	if is_instance_valid(_preview_muro_tex):
		var ruta_tex: String = info.get("tex", "")
		if ResourceLoader.exists(ruta_tex):
			_preview_muro_tex.texture = load(ruta_tex) as Texture2D
		else:
			_preview_muro_tex.texture = null
	if is_instance_valid(_preview_muro_nombre):
		_preview_muro_nombre.text = info.get("nombre", _muro_activo)
	if is_instance_valid(_preview_muro_desc):
		var etq_cat: String = "Campo / Agricola" if info.get("cat", "urbano") == "campo" else "Urbano / Modular"
		_preview_muro_desc.text = "%s\nTipo: %s" % [info.get("desc", ""), etq_cat]
	for m_id in _dict_botones_muro:
		var btn: Button = _dict_botones_muro[m_id]
		if is_instance_valid(btn):
			var es_sel: bool = (m_id == _muro_activo)
			_estilar_boton(btn, Color(0.18, 0.14, 0.07, 0.94) if es_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if es_sel else COLOR_BORDE, 10.0)

func _construir_vista_muros() -> void:
	_dict_botones_muro.clear()

	# Tarjeta de previsualizacion grande (mismo estilo que arboles)
	var card_prev := PanelContainer.new()
	_estilar_panel_glass(card_prev, Color(0.09, 0.10, 0.12, 0.90), COLOR_BORDE, 12.0, 12.0)
	_box_prop_contenido.add_child(card_prev)

	var vbox_prev := VBoxContainer.new()
	vbox_prev.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_prev.add_theme_constant_override("separation", 8)
	card_prev.add_child(vbox_prev)

	var lbl_tag := Label.new()
	lbl_tag.text = "PREVISUALIZACION"
	lbl_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tag.add_theme_font_size_override("font_size", 13)
	lbl_tag.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_tag.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(lbl_tag)

	var marco_tex := PanelContainer.new()
	marco_tex.custom_minimum_size = Vector2(220, 220)
	marco_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_estilar_panel_glass(marco_tex, Color(0.06, 0.07, 0.08, 0.92), Color(0.88, 0.68, 0.28, 0.45), 12.0, 8.0)
	vbox_prev.add_child(marco_tex)

	_preview_muro_tex = TextureRect.new()
	_preview_muro_tex.custom_minimum_size = Vector2(204, 204)
	_preview_muro_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_muro_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco_tex.add_child(_preview_muro_tex)

	_preview_muro_nombre = Label.new()
	_preview_muro_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_muro_nombre.add_theme_font_size_override("font_size", 22)
	_preview_muro_nombre.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	_preview_muro_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _fuente_ui:
		_preview_muro_nombre.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(_preview_muro_nombre)

	_preview_muro_desc = Label.new()
	_preview_muro_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_muro_desc.add_theme_font_size_override("font_size", 15)
	_preview_muro_desc.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	_preview_muro_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _fuente_ui:
		_preview_muro_desc.add_theme_font_override("font", _fuente_ui)
	vbox_prev.add_child(_preview_muro_desc)

	# Pestañas organizadas: Urbanos (10) / Campo (5)
	var hbox_tabs := HBoxContainer.new()
	hbox_tabs.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_tabs)

	var btn_urb := Button.new()
	btn_urb.text = "Urbanos (10)"
	btn_urb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_urb.custom_minimum_size = Vector2(0, 48)
	btn_urb.add_theme_font_size_override("font_size", 17)
	if _fuente_ui:
		btn_urb.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_urb, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _muro_filtro_cat == "urbano" else COLOR_BORDE, 10.0)
	btn_urb.pressed.connect(func():
		_muro_filtro_cat = "urbano"
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	hbox_tabs.add_child(btn_urb)

	var btn_campo := Button.new()
	btn_campo.text = "Campo (5)"
	btn_campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_campo.custom_minimum_size = Vector2(0, 48)
	btn_campo.add_theme_font_size_override("font_size", 17)
	if _fuente_ui:
		btn_campo.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_campo, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _muro_filtro_cat == "campo" else COLOR_BORDE, 10.0)
	btn_campo.pressed.connect(func():
		_muro_filtro_cat = "campo"
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	hbox_tabs.add_child(btn_campo)

	# Galería visual de muros filtrados
	var grid_muros := GridContainer.new()
	grid_muros.columns = 3
	grid_muros.add_theme_constant_override("h_separation", 8)
	grid_muros.add_theme_constant_override("v_separation", 8)
	_box_prop_contenido.add_child(grid_muros)

	for item in _ControladorMurosRef.obtener_catalogo_muros():
		if item.get("cat", "urbano") != _muro_filtro_cat:
			continue
		var m_id: String = item["id"]
		var btn_m := Button.new()
		btn_m.text = item["corto"]
		btn_m.custom_minimum_size = Vector2(0, 74)
		btn_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_m.add_theme_font_size_override("font_size", 13)
		btn_m.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_m.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn_m.expand_icon = true
		btn_m.add_theme_constant_override("icon_max_width", 44)
		if _fuente_ui:
			btn_m.add_theme_font_override("font", _fuente_ui)
		if ResourceLoader.exists(item["tex"]):
			btn_m.icon = load(item["tex"]) as Texture2D
		btn_m.pressed.connect(func():
			_muro_activo = m_id
			_actualizar_preview_muro()
			muro_tipo_cambiado.emit(m_id)
		)
		grid_muros.add_child(btn_m)
		_dict_botones_muro[m_id] = btn_m

	_actualizar_preview_muro()

	_crear_fila_slider("Escala Altura", "ico_fuerza", 0.6, 2.0, _muro_escala_altura, "x", 0.1, func(val):
		_muro_escala_altura = val
		muro_escala_altura_cambiada.emit(val)
	)

	_crear_botones_accion_inferiores(
		func():
			muro_deshacer_solicitado.emit(),
		func():
			muro_finalizar_tramo_solicitado.emit(),
		"Deshacer Punto",
		"✓ Finalizar Tramo"
	)

# I. Spawn
var _parqueo_tipo_sel: int = 0
var _parqueo_color_sel: int = 0
var _parqueo_iluminacion_sel: bool = true
var _parqueo_arbolado_sel: bool = true
var _parqueo_hay_seleccion: bool = false
var _parqueo_finalizado: bool = false
var _parqueo_tiene_conexion: bool = false
var _parqueo_rotacion_sel: float = 0.0
var _parqueo_adaptar_terreno_sel: bool = true

func actualizar_estado_parqueo_ui(hay_sel: bool, datos: Dictionary) -> void:
	_parqueo_hay_seleccion = hay_sel
	if hay_sel:
		_parqueo_tipo_sel = int(datos.get("tipo", 0))
		_parqueo_color_sel = int(datos.get("color_lineas", 0))
		_parqueo_iluminacion_sel = bool(datos.get("iluminacion", true))
		_parqueo_arbolado_sel = bool(datos.get("arbolado", true))
		_parqueo_finalizado = bool(datos.get("finalizado", false))
		_parqueo_tiene_conexion = bool(datos.get("tiene_conexion", false))
		_parqueo_rotacion_sel = float(datos.get("rotacion", 0.0))
		_parqueo_adaptar_terreno_sel = bool(datos.get("adaptar_terreno", _parqueo_adaptar_terreno_sel))
	else:
		_parqueo_finalizado = false
		_parqueo_tiene_conexion = false
		_parqueo_rotacion_sel = 0.0
	if _categoria_activa == "parqueo":
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func actualizar_rotacion_parqueo_ui(angulo: float) -> void:
	_parqueo_rotacion_sel = wrapf(angulo, 0.0, 360.0)
	_actualizar_slider_val("Rotación Parqueo", _parqueo_rotacion_sel)

func _construir_vista_parqueo() -> void:
	# 1. Tarjeta de Estado / Guía
	var card_info := PanelContainer.new()
	var borde_estado := Color(0.35, 0.90, 0.52, 0.75) if (_parqueo_hay_seleccion and _parqueo_finalizado) else (COLOR_AMARILLO_SEL if _parqueo_hay_seleccion else COLOR_BORDE)
	_estilar_panel_glass(card_info, Color(0.09, 0.10, 0.12, 0.92), borde_estado, 12.0, 14.0)
	_box_prop_contenido.add_child(card_info)

	var vbox_info := VBoxContainer.new()
	vbox_info.add_theme_constant_override("separation", 6)
	card_info.add_child(vbox_info)

	var lbl_tit := Label.new()
	if _parqueo_hay_seleccion:
		lbl_tit.text = "PARQUEO LISTO" if _parqueo_finalizado else "EDITANDO ESQUINAS"
		lbl_tit.add_theme_color_override("font_color", Color(0.42, 0.94, 0.58) if _parqueo_finalizado else COLOR_AMARILLO_SEL)
	else:
		lbl_tit.text = "PARQUEO PROCEDURAL"
		lbl_tit.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	lbl_tit.add_theme_font_size_override("font_size", 23)
	if _fuente_ui:
		lbl_tit.add_theme_font_override("font", _fuente_ui)
	vbox_info.add_child(lbl_tit)

	var lbl_desc := Label.new()
	if _parqueo_hay_seleccion and not _parqueo_finalizado:
		lbl_desc.text = "Arrastra las 4 esferas amarillas para adaptar el espacio o el punto verde para mover la entrada."
	elif _parqueo_hay_seleccion:
		lbl_desc.text = "Puedes rotar el parqueo, unir la salida con la carretera o volver a editar sus esquinas."
	else:
		lbl_desc.text = "Crea un nuevo estacionamiento (R para rotar) o toca uno existente para configurarlo."
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", 19)
	lbl_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_desc.add_theme_font_override("font", _fuente_ui)
	vbox_info.add_child(lbl_desc)

	# 2. Acciones Principales (Finalizar / Editar Esquinas + Unir con Carretera)
	if _parqueo_hay_seleccion:
		var card_flujo := PanelContainer.new()
		_estilar_panel_glass(card_flujo, Color(0.09, 0.10, 0.12, 0.92), COLOR_BORDE, 12.0, 14.0)
		_box_prop_contenido.add_child(card_flujo)

		var vbox_flujo := VBoxContainer.new()
		vbox_flujo.add_theme_constant_override("separation", 10)
		card_flujo.add_child(vbox_flujo)

		if not _parqueo_finalizado:
			var btn_fin := Button.new()
			btn_fin.text = "✓ FINALIZAR PARQUEO"
			btn_fin.custom_minimum_size = Vector2(0, 62)
			btn_fin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_fin.add_theme_font_size_override("font_size", 23)
			if _fuente_ui:
				btn_fin.add_theme_font_override("font", _fuente_ui)
			_estilar_boton(btn_fin, Color(0.14, 0.56, 0.30, 0.95), Color(0.35, 0.90, 0.52, 0.95), 10.0)
			btn_fin.add_theme_color_override("font_color", Color.WHITE)
			btn_fin.pressed.connect(func(): parqueo_finalizar_solicitado.emit())
			vbox_flujo.add_child(btn_fin)
		else:
			var btn_ed_esq := Button.new()
			btn_ed_esq.text = "✏️ EDITAR ESQUINAS"
			btn_ed_esq.custom_minimum_size = Vector2(0, 58)
			btn_ed_esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_ed_esq.add_theme_font_size_override("font_size", 22)
			if _fuente_ui:
				btn_ed_esq.add_theme_font_override("font", _fuente_ui)
			_estilar_boton(btn_ed_esq, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
			btn_ed_esq.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
			btn_ed_esq.pressed.connect(func(): parqueo_editar_esquinas_solicitado.emit())
			vbox_flujo.add_child(btn_ed_esq)

		var btn_unir := Button.new()
		btn_unir.text = "🛣️ ACTUALIZAR VÍA" if _parqueo_tiene_conexion else "🛣️ UNIR CON CARRETERA"
		btn_unir.custom_minimum_size = Vector2(0, 60)
		btn_unir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_unir.add_theme_font_size_override("font_size", 22)
		if _fuente_ui:
			btn_unir.add_theme_font_override("font", _fuente_ui)
		_estilar_boton(btn_unir, Color(0.18, 0.15, 0.08, 0.92), COLOR_AMARILLO_SEL, 10.0)
		btn_unir.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
		btn_unir.pressed.connect(func(): parqueo_unir_carretera_solicitado.emit())
		vbox_flujo.add_child(btn_unir)

		# 2B. Rotación del estacionamiento
		var card_rot := PanelContainer.new()
		_estilar_panel_glass(card_rot, Color(0.09, 0.10, 0.12, 0.92), COLOR_BORDE, 12.0, 14.0)
		_box_prop_contenido.add_child(card_rot)

		var vbox_rot := VBoxContainer.new()
		vbox_rot.add_theme_constant_override("separation", 8)
		card_rot.add_child(vbox_rot)

		var hbox_rot_btns := HBoxContainer.new()
		hbox_rot_btns.add_theme_constant_override("separation", 6)
		vbox_rot.add_child(hbox_rot_btns)
		for delta_r in [-90.0, -15.0, 15.0, 90.0]:
			var btn_r := Button.new()
			btn_r.text = ("%+d°" % int(delta_r))
			btn_r.custom_minimum_size = Vector2(0, 48)
			btn_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_r.add_theme_font_size_override("font_size", 19)
			if _fuente_ui:
				btn_r.add_theme_font_override("font", _fuente_ui)
			_estilar_boton(btn_r, COLOR_PANEL_SEC, COLOR_BORDE, 8.0)
			btn_r.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
			var dr := float(delta_r)
			btn_r.pressed.connect(func(): parqueo_rotacion_delta_solicitada.emit(dr))
			hbox_rot_btns.add_child(btn_r)

		_crear_fila_slider("Rotación Parqueo", "act_rotar", 0.0, 360.0, _parqueo_rotacion_sel, "°", 1.0, func(v):
			_parqueo_rotacion_sel = v
			parqueo_rotacion_cambiada.emit(v)
		)

	var padre_adaptar: VBoxContainer = _box_sliders_contenido if is_instance_valid(_box_sliders_contenido) else _box_prop_contenido
	var btn_adaptar_terreno := Button.new()
	btn_adaptar_terreno.custom_minimum_size = Vector2(0, 50)
	btn_adaptar_terreno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estilar_boton(btn_adaptar_terreno, Color(0.18, 0.15, 0.08, 0.92) if _parqueo_adaptar_terreno_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _parqueo_adaptar_terreno_sel else COLOR_BORDE, 10.0)
	var hbox_adaptar := HBoxContainer.new()
	hbox_adaptar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox_adaptar.offset_left = 14.0
	hbox_adaptar.offset_right = -14.0
	hbox_adaptar.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox_adaptar.add_theme_constant_override("separation", 10)
	hbox_adaptar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_adaptar_terreno.add_child(hbox_adaptar)

	var chk_adaptar := CheckBox.new()
	chk_adaptar.button_pressed = _parqueo_adaptar_terreno_sel
	chk_adaptar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_adaptar.add_child(chk_adaptar)

	var lbl_adaptar := Label.new()
	lbl_adaptar.text = "Adaptar a Terreno"
	lbl_adaptar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_adaptar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_adaptar.add_theme_font_size_override("font_size", 20)
	lbl_adaptar.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if _parqueo_adaptar_terreno_sel else COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_adaptar.add_theme_font_override("font", _fuente_ui)
	lbl_adaptar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_adaptar.add_child(lbl_adaptar)

	btn_adaptar_terreno.pressed.connect(func():
		_parqueo_adaptar_terreno_sel = not _parqueo_adaptar_terreno_sel
		chk_adaptar.button_pressed = _parqueo_adaptar_terreno_sel
		_estilar_boton(btn_adaptar_terreno, Color(0.18, 0.15, 0.08, 0.92) if _parqueo_adaptar_terreno_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _parqueo_adaptar_terreno_sel else COLOR_BORDE, 10.0)
		lbl_adaptar.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if _parqueo_adaptar_terreno_sel else COLOR_TEXTO_PRI)
		parqueo_adaptar_terreno_cambiado.emit(_parqueo_adaptar_terreno_sel)
	)
	padre_adaptar.add_child(btn_adaptar_terreno)

	# 3. Distribución de Bahías (Selector horizontal en 3 columnas)
	var card_tipo := PanelContainer.new()
	_estilar_panel_glass(card_tipo, Color(0.09, 0.10, 0.12, 0.92), COLOR_BORDE, 12.0, 14.0)
	_box_prop_contenido.add_child(card_tipo)

	var vbox_tipo := VBoxContainer.new()
	vbox_tipo.add_theme_constant_override("separation", 10)
	card_tipo.add_child(vbox_tipo)

	var lbl_tipo := Label.new()
	lbl_tipo.text = "DISTRIBUCIÓN DE BAHÍAS"
	lbl_tipo.add_theme_font_size_override("font_size", 21)
	lbl_tipo.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_tipo.add_theme_font_override("font", _fuente_ui)
	vbox_tipo.add_child(lbl_tipo)

	var hbox_tipos := HBoxContainer.new()
	hbox_tipos.add_theme_constant_override("separation", 8)
	vbox_tipo.add_child(hbox_tipos)

	var tipos := [
		{"id": 0, "nombre": "Autos 90°"},
		{"id": 1, "nombre": "Carga 45°"},
		{"id": 2, "nombre": "Mixto"}
	]
	for t in tipos:
		var btn_t := Button.new()
		btn_t.text = t["nombre"]
		btn_t.custom_minimum_size = Vector2(0, 58)
		btn_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_t.add_theme_font_size_override("font_size", 20)
		if _fuente_ui:
			btn_t.add_theme_font_override("font", _fuente_ui)
		var activo: bool = (_parqueo_tipo_sel == int(t["id"]))
		_estilar_boton(btn_t, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if activo else COLOR_BORDE, 10.0)
		btn_t.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if activo else COLOR_TEXTO_PRI)
		var id_t := int(t["id"])
		btn_t.pressed.connect(func():
			_parqueo_tipo_sel = id_t
			parqueo_tipo_cambiado.emit(id_t)
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		hbox_tipos.add_child(btn_t)

	# 4. Estilo y Entorno (Cuadrícula 2x2 limpia)
	var card_estilo := PanelContainer.new()
	_estilar_panel_glass(card_estilo, Color(0.09, 0.10, 0.12, 0.92), COLOR_BORDE, 12.0, 14.0)
	_box_prop_contenido.add_child(card_estilo)

	var vbox_est := VBoxContainer.new()
	vbox_est.add_theme_constant_override("separation", 10)
	card_estilo.add_child(vbox_est)

	var lbl_color := Label.new()
	lbl_color.text = "DEMARCACIÓN Y ENTORNO"
	lbl_color.add_theme_font_size_override("font_size", 21)
	lbl_color.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_color.add_theme_font_override("font", _fuente_ui)
	vbox_est.add_child(lbl_color)

	var grid_est := GridContainer.new()
	grid_est.columns = 2
	grid_est.add_theme_constant_override("h_separation", 8)
	grid_est.add_theme_constant_override("v_separation", 8)
	vbox_est.add_child(grid_est)

	for c_info in [{"id": 0, "nombre": "Línea Blanca"}, {"id": 1, "nombre": "Línea Amarilla"}]:
		var btn_c := Button.new()
		btn_c.text = c_info["nombre"]
		btn_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_c.custom_minimum_size = Vector2(0, 56)
		btn_c.add_theme_font_size_override("font_size", 20)
		if _fuente_ui:
			btn_c.add_theme_font_override("font", _fuente_ui)
		var act_c: bool = (_parqueo_color_sel == int(c_info["id"]))
		_estilar_boton(btn_c, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if act_c else COLOR_BORDE, 10.0)
		btn_c.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if act_c else COLOR_TEXTO_PRI)
		var id_c := int(c_info["id"])
		btn_c.pressed.connect(func():
			_parqueo_color_sel = id_c
			parqueo_color_lineas_cambiado.emit(id_c)
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		grid_est.add_child(btn_c)

	var btn_luz := Button.new()
	btn_luz.text = "💡 Luz: ON" if _parqueo_iluminacion_sel else "💡 Luz: OFF"
	btn_luz.custom_minimum_size = Vector2(0, 56)
	btn_luz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_luz.add_theme_font_size_override("font_size", 20)
	if _fuente_ui:
		btn_luz.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_luz, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _parqueo_iluminacion_sel else COLOR_BORDE, 10.0)
	btn_luz.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if _parqueo_iluminacion_sel else COLOR_TEXTO_SEC)
	btn_luz.pressed.connect(func():
		_parqueo_iluminacion_sel = not _parqueo_iluminacion_sel
		parqueo_iluminacion_cambiada.emit(_parqueo_iluminacion_sel)
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	grid_est.add_child(btn_luz)

	var btn_arb := Button.new()
	btn_arb.text = "🌳 Árboles: ON" if _parqueo_arbolado_sel else "🌳 Árboles: OFF"
	btn_arb.custom_minimum_size = Vector2(0, 56)
	btn_arb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_arb.add_theme_font_size_override("font_size", 20)
	if _fuente_ui:
		btn_arb.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_arb, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _parqueo_arbolado_sel else COLOR_BORDE, 10.0)
	btn_arb.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if _parqueo_arbolado_sel else COLOR_TEXTO_SEC)
	btn_arb.pressed.connect(func():
		_parqueo_arbolado_sel = not _parqueo_arbolado_sel
		parqueo_arbolado_cambiado.emit(_parqueo_arbolado_sel)
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	grid_est.add_child(btn_arb)

	# 5. Acciones de Terreno y Borrado
	var hbox_acc := HBoxContainer.new()
	hbox_acc.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_acc)

	var btn_niv := Button.new()
	btn_niv.text = "⫶ Nivelar"
	btn_niv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_niv.custom_minimum_size = Vector2(0, 58)
	btn_niv.add_theme_font_size_override("font_size", 21)
	if _fuente_ui:
		btn_niv.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_niv, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
	btn_niv.pressed.connect(func(): parqueo_nivelar_solicitado.emit())
	hbox_acc.add_child(btn_niv)

	var btn_del := Button.new()
	btn_del.text = "✕ Eliminar"
	btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del.custom_minimum_size = Vector2(0, 58)
	btn_del.add_theme_font_size_override("font_size", 21)
	if _fuente_ui:
		btn_del.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_del, COLOR_CRIMSON_SALIR, Color(1.0, 0.45, 0.45, 0.65), 10.0)
	btn_del.add_theme_color_override("font_color", Color.WHITE)
	btn_del.pressed.connect(func(): parqueo_eliminar_solicitado.emit())
	hbox_acc.add_child(btn_del)

var _concreto_hay_seleccion: bool = false
var _concreto_finalizado: bool = false
var _concreto_num_puntos: int = 8
var _concreto_acabado_sel: int = 0
var _concreto_altura_sel: float = 0.16
var _concreto_bordillo_sel: bool = false
var _concreto_adaptar_terreno_sel: bool = true

func actualizar_estado_concreto_ui(hay_sel: bool, datos: Dictionary) -> void:
	_concreto_hay_seleccion = hay_sel
	if hay_sel:
		_concreto_finalizado = bool(datos.get("finalizado", false))
		_concreto_num_puntos = int(datos.get("num_puntos", 8))
		_concreto_acabado_sel = int(datos.get("acabado", 0))
		_concreto_altura_sel = float(datos.get("altura_losa", 0.16))
		_concreto_bordillo_sel = bool(datos.get("bordillo", false))
		_concreto_adaptar_terreno_sel = bool(datos.get("adaptar_terreno", _concreto_adaptar_terreno_sel))
	else:
		_concreto_finalizado = false
		_concreto_num_puntos = 8
	if _categoria_activa == "concreto":
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func _construir_vista_concreto() -> void:
	# 1. Tarjeta de Estado
	var card_info := PanelContainer.new()
	var borde_estado := Color(0.35, 0.90, 0.52, 0.75) if (_concreto_hay_seleccion and _concreto_finalizado) else (COLOR_AMARILLO_SEL if _concreto_hay_seleccion else COLOR_BORDE)
	_estilar_panel_glass(card_info, Color(0.09, 0.10, 0.12, 0.92), borde_estado, 12.0, 14.0)
	_box_prop_contenido.add_child(card_info)

	var vbox_info := VBoxContainer.new()
	vbox_info.add_theme_constant_override("separation", 6)
	card_info.add_child(vbox_info)

	var lbl_tit := Label.new()
	if _concreto_hay_seleccion:
		lbl_tit.text = ("CONCRETO LISTO (%d pts)" % _concreto_num_puntos) if _concreto_finalizado else ("EDITANDO PUNTOS (%d)" % _concreto_num_puntos)
		lbl_tit.add_theme_color_override("font_color", Color(0.42, 0.94, 0.58) if _concreto_finalizado else COLOR_AMARILLO_SEL)
	else:
		lbl_tit.text = "SUELO DE CONCRETO"
		lbl_tit.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	lbl_tit.add_theme_font_size_override("font_size", 23)
	if _fuente_ui:
		lbl_tit.add_theme_font_override("font", _fuente_ui)
	vbox_info.add_child(lbl_tit)

	var lbl_desc := Label.new()
	if _concreto_hay_seleccion and not _concreto_finalizado:
		lbl_desc.text = "Arrastra los puntos amarillos para dar forma al suelo de concreto o agrega más vértices."
	elif _concreto_hay_seleccion:
		lbl_desc.text = "Toca Editar Puntos para seguir moldeando la losa o cambia su acabado."
	else:
		lbl_desc.text = "Crea una losa de concreto con 8 puntos editables (R para rotar) y agrégale más puntos si lo necesitas."
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", 19)
	lbl_desc.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_desc.add_theme_font_override("font", _fuente_ui)
	vbox_info.add_child(lbl_desc)

	# 2. Edición de puntos y flujo
	if _concreto_hay_seleccion:
		var card_flujo := PanelContainer.new()
		_estilar_panel_glass(card_flujo, Color(0.09, 0.10, 0.12, 0.92), COLOR_BORDE, 12.0, 14.0)
		_box_prop_contenido.add_child(card_flujo)

		var vbox_flujo := VBoxContainer.new()
		vbox_flujo.add_theme_constant_override("separation", 10)
		card_flujo.add_child(vbox_flujo)

		if not _concreto_finalizado:
			var btn_fin := Button.new()
			btn_fin.text = "✓ FINALIZAR CONCRETO"
			btn_fin.custom_minimum_size = Vector2(0, 60)
			btn_fin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_fin.add_theme_font_size_override("font_size", 22)
			if _fuente_ui:
				btn_fin.add_theme_font_override("font", _fuente_ui)
			_estilar_boton(btn_fin, Color(0.14, 0.56, 0.30, 0.95), Color(0.35, 0.90, 0.52, 0.95), 10.0)
			btn_fin.add_theme_color_override("font_color", Color.WHITE)
			btn_fin.pressed.connect(func(): concreto_finalizar_solicitado.emit())
			vbox_flujo.add_child(btn_fin)
		else:
			var btn_ed := Button.new()
			btn_ed.text = "✏️ EDITAR PUNTOS"
			btn_ed.custom_minimum_size = Vector2(0, 56)
			btn_ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_ed.add_theme_font_size_override("font_size", 22)
			if _fuente_ui:
				btn_ed.add_theme_font_override("font", _fuente_ui)
			_estilar_boton(btn_ed, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
			btn_ed.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
			btn_ed.pressed.connect(func(): concreto_editar_puntos_solicitado.emit())
			vbox_flujo.add_child(btn_ed)

		var hbox_pts := HBoxContainer.new()
		hbox_pts.add_theme_constant_override("separation", 8)
		vbox_flujo.add_child(hbox_pts)

		var btn_add_pt := Button.new()
		btn_add_pt.text = "＋ Punto"
		btn_add_pt.custom_minimum_size = Vector2(0, 52)
		btn_add_pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_add_pt.add_theme_font_size_override("font_size", 20)
		if _fuente_ui:
			btn_add_pt.add_theme_font_override("font", _fuente_ui)
		_estilar_boton(btn_add_pt, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
		btn_add_pt.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
		btn_add_pt.pressed.connect(func(): concreto_agregar_punto_solicitado.emit())
		hbox_pts.add_child(btn_add_pt)

		var btn_subdiv := Button.new()
		btn_subdiv.text = "◫ x2 Puntos"
		btn_subdiv.custom_minimum_size = Vector2(0, 52)
		btn_subdiv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_subdiv.add_theme_font_size_override("font_size", 20)
		if _fuente_ui:
			btn_subdiv.add_theme_font_override("font", _fuente_ui)
		_estilar_boton(btn_subdiv, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
		btn_subdiv.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
		btn_subdiv.pressed.connect(func(): concreto_subdividir_solicitado.emit())
		hbox_pts.add_child(btn_subdiv)

		var btn_del_pt := Button.new()
		btn_del_pt.text = "－ Quitar"
		btn_del_pt.custom_minimum_size = Vector2(0, 52)
		btn_del_pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_del_pt.add_theme_font_size_override("font_size", 20)
		if _fuente_ui:
			btn_del_pt.add_theme_font_override("font", _fuente_ui)
		_estilar_boton(btn_del_pt, COLOR_PANEL_SEC, COLOR_CRIMSON_SALIR, 10.0)
		btn_del_pt.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
		btn_del_pt.pressed.connect(func(): concreto_eliminar_punto_solicitado.emit())
		hbox_pts.add_child(btn_del_pt)

		var hbox_rot := HBoxContainer.new()
		hbox_rot.add_theme_constant_override("separation", 6)
		vbox_flujo.add_child(hbox_rot)
		for delta_r in [-90.0, -15.0, 15.0, 90.0]:
			var btn_r := Button.new()
			btn_r.text = ("%+d°" % int(delta_r))
			btn_r.custom_minimum_size = Vector2(0, 46)
			btn_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_r.add_theme_font_size_override("font_size", 19)
			if _fuente_ui:
				btn_r.add_theme_font_override("font", _fuente_ui)
			_estilar_boton(btn_r, COLOR_PANEL_SEC, COLOR_BORDE, 8.0)
			btn_r.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
			var dr := float(delta_r)
			btn_r.pressed.connect(func(): concreto_rotacion_delta_solicitada.emit(dr))
			hbox_rot.add_child(btn_r)

		_crear_fila_slider("Espesor Losa", "act_nivelar", 0.05, 0.80, _concreto_altura_sel, "m", 0.02, func(v):
			_concreto_altura_sel = v
			concreto_altura_cambiada.emit(v)
		)

	var padre_adaptar: VBoxContainer = _box_sliders_contenido if is_instance_valid(_box_sliders_contenido) else _box_prop_contenido
	var btn_adaptar_terreno := Button.new()
	btn_adaptar_terreno.custom_minimum_size = Vector2(0, 50)
	btn_adaptar_terreno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estilar_boton(btn_adaptar_terreno, Color(0.18, 0.15, 0.08, 0.92) if _concreto_adaptar_terreno_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _concreto_adaptar_terreno_sel else COLOR_BORDE, 10.0)
	var hbox_adaptar := HBoxContainer.new()
	hbox_adaptar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox_adaptar.offset_left = 14.0
	hbox_adaptar.offset_right = -14.0
	hbox_adaptar.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox_adaptar.add_theme_constant_override("separation", 10)
	hbox_adaptar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_adaptar_terreno.add_child(hbox_adaptar)

	var chk_adaptar := CheckBox.new()
	chk_adaptar.button_pressed = _concreto_adaptar_terreno_sel
	chk_adaptar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_adaptar.add_child(chk_adaptar)

	var lbl_adaptar := Label.new()
	lbl_adaptar.text = "Adaptar a Terreno"
	lbl_adaptar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_adaptar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_adaptar.add_theme_font_size_override("font_size", 20)
	lbl_adaptar.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if _concreto_adaptar_terreno_sel else COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_adaptar.add_theme_font_override("font", _fuente_ui)
	lbl_adaptar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox_adaptar.add_child(lbl_adaptar)

	btn_adaptar_terreno.pressed.connect(func():
		_concreto_adaptar_terreno_sel = not _concreto_adaptar_terreno_sel
		chk_adaptar.button_pressed = _concreto_adaptar_terreno_sel
		_estilar_boton(btn_adaptar_terreno, Color(0.18, 0.15, 0.08, 0.92) if _concreto_adaptar_terreno_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _concreto_adaptar_terreno_sel else COLOR_BORDE, 10.0)
		lbl_adaptar.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if _concreto_adaptar_terreno_sel else COLOR_TEXTO_PRI)
		concreto_adaptar_terreno_cambiado.emit(_concreto_adaptar_terreno_sel)
	)
	padre_adaptar.add_child(btn_adaptar_terreno)

	# 3. Acabados de Concreto
	var card_acab := PanelContainer.new()
	_estilar_panel_glass(card_acab, Color(0.09, 0.10, 0.12, 0.92), COLOR_BORDE, 12.0, 14.0)
	_box_prop_contenido.add_child(card_acab)

	var vbox_acab := VBoxContainer.new()
	vbox_acab.add_theme_constant_override("separation", 10)
	card_acab.add_child(vbox_acab)

	var lbl_acab := Label.new()
	lbl_acab.text = "ACABADO DE CONCRETO"
	lbl_acab.add_theme_font_size_override("font_size", 21)
	lbl_acab.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui:
		lbl_acab.add_theme_font_override("font", _fuente_ui)
	vbox_acab.add_child(lbl_acab)

	var grid_acab := GridContainer.new()
	grid_acab.columns = 2
	grid_acab.add_theme_constant_override("h_separation", 8)
	grid_acab.add_theme_constant_override("v_separation", 8)
	vbox_acab.add_child(grid_acab)

	var acabados := [
		{"id": 0, "nombre": "Concreto Liso"},
		{"id": 1, "nombre": "Losas / Juntas"},
		{"id": 2, "nombre": "Concreto Oscuro"},
		{"id": 3, "nombre": "Adoquín Gris"}
	]
	for ac in acabados:
		var btn_a := Button.new()
		btn_a.text = ac["nombre"]
		btn_a.custom_minimum_size = Vector2(0, 54)
		btn_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_a.add_theme_font_size_override("font_size", 19)
		if _fuente_ui:
			btn_a.add_theme_font_override("font", _fuente_ui)
		var activo: bool = (_concreto_acabado_sel == int(ac["id"]))
		_estilar_boton(btn_a, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if activo else COLOR_BORDE, 10.0)
		btn_a.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if activo else COLOR_TEXTO_PRI)
		var id_a := int(ac["id"])
		btn_a.pressed.connect(func():
			_concreto_acabado_sel = id_a
			concreto_acabado_cambiado.emit(id_a)
			_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
		)
		grid_acab.add_child(btn_a)

	var btn_bord := Button.new()
	btn_bord.text = "Bordillo: SÍ" if _concreto_bordillo_sel else "Bordillo: NO"
	btn_bord.custom_minimum_size = Vector2(0, 54)
	btn_bord.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_bord.add_theme_font_size_override("font_size", 20)
	if _fuente_ui:
		btn_bord.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_bord, Color(0.18, 0.15, 0.08, 0.92) if _concreto_bordillo_sel else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if _concreto_bordillo_sel else COLOR_BORDE, 10.0)
	btn_bord.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if _concreto_bordillo_sel else COLOR_TEXTO_PRI)
	btn_bord.pressed.connect(func():
		_concreto_bordillo_sel = not _concreto_bordillo_sel
		concreto_bordillo_cambiado.emit(_concreto_bordillo_sel)
		_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)
	)
	_box_prop_contenido.add_child(btn_bord)

	# 4. Nivelar y Eliminar
	var hbox_acc := HBoxContainer.new()
	hbox_acc.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_acc)

	var btn_niv := Button.new()
	btn_niv.text = "⫶ Nivelar"
	btn_niv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_niv.custom_minimum_size = Vector2(0, 58)
	btn_niv.add_theme_font_size_override("font_size", 21)
	if _fuente_ui:
		btn_niv.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_niv, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
	btn_niv.pressed.connect(func(): concreto_nivelar_solicitado.emit())
	hbox_acc.add_child(btn_niv)

	var btn_del := Button.new()
	btn_del.text = "✕ Eliminar"
	btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del.custom_minimum_size = Vector2(0, 58)
	btn_del.add_theme_font_size_override("font_size", 21)
	if _fuente_ui:
		btn_del.add_theme_font_override("font", _fuente_ui)
	_estilar_boton(btn_del, COLOR_CRIMSON_SALIR, Color(1.0, 0.45, 0.45, 0.65), 10.0)
	btn_del.add_theme_color_override("font_color", Color.WHITE)
	btn_del.pressed.connect(func(): concreto_eliminar_solicitado.emit())
	hbox_acc.add_child(btn_del)

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
	var destino_slider: VBoxContainer = _box_sliders_contenido if is_instance_valid(_box_sliders_contenido) else _box_prop_contenido
	destino_slider.add_child(vbox_item)

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
		var sl = _dict_sliders[titulo]
		if is_instance_valid(sl):
			sl.value = nuevo_val
		else:
			_dict_sliders.erase(titulo)

# ── BOTONES DE ACCIÓN INFERIORES ("Restablecer" y "Aplicar") ──────────
func _crear_botones_accion_inferiores(callback_reset: Callable, callback_aplicar: Callable, texto_reset: String = "Restablecer", texto_aplicar: String = "Aplicar") -> void:
	var hbox_acts := HBoxContainer.new()
	hbox_acts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_acts.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_acts)

	# Botón Secundario / Restablecer / Peligro
	_btn_prop_restablecer = Button.new()
	_btn_prop_restablecer.text = " " + texto_reset
	_btn_prop_restablecer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_prop_restablecer.custom_minimum_size = Vector2(0, 52)
	_btn_prop_restablecer.clip_text = true
	_btn_prop_restablecer.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	if _fuente_ui:
		_btn_prop_restablecer.add_theme_font_override("font", _fuente_ui)

	var es_peligro: bool = texto_reset.begins_with("Eliminar") or texto_reset.begins_with("Demoler") or texto_reset.begins_with("Borrar")
	if es_peligro:
		_estilar_boton(_btn_prop_restablecer, Color(0.20, 0.08, 0.08, 0.92), COLOR_CRIMSON_SALIR, 12.0)
		_btn_prop_restablecer.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85, 1.0))
		var ico_del := _cargar_icono_svg("act_demoler")
		if ico_del:
			_btn_prop_restablecer.icon = ico_del
			_btn_prop_restablecer.expand_icon = true
			_btn_prop_restablecer.add_theme_constant_override("icon_max_width", 22)
	else:
		_estilar_boton(_btn_prop_restablecer, COLOR_PANEL_SEC, COLOR_BORDE, 12.0)
		var ico_rst := _cargar_icono_svg("act_restablecer")
		if ico_rst:
			_btn_prop_restablecer.icon = ico_rst
			_btn_prop_restablecer.expand_icon = true
			_btn_prop_restablecer.add_theme_constant_override("icon_max_width", 22)

	_btn_prop_restablecer.pressed.connect(callback_reset)
	hbox_acts.add_child(_btn_prop_restablecer)

	# Botón Primario / Aplicar / Acción principal
	_btn_prop_aplicar = Button.new()
	_btn_prop_aplicar.text = " " + texto_aplicar
	_btn_prop_aplicar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_prop_aplicar.custom_minimum_size = Vector2(0, 52)
	_btn_prop_aplicar.clip_text = true
	_estilar_boton(_btn_prop_aplicar, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	_btn_prop_aplicar.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	_btn_prop_aplicar.add_theme_font_size_override("font_size", FONT_BOTON_ACCION) # 24px
	if _fuente_ui:
		_btn_prop_aplicar.add_theme_font_override("font", _fuente_ui)
	var ico_apl := _cargar_icono_svg("act_aplicar")
	if ico_apl:
		_btn_prop_aplicar.icon = ico_apl
		_btn_prop_aplicar.expand_icon = true
		_btn_prop_aplicar.add_theme_constant_override("icon_max_width", 24)

	_btn_colocar_grande = _btn_prop_aplicar

	_btn_prop_aplicar.pressed.connect(func():
		if is_inside_tree():
			var tween = create_tween()
			tween.tween_property(_btn_prop_aplicar, "scale", Vector2(0.96, 0.96), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(_btn_prop_aplicar, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		callback_aplicar.call()
	)
	hbox_acts.add_child(_btn_prop_aplicar)

# ── LLENADO DE LA CUADRÍCULA DE HERRAMIENTAS (ZONA C) ─────────────────
func _refrescar_grid_herramientas(cat_id: String) -> void:
	for child in _grid_herramientas.get_children():
		_grid_herramientas.remove_child(child)
		child.queue_free()
	if _box_herramientas:
		for child in _box_herramientas.get_children():
			if child != _grid_herramientas:
				_box_herramientas.remove_child(child)
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
				{"id": "pendiente", "nombre": "Rampa", "ico": "act_nivelar"},
				{"id": "pintar", "nombre": "Pintar", "ico": "terreno_pintar"},
				{"id": "follaje", "nombre": "Follaje 3D", "ico": "terreno_cesped"},
				{"id": "lotes", "nombre": "+ Lotes", "ico": "terreno_aplanar"}
			]
		"vias":
			# Biblioteca organizada por secciones compactas: Vías, Rotondas y Cruces/Obra
			if _box_herramientas:
				var hbox_tabs := HBoxContainer.new()
				hbox_tabs.add_theme_constant_override("separation", 8)
				hbox_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var secs_vias: Array = [
					{"id": "vias", "nom": "Vías"},
					{"id": "rotondas", "nom": "Rotondas"},
					{"id": "cruces", "nom": "Cruces"}
				]
				for sec: Dictionary in secs_vias:
					var s_id: String = sec["id"]
					var btn_sec := Button.new()
					btn_sec.text = sec["nom"]
					btn_sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn_sec.custom_minimum_size = Vector2(110, 52)
					btn_sec.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
					if _fuente_ui:
						btn_sec.add_theme_font_override("font", _fuente_ui)
					var es_sec_act: bool = (_seccion_vias_library == s_id)
					_estilar_boton(btn_sec, COLOR_AMARILLO_SEL if es_sec_act else COLOR_PANEL_SEC, COLOR_AMARILLO_PRI if es_sec_act else COLOR_BORDE, 8.0)
					btn_sec.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL if es_sec_act else COLOR_TEXTO_PRI)
					btn_sec.pressed.connect(func():
						_seccion_vias_library = s_id
						_refrescar_grid_herramientas("vias")
					)
					hbox_tabs.add_child(btn_sec)
				_box_herramientas.add_child(hbox_tabs)
				_box_herramientas.move_child(hbox_tabs, 0)

			match _seccion_vias_library:
				"rotondas":
					lista_tools = [
						{"id": "rotonda", "nombre": "Rotonda Clásica", "ico": "via_rotonda"}
					]
				"cruces":
					lista_tools = [
						{"id": "conectar", "nombre": "Conectar", "ico": "via_conectar"},
						{"id": "cruce_t", "nombre": "Cruce en T", "ico": "via_cruce_t"},
						{"id": "cruce_4", "nombre": "Cruce Cruz", "ico": "via_cruce_4"},
						{"id": "dividir", "nombre": "Dividir Vía", "ico": "via_dividir"},
						{"id": "equipamiento_vias", "nombre": "Equipar", "ico": "via_equipamiento"},
						{"id": "nivelar", "nombre": "Nivelar", "ico": "act_nivelar"},
						{"id": "auto_nivelar", "nombre": "Auto-Nivel", "ico": "act_nivelar"}
					]
				_:
					lista_tools = [
						{"id": "calle_1", "nombre": "Calle 1C", "ico": "via_calle_1"},
						{"id": "calle_2", "nombre": "Calle 2C", "ico": "via_calle_2"},
						{"id": "nacional", "nombre": "Nacional", "ico": "via_nacional"},
						{"id": "avenida_4", "nombre": "Avenida 4C", "ico": "via_avenida_4"},
						{"id": "autopista_6", "nombre": "Autopista 6C", "ico": "via_autopista_6"},
						{"id": "doble_8", "nombre": "Doble 8C", "ico": "via_doble_8"},
						{"id": "adoquin", "nombre": "Adoquín", "ico": "via_adoquin"},
						{"id": "recebo", "nombre": "Recebo", "ico": "via_recebo"},
						{"id": "trocha", "nombre": "Trocha", "ico": "via_trocha"},
						{"id": "ciclovia", "nombre": "Ciclovía", "ico": "via_ciclovia"}
					]
		"ciudad":
			lista_tools = [
				{"id": "res", "nombre": "Viviendas", "ico": "cat_ciudad"},
				{"id": "com", "nombre": "Comercio", "ico": "cat_ciudad"},
				{"id": "inst", "nombre": "Público", "ico": "cat_ciudad"},
				{"id": "hist", "nombre": "Patrimonio", "ico": "cat_ciudad"},
				{"id": "ind", "nombre": "Industria", "ico": "cat_ciudad"},
				{"id": "zonas", "nombre": "Zonas", "ico": "cat_ciudad"},
				{"id": "auto_casas", "nombre": "Auto-Casas", "ico": "cat_ciudad"},
				{"id": "zonificar", "nombre": "Zonificar", "ico": "act_grid"},
				{"id": "rotar", "nombre": "Rotar", "ico": "act_rotar"},
				{"id": "demoler", "nombre": "Demoler", "ico": "act_demoler"},
				{"id": "mover", "nombre": "Mover", "ico": "act_colocar"},
				{"id": "grid", "nombre": "Cuadrícula", "ico": "act_grid"}
			]
		"vegetacion":
			lista_tools = [
				{"id": "dispersion", "nombre": "Pincel", "ico": "act_colocar"},
				{"id": "borrar", "nombre": "Borrar", "ico": "act_demoler"},
				{"id": "rotar", "nombre": "Rotar", "ico": "act_rotar"},
				{"id": "snap", "nombre": "Snap", "ico": "act_grid"}
			]
		"muros":
			lista_tools = [
				{"id": "muro_colocar", "nombre": "Trazar", "ico": "act_colocar"},
				{"id": "muro_finalizar", "nombre": "Finalizar", "ico": "cat_muros"},
				{"id": "muro_deshacer", "nombre": "Deshacer", "ico": "act_rotar"},
				{"id": "muro_borrar", "nombre": "Borrar", "ico": "act_demoler"}
			]
		"parqueo":
			lista_tools = [
				{"id": "parqueo_crear", "nombre": "Crear", "ico": "act_colocar"},
				{"id": "parqueo_editar", "nombre": "Esquinas", "ico": "cat_parqueo"},
				{"id": "parqueo_nivelar", "nombre": "Nivelar", "ico": "act_nivelar"},
				{"id": "parqueo_borrar", "nombre": "Borrar", "ico": "act_demoler"}
			]
		"concreto":
			lista_tools = [
				{"id": "concreto_crear", "nombre": "Crear", "ico": "act_colocar"},
				{"id": "concreto_editar", "nombre": "Puntos", "ico": "cat_ciudad"},
				{"id": "concreto_nivelar", "nombre": "Nivelar", "ico": "act_nivelar"},
				{"id": "concreto_borrar", "nombre": "Borrar", "ico": "act_demoler"}
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

	var es_layout_cinco: bool = (lista_tools.size() == 5)
	_grid_herramientas.columns = 2 if (es_layout_cinco or lista_tools.size() == 4) else 3

	for idx in lista_tools.size():
		var t: Dictionary = lista_tools[idx]
		var es_boton_ancho: bool = es_layout_cinco and idx == 4
		var btn_t := Button.new()
		btn_t.text = t["nombre"]
		btn_t.add_theme_font_size_override("font_size", FONT_BOTON_GRID) # 17px
		if _fuente_ui:
			btn_t.add_theme_font_override("font", _fuente_ui)

		var ico := _cargar_icono_svg(t["ico"])
		if es_boton_ancho:
			btn_t.custom_minimum_size = Vector2(286, 68)
			btn_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_t.alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_t.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn_t.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			btn_t.add_theme_constant_override("h_separation", 12)
			if ico:
				btn_t.icon = ico
				btn_t.expand_icon = true
				btn_t.add_theme_constant_override("icon_max_width", 34)
		else:
			btn_t.custom_minimum_size = Vector2(138, 108) if es_layout_cinco else Vector2(114, 108)
			btn_t.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_t.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			if ico:
				btn_t.icon = ico
				btn_t.expand_icon = true
				btn_t.add_theme_constant_override("icon_max_width", 44)

		var tool_id: String = t["id"]
		btn_t.pressed.connect(func():
			_seleccionar_subherramienta(tool_id)
		)
		if es_boton_ancho and _box_herramientas:
			_box_herramientas.add_child(btn_t)
		else:
			_grid_herramientas.add_child(btn_t)
		_dict_botones_herramientas[tool_id] = btn_t

	_actualizar_estilo_botones_herramientas()
	call_deferred("_ajustar_tamano_panel_herramientas")

func _seleccionar_subherramienta(tool_id: String) -> void:
	if tool_id.begins_with("rotonda_"):
		var n_sal: int = clampi(int(tool_id.trim_prefix("rotonda_")), 3, 6)
		_rotonda_salidas_activa = n_sal
		rotonda_salidas_cambiada.emit(_rotonda_salidas_activa)
		tool_id = "rotonda"

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
		"auto_nivelar":
			_auto_nivelar_vias_activo = not _auto_nivelar_vias_activo
			auto_nivelar_vias_alternado.emit(_auto_nivelar_vias_activo)
			_actualizar_estilo_botones_herramientas()
			mostrar_notificacion("Auto-nivelar al trazar: " + ("ACTIVADO" if _auto_nivelar_vias_activo else "DESACTIVADO"))
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
			_actualizar_panel_contextual(_categoria_activa, _especie_vegetacion_activa)
			return
		"borrar":
			borrar_dispersion_vegetacion_solicitado.emit()
			return
		"muro_finalizar":
			muro_finalizar_tramo_solicitado.emit()
			return
		"muro_deshacer":
			muro_deshacer_solicitado.emit()
			return
		"muro_borrar":
			muro_borrar_solicitado.emit()
			return

	_subherramienta_activa = tool_id
	_id_item_activo = tool_id
	if _categoria_activa == "vegetacion":
		_especie_vegetacion_activa = tool_id

	_actualizar_estilo_botones_herramientas()
	if tool_id == "pintar":
		subherramienta_seleccionada.emit("pintar_" + _material_pintura_activo)
	else:
		subherramienta_seleccionada.emit(tool_id)
	_actualizar_panel_contextual(_categoria_activa, tool_id)

func _actualizar_estilo_botones_herramientas() -> void:
	for t_id in _dict_botones_herramientas:
		var btn: Button = _dict_botones_herramientas[t_id]
		var es_activo: bool = (t_id == _subherramienta_activa) or (t_id == "auto_nivelar" and _auto_nivelar_vias_activo) or (_subherramienta_activa == "rotonda" and t_id == ("rotonda_%d" % _rotonda_salidas_activa))
		var sb_normal := StyleBoxFlat.new()
		sb_normal.set_corner_radius_all(12)
		sb_normal.content_margin_left = 12
		sb_normal.content_margin_right = 12
		sb_normal.content_margin_top = 12
		sb_normal.content_margin_bottom = 10

		if es_activo:
			sb_normal.bg_color = Color(0.18, 0.14, 0.07, 0.94)
			sb_normal.set_border_width_all(2)
			sb_normal.border_color = Color(0.88, 0.68, 0.28, 0.95)
			sb_normal.shadow_color = Color(0.88, 0.68, 0.28, 0.28)
			sb_normal.shadow_size = 6
			btn.add_theme_stylebox_override("normal", sb_normal)
			btn.add_theme_stylebox_override("hover", sb_normal)
			btn.add_theme_stylebox_override("pressed", sb_normal)
			btn.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_normal_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_hover_color", COLOR_AMARILLO_SEL)
			btn.add_theme_color_override("icon_pressed_color", COLOR_AMARILLO_SEL)
		else:
			sb_normal.bg_color = Color(0.08, 0.09, 0.11, 0.84)
			sb_normal.set_border_width_all(1)
			sb_normal.border_color = Color(0.78, 0.81, 0.85, 0.22)
			sb_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
			sb_normal.shadow_size = 5
			var sb_hover := sb_normal.duplicate() as StyleBoxFlat
			sb_hover.bg_color = Color(0.13, 0.15, 0.19, 0.92)
			sb_hover.border_color = Color(0.85, 0.88, 0.92, 0.42)
			var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
			sb_pressed.bg_color = Color(0.16, 0.13, 0.08, 0.95)
			sb_pressed.border_color = Color(0.88, 0.68, 0.28, 0.75)
			btn.add_theme_stylebox_override("normal", sb_normal)
			btn.add_theme_stylebox_override("hover", sb_hover)
			btn.add_theme_stylebox_override("pressed", sb_pressed)
			btn.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
			btn.add_theme_color_override("icon_normal_color", COLOR_TEXTO_PRI)
			btn.add_theme_color_override("icon_hover_color", Color.WHITE)
			btn.add_theme_color_override("icon_pressed_color", COLOR_AMARILLO_SEL)

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
			if _subherramienta_activa == "pintar":
				_lbl_modo_estado.text = "Modo: Terreno (Pintar: %s)" % _material_pintura_activo.replace("_", " ").capitalize()
			else:
				_lbl_modo_estado.text = "Modo: Terreno (%s)" % nom
		"vias":
			_lbl_modo_estado.text = "Modo: Trazado Vías (%s)" % nom
		"ciudad":
			_lbl_modo_estado.text = "Modo: Ciudad (%s)" % nom
		"vegetacion":
			_lbl_modo_estado.text = "Modo: Naturaleza (%s)" % nom
		"muros":
			_lbl_modo_estado.text = "Modo: Muros Modulares (Toca A -> B)"
		"parqueo":
			_lbl_modo_estado.text = "Modo: Estacionamientos (Arrastra las 4 esquinas)"
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
	_popup_sistema.offset_bottom = 570.0
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

	# Distancia de renderizado (calidad / FPS)
	var box_render := VBoxContainer.new()
	box_render.add_theme_constant_override("separation", 4)
	vbox.add_child(box_render)

	var lbl_render := Label.new()
	lbl_render.text = "👁️ Distancia de Renderizado: 600 m"
	lbl_render.add_theme_font_size_override("font_size", 16)
	lbl_render.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui:
		lbl_render.add_theme_font_override("font", _fuente_ui)
	box_render.add_child(lbl_render)

	var slider_render := HSlider.new()
	slider_render.min_value = 250.0
	slider_render.max_value = 1500.0
	slider_render.step = 50.0
	slider_render.value = 600.0
	slider_render.custom_minimum_size = Vector2(0, 28)
	slider_render.value_changed.connect(func(v: float):
		lbl_render.text = "👁️ Distancia de Renderizado: %d m" % int(v)
		distancia_renderizado_cambiada.emit(v)
	)
	box_render.add_child(slider_render)

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
	if is_inside_tree():
		var tween = create_tween()
		if tween:
			tween.tween_property(_panel_toast_flotante, "modulate:a", 1.0, 0.20)
			tween.tween_interval(2.2)
			tween.tween_property(_panel_toast_flotante, "modulate:a", 0.0, 0.35)
	else:
		_panel_toast_flotante.modulate.a = 1.0

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
		"muros": sub_defecto = "muro_colocar"
		"parqueo": sub_defecto = "parqueo_crear"
		"concreto": sub_defecto = "concreto_crear"
		"agua": sub_defecto = "lago"
		"spawn": sub_defecto = "vehiculo"

	_seleccionar_subherramienta(sub_defecto)

func _construir_dock_camara_movil(padre: Control) -> void:
	_panel_camara_movil = PanelContainer.new()
	_panel_camara_movil.name = "DockCamaraMovil"
	_panel_camara_movil.anchor_left = 0.0
	_panel_camara_movil.anchor_right = 0.0
	_panel_camara_movil.anchor_top = 1.0
	_panel_camara_movil.anchor_bottom = 1.0
	_panel_camara_movil.offset_left = 20.0
	_panel_camara_movil.offset_right = 356.0
	_panel_camara_movil.offset_top = -510.0
	_panel_camara_movil.offset_bottom = -422.0
	_panel_camara_movil.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilar_panel_glass(_panel_camara_movil, COLOR_PANEL, COLOR_BORDE, 14.0, 8.0)
	padre.add_child(_panel_camara_movil)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_panel_camara_movil.add_child(hbox)

	var modos := [
		{"id": "", "nom": "Pincel", "ico": "terreno_pintar", "tip": "Usar herramienta / pincel del editor"},
		{"id": "seleccionar", "nom": "Selec.", "ico": "cam_seleccionar", "tip": "Toca cualquier objeto, vía o elemento de la escena para seleccionarlo"},
		{"id": "mover", "nom": "Mover", "ico": "cam_mover", "tip": "Arrastra con 1 dedo para mover/panear la cámara"},
		{"id": "orbitar", "nom": "Rotar", "ico": "cam_rotar", "tip": "Arrastra con 1 dedo para rotar/orbitar la cámara"},
		{"id": "zoom", "nom": "Zoom", "ico": "cam_zoom", "tip": "Arrastra arriba o abajo para acercar o alejar"}
	]
	_botones_camara_movil.clear()
	for m in modos:
		var btn := Button.new()
		btn.tooltip_text = m["tip"]
		btn.custom_minimum_size = Vector2(66, 66)
		btn.focus_mode = Control.FOCUS_NONE
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 4)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vb)

		var tex_rect := TextureRect.new()
		tex_rect.name = "Icono"
		tex_rect.custom_minimum_size = Vector2(28, 28)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture = _cargar_icono_svg(m["ico"])
		vb.add_child(tex_rect)

		var lbl := Label.new()
		lbl.name = "Texto"
		lbl.text = m["nom"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _fuente_ui:
			lbl.add_theme_font_override("font", _fuente_ui)
		vb.add_child(lbl)

		var id_modo: String = m["id"]
		btn.pressed.connect(func(): _alternar_modo_camara_movil(id_modo))
		hbox.add_child(btn)
		_botones_camara_movil[id_modo] = btn
	_actualizar_estilos_camara_movil()
	_posicionar_dock_camara_movil()

func _posicionar_dock_camara_movil() -> void:
	if not is_instance_valid(_panel_camara_movil):
		return
	var min_sz := _panel_camara_movil.get_combined_minimum_size()
	var ancho := maxf(min_sz.x, 336.0)
	var alto := maxf(min_sz.y, 84.0)
	var base_bottom := -132.0
	if is_instance_valid(_panel_herramientas) and not _esta_colapsado_herramientas:
		base_bottom = _panel_herramientas.offset_top - 10.0
	_panel_camara_movil.anchor_top = 1.0
	_panel_camara_movil.anchor_bottom = 1.0
	_panel_camara_movil.offset_left = 20.0
	_panel_camara_movil.offset_right = 20.0 + ancho
	_panel_camara_movil.offset_bottom = base_bottom
	_panel_camara_movil.offset_top = base_bottom - alto

func _alternar_modo_camara_movil(modo: String) -> void:
	if modo != "" and _modo_camara_movil == modo:
		_modo_camara_movil = ""
	else:
		_modo_camara_movil = modo
	_actualizar_estilos_camara_movil()
	modo_camara_movil_cambiado.emit(_modo_camara_movil)

func _actualizar_estilos_camara_movil() -> void:
	for k in _botones_camara_movil:
		var btn: Button = _botones_camara_movil[k]
		if is_instance_valid(btn):
			var activo: bool = (str(k) == _modo_camara_movil)
			_estilar_boton(btn, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if activo else COLOR_BORDE, 10.0)
			var col_fg := COLOR_AMARILLO_SEL if activo else Color(0.95, 0.96, 0.98)
			var tex := btn.find_child("Icono", true, false) as TextureRect
			if tex:
				tex.modulate = col_fg
			var lbl := btn.find_child("Texto", true, false) as Label
			if lbl:
				lbl.add_theme_color_override("font_color", col_fg)

func esta_sobre_interfaz(pos_pantalla: Vector2) -> bool:
	if _hud_superior and _hud_superior.visible and _hud_superior.get_global_rect().has_point(pos_pantalla):
		return true
	if _panel_herramientas and _panel_herramientas.visible and _panel_herramientas.get_global_rect().has_point(pos_pantalla):
		return true
	if _panel_camara_movil and _panel_camara_movil.visible and _panel_camara_movil.get_global_rect().has_point(pos_pantalla):
		return true
	if _panel_propiedades and _panel_propiedades.visible and _panel_propiedades.get_global_rect().has_point(pos_pantalla):
		return true
	if _panel_sliders and _panel_sliders.visible and _panel_sliders.get_global_rect().has_point(pos_pantalla):
		return true
	if _popup_sistema and _popup_sistema.visible and _popup_sistema.get_global_rect().has_point(pos_pantalla):
		return true
	if _hud_inferior_izquierdo and _hud_inferior_izquierdo.visible and _hud_inferior_izquierdo.get_global_rect().has_point(pos_pantalla):
		return true
	if _hud_barra_estado and _hud_barra_estado.visible and _hud_barra_estado.get_global_rect().has_point(pos_pantalla):
		return true
	if _btn_centrar_seleccion and _btn_centrar_seleccion.visible and _btn_centrar_seleccion.get_global_rect().has_point(pos_pantalla):
		return true
	if _btn_listo_seleccion and _btn_listo_seleccion.visible and _btn_listo_seleccion.get_global_rect().has_point(pos_pantalla):
		return true
	if _btn_flotante_rotonda and _btn_flotante_rotonda.visible and _btn_flotante_rotonda.get_global_rect().has_point(pos_pantalla):
		return true
	if _btn_flotante_finalizar_muro and _btn_flotante_finalizar_muro.visible and _btn_flotante_finalizar_muro.get_global_rect().has_point(pos_pantalla):
		return true
	return false

func actualizar_telemetria_trazo_via(activa: bool, distancia_m: float, pendiente_pct: float) -> void:
	if not _lbl_modo_estado:
		return
	if not activa:
		_actualizar_etiqueta_estado()
		_lbl_modo_estado.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
		return
	_lbl_modo_estado.text = "Tramo: %.0fm  •  Pendiente: %.1f%%" % [distancia_m, pendiente_pct]
	if pendiente_pct > 18.0:
		_lbl_modo_estado.add_theme_color_override("font_color", COLOR_CRIMSON_SALIR)
	elif pendiente_pct > 12.0:
		_lbl_modo_estado.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	else:
		_lbl_modo_estado.add_theme_color_override("font_color", COLOR_VERDE_ACTIVO)

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
		match categoria:
			"vias":
				if subherramienta == "equipamiento_vias":
					if _paso_equipamiento_actual == 2:
						_btn_colocar_grande.text = "✓ Aplicar al Tramo"
						_estilar_boton(_btn_colocar_grande, Color(0.14, 0.56, 0.30, 0.95), Color(0.35, 0.90, 0.52, 0.9), 12.0)
						_btn_colocar_grande.add_theme_color_override("font_color", Color.WHITE)
						return
					elif _paso_equipamiento_actual == 1:
						_btn_colocar_grande.text = "📍 Toca Punto B (Fin)"
					else:
						_btn_colocar_grande.text = "📍 Toca Punto A (Inicio)"
				elif subherramienta in ["cruce_4", "cruce_t"]:
					_btn_colocar_grande.text = "＋ Colocar Cruce"
				elif _snap_conexion or _origen_conexion_fijado:
					_btn_colocar_grande.text = "☍ Conectar Vías Aquí"
				elif _sobre_cruce_existente:
					_btn_colocar_grande.text = "✎ Editar Cruce"
				elif _sobre_punto_existente:
					_btn_colocar_grande.text = "✎ Editar Punto"
				else:
					_btn_colocar_grande.text = "＋ Colocar Punto de Vía"
				_estilar_boton(_btn_colocar_grande, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
				_btn_colocar_grande.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
			_:
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
func mostrar_panel_edicion_cruce(datos: Dictionary, _datos_ramales: Array = []) -> void:
	_asegurar_panel_propiedades_visible_y_expandido()
	mostrar_boton_centrar_seleccion(true)

	_ico_prop_header.texture = _cargar_icono_svg("via_cruce_4")
	if not _ico_prop_header.texture:
		_ico_prop_header.texture = _cargar_icono_svg("via_calle_2")
	_lbl_prop_titulo.text = "Editar Cruce"
	_lbl_prop_badge.text = "● Cruce"
	for child in _box_prop_contenido.get_children():
		_box_prop_contenido.remove_child(child)
		child.queue_free()
	_limpiar_sliders_contenido()

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

	var hbox_ctrl := HBoxContainer.new()
	hbox_ctrl.add_theme_constant_override("separation", 6)
	_box_prop_contenido.add_child(hbox_ctrl)
	var ctrl_act := str(datos.get("control_trafico", "semaforo"))
	for ct in [{"id": "semaforo", "nom": "🚦 Semáforos"}, {"id": "pare", "nom": "🛑 PARE"}, {"id": "libre", "nom": "➡ Libre"}]:
		var btn_ct := Button.new()
		btn_ct.text = ct["nom"]
		btn_ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_ct.custom_minimum_size = Vector2(0, 42)
		btn_ct.add_theme_font_size_override("font_size", 15)
		var act_ct := (ctrl_act == str(ct["id"]))
		_estilar_boton(btn_ct, Color(0.18, 0.15, 0.08, 0.92) if act_ct else COLOR_PANEL_SEC, COLOR_AMARILLO_SEL if act_ct else COLOR_BORDE, 8.0)
		if _fuente_ui:
			btn_ct.add_theme_font_override("font", _fuente_ui)
		var cid := str(ct["id"])
		btn_ct.pressed.connect(func(): cruce_control_trafico_cambiado.emit(cid))
		hbox_ctrl.add_child(btn_ct)

	_crear_botones_accion_inferiores(
		func(): cruce_eliminar_solicitado.emit(),
		func(): cruce_edicion_cerrada.emit(),
		"Eliminar Cruce",
		"Cerrar Edición"
	)
	call_deferred("_ajustar_tamano_panel_propiedades")

func actualizar_datos_panel_cruce(datos: Dictionary) -> void:
	if datos.has("radio"):
		_actualizar_slider_val("Radio de Cruce", float(datos["radio"]))
	if datos.has("rotacion"):
		_actualizar_slider_val("Rotación Cruce", float(datos["rotacion"]))

func actualizar_seccion_ramales(_datos_ramales: Array) -> void:
	pass

func ocultar_panel_edicion_cruce() -> void:
	mostrar_boton_centrar_seleccion(false)
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func _seleccionar_boton_tipo_via(_tipo: int) -> void:
	pass

func mostrar_panel_edicion_punto_via(datos: Dictionary) -> void:
	_asegurar_panel_propiedades_visible_y_expandido()
	mostrar_boton_centrar_seleccion(true)
	if _btn_flotante_rotonda:
		_btn_flotante_rotonda.visible = false

	_ico_prop_header.texture = _cargar_icono_svg("via_modificar")
	if not _ico_prop_header.texture:
		_ico_prop_header.texture = _cargar_icono_svg("act_nivelar")
	_lbl_prop_titulo.text = "Editar Rasante"
	_lbl_prop_badge.text = "● Rasante"
	for child in _box_prop_contenido.get_children():
		_box_prop_contenido.remove_child(child)
		child.queue_free()
	_limpiar_sliders_contenido()

	_crear_fila_slider("Altura Rasante", "act_nivelar", -10.0, 35.0, float(datos.get("altura", 0.0)), "m", 0.5, func(v):
		punto_via_altura_cambiada.emit(v)
	)
	_crear_fila_slider("Peralte Curva", "act_rotar", -15.0, 15.0, float(datos.get("peralte", 0.0)), "°", 0.5, func(v):
		punto_via_peralte_cambiado.emit(v)
	)

	var btn_seguir := Button.new()
	btn_seguir.text = "＋ Seguir Carretera desde Aquí"
	btn_seguir.clip_text = true
	btn_seguir.custom_minimum_size = Vector2(0, 54)
	btn_seguir.add_theme_font_size_override("font_size", FONT_BOTON_ACCION) # 24px
	_estilar_boton(btn_seguir, COLOR_AMARILLO_SEL, COLOR_AMARILLO_PRI, 12.0)
	btn_seguir.add_theme_color_override("font_color", COLOR_FONDO_PRINCIPAL)
	if _fuente_ui:
		btn_seguir.add_theme_font_override("font", _fuente_ui)
	btn_seguir.pressed.connect(func(): seguir_carretera_desde_punto_solicitado.emit())
	_box_prop_contenido.add_child(btn_seguir)

	var btn_cerrar_tramo := Button.new()
	btn_cerrar_tramo.text = "☍ Seleccionar Tramo (A → B)"
	btn_cerrar_tramo.clip_text = true
	btn_cerrar_tramo.custom_minimum_size = Vector2(0, 48)
	btn_cerrar_tramo.add_theme_font_size_override("font_size", FONT_BOTON_MEDIO) # 21px
	_estilar_boton(btn_cerrar_tramo, COLOR_PANEL_SEC, COLOR_AMARILLO_PRI, 12.0)
	if _fuente_ui:
		btn_cerrar_tramo.add_theme_font_override("font", _fuente_ui)
	btn_cerrar_tramo.pressed.connect(func(): seleccionar_tramo_desde_punto_solicitado.emit())
	_box_prop_contenido.add_child(btn_cerrar_tramo)

	var btn_adaptar := Button.new()
	btn_adaptar.text = "⊞ Adaptar Terreno al Tramo"
	btn_adaptar.clip_text = true
	btn_adaptar.custom_minimum_size = Vector2(0, 48)
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
	call_deferred("_ajustar_tamano_panel_propiedades")

func actualizar_datos_panel_punto_via(datos: Dictionary) -> void:
	if datos.has("altura"):
		_actualizar_slider_val("Altura Rasante", float(datos["altura"]))
	if datos.has("peralte"):
		_actualizar_slider_val("Peralte Curva", float(datos["peralte"]))

func ocultar_panel_edicion_punto_via() -> void:
	mostrar_boton_centrar_seleccion(false)
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func actualizar_subherramienta_externa(categoria: String, subherramienta: String) -> void:
	_categoria_activa = categoria
	_subherramienta_activa = subherramienta
	_id_item_activo = subherramienta
	_actualizar_estilo_botones_herramientas()
	_actualizar_panel_contextual(categoria, subherramienta)

func _seleccionar_boton_tipo_via_punto(_tipo: int) -> void:
	pass

func mostrar_panel_equipamiento_vias(_datos: Dictionary = {}) -> void:
	_asegurar_panel_propiedades_visible_y_expandido()

	_ico_prop_header.texture = _cargar_icono_svg("via_equipamiento")
	_lbl_prop_titulo.text = "Equipamiento Vial"
	_actualizar_badge_equipamiento(_datos)
	for child in _box_prop_contenido.get_children():
		_box_prop_contenido.remove_child(child)
		child.queue_free()
	_limpiar_sliders_contenido()

	var paso: int = int(_datos.get("paso", 0))
	_paso_equipamiento_actual = paso

	# Banner de guía paso a paso
	var panel_guia := PanelContainer.new()
	var sb_guia := StyleBoxFlat.new()
	sb_guia.bg_color = Color(0.18, 0.14, 0.06, 0.92) if paso < 2 else Color(0.08, 0.20, 0.12, 0.92)
	sb_guia.border_color = COLOR_AMARILLO_PRI if paso < 2 else Color(0.30, 0.85, 0.50, 0.85)
	sb_guia.set_border_width_all(1)
	sb_guia.set_corner_radius_all(10)
	sb_guia.set_content_margin_all(12)
	panel_guia.add_theme_stylebox_override("panel", sb_guia)
	_box_prop_contenido.add_child(panel_guia)

	var lbl_guia := Label.new()
	lbl_guia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_guia.add_theme_font_size_override("font_size", 17)
	lbl_guia.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if paso < 2 else Color(0.65, 1.0, 0.78))
	if _fuente_ui:
		lbl_guia.add_theme_font_override("font", _fuente_ui)
	if paso == 0:
		lbl_guia.text = "SELECCIÓN DE TRAMO\nToca directamente cualquier tramo de vía en 3D o elige Punto A → Punto B."
	elif paso == 1:
		lbl_guia.text = "PASO 2 DE 2 — Punto A fijado\n👉 Toca OTRO punto (●) de la carretera para elegir el FIN (Punto B)."
	else:
		lbl_guia.text = "✅ Tramo listo: %.1fm (%d puntos)\nPersonaliza tipo, superficie, señalización o equipamiento abajo." % [float(_datos.get("distancia", 0.0)), int(_datos.get("num_puntos", 0))]
	panel_guia.add_child(lbl_guia)

	if paso < 2:
		var btn_reset_a := Button.new()
		btn_reset_a.text = "↺ Cambiar Punto A" if paso == 1 else "✕ Cancelar"
		btn_reset_a.custom_minimum_size = Vector2(0, 44)
		btn_reset_a.add_theme_font_size_override("font_size", 18)
		_estilar_boton(btn_reset_a, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
		if _fuente_ui:
			btn_reset_a.add_theme_font_override("font", _fuente_ui)
		btn_reset_a.pressed.connect(func(): equipamiento_cancelar_solicitado.emit())
		_box_prop_contenido.add_child(btn_reset_a)
		_ajustar_tamano_panel_propiedades()
		return

	# Barra de 4 pestañas limpias para evitar saturar el inspector
	var hbox_tabs_tramo := HBoxContainer.new()
	hbox_tabs_tramo.add_theme_constant_override("separation", 6)
	_box_prop_contenido.add_child(hbox_tabs_tramo)

	var box_tab_equipar := VBoxContainer.new()
	box_tab_equipar.add_theme_constant_override("separation", 10)
	var box_tab_senales := VBoxContainer.new()
	box_tab_senales.add_theme_constant_override("separation", 10)
	var box_tab_estilo := VBoxContainer.new()
	box_tab_estilo.add_theme_constant_override("separation", 10)
	var box_tab_via := VBoxContainer.new()
	box_tab_via.add_theme_constant_override("separation", 10)

	var tabs_def := [
		{"id": "equipar", "nom": "Equipar", "box": box_tab_equipar},
		{"id": "senales", "nom": "Señales", "box": box_tab_senales},
		{"id": "estilo", "nom": "Superficie", "box": box_tab_estilo},
		{"id": "via", "nom": "Tipo Vía", "box": box_tab_via}
	]
	var btns_tabs_tramo: Array[Button] = []
	for t_it in tabs_def:
		var btn_t := Button.new()
		btn_t.text = t_it["nom"]
		btn_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_t.custom_minimum_size = Vector2(0, 44)
		btn_t.add_theme_font_size_override("font_size", 16)
		if _fuente_ui: btn_t.add_theme_font_override("font", _fuente_ui)
		var tid: String = t_it["id"]
		var act_t := (tid == _tab_equip_tramo)
		_estilar_boton(btn_t, Color(0.20, 0.16, 0.08, 0.94) if act_t else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if act_t else COLOR_BORDE, 10.0)
		btn_t.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if act_t else COLOR_TEXTO_PRI)
		btn_t.pressed.connect(func():
			_tab_equip_tramo = tid
			for idx_t in range(tabs_def.size()):
				var es_a: bool = (tabs_def[idx_t]["id"] == _tab_equip_tramo)
				(tabs_def[idx_t]["box"] as Control).visible = es_a
				_estilar_boton(btns_tabs_tramo[idx_t], Color(0.20, 0.16, 0.08, 0.94) if es_a else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if es_a else COLOR_BORDE, 10.0)
				btns_tabs_tramo[idx_t].add_theme_color_override("font_color", COLOR_AMARILLO_SEL if es_a else COLOR_TEXTO_PRI)
			_ajustar_tamano_panel_propiedades()
		)
		hbox_tabs_tramo.add_child(btn_t)
		btns_tabs_tramo.append(btn_t)
		(t_it["box"] as Control).visible = act_t

	_box_prop_contenido.add_child(box_tab_equipar)
	_box_prop_contenido.add_child(box_tab_senales)
	_box_prop_contenido.add_child(box_tab_estilo)
	_box_prop_contenido.add_child(box_tab_via)

	# ── PESTAÑA 1: EQUIPAR ───────────────────────────────────────────────
	var lbl_pre := Label.new()
	lbl_pre.text = "Estilos Rápidos (1 toque)"
	lbl_pre.add_theme_font_size_override("font_size", 17)
	lbl_pre.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui: lbl_pre.add_theme_font_override("font", _fuente_ui)
	box_tab_equipar.add_child(lbl_pre)

	var hbox_pre := HBoxContainer.new()
	hbox_pre.add_theme_constant_override("separation", 8)
	box_tab_equipar.add_child(hbox_pre)
	for p in [{"id": "urbana", "nom": "Urbana"}, {"id": "carretera", "nom": "Carretera"}, {"id": "montana", "nom": "Montaña"}]:
		var btn_p := Button.new()
		btn_p.text = p["nom"]
		btn_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_p.custom_minimum_size = Vector2(0, 44)
		btn_p.add_theme_font_size_override("font_size", 16)
		_estilar_boton(btn_p, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
		if _fuente_ui: btn_p.add_theme_font_override("font", _fuente_ui)
		var pid: String = p["id"]
		btn_p.pressed.connect(func(): preset_equipamiento_solicitado.emit(pid))
		hbox_pre.add_child(btn_p)

	var lbl_elem := Label.new()
	lbl_elem.text = "Elemento Individual"
	lbl_elem.add_theme_font_size_override("font_size", 17)
	lbl_elem.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
	if _fuente_ui: lbl_elem.add_theme_font_override("font", _fuente_ui)
	box_tab_equipar.add_child(lbl_elem)

	var grid_eq := GridContainer.new()
	grid_eq.columns = 3
	grid_eq.add_theme_constant_override("h_separation", 8)
	grid_eq.add_theme_constant_override("v_separation", 8)
	box_tab_equipar.add_child(grid_eq)

	var box_estilo_acera := VBoxContainer.new()
	box_estilo_acera.add_theme_constant_override("separation", 6)
	box_estilo_acera.visible = (_equip_tipo_ui_actual == 0)

	var tipos_eq := [
		{"t": 0, "nom": "Aceras"}, {"t": 1, "nom": "Bermas"}, {"t": 2, "nom": "Barreras"},
		{"t": 3, "nom": "Luces"}, {"t": 4, "nom": "Árboles"}, {"t": 5, "nom": "Reductor"},
		{"t": 6, "nom": "Puente"}, {"t": 7, "nom": "Túnel"}, {"t": 8, "nom": "Cebra"},
		{"t": 10, "nom": "Semáforo"}, {"t": 11, "nom": "Ojos Gato"}
	]
	var btns_eq: Array[Button] = []
	for item in tipos_eq:
		var btn_e := Button.new()
		btn_e.text = item["nom"]
		btn_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_e.custom_minimum_size = Vector2(0, 44)
		btn_e.add_theme_font_size_override("font_size", 16)
		if _fuente_ui: btn_e.add_theme_font_override("font", _fuente_ui)
		var t_val: int = item["t"]
		var activo := (t_val == _equip_tipo_ui_actual)
		_estilar_boton(btn_e, Color(0.20, 0.16, 0.08, 0.94) if activo else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if activo else COLOR_BORDE, 10.0)
		btn_e.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if activo else COLOR_TEXTO_PRI)
		btn_e.pressed.connect(func():
			_equip_tipo_ui_actual = t_val
			equipamiento_tipo_cambiado.emit(t_val)
			box_estilo_acera.visible = (_equip_tipo_ui_actual == 0)
			for i in range(btns_eq.size()):
				var b_i: Button = btns_eq[i]
				var es_act: bool = (int(tipos_eq[i]["t"]) == _equip_tipo_ui_actual)
				_estilar_boton(b_i, Color(0.20, 0.16, 0.08, 0.94) if es_act else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if es_act else COLOR_BORDE, 10.0)
				b_i.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if es_act else COLOR_TEXTO_PRI)
			_ajustar_tamano_panel_propiedades()
		)
		grid_eq.add_child(btn_e)
		btns_eq.append(btn_e)

	box_tab_equipar.add_child(box_estilo_acera)

	# ── PESTAÑA 2: SEÑALES VERTICALES 3D ─────────────────────────────────
	var lbl_ts := Label.new()
	lbl_ts.text = "Señalización Vertical (3D Blender)"
	lbl_ts.add_theme_font_size_override("font_size", 18)
	lbl_ts.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui: lbl_ts.add_theme_font_override("font", _fuente_ui)
	box_tab_senales.add_child(lbl_ts)

	var grid_ts := GridContainer.new()
	grid_ts.columns = 2
	grid_ts.add_theme_constant_override("h_separation", 8)
	grid_ts.add_theme_constant_override("v_separation", 8)
	box_tab_senales.add_child(grid_ts)
	var senales_lista := [
		{"id": 0, "nom": "PARE"}, {"id": 1, "nom": "Máx 60 km/h"},
		{"id": 5, "nom": "Máx 80 km/h"}, {"id": 2, "nom": "Curva Peligrosa"},
		{"id": 3, "nom": "Ceda el Paso"}, {"id": 4, "nom": "Zona Escolar"}
	]
	var btns_ts: Array[Button] = []
	for sn in senales_lista:
		var btn_sn := Button.new()
		btn_sn.text = sn["nom"]
		btn_sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_sn.custom_minimum_size = Vector2(0, 48)
		btn_sn.add_theme_font_size_override("font_size", 17)
		if _fuente_ui: btn_sn.add_theme_font_override("font", _fuente_ui)
		var sn_val: int = sn["id"]
		var sn_act := (sn_val == _tipo_senal_ui_actual)
		_estilar_boton(btn_sn, Color(0.20, 0.16, 0.08, 0.94) if sn_act else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if sn_act else COLOR_BORDE, 10.0)
		btn_sn.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if sn_act else COLOR_TEXTO_PRI)
		btn_sn.pressed.connect(func():
			_tipo_senal_ui_actual = sn_val
			equipamiento_tipo_cambiado.emit(9)
			equipamiento_tipo_senal_cambiado.emit(sn_val)
			for k in range(btns_ts.size()):
				var es_s: bool = (int(senales_lista[k]["id"]) == _tipo_senal_ui_actual)
				_estilar_boton(btns_ts[k], Color(0.20, 0.16, 0.08, 0.94) if es_s else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if es_s else COLOR_BORDE, 10.0)
				btns_ts[k].add_theme_color_override("font_color", COLOR_AMARILLO_SEL if es_s else COLOR_TEXTO_PRI)
		)
		grid_ts.add_child(btn_sn)
		btns_ts.append(btn_sn)

	var btn_ap_senal := Button.new()
	btn_ap_senal.text = "✓ Colocar Señal en Tramo"
	btn_ap_senal.custom_minimum_size = Vector2(0, 48)
	btn_ap_senal.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_ap_senal, Color(0.16, 0.36, 0.20, 0.95), Color(0.35, 0.85, 0.45, 0.9), 10.0)
	if _fuente_ui: btn_ap_senal.add_theme_font_override("font", _fuente_ui)
	btn_ap_senal.pressed.connect(func():
		equipamiento_tipo_cambiado.emit(9)
		equipamiento_tipo_senal_cambiado.emit(_tipo_senal_ui_actual)
		equipamiento_aplicar_solicitado.emit()
	)
	box_tab_senales.add_child(btn_ap_senal)

	# ── PESTAÑA 3: SUPERFICIE PBR ────────────────────────────────────────
	var lbl_sup := Label.new()
	lbl_sup.text = "Material de Calzada (PBR)"
	lbl_sup.add_theme_font_size_override("font_size", 18)
	lbl_sup.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui: lbl_sup.add_theme_font_override("font", _fuente_ui)
	box_tab_estilo.add_child(lbl_sup)

	var grid_sup := GridContainer.new()
	grid_sup.columns = 2
	grid_sup.add_theme_constant_override("h_separation", 8)
	grid_sup.add_theme_constant_override("v_separation", 8)
	box_tab_estilo.add_child(grid_sup)
	var sups := [
		{"id": 0, "nom": "Asfalto Estándar"}, {"id": 1, "nom": "Asfalto Nuevo"},
		{"id": 2, "nom": "Asfalto Desgastado"}, {"id": 3, "nom": "Adoquín"},
		{"id": 4, "nom": "Recebo / Grava"}, {"id": 5, "nom": "Ciclovía"}
	]
	for s_it in sups:
		var btn_s := Button.new()
		btn_s.text = s_it["nom"]
		btn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_s.custom_minimum_size = Vector2(0, 46)
		btn_s.add_theme_font_size_override("font_size", 16)
		_estilar_boton(btn_s, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
		if _fuente_ui: btn_s.add_theme_font_override("font", _fuente_ui)
		var s_val: int = s_it["id"]
		btn_s.pressed.connect(func():
			_sup_via_ui_actual = s_val
			tramo_estilo_cambiado.emit(_sup_via_ui_actual, 0)
		)
		grid_sup.add_child(btn_s)

	# ── PESTAÑA 4: CONVERTIR TIPO DE VÍA ─────────────────────────────────
	var lbl_tipo_tramo := Label.new()
	lbl_tipo_tramo.text = "Cambiar Tipo de Vía del Tramo"
	lbl_tipo_tramo.add_theme_font_size_override("font_size", 18)
	lbl_tipo_tramo.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
	if _fuente_ui: lbl_tipo_tramo.add_theme_font_override("font", _fuente_ui)
	box_tab_via.add_child(lbl_tipo_tramo)

	var grid_tv := GridContainer.new()
	grid_tv.columns = 2
	grid_tv.add_theme_constant_override("h_separation", 8)
	grid_tv.add_theme_constant_override("v_separation", 8)
	box_tab_via.add_child(grid_tv)
	var tipos_via_conv := [
		{"t": 4, "nom": "Calle 1C"}, {"t": 0, "nom": "Calle 2C"},
		{"t": 5, "nom": "Nacional 2C"}, {"t": 1, "nom": "Avenida 4C"},
		{"t": 2, "nom": "Autopista 6C"}, {"t": 6, "nom": "Doble 8C"},
		{"t": 7, "nom": "Adoquín"}, {"t": 8, "nom": "Recebo"},
		{"t": 3, "nom": "Trocha"}, {"t": 9, "nom": "Ciclovía"}
	]
	for tv_it in tipos_via_conv:
		var btn_tv := Button.new()
		btn_tv.text = tv_it["nom"]
		btn_tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_tv.custom_minimum_size = Vector2(0, 44)
		btn_tv.add_theme_font_size_override("font_size", 16)
		_estilar_boton(btn_tv, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
		if _fuente_ui: btn_tv.add_theme_font_override("font", _fuente_ui)
		var tv_val: int = tv_it["t"]
		btn_tv.pressed.connect(func(): tramo_cambiar_tipo_via_solicitado.emit(tv_val))
		grid_tv.add_child(btn_tv)

	var lbl_estilo_acera := Label.new()
	lbl_estilo_acera.text = "Material de Acera"
	lbl_estilo_acera.add_theme_font_size_override("font_size", 15)
	lbl_estilo_acera.add_theme_color_override("font_color", COLOR_TEXTO_SEC)
	if _fuente_ui: lbl_estilo_acera.add_theme_font_override("font", _fuente_ui)
	box_estilo_acera.add_child(lbl_estilo_acera)

	var hbox_acera := HBoxContainer.new()
	hbox_acera.add_theme_constant_override("separation", 6)
	box_estilo_acera.add_child(hbox_acera)
	var btns_acera: Array[Button] = []
	var estilos_acera := [
		{"id": 0, "nom": "Concreto"}, {"id": 1, "nom": "Adoquín"},
		{"id": 2, "nom": "Verde"}, {"id": 3, "nom": "Granito"}
	]
	for ea in estilos_acera:
		var btn_a := Button.new()
		btn_a.text = ea["nom"]
		btn_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_a.custom_minimum_size = Vector2(0, 38)
		btn_a.add_theme_font_size_override("font_size", 14)
		if _fuente_ui: btn_a.add_theme_font_override("font", _fuente_ui)
		var ea_val: int = ea["id"]
		var act_a := (ea_val == _tipo_acera_ui_actual)
		_estilar_boton(btn_a, Color(0.20, 0.16, 0.08, 0.94) if act_a else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if act_a else COLOR_BORDE, 8.0)
		btn_a.add_theme_color_override("font_color", COLOR_AMARILLO_SEL if act_a else COLOR_TEXTO_PRI)
		btn_a.pressed.connect(func():
			_tipo_acera_ui_actual = ea_val
			equipamiento_tipo_acera_cambiado.emit(ea_val)
			for j in range(btns_acera.size()):
				var es_aa: bool = (int(estilos_acera[j]["id"]) == _tipo_acera_ui_actual)
				_estilar_boton(btns_acera[j], Color(0.20, 0.16, 0.08, 0.94) if es_aa else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if es_aa else COLOR_BORDE, 8.0)
				btns_acera[j].add_theme_color_override("font_color", COLOR_AMARILLO_SEL if es_aa else COLOR_TEXTO_PRI)
		)
		hbox_acera.add_child(btn_a)
		btns_acera.append(btn_a)

	# 4. Lado (Ambos / Izquierda / Derecha)
	var hbox_lado := HBoxContainer.new()
	hbox_lado.add_theme_constant_override("separation", 6)
	_box_prop_contenido.add_child(hbox_lado)
	var btns_lado: Array[Button] = []
	var lados_eq := [{"l": 0, "nom": "Ambos Lados"}, {"l": 1, "nom": "Izquierda"}, {"l": 2, "nom": "Derecha"}]
	for l_it in lados_eq:
		var btn_l := Button.new()
		btn_l.text = l_it["nom"]
		btn_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_l.custom_minimum_size = Vector2(0, 40)
		btn_l.add_theme_font_size_override("font_size", 15)
		if _fuente_ui: btn_l.add_theme_font_override("font", _fuente_ui)
		var l_val: int = l_it["l"]
		var act_l := (l_val == _equip_lado_ui_actual)
		_estilar_boton(btn_l, Color(0.20, 0.16, 0.08, 0.94) if act_l else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if act_l else COLOR_BORDE, 10.0)
		btn_l.pressed.connect(func():
			_equip_lado_ui_actual = l_val
			equipamiento_lado_cambiado.emit(l_val)
			for i in range(btns_lado.size()):
				var es_act: bool = (int(lados_eq[i]["l"]) == _equip_lado_ui_actual)
				_estilar_boton(btns_lado[i], Color(0.20, 0.16, 0.08, 0.94) if es_act else COLOR_PANEL_SEC, COLOR_BORDE_ACTIVO if es_act else COLOR_BORDE, 10.0)
		)
		hbox_lado.add_child(btn_l)
		btns_lado.append(btn_l)

	_crear_fila_slider("Ancho de Acera/Berma", "ico_pincel_radio", 1.0, 5.0, _ancho_equip_ui_actual, "m", 0.2, func(v):
		_ancho_equip_ui_actual = v
		equipamiento_ancho_cambiado.emit(v)
	)

	_crear_botones_accion_inferiores(
		func(): equipamiento_limpiar_solicitado.emit(),
		func(): equipamiento_aplicar_solicitado.emit(),
		"Limpiar Tramo",
		"Aplicar a Tramo"
	)

	var btn_otro_tramo := Button.new()
	btn_otro_tramo.text = "↺ Elegir Otro Tramo (A → B)"
	btn_otro_tramo.custom_minimum_size = Vector2(0, 42)
	btn_otro_tramo.add_theme_font_size_override("font_size", 16)
	_estilar_boton(btn_otro_tramo, COLOR_PANEL_SEC, COLOR_BORDE, 10.0)
	if _fuente_ui:
		btn_otro_tramo.add_theme_font_override("font", _fuente_ui)
	btn_otro_tramo.pressed.connect(func(): equipamiento_cancelar_solicitado.emit())
	_box_prop_contenido.add_child(btn_otro_tramo)

	_ajustar_tamano_panel_propiedades()

func _actualizar_badge_equipamiento(datos: Dictionary) -> void:
	var paso: int = int(datos.get("paso", 0))
	_paso_equipamiento_actual = paso
	if not is_instance_valid(_lbl_prop_badge):
		return
	if paso == 1:
		_lbl_prop_badge.text = "● Elige Punto B"
	elif paso == 2:
		_lbl_prop_badge.text = "● %.0fm (%d pts)" % [float(datos.get("distancia", 0.0)), int(datos.get("num_puntos", 0))]
	else:
		_lbl_prop_badge.text = "● Elige Punto A"

func actualizar_datos_panel_equipamiento(datos: Dictionary) -> void:
	_actualizar_badge_equipamiento(datos)
	if datos.has("ancho"):
		_actualizar_slider_val("Ancho de Acera/Berma", float(datos["ancho"]))

func ocultar_panel_equipamiento_vias() -> void:
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func mostrar_panel_edicion_objeto(datos: Dictionary) -> void:
	_asegurar_panel_propiedades_visible_y_expandido()
	mostrar_boton_centrar_seleccion(true)

	_ico_prop_header.texture = _cargar_icono_svg("cat_ciudad")
	_lbl_prop_titulo.text = "Inspector: " + str(datos.get("nombre", "Objeto"))
	_lbl_prop_badge.text = "● Objeto"
	for child in _box_prop_contenido.get_children():
		_box_prop_contenido.remove_child(child)
		child.queue_free()
	_limpiar_sliders_contenido()

	var rot := float(datos.get("rotacion_y", 0.0))
	_crear_fila_slider("Rotación Objeto", "act_rotar", 0.0, 360.0, rot, "°", 5.0, func(v):
		objeto_rotacion_fijada.emit(v)
	)

	var incl := float(datos.get("rotacion_z", 0.0))
	_crear_fila_slider("Inclinacion Lateral", "act_rotar", -90.0, 90.0, incl, "°", 5.0, func(v):
		objeto_inclinacion_fijada.emit(v)
	)

	var hbox_acts := HBoxContainer.new()
	hbox_acts.add_theme_constant_override("separation", 10)
	_box_prop_contenido.add_child(hbox_acts)

	var btn_mov := Button.new()
	btn_mov.text = "Mover Objeto"
	btn_mov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mov.custom_minimum_size = Vector2(0, 56)
	btn_mov.add_theme_font_size_override("font_size", 20)
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
		"✓ Listo"
	)
	call_deferred("_ajustar_tamano_panel_propiedades")

func actualizar_datos_panel_objeto(datos: Dictionary) -> void:
	if datos.has("rotacion_y"):
		_actualizar_slider_val("Rotación Objeto", float(datos["rotacion_y"]))
	if datos.has("rotacion_z"):
		_actualizar_slider_val("Inclinacion Lateral", float(datos["rotacion_z"]))

func ocultar_panel_edicion_objeto() -> void:
	mostrar_boton_centrar_seleccion(false)
	_actualizar_panel_contextual(_categoria_activa, _subherramienta_activa)

func mostrar_panel_variaciones_garaje(id_actual: String) -> void:
	for i in range(VARIACIONES_GARAJE.size()):
		if VARIACIONES_GARAJE[i]["id"] == id_actual:
			_idx_var_garaje = i
			break
	if not is_instance_valid(_panel_variaciones_garaje):
		_panel_variaciones_garaje = PanelContainer.new()
		_panel_variaciones_garaje.name = "PanelVariacionesGaraje"
		_panel_variaciones_garaje.anchor_left = 0.0
		_panel_variaciones_garaje.anchor_right = 0.0
		_panel_variaciones_garaje.anchor_top = 0.0
		_panel_variaciones_garaje.anchor_bottom = 0.0
		_panel_variaciones_garaje.offset_left = 24.0
		_panel_variaciones_garaje.offset_top = 148.0
		_panel_variaciones_garaje.custom_minimum_size = Vector2(390.0, 118.0)
		_panel_variaciones_garaje.mouse_filter = Control.MOUSE_FILTER_STOP
		_estilar_panel_glass(_panel_variaciones_garaje, COLOR_PANEL, COLOR_AMARILLO_SEL, 14.0, 14.0)
		add_child(_panel_variaciones_garaje)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		_panel_variaciones_garaje.add_child(vbox)

		var hdr := HBoxContainer.new()
		vbox.add_child(hdr)
		var lbl_t := Label.new()
		lbl_t.text = "🚛 VARIACIONES DE TALLER"
		lbl_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_t.add_theme_font_size_override("font_size", 16)
		lbl_t.add_theme_color_override("font_color", COLOR_AMARILLO_SEL)
		if _fuente_ui:
			lbl_t.add_theme_font_override("font", _fuente_ui)
		hdr.add_child(lbl_t)

		var btn_x := Button.new()
		btn_x.text = "✕"
		btn_x.custom_minimum_size = Vector2(36, 36)
		_estilar_boton(btn_x, COLOR_PANEL_SEC, COLOR_BORDE, 8.0)
		btn_x.pressed.connect(ocultar_panel_variaciones_garaje)
		hdr.add_child(btn_x)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)

		var btn_prev := Button.new()
		btn_prev.text = "◀"
		btn_prev.custom_minimum_size = Vector2(54, 48)
		btn_prev.add_theme_font_size_override("font_size", 20)
		_estilar_boton(btn_prev, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
		btn_prev.pressed.connect(func():
			_idx_var_garaje = (_idx_var_garaje - 1 + VARIACIONES_GARAJE.size()) % VARIACIONES_GARAJE.size()
			_actualizar_texto_var_garaje()
			variacion_garaje_cambiada.emit(VARIACIONES_GARAJE[_idx_var_garaje]["id"])
		)
		row.add_child(btn_prev)

		_lbl_var_garaje = Label.new()
		_lbl_var_garaje.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lbl_var_garaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl_var_garaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lbl_var_garaje.add_theme_font_size_override("font_size", 18)
		_lbl_var_garaje.add_theme_color_override("font_color", COLOR_TEXTO_PRI)
		if _fuente_ui:
			_lbl_var_garaje.add_theme_font_override("font", _fuente_ui)
		row.add_child(_lbl_var_garaje)

		var btn_next := Button.new()
		btn_next.text = "▶"
		btn_next.custom_minimum_size = Vector2(54, 48)
		btn_next.add_theme_font_size_override("font_size", 20)
		_estilar_boton(btn_next, COLOR_PANEL_SEC, COLOR_AMARILLO_SEL, 10.0)
		btn_next.pressed.connect(func():
			_idx_var_garaje = (_idx_var_garaje + 1) % VARIACIONES_GARAJE.size()
			_actualizar_texto_var_garaje()
			variacion_garaje_cambiada.emit(VARIACIONES_GARAJE[_idx_var_garaje]["id"])
		)
		row.add_child(btn_next)

	_actualizar_texto_var_garaje()
	_panel_variaciones_garaje.visible = true

func _actualizar_texto_var_garaje() -> void:
	if is_instance_valid(_lbl_var_garaje):
		var v: Dictionary = VARIACIONES_GARAJE[_idx_var_garaje]
		_lbl_var_garaje.text = "%d/%d · %s" % [_idx_var_garaje + 1, VARIACIONES_GARAJE.size(), v["nom"]]

func ocultar_panel_variaciones_garaje() -> void:
	if is_instance_valid(_panel_variaciones_garaje):
		_panel_variaciones_garaje.visible = false

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
	if not get_viewport():
		return
	var vp_size: Vector2i = get_viewport().size
	if _panel_propiedades:
		_panel_propiedades.offset_left = -420.0 if vp_size.x < 1200 else -480.0
		_panel_propiedades.offset_right = -20.0
		if _esta_colapsado_propiedades:
			_panel_propiedades.anchor_bottom = 0.0
			_panel_propiedades.offset_bottom = _panel_propiedades.offset_top + 64.0
		else:
			_ajustar_tamano_panel_propiedades()
	if _panel_sliders:
		_panel_sliders.offset_left = 20.0
		_panel_sliders.offset_right = 380.0 if vp_size.x < 1200 else 430.0
		_actualizar_panel_sliders()
	if _panel_herramientas and not _esta_colapsado_herramientas:
		_ajustar_tamano_panel_herramientas()

func _obtener_metadatos_herramienta(categoria: String, subherramienta: String) -> Dictionary:
	var dict_nombres = {
		"elevar": {"titulo": "Elevar Terreno", "icono": "terreno_elevar"},
		"bajar": {"titulo": "Bajar Terreno", "icono": "terreno_bajar"},
		"aplanar": {"titulo": "Aplanar Terreno", "icono": "terreno_aplanar"},
		"suavizar": {"titulo": "Suavizar Terreno", "icono": "terreno_suavizar"},
		"pintar": {"titulo": "Pintar Terreno", "icono": "terreno_pintar"},
		"follaje": {"titulo": "Pintar Follaje 3D", "icono": "terreno_cesped"},
		"cesped": {"titulo": "Pintar Césped", "icono": "terreno_cesped"},
		"tierra": {"titulo": "Pintar Tierra", "icono": "terreno_tierra"},
		"roca": {"titulo": "Pintar Roca", "icono": "terreno_roca"},
		"agua": {"titulo": "Lago / Embalse", "icono": "terreno_agua"},
		"lago": {"titulo": "Lago / Embalse", "icono": "terreno_agua"},
		"rio": {"titulo": "Río / Quebrada", "icono": "terreno_rio"},
		"calle_2": {"titulo": "Calle 2 Carriles", "icono": "via_calle_2"},
		"avenida_4": {"titulo": "Avenida 4 Carriles", "icono": "via_avenida_4"},
		"autopista_6": {"titulo": "Autopista 6 Carriles", "icono": "via_autopista_6"},
		"trocha": {"titulo": "Trocha Rural", "icono": "via_trocha"},
		"rotonda": {"titulo": "Rotonda Clásica", "icono": "via_rotonda"},
		"cruce_t": {"titulo": "Cruce en T", "icono": "via_cruce_t"},
		"cruce_4": {"titulo": "Cruce en Cruz", "icono": "via_cruce_4"},
		"dividir": {"titulo": "Dividir Vía", "icono": "via_dividir"},
		"conectar": {"titulo": "Conectar Vías", "icono": "via_conectar"},
		"nivelar": {"titulo": "Nivelar Terreno", "icono": "act_nivelar"},
		"res": {"titulo": "Zona Residencial", "icono": "cat_ciudad"},
		"com": {"titulo": "Zona Comercial", "icono": "cat_ciudad"},
		"inst": {"titulo": "Zona Institucional", "icono": "cat_ciudad"},
		"arbol_sabanero": {"titulo": "Árbol Sabanero", "icono": "cat_vegetacion"},
		"parqueo_crear": {"titulo": "Crear Parqueo", "icono": "cat_parqueo"},
		"parqueo_editar": {"titulo": "Editar Esquinas", "icono": "cat_parqueo"},
		"parqueo_nivelar": {"titulo": "Nivelar Parqueo", "icono": "act_nivelar"},
		"parqueo_borrar": {"titulo": "Borrar Parqueo", "icono": "act_demoler"},
		"concreto_crear": {"titulo": "Crear Concreto", "icono": "cat_ciudad"},
		"concreto_editar": {"titulo": "Editar Puntos", "icono": "cat_ciudad"},
		"concreto_nivelar": {"titulo": "Nivelar Concreto", "icono": "act_nivelar"},
		"concreto_borrar": {"titulo": "Borrar Concreto", "icono": "act_demoler"},
		"vehiculo": {"titulo": "Spawn Vehículo", "icono": "cat_spawn"},
		"jugador": {"titulo": "Spawn Jugador", "icono": "cat_spawn"}
	}
	if dict_nombres.has(subherramienta):
		return dict_nombres[subherramienta]
	return {"titulo": subherramienta.capitalize() + " (" + categoria.capitalize() + ")", "icono": "cat_" + categoria}
