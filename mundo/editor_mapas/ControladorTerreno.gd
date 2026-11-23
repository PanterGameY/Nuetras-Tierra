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
	PINTAR_ROCA,
	PINTAR_MATERIAL,
	PINTAR_FOLLAJE,
	BORRAR_FOLLAJE,
	PENDIENTE,
	LOTES
}

const MATERIALES_PINTURA: Array[Dictionary] = [
	{
		"id": "cesped_verde",
		"nombre": "Césped Verde",
		"categoria": "pastos",
		"tipo": "Pasto / Pradera",
		"descripcion": "Césped verde vivo y denso de pradera húmeda.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde_normal.png",
		"fallback": "res://materiales/Mapa/Cesped/Grass004_2K_Color.jpg",
		"tinte": Color.WHITE
	},
	{
		"id": "pasto_kikuyo",
		"nombre": "Pasto Kikuyo",
		"categoria": "pastos",
		"tipo": "Pasto / Andino",
		"descripcion": "Kikuyo espeso colombiano de finca y potrero verde.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/pasto_kikuyo.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/pasto_kikuyo_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde.png",
		"tinte": Color.WHITE
	},
	{
		"id": "trebol_pradera",
		"nombre": "Pradera Trébol",
		"categoria": "pastos",
		"tipo": "Pasto / Jardín",
		"descripcion": "Pradera con tréboles y pequeñas flores silvestres.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/trebol_pradera.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/trebol_pradera_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_verde.png",
		"tinte": Color.WHITE
	},
	{
		"id": "cesped_seco",
		"nombre": "Césped Seco",
		"categoria": "pastos",
		"tipo": "Pasto / Sabana",
		"descripcion": "Pasto seco dorado-oliva de sabana o potrero.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_seco.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_seco_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/pasto_cesped/Cesped_2.png",
		"tinte": Color.WHITE
	},
	{
		"id": "cesped_paramo",
		"nombre": "Pajonal Páramo",
		"categoria": "pastos",
		"tipo": "Pasto / Montaña",
		"descripcion": "Pajonal andino dorado-oliva sobre suelo oscuro de altura.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_paramo.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_paramo_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cesped_seco.png",
		"tinte": Color.WHITE
	},
	{
		"id": "musgo_bosque",
		"nombre": "Musgo Bosque",
		"categoria": "pastos",
		"tipo": "Pasto / Sotobosque",
		"descripcion": "Musgo profundo de bosque húmedo con hojarasca.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/musgo_bosque.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/musgo_bosque_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/pasto_cesped/Cesped_1.png",
		"tinte": Color.WHITE
	},
	{
		"id": "tierra_fertil",
		"nombre": "Tierra Fértil",
		"categoria": "suelos",
		"tipo": "Suelo / Orgánico",
		"descripcion": "Tierra oscura fértil con grumos y gravilla fina.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/tierra_fertil.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/tierra_fertil_normal.png",
		"fallback": "res://materiales/Mapa/ground/Ground103_1K-JPG_Color.jpg",
		"tinte": Color.WHITE
	},
	{
		"id": "barro_arcilla",
		"nombre": "Barro Arcilla",
		"categoria": "suelos",
		"tipo": "Suelo / Húmedo",
		"descripcion": "Arcilla rojiza andina húmeda con grietas finas.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/barro_arcilla.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/barro_arcilla_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/tierra_barro/Tierra_1.png",
		"tinte": Color.WHITE
	},
	{
		"id": "arena_grava",
		"nombre": "Arena y Grava",
		"categoria": "suelos",
		"tipo": "Suelo / Ribera",
		"descripcion": "Arena natural de río mezclada con cantos suaves.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/arena_grava.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/arena_grava_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/tierra_barro/Tierra_2.png",
		"tinte": Color.WHITE
	},
	{
		"id": "cascajo_recebo",
		"nombre": "Cascajo",
		"categoria": "rocas",
		"tipo": "Piedra / Trocha",
		"descripcion": "Recebo y piedra triturada compacta para caminos.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cascajo_recebo.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/cascajo_recebo_normal.png",
		"fallback": "res://materiales/Mapa/Trocha/trocha_cascajo_albedo.png",
		"tinte": Color.WHITE
	},
	{
		"id": "roca_gris",
		"nombre": "Roca Gris",
		"categoria": "rocas",
		"tipo": "Roca / Montaña",
		"descripcion": "Granito y andesita gris andina con fracturas.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_gris_normal.png",
		"fallback": "res://demo/assets/textures/rock023_alb_ht.png",
		"tinte": Color.WHITE
	},
	{
		"id": "roca_ocre",
		"nombre": "Roca Ocre",
		"categoria": "rocas",
		"tipo": "Roca / Acantilado",
		"descripcion": "Arenisca ocre estratificada de talud o acantilado.",
		"albedo": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_ocre.png",
		"normal": "res://recursos/texturas/mapas/01_terrenos/pincel_pbr/roca_ocre_normal.png",
		"fallback": "res://recursos/texturas/mapas/01_terrenos/rocas_acantilados/roca-amarilla.jpg",
		"tinte": Color.WHITE
	}
]

const FOLLAJE_CATALOGO: Array[Dictionary] = [
	{
		"id": "follaje_cesped_fino",
		"mesh_id": 0,
		"nombre": "Césped Fino",
		"categoria": "pastos",
		"tipo": "Césped 3D / Pradera",
		"descripcion": "Matas densas de césped verde corto para praderas y bordes.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_cesped_fino.png",
		"height_offset": 0.25,
		"density": 12.0,
		"escala": 95.0
	},
	{
		"id": "follaje_pasto_alto",
		"mesh_id": 1,
		"nombre": "Pasto Alto",
		"categoria": "pastos",
		"tipo": "Césped 3D / Potrero",
		"descripcion": "Brizna alta silvestre ideal para potreros y laderas.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_pasto_alto.png",
		"height_offset": 0.42,
		"density": 8.0,
		"escala": 120.0
	},
	{
		"id": "follaje_pajonal_seco",
		"mesh_id": 2,
		"nombre": "Pajonal Seco",
		"categoria": "pastos",
		"tipo": "Césped 3D / Sabana",
		"descripcion": "Pajonal dorado de sabana seca o páramo alto.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_pajonal_seco.png",
		"height_offset": 0.38,
		"density": 8.0,
		"escala": 115.0
	},
	{
		"id": "follaje_trebol_flores",
		"mesh_id": 3,
		"nombre": "Trébol y Flores",
		"categoria": "flores",
		"tipo": "Flores 3D / Jardín",
		"descripcion": "Pasto con florecillas silvestres blancas, amarillas y rosadas.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_trebol_flores.png",
		"height_offset": 0.28,
		"density": 9.0,
		"escala": 105.0
	},
	{
		"id": "follaje_helecho",
		"mesh_id": 4,
		"nombre": "Helecho Andino",
		"categoria": "arbustos",
		"tipo": "Sotobosque 3D / Helecho",
		"descripcion": "Frondas verdes de helecho para bosques y quebradas.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_helecho.png",
		"height_offset": 0.48,
		"density": 5.0,
		"escala": 135.0
	},
	{
		"id": "follaje_arbusto_bajo",
		"mesh_id": 5,
		"nombre": "Arbusto Bajo",
		"categoria": "arbustos",
		"tipo": "Sotobosque 3D / Matorral",
		"descripcion": "Matorral frondoso bajo para bordes de camino y monte.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_arbusto_bajo.png",
		"height_offset": 0.52,
		"density": 4.0,
		"escala": 145.0
	},
	{
		"id": "follaje_kikuyo_denso",
		"mesh_id": 6,
		"nombre": "Kikuyo Esmeralda",
		"categoria": "pastos",
		"tipo": "Césped 3D / Hiperrealista",
		"descripcion": "Mata espesa de kikuyo andino verde vivo con detalle botánico.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_kikuyo_denso.png",
		"height_offset": 0.30,
		"density": 11.0,
		"escala": 105.0
	},
	{
		"id": "follaje_espiga_dorada",
		"mesh_id": 7,
		"nombre": "Espiga Dorada",
		"categoria": "pastos",
		"tipo": "Césped 3D / Hiperrealista",
		"descripcion": "Tallos altos de espiga silvestre dorada y oliva con semillas.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_espiga_dorada.png",
		"height_offset": 0.45,
		"density": 7.5,
		"escala": 125.0
	},
	{
		"id": "follaje_cola_zorro",
		"mesh_id": 8,
		"nombre": "Cola de Zorro",
		"categoria": "pastos",
		"tipo": "Césped 3D / Hiperrealista",
		"descripcion": "Macolla de cortadera andina con plumeros blancos sedosos.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_cola_zorro.png",
		"height_offset": 0.55,
		"density": 5.5,
		"escala": 145.0
	},
	{
		"id": "follaje_lirio_silvestre",
		"mesh_id": 9,
		"nombre": "Lirio de Pradera",
		"categoria": "flores",
		"tipo": "Flores 3D / Hiperrealista",
		"descripcion": "Césped con flores andinas naranjas, amarillas y violetas.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_lirio_silvestre.png",
		"height_offset": 0.36,
		"density": 8.0,
		"escala": 115.0
	},
	{
		"id": "follaje_junco_ribera",
		"mesh_id": 10,
		"nombre": "Junco de Ribera",
		"categoria": "arbustos",
		"tipo": "Ribera 3D / Hiperrealista",
		"descripcion": "Juncos altos verde oscuro ideales para lagos, ríos y humedales.",
		"tex": "res://recursos/texturas/mapas/04_vegetacion/hojas_follaje/follaje_junco_ribera.png",
		"height_offset": 0.52,
		"density": 6.5,
		"escala": 135.0
	}
]

@export var modo_actual: ModoTerreno = ModoTerreno.ELEVAR
@export var radio_pincel: float = 25.0
@export var fuerza_pincel: float = 0.4
@export var altura_objetivo: float = 10.0
@export var suavizado_borde_pintura: float = 0.30

var terrain: Terrain3D
var terrain_editor: Terrain3DEditor
var _cursor_pincel: MeshInstance3D
var _cursor_centro: MeshInstance3D
var _trazo_activo: bool = false
var _brush_images: Array = []
var perfil_actual: int = 0 # 0: Suave, 1: Medio, 2: Fuerte
var textura_pintura_actual: int = 0
var follaje_mesh_actual: int = 0
var follaje_densidad: float = 0.85
var follaje_escala_pct: float = 100.0
var follaje_borrar_activo: bool = false

func _ready() -> void:
	_cargar_pincel_por_defecto()
	_crear_cursor_pincel()
	_inicializar_terreno()

func _inicializar_terreno() -> void:
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.free_editor_textures = false
	terrain.mesh_lods = 5
	terrain.mesh_size = 32
	
	# Usar material con shader liviano para prevenir fallos de compilación SPIR-V en GPU móvil/Intel
	var mat := Terrain3DMaterial.new()
	var shader_path := "res://mundo/editor_mapas/terreno_pincel.gdshader"
	if not ResourceLoader.exists(shader_path):
		shader_path = "res://addons/terrain_3d/extras/shaders/lightweight.gdshader"
	if ResourceLoader.exists(shader_path):
		mat.shader_override = load(shader_path)
		mat.shader_override_enabled = true
	mat.world_background = Terrain3DMaterial.NONE
	mat.set_shader_param("blend_sharpness", 0.0)
	terrain.material = mat
	
	# Configurar materiales de terreno reales (0: Césped, 1: Tierra, 2: Roca)
	terrain.assets = _construir_assets_terreno()
		
	# Si el mapa del Hub ya tiene su carpeta de terreno guardada, cargarla; si es nuevo, iniciar vacío y plano
	var dir_inicial := ""
	var ruta_hub := str(Engine.get_meta("nt_editor_mapa_ruta", ""))
	if not ruta_hub.is_empty():
		var dir_hub_terreno := ruta_hub.get_basename() + "_terreno"
		if _tiene_regiones_terreno(dir_hub_terreno):
			dir_inicial = dir_hub_terreno
	if not dir_inicial.is_empty():
		terrain.data_directory = dir_inicial
		set_meta("ultimo_dir_terreno_cargado", dir_inicial)
		
	add_child(terrain)
	
	# Si no hay data preexistente, crear únicamente un cuadro plano de terreno en (0, 0)
	if terrain.data and terrain.data.get_region_count() == 0:
		terrain.data.add_region_blank(Vector2i(0, 0), false)
		terrain.data.update_maps(3, true, true)
	
	# Nota: En tiempo de ejecución (fuera del editor de Godot), operamos directamente
	# sobre terrain.data para evitar errores de EditorUndoRedoManager (_store_undo).
	if terrain.assets and terrain.assets.has_method("update_texture_list"):
		terrain.assets.update_texture_list()
	actualizar_parametros_pincel()


func aplicar_distancia_renderizado(dist: float, cam: Camera3D = null) -> void:
	if not is_instance_valid(terrain):
		return
	var lods := 5
	if dist <= 350.0:
		lods = 4
	elif dist <= 650.0:
		lods = 5
	elif dist <= 1050.0:
		lods = 6
	else:
		lods = 7
	terrain.mesh_lods = lods
	if is_instance_valid(cam) and terrain.has_method("set_camera"):
		terrain.set_camera(cam)

func _construir_assets_terreno() -> Terrain3DAssets:
	var assets := Terrain3DAssets.new()
	var lista_meshes: Array[Terrain3DMeshAsset] = []
	for f_info in FOLLAJE_CATALOGO:
		var ma := Terrain3DMeshAsset.new()
		ma.id = int(f_info["mesh_id"])
		ma.name = str(f_info["nombre"])
		ma.generated_type = Terrain3DMeshAsset.TYPE_TEXTURE_CARD
		ma.height_offset = float(f_info["height_offset"])
		ma.density = float(f_info["density"])
		ma.last_lod = 0
		ma.last_shadow_lod = 0
		ma.lod0_range = 128.0
		var mat_f := StandardMaterial3D.new()
		mat_f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat_f.alpha_scissor_threshold = 0.42
		mat_f.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat_f.vertex_color_use_as_albedo = true
		mat_f.backlight_enabled = true
		mat_f.backlight = Color(0.5, 0.5, 0.5)
		mat_f.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		mat_f.distance_fade_min_distance = 128.0
		mat_f.distance_fade_max_distance = 96.0
		var ruta_tex: String = str(f_info["tex"])
		if ResourceLoader.exists(ruta_tex):
			mat_f.albedo_texture = load(ruta_tex) as Texture2D
		ma.material_override = mat_f
		lista_meshes.append(ma)
	assets.mesh_list = lista_meshes
	if assets.has_method("set_mesh_asset"):
		for idx in lista_meshes.size():
			assets.set_mesh_asset(idx, lista_meshes[idx])
	if assets.has_method("update_mesh_list"):
		assets.update_mesh_list()

	var lista_texturas: Array[Terrain3DTextureAsset] = []
	for idx in MATERIALES_PINTURA.size():
		var mat_info: Dictionary = MATERIALES_PINTURA[idx]
		var tex_asset := _crear_textura_terreno(
			idx,
			mat_info["nombre"],
			mat_info["albedo"],
			mat_info["normal"],
			mat_info["fallback"],
			mat_info["tinte"]
		)
		lista_texturas.append(tex_asset)
	assets.texture_list = lista_texturas
	if assets.has_method("set_texture_asset"):
		for idx in lista_texturas.size():
			assets.set_texture_asset(idx, lista_texturas[idx])
	if assets.has_method("update_texture_list"):
		assets.update_texture_list()
	return assets

func _crear_textura_terreno(
	id_tex: int,
	nombre: String,
	ruta_albedo: String,
	ruta_normal: String,
	fallback_albedo: String,
	color_tinte: Color
) -> Terrain3DTextureAsset:
	var tex_asset := Terrain3DTextureAsset.new()
	tex_asset.id = id_tex
	tex_asset.name = nombre
	tex_asset.albedo_color = color_tinte
	tex_asset.uv_scale = 0.36
	tex_asset.normal_depth = 1.2
	tex_asset.ao_strength = 0.85
	tex_asset.detiling_rotation = 0.15

	var tex_albedo := _normalizar_textura(ruta_albedo, fallback_albedo, 1024)
	if tex_albedo:
		tex_asset.albedo_texture = tex_albedo

	var tex_normal := _normalizar_textura(ruta_normal, "", 1024)
	if tex_normal:
		tex_asset.normal_texture = tex_normal
	return tex_asset

func _normalizar_textura(ruta: String, fallback: String, tamano: int = 1024) -> Texture2D:
	var tex: Texture2D = null
	if not ruta.is_empty() and ResourceLoader.exists(ruta):
		tex = load(ruta) as Texture2D
	elif not fallback.is_empty() and ResourceLoader.exists(fallback):
		tex = load(fallback) as Texture2D
	if not tex:
		return null

	var img := tex.get_image()
	if not img:
		return tex
	if img.is_compressed():
		img.decompress()
	if img.get_width() != tamano or img.get_height() != tamano:
		img.resize(tamano, tamano, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

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

	var box := BoxMesh.new()
	box.size = Vector3(2.2, 2.2, 2.2)
	_cursor_pincel.mesh = box
	_cursor_pincel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_mix;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 color_principal : source_color = vec4(1.0, 0.773, 0.180, 0.95);
uniform vec4 color_secundario : source_color = vec4(0.85, 0.90, 0.96, 0.55);
uniform vec3 centro_pincel = vec3(0.0);
uniform float radio_cursor = 25.0;
uniform float radio_nucleo = 0.71;

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	if (depth <= 0.00001) {
		discard;
	}

	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;

	vec3 delta = world_pos - centro_pincel;
	float r = length(delta) / max(radio_cursor, 0.01);
	if (r > 1.0) {
		discard;
	}

	// Aro exterior fino y nítido (0.965 - 1.0)
	float aro_ext = smoothstep(0.965, 0.975, r) * (1.0 - smoothstep(0.994, 1.0, r));
	// Aro interior de núcleo sólido con trazado suave
	float aro_int = smoothstep(radio_nucleo - 0.010, radio_nucleo - 0.002, r) * (1.0 - smoothstep(radio_nucleo + 0.005, radio_nucleo + 0.013, r)) * 0.45;

	// 4 marcas cardinales en el plano XZ relativo
	vec2 p_xz = delta.xz / max(radio_cursor, 0.01);
	float eje_x = step(abs(p_xz.y), 0.022) * step(0.88, r) * step(r, 1.0);
	float eje_y = step(abs(p_xz.x), 0.022) * step(0.88, r) * step(r, 1.0);
	float marcas = clamp(eje_x + eje_y, 0.0, 1.0) * 0.85;

	// Relleno radial translúcido sutil
	float relleno = mix(0.05, 0.16, smoothstep(0.0, 0.98, r)) * (1.0 - smoothstep(0.975, 1.0, r));

	vec3 col = mix(color_principal.rgb, color_secundario.rgb, clamp(aro_int * 1.5, 0.0, 0.6));
	float alpha = clamp(aro_ext * color_principal.a + aro_int + marcas + relleno, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = alpha;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_cursor_pincel.material_override = mat
	_cursor_pincel.visible = false
	add_child(_cursor_pincel)

	_cursor_centro = MeshInstance3D.new()
	_cursor_centro.name = "CursorCentro"
	var sph := SphereMesh.new()
	sph.radius = 0.32
	sph.height = 0.64
	_cursor_centro.mesh = sph
	_cursor_centro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat_c := StandardMaterial3D.new()
	mat_c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_c.albedo_color = Color(1.0, 0.773, 0.180, 0.98)
	mat_c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_c.no_depth_test = true
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
		_cursor_pincel.global_position = pos_mundo
		_cursor_pincel.scale = Vector3.ONE * max(radio_pincel, 0.1)
		var mat := _cursor_pincel.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("centro_pincel", pos_mundo)
			mat.set_shader_parameter("radio_cursor", radio_pincel)
			var es_pintura: bool = modo_actual in [ModoTerreno.PINTAR_CESPED, ModoTerreno.PINTAR_TIERRA, ModoTerreno.PINTAR_ROCA, ModoTerreno.PINTAR_MATERIAL, ModoTerreno.PINTAR_FOLLAJE, ModoTerreno.BORRAR_FOLLAJE]
			mat.set_shader_parameter("radio_nucleo", _obtener_nucleo_pintura() if es_pintura else 0.72)
		if _cursor_centro:
			_cursor_centro.global_position = pos_mundo

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
	if nuevo_modo != ModoTerreno.PENDIENTE:
		limpiar_pendiente()
	actualizar_parametros_pincel()

func establecer_info_vista(modo: int) -> void:
	if terrain and terrain.material:
		terrain.material.set_shader_param("info_vista_modo", clampi(modo, 0, 3))

func establecer_material_pintura(id_material: String) -> void:
	for idx in MATERIALES_PINTURA.size():
		if MATERIALES_PINTURA[idx]["id"] == id_material:
			textura_pintura_actual = idx
			modo_actual = ModoTerreno.PINTAR_MATERIAL
			actualizar_parametros_pincel()
			return
	textura_pintura_actual = 0
	modo_actual = ModoTerreno.PINTAR_MATERIAL
	actualizar_parametros_pincel()

func establecer_follaje_pintura(id_follaje: String) -> void:
	for f_info in FOLLAJE_CATALOGO:
		if f_info["id"] == id_follaje:
			follaje_mesh_actual = int(f_info["mesh_id"])
			follaje_escala_pct = float(f_info.get("escala", 100.0))
			modo_actual = ModoTerreno.BORRAR_FOLLAJE if follaje_borrar_activo else ModoTerreno.PINTAR_FOLLAJE
			actualizar_parametros_pincel()
			return
	follaje_mesh_actual = 0
	modo_actual = ModoTerreno.BORRAR_FOLLAJE if follaje_borrar_activo else ModoTerreno.PINTAR_FOLLAJE
	actualizar_parametros_pincel()

func establecer_densidad_follaje(densidad: float) -> void:
	follaje_densidad = clampf(densidad, 0.05, 1.0)

func establecer_escala_follaje(escala_pct: float) -> void:
	follaje_escala_pct = clampf(escala_pct, 30.0, 300.0)

func establecer_borrar_follaje(borrar: bool) -> void:
	follaje_borrar_activo = borrar
	if modo_actual in [ModoTerreno.PINTAR_FOLLAJE, ModoTerreno.BORRAR_FOLLAJE]:
		modo_actual = ModoTerreno.BORRAR_FOLLAJE if borrar else ModoTerreno.PINTAR_FOLLAJE

func establecer_radio(radio: float) -> void:
	radio_pincel = clamp(radio, 3.0, 150.0)
	actualizar_parametros_pincel()

func establecer_fuerza(fuerza: float) -> void:
	fuerza_pincel = clamp(fuerza, 0.05, 1.0)
	actualizar_parametros_pincel()

func establecer_altura_objetivo(altura: float) -> void:
	altura_objetivo = altura
	actualizar_parametros_pincel()

func establecer_suavizado_borde(suavizado: float) -> void:
	suavizado_borde_pintura = clampf(suavizado, 0.0, 1.0)
	actualizar_parametros_pincel()

func _obtener_nucleo_pintura() -> float:
	return lerpf(0.98, 0.08, clampf(suavizado_borde_pintura, 0.0, 1.0))

func actualizar_parametros_pincel() -> void:
	# Sincroniza los parámetros del pincel para el procesador en tiempo real
	pass

func _obtener_id_textura_actual() -> int:
	match modo_actual:
		ModoTerreno.PINTAR_CESPED:
			return 0
		ModoTerreno.PINTAR_TIERRA:
			return 3
		ModoTerreno.PINTAR_ROCA:
			return 7
		ModoTerreno.PINTAR_MATERIAL:
			return clamp(textura_pintura_actual, 0, MATERIALES_PINTURA.size() - 1)
	return 0

func _calcular_peso_perfil(dist_norm: float) -> float:
	match perfil_actual:
		0: # Suave
			return smoothstep(1.0, 0.0, dist_norm)
		1: # Medio
			return clamp(1.0 - dist_norm, 0.0, 1.0)
		2: # Fuerte
			return pow(clamp(1.0 - dist_norm, 0.0, 1.0), 0.45)
	return smoothstep(1.0, 0.0, dist_norm)

var _ultimo_update_maps_ms: int = 0

func _asegurar_region_en(data: Terrain3DData, pt: Vector3) -> bool:
	if is_nan(pt.x) or is_nan(pt.z) or is_inf(pt.x) or is_inf(pt.z):
		return false
	if absf(pt.x) > 8192.0 or absf(pt.z) > 8192.0:
		return false
	# Evitar crear regiones de 1024x1024 en caliente durante un trazo (previene TDR en GPU integrada/móvil)
	return data.has_regionp(pt)

func _aplicar_pincel_en_tiempo_real(pos_mundo: Vector3) -> void:
	if not terrain or not terrain.data:
		return
	if is_nan(pos_mundo.x) or is_nan(pos_mundo.z) or absf(pos_mundo.x) > 8192.0 or absf(pos_mundo.z) > 8192.0:
		return

	var data := terrain.data
	if modo_actual == ModoTerreno.PINTAR_FOLLAJE or modo_actual == ModoTerreno.BORRAR_FOLLAJE:
		if not _asegurar_region_en(data, pos_mundo):
			return
		if terrain.instancer:
			var params_inst := {
				"size": maxf(radio_pincel * 2.0, 2.0),
				"strength": clampf(follaje_densidad, 0.05, 1.0),
				"mesh_asset_ids": [follaje_mesh_actual],
				"fixed_scale": follaje_escala_pct,
				"random_scale": 25.0,
				"fixed_spin": 0.0,
				"random_spin": 360.0,
				"fixed_tilt": 0.0,
				"random_tilt": 12.0,
				"align_to_normal": true,
				"vertex_color": Color.WHITE,
				"random_hue": 8.0,
				"random_darken": 30.0,
				"height_offset": 0.0,
				"random_height": 0.04,
				"on_collision": false,
				"raycast_height": 10.0
			}
			if modo_actual == ModoTerreno.PINTAR_FOLLAJE:
				terrain.instancer.add_instances(pos_mundo, params_inst)
			else:
				terrain.instancer.remove_instances(pos_mundo, params_inst)
			terreno_modificado.emit()
		return

	var paso: float = max(terrain.vertex_spacing, 1.0)
	var radio: float = max(radio_pincel, paso)
	var radio_sq: float = radio * radio

	var cx: float = snappedf(pos_mundo.x, paso)
	var cz: float = snappedf(pos_mundo.z, paso)
	var pasos_r: int = int(ceil(radio / paso))

	var es_pintura := modo_actual in [
		ModoTerreno.PINTAR_CESPED,
		ModoTerreno.PINTAR_TIERRA,
		ModoTerreno.PINTAR_ROCA,
		ModoTerreno.PINTAR_MATERIAL
	]

	if es_pintura:
		var tex_id: int = _obtener_id_textura_actual()
		var nucleo_lim: float = _obtener_nucleo_pintura()
		var mat_t := terrain.material
		var auto_base: int = 0
		var auto_overlay: int = 1
		var auto_slope_v: float = 1.0
		var auto_height_red: float = 0.1
		if mat_t:
			var v_ab = mat_t.get_shader_param("auto_base_texture")
			if v_ab != null: auto_base = int(v_ab)
			var v_ao = mat_t.get_shader_param("auto_overlay_texture")
			if v_ao != null: auto_overlay = int(v_ao)
			var v_as = mat_t.get_shader_param("auto_slope")
			if v_as != null: auto_slope_v = float(v_as)
			var v_ah = mat_t.get_shader_param("auto_height_reduction")
			if v_ah != null: auto_height_red = float(v_ah)

		for ix in range(-pasos_r, pasos_r + 1):
			var wx: float = cx + ix * paso
			for iz in range(-pasos_r, pasos_r + 1):
				var wz: float = cz + iz * paso
				var dx: float = wx - pos_mundo.x
				var dz: float = wz - pos_mundo.z
				var d_sq: float = dx * dx + dz * dz
				if d_sq > radio_sq:
					continue
				var pt := Vector3(wx, 0.0, wz)
				if not _asegurar_region_en(data, pt):
					continue
				var wy: float = data.get_height(pt)
				if is_nan(wy):
					wy = pos_mundo.y
				var dy: float = wy - pos_mundo.y
				var d_sq_3d: float = d_sq + dy * dy
				if d_sq_3d > radio_sq:
					continue
				var dist_norm: float = sqrt(d_sq_3d) / radio
				var era_auto: bool = bool(data.get_control_auto(pt))
				data.set_control_auto(pt, false)
				var base_actual: int = int(data.get_control_base_id(pt))
				var overlay_actual: int = int(data.get_control_overlay_id(pt))
				var blend_actual: float = float(data.get_control_blend(pt))
				if era_auto:
					var hx0: float = data.get_height(Vector3(wx - paso, 0.0, wz))
					var hx1: float = data.get_height(Vector3(wx + paso, 0.0, wz))
					var hz0: float = data.get_height(Vector3(wx, 0.0, wz - paso))
					var hz1: float = data.get_height(Vector3(wx, 0.0, wz + paso))
					if is_nan(hx0): hx0 = wy
					if is_nan(hx1): hx1 = wy
					if is_nan(hz0): hz0 = wy
					if is_nan(hz1): hz1 = wy
					var nrm_y: float = Vector3(hx0 - hx1, 2.0 * paso, hz0 - hz1).normalized().y
					var auto_blend: float = clampf(auto_slope_v * 2.0 * (nrm_y - 1.0) + 1.0 - auto_height_red * 0.01 * wy, 0.0, 1.0)
					base_actual = auto_overlay if auto_blend >= 0.5 else auto_base
					overlay_actual = base_actual
					blend_actual = 0.0
					data.set_control_base_id(pt, base_actual)
					data.set_control_overlay_id(pt, overlay_actual)
					data.set_control_blend(pt, 0.0)

				if dist_norm <= nucleo_lim:
					data.set_control_base_id(pt, tex_id)
					data.set_control_overlay_id(pt, tex_id)
					data.set_control_blend(pt, 0.0)
				else:
					var nuevo_blend: float = smoothstep(1.0, nucleo_lim, dist_norm)
					if base_actual == tex_id:
						if overlay_actual != tex_id:
							data.set_control_blend(pt, clampf(minf(blend_actual, 1.0 - nuevo_blend), 0.0, 1.0))
					elif overlay_actual == tex_id:
						data.set_control_blend(pt, clampf(maxf(blend_actual, nuevo_blend), 0.0, 1.0))
					elif blend_actual > 0.5:
						data.set_control_base_id(pt, overlay_actual)
						data.set_control_overlay_id(pt, tex_id)
						data.set_control_blend(pt, clampf(nuevo_blend, 0.0, 1.0))
					else:
						data.set_control_overlay_id(pt, tex_id)
						data.set_control_blend(pt, clampf(nuevo_blend, 0.0, 1.0))
		var ahora_ms: int = Time.get_ticks_msec()
		if ahora_ms - _ultimo_update_maps_ms >= 33:
			_ultimo_update_maps_ms = ahora_ms
			data.update_maps(1, true, false) # 1 = Terrain3DRegion.MapType.Control (tiempo real)
	else:
		# Esculpido en tiempo real (Elevar, Bajar, Aplanar, Suavizar)
		var muestras_suavizado: Array = []
		if modo_actual == ModoTerreno.SUAVIZAR:
			for ix in range(-pasos_r, pasos_r + 1):
				var wx: float = cx + ix * paso
				for iz in range(-pasos_r, pasos_r + 1):
					var wz: float = cz + iz * paso
					var dx: float = wx - pos_mundo.x
					var dz: float = wz - pos_mundo.z
					var d_sq: float = dx * dx + dz * dz
					if d_sq > radio_sq:
						continue
					var pt := Vector3(wx, 0.0, wz)
					if not _asegurar_region_en(data, pt):
						continue
					var h0: float = data.get_height(pt)
					if is_nan(h0):
						h0 = 0.0
					var h_n: float = data.get_height(Vector3(wx, 0.0, wz - paso))
					var h_s: float = data.get_height(Vector3(wx, 0.0, wz + paso))
					var h_e: float = data.get_height(Vector3(wx + paso, 0.0, wz))
					var h_o: float = data.get_height(Vector3(wx - paso, 0.0, wz))
					var suma: float = h0
					var cnt: int = 1
					for hv in [h_n, h_s, h_e, h_o]:
						if not is_nan(hv):
							suma += hv
							cnt += 1
					var peso: float = _calcular_peso_perfil(sqrt(d_sq) / radio) * fuerza_pincel
					muestras_suavizado.append([pt, lerpf(h0, suma / float(cnt), clampf(peso, 0.0, 1.0))])
			for m in muestras_suavizado:
				data.set_height(m[0], m[1])
		else:
			for ix in range(-pasos_r, pasos_r + 1):
				var wx: float = cx + ix * paso
				for iz in range(-pasos_r, pasos_r + 1):
					var wz: float = cz + iz * paso
					var dx: float = wx - pos_mundo.x
					var dz: float = wz - pos_mundo.z
					var d_sq: float = dx * dx + dz * dz
					if d_sq > radio_sq:
						continue
					var pt := Vector3(wx, 0.0, wz)
					if not _asegurar_region_en(data, pt):
						continue
					var h_actual: float = data.get_height(pt)
					if is_nan(h_actual):
						h_actual = 0.0
					var peso: float = _calcular_peso_perfil(sqrt(d_sq) / radio) * fuerza_pincel
					var h_nueva: float = h_actual
					match modo_actual:
						ModoTerreno.ELEVAR:
							h_nueva = h_actual + peso * 1.2
						ModoTerreno.BAJAR:
							h_nueva = h_actual - peso * 1.2
						ModoTerreno.APLANAR:
							h_nueva = lerpf(h_actual, altura_objetivo, clampf(peso, 0.0, 1.0))
					data.set_height(pt, h_nueva)
		var ahora_h_ms: int = Time.get_ticks_msec()
		if ahora_h_ms - _ultimo_update_maps_ms >= 33:
			_ultimo_update_maps_ms = ahora_h_ms
			data.update_maps(0, true, false)

var bloqueado_en_prueba: bool = false

func comenzar_trazo(pos_mundo: Vector3) -> void:
	if bloqueado_en_prueba or modo_actual == ModoTerreno.LOTES:
		return
	_trazo_activo = true
	_ultimo_update_maps_ms = 0
	_aplicar_pincel_en_tiempo_real(pos_mundo)
	terreno_modificado.emit()

func aplicar_trazo(pos_mundo: Vector3, _rot_camara: float = 0.0) -> void:
	if bloqueado_en_prueba or not _trazo_activo or modo_actual == ModoTerreno.LOTES:
		return
	_aplicar_pincel_en_tiempo_real(pos_mundo)
	terreno_modificado.emit()

func finalizar_trazo() -> void:
	if bloqueado_en_prueba or not _trazo_activo:
		return
	_trazo_activo = false
	if terrain and terrain.data:
		terrain.data.update_maps(3, true, true) # 3 = Terrain3DRegion.MapType.Max + mipmaps
	terreno_modificado.emit()


var _contenedor_lotes: Node3D = null

func mostrar_lotes_disponibles(activo: bool) -> void:
	if not is_instance_valid(_contenedor_lotes):
		_contenedor_lotes = Node3D.new()
		_contenedor_lotes.name = "LotesDisponibles3D"
		add_child(_contenedor_lotes)
	for ch in _contenedor_lotes.get_children():
		ch.queue_free()
	_contenedor_lotes.visible = activo
	if not activo or not is_instance_valid(terrain) or not terrain.data:
		return

	var locs: Array = terrain.data.get_region_locations()
	var ocupados: Dictionary = {}
	for v in locs:
		ocupados[Vector2i(int(v.x), int(v.y))] = true

	var candidatos: Dictionary = {}
	for k: Vector2i in ocupados.keys():
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = k + d
			if not ocupados.has(nc):
				candidatos[nc] = true

	var r_size: float = float(terrain.region_size) if "region_size" in terrain else 1024.0
	var mat_lote := StandardMaterial3D.new()
	mat_lote.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_lote.albedo_color = Color(0.88, 0.68, 0.28, 0.72)
	mat_lote.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_lote.cull_mode = BaseMaterial3D.CULL_DISABLED

	for coord: Vector2i in candidatos.keys():
		var cx: float = (float(coord.x) + 0.5) * r_size
		var cz: float = (float(coord.y) + 0.5) * r_size
		var nodo := Node3D.new()
		nodo.position = Vector3(cx, 1.5, cz)
		_contenedor_lotes.add_child(nodo)

		# Marco perimetral del lote (1024 x 1024)
		var hw: float = r_size * 0.5 - 6.0
		var grosor: float = 8.0
		for sz in [-hw, hw]:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(hw * 2.0 + grosor, 2.0, grosor)
			m.mesh = b
			m.material_override = mat_lote
			m.position = Vector3(0.0, 0.0, sz)
			nodo.add_child(m)
		for sx in [-hw, hw]:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(grosor, 2.0, hw * 2.0)
			m.mesh = b
			m.material_override = mat_lote
			m.position = Vector3(sx, 0.0, 0.0)
			nodo.add_child(m)

		var lbl := Label3D.new()
		lbl.text = "＋\nAÑADIR LOTE"
		lbl.font_size = 128
		lbl.pixel_size = 0.35
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(0.95, 0.80, 0.42, 0.96)
		lbl.outline_size = 14
		lbl.outline_modulate = Color(0.06, 0.07, 0.09, 0.90)
		lbl.position = Vector3(0.0, 36.0, 0.0)
		nodo.add_child(lbl)


func intentar_agregar_lote_en(pos_mundo: Vector3) -> Dictionary:
	if not is_instance_valid(terrain) or not terrain.data:
		return {"ok": false}
	var r_size: float = float(terrain.region_size) if "region_size" in terrain else 1024.0
	var coord := Vector2i(int(floorf(pos_mundo.x / r_size)), int(floorf(pos_mundo.z / r_size)))
	var data := terrain.data
	if data.has_region(coord):
		return {"ok": false, "motivo": "ocupado"}
	if data.get_region_count() >= 32:
		return {"ok": false, "motivo": "limite"}

	var adyacente := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if data.has_region(coord + d):
			adyacente = true
			break
	if not adyacente:
		return {"ok": false, "motivo": "no_adyacente"}

	data.add_region_blank(coord, false)
	data.update_maps(3, true, true)
	mostrar_lotes_disponibles(true)
	terreno_modificado.emit()
	return {"ok": true, "coord": coord}

var _punto_pendiente_a: Vector3 = Vector3.ZERO
var _tiene_punto_pendiente_a: bool = false
var _marcador_pendiente_a: MeshInstance3D = null

func limpiar_pendiente() -> void:
	_tiene_punto_pendiente_a = false
	if is_instance_valid(_marcador_pendiente_a):
		_marcador_pendiente_a.visible = false

func clic_pendiente(pos_mundo: Vector3) -> Dictionary:
	if not _tiene_punto_pendiente_a:
		_punto_pendiente_a = pos_mundo
		_punto_pendiente_a.y = obtener_altura(pos_mundo)
		_tiene_punto_pendiente_a = true
		if not is_instance_valid(_marcador_pendiente_a):
			_marcador_pendiente_a = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.9; sm.height = 1.8
			_marcador_pendiente_a.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.72, 0.15)
			mat.emission_enabled = true
			mat.emission = Color(0.95, 0.72, 0.15)
			mat.emission_energy_multiplier = 1.8
			_marcador_pendiente_a.material_override = mat
			add_child(_marcador_pendiente_a)
		_marcador_pendiente_a.global_position = _punto_pendiente_a + Vector3(0.0, 0.9, 0.0)
		_marcador_pendiente_a.visible = true
		return {"paso": 1, "altura": _punto_pendiente_a.y}
	var p_b := pos_mundo
	p_b.y = obtener_altura(pos_mundo)
	var ok := _aplicar_rampa(_punto_pendiente_a, p_b)
	limpiar_pendiente()
	return {"paso": 2, "ok": ok, "h_a": _punto_pendiente_a.y, "h_b": p_b.y}

func _aplicar_rampa(p_a: Vector3, p_b: Vector3) -> bool:
	if not terrain or not terrain.data:
		return false
	var data := terrain.data
	var vs: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var a2 := Vector2(p_a.x, p_a.z)
	var b2 := Vector2(p_b.x, p_b.z)
	var len_ab := a2.distance_to(b2)
	if len_ab < 0.5:
		return false
	var half_w := maxf(2.0, radio_pincel * 0.5)
	var falloff := maxf(2.0, radio_pincel * 0.4 + 2.0)
	var pad := half_w + falloff + vs * 2.0
	var min_xz := Vector3(minf(p_a.x, p_b.x) - pad, 0.0, minf(p_a.z, p_b.z) - pad).snapped(Vector3(vs, 0.0, vs))
	var max_xz := Vector3(maxf(p_a.x, p_b.x) + pad, 0.0, maxf(p_a.z, p_b.z) + pad).snapped(Vector3(vs, 0.0, vs)) + Vector3(vs, 0.0, vs)
	var mod := false
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var wp := Vector3(x, 0.0, z)
			if data.has_regionp(wp):
				var curr_h := data.get_height(wp)
				if not is_nan(curr_h):
					var p2 := Vector2(x, z)
					var q := Geometry2D.get_closest_point_to_segment(p2, a2, b2)
					var d := p2.distance_to(q)
					if d <= half_w + falloff:
						var t_ab := clampf(a2.distance_to(q) / len_ab, 0.0, 1.0)
						var h_ramp := lerpf(p_a.y, p_b.y, t_ab)
						var desired := h_ramp
						if d > half_w:
							var f := clampf((d - half_w) / falloff, 0.0, 1.0)
							var s := f * f * (3.0 - 2.0 * f)
							desired = lerpf(h_ramp, curr_h, s)
						if absf(curr_h - desired) > 0.015:
							data.set_height(wp, desired)
							mod = true
			z += vs
		x += vs
	if mod:
		data.update_maps(0)
		data.calc_height_range()
		terreno_modificado.emit()
	return mod

func capturar_snapshot_altura(centro: Vector3, radio: float) -> Dictionary:
	var snap: Dictionary = {}
	if not terrain or not terrain.data:
		return snap
	var data := terrain.data
	var vs: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var pad := radio + vs * 2.0
	var min_xz := Vector3(centro.x - pad, 0.0, centro.z - pad).snapped(Vector3(vs, 0.0, vs))
	var max_xz := Vector3(centro.x + pad, 0.0, centro.z + pad).snapped(Vector3(vs, 0.0, vs)) + Vector3(vs, 0.0, vs)
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var wp := Vector3(x, 0.0, z)
			if data.has_regionp(wp):
				var h := data.get_height(wp)
				if not is_nan(h):
					snap[Vector2(x, z)] = h
			z += vs
		x += vs
	return snap

func restaurar_snapshot_altura(snap: Dictionary) -> void:
	if snap.is_empty() or not terrain or not terrain.data:
		return
	var data := terrain.data
	for k in snap.keys():
		var p2: Vector2 = k
		data.set_height(Vector3(p2.x, 0.0, p2.y), float(snap[k]))
	data.update_maps(0)
	data.calc_height_range()
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
		var p = terrain.get_intersection(origen_rayo, dir_rayo, false)
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

func _tiene_regiones_terreno(dir_terreno: String) -> bool:
	if dir_terreno.is_empty() or not DirAccess.dir_exists_absolute(dir_terreno):
		return false
	var d := DirAccess.open(dir_terreno)
	if not d:
		return false
	for f in d.get_files():
		if f.ends_with(".res"):
			return true
	return false

func guardar_terreno(dir_terreno: String) -> bool:
	if not terrain or not terrain.data or dir_terreno.is_empty():
		return false
	if not DirAccess.dir_exists_absolute(dir_terreno):
		var err := DirAccess.make_dir_recursive_absolute(dir_terreno)
		if err != OK:
			return false
	var locs: Array = terrain.data.get_region_locations()
	for loc in locs:
		terrain.data.set_region_modified(loc, true)
	terrain.data.save_directory(dir_terreno)
	set_meta("ultimo_dir_terreno_cargado", dir_terreno)
	return true

func cargar_terreno(dir_terreno: String) -> bool:
	if not terrain or not terrain.data or not _tiene_regiones_terreno(dir_terreno):
		return false
	if str(get_meta("ultimo_dir_terreno_cargado", "")) == dir_terreno:
		return true
	terrain.data.load_directory(dir_terreno)
	terrain.data.update_maps(3, true, true)
	set_meta("ultimo_dir_terreno_cargado", dir_terreno)
	terreno_modificado.emit()
	return true
