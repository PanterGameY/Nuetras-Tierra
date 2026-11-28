class_name ControladorGasolineras
extends Node3D

signal gasolinera_actualizada(total: int)
signal gasolinera_seleccionada_cambiada(hay_seleccion: bool, datos: Dictionary)

enum TipoTecho {
	PLANO_MODERNO = 0,
	DOS_AGUAS = 1,
	CURVO_ARCO = 2,
	VOLADIZO_T = 3
}

enum TipoLetrero {
	MONOLITO_CLASICO = 0,
	TORRE_MODERNA = 1,
	DOBLE_POSTE = 2,
	TOTEM_CURVO = 3
}

const PATH_SURTIDOR_GLB := "res://modelos3d/mapa/modulares/surtidor_gasolina.glb"
const ZonaGasolineraScript = preload("res://mundo/editor_mapas/ZonaGasolinera.gd")
const PantallaSurtidor2DScript = preload("res://mundo/editor_mapas/PantallaSurtidor2D.gd")

var controlador_terreno = null
var controlador_carreteras = null

var _contenedor: Node3D = null
var _gasolineras: Array[Dictionary] = []

var indice_seleccionado: int = -1
var punto_seleccionado: int = -1
var _manejadores_visibles: bool = false

var rotacion_cursor_grados: float = 0.0
var adaptar_terreno_activo: bool = true

var _cursor_gasolinera: Node3D = null
var _cursor_mesh_fill: MeshInstance3D = null
var _cursor_mesh_borde: MeshInstance3D = null
var _cursor_ghost: Node3D = null
var _cursor_ultima_pos: Vector3 = Vector3(1e9, 1e9, 1e9)
var _cursor_ultima_rot: float = -999.0
var _mat_cursor_borde: StandardMaterial3D = null
var _mat_cursor_fill: StandardMaterial3D = null
var _mat_concreto: StandardMaterial3D = null
var _mat_punto_idle: StandardMaterial3D = null
var _mat_punto_sel: StandardMaterial3D = null
var _mat_punto_letrero: StandardMaterial3D = null
var _mat_gizmo_rot: StandardMaterial3D = null
var _mat_isla: StandardMaterial3D = null
var _mat_bordillo_isla: StandardMaterial3D = null
var _mat_luz_techo: StandardMaterial3D = null
var _mat_techo_cielo: StandardMaterial3D = null
var _mat_linea_amarilla: StandardMaterial3D = null
var _mat_linea_blanca: StandardMaterial3D = null
var _tex_metal_norm: Texture2D = null
var _tex_metal_rough: Texture2D = null
var _mat_metal_oscuro: StandardMaterial3D = null
var _mat_vidrio_oscuro: StandardMaterial3D = null
var _mat_grados_cache: StandardMaterial3D = null
var _escena_surtidor: PackedScene = null

func _ready() -> void:
	_asegurar_inicializado()

func _asegurar_inicializado() -> void:
	if not is_instance_valid(_contenedor):
		_contenedor = Node3D.new()
		_contenedor.name = "ContenedorGasolineras"
		add_child(_contenedor)
	if _mat_concreto == null:
		_inicializar_materiales()
	if _escena_surtidor == null and ResourceLoader.exists(PATH_SURTIDOR_GLB):
		_escena_surtidor = load(PATH_SURTIDOR_GLB) as PackedScene
	if not is_instance_valid(_cursor_gasolinera):
		_cursor_gasolinera = _construir_cursor_gasolinera()
		_cursor_gasolinera.visible = false
		add_child(_cursor_gasolinera)

func _inicializar_materiales() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 619
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var noise_grano := FastNoiseLite.new()
	noise_grano.seed = 991
	noise_grano.noise_type = FastNoiseLite.TYPE_VALUE
	noise_grano.frequency = 0.35
	noise_grano.fractal_octaves = 3

	var img_n := noise.get_seamless_image(256, 256, false, false)
	var img_g := noise_grano.get_seamless_image(256, 256, false, false)
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var img_h := Image.create(256, 256, false, Image.FORMAT_RF)
	var img_r := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var vm := img_n.get_pixel(x, y).r - 0.5
			var vg := img_g.get_pixel(x, y).r - 0.5
			var v := vm * 0.14 + vg * 0.09
			var h_val := clampf(0.5 + vm * 0.3 + vg * 0.28, 0.0, 1.0)
			var c := Color(clampf(0.36 + v, 0.0, 1.0), clampf(0.37 + v, 0.0, 1.0), clampf(0.39 + v, 0.0, 1.0), 1.0)
			var rough_v := clampf(0.84 + vm * 0.12 - vg * 0.08, 0.55, 0.98)
			# Juntas de dilatación del concreto
			if x < 3 or y < 3 or abs(x - 128) < 2 or abs(y - 128) < 2:
				c = c.darkened(0.38)
				h_val = 0.12
				rough_v = 0.96
			img.set_pixel(x, y, c)
			img_h.set_pixel(x, y, Color(h_val, h_val, h_val, 1.0))
			img_r.set_pixel(x, y, Color(rough_v, rough_v, rough_v, 1.0))
	img.generate_mipmaps()
	img_h.bump_map_to_normal_map(1.8)
	img_h.generate_mipmaps()
	img_r.generate_mipmaps()

	_mat_concreto = StandardMaterial3D.new()
	_mat_concreto.albedo_texture = ImageTexture.create_from_image(img)
	_mat_concreto.normal_enabled = true
	_mat_concreto.normal_texture = ImageTexture.create_from_image(img_h)
	_mat_concreto.normal_scale = 0.95
	_mat_concreto.roughness_texture = ImageTexture.create_from_image(img_r)
	_mat_concreto.roughness = 0.90
	_mat_concreto.uv1_triplanar = true
	_mat_concreto.uv1_world_triplanar = true
	_mat_concreto.uv1_scale = Vector3(0.22, 0.22, 0.22)

	# Textura metálica con paneles y cepillado para techo/columnas/surtidores
	var img_mh := Image.create(128, 128, false, Image.FORMAT_RF)
	var img_mr := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var brush := (img_g.get_pixel(x * 2, (y / 4) * 2).r - 0.5) * 0.08
			var seam := 0.18 if (x < 2 or y < 2 or abs(x - 64) < 1) else (0.55 + brush)
			var rv := clampf(0.32 + brush * 1.4, 0.18, 0.52)
			img_mh.set_pixel(x, y, Color(seam, seam, seam, 1.0))
			img_mr.set_pixel(x, y, Color(rv, rv, rv, 1.0))
	img_mh.bump_map_to_normal_map(1.4)
	img_mh.generate_mipmaps()
	img_mr.generate_mipmaps()
	_tex_metal_norm = ImageTexture.create_from_image(img_mh)
	_tex_metal_rough = ImageTexture.create_from_image(img_mr)

	_mat_isla = StandardMaterial3D.new()
	_mat_isla.albedo_texture = ImageTexture.create_from_image(img)
	_mat_isla.albedo_color = Color(0.85, 0.86, 0.88)
	_mat_isla.normal_enabled = true
	_mat_isla.normal_texture = _mat_concreto.normal_texture
	_mat_isla.roughness = 0.84
	_mat_isla.uv1_triplanar = true
	_mat_isla.uv1_world_triplanar = true
	_mat_isla.uv1_scale = Vector3(0.45, 0.45, 0.45)

	# Bordillo de seguridad industrial (franjas amarillas/negras)
	var img_seg := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(128):
			var diag := ((x + y) / 16) % 2
			var col_s := Color(0.88, 0.68, 0.14) if diag == 0 else Color(0.12, 0.13, 0.14)
			var gr := (img_g.get_pixel(x, y).r - 0.5) * 0.06
			img_seg.set_pixel(x, y, Color(clampf(col_s.r + gr, 0.0, 1.0), clampf(col_s.g + gr, 0.0, 1.0), clampf(col_s.b + gr, 0.0, 1.0), 1.0))
	img_seg.generate_mipmaps()
	_mat_bordillo_isla = StandardMaterial3D.new()
	_mat_bordillo_isla.albedo_texture = ImageTexture.create_from_image(img_seg)
	_mat_bordillo_isla.roughness = 0.72
	_mat_bordillo_isla.uv1_triplanar = true
	_mat_bordillo_isla.uv1_world_triplanar = true
	_mat_bordillo_isla.uv1_scale = Vector3(0.55, 0.55, 0.55)

	_mat_techo_cielo = StandardMaterial3D.new()
	_mat_techo_cielo.albedo_color = Color(0.88, 0.90, 0.92)
	_mat_techo_cielo.normal_enabled = true
	_mat_techo_cielo.normal_texture = _tex_metal_norm
	_mat_techo_cielo.normal_scale = 0.7
	_mat_techo_cielo.metallic = 0.25
	_mat_techo_cielo.roughness = 0.45
	_mat_techo_cielo.uv1_triplanar = true
	_mat_techo_cielo.uv1_world_triplanar = true
	_mat_techo_cielo.uv1_scale = Vector3(0.4, 0.4, 0.4)

	_mat_luz_techo = StandardMaterial3D.new()
	_mat_luz_techo.albedo_color = Color(1.0, 0.98, 0.94)
	_mat_luz_techo.emission_enabled = true
	_mat_luz_techo.emission = Color(1.0, 0.96, 0.88)
	_mat_luz_techo.emission_energy_multiplier = 2.6

	_mat_linea_amarilla = StandardMaterial3D.new()
	_mat_linea_amarilla.albedo_color = Color(0.88, 0.68, 0.14)
	_mat_linea_amarilla.normal_enabled = true
	_mat_linea_amarilla.normal_texture = _mat_concreto.normal_texture
	_mat_linea_amarilla.normal_scale = 0.45
	_mat_linea_amarilla.roughness = 0.72
	_mat_linea_amarilla.uv1_triplanar = true
	_mat_linea_amarilla.uv1_world_triplanar = true

	_mat_linea_blanca = StandardMaterial3D.new()
	_mat_linea_blanca.albedo_color = Color(0.86, 0.87, 0.89)
	_mat_linea_blanca.normal_enabled = true
	_mat_linea_blanca.normal_texture = _mat_concreto.normal_texture
	_mat_linea_blanca.normal_scale = 0.45
	_mat_linea_blanca.roughness = 0.72
	_mat_linea_blanca.uv1_triplanar = true
	_mat_linea_blanca.uv1_world_triplanar = true

	_mat_punto_idle = StandardMaterial3D.new()
	_mat_punto_idle.albedo_color = Color(0.95, 0.75, 0.20)
	_mat_punto_idle.emission_enabled = true
	_mat_punto_idle.emission = Color(0.95, 0.70, 0.10)
	_mat_punto_idle.emission_energy_multiplier = 1.6

	_mat_punto_sel = StandardMaterial3D.new()
	_mat_punto_sel.albedo_color = Color(0.20, 0.95, 0.48)
	_mat_punto_sel.emission_enabled = true
	_mat_punto_sel.emission = Color(0.20, 0.95, 0.48)
	_mat_punto_sel.emission_energy_multiplier = 2.0

	_mat_punto_letrero = StandardMaterial3D.new()
	_mat_punto_letrero.albedo_color = Color(0.22, 0.82, 0.98)
	_mat_punto_letrero.emission_enabled = true
	_mat_punto_letrero.emission = Color(0.18, 0.78, 0.98)
	_mat_punto_letrero.emission_energy_multiplier = 1.9

	_mat_gizmo_rot = StandardMaterial3D.new()
	_mat_gizmo_rot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_gizmo_rot.albedo_color = Color(0.98, 0.75, 0.18, 0.96)
	_mat_gizmo_rot.no_depth_test = true
	_mat_gizmo_rot.render_priority = 5

	_mat_metal_oscuro = StandardMaterial3D.new()
	_mat_metal_oscuro.albedo_color = Color(0.11, 0.12, 0.14)
	_mat_metal_oscuro.metallic = 0.78
	_mat_metal_oscuro.roughness = 0.38
	if _tex_metal_norm:
		_mat_metal_oscuro.normal_enabled = true
		_mat_metal_oscuro.normal_texture = _tex_metal_norm
		_mat_metal_oscuro.normal_scale = 0.5
		_mat_metal_oscuro.uv1_triplanar = true
		_mat_metal_oscuro.uv1_world_triplanar = true

	_mat_vidrio_oscuro = StandardMaterial3D.new()
	_mat_vidrio_oscuro.albedo_color = Color(0.03, 0.04, 0.05)
	_mat_vidrio_oscuro.metallic = 0.15
	_mat_vidrio_oscuro.roughness = 0.08

	_mat_grados_cache = StandardMaterial3D.new()
	_mat_grados_cache.albedo_texture = _crear_textura_grados()
	_mat_grados_cache.roughness = 0.25

func _construir_cursor_gasolinera() -> Node3D:
	var n := Node3D.new()
	n.name = "CursorGasolinera"

	_mat_cursor_borde = StandardMaterial3D.new()
	_mat_cursor_borde.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cursor_borde.albedo_color = Color(0.96, 0.74, 0.20, 0.96)
	_mat_cursor_borde.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cursor_borde.no_depth_test = true
	_mat_cursor_borde.render_priority = 21

	_mat_cursor_fill = StandardMaterial3D.new()
	_mat_cursor_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cursor_fill.albedo_color = Color(0.95, 0.72, 0.18, 0.20)
	_mat_cursor_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cursor_fill.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cursor_fill.no_depth_test = true
	_mat_cursor_fill.render_priority = 20

	_cursor_mesh_borde = MeshInstance3D.new()
	_cursor_mesh_borde.material_override = _mat_cursor_borde
	n.add_child(_cursor_mesh_borde)

	_cursor_mesh_fill = MeshInstance3D.new()
	_cursor_mesh_fill.material_override = _mat_cursor_fill
	n.add_child(_cursor_mesh_fill)

	# Silueta fantasma elevada (bahías + techo + letrero) para previsualizar orientación
	_cursor_ghost = Node3D.new()
	n.add_child(_cursor_ghost)

	var mat_ghost := StandardMaterial3D.new()
	mat_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_ghost.albedo_color = Color(0.95, 0.74, 0.22, 0.30)
	mat_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_ghost.no_depth_test = true
	mat_ghost.render_priority = 19

	var mat_let_ghost := StandardMaterial3D.new()
	mat_let_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_let_ghost.albedo_color = Color(0.22, 0.85, 0.98, 0.55)
	mat_let_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_let_ghost.no_depth_test = true
	mat_let_ghost.render_priority = 19

	# 2 islas y 4 surtidores fantasma
	for z_i: float in [-6.5, 6.5]:
		_crear_caja(_cursor_ghost, Vector3(11.0, 0.25, 1.65), Vector3(0.0, 0.125, z_i), mat_ghost)
		for x_s: float in [-2.6, 2.6]:
			_crear_caja(_cursor_ghost, Vector3(1.0, 2.2, 0.6), Vector3(x_s, 1.35, z_i), mat_ghost)
	# Techo fantasma
	_crear_caja(_cursor_ghost, Vector3(17.5, 0.55, 25.2), Vector3(0.0, 5.45, 0.0), mat_ghost)
	# Letrero fantasma
	_crear_caja(_cursor_ghost, Vector3(2.2, 5.0, 0.55), Vector3(17.5, 2.5, -13.5), mat_let_ghost)

	return n

func actualizar_cursor_gasolinera(pos: Vector3, visible_flag: bool) -> void:
	_asegurar_inicializado()
	if not visible_flag:
		_cursor_gasolinera.visible = false
		return
	_cursor_gasolinera.visible = true

	if pos.distance_squared_to(_cursor_ultima_pos) < 0.02 and absf(rotacion_cursor_grados - _cursor_ultima_rot) < 0.2:
		return
	_cursor_ultima_pos = pos
	_cursor_ultima_rot = rotacion_cursor_grados

	var rad := -deg_to_rad(rotacion_cursor_grados)
	var hw := 20.0
	var hd := 16.0
	var nx := 5
	var nz := 5

	# Grilla adaptada al terreno para que el relleno no atraviese colinas
	var grid_pts: Array = []
	var y_max_total := pos.y
	for iz in range(nz + 1):
		var row: Array[Vector3] = []
		var tz := lerpf(-hd, hd, float(iz) / float(nz))
		for ix in range(nx + 1):
			var tx := lerpf(-hw, hw, float(ix) / float(nx))
			var wp := pos + Vector3(tx, 0.0, tz).rotated(Vector3.UP, rad)
			var yh := _altura_terreno(wp.x, wp.z, pos.y)
			y_max_total = maxf(y_max_total, yh)
			row.append(Vector3(wp.x, yh + 0.35, wp.z))
		grid_pts.append(row)

	var st_f := SurfaceTool.new()
	st_f.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(nz):
		for ix in range(nx):
			var p00: Vector3 = grid_pts[iz][ix]
			var p10: Vector3 = grid_pts[iz][ix + 1]
			var p11: Vector3 = grid_pts[iz + 1][ix + 1]
			var p01: Vector3 = grid_pts[iz + 1][ix]
			st_f.add_vertex(p00); st_f.add_vertex(p10); st_f.add_vertex(p11)
			st_f.add_vertex(p00); st_f.add_vertex(p11); st_f.add_vertex(p01)
	st_f.generate_normals()
	_cursor_mesh_fill.mesh = st_f.commit()

	# Borde perimetral y esquinas adaptadas al terreno
	var st_b := SurfaceTool.new()
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(nx):
		_agregar_segmento_caja(st_b, grid_pts[0][ix] + Vector3(0, 0.08, 0), grid_pts[0][ix + 1] + Vector3(0, 0.08, 0), 0.32, 0.14)
		_agregar_segmento_caja(st_b, grid_pts[nz][ix] + Vector3(0, 0.08, 0), grid_pts[nz][ix + 1] + Vector3(0, 0.08, 0), 0.32, 0.14)
	for iz in range(nz):
		_agregar_segmento_caja(st_b, grid_pts[iz][0] + Vector3(0, 0.08, 0), grid_pts[iz + 1][0] + Vector3(0, 0.08, 0), 0.32, 0.14)
		_agregar_segmento_caja(st_b, grid_pts[iz][nx] + Vector3(0, 0.08, 0), grid_pts[iz + 1][nx] + Vector3(0, 0.08, 0), 0.32, 0.14)
	st_b.generate_normals()
	_cursor_mesh_borde.mesh = st_b.commit()

	if is_instance_valid(_cursor_ghost):
		_cursor_ghost.position = Vector3(pos.x, y_max_total + 0.35, pos.z)
		_cursor_ghost.rotation.y = rad

func rotar_cursor(delta: float) -> float:
	rotacion_cursor_grados = wrapf(rotacion_cursor_grados + delta, 0.0, 360.0)
	_cursor_ultima_rot = -999.0
	if is_instance_valid(_cursor_gasolinera) and _cursor_gasolinera.visible:
		actualizar_cursor_gasolinera(_cursor_ultima_pos, true)
	return rotacion_cursor_grados

func establecer_manejadores_visibles(vis: bool) -> void:
	_manejadores_visibles = vis
	for i in range(_gasolineras.size()):
		var g: Dictionary = _gasolineras[i]
		var mostrar: bool = vis and not bool(g.get("finalizado", false))
		for m in g.get("manejadores", []):
			if is_instance_valid(m):
				m.visible = mostrar
		var ml := g.get("manejador_letrero") as MeshInstance3D
		if is_instance_valid(ml):
			ml.visible = mostrar
		var gz := g.get("gizmo_letrero") as Node3D
		if is_instance_valid(gz):
			gz.visible = mostrar and (i == indice_seleccionado) and (punto_seleccionado in [-2, -3])

func crear_gasolinera(pos_centro: Vector3, tipo_techo: int = 0) -> int:
	_asegurar_inicializado()
	var hw := 20.0
	var hd := 16.0
	var rad := -deg_to_rad(rotacion_cursor_grados)
	var locales := [
		Vector3(-hw, 0, -hd), Vector3(0, 0, -hd), Vector3(hw, 0, -hd),
		Vector3(hw, 0, 0), Vector3(hw, 0, hd), Vector3(0, 0, hd),
		Vector3(-hw, 0, hd), Vector3(-hw, 0, 0)
	]
	var puntos: Array[Vector3] = []
	for lp: Vector3 in locales:
		var wp: Vector3 = pos_centro + lp.rotated(Vector3.UP, rad)
		wp.y = _altura_terreno(wp.x, wp.z, pos_centro.y)
		puntos.append(wp)

	var nodo := Node3D.new()
	nodo.name = "Gasolinera_%d" % (_gasolineras.size() + 1)
	_contenedor.add_child(nodo)

	var pos_letrero := pos_centro + Vector3(17.5, 0.0, -13.5).rotated(Vector3.UP, rad)
	pos_letrero.y = _altura_terreno(pos_letrero.x, pos_letrero.z, pos_centro.y)

	var datos := {
		"puntos": puntos,
		"rotacion": rotacion_cursor_grados,
		"altura_losa": 0.16,
		"adaptar_terreno": adaptar_terreno_activo,
		"cantidad_bahias": 2,
		"cantidad_surtidores": 4,
		"tipo_techo": clampi(tipo_techo, 0, 3),
		"altura_techo": 5.2,
		"tipo_letrero": 0,
		"pos_letrero": pos_letrero,
		"rotacion_letrero": rotacion_cursor_grados,
		"color_primario": Color(0.86, 0.14, 0.14),
		"color_secundario": Color(0.95, 0.72, 0.12),
		"color_estructura": Color(0.88, 0.90, 0.92),
		"lado_conexion": 0,
		"conexion_via": {},
		"finalizado": false,
		"nodo": nodo,
		"manejadores": [],
		"manejador_letrero": null
	}
	_gasolineras.append(datos)
	var idx := _gasolineras.size() - 1
	if adaptar_terreno_activo:
		adaptar_terreno_gasolinera(idx)
	_reconstruir_gasolinera(idx)
	seleccionar_gasolinera(idx)
	gasolinera_actualizada.emit(_gasolineras.size())
	return idx

func seleccionar_gasolinera(idx: int) -> void:
	if idx < 0 or idx >= _gasolineras.size():
		indice_seleccionado = -1
		punto_seleccionado = -1
	else:
		indice_seleccionado = idx
		punto_seleccionado = 0 if not (_gasolineras[idx]["puntos"] as Array).is_empty() else -1
	_actualizar_colores_manejadores()
	_emitir_seleccion()

func seleccionar_punto(idx_g: int, idx_p: int) -> void:
	if idx_g < 0 or idx_g >= _gasolineras.size():
		return
	var pts: Array = _gasolineras[idx_g]["puntos"]
	if not (idx_p in [-2, -3]) and (idx_p < 0 or idx_p >= pts.size()):
		return
	indice_seleccionado = idx_g
	punto_seleccionado = idx_p
	_actualizar_colores_manejadores()
	_emitir_seleccion()

func mover_punto(idx_g: int, idx_p: int, nueva_pos: Vector3) -> void:
	if idx_g < 0 or idx_g >= _gasolineras.size():
		return
	var g: Dictionary = _gasolineras[idx_g]
	if bool(g.get("finalizado", false)):
		return
	if idx_p == -2:
		var nueva_pl := Vector3(nueva_pos.x, _altura_terreno(nueva_pos.x, nueva_pos.z, nueva_pos.y), nueva_pos.z)
		g["pos_letrero"] = nueva_pl
		var nl := g.get("nodo_letrero") as Node3D
		if is_instance_valid(nl):
			nl.position = nueva_pl
		var ml := g.get("manejador_letrero") as Node3D
		if is_instance_valid(ml):
			ml.position = nueva_pl + Vector3(0.0, 0.85, 0.0)
		var gz := g.get("gizmo_letrero") as Node3D
		if is_instance_valid(gz):
			gz.position = nueva_pl + Vector3(0.0, 0.38, 0.0)
		return
	if idx_p == -3:
		var pl: Vector3 = g.get("pos_letrero", Vector3.ZERO)
		var dx := nueva_pos.x - pl.x
		var dz := nueva_pos.z - pl.z
		if dx * dx + dz * dz > 0.04:
			var ang_rad := atan2(dx, dz)
			var rot_deg := wrapf(-rad_to_deg(ang_rad), 0.0, 360.0)
			g["rotacion_letrero"] = rot_deg
			var ry := -deg_to_rad(rot_deg)
			var nl := g.get("nodo_letrero") as Node3D
			if is_instance_valid(nl):
				nl.rotation.y = ry
			var gz := g.get("gizmo_letrero") as Node3D
			if is_instance_valid(gz):
				gz.rotation.y = ry
		return
	var pts: Array = g["puntos"]
	if idx_p < 0 or idx_p >= pts.size():
		return
	var p_nuevo := Vector3(nueva_pos.x, _altura_terreno(nueva_pos.x, nueva_pos.z, nueva_pos.y), nueva_pos.z)
	pts[idx_p] = p_nuevo

	# Actualizar únicamente la losa de concreto y el manejador arrastrado (sin reconstruir surtidores ni SubViewports)
	var altura_losa: float = float(g.get("altura_losa", 0.16))
	var mans: Array = g.get("manejadores", [])
	if idx_p < mans.size() and is_instance_valid(mans[idx_p]):
		(mans[idx_p] as Node3D).position = p_nuevo + Vector3(0.0, altura_losa + 0.62, 0.0)
	var nodo_conc := g.get("nodo_concreto") as Node3D
	if is_instance_valid(nodo_conc):
		for ch in nodo_conc.get_children():
			nodo_conc.remove_child(ch)
			ch.queue_free()
		_construir_base_concreto(nodo_conc, pts, altura_losa)
	else:
		_reconstruir_gasolinera(idx_g)

func finalizar_arrastre_punto(idx_g: int) -> void:
	if idx_g < 0 or idx_g >= _gasolineras.size():
		return
	_reconstruir_gasolinera(idx_g)

func esta_editando_puntos() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	return not bool(_gasolineras[indice_seleccionado].get("finalizado", false))

func buscar_punto_por_rayo(ray_orig: Vector3, ray_dir: Vector3, radio_hit: float = 1.6) -> Dictionary:
	var mejor_dist := 1e9
	var mejor := {"encontrado": false, "idx_zona": -1, "idx_pto": -1}
	for i in range(_gasolineras.size()):
		if bool(_gasolineras[i].get("finalizado", false)):
			continue
		var pts: Array = _gasolineras[i]["puntos"]
		var alt := float(_gasolineras[i].get("altura_losa", 0.16)) + 0.65
		for j in range(pts.size()):
			var p: Vector3 = (pts[j] as Vector3) + Vector3(0.0, alt, 0.0)
			var t := (p - ray_orig).dot(ray_dir)
			if t < 0.0:
				continue
			var d := (ray_orig + ray_dir * t).distance_to(p)
			if d <= radio_hit and t < mejor_dist:
				mejor_dist = t
				mejor = {"encontrado": true, "idx_zona": i, "idx_pto": j}
		# Punto de posicionamiento y gizmo de rotación del letrero de precios
		if _gasolineras[i].has("pos_letrero"):
			var pl: Vector3 = _gasolineras[i]["pos_letrero"] as Vector3
			if i == indice_seleccionado and (punto_seleccionado in [-2, -3]):
				var rot_l_rad := -deg_to_rad(float(_gasolineras[i].get("rotacion_letrero", 0.0)))
				var knob := pl + Vector3(0.0, 0.38, 2.35).rotated(Vector3.UP, rot_l_rad)
				var tk := (knob - ray_orig).dot(ray_dir)
				if tk >= 0.0:
					var dk := (ray_orig + ray_dir * tk).distance_to(knob)
					if dk <= radio_hit * 1.15 and tk < mejor_dist:
						mejor_dist = tk
						mejor = {"encontrado": true, "idx_zona": i, "idx_pto": -3}
			var pl_cen := pl + Vector3(0.0, 0.85, 0.0)
			var tl := (pl_cen - ray_orig).dot(ray_dir)
			if tl >= 0.0:
				var dl := (ray_orig + ray_dir * tl).distance_to(pl_cen)
				if dl <= radio_hit * 1.25 and tl < mejor_dist:
					mejor_dist = tl
					mejor = {"encontrado": true, "idx_zona": i, "idx_pto": -2}
	return mejor

func buscar_gasolinera_por_posicion(pos: Vector3, max_dist: float = 20.0) -> int:
	var best_idx := -1
	var best_d := max_dist
	var p2 := Vector2(pos.x, pos.z)
	for i in range(_gasolineras.size()):
		var pts: Array = _gasolineras[i]["puntos"]
		var poly := _pts_a_poly2d(pts)
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p2, poly):
			return i
		var c := _centro_puntos(pts)
		var d := Vector2(c.x, c.z).distance_to(p2)
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx

func finalizar_edicion_actual() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	_gasolineras[indice_seleccionado]["finalizado"] = true
	if bool(_gasolineras[indice_seleccionado].get("adaptar_terreno", true)):
		adaptar_terreno_gasolinera(indice_seleccionado)
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	return true

func activar_edicion_puntos_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	_gasolineras[indice_seleccionado]["finalizado"] = false
	_manejadores_visibles = true
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	return true

func agregar_punto_en_borde_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	var g: Dictionary = _gasolineras[indice_seleccionado]
	if bool(g.get("finalizado", false)):
		return false
	var pts: Array = g["puntos"]
	if pts.size() >= 24:
		return false
	var idx_a := clampi(punto_seleccionado, 0, pts.size() - 1)
	var idx_b := (idx_a + 1) % pts.size()
	var mid := ((pts[idx_a] as Vector3) + (pts[idx_b] as Vector3)) * 0.5
	mid.y = _altura_terreno(mid.x, mid.z, mid.y)
	pts.insert(idx_b, mid)
	punto_seleccionado = idx_b
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	return true

func subdividir_bordes_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	var g: Dictionary = _gasolineras[indice_seleccionado]
	if bool(g.get("finalizado", false)):
		return false
	var pts: Array = g["puntos"]
	if pts.size() * 2 > 24:
		return false
	var nuevos: Array[Vector3] = []
	for i in range(pts.size()):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		var m := (a + b) * 0.5
		m.y = _altura_terreno(m.x, m.z, m.y)
		nuevos.append(a)
		nuevos.append(m)
	g["puntos"] = nuevos
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	return true

func eliminar_punto_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	var g: Dictionary = _gasolineras[indice_seleccionado]
	if bool(g.get("finalizado", false)):
		return false
	var pts: Array = g["puntos"]
	if pts.size() <= 4:
		return false
	var idx_p := clampi(punto_seleccionado, 0, pts.size() - 1)
	pts.remove_at(idx_p)
	punto_seleccionado = clampi(idx_p, 0, pts.size() - 1)
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	return true

func rotar_seleccionado(delta_grados: float) -> float:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return 0.0
	var g: Dictionary = _gasolineras[indice_seleccionado]
	var pts: Array = g["puntos"]
	var centro := _centro_puntos(pts)
	var rad := -deg_to_rad(delta_grados)
	for i in range(pts.size()):
		var p: Vector3 = (pts[i] as Vector3) - centro
		p = p.rotated(Vector3.UP, rad) + centro
		p.y = _altura_terreno(p.x, p.z, p.y)
		pts[i] = p
	g["rotacion"] = wrapf(float(g.get("rotacion", 0.0)) + delta_grados, 0.0, 360.0)
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	return float(g["rotacion"])

func establecer_bahias_seleccionado(cant: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return
	_gasolineras[indice_seleccionado]["cantidad_bahias"] = clampi(cant, 1, 4)
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()

func establecer_surtidores_seleccionado(cant: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return
	_gasolineras[indice_seleccionado]["cantidad_surtidores"] = clampi(cant, 1, 8)
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()

func establecer_tipo_techo_seleccionado(tipo: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return
	_gasolineras[indice_seleccionado]["tipo_techo"] = clampi(tipo, 0, 3)
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()

func establecer_altura_techo_seleccionado(altura: float) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return
	var g: Dictionary = _gasolineras[indice_seleccionado]
	var nueva_alt := clampf(altura, 4.0, 7.5)
	if absf(float(g.get("altura_techo", 5.2)) - nueva_alt) < 0.05:
		return
	g["altura_techo"] = nueva_alt
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()

func establecer_tipo_letrero_seleccionado(tipo: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return
	_gasolineras[indice_seleccionado]["tipo_letrero"] = clampi(tipo, 0, 3)
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()

func rotar_letrero_seleccionado(delta_grados: float) -> float:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return 0.0
	var g: Dictionary = _gasolineras[indice_seleccionado]
	var rot_deg := wrapf(float(g.get("rotacion_letrero", 0.0)) + delta_grados, 0.0, 360.0)
	g["rotacion_letrero"] = rot_deg
	var ry := -deg_to_rad(rot_deg)
	var nl := g.get("nodo_letrero") as Node3D
	if is_instance_valid(nl):
		nl.rotation.y = ry
	var gz := g.get("gizmo_letrero") as Node3D
	if is_instance_valid(gz):
		gz.rotation.y = ry
	_emitir_seleccion()
	return rot_deg

func establecer_colores_seleccionado(primario: Color, secundario: Color, estructura: Color) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return
	var g: Dictionary = _gasolineras[indice_seleccionado]
	g["color_primario"] = primario
	g["color_secundario"] = secundario
	g["color_estructura"] = estructura
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()

func establecer_adaptar_terreno(activo: bool) -> void:
	adaptar_terreno_activo = activo
	if indice_seleccionado >= 0 and indice_seleccionado < _gasolineras.size():
		_gasolineras[indice_seleccionado]["adaptar_terreno"] = activo
		if activo:
			adaptar_terreno_gasolinera(indice_seleccionado)
			_reconstruir_gasolinera(indice_seleccionado)
		_emitir_seleccion()

func adaptar_terreno_gasolinera(idx: int) -> void:
	if idx < 0 or idx >= _gasolineras.size():
		return
	if not controlador_terreno or not controlador_terreno.terrain or not controlador_terreno.terrain.data:
		return
	var terrain = controlador_terreno.terrain
	var t_data = terrain.data
	var pts: Array = _gasolineras[idx]["puntos"]
	if pts.size() < 3:
		return

	var h_prom := 0.0
	for p in pts:
		h_prom += float((p as Vector3).y)
	h_prom /= float(pts.size())
	for i in range(pts.size()):
		var pi: Vector3 = pts[i]
		pts[i] = Vector3(pi.x, h_prom, pi.z)

	var poly := _pts_a_poly2d(pts)
	var vertex_spacing: float = terrain.vertex_spacing if terrain.vertex_spacing > 0.0 else 1.0
	var edge_margin := 1.6
	var edge_falloff := 5.5
	var pad := edge_margin + edge_falloff + vertex_spacing * 2.0

	var min_x := float(pts[0].x); var max_x := float(pts[0].x)
	var min_z := float(pts[0].z); var max_z := float(pts[0].z)
	for p in pts:
		min_x = minf(min_x, float(p.x)); max_x = maxf(max_x, float(p.x))
		min_z = minf(min_z, float(p.z)); max_z = maxf(max_z, float(p.z))

	var min_xz := Vector3(min_x - pad, 0.0, min_z - pad).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing))
	var max_xz := Vector3(max_x + pad, 0.0, max_z + pad).snapped(Vector3(vertex_spacing, 0.0, vertex_spacing)) + Vector3(vertex_spacing, 0.0, vertex_spacing)

	var modificado := false
	var h_target := h_prom - 0.04
	var x := min_xz.x
	while x <= max_xz.x:
		var z := min_xz.z
		while z <= max_xz.z:
			var world_pos := Vector3(x, 0.0, z)
			if t_data.has_regionp(world_pos):
				var curr_h: float = t_data.get_height(world_pos)
				if not is_nan(curr_h):
					var p_xz := Vector2(x, z)
					var dentro := Geometry2D.is_point_in_polygon(p_xz, poly)
					var dist := 0.0
					if not dentro:
						dist = 999999.0
						for i in range(pts.size()):
							var q := Geometry2D.get_closest_point_to_segment(p_xz, poly[i], poly[(i + 1) % pts.size()])
							dist = minf(dist, p_xz.distance_to(q))
					if dist <= edge_margin:
						if absf(curr_h - h_target) > 0.015:
							t_data.set_height(world_pos, h_target)
							modificado = true
					elif dist <= edge_margin + edge_falloff:
						var t := (dist - edge_margin) / edge_falloff
						var factor := t * t * (3.0 - 2.0 * t)
						var desired := lerpf(h_target, curr_h, factor)
						if absf(curr_h - desired) > 0.015:
							t_data.set_height(world_pos, desired)
							modificado = true
			z += vertex_spacing
		x += vertex_spacing

	if modificado:
		t_data.update_maps(0)
		t_data.calc_height_range()
		if controlador_terreno.has_signal("terreno_modificado"):
			controlador_terreno.terreno_modificado.emit()

func establecer_lado_conexion_seleccionado(lado: int) -> void:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return
	_gasolineras[indice_seleccionado]["lado_conexion"] = clampi(lado, 0, 3)
	_emitir_seleccion()

func _obtener_borde_conexion(g: Dictionary, lado: int) -> Dictionary:
	var pts: Array = g["puntos"]
	var centro := _centro_puntos(pts)
	var rot_rad := -deg_to_rad(float(g.get("rotacion", 0.0)))
	var altura_losa: float = float(g.get("altura_losa", 0.16))
	# Direcciones locales por lado: 0=Frontal(-Z), 1=Derecho(+X), 2=Trasero(+Z), 3=Izquierdo(-X)
	var dirs_loc := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	var dir_loc: Vector3 = dirs_loc[clampi(lado, 0, 3)]
	var dir_mundo := dir_loc.rotated(Vector3.UP, rot_rad).normalized()
	var right_mundo := dir_mundo.cross(Vector3.UP).normalized()

	var max_proj := -1e9
	for p in pts:
		var proj := ((p as Vector3) - centro).dot(dir_mundo)
		max_proj = maxf(max_proj, proj)

	var p_cen := centro + dir_mundo * max_proj
	p_cen.y = centro.y + altura_losa
	var half_w := 4.5
	return {
		"centro": p_cen,
		"izq": p_cen - right_mundo * half_w,
		"der": p_cen + right_mundo * half_w
	}

func conectar_a_carretera_seleccionada() -> Dictionary:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return {"ok": false, "mensaje": "Selecciona primero una gasolinera"}
	if not controlador_carreteras or not controlador_carreteras.road_container or not is_instance_valid(controlador_carreteras.road_container):
		return {"ok": false, "mensaje": "No hay sistema de carreteras disponible"}
	var g: Dictionary = _gasolineras[indice_seleccionado]
	var lado := int(g.get("lado_conexion", 0))
	var borde := _obtener_borde_conexion(g, lado)
	var p_ent: Vector3 = borde["centro"]

	var mejor_pt := Vector3.ZERO
	var mejor_dist := 260.0
	var mejor_ancho := 8.8
	var encontro := false
	for obj in controlador_carreteras.road_container.get_segments():
		var seg := obj as Node3D
		if not is_instance_valid(seg):
			continue
		var curva: Curve3D = seg.get("curve") as Curve3D
		if not curva:
			continue
		var local_p: Vector3 = seg.to_local(p_ent) if seg.is_inside_tree() else (p_ent - seg.position)
		var closest_local: Vector3 = curva.get_closest_point(local_p)
		var closest_world: Vector3 = seg.to_global(closest_local) if seg.is_inside_tree() else (seg.position + closest_local)
		var d := p_ent.distance_to(closest_world)
		if d < mejor_dist:
			mejor_dist = d
			mejor_pt = closest_world
			if controlador_carreteras.has_method("_obtener_ancho_via_punto") and seg.get("start_point") != null:
				mejor_ancho = float(controlador_carreteras._obtener_ancho_via_punto(seg.get("start_point")))
			encontro = true

	if not encontro:
		return {"ok": false, "mensaje": "No se encontró ninguna carretera cercana (máx. 260m)"}

	g["conexion_via"] = {"lado": lado, "punto_via": [mejor_pt.x, mejor_pt.y, mejor_pt.z], "ancho_via": mejor_ancho}
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	var nombres_lado := ["Frontal", "Derecho", "Trasero", "Izquierdo"]
	return {"ok": true, "mensaje": "✓ Conectado por el lado %s (%.1fm)" % [nombres_lado[lado], mejor_dist]}

func desconectar_carretera_seleccionada() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	_gasolineras[indice_seleccionado]["conexion_via"] = {}
	_reconstruir_gasolinera(indice_seleccionado)
	_emitir_seleccion()
	return true

func nivelar_terreno_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	adaptar_terreno_gasolinera(indice_seleccionado)
	_reconstruir_gasolinera(indice_seleccionado)
	return true

func adaptar_base_a_terreno_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	var g: Dictionary = _gasolineras[indice_seleccionado]
	var pts: Array = g["puntos"]
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		pts[i] = Vector3(p.x, _altura_terreno(p.x, p.z, p.y), p.z)
	if g.has("pos_letrero"):
		var pl: Vector3 = g["pos_letrero"]
		g["pos_letrero"] = Vector3(pl.x, _altura_terreno(pl.x, pl.z, pl.y), pl.z)
	_reconstruir_gasolinera(indice_seleccionado)
	return true

func eliminar_seleccionado() -> bool:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return false
	return eliminar_gasolinera(indice_seleccionado)

func borrar_gasolinera_en_posicion(pos: Vector3) -> bool:
	var idx := buscar_gasolinera_por_posicion(pos)
	if idx < 0:
		return false
	return eliminar_gasolinera(idx)

func eliminar_gasolinera(idx: int) -> bool:
	if idx < 0 or idx >= _gasolineras.size():
		return false
	var n := _gasolineras[idx].get("nodo") as Node
	if is_instance_valid(n):
		n.queue_free()
	_gasolineras.remove_at(idx)
	if indice_seleccionado == idx:
		indice_seleccionado = -1
		punto_seleccionado = -1
	elif indice_seleccionado > idx:
		indice_seleccionado -= 1
	_emitir_seleccion()
	gasolinera_actualizada.emit(_gasolineras.size())
	return true

func limpiar_todos() -> void:
	for g in _gasolineras:
		var n := g.get("nodo") as Node
		if is_instance_valid(n):
			n.queue_free()
	_gasolineras.clear()
	indice_seleccionado = -1
	punto_seleccionado = -1
	_emitir_seleccion()
	gasolinera_actualizada.emit(0)

func obtener_centro_seleccionado() -> Vector3:
	if indice_seleccionado < 0 or indice_seleccionado >= _gasolineras.size():
		return Vector3.ZERO
	return _centro_puntos(_gasolineras[indice_seleccionado]["puntos"])

# ==============================================================================
# RECONSTRUCCIÓN PROCEDURAL DE LA GASOLINERA
# ==============================================================================
func _reconstruir_gasolinera(idx: int) -> void:
	if idx < 0 or idx >= _gasolineras.size():
		return
	var g: Dictionary = _gasolineras[idx]
	var nodo := g["nodo"] as Node3D
	for ch in nodo.get_children():
		nodo.remove_child(ch)
		ch.queue_free()

	var manejadores: Array[MeshInstance3D] = []
	g["manejadores"] = manejadores

	var pts: Array = g["puntos"]
	if pts.size() < 3:
		return

	var altura_losa: float = float(g.get("altura_losa", 0.16))
	var col_pri: Color = g.get("color_primario", Color(0.86, 0.14, 0.14))
	var col_sec: Color = g.get("color_secundario", Color(0.95, 0.72, 0.12))
	var col_est: Color = g.get("color_estructura", Color(0.88, 0.90, 0.92))

	var mat_pri := StandardMaterial3D.new()
	mat_pri.albedo_color = col_pri
	mat_pri.metallic = 0.32
	mat_pri.roughness = 0.34
	if _tex_metal_norm:
		mat_pri.normal_enabled = true
		mat_pri.normal_texture = _tex_metal_norm
		mat_pri.normal_scale = 0.55
		mat_pri.roughness_texture = _tex_metal_rough
		mat_pri.uv1_triplanar = true
		mat_pri.uv1_world_triplanar = true
		mat_pri.uv1_scale = Vector3(0.45, 0.45, 0.45)

	var mat_sec := StandardMaterial3D.new()
	mat_sec.albedo_color = col_sec
	mat_sec.metallic = 0.25
	mat_sec.roughness = 0.36
	if _tex_metal_norm:
		mat_sec.normal_enabled = true
		mat_sec.normal_texture = _tex_metal_norm
		mat_sec.normal_scale = 0.45
		mat_sec.uv1_triplanar = true
		mat_sec.uv1_world_triplanar = true
		mat_sec.uv1_scale = Vector3(0.45, 0.45, 0.45)

	var mat_est := StandardMaterial3D.new()
	mat_est.albedo_color = col_est
	mat_est.metallic = 0.65
	mat_est.roughness = 0.32
	if _tex_metal_norm:
		mat_est.normal_enabled = true
		mat_est.normal_texture = _tex_metal_norm
		mat_est.normal_scale = 0.65
		mat_est.roughness_texture = _tex_metal_rough
		mat_est.uv1_triplanar = true
		mat_est.uv1_world_triplanar = true
		mat_est.uv1_scale = Vector3(0.5, 0.5, 0.5)

	# 1. BASE DE CONCRETO PROCEDURAL (aislada en nodo_concreto para arrastre rápido)
	var nodo_conc := Node3D.new()
	nodo_conc.name = "BaseConcreto"
	nodo.add_child(nodo_conc)
	g["nodo_concreto"] = nodo_conc
	_construir_base_concreto(nodo_conc, pts, altura_losa)

	# 1b. RAMPA DE CONEXIÓN A CARRETERA (solo desde el lado elegido)
	var con_via: Dictionary = g.get("conexion_via", {})
	if con_via.has("punto_via") and con_via["punto_via"] is Array and (con_via["punto_via"] as Array).size() >= 3:
		var pva: Array = con_via["punto_via"]
		var p_via := Vector3(float(pva[0]), float(pva[1]), float(pva[2]))
		var lado_con := int(con_via.get("lado", g.get("lado_conexion", 0)))
		var borde_con := _obtener_borde_conexion(g, lado_con)
		_construir_rampa_conexion_via(nodo, borde_con["izq"], borde_con["der"], p_via, float(con_via.get("ancho_via", 8.8)), altura_losa)

	# 2. CALCULAR ÁREA INTERIOR ORIENTADA PARA BAHÍAS Y TECHO
	var centro := _centro_puntos(pts)
	var rot_deg := float(g.get("rotacion", 0.0))
	var rot_rad := -deg_to_rad(rot_deg)

	var min_x := 1e9; var max_x := -1e9
	var min_z := 1e9; var max_z := -1e9
	for p in pts:
		var loc: Vector3 = ((p as Vector3) - centro).rotated(Vector3.UP, -rot_rad)
		min_x = minf(min_x, loc.x); max_x = maxf(max_x, loc.x)
		min_z = minf(min_z, loc.z); max_z = maxf(max_z, loc.z)

	var ancho_util := maxf(10.0, (max_x - min_x) * 0.80)
	var largo_util := maxf(8.0, (max_z - min_z) * 0.78)
	var y_superficie := centro.y + altura_losa

	var zona := ZonaGasolineraScript.new()
	zona.name = "ZonaGasolinera"
	zona.position = Vector3(centro.x, y_superficie, centro.z)
	zona.rotation.y = rot_rad
	zona.color_primario = col_pri
	zona.color_secundario = col_sec
	nodo.add_child(zona)

	# 3. BAHÍAS, ISLAS, SURTIDORES Y ZONAS DE ESTACIONAMIENTO
	var num_bahias: int = clampi(int(g.get("cantidad_bahias", 2)), 1, 4)
	var num_surtidores: int = clampi(int(g.get("cantidad_surtidores", 4)), 1, 8)
	var altura_techo: float = float(g.get("altura_techo", 5.2))
	var tipo_techo: int = clampi(int(g.get("tipo_techo", 0)), 0, 3)

	var paso_z := maxf(13.0, largo_util / float(num_bahias))
	var total_span_z := paso_z * float(num_bahias)
	var surtidores_por_bahia: Array[int] = []
	for b in range(num_bahias):
		surtidores_por_bahia.append(0)
	for s in range(num_surtidores):
		surtidores_por_bahia[s % num_bahias] += 1

	var posiciones_columnas: Array[Vector3] = []
	var max_largo_isla := 6.5
	var z_min_isla := 1e9
	var z_max_isla := -1e9

	var tex_copete_est := _crear_textura_copete(col_pri, col_sec)
	var mat_copete_est := StandardMaterial3D.new()
	mat_copete_est.albedo_texture = tex_copete_est
	mat_copete_est.emission_enabled = true
	mat_copete_est.emission_texture = tex_copete_est
	mat_copete_est.emission_energy_multiplier = 0.9

	for b in range(num_bahias):
		var z_isla := -total_span_z * 0.5 + paso_z * (float(b) + 0.5)
		z_min_isla = minf(z_min_isla, z_isla)
		z_max_isla = maxf(z_max_isla, z_isla)
		var cant_s := surtidores_por_bahia[b]
		var largo_isla := clampf(maxf(6.5, float(cant_s) * 4.8), 6.5, maxf(12.0, ancho_util * 0.85))
		max_largo_isla = maxf(max_largo_isla, largo_isla)

		# Isla de concreto + bordillo de seguridad industrial
		_crear_caja_static(zona, Vector3(largo_isla, 0.22, 1.65), Vector3(0.0, 0.11, z_isla), _mat_isla)
		_crear_caja(zona, Vector3(largo_isla + 0.08, 0.08, 1.73), Vector3(0.0, 0.04, z_isla), _mat_bordillo_isla)
		# Bolardos de protección en extremos de isla
		for bx in [-largo_isla * 0.5 + 0.35, largo_isla * 0.5 - 0.35]:
			_crear_cilindro(zona, 0.11, 0.90, Vector3(bx, 0.67, z_isla - 0.55), mat_sec)
			_crear_cilindro(zona, 0.11, 0.90, Vector3(bx, 0.67, z_isla + 0.55), mat_sec)

		# Extintores contra incendios en los extremos de la isla
		_crear_extintor(zona, Vector3(-largo_isla * 0.5 + 0.72, 0.22, z_isla))
		_crear_extintor(zona, Vector3(largo_isla * 0.5 - 0.72, 0.22, z_isla))

		posiciones_columnas.append(Vector3(-largo_isla * 0.36, 0.0, z_isla))
		posiciones_columnas.append(Vector3(largo_isla * 0.36, 0.0, z_isla))

		# Demarcación amplia de carriles de estacionamiento (autos, buses y tractomulas)
		var offset_carril := 4.25
		for lado: float in [-1.0, 1.0]:
			var z_carril: float = z_isla + lado * offset_carril
			_crear_demarcacion_bahia(zona, Vector3(0.0, 0.015, z_carril), largo_isla + 6.5, 4.6)

		# Zona de parqueo vehicular amplia para esta bahía
		var area_veh := Area3D.new()
		area_veh.name = "AreaVehiculoBahia_%d" % b
		var cs_veh := CollisionShape3D.new()
		var box_veh := BoxShape3D.new()
		box_veh.size = Vector3(largo_isla + 7.0, 4.8, 12.2)
		cs_veh.shape = box_veh
		area_veh.add_child(cs_veh)
		area_veh.position = Vector3(0.0, 2.4, z_isla)
		zona.add_child(area_veh)

		# Instanciar surtidores en la isla
		if cant_s > 0:
			var paso_s := (largo_isla - 2.0) / float(max(1, cant_s))
			for si in range(cant_s):
				var x_s := 0.0 if cant_s == 1 else (- (largo_isla - 2.0) * 0.5 + paso_s * (float(si) + 0.5))
				var pos_s := Vector3(x_s, 0.22, z_isla)
				_instanciar_surtidor(zona, pos_s, mat_pri, mat_sec, mat_est, area_veh, col_pri, col_sec, col_est, mat_copete_est)

	# 4. TECHO PROCEDURAL AJUSTADO A LOS SURTIDORES Y BAHÍAS (NO AL CONCRETO COMPLETO)
	var techo_ancho := max_largo_isla + 6.8
	var techo_largo := (z_max_isla - z_min_isla) + 12.2
	var z_centro_techo := (z_min_isla + z_max_isla) * 0.5
	_construir_techo_procedural(zona, techo_ancho, techo_largo, z_centro_techo, altura_techo, tipo_techo, posiciones_columnas, mat_pri, mat_sec, mat_est)

	# 5. LETRERO GRANDE DE PRECIOS DE COMBUSTIBLE (posicionable con su propio punto)
	if not g.has("pos_letrero"):
		var def_pos := Vector3(maxf(ancho_util * 0.5 - 1.5, techo_ancho * 0.5 + 2.2), 0.0, minf(-largo_util * 0.5 + 1.5, z_min_isla - 4.8))
		var pl_w := Vector3(centro.x, y_superficie, centro.z) + def_pos.rotated(Vector3.UP, rot_rad)
		pl_w.y = _altura_terreno(pl_w.x, pl_w.z, centro.y)
		g["pos_letrero"] = pl_w
	var pos_let_mundo: Vector3 = g["pos_letrero"]
	var rot_let_deg: float = float(g.get("rotacion_letrero", rot_deg))
	var tipo_let: int = clampi(int(g.get("tipo_letrero", 0)), 0, 3)
	g["nodo_letrero"] = _crear_letrero_precios(nodo, pos_let_mundo, -deg_to_rad(rot_let_deg), tipo_let, mat_pri, mat_sec, mat_est, col_pri, col_sec)

	# 6. MANEJADORES DE PUNTOS EN EL EDITOR
	var mostrar_ed := _manejadores_visibles and not bool(g.get("finalizado", false))
	for j in range(pts.size()):
		var esf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.62; sm.height = 1.24
		esf.mesh = sm
		esf.position = (pts[j] as Vector3) + Vector3(0.0, altura_losa + 0.62, 0.0)
		esf.visible = mostrar_ed
		esf.material_override = _mat_punto_sel if (idx == indice_seleccionado and j == punto_seleccionado) else _mat_punto_idle
		nodo.add_child(esf)
		manejadores.append(esf)

	# Manejador independiente del letrero de precios (esfera cian) + Gizmo de rotación
	var esf_l := MeshInstance3D.new()
	var sm_l := SphereMesh.new()
	sm_l.radius = 0.72; sm_l.height = 1.44
	esf_l.mesh = sm_l
	esf_l.position = pos_let_mundo + Vector3(0.0, 0.85, 0.0)
	esf_l.visible = mostrar_ed
	esf_l.material_override = _mat_punto_sel if (idx == indice_seleccionado and (punto_seleccionado in [-2, -3])) else _mat_punto_letrero
	nodo.add_child(esf_l)
	g["manejador_letrero"] = esf_l

	var gizmo_l := Node3D.new()
	gizmo_l.name = "GizmoRotacionLetrero"
	gizmo_l.position = pos_let_mundo + Vector3(0.0, 0.38, 0.0)
	gizmo_l.rotation.y = -deg_to_rad(rot_let_deg)
	gizmo_l.visible = mostrar_ed and (idx == indice_seleccionado) and (punto_seleccionado in [-2, -3])
	nodo.add_child(gizmo_l)

	var ring_m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.25
	torus.outer_radius = 2.45
	torus.rings = 32
	torus.ring_segments = 8
	ring_m.mesh = torus
	ring_m.scale = Vector3(1.0, 0.25, 1.0)
	ring_m.material_override = _mat_gizmo_rot
	gizmo_l.add_child(ring_m)

	var knob_m := MeshInstance3D.new()
	var sm_k := SphereMesh.new()
	sm_k.radius = 0.52; sm_k.height = 1.04
	knob_m.mesh = sm_k
	knob_m.position = Vector3(0.0, 0.0, 2.35)
	knob_m.material_override = _mat_punto_sel if (idx == indice_seleccionado and punto_seleccionado == -3) else _mat_gizmo_rot
	gizmo_l.add_child(knob_m)
	g["gizmo_letrero"] = gizmo_l

func _construir_base_concreto(nodo: Node3D, pts: Array, altura_losa: float) -> void:
	var poly := _pts_a_poly2d(pts)
	var tris := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ti in range(0, tris.size(), 3):
		var a: Vector3 = pts[tris[ti]] + Vector3(0.0, altura_losa, 0.0)
		var b: Vector3 = pts[tris[ti + 1]] + Vector3(0.0, altura_losa, 0.0)
		var c: Vector3 = pts[tris[ti + 2]] + Vector3(0.0, altura_losa, 0.0)
		var nrm := (b - a).cross(c - a)
		if nrm.y > 0.0:
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
		else:
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

	var n := pts.size()
	var area2 := 0.0
	for i in range(n):
		var j := (i + 1) % n
		area2 += (poly[i].x * poly[j].y - poly[j].x * poly[i].y)
	var ccw := area2 > 0.0
	for i in range(n):
		var j := (i + 1) % n
		var e0: Vector3 = (pts[i] as Vector3) + Vector3(0.0, altura_losa, 0.0)
		var e1: Vector3 = (pts[j] as Vector3) + Vector3(0.0, altura_losa, 0.0)
		var b0 := e0 - Vector3(0.0, altura_losa + 0.65, 0.0)
		var b1 := e1 - Vector3(0.0, altura_losa + 0.65, 0.0)
		if ccw:
			st.add_vertex(e0); st.add_vertex(b0); st.add_vertex(b1)
			st.add_vertex(e0); st.add_vertex(b1); st.add_vertex(e1)
		else:
			st.add_vertex(e0); st.add_vertex(e1); st.add_vertex(b1)
			st.add_vertex(e0); st.add_vertex(b1); st.add_vertex(b0)

	st.generate_normals()
	var mesh_losa := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_losa
	mi.material_override = _mat_concreto
	nodo.add_child(mi)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh_losa.create_trimesh_shape()
	sb.add_child(cs)
	nodo.add_child(sb)

func _construir_rampa_conexion_via(nodo: Node3D, p_ent_izq: Vector3, p_ent_der: Vector3, p_via: Vector3, ancho_via: float, altura_losa: float) -> void:
	var p_ent_cen := 0.5 * (p_ent_izq + p_ent_der)
	var dir_total := Vector3(p_via.x - p_ent_cen.x, 0.0, p_via.z - p_ent_cen.z)
	if dir_total.length() < 0.8:
		return
	var dir_xz := dir_total.normalized()
	var recorte_via := maxf(0.0, ancho_via * 0.5 - 0.35)
	var dist_util := maxf(1.6, dir_total.length() - recorte_via)
	var p_destino := p_ent_cen + dir_xz * dist_util
	p_destino.y = p_via.y + 0.04

	var right := Vector3.UP.cross(dir_xz).normalized()
	var half_w_base := maxf(5.0, p_ent_izq.distance_to(p_ent_der) * 0.52)
	var flare_extra := minf(3.8, dist_util * 0.42)
	var yaw_r := atan2(dir_xz.x, dir_xz.z)

	# Construir rampa acampanada (embudo comercial de entrada/salida) en 5 segmentos
	var segs := 5
	var pts_l: Array[Vector3] = []
	var pts_r: Array[Vector3] = []
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var c_t := p_ent_cen.lerp(p_destino, t)
		var hw_t := half_w_base + flare_extra * (t * t)
		pts_l.append(c_t - right * hw_t)
		pts_r.append(c_t + right * hw_t)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_bord := SurfaceTool.new()
	st_bord.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_lin := SurfaceTool.new()
	st_lin.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ref_in := 0.5 * (p_ent_cen + p_destino) - Vector3(0, 1.5, 0)
	for i in range(segs):
		var a0: Vector3 = pts_l[i]; var b0: Vector3 = pts_r[i]
		var a1: Vector3 = pts_l[i + 1]; var b1: Vector3 = pts_r[i + 1]
		_agregar_tri_orientado(st, a0, b0, b1, ref_in)
		_agregar_tri_orientado(st, a0, b1, a1, ref_in)
		# Faldones laterales hacia el terreno
		var da0 := a0 - Vector3(0, altura_losa + 0.7, 0)
		var db0 := b0 - Vector3(0, altura_losa + 0.7, 0)
		var da1 := a1 - Vector3(0, 0.7, 0)
		var db1 := b1 - Vector3(0, 0.7, 0)
		_agregar_tri_orientado(st, a0, a1, da1, ref_in)
		_agregar_tri_orientado(st, a0, da1, da0, ref_in)
		_agregar_tri_orientado(st, b1, b0, db0, ref_in)
		_agregar_tri_orientado(st, b1, db0, db1, ref_in)

		# Bordillos laterales elevados
		_agregar_segmento_caja(st_bord, a0 + Vector3(0, 0.08, 0), a1 + Vector3(0, 0.08, 0), 0.34, 0.18)
		_agregar_segmento_caja(st_bord, b0 + Vector3(0, 0.08, 0), b1 + Vector3(0, 0.08, 0), 0.34, 0.18)

		# Líneas amarillas de borde interior
		_agregar_segmento_caja(st_lin, a0 + right * 0.42 + Vector3(0, 0.02, 0), a1 + right * 0.42 + Vector3(0, 0.02, 0), 0.14, 0.02)
		_agregar_segmento_caja(st_lin, b0 - right * 0.42 + Vector3(0, 0.02, 0), b1 - right * 0.42 + Vector3(0, 0.02, 0), 0.14, 0.02)

	st.generate_normals()
	var mesh_r := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_r
	mi.material_override = _mat_concreto
	nodo.add_child(mi)

	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh_r.create_trimesh_shape()
	sb.add_child(cs)
	nodo.add_child(sb)

	st_bord.generate_normals()
	var mi_bord := MeshInstance3D.new()
	mi_bord.mesh = st_bord.commit()
	mi_bord.material_override = _mat_isla
	nodo.add_child(mi_bord)

	st_lin.generate_normals()
	var mi_lin := MeshInstance3D.new()
	mi_lin.mesh = st_lin.commit()
	mi_lin.material_override = _mat_linea_amarilla
	nodo.add_child(mi_lin)

	# Bolardos reflectivos en las esquinas de la boca de entrada
	_crear_cilindro(nodo, 0.12, 0.88, pts_l[0] + right * 0.25 + Vector3(0, 0.44, 0), _mat_linea_amarilla)
	_crear_cilindro(nodo, 0.12, 0.88, pts_r[0] - right * 0.25 + Vector3(0, 0.44, 0), _mat_linea_amarilla)

	# Línea central divisoria discontinua + flechas de carril (entrada / salida)
	var pasos := maxi(1, int(dist_util / 2.8))
	for k in range(pasos):
		var t := (float(k) + 0.5) / float(pasos)
		var c_seg := p_ent_cen.lerp(p_destino, t) + Vector3(0, 0.025, 0)
		var q_m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.02, 1.35)
		q_m.mesh = bm
		q_m.material_override = _mat_linea_amarilla
		q_m.position = c_seg
		q_m.rotation.y = yaw_r
		nodo.add_child(q_m)

	# Flechas blancas de sentido en ambos carriles a mitad de la entrada
	var c_mid := p_ent_cen.lerp(p_destino, 0.5) + Vector3(0, 0.028, 0)
	for lane_cfg in [{"off": -half_w_base * 0.46, "rot": yaw_r}, {"off": half_w_base * 0.46, "rot": yaw_r + PI}]:
		var arr_root := Node3D.new()
		arr_root.position = c_mid + right * float(lane_cfg["off"])
		arr_root.rotation.y = float(lane_cfg["rot"])
		nodo.add_child(arr_root)
		_crear_caja(arr_root, Vector3(0.24, 0.02, 1.6), Vector3(0, 0, 0), _mat_linea_blanca)
		var wing_l := _crear_caja(arr_root, Vector3(0.22, 0.02, 0.9), Vector3(-0.28, 0, 0.55), _mat_linea_blanca)
		wing_l.rotation.y = deg_to_rad(38.0)
		var wing_r := _crear_caja(arr_root, Vector3(0.22, 0.02, 0.9), Vector3(0.28, 0, 0.55), _mat_linea_blanca)
		wing_r.rotation.y = deg_to_rad(-38.0)

func _instanciar_surtidor(zona: ZonaGasolinera, pos: Vector3, mat_pri: StandardMaterial3D, mat_sec: StandardMaterial3D, mat_est: StandardMaterial3D, area_veh: Area3D, col_pri: Color, col_sec: Color, col_est: Color, mat_copete_shared: StandardMaterial3D = null) -> void:
	var surt_node := Node3D.new()
	surt_node.position = pos
	zona.add_child(surt_node)

	if _escena_surtidor:
		var inst := _escena_surtidor.instantiate() as Node3D
		surt_node.add_child(inst)
		for ch in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := ch as MeshInstance3D
			if not mi or not mi.mesh:
				continue
			for s in range(mi.mesh.get_surface_count()):
				var mat := mi.mesh.surface_get_material(s)
				if mat:
					if mat.resource_name == "Mat_Primario":
						mi.set_surface_override_material(s, mat_pri)
					elif mat.resource_name == "Mat_Secundario":
						mi.set_surface_override_material(s, mat_sec)
					elif mat.resource_name == "Mat_Estructura":
						mi.set_surface_override_material(s, mat_est)
					elif mat.resource_name in ["Mat_Metal", "Mat_Teclado"]:
						mi.set_surface_override_material(s, _mat_metal_oscuro)
					elif mat.resource_name == "Mat_Pantalla":
						mi.set_surface_override_material(s, _mat_vidrio_oscuro)
	else:
		_crear_caja(surt_node, Vector3(0.95, 2.2, 0.55), Vector3(0, 1.1, 0), mat_pri)

	# Colisión del surtidor
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(1.05, 2.3, 0.62)
	cs.shape = bsh
	cs.position = Vector3(0, 1.15, 0)
	sb.add_child(cs)
	surt_node.add_child(sb)

	# Pantalla LCD 2D real via SubViewport (0.56 x 0.38 m encajada dentro del marco)
	var pantalla_2d := PantallaSurtidor2DScript.new()
	surt_node.add_child(pantalla_2d)

	var mat_lcd := StandardMaterial3D.new()
	mat_lcd.albedo_texture = pantalla_2d.get_texture()
	mat_lcd.emission_enabled = true
	mat_lcd.emission_texture = pantalla_2d.get_texture()
	mat_lcd.emission_energy_multiplier = 1.15
	mat_lcd.roughness = 0.12

	var mat_copete := mat_copete_shared
	if mat_copete == null:
		var tex_copete := _crear_textura_copete(col_pri, col_sec)
		mat_copete = StandardMaterial3D.new()
		mat_copete.albedo_texture = tex_copete
		mat_copete.emission_enabled = true
		mat_copete.emission_texture = tex_copete
		mat_copete.emission_energy_multiplier = 0.9

	for lado_cfg in [{"z": 1.0, "rot_y": 0.0}, {"z": -1.0, "rot_y": PI}]:
		var sz: float = float(lado_cfg["z"])
		var ry: float = float(lado_cfg["rot_y"])

		var quad_lcd := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.56, 0.38)
		quad_lcd.mesh = qm
		quad_lcd.material_override = mat_lcd
		quad_lcd.position = Vector3(0.0, 1.70, sz * 0.256)
		quad_lcd.rotation.y = ry
		surt_node.add_child(quad_lcd)

		var quad_cop := MeshInstance3D.new()
		var qmc := QuadMesh.new()
		qmc.size = Vector2(0.84, 0.15)
		quad_cop.mesh = qmc
		quad_cop.material_override = mat_copete
		quad_cop.position = Vector3(0.0, 2.32, sz * 0.296)
		quad_cop.rotation.y = ry
		surt_node.add_child(quad_cop)

		var quad_gr := MeshInstance3D.new()
		var qmg := QuadMesh.new()
		qmg.size = Vector2(0.54, 0.10)
		quad_gr.mesh = qmg
		quad_gr.material_override = _mat_grados_cache
		quad_gr.position = Vector3(0.0, 1.34, sz * 0.258)
		quad_gr.rotation.y = ry
		surt_node.add_child(quad_gr)

	# Área de interacción a pie junto al surtidor
	var area_s := Area3D.new()
	area_s.name = "AreaInteraccionSurtidor"
	var cs_s := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.8
	cs_s.shape = sph
	area_s.add_child(cs_s)
	area_s.position = Vector3(0, 1.0, 0)
	surt_node.add_child(area_s)

	zona.registrar_surtidor(pos, area_veh, area_s, pantalla_2d)

func _crear_demarcacion_bahia(padre: Node3D, pos: Vector3, largo: float, ancho: float) -> void:
	var hw := largo * 0.5
	var hd := ancho * 0.5
	# Líneas laterales del cajón
	_crear_caja(padre, Vector3(largo, 0.02, 0.14), pos + Vector3(0, 0, -hd), _mat_linea_amarilla)
	_crear_caja(padre, Vector3(largo, 0.02, 0.14), pos + Vector3(0, 0, hd), _mat_linea_amarilla)
	# Marcas de entrada/salida en extremos
	_crear_caja(padre, Vector3(0.18, 0.02, ancho * 0.4), pos + Vector3(-hw, 0, 0), _mat_linea_blanca)
	_crear_caja(padre, Vector3(0.18, 0.02, ancho * 0.4), pos + Vector3(hw, 0, 0), _mat_linea_blanca)

func _agregar_tri_orientado(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref_interior: Vector3) -> void:
	var centro := (a + b + c) / 3.0
	var nrm := (b - a).cross(c - a)
	# En Godot el frente horario tiene (b-a)x(c-a) apuntando hacia el interior
	if nrm.dot(centro - ref_interior) > 0.0:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

func _construir_techo_procedural(padre: Node3D, ancho: float, largo: float, z_centro: float, altura: float, tipo: int, cols: Array[Vector3], mat_pri: StandardMaterial3D, mat_sec: StandardMaterial3D, mat_est: StandardMaterial3D) -> void:
	# Columnas estructurales sobre las islas
	for cpos in cols:
		_crear_caja_static(padre, Vector3(0.36, altura, 0.36), Vector3(cpos.x, altura * 0.5, cpos.z), mat_est)
		_crear_caja(padre, Vector3(0.44, 0.55, 0.44), Vector3(cpos.x, 0.48, cpos.z), mat_pri)

	var techo_root := Node3D.new()
	techo_root.name = "TechoCanopy"
	techo_root.position = Vector3(0.0, 0.0, z_centro)
	padre.add_child(techo_root)

	var w := ancho
	var d := largo

	match tipo:
		TipoTecho.PLANO_MODERNO:
			_crear_caja(techo_root, Vector3(w - 0.3, 0.12, d - 0.3), Vector3(0, altura, 0), _mat_techo_cielo)
			_crear_caja(techo_root, Vector3(w, 0.72, d), Vector3(0, altura + 0.42, 0), mat_pri)
			_crear_caja(techo_root, Vector3(w + 0.12, 0.16, d + 0.12), Vector3(0, altura + 0.16, 0), mat_sec)
			_crear_caja(techo_root, Vector3(w - 0.2, 0.10, d - 0.2), Vector3(0, altura + 0.82, 0), mat_est)

		TipoTecho.DOS_AGUAS:
			_crear_caja(techo_root, Vector3(w - 0.2, 0.14, d - 0.2), Vector3(0, altura, 0), _mat_techo_cielo)
			_crear_caja(techo_root, Vector3(w + 0.16, 0.26, d + 0.16), Vector3(0, altura + 0.18, 0), mat_sec)
			var cumbrera := 1.75
			var hw := w * 0.5 + 0.15
			var hd := d * 0.5 + 0.15
			var y0 := altura + 0.30
			var y1 := y0 + cumbrera
			var ref_in := Vector3(0.0, y0 + 0.2, 0.0)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var f_l := Vector3(-hw, y0, hd); var f_r := Vector3(hw, y0, hd); var f_t := Vector3(0, y1, hd)
			var b_l := Vector3(-hw, y0, -hd); var b_r := Vector3(hw, y0, -hd); var b_t := Vector3(0, y1, -hd)
			# Faldones izquierdo y derecho
			_agregar_tri_orientado(st, f_l, f_t, b_t, ref_in)
			_agregar_tri_orientado(st, f_l, b_t, b_l, ref_in)
			_agregar_tri_orientado(st, f_t, f_r, b_r, ref_in)
			_agregar_tri_orientado(st, f_t, b_r, b_t, ref_in)
			# Tímpanos frontal y trasero
			_agregar_tri_orientado(st, f_l, f_r, f_t, ref_in)
			_agregar_tri_orientado(st, b_r, b_l, b_t, ref_in)
			st.generate_normals()
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat_pri
			techo_root.add_child(mi)
			# Cumbrera superior metálica
			_crear_caja(techo_root, Vector3(0.32, 0.18, d + 0.38), Vector3(0, y1 + 0.04, 0), mat_est)

		TipoTecho.CURVO_ARCO:
			_crear_caja(techo_root, Vector3(w - 0.2, 0.12, d - 0.2), Vector3(0, altura, 0), _mat_techo_cielo)
			_crear_caja(techo_root, Vector3(w + 0.12, 0.24, d + 0.12), Vector3(0, altura + 0.14, 0), mat_sec)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var segs := 14
			var hw := w * 0.5 + 0.06
			var hd := d * 0.5 + 0.06
			var h_arco := 1.85
			var espesor := 0.22
			var ref_in := Vector3(0.0, altura + 0.25, 0.0)
			for i in range(segs):
				var t0 := float(i) / float(segs)
				var t1 := float(i + 1) / float(segs)
				var x0 := lerpf(-hw, hw, t0)
				var x1 := lerpf(-hw, hw, t1)
				var y0_in := altura + 0.22 + sin(t0 * PI) * h_arco
				var y1_in := altura + 0.22 + sin(t1 * PI) * h_arco
				var y0_out := y0_in + espesor
				var y1_out := y1_in + espesor
				# Cara superior del arco
				_agregar_tri_orientado(st, Vector3(x0, y0_out, hd), Vector3(x1, y1_out, hd), Vector3(x1, y1_out, -hd), ref_in)
				_agregar_tri_orientado(st, Vector3(x0, y0_out, hd), Vector3(x1, y1_out, -hd), Vector3(x0, y0_out, -hd), ref_in)
				# Tapas frontal y trasera del arco
				_agregar_tri_orientado(st, Vector3(x0, y0_in, hd), Vector3(x1, y1_in, hd), Vector3(x1, y1_out, hd), ref_in)
				_agregar_tri_orientado(st, Vector3(x0, y0_in, hd), Vector3(x1, y1_out, hd), Vector3(x0, y0_out, hd), ref_in)
				_agregar_tri_orientado(st, Vector3(x1, y1_in, -hd), Vector3(x0, y0_in, -hd), Vector3(x0, y0_out, -hd), ref_in)
				_agregar_tri_orientado(st, Vector3(x1, y1_in, -hd), Vector3(x0, y0_out, -hd), Vector3(x1, y1_out, -hd), ref_in)
				# Relleno inferior desde la base del arco
				_agregar_tri_orientado(st, Vector3(x0, altura + 0.22, hd), Vector3(x1, altura + 0.22, hd), Vector3(x1, y1_in, hd), ref_in)
				_agregar_tri_orientado(st, Vector3(x0, altura + 0.22, hd), Vector3(x1, y1_in, hd), Vector3(x0, y0_in, hd), ref_in)
				_agregar_tri_orientado(st, Vector3(x1, altura + 0.22, -hd), Vector3(x0, altura + 0.22, -hd), Vector3(x0, y0_in, -hd), ref_in)
				_agregar_tri_orientado(st, Vector3(x1, altura + 0.22, -hd), Vector3(x0, y0_in, -hd), Vector3(x1, y1_in, -hd), ref_in)
			st.generate_normals()
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat_pri
			techo_root.add_child(mi)

		TipoTecho.VOLADIZO_T:
			# Espina estructural central + dos alas en V alineadas geométricamente
			_crear_caja(techo_root, Vector3(w + 0.10, 0.42, 1.35), Vector3(0, altura + 0.21, 0), mat_est)
			var ang_deg := 8.5
			var ang_rad := deg_to_rad(ang_deg)
			var ala_len := d * 0.50
			for lado: float in [-1.0, 1.0]:
				var ala_pivot := Node3D.new()
				ala_pivot.position = Vector3(0.0, altura + 0.24, lado * 0.35)
				ala_pivot.rotation.x = lado * (-ang_rad)
				techo_root.add_child(ala_pivot)

				_crear_caja(ala_pivot, Vector3(w, 0.24, ala_len), Vector3(0.0, 0.0, lado * (ala_len * 0.5)), mat_pri)
				_crear_caja(ala_pivot, Vector3(w - 0.2, 0.06, ala_len - 0.15), Vector3(0.0, -0.13, lado * (ala_len * 0.5)), _mat_techo_cielo)
				_crear_caja(ala_pivot, Vector3(w + 0.12, 0.30, 0.16), Vector3(0.0, 0.0, lado * ala_len), mat_sec)

	# Paneles LED distribuidos bajo el techo
	var lx_step := maxf(4.5, w / 3.0)
	var x_pos := -w * 0.32
	while x_pos <= w * 0.33:
		_crear_caja(techo_root, Vector3(1.5, 0.06, 0.75), Vector3(x_pos, altura - 0.04, 0.0), _mat_luz_techo)
		x_pos += lx_step

func _crear_extintor(padre: Node3D, pos: Vector3) -> void:
	var ext := Node3D.new()
	ext.position = pos
	padre.add_child(ext)

	var mat_rojo := StandardMaterial3D.new()
	mat_rojo.albedo_color = Color(0.82, 0.08, 0.08)
	mat_rojo.metallic = 0.42
	mat_rojo.roughness = 0.28

	var mat_negro := StandardMaterial3D.new()
	mat_negro.albedo_color = Color(0.08, 0.08, 0.09)
	mat_negro.roughness = 0.65

	var mat_cromo := StandardMaterial3D.new()
	mat_cromo.albedo_color = Color(0.84, 0.86, 0.88)
	mat_cromo.metallic = 0.90
	mat_cromo.roughness = 0.18

	# Base metálica de soporte
	_crear_caja(ext, Vector3(0.32, 0.06, 0.32), Vector3(0, 0.03, 0), mat_negro)
	# Cilindro presurizado rojo
	_crear_cilindro(ext, 0.11, 0.62, Vector3(0, 0.37, 0), mat_rojo)
	# Válvula y manija cromada
	_crear_cilindro(ext, 0.035, 0.12, Vector3(0, 0.74, 0), mat_cromo)
	_crear_caja(ext, Vector3(0.14, 0.03, 0.04), Vector3(0.04, 0.79, 0), mat_negro)
	# Manguera lateral con boquilla
	_crear_caja(ext, Vector3(0.03, 0.38, 0.03), Vector3(-0.12, 0.48, 0.03), mat_negro)

func _crear_letrero_precios(padre: Node3D, pos: Vector3, rot_y: float, tipo_letrero: int, mat_pri: StandardMaterial3D, mat_sec: StandardMaterial3D, mat_est: StandardMaterial3D, col_pri: Color, col_sec: Color) -> Node3D:
	var totem := Node3D.new()
	totem.name = "LetreroPrecios"
	totem.position = pos
	totem.rotation.y = rot_y
	padre.add_child(totem)

	var y_tablero := 2.75
	var z_tablero := 0.29
	var size_tablero := Vector2(2.05, 3.25)

	match tipo_letrero:
		TipoLetrero.MONOLITO_CLASICO:
			_crear_caja_static(totem, Vector3(2.6, 0.45, 0.85), Vector3(0, 0.225, 0), mat_est)
			_crear_caja_static(totem, Vector3(2.35, 5.4, 0.55), Vector3(0, 2.9, 0), mat_est)
			_crear_caja(totem, Vector3(2.48, 1.05, 0.62), Vector3(0, 5.15, 0), mat_pri)
			_crear_caja(totem, Vector3(2.54, 0.18, 0.66), Vector3(0, 4.58, 0), mat_sec)
			y_tablero = 2.75
			z_tablero = 0.29
			size_tablero = Vector2(2.05, 3.25)

		TipoLetrero.TORRE_MODERNA:
			# Torre estilizada asimétrica con aleta lateral y corona luminosa
			_crear_caja_static(totem, Vector3(2.2, 0.35, 0.75), Vector3(0, 0.175, 0), mat_est)
			_crear_caja_static(totem, Vector3(1.85, 6.2, 0.46), Vector3(-0.15, 3.25, 0), mat_est)
			_crear_caja(totem, Vector3(0.42, 6.5, 0.58), Vector3(0.95, 3.4, 0), mat_pri)
			_crear_caja(totem, Vector3(0.14, 6.55, 0.62), Vector3(0.72, 3.4, 0), mat_sec)
			_crear_caja(totem, Vector3(2.35, 0.95, 0.54), Vector3(0, 5.95, 0), mat_pri)
			y_tablero = 3.25
			z_tablero = 0.25
			size_tablero = Vector2(1.65, 3.35)

		TipoLetrero.DOBLE_POSTE:
			# Estructura industrial elevada sobre dos columnas metálicas
			_crear_caja_static(totem, Vector3(0.32, 6.0, 0.32), Vector3(-1.05, 3.0, 0), mat_est)
			_crear_caja_static(totem, Vector3(0.32, 6.0, 0.32), Vector3(1.05, 3.0, 0), mat_est)
			_crear_caja(totem, Vector3(2.55, 0.30, 0.50), Vector3(0, 2.05, 0), mat_sec)
			_crear_caja_static(totem, Vector3(2.55, 3.55, 0.48), Vector3(0, 3.95, 0), mat_est)
			_crear_caja(totem, Vector3(2.65, 0.95, 0.56), Vector3(0, 6.15, 0), mat_pri)
			_crear_caja(totem, Vector3(2.70, 0.16, 0.60), Vector3(0, 5.65, 0), mat_sec)
			y_tablero = 3.95
			z_tablero = 0.26
			size_tablero = Vector2(2.15, 3.15)

		TipoLetrero.TOTEM_CURVO:
			# Tótem aerodinámico con remate superior curvo/cilíndrico
			_crear_caja_static(totem, Vector3(2.4, 0.38, 0.80), Vector3(0, 0.19, 0), mat_est)
			_crear_caja_static(totem, Vector3(2.15, 4.9, 0.50), Vector3(0, 2.65, 0), mat_est)
			var corona := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.12; cm.bottom_radius = 1.12; cm.height = 0.54
			corona.mesh = cm
			corona.material_override = mat_pri
			corona.position = Vector3(0, 5.10, 0)
			corona.rotation.x = deg_to_rad(90.0)
			totem.add_child(corona)
			_crear_caja(totem, Vector3(2.26, 0.16, 0.56), Vector3(0, 4.65, 0), mat_sec)
			y_tablero = 2.75
			z_tablero = 0.27
			size_tablero = Vector2(1.95, 3.10)

	# SubViewport 2D para el tablero LED de precios (resolución optimizada para móvil)
	var sv := SubViewport.new()
	sv.size = Vector2i(320, 480)
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	totem.add_child(sv)

	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.05, 0.06, 0.07, 1.0)
	sb_bg.border_width_left = 8; sb_bg.border_width_top = 8
	sb_bg.border_width_right = 8; sb_bg.border_width_bottom = 8
	sb_bg.border_color = col_sec
	sb_bg.content_margin_left = 22; sb_bg.content_margin_right = 22
	sb_bg.content_margin_top = 22; sb_bg.content_margin_bottom = 22
	bg.add_theme_stylebox_override("panel", sb_bg)
	sv.add_child(bg)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	bg.add_child(vb)

	var hdr := PanelContainer.new()
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = col_pri
	sb_h.set_corner_radius_all(10)
	sb_h.content_margin_top = 14; sb_h.content_margin_bottom = 14
	hdr.add_theme_stylebox_override("panel", sb_h)
	vb.add_child(hdr)

	var l_hdr := Label.new()
	l_hdr.text = "PRECIOS POR GALÓN"
	l_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_hdr.add_theme_font_size_override("font_size", 21)
	l_hdr.add_theme_color_override("font_color", Color.WHITE)
	hdr.add_child(l_hdr)

	for comb in [
		{"nom": "CORRIENTE", "precio": "$ 11.200", "col": Color(0.28, 0.92, 0.45)},
		{"nom": "EXTRA 91",  "precio": "$ 14.850", "col": Color(0.32, 0.72, 1.00)},
		{"nom": "DIÉSEL",    "precio": "$  9.650", "col": Color(0.98, 0.78, 0.22)}
	]:
		var row := PanelContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sb_r := StyleBoxFlat.new()
		sb_r.bg_color = Color(0.09, 0.11, 0.13, 1.0)
		sb_r.border_width_left = 4
		sb_r.border_color = comb["col"]
		sb_r.set_corner_radius_all(6)
		sb_r.content_margin_left = 10; sb_r.content_margin_right = 10
		sb_r.content_margin_top = 8; sb_r.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", sb_r)
		vb.add_child(row)

		var hb := HBoxContainer.new()
		row.add_child(hb)

		var ln := Label.new()
		ln.text = str(comb["nom"])
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ln.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ln.add_theme_font_size_override("font_size", 19)
		ln.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
		hb.add_child(ln)

		var lp := Label.new()
		lp.text = str(comb["precio"])
		lp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lp.add_theme_font_size_override("font_size", 28)
		lp.add_theme_color_override("font_color", comb["col"])
		hb.add_child(lp)

	var mat_tablero := StandardMaterial3D.new()
	mat_tablero.albedo_texture = sv.get_texture()
	mat_tablero.emission_enabled = true
	mat_tablero.emission_texture = sv.get_texture()
	mat_tablero.emission_energy_multiplier = 1.1
	mat_tablero.roughness = 0.15

	for lado in [{"z": z_tablero, "ry": 0.0}, {"z": -z_tablero, "ry": PI}]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = size_tablero
		q.mesh = qm
		q.material_override = mat_tablero
		q.position = Vector3(0.0, y_tablero, float(lado["z"]))
		q.rotation.y = float(lado["ry"])
		totem.add_child(q)
	return totem

func _crear_textura_copete(col_pri: Color, col_sec: Color) -> ImageTexture:
	var w := 128; var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c := col_pri.darkened(0.15)
			if y < 3 or y >= h - 3 or x < 3 or x >= w - 3:
				c = col_sec
			elif y > 11 and y < 21 and x > 12 and x < w - 12:
				c = Color(0.95, 0.96, 0.98) if ((x / 9) % 2 == 0 or x < 90) else col_sec
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _crear_textura_grados() -> ImageTexture:
	var w := 256; var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cols := [Color(0.16, 0.72, 0.34), Color(0.18, 0.54, 0.88), Color(0.90, 0.68, 0.14)]
	for y in range(h):
		for x in range(w):
			var seg := clampi(x * 3 / w, 0, 2)
			var lx := x - seg * (w / 3)
			var c := Color(0.10, 0.11, 0.13)
			if lx > 6 and lx < (w / 3) - 6 and y > 6 and y < h - 6:
				c = cols[seg]
				if y > 18 and y < 30 and lx > 14 and lx < (w / 3) - 14:
					c = Color(0.95, 0.96, 0.98)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _crear_caja(padre: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	padre.add_child(mi)
	return mi

func _crear_caja_static(padre: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	_crear_caja(padre, size, pos, mat)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.position = pos
	sb.add_child(cs)
	padre.add_child(sb)

func _crear_cilindro(padre: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius; cm.bottom_radius = radius; cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	padre.add_child(mi)

func _agregar_segmento_caja(st: SurfaceTool, a: Vector3, b: Vector3, ancho: float, alto: float) -> void:
	var dir := b - a
	var len_seg := dir.length()
	if len_seg < 0.05:
		return
	var fwd := dir / len_seg
	var right := fwd.cross(Vector3.UP).normalized() * (ancho * 0.5)
	if right.length_squared() < 0.001:
		right = Vector3(ancho * 0.5, 0.0, 0.0)
	var half_h := Vector3(0.0, alto * 0.5, 0.0)
	var a_l := a - right; var a_r := a + right
	var b_l := b - right; var b_r := b + right
	for quad in [
		[a_l + half_h, a_r + half_h, b_r + half_h, b_l + half_h],
		[a_l - half_h, a_l + half_h, b_l + half_h, b_l - half_h],
		[a_r + half_h, a_r - half_h, b_r - half_h, b_r + half_h],
		[a_l - half_h, a_r - half_h, a_r + half_h, a_l + half_h],
		[b_r - half_h, b_l - half_h, b_l + half_h, b_r + half_h],
	]:
		st.add_vertex(quad[0]); st.add_vertex(quad[1]); st.add_vertex(quad[2])
		st.add_vertex(quad[0]); st.add_vertex(quad[2]); st.add_vertex(quad[3])

func _actualizar_colores_manejadores() -> void:
	for i in range(_gasolineras.size()):
		var mans: Array = _gasolineras[i].get("manejadores", [])
		for j in range(mans.size()):
			var m := mans[j] as MeshInstance3D
			if is_instance_valid(m):
				m.material_override = _mat_punto_sel if (i == indice_seleccionado and j == punto_seleccionado) else _mat_punto_idle
		var ml := _gasolineras[i].get("manejador_letrero") as MeshInstance3D
		if is_instance_valid(ml):
			ml.material_override = _mat_punto_sel if (i == indice_seleccionado and (punto_seleccionado in [-2, -3])) else _mat_punto_letrero
		var gz := _gasolineras[i].get("gizmo_letrero") as Node3D
		if is_instance_valid(gz):
			gz.visible = _manejadores_visibles and not bool(_gasolineras[i].get("finalizado", false)) and (i == indice_seleccionado) and (punto_seleccionado in [-2, -3])

func _emitir_seleccion() -> void:
	if indice_seleccionado >= 0 and indice_seleccionado < _gasolineras.size():
		var g: Dictionary = _gasolineras[indice_seleccionado]
		gasolinera_seleccionada_cambiada.emit(true, {
			"indice": indice_seleccionado,
			"num_puntos": (g["puntos"] as Array).size(),
			"cantidad_bahias": int(g.get("cantidad_bahias", 2)),
			"cantidad_surtidores": int(g.get("cantidad_surtidores", 4)),
			"tipo_techo": int(g.get("tipo_techo", 0)),
			"altura_techo": float(g.get("altura_techo", 5.2)),
			"tipo_letrero": int(g.get("tipo_letrero", 0)),
			"color_primario": g.get("color_primario", Color(0.86, 0.14, 0.14)),
			"color_secundario": g.get("color_secundario", Color(0.95, 0.72, 0.12)),
			"color_estructura": g.get("color_estructura", Color(0.88, 0.90, 0.92)),
			"lado_conexion": int(g.get("lado_conexion", 0)),
			"conectada_via": not (g.get("conexion_via", {}) as Dictionary).is_empty(),
			"adaptar_terreno": bool(g.get("adaptar_terreno", true)),
			"finalizado": bool(g.get("finalizado", false))
		})
	else:
		gasolinera_seleccionada_cambiada.emit(false, {})

func _altura_terreno(x: float, z: float, fallback: float) -> float:
	if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
		var h := float(controlador_terreno.obtener_altura(Vector3(x, 0.0, z)))
		if not is_nan(h):
			return h
	if controlador_terreno and controlador_terreno.has_method("obtener_altura_mundo"):
		var h2 := float(controlador_terreno.obtener_altura_mundo(x, z))
		if not is_nan(h2):
			return h2
	return fallback

func _pts_a_poly2d(pts: Array) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2((p as Vector3).x, (p as Vector3).z))
	return poly

func _centro_puntos(pts: Array) -> Vector3:
	if pts.is_empty():
		return Vector3.ZERO
	var s := Vector3.ZERO
	for p in pts:
		s += p as Vector3
	return s / float(pts.size())

func serializar_gasolineras() -> Array:
	var salida: Array = []
	for g in _gasolineras:
		var pts_arr: Array = []
		for p in g["puntos"]:
			pts_arr.append([p.x, p.y, p.z])
		var cp: Color = g.get("color_primario", Color(0.86, 0.14, 0.14))
		var cs: Color = g.get("color_secundario", Color(0.95, 0.72, 0.12))
		var ce: Color = g.get("color_estructura", Color(0.88, 0.90, 0.92))
		var pl: Vector3 = g.get("pos_letrero", Vector3.ZERO)
		salida.append({
			"puntos": pts_arr,
			"rotacion": float(g.get("rotacion", 0.0)),
			"altura_losa": float(g.get("altura_losa", 0.16)),
			"adaptar_terreno": bool(g.get("adaptar_terreno", true)),
			"cantidad_bahias": int(g.get("cantidad_bahias", 2)),
			"cantidad_surtidores": int(g.get("cantidad_surtidores", 4)),
			"tipo_techo": int(g.get("tipo_techo", 0)),
			"altura_techo": float(g.get("altura_techo", 5.2)),
			"tipo_letrero": int(g.get("tipo_letrero", 0)),
			"pos_letrero": [pl.x, pl.y, pl.z],
			"rotacion_letrero": float(g.get("rotacion_letrero", 0.0)),
			"color_primario": [cp.r, cp.g, cp.b, cp.a],
			"color_secundario": [cs.r, cs.g, cs.b, cs.a],
			"color_estructura": [ce.r, ce.g, ce.b, ce.a],
			"lado_conexion": int(g.get("lado_conexion", 0)),
			"conexion_via": g.get("conexion_via", {}),
			"finalizado": bool(g.get("finalizado", false))
		})
	return salida

func deserializar_gasolineras(lista: Array) -> void:
	_asegurar_inicializado()
	limpiar_todos()
	for d in lista:
		if not (d is Dictionary):
			continue
		var pts: Array[Vector3] = []
		for pa in d.get("puntos", []):
			if pa is Array and pa.size() >= 3:
				pts.append(Vector3(float(pa[0]), float(pa[1]), float(pa[2])))
		if pts.size() < 3:
			continue
		var cp_a: Array = d.get("color_primario", [0.86, 0.14, 0.14, 1.0])
		var cs_a: Array = d.get("color_secundario", [0.95, 0.72, 0.12, 1.0])
		var ce_a: Array = d.get("color_estructura", [0.88, 0.90, 0.92, 1.0])
		var nodo := Node3D.new()
		nodo.name = "Gasolinera_%d" % (_gasolineras.size() + 1)
		_contenedor.add_child(nodo)
		var dict_g := {
			"puntos": pts,
			"rotacion": float(d.get("rotacion", 0.0)),
			"altura_losa": float(d.get("altura_losa", 0.16)),
			"adaptar_terreno": bool(d.get("adaptar_terreno", true)),
			"cantidad_bahias": int(d.get("cantidad_bahias", 2)),
			"cantidad_surtidores": int(d.get("cantidad_surtidores", 4)),
			"tipo_techo": int(d.get("tipo_techo", 0)),
			"altura_techo": float(d.get("altura_techo", 5.2)),
			"tipo_letrero": int(d.get("tipo_letrero", 0)),
			"rotacion_letrero": float(d.get("rotacion_letrero", float(d.get("rotacion", 0.0)))),
			"color_primario": Color(float(cp_a[0]), float(cp_a[1]), float(cp_a[2]), float(cp_a[3]) if cp_a.size() > 3 else 1.0),
			"color_secundario": Color(float(cs_a[0]), float(cs_a[1]), float(cs_a[2]), float(cs_a[3]) if cs_a.size() > 3 else 1.0),
			"color_estructura": Color(float(ce_a[0]), float(ce_a[1]), float(ce_a[2]), float(ce_a[3]) if ce_a.size() > 3 else 1.0),
			"lado_conexion": int(d.get("lado_conexion", 0)),
			"conexion_via": d.get("conexion_via", {}),
			"finalizado": bool(d.get("finalizado", false)),
			"nodo": nodo,
			"manejadores": [],
			"manejador_letrero": null
		}
		if d.has("pos_letrero") and d["pos_letrero"] is Array and (d["pos_letrero"] as Array).size() >= 3:
			var pla: Array = d["pos_letrero"]
			dict_g["pos_letrero"] = Vector3(float(pla[0]), float(pla[1]), float(pla[2]))
		_gasolineras.append(dict_g)
		_reconstruir_gasolinera(_gasolineras.size() - 1)
	gasolinera_actualizada.emit(_gasolineras.size())
