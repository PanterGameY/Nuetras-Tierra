path = "mundo/editor_mapas/CargadorBiblioteca.gd"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Add helper methods after obtener_items_por_categoria
target_after = """static func obtener_items_por_categoria(cat_id: String) -> Array[Dictionary]:
\tif not _inicializado:
\t\tinicializar()
\tif cat_id.is_empty() or cat_id == "todas":
\t\treturn _catalogo_cargado
\t\t
\tvar resultado: Array[Dictionary] = []
\tfor item in _catalogo_cargado:
\t\tvar cat_item: String = item.get("categoria_raiz", "")
\t\tif cat_item == cat_id or cat_item.begins_with(cat_id):
\t\t\tresultado.append(item)
\treturn resultado"""

new_helpers = """static func obtener_items_por_categoria(cat_id: String) -> Array[Dictionary]:
\tif not _inicializado:
\t\tinicializar()
\tif cat_id.is_empty() or cat_id == "todas":
\t\treturn _catalogo_cargado
\t\t
\tvar resultado: Array[Dictionary] = []
\tfor item in _catalogo_cargado:
\t\tvar cat_item: String = item.get("categoria_raiz", "")
\t\tif cat_item == cat_id or cat_item.begins_with(cat_id):
\t\t\tresultado.append(item)
\treturn resultado

## Formatea nombres de carpetas como '01_Residencial' -> 'Residencial' o 'Casas_Modernas' -> 'Casas Modernas'
static func formatear_nombre_carpeta(nombre_raw: String) -> String:
\tvar s = nombre_raw
\tif s.length() >= 3 and s[0].is_valid_int() and s[1].is_valid_int() and s[2] == "_":
\t\ts = s.substr(3)
\treturn s.replace("_", " ")

## Deduce icono apropiado para una sección o subapartado
static func deducir_icono_seccion_o_sub(nombre_raw: String) -> String:
\tvar n = nombre_raw.to_lower()
\tif "modern" in n: return "🏢"
\tif "tradicional" in n or "campesina" in n or "colonial" in n: return "🏠"
\tif "conjunto" in n or "paread" in n: return "🏘️"
\tif "edificio" in n or "apartament" in n or "torre" in n: return "🏬"
\tif "residencial" in n or "casa" in n: return "🏡"
\tif "gasolina" in n or "servicio" in n or "eds" in n: return "⛽"
\tif "comercial" in n or "tienda" in n: return "🏪"
\tif "supermercado" in n or "centro" in n: return "🛍️"
\tif "hotel" in n or "hospedaje" in n: return "🏨"
\tif "restaurante" in n or "cafe" in n: return "☕"
\tif "industrial" in n or "fabrica" in n or "planta" in n: return "🏭"
\tif "bodega" in n or "almacen" in n: return "📦"
\tif "taller" in n or "mecanico" in n: return "🔧"
\tif "silo" in n or "tolva" in n: return "🏗️"
\tif "rural" in n or "finca" in n or "hacienda" in n or "agro" in n: return "🚜"
\tif "cultivo" in n or "invernadero" in n: return "🌱"
\tif "galpon" in n or "establo" in n: return "🐴"
\tif "salud" in n or "hospital" in n: return "🏥"
\tif "seguridad" in n or "bombero" in n or "policia" in n: return "🚒"
\tif "educacion" in n or "colegio" in n: return "🏫"
\tif "gobierno" in n or "plaza" in n: return "🏛️"
\tif "arbol" in n or "bosque" in n: return "🌳"
\tif "palmera" in n: return "🌴"
\treturn "📁"

## Retorna las secciones disponibles para una categoría
static func obtener_secciones_de_categoria(cat_raiz: String) -> Array[Dictionary]:
\tif not _inicializado:
\t\tinicializar()
\tvar secciones_dict: Dictionary = {}
\tfor item in _catalogo_cargado:
\t\tvar c: String = item.get("categoria_raiz", "")
\t\tif cat_raiz.is_empty() or cat_raiz == "todas" or c == cat_raiz or c.begins_with(cat_raiz):
\t\t\tvar sec: String = item.get("seccion", "")
\t\t\tif not sec.is_empty() and not secciones_dict.has(sec):
\t\t\t\tsecciones_dict[sec] = {
\t\t\t\t\t"id": sec,
\t\t\t\t\t"nombre": formatear_nombre_carpeta(sec),
\t\t\t\t\t"icono": deducir_icono_seccion_o_sub(sec)
\t\t\t\t}
\tvar lista: Array[Dictionary] = []
\tvar claves = secciones_dict.keys()
\tclaves.sort()
\tfor k in claves:
\t\tlista.append(secciones_dict[k])
\treturn lista

## Retorna los subapartados disponibles para una sección
static func obtener_subapartados_de_seccion(cat_raiz: String, seccion_id: String) -> Array[Dictionary]:
\tif not _inicializado:
\t\tinicializar()
\tvar sub_dict: Dictionary = {}
\tfor item in _catalogo_cargado:
\t\tvar c: String = item.get("categoria_raiz", "")
\t\tvar s: String = item.get("seccion", "")
\t\tif (cat_raiz.is_empty() or cat_raiz == "todas" or c == cat_raiz or c.begins_with(cat_raiz)) and (seccion_id.is_empty() or seccion_id == "todas" or s == seccion_id):
\t\t\tvar sub: String = item.get("subapartado", "")
\t\t\tif not sub.is_empty() and not sub_dict.has(sub):
\t\t\t\tsub_dict[sub] = {
\t\t\t\t\t"id": sub,
\t\t\t\t\t"nombre": formatear_nombre_carpeta(sub),
\t\t\t\t\t"icono": deducir_icono_seccion_o_sub(sub)
\t\t\t\t}
\tvar lista: Array[Dictionary] = []
\tvar claves = sub_dict.keys()
\tclaves.sort()
\tfor k in claves:
\t\tlista.append(sub_dict[k])
\treturn lista

## Retorna items filtrados con precisión por categoría, sección y subapartado
static func obtener_items_filtrados(cat_raiz: String, seccion_id: String = "", subapartado_id: String = "") -> Array[Dictionary]:
\tif not _inicializado:
\t\tinicializar()
\tvar resultado: Array[Dictionary] = []
\tfor item in _catalogo_cargado:
\t\tvar c: String = item.get("categoria_raiz", "")
\t\tif not cat_raiz.is_empty() and cat_raiz != "todas" and c != cat_raiz and not c.begins_with(cat_raiz):
\t\t\tcontinue
\t\tvar s: String = item.get("seccion", "")
\t\tif not seccion_id.is_empty() and seccion_id != "todas" and s != seccion_id:
\t\t\tcontinue
\t\tvar sub: String = item.get("subapartado", "")
\t\tvar subcat: String = item.get("subcategoria", "")
\t\tif not subapartado_id.is_empty() and subapartado_id != "todos" and sub != subapartado_id and subcat != subapartado_id:
\t\t\tcontinue
\t\tresultado.append(item)
\treturn resultado"""

text_clean = text.replace("\r\n", "\n")
target_clean = target_after.replace("\r\n", "\n")
new_clean = new_helpers.replace("\r\n", "\n")

assert target_clean in text_clean, "target_after not found in text"
text_clean = text_clean.replace(target_clean, new_clean, 1)

# Also update _registrar_modelos_integrados mapping
old_integ = """\t\tvar it = {
\t\t\t"id": id,
\t\t\t"nombre": item["nombre"],
\t\t\t"icono": item["icono"],
\t\t\t"icono_textura": item.get("icono_textura", ""),
\t\t\t"categoria_raiz": cat_raiz,
\t\t\t"subcategoria": "General",
\t\t\t"ruta_escena": "",
\t\t\t"tamano": item.get("tamano", Vector3(10.0, 6.0, 10.0)),
\t\t\t"descripcion": item.get("desc", ""),
\t\t\t"es_biblioteca_archivo": false
\t\t}"""

new_integ = """\t\tvar sec = "01_Residencial"
\t\tvar sub = "Casas_Tradicionales"
\t\tmatch id:
\t\t\t"casa_suburbana":
\t\t\t\tsec = "01_Residencial"; sub = "Casas_Tradicionales"
\t\t\t"casa_moderna":
\t\t\t\tsec = "01_Residencial"; sub = "Casas_Modernas"
\t\t\t"edificio_residencial":
\t\t\t\tsec = "01_Residencial"; sub = "Edificios_Apartamentos"
\t\t\t"tienda_barrio":
\t\t\t\tsec = "02_Comercial"; sub = "Tiendas_y_Locales"
\t\t\t"centro_comercial":
\t\t\t\tsec = "02_Comercial"; sub = "Supermercados_CentrosComerciales"
\t\t\t"gasolinera":
\t\t\t\tsec = "02_Comercial"; sub = "Estaciones_Servicio"
\t\t\t"rascacielos":
\t\t\t\tsec = "03_Industrial_Logistica"; sub = "Fabricas_Plantas"
\t\t\t"bodega_industrial":
\t\t\t\tsec = "03_Industrial_Logistica"; sub = "Bodegas_Almacenaje"
\t\t\t"hospital":
\t\t\t\tsec = "04_Servicios_Publicos"; sub = "Salud"
\t\t\t"estacion_bomberos":
\t\t\t\tsec = "04_Servicios_Publicos"; sub = "Seguridad_Emergencias"
\t\t\t"plaza_parque":
\t\t\t\tsec = "04_Servicios_Publicos"; sub = "Gobierno_Comunitario"
\t\t\t_:
\t\t\t\tsec = "01_Residencial"; sub = "General"
\t\tvar it = {
\t\t\t"id": id,
\t\t\t"nombre": item["nombre"],
\t\t\t"icono": item["icono"],
\t\t\t"icono_textura": item.get("icono_textura", ""),
\t\t\t"categoria_raiz": cat_raiz,
\t\t\t"seccion": sec,
\t\t\t"subapartado": sub,
\t\t\t"subcategoria": sub,
\t\t\t"ruta_escena": "",
\t\t\t"tamano": item.get("tamano", Vector3(10.0, 6.0, 10.0)),
\t\t\t"descripcion": item.get("desc", ""),
\t\t\t"es_biblioteca_archivo": false
\t\t}"""

old_integ_clean = old_integ.replace("\r\n", "\n")
new_integ_clean = new_integ.replace("\r\n", "\n")
assert old_integ_clean in text_clean, "old_integ not found"
text_clean = text_clean.replace(old_integ_clean, new_integ_clean, 1)

if "\r\n" in text:
    text_clean = text_clean.replace("\n", "\r\n")

with open(path, "w", encoding="utf-8") as f:
    f.write(text_clean)

print("Successfully added helper methods and updated model mappings in CargadorBiblioteca!")
