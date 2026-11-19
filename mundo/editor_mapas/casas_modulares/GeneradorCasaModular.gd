class_name GeneradorCasaModular
extends RefCounted

## GeneradorCasaModular.gd — Constructor procedural 3D de casas modulares con Atlas PBR.
## Genera una malla optimizada (ArrayMesh con 4 superficies) + colisiones físicas.

const SHADER_PATH := "res://shaders/casa_modular.gdshader"
const TEX_DIR := "res://recursos/texturas_casas/"
const GLB_DIR := "res://modelos3d/mapa/modulares/"

static var _mat_fachada: ShaderMaterial = null
static var _mat_ventanas_base: ShaderMaterial = null
static var _mat_puertas: ShaderMaterial = null
static var _mat_techos: ShaderMaterial = null
static var _glb_cache: Dictionary = {}

static func _asegurar_materiales() -> void:
	if _mat_fachada != null:
		return
	var shader: Shader = load(SHADER_PATH)
	if not shader:
		push_error("GeneradorCasaModular: No se encontró shader en " + SHADER_PATH)
		return

	_mat_fachada = _crear_mat(shader, "atlas_fachadas", false)
	_mat_ventanas_base = _crear_mat(shader, "atlas_ventanas", true)
	_mat_puertas = _crear_mat(shader, "atlas_puertas", false)
	_mat_techos = _crear_mat(shader, "atlas_techos", false)

static func _crear_mat(shader: Shader, prefijo: String, con_emision: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("atlas_albedo", load(TEX_DIR + prefijo + "_albedo.png"))
	mat.set_shader_parameter("atlas_normal", load(TEX_DIR + prefijo + "_normal.png"))
	mat.set_shader_parameter("atlas_roughness", load(TEX_DIR + prefijo + "_roughness.png"))
	if con_emision:
		mat.set_shader_parameter("atlas_emission", load(TEX_DIR + prefijo + "_emission.png"))
		mat.set_shader_parameter("usar_emision", true)
		mat.set_shader_parameter("intensidad_emision", 1.1)
	return mat

static func crear_casa(config_raw: Dictionary) -> Node3D:
	_asegurar_materiales()
	var cfg := DatosCasaModular.normalizar_config(config_raw)

	var root := Node3D.new()
	root.name = "CasaModular"
	root.set_meta("id_modelo", "casa_modular")
	root.set_meta("es_casa_modular", true)
	root.set_meta("config_casa", cfg.duplicate(true))

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MallaCasa"
	root.add_child(mesh_inst)

	var body := StaticBody3D.new()
	body.name = "ColisionCasa"
	root.add_child(body)

	reconstruir_casa(root, cfg)
	return root

static func reconstruir_casa(root: Node3D, config_raw: Dictionary) -> void:
	_asegurar_materiales()
	var cfg := DatosCasaModular.normalizar_config(config_raw)
	root.set_meta("config_casa", cfg.duplicate(true))

	var mesh_inst := root.get_node_or_null("MallaCasa") as MeshInstance3D
	if not mesh_inst:
		mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "MallaCasa"
		root.add_child(mesh_inst)

	var st_fachada := SurfaceTool.new()
	var st_ventanas := SurfaceTool.new()
	var st_puertas := SurfaceTool.new()
	var st_techos := SurfaceTool.new()
	for st in [st_fachada, st_ventanas, st_puertas, st_techos]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ancho: float = float(cfg["ancho"])
	var fondo: float = float(cfg["fondo"])
	var pisos: int = int(cfg["pisos"])
	var h_piso: float = float(cfg["altura_piso"])
	var h_zoc: float = float(cfg["altura_zocalo"])
	var forma: String = str(cfg.get("forma", "rectangular"))
	var esc_tex: float = float(cfg.get("escala_textura", 0.35))

	var col_fach := DatosCasaModular.parsear_color(cfg["color_fachada"], Color.WHITE)
	var col_p1 := DatosCasaModular.parsear_color(cfg["color_piso1"], col_fach)
	var col_zoc := DatosCasaModular.parsear_color(cfg["color_zocalo"], Color(0.5, 0.5, 0.5))
	var col_mold := DatosCasaModular.parsear_color(cfg["color_molduras"], Color(0.9, 0.9, 0.88))
	var col_puerta := DatosCasaModular.parsear_color(cfg["color_puerta"], Color(0.45, 0.28, 0.16))
	var col_garaje := DatosCasaModular.parsear_color(cfg["color_garaje"], Color(0.35, 0.38, 0.42))
	var col_vent := DatosCasaModular.parsear_color(cfg["color_ventanas"], Color.WHITE)
	var col_techo := DatosCasaModular.parsear_color(cfg["color_techo"], Color.WHITE)

	var mat_fach: int = int(cfg["mat_fachada"])
	var mat_p1: int = int(cfg["mat_piso1"]) if bool(cfg["usar_mat_piso1"]) else mat_fach
	var col_p1_final: Color = col_p1 if bool(cfg["usar_mat_piso1"]) else col_fach
	var mat_zoc: int = int(cfg["mat_zocalo"])
	var mat_techo: int = int(cfg["mat_techo"])

	# 1. ZÓCALO / BASE
	var y_actual: float = 0.0
	if h_zoc > 0.05:
		_add_box_tiled(st_fachada, Vector3(0, h_zoc * 0.5, 0), Vector3(ancho + 0.08, h_zoc, fondo + 0.08), mat_zoc, col_zoc, esc_tex)
		y_actual = h_zoc

	# 2. VOLÚMENES POR PISO + MOLDURAS + PILASTRAS + VENTANAS + PUERTAS + BALCONES
	var top_w: float = ancho
	var top_d: float = fondo
	var top_z_off: float = 0.0

	for p in range(pisos):
		var w_piso: float = ancho
		var d_piso: float = fondo
		var z_off: float = 0.0

		if forma == "voladizo" and p >= 1:
			d_piso = fondo + 0.85
			z_off = 0.425
		elif forma == "escalonada" and p >= 1:
			var reduccion: float = minf(fondo * 0.35, 1.3 * float(p))
			d_piso = maxf(3.5, fondo - reduccion)
			z_off = -reduccion * 0.5

		if p == pisos - 1:
			top_w = w_piso
			top_d = d_piso
			top_z_off = z_off

		var mat_cur: int = mat_p1 if p == 0 else mat_fach
		var col_cur: Color = col_p1_final if p == 0 else col_fach
		var centro_piso := Vector3(0.0, y_actual + h_piso * 0.5, z_off)

		# Caja principal del piso
		_add_box_tiled(st_fachada, centro_piso, Vector3(w_piso, h_piso, d_piso), mat_cur, col_cur, esc_tex)

		# Losa / Cornisa divisoria entre pisos
		if p > 0:
			_add_box_solid(st_fachada, Vector3(0.0, y_actual, z_off), Vector3(w_piso + 0.14, 0.14, d_piso + 0.14), col_mold)

		# Pilastras en esquinas
		if bool(cfg.get("tiene_pilastras", false)):
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var px: float = sx * (w_piso * 0.5 - 0.08)
					var pz: float = z_off + sz * (d_piso * 0.5 - 0.08)
					_add_box_solid(st_fachada, Vector3(px, y_actual + h_piso * 0.5, pz), Vector3(0.24, h_piso, 0.24), col_mold)

		# Aberturas del piso (Puerta / Garaje en Piso 0 + Ventanas en todos los pisos)
		var tiene_garaje: bool = (p == 0) and bool(cfg.get("tiene_garaje", false)) and (w_piso >= 6.5)
		var puerta_x: float = 0.0
		var puerta_w: float = 1.65 if bool(cfg.get("puerta_doble", false)) else 1.15
		var puerta_h: float = minf(2.35, h_piso - 0.35)
		var garaje_x: float = 0.0
		var garaje_w: float = minf(3.2, w_piso * 0.38)
		var garaje_h: float = minf(2.45, h_piso - 0.3)

		if p == 0:
			var pos_p: String = str(cfg.get("pos_puerta", "centro"))
			if tiene_garaje:
				if pos_p == "derecha":
					puerta_x = w_piso * 0.28
					garaje_x = -w_piso * 0.22
				else:
					puerta_x = -w_piso * 0.28
					garaje_x = w_piso * 0.20
			else:
				if pos_p == "izquierda":
					puerta_x = -w_piso * 0.28
				elif pos_p == "derecha":
					puerta_x = w_piso * 0.28
				else:
					puerta_x = 0.0

			# Puerta principal (+Z)
			var z_frente: float = z_off + d_piso * 0.5
			_colocar_abertura_puerta(st_fachada, st_puertas, Vector3(puerta_x, y_actual, z_frente), puerta_w, puerta_h, int(cfg["tipo_puerta"]), col_puerta, col_mold)

			# Escaleras de entrada si hay zócalo
			if bool(cfg.get("tiene_escaleras", false)) and h_zoc > 0.12:
				_construir_escaleras(st_techos, Vector3(puerta_x, 0.0, z_frente), puerta_w + 0.5, h_zoc, col_mold)

			# Toldo comercial
			if bool(cfg.get("tiene_toldo", false)):
				var col_toldo := DatosCasaModular.parsear_color(cfg.get("color_toldo", "#c94038"), Color.RED)
				_construir_toldo(st_fachada, Vector3(0.0, y_actual + puerta_h + 0.25, z_frente), w_piso * 0.72, 1.15, col_toldo, col_mold)

			# Garaje / Cortina comercial (+Z)
			if tiene_garaje:
				_colocar_abertura_puerta(st_fachada, st_puertas, Vector3(garaje_x, y_actual, z_frente), garaje_w, garaje_h, int(cfg["tipo_garaje"]), col_garaje, col_mold)

		# Ventanas en Frente (+Z)
		var n_vf: int = int(cfg.get("ventanas_frente", 2))
		var tipo_v: int = int(cfg["tipo_ventana_p1"]) if p == 0 else int(cfg["tipo_ventana_sup"])
		var esc_v: float = float(cfg.get("escala_ventana", 1.0))
		var vw: float = 1.25 * esc_v
		var vh: float = clampf(1.35 * esc_v, 0.8, h_piso - 0.65)
		var vy_centro: float = y_actual + h_piso * 0.52
		if tipo_v == 3: # Ventanal piso-techo
			vh = h_piso - 0.45
			vy_centro = y_actual + vh * 0.5 + 0.15

		var z_frente_v: float = z_off + d_piso * 0.5
		if n_vf > 0:
			var paso_x: float = w_piso / float(n_vf + 1)
			for i in range(n_vf):
				var vx: float = -w_piso * 0.5 + paso_x * float(i + 1)
				if p == 0:
					if absf(vx - puerta_x) < (puerta_w * 0.5 + vw * 0.55):
						continue
					if tiene_garaje and absf(vx - garaje_x) < (garaje_w * 0.5 + vw * 0.55):
						continue
				_colocar_ventana(st_fachada, st_ventanas, Vector3(vx, vy_centro, z_frente_v), 0.0, vw, vh, tipo_v, col_vent, col_mold, bool(cfg.get("tiene_jardineras", false)))

		# Ventanas Laterales (-X y +X)
		var n_vl: int = int(cfg.get("ventanas_lados", 2))
		if n_vl > 0:
			var paso_z: float = d_piso / float(n_vl + 1)
			for i in range(n_vl):
				var vz: float = z_off - d_piso * 0.5 + paso_z * float(i + 1)
				_colocar_ventana(st_fachada, st_ventanas, Vector3(-w_piso * 0.5, vy_centro, vz), -PI * 0.5, vw, vh, tipo_v, col_vent, col_mold, false)
				_colocar_ventana(st_fachada, st_ventanas, Vector3(w_piso * 0.5, vy_centro, vz), PI * 0.5, vw, vh, tipo_v, col_vent, col_mold, false)

		# Ventanas Atrás (-Z)
		var n_va: int = int(cfg.get("ventanas_atras", 2))
		if n_va > 0:
			var paso_xa: float = w_piso / float(n_va + 1)
			for i in range(n_va):
				var vxa: float = -w_piso * 0.5 + paso_xa * float(i + 1)
				_colocar_ventana(st_fachada, st_ventanas, Vector3(vxa, vy_centro, z_off - d_piso * 0.5), PI, vw, vh, tipo_v, col_vent, col_mold, false)

		# Balcón en pisos superiores (p >= 1)
		if p >= 1 and bool(cfg.get("tiene_balcon", false)):
			var col_bal := DatosCasaModular.parsear_color(cfg.get("color_balcon", "#6b4024"), Color(0.4, 0.25, 0.15))
			_construir_balcon(st_fachada, st_ventanas, Vector3(0.0, y_actual, z_off + d_piso * 0.5), w_piso * 0.84, 1.05, str(cfg.get("tipo_balcon", "madera")), col_bal, col_mold)

		y_actual += h_piso

	# 3. PORCHE FRONTAL EN PISO 0
	if bool(cfg.get("tiene_porche", false)):
		var col_por := DatosCasaModular.parsear_color(cfg.get("color_porche", "#6b4024"), Color(0.45, 0.28, 0.16))
		_construir_porche(st_fachada, st_techos, Vector3(0.0, h_zoc, fondo * 0.5), ancho * 0.92, 1.8, h_piso, mat_techo, col_por, col_techo, esc_tex)

	# 4. TECHO / CUBIERTA
	var tipo_techo: String = str(cfg.get("tipo_techo", "dos_aguas"))
	var alero: float = float(cfg.get("alero", 0.6))
	var pend: float = float(cfg.get("pendiente_techo", 24.0))
	var h_techo: float = 0.35

	if tipo_techo == "plano":
		_construir_techo_plano(st_fachada, st_techos, Vector3(0.0, y_actual, top_z_off), top_w, top_d, alero, mat_techo, col_techo, col_mold, esc_tex, bool(cfg.get("detalles_azotea", false)))
		h_techo = 0.6
	elif tipo_techo == "dos_aguas":
		h_techo = _construir_techo_dos_aguas(st_fachada, st_techos, Vector3(0.0, y_actual, top_z_off), top_w, top_d, alero, pend, mat_fach, col_fach, mat_techo, col_techo, esc_tex)
	elif tipo_techo == "cuatro_aguas":
		h_techo = _construir_techo_cuatro_aguas(st_techos, Vector3(0.0, y_actual, top_z_off), top_w, top_d, alero, pend, mat_techo, col_techo, esc_tex)
	elif tipo_techo == "un_agua":
		h_techo = _construir_techo_un_agua(st_fachada, st_techos, Vector3(0.0, y_actual, top_z_off), top_w, top_d, alero, pend, mat_fach, col_fach, mat_techo, col_techo, esc_tex)
	elif tipo_techo == "mansarda":
		h_techo = _construir_techo_mansarda(st_techos, Vector3(0.0, y_actual, top_z_off), top_w, top_d, alero, pend, mat_techo, col_techo, esc_tex)
	elif tipo_techo == "diente_sierra":
		h_techo = _construir_techo_diente_sierra(st_fachada, st_ventanas, st_techos, Vector3(0.0, y_actual, top_z_off), top_w, top_d, pend, mat_fach, col_fach, mat_techo, col_techo, esc_tex)
	elif tipo_techo == "boveda":
		h_techo = _construir_techo_boveda(st_fachada, st_techos, Vector3(0.0, y_actual, top_z_off), top_w, top_d, alero, mat_fach, col_fach, mat_techo, col_techo, esc_tex)

	# Chimenea residencial opcional
	if bool(cfg.get("tiene_chimenea", false)):
		_add_box_tiled(st_fachada, Vector3(top_w * 0.28, y_actual + h_techo * 0.55 + 0.5, top_z_off - top_d * 0.15), Vector3(0.65, h_techo + 1.1, 0.65), 2, Color.WHITE, esc_tex)
		_add_box_solid(st_fachada, Vector3(top_w * 0.28, y_actual + h_techo + 1.12, top_z_off - top_d * 0.15), Vector3(0.78, 0.12, 0.78), col_mold)

	# Tótem / Letrero comercial
	if bool(cfg.get("tiene_totem", false)):
		var col_tot := DatosCasaModular.parsear_color(cfg.get("color_totem", "#4b6478"), Color(0.3, 0.4, 0.5))
		var tx: float = -ancho * 0.5 - 1.6
		var tz: float = fondo * 0.5 + 1.8
		_add_box_solid(st_fachada, Vector3(tx, 2.6, tz), Vector3(1.4, 5.2, 0.45), col_mold)
		_add_box_solid(st_fachada, Vector3(tx, 3.8, tz), Vector3(1.55, 2.2, 0.55), col_tot)

	# 5. COMPILAR ARRAYMESH
	var mesh := ArrayMesh.new()
	var mats: Array[Material] = []

	var mat_vent: ShaderMaterial = _mat_ventanas_base.duplicate()
	if bool(cfg.get("luz_nocturna", false)):
		mat_vent.set_shader_parameter("intensidad_emision", float(cfg.get("intensidad_luz", 0.65)))
	else:
		mat_vent.set_shader_parameter("intensidad_emision", 0.0)

	var pares := [
		[st_fachada, _mat_fachada],
		[st_ventanas, mat_vent],
		[st_puertas, _mat_puertas],
		[st_techos, _mat_techos],
	]
	for par in pares:
		var st: SurfaceTool = par[0]
		st.index()
		var arr := st.commit_to_arrays()
		if arr[Mesh.ARRAY_VERTEX].size() > 0:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mats.append(par[1])

	mesh_inst.mesh = mesh
	for i in range(mats.size()):
		mesh_inst.set_surface_override_material(i, mats[i])

	var n_modulos: int = clampi(int(cfg.get("modulos_conjunto", 1)), 1, 5)
	var ancho_total: float = ancho * float(n_modulos)
	if n_modulos > 1:
		mesh_inst.position.x = -ancho * float(n_modulos - 1) * 0.5
	else:
		mesh_inst.position.x = 0.0

	# 6. MÓDULOS DETALLADOS DE BLENDER (.GLB) Y REPETICIÓN DE CONJUNTO
	_poblar_modulos_blender(root, cfg, mesh, mats, y_actual, h_techo, top_w, top_d, top_z_off, n_modulos)

	# 7. ACTUALIZAR COLISIONES FÍSICAS
	_actualizar_colisiones(root, ancho_total, y_actual + h_techo * 0.5, fondo)


static func _actualizar_colisiones(root: Node3D, ancho: float, alto_total: float, fondo: float) -> void:
	var body := root.get_node_or_null("ColisionCasa") as StaticBody3D
	if not body:
		return
	for h in body.get_children():
		h.queue_free()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ancho, alto_total, fondo)
	col.shape = box
	col.position = Vector3(0.0, alto_total * 0.5, 0.0)
	body.add_child(col)


# ============================================================================
# PRIMITIVAS DE CONSTRUCCIÓN (QUADS, CAJAS, ABERTURAS, BALCONES, TECHOS)
# ============================================================================

static func _emit_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2, normal: Vector3, col: Color, uv2_data: Vector2) -> void:
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv2(uv2_data)

	st.set_uv(uv0); st.add_vertex(p0)
	st.set_uv(uv1); st.add_vertex(p1)
	st.set_uv(uv2); st.add_vertex(p2)

	st.set_uv(uv0); st.add_vertex(p0)
	st.set_uv(uv2); st.add_vertex(p2)
	st.set_uv(uv3); st.add_vertex(p3)

static func _emit_tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, normal: Vector3, col: Color, uv2_data: Vector2) -> void:
	st.set_color(col)
	st.set_normal(normal)
	st.set_uv2(uv2_data)
	st.set_uv(uv0); st.add_vertex(p0)
	st.set_uv(uv1); st.add_vertex(p1)
	st.set_uv(uv2); st.add_vertex(p2)

static func _add_box_tiled(st: SurfaceTool, center: Vector3, size: Vector3, tile_idx: int, col: Color, esc: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var uv2 := Vector2(float(tile_idx), 0.0)

	# +Z (Frente)
	_emit_quad(st,
		center + Vector3(-hx, hy, hz), center + Vector3(hx, hy, hz),
		center + Vector3(hx, -hy, hz), center + Vector3(-hx, -hy, hz),
		Vector2(0, 0), Vector2(size.x * esc, 0), Vector2(size.x * esc, size.y * esc), Vector2(0, size.y * esc),
		Vector3(0, 0, 1), col, uv2)
	# -Z (Atrás)
	_emit_quad(st,
		center + Vector3(hx, hy, -hz), center + Vector3(-hx, hy, -hz),
		center + Vector3(-hx, -hy, -hz), center + Vector3(hx, -hy, -hz),
		Vector2(0, 0), Vector2(size.x * esc, 0), Vector2(size.x * esc, size.y * esc), Vector2(0, size.y * esc),
		Vector3(0, 0, -1), col, uv2)
	# +X (Derecha)
	_emit_quad(st,
		center + Vector3(hx, hy, hz), center + Vector3(hx, hy, -hz),
		center + Vector3(hx, -hy, -hz), center + Vector3(hx, -hy, hz),
		Vector2(0, 0), Vector2(size.z * esc, 0), Vector2(size.z * esc, size.y * esc), Vector2(0, size.y * esc),
		Vector3(1, 0, 0), col, uv2)
	# -X (Izquierda)
	_emit_quad(st,
		center + Vector3(-hx, hy, -hz), center + Vector3(-hx, hy, hz),
		center + Vector3(-hx, -hy, hz), center + Vector3(-hx, -hy, -hz),
		Vector2(0, 0), Vector2(size.z * esc, 0), Vector2(size.z * esc, size.y * esc), Vector2(0, size.y * esc),
		Vector3(-1, 0, 0), col, uv2)
	# +Y (Arriba)
	_emit_quad(st,
		center + Vector3(-hx, hy, -hz), center + Vector3(hx, hy, -hz),
		center + Vector3(hx, hy, hz), center + Vector3(-hx, hy, hz),
		Vector2(0, 0), Vector2(size.x * esc, 0), Vector2(size.x * esc, size.z * esc), Vector2(0, size.z * esc),
		Vector3(0, 1, 0), col, uv2)
	# -Y (Abajo)
	_emit_quad(st,
		center + Vector3(-hx, -hy, hz), center + Vector3(hx, -hy, hz),
		center + Vector3(hx, -hy, -hz), center + Vector3(-hx, -hy, -hz),
		Vector2(0, 0), Vector2(size.x * esc, 0), Vector2(size.x * esc, size.z * esc), Vector2(0, size.z * esc),
		Vector3(0, -1, 0), col, uv2)

static func _add_box_solid(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var uv2 := Vector2(0.0, 2.0) # modo 2 = color sólido
	var z := Vector2.ZERO
	_emit_quad(st, center + Vector3(-hx, hy, hz), center + Vector3(hx, hy, hz), center + Vector3(hx, -hy, hz), center + Vector3(-hx, -hy, hz), z, z, z, z, Vector3(0, 0, 1), col, uv2)
	_emit_quad(st, center + Vector3(hx, hy, -hz), center + Vector3(-hx, hy, -hz), center + Vector3(-hx, -hy, -hz), center + Vector3(hx, -hy, -hz), z, z, z, z, Vector3(0, 0, -1), col, uv2)
	_emit_quad(st, center + Vector3(hx, hy, hz), center + Vector3(hx, hy, -hz), center + Vector3(hx, -hy, -hz), center + Vector3(hx, -hy, hz), z, z, z, z, Vector3(1, 0, 0), col, uv2)
	_emit_quad(st, center + Vector3(-hx, hy, -hz), center + Vector3(-hx, hy, hz), center + Vector3(-hx, -hy, hz), center + Vector3(-hx, -hy, -hz), z, z, z, z, Vector3(-1, 0, 0), col, uv2)
	_emit_quad(st, center + Vector3(-hx, hy, -hz), center + Vector3(hx, hy, -hz), center + Vector3(hx, hy, hz), center + Vector3(-hx, hy, hz), z, z, z, z, Vector3(0, 1, 0), col, uv2)
	_emit_quad(st, center + Vector3(-hx, -hy, hz), center + Vector3(hx, -hy, hz), center + Vector3(hx, -hy, -hz), center + Vector3(-hx, -hy, -hz), z, z, z, z, Vector3(0, -1, 0), col, uv2)

static func _colocar_abertura_puerta(st_mold: SurfaceTool, st_puertas: SurfaceTool, base_pos: Vector3, w: float, h: float, tipo: int, col_p: Color, col_m: Color) -> void:
	# Marco 3D alrededor de la puerta
	_add_box_solid(st_mold, base_pos + Vector3(0, h + 0.05, 0.04), Vector3(w + 0.16, 0.10, 0.10), col_m)
	_add_box_solid(st_mold, base_pos + Vector3(-w * 0.5 - 0.04, h * 0.5, 0.04), Vector3(0.08, h, 0.10), col_m)
	_add_box_solid(st_mold, base_pos + Vector3(w * 0.5 + 0.04, h * 0.5, 0.04), Vector3(0.08, h, 0.10), col_m)

	# Quad de puerta (modo 1 = 1:1 en atlas)
	var z := base_pos.z + 0.035
	_emit_quad(st_puertas,
		Vector3(base_pos.x - w * 0.5, base_pos.y + h, z),
		Vector3(base_pos.x + w * 0.5, base_pos.y + h, z),
		Vector3(base_pos.x + w * 0.5, base_pos.y, z),
		Vector3(base_pos.x - w * 0.5, base_pos.y, z),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
		Vector3(0, 0, 1), col_p, Vector2(float(tipo), 1.0))

static func _colocar_ventana(st_mold: SurfaceTool, st_vent: SurfaceTool, centro: Vector3, rot_y: float, w: float, h: float, tipo: int, col_v: Color, col_m: Color, jardinera: bool) -> void:
	var basis := Basis(Vector3.UP, rot_y)
	var fwd := basis * Vector3(0, 0, 1)
	var right := basis * Vector3(1, 0, 0)

	# Antepecho / alféizar 3D
	var sill_pos := centro + Vector3(0, -h * 0.5 - 0.04, 0) + fwd * 0.06
	var sill_size := Vector3(w + 0.18, 0.08, 0.16)
	if absf(rot_y) > 0.4 and absf(rot_y) < 2.5:
		sill_size = Vector3(0.16, 0.08, w + 0.18)
	_add_box_solid(st_mold, sill_pos, sill_size, col_m)

	# Dintel superior
	var lint_pos := centro + Vector3(0, h * 0.5 + 0.04, 0) + fwd * 0.04
	var lint_size := Vector3(w + 0.14, 0.08, 0.10)
	if absf(rot_y) > 0.4 and absf(rot_y) < 2.5:
		lint_size = Vector3(0.10, 0.08, w + 0.14)
	_add_box_solid(st_mold, lint_pos, lint_size, col_m)

	# Jardinera con vegetación opcional
	if jardinera:
		var j_pos := centro + Vector3(0, -h * 0.5 - 0.16, 0) + fwd * 0.15
		var j_size := Vector3(w * 0.85, 0.16, 0.22)
		if absf(rot_y) > 0.4 and absf(rot_y) < 2.5:
			j_size = Vector3(0.22, 0.16, w * 0.85)
		_add_box_solid(st_mold, j_pos, j_size, Color(0.55, 0.28, 0.18))
		var g_pos := j_pos + Vector3(0, 0.11, 0)
		var g_size := Vector3(w * 0.78, 0.10, 0.18)
		if absf(rot_y) > 0.4 and absf(rot_y) < 2.5:
			g_size = Vector3(0.18, 0.10, w * 0.78)
		_add_box_solid(st_mold, g_pos, g_size, Color(0.18, 0.48, 0.20))

	# Quad de ventana (modo 1 = 1:1 en atlas)
	var p_base := centro + fwd * 0.032
	var hw := w * 0.5
	var hh := h * 0.5
	var p0 := p_base - right * hw + Vector3(0, hh, 0)
	var p1 := p_base + right * hw + Vector3(0, hh, 0)
	var p2 := p_base + right * hw - Vector3(0, hh, 0)
	var p3 := p_base - right * hw - Vector3(0, hh, 0)
	_emit_quad(st_vent, p0, p1, p2, p3, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), fwd, col_v, Vector2(float(tipo), 1.0))

static func _construir_escaleras(st_techos: SurfaceTool, base_puerta: Vector3, w: float, h: float, col: Color) -> void:
	var n_pel := clampi(int(ceil(h / 0.18)), 2, 6)
	var dh: float = h / float(n_pel)
	var dd: float = 0.30
	for i in range(n_pel):
		var y_pel: float = (float(n_pel - i) * dh) * 0.5
		var z_pel: float = base_puerta.z + (float(i) + 0.5) * dd
		_add_box_tiled(st_techos, Vector3(base_puerta.x, y_pel, z_pel), Vector3(w, float(n_pel - i) * dh, dd), 12, col, 0.5)

static func _construir_toldo(st_fach: SurfaceTool, base_pos: Vector3, w: float, prof: float, col_toldo: Color, col_m: Color) -> void:
	var hw := w * 0.5
	var p0 := Vector3(base_pos.x - hw, base_pos.y + 0.35, base_pos.z + 0.02)
	var p1 := Vector3(base_pos.x + hw, base_pos.y + 0.35, base_pos.z + 0.02)
	var p2 := Vector3(base_pos.x + hw, base_pos.y - 0.15, base_pos.z + prof)
	var p3 := Vector3(base_pos.x - hw, base_pos.y - 0.15, base_pos.z + prof)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	_emit_quad(st_fach, p0, p1, p2, p3, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, n, col_toldo, Vector2(0, 2.0))
	_add_box_solid(st_fach, Vector3(base_pos.x, base_pos.y - 0.18, base_pos.z + prof), Vector3(w, 0.12, 0.04), col_m)

static func _construir_balcon(st_fach: SurfaceTool, _st_vent: SurfaceTool, base_pos: Vector3, w: float, prof: float, tipo: String, col_bal: Color, col_mold: Color) -> void:
	# Losa del balcón
	_add_box_solid(st_fach, base_pos + Vector3(0, 0.06, prof * 0.5), Vector3(w, 0.14, prof), col_mold)
	var h_bar: float = 0.95
	var y_bar: float = base_pos.y + 0.13
	var z_f: float = base_pos.z + prof - 0.05

	if tipo == "concreto":
		_add_box_solid(st_fach, Vector3(base_pos.x, y_bar + h_bar * 0.45, z_f), Vector3(w, h_bar * 0.9, 0.12), col_bal)
		_add_box_solid(st_fach, Vector3(-w * 0.5 + 0.06, y_bar + h_bar * 0.45, base_pos.z + prof * 0.5), Vector3(0.12, h_bar * 0.9, prof), col_bal)
		_add_box_solid(st_fach, Vector3(w * 0.5 - 0.06, y_bar + h_bar * 0.45, base_pos.z + prof * 0.5), Vector3(0.12, h_bar * 0.9, prof), col_bal)
	else:
		# Pasamanos superior
		_add_box_solid(st_fach, Vector3(base_pos.x, y_bar + h_bar, z_f), Vector3(w, 0.07, 0.08), col_bal)
		_add_box_solid(st_fach, Vector3(-w * 0.5 + 0.04, y_bar + h_bar, base_pos.z + prof * 0.5), Vector3(0.08, 0.07, prof), col_bal)
		_add_box_solid(st_fach, Vector3(w * 0.5 - 0.04, y_bar + h_bar, base_pos.z + prof * 0.5), Vector3(0.08, 0.07, prof), col_bal)
		# Barrotes verticales
		var paso: float = 0.42 if tipo == "madera" else (0.30 if tipo == "hierro" else w * 0.48)
		var x: float = -w * 0.5 + 0.06
		while x <= w * 0.5 - 0.05:
			_add_box_solid(st_fach, Vector3(x, y_bar + h_bar * 0.5, z_f), Vector3(0.05, h_bar, 0.05), col_bal)
			x += paso
		if tipo == "vidrio":
			# Panel de vidrio estilizado
			_add_box_solid(st_fach, Vector3(base_pos.x, y_bar + h_bar * 0.48, z_f), Vector3(w - 0.1, h_bar * 0.85, 0.03), Color(0.25, 0.36, 0.44))

static func _construir_porche(st_fach: SurfaceTool, st_techos: SurfaceTool, base_pos: Vector3, w: float, prof: float, h_piso: float, mat_techo: int, col_por: Color, col_techo: Color, esc_tex: float) -> void:
	# Plataforma
	_add_box_tiled(st_techos, Vector3(base_pos.x, base_pos.y * 0.5, base_pos.z + prof * 0.5), Vector3(w, maxf(0.18, base_pos.y), prof), 11, Color.WHITE, esc_tex)
	# Columnas
	var n_cols: int = 4 if w >= 9.0 else 2
	for i in range(n_cols):
		var cx: float = -w * 0.46 + (w * 0.92) * (float(i) / float(n_cols - 1))
		_add_box_solid(st_fach, Vector3(cx, base_pos.y + (h_piso - 0.25) * 0.5, base_pos.z + prof - 0.18), Vector3(0.18, h_piso - 0.25, 0.18), col_por)
	# Techo inclinado del porche
	var y_top: float = base_pos.y + h_piso - 0.15
	var y_low: float = y_top - 0.42
	var hw := w * 0.5 + 0.2
	var z0 := base_pos.z
	var z1 := base_pos.z + prof + 0.25
	var p0 := Vector3(-hw, y_top, z0)
	var p1 := Vector3(hw, y_top, z0)
	var p2 := Vector3(hw, y_low, z1)
	var p3 := Vector3(-hw, y_low, z1)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	_emit_quad(st_techos, p0, p1, p2, p3, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, prof * esc_tex), Vector2(0, prof * esc_tex), n, col_techo, Vector2(float(mat_techo), 0.0))

# ============================================================================
# TECHOS (5 TIPOS ARQUITECTÓNICOS)
# ============================================================================

static func _construir_techo_plano(st_fach: SurfaceTool, st_techos: SurfaceTool, base: Vector3, w: float, d: float, alero: float, mat_techo: int, col_techo: Color, col_mold: Color, esc_tex: float, _detalles_azotea: bool) -> void:
	# Losa superior
	_add_box_tiled(st_techos, base + Vector3(0, 0.10, 0), Vector3(w + alero * 2.0, 0.20, d + alero * 2.0), mat_techo, col_techo, esc_tex)
	# Pretil perimetral
	var hp: float = 0.42
	var yp: float = base.y + 0.20 + hp * 0.5
	_add_box_solid(st_fach, Vector3(0, yp, base.z + d * 0.5 - 0.09), Vector3(w, hp, 0.18), col_mold)
	_add_box_solid(st_fach, Vector3(0, yp, base.z - d * 0.5 + 0.09), Vector3(w, hp, 0.18), col_mold)
	_add_box_solid(st_fach, Vector3(-w * 0.5 + 0.09, yp, base.z), Vector3(0.18, hp, d), col_mold)
	_add_box_solid(st_fach, Vector3(w * 0.5 - 0.09, yp, base.z), Vector3(0.18, hp, d), col_mold)

static func _construir_techo_dos_aguas(st_fach: SurfaceTool, st_techos: SurfaceTool, base: Vector3, w: float, d: float, alero: float, pend_deg: float, mat_fach: int, col_fach: Color, mat_techo: int, col_techo: Color, esc_tex: float) -> float:
	var h_cumbrera: float = (d * 0.5) * tan(deg_to_rad(pend_deg))
	var hw := w * 0.5
	var hd := d * 0.5
	var hw_a := hw + alero
	var hd_a := hd + alero
	var dy_alero: float = alero * tan(deg_to_rad(pend_deg))

	var top_l := Vector3(-hw_a, base.y + h_cumbrera, base.z)
	var top_r := Vector3(hw_a, base.y + h_cumbrera, base.z)
	var fl := Vector3(-hw_a, base.y - dy_alero, base.z + hd_a)
	var fr := Vector3(hw_a, base.y - dy_alero, base.z + hd_a)
	var bl := Vector3(-hw_a, base.y - dy_alero, base.z - hd_a)
	var br := Vector3(hw_a, base.y - dy_alero, base.z - hd_a)

	var nf := (top_r - top_l).cross(fl - top_l).normalized()
	var nb := (top_l - top_r).cross(br - top_r).normalized()
	var uv2_t := Vector2(float(mat_techo), 0.0)
	var slope_len := top_l.distance_to(fl)

	# Faldón frontal y trasero (arriba y abajo para grosor visual)
	_emit_quad(st_techos, top_l, top_r, fr, fl, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, slope_len * esc_tex), Vector2(0, slope_len * esc_tex), nf, col_techo, uv2_t)
	_emit_quad(st_techos, top_r, top_l, bl, br, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, slope_len * esc_tex), Vector2(0, slope_len * esc_tex), nb, col_techo, uv2_t)
	# Cielorraso inferior del alero (tile 15)
	_emit_quad(st_techos, fl, fr, top_r - Vector3(0, 0.08, 0), top_l - Vector3(0, 0.08, 0), Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, slope_len * esc_tex), Vector2(0, slope_len * esc_tex), -nf, Color.WHITE, Vector2(15.0, 0.0))
	_emit_quad(st_techos, br, bl, top_l - Vector3(0, 0.08, 0), top_r - Vector3(0, 0.08, 0), Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, slope_len * esc_tex), Vector2(0, slope_len * esc_tex), -nb, Color.WHITE, Vector2(15.0, 0.0))

	# Hastiales triangulares laterales (fachada)
	var uv2_f := Vector2(float(mat_fach), 0.0)
	_emit_tri(st_fach, Vector3(-hw, base.y, base.z + hd), Vector3(-hw, base.y + h_cumbrera, base.z), Vector3(-hw, base.y, base.z - hd),
		Vector2(0, 0), Vector2(hd * esc_tex, h_cumbrera * esc_tex), Vector2(d * esc_tex, 0), Vector3(-1, 0, 0), col_fach, uv2_f)
	_emit_tri(st_fach, Vector3(hw, base.y, base.z - hd), Vector3(hw, base.y + h_cumbrera, base.z), Vector3(hw, base.y, base.z + hd),
		Vector2(0, 0), Vector2(hd * esc_tex, h_cumbrera * esc_tex), Vector2(d * esc_tex, 0), Vector3(1, 0, 0), col_fach, uv2_f)

	return h_cumbrera

static func _construir_techo_cuatro_aguas(st_techos: SurfaceTool, base: Vector3, w: float, d: float, alero: float, pend_deg: float, mat_techo: int, col_techo: Color, esc_tex: float) -> float:
	var menor: float = minf(w, d)
	var h_cumbrera: float = (menor * 0.5) * tan(deg_to_rad(pend_deg))
	var hw := w * 0.5 + alero
	var hd := d * 0.5 + alero
	var dy_alero: float = alero * tan(deg_to_rad(pend_deg))
	var y_eave := base.y - dy_alero
	var y_top := base.y + h_cumbrera

	var ridge_half := maxf(0.0, (w - d) * 0.5)
	var rl := Vector3(-ridge_half, y_top, base.z)
	var rr := Vector3(ridge_half, y_top, base.z)

	var fl := Vector3(-hw, y_eave, base.z + hd)
	var fr := Vector3(hw, y_eave, base.z + hd)
	var bl := Vector3(-hw, y_eave, base.z - hd)
	var br := Vector3(hw, y_eave, base.z - hd)
	var uv2_t := Vector2(float(mat_techo), 0.0)

	var nf := (rr - rl).cross(fl - rl).normalized()
	var nb := (rl - rr).cross(br - rr).normalized()
	var nl := (bl - rl).cross(fl - rl).normalized()
	var nr := (fr - rr).cross(br - rr).normalized()

	_emit_quad(st_techos, rl, rr, fr, fl, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, d * 0.5 * esc_tex), Vector2(0, d * 0.5 * esc_tex), nf, col_techo, uv2_t)
	_emit_quad(st_techos, rr, rl, bl, br, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, d * 0.5 * esc_tex), Vector2(0, d * 0.5 * esc_tex), nb, col_techo, uv2_t)
	_emit_tri(st_techos, rl, fl, bl, Vector2(d * 0.5 * esc_tex, 0), Vector2(0, d * 0.5 * esc_tex), Vector2(d * esc_tex, d * 0.5 * esc_tex), nl, col_techo, uv2_t)
	_emit_tri(st_techos, rr, br, fr, Vector2(d * 0.5 * esc_tex, 0), Vector2(0, d * 0.5 * esc_tex), Vector2(d * esc_tex, d * 0.5 * esc_tex), nr, col_techo, uv2_t)
	# Soffit inferior plano para ocultar huecos desde abajo
	_emit_quad(st_techos, fl, fr, br, bl, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, d * esc_tex), Vector2(0, d * esc_tex), Vector3(0, -1, 0), Color.WHITE, Vector2(15.0, 0.0))

	return h_cumbrera

static func _construir_techo_un_agua(st_fach: SurfaceTool, st_techos: SurfaceTool, base: Vector3, w: float, d: float, alero: float, pend_deg: float, mat_fach: int, col_fach: Color, mat_techo: int, col_techo: Color, esc_tex: float) -> float:
	var h_dif: float = d * tan(deg_to_rad(pend_deg))
	var hw := w * 0.5
	var hd := d * 0.5
	var fl := Vector3(-hw - alero, base.y + h_dif, base.z + hd + alero)
	var fr := Vector3(hw + alero, base.y + h_dif, base.z + hd + alero)
	var bl := Vector3(-hw - alero, base.y, base.z - hd - alero)
	var br := Vector3(hw + alero, base.y, base.z - hd - alero)
	var n := (fr - fl).cross(bl - fl).normalized()
	_emit_quad(st_techos, bl, br, fr, fl, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, d * esc_tex), Vector2(0, d * esc_tex), n, col_techo, Vector2(float(mat_techo), 0.0))
	_emit_quad(st_techos, fl, fr, br, bl, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, d * esc_tex), Vector2(0, d * esc_tex), -n, Color.WHITE, Vector2(15.0, 0.0))

	# Muros laterales y frontal de remate
	var uv2_f := Vector2(float(mat_fach), 0.0)
	_emit_quad(st_fach, Vector3(-hw, base.y + h_dif, base.z + hd), Vector3(hw, base.y + h_dif, base.z + hd), Vector3(hw, base.y, base.z + hd), Vector3(-hw, base.y, base.z + hd),
		Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, h_dif * esc_tex), Vector2(0, h_dif * esc_tex), Vector3(0, 0, 1), col_fach, uv2_f)
	_emit_tri(st_fach, Vector3(-hw, base.y, base.z + hd), Vector3(-hw, base.y + h_dif, base.z + hd), Vector3(-hw, base.y, base.z - hd),
		Vector2(0, 0), Vector2(0, h_dif * esc_tex), Vector2(d * esc_tex, 0), Vector3(-1, 0, 0), col_fach, uv2_f)
	_emit_tri(st_fach, Vector3(hw, base.y, base.z - hd), Vector3(hw, base.y + h_dif, base.z + hd), Vector3(hw, base.y, base.z + hd),
		Vector2(0, 0), Vector2(d * esc_tex, h_dif * esc_tex), Vector2(d * esc_tex, 0), Vector3(1, 0, 0), col_fach, uv2_f)
	return h_dif

static func _construir_techo_mansarda(st_techos: SurfaceTool, base: Vector3, w: float, d: float, alero: float, pend_deg: float, mat_techo: int, col_techo: Color, esc_tex: float) -> float:
	var h_m: float = clampf(tan(deg_to_rad(pend_deg)) * 2.2, 0.8, 2.2)
	var hw := w * 0.5 + alero
	var hd := d * 0.5 + alero
	var tw := maxf(1.5, w * 0.5 - 1.1)
	var td := maxf(1.5, d * 0.5 - 1.1)
	var uv2_t := Vector2(float(mat_techo), 0.0)

	var fl := Vector3(-hw, base.y, base.z + hd)
	var fr := Vector3(hw, base.y, base.z + hd)
	var bl := Vector3(-hw, base.y, base.z - hd)
	var br := Vector3(hw, base.y, base.z - hd)

	var tfl := Vector3(-tw, base.y + h_m, base.z + td)
	var tfr := Vector3(tw, base.y + h_m, base.z + td)
	var tbl := Vector3(-tw, base.y + h_m, base.z - td)
	var tbr := Vector3(tw, base.y + h_m, base.z - td)

	_emit_quad(st_techos, tfl, tfr, fr, fl, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, h_m * esc_tex), Vector2(0, h_m * esc_tex), Vector3(0, 0.5, 1).normalized(), col_techo, uv2_t)
	_emit_quad(st_techos, tbr, tbl, bl, br, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, h_m * esc_tex), Vector2(0, h_m * esc_tex), Vector3(0, 0.5, -1).normalized(), col_techo, uv2_t)
	_emit_quad(st_techos, tbl, tfl, fl, bl, Vector2(0, 0), Vector2(d * esc_tex, 0), Vector2(d * esc_tex, h_m * esc_tex), Vector2(0, h_m * esc_tex), Vector3(-1, 0.5, 0).normalized(), col_techo, uv2_t)
	_emit_quad(st_techos, tfr, tbr, br, fr, Vector2(0, 0), Vector2(d * esc_tex, 0), Vector2(d * esc_tex, h_m * esc_tex), Vector2(0, h_m * esc_tex), Vector3(1, 0.5, 0).normalized(), col_techo, uv2_t)
	_emit_quad(st_techos, tbl, tbr, tfr, tfl, Vector2(0, 0), Vector2(tw * 2 * esc_tex, 0), Vector2(tw * 2 * esc_tex, td * 2 * esc_tex), Vector2(0, td * 2 * esc_tex), Vector3(0, 1, 0), col_techo, Vector2(5.0, 0.0))
	return h_m

static func _construir_techo_diente_sierra(st_fach: SurfaceTool, st_vent: SurfaceTool, st_techos: SurfaceTool, base: Vector3, w: float, d: float, pend_deg: float, mat_fach: int, col_fach: Color, mat_techo: int, col_techo: Color, esc_tex: float) -> float:
	var n_dientes := clampi(int(round(d / 4.5)), 2, 5)
	var paso_z := d / float(n_dientes)
	var h_diente := clampf(paso_z * tan(deg_to_rad(pend_deg)) * 0.75, 1.0, 2.8)
	var hw := w * 0.5
	var uv2_t := Vector2(float(mat_techo), 0.0)
	var uv2_f := Vector2(float(mat_fach), 0.0)

	for i in range(n_dientes):
		var z0 := base.z - d * 0.5 + float(i) * paso_z
		var z1 := z0 + paso_z
		var p_low_l := Vector3(-hw, base.y, z0)
		var p_low_r := Vector3(hw, base.y, z0)
		var p_top_l := Vector3(-hw, base.y + h_diente, z1)
		var p_top_r := Vector3(hw, base.y + h_diente, z1)
		var p_bot_l := Vector3(-hw, base.y, z1)
		var p_bot_r := Vector3(hw, base.y, z1)

		var n_slope := (p_low_r - p_low_l).cross(p_top_l - p_low_l).normalized()
		_emit_quad(st_techos, p_top_l, p_top_r, p_low_r, p_low_l, Vector2(0, 0), Vector2(w * esc_tex, 0), Vector2(w * esc_tex, paso_z * esc_tex), Vector2(0, paso_z * esc_tex), n_slope, col_techo, uv2_t)
		# Tragaluz vertical (+Z) en cada diente
		_emit_quad(st_vent, p_top_l, p_top_r, p_bot_r, p_bot_l, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector3(0, 0, 1), Color(0.75, 0.78, 0.82), Vector2(15.0, 1.0))
		# Hastiales laterales
		_emit_tri(st_fach, p_low_l, p_top_l, p_bot_l, Vector2(0, 0), Vector2(paso_z * esc_tex, h_diente * esc_tex), Vector2(paso_z * esc_tex, 0), Vector3(-1, 0, 0), col_fach, uv2_f)
		_emit_tri(st_fach, p_bot_r, p_top_r, p_low_r, Vector2(0, 0), Vector2(0, h_diente * esc_tex), Vector2(paso_z * esc_tex, 0), Vector3(1, 0, 0), col_fach, uv2_f)
	return h_diente

static func _construir_techo_boveda(st_fach: SurfaceTool, st_techos: SurfaceTool, base: Vector3, w: float, d: float, alero: float, mat_fach: int, col_fach: Color, mat_techo: int, col_techo: Color, esc_tex: float) -> float:
	var h_arco: float = clampf(w * 0.14, 1.2, 3.2)
	var hw := w * 0.5
	var hd := d * 0.5 + alero
	var segs := 8
	var uv2_t := Vector2(float(mat_techo), 0.0)
	var uv2_f := Vector2(float(mat_fach), 0.0)

	for s in range(segs):
		var t0 := float(s) / float(segs)
		var t1 := float(s + 1) / float(segs)
		var x0 := -hw - alero + (w + alero * 2.0) * t0
		var x1 := -hw - alero + (w + alero * 2.0) * t1
		var y0 := base.y + sin(t0 * PI) * h_arco
		var y1 := base.y + sin(t1 * PI) * h_arco

		var p0 := Vector3(x0, y0, base.z - hd)
		var p1 := Vector3(x1, y1, base.z - hd)
		var p2 := Vector3(x1, y1, base.z + hd)
		var p3 := Vector3(x0, y0, base.z + hd)
		var n := (p1 - p0).cross(p3 - p0).normalized()
		_emit_quad(st_techos, p0, p1, p2, p3, Vector2(t0 * w * esc_tex, 0), Vector2(t1 * w * esc_tex, 0), Vector2(t1 * w * esc_tex, d * esc_tex), Vector2(t0 * w * esc_tex, d * esc_tex), n, col_techo, uv2_t)

		# Tímpanos frontal y trasero
		var fx0 := lerpf(-hw, hw, t0)
		var fx1 := lerpf(-hw, hw, t1)
		var fy0 := base.y + sin(t0 * PI) * h_arco
		var fy1 := base.y + sin(t1 * PI) * h_arco
		_emit_tri(st_fach, Vector3(fx0, base.y, base.z + d * 0.5), Vector3(fx0, fy0, base.z + d * 0.5), Vector3(fx1, fy1, base.z + d * 0.5), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector3(0, 0, 1), col_fach, uv2_f)
		_emit_tri(st_fach, Vector3(fx0, base.y, base.z + d * 0.5), Vector3(fx1, fy1, base.z + d * 0.5), Vector3(fx1, base.y, base.z + d * 0.5), Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), Vector3(0, 0, 1), col_fach, uv2_f)
		_emit_tri(st_fach, Vector3(fx1, fy1, base.z - d * 0.5), Vector3(fx0, fy0, base.z - d * 0.5), Vector3(fx0, base.y, base.z - d * 0.5), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector3(0, 0, -1), col_fach, uv2_f)
		_emit_tri(st_fach, Vector3(fx1, base.y, base.z - d * 0.5), Vector3(fx1, fy1, base.z - d * 0.5), Vector3(fx0, base.y, base.z - d * 0.5), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), Vector3(0, 0, -1), col_fach, uv2_f)
	return h_arco

static func _instanciar_glb(archivo: String, pos: Vector3, rot_y_deg: float = 0.0, esc: Vector3 = Vector3.ONE) -> Node3D:
	var ruta := GLB_DIR + archivo
	var scene: PackedScene = _glb_cache.get(ruta)
	if not scene and ResourceLoader.exists(ruta):
		scene = load(ruta) as PackedScene
		_glb_cache[ruta] = scene
	if not scene:
		return null
	var inst := scene.instantiate() as Node3D
	if inst:
		inst.position = pos
		inst.rotation_degrees.y = rot_y_deg
		inst.scale = esc
	return inst

static func _poblar_modulos_blender(root: Node3D, cfg: Dictionary, mesh: ArrayMesh, mats: Array[Material], y_techo: float, h_techo: float, top_w: float, top_d: float, top_z_off: float, n_modulos: int) -> void:
	var cont := root.get_node_or_null("ModulosBlender") as Node3D
	if cont:
		for h in cont.get_children():
			h.queue_free()
	else:
		cont = Node3D.new()
		cont.name = "ModulosBlender"
		root.add_child(cont)

	var ancho: float = float(cfg["ancho"])
	var fondo: float = float(cfg["fondo"])
	var h_zoc: float = float(cfg["altura_zocalo"])
	var tipo_techo: String = str(cfg.get("tipo_techo", "dos_aguas"))

	# 1. Repetición de módulos en Conjuntos Residenciales
	if n_modulos > 1:
		var x_ini := -ancho * float(n_modulos - 1) * 0.5
		for i in range(1, n_modulos):
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			for si in range(mats.size()):
				mi.set_surface_override_material(si, mats[si])
			mi.position.x = x_ini + float(i) * ancho
			cont.add_child(mi)

	var ancho_total := ancho * float(n_modulos)
	var y_azotea := y_techo + (0.20 if tipo_techo == "plano" else h_techo * 0.35)

	# 2. Tinaco / Tanque elevado en azotea (Blender GLB)
	if bool(cfg.get("detalles_azotea", false)) and tipo_techo == "plano":
		var t_inst := _instanciar_glb("tanque_agua_tinaco.glb", Vector3(-top_w * 0.28, y_techo + 0.20, top_z_off - top_d * 0.22))
		if t_inst:
			cont.add_child(t_inst)

	# 3. Unidades HVAC en azotea (Blender GLB)
	var n_hvac := int(cfg.get("unidades_hvac", 0))
	for i in range(n_hvac):
		var hx := -top_w * 0.32 + (top_w * 0.64) * (float(i) / maxf(1.0, float(n_hvac - 1))) if n_hvac > 1 else top_w * 0.24
		var hy := (y_techo + 0.20) if tipo_techo == "plano" else (y_azotea + 0.1)
		var h_inst := _instanciar_glb("hvac_industrial.glb", Vector3(hx, hy, top_z_off - top_d * 0.15))
		if h_inst:
			cont.add_child(h_inst)

	# 4. Antena Telecomunicaciones en azotea (Blender GLB)
	if bool(cfg.get("tiene_antena", false)):
		var a_inst := _instanciar_glb("antena_telecom.glb", Vector3(top_w * 0.30, y_techo + 0.20, top_z_off + top_d * 0.22))
		if a_inst:
			cont.add_child(a_inst)

	# 5. Paneles Solares en azotea (Blender GLB)
	if bool(cfg.get("tiene_paneles_solares", false)):
		var ps_inst := _instanciar_glb("panel_solar_rack.glb", Vector3(-top_w * 0.18, y_techo + 0.20, top_z_off + top_d * 0.18), 0.0, Vector3(1.2, 1.2, 1.2))
		if ps_inst:
			cont.add_child(ps_inst)

	# 6. Domos Tragaluces (Blender GLB)
	if bool(cfg.get("tiene_domos", false)):
		for dx in [-top_w * 0.22, top_w * 0.22]:
			var d_inst := _instanciar_glb("domo_tragaluz.glb", Vector3(dx, y_techo + 0.20, top_z_off))
			if d_inst:
				cont.add_child(d_inst)

	# 7. Marquesina Comercial / Lobby (Blender GLB)
	if bool(cfg.get("tiene_marquesina", false)):
		var m_inst := _instanciar_glb("marquesina_comercial.glb", Vector3(0.0, h_zoc, fondo * 0.5))
		if m_inst:
			cont.add_child(m_inst)

	# 8. Muelles de Carga Logísticos (Blender GLB)
	var n_muelles := int(cfg.get("muelles_carga", 0))
	if n_muelles > 0:
		var paso_m := ancho_total / float(n_muelles + 1)
		for i in range(n_muelles):
			var mx := -ancho_total * 0.5 + paso_m * float(i + 1)
			var mu_inst := _instanciar_glb("muelle_carga.glb", Vector3(mx, 0.0, fondo * 0.5))
			if mu_inst:
				cont.add_child(mu_inst)

	# 9. Silos Industriales Laterales (Blender GLB)
	var n_silos := int(cfg.get("silos_laterales", 0))
	for i in range(n_silos):
		var sz := -fondo * 0.32 + float(i) * 3.5
		var s_inst := _instanciar_glb("silo_industrial.glb", Vector3(ancho_total * 0.5 + 2.0, 0.0, sz))
		if s_inst:
			cont.add_child(s_inst)

	# 10. Chimenea Industrial Alta (Blender GLB)
	if bool(cfg.get("tiene_chimenea_ind", false)):
		var ch_inst := _instanciar_glb("chimenea_industrial.glb", Vector3(-ancho_total * 0.5 - 1.8, 0.0, -fondo * 0.28))
		if ch_inst:
			cont.add_child(ch_inst)

	# 11. Portería de Conjunto Residencial (Blender GLB)
	if bool(cfg.get("tiene_porteria", false)):
		var p_inst := _instanciar_glb("porteria_conjunto.glb", Vector3(-ancho_total * 0.25, 0.0, fondo * 0.5 + 4.5))
		if p_inst:
			cont.add_child(p_inst)

