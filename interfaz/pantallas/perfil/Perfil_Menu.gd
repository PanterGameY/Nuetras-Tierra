extends Control

# ==============================================================================
# PERFIL_MENU.GD - Glassmorphism Cockpit UI Driver Profile
# Sistema de Gestión de Conductor y Credenciales "Nuestra Tierra"
# ==============================================================================

signal nombre_usuario_cambiado(nuevo_nombre: String)
signal avatar_cambiada(nueva_ruta: String)

# Top Bar / Controles Principales
@onready var btn_home: Button = $MainMargin/MainVBox/TopBar/BtnHome
@onready var btn_cerrar_sesion: Button = $MainMargin/MainVBox/TopBar/BtnCerrarSesion
@onready var barra_divisas: BarraDivisas = $MainMargin/MainVBox/TopBar/EconomyPill

# Columna Izquierda: Ficha de Conductor
@onready var label_id_conductor: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HeaderIDRow/LabelIDConductor
@onready var avatar_rect: TextureRect = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HBoxPerfil/AvatarMarco/Avatar
@onready var labelnombre: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HBoxPerfil/VBoxDatosPpal/labelnombre
@onready var label_rango: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HBoxPerfil/VBoxDatosPpal/LabelRango
@onready var btn_avatar: Button = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HBoxPerfil/VBoxDatosPpal/HBoxBotonesAccion/BtnAvatar
@onready var btn_nick: Button = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HBoxPerfil/VBoxDatosPpal/HBoxBotonesAccion/BtnNick
@onready var label_nivel: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/VBoxProgreso/HBoxXpInfo/LabelNivel
@onready var label_xp: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/VBoxProgreso/HBoxXpInfo/LabelXp
@onready var progress_bar: ProgressBar = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/VBoxProgreso/ProgressBar
@onready var valor_dinero: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/GridMetricas/CardSaldo/VBox/ValorDinero
@onready var valor_esmeraldas: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/GridMetricas/CardEsmeraldas/VBox/ValorEsmeraldas
@onready var valor_vehiculos: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/GridMetricas/CardVehiculos/VBox/ValorVehiculos
@onready var valor_misiones: Label = $MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/GridMetricas/CardMisiones/VBox/ValorMisiones

# Licencias
@onready var card_lic_b1: PanelContainer = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLicencias/GridLicencias/CardLicB1
@onready var card_lic_c1: PanelContainer = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLicencias/GridLicencias/CardLicC1
@onready var card_lic_c2: PanelContainer = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLicencias/GridLicencias/CardLicC2
@onready var card_lic_c3: PanelContainer = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLicencias/GridLicencias/CardLicC3

# Logros
@onready var btn_reclamar1: Button = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLogros/ScrollLogros/GridLogros/CardLogro1/VBox/BtnReclamar1
@onready var btn_reclamar2: Button = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLogros/ScrollLogros/GridLogros/CardLogro2/VBox/BtnReclamar2
@onready var btn_reclamar3: Button = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLogros/ScrollLogros/GridLogros/CardLogro3/VBox/BtnReclamar3
@onready var btn_reclamar4: Button = $MainMargin/MainVBox/ColumnsHBox/RightCard/Margin/VBoxRight/SectionLogros/ScrollLogros/GridLogros/CardLogro4/VBox/BtnReclamar4

# Audio player para feedback de acciones
var sfx_player: AudioStreamPlayer = null

# Rutas persistentes
const RUTA_DEFAULT_AVATAR := "res://interfaz/pantallas/menu_principal/imagenes/default_avatar.svg"
const RUTA_FALLBACK_ICON := "res://icon.svg"
const CONFIG_LOGROS_PATH := "user://logros_reclamados.cfg"

# Cache de logros reclamados
var logros_reclamados: Dictionary = {}

func _ready() -> void:
	_inicializar_audio()
	_cargar_logros_guardados()
	_conectar_senales()
	_aplicar_estilos_dinamicos()
	_actualizar_ui_completa()
	_animacion_entrada()

func _inicializar_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	if ResourceLoader.exists("res://recursos/efectos/money.mp3"):
		sfx_player.stream = load("res://recursos/efectos/money.mp3")

func _play_sfx(stream_path: String = "") -> void:
	if not sfx_player:
		return
	if stream_path != "" and ResourceLoader.exists(stream_path):
		sfx_player.stream = load(stream_path)
	if sfx_player.stream:
		sfx_player.play()

func _conectar_senales() -> void:
	if btn_home and not btn_home.pressed.is_connected(_on_btn_home_pressed):
		btn_home.pressed.connect(_on_btn_home_pressed)
		
	if btn_cerrar_sesion and not btn_cerrar_sesion.pressed.is_connected(_on_btn_cerrar_sesion_pressed):
		btn_cerrar_sesion.pressed.connect(_on_btn_cerrar_sesion_pressed)
		
	if btn_avatar and not btn_avatar.pressed.is_connected(_on_btn_avatar_pressed):
		btn_avatar.pressed.connect(_on_btn_avatar_pressed)
		
	if btn_nick and not btn_nick.pressed.is_connected(_on_btn_nick_pressed):
		btn_nick.pressed.connect(_on_btn_nick_pressed)

	# Conexión de botones de reclamo de logros
	if btn_reclamar1 and not btn_reclamar1.pressed.is_connected(func(): _reclamar_logro("primer_viaje", 5000, 150, btn_reclamar1)):
		btn_reclamar1.pressed.connect(func(): _reclamar_logro("primer_viaje", 5000, 150, btn_reclamar1))
	if btn_reclamar2 and not btn_reclamar2.pressed.is_connected(func(): _reclamar_logro("patron_asfalto", 25000, 500, btn_reclamar2)):
		btn_reclamar2.pressed.connect(func(): _reclamar_logro("patron_asfalto", 25000, 500, btn_reclamar2))
	if btn_reclamar3 and not btn_reclamar3.pressed.is_connected(func(): _reclamar_logro("rey_carretera", 100000, 2000, btn_reclamar3)):
		btn_reclamar3.pressed.connect(func(): _reclamar_logro("rey_carretera", 100000, 2000, btn_reclamar3))
	if btn_reclamar4 and not btn_reclamar4.pressed.is_connected(func(): _reclamar_logro("dueno_flota", 50000, 1000, btn_reclamar4)):
		btn_reclamar4.pressed.connect(func(): _reclamar_logro("dueno_flota", 50000, 1000, btn_reclamar4))

	# Conectar con cambios en DatosUsuario si existen señales
	if DatosUsuario.has_signal("perfil_actualizado"):
		if not DatosUsuario.perfil_actualizado.is_connected(_actualizar_ui_completa):
			DatosUsuario.perfil_actualizado.connect(_actualizar_ui_completa)
	if DatosUsuario.has_signal("dinero_cambiado"):
		if not DatosUsuario.dinero_cambiado.is_connected(func(_m): _actualizar_ui_completa()):
			DatosUsuario.dinero_cambiado.connect(func(_m): _actualizar_ui_completa())

func _aplicar_estilos_dinamicos() -> void:
	# Hover feedback suave para botones táctiles
	var buttons = [btn_home, btn_cerrar_sesion, btn_nick, btn_avatar]
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(func(): _tween_button_scale(btn, 1.05))
			btn.mouse_exited.connect(func(): _tween_button_scale(btn, 1.0))

func _tween_button_scale(btn: Control, target_scale: float) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE * target_scale, 0.15)

func _animacion_entrada() -> void:
	var left_card = $MainMargin/MainVBox/ColumnsHBox/LeftCard
	var right_card = $MainMargin/MainVBox/ColumnsHBox/RightCard
	var top_bar = $MainMargin/MainVBox/TopBar
	
	if top_bar:
		top_bar.modulate.a = 0.0
		var tw_top = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_top.tween_property(top_bar, "modulate:a", 1.0, 0.3)
	
	if left_card:
		left_card.modulate.a = 0.0
		left_card.position.x -= 30.0
		var tw_left = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_left.tween_property(left_card, "modulate:a", 1.0, 0.35)
		tw_left.parallel().tween_property(left_card, "position:x", left_card.position.x + 30.0, 0.35)
		
	if right_card:
		right_card.modulate.a = 0.0
		right_card.position.x += 30.0
		var tw_right = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_right.tween_property(right_card, "modulate:a", 1.0, 0.4)
		tw_right.parallel().tween_property(right_card, "position:x", right_card.position.x - 30.0, 0.4)

# ==============================================================================
# ACTUALIZACIÓN DE DATOS DINÁMICOS
# ==============================================================================
func _actualizar_ui_completa() -> void:
	_cargar_avatar()
	_cargar_datos_usuario()
	_cargar_licencias()
	_actualizar_estado_logros()

func _cargar_datos_usuario() -> void:
	# 1. Nombre de Usuario
	var nombre = "CONDUCTOR"
	if DatosUsuario.has_method("obtener_nombre_usuario"):
		nombre = DatosUsuario.obtener_nombre_usuario()
	elif "nombre_usuario" in DatosUsuario and DatosUsuario.nombre_usuario != "":
		nombre = DatosUsuario.nombre_usuario
	
	if labelnombre:
		labelnombre.text = nombre.to_upper()
		
	# 2. ID Conductor
	if label_id_conductor:
		var id_str = ""
		if "id_usuario" in DatosUsuario and DatosUsuario.id_usuario != "":
			id_str = str(DatosUsuario.id_usuario).left(8).to_upper()
		elif "id_jugador" in DatosUsuario and DatosUsuario.id_jugador != "":
			id_str = str(DatosUsuario.id_jugador).left(8).to_upper()
		else:
			id_str = "COL-8492"
		label_id_conductor.text = "ID: " + id_str

	# 3. Nivel y Experiencia
	var nivel = 1
	var xp = 0
	if "nivel" in DatosUsuario:
		nivel = DatosUsuario.nivel
	if "experiencia" in DatosUsuario:
		xp = DatosUsuario.experiencia
		
	var xp_requerida = (nivel + 1) * 350
	
	if label_nivel:
		label_nivel.text = "NIVEL " + str(nivel)
	if label_xp:
		label_xp.text = "%d / %d XP" % [xp, xp_requerida]
	if progress_bar:
		progress_bar.max_value = max(1, xp_requerida)
		progress_bar.value = clamp(xp, 0, xp_requerida)
		
	# 4. Rango de Conductor
	if label_rango:
		label_rango.text = _calcular_rango_conductor(nivel)

	# 5. Economía (Dinero y Esmeraldas)
	var dinero = 0
	var esmeraldas = 0
	if DatosUsuario.has_method("obtener_dinero"):
		dinero = DatosUsuario.obtener_dinero()
	elif "dinero" in DatosUsuario:
		dinero = DatosUsuario.dinero
		
	if DatosUsuario.has_method("obtener_esmeraldas"):
		esmeraldas = DatosUsuario.obtener_esmeraldas()
	elif "esmeraldas" in DatosUsuario:
		esmeraldas = DatosUsuario.esmeraldas
		
	var dinero_fmt = "$ " + _formatear_numero(dinero)
	var esmeraldas_fmt = _formatear_numero(esmeraldas) + " ESM"
	
	if barra_divisas:
		barra_divisas.set_valores(float(dinero), int(esmeraldas))
	if valor_dinero:
		valor_dinero.text = dinero_fmt
	if valor_esmeraldas:
		valor_esmeraldas.text = esmeraldas_fmt
		
	# 6. Flota y Misiones completadas
	var vehiculos_count = 1
	if "vehiculos_personalizados" in DatosUsuario and DatosUsuario.vehiculos_personalizados is Dictionary:
		vehiculos_count = max(1, DatosUsuario.vehiculos_personalizados.size())
	elif "camiones_desbloqueados" in DatosUsuario and DatosUsuario.camiones_desbloqueados is Array:
		vehiculos_count = max(1, DatosUsuario.camiones_desbloqueados.size())
		
	if valor_vehiculos:
		valor_vehiculos.text = str(vehiculos_count) + " UND"
		
	var misiones_count = int(nivel * 3 + (xp / 120))
	if valor_misiones:
		valor_misiones.text = str(misiones_count)

func _calcular_rango_conductor(lvl: int) -> String:
	if lvl < 5:
		return "CONDUCTOR NOVATO"
	elif lvl < 15:
		return "RUTERO EXPERIMENTADO"
	elif lvl < 30:
		return "AMO DE LA TROCHA"
	elif lvl < 50:
		return "LEYENDA DEL ASFALTO"
	else:
		return "PATRÓN NACIONAL"

func _formatear_numero(valor: int) -> String:
	var texto = str(abs(valor))
	var longitud = texto.length()
	var resultado = ""
	for i in range(longitud):
		if i > 0 and (longitud - i) % 3 == 0:
			resultado += "."
		resultado += texto[i]
	return ("-" if valor < 0 else "") + resultado

# ==============================================================================
# GESTIÓN DE AVATAR (COMPATIBLE CON ESCRITORIO Y ANDROID)
# ==============================================================================
func _cargar_avatar() -> void:
	if not avatar_rect:
		return
		
	var ruta_avatar = ""
	if DatosUsuario.has_method("obtener_avatar"):
		ruta_avatar = DatosUsuario.obtener_avatar()
	elif "avatar_personalizado" in DatosUsuario:
		ruta_avatar = DatosUsuario.avatar_personalizado
	elif "avatar_ruta" in DatosUsuario:
		ruta_avatar = DatosUsuario.avatar_ruta
		
	if ruta_avatar != "" and (FileAccess.file_exists(ruta_avatar) or ResourceLoader.exists(ruta_avatar)):
		if ruta_avatar.begins_with("res://") or ruta_avatar.begins_with("user://"):
			var tex = ResourceLoader.load(ruta_avatar)
			if tex is Texture2D:
				avatar_rect.texture = tex
				return
		else:
			var img = Image.new()
			var err = img.load(ruta_avatar)
			if err == OK:
				var tex = ImageTexture.create_from_image(img)
				avatar_rect.texture = tex
				return

	# Fallbacks oficiales
	if ResourceLoader.exists(RUTA_DEFAULT_AVATAR):
		avatar_rect.texture = load(RUTA_DEFAULT_AVATAR)
	elif ResourceLoader.exists(RUTA_FALLBACK_ICON):
		avatar_rect.texture = load(RUTA_FALLBACK_ICON)

func _on_btn_avatar_pressed() -> void:
	_play_sfx()
	if OS.get_name() == "Android":
		# Soporte de selección de imagen en Android nativo si existe el singleton
		if Engine.has_singleton("GodotFilePicker"):
			var picker = Engine.get_singleton("GodotFilePicker")
			picker.open_gallery()
			return
		elif Engine.has_singleton("FileManager"):
			var fm = Engine.get_singleton("FileManager")
			fm.abrir_selector_imagenes()
			return

	# Desktop / Editor FileDialog instanciado dinámicamente
	var dialog = FileDialog.new()
	dialog.name = "DynamicFileDialog"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Formatos de Imagen"])
	dialog.file_selected.connect(func(path: String):
		_on_avatar_file_selected(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _on_avatar_file_selected(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
		
	var ext = path.get_extension().to_lower()
	if ext not in ["png", "jpg", "jpeg", "webp"]:
		return
		
	# Copiar a user:// para persistencia
	var dir_user = "user://perfil"
	DirAccess.make_dir_recursive_absolute(dir_user)
	var nueva_ruta = dir_user + "/avatar_custom." + ext
	
	var err = DirAccess.copy_absolute(path, nueva_ruta)
	if err == OK:
		_guardar_nuevo_avatar(nueva_ruta)
	else:
		_guardar_nuevo_avatar(path)

func _guardar_nuevo_avatar(ruta: String) -> void:
	if DatosUsuario.has_method("guardar_avatar"):
		DatosUsuario.guardar_avatar(ruta)
	elif "avatar_personalizado" in DatosUsuario:
		DatosUsuario.avatar_personalizado = ruta
		if DatosUsuario.has_method("guardar_datos"):
			DatosUsuario.guardar_datos()
	elif "avatar_ruta" in DatosUsuario:
		DatosUsuario.avatar_ruta = ruta
		if DatosUsuario.has_method("guardar_datos"):
			DatosUsuario.guardar_datos()
			
	avatar_cambiada.emit(ruta)
	_cargar_avatar()

# ==============================================================================
# EDICIÓN DE NICKNAME (MODAL GLASSMORPHIC COCKPIT)
# ==============================================================================
func _on_btn_nick_pressed() -> void:
	_play_sfx()
	_crear_modal_nick()

func _crear_modal_nick() -> void:
	# Eliminar modal previo si existe
	var modal_prev = get_node_or_null("ModalNickLayer")
	if modal_prev:
		modal_prev.queue_free()

	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ModalNickLayer"
	canvas_layer.layer = 100
	add_child(canvas_layer)

	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.72)
	canvas_layer.add_child(backdrop)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 240)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.pivot_offset = Vector2(230, 120)
	
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	panel_sb.set_border_width_all(1)
	panel_sb.border_color = Color(0.88, 0.68, 0.28, 0.8)
	panel_sb.set_corner_radius_all(14)
	panel_sb.shadow_size = 12
	panel_sb.shadow_color = Color(0, 0, 0, 0.6)
	panel.add_theme_stylebox_override("panel", panel_sb)
	canvas_layer.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.remove_child(vbox)
	panel.add_child(margin)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "EDITAR NOMBRE DE CONDUCTOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 1.0))
	if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
		title.add_theme_font_override("font", load("res://recursos/fonts/Moderniz.otf"))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var line_edit = LineEdit.new()
	line_edit.name = "LineEditNick"
	line_edit.custom_minimum_size = Vector2(0, 48)
	line_edit.placeholder_text = "Ingresa tu indicativo..."
	line_edit.max_length = 16
	line_edit.text = labelnombre.text if labelnombre else ""
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var edit_sb = StyleBoxFlat.new()
	edit_sb.bg_color = Color(0.04, 0.05, 0.06, 0.9)
	edit_sb.set_border_width_all(1)
	edit_sb.border_color = Color(0.78, 0.81, 0.85, 0.3)
	edit_sb.set_corner_radius_all(8)
	line_edit.add_theme_stylebox_override("normal", edit_sb)
	line_edit.add_theme_stylebox_override("focus", edit_sb)
	line_edit.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	line_edit.add_theme_font_size_override("font_size", 18)
	vbox.add_child(line_edit)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var btn_cancelar = Button.new()
	btn_cancelar.text = "CANCELAR"
	btn_cancelar.custom_minimum_size = Vector2(140, 44)
	btn_cancelar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb_cancel = StyleBoxFlat.new()
	sb_cancel.bg_color = Color(0.18, 0.20, 0.24, 0.8)
	sb_cancel.set_corner_radius_all(8)
	btn_cancelar.add_theme_stylebox_override("normal", sb_cancel)
	btn_cancelar.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 1.0))
	btn_cancelar.pressed.connect(func(): canvas_layer.queue_free())
	btn_hbox.add_child(btn_cancelar)

	var btn_guardar = Button.new()
	btn_guardar.text = "CONFIRMAR"
	btn_guardar.custom_minimum_size = Vector2(160, 44)
	btn_guardar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb_save = StyleBoxFlat.new()
	sb_save.bg_color = Color(0.88, 0.68, 0.28, 0.95)
	sb_save.set_corner_radius_all(8)
	btn_guardar.add_theme_stylebox_override("normal", sb_save)
	btn_guardar.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 1.0))
	btn_guardar.pressed.connect(func(): _confirmar_modal_nick(line_edit.text.strip_edges(), canvas_layer))
	btn_hbox.add_child(btn_guardar)

	# Animación modal
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.25)
	line_edit.grab_focus()

func _confirmar_modal_nick(nuevo_nombre: String, modal_layer: CanvasLayer) -> void:
	if nuevo_nombre.length() < 3:
		return
		
	if DatosUsuario.has_method("guardar_nombre_usuario"):
		DatosUsuario.guardar_nombre_usuario(nuevo_nombre)
	elif "nombre_usuario" in DatosUsuario:
		DatosUsuario.nombre_usuario = nuevo_nombre
		if DatosUsuario.has_method("guardar_datos"):
			DatosUsuario.guardar_datos()
			
	nombre_usuario_cambiado.emit(nuevo_nombre)
	_play_sfx()
	modal_layer.queue_free()
	_actualizar_ui_completa()

# ==============================================================================
# GESTIÓN DE LICENCIAS
# ==============================================================================
func _cargar_licencias() -> void:
	# B1 siempre activa por defecto (Conductor de Vehículo Liviano)
	_actualizar_tarjeta_licencia(card_lic_b1, true, "B1")
	
	var c1_activo = DatosUsuario.get("licencia_c1") if "licencia_c1" in DatosUsuario else true
	_actualizar_tarjeta_licencia(card_lic_c1, c1_activo, "C1")
	
	var c2_activo = DatosUsuario.get("licencia_c2") if "licencia_c2" in DatosUsuario else false
	_actualizar_tarjeta_licencia(card_lic_c2, c2_activo, "C2")
	
	var c3_activo = DatosUsuario.get("licencia_c3") if "licencia_c3" in DatosUsuario else false
	_actualizar_tarjeta_licencia(card_lic_c3, c3_activo, "C3")

func _actualizar_tarjeta_licencia(card: PanelContainer, habilitada: bool, categoria: String) -> void:
	if not card:
		return
		
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	
	if habilitada:
		sb.bg_color = Color(0.10, 0.12, 0.14, 0.85)
		sb.border_color = Color(0.88, 0.68, 0.28, 0.6)
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		sb.bg_color = Color(0.06, 0.07, 0.08, 0.6)
		sb.border_color = Color(0.35, 0.38, 0.42, 0.3)
		card.modulate = Color(0.65, 0.65, 0.65, 0.7)
		
	card.add_theme_stylebox_override("panel", sb)

# ==============================================================================
# SISTEMA INTERACTIVO DE LOGROS Y RECOMPENSAS
# ==============================================================================
func _cargar_logros_guardados() -> void:
	logros_reclamados.clear()
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_LOGROS_PATH)
	if err == OK:
		for clave in cfg.get_section_keys("logros"):
			logros_reclamados[clave] = cfg.get_value("logros", clave, false)

func _guardar_logros() -> void:
	var cfg = ConfigFile.new()
	for clave in logros_reclamados.keys():
		cfg.set_value("logros", clave, logros_reclamados[clave])
	cfg.save(CONFIG_LOGROS_PATH)

func _actualizar_estado_logros() -> void:
	_configurar_boton_logro(btn_reclamar1, "primer_viaje")
	_configurar_boton_logro(btn_reclamar2, "patron_asfalto")
	_configurar_boton_logro(btn_reclamar3, "rey_carretera")
	_configurar_boton_logro(btn_reclamar4, "dueno_flota")

func _configurar_boton_logro(btn: Button, id_logro: String) -> void:
	if not btn:
		return
	var reclamado = logros_reclamados.get(id_logro, false)
	if reclamado:
		btn.text = "RECLAMADO"
		btn.disabled = true
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.14, 0.16, 0.6)
		sb.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("disabled", sb)
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.6, 0.7))
	else:
		btn.text = "RECLAMAR"
		btn.disabled = false
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.88, 0.68, 0.28, 0.95)
		sb.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 1.0))

func _reclamar_logro(id_logro: String, recompensa_dinero: int, recompensa_xp: int, btn: Button) -> void:
	if logros_reclamados.get(id_logro, false):
		return

	logros_reclamados[id_logro] = true
	_guardar_logros()
	
	# Premiar al usuario
	if DatosUsuario.has_method("agregar_dinero"):
		DatosUsuario.agregar_dinero(recompensa_dinero)
	elif "dinero" in DatosUsuario:
		DatosUsuario.dinero += recompensa_dinero
		
	if DatosUsuario.has_method("agregar_experiencia"):
		DatosUsuario.agregar_experiencia(recompensa_xp)
	elif "experiencia" in DatosUsuario:
		DatosUsuario.experiencia += recompensa_xp
		
	if DatosUsuario.has_method("guardar_datos"):
		DatosUsuario.guardar_datos()

	_play_sfx("res://recursos/efectos/money.mp3")
	_configurar_boton_logro(btn, id_logro)
	_actualizar_ui_completa()

# ==============================================================================
# NAVEGACIÓN Y SESIÓN
# ==============================================================================
func _on_btn_home_pressed() -> void:
	_play_sfx()
	var ruta_moderna = "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
	if DatosUsuario:
		DatosUsuario.cambiar_escena(ruta_moderna)
	elif ResourceLoader.exists(ruta_moderna):
		get_tree().change_scene_to_file(ruta_moderna)
	else:
		push_error("No se encontró MainMenuModerno.tscn")

func _on_btn_cerrar_sesion_pressed() -> void:
	_play_sfx()
	
	# Desconectar / cerrar sesión en Firebase o Auth si existe
	if Engine.has_singleton("Firebase"):
		var fb = Engine.get_singleton("Firebase")
		if fb.has_method("logout"):
			fb.logout()
	elif has_node("/root/Firebase"):
		var fb_node = get_node("/root/Firebase")
		if fb_node.has_node("Auth") and fb_node.get_node("Auth").has_method("logout"):
			fb_node.get_node("Auth").logout()

	if DatosUsuario.has_method("cerrar_sesion"):
		DatosUsuario.cerrar_sesion()

	var ruta_login = "res://interfaz/pantallas/login/Login.tscn"
	if ResourceLoader.exists(ruta_login):
		get_tree().change_scene_to_file(ruta_login)
	else:
		get_tree().change_scene_to_file("res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn")
