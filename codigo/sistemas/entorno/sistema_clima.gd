# ═══════════════════════════════════════════════════════════════════════════════
# sistema_clima.gd
# Sistema Dinámico de Climas y Precipitación (Lluvia / Nublado / Soleado)
# Diseñado para integrarse con el Sky Shader volumétrico y WorldEnvironment
# Proyecto: Nuestra Tierra 2.0
# ═══════════════════════════════════════════════════════════════════════════════
@tool
class_name SistemaClima
extends Node3D

signal clima_cambiado(tipo: TipoClima, nombre: String)
signal factor_lluvia_actualizado(factor: float)

enum TipoClima {
	DESPEJADO,             # Soleado, cielo azul limpio, nubes compactas blancas
	PARCIALMENTE_NUBLADO,  # Cúmulos dispersos con sombra suave
	NUBLADO,               # Cielo cubierto de nubes densas grisáceas
	LLUVIA_LIGERA,         # Llovizna, nubes oscuras, niebla húmeda
	TORMENTA               # Nubes de tormenta gris carbón, lluvia fuerte, viento veloz
}

@export_group("🌦️ Control de Clima")
## Clima activo actualmente. Modificarlo en el Inspector inicia una transición suave.
@export var clima_actual: TipoClima = TipoClima.DESPEJADO:
	set(valor):
		clima_actual = valor
		_iniciar_transicion(valor)

## Tiempo en segundos que dura la transición suave entre dos climas.
@export_range(0.1, 30.0, 0.5) var tiempo_transicion: float = 6.0

## Si está activo, el clima cambia aleatoriamente con el paso del tiempo en el juego.
@export var cambio_automatico: bool = false
## Intervalo en segundos reales para evaluar un cambio de clima aleatorio.
@export_range(30.0, 600.0, 10.0) var intervalo_cambio_segundos: float = 180.0

@export_group("🔗 Referencias de Escena")
## Nodo WorldEnvironment con el material de cielo. Si no se asigna, se busca en la escena.
@export var world_environment: WorldEnvironment
## Nodo DirectionalLight3D del Sol (o ControladorSolLuna).
@export var luz_sol: DirectionalLight3D

@export_group("🌧️ Precipitación (Partículas)")
## Nodo GPUParticles3D para la lluvia. Si no existe, se genera automáticamente.
@export var particulas_lluvia: GPUParticles3D
## Seguir la posición de la cámara activa para que la lluvia siempre rodee al jugador.
@export var lluvia_sigue_camara: bool = true

# Estructura de perfiles climáticos
var _perfiles: Dictionary = {}

# Variables de transición interna (lerp)
var _valores_actuales: Dictionary = {}
var _valores_objetivo: Dictionary = {}
var _tiempo_restante_transicion: float = 0.0
var _duracion_transicion_actual: float = 1.0
var _temporizador_clima_auto: float = 0.0

# Caché de ShaderMaterial de cielo y materiales de vehículos
var _mat_cielo: ShaderMaterial = null
var _mat_cromo_cache: ShaderMaterial = null
var _mat_carroceria_cache: ShaderMaterial = null


func _init() -> void:
	_definir_perfiles_clima()
	_valores_actuales = _perfiles[TipoClima.DESPEJADO].duplicate()
	_valores_objetivo = _perfiles[TipoClima.DESPEJADO].duplicate()


func _ready() -> void:
	_buscar_nodos_si_faltan()
	_obtener_material_cielo()
	_asegurar_particulas_lluvia()
	_iniciar_transicion(clima_actual, true)


func _process(delta: float) -> void:
	# Seguir la cámara con el emisor de lluvia
	if lluvia_sigue_camara and is_instance_valid(particulas_lluvia):
		var cam = get_viewport().get_camera_3d() if get_viewport() else null
		if cam:
			particulas_lluvia.global_position = cam.global_position + Vector3(0, 10.0, 0)

	# Procesar interpolación suave de clima
	if _tiempo_restante_transicion > 0.0:
		_tiempo_restante_transicion = maxf(_tiempo_restante_transicion - delta, 0.0)
		var factor_t = 1.0 - (_tiempo_restante_transicion / _duracion_transicion_actual)
		# Curva cúbica suave
		var t_suave = factor_t * factor_t * (3.0 - 2.0 * factor_t)
		_interpolar_valores(t_suave)
		_aplicar_valores_a_escena()

	# Cambio automático de clima en el juego
	if cambio_automatico and not Engine.is_editor_hint():
		_temporizador_clima_auto += delta
		if _temporizador_clima_auto >= intervalo_cambio_segundos:
			_temporizador_clima_auto = 0.0
			_elegir_siguiente_clima_aleatorio()


# ═══════════════════════════════════════════════════════════════════════════════
# MÉTODOS PÚBLICOS DE CONTROL
# ═══════════════════════════════════════════════════════════════════════════════

## Cambia el clima con una duración de transición personalizada (en segundos).
func cambiar_clima(nuevo_clima: TipoClima, duracion_segundos: float = -1.0) -> void:
	if duracion_segundos > 0.0:
		tiempo_transicion = duracion_segundos
	clima_actual = nuevo_clima


## Retorna el factor actual de lluvia (0.0 a 1.0).
func obtener_factor_lluvia() -> float:
	return _valores_actuales.get("intensidad_lluvia", 0.0)


## Retorna el nombre legible del clima actual.
func obtener_nombre_clima() -> String:
	match clima_actual:
		TipoClima.DESPEJADO: return "Despejado"
		TipoClima.PARCIALMENTE_NUBLADO: return "Parcialmente Nublado"
		TipoClima.NUBLADO: return "Nublado"
		TipoClima.LLUVIA_LIGERA: return "Lluvia Ligera"
		TipoClima.TORMENTA: return "Tormenta"
		_: return "Desconocido"


# ═══════════════════════════════════════════════════════════════════════════════
# NÚCLEO DE PERFILES Y TRANSICIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _definir_perfiles_clima() -> void:
	_perfiles[TipoClima.DESPEJADO] = {
		"cloud_coverage": 0.48,
		"cloud_feather": 0.12,
		"cloud_color": Color(0.96, 0.97, 0.98, 1.0),
		"cloud_shadow_color": Color(0.52, 0.58, 0.68, 1.0),
		"sky_day": Color(0.24, 0.46, 0.72, 1.0),
		"horizon_day": Color(0.74, 0.80, 0.85, 1.0),
		"wind_speed": Vector2(0.35, 0.18),
		"sun_strength": 14.0,
		"factor_energia_sol": 1.0,
		"niebla_densidad": 0.00035,
		"niebla_color": Color(0.70, 0.78, 0.85, 1.0),
		"intensidad_lluvia": 0.0
	}

	_perfiles[TipoClima.PARCIALMENTE_NUBLADO] = {
		"cloud_coverage": 0.60,
		"cloud_feather": 0.12,
		"cloud_color": Color(0.94, 0.95, 0.96, 1.0),
		"cloud_shadow_color": Color(0.48, 0.54, 0.64, 1.0),
		"sky_day": Color(0.22, 0.42, 0.68, 1.0),
		"horizon_day": Color(0.70, 0.76, 0.82, 1.0),
		"wind_speed": Vector2(0.5, 0.25),
		"sun_strength": 11.0,
		"factor_energia_sol": 0.85,
		"niebla_densidad": 0.0006,
		"niebla_color": Color(0.66, 0.74, 0.80, 1.0),
		"intensidad_lluvia": 0.0
	}

	_perfiles[TipoClima.NUBLADO] = {
		"cloud_coverage": 0.85,
		"cloud_feather": 0.14,
		"cloud_color": Color(0.68, 0.72, 0.78, 1.0),
		"cloud_shadow_color": Color(0.40, 0.44, 0.52, 1.0),
		"sky_day": Color(0.35, 0.42, 0.52, 1.0),
		"horizon_day": Color(0.55, 0.60, 0.68, 1.0),
		"wind_speed": Vector2(0.8, 0.4),
		"sun_strength": 4.0,
		"factor_energia_sol": 0.40,
		"niebla_densidad": 0.0022,
		"niebla_color": Color(0.50, 0.55, 0.62, 1.0),
		"intensidad_lluvia": 0.0
	}

	_perfiles[TipoClima.LLUVIA_LIGERA] = {
		"cloud_coverage": 0.92,
		"cloud_feather": 0.16,
		"cloud_color": Color(0.42, 0.46, 0.52, 1.0),
		"cloud_shadow_color": Color(0.25, 0.28, 0.35, 1.0),
		"sky_day": Color(0.22, 0.28, 0.36, 1.0),
		"horizon_day": Color(0.42, 0.46, 0.54, 1.0),
		"wind_speed": Vector2(1.2, 0.6),
		"sun_strength": 1.5,
		"factor_energia_sol": 0.22,
		"niebla_densidad": 0.0040,
		"niebla_color": Color(0.40, 0.44, 0.50, 1.0),
		"intensidad_lluvia": 0.55
	}

	_perfiles[TipoClima.TORMENTA] = {
		"cloud_coverage": 0.98,
		"cloud_feather": 0.18,
		"cloud_color": Color(0.22, 0.25, 0.30, 1.0),
		"cloud_shadow_color": Color(0.12, 0.14, 0.18, 1.0),
		"sky_day": Color(0.12, 0.15, 0.22, 1.0),
		"horizon_day": Color(0.28, 0.32, 0.38, 1.0),
		"wind_speed": Vector2(2.0, 1.0),
		"sun_strength": 0.0,
		"factor_energia_sol": 0.08,
		"niebla_densidad": 0.0065,
		"niebla_color": Color(0.25, 0.28, 0.34, 1.0),
		"intensidad_lluvia": 1.0
	}


func _iniciar_transicion(nuevo_clima: TipoClima, instantaneo: bool = false) -> void:
	if not _perfiles.has(nuevo_clima):
		return

	_valores_objetivo = _perfiles[nuevo_clima].duplicate()

	if instantaneo or tiempo_transicion <= 0.01:
		_valores_actuales = _valores_objetivo.duplicate()
		_tiempo_restante_transicion = 0.0
		_aplicar_valores_a_escena()
	else:
		_duracion_transicion_actual = tiempo_transicion
		_tiempo_restante_transicion = tiempo_transicion

	clima_cambiado.emit(nuevo_clima, obtener_nombre_clima())


func _interpolar_valores(t: float) -> void:
	for clave in _valores_objetivo.keys():
		var v_origen = _valores_actuales[clave]
		var v_destino = _valores_objetivo[clave]

		if v_origen is float:
			_valores_actuales[clave] = lerpf(v_origen, v_destino, t)
		elif v_origen is Color:
			_valores_actuales[clave] = (v_origen as Color).lerp(v_destino, t)
		elif v_origen is Vector2:
			_valores_actuales[clave] = (v_origen as Vector2).lerp(v_destino, t)


func _aplicar_valores_a_escena() -> void:
	_obtener_material_cielo()

	# 1. Actualizar uniformes del shader de cielo
	if is_instance_valid(_mat_cielo):
		_mat_cielo.set_shader_parameter("cloud_coverage", _valores_actuales["cloud_coverage"])
		_mat_cielo.set_shader_parameter("cloud_feather", _valores_actuales["cloud_feather"])
		_mat_cielo.set_shader_parameter("cloud_color", _valores_actuales["cloud_color"])
		_mat_cielo.set_shader_parameter("cloud_shadow_color", _valores_actuales["cloud_shadow_color"])
		_mat_cielo.set_shader_parameter("sky_day", _valores_actuales["sky_day"])
		_mat_cielo.set_shader_parameter("horizon_day", _valores_actuales["horizon_day"])
		_mat_cielo.set_shader_parameter("wind_speed", _valores_actuales["wind_speed"])
		_mat_cielo.set_shader_parameter("sun_strength", _valores_actuales["sun_strength"])

	# 2. Niebla y ambiente en WorldEnvironment
	if is_instance_valid(world_environment) and world_environment.environment:
		var env = world_environment.environment
		env.fog_enabled = true
		env.fog_density = _valores_actuales["niebla_densidad"]
		env.fog_light_color = _valores_actuales["niebla_color"]
		env.ambient_light_color = _valores_actuales["niebla_color"].lerp(Color.WHITE, 0.15)

	# 3. Factor de lluvia en partículas y emisión de señal
	var lluvia_fac: float = _valores_actuales.get("intensidad_lluvia", 0.0)
	if is_instance_valid(particulas_lluvia):
		if lluvia_fac > 0.01:
			particulas_lluvia.visible = true
			particulas_lluvia.emitting = true
			particulas_lluvia.amount_ratio = clampf(lluvia_fac, 0.05, 1.0)
		else:
			particulas_lluvia.emitting = false
			particulas_lluvia.visible = false

	factor_lluvia_actualizado.emit(lluvia_fac)

	# 4. Sincronizar gotas de lluvia con cromo y carrocería (usando caché en memoria)
	if not _mat_cromo_cache and ResourceLoader.exists("res://materiales/Vehiculos/cromo.tres"):
		_mat_cromo_cache = load("res://materiales/Vehiculos/cromo.tres") as ShaderMaterial
	if _mat_cromo_cache:
		_mat_cromo_cache.set_shader_parameter("nivel_lluvia", lluvia_fac)
	if not _mat_carroceria_cache and ResourceLoader.exists("res://modelos3d/vehiculos/materiales/carroceria.tres"):
		_mat_carroceria_cache = load("res://modelos3d/vehiculos/materiales/carroceria.tres") as ShaderMaterial
	if _mat_carroceria_cache:
		_mat_carroceria_cache.set_shader_parameter("nivel_lluvia", lluvia_fac)


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN AUTOMÁTICA DE COMPONENTES
# ═══════════════════════════════════════════════════════════════════════════════

func _obtener_material_cielo() -> void:
	if not _mat_cielo and is_instance_valid(world_environment) and world_environment.environment:
		if world_environment.environment.sky:
			_mat_cielo = world_environment.environment.sky.sky_material as ShaderMaterial


func _buscar_nodos_si_faltan() -> void:
	if not is_instance_valid(world_environment):
		world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
		if not world_environment and get_parent():
			world_environment = get_parent().find_child("WorldEnvironment", true, false) as WorldEnvironment

	if not is_instance_valid(luz_sol):
		luz_sol = get_node_or_null("SunLight") as DirectionalLight3D
		if not luz_sol and get_parent():
			luz_sol = get_parent().find_child("SunLight", true, false) as DirectionalLight3D


func _asegurar_particulas_lluvia() -> void:
	if not is_instance_valid(particulas_lluvia):
		particulas_lluvia = get_node_or_null("ParticulasLluvia") as GPUParticles3D

	if not is_instance_valid(particulas_lluvia):
		particulas_lluvia = GPUParticles3D.new()
		particulas_lluvia.name = "ParticulasLluvia"
		add_child(particulas_lluvia)
		if Engine.is_editor_hint():
			particulas_lluvia.owner = get_tree().edited_scene_root if get_tree() else null

	# Configurar el sistema de partículas optimizado para gotas de lluvia
	particulas_lluvia.amount = 2400
	particulas_lluvia.lifetime = 1.0
	particulas_lluvia.speed_scale = 1.6
	particulas_lluvia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particulas_lluvia.extra_cull_margin = 100.0

	# Material de proceso
	var mat_proc = ParticleProcessMaterial.new()
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_proc.emission_box_extents = Vector3(25.0, 1.0, 25.0)
	mat_proc.direction = Vector3(0.15, -1.0, 0.05)
	mat_proc.spread = 2.0
	mat_proc.initial_velocity_min = 26.0
	mat_proc.initial_velocity_max = 34.0
	mat_proc.color = Color(0.78, 0.85, 0.95, 0.35)
	particulas_lluvia.process_material = mat_proc

	# Malla alargada vertical para simular gotas / trazos de lluvia
	var quad = QuadMesh.new()
	quad.size = Vector2(0.04, 0.70)
	var mat_gotas = StandardMaterial3D.new()
	mat_gotas.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_gotas.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat_gotas.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_gotas.billboard_keep_scale = true
	quad.material = mat_gotas
	particulas_lluvia.draw_pass_1 = quad

	particulas_lluvia.emitting = false
	particulas_lluvia.visible = false


func _elegir_siguiente_clima_aleatorio() -> void:
	var opciones = [
		TipoClima.DESPEJADO,
		TipoClima.PARCIALMENTE_NUBLADO,
		TipoClima.NUBLADO,
		TipoClima.LLUVIA_LIGERA,
		TipoClima.TORMENTA
	]
	opciones.erase(clima_actual)
	var prox = opciones[randi() % opciones.size()]
	clima_actual = prox
