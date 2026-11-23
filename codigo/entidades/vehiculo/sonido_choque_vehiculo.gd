class_name SonidoChoqueVehiculo
extends Node3D

## Sistema reutilizable de sonido de choques e impactos para vehículos RigidBody3D.
## Evalúa cambios bruscos de velocidad con contacto físico real y reproduce el sonido acorde a la severidad.

const RUTA_LEVE := "res://recursos/sonidos_vehiculo/efectos/choque_leve.mp3"
const RUTA_MEDIO := "res://recursos/sonidos_vehiculo/efectos/golpe_metal.mp3"
const RUTA_FUERTE := "res://recursos/sonidos_vehiculo/sonidos_metalicos/car_crash.mp3"
const RUTA_CLANK := "res://recursos/sonidos_vehiculo/sonidos_metalicos/clank.mp3"

var _stream_leve: AudioStream = null
var _stream_medio: AudioStream = null
var _stream_fuerte: AudioStream = null
var _stream_clank: AudioStream = null

var _player: AudioStreamPlayer3D = null
var _cuerpo: RigidBody3D = null
var _vel_previa: Vector3 = Vector3.ZERO
var _cooldown: float = 0.0
var _frames_inicio: int = 0
var _estaba_en_aire: bool = false

func configurar(cuerpo: RigidBody3D) -> void:
	_cuerpo = cuerpo
	if not is_instance_valid(_cuerpo):
		return
	_cuerpo.contact_monitor = true
	if _cuerpo.max_contacts_reported < 4:
		_cuerpo.max_contacts_reported = 4
	_vel_previa = _cuerpo.linear_velocity
	_frames_inicio = 6

	if ResourceLoader.exists(RUTA_LEVE):
		_stream_leve = load(RUTA_LEVE) as AudioStream
	if ResourceLoader.exists(RUTA_MEDIO):
		_stream_medio = load(RUTA_MEDIO) as AudioStream
	if ResourceLoader.exists(RUTA_FUERTE):
		_stream_fuerte = load(RUTA_FUERTE) as AudioStream
	if ResourceLoader.exists(RUTA_CLANK):
		_stream_clank = load(RUTA_CLANK) as AudioStream

	_player = AudioStreamPlayer3D.new()
	_player.name = "AudioChoque3D"
	_player.max_distance = 75.0
	_player.unit_size = 6.0
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_player)

func actualizar(delta: float, ruedas_suelo: int) -> void:
	if not is_instance_valid(_cuerpo) or not is_instance_valid(_player):
		return
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)

	var vel_actual: Vector3 = _cuerpo.linear_velocity
	if _frames_inicio > 0:
		_frames_inicio -= 1
		_vel_previa = vel_actual
		_estaba_en_aire = (ruedas_suelo == 0)
		return

	var dv: float = (vel_actual - _vel_previa).length()
	var en_aire_ahora: bool = (ruedas_suelo == 0)
	var aterrizo_fuerte: bool = _estaba_en_aire and (not en_aire_ahora) and dv > 4.5
	var hay_contacto_chasis: bool = _cuerpo.get_contact_count() > 0

	if _cooldown <= 0.0:
		if hay_contacto_chasis and dv > 2.2:
			_reproducir_por_intensidad(dv)
		elif aterrizo_fuerte:
			_reproducir_aterrizaje(dv)

	_vel_previa = vel_actual
	_estaba_en_aire = en_aire_ahora

func _reproducir_por_intensidad(dv: float) -> void:
	var stream: AudioStream = null
	var vol_db: float = -6.0
	if dv >= 12.0 and _stream_fuerte:
		stream = _stream_fuerte
		vol_db = clampf(linear_to_db(clampf(dv / 18.0, 0.55, 1.0)), -8.0, 2.0)
	elif dv >= 6.0 and _stream_medio:
		stream = _stream_medio
		vol_db = clampf(linear_to_db(clampf(dv / 12.0, 0.40, 0.95)), -10.0, 0.0)
	elif _stream_leve:
		stream = _stream_leve
		vol_db = clampf(linear_to_db(clampf((dv - 1.5) / 6.0, 0.25, 0.80)), -14.0, -2.0)
	elif _stream_clank:
		stream = _stream_clank
		vol_db = -8.0

	if not stream:
		return
	_player.stream = stream
	_player.volume_db = vol_db
	_player.pitch_scale = randf_range(0.88, 1.12)
	_player.play()
	_cooldown = 0.22

func _reproducir_aterrizaje(dv: float) -> void:
	var stream: AudioStream = _stream_clank if _stream_clank else _stream_medio
	if not stream:
		return
	_player.stream = stream
	_player.volume_db = clampf(linear_to_db(clampf(dv / 16.0, 0.30, 0.85)), -12.0, -1.0)
	_player.pitch_scale = randf_range(0.82, 1.02)
	_player.play()
	_cooldown = 0.25
