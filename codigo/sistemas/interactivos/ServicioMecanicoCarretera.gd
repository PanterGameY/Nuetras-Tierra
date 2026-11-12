# ServicioMecanicoCarretera.gd - Sistema Autónomo de Asistencia Mecánica y Auxilio Vial con Tráfico IA
# Desarrollado para Nuestra Tierra 2.0 (Godot 4.7) - Panter Studio
# Integra despacho retrasado realista, navegación fluida en la red vial de tráfico IA (TrafficNetworkManager3D),
# aproximación cinemática detrás del camión/remolque, rótulos 3D llamativos, luces de emergencia,
# descenso del personaje mecánico (cápsula 3D), abastecimiento de combustible, reparación de llanta, motor y rescate.
extends Node3D
class_name ServicioMecanicoCarretera

signal asistencia_iniciada(tipo_servicio: int)
signal reparacion_completada(tipo_servicio: int)
signal vehiculo_retirado()

enum TipoServicio {
	COMBUSTIBLE = 0,
	PINCHAZO = 1,
	AVERIA_MECANICA = 2,
	DESVOLCAR_RESCATE = 3
}

enum EstadoAuxilio {
	INACTIVO = 0,
	DESPACHADO = 1,
	EN_RUTA_IA = 2,
	ESTACIONANDO = 3,
	TRABAJANDO = 4,
	RETIRADA = 5
}

const NOMBRES_SERVICIO: Dictionary = {
	TipoServicio.COMBUSTIBLE: "Suministro de Combustible",
	TipoServicio.PINCHAZO: "Cambio de Llanta Ponchada",
	TipoServicio.AVERIA_MECANICA: "Reparación de Avería de Motor",
	TipoServicio.DESVOLCAR_RESCATE: "Rescate y Desvolcado"
}

const TARIFAS: Dictionary = {
	TipoServicio.COMBUSTIBLE: 60000,
	TipoServicio.PINCHAZO: 85000,
	TipoServicio.AVERIA_MECANICA: 120000,
	TipoServicio.DESVOLCAR_RESCATE: 150000
}

static var instance: ServicioMecanicoCarretera = null

@export_group("Configuración de Despacho y Tráfico IA")
@export var demora_despacho_s: float = 3.5           # Tiempo de comunicación y despacho por radio
@export var distancia_spawn_carretera_m: float = 170.0 # Distancia atrás en la vía donde aparece el vehículo
@export var velocidad_crucero_ia_ms: float = 14.5      # ~52 km/h velocidad de circulación en el tráfico
@export var distancia_estacionamiento_m: float = 9.0   # Distancia de parada detrás del camión averiado
@export var duracion_reparacion_s: float = 5.5

# Referencias a nodos visuales
var chasis_camioneta: Node3D = null
var luces_estacionarias: Array[MeshInstance3D] = []
var torreta_ambar: MeshInstance3D = null
var cartel_mecanico: Label3D = null
var personaje_mecanico: Node3D = null
var prop_herramienta: Node3D = null

# Estado y navegación IA
var estado_actual: EstadoAuxilio = EstadoAuxilio.INACTIVO
var camión_objetivo: Node3D = null
var tipo_servicio_actual: int = TipoServicio.PINCHAZO
var rueda_objetivo_nombre: String = ""

var _posicion_estacionamiento: Vector3 = Vector3.ZERO
var _camino_ia: Path3D = null
var _path_follow_ia: PathFollow3D = null
var _sentido_ia: float = 1.0
var _notif_media_enviada: bool = false
var _hazard_tween: Tween = null
var _cartel_pulse_tween: Tween = null
var _en_servicio: bool = false

func _ready() -> void:
	instance = self
	add_to_group("servicio_mecanico")
	
	chasis_camioneta = get_node_or_null("ChasisCamioneta")
	torreta_ambar = get_node_or_null("ChasisCamioneta/TorretaAmbar")
	cartel_mecanico = get_node_or_null("ChasisCamioneta/CartelMecanico")
	personaje_mecanico = get_node_or_null("PersonajeMecanico")
	
	for l in find_children("*Estacionaria*", "MeshInstance3D", true, false):
		luces_estacionarias.append(l)
		
	if is_instance_valid(cartel_mecanico):
		_iniciar_pulso_cartel()

func _physics_process(delta: float) -> void:
	if estado_actual == EstadoAuxilio.EN_RUTA_IA:
		_procesar_transito_ia(delta)

# ═════════════════════════════════════════════════════════════════════════════
# API ESTÁTICA PÚBLICA
# ═════════════════════════════════════════════════════════════════════════════

static func solicitar_servicio(tipo: int = TipoServicio.PINCHAZO, objetivo: Node3D = null, rueda: String = "") -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return false
		
	var servicio = instance
	if not is_instance_valid(servicio) or not servicio.is_inside_tree():
		var escena = load("res://codigo/sistemas/interactivos/VehiculoMecanicoAsistencia.tscn")
		if not escena:
			push_error("[ServicioMecanico] No se pudo cargar VehiculoMecanicoAsistencia.tscn")
			return false
		servicio = escena.instantiate() as ServicioMecanicoCarretera
		var escena_activa = tree.current_scene
		if not escena_activa:
			escena_activa = tree.root
		escena_activa.add_child(servicio)
		
	if not is_instance_valid(objetivo):
		objetivo = resolver_vehiculo_cercano(tree)
		
	if not is_instance_valid(objetivo):
		if CelularUI.instance:
			CelularUI.instance.notificar("No se encontró ningún vehículo para asistir.", "alerta")
		return false
		
	return servicio.iniciar_servicio(objetivo, tipo, rueda)

func solicitar_asistencia(camion: RigidBody3D, rueda_nombre: String = "") -> bool:
	return iniciar_servicio(camion, TipoServicio.PINCHAZO, rueda_nombre)

static func resolver_vehiculo_cercano(tree: SceneTree) -> Node3D:
	var gestor = tree.root.get_node_or_null("GestorVehiculos")
	if gestor and "vehiculo_actual" in gestor and is_instance_valid(gestor.vehiculo_actual):
		return gestor.vehiculo_actual as Node3D
		
	var iv = tree.root.get_node_or_null("InputVehiculo")
	if iv and "vehiculo_actual" in iv and is_instance_valid(iv.vehiculo_actual):
		return iv.vehiculo_actual as Node3D
		
	var jugador = tree.get_first_node_in_group("jugador") as Node3D
	if not jugador and tree.current_scene:
		jugador = tree.current_scene.find_child("Jugador", true, false) as Node3D
		
	if is_instance_valid(jugador):
		if jugador.get("_conduciendo") == true and is_instance_valid(jugador.get("_vehiculo_actual")):
			return jugador.get("_vehiculo_actual") as Node3D
		if "vehiculo_actual" in jugador and is_instance_valid(jugador.vehiculo_actual):
			return jugador.vehiculo_actual as Node3D
			
		var vehiculos = tree.get_nodes_in_group("Vehiculo")
		if vehiculos.is_empty():
			vehiculos = tree.get_nodes_in_group("vehiculos")
		var menor_dist = 999999.0
		var veh_cercano: Node3D = null
		for v in vehiculos:
			if v is Node3D and is_instance_valid(v):
				var d = jugador.global_position.distance_to((v as Node3D).global_position)
				if d < menor_dist:
					menor_dist = d
					veh_cercano = v as Node3D
		if veh_cercano and menor_dist < 60.0:
			return veh_cercano
			
		return jugador
		
	if tree.current_scene:
		var t800 = tree.current_scene.find_child("T800_A", true, false) as Node3D
		if not t800:
			t800 = tree.current_scene.find_child("T800_Alargada", true, false) as Node3D
		if t800:
			return t800
			
	return null

static func puede_costear_servicio(tipo: int) -> bool:
	var costo = TARIFAS.get(tipo, 85000)
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return true
	var datos = tree.root.get_node_or_null("DatosUsuario")
	if datos and "dinero" in datos:
		return datos.dinero >= costo
	return true

# ═════════════════════════════════════════════════════════════════════════════
# INICIO Y DESPACHO CON TRÁFICO IA
# ═════════════════════════════════════════════════════════════════════════════

func iniciar_servicio(vehiculo: Node3D, tipo: int, rueda_nombre: String = "") -> bool:
	if _en_servicio:
		if CelularUI.instance:
			CelularUI.instance.notificar("La unidad de auxilio vial ya está en camino a tu posición.", "info")
		return false
		
	var costo = TARIFAS.get(tipo, 85000)
	var nombre_srv = NOMBRES_SERVICIO.get(tipo, "Auxilio Vial")
	
	# Verificar y debitar saldo
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and "dinero" in datos:
		if datos.dinero < costo:
			if CelularUI.instance:
				CelularUI.instance.notificar("Saldo insuficiente ($ %d). Solicita un préstamo en Nequi." % costo, "alerta")
			return false
		datos.dinero -= costo
		if datos.has_method("save_local"):
			datos.save_local()
			
	var nequi = get_node_or_null("/root/SistemaFinancieroNequi")
	if nequi and nequi.has_method("registrar_transaccion"):
		nequi.call("registrar_transaccion", "Auxilio Mecánico (%s)" % nombre_srv, -costo, "Servicios")
	elif CelularUI.instance:
		CelularUI.instance.registrar_movimiento_nequi("out", "Auxilio Mecánico (%s)" % nombre_srv, costo)
		
	camión_objetivo = vehiculo
	tipo_servicio_actual = tipo
	rueda_objetivo_nombre = rueda_nombre
	_en_servicio = true
	_notif_media_enviada = false
	estado_actual = EstadoAuxilio.DESPACHADO
	
	emit_signal("asistencia_iniciada", tipo)
	
	# Notificación diegética de llamada y despacho
	if CelularUI.instance:
		CelularUI.instance.notificar("📻 Central Auxilio Vial: Solicitud de %s aprobada (-$ %d). Despachando móvil con tráfico en ruta..." % [nombre_srv, costo], "exito")
		
	# Demora inicial de despacho realista (2.8 - 3.5 segundos)
	var tw_dispatch = create_tween()
	tw_dispatch.tween_interval(demora_despacho_s)
	tw_dispatch.tween_callback(func():
		_iniciar_transito_en_trafico_ia()
	)
	
	return true

func _iniciar_transito_en_trafico_ia() -> void:
	if not is_instance_valid(camión_objetivo):
		_en_servicio = false
		estado_actual = EstadoAuxilio.INACTIVO
		return
		
	# 1. Determinar referencia de cola y posición de parada final detrás
	var ref_node = camión_objetivo
	var remolque = _obtener_remolque_acoplado(camión_objetivo)
	if is_instance_valid(remolque):
		ref_node = remolque
		
	var ref_trans = ref_node.global_transform
	var forward = -ref_trans.basis.z.normalized()
	
	var dist_detras = distancia_estacionamiento_m
	if is_instance_valid(remolque):
		dist_detras += 3.5
		
	_posicion_estacionamiento = ref_trans.origin - (forward * dist_detras)
	_posicion_estacionamiento.y = _obtener_altura_suelo(_posicion_estacionamiento, ref_trans.origin.y)
	
	# 2. Buscar si el camión está sobre un carril de la red de tráfico IA
	var red_trafico = _obtener_gestor_trafico()
	var mejor_camino: Path3D = null
	var mejor_offset: float = 0.0
	var menor_dist: float = INF
	
	if red_trafico and "all_paths" in red_trafico and not red_trafico.all_paths.is_empty():
		for p in red_trafico.all_paths:
			if not is_instance_valid(p) or p.curve == null:
				continue
			var loc = p.to_local(_posicion_estacionamiento)
			var off = p.curve.get_closest_offset(loc)
			var pt_world = p.to_global(p.curve.sample_baked(off))
			var d = _posicion_estacionamiento.distance_to(pt_world)
			if d < menor_dist:
				menor_dist = d
				mejor_camino = p
				mejor_offset = off
				
	# 3. Configurar spawn integrado en el tráfico
	visible = true
	scale = Vector3.ONE
	_activar_luces_estacionarias(true)
	
	if mejor_camino != null and menor_dist <= 35.0:
		# Integrado directamente sobre la curva de tráfico de la carretera
		_camino_ia = mejor_camino
		var len_c = _camino_ia.curve.get_baked_length()
		
		# Determinar sentido de circulación respecto al camión
		var off_next = minf(mejor_offset + 3.0, len_c)
		var pt_next = _camino_ia.to_global(_camino_ia.curve.sample_baked(off_next))
		var pt_now = _camino_ia.to_global(_camino_ia.curve.sample_baked(mejor_offset))
		var dir_camino = (pt_next - pt_now).normalized()
		_sentido_ia = 1.0 if forward.dot(dir_camino) >= 0.0 else -1.0
		
		var spawn_offset = mejor_offset - (_sentido_ia * distancia_spawn_carretera_m)
		if spawn_offset < 0.0:
			spawn_offset = fposmod(spawn_offset, len_c)
		elif spawn_offset > len_c:
			spawn_offset = fposmod(spawn_offset, len_c)
			
		_path_follow_ia = PathFollow3D.new()
		_path_follow_ia.loop = true
		_path_follow_ia.rotation_mode = PathFollow3D.ROTATION_Y
		_camino_ia.add_child(_path_follow_ia)
		_path_follow_ia.progress = spawn_offset
		
		global_transform = _path_follow_ia.global_transform
		global_position.y = _obtener_altura_suelo(global_position, global_position.y)
	else:
		# Si está fuera de una carretera con Path3D, aparece a 150m en la vía más cercana
		_camino_ia = null
		_path_follow_ia = null
		var spawn_pos = _posicion_estacionamiento - (forward * distancia_spawn_carretera_m)
		spawn_pos.y = _obtener_altura_suelo(spawn_pos, _posicion_estacionamiento.y)
		global_position = spawn_pos
		look_at(_posicion_estacionamiento, Vector3.UP)
		
	estado_actual = EstadoAuxilio.EN_RUTA_IA
	
	if CelularUI.instance:
		CelularUI.instance.notificar("🚨 Móvil de auxilio vial en carretera transitando hacia tu ubicación...", "info")

func _procesar_transito_ia(delta: float) -> void:
	if not is_instance_valid(camión_objetivo):
		_retirar_camioneta_asistencia()
		return
		
	var dist_al_objetivo = global_position.distance_to(_posicion_estacionamiento)
	
	# Aviso intermedio de aproximación por radio
	if dist_al_objetivo <= 85.0 and not _notif_media_enviada:
		_notif_media_enviada = true
		if CelularUI.instance:
			CelularUI.instance.notificar("🛠️ Unidad de auxilio en aproximación final (a %d m de tu posición)..." % int(dist_al_objetivo), "info")
			
	if is_instance_valid(_path_follow_ia) and is_instance_valid(_camino_ia):
		# Avanzar con velocidad de tráfico IA
		_path_follow_ia.progress += _sentido_ia * velocidad_crucero_ia_ms * delta
		global_position = _path_follow_ia.global_position
		global_position.y = _obtener_altura_suelo(global_position, global_position.y)
		
		# Orientar mirando en el sentido de avance
		var len_c = _camino_ia.curve.get_baked_length()
		var next_off = fposmod(_path_follow_ia.progress + (_sentido_ia * 3.0), len_c)
		var next_pt = _camino_ia.to_global(_camino_ia.curve.sample_baked(next_off))
		var dir = (next_pt - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.1:
			var target_rot = Transform3D().looking_at(dir, Vector3.UP).basis
			global_transform.basis = global_transform.basis.slerp(target_rot, 7.0 * delta)
	else:
		# Movimiento cinemático de aproximación si no hay Path3D
		var dir = (_posicion_estacionamiento - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.5:
			var move_step = dir.normalized() * velocidad_crucero_ia_ms * delta
			global_position += move_step
			global_position.y = _obtener_altura_suelo(global_position, global_position.y)
			var target_rot = Transform3D().looking_at(dir, Vector3.UP).basis
			global_transform.basis = global_transform.basis.slerp(target_rot, 7.0 * delta)
			
	# Al llegar al rango de frenado y estacionamiento (~18 metros)
	if dist_al_objetivo <= 18.0:
		_iniciar_maniobra_estacionamiento()

func _iniciar_maniobra_estacionamiento() -> void:
	estado_actual = EstadoAuxilio.ESTACIONANDO
	
	# Liberar el PathFollow3D para hacer la parada precisa detrás del camión
	if is_instance_valid(_path_follow_ia):
		_path_follow_ia.queue_free()
		_path_follow_ia = null
		
	# Desaceleración y alineación exacta detrás del camión
	var tw_park = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_park.tween_property(self, "global_position", _posicion_estacionamiento, 2.8)
	
	tw_park.tween_callback(func():
		look_at(camión_objetivo.global_position, Vector3.UP)
		_reproducir_sfx_llegada()
		estado_actual = EstadoAuxilio.TRABAJANDO
		if CelularUI.instance:
			CelularUI.instance.notificar("👨‍🔧 La unidad de auxilio se ha estacionado detrás. Iniciando maniobras técnicas...", "info")
		_descender_mecanico()
	)

func _obtener_gestor_trafico() -> Node:
	var mgr = get_tree().get_first_node_in_group("traffic_network_manager")
	if not mgr and get_tree().current_scene:
		mgr = get_tree().current_scene.find_child("TrafficNetworkManager3D", true, false)
	return mgr

func _obtener_altura_suelo(pos: Vector3, fallback_y: float) -> float:
	if not is_inside_tree():
		return fallback_y
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(pos + Vector3(0, 10, 0), pos - Vector3(0, 25, 0))
	query.collision_mask = 1
	var hit = space.intersect_ray(query)
	if hit:
		return hit.position.y
	return fallback_y

func _obtener_remolque_acoplado(vehiculo: Node3D) -> RigidBody3D:
	var hitch = vehiculo.find_child("Enganche", true, false)
	if hitch and "conectado" in hitch and hitch.conectado and hitch.get("enganche_remoto"):
		if hitch.has_method("_buscar_cuerpo"):
			return hitch.call("_buscar_cuerpo", hitch.enganche_remoto) as RigidBody3D
	return null

# ═════════════════════════════════════════════════════════════════════════════
# SECUENCIA DEL MECÁNICO (CÁPSULA 3D)
# ═════════════════════════════════════════════════════════════════════════════

func _descender_mecanico() -> void:
	if not is_instance_valid(personaje_mecanico):
		personaje_mecanico = _crear_personaje_mecanico_capsula()
		
	personaje_mecanico.visible = true
	personaje_mecanico.position = Vector3(-1.45, 0.0, 0.5)
	_actualizar_prop_mecanico(tipo_servicio_actual)
	_reproducir_sfx_puerta()
	
	var target_world_pos = _calcular_posicion_trabajo()
	
	var tw_walk = create_tween().set_trans(Tween.TRANS_LINEAR)
	tw_walk.tween_property(personaje_mecanico, "global_position", target_world_pos, 2.8)
	
	var tw_bob = create_tween().set_loops(7)
	tw_bob.tween_property(personaje_mecanico, "position:y", 0.12, 0.20)
	tw_bob.tween_property(personaje_mecanico, "position:y", 0.0, 0.20)
	
	tw_walk.tween_callback(func():
		tw_bob.kill()
		personaje_mecanico.position.y = 0.0
		personaje_mecanico.look_at(camión_objetivo.global_position, Vector3.UP)
		_ejecutar_trabajo_mecanico()
	)

func _calcular_posicion_trabajo() -> Vector3:
	var c_trans = camión_objetivo.global_transform
	var forward = -c_trans.basis.z.normalized()
	var right = c_trans.basis.x.normalized()
	
	match tipo_servicio_actual:
		TipoServicio.COMBUSTIBLE:
			return c_trans.origin + (right * 1.5) - (forward * 0.4)
			
		TipoServicio.PINCHAZO:
			var sist_pinchazos = get_tree().get_first_node_in_group("sistema_pinchazos") as SistemaPinchazos
			if sist_pinchazos:
				if rueda_objetivo_nombre == "" or not sist_pinchazos.ruedas_estado.has(rueda_objetivo_nombre):
					for k in sist_pinchazos.ruedas_estado:
						if sist_pinchazos.ruedas_estado[k]["pinchada"]:
							rueda_objetivo_nombre = k
							break
				if rueda_objetivo_nombre != "" and sist_pinchazos.ruedas_estado.has(rueda_objetivo_nombre):
					var r = sist_pinchazos.ruedas_estado[rueda_objetivo_nombre]
					if r.get("raycast") and is_instance_valid(r["raycast"]):
						return r["raycast"].global_position + (right * 0.75)
			return c_trans.origin + (right * 1.4) + (forward * 1.2)
			
		TipoServicio.AVERIA_MECANICA:
			return c_trans.origin + (forward * 3.6)
			
		TipoServicio.DESVOLCAR_RESCATE:
			return c_trans.origin + (right * 2.8)
			
	return c_trans.origin + (right * 1.5)

func _ejecutar_trabajo_mecanico() -> void:
	var tw_crouch = create_tween()
	tw_crouch.tween_property(personaje_mecanico, "scale:y", 0.55, 0.35)
	tw_crouch.parallel().tween_property(personaje_mecanico, "position:y", -0.38, 0.35)
	
	match tipo_servicio_actual:
		TipoServicio.COMBUSTIBLE:
			_reproducir_sfx_combustible()
			if CelularUI.instance:
				CelularUI.instance.notificar("⛽ Suministrando combustible al tanque desde el bidón de emergencia...", "info")
				
		TipoServicio.PINCHAZO:
			_reproducir_sfx_gato_y_llave()
			if CelularUI.instance:
				CelularUI.instance.notificar("🛞 Mecánico usando gato hidráulico y llave neumática para montar repuesto...", "info")
				
		TipoServicio.AVERIA_MECANICA:
			_reproducir_sfx_reparacion_motor()
			if CelularUI.instance:
				CelularUI.instance.notificar("🔧 Diagnosticando inyección, circuito eléctrico y reparando avería...", "info")
				
		TipoServicio.DESVOLCAR_RESCATE:
			_reproducir_sfx_winche()
			if CelularUI.instance:
				CelularUI.instance.notificar("🏗️ Asegurando guayas y aplicando tracción con winche hidráulico...", "info")
				
	var tw_work = create_tween()
	tw_work.tween_interval(duracion_reparacion_s)
	tw_work.tween_callback(func():
		_completar_servicio_en_vehiculo()
		_levantar_y_retirar_mecanico()
	)

func _completar_servicio_en_vehiculo() -> void:
	match tipo_servicio_actual:
		TipoServicio.COMBUSTIBLE:
			if has_node("/root/InputVehiculo"):
				var iv = get_node("/root/InputVehiculo")
				iv.set("combustible", maxf(float(iv.get("combustible")), 50.0))
				iv.set("motor_encendido", false)
				
			var motor = camión_objetivo.find_child("Motor", true, false)
			if motor and "nivel_combustible_l" in motor and "capacidad_combustible_l" in motor:
				motor.nivel_combustible_l = maxf(motor.nivel_combustible_l, 140.0)
				motor.set("encendido", false)
				
			if CelularUI.instance:
				CelularUI.instance.notificar("✅ Tanque reabastecido con 140 L. ¡Ya puedes encender el motor!", "exito")
				
		TipoServicio.PINCHAZO:
			var sist_pinchazos = get_tree().get_first_node_in_group("sistema_pinchazos") as SistemaPinchazos
			if sist_pinchazos:
				sist_pinchazos.reparar_por_mecanico_asistencia()
			if CelularUI.instance:
				CelularUI.instance.notificar("✅ Rueda ponchada reemplazada. Presión a 110 PSI y repuesto listo.", "exito")
				
		TipoServicio.AVERIA_MECANICA:
			var motor = camión_objetivo.find_child("Motor", true, false)
			if motor:
				if "temperatura" in motor:
					motor.temperatura = 85.0
				if "temperatura_motor" in motor:
					motor.temperatura_motor = 85.0
				if "falla_motor_activa" in motor:
					motor.falla_motor_activa = false
				if "tipo_falla" in motor:
					motor.tipo_falla = ""
				if "averiado" in motor:
					motor.averiado = false
			if has_node("/root/InputVehiculo"):
				var iv = get_node("/root/InputVehiculo")
				iv.set("motor_encendido", false)
			if CelularUI.instance:
				CelularUI.instance.notificar("✅ Motor y transmisión calibrados al 100%. Vehículo operativo.", "exito")
				
		TipoServicio.DESVOLCAR_RESCATE:
			_enderezar_vehiculo(camión_objetivo)
			var remolque = _obtener_remolque_acoplado(camión_objetivo)
			if is_instance_valid(remolque):
				_enderezar_vehiculo(remolque)
			if CelularUI.instance:
				CelularUI.instance.notificar("✅ Vehículo enderezado y estabilizado sobre el pavimento.", "exito")
				
	emit_signal("reparacion_completada", tipo_servicio_actual)

func _enderezar_vehiculo(cuerpo: Node3D) -> void:
	if not is_instance_valid(cuerpo):
		return
	if cuerpo is RigidBody3D:
		var rb = cuerpo as RigidBody3D
		rb.freeze = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		var ground_y = _obtener_altura_suelo(rb.global_position, rb.global_position.y)
		var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(rb, "rotation:z", 0.0, 1.2)
		tw.parallel().tween_property(rb, "rotation:x", 0.0, 1.2)
		tw.parallel().tween_property(rb, "global_position:y", ground_y + 0.35, 1.2)
		tw.tween_callback(func():
			if is_instance_valid(rb):
				rb.freeze = false
				rb.linear_velocity = Vector3.ZERO
				rb.angular_velocity = Vector3.ZERO
		)
	else:
		cuerpo.rotation.z = 0.0
		cuerpo.rotation.x = 0.0
		cuerpo.global_position.y = _obtener_altura_suelo(cuerpo.global_position, cuerpo.global_position.y) + 0.35

func _levantar_y_retirar_mecanico() -> void:
	var tw_stand = create_tween()
	tw_stand.tween_property(personaje_mecanico, "scale:y", 1.0, 0.35)
	tw_stand.parallel().tween_property(personaje_mecanico, "position:y", 0.0, 0.35)
	
	var tw_back = create_tween().set_trans(Tween.TRANS_LINEAR)
	var door_world_pos = to_global(Vector3(-1.45, 0.0, 0.5))
	tw_back.tween_property(personaje_mecanico, "global_position", door_world_pos, 2.5)
	
	tw_back.tween_callback(func():
		_reproducir_sfx_puerta()
		personaje_mecanico.visible = false
		_retirar_camioneta_asistencia()
	)

func _retirar_camioneta_asistencia() -> void:
	estado_actual = EstadoAuxilio.RETIRADA
	if CelularUI.instance:
		CelularUI.instance.notificar("La unidad de auxilio vial se retira integrándose nuevamente al flujo vial. ¡Buen viaje!", "info")
		
	var tw_leave = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var forward = -global_transform.basis.z.normalized()
	tw_leave.tween_property(self, "global_position", global_position + (forward * 42.0), 4.2)
	tw_leave.parallel().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 4.2)
	
	tw_leave.tween_callback(func():
		_activar_luces_estacionarias(false)
		if _cartel_pulse_tween:
			_cartel_pulse_tween.kill()
		visible = false
		_en_servicio = false
		estado_actual = EstadoAuxilio.INACTIVO
		emit_signal("vehiculo_retirado")
		queue_free()
	)

# ═════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN VISUAL DEL PERSONAJE (CÁPSULA 3D + UTILERÍA)
# ═════════════════════════════════════════════════════════════════════════════

func _crear_personaje_mecanico_capsula() -> Node3D:
	var nodo = Node3D.new()
	nodo.name = "PersonajeMecanico"
	
	var mesh_inst = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.65
	mesh_inst.mesh = cap
	var mat_overol = StandardMaterial3D.new()
	mat_overol.albedo_color = Color(0.12, 0.32, 0.68)
	mat_overol.roughness = 0.6
	mesh_inst.material_override = mat_overol
	mesh_inst.position.y = 0.82
	nodo.add_child(mesh_inst)
	
	var mesh_chaleco = MeshInstance3D.new()
	var box_ch = BoxMesh.new()
	box_ch.size = Vector3(0.58, 0.70, 0.58)
	mesh_chaleco.mesh = box_ch
	var mat_chaleco = StandardMaterial3D.new()
	mat_chaleco.albedo_color = Color(1.0, 0.45, 0.05)
	mat_chaleco.roughness = 0.4
	mesh_chaleco.material_override = mat_chaleco
	mesh_chaleco.position.y = 0.88
	nodo.add_child(mesh_chaleco)
	
	var mesh_casco = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.34
	mesh_casco.mesh = sph
	var mat_casco = StandardMaterial3D.new()
	mat_casco.albedo_color = Color(0.96, 0.96, 0.98)
	mat_casco.roughness = 0.3
	mesh_casco.material_override = mat_casco
	mesh_casco.position.y = 1.62
	nodo.add_child(mesh_casco)
	
	prop_herramienta = Node3D.new()
	prop_herramienta.name = "PropHerramienta"
	prop_herramienta.position = Vector3(0.38, 0.50, -0.15)
	nodo.add_child(prop_herramienta)
	
	add_child(nodo)
	return nodo

func _actualizar_prop_mecanico(tipo: int) -> void:
	if not is_instance_valid(prop_herramienta):
		return
	for c in prop_herramienta.get_children():
		c.queue_free()
		
	match tipo:
		TipoServicio.COMBUSTIBLE:
			var mesh_bidon = MeshInstance3D.new()
			var b = BoxMesh.new()
			b.size = Vector3(0.24, 0.36, 0.18)
			mesh_bidon.mesh = b
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.15, 0.12)
			mesh_bidon.material_override = mat
			prop_herramienta.add_child(mesh_bidon)
			
			var boquilla = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.02
			cyl.bottom_radius = 0.03
			cyl.height = 0.16
			boquilla.mesh = cyl
			boquilla.position = Vector3(0.08, 0.22, 0.0)
			boquilla.rotation.z = deg_to_rad(-35)
			prop_herramienta.add_child(boquilla)
			
		TipoServicio.PINCHAZO:
			var caja = MeshInstance3D.new()
			var b = BoxMesh.new()
			b.size = Vector3(0.28, 0.22, 0.38)
			caja.mesh = b
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.15, 0.15, 0.18)
			caja.material_override = mat
			prop_herramienta.add_child(caja)
			
		TipoServicio.AVERIA_MECANICA:
			var caja = MeshInstance3D.new()
			var b = BoxMesh.new()
			b.size = Vector3(0.26, 0.24, 0.42)
			caja.mesh = b
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.90, 0.12, 0.12)
			caja.material_override = mat
			prop_herramienta.add_child(caja)
			
		TipoServicio.DESVOLCAR_RESCATE:
			var control = MeshInstance3D.new()
			var b = BoxMesh.new()
			b.size = Vector3(0.14, 0.22, 0.14)
			control.mesh = b
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.8, 0.05)
			control.material_override = mat
			prop_herramienta.add_child(control)

# ═════════════════════════════════════════════════════════════════════════════
# EFECTOS VISUALES Y SONOROS
# ═════════════════════════════════════════════════════════════════════════════

func _iniciar_pulso_cartel() -> void:
	if not is_instance_valid(cartel_mecanico):
		return
	if _cartel_pulse_tween:
		_cartel_pulse_tween.kill()
		
	_cartel_pulse_tween = create_tween().set_loops()
	_cartel_pulse_tween.tween_property(cartel_mecanico, "modulate", Color(1.0, 0.95, 0.3, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	_cartel_pulse_tween.tween_property(cartel_mecanico, "modulate", Color(0.95, 0.65, 0.1, 0.85), 0.7).set_trans(Tween.TRANS_SINE)

func _activar_luces_estacionarias(activar: bool) -> void:
	if _hazard_tween:
		_hazard_tween.kill()
		_hazard_tween = null
		
	if not activar:
		for l in luces_estacionarias:
			if is_instance_valid(l) and l.material_override is StandardMaterial3D:
				(l.material_override as StandardMaterial3D).emission_enabled = false
		if is_instance_valid(torreta_ambar) and torreta_ambar.material_override is StandardMaterial3D:
			(torreta_ambar.material_override as StandardMaterial3D).emission_enabled = false
		return
		
	_hazard_tween = create_tween().set_loops()
	_hazard_tween.tween_callback(func():
		_set_hazard_emission(true)
	)
	_hazard_tween.tween_interval(0.38)
	_hazard_tween.tween_callback(func():
		_set_hazard_emission(false)
	)
	_hazard_tween.tween_interval(0.38)

func _set_hazard_emission(encendidas: bool) -> void:
	var col = Color(1.0, 0.68, 0.05, 1.0) if encendidas else Color(0.1, 0.1, 0.1, 1.0)
	for l in luces_estacionarias:
		if is_instance_valid(l) and l.material_override is StandardMaterial3D:
			var mat = l.material_override as StandardMaterial3D
			mat.emission_enabled = encendidas
			mat.emission = col
			mat.emission_energy_multiplier = 4.0 if encendidas else 0.0
			
	if is_instance_valid(torreta_ambar) and torreta_ambar.material_override is StandardMaterial3D:
		var mat_t = torreta_ambar.material_override as StandardMaterial3D
		mat_t.emission_enabled = encendidas
		mat_t.emission_energy_multiplier = 5.0 if encendidas else 0.0

func _reproducir_sfx_llegada() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXLlegada"
	var stream = load("res://recursos/sonidos_vehiculo/motor/automovil/claxon 1.mp3")
	if not stream:
		stream = load("res://recursos/efectos/checkpoint.mp3")
	if stream:
		sfx.stream = stream
		sfx.pitch_scale = 1.3
		sfx.unit_size = 15.0
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

func _reproducir_sfx_puerta() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXPuerta"
	var stream = load("res://recursos/efectos/golpear_puerta.mp3")
	if stream:
		sfx.stream = stream
		sfx.unit_size = 12.0
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

func _reproducir_sfx_gato_y_llave() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXHidraulico"
	var stream = load("res://recursos/sonidos_vehiculo/efectos/Hidraulico.mp3")
	if not stream:
		stream = load("res://recursos/sonidos_vehiculo/efectos/golpe_metal.mp3")
	if stream:
		sfx.stream = stream
		sfx.unit_size = 14.0
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

func _reproducir_sfx_combustible() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXCombustible"
	var stream = load("res://recursos/sonidos_vehiculo/efectos/seleccion1.mp3")
	if stream:
		sfx.stream = stream
		sfx.pitch_scale = 0.85
		sfx.unit_size = 10.0
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

func _reproducir_sfx_reparacion_motor() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXMotorRepara"
	var stream = load("res://recursos/sonidos_vehiculo/efectos/golpe_metal.mp3")
	if stream:
		sfx.stream = stream
		sfx.pitch_scale = 1.15
		sfx.unit_size = 14.0
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

func _reproducir_sfx_winche() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXWinche"
	var stream = load("res://recursos/sonidos_vehiculo/efectos/Hidraulico.mp3")
	if stream:
		sfx.stream = stream
		sfx.pitch_scale = 0.75
		sfx.unit_size = 16.0
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())
