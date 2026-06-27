# controlador_llantas.gd
extends Node3D

@export_group("Frenos")
@export var fuerza_freno_max: float = 2000.0

@export_group("Debug")
@export var debug_finder: bool = false

@export_group("Grip")
@export var grip_multiplier: float = 1.25

@export_group("Dirección")
@export var angulo_max_giro: float = 0.9
var suavizado_volante: float = 4.0
var suavizado_movil: float = 12.0
var wheelbase: float = 2.5
var track_width: float = 1.6
var bias_delantero: float = 0.45
var bias_trasero: float = 0.55
var _configurado: bool = false

func configurar_desde_vehiculo(cfg: VehiculoConfig) -> void:
	if _configurado:
		return
	_configurado = true
	angulo_max_giro = cfg.angulo_max_giro
	suavizado_volante = cfg.suavizado_volante
	suavizado_movil = cfg.suavizado_movil
	wheelbase = cfg.wheelbase
	track_width = cfg.track_width
	bias_delantero = cfg.bias_delantero
	bias_trasero = cfg.bias_trasero

# --- VARIABLES INTERNAS ---
var llantas_todas: Array = []
var llantas_motrices: Array = []
var llantas_directrices: Array = []

func _ready() -> void:
	# Esperar a que los hijos se asienten
	await get_tree().process_frame
	_preparar_subsistemas()

func _preparar_subsistemas() -> void:
	llantas_todas.clear()
	llantas_motrices.clear()
	llantas_directrices.clear()
	
	for hijo in get_children():
		# Evitar dependencia de class_name durante la carga: detectar por API disponible
		if hijo and (hijo.has_method("set_drive_torque") or hijo.has_method("get_resultant_force")):
			llantas_todas.append(hijo)
			if typeof(hijo.get("es_tractriz")) != TYPE_NIL and hijo.get("es_tractriz"):
				llantas_motrices.append(hijo)
			if typeof(hijo.get("es_directriz")) != TYPE_NIL and hijo.get("es_directriz"):
				llantas_directrices.append(hijo)
	
	if llantas_todas.is_empty():
		push_warning("ControladorLlantas: No se encontraron nodos de tipo Llanta.")
		return

	# Recuperación automática: si no hay llantas directrices configuradas,
	# asumimos como directrices el eje delantero (menor Z local).
	if llantas_directrices.is_empty():
		_auto_configurar_directrices()

	# Recuperación automática: si no hay motrices, asumimos tracción trasera (mayor Z local).
	if llantas_motrices.is_empty():
		_auto_configurar_motrices()

	# DEBUG: informar sobre llantas encontradas
	if debug_finder:
		# Propagar debug a ruedas para obtener más información
		for l in llantas_todas:
			if typeof(l.set) == TYPE_NIL:
				# intentar asignación directa
				if typeof(l.debug_llanta) != TYPE_NIL:
					l.debug_llanta = true
			else:
				# si el nodo soporta setters, intentar set
				l.set("debug_llanta", true)

		# Propagar multiplicador de agarre a cada rueda para ajuste global
		for l in llantas_todas:
			if typeof(l.set) == TYPE_NIL:
				if typeof(l.grip_multiplier) != TYPE_NIL:
					l.grip_multiplier = grip_multiplier
			else:
				l.set("grip_multiplier", grip_multiplier)

func _physics_process(delta: float) -> void:
	if llantas_directrices.is_empty(): return
	
	# Obtener input centralizado
	var input_dir = InputVehiculo.direccion
	_actualizar_direccion(input_dir, delta)

func _actualizar_direccion(input: float, delta: float) -> void:
	var suavizado = max(suavizado_volante, suavizado_movil)
	
	for l in llantas_directrices:
		var angulo_target = 0.0
		if abs(input) > 0.001:
			var es_izquierda = l.position.x < 0.0
			var angulo_base = abs(input) * angulo_max_giro
			angulo_base = max(angulo_base, 0.001)
			var denom := tan(angulo_base)
			if abs(denom) < 1e-6:
				denom = 1e-6
			var radio_giro = wheelbase / denom
			
			var es_interna = (input > 0.0 and !es_izquierda) or (input < 0.0 and es_izquierda)
			
			if es_interna:
				angulo_target = atan(wheelbase / max(radio_giro - (track_width / 2.0), 0.05))
			else:
				angulo_target = atan(wheelbase / max(radio_giro + (track_width / 2.0), 0.05))
			
			angulo_target *= sign(input)
		
		var nuevo_angulo = lerp(l.angulo_direccion, angulo_target, suavizado * delta)
		l.aplicar_angulo_direccion(nuevo_angulo)

## Devuelve la suma de fuerzas aplicadas por todas las llantas (si las llantas exponen get_resultant_force)
func obtener_fuerza_total_llantas() -> Vector3:
	var fuerza_total: Vector3 = Vector3.ZERO
	for l in llantas_todas:
		if l and l.has_method("get_resultant_force"):
			fuerza_total += l.get_resultant_force()
	return fuerza_total

func _auto_configurar_directrices() -> void:
	if llantas_todas.size() < 2:
		return

	var z_min = INF
	for l in llantas_todas:
		z_min = min(z_min, l.position.z)

	for l in llantas_todas:
		if abs(l.position.z - z_min) < 0.25:
			l.es_directriz = true
			if not llantas_directrices.has(l):
				llantas_directrices.append(l)

func _auto_configurar_motrices() -> void:
	if llantas_todas.is_empty():
		return

	var z_max = -INF
	for l in llantas_todas:
		z_max = max(z_max, l.position.z)

	for l in llantas_todas:
		if abs(l.position.z - z_max) < 0.25:
			l.es_tractriz = true
			if not llantas_motrices.has(l):
				llantas_motrices.append(l)

func recibir_par_motor(torque_total: float) -> void:
	if llantas_motrices.is_empty():
		return

	# Umbral de zona muerta para el motor
	if abs(torque_total) < 0.5:
		for l in llantas_motrices:
			l.set_drive_torque(0.0)
		return

	# Diferencial limitado simple (LSD-like): repartir torque según carga normal de cada rueda
	var total_normal: float = 0.0
	for l in llantas_motrices:
		# usar la fuerza normal calculada por la llanta; si no existe, usar 1.0 como fallback
		var fn: float = 0.0
		if l and typeof(l.fuerza_normal_anterior) != TYPE_NIL:
			fn = max(float(l.fuerza_normal_anterior), 0.0)
		else:
			fn = 1.0
		total_normal += max(fn, 0.01)

	if total_normal <= 0.0:
		# Fallback: reparto equitativo
		var par_por_rueda = torque_total / llantas_motrices.size()
		for l in llantas_motrices:
			l.set_drive_torque(par_por_rueda)
		return

	for l in llantas_motrices:
		var fn_local: float = max(float(l.fuerza_normal_anterior) if typeof(l.fuerza_normal_anterior) != TYPE_NIL else 1.0, 0.01)
		var share: float = fn_local / total_normal
		var torque_rueda: float = torque_total * share
		# limitar el torque por rueda si es necesario para evitar picos
		l.set_drive_torque(torque_rueda)

func aplicar_freno(intensidad: float) -> void:
	intensidad = clamp(intensidad, 0.0, 1.0)
	var freno_mano_activo = InputVehiculo.freno_mano

	# Calcular carga normal promedio para normalizar efecto de la carga
	var suma_normal: float = 0.0
	for l in llantas_todas:
		suma_normal += l.fuerza_normal_anterior if typeof(l.fuerza_normal_anterior) != TYPE_NIL else 0.0
	var normal_prom: float = suma_normal / max(1, llantas_todas.size())

	for l in llantas_todas:
		var bias: float = bias_delantero if l.es_directriz else bias_trasero
		# Cálculo de ajuste por carga (fallbacks conservadores)
		var carga_local: float = 0.0
		if typeof(l.fuerza_normal_anterior) != TYPE_NIL:
			carga_local = float(l.fuerza_normal_anterior)
		elif normal_prom > 0.0:
			carga_local = normal_prom
		else:
			carga_local = 1.0

		var ajuste_carga: float = carga_local / max(normal_prom, 1.0)

		# Aplicar intensidad por rueda directamente: presion global * bias * ajuste_carga
		var intensidad_rueda: float = clamp(intensidad * bias * ajuste_carga, 0.0, 1.0)
		var usar_freno_mano: bool = freno_mano_activo and l.es_freno_mano
		l.set_brake(intensidad_rueda, usar_freno_mano)

# Función de utilidad si el coche cambia de configuración en tiempo real (ej. entrar a boxes)
func refrescar_configuracion() -> void:
	_preparar_subsistemas()
