extends Control

@onready var btn_perfil: Button = $PerfilUsuario/BtnPerfil
@onready var btn_jugar: Button = $HBoxContainer2/Jugar
@onready var btn_configuracion: Button = $HBoxContainer2/Configuracion
@onready var label_nombre: Label = $PerfilUsuario/InputFalso/labelnombre
@onready var label_dinero: Label = $VBoxContainer2/PanelMoneda/HBoxContainer/Label
@onready var label_esmeraldas: Label = $VBoxContainer2/PanelEsmeralda/HBoxContainer/Label
@onready var fondo_rect: TextureRect = $Fondo
@onready var camera_menu: Camera3D = null
@onready var avatar_node: TextureRect = $PerfilUsuario/Avatar

var _avatar_file_dialog: FileDialog = null

const ESCENA_CARGA := "res://escenas/gui/escena_carga.tscn"
const ESCENA_SKY3D_DEMO := "res://demo/Sky3DDemo.tscn"
const MENU_MUSIC_PATH := "res://recursos/Musica/Aire-de-son.mp3"
var _audio_player_menu = null
var _menu_music_playing = false
func _ready() -> void:
	btn_perfil.pressed.connect(_on_btn_perfil_pressed)
	btn_jugar.pressed.connect(_on_btn_jugar_pressed)
	btn_configuracion.pressed.connect(_on_config_pressed)

	var btn_multi = get_node_or_null("HBoxContainer2/Multijugador")
	if btn_multi:
		btn_multi.pressed.connect(_on_multijugador_pressed)

	# Buscar la cámara en el viewport del fondo
	camera_menu = get_node_or_null("Node3D/SubViewport2/Bodega/Camera3D")

	# Preparar Avatar: no permitir cambiar desde este menú (usar Perfil_Menu -> BtnAvatar)
	if avatar_node:
		avatar_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Aplicar avatar guardado si existe
		if DatosUsuario:
			if DatosUsuario.avatar_texture != null:
				avatar_node.texture = DatosUsuario.avatar_texture
			elif DatosUsuario.avatar_path != "":
				if ResourceLoader.exists(DatosUsuario.avatar_path):
					avatar_node.texture = load(DatosUsuario.avatar_path)

	# Crear botón para subir la cámara (programático; evita editar la escena .tscn)
	var btn_subir_cam = get_node_or_null("HBoxContainer2/SubirCamara")
	if btn_subir_cam == null:
		btn_subir_cam = Button.new()
		btn_subir_cam.name = "SubirCamara"
		btn_subir_cam.text = "↑"
		btn_subir_cam.custom_minimum_size = Vector2(48, 48)
		# Añadimos al contenedor principal de botones
		var hbox = get_node_or_null("HBoxContainer2")
		if hbox:
			hbox.add_child(btn_subir_cam)
		else:
			add_child(btn_subir_cam)
	btn_subir_cam.pressed.connect(_on_subir_cam_pressed)

	# Configurar el fondo para recibir input
	if fondo_rect:
		fondo_rect.mouse_filter = Control.MOUSE_FILTER_PASS 
		fondo_rect.gui_input.connect(_on_fondo_gui_input)

	_configurar_label_nombre()
	_actualizar_label_nombre()
	_actualizar_dinero()
	_actualizar_esmeraldas()


	if DatosUsuario:
		var cb_nombre := Callable(self, "_on_nombre_usuario_cambiado")
		if not DatosUsuario.is_connected("nombre_usuario_cambiado", cb_nombre):
			DatosUsuario.connect("nombre_usuario_cambiado", cb_nombre)

	# Iniciar música del Main Menu
	_start_menu_music()


func _configurar_label_nombre() -> void:
	if not label_nombre:
		return
	label_nombre.clip_text = true
	label_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _actualizar_label_nombre() -> void:
	if not label_nombre:
		return
	if DatosUsuario and DatosUsuario.nombre_usuario != "":
		label_nombre.text = DatosUsuario.nombre_usuario


func _actualizar_esmeraldas() -> void:
	if not label_esmeraldas:
		return
	if DatosUsuario:
		label_esmeraldas.text = str(DatosUsuario.esmeraldas)


func _actualizar_dinero() -> void:
	if not label_dinero:
		return
	if DatosUsuario:
		label_dinero.text = str(snapped(DatosUsuario.dinero, 0.01))

	


func _on_nombre_usuario_cambiado(new_name: String) -> void:
	if label_nombre:
		label_nombre.text = new_name
	_actualizar_dinero()
	_actualizar_esmeraldas()


func _on_btn_perfil_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/Perfil_Menu/Perfil_Menu.tscn")


func _on_btn_jugar_pressed() -> void:
	if not ResourceLoader.exists(ESCENA_CARGA):
		push_warning("MainMenu: escena de carga no encontrada: %s" % ESCENA_CARGA)
		return
	if not ResourceLoader.exists(ESCENA_SKY3D_DEMO):
		push_warning("MainMenu: Sky3DDemo no encontrado: %s" % ESCENA_SKY3D_DEMO)
		return

	if DatosUsuario:
		if DatosUsuario.guardado_player_scene != "" and ResourceLoader.exists(DatosUsuario.guardado_player_scene):
			DatosUsuario.next_scene = DatosUsuario.guardado_player_scene
		else:
			DatosUsuario.next_scene = ESCENA_SKY3D_DEMO
	get_tree().change_scene_to_file(ESCENA_CARGA)


func _on_config_pressed() -> void:
	if has_node("/root/SettingsManager"):
		get_node("/root/SettingsManager").change_to_settings()
	else:
		get_tree().change_scene_to_file("res://escenas/configuraciones/configuraciones.tscn")

func _on_fondo_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		if camera_menu and camera_menu.has_method("rotate_from_input"):
			camera_menu.rotate_from_input(-event.relative.x)

func _on_subir_cam_pressed() -> void:
	if camera_menu:
		var step := 0.5
		camera_menu.height_offset += step
		# Rango razonable para la altura de la cámara
		camera_menu.height_offset = clamp(camera_menu.height_offset, -50.0, 100.0)

func _start_menu_music() -> void:
	if _audio_player_menu and _menu_music_playing:
		return
	if not ResourceLoader.exists(MENU_MUSIC_PATH):
		print("MainMenu: música no encontrada:", MENU_MUSIC_PATH)
		return
	var stream = load(MENU_MUSIC_PATH)
	if not stream:
		print("MainMenu: fallo al cargar música:", MENU_MUSIC_PATH)
		return

	_audio_player_menu = AudioStreamPlayer.new()
	_audio_player_menu.stream = stream
	_audio_player_menu.volume_db = -6
	add_child(_audio_player_menu)
	_audio_player_menu.play()
	_menu_music_playing = true


func _stop_menu_music() -> void:
	if _audio_player_menu:
		if _audio_player_menu.playing:
			_audio_player_menu.stop()
		_audio_player_menu.queue_free()
		_audio_player_menu = null
		_menu_music_playing = false


func _on_avatar_gui_input(event: InputEvent) -> void:
	# Soporta click de ratón y toque en pantalla
	var clicked: bool = false
	if event is InputEventMouseButton:
		clicked = (event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	elif event is InputEventScreenTouch:
		clicked = event.pressed
	if clicked:
		_open_avatar_file_dialog()


func _open_avatar_file_dialog() -> void:
	if _avatar_file_dialog == null:
		_avatar_file_dialog = FileDialog.new()
		_avatar_file_dialog.name = "AvatarFileDialog"
		# Permitir seleccionar cualquier imagen desde el sistema de archivos
		_avatar_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_avatar_file_dialog.add_filter("*.png ; *.jpg ; *.jpeg ; *.webp ; *.bmp")
		_avatar_file_dialog.connect("file_selected", Callable(self, "_on_avatar_file_selected"))
		add_child(_avatar_file_dialog)
	# Mostrar diálogo
	if _avatar_file_dialog.has_method("popup_centered"):
		_avatar_file_dialog.popup_centered()
	else:
		_avatar_file_dialog.popup()


func _on_avatar_file_selected(path: String) -> void:
	# Intentar cargar la imagen seleccionada
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_warning("MainMenu: no se pudo cargar imagen: %s" % path)
		return

	# Crear textura desde la imagen
	var tex := ImageTexture.new()
	# create_from_image puede requerir flags, pero el fallback funcionará en la mayoría de casos
	if tex.has_method("create_from_image"):
		tex.create_from_image(img)
	else:
		# Fallback: asignar directamente si load puede manejar la ruta (res:// o user://)
		tex = load(path)

	# Aplicar a la UI inmediatamente
	if avatar_node:
		avatar_node.texture = tex
		avatar_node.expand = true
		# Usar modo de estirado que cubre el área manteniendo aspecto
		if avatar_node.has_method("set"):
			avatar_node.set("stretch_mode", 5)

	# Guardar en DatosUsuario: copiar archivo a user:// para persistencia si es externo
	if DatosUsuario:
		if not path.begins_with("res://"):
			# Asegurar carpeta (usar ruta absoluta con API estática disponible)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://avatars"))
			var ext := path.get_extension()
			var dest := "user://avatars/avatar_%d.%s" % [Time.get_unix_time_from_system(), ext]
			# Copiar bytes
			var src := FileAccess.open(path, FileAccess.READ)
			if src:
				var data := src.get_buffer(src.get_length())
				src.close()
				var dst := FileAccess.open(dest, FileAccess.WRITE)
				if dst:
					dst.store_buffer(data)
					dst.close()
					DatosUsuario.avatar_path = dest
				else:
					print("MainMenu: no se pudo escribir avatar en:", dest)
			else:
				print("MainMenu: no se pudo leer archivo:", path)
		else:
			# Si es res://, simplemente apuntamos a la ruta
			DatosUsuario.avatar_path = path

		# Guardar la textura en memoria y persistir metadata
		DatosUsuario.avatar_texture = tex
		DatosUsuario.save_local()
		# Emitir señal para que otras escenas actualicen su avatar
		if DatosUsuario.has_method("emit_signal"):
			DatosUsuario.emit_signal("avatar_cambiada", tex)

func _on_multijugador_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/multijugador/LobbyMultijugador.tscn")
