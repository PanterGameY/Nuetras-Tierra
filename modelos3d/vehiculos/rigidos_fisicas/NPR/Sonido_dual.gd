extends Node3D

@export_group("Motor")
@export var sonido_ralenti: AudioStream
@export var sonido_aceleracion: AudioStream
@export var sonido_encender: AudioStream
@export var sonido_apagar: AudioStream

@export_group("Pitch Motor")
# Pitch mínimo del motor (en ralentí o inicio de marcha). Rango acústico natural para evitar distorsión o aliasing.
@export_range(0.5, 1.2, 0.01) var pitch_min: float = 0.78
# Pitch máximo del motor al límite de revoluciones.
@export_range(1.0, 2.0, 0.05) var pitch_max: float = 1.38
# Velocidad de subida del pitch general del ralentí cuando aceleras.
@export_range(1.0, 30.0, 0.5) var suavizado_subida: float = 18.0
# Velocidad de caída del pitch general del ralentí cuando dejas de acelerar.
@export_range(0.5, 20.0, 0.5) var suavizado_bajada: float = 14.0
# Velocidad de caída de pitch durante un cambio de marcha.
@export_range(1.0, 60.0, 0.5) var suavizado_cambio: float = 24.0
# Velocidad de subida de pitch tras completar el cambio (recuperación).
@export_range(0.5, 20.0, 0.5) var suavizado_recuperacion: float = 12.0
# Qué tan rápido sigue el pitch del sonido de aceleración a las RPM reales del vehículo.
@export_range(1.0, 30.0, 0.5) var suavizado_power_pitch: float = 10.0
# Curva de respuesta del pitch: 1.0 = lineal progresivo. 1.05 proporciona aceleración uniforme y realista.
@export_range(0.5, 2.0, 0.05) var pitch_curva_exponente: float = 1.05

@export_group("Volumen Motor")
@export_range(-40.0, 6.0, 1.0) var vol_ralenti_base: float = -8.0
@export_range(-40.0, 6.0, 1.0) var vol_ralenti_max: float = -4.0
@export_range(-40.0, 6.0, 1.0) var vol_aceleracion_base: float = -14.0
@export_range(-40.0, 6.0, 1.0) var vol_aceleracion_max: float = 0.0

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
var _pitch_power: float = 0.5 # Pitch independiente del sonido de aceleración
var _gas_suavizado: float = 0.0  # Gas suavizado para transiciones de volumen
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
var _vol_idle_actual: float = -80.0
var _vol_power_actual: float = -80.0

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

	_asegurar_loop(_idle)
	_asegurar_loop(_power)

	_vol_idle_actual = vol_ralenti_base
	_vol_power_actual = -60.0

	for p in [_idle, _power]:
		if p:
			p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	if _start_player:
		_start_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		_start_target_volume = 0.0
	if _stop_player:
		_stop_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

func _asegurar_loop(player: AudioStreamPlayer3D) -> void:
	if not player or not player.stream:
		return
	if player.stream is AudioStreamWAV:
		var wav = player.stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		if wav.loop_end <= 0 and wav.mix_rate > 0:
			wav.loop_end = int(wav.get_length() * wav.mix_rate)

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
		# Priorizar siempre el export property. Solo usar el stream del nodo hijo
		# si el usuario NO asignó ninguno desde el inspector.
		if stream == null:
			stream = player.stream
	else:
		player = AudioStreamPlayer3D.new()
		player.name = nombre
		add_child(player)
	# Siempre aplicar el stream resuelto (el export tiene prioridad)
	if stream != null:
		player.stream = stream
	player.volume_db = vol
	player.unit_size = alcance_sonido
	# Evitar conectar la señal más de una vez si el nodo ya existía
	var cb := Callable(self, "_on_audio_finish").bind(player)
	if not player.finished.is_connected(cb):
		player.finished.connect(cb)
	return player

func _get_iv() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/InputVehiculo")

func solicitar_encendido() -> void:
	var iv = _get_iv()
	if not is_inside_tree():
		if iv:
			iv.motor_encendido = true
			_motor_listo = true
		return
		
	if _start_player and _start_player.stream and _start_player.is_inside_tree():
		_esperando_encendido = true
		_motor_listo = false
		_start_player.stop()
		_start_player.volume_db = 0.0
		_start_player.play(0.0)
		var t_espera = duracion_arranque if duracion_arranque > 0.0 else 1.5
		if get_tree():
			_timer_arranque = get_tree().create_timer(t_espera)
			_timer_arranque.timeout.connect(_on_timer_arranque_fin)
	else:
		if iv:
			iv.motor_encendido = true
			_motor_listo = true

func _on_timer_arranque_fin() -> void:
	if not _esperando_encendido:
		return
	_esperando_encendido = false
	_motor_listo = true
	var iv = _get_iv()
	if iv:
		iv.motor_encendido = true
	if _idle and not _idle.playing:
		_idle.play(0.0)
	if _power and not _power.playing:
		_power.play(0.0)

func reproducir_encender() -> void:
	if not is_inside_tree():
		return
	var iv = _get_iv()
	if iv:
		iv.motor_encendido = true
	_motor_listo = true
	_esperando_encendido = false
	if _start_player and _start_player.stream and _start_player.is_inside_tree():
		_start_player.stop()
		_start_player.volume_db = 0.0
		_start_player.play(0.0)
	if _idle and not _idle.playing:
		_idle.play(0.0)
	if _power and not _power.playing:
		_power.play(0.0)

func reproducir_apagar() -> void:
	if not is_inside_tree():
		return
	if _idle and _idle.playing:
		_idle.stop()
	if _power and _power.playing:
		_power.stop()
	if _engine_brake and _engine_brake.playing:
		_engine_brake.stop()
	if _reverse and _reverse.playing:
		_reverse.stop()
	_vol_idle_actual = -80.0
	_vol_power_actual = -80.0
	if _stop_player and _stop_player.stream and _stop_player.is_inside_tree():
		_stop_player.stop()
		_stop_player.play(0.0)

func detener_todos_los_sonidos() -> void:
	for p in [_idle, _power, _brake, _release_brake, _engine_brake, _shift, _turn, _horn, _reverse]:
		if p and p.playing:
			p.stop()
	_vol_idle_actual = -80.0
	_vol_power_actual = -80.0
	_bocina_activa = false
	_turn_activo = "apagado"
	_turn_state = false

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
		var iv = _get_iv()
		if iv:
			iv.motor_encendido = true
		if _idle and not _idle.playing:
			_idle.play(0.0)
		if _power and not _power.playing:
			_power.play(0.0)
	elif player == _horn and _bocina_activa:
		player.play()
	elif player == _turn and _turn_state:
		player.play()
	elif player == _idle or player == _power:
		var iv = _get_iv()
		var motor_on = (iv != null and iv.get("motor_encendido") == true)
		if motor_on:
			player.play(0.0)
	# NOTA: La reversa y el freno NO se re-reproducen aquí.
	# _actualizar_reverse() y _actualizar_brake() ya manejan su loop
	# correctamente. Re-disparar aquí causaba solapamiento de audio.

func _es_reversa() -> bool:
	var iv = _get_iv()
	if not iv:
		return false
	# Preferir método público si existe
	if iv.has_method("esta_en_reversa"):
		return iv.esta_en_reversa()
	# Fallback: comparar contra el enum
	if iv.has("marcha_actual") and iv.has("Marcha"):
		return iv.marcha_actual == iv.Marcha.REVERSA
	# Último recurso: comparar con el valor entero tradicional
	return iv.marcha_actual == 1

func _freno_activo() -> bool:
	var iv = _get_iv()
	return iv != null and iv.freno > umbral_freno_inicio

func _freno_motor_activo() -> bool:
	var p = get_parent()
	if p:
		if p.get("freno_motor_activo") != null:
			return p.get("freno_motor_activo") == true
		var m = p.get_node_or_null("Motor")
		if m and m.get("freno_motor_activo") != null:
			return m.get("freno_motor_activo") == true
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

	var iv = _get_iv()
	var motor_on = (iv != null and iv.get("motor_encendido") == true)
	if not motor_on or _esperando_encendido:
		if _idle:
			_idle.volume_db = -80.0
			if _idle.playing:
				_idle.stop()
		if _power:
			_power.volume_db = -80.0
			if _power.playing:
				_power.stop()
		if _engine_brake and _engine_brake.playing:
			_engine_brake.stop()
		if _reverse and _reverse.playing:
			_reverse.stop()
		_actualizar_brake()
		_actualizar_horn_fade(delta)
		_actualizar_turn(delta)
		return

	if not _idle.playing:
		_idle.play()
	if _power and not _power.playing:
		_power.play()

	# === PITCH DEL RALENTÍ (sigue el motor con modulación acústica natural) ===
	var pitch_idle_target = lerpf(0.92, 1.18, clampf(rpm_norm, 0.0, 1.0))
	var factor: float
	if _en_cambio and pitch_idle_target < _pitch_actual:
		factor = suavizado_cambio
	elif _en_recuperacion and pitch_idle_target > _pitch_actual:
		factor = suavizado_recuperacion
	elif pitch_idle_target > _pitch_actual:
		factor = suavizado_subida
	else:
		factor = suavizado_bajada
	_pitch_actual = move_toward(_pitch_actual, pitch_idle_target, delta * factor)

	if _idle:
		_idle.pitch_scale = _pitch_actual

	# === PITCH DEL SONIDO DE ACELERACIÓN: sigue las RPM con progresión realista ===
	var rpm_curvado = pow(clampf(rpm_norm, 0.0, 1.0), pitch_curva_exponente)
	var pitch_power_target: float

	if _en_cambio:
		pitch_power_target = maxf(pitch_min, lerpf(pitch_min, pitch_max, rpm_curvado) * 0.85)
	else:
		pitch_power_target = lerpf(pitch_min, pitch_max, rpm_curvado)

	var factor_power: float
	if pitch_power_target < _pitch_power:
		factor_power = suavizado_cambio if _en_cambio else suavizado_bajada
	else:
		factor_power = suavizado_power_pitch

	_pitch_power = lerpf(_pitch_power, pitch_power_target, 1.0 - exp(-factor_power * delta))

	if _power:
		_power.pitch_scale = _pitch_power

	# === GAS SUAVIZADO: respuesta gradual que no dispara rugido por un toque rápido ===
	_gas_suavizado = move_toward(_gas_suavizado, gas, delta * 3.5)

	if _en_cambio:
		_gas_cambio = move_toward(_gas_cambio, 0.30, delta * 10.0)
	elif _en_recuperacion:
		_gas_cambio = move_toward(_gas_cambio, 1.0, delta * suavizado_recuperacion)
	else:
		_gas_cambio = 1.0

	var gas_efectivo = _gas_suavizado * _gas_cambio

	# === VOLUMEN RALENTÍ: constante en reposo, atenuación ligera (4 dB) al acelerar ===
	var vol_idle_target: float = vol_ralenti_base - clampf(gas_efectivo * 4.0, 0.0, 4.0)

	# === VOLUMEN DE ACELERACIÓN: completamente silencioso en ralentí, escala suave con el pedal ===
	var vol_power_target: float = -60.0
	var factor_presion_pedal = clampf(gas_efectivo, 0.0, 1.0)

	if factor_presion_pedal > 0.03:
		# Escala de forma natural con la carga: pedal + RPM
		# Un toque leve (0.15) produce un sonido bajo (-30 dB); acelerar a fondo (+3 dB)
		var carga = factor_presion_pedal * 0.70 + (rpm_norm * factor_presion_pedal) * 0.30
		vol_power_target = lerpf(vol_aceleracion_base - 14.0, vol_aceleracion_max, pow(carga, 1.15))
	else:
		# Retención / desaceleración suave si las RPM siguen altas
		if rpm_norm > 0.25:
			var factor_overrun = clampf((rpm_norm - 0.25) / 0.75, 0.0, 1.0)
			vol_power_target = lerpf(-55.0, vol_aceleracion_base - 8.0, factor_overrun * 0.40)
		else:
			vol_power_target = -65.0

	# Interpolación de volumen anti-popping
	var vel_lerp_idle = 8.0
	var vel_lerp_power = 9.0 if vol_power_target > _vol_power_actual else 5.5
	_vol_idle_actual = lerpf(_vol_idle_actual, vol_idle_target, clampf(delta * vel_lerp_idle, 0.0, 1.0))
	_vol_power_actual = lerpf(_vol_power_actual, vol_power_target, clampf(delta * vel_lerp_power, 0.0, 1.0))

	if _idle:
		_idle.volume_db = _vol_idle_actual
	if _power:
		_power.volume_db = _vol_power_actual

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
	# El pitch_power cae automáticamente siguiendo rpm_norm durante el cambio;
	# no hace falta un reset manual.

func set_recovering(activo: bool) -> void:
	_en_recuperacion = activo

func set_freno_motor(activo: bool) -> void:
	# Llamado por motor.gd. Activa/desactiva el sonido de freno de motor
	# respetando el stream asignado por el usuario en la escena.
	if not _engine_brake:
		return
	if activo:
		if _engine_brake.stream and not _engine_brake.playing:
			_engine_brake.play()
	else:
		if _engine_brake.playing:
			_engine_brake.stop()
