path = "mundo/editor_mapas/CargadorBiblioteca.gd"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Replace _escanear_directorio_recursivo and _procesar_archivo_asset and add new query methods
old_scan_block = """## Escaneo recursivo interno
static func _escanear_directorio_recursivo(ruta_actual: String, cat_raiz: String) -> void:
\tvar dir = DirAccess.open(ruta_actual)
\tif not dir:
\t\treturn
\t\t
\tdir.list_dir_begin()
\tvar nombre_archivo = dir.get_next()
\t
\twhile not nombre_archivo.is_empty():
\t\tif nombre_archivo.begins_with("."):
\t\t\tnombre_archivo = dir.get_next()
\t\t\tcontinue
\t\t\t
\t\tvar ruta_completa = ruta_actual.path_join(nombre_archivo)
\t\tif dir.current_is_dir():
\t\t\tvar nueva_cat_raiz = cat_raiz
\t\t\tif cat_raiz.is_empty():
\t\t\t\tfor c in CATEGORIAS_DEFINIDAS:
\t\t\t\t\tif nombre_archivo.begins_with(c["id"]) or nombre_archivo == c["id"]:
\t\t\t\t\t\tnueva_cat_raiz = c["id"]
\t\t\t\t\t\tbreak
\t\t\t_escanear_directorio_recursivo(ruta_completa, nueva_cat_raiz)
\t\telse:
\t\t\tvar ext = nombre_archivo.get_extension().to_lower()
\t\t\tif ext == "tscn" or ext == "glb" or ext == "gltf":
\t\t\t\t_procesar_archivo_asset(ruta_completa, nombre_archivo, cat_raiz)
\t\t\t\t
\t\tnombre_archivo = dir.get_next()
\tdir.list_dir_end()

## Procesa un archivo 3D descubierto en la Biblioteca
static func _procesar_archivo_asset(ruta_archivo: String, nombre_archivo: String, cat_raiz: String) -> void:
\tvar id_base = nombre_archivo.get_basename()
\tvar ruta_dir = ruta_archivo.get_base_dir()
\t
\t# Verificar si existe metadata.json en la misma carpeta o con el mismo nombre
\tvar datos_meta := {}
\tvar ruta_meta_especifica = ruta_dir.path_join(id_base + ".json")
\tvar ruta_meta_carpeta = ruta_dir.path_join("metadata.json")
\t
\tif FileAccess.file_exists(ruta_meta_especifica):
\t\tdatos_meta = _cargar_json(ruta_meta_especifica)
\telif FileAccess.file_exists(ruta_meta_carpeta):
\t\tdatos_meta = _cargar_json(ruta_meta_carpeta)
\t\t
\tvar item_id = datos_meta.get("id", id_base)
\tif _items_por_id.has(item_id):
\t\treturn # Evitar duplicados
\t\t
\tvar nombre_display: String = datos_meta.get("nombre", id_base.capitalize().replace("_", " "))
\tvar icono_fallback: String = datos_meta.get("icono", _deducir_icono_fallback(cat_raiz))
\tvar tex_ico: String = datos_meta.get("icono_textura", "")
\t
\t# Búsqueda automática de textura de icono si no está en metadata
\tif tex_ico.is_empty():
\t\tvar posibles_rutas_icono = [
\t\t\truta_dir.path_join(id_base + ".png"),
\t\t\t"res://recursos/iconos_editor/arboles/" + id_base + ".png",
\t\t\t"res://recursos/iconos_editor/edificios/" + id_base + ".png"
\t\t]
\t\tfor p in posibles_rutas_icono:
\t\t\tif ResourceLoader.exists(p):
\t\t\t\ttex_ico = p
\t\t\t\tbreak
\t\t\t\t
\tvar tamano_v := Vector3(8.0, 5.0, 8.0)
\tif datos_meta.has("tamano") and datos_meta["tamano"] is Array and datos_meta["tamano"].size() >= 3:
\t\ttamano_v = Vector3(datos_meta["tamano"][0], datos_meta["tamano"][1], datos_meta["tamano"][2])
\t\t
\tvar item_dict = {
\t\t"id": item_id,
\t\t"nombre": nombre_display,
\t\t"icono": icono_fallback,
\t\t"icono_textura": tex_ico,
\t\t"categoria_raiz": cat_raiz if not cat_raiz.is_empty() else "01_Edificaciones",
\t\t"subcategoria": datos_meta.get("subcategoria", ruta_dir.get_file()),
\t\t"ruta_escena": ruta_archivo,
\t\t"tamano": tamano_v,
\t\t"descripcion": datos_meta.get("descripcion", ""),
\t\t"es_biblioteca_archivo": true
\t}
\t
\t_catalogo_cargado.append(item_dict)
\t_items_por_id[item_id] = item_dict"""

new_scan_block = """## Escaneo recursivo interno con reconocimiento jerárquico de carpetas
static func _escanear_directorio_recursivo(ruta_actual: String, cat_raiz: String, seccion: String = "", subapartado: String = "") -> void:
\tvar dir = DirAccess.open(ruta_actual)
\tif not dir:
\t\treturn
\t\t
\tdir.list_dir_begin()
\tvar nombre_archivo = dir.get_next()
\t
\twhile not nombre_archivo.is_empty():
\t\tif nombre_archivo.begins_with("."):
\t\t\tnombre_archivo = dir.get_next()
\t\t\tcontinue
\t\t\t
\t\tvar ruta_completa = ruta_actual.path_join(nombre_archivo)
\t\tif dir.current_is_dir():
\t\t\tvar nueva_cat_raiz = cat_raiz
\t\t\tvar nueva_seccion = seccion
\t\t\tvar nuevo_subapartado = subapartado
\t\t\t
\t\t\tif cat_raiz.is_empty():
\t\t\t\tfor c in CATEGORIAS_DEFINIDAS:
\t\t\t\t\tif nombre_archivo.begins_with(c["id"]) or nombre_archivo == c["id"]:
\t\t\t\t\t\tnueva_cat_raiz = c["id"]
\t\t\t\t\t\tbreak
\t\t\telif seccion.is_empty():
\t\t\t\tnueva_seccion = nombre_archivo
\t\t\telif subapartado.is_empty():
\t\t\t\tnuevo_subapartado = nombre_archivo
\t\t\telse:
\t\t\t\tnuevo_subapartado = subapartado.path_join(nombre_archivo)
\t\t\t\t
\t\t\t_escanear_directorio_recursivo(ruta_completa, nueva_cat_raiz, nueva_seccion, nuevo_subapartado)
\t\telse:
\t\t\tvar ext = nombre_archivo.get_extension().to_lower()
\t\t\tif ext == "tscn" or ext == "glb" or ext == "gltf":
\t\t\t\t_procesar_archivo_asset(ruta_completa, nombre_archivo, cat_raiz, seccion, subapartado)
\t\t\t\t
\t\tnombre_archivo = dir.get_next()
\tdir.list_dir_end()

## Procesa un archivo 3D descubierto en la Biblioteca
static func _procesar_archivo_asset(ruta_archivo: String, nombre_archivo: String, cat_raiz: String, seccion: String = "", subapartado: String = "") -> void:
\tvar id_base = nombre_archivo.get_basename()
\tvar ruta_dir = ruta_archivo.get_base_dir()
\t
\t# Verificar si existe metadata.json en la misma carpeta o con el mismo nombre
\tvar datos_meta := {}
\tvar ruta_meta_especifica = ruta_dir.path_join(id_base + ".json")
\tvar ruta_meta_carpeta = ruta_dir.path_join("metadata.json")
\t
\tif FileAccess.file_exists(ruta_meta_especifica):
\t\tdatos_meta = _cargar_json(ruta_meta_especifica)
\telif FileAccess.file_exists(ruta_meta_carpeta):
\t\tdatos_meta = _cargar_json(ruta_meta_carpeta)
\t\t
\tvar item_id = datos_meta.get("id", id_base)
\tif _items_por_id.has(item_id):
\t\treturn # Evitar duplicados
\t\t
\tvar nombre_display: String = datos_meta.get("nombre", id_base.capitalize().replace("_", " "))
\tvar icono_fallback: String = datos_meta.get("icono", _deducir_icono_fallback(cat_raiz))
\tvar tex_ico: String = datos_meta.get("icono_textura", "")
\t
\t# Búsqueda automática de textura de icono si no está en metadata
\tif tex_ico.is_empty():
\t\tvar posibles_rutas_icono = [
\t\t\truta_dir.path_join(id_base + ".png"),
\t\t\t"res://recursos/iconos_editor/arboles/" + id_base + ".png",
\t\t\t"res://recursos/iconos_editor/edificios/" + id_base + ".png"
\t\t]
\t\tfor p in posibles_rutas_icono:
\t\t\tif ResourceLoader.exists(p):
\t\t\t\ttex_ico = p
\t\t\t\tbreak
\t\t\t\t
\tvar tamano_v := Vector3(8.0, 5.0, 8.0)
\tif datos_meta.has("tamano") and datos_meta["tamano"] is Array and datos_meta["tamano"].size() >= 3:
\t\ttamano_v = Vector3(datos_meta["tamano"][0], datos_meta["tamano"][1], datos_meta["tamano"][2])
\t\t
\tvar sec_final: String = str(datos_meta.get("seccion", seccion))
\tvar sub_final: String = str(datos_meta.get("subapartado", subapartado if not subapartado.is_empty() else ruta_dir.get_file()))
\t
\tvar item_dict = {
\t\t"id": item_id,
\t\t"nombre": nombre_display,
\t\t"icono": icono_fallback,
\t\t"icono_textura": tex_ico,
\t\t"categoria_raiz": cat_raiz if not cat_raiz.is_empty() else "01_Edificaciones",
\t\t"seccion": sec_final,
\t\t"subapartado": sub_final,
\t\t"subcategoria": sub_final if not sub_final.is_empty() else sec_final,
\t\t"ruta_escena": ruta_archivo,
\t\t"tamano": tamano_v,
\t\t"descripcion": datos_meta.get("descripcion", ""),
\t\t"es_biblioteca_archivo": true
\t}
\t
\t_catalogo_cargado.append(item_dict)
\t_items_por_id[item_id] = item_dict"""

text_clean = text.replace("\r\n", "\n")
old_clean = old_scan_block.replace("\r\n", "\n")
new_clean = new_scan_block.replace("\r\n", "\n")

assert old_clean in text_clean, "old_scan_block not found"
text_clean = text_clean.replace(old_clean, new_clean, 1)

if "\r\n" in text:
    text_clean = text_clean.replace("\n", "\r\n")

with open(path, "w", encoding="utf-8") as f:
    f.write(text_clean)

print("Successfully updated CargadorBiblioteca scanning logic!")
