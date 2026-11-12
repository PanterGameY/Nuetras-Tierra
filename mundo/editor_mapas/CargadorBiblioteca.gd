class_name CargadorBiblioteca
extends RefCounted

## CargadorBiblioteca.gd
## Motor dinámico de catalogación, descubrimiento y carga de assets para el Editor de Mapas.
## Escanea res://mundo/editor_mapas/Biblioteca/ recursivamente, lee metadatos (metadata.json)
## y enlaza los modelos 3D (.tscn, .glb) con el sistema del editor.

const RUTA_BIBLIOTECA := "res://mundo/editor_mapas/Biblioteca"

const CATEGORIAS_DEFINIDAS: Array[Dictionary] = [
	{"id": "01_Edificaciones", "nombre": "Edificaciones", "icono": "🏢", "desc": "Viviendas, comercio, industria y fincas"},
	{"id": "02_Monumentos_Hitos", "nombre": "Monumentos", "icono": "🏛️", "desc": "Iglesias, plazas y monumentos cívicos"},
	{"id": "03_Accesorios_Viales", "nombre": "Accesorios Viales", "icono": "🛣️", "desc": "Señalización, resaltos y peajes"},
	{"id": "04_Mobiliario_Urbano", "nombre": "Mobiliario", "icono": "🪑", "desc": "Bancas, paraderos, canecas y cercas"},
	{"id": "05_Vegetacion_Naturaleza", "nombre": "Naturaleza", "icono": "🌳", "desc": "Árboles nativos, arbustos y rocas"},
	{"id": "06_Infraestructura_Transporte", "nombre": "Transporte", "icono": "🚚", "desc": "Terminales, puentes y túneles"},
	{"id": "07_Plantillas_y_Kits", "nombre": "Plantillas", "icono": "📦", "desc": "Manzanas y sectores prearmados"}
]

static var _catalogo_cargado: Array[Dictionary] = []
static var _items_por_id: Dictionary = {}
static var _inicializado: bool = false

## Inicializa y escanea la biblioteca completa
static func inicializar() -> void:
	if _inicializado and not _catalogo_cargado.is_empty():
		return
	escanear_biblioteca()
	_inicializado = true

## Fuerza un re-escaneo del sistema de archivos de la biblioteca
static func escanear_biblioteca() -> Array[Dictionary]:
	_catalogo_cargado.clear()
	_items_por_id.clear()
	
	# 1. Registrar modelos integrados del proyecto mapeados a la Biblioteca
	_registrar_modelos_integrados()
	
	# 2. Escaneo recursivo de res://mundo/editor_mapas/Biblioteca/
	if DirAccess.dir_exists_absolute(RUTA_BIBLIOTECA):
		_escanear_directorio_recursivo(RUTA_BIBLIOTECA, "")
	
	return _catalogo_cargado

## Retorna todas las categorías principales disponibles
static func obtener_categorias() -> Array[Dictionary]:
	if not _inicializado:
		inicializar()
	return CATEGORIAS_DEFINIDAS

## Retorna los items filtrados por categoría raíz ("01_Edificaciones", "05_Vegetacion_Naturaleza", etc.)
static func obtener_items_por_categoria(cat_id: String) -> Array[Dictionary]:
	if not _inicializado:
		inicializar()
	if cat_id.is_empty() or cat_id == "todas":
		return _catalogo_cargado
		
	var resultado: Array[Dictionary] = []
	for item in _catalogo_cargado:
		var cat_item: String = item.get("categoria_raiz", "")
		if cat_item == cat_id or cat_item.begins_with(cat_id):
			resultado.append(item)
	return resultado

## Formatea nombres de carpetas como '01_Residencial' -> 'Residencial' o 'Casas_Modernas' -> 'Casas Modernas'
static func formatear_nombre_carpeta(nombre_raw: String) -> String:
	var s = nombre_raw
	if s.length() >= 3 and s[0].is_valid_int() and s[1].is_valid_int() and s[2] == "_":
		s = s.substr(3)
	return s.replace("_", " ")

## Deduce icono apropiado para una sección o subapartado
static func deducir_icono_seccion_o_sub(nombre_raw: String) -> String:
	var n = nombre_raw.to_lower()
	if "modern" in n: return "🏢"
	if "tradicional" in n or "campesina" in n or "colonial" in n: return "🏠"
	if "conjunto" in n or "paread" in n: return "🏘️"
	if "edificio" in n or "apartament" in n or "torre" in n: return "🏬"
	if "residencial" in n or "casa" in n: return "🏡"
	if "gasolina" in n or "servicio" in n or "eds" in n: return "⛽"
	if "comercial" in n or "tienda" in n: return "🏪"
	if "supermercado" in n or "centro" in n: return "🛍️"
	if "hotel" in n or "hospedaje" in n: return "🏨"
	if "restaurante" in n or "cafe" in n: return "☕"
	if "industrial" in n or "fabrica" in n or "planta" in n: return "🏭"
	if "bodega" in n or "almacen" in n: return "📦"
	if "taller" in n or "mecanico" in n: return "🔧"
	if "silo" in n or "tolva" in n: return "🏗️"
	if "rural" in n or "finca" in n or "hacienda" in n or "agro" in n: return "🚜"
	if "cultivo" in n or "invernadero" in n: return "🌱"
	if "galpon" in n or "establo" in n: return "🐴"
	if "salud" in n or "hospital" in n: return "🏥"
	if "seguridad" in n or "bombero" in n or "policia" in n: return "🚒"
	if "educacion" in n or "colegio" in n: return "🏫"
	if "gobierno" in n or "plaza" in n: return "🏛️"
	if "arbol" in n or "bosque" in n: return "🌳"
	if "palmera" in n: return "🌴"
	return "📁"

## Retorna las secciones disponibles para una categoría
static func obtener_secciones_de_categoria(cat_raiz: String) -> Array[Dictionary]:
	if not _inicializado:
		inicializar()
	var secciones_dict: Dictionary = {}
	for item in _catalogo_cargado:
		var c: String = item.get("categoria_raiz", "")
		if cat_raiz.is_empty() or cat_raiz == "todas" or c == cat_raiz or c.begins_with(cat_raiz):
			var sec: String = item.get("seccion", "")
			if not sec.is_empty() and not secciones_dict.has(sec):
				secciones_dict[sec] = {
					"id": sec,
					"nombre": formatear_nombre_carpeta(sec),
					"icono": deducir_icono_seccion_o_sub(sec)
				}
	var lista: Array[Dictionary] = []
	var claves = secciones_dict.keys()
	claves.sort()
	for k in claves:
		lista.append(secciones_dict[k])
	return lista

## Retorna los subapartados disponibles para una sección
static func obtener_subapartados_de_seccion(cat_raiz: String, seccion_id: String) -> Array[Dictionary]:
	if not _inicializado:
		inicializar()
	var sub_dict: Dictionary = {}
	for item in _catalogo_cargado:
		var c: String = item.get("categoria_raiz", "")
		var s: String = item.get("seccion", "")
		if (cat_raiz.is_empty() or cat_raiz == "todas" or c == cat_raiz or c.begins_with(cat_raiz)) and (seccion_id.is_empty() or seccion_id == "todas" or s == seccion_id):
			var sub: String = item.get("subapartado", "")
			if not sub.is_empty() and not sub_dict.has(sub):
				sub_dict[sub] = {
					"id": sub,
					"nombre": formatear_nombre_carpeta(sub),
					"icono": deducir_icono_seccion_o_sub(sub)
				}
	var lista: Array[Dictionary] = []
	var claves = sub_dict.keys()
	claves.sort()
	for k in claves:
		lista.append(sub_dict[k])
	return lista

## Retorna items filtrados con precisión por categoría, sección y subapartado
static func obtener_items_filtrados(cat_raiz: String, seccion_id: String = "", subapartado_id: String = "") -> Array[Dictionary]:
	if not _inicializado:
		inicializar()
	var resultado: Array[Dictionary] = []
	for item in _catalogo_cargado:
		var c: String = item.get("categoria_raiz", "")
		if not cat_raiz.is_empty() and cat_raiz != "todas" and c != cat_raiz and not c.begins_with(cat_raiz):
			continue
		var s: String = item.get("seccion", "")
		if not seccion_id.is_empty() and seccion_id != "todas" and s != seccion_id:
			continue
		var sub: String = item.get("subapartado", "")
		var subcat: String = item.get("subcategoria", "")
		if not subapartado_id.is_empty() and subapartado_id != "todos" and sub != subapartado_id and subcat != subapartado_id:
			continue
		resultado.append(item)
	return resultado

## Retorna los metadatos de un item por su ID
static func obtener_item(id_item: String) -> Dictionary:
	if not _inicializado:
		inicializar()
	return _items_por_id.get(id_item, {})

## Instancia un objeto en la escena 3D a partir de su ID
static func instanciar_asset(id_item: String) -> Node3D:
	if not _inicializado:
		inicializar()
		
	if _items_por_id.has(id_item):
		var info: Dictionary = _items_por_id[id_item]
		var ruta_escena: String = info.get("ruta_escena", "")
		if not ruta_escena.is_empty() and ResourceLoader.exists(ruta_escena):
			var packed = load(ruta_escena)
			if packed and packed is PackedScene:
				var inst = packed.instantiate()
				if inst is Node3D:
					inst.set_meta("id_modelo", id_item)
					inst.set_meta("es_objeto_ciudad", true)
					_asegurar_colision(inst, info)
					return inst
					
	# Fallback a generador procedural integrado si existe
	return GeneradorModelosCiudad.crear_instancia_objeto(id_item)

## Escaneo recursivo interno con reconocimiento jerárquico de carpetas
static func _escanear_directorio_recursivo(ruta_actual: String, cat_raiz: String, seccion: String = "", subapartado: String = "") -> void:
	var dir = DirAccess.open(ruta_actual)
	if not dir:
		return
		
	dir.list_dir_begin()
	var nombre_archivo = dir.get_next()
	
	while not nombre_archivo.is_empty():
		if nombre_archivo.begins_with("."):
			nombre_archivo = dir.get_next()
			continue
			
		var ruta_completa = ruta_actual.path_join(nombre_archivo)
		if dir.current_is_dir():
			var nueva_cat_raiz = cat_raiz
			var nueva_seccion = seccion
			var nuevo_subapartado = subapartado
			
			if cat_raiz.is_empty():
				for c in CATEGORIAS_DEFINIDAS:
					if nombre_archivo.begins_with(c["id"]) or nombre_archivo == c["id"]:
						nueva_cat_raiz = c["id"]
						break
			elif seccion.is_empty():
				nueva_seccion = nombre_archivo
			elif subapartado.is_empty():
				nuevo_subapartado = nombre_archivo
			else:
				nuevo_subapartado = subapartado.path_join(nombre_archivo)
				
			_escanear_directorio_recursivo(ruta_completa, nueva_cat_raiz, nueva_seccion, nuevo_subapartado)
		else:
			var ext = nombre_archivo.get_extension().to_lower()
			if ext == "tscn" or ext == "glb" or ext == "gltf":
				_procesar_archivo_asset(ruta_completa, nombre_archivo, cat_raiz, seccion, subapartado)
				
		nombre_archivo = dir.get_next()
	dir.list_dir_end()

## Procesa un archivo 3D descubierto en la Biblioteca
static func _procesar_archivo_asset(ruta_archivo: String, nombre_archivo: String, cat_raiz: String, seccion: String = "", subapartado: String = "") -> void:
	var id_base = nombre_archivo.get_basename()
	var ruta_dir = ruta_archivo.get_base_dir()
	
	# Verificar si existe metadata.json en la misma carpeta o con el mismo nombre
	var datos_meta := {}
	var ruta_meta_especifica = ruta_dir.path_join(id_base + ".json")
	var ruta_meta_carpeta = ruta_dir.path_join("metadata.json")
	
	if FileAccess.file_exists(ruta_meta_especifica):
		datos_meta = _cargar_json(ruta_meta_especifica)
	elif FileAccess.file_exists(ruta_meta_carpeta):
		datos_meta = _cargar_json(ruta_meta_carpeta)
		
	var item_id = datos_meta.get("id", id_base)
	if _items_por_id.has(item_id):
		return # Evitar duplicados
		
	var nombre_display: String = datos_meta.get("nombre", id_base.capitalize().replace("_", " "))
	var icono_fallback: String = datos_meta.get("icono", _deducir_icono_fallback(cat_raiz))
	var tex_ico: String = datos_meta.get("icono_textura", "")
	
	# Búsqueda automática de textura de icono si no está en metadata
	if tex_ico.is_empty():
		var posibles_rutas_icono = [
			ruta_dir.path_join(id_base + ".png"),
			"res://recursos/iconos_editor/arboles/" + id_base + ".png",
			"res://recursos/iconos_editor/edificios/" + id_base + ".png"
		]
		for p in posibles_rutas_icono:
			if ResourceLoader.exists(p):
				tex_ico = p
				break
				
	var tamano_v := Vector3(8.0, 5.0, 8.0)
	if datos_meta.has("tamano") and datos_meta["tamano"] is Array and datos_meta["tamano"].size() >= 3:
		tamano_v = Vector3(datos_meta["tamano"][0], datos_meta["tamano"][1], datos_meta["tamano"][2])
		
	var sec_final: String = str(datos_meta.get("seccion", seccion))
	var sub_final: String = str(datos_meta.get("subapartado", subapartado if not subapartado.is_empty() else ruta_dir.get_file()))
	
	var item_dict = {
		"id": item_id,
		"nombre": nombre_display,
		"icono": icono_fallback,
		"icono_textura": tex_ico,
		"categoria_raiz": cat_raiz if not cat_raiz.is_empty() else "01_Edificaciones",
		"seccion": sec_final,
		"subapartado": sub_final,
		"subcategoria": sub_final if not sub_final.is_empty() else sec_final,
		"ruta_escena": ruta_archivo,
		"tamano": tamano_v,
		"descripcion": datos_meta.get("descripcion", ""),
		"es_biblioteca_archivo": true
	}
	
	_catalogo_cargado.append(item_dict)
	_items_por_id[item_id] = item_dict

static func _cargar_json(ruta: String) -> Dictionary:
	var f = FileAccess.open(ruta, FileAccess.READ)
	if not f:
		return {}
	var txt = f.get_as_text()
	var json = JSON.new()
	if json.parse(txt) == OK and json.data is Dictionary:
		return json.data
	return {}

static func _deducir_icono_fallback(cat_raiz: String) -> String:
	match cat_raiz:
		"01_Edificaciones": return "🏢"
		"02_Monumentos_Hitos": return "🏛️"
		"03_Accesorios_Viales": return "🛣️"
		"04_Mobiliario_Urbano": return "🪑"
		"05_Vegetacion_Naturaleza": return "🌳"
		"06_Infraestructura_Transporte": return "🚚"
		"07_Plantillas_y_Kits": return "📦"
		_: return "📦"

## Registra los modelos integrados y los 5 árboles nativos de Nuestra Tierra
static func _registrar_modelos_integrados() -> void:
	# 1. Árboles Nativos 3D
	var arboles = [
		{"id": "arbol_sabanero", "nombre": "Árbol Sabanero", "icono": "🌳", "tex": "res://recursos/iconos_editor/arboles/arbol_sabanero.png", "tscn": "res://modelos3d/mapa/arboles/arbol_sabanero.tscn", "tam": Vector3(8.0, 11.5, 8.0)},
		{"id": "arbol_roble_3d", "nombre": "Roble 3D", "icono": "🌲", "tex": "res://recursos/iconos_editor/arboles/arbol_roble_3d.png", "tscn": "res://modelos3d/mapa/arboles/arbol_roble_3d.tscn", "tam": Vector3(8.0, 12.0, 8.0)},
		{"id": "arbol_palmera", "nombre": "Palmera", "icono": "🌴", "tex": "res://recursos/iconos_editor/arboles/arbol_palmera.png", "tscn": "res://modelos3d/mapa/arboles/arbol_palmera.tscn", "tam": Vector3(5.0, 14.0, 5.0)},
		{"id": "arbol_alto_silvestre", "nombre": "Silvestre Alto", "icono": "🌿", "tex": "res://recursos/iconos_editor/arboles/arbol_alto_silvestre.png", "tscn": "res://modelos3d/mapa/arboles/arbol_alto_silvestre.tscn", "tam": Vector3(7.0, 13.0, 7.0)},
		{"id": "arbol_frondoso", "nombre": "Árbol Frondoso", "icono": "🍃", "tex": "res://recursos/iconos_editor/arboles/arbol_frondoso.png", "tscn": "res://modelos3d/mapa/arboles/arbol_frondoso.tscn", "tam": Vector3(9.0, 10.5, 9.0)}
	]
	for a in arboles:
		var it = {
			"id": a["id"],
			"nombre": a["nombre"],
			"icono": a["icono"],
			"icono_textura": a["tex"],
			"categoria_raiz": "05_Vegetacion_Naturaleza",
			"subcategoria": "01_Arboles",
			"ruta_escena": a["tscn"],
			"tamano": a["tam"],
			"descripcion": "Especie vegetal nativa para el paisaje colombiano.",
			"es_biblioteca_archivo": false
		}
		_catalogo_cargado.append(it)
		_items_por_id[a["id"]] = it
		
	# 2. Edificaciones y equipamientos de GeneradorModelosCiudad
	for item in GeneradorModelosCiudad.obtener_catalogo():
		var id: String = item["id"]
		if _items_por_id.has(id):
			continue
			
		var cat_num = item.get("categoria", 0)
		var cat_raiz = "01_Edificaciones"
		match cat_num:
			GeneradorModelosCiudad.Categoria.RESIDENCIAL, GeneradorModelosCiudad.Categoria.COMERCIAL, GeneradorModelosCiudad.Categoria.INDUSTRIAL, GeneradorModelosCiudad.Categoria.SERVICIOS:
				cat_raiz = "01_Edificaciones"
			GeneradorModelosCiudad.Categoria.VEGETACION:
				cat_raiz = "05_Vegetacion_Naturaleza"
			GeneradorModelosCiudad.Categoria.MOBILIARIO:
				cat_raiz = "04_Mobiliario_Urbano"
				
		var sec = "01_Residencial"
		var sub = "Casas_Tradicionales"
		match id:
			"casa_suburbana":
				sec = "01_Residencial"; sub = "Casas_Tradicionales"
			"casa_moderna":
				sec = "01_Residencial"; sub = "Casas_Modernas"
			"edificio_residencial":
				sec = "01_Residencial"; sub = "Edificios_Apartamentos"
			"tienda_barrio":
				sec = "02_Comercial"; sub = "Tiendas_y_Locales"
			"centro_comercial":
				sec = "02_Comercial"; sub = "Supermercados_CentrosComerciales"
			"gasolinera":
				sec = "02_Comercial"; sub = "Estaciones_Servicio"
			"rascacielos":
				sec = "03_Industrial_Logistica"; sub = "Fabricas_Plantas"
			"bodega_industrial":
				sec = "03_Industrial_Logistica"; sub = "Bodegas_Almacenaje"
			"hospital":
				sec = "04_Servicios_Publicos"; sub = "Salud"
			"estacion_bomberos":
				sec = "04_Servicios_Publicos"; sub = "Seguridad_Emergencias"
			"plaza_parque":
				sec = "04_Servicios_Publicos"; sub = "Gobierno_Comunitario"
			_:
				sec = "01_Residencial"; sub = "General"
		var it = {
			"id": id,
			"nombre": item["nombre"],
			"icono": item["icono"],
			"icono_textura": item.get("icono_textura", ""),
			"categoria_raiz": cat_raiz,
			"seccion": sec,
			"subapartado": sub,
			"subcategoria": sub,
			"ruta_escena": "",
			"tamano": item.get("tamano", Vector3(10.0, 6.0, 10.0)),
			"descripcion": item.get("desc", ""),
			"es_biblioteca_archivo": false
		}
		_catalogo_cargado.append(it)
		_items_por_id[id] = it

## Asegura que el nodo tenga colisión física para el editor y vehículos
static func _asegurar_colision(nodo: Node3D, info: Dictionary) -> void:
	if not nodo is CollisionObject3D:
		return
	# Si ya tiene colisión no hacer nada
	for c in nodo.get_children():
		if c is CollisionShape3D:
			return
			
	var tam: Vector3 = info.get("tamano", Vector3(8.0, 5.0, 8.0))
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tam
	col.shape = box
	col.position = Vector3(0.0, tam.y * 0.5, 0.0)
	nodo.add_child(col)
