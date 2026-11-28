extends Control

# ═══════════════════════════════════════════════════════════════════════
# MainMenuModerno.gd — Menú Principal (Glassmorphism Automotriz)
# ═══════════════════════════════════════════════════════════════════════
# Sigue el sistema de diseño de diseño.md / manual_diseno_ui.md:
#   · Cristal ahumado de alta densidad + borde frost de 1px
#   · Acento ámbar instrumental para acciones y selecciones
#   · Carmesí técnico para la acción destructiva (salir)
#   · Tipografía Moderniz, botones de 58-100 px de alto
#   · Entrada animada con Tweens (escala + fundido)
# La esquina superior izquierda la ocupa el logotipo de la marca; el panel
# de perfil vive en el lateral derecho, centrado verticalmente, como
# tarjeta de conductor (avatar, nivel, experiencia y acceso al perfil).
# ═══════════════════════════════════════════════════════════════════════

const FONT := preload("res://recursos/fonts/Moderniz.otf")
const ESCENA_CARGA := "res://interfaz/sistema/escena_carga.tscn"
const ESCENA_JUEGO_PRINCIPAL := "res://mundo/principal/Principal.tscn"
const ESCENA_LOBBY_MULTI := "res://interfaz/pantallas/multijugador/LobbyMultijugadorModerno.tscn"
const ESCENA_LOBBY_MULTI_FALLBACK := "res://interfaz/pantallas/multijugador/LobbyMultijugador.tscn"
const ESCENA_TIENDA := "res://interfaz/pantallas/tienda/Tienda.tscn"
const ESCENA_PASE_ELITE := "res://interfaz/pantallas/pase_elite/PaseElite.tscn"
const ESCENA_GARAJE := "res://interfaz/pantallas/garaje/GarajeBodega.tscn"
const ESCENA_MISIONES := "res://interfaz/pantallas/misiones/MisionesMenu.tscn"
const ESCENA_CONFIG := "res://interfaz/pantallas/configuraciones/configuraciones.tscn"
const ESCENA_PERFIL := "res://interfaz/pantallas/perfil/Perfil_Menu.tscn"
const ESCENA_EDITOR_MAPAS := "res://mundo/editor_mapas/HubEditorMapas.tscn"
const SCRIPT_COMUNIDAD_MODAL := preload("res://interfaz/pantallas/menu_principal/ComunidadModal.gd")
const MENU_MUSIC_PATH := "res://recursos/Musica/Aire-de-son.mp3"

# ── Tokens de diseño (diseño.md) ───────────────────────────────────────
const C_AMBER := Color(0.88, 0.68, 0.28, 0.92)
const C_AMBER_BRIGHT := Color(1.0, 0.80, 0.40, 1.0)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_BORDER_BRIGHT := Color(0.85, 0.88, 0.92, 0.42)
const C_TEXT_MUTED := Color(0.50, 0.54, 0.58, 0.85)

# Tintes aplicados por modulate a iconos y etiquetas (el shader de iconos
# multiplica por COLOR, por lo que el icono blanco adopta el tinte).
const TINTE_NEUTRO := Color(1.0, 1.0, 1.0, 1.0)
const TINTE_AMBER := Color(1.0, 0.82, 0.45, 1.0)
const TINTE_PELIGRO := Color(1.0, 0.56, 0.54, 1.0)
const TINTE_PELIGRO_HOVER := Color(1.0, 0.70, 0.68, 1.0)
const TINTE_TINTA := Color(0.12, 0.09, 0.04, 1.0)
const TINTE_TINTA_HOVER := Color(0.05, 0.04, 0.02, 1.0)

var _audio_player_menu: AudioStreamPlayer = null
var _toast_actual: PanelContainer = null
static var _bienvenida_mostrada: bool = false
var _ad_view = null
var _comunidad_modal: Control = null
var _timer_presencia: Timer = null

@onready var fondo_3d: TextureRect = $Fondo3D
@onready var camera_menu: Camera3D = null

@onready var top_bar: HBoxContainer = $TopBar
@onready var nav_panel: PanelContainer = $LeftNav
@onready var perfil_panel: PanelContainer = $PerfilPanel
@onready var bottom_dock: CenterContainer = $BottomDock
@onready var hint_chip: PanelContainer = $HintChip

@onready var barra_divisas: BarraDivisas = $TopBar/TopRightEconomy

@onready var btn_tienda: Button = $LeftNav/VBox/BtnTienda
@onready var btn_garaje: Button = $LeftNav/VBox/BtnGaraje
@onready var btn_pase_elite: Button = $LeftNav/VBox/BtnPaseElite
@onready var punto_pase: Panel = $LeftNav/VBox/BtnPaseElite/PuntoPase
@onready var btn_misiones: Button = $LeftNav/VBox/BtnMisiones
@onready var btn_comunidad: Button = $LeftNav/VBox/BtnComunidad
@onready var btn_soporte: Button = $LeftNav/VBox/BtnSoporte

@onready var avatar_perfil: TextureRect = $PerfilPanel/VBox/HBoxAvatar/AvatarMarco/Lienzo/Avatar
@onready var avatar_inicial: Label = $PerfilPanel/VBox/HBoxAvatar/AvatarMarco/Lienzo/LabelInicial
@onready var label_nombre: Label = $PerfilPanel/VBox/LabelNombre
@onready var label_nivel: Label = $PerfilPanel/VBox/HBoxNivel/PanelNivel/LabelNivel
@onready var label_id: Label = $PerfilPanel/VBox/HBoxHeader/LabelId
@onready var label_xp: Label = $PerfilPanel/VBox/VBoxProgreso/HBoxCaption/LabelXp
@onready var barra_xp: ProgressBar = $PerfilPanel/VBox/VBoxProgreso/BarraXp
@onready var btn_ver_perfil: Button = $PerfilPanel/VBox/BtnVerPerfil

@onready var btn_multijugador: Button = $BottomDock/DockBar/Contenido/BtnMultijugador
@onready var btn_editor_mapas: Button = $BottomDock/DockBar/Contenido/BtnEditorMapas
@onready var btn_config: Button = $BottomDock/DockBar/Contenido/IconCluster/BtnConfig
@onready var btn_salir: Button = $BottomDock/DockBar/Contenido/IconCluster/BtnSalir


func _ready() -> void:
	camera_menu = get_node_or_null("Node3D/SubViewport2/Bodega/Camera3D")
	if fondo_3d:
		fondo_3d.mouse_filter = Control.MOUSE_FILTER_PASS
		if not fondo_3d.gui_input.is_connected(_on_fondo_gui_input):
			fondo_3d.gui_input.connect(_on_fondo_gui_input)

	_estilizar_controles()
	_aplicar_avatar_circular()
	_conectar_botones()
	_actualizar_datos_usuario()
	_animar_entrada()
	_mostrar_bienvenida_usuario()

	if DatosUsuario:
		if not DatosUsuario.nombre_usuario_cambiado.is_connected(_on_nombre_actualizado):
			DatosUsuario.nombre_usuario_cambiado.connect(_on_nombre_actualizado)
		if (
			DatosUsuario.has_signal("avatar_cambiada")
			and not DatosUsuario.avatar_cambiada.is_connected(_on_avatar_actualizada)
		):
			DatosUsuario.avatar_cambiada.connect(_on_avatar_actualizada)

	if not visibility_changed.is_connected(_actualizar_datos_usuario):
		visibility_changed.connect(_actualizar_datos_usuario)

	_start_menu_music()
	_iniciar_anuncio_menu()
	_cargar_vehiculo_seleccionado_en_fondo()
	var sb := get_node_or_null("/root/SupabaseManager")
	if sb and sb.has_signal("perfil_cargado") and not sb.perfil_cargado.is_connected(_on_perfil_nube_cargado):
		sb.perfil_cargado.connect(_on_perfil_nube_cargado)
	_iniciar_presencia_ligera()

func _on_perfil_nube_cargado(_perfil: Dictionary) -> void:
	_cargar_vehiculo_seleccionado_en_fondo()

const CATALOGO_VEHICULOS_MENU := {
	"T800_A": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T800_Alargada": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"Mespark": "res://modelos3d/vehiculos/automoviles/Mespark/mespark.tscn",
	"Duster": "res://modelos3d/vehiculos/automoviles/Duster/duster.tscn",
	"ToyotaHiace": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Hiage": "res://modelos3d/vehiculos/automoviles/toyota-hiace/hiage.tscn",
	"Pardo": "res://modelos3d/vehiculos/automoviles/Pardo/pardo.tscn",
	"T800": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"800_Modular": "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn",
	"T680": "res://modelos3d/vehiculos/tractomulas/cabezotes/T680/T680.tscn",
	"Kodiak": "res://modelos3d/vehiculos/tractomulas/cabezotes/KODIAK/kodiak.tscn",
	"NPR": "res://modelos3d/vehiculos/NPR/npr.tscn",
	"Sprinter": "res://modelos3d/vehiculos/automoviles/sprinter/sprinter_repartidor.tscn",
	"Marcopolo": "res://modelos3d/vehiculos/Buses/MarcopoloG8-1200/MarcopoloG8-1200.tscn"
}

func _cargar_vehiculo_seleccionado_en_fondo() -> void:
	var bodega := get_node_or_null("Node3D/SubViewport2/Bodega")
	if not bodega:
		return

	var id_vehiculo := "T800_A"
	var du := get_node_or_null("/root/DatosUsuario")
	if du:
		if "guardado_player_vehiculo_nombre" in du and str(du.guardado_player_vehiculo_nombre) != "":
			id_vehiculo = str(du.guardado_player_vehiculo_nombre)
		elif "vehiculo_actual" in du and str(du.vehiculo_actual) != "":
			id_vehiculo = str(du.vehiculo_actual)

	if not CATALOGO_VEHICULOS_MENU.has(id_vehiculo):
		for k in CATALOGO_VEHICULOS_MENU.keys():
			if k.to_lower() in id_vehiculo.to_lower() or id_vehiculo.to_lower() in k.to_lower():
				id_vehiculo = k
				break
		if not CATALOGO_VEHICULOS_MENU.has(id_vehiculo):
			id_vehiculo = "T800_A"

	var vehiculo_actual_nodo: Node3D = bodega.get_node_or_null("VehiculoMenuSeleccionado")
	if not vehiculo_actual_nodo:
		vehiculo_actual_nodo = bodega.get_node_or_null("T800_Alargada")
		if not vehiculo_actual_nodo:
			vehiculo_actual_nodo = bodega.find_child("*T800*", true, false) as Node3D

	var spawn_xform := Transform3D.IDENTITY
	if vehiculo_actual_nodo:
		spawn_xform = vehiculo_actual_nodo.transform
		var ya_coincide := vehiculo_actual_nodo.has_meta("modelo_id") and str(vehiculo_actual_nodo.get_meta("modelo_id")) == id_vehiculo
		var es_t800_default := (id_vehiculo == "T800_A" or id_vehiculo == "T800_Alargada" or id_vehiculo == "T800") and ("T800" in vehiculo_actual_nodo.name)
		if not ya_coincide and not es_t800_default:
			vehiculo_actual_nodo.queue_free()
			vehiculo_actual_nodo = null

	if not vehiculo_actual_nodo:
		var ruta: String = CATALOGO_VEHICULOS_MENU.get(id_vehiculo, CATALOGO_VEHICULOS_MENU["T800_A"])
		if ResourceLoader.exists(ruta):
			var ps := load(ruta) as PackedScene
			if ps:
				vehiculo_actual_nodo = ps.instantiate() as Node3D
				if vehiculo_actual_nodo:
					vehiculo_actual_nodo.name = "VehiculoMenuSeleccionado"
					bodega.add_child(vehiculo_actual_nodo)
					vehiculo_actual_nodo.transform = spawn_xform

	if not vehiculo_actual_nodo:
		return

	if vehiculo_actual_nodo is RigidBody3D:
		vehiculo_actual_nodo.freeze = true
		vehiculo_actual_nodo.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	elif "freeze" in vehiculo_actual_nodo:
		vehiculo_actual_nodo.set("freeze", true)

	vehiculo_actual_nodo.set_meta("modelo_id", id_vehiculo)
	var cust: Node = vehiculo_actual_nodo.get_node_or_null("CustomizerComponent")
	if not cust:
		cust = vehiculo_actual_nodo.find_child("CustomizerComponent", true, false)
	if not cust:
		var cust_script := load("res://codigo/sistemas/taller/customizer_component.gd")
		if cust_script:
			cust = Node.new()
			cust.set_script(cust_script)
			cust.name = "CustomizerComponent"
			vehiculo_actual_nodo.add_child(cust)
	if cust and cust.has_method("cargar_personalizacion"):
		cust.cargar_personalizacion()


func _exit_tree() -> void:
	_destruir_anuncio_menu()


func _iniciar_anuncio_menu() -> void:
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return
	if not ClassDB.class_exists("MobileAds") or not ClassDB.class_exists("AdView"):
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status) -> void:
		_cargar_anuncio_menu()
	MobileAds.initialize(listener)


func _cargar_anuncio_menu() -> void:
	var ad_unit_id := _obtener_banner_menu_ad_unit_id()
	if ad_unit_id.is_empty():
		push_error("[AdMob] Falta configurar el banner fijo del menu principal.")
		return
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(int(size.x))
	if ad_size.width <= 0:
		ad_size = AdSize.BANNER
	_ad_view = AdView.new(ad_unit_id, ad_size, AdPosition.TOP)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		if is_instance_valid(_ad_view):
			_ad_view.show()
	listener.on_ad_failed_to_load = func(error) -> void:
		push_warning("[AdMob] No se pudo cargar el banner del menu: %s" % str(error))
	_ad_view.ad_listener = listener
	_ad_view.load_ad(AdRequest.new())


func _obtener_banner_menu_ad_unit_id() -> String:
	var setting_name := "nuestra_tierra/admob/banner_menu_unit_id_android"
	if OS.get_name() == "iOS":
		setting_name = "nuestra_tierra/admob/banner_menu_unit_id_ios"
	if ProjectSettings.has_setting(setting_name):
		var configured_id := str(ProjectSettings.get_setting(setting_name)).strip_edges()
		if not configured_id.is_empty():
			return configured_id
	if OS.is_debug_build() and OS.get_name() == "Android":
		return "ca-app-pub-3940256099942544/9214589741"
	if OS.is_debug_build() and OS.get_name() == "iOS":
		return "ca-app-pub-3940256099942544/2934735716"
	return ""


func _destruir_anuncio_menu() -> void:
	if is_instance_valid(_ad_view):
		_ad_view.destroy()
	_ad_view = null


# ═══════════════════════════════════════════════════════════════════════
# ESTILOS
# ═══════════════════════════════════════════════════════════════════════

func _estilizar_controles() -> void:
	for btn in _botones_nav():
		_aplicar_estilo_nav(btn)
		_conectar_hover(btn, _icono_de(btn), _label_de(btn), TINTE_NEUTRO, TINTE_AMBER)
		_preparar_boton(btn, 1.01)

	for btn in [btn_multijugador, btn_editor_mapas]:
		if btn:
			_aplicar_estilo_secundario(btn, btn == btn_multijugador)
			_conectar_hover(
				btn, _icono_de(btn), _label_de(btn), TINTE_NEUTRO, TINTE_AMBER
			)
			_preparar_boton(btn, 1.02)

	if btn_config:
		_aplicar_estilo_icono(btn_config, false)
		_conectar_hover(btn_config, _icono_de(btn_config), _label_de(btn_config), TINTE_NEUTRO, TINTE_AMBER)
		_preparar_boton(btn_config, 1.02)

	if btn_salir:
		_aplicar_estilo_icono(btn_salir, true)
		_conectar_hover(btn_salir, _icono_de(btn_salir), _label_de(btn_salir), TINTE_PELIGRO, TINTE_PELIGRO_HOVER)
		_preparar_boton(btn_salir, 1.02)

	_aplicar_estilo_perfil(btn_ver_perfil)
	_conectar_hover(btn_ver_perfil, null, null, TINTE_NEUTRO, TINTE_AMBER)
	_preparar_boton(btn_ver_perfil, 1.02)


func _botones_nav() -> Array:
	return [btn_tienda, btn_garaje, btn_pase_elite, btn_misiones, btn_comunidad, btn_soporte]


func _todos_los_botones() -> Array:
	var lista := _botones_nav()
	for btn in [btn_multijugador, btn_editor_mapas, btn_config, btn_salir, btn_ver_perfil]:
		if btn != null:
			lista.append(btn)
	return lista


func _crear_estilo(
	fondo: Color, borde: Color, radio: int, grosor: int = 1, sombra: int = 6
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(grosor)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = sombra
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _aplicar_estilo_nav(btn: Button) -> void:
	var normal := _crear_estilo(Color(0.06, 0.07, 0.08, 0.55), Color(0.78, 0.81, 0.85, 0.10), 10, 1, 0)
	var hover := _crear_estilo(Color(0.13, 0.15, 0.18, 0.92), C_BORDER_BRIGHT, 10, 1, 6)
	var pressed := _crear_estilo(Color(0.18, 0.20, 0.24, 0.96), C_AMBER, 10, 1, 8)
	pressed.border_width_bottom = 2

	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = C_AMBER

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 20)


func _aplicar_estilo_primario(btn: Button) -> void:
	var normal := _crear_estilo(
		Color(0.88, 0.68, 0.28, 1.0), Color(1.0, 0.86, 0.55, 0.9), 12, 1, 0
	)
	normal.shadow_color = Color(0.88, 0.68, 0.28, 0.22)
	normal.shadow_size = 14
	normal.shadow_offset = Vector2(0, 4)

	var hover := _crear_estilo(Color(0.96, 0.77, 0.37, 1.0), Color(1.0, 0.92, 0.66, 1.0), 12, 1, 0)
	hover.shadow_color = Color(0.88, 0.68, 0.28, 0.36)
	hover.shadow_size = 18
	hover.shadow_offset = Vector2(0, 4)

	var pressed := _crear_estilo(Color(0.78, 0.58, 0.22, 1.0), Color(1.0, 0.86, 0.55, 1.0), 12, 1, 0)
	pressed.shadow_color = Color(0.88, 0.68, 0.28, 0.18)
	pressed.shadow_size = 8

	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = Color(1.0, 1.0, 1.0, 0.85)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 30)


func _aplicar_estilo_secundario(btn: Button, destacado: bool = false) -> void:
	var borde_normal := Color(0.88, 0.68, 0.28, 0.42) if destacado else Color(0.78, 0.81, 0.85, 0.16)
	var fondo_normal := Color(0.09, 0.10, 0.12, 0.86) if destacado else Color(0.08, 0.09, 0.11, 0.78)
	var normal := _crear_estilo(fondo_normal, borde_normal, 12, 1, 4)
	var hover := _crear_estilo(Color(0.13, 0.15, 0.18, 0.94), C_AMBER if destacado else C_BORDER_BRIGHT, 12, 1, 6)
	var pressed := _crear_estilo(Color(0.88, 0.68, 0.28, 0.18), C_AMBER, 12, 1, 8)

	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = C_AMBER

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)


func _aplicar_estilo_perfil(btn: Button) -> void:
	var normal := _crear_estilo(
		Color(0.88, 0.68, 0.28, 0.1), Color(0.88, 0.68, 0.28, 0.42), 10, 1, 0
	)
	var hover := _crear_estilo(Color(0.88, 0.68, 0.28, 0.2), C_AMBER, 10, 1, 8)
	var pressed := _crear_estilo(Color(0.88, 0.68, 0.28, 0.3), C_AMBER_BRIGHT, 10, 1, 10)
	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = C_AMBER_BRIGHT

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", C_AMBER)
	btn.add_theme_color_override("font_hover_color", C_AMBER_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", C_AMBER_BRIGHT)
	btn.add_theme_color_override("font_focus_color", C_AMBER)


func _aplicar_estilo_icono(btn: Button, peligro: bool) -> void:
	if btn == null:
		return
	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var pressed: StyleBoxFlat
	var transparente := Color(1.0, 1.0, 1.0, 0.0)

	if peligro:
		normal = _crear_estilo(Color(0.78, 0.28, 0.26, 0.10), Color(0.78, 0.28, 0.26, 0.35), 10, 1, 4)
		hover = _crear_estilo(Color(0.78, 0.28, 0.26, 0.24), Color(0.78, 0.28, 0.26, 0.80), 10, 1, 6)
		pressed = _crear_estilo(Color(0.78, 0.28, 0.26, 0.36), C_CRIMSON, 10, 1, 8)
	else:
		normal = _crear_estilo(Color(0.08, 0.09, 0.11, 0.78), Color(0.78, 0.81, 0.85, 0.16), 10, 1, 4)
		hover = _crear_estilo(Color(0.13, 0.15, 0.18, 0.92), C_BORDER_BRIGHT, 10, 1, 6)
		pressed = _crear_estilo(Color(0.88, 0.68, 0.28, 0.18), C_AMBER, 10, 1, 8)

	var focus := hover.duplicate() as StyleBoxFlat
	if not peligro:
		focus.border_color = C_AMBER

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)


# ═══════════════════════════════════════════════════════════════════════
# INTERACCIÓN (hover, foco y pulsación táctil)
# ═══════════════════════════════════════════════════════════════════════

func _icono_de(btn: Button) -> TextureRect:
	if btn == null:
		return null
	var icono := btn.get_node_or_null("Contenido/Icono") as TextureRect
	if icono == null:
		icono = btn.get_node_or_null("Icono") as TextureRect
	return icono


func _label_de(btn: Button) -> Label:
	if btn == null:
		return null
	return btn.get_node_or_null("Contenido/Label") as Label


func _conectar_hover(
	btn: Button, icono: TextureRect, label: Label, tinte_normal: Color, tinte_hover: Color
) -> void:
	if btn == null:
		return

	if icono:
		icono.modulate = tinte_normal
	if label:
		label.modulate = tinte_normal

	btn.set_meta("_hover", false)
	btn.mouse_entered.connect(func() -> void:
		btn.set_meta("_hover", true)
		_tintar(icono, label, tinte_hover)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.set_meta("_hover", false)
		if not btn.has_focus():
			_tintar(icono, label, tinte_normal)
	)
	btn.focus_entered.connect(func() -> void: _tintar(icono, label, tinte_hover))
	btn.focus_exited.connect(func() -> void:
		if not btn.get_meta("_hover", false):
			_tintar(icono, label, tinte_normal)
	)


func _tintar(icono: TextureRect, label: Label, color: Color) -> void:
	for ctrl in [icono, label]:
		if ctrl == null:
			continue
		if ctrl.has_meta("tw_tinte"):
			var prev = ctrl.get_meta("tw_tinte")
			if prev is Tween and prev.is_valid():
				prev.kill()
		var tw: Tween = ctrl.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ctrl, "modulate", color, 0.15)
		ctrl.set_meta("tw_tinte", tw)


func _preparar_boton(btn: Button, escala_hover: float) -> void:
	if btn == null:
		return

	btn.resized.connect(_actualizar_pivote.bind(btn))
	btn.mouse_entered.connect(func() -> void: _escalar(btn, escala_hover, 0.14))
	btn.mouse_exited.connect(func() -> void: _escalar(btn, 1.0, 0.18))
	btn.button_down.connect(func() -> void: _escalar(btn, 0.95, 0.08))
	btn.button_up.connect(func() -> void:
		var destino := escala_hover if (btn.has_meta("_hover") and btn.get_meta("_hover")) else 1.0
		_escalar(btn, destino, 0.18)
	)


func _escalar(ctrl: Control, factor: float, duracion: float) -> void:
	if ctrl == null:
		return
	if ctrl.has_meta("tw_escala"):
		var prev = ctrl.get_meta("tw_escala")
		if prev is Tween and prev.is_valid():
			prev.kill()
	var tw: Tween = ctrl.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2(factor, factor), duracion)
	ctrl.set_meta("tw_escala", tw)


func _actualizar_pivote(ctrl: Control) -> void:
	if ctrl:
		ctrl.pivot_offset = ctrl.size * 0.5


# ═══════════════════════════════════════════════════════════════════════
# ANIMACIÓN DE ENTRADA (diseño.md §8)
# ═══════════════════════════════════════════════════════════════════════

func _animar_entrada() -> void:
	modulate.a = 0.0
	await get_tree().process_frame

	for btn in _todos_los_botones():
		_actualizar_pivote(btn)

	var elementos := [
		[top_bar, Vector2(0.0, -16.0)],
		[nav_panel, Vector2(-26.0, 0.0)],
		[perfil_panel, Vector2(26.0, 0.0)],
		[bottom_dock, Vector2(0.0, 24.0)],
		[hint_chip, Vector2(0.0, 12.0)],
	]

	var tw: Tween = create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.32)

	for i in elementos.size():
		var ctrl: Control = elementos[i][0]
		var desplazamiento: Vector2 = elementos[i][1]
		var destino: Vector2 = ctrl.position
		var retardo := 0.04 * float(i)
		ctrl.position = destino + desplazamiento
		ctrl.modulate.a = 0.0
		tw.tween_property(ctrl, "position", destino, 0.42).set_delay(retardo)
		tw.tween_property(ctrl, "modulate:a", 1.0, 0.34).set_delay(retardo)


# ═══════════════════════════════════════════════════════════════════════
# DATOS DE USUARIO
# ═══════════════════════════════════════════════════════════════════════

func _actualizar_datos_usuario() -> void:
	var dinero := 0.0
	var esmeraldas := 0

	if DatosUsuario:
		dinero = float(DatosUsuario.dinero)
		esmeraldas = int(DatosUsuario.esmeraldas)

	if barra_divisas:
		barra_divisas.set_valores(dinero, esmeraldas)

	_actualizar_perfil()
	_actualizar_punto_pase()


func _actualizar_perfil() -> void:
	var nombre := "CONDUCTOR"
	var nivel := 0
	var experiencia := 0
	var identificador := ""
	var textura: Texture2D = null

	if DatosUsuario:
		var nombre_guardado := str(DatosUsuario.nombre_usuario).strip_edges()
		if nombre_guardado != "":
			nombre = nombre_guardado
		nivel = int(DatosUsuario.nivel)
		experiencia = int(DatosUsuario.experiencia)
		identificador = str(DatosUsuario.id_usuario).strip_edges()
		textura = DatosUsuario.avatar_texture

	if label_nombre:
		label_nombre.text = nombre
	if label_id:
		label_id.text = identificador if identificador != "" else "INVITADO"
	if label_nivel:
		label_nivel.text = "NIVEL %s" % _formatear_miles(nivel)

	var rango := RangoConductor.obtener_rango(nivel)
	var color_rango: Color = rango["color"]
	_aplicar_escudo_rango(nivel, rango)

	var requerido := maxi((nivel + 1) * 300, 1)
	var xp_clamped := clampi(experiencia, 0, requerido)
	var pct := roundi((float(xp_clamped) / float(requerido)) * 100.0)
	if barra_xp:
		barra_xp.max_value = float(requerido)
		barra_xp.value = float(xp_clamped)
		var sb_bg := _crear_estilo(Color(0.05, 0.06, 0.08, 0.95), Color(0.78, 0.81, 0.85, 0.20), 7, 1, 0)
		barra_xp.add_theme_stylebox_override("background", sb_bg)
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = color_rango
		sb_fill.set_corner_radius_all(7)
		sb_fill.shadow_color = Color(color_rango.r, color_rango.g, color_rango.b, 0.45)
		sb_fill.shadow_size = 8
		barra_xp.add_theme_stylebox_override("fill", sb_fill)
	if label_xp:
		label_xp.text = "%s / %s XP (%d%%)" % [
			_formatear_miles(experiencia), _formatear_miles(requerido), pct
		]
		label_xp.add_theme_color_override("font_color", color_rango.lightened(0.25))

	if avatar_perfil:
		avatar_perfil.texture = textura
	if avatar_inicial:
		avatar_inicial.visible = textura == null
		if textura == null:
			var inicial := nombre.substr(0, 1).to_upper()
			avatar_inicial.text = inicial if inicial != "" else "?"


func _aplicar_escudo_rango(nivel: int, rango: Dictionary) -> void:
	var hbox_nivel := get_node_or_null("PerfilPanel/VBox/HBoxNivel")
	if not hbox_nivel:
		return
	var escudo_rect := hbox_nivel.get_node_or_null("EscudoRango") as TextureRect
	if not escudo_rect:
		escudo_rect = TextureRect.new()
		escudo_rect.name = "EscudoRango"
		escudo_rect.custom_minimum_size = Vector2(38, 38)
		escudo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		escudo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox_nivel.add_child(escudo_rect)
		hbox_nivel.move_child(escudo_rect, 0)
	escudo_rect.texture = RangoConductor.obtener_textura_escudo(nivel)
	escudo_rect.tooltip_text = str(rango["nombre"])

	var color_rango: Color = rango["color"]
	var panel_nivel := hbox_nivel.get_node_or_null("PanelNivel") as PanelContainer
	if panel_nivel:
		var sb_niv := _crear_estilo(Color(color_rango.r, color_rango.g, color_rango.b, 0.14), Color(color_rango.r, color_rango.g, color_rango.b, 0.72), 8, 1, 0)
		sb_niv.content_margin_left = 12.0
		sb_niv.content_margin_right = 12.0
		sb_niv.content_margin_top = 4.0
		sb_niv.content_margin_bottom = 4.0
		panel_nivel.add_theme_stylebox_override("panel", sb_niv)
	if label_nivel:
		label_nivel.add_theme_color_override("font_color", color_rango.lightened(0.2))

	var vbox_perfil := get_node_or_null("PerfilPanel/VBox")
	if vbox_perfil:
		var lbl_rango := vbox_perfil.get_node_or_null("LabelRangoConductor") as Label
		if not lbl_rango:
			lbl_rango = Label.new()
			lbl_rango.name = "LabelRangoConductor"
			lbl_rango.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_rango.add_theme_font_override("font", FONT)
			lbl_rango.add_theme_font_size_override("font_size", 11)
			vbox_perfil.add_child(lbl_rango)
			vbox_perfil.move_child(lbl_rango, hbox_nivel.get_index() + 1)
		lbl_rango.text = str(rango["nombre"])
		lbl_rango.add_theme_color_override("font_color", color_rango)


func _actualizar_punto_pase() -> void:
	if punto_pase == null:
		return

	var disponible := false
	if DatosUsuario:
		disponible = (
			DatosUsuario.tiene_pase_elite() and DatosUsuario.puede_reclamar_pase()
		)

	punto_pase.visible = disponible
	if not disponible:
		if punto_pase.has_meta("tw_pulso"):
			var previo = punto_pase.get_meta("tw_pulso")
			if previo is Tween and previo.is_valid():
				previo.kill()
			punto_pase.remove_meta("tw_pulso")
		punto_pase.modulate.a = 1.0
		return

	if punto_pase.has_meta("tw_pulso"):
		return
	var tw := punto_pase.create_tween().set_loops()
	tw.tween_property(punto_pase, "modulate:a", 0.45, 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(punto_pase, "modulate:a", 1.0, 0.85).set_trans(Tween.TRANS_SINE)
	punto_pase.set_meta("tw_pulso", tw)


func _formatear_miles(valor: int) -> String:
	var negativo := valor < 0
	var digitos := str(absi(valor))
	var salida := ""
	for i in range(digitos.length()):
		if i > 0 and (digitos.length() - i) % 3 == 0:
			salida += "."
		salida += digitos[i]
	return ("-" if negativo else "") + salida


func _on_nombre_actualizado(_nuevo_nombre: String) -> void:
	_actualizar_datos_usuario()


func _on_avatar_actualizada(_textura) -> void:
	_actualizar_datos_usuario()


# ═══════════════════════════════════════════════════════════════════════
# FONDO 3D
# ═══════════════════════════════════════════════════════════════════════

func _on_fondo_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (
		event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)
	):
		if camera_menu and camera_menu.has_method("rotate_from_input"):
			camera_menu.rotate_from_input(-event.relative.x)


# ═══════════════════════════════════════════════════════════════════════
# NAVEGACIÓN
# ═══════════════════════════════════════════════════════════════════════

func _conectar_botones() -> void:
	if btn_multijugador: btn_multijugador.pressed.connect(_on_multijugador_pressed)
	if btn_editor_mapas: btn_editor_mapas.pressed.connect(_on_editor_mapas_pressed)
	if btn_config: btn_config.pressed.connect(_on_config_pressed)
	if btn_salir: btn_salir.pressed.connect(_on_salir_pressed)

	if btn_tienda: btn_tienda.pressed.connect(_on_tienda_pressed)
	if btn_garaje: btn_garaje.pressed.connect(_on_garaje_nav_pressed)
	if btn_pase_elite: btn_pase_elite.pressed.connect(_on_pase_elite_pressed)
	if btn_misiones: btn_misiones.pressed.connect(_on_misiones_pressed)
	if btn_comunidad: btn_comunidad.pressed.connect(_on_comunidad_pressed)
	if btn_soporte: btn_soporte.pressed.connect(_on_soporte_pressed)
	if btn_ver_perfil: btn_ver_perfil.pressed.connect(_on_ver_perfil_pressed)


func _on_editor_mapas_pressed() -> void:
	if ResourceLoader.exists(ESCENA_EDITOR_MAPAS):
		get_tree().change_scene_to_file(ESCENA_EDITOR_MAPAS)
	else:
		_mostrar_toast("CENTRO DE MAPAS NO DISPONIBLE")


func _on_multijugador_pressed() -> void:
	var destino := ESCENA_LOBBY_MULTI
	if not ResourceLoader.exists(destino):
		destino = ESCENA_LOBBY_MULTI_FALLBACK
	if ResourceLoader.exists(destino):
		if DatosUsuario:
			DatosUsuario.cambiar_escena(destino)
		else:
			get_tree().change_scene_to_file(destino)
	else:
		_mostrar_toast("CONVOY ONLINE NO DISPONIBLE")


func _on_garage_pressed() -> void:
	if ResourceLoader.exists(ESCENA_GARAJE):
		if DatosUsuario:
			DatosUsuario.cambiar_escena(ESCENA_GARAJE)
		else:
			get_tree().change_scene_to_file(ESCENA_GARAJE)
	else:
		_on_tienda_pressed()


func _on_config_pressed() -> void:
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").change_to_settings()
	elif ResourceLoader.exists(ESCENA_CONFIG):
		get_tree().change_scene_to_file(ESCENA_CONFIG)
	else:
		_mostrar_toast("CONFIGURACION NO DISPONIBLE")


func _on_salir_pressed() -> void:
	get_tree().quit()


func _on_tienda_pressed() -> void:
	if ResourceLoader.exists(ESCENA_TIENDA):
		if DatosUsuario:
			DatosUsuario.cambiar_escena(ESCENA_TIENDA)
		else:
			get_tree().change_scene_to_file(ESCENA_TIENDA)
	elif ResourceLoader.exists(ESCENA_GARAJE):
		_on_garage_pressed()
	else:
		_mostrar_toast("TIENDA NO DISPONIBLE")


func _on_garaje_nav_pressed() -> void:
	_on_garage_pressed()


func _on_pase_elite_pressed() -> void:
	if ResourceLoader.exists(ESCENA_PASE_ELITE):
		get_tree().change_scene_to_file(ESCENA_PASE_ELITE)
	else:
		_mostrar_toast("PASE ELITE NO DISPONIBLE")


func _on_misiones_pressed() -> void:
	var ruta_ruleta := "res://interfaz/pantallas/ruleta/RuletaPremios.tscn"
	if ResourceLoader.exists(ruta_ruleta):
		if DatosUsuario:
			DatosUsuario.cambiar_escena(ruta_ruleta)
		else:
			get_tree().change_scene_to_file(ruta_ruleta)
	else:
		_mostrar_toast("RULETA NO DISPONIBLE")


func _on_comunidad_pressed() -> void:
	if not is_instance_valid(_comunidad_modal):
		_comunidad_modal = Control.new()
		_comunidad_modal.name = "ComunidadModal"
		_comunidad_modal.set_script(SCRIPT_COMUNIDAD_MODAL)
		add_child(_comunidad_modal)
	if _comunidad_modal.has_method("abrir"):
		_comunidad_modal.abrir()


func _iniciar_presencia_ligera() -> void:
	var sb := get_node_or_null("/root/SupabaseManager")
	if sb and sb.has_method("actualizar_presencia"):
		sb.actualizar_presencia()
	_timer_presencia = Timer.new()
	_timer_presencia.wait_time = 60.0
	_timer_presencia.one_shot = false
	_timer_presencia.autostart = true
	_timer_presencia.timeout.connect(func() -> void:
		var supa := get_node_or_null("/root/SupabaseManager")
		if supa and supa.has_method("actualizar_presencia"):
			supa.actualizar_presencia()
	)
	add_child(_timer_presencia)


func _on_soporte_pressed() -> void:
	_mostrar_toast("AYUDA: MODULO EN PREPARACION")


func _on_ver_perfil_pressed() -> void:
	if ResourceLoader.exists(ESCENA_PERFIL):
		if DatosUsuario and "escenas_precargadas" in DatosUsuario and DatosUsuario.escenas_precargadas.has(ESCENA_PERFIL):
			var ps: PackedScene = DatosUsuario.escenas_precargadas[ESCENA_PERFIL] as PackedScene
			if ps:
				get_tree().change_scene_to_packed(ps)
				return
		get_tree().change_scene_to_file(ESCENA_PERFIL)
	else:
		_mostrar_toast("PERFIL NO DISPONIBLE")


# ═══════════════════════════════════════════════════════════════════════
# AVISO FLOTANTE (feedback para acciones sin escena todavía)
# ═══════════════════════════════════════════════════════════════════════

func _aplicar_avatar_circular() -> void:
	if not avatar_perfil:
		return
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float alpha = 1.0 - smoothstep(0.48, 0.5, length(d));
	vec4 col = texture(TEXTURE, UV) * COLOR;
	col.a *= alpha;
	COLOR = col;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	avatar_perfil.material = mat


func _mostrar_bienvenida_usuario() -> void:
	if _bienvenida_mostrada:
		return
	_bienvenida_mostrada = true
	var nombre := "Conductor"
	if DatosUsuario:
		var n := str(DatosUsuario.nombre_usuario).strip_edges()
		if not n.is_empty():
			nombre = n
	call_deferred("_mostrar_toast", "BIENVENIDO, " + nombre)


func _mostrar_toast(texto: String) -> void:
	if _toast_actual and is_instance_valid(_toast_actual):
		_toast_actual.queue_free()
		_toast_actual = null

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := _crear_estilo(Color(0.09, 0.10, 0.12, 0.95), C_AMBER, 10, 1, 10)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = texto
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_TEXT_MUTED.lightened(0.45))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)

	add_child(panel)
	_toast_actual = panel

	# Centrado en la parte alta de la pantalla, bajo la barra superior.
	panel.size = Vector2(440.0, 52.0)
	panel.position = Vector2((size.x - panel.size.x) * 0.5, 196.0)
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)

	var tw: Tween = create_tween()
	tw.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.20)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.26)

	await get_tree().create_timer(1.9).timeout
	if not is_instance_valid(panel):
		return

	var tw_salida := create_tween()
	tw_salida.tween_property(panel, "modulate:a", 0.0, 0.25)
	await tw_salida.finished
	if is_instance_valid(panel):
		panel.queue_free()
	if _toast_actual == panel:
		_toast_actual = null


# ═══════════════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════════════

func _start_menu_music() -> void:
	if _audio_player_menu and _audio_player_menu.playing:
		return
	if not ResourceLoader.exists(MENU_MUSIC_PATH):
		return
	var stream = load(MENU_MUSIC_PATH)
	if not stream:
		return
	_audio_player_menu = AudioStreamPlayer.new()
	_audio_player_menu.stream = stream
	_audio_player_menu.volume_db = -6
	add_child(_audio_player_menu)
	_audio_player_menu.play()
