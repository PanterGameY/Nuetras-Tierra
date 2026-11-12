class_name PesadoFisicasController
extends RigidBody3D

## Controlador de física analítica pesada inspirado en Rigs of Rods (RoR)
## Optimizado para Android (60 FPS estables en Godot 4.7)
## Integra motor diésel con curva spline, inercia de volante, transmisión
## neumática de 10 marchas, suspensión asimétrica (Bump/Rebound) y barra estabilizadora.

# --- 1. CONFIGURACIÓN DEL MOTOR DIÉSEL PESADO ---
@export_group("Motor Diésel")
@export var torque_max_nm: float = 2400.0         ## Torque máximo (Nm) típicamente 2000-2800 en camiones pesados
@export var rpm_idle: float = 600.0              ## Ralentí
@export var rpm_min_trabajo: float = 1100.0      ## Entrada de turbo
@export var rpm_max: float = 2300.0              ## Corte de inyección diésel pesado
@export var rpm_stall: float = 350.0             ## Calado de motor
@export var inercia_volante: float = 18.0        ## Inercia rotacional del cigüeñal (kg*m^2)
@export var motor_encendido: bool = true

# --- 2. TRANSMISIÓN MULTI-MARCHA ---
@export_group("Transmisión")
@export var relaciones_caja: Array[float] = [
	-13.8,  # R
	0.0,    # N
	14.4,   # 1ra
	10.8,   # 2da
	7.8,    # 3ra
	5.7,    # 4ta
	4.1,    # 5ta
	3.0,    # 6ta
	2.2,    # 7ma
	1.6,    # 8va
	1.2,    # 9na
	0.86    # 10ma (Sobremarcha)
]
@export var relacion_diferencial: float = 3.73
@export var tiempo_cambio: float = 0.55          ## Segundos que toma engranar marcha neumática
@export var fuerza_embrague: float = 12000.0     ## Rigidez de acople de embrague
@export var transmision_automatica: bool = true

# --- 3. FRENOS, RETARDER Y JAKE BRAKE ---
@export_group("Frenos y Retardador")
@export_enum("Apagado", "Bajo (33%)", "Medio (66%)", "Alto (100%)") var modo_jake_brake: int = 0
@export var torque_jake_max: float = 2100.0      ## Capacidad máxima de absorción del freno de compresión
@export var fuerza_frenos_servicio: float = 32000.0 ## Freno neumático de servicio (N)
@export var fuerza_freno_mano: float = 45000.0   ## Freno de estacionamiento (N)
@export var presion_aire_descarga: float = 1.0   ## Efecto de descarga neumática (Air Purge)

# --- 4. SUSPENSIÓN ASIMÉTRICA Y RUEDAS ---
@export_group("Suspensión Asimétrica")
@export var longitud_descanso: float = 0.55
@export var rigidez_compresion: float = 115000.0 ## N/m (Bump - compresión suave para absorber)
@export var rigidez_rebote: float = 95000.0     ## N/m (Rebound - extensión elástica)
@export var amortiguacion_compresion: float = 7500.0 ## N*s/m (Bump damping)
@export var amortiguacion_rebote: float = 18500.0   ## N*s/m (2.5x más alto para eliminar oscilaciones y bamboleo)
@export var rigidez_barra_estabilizadora: float = 35000.0 ## Rigidez anti-vuelco analítica inter-eje (N/m)
@export var radio_rueda: float = 0.52           ## Radio dinámico del neumático (m)
@export var angulo_max_direccion: float = 0.58  ## ~33 grados para ruedas directrices
@export var rigidez_lateral: float = 28000.0    ## Rigidez lateral Pacejka pesada (N/rad)

# --- NODOS INTERNOS ---
@export_group("Ruedas (RayCast3D)")
@export var ruedas_raycast: Array[RayCast3D] = [] ## Orden recomendado: [FL, FR, RL1, RR1, RL2, RR2]
@export var ruedas_directrices: Array[int] = [0, 1] ## Índices de ruedas que giran
@export var ruedas_motrices: Array[int] = [2, 3, 4, 5] ## Índices con tracción

# --- ESTADO EN TIEMPO REAL ---
var rpm_actual: float = 600.0
var marcha_actual: int = 1 # 0: R, 1: N, 2: 1ra...
var pedal_acelerador: float = 0.0
var pedal_freno: float = 0.0
var entrada_direccion: float = 0.0
var freno_mano_activo: bool = false
var estado_embrague: float = 1.0 # 0.0 = desacoplado, 1.0 = acoplado
var reloj_cambio: float = 0.0
var cambiando_marcha: bool = false
var marcha_objetivo: int = 1
var suspension_prev_compresion: Array[float] = []
var angulo_direccion_actual: float = 0.0
var angulo_rodado_ruedas: Array[float] = []

# Referencias opcionales de juego
var _iv_cache: Node = null

func _ready() -> void:
	# Descubrimiento automático de ruedas si no se especificaron manualmente
	if ruedas_raycast.is_empty():
		_auto_descubrir_ruedas()

	var num_ruedas = ruedas_raycast.size()
	suspension_prev_compresion.resize(num_ruedas)
	suspension_prev_compresion.fill(0.0)
	angulo_rodado_ruedas.resize(num_ruedas)
	angulo_rodado_ruedas.fill(0.0)

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Centro de gravedad realista elevado para simular balanceo dinámico de carga pesada
	center_of_mass = Vector3(0.0, 0.45, 0.0)

	for ray in ruedas_raycast:
		if is_instance_valid(ray):
			ray.add_exception(self)
			ray.target_position = Vector3(0.0, -(longitud_descanso + radio_rueda + 0.15), 0.0)

func _auto_descubrir_ruedas() -> void:
	ruedas_raycast.clear()
	for child in get_children():
		if child is RayCast3D:
			ruedas_raycast.append(child)
		else:
			for sub in child.get_children():
				if sub is RayCast3D:
					ruedas_raycast.append(sub)

	# Ordenar por posición Z (frontales primero: Z menor) y luego por X
	ruedas_raycast.sort_custom(func(a: RayCast3D, b: RayCast3D) -> bool:
		if absf(a.position.z - b.position.z) > 0.2:
			return a.position.z < b.position.z
		return a.position.x < b.position.x
	)

	# Si hay al menos 2 ruedas, las 2 primeras son directrices
	ruedas_directrices.clear()
	ruedas_motrices.clear()
	for i in range(ruedas_raycast.size()):
		if i < 2:
			ruedas_directrices.append(i)
		else:
			ruedas_motrices.append(i)

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

func _physics_process(delta: float) -> void:
	_leer_entradas()
	_procesar_transmision(delta)
	_actualizar_motor(delta)
	_procesar_suspension_y_traccion(delta)

func _leer_entradas() -> void:
	var iv = _get_iv()
	if iv and ("conduciendo" in iv) and iv.conduciendo:
		pedal_acelerador = float(iv.gas)
		pedal_freno = float(iv.freno)
		entrada_direccion = float(iv.direccion)
		freno_mano_activo = bool(iv.freno_mano)
		motor_encendido = bool(iv.motor_encendido)

		if iv.freno_motor:
			modo_jake_brake = 3 # 100%
		else:
			modo_jake_brake = 0

		# Mapear modo de transmisión
		if "marcha_actual" in iv:
			match iv.marcha_actual:
				0: # PARQUEO
					freno_mano_activo = true
					if marcha_actual != 1:
						iniciar_cambio(1)
				1: # REVERSA
					if marcha_actual != 0:
						iniciar_cambio(0)
				2: # NEUTRO
					if marcha_actual != 1:
						iniciar_cambio(1)
				3: # DRIVE
					if marcha_actual <= 1 and not cambiando_marcha:
						iniciar_cambio(2) # 1ra
	else:
		# Fallback a controles estándar de teclado/gamepad
		pedal_acelerador = Input.get_action_strength("ui_up")
		pedal_freno = Input.get_action_strength("ui_down")
		entrada_direccion = Input.get_axis("ui_left", "ui_right")
		freno_mano_activo = Input.is_action_pressed("ui_select")

		if Input.is_action_just_pressed("ui_page_up") and marcha_actual < relaciones_caja.size() - 1:
			iniciar_cambio(marcha_actual + 1)
		elif Input.is_action_just_pressed("ui_page_down") and marcha_actual > 0:
			iniciar_cambio(marcha_actual - 1)

	# Suavizado de dirección
	var angulo_obj = -entrada_direccion * angulo_max_direccion
	angulo_direccion_actual = move_toward(angulo_direccion_actual, angulo_obj, 3.5 * get_physics_process_delta_time())

# --- FÓRMULA DE CURVA DE TORQUE DIÉSEL (RoR Spline Approximation) ---
func _calcular_factor_torque_diesel(rpm: float) -> float:
	if rpm < rpm_stall:
		return 0.1
	elif rpm < rpm_idle:
		return lerpf(0.3, 0.75, (rpm - rpm_stall) / maxf(rpm_idle - rpm_stall, 1.0))
	elif rpm <= 1800.0:
		# Meseta de torque máximo diésel entre 1100 y 1800 RPM
		return 1.0
	elif rpm <= rpm_max:
		# Caída de torque suave post-meseta
		return lerpf(1.0, 0.70, (rpm - 1800.0) / maxf(rpm_max - 1800.0, 1.0))
	else:
		# Corte por inyección
		return clampf(lerpf(0.70, 0.0, (rpm - rpm_max) / 250.0), 0.0, 1.0)

# --- LOGICA DEL MOTOR Y JAKE BRAKE ---
func _actualizar_motor(delta: float) -> void:
	if not motor_encendido:
		rpm_actual = move_toward(rpm_actual, 0.0, delta * 800.0)
		return

	var gas = pedal_acelerador if not freno_mano_activo else 0.0
	var torque_combustion: float = torque_max_nm * _calcular_factor_torque_diesel(rpm_actual) * gas
	
	# Freno motor por fricción pasiva interna (20% en RoR)
	var torque_friccion_interna: float = (torque_max_nm * 0.20) * (rpm_actual / rpm_max) * (1.0 - gas)
	
	# Freno de compresión (Jake Brake) activo cuando no se acelera
	var factor_jake: float = float(modo_jake_brake) / 3.0
	var torque_jake: float = (torque_jake_max * factor_jake) * (rpm_actual / rpm_max) * (1.0 - gas)
	
	var torque_neto_motor: float = torque_combustion - torque_friccion_interna - torque_jake
	
	# En marcha neutral o desacoplado, la inercia del volante determina directamente las RPM
	if marcha_actual == 1 or estado_embrague < 0.2 or freno_mano_activo:
		var delta_rpm: float = (torque_neto_motor / inercia_volante) * delta * 9.54929 # Rad/s a RPM
		rpm_actual = clampf(rpm_actual + delta_rpm, rpm_idle, rpm_max + 200.0)
	else:
		# En marcha engranada, las RPM se sincronizan con las ruedas a través de la transmisión
		var ratio_caja: float = relaciones_caja[marcha_actual] * relacion_diferencial
		var vel_ms = absf(-global_transform.basis.orthonormalized().inverse().z.dot(linear_velocity))
		var rpm_transmision = (vel_ms / maxf(radio_rueda, 0.1)) * absf(ratio_caja) * 9.54929
		var rpm_obj = clampf(maxf(rpm_idle, rpm_transmision) + (gas * 140.0), rpm_idle, rpm_max)
		rpm_actual = lerpf(rpm_actual, rpm_obj, clampf(delta * 12.0, 0.0, 1.0))

# --- CAJA DE CAMBIOS Y EMBRAGUE ANALÍTICO ---
func iniciar_cambio(nueva_marcha: int) -> void:
	if cambiando_marcha or nueva_marcha == marcha_actual:
		return
	if nueva_marcha < 0 or nueva_marcha >= relaciones_caja.size():
		return
	cambiando_marcha = true
	marcha_objetivo = nueva_marcha
	reloj_cambio = 0.0

func _procesar_transmision(delta: float) -> void:
	# Transmisión automática simple en modo Drive
	if transmision_automatica and not cambiando_marcha and marcha_actual >= 2:
		var vel_kmh = linear_velocity.length() * 3.6
		if pedal_acelerador > 0.1 and rpm_actual > 2050.0 and marcha_actual < relaciones_caja.size() - 1:
			iniciar_cambio(marcha_actual + 1)
		elif rpm_actual < 1050.0 and marcha_actual > 2 and vel_kmh < 90.0:
			iniciar_cambio(marcha_actual - 1)

	if not cambiando_marcha:
		estado_embrague = 1.0
		return
		
	reloj_cambio += delta
	var mitad_tiempo: float = tiempo_cambio * 0.5
	
	if reloj_cambio < mitad_tiempo:
		# Desacople cuadrático (Pérdida de inercia)
		var t_norm: float = reloj_cambio / mitad_tiempo
		estado_embrague = pow(1.0 - t_norm, 2.0)
	else:
		# Engranado y re-acople progresivo
		marcha_actual = marcha_objetivo
		var t_norm: float = (reloj_cambio - mitad_tiempo) / mitad_tiempo
		estado_embrague = sqrt(clampf(t_norm, 0.0, 1.0))
		
	if reloj_cambio >= tiempo_cambio:
		cambiando_marcha = false
		estado_embrague = 1.0

# --- SUSPENSIÓN ASIMÉTRICA + TRANSFERENCIA DE PESO ---
func _procesar_suspension_y_traccion(delta: float) -> void:
	var num_ruedas: int = ruedas_raycast.size()
	if num_ruedas == 0:
		return

	var ratio_caja: float = relaciones_caja[marcha_actual] * relacion_diferencial
	var torque_eje_motriz: float = 0.0
	
	if absf(ratio_caja) > 0.01 and estado_embrague > 0.05 and motor_encendido and not freno_mano_activo:
		torque_eje_motriz = (torque_max_nm * _calcular_factor_torque_diesel(rpm_actual) * pedal_acelerador * ratio_caja * estado_embrague)

	# Freno motor y Jake Brake transferidos al eje motriz
	if modo_jake_brake > 0 and pedal_acelerador < 0.05 and absf(ratio_caja) > 0.01:
		var factor_jake: float = float(modo_jake_brake) / 3.0
		var torque_retardo = (torque_jake_max * factor_jake) * (rpm_actual / rpm_max) * absf(ratio_caja)
		torque_eje_motriz -= signf(ratio_caja) * torque_retardo

	var num_motrices = max(1, ruedas_motrices.size())

	for i in range(num_ruedas):
		var ray: RayCast3D = ruedas_raycast[i]
		if not is_instance_valid(ray):
			continue

		var es_directriz = ruedas_directrices.has(i)
		var es_motriz = ruedas_motrices.has(i)

		# Orientación de rueda (con ángulo de dirección si es directriz)
		var ray_basis = ray.global_transform.basis.orthonormalized()
		var dir_adelante = -ray_basis.z
		var dir_lateral = ray_basis.x
		var dir_up = ray_basis.y

		if es_directriz and absf(angulo_direccion_actual) > 0.001:
			dir_adelante = dir_adelante.rotated(dir_up, angulo_direccion_actual).normalized()
			dir_lateral = dir_lateral.rotated(dir_up, angulo_direccion_actual).normalized()

		if not ray.is_colliding():
			suspension_prev_compresion[i] = 0.0
			_actualizar_rueda_visual(ray, -longitud_descanso, es_directriz, i, delta)
			continue

		var punto_colision: Vector3 = ray.get_collision_point()
		var normal_colision: Vector3 = ray.get_collision_normal()
		var distancia: float = ray.global_position.distance_to(punto_colision)
		
		# 1. Compresión y velocidad de vástago
		var compresion: float = clampf((longitud_descanso + radio_rueda) - distancia, 0.0, longitud_descanso)
		var v_suspension: float = (compresion - suspension_prev_compresion[i]) / delta
		suspension_prev_compresion[i] = compresion
		
		# 2. Amortiguación Asimétrica de RoR (Rebound vs Bump)
		var k_actual: float = rigidez_compresion if v_suspension >= 0.0 else rigidez_rebote
		var d_actual: float = amortiguacion_compresion if v_suspension >= 0.0 else amortiguacion_rebote
		
		# Progresión cuadrática en topes de suspensión
		var factor_progresivo: float = pow(compresion / maxf(longitud_descanso, 0.05), 2.0)
		k_actual *= (1.0 + 1.2 * factor_progresivo)
		
		var fuerza_muelle: float = (compresion * k_actual) + (v_suspension * d_actual)
		
		# 3. Barra Estabilizadora Analítica (Anti-Roll Bar)
		# Emparejamos ruedas izquierda y derecha (ej. 0 con 1, 2 con 3, etc.)
		var idx_opuesta: int = i + 1 if (i % 2 == 0) else i - 1
		if idx_opuesta < num_ruedas and idx_opuesta >= 0:
			var dif_compresion: float = compresion - suspension_prev_compresion[idx_opuesta]
			fuerza_muelle += dif_compresion * rigidez_barra_estabilizadora

		var f_normal = maxf(fuerza_muelle, 0.0)
		# Aplicar fuerza vertical de soporte
		apply_force(normal_colision * f_normal, punto_colision - global_position)
		
		# 4. Tracción y Frenado en Ruedas
		var velocidad_contacto: Vector3 = _obtener_velocidad_punto(punto_colision)
		var vel_longitudinal: float = velocidad_contacto.dot(dir_adelante)
		var vel_lateral: float = velocidad_contacto.dot(dir_lateral)
		
		# Fricción lateral analítica estricta (Pacejka simplificada para camión pesado)
		var f_lat_mag = vel_lateral * rigidez_lateral
		var limite_lat = f_normal * 1.35
		f_lat_mag = clampf(f_lat_mag, -limite_lat, limite_lat)
		var fuerza_lateral: Vector3 = -dir_lateral * f_lat_mag
		
		# Fuerza longitudinal (Tracción si es rueda motriz, frenado de servicio y estacionamiento)
		var fuerza_traccion_n: float = 0.0
		if es_motriz:
			fuerza_traccion_n = (torque_eje_motriz / num_motrices) / maxf(radio_rueda, 0.1)
			
		# Frenos de servicio neumáticos
		var fuerza_frenado: float = pedal_freno * (fuerza_frenos_servicio / num_ruedas)
		if freno_mano_activo:
			fuerza_frenado += (fuerza_freno_mano / num_ruedas)

		if absf(vel_longitudinal) > 0.05:
			fuerza_traccion_n -= signf(vel_longitudinal) * fuerza_frenado
		elif fuerza_frenado > 0.0:
			# Estabilización en reposo para pendientes
			fuerza_traccion_n -= vel_longitudinal * 12000.0

		var limite_long = f_normal * 1.45
		fuerza_traccion_n = clampf(fuerza_traccion_n, -limite_long, limite_long)

		apply_force((dir_adelante * fuerza_traccion_n) + fuerza_lateral, punto_colision - global_position)

		# Actualizar visual de la rueda
		var target_y = -distancia + radio_rueda
		_actualizar_rueda_visual(ray, target_y, es_directriz, i, delta)

func _obtener_velocidad_punto(punto: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(punto - global_position)

func _actualizar_rueda_visual(ray: RayCast3D, target_y: float, es_directriz: bool, idx: int, delta: float) -> void:
	if ray.get_child_count() == 0:
		return
	var visual: Node3D = ray.get_child(0) as Node3D
	if not visual:
		return

	# Recorrido de suspensión suave
	visual.position.y = lerpf(visual.position.y, clampf(target_y, -longitud_descanso, 0.0), clampf(delta * 15.0, 0.0, 1.0))

	# Dirección
	var q_dir = Quaternion(Vector3.UP, angulo_direccion_actual) if es_directriz else Quaternion.IDENTITY

	# Rodado visual
	var vel_ms = -global_transform.basis.orthonormalized().inverse().z.dot(linear_velocity)
	angulo_rodado_ruedas[idx] += (vel_ms / maxf(radio_rueda, 0.1)) * delta
	angulo_rodado_ruedas[idx] = wrapf(angulo_rodado_ruedas[idx], -PI, PI)
	var q_rot = Quaternion(Vector3.RIGHT, angulo_rodado_ruedas[idx])

	visual.quaternion = q_dir * q_rot
