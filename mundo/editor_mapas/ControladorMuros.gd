class_name ControladorMuros
extends Node3D

## ControladorMuros.gd — Sistema procedural y modular de muros y cercas por trazado A -> B -> C.
## Utiliza los modelos GLB con texturas atlas generadas en Blender.

signal tramo_muro_actualizado(cantidad_tramos: int)

const LARGO_MODULO: float = 4.0

var controlador_terreno: Node = null
var tipo_muro_activo: String = "muro_ladrillo"
var escala_altura: float = 1.0

var _contenedor_muros: Node3D = null
var _tramos: Array[Dictionary] = [] # {"id": String, "escala_y": float, "puntos": Array[Vector3], "nodo": Node3D}
var _tramo_activo_idx: int = -1

var _marcador_preview: MeshInstance3D = null
var _linea_preview_inst: MeshInstance3D = null
var _linea_preview: ImmediateMesh = null
var _cache_escenas: Dictionary = {}

static func obtener_catalogo_muros() -> Array[Dictionary]:
	return [
		# 10 Muros Urbanos / Arquitectónicos
		{"id": "muro_ladrillo", "nombre": "Muro Ladrillo", "corto": "Ladrillo", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_ladrillo.glb", "tex": "res://recursos/iconos_editor/muros/muro_ladrillo.png", "desc": "Ladrillo rojo terracota con pilastras y remate"},
		{"id": "muro_concreto", "nombre": "Muro Concreto", "corto": "Concreto", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_concreto.glb", "tex": "res://recursos/iconos_editor/muros/muro_concreto.png", "desc": "Concreto arquitectonico con juntas de dilatacion"},
		{"id": "muro_piedra_natural", "nombre": "Piedra Natural", "corto": "Piedra", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_piedra_natural.glb", "tex": "res://recursos/iconos_editor/muros/muro_piedra_natural.png", "desc": "Muro robusto en piedra laja tallada"},
		{"id": "muro_bloque_gris", "nombre": "Bloque Gris", "corto": "Bloque", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_bloque_gris.glb", "tex": "res://recursos/iconos_editor/muros/muro_bloque_gris.png", "desc": "Bloque estructural gris con columnas"},
		{"id": "muro_mamposteria_colonial", "nombre": "Muro Colonial", "corto": "Colonial", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_mamposteria_colonial.glb", "tex": "res://recursos/iconos_editor/muros/muro_mamposteria_colonial.png", "desc": "Estuco colonial blanco con zocalo y teja"},
		{"id": "muro_prefabricado_industrial", "nombre": "Prefabricado", "corto": "Prefab", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_prefabricado_industrial.glb", "tex": "res://recursos/iconos_editor/muros/muro_prefabricado_industrial.png", "desc": "Placas prefabricadas industriales con postes H"},
		{"id": "muro_barrera_jersey", "nombre": "Barrera Jersey", "corto": "Jersey", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_barrera_jersey.glb", "tex": "res://recursos/iconos_editor/muros/muro_barrera_jersey.png", "desc": "Separador vial de hormigon con franja reflectiva"},
		{"id": "muro_gaviones", "nombre": "Muro Gaviones", "corto": "Gavion", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_gaviones.glb", "tex": "res://recursos/iconos_editor/muros/muro_gaviones.png", "desc": "Jaula metalica rellena de piedra de rio"},
		{"id": "muro_ladrillo_reja", "nombre": "Ladrillo y Reja", "corto": "Reja", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_ladrillo_reja.glb", "tex": "res://recursos/iconos_editor/muros/muro_ladrillo_reja.png", "desc": "Zocalo de ladrillo con barrotes de hierro"},
		{"id": "muro_contencion_hormigon", "nombre": "Muro Contencion", "corto": "Contencion", "cat": "urbano", "glb": "res://modelos3d/mapa/muros/muro_contencion_hormigon.glb", "tex": "res://recursos/iconos_editor/muros/muro_contencion_hormigon.png", "desc": "Hormigon inclinado con contrafuertes"},
		# 5 Muros Agrícolas / de Campo
		{"id": "cerca_madera_rustica", "nombre": "Cerca Madera", "corto": "Madera", "cat": "campo", "glb": "res://modelos3d/mapa/muros/cerca_madera_rustica.glb", "tex": "res://recursos/iconos_editor/muros/cerca_madera_rustica.png", "desc": "Cerca campestre de postes y tablones"},
		{"id": "cerca_alambre_puas", "nombre": "Alambre Puas", "corto": "Alambre", "cat": "campo", "glb": "res://modelos3d/mapa/muros/cerca_alambre_puas.glb", "tex": "res://recursos/iconos_editor/muros/cerca_alambre_puas.png", "desc": "Postes rurales con 4 hilos de alambre"},
		{"id": "cerca_guadua_bambu", "nombre": "Cerca Guadua", "corto": "Guadua", "cat": "campo", "glb": "res://modelos3d/mapa/muros/cerca_guadua_bambu.glb", "tex": "res://recursos/iconos_editor/muros/cerca_guadua_bambu.png", "desc": "Cerca tradicional colombiana en guadua"},
		{"id": "cerca_piedra_seca", "nombre": "Pirca Piedra", "corto": "Pirca", "cat": "campo", "glb": "res://modelos3d/mapa/muros/cerca_piedra_seca.glb", "tex": "res://recursos/iconos_editor/muros/cerca_piedra_seca.png", "desc": "Muro agricola de piedra apilada con musgo"},
		{"id": "cerca_seto_vivo", "nombre": "Seto Vivo", "corto": "Seto", "cat": "campo", "glb": "res://modelos3d/mapa/muros/cerca_seto_vivo.glb", "tex": "res://recursos/iconos_editor/muros/cerca_seto_vivo.png", "desc": "Cerco vivo de follaje denso recortado"}
	]

func _ready() -> void:
	_contenedor_muros = Node3D.new()
	_contenedor_muros.name = "ContenedorMuros_Editor"
	add_child(_contenedor_muros)
	_crear_preview()

func _crear_preview() -> void:
	_marcador_preview = MeshInstance3D.new()
	_marcador_preview.name = "MarcadorPreviewMuro"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.65
	cyl.bottom_radius = 0.65
	cyl.height = 0.35
	_marcador_preview.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.68, 0.28, 0.90)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marcador_preview.material_override = mat
	_marcador_preview.visible = false
	add_child(_marcador_preview)

	_linea_preview_inst = MeshInstance3D.new()
	_linea_preview_inst.name = "LineaPreviewMuro"
	_linea_preview = ImmediateMesh.new()
	_linea_preview_inst.mesh = _linea_preview
	var mat_lin := StandardMaterial3D.new()
	mat_lin.albedo_color = Color(0.95, 0.78, 0.35, 0.95)
	mat_lin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_linea_preview_inst.material_override = mat_lin
	_linea_preview_inst.visible = false
	add_child(_linea_preview_inst)

func establecer_tipo_muro(id_muro: String) -> void:
	for item in obtener_catalogo_muros():
		if item["id"] == id_muro:
			tipo_muro_activo = id_muro
			return

func establecer_escala_altura(esc: float) -> void:
	escala_altura = clampf(esc, 0.5, 2.2)

func actualizar_cursor_muro(pos_mundo: Vector3, visible_en_pantalla: bool) -> void:
	if _marcador_preview:
		_marcador_preview.visible = visible_en_pantalla
		if visible_en_pantalla:
			_marcador_preview.global_position = pos_mundo + Vector3(0, 0.2, 0)

	if _linea_preview_inst and _linea_preview:
		if visible_en_pantalla and _tramo_activo_idx >= 0 and _tramo_activo_idx < _tramos.size():
			var pts: Array = _tramos[_tramo_activo_idx]["puntos"]
			if pts.size() >= 1:
				var p_ini: Vector3 = pts[pts.size() - 1]
				_linea_preview.clear_surfaces()
				_linea_preview.surface_begin(Mesh.PRIMITIVE_LINES)
				_linea_preview.surface_add_vertex(p_ini + Vector3(0, 0.4, 0))
				_linea_preview.surface_add_vertex(pos_mundo + Vector3(0, 0.4, 0))
				_linea_preview.surface_end()
				_linea_preview_inst.visible = true
				return
		_linea_preview_inst.visible = false

func agregar_punto_muro(pos_mundo: Vector3) -> void:
	var pos := pos_mundo
	if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
		pos.y = controlador_terreno.obtener_altura(pos)

	# Snap suave a extremos de otros tramos para cerrar cercas/muros
	var snap_dist := 3.5
	for t in _tramos:
		var pts_t: Array = t["puntos"]
		if pts_t.size() > 0:
			for ext in [pts_t[0], pts_t[pts_t.size() - 1]]:
				if pos.distance_to(ext) <= snap_dist:
					pos = ext
					break

	if _tramo_activo_idx < 0 or _tramo_activo_idx >= _tramos.size():
		var nodo := Node3D.new()
		nodo.name = "TramoMuro_%d" % _tramos.size()
		_contenedor_muros.add_child(nodo)
		var pts_nuevos: Array[Vector3] = [pos]
		_tramos.append({
			"id": tipo_muro_activo,
			"escala_y": escala_altura,
			"puntos": pts_nuevos,
			"nodo": nodo
		})
		_tramo_activo_idx = _tramos.size() - 1
	else:
		var pts: Array = _tramos[_tramo_activo_idx]["puntos"]
		if pts.size() > 0 and pts[pts.size() - 1].distance_to(pos) < 1.0:
			return
		pts.append(pos)
		_reconstruir_tramo(_tramo_activo_idx)

	tramo_muro_actualizado.emit(_tramos.size())

func finalizar_tramo_actual() -> void:
	_tramo_activo_idx = -1
	if _linea_preview_inst:
		_linea_preview_inst.visible = false

func deshacer_ultimo_punto() -> bool:
	if _tramo_activo_idx >= 0 and _tramo_activo_idx < _tramos.size():
		var pts: Array = _tramos[_tramo_activo_idx]["puntos"]
		if pts.size() > 1:
			pts.pop_back()
			_reconstruir_tramo(_tramo_activo_idx)
			tramo_muro_actualizado.emit(_tramos.size())
			return true
		else:
			var nodo: Node3D = _tramos[_tramo_activo_idx]["nodo"]
			if is_instance_valid(nodo):
				nodo.queue_free()
			_tramos.remove_at(_tramo_activo_idx)
			_tramo_activo_idx = -1
			tramo_muro_actualizado.emit(_tramos.size())
			return true
	elif _tramos.size() > 0:
		var ult = _tramos.pop_back()
		if is_instance_valid(ult["nodo"]):
			ult["nodo"].queue_free()
		tramo_muro_actualizado.emit(_tramos.size())
		return true
	return false

func borrar_muro_en_posicion(pos_mundo: Vector3, radio: float = 5.0) -> bool:
	var mejor_idx := -1
	var menor_d2 := radio * radio
	for i in _tramos.size():
		var pts: Array = _tramos[i]["puntos"]
		for p in pts:
			var d2 := Vector2(p.x - pos_mundo.x, p.z - pos_mundo.z).length_squared()
			if d2 < menor_d2:
				menor_d2 = d2
				mejor_idx = i
	if mejor_idx != -1:
		var nodo: Node3D = _tramos[mejor_idx]["nodo"]
		if is_instance_valid(nodo):
			nodo.queue_free()
		_tramos.remove_at(mejor_idx)
		if _tramo_activo_idx == mejor_idx:
			_tramo_activo_idx = -1
		elif _tramo_activo_idx > mejor_idx:
			_tramo_activo_idx -= 1
		tramo_muro_actualizado.emit(_tramos.size())
		return true
	return false

func _obtener_escena_muro(id_muro: String) -> PackedScene:
	if _cache_escenas.has(id_muro):
		return _cache_escenas[id_muro]
	var ruta := ""
	for item in obtener_catalogo_muros():
		if item["id"] == id_muro:
			ruta = item["glb"]
			break
	if not ruta.is_empty() and ResourceLoader.exists(ruta):
		var scn := load(ruta) as PackedScene
		_cache_escenas[id_muro] = scn
		return scn
	return null

func _reconstruir_tramo(idx: int) -> void:
	if idx < 0 or idx >= _tramos.size():
		return
	var datos: Dictionary = _tramos[idx]
	var nodo: Node3D = datos["nodo"]
	for h in nodo.get_children():
		nodo.remove_child(h)
		h.queue_free()

	var pts: Array = datos["puntos"]
	if pts.size() < 2:
		return

	var curva := Curve3D.new()
	for i in pts.size():
		var p: Vector3 = pts[i]
		var tan_in := Vector3.ZERO
		var tan_out := Vector3.ZERO
		if i > 0 and i < pts.size() - 1:
			var p_sig: Vector3 = pts[i + 1]
			var p_ant: Vector3 = pts[i - 1]
			var dir_suave: Vector3 = (p_sig - p_ant).normalized()
			var dist_min: float = minf(p.distance_to(p_ant), p.distance_to(p_sig)) * 0.28
			tan_in = -dir_suave * dist_min
			tan_out = dir_suave * dist_min
		curva.add_point(p, tan_in, tan_out)

	var largo_total: float = curva.get_baked_length()
	if largo_total < 0.5:
		return

	var num_modulos: int = maxi(1, int(round(largo_total / LARGO_MODULO)))
	var paso_real: float = largo_total / float(num_modulos)
	var factor_z: float = paso_real / LARGO_MODULO
	var esc_y: float = float(datos.get("escala_y", 1.0))
	var scn: PackedScene = _obtener_escena_muro(datos["id"])

	for m in num_modulos:
		var d_ini: float = float(m) * paso_real
		var d_fin: float = minf(largo_total, float(m + 1) * paso_real)
		var d_centro: float = (d_ini + d_fin) * 0.5

		var p_a: Vector3 = curva.sample_baked(d_ini)
		var p_b: Vector3 = curva.sample_baked(d_fin)
		var p_c: Vector3 = curva.sample_baked(d_centro)
		if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
			p_a.y = controlador_terreno.obtener_altura(p_a)
			p_b.y = controlador_terreno.obtener_altura(p_b)
			p_c.y = controlador_terreno.obtener_altura(p_c)

		var p_centro: Vector3 = (p_a + p_b) * 0.5
		# Si hay una hondonada en medio del segmento, bajar ligeramente para no quedar flotando
		p_centro.y = minf(p_centro.y, p_c.y) - 0.14

		var vec_3d: Vector3 = p_b - p_a
		var largo_3d: float = vec_3d.length()
		if largo_3d < 0.05:
			continue
		var dir_3d: Vector3 = vec_3d / largo_3d
		if absf(dir_3d.y) > 0.96:
			dir_3d = Vector3(dir_3d.x, signf(dir_3d.y) * 0.96, dir_3d.z).normalized()

		var factor_z_pendiente: float = (largo_3d / LARGO_MODULO) * 1.03

		var mod_nodo: Node3D = scn.instantiate() if scn else Node3D.new()
		nodo.add_child(mod_nodo)
		mod_nodo.global_position = p_centro
		mod_nodo.look_at(p_centro + dir_3d, Vector3.UP)
		mod_nodo.scale = Vector3(1.0, esc_y, factor_z_pendiente)

		# Colisión sólida para vehículo y jugador en Modo Prueba
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.65, 2.4, LARGO_MODULO)
		cs.shape = box
		cs.position = Vector3(0.0, 1.2, 0.0)
		sb.add_child(cs)
		mod_nodo.add_child(sb)

func limpiar_todos_los_muros() -> void:
	_tramo_activo_idx = -1
	for t in _tramos:
		if is_instance_valid(t["nodo"]):
			t["nodo"].queue_free()
	_tramos.clear()
	tramo_muro_actualizado.emit(0)

func serializar_muros() -> Array:
	var salida: Array = []
	for t in _tramos:
		var pts_arr: Array = []
		for p in t["puntos"]:
			pts_arr.append([p.x, p.y, p.z])
		salida.append({
			"id": t["id"],
			"escala_y": t.get("escala_y", 1.0),
			"puntos": pts_arr
		})
	return salida

func deserializar_muros(lista: Array) -> void:
	limpiar_todos_los_muros()
	for d in lista:
		if not (d is Dictionary):
			continue
		var pts: Array[Vector3] = []
		for p_arr in d.get("puntos", []):
			if p_arr is Array and p_arr.size() >= 3:
				pts.append(Vector3(float(p_arr[0]), float(p_arr[1]), float(p_arr[2])))
		if pts.size() < 2:
			continue
		var nodo := Node3D.new()
		nodo.name = "TramoMuro_%d" % _tramos.size()
		_contenedor_muros.add_child(nodo)
		_tramos.append({
			"id": str(d.get("id", "muro_ladrillo")),
			"escala_y": float(d.get("escala_y", 1.0)),
			"puntos": pts,
			"nodo": nodo
		})
		_reconstruir_tramo(_tramos.size() - 1)
	tramo_muro_actualizado.emit(_tramos.size())
