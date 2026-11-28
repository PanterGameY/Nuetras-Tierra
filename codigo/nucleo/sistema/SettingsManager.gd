extends Node

const SAVE_PATH = "user://settings.cfg"

signal modo_pc_cambiado(activo: bool)

var last_scene_path: String = ""
var _instancia_ui: Node = null
var current_sombras: int = 2
var modo_pc: bool = false

func change_to_settings() -> void:
	if _instancia_ui and is_instance_valid(_instancia_ui):
		_instancia_ui.visible = true
		if _instancia_ui.has_method("_load_settings"):
			_instancia_ui.call("_load_settings")
		if _instancia_ui.has_method("_actualizar_ui_completa"):
			_instancia_ui.call("_actualizar_ui_completa")
		return

	var path = "res://interfaz/pantallas/configuraciones/configuraciones.tscn"
	var scn = load(path)
	if scn:
		_instancia_ui = scn.instantiate()
		# Aseguramos que sea una capa superior
		if _instancia_ui is CanvasLayer:
			_instancia_ui.layer = 100
		get_tree().root.add_child(_instancia_ui)
		_instancia_ui.visible = true
	else:
		push_error("[SettingsManager] No se pudo cargar configuraciones.tscn")

func return_from_settings() -> void:
	if _instancia_ui and is_instance_valid(_instancia_ui):
		_instancia_ui.visible = false

func _ready() -> void:
	_adaptar_ventana_pc()
	# Aplicar configuraciones al arrancar el juego
	apply_all_settings()
	get_tree().node_added.connect(_on_node_added)
	if get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_scene_changed)

func _es_modo_editor_mapas() -> bool:
	var tree := get_tree()
	if not tree:
		return false
	var escena := tree.current_scene
	if not is_instance_valid(escena):
		return false
	# EditorMapas tiene su propia configuración (user://editor_config.cfg) cuando está editando.
	# Cuando está en modo prueba o multijugador, debe usar las configuraciones del juego.
	if "modo_prueba" in escena and escena.get("modo_prueba") != null:
		var mp = escena.get("modo_prueba")
		var en_prueba := bool(mp.get("en_prueba")) if mp else false
		var en_mp := bool(escena.get("_en_modo_multijugador")) if "_en_modo_multijugador" in escena else false
		return not en_prueba and not en_mp
	return false

func _on_scene_changed() -> void:
	if _es_modo_editor_mapas():
		return
	call_deferred("apply_all_settings")

func _adaptar_ventana_pc() -> void:
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return
	if OS.get_name() in ["Windows", "Linux", "macOS"]:
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		if usable.size.x > 0 and usable.size.y > 0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func apply_all_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	
	if err != OK:
		print("[SettingsManager] No se pudo cargar settings.cfg (error %d), inicializando con preset Medio." % err)
		apply_preset(1)
		return

	_apply_audio(cfg)
	_apply_controls(cfg)
	if not _es_modo_editor_mapas():
		_apply_graphics(cfg)
	print("[SettingsManager] Configuraciones aplicadas correctamente.")

func apply_preset(preset_idx: int) -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	
	match preset_idx:
		0: # BAJO (Gama baja / móvil modesto)
			cfg.set_value("graficos", "calidad", 0)
			cfg.set_value("graficos", "cielo_calidad", 2)
			cfg.set_value("graficos", "sombras", 0)
			cfg.set_value("graficos", "aa", 0)
			cfg.set_value("graficos", "render_scale", 60)
			cfg.set_value("graficos", "fps", 0) # 30 FPS
			cfg.set_value("graficos", "ssao_enabled", false)
			cfg.set_value("graficos", "glow_enabled", false)
			cfg.set_value("graficos", "sdfgi_enabled", false)
		1: # MEDIO (Gama media)
			cfg.set_value("graficos", "calidad", 1)
			cfg.set_value("graficos", "cielo_calidad", 1)
			cfg.set_value("graficos", "sombras", 1)
			cfg.set_value("graficos", "aa", 1)
			cfg.set_value("graficos", "render_scale", 75)
			cfg.set_value("graficos", "fps", 1) # 60 FPS
			cfg.set_value("graficos", "ssao_enabled", false)
			cfg.set_value("graficos", "glow_enabled", false)
			cfg.set_value("graficos", "sdfgi_enabled", false)
		2: # ALTO (Estilo ATS - Optimizado)
			cfg.set_value("graficos", "calidad", 2)
			cfg.set_value("graficos", "cielo_calidad", 0)
			cfg.set_value("graficos", "sombras", 2)
			cfg.set_value("graficos", "aa", 1)
			cfg.set_value("graficos", "render_scale", 85)
			cfg.set_value("graficos", "fps", 1) # 60 FPS
			cfg.set_value("graficos", "ssao_enabled", false)
			cfg.set_value("graficos", "glow_enabled", true)
			cfg.set_value("graficos", "sdfgi_enabled", false)
		3: # ULTRA (Gama alta / PC)
			cfg.set_value("graficos", "calidad", 3)
			cfg.set_value("graficos", "cielo_calidad", 0)
			cfg.set_value("graficos", "sombras", 3)
			cfg.set_value("graficos", "aa", 2)
			cfg.set_value("graficos", "render_scale", 100)
			cfg.set_value("graficos", "fps", 1) # 60 FPS
			cfg.set_value("graficos", "ssao_enabled", true)
			cfg.set_value("graficos", "glow_enabled", true)
			cfg.set_value("graficos", "sdfgi_enabled", false)

	cfg.save(SAVE_PATH)
	_apply_graphics(cfg)
	print("[SettingsManager] Preset %d aplicado y guardado." % preset_idx)

func _apply_graphics(cfg: ConfigFile) -> void:
	var vp = get_viewport()
	var es_compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	
	# Anti-aliasing
	var aa = cfg.get_value("graficos", "aa", 0)
	if es_compat:
		# En OpenGL ES 3 (gl_compatibility), MSAA/FXAA en FBO puede invertir o corromper el Z-buffer en emuladores
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		match aa:
			0:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			1:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			2:
				vp.msaa_3d = Viewport.MSAA_2X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			3:
				vp.msaa_3d = Viewport.MSAA_4X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			4:
				vp.msaa_3d = Viewport.MSAA_8X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	# VSync
	var vsync = cfg.get_value("graficos", "vsync", true)
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Sombras
	var sombras = cfg.get_value("graficos", "sombras", 1)
	current_sombras = sombras
	var atlas_size = 0
	# Aplicar calidad de sombras en tiempo real a nivel de RenderingServer
	# 0: Off, 1: Low (1024), 2: Mid (2048), 3: High (4096)
	match sombras:
		0:
			# NUNCA asignar 0 a directional_shadow_atlas_set_size en Vulkan.
			# Asignar 0 destruye el framebuffer del atlas de sombras en la GPU.
			# Si cualquier luz tiene o activa shadow_enabled=true, Godot intenta
			# dibujar en un framebuffer nulo y explota con:
			# "Parameter framebuffer is null" / "draw_list_begin".
			# El apagado de sombras se hace mediante light.shadow_enabled = false.
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			atlas_size = 1024
		1:
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			atlas_size = 1024
		2:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			atlas_size = 2048
		3:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			atlas_size = 4096

	vp.positional_shadow_atlas_size = atlas_size

	# Aplicar en tiempo real a todas las luces del árbol
	var all_lights: Array = []
	_find_all_lights(get_tree().root, all_lights)
	for l in all_lights:
		_configurar_luz_sombras(l, sombras)

	# Render scale & FSR (40% - 100%)
	var render_pct: float = clampf(float(cfg.get_value("graficos", "render_scale", 75)), 40.0, 100.0)
	var render_scale := render_pct / 100.0
	var method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	if not es_compat and method == "forward_plus" and render_pct >= 60.0:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = render_scale

	# FPS cap
	var fps_idx = cfg.get_value("graficos", "fps", 1)
	var fps_values: Array[int] = [30, 60, 90, 120, 0]
	if fps_idx < fps_values.size():
		Engine.max_fps = fps_values[fps_idx]

	# Modificar Environment (SSAO, Glow, SDFGI) en tiempo real
	var env = vp.find_world_3d().environment if vp.find_world_3d() else null
	if env:
		_apply_environment_settings(env, cfg)

	# Notificar a los optimizadores de ciudad activos
	var optimizers = get_tree().get_nodes_in_group("city_optimizer")
	for opt in optimizers:
		if opt.has_method("update_settings_from_config"):
			opt.update_settings_from_config()

	# Aplicar la calidad de cielo guardada
	var cielo = _find_cielo_sistema(get_tree().root)
	if cielo:
		var cielo_calidad = cfg.get_value("graficos", "cielo_calidad", 2)
		if "perfil_calidad" in cielo:
			cielo.perfil_calidad = cielo_calidad
	
	# Asegurar que los cambios se propaguen al RenderingServer
	RenderingServer.force_draw(false)

func _apply_audio(cfg: ConfigFile) -> void:
	var master_vol = cfg.get_value("audio", "vol_general", 100) / 100.0
	var music_vol = cfg.get_value("audio", "musica", 80) / 100.0
	var sfx_vol = cfg.get_value("audio", "efectos", 100) / 100.0
	
	_set_bus_volume(0, master_vol)
	_set_bus_volume(1, music_vol)
	_set_bus_volume(2, sfx_vol)

func _set_bus_volume(bus_idx: int, linear: float) -> void:
	if bus_idx >= AudioServer.get_bus_count():
		return
	var db = linear_to_db(linear) if linear > 0.001 else -80.0
	AudioServer.set_bus_volume_db(bus_idx, db)

func _configurar_luz_sombras(l: Light3D, nivel_sombras: int) -> void:
	if not is_instance_valid(l):
		return
	if l is DirectionalLight3D:
		l.shadow_enabled = (nivel_sombras > 0)
		match nivel_sombras:
			1: # Baja
				l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				l.directional_shadow_max_distance = 80.0
				l.directional_shadow_blend_splits = false
			2: # Media
				l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				l.directional_shadow_max_distance = 140.0
				l.directional_shadow_blend_splits = true
			3: # Alta
				l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				l.directional_shadow_max_distance = 200.0
				l.directional_shadow_blend_splits = true
	elif l is Light3D:
		# Luces secundarias (faros vehiculares, postes)
		l.shadow_enabled = (nivel_sombras >= 2)

func _find_all_lights(node: Node, result: Array) -> void:
	if node is Light3D:
		result.append(node)
	for child in node.get_children():
		_find_all_lights(child, result)

func _find_directional_lights(node: Node, result: Array) -> void:
	_find_all_lights(node, result)

func _apply_environment_settings(env: Environment, cfg: ConfigFile) -> void:
	if not env:
		return
	env.ssao_enabled = bool(cfg.get_value("graficos", "ssao_enabled", false))
	env.glow_enabled = bool(cfg.get_value("graficos", "glow_enabled", false))
	env.sdfgi_enabled = bool(cfg.get_value("graficos", "sdfgi_enabled", false))

func _apply_controls(cfg: ConfigFile) -> void:
	var sv: int = int(cfg.get_value("controles", "sensibilidad_volante", 150))
	var s_dir: float = float(cfg.get_value("controles", "suavizado_direccion", 10.0))
	var r_vol: float = float(cfg.get_value("controles", "retorno_volante", 3.5))
	var s_ped: float = float(cfg.get_value("controles", "suavizado_pedales", 3.5))

	_apply_volante_sensitivity_recursive(get_tree().root, float(sv) / 100.0)

	var input_veh = get_node_or_null("/root/InputVehiculo")
	if input_veh:
		input_veh.suavizado_direccion = s_dir
		input_veh.retorno_volante = r_vol
		input_veh.suavizado_pedales = s_ped

	modo_pc = bool(cfg.get_value("controles", "modo_pc", false))
	modo_pc_cambiado.emit(modo_pc)
	_aplicar_modo_pc_en_arbol(get_tree().root, modo_pc)

func _aplicar_modo_pc_en_arbol(node: Node, activo: bool) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("aplicar_modo_pc"):
		node.call("aplicar_modo_pc", activo)
	for child in node.get_children():
		_aplicar_modo_pc_en_arbol(child, activo)

func _apply_volante_sensitivity_recursive(node: Node, s: float) -> void:
	for child in node.get_children():
		var scr = child.get_script()
		if scr and typeof(scr) == TYPE_OBJECT:
			var path = str(scr.resource_path)
			if path.find("volante") != -1:
				child.set("sensibilidad", s)
		_apply_volante_sensitivity_recursive(child, s)

func _on_node_added(node: Node) -> void:
	if node is SubViewport and RenderingServer.get_current_rendering_method() == "gl_compatibility":
		node.msaa_3d = Viewport.MSAA_DISABLED
		node.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		node.scaling_3d_scale = 1.0

	var scr = node.get_script()
	if scr and typeof(scr) == TYPE_OBJECT and str(scr.resource_path).find("volante") != -1:
		var cfg_v := ConfigFile.new()
		if cfg_v.load(SAVE_PATH) == OK:
			node.set("sensibilidad", float(cfg_v.get_value("controles", "sensibilidad_volante", 150)) / 100.0)

	if node.has_method("aplicar_modo_pc"):
		node.call_deferred("aplicar_modo_pc", modo_pc)

	if _es_modo_editor_mapas():
		return

	if node is Light3D:
		_configurar_luz_sombras(node, current_sombras)
	if node is WorldEnvironment:
		call_deferred("_aplicar_env_nodo", node)
	if node.name == "CieloSistema" or node.has_method("clima_despejado"):
		var cfg = ConfigFile.new()
		if cfg.load(SAVE_PATH) == OK:
			var cielo_calidad = cfg.get_value("graficos", "cielo_calidad", 2)
			if "perfil_calidad" in node:
				node.perfil_calidad = cielo_calidad
	if node.has_method("aplicar_configuracion_sombras"):
		node.call("aplicar_configuracion_sombras", current_sombras)

func _aplicar_env_nodo(node: Node) -> void:
	if not is_instance_valid(node) or not (node is WorldEnvironment):
		return
	if _es_modo_editor_mapas():
		return
	var we := node as WorldEnvironment
	if we.environment:
		var cfg := ConfigFile.new()
		if cfg.load(SAVE_PATH) == OK:
			_apply_environment_settings(we.environment, cfg)

func _find_cielo_sistema(node: Node) -> Node:
	if node.name == "CieloSistema" or node.has_method("clima_despejado"):
		return node
	for child in node.get_children():
		var found = _find_cielo_sistema(child)
		if found:
			return found
	return null
