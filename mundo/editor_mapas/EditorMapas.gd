class_name EditorMapas
extends Node3D

## EditorMapas.gd — Controlador principal del Editor de Mapas estilo Cities: Skylines
## Integra Terreno 3D (Terrain3D), Carreteras (Road Generator), Edificios, Vegetación, Spawn y Modo Prueba.

@onready var camara_editor: CamaraEditor = $CamaraEditor
@onready var controlador_terreno: ControladorTerreno = $ControladorTerreno
@onready var controlador_carreteras: ControladorCarreteras = $ControladorCarreteras
@onready var controlador_objetos: ControladorObjetos = $ControladorObjetos
@onready var controlador_spawn: ControladorSpawn = $ControladorSpawn
@onready var modo_prueba: ModoPrueba = $ModoPrueba
@onready var ui_editor: UIEditorMapas = $UIEditorMapas

var controlador_equipamiento: ControladorEquipamientoVias = null

const ControladorAgua = preload("res://mundo/editor_mapas/ControladorAgua.gd")
const ControladorMuros = preload("res://mundo/editor_mapas/ControladorMuros.gd")
const ControladorEstacionamientos = preload("res://mundo/editor_mapas/ControladorEstacionamientos.gd")
const ControladorConcreto = preload("res://mundo/editor_mapas/ControladorConcreto.gd")
const ControladorZonificacion = preload("res://mundo/editor_mapas/ControladorZonificacion.gd")
var controlador_agua: ControladorAgua = null
var controlador_muros: ControladorMuros = null
var controlador_estacionamientos: ControladorEstacionamientos = null
var controlador_concreto: ControladorConcreto = null
var controlador_zonificacion: ControladorZonificacion = null
var _undo_redo: UndoRedo = UndoRedo.new()
var hora_actual_editor: int = 1
var controlador_sol_luna: ControladorSolLuna = null
var world_env_editor: WorldEnvironment = null # 0: Amanecer, 1: Mediodia, 2: Atardecer, 3: Noche
var _env_editor: Environment = null
var _env_prueba: Environment = null
var _sky_mat_editor: ProceduralSkyMaterial = null

var _categoria_activa: String = "terreno"
var _subherramienta_activa: String = "elevar"
var _puntero_presionado: bool = false
var _modo_camara_movil: String = ""
var _puntos_rio_temp: Array[Vector3] = []
var _pos_puntero_pantalla: Vector2 = Vector2.ZERO
var _pos_impacto_terreno: Vector3 = Vector3.ZERO
var _impacto_valido: bool = false
var _arrastrando_punto_carretera: bool = false
var _punto_carretera_fue_arrastrado: bool = false
var _arrastrando_esquina_parqueo: bool = false
var _esquina_parqueo_idx_est: int = -1
var _esquina_parqueo_idx_esq: int = -1
var _arrastrando_punto_concreto: bool = false
var _punto_concreto_idx_zona: int = -1
var _punto_concreto_idx_pto: int = -1
var _arrastrando_objeto: Node3D = null
var _objeto_fue_arrastrado: bool = false
var _eje_arrastre_objeto: Vector3 = Vector3.ZERO
var _pos_inicio_arrastre_eje: Vector3 = Vector3.ZERO
var _pos_terreno_inicio_arrastre: Vector3 = Vector3.ZERO
var _plano_arrastre_objeto: Plane = Plane(Vector3.UP, 0.0)
var _hit_inicio_arrastre: Vector3 = Vector3.ZERO
var _offset_arrastre_libre: Vector3 = Vector3.ZERO
var _modo_mover_objeto: bool = false
var _arrastrando_camara: bool = false
var _pos_toque_pantalla_anterior: Vector2 = Vector2.ZERO

func _ready() -> void:
	controlador_equipamiento = ControladorEquipamientoVias.new()
	controlador_equipamiento.name = "ControladorEquipamientoVias"
	add_child(controlador_equipamiento)

	if controlador_carreteras:
		if controlador_terreno:
			controlador_carreteras.controlador_terreno = controlador_terreno
		controlador_carreteras.equipamiento_controller = controlador_equipamiento
		controlador_equipamiento.road_container = controlador_carreteras.road_container
		controlador_equipamiento.controlador_carreteras = controlador_carreteras
	_conectar_senales_ui()
	_conectar_senales_prueba()
	_configurar_entorno_iluminacion()
	controlador_agua = ControladorAgua.new()
	controlador_agua.name = "ControladorAgua"
	controlador_agua.controlador_terreno = controlador_terreno
	add_child(controlador_agua)

	controlador_muros = ControladorMuros.new()
	controlador_muros.name = "ControladorMuros"
	controlador_muros.controlador_terreno = controlador_terreno
	add_child(controlador_muros)

	controlador_estacionamientos = ControladorEstacionamientos.new()
	controlador_estacionamientos.name = "ControladorEstacionamientos"
	controlador_estacionamientos.controlador_terreno = controlador_terreno
	controlador_estacionamientos.controlador_carreteras = controlador_carreteras
	add_child(controlador_estacionamientos)
	controlador_estacionamientos.estacionamiento_seleccionado_cambiado.connect(func(hay_sel: bool, datos: Dictionary):
		if ui_editor:
			ui_editor.actualizar_estado_parqueo_ui(hay_sel, datos)
	)

	controlador_concreto = ControladorConcreto.new()
	controlador_concreto.name = "ControladorConcreto"
	controlador_concreto.controlador_terreno = controlador_terreno
	add_child(controlador_concreto)
	controlador_concreto.zona_seleccionada_cambiada.connect(func(hay_sel: bool, datos: Dictionary):
		if ui_editor:
			ui_editor.actualizar_estado_concreto_ui(hay_sel, datos)
	)
	
	if controlador_objetos:
		controlador_objetos.controlador_terreno = controlador_terreno
		controlador_objetos.controlador_carreteras = controlador_carreteras

	controlador_zonificacion = ControladorZonificacion.new()
	controlador_zonificacion.name = "ControladorZonificacion"
	controlador_zonificacion.controlador_terreno = controlador_terreno
	controlador_zonificacion.controlador_carreteras = controlador_carreteras
	controlador_zonificacion.controlador_objetos = controlador_objetos
	add_child(controlador_zonificacion)

	if camara_editor and controlador_terreno:
		controlador_terreno.configurar_camara(camara_editor.obtener_camara())
	ui_editor.mostrar_notificacion("¡Bienvenido al Editor de Mapas Nuestra Tierra!")

func _configurar_entorno_iluminacion() -> void:
	# Eliminar SolEditor estático heredado de EditorMapas.tscn para que ControladorSolLuna controle la luz única
	var sol_legacy := find_child("SolEditor", true, false) as DirectionalLight3D
	if sol_legacy:
		sol_legacy.queue_free()

	# Configuración idéntica a Principal.tscn con ControladorSolLuna y Shader de Cielo
	world_env_editor = find_child("WorldEnvironment", true, false) as WorldEnvironment
	if not world_env_editor:
		world_env_editor = WorldEnvironment.new()
		world_env_editor.name = "WorldEnvironment"
		add_child(world_env_editor)

	# 1. Entorno ultrarrápido para el Editor de Mapas (máximos FPS, sin shader pesado de nubes)
	_sky_mat_editor = ProceduralSkyMaterial.new()
	_sky_mat_editor.sky_top_color = Color(0.20, 0.44, 0.76, 1.0)
	_sky_mat_editor.sky_horizon_color = Color(0.62, 0.76, 0.88, 1.0)
	_sky_mat_editor.ground_bottom_color = Color(0.16, 0.18, 0.20, 1.0)
	_sky_mat_editor.ground_horizon_color = Color(0.55, 0.62, 0.68, 1.0)
	_sky_mat_editor.sun_curve = 0.08

	var sky_editor := Sky.new()
	sky_editor.sky_material = _sky_mat_editor
	sky_editor.radiance_size = Sky.RADIANCE_SIZE_64
	sky_editor.process_mode = Sky.PROCESS_MODE_AUTOMATIC

	_env_editor = Environment.new()
	_env_editor.background_mode = Environment.BG_SKY
	_env_editor.sky = sky_editor
	_env_editor.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env_editor.ambient_light_color = Color(0.745, 0.813, 0.873, 1)
	_env_editor.ambient_light_energy = 0.35
	_env_editor.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env_editor.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env_editor.glow_enabled = false
	_env_editor.fog_enabled = false

	# 2. Entorno completo con cielo_sky.gdshader (solo se activa al probar el mapa)
	var env_p := Environment.new()
	env_p.background_mode = Environment.BG_SKY
	
	var sky_mat := ShaderMaterial.new()
	var sky_shader = load("res://shaders/cielo_sky.gdshader")
	if sky_shader:
		sky_mat.shader = sky_shader
		sky_mat.set_shader_parameter("sky_day", Color(0.18, 0.42, 0.74, 1))
		sky_mat.set_shader_parameter("horizon_day", Color(0.58, 0.72, 0.84, 1))
		sky_mat.set_shader_parameter("sky_sunset", Color(0.18, 0.22, 0.42, 1))
		sky_mat.set_shader_parameter("horizon_sunset", Color(0.92, 0.52, 0.22, 1))
		sky_mat.set_shader_parameter("sky_night", Color(0.03, 0.04, 0.08, 1))
		sky_mat.set_shader_parameter("horizon_night", Color(0.06, 0.08, 0.14, 1))
		sky_mat.set_shader_parameter("day_night_mix", 0.8)
		sky_mat.set_shader_parameter("use_directional_light", true)
		sky_mat.set_shader_parameter("horizon_exponent", 2.8)
		sky_mat.set_shader_parameter("sunset_amount_exponent", 0.4)
		sky_mat.set_shader_parameter("night_amount_exponent", 4.0)
		
		if ResourceLoader.exists("res://recursos/cielo/nubes/clouds_03.tres"):
			sky_mat.set_shader_parameter("cloud_tex_01", load("res://recursos/cielo/nubes/clouds_03.tres"))
		if ResourceLoader.exists("res://recursos/cielo/nubes/clouds_02.tres"):
			sky_mat.set_shader_parameter("cloud_tex_02", load("res://recursos/cielo/nubes/clouds_02.tres"))
		sky_mat.set_shader_parameter("cloud_color", Color(0.96, 0.97, 0.98, 1))
		sky_mat.set_shader_parameter("cloud_shadow_color", Color(0.52, 0.58, 0.68, 1))
		sky_mat.set_shader_parameter("cloud_tiling", Vector2(1, 1))
		sky_mat.set_shader_parameter("wind_speed", Vector2(0.35, 0.18))
		sky_mat.set_shader_parameter("cloud_coverage", 0.35)
		sky_mat.set_shader_parameter("cloud_feather", 0.22)
		sky_mat.set_shader_parameter("cloud_depth", 3.0)
		sky_mat.set_shader_parameter("cloud_occlude_exponent", 1.5)
		if ResourceLoader.exists("res://recursos/cielo/nubes/clouds_07.tres"):
			sky_mat.set_shader_parameter("night_noise_01", load("res://recursos/cielo/nubes/clouds_07.tres"))
		if ResourceLoader.exists("res://recursos/cielo/nubes/clouds_05.tres"):
			sky_mat.set_shader_parameter("night_noise_02", load("res://recursos/cielo/nubes/clouds_05.tres"))
		sky_mat.set_shader_parameter("sun_scale", 0.045)
		sky_mat.set_shader_parameter("sun_strength", 3.5)
		sky_mat.set_shader_parameter("sun_color", Color(1, 0.97, 0.88, 1))
		sky_mat.set_shader_parameter("moon_scale", 0.035)
		sky_mat.set_shader_parameter("moon_strength", 4.0)
		sky_mat.set_shader_parameter("moon_color", Color(0.65, 0.75, 0.95, 1))
	
	var sky_res := Sky.new()
	sky_res.sky_material = sky_mat
	sky_res.radiance_size = Sky.RADIANCE_SIZE_128
	sky_res.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	env_p.sky = sky_res
	env_p.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_p.ambient_light_color = Color(0.745, 0.813, 0.873, 1)
	env_p.ambient_light_energy = 0.35
	env_p.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env_p.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_p.glow_enabled = true
	env_p.glow_intensity = 0.08
	env_p.fog_enabled = true
	env_p.fog_light_color = Color(0.62, 0.74, 0.86, 1)
	env_p.fog_density = 0.00025
	env_p.fog_sky_affect = 0.0
	_env_prueba = env_p

	world_env_editor.environment = _env_editor
	
	controlador_sol_luna = find_child("ControladorSolLuna", true, false) as ControladorSolLuna
	if not controlador_sol_luna:
		controlador_sol_luna = ControladorSolLuna.new()
		controlador_sol_luna.name = "ControladorSolLuna"
		
		var sun := DirectionalLight3D.new()
		sun.name = "SunLight"
		sun.shadow_enabled = true
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 1.6
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 150.0
		controlador_sol_luna.add_child(sun)
		controlador_sol_luna.luz_sol = sun
		
		var moon := DirectionalLight3D.new()
		moon.name = "MoonLight"
		moon.light_color = Color(0.65, 0.78, 1.0)
		moon.shadow_bias = 0.03
		moon.directional_shadow_max_distance = 80.0
		controlador_sol_luna.add_child(moon)
		controlador_sol_luna.luz_luna = moon
		
		controlador_sol_luna.world_environment = world_env_editor
		controlador_sol_luna.azimut_sol = 41.0
		controlador_sol_luna.energia_maxima_sol = 1.34
		controlador_sol_luna.energia_maxima_luna = 0.34
		controlador_sol_luna.hora_actual = 11.5
		add_child(controlador_sol_luna)
	call_deferred("_cargar_mapa_inicial_hub")

# ── CONEXIÓN DE SEÑALES DE LA INTERFAZ ───────────────────────────────

var _senales_ui_conectadas: bool = false
var _senales_prueba_conectadas: bool = false
var _historial_vias_undo: Array = []
var _historial_vias_redo: Array = []
var _ruta_mapa_actual: String = "user://mapas/mapa_guardado.ntmap"
var _nombre_mapa_actual: String = "Mapa Guardado"

func _conectar_senales_ui() -> void:
	if _senales_ui_conectadas:
		return
	_senales_ui_conectadas = true
	ui_editor.categoria_cambiada.connect(_on_categoria_cambiada)
	ui_editor.subherramienta_seleccionada.connect(_on_subherramienta_seleccionada)
	ui_editor.radio_pincel_cambiado.connect(func(r): controlador_terreno.establecer_radio(r))
	ui_editor.fuerza_pincel_cambiada.connect(func(f): controlador_terreno.establecer_fuerza(f))
	if ui_editor.has_signal("perfil_pincel_cambiado"):
		ui_editor.perfil_pincel_cambiado.connect(func(p): controlador_terreno.establecer_perfil(p))
	if ui_editor.has_signal("altura_objetivo_terreno_cambiada"):
		ui_editor.altura_objetivo_terreno_cambiada.connect(func(h): controlador_terreno.establecer_altura_objetivo(h))
	if ui_editor.has_signal("material_pintura_cambiado"):
		ui_editor.material_pintura_cambiado.connect(func(mat_id): controlador_terreno.establecer_material_pintura(mat_id))
	if ui_editor.has_signal("follaje_pintura_cambiado"):
		ui_editor.follaje_pintura_cambiado.connect(func(fid): controlador_terreno.establecer_follaje_pintura(fid))
	if ui_editor.has_signal("densidad_follaje_cambiada"):
		ui_editor.densidad_follaje_cambiada.connect(func(d): controlador_terreno.establecer_densidad_follaje(d))
	if ui_editor.has_signal("escala_follaje_cambiada"):
		ui_editor.escala_follaje_cambiada.connect(func(e): controlador_terreno.establecer_escala_follaje(e))
	if ui_editor.has_signal("borrar_follaje_alternado"):
		ui_editor.borrar_follaje_alternado.connect(func(b): controlador_terreno.establecer_borrar_follaje(b))
	if ui_editor.has_signal("suavizado_borde_cambiado"):
		ui_editor.suavizado_borde_cambiado.connect(func(s): controlador_terreno.establecer_suavizado_borde(s))
	ui_editor.demolicion_alternada.connect(func(act):
		controlador_objetos.alternar_demolicion()
		controlador_objetos.actualizar_cursor_objeto(_pos_impacto_terreno, _impacto_valido and (_categoria_activa in ["ciudad", "vegetacion"]))
		ui_editor.actualizar_estado_boton_colocar(_categoria_activa, _subherramienta_activa, controlador_objetos.modo_demolicion)
	)
	ui_editor.rotar_objeto_solicitado.connect(_on_rotar_objeto_solicitado)
	ui_editor.snap_cuadricula_alternado.connect(func(act):
		controlador_objetos.snap_cuadricula_activo = act
	)
	ui_editor.accion_colocar_solicitada.connect(_ejecutar_accion_colocar)
	ui_editor.variacion_garaje_cambiada.connect(_on_variacion_garaje_cambiada)
	ui_editor.terminar_tramo_via_solicitado.connect(func():
		controlador_carreteras.finalizar_tramo_actual()
		ui_editor.mostrar_notificacion("Tramo de carretera finalizado.")
	)
	if ui_editor.has_signal("rotonda_salidas_cambiada"):
		ui_editor.rotonda_salidas_cambiada.connect(func(n_sal: int):
			controlador_carreteras.rotonda_salidas = clampi(n_sal, 3, 6)
			ui_editor.mostrar_notificacion("Rotonda de %d salidas seleccionada." % controlador_carreteras.rotonda_salidas)
		)
	if ui_editor.has_signal("seguir_carretera_desde_punto_solicitado"):
		ui_editor.seguir_carretera_desde_punto_solicitado.connect(_on_seguir_carretera_desde_punto)
	if ui_editor.has_signal("seleccionar_tramo_desde_punto_solicitado"):
		ui_editor.seleccionar_tramo_desde_punto_solicitado.connect(_on_seleccionar_tramo_desde_punto)
	if ui_editor.has_signal("umbral_altura_puente_cambiado"):
		ui_editor.umbral_altura_puente_cambiado.connect(func(v: float):
			controlador_carreteras.umbral_altura_puente = v
		)
	ui_editor.conectar_vias_solicitado.connect(_on_conectar_vias_solicitado)
	ui_editor.deshacer_punto_via_solicitado.connect(_deshacer_accion)
	ui_editor.rehacer_solicitado.connect(_rehacer_accion)
	ui_editor.hora_dia_cambiada.connect(_cambiar_hora_dia)
	ui_editor.modo_dispersion_vegetacion_alternado.connect(func(act):
		controlador_objetos.alternar_modo_dispersion(act)
		ui_editor.mostrar_notificacion("Pincel de dispersión: " + ("ACTIVADO" if act else "DESACTIVADO"))
	)
	ui_editor.radio_dispersion_vegetacion_cambiado.connect(func(r):
		controlador_objetos.establecer_radio_dispersion(r)
	)
	ui_editor.densidad_dispersion_vegetacion_cambiada.connect(func(d):
		controlador_objetos.establecer_densidad_dispersion(d)
	)
	ui_editor.borrar_dispersion_vegetacion_solicitado.connect(func():
		var borradas = controlador_objetos.borrar_vegetacion_en_radio(_pos_impacto_terreno, controlador_objetos.radio_pincel_dispersion)
		ui_editor.mostrar_notificacion("Borrados %d árboles en radio." % borradas)
	)
	ui_editor.snap_cuadricula_alternado.connect(func(act):
		controlador_objetos.snap_cuadricula_activo = act
		ui_editor.mostrar_notificacion("Snap a cuadrícula: " + ("ACTIVADO" if act else "DESACTIVADO"))
	)
	ui_editor.nivelar_terreno_vias_solicitado.connect(func():
		controlador_carreteras.nivelar_terreno_bajo_carreteras()
		ui_editor.mostrar_notificacion("Terreno nivelado bajo carreteras.")
	)
	if ui_editor.has_signal("auto_nivelar_vias_alternado"):
		ui_editor.auto_nivelar_vias_alternado.connect(func(act):
			controlador_carreteras.auto_nivelar_al_trazar = act
		)
	if ui_editor.has_signal("preset_equipamiento_solicitado"):
		ui_editor.preset_equipamiento_solicitado.connect(func(pid):
			var res: Dictionary = controlador_equipamiento.aplicar_preset_via(pid)
			ui_editor.mostrar_notificacion(str(res.get("mensaje", "")))
		)
	if ui_editor.has_signal("tramo_cambiar_tipo_via_solicitado"):
		ui_editor.tramo_cambiar_tipo_via_solicitado.connect(func(nuevo_tipo: int):
			if controlador_equipamiento and not controlador_equipamiento.tramo_segmentos.is_empty():
				_guardar_snapshot_vias()
				controlador_carreteras.cambiar_tipo_via_segmentos(controlador_equipamiento.tramo_segmentos, nuevo_tipo)
				ui_editor.mostrar_panel_equipamiento_vias(controlador_equipamiento.obtener_datos_tramo_seleccionado())
				ui_editor.mostrar_notificacion("Tipo de vía actualizado en el tramo.")
		)
	if ui_editor.has_signal("tramo_estilo_cambiado"):
		ui_editor.tramo_estilo_cambiado.connect(func(sup: int, dem: int):
			if controlador_equipamiento and not controlador_equipamiento.tramo_segmentos.is_empty():
				controlador_carreteras.aplicar_estilo_segmentos(controlador_equipamiento.tramo_segmentos, sup, dem)
				ui_editor.mostrar_notificacion("Superficie / demarcación aplicada al tramo.")
		)
	if ui_editor.has_signal("tramo_limpiar_equipamiento_solicitado"):
		ui_editor.tramo_limpiar_equipamiento_solicitado.connect(func():
			if controlador_equipamiento and not controlador_equipamiento.tramo_segmentos.is_empty():
				controlador_equipamiento.limpiar_equipamiento_segmentos(controlador_equipamiento.tramo_segmentos)
				ui_editor.mostrar_notificacion("Equipamiento del tramo limpiado.")
		)
	if ui_editor.has_signal("equipamiento_ojos_gato_solicitado"):
		ui_editor.equipamiento_ojos_gato_solicitado.connect(func(lado_idx: int):
			if controlador_equipamiento and not controlador_equipamiento.tramo_segmentos.is_empty():
				var lado := clampi(lado_idx, 0, 2) as ControladorEquipamientoVias.LadoEquipamiento
				controlador_equipamiento.aplicar_ojos_de_gato(controlador_equipamiento.tramo_segmentos, lado)
				ui_editor.mostrar_notificacion("Tachas reflectivas (ojos de gato) aplicadas.")
		)
	if controlador_carreteras.has_signal("telemetria_trazo_actualizada"):
		controlador_carreteras.telemetria_trazo_actualizada.connect(func(activa, dist, pend):
			if _categoria_activa == "vias":
				ui_editor.actualizar_telemetria_trazo_via(activa, dist, pend)
		)
	ui_editor.alternar_modo_spawn_solicitado.connect(func():
		var nuevo_m = controlador_spawn.alternar_modo()
		ui_editor.mostrar_notificacion("Modo de spawn cambiado a: " + nuevo_m.to_upper())
	)
	ui_editor.guardar_mapa_solicitado.connect(guardar_mapa)
	ui_editor.cargar_mapa_solicitado.connect(cargar_mapa)
	ui_editor.iniciar_prueba_solicitado.connect(_on_iniciar_prueba)
	
	# Señales de edición procedural de cruces
	ui_editor.cruce_radio_cambiado.connect(func(r):
		controlador_carreteras.modificar_radio_cruce(r)
	)
	ui_editor.cruce_rotacion_cambiada.connect(func(ang):
		controlador_carreteras.rotar_cruce_seleccionado(ang)
	)
	ui_editor.cruce_rotar_rapido_solicitado.connect(func(delta):
		controlador_carreteras.rotar_cruce_seleccionado_delta(delta)
		if controlador_carreteras.cruce_seleccionado:
			var d = controlador_carreteras.obtener_datos_cruce_seleccionado()
			var dr = controlador_carreteras.obtener_datos_ramales_cruce()
			ui_editor.actualizar_datos_panel_cruce(d)
			ui_editor.actualizar_seccion_ramales(dr)
	)
	ui_editor.cruce_ramal_seleccionado.connect(func(indice: int):
		controlador_carreteras.seleccionar_ramal_por_indice(indice)
		var dr = controlador_carreteras.obtener_datos_ramales_cruce()
		ui_editor.actualizar_seccion_ramales(dr)
		if controlador_carreteras.ramal_cruce_seleccionado:
			var tipo = controlador_carreteras._obtener_tipo_via_de_punto(controlador_carreteras.ramal_cruce_seleccionado)
			ui_editor._seleccionar_boton_tipo_via(tipo)
			ui_editor.mostrar_notificacion("Salida %d seleccionada." % (indice + 1))
		else:
			var tipo_gen = controlador_carreteras._obtener_tipo_via_de_puntos(controlador_carreteras.cruce_seleccionado.edge_points)
			ui_editor._seleccionar_boton_tipo_via(tipo_gen)
			ui_editor.mostrar_notificacion("Modificando todas las salidas.")
	)
	ui_editor.cruce_tipo_via_cambiado.connect(func(tipo):
		controlador_carreteras.cambiar_tipo_via_ramal_seleccionado_o_todos(tipo)
		if controlador_carreteras.cruce_seleccionado:
			var d = controlador_carreteras.obtener_datos_cruce_seleccionado()
			var dr = controlador_carreteras.obtener_datos_ramales_cruce()
			ui_editor.actualizar_datos_panel_cruce(d)
			ui_editor.actualizar_seccion_ramales(dr)
			var nom_tipo = "2 Vías" if tipo == 0 else ("4 Vías" if tipo == 1 else ("6 Vías" if tipo == 2 else "Trocha Rural"))
			if controlador_carreteras.ramal_cruce_seleccionado:
				ui_editor.mostrar_notificacion("Salida ajustada a %s" % nom_tipo)
			else:
				ui_editor.mostrar_notificacion("Todas las salidas ajustadas a %s" % nom_tipo)
	)
	ui_editor.cruce_num_brazos_cambiado.connect(func(num):
		controlador_carreteras.cambiar_configuracion_brazos_cruce(num)
		if controlador_carreteras.cruce_seleccionado:
			var d = controlador_carreteras.obtener_datos_cruce_seleccionado()
			var dr = controlador_carreteras.obtener_datos_ramales_cruce()
			ui_editor.actualizar_datos_panel_cruce(d)
			ui_editor.actualizar_seccion_ramales(dr)
	)
	ui_editor.cruce_aplanar_alternado.connect(func(activo):
		controlador_carreteras.cambiar_aplanar_cruce(activo)
	)
	ui_editor.cruce_eliminar_solicitado.connect(func():
		controlador_carreteras.eliminar_cruce_seleccionado()
		ui_editor.ocultar_panel_edicion_cruce()
		ui_editor.mostrar_notificacion("Cruce eliminado.")
	)
	ui_editor.cruce_edicion_cerrada.connect(func():
		controlador_carreteras.deseleccionar_cruce()
	)
	
	# Señales de edición de puntos de vía (Modificar Vías)
	ui_editor.punto_via_eliminado_solicitado.connect(func():
		var ok = controlador_carreteras.eliminar_punto_carretera_seleccionado()
		ui_editor.ocultar_panel_edicion_punto_via()
		if ok:
			ui_editor.mostrar_notificacion("Punto de vía eliminado.")
	)
	ui_editor.punto_via_tipo_cambiado.connect(func(tipo):
		controlador_carreteras.cambiar_tipo_via_punto_seleccionado(tipo)
		ui_editor.mostrar_notificacion("Tipo de vía actualizado.")
	)
	ui_editor.adaptar_terreno_tramo_solicitado.connect(func():
		var segs: Array = []
		if controlador_equipamiento and not controlador_equipamiento.tramo_segmentos.is_empty():
			segs = controlador_equipamiento.tramo_segmentos
		elif controlador_carreteras.punto_carretera_seleccionado:
			segs = controlador_carreteras.obtener_segmentos_de_punto(controlador_carreteras.punto_carretera_seleccionado)
		if segs.is_empty():
			ui_editor.mostrar_notificacion("⚠️ Selecciona un punto o tramo de vía primero para adaptar el terreno.")
			return
		var ok = controlador_carreteras.adaptar_terreno_en_tramo(segs)
		if ok:
			ui_editor.mostrar_notificacion("¡Terreno adaptado y nivelado perfectamente bajo el tramo seleccionado!")
		else:
			ui_editor.mostrar_notificacion("El terreno ya se encuentra adaptado al rasante de la vía.")
	)
	ui_editor.punto_via_altura_cambiada.connect(func(alt):
		controlador_carreteras.establecer_altura_punto_seleccionado(alt)
		ui_editor.mostrar_notificacion("Altura rasante: %+.1fm (Pilares/Túnel automáticos)" % alt)
	)
	ui_editor.punto_via_peralte_cambiado.connect(func(grados):
		controlador_carreteras.fijar_peralte_punto_seleccionado(grados)
	)
	ui_editor.punto_via_edicion_cerrada.connect(func():
		controlador_carreteras.deseleccionar_punto_carretera()
	)
	controlador_carreteras.carretera_actualizada.connect(func():
		if controlador_equipamiento:
			controlador_equipamiento.actualizar_puentes_y_tuneles_automaticos()
	)
	
	# Señales de equipamiento vial (Aceras, Bermas, Barreras, etc.)
	ui_editor.equipamiento_tipo_cambiado.connect(func(tipo):
		controlador_equipamiento.tipo_equipamiento_actual = tipo as ControladorEquipamientoVias.TipoEquipamiento
	)
	if ui_editor.has_signal("equipamiento_tipo_senal_cambiado"):
		ui_editor.equipamiento_tipo_senal_cambiado.connect(func(ts: int):
			controlador_equipamiento.tipo_senal_actual = ts
		)
	ui_editor.equipamiento_lado_cambiado.connect(func(lado):
		controlador_equipamiento.lado_actual = lado as ControladorEquipamientoVias.LadoEquipamiento
	)
	ui_editor.equipamiento_ancho_cambiado.connect(func(ancho):
		controlador_equipamiento.ancho_actual = ancho
	)
	ui_editor.equipamiento_tipo_acera_cambiado.connect(func(tipo_acera):
		controlador_equipamiento.tipo_acera_actual = tipo_acera as ControladorEquipamientoVias.TipoAcera
	)
	ui_editor.equipamiento_modo_arboles_cambiado.connect(func(modo):
		controlador_equipamiento.modo_distribucion_arboles = modo as ControladorEquipamientoVias.ModoDistribucionArboles
	)
	ui_editor.equipamiento_arboles_seleccionados_cambiados.connect(func(arboles):
		controlador_equipamiento.arboles_seleccionados.clear()
		for a in arboles:
			controlador_equipamiento.arboles_seleccionados.append(str(a))
	)
	ui_editor.equipamiento_aplicar_solicitado.connect(func():
		var res = controlador_equipamiento.aplicar_equipamiento_actual()
		ui_editor.mostrar_notificacion(res.get("mensaje", "Equipamiento aplicado"))
		if res.get("exito", false):
			controlador_carreteras.nivelar_terreno_bajo_carreteras()
	)
	ui_editor.equipamiento_limpiar_solicitado.connect(func():
		var res = controlador_equipamiento.limpiar_equipamiento_tramo()
		ui_editor.mostrar_notificacion(res.get("mensaje", "Equipamiento removido"))
	)
	ui_editor.equipamiento_cancelar_solicitado.connect(func():
		controlador_equipamiento.limpiar_seleccion_tramo()
		ui_editor.mostrar_notificacion("Selección de tramo cancelada.")
	)
	controlador_equipamiento.tramo_seleccionado_cambiado.connect(func(_hay_tramo, datos):
		if _subherramienta_activa == "equipamiento_vias":
			ui_editor.mostrar_panel_equipamiento_vias(datos)
		else:
			ui_editor.actualizar_datos_panel_equipamiento(datos)
		var hay_snap = (controlador_carreteras.punto_snap_detectado != null)
		var origen_fijado = (controlador_carreteras._punto_origen_conexion != null)
		ui_editor.actualizar_estado_boton_colocar(_categoria_activa, _subherramienta_activa, false, hay_snap, origen_fijado)
	)
	
	# Señales de edición contextual de objetos (Casas, Edificios, Vegetación)
	ui_editor.objeto_rotacion_delta.connect(func(delta_ang):
		var nuevo_ang = controlador_objetos.rotar_objeto_seleccionado(delta_ang)
		ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
	)
	ui_editor.objeto_rotacion_fijada.connect(func(ang):
		controlador_objetos.establecer_rotacion_objeto_seleccionado(ang)
		ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
	)
	ui_editor.objeto_inclinacion_fijada.connect(func(ang):
		controlador_objetos.establecer_inclinacion_objeto_seleccionado(ang)
		ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
	)
	ui_editor.objeto_altura_delta.connect(func(delta_h):
		controlador_objetos.modificar_altura_objeto_seleccionado(delta_h)
		ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
	)
	ui_editor.objeto_altura_reset.connect(func():
		controlador_objetos.establecer_altura_offset_seleccionado(0.0)
		ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
	)
	ui_editor.objeto_eliminar_solicitado.connect(func():
		controlador_objetos.eliminar_objeto_seleccionado()
		ui_editor.mostrar_notificacion("Objeto eliminado.")
	)
	ui_editor.objeto_reemplazar_solicitado.connect(func():
		var nuevo = controlador_objetos.reemplazar_objeto_seleccionado()
		if nuevo:
			ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
			var nombre = nuevo.get_meta("id_modelo", "objeto").capitalize()
			ui_editor.mostrar_notificacion("Objeto reemplazado por: %s" % nombre)
	)
	ui_editor.objeto_mover_alternado.connect(func(activo):
		_modo_mover_objeto = activo
		if activo:
			ui_editor.mostrar_notificacion("Toca el terreno para mover el objeto a esa posición.")
	)
	ui_editor.objeto_edicion_cerrada.connect(func():
		controlador_objetos.deseleccionar_objeto()
		ui_editor.ocultar_panel_edicion_objeto()
		_modo_mover_objeto = false
	)
	ui_editor.disenador_casa_solicitado.connect(func(editar_sel: bool):
		_abrir_disenador_casa_modular(editar_sel)
	)
	
	# Navegación móvil de cámara
	ui_editor.camara_pan_solicitado.connect(func(dir): camara_editor.panear_direccion(dir))
	ui_editor.camara_zoom_solicitado.connect(func(f): camara_editor.zoom(f))
	ui_editor.camara_orbita_solicitada.connect(func(g): camara_editor.rotar_orbita(g))
	ui_editor.camara_cenital_solicitada.connect(func(): camara_editor.alternar_cenital())
	ui_editor.centrar_camara_seleccion_solicitado.connect(_on_centrar_camara_seleccion)
	ui_editor.listo_seleccion_solicitado.connect(_on_listo_seleccion)
	ui_editor.modo_camara_movil_cambiado.connect(func(modo: String):
		_modo_camara_movil = modo
		_puntero_presionado = false
		_arrastrando_camara = false
		if controlador_terreno:
			controlador_terreno.finalizar_trazo()
		_actualizar_visibilidad_cursores()
		if modo == "":
			ui_editor.mostrar_notificacion("🖌️ Modo Pincel / Edición activo")
		elif modo == "seleccionar":
			ui_editor.mostrar_notificacion("🎯 Modo Seleccionar activo (toca cualquier objeto)")
		else:
			var nom_modo := "Mover cámara" if modo == "mover" else ("Rotar cámara" if modo == "orbitar" else "Zoom cámara")
			ui_editor.mostrar_notificacion("📷 %s activo (arrastra en pantalla)" % nom_modo)
	)

	# Señales de Muros Modulares
	ui_editor.muro_tipo_cambiado.connect(func(id_m):
		if controlador_muros:
			controlador_muros.establecer_tipo_muro(id_m)
			ui_editor.mostrar_notificacion("Muro activo: %s" % id_m.replace("_", " ").capitalize())
	)
	ui_editor.muro_escala_altura_cambiada.connect(func(esc):
		if controlador_muros:
			controlador_muros.establecer_escala_altura(esc)
	)
	ui_editor.muro_finalizar_tramo_solicitado.connect(func():
		if _categoria_activa == "parqueo" and controlador_estacionamientos:
			if controlador_estacionamientos.finalizar_edicion_actual():
				ui_editor.mostrar_notificacion("✓ Estacionamiento finalizado. Tócalo para ver opciones.")
		elif _categoria_activa == "concreto" and controlador_concreto:
			if controlador_concreto.finalizar_edicion_actual():
				ui_editor.mostrar_notificacion("✓ Concreto finalizado. Tócalo para editar puntos o acabado.")
		elif _categoria_activa == "agua" and controlador_agua:
			if controlador_agua.finalizar_tramo_rio():
				ui_editor.mostrar_notificacion("✓ Río finalizado")
		elif controlador_muros:
			controlador_muros.finalizar_tramo_actual()
			ui_editor.mostrar_notificacion("Tramo de muro finalizado")
	)
	ui_editor.muro_deshacer_solicitado.connect(func():
		if controlador_muros and controlador_muros.deshacer_ultimo_punto():
			ui_editor.mostrar_notificacion("Ultimo punto de muro deshecho")
	)
	ui_editor.muro_borrar_solicitado.connect(func():
		if controlador_muros and _impacto_valido:
			if controlador_muros.borrar_muro_en_posicion(_pos_impacto_terreno):
				ui_editor.mostrar_notificacion("Tramo de muro eliminado")
			else:
				ui_editor.mostrar_notificacion("Acerca el cursor al muro que deseas borrar")
	)

	# Señales de Estacionamientos Procedurales
	ui_editor.parqueo_tipo_cambiado.connect(func(tipo: int):
		if controlador_estacionamientos:
			controlador_estacionamientos.establecer_tipo_seleccionado(tipo)
	)
	ui_editor.parqueo_color_lineas_cambiado.connect(func(color_idx: int):
		if controlador_estacionamientos:
			controlador_estacionamientos.establecer_color_lineas_seleccionado(color_idx)
	)
	ui_editor.parqueo_iluminacion_cambiada.connect(func(activa: bool):
		if controlador_estacionamientos:
			controlador_estacionamientos.establecer_iluminacion_seleccionado(activa)
	)
	ui_editor.parqueo_arbolado_cambiado.connect(func(activo: bool):
		if controlador_estacionamientos:
			controlador_estacionamientos.establecer_arbolado_seleccionado(activo)
	)
	ui_editor.parqueo_finalizar_solicitado.connect(func():
		if controlador_estacionamientos and controlador_estacionamientos.finalizar_edicion_actual():
			ui_editor.mostrar_notificacion("✓ Estacionamiento finalizado. Tócalo para editar o unir con carretera.")
	)
	ui_editor.parqueo_editar_esquinas_solicitado.connect(func():
		if controlador_estacionamientos and controlador_estacionamientos.activar_edicion_esquinas_seleccionado():
			ui_editor.mostrar_notificacion("Modo edición de esquinas activado.")
	)
	ui_editor.parqueo_unir_carretera_solicitado.connect(func():
		if controlador_estacionamientos:
			var res_u := controlador_estacionamientos.unir_salida_con_carretera_mas_cercana()
			ui_editor.mostrar_notificacion(str(res_u.get("mensaje", "")))
	)
	ui_editor.parqueo_nivelar_solicitado.connect(func():
		if controlador_estacionamientos:
			if controlador_estacionamientos.nivelar_terreno_seleccionado():
				ui_editor.mostrar_notificacion("✓ Terreno nivelado bajo el estacionamiento")
			else:
				ui_editor.mostrar_notificacion("Selecciona primero un estacionamiento")
	)
	ui_editor.parqueo_eliminar_solicitado.connect(func():
		if controlador_estacionamientos:
			if controlador_estacionamientos.eliminar_seleccionado():
				ui_editor.mostrar_notificacion("Estacionamiento eliminado")
			else:
				ui_editor.mostrar_notificacion("Selecciona primero un estacionamiento")
	)
	ui_editor.parqueo_rotacion_cambiada.connect(func(ang: float):
		if controlador_estacionamientos:
			controlador_estacionamientos.establecer_rotacion_seleccionado(ang)
	)
	ui_editor.parqueo_rotacion_delta_solicitada.connect(func(delta: float):
		if controlador_estacionamientos:
			var nuevo_ang := controlador_estacionamientos.rotar_seleccionado(delta)
			ui_editor.actualizar_rotacion_parqueo_ui(nuevo_ang)
			ui_editor.mostrar_notificacion("Parqueo rotado a %d°" % int(round(nuevo_ang)))
	)
	ui_editor.parqueo_adaptar_terreno_cambiado.connect(func(activo: bool):
		if controlador_estacionamientos:
			controlador_estacionamientos.establecer_adaptar_terreno(activo)
			ui_editor.mostrar_notificacion("✓ Terreno se adapta al parqueo" if activo else "✓ Parqueo se adapta al terreno")
	)
	ui_editor.concreto_acabado_cambiado.connect(func(acabado: int):
		if controlador_concreto:
			controlador_concreto.establecer_acabado_seleccionado(acabado)
	)
	ui_editor.concreto_altura_cambiada.connect(func(altura: float):
		if controlador_concreto:
			controlador_concreto.establecer_altura_losa_seleccionada(altura)
	)
	ui_editor.concreto_bordillo_cambiado.connect(func(activo: bool):
		if controlador_concreto:
			controlador_concreto.establecer_bordillo_seleccionado(activo)
	)
	ui_editor.concreto_adaptar_terreno_cambiado.connect(func(activo: bool):
		if controlador_concreto:
			controlador_concreto.establecer_adaptar_terreno(activo)
			ui_editor.mostrar_notificacion("✓ Terreno se adapta al concreto" if activo else "✓ Puntos de concreto adaptados al terreno")
	)
	ui_editor.concreto_agregar_punto_solicitado.connect(func():
		if controlador_concreto and controlador_concreto.agregar_punto_en_borde_seleccionado():
			ui_editor.mostrar_notificacion("✓ Punto agregado al concreto")
	)
	ui_editor.concreto_subdividir_solicitado.connect(func():
		if controlador_concreto and controlador_concreto.subdividir_bordes_seleccionado():
			ui_editor.mostrar_notificacion("✓ Puntos de edición duplicados")
	)
	ui_editor.concreto_eliminar_punto_solicitado.connect(func():
		if controlador_concreto:
			if controlador_concreto.eliminar_punto_seleccionado():
				ui_editor.mostrar_notificacion("Punto eliminado")
			else:
				ui_editor.mostrar_notificacion("Mínimo 3 puntos requeridos")
	)
	ui_editor.concreto_finalizar_solicitado.connect(func():
		if controlador_concreto and controlador_concreto.finalizar_edicion_actual():
			ui_editor.mostrar_notificacion("✓ Suelo de concreto finalizado")
	)
	ui_editor.concreto_editar_puntos_solicitado.connect(func():
		if controlador_concreto and controlador_concreto.activar_edicion_puntos_seleccionado():
			ui_editor.mostrar_notificacion("Modo edición de puntos activado")
	)
	ui_editor.concreto_nivelar_solicitado.connect(func():
		if controlador_concreto and controlador_concreto.nivelar_terreno_seleccionado():
			ui_editor.mostrar_notificacion("✓ Terreno nivelado bajo el concreto")
		else:
			ui_editor.mostrar_notificacion("Selecciona primero una zona de concreto")
	)
	ui_editor.concreto_eliminar_solicitado.connect(func():
		if controlador_concreto and controlador_concreto.eliminar_seleccionado():
			ui_editor.mostrar_notificacion("Zona de concreto eliminada")
	)
	ui_editor.concreto_rotacion_delta_solicitada.connect(func(delta: float):
		if controlador_concreto:
			var ang_c := controlador_concreto.rotar_seleccionado(delta)
			ui_editor.mostrar_notificacion("Concreto rotado a %d°" % int(round(ang_c)))
	)
	ui_editor.agua_rio_limpiar_solicitado.connect(func():
		if controlador_agua:
			controlador_agua.limpiar_trazo_rio()
	)
	ui_editor.agua_rio_finalizar_solicitado.connect(func():
		if controlador_agua:
			if controlador_agua.finalizar_tramo_rio():
				ui_editor.mostrar_notificacion("✓ Tramo de río finalizado")
			else:
				ui_editor.mostrar_notificacion("Agrega al menos 2 puntos en el terreno para crear un río")
	)
	ui_editor.agua_nivel_delta_solicitado.connect(func(delta_y: float):
		if controlador_agua:
			if is_instance_valid(controlador_agua.cuerpo_seleccionado):
				var ny := controlador_agua.modificar_nivel_agua(delta_y)
				ui_editor.mostrar_notificacion("Nivel de agua: %.2f m" % ny)
			else:
				ui_editor.mostrar_notificacion("Toca primero un lago o río en el mapa para seleccionarlo")
	)
	ui_editor.agua_limpiar_todo_solicitado.connect(func():
		if controlador_agua:
			controlador_agua.limpiar_todo_agua()
			ui_editor.mostrar_notificacion("Toda el agua ha sido eliminada del mapa")
	)
	ui_editor.info_vista_cambiada.connect(func(modo: int):
		if controlador_terreno:
			controlador_terreno.establecer_info_vista(modo)
	)
	ui_editor.via_snap_angulo_cambiado.connect(func(act: bool):
		if controlador_carreteras:
			controlador_carreteras.snap_angulo_activo = act
	)
	ui_editor.via_elevacion_paso_solicitada.connect(func(delta_m: float):
		if controlador_carreteras:
			var ny := controlador_carreteras.cambiar_elevacion_paso(delta_m)
			ui_editor.mostrar_notificacion("Elevación de vía: %+.1f m" % ny)
	)
	ui_editor.via_elevacion_reset_solicitada.connect(func():
		if controlador_carreteras:
			controlador_carreteras.resetear_elevacion()
			ui_editor.mostrar_notificacion("Elevación de vía restablecida a 0.0 m (a ras de suelo)")
	)
	ui_editor.via_mejorar_alternado.connect(func(act: bool):
		if controlador_carreteras:
			controlador_carreteras.modo_mejorar_via = act
			ui_editor.mostrar_notificacion("Modo Mejorar Vía: toca un tramo para actualizarlo" if act else "Modo Mejorar Vía desactivado")
	)
	ui_editor.cruce_control_trafico_cambiado.connect(func(modo: String):
		if controlador_carreteras:
			controlador_carreteras.establecer_control_cruce_seleccionado(modo)
			ui_editor.mostrar_panel_edicion_cruce(controlador_carreteras.obtener_datos_cruce_seleccionado())
			ui_editor.mostrar_notificacion("Control de cruce: " + modo.capitalize())
	)
	ui_editor.snap_via_ciudad_alternado.connect(func(act: bool):
		if controlador_objetos:
			controlador_objetos.snap_carretera_activo = act
			ui_editor.mostrar_notificacion("Snap a borde de vía: " + ("ACTIVADO" if act else "DESACTIVADO"))
	)
	ui_editor.pipeta_solicitada.connect(_activar_pipeta_en_cursor)
	ui_editor.zona_tipo_cambiado.connect(func(tipo: int):
		if controlador_zonificacion:
			controlador_zonificacion.zona_activa = tipo
	)
	ui_editor.zona_desarrollar_solicitado.connect(func():
		if controlador_zonificacion:
			var n_creados := controlador_zonificacion.desarrollar_zonas()
			ui_editor.mostrar_notificacion("⚡ %d edificios desarrollados en las zonas" % n_creados)
	)
	ui_editor.zona_limpiar_solicitado.connect(func():
		if controlador_zonificacion:
			controlador_zonificacion.limpiar_todas()
			ui_editor.mostrar_notificacion("Zonificación limpiada")
	)
	ui_editor.zona_auto_construir_cambiado.connect(func(act: bool):
		if controlador_zonificacion:
			controlador_zonificacion.auto_construir_al_pintar = act
	)
	ui_editor.zona_radio_cambiado.connect(func(r: float):
		if controlador_zonificacion:
			controlador_zonificacion.radio_pincel = r
	)
	ui_editor.zona_filas_cambiado.connect(func(f: int):
		if controlador_zonificacion:
			controlador_zonificacion.filas_profundidad = f
			controlador_zonificacion.mostrar_grilla_disponible(_categoria_activa == "ciudad" and _subherramienta_activa == "zonificar")
	)
	ui_editor.auto_casas_radio_cambiado.connect(func(r: float):
		if controlador_objetos:
			controlador_objetos.radio_auto_casas = r
	)
	ui_editor.rehacer_solicitado.connect(_rehacer_accion)

func _on_listo_seleccion() -> void:
	_arrastrando_objeto = null
	_eje_arrastre_objeto = Vector3.ZERO
	_modo_mover_objeto = false
	if is_instance_valid(controlador_objetos.objeto_seleccionado):
		controlador_objetos.deseleccionar_objeto()
		ui_editor.ocultar_panel_edicion_objeto()
		ui_editor.mostrar_notificacion("✓ Edicion finalizada")
	elif is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
		controlador_carreteras.deseleccionar_punto_carretera()
		ui_editor.ocultar_panel_edicion_punto_via()
	elif is_instance_valid(controlador_carreteras.cruce_seleccionado):
		controlador_carreteras.deseleccionar_cruce()
		ui_editor.ocultar_panel_edicion_cruce()

func _on_centrar_camara_seleccion() -> void:
	if is_instance_valid(controlador_objetos.objeto_seleccionado):
		camara_editor.enfocar_punto(controlador_objetos.objeto_seleccionado.global_position, 28.0)
	elif is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
		camara_editor.enfocar_punto(controlador_carreteras.punto_carretera_seleccionado.global_position, 32.0)
	elif is_instance_valid(controlador_carreteras.cruce_seleccionado):
		camara_editor.enfocar_punto(controlador_carreteras.cruce_seleccionado.global_position, 42.0)
	elif _categoria_activa == "concreto" and controlador_concreto and controlador_concreto.indice_seleccionado >= 0:
		camara_editor.enfocar_punto(controlador_concreto.obtener_centro_seleccionado(), 34.0)
	elif _categoria_activa == "parqueo" and controlador_estacionamientos and controlador_estacionamientos.indice_seleccionado >= 0:
		camara_editor.enfocar_punto(controlador_estacionamientos.obtener_centro_seleccionado(), 38.0)

func _conectar_senales_prueba() -> void:
	if _senales_prueba_conectadas:
		return
	_senales_prueba_conectadas = true
	modo_prueba.prueba_finalizada.connect(_on_prueba_finalizada)

# ── CAMBIO DE CATEGORÍAS Y HERRAMIENTAS ──────────────────────────────

func _on_seguir_carretera_desde_punto() -> void:
	var rp: RoadPoint = controlador_carreteras.punto_carretera_seleccionado
	if not is_instance_valid(rp):
		return
	if not controlador_carreteras.continuar_trazo_desde_punto(rp):
		ui_editor.mostrar_notificacion("Este punto es intermedio (ya tiene 2 conexiones). Selecciona un extremo libre.")
		return
	var sub_via: String = "calle_2"
	match controlador_carreteras.tipo_via_actual:
		ControladorCarreteras.TipoVia.AVENIDA_4_VIAS:
			sub_via = "avenida_4"
		ControladorCarreteras.TipoVia.AUTOPISTA_6_VIAS:
			sub_via = "autopista_6"
		ControladorCarreteras.TipoVia.TROCHA:
			sub_via = "trocha"
		_:
			sub_via = "calle_2"
	_subherramienta_activa = sub_via
	controlador_carreteras.subherramienta_via_actual = sub_via
	ui_editor.actualizar_subherramienta_externa("vias", sub_via)
	ui_editor.mostrar_notificacion("Continuando carretera desde este punto. Toca para agregar más puntos.")

func _on_seleccionar_tramo_desde_punto() -> void:
	var rp: RoadPoint = controlador_carreteras.punto_carretera_seleccionado
	if not is_instance_valid(rp):
		return
	controlador_carreteras.deseleccionar_punto_carretera()
	controlador_carreteras.desactivar_modo_conexion()
	controlador_carreteras.finalizar_tramo_actual()
	_categoria_activa = "vias"
	_subherramienta_activa = "equipamiento_vias"
	controlador_carreteras.subherramienta_via_actual = "equipamiento_vias"
	ui_editor.actualizar_boton_modo_conectar(false)
	ui_editor.ocultar_panel_edicion_punto_via()
	ui_editor.mostrar_panel_equipamiento_vias({"paso": 1, "inicio": rp.name})
	controlador_equipamiento.fijar_punto_inicio(rp)
	ui_editor.mostrar_notificacion("Punto A fijado. Ahora toca el Punto B en la carretera para seleccionar el tramo.")

func _on_conectar_vias_solicitado() -> void:
	_categoria_activa = "vias"
	if controlador_carreteras.modo_conectar_activo:
		# Si ya está activo, desactivarlo (toggle off)
		controlador_carreteras.desactivar_modo_conexion()
		_subherramienta_activa = "calle_2"
		controlador_carreteras.subherramienta_via_actual = "calle_2"
		ui_editor.actualizar_boton_modo_conectar(false)
		ui_editor.resaltar_tarjeta("calle_2")
		ui_editor.actualizar_estado_boton_colocar(_categoria_activa, _subherramienta_activa, false, false, false)
		ui_editor.mostrar_notificacion("Modo Conectar Vías desactivado.")
	else:
		# Activar modo conectar vías
		_subherramienta_activa = "conectar_vias"
		controlador_carreteras.subherramienta_via_actual = "conectar_vias"
		controlador_carreteras.activar_modo_conexion()
		ui_editor.actualizar_boton_modo_conectar(true)
		ui_editor.resaltar_tarjeta("conectar_vias")
		ui_editor.actualizar_estado_boton_colocar(_categoria_activa, _subherramienta_activa, false, false, false)
		ui_editor.mostrar_notificacion("Modo Conectar Vías: Toca el primer extremo de vía a unir (pulsa '✕ CANCELAR' para salir)")

func _on_categoria_cambiada(cat: String) -> void:
	_categoria_activa = cat
	if cat != "ciudad" and cat != "vegetacion":
		controlador_objetos.deseleccionar_objeto()
		ui_editor.ocultar_panel_edicion_objeto()
		ui_editor.ocultar_panel_variaciones_garaje()
		_arrastrando_objeto = null
		_modo_mover_objeto = false
	if cat != "vias":
		if controlador_carreteras.modo_conectar_activo:
			controlador_carreteras.desactivar_modo_conexion()
			ui_editor.actualizar_boton_modo_conectar(false)
		if controlador_carreteras.cruce_seleccionado:
			controlador_carreteras.deseleccionar_cruce()
			ui_editor.ocultar_panel_edicion_cruce()
		if controlador_carreteras.punto_carretera_seleccionado:
			controlador_carreteras.deseleccionar_punto_carretera()
			ui_editor.ocultar_panel_edicion_punto_via()
		if controlador_equipamiento:
			controlador_equipamiento.limpiar_seleccion_tramo()
			ui_editor.ocultar_panel_equipamiento_vias()
	if cat != "muros" and controlador_muros:
		controlador_muros.finalizar_tramo_actual()
	if controlador_estacionamientos:
		controlador_estacionamientos.establecer_visibilidad_manejadores(cat == "parqueo")
	if controlador_concreto:
		controlador_concreto.establecer_visibilidad_manejadores(cat == "concreto")
	_actualizar_visibilidad_cursores()
	ui_editor.actualizar_estado_boton_colocar(_categoria_activa, _subherramienta_activa, controlador_objetos.modo_demolicion)

func _on_subherramienta_seleccionada(id_herramienta: String) -> void:
	_subherramienta_activa = id_herramienta
	
	if id_herramienta != "equipamiento_vias" and controlador_equipamiento and not controlador_equipamiento.tramo_segmentos.is_empty():
		controlador_equipamiento.limpiar_seleccion_tramo()
		ui_editor.ocultar_panel_equipamiento_vias()
	match _categoria_activa:
		"agua":
			if id_herramienta != "rio" and controlador_agua:
				controlador_agua.finalizar_tramo_rio()
		"ciudad":
			if id_herramienta == "demoler":
				controlador_objetos.modo_demolicion = true
				controlador_objetos.deseleccionar_objeto()
			elif id_herramienta in ["res", "com", "inst", "hist", "ind", "auto_casas", "zonificar"]:
				controlador_objetos.modo_demolicion = false
			else:
				controlador_objetos.seleccionar_objeto(id_herramienta)
				if id_herramienta in ["garaje_camiones", "garaje_doble", "garaje_terminal", "garaje_moderno"]:
					ui_editor.mostrar_panel_variaciones_garaje(id_herramienta)
				else:
					ui_editor.ocultar_panel_variaciones_garaje()
		"terreno":
			if id_herramienta.begins_with("pintar_"):
				controlador_terreno.establecer_material_pintura(id_herramienta.trim_prefix("pintar_"))
			else:
				match id_herramienta:
					"elevar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.ELEVAR)
					"bajar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.BAJAR)
					"aplanar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.APLANAR)
					"suavizar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.SUAVIZAR)
					"pendiente": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.PENDIENTE)
					"pintar", "cesped": controlador_terreno.establecer_material_pintura("cesped_verde")
					"tierra": controlador_terreno.establecer_material_pintura("tierra_fertil")
					"roca": controlador_terreno.establecer_material_pintura("roca_gris")
					"follaje": controlador_terreno.establecer_follaje_pintura(ui_editor._follaje_pintura_activo if ui_editor else "follaje_cesped_fino")
		"vias":
			controlador_carreteras.subherramienta_via_actual = id_herramienta
			match id_herramienta:
				"calle_2", "calle_2_vias":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.CALLE_2_VIAS
					ui_editor.actualizar_boton_modo_conectar(false)
				"avenida_4", "avenida_4_vias":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.AVENIDA_4_VIAS
					ui_editor.actualizar_boton_modo_conectar(false)
				"autopista_6", "autopista_6_vias":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.AUTOPISTA_6_VIAS
					ui_editor.actualizar_boton_modo_conectar(false)
				"trocha", "trocha_rural":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.TROCHA
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Trocha Rural seleccionada.")
				"calle_1":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.CALLE_1_CARRIL
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Calle 1 Carril seleccionada.")
				"nacional":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.CARRETERA_NACIONAL
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Carretera Nacional 2C seleccionada.")
				"doble_8":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.DOBLE_CALZADA_8C
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Autopista 8 Carriles seleccionada.")
				"adoquin":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.VIA_ADOQUINADA
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Vía Adoquinada seleccionada.")
				"recebo":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.VIA_RECEBO
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Vía Destapada / Recebo seleccionada.")
				"ciclovia":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.tipo_via_actual = ControladorCarreteras.TipoVia.CICLOVIA_PEATONAL
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Ciclovía / Sendero seleccionado.")
				"cruce_4":
					controlador_carreteras.desactivar_modo_conexion()
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Cruce 4 Vías seleccionado. Arrastra y pulsa COLOCAR.")
				"cruce_t":
					controlador_carreteras.desactivar_modo_conexion()
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Cruce en T seleccionado. Puedes rotarlo con '⟳ 45°'.")
				"conectar_vias":
					controlador_carreteras.activar_modo_conexion()
					ui_editor.actualizar_boton_modo_conectar(true)
					ui_editor.mostrar_notificacion("Modo Conectar Vías: Toca el primer extremo de vía a unir (o pulsa '✕ CANCELAR' para salir)")
				"modificar_vias":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.finalizar_tramo_actual()
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_notificacion("Modo Modificar Vías: Selecciona o arrastra cualquier punto para ajustar las carreteras.")
				"equipamiento_vias":
					controlador_carreteras.desactivar_modo_conexion()
					controlador_carreteras.finalizar_tramo_actual()
					ui_editor.actualizar_boton_modo_conectar(false)
					ui_editor.mostrar_panel_equipamiento_vias({"paso": 0})
					ui_editor.mostrar_notificacion("Modo Aceras y Bermas: Toca el punto donde INICIA el tramo.")
		"ciudad", "vegetacion":
			controlador_objetos.seleccionar_objeto(id_herramienta)
		"spawn":
			match id_herramienta:
				"spawn_vehiculo": controlador_spawn.establecer_modo("vehiculo")
				"spawn_peaton", "spawn_pie": controlador_spawn.establecer_modo("a_pie")
				
	var hay_snap = (controlador_carreteras.punto_snap_detectado != null)
	var origen_fijado = (controlador_carreteras._punto_origen_conexion != null)
	ui_editor.actualizar_estado_boton_colocar(_categoria_activa, _subherramienta_activa, controlador_objetos.modo_demolicion, hay_snap, origen_fijado)

func _on_rotar_objeto_solicitado() -> void:
	if _categoria_activa == "spawn":
		controlador_spawn.rotar_spawn(45.0)
		ui_editor.mostrar_notificacion("Spawn rotado 45°")
	elif _categoria_activa == "vias" and _subherramienta_activa in ["cruce_4", "cruce_t"]:
		var r = controlador_carreteras.rotar_cruce(45.0)
		ui_editor.mostrar_notificacion("Cruce rotado a %d°" % int(r))
	elif _categoria_activa == "parqueo" and controlador_estacionamientos:
		if controlador_estacionamientos.indice_seleccionado >= 0:
			var rp := controlador_estacionamientos.rotar_seleccionado(45.0)
			ui_editor.actualizar_rotacion_parqueo_ui(rp)
			ui_editor.mostrar_notificacion("Parqueo rotado a %d°" % int(round(rp)))
		else:
			var rc := controlador_estacionamientos.rotar_cursor(45.0)
			ui_editor.mostrar_notificacion("Orientación de parqueo: %d°" % int(round(rc)))
	elif _categoria_activa == "concreto" and controlador_concreto:
		if controlador_concreto.indice_seleccionado >= 0:
			var rc_z := controlador_concreto.rotar_seleccionado(45.0)
			ui_editor.mostrar_notificacion("Concreto rotado a %d°" % int(round(rc_z)))
		else:
			var rc_c := controlador_concreto.rotar_cursor(45.0)
			ui_editor.mostrar_notificacion("Orientación de concreto: %d°" % int(round(rc_c)))
	else:
		controlador_objetos.rotar_objeto(45.0)
		ui_editor.mostrar_notificacion("Objeto rotado 45°")

func _actualizar_visibilidad_cursores() -> void:
	var modo_pincel: bool = (_modo_camara_movil == "")
	var en_terreno = modo_pincel and (_categoria_activa == "terreno")
	var en_vias = modo_pincel and (_categoria_activa == "vias")
	var en_objetos = modo_pincel and (_categoria_activa in ["ciudad", "vegetacion"])
	var en_spawn = modo_pincel and (_categoria_activa == "spawn")
	
	controlador_terreno.actualizar_cursor(_pos_impacto_terreno, _impacto_valido and en_terreno)
	controlador_carreteras.actualizar_cursor_via(_pos_impacto_terreno, _impacto_valido and en_vias)
	controlador_objetos.modo_auto_casas = modo_pincel and (_categoria_activa == "ciudad" and _subherramienta_activa == "auto_casas")
	controlador_objetos.actualizar_cursor_objeto(_pos_impacto_terreno, _impacto_valido and en_objetos)
	if controlador_zonificacion:
		controlador_zonificacion.mostrar_grilla_disponible(modo_pincel and _categoria_activa == "ciudad" and _subherramienta_activa == "zonificar")
	if controlador_muros:
		controlador_muros.actualizar_cursor_muro(_pos_impacto_terreno, _impacto_valido and modo_pincel and (_categoria_activa == "muros"))
	if controlador_estacionamientos:
		var editando_parqueo := _arrastrando_esquina_parqueo or controlador_estacionamientos.esta_editando_puntos()
		var mostrar_cursor_parqueo := _impacto_valido and modo_pincel and (_categoria_activa == "parqueo") and (_subherramienta_activa == "parqueo_crear") and (not editando_parqueo)
		var tipo_p_cur: int = ui_editor._parqueo_tipo_sel if ui_editor else 0
		controlador_estacionamientos.actualizar_cursor_parqueo(_pos_impacto_terreno, mostrar_cursor_parqueo, tipo_p_cur)
	if controlador_concreto:
		var editando_concreto := _arrastrando_punto_concreto or controlador_concreto.esta_editando_puntos()
		var mostrar_cursor_concreto := _impacto_valido and modo_pincel and (_categoria_activa == "concreto") and (_subherramienta_activa == "concreto_crear") and (not editando_concreto)
		controlador_concreto.actualizar_cursor_concreto(_pos_impacto_terreno, mostrar_cursor_concreto)
	if controlador_agua:
		var r_cur_agua: float = ui_editor._radio_lago if ui_editor else 24.0
		if _subherramienta_activa == "rio":
			r_cur_agua = ui_editor._ancho_rio if ui_editor else 8.0
		controlador_agua.actualizar_cursor_agua(_pos_impacto_terreno, _impacto_valido and modo_pincel and (_categoria_activa == "agua"), _subherramienta_activa, r_cur_agua)
	controlador_spawn.actualizar_cursor_spawn(_pos_impacto_terreno, _impacto_valido and en_spawn)

# ── PROCESAMIENTO DE ENTRADA Y RAYCASTING AL MUNDO 3D ────────────────

func _unhandled_input(event: InputEvent) -> void:
	if modo_prueba.en_prueba:
		return
		
	# Manejar gestos táctiles multitouch de cámara (pinch zoom, dos dedos pan)
	if camara_editor.manejar_evento_pantalla(event):
		_puntero_presionado = false
		_arrastrando_camara = false
		if controlador_terreno:
			controlador_terreno.finalizar_trazo()
		return
		
	# Atajos de teclado en escritorio (Espacio / Enter para colocar, R para rotar, Ctrl+Z/Y, I, RePag/AvPag)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z:
			if event.shift_pressed:
				_rehacer_accion()
			else:
				_deshacer_accion()
			get_viewport().set_input_as_handled()
			return
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			_rehacer_accion()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_I:
			_activar_pipeta_en_cursor()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_PAGEUP and _categoria_activa == "vias" and controlador_carreteras:
			var ny_u := controlador_carreteras.cambiar_elevacion_paso(3.0)
			ui_editor.mostrar_notificacion("Elevación de vía: %+.1f m" % ny_u)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_PAGEDOWN and _categoria_activa == "vias" and controlador_carreteras:
			var ny_d := controlador_carreteras.cambiar_elevacion_paso(-3.0)
			ui_editor.mostrar_notificacion("Elevación de vía: %+.1f m" % ny_d)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_ejecutar_accion_colocar()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_R:
			_on_rotar_objeto_solicitado()
			get_viewport().set_input_as_handled()
			return
		
	# Interacción táctil y ratón: arrastre de elementos si se toca uno, o navegación fluida de cámara en espacio libre
	if event is InputEventScreenTouch:
		if not event.pressed:
			_puntero_presionado = false
			_arrastrando_camara = false
			controlador_terreno.finalizar_trazo()
			if _categoria_activa == "ciudad" and _subherramienta_activa == "zonificar" and controlador_zonificacion:
				var n_auto_z := controlador_zonificacion.finalizar_pintura()
				if n_auto_z > 0:
					ui_editor.mostrar_notificacion("🏠 %d casas construidas en los cuadros pintados" % n_auto_z)
			if _arrastrando_objeto:
				if _objeto_fue_arrastrado and is_instance_valid(_arrastrando_objeto):
					_aplicar_arrastre_objeto()
					ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
					ui_editor.mostrar_notificacion("✓ Objeto reposicionado")
				_arrastrando_objeto = null
				_objeto_fue_arrastrado = false
				_eje_arrastre_objeto = Vector3.ZERO
			if _arrastrando_punto_carretera:
				_arrastrando_punto_carretera = false
				if _punto_carretera_fue_arrastrado and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
					controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, false)
					ui_editor.actualizar_datos_panel_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
					ui_editor.mostrar_notificacion("✓ Carretera actualizada")
				_punto_carretera_fue_arrastrado = false
			if _arrastrando_esquina_parqueo:
				if controlador_estacionamientos and _esquina_parqueo_idx_est >= 0 and _esquina_parqueo_idx_esq != 4:
					controlador_estacionamientos.adaptar_terreno_estacionamiento(_esquina_parqueo_idx_est)
				_arrastrando_esquina_parqueo = false
				_esquina_parqueo_idx_est = -1
				_esquina_parqueo_idx_esq = -1
			if _arrastrando_punto_concreto:
				if controlador_concreto and _punto_concreto_idx_zona >= 0:
					controlador_concreto.adaptar_terreno_zona(_punto_concreto_idx_zona)
				_arrastrando_punto_concreto = false
				_punto_concreto_idx_zona = -1
				_punto_concreto_idx_pto = -1
		elif not (ui_editor and ui_editor.esta_sobre_interfaz(event.position)):
			_puntero_presionado = true
			_pos_puntero_pantalla = event.position
			_pos_toque_pantalla_anterior = event.position
			if _modo_camara_movil == "seleccionar":
				_actualizar_raycast_terreno()
				_seleccionar_cualquier_objeto_en_escena()
				get_viewport().set_input_as_handled()
				return
			elif _modo_camara_movil != "":
				_arrastrando_camara = true
				return
			_actualizar_raycast_terreno()
			var toco_elemento = _verificar_seleccion_en_click()
			if not toco_elemento and not _arrastrando_punto_carretera and not _arrastrando_objeto and not _arrastrando_esquina_parqueo:
				# Solo permitir arrastrar cámara con 1 dedo si estamos en vías en espacio libre
				if _categoria_activa == "vias":
					_arrastrando_camara = true
				elif _categoria_activa == "ciudad" and _subherramienta_activa == "auto_casas":
					_ejecutar_accion_colocar()
				elif _categoria_activa == "terreno" and _impacto_valido:
					controlador_terreno.comenzar_trazo(_pos_impacto_terreno)
			
	elif event is InputEventScreenDrag:
		if ui_editor and ui_editor.esta_sobre_interfaz(event.position):
			return
		_pos_puntero_pantalla = event.position
		if _modo_camara_movil != "" and _modo_camara_movil != "seleccionar" and _arrastrando_camara:
			var delta_cam: Vector2 = event.position - _pos_toque_pantalla_anterior
			_aplicar_gesto_camara_movil(delta_cam)
			_pos_toque_pantalla_anterior = event.position
			return
		_actualizar_raycast_terreno()
		if _arrastrando_objeto and is_instance_valid(_arrastrando_objeto):
			if event.position.distance_to(_pos_toque_pantalla_anterior) > 6.0 or _objeto_fue_arrastrado:
				_objeto_fue_arrastrado = true
				_aplicar_arrastre_objeto()
		elif _arrastrando_punto_carretera and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
			if event.position.distance_to(_pos_toque_pantalla_anterior) > 5.0 or _punto_carretera_fue_arrastrado:
				_punto_carretera_fue_arrastrado = true
				controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, true)
		elif _arrastrando_esquina_parqueo and controlador_estacionamientos and _impacto_valido:
			controlador_estacionamientos.mover_esquina(_esquina_parqueo_idx_est, _esquina_parqueo_idx_esq, _pos_impacto_terreno)
		elif _arrastrando_punto_concreto and controlador_concreto and _impacto_valido:
			controlador_concreto.mover_punto(_punto_concreto_idx_zona, _punto_concreto_idx_pto, _pos_impacto_terreno)
		elif _modo_camara_movil == "seleccionar":
			return
		elif _categoria_activa == "terreno" and _puntero_presionado and _impacto_valido:
			controlador_terreno.aplicar_trazo(_pos_impacto_terreno, camara_editor.angulo_yaw)
		elif _categoria_activa == "ciudad" and _subherramienta_activa == "zonificar" and _puntero_presionado and _impacto_valido and controlador_zonificacion:
			controlador_zonificacion.pintar_en_posicion(_pos_impacto_terreno)
		elif _categoria_activa in ["ciudad", "vegetacion"] and controlador_objetos.modo_demolicion and _puntero_presionado and _impacto_valido:
			controlador_objetos.demoler_en_radio(_pos_impacto_terreno, 6.0)
		elif _arrastrando_camara:
			var delta_drag = event.position - _pos_toque_pantalla_anterior
			camara_editor.panear_por_arrastre(delta_drag)
			_pos_toque_pantalla_anterior = event.position
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_puntero_presionado = false
				_arrastrando_camara = false
				controlador_terreno.finalizar_trazo()
				if _categoria_activa == "ciudad" and _subherramienta_activa == "zonificar" and controlador_zonificacion:
					var n_auto_zm := controlador_zonificacion.finalizar_pintura()
					if n_auto_zm > 0:
						ui_editor.mostrar_notificacion("🏠 %d casas construidas en los cuadros pintados" % n_auto_zm)
				if _arrastrando_objeto:
					if _objeto_fue_arrastrado and is_instance_valid(_arrastrando_objeto):
						_aplicar_arrastre_objeto()
						ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
						ui_editor.mostrar_notificacion("✓ Objeto reposicionado")
					_arrastrando_objeto = null
					_objeto_fue_arrastrado = false
					_eje_arrastre_objeto = Vector3.ZERO
				if _arrastrando_punto_carretera:
					_arrastrando_punto_carretera = false
					if _punto_carretera_fue_arrastrado and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
						controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, false)
						ui_editor.actualizar_datos_panel_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
						ui_editor.mostrar_notificacion("✓ Carretera actualizada")
					_punto_carretera_fue_arrastrado = false
				if _arrastrando_esquina_parqueo:
					if controlador_estacionamientos and _esquina_parqueo_idx_est >= 0 and _esquina_parqueo_idx_esq != 4:
						controlador_estacionamientos.adaptar_terreno_estacionamiento(_esquina_parqueo_idx_est)
					_arrastrando_esquina_parqueo = false
					_esquina_parqueo_idx_est = -1
					_esquina_parqueo_idx_esq = -1
				if _arrastrando_punto_concreto:
					if controlador_concreto and _punto_concreto_idx_zona >= 0:
						controlador_concreto.adaptar_terreno_zona(_punto_concreto_idx_zona)
					_arrastrando_punto_concreto = false
					_punto_concreto_idx_zona = -1
					_punto_concreto_idx_pto = -1
			elif not (ui_editor and ui_editor.esta_sobre_interfaz(event.position)):
				_puntero_presionado = true
				_pos_puntero_pantalla = event.position
				_pos_toque_pantalla_anterior = event.position
				if _modo_camara_movil == "seleccionar":
					_actualizar_raycast_terreno()
					_seleccionar_cualquier_objeto_en_escena()
					get_viewport().set_input_as_handled()
					return
				elif _modo_camara_movil != "":
					_arrastrando_camara = true
					return
				_actualizar_raycast_terreno()
				var toco_elemento = _verificar_seleccion_en_click()
				if not toco_elemento and not _arrastrando_punto_carretera and not _arrastrando_objeto and not _arrastrando_esquina_parqueo:
					# Solo permitir arrastrar cámara con clic izquierdo si estamos en vías en espacio libre
					if _categoria_activa == "vias":
						_arrastrando_camara = true
					elif _categoria_activa == "ciudad" and _subherramienta_activa == "auto_casas":
						_ejecutar_accion_colocar()
					elif _categoria_activa == "terreno" and _impacto_valido:
						controlador_terreno.comenzar_trazo(_pos_impacto_terreno)
				
	elif event is InputEventMouseMotion:
		# Sistema híbrido PC/Móvil: solo interactuar o mover si el usuario tiene el puntero presionado (clic y arrastre)
		if not _puntero_presionado:
			return
		if ui_editor and ui_editor.esta_sobre_interfaz(event.position):
			return
		_pos_puntero_pantalla = event.position
		if _modo_camara_movil != "" and _modo_camara_movil != "seleccionar" and _arrastrando_camara:
			var delta_cam: Vector2 = event.position - _pos_toque_pantalla_anterior
			_aplicar_gesto_camara_movil(delta_cam)
			_pos_toque_pantalla_anterior = event.position
			return
		_actualizar_raycast_terreno()
		if _arrastrando_objeto and is_instance_valid(_arrastrando_objeto):
			if event.position.distance_to(_pos_toque_pantalla_anterior) > 6.0 or _objeto_fue_arrastrado:
				_objeto_fue_arrastrado = true
				_aplicar_arrastre_objeto()
		elif _arrastrando_punto_carretera and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
			if event.position.distance_to(_pos_toque_pantalla_anterior) > 5.0 or _punto_carretera_fue_arrastrado:
				_punto_carretera_fue_arrastrado = true
				controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, true)
		elif _arrastrando_esquina_parqueo and controlador_estacionamientos and _impacto_valido:
			controlador_estacionamientos.mover_esquina(_esquina_parqueo_idx_est, _esquina_parqueo_idx_esq, _pos_impacto_terreno)
		elif _arrastrando_punto_concreto and controlador_concreto and _impacto_valido:
			controlador_concreto.mover_punto(_punto_concreto_idx_zona, _punto_concreto_idx_pto, _pos_impacto_terreno)
		elif _modo_camara_movil == "seleccionar":
			return
		elif _categoria_activa == "terreno" and _impacto_valido:
			controlador_terreno.aplicar_trazo(_pos_impacto_terreno, camara_editor.angulo_yaw)
		elif _categoria_activa == "ciudad" and _subherramienta_activa == "zonificar" and _impacto_valido and controlador_zonificacion:
			controlador_zonificacion.pintar_en_posicion(_pos_impacto_terreno)
		elif _categoria_activa in ["ciudad", "vegetacion"] and controlador_objetos.modo_demolicion and _impacto_valido:
			controlador_objetos.demoler_en_radio(_pos_impacto_terreno, 6.0)
		elif _arrastrando_camara:
			var delta_drag = event.position - _pos_toque_pantalla_anterior
			camara_editor.panear_por_arrastre(delta_drag)
			_pos_toque_pantalla_anterior = event.position

func _aplicar_gesto_camara_movil(delta_drag: Vector2) -> void:
	if not camara_editor:
		return
	match _modo_camara_movil:
		"mover":
			camara_editor.panear_por_arrastre(delta_drag)
		"orbitar":
			camara_editor.rotar_orbita(delta_drag.x * 0.32)
			camara_editor.inclinar_pitch(-delta_drag.y * 0.25)
		"zoom":
			var factor: float = clampf(1.0 + delta_drag.y * 0.005, 0.85, 1.18)
			camara_editor.zoom(factor)

func _iniciar_arrastre_objeto(obj: Node3D, eje: Vector3) -> void:
	_arrastrando_objeto = obj
	_objeto_fue_arrastrado = false
	_eje_arrastre_objeto = eje
	_pos_inicio_arrastre_eje = obj.global_position
	_pos_terreno_inicio_arrastre = _pos_impacto_terreno
	if absf(eje.y) > 0.5 and camara_editor and camara_editor.obtener_camara():
		var cam_fwd: Vector3 = -camara_editor.obtener_camara().global_transform.basis.z
		var n_vert := Vector3(cam_fwd.x, 0.0, cam_fwd.z)
		if n_vert.length_squared() < 0.001:
			n_vert = Vector3.FORWARD
		_plano_arrastre_objeto = Plane(n_vert.normalized(), obj.global_position)
	else:
		_plano_arrastre_objeto = Plane(Vector3.UP, obj.global_position.y)
	var orig := camara_editor.proyectar_rayo_origen(_pos_puntero_pantalla)
	var dir := camara_editor.proyectar_rayo_direccion(_pos_puntero_pantalla)
	var hit = _plano_arrastre_objeto.intersects_ray(orig, dir)
	if hit != null:
		_hit_inicio_arrastre = hit
		_offset_arrastre_libre = obj.global_position - hit
	else:
		_hit_inicio_arrastre = obj.global_position
		_offset_arrastre_libre = Vector3.ZERO

func _aplicar_arrastre_objeto() -> void:
	if not is_instance_valid(_arrastrando_objeto):
		return
	var orig := camara_editor.proyectar_rayo_origen(_pos_puntero_pantalla)
	var dir := camara_editor.proyectar_rayo_direccion(_pos_puntero_pantalla)
	var hit_actual = _plano_arrastre_objeto.intersects_ray(orig, dir)
	if hit_actual == null:
		return
	if _eje_arrastre_objeto != Vector3.ZERO:
		var pos_objetivo: Vector3 = _pos_inicio_arrastre_eje + (hit_actual - _hit_inicio_arrastre)
		controlador_objetos.mover_objeto_en_eje(_arrastrando_objeto, _pos_inicio_arrastre_eje, _eje_arrastre_objeto, pos_objetivo)
	else:
		controlador_objetos.mover_objeto(_arrastrando_objeto, hit_actual + _offset_arrastre_libre)

func _actualizar_raycast_terreno() -> void:
	var orig = camara_editor.proyectar_rayo_origen(_pos_puntero_pantalla)
	var dir = camara_editor.proyectar_rayo_direccion(_pos_puntero_pantalla)
	var res = controlador_terreno.raycast_terreno(orig, dir)
	_impacto_valido = res["impacto"]
	if _impacto_valido:
		_pos_impacto_terreno = res["posicion"]
	_actualizar_visibilidad_cursores()
	if ui_editor:
		ui_editor.actualizar_posicion_cursor(_pos_impacto_terreno, _impacto_valido)
		if _categoria_activa == "vias":
			var hay_snap = (controlador_carreteras.punto_snap_detectado != null and controlador_carreteras.punto_snap_detectado != controlador_carreteras._ultimo_road_point)
			var origen_fijado = (controlador_carreteras._punto_origen_conexion != null)
			var cruce_cercano = null
			if controlador_carreteras._ultimo_road_point == null and not controlador_carreteras.modo_conectar_activo and not (_subherramienta_activa in ["cruce_4", "cruce_t"]):
				cruce_cercano = controlador_carreteras.buscar_cruce_cercano(_pos_impacto_terreno, 10.0)
			var pt_cercano = null
			if not controlador_carreteras.modo_conectar_activo and not (_subherramienta_activa in ["cruce_4", "cruce_t"]):
				pt_cercano = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 6.0)
			var tiene_pt_sel = (controlador_carreteras.punto_carretera_seleccionado != null)
			ui_editor.actualizar_estado_boton_colocar("vias", _subherramienta_activa, false, hay_snap, origen_fijado, cruce_cercano != null, pt_cercano != null, tiene_pt_sel)

func _buscar_punto_via_bajo_puntero() -> RoadPoint:
	if _impacto_valido:
		var rp_terreno = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 7.5)
		if rp_terreno != null:
			return rp_terreno
	if not controlador_carreteras.road_container or not is_instance_valid(controlador_carreteras.road_container):
		return null
	var orig: Vector3 = camara_editor.proyectar_rayo_origen(_pos_puntero_pantalla)
	var dir: Vector3 = camara_editor.proyectar_rayo_direccion(_pos_puntero_pantalla).normalized()
	var mejor_rp: RoadPoint = null
	var mejor_dist: float = 4.0
	for rp in controlador_carreteras.road_container.get_roadpoints():
		if not (rp is RoadPoint) or not is_instance_valid(rp):
			continue
		var v: Vector3 = rp.global_position - orig
		var t: float = v.dot(dir)
		if t < 0.0:
			continue
		var proj: Vector3 = orig + dir * t
		var d: float = proj.distance_to(rp.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor_rp = rp
	return mejor_rp

func _seleccionar_cualquier_objeto_en_escena() -> bool:
	if not camara_editor:
		return false
	var ray_orig := camara_editor.proyectar_rayo_origen(_pos_puntero_pantalla)
	var ray_dir := camara_editor.proyectar_rayo_direccion(_pos_puntero_pantalla).normalized()
	var pos_ref: Vector3 = _pos_impacto_terreno if _impacto_valido else (ray_orig + ray_dir * 35.0)

	# 0. Gizmo del objeto ya seleccionado
	if controlador_objetos and is_instance_valid(controlador_objetos.objeto_seleccionado):
		var eje_flecha := controlador_objetos.detectar_flecha_gizmo_por_rayo(ray_orig, ray_dir)
		if eje_flecha != Vector3.ZERO:
			_iniciar_arrastre_objeto(controlador_objetos.objeto_seleccionado, eje_flecha)
			return true

	# 1. Raycast físico 3D directo sobre cualquier colisionador de escena (edificios, talleres, casas, árboles, vías)
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(ray_orig, ray_orig + ray_dir * 900.0)
		var res := space.intersect_ray(q)
		if res and res.has("collider"):
			var hit_pos: Vector3 = res["position"]
			var cur: Node = res["collider"] as Node
			while is_instance_valid(cur) and cur != self:
				if controlador_objetos and cur in controlador_objetos._objetos_en_escena:
					if cur == controlador_objetos.objeto_seleccionado:
						_iniciar_arrastre_objeto(controlador_objetos.objeto_seleccionado, Vector3.ZERO)
						return true
					var datos_f = controlador_objetos.seleccionar_objeto_en_escena(cur as Node3D)
					ui_editor.mostrar_panel_edicion_objeto(datos_f)
					ui_editor.mostrar_notificacion("%s seleccionado (pulsa Listo al terminar)" % datos_f.get("nombre", "Objeto"))
					_arrastrando_objeto = null
					_eje_arrastre_objeto = Vector3.ZERO
					return true
				if controlador_carreteras and ("start_point" in cur and "end_point" in cur):
					var seg: Node = cur
					var sp: Node3D = seg.get("start_point") as Node3D
					var ep: Node3D = seg.get("end_point") as Node3D
					var rp_sel: Node3D = null
					if is_instance_valid(sp) and is_instance_valid(ep):
						rp_sel = sp if hit_pos.distance_to(sp.global_position) <= hit_pos.distance_to(ep.global_position) else ep
					elif is_instance_valid(sp):
						rp_sel = sp
					elif is_instance_valid(ep):
						rp_sel = ep
					if is_instance_valid(rp_sel):
						controlador_carreteras.seleccionar_punto_carretera(rp_sel)
						_arrastrando_punto_carretera = true
						_punto_carretera_fue_arrastrado = false
						ui_editor.mostrar_panel_edicion_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
						ui_editor.mostrar_notificacion("Punto de vía seleccionado.")
						return true
				cur = cur.get_parent()

	# 2. Objetos 3D por AABB / MultiMesh (árboles de bosque, props sin colisionador)
	if controlador_objetos:
		var obj_cercano = controlador_objetos.buscar_objeto_por_rayo(ray_orig, ray_dir, pos_ref, 7.5)
		if obj_cercano != null:
			if obj_cercano == controlador_objetos.objeto_seleccionado:
				_iniciar_arrastre_objeto(controlador_objetos.objeto_seleccionado, Vector3.ZERO)
				return true
			var datos = controlador_objetos.seleccionar_objeto_en_escena(obj_cercano)
			ui_editor.mostrar_panel_edicion_objeto(datos)
			ui_editor.mostrar_notificacion("%s seleccionado (pulsa Listo al terminar)" % datos.get("nombre", "Objeto"))
			_arrastrando_objeto = null
			_eje_arrastre_objeto = Vector3.ZERO
			return true

	# 3. Estacionamientos (esquinas y lotes)
	if controlador_estacionamientos:
		var res_esq := controlador_estacionamientos.buscar_esquina_por_rayo(ray_orig, ray_dir)
		if res_esq.get("encontrado", false):
			if _categoria_activa != "parqueo" and ui_editor:
				ui_editor.seleccionar_categoria("parqueo")
				ui_editor._seleccionar_subherramienta("parqueo_editar")
			_esquina_parqueo_idx_est = int(res_esq["idx_est"])
			_esquina_parqueo_idx_esq = int(res_esq["idx_esq"])
			_arrastrando_esquina_parqueo = true
			controlador_estacionamientos.seleccionar_esquina(_esquina_parqueo_idx_est, _esquina_parqueo_idx_esq)
			return true
		if _impacto_valido:
			var idx_p := controlador_estacionamientos.buscar_estacionamiento_por_posicion(_pos_impacto_terreno)
			if idx_p >= 0:
				if _categoria_activa != "parqueo" and ui_editor:
					ui_editor.seleccionar_categoria("parqueo")
					ui_editor._seleccionar_subherramienta("parqueo_editar")
				controlador_estacionamientos.seleccionar_estacionamiento(idx_p)
				ui_editor.mostrar_notificacion("Estacionamiento #%d seleccionado." % (idx_p + 1))
				return true

	# 4. Zonas de concreto
	if controlador_concreto:
		var res_pto := controlador_concreto.buscar_punto_por_rayo(ray_orig, ray_dir)
		if res_pto.get("encontrado", false):
			if _categoria_activa != "concreto" and ui_editor:
				ui_editor.seleccionar_categoria("concreto")
				ui_editor._seleccionar_subherramienta("concreto_editar")
			_punto_concreto_idx_zona = int(res_pto["idx_zona"])
			_punto_concreto_idx_pto = int(res_pto["idx_pto"])
			_arrastrando_punto_concreto = true
			controlador_concreto.seleccionar_punto(_punto_concreto_idx_zona, _punto_concreto_idx_pto)
			return true
		if _impacto_valido:
			var idx_z := controlador_concreto.buscar_zona_por_posicion(_pos_impacto_terreno)
			if idx_z >= 0:
				if _categoria_activa != "concreto" and ui_editor:
					ui_editor.seleccionar_categoria("concreto")
					ui_editor._seleccionar_subherramienta("concreto_editar")
				controlador_concreto.seleccionar_zona(idx_z)
				ui_editor.mostrar_notificacion("Zona de concreto #%d seleccionada." % (idx_z + 1))
				return true

	# 5. Vías (puntos de carretera, cruces y tramos)
	if controlador_carreteras and _impacto_valido:
		var rp_cercano = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 7.0)
		if rp_cercano != null:
			controlador_carreteras.seleccionar_punto_carretera(rp_cercano)
			_arrastrando_punto_carretera = true
			_punto_carretera_fue_arrastrado = false
			ui_editor.mostrar_panel_edicion_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
			ui_editor.mostrar_notificacion("Punto de vía seleccionado.")
			return true
		var inter_cercana = controlador_carreteras.buscar_cruce_cercano(_pos_impacto_terreno, 12.0)
		if inter_cercana != null:
			controlador_carreteras.seleccionar_cruce(inter_cercana)
			ui_editor.mostrar_panel_edicion_cruce(controlador_carreteras.obtener_datos_cruce_seleccionado(), controlador_carreteras.obtener_datos_ramales_cruce())
			ui_editor.mostrar_notificacion("Cruce seleccionado para editar.")
			return true
		var seg_cercano = controlador_carreteras.buscar_segmento_por_posicion(_pos_impacto_terreno, 10.0)
		if seg_cercano != null:
			var rp_seg: RoadPoint = seg_cercano.start_point if is_instance_valid(seg_cercano.start_point) else seg_cercano.end_point
			if is_instance_valid(rp_seg):
				controlador_carreteras.seleccionar_punto_carretera(rp_seg)
				ui_editor.mostrar_panel_edicion_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
				ui_editor.mostrar_notificacion("Vía seleccionada.")
				return true

	# Si tocó espacio vacío y había algo seleccionado, deseleccionar limpiamente
	if controlador_objetos and is_instance_valid(controlador_objetos.objeto_seleccionado):
		controlador_objetos.deseleccionar_objeto()
		ui_editor.ocultar_panel_edicion_objeto()
	return false

func _verificar_seleccion_en_click() -> bool:
	if _categoria_activa == "vias" and _subherramienta_activa == "equipamiento_vias":
		if _impacto_valido:
			var seg_directo = controlador_carreteras.buscar_segmento_por_posicion(_pos_impacto_terreno, 10.0)
			if seg_directo != null and controlador_equipamiento.punto_inicio == null:
				controlador_equipamiento.seleccionar_segmentos_directo([seg_directo])
				ui_editor.mostrar_notificacion("✓ Tramo seleccionado. Pulsa 'Aplicar al Tramo' para colocar aceras o equipamiento.")
				return true
		var rp_equip = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 4.0) if _impacto_valido else _buscar_punto_via_bajo_puntero()
		if rp_equip != null:
			var res_equip = controlador_equipamiento.procesar_clic_punto(rp_equip)
			ui_editor.mostrar_notificacion(res_equip.get("mensaje", ""))
			return true
		if _impacto_valido:
			var seg_directo2 = controlador_carreteras.buscar_segmento_por_posicion(_pos_impacto_terreno, 14.0)
			if seg_directo2 != null:
				controlador_equipamiento.seleccionar_segmentos_directo([seg_directo2])
				ui_editor.mostrar_notificacion("✓ Tramo seleccionado. Pulsa 'Aplicar al Tramo' para colocar aceras o equipamiento.")
				return true
		return false

	if not _impacto_valido:
		return false

	if _categoria_activa == "parqueo" and controlador_estacionamientos and camara_editor:
		var cam_p: Camera3D = camara_editor.obtener_camara()
		if cam_p:
			var orig_p := cam_p.project_ray_origin(_pos_puntero_pantalla)
			var dir_p := cam_p.project_ray_normal(_pos_puntero_pantalla)
			var res_esq := controlador_estacionamientos.buscar_esquina_por_rayo(orig_p, dir_p)
			if res_esq.get("encontrado", false):
				_esquina_parqueo_idx_est = int(res_esq["idx_est"])
				_esquina_parqueo_idx_esq = int(res_esq["idx_esq"])
				_arrastrando_esquina_parqueo = true
				controlador_estacionamientos.seleccionar_esquina(_esquina_parqueo_idx_est, _esquina_parqueo_idx_esq)
				if _esquina_parqueo_idx_esq == 4:
					ui_editor.mostrar_notificacion("Entrada seleccionada. Arrastra a lo largo del frente para moverla.")
				else:
					ui_editor.mostrar_notificacion("Esquina #%d seleccionada. Arrastra para adaptar el parqueo." % (_esquina_parqueo_idx_esq + 1))
				return true
		var idx_p := controlador_estacionamientos.buscar_estacionamiento_por_posicion(_pos_impacto_terreno)
		if idx_p >= 0:
			controlador_estacionamientos.seleccionar_estacionamiento(idx_p)
			ui_editor.mostrar_notificacion("Estacionamiento #%d seleccionado." % (idx_p + 1))
			return true

	if _categoria_activa == "concreto" and controlador_concreto and camara_editor:
		var cam_c: Camera3D = camara_editor.obtener_camara()
		if cam_c:
			var orig_c := cam_c.project_ray_origin(_pos_puntero_pantalla)
			var dir_c := cam_c.project_ray_normal(_pos_puntero_pantalla)
			var res_pto := controlador_concreto.buscar_punto_por_rayo(orig_c, dir_c)
			if res_pto.get("encontrado", false):
				_punto_concreto_idx_zona = int(res_pto["idx_zona"])
				_punto_concreto_idx_pto = int(res_pto["idx_pto"])
				_arrastrando_punto_concreto = true
				controlador_concreto.seleccionar_punto(_punto_concreto_idx_zona, _punto_concreto_idx_pto)
				ui_editor.mostrar_notificacion("Punto #%d seleccionado. Arrastra para moldear el concreto." % (_punto_concreto_idx_pto + 1))
				return true
		var idx_z := controlador_concreto.buscar_zona_por_posicion(_pos_impacto_terreno)
		if idx_z >= 0:
			controlador_concreto.seleccionar_zona(idx_z)
			ui_editor.mostrar_notificacion("Zona de concreto #%d seleccionada." % (idx_z + 1))
			return true

	if _categoria_activa == "vias":
		if controlador_carreteras.modo_conectar_activo:
			return false
			
			
		# 1. Si ya hay un cruce seleccionado, verificar primero si se hizo clic en una de sus salidas
		if is_instance_valid(controlador_carreteras.cruce_seleccionado):
			var ramal_cercano = controlador_carreteras.buscar_ramal_cruce_cercano(_pos_impacto_terreno, 6.0)
			if ramal_cercano != null:
				controlador_carreteras.seleccionar_ramal_cruce(ramal_cercano)
				var dr = controlador_carreteras.obtener_datos_ramales_cruce()
				ui_editor.actualizar_seccion_ramales(dr)
				var tipo = controlador_carreteras._obtener_tipo_via_de_punto(ramal_cercano)
				ui_editor._seleccionar_boton_tipo_via(tipo)
				var etq = controlador_carreteras._obtener_etiqueta_cardinal(controlador_carreteras.cruce_seleccionado.global_position, ramal_cercano.global_position)
				ui_editor.mostrar_notificacion("Salida (%s) seleccionada para editar carriles." % etq)
				return true

		# 2. Permitir seleccionar y arrastrar cualquier punto de vía existente al tocarlo directamente:
		if not (_subherramienta_activa in ["cruce_4", "cruce_t", "conectar_vias", "equipamiento_vias"]):
			var rp_cercano = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 6.0)
			if rp_cercano != null:
				controlador_carreteras.seleccionar_punto_carretera(rp_cercano)
				_arrastrando_punto_carretera = true
				_punto_carretera_fue_arrastrado = false
				var dp = controlador_carreteras.obtener_datos_punto_seleccionado()
				ui_editor.mostrar_panel_edicion_punto_via(dp)
				ui_editor.mostrar_notificacion("Punto de vía seleccionado. Usa ↕ ALTURA o arrástralo.")
				return true
			elif is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
				var pos_sel = controlador_carreteras.punto_carretera_seleccionado.global_position
				var dist_2d = Vector2(_pos_impacto_terreno.x, _pos_impacto_terreno.z).distance_to(Vector2(pos_sel.x, pos_sel.z))
				if dist_2d <= 6.5:
					_arrastrando_punto_carretera = true
					_punto_carretera_fue_arrastrado = false
					return true

		# 3. Si no hay trazo activo, permitir seleccionar cualquier cruce tocándolo
		if controlador_carreteras._ultimo_road_point == null and not (_subherramienta_activa in ["cruce_4", "cruce_t"]):
			var inter_cercana = controlador_carreteras.buscar_cruce_cercano(_pos_impacto_terreno, 12.0)
			if inter_cercana != null:
				controlador_carreteras.seleccionar_cruce(inter_cercana)
				var datos = controlador_carreteras.obtener_datos_cruce_seleccionado()
				var datos_ramales = controlador_carreteras.obtener_datos_ramales_cruce()
				ui_editor.mostrar_panel_edicion_cruce(datos, datos_ramales)
				ui_editor.mostrar_notificacion("Cruce seleccionado para editar.")
				return true
			elif is_instance_valid(controlador_carreteras.cruce_seleccionado):
				# Clic en terreno vacío alejado: deseleccionar cruce actual
				controlador_carreteras.deseleccionar_cruce()
				ui_editor.ocultar_panel_edicion_cruce()

		# 4. Si tocó en terreno vacío alejado y había punto seleccionado (y no estamos en modificar_vias):
		if is_instance_valid(controlador_carreteras.punto_carretera_seleccionado) and _subherramienta_activa != "modificar_vias":
			controlador_carreteras.deseleccionar_punto_carretera()
			ui_editor.ocultar_panel_edicion_punto_via()

	elif _categoria_activa in ["ciudad", "vegetacion"]:
		var ray_orig := camara_editor.proyectar_rayo_origen(_pos_puntero_pantalla)
		var ray_dir := camara_editor.proyectar_rayo_direccion(_pos_puntero_pantalla)

		# Si ya hay un objeto seleccionado, bloquear cambio accidental hasta pulsar "Listo"
		if is_instance_valid(controlador_objetos.objeto_seleccionado):
			var eje_flecha := controlador_objetos.detectar_flecha_gizmo_por_rayo(ray_orig, ray_dir)
			if eje_flecha != Vector3.ZERO:
				_iniciar_arrastre_objeto(controlador_objetos.objeto_seleccionado, eje_flecha)
				return true

			var obj_mismo = controlador_objetos.buscar_objeto_por_rayo(ray_orig, ray_dir, _pos_impacto_terreno, 6.5)
			if obj_mismo == controlador_objetos.objeto_seleccionado or _modo_mover_objeto:
				_iniciar_arrastre_objeto(controlador_objetos.objeto_seleccionado, Vector3.ZERO)
				return true

			return false

		var obj_cercano = controlador_objetos.buscar_objeto_por_rayo(ray_orig, ray_dir, _pos_impacto_terreno, 6.5)
		if controlador_objetos.modo_demolicion:
			if obj_cercano != null:
				controlador_objetos.eliminar_objeto(obj_cercano)
				ui_editor.mostrar_notificacion("✓ Elemento demolido")
				return true
			elif controlador_objetos.demoler_en_radio(_pos_impacto_terreno, 6.0) > 0:
				ui_editor.mostrar_notificacion("✓ Elementos demolidos")
				return true
			return false
		if obj_cercano != null:
			# Primer clic: Seleccionar y mostrar caja delimitadora, flechas e inspector
			var datos = controlador_objetos.seleccionar_objeto_en_escena(obj_cercano)
			ui_editor.mostrar_panel_edicion_objeto(datos)
			ui_editor.mostrar_notificacion("%s seleccionado (pulsa Listo al terminar)" % datos.get("nombre", "Objeto"))
			_arrastrando_objeto = null # NO mover en el primer toque
			_eje_arrastre_objeto = Vector3.ZERO
			return true

	return false

func _ejecutar_accion_colocar() -> void:
	if not _impacto_valido:
		ui_editor.mostrar_notificacion("Toca o arrastra sobre el terreno para posicionar primero")
		return
	
	if _subherramienta_activa == "reductor_velocidad":
		var ok = controlador_equipamiento.colocar_reductor_en_posicion_mundo(_pos_impacto_terreno)
		if ok:
			ui_editor.mostrar_notificacion("¡Resalto vial colocado y vinculado a la carretera!")
		else:
			ui_editor.mostrar_notificacion("⚠️ Toca sobre una carretera existente para instalar el resalto.")
		return
		
	match _categoria_activa:
		"agua":
			if controlador_agua:
				var r_lago: float = ui_editor._radio_lago if ui_editor else 24.0
				var p_lago: float = ui_editor._profundidad_lago if ui_editor else 3.5
				var w_rio: float = ui_editor._ancho_rio if ui_editor else 8.0
				match _subherramienta_activa:
					"lago", "lago_agua":
						var lago := controlador_agua.crear_lago(_pos_impacto_terreno, r_lago, p_lago, true, true)
						if lago:
							ui_editor.mostrar_notificacion("✓ Lago creado (Radio: %.0fm, Prof: %.1fm)" % [r_lago, p_lago])
					"cuenca":
						if controlador_agua.excavar_cuenca(_pos_impacto_terreno, r_lago, p_lago):
							ui_editor.mostrar_notificacion("✓ Cuenca excavada (Radio: %.0fm)" % r_lago)
						else:
							ui_editor.mostrar_notificacion("No se pudo excavar la cuenca en esta zona")
					"rio", "rio_agua":
						var n_pts := controlador_agua.agregar_punto_rio(_pos_impacto_terreno, w_rio)
						if n_pts >= 2:
							ui_editor.mostrar_notificacion("✓ Tramo de río actualizado (%d puntos, ancho %.0fm)" % [n_pts, w_rio])
						else:
							ui_editor.mostrar_notificacion("Punto #1 del río fijado. Toca más puntos para trazarlo.")
					"nivel":
						var sel_a := controlador_agua.seleccionar_cuerpo_cercano(_pos_impacto_terreno)
						if sel_a:
							ui_editor.mostrar_notificacion("✓ %s seleccionado (Nivel: %.2fm). Usa los botones +/-." % [sel_a.name, sel_a.global_position.y])
						else:
							ui_editor.mostrar_notificacion("Toca sobre un lago o río para seleccionarlo")
					"limpiar":
						if controlador_agua.borrar_agua_en_posicion(_pos_impacto_terreno):
							ui_editor.mostrar_notificacion("✓ Cuerpo de agua eliminado")
						else:
							ui_editor.mostrar_notificacion("Toca sobre un lago o río para eliminarlo")
		"terreno":
			if _subherramienta_activa == "pendiente" and controlador_terreno:
				var res_p := controlador_terreno.clic_pendiente(_pos_impacto_terreno)
				if int(res_p.get("paso", 0)) == 1:
					ui_editor.mostrar_notificacion("📍 Punto A de rampa fijado (%.1fm). Toca el Punto B." % float(res_p.get("altura", 0.0)))
				elif bool(res_p.get("ok", false)):
					ui_editor.mostrar_notificacion("✓ Rampa nivelada (%.1fm → %.1fm)" % [float(res_p.get("h_a", 0.0)), float(res_p.get("h_b", 0.0))])
				else:
					ui_editor.mostrar_notificacion("Selecciona un punto B más lejano")
			else:
				var snap_antes := controlador_terreno.capturar_snapshot_altura(_pos_impacto_terreno, controlador_terreno.radio_pincel)
				controlador_terreno.comenzar_trazo(_pos_impacto_terreno)
				controlador_terreno.aplicar_trazo(_pos_impacto_terreno, camara_editor.angulo_yaw)
				controlador_terreno.finalizar_trazo()
				var snap_despues := controlador_terreno.capturar_snapshot_altura(_pos_impacto_terreno, controlador_terreno.radio_pincel)
				if not snap_antes.is_empty():
					_undo_redo.create_action("Modificar terreno")
					_undo_redo.add_do_method(func(): controlador_terreno.restaurar_snapshot_altura(snap_despues))
					_undo_redo.add_undo_method(func(): controlador_terreno.restaurar_snapshot_altura(snap_antes))
					_undo_redo.commit_action(false)
				if controlador_carreteras and not controlador_carreteras._puntos_creados.is_empty():
					controlador_carreteras.nivelar_terreno_bajo_carreteras()
				ui_editor.mostrar_notificacion("Terreno modificado")
		"vegetacion":
			if controlador_objetos.modo_demolicion:
				if controlador_objetos.demoler_en_posicion(_pos_impacto_terreno):
					ui_editor.mostrar_notificacion("Elemento demolido")
				else:
					ui_editor.mostrar_notificacion("No se encontró ningún elemento en ese punto")
			elif controlador_objetos.modo_pincel_dispersion:
				var cant = controlador_objetos.dispersar_vegetacion(_pos_impacto_terreno)
				ui_editor.mostrar_notificacion("Dispersados %d árboles con MultiMesh en el terreno." % cant)
			else:
				var obj = controlador_objetos.colocar_objeto(_pos_impacto_terreno)
				if obj:
					var nombre_item = controlador_objetos.id_objeto_seleccionado.replace("_", " ").capitalize()
					ui_editor.mostrar_notificacion("¡%s colocado exitosamente!" % nombre_item)
					if controlador_objetos.id_objeto_seleccionado in ["garaje_camiones", "garaje_doble", "garaje_terminal", "garaje_moderno"]:
						set_meta("ultimo_garaje_colocado", obj)
						ui_editor.mostrar_panel_variaciones_garaje(controlador_objetos.id_objeto_seleccionado)
		"muros":
			if controlador_muros:
				controlador_muros.agregar_punto_muro(_pos_impacto_terreno)
				ui_editor.mostrar_notificacion("Punto de muro colocado (toca el siguiente punto para extender)")
		"parqueo":
			if controlador_estacionamientos:
				if _subherramienta_activa == "parqueo_nivelar":
					if controlador_estacionamientos.nivelar_terreno_seleccionado():
						ui_editor.mostrar_notificacion("✓ Terreno nivelado bajo el estacionamiento")
					else:
						ui_editor.mostrar_notificacion("Selecciona primero una esquina de estacionamiento")
				elif _subherramienta_activa == "parqueo_borrar":
					if controlador_estacionamientos.borrar_estacionamiento_en_posicion(_pos_impacto_terreno):
						ui_editor.mostrar_notificacion("Estacionamiento eliminado")
					else:
						ui_editor.mostrar_notificacion("Acerca el cursor al estacionamiento que deseas borrar")
				else:
					var tipo_p: int = ui_editor._parqueo_tipo_sel if ui_editor else 0
					controlador_estacionamientos.crear_estacionamiento(_pos_impacto_terreno, tipo_p)
					ui_editor.mostrar_notificacion("✓ Estacionamiento creado. Arrastra las 4 esferas amarillas para adaptarlo.")
		"concreto":
			if controlador_concreto:
				if _subherramienta_activa == "concreto_nivelar":
					if controlador_concreto.nivelar_terreno_seleccionado():
						ui_editor.mostrar_notificacion("✓ Terreno nivelado bajo el concreto")
					else:
						ui_editor.mostrar_notificacion("Selecciona primero una zona de concreto")
				elif _subherramienta_activa == "concreto_borrar":
					if controlador_concreto.borrar_zona_en_posicion(_pos_impacto_terreno):
						ui_editor.mostrar_notificacion("Zona de concreto eliminada")
					else:
						ui_editor.mostrar_notificacion("Toca la zona de concreto que deseas borrar")
				else:
					var acab: int = ui_editor._concreto_acabado_sel if ui_editor else 0
					controlador_concreto.crear_zona_concreto(_pos_impacto_terreno, acab)
					ui_editor.mostrar_notificacion("✓ Concreto creado con 8 puntos editables. Arrástralos o agrega más puntos.")
		"ciudad":
			if _subherramienta_activa == "auto_casas":
				var sec_ac: String = ui_editor._auto_casas_seccion_ui if ui_editor else "01_Residencial"
				var rad_ac: float = ui_editor._auto_casas_radio_ui if ui_editor else 35.0
				var cant_ac: int = ui_editor._auto_casas_cantidad_ui if ui_editor else 8
				var modo_ac: String = ui_editor._auto_casas_modo_ui if ui_editor else "pincel"
				var lote: Array[Node3D] = []
				if modo_ac == "cuadra":
					var cols_c := clampi(int(round(rad_ac / 8.0)), 3, 8)
					lote = controlador_objetos.generar_cuadra_casas(_pos_impacto_terreno, sec_ac, cols_c, controlador_objetos.rotacion_actual_grados, true)
				else:
					lote = controlador_objetos.generar_casas_automaticas(_pos_impacto_terreno, sec_ac, rad_ac, cant_ac, modo_ac)
				if lote.size() > 0:
					_undo_redo.create_action("Generar casas automáticas")
					_undo_redo.add_do_method(func():
						for o in lote:
							if is_instance_valid(o):
								o.visible = true
					)
					_undo_redo.add_undo_method(func():
						for o in lote:
							if is_instance_valid(o):
								controlador_objetos._objetos_en_escena.erase(o)
								o.queue_free()
					)
					_undo_redo.commit_action(false)
					ui_editor.mostrar_notificacion("🏠 %d casas generadas automáticamente en la sección" % lote.size())
				else:
					ui_editor.mostrar_notificacion("No hay espacio libre suficiente (o acércate a una vía en modo Borde de Vía)")
			elif _subherramienta_activa == "zonificar" and controlador_zonificacion:
				var n_z := controlador_zonificacion.pintar_en_posicion(_pos_impacto_terreno)
				if n_z > 0:
					ui_editor.mostrar_notificacion("✓ %d celdas zonificadas junto a la vía" % n_z)
				else:
					ui_editor.mostrar_notificacion("Acerca el pincel a una carretera para pintar zonas")
			elif controlador_objetos.modo_demolicion:
				var cant_d := controlador_objetos.demoler_en_radio(_pos_impacto_terreno, 6.0)
				if cant_d > 0:
					ui_editor.mostrar_notificacion("Elementos demolidos (%d)" % cant_d)
				else:
					ui_editor.mostrar_notificacion("No se encontró ningún elemento en ese punto")
			else:
				var obj = controlador_objetos.colocar_objeto(_pos_impacto_terreno)
				if obj:
					_undo_redo.create_action("Colocar objeto")
					_undo_redo.add_do_method(func():
						if is_instance_valid(obj):
							obj.visible = true
					)
					_undo_redo.add_undo_method(func():
						if is_instance_valid(obj):
							controlador_objetos._objetos_en_escena.erase(obj)
							obj.queue_free()
					)
					_undo_redo.commit_action(false)
					var nombre_item = controlador_objetos.id_objeto_seleccionado.replace("_", " ").capitalize()
					ui_editor.mostrar_notificacion("¡%s colocado exitosamente!" % nombre_item)
					if controlador_objetos.id_objeto_seleccionado in ["garaje_camiones", "garaje_doble", "garaje_terminal", "garaje_moderno"]:
						set_meta("ultimo_garaje_colocado", obj)
						ui_editor.mostrar_panel_variaciones_garaje(controlador_objetos.id_objeto_seleccionado)
		"vias":
			if controlador_carreteras.modo_mejorar_via:
				if controlador_carreteras.mejorar_segmento_en_posicion(_pos_impacto_terreno, controlador_carreteras.tipo_via_actual):
					ui_editor.mostrar_notificacion("✓ Vía actualizada al tipo seleccionado")
				else:
					ui_editor.mostrar_notificacion("Toca sobre un tramo de vía existente para mejorarlo")
				return
			if _subherramienta_activa == "equipamiento_vias":
				if not controlador_equipamiento.tramo_segmentos.is_empty():
					var res_eq = controlador_equipamiento.aplicar_equipamiento_actual()
					ui_editor.mostrar_notificacion(res_eq.get("mensaje", "Equipamiento aplicado al tramo"))
					if res_eq.get("exito", false):
						controlador_carreteras.nivelar_terreno_bajo_carreteras()
				else:
					var rp_col = _buscar_punto_via_bajo_puntero()
					if rp_col != null:
						var res_p = controlador_equipamiento.procesar_clic_punto(rp_col)
						ui_editor.mostrar_notificacion(res_p.get("mensaje", ""))
					else:
						ui_editor.mostrar_notificacion("Toca un punto de la vía para seleccionarlo como inicio/fin.")
				return
			elif is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
				controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, false)
				ui_editor.actualizar_datos_panel_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
				ui_editor.mostrar_notificacion("✓ Punto de vía movido a la nueva posición")
				return
			elif _subherramienta_activa == "modificar_vias":
				var pt_apuntado = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 6.0)
				if pt_apuntado != null:
					controlador_carreteras.seleccionar_punto_carretera(pt_apuntado)
					ui_editor.mostrar_panel_edicion_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
					ui_editor.mostrar_notificacion("Punto seleccionado. Arrástralo o pulsa 'MOVER PUNTO AQUÍ'.")
				else:
					ui_editor.mostrar_notificacion("Toca sobre un punto de vía para modificarlo")
				return
			elif _subherramienta_activa == "rotonda":
				_guardar_snapshot_vias()
				var res_rot: Dictionary = controlador_carreteras.crear_rotonda(_pos_impacto_terreno)
				if res_rot.get("exito", false):
					ui_editor.mostrar_notificacion("¡Rotonda colocada! Conecta vías a sus 4 accesos.")
				return
			elif _subherramienta_activa == "dividir":
				var seg_info: Dictionary = controlador_carreteras.buscar_segmento_cercano(_pos_impacto_terreno, 9.0)
				if seg_info.is_empty():
					ui_editor.mostrar_notificacion("Apunta sobre una vía existente para insertar un nodo.")
					return
				_guardar_snapshot_vias()
				var nuevo_rp = controlador_carreteras.insertar_punto_en_segmento(seg_info["segmento"], seg_info["posicion"])
				if nuevo_rp:
					controlador_carreteras.seleccionar_punto_carretera(nuevo_rp)
					ui_editor.mostrar_panel_edicion_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
					ui_editor.mostrar_notificacion("¡Nodo insertado! Arrástralo para curvar la vía.")
				return
			elif _subherramienta_activa in ["cruce_4", "cruce_t"]:
				_guardar_snapshot_vias()
				var rot = controlador_carreteras.rotacion_cruce_grados
				var inter = controlador_carreteras.crear_cruce(_pos_impacto_terreno, _subherramienta_activa, rot)
				if inter:
					var nombre_cruce = "Cruce de 4 Vías" if _subherramienta_activa == "cruce_4" else "Cruce en T"
					ui_editor.mostrar_notificacion("¡%s colocado!" % nombre_cruce)
			elif controlador_carreteras.modo_conectar_activo:
				_guardar_snapshot_vias()
				var res_con = controlador_carreteras.ejecutar_paso_conexion(_pos_impacto_terreno)
				ui_editor.mostrar_notificacion(res_con["mensaje"])
				var origen_fijado = (controlador_carreteras._punto_origen_conexion != null)
				ui_editor.actualizar_estado_boton_colocar("vias", _subherramienta_activa, false, false, origen_fijado)
			else:
				# Si no hay trazo activo y el cursor apunta a un cruce existente, seleccionarlo para editar
				if controlador_carreteras._ultimo_road_point == null:
					var cruce_apuntado = controlador_carreteras.buscar_cruce_cercano(_pos_impacto_terreno, 10.0)
					if cruce_apuntado != null:
						controlador_carreteras.seleccionar_cruce(cruce_apuntado)
						var datos = controlador_carreteras.obtener_datos_cruce_seleccionado()
						var datos_ramales = controlador_carreteras.obtener_datos_ramales_cruce()
						ui_editor.mostrar_panel_edicion_cruce(datos, datos_ramales)
						ui_editor.mostrar_notificacion("Cruce seleccionado para editar.")
						return
						
				_guardar_snapshot_vias()
				var rp_previo = controlador_carreteras.punto_snap_detectado
				var es_conexion = (rp_previo != null and rp_previo != controlador_carreteras._ultimo_road_point)
				controlador_carreteras.agregar_punto_carretera(controlador_carreteras.obtener_posicion_trazo_snapped(_pos_impacto_terreno))
				if es_conexion:
					ui_editor.mostrar_notificacion("¡Vías conectadas exitosamente!")
				else:
					ui_editor.mostrar_notificacion("Punto de vía colocado")
		"spawn":
			controlador_spawn.posicionar_spawn(_pos_impacto_terreno)
			ui_editor.mostrar_notificacion("Punto de Spawn posicionado")

func _process(_delta: float) -> void:
	if not modo_prueba.en_prueba:
		ui_editor.actualizar_telemetria(
			Engine.get_frames_per_second(),
			controlador_objetos._objetos_en_escena.size(),
			_pos_impacto_terreno.x,
			_pos_impacto_terreno.z
		)

# ── TRANSICIÓN DE MODO PRUEBA (TEST DE CONDUCCIÓN / EXPLORACIÓN) ─────

func _on_iniciar_prueba() -> void:
	# Activar el cielo completo con nubes/sol/luna solo durante la prueba del mapa
	if is_instance_valid(world_env_editor) and _env_prueba:
		world_env_editor.environment = _env_prueba
	# Ocultar cámara, UI y marcadores del editor
	if camara_editor:
		camara_editor.activa = false
		camara_editor.visible = false
		camara_editor.set_process(false)
		camara_editor.set_process_input(false)
		camara_editor.set_process_unhandled_input(false)
		var cam = camara_editor.obtener_camara()
		if cam:
			cam.current = false
	if ui_editor:
		ui_editor.visible = false
	if is_instance_valid(controlador_spawn):
		controlador_spawn.visible = false
	if is_instance_valid(controlador_carreteras):
		controlador_carreteras.deseleccionar_todo()
	
	# Iniciar modo prueba en el punto de spawn configurado
	var spawn_xf = controlador_spawn.obtener_transform_spawn() if controlador_spawn else Transform3D.IDENTITY
	var modo_sp = controlador_spawn.obtener_modo_nombre() if controlador_spawn else "vehiculo"
	modo_prueba.iniciar_prueba(self, spawn_xf, modo_sp)

func _on_prueba_finalizada() -> void:
	# Restaurar el cielo ligero de alto rendimiento para el Editor de Mapas
	if is_instance_valid(world_env_editor) and _env_editor:
		world_env_editor.environment = _env_editor
	# Restaurar cámara, UI y marcadores del editor
	if is_instance_valid(controlador_spawn):
		controlador_spawn.visible = true
	if camara_editor:
		camara_editor.activa = true
		camara_editor.visible = true
		camara_editor.set_process(true)
		camara_editor.set_process_input(true)
		camara_editor.set_process_unhandled_input(true)
		var cam = camara_editor.obtener_camara()
		if cam:
			cam.current = true
			if controlador_terreno:
				controlador_terreno.bloqueado_en_prueba = false
				controlador_terreno.configurar_camara(cam)
	if ui_editor:
		ui_editor.visible = true
		ui_editor.mostrar_notificacion("Has vuelto al editor de mapas")

# ── GUARDAR Y CARGAR MAPAS (PERSISTENCIA COMPLETA) ───────────────────

func _activar_pipeta_en_cursor() -> void:
	if not _impacto_valido or not controlador_objetos:
		return
	var id_copiado := controlador_objetos.obtener_id_en_posicion(_pos_impacto_terreno, 8.0)
	if not id_copiado.is_empty():
		controlador_objetos.modo_demolicion = false
		controlador_objetos.seleccionar_objeto(id_copiado)
		ui_editor.mostrar_notificacion("💧 Pipeta: seleccionado '%s'" % id_copiado.replace("_", " ").capitalize())
	else:
		ui_editor.mostrar_notificacion("Apunta sobre un edificio o árbol para copiarlo con la pipeta")

func _cargar_mapa_inicial_hub() -> void:
	var ruta_hub: String = str(Engine.get_meta("nt_editor_mapa_ruta", ""))
	var nombre_hub: String = str(Engine.get_meta("nt_editor_mapa_nombre", ""))
	if not ruta_hub.is_empty():
		_ruta_mapa_actual = ruta_hub
		if not nombre_hub.is_empty():
			_nombre_mapa_actual = nombre_hub
		if FileAccess.file_exists(ruta_hub):
			cargar_mapa_desde_ruta(ruta_hub)

func guardar_mapa() -> void:
	var dir_mapas = "user://mapas"
	if not DirAccess.dir_exists_absolute(dir_mapas):
		DirAccess.make_dir_recursive_absolute(dir_mapas)
		
	var ruta_ntmap = _ruta_mapa_actual if not _ruta_mapa_actual.is_empty() else (dir_mapas + "/mapa_guardado.ntmap")
	_ruta_mapa_actual = ruta_ntmap
	var dir_terreno := ruta_ntmap.get_basename() + "_terreno"
	var terreno_ok := false
	if controlador_terreno:
		terreno_ok = controlador_terreno.guardar_terreno(dir_terreno)

	var datos := {
		"formato": "NT_MAP",
		"version": 2,
		"nombre": _nombre_mapa_actual,
		"autor": "EditorNuestraTierra",
		"hora_dia": hora_actual_editor,
		"terreno_dir": dir_terreno if terreno_ok else "",
		"objetos": controlador_objetos.serializar_objetos(),
		"vegetacion_multimesh": controlador_objetos.serializar_vegetacion_multimesh(),
		"carreteras": controlador_carreteras.serializar_carreteras(),
		"equipamiento_vias": controlador_equipamiento.serializar_equipamiento() if controlador_equipamiento else [],
		"muros": controlador_muros.serializar_muros() if controlador_muros else [],
		"estacionamientos": controlador_estacionamientos.serializar_estacionamientos() if controlador_estacionamientos else [],
		"zonas_concreto": controlador_concreto.serializar_zonas() if controlador_concreto else [],
		"zonas_cs2": controlador_zonificacion.serializar_zonas() if controlador_zonificacion else [],
		"cuerpos_agua": controlador_agua.serializar_aguas() if controlador_agua else [],
		"spawn": controlador_spawn.serializar_spawn()
	}
	
	var file = FileAccess.open(ruta_ntmap, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(datos, "  "))
		file.close()
		# Guardar copia compatible .json
		var f_json = FileAccess.open(dir_mapas + "/mapa_guardado.json", FileAccess.WRITE)
		if f_json:
			f_json.store_string(JSON.stringify(datos, "  "))
			f_json.close()
		ui_editor.mostrar_notificacion("¡Mapa guardado en %s!" % ruta_ntmap.get_file())
	else:
		push_error("Error al abrir archivo para guardar mapa: %s (err=%d)" % [ruta_ntmap, FileAccess.get_open_error()])
		ui_editor.mostrar_notificacion("Error al guardar mapa.")

func cargar_mapa() -> void:
	var dir_mapas = "user://mapas"
	var ruta_archivo = _ruta_mapa_actual if (not _ruta_mapa_actual.is_empty() and FileAccess.file_exists(_ruta_mapa_actual)) else (dir_mapas + "/mapa_guardado.ntmap")
	if not FileAccess.file_exists(ruta_archivo):
		ruta_archivo = dir_mapas + "/mapa_guardado.json"
		if not FileAccess.file_exists(ruta_archivo):
			ui_editor.mostrar_notificacion("No se encontró ningún mapa guardado (.ntmap).")
			return
	cargar_mapa_desde_ruta(ruta_archivo)

func cargar_mapa_desde_ruta(ruta_archivo: String) -> void:
	if not FileAccess.file_exists(ruta_archivo):
		return
	var file = FileAccess.open(ruta_archivo, FileAccess.READ)
	if not file:
		return
	var texto = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(texto) == OK:
		var datos = json.data
		if datos is Dictionary:
			_ruta_mapa_actual = ruta_archivo
			if datos.has("nombre"):
				_nombre_mapa_actual = str(datos["nombre"])
			var dir_terreno := str(datos.get("terreno_dir", ""))
			if dir_terreno.is_empty():
				dir_terreno = ruta_archivo.get_basename() + "_terreno"
			if controlador_terreno and not dir_terreno.is_empty():
				controlador_terreno.cargar_terreno(dir_terreno)
			if datos.has("carreteras"):
				controlador_carreteras.deserializar_carreteras(datos["carreteras"])
			if datos.has("equipamiento_vias") and controlador_equipamiento:
				controlador_equipamiento.deserializar_equipamiento(datos["equipamiento_vias"])
			if datos.has("muros") and controlador_muros and datos["muros"] is Array:
				controlador_muros.deserializar_muros(datos["muros"])
			if datos.has("estacionamientos") and controlador_estacionamientos and datos["estacionamientos"] is Array:
				controlador_estacionamientos.deserializar_estacionamientos(datos["estacionamientos"])
			if datos.has("zonas_concreto") and controlador_concreto and datos["zonas_concreto"] is Array:
				controlador_concreto.deserializar_zonas(datos["zonas_concreto"])
			if datos.has("zonas_cs2") and controlador_zonificacion and datos["zonas_cs2"] is Array:
				controlador_zonificacion.deserializar_zonas(datos["zonas_cs2"])
			if datos.has("objetos"):
				controlador_objetos.deserializar_objetos(datos["objetos"])
			if datos.has("vegetacion_multimesh") and datos["vegetacion_multimesh"] is Dictionary:
				controlador_objetos.deserializar_vegetacion_multimesh(datos["vegetacion_multimesh"])
			if datos.has("cuerpos_agua") and controlador_agua:
				controlador_agua.deserializar_aguas(datos["cuerpos_agua"])
			if datos.has("spawn"):
				controlador_spawn.deserializar_spawn(datos["spawn"])
			if datos.has("hora_dia"):
				_cambiar_hora_dia(int(datos["hora_dia"]))
			ui_editor.mostrar_notificacion("¡Mapa '%s' cargado!" % _nombre_mapa_actual)

func _guardar_snapshot_vias() -> void:
	if not controlador_carreteras:
		return
	var snap := {
		"vias": controlador_carreteras.serializar_carreteras(),
		"equip": controlador_equipamiento.serializar_equipamiento() if controlador_equipamiento else []
	}
	_historial_vias_undo.append(snap)
	if _historial_vias_undo.size() > 20:
		_historial_vias_undo.pop_front()
	_historial_vias_redo.clear()

func _deshacer_accion() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()
		ui_editor.mostrar_notificacion("Acción deshecha.")
	elif not _historial_vias_undo.is_empty():
		var actual := {
			"vias": controlador_carreteras.serializar_carreteras(),
			"equip": controlador_equipamiento.serializar_equipamiento() if controlador_equipamiento else []
		}
		_historial_vias_redo.append(actual)
		var prev: Dictionary = _historial_vias_undo.pop_back()
		controlador_carreteras.deserializar_carreteras(prev.get("vias", []))
		if controlador_equipamiento:
			controlador_equipamiento.deserializar_equipamiento(prev.get("equip", []))
		ui_editor.mostrar_notificacion("Acción vial deshecha.")
	else:
		controlador_carreteras.deshacer_ultimo_punto()
		ui_editor.mostrar_notificacion("Último punto de vía deshecho.")

func _rehacer_accion() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		ui_editor.mostrar_notificacion("Acción rehecha.")
	elif not _historial_vias_redo.is_empty():
		var actual := {
			"vias": controlador_carreteras.serializar_carreteras(),
			"equip": controlador_equipamiento.serializar_equipamiento() if controlador_equipamiento else []
		}
		_historial_vias_undo.append(actual)
		var sig: Dictionary = _historial_vias_redo.pop_back()
		controlador_carreteras.deserializar_carreteras(sig.get("vias", []))
		if controlador_equipamiento:
			controlador_equipamiento.deserializar_equipamiento(sig.get("equip", []))
		ui_editor.mostrar_notificacion("Acción vial rehecha.")
	else:
		ui_editor.mostrar_notificacion("No hay acciones por rehacer.")

func _cambiar_hora_dia(hora: int) -> void:
	hora_actual_editor = hora
	if _sky_mat_editor:
		match hora:
			0: # Amanecer
				_sky_mat_editor.sky_top_color = Color(0.26, 0.36, 0.58, 1.0)
				_sky_mat_editor.sky_horizon_color = Color(0.86, 0.62, 0.44, 1.0)
			1: # Mediodía
				_sky_mat_editor.sky_top_color = Color(0.20, 0.44, 0.76, 1.0)
				_sky_mat_editor.sky_horizon_color = Color(0.62, 0.76, 0.88, 1.0)
			2: # Atardecer
				_sky_mat_editor.sky_top_color = Color(0.18, 0.22, 0.42, 1.0)
				_sky_mat_editor.sky_horizon_color = Color(0.90, 0.52, 0.24, 1.0)
			3: # Noche
				_sky_mat_editor.sky_top_color = Color(0.03, 0.04, 0.08, 1.0)
				_sky_mat_editor.sky_horizon_color = Color(0.06, 0.09, 0.16, 1.0)
	
	if controlador_sol_luna:
		match hora:
			0: # Amanecer (06:30)
				controlador_sol_luna.hora_actual = 6.5
				_actualizar_luces_nocturnas(false)
				ui_editor.mostrar_notificacion("Hora cambiada: 🌅 Amanecer (06:30)")
			1: # Mediodía (12:00)
				controlador_sol_luna.hora_actual = 12.0
				_actualizar_luces_nocturnas(false)
				ui_editor.mostrar_notificacion("Hora cambiada: ☀️ Mediodía (12:00)")
			2: # Atardecer (18:15)
				controlador_sol_luna.hora_actual = 18.25
				_actualizar_luces_nocturnas(false)
				ui_editor.mostrar_notificacion("Hora cambiada: 🌇 Atardecer (18:15)")
			3: # Noche (22:00)
				controlador_sol_luna.hora_actual = 22.5
				_actualizar_luces_nocturnas(true)
				ui_editor.mostrar_notificacion("Hora cambiada: 🌙 Noche (22:30) — Alumbrado encendido")
	else:
		var sol = find_child("DirectionalLight3D", true, false) as DirectionalLight3D
		if sol:
			match hora:
				0: sol.rotation_degrees = Vector3(-15.0, 75.0, 0.0)
				1: sol.rotation_degrees = Vector3(-65.0, 45.0, 0.0)
				2: sol.rotation_degrees = Vector3(-12.0, -80.0, 0.0)
				3: sol.rotation_degrees = Vector3(45.0, 45.0, 0.0)

func _actualizar_luces_nocturnas(activar: bool) -> void:
	if not controlador_equipamiento:
		return
	var cola: Array[Node] = [controlador_equipamiento]
	while not cola.is_empty():
		var n = cola.pop_front()
		if n is Light3D:
			(n as Light3D).visible = activar
		for h in n.get_children():
			cola.append(h)

func _abrir_disenador_casa_modular(editar_sel: bool) -> void:
	var cfg := controlador_objetos.config_casa_modular_actual.duplicate(true)
	if editar_sel and controlador_objetos.objeto_seleccionado and controlador_objetos.objeto_seleccionado.get_meta("es_casa_modular", false):
		cfg = controlador_objetos.objeto_seleccionado.get_meta("config_casa", cfg).duplicate(true)

	var disenador := UIDisenadorCasaModular.new()
	ui_editor.add_child(disenador)
	disenador.abrir_con_config(cfg)
	disenador.casa_confirmada.connect(func(nueva_cfg: Dictionary):
		if editar_sel and controlador_objetos.aplicar_config_a_casa_seleccionada(nueva_cfg):
			ui_editor.mostrar_notificacion("Casa modular actualizada.")
		else:
			controlador_objetos.establecer_config_casa_modular(nueva_cfg)
			_categoria_activa = "ciudad"
			_subherramienta_activa = "casa_modular"
			ui_editor.mostrar_notificacion("Casa modular lista. Toca el mapa para colocarla.")
	)

func _on_variacion_garaje_cambiada(nuevo_id: String) -> void:
	controlador_objetos.seleccionar_objeto(nuevo_id)
	var obj_objetivo: Node3D = null
	if is_instance_valid(controlador_objetos.objeto_seleccionado):
		var id_sel := str(controlador_objetos.objeto_seleccionado.get_meta("id_modelo", ""))
		if id_sel in ["garaje_camiones", "garaje_doble", "garaje_terminal", "garaje_moderno"]:
			obj_objetivo = controlador_objetos.objeto_seleccionado
	if not is_instance_valid(obj_objetivo) and has_meta("ultimo_garaje_colocado"):
		var ult = get_meta("ultimo_garaje_colocado")
		if ult is Node3D and is_instance_valid(ult):
			obj_objetivo = ult
	if is_instance_valid(obj_objetivo):
		var nuevo_obj := controlador_objetos.reemplazar_objeto_en_sitio(obj_objetivo, nuevo_id)
		if is_instance_valid(nuevo_obj):
			set_meta("ultimo_garaje_colocado", nuevo_obj)
			ui_editor.mostrar_notificacion("✓ Variación cambiada: %s" % nuevo_id.replace("_", " ").capitalize())
