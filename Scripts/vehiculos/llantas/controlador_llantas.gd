# controlador_llantas.gd
extends Node3D

# --- CONFIGURACIÓN ---
@export_group("Dirección")
@export var angulo_max_giro: float = 0.55 # Radianes (~32 grados)
@export var suavizado_volante: float = 8.0
@export var suavizado_movil: float = 12.0
@export var wheelbase: float = 2.5 # Distancia entre ejes para Ackermann
@export var track_width: float = 1.6 # Distancia entre ruedas del mismo eje

@export_group("Frenos")
@export var fuerza_freno_max: float = 2000.0 # Torque máximo de frenado
@export var bias_delantero: float = 0.65
@export var bias_trasero: float = 0.35

# --- VARIABLES INTERNAS ---
var llantas_todas: Array[Llanta] = []
var llantas_motrices: Array[Llanta] = []
var llantas_directrices: Array[Llanta] = []

func _ready() -> void:
	# Esperar a que los hijos se asienten
	await get_tree().process_frame
	_preparar_subsistemas()

func _preparar_subsistemas() -> void:
	llantas_todas.clear()
	llantas_motrices.clear()
	llantas_directrices.clear()
	
	for hijo in get_children():
		if hijo is Llanta:
			llantas_todas.append(hijo)
			if hijo.es_tractriz:
				llantas_motrices.append(hijo)
			if hijo.es_directriz:
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

func _physics_process(delta: float) -> void:
	if llantas_directrices.is_empty(): return
	
	# Obtener input centralizado
	var input_dir = InputVehiculo.direccion
	_actualizar_direccion(input_dir, delta)

func _actualizar_direccion(input: float, delta: float) -> void:
	var suavizado = suavizado_movil if OS.has_feature("mobile") else suavizado_volante
	
	for l in llantas_directrices:
		# --- GEOMETRÍA ACKERMANN REAL ---
		# Calcula el ángulo exacto para que cada rueda siga su radio de giro único
		var angulo_target = 0.0
		if abs(input) > 0.001:
			var es_izquierda = l.position.x < 0.0
			var angulo_base = abs(input) * angulo_max_giro
			if abs(angulo_base) < 0.001:
				angulo_base = 0.001
			var radio_giro = wheelbase / tan(angulo_base)
			
			# Ajustamos el radio según si la rueda es interna o externa a la curva
			# Input > 0 es giro a la derecha
			var es_interna = (input > 0.0 and !es_izquierda) or (input < 0.0 and es_izquierda)
			
			if es_interna:
				angulo_target = atan(wheelbase / max(radio_giro - (track_width / 2.0), 0.05))
			else:
				angulo_target = atan(wheelbase / max(radio_giro + (track_width / 2.0), 0.05))
			
			# Mantener el signo original del giro
			angulo_target *= sign(input)
		
		# Aplicar lerp al ángulo actual de la llanta
		var nuevo_angulo = lerp(l.angulo_direccion, angulo_target, suavizado * delta)
		l.aplicar_angulo_direccion(nuevo_angulo)

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
	if llantas_motrices.is_empty(): return

	# Umbral de zona muerta para el motor
	if abs(torque_total) < 0.5:
		for l in llantas_motrices:
			l.set_drive_torque(0.0)
		return

	# Reparto de par motor (Diferencial abierto simple)
	var par_por_rueda = torque_total / llantas_motrices.size()
	for l in llantas_motrices:
		l.set_drive_torque(par_por_rueda)

func aplicar_freno(intensidad: float) -> void:
	intensidad = clamp(intensidad, 0.0, 1.0)
	var freno_mano_activo = InputVehiculo.freno_mano

	for l in llantas_todas:
		# Reparto por eje en intensidad normalizada (0..1).
		# set_brake() ya convierte intensidad a torque interno de la llanta.
		var bias = bias_delantero if l.es_directriz else bias_trasero
		var intensidad_rueda = clamp(intensidad * bias, 0.0, 1.0)
		
		# Si la rueda tiene freno de mano, aplicamos bloqueo total o extra
		var usar_freno_mano = freno_mano_activo and l.es_freno_mano
		
		l.set_brake(intensidad_rueda, usar_freno_mano)

# Función de utilidad si el coche cambia de configuración en tiempo real (ej. entrar a boxes)
func refrescar_configuracion() -> void:
	_preparar_subsistemas()