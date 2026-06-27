extends Control

# Referencias a los nodos mediante su ruta en la jerarquía
@onready var label_name = $LayoutPrincipal/HeaderCard/CardPanel/PaddingInterior/Content/InfoVBox/NameHBox/LabelName
@onready var status_label = $LayoutPrincipal/HeaderCard/CardPanel/PaddingInterior/Content/InfoVBox/LabelStatus
@onready var btn_volver = $Button

# Referencias a los botones del menú
@onready var grid_botones = $LayoutPrincipal/GridBotones
var default_status_text: String = ""
var default_status_color: Color = Color(1, 1, 1, 1)
var default_status_font_size: int = 30
@export var warning_sound: AudioStream = null
@export var blink_interval: float = 0.5
@export var warning_volume_db: float = 0.0
@export var warning_auto_clear_seconds: float = 5.0
@export var success_sound: AudioStream = null
@export var success_volume_db: float = 0.0
@export var min_status_font_size: int = 29
var _warning_timer: Timer = null
var _warning_audio: AudioStreamPlayer = null
var _success_audio: AudioStreamPlayer = null
var is_warning_active: bool = false
var default_status_modulate: Color = Color(1, 1, 1, 1)
var _blink_state: bool = false
var _warning_auto_timer: Timer = null
var _btn_editar_nombre: Button = null

func _ready():
	# Conectar señales de los botones del menú de forma automática
	for boton in grid_botones.get_children():
		if boton is Button:
			boton.pressed.connect(_on_menu_button_pressed.bind(boton.name))
			# Efecto de sonido sutil al pasar el ratón (opcional)
			boton.mouse_entered.connect(_on_button_hover)

	# Conectar botón de editar nombre, soportando ambos nombres de nodo.
	_btn_editar_nombre = _find_name_edit_button()
	if _btn_editar_nombre:
		_btn_editar_nombre.pressed.connect(_on_btn_editar_pressed)
	else:
		print("[Perfil][WARN] No se encontró BtnNick ni BtnEditar para cambiar el nombre")

	# Conectar botón volver al MainMenu
	if btn_volver:
		btn_volver.pressed.connect(_on_btn_volver_pressed)
		print("[Perfil][DEBUG] btn_volver conectado a MainMenu")
	else:
		print("[Perfil][WARN] btn_volver no encontrado en Perfil.tscn")

	# Guardar texto por defecto del status para poder mostrar advertencias junto al estado
	default_status_text = status_label.text

	# Guardar color y tamaño por defecto (fallbacks si no existen overrides)
	var col = status_label.get("theme_override_colors/font_color")
	if col != null:
		default_status_color = col

	var fs = status_label.get("theme_override_font_sizes/font_size")
	if fs != null:
		default_status_font_size = int(fs)

	# Asegurar un tamaño mínimo visible y aplicarlo al Label
	if default_status_font_size < min_status_font_size:
		default_status_font_size = min_status_font_size

	# Forzar el tamaño en el label para evitar overrides demasiado pequeños
	status_label.set("theme_override_font_sizes/font_size", default_status_font_size)

	# Guardar modulate por defecto (para parpadeo por opacidad)
	default_status_modulate = status_label.modulate

	# Mostrar nombre guardado en DatosUsuario si existe
	if DatosUsuario and DatosUsuario.nombre_usuario != "":
		label_name.text = DatosUsuario.nombre_usuario

	# Si el singleton tiene avatar cargado, aplicarlo al IconTexture
	var icon_node := get_node_or_null("LayoutPrincipal/HeaderCard/CardPanel/PaddingInterior/Content/AvatarBG/IconTexture")
	if icon_node != null and DatosUsuario:
		if DatosUsuario.avatar_texture != null:
			icon_node.texture = DatosUsuario.avatar_texture
		elif DatosUsuario.avatar_path != "":
			if ResourceLoader.exists(DatosUsuario.avatar_path):
				icon_node.texture = load(DatosUsuario.avatar_path)

	# Conectar señal para actualizar el nombre en tiempo real desde el singleton
	if DatosUsuario:
		var cb_nombre := Callable(self, "_on_nombre_usuario_cambiado")
		if not DatosUsuario.is_connected("nombre_usuario_cambiado", cb_nombre):
			DatosUsuario.connect("nombre_usuario_cambiado", cb_nombre)

	# Crear/Configurar Timer y AudioStreamPlayer para advertencias (parpadeo + sonido)
	_warning_timer = get_node_or_null("WarningBlinkTimer")
	if _warning_timer == null:
		_warning_timer = Timer.new()
		_warning_timer.name = "WarningBlinkTimer"
		_warning_timer.wait_time = blink_interval
		_warning_timer.one_shot = false
		add_child(_warning_timer)
		_warning_timer.connect("timeout", Callable(self, "_on_warning_blink_timeout"))
	else:
		_warning_timer.wait_time = blink_interval

	_warning_audio = get_node_or_null("WarningAudio")
	if _warning_audio == null:
		_warning_audio = AudioStreamPlayer.new()
		_warning_audio.name = "WarningAudio"
		add_child(_warning_audio)

	# Crear/Configurar reproductor para sonido de éxito
	_success_audio = get_node_or_null("SuccessAudio")
	if _success_audio == null:
		_success_audio = AudioStreamPlayer.new()
		_success_audio.name = "SuccessAudio"
		add_child(_success_audio)

	if warning_sound != null:
		_warning_audio.stream = warning_sound
	if _warning_audio != null:
		_warning_audio.volume_db = warning_volume_db

	if success_sound != null:
		_success_audio.stream = success_sound
	if _success_audio != null:
		_success_audio.volume_db = success_volume_db

	# Crear Timer one-shot para limpiar la advertencia automáticamente
	_warning_auto_timer = get_node_or_null("WarningAutoClearTimer")
	if _warning_auto_timer == null:
		_warning_auto_timer = Timer.new()
		_warning_auto_timer.name = "WarningAutoClearTimer"
		_warning_auto_timer.wait_time = warning_auto_clear_seconds
		_warning_auto_timer.one_shot = true
		add_child(_warning_auto_timer)
		_warning_auto_timer.connect("timeout", Callable(self, "_on_warning_auto_clear_timeout"))
	else:
		_warning_auto_timer.wait_time = warning_auto_clear_seconds


func _find_name_edit_button() -> Button:
	var button_paths := [
		"LayoutPrincipal/HeaderCard/CardPanel/PaddingInterior/Content/InfoVBox/NameHBox/BtnNick",
		"LayoutPrincipal/HeaderCard/CardPanel/PaddingInterior/Content/InfoVBox/NameHBox/BtnEditar",
	]
	for node_path in button_paths:
		var button := get_node_or_null(node_path)
		if button is Button:
			return button
	return null

# --- LÓGICA DE EDICIÓN DE NOMBRE ---
func _on_btn_editar_pressed():
	# Editar inline: ocultar la Label y mostrar un LineEdit en su lugar
	var parent = label_name.get_parent()
	# Si ya existe el editor inline, enfocarlo
	if parent.has_node("InlineNameEdit"):
		var existing = parent.get_node("InlineNameEdit")
		existing.grab_focus()
		return

	# Ocultar la etiqueta y crear el LineEdit en el mismo contenedor
	label_name.hide()
	var line_edit = LineEdit.new()
	line_edit.name = "InlineNameEdit"
	line_edit.text = label_name.text
	line_edit.placeholder_text = "Escribe tu nuevo nombre..."
	# Copiar configuraciones básicas de tamaño para que encaje
	line_edit.size_flags_horizontal = label_name.size_flags_horizontal
	line_edit.size_flags_vertical = label_name.size_flags_vertical
	line_edit.custom_minimum_size = label_name.get_minimum_size()
	# Copiar tamaño de fuente de la Label si existe override
	var font_prop := "theme_override_font_sizes/font_size"
	var fs_val = null
	# label_name.get(prop) devuelve null si la propiedad no existe
	fs_val = label_name.get(font_prop)
	if fs_val != null and (typeof(fs_val) == TYPE_INT or typeof(fs_val) == TYPE_FLOAT):
		line_edit.set(font_prop, int(fs_val))

	parent.add_child(line_edit)
	# Insertarlo en la misma posición que la label (usar get_children().find)
	var idx := parent.get_children().find(label_name)
	if idx >= 0:
		parent.move_child(line_edit, idx)

	line_edit.grab_focus()
	line_edit.select_all()

	# Conectar señales usando Callables enlazados (compatible con Godot 4)
	if line_edit.has_signal("text_submitted"):
		var cb_text := Callable(self, "_on_inline_lineedit_text_submitted").bind(line_edit)
		line_edit.connect("text_submitted", cb_text)
	elif line_edit.has_signal("text_entered"):
		var cb_text2 := Callable(self, "_on_inline_lineedit_text_submitted").bind(line_edit)
		line_edit.connect("text_entered", cb_text2)

	if line_edit.has_signal("focus_exited"):
		var cb_focus := Callable(self, "_on_inline_lineedit_focus_exited").bind(line_edit)
		line_edit.connect("focus_exited", cb_focus)

	# Conectar gui_input para detectar Escape / Enter como fallback
	if line_edit.has_signal("gui_input"):
		var cb_gui := Callable(self, "_on_inline_lineedit_gui_input").bind(line_edit)
		line_edit.connect("gui_input", cb_gui)

# --- LÓGICA DE NAVEGACIÓN ---
func _on_menu_button_pressed(button_name: String):
	match button_name:
		"BtnLogros":
			print("Abriendo Logros...")
			# get_tree().change_scene_to_file("res://escenas/logros.tscn")
		"BtnNivel":
			print("Mostrando detalles de nivel...")
		"BtnMisiones":
			print("Cargando misiones diarias...")
		"BtnSemanal":
			print("Reclamando recompensa semanal...")
		"BtnSocial":
			print("Abriendo lista de amigos...")
		"BtnTienda":
			print("Entrando a la tienda...")
		"BtnCerrarSesion", "BtnSignOut":
			print("Perfil: cerrar sesión solicitado")
			_sign_out()

# --- EFECTOS VISUALES ---
func _on_button_hover():
	# Aquí podrías reproducir un AudioStreamPlayer con un "click" suave
	pass


# Sanitización y validación de entradas del usuario
func sanitize_player_input(input: String) -> Dictionary:
	var s = input.strip_edges()
	var res = {"ok": true, "clean": s, "reason": "", "modified": false}
	if s == "":
		res.ok = false
		res.clean = ""
		res.reason = "Nombre vacío"
		return res

	var lower = s.to_lower()
	# Prohibir rutas y secuencias que puedan usarse para acceder a archivos
	if lower.find("res://") >= 0 or lower.find("user://") >= 0 or lower.find("../") >= 0:
		res.ok = false
		res.clean = ""
		res.reason = "Nombre contiene rutas o secuencias inseguras"
		return res

	# Eliminar caracteres de control y símbolos potencialmente peligrosos
	var forbidden = ["\n", "\r", "\t", "<", ">", "/", "\\", ":", ";", "{", "}", "(", ")", "*", "?", "$", "%", "`", "|", "&", "~", "^"]
	var cleaned = ""
	for c in s:
		if forbidden.has(c):
			res.modified = true
			continue
		cleaned += c

	cleaned = cleaned.strip_edges()
	if cleaned == "":
		res.ok = false
		res.clean = ""
		res.reason = "Nombre inválido después de sanitizar"
		return res

	var max_len := 20
	if cleaned.length() > max_len:
		cleaned = cleaned.substr(0, max_len)
		res.modified = true
		res.reason = "Recortado a %d caracteres" % max_len

	# Bloquear nombres reservados y palabras prohibidas (insensitive)
	var banned_exact = ["pantergamey", "crazydayjho", "fenix"]
	var banned_words = ["hack", "hacker", "cheat", "cheater", "admin", "staff", "owner", "puta", "mierda", "idiota", "imbecil"]
	var lower_clean := cleaned.to_lower()
	for b in banned_exact:
		if lower_clean == b:
			res.ok = false
			res.clean = ""
			res.reason = "Nombre reservado o prohibido"
			return res
	for b in banned_words:
		if lower_clean.find(b) >= 0:
			res.ok = false
			res.clean = ""
			res.reason = "Nombre contiene palabra prohibida: %s" % b
			return res

	res.clean = cleaned
	if res.reason == "" and cleaned != s:
		res.reason = "Se eliminaron caracteres inválidos"
	res.ok = true
	return res


# Mostrar y limpiar advertencias en status_label
func show_status_warning(reason: String) -> void:
	# Mostrar sólo la advertencia (sin el nivel)
	status_label.text = "⚠️ " + reason
	# Color rojo y fuente más grande
	status_label.set("theme_override_colors/font_color", Color(1, 0.2, 0.2, 1))
	status_label.set("theme_override_font_sizes/font_size", int(default_status_font_size + 10))
	# Asegurar opacidad inicial completa y arrancar parpadeo por opacidad
	is_warning_active = true
	_blink_state = false
	status_label.modulate = Color(default_status_modulate.r, default_status_modulate.g, default_status_modulate.b, 1.0)
	if _warning_timer != null:
		_warning_timer.wait_time = blink_interval
		_warning_timer.start()
	if warning_sound != null and _warning_audio != null:
		_warning_audio.stream = warning_sound
		_warning_audio.play()

	# Iniciar/Resetear timer de auto-clear
	if _warning_auto_timer != null:
		_warning_auto_timer.wait_time = warning_auto_clear_seconds
		_warning_auto_timer.start()


func show_status_success(message: String) -> void:
	# Mostrar mensaje de éxito temporalmente y restaurar después
	status_label.text = message
	# Asegurar estilos por defecto
	status_label.set("theme_override_colors/font_color", default_status_color)
	status_label.set("theme_override_font_sizes/font_size", default_status_font_size)
	# Detener parpadeo si estaba activo
	is_warning_active = false
	if _warning_timer != null:
		_warning_timer.stop()
	# Iniciar timer one-shot para limpiar el mensaje
	if _warning_auto_timer != null:
		_warning_auto_timer.wait_time = warning_auto_clear_seconds
		_warning_auto_timer.start()

	# Reproducir sonido de éxito si está asignado
	if success_sound != null and _success_audio != null:
		_success_audio.stream = success_sound
		_success_audio.play()

func clear_status_warning() -> void:
	# Restaurar texto y estilos por defecto
	status_label.text = default_status_text
	status_label.set("theme_override_colors/font_color", default_status_color)
	status_label.set("theme_override_font_sizes/font_size", default_status_font_size)
	# Detener parpadeo y asegurar que esté visible
	is_warning_active = false
	if _warning_timer != null:
		_warning_timer.stop()
	# Restaurar modulate original
	status_label.modulate = default_status_modulate
	# Detener cualquier sonido de advertencia en reproducción
	if _warning_audio != null:
		_warning_audio.stop()

	# Detener sonido de éxito si está reproduciendo
	if _success_audio != null:
		_success_audio.stop()

	# Detener timer de auto-clear si está corriendo
	if _warning_auto_timer != null:
		_warning_auto_timer.stop()

func _on_warning_blink_timeout() -> void:
	if not is_warning_active:
		if _warning_timer != null:
			_warning_timer.stop()
		status_label.modulate = default_status_modulate
		return

	_blink_state = not _blink_state
	var alpha := 0.15 if _blink_state else 1.0
	status_label.modulate = Color(default_status_modulate.r, default_status_modulate.g, default_status_modulate.b, alpha)


func _on_warning_auto_clear_timeout() -> void:
	clear_status_warning()


func _on_nombre_usuario_cambiado(new_name: String) -> void:
	# Actualiza el label del perfil cuando el singleton emite el cambio
	if label_name:
		label_name.text = new_name


# Handlers para edición inline
func _on_inline_lineedit_text_submitted(new_text: String, line_edit: LineEdit) -> void:
	var result = sanitize_player_input(new_text)
	if not result.ok:
		# Mostrar advertencia en rojo sin el nivel
		show_status_warning(result.reason)
	else:
		label_name.text = result.clean
		# Actualizar global DatosUsuario usando el setter (emite señal y guarda)
		if DatosUsuario:
			if DatosUsuario.has_method("set_nombre_usuario"):
				DatosUsuario.set_nombre_usuario(result.clean)
			else:
				DatosUsuario.nombre_usuario = result.clean
				DatosUsuario.save_local()
		if result.modified:
			show_status_warning(result.reason)
		else:
			show_status_success("Nombre actualizado correctamente")
	print("Nombre actualizado a: ", result.clean)
	line_edit.queue_free()
	label_name.show()

func _on_inline_lineedit_focus_exited(line_edit: LineEdit) -> void:
	var new_text = line_edit.text
	var result = sanitize_player_input(new_text)
	if not result.ok:
		show_status_warning(result.reason)
	else:
		label_name.text = result.clean
		# Actualizar global DatosUsuario usando el setter (emite señal y guarda)
		if DatosUsuario:
			if DatosUsuario.has_method("set_nombre_usuario"):
				DatosUsuario.set_nombre_usuario(result.clean)
			else:
				DatosUsuario.nombre_usuario = result.clean
				DatosUsuario.save_local()
		if result.modified:
			show_status_warning(result.reason)
		else:
			show_status_success("Nombre actualizado correctamente")
	print("Nombre actualizado a: ", result.clean)
	line_edit.queue_free()
	label_name.show()


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


func _sign_out() -> void:
	# Cierra sesión en el backend Firebase (autoload o plugin nativo), limpia DatosUsuario y vuelve al login
	print("[Perfil] Iniciando cierre de sesión...")
	var auth_context := _get_auth_backend_for_sign_out()
	var backend: Object = auth_context.get("backend", null)
	var auth_backend: Object = auth_context.get("auth", null)
	var sign_out_requested := false

	if auth_backend:
		if auth_backend.has_method("sign_out"):
			auth_backend.sign_out()
			sign_out_requested = true
			print("[Perfil] sign_out() llamado")
		elif auth_backend.has_method("signOut"):
			auth_backend.signOut()
			sign_out_requested = true
			print("[Perfil] signOut() llamado")
	else:
		print("[Perfil] No se detectó backend Firebase para sign out")

	if not sign_out_requested:
		show_status_warning("No se pudo iniciar el cierre de sesión.")
		return

	var signed_out := await _wait_until_signed_out(auth_backend)
	print("[Perfil] Estado signed in después de sign out:", not signed_out)
	if not signed_out:
		show_status_warning("La sesión sigue activa. No se cambió de escena.")
		return

	# Limpiar DatosUsuario local
	if DatosUsuario:
		if DatosUsuario.has_method("clear_session"):
			DatosUsuario.clear_session(true)
		else:
			DatosUsuario.id_usuario = ""
			DatosUsuario.firebase_uid = ""
			DatosUsuario.nombre_usuario = ""
			if DatosUsuario.has_method("save_local"):
				DatosUsuario.save_local()
			elif DatosUsuario.has_method("set_nombre_usuario"):
				DatosUsuario.set_nombre_usuario("", true)

	# Actualizar UI
	if label_name:
		label_name.text = ""

	show_status_success("Sesión cerrada. Volviendo al login...")

	# Cambiar a la escena de Login si existe
	var login_scene = "res://escenas/gui/Login/Login.tscn"
	if ResourceLoader.exists(login_scene):
		get_tree().call_deferred("change_scene_to_file", login_scene)
	else:
		push_warning("Perfil: escena de Login no encontrada: %s" % login_scene)

func _on_inline_lineedit_gui_input(event: InputEvent, line_edit: LineEdit) -> void:
	if event is InputEventKey and event.pressed:
		# Esc cancelar
		if event.keycode == KEY_ESCAPE:
			line_edit.queue_free()
			label_name.show()
			return
		# Enter aceptar (fallback si la señal no existe)
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var new_text = line_edit.text
			var result = sanitize_player_input(new_text)
			if not result.ok:
				show_status_warning(result.reason)
			else:
				label_name.text = result.clean
				# Actualizar global DatosUsuario usando el setter (emite señal y guarda)
				if DatosUsuario:
					if DatosUsuario.has_method("set_nombre_usuario"):
						DatosUsuario.set_nombre_usuario(result.clean)
					else:
						DatosUsuario.nombre_usuario = result.clean
						DatosUsuario.save_local()
				if result.modified:
					show_status_warning(result.reason)
				else:
					show_status_success("Nombre actualizado correctamente")
			print("Nombre actualizado a: ", result.clean)
			line_edit.queue_free()
			label_name.show()

# Función para actualizar el nivel desde otros scripts
func actualizar_nivel(nuevo_nivel: int):
	default_status_text = "● EN LÍNEA • NIVEL " + str(nuevo_nivel)
	clear_status_warning()


func _on_btn_volver_pressed() -> void:
	# Cambiar a la escena principal (MainMenu)
	var main_menu_scene = load("res://scenes/MainMenu.tscn")
	if main_menu_scene:
		get_tree().change_scene_to_packed(main_menu_scene)
	else:
		push_error("[Perfil][ERROR] No se pudo cargar res://scenes/MainMenu.tscn")
