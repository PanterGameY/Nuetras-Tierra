# espejos2.gd
# Controla los SubViewports de los espejos hijos (MeshInstance3D > SubViewport > Camera3D).
# Activa los SubViewports y sus cámaras solo cuando el jugador está dentro del vehículo,
# para ahorrar rendimiento cuando el vehículo está aparcado.
extends Node3D

# ── Configuración ───────────────────────────────────────────────────────────
@export var resolucion: Vector2i = Vector2i(512, 256)
# Cuántos fps renderiza cada espejo (0 = sin límite, útil para ahorrar rendimiento)
@export var fps_mirrors: int = 30

# ── Estado interno ──────────────────────────────────────────────────────────
var _viewports: Array[SubViewport] = []
var _activos: bool = false

func _ready() -> void:
	# Recorrer los hijos directos (MeshInstance3D de cada espejo)
	for espejo in get_children():
		var vp: SubViewport = espejo.get_node_or_null("SubViewport") as SubViewport
		if vp:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			vp.size = resolucion
			_viewports.append(vp)

	# Buscar el vehículo padre (RigidBody3D) para conectar entrada/salida
	var vehiculo := _get_vehiculo_parent(get_parent())
	if vehiculo:
		# Conectamos a las señales del coche si las tiene, de lo contrario
		# el propio InputVehiculo nos sirve de fuente de verdad en _process.
		if vehiculo.has_signal("jugador_subio"):
			vehiculo.jugador_subio.connect(_activar)
		if vehiculo.has_signal("jugador_bajo"):
			vehiculo.jugador_bajo.connect(_desactivar)
	
	# Estado inicial: desactivado
	_aplicar_estado(false)

func _process(_delta: float) -> void:
	# Fallback: sincronizar con InputVehiculo por si las señales no están disponibles
	var deberia_estar_activo: bool = is_instance_valid(InputVehiculo) and InputVehiculo.conduciendo
	if deberia_estar_activo != _activos:
		_aplicar_estado(deberia_estar_activo)

# ── API pública (por si el vehículo llama directo) ──────────────────────────
func _activar() -> void:
	_aplicar_estado(true)

func _desactivar() -> void:
	_aplicar_estado(false)

# ── Lógica central ──────────────────────────────────────────────────────────
func _aplicar_estado(activo: bool) -> void:
	_activos = activo
	var modo: int = SubViewport.UPDATE_WHEN_VISIBLE if activo else SubViewport.UPDATE_DISABLED
	for vp in _viewports:
		if is_instance_valid(vp):
			vp.render_target_update_mode = modo
			# También activar/desactivar la Camera3D hija para no consumir culling
			var cam := vp.get_node_or_null("Camera3D") as Camera3D
			if cam:
				cam.set_process(activo)
				cam.set_physics_process(activo)

# ── Utilidad ─────────────────────────────────────────────────────────────────
func _get_vehiculo_parent(n: Node) -> Node:
	if n == null:
		return null
	if n is RigidBody3D:
		return n
	return _get_vehiculo_parent(n.get_parent())
