extends Control

# ==============================================================================
# MISIONES_MENU.GD - Centro de Despacho de Trabajos y Misiones "Nuestra Tierra"
# Estilo de Mundo Abierto Civil (GTA sin armas): KM, Tiempo, Búsqueda y Licencias
# Glassmorphism Automotriz
# ==============================================================================

signal mision_seleccionada(id_mision: String)
signal mision_aceptada(id_mision: String)

# Top Bar y Economía
@onready var btn_home: Button = $MainMargin/MainVBox/TopBar/BtnHome
@onready var barra_divisas: BarraDivisas = $MainMargin/MainVBox/TopBar/EconomyPill

# Filtros
@onready var btn_filtro_todos: Button = $MainMargin/MainVBox/FilterBar/BtnFiltroTodos
@onready var btn_filtro_km: Button = $MainMargin/MainVBox/FilterBar/BtnFiltroKm
@onready var btn_filtro_min: Button = $MainMargin/MainVBox/FilterBar/BtnFiltroMin
@onready var btn_filtro_busqueda: Button = $MainMargin/MainVBox/FilterBar/BtnFiltroBusqueda
@onready var btn_filtro_licencias: Button = $MainMargin/MainVBox/FilterBar/BtnFiltroLicencias

# Columna Izquierda: Listado
@onready var list_container: VBoxContainer = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxMisiones/ScrollMisiones/ListContainer
@onready var label_count: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxMisiones/HeaderListRow/LabelCount

# Columna Derecha: Dossier
@onready var label_estado_activo: Label = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/HeaderDossier/LabelEstadoActivo
@onready var titulo_contrato: Label = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/TituloContrato
@onready var desc_contrato: Label = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/DescContrato
@onready var label_val_vehiculo: Label = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/CardDetalles/GridInfo/LabelValVehiculo
@onready var label_val_licencia: Label = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/CardDetalles/GridInfo/LabelValLicencia
@onready var label_val_recompensa: Label = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/CardDetalles/GridInfo/LabelValRecompensa
@onready var label_progreso_val: Label = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/VBoxProgresoDetalle/HBoxProgresoInfo/LabelProgresoVal
@onready var progress_bar_detalle: ProgressBar = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/VBoxProgresoDetalle/ProgressBarDetalle
@onready var btn_aceptar_iniciar: Button = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/VBoxAcciones/BtnAceptarIniciar
@onready var btn_cancelar_mision: Button = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxDossier/VBoxAcciones/BtnCancelarMision

const RUTA_MAIN_MENU := "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const RUTA_ESCENA_JUEGO := "res://interfaz/sistema/escena_carga.tscn"
const CONFIG_PATH := "user://misiones_guardadas.cfg"

var sfx_player: AudioStreamPlayer = null
var filtro_actual: String = "todos" # "todos", "km", "tiempo", "busqueda", "licencias"
var id_mision_seleccionada: String = "km_bogota_girardot"
var id_mision_activa: String = ""

# Base de datos canónica de misiones estilo mundo abierto civil / GTA sin armas
var catalogo_misiones: Array[Dictionary] = [
	# 1. KILOMETRAJE / RUTAS
	{
		"id": "km_bogota_girardot",
		"categoria": "km",
		"titulo": "Flete Cafetero: Bogotá - Girardot",
		"desc": "Conduce 35 km por la autopista y el descenso de montaña transportando bultos de café tipo exportación. Cada km registrado en el odómetro suma a tu liquidación.",
		"tipo_objetivo": "kilometros",
		"meta": 35.0,
		"unidad": "KM",
		"vehiculo": "Camión NPR / Kodiak",
		"licencia": "C1 / C2",
		"pago_dinero": 280000,
		"pago_xp": 450,
		"pago_esmeraldas": 0,
		"gps_coord": Vector3(120.0, 0.0, 450.0)
	},
	{
		"id": "km_la_linea",
		"categoria": "km",
		"titulo": "Desafío Cordillera: Alto de La Línea",
		"desc": "Maneja 50 km continuos de alta montaña y curvas cerradas. Requiere uso intensivo de freno de motor y control térmico del tractocamión para evitar volcamiento.",
		"tipo_objetivo": "kilometros",
		"meta": 50.0,
		"unidad": "KM",
		"vehiculo": "Tractomula T800 con Tráiler",
		"licencia": "C3 (Pesados)",
		"pago_dinero": 650000,
		"pago_xp": 900,
		"pago_esmeraldas": 5,
		"gps_coord": Vector3(-350.0, 25.0, 890.0)
	},
	{
		"id": "km_circuito_rapido",
		"categoria": "km",
		"titulo": "Circuito Expreso Sabana",
		"desc": "Recorre 15 km a velocidad constante sin choques para entregar paquetes ligeros entre los peajes de la sabana.",
		"tipo_objetivo": "kilometros",
		"meta": 15.0,
		"unidad": "KM",
		"vehiculo": "Sprinter / Duster / Mespark",
		"licencia": "B1 (Livianos)",
		"pago_dinero": 140000,
		"pago_xp": 250,
		"pago_esmeraldas": 0,
		"gps_coord": Vector3(200.0, 0.0, -150.0)
	},

	# 2. TRABAJOS TEMPORALES (MINUTOS)
	{
		"id": "min_repartidor",
		"categoria": "tiempo",
		"titulo": "Turno de Reparto Urbano",
		"desc": "Trabaja durante 5 minutos continuos en la furgoneta de encomiendas entregando cajas en los puntos comerciales de la ciudad.",
		"tipo_objetivo": "tiempo_min",
		"meta": 5.0,
		"unidad": "MIN",
		"vehiculo": "Sprinter Repartidor / Hiace",
		"licencia": "B1 / C1",
		"pago_dinero": 180000,
		"pago_xp": 300,
		"pago_esmeraldas": 0,
		"gps_coord": Vector3(45.0, 0.0, 30.0)
	},
	{
		"id": "min_montacargas",
		"categoria": "tiempo",
		"titulo": "Turno Logístico con Montacargas",
		"desc": "Opera 3 minutos en el patio de maniobras de la bodega cargando estibas y pallets industriales a las plataformas de los camiones.",
		"tipo_objetivo": "tiempo_min",
		"meta": 3.0,
		"unidad": "MIN",
		"vehiculo": "Forklift Industrial (Bodega)",
		"licencia": "Libre (Operario Patio)",
		"pago_dinero": 110000,
		"pago_xp": 220,
		"pago_esmeraldas": 0,
		"gps_coord": Vector3(-0.648, 0.0, 0.0)
	},
	{
		"id": "min_colectivo",
		"categoria": "tiempo",
		"titulo": "Turno de Colectivo Intermunicipal",
		"desc": "Conduce 8 minutos en servicio de transporte público realizando paradas de pasajeros en los paraderos autorizados de la ruta.",
		"tipo_objetivo": "tiempo_min",
		"meta": 8.0,
		"unidad": "MIN",
		"vehiculo": "Marcopolo G8 / Colectivo",
		"licencia": "C1 / C2",
		"pago_dinero": 380000,
		"pago_xp": 600,
		"pago_esmeraldas": 3,
		"gps_coord": Vector3(310.0, 0.0, -80.0)
	},

	# 3. BÚSQUEDA Y RECOLECCIÓN
	{
		"id": "busc_repuestos",
		"categoria": "busqueda",
		"titulo": "Repuestos Perdidos en la Trocha",
		"desc": "Un tractocamión derramó cajas de herramientas en la berma durante la noche. Explora la trocha a pie o en 4x4 y localiza las 3 cajas extraviadas.",
		"tipo_objetivo": "recoleccion",
		"meta": 3.0,
		"unidad": "CAJAS",
		"vehiculo": "A pie / Duster 4x4",
		"licencia": "Libre",
		"pago_dinero": 200000,
		"pago_xp": 400,
		"pago_esmeraldas": 0,
		"gps_coord": Vector3(85.0, 5.0, 220.0)
	},
	{
		"id": "busc_trailer",
		"categoria": "busqueda",
		"titulo": "Rescate de Tráiler Cisterna",
		"desc": "Localiza un remolque cisterna abandonado en los patios de la zona industrial, acopla la quinta rueda y transpórtalo al taller central.",
		"tipo_objetivo": "recoleccion",
		"meta": 1.0,
		"unidad": "TRÁILER",
		"vehiculo": "Tractomula T800 / T680",
		"licencia": "C3 (Tractomula)",
		"pago_dinero": 500000,
		"pago_xp": 750,
		"pago_esmeraldas": 4,
		"gps_coord": Vector3(-180.0, 0.0, 600.0)
	},
	{
		"id": "busc_esmeraldas",
		"categoria": "busqueda",
		"titulo": "Prospección de Esmeraldas en Miradores",
		"desc": "Explora a pie en primera persona los cerros y miradores naturales del valle para hallar 5 alijos minerales de esmeraldas sin tallar.",
		"tipo_objetivo": "recoleccion",
		"meta": 5.0,
		"unidad": "ALIJOS",
		"vehiculo": "A pie (Primera Persona)",
		"licencia": "Libre",
		"pago_dinero": 250000,
		"pago_xp": 500,
		"pago_esmeraldas": 15,
		"gps_coord": Vector3(450.0, 60.0, -320.0)
	},

	# 4. LICENCIAS Y HOMOLOGACIÓN RUNT
	{
		"id": "lic_c1_examen",
		"categoria": "licencias",
		"titulo": "Examen Licencia C1 (Camionetas y Reparto)",
		"desc": "Prueba oficial en pista de maniobras de la academia: prueba de arranque en pendiente, frenado en seco y parqueo en reversa con furgón.",
		"tipo_objetivo": "examen",
		"meta": 1.0,
		"unidad": "PRUEBA",
		"vehiculo": "Sprinter / Camioneta",
		"licencia": "B1 aprobada previa",
		"pago_dinero": 150000,
		"pago_xp": 350,
		"pago_esmeraldas": 0,
		"gps_coord": Vector3(12.0, 0.0, 80.0)
	},
	{
		"id": "lic_c2_examen",
		"categoria": "licencias",
		"titulo": "Examen Licencia C2 (Camiones Rígidos)",
		"desc": "Prueba de maniobra en camión de dos ejes (NPR/Kodiak): calibración de frenos de aire y estacionamiento en bahía de cargue estrecha.",
		"tipo_objetivo": "examen",
		"meta": 1.0,
		"unidad": "PRUEBA",
		"vehiculo": "Camión Rígido NPR",
		"licencia": "C1 aprobada",
		"pago_dinero": 350000,
		"pago_xp": 550,
		"pago_esmeraldas": 2,
		"gps_coord": Vector3(12.0, 0.0, 80.0)
	},
	{
		"id": "lic_c3_examen",
		"categoria": "licencias",
		"titulo": "Examen Maestro Licencia C3 (Tractomula)",
		"desc": "La prueba cumbre del transporte nacional: enganche de tractomula, maniobra de tijera controlada y parqueo de tráiler articulado.",
		"tipo_objetivo": "examen",
		"meta": 1.0,
		"unidad": "PRUEBA",
		"vehiculo": "Tractomula T800 + Tráiler",
		"licencia": "C2 aprobada",
		"pago_dinero": 800000,
		"pago_xp": 1000,
		"pago_esmeraldas": 5,
		"gps_coord": Vector3(12.0, 0.0, 80.0)
	}
]

# Diccionario de progreso guardado: id -> { "progreso": float, "completada": bool }
var progreso_misiones: Dictionary = {}

func _ready() -> void:
	_inicializar_audio()
	_cargar_progreso_archivo()
	_conectar_senales()
	_actualizar_economia_top()
	_filtrar_misiones("todos")
	_seleccionar_mision(id_mision_seleccionada)
	_animacion_entrada()

func _inicializar_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)
	if ResourceLoader.exists("res://recursos/efectos/money.mp3"):
		sfx_player.stream = load("res://recursos/efectos/money.mp3")

func _play_sfx(path: String = "") -> void:
	if not sfx_player:
		return
	if path != "" and ResourceLoader.exists(path):
		sfx_player.stream = load(path)
	if sfx_player.stream:
		sfx_player.play()

func _conectar_senales() -> void:
	if btn_home:
		btn_home.pressed.connect(_on_btn_home_pressed)

	if btn_filtro_todos:
		btn_filtro_todos.pressed.connect(func(): _filtrar_misiones("todos"))
	if btn_filtro_km:
		btn_filtro_km.pressed.connect(func(): _filtrar_misiones("km"))
	if btn_filtro_min:
		btn_filtro_min.pressed.connect(func(): _filtrar_misiones("tiempo"))
	if btn_filtro_busqueda:
		btn_filtro_busqueda.pressed.connect(func(): _filtrar_misiones("busqueda"))
	if btn_filtro_licencias:
		btn_filtro_licencias.pressed.connect(func(): _filtrar_misiones("licencias"))

	if btn_aceptar_iniciar:
		btn_aceptar_iniciar.pressed.connect(_on_btn_aceptar_iniciar_pressed)
	if btn_cancelar_mision:
		btn_cancelar_mision.pressed.connect(_on_btn_cancelar_mision_pressed)

func _actualizar_economia_top() -> void:
	var dinero = 0
	var esmeraldas = 0
	if DatosUsuario:
		if DatosUsuario.has_method("obtener_dinero"):
			dinero = DatosUsuario.obtener_dinero()
		elif "dinero" in DatosUsuario:
			dinero = DatosUsuario.dinero

		if DatosUsuario.has_method("obtener_esmeraldas"):
			esmeraldas = DatosUsuario.obtener_esmeraldas()
		elif "esmeraldas" in DatosUsuario:
			esmeraldas = DatosUsuario.esmeraldas

	if barra_divisas:
		barra_divisas.set_valores(float(dinero), int(esmeraldas))

func _filtrar_misiones(categoria: String) -> void:
	filtro_actual = categoria
	_actualizar_estilo_pills()

	# Limpiar contenedor de lista
	for c in list_container.get_children():
		c.queue_free()

	var filtradas: Array[Dictionary] = []
	for m in catalogo_misiones:
		if categoria == "todos" or m["categoria"] == categoria:
			filtradas.append(m)

	if label_count:
		label_count.text = str(filtradas.size()) + " DISPONIBLES"

	for mision in filtradas:
		var card = _crear_tarjeta_mision(mision)
		list_container.add_child(card)

func _actualizar_estilo_pills() -> void:
	var pills = [
		{"btn": btn_filtro_todos, "cat": "todos"},
		{"btn": btn_filtro_km, "cat": "km"},
		{"btn": btn_filtro_min, "cat": "tiempo"},
		{"btn": btn_filtro_busqueda, "cat": "busqueda"},
		{"btn": btn_filtro_licencias, "cat": "licencias"},
	]
	for p in pills:
		if p["btn"]:
			var activo = (filtro_actual == p["cat"])
			p["btn"].add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 1.0) if activo else Color(0.85, 0.88, 0.92, 1.0))
			var sb = StyleBoxFlat.new()
			sb.set_corner_radius_all(10)
			if activo:
				sb.bg_color = Color(0.88, 0.68, 0.28, 0.95)
			else:
				sb.bg_color = Color(0.08, 0.1, 0.13, 0.8)
				sb.set_border_width_all(1)
				sb.border_color = Color(0.78, 0.81, 0.85, 0.18)
			p["btn"].add_theme_stylebox_override("normal", sb)

func _crear_tarjeta_mision(mision: Dictionary) -> PanelContainer:
	var id = mision["id"]
	var datos_prog = progreso_misiones.get(id, {"progreso": 0.0, "completada": false})
	var completada = datos_prog.get("completada", false)
	var es_activa = (id_mision_activa == id)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 110)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	if es_activa:
		sb.bg_color = Color(0.12, 0.15, 0.18, 0.95)
		sb.border_color = Color(0.88, 0.68, 0.28, 0.9)
	elif completada:
		sb.bg_color = Color(0.07, 0.09, 0.11, 0.75)
		sb.border_color = Color(0.2, 0.85, 0.45, 0.4)
	else:
		sb.bg_color = Color(0.08, 0.09, 0.12, 0.88)
		sb.border_color = Color(0.78, 0.81, 0.85, 0.18)
	card.add_theme_stylebox_override("panel", sb)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Fila superior: Título y Badge
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var lbl_tit = Label.new()
	lbl_tit.text = mision["titulo"]
	lbl_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_tit.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
		lbl_tit.add_theme_font_override("font", load("res://recursos/fonts/Moderniz.otf"))
	lbl_tit.add_theme_font_size_override("font_size", 14)
	top_row.add_child(lbl_tit)

	var badge = Label.new()
	var sb_b = StyleBoxFlat.new()
	sb_b.set_corner_radius_all(6)
	if completada:
		badge.text = "COMPLETADO"
		badge.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45, 1.0))
		sb_b.bg_color = Color(0.05, 0.15, 0.08, 0.8)
	elif es_activa:
		badge.text = "EN CURSO"
		badge.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
		sb_b.bg_color = Color(0.2, 0.15, 0.05, 0.8)
	else:
		badge.text = "DISPONIBLE"
		badge.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72, 1.0))
		sb_b.bg_color = Color(0.12, 0.14, 0.16, 0.8)
	badge.add_theme_stylebox_override("normal", sb_b)
	badge.add_theme_font_size_override("font_size", 11)
	top_row.add_child(badge)

	# Fila media: Breve descripción
	var lbl_desc = Label.new()
	lbl_desc.text = mision["desc"]
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.max_lines_visible = 2
	lbl_desc.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78, 0.85))
	lbl_desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_desc)

	# Fila inferior: Pago y Vehículo
	var bot_row = HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 16)
	vbox.add_child(bot_row)

	var lbl_pago = Label.new()
	lbl_pago.text = "PAGO: $ " + _formatear_numero(mision["pago_dinero"]) + (" + " + str(mision["pago_esmeraldas"]) + " ESM" if mision["pago_esmeraldas"] > 0 else "")
	lbl_pago.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45, 1.0))
	lbl_pago.add_theme_font_size_override("font_size", 12)
	bot_row.add_child(lbl_pago)

	var lbl_req = Label.new()
	lbl_req.text = "EXIGE: " + mision["licencia"]
	lbl_req.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.9))
	lbl_req.add_theme_font_size_override("font_size", 12)
	bot_row.add_child(lbl_req)

	# Interacción al hacer clic en la tarjeta
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_play_sfx()
			_seleccionar_mision(id)
	)

	return card

func _seleccionar_mision(id: String) -> void:
	id_mision_seleccionada = id
	var mision: Dictionary = {}
	for m in catalogo_misiones:
		if m["id"] == id:
			mision = m
			break

	if mision.is_empty():
		return

	mision_seleccionada.emit(id)

	# Actualizar columna derecha (Dossier)
	if titulo_contrato:
		titulo_contrato.text = mision["titulo"].to_upper()
	if desc_contrato:
		desc_contrato.text = mision["desc"]
	if label_val_vehiculo:
		label_val_vehiculo.text = mision["vehiculo"]
	if label_val_licencia:
		label_val_licencia.text = mision["licencia"]
	if label_val_recompensa:
		var txt_recompensa = "$ " + _formatear_numero(mision["pago_dinero"]) + "  + " + str(mision["pago_xp"]) + " XP"
		if mision["pago_esmeraldas"] > 0:
			txt_recompensa += "  + " + str(mision["pago_esmeraldas"]) + " ESM"
		label_val_recompensa.text = txt_recompensa

	# Estado y Progreso
	var datos_prog = progreso_misiones.get(id, {"progreso": 0.0, "completada": false})
	var completada = datos_prog.get("completada", false)
	var progreso_actual = float(datos_prog.get("progreso", 0.0))
	var meta = float(mision["meta"])
	var porcentaje = clamp(progreso_actual / max(0.01, meta), 0.0, 1.0) * 100.0

	if label_progreso_val:
		label_progreso_val.text = "%.1f / %.1f %s (%d%%)" % [progreso_actual, meta, mision["unidad"], int(porcentaje)]
	if progress_bar_detalle:
		progress_bar_detalle.max_value = meta
		progress_bar_detalle.value = progreso_actual

	var es_activa = (id_mision_activa == id)

	if label_estado_activo:
		if completada:
			label_estado_activo.text = "COMPLETADO"
			label_estado_activo.add_theme_color_override("font_color", Color(0.2, 0.85, 0.45, 1.0))
		elif es_activa:
			label_estado_activo.text = "EN CURSO"
			label_estado_activo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
		else:
			label_estado_activo.text = "DISPONIBLE"
			label_estado_activo.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.8))

	# Configurar botones de acción
	if btn_aceptar_iniciar:
		if completada:
			btn_aceptar_iniciar.text = "RECLAMAR PAGO FINAL"
			btn_aceptar_iniciar.disabled = false
		elif es_activa:
			btn_aceptar_iniciar.text = "INICIAR RECORRIDO EN EL MUNDO"
			btn_aceptar_iniciar.disabled = false
		else:
			btn_aceptar_iniciar.text = "ACEPTAR CONTRATO"
			btn_aceptar_iniciar.disabled = false

	if btn_cancelar_mision:
		btn_cancelar_mision.visible = es_activa and not completada

func _on_btn_aceptar_iniciar_pressed() -> void:
	_play_sfx("res://recursos/efectos/money.mp3")
	var datos_prog = progreso_misiones.get(id_mision_seleccionada, {"progreso": 0.0, "completada": false})

	# Si ya está completada, otorgar recompensa y finalizar
	if datos_prog.get("completada", false):
		_cobrar_recompensa_mision(id_mision_seleccionada)
		return

	# Si no estaba activa, aceptarla
	if id_mision_activa != id_mision_seleccionada:
		id_mision_activa = id_mision_seleccionada
		_guardar_progreso_archivo()
		_filtrar_misiones(filtro_actual)
		_seleccionar_mision(id_mision_seleccionada)
		mision_aceptada.emit(id_mision_activa)
		return

	# Si ya estaba activa, conducir al mundo principal
	_ir_al_mundo_con_mision()

func _on_btn_cancelar_mision_pressed() -> void:
	_play_sfx()
	id_mision_activa = ""
	_guardar_progreso_archivo()
	_filtrar_misiones(filtro_actual)
	_seleccionar_mision(id_mision_seleccionada)

func _cobrar_recompensa_mision(id: String) -> void:
	var mision: Dictionary = {}
	for m in catalogo_misiones:
		if m["id"] == id:
			mision = m
			break
	if mision.is_empty():
		return

	if DatosUsuario:
		if DatosUsuario.has_method("agregar_dinero"):
			DatosUsuario.agregar_dinero(mision["pago_dinero"])
		elif "dinero" in DatosUsuario:
			DatosUsuario.dinero += mision["pago_dinero"]

		if DatosUsuario.has_method("agregar_experiencia"):
			DatosUsuario.agregar_experiencia(mision["pago_xp"])
		elif "experiencia" in DatosUsuario:
			DatosUsuario.experiencia += mision["pago_xp"]

		if mision["pago_esmeraldas"] > 0:
			if DatosUsuario.has_method("agregar_esmeraldas"):
				DatosUsuario.agregar_esmeraldas(mision["pago_esmeraldas"])
			elif "esmeraldas" in DatosUsuario:
				DatosUsuario.esmeraldas += mision["pago_esmeraldas"]

		if DatosUsuario.has_method("guardar_progreso"):
			DatosUsuario.guardar_progreso()

	_actualizar_economia_top()
	id_mision_activa = ""
	progreso_misiones.erase(id)
	_guardar_progreso_archivo()
	_filtrar_misiones(filtro_actual)
	_seleccionar_mision(id_mision_seleccionada)

func _ir_al_mundo_con_mision() -> void:
	# Configurar GPS o destino en CelularUI/DatosUsuario si existe
	var mision_activa_dict: Dictionary = {}
	for m in catalogo_misiones:
		if m["id"] == id_mision_activa:
			mision_activa_dict = m
			break

	if DatosUsuario:
		DatosUsuario.set_meta("mision_activa_id", id_mision_activa)
		if not mision_activa_dict.is_empty():
			DatosUsuario.set_meta("mision_activa_gps", mision_activa_dict["gps_coord"])
		DatosUsuario.cambiar_escena("res://mundo/principal/Principal.tscn")
	else:
		get_tree().change_scene_to_file("res://mundo/principal/Principal.tscn")

func _cargar_progreso_archivo() -> void:
	progreso_misiones.clear()
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err == OK:
		id_mision_activa = cfg.get_value("general", "mision_activa", "")
		for sec in cfg.get_sections():
			if sec != "general":
				progreso_misiones[sec] = {
					"progreso": cfg.get_value(sec, "progreso", 0.0),
					"completada": cfg.get_value(sec, "completada", false)
				}

func _guardar_progreso_archivo() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("general", "mision_activa", id_mision_activa)
	for k in progreso_misiones.keys():
		cfg.set_value(k, "progreso", progreso_misiones[k].get("progreso", 0.0))
		cfg.set_value(k, "completada", progreso_misiones[k].get("completada", false))
	cfg.save(CONFIG_PATH)

func _on_btn_home_pressed() -> void:
	_play_sfx()
	if DatosUsuario:
		DatosUsuario.cambiar_escena(RUTA_MAIN_MENU)
	elif ResourceLoader.exists(RUTA_MAIN_MENU):
		get_tree().change_scene_to_file(RUTA_MAIN_MENU)

func _animacion_entrada() -> void:
	var left = $MainMargin/MainVBox/ColumnsHBox/LeftCard
	var right = $MainMargin/MainVBox/ColumnsHBox/RightCard
	var top = $MainMargin/MainVBox/TopBar
	
	if top:
		top.modulate.a = 0.0
		var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(top, "modulate:a", 1.0, 0.25)
	if left:
		left.modulate.a = 0.0
		left.position.x -= 25.0
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(left, "modulate:a", 1.0, 0.3)
		tw.parallel().tween_property(left, "position:x", left.position.x + 25.0, 0.3)
	if right:
		right.modulate.a = 0.0
		right.position.x += 25.0
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(right, "modulate:a", 1.0, 0.35)
		tw.parallel().tween_property(right, "position:x", right.position.x - 25.0, 0.35)

func _formatear_numero(valor: int) -> String:
	var texto = str(abs(valor))
	var longitud = texto.length()
	var resultado = ""
	for i in range(longitud):
		if i > 0 and (longitud - i) % 3 == 0:
			resultado += "."
		resultado += texto[i]
	return ("-" if valor < 0 else "") + resultado
