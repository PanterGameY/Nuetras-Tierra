extends Control

# ═══════════════════════════════════════════════════════════════════════
# pase_elite.gd — Pase Élite (membresía + recompensas diarias)
# ═══════════════════════════════════════════════════════════════════════
# Sigue el sistema de diseño de documentacion/interfaz_ui/manual_diseno_ui.md:
#   · Cristal ahumado + borde frost de 1px
#   · Acento ámbar para acciones y estados disponibles
#   · Tipografía Moderniz y botones de 58-100 px
#   · Entrada animada con Tweens y efectos de pulso
# La lógica económica vive en DatosUsuario (comprar_pase_elite,
# reclamar_pase_diario); esta pantalla solo presenta y anima.
# ═══════════════════════════════════════════════════════════════════════

const FONT := preload("res://recursos/fonts/Moderniz.otf")
const ESCENA_MENU := "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const MONEDA := preload("res://recursos/botones/money.png")
const SFX_ACTIVACION := preload("res://recursos/efectos/level_up.mp3")
const SFX_PREMIO := preload("res://recursos/efectos/money.mp3")

const C_AMBER := Color(0.88, 0.68, 0.28, 1.0)
const C_AMBER_BRIGHT := Color(1.0, 0.82, 0.45, 1.0)
const C_INK := Color(0.09, 0.07, 0.03, 1.0)
const C_TEXT := Color(0.88, 0.90, 0.93, 0.95)
const C_MUTED := Color(0.50, 0.54, 0.58, 0.85)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_BORDER_BRIGHT := Color(0.85, 0.88, 0.92, 0.42)

var _tarjetas: Array[PanelContainer] = []
var _puede_reclamar: bool = false
var _toast_tween: Tween = null
var _sfx_activacion: AudioStreamPlayer = null
var _sfx_premio: AudioStreamPlayer = null
var _tw_halo: Tween = null
var _tw_icono: Tween = null
var _tw_anillo: Tween = null
var _icono_base: Vector2 = Vector2.ZERO
var _premio_monedas: int = 0

@onready var header: HBoxContainer = $Main/VBox/Header
@onready var brillo_ambar: TextureRect = $BrilloAmbar
@onready var brillo_frio: TextureRect = $BrilloFrio

@onready var btn_volver: Button = $Main/VBox/Header/BtnVolver
@onready var barra_divisas: BarraDivisas = $Main/VBox/Header/EconomyPill

@onready var panel_hero: PanelContainer = $Main/VBox/Body/PanelHero
@onready var label_precio: Label = $Main/VBox/Body/PanelHero/VBoxHero/HBoxPrecio/LabelPrecio
@onready var label_precio_nota: Label = (
	$Main/VBox/Body/PanelHero/VBoxHero/HBoxPrecio/LabelPrecioNota
)
@onready var btn_comprar: Button = $Main/VBox/Body/PanelHero/VBoxHero/BtnComprar
@onready var label_membresia: Label = $Main/VBox/Body/PanelHero/VBoxHero/LabelMembresia

@onready var panel_dias: PanelContainer = $Main/VBox/Body/PanelDias
@onready var label_ciclo: Label = (
	$Main/VBox/Body/PanelDias/VBoxDias/HBoxCabecera/LabelCiclo
)
@onready var label_proximo: Label = (
	$Main/VBox/Body/PanelDias/VBoxDias/HBoxPie/VBoxEstado/LabelProximo
)
@onready var label_ayuda: Label = (
	$Main/VBox/Body/PanelDias/VBoxDias/HBoxPie/VBoxEstado/LabelAyuda
)
@onready var btn_reclamar: Button = $Main/VBox/Body/PanelDias/VBoxDias/HBoxPie/BtnReclamar

@onready var chip_monedas: Label = (
	$Main/VBox/Body/PanelDias/VBoxDias/HBoxResumen/ChipMonedas/VBox/LabelValor
)
@onready var chip_xp: Label = (
	$Main/VBox/Body/PanelDias/VBoxDias/HBoxResumen/ChipXp/VBox/LabelValor
)
@onready var chip_dias: Label = (
	$Main/VBox/Body/PanelDias/VBoxDias/HBoxResumen/ChipDias/VBox/LabelValor
)

@onready var overlay_recompensa: Control = $OverlayRecompensa
@onready var panel_recompensa: PanelContainer = $OverlayRecompensa/Centro/PanelRecompensa
@onready var rec_cabecera: Label = $OverlayRecompensa/Centro/PanelRecompensa/VBox/LabelCabecera
@onready var rec_icono: TextureRect = $OverlayRecompensa/Centro/PanelRecompensa/VBox/Icono
@onready var rec_monto: Label = $OverlayRecompensa/Centro/PanelRecompensa/VBox/LabelMonto
@onready var rec_xp: Label = $OverlayRecompensa/Centro/PanelRecompensa/VBox/LabelXp
@onready var rec_dia: Label = $OverlayRecompensa/Centro/PanelRecompensa/VBox/LabelDia
@onready var btn_continuar: Button = (
	$OverlayRecompensa/Centro/PanelRecompensa/VBox/BtnContinuar
)

@onready var overlay_compra: Control = $OverlayCompra
@onready var panel_compra: PanelContainer = $OverlayCompra/Centro/PanelCompra
@onready var compra_texto: Label = $OverlayCompra/Centro/PanelCompra/VBox/LabelTexto
@onready var btn_cancelar: Button = $OverlayCompra/Centro/PanelCompra/VBox/HBoxBotones/BtnCancelar
@onready var btn_confirmar: Button = (
	$OverlayCompra/Centro/PanelCompra/VBox/HBoxBotones/BtnConfirmar
)

@onready var overlay_activacion: Control = $OverlayActivacion
@onready var panel_activacion: PanelContainer = (
	$OverlayActivacion/Centro/PanelActivacion
)
@onready var activ_brillo: TextureRect = $OverlayActivacion/Brillo
@onready var activ_particulas: Control = $OverlayActivacion/Particulas
@onready var activ_destello: ColorRect = $OverlayActivacion/Destello
@onready var activ_halo: TextureRect = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Sello/Halo
)
@onready var activ_anillo: Panel = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Sello/Anillo
)
@onready var activ_icono: TextureRect = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Sello/Icono
)
@onready var activ_sello_label: Label = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Sello/LabelSello
)
@onready var activ_kicker: Label = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Contenido/Kicker
)
@onready var activ_titulo: Label = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Contenido/LabelTituloActivacion
)
@onready var activ_sub: Label = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Contenido/LabelSubActivacion
)
@onready var activ_separador: HSeparator = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Contenido/SeparadorActivacion
)
@onready var activ_chips: HBoxContainer = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Contenido/ChipsActivacion
)
@onready var activ_chip_premio_valor: Label = (
	activ_chips.get_node("ChipPremio/VBox/LabelValor") as Label
)
@onready var activ_nota: Label = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Cuerpo/Contenido/LabelNotaActivacion
)
@onready var activ_botones: HBoxContainer = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Pie/HBox
)
@onready var activ_miembro: Label = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Pie/HBox/LabelMiembroActivacion
)
@onready var btn_activ_luego: Button = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Pie/HBox/BtnActivacionLuego
)
@onready var btn_activ_reclamar: Button = (
	$OverlayActivacion/Centro/PanelActivacion/VBox/Pie/HBox/BtnActivacionReclamar
)

@onready var toast_panel: PanelContainer = $Toast
@onready var toast_label: Label = $Toast/Label


func _ready() -> void:
	_preparar_audio()
	_aplicar_estilos_botones()
	_conectar_botones()
	_preparar_tarjetas()
	_actualizar_vista()
	_animar_entrada()
	_animar_brillos()

	var reloj := Timer.new()
	reloj.name = "RelojPase"
	reloj.wait_time = 1.0
	reloj.autostart = true
	reloj.timeout.connect(_on_reloj_timeout)
	add_child(reloj)


func _preparar_audio() -> void:
	_sfx_activacion = AudioStreamPlayer.new()
	_sfx_activacion.name = "SFXActivacion"
	_sfx_activacion.stream = SFX_ACTIVACION
	_sfx_activacion.volume_db = -2.0
	add_child(_sfx_activacion)

	_sfx_premio = AudioStreamPlayer.new()
	_sfx_premio.name = "SFXPremio"
	_sfx_premio.stream = SFX_PREMIO
	_sfx_premio.volume_db = -2.0
	add_child(_sfx_premio)


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if overlay_activacion.visible:
		_cerrar_activacion()
	elif overlay_compra.visible:
		_ocultar_overlay(overlay_compra, panel_compra)
	elif overlay_recompensa.visible:
		_ocultar_overlay(overlay_recompensa, panel_recompensa)
	else:
		_volver()


# ═══════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE ESTILOS
# ═══════════════════════════════════════════════════════════════════════

func _crear_estilo(fondo: Color, borde: Color, radio: int, sombra: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(1)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	if sombra > 0:
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		sb.shadow_size = sombra
		sb.shadow_offset = Vector2(0, 4)
	return sb


func _aplicar_estilos_botones() -> void:
	_aplicar_boton_primario(btn_comprar, 22)
	_aplicar_boton_primario(btn_reclamar, 21)
	_aplicar_boton_primario(btn_confirmar, 20)
	_aplicar_boton_primario(btn_continuar, 20)
	_aplicar_boton_primario(btn_activ_reclamar, 20)
	_aplicar_boton_fantasma(btn_volver, 18)
	_aplicar_boton_fantasma(btn_cancelar, 20)
	_aplicar_boton_fantasma(btn_activ_luego, 19)

	for btn in [
		btn_comprar, btn_reclamar, btn_confirmar, btn_continuar, btn_activ_reclamar
	]:
		_preparar_boton(btn, 1.02)
	for btn in [btn_volver, btn_cancelar, btn_activ_luego]:
		_preparar_boton(btn, 1.03)


func _aplicar_boton_primario(btn: Button, tam: int) -> void:
	var normal := _crear_estilo(C_AMBER, Color(1.0, 0.86, 0.55, 0.9), 12)
	normal.shadow_color = Color(0.88, 0.68, 0.28, 0.22)
	normal.shadow_size = 14
	normal.shadow_offset = Vector2(0, 4)

	var hover := _crear_estilo(Color(0.96, 0.77, 0.37, 1.0), Color(1.0, 0.92, 0.66, 1.0), 12)
	hover.shadow_color = Color(0.88, 0.68, 0.28, 0.36)
	hover.shadow_size = 18
	hover.shadow_offset = Vector2(0, 4)

	var pressed := _crear_estilo(Color(0.78, 0.58, 0.22, 1.0), C_AMBER, 12)
	var disabled := _crear_estilo(Color(1.0, 1.0, 1.0, 0.05), C_BORDER_FROST, 12)

	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = Color(1.0, 1.0, 1.0, 0.85)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", tam)
	btn.add_theme_color_override("font_color", C_INK)
	btn.add_theme_color_override("font_hover_color", C_INK)
	btn.add_theme_color_override("font_pressed_color", C_INK)
	btn.add_theme_color_override("font_focus_color", C_INK)
	btn.add_theme_color_override("font_disabled_color", C_MUTED)


func _aplicar_boton_fantasma(btn: Button, tam: int) -> void:
	var normal := _crear_estilo(Color(1.0, 1.0, 1.0, 0.04), C_BORDER_FROST, 10)
	var hover := _crear_estilo(Color(1.0, 1.0, 1.0, 0.10), C_BORDER_BRIGHT, 10)
	var pressed := _crear_estilo(Color(0.88, 0.68, 0.28, 0.16), C_AMBER, 10)
	var disabled := _crear_estilo(Color(1.0, 1.0, 1.0, 0.02), C_BORDER_FROST, 10)

	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = C_AMBER

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", tam)
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_AMBER_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", C_AMBER_BRIGHT)
	btn.add_theme_color_override("font_focus_color", C_AMBER)
	btn.add_theme_color_override("font_disabled_color", C_MUTED)


func _estilo_carta(estado: String, bono: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0

	if estado == "disponible":
		sb.bg_color = Color(0.88, 0.68, 0.28, 0.12)
		sb.border_color = Color(0.88, 0.68, 0.28, 0.85)
		sb.shadow_color = Color(0.88, 0.68, 0.28, 0.20)
		sb.shadow_size = 14
	elif estado == "reclamado":
		sb.bg_color = Color(0.07, 0.08, 0.09, 0.70)
		sb.border_color = Color(0.78, 0.81, 0.85, 0.12)
	else:
		sb.bg_color = Color(0.04, 0.05, 0.06, 0.55)
		sb.border_color = Color(0.78, 0.81, 0.85, 0.09)

	if bono and estado != "disponible":
		sb.border_color = Color(0.88, 0.68, 0.28, 0.32)
	return sb


# ═══════════════════════════════════════════════════════════════════════
# TARJETAS Y ESTADO
# ═══════════════════════════════════════════════════════════════════════

func _preparar_tarjetas() -> void:
	var encontradas := find_children("Dia*", "PanelContainer", true, false)
	var por_nombre := {}
	for nodo in encontradas:
		por_nombre[String(nodo.name)] = nodo
	for i in range(1, 8):
		var carta := por_nombre.get("Dia%d" % i, null) as PanelContainer
		if carta == null:
			continue
		_tarjetas.append(carta)
		carta.resized.connect(_actualizar_pivote.bind(carta))
		carta.mouse_entered.connect(_escalar_control.bind(carta, 1.015))
		carta.mouse_exited.connect(_escalar_control.bind(carta, 1.0))
		carta.gui_input.connect(_on_tarjeta_gui_input.bind(carta))
		_actualizar_pivote(carta)


func _actualizar_vista() -> void:
	var premios: Array = DatosUsuario.recompensas_pase()
	var activo: bool = DatosUsuario.tiene_pase_elite()
	var dia_actual: int = DatosUsuario.dia_pase_actual()
	var ciclo: int = DatosUsuario.ciclo_pase_actual()
	var puede: bool = DatosUsuario.puede_reclamar_pase()
	_puede_reclamar = puede

	_actualizar_economia()
	_actualizar_resumen(premios)

	for i in _tarjetas.size():
		var premio: Dictionary = {}
		if i < premios.size():
			premio = premios[i]
		_actualizar_tarjeta(_tarjetas[i], i + 1, premio, activo, dia_actual, puede)

	if activo:
		label_ciclo.text = "CICLO %d · DIA %d DE 7" % [ciclo, dia_actual]
	else:
		label_ciclo.text = "SIN MEMBRESIA ACTIVA"

	if activo:
		btn_comprar.disabled = true
		btn_comprar.text = "PASE ACTIVO"
		label_precio.text = "ACTIVO"
		label_precio_nota.text = "TU MEMBRESIA ESTA VIGENTE"
		label_membresia.text = "MIEMBRO DESDE %s" % _fecha_legible(
			DatosUsuario.pase_elite_desde
		)
		btn_reclamar.disabled = not puede
		if puede:
			btn_reclamar.text = "RECLAMAR DIA %d" % dia_actual
			label_proximo.text = "RECOMPENSA DISPONIBLE AHORA"
			label_ayuda.text = "Un reclamo cada 24 h. El ciclo se repite cada semana."
		else:
			var cuenta := _texto_cuenta_atras(DatosUsuario.segundos_hasta_proximo_pase())
			btn_reclamar.text = "RECLAMADO · " + cuenta
			label_proximo.text = "PROXIMO RECLAMO EN " + cuenta
			label_ayuda.text = "Vuelve en 24 h para seguir tu racha."
	else:
		var costo := DatosUsuario.costo_pase_elite()
		var faltante := costo - DatosUsuario.dinero
		label_precio.text = _formatear_dinero(costo)
		label_precio_nota.text = "PAGO UNICO · PARA SIEMPRE"
		btn_comprar.disabled = faltante > 0.0
		btn_comprar.text = "ACTIVAR PASE ELITE" if faltante <= 0.0 else "EFECTIVO INSUFICIENTE"
		if faltante > 0.0:
			label_membresia.text = "TE FALTAN %s PARA ACTIVARLO" % _formatear_dinero(faltante)
		else:
			label_membresia.text = "AUN NO ERES MIEMBRO"
		btn_reclamar.disabled = true
		btn_reclamar.text = "ACTIVA EL PASE PARA RECLAMAR"
		label_proximo.text = "SIN MEMBRESIA ACTIVA"
		label_ayuda.text = "Compra el pase para empezar a reclamar recompensas."


func _actualizar_tarjeta(
	carta: PanelContainer,
	dia: int,
	premio: Dictionary,
	activo: bool,
	dia_actual: int,
	puede: bool
) -> void:
	var label_dia := carta.get_node_or_null("VBox/HBoxTop/LabelDia") as Label
	var label_estado := carta.get_node_or_null("VBox/HBoxTop/LabelEstadoDia") as Label
	var label_monedas := carta.get_node_or_null("VBox/HBoxValor/LabelMonedas") as Label
	var label_xp := carta.get_node_or_null("VBox/LabelXp") as Label
	var label_nota := carta.get_node_or_null("VBox/LabelNota") as Label

	var bono := bool(premio.get("bono", false))
	if label_dia:
		label_dia.text = "DIA %d · BONO" % dia if bono else "DIA %d" % dia
	if label_monedas:
		label_monedas.text = "+$ %s" % _miles(int(premio.get("monedas", 0.0)))
	if label_xp:
		label_xp.text = "+%s XP" % _miles(int(premio.get("experiencia", 0)))
	if label_nota:
		label_nota.text = "BONO DEL CICLO" if bono else "MONEDAS + EXPERIENCIA"

	var estado := "bloqueado"
	if not activo:
		if label_estado:
			label_estado.text = "BLOQUEADO"
	elif dia < dia_actual:
		estado = "reclamado"
		if label_estado:
			label_estado.text = "RECLAMADO"
	elif dia == dia_actual:
		if puede:
			estado = "disponible"
			if label_estado:
				label_estado.text = "DISPONIBLE"
		else:
			estado = "reclamado"
			if label_estado:
				label_estado.text = "RECLAMADO HOY"
	else:
		if label_estado:
			label_estado.text = "EN ESPERA"

	carta.set_meta("estado", estado)
	carta.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if estado == "disponible" else Control.CURSOR_ARROW
	)
	if estado != "disponible":
		var pulso_previo = carta.get_meta("tw_pulso") if carta.has_meta("tw_pulso") else null
		if pulso_previo is Tween and pulso_previo.is_valid():
			pulso_previo.kill()
		if carta.has_meta("tw_pulso"):
			carta.remove_meta("tw_pulso")
	carta.add_theme_stylebox_override("panel", _estilo_carta(estado, bono))

	match estado:
		"disponible":
			carta.modulate = Color(1, 1, 1, 1)
			_pulsar_tarjeta(carta)
		"reclamado":
			carta.modulate = Color(1, 1, 1, 0.58)
		_:
			carta.modulate = Color(1, 1, 1, 0.44)

	if label_estado:
		if estado == "disponible":
			label_estado.add_theme_color_override("font_color", C_AMBER_BRIGHT)
		else:
			label_estado.add_theme_color_override("font_color", C_MUTED)


func _actualizar_resumen(premios: Array) -> void:
	var total_monedas := 0.0
	var total_xp := 0
	for premio in premios:
		var dato: Dictionary = premio
		total_monedas += float(dato.get("monedas", 0.0))
		total_xp += int(dato.get("experiencia", 0))
	if chip_monedas:
		chip_monedas.text = _miles(int(total_monedas))
	if chip_xp:
		chip_xp.text = _miles(total_xp)
	if chip_dias:
		chip_dias.text = str(premios.size())


func _actualizar_economia() -> void:
	var dinero: float = float(DatosUsuario.dinero)
	var esmeraldas: int = int(DatosUsuario.esmeraldas)

	if barra_divisas:
		barra_divisas.set_valores(dinero, esmeraldas)


func _pulsar_tarjeta(carta: PanelContainer) -> void:
	var previo = carta.get_meta("tw_pulso") if carta.has_meta("tw_pulso") else null
	if previo is Tween and previo.is_valid():
		previo.kill()
	var sb := carta.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	var tw: Tween = carta.create_tween().set_loops()
	tw.tween_property(sb, "border_color", C_AMBER_BRIGHT, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(
		sb, "border_color", Color(0.88, 0.68, 0.28, 0.35), 1.1
	).set_trans(Tween.TRANS_SINE)
	carta.set_meta("tw_pulso", tw)


# ═══════════════════════════════════════════════════════════════════════
# ACCIONES
# ═══════════════════════════════════════════════════════════════════════

func _conectar_botones() -> void:
	btn_volver.pressed.connect(_volver)
	btn_comprar.pressed.connect(_on_comprar_pressed)
	btn_reclamar.pressed.connect(_on_reclamar_pressed)
	btn_continuar.pressed.connect(_cerrar_recompensa)
	btn_cancelar.pressed.connect(_cerrar_compra)
	btn_confirmar.pressed.connect(_confirmar_compra)
	btn_activ_luego.pressed.connect(_cerrar_activacion)
	btn_activ_reclamar.pressed.connect(_reclamar_desde_activacion)
	$OverlayCompra/Fondo.gui_input.connect(_on_fondo_compra_input)
	$OverlayRecompensa/Fondo.gui_input.connect(_on_fondo_recompensa_input)


func _on_comprar_pressed() -> void:
	if DatosUsuario.tiene_pase_elite():
		_mostrar_toast("TU PASE YA ESTA ACTIVO")
		return
	var costo := DatosUsuario.costo_pase_elite()
	if DatosUsuario.dinero < costo:
		_mostrar_toast("EFECTIVO INSUFICIENTE")
		return
	compra_texto.text = (
		"Esta compra descuenta %s de tu efectivo. Recibes una recompensa cada 24 h "
		+ "mientras el pase siga activo. El bono de experiencia empieza al instante."
	) % _formatear_dinero(costo)
	_mostrar_overlay(overlay_compra, panel_compra)


func _confirmar_compra() -> void:
	_cerrar_compra()
	if DatosUsuario.comprar_pase_elite():
		_actualizar_vista()
		_pulso_etiqueta(label_precio)
		_pulso_etiqueta(btn_reclamar)
		_animar_activacion()
	else:
		_mostrar_toast("NO SE PUDO COMPLETAR LA COMPRA")


func _on_reclamar_pressed() -> void:
	var resultado := DatosUsuario.reclamar_pase_diario()
	if resultado.is_empty():
		_mostrar_toast("YA RECLAMASTE LA RECOMPENSA DE HOY")
		_actualizar_vista()
		return
	_reproducir(_sfx_premio)
	_actualizar_vista()
	var indice := clampi(int(resultado.get("dia", 1)) - 1, 0, _tarjetas.size() - 1)
	if indice >= 0 and indice < _tarjetas.size():
		_flotar_texto(
			_tarjetas[indice], "+$ %s" % _miles(int(resultado.get("monedas", 0.0)))
		)
	await get_tree().create_timer(0.30).timeout
	_animar_recompensa(resultado)


func _animar_recompensa(resultado: Dictionary) -> void:
	var bono := bool(resultado.get("bono", false))
	rec_cabecera.text = "BONO DEL CICLO" if bono else "RECOMPENSA DIARIA"
	rec_monto.text = "+$ %s" % _miles(int(resultado.get("monedas", 0.0)))
	rec_xp.text = "+%s XP" % _miles(int(resultado.get("experiencia", 0)))
	rec_dia.text = "DIA %d DE 7" % int(resultado.get("dia", 1))
	if rec_icono:
		_actualizar_pivote(rec_icono)
		var twi := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		twi.tween_property(rec_icono, "scale", Vector2(1.25, 1.25), 0.18)
		twi.tween_property(rec_icono, "scale", Vector2.ONE, 0.30)
	_mostrar_overlay(overlay_recompensa, panel_recompensa)


func _cerrar_recompensa() -> void:
	_ocultar_overlay(overlay_recompensa, panel_recompensa)


func _cerrar_compra() -> void:
	_ocultar_overlay(overlay_compra, panel_compra)


# ═══════════════════════════════════════════════════════════════════════
# ACTIVACION DE LA MEMBRESIA
# ═══════════════════════════════════════════════════════════════════════
# La compra se celebra como un desbloqueo: destello, estallido de monedas,
# sello que brota con rebote, panel escalonado y CTA para el primer premio.

func _animar_activacion() -> void:
	if overlay_activacion == null or overlay_activacion.visible:
		return
	_preparar_panel_activacion()
	_reproducir(_sfx_activacion)

	overlay_activacion.visible = true
	overlay_activacion.modulate.a = 0.0
	await get_tree().process_frame
	_reset_estado_activacion()

	var tw_fondo := create_tween().set_parallel(true)
	tw_fondo.tween_property(overlay_activacion, "modulate:a", 1.0, 0.20)
	tw_fondo.tween_property(activ_brillo, "modulate:a", 0.95, 0.42)
	tw_fondo.tween_property(activ_destello, "color", Color(1.0, 0.86, 0.58, 0.0), 0.55).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tw_fondo.tween_property(activ_halo, "modulate:a", 0.95, 0.36).set_delay(0.06)

	var tw_icono := create_tween().set_parallel(true)
	tw_icono.tween_property(activ_icono, "scale", Vector2.ONE, 0.66).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT).set_delay(0.04)
	tw_icono.tween_property(activ_icono, "rotation", 0.0, 0.74).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT).set_delay(0.04)
	tw_icono.tween_property(activ_icono, "modulate:a", 1.0, 0.20).set_delay(0.04)

	var tw_anillo := create_tween().set_parallel(true)
	tw_anillo.tween_property(activ_anillo, "scale", Vector2.ONE, 0.78).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT).set_delay(0.02)
	tw_anillo.tween_property(activ_anillo, "modulate:a", 1.0, 0.30).set_delay(0.02)
	tw_anillo.tween_property(activ_sello_label, "modulate:a", 1.0, 0.40).set_delay(0.34)

	var tw_panel := create_tween().set_parallel(true)
	tw_panel.tween_property(panel_activacion, "scale", Vector2.ONE, 0.54).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT).set_delay(0.10)
	tw_panel.tween_property(panel_activacion, "modulate:a", 1.0, 0.24).set_delay(0.10)

	_entrada_escalonada()

	await get_tree().create_timer(0.16).timeout
	if not overlay_activacion.visible:
		return
	_lanzar_particulas(
		activ_icono.get_global_rect().get_center()
		- activ_particulas.get_global_rect().position
	)

	await get_tree().create_timer(0.34).timeout
	if not overlay_activacion.visible:
		return
	_contar_premio()
	_animar_crest_loop()
	if btn_activ_reclamar:
		btn_activ_reclamar.grab_focus()


func _preparar_panel_activacion() -> void:
	var premio: Dictionary = DatosUsuario.recompensa_pase_dia(
		DatosUsuario.dia_pase_actual()
	)
	_premio_monedas = int(premio.get("monedas", 0.0))
	if activ_chip_premio_valor:
		activ_chip_premio_valor.text = "+$ 0"
	if activ_miembro:
		activ_miembro.text = "MIEMBRO DESDE %s" % _fecha_legible(
			DatosUsuario.pase_elite_desde
		)


func _contar_premio() -> void:
	if activ_chip_premio_valor == null or _premio_monedas <= 0:
		return
	var tw := create_tween()
	tw.tween_method(_escribir_premio, 0.0, float(_premio_monedas), 0.85).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_pulso_etiqueta.bind(activ_chip_premio_valor))


func _escribir_premio(valor: float) -> void:
	if activ_chip_premio_valor:
		activ_chip_premio_valor.text = "+$ %s" % _miles(int(round(valor)))


func _reset_estado_activacion() -> void:
	activ_brillo.modulate = Color(1.0, 0.92, 0.74, 0.0)
	activ_halo.modulate = Color(1.0, 0.86, 0.62, 0.0)
	activ_destello.color = Color(1.0, 0.86, 0.58, 0.72)

	_actualizar_pivote(activ_icono)
	activ_icono.modulate.a = 0.0
	activ_icono.scale = Vector2(0.25, 0.25)
	activ_icono.rotation = deg_to_rad(-24.0)
	_icono_base = activ_icono.position

	_actualizar_pivote(activ_anillo)
	activ_anillo.modulate.a = 0.0
	activ_anillo.scale = Vector2(0.82, 0.82)
	activ_sello_label.modulate.a = 0.0

	_actualizar_pivote(panel_activacion)
	panel_activacion.modulate.a = 0.0
	panel_activacion.scale = Vector2(0.90, 0.90)


func _entrada_escalonada() -> void:
	var piezas: Array[Control] = [
		activ_kicker,
		activ_titulo,
		activ_sub,
		activ_chips,
		activ_nota,
		activ_miembro,
		activ_botones,
	]
	for i in piezas.size():
		var pieza: Control = piezas[i]
		if pieza == null:
			continue
		var retardo := 0.26 + 0.055 * float(i)
		pieza.modulate.a = 0.0
		_actualizar_pivote(pieza)
		pieza.scale = Vector2(0.96, 0.96)

		var tw := create_tween().set_parallel(true)
		tw.tween_property(pieza, "modulate:a", 1.0, 0.30).set_delay(retardo).set_trans(
			Tween.TRANS_SINE
		)
		tw.tween_property(pieza, "scale", Vector2.ONE, 0.36).set_delay(retardo).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)

	_actualizar_pivote(activ_separador)
	activ_separador.modulate.a = 0.0
	activ_separador.scale = Vector2(0.15, 1.0)
	var tw_sep := create_tween().set_parallel(true)
	tw_sep.tween_property(activ_separador, "scale:x", 1.0, 0.42).set_delay(0.22).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	tw_sep.tween_property(activ_separador, "modulate:a", 1.0, 0.22).set_delay(0.22)


func _animar_crest_loop() -> void:
	if _tw_halo and _tw_halo.is_valid():
		_tw_halo.kill()
	_tw_halo = create_tween().set_loops()
	_tw_halo.tween_property(activ_halo, "modulate:a", 0.45, 2.2).set_trans(
		Tween.TRANS_SINE
	)
	_tw_halo.tween_property(activ_halo, "modulate:a", 0.9, 2.2).set_trans(
		Tween.TRANS_SINE
	)

	if _tw_icono and _tw_icono.is_valid():
		_tw_icono.kill()
	_tw_icono = create_tween().set_loops()
	_tw_icono.tween_property(activ_icono, "position:y", _icono_base.y - 6.0, 1.8).set_trans(
		Tween.TRANS_SINE
	)
	_tw_icono.tween_property(activ_icono, "position:y", _icono_base.y, 1.8).set_trans(
		Tween.TRANS_SINE
	)

	var estilo := activ_anillo.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo:
		var anillo := estilo.duplicate() as StyleBoxFlat
		activ_anillo.add_theme_stylebox_override("panel", anillo)
		if _tw_anillo and _tw_anillo.is_valid():
			_tw_anillo.kill()
		_tw_anillo = create_tween().set_loops()
		_tw_anillo.tween_property(
			anillo, "border_color", Color(0.88, 0.68, 0.28, 0.62), 1.9
		).set_trans(Tween.TRANS_SINE)
		_tw_anillo.tween_property(
			anillo, "border_color", Color(0.88, 0.68, 0.28, 0.20), 1.9
		).set_trans(Tween.TRANS_SINE)


func _lanzar_particulas(centro: Vector2) -> void:
	if activ_particulas == null:
		return
	for previo in activ_particulas.get_children():
		previo.queue_free()

	for i in 18:
		var chispa := ColorRect.new()
		var lado := randf_range(4.0, 9.0)
		chispa.size = Vector2(lado, lado)
		chispa.position = centro - Vector2(lado, lado) * 0.5
		chispa.pivot_offset = Vector2(lado, lado) * 0.5
		chispa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chispa.color = Color(
			1.0, randf_range(0.72, 0.92), randf_range(0.34, 0.56), 0.95
		)
		activ_particulas.add_child(chispa)

		var angulo := randf_range(0.0, TAU)
		var destino := centro + Vector2(cos(angulo), sin(angulo)) * randf_range(
			110.0, 290.0
		)
		var tw := chispa.create_tween().set_parallel(true)
		tw.tween_property(chispa, "position", destino, randf_range(0.55, 0.95)).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)
		tw.tween_property(chispa, "modulate:a", 0.0, randf_range(0.45, 0.80)).set_delay(0.10)
		tw.tween_property(chispa, "scale", Vector2(0.2, 0.2), 0.72)
		tw.chain().tween_callback(chispa.queue_free)

	for i in 5:
		var moneda := TextureRect.new()
		moneda.texture = MONEDA
		moneda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		moneda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		moneda.size = Vector2(28, 28)
		moneda.position = centro - Vector2(14, 14)
		moneda.pivot_offset = Vector2(14, 14)
		moneda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		activ_particulas.add_child(moneda)

		var ang := lerpf(-PI * 0.88, -PI * 0.12, float(i) / 4.0)
		var salto := randf_range(150.0, 250.0)
		var destino_m := centro + Vector2(cos(ang), sin(ang)) * salto + Vector2(
			0.0, randf_range(40.0, 90.0)
		)
		var twm := moneda.create_tween().set_parallel(true)
		twm.tween_property(moneda, "position", destino_m, randf_range(0.62, 0.90)).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		twm.tween_property(moneda, "rotation", randf_range(-3.0, 3.0), 0.8)
		twm.tween_property(moneda, "modulate:a", 0.0, 0.42).set_delay(0.40)
		twm.tween_property(moneda, "scale", Vector2(0.45, 0.45), 0.82)
		twm.chain().tween_callback(moneda.queue_free)


func _cerrar_activacion() -> void:
	if overlay_activacion == null or not overlay_activacion.visible:
		return
	if _tw_halo and _tw_halo.is_valid():
		_tw_halo.kill()
	if _tw_icono and _tw_icono.is_valid():
		_tw_icono.kill()
	if _tw_anillo and _tw_anillo.is_valid():
		_tw_anillo.kill()
	_tw_halo = null
	_tw_icono = null
	_tw_anillo = null
	activ_icono.position = _icono_base

	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay_activacion, "modulate:a", 0.0, 0.18)
	tw.tween_property(panel_activacion, "scale", Vector2(0.96, 0.96), 0.18)
	tw.chain().tween_callback(overlay_activacion.hide)


func _reclamar_desde_activacion() -> void:
	_cerrar_activacion()
	await get_tree().create_timer(0.20).timeout
	if not DatosUsuario.puede_reclamar_pase():
		_mostrar_toast("TU PRIMER PREMIO YA ESTA RECLAMADO")
		return
	_on_reclamar_pressed()


func _reproducir(reproductor: AudioStreamPlayer) -> void:
	if reproductor == null or reproductor.stream == null:
		return
	reproductor.stop()
	reproductor.play()


func _volver() -> void:
	if ResourceLoader.exists(ESCENA_MENU):
		get_tree().change_scene_to_file(ESCENA_MENU)
	else:
		get_tree().quit()


func _on_tarjeta_gui_input(evento: InputEvent, carta: PanelContainer) -> void:
	if not (evento is InputEventMouseButton):
		return
	var clic := evento as InputEventMouseButton
	if not clic.pressed or clic.button_index != MOUSE_BUTTON_LEFT:
		return
	if String(carta.get_meta("estado", "")) == "disponible":
		_on_reclamar_pressed()


func _on_fondo_compra_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		_cerrar_compra()


func _on_fondo_recompensa_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		_cerrar_recompensa()


func _on_reloj_timeout() -> void:
	if not DatosUsuario.tiene_pase_elite():
		return
	var puede := DatosUsuario.puede_reclamar_pase()
	if puede != _puede_reclamar:
		_actualizar_vista()
		return
	if puede:
		return
	var cuenta := _texto_cuenta_atras(DatosUsuario.segundos_hasta_proximo_pase())
	label_proximo.text = "PROXIMO RECLAMO EN " + cuenta
	btn_reclamar.text = "RECLAMADO · " + cuenta


# ═══════════════════════════════════════════════════════════════════════
# ANIMACIONES
# ═══════════════════════════════════════════════════════════════════════

func _animar_entrada() -> void:
	modulate.a = 0.0
	await get_tree().process_frame
	var tw: Tween = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

	for i in 3:
		var ctrl: Control = [header, panel_hero, panel_dias][i]
		if ctrl == null:
			continue
		_actualizar_pivote(ctrl)
		ctrl.modulate.a = 0.0
		ctrl.scale = Vector2(0.98, 0.98)
		tw.tween_property(ctrl, "modulate:a", 1.0, 0.26).set_delay(0.04 * float(i))
		tw.tween_property(ctrl, "scale", Vector2.ONE, 0.32).set_delay(0.04 * float(i))


func _animar_brillos() -> void:
	if brillo_ambar:
		brillo_ambar.modulate.a = 0.8
		var tw: Tween = create_tween().set_loops()
		tw.tween_property(brillo_ambar, "modulate:a", 0.45, 4.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(brillo_ambar, "modulate:a", 0.9, 4.5).set_trans(Tween.TRANS_SINE)
	if brillo_frio:
		brillo_frio.modulate.a = 0.55
		var tw2 := create_tween().set_loops()
		tw2.tween_property(brillo_frio, "modulate:a", 0.85, 6.0).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(brillo_frio, "modulate:a", 0.5, 6.0).set_trans(Tween.TRANS_SINE)


func _mostrar_overlay(overlay: Control, panel: Control) -> void:
	if overlay.visible:
		return
	overlay.visible = true
	overlay.modulate.a = 0.0
	await get_tree().process_frame
	_actualizar_pivote(panel)
	panel.scale = Vector2(0.94, 0.94)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)


func _ocultar_overlay(overlay: Control, panel: Control) -> void:
	if not overlay.visible:
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.14)
	tw.tween_property(panel, "scale", Vector2(0.97, 0.97), 0.14)
	tw.chain().tween_callback(overlay.hide)


func _flotar_texto(carta: Control, texto: String) -> void:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 50
	lbl.size = Vector2(260, 40)
	add_child(lbl)
	var centro := carta.get_global_rect().get_center() - global_position
	lbl.position = centro - Vector2(130, 20)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 74.0, 1.0).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.chain().tween_callback(lbl.queue_free)


func _escalar_control(ctrl: Control, factor: float) -> void:
	if ctrl == null:
		return
	var previo = ctrl.get_meta("tw_escala") if ctrl.has_meta("tw_escala") else null
	if previo is Tween and previo.is_valid():
		previo.kill()
	var tw: Tween = ctrl.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2(factor, factor), 0.16)
	ctrl.set_meta("tw_escala", tw)


func _preparar_boton(btn: Button, escala_hover: float) -> void:
	if btn == null:
		return
	btn.resized.connect(_actualizar_pivote.bind(btn))
	btn.mouse_entered.connect(_on_boton_hover.bind(btn, escala_hover))
	btn.mouse_exited.connect(_on_boton_hover.bind(btn, 1.0))
	btn.button_down.connect(_on_boton_down.bind(btn))
	btn.button_up.connect(_on_boton_up.bind(btn, escala_hover))
	_actualizar_pivote(btn)


func _on_boton_hover(btn: Button, factor: float) -> void:
	if btn.disabled:
		_escalar_control(btn, 1.0)
		return
	_escalar_control(btn, factor)


func _on_boton_down(btn: Button) -> void:
	if not btn.disabled:
		_escalar_control(btn, 0.97)


func _on_boton_up(btn: Button, escala_hover: float) -> void:
	if btn.disabled:
		_escalar_control(btn, 1.0)
		return
	var dentro := btn.get_global_rect().has_point(get_global_mouse_position())
	_escalar_control(btn, escala_hover if dentro else 1.0)


func _actualizar_pivote(ctrl: Control) -> void:
	if ctrl:
		ctrl.pivot_offset = ctrl.size * 0.5


func _pulso_etiqueta(ctrl: Control) -> void:
	if ctrl == null:
		return
	_actualizar_pivote(ctrl)
	var previo = ctrl.get_meta("tw_escala") if ctrl.has_meta("tw_escala") else null
	if previo is Tween and previo.is_valid():
		previo.kill()
	var tw: Tween = ctrl.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2(1.06, 1.06), 0.12)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.20)
	ctrl.set_meta("tw_escala", tw)


# ═══════════════════════════════════════════════════════════════════════
# TOAST Y FORMATO
# ═══════════════════════════════════════════════════════════════════════

func _mostrar_toast(texto: String) -> void:
	if toast_label == null or toast_panel == null:
		return
	toast_label.text = texto
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_property(toast_panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.2)
	tw.tween_property(toast_panel, "modulate:a", 0.0, 0.28)
	tw.tween_callback(_ocultar_toast)
	_toast_tween = tw


func _ocultar_toast() -> void:
	if toast_panel:
		toast_panel.visible = false


func _texto_cuenta_atras(segundos: int) -> String:
	var total := maxi(segundos, 0)
	var horas := int(floor(float(total) / 3600.0))
	var minutos := int(floor(float(total % 3600) / 60.0))
	return "%02dH %02dM" % [horas, minutos]


func _fecha_legible(iso: String) -> String:
	var partes := iso.split("-")
	if partes.size() != 3:
		return "HOY"
	return "%s/%s/%s" % [partes[2], partes[1], partes[0]]


func _formatear_dinero(valor: float) -> String:
	var absoluto := absf(valor)
	var entero := int(floor(absoluto))
	var centavos := int(round((absoluto - float(entero)) * 100.0))
	if centavos >= 100:
		entero += 1
		centavos = 0

	var texto := "$ " + _miles(entero)
	if centavos > 0:
		texto += ",%02d" % centavos
	if valor < 0.0:
		texto = "-" + texto
	return texto


func _miles(valor: int) -> String:
	var digitos := str(absi(valor))
	var salida := ""
	for i in range(digitos.length()):
		if i > 0 and (digitos.length() - i) % 3 == 0:
			salida += "."
		salida += digitos[i]
	return "-" + salida if valor < 0 else salida
