class_name MotoTraficoIA
extends VehiculoTraficoIA

## Personalidades de conducción estilo latinoamericano
enum PerfilConduccion {
	REPARTIDOR,   # Mensajero / domiciliario apresurado: filtra agresivamente, alta velocidad, adelantamientos por izquierda o derecha
	PROMEDIO,     # Motociclista urbano ágil: busca espacios libres, velocidad estándar dinámica
	TRANQUILO     # Conductor relajado: adelantamientos prudentes cuando el tráfico se detiene
}

enum EstadoMoto {
	CRUCERO,
	ADELANTANDO,
	RETORNANDO
}

@export_group("Personalidad y Comportamiento Moto")
@export var perfil_actual: PerfilConduccion = PerfilConduccion.REPARTIDOR
@export var permitir_adelantamiento: bool = true
@export var inclinacion_maxima_deg: float = 24.0

# Estado interno de navegación y filtrado
var _estado_moto: EstadoMoto = EstadoMoto.CRUCERO
var _desfase_crucero_base: float = 0.55  # Desfase normal en el carril (motos raramente van al centro geométrico)
var _desfase_objetivo: float = 0.55
var _progreso_inicio_adelanto: float = 0.0
var _tiempo_en_adelanto: float = 0.0
var _semilla_ritmo: float = 0.0
var _inclinacion_actual: float = 0.0
var _h_offset_anterior: float = 0.0

# Referencias visuales internas de la moto
var _nodo_visual: Node3D = null
var _rueda_delantera: Node3D = null
var _rueda_trasera: Node3D = null
var _horquilla_delantera: Node3D = null
var _manubrio: Node3D = null
var _malla_chasis: MeshInstance3D = null
var _malla_guardabarro: MeshInstance3D = null


func _ready() -> void:
	# Ajustes físicos y de dimensiones para moto
	longitud_vehiculo = 2.1
	radio_rueda = 0.30
	offset_y = 0.43
	distancia_minima = 4.2
	distancia_raycast_corto = 3.8
	permitir_cambio_carril = false # La moto gestiona su propio adelantamiento condicionado
	_semilla_ritmo = randf_range(0.0, 100.0)

	_configurar_perfil_aleatorio()
	_setup_referencias_moto()

	super._ready()
	collision_layer = 7
	collision_mask = 7


func _setup_referencias_moto() -> void:
	# El pivot visual es el nodo Moto1 interno o el primer Node3D visual
	_nodo_visual = get_node_or_null("Moto1")
	if _nodo_visual == null:
		_nodo_visual = get_node_or_null("Visual")
	if _nodo_visual == null:
		for h in get_children():
			if h is Node3D and not h is CollisionShape3D and not h is RayCast3D:
				_nodo_visual = h
				break

	_rueda_delantera = find_child("wheel_front", true, false) as Node3D
	_rueda_trasera = find_child("wheel_rear", true, false) as Node3D
	_horquilla_delantera = find_child("forks_front", true, false) as Node3D
	_manubrio = find_child("handlebars", true, false) as Node3D
	_malla_chasis = find_child("chassis", true, false) as MeshInstance3D
	_malla_guardabarro = find_child("mudguard", true, false) as MeshInstance3D


func _configurar_perfil_aleatorio() -> void:
	# 50% repartidores/mensajeros, 35% promedio, 15% tranquilos
	var r := randf()
	if r < 0.50:
		perfil_actual = PerfilConduccion.REPARTIDOR
	elif r < 0.85:
		perfil_actual = PerfilConduccion.PROMEDIO
	else:
		perfil_actual = PerfilConduccion.TRANQUILO

	match perfil_actual:
		PerfilConduccion.REPARTIDOR:
			# Rápido, aceleración contundente
			velocidad_crucero = randf_range(20.0, 24.5) # ~72 a 88 km/h
			aceleracion = randf_range(5.5, 6.8)
			frenado = 9.5
			inclinacion_maxima_deg = 24.0
			velocidad_cambio_lateral = 3.6
			_desfase_crucero_base = [-0.7, 0.7].pick_random()
		PerfilConduccion.PROMEDIO:
			# Ritmo ágil estándar
			velocidad_crucero = randf_range(16.5, 19.5) # ~60 a 70 km/h
			aceleracion = randf_range(4.0, 5.0)
			frenado = 8.5
			inclinacion_maxima_deg = 18.0
			velocidad_cambio_lateral = 2.8
			_desfase_crucero_base = [-0.55, 0.55].pick_random()
		PerfilConduccion.TRANQUILO:
			# Desplazamiento relajado
			velocidad_crucero = randf_range(13.0, 15.5) # ~47 a 56 km/h
			aceleracion = randf_range(2.8, 3.6)
			frenado = 7.5
			inclinacion_maxima_deg = 14.0
			velocidad_cambio_lateral = 2.2
			_desfase_crucero_base = [-0.4, 0.4].pick_random()

	_desfase_objetivo = _desfase_crucero_base
	_h_offset_anterior = _desfase_crucero_base


## Aplicación de pintura al azar en el chasis y guardabarros de la moto
func aplicar_apariencia_aleatoria() -> void:
	if _malla_chasis == null:
		_setup_referencias_moto()

	var color_elegido: Color
	if colores_carroceria.size() > 0:
		color_elegido = colores_carroceria[randi() % colores_carroceria.size()]
	else:
		color_elegido = PALETA_COLORES_DEFAULT.pick_random()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_elegido
	mat.metallic = 0.45
	mat.roughness = 0.22
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.8
	mat.clearcoat_roughness = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if _malla_chasis != null:
		_malla_chasis.material_override = mat
	if _malla_guardabarro != null:
		_malla_guardabarro.material_override = mat


## Reinicio cuando es reutilizada desde el pool de tráfico
func reset_for_pool(manager: TrafficNetworkManager3D, start_lane: TrafficLane3D, start_distance: float = 0.0) -> void:
	_configurar_perfil_aleatorio()
	_estado_moto = EstadoMoto.CRUCERO
	_desfase_objetivo = _desfase_crucero_base
	_h_offset_anterior = _desfase_crucero_base
	_tiempo_en_adelanto = 0.0
	super.reset_for_pool(manager, start_lane, start_distance)


func activar(nuevo_path_follow: PathFollow3D, progreso_inicial: float, nuevo_sentido: int = 1, desfase_carril: float = 0.0) -> void:
	_configurar_perfil_aleatorio()
	_estado_moto = EstadoMoto.CRUCERO
	_desfase_objetivo = _desfase_crucero_base
	_h_offset_anterior = _desfase_crucero_base
	_tiempo_en_adelanto = 0.0
	super.activar(nuevo_path_follow, progreso_inicial, nuevo_sentido, desfase_carril)


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or (path_follow == null and current_lane == null):
		return

	# Si está adelantando con suficiente desfase lateral, el vehículo líder de la curva está a un lado (no de frente)
	var esquivando_lateralmente := (_estado_moto == EstadoMoto.ADELANTANDO and absf(_desfase_lateral_actual) > 1.0)
	var dist_lider_respaldo := distancia_lider
	if esquivando_lateralmente:
		distancia_lider = INF

	# 1-2. Física base de avance, freno y comportamiento de carril (via _procesar_cambio_carril sobreescrito)
	super._physics_process(delta)

	if esquivando_lateralmente:
		distancia_lider = dist_lider_respaldo

	# 3. Efectos visuales de moto: rodamiento de ruedas, giro de manubrio e inclinación en curva/esquiva
	_actualizar_efectos_moto(delta)


func _procesar_cambio_carril(delta: float) -> void:
	_procesar_comportamiento_moto(delta)


## Lógica de adelantamiento, filtrado ("pasar por la mitad") y variación orgánica de acelerador
func _procesar_comportamiento_moto(delta: float) -> void:
	if path_follow == null:
		return

	var c_len: float = 1000.0
	var camino := path_follow.get_parent() as Path3D
	if camino != null and camino.curve != null:
		c_len = camino.curve.get_baked_length()

	var sensor_delante := _obtener_menor_distancia_sensores()
	var espacio_frente := minf(distancia_lider, sensor_delante)
	var bloqueo_jugador := _bloqueado_directo_por_jugador()

	# Distancia a la cual la moto decide no frenar pasivamente sino esquivar/adelantar
	var umbral_adelanto := 22.0 if perfil_actual == PerfilConduccion.REPARTIDOR else (18.0 if perfil_actual == PerfilConduccion.PROMEDIO else 14.0)

	match _estado_moto:
		EstadoMoto.CRUCERO:
			_desfase_objetivo = _desfase_crucero_base
			if permitir_adelantamiento and not bloqueo_jugador and espacio_frente < umbral_adelanto and not frenar_por_semaforo:
				# REQUISITO ESTRICTO: Solo adelantar si hay otro carril paralelo en la misma dirección
				var dir_fwd := -global_transform.basis.z.normalized()
				var info_paralelo: Dictionary = {}
				if network_manager != null and network_manager.has_method("obtener_info_carril_paralelo"):
					info_paralelo = network_manager.obtener_info_carril_paralelo(camino, global_position, dir_fwd, self)

				if info_paralelo.get("encontrado", false):
					_estado_moto = EstadoMoto.ADELANTANDO
					_progreso_inicio_adelanto = path_follow.progress
					_tiempo_en_adelanto = 0.0
					var d_lat: float = info_paralelo.get("distancia", 3.2)
					var lado: float = info_paralelo.get("lado", -1.0)
					_desfase_objetivo = d_lat * lado
				else:
					# No hay carril contiguo: mantenerse seguro en el centro de su carril
					_desfase_objetivo = clampf(_desfase_crucero_base, -0.45, 0.45)

		EstadoMoto.ADELANTANDO:
			_tiempo_en_adelanto += delta
			var avance_desde_inicio: float = fposmod(path_follow.progress - _progreso_inicio_adelanto, c_len)

			# Condiciones para completar el adelantamiento o abortar solo si el jugador bloquea directamente:
			if bloqueo_jugador or (espacio_frente > 14.0 and avance_desde_inicio > 16.0) or avance_desde_inicio > 26.0 or _tiempo_en_adelanto > 5.0:
				_estado_moto = EstadoMoto.RETORNANDO
				_desfase_objetivo = _desfase_crucero_base

		EstadoMoto.RETORNANDO:
			_desfase_objetivo = _desfase_crucero_base
			if absf(_desfase_lateral_actual - _desfase_crucero_base) < 0.15:
				_estado_moto = EstadoMoto.CRUCERO
				_desfase_crucero_base = [-0.45, 0.45].pick_random()

	# Desplazamiento lateral suave usando _desfase_lateral_actual (perpendicular a la curva)
	path_follow.h_offset = 0.0
	_desfase_lateral_actual = move_toward(_desfase_lateral_actual, _desfase_objetivo, velocidad_cambio_lateral * delta)


## Cálculo de velocidad objetivo con variaciones orgánicas y ráfaga al adelantar
func _calcular_velocidad_objetivo() -> float:
	var objetivo := velocidad_crucero * multiplicador_velocidad

	# Micro-oscilaciones orgánicas del acelerador ("golpes de gas / variaciones humanas")
	var tiempo_ms := float(Time.get_ticks_msec())
	var pulsacion_gas := sin(tiempo_ms * 0.0035 + _semilla_ritmo) * 0.95 + cos(tiempo_ms * 0.0017 + _semilla_ritmo * 2.0) * 0.4
	objetivo += pulsacion_gas

	# Durante el adelantamiento, la moto acelera con fuerza para pasar al vehículo rápidamente
	if _estado_moto == EstadoMoto.ADELANTANDO:
		objetivo = velocidad_crucero * 1.25

	# Límite de velocidad de la vía
	var camino: Node = null
	if current_lane != null:
		camino = current_lane
	elif path_follow != null:
		camino = path_follow.get_parent()

	if camino != null and camino.get("speed_limit") != null:
		var limite_ms: float = (float(camino.get("speed_limit")) * 1000.0) / 3600.0
		if limite_ms > 0.0:
			objetivo = minf(objetivo, limite_ms * 1.15) # Motos suelen superar levemente el límite

	# Al adelantar hacia carril despejado, no quedar clavada por el líder detenido del carril previo
	var esquivando_lateralmente := (_estado_moto == EstadoMoto.ADELANTANDO and (absf(_desfase_lateral_actual) > 0.9 or not _bloqueado_directo_por_jugador()))

	if not esquivando_lateralmente:
		if distancia_lider < INF:
			objetivo = minf(objetivo, _velocidad_segura(distancia_lider))

	# Los sensores frontales inmediatos siempre protegen contra choque directo o jugador
	var sensor_corto := _obtener_menor_distancia_sensores()
	var dist_jug_directo := _obtener_distancia_jugador_directa()
	if dist_jug_directo <= 4.5 or _bloqueado_directo_por_jugador():
		if sensor_corto <= distancia_raycast_corto:
			objetivo = 0.0
		elif sensor_corto < INF:
			objetivo = minf(objetivo, _velocidad_segura(sensor_corto))
	elif sensor_corto < INF:
		var umbral_freno := 2.8 if _estado_moto == EstadoMoto.ADELANTANDO else distancia_raycast_corto
		if sensor_corto <= umbral_freno:
			objetivo = 0.0
		elif not esquivando_lateralmente or sensor_corto < 7.0:
			objetivo = minf(objetivo, _velocidad_segura(sensor_corto))

	if frenar_por_semaforo:
		objetivo = 0.0

	return maxf(objetivo, 0.0)


## Efectos visuales: Inclinación en curva y maniobras (Roll), rotación de ruedas y manubrio
func _actualizar_efectos_moto(delta: float) -> void:
	if delta <= 0.0 or _lod_level >= 2:
		return
	if _nodo_visual == null:
		_setup_referencias_moto()

	# 1. Rotación de ruedas
	if radio_rueda > 0.0:
		var rot_angulo := -velocidad_actual * delta / radio_rueda
		if is_instance_valid(_rueda_delantera):
			_rueda_delantera.rotate_x(rot_angulo)
		if is_instance_valid(_rueda_trasera):
			_rueda_trasera.rotate_x(rot_angulo)

	# 2. Giro del manubrio y horquilla frontal
	if is_instance_valid(_horquilla_delantera):
		_horquilla_delantera.rotation.y = lerp_angle(_horquilla_delantera.rotation.y, angulo_ruedas * 0.75, delta * 12.0)
	elif is_instance_valid(_manubrio):
		_manubrio.rotation.y = lerp_angle(_manubrio.rotation.y, angulo_ruedas * 0.75, delta * 12.0)

	# 3. Inclinación dinámica de la moto (Banking / Roll)
	if is_instance_valid(_nodo_visual):
		var vel_lateral := (_desfase_lateral_actual - _h_offset_anterior) / delta
		_h_offset_anterior = _desfase_lateral_actual

		var factor_inclinacion := deg_to_rad(inclinacion_maxima_deg)
		# Se inclina proporcionalmente a la curva de la carretera (angulo_ruedas) y a las esquivas rápidas (vel_lateral)
		var inclinacion_deseada := clampf(-angulo_ruedas * 0.85 - (vel_lateral * 0.16), -factor_inclinacion, factor_inclinacion)

		_inclinacion_actual = lerp_angle(_inclinacion_actual, inclinacion_deseada, clampf(delta * 8.5, 0.0, 1.0))
		_nodo_visual.rotation.z = _inclinacion_actual
