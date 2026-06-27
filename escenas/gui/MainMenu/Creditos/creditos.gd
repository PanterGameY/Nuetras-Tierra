extends CanvasLayer

@export var scroll_speed: float = 60.0
@export var pause_before_scroll: float = 1.2
@export var fade_height: int = 120

@export var credits_data: Array = [
	{'title':'Desarrollo','names':['PanterGameY - Líder de Proyecto']},
	{'title':'Música & SFX','names':['Studio Sound']},
	{'title':'QA & Testers','names':['Equipo Beta','Usuarios Preliminares']},
	{'title':'Agradecimientos','names':['Familia','Amigos','Comunidad de Jugadores']},
]

@onready var _fondo: ColorRect = $Fondo
@onready var logo: TextureRect = $Logo
@onready var _viewport_ctrl: Control = $ViewportCtrl
@onready var credits_label: RichTextLabel = $ViewportCtrl/CreditsLabel
@onready var btn_back: Button = $BtnBack
@onready var btn_skip: Button = $BtnSkip
@onready var top_fade: ColorRect = $ViewportCtrl/TopFade
@onready var bottom_fade: ColorRect = $ViewportCtrl/BottomFade

var _tween = null
var _max_scroll := 0.0

func _ready() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_skip:
		btn_skip.pressed.connect(_on_skip_pressed)

	get_viewport().connect('size_changed', Callable(self, '_on_viewport_size_changed'))
	await get_tree().process_frame
	_on_viewport_size_changed()
	_populate_credits()
	await get_tree().process_frame
	_start_scroll()

func _on_viewport_size_changed() -> void:
	var visible = get_viewport().get_visible_rect().size
	if _fondo:
		_fondo.size = visible
	if _viewport_ctrl:
		var view_w = min(1200, visible.x - 160)
		var view_h = min(720, visible.y - 160)
		_viewport_ctrl.position = Vector2((visible.x - view_w) / 2, (visible.y - view_h) / 2 + 40)
		_viewport_ctrl.size = Vector2(view_w, view_h)
		if credits_label:
			credits_label.custom_minimum_size = Vector2(view_w - 80, max(200, view_h - 80))

		if top_fade:
			top_fade.size = Vector2(view_w, fade_height)
			top_fade.position = Vector2(0, 0)
		if bottom_fade:
			bottom_fade.size = Vector2(view_w, fade_height)
			bottom_fade.position = Vector2(0, max(0, view_h - fade_height))

func _populate_credits() -> void:
	if not credits_label:
		printerr("[Creditos] CreditsLabel no encontrado")
		return
	var bb := ''
	bb += '[center][color=#ffd27f][font_size=64]NUESTRA TIERRA[/font_size][/color][/center]\n\n'
	for group in credits_data:
		bb += '[center][font_size=48][color=#ffb347]' + str(group.title) + '[/color][/font_size][/center]\n'
		for name in group.names:
			bb += '[center][font_size=40][color=#ffffff]' + str(name) + '[/color][/font_size][/center]\n'
		bb += '\n'
	bb += '[center][font_size=40][color=#aaaaaa]Gracias por jugar a Nuestra Tierra.[/color][/font_size][/center]\n'
	credits_label.bbcode_text = bb

func _start_scroll() -> void:
	await get_tree().process_frame
	if not credits_label:
		return
	var vbar = credits_label.get_v_scroll_bar()
	if not vbar:
		return
	_max_scroll = vbar.max_value
	if _max_scroll <= 0:
		return
	await get_tree().create_timer(pause_before_scroll).timeout
	var dur = max(0.5, _max_scroll / scroll_speed)
	_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(vbar, 'value', _max_scroll, dur)
	_tween.finished.connect(_on_scroll_finished)

func _on_scroll_finished() -> void:
	var f = ColorRect.new()
	f.color = Color(0,0,0,0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size = get_viewport().get_visible_rect().size
	add_child(f)
	var tw = create_tween()
	tw.tween_property(f, 'color:a', 1.0, 0.9)
	await tw.finished
	if ResourceLoader.exists('res://scenes/MainMenu.tscn'):
		get_tree().change_scene_to_file('res://scenes/MainMenu.tscn')
	else:
		get_tree().quit()

func _on_back_pressed() -> void:
	if ResourceLoader.exists('res://scenes/MainMenu.tscn'):
		get_tree().change_scene_to_file('res://scenes/MainMenu.tscn')

func _on_skip_pressed() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if credits_label:
		var vbar = credits_label.get_v_scroll_bar()
		if vbar:
			vbar.value = vbar.max_value

func _input(event) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
		elif event.keycode == KEY_SPACE:
			_on_skip_pressed()