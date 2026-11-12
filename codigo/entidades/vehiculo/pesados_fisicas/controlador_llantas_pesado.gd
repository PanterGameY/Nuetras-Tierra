# controlador_llantas_pesado.gd - Controlador unificado de ruedas, frenos y dirección para vehículos pesados
extends Node3D

var llantas_todas: Array[RayCast3D] = []
var llantas_directrices: Array[RayCast3D] = []
var llantas_motrices: Array[RayCast3D] = []

var angulo_max_giro: float = 0.61
var wheelbase: float = 5.4
var _iv_cache: Node = null

func _get_iv() -> Node:
	if is_instance_valid(_iv_cache):
		return _iv_cache
	if is_inside_tree():
		_iv_cache = get_node_or_null("/root/InputVehiculo")
	return _iv_cache

func _ready() -> void:
	var coche = get_parent()
	if coche:
		await get_tree().process_frame
		if "llantas_todas" in coche:
			llantas_todas = coche.get("llantas_todas")
		if "llantas_directrices" in coche:
			llantas_directrices = coche.get("llantas_directrices")
		if "llantas_motrices" in coche:
			llantas_motrices = coche.get("llantas_motrices")
		_emparejar_ruedas_eje()

func _emparejar_ruedas_eje() -> void:
	for a in llantas_todas:
		if not is_instance_valid(a):
			continue
		var mejor_opuesta: Node = null
		var menor_dist_z: float = INF
		var mejor_tandem: Node = null
		var menor_dist_tandem_z: float = INF
		
		for b in llantas_todas:
			if b == a or not is_instance_valid(b):
				continue
			# Rueda opuesta en el mismo eje (X de signo opuesto, Z similar)
			if (a.position.x * b.position.x) < 0.0:
				var dist_z = absf(a.position.z - b.position.z)
				if dist_z < 0.40 and dist_z < menor_dist_z:
					menor_dist_z = dist_z
					mejor_opuesta = b
			# Rueda tándem en el mismo lado (mismo signo en X, diferente Z en el bogie trasero)
			elif (a.position.x * b.position.x) > 0.0:
				var dist_tandem = absf(a.position.z - b.position.z)
				if dist_tandem > 0.50 and dist_tandem < 2.20 and dist_tandem < menor_dist_tandem_z:
					menor_dist_tandem_z = dist_tandem
					mejor_tandem = b

		if mejor_opuesta:
			a.set("rueda_opuesta", mejor_opuesta)
		if mejor_tandem:
			a.set("rueda_tandem", mejor_tandem)

func recibir_par_motor(par: float) -> void:
	var coche = get_parent()
	if coche:
		var motor = coche.get_node_or_null("Motor")
		if motor and "fuerza_ruedas" in motor:
			motor.fuerza_ruedas = par

func aplicar_freno(freno_norm: float) -> void:
	set_fuerza_freno(clampf(freno_norm, 0.0, 1.0) * 20000.0)

func set_fuerza_freno(freno: float) -> void:
	for rueda in llantas_todas:
		if is_instance_valid(rueda) and "fuerza_freno" in rueda:
			rueda.fuerza_freno = freno

func set_freno_mano(activo_fm: bool) -> void:
	for rueda in llantas_todas:
		if is_instance_valid(rueda) and "fuerza_freno_mano" in rueda:
			rueda.fuerza_freno_mano = 38000.0 if activo_fm else 0.0

func get_direccion_normalizada() -> float:
	if llantas_directrices.size() > 0:
		var sum_angle := 0.0
		var count := 0
		for rueda in llantas_directrices:
			if is_instance_valid(rueda):
				if "angulo_direccion" in rueda:
					sum_angle += float(rueda.angulo_direccion)
					count += 1
				elif "_angulo_actual" in rueda:
					sum_angle += float(rueda.get("_angulo_actual"))
					count += 1
		if count > 0:
			var max_rad := angulo_max_giro if angulo_max_giro > 0.001 else 0.61
			return clampf(-sum_angle / (float(count) * max_rad), -1.0, 1.0)

	var iv = _get_iv()
	if is_instance_valid(iv) and "direccion" in iv:
		return clampf(float(iv.direccion), -1.0, 1.0)

	return 0.0

func get_velocidad_kmh() -> float:
	var coche = get_parent()
	if is_instance_valid(coche) and coche is RigidBody3D:
		return float(coche.linear_velocity.length() * 3.6)
	return 0.0
