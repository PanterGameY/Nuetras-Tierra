class_name RepositorioMapasComunidad
extends Node

## RepositorioMapasComunidad.gd — Publicación, listado en Supabase y descarga para jugar en "Descubrir"

signal mapas_cargados(lista: Array[Dictionary])
signal subida_completada(exito: bool, mensaje: String)

const TABLA_SUPABASE := "mapas_comunidad"
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
	var token := key
	var sm := get_node_or_null("/root/SupabaseManager")
	if sm and "access_token" in sm and not str(sm.access_token).is_empty():
		token = str(sm.access_token)
	var headers := PackedStringArray([
		"apikey: " + key,
		"Authorization: Bearer " + token,
		"Content-Type: application/json"
	])
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

func cargar_mapas_comunidad() -> void:
	var url := "%s/rest/v1/%s?select=*&order=fecha.desc&limit=60" % [_obtener_supabase_url(), TABLA_SUPABASE]
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

func _empaquetar_terreno_zip_b64(dir_terreno: String) -> String:
	if not DirAccess.dir_exists_absolute(dir_terreno):
		return ""
	var d := DirAccess.open(dir_terreno)
	if not d:
		return ""
	var archivos: Array[String] = []
	for fn in d.get_files():
		if fn.ends_with(".res"):
			archivos.append(fn)
	if archivos.is_empty():
		return ""
	var zip_path := "user://_tmp_terreno_upload.zip"
	var zp := ZIPPacker.new()
	if zp.open(zip_path) != OK:
		return ""
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
		return ""
	return Marshalls.raw_to_base64(zip_bytes)

func _generar_identificador_mapa() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%d.map" % rng.randi_range(100, 9999)

func subir_mapa(ruta_ntmap: String, categoria: String, descripcion: String, portada_url: String = "") -> Dictionary:
	if not FileAccess.file_exists(ruta_ntmap):
		return {"exito": false, "mensaje": "No se encontró el archivo del mapa."}
	var texto := _leer_texto_ntmap(ruta_ntmap)
	if texto.is_empty():
		return {"exito": false, "mensaje": "No se pudo leer el archivo del mapa."}

	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		return {"exito": false, "mensaje": "El archivo del mapa no es válido."}
	var datos: Dictionary = json.data

	var nombre := str(datos.get("nombre", ruta_ntmap.get_file().get_basename()))
	var autor := str(datos.get("autor", "Conductor"))
	var autor_uid := ""
	var du = get_node_or_null("/root/DatosUsuario")
	if du:
		if "nombre_usuario" in du and str(du.nombre_usuario).strip_edges() != "":
			autor = str(du.nombre_usuario)
		if "supabase_uid" in du and str(du.supabase_uid) != "":
			autor_uid = str(du.supabase_uid)
	var sm := get_node_or_null("/root/SupabaseManager")
	if autor_uid.is_empty() and sm and "user_id" in sm:
		autor_uid = str(sm.user_id)

	var doc_id := _generar_identificador_mapa()

	var ntmap_bytes := FileAccess.get_file_as_bytes(ruta_ntmap)
	var ntmap_b64 := Marshalls.raw_to_base64(ntmap_bytes)
	var terreno_zip_b64 := _empaquetar_terreno_zip_b64(ruta_ntmap.get_basename() + "_terreno")
	var portada_limpia := portada_url.strip_edges()

	var payload := {
		"id_mapa": doc_id,
		"nombre": nombre,
		"autor": autor,
		"autor_uid": autor_uid,
		"categoria": categoria,
		"descripcion": descripcion.strip_edges() if not descripcion.strip_edges().is_empty() else "Ruta publicada por la comunidad de Nuestra Tierra.",
		"portada_url": portada_limpia,
		"num_vias": (datos.get("carreteras", []) as Array).size(),
		"num_objetos": (datos.get("objetos", []) as Array).size(),
		"descargas": 0,
		"fecha": int(Time.get_unix_time_from_system()),
		"ntmap_b64": ntmap_b64,
		"terreno_zip_b64": terreno_zip_b64
	}

	_guardar_en_cache_local(doc_id, payload)

	var url := "%s/rest/v1/%s" % [_obtener_supabase_url(), TABLA_SUPABASE]
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.request_completed.connect(func(res: int, status: int, _hdrs: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		if res == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300:
			subida_completada.emit(true, "¡Mapa publicado en Descubrir! ID: %s" % doc_id)
		else:
			var err_txt := resp_body.get_string_from_utf8().left(140)
			push_warning("[RepositorioMapasComunidad] Supabase POST %d: %s" % [status, err_txt])
			subida_completada.emit(true, "Guardado localmente (error Supabase %d)." % status)
	)
	var headers := _obtener_headers_supabase(PackedStringArray(["Prefer: return=minimal"]))
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		subida_completada.emit(true, "Mapa publicado en caché local.")
		return {"exito": true, "mensaje": "Mapa guardado localmente."}

	return {"exito": true, "mensaje": "Publicando mapa en Supabase..."}

func mapa_ya_descargado(id_mapa: String) -> bool:
	return FileAccess.file_exists(_ruta_local_comunidad(id_mapa))

func ruta_mapa_descargado(id_mapa: String) -> String:
	return _ruta_local_comunidad(id_mapa)

func preparar_mapa_para_jugar(item: Dictionary) -> Dictionary:
	var id_mapa := str(item.get("id_mapa", ""))
	if id_mapa.is_empty():
		return {"exito": false, "mensaje": "Mapa inválido."}

	if not DirAccess.dir_exists_absolute(DIR_MAPAS_LOCAL):
		DirAccess.make_dir_recursive_absolute(DIR_MAPAS_LOCAL)

	var ruta_dest := _ruta_local_comunidad(id_mapa)
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
	elif str(item.get("ruta_local_defecto", "")) != "" and FileAccess.file_exists(str(item.get("ruta_local_defecto", ""))):
		var bytes_def := FileAccess.get_file_as_bytes(str(item.get("ruta_local_defecto", "")))
		var fw_d := FileAccess.open(ruta_dest, FileAccess.WRITE)
		if fw_d and not bytes_def.is_empty():
			fw_d.store_buffer(bytes_def)
			fw_d.close()

	# Extraer terreno ZIP si viene incluido desde Supabase
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
	elif id_mapa == "ciudad_prueba_grande":
		# Si es la ciudad destacada por defecto, copiar su carpeta de terreno local si existe
		var dir_src := DIR_MAPAS_LOCAL + "/ciudad_prueba_grande_terreno"
		var dir_dst := ruta_dest.get_basename() + "_terreno"
		if DirAccess.dir_exists_absolute(dir_src) and not DirAccess.dir_exists_absolute(dir_dst):
			DirAccess.make_dir_recursive_absolute(dir_dst)
			var ds := DirAccess.open(dir_src)
			if ds:
				for fn in ds.get_files():
					if fn.ends_with(".res"):
						var b := FileAccess.get_file_as_bytes(dir_src + "/" + fn)
						var fo := FileAccess.open(dir_dst + "/" + fn, FileAccess.WRITE)
						if fo and not b.is_empty():
							fo.store_buffer(b)
							fo.close()

	if not FileAccess.file_exists(ruta_dest):
		return {"exito": false, "mensaje": "No se pudo preparar el archivo del mapa."}

	return {
		"exito": true,
		"ruta": ruta_dest,
		"nombre": str(item.get("nombre", "Mapa Comunidad")),
		"mensaje": "¡Iniciando mapa!"
	}

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
	var peso_b: int = int((nt_b64.length() * 3) / 4) + int((tz_b64.length() * 3) / 4)
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
		"categoria": str(d.get("categoria", "Urbano")),
		"descripcion": str(d.get("descripcion", "Ruta compartida por la comunidad.")),
		"portada_url": str(d.get("portada_url", "")),
		"peso_texto": _formatear_peso(peso_b),
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

	# Mapa destacado incluido por defecto
	var ruta_def := "res://mundo/editor_mapas/mapas_defecto/ciudad_prueba_grande.ntmap"
	if FileAccess.file_exists(ruta_def):
		var peso_def: int = FileAccess.get_file_as_bytes(ruta_def).size()
		var dir_t_def := DIR_MAPAS_LOCAL + "/ciudad_prueba_grande_terreno"
		if DirAccess.dir_exists_absolute(dir_t_def):
			var dt := DirAccess.open(dir_t_def)
			if dt:
				for fn_t in dt.get_files():
					if fn_t.ends_with(".res"):
						peso_def += FileAccess.get_file_as_bytes(dir_t_def + "/" + fn_t).size()
		lista.append({
			"id_mapa": "ciudad_prueba_grande",
			"codigo_id": "NT-000001",
			"nombre": "Ciudad Prueba Grande",
			"autor": "Nuestra Tierra",
			"categoria": "Urbano",
			"descripcion": "Ciudad completa con 4x4 avenidas, viaducto elevado con pilotes, zonas de carga/descarga y colinas.",
			"portada_url": "",
			"peso_texto": _formatear_peso(peso_def),
			"num_vias": 57,
			"num_objetos": 165,
			"ruta_local_defecto": ruta_def
		})
	return lista
