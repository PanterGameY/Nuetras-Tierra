extends Control

signal volver_pressed()

const C_BG          := Color(0.96, 0.97, 0.99, 1.0)
const C_SURFACE     := Color.WHITE
const C_BORDER      := Color(0.88, 0.90, 0.94)
const C_TEXT        := Color(0.08, 0.08, 0.12)
const C_TEXT_DIM    := Color(0.48, 0.50, 0.58)
const C_ACCENT      := Color(0.12, 0.45, 0.92, 1.00)
const C_GREEN       := Color(0.14, 0.85, 0.45, 1.00)
const C_YELLOW      := Color(1.00, 0.78, 0.10, 1.00)

var _font: FontFile = null
var _list_vbox: VBoxContainer = null

func _ready() -> void:
	_font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	var bg_panel = Panel.new()
	bg_panel.name = "BGPanel"
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.06, 0.10, 0.96)
	bg_style.border_width_left = 3
	bg_style.border_width_top = 3
	bg_style.border_width_right = 3
	bg_style.border_width_bottom = 3
	bg_style.border_color = Color(0.20, 0.60, 1.00, 0.45)
	bg_style.corner_radius_top_left = 20
	bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20
	bg_style.corner_radius_bottom_right = 20
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	var root = VBoxContainer.new()
	root.name = "RootVBox"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(root)

	var header_margin = MarginContainer.new()
	header_margin.custom_minimum_size = Vector2(0, 70)
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_right", 20)
	header_margin.add_theme_constant_override("margin_top", 15)
	root.add_child(header_margin)

	var header_hbox = HBoxContainer.new()
	header_margin.add_child(header_hbox)

	var back_btn = Button.new()
	back_btn.text = "< Volver"
	back_btn.flat = true
	back_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _font:
		back_btn.add_theme_font_override("font", _font)
	back_btn.add_theme_font_size_override("font_size", 32)
	back_btn.add_theme_color_override("font_color", Color(0.20, 0.60, 1.00))
	back_btn.pressed.connect(func(): emit_signal("volver_pressed"))
	header_hbox.add_child(back_btn)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var title_lbl = Label.new()
	title_lbl.text = "MISIONES Y LICENCIAS"
	if _font:
		title_lbl.add_theme_font_override("font", _font)
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	header_hbox.add_child(title_lbl)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer2)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 20)
	scroll_margin.add_theme_constant_override("margin_right", 20)
	scroll_margin.add_theme_constant_override("margin_bottom", 20)
	root.add_child(scroll_margin)
	scroll_margin.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(list_vbox)
	_list_vbox = list_vbox

	_populate_missions(list_vbox)

func actualizar_lista() -> void:
	if _list_vbox:
		_populate_missions(_list_vbox)

func _populate_missions(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

	var coord_academia := Vector3(12.0, 0.0, 80.0)
	var coord_mensajero := Vector3(45.0, 0.0, 20.0)

	# Licencia C1 (Tutorial inicial disfrazado de examen de conducción — gratuito y sin penalización de intentos)
	var tiene_c1: bool = DatosUsuario.tiene_licencia("C1") if (DatosUsuario and DatosUsuario.has_method("tiene_licencia")) else false
	container.add_child(_create_mission_card(
		"Examen Licencia C1 — Camionetas y Livianos (Tutorial)",
		"Aprende los controles del vehículo en una prueba práctica guiada en la Academia Automovilística (encendido, luces, cambios, frenado y parqueo). Exenta de cobro e intentos ilimitados.",
		"Desbloquea Licencia C1 (Camionetas) + 100 EXP",
		tiene_c1,
		coord_academia
	))

	# Licencia C2 (Camión Rígido)
	var tiene_c2: bool = DatosUsuario.tiene_licencia("C2") if (DatosUsuario and DatosUsuario.has_method("tiene_licencia")) else false
	container.add_child(_create_mission_card(
		"Examen Licencia C2 — Camión Rígido",
		"Dirígete a la Academia Automovilística. Costo de prueba: $ 450.000 (tienes 3 intentos para aprobar; si repruebas se te devuelve el 50%: $ 225.000).",
		"Desbloquea Camiones Rígidos + 150 EXP",
		tiene_c2,
		coord_academia
	))

	# Licencia C3 (Tractomula)
	var tiene_c3: bool = DatosUsuario.tiene_licencia("C3") if (DatosUsuario and DatosUsuario.has_method("tiene_licencia")) else false
	container.add_child(_create_mission_card(
		"Examen Licencia C3 — Tractomula Pesada",
		"Prueba maestra de maniobra con tráiler en la Academia Automovilística. Costo de prueba: $ 1.100.000 (3 intentos; devolución del 50% si repruebas: $ 550.000).",
		"Desbloquea Tractomulas C3 + 300 EXP",
		tiene_c3,
		coord_academia
	))

	# Misión: Reparto Inicial
	var completada_rep: bool = DatosUsuario.mision_reparto_completada if DatosUsuario else false
	container.add_child(_create_mission_card(
		"Reparto Urbano Inicial",
		"Interactúa con el jefe de logística en la base de mensajería y completa tu primera ruta de entrega de paquetes.",
		"Pago $ 180.000 + Reputación",
		completada_rep,
		coord_mensajero
	))

func _create_mission_card(title: String, desc: String, reward: String, completed: bool, gps_target: Vector3) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.19, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.55, 0.95, 0.30)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	var title_hbox = HBoxContainer.new()
	vbox.add_child(title_hbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	if _font:
		title_lbl.add_theme_font_override("font", _font)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_lbl)

	var badge = Label.new()
	var badge_style = StyleBoxFlat.new()
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	badge_style.corner_radius_top_left = 6
	badge_style.corner_radius_top_right = 6
	badge_style.corner_radius_bottom_left = 6
	badge_style.corner_radius_bottom_right = 6

	if completed:
		badge.text = "APROBADA"
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge_style.bg_color = Color(0.14, 0.78, 0.42, 0.9)
	else:
		badge.text = "DISPONIBLE"
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge_style.bg_color = Color(0.15, 0.45, 0.90, 0.9)

	badge.add_theme_stylebox_override("normal", badge_style)
	if _font:
		badge.add_theme_font_override("font", _font)
	badge.add_theme_font_size_override("font_size", 20)
	title_hbox.add_child(badge)

	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(sep)

	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	vbox.add_child(desc_lbl)

	var reward_lbl = Label.new()
	reward_lbl.text = "🎁 Beneficio: " + reward
	if _font:
		reward_lbl.add_theme_font_override("font", _font)
	reward_lbl.add_theme_font_size_override("font_size", 22)
	reward_lbl.add_theme_color_override("font_color", Color(0.35, 0.75, 1.00))
	vbox.add_child(reward_lbl)

	if not completed:
		var track_btn = Button.new()
		track_btn.text = "📍 Marcar Ruta en GPS"
		var t_style = StyleBoxFlat.new()
		t_style.bg_color = Color(0.12, 0.42, 0.85, 0.95)
		t_style.corner_radius_top_left = 10
		t_style.corner_radius_top_right = 10
		t_style.corner_radius_bottom_left = 10
		t_style.corner_radius_bottom_right = 10
		t_style.content_margin_top = 8
		t_style.content_margin_bottom = 8
		track_btn.add_theme_stylebox_override("normal", t_style)
		if _font:
			track_btn.add_theme_font_override("font", _font)
		track_btn.add_theme_font_size_override("font_size", 22)
		track_btn.add_theme_color_override("font_color", Color.WHITE)
		track_btn.pressed.connect(func():
			var target_pos = gps_target
			var nodes = get_tree().get_nodes_in_group("AcademiaSpawnPoint")
			if nodes.size() > 0 and title.contains("Licencia"):
				target_pos = nodes[0].global_position
			if CelularUI.instance:
				CelularUI.instance.notificar("Ruta establecida en GPS 📍", "info")
				var gps_line = CelularUI.instance.get("gps_line")
				if gps_line and gps_line.has_method("set_destination"):
					gps_line.call("set_destination", target_pos)
				CelularUI.instance.call("_switch_app", "waze")
		)
		vbox.add_child(track_btn)

	return card
