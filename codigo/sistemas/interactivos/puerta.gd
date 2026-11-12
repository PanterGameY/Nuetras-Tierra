extends MeshInstance3D

# puerta.gd
# Este script permite físicas/rotación suave para una puerta basándose en empuje físico.
# Para evitar el gasto constante de físicas y colisiones, la puerta solo actúa dinámicamente
# (y activa su área/cuerpo) cuando el jugador está dentro de su área de proximidad.
# Cuando el jugador no está cerca o no la está empujando, la puerta rota suavemente de regreso
# a su ángulo de rotación original (posición cerrada).

@export_group("Configuracion de Puerta")
## Activar mensajes de depuración en la consola
@export var debug_puerta: bool = true
## Ángulo máximo que puede abrirse la puerta (en grados)
@export var angulo_limite_abierto: float = 90.0
## Dirección de rotación (1 o -1 para invertir el lado de apertura)
@export var inversion_direccion: float = 1.0
## Velocidad de retorno/cierre de la puerta cuando el jugador deja de empujar
@export var velocidad_retorno: float = 4.0
## Fuerza con la que el jugador empuja la puerta al chocar físicamente con ella
@export var fuerza_empuje: float = 1.5

@export_group("Nodos")
## El área de proximidad (Area3D) para activar el modo empuje. Si se deja vacía, se buscará un Area3D hijo.
@export var area_proximidad: Area3D
## El cuerpo de la puerta (CollisionObject3D/StaticBody3D/AnimatableBody3D o el propio Node3D).
@export var cuerpo_puerta: Node3D

# Estado interno
var _rotacion_inicial_y: float = 0.0
var _angulo_actual_y: float = 0.0
var _pivote_marker: Marker3D = null
var _esta_cerrada: bool = true
var _lado_apertura: float = 1.0

func _ready() -> void:
	if debug_puerta:
		print("[Puerta] Inicializando script en nodo: ", name)
		
	_rotacion_inicial_y = rotation_degrees.y
	_angulo_actual_y = _rotacion_inicial_y
	
	# Buscar el Marker3D llamado "Puerta" para usarlo como pivote personalizado
	_pivote_marker = get_node_or_null("Puerta") as Marker3D
	if not _pivote_marker:
		_pivote_marker = find_child("Puerta", true, false) as Marker3D
		
	if _pivote_marker:
		if debug_puerta:
			print("[Puerta] Pivote personalizado 'Puerta' encontrado en posición local: ", _pivote_marker.position)
	else:
		if debug_puerta:
			print("[Puerta] ADVERTENCIA: No se encontró el Marker3D 'Puerta'. Usando origen local del mesh.")
		
	# 1. Buscar Area3D de proximidad o crearla dinámicamente si no existe
	if not area_proximidad:
		area_proximidad = find_child("Area3D", true, false) as Area3D
	if not area_proximidad:
		area_proximidad = get_node_or_null("Area3D") as Area3D
		
	# Si no se encuentra ningún Area3D en el nodo, la creamos por código para evitar que falle
	if not area_proximidad:
		if debug_puerta:
			print("[Puerta] Creando Area3D de proximidad automáticamente...")
		area_proximidad = Area3D.new()
		area_proximidad.name = "AreaProximidadAuto"
		area_proximidad.collision_layer = 0
		area_proximidad.collision_mask = 0xFFFFFFFF
		add_child(area_proximidad)
		
		var col_shape = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 3.0 # Rango de 3 metros alrededor de la puerta
		col_shape.shape = sphere
		area_proximidad.add_child(col_shape)
		# Centrar el área
		if _pivote_marker:
			col_shape.position = _pivote_marker.position
		else:
			col_shape.position = Vector3.ZERO
		
	if area_proximidad:
		area_proximidad.body_entered.connect(_on_area_body_entered)
		if debug_puerta:
			print("[Puerta] Area3D conectada con éxito. Capa de colisión:", area_proximidad.collision_layer, " Máscara:", area_proximidad.collision_mask)
		
	if not cuerpo_puerta:
		cuerpo_puerta = self
		
	# Desactivar procesamiento de física por defecto hasta que el jugador esté cerca
	set_physics_process(false)

func _on_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador") or "jugador" in body.name.to_lower() or body is CharacterBody3D:
		# Calcular de qué lado entra el jugador (antes de que la puerta empiece a rotar)
		var pos_local_jugador = to_local(body.global_position)
		if _pivote_marker:
			pos_local_jugador = _pivote_marker.to_local(body.global_position)
		
		# Guardamos el lado una sola vez al entrar para evitar que cambie durante la rotación
		_lado_apertura = 1.0 if pos_local_jugador.z > 0.0 else -1.0
		
		_esta_cerrada = false
		set_physics_process(true)
		if debug_puerta:
			print("[Puerta] Jugador detectado entrando por Z local: ", pos_local_jugador.z, " | Lado apertura: ", _lado_apertura)

func _physics_process(delta: float) -> void:
	# Buscar si el jugador está actualmente dentro de la zona de colisión
	var jugador_ref: Node3D = null
	if area_proximidad:
		for body in area_proximidad.get_overlapping_bodies():
			if body.is_in_group("jugador") or "jugador" in body.name.to_lower() or body is CharacterBody3D:
				jugador_ref = body
				break
				
	if jugador_ref and is_instance_valid(jugador_ref):
		var angulo_rotacion_final = _rotacion_inicial_y + (angulo_limite_abierto * _lado_apertura * inversion_direccion)
		
		# Rotar suavemente hacia los 90 grados (o el ángulo límite establecido)
		if _pivote_marker:
			_pivote_rotar_y(angulo_rotacion_final, delta)
		else:
			rotation_degrees.y = lerp(rotation_degrees.y, angulo_rotacion_final, delta * 8.0)
			_angulo_actual_y = rotation_degrees.y
	else:
		# Retornar suavemente a la posición cerrada original si no hay jugadores dentro
		var rot_actual = rotation_degrees.y
		if is_equal_approx(rot_actual, _rotacion_inicial_y):
			# La puerta ya está cerrada, la forzamos a la posición inicial y entramos en reposo
			if _pivote_marker:
				_pivote_rotar_y(_rotacion_inicial_y, 1.0)
			else:
				rotation_degrees.y = _rotacion_inicial_y
				_angulo_actual_y = _rotacion_inicial_y
			
			_esta_cerrada = true
			set_physics_process(false) # Desactivar procesamiento de físicas
			if debug_puerta:
				print("[Puerta] Sin jugadores. Puerta cerrada. Entrando en reposo.")
		else:
			# Seguir cerrando la puerta suavemente
			if _pivote_marker:
				var angulo_target = lerp(rot_actual, _rotacion_inicial_y, delta * velocidad_retorno)
				_pivote_rotar_y(angulo_target, 1.0)
			else:
				rotation_degrees.y = lerp(rot_actual, _rotacion_inicial_y, delta * velocidad_retorno)
				_angulo_actual_y = rotation_degrees.y

# Rotar sobre el pivote del Marker3D sin desfasar el mesh
func _pivote_rotar_y(angulo_target_y: float, delta: float) -> void:
	if not _pivote_marker:
		return
	
	# Interpolar suavemente el ángulo objetivo
	var angulo_actual = lerp(rotation_degrees.y, angulo_target_y, delta * 12.0)
	
	# Obtener la posición global del pivote (Marker3D) antes de la rotación
	var pivot_global_pos = _pivote_marker.global_position
	
	# Aplicar la rotación al nodo de la puerta
	rotation_degrees.y = angulo_actual
	_angulo_actual_y = angulo_actual
	
	# Calcular cuánto se desplazó el pivote debido a la rotación y compensar la posición del padre
	var pivot_new_global_pos = _pivote_marker.global_position
	var displacement = pivot_global_pos - pivot_new_global_pos
	
	# Mover el nodo padre para que el pivote (Marker3D) permanezca exactamente en el mismo lugar físico
	global_position += displacement

