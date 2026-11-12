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
var controlador_agua: ControladorAgua = null
var _undo_redo: UndoRedo = UndoRedo.new()
var hora_actual_editor: int = 1
var controlador_sol_luna: ControladorSolLuna = null
var world_env_editor: WorldEnvironment = null # 0: Amanecer, 1: Mediodia, 2: Atardecer, 3: Noche

var _categoria_activa: String = "terreno"
var _subherramienta_activa: String = "elevar"
var _puntero_presionado: bool = false
var _puntos_rio_temp: Array[Vector3] = []
var _pos_puntero_pantalla: Vector2 = Vector2.ZERO
var _pos_impacto_terreno: Vector3 = Vector3.ZERO
var _impacto_valido: bool = false
var _arrastrando_punto_carretera: bool = false
var _punto_carretera_fue_arrastrado: bool = false
var _arrastrando_objeto: Node3D = null
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
	
	if controlador_objetos:
		controlador_objetos.controlador_terreno = controlador_terreno

	if camara_editor and controlador_terreno:
		controlador_terreno.configurar_camara(camara_editor.obtener_camara())
	ui_editor.mostrar_notificacion("¡Bienvenido al Editor de Mapas Nuestra Tierra!")

func _configurar_entorno_iluminacion() -> void:
	# Configuración idéntica a Principal.tscn con ControladorSolLuna y Shader de Cielo
	world_env_editor = find_child("WorldEnvironment", true, false) as WorldEnvironment
	if not world_env_editor:
		world_env_editor = WorldEnvironment.new()
		world_env_editor.name = "WorldEnvironment"
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		
		var sky_mat := ShaderMaterial.new()
		var sky_shader = load("res://shaders/cielo_sky.gdshader")
		if sky_shader:
			sky_mat.shader = sky_shader
			sky_mat.set_shader_parameter("sky_day", Color(0.24, 0.46, 0.72, 1))
			sky_mat.set_shader_parameter("horizon_day", Color(0.74, 0.8, 0.85, 1))
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
			sky_mat.set_shader_parameter("cloud_coverage", 0.48)
			sky_mat.set_shader_parameter("cloud_feather", 0.12)
			sky_mat.set_shader_parameter("cloud_depth", 3.5)
			sky_mat.set_shader_parameter("cloud_occlude_exponent", 1.5)
			if ResourceLoader.exists("res://recursos/cielo/nubes/clouds_07.tres"):
				sky_mat.set_shader_parameter("night_noise_01", load("res://recursos/cielo/nubes/clouds_07.tres"))
			if ResourceLoader.exists("res://recursos/cielo/nubes/clouds_05.tres"):
				sky_mat.set_shader_parameter("night_noise_02", load("res://recursos/cielo/nubes/clouds_05.tres"))
			sky_mat.set_shader_parameter("sun_scale", 0.045)
			sky_mat.set_shader_parameter("sun_strength", 14.0)
			sky_mat.set_shader_parameter("sun_color", Color(1, 0.97, 0.88, 1))
			sky_mat.set_shader_parameter("moon_scale", 0.035)
			sky_mat.set_shader_parameter("moon_strength", 9.0)
			sky_mat.set_shader_parameter("moon_color", Color(0.65, 0.75, 0.95, 1))
		
		var sky_res := Sky.new()
		sky_res.sky_material = sky_mat
		sky_res.process_mode = Sky.PROCESS_MODE_QUALITY
		env.sky = sky_res
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.745, 0.813, 0.873, 1)
		env.ambient_light_energy = 0.35
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.glow_enabled = true
		env.glow_intensity = 0.12
		env.fog_enabled = true
		env.fog_light_color = Color(0.7, 0.78, 0.85, 1)
		env.fog_density = 0.00035
		world_env_editor.environment = env
		add_child(world_env_editor)
	
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

# ── CONEXIÓN DE SEÑALES DE LA INTERFAZ ───────────────────────────────

var _senales_ui_conectadas: bool = false
var _senales_prueba_conectadas: bool = false

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
	ui_editor.terminar_tramo_via_solicitado.connect(func():
		controlador_carreteras.finalizar_tramo_actual()
		ui_editor.mostrar_notificacion("Tramo de carretera finalizado.")
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
		_modo_mover_objeto = false
	)
	
	# Navegación móvil de cámara
	ui_editor.camara_pan_solicitado.connect(func(dir): camara_editor.panear_direccion(dir))
	ui_editor.camara_zoom_solicitado.connect(func(f): camara_editor.zoom(f))
	ui_editor.camara_orbita_solicitada.connect(func(g): camara_editor.rotar_orbita(g))
	ui_editor.camara_cenital_solicitada.connect(func(): camara_editor.alternar_cenital())

func _conectar_senales_prueba() -> void:
	if _senales_prueba_conectadas:
		return
	_senales_prueba_conectadas = true
	modo_prueba.prueba_finalizada.connect(_on_prueba_finalizada)

# ── CAMBIO DE CATEGORÍAS Y HERRAMIENTAS ──────────────────────────────

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
	_actualizar_visibilidad_cursores()
	ui_editor.actualizar_estado_boton_colocar(_categoria_activa, _subherramienta_activa, controlador_objetos.modo_demolicion)

func _on_subherramienta_seleccionada(id_herramienta: String) -> void:
	_subherramienta_activa = id_herramienta
	
	if id_herramienta != "equipamiento_vias" and controlador_equipamiento:
		controlador_equipamiento.limpiar_seleccion_tramo()
		ui_editor.ocultar_panel_equipamiento_vias()
	match _categoria_activa:
		"agua":
			if _subherramienta_activa in ["lago_agua", "lago"]:
				var r_lago = ui_editor.obtener_radio_lago() if ui_editor.has_method("obtener_radio_lago") else 24.0
				var p_lago = ui_editor.obtener_profundidad_lago() if ui_editor.has_method("obtener_profundidad_lago") else 3.5
				var lago = controlador_agua.crear_lago(_pos_impacto_terreno, r_lago, p_lago)
				if lago:
					ui_editor.mostrar_notificacion("¡Lago creado exitosamente (Radio: %.0fm)!" % r_lago)
			elif _subherramienta_activa in ["rio_agua", "rio"]:
				var pt = _pos_impacto_terreno
				if not _puntos_rio_temp:
					_puntos_rio_temp = []
				_puntos_rio_temp.append(pt)
				var w_rio = ui_editor.obtener_ancho_rio() if ui_editor.has_method("obtener_ancho_rio") else 8.0
				if _puntos_rio_temp.size() >= 2:
					controlador_agua.crear_tramo_rio(_puntos_rio_temp, w_rio)
					ui_editor.mostrar_notificacion("Tramo de río extendido (%d puntos, ancho %.0fm)" % [_puntos_rio_temp.size(), w_rio])
				else:
					ui_editor.mostrar_notificacion("Primer nodo del río fijado. Toca más puntos en el terreno.")
		"terreno":
			match id_herramienta:
				"elevar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.ELEVAR)
				"bajar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.BAJAR)
				"aplanar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.APLANAR)
				"suavizar": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.SUAVIZAR)
				"cesped", "pintar_cesped": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.PINTAR_CESPED)
				"tierra", "pintar_tierra": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.PINTAR_TIERRA)
				"roca", "pintar_roca": controlador_terreno.establecer_modo(ControladorTerreno.ModoTerreno.PINTAR_ROCA)
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
					ui_editor.mostrar_notificacion("Trocha Rural seleccionada (Material Trocha.tres mejorado con huellones 3D y charcos).")
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
	else:
		controlador_objetos.rotar_objeto(45.0)
		ui_editor.mostrar_notificacion("Objeto rotado 45°")

func _actualizar_visibilidad_cursores() -> void:
	var en_terreno = (_categoria_activa == "terreno")
	var en_vias = (_categoria_activa == "vias")
	var en_objetos = (_categoria_activa in ["ciudad", "vegetacion"])
	var en_spawn = (_categoria_activa == "spawn")
	
	controlador_terreno.actualizar_cursor(_pos_impacto_terreno, _impacto_valido and en_terreno)
	controlador_carreteras.actualizar_cursor_via(_pos_impacto_terreno, _impacto_valido and en_vias)
	controlador_objetos.actualizar_cursor_objeto(_pos_impacto_terreno, _impacto_valido and en_objetos)
	controlador_spawn.actualizar_cursor_spawn(_pos_impacto_terreno, _impacto_valido and en_spawn)

# ── PROCESAMIENTO DE ENTRADA Y RAYCASTING AL MUNDO 3D ────────────────

func _unhandled_input(event: InputEvent) -> void:
	if modo_prueba.en_prueba:
		return
		
	# Manejar gestos táctiles multitouch de cámara (pinch zoom, dos dedos pan)
	if camara_editor.manejar_evento_pantalla(event):
		return
		
	# Atajos de teclado en escritorio (Espacio / Enter para colocar, R para rotar)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
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
			if _arrastrando_objeto:
				if is_instance_valid(_arrastrando_objeto):
					controlador_objetos.mover_objeto(_arrastrando_objeto, _pos_impacto_terreno)
					ui_editor.mostrar_notificacion("✓ Objeto reposicionado")
				_arrastrando_objeto = null
			if _arrastrando_punto_carretera:
				_arrastrando_punto_carretera = false
				if _punto_carretera_fue_arrastrado and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
					controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, false)
					ui_editor.actualizar_datos_panel_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
					ui_editor.mostrar_notificacion("✓ Carretera actualizada")
				_punto_carretera_fue_arrastrado = false
		elif not (ui_editor and ui_editor.esta_sobre_interfaz(event.position)):
			_puntero_presionado = true
			_pos_puntero_pantalla = event.position
			_pos_toque_pantalla_anterior = event.position
			_actualizar_raycast_terreno()
			var toco_elemento = _verificar_seleccion_en_click()
			if not toco_elemento and not _arrastrando_punto_carretera and not _arrastrando_objeto:
				# Solo permitir arrastrar cámara con 1 dedo si estamos en vías en espacio libre
				if _categoria_activa == "vias":
					_arrastrando_camara = true
			
	elif event is InputEventScreenDrag:
		if ui_editor and ui_editor.esta_sobre_interfaz(event.position):
			return
		_pos_puntero_pantalla = event.position
		_actualizar_raycast_terreno()
		if _arrastrando_objeto and is_instance_valid(_arrastrando_objeto):
			controlador_objetos.mover_objeto(_arrastrando_objeto, _pos_impacto_terreno)
		elif _arrastrando_punto_carretera and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
			if event.position.distance_to(_pos_toque_pantalla_anterior) > 5.0 or _punto_carretera_fue_arrastrado:
				_punto_carretera_fue_arrastrado = true
				controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, true)
		elif _categoria_activa == "terreno" and _puntero_presionado and _impacto_valido:
			controlador_terreno.comenzar_trazo(_pos_impacto_terreno)
			controlador_terreno.aplicar_trazo(_pos_impacto_terreno, camara_editor.angulo_yaw)
			controlador_terreno.finalizar_trazo()
		elif _arrastrando_camara:
			var delta_drag = event.position - _pos_toque_pantalla_anterior
			camara_editor.panear_por_arrastre(delta_drag)
			_pos_toque_pantalla_anterior = event.position
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_puntero_presionado = false
				_arrastrando_camara = false
				if _arrastrando_objeto:
					if is_instance_valid(_arrastrando_objeto):
						controlador_objetos.mover_objeto(_arrastrando_objeto, _pos_impacto_terreno)
						ui_editor.mostrar_notificacion("✓ Objeto reposicionado")
					_arrastrando_objeto = null
				if _arrastrando_punto_carretera:
					_arrastrando_punto_carretera = false
					if _punto_carretera_fue_arrastrado and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
						controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, false)
						ui_editor.actualizar_datos_panel_punto_via(controlador_carreteras.obtener_datos_punto_seleccionado())
						ui_editor.mostrar_notificacion("✓ Carretera actualizada")
					_punto_carretera_fue_arrastrado = false
			elif not (ui_editor and ui_editor.esta_sobre_interfaz(event.position)):
				_puntero_presionado = true
				_pos_puntero_pantalla = event.position
				_pos_toque_pantalla_anterior = event.position
				_actualizar_raycast_terreno()
				var toco_elemento = _verificar_seleccion_en_click()
				if not toco_elemento and not _arrastrando_punto_carretera and not _arrastrando_objeto:
					# Solo permitir arrastrar cámara con clic izquierdo si estamos en vías en espacio libre
					if _categoria_activa == "vias":
						_arrastrando_camara = true
				
	elif event is InputEventMouseMotion:
		# Sistema híbrido PC/Móvil: solo interactuar o mover si el usuario tiene el puntero presionado (clic y arrastre)
		if not _puntero_presionado:
			return
		if ui_editor and ui_editor.esta_sobre_interfaz(event.position):
			return
		_pos_puntero_pantalla = event.position
		_actualizar_raycast_terreno()
		if _arrastrando_objeto and is_instance_valid(_arrastrando_objeto):
			controlador_objetos.mover_objeto(_arrastrando_objeto, _pos_impacto_terreno)
		elif _arrastrando_punto_carretera and is_instance_valid(controlador_carreteras.punto_carretera_seleccionado):
			if event.position.distance_to(_pos_toque_pantalla_anterior) > 5.0 or _punto_carretera_fue_arrastrado:
				_punto_carretera_fue_arrastrado = true
				controlador_carreteras.mover_punto_carretera(controlador_carreteras.punto_carretera_seleccionado, _pos_impacto_terreno, true)
		elif _categoria_activa == "terreno" and _impacto_valido:
			controlador_terreno.comenzar_trazo(_pos_impacto_terreno)
			controlador_terreno.aplicar_trazo(_pos_impacto_terreno, camara_editor.angulo_yaw)
			controlador_terreno.finalizar_trazo()
		elif _arrastrando_camara:
			var delta_drag = event.position - _pos_toque_pantalla_anterior
			camara_editor.panear_por_arrastre(delta_drag)
			_pos_toque_pantalla_anterior = event.position

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

func _verificar_seleccion_en_click() -> bool:
	if not _impacto_valido:
		return false
		
	if _categoria_activa == "vias":
		if controlador_carreteras.modo_conectar_activo:
			return false
			
		# 0. Si el modo es equipamiento_vias: selección de tramos de Punto A a Punto B
		if _subherramienta_activa == "equipamiento_vias":
			var rp_equip = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 6.5)
			if rp_equip != null:
				var res_equip = controlador_equipamiento.procesar_clic_punto(rp_equip)
				ui_editor.mostrar_notificacion(res_equip.get("mensaje", ""))
				return true
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
		var obj_cercano = controlador_objetos.buscar_objeto_cercano(_pos_impacto_terreno, 4.0)
		if obj_cercano != null:
			if controlador_objetos.modo_demolicion:
				controlador_objetos.demoler_en_posicion(_pos_impacto_terreno)
				ui_editor.mostrar_notificacion("Elemento demolido")
				return true
			
			# Si ya está seleccionado este mismo objeto, permitir arrastrarlo
			if controlador_objetos.objeto_seleccionado == obj_cercano:
				_arrastrando_objeto = obj_cercano
				return true
			else:
				# Primer clic: Seleccionar y mostrar caja delimitadora e inspector
				var datos = controlador_objetos.seleccionar_objeto_en_escena(obj_cercano)
				ui_editor.mostrar_panel_edicion_objeto(datos)
				ui_editor.mostrar_notificacion("%s seleccionado" % datos.get("nombre", "Objeto"))
				_arrastrando_objeto = null # NO mover en el primer toque
				return true
		else:
			# Clic en terreno vacío
			if is_instance_valid(controlador_objetos.objeto_seleccionado):
				if _modo_mover_objeto:
					# Reposicionar el objeto seleccionado al punto tocado
					controlador_objetos.mover_objeto(controlador_objetos.objeto_seleccionado, _pos_impacto_terreno)
					ui_editor.actualizar_datos_panel_objeto(controlador_objetos.obtener_datos_objeto_seleccionado())
					ui_editor.mostrar_notificacion("✓ Objeto reposicionado")
					return true
				else:
					# Deseleccionar al tocar terreno vacío lejano
					controlador_objetos.deseleccionar_objeto()
					ui_editor.ocultar_panel_edicion_objeto()

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
		"terreno":
			if _subherramienta_activa == "lago_agua":
				var lago = controlador_agua.crear_lago(_pos_impacto_terreno, 24.0, 3.5)
				if lago:
					ui_editor.mostrar_notificacion("¡Lago procedural creado con shader de agua realista!")
			elif _subherramienta_activa == "rio_agua":
				var pt = _pos_impacto_terreno
				if not _puntos_rio_temp:
					_puntos_rio_temp = []
				_puntos_rio_temp.append(pt)
				if _puntos_rio_temp.size() >= 2:
					controlador_agua.crear_tramo_rio(_puntos_rio_temp, 8.0)
					ui_editor.mostrar_notificacion("Tramo de río extendido (%d puntos)" % _puntos_rio_temp.size())
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
		"ciudad":
			if controlador_objetos.modo_demolicion:
				if controlador_objetos.demoler_en_posicion(_pos_impacto_terreno):
					ui_editor.mostrar_notificacion("Elemento demolido")
				else:
					ui_editor.mostrar_notificacion("No se encontró ningún elemento en ese punto")
			else:
				var obj = controlador_objetos.colocar_objeto(_pos_impacto_terreno)
				if obj:
					var nombre_item = controlador_objetos.id_objeto_seleccionado.replace("_", " ").capitalize()
					ui_editor.mostrar_notificacion("¡%s colocado exitosamente!" % nombre_item)
		"vias":
			if _subherramienta_activa == "equipamiento_vias":
				if not controlador_equipamiento.tramo_segmentos.is_empty():
					var res_ap = controlador_equipamiento.aplicar_equipamiento_actual()
					ui_editor.mostrar_notificacion(res_ap.get("mensaje", "Equipamiento aplicado"))
					if res_ap.get("exito", false):
						controlador_carreteras.nivelar_terreno_bajo_carreteras()
				else:
					var rp_col = controlador_carreteras.buscar_punto_carretera_cercano(_pos_impacto_terreno, 6.5)
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
			elif _subherramienta_activa in ["cruce_4", "cruce_t"]:
				var rot = controlador_carreteras.rotacion_cruce_grados
				var inter = controlador_carreteras.crear_cruce(_pos_impacto_terreno, _subherramienta_activa, rot)
				if inter:
					var nombre_cruce = "Cruce de 4 Vías" if _subherramienta_activa == "cruce_4" else "Cruce en T"
					ui_editor.mostrar_notificacion("¡%s colocado!" % nombre_cruce)
			elif controlador_carreteras.modo_conectar_activo:
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
						
				var rp_previo = controlador_carreteras.punto_snap_detectado
				var es_conexion = (rp_previo != null and rp_previo != controlador_carreteras._ultimo_road_point)
				controlador_carreteras.agregar_punto_carretera(_pos_impacto_terreno)
				if es_conexion:
					ui_editor.mostrar_notificacion("¡Vías conectadas exitosamente!")
				else:
					ui_editor.mostrar_notificacion("Punto de vía colocado")
		"spawn":
			controlador_spawn.posicionar_spawn(_pos_impacto_terreno)
			ui_editor.mostrar_notificacion("Punto de Spawn posicionado")
		"terreno":
			controlador_terreno.comenzar_trazo(_pos_impacto_terreno)
			controlador_terreno.aplicar_trazo(_pos_impacto_terreno, camara_editor.angulo_yaw)
			controlador_terreno.finalizar_trazo()
			if controlador_carreteras and not controlador_carreteras._puntos_creados.is_empty():
				controlador_carreteras.nivelar_terreno_bajo_carreteras()
			ui_editor.mostrar_notificacion("Terreno modificado")

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
	# Ocultar cámara, UI y marcadores del editor
	if camara_editor:
		camara_editor.visible = false
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
	# Restaurar cámara, UI y marcadores del editor
	if is_instance_valid(controlador_spawn):
		controlador_spawn.visible = true
	if camara_editor:
		camara_editor.visible = true
		var cam = camara_editor.obtener_camara()
		if cam:
			cam.current = true
	if ui_editor:
		ui_editor.visible = true
		ui_editor.mostrar_notificacion("Has vuelto al editor de mapas")

# ── GUARDAR Y CARGAR MAPAS (PERSISTENCIA COMPLETA) ───────────────────

func guardar_mapa() -> void:
	var dir_mapas = "user://mapas"
	if not DirAccess.dir_exists_absolute(dir_mapas):
		DirAccess.make_dir_recursive_absolute(dir_mapas)
		
	var ruta_ntmap = dir_mapas + "/mapa_guardado.ntmap"
	var datos := {
		"formato": "NT_MAP",
		"version": 2,
		"autor": "EditorNuestraTierra",
		"hora_dia": hora_actual_editor,
		"objetos": controlador_objetos.serializar_objetos(),
		"vegetacion_multimesh": controlador_objetos.serializar_vegetacion_multimesh(),
		"carreteras": controlador_carreteras.serializar_carreteras(),
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
		ui_editor.mostrar_notificacion("¡Mapa exportado a paquete .ntmap exitosamente!")
	else:
		ui_editor.mostrar_notificacion("Error al guardar mapa.")

func cargar_mapa() -> void:
	var dir_mapas = "user://mapas"
	var ruta_archivo = dir_mapas + "/mapa_guardado.ntmap"
	if not FileAccess.file_exists(ruta_archivo):
		ruta_archivo = dir_mapas + "/mapa_guardado.json"
		if not FileAccess.file_exists(ruta_archivo):
			ui_editor.mostrar_notificacion("No se encontró ningún mapa guardado (.ntmap).")
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
			if datos.has("objetos"):
				controlador_objetos.deserializar_objetos(datos["objetos"])
			if datos.has("vegetacion_multimesh"):
				controlador_objetos.deserializar_vegetacion_multimesh(datos["vegetacion_multimesh"])
			if datos.has("cuerpos_agua") and controlador_agua:
				controlador_agua.deserializar_aguas(datos["cuerpos_agua"])
			if datos.has("spawn"):
				controlador_spawn.deserializar_spawn(datos["spawn"])
			if datos.has("hora_dia"):
				_cambiar_hora_dia(int(datos["hora_dia"]))
			ui_editor.mostrar_notificacion("¡Mapa .ntmap cargado exitosamente!")

func _deshacer_accion() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()
		ui_editor.mostrar_notificacion("Acción deshecha.")
	else:
		controlador_carreteras.deshacer_ultimo_punto()
		ui_editor.mostrar_notificacion("Último punto de vía deshecho.")

func _rehacer_accion() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		ui_editor.mostrar_notificacion("Acción rehecha.")
	else:
		ui_editor.mostrar_notificacion("No hay acciones por rehacer.")

func _cambiar_hora_dia(hora: int) -> void:
	hora_actual_editor = hora
	
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
