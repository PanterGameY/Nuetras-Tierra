class_name RepositorioMapasComunidad
extends Node

## RepositorioMapasComunidad.gd — Publicación, listado y descarga (10 Esmeraldas) de mapas comunitarios en Firestore

signal mapas_cargados(lista: Array[Dictionary])
signal subida_completada(exito: bool, mensaje: String)

const COLECCION_COMUNIDAD := "mapas_comunidad"
const PRECIO_DESCARGA_ESMERALDAS := 10
const DIR_MAPAS_LOCAL := "user://mapas"
const DIR_CACHE_PC := "user://mapas_comunidad_cache"

var _conectado_fb: bool = false
var _esperando_lista: bool = false
var _esperando_subida: bool = false

func _ready() -> void:
	_conectar_firebase()

func _obtener_firestore() -> Object:
	var fb = get_node_or_null("/root/Firebase")
	if fb and "firestore" in fb and fb.firestore:
		return fb.firestore
	return null

func _tiene_plugin_activo() -> bool:
	var fb = get_node_or_null("/root/Firebase")
	if fb and "_plugin_singleton" in fb and fb._plugin_singleton != null:
		return true
	return false

func _conectar_firebase() -> void:
	if _conectado_fb:
		return
	var fs = _obtener_firestore()
	if not fs:
		return
	if fs.has_signal("get_task_completed") and not fs.get_task_completed.is_connected(_on_get_task_completed):
		fs.get_task_completed.connect(_on_get_task_completed)
	if fs.has_signal("write_task_completed") and not fs.write_task_completed.is_connected(_on_write_task_completed):
		fs.write_task_completed.connect(_on_write_task_completed)
	_conectado_fb = true

func cargar_mapas_comunidad() -> void:
	_conectar_firebase()
	var fs = _obtener_firestore()
	if fs and _tiene_plugin_activo() and fs.has_method("get_documents_in_collection"):
		_esperando_lista = true
		fs.get_documents_in_collection(COLECCION_COMUNIDAD)
	else:
		# Fallback PC/offline: leer caché local + mapas destacados base
		mapas_cargados.emit(_cargar_cache_y_destacados())

func subir_mapa(ruta_ntmap: String, categoria: String, descripcion: String) -> Dictionary:
	if not FileAccess.file_exists(ruta_ntmap):
		return {"exito": false, "mensaje": "No se encontro el archivo del mapa."}
	var f := FileAccess.open(ruta_ntmap, FileAccess.READ)
	if not f:
		return {"exito": false, "mensaje": "No se pudo leer el mapa."}
	var texto := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		return {"exito": false, "mensaje": "El archivo del mapa no es valido."}
	var datos: Dictionary = json.data

	var nombre := str(datos.get("nombre", ruta_ntmap.get_file().get_basename()))
	var autor := str(datos.get("autor", "Conductor"))
	var autor_uid := ""
	var du = get_node_or_null("/root/DatosUsuario")
	if du:
		if "nombre_usuario" in du and str(du.nombre_usuario).strip_edges() != "":
			autor = str(du.nombre_usuario)
		if "firebase_uid" in du:
			autor_uid = str(du.firebase_uid)

	var doc_id := "map_%s_%d" % [nombre.to_lower().replace(" ", "_").left(20), Time.get_unix_time_from_system()]
	for c in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "."]:
		doc_id = doc_id.replace(c, "")

	var payload := {
		"id_mapa": doc_id,
		"nombre": nombre,
		"autor": autor,
		"autor_uid": autor_uid,
		"categoria": categoria,
		"descripcion": descripcion if not descripcion.strip_edges().is_empty() else "Ruta creada por la comunidad de Nuestra Tierra.",
		"precio_esmeraldas": PRECIO_DESCARGA_ESMERALDAS,
		"num_vias": (datos.get("carreteras", []) as Array).size(),
		"num_objetos": (datos.get("objetos", []) as Array).size(),
		"descargas": 0,
		"fecha": Time.get_unix_time_from_system(),
		"datos_json": texto
	}

	# Guardar también en caché local PC para pruebas offline
	_guardar_en_cache_local(doc_id, payload)

	_conectar_firebase()
	var fs = _obtener_firestore()
	if fs and _tiene_plugin_activo() and fs.has_method("set_document"):
		_esperando_subida = true
		fs.set_document(COLECCION_COMUNIDAD, doc_id, payload, true)
		return {"exito": true, "mensaje": "Subiendo mapa a la base de datos..."}

	subida_completada.emit(true, "Mapa publicado en galeria local (modo PC).")
	return {"exito": true, "mensaje": "Mapa publicado en galeria local."}

func mapa_ya_descargado(id_mapa: String) -> bool:
	return FileAccess.file_exists(_ruta_local_comunidad(id_mapa))

func ruta_mapa_descargado(id_mapa: String) -> String:
	return _ruta_local_comunidad(id_mapa)

func comprar_y_descargar_mapa(item: Dictionary) -> Dictionary:
	var id_mapa := str(item.get("id_mapa", ""))
	if id_mapa.is_empty():
		return {"exito": false, "mensaje": "Mapa invalido."}

	var ruta_dest := _ruta_local_comunidad(id_mapa)
	if FileAccess.file_exists(ruta_dest):
		return {"exito": true, "ya_comprado": true, "ruta": ruta_dest, "mensaje": "Mapa ya guardado en Mis Mapas."}

	var precio: int = int(item.get("precio_esmeraldas", PRECIO_DESCARGA_ESMERALDAS))
	var du = get_node_or_null("/root/DatosUsuario")
	if precio > 0:
		if not du or not ("esmeraldas" in du):
			return {"exito": false, "mensaje": "No se pudo verificar tu saldo de esmeraldas."}
		if int(du.esmeraldas) < precio:
			return {"exito": false, "mensaje": "Necesitas %d esmeraldas (tienes %d)." % [precio, int(du.esmeraldas)]}
		du.esmeraldas = int(du.esmeraldas) - precio
		if du.has_method("save_local"):
			du.save_local()
		if du.has_method("sync_account_to_firebase"):
			du.sync_account_to_firebase()

	# Guardar archivo .ntmap localmente para uso permanente
	if not DirAccess.dir_exists_absolute(DIR_MAPAS_LOCAL):
		DirAccess.make_dir_recursive_absolute(DIR_MAPAS_LOCAL)

	var datos_mapa: Dictionary = {}
	var raw_json := str(item.get("datos_json", ""))
	if not raw_json.is_empty():
		var j := JSON.new()
		if j.parse(raw_json) == OK and j.data is Dictionary:
			datos_mapa = j.data
	if datos_mapa.is_empty():
		datos_mapa = {
			"formato": "NT_MAP",
			"version": 2,
			"nombre": str(item.get("nombre", "Mapa Comunidad")),
			"autor": str(item.get("autor", "Comunidad")),
			"plantilla": str(item.get("plantilla", "valle_verde")),
			"hora_dia": int(item.get("hora", 12)),
			"objetos": [],
			"vegetacion_multimesh": {},
			"carreteras": [],
			"equipamiento_vias": [],
			"cuerpos_agua": [],
			"spawn": {"posicion": [0.0, 0.2, 0.0], "rotacion_y": 0.0, "modo": "vehiculo"}
		}
	datos_mapa["comprado_comunidad"] = true
	datos_mapa["id_comunidad"] = id_mapa

	var fw := FileAccess.open(ruta_dest, FileAccess.WRITE)
	if not fw:
		return {"exito": false, "mensaje": "Error al guardar el mapa en tu dispositivo."}
	fw.store_string(JSON.stringify(datos_mapa, "  "))
	fw.close()

	return {
		"exito": true,
		"ya_comprado": false,
		"ruta": ruta_dest,
		"mensaje": "Mapa descargado por %d esmeraldas y guardado en Mis Mapas." % precio
	}

func _ruta_local_comunidad(id_mapa: String) -> String:
	return "%s/com_%s.ntmap" % [DIR_MAPAS_LOCAL, id_mapa]

func _on_write_task_completed(result: Dictionary) -> void:
	if not _esperando_subida:
		return
	_esperando_subida = false
	var ok: bool = bool(result.get("success", true))
	subida_completada.emit(ok, "Mapa subido a la comunidad!" if ok else "Error al subir mapa.")

func _on_get_task_completed(result: Dictionary) -> void:
	if not _esperando_lista:
		return
	_esperando_lista = false
	var lista: Array[Dictionary] = []
	var docs = result.get("documents", result.get("data", []))
	if docs is Array:
		for d in docs:
			if d is Dictionary:
				lista.append(_normalizar_doc_comunidad(d))
	elif docs is Dictionary:
		for k in docs.keys():
			var val = docs[k]
			if val is Dictionary:
				var item := _normalizar_doc_comunidad(val)
				if str(item.get("id_mapa", "")).is_empty():
					item["id_mapa"] = str(k)
				lista.append(item)

	# Combinar con destacados locales si la colección aún tiene pocos elementos
	for dest in _cargar_cache_y_destacados():
		var ya := false
		for ex in lista:
			if ex["id_mapa"] == dest["id_mapa"]:
				ya = true
				break
		if not ya:
			lista.append(dest)

	mapas_cargados.emit(lista)

func _normalizar_doc_comunidad(d: Dictionary) -> Dictionary:
	return {
		"id_mapa": str(d.get("id_mapa", d.get("id", ""))),
		"nombre": str(d.get("nombre", "Mapa Comunidad")),
		"autor": str(d.get("autor", "Conductor")),
		"categoria": str(d.get("categoria", "Sierra")),
		"descripcion": str(d.get("descripcion", "Ruta compartida por la comunidad.")),
		"precio_esmeraldas": int(d.get("precio_esmeraldas", PRECIO_DESCARGA_ESMERALDAS)),
		"num_vias": int(d.get("num_vias", 0)),
		"num_objetos": int(d.get("num_objetos", 0)),
		"datos_json": str(d.get("datos_json", ""))
	}

func _guardar_en_cache_local(doc_id: String, payload: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(DIR_CACHE_PC):
		DirAccess.make_dir_recursive_absolute(DIR_CACHE_PC)
	var f := FileAccess.open("%s/%s.json" % [DIR_CACHE_PC, doc_id], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "  "))
		f.close()

func _cargar_cache_y_destacados() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if DirAccess.dir_exists_absolute(DIR_CACHE_PC):
		var dir := DirAccess.open(DIR_CACHE_PC)
		if dir:
			dir.list_dir_begin()
			var fn := dir.get_next()
			while fn != "":
				if not dir.current_is_dir() and fn.ends_with(".json"):
					var f := FileAccess.open(DIR_CACHE_PC + "/" + fn, FileAccess.READ)
					if f:
						var j := JSON.new()
						if j.parse(f.get_as_text()) == OK and j.data is Dictionary:
							lista.append(_normalizar_doc_comunidad(j.data))
						f.close()
				fn = dir.get_next()
			dir.list_dir_end()

	# Mapas base comunitarios de muestra
	var muestras := [
		{
			"id_mapa": "com_ruta_cafe",
			"nombre": "Ruta del Cafe",
			"autor": "Equipo Nuestra Tierra",
			"categoria": "Sierra",
			"descripcion": "Tramo sinuoso de doble calzada con miradores y curvas amplias.",
			"precio_esmeraldas": PRECIO_DESCARGA_ESMERALDAS,
			"num_vias": 4,
			"num_objetos": 18,
			"plantilla": "paso_montana",
			"hora": 16
		},
		{
			"id_mapa": "com_distrito_central",
			"nombre": "Distrito Central",
			"autor": "Equipo Nuestra Tierra",
			"categoria": "Urbano",
			"descripcion": "Base urbana con avenida de 4 carriles, aceras y rotonda central.",
			"precio_esmeraldas": PRECIO_DESCARGA_ESMERALDAS,
			"num_vias": 6,
			"num_objetos": 32,
			"plantilla": "valle_verde",
			"hora": 10
		},
		{
			"id_mapa": "com_autopista_llano",
			"nombre": "Autopista del Llano",
			"autor": "Comunidad NT",
			"categoria": "Autopista",
			"descripcion": "Larga recta de alta velocidad ideal para probar tractomulas.",
			"precio_esmeraldas": PRECIO_DESCARGA_ESMERALDAS,
			"num_vias": 3,
			"num_objetos": 12,
			"plantilla": "lienzo_blanco",
			"hora": 14
		}
	]
	for m in muestras:
		lista.append(m)
	return lista
