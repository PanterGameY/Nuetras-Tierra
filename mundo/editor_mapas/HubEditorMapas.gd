extends Control

## HubEditorMapas.gd — Taller de Mapas con estética Automotive Glassmorphism idéntica a MainMenuModerno

const ESCENA_EDITOR_MAPAS := "res://mundo/editor_mapas/EditorMapas.tscn"
const RepositorioComunidad := preload("res://mundo/editor_mapas/RepositorioMapasComunidad.gd")
const ESCENA_MENU_PRINCIPAL := "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const RUTA_FUENTE_UI := "res://recursos/fonts/Moderniz.otf"
const DIR_MAPAS := "user://mapas"
const PRECIO_MAPA_ESMERALDAS := 10

# Tokens idénticos a MainMenuModerno.gd / diseño.md
const C_AMBER := Color(0.88, 0.68, 0.28, 0.92)
const C_AMBER_BRIGHT := Color(1.0, 0.80, 0.40, 1.0)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.20)
const C_BORDER_BRIGHT := Color(0.85, 0.88, 0.92, 0.42)
const C_GLASS := Color(0.06, 0.07, 0.08, 0.76)
const C_CARD := Color(0.08, 0.09, 0.11, 0.82)
const C_TEXT := Color(0.95, 0.96, 0.98, 1.0)
const C_TEXT_MUTED := Color(0.62, 0.66, 0.72, 0.90)
const TINTE_TINTA := Color(0.10, 0.08, 0.03, 1.0)

const PLANTILLAS: Array[Dictionary] = [
	{
		"id": "valle_verde",
		"nombre": "Valle Verde",
		"desc": "Pradera abierta ideal para autopistas, rotondas y ciudades.",
		"hora": 10,
		"tag": "SUAVE"
	},
	{
		"id": "paso_montana",
		"nombre": "Paso Andino",
		"desc": "Relieve elevado listo para viaductos, pilares y tuneles de 12m.",
		"hora": 16,
		"tag": "SIERRA"
	},
	{
		"id": "lienzo_blanco",
		"nombre": "Lienzo en Blanco",
		"desc": "Terreno limpio desde cero para crear cualquier ruta libremente.",
		"hora": 12,
		"tag": "LIBRE"
	}
]

const MAPAS_GALERIA: Array[Dictionary] = [
	{
		"id": "gal_ruta_cafetera",
		"nombre": "Ruta del Cafe",
		"autor": "Equipo Nuestra Tierra",
		"categoria": "Sierra",
		"desc": "Tramo sinuoso de doble calzada con miradores y curvas amplias.",
		"plantilla": "paso_montana",
		"hora": 16
	},
	{
		"id": "gal_circuito_urbano",
		"nombre": "Distrito Central",
		"autor": "Equipo Nuestra Tierra",
		"categoria": "Urbano",
		"desc": "Base urbana con avenida de 4 carriles, aceras y rotonda central.",
		"plantilla": "valle_verde",
		"hora": 10
	},
	{
		"id": "gal_autopista_llano",
		"nombre": "Autopista del Llano",
		"autor": "Comunidad NT",
		"categoria": "Autopista",
		"desc": "Larga recta de alta velocidad ideal para probar tractomulas.",
		"plantilla": "lienzo_blanco",
		"hora": 14
	}
]

var _fuente: Font = null
var _fuente_cuerpo: Font = null
var _fuente_bold: Font = null
var _tab_actual: String = "galeria"
var _modo_creador: bool = false
var _lbl_hub_titulo: Label = null
var _lbl_hub_sub: Label = null
var _btn_modo_creador: Button = null
var _plantilla_seleccionada: String = "valle_verde"
var _filtro_galeria: String = "Todos"
var _busqueda_galeria: String = ""
var _grid_galeria: GridContainer = null

var _cam_fondo: Camera3D = null
var _angulo_cam: float = 0.0
var _left_nav: PanelContainer
var _top_bar: HBoxContainer
var _contenedor_vista: MarginContainer
var _botones_tabs: Dictionary = {}
var _input_nombre_mapa: LineEdit
var _lbl_toast: Label
var _lbl_esmeraldas: Label
var _tween_toast: Tween
var _repo_comunidad: Node = null
var _mapas_comunidad_cache: Array[Dictionary] = []
var _modal_subida: PanelContainer = null

func _ready() -> void:
	if ResourceLoader.exists(RUTA_FUENTE_UI):
		_fuente = load(RUTA_FUENTE_UI)
	if ResourceLoader.exists("res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf"):
		_fuente_cuerpo = load("res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf")
	if ResourceLoader.exists("res://recursos/fonts/creato_display/CreatoDisplay-Bold.otf"):
		_fuente_bold = load("res://recursos/fonts/creato_display/CreatoDisplay-Bold.otf")
	_repo_comunidad = RepositorioComunidad.new()
	add_child(_repo_comunidad)
	_repo_comunidad.mapas_cargados.connect(_on_mapas_comunidad_cargados)
	_repo_comunidad.subida_completada.connect(func(exito: bool, msg: String):
		_mostrar_toast(msg)
		if exito and _tab_actual == "galeria":
			_repo_comunidad.cargar_mapas_comunidad()
	)
	_construir_fondo_3d()
	_construir_hud_flotante()
	_actualizar_saldo_esmeraldas()
	_cambiar_tab("galeria")
	_repo_comunidad.cargar_mapas_comunidad()
	_animar_entrada()

func _process(delta: float) -> void:
	if is_instance_valid(_cam_fondo):
		_angulo_cam += delta * 0.08
		_cam_fondo.position = Vector3(sin(_angulo_cam) * 18.0, 6.2, cos(_angulo_cam) * 18.0)
		_cam_fondo.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)

func _animar_entrada() -> void:
	if _left_nav:
		_left_nav.modulate.a = 0.0
		_left_nav.position.x -= 24.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_left_nav, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_left_nav, "position:x", _left_nav.position.x + 24.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _contenedor_vista:
		_contenedor_vista.modulate.a = 0.0
		var tw2 := create_tween()
		tw2.tween_property(_contenedor_vista, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── FONDO 3D ATMOSFÉRICO (ESTILO BODEGA / PISTA DE MAINMENUMODERNO) ───

func _construir_fondo_3d() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)

	var world := Node3D.new()
	sv.add_child(world)

	# Ambiente nocturno cálido con neblina sutil
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.06, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.21, 0.26)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.028
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_color = Color(1.0, 0.85, 0.62)
	sun.light_energy = 1.4
	world.add_child(sun)

	# Piso oscuro de estudio
	var piso := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(120, 120)
	piso.mesh = pl
	var mat_piso := StandardMaterial3D.new()
	mat_piso.albedo_color = Color(0.05, 0.06, 0.07)
	mat_piso.roughness = 0.75
	piso.material_override = mat_piso
	world.add_child(piso)

	# Anillo de carretera estilizada con líneas ámbar
	var anillo := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 9.0
	tor.outer_radius = 15.0
	tor.rings = 48
	tor.ring_segments = 6
	anillo.mesh = tor
	anillo.scale = Vector3(1.0, 0.05, 1.0)
	anillo.position.y = 0.04
	var mat_asf := StandardMaterial3D.new()
	mat_asf.albedo_color = Color(0.11, 0.12, 0.14)
	mat_asf.roughness = 0.88
	anillo.material_override = mat_asf
	world.add_child(anillo)

	# Luces cálidas alrededor de la pista
	for i in range(6):
		var ang := float(i) * TAU / 6.0
		var pos := Vector3(cos(ang) * 12.0, 3.2, sin(ang) * 12.0)
		var luz := OmniLight3D.new()
		luz.position = pos
		luz.light_color = Color(0.95, 0.72, 0.30)
		luz.light_energy = 2.2
		luz.omni_range = 10.0
		world.add_child(luz)

	_cam_fondo = Camera3D.new()
	_cam_fondo.position = Vector3(0.0, 6.2, 18.0)
	_cam_fondo.fov = 46.0
	world.add_child(_cam_fondo)
	_cam_fondo.current = true

	# Viñeta oscura sobre el 3D para máxima legibilidad de los paneles glass
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.04, 0.05, 0.56)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

# ── HUD FLOTANTE (LAYOUT DE JUEGO COMO MAINMENUMODERNO) ─────────────────

func _construir_hud_flotante() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 28)
	root_margin.add_theme_constant_override("margin_right", 28)
	root_margin.add_theme_constant_override("margin_top", 22)
	root_margin.add_theme_constant_override("margin_bottom", 22)
	add_child(root_margin)

	var vbox_main := VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 20)
	root_margin.add_child(vbox_main)

	# ── TOP BAR FLOTANTE ──────────────────────────────────────────────
	_top_bar = HBoxContainer.new()
	_top_bar.add_theme_constant_override("separation", 16)
	vbox_main.add_child(_top_bar)

	var chip_brand := PanelContainer.new()
	_estilar_panel(chip_brand, C_GLASS, C_BORDER_FROST, 12, 4)
	_top_bar.add_child(chip_brand)

	var m_brand := MarginContainer.new()
	m_brand.add_theme_constant_override("margin_left", 18)
	m_brand.add_theme_constant_override("margin_right", 22)
	m_brand.add_theme_constant_override("margin_top", 10)
	m_brand.add_theme_constant_override("margin_bottom", 10)
	chip_brand.add_child(m_brand)

	var hb_brand := HBoxContainer.new()
	hb_brand.add_theme_constant_override("separation", 14)
	m_brand.add_child(hb_brand)

	var barra_acento := ColorRect.new()
	barra_acento.color = C_AMBER
	barra_acento.custom_minimum_size = Vector2(5, 34)
	hb_brand.add_child(barra_acento)

	var vb_tit := VBoxContainer.new()
	vb_tit.add_theme_constant_override("separation", 0)
	hb_brand.add_child(vb_tit)

	_lbl_hub_titulo = Label.new()
	_lbl_hub_titulo.text = "CENTRO DE MAPAS"
	_lbl_hub_titulo.add_theme_font_size_override("font_size", 28)
	_lbl_hub_titulo.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	if _fuente: _lbl_hub_titulo.add_theme_font_override("font", _fuente)
	vb_tit.add_child(_lbl_hub_titulo)

	_lbl_hub_sub = Label.new()
	_lbl_hub_sub.text = "NUESTRA TIERRA  •  EXPLORA, DESCARGA Y JUEGA"
	_lbl_hub_sub.add_theme_font_size_override("font_size", 13)
	_lbl_hub_sub.add_theme_color_override("font_color", C_TEXT_MUTED)
	if _fuente: _lbl_hub_sub.add_theme_font_override("font", _fuente)
	vb_tit.add_child(_lbl_hub_sub)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(spacer)

	# Chip de saldo de Esmeraldas
	var chip_esm := PanelContainer.new()
	_estilar_panel(chip_esm, C_GLASS, C_AMBER, 10, 4)
	_top_bar.add_child(chip_esm)

	var m_esm := MarginContainer.new()
	m_esm.add_theme_constant_override("margin_left", 16)
	m_esm.add_theme_constant_override("margin_right", 16)
	m_esm.add_theme_constant_override("margin_top", 8)
	m_esm.add_theme_constant_override("margin_bottom", 8)
	chip_esm.add_child(m_esm)

	_lbl_esmeraldas = Label.new()
	_lbl_esmeraldas.text = "ESMERALDAS: 0"
	_lbl_esmeraldas.add_theme_font_size_override("font_size", 18)
	_lbl_esmeraldas.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	if _fuente: _lbl_esmeraldas.add_theme_font_override("font", _fuente)
	m_esm.add_child(_lbl_esmeraldas)

	var btn_volver := Button.new()
	btn_volver.text = "✕  VOLVER"
	btn_volver.custom_minimum_size = Vector2(180, 52)
	btn_volver.add_theme_font_size_override("font_size", 20)
	if _fuente: btn_volver.add_theme_font_override("font", _fuente)
	_estilar_boton_crimson(btn_volver)
	btn_volver.pressed.connect(func(): get_tree().change_scene_to_file(ESCENA_MENU_PRINCIPAL))
	_top_bar.add_child(btn_volver)

	# ── CUERPO: LEFTNAV FLOTANTE + STAGE CENTRAL ──────────────────────
	var hbox_body := HBoxContainer.new()
	hbox_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox_body.add_theme_constant_override("separation", 22)
	vbox_main.add_child(hbox_body)

	# LeftNav estilo MainMenuModerno (botones grandes y legibles)
	_left_nav = PanelContainer.new()
	_left_nav.custom_minimum_size = Vector2(330, 0)
	_left_nav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_estilar_panel(_left_nav, C_GLASS, C_BORDER_FROST, 14, 8)
	hbox_body.add_child(_left_nav)

	var m_nav := MarginContainer.new()
	m_nav.add_theme_constant_override("margin_left", 16)
	m_nav.add_theme_constant_override("margin_right", 16)
	m_nav.add_theme_constant_override("margin_top", 18)
	m_nav.add_theme_constant_override("margin_bottom", 18)
	_left_nav.add_child(m_nav)

	var vb_nav := VBoxContainer.new()
	vb_nav.add_theme_constant_override("separation", 14)
	m_nav.add_child(vb_nav)

	var tabs := [
		{"id": "galeria", "nom": "DESCUBRIR"},
		{"id": "mis_mapas", "nom": "MIS MAPAS"},
		{"id": "nuevo", "nom": "+ NUEVO MAPA"},
		{"id": "guia", "nom": "GUIA RAPIDA"}
	]
	for t in tabs:
		var btn_t := Button.new()
		btn_t.text = t["nom"]
		btn_t.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_t.custom_minimum_size = Vector2(0, 74)
		if _fuente: btn_t.add_theme_font_override("font", _fuente)
		var tid: String = t["id"]
		btn_t.pressed.connect(func(): _cambiar_tab(tid))
		vb_nav.add_child(btn_t)
		_botones_tabs[tid] = btn_t

	_btn_modo_creador = Button.new()
	_btn_modo_creador.text = "🛠  MODO CREADOR"
	_btn_modo_creador.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_btn_modo_creador.custom_minimum_size = Vector2(0, 74)
	if _fuente: _btn_modo_creador.add_theme_font_override("font", _fuente)
	_aplicar_estilo_primario(_btn_modo_creador, 18)
	_btn_modo_creador.pressed.connect(func(): _alternar_modo_creador(not _modo_creador))
	vb_nav.add_child(_btn_modo_creador)
	_actualizar_visibilidad_nav_modo()

	# Stage central transparente (las tarjetas flotan sobre el fondo 3D)
	_contenedor_vista = MarginContainer.new()
	_contenedor_vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenedor_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox_body.add_child(_contenedor_vista)

	# Toast inferior flotante
	_lbl_toast = Label.new()
	_lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_toast.add_theme_font_size_override("font_size", 20)
	_lbl_toast.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	if _fuente: _lbl_toast.add_theme_font_override("font", _fuente)
	_lbl_toast.modulate.a = 0.0
	vbox_main.add_child(_lbl_toast)

func _alternar_modo_creador(activar: bool) -> void:
	_modo_creador = activar
	_actualizar_visibilidad_nav_modo()
	if _modo_creador:
		_cambiar_tab("mis_mapas")
	else:
		_cambiar_tab("galeria")

func _actualizar_visibilidad_nav_modo() -> void:
	if _botones_tabs.has("galeria"):
		_botones_tabs["galeria"].visible = not _modo_creador
	for tid_c in ["mis_mapas", "nuevo", "guia"]:
		if _botones_tabs.has(tid_c):
			_botones_tabs[tid_c].visible = _modo_creador
	if is_instance_valid(_btn_modo_creador):
		_btn_modo_creador.text = "←  VOLVER A DESCUBRIR" if _modo_creador else "🛠  MODO CREADOR"
	if is_instance_valid(_lbl_hub_titulo):
		_lbl_hub_titulo.text = "MODO CREADOR" if _modo_creador else "CENTRO DE MAPAS"
	if is_instance_valid(_lbl_hub_sub):
		_lbl_hub_sub.text = "NUESTRA TIERRA  •  EDITOR Y GESTIÓN DE RUTAS" if _modo_creador else "NUESTRA TIERRA  •  EXPLORA, DESCARGA Y JUEGA"

func _cambiar_tab(id_tab: String) -> void:
	_tab_actual = id_tab
	for k in _botones_tabs.keys():
		var b: Button = _botones_tabs[k]
		var activo: bool = (k == id_tab)
		_aplicar_estilo_nav(b, activo)

	for child in _contenedor_vista.get_children():
		_contenedor_vista.remove_child(child)
		child.queue_free()

	match id_tab:
		"nuevo":
			_construir_vista_nuevo_mapa()
		"mis_mapas":
			_construir_vista_mis_mapas()
		"galeria":
			_construir_vista_galeria()
		"guia":
			_construir_vista_guia()

	_contenedor_vista.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_contenedor_vista, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── VISTA: NUEVO MAPA ─────────────────────────────────────────────────

func _construir_vista_nuevo_mapa() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_contenedor_vista.add_child(vbox)

	var card_nombre := PanelContainer.new()
	_estilar_panel(card_nombre, C_GLASS, C_BORDER_FROST, 14, 6)
	vbox.add_child(card_nombre)

	var m_nom := MarginContainer.new()
	m_nom.add_theme_constant_override("margin_left", 22)
	m_nom.add_theme_constant_override("margin_right", 22)
	m_nom.add_theme_constant_override("margin_top", 16)
	m_nom.add_theme_constant_override("margin_bottom", 16)
	card_nombre.add_child(m_nom)

	var hbox_nom := HBoxContainer.new()
	hbox_nom.add_theme_constant_override("separation", 16)
	m_nom.add_child(hbox_nom)

	var lbl_n := Label.new()
	lbl_n.text = "NOMBRE DEL PROYECTO"
	lbl_n.add_theme_font_size_override("font_size", 18)
	lbl_n.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	if _fuente: lbl_n.add_theme_font_override("font", _fuente)
	hbox_nom.add_child(lbl_n)

	_input_nombre_mapa = LineEdit.new()
	_input_nombre_mapa.text = "Mi Nueva Ruta"
	_input_nombre_mapa.placeholder_text = "Ej: Cordillera Oriental"
	_input_nombre_mapa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_nombre_mapa.custom_minimum_size = Vector2(0, 48)
	_input_nombre_mapa.add_theme_font_size_override("font_size", 22)
	if _fuente: _input_nombre_mapa.add_theme_font_override("font", _fuente)
	var sb_le := StyleBoxFlat.new()
	sb_le.bg_color = Color(0.05, 0.06, 0.07, 0.85)
	sb_le.border_color = C_BORDER_FROST
	sb_le.set_border_width_all(1)
	sb_le.set_corner_radius_all(8)
	sb_le.set_content_margin_all(10)
	_input_nombre_mapa.add_theme_stylebox_override("normal", sb_le)
	hbox_nom.add_child(_input_nombre_mapa)

	var hbox_plant := HBoxContainer.new()
	hbox_plant.add_theme_constant_override("separation", 16)
	hbox_plant.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox_plant)

	for p in PLANTILLAS:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sel: bool = (str(p["id"]) == _plantilla_seleccionada)
		_estilar_panel(card, Color(0.14, 0.11, 0.06, 0.86) if sel else C_CARD, C_AMBER if sel else C_BORDER_FROST, 14, 6)
		hbox_plant.add_child(card)

		var mc := MarginContainer.new()
		mc.add_theme_constant_override("margin_left", 20)
		mc.add_theme_constant_override("margin_right", 20)
		mc.add_theme_constant_override("margin_top", 20)
		mc.add_theme_constant_override("margin_bottom", 20)
		card.add_child(mc)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		mc.add_child(vb)

		var lbl_tag := Label.new()
		lbl_tag.text = "● " + p["tag"]
		lbl_tag.add_theme_font_size_override("font_size", 14)
		lbl_tag.add_theme_color_override("font_color", C_AMBER)
		if _fuente: lbl_tag.add_theme_font_override("font", _fuente)
		vb.add_child(lbl_tag)

		var lbl_t := Label.new()
		lbl_t.text = p["nombre"]
		lbl_t.add_theme_font_size_override("font_size", 26)
		lbl_t.add_theme_color_override("font_color", C_TEXT)
		if _fuente: lbl_t.add_theme_font_override("font", _fuente)
		vb.add_child(lbl_t)

		var lbl_d := Label.new()
		lbl_d.text = p["desc"]
		lbl_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lbl_d.add_theme_font_size_override("font_size", 17)
		lbl_d.add_theme_color_override("font_color", C_TEXT_MUTED)
		if _fuente: lbl_d.add_theme_font_override("font", _fuente)
		vb.add_child(lbl_d)

		var btn_sel := Button.new()
		btn_sel.text = "✓ SELECCIONADA" if sel else "SELECCIONAR"
		btn_sel.custom_minimum_size = Vector2(0, 46)
		btn_sel.add_theme_font_size_override("font_size", 18)
		if _fuente: btn_sel.add_theme_font_override("font", _fuente)
		if sel:
			_aplicar_estilo_primario(btn_sel, 18)
		else:
			_aplicar_estilo_nav(btn_sel, false)
		var pid: String = str(p["id"])
		btn_sel.pressed.connect(func():
			_plantilla_seleccionada = pid
			_cambiar_tab("nuevo")
		)
		vb.add_child(btn_sel)

	var hbox_cta := HBoxContainer.new()
	hbox_cta.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(hbox_cta)

	var btn_crear := Button.new()
	btn_crear.text = "CREAR Y ABRIR EDITOR"
	btn_crear.custom_minimum_size = Vector2(380, 64)
	if _fuente: btn_crear.add_theme_font_override("font", _fuente)
	_aplicar_estilo_primario(btn_crear, 24)
	btn_crear.pressed.connect(_on_crear_nuevo_mapa)
	hbox_cta.add_child(btn_crear)

# ── VISTA: MIS MAPAS ──────────────────────────────────────────────────

func _construir_vista_mis_mapas() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_contenedor_vista.add_child(vbox)

	var mapas := _listar_mapas_locales()
	if mapas.is_empty():
		var empty_panel := PanelContainer.new()
		empty_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_estilar_panel(empty_panel, C_GLASS, C_BORDER_FROST, 14, 8)
		vbox.add_child(empty_panel)

		var vb_e := VBoxContainer.new()
		vb_e.alignment = BoxContainer.ALIGNMENT_CENTER
		vb_e.add_theme_constant_override("separation", 18)
		empty_panel.add_child(vb_e)

		var lbl_e := Label.new()
		lbl_e.text = "NO TIENES MAPAS GUARDADOS TODAVIA"
		lbl_e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_e.add_theme_font_size_override("font_size", 26)
		lbl_e.add_theme_color_override("font_color", C_TEXT)
		if _fuente: lbl_e.add_theme_font_override("font", _fuente)
		vb_e.add_child(lbl_e)

		var btn_ir_nuevo := Button.new()
		btn_ir_nuevo.text = "+ CREAR PRIMER MAPA"
		btn_ir_nuevo.custom_minimum_size = Vector2(340, 60)
		btn_ir_nuevo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if _fuente: btn_ir_nuevo.add_theme_font_override("font", _fuente)
		_aplicar_estilo_primario(btn_ir_nuevo, 22)
		btn_ir_nuevo.pressed.connect(func(): _cambiar_tab("nuevo"))
		vb_e.add_child(btn_ir_nuevo)
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 12)
	scroll.add_child(lista)

	for m in mapas:
		var card := PanelContainer.new()
		_estilar_panel(card, C_GLASS, C_BORDER_FROST, 14, 6)
		lista.add_child(card)

		var mc := MarginContainer.new()
		mc.add_theme_constant_override("margin_left", 22)
		mc.add_theme_constant_override("margin_right", 22)
		mc.add_theme_constant_override("margin_top", 16)
		mc.add_theme_constant_override("margin_bottom", 16)
		card.add_child(mc)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		mc.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		hbox.add_child(info)

		var lbl_n := Label.new()
		lbl_n.text = m["nombre"]
		lbl_n.add_theme_font_size_override("font_size", 24)
		lbl_n.add_theme_color_override("font_color", C_AMBER_BRIGHT)
		if _fuente: lbl_n.add_theme_font_override("font", _fuente)
		info.add_child(lbl_n)

		var lbl_meta := Label.new()
		lbl_meta.text = "AUTOR: %s   •   VIAS: %d   •   OBJETOS: %d" % [
			str(m["autor"]).to_upper(), m["num_vias"], m["num_objetos"]
		]
		lbl_meta.add_theme_font_size_override("font_size", 15)
		lbl_meta.add_theme_color_override("font_color", C_TEXT_MUTED)
		if _fuente: lbl_meta.add_theme_font_override("font", _fuente)
		info.add_child(lbl_meta)

		var ruta_m: String = m["ruta"]
		var nombre_m: String = m["nombre"]

		var btn_editar := Button.new()
		btn_editar.text = "ABRIR"
		btn_editar.custom_minimum_size = Vector2(135, 52)
		if _fuente: btn_editar.add_theme_font_override("font", _fuente)
		_aplicar_estilo_primario(btn_editar, 19)
		btn_editar.pressed.connect(func(): _abrir_en_editor(ruta_m, nombre_m, "valle_verde"))
		hbox.add_child(btn_editar)

		var btn_subir := Button.new()
		btn_subir.text = "SUBIR"
		btn_subir.custom_minimum_size = Vector2(125, 52)
		if _fuente: btn_subir.add_theme_font_override("font", _fuente)
		_aplicar_estilo_nav(btn_subir, false)
		btn_subir.pressed.connect(func(): _abrir_modal_subida(ruta_m, nombre_m))
		hbox.add_child(btn_subir)

		var btn_dup := Button.new()
		btn_dup.text = "DUPLICAR"
		btn_dup.custom_minimum_size = Vector2(135, 52)
		if _fuente: btn_dup.add_theme_font_override("font", _fuente)
		_aplicar_estilo_nav(btn_dup, false)
		btn_dup.pressed.connect(func(): _duplicar_mapa(ruta_m, nombre_m))
		hbox.add_child(btn_dup)

		var btn_del := Button.new()
		btn_del.text = "X"
		btn_del.custom_minimum_size = Vector2(54, 52)
		if _fuente: btn_del.add_theme_font_override("font", _fuente)
		_estilar_boton_crimson(btn_del)
		btn_del.pressed.connect(func(): _eliminar_mapa(ruta_m))
		hbox.add_child(btn_del)

# ── VISTA: GALERÍA DE MAPAS ───────────────────────────────────────────

func _construir_vista_galeria() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_contenedor_vista.add_child(vbox)

	# Buscador amplio optimizado para móviles (nombre, creador o identificador)
	var hbox_busq := HBoxContainer.new()
	hbox_busq.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox_busq)

	var le_busq := LineEdit.new()
	le_busq.text = _busqueda_galeria
	le_busq.placeholder_text = "🔍  Buscar mapa por nombre, creador o ID (ej: 123.map)..."
	le_busq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le_busq.custom_minimum_size = Vector2(0, 62)
	le_busq.add_theme_font_size_override("font_size", 20)
	le_busq.add_theme_color_override("font_color", C_TEXT)
	le_busq.add_theme_color_override("font_placeholder_color", Color(0.68, 0.72, 0.78, 0.70))
	if _fuente_cuerpo:
		le_busq.add_theme_font_override("font", _fuente_cuerpo)
	elif _fuente:
		le_busq.add_theme_font_override("font", _fuente)
	var sb_busq := StyleBoxFlat.new()
	sb_busq.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	sb_busq.set_corner_radius_all(12)
	sb_busq.set_border_width_all(2)
	sb_busq.border_color = C_BORDER_FROST
	sb_busq.content_margin_left = 18
	sb_busq.content_margin_right = 18
	var sb_busq_f := sb_busq.duplicate() as StyleBoxFlat
	sb_busq_f.border_color = C_AMBER
	le_busq.add_theme_stylebox_override("normal", sb_busq)
	le_busq.add_theme_stylebox_override("focus", sb_busq_f)
	hbox_busq.add_child(le_busq)

	var btn_limpiar_busq := Button.new()
	btn_limpiar_busq.text = "✕"
	btn_limpiar_busq.custom_minimum_size = Vector2(62, 62)
	btn_limpiar_busq.add_theme_font_size_override("font_size", 22)
	btn_limpiar_busq.visible = not _busqueda_galeria.strip_edges().is_empty()
	_aplicar_estilo_nav(btn_limpiar_busq, false)
	hbox_busq.add_child(btn_limpiar_busq)

	le_busq.text_changed.connect(func(nuevo: String):
		_busqueda_galeria = nuevo
		btn_limpiar_busq.visible = not nuevo.strip_edges().is_empty()
		_poblar_grid_galeria()
	)
	btn_limpiar_busq.pressed.connect(func():
		_busqueda_galeria = ""
		le_busq.text = ""
		btn_limpiar_busq.visible = false
		_poblar_grid_galeria()
	)

	var hbox_filtros := HBoxContainer.new()
	hbox_filtros.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox_filtros)

	for cat in ["Todos", "Sierra", "Urbano", "Autopista"]:
		var btn_f := Button.new()
		btn_f.text = cat.to_upper()
		btn_f.custom_minimum_size = Vector2(140, 44)
		if _fuente: btn_f.add_theme_font_override("font", _fuente)
		var act: bool = (str(cat) == _filtro_galeria)
		_aplicar_estilo_nav(btn_f, act)
		var c_id: String = cat
		btn_f.pressed.connect(func():
			_filtro_galeria = c_id
			_cambiar_tab("galeria")
		)
		hbox_filtros.add_child(btn_f)

	var sp_f := Control.new()
	sp_f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_filtros.add_child(sp_f)

	var btn_refrescar := Button.new()
	btn_refrescar.text = "ACTUALIZAR"
	btn_refrescar.custom_minimum_size = Vector2(160, 44)
	if _fuente: btn_refrescar.add_theme_font_override("font", _fuente)
	_aplicar_estilo_nav(btn_refrescar, false)
	btn_refrescar.pressed.connect(func():
		_mostrar_toast("Actualizando mapas de la comunidad...")
		if _repo_comunidad:
			_repo_comunidad.cargar_mapas_comunidad()
	)
	hbox_filtros.add_child(btn_refrescar)

	var scroll_g := ScrollContainer.new()
	scroll_g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_g)

	_grid_galeria = GridContainer.new()
	_grid_galeria.columns = 3
	_grid_galeria.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_galeria.add_theme_constant_override("h_separation", 16)
	_grid_galeria.add_theme_constant_override("v_separation", 16)
	scroll_g.add_child(_grid_galeria)
	_poblar_grid_galeria()

func _poblar_grid_galeria() -> void:
	if not is_instance_valid(_grid_galeria):
		return
	for ch in _grid_galeria.get_children():
		ch.queue_free()
	var grid := _grid_galeria
	var q_busq: String = _busqueda_galeria.strip_edges().to_lower()
	var fuente_lista: Array[Dictionary] = _mapas_comunidad_cache
	for item in fuente_lista:
		var cat_it: String = str(item.get("categoria", "Sierra"))
		if _filtro_galeria != "Todos" and cat_it != _filtro_galeria:
			continue
		if not q_busq.is_empty():
			var nom_b := str(item.get("nombre", "")).to_lower()
			var aut_b := str(item.get("autor", "")).to_lower()
			var id_b := str(item.get("id_mapa", "")).to_lower()
			var cod_b := str(item.get("codigo_id", "")).to_lower()
			if not (q_busq in nom_b or q_busq in aut_b or q_busq in id_b or q_busq in cod_b):
				continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_contents = true
		_estilar_panel(card, Color(0.07, 0.08, 0.10, 0.94), C_BORDER_FROST, 16, 0)
		grid.add_child(card)

		var vb_root := VBoxContainer.new()
		vb_root.add_theme_constant_override("separation", 0)
		card.add_child(vb_root)

		var portada_url: String = str(item.get("portada_url", ""))

		# Portada edge-to-edge con degradado inferior y badges flotantes
		var marco_portada := Control.new()
		marco_portada.custom_minimum_size = Vector2(0, 224)
		marco_portada.clip_contents = true
		vb_root.add_child(marco_portada)

		var bg_ph := ColorRect.new()
		bg_ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_ph.color = Color(0.05, 0.06, 0.08, 1.0)
		marco_portada.add_child(bg_ph)

		var tex_portada := TextureRect.new()
		tex_portada.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_portada.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_portada.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		marco_portada.add_child(tex_portada)

		var lbl_sin_img := Label.new()
		lbl_sin_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl_sin_img.text = str(item.get("nombre", "MAPA")).to_upper()
		lbl_sin_img.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sin_img.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_sin_img.add_theme_font_size_override("font_size", 20)
		lbl_sin_img.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.28))
		if _fuente: lbl_sin_img.add_theme_font_override("font", _fuente)
		marco_portada.add_child(lbl_sin_img)

		# Degradado inferior para fundir la portada con la tarjeta oscura
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(0.07, 0.08, 0.10, 0.0), Color(0.07, 0.08, 0.10, 0.96)])
		var grad_tex := GradientTexture2D.new()
		grad_tex.gradient = grad
		grad_tex.fill_from = Vector2(0.5, 0.0)
		grad_tex.fill_to = Vector2(0.5, 1.0)
		var rect_grad := TextureRect.new()
		rect_grad.anchor_left = 0.0
		rect_grad.anchor_right = 1.0
		rect_grad.anchor_top = 0.45
		rect_grad.anchor_bottom = 1.0
		rect_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect_grad.texture = grad_tex
		rect_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marco_portada.add_child(rect_grad)

		# Badge de categoría arriba izquierda
		var pill_cat := PanelContainer.new()
		pill_cat.position = Vector2(14, 14)
		_estilar_panel(pill_cat, Color(0.06, 0.07, 0.09, 0.86), C_AMBER, 8, 6)
		marco_portada.add_child(pill_cat)
		var lbl_cat := Label.new()
		lbl_cat.text = cat_it.to_upper()
		lbl_cat.add_theme_font_size_override("font_size", 12)
		lbl_cat.add_theme_color_override("font_color", C_AMBER_BRIGHT)
		if _fuente_bold: lbl_cat.add_theme_font_override("font", _fuente_bold)
		elif _fuente: lbl_cat.add_theme_font_override("font", _fuente)
		pill_cat.add_child(lbl_cat)

		# Pill de peso abajo derecha
		var pill_stats := PanelContainer.new()
		pill_stats.anchor_left = 1.0
		pill_stats.anchor_right = 1.0
		pill_stats.anchor_top = 1.0
		pill_stats.anchor_bottom = 1.0
		pill_stats.offset_left = -112.0
		pill_stats.offset_right = -14.0
		pill_stats.offset_top = -38.0
		pill_stats.offset_bottom = -10.0
		_estilar_panel(pill_stats, Color(0.06, 0.07, 0.09, 0.88), C_BORDER_FROST, 8, 5)
		marco_portada.add_child(pill_stats)
		var lbl_stats := Label.new()
		lbl_stats.text = str(item.get("peso_texto", "Ligero"))
		lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_stats.add_theme_font_size_override("font_size", 14)
		lbl_stats.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
		if _fuente_bold: lbl_stats.add_theme_font_override("font", _fuente_bold)
		elif _fuente_cuerpo: lbl_stats.add_theme_font_override("font", _fuente_cuerpo)
		pill_stats.add_child(lbl_stats)

		if _repo_comunidad and not portada_url.is_empty():
			var tex_ref := tex_portada
			var lbl_ref := lbl_sin_img
			_repo_comunidad.descargar_portada_async(portada_url, func(tex: Texture2D):
				if is_instance_valid(tex_ref) and tex:
					tex_ref.texture = tex
					if is_instance_valid(lbl_ref):
						lbl_ref.visible = false
			)

		# Cuerpo inferior con márgenes compactos y CreatoDisplay para textos
		var mc := MarginContainer.new()
		mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mc.add_theme_constant_override("margin_left", 18)
		mc.add_theme_constant_override("margin_right", 18)
		mc.add_theme_constant_override("margin_top", 8)
		mc.add_theme_constant_override("margin_bottom", 14)
		vb_root.add_child(mc)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		mc.add_child(vb)

		var lbl_t := Label.new()
		lbl_t.text = str(item.get("nombre", "Mapa"))
		lbl_t.add_theme_font_size_override("font_size", 21)
		lbl_t.add_theme_color_override("font_color", C_TEXT)
		lbl_t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if _fuente: lbl_t.add_theme_font_override("font", _fuente)
		vb.add_child(lbl_t)

		# Autor con chip premium
		var hb_autor := HBoxContainer.new()
		hb_autor.add_theme_constant_override("separation", 6)
		vb.add_child(hb_autor)

		var lbl_estrella := Label.new()
		lbl_estrella.text = "✦"
		lbl_estrella.add_theme_font_size_override("font_size", 16)
		lbl_estrella.add_theme_color_override("font_color", C_AMBER_BRIGHT)
		hb_autor.add_child(lbl_estrella)

		var lbl_a := Label.new()
		lbl_a.text = str(item.get("autor", "Comunidad"))
		lbl_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_a.add_theme_font_size_override("font_size", 17)
		lbl_a.add_theme_color_override("font_color", Color(0.96, 0.78, 0.36, 1.0))
		if _fuente_bold: lbl_a.add_theme_font_override("font", _fuente_bold)
		elif _fuente_cuerpo: lbl_a.add_theme_font_override("font", _fuente_cuerpo)
		hb_autor.add_child(lbl_a)

		var cod_disp: String = str(item.get("codigo_id", item.get("id_mapa", "")))
		if not cod_disp.is_empty():
			var lbl_id := Label.new()
			lbl_id.text = "ID: " + cod_disp
			lbl_id.add_theme_font_size_override("font_size", 14)
			lbl_id.add_theme_color_override("font_color", Color(0.68, 0.73, 0.80, 0.88))
			if _fuente_bold: lbl_id.add_theme_font_override("font", _fuente_bold)
			elif _fuente_cuerpo: lbl_id.add_theme_font_override("font", _fuente_cuerpo)
			hb_autor.add_child(lbl_id)

		var lbl_d := Label.new()
		lbl_d.text = str(item.get("descripcion", ""))
		lbl_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lbl_d.custom_minimum_size = Vector2(0, 34)
		lbl_d.add_theme_font_size_override("font_size", 18)
		lbl_d.add_theme_color_override("font_color", Color(0.84, 0.88, 0.93, 0.95))
		if _fuente_cuerpo: lbl_d.add_theme_font_override("font", _fuente_cuerpo)
		vb.add_child(lbl_d)

		var btn_jugar := Button.new()
		btn_jugar.text = "▶   JUGAR AHORA"
		btn_jugar.custom_minimum_size = Vector2(0, 46)
		if _fuente: btn_jugar.add_theme_font_override("font", _fuente)
		btn_jugar.add_theme_font_size_override("font_size", 17)
		btn_jugar.add_theme_color_override("font_color", Color(0.06, 0.07, 0.09, 1.0))
		btn_jugar.add_theme_color_override("font_hover_color", Color(0.04, 0.05, 0.07, 1.0))
		btn_jugar.add_theme_color_override("font_pressed_color", Color(0.04, 0.05, 0.07, 1.0))

		var sb_n := StyleBoxFlat.new()
		sb_n.bg_color = Color(0.90, 0.67, 0.24, 0.96)
		sb_n.set_corner_radius_all(12)
		sb_n.set_border_width_all(2)
		sb_n.border_color = Color(1.0, 0.85, 0.46, 0.95)
		sb_n.shadow_size = 8
		sb_n.shadow_color = Color(0.90, 0.67, 0.24, 0.32)

		var sb_h := sb_n.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(0.98, 0.76, 0.32, 1.0)
		sb_h.border_color = Color(1.0, 0.92, 0.62, 1.0)
		sb_h.shadow_size = 12

		var sb_p := sb_n.duplicate() as StyleBoxFlat
		sb_p.bg_color = Color(0.76, 0.55, 0.18, 1.0)
		sb_p.shadow_size = 4

		btn_jugar.add_theme_stylebox_override("normal", sb_n)
		btn_jugar.add_theme_stylebox_override("hover", sb_h)
		btn_jugar.add_theme_stylebox_override("pressed", sb_p)
		var it_copy := item
		btn_jugar.pressed.connect(func():
			var res: Dictionary = _repo_comunidad.preparar_mapa_para_jugar(it_copy)
			_mostrar_toast(str(res.get("mensaje", "")))
			if res.get("exito", false):
				_jugar_mapa_directo(str(res.get("ruta", "")), str(res.get("nombre", "Mapa")))
		)
		vb.add_child(btn_jugar)

# ── VISTA: GUÍA RÁPIDA ────────────────────────────────────────────────

func _construir_vista_guia() -> void:
	var card := PanelContainer.new()
	_estilar_panel(card, C_GLASS, C_BORDER_FROST, 14, 6)
	_contenedor_vista.add_child(card)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 28)
	mc.add_theme_constant_override("margin_right", 28)
	mc.add_theme_constant_override("margin_top", 24)
	mc.add_theme_constant_override("margin_bottom", 24)
	card.add_child(mc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	mc.add_child(vb)

	var tips := [
		"Camara 3D: Clic derecho para orbitar, rueda central para panear, WASD/QE para volar y rueda para zoom.",
		"Vias y Rotondas: Selecciona un tipo de via o rotonda (3-6 salidas) y coloca puntos sobre el terreno.",
		"Seleccionar Tramo (A -> B): Toca un punto, pulsa Seleccionar Tramo y toca el Punto B para poner aceras, luces o barreras.",
		"Tuneles y Pilares: Si la via queda 3m o mas sobre el terreno se crean pilares; si tiene +12m arriba se crea tunel.",
		"Probar Mapa: Coloca el punto de Spawn y pulsa Probar Mapa para conducir la T800 y caminar por tu ruta."
	]
	for t in tips:
		var lbl := Label.new()
		lbl.text = t
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", C_TEXT)
		if _fuente: lbl.add_theme_font_override("font", _fuente)
		vb.add_child(lbl)

# ── ACCIONES DE ARCHIVOS Y NAVEGACIÓN ─────────────────────────────────

func _on_crear_nuevo_mapa() -> void:
	var nombre := _input_nombre_mapa.text.strip_edges() if _input_nombre_mapa else "Mi Nueva Ruta"
	if nombre.is_empty():
		nombre = "Mi Nueva Ruta"
	var hora := 12
	for p in PLANTILLAS:
		if p["id"] == _plantilla_seleccionada:
			hora = int(p["hora"])
			break
	var ruta := _crear_archivo_mapa(nombre, _plantilla_seleccionada, hora)
	if ruta != "":
		_abrir_en_editor(ruta, nombre, _plantilla_seleccionada)

func _crear_archivo_mapa(nombre: String, plantilla: String, hora: int) -> String:
	if not DirAccess.dir_exists_absolute(DIR_MAPAS):
		DirAccess.make_dir_recursive_absolute(DIR_MAPAS)
	var slug := nombre.to_lower().replace(" ", "_")
	for c in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		slug = slug.replace(c, "")
	if slug.is_empty():
		slug = "mapa"
	var ruta := "%s/%s_%d.ntmap" % [DIR_MAPAS, slug, Time.get_unix_time_from_system()]
	var autor := "EditorNuestraTierra"
	var du = get_node_or_null("/root/DatosUsuario")
	if du and "nombre_jugador" in du and str(du.nombre_jugador) != "":
		autor = str(du.nombre_jugador)
	var datos := {
		"formato": "NT_MAP",
		"version": 2,
		"nombre": nombre,
		"autor": autor,
		"plantilla": plantilla,
		"hora_dia": hora,
		"objetos": [],
		"vegetacion_multimesh": {},
		"carreteras": [],
		"equipamiento_vias": [],
		"cuerpos_agua": [],
		"spawn": {"posicion": [128.0, 0.2, 128.0], "rotacion_y": 0.0, "modo": "vehiculo"}
	}
	var f := FileAccess.open_compressed(ruta, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if not f:
		f = FileAccess.open(ruta, FileAccess.WRITE)
	if not f:
		_mostrar_toast("Error al crear el archivo del mapa.")
		return ""
	f.store_string(JSON.stringify(datos))
	f.close()
	return ruta

func _leer_texto_ntmap(ruta: String) -> String:
	var f_comp := FileAccess.open_compressed(ruta, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f_comp:
		var txt_c := f_comp.get_as_text()
		f_comp.close()
		if txt_c.strip_edges().begins_with("{"):
			return txt_c
	var f_plain := FileAccess.open(ruta, FileAccess.READ)
	if f_plain:
		var txt_p := f_plain.get_as_text()
		f_plain.close()
		return txt_p
	return ""

func _listar_mapas_locales() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(DIR_MAPAS):
		DirAccess.make_dir_recursive_absolute(DIR_MAPAS)
	var ruta_def := "res://mundo/editor_mapas/mapas_defecto/ciudad_prueba_grande.ntmap"
	var ruta_dest := DIR_MAPAS + "/ciudad_prueba_grande.ntmap"
	if FileAccess.file_exists(ruta_def) and not FileAccess.file_exists(ruta_dest):
		var bytes_def := FileAccess.get_file_as_bytes(ruta_def)
		var f_out := FileAccess.open(ruta_dest, FileAccess.WRITE)
		if f_out and not bytes_def.is_empty():
			f_out.store_buffer(bytes_def)
			f_out.close()
	var dir := DirAccess.open(DIR_MAPAS)
	if not dir:
		return res
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".ntmap"):
			var ruta := DIR_MAPAS + "/" + fname
			var txt := _leer_texto_ntmap(ruta)
			if not txt.is_empty():
				var json := JSON.new()
				if json.parse(txt) == OK and json.data is Dictionary:
					var d: Dictionary = json.data
					res.append({
						"ruta": ruta,
						"archivo": fname,
						"nombre": str(d.get("nombre", fname.get_basename().capitalize())),
						"autor": str(d.get("autor", "Local")),
						"num_vias": (d.get("carreteras", []) as Array).size(),
						"num_objetos": (d.get("objetos", []) as Array).size()
					})
		fname = dir.get_next()
	dir.list_dir_end()
	return res

func _duplicar_mapa(ruta_origen: String, nombre_origen: String) -> void:
	var f := FileAccess.open(ruta_origen, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		var datos: Dictionary = json.data
		datos["nombre"] = nombre_origen + " (Copia)"
		var nueva_ruta := "%s/copia_%d.ntmap" % [DIR_MAPAS, Time.get_unix_time_from_system()]
		var fw := FileAccess.open(nueva_ruta, FileAccess.WRITE)
		if fw:
			fw.store_string(JSON.stringify(datos, "  "))
			fw.close()
			_mostrar_toast("Mapa duplicado.")
			_cambiar_tab("mis_mapas")
	f.close()

func _eliminar_mapa(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)
		_mostrar_toast("Mapa eliminado.")
		_cambiar_tab("mis_mapas")

func _jugar_mapa_directo(ruta: String, nombre: String) -> void:
	Engine.set_meta("nt_editor_mapa_ruta", ruta)
	Engine.set_meta("nt_editor_mapa_nombre", nombre)
	Engine.set_meta("nt_editor_mapa_plantilla", "valle_verde")
	Engine.set_meta("nt_jugar_directo", true)
	get_tree().change_scene_to_file(ESCENA_EDITOR_MAPAS)

func _abrir_en_editor(ruta: String, nombre: String, plantilla: String) -> void:
	Engine.set_meta("nt_editor_mapa_ruta", ruta)
	Engine.set_meta("nt_editor_mapa_nombre", nombre)
	Engine.set_meta("nt_editor_mapa_plantilla", plantilla)
	Engine.set_meta("nt_jugar_directo", false)
	get_tree().change_scene_to_file(ESCENA_EDITOR_MAPAS)

func _on_mapas_comunidad_cargados(lista: Array[Dictionary]) -> void:
	_mapas_comunidad_cache = lista
	if _tab_actual == "galeria":
		_cambiar_tab("galeria")

func _actualizar_saldo_esmeraldas() -> void:
	if not is_instance_valid(_lbl_esmeraldas):
		return
	var esm := 0
	var du = get_node_or_null("/root/DatosUsuario")
	if du and "esmeraldas" in du:
		esm = int(du.esmeraldas)
	_lbl_esmeraldas.text = "ESMERALDAS: %d" % esm

func _abrir_modal_subida(ruta_mapa: String, nombre_mapa: String) -> void:
	if is_instance_valid(_modal_subida):
		_modal_subida.queue_free()

	_modal_subida = PanelContainer.new()
	_modal_subida.set_anchors_preset(Control.PRESET_CENTER)
	_modal_subida.custom_minimum_size = Vector2(600, 420)
	_modal_subida.position = Vector2(-300, -210)
	_estilar_panel(_modal_subida, Color(0.06, 0.07, 0.08, 0.96), C_AMBER, 16, 12)
	add_child(_modal_subida)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 24)
	mc.add_theme_constant_override("margin_right", 24)
	mc.add_theme_constant_override("margin_top", 22)
	mc.add_theme_constant_override("margin_bottom", 22)
	_modal_subida.add_child(mc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	mc.add_child(vb)

	var lbl_t := Label.new()
	lbl_t.text = "SUBIR MAPA: " + nombre_mapa.to_upper()
	lbl_t.add_theme_font_size_override("font_size", 22)
	lbl_t.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	if _fuente: lbl_t.add_theme_font_override("font", _fuente)
	vb.add_child(lbl_t)

	var cat_sel := {"val": "Sierra"}
	var hb_cat := HBoxContainer.new()
	hb_cat.add_theme_constant_override("separation", 8)
	vb.add_child(hb_cat)
	var btns_c: Array[Button] = []
	for c in ["Sierra", "Urbano", "Autopista"]:
		var bc := Button.new()
		bc.text = c.to_upper()
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bc.custom_minimum_size = Vector2(0, 44)
		if _fuente: bc.add_theme_font_override("font", _fuente)
		_aplicar_estilo_nav(bc, c == "Sierra")
		var c_str: String = c
		bc.pressed.connect(func():
			cat_sel["val"] = c_str
			for idx in range(btns_c.size()):
				_aplicar_estilo_nav(btns_c[idx], btns_c[idx].text == c_str.to_upper())
		)
		hb_cat.add_child(bc)
		btns_c.append(bc)

	var le_desc := LineEdit.new()
	le_desc.placeholder_text = "Descripción corta de tu ruta..."
	le_desc.custom_minimum_size = Vector2(0, 48)
	le_desc.add_theme_font_size_override("font_size", 18)
	if _fuente: le_desc.add_theme_font_override("font", _fuente)
	vb.add_child(le_desc)

	var le_portada := LineEdit.new()
	le_portada.placeholder_text = "Link de imagen de portada (ej: https://cdn.discordapp.com/...)"
	le_portada.custom_minimum_size = Vector2(0, 48)
	le_portada.add_theme_font_size_override("font_size", 16)
	if _fuente: le_portada.add_theme_font_override("font", _fuente)
	vb.add_child(le_portada)

	var lbl_info := Label.new()
	lbl_info.text = "Se subirá tu archivo .ntmap a Supabase y aparecerá en Descubrir para todo el mundo."
	lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_info.add_theme_font_size_override("font_size", 15)
	lbl_info.add_theme_color_override("font_color", C_TEXT_MUTED)
	if _fuente: lbl_info.add_theme_font_override("font", _fuente)
	vb.add_child(lbl_info)

	var hb_act := HBoxContainer.new()
	hb_act.add_theme_constant_override("separation", 12)
	vb.add_child(hb_act)

	var btn_can := Button.new()
	btn_can.text = "CANCELAR"
	btn_can.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_can.custom_minimum_size = Vector2(0, 50)
	if _fuente: btn_can.add_theme_font_override("font", _fuente)
	_estilar_boton_crimson(btn_can)
	btn_can.pressed.connect(func(): _modal_subida.queue_free())
	hb_act.add_child(btn_can)

	var btn_pub := Button.new()
	btn_pub.text = "PUBLICAR EN DESCUBRIR"
	btn_pub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pub.custom_minimum_size = Vector2(0, 50)
	if _fuente: btn_pub.add_theme_font_override("font", _fuente)
	_aplicar_estilo_primario(btn_pub, 18)
	btn_pub.pressed.connect(func():
		var res: Dictionary = _repo_comunidad.subir_mapa(ruta_mapa, cat_sel["val"], le_desc.text, le_portada.text)
		_mostrar_toast(str(res.get("mensaje", "")))
		_modal_subida.queue_free()
	)
	hb_act.add_child(btn_pub)

func _mostrar_toast(msg: String) -> void:
	if not _lbl_toast:
		return
	_lbl_toast.text = msg
	_lbl_toast.modulate.a = 1.0
	if _tween_toast:
		_tween_toast.kill()
	_tween_toast = create_tween()
	_tween_toast.tween_interval(2.0)
	_tween_toast.tween_property(_lbl_toast, "modulate:a", 0.0, 0.4)

# ── ESTILOS IDÉNTICOS A MAINMENUMODERNO ───────────────────────────────

func _crear_estilo(fondo: Color, borde: Color, radio: int, grosor: int = 1, sombra: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(grosor)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = sombra
	sb.shadow_offset = Vector2(0, 3)
	return sb

func _estilar_panel(ctrl: Control, bg: Color, borde: Color, radio: int, sombra: int = 6) -> void:
	ctrl.add_theme_stylebox_override("panel", _crear_estilo(bg, borde, radio, 1, sombra))

func _aplicar_estilo_nav(btn: Button, activo: bool = false) -> void:
	var normal := _crear_estilo(
		Color(0.18, 0.14, 0.07, 0.90) if activo else Color(0.06, 0.07, 0.08, 0.55),
		C_AMBER if activo else Color(0.78, 0.81, 0.85, 0.12),
		10, 1, 6 if activo else 0
	)
	if activo:
		normal.border_width_left = 4
	var hover := _crear_estilo(Color(0.13, 0.15, 0.18, 0.92), C_BORDER_BRIGHT, 10, 1, 6)
	var pressed := _crear_estilo(Color(0.18, 0.20, 0.24, 0.96), C_AMBER, 10, 1, 8)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", C_AMBER_BRIGHT if activo else C_TEXT)

func _aplicar_estilo_primario(btn: Button, tam_fuente: int = 22) -> void:
	var normal := _crear_estilo(Color(0.88, 0.68, 0.28, 1.0), Color(1.0, 0.86, 0.55, 0.9), 12, 1, 0)
	normal.shadow_color = Color(0.88, 0.68, 0.28, 0.25)
	normal.shadow_size = 14
	normal.shadow_offset = Vector2(0, 4)
	var hover := _crear_estilo(Color(0.96, 0.77, 0.37, 1.0), Color(1.0, 0.92, 0.66, 1.0), 12, 1, 0)
	hover.shadow_color = Color(0.88, 0.68, 0.28, 0.38)
	hover.shadow_size = 18
	var pressed := _crear_estilo(Color(0.78, 0.58, 0.22, 1.0), Color(1.0, 0.86, 0.55, 1.0), 12, 1, 0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", tam_fuente)
	btn.add_theme_color_override("font_color", TINTE_TINTA)
	btn.add_theme_color_override("font_hover_color", TINTE_TINTA)
	btn.add_theme_color_override("font_pressed_color", TINTE_TINTA)

func _estilar_boton_crimson(btn: Button) -> void:
	var normal := _crear_estilo(Color(0.24, 0.08, 0.08, 0.85), C_CRIMSON, 10, 1, 6)
	var hover := _crear_estilo(Color(0.36, 0.11, 0.11, 0.95), Color(1.0, 0.45, 0.42, 0.95), 10, 1, 8)
	var pressed := _crear_estilo(C_CRIMSON, Color.WHITE, 10, 1, 4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", C_TEXT)
