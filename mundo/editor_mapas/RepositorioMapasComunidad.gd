class_name RepositorioMapasComunidad
extends Node

## RepositorioMapasComunidad.gd — Publicación (100 Esmeraldas), listado ligero en Supabase,
## descarga (10 Esmeraldas -> +1 al creador) y Biblioteca local.

signal mapas_cargados(lista: Array[Dictionary])
signal subida_completada(exito: bool, mensaje: String)

const TABLA_SUPABASE := "mapas_comunidad"
const PRECIO_DESCARGA_ESMERALDAS := 10
const PRECIO_SUBIDA_ESMERALDAS := 100
const RECOMPENSA_CREADOR_DESCARGA := 1
const MAX_BYTES_PAQUETE := 5242880 # 5 MB máx. comprimido
const LIMITE_PAGINA := 20
const DIR_MAPAS_LOCAL := "user://mapas"
const DIR_CACHE_PC := "user://mapas_comunidad_cache"
const DIR_CACHE_PORTADAS := "user://mapas_comunidad_cache/portadas"

var _portadas_cache_mem: Dictionary = {}

func _obtener_supabase_url() -> String:
	var sm := get_node_or_null("/root/SupabaseManager")
	if sm and "SUPABASE_URL" in sm:
		return str(sm.SUPABASE_URL)
	return "https://hndlwmvezampajbmpqae.supabase.co"

func _obtener_supabase_key() -> String:
	var sm := get_node_or_null("/root/SupabaseManager")
	if sm and "SUPABASE_KEY" in sm:
		return str(sm.SUPABASE_KEY)
	return "sb_publishable_Cw95N8YDQNhc4zDGTE__Yg_C_Xj0IP4"

func _obtener_headers_supabase(extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var key := _obtener_supabase_key()
	var headers := PackedStringArray([
		"apikey: " + key,
		"Content-Type: application/json"
	])
	var sm := get_node_or_null("/root/SupabaseManager")
	if sm and "access_token" in sm:
		var tok := str(sm.access_token).strip_edges()
		if not tok.is_empty():
			headers.append("Authorization: Bearer " + tok)
	elif key.contains("."):
		headers.append("Authorization: Bearer " + key)
	for h in extra:
		headers.append(h)
	return headers

func _leer_texto_ntmap(ruta: String) -> String:
	var f_comp := FileAccess.open_compressed(ruta, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f_comp:
		var txt_c := f_comp.get_as_text()
		f_comp.close()
		if txt_c.strip_edges().begins_with("{"):
			return txt_c
	var f_plain := FileAccess.open(ruta, FileAccess.READ)
	if f_plain:
		var txt_p := f_plain.get_as_text()
		f_plain.close()
		return txt_p
	return ""

func buscar_mapa_por_nombre_async(nombre_mapa: String, callback: Callable) -> void:
	var objetivo := nombre_mapa.strip_edges()
	if objetivo.is_empty():
		callback.call({})
		return
	var campos := "id,id_mapa,nombre,autor,autor_uid,categoria,descripcion,portada_url,num_vias,num_objetos,descargas,fecha,tamano_bytes"
	var url := "%s/rest/v1/%s?select=%s&nombre=ilike.%s&limit=1" % [
		_obtener_supabase_url(), TABLA_SUPABASE, campos, objetivo.uri_encode()
	]
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if res == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300:
			var j := JSON.new()
			if j.parse(body.get_string_from_utf8()) == OK and j.data is Array and not (j.data as Array).is_empty():
				var d = (j.data as Array)[0]
				if d is Dictionary:
					callback.call(_normalizar_doc_comunidad(d))
					return
		callback.call({})
	)
	var err := http.request(url, _obtener_headers_supabase(), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		callback.call({})

func cargar_mapas_comunidad(offset: int = 0, limite: int = LIMITE_PAGINA) -> void:
	# Consulta ligera: solo metadatos (sin descargar ntmap_b64 ni terreno_zip_b64 hasta que el jugador compre/descargue)
	var campos := "id,id_mapa,nombre,autor,autor_uid,categoria,descripcion,portada_url,num_vias,num_objetos,descargas,fecha,tamano_bytes"
	var url := "%s/rest/v1/%s?select=%s&order=fecha.desc&limit=%d&offset=%d" % [_obtener_supabase_url(), TABLA_SUPABASE, campos, limite, offset]
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		var lista: Array[Dictionary] = []
		if res == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300:
			var j := JSON.new()
			if j.parse(body.get_string_from_utf8()) == OK and j.data is Array:
				for d in j.data:
					if d is Dictionary:
						lista.append(_normalizar_doc_comunidad(d))
		mapas_cargados.emit(lista)
	)
	var err := http.request(url, _obtener_headers_supabase(), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		var vacia: Array[Dictionary] = []
		mapas_cargados.emit(vacia)

func cargar_estadisticas_creador_async(callback: Callable) -> void:
	var du = get_node_or_null("/root/DatosUsuario")
	var sm = get_node_or_null("/root/SupabaseManager")
	var autor_uid := ""
	var autor := ""
	if du:
		if "supabase_uid" in du:
			autor_uid = str(du.supabase_uid).strip_edges()
		if "nombre_usuario" in du:
			autor = str(du.nombre_usuario).strip_edges()
	if autor_uid.is_empty() and sm and "user_id" in sm:
		autor_uid = str(sm.user_id).strip_edges()

	var filtro := ""
	if not autor_uid.is_empty():
		filtro = "autor_uid=eq.%s" % autor_uid.uri_encode()
	elif not autor.is_empty():
		filtro = "autor=eq.%s" % autor.uri_encode()
	else:
		callback.call({"exito": false, "mapas": [], "mensaje": "Inicia sesión para ver tus estadísticas de creador."})
		return

	var campos := "id,id_mapa,nombre,autor,autor_uid,categoria,num_vias,num_objetos,descargas,fecha,tamano_bytes"
	var url := "%s/rest/v1/%s?select=%s&%s&order=descargas.desc,fecha.desc" % [
		_obtener_supabase_url(), TABLA_SUPABASE, campos, filtro
	]
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
			callback.call({"exito": false, "mapas": [], "mensaje": "Error al consultar estadísticas (%d)." % status})
			return
		var lista: Array[Dictionary] = []
		var j := JSON.new()
		if j.parse(body.get_string_from_utf8()) == OK and j.data is Array:
			for d in j.data:
				if d is Dictionary:
					lista.append(_normalizar_doc_comunidad(d))
		callback.call({"exito": true, "mapas": lista, "mensaje": ""})
	)
	var err := http.request(url, _obtener_headers_supabase(), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		callback.call({"exito": false, "mapas": [], "mensaje": "No se pudo conectar con Supabase."})

func _empaquetar_terreno_zip_b64(dir_terreno: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(dir_terreno):
		return {"b64": "", "bytes": 0}
	var d := DirAccess.open(dir_terreno)
	if not d:
		return {"b64": "", "bytes": 0}
	var archivos: Array[String] = []
	var peso_res_total := 0
	for fn in d.get_files():
		if fn.ends_with(".res"):
			archivos.append(fn)
			peso_res_total += FileAccess.get_file_as_bytes(dir_terreno + "/" + fn).size()
	# Si es un único cuadro plano sin esculpir (<= 10 KB), omitir subida de terreno para ahorrar 95% de espacio
	if archivos.is_empty() or (archivos.size() == 1 and peso_res_total <= 10240):
		return {"b64": "", "bytes": 0}

	var zip_path := "user://_tmp_terreno_upload.zip"
	var zp := ZIPPacker.new()
	if zp.open(zip_path) != OK:
		return {"b64": "", "bytes": 0}
	for fn in archivos:
		var bytes := FileAccess.get_file_as_bytes(dir_terreno + "/" + fn)
		if not bytes.is_empty():
			zp.start_file(fn)
			zp.write_file(bytes)
			zp.close_file()
	zp.close()
	var zip_bytes := FileAccess.get_file_as_bytes(zip_path)
	DirAccess.remove_absolute(zip_path)
	if zip_bytes.is_empty():
		return {"b64": "", "bytes": 0}
	return {"b64": Marshalls.raw_to_base64(zip_bytes), "bytes": zip_bytes.size()}

func _generar_identificador_mapa() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%d.map" % rng.randi_range(100, 9999)

func subir_mapa(ruta_ntmap: String, categoria: String, descripcion: String, portada_url: String = "") -> Dictionary:
	if not FileAccess.file_exists(ruta_ntmap):
		return {"exito": false, "mensaje": "No se encontró el archivo del mapa."}

	var du = get_node_or_null("/root/DatosUsuario")
	if not du or not ("pases_mapa" in du):
		return {"exito": false, "mensaje": "No se pudo verificar tus Pases de Mapa."}
	if int(du.pases_mapa) < 1:
		return {"exito": false, "mensaje": "Necesitas 1 Pase de Mapa para publicar. Cómpralo en la Tienda (100 Esmeraldas)."}

	var texto := _leer_texto_ntmap(ruta_ntmap)
	if texto.is_empty():
		return {"exito": false, "mensaje": "No se pudo leer el archivo del mapa."}

	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		return {"exito": false, "mensaje": "El archivo del mapa no es válido."}
	var datos: Dictionary = json.data

	var ntmap_bytes := FileAccess.get_file_as_bytes(ruta_ntmap)
	var terr_res := _empaquetar_terreno_zip_b64(ruta_ntmap.get_basename() + "_terreno")
	var tamano_total_bytes: int = ntmap_bytes.size() + int(terr_res.get("bytes", 0))
	if tamano_total_bytes > MAX_BYTES_PAQUETE:
		return {"exito": false, "mensaje": "El mapa supera el límite de 5 MB comprimido (%s)." % _formatear_peso(tamano_total_bytes)}

	var nombre := str(datos.get("nombre", ruta_ntmap.get_file().get_basename()))
	var autor := str(datos.get("autor", "Conductor"))
	var autor_uid := ""
	if "nombre_usuario" in du and str(du.nombre_usuario).strip_edges() != "":
		autor = str(du.nombre_usuario)
	if "supabase_uid" in du and str(du.supabase_uid) != "":
		autor_uid = str(du.supabase_uid)
	var sm := get_node_or_null("/root/SupabaseManager")
	if autor_uid.is_empty() and sm and "user_id" in sm:
		autor_uid = str(sm.user_id)

	var doc_id := _generar_identificador_mapa()
	var ntmap_b64 := Marshalls.raw_to_base64(ntmap_bytes)
	var terreno_zip_b64 := str(terr_res.get("b64", ""))
	var portada_limpia := portada_url.strip_edges()

	var vias_arr: Array = datos.get("carreteras", []) if datos.get("carreteras") is Array else []
	var objs_arr: Array = datos.get("objetos", []) if datos.get("objetos") is Array else []
	var payload := {
		"id_mapa": doc_id,
		"nombre": nombre,
		"autor": autor,
		"autor_uid": autor_uid,
		"categoria": categoria,
		"descripcion": descripcion.strip_edges() if not descripcion.strip_edges().is_empty() else "Ruta publicada por la comunidad de Nuestra Tierra.",
		"portada_url": portada_limpia,
		"num_vias": vias_arr.size(),
		"num_objetos": objs_arr.size(),
		"descargas": 0,
		"fecha": int(Time.get_unix_time_from_system()),
		"tamano_bytes": tamano_total_bytes,
		"ntmap_b64": ntmap_b64,
		"terreno_zip_b64": terreno_zip_b64
	}

	var url := "%s/rest/v1/%s" % [_obtener_supabase_url(), TABLA_SUPABASE]
	var http := HTTPRequest.new()
	http.timeout = 25.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _hdrs: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		if res == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300:
			du.pases_mapa = maxi(0, int(du.pases_mapa) - 1)
			if du.has_method("save_local"):
				du.save_local()
			_guardar_en_cache_local(doc_id, payload)
			subida_completada.emit(true, "¡Mapa publicado (-1 Pase de Mapa)! ID: %s" % doc_id)
		else:
			var err_txt := resp_body.get_string_from_utf8().left(220)
			push_warning("[RepositorioMapasComunidad] Supabase POST %d (res=%d): %s" % [status, res, err_txt])
			subida_completada.emit(false, "Error al publicar en Supabase (%d): %s" % [status, err_txt if not err_txt.is_empty() else "Sin respuesta"])
	)
	var headers := _obtener_headers_supabase(PackedStringArray(["Prefer: return=minimal"]))
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		subida_completada.emit(false, "No se pudo conectar con Supabase (código %d)." % err)
		return {"exito": false, "mensaje": "Error de conexión al publicar."}

	return {"exito": true, "mensaje": "Publicando mapa en la nube..."}

func mapa_ya_descargado(id_mapa: String) -> bool:
	return FileAccess.file_exists(_ruta_local_comunidad(id_mapa))

func ruta_mapa_descargado(id_mapa: String) -> String:
	return _ruta_local_comunidad(id_mapa)

func descargar_y_preparar_async(item: Dictionary, callback: Callable) -> void:
	var id_mapa := str(item.get("id_mapa", ""))
	if id_mapa.is_empty():
		callback.call({"exito": false, "mensaje": "Mapa inválido."})
		return

	# Si ya está en la biblioteca local, abrir directo sin cobrar ni descargar
	if mapa_ya_descargado(id_mapa):
		callback.call(preparar_mapa_para_jugar(item))
		return

	# Verificar saldo antes de descargar
	var du = get_node_or_null("/root/DatosUsuario")
	if not du or not ("esmeraldas" in du):
		callback.call({"exito": false, "mensaje": "No se pudo verificar tu saldo de esmeraldas."})
		return
	if int(du.esmeraldas) < PRECIO_DESCARGA_ESMERALDAS:
		callback.call({"exito": false, "mensaje": "Necesitas %d esmeraldas para descargar este mapa (tienes %d)." % [PRECIO_DESCARGA_ESMERALDAS, int(du.esmeraldas)]})
		return

	# Si el item ya trae el payload completo, preparar de inmediato
	if not str(item.get("ntmap_b64", "")).is_empty() or not str(item.get("datos_json", "")).is_empty():
		var res_dir := preparar_mapa_para_jugar(item)
		if res_dir.get("exito", false):
			_registrar_descarga_en_supabase(id_mapa)
		callback.call(res_dir)
		return

	# Descargar únicamente el payload de este mapa desde Supabase
	var url := "%s/rest/v1/%s?select=ntmap_b64,terreno_zip_b64&id_mapa=eq.%s&limit=1" % [
		_obtener_supabase_url(), TABLA_SUPABASE, id_mapa.uri_encode()
	]
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
			push_warning("[RepositorioMapasComunidad] Supabase GET descarga %d: %s" % [status, body.get_string_from_utf8().left(160)])
			callback.call({"exito": false, "mensaje": "Error al descargar el mapa (%d)." % status})
			return
		var j := JSON.new()
		if j.parse(body.get_string_from_utf8()) != OK or not (j.data is Array) or (j.data as Array).is_empty():
			callback.call({"exito": false, "mensaje": "No se encontraron los datos del mapa en el servidor."})
			return
		var fila: Dictionary = j.data[0]
		var item_completo := item.duplicate()
		item_completo["ntmap_b64"] = str(fila.get("ntmap_b64", ""))
		item_completo["terreno_zip_b64"] = str(fila.get("terreno_zip_b64", ""))
		var res_prep := preparar_mapa_para_jugar(item_completo)
		if res_prep.get("exito", false):
			_registrar_descarga_en_supabase(id_mapa)
		callback.call(res_prep)
	)
	var err := http.request(url, _obtener_headers_supabase(), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		callback.call({"exito": false, "mensaje": "No se pudo conectar con el servidor."})

func _registrar_descarga_en_supabase(id_mapa: String) -> void:
	# Llama a la función RPC de Supabase para sumar +1 descarga y acreditar +1 esmeralda al creador
	var url := "%s/rest/v1/rpc/registrar_descarga_mapa" % _obtener_supabase_url()
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(_r: int, _s: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
	)
	http.request(url, _obtener_headers_supabase(), HTTPClient.METHOD_POST, JSON.stringify({"p_id_mapa": id_mapa}))

func preparar_mapa_para_jugar(item: Dictionary) -> Dictionary:
	var id_mapa := str(item.get("id_mapa", ""))
	if id_mapa.is_empty():
		return {"exito": false, "mensaje": "Mapa inválido."}

	if not DirAccess.dir_exists_absolute(DIR_MAPAS_LOCAL):
		DirAccess.make_dir_recursive_absolute(DIR_MAPAS_LOCAL)

	var ruta_dest := _ruta_local_comunidad(id_mapa)
	var ya_en_biblioteca := FileAccess.file_exists(ruta_dest)

	if not ya_en_biblioteca:
		var du = get_node_or_null("/root/DatosUsuario")
		if not du or not ("esmeraldas" in du):
			return {"exito": false, "mensaje": "No se pudo verificar tu saldo de esmeraldas."}
		if int(du.esmeraldas) < PRECIO_DESCARGA_ESMERALDAS:
			return {"exito": false, "mensaje": "Necesitas %d esmeraldas para descargar este mapa (tienes %d)." % [PRECIO_DESCARGA_ESMERALDAS, int(du.esmeraldas)]}
		du.esmeraldas = int(du.esmeraldas) - PRECIO_DESCARGA_ESMERALDAS
		if du.has_method("save_local"):
			du.save_local()
		var sm := get_node_or_null("/root/SupabaseManager")
		if sm and sm.has_method("guardar_perfil") and "access_token" in sm and not str(sm.access_token).is_empty():
			sm.guardar_perfil({"esmeraldas": int(du.esmeraldas)})

	var ntmap_b64 := str(item.get("ntmap_b64", ""))
	var raw_json := str(item.get("datos_json", ""))

	if not ntmap_b64.is_empty():
		var bytes := Marshalls.base64_to_raw(ntmap_b64)
		if not bytes.is_empty():
			var fw := FileAccess.open(ruta_dest, FileAccess.WRITE)
			if fw:
				fw.store_buffer(bytes)
				fw.close()
	elif not raw_json.is_empty():
		var fw_c := FileAccess.open_compressed(ruta_dest, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if not fw_c:
			fw_c = FileAccess.open(ruta_dest, FileAccess.WRITE)
		if fw_c:
			fw_c.store_string(raw_json)
			fw_c.close()

	var tz_b64 := str(item.get("terreno_zip_b64", ""))
	if not tz_b64.is_empty():
		var zip_bytes := Marshalls.base64_to_raw(tz_b64)
		if not zip_bytes.is_empty():
			var tmp_zip := "user://_tmp_terreno_dl.zip"
			var fz := FileAccess.open(tmp_zip, FileAccess.WRITE)
			if fz:
				fz.store_buffer(zip_bytes)
				fz.close()
				var zr := ZIPReader.new()
				if zr.open(tmp_zip) == OK:
					var dir_terr := ruta_dest.get_basename() + "_terreno"
					DirAccess.make_dir_recursive_absolute(dir_terr)
					for fn in zr.get_files():
						var f_out := FileAccess.open(dir_terr + "/" + fn, FileAccess.WRITE)
						if f_out:
							f_out.store_buffer(zr.read_file(fn))
							f_out.close()
					zr.close()
				DirAccess.remove_absolute(tmp_zip)

	if not FileAccess.file_exists(ruta_dest):
		return {"exito": false, "mensaje": "No se pudo guardar el archivo del mapa."}

	var meta_path := ruta_dest.get_basename() + ".meta.json"
	var fm := FileAccess.open(meta_path, FileAccess.WRITE)
	if fm:
		fm.store_string(JSON.stringify({
			"id_mapa": id_mapa,
			"codigo_id": str(item.get("codigo_id", id_mapa)),
			"nombre": str(item.get("nombre", "Mapa Comunidad")),
			"autor": str(item.get("autor", "Conductor")),
			"categoria": str(item.get("categoria", "Urbano")),
			"descripcion": str(item.get("descripcion", "")),
			"portada_url": str(item.get("portada_url", "")),
			"peso_texto": str(item.get("peso_texto", "Ligero"))
		}))
		fm.close()

	return {
		"exito": true,
		"ya_en_biblioteca": ya_en_biblioteca,
		"ruta": ruta_dest,
		"nombre": str(item.get("nombre", "Mapa Comunidad")),
		"mensaje": "¡Abriendo mapa!" if ya_en_biblioteca else ("Mapa descargado (-%d Esmeraldas) y guardado en tu Biblioteca." % PRECIO_DESCARGA_ESMERALDAS)
	}

func listar_biblioteca_local() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(DIR_MAPAS_LOCAL):
		return res
	var dir := DirAccess.open(DIR_MAPAS_LOCAL)
	if not dir:
		return res
	for fn in dir.get_files():
		if fn.begins_with("com_") and fn.ends_with(".ntmap"):
			var ruta := DIR_MAPAS_LOCAL + "/" + fn
			var meta_path := ruta.get_basename() + ".meta.json"
			var info: Dictionary = {
				"id_mapa": fn.trim_prefix("com_").trim_suffix(".ntmap"),
				"codigo_id": fn.trim_prefix("com_").trim_suffix(".ntmap") + ".map",
				"nombre": fn.trim_prefix("com_").trim_suffix(".ntmap").capitalize(),
				"autor": "Comunidad",
				"categoria": "Urbano",
				"descripcion": "Mapa guardado en tu biblioteca.",
				"portada_url": "",
				"peso_texto": _formatear_peso(FileAccess.get_file_as_bytes(ruta).size()),
				"ruta": ruta
			}
			if FileAccess.file_exists(meta_path):
				var fm := FileAccess.open(meta_path, FileAccess.READ)
				if fm:
					var j := JSON.new()
					if j.parse(fm.get_as_text()) == OK and j.data is Dictionary:
						for k in j.data.keys():
							info[k] = j.data[k]
					fm.close()
			info["ruta"] = ruta
			res.append(info)
	return res

func descargar_portada_async(url_portada: String, callback: Callable) -> void:
	var url := url_portada.strip_edges()
	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		return
	if _portadas_cache_mem.has(url):
		callback.call(_portadas_cache_mem[url])
		return

	var hash_id := str(url.hash())
	var ruta_cache := "%s/%s.png" % [DIR_CACHE_PORTADAS, hash_id]
	if FileAccess.file_exists(ruta_cache):
		var img_c := Image.new()
		if img_c.load(ruta_cache) == OK:
			var tex_c := ImageTexture.create_from_image(img_c)
			_portadas_cache_mem[url] = tex_c
			callback.call(tex_c)
			return

	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _hdrs: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300 or body.is_empty():
			return
		var img := _decodificar_imagen(body)
		if img == null or img.is_empty():
			return
		if not DirAccess.dir_exists_absolute(DIR_CACHE_PORTADAS):
			DirAccess.make_dir_recursive_absolute(DIR_CACHE_PORTADAS)
		img.save_png(ruta_cache)
		var tex := ImageTexture.create_from_image(img)
		_portadas_cache_mem[url] = tex
		if callback.is_valid():
			callback.call(tex)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _decodificar_imagen(body: PackedByteArray) -> Image:
	var img := Image.new()
	if img.load_png_from_buffer(body) == OK:
		return img
	if img.load_jpg_from_buffer(body) == OK:
		return img
	if img.load_webp_from_buffer(body) == OK:
		return img
	return null

func _ruta_local_comunidad(id_mapa: String) -> String:
	var limpio := id_mapa.replace(".map", "")
	return "%s/com_%s.ntmap" % [DIR_MAPAS_LOCAL, limpio]

func _formatear_peso(bytes: int) -> String:
	if bytes <= 0:
		return "Ligero"
	if bytes >= 1048576:
		return "%.1f MB" % (float(bytes) / 1048576.0)
	return "%d KB" % maxi(1, int(round(float(bytes) / 1024.0)))

func _normalizar_doc_comunidad(d: Dictionary) -> Dictionary:
	var nt_b64 := str(d.get("ntmap_b64", ""))
	var tz_b64 := str(d.get("terreno_zip_b64", ""))
	var d_json := str(d.get("datos_json", ""))
	var peso_b: int = int(d.get("tamano_bytes", 0))
	if peso_b <= 0:
		peso_b = int((nt_b64.length() * 3) / 4) + int((tz_b64.length() * 3) / 4)
	if peso_b <= 0:
		peso_b = d_json.length()
	var id_m := str(d.get("id_mapa", d.get("id", "")))
	var id_db := str(d.get("id", ""))
	var codigo_id := id_m if id_m.ends_with(".map") else ("%s.map" % id_db if not id_db.is_empty() else id_m)
	return {
		"id_mapa": id_m,
		"id_db": id_db,
		"codigo_id": codigo_id,
		"nombre": str(d.get("nombre", "Mapa Comunidad")),
		"autor": str(d.get("autor", "Conductor")),
		"autor_uid": str(d.get("autor_uid", "")),
		"categoria": str(d.get("categoria", "Urbano")),
		"descripcion": str(d.get("descripcion", "Ruta compartida por la comunidad.")),
		"portada_url": str(d.get("portada_url", "")),
		"peso_texto": _formatear_peso(peso_b),
		"descargas": int(d.get("descargas", 0)),
		"num_vias": int(d.get("num_vias", 0)),
		"num_objetos": int(d.get("num_objetos", 0)),
		"ntmap_b64": nt_b64,
		"terreno_zip_b64": tz_b64,
		"datos_json": d_json
	}

func _guardar_en_cache_local(doc_id: String, payload: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(DIR_CACHE_PC):
		DirAccess.make_dir_recursive_absolute(DIR_CACHE_PC)
	var f := FileAccess.open("%s/%s.json" % [DIR_CACHE_PC, doc_id], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload))
		f.close()
