extends Control

## Panel de verificacion de AdMob. Se puede ejecutar directamente en el editor
## (modo simulado) o en un dispositivo Android (anuncios de prueba reales).

const C_BG := Color(0.045, 0.05, 0.06, 1.0)
const C_PANEL := Color(0.08, 0.09, 0.11, 0.97)
const C_RECUADRO := Color(0.11, 0.12, 0.15, 0.98)
const C_BORDE := Color(0.78, 0.81, 0.85, 0.22)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.95)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_TEXTO := Color(0.92, 0.94, 0.96, 0.98)
const C_MUTED := Color(0.60, 0.64, 0.70, 0.92)
const C_VERDE := Color(0.32, 0.85, 0.58, 0.98)

const RUTA_FONT := "res://recursos/fonts/Moderniz.otf"

var _fuente: Font = null
var _log: RichTextLabel
var _estado: Label
var _recompensas: Label
var _btn_banner: Button
var _contador_recompensas := 0


func _ready() -> void:
	if ResourceLoader.exists(RUTA_FONT):
		_fuente = load(RUTA_FONT)
	_construir()
	_conectar()
	_escribir("Panel listo.")
	_escribir("Plataforma: %s" % GestorAnuncios.plataforma())
	_escribir("Modo: %s" % GestorAnuncios.modo_texto())
	_escribir("IDs: anuncios oficiales de PRUEBA de Google (sin cobro).")


func _construir() -> void:
	var fondo := ColorRect.new()
	fondo.color = C_BG
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var brillo := ColorRect.new()
	brillo.color = Color(0.88, 0.68, 0.28, 0.05)
	brillo.anchor_right = 1.0
	brillo.anchor_bottom = 0.32
	brillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brillo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 36)
	margen.add_theme_constant_override("margin_top", 28)
	margen.add_theme_constant_override("margin_right", 36)
	margen.add_theme_constant_override("margin_bottom", 28)
	add_child(margen)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margen.add_child(vbox)

	# Cabecera
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 18)
	vbox.add_child(cabecera)

	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.add_theme_constant_override("separation", 4)
	cabecera.add_child(titulos)

	var eyebrow := Label.new()
	eyebrow.text = "MONETIZACION / ADMOB"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", C_AMBER)
	titulos.add_child(eyebrow)

	var titulo := Label.new()
	titulo.text = "CENTRO DE PRUEBA DE ANUNCIOS"
	_aplicar_fuente(titulo, 40)
	titulo.add_theme_color_override("font_color", C_TEXTO)
	titulos.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Banner, intersticial y recompensado con IDs de prueba de Google."
	subtitulo.add_theme_font_size_override("font_size", 17)
	subtitulo.add_theme_color_override("font_color", C_MUTED)
	titulos.add_child(subtitulo)

	var badge := Label.new()
	badge.text = "MODO PRUEBA"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(170, 46)
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", C_AMBER)
	badge.add_theme_stylebox_override("normal", _estilo(Color(0.16, 0.14, 0.08, 0.9), C_AMBER, 10))
	cabecera.add_child(badge)

	# Cuerpo
	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 20)
	vbox.add_child(cuerpo)

	var panel_controles := PanelContainer.new()
	panel_controles.custom_minimum_size = Vector2(560, 0)
	panel_controles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_controles.add_theme_stylebox_override("panel", _estilo(C_PANEL, C_BORDE, 14))
	cuerpo.add_child(panel_controles)

	var margen_ctrl := MarginContainer.new()
	margen_ctrl.add_theme_constant_override("margin_left", 24)
	margen_ctrl.add_theme_constant_override("margin_top", 22)
	margen_ctrl.add_theme_constant_override("margin_right", 24)
	margen_ctrl.add_theme_constant_override("margin_bottom", 22)
	panel_controles.add_child(margen_ctrl)

	var vbox_ctrl := VBoxContainer.new()
	vbox_ctrl.add_theme_constant_override("separation", 12)
	margen_ctrl.add_child(vbox_ctrl)

	var rotulo := Label.new()
	rotulo.text = "ACCIONES DISPONIBLES"
	rotulo.add_theme_font_size_override("font_size", 13)
	rotulo.add_theme_color_override("font_color", C_AMBER)
	vbox_ctrl.add_child(rotulo)

	_btn_banner = _crear_boton("MOSTRAR BANNER", "Franja inferior adaptativa.")
	_btn_banner.pressed.connect(_on_banner)
	vbox_ctrl.add_child(_btn_banner)

	var btn_intersticial := _crear_boton("VER INTERSTICIAL", "Pantalla completa al cargar.")
	btn_intersticial.pressed.connect(_on_intersticial)
	vbox_ctrl.add_child(btn_intersticial)

	var btn_recompensado := _crear_boton("VER RECOMPENSADO", "+25 esmeraldas simuladas.")
	btn_recompensado.pressed.connect(_on_recompensado)
	vbox_ctrl.add_child(btn_recompensado)

	var btn_ocultar := _crear_boton("OCULTAR / DESTRUIR BANNER", "Limpia el banner actual.")
	btn_ocultar.pressed.connect(_on_ocultar)
	vbox_ctrl.add_child(btn_ocultar)

	_estado = Label.new()
	_estado.text = "ESTADO: en espera"
	_estado.add_theme_font_size_override("font_size", 15)
	_estado.add_theme_color_override("font_color", C_MUTED)
	vbox_ctrl.add_child(_estado)

	_recompensas = Label.new()
	_recompensas.text = "ESMERALDAS SIMULADAS: 0"
	_recompensas.add_theme_font_size_override("font_size", 20)
	_recompensas.add_theme_color_override("font_color", C_VERDE)
	vbox_ctrl.add_child(_recompensas)

	var nota := Label.new()
	nota.text = "En Android se usan los anuncios reales de prueba de Google. En PC no hay SDK nativo: el flujo se simula con las mismas senales."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_font_size_override("font_size", 14)
	nota.add_theme_color_override("font_color", C_MUTED)
	vbox_ctrl.add_child(nota)

	# Registro
	var panel_log := PanelContainer.new()
	panel_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_log.add_theme_stylebox_override("panel", _estilo(C_PANEL, C_BORDE, 14))
	cuerpo.add_child(panel_log)

	var margen_log := MarginContainer.new()
	margen_log.add_theme_constant_override("margin_left", 20)
	margen_log.add_theme_constant_override("margin_top", 18)
	margen_log.add_theme_constant_override("margin_right", 20)
	margen_log.add_theme_constant_override("margin_bottom", 18)
	panel_log.add_child(margen_log)

	var vbox_log := VBoxContainer.new()
	vbox_log.add_theme_constant_override("separation", 10)
	margen_log.add_child(vbox_log)

	var rotulo_log := Label.new()
	rotulo_log.text = "REGISTRO DE EVENTOS"
	rotulo_log.add_theme_font_size_override("font_size", 13)
	rotulo_log.add_theme_color_override("font_color", C_AMBER)
	vbox_log.add_child(rotulo_log)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.bbcode_enabled = false
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.add_theme_color_override("default_color", C_TEXTO)
	_log.add_theme_stylebox_override("normal", _estilo(Color(0.04, 0.05, 0.06, 0.9), C_BORDE, 10))
	vbox_log.add_child(_log)


func _crear_boton(titulo: String, detalle: String) -> Button:
	var btn := Button.new()
	btn.text = titulo + "\n" + detalle
	btn.custom_minimum_size = Vector2(0, 84)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", C_TEXTO)
	btn.add_theme_stylebox_override("normal", _estilo(C_RECUADRO, C_BORDE, 12))
	btn.add_theme_stylebox_override("hover", _estilo(Color(0.16, 0.15, 0.11, 0.98), C_AMBER, 12))
	btn.add_theme_stylebox_override("pressed", _estilo(Color(0.20, 0.17, 0.09, 1.0), C_AMBER, 12))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


func _estilo(fondo: Color, borde: Color, radio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(1)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _aplicar_fuente(etiqueta: Label, tamano: int) -> void:
	if _fuente:
		etiqueta.add_theme_font_override("font", _fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)


func _conectar() -> void:
	GestorAnuncios.inicializacion_terminada.connect(_on_inicializacion)
	GestorAnuncios.banner_cargado.connect(func() -> void: _escribir("Banner cargado."))
	GestorAnuncios.banner_cerrado.connect(func() -> void: _escribir("Banner oculto/destruido."))
	GestorAnuncios.intersticial_cargado.connect(func() -> void: _escribir("Intersticial cargado."))
	GestorAnuncios.intersticial_cerrado.connect(func() -> void: _escribir("Intersticial cerrado."))
	GestorAnuncios.recompensado_cargado.connect(func() -> void: _escribir("Recompensado cargado."))
	GestorAnuncios.recompensa_obtenida.connect(_on_recompensa)
	GestorAnuncios.anuncio_fallido.connect(_on_fallo)
	GestorAnuncios.simulacion_ejecutada.connect(func(formato: String) -> void: _escribir("Simulando: " + formato))


func _on_inicializacion(ok: bool) -> void:
	_estado.text = "ESTADO: inicializado" if ok else "ESTADO: error de inicializacion"
	_estado.add_theme_color_override("font_color", C_VERDE if ok else C_CRIMSON)


func _on_banner() -> void:
	GestorAnuncios.mostrar_banner()
	_estado.text = "ESTADO: solicitando banner"
	_estado.add_theme_color_override("font_color", C_AMBER)
	_btn_banner.text = "OCULTAR BANNER\nFranja inferior adaptativa."


func _on_intersticial() -> void:
	GestorAnuncios.mostrar_intersticial()
	_estado.text = "ESTADO: solicitando intersticial"
	_estado.add_theme_color_override("font_color", C_AMBER)


func _on_recompensado() -> void:
	GestorAnuncios.mostrar_recompensado()
	_estado.text = "ESTADO: solicitando recompensado"
	_estado.add_theme_color_override("font_color", C_AMBER)


func _on_ocultar() -> void:
	GestorAnuncios.destruir_banner()
	_estado.text = "ESTADO: banner destruido"
	_estado.add_theme_color_override("font_color", C_MUTED)
	_btn_banner.text = "MOSTRAR BANNER\nFranja inferior adaptativa."


func _on_recompensa(cantidad: int, tipo: String) -> void:
	_contador_recompensas += cantidad
	_recompensas.text = "ESMERALDAS SIMULADAS: %d" % _contador_recompensas
	_escribir("Recompensa: +%d %s" % [cantidad, tipo])
	_estado.text = "ESTADO: recompensa acreditada"
	_estado.add_theme_color_override("font_color", C_VERDE)


func _on_fallo(formato: String, mensaje: String) -> void:
	_escribir("ERROR %s: %s" % [formato, mensaje])
	_estado.text = "ESTADO: error en " + formato
	_estado.add_theme_color_override("font_color", C_CRIMSON)


func _escribir(texto: String) -> void:
	if _log:
		_log.append_text("> " + texto + "\n")
	print("[PruebaAnuncios] " + texto)
