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
	# Avatar circular con borde metálico/ámbar y recorte anti-aliased
	var avatar_marco := get_node_or_null("MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HBoxPerfil/AvatarMarco") as PanelContainer
	if avatar_marco:
		avatar_marco.custom_minimum_size = Vector2(124, 124)
		var sb_av := StyleBoxFlat.new()
		sb_av.bg_color = Color(0.07, 0.08, 0.10, 0.95)
		sb_av.set_border_width_all(2)
		sb_av.border_color = Color(0.88, 0.68, 0.28, 0.55)
		sb_av.set_corner_radius_all(62)
		sb_av.content_margin_left = 4
		sb_av.content_margin_right = 4
		sb_av.content_margin_top = 4
		sb_av.content_margin_bottom = 4
		avatar_marco.add_theme_stylebox_override("panel", sb_av)

	if avatar_rect:
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
		avatar_rect.material = mat

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
	var left_card := get_node_or_null("MainMargin/MainVBox/ColumnsHBox/LeftCard") as Control
	var right_card := get_node_or_null("MainMargin/MainVBox/ColumnsHBox/RightCard") as Control
	var top_bar := get_node_or_null("MainMargin/MainVBox/TopBar") as Control

	if right_card:
		right_card.clip_contents = true
		right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_card.size_flags_stretch_ratio = 1.08

	if top_bar:
		top_bar.modulate.a = 0.0
		var tw_top = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_top.tween_property(top_bar, "modulate:a", 1.0, 0.28)

	for c in [left_card, right_card]:
		if c:
			c.pivot_offset = c.size * 0.5
			c.modulate.a = 0.0
			c.scale = Vector2(0.96, 0.96)
			var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "modulate:a", 1.0, 0.30)
			tw.tween_property(c, "scale", Vector2.ONE, 0.32)

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
		var id_str := ""
		if "id_usuario" in DatosUsuario and not str(DatosUsuario.id_usuario).strip_edges().is_empty():
			id_str = str(DatosUsuario.id_usuario).strip_edges().to_upper()
		else:
			id_str = "001"
		label_id_conductor.text = "ID #" + id_str

	# 3. Nivel, Escudo, Rango y Experiencia
	var nivel: int = int(DatosUsuario.nivel) if "nivel" in DatosUsuario else 0
	var xp: int = int(DatosUsuario.experiencia) if "experiencia" in DatosUsuario else 0
	var xp_requerida := maxi((nivel + 1) * 300, 1)
	var xp_clamped := clampi(xp, 0, xp_requerida)
	var pct := roundi((float(xp_clamped) / float(xp_requerida)) * 100.0)

	var rango := RangoConductor.obtener_rango(nivel)
	var color_rango: Color = rango["color"]

	if label_nivel:
		label_nivel.text = "NIVEL " + str(nivel)
		label_nivel.add_theme_color_override("font_color", color_rango.lightened(0.2))
	if label_xp:
		label_xp.text = "%s / %s XP (%d%%)" % [_formatear_numero(xp), _formatear_numero(xp_requerida), pct]
		label_xp.add_theme_color_override("font_color", color_rango.lightened(0.25))
	if progress_bar:
		progress_bar.custom_minimum_size.y = 14
		progress_bar.max_value = xp_requerida
		progress_bar.value = xp_clamped
		var sb_bg := StyleBoxFlat.new()
		sb_bg.bg_color = Color(0.05, 0.06, 0.08, 0.95)
		sb_bg.set_border_width_all(1)
		sb_bg.border_color = Color(0.78, 0.81, 0.85, 0.22)
		sb_bg.set_corner_radius_all(7)
		progress_bar.add_theme_stylebox_override("background", sb_bg)
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = color_rango
		sb_fill.set_corner_radius_all(7)
		sb_fill.shadow_color = Color(color_rango.r, color_rango.g, color_rango.b, 0.45)
		sb_fill.shadow_size = 8
		progress_bar.add_theme_stylebox_override("fill", sb_fill)

	# 4. Rango y Escudo de Conductor
	if label_rango:
		label_rango.text = str(rango["nombre"])
		label_rango.add_theme_color_override("font_color", color_rango)
	_actualizar_escudo_e_identidad(nivel, rango)

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
		
	# 6. Flota real y Estado de Pase Élite
	var vehiculos_count := 0
	if "vehiculos_comprados" in DatosUsuario and DatosUsuario.vehiculos_comprados is Dictionary:
		vehiculos_count = DatosUsuario.vehiculos_comprados.size()
	elif "vehiculos_personalizados" in DatosUsuario and DatosUsuario.vehiculos_personalizados is Dictionary:
		vehiculos_count = DatosUsuario.vehiculos_personalizados.size()

	if valor_vehiculos:
		valor_vehiculos.text = str(vehiculos_count) + " UND"

	var card_misiones_tit := get_node_or_null("MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/GridMetricas/CardMisiones/VBox/LabelTit") as Label
	if card_misiones_tit:
		card_misiones_tit.text = "PASE ELITE"
	if valor_misiones:
		var pase_ok: bool = DatosUsuario.tiene_pase_elite() if DatosUsuario.has_method("tiene_pase_elite") else bool(DatosUsuario.get("pase_elite_activo"))
		valor_misiones.text = "ACTIVO" if pase_ok else "INACTIVO"
		valor_misiones.add_theme_color_override("font_color", Color(0.28, 0.90, 0.54, 1.0) if pase_ok else Color(0.68, 0.72, 0.78, 0.85))


func _actualizar_escudo_e_identidad(nivel: int, rango: Dictionary) -> void:
	var vbox_datos := get_node_or_null("MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft/HBoxPerfil/VBoxDatosPpal")
	if vbox_datos and label_rango:
		var fila_rango := vbox_datos.get_node_or_null("FilaRangoEscudo") as HBoxContainer
		if not fila_rango:
			fila_rango = HBoxContainer.new()
			fila_rango.name = "FilaRangoEscudo"
			fila_rango.add_theme_constant_override("separation", 8)
			var idx := label_rango.get_index()
			vbox_datos.add_child(fila_rango)
			vbox_datos.move_child(fila_rango, idx)
			var escudo := TextureRect.new()
			escudo.name = "EscudoRango"
			escudo.custom_minimum_size = Vector2(40, 40)
			escudo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			escudo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			fila_rango.add_child(escudo)
			label_rango.reparent(fila_rango)
			label_rango.add_theme_font_size_override("font_size", 15)
		var esc_node := fila_rango.get_node_or_null("EscudoRango") as TextureRect
		if esc_node:
			esc_node.texture = RangoConductor.obtener_textura_escudo(nivel)
			esc_node.tooltip_text = str(rango["nombre"])

	var vbox_left := get_node_or_null("MainMargin/MainVBox/ColumnsHBox/LeftCard/Margin/VBoxLeft")
	if not vbox_left:
		return
	var panel_id := vbox_left.get_node_or_null("PanelIdentidadVinculada") as PanelContainer
	if not panel_id:
		panel_id = PanelContainer.new()
		panel_id.name = "PanelIdentidadVinculada"
		var sb_id := StyleBoxFlat.new()
		sb_id.bg_color = Color(0.05, 0.06, 0.08, 0.78)
		sb_id.set_border_width_all(1)
		sb_id.border_color = Color(0.78, 0.81, 0.85, 0.16)
		sb_id.set_corner_radius_all(10)
		sb_id.content_margin_left = 14
		sb_id.content_margin_right = 14
		sb_id.content_margin_top = 10
		sb_id.content_margin_bottom = 10
		panel_id.add_theme_stylebox_override("panel", sb_id)
		var lbl := Label.new()
		lbl.name = "LabelIdentidad"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if ResourceLoader.exists("res://recursos/fonts/Moderniz.otf"):
			lbl.add_theme_font_override("font", load("res://recursos/fonts/Moderniz.otf"))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.76, 0.80, 0.86, 0.88))
		panel_id.add_child(lbl)
		vbox_left.add_child(panel_id)

	var lbl_id := panel_id.get_node_or_null("LabelIdentidad") as Label
	if lbl_id:
		var correo := str(DatosUsuario.email_usuario).strip_edges() if "email_usuario" in DatosUsuario else ""
		var discord_u := str(DatosUsuario.discord_username).strip_edges() if "discord_username" in DatosUsuario else ""
		var prov := str(DatosUsuario.proveedor_auth).replace("supabase_", "").to_upper() if "proveedor_auth" in DatosUsuario else ""
		var partes: Array[String] = []
		if not prov.is_empty():
			partes.append("CUENTA: " + prov)
		if not correo.is_empty():
			partes.append("CORREO: " + correo)
		if not discord_u.is_empty():
			partes.append("DISCORD: " + discord_u)
		lbl_id.text = "  |  ".join(partes) if not partes.is_empty() else "MODO INVITADO (SIN VINCULAR)"

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

	if DatosUsuario.has_method("set_nombre_usuario"):
		DatosUsuario.set_nombre_usuario(nuevo_nombre, true)
	elif "nombre_usuario" in DatosUsuario:
		DatosUsuario.nombre_usuario = nuevo_nombre
		if DatosUsuario.has_method("save_local"):
			DatosUsuario.save_local()
			
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
	if DatosUsuario and "escenas_precargadas" in DatosUsuario and DatosUsuario.escenas_precargadas.has(ruta_moderna):
		var ps: PackedScene = DatosUsuario.escenas_precargadas[ruta_moderna] as PackedScene
		if ps:
			get_tree().change_scene_to_packed(ps)
			return
	if DatosUsuario:
		DatosUsuario.cambiar_escena(ruta_moderna)
	elif ResourceLoader.exists(ruta_moderna):
		get_tree().change_scene_to_file(ruta_moderna)
	else:
		push_error("No se encontró MainMenuModerno.tscn")

func _on_btn_cerrar_sesion_pressed() -> void:
	_play_sfx()

	var sb := get_node_or_null("/root/SupabaseManager")
	if sb and sb.has_method("cerrar_sesion"):
		sb.cerrar_sesion()

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
