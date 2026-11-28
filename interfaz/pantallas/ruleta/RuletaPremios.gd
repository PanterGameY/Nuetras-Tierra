extends Control

## RuletaPremios.gd — Ruleta Misteriosa con estética Automotive Glassmorphism.
## Los premios permanecen ocultos como cápsulas misteriosas hasta que la ruleta se detiene y revela el ganador.

const ESCENA_MENU_PRINCIPAL := "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const ESCENA_BARRA_DIVISAS := preload("res://interfaz/componentes/divisas/BarraDivisas.tscn")
const RUTA_FUENTE_TITULO := "res://recursos/fonts/Moderniz.otf"
const RUTA_FUENTE_CUERPO := "res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf"
const RUTA_FUENTE_BOLD := "res://recursos/fonts/creato_display/CreatoDisplay-Bold.otf"
const RUTA_ICONO_ESMERALDA := "res://recursos/botones/Esmeralda.png"
const RUTA_ICONO_DINERO := "res://recursos/botones/money.png"
const RUTA_ICONO_PASE := "res://recursos/botones/PaseMapa.png"
const ARCHIVO_ESTADO_RULETA := "user://ruleta_estado.cfg"

const COSTO_GIRO_DINERO := 25000.0
const COOLDOWN_GRATIS_SEG := 86400

const C_BG := Color(0.04, 0.05, 0.06, 1.0)
const C_SURFACE := Color(0.06, 0.07, 0.08, 0.90)
const C_CARD := Color(0.09, 0.10, 0.12, 0.90)
const C_AMBER := Color(0.88, 0.68, 0.28, 0.92)
const C_AMBER_BRIGHT := Color(1.0, 0.85, 0.42, 1.0)
const C_CRIMSON := Color(0.78, 0.28, 0.26, 0.95)
const C_BORDER_FROST := Color(0.78, 0.81, 0.85, 0.22)
const C_TEXT := Color(0.95, 0.96, 0.98, 1.0)
const C_TEXT_MUTED := Color(0.62, 0.66, 0.72, 0.92)
const C_VERDE := Color(0.42, 0.90, 0.58, 1.0)

const PREMIOS: Array[Dictionary] = [
	{"id": "dinero_15k", "tipo": "dinero", "cantidad": 15000, "titulo": "$ 15.000", "sub": "Efectivo", "peso": 26, "color": Color(0.08, 0.11, 0.16, 1.0), "aura": Color(0.35, 0.72, 1.0, 1.0)},
	{"id": "esm_3", "tipo": "esmeraldas", "cantidad": 3, "titulo": "+3", "sub": "Esmeraldas", "peso": 24, "color": Color(0.07, 0.14, 0.12, 1.0), "aura": Color(0.28, 0.90, 0.56, 1.0)},
	{"id": "dinero_45k", "tipo": "dinero", "cantidad": 45000, "titulo": "$ 45.000", "sub": "Efectivo", "peso": 18, "color": Color(0.10, 0.13, 0.19, 1.0), "aura": Color(0.45, 0.80, 1.0, 1.0)},
	{"id": "esm_5", "tipo": "esmeraldas", "cantidad": 5, "titulo": "+5", "sub": "Esmeraldas", "peso": 14, "color": Color(0.08, 0.16, 0.13, 1.0), "aura": Color(0.32, 0.95, 0.62, 1.0)},
	{"id": "pase_1", "tipo": "pase_mapa", "cantidad": 1, "titulo": "1 PASE", "sub": "Pase de Mapa", "peso": 7, "color": Color(0.17, 0.12, 0.05, 1.0), "aura": Color(1.0, 0.82, 0.35, 1.0)},
	{"id": "dinero_100k", "tipo": "dinero", "cantidad": 100000, "titulo": "$ 100.000", "sub": "Efectivo", "peso": 6, "color": Color(0.12, 0.11, 0.20, 1.0), "aura": Color(0.62, 0.72, 1.0, 1.0)},
	{"id": "esm_12", "tipo": "esmeraldas", "cantidad": 12, "titulo": "+12", "sub": "Esmeraldas", "peso": 4, "color": Color(0.07, 0.19, 0.14, 1.0), "aura": Color(0.38, 1.0, 0.68, 1.0)},
	{"id": "esm_25", "tipo": "esmeraldas", "cantidad": 25, "titulo": "+25", "sub": "Jackpot", "peso": 1, "color": Color(0.22, 0.15, 0.04, 1.0), "aura": Color(1.0, 0.88, 0.42, 1.0)}
]

var _fuente_titulo: Font = null
var _fuente_cuerpo: Font = null
var _fuente_bold: Font = null
var _tex_esmeralda: Texture2D = null
var _tex_dinero: Texture2D = null
var _tex_pase: Texture2D = null

var _barra_divisas: BarraDivisas = null
var _lbl_pases: Label = null
var _holder_ruleta: Control = null
var _disco_ruleta: Control = null
var _aguja: Control = null
var _btn_girar: Button = null
var _btn_volver: Button = null
var _lbl_estado_giro: Label = null
var _lbl_subestado: Label = null
var _particulas: CPUParticles2D = null
var _panel_principal: Control = null

var _girando: bool = false
var _angulo_actual: float = 0.0
var _ultimo_sector_peg: int = -1
var _fase_led: float = 0.0
var _ultimo_giro_gratis: int = 0
var _tween_giro: Tween = null
var _rng := RandomNumberGenerator.new()

var _tick_players: Array[AudioStreamPlayer] = []
var _tick_idx: int = 0
var _audio_inicio: AudioStreamPlayer = null
var _audio_ganar: AudioStreamPlayer = null
var _audio_moneda: AudioStreamPlayer = null


# ── Disco con cápsulas misteriosas ocultas ──────────────────────────────────
class RuletaDisco extends Control:
	var premios: Array[Dictionary] = []
	var tex_esmeralda: Texture2D = null
	var tex_dinero: Texture2D = null
	var tex_pase: Texture2D = null
	var fuente_titulo: Font = null
	var fuente_bold: Font = null
	var angulo_rad: float = 0.0
	var fase_led: float = 0.0
	var indice_revelado: int = -1

	func _draw() -> void:
		if premios.is_empty():
			return
		var centro := size * 0.5
		var radio := minf(size.x, size.y) * 0.45
		if radio <= 40.0:
			return
		var n := premios.size()
		var paso := TAU / float(n)

		# Halo ambiental + bisel metálico oscuro
		draw_circle(centro, radio + 30.0, Color(0.88, 0.68, 0.28, 0.08))
		draw_circle(centro, radio + 22.0, Color(0.05, 0.06, 0.08, 0.98))
		draw_arc(centro, radio + 22.0, 0.0, TAU, 128, Color(0.78, 0.81, 0.85, 0.26), 2.5, true)
		draw_circle(centro, radio + 12.0, Color(0.11, 0.12, 0.15, 1.0))

		# Cuñas de la ruleta
		for i in range(n):
			var p: Dictionary = premios[i]
			var a0 := angulo_rad + float(i) * paso - PI * 0.5 - paso * 0.5
			var a1 := a0 + paso
			var color_base: Color = p.get("color", Color(0.10, 0.12, 0.16, 1.0))
			if i == indice_revelado:
				color_base = color_base.lightened(0.24)
			_dibujar_sector(centro, radio - 8.0, a0, a1, color_base)

			var aura: Color = p.get("aura", C_AMBER_BRIGHT)
			_dibujar_sector_anillo(centro, radio * 0.84, radio - 12.0, a0 + 0.02, a1 - 0.02, Color(aura.r, aura.g, aura.b, 0.16))

			var p_borde := centro + Vector2(cos(a0), sin(a0)) * (radio - 8.0)
			draw_line(centro, p_borde, Color(0.95, 0.78, 0.38, 0.65), 2.5, true)

		# Anillo dorado
		draw_arc(centro, radio - 8.0, 0.0, TAU, 128, Color(0.95, 0.74, 0.28, 0.95), 4.5, true)

		# 32 LEDs en el bisel
		var num_leds := 32
		for k in range(num_leds):
			var ang_l := angulo_rad + float(k) * (TAU / float(num_leds)) - PI * 0.5
			var pos_l := centro + Vector2(cos(ang_l), sin(ang_l)) * (radio + 5.0)
			var encendido := int(floor(fase_led + float(k))) % 2 == 0
			if encendido:
				draw_circle(pos_l, 8.5, Color(1.0, 0.84, 0.38, 0.28))
				draw_circle(pos_l, 4.5, Color(1.0, 0.90, 0.55, 1.0))
			else:
				draw_circle(pos_l, 4.0, Color(0.26, 0.22, 0.14, 0.85))

		# 8 pines metálicos dorados
		for i in range(n):
			var ang_peg := angulo_rad + float(i) * paso - PI * 0.5 - paso * 0.5
			var pos_peg := centro + Vector2(cos(ang_peg), sin(ang_peg)) * (radio - 8.0)
			draw_circle(pos_peg, 7.5, Color(0.12, 0.09, 0.03, 1.0))
			draw_circle(pos_peg, 5.0, Color(1.0, 0.86, 0.45, 1.0))

		# Contenido de cada cuña
		for i in range(n):
			var p: Dictionary = premios[i]
			var a_mid := angulo_rad + float(i) * paso - PI * 0.5
			var dir := Vector2(cos(a_mid), sin(a_mid))
			var aura: Color = p.get("aura", C_AMBER_BRIGHT)

			if i == indice_revelado:
				var tex: Texture2D = null
				match str(p.get("tipo", "")):
					"esmeraldas": tex = tex_esmeralda
					"dinero": tex = tex_dinero
					"pase_mapa": tex = tex_pase
				if tex:
					var pos_ico := centro + dir * (radio * 0.66)
					var tam_ico := clampf(radio * 0.22, 48.0, 74.0)
					draw_set_transform(pos_ico, a_mid + PI * 0.5, Vector2.ONE)
					draw_texture_rect(tex, Rect2(-tam_ico * 0.5, -tam_ico * 0.5, tam_ico, tam_ico), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if fuente_bold:
					var pos_txt := centro + dir * (radio * 0.42)
					var txt := str(p.get("titulo", ""))
					var fz := int(clampf(radio * 0.085, 20.0, 28.0))
					var w_txt := fuente_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fz).x
					draw_set_transform(pos_txt, a_mid + PI * 0.5, Vector2.ONE)
					draw_string(fuente_bold, Vector2(-w_txt * 0.5, 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fz, Color(1.0, 0.92, 0.55, 1.0))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var pos_m := centro + dir * (radio * 0.61)
				var pulso := 0.85 + 0.15 * sin(fase_led * 0.7 + float(i) * 0.9)
				var r_hex := clampf(radio * 0.105, 24.0, 34.0)
				draw_circle(pos_m, (r_hex + 8.0) * pulso, Color(aura.r, aura.g, aura.b, 0.15))
				_dibujar_hexagono(pos_m, r_hex, a_mid + PI * 0.5, Color(0.06, 0.07, 0.10, 0.96), Color(aura.r, aura.g, aura.b, 0.82))
				if fuente_titulo:
					var q := "?"
					var fz_q := int(clampf(radio * 0.105, 24.0, 34.0))
					var w_q := fuente_titulo.get_string_size(q, HORIZONTAL_ALIGNMENT_CENTER, -1, fz_q).x
					draw_set_transform(pos_m, a_mid + PI * 0.5, Vector2.ONE)
					draw_string(fuente_titulo, Vector2(-w_q * 0.5, 10.0), q, HORIZONTAL_ALIGNMENT_LEFT, -1, fz_q, Color(aura.r, aura.g, aura.b, 0.98))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Hub central
		var r_hub := clampf(radio * 0.21, 46.0, 66.0)
		draw_circle(centro, r_hub, Color(0.05, 0.06, 0.08, 1.0))
		draw_arc(centro, r_hub, 0.0, TAU, 64, Color(0.95, 0.74, 0.28, 0.98), 4.5, true)
		draw_circle(centro, r_hub * 0.74, Color(0.16, 0.12, 0.04, 1.0))
		draw_arc(centro, r_hub * 0.74, 0.0, TAU, 64, Color(1.0, 0.86, 0.45, 0.55), 2.0, true)
		if fuente_titulo:
			var nt := "NT"
			var fz_nt := int(clampf(r_hub * 0.44, 22.0, 30.0))
			var w_nt := fuente_titulo.get_string_size(nt, HORIZONTAL_ALIGNMENT_CENTER, -1, fz_nt).x
			draw_string(fuente_titulo, centro + Vector2(-w_nt * 0.5, fz_nt * 0.36), nt, HORIZONTAL_ALIGNMENT_LEFT, -1, fz_nt, Color(1.0, 0.86, 0.44, 1.0))

	func _dibujar_sector(centro: Vector2, radio: float, a0: float, a1: float, col: Color) -> void:
		var pts := PackedVector2Array([centro])
		var pasos := 22
		for s in range(pasos + 1):
			var a := lerpf(a0, a1, float(s) / float(pasos))
			pts.append(centro + Vector2(cos(a), sin(a)) * radio)
		draw_colored_polygon(pts, col)

	func _dibujar_sector_anillo(centro: Vector2, r_in: float, r_out: float, a0: float, a1: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var pasos := 18
		for s in range(pasos + 1):
			var a := lerpf(a0, a1, float(s) / float(pasos))
			pts.append(centro + Vector2(cos(a), sin(a)) * r_out)
		for s in range(pasos, -1, -1):
			var a := lerpf(a0, a1, float(s) / float(pasos))
			pts.append(centro + Vector2(cos(a), sin(a)) * r_in)
		draw_colored_polygon(pts, col)

	func _dibujar_hexagono(centro: Vector2, radio: float, rot: float, relleno: Color, borde: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(6):
			var a := rot + float(i) * (TAU / 6.0)
			pts.append(centro + Vector2(cos(a), sin(a)) * radio)
		draw_colored_polygon(pts, relleno)
		var linea := pts.duplicate()
		linea.append(pts[0])
		draw_polyline(linea, borde, 2.5, true)


class RuletaAguja extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([
			Vector2(w * 0.5, h - 2.0),
			Vector2(4.0, 14.0),
			Vector2(w * 0.5, 2.0),
			Vector2(w - 4.0, 14.0)
		])
		draw_colored_polygon(pts, Color(0.98, 0.78, 0.30, 1.0))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.14, 0.10, 0.03, 1.0), 3.0, true)
		draw_circle(Vector2(w * 0.5, 18.0), 10.0, Color(0.08, 0.09, 0.12, 1.0))
		draw_arc(Vector2(w * 0.5, 18.0), 10.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.42, 0.9), 2.0, true)


func _ready() -> void:
	_rng.randomize()
	_cargar_recursos()
	_inicializar_audio()
	_cargar_estado_ruleta()
	_construir_ui()
	_actualizar_divisas_y_estado()
	_animar_entrada()


func _exit_tree() -> void:
	if _tween_giro and _tween_giro.is_valid():
		_tween_giro.kill()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _girando:
		_volver_menu()


func _process(delta: float) -> void:
	_fase_led += delta * (16.0 if _girando else 3.5)
	if is_instance_valid(_disco_ruleta):
		(_disco_ruleta as RuletaDisco).fase_led = _fase_led
		_disco_ruleta.queue_redraw()
	if not _girando:
		_actualizar_texto_cooldown()


func _cargar_recursos() -> void:
	if ResourceLoader.exists(RUTA_FUENTE_TITULO):
		_fuente_titulo = load(RUTA_FUENTE_TITULO) as Font
	if ResourceLoader.exists(RUTA_FUENTE_CUERPO):
		_fuente_cuerpo = load(RUTA_FUENTE_CUERPO) as Font
	if ResourceLoader.exists(RUTA_FUENTE_BOLD):
		_fuente_bold = load(RUTA_FUENTE_BOLD) as Font
	if ResourceLoader.exists(RUTA_ICONO_ESMERALDA):
		_tex_esmeralda = load(RUTA_ICONO_ESMERALDA) as Texture2D
	if ResourceLoader.exists(RUTA_ICONO_DINERO):
		_tex_dinero = load(RUTA_ICONO_DINERO) as Texture2D
	if ResourceLoader.exists(RUTA_ICONO_PASE):
		_tex_pase = load(RUTA_ICONO_PASE) as Texture2D


func _cargar_estado_ruleta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_ESTADO_RULETA) == OK:
		_ultimo_giro_gratis = int(cfg.get_value("ruleta", "ultimo_giro_gratis", 0))


func _guardar_estado_ruleta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ruleta", "ultimo_giro_gratis", _ultimo_giro_gratis)
	cfg.save(ARCHIVO_ESTADO_RULETA)


func _giro_gratis_disponible() -> bool:
	var ahora := int(Time.get_unix_time_from_system())
	return (ahora - _ultimo_giro_gratis) >= COOLDOWN_GRATIS_SEG


func _construir_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 42)
	mc.add_theme_constant_override("margin_right", 42)
	mc.add_theme_constant_override("margin_top", 28)
	mc.add_theme_constant_override("margin_bottom", 28)
	add_child(mc)
	_panel_principal = mc

	var vb_root := VBoxContainer.new()
	vb_root.add_theme_constant_override("separation", 18)
	mc.add_child(vb_root)

	# ── HEADER ESTÁNDAR (igual a Tienda / Pase Elite) ──────────────────────
	var hb_top := HBoxContainer.new()
	hb_top.add_theme_constant_override("separation", 24)
	vb_root.add_child(hb_top)

	var vb_tit := VBoxContainer.new()
	vb_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_tit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb_tit.add_theme_constant_override("separation", 2)
	hb_top.add_child(vb_tit)

	var lbl_eyebrow := Label.new()
	lbl_eyebrow.text = "SORTEO DIARIO / PREMIOS OCULTOS"
	lbl_eyebrow.add_theme_font_size_override("font_size", 14)
	lbl_eyebrow.add_theme_color_override("font_color", C_AMBER)
	if _fuente_titulo: lbl_eyebrow.add_theme_font_override("font", _fuente_titulo)
	vb_tit.add_child(lbl_eyebrow)

	var lbl_tit := Label.new()
	lbl_tit.text = "RULETA MISTERIOSA"
	lbl_tit.add_theme_font_size_override("font_size", 44)
	lbl_tit.add_theme_color_override("font_color", C_TEXT)
	lbl_tit.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl_tit.add_theme_constant_override("shadow_offset_x", 2)
	lbl_tit.add_theme_constant_override("shadow_offset_y", 2)
	if _fuente_titulo: lbl_tit.add_theme_font_override("font", _fuente_titulo)
	vb_tit.add_child(lbl_tit)

	var lbl_sub := Label.new()
	lbl_sub.text = "Gira la ruleta para revelar tu recompensa instantanea"
	lbl_sub.add_theme_font_size_override("font_size", 17)
	lbl_sub.add_theme_color_override("font_color", C_TEXT_MUTED)
	if _fuente_cuerpo: lbl_sub.add_theme_font_override("font", _fuente_cuerpo)
	vb_tit.add_child(lbl_sub)

	_barra_divisas = ESCENA_BARRA_DIVISAS.instantiate() as BarraDivisas
	if _barra_divisas:
		_barra_divisas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb_top.add_child(_barra_divisas)

	# Chip Pases de Mapa
	var chip_pase := PanelContainer.new()
	chip_pase.custom_minimum_size = Vector2(180, 80)
	chip_pase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_pase := _crear_estilo(C_CARD, C_BORDER_FROST, 10, 1, 6)
	sb_pase.content_margin_left = 16.0
	sb_pase.content_margin_right = 18.0
	chip_pase.add_theme_stylebox_override("panel", sb_pase)
	hb_top.add_child(chip_pase)

	var hb_p := HBoxContainer.new()
	hb_p.add_theme_constant_override("separation", 10)
	chip_pase.add_child(hb_p)
	var ac_p := ColorRect.new()
	ac_p.custom_minimum_size = Vector2(3, 40)
	ac_p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ac_p.color = C_AMBER
	hb_p.add_child(ac_p)
	if _tex_pase:
		var tr_p := TextureRect.new()
		tr_p.texture = _tex_pase
		tr_p.custom_minimum_size = Vector2(38, 38)
		tr_p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb_p.add_child(tr_p)
	var vb_p := VBoxContainer.new()
	vb_p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb_p.add_child(vb_p)
	var cap_p := Label.new()
	cap_p.text = "PASES"
	cap_p.add_theme_font_size_override("font_size", 15)
	cap_p.add_theme_color_override("font_color", C_TEXT_MUTED)
	if _fuente_bold: cap_p.add_theme_font_override("font", _fuente_bold)
	vb_p.add_child(cap_p)
	_lbl_pases = Label.new()
	_lbl_pases.text = "0"
	_lbl_pases.add_theme_font_size_override("font_size", 24)
	_lbl_pases.add_theme_color_override("font_color", C_TEXT)
	if _fuente_bold: _lbl_pases.add_theme_font_override("font", _fuente_bold)
	vb_p.add_child(_lbl_pases)

	_btn_volver = Button.new()
	_btn_volver.text = "VOLVER"
	_btn_volver.custom_minimum_size = Vector2(160, 80)
	_btn_volver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_volver.focus_mode = Control.FOCUS_NONE
	_btn_volver.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_aplicar_boton_salir(_btn_volver, 19)
	_btn_volver.pressed.connect(_volver_menu)
	hb_top.add_child(_btn_volver)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.78, 0.81, 0.85, 0.12)
	vb_root.add_child(sep)

	# ── CUERPO 2 COLUMNAS (Cockpit Glassmorphism) ──────────────────────────
	var hb_body := HBoxContainer.new()
	hb_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb_body.add_theme_constant_override("separation", 24)
	vb_root.add_child(hb_body)

	# Columna Izquierda: Escenario de la Ruleta
	var stage_panel := PanelContainer.new()
	stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_stage := _crear_estilo(C_SURFACE, C_BORDER_FROST, 14, 1, 8)
	sb_stage.content_margin_left = 18.0
	sb_stage.content_margin_right = 18.0
	sb_stage.content_margin_top = 18.0
	sb_stage.content_margin_bottom = 18.0
	stage_panel.add_theme_stylebox_override("panel", sb_stage)
	hb_body.add_child(stage_panel)

	var center_r := CenterContainer.new()
	center_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_child(center_r)

	_holder_ruleta = Control.new()
	_holder_ruleta.custom_minimum_size = Vector2(520, 520)
	center_r.add_child(_holder_ruleta)

	center_r.resized.connect(func() -> void:
		if not is_instance_valid(_holder_ruleta):
			return
		var lado := clampf(minf(center_r.size.x, center_r.size.y) - 16.0, 460.0, 740.0)
		_holder_ruleta.custom_minimum_size = Vector2(lado, lado)
		_reubicar_overlays_ruleta()
	)

	var disco := RuletaDisco.new()
	disco.premios = PREMIOS
	disco.tex_esmeralda = _tex_esmeralda
	disco.tex_dinero = _tex_dinero
	disco.tex_pase = _tex_pase
	disco.fuente_titulo = _fuente_titulo
	disco.fuente_bold = _fuente_bold
	disco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder_ruleta.add_child(disco)
	_disco_ruleta = disco

	var aguja := RuletaAguja.new()
	aguja.custom_minimum_size = Vector2(64, 80)
	aguja.size = Vector2(64, 80)
	aguja.pivot_offset = Vector2(32, 18)
	_holder_ruleta.add_child(aguja)
	_aguja = aguja

	_particulas = CPUParticles2D.new()
	_particulas.emitting = false
	_particulas.one_shot = true
	_particulas.explosiveness = 0.94
	_particulas.amount = 90
	_particulas.lifetime = 1.5
	_particulas.direction = Vector2.UP
	_particulas.spread = 180.0
	_particulas.initial_velocity_min = 220.0
	_particulas.initial_velocity_max = 560.0
	_particulas.gravity = Vector2(0, 340)
	_particulas.scale_amount_min = 7.0
	_particulas.scale_amount_max = 14.0
	_particulas.color = C_AMBER_BRIGHT
	_holder_ruleta.add_child(_particulas)

	_holder_ruleta.resized.connect(_reubicar_overlays_ruleta)
	_reubicar_overlays_ruleta()

	# Columna Derecha: Panel de Control + Premios Posibles
	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(460, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_side := _crear_estilo(C_CARD, C_BORDER_FROST, 14, 1, 8)
	sb_side.content_margin_left = 26.0
	sb_side.content_margin_right = 26.0
	sb_side.content_margin_top = 24.0
	sb_side.content_margin_bottom = 24.0
	side_panel.add_theme_stylebox_override("panel", sb_side)
	hb_body.add_child(side_panel)

	var vb_side := VBoxContainer.new()
	vb_side.add_theme_constant_override("separation", 18)
	side_panel.add_child(vb_side)

	var lbl_side_tit := Label.new()
	lbl_side_tit.text = "RECOMPENSAS DEL SORTEO"
	lbl_side_tit.add_theme_font_size_override("font_size", 20)
	lbl_side_tit.add_theme_color_override("font_color", C_AMBER)
	if _fuente_titulo: lbl_side_tit.add_theme_font_override("font", _fuente_titulo)
	vb_side.add_child(lbl_side_tit)

	var vb_premios := VBoxContainer.new()
	vb_premios.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb_premios.add_theme_constant_override("separation", 8)
	vb_side.add_child(vb_premios)

	for p in PREMIOS:
		vb_premios.add_child(_crear_fila_premio(p))

	var sep_side := ColorRect.new()
	sep_side.custom_minimum_size = Vector2(0, 1)
	sep_side.color = Color(0.78, 0.81, 0.85, 0.14)
	vb_side.add_child(sep_side)

	_lbl_estado_giro = Label.new()
	_lbl_estado_giro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_estado_giro.add_theme_font_size_override("font_size", 20)
	_lbl_estado_giro.add_theme_color_override("font_color", C_VERDE)
	if _fuente_bold: _lbl_estado_giro.add_theme_font_override("font", _fuente_bold)
	vb_side.add_child(_lbl_estado_giro)

	_lbl_subestado = Label.new()
	_lbl_subestado.text = "Un giro diario sin costo o giros extra por $25.000"
	_lbl_subestado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_subestado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_subestado.add_theme_font_size_override("font_size", 16)
	_lbl_subestado.add_theme_color_override("font_color", C_TEXT_MUTED)
	if _fuente_cuerpo: _lbl_subestado.add_theme_font_override("font", _fuente_cuerpo)
	vb_side.add_child(_lbl_subestado)

	_btn_girar = Button.new()
	_btn_girar.custom_minimum_size = Vector2(0, 80)
	_btn_girar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_girar.focus_mode = Control.FOCUS_NONE
	_btn_girar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_girar.add_theme_font_size_override("font_size", 26)
	_btn_girar.add_theme_color_override("font_color", Color(0.07, 0.08, 0.10, 1.0))
	_btn_girar.add_theme_color_override("font_disabled_color", C_TEXT_MUTED)
	if _fuente_titulo: _btn_girar.add_theme_font_override("font", _fuente_titulo)
	_btn_girar.add_theme_stylebox_override("normal", _crear_estilo(C_AMBER, C_AMBER_BRIGHT, 12, 1, 10))
	_btn_girar.add_theme_stylebox_override("hover", _crear_estilo(C_AMBER_BRIGHT, Color.WHITE, 12, 1, 14))
	_btn_girar.add_theme_stylebox_override("pressed", _crear_estilo(Color(0.75, 0.54, 0.18, 1.0), C_AMBER, 12, 1, 4))
	_btn_girar.add_theme_stylebox_override("disabled", _crear_estilo(Color(1.0, 1.0, 1.0, 0.05), C_BORDER_FROST, 12, 1, 0))
	_btn_girar.pressed.connect(_on_girar_pressed)
	vb_side.add_child(_btn_girar)


func _crear_fila_premio(p: Dictionary) -> PanelContainer:
	var fila := PanelContainer.new()
	var aura: Color = p.get("aura", C_AMBER)
	var sb := _crear_estilo(Color(0.06, 0.07, 0.09, 0.85), Color(aura.r, aura.g, aura.b, 0.25), 10, 1, 0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	fila.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	fila.add_child(hb)

	var barra := ColorRect.new()
	barra.custom_minimum_size = Vector2(4, 28)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.color = aura
	hb.add_child(barra)

	var tex: Texture2D = null
	match str(p.get("tipo", "")):
		"esmeraldas": tex = _tex_esmeralda
		"dinero": tex = _tex_dinero
		"pase_mapa": tex = _tex_pase
	if tex:
		var ico := TextureRect.new()
		ico.texture = tex
		ico.custom_minimum_size = Vector2(30, 30)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ico)

	var lbl_nom := Label.new()
	lbl_nom.text = "%s  %s" % [str(p.get("titulo", "")), str(p.get("sub", ""))]
	lbl_nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_nom.add_theme_font_size_override("font_size", 18)
	lbl_nom.add_theme_color_override("font_color", C_TEXT)
	if _fuente_bold: lbl_nom.add_theme_font_override("font", _fuente_bold)
	hb.add_child(lbl_nom)

	return fila


func _reubicar_overlays_ruleta() -> void:
	if not is_instance_valid(_holder_ruleta):
		return
	var s := _holder_ruleta.size
	if s.x <= 10.0:
		s = _holder_ruleta.custom_minimum_size
	if is_instance_valid(_aguja):
		_aguja.position = Vector2(s.x * 0.5 - _aguja.size.x * 0.5, -6.0)
	if is_instance_valid(_particulas):
		_particulas.position = s * 0.5


func _animar_entrada() -> void:
	if not is_instance_valid(_panel_principal):
		return
	_panel_principal.modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel_principal, "modulate:a", 1.0, 0.28)


func _volver_menu() -> void:
	if _girando:
		return
	var du := get_node_or_null("/root/DatosUsuario")
	if du and du.has_method("cambiar_escena"):
		du.cambiar_escena(ESCENA_MENU_PRINCIPAL)
	else:
		get_tree().change_scene_to_file(ESCENA_MENU_PRINCIPAL)


func _actualizar_divisas_y_estado() -> void:
	if is_instance_valid(_barra_divisas):
		_barra_divisas.refrescar(true)
	var du := get_node_or_null("/root/DatosUsuario")
	if is_instance_valid(_lbl_pases):
		_lbl_pases.text = str(int(du.pases_mapa) if (du and "pases_mapa" in du) else 0)
	_actualizar_texto_cooldown()


func _actualizar_texto_cooldown() -> void:
	if not is_instance_valid(_btn_girar) or not is_instance_valid(_lbl_estado_giro):
		return
	if _girando:
		return
	if _giro_gratis_disponible():
		_lbl_estado_giro.text = "GIRO GRATIS DIARIO DISPONIBLE"
		_lbl_estado_giro.add_theme_color_override("font_color", C_VERDE)
		_btn_girar.text = "GIRAR GRATIS"
		_btn_girar.disabled = false
	else:
		var restante := COOLDOWN_GRATIS_SEG - (int(Time.get_unix_time_from_system()) - _ultimo_giro_gratis)
		var hrs := int(restante / 3600.0)
		var mins := int((restante % 3600) / 60.0)
		_lbl_estado_giro.text = "Proximo giro gratis en %02dh %02dm" % [hrs, mins]
		_lbl_estado_giro.add_theme_color_override("font_color", C_TEXT_MUTED)
		_btn_girar.text = "GIRAR  ($ 25.000)"
		var du := get_node_or_null("/root/DatosUsuario")
		_btn_girar.disabled = not (du and float(du.dinero) >= COSTO_GIRO_DINERO)


func _elegir_indice_ponderado() -> int:
	var total := 0
	for p in PREMIOS:
		total += int(p.get("peso", 1))
	var r := _rng.randi_range(1, maxi(1, total))
	var acum := 0
	for i in range(PREMIOS.size()):
		acum += int(PREMIOS[i].get("peso", 1))
		if r <= acum:
			return i
	return 0


func _on_girar_pressed() -> void:
	if _girando:
		return
	var du := get_node_or_null("/root/DatosUsuario")
	if _giro_gratis_disponible():
		_ultimo_giro_gratis = int(Time.get_unix_time_from_system())
		_guardar_estado_ruleta()
	else:
		if not du or float(du.dinero) < COSTO_GIRO_DINERO:
			return
		du.dinero = float(du.dinero) - COSTO_GIRO_DINERO
		if du.has_method("save_local"):
			du.save_local()
		_actualizar_divisas_y_estado()

	_girando = true
	_btn_girar.disabled = true
	_btn_girar.text = "GIRANDO..."
	if is_instance_valid(_btn_volver):
		_btn_volver.disabled = true
	if is_instance_valid(_audio_inicio):
		_audio_inicio.play()
	var disco := _disco_ruleta as RuletaDisco
	disco.indice_revelado = -1

	var idx_ganador := _elegir_indice_ponderado()
	var n := PREMIOS.size()
	var paso := TAU / float(n)
	var vueltas := float(_rng.randi_range(6, 9))
	var jitter := _rng.randf_range(-paso * 0.25, paso * 0.25)
	var base_actual := fmod(_angulo_actual, TAU)
	var objetivo_mod := fposmod(-float(idx_ganador) * paso + jitter, TAU)
	var delta_ang := fposmod(objetivo_mod - base_actual, TAU)
	var angulo_destino := _angulo_actual + vueltas * TAU + delta_ang

	_ultimo_sector_peg = int(floor(_angulo_actual / paso))
	if _tween_giro and _tween_giro.is_valid():
		_tween_giro.kill()
	_tween_giro = create_tween()
	_tween_giro.tween_method(func(a: float) -> void:
		if not is_instance_valid(disco):
			return
		_angulo_actual = a
		disco.angulo_rad = a
		disco.queue_redraw()
		var sec_act := int(floor((a + paso * 0.5) / paso))
		if sec_act != _ultimo_sector_peg:
			_ultimo_sector_peg = sec_act
			_rebotar_aguja()
	, _angulo_actual, angulo_destino, 4.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	_tween_giro.tween_callback(func() -> void:
		_girando = false
		if is_instance_valid(_btn_volver):
			_btn_volver.disabled = false
		if is_instance_valid(disco):
			disco.indice_revelado = idx_ganador
			disco.queue_redraw()
		if is_instance_valid(_particulas):
			_particulas.restart()
			_particulas.emitting = true
		_otorgar_premio(PREMIOS[idx_ganador])
	)


func _rebotar_aguja() -> void:
	_reproducir_tick()
	if not is_instance_valid(_aguja):
		return
	var prev = _aguja.get_meta("tw_aguja", null)
	if prev is Tween and prev.is_valid():
		prev.kill()
	_aguja.rotation_degrees = -26.0
	var tw := _aguja.create_tween()
	tw.tween_property(_aguja, "rotation_degrees", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_aguja.set_meta("tw_aguja", tw)


func _inicializar_audio() -> void:
	var tick_wav := _crear_stream_tick()
	for i in range(3):
		var p := AudioStreamPlayer.new()
		p.stream = tick_wav
		p.volume_db = -5.0
		add_child(p)
		_tick_players.append(p)

	if ResourceLoader.exists("res://recursos/efectos/checkpoint.mp3"):
		_audio_inicio = AudioStreamPlayer.new()
		_audio_inicio.stream = load("res://recursos/efectos/checkpoint.mp3")
		_audio_inicio.volume_db = -4.0
		add_child(_audio_inicio)

	if ResourceLoader.exists("res://recursos/efectos/level_up.mp3"):
		_audio_ganar = AudioStreamPlayer.new()
		_audio_ganar.stream = load("res://recursos/efectos/level_up.mp3")
		_audio_ganar.volume_db = -2.0
		add_child(_audio_ganar)

	if ResourceLoader.exists("res://recursos/efectos/money.mp3"):
		_audio_moneda = AudioStreamPlayer.new()
		_audio_moneda.stream = load("res://recursos/efectos/money.mp3")
		_audio_moneda.volume_db = -3.0
		add_child(_audio_moneda)


func _crear_stream_tick() -> AudioStreamWAV:
	var sr := 22050
	var num_muestras := int(sr * 0.038)
	var data := PackedByteArray()
	data.resize(num_muestras * 2)
	for i in range(num_muestras):
		var t := float(i) / float(sr)
		var env := exp(-t * 95.0)
		var freq := lerpf(980.0, 420.0, minf(1.0, t * 35.0))
		var muestra := int(clampf(sin(TAU * freq * t) * env * 0.65, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, muestra)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	wav.data = data
	return wav


func _reproducir_tick() -> void:
	if _tick_players.is_empty():
		return
	var p := _tick_players[_tick_idx % _tick_players.size()]
	_tick_idx += 1
	p.pitch_scale = _rng.randf_range(0.95, 1.06)
	p.play()


func _otorgar_premio(premio: Dictionary) -> void:
	if is_instance_valid(_audio_ganar):
		_audio_ganar.play()
	var du := get_node_or_null("/root/DatosUsuario")
	var tipo := str(premio.get("tipo", ""))
	var cant := int(premio.get("cantidad", 0))
	if du:
		match tipo:
			"dinero":
				du.dinero = float(du.dinero) + float(cant)
			"esmeraldas":
				du.esmeraldas = int(du.esmeraldas) + cant
			"pase_mapa":
				if "pases_mapa" in du:
					du.pases_mapa = int(du.pases_mapa) + cant
		if du.has_method("save_local"):
			du.save_local()
		var sm := get_node_or_null("/root/SupabaseManager")
		if sm and sm.has_method("guardar_perfil") and "access_token" in sm and not str(sm.access_token).is_empty():
			sm.guardar_perfil({"dinero": float(du.dinero), "esmeraldas": int(du.esmeraldas)})

	_actualizar_divisas_y_estado()
	get_tree().create_timer(0.55).timeout.connect(func():
		if is_instance_valid(self):
			if is_instance_valid(_audio_moneda):
				_audio_moneda.play()
			_mostrar_celebracion_premio(premio)
	)


func _mostrar_celebracion_premio(premio: Dictionary) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.05, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 540)
	card.add_theme_stylebox_override("panel", _crear_estilo(Color(0.07, 0.08, 0.11, 0.96), C_AMBER_BRIGHT, 16, 2, 24))
	center.add_child(card)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 40)
	mc.add_theme_constant_override("margin_right", 40)
	mc.add_theme_constant_override("margin_top", 34)
	mc.add_theme_constant_override("margin_bottom", 34)
	card.add_child(mc)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	mc.add_child(vb)

	var lbl_top := Label.new()
	lbl_top.text = "PREMIO REVELADO"
	lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_top.add_theme_font_size_override("font_size", 24)
	lbl_top.add_theme_color_override("font_color", C_AMBER_BRIGHT)
	if _fuente_titulo: lbl_top.add_theme_font_override("font", _fuente_titulo)
	vb.add_child(lbl_top)

	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(220, 220)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	match str(premio.get("tipo", "")):
		"esmeraldas": tr.texture = _tex_esmeralda
		"dinero": tr.texture = _tex_dinero
		"pase_mapa": tr.texture = _tex_pase
	vb.add_child(tr)

	var lbl_val := Label.new()
	lbl_val.text = "%s  %s" % [str(premio.get("titulo", "")), str(premio.get("sub", "")).to_upper()]
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val.add_theme_font_size_override("font_size", 38)
	lbl_val.add_theme_color_override("font_color", C_TEXT)
	if _fuente_titulo: lbl_val.add_theme_font_override("font", _fuente_titulo)
	vb.add_child(lbl_val)

	var btn_ok := Button.new()
	btn_ok.text = "RECOGER"
	btn_ok.custom_minimum_size = Vector2(360, 72)
	btn_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_ok.focus_mode = Control.FOCUS_NONE
	btn_ok.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_ok.add_theme_font_size_override("font_size", 26)
	btn_ok.add_theme_color_override("font_color", Color(0.07, 0.08, 0.10, 1.0))
	if _fuente_titulo: btn_ok.add_theme_font_override("font", _fuente_titulo)
	btn_ok.add_theme_stylebox_override("normal", _crear_estilo(C_AMBER, C_AMBER_BRIGHT, 12, 1, 10))
	btn_ok.add_theme_stylebox_override("hover", _crear_estilo(C_AMBER_BRIGHT, Color.WHITE, 12, 1, 14))
	btn_ok.pressed.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	vb.add_child(btn_ok)

	card.pivot_offset = card.custom_minimum_size * 0.5
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	tr.pivot_offset = tr.custom_minimum_size * 0.5
	tr.scale = Vector2(0.75, 0.75)
	var tw := overlay.create_tween().set_parallel(true)
	tw.tween_property(overlay, "color:a", 0.78, 0.25)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_property(card, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tr, "scale", Vector2.ONE, 0.40).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _aplicar_boton_salir(btn: Button, tam: int) -> void:
	var normal := _crear_estilo(Color(0.16, 0.09, 0.09, 0.55), Color(0.78, 0.28, 0.26, 0.45), 10, 1, 4)
	var hover := _crear_estilo(Color(0.78, 0.28, 0.26, 0.24), Color(0.78, 0.28, 0.26, 0.75), 10, 1, 6)
	var pressed := _crear_estilo(Color(0.78, 0.28, 0.26, 0.35), C_CRIMSON, 10, 1, 8)
	pressed.border_width_bottom = 2
	var disabled := _crear_estilo(Color(1.0, 1.0, 1.0, 0.04), C_BORDER_FROST, 10, 1, 0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", normal)
	if _fuente_titulo: btn.add_theme_font_override("font", _fuente_titulo)
	btn.add_theme_font_size_override("font_size", tam)
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.9, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.9, 1.0))
	btn.add_theme_color_override("font_disabled_color", C_TEXT_MUTED)


func _crear_estilo(fondo: Color, borde: Color, radio: int, grosor: int = 1, sombra: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(grosor)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = sombra
	sb.shadow_offset = Vector2(0, 3)
	return sb
