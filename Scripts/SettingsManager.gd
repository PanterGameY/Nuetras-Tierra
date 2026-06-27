extends Node

const SAVE_PATH = "user://settings.cfg"

var last_scene_path: String = ""
var _instancia_ui: Node = null
var current_sombras: int = 2

func change_to_settings() -> void:
	if _instancia_ui and is_instance_valid(_instancia_ui):
		_instancia_ui.visible = true
		return

	var path = "res://escenas/configuraciones/configuraciones.tscn"
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
	# Aplicar configuraciones al arrancar el juego
	apply_all_settings()
	get_tree().node_added.connect(_on_node_added)

func apply_all_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	
	if err != OK:
		print("[SettingsManager] No se pudo cargar settings.cfg (error %d), usando valores por defecto." % err)
		return

	_apply_graphics(cfg)
	_apply_audio(cfg)
	print("[SettingsManager] Configuraciones aplicadas correctamente.")

func _apply_graphics(cfg: ConfigFile) -> void:
	var vp = get_viewport()
	
	# Anti-aliasing
	var aa = cfg.get_value("graficos", "aa", 0)
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
	var sombras = cfg.get_value("graficos", "sombras", 2)
	var atlas_size = 0
	# Aplicar calidad de sombras en tiempo real
	# 0: Off, 1: Low, 2: Mid, 3: High
	match sombras:
		0:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 0)
			atlas_size = 0
		1:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 1024)
			atlas_size = 1024
		2:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 2048)
			atlas_size = 2048
		3:
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
			atlas_size = 4096

	vp.positional_shadow_atlas_size = atlas_size

	# Para que los cambios se apliquen en tiempo real a todas las luces direccionales del árbol
	var d_lights: Array = []
	_find_directional_lights(get_tree().root, d_lights)
	for dl in d_lights:
		if dl is DirectionalLight3D:
			dl.shadow_enabled = (sombras > 0)

	# Render scale & FSR
	var render_scale = cfg.get_value("graficos", "render_scale", 100) / 100.0
	var method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	if method == "forward_plus":
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
		env.ssao_enabled = cfg.get_value("graficos", "ssao_enabled", true)
		env.glow_enabled = cfg.get_value("graficos", "glow_enabled", true)
		env.sdfgi_enabled = cfg.get_value("graficos", "sdfgi_enabled", false)

	# Notificar a los optimizadores de ciudad activos
	var optimizers = get_tree().get_nodes_in_group("city_optimizer")
	for opt in optimizers:
		if opt.has_method("update_settings_from_config"):
			opt.update_settings_from_config()
	
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

func _find_directional_lights(node: Node, result: Array) -> void:
	if node is DirectionalLight3D:
		result.append(node)
	for child in node.get_children():
		_find_directional_lights(child, result)

func _on_node_added(node: Node) -> void:
	if node is DirectionalLight3D:
		node.shadow_enabled = (current_sombras > 0)
