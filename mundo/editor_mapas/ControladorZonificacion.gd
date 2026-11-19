class_name ControladorZonificacion
extends Node3D

## ControladorZonificacion.gd
## Sistema de zonificación estilo Cities: Skylines 2 con cuadros pegados adaptados a las curvas de las carreteras.

signal zonas_actualizadas(total: int)

enum TipoZona {
	NINGUNA = 0,
	RESIDENCIAL = 1,
	COMERCIAL = 2,
	INDUSTRIAL = 3,
	MIXTO = 4,
	MODULAR = 5
}

const COLORES_ZONA := {
	TipoZona.RESIDENCIAL: Color(0.18, 0.84, 0.38, 0.52),
	TipoZona.COMERCIAL: Color(0.18, 0.56, 0.96, 0.52),
	TipoZona.INDUSTRIAL: Color(0.94, 0.68, 0.16, 0.52),
	TipoZona.MIXTO: Color(0.68, 0.34, 0.90, 0.52),
	TipoZona.MODULAR: Color(0.16, 0.82, 0.80, 0.52),
}

const SECCION_POR_ZONA := {
	TipoZona.RESIDENCIAL: "01_Residencial",
	TipoZona.COMERCIAL: "02_Comercial",
	TipoZona.INDUSTRIAL: "03_Industrial_Logistica",
	TipoZona.MIXTO: "01_Residencial",
	TipoZona.MODULAR: "modulares",
}

var controlador_terreno = null
var controlador_carreteras = null
var controlador_objetos = null

var zona_activa: int = TipoZona.RESIDENCIAL
var radio_pincel: float = 5.5
var filas_profundidad: int = 1
var auto_construir_al_pintar: bool = true

var _celdas: Dictionary = {} # key -> Dictionary {"pts": Array[Vector3], "centro": Vector3, "rot_y": float, "tipo": int, "ocupada": bool, "nodo": MeshInstance3D}
var _grilla_preview: MeshInstance3D = null
var _contenedor: Node3D = null
var _materiales: Dictionary = {}
var _mat_grilla_vacia: StandardMaterial3D = null
var _pendientes_construir: Array[String] = []

func _ready() -> void:
	_asegurar_inicializado()

func _asegurar_inicializado() -> void:
	if not is_instance_valid(_contenedor):
		_contenedor = Node3D.new()
		_contenedor.name = "CeldasZonificacion"
		add_child(_contenedor)
	if _materiales.is_empty():
		for t in COLORES_ZONA.keys():
			var mat := StandardMaterial3D.new()
			var c: Color = COLORES_ZONA[t]
			mat.albedo_color = c
			mat.emission_enabled = true
			mat.emission = Color(c.r, c.g, c.b)
			mat.emission_energy_multiplier = 0.75
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materiales[t] = mat
	if not _mat_grilla_vacia:
		_mat_grilla_vacia = StandardMaterial3D.new()
		_mat_grilla_vacia.albedo_color = Color(0.88, 0.92, 0.96, 0.42)
		_mat_grilla_vacia.emission_enabled = true
		_mat_grilla_vacia.emission = Color(0.70, 0.80, 0.92)
		_mat_grilla_vacia.emission_energy_multiplier = 0.5
		_mat_grilla_vacia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_grilla_vacia.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not is_instance_valid(_grilla_preview):
		_grilla_preview = MeshInstance3D.new()
		_grilla_preview.name = "GrillaCurvasPreview"
		_grilla_preview.material_override = _mat_grilla_vacia
		_grilla_preview.visible = false
		add_child(_grilla_preview)

func _altura_terreno(p: Vector3) -> float:
	if controlador_terreno and controlador_terreno.has_method("obtener_altura"):
		return float(controlador_terreno.obtener_altura(p))
	return p.y

func _construir_cuadros_de_segmentos() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if not controlador_carreteras or not controlador_carreteras.get("road_container") or not is_instance_valid(controlador_carreteras.road_container):
		return resultado
	var rc = controlador_carreteras.road_container
	const CELL_W := 7.5
	const CELL_D := 8.0
	var num_filas: int = clampi(filas_profundidad, 1, 2)

	for seg_obj in rc.get_segments():
		var seg := seg_obj as Node3D
		if not is_instance_valid(seg):
			continue
		var curve := seg.get("curve") as Curve3D
		if not curve:
			continue
		var largo: float = curve.get_baked_length()
		if largo < 4.0:
			continue
		var ancho_via := 8.8
		var sp = seg.get("start_point")
		if controlador_carreteras.has_method("_obtener_ancho_via_punto") and sp != null and is_instance_valid(sp):
			ancho_via = float(controlador_carreteras._obtener_ancho_via_punto(sp))

		var pasos := maxi(1, int(round(largo / CELL_W)))
		var step_len := largo / float(pasos)

		for i in range(pasos):
			var off0 := float(i) * step_len
			var off1 := float(i + 1) * step_len
			var p0 := _sample_world(seg, curve, off0)
			var p1 := _sample_world(seg, curve, off1)
			var t0 := _tangent_world(seg, curve, off0, largo)
			var t1 := _tangent_world(seg, curve, off1, largo)
			var lat0 := Vector3(-t0.z, 0.0, t0.x)
			var lat1 := Vector3(-t1.z, 0.0, t1.x)

			for s_v in [-1.0, 1.0]:
				var signo: float = float(s_v)
				for fila in range(num_filas):
					var d_in := ancho_via * 0.5 + 3.2 + float(fila) * CELL_D
					var d_out := d_in + CELL_D
					var q00 := p0 + lat0 * (signo * d_in)
					var q10 := p1 + lat1 * (signo * d_in)
					var q11 := p1 + lat1 * (signo * d_out)
					var q01 := p0 + lat0 * (signo * d_out)
					q00.y = _altura_terreno(q00) + 0.14
					q10.y = _altura_terreno(q10) + 0.14
					q11.y = _altura_terreno(q11) + 0.14
					q01.y = _altura_terreno(q01) + 0.14
					var centro := (q00 + q10 + q11 + q01) * 0.25
					var dir_frente := ((q00 + q10) * 0.5 - centro)
					dir_frente.y = 0.0
					var rot_y := rad_to_deg(atan2(dir_frente.x, dir_frente.z)) if dir_frente.length_squared() > 0.001 else 0.0
					var key := "%d_%d" % [int(round(centro.x / 5.0)), int(round(centro.z / 5.0))]
					resultado.append({
						"key": key,
						"pts": [q00, q10, q11, q01],
						"centro": centro,
						"rot_y": rot_y,
						"fila": fila
					})
	return resultado

func _sample_world(seg: Node3D, curve: Curve3D, off: float) -> Vector3:
	var pl: Vector3 = curve.sample_baked(clampf(off, 0.0, curve.get_baked_length()))
	return seg.to_global(pl) if seg.is_inside_tree() else (seg.position + pl)

func _tangent_world(seg: Node3D, curve: Curve3D, off: float, largo: float) -> Vector3:
	var o_a := clampf(off - 0.5, 0.0, largo)
	var o_b := clampf(off + 0.5, 0.0, largo)
	var pa := _sample_world(seg, curve, o_a)
	var pb := _sample_world(seg, curve, o_b)
	var t := pb - pa
	t.y = 0.0
	return t.normalized() if t.length_squared() > 0.0001 else Vector3.FORWARD

func mostrar_grilla_disponible(visible_flag: bool) -> void:
	_asegurar_inicializado()
	_grilla_preview.visible = visible_flag
	if not visible_flag:
		return
	var cuadros := _construir_cuadros_de_segmentos()
	if cuadros.is_empty():
		_grilla_preview.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for c in cuadros:
		var pts: Array = c["pts"]
		for k in range(4):
			st.add_vertex(pts[k] as Vector3)
			st.add_vertex(pts[(k + 1) % 4] as Vector3)
	_grilla_preview.mesh = st.commit()

func _crear_mesh_quad(pts: Array, tipo: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Margen interno sutil de 0.18m hacia el centro para marcar el borde entre cuadros pegados
	var centro := ((pts[0] as Vector3) + (pts[1] as Vector3) + (pts[2] as Vector3) + (pts[3] as Vector3)) * 0.25
	var p0 := (pts[0] as Vector3).lerp(centro, 0.03)
	var p1 := (pts[1] as Vector3).lerp(centro, 0.03)
	var p2 := (pts[2] as Vector3).lerp(centro, 0.03)
	var p3 := (pts[3] as Vector3).lerp(centro, 0.03)
	var nrm := (p1 - p0).cross(p2 - p0)
	if nrm.y > 0.0:
		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p0); st.add_vertex(p3); st.add_vertex(p2)
	else:
		st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(p2)
		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p3)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _materiales.get(tipo, _materiales[TipoZona.RESIDENCIAL])
	_contenedor.add_child(mi)
	return mi

func pintar_en_posicion(pos_mundo: Vector3) -> int:
	_asegurar_inicializado()
	var cuadros := _construir_cuadros_de_segmentos()
	var cambios := 0

	for c in cuadros:
		var centro: Vector3 = c["centro"]
		if Vector2(centro.x - pos_mundo.x, centro.z - pos_mundo.z).length() > radio_pincel:
			continue
		var key: String = c["key"]
		if zona_activa == TipoZona.NINGUNA:
			if _celdas.has(key):
				var old_n = _celdas[key].get("nodo")
				if is_instance_valid(old_n):
					(old_n as Node3D).queue_free()
				_celdas.erase(key)
				cambios += 1
		else:
			if _celdas.has(key):
				var cd: Dictionary = _celdas[key]
				if int(cd["tipo"]) != zona_activa:
					cd["tipo"] = zona_activa
					var mi := cd.get("nodo") as MeshInstance3D
					if is_instance_valid(mi):
						mi.material_override = _materiales.get(zona_activa, _materiales[TipoZona.RESIDENCIAL])
					cambios += 1
			else:
				var mi := _crear_mesh_quad(c["pts"], zona_activa)
				_celdas[key] = {
					"pts": c["pts"],
					"centro": centro,
					"rot_y": float(c["rot_y"]),
					"fila": int(c.get("fila", 0)),
					"tipo": zona_activa,
					"ocupada": false,
					"nodo": mi
				}
				if not _pendientes_construir.has(key):
					_pendientes_construir.append(key)
				cambios += 1
	if cambios > 0:
		zonas_actualizadas.emit(_celdas.size())
	return cambios

func finalizar_pintura() -> int:
	if not auto_construir_al_pintar or _pendientes_construir.is_empty():
		_pendientes_construir.clear()
		return 0
	var creados := _desarrollar_keys(_pendientes_construir)
	_pendientes_construir.clear()
	return creados

func desarrollar_zonas() -> int:
	var todas: Array[String] = []
	for k in _celdas.keys():
		todas.append(str(k))
	return _desarrollar_keys(todas)

func _desarrollar_keys(keys: Array[String]) -> int:
	if not controlador_objetos:
		return 0
	var creados := 0
	var presets: Array[Dictionary] = DatosCasaModular.obtener_presets()
	var paleta := ["#f4efe6", "#e8d5b7", "#d9c2a3", "#e29578", "#a8dadc", "#f2cc8f", "#d8e2dc", "#cdb4db"]

	var id_prev: String = controlador_objetos.id_objeto_seleccionado
	var cfg_prev: Dictionary = controlador_objetos.config_casa_modular_actual.duplicate(true)
	var rot_prev: float = controlador_objetos.rotacion_actual_grados
	var snap_via_prev: bool = controlador_objetos.snap_carretera_activo
	var snap_grid_prev: bool = controlador_objetos.snap_cuadricula_activo
	controlador_objetos.snap_carretera_activo = false
	controlador_objetos.snap_cuadricula_activo = false

	for key in keys:
		if not _celdas.has(key):
			continue
		var cd: Dictionary = _celdas[key]
		if bool(cd.get("ocupada", false)):
			continue
		var centro: Vector3 = cd["centro"]
		if controlador_objetos.has_method("_existe_objeto_cerca") and controlador_objetos._existe_objeto_cerca(centro, 5.2):
			cd["ocupada"] = true
			continue

		var tipo: int = int(cd.get("tipo", TipoZona.RESIDENCIAL))
		var sec_id: String = str(SECCION_POR_ZONA.get(tipo, "01_Residencial"))
		if controlador_objetos.has_method("generar_config_modular_aleatoria"):
			controlador_objetos.config_casa_modular_actual = controlador_objetos.generar_config_modular_aleatoria(sec_id, 6.8, 7.2)
		elif not presets.is_empty():
			var pr: Dictionary = presets[randi() % presets.size()]
			var cfg := DatosCasaModular.normalizar_config(pr.get("config", {}))
			cfg["color_fachada"] = paleta[randi() % paleta.size()]
			cfg["ancho"] = clampf(float(cfg.get("ancho", 6.5)), 5.8, 6.8)
			cfg["fondo"] = clampf(float(cfg.get("fondo", 6.8)), 6.0, 7.2)
			controlador_objetos.config_casa_modular_actual = cfg
		controlador_objetos.id_objeto_seleccionado = "casa_modular"

		controlador_objetos.rotacion_actual_grados = float(cd.get("rot_y", 0.0))
		var pos_spawn := centro
		pos_spawn.y = _altura_terreno(centro)
		var obj = controlador_objetos.colocar_objeto(pos_spawn)
		if obj:
			# Si la casa tiene porche/voladizo frontal, empujarla hacia atrás para no invadir la acera ni la vía
			if controlador_objetos.has_method("_calcular_aabb_objeto"):
				var aabb_l: AABB = controlador_objetos._calcular_aabb_objeto(obj)
				var frente_ext := aabb_l.position.z + aabb_l.size.z
				if frente_ext > 3.8:
					var retroceso := frente_ext - 3.6
					var fwd_w: Vector3 = obj.global_transform.basis.z
					fwd_w.y = 0.0
					if fwd_w.length_squared() > 0.001:
						obj.global_position -= fwd_w.normalized() * retroceso
						obj.global_position.y = _altura_terreno(obj.global_position)
			var r_h: float = controlador_objetos._obtener_radio_huella(obj) if controlador_objetos.has_method("_obtener_radio_huella") else 3.8
			if controlador_objetos.has_method("hay_colision_huella") and controlador_objetos.hay_colision_huella(pos_spawn, r_h, [], 0.2, obj):
				controlador_objetos.eliminar_objeto(obj)
			else:
				_crear_base_concreto_lote(cd)
				cd["ocupada"] = true
				creados += 1

	controlador_objetos.id_objeto_seleccionado = id_prev
	controlador_objetos.config_casa_modular_actual = cfg_prev
	controlador_objetos.rotacion_actual_grados = rot_prev
	controlador_objetos.snap_carretera_activo = snap_via_prev
	controlador_objetos.snap_cuadricula_activo = snap_grid_prev
	return creados

var _mat_losa_lote: StandardMaterial3D = null

func _crear_base_concreto_lote(cd: Dictionary) -> void:
	var pts: Array = cd.get("pts", [])
	if pts.size() != 4:
		return
	if not _mat_losa_lote:
		_mat_losa_lote = StandardMaterial3D.new()
		_mat_losa_lote.albedo_color = Color(0.60, 0.60, 0.58)
		_mat_losa_lote.roughness = 0.88
		_mat_losa_lote.metallic = 0.0
		_mat_losa_lote.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Extender el frente hacia la acera (-3.0m si es fila 0) y +0.25m lateral para unir lotes vecinos sin huecos
	var p0: Vector3 = pts[0]
	var p1: Vector3 = pts[1]
	var p2: Vector3 = pts[2]
	var p3: Vector3 = pts[3]
	var dir_f0 := (p0 - p3); dir_f0.y = 0.0
	dir_f0 = dir_f0.normalized() if dir_f0.length_squared() > 0.001 else Vector3.ZERO
	var dir_f1 := (p1 - p2); dir_f1.y = 0.0
	dir_f1 = dir_f1.normalized() if dir_f1.length_squared() > 0.001 else Vector3.ZERO
	var dir_lat := (p1 - p0); dir_lat.y = 0.0
	dir_lat = dir_lat.normalized() if dir_lat.length_squared() > 0.001 else Vector3.ZERO

	var ext_frente := 2.8 if int(cd.get("fila", 0)) == 0 else 0.4
	var q0 := p0 + dir_f0 * ext_frente - dir_lat * 0.25 + Vector3(0.0, 0.02, 0.0)
	var q1 := p1 + dir_f1 * ext_frente + dir_lat * 0.25 + Vector3(0.0, 0.02, 0.0)
	var q2 := p2 - dir_f1 * 0.60 + dir_lat * 0.25 + Vector3(0.0, 0.02, 0.0)
	var q3 := p3 - dir_f0 * 0.60 - dir_lat * 0.25 + Vector3(0.0, 0.02, 0.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := (q1 - q0).cross(q2 - q0)
	if nrm.y > 0.0:
		st.add_vertex(q0); st.add_vertex(q2); st.add_vertex(q1)
		st.add_vertex(q0); st.add_vertex(q3); st.add_vertex(q2)
	else:
		st.add_vertex(q0); st.add_vertex(q1); st.add_vertex(q2)
		st.add_vertex(q0); st.add_vertex(q2); st.add_vertex(q3)
	# Faldón perimetral -0.50m hacia el terreno
	var q_arr := [q0, q1, q2, q3]
	for k in range(4):
		var a: Vector3 = q_arr[k]
		var b: Vector3 = q_arr[(k + 1) % 4]
		var ba := a - Vector3(0.0, 0.50, 0.0)
		var bb := b - Vector3(0.0, 0.50, 0.0)
		st.add_vertex(a); st.add_vertex(ba); st.add_vertex(bb)
		st.add_vertex(a); st.add_vertex(bb); st.add_vertex(b)
	st.generate_normals()

	var mi := MeshInstance3D.new()
	mi.name = "LosaConcretoLote"
	mi.mesh = st.commit()
	mi.material_override = _mat_losa_lote
	_contenedor.add_child(mi)
	# Ocultar el plano verde/azul de zonificación al construir la losa de concreto
	var old_z = cd.get("nodo")
	if is_instance_valid(old_z):
		(old_z as Node3D).visible = false

func limpiar_todas() -> void:
	if is_instance_valid(_contenedor):
		for ch in _contenedor.get_children():
			ch.queue_free()
	_celdas.clear()
	_pendientes_construir.clear()
	zonas_actualizadas.emit(0)

func serializar_zonas() -> Array:
	var salida: Array = []
	for k in _celdas.keys():
		var cd: Dictionary = _celdas[k]
		var pts_arr: Array = []
		for p in cd.get("pts", []):
			var v: Vector3 = p
			pts_arr.append([v.x, v.y, v.z])
		var c: Vector3 = cd["centro"]
		salida.append({
			"k": k,
			"pts": pts_arr,
			"centro": [c.x, c.y, c.z],
			"rot_y": float(cd.get("rot_y", 0.0)),
			"tipo": int(cd.get("tipo", 1)),
			"ocupada": bool(cd.get("ocupada", false))
		})
	return salida

func deserializar_zonas(lista: Array) -> void:
	_asegurar_inicializado()
	limpiar_todas()
	for it in lista:
		if not (it is Dictionary):
			continue
		var pts: Array[Vector3] = []
		for pa in it.get("pts", []):
			if pa is Array and pa.size() >= 3:
				pts.append(Vector3(float(pa[0]), float(pa[1]), float(pa[2])))
		var ca = it.get("centro", it.get("pos", [0, 0, 0]))
		var centro := Vector3(float(ca[0]), float(ca[1]), float(ca[2]))
		if pts.size() != 4:
			var hs := 4.8
			pts = [
				centro + Vector3(-hs, 0.14, -hs),
				centro + Vector3(hs, 0.14, -hs),
				centro + Vector3(hs, 0.14, hs),
				centro + Vector3(-hs, 0.14, hs)
			]
		var tipo := int(it.get("tipo", 1))
		var rot_y := float(it.get("rot_y", 0.0))
		var key := str(it.get("k", "%d_%d" % [int(round(centro.x / 5.0)), int(round(centro.z / 5.0))]))
		var mi := _crear_mesh_quad(pts, tipo)
		_celdas[key] = {
			"pts": pts,
			"centro": centro,
			"rot_y": rot_y,
			"tipo": tipo,
			"ocupada": bool(it.get("ocupada", false)),
			"nodo": mi
		}
	zonas_actualizadas.emit(_celdas.size())
