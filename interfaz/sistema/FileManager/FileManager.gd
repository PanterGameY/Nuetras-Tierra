extends Control

signal file_selected(path: String)

@export var start_path: String = "user://"

const FM_FONT := preload("res://recursos/fonts/Moderniz.otf")
var FOLDER_SVG: Texture2D = null
const CARD_WIDTH: int = 220
const CARD_SPACING: int = 16

var current_dir: String = ""
var items_paths: Array = []

var dialog: Panel
var files_scroll: ScrollContainer
var files_grid: GridContainer
var selected_path: String = ""
var selected_is_dir: bool = false
var preview: TextureRect
var path_label: LineEdit
var btn_up: Button
var btn_browse: Button
var btn_select: Button
var btn_close: Button
# External folder selection handled via the path LineEdit input

func _ready() -> void:
	current_dir = start_path
	_load_folder_icon()
	_build_ui()
	_populate_list()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_grid_columns()

func _update_grid_columns() -> void:
	if not files_grid or not files_scroll:
		return
	var avail: float = files_scroll.rect_size.x
	if avail <= 0:
		var parent := files_grid.get_parent()
		if parent:
			avail = parent.rect_size.x
	if avail <= 0:
		return
	var total := CARD_WIDTH + CARD_SPACING
	var cols := int((avail + CARD_SPACING) / total)
	if cols < 1:
		cols = 1
	files_grid.columns = cols

func _build_ui() -> void:
	var existing_dialog := get_node_or_null("FileManagerDialog")
	if existing_dialog and existing_dialog is Panel:
		dialog = existing_dialog as Panel
	else:
		dialog = Panel.new()
		dialog.name = "FileManagerDialog"
		# Make the panel fill the whole parent (fullscreen)
		dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dialog)
	dialog.visible = true

	# Background color (dark bluish-gray)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.04, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(bg)
	dialog.move_child(bg, 0)

	# Safe area with margins (so UI is not glued to edges)
	var safe_area := MarginContainer.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 22)
	safe_area.add_theme_constant_override("margin_top", 34)
	safe_area.add_theme_constant_override("margin_right", 22)
	safe_area.add_theme_constant_override("margin_bottom", 34)
	dialog.add_child(safe_area)

	# Main vertical layout that contains top bar and main content
	var content_v := VBoxContainer.new()
	content_v.name = "Content"
	content_v.custom_minimum_size = Vector2(920, 600)
	content_v.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	content_v.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	safe_area.add_child(content_v)

	# Top bar (PanelContainer with style similar to Perfil_Menu)
	var top_panel := PanelContainer.new()
	top_panel.custom_minimum_size = Vector2(0, 80)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.08, 0.14, 0.98)
	top_style.border_width_left = 3
	top_style.border_width_top = 3
	top_style.border_width_right = 3
	top_style.border_width_bottom = 3
	top_style.border_color = Color(0.22, 0.82, 1.0, 0.95)
	top_style.corner_radius_top_left = 18
	top_style.corner_radius_top_right = 18
	top_style.shadow_color = Color(0, 0, 0, 0.45)
	top_style.shadow_size = 18
	top_style.shadow_offset = Vector2(0, 12)
	top_panel.add_theme_stylebox_override("panel", top_style)
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 80)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	top_panel.add_child(top_bar)
	content_v.add_child(top_panel)

	btn_up = Button.new()
	btn_up.text = "⬆"
	btn_up.pressed.connect(Callable(self, "_on_up_pressed"))
	btn_up.custom_minimum_size = Vector2(96, 96)
	btn_up.add_theme_font_size_override("font_size", 42)
	btn_up.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	var btn_small_style := StyleBoxFlat.new()
	btn_small_style.bg_color = Color(0.12, 0.16, 0.22)
	btn_small_style.border_width_left = 2
	btn_small_style.border_width_top = 2
	btn_small_style.border_width_right = 2
	btn_small_style.border_width_bottom = 2
	btn_small_style.border_color = Color(0.35, 0.43, 0.52, 0.9)
	btn_small_style.corner_radius_top_left = 12
	btn_small_style.corner_radius_top_right = 12
	btn_small_style.corner_radius_bottom_right = 12
	btn_small_style.corner_radius_bottom_left = 12
	btn_up.add_theme_stylebox_override("normal", btn_small_style)
	btn_up.add_theme_stylebox_override("hover", btn_small_style)
	top_bar.add_child(btn_up)

	btn_browse = Button.new()
	btn_browse.text = "Abrir carpeta"
	btn_browse.pressed.connect(Callable(self, "_on_browse_focus"))
	btn_browse.add_theme_font_size_override("font_size", 22)
	btn_browse.add_theme_font_override("font", FM_FONT)
	top_bar.add_child(btn_browse)

	path_label = LineEdit.new()
	path_label.text = current_dir
	path_label.placeholder_text = "Pega o escribe una ruta externa y presiona Enter"
	path_label.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	path_label.add_theme_font_size_override("font_size", 30)
	path_label.add_theme_font_override("font", FM_FONT)
	path_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	path_label.connect("text_submitted", Callable(self, "_on_path_entered"))
	top_bar.add_child(path_label)
	top_bar.add_child(path_label)

	# try to set folder svg as a default icon (if loaded)
	if FOLDER_SVG:
		# no-op; it will be applied when populating
		pass

	# Main horizontal area (left: list, right: preview/actions)
	var main_h := HBoxContainer.new()
	main_h.custom_minimum_size = Vector2(900, 520)
	main_h.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	main_h.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	content_v.add_child(main_h)

	# Left panel (file list)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(520, 0)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	left_style.border_width_left = 2
	left_style.border_width_top = 2
	left_style.border_width_right = 2
	left_style.border_width_bottom = 2
	left_style.border_color = Color(0.19, 0.69, 0.96, 0.95)
	left_style.corner_radius_top_left = 18
	left_style.corner_radius_bottom_left = 18
	left_style.shadow_color = Color(0, 0, 0, 0.35)
	left_style.shadow_size = 12
	left_style.shadow_offset = Vector2(0, 8)
	left_panel.add_theme_stylebox_override("panel", left_style)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	main_h.add_child(left_panel)

	# Grid of tarjetas (cards) dentro de un ScrollContainer
	files_scroll = ScrollContainer.new()
	files_scroll.name = "FilesScroll"
	files_scroll.custom_minimum_size = Vector2(520, 0)
	files_scroll.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	files_scroll.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	# ScrollContainer gestiona el scroll automáticamente; no usar propiedades inexistentes
	left_panel.add_child(files_scroll)

	files_grid = GridContainer.new()
	files_grid.name = "FilesGrid"
	files_grid.columns = 3
	files_grid.custom_minimum_size = Vector2(520, 0)
	files_grid.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	files_grid.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	files_scroll.add_child(files_grid)

	# Right panel (preview + actions)
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(360, 0)
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.05, 0.07, 0.10, 0.98)
	right_style.border_width_left = 2
	right_style.border_width_top = 2
	right_style.border_width_right = 2
	right_style.border_width_bottom = 2
	right_style.border_color = Color(0.19, 0.69, 0.96, 0.95)
	right_style.corner_radius_top_right = 18
	right_style.corner_radius_bottom_right = 18
	right_style.shadow_color = Color(0, 0, 0, 0.35)
	right_style.shadow_size = 12
	right_style.shadow_offset = Vector2(0, 8)
	right_panel.add_theme_stylebox_override("panel", right_style)
	right_panel.size_flags_horizontal = Control.SIZE_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	main_h.add_child(right_panel)

	var right_v := VBoxContainer.new()
	right_v.custom_minimum_size = Vector2(360, 0)
	right_v.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	right_v.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	right_panel.add_child(right_v)

	preview = TextureRect.new()
	preview.expand = true
	preview.set("stretch_mode", 5)
	preview.custom_minimum_size = Vector2(0, 360)
	preview.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	# Give preview its own framed style
	var preview_frame := StyleBoxFlat.new()
	preview_frame.bg_color = Color(0.03, 0.04, 0.06)
	preview_frame.border_width_left = 2
	preview_frame.border_width_top = 2
	preview_frame.border_width_right = 2
	preview_frame.border_width_bottom = 2
	preview_frame.border_color = Color(0.22, 0.82, 1.0, 0.7)
	preview.add_theme_stylebox_override("frame", preview_frame)
	right_v.add_child(preview)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	right_v.add_child(actions)

	btn_select = Button.new()
	btn_select.text = "Seleccionar"
	btn_select.pressed.connect(Callable(self, "_on_select_pressed"))
	btn_select.add_theme_font_size_override("font_size", 30)
	btn_select.add_theme_font_override("font", FM_FONT)
	var save_style := StyleBoxFlat.new()
	save_style.bg_color = Color(0.0, 0.63, 0.86, 1)
	save_style.border_width_left = 2
	save_style.border_width_top = 2
	save_style.border_width_right = 2
	save_style.border_width_bottom = 2
	save_style.border_color = Color(0.64, 0.93, 1.0, 1.0)
	save_style.corner_radius_top_left = 18
	save_style.corner_radius_top_right = 18
	save_style.corner_radius_bottom_right = 18
	save_style.corner_radius_bottom_left = 18
	btn_select.add_theme_stylebox_override("normal", save_style)
	btn_select.add_theme_stylebox_override("hover", save_style)
	btn_select.add_theme_color_override("font_color", Color(0.03, 0.08, 0.12, 1))
	actions.add_child(btn_select)

	btn_close = Button.new()
	btn_close.text = "Cerrar"
	btn_close.pressed.connect(Callable(self, "_on_close_pressed"))
	btn_close.add_theme_font_size_override("font_size", 30)
	btn_close.add_theme_font_override("font", FM_FONT)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.14, 0.18, 0.24, 1)
	cancel_style.border_width_left = 2
	cancel_style.border_width_top = 2
	cancel_style.border_width_right = 2
	cancel_style.border_width_bottom = 2
	cancel_style.border_color = Color(0.35, 0.43, 0.52, 0.9)
	cancel_style.corner_radius_top_left = 18
	cancel_style.corner_radius_top_right = 18
	cancel_style.corner_radius_bottom_right = 18
	cancel_style.corner_radius_bottom_left = 18
	btn_close.add_theme_stylebox_override("normal", cancel_style)
	btn_close.add_theme_stylebox_override("hover", cancel_style)
	btn_close.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	actions.add_child(btn_close)

	btn_up.add_theme_font_size_override("font_size", 42)
	path_label.add_theme_font_size_override("font_size", 30)
	path_label.add_theme_font_override("font", FM_FONT)

func _populate_list() -> void:
	items_paths.clear()
	path_label.text = current_dir

	# limpiar grid
	if files_grid:
		for child in files_grid.get_children():
			child.queue_free()

	var dir_path := _resolve_path(current_dir)
	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		push_warning("FileManager: no se pudo abrir directorio: %s (resuelto: %s)" % [current_dir, dir_path])
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	var entries: Array = []
	while entry_name != "":
		if entry_name in [".", ".."]:
			entry_name = dir.get_next()
			continue
		var is_dir: bool = dir.current_is_dir()
		entries.append([entry_name, is_dir])
		entry_name = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(Callable(self, "_entry_sort"))
	for pair in entries:
		var display: String = pair[0]
		var resource_path: String = _join_path(current_dir, pair[0])
		if pair[1]:
			display = "%s/" % display

		# crear tarjeta
		var card_btn: Button = Button.new()
		card_btn.flat = true
		card_btn.custom_minimum_size = Vector2(220, 260)
		card_btn.focus_mode = Control.FOCUS_NONE

		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.09, 0.12)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color(0.15, 0.45, 0.7)
		card_style.corner_radius_top_left = 12
		card_style.corner_radius_top_right = 12
		card_style.corner_radius_bottom_right = 12
		card_style.corner_radius_bottom_left = 12
		card_btn.add_theme_stylebox_override("normal", card_style)

		var card_hover: StyleBoxFlat = StyleBoxFlat.new()
		card_hover.bg_color = Color(0.08, 0.12, 0.16)
		card_hover.border_color = Color(0.22, 0.62, 0.96)
		card_hover.corner_radius_top_left = 12
		card_hover.corner_radius_top_right = 12
		card_hover.corner_radius_bottom_right = 12
		card_hover.corner_radius_bottom_left = 12
		card_btn.add_theme_stylebox_override("hover", card_hover)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(220, 260)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL

		var thumb: TextureRect = TextureRect.new()
		thumb.name = "Thumb"
		thumb.expand = true
		thumb.set("stretch_mode", 5)
		thumb.custom_minimum_size = Vector2(220, 180)
		vbox.add_child(thumb)

		var name_label: Label = Label.new()
		name_label.text = display
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_font_override("font", FM_FONT)
		name_label.custom_minimum_size = Vector2(220, 64)
		vbox.add_child(name_label)

		card_btn.add_child(vbox)
		card_btn.pressed.connect(Callable(self, "_on_card_pressed").bind(resource_path, pair[1]))
		card_btn.mouse_entered.connect(Callable(self, "_on_card_hovered").bind(resource_path, pair[1]))

		# generar miniatura
		if pair[1]:
			# Usar SVG de carpeta si existe, sino fallback a placeholder
			if FOLDER_SVG:
				thumb.texture = FOLDER_SVG
			else:
				var ph: Image = Image.create(220, 160, false, Image.FORMAT_RGBA8)
				ph.fill(Color(0.06, 0.12, 0.20))
				var ph_tex: ImageTexture = ImageTexture.create_from_image(ph)
				thumb.texture = ph_tex
		else:
			var fs_path: String = _resolve_path(resource_path)
			var thumb_img: Image = Image.new()
			if thumb_img.load(fs_path) == OK:
				thumb_img.resize(220, 160, Image.INTERPOLATE_BILINEAR)
				var thumb_tex: ImageTexture = ImageTexture.create_from_image(thumb_img)
				thumb.texture = thumb_tex
			else:
				var ph2: Image = Image.create(220, 160, false, Image.FORMAT_RGBA8)
				ph2.fill(Color(0.06, 0.12, 0.20))
				thumb.texture = ImageTexture.create_from_image(ph2)

		files_grid.add_child(card_btn)
		items_paths.append(resource_path)

func _entry_sort(a, b) -> int:
	var a_dir: bool = a[1]
	var b_dir: bool = b[1]
	if a_dir and not b_dir:
		return -1
	if b_dir and not a_dir:
		return 1
	var a_str: String = a[0].to_lower()
	var b_str: String = b[0].to_lower()
	if a_str < b_str:
		return -1
	if a_str > b_str:
		return 1
	return 0

func _join_path(base: String, child: String) -> String:
	if base == "" or base == ".":
		return child
	if base.ends_with("/"):
		return "%s%s" % [base, child]
	return "%s/%s" % [base, child]


func _resolve_path(p: String) -> String:
	# Normalize path input to a filesystem path. Supports res:// and user:// virtual paths.
	var s: String = str(p).strip_edges()
	if s == "":
		return ProjectSettings.globalize_path("user://")
	if s.begins_with("res://") or s.begins_with("user://"):
		return ProjectSettings.globalize_path(s)
	# Normalize backslashes to forward slashes for consistency
	s = s.replace("\\", "/")
	# Expand ~ to user home if present
	if s.begins_with("~"):
		var home := ""
		if OS.has_environment("USERPROFILE"):
			home = OS.get_environment("USERPROFILE")
		elif OS.has_environment("HOME"):
			home = OS.get_environment("HOME")
		if home != "":
			s = home + s.substr(1)
	return s

func _on_card_hovered(path: String, is_dir: bool) -> void:
	selected_path = path
	selected_is_dir = is_dir
	if is_dir:
		preview.texture = null
		return
	# If resource inside project, try loading via ResourceLoader first
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var tex_res = load(path)
		if tex_res and tex_res is Texture2D:
			preview.texture = tex_res
			return
	# Otherwise resolve filesystem path and try load as image file
	var fs_path: String = _resolve_path(path)
	var img: Image = Image.new()
	if img.load(fs_path) == OK:
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		preview.texture = tex
	else:
		preview.texture = null

func _on_card_pressed(path: String, is_dir: bool) -> void:
	if is_dir:
		current_dir = path
		_populate_list()
		return
	emit_signal("file_selected", path)
	queue_free()

func _on_up_pressed() -> void:
	var parent: String = current_dir.get_base_dir()
	if parent == current_dir or parent.strip_edges() == "":
		return
	current_dir = parent
	_populate_list()

func _on_select_pressed() -> void:
	if selected_path == "":
		return
	if selected_is_dir:
		current_dir = selected_path
		_populate_list()
		return
	emit_signal("file_selected", selected_path)
	queue_free()

func _on_close_pressed() -> void:
	queue_free()


func _on_browse_focus() -> void:
	if path_label:
		path_label.grab_focus()
		path_label.select_all()


func _on_path_entered(text: String) -> void:
	var trimmed := str(text).strip_edges()
	if trimmed == "":
		return
	# Accept both 'user://' or 'res://' virtual paths and absolute system paths
	current_dir = trimmed
	_populate_list()


func _load_folder_icon() -> void:
	# Load carpeta.svg at runtime; fallback to carpeta.png if SVG importer isn't available
	var svg_path := "res://recursos/botones/carpeta.svg"
	if ResourceLoader.exists(svg_path):
		var r := ResourceLoader.load(svg_path)
		if r and r is Texture2D:
			FOLDER_SVG = r
			return
		# Some setups may import svg as Image
		if r and r is Image:
			FOLDER_SVG = ImageTexture.create_from_image(r)
			return
	var png_path := "res://recursos/botones/carpeta.png"
	if ResourceLoader.exists(png_path):
		var p := ResourceLoader.load(png_path)
		if p and p is Texture2D:
			FOLDER_SVG = p
			return
