class_name ControladorTerreno
extends Node3D

## ControladorTerreno.gd — Integración de Terrain3D para escultura y pintado en tiempo real
## Permite modificar elevaciones (elevar, bajar, aplanar, suavizar) y texturizar el terreno móvil.

signal terreno_modificado()

enum ModoTerreno {
	ELEVAR,
	BAJAR,
	APLANAR,
	SUAVIZAR,
	PINTAR_CESPED,
	PINTAR_TIERRA,
	PINTAR_ROCA
}

@export var modo_actual: ModoTerreno = ModoTerreno.ELEVAR
@export var radio_pincel: float = 25.0
@export var fuerza_pincel: float = 0.4
@export var altura_objetivo: float = 10.0

var terrain: Terrain3D
var terrain_editor: Terrain3DEditor
var _cursor_pincel: MeshInstance3D
var _cursor_centro: MeshInstance3D
var _trazo_activo: bool = false
var _brush_images: Array = []
var perfil_actual: int = 0 # 0: Suave, 1: Medio, 2: Fuerte

func _ready() -> void:
	_cargar_pincel_por_defecto()
	_crear_cursor_pincel()
	_inicializar_terreno()

func _inicializar_terreno() -> void:
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.free_editor_textures = false
	
	# Usar material con shader liviano para prevenir fallos de compilación SPIR-V en GPU móvil/Intel
	var mat := Terrain3DMaterial.new()
	var shader_path := "res://addons/terrain_3d/extras/shaders/lightweight.gdshader"
	if ResourceLoader.exists(shader_path):
		mat.shader_override = load(shader_path)
		mat.shader_override_enabled = true
	mat.world_background = Terrain3DMaterial.NONE
	terrain.material = mat
	
	# Asignar recursos existentes de texturas y mallas si están disponibles
	if ResourceLoader.exists("res://demo/data/assets.tres"):
		terrain.assets = load("res://demo/data/assets.tres")
		
	# Si existen regiones de mapa base guardadas en demo/data, utilizarlas
	if DirAccess.dir_exists_absolute("res://demo/data") and FileAccess.file_exists("res://demo/data/terrain3d_00_00.res"):
		terrain.data_directory = "res://demo/data"
		
	add_child(terrain)
	
	# Si no hay data preexistente, crear región plana base limpia
	if terrain.data and terrain.data.get_region_count() == 0:
		terrain.data.add_region_blankp(Vector3.ZERO)
	
	# Inicializar el editor nativo Terrain3DEditor
	terrain_editor = Terrain3DEditor.new()
	terrain_editor.set_terrain(terrain)
	actualizar_parametros_pincel()

func configurar_camara(cam: Camera3D) -> void:
	if terrain and is_instance_valid(terrain) and cam and is_instance_valid(cam):
		terrain.set_camera(cam)
		terrain.set_clipmap_target(cam)

func _cargar_pincel_por_defecto() -> void:
	var path_brush = "res://addons/terrain_3d/brushes/circle1.exr"
	if FileAccess.file_exists(path_brush):
		var img = Image.load_from_file(path_brush)
		if img:
			img.resize(512, 512, Image.INTERPOLATE_CUBIC)
			var tex = ImageTexture.create_from_image(img)
			_brush_images = [img, tex]
			return

	# Fallback procedimental para garantizar siempre [Image, Texture]
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RF)
	var centro := Vector2(128, 128)
	var radio_max := 128.0
	for x in 256:
		for y in 256:
			var d = centro.distance_to(Vector2(x, y))
			var v = clamp(1.0 - (d / radio_max), 0.0, 1.0)
			v = smoothstep(0.0, 1.0, v)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	var tex = ImageTexture.create_from_image(img)
	_brush_images = [img, tex]

func _crear_cursor_pincel() -> void:
	_cursor_pincel = MeshInstance3D.new()
	_cursor_pincel.name = "CursorPincel"
	
	var torus = TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.0
	torus.rings = 36
	torus.ring_segments = 4
	_cursor_pincel.mesh = torus
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.773, 0.180, 0.95) # Amarillo dorado #FFC52E
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_pincel.material_override = mat
	_cursor_pincel.visible = false
	add_child(_cursor_pincel)

	_cursor_centro = MeshInstance3D.new()
	_cursor_centro.name = "CursorCentro"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.65
	cyl.bottom_radius = 0.65
	cyl.height = 0.08
	_cursor_centro.mesh = cyl
	var mat_c = StandardMaterial3D.new()
	mat_c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_c.albedo_color = Color(1.0, 0.773, 0.180, 0.98) # Punto central amarillo brillante
	_cursor_centro.material_override = mat_c
	_cursor_centro.visible = false
	add_child(_cursor_centro)

func actualizar_cursor(pos_mundo: Vector3, visible_en_pantalla: bool) -> void:
	if not _cursor_pincel:
		return
	_cursor_pincel.visible = visible_en_pantalla
	if _cursor_centro:
		_cursor_centro.visible = visible_en_pantalla
	if visible_en_pantalla:
		var altura = obtener_altura(pos_mundo)
		_cursor_pincel.global_position = Vector3(pos_mundo.x, altura + 0.15, pos_mundo.z)
		_cursor_pincel.scale = Vector3(radio_pincel, 1.0, radio_pincel)
		if _cursor_centro:
			_cursor_centro.global_position = Vector3(pos_mundo.x, altura + 0.16, pos_mundo.z)

func establecer_perfil(tipo: int) -> void:
	perfil_actual = clamp(tipo, 0, 2)
	_generar_textura_perfil()
	actualizar_parametros_pincel()

func _generar_textura_perfil() -> void:
	var img := Image.create_empty(256, 256, false, Image.FORMAT_RF)
	var centro := Vector2(128, 128)
	var radio_max := 128.0
	for x in 256:
		for y in 256:
			var d = centro.distance_to(Vector2(x, y))
			var dist_norm = clamp(d / radio_max, 0.0, 1.0)
			var v: float = 0.0
			match perfil_actual:
				0: # Suave (Gaussian/Smoothstep)
					v = smoothstep(1.0, 0.0, dist_norm)
				1: # Medio (Linear Cone)
					v = clamp(1.0 - dist_norm, 0.0, 1.0)
				2: # Fuerte (Pico escarpado)
					v = pow(clamp(1.0 - dist_norm, 0.0, 1.0), 0.45)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	var tex = ImageTexture.create_from_image(img)
	_brush_images = [img, tex]

func establecer_modo(nuevo_modo: ModoTerreno) -> void:
	modo_actual = nuevo_modo
	actualizar_parametros_pincel()

func establecer_radio(radio: float) -> void:
	radio_pincel = clamp(radio, 3.0, 150.0)
	actualizar_parametros_pincel()

func establecer_fuerza(fuerza: float) -> void:
	fuerza_pincel = clamp(fuerza, 0.05, 1.0)
	actualizar_parametros_pincel()

func establecer_altura_objetivo(altura: float) -> void:
	altura_objetivo = altura
	actualizar_parametros_pincel()

func actualizar_parametros_pincel() -> void:
	if not terrain_editor:
		return
		
	var dict_brush := {
		"size": radio_pincel,
		"strength": fuerza_pincel * 100.0,
		"height": altura_objetivo,
		"color": Color.WHITE,
		"roughness": 0.0,
		"align_to_view": false,
		"gamma": 1.0,
		"show_brush_texture": false,
		"invert": false
	}
	
	if _brush_images.size() >= 2:
		dict_brush["brush"] = _brush_images

	match modo_actual:
		ModoTerreno.ELEVAR:
			terrain_editor.set_tool(Terrain3DEditor.SCULPT)
			terrain_editor.set_operation(Terrain3DEditor.ADD)
		ModoTerreno.BAJAR:
			terrain_editor.set_tool(Terrain3DEditor.SCULPT)
			terrain_editor.set_operation(Terrain3DEditor.SUBTRACT)
		ModoTerreno.APLANAR:
			terrain_editor.set_tool(Terrain3DEditor.HEIGHT)
			terrain_editor.set_operation(Terrain3DEditor.REPLACE)
		ModoTerreno.SUAVIZAR:
			terrain_editor.set_tool(Terrain3DEditor.SCULPT)
			terrain_editor.set_operation(Terrain3DEditor.AVERAGE)
		ModoTerreno.PINTAR_CESPED:
			terrain_editor.set_tool(Terrain3DEditor.TEXTURE)
			terrain_editor.set_operation(Terrain3DEditor.REPLACE)
			dict_brush["texture_asset_ids"] = [0]
		ModoTerreno.PINTAR_TIERRA:
			terrain_editor.set_tool(Terrain3DEditor.TEXTURE)
			terrain_editor.set_operation(Terrain3DEditor.REPLACE)
			dict_brush["texture_asset_ids"] = [1]
		ModoTerreno.PINTAR_ROCA:
			terrain_editor.set_tool(Terrain3DEditor.TEXTURE)
			terrain_editor.set_operation(Terrain3DEditor.REPLACE)
			dict_brush["texture_asset_ids"] = [2]
			
	terrain_editor.set_brush_data(dict_brush)

func comenzar_trazo(pos_mundo: Vector3) -> void:
	if not terrain_editor:
		return
	_trazo_activo = true
	actualizar_parametros_pincel()
	terrain_editor.start_operation(pos_mundo)
	terrain_editor.operate(pos_mundo, 0.0)
	terreno_modificado.emit()

func aplicar_trazo(pos_mundo: Vector3, rot_camara: float = 0.0) -> void:
	if not terrain_editor or not _trazo_activo:
		return
	terrain_editor.operate(pos_mundo, rot_camara)
	terreno_modificado.emit()

func finalizar_trazo() -> void:
	if not terrain_editor or not _trazo_activo:
		return
	_trazo_activo = false
	terrain_editor.stop_operation()
	terreno_modificado.emit()

func obtener_altura(pos_mundo: Vector3) -> float:
	if terrain and terrain.data:
		var h = terrain.data.get_height(pos_mundo)
		if not is_nan(h):
			return h
	return 0.0

func raycast_terreno(origen_rayo: Vector3, dir_rayo: Vector3) -> Dictionary:
	var res := { "impacto": false, "posicion": Vector3.ZERO }
	
	if terrain:
		var p = terrain.get_intersection(origen_rayo, dir_rayo, true)
		if p.z < 3.0e38 and not is_nan(p.y):
			res["impacto"] = true
			res["posicion"] = p
			return res
	
	# Fallback a plano horizontal Y = 0 si está fuera de regiones
	if abs(dir_rayo.y) > 0.0001:
		var d = -origen_rayo.y / dir_rayo.y
		if d > 0.0:
			res["impacto"] = true
			res["posicion"] = origen_rayo + dir_rayo * d
			return res
			
	return res
