# ════════════════════════════════════════════════════════════════════════════════
# SistemaFletesPesados.gd — Sistema Integral de Fletes y Logística por Categoría
# (C1 Camionetas/Pequeños, C2 Camión Rígido, C3 Tractomula) + Registro en Nequi
# Panter Studio | Nuestra Tierra Job Simulator (Godot 4.7)
# ════════════════════════════════════════════════════════════════════════════════
extends Node
class_name SistemaFletesPesados

static var instance: SistemaFletesPesados = null

signal fletes_actualizados()
signal flete_aceptado(flete: Dictionary)
signal progreso_carga_actualizado(porcentaje: float, estado_texto: String)
signal carga_completada(flete: Dictionary)
signal flete_entregado(flete: Dictionary, pago_neto: float, exp_ganada: int)
signal flete_cancelado(motivo: String)

enum EstadoFlete {
	DISPONIBLE,
	ACEPTADO,
	CARGANDO,
	EN_RUTA,
	DESCARGANDO,
	COMPLETADO,
	CANCELADO
}

@export var validar_licencia_al_aceptar: bool = true

var fletes_disponibles: Array = []
var flete_activo: Dictionary = {}
var estado_actual: EstadoFlete = EstadoFlete.DISPONIBLE
var tiempo_restante_segundos: float = 0.0
var en_zona_carga: bool = false
var en_zona_descarga: bool = false

var _tiempo_operacion_acumulado: float = 0.0
var _duracion_operacion_total: float = 5.0
var _operando_carga: bool = false

var _catalogo_cargas: Dictionary = {}
var _lista_puntos: Array = []

func _init() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	add_to_group("sistema_fletes")
	_cargar_base_logistica()
	generar_bolsa_de_fletes()

func _process(delta: float) -> void:
	if estado_actual == EstadoFlete.EN_RUTA and tiempo_restante_segundos > 0.0:
		tiempo_restante_segundos = maxf(tiempo_restante_segundos - delta, 0.0)

	if _operando_carga:
		_tiempo_operacion_acumulado += delta
		var pct: float = clampf(_tiempo_operacion_acumulado / _duracion_operacion_total, 0.0, 1.0)
		var txt: String = "Cargando mercancía..." if estado_actual == EstadoFlete.CARGANDO else "Descargando en muelle..."
		progreso_carga_actualizado.emit(pct, txt)

		if pct >= 1.0:
			_operando_carga = false
			if estado_actual == EstadoFlete.CARGANDO:
				_finalizar_fase_carga()
			elif estado_actual == EstadoFlete.DESCARGANDO:
				_finalizar_fase_descarga()

func _cargar_base_logistica() -> void:
	var data: Dictionary = {}
	if ResourceLoader.exists("res://codigo/sistemas/logistica/GestorPuntosCarga.gd"):
		var gestor = load("res://codigo/sistemas/logistica/GestorPuntosCarga.gd")
		if gestor and gestor.has_method("cargar_datos"):
			data = gestor.call("cargar_datos")

	if data.is_empty():
		var ruta: String = "res://Datos/logistica/puntos_carga.json"
		if FileAccess.file_exists(ruta):
			var file = FileAccess.open(ruta, FileAccess.READ)
			if file:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
					data = json.data
				file.close()

	_catalogo_cargas.clear()
	for c in data.get("catalogo_cargas", []):
		_catalogo_cargas[c.get("id", "")] = c

	_lista_puntos = data.get("puntos", [])

func generar_bolsa_de_fletes(cantidad: int = 6) -> void:
	fletes_disponibles.clear()
	if _lista_puntos.size() < 2:
		return

	var origenes: Array = []
	var destinos: Array = []

	for p in _lista_puntos:
		var t: int = int(p.get("tipo_punto", 0))
		if t == 0 or t == 2:
			origenes.append(p)
		if t == 1 or t == 2:
			destinos.append(p)

	if origenes.is_empty() or destinos.is_empty():
		return

	var categorias_rotacion: Array[String] = ["C1", "C2", "C2", "C3", "C3", "C3"]

	for i in range(cantidad):
		var orig: Dictionary = origenes[randi() % origenes.size()]
		var dest: Dictionary = destinos[randi() % destinos.size()]

		var intentos: int = 0
		while dest.get("id_punto") == orig.get("id_punto") and intentos < 6:
			dest = destinos[randi() % destinos.size()]
			intentos += 1

		var cat_licencia: String = categorias_rotacion[i % categorias_rotacion.size()]
		var carga_id: String = _elegir_carga_por_licencia(cat_licencia, orig.get("cargas_permitidas", []))
		var info_carga: Dictionary = _catalogo_cargas.get(carga_id, {})
		var nombre_carga: String = info_carga.get("nombre", "Carga General Paletizada")
		var tarifa_base: float = float(info_carga.get("tarifa_sugerida", 1500))

		var pos_orig: Vector3 = _array_a_vector3(orig.get("posicion", [0, 0, 0]))
		var pos_dest: Vector3 = _array_a_vector3(dest.get("posicion", [100, 0, 100]))
		var dist_metros: float = pos_orig.distance_to(pos_dest)
		var dist_km: float = maxf(roundf((dist_metros / 1000.0) * 1.85 * 10.0) / 10.0, 3.2)

		var peso_toneladas: float = 2.5
		var factor_pago: float = 1.0
		match cat_licencia:
			"C1":
				peso_toneladas = roundf(randf_range(0.8, 3.2) * 10.0) / 10.0
				factor_pago = 0.35
			"C2":
				peso_toneladas = roundf(randf_range(5.5, 12.0) * 10.0) / 10.0
				factor_pago = 0.65
			"C3":
				peso_toneladas = roundf(randf_range(18.0, 34.0) * 10.0) / 10.0
				factor_pago = 1.15

		var pago_calculado: float = ((dist_km * 38000.0) + (peso_toneladas * tarifa_base * 36.0) + 280000.0) * factor_pago
		var pago_final: float = float(int(round(pago_calculado / 5000.0)) * 5000)
		var exp: int = int(80 + (dist_km * 14.0) + (peso_toneladas * 4.0))

		var contrato: Dictionary = {
			"id": "FLETE-%03d" % (i + 1),
			"titulo": "%s (%.1f t)" % [nombre_carga, peso_toneladas],
			"carga_id": carga_id,
			"nombre_carga": nombre_carga,
			"licencia_requerida": cat_licencia,
			"tipo_vehiculo_texto": _obtener_vehiculo_por_licencia(cat_licencia),
			"peso_toneladas": peso_toneladas,
			"origen_id": orig.get("id_punto", ""),
			"origen_nombre": orig.get("nombre_punto", "Bodega Fusagasugá"),
			"origen_pos": pos_orig,
			"destino_id": dest.get("id_punto", ""),
			"destino_nombre": dest.get("nombre_punto", "Muelle Silvania"),
			"destino_pos": pos_dest,
			"distancia_km": dist_km,
			"pago_cop": pago_final,
			"pago_formateado": formatear_moneda(pago_final),
			"recompensa_exp": exp,
			"tiempo_limite_minutos": int(15 + dist_km * 3.5),
			"remolque_requerido": _obtener_remolque_para_carga(carga_id, cat_licencia),
			"estado": "DISPONIBLE"
		}
		fletes_disponibles.append(contrato)

	fletes_actualizados.emit()

func _elegir_carga_por_licencia(cat: String, permitidas: Array) -> String:
	match cat:
		"C1":
			return "paqueteria" if permitidas.has("paqueteria") else "general"
		"C2":
			var opciones_c2: Array[String] = ["alimentos", "madera", "construccion", "general"]
			return opciones_c2[randi() % opciones_c2.size()]
		_:
			var opciones_c3: Array[String] = ["combustible", "refrigerado", "maquinaria", "contenedores", "granel", "quimicos"]
			return opciones_c3[randi() % opciones_c3.size()]

func _obtener_vehiculo_por_licencia(cat: String) -> String:
	match cat:
		"C1":
			return "Camioneta / Utilitario (Lic. C1)"
		"C2":
			return "Camión Rígido NPR / Kodiak (Lic. C2)"
		_:
			return "Tractomula Kenworth T800 (Lic. C3)"

func _obtener_remolque_para_carga(carga_id: String, cat: String) -> String:
	if cat == "C1":
		return "Platón / Furgón Liviano"
	elif cat == "C2":
		return "Carrocería Estacas / Furgón Rígido"
	match carga_id:
		"combustible", "quimicos":
			return "Tráiler Cisterna (C3)"
		"refrigerado", "alimentos":
			return "Tráiler Refrigerado / Carpado (C3)"
		"maquinaria", "construccion":
			return "Tráiler Cama Baja / Plancha (C3)"
		"granel":
			return "Tráiler Tolva Granelera (C3)"
		_:
			return "Tráiler Carpado 3 Ejes (C3)"

func _array_a_vector3(arr) -> Vector3:
	if typeof(arr) == TYPE_ARRAY and arr.size() >= 3:
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return Vector3.ZERO

func aceptar_flete(flete_id: String) -> bool:
	if estado_actual != EstadoFlete.DISPONIBLE:
		_notificar("Ya tienes un flete activo en curso.", "alerta")
		return false

	for f in fletes_disponibles:
		if f.get("id") == flete_id:
			var req_lic: String = str(f.get("licencia_requerida", "C1"))
			var datos = get_node_or_null("/root/DatosUsuario")
			if validar_licencia_al_aceptar and datos and datos.has_method("tiene_licencia"):
				if not datos.call("tiene_licencia", req_lic):
					_notificar("Requiere Licencia %s (%s). Adquiérela en la Academia Automovilística." % [req_lic, f.get("tipo_vehiculo_texto", "")], "alerta")
					return false

			flete_activo = f.duplicate(true)
			flete_activo["estado"] = "ACEPTADO"
			estado_actual = EstadoFlete.ACEPTADO
			tiempo_restante_segundos = float(flete_activo.get("tiempo_limite_minutos", 30)) * 60.0

			flete_aceptado.emit(flete_activo)
			_notificar("¡Flete %s aceptado! Dirígete a %s para cargar." % [flete_id, flete_activo.get("origen_nombre", "")], "exito")
			_sincronizar_gps_waze(flete_activo.get("origen_pos", Vector3.ZERO))
			return true

	return false

func notificar_entrada_zona(id_punto: String, es_origen: bool) -> void:
	if flete_activo.is_empty():
		return
	if es_origen and id_punto == flete_activo.get("origen_id"):
		en_zona_carga = true
		if estado_actual == EstadoFlete.ACEPTADO:
			_notificar("Detén el vehículo en la bahía para cargar la mercancía.", "info")
	elif not es_origen and id_punto == flete_activo.get("destino_id"):
		en_zona_descarga = true
		if estado_actual == EstadoFlete.EN_RUTA:
			_notificar("Llegaste al muelle de destino. Detén el vehículo para descargar y recibir tu pago en Nequi.", "info")

func notificar_salida_zona(id_punto: String) -> void:
	if flete_activo.is_empty():
		return
	if id_punto == flete_activo.get("origen_id"):
		en_zona_carga = false
	if id_punto == flete_activo.get("destino_id"):
		en_zona_descarga = false

func iniciar_carga_mercancia() -> bool:
	if estado_actual != EstadoFlete.ACEPTADO or not en_zona_carga:
		return false
	estado_actual = EstadoFlete.CARGANDO
	flete_activo["estado"] = "CARGANDO"
	_operando_carga = true
	_tiempo_operacion_acumulado = 0.0
	_duracion_operacion_total = 5.0
	return true

func _finalizar_fase_carga() -> void:
	estado_actual = EstadoFlete.EN_RUTA
	flete_activo["estado"] = "EN_RUTA"
	carga_completada.emit(flete_activo)
	_notificar("Carga asegurada. Ruta GPS actualizada hacia %s." % flete_activo.get("destino_nombre", ""), "exito")
	_sincronizar_gps_waze(flete_activo.get("destino_pos", Vector3.ZERO))

func iniciar_descarga_mercancia() -> bool:
	if estado_actual != EstadoFlete.EN_RUTA or not en_zona_descarga:
		return false
	estado_actual = EstadoFlete.DESCARGANDO
	flete_activo["estado"] = "DESCARGANDO"
	_operando_carga = true
	_tiempo_operacion_acumulado = 0.0
	_duracion_operacion_total = 6.0
	return true

func _finalizar_fase_descarga() -> void:
	var pago: float = float(flete_activo.get("pago_cop", 0.0))
	var exp: int = int(flete_activo.get("recompensa_exp", 0))
	var nombre_c: String = str(flete_activo.get("nombre_carga", "Flete"))

	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.dinero += pago
		if datos.has_method("agregar_experiencia"):
			datos.call("agregar_experiencia", exp)
		if datos.has_method("save_local"):
			datos.call("save_local")

	# Registrar movimiento en Nequi
	var celular = get_tree().get_first_node_in_group("celular") if get_tree() else null
	if not celular and CelularUI.instance:
		celular = CelularUI.instance
	if celular and celular.has_method("registrar_movimiento_nequi"):
		celular.call("registrar_movimiento_nequi", "in", "Pago Flete: " + nombre_c, pago)

	estado_actual = EstadoFlete.COMPLETADO
	flete_entregado.emit(flete_activo, pago, exp)
	_notificar("¡Flete entregado! Se abonaron %s a tu cuenta Nequi (+%d EXP)." % [formatear_moneda(pago), exp], "exito")

	flete_activo.clear()
	estado_actual = EstadoFlete.DISPONIBLE
	generar_bolsa_de_fletes()

func cancelar_flete_activo(motivo: String = "Cancelado por el conductor") -> void:
	if flete_activo.is_empty():
		return
	flete_activo.clear()
	estado_actual = EstadoFlete.DISPONIBLE
	_operando_carga = false
	flete_cancelado.emit(motivo)
	_notificar("Flete cancelado: " + motivo, "alerta")

func _sincronizar_gps_waze(destino: Vector3) -> void:
	var celular = get_tree().get_first_node_in_group("celular") if get_tree() else null
	if not celular and CelularUI.instance:
		celular = CelularUI.instance
	if celular:
		var gps = celular.get("gps_line")
		if gps and gps.has_method("set_destination"):
			gps.call("set_destination", destino)

func _notificar(mensaje: String, tipo: String = "info") -> void:
	if has_node("/root/NotificationManager"):
		var nm = get_node("/root/NotificationManager")
		if tipo == "exito" and nm.has_method("notificar_exito"):
			nm.call("notificar_exito", mensaje)
			return
		elif tipo == "alerta" and nm.has_method("notificar_error"):
			nm.call("notificar_error", mensaje)
			return
	print("[SistemaFletesPesados] ", mensaje)

static func formatear_moneda(monto: float) -> String:
	var entero: int = int(round(absf(monto)))
	var str_val: String = str(entero)
	var res: String = ""
	var contador: int = 0
	for i in range(str_val.length() - 1, -1, -1):
		res = str_val[i] + res
		contador += 1
		if contador == 3 and i > 0:
			res = "." + res
			contador = 0
	return "$ " + res

func obtener_flete_activo() -> Dictionary:
	return flete_activo

func obtener_fletes_disponibles() -> Array:
	return fletes_disponibles
