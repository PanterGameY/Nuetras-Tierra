class_name UIDisenadorCasaModular
extends Control

## UIDisenadorCasaModular.gd — Diseñador visual 3D de Casas Modulares
## Estética Glassmorphism Automotriz (diseño.md): controles amplios y legibles para móvil/PC,
## visor 3D grande con auto-encuadre completo y modal dedicado para selección de colores.

signal casa_confirmada(config: Dictionary)
signal cancelado()

const C_BG_GLASS := Color(0.06, 0.07, 0.08, 0.95)
const C_SURFACE_CARD := Color(0.09, 0.10, 0.12, 0.92)
const C_SURFACE_ELEV := Color(0.12, 0.14, 0.17, 0.95)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_BORDER_SUBTLE := Color(0.78, 0.81, 0.85, 0.14)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.95)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_TEXT_PRI := Color(0.92, 0.94, 0.96, 0.98)
const C_TEXT_MUT := Color(0.62, 0.66, 0.72, 0.92)
const FONT_PATH := "res://recursos/fonts/Moderniz.otf"

var _config: Dictionary = {}
var _fuente: Font = null
var _panel_principal: PanelContainer = null
var _tabs_bar: HBoxContainer = null
var _contenido_tab: VBoxContainer = null
var _tab_activa: String = "estilos"
var _filtro_categoria: String = "todos"

# Modal de Selector de Color
var _modal_color: Control = null

# Preview 3D
var _subviewport: SubViewport = null
var _pivote_camara: Node3D = null
var _camara_preview: Camera3D = null
var _sol_preview: DirectionalLight3D = null
var _world_env_preview: WorldEnvironment = null
var _casa_preview: Node3D = null
var _arrastrando_preview: bool = false
var _rot_auto: bool = true
var _modo_noche: bool = false
var _dist_camara: float = 24.0
var _zoom_factor: float = 1.0
var _yaw_camara: float = 0.62
var _pitch_camara: float = -0.30

var _tex_grabber: ImageTexture = null

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	if ResourceLoader.exists(FONT_PATH):
		_fuente = load(FONT_PATH)
	_crear_textura_grabber()
	if _config.is_empty():
		_config = DatosCasaModular.crear_config_defecto()
	_construir_ui()
	_reconstruir_preview_3d()
	_animar_entrada()

func abrir_con_config(cfg: Dictionary) -> void:
	_config = DatosCasaModular.normalizar_config(cfg)
	_zoom_factor = 1.0
	if is_inside_tree():
		_reconstruir_preview_3d()
		_construir_contenido_tab()
		_animar_entrada()

func _process(delta: float) -> void:
	if _rot_auto and not _arrastrando_preview and _pivote_camara:
		_yaw_camara += delta * 0.25
		_actualizar_camara_preview()

func _crear_textura_grabber() -> void:
	var sz := 28
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz * 0.5, sz * 0.5)
	for y in range(sz):
		for x in range(sz):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= 12.0:
				if d >= 8.8:
					img.set_pixel(x, y, Color(0.96, 0.97, 0.99, 1.0))
				else:
					img.set_pixel(x, y, C_AMBER)
			elif d <= 13.6:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.45))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_tex_grabber = ImageTexture.create_from_image(img)

func _animar_entrada() -> void:
	if not _panel_principal:
		return
	_panel_principal.pivot_offset = _panel_principal.size * 0.5
	_panel_principal.scale = Vector2(0.94, 0.94)
	_panel_principal.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel_principal, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel_principal, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _crear_stylebox(bg: Color, borde: Color, radio: int = 10, grosor: int = 1, pad_h: int = 14, pad_v: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	sb.set_corner_radius_all(radio)
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

func _estilar_boton(btn: Button, activo: bool = false, carmesi: bool = false) -> void:
	var bg := Color(0.08, 0.09, 0.11, 0.88)
	var bd := C_BORDER_FROST
	if carmesi:
		bg = Color(0.24, 0.11, 0.11, 0.95)
		bd = C_CRIMSON
	elif activo:
		bg = Color(0.18, 0.20, 0.24, 0.96)
		bd = C_AMBER

	var normal := _crear_stylebox(bg, bd, 10, 2 if (activo or carmesi) else 1, 14, 10)
	var hover := _crear_stylebox(bg.lightened(0.08), C_AMBER if not carmesi else C_CRIMSON, 10, 2 if activo else 1, 14, 10)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", C_AMBER if activo else C_TEXT_PRI)
	if _fuente:
		btn.add_theme_font_override("font", _fuente)

func _construir_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.04, 0.75)
	add_child(dim)

	_panel_principal = PanelContainer.new()
	_panel_principal.anchor_left = 0.018
	_panel_principal.anchor_top = 0.022
	_panel_principal.anchor_right = 0.982
	_panel_principal.anchor_bottom = 0.978
	_panel_principal.add_theme_stylebox_override("panel", _crear_stylebox(C_BG_GLASS, C_BORDER_FROST, 14, 1, 18, 16))
	add_child(_panel_principal)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	_panel_principal.add_child(root_vbox)

	# ── CABECERA ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root_vbox.add_child(header)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "DISEÑADOR ARQUITECTÓNICO MODULAR"
	lbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_titulo.add_theme_font_size_override("font_size", 32)
	lbl_titulo.add_theme_color_override("font_color", C_TEXT_PRI)
	if _fuente:
		lbl_titulo.add_theme_font_override("font", _fuente)
	header.add_child(lbl_titulo)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕ CERRAR"
	btn_cerrar.custom_minimum_size = Vector2(150, 50)
	btn_cerrar.add_theme_font_size_override("font_size", 20)
	_estilar_boton(btn_cerrar, false, true)
	btn_cerrar.pressed.connect(func():
		cancelado.emit()
		queue_free()
	)
	header.add_child(btn_cerrar)

	# ── CUERPO PRINCIPAL (IZQ 52%: PREVIEW 3D GRANDE | DER 48%: CONTROLES AMPLIOS) ──
	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 16)
	root_vbox.add_child(cuerpo)

	# IZQUIERDA: Visor 3D grande
	var card_preview := PanelContainer.new()
	card_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_preview.size_flags_stretch_ratio = 1.12
	card_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_preview.add_theme_stylebox_override("panel", _crear_stylebox(C_SURFACE_CARD, C_BORDER_FROST, 12, 1, 12, 12))
	cuerpo.add_child(card_preview)

	var vbox_prev := VBoxContainer.new()
	vbox_prev.add_theme_constant_override("separation", 10)
	card_preview.add_child(vbox_prev)

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.gui_input.connect(_on_preview_gui_input)
	vbox_prev.add_child(svc)

	_subviewport = SubViewport.new()
	_subviewport.own_world_3d = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_subviewport)
	_configurar_escena_preview()

	var hbox_prev_ctrl := HBoxContainer.new()
	hbox_prev_ctrl.add_theme_constant_override("separation", 10)
	vbox_prev.add_child(hbox_prev_ctrl)

	var btn_encuadrar := Button.new()
	btn_encuadrar.text = "⌖ Encuadrar"
	btn_encuadrar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_encuadrar.custom_minimum_size = Vector2(0, 48)
	btn_encuadrar.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_encuadrar, false)
	btn_encuadrar.pressed.connect(func():
		_zoom_factor = 1.0
		_pitch_camara = -0.30
		_actualizar_camara_preview()
	)
	hbox_prev_ctrl.add_child(btn_encuadrar)

	var btn_rot := Button.new()
	btn_rot.text = "⟳ Giro Auto"
	btn_rot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rot.custom_minimum_size = Vector2(0, 48)
	btn_rot.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_rot, _rot_auto)
	btn_rot.pressed.connect(func():
		_rot_auto = not _rot_auto
		_estilar_boton(btn_rot, _rot_auto)
	)
	hbox_prev_ctrl.add_child(btn_rot)

	var btn_luz := Button.new()
	btn_luz.text = "☀ Día / 🌙 Noche"
	btn_luz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_luz.custom_minimum_size = Vector2(0, 48)
	btn_luz.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_luz, _modo_noche)
	btn_luz.pressed.connect(func():
		_modo_noche = not _modo_noche
		_estilar_boton(btn_luz, _modo_noche)
		_actualizar_iluminacion_preview()
	)
	hbox_prev_ctrl.add_child(btn_luz)

	# DERECHA: Pestañas + Scroll de Propiedades
	var vbox_der := VBoxContainer.new()
	vbox_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_der.size_flags_stretch_ratio = 1.0
	vbox_der.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_der.add_theme_constant_override("separation", 10)
	cuerpo.add_child(vbox_der)

	_tabs_bar = HBoxContainer.new()
	_tabs_bar.add_theme_constant_override("separation", 8)
	vbox_der.add_child(_tabs_bar)
	_construir_tabs_bar()

	var card_ctrl := PanelContainer.new()
	card_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_ctrl.add_theme_stylebox_override("panel", _crear_stylebox(C_SURFACE_CARD, C_BORDER_FROST, 12, 1, 14, 14))
	vbox_der.add_child(card_ctrl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_ctrl.add_child(scroll)

	_contenido_tab = VBoxContainer.new()
	_contenido_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido_tab.add_theme_constant_override("separation", 12)
	scroll.add_child(_contenido_tab)
	_construir_contenido_tab()

	# ── PIE: ACCIONES ──
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root_vbox.add_child(footer)

	var btn_rand := Button.new()
	btn_rand.text = "🎲 ALEATORIO"
	btn_rand.custom_minimum_size = Vector2(210, 58)
	btn_rand.add_theme_font_size_override("font_size", 22)
	_estilar_boton(btn_rand, false)
	btn_rand.pressed.connect(_aleatorizar_casa)
	footer.add_child(btn_rand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var btn_confirmar := Button.new()
	btn_confirmar.text = "✓ GUARDAR Y USAR CASA"
	btn_confirmar.custom_minimum_size = Vector2(340, 58)
	btn_confirmar.add_theme_font_size_override("font_size", 22)
	_estilar_boton(btn_confirmar, true)
	btn_confirmar.pressed.connect(func():
		casa_confirmada.emit(_config.duplicate(true))
		queue_free()
	)
	footer.add_child(btn_confirmar)

func _configurar_escena_preview() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.68)
	sky_mat.sky_horizon_color = Color(0.64, 0.74, 0.84)
	sky_mat.ground_bottom_color = Color(0.12, 0.14, 0.16)
	sky_mat.ground_horizon_color = Color(0.32, 0.36, 0.40)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	_world_env_preview = WorldEnvironment.new()
	_world_env_preview.environment = env
	_subviewport.add_child(_world_env_preview)

	_sol_preview = DirectionalLight3D.new()
	_sol_preview.rotation_degrees = Vector3(-42, 35, 0)
	_sol_preview.light_energy = 1.5
	_sol_preview.shadow_enabled = true
	_subviewport.add_child(_sol_preview)

	var cesped := MeshInstance3D.new()
	var cyl_c := CylinderMesh.new()
	cyl_c.top_radius = 28.0
	cyl_c.bottom_radius = 29.0
	cyl_c.height = 0.3
	cesped.mesh = cyl_c
	cesped.position.y = -0.18
	var mat_c := StandardMaterial3D.new()
	mat_c.albedo_color = Color(0.22, 0.30, 0.19)
	mat_c.roughness = 0.95
	cesped.material_override = mat_c
	_subviewport.add_child(cesped)

	var anden := MeshInstance3D.new()
	var box_a := BoxMesh.new()
	box_a.size = Vector3(26.0, 0.08, 26.0)
	anden.mesh = box_a
	anden.position.y = -0.04
	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = Color(0.38, 0.39, 0.41)
	mat_a.roughness = 0.88
	anden.material_override = mat_a
	_subviewport.add_child(anden)

	_pivote_camara = Node3D.new()
	_subviewport.add_child(_pivote_camara)

	_camara_preview = Camera3D.new()
	_camara_preview.fov = 40.0
	_pivote_camara.add_child(_camara_preview)
	_actualizar_camara_preview()

func _actualizar_camara_preview() -> void:
	if not _pivote_camara or not _camara_preview:
		return
	var n_mod: int = clampi(int(_config.get("modulos_conjunto", 1)), 1, 5)
	var ancho: float = float(_config.get("ancho", 9.0)) * float(n_mod)
	if int(_config.get("silos_laterales", 0)) > 0:
		ancho += 4.5
	var fondo: float = float(_config.get("fondo", 8.0))
	if bool(_config.get("tiene_porteria", false)):
		fondo += 6.0
	var pisos: int = int(_config.get("pisos", 2))
	var h_piso: float = float(_config.get("altura_piso", 3.0))
	var h_zoc: float = float(_config.get("altura_zocalo", 0.45))
	var h_techo: float = 2.5 if str(_config.get("tipo_techo", "dos_aguas")) != "plano" else 1.5
	var h_total: float = h_zoc + float(pisos) * h_piso + h_techo
	if bool(_config.get("tiene_chimenea_ind", false)):
		h_total = maxf(h_total, 12.5)

	var radio: float = Vector3(ancho * 0.5, h_total * 0.5, fondo * 0.5).length()
	var half_fov := deg_to_rad(_camara_preview.fov * 0.5)
	_dist_camara = (radio / sin(half_fov)) * 1.15 * _zoom_factor

	_pivote_camara.position = Vector3(0.0, h_total * 0.45, 0.0)
	_pivote_camara.rotation = Vector3(_pitch_camara, _yaw_camara, 0.0)
	_camara_preview.position = Vector3(0.0, 0.0, _dist_camara)

func _actualizar_iluminacion_preview() -> void:
	var sky_mat := _world_env_preview.environment.sky.sky_material as ProceduralSkyMaterial
	if _modo_noche:
		sky_mat.sky_top_color = Color(0.02, 0.03, 0.07)
		sky_mat.sky_horizon_color = Color(0.06, 0.08, 0.14)
		_world_env_preview.environment.ambient_light_energy = 0.22
		_sol_preview.light_energy = 0.28
		_sol_preview.light_color = Color(0.55, 0.68, 0.95)
	else:
		sky_mat.sky_top_color = Color(0.22, 0.42, 0.68)
		sky_mat.sky_horizon_color = Color(0.64, 0.74, 0.84)
		_world_env_preview.environment.ambient_light_energy = 0.65
		_sol_preview.light_energy = 1.5
		_sol_preview.light_color = Color(1.0, 0.97, 0.92)

func _on_preview_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando_preview = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_factor = clampf(_zoom_factor - 0.08, 0.55, 1.85)
			_actualizar_camara_preview()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_factor = clampf(_zoom_factor + 0.08, 0.55, 1.85)
			_actualizar_camara_preview()
	elif ev is InputEventMouseMotion and _arrastrando_preview:
		_yaw_camara -= ev.relative.x * 0.01
		_pitch_camara = clampf(_pitch_camara - ev.relative.y * 0.01, -1.15, 0.12)
		_actualizar_camara_preview()

func _reconstruir_preview_3d() -> void:
	if not _subviewport:
		return
	if _casa_preview and is_instance_valid(_casa_preview):
		GeneradorCasaModular.reconstruir_casa(_casa_preview, _config)
	else:
		_casa_preview = GeneradorCasaModular.crear_casa(_config)
		_subviewport.add_child(_casa_preview)
	_actualizar_camara_preview()

func _construir_tabs_bar() -> void:
	for c in _tabs_bar.get_children():
		c.queue_free()
	var tabs := [
		["estilos", "Estilos"],
		["estructura", "Estructura"],
		["fachada", "Fachada"],
		["aberturas", "Puertas"],
		["techo", "Techo"],
	]
	for t in tabs:
		var btn := Button.new()
		btn.text = t[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 18)
		_estilar_boton(btn, _tab_activa == t[0])
		btn.pressed.connect(func():
			_tab_activa = t[0]
			_construir_tabs_bar()
			_construir_contenido_tab()
		)
		_tabs_bar.add_child(btn)

func _construir_contenido_tab() -> void:
	for c in _contenido_tab.get_children():
		c.queue_free()
	match _tab_activa:
		"estilos": _tab_estilos()
		"estructura": _tab_estructura()
		"fachada": _tab_fachada()
		"aberturas": _tab_aberturas()
		"techo": _tab_techo_extras()

# ============================================================================
# TABS DE CONTENIDO (AMPLIAS Y BIEN APROVECHADAS)
# ============================================================================

func _tab_estilos() -> void:
	_add_seccion("CATEGORÍA DE EDIFICACIÓN")
	var grid_cat := GridContainer.new()
	grid_cat.columns = 3
	grid_cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_cat.add_theme_constant_override("h_separation", 8)
	grid_cat.add_theme_constant_override("v_separation", 8)
	_contenido_tab.add_child(grid_cat)

	var cats := [{"id": "todos", "nombre": "Todos"}]
	cats.append_array(DatosCasaModular.CATEGORIAS_CONSTRUCCION)
	for c in cats:
		var bc := Button.new()
		bc.text = c["nombre"]
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bc.custom_minimum_size = Vector2(0, 48)
		bc.add_theme_font_size_override("font_size", 17)
		_estilar_boton(bc, _filtro_categoria == c["id"])
		bc.pressed.connect(func():
			_filtro_categoria = c["id"]
			_construir_contenido_tab()
		)
		grid_cat.add_child(bc)

	_add_seccion("PLANTILLAS ARQUITECTÓNICAS")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_contenido_tab.add_child(grid)

	for p in DatosCasaModular.obtener_presets():
		var p_cat := str(p["config"].get("categoria", "casa"))
		if _filtro_categoria != "todos" and p_cat != _filtro_categoria:
			continue
		var btn := Button.new()
		btn.text = "%s\n%s" % [p["nombre"], p["desc"]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 96)
		btn.add_theme_font_size_override("font_size", 17)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_estilar_boton(btn, _config.get("preset", "") == p["id"])
		btn.pressed.connect(func():
			_config = DatosCasaModular.normalizar_config(p["config"])
			_zoom_factor = 1.0
			_reconstruir_preview_3d()
			_construir_contenido_tab()
		)
		grid.add_child(btn)

func _tab_estructura() -> void:
	_add_seccion("DIMENSIONES PRINCIPALES")
	_add_slider("Ancho por Módulo (m)", "ancho", 4.0, 36.0, 0.5)
	_add_slider("Fondo / Largo (m)", "fondo", 4.0, 30.0, 0.5)
	_add_slider("Cantidad de Pisos", "pisos", 1, 12, 1, true)
	_add_slider("Altura por Piso (m)", "altura_piso", 2.4, 7.5, 0.1)
	_add_slider("Altura de Zócalo / Base (m)", "altura_zocalo", 0.0, 1.4, 0.05)
	_add_slider("Módulos Adosados (Conjunto)", "modulos_conjunto", 1, 5, 1, true)

	_add_seccion("FORMA VOLUMÉTRICA")
	var hbox_f := HBoxContainer.new()
	hbox_f.add_theme_constant_override("separation", 10)
	_contenido_tab.add_child(hbox_f)
	for f in DatosCasaModular.FORMAS_CASA:
		var btn := Button.new()
		btn.text = f["nombre"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 58)
		btn.add_theme_font_size_override("font_size", 17)
		_estilar_boton(btn, str(_config.get("forma", "rectangular")) == f["id"])
		btn.pressed.connect(func():
			_config["forma"] = f["id"]
			_reconstruir_preview_3d()
			_construir_contenido_tab()
		)
		hbox_f.add_child(btn)

func _tab_fachada() -> void:
	_add_seccion("FACHADA PRINCIPAL")
	_add_selector_lista("Material Fachada", "mat_fachada", DatosCasaModular.MATERIALES_FACHADA, "id", "nombre")
	_add_boton_color("Color de Fachada", "color_fachada", DatosCasaModular.PALETA_COLORES_FACHADA)
	_add_slider("Escala de Textura", "escala_textura", 0.15, 0.80, 0.05)

	_add_seccion("PRIMER PISO, ZÓCALO Y MOLDURAS")
	_add_check("Usar Material Diferente en Piso 1", "usar_mat_piso1")
	if bool(_config.get("usar_mat_piso1", false)):
		_add_selector_lista("Material Piso 1", "mat_piso1", DatosCasaModular.MATERIALES_FACHADA, "id", "nombre")
		_add_boton_color("Color de Piso 1", "color_piso1", DatosCasaModular.PALETA_COLORES_FACHADA)
	_add_selector_lista("Material Zócalo", "mat_zocalo", DatosCasaModular.MATERIALES_FACHADA, "id", "nombre")
	_add_boton_color("Color de Zócalo", "color_zocalo", DatosCasaModular.PALETA_COLORES_ACENTO)
	_add_boton_color("Color de Molduras / Cornisas", "color_molduras", DatosCasaModular.PALETA_COLORES_ACENTO)

func _tab_aberturas() -> void:
	_add_seccion("PUERTA PRINCIPAL Y GARAJE")
	_add_selector_lista("Estilo Puerta", "tipo_puerta", DatosCasaModular.ESTILOS_PUERTA, "id", "nombre")
	_add_boton_color("Color de Puerta", "color_puerta", DatosCasaModular.PALETA_COLORES_ACENTO)
	_add_selector_lista("Posición Puerta", "pos_puerta", [
		{"id": "izquierda", "nombre": "Izquierda"},
		{"id": "centro", "nombre": "Centro"},
		{"id": "derecha", "nombre": "Derecha"},
	], "id", "nombre")
	_add_check("Puerta Doble Ancho", "puerta_doble")
	_add_check("Incluir Garaje / Cortina Comercial", "tiene_garaje")
	if bool(_config.get("tiene_garaje", false)):
		_add_selector_lista("Estilo Garaje", "tipo_garaje", DatosCasaModular.ESTILOS_PUERTA, "id", "nombre")
		_add_boton_color("Color de Garaje", "color_garaje", DatosCasaModular.PALETA_COLORES_ACENTO)

	_add_seccion("VENTANAS E ILUMINACIÓN")
	_add_selector_lista("Ventanas Piso 1", "tipo_ventana_p1", DatosCasaModular.ESTILOS_VENTANA, "id", "nombre")
	_add_selector_lista("Ventanas Pisos Superiores", "tipo_ventana_sup", DatosCasaModular.ESTILOS_VENTANA, "id", "nombre")
	_add_boton_color("Color Marcos de Ventana", "color_ventanas", DatosCasaModular.PALETA_COLORES_ACENTO)
	_add_slider("Ventanas Frente", "ventanas_frente", 0, 5, 1, true)
	_add_slider("Ventanas Laterales", "ventanas_lados", 0, 5, 1, true)
	_add_slider("Ventanas Atrás", "ventanas_atras", 0, 5, 1, true)
	_add_slider("Tamaño de Ventanas", "escala_ventana", 0.65, 1.45, 0.05)
	_add_check("Luz Interior Nocturna", "luz_nocturna")
	if bool(_config.get("luz_nocturna", true)):
		_add_slider("Intensidad de Luz", "intensidad_luz", 0.2, 2.5, 0.1)

func _tab_techo_extras() -> void:
	_add_seccion("CUBIERTA / TECHO")
	_add_selector_lista("Tipo de Techo", "tipo_techo", DatosCasaModular.TIPOS_TECHO, "id", "nombre")
	_add_selector_lista("Material Techo", "mat_techo", DatosCasaModular.MATERIALES_TECHO, "id", "nombre")
	_add_boton_color("Tinte / Color de Techo", "color_techo", DatosCasaModular.PALETA_COLORES_FACHADA)
	_add_slider("Pendiente del Techo (°)", "pendiente_techo", 8.0, 48.0, 1.0)
	_add_slider("Alero / Voladizo (m)", "alero", 0.0, 1.5, 0.05)

	_add_seccion("ELEMENTOS ARQUITECTÓNICOS")
	_add_check("Balcón en Pisos Superiores", "tiene_balcon")
	if bool(_config.get("tiene_balcon", false)):
		_add_selector_lista("Tipo Balcón", "tipo_balcon", DatosCasaModular.TIPOS_BALCON, "id", "nombre")
		_add_boton_color("Color de Balcón", "color_balcon", DatosCasaModular.PALETA_COLORES_ACENTO)
	_add_check("Porche / Corredor Frontal", "tiene_porche")
	if bool(_config.get("tiene_porche", false)):
		_add_boton_color("Color Columnas Porche", "color_porche", DatosCasaModular.PALETA_COLORES_ACENTO)
	_add_check("Escaleras de Entrada", "tiene_escaleras")
	_add_check("Toldo Comercial", "tiene_toldo")
	if bool(_config.get("tiene_toldo", false)):
		_add_boton_color("Color de Toldo", "color_toldo", DatosCasaModular.PALETA_COLORES_ACENTO)
	_add_check("Chimenea Residencial", "tiene_chimenea")
	_add_check("Tinaco / Tanque Elevado Azotea", "detalles_azotea")
	_add_check("Jardineras en Ventanas", "tiene_jardineras")
	_add_check("Pilastras en Esquinas", "tiene_pilastras")

	_add_seccion("MÓDULOS EDIFICIOS, INDUSTRIA, CONJUNTOS Y COMERCIO")
	_add_check("Marquesina de Entrada (Lobby / Centro Comercial)", "tiene_marquesina")
	_add_check("Portería con Talanquera (Conjunto Residencial)", "tiene_porteria")
	_add_slider("Muelles de Carga Logísticos", "muelles_carga", 0, 5, 1, true)
	_add_slider("Silos Industriales Laterales", "silos_laterales", 0, 4, 1, true)
	_add_check("Chimenea Industrial Alta", "tiene_chimenea_ind")
	_add_slider("Unidades HVAC en Azotea", "unidades_hvac", 0, 6, 1, true)
	_add_check("Domos Tragaluces en Cubierta", "tiene_domos")
	_add_check("Antena Telecomunicaciones Azotea", "tiene_antena")
	_add_check("Paneles Solares en Azotea", "tiene_paneles_solares")
	_add_check("Tótem / Letrero Comercial", "tiene_totem")
	if bool(_config.get("tiene_totem", false)):
		_add_boton_color("Color Tótem Comercial", "color_totem", DatosCasaModular.PALETA_COLORES_ACENTO)

# ============================================================================
# CONTROLES UI GRANDES Y LEGIBLES (MÓVIL / PC)
# ============================================================================

func _crear_tarjeta_columna() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _crear_stylebox(C_SURFACE_ELEV, C_BORDER_SUBTLE, 10, 1, 14, 12))
	_contenido_tab.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	return vbox

func _crear_tarjeta_fila() -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _crear_stylebox(C_SURFACE_ELEV, C_BORDER_SUBTLE, 10, 1, 14, 10))
	_contenido_tab.add_child(panel)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)
	return hbox

func _add_seccion(titulo: String) -> void:
	var lbl := Label.new()
	lbl.text = "▸ " + titulo
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", C_AMBER)
	if _fuente:
		lbl.add_theme_font_override("font", _fuente)
	_contenido_tab.add_child(lbl)

func _add_slider(titulo: String, clave: String, min_v: float, max_v: float, paso: float, entero: bool = false) -> void:
	var vbox := _crear_tarjeta_columna()

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)

	var lbl := Label.new()
	lbl.text = titulo
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_TEXT_PRI)
	top.add_child(lbl)

	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(78, 36)
	pill.add_theme_stylebox_override("panel", _crear_stylebox(Color(0.06, 0.07, 0.09, 0.95), C_AMBER, 8, 1, 8, 4))
	top.add_child(pill)

	var val_lbl := Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", C_AMBER)
	var v_ini := float(_config.get(clave, min_v))
	val_lbl.text = str(int(v_ini)) if entero else ("%.2f" % v_ini)
	pill.add_child(val_lbl)

	# Fila inferior: Slider grande que aprovecha todo el ancho + botones -/+ táctiles
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 10)
	vbox.add_child(bot)

	var btn_menos := Button.new()
	btn_menos.text = "−"
	btn_menos.custom_minimum_size = Vector2(44, 42)
	btn_menos.add_theme_font_size_override("font_size", 22)
	_estilar_boton(btn_menos, false)
	bot.add_child(btn_menos)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = paso
	sl.value = v_ini
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(0, 42)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.05, 0.06, 0.08, 0.96)
	sb_track.border_color = C_BORDER_FROST
	sb_track.set_border_width_all(1)
	sb_track.set_corner_radius_all(8)
	sb_track.content_margin_top = 8
	sb_track.content_margin_bottom = 8

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = C_AMBER
	sb_fill.set_corner_radius_all(8)

	sl.add_theme_stylebox_override("slider", sb_track)
	sl.add_theme_stylebox_override("grabber_area", sb_fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", sb_fill)
	if _tex_grabber:
		sl.add_theme_icon_override("grabber", _tex_grabber)
		sl.add_theme_icon_override("grabber_highlight", _tex_grabber)
	bot.add_child(sl)

	var btn_mas := Button.new()
	btn_mas.text = "+"
	btn_mas.custom_minimum_size = Vector2(44, 42)
	btn_mas.add_theme_font_size_override("font_size", 22)
	_estilar_boton(btn_mas, false)
	bot.add_child(btn_mas)

	sl.value_changed.connect(func(v: float):
		_config[clave] = int(v) if entero else v
		val_lbl.text = str(int(v)) if entero else ("%.2f" % v)
		_reconstruir_preview_3d()
	)
	btn_menos.pressed.connect(func(): sl.value = maxf(min_v, sl.value - paso))
	btn_mas.pressed.connect(func(): sl.value = minf(max_v, sl.value + paso))

func _add_check(titulo: String, clave: String) -> void:
	var hbox := _crear_tarjeta_fila()
	var activo := bool(_config.get(clave, false))

	var lbl := Label.new()
	lbl.text = titulo
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_TEXT_PRI)
	hbox.add_child(lbl)

	var btn := Button.new()
	btn.text = "ACTIVADO" if activo else "DESACTIVADO"
	btn.custom_minimum_size = Vector2(150, 44)
	btn.add_theme_font_size_override("font_size", 16)
	_estilar_boton(btn, activo)
	btn.pressed.connect(func():
		_config[clave] = not bool(_config.get(clave, false))
		_reconstruir_preview_3d()
		_construir_contenido_tab()
	)
	hbox.add_child(btn)

func _add_selector_lista(titulo: String, clave: String, items: Array, key_id: String, key_nom: String) -> void:
	var vbox := _crear_tarjeta_columna()

	var lbl := Label.new()
	lbl.text = titulo
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_TEXT_MUT)
	vbox.add_child(lbl)

	var cur_val = _config.get(clave)
	var nombre_actual := str(cur_val)
	for it in items:
		if str(it[key_id]) == str(cur_val):
			nombre_actual = str(it[key_nom])
			break

	var btn_sel := Button.new()
	btn_sel.text = "  %s    ▾" % nombre_actual
	btn_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sel.custom_minimum_size = Vector2(0, 54)
	btn_sel.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_sel.add_theme_font_size_override("font_size", 20)
	_estilar_boton(btn_sel, false)
	btn_sel.add_theme_color_override("font_color", C_AMBER)
	btn_sel.pressed.connect(func():
		_abrir_modal_selector(titulo, clave, items, key_id, key_nom)
	)
	vbox.add_child(btn_sel)

func _abrir_modal_selector(titulo: String, clave: String, items: Array, key_id: String, key_nom: String) -> void:
	if _modal_color and is_instance_valid(_modal_color):
		_modal_color.queue_free()

	_modal_color = Control.new()
	_modal_color.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_modal_color.mouse_filter = MOUSE_FILTER_STOP
	add_child(_modal_color)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.03, 0.78)
	_modal_color.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_modal_color.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 620)
	panel.add_theme_stylebox_override("panel", _crear_stylebox(C_BG_GLASS, C_AMBER, 14, 2, 22, 20))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var lbl_t := Label.new()
	lbl_t.text = "SELECCIONAR — " + titulo.to_upper()
	lbl_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_t.add_theme_font_size_override("font_size", 26)
	lbl_t.add_theme_color_override("font_color", C_AMBER)
	if _fuente:
		lbl_t.add_theme_font_override("font", _fuente)
	hdr.add_child(lbl_t)

	var btn_x := Button.new()
	btn_x.text = "✕ CERRAR"
	btn_x.custom_minimum_size = Vector2(140, 48)
	btn_x.add_theme_font_size_override("font_size", 18)
	_estilar_boton(btn_x, false, true)
	btn_x.pressed.connect(func(): _modal_color.queue_free())
	hdr.add_child(btn_x)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var cur_val = _config.get(clave)
	for it in items:
		var es_act := (str(it[key_id]) == str(cur_val))
		var b := Button.new()
		b.text = str(it[key_nom])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 68)
		b.add_theme_font_size_override("font_size", 21)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_estilar_boton(b, es_act)
		b.pressed.connect(func():
			_config[clave] = it[key_id]
			_reconstruir_preview_3d()
			_modal_color.queue_free()
			_construir_contenido_tab()
		)
		grid.add_child(b)

func _add_boton_color(titulo: String, clave: String, paleta: Array[Dictionary]) -> void:
	var hbox := _crear_tarjeta_fila()

	var lbl := Label.new()
	lbl.text = titulo
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_TEXT_PRI)
	hbox.add_child(lbl)

	var col_actual := DatosCasaModular.parsear_color(_config.get(clave, "#ffffff"))

	var btn_abrir := Button.new()
	btn_abrir.text = "  Elegir Color"
	btn_abrir.custom_minimum_size = Vector2(210, 46)
	btn_abrir.add_theme_font_size_override("font_size", 17)
	_estilar_boton(btn_abrir, false)
	hbox.add_child(btn_abrir)

	var muestra := Panel.new()
	muestra.custom_minimum_size = Vector2(36, 36)
	muestra.mouse_filter = MOUSE_FILTER_IGNORE
	muestra.add_theme_stylebox_override("panel", _crear_stylebox(col_actual, C_BORDER_FROST, 7, 2, 0, 0))
	hbox.add_child(muestra)

	btn_abrir.pressed.connect(func():
		_abrir_modal_color(titulo, clave, paleta)
	)

# ============================================================================
# PANEL MODAL DEDICADO PARA SELECCIÓN DE COLORES
# ============================================================================

func _abrir_modal_color(titulo: String, clave: String, paleta: Array[Dictionary]) -> void:
	if _modal_color and is_instance_valid(_modal_color):
		_modal_color.queue_free()

	_modal_color = Control.new()
	_modal_color.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_modal_color.mouse_filter = MOUSE_FILTER_STOP
	add_child(_modal_color)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.03, 0.80)
	_modal_color.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.05
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.95
	panel.add_theme_stylebox_override("panel", _crear_stylebox(C_BG_GLASS, C_AMBER, 16, 2, 24, 22))
	_modal_color.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Cabecera modal color
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 14)
	vbox.add_child(hdr)

	var lbl_t := Label.new()
	lbl_t.text = "SELECTOR DE COLOR — " + titulo.to_upper()
	lbl_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_t.add_theme_font_size_override("font_size", 28)
	lbl_t.add_theme_color_override("font_color", C_AMBER)
	if _fuente:
		lbl_t.add_theme_font_override("font", _fuente)
	hdr.add_child(lbl_t)

	var btn_x := Button.new()
	btn_x.text = "✕ CERRAR"
	btn_x.custom_minimum_size = Vector2(160, 56)
	btn_x.add_theme_font_size_override("font_size", 20)
	_estilar_boton(btn_x, false, true)
	btn_x.pressed.connect(func(): _modal_color.queue_free())
	hdr.add_child(btn_x)

	# Cuerpo en 2 columnas grandes para móvil
	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 20)
	vbox.add_child(cuerpo)

	# ── COLUMNA IZQUIERDA: PALETA EN BOTONES GRANDES + MUESTRA ──
	var card_pal := PanelContainer.new()
	card_pal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_pal.size_flags_stretch_ratio = 1.1
	card_pal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_pal.add_theme_stylebox_override("panel", _crear_stylebox(C_SURFACE_CARD, C_BORDER_FROST, 12, 1, 16, 16))
	cuerpo.add_child(card_pal)

	var col_izq := VBoxContainer.new()
	col_izq.add_theme_constant_override("separation", 14)
	card_pal.add_child(col_izq)

	var lbl_pal := Label.new()
	lbl_pal.text = "PALETA ARQUITECTÓNICA"
	lbl_pal.add_theme_font_size_override("font_size", 20)
	lbl_pal.add_theme_color_override("font_color", C_AMBER)
	if _fuente:
		lbl_pal.add_theme_font_override("font", _fuente)
	col_izq.add_child(lbl_pal)

	var scroll_pal := ScrollContainer.new()
	scroll_pal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_pal.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_izq.add_child(scroll_pal)

	var grid_pal := GridContainer.new()
	grid_pal.columns = 2
	grid_pal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_pal.add_theme_constant_override("h_separation", 12)
	grid_pal.add_theme_constant_override("v_separation", 12)
	scroll_pal.add_child(grid_pal)

	# ── COLUMNA DERECHA: SELECTOR TÁCTIL + SLIDERS RGB GRANDES ──
	var card_rgb := PanelContainer.new()
	card_rgb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_rgb.size_flags_stretch_ratio = 1.0
	card_rgb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_rgb.add_theme_stylebox_override("panel", _crear_stylebox(C_SURFACE_CARD, C_BORDER_FROST, 12, 1, 16, 16))
	cuerpo.add_child(card_rgb)

	var col_der := VBoxContainer.new()
	col_der.add_theme_constant_override("separation", 12)
	card_rgb.add_child(col_der)

	var lbl_rgb := Label.new()
	lbl_rgb.text = "AJUSTE PERSONALIZADO"
	lbl_rgb.add_theme_font_size_override("font_size", 20)
	lbl_rgb.add_theme_color_override("font_color", C_AMBER)
	if _fuente:
		lbl_rgb.add_theme_font_override("font", _fuente)
	col_der.add_child(lbl_rgb)

	var col_ini := DatosCasaModular.parsear_color(_config.get(clave, "#ffffff"))

	# Muestra grande del color seleccionado
	var muestra_box := PanelContainer.new()
	muestra_box.custom_minimum_size = Vector2(0, 62)
	var sb_muestra := _crear_stylebox(col_ini, C_BORDER_FROST, 10, 2, 14, 8)
	muestra_box.add_theme_stylebox_override("panel", sb_muestra)
	col_der.add_child(muestra_box)

	var lbl_hex := Label.new()
	lbl_hex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hex.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_hex.add_theme_font_size_override("font_size", 22)
	col_der.move_child(muestra_box, 1)
	muestra_box.add_child(lbl_hex)

	var cp := ColorPicker.new()
	cp.color = col_ini
	cp.edit_alpha = false
	cp.presets_visible = false
	cp.color_modes_visible = false
	cp.sliders_visible = false
	cp.sampler_visible = false
	cp.hex_visible = false
	cp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_der.add_child(cp)

	var sliders_rgb: Array[HSlider] = []
	var labels_rgb: Array[Label] = []
	var bloqueando_sync := [false]

	var actualizar_ui_color := func(c: Color):
		sb_muestra.bg_color = c
		lbl_hex.text = "#" + c.to_html(false).to_upper()
		lbl_hex.add_theme_color_override("font_color", Color(0.08, 0.09, 0.10) if c.get_luminance() > 0.52 else Color(0.95, 0.96, 0.98))
		_config[clave] = "#" + c.to_html(false)
		_reconstruir_preview_3d()
		if not bloqueando_sync[0] and sliders_rgb.size() == 3:
			bloqueando_sync[0] = true
			sliders_rgb[0].value = roundi(c.r * 255.0)
			sliders_rgb[1].value = roundi(c.g * 255.0)
			sliders_rgb[2].value = roundi(c.b * 255.0)
			labels_rgb[0].text = str(int(sliders_rgb[0].value))
			labels_rgb[1].text = str(int(sliders_rgb[1].value))
			labels_rgb[2].text = str(int(sliders_rgb[2].value))
			bloqueando_sync[0] = false

	# Sliders R, G, B grandes y táctiles
	var canales := [
		["ROJO", Color(0.88, 0.28, 0.28)],
		["VERDE", Color(0.30, 0.82, 0.42)],
		["AZUL", Color(0.32, 0.58, 0.92)],
	]
	for idx_c in range(3):
		var fila_c := HBoxContainer.new()
		fila_c.add_theme_constant_override("separation", 10)
		col_der.add_child(fila_c)

		var l_nom := Label.new()
		l_nom.text = canales[idx_c][0]
		l_nom.custom_minimum_size = Vector2(76, 0)
		l_nom.add_theme_font_size_override("font_size", 17)
		l_nom.add_theme_color_override("font_color", canales[idx_c][1])
		fila_c.add_child(l_nom)

		var sl_c := HSlider.new()
		sl_c.min_value = 0
		sl_c.max_value = 255
		sl_c.step = 1
		sl_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl_c.custom_minimum_size = Vector2(0, 42)
		sl_c.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var sb_tr := StyleBoxFlat.new()
		sb_tr.bg_color = Color(0.05, 0.06, 0.08, 0.96)
		sb_tr.border_color = C_BORDER_FROST
		sb_tr.set_border_width_all(1)
		sb_tr.set_corner_radius_all(8)
		sb_tr.content_margin_top = 8
		sb_tr.content_margin_bottom = 8
		var sb_fl := StyleBoxFlat.new()
		sb_fl.bg_color = canales[idx_c][1]
		sb_fl.set_corner_radius_all(8)
		sl_c.add_theme_stylebox_override("slider", sb_tr)
		sl_c.add_theme_stylebox_override("grabber_area", sb_fl)
		sl_c.add_theme_stylebox_override("grabber_area_highlight", sb_fl)
		if _tex_grabber:
			sl_c.add_theme_icon_override("grabber", _tex_grabber)
			sl_c.add_theme_icon_override("grabber_highlight", _tex_grabber)
		fila_c.add_child(sl_c)

		var l_val := Label.new()
		l_val.custom_minimum_size = Vector2(52, 0)
		l_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l_val.add_theme_font_size_override("font_size", 18)
		l_val.add_theme_color_override("font_color", C_TEXT_PRI)
		fila_c.add_child(l_val)

		sliders_rgb.append(sl_c)
		labels_rgb.append(l_val)
		sl_c.value_changed.connect(func(_v: float):
			if bloqueando_sync[0]:
				return
			bloqueando_sync[0] = true
			var nc := Color(sliders_rgb[0].value / 255.0, sliders_rgb[1].value / 255.0, sliders_rgb[2].value / 255.0)
			labels_rgb[0].text = str(int(sliders_rgb[0].value))
			labels_rgb[1].text = str(int(sliders_rgb[1].value))
			labels_rgb[2].text = str(int(sliders_rgb[2].value))
			cp.color = nc
			bloqueando_sync[0] = false
			actualizar_ui_color.call(nc)
		)

	actualizar_ui_color.call(col_ini)

	for sw in paleta:
		var btn_sw := Button.new()
		btn_sw.text = sw["nombre"]
		btn_sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_sw.custom_minimum_size = Vector2(0, 68)
		btn_sw.add_theme_font_size_override("font_size", 20)
		var c_sw: Color = sw["color"]
		var txt_col := Color(0.08, 0.09, 0.10) if c_sw.get_luminance() > 0.52 else Color(0.95, 0.96, 0.98)
		btn_sw.add_theme_stylebox_override("normal", _crear_stylebox(c_sw, C_BORDER_FROST, 10, 1, 14, 8))
		btn_sw.add_theme_stylebox_override("hover", _crear_stylebox(c_sw, C_AMBER, 10, 3, 14, 8))
		btn_sw.add_theme_color_override("font_color", txt_col)
		btn_sw.pressed.connect(func():
			cp.color = c_sw
			actualizar_ui_color.call(c_sw)
		)
		grid_pal.add_child(btn_sw)

	cp.color_changed.connect(func(c: Color):
		actualizar_ui_color.call(c)
	)

	var btn_ok := Button.new()
	btn_ok.text = "✓ APLICAR COLOR"
	btn_ok.custom_minimum_size = Vector2(0, 66)
	btn_ok.add_theme_font_size_override("font_size", 24)
	_estilar_boton(btn_ok, true)
	btn_ok.pressed.connect(func():
		_modal_color.queue_free()
		_construir_contenido_tab()
	)
	vbox.add_child(btn_ok)

func _aleatorizar_casa() -> void:
	var presets := DatosCasaModular.obtener_presets()
	var base: Dictionary = presets[randi() % presets.size()]["config"].duplicate(true)
	var pal_f := DatosCasaModular.PALETA_COLORES_FACHADA
	var pal_a := DatosCasaModular.PALETA_COLORES_ACENTO
	base["ancho"] = snappedf(randf_range(6.5, 15.0), 0.5)
	base["fondo"] = snappedf(randf_range(6.0, 13.0), 0.5)
	base["pisos"] = randi_range(1, 4)
	base["color_fachada"] = "#" + pal_f[randi() % pal_f.size()]["color"].to_html(false)
	base["color_puerta"] = "#" + pal_a[randi() % pal_a.size()]["color"].to_html(false)
	base["color_ventanas"] = "#" + pal_a[randi() % pal_a.size()]["color"].to_html(false)
	_config = DatosCasaModular.normalizar_config(base)
	_zoom_factor = 1.0
	_reconstruir_preview_3d()
	_construir_contenido_tab()
