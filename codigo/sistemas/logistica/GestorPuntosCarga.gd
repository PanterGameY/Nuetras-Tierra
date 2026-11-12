@tool
extends RefCounted
class_name GestorPuntosCarga

## GestorPuntosCarga.gd
##
## Módulo centralizado para la persistencia, consulta y sincronización dinámica
## de los Puntos de Carga/Descarga y el Catálogo de Cargas y Mercancías.

const RUTA_CONFIG_BASE: String = "res://Datos/logistica/puntos_carga.json"
const RUTA_CONFIG_USER: String = "user://puntos_carga.json"

## Carga los datos desde user:// (si existe para persistir cambios en runtime) o res:// (configuración base)
static func cargar_datos() -> Dictionary:
	var ruta_a_usar = RUTA_CONFIG_BASE
	if FileAccess.file_exists(RUTA_CONFIG_USER):
		ruta_a_usar = RUTA_CONFIG_USER
	elif not FileAccess.file_exists(RUTA_CONFIG_BASE):
		push_warning("[GestorPuntosCarga] No se encontró archivo de configuración en %s ni en %s" % [RUTA_CONFIG_USER, RUTA_CONFIG_BASE])
		return _obtener_datos_por_defecto()

	var file = FileAccess.open(ruta_a_usar, FileAccess.READ)
	if not file:
		push_error("[GestorPuntosCarga] Error al abrir archivo: " + ruta_a_usar)
		return _obtener_datos_por_defecto()

	var contenido = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(contenido)
	if error != OK:
		push_error("[GestorPuntosCarga] Error al parsear JSON: %s (Línea %d)" % [json.get_error_message(), json.get_error_line()])
		return _obtener_datos_por_defecto()

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return _obtener_datos_por_defecto()

	return data

## Guarda los datos en disco (en user:// por defecto para juego en vivo, o res:// si se especifica)
static func guardar_datos(datos: Dictionary, guardar_en_res: bool = false) -> bool:
	var ruta = RUTA_CONFIG_BASE if (guardar_en_res and OS.has_feature("editor")) else RUTA_CONFIG_USER
	
	# Asegurar que el directorio exista
	var dir_path = ruta.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file = FileAccess.open(ruta, FileAccess.WRITE)
	if not file:
		push_error("[GestorPuntosCarga] No se pudo escribir en: " + ruta)
		return false

	var texto_json = JSON.stringify(datos, "  ")
	file.store_string(texto_json)
	file.close()
	print("[GestorPuntosCarga] Datos guardados exitosamente en: ", ruta)
	return true

## Obtiene el catálogo completo de cargas registradas
static func obtener_catalogo_cargas() -> Array:
	var data = cargar_datos()
	return data.get("catalogo_cargas", [])

## Obtiene la lista de puntos de carga/descarga
static func obtener_puntos() -> Array:
	var data = cargar_datos()
	return data.get("puntos", [])

## Busca un punto por su id_punto en los datos cargados
static func obtener_punto_por_id(id_buscado: String) -> Dictionary:
	var puntos = obtener_puntos()
	for p in puntos:
		if p.get("id_punto", "") == id_buscado:
			return p
	return {}

## Agrega o actualiza un tipo de carga en el catálogo
static func registrar_tipo_carga(id_carga: String, nombre: String, icono: String = "📦", descripcion: String = "", tarifa: float = 1500.0, guardar_en_res: bool = false) -> bool:
	var data = cargar_datos()
	var catalogo: Array = data.get("catalogo_cargas", [])
	
	var encontrado = false
	for item in catalogo:
		if item.get("id", "") == id_carga:
			item["nombre"] = nombre
			item["icono"] = icono
			item["descripcion"] = descripcion
			item["tarifa_sugerida"] = tarifa
			encontrado = true
			break
			
	if not encontrado:
		catalogo.append({
			"id": id_carga,
			"nombre": nombre,
			"icono": icono,
			"descripcion": descripcion,
			"tarifa_sugerida": tarifa
		})
		
	data["catalogo_cargas"] = catalogo
	return guardar_datos(data, guardar_en_res)

## Aplica la configuración de un diccionario a un nodo PuntoCargaDescarga existente
static func aplicar_datos_a_nodo(nodo: PuntoCargaDescarga, datos: Dictionary) -> void:
	if not is_instance_valid(nodo) or datos.is_empty():
		return

	if datos.has("id_punto"): nodo.id_punto = str(datos["id_punto"])
	if datos.has("nombre_punto"): nodo.nombre_punto = str(datos["nombre_punto"])
	if datos.has("orden_indice"): nodo.orden_indice = int(datos["orden_indice"])
	if datos.has("tipo_punto"): nodo.tipo_punto = int(datos["tipo_punto"])
	if datos.has("generar_area_deteccion"): nodo.generar_area_deteccion = bool(datos["generar_area_deteccion"])
	if datos.has("cargas_permitidas"):
		var arr: Array[String] = []
		for c in datos["cargas_permitidas"]:
			arr.append(str(c))
		nodo.cargas_permitidas = arr
		
	if datos.has("tarifa_base"): nodo.tarifa_base = float(datos["tarifa_base"])
	if datos.has("tiempo_operacion"): nodo.tiempo_operacion = float(datos["tiempo_operacion"])
	if datos.has("forma_zona"): nodo.forma_zona = int(datos["forma_zona"])
	if datos.has("radio"): nodo.radio = float(datos["radio"])
	if datos.has("ancho"): nodo.ancho = float(datos["ancho"])
	if datos.has("largo"): nodo.largo = float(datos["largo"])
	if datos.has("altura"): nodo.altura = float(datos["altura"])
	if datos.has("grosor_linea"): nodo.grosor_linea = float(datos["grosor_linea"])
	if datos.has("radio_esquinas"): nodo.radio_esquinas = float(datos["radio_esquinas"])
	if datos.has("velocidad_animacion"): nodo.velocidad_animacion = float(datos["velocidad_animacion"])
	if datos.has("velocidad_pulsacion"): nodo.velocidad_pulsacion = float(datos["velocidad_pulsacion"])
	if datos.has("usar_color_personalizado"): nodo.usar_color_personalizado = bool(datos["usar_color_personalizado"])
	
	if datos.has("color_personalizado"):
		var col_arr = datos["color_personalizado"]
		if typeof(col_arr) == TYPE_ARRAY and col_arr.size() >= 3:
			var a = col_arr[3] if col_arr.size() >= 4 else 1.0
			nodo.color_personalizado = Color(col_arr[0], col_arr[1], col_arr[2], a)
			
	if datos.has("opacidad_zona"): nodo.opacidad_zona = float(datos["opacidad_zona"])
	if datos.has("mostrar_etiqueta_3d"): nodo.mostrar_etiqueta_3d = bool(datos["mostrar_etiqueta_3d"])

	if datos.has("posicion"):
		var pos_arr = datos["posicion"]
		if typeof(pos_arr) == TYPE_ARRAY and pos_arr.size() == 3:
			nodo.position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])

	if datos.has("rotacion_y"):
		nodo.rotation_degrees.y = float(datos["rotacion_y"])

	nodo._actualizar_visuales()

## Extrae los datos de un nodo PuntoCargaDescarga a un diccionario serializable
static func extraer_datos_de_nodo(nodo: PuntoCargaDescarga) -> Dictionary:
	if not is_instance_valid(nodo):
		return {}

	var col = nodo.color_personalizado
	var pos = [snapped(nodo.position.x, 0.01), snapped(nodo.position.y, 0.01), snapped(nodo.position.z, 0.01)]

	return {
		"id_punto": nodo.id_punto,
		"nombre_punto": nodo.nombre_punto,
		"orden_indice": nodo.orden_indice,
		"tipo_punto": int(nodo.tipo_punto),
		"cargas_permitidas": nodo.cargas_permitidas.duplicate(),
		"tarifa_base": nodo.tarifa_base,
		"tiempo_operacion": nodo.tiempo_operacion,
		"generar_area_deteccion": nodo.generar_area_deteccion,
		"forma_zona": int(nodo.forma_zona),
		"radio": nodo.radio,
		"ancho": nodo.ancho,
		"largo": nodo.largo,
		"altura": nodo.altura,
		"posicion": pos,
		"rotacion_y": snapped(nodo.rotation_degrees.y, 0.1),
		"grosor_linea": nodo.grosor_linea,
		"radio_esquinas": nodo.radio_esquinas,
		"velocidad_animacion": nodo.velocidad_animacion,
		"velocidad_pulsacion": nodo.velocidad_pulsacion,
		"usar_color_personalizado": nodo.usar_color_personalizado,
		"color_personalizado": [snapped(col.r, 0.01), snapped(col.g, 0.01), snapped(col.b, 0.01), snapped(col.a, 0.01)],
		"opacidad_zona": nodo.opacidad_zona,
		"mostrar_etiqueta_3d": nodo.mostrar_etiqueta_3d
	}

## Crea un diccionario de punto nuevo con valores por defecto óptimos
static func crear_nuevo_punto_dict(id_nuevo: String, nombre: String = "Nuevo Punto de Carga", pos: Vector3 = Vector3.ZERO) -> Dictionary:
	return {
		"id_punto": id_nuevo,
		"nombre_punto": nombre,
		"orden_indice": 0,
		"tipo_punto": 0, # CARGA por defecto
		"cargas_permitidas": ["general"],
		"tarifa_base": 1500.0,
		"tiempo_operacion": 5.0,
		"generar_area_deteccion": true,
		"forma_zona": 1, # CAJA
		"radio": 3.5,
		"ancho": 5.0,
		"largo": 12.0,
		"altura": 3.0,
		"posicion": [snapped(pos.x, 0.01), snapped(pos.y, 0.01), snapped(pos.z, 0.01)],
		"rotacion_y": 0.0,
		"grosor_linea": 0.03,
		"radio_esquinas": 0.25,
		"velocidad_animacion": 3.5,
		"velocidad_pulsacion": 2.0,
		"usar_color_personalizado": false,
		"color_personalizado": [0.2, 0.85, 0.35, 0.9],
		"opacidad_zona": 0.85,
		"mostrar_etiqueta_3d": true
	}

static func _obtener_datos_por_defecto() -> Dictionary:
	return {
		"version": "1.0",
		"catalogo_cargas": [
			{"id": "general", "nombre": "Carga General", "icono": "📦", "descripcion": "Cajas y mercancía general", "tarifa_sugerida": 1200}
		],
		"puntos": []
	}
