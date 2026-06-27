extends Control

const ESCENA_MAIN_MENU := "res://escenas/main menu/Main-Menu.tscn"

@onready var btn_cerrar_sesion: Button = $BtnCerrarSesion
@onready var btn_home: Button = get_node_or_null("BtnHome") as Button
@onready var btn_nick: Button = get_node_or_null("Control/HBoxContainer/BtnNick") as Button
@onready var label_nombre: Label = $Control/PerfilUsuario/InputFalso/labelnombre
@onready var btn_avatar: Button = get_node_or_null("Control/HBoxContainer/BtnAvatar") as Button

var _avatar_file_dialog: FileDialog = null
@export var force_filemanager_on_android: bool = false

var _nick_modal_overlay: ColorRect = null
var _nick_modal_panel: PanelContainer = null
var _nick_modal_input: LineEdit = null
var _nick_modal_hint: Label = null

func _ready() -> void:
	if btn_cerrar_sesion:
		btn_cerrar_sesion.pressed.connect(_on_cerrar_sesion_pressed)
	if btn_home:
		btn_home.pressed.connect(_on_btn_home_pressed)
	if btn_nick:
		btn_nick.pressed.connect(_on_btn_nick_pressed)
	if btn_avatar:
		btn_avatar.pressed.connect(_on_btn_avatar_pressed)
	_crear_modal_nick()
	_configurar_label_nombre()
	_actualizar_label_nombre()
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		var cb_nombre := Callable(self, "_on_nombre_usuario_cambiado")
		if not datos.is_connected("nombre_usuario_cambiado", cb_nombre):
			datos.connect("nombre_usuario_cambiado", cb_nombre)


func _configurar_label_nombre() -> void:
	if not label_nombre:
		return
	label_nombre.clip_text = true
	label_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _actualizar_label_nombre() -> void:
	if not label_nombre:
		return
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and datos.nombre_usuario != "":
		label_nombre.text = datos.nombre_usuario


func _on_nombre_usuario_cambiado(new_name: String) -> void:
	if label_nombre:
		label_nombre.text = new_name


func _on_btn_nick_pressed() -> void:
	if not _nick_modal_overlay or not _nick_modal_input or not label_nombre:
		return
	_nick_modal_overlay.visible = true
	_nick_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_nick_modal_overlay.modulate = Color(1, 1, 1, 0)
	_nick_modal_panel.scale = Vector2(0.92, 0.92)
	_nick_modal_input.text = label_nombre.text
	_nick_modal_input.placeholder_text = "Escribe tu nuevo nombre"
	_actualizar_hint_modal_nick("3 a 20 caracteres. Sin simbolos raros.", Color(0.75, 0.9, 1.0, 0.95))
	_nick_modal_input.grab_focus()
	_nick_modal_input.select_all()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_nick_modal_overlay, "modulate", Color(1, 1, 1, 1), 0.18)
	tween.tween_property(_nick_modal_panel, "scale", Vector2.ONE, 0.18)


func _sanitizar_nombre_usuario(input: String) -> String:
	var cleaned := input.strip_edges()
	var forbidden := ["\n", "\r", "\t", "<", ">", "/", "\\", ":", ";", "{", "}", "(", ")", "*", "?", "$", "%", "`", "|", "&", "~", "^"]
	var safe_name := ""
	for character in cleaned:
		if forbidden.has(character):
			continue
		safe_name += character
	safe_name = safe_name.strip_edges()
	if safe_name.length() > 20:
		safe_name = safe_name.substr(0, 20)
	return safe_name


func _crear_modal_nick() -> void:
	if _nick_modal_overlay:
		return
	var overlay := ColorRect.new()
	overlay.name = "NickModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.03, 0.07, 0.8)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 22)
	safe_area.add_theme_constant_override("margin_top", 34)
	safe_area.add_theme_constant_override("margin_right", 22)
	# Dejamos una franja inferior amplia para que el teclado movil no tape el modal.
	safe_area.add_theme_constant_override("margin_bottom", 320)

	var top_host := VBoxContainer.new()
	top_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_host.alignment = BoxContainer.ALIGNMENT_CENTER
	top_host.add_theme_constant_override("separation", 0)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 24)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 320)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.08, 0.14, 0.97)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.22, 0.82, 1.0, 0.95)
	panel_style.corner_radius_top_left = 26
	panel_style.corner_radius_top_right = 26
	panel_style.corner_radius_bottom_right = 26
	panel_style.corner_radius_bottom_left = 26
	panel_style.shadow_color = Color(0, 0, 0, 0.45)
	panel_style.shadow_size = 22
	panel_style.shadow_offset = Vector2(0, 12)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)

	var title := Label.new()
	title.text = "EDITAR NICKNAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(0.92, 0.98, 1.0, 1)

	var subtitle := Label.new()
	subtitle.text = "Elige un nombre corto, limpio y facil de reconocer."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(0.72, 0.86, 0.96, 0.92)

	var input := LineEdit.new()
	input.custom_minimum_size = Vector2(0, 58)
	input.placeholder_text = "Escribe tu nuevo nombre"
	input.max_length = 20
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 24)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.08, 0.12, 0.18, 0.98)
	input_style.border_width_left = 2
	input_style.border_width_top = 2
	input_style.border_width_right = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(0.19, 0.69, 0.96, 0.95)
	input_style.corner_radius_top_left = 18
	input_style.corner_radius_top_right = 18
	input_style.corner_radius_bottom_right = 18
	input_style.corner_radius_bottom_left = 18
	input.add_theme_stylebox_override("normal", input_style)
	input.add_theme_stylebox_override("focus", input_style)
	input.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	input.add_theme_color_override("caret_color", Color(0.35, 0.88, 1.0, 1.0))

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(0.75, 0.9, 1.0, 0.95)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)

	var cancel_button := Button.new()
	cancel_button.text = "CANCELAR"
	cancel_button.custom_minimum_size = Vector2(180, 52)
	cancel_button.add_theme_font_size_override("font_size", 18)
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
	cancel_button.add_theme_stylebox_override("normal", cancel_style)
	cancel_button.add_theme_stylebox_override("hover", cancel_style)

	var save_button := Button.new()
	save_button.text = "GUARDAR"
	save_button.custom_minimum_size = Vector2(200, 52)
	save_button.add_theme_font_size_override("font_size", 18)
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
	save_button.add_theme_stylebox_override("normal", save_style)
	save_button.add_theme_stylebox_override("hover", save_style)
	save_button.add_theme_color_override("font_color", Color(0.03, 0.08, 0.12, 1))

	var themed_font = null
	if label_nombre:
		themed_font = label_nombre.get("theme_override_fonts/font")
	if themed_font != null:
		title.add_theme_font_override("font", themed_font)
		subtitle.add_theme_font_override("font", themed_font)
		input.add_theme_font_override("font", themed_font)
		hint.add_theme_font_override("font", themed_font)
		cancel_button.add_theme_font_override("font", themed_font)
		save_button.add_theme_font_override("font", themed_font)

	buttons.add_child(cancel_button)
	buttons.add_child(save_button)
	content.add_child(title)
	content.add_child(subtitle)
	content.add_child(input)
	content.add_child(hint)
	content.add_child(buttons)
	margin.add_child(content)
	panel.add_child(margin)
	top_host.add_child(top_spacer)
	top_host.add_child(panel)
	safe_area.add_child(top_host)
	overlay.add_child(safe_area)
	add_child(overlay)
	move_child(overlay, -1)

	_nick_modal_overlay = overlay
	_nick_modal_panel = panel
	_nick_modal_input = input
	_nick_modal_hint = hint

	cancel_button.pressed.connect(_cerrar_modal_nick)
	save_button.pressed.connect(_confirmar_modal_nick)
	input.text_submitted.connect(_on_modal_nick_submitted)
	input.gui_input.connect(_on_modal_nick_gui_input)


func _actualizar_hint_modal_nick(message: String, color: Color) -> void:
	if not _nick_modal_hint:
		return
	_nick_modal_hint.text = message
	_nick_modal_hint.modulate = color


func _cerrar_modal_nick() -> void:
	if not _nick_modal_overlay:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_nick_modal_overlay, "modulate", Color(1, 1, 1, 0), 0.16)
	tween.tween_property(_nick_modal_panel, "scale", Vector2(0.94, 0.94), 0.16)
	await tween.finished
	if _nick_modal_overlay:
		_nick_modal_overlay.visible = false


func _confirmar_modal_nick() -> void:
	if not _nick_modal_input:
		return
	var nuevo_nombre := _sanitizar_nombre_usuario(_nick_modal_input.text)
	if nuevo_nombre.length() < 3:
		_actualizar_hint_modal_nick("El nickname debe tener minimo 3 caracteres.", Color(1.0, 0.48, 0.48, 1.0))
		_nick_modal_input.grab_focus()
		return
	if label_nombre:
		label_nombre.text = nuevo_nombre
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		if datos.has_method("set_nombre_usuario"):
			datos.set_nombre_usuario(nuevo_nombre, true)
		else:
			datos.nombre_usuario = nuevo_nombre
			if datos.has_method("save_local"):
				datos.save_local()
	_actualizar_hint_modal_nick("Nickname actualizado correctamente.", Color(0.58, 1.0, 0.78, 1.0))
	await get_tree().create_timer(0.22).timeout
	_cerrar_modal_nick()


func _on_modal_nick_submitted(_new_text: String) -> void:
	_confirmar_modal_nick()


func _on_modal_nick_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cerrar_modal_nick()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_confirmar_modal_nick()


func _on_btn_home_pressed() -> void:
	if ResourceLoader.exists(ESCENA_MAIN_MENU):
		get_tree().change_scene_to_file(ESCENA_MAIN_MENU)


func _on_btn_avatar_pressed() -> void:
	# Intentar cargar y abrir primero la escena FileManager (funciona en desktop y también si está disponible en Android).
	print("[PerfilMenu] _on_btn_avatar_pressed called - OS=", OS.get_name(), " force_filemanager_on_android=", force_filemanager_on_android)
	var scene: PackedScene = load("res://escenas/gui/FileManager/FileManager.tscn") as PackedScene
	print("[PerfilMenu] load FileManager.tscn ->", scene)
	if scene:
		print("[PerfilMenu] instantiating FileManager scene")
		var fm: Control = scene.instantiate() as Control
		print("[PerfilMenu] instantiate returned ->", fm)
		# Iniciar en carpeta de usuario por defecto (asignar antes de añadir a la escena)
		var fm_script: GDScript = fm.get_script() as GDScript
		if fm_script:
			for prop in fm_script.get_script_property_list():
				if prop.name == "start_path":
					# Prefer opening system user folder by default so users can pick external files
					var default_path := "user://"
					var os_name := OS.get_name()
					if os_name == "Windows":
						if OS.has_environment("USERPROFILE"):
							default_path = OS.get_environment("USERPROFILE").replace("\\", "/")
						else:
							default_path = "C:/"
					elif os_name == "Android":
						# Common external storage paths on Android
						var _d := DirAccess.open("/sdcard")
						if _d:
							_d.close()
							default_path = "/sdcard"
						else:
							var _d2 := DirAccess.open("/storage/emulated/0")
							if _d2:
								_d2.close()
								default_path = "/storage/emulated/0"
							else:
								default_path = "/"
					else:
						if OS.has_environment("HOME"):
							default_path = OS.get_environment("HOME")
						else:
							default_path = "/"
					fm.start_path = default_path
					break
		# Añadir el gestor a la escena
		if fm:
			add_child(fm)
			# mover al frente para asegurar visibilidad
			move_child(fm, -1)
			fm.visible = true
			if fm and fm is Control:
				fm.set_anchors_preset(Control.PRESET_FULL_RECT)
			fm.connect("file_selected", Callable(self, "_on_avatar_file_selected"))
			print("[PerfilMenu] FileManager added to scene tree")
			return
		else:
			print("[PerfilMenu] instantiate returned null, will fallback to FileDialog")

	# Si la escena no existe o no pudo cargarse, usar FileDialog (en Android aprovecha SAF)
	if OS.get_name() == "Android" and not force_filemanager_on_android:
		if _avatar_file_dialog == null:
			_avatar_file_dialog = FileDialog.new()
			_avatar_file_dialog.name = "PerfilAvatarFileDialog"
			_avatar_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			_avatar_file_dialog.add_filter("*.png ; *.jpg ; *.jpeg ; *.webp ; *.bmp")
			_avatar_file_dialog.connect("file_selected", Callable(self, "_on_avatar_file_selected"))
			add_child(_avatar_file_dialog)
			if _avatar_file_dialog.has_method("popup_centered"):
				_avatar_file_dialog.popup_centered()
			else:
				_avatar_file_dialog.popup()
		return

	# Fallback general
	if _avatar_file_dialog == null:
		_avatar_file_dialog = FileDialog.new()
		_avatar_file_dialog.name = "PerfilAvatarFileDialog"
		_avatar_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_avatar_file_dialog.add_filter("*.png ; *.jpg ; *.jpeg ; *.webp ; *.bmp")
		_avatar_file_dialog.connect("file_selected", Callable(self, "_on_avatar_file_selected"))
		add_child(_avatar_file_dialog)
		if _avatar_file_dialog.has_method("popup_centered"):
			_avatar_file_dialog.popup_centered()
		else:
			_avatar_file_dialog.popup()


func _on_avatar_file_selected(path: String) -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	var resolved_src := path
	if path.begins_with("res://") or path.begins_with("user://"):
		resolved_src = ProjectSettings.globalize_path(path)

	var img: Image = Image.new()
	var err: int = img.load(resolved_src)
	if err != OK:
		push_warning("PerfilMenu: no se pudo cargar imagen: %s (resuelto: %s)" % [path, resolved_src])
		return

	var _tex: ImageTexture = ImageTexture.create_from_image(img)

	# Guardar solo localmente: copiar a user://avatars cuando venga del sistema de archivos
	if not path.begins_with("res://"):
		var avatars_dir_fs := ProjectSettings.globalize_path("user://avatars")
		DirAccess.make_dir_recursive_absolute(avatars_dir_fs)
		var ext: String = path.get_extension()
		var dest: String = "user://avatars/avatar_%d.%s" % [Time.get_unix_time_from_system(), ext]
		var dest_fs := ProjectSettings.globalize_path(dest)
		var src: FileAccess = FileAccess.open(resolved_src, FileAccess.READ)
		if src:
			var data: PackedByteArray = src.get_buffer(src.get_length())
			src.close()
			var dst: FileAccess = FileAccess.open(dest_fs, FileAccess.WRITE)
			if dst:
				dst.store_buffer(data)
				dst.close()
				if datos:
					if datos.has_method("set_avatar_texture"):
						datos.set_avatar_texture(_tex, true)
					else:
						datos.avatar_texture = _tex
						datos.avatar_path = dest
						if datos.has_method("save_local"):
							datos.save_local()
					# Emitir señal para que otros nodos actualicen si escuchan
					datos.emit_signal("avatar_cambiada", datos.avatar_texture)
			else:
				push_warning("PerfilMenu: no se pudo escribir avatar en: %s" % dest_fs)
		else:
			push_warning("PerfilMenu: no se pudo leer archivo: %s" % resolved_src)
	else:
		# recurso en res:// — usar directamente
		if ResourceLoader.exists(path):
			var loaded: Texture2D = load(path) as Texture2D
			if datos and datos.has_method("set_avatar_texture"):
				datos.set_avatar_texture(loaded, true)
			elif datos:
				datos.avatar_texture = loaded
				datos.avatar_path = path
				if datos.has_method("save_local"):
					datos.save_local()
			if datos:
				datos.emit_signal("avatar_cambiada", datos.avatar_texture)

	# Actualizar UI local del avatar si existe en esta escena
	var avatar_node = get_node_or_null("Control/PerfilUsuario/Avatar")
	var datos_local = get_node_or_null("/root/DatosUsuario")
	if avatar_node and datos_local:
		if datos_local.avatar_texture != null:
			avatar_node.texture = datos_local.avatar_texture
		elif datos_local.avatar_path != "":
			var rp: String = datos_local.avatar_path
			var resolved: String = rp
			if rp.begins_with("res://") or rp.begins_with("user://"):
				resolved = ProjectSettings.globalize_path(rp)
			var img2: Image = Image.new()
			if img2.load(resolved) == OK:
				avatar_node.texture = ImageTexture.create_from_image(img2)
			else:
				push_warning("PerfilMenu: no se pudo cargar recurso desde:%s (resuelto:%s)" % [rp, resolved])


func _get_auth_backend_for_sign_out() -> Dictionary:
	var firebase_root = get_node_or_null("/root/Firebase")
	if firebase_root and firebase_root.auth:
		return {
			"backend": firebase_root,
			"auth": firebase_root.auth,
		}
	if Engine.has_singleton("GodotFirebaseAndroid"):
		var native = Engine.get_singleton("GodotFirebaseAndroid")
		return {
			"backend": native,
			"auth": native,
		}
	return {
		"backend": null,
		"auth": null,
	}


func _is_auth_session_open(auth_backend: Object) -> bool:
	if not auth_backend:
		return false
	if auth_backend.has_method("is_signed_in"):
		return auth_backend.is_signed_in()
	if auth_backend.has_method("isSignedIn"):
		return auth_backend.isSignedIn()
	return false


func _wait_until_signed_out(auth_backend: Object, attempts: int = 12, delay_seconds: float = 0.2) -> bool:
	for _i in range(attempts):
		if not _is_auth_session_open(auth_backend):
			return true
		await get_tree().create_timer(delay_seconds).timeout
	return not _is_auth_session_open(auth_backend)

func _on_cerrar_sesion_pressed() -> void:
	print("[PerfilMenu] Cerrando sesión y borrando datos persistentes.")

	# 2. Cerrar sesión en Firebase
	var auth_context := _get_auth_backend_for_sign_out()
	var auth_backend: Object = auth_context.get("auth", null)
	var sign_out_requested := false
	if auth_backend:
		if auth_backend.has_method("sign_out"):
			auth_backend.sign_out()
			sign_out_requested = true
		elif auth_backend.has_method("signOut"):
			auth_backend.signOut()
			sign_out_requested = true

	if not sign_out_requested:
		printerr("[PerfilMenu] No se pudo iniciar el cierre de sesión.")
		return

	var signed_out := await _wait_until_signed_out(auth_backend)
	print("[PerfilMenu] Estado signed in después de sign out:", not signed_out)
	if not signed_out:
		printerr("[PerfilMenu] La sesión sigue activa. No se cambió de escena.")
		return

	# 4. Borrar datos de DatosUsuario cuando el backend ya procesó el sign out
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		if datos.has_method("clear_session"):
			datos.clear_session(true)
		else:
			datos.id_usuario = ""
			datos.firebase_uid = ""
			datos.nombre_usuario = ""
			if "next_scene" in datos:
				datos.next_scene = ""
			if datos.has_method("save_local"):
				datos.save_local()
		print("[PerfilMenu] Archivo de persistencia limpiado.")
	
	# 5. Volver al Login
	get_tree().change_scene_to_file("res://escenas/gui/Login/Login.tscn")
