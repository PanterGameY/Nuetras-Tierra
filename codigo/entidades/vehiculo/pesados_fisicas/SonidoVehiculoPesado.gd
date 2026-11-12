class_name SonidoVehiculoPesado
extends Node3D

## Controlador acústico diésel multicapa con física analítica basada en Rigs of Rods (RoR)
## Optimizado para Android (Godot 4.7) - Loop forzado garantizado y cero silencios en aceleración.

enum TipoPesado {
	TRACTOMULA_15L,    # Tractocamión pesado (T800 / Kenworth / Mack) - Grave, resonante, turbo pesado
	CAMION_MEDIANO,    # Camión de carga mediano (NPR / Hino / Fuso) - 4/6 cilindros ágil
	VOLQUETA_PESADA,   # Volqueta / Volquete doble troque - Rugido rudo bajo carga
	AUTOBUS_URBANO     # Autobús intermunicipal o urbano - Tono más suave y continuo
}

@export_group("Tipo de Vehículo")
@export var tipo_vehiculo: TipoPesado = TipoPesado.TRACTOMULA_15L:
	set(val):
		tipo_vehiculo = val
		_aplicar_perfil_vehiculo()

@export_range(0.5, 1.5, 0.05) var multiplicador_tono_global: float = 0.85
@export_range(-20.0, 15.0, 0.5) var volumen_maestro_db: float = 2.0
@export_range(5.0, 100.0, 1.0) var alcance_sonido: float = 45.0
@export_range(20.0, 300.0, 5.0) var distancia_maxima: float = 140.0

# --- RUTAS DE LOS SONIDOS (Organizados en camion_pesado) ---
@export_group("Sonidos de Motor Diésel")
@export var audio_idle: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_diesel_idle.wav")
@export var audio_low: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_diesel_low.wav")
@export var audio_medium: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_diesel_medium.wav")
@export var audio_high: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_diesel_high.wav")
@export var audio_force: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_diesel_force.wav")

@export_group("Sonidos de Turbo y Válvulas")
@export var audio_turbo: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_turbo.wav")
@export var audio_wastegate: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_wastegate_flutter.wav")
@export var audio_aire_valvula: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_valve.wav")
@export var audio_cambio_marcha: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_shift.wav")

@export_group("Frenos")
@export var audio_freno_motor: AudioStream = preload("res://recursos/sonidos_vehiculo/freno_motor/FrenoM1.wav")
@export var audio_freno_servicio: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_brakes.wav")
@export var audio_freno_mano: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_parking_brakes.wav")

@export_group("Seguridad e Ignición")
@export var audio_reversa: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_reverse_beep.wav")
@export var audio_arranque: AudioStream = preload("res://recursos/sonidos_vehiculo/motor/camion_pesado/default_starter.wav")
@export var audio_apagar: AudioStream = preload("res://modelos3d/vehiculos/tractomulas/cabezotes/T800/Sonidos/Apagar.wav")
@export var audio_bocina: AudioStream = preload("res://modelos3d/vehiculos/tractomulas/cabezotes/T800/Sonidos/Buzina.ogg")

# --- REPRODUCTORES INTERNOS ---
var _p_idle: AudioStreamPlayer3D
var _p_low: AudioStreamPlayer3D
var _p_medium: AudioStreamPlayer3D
var _p_high: AudioStreamPlayer3D
var _p_force: AudioStreamPlayer3D
var _p_turbo: AudioStreamPlayer3D
var _p_jake: AudioStreamPlayer3D
var _p_brakes: AudioStreamPlayer3D
var _p_sfx_aire: AudioStreamPlayer3D
var _p_sfx_cambio: AudioStreamPlayer3D
var _p_sfx_reversa: AudioStreamPlayer3D
var _p_sfx_arranque: AudioStreamPlayer3D
var _p_sfx_apagar: AudioStreamPlayer3D
var _p_sfx_bocina: AudioStreamPlayer3D
var _p_sfx_flutter: AudioStreamPlayer3D

# --- ESTADO EN TIEMPO REAL ---
var motor_encendido: bool = true
var freno_motor_activo: bool = false
var en_reversa: bool = false
var en_cambio: bool = false
var en_recuperacion: bool = false
var gas_actual: float = 0.0
var rpm_norm_actual: float = 0.0
var turbo_psi_simulado: float = 0.0
var temporizador_aire: float = 0.0

func _ready() -> void:
	_inicializar_canales_audio()
	_aplicar_perfil_vehiculo()
	if motor_encendido:
		_iniciar_reproduccion_bucles()

func _asegurar_loop(stream: AudioStream) -> void:
	if not stream:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		if wav.loop_end <= 0 and wav.mix_rate > 0:
			wav.loop_end = int(wav.get_length() * wav.mix_rate)

func _instanciar_player(nombre_nodo: String, recurso: AudioStream, volumen_db: float, es_bucle: bool = false) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = nombre_nodo
	p.stream = recurso
	p.volume_db = volumen_db
	p.unit_size = alcance_sonido
	p.max_distance = distancia_maxima
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	p.bus = "Master"
	
	if es_bucle and recurso != null:
		_asegurar_loop(recurso)
		var cb := Callable(self, "_on_loop_terminado").bind(p)
		if not p.finished.is_connected(cb):
			p.finished.connect(cb)

	add_child(p)
	return p

func _on_loop_terminado(player: AudioStreamPlayer3D) -> void:
	if not motor_encendido or not is_instance_valid(player):
		return
	# Re-disparar inmediatamente si por cualquier motivo el sample alcanzó el final
	if player == _p_sfx_reversa:
		if en_reversa and not player.playing:
			player.play(0.0)
	elif player != _p_jake:
		if not player.playing:
			player.play(0.0)

func _inicializar_canales_audio() -> void:
	# Bucles continuos del motor
	_p_idle = _instanciar_player("Audio_Idle", audio_idle, -6.0, true)
	_p_low = _instanciar_player("Audio_Low", audio_low, -80.0, true)
	_p_medium = _instanciar_player("Audio_Med", audio_medium, -80.0, true)
	_p_high = _instanciar_player("Audio_High", audio_high, -80.0, true)
	_p_force = _instanciar_player("Audio_Force", audio_force, -80.0, true)
	_p_turbo = _instanciar_player("Audio_Turbo", audio_turbo, -80.0, true)
	_p_jake = _instanciar_player("Audio_Jake", audio_freno_motor, -80.0, true)
	_p_brakes = _instanciar_player("Audio_Brakes", audio_freno_servicio, -80.0, false)
	_p_sfx_reversa = _instanciar_player("SFX_Reverse", audio_reversa, -4.0, true)

	# One-shots y SFX de eventos mecánicos
	_p_sfx_aire = _instanciar_player("SFX_AirPurge", audio_aire_valvula, -1.0, false)
	_p_sfx_cambio = _instanciar_player("SFX_Shift", audio_cambio_marcha, 0.0, false)
	_p_sfx_arranque = _instanciar_player("SFX_Starter", audio_arranque, 0.0, false)
	_p_sfx_apagar = _instanciar_player("SFX_Apagar", audio_apagar, 0.0, false)
	_p_sfx_bocina = _instanciar_player("SFX_Bocina", audio_bocina, 2.0, false)
	_p_sfx_flutter = _instanciar_player("SFX_Flutter", audio_wastegate, -1.0, false)

func _iniciar_reproduccion_bucles() -> void:
	if _p_idle and not _p_idle.playing: _p_idle.play(0.0)
	if _p_low and not _p_low.playing: _p_low.play(0.0)
	if _p_medium and not _p_medium.playing: _p_medium.play(0.0)
	if _p_high and not _p_high.playing: _p_high.play(0.0)
	if _p_force and not _p_force.playing: _p_force.play(0.0)
	if _p_turbo and not _p_turbo.playing: _p_turbo.play(0.0)

func _aplicar_perfil_vehiculo() -> void:
	match tipo_vehiculo:
		TipoPesado.TRACTOMULA_15L:
			multiplicador_tono_global = 0.84
		TipoPesado.VOLQUETA_PESADA:
			multiplicador_tono_global = 0.94
		TipoPesado.CAMION_MEDIANO:
			multiplicador_tono_global = 1.08
		TipoPesado.AUTOBUS_URBANO:
			multiplicador_tono_global = 1.16

# --- API PRINCIPAL DE AUDIO ---
func procesar_audio(rpm_norm: float, gas_suavizado: float, delta: float) -> void:
	if not motor_encendido:
		return

	# Salvaguarda: garantizar que las capas continuas nunca se queden silenciadas por fin de sample
	if not _p_idle.playing: _p_idle.play(0.0)
	if not _p_low.playing: _p_low.play(0.0)
	if not _p_medium.playing: _p_medium.play(0.0)
	if not _p_high.playing: _p_high.play(0.0)
	if not _p_force.playing: _p_force.play(0.0)
	if not _p_turbo.playing: _p_turbo.play(0.0)

	rpm_norm_actual = rpm_norm
	gas_actual = gas_suavizado
	var gas_efectivo: float = 0.0 if en_cambio else gas_suavizado

	# 1. Modulación de Tono (Pitch Bending Analítico Dinámico)
	var factor_rpm: float = lerpf(0.82, 1.46, rpm_norm) * multiplicador_tono_global
	_p_idle.pitch_scale = factor_rpm * 0.92
	_p_low.pitch_scale = factor_rpm * 0.98
	_p_medium.pitch_scale = factor_rpm * 1.02
	_p_high.pitch_scale = factor_rpm * 1.08
	_p_force.pitch_scale = factor_rpm

	# 2. Fundido Cruzado Multicapa estilo Rigs of Rods (Crossfading con amplio solapamiento)
	# Esto erradica zonas muertas o caídas de volumen al acelerar
	var ganancia_idle: float = clampf(1.0 - (rpm_norm / 0.42), 0.0, 1.0)
	var ganancia_low: float = clampf(1.0 - absf((rpm_norm - 0.28) / 0.28), 0.0, 1.0)
	var ganancia_med: float = clampf(1.0 - absf((rpm_norm - 0.58) / 0.32), 0.0, 1.0)
	var ganancia_high: float = clampf((rpm_norm - 0.48) / 0.52, 0.0, 1.0)

	_p_idle.volume_db = linear_to_db(maxf(ganancia_idle * 0.90, 0.0001)) + volumen_maestro_db - 1.0
	_p_low.volume_db = linear_to_db(maxf(ganancia_low * 0.95, 0.0001)) + volumen_maestro_db
	_p_medium.volume_db = linear_to_db(maxf(ganancia_med * 1.00, 0.0001)) + volumen_maestro_db + 1.0
	_p_high.volume_db = linear_to_db(maxf(ganancia_high * 1.05, 0.0001)) + volumen_maestro_db + 1.5

	# 3. Capa de Combustión e Inyector Diésel bajo Esfuerzo (default_diesel_force)
	# Aporta el estruendo mecánico pesado cuando se pisa el acelerador
	var factor_carga: float = clampf(gas_efectivo * lerpf(0.55, 1.25, rpm_norm), 0.0, 1.0)
	_p_force.volume_db = linear_to_db(maxf(factor_carga, 0.0001)) + volumen_maestro_db + 2.0

	# 4. Spooling Analítico del Turbo de Geometría Variable
	var turbo_target: float = gas_efectivo * lerpf(0.30, 1.0, rpm_norm)
	turbo_psi_simulado = move_toward(turbo_psi_simulado, turbo_target, delta * 1.2)
	_p_turbo.pitch_scale = lerpf(0.85, 1.70, turbo_psi_simulado)
	_p_turbo.volume_db = linear_to_db(maxf(turbo_psi_simulado * 0.85, 0.0001)) + volumen_maestro_db - 2.0

	# 5. Freno de Compresión (Jake Brake)
	if freno_motor_activo and gas_suavizado < 0.10 and rpm_norm > 0.15:
		if not _p_jake.playing:
			_p_jake.play(0.0)
		var vol_jake: float = clampf(lerpf(0.5, 1.0, rpm_norm), 0.1, 1.0)
		_p_jake.pitch_scale = lerpf(0.80, 1.25, rpm_norm) * multiplicador_tono_global
		_p_jake.volume_db = linear_to_db(vol_jake) + volumen_maestro_db + 3.0
	else:
		_p_jake.volume_db = -80.0
		if _p_jake.playing:
			_p_jake.stop()

	# 6. Descarga Periódica y Dinámica del Calderín de Aire Comprimido
	temporizador_aire += delta * lerpf(0.6, 2.0, rpm_norm)
	if temporizador_aire > 35.0:
		purgar_aire(0.85)
		temporizador_aire = 0.0

func reproducir_cambio(marcha: int, total_marchas: int = 10, gas: float = 0.0, rpm_norm: float = 0.0) -> void:
	if _p_sfx_cambio:
		_p_sfx_cambio.pitch_scale = randf_range(0.96, 1.04)
		_p_sfx_cambio.play()
		
	# Si había carga previa de turbo y se corta gas durante el cambio, aleteo wastegate
	if turbo_psi_simulado > 0.35 and _p_sfx_flutter:
		_p_sfx_flutter.pitch_scale = randf_range(0.95, 1.05)
		_p_sfx_flutter.volume_db = linear_to_db(clampf(turbo_psi_simulado, 0.3, 1.0)) + volumen_maestro_db
		_p_sfx_flutter.play()

func set_shifting(shifting: bool) -> void:
	en_cambio = shifting

func set_recovering(recovering: bool) -> void:
	en_recuperacion = recovering

func set_freno_motor(activo: bool) -> void:
	freno_motor_activo = activo

func purgar_aire(volumen_relativo: float = 1.0) -> void:
	if _p_sfx_aire:
		_p_sfx_aire.pitch_scale = randf_range(0.93, 1.07)
		_p_sfx_aire.volume_db = linear_to_db(clampf(volumen_relativo, 0.1, 1.0)) + volumen_maestro_db
		_p_sfx_aire.play()

func activar_reversa(activar: bool) -> void:
	en_reversa = activar
	if not _p_sfx_reversa: return
	if activar and not _p_sfx_reversa.playing:
		_p_sfx_reversa.play(0.0)
	elif not activar and _p_sfx_reversa.playing:
		_p_sfx_reversa.stop()

func detener_todos_los_sonidos() -> void:
	motor_encendido = false
	for p in [_p_idle, _p_low, _p_medium, _p_high, _p_force, _p_turbo, _p_jake, _p_brakes, _p_sfx_reversa, _p_sfx_flutter]:
		if is_instance_valid(p) and p.playing:
			p.stop()

func encender_motor() -> void:
	motor_encendido = true
	_iniciar_reproduccion_bucles()

func solicitar_encendido() -> void:
	reproducir_encender()

func reproducir_encender() -> void:
	if _p_sfx_arranque:
		_p_sfx_arranque.play()
	encender_motor()

func reproducir_apagar() -> void:
	detener_todos_los_sonidos()
	if _p_sfx_apagar:
		_p_sfx_apagar.play()

func tocar_bocina(activar: bool) -> void:
	if not _p_sfx_bocina: return
	if activar and not _p_sfx_bocina.playing:
		_p_sfx_bocina.play()
	elif not activar and _p_sfx_bocina.playing:
		_p_sfx_bocina.stop()

func set_bocina(activar: bool) -> void:
	tocar_bocina(activar)

func set_direccional(_lado: String) -> void:
	pass
