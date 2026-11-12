# ════════════════════════════════════════════════════════════════════════════════
# CasetaPeaje.gd — Controlador de Peaje con Talanquera Animada y Cobro en COP
# Panter Studio | Nuestra Tierra Job Simulator (Godot 4.7)
# ════════════════════════════════════════════════════════════════════════════════
extends Node3D
class_name CasetaPeaje

signal peaje_pagado(monto: float, categoria: String, vehiculo: Node)
signal barrera_abierta()
signal barrera_cerrada()

enum EstadoPeaje {
	CERRADO_ESPERANDO,
	COBRANDO,
	ABIERTO_PASO,
	CERRANDO
}

@export_group("Identificación y Tarifas")
## Nombre del peaje vial (ej. "Peaje de Chusacá", "Peaje de Chinauta")
@export var nombre_peaje: String = "Peaje de Chusacá"
## Tarifa Categoría I (Vehículos particulares y livianos)
@export var tarifa_cat_1: float = 14500.0
## Tarifa Categoría II (Buses y camiones medianos rígidos / NPR)
@export var tarifa_cat_2: float = 21000.0
## Tarifa Categoría Pesada (Tractomulas Kenworth T800, camiones pesados y articulados)
@export var tarifa_cat_pesada: float = 48500.0

@export_group("Mecánica de Barrera")
## Ángulo de rotación en grados de la talanquera cuando está levantada
@export var angulo_abierto_grados: float = 85.0
## Duración en segundos de la animación de subida/bajada de la talanquera
@export var duracion_movimiento_barrera: float = 0.85
## Tiempo máximo de cortesía en segundos con la barrera arriba antes de verificar paso
@export var tiempo_espera_abierta_segundos: float = 6.0

@export_group("Nodos de Control")
@export var nodo_talanquera: Node3D = null
@export var colision_barrera: CollisionShape3D = null
@export var semaforo_luz_roja: MeshInstance3D = null
@export var semaforo_luz_verde: MeshInstance3D = null
@export var display_texto_3d: Label3D = null
@export var area_cobro: Area3D = null
@export var area_salida: Area3D = null
@export var audio_player: AudioStreamPlayer3D = null

var estado_actual: EstadoPeaje = EstadoPeaje.CERRADO_ESPERANDO
var _vehiculo_en_caseta: Node = null
var _tween_barrera: Tween = null
var _rotacion_inicial_barrera: Vector3 = Vector3.ZERO
var _temporizador_paso: float = 0.0

# Materiales para luces de semáforo
var _mat_rojo: StandardMaterial3D = null
var _mat_verde: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("peajes")
	_inicializar_nodos()
	_preparar_materiales_semaforo()
	_actualizar_semaforo(false)
	_mostrar_pantalla("PARE\nPEAJE", Color(1.0, 0.25, 0.25))

func _process(delta: float) -> void:
	if estado_actual == EstadoPeaje.ABIERTO_PASO:
		_temporizador_paso += delta
		if _temporizador_paso >= tiempo_espera_abierta_segundos:
			if not _vehiculo_bloqueando_barrera():
				cerrar_barrera()

func _inicializar_nodos() -> void:
	if not nodo_talanquera:
		nodo_talanquera = find_child("BrazoTalanquera", true, false) as Node3D
		if not nodo_talanquera:
			nodo_talanquera = find_child("Talanquera", true, false) as Node3D

	if nodo_talanquera:
		_rotacion_inicial_barrera = nodo_talanquera.rotation_degrees

	if not colision_barrera and nodo_talanquera:
		colision_barrera = nodo_talanquera.find_child("CollisionShape3D", true, false) as CollisionShape3D

	if not semaforo_luz_roja:
		semaforo_luz_roja = find_child("LuzRoja", true, false) as MeshInstance3D
	if not semaforo_luz_verde:
		semaforo_luz_verde = find_child("LuzVerde", true, false) as MeshInstance3D
	if not display_texto_3d:
		display_texto_3d = find_child("DisplayTarifa", true, false) as Label3D

	if not area_cobro:
		area_cobro = find_child("AreaCobro", true, false) as Area3D
	if area_cobro:
		area_cobro.body_entered.connect(_on_area_cobro_body_entered)
		area_cobro.body_exited.connect(_on_area_cobro_body_exited)

	if not area_salida:
		area_salida = find_child("AreaSalida", true, false) as Area3D
	if area_salida:
		area_salida.body_exited.connect(_on_area_salida_body_exited)

func _preparar_materiales_semaforo() -> void:
	_mat_rojo = StandardMaterial3D.new()
	_mat_rojo.albedo_color = Color(1.0, 0.1, 0.1)
	_mat_rojo.emission_enabled = true
	_mat_rojo.emission = Color(1.0, 0.1, 0.1)
	_mat_rojo.emission_energy_multiplier = 3.5

	_mat_verde = StandardMaterial3D.new()
	_mat_verde.albedo_color = Color(0.1, 1.0, 0.3)
	_mat_verde.emission_enabled = true
	_mat_verde.emission = Color(0.1, 1.0, 0.3)
	_mat_verde.emission_energy_multiplier = 3.5

func _on_area_cobro_body_entered(body: Node) -> void:
	var vehiculo = _obtener_raiz_vehiculo(body)
	if not vehiculo:
		return

	_vehiculo_en_caseta = vehiculo
	if estado_actual == EstadoPeaje.CERRADO_ESPERANDO:
		_procesar_cobro_peaje(vehiculo)

func _on_area_cobro_body_exited(body: Node) -> void:
	var vehiculo = _obtener_raiz_vehiculo(body)
	if vehiculo and vehiculo == _vehiculo_en_caseta:
		pass

func _on_area_salida_body_exited(body: Node) -> void:
	var vehiculo = _obtener_raiz_vehiculo(body)
	if vehiculo and vehiculo == _vehiculo_en_caseta:
		_vehiculo_en_caseta = null
		cerrar_barrera()

func _procesar_cobro_peaje(vehiculo: Node) -> void:
	estado_actual = EstadoPeaje.COBRANDO
	var tarifa: float = tarifa_cat_1
	var categoria: String = "Cat. I (Liviano)"

	if _es_tractomula_o_pesado(vehiculo):
		tarifa = tarifa_cat_pesada
		categoria = "Cat. V (Tractomula / Pesado)"
	elif _es_camion_mediano(vehiculo):
		tarifa = tarifa_cat_2
		categoria = "Cat. II (Comercial / Bus)"

	var datos = get_node_or_null("/root/DatosUsuario")
	var saldo_actual: float = datos.dinero if datos else 9999999.0

	_mostrar_pantalla("TARIFA %s\n$%s COP" % [categoria, _formatear_pesos(tarifa)], Color(1.0, 0.85, 0.2))

	if saldo_actual < tarifa:
		_mostrar_pantalla("SALDO INSUFICIENTE\n$%s COP" % _formatear_pesos(tarifa), Color(1.0, 0.2, 0.2))
		_notificar_jugador("No tienes saldo suficiente para pagar el peaje ($%s COP)." % _formatear_pesos(tarifa), "alerta")
		estado_actual = EstadoPeaje.CERRADO_ESPERANDO
		return

	if datos:
		datos.dinero -= tarifa
		if datos.has_method("save_local"):
			datos.save_local()

	peaje_pagado.emit(tarifa, categoria, vehiculo)
	_mostrar_pantalla("PAGO EXITOSO\n¡BUEN VIAJE!", Color(0.2, 1.0, 0.4))
	_notificar_jugador("Peaje pagado: $%s COP (%s)" % [_formatear_pesos(tarifa), nombre_peaje], "exito")

	abrir_barrera()

func abrir_barrera() -> void:
	estado_actual = EstadoPeaje.ABIERTO_PASO
	_temporizador_paso = 0.0
	_actualizar_semaforo(true)

	if colision_barrera:
		colision_barrera.set_deferred("disabled", true)

	if nodo_talanquera:
		if _tween_barrera and _tween_barrera.is_running():
			_tween_barrera.kill()
		_tween_barrera = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var rot_objetivo = _rotacion_inicial_barrera + Vector3(0, 0, angulo_abierto_grados)
		_tween_barrera.tween_property(nodo_talanquera, "rotation_degrees", rot_objetivo, duracion_movimiento_barrera)

	barrera_abierta.emit()

func cerrar_barrera() -> void:
	if estado_actual == EstadoPeaje.CERRADO_ESPERANDO or estado_actual == EstadoPeaje.CERRANDO:
		return

	estado_actual = EstadoPeaje.CERRANDO
	_actualizar_semaforo(false)
	_mostrar_pantalla("PARE\nPEAJE", Color(1.0, 0.25, 0.25))

	if nodo_talanquera:
		if _tween_barrera and _tween_barrera.is_running():
			_tween_barrera.kill()
		_tween_barrera = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_tween_barrera.tween_property(nodo_talanquera, "rotation_degrees", _rotacion_inicial_barrera, duracion_movimiento_barrera * 1.1)
		_tween_barrera.tween_callback(func():
			if colision_barrera:
				colision_barrera.set_deferred("disabled", false)
			estado_actual = EstadoPeaje.CERRADO_ESPERANDO
			barrera_cerrada.emit()
		)
	else:
		estado_actual = EstadoPeaje.CERRADO_ESPERANDO
		barrera_cerrada.emit()

func _actualizar_semaforo(verde_activo: bool) -> void:
	var mat_apagado = StandardMaterial3D.new()
	mat_apagado.albedo_color = Color(0.15, 0.15, 0.15)
	mat_apagado.emission_enabled = false

	if semaforo_luz_roja:
		semaforo_luz_roja.material_override = mat_apagado if verde_activo else _mat_rojo
	if semaforo_luz_verde:
		semaforo_luz_verde.material_override = _mat_verde if verde_activo else mat_apagado

func _mostrar_pantalla(texto: String, color: Color) -> void:
	if display_texto_3d:
		display_texto_3d.text = texto
		display_texto_3d.modulate = color

func _vehiculo_bloqueando_barrera() -> bool:
	if area_cobro:
		for b in area_cobro.get_overlapping_bodies():
			if _obtener_raiz_vehiculo(b):
				return true
	return false

func _obtener_raiz_vehiculo(node: Node) -> Node:
	var curr = node
	while curr and curr != get_tree().current_scene:
		if curr.is_in_group("vehiculo") or curr.is_in_group("remolque") or curr.has_method("subir_jugador"):
			return curr
		curr = curr.get_parent()
	return null

func _es_tractomula_o_pesado(vehiculo: Node) -> bool:
	if vehiculo.name.to_lower().contains("t800") or vehiculo.name.to_lower().contains("mula") or vehiculo.name.to_lower().contains("tracto"):
		return true
	if vehiculo.is_in_group("remolque") or vehiculo.is_in_group("trailers"):
		return true
	if "mass" in vehiculo and float(vehiculo.get("mass")) > 9000.0:
		return true
	return false

func _es_camion_mediano(vehiculo: Node) -> bool:
	if vehiculo.name.to_lower().contains("npr") or vehiculo.name.to_lower().contains("kodiak") or vehiculo.name.to_lower().contains("prolet"):
		return true
	if "mass" in vehiculo and float(vehiculo.get("mass")) > 3500.0:
		return true
	return false

func _formatear_pesos(monto: float) -> String:
	var entero = int(monto)
	var str_val = str(entero)
	var res = ""
	var contador = 0
	for i in range(str_val.length() - 1, -1, -1):
		res = str_val[i] + res
		contador += 1
		if contador == 3 and i > 0:
			res = "." + res
			contador = 0
	return res

func _notificar_jugador(msg: String, tipo: String = "info") -> void:
	if has_node("/root/NotificationManager"):
		var nm = get_node("/root/NotificationManager")
		if tipo == "exito" and nm.has_method("notificar_exito"):
			nm.call("notificar_exito", msg)
			return
		elif tipo == "alerta" and nm.has_method("notificar_error"):
			nm.call("notificar_error", msg)
			return
	print("[Peaje] ", msg)
