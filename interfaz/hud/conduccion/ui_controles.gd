# ui_controles.gd
# HUD táctil del vehículo. Funciona con mouse (PC) y touch (Android).
# Usa solo nodos Button — sin TouchScreenButton que no funciona en PC.
# Adjunta al CanvasLayer "UIVehiculo", hijo directo del RigidBody3D (npr).
extends CanvasLayer

# ── Joystick ──────────────────────────────────────────────────────────────────
@onready var joy_area:  Control = $Joystick/Area
@onready var joy_knob:  Control = $Joystick/Area/Knob

# ── Gas / Freno / Freno de mano ───────────────────────────────────────────────
@onready var btn_gas:    Button = $Acciones/BtnGas
@onready var btn_freno:  Button = $Acciones/BtnFreno
@onready var btn_fmano:  Button = $Acciones/BtnFrenoMano

# ── Selector de marchas ───────────────────────────────────────────────────────
@onready var btn_menos:  Button = $Marchas/BtnMenos
@onready var btn_mas:    Button = $Marchas/BtnMas
@onready var lbl_marcha: Label  = $Marchas/Display

# ── Cámara ────────────────────────────────────────────────────────────────────
@onready var btn_cam:    Button = $BtnCamara

# ── HUD ───────────────────────────────────────────────────────────────────────
@onready var lbl_vel:          Label       = $HUD/LblVel
@onready var lbl_rpm:          Label       = $HUD/LblRPM
@onready var lbl_marcha_hud:   Label       = $HUD/LblMarchaGrande
@onready var barra_rpm:        ProgressBar = $HUD/BarraRPM
@onready var contenedor_mapa:  Control     = $Minimapa

# ── Estado ────────────────────────────────────────────────────────────────────
const RADIO_JOY: float = 80.0
const MARCHAS: Array[String] = ["R", "N", "1", "2", "3", "4", "5", "6"]

var _marcha_idx: int = 1   # "N"
var _joy_dragging: bool = false
var _joy_touch_id: int = -1
var _joy_centro: Vector2

var _coche:   RigidBody3D = null
var _rpm_ref: Node = null

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Buscar coche y RPM
	var p = get_parent()
	if p is RigidBody3D:
		_coche = p
		_rpm_ref = p.get_node_or_null("Motor/ControladorRPM")

	# ── Conectar señales de botones ───────────────────────────────────────────

	# Gas — mantener presionado
	btn_gas.button_down.connect(func(): InputVehiculo.set_gas(1.0))
	btn_gas.button_up.connect(func():   InputVehiculo.set_gas(0.0))

	# Freno — mantener presionado
	btn_freno.button_down.connect(func(): InputVehiculo.set_freno(1.0))
	btn_freno.button_up.connect(func():   InputVehiculo.set_freno(0.0))

	# Freno de mano — toggle
	btn_fmano.button_down.connect(func(): InputVehiculo.set_fmano(true))
	btn_fmano.button_up.connect(func():   InputVehiculo.set_fmano(false))

	# Marchas
	btn_menos.pressed.connect(_marcha_bajar)
	btn_mas.pressed.connect(_marcha_subir)

	# Cámara
	btn_cam.pressed.connect(_cambiar_camara)

	# Asegurarse de que los botones de gas/freno no pierdan el input al deslizar
	btn_gas.action_mode   = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn_freno.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

	# Joystick: capturar input en el área
	joy_area.gui_input.connect(_on_joy_input)

	# Estado inicial
	_marcha_idx = MARCHAS.find("N")
	_sync_marcha()
	visible = false

# ── Proceso: HUD ──────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not visible: return
	_actualizar_hud()

func _actualizar_hud() -> void:
	if _coche and lbl_vel:
		var kmh: float = abs(_coche.linear_velocity.dot(-_coche.global_transform.basis.z)) * 3.6
		lbl_vel.text = "%d\nkm/h" % int(kmh)

	if _rpm_ref:
		if lbl_rpm:
			lbl_rpm.text = "%d\nRPM" % int(_rpm_ref.rpm_actual)
		if barra_rpm:
			var norm: float = _rpm_ref.get_rpm_norm()
			barra_rpm.value = norm * 100.0
			if   norm > 0.85: barra_rpm.modulate = Color(1.0, 0.15, 0.15)
			elif norm > 0.65: barra_rpm.modulate = Color(1.0, 0.75, 0.0)
			else:             barra_rpm.modulate = Color(0.25, 1.0, 0.45)

	if lbl_marcha_hud:
		lbl_marcha_hud.text = InputVehiculo.marcha

# ── Joystick ──────────────────────────────────────────────────────────────────
func _on_joy_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			if evento.pressed:
				_joy_dragging = true
				_joy_centro   = joy_area.size * 0.5
			else:
				_joy_dragging = false
				_resetear_joy()

	elif evento is InputEventMouseMotion and _joy_dragging:
		_mover_joy(evento.position)

	elif evento is InputEventScreenTouch:
		if evento.pressed:
			_joy_dragging  = true
			_joy_touch_id  = evento.index
			_joy_centro    = joy_area.size * 0.5
		else:
			_joy_dragging  = false
			_joy_touch_id  = -1
			_resetear_joy()

	elif evento is InputEventScreenDrag:
		if evento.index == _joy_touch_id:
			_mover_joy(evento.position)

func _mover_joy(pos: Vector2) -> void:
	var delta: Vector2  = pos - _joy_centro
	var clamped: Vector2 = delta.limit_length(RADIO_JOY)
	# Centro del knob dentro del área
	joy_knob.position = _joy_centro - joy_knob.size * 0.5 + clamped
	InputVehiculo.set_dir(clamped.x / RADIO_JOY)

func _resetear_joy() -> void:
	joy_knob.position = joy_area.size * 0.5 - joy_knob.size * 0.5
	InputVehiculo.set_dir(0.0)

# ── Marchas ───────────────────────────────────────────────────────────────────
func _marcha_bajar() -> void:
	_marcha_idx = max(_marcha_idx - 1, 0)
	_sync_marcha()

func _marcha_subir() -> void:
	_marcha_idx = min(_marcha_idx + 1, MARCHAS.size() - 1)
	_sync_marcha()

func _sync_marcha() -> void:
	var m: String = MARCHAS[_marcha_idx]
	InputVehiculo.set_marcha(m)
	if lbl_marcha: lbl_marcha.text = m
	if lbl_marcha:
		match m:
			"R":    lbl_marcha.modulate = Color(1.0, 0.3, 0.3)
			"N":    lbl_marcha.modulate = Color(1.0, 1.0, 0.3)
			_:      lbl_marcha.modulate = Color(0.3, 1.0, 0.5)

# ── Cámara ────────────────────────────────────────────────────────────────────
func _cambiar_camara() -> void:
	var ev        = InputEventAction.new()
	ev.action     = "cambiar_camara"
	ev.pressed    = true
	Input.parse_input_event(ev)

# ── API pública (llamada desde npr.gd) ────────────────────────────────────────
func mostrar() -> void:
	_marcha_idx = MARCHAS.find("N")
	_sync_marcha()
	_resetear_joy()
	InputVehiculo.reset_tactil()
	visible = true

func ocultar() -> void:
	InputVehiculo.reset_tactil()
	visible = false
