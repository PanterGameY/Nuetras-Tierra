extends RigidBody3D
class_name VehiculoTraficoIA

## ══════════════════════════════════════════════════════════════════════════════
##  VehiculoTraficoIA.gd
##  Vehículo cinemático para tráfico vehicular IA tipo simulador de transporte.
##  Soporta doble modo de navegación:
##    1. Modo Carril Directo (TrafficNetworkManager3D / TrafficLane3D en mapa.tscn)
##    2. Modo PathFollow3D (GestorTrafico en pistas de prueba)
##  Compatible con RigidBody3D (congelado en modo cinemático), sensores RayCast3D,
##  controlador de suspensión Ruedas_IA y módulo de luces Luces_IA.
##  Incluye:
##    - Contacto de suelo dinámico (_sensor_suelo) para ruedas a ras de asfalto.
##    - Maniobras autónomas de cambio de carril con direccionales previas.
##    - Desaceleración progresiva cuadrática realista y luces de freno.
##    - Inclinación y cabeceo analíticos de suspensión optimizados para alto rendimiento.
## ══════════════════════════════════════════════════════════════════════════════

enum EstadoCarril {
	CARRIL_BASE,
	PREPARANDO_CAMBIO,
	CAMBIANDO,
	ADELANTANDO,
	RETORNANDO
}

const HOLGURA_ABSOLUTA := 2.5   # m, distancia física mínima absoluta entre parachoques tipo ATS/ETS2

@export_group("Velocidad y Desempeño")
@export var velocidad_crucero: float = 14.0      # m/s (~50 km/h)
@export var aceleracion: float = 3.5             # m/s² al acelerar
@export var frenado: float = 8.0                 # m/s² al frenar
@export var radio_rueda: float = 0.52            # metros, para la rodadura visual
@export var longitud_vehiculo: float = 7.5       # metros de parachoques a parachoques
@export var distancia_ejes: float = 4.2          # metros entre eje delantero y trasero (geometría de giro ATS/ETS2)
@export var offset_y: float = 0.95               # Elevación base sobre el asfalto

@export_group("Cambio de Carril y Dinámicas")
@export var permitir_cambio_carril: bool = true
@export var ancho_carril: float = 3.5                # metros de separación entre carriles
@export var duracion_direccional_previa: float = 1.3  # segundos de direccional antes de maniobrar
@export var velocidad_cambio_lateral: float = 1.2     # m/s velocidad de transición lateral

@export_group("Sensores y Seguridad")
@export var distancia_raycast_largo: float = 32.0   # detección temprana (desaceleración suave)
@export var distancia_raycast_corto: float = 6.0    # freno de seguridad preventivo
@export var distancia_minima: float = 6.0           # separación en detención para camiones (estilo ATS)
@export_range(0.3, 1.0) var factor_frenado_seguro: float = 0.7

const PALETA_COLORES_DEFAULT: Array[Color] = [
	Color(0.85, 0.12, 0.12), # Rojo pasión / tractomula
	Color(0.12, 0.32, 0.85), # Azul rey metálico
	Color(0.95, 0.95, 0.97), # Blanco glaciar
	Color(0.96, 0.75, 0.10), # Amarillo comercial
	Color(0.08, 0.45, 0.18), # Verde esmeralda
	Color(0.90, 0.40, 0.08), # Naranja de carga
	Color(0.50, 0.08, 0.12), # Vinotinto
	Color(0.25, 0.26, 0.28), # Gris grafito / carbón
	Color(0.72, 0.74, 0.76), # Plata metálico
	Color(0.08, 0.14, 0.35), # Azul noche
	Color(0.06, 0.52, 0.56), # Turquesa
	Color(0.68, 0.55, 0.40), # Arena / Beige
	Color(0.10, 0.10, 0.11), # Negro perla
]

@export_group("Apariencia y Depuración")
@export var altura_etiqueta: float = 3.2
@export var colores_carroceria: PackedColorArray = PackedColorArray()
@export var materiales_carroceria: Array[Material] = []

# ── Variables leídas por Luces_IA y Ruedas_IA ─────────────────────────────────
var luces_direccional_izq: bool = false
var luces_direccional_der: bool = false
var luces_stop: bool = false
var angulo_ruedas: float = 0.0

# ── Estado de navegación y LOD ───────────────────────────────────────────────
var path_follow: PathFollow3D = null
var current_lane: TrafficLane3D = null
var current_distance: float = 0.0
var network_manager = null
var velocidad_actual: float = 0.0
var sentido: int = 1                     # +1 con la curva, -1 contra la curva
var frenar_por_semaforo: bool = false
var multiplicador_velocidad: float = 1.0
var distancia_lider: float = INF
var mostrar_velocidad: bool = false
var distancia_al_jugador: float = 20.0
var _lod_level: int = 0                  # 0: <35m (alto), 1: 35-85m (medio), 2: >85m (bajo)

# ── Estado de colisión y choque ───────────────────────────────────────────────
var _en_choque: bool = false
var _tiempo_choque: float = 0.0
var _ultimo_frame_ray: int = -1
var _distancia_ray_cache: float = INF

# ── Estado interno de cambio de carril ────────────────────────────────────────
var _estado_carril: EstadoCarril = EstadoCarril.CARRIL_BASE
var _desfase_lateral_actual: float = 0.0
var _desfase_lateral_objetivo: float = 0.0
var _desfase_inicio_cambio: float = 0.0
var _duracion_cambio_carril: float = 2.4
var _yaw_cambio_carril: float = 0.0
var _carril_destino_cambio: Path3D = null
var _tiempo_en_estado_carril: float = 0.0
var _cooldown_cambio_carril: float = 2.5

# ── Estado de cruce continuo entre Path3D separados ───────────────────────────
var _cruzando_interseccion: bool = false
var _cruce_destino_pos: Vector3 = Vector3.ZERO
var _cruce_camino_destino: Path3D = null
var _cruce_offset_destino: float = 0.0

# ── Luces y parpadeo universal ────────────────────────────────────────────────
var _luces_universales: Node3D = null
var _luces_stop_mesh: Array[MeshInstance3D] = []
var _luces_izq_mesh: Array[MeshInstance3D] = []
var _luces_der_mesh: Array[MeshInstance3D] = []
var _timer_parpadeo: float = 0.0
var _estado_parpadeo: bool = false
var _cruce_dir_destino: Vector3 = Vector3.FORWARD
var _cruce_dist_inicial: float = 1.0
var _tiempo_en_cruce: float = 0.0
var _timer_direccional_giro: float = 0.0

# ── Sensores y ruedas internos ────────────────────────────────────────────────
var _sensor_suelo: RayCast3D = null
var _sensores_frontales: Array[RayCast3D] = []
var _retroceso_ray: float = 0.0
var _ultimo_col_ray: Object = null
var _ruedas_visuales: Array[Node3D] = []
var _tiene_ruedas_ia: bool = false
var _nodo_visual_fallback: Node3D = null
var _cabeceo_fallback: float = 0.0
var _balanceo_fallback: float = 0.0
var _vel_anterior_fallback: float = 0.0
var _etiqueta: Label3D = null
var _tiempo_etiqueta: float = 0.0

# ── Sistema de Claxon e Impaciencia en Trancón ────────────────────────────────
static var _stream_claxon: AudioStream = null
var _audio_claxon: AudioStreamPlayer3D = null
var _tiempo_detenido: float = 0.0
var _cooldown_reintento_arranque: float = 0.0
var _timer_desesperacion_claxon: float = 0.0
var _toques_pendientes: int = 0
var _timer_entre_toques: float = 0.0


func _ready() -> void:
	# Asegurar comportamiento físico sólido que interactúe físicamente con el jugador y otros vehículos
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = 4   # Capa 3 (Tráfico IA, bit 4). Excluye Capa 1 (Suelo/Mundo) para evitar que los sensores de suelo detecten vehículos como asfalto
	collision_mask = 7    # Detecta jugador (1), vehículos (2), tráfico (4)
	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_impacto_colision):
		body_entered.connect(_on_impacto_colision)

	add_to_group("trafico")
	add_to_group("Vehiculo")

	_setup_sensores()
	_setup_ruedas()
	_setup_luces_universales()
	_setup_audio_claxon()
	aplicar_apariencia_aleatoria()

	# Cooldown inicial aleatorio para que los vehículos no cambien todos al mismo tiempo
	_cooldown_cambio_carril = randf_range(8.0, 25.0)

	if mostrar_velocidad:
		_crear_etiqueta()


func aplicar_apariencia_aleatoria() -> void:
	# 1. Si hay materiales personalizados exportados en la escena/inspector, aplicar uno al azar
	if materiales_carroceria.size() > 0:
		var mat_elegido: Material = materiales_carroceria.pick_random()
		if mat_elegido != null:
			_asignar_material_carroceria(mat_elegido)
			return

	# 2. Elegir color de la paleta exportada o de la paleta por defecto
	var color_elegido: Color
	if colores_carroceria.size() > 0:
		color_elegido = colores_carroceria[randi() % colores_carroceria.size()]
	else:
		color_elegido = PALETA_COLORES_DEFAULT.pick_random()

	_asignar_color_carroceria(color_elegido)


func _asignar_material_carroceria(mat: Material) -> void:
	var mesh_carroceria := _obtener_mesh_carroceria()
	if mesh_carroceria != null:
		mesh_carroceria.material_override = mat


func _asignar_color_carroceria(col: Color) -> void:
	var mesh_carroceria := _obtener_mesh_carroceria()
	if mesh_carroceria == null:
		return

	# Si ya tiene un material_override (como Cascadia y T680 con Carroceria_IA)
	if mesh_carroceria.material_override != null and mesh_carroceria.material_override is StandardMaterial3D:
		var mat_duplicado: StandardMaterial3D = (mesh_carroceria.material_override as StandardMaterial3D).duplicate()
		mat_duplicado.albedo_color = col
		mesh_carroceria.material_override = mat_duplicado
	else:
		# Para Transit y Furgon1: crear StandardMaterial3D preservando la textura albedo original
		var orig_mat = mesh_carroceria.mesh.surface_get_material(0) if mesh_carroceria.mesh else null
		var nuevo_mat := StandardMaterial3D.new()
		if orig_mat and orig_mat is StandardMaterial3D and orig_mat.albedo_texture != null:
			nuevo_mat.albedo_texture = orig_mat.albedo_texture
		nuevo_mat.albedo_color = col
		nuevo_mat.metallic = 0.35
		nuevo_mat.roughness = 0.30
		nuevo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_carroceria.material_override = nuevo_mat


func _obtener_mesh_carroceria() -> MeshInstance3D:
	for child in find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var lname := mi.name.to_lower()
		var p_lname := mi.get_parent().name.to_lower() if mi.get_parent() else ""

		# Descartar ruedas, cristales, luces, espejos y accesorios
		if "wheel" in lname or "rueda" in lname or "glass" in lname or "cristal" in lname or "windshield" in lname:
			continue
		if "light" in lname or "luz" in lname or "faruri" in lname or "led" in lname or "stop" in lname or "dir_" in lname:
			continue
		if "mirror" in lname or "chrome" in lname or "steer" in lname or "interior" in lname or lname.begins_with("int1"):
			continue

		# Identificar malla principal de chapa exterior
		if "cascadia_b" in lname or "paint" in lname or "paint" in p_lname:
			return mi
		elif "ford_transit_connect_2011_0" in lname and not "_001" in lname and not "_002" in lname and not "_003" in lname and not "_004" in lname and not "_005" in lname:
			return mi
		elif "maxity" in lname:
			return mi
		elif "carroceria" in lname or "body" in lname:
			return mi

	return null


func _setup_sensores() -> void:
	_sensores_frontales.clear()

	# 1. Desactivar raycasts legacy en contenedor "Sensores" para evitar lecturas laterales corruptas
	var nodo_sensores := get_node_or_null("Sensores")
	if nodo_sensores != null:
		for hijo in nodo_sensores.get_children():
			if hijo is RayCast3D:
				(hijo as RayCast3D).enabled = false

	# 2. Desactivar RayCastLargo viejo si existe
	var rc_largo := get_node_or_null("RayCastLargo") as RayCast3D
	if rc_largo != null:
		rc_largo.enabled = false

	# 3. Sensores frontales cubriendo todo el ancho y desde el cuarto delantero del chasis para eliminar puntos ciegos pegados al parachoques
	_retroceso_ray = minf(longitud_vehiculo * 0.25, 1.8)
	var z_inicio: float = -longitud_vehiculo * 0.50 + _retroceso_ray
	var alcance_ray: float = distancia_raycast_largo + _retroceso_ray
	var config_sensores: Array[Dictionary] = [
		{"name": "RayFrontalCentro", "pos": Vector3(0.0, 0.70, z_inicio), "tgt": Vector3(0.0, 0.0, -alcance_ray)},
		{"name": "RayFrontalAlto", "pos": Vector3(0.0, 1.65, z_inicio), "tgt": Vector3(0.0, 0.0, -alcance_ray)},
		{"name": "RayFrontalMedIzq", "pos": Vector3(-0.48, 0.70, z_inicio), "tgt": Vector3(0.0, 0.0, -alcance_ray)},
		{"name": "RayFrontalMedDer", "pos": Vector3(0.48, 0.70, z_inicio), "tgt": Vector3(0.0, 0.0, -alcance_ray)},
		{"name": "RayFrontalAltoIzq", "pos": Vector3(-0.88, 1.60, z_inicio), "tgt": Vector3(-0.08, 0.0, -alcance_ray)},
		{"name": "RayFrontalAltoDer", "pos": Vector3(0.88, 1.60, z_inicio), "tgt": Vector3(0.08, 0.0, -alcance_ray)},
		{"name": "RayFrontalBajo", "pos": Vector3(0.0, 0.50, z_inicio), "tgt": Vector3(0.0, 0.0, -alcance_ray)},
		{"name": "RayFrontalIzq", "pos": Vector3(-0.98, 0.70, z_inicio), "tgt": Vector3(-0.10, 0.0, -alcance_ray)},
		{"name": "RayFrontalDer", "pos": Vector3(0.98, 0.70, z_inicio), "tgt": Vector3(0.10, 0.0, -alcance_ray)},
	]

	for cfg in config_sensores:
		var ray: RayCast3D = get_node_or_null(cfg["name"]) as RayCast3D
		if ray == null:
			ray = RayCast3D.new()
			ray.name = cfg["name"]
			add_child(ray)

		ray.position = cfg["pos"]
		ray.target_position = cfg["tgt"]
		ray.collision_mask = 7  # Capas 1 (Jugador/Terreno), 2 (Vehículos), 3 (Tráfico IA)
		ray.hit_from_inside = true
		ray.enabled = false
		ray.exclude_parent = true
		ray.add_exception(self)
		_sensores_frontales.append(ray)

	# 4. Sensor vertical de contacto con asfalto (garantiza ruedas a ras de carretera)
	_sensor_suelo = get_node_or_null("RaySensorSuelo") as RayCast3D
	if _sensor_suelo == null:
		_sensor_suelo = RayCast3D.new()
		_sensor_suelo.name = "RaySensorSuelo"
		add_child(_sensor_suelo)

	_sensor_suelo.position = Vector3(0.0, 1.8, 0.0)
	_sensor_suelo.target_position = Vector3(0.0, -12.0, 0.0)
	_sensor_suelo.collision_mask = 1  # Capa 1: Solo suelo y carretera estática
	_sensor_suelo.enabled = false
	_sensor_suelo.exclude_parent = true
	_sensor_suelo.add_exception(self)


func _setup_ruedas() -> void:
	_ruedas_visuales.clear()

	# Detectar si existe un nodo con script Ruedas_IA
	for hijo in get_children():
		if hijo.get_script() != null and "Ruedas_IA" in str(hijo.get_script().resource_path):
			_tiene_ruedas_ia = true
			break

	if not _tiene_ruedas_ia:
		# Buscar contenedores de ruedas estándar
		for nombre in ["Wheels", "Ruedas", "Wheels_24", "ruedas"]:
			var cont = get_node_or_null(nombre)
			if cont != null:
				for r in cont.get_children():
					if r is Node3D:
						_ruedas_visuales.append(r)
				break

		# Asignar nodo visual de carrocería para el cabeceo/balanceo fallback
		_nodo_visual_fallback = _obtener_mesh_carroceria()


func _setup_luces_universales() -> void:
	# Si ya tiene Luces_IA (ej. Cascadia o T680), omitir luces procedurales
	for child in find_children("*", "Node3D", true, false):
		if child.get_script() != null and "Luces_IA" in str(child.get_script().resource_path):
			return

	if _luces_universales != null and is_instance_valid(_luces_universales):
		return

	_luces_universales = Node3D.new()
	_luces_universales.name = "LucesUniversalesIA"
	add_child(_luces_universales)

	var mat_stop := StandardMaterial3D.new()
	mat_stop.albedo_color = Color(1.0, 0.05, 0.05)
	mat_stop.emission_enabled = true
	mat_stop.emission = Color(1.0, 0.05, 0.05)
	mat_stop.emission_energy_multiplier = 4.0
	mat_stop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mat_dir := StandardMaterial3D.new()
	mat_dir.albedo_color = Color(1.0, 0.55, 0.0)
	mat_dir.emission_enabled = true
	mat_dir.emission = Color(1.0, 0.55, 0.0)
	mat_dir.emission_energy_multiplier = 4.5
	mat_dir.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.20)

	var z_trasero := longitud_vehiculo * 0.48
	var y_luz := 0.85
	var x_offset := 0.85

	# 1. Luces de Stop traseras
	for lado in [-1.0, 1.0]:
		var m := MeshInstance3D.new()
		m.mesh = quad
		m.material_override = mat_stop
		m.position = Vector3(lado * (x_offset - 0.2), y_luz, z_trasero)
		m.visible = false
		_luces_universales.add_child(m)
		_luces_stop_mesh.append(m)

	# 2. Direccionales traseras
	for lado in [-1.0, 1.0]:
		var m := MeshInstance3D.new()
		m.mesh = quad
		m.material_override = mat_dir
		m.position = Vector3(lado * x_offset, y_luz, z_trasero)
		m.visible = false
		_luces_universales.add_child(m)
		if lado < 0.0:
			_luces_izq_mesh.append(m)
		else:
			_luces_der_mesh.append(m)


func _setup_audio_claxon() -> void:
	if _stream_claxon == null:
		var ruta := "res://recursos/sonidos_vehiculo/motor/automovil/claxon 1.mp3"
		if ResourceLoader.exists(ruta):
			_stream_claxon = load(ruta)

	if _stream_claxon != null and _audio_claxon == null:
		_audio_claxon = AudioStreamPlayer3D.new()
		_audio_claxon.name = "AudioClaxon"
		_audio_claxon.stream = _stream_claxon
		_audio_claxon.unit_size = 14.0
		_audio_claxon.max_distance = 65.0
		_audio_claxon.max_polyphony = 2
		_audio_claxon.volume_db = -1.5
		# Tono ligeramente variado por vehículo para realismo acústico
		_audio_claxon.pitch_scale = randf_range(0.93, 1.14)
		add_child(_audio_claxon)

	_timer_desesperacion_claxon = randf_range(2.0, 5.0)


func _procesar_claxon_desesperado(delta: float) -> void:
	# Optimización LOD: solo vehículos cercanos o visibles gestionan audio de bocina
	if _lod_level >= 2 or distancia_al_jugador > 65.0:
		return

	if _audio_claxon == null:
		_setup_audio_claxon()
		if _audio_claxon == null:
			return

	# Si el vehículo está detenido (< 0.4 m/s) por trancón, líder o choque:
	if velocidad_actual < 0.4:
		# Ráfagas rápidas de pitos ("¡Pi-Pi!")
		if _toques_pendientes > 0:
			_timer_entre_toques -= delta
			if _timer_entre_toques <= 0.0:
				_tocar_claxon()
				_toques_pendientes -= 1
				_timer_entre_toques = randf_range(0.18, 0.32)
			return

		# A partir de 1.8 segundos de detención, el conductor se impacienta
		if _tiempo_detenido >= 1.8:
			_timer_desesperacion_claxon -= delta
			if _timer_desesperacion_claxon <= 0.0:
				_tocar_claxon()
				# 60% de probabilidad de pito doble o triple desesperado
				if randf() < 0.60:
					_toques_pendientes = randi_range(1, 2)
					_timer_entre_toques = randf_range(0.20, 0.35)

				# Impaciencia progresiva: cuanto más tiempo parado, pita más seguido
				var factor_impaciencia := clampf(1.0 - (_tiempo_detenido / 18.0), 0.35, 1.0)
				_timer_desesperacion_claxon = randf_range(2.2, 5.2) * factor_impaciencia
	else:
		# Al reiniciar la marcha, se reinician los contadores de claxon
		_toques_pendientes = 0
		_timer_desesperacion_claxon = randf_range(3.0, 6.0)


func _tocar_claxon() -> void:
	if _audio_claxon != null and is_instance_valid(_audio_claxon) and _audio_claxon.is_inside_tree():
		_audio_claxon.pitch_scale = randf_range(0.94, 1.12)
		_audio_claxon.play()


## Configuración para TrafficNetworkManager3D (utilizado en mapa.tscn)
func setup_vehicle(manager: TrafficNetworkManager3D, start_lane: TrafficLane3D) -> void:
	network_manager = manager
	current_lane = start_lane
	path_follow = null
	current_distance = 0.0
	velocidad_actual = velocidad_crucero * multiplicador_velocidad
	distancia_lider = INF
	frenar_por_semaforo = false
	luces_stop = false
	luces_direccional_izq = false
	luces_direccional_der = false
	_desfase_lateral_actual = 0.0
	_desfase_lateral_objetivo = 0.0
	_yaw_cambio_carril = 0.0
	_carril_destino_cambio = null
	_estado_carril = EstadoCarril.CARRIL_BASE
	visible = true
	aplicar_apariencia_aleatoria()

	if current_lane != null and current_lane.curve != null:
		var lane_len := current_lane.get_total_length()
		if lane_len > 15.0:
			current_distance = randf_range(0.0, minf(lane_len * 0.7, 40.0))
		_posicionar_en_carril(current_distance, 1.0)

	set_physics_process(true)


## Reinicio rápido para pools de tráfico
func reset_for_pool(manager: TrafficNetworkManager3D, start_lane: TrafficLane3D, start_distance: float = 0.0) -> void:
	network_manager = manager
	current_lane = start_lane
	path_follow = null
	current_distance = start_distance
	velocidad_actual = velocidad_crucero * multiplicador_velocidad
	distancia_lider = INF
	frenar_por_semaforo = false
	luces_stop = false
	luces_direccional_izq = false
	luces_direccional_der = false
	_desfase_lateral_actual = 0.0
	_desfase_lateral_objetivo = 0.0
	_yaw_cambio_carril = 0.0
	_carril_destino_cambio = null
	_estado_carril = EstadoCarril.CARRIL_BASE
	_cooldown_cambio_carril = randf_range(12.0, 30.0)
	visible = true
	aplicar_apariencia_aleatoria()

	if current_lane != null and current_lane.curve != null:
		_posicionar_en_carril(current_distance, 1.0)

	set_physics_process(true)


## Activación desde el pool de GestorTrafico (PathFollow3D)
func activar(nuevo_path_follow: PathFollow3D, progreso_inicial: float, nuevo_sentido: int = 1, desfase_carril: float = 0.0) -> void:
	path_follow = nuevo_path_follow
	current_lane = null
	sentido = 1 if nuevo_sentido >= 0 else -1
	path_follow.progress = progreso_inicial
	_desfase_lateral_actual = desfase_carril
	_desfase_lateral_objetivo = desfase_carril
	path_follow.h_offset = 0.0
	position = Vector3(0.0, offset_y, 0.0)
	rotation = Vector3(0.0, 0.0 if sentido > 0 else PI, 0.0)
	velocidad_actual = velocidad_crucero * multiplicador_velocidad
	distancia_lider = INF
	frenar_por_semaforo = false
	luces_stop = false
	luces_direccional_izq = false
	luces_direccional_der = false
	_yaw_cambio_carril = 0.0
	_carril_destino_cambio = null
	_estado_carril = EstadoCarril.CARRIL_BASE
	_cruzando_interseccion = false
	_cruce_camino_destino = null
	_cooldown_cambio_carril = randf_range(1.5, 4.0)
	visible = true
	aplicar_apariencia_aleatoria()
	set_physics_process(true)
	_actualizar_contacto_suelo(1.0)


## Devolución limpia al pool
func desactivar() -> void:
	set_physics_process(false)
	_cruzando_interseccion = false
	_cruce_camino_destino = null
	visible = false
	velocidad_actual = 0.0
	distancia_lider = INF
	frenar_por_semaforo = false
	luces_stop = false
	luces_direccional_izq = false
	luces_direccional_der = false
	_desfase_lateral_actual = 0.0
	_desfase_lateral_objetivo = 0.0
	_yaw_cambio_carril = 0.0
	_carril_destino_cambio = null
	_estado_carril = EstadoCarril.CARRIL_BASE
	rotation.y = 0.0
	if path_follow != null:
		path_follow.h_offset = 0.0
	path_follow = null
	current_lane = null


func _es_jugador_o_camion_jugador(obj: Object) -> bool:
	if not is_instance_valid(obj) or not (obj is Node):
		return false
	var n := obj as Node
	return (n is CharacterBody3D) or n.is_in_group("jugador") or n.is_in_group("player") or n.is_in_group("remolque") or n.is_in_group("trailers") or (n.is_in_group("Vehiculo") and not (n is VehiculoTraficoIA))


func _on_impacto_colision(body: Node) -> void:
	if body == self or body is StaticBody3D or body is CSGShape3D or body is GridMap:
		return
	var es_jugador_o_vehiculo := _es_jugador_o_camion_jugador(body)
	# Entre vehículos IA a baja velocidad o cruzando intersección evitar bloqueos permanentes;
	# con el jugador o su vehículo frenar SIEMPRE para no atravesarlos
	if not es_jugador_o_vehiculo and (_cruzando_interseccion or velocidad_actual < 5.0):
		return
	if es_jugador_o_vehiculo or body is RigidBody3D or body.is_in_group("trafico"):
		_registrar_choque(body)


func _registrar_choque(body: Node) -> void:
	if _en_choque:
		return
	var vel_impacto := velocidad_actual
	_en_choque = true
	_tiempo_choque = 2.0 if (body is CharacterBody3D and vel_impacto < 2.5) else randf_range(3.5, 6.0)
	velocidad_actual = 0.0
	linear_velocity = Vector3.ZERO
	luces_stop = true
	luces_direccional_izq = true
	luces_direccional_der = true
	_cabeceo_fallback = deg_to_rad(-4.0)
	_tocar_claxon()

	# Sacudida visual de impacto si tiene carrocería fallback
	if is_instance_valid(_nodo_visual_fallback):
		_nodo_visual_fallback.rotation.x = deg_to_rad(-3.5)
		_nodo_visual_fallback.rotation.z = deg_to_rad(randf_range(-2.5, 2.5))

	# Si colisionamos con el jugador (CharacterBody3D):
	# Evitar que la física de depenetración lo catapulte a velocidades absurdas.
	# Le aplicamos un empujón suave y controlado realista de impacto.
	if body is CharacterBody3D and vel_impacto >= 2.5:
		var cb := body as CharacterBody3D
		var dir_push: Vector3 = (cb.global_position - global_position)
		dir_push.y = 0.0
		if dir_push.length_squared() < 0.01:
			dir_push = -global_transform.basis.z
		dir_push = dir_push.normalized()
		dir_push.y = 0.15 # ligero empuje hacia atrás y arriba
		dir_push = dir_push.normalized()
		cb.velocity = dir_push * 5.0 # Empuje realista (~18 km/h)

	# Si colisionamos con un vehículo dinámico del jugador (RigidBody3D):
	elif body is RigidBody3D and not (body as RigidBody3D).freeze:
		var rb := body as RigidBody3D
		var dir_push: Vector3 = (rb.global_position - global_position)
		dir_push.y = 0.0
		if dir_push.length_squared() < 0.01:
			dir_push = -global_transform.basis.z
		dir_push = dir_push.normalized()
		rb.linear_velocity = dir_push * minf(rb.linear_velocity.length() * 0.4 + 3.0, 7.0)
		rb.angular_velocity = Vector3(
			clampf(rb.angular_velocity.x, -2.0, 2.0),
			clampf(rb.angular_velocity.y, -2.0, 2.0),
			clampf(rb.angular_velocity.z, -2.0, 2.0)
		)


func obtener_progreso() -> float:
	if path_follow != null:
		return path_follow.progress
	return current_distance


func _physics_process(delta: float) -> void:
	if path_follow == null and current_lane == null:
		return

	# Actualizar nivel de LOD según proximidad al jugador
	if distancia_al_jugador < 35.0:
		_lod_level = 0
	elif distancia_al_jugador < 85.0:
		_lod_level = 1
	else:
		_lod_level = 2

	# 0. Si el vehículo está en estado de choque / accidente: detenerlo y encender intermitentes
	if _en_choque:
		velocidad_actual = 0.0
		luces_stop = true
		luces_direccional_izq = true
		luces_direccional_der = true
		_tiempo_choque -= delta
		if _tiempo_choque <= 0.0:
			var sensor_dist := _obtener_menor_distancia_sensores()
			if sensor_dist > 5.5 and distancia_lider > 6.0:
				_en_choque = false
				luces_stop = false
				luces_direccional_izq = false
				luces_direccional_der = false
				_cooldown_cambio_carril = randf_range(8.0, 16.0)
			else:
				_tiempo_choque = 1.8
		_actualizar_luces(delta)
		return

	# 1. Gestión de cambio de carril autónomo (restringido a carriles paralelos existentes)
	_procesar_cambio_carril(delta)

	# 2. Cálculo de velocidad objetivo y frenado progresivo
	var saliendo_al_carril := (_estado_carril == EstadoCarril.CAMBIANDO and not _bloqueado_directo_por_jugador())
	var en_carril_adelanto := (absf(_desfase_lateral_actual) > 1.7) or (saliendo_al_carril and _tiempo_en_estado_carril >= _duracion_cambio_carril * 0.45)
	var dist_lider_backup := distancia_lider
	if en_carril_adelanto:
		distancia_lider = INF

	var velocidad_objetivo := _calcular_velocidad_objetivo()
	var menor_ray := _obtener_menor_distancia_sensores()
	var dist_jug_directo := _obtener_distancia_jugador_directa()
	if saliendo_al_carril and menor_ray > 3.0 and dist_jug_directo > 4.5:
		var vel_maniobra := lerpf(5.5, velocidad_crucero * 1.12, clampf(_tiempo_en_estado_carril / maxf(_duracion_cambio_carril, 0.6), 0.0, 1.0))
		velocidad_objetivo = maxf(velocidad_objetivo, vel_maniobra)

	if en_carril_adelanto:
		distancia_lider = dist_lider_backup

	var espacio_frente := minf(distancia_lider, menor_ray)
	var dist_parada_efectiva := 2.9 if (saliendo_al_carril and dist_jug_directo > 4.5) else distancia_minima
	# Histéresis de arranque: si ya está detenido, esperar margen extra antes de reiniciar marcha
	var margen_rearranque := 0.75 if velocidad_actual < 0.1 else 0.0
	var debe_detenerse := (velocidad_objetivo <= 0.15 or espacio_frente <= dist_parada_efectiva + margen_rearranque)

	if debe_detenerse:
		# Frenado suave y firme: parada total sólo al quedar muy lento o pegado al obstáculo
		if velocidad_actual < 0.20 or espacio_frente <= HOLGURA_ABSOLUTA + 0.30:
			velocidad_actual = 0.0
		else:
			velocidad_actual = move_toward(velocidad_actual, 0.0, frenado * 1.8 * delta)
		luces_stop = true
	elif velocidad_objetivo > velocidad_actual:
		var factor_arranque := lerpf(0.35, 0.90, clampf(velocidad_actual / 4.5, 0.0, 1.0))
		var tasa_acel := aceleracion * factor_arranque
		velocidad_actual = move_toward(velocidad_actual, velocidad_objetivo, tasa_acel * delta)
		luces_stop = false
	else:
		# Desaceleración progresiva suave (sin frenazos bruscos al entrar a curvas)
		var tasa_frenado := frenado if espacio_frente < 12.0 else 1.4
		velocidad_actual = move_toward(velocidad_actual, velocidad_objetivo, tasa_frenado * delta)
		luces_stop = (velocidad_actual > 0.5 and (velocidad_actual - velocidad_objetivo > 4.0 or espacio_frente < 12.0))

	# Freno absoluto de emergencia y corte total de avance (anti-superposición y anti-deslizamiento)
	var avance: float = 0.0
	if velocidad_actual > 0.0:
		avance = velocidad_actual * delta
		if espacio_frente < INF and delta > 0.0:
			var libre := maxf(espacio_frente - HOLGURA_ABSOLUTA, 0.0)
			# Si queda menos de 5cm de holgura, DETENCIÓN TOTAL: avance CERO
			if libre <= 0.05 or espacio_frente <= HOLGURA_ABSOLUTA:
				avance = 0.0
				velocidad_actual = 0.0
				luces_stop = true
			elif avance > libre:
				avance = libre
				velocidad_actual = avance / delta
				luces_stop = true

	# 2.5 Conteo global de detención (independiente de LOD/audio) y bocina de impaciencia
	if velocidad_actual < 0.35 and not frenar_por_semaforo and not _en_choque:
		_tiempo_detenido += delta
		_cooldown_reintento_arranque = maxf(_cooldown_reintento_arranque - delta, 0.0)
	elif velocidad_actual >= 1.5:
		_tiempo_detenido = maxf(_tiempo_detenido - delta * 2.5, 0.0)
		_cooldown_reintento_arranque = 0.0

	_procesar_claxon_desesperado(delta)

	# 2.6 Sistema Anti-Stuck tipo ATS/ETS2: nunca reciclar si espera al jugador o está visible cerca (< 75 m)
	if velocidad_actual < 0.35 and not frenar_por_semaforo and not _en_choque:
		var bloqueado_por_jugador := _es_jugador_o_camion_jugador(_ultimo_col_ray)
		var visible_para_jugador := (distancia_al_jugador < 75.0)
		if _tiempo_detenido > 6.5 and not bloqueado_por_jugador and not visible_para_jugador:
			_tiempo_detenido = 0.0
			_cooldown_reintento_arranque = 0.0
			if network_manager != null and network_manager.has_method("_reciclar_vehiculo_atascado"):
				network_manager._reciclar_vehiculo_atascado(self)
		elif _cooldown_reintento_arranque <= 0.0 and _tiempo_detenido > 2.5 and espacio_frente > dist_parada_efectiva + 0.85 and velocidad_objetivo > 0.25:
			# Si el frente está despejado, reanudar progresivamente desde cero sin salto brusco
			_cooldown_reintento_arranque = 2.5
			velocidad_actual = move_toward(velocidad_actual, minf(velocidad_objetivo, 1.5), aceleracion * 0.35 * delta)
			avance = velocidad_actual * delta
			luces_stop = false

	# MODO 0: Cruce continuo de intersección entre dos Path3D separados
	if _cruzando_interseccion:
		_procesar_cruce_interseccion(avance, delta)

	# MODO 1: Navegación directa en TrafficLane3D (mapa.tscn)
	elif current_lane != null and is_instance_valid(current_lane) and current_lane.curve != null:
		current_distance += avance
		var longitud_carril := current_lane.get_total_length()

		if current_distance >= longitud_carril:
			var proximo := _obtener_siguiente_carril()
			if proximo != null:
				current_distance = maxf(current_distance - longitud_carril, 0.0)
				current_lane = proximo
				_posicionar_en_carril(current_distance, 1.0)
			else:
				current_distance = fmod(current_distance, maxf(longitud_carril, 1.0))
				_posicionar_en_carril(current_distance, 1.0)
		else:
			_posicionar_en_carril(current_distance, delta)

		_actualizar_direccion_y_fisica_lane(delta)

	# MODO 2: Navegación sobre PathFollow3D con Traspaso Continuo a Siguiente Vía
	elif path_follow != null and is_instance_valid(path_follow):
		var camino := path_follow.get_parent() as Path3D
		if camino != null and camino.curve != null:
			var c_len := camino.curve.get_baked_length()
			var nuevo_prog: float = path_follow.progress + avance * float(sentido)

			# Detección de fin de carril / nodo: conectar con la siguiente vía
			if nuevo_prog >= c_len or nuevo_prog < 0.0:
				var traspaso_ok := false
				if network_manager != null and network_manager.has_method("traspasar_vehiculo_siguiente_camino"):
					traspaso_ok = network_manager.traspasar_vehiculo_siguiente_camino(self, camino, nuevo_prog, c_len)

				if not traspaso_ok:
					# Si no hay empalme a otro nodo, recircular sin invertir rotación
					path_follow.progress = fposmod(nuevo_prog, maxf(c_len, 1.0))
			else:
				path_follow.progress = nuevo_prog

		path_follow.h_offset = 0.0
		_actualizar_direccion_y_fisica_path(delta)

	# 3. Adherencia al suelo: en LOD 0 y 1, adaptado; en LOD 2 omitido
	if _lod_level < 2:
		_actualizar_contacto_suelo(delta)

	# 4. Dinámicas visuales de suspensión y ruedas (solo en cercanía LOD 0 y 1)
	if _lod_level == 0 and not _tiene_ruedas_ia:
		_girar_ruedas_fallback(delta)
		_actualizar_suspension_fallback(delta)
	elif _lod_level == 1 and not _tiene_ruedas_ia:
		_girar_ruedas_fallback(delta)

	# 5. Luces y parpadeo universal
	if _lod_level < 2:
		_actualizar_luces(delta)
		_actualizar_etiqueta(delta)


## Indica si el propio vehículo está detenido directamente por el jugador, semáforo o accidente (no impide adelantar tacos en otro carril libre)
func _bloqueado_directo_por_jugador() -> bool:
	if frenar_por_semaforo or _en_choque:
		return true
	if _ultimo_col_ray != null and _es_jugador_o_camion_jugador(_ultimo_col_ray):
		return true
	if _obtener_distancia_jugador_directa() <= 13.0:
		return true
	return false


## Lógica de cambio de carril fluido estilo ATS/ETS2 con curva en S y traspaso real de Path3D
func _procesar_cambio_carril(delta: float) -> void:
	if not permitir_cambio_carril:
		_yaw_cambio_carril = move_toward(_yaw_cambio_carril, 0.0, delta * 1.5)
		_desfase_lateral_objetivo = 0.0
		_desfase_lateral_actual = move_toward(_desfase_lateral_actual, 0.0, velocidad_cambio_lateral * delta)
		return

	# Si el jugador bloquea directamente al vehículo frente a frente (o hay semáforo/choque), mantener fila sin atravesarlo
	if _bloqueado_directo_por_jugador():
		_yaw_cambio_carril = move_toward(_yaw_cambio_carril, 0.0, delta * 2.0)
		if _estado_carril == EstadoCarril.CARRIL_BASE or _estado_carril == EstadoCarril.PREPARANDO_CAMBIO or (_estado_carril == EstadoCarril.CAMBIANDO and absf(_desfase_lateral_actual) < 1.5):
			_carril_destino_cambio = null
			_desfase_lateral_objetivo = 0.0
			_desfase_lateral_actual = move_toward(_desfase_lateral_actual, 0.0, velocidad_cambio_lateral * delta)
			luces_direccional_izq = false
			luces_direccional_der = false
			if absf(_desfase_lateral_actual) < 0.05:
				_desfase_lateral_actual = 0.0
				_estado_carril = EstadoCarril.CARRIL_BASE
			else:
				_desfase_inicio_cambio = _desfase_lateral_actual
				_duracion_cambio_carril = 1.6
				_estado_carril = EstadoCarril.RETORNANDO
				_tiempo_en_estado_carril = 0.0
			_cooldown_cambio_carril = maxf(_cooldown_cambio_carril, 3.0)
			return

	# Prohibido iniciar adelantamientos o cambios de carril en rotondas, cruces o curvas cerradas
	var cerca_rotonda: bool = false
	if network_manager != null and network_manager.has_method("_esta_en_zona_rotonda"):
		cerca_rotonda = bool(network_manager._esta_en_zona_rotonda(global_position, 48.0))
	if _cruzando_interseccion or cerca_rotonda or absf(angulo_ruedas) > deg_to_rad(6.5):
		if _estado_carril == EstadoCarril.CARRIL_BASE or _estado_carril == EstadoCarril.PREPARANDO_CAMBIO:
			_carril_destino_cambio = null
			_yaw_cambio_carril = move_toward(_yaw_cambio_carril, 0.0, delta * 2.0)
			_desfase_lateral_objetivo = 0.0
			_desfase_lateral_actual = move_toward(_desfase_lateral_actual, 0.0, velocidad_cambio_lateral * delta)
			luces_direccional_izq = false
			luces_direccional_der = false
			return

	if _cooldown_cambio_carril > 0.0:
		_cooldown_cambio_carril -= delta

	var camino_actual: Path3D = null
	if current_lane != null:
		camino_actual = current_lane
	elif path_follow != null:
		camino_actual = path_follow.get_parent() as Path3D

	match _estado_carril:
		EstadoCarril.CARRIL_BASE:
			_yaw_cambio_carril = move_toward(_yaw_cambio_carril, 0.0, delta * 2.0)
			_desfase_lateral_objetivo = 0.0
			_desfase_lateral_actual = move_toward(_desfase_lateral_actual, 0.0, velocidad_cambio_lateral * delta)

			# Evaluar adelantamiento tanto en movimiento lento como atrapado en un taco cuando hay carril paralelo despejado
			if _cooldown_cambio_carril <= 0.0 and not frenar_por_semaforo:
				var menor_ray := _obtener_menor_distancia_sensores()
				var obstaculo := minf(distancia_lider, menor_ray)
				var en_taco := (_tiempo_detenido > 0.8 and obstaculo < 22.0)
				var quiere_adelantar := (not _bloqueado_directo_por_jugador() and obstaculo < 28.0 and (en_taco or velocidad_actual < velocidad_crucero * 0.88 or obstaculo < 18.0))
				if quiere_adelantar and camino_actual != null:
					var dir_fwd := -global_transform.basis.z.normalized()
					var info_paralelo: Dictionary = {}
					if network_manager != null and network_manager.has_method("obtener_info_carril_paralelo"):
						info_paralelo = network_manager.obtener_info_carril_paralelo(camino_actual, global_position, dir_fwd, self, 0.0)

					if info_paralelo.get("encontrado", false):
						var d_lat: float = info_paralelo.get("distancia", ancho_carril)
						var lado: float = info_paralelo.get("lado", -1.0)
						_carril_destino_cambio = info_paralelo.get("path", null) as Path3D
						_desfase_inicio_cambio = _desfase_lateral_actual
						_desfase_lateral_objetivo = d_lat * lado
						_duracion_cambio_carril = clampf(d_lat / maxf(velocidad_cambio_lateral * 1.6, 1.8), 1.8, 2.8)
						luces_direccional_izq = (lado < 0.0)
						luces_direccional_der = (lado > 0.0)
						_estado_carril = EstadoCarril.PREPARANDO_CAMBIO
						_tiempo_en_estado_carril = 0.0
					else:
						_desfase_lateral_objetivo = 0.0
						_cooldown_cambio_carril = randf_range(1.2, 2.5)

		EstadoCarril.PREPARANDO_CAMBIO:
			_tiempo_en_estado_carril += delta
			_yaw_cambio_carril = move_toward(_yaw_cambio_carril, 0.0, delta * 2.0)
			luces_direccional_izq = (_desfase_lateral_objetivo < 0.0)
			luces_direccional_der = (_desfase_lateral_objetivo > 0.0)
			if is_instance_valid(_carril_destino_cambio) and network_manager != null and network_manager.has_method("carril_paralelo_despejado"):
				var off_d := _carril_destino_cambio.curve.get_closest_offset(_carril_destino_cambio.to_local(global_position))
				if not network_manager.carril_paralelo_despejado(_carril_destino_cambio, off_d, self):
					_estado_carril = EstadoCarril.CARRIL_BASE
					_carril_destino_cambio = null
					luces_direccional_izq = false
					luces_direccional_der = false
					_cooldown_cambio_carril = 2.0
					return
			if _tiempo_en_estado_carril >= duracion_direccional_previa:
				_estado_carril = EstadoCarril.CAMBIANDO
				_tiempo_en_estado_carril = 0.0

		EstadoCarril.CAMBIANDO:
			var factor_avance_lat := clampf(maxf(velocidad_actual, 2.0) / 4.5, 0.45, 1.15)
			_tiempo_en_estado_carril += delta * factor_avance_lat
			var dur: float = maxf(_duracion_cambio_carril, 0.6)
			var t: float = clampf(_tiempo_en_estado_carril / dur, 0.0, 1.0)
			var s: float = t * t * (3.0 - 2.0 * t)
			_desfase_lateral_actual = lerpf(_desfase_inicio_cambio, _desfase_lateral_objetivo, s)
			var vel_lat: float = (_desfase_lateral_objetivo - _desfase_inicio_cambio) * 6.0 * t * (1.0 - t) * factor_avance_lat / dur
			_yaw_cambio_carril = clampf(-atan2(vel_lat, maxf(velocidad_actual, 5.5)), -deg_to_rad(15.0), deg_to_rad(15.0))

			if t >= 1.0:
				_yaw_cambio_carril = 0.0
				luces_direccional_izq = false
				luces_direccional_der = false
				if is_instance_valid(_carril_destino_cambio) and network_manager != null and network_manager.has_method("completar_cambio_carril_a_camino"):
					if network_manager.completar_cambio_carril_a_camino(self, _carril_destino_cambio):
						_desfase_lateral_actual = 0.0
						_desfase_lateral_objetivo = 0.0
						_carril_destino_cambio = null
						_estado_carril = EstadoCarril.CARRIL_BASE
						_tiempo_en_estado_carril = 0.0
						_cooldown_cambio_carril = randf_range(7.0, 14.0)
						return
				_desfase_lateral_actual = _desfase_lateral_objetivo
				_estado_carril = EstadoCarril.ADELANTANDO
				_tiempo_en_estado_carril = 0.0

		EstadoCarril.ADELANTANDO:
			_tiempo_en_estado_carril += delta
			_yaw_cambio_carril = move_toward(_yaw_cambio_carril, 0.0, delta * 2.0)
			if _tiempo_en_estado_carril >= 5.0 and distancia_lider > 22.0:
				_desfase_inicio_cambio = _desfase_lateral_actual
				_desfase_lateral_objetivo = 0.0
				_duracion_cambio_carril = 2.0
				luces_direccional_der = (_desfase_lateral_actual < 0.0)
				luces_direccional_izq = (_desfase_lateral_actual > 0.0)
				_estado_carril = EstadoCarril.RETORNANDO
				_tiempo_en_estado_carril = 0.0

		EstadoCarril.RETORNANDO:
			_tiempo_en_estado_carril += delta
			var dur_r: float = maxf(_duracion_cambio_carril, 0.6)
			var t_r: float = clampf(_tiempo_en_estado_carril / dur_r, 0.0, 1.0)
			var s_r: float = t_r * t_r * (3.0 - 2.0 * t_r)
			_desfase_lateral_actual = lerpf(_desfase_inicio_cambio, _desfase_lateral_objetivo, s_r)
			var vel_lat_r: float = (_desfase_lateral_objetivo - _desfase_inicio_cambio) * 6.0 * t_r * (1.0 - t_r) / dur_r
			_yaw_cambio_carril = clampf(-atan2(vel_lat_r, maxf(velocidad_actual, 6.0)), -deg_to_rad(14.0), deg_to_rad(14.0))

			if t_r >= 1.0:
				_desfase_lateral_actual = 0.0
				_yaw_cambio_carril = 0.0
				_carril_destino_cambio = null
				_estado_carril = EstadoCarril.CARRIL_BASE
				luces_direccional_izq = false
				luces_direccional_der = false
				_cooldown_cambio_carril = randf_range(12.0, 22.0)


## Ajuste dinámico de adherencia al suelo (ruedas firmes sobre el asfalto)
func _actualizar_contacto_suelo(delta: float) -> void:
	if _sensor_suelo == null or not is_instance_valid(_sensor_suelo):
		return

	# Optimización LOD: en distancia lejana (LOD 2, >85m) no raycastear suelo; en LOD 1 cada 3 frames
	if _lod_level >= 2 and delta < 1.0:
		return
	if _lod_level == 1 and delta < 1.0 and (Engine.get_physics_frames() + get_instance_id()) % 3 != 0:
		return

	_sensor_suelo.force_raycast_update()
	if _sensor_suelo.is_colliding():
		var col = _sensor_suelo.get_collider()
		# Si colisiona con otro vehículo de tráfico o jugador, descartar para no elevarse al cielo
		if col is VehiculoTraficoIA or (col is Node and (col.is_in_group("trafico") or col.is_in_group("Vehiculo"))):
			return
		var col_pt := _sensor_suelo.get_collision_point()
		var y_suelo_deseado := col_pt.y + offset_y

		if path_follow != null and is_instance_valid(path_follow):
			var y_local_deseada := y_suelo_deseado - path_follow.global_position.y
			y_local_deseada = clampf(y_local_deseada, offset_y - 4.0, offset_y + 4.0)
			var factor := 1.0 if delta >= 1.0 else clampf(14.0 * delta, 0.0, 1.0)
			position.y = lerpf(position.y, y_local_deseada, factor)
		elif current_lane != null:
			var factor := 1.0 if delta >= 1.0 else clampf(14.0 * delta, 0.0, 1.0)
			global_position.y = lerpf(global_position.y, y_suelo_deseado, factor)
	else:
		if path_follow != null and is_instance_valid(path_follow):
			var factor := 1.0 if delta >= 1.0 else clampf(8.0 * delta, 0.0, 1.0)
			position.y = lerpf(position.y, offset_y, factor)


## Posicionamiento con elevación y desplazamiento lateral sobre la curva del carril
func iniciar_cruce_interseccion(camino_dest: Path3D, offset_dest: float, punto_dest: Vector3) -> void:
	_cruzando_interseccion = true
	_cruce_camino_destino = camino_dest
	_cruce_offset_destino = offset_dest
	_cruce_destino_pos = punto_dest
	_cruce_dist_inicial = maxf(global_position.distance_to(punto_dest), 1.0)
	_tiempo_en_cruce = 0.0

	# Calcular tangente final de destino para curvar suavemente y activar direccionales
	_cruce_dir_destino = (punto_dest - global_position)
	_cruce_dir_destino.y = 0.0
	if is_instance_valid(camino_dest) and camino_dest.curve != null:
		var c_len := camino_dest.curve.get_baked_length()
		var off_fwd := minf(offset_dest + 3.0, c_len)
		if off_fwd <= offset_dest + 0.2:
			off_fwd = maxf(offset_dest - 3.0, 0.0)
		var pt_a := camino_dest.to_global(camino_dest.curve.sample_baked(offset_dest))
		var pt_b := camino_dest.to_global(camino_dest.curve.sample_baked(off_fwd))
		var d_tan := (pt_b - pt_a) if off_fwd > offset_dest else (pt_a - pt_b)
		d_tan.y = 0.0
		if d_tan.length_squared() > 0.001:
			_cruce_dir_destino = d_tan.normalized()
	elif _cruce_dir_destino.length_squared() > 0.001:
		_cruce_dir_destino = _cruce_dir_destino.normalized()

	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() > 0.001 and _cruce_dir_destino.length_squared() > 0.001:
		var ang := fwd.normalized().signed_angle_to(_cruce_dir_destino, Vector3.UP)
		if ang > deg_to_rad(5.0):
			luces_direccional_izq = true
			luces_direccional_der = false
			_timer_direccional_giro = 2.4
		elif ang < -deg_to_rad(5.0):
			luces_direccional_der = true
			luces_direccional_izq = false
			_timer_direccional_giro = 2.4
		elif network_manager != null and network_manager.has_method("_es_rotonda"):
			if network_manager._es_rotonda(camino_dest):
				luces_direccional_izq = true
				luces_direccional_der = false
				_timer_direccional_giro = 2.0
			else:
				luces_direccional_der = true
				luces_direccional_izq = false
				_timer_direccional_giro = 2.0


func _procesar_cruce_interseccion(avance: float, delta: float) -> void:
	if not is_instance_valid(_cruce_camino_destino):
		_cruzando_interseccion = false
		return

	_tiempo_en_cruce += delta
	var pos_actual := global_position
	var dir := _cruce_destino_pos - pos_actual
	dir.y = 0.0
	var dist_restante := dir.length()
	var dir_n := dir / dist_restante if dist_restante > 0.001 else _cruce_dir_destino

	var rebaso_destino := (_tiempo_en_cruce > 0.25 and dist_restante < 6.5 and _cruce_dir_destino.length_squared() > 0.001 and dir_n.dot(_cruce_dir_destino) < 0.0)
	if dist_restante <= maxf(avance + 0.5, 2.2) or rebaso_destino or _tiempo_en_cruce > 4.5:
		_cruzando_interseccion = false
		var dest := _cruce_camino_destino
		var off := _cruce_offset_destino
		_cruce_camino_destino = null
		if network_manager != null and network_manager.has_method("finalizar_cruce_camino"):
			network_manager.finalizar_cruce_camino(self, dest, off)
		return

	var t_blend := clampf(1.0 - (dist_restante / _cruce_dist_inicial), 0.0, 1.0)
	var has_tan := _cruce_dir_destino.length_squared() > 0.001
	var dir_visual := dir_n.slerp(_cruce_dir_destino, t_blend * 0.70).normalized() if has_tan else dir_n
	# El desplazamiento siempre converge hacia _cruce_destino_pos (evita orbitar tangencialmente alrededor del punto)
	var dir_mov := dir_n if (dist_restante <= 4.5 or not has_tan) else dir_n.slerp(_cruce_dir_destino, t_blend * 0.28).normalized()
	var target_basis := Basis.looking_at(dir_visual, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_basis, clampf(delta * 4.5, 0.0, 1.0))

	var fwd_chasis := -global_transform.basis.z
	fwd_chasis.y = 0.0
	if fwd_chasis.length_squared() > 0.001:
		var angle_diff := fwd_chasis.normalized().signed_angle_to(dir_visual, Vector3.UP)
		angulo_ruedas = lerpf(angulo_ruedas, clampf(angle_diff * 1.4, -deg_to_rad(32.0), deg_to_rad(32.0)), clampf(delta * 8.0, 0.0, 1.0))

	global_position = pos_actual + dir_mov * avance
	linear_velocity = -global_transform.basis.z * velocidad_actual


func _sample_lane_point_continuous(d: float, total_len: float, right_offset: float) -> Vector3:
	if d <= total_len:
		var t := current_lane.sample_transform_at_distance(maxf(d, 0.0))
		return t.origin + (t.basis.x.normalized() * right_offset)
	var prox := _obtener_siguiente_carril_preview()
	if prox != null:
		var t_next := prox.sample_transform_at_distance(d - total_len)
		return t_next.origin + (t_next.basis.x.normalized() * right_offset)
	var t_end := current_lane.sample_transform_at_distance(total_len)
	return t_end.origin + (t_end.basis.x.normalized() * right_offset)


func _posicionar_en_carril(dist: float, delta: float) -> void:
	if current_lane == null or current_lane.curve == null:
		return

	var total_len := current_lane.get_total_length()
	if total_len <= 0.0:
		return

	var trans := current_lane.sample_transform_at_distance(dist)
	var up_vec := trans.basis.y.normalized()
	if up_vec.length_squared() < 0.01:
		up_vec = Vector3.UP
	var right_vec := trans.basis.x.normalized()

	# Posicionar con elevación offset_y y desplazamiento lateral de carril
	global_position = trans.origin + (up_vec * offset_y) + (right_vec * _desfase_lateral_actual)

	# Modelo bicicleta (eje trasero y delantero) con transición continua entre carriles
	var L := clampf(distancia_ejes, 2.4, 5.5)
	var pt_rear := _sample_lane_point_continuous(maxf(dist - L * 0.45, 0.0), total_len, _desfase_lateral_actual)
	var pt_front := _sample_lane_point_continuous(dist + L * 0.55, total_len, _desfase_lateral_actual)
	var dir_adelante := (pt_front - pt_rear)
	dir_adelante.y = 0.0
	if dir_adelante.length_squared() > 0.01:
		var target_basis := Basis.looking_at(dir_adelante.normalized(), Vector3.UP)
		var factor_suavizado := 1.0 if delta >= 1.0 else clampf(7.5 * delta, 0.0, 1.0)
		global_transform.basis = global_transform.basis.slerp(target_basis, factor_suavizado)


func _obtener_siguiente_carril_preview() -> TrafficLane3D:
	if current_lane != null and not current_lane.next_lanes.is_empty():
		for l in current_lane.next_lanes:
			if is_instance_valid(l) and l.is_active:
				return l
	return null


func _obtener_siguiente_carril() -> TrafficLane3D:
	# 1. Carriles explícitos configurados en next_lanes
	if current_lane != null and not current_lane.next_lanes.is_empty():
		var candidatos: Array[TrafficLane3D] = []
		for l in current_lane.next_lanes:
			if is_instance_valid(l) and l.is_active:
				candidatos.append(l)
		if not candidatos.is_empty():
			return candidatos.pick_random()

	# 2. Conectar automáticamente con el inicio de un carril contiguo en la red vial
	if network_manager != null and "lanes" in network_manager:
		var fin_actual: Vector3 = current_lane.sample_point_at_distance(current_lane.get_total_length()) if current_lane != null else global_position
		var carril_cercano: TrafficLane3D = null
		var menor_dist: float = 25.0
		for l in network_manager.lanes:
			var lane_cand := l as TrafficLane3D
			if is_instance_valid(lane_cand) and lane_cand != current_lane and lane_cand.is_active:
				var ini: Vector3 = lane_cand.sample_point_at_distance(0.0)
				var d: float = fin_actual.distance_to(ini)
				if d < menor_dist:
					menor_dist = d
					carril_cercano = lane_cand
		if carril_cercano != null:
			return carril_cercano

		# Si no hay empalme directo, reaparecer en un carril activo aleatorio del mapa
		var disponibles: Array[TrafficLane3D] = []
		for l in network_manager.lanes:
			var lane_disp := l as TrafficLane3D
			if is_instance_valid(lane_disp) and lane_disp.is_active:
				disponibles.append(lane_disp)
		if not disponibles.is_empty():
			return disponibles.pick_random()

	return null


func _actualizar_direccion_y_fisica_lane(delta: float) -> void:
	if not is_inside_tree():
		return
	linear_velocity = -global_transform.basis.z * velocidad_actual

	if current_lane != null and current_lane.curve != null:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		var total_len := current_lane.get_total_length()
		var L := clampf(distancia_ejes, 2.4, 5.5)
		var look_ahead := _sample_lane_point_continuous(current_distance + L * 0.55 + 3.0, total_len, _desfase_lateral_actual)
		var dir_deseada := (look_ahead - global_position)
		dir_deseada.y = 0.0
		if forward.length_squared() > 0.01 and dir_deseada.length_squared() > 0.01:
			var angle_diff := forward.normalized().signed_angle_to(dir_deseada.normalized(), Vector3.UP)
			var objetivo_ang := clampf(angle_diff * 1.35, -deg_to_rad(32.0), deg_to_rad(32.0))
			angulo_ruedas = lerpf(angulo_ruedas, objetivo_ang, clampf(delta * 8.0, 0.0, 1.0))


func _actualizar_direccion_y_fisica_path(delta: float) -> void:
	if not is_inside_tree() or path_follow == null:
		return
	var camino := path_follow.get_parent() as Path3D
	if camino != null and camino.is_inside_tree() and camino.curve != null:
		var longitud := camino.curve.get_baked_length()
		if longitud > 0.0:
			# 1. Cinemática de giro sobre eje trasero (Bicycle/Ackerman Model estilo ATS/ETS2)
			var L := clampf(distancia_ejes, 2.4, 5.5)
			var prog := path_follow.progress
			var es_cerrado := camino.curve.sample_baked(0.0).distance_to(camino.curve.sample_baked(longitud)) < 3.0
			var prog_rear: float
			var prog_front: float
			if es_cerrado:
				prog_rear = fposmod(prog - (L * 0.45 * float(sentido)), longitud)
				prog_front = fposmod(prog + (L * 0.55 * float(sentido)), longitud)
			else:
				prog_rear = clampf(prog - (L * 0.45 * float(sentido)), 0.0, longitud)
				prog_front = clampf(prog + (L * 0.55 * float(sentido)), 0.0, longitud)

			var pt_rear := camino.to_global(camino.curve.sample_baked(prog_rear))
			var pt_front := camino.to_global(camino.curve.sample_baked(prog_front))
			var dir_chasis := (pt_front - pt_rear)
			dir_chasis.y = 0.0

			if dir_chasis.length_squared() > 0.01:
				if sentido < 0:
					dir_chasis = -dir_chasis
				var target_basis := Basis.looking_at(dir_chasis.normalized(), Vector3.UP)
				# Aplicar desfase lateral siempre perpendicular a la vía (evita desviarse hacia aceras cuando ROTATION_NONE)
				var offset_local := path_follow.to_local(path_follow.global_position + (target_basis.x.normalized() * _desfase_lateral_actual))
				position.x = offset_local.x
				position.z = offset_local.z
				if absf(_yaw_cambio_carril) > 0.001:
					target_basis = target_basis.rotated(Vector3.UP, _yaw_cambio_carril)
				# Inercia angular pesada y continua de camión (sin saltos ni interferencias de riel)
				var factor_suave := 1.0 if delta >= 1.0 else clampf(delta * 5.5, 0.0, 1.0)
				global_transform.basis = global_transform.basis.slerp(target_basis, factor_suave)

				# 2. Las ruedas delanteras doblan hacia la curva por delante de la cabina
				var prog_look: float
				if es_cerrado:
					prog_look = fposmod(prog_front + (2.5 * float(sentido)), longitud)
				else:
					prog_look = clampf(prog_front + (2.5 * float(sentido)), 0.0, longitud)
				var pt_look := camino.to_global(camino.curve.sample_baked(prog_look))
				var dir_look := (pt_look - pt_front)
				dir_look.y = 0.0
				if dir_look.length_squared() > 0.01:
					if sentido < 0:
						dir_look = -dir_look
					var fwd_chasis := -global_transform.basis.z
					fwd_chasis.y = 0.0
					var angle_diff := fwd_chasis.normalized().signed_angle_to(dir_look.normalized(), Vector3.UP)
					var objetivo_ang := clampf(angle_diff * 1.35, -deg_to_rad(32.0), deg_to_rad(32.0))
					angulo_ruedas = lerpf(angulo_ruedas, objetivo_ang, clampf(delta * 6.5, 0.0, 1.0))
			else:
				var dir_fwd := -global_transform.basis.z
				if dir_fwd.length_squared() > 0.01:
					var target_basis := Basis.looking_at(dir_fwd, Vector3.UP)
					global_transform.basis = global_transform.basis.slerp(target_basis, clampf(delta * 5.5, 0.0, 1.0))

	# Vector de velocidad real para alimentar dinámicas de suspensión, cabeceo, balanceo y rodadura
	linear_velocity = -global_transform.basis.z * velocidad_actual


func _obtener_menor_distancia_sensores() -> float:
	# En LOD 2 (> 85m), la separación con otros vehículos se calcula 100% analíticamente sin raycasts
	if _lod_level >= 2:
		return INF

	var frame_actual := Engine.get_physics_frames()
	if _ultimo_frame_ray == frame_actual:
		return _distancia_ray_cache

	# En LOD 2 (>85m), ahorrar raycasts por completo
	if _lod_level >= 2:
		_distancia_ray_cache = INF
		_ultimo_col_ray = null
		return INF

	# En LOD 1 (35m - 85m), actualizar solo cada 4 frames con 2 sensores principales
	if _lod_level == 1 and (frame_actual + get_instance_id()) % 4 != 0:
		return _distancia_ray_cache

	# En LOD 0 fuera de zona cercana (>18m), alternar por instancia cada 2 frames
	if _lod_level == 0 and distancia_al_jugador > 18.0 and ((frame_actual + get_instance_id()) & 1) != 0:
		return _distancia_ray_cache

	_ultimo_frame_ray = frame_actual
	_ultimo_col_ray = null
	var menor := INF

	var en_curva := absf(angulo_ruedas) > deg_to_rad(4.0)
	var cant_rayos: int = 2 if _lod_level == 1 else _sensores_frontales.size()
	var fwd_propio := -global_transform.basis.z
	fwd_propio.y = 0.0
	if fwd_propio.length_squared() > 0.001:
		fwd_propio = fwd_propio.normalized()

	for i in range(cant_rayos):
		if i >= _sensores_frontales.size():
			break
		var ray: RayCast3D = _sensores_frontales[i]
		if is_instance_valid(ray):
			# Inclinar el abanico de sensores en el sentido del giro para detectar jugador/obstáculos dentro de la curva
			ray.rotation.y = angulo_ruedas * 0.65 if en_curva else 0.0
			ray.force_raycast_update()
			if ray.is_colliding():
				var col = ray.get_collider()
				if _es_obstaculo_valido(col):
					var d := maxf(ray.global_position.distance_to(ray.get_collision_point()) - _retroceso_ray, 0.0)
					if en_curva and d > 24.0:
						continue
					# En rotonda: quien ya va dentro tiene prelación y no frena por vehículos esperando en vías de entrada
					if col is VehiculoTraficoIA and col is Node3D:
						var col_veh := col as VehiculoTraficoIA
						if path_follow != null and network_manager != null and network_manager.has_method("_es_rotonda"):
							var mi_cam := path_follow.get_parent() as Path3D
							if mi_cam != null and network_manager._es_rotonda(mi_cam) and not _cruzando_interseccion:
								var otro_cam := col_veh.path_follow.get_parent() as Path3D if col_veh.path_follow != null else null
								if otro_cam != mi_cam and not network_manager._es_rotonda(otro_cam):
									# Ignorar vehículos fuera del anillo o recién asomando en entrada si no están en nuestro camino inmediato
									if not col_veh._cruzando_interseccion or d > 9.0:
										continue
						var col_node := col as Node3D
						var fwd_otro := -col_node.global_transform.basis.z
						fwd_otro.y = 0.0
						if fwd_otro.length_squared() > 0.001:
							var alinea := fwd_propio.dot(fwd_otro.normalized())
							if en_curva and alinea < 0.10 and d > 8.0:
								continue
					if d < menor:
						menor = d
						_ultimo_col_ray = col

	var info_jug := _obtener_info_jugador_directa()
	var dist_jug_dir: float = info_jug.get("dist", INF)
	if dist_jug_dir < menor:
		menor = dist_jug_dir
		_ultimo_col_ray = info_jug.get("obj", null)

	_distancia_ray_cache = menor
	return _distancia_ray_cache


func _obtener_distancia_jugador_directa() -> float:
	return float(_obtener_info_jugador_directa().get("dist", INF))


## Barrera geométrica directa en espacio local contra el jugador, su vehículo y remolques para impedir traspasos
func _obtener_info_jugador_directa() -> Dictionary:
	if not is_inside_tree():
		return {"dist": INF, "obj": null}
	var mitad_largo: float = longitud_vehiculo * 0.5
	var menor_j: float = INF
	var mejor_obj: Object = null

	var jugador_node: Node3D = null
	if distancia_al_jugador <= 40.0:
		if network_manager != null and network_manager.has_method("_find_player"):
			jugador_node = network_manager._find_player() as Node3D
		elif get_tree() != null:
			jugador_node = get_tree().get_first_node_in_group("jugador") as Node3D
		if is_instance_valid(jugador_node):
			var loc_j := to_local(jugador_node.global_position)
			if absf(loc_j.y) <= 3.2 and absf(loc_j.x) <= 1.65 and loc_j.z <= 0.25 and loc_j.z >= -(mitad_largo + 24.0):
				var dist_j: float = maxf(-loc_j.z - mitad_largo, 0.0)
				if dist_j < menor_j:
					menor_j = dist_j
					mejor_obj = jugador_node
			var veh_conducido = jugador_node.get("_vehiculo_actual")
			if veh_conducido is Node3D and is_instance_valid(veh_conducido):
				var vc := veh_conducido as Node3D
				for z_s in [-2.8, 0.0, 2.8]:
					var loc_v := to_local(vc.to_global(Vector3(0.0, 1.0, z_s)))
					if absf(loc_v.y) <= 3.2 and absf(loc_v.x) <= 1.75 and loc_v.z <= 0.25 and loc_v.z >= -(mitad_largo + 24.0):
						var dist_v: float = maxf(-loc_v.z - mitad_largo, 0.0)
						if dist_v < menor_j:
							menor_j = dist_v
							mejor_obj = vc

	if get_tree() != null and _lod_level <= 1 and distancia_al_jugador <= 75.0:
		for tr_node in get_tree().get_nodes_in_group("remolque"):
			if not (tr_node is Node3D) or not is_instance_valid(tr_node):
				continue
			var tr := tr_node as Node3D
			if not tr.is_inside_tree() or tr.global_position.distance_squared_to(global_position) > 1024.0:
				continue
			for z_t in [-6.0, -3.5, -1.0, 1.5, 4.0, 6.2]:
				for x_t in [-1.15, 1.15]:
					var loc_t := to_local(tr.to_global(Vector3(x_t, 1.2, z_t)))
					if absf(loc_t.y) <= 3.6 and absf(loc_t.x) <= 1.65 and loc_t.z <= 0.25 and loc_t.z >= -(mitad_largo + 24.0):
						var dist_t: float = maxf(-loc_t.z - mitad_largo, 0.0)
						if dist_t < menor_j:
							menor_j = dist_t
							mejor_obj = tr

	return {"dist": menor_j, "obj": mejor_obj}


func _es_obstaculo_valido(col: Object) -> bool:
	if col == null or col == self:
		return false
	if col is Node and (is_ancestor_of(col) or (col as Node).is_ancestor_of(self)):
		return false
	# Ignorar terreno, carretera estática, túneles, mallas de asfalto y guardrails
	if col is StaticBody3D or col is CSGShape3D or col is GridMap:
		return false
	# Frenar por vehículos, jugadores, peatones o tráfico
	if col is RigidBody3D or col is CharacterBody3D or col is VehiculoTraficoIA:
		return true
	if col is Node and (col.is_in_group("Vehiculo") or col.is_in_group("jugador") or col.is_in_group("player") or col.is_in_group("trafico") or col.is_in_group("remolque") or col.is_in_group("trailers")):
		return true
	return false


func _calcular_velocidad_objetivo() -> float:
	var objetivo := velocidad_crucero * multiplicador_velocidad

	# Respetar límite de velocidad si estamos en un TrafficLane3D
	var camino: Node = null
	if current_lane != null:
		camino = current_lane
	elif path_follow != null:
		camino = path_follow.get_parent()

	if camino != null and camino.get("speed_limit") != null:
		var limite_ms: float = (float(camino.get("speed_limit")) * 1000.0) / 3600.0
		if limite_ms > 0.0:
			objetivo = minf(objetivo, limite_ms)

	# 0. Reducción natural y progresiva de velocidad en rotondas y curvas cerradas
	var angulo_curva := absf(angulo_ruedas)
	if angulo_curva > deg_to_rad(15.0):
		var t_curva := clampf((angulo_curva - deg_to_rad(15.0)) / deg_to_rad(25.0), 0.0, 1.0)
		var factor_curva := lerpf(1.0, 0.70, smoothstep(0.0, 1.0, t_curva))
		var vel_curva := maxf(objetivo * factor_curva, 9.5)
		objetivo = minf(objetivo, vel_curva)

	# 1. Distancia de líder sobre la curva calculada por TrafficNetworkManager3D / GestorTrafico
	if distancia_lider < INF:
		objetivo = minf(objetivo, _velocidad_segura(distancia_lider))

	# 2. Sensores RayCast frontales (detectan obstáculos, jugadores o camiones delante)
	var menor_distancia_ray := _obtener_menor_distancia_sensores()

	if menor_distancia_ray < INF:
		if menor_distancia_ray <= distancia_raycast_corto:
			objetivo = 0.0 # Parada preventiva de seguridad
		else:
			objetivo = minf(objetivo, _velocidad_segura(menor_distancia_ray))

	# 3. Semáforo
	if frenar_por_semaforo:
		objetivo = 0.0

	return objetivo


## Curva de desaceleración progresiva continua (IDM-like) para paradas suaves sin tirones
func _velocidad_segura(hueco: float) -> float:
	var espacio := maxf(hueco - distancia_minima, 0.0)
	var rango := maxf(distancia_raycast_largo - distancia_minima, 1.0)
	var ratio := clampf(espacio / rango, 0.0, 1.0)
	var vel_max := velocidad_crucero * multiplicador_velocidad
	var ratio_suave := smoothstep(0.0, 1.0, ratio)
	var piso_creep := 1.2 * smoothstep(distancia_minima * 1.05, distancia_minima * 1.6, hueco)
	return maxf(vel_max * ratio_suave, piso_creep)


func _girar_ruedas_fallback(delta: float) -> void:
	if radio_rueda <= 0.0 or _ruedas_visuales.is_empty():
		return
	var angulo := -velocidad_actual * delta / radio_rueda
	for r in _ruedas_visuales:
		if is_instance_valid(r):
			r.rotate_x(angulo)


## Cabeceo y balanceo de carrocería fallback para vehículos sin Ruedas_IA (Transit, etc.)
func _actualizar_suspension_fallback(delta: float) -> void:
	if not is_instance_valid(_nodo_visual_fallback):
		return

	var accel := (velocidad_actual - _vel_anterior_fallback) / maxf(delta, 0.001)
	_vel_anterior_fallback = velocidad_actual

	# Cabeceo por freno/aceleración (nose-down al frenar, squat al acelerar)
	var target_pitch: float = 0.0
	if accel < 0.0:
		target_pitch = clampf(-accel / 3.0 * deg_to_rad(4.5), -deg_to_rad(4.5), deg_to_rad(4.5))
	else:
		target_pitch = clampf(-accel / 3.0 * deg_to_rad(3.0), -deg_to_rad(4.5), deg_to_rad(3.0))

	# Balanceo por viraje centrífugo
	var lat_acc := (velocidad_actual * velocidad_actual * sin(angulo_ruedas)) / 4.0
	var target_roll := clampf(-lat_acc / 4.0 * deg_to_rad(4.0), -deg_to_rad(4.0), deg_to_rad(4.0))

	_cabeceo_fallback = lerpf(_cabeceo_fallback, target_pitch, clampf(4.0 * delta, 0.0, 1.0))
	_balanceo_fallback = lerpf(_balanceo_fallback, target_roll, clampf(3.0 * delta, 0.0, 1.0))

	_nodo_visual_fallback.rotation.x = _cabeceo_fallback
	_nodo_visual_fallback.rotation.z = _balanceo_fallback


func _actualizar_luces(delta: float) -> void:
	if _timer_direccional_giro > 0.0:
		_timer_direccional_giro -= delta
		if _timer_direccional_giro <= 0.0 and not _en_choque and _estado_carril == EstadoCarril.CARRIL_BASE:
			luces_direccional_izq = false
			luces_direccional_der = false

	# Parpadeo de direccionales a 1.5 Hz
	if luces_direccional_izq or luces_direccional_der:
		_timer_parpadeo += delta
		var periodo := 1.0 / 1.5
		if _timer_parpadeo >= periodo:
			_timer_parpadeo = fmod(_timer_parpadeo, periodo)
			_estado_parpadeo = not _estado_parpadeo
	else:
		_timer_parpadeo = 0.0
		_estado_parpadeo = false

	# Meshes fallback si el modelo no tiene módulo Luces_IA propio
	if _luces_universales != null:
		for m in _luces_stop_mesh:
			if is_instance_valid(m):
				m.visible = luces_stop
		for m in _luces_izq_mesh:
			if is_instance_valid(m):
				m.visible = (luces_direccional_izq and _estado_parpadeo)
		for m in _luces_der_mesh:
			if is_instance_valid(m):
				m.visible = (luces_direccional_der and _estado_parpadeo)


func _crear_etiqueta() -> void:
	_etiqueta = Label3D.new()
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.no_depth_test = true
	_etiqueta.pixel_size = 0.012
	_etiqueta.font_size = 48
	_etiqueta.outline_size = 12
	_etiqueta.position = Vector3(0.0, altura_etiqueta, 0.0)
	add_child(_etiqueta)


func _actualizar_etiqueta(delta: float) -> void:
	if _etiqueta == null:
		return
	_tiempo_etiqueta += delta
	if _tiempo_etiqueta < 0.2:
		return
	_tiempo_etiqueta = 0.0
	_etiqueta.text = "%d km/h" % int(roundf(velocidad_actual * 3.6))
