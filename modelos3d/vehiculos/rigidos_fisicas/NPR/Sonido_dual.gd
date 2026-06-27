extends Node3D

@export_group("Motor")
@export var sonido_ralenti: AudioStream
@export var sonido_aceleracion: AudioStream
@export var sonido_encender: AudioStream
@export var sonido_apagar: AudioStream

@export_group("Pitch Motor")
@export_range(0.1, 3.0, 0.05) var pitch_min: float = 0.4
@export_range(0.1, 3.0, 0.05) var pitch_max: float = 1.6
@export_range(1.0, 30.0, 0.5) var suavizado_subida: float = 6.0
@export_range(0.5, 20.0, 0.5) var suavizado_bajada: float = 3.0
# Velocidad de caída de pitch durante un cambio de marcha. Mayor = caída más drástica y audible.
@export_range(1.0, 60.0, 0.5) var suavizado_cambio: float = 8.0
# Velocidad de subida de pitch tras completar el cambio (recuperación). Menor = más lento y realista.
@export_range(0.5, 20.0, 0.5) var suavizado_recuperacion: float = 1.5

@export_group("Volumen Motor")
@export_range(-60.0, 0.0, 1.0) var vol_ralenti_base: float = -40.0
@export_range(-60.0, 0.0, 1.0) var vol_ralenti_max: float = -32.0
@export_range(-60.0, 0.0, 1.0) var vol_aceleracion_base: float = -60.0
@export_range(-60.0, 0.0, 1.0) var vol_aceleracion_max: float = -20.0

@export_group("Freno")
@export var sonido_freno: AudioStream
@export_range(-60.0, 20.0, 1.0) var volumen_freno: float = 0.0
@export var umbral_freno_inicio: float = 0.02
@export var loop_inicio: float = 0.09
@export var loop_fin: float = 0.45

@export_group("Release Freno")
@export var sonido_release_freno: AudioStream
@export_range(-60.0, 20.0, 1.0) var volumen_release_freno: float = -4.0

@export_group("Freno de Motor")
@export var sonido_freno_motor: AudioStream
@export_range(-60.0, 20.0, 1.0) var volumen_freno_motor: float = 0.0

@export_group("Cambio de Marcha")
@export var sonido_cambio: AudioStream
@export_range(-60.0, 20.0, 1.0) var volumen_cambio: float = 0.0
@export_range(0.5, 2.0, 0.05) var pitch_cambio_min: float = 0.7
@export_range(0.5, 2.0, 0.05) var pitch_cambio_max: float = 1.3
@export_range(0.0, 1.0, 0.05) var influencia_gas: float = 0.3
@export_range(0.0, 1.0, 0.05) var influencia_rpm: float = 0.5

@export_group("Direccionales")
@export var sonido_direccional: AudioStream
@export_range(-60.0, 20.0, 1.0) var volumen_direccional: float = 0.0

@export_group("Bocina")
@export var sonido_bocina: AudioStream
@export_range(-60.0, 20.0, 1.0) var volumen_bocina: float = 0.0
@export_range(0.01, 1.0, 0.01) var bocina_fade_in: float = 0.12
@export_range(0.01, 1.0, 0.01) var bocina_fade_out: float = 0.18

@export_group("Reversa")
@export var sonido_reversa: AudioStream
@export_range(-60.0, 20.0, 1.0) var volumen_reversa: float = 0.0

@export_group("Encendido")
# Segundos que se reproducen del sonido de arranque antes de activar el motor.
# 0.0 = reproducir el sonido completo.
@export_range(0.0, 10.0, 0.1) var duracion_arranque: float = 0.0
# Duración del fundido del ralentí después del arranque (transición suave).
@export_range(0.5, 5.0, 0.1) var fade_in_motor: float = 1.5

@export_group("3D")
@export_range(0.1, 50.0, 0.5) var alcance_sonido: float = 12.0

var _idle: AudioStreamPlayer3D
var _power: AudioStreamPlayer3D
var _start_player: AudioStreamPlayer3D
var _stop_player: AudioStreamPlayer3D
var _brake: AudioStreamPlayer3D
var _release_brake: AudioStreamPlayer3D
var _engine_brake: AudioStreamPlayer3D
var _shift: AudioStreamPlayer3D
var _turn: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _reverse: AudioStreamPlayer3D

var _pitch_actual: float = 0.5
var _turn_timer: float = 0.0
var _turn_activo: String = "apagado"
var _turn_state: bool = false
var _bocina_activa: bool = false
var _bocina_volumen_actual: float = -80.0
var _prev_brake: bool = false
var release_playing: bool = false
var _esperando_encendido: bool = false
var _motor_listo: bool = false
var _timer_arranque: SceneTreeTimer = null
var _en_cambio: bool = false
var _en_recuperacion: bool = false
var _fade_in_tiempo: float = 0.0
var _fade_start_tiempo: float = 0.0
var _fade_start_activo: bool = false
var _start_target_volume: float = 0.0
var _gas_cambio: float = 1.0  # Multiplicador de gas para volumen durante cambio (0=silencio, 1=normal)

func _ready() -> void:
	if sonido_encender == null:
		sonido_encender = _generar_tono(120, 200, 1.2)
	if sonido_apagar == null:
		sonido_apagar = _generar_tono(200, 80, 0.8)

	_idle = _obtener_audio("SonidoIdle", sonido_ralenti, vol_ralenti_base)
	_power = _obtener_audio("SonidoAcelerar", sonido_aceleracion, vol_aceleracion_base)
	_start_player = _obtener_audio("SonidoEncender", sonido_encender, 0.0)
	_stop_player = _obtener_audio("SonidoApagar", sonido_apagar, 0.0)
	_brake = _obtener_audio("SonidoFreno", sonido_freno, volumen_freno)
	_release_brake = _obtener_audio("SonidoReleaseFreno", sonido_release_freno, volumen_release_freno)
	_engine_brake = _obtener_audio("SonidoFrenoMotor", sonido_freno_motor, volumen_freno_motor)
	_shift = _obtener_audio("SonidoCambio", sonido_cambio, volumen_cambio)
	_turn = _obtener_audio("SonidoDireccional", sonido_direccional, volumen_direccional)
	_horn = _obtener_audio("SonidoBocina", sonido_bocina, volumen_bocina)
	_reverse = _obtener_audio("SonidoReversa", sonido_reversa, volumen_reversa)

	for p in [_idle, _power]:
		if p:
			p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	if _start_player:
		_start_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	if _stop_player:
		_stop_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

	# Preparar volumen objetivo del encendido y mantener el player silencioso hasta iniciar
	if _start_player:
		_start_target_volume = _start_player.volume_db
		_start_player.volume_db = -80.0

func _generar_tono(freq_inicial: float, freq_final: float, duracion: float, volumen: float = 0.3) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(duracion * sample_rate)
	var data = PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = lerpf(freq_inicial, freq_final, t / duracion)
		var env = 1.0
		if t < 0.02:
			env = t / 0.02
		if t > duracion - 0.05:
			env = (duracion - t) / 0.05
		var valor = sin(2.0 * PI * freq * t) + sin(2.0 * PI * freq * 1.5 * t) * 0.3
		var sample = int(clamp(valor * env * volumen * 32767, -32768, 32767))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _obtener_audio(nombre: String, stream: AudioStream, vol: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D
	if has_node(nombre):
		player = get_node(nombre)
		if stream == null:
			stream = player.stream
	else:
		player = AudioStreamPlayer3D.new()
		player.name = nombre
		add_child(player)
	player.stream = stream
	player.volume_db = vol
	player.unit_size = alcance_sonido
	player.finished.connect(Callable(self, "_on_audio_finish").bind(player))
	return player

func solicitar_encendido() -> void:
	if _start_player and _start_player.stream:
		_esperando_encendido = true
		_motor_listo = false
		_start_player.stop()
		# empezar silencioso y hacer fade en el sonido de encendido
		_start_player.volume_db = -80.0
		_fade_start_tiempo = 0.0
		_fade_start_activo = true
		_start_player.play(0.0)
		if duracion_arranque > 0.0:
			_timer_arranque = get_tree().create_timer(duracion_arranque)
			_timer_arranque.timeout.connect(_on_timer_arranque_fin)
		else:
			_timer_arranque = null
	else:
		if is_instance_valid(InputVehiculo):
			InputVehiculo.motor_encendido = true
			_motor_listo = true

func _on_timer_arranque_fin() -> void:
	if not _esperando_encendido:
		return
	_esperando_encendido = false
	_motor_listo = true
	# Detener cualquier fade de encendido y preparar estado
	_fade_start_activo = false
	_fade_start_tiempo = 0.0
	if _start_player and _start_player.playing:
		_start_player.stop()
		_start_player.volume_db = -80.0
	if is_instance_valid(InputVehiculo):
		InputVehiculo.motor_encendido = true

func reproducir_encender() -> void:
	if _start_player and _start_player.stream:
		# reproducir con fade para consistencia
		_start_player.stop()
		_start_player.volume_db = -80.0
		_fade_start_tiempo = 0.0
		_fade_start_activo = true
		_start_player.play(0.0)

func reproducir_apagar() -> void:
	if _stop_player and _stop_player.stream:
		_stop_player.stop()
		_stop_player.play(0.0)

func _set(_property: StringName, _value) -> bool:
	_aplicar_volumenes()
	return false

func _aplicar_volumenes() -> void:
	if _idle:
		_idle.unit_size = alcance_sonido
	if _power:
		_power.unit_size = alcance_sonido
	if _brake:
		_brake.volume_db  = volumen_freno
		_brake.unit_size  = alcance_sonido
	if _release_brake:
		_release_brake.volume_db = volumen_release_freno
		_release_brake.unit_size = alcance_sonido
	if _engine_brake:
		_engine_brake.volume_db = volumen_freno_motor
		_engine_brake.unit_size = alcance_sonido
	if _shift:
		_shift.volume_db  = volumen_cambio
		_shift.unit_size  = alcance_sonido
	if _turn:
		_turn.volume_db   = volumen_direccional
		_turn.unit_size   = alcance_sonido
	if _horn:
		_horn.volume_db   = volumen_bocina
		_horn.unit_size   = alcance_sonido
	if _reverse:
		_reverse.volume_db = volumen_reversa
		_reverse.unit_size = alcance_sonido

func _on_audio_finish(player: AudioStreamPlayer3D) -> void:
	if player == _start_player and _esperando_encendido:
		_esperando_encendido = false
		_motor_listo = true
		# detener fade de encendido (el sonido ya terminó)
		_fade_start_activo = false
		_fade_start_tiempo = 0.0
		if is_instance_valid(InputVehiculo):
			InputVehiculo.motor_encendido = true
	elif player == _horn and _bocina_activa:
		player.play()
	elif player == _turn and _turn_state:
		player.play()
	elif player == _reverse and _es_reversa():
		if player.stream:
			player.play()
	elif player == _brake:
		if _freno_activo():
			player.play(loop_inicio)

func _es_reversa() -> bool:
	if not is_instance_valid(InputVehiculo):
		return false
	# Preferir método público si existe
	if InputVehiculo.has_method("esta_en_reversa"):
		return InputVehiculo.esta_en_reversa()
	# Fallback: comparar contra el enum
	if InputVehiculo.has("marcha_actual") and InputVehiculo.has("Marcha"):
		return InputVehiculo.marcha_actual == InputVehiculo.Marcha.REVERSA
	# Último recurso: comparar con el valor entero tradicional
	return InputVehiculo.marcha_actual == 1

func _freno_activo() -> bool:
	return is_instance_valid(InputVehiculo) and InputVehiculo.freno > umbral_freno_inicio

func _freno_motor_activo() -> bool:
	var motor = get_parent()
	if motor and motor.get("freno_motor_activo") != null:
		return motor.get("freno_motor_activo") == true
	return false

func _actualizar_brake() -> void:
	var frenando = _freno_activo()
	if _brake and _brake.stream:
		if frenando and not _prev_brake:
			_brake.stop()
			_brake.play(0.0)
		elif _prev_brake and not frenando:
			_brake.stop()
			if _release_brake and _release_brake.stream and not _release_brake.playing:
				_release_brake.play()
	_prev_brake = frenando

func _actualizar_engine_brake() -> void:
	if not _engine_brake:
		return
	if _freno_motor_activo():
		if not _engine_brake.playing:
			_engine_brake.play()
	else:
		if _engine_brake.playing:
			_engine_brake.stop()

func _actualizar_turn(delta: float) -> void:
	if not _turn or _turn_activo == "apagado":
		if _turn:
			_turn.stop()
		_turn_state = false
		return
	_turn_timer += delta
	if _turn_timer >= 0.4:
		_turn_timer = 0.0
		_turn_state = not _turn_state
		if _turn_state:
			_turn.play()
		else:
			_turn.stop()

func _actualizar_horn_fade(delta: float) -> void:
	if not _horn:
		return
	if _bocina_activa:
		if not _horn.playing:
			_horn.volume_db = -80.0
			_bocina_volumen_actual = -80.0
			_horn.play()
		_bocina_volumen_actual = lerpf(_bocina_volumen_actual, volumen_bocina, 1.0 - exp(-bocina_fade_in * 60.0 * delta))
		_horn.volume_db = _bocina_volumen_actual
	else:
		if _horn.playing:
			_bocina_volumen_actual = lerpf(_bocina_volumen_actual, -80.0, 1.0 - exp(-bocina_fade_out * 60.0 * delta))
			_horn.volume_db = _bocina_volumen_actual
			if _bocina_volumen_actual <= -78.0:
				_horn.stop()
				_bocina_volumen_actual = -80.0

func _actualizar_fade_start(delta: float) -> void:
	if not _start_player or not _start_player.stream or not _fade_start_activo:
		return
	if fade_in_motor <= 0.0:
		_start_player.volume_db = _start_target_volume
		_fade_start_activo = false
		return
	_fade_start_tiempo += delta
	var frac = clampf(_fade_start_tiempo / fade_in_motor, 0.0, 1.0)
	_start_player.volume_db = lerpf(-80.0, _start_target_volume, frac)
	if frac >= 1.0:
		_fade_start_activo = false

func _actualizar_reverse() -> void:
	if not _reverse:
		return
	# Asegurar que el player tenga el stream correcto (fallback por seguridad)
	if not _reverse.stream and sonido_reversa:
		_reverse.stream = sonido_reversa
	if _es_reversa():
		if not _reverse.stream:
			push_warning("Sonido_dual: 'sonido_reversa' no asignado o no cargado para este vehículo")
			return
		if not _reverse.playing:
			# Si el volumen está extremadamente bajo, no lo dejemos inaudible por error
			if _reverse.volume_db <= -80.0:
				_reverse.volume_db = max(volumen_reversa, -20.0)
			_reverse.stop()
			_reverse.play(0.0)
	else:
		if _reverse.playing:
			_reverse.stop()

func procesar_audio(rpm_norm: float, gas: float, delta: float) -> void:
	if not is_instance_valid(_idle):
		return

	var motor_on = is_instance_valid(InputVehiculo) and InputVehiculo.get("motor_encendido") == true
	if not motor_on or _esperando_encendido:
		# Mientras esperamos el encendido, actualizar fade del sonido de arranque
		if _esperando_encendido:
			_actualizar_fade_start(delta)
		if _idle:
			_idle.volume_db = -80.0
		if _power:
			_power.volume_db = -80.0
		return

	if _fade_in_tiempo < fade_in_motor:
		_fade_in_tiempo += delta

	if _idle and not _idle.playing:
		_idle.play()
	if _power and not _power.playing:
		_power.play()

	var pitch_target = lerpf(pitch_min, pitch_max, rpm_norm)
	var factor: float
	if _en_cambio and pitch_target < _pitch_actual:
		factor = suavizado_cambio
	elif _en_recuperacion and pitch_target > _pitch_actual:
		factor = suavizado_recuperacion
	elif pitch_target > _pitch_actual:
		factor = suavizado_subida
	else:
		factor = suavizado_bajada
	_pitch_actual = move_toward(_pitch_actual, pitch_target, delta * factor)

	if _idle:
		_idle.pitch_scale = _pitch_actual
	if _power:
		_power.pitch_scale = _pitch_actual

	# Durante el cambio: desacoplar el sonido de aceleración (como el embrague real).
	# Durante la recuperación: volver a mezclar el gas gradualmente.
	if _en_cambio:
		_gas_cambio = move_toward(_gas_cambio, 0.0, delta * 8.0)
	elif _en_recuperacion:
		_gas_cambio = move_toward(_gas_cambio, 1.0, delta * suavizado_recuperacion)
	else:
		_gas_cambio = 1.0

	var gas_efectivo = gas * _gas_cambio
	var mezcla = clamp(gas_efectivo * gas_efectivo * (3.0 - 2.0 * gas_efectivo), 0.0, 1.0)
	var vol_idle = lerpf(vol_ralenti_base, vol_ralenti_max, mezcla)
	var vol_power = lerpf(vol_aceleracion_base, vol_aceleracion_max, mezcla)

	# No hacer el fundido del ralenti aquí; el fade se aplica al encendido.
	if _idle:
		_idle.volume_db = vol_idle
	if _power:
		_power.volume_db = vol_power

	if rpm_norm > 0.97 and _power:
		_power.volume_db += sin(Time.get_ticks_msec() * 0.05) * 5.0

	_actualizar_brake()
	_actualizar_reverse()
	_actualizar_engine_brake()
	_actualizar_horn_fade(delta)
	_actualizar_turn(delta)

func set_direccional(lado: String) -> void:
	_turn_activo = lado
	if lado == "apagado":
		_turn_timer = 0.0
		_turn_state = false
		if _turn:
			_turn.stop()

func set_bocina(activo: bool) -> void:
	_bocina_activa = activo

func reproducir_cambio(gear: int, total_marchas: int, gas: float, rpm_norm: float) -> void:
	if not _shift or not _shift.stream:
		return
	var progreso_gear = float(gear) / max(total_marchas - 1, 1)
	var factor_gas = 1.0 + gas * influencia_gas
	var factor_rpm = 1.0 + rpm_norm * influencia_rpm
	var pitch = lerpf(pitch_cambio_min, pitch_cambio_max, progreso_gear) * factor_gas * factor_rpm
	_shift.pitch_scale = clampf(pitch, 0.3, 3.0)
	_shift.play()

func set_shifting(activo: bool) -> void:
	_en_cambio = activo

func set_recovering(activo: bool) -> void:
	_en_recuperacion = activo
