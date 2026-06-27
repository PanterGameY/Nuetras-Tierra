extends Node3D
## Luces_IA — controla las luces de direccional y stop del vehículo de tráfico IA.
##
## Cómo usarlo:
##   1. Añade este nodo como hijo del vehículo IA (hermano o descendiente del RigidBody3D
##      que tiene TraficoAI.gd adjunto).
##   2. En el Inspector asigna los NodePaths a los MeshInstance3D de cada grupo de luces.
##   3. Los meshes se activarán/desactivarán automáticamente según el estado de TraficoAI.
##
## Flujo de direccionales:
##   • TraficoAI decide cambiar de carril → espera 3 s (hazard_wait_time) →
##     direccional encendida todo ese tiempo → cambia de carril →
##     direccional sigue 3 s más (lane_change_cooldown) → se apaga.

@export_group("Vehículo AI")
## NodePath al nodo con TraficoAI.gd. Si está vacío busca en el padre directo.
@export var trafico_ai_path: NodePath = NodePath("")

@export_group("Meshes Direccional Izquierda")
## Meshes que parpadean cuando el vehículo va a cambiar al carril izquierdo.
@export var meshes_dir_izq: Array[NodePath] = []

@export_group("Meshes Direccional Derecha")
## Meshes que parpadean cuando el vehículo va a cambiar al carril derecho.
@export var meshes_dir_der: Array[NodePath] = []

@export_group("Meshes Stop")
## Meshes que se encienden cuando el vehículo frena o está bloqueado.
@export var meshes_stop: Array[NodePath] = []

@export_group("Parpadeo")
## Frecuencia del parpadeo de las direccionales en Hz (1.5 ≈ 90 BPM estándar).
@export_range(0.5, 4.0, 0.1) var frecuencia_parpadeo: float = 1.5

# ── estado interno ────────────────────────────────────────────
var _ai: Node = null
var _nodos_izq: Array[MeshInstance3D] = []
var _nodos_der: Array[MeshInstance3D] = []
var _nodos_stop: Array[MeshInstance3D] = []
var _blink_acc: float = 0.0
var _blink_estado: bool = false

# ── ciclo de vida ─────────────────────────────────────────────
func _ready() -> void:
	# Buscar nodo TraficoAI
	if trafico_ai_path and str(trafico_ai_path) != "":
		_ai = get_node_or_null(trafico_ai_path)
	if not _ai:
		_ai = get_parent()
	if not _ai:
		push_warning("Luces_IA [", name, "]: no se encontró el nodo TraficoAI.")

	_resolver_meshes(meshes_dir_izq, _nodos_izq)
	_resolver_meshes(meshes_dir_der, _nodos_der)
	_resolver_meshes(meshes_stop, _nodos_stop)

	# Apagar todo al inicio
	_set_visible(_nodos_izq, false)
	_set_visible(_nodos_der, false)
	_set_visible(_nodos_stop, false)

func _process(delta: float) -> void:
	if not is_instance_valid(_ai):
		return

	# Leer estado de luces desde TraficoAI
	var dir_izq: bool = false
	var dir_der: bool = false
	var stop_on: bool = false
	var v_izq = _ai.get("luces_direccional_izq")
	var v_der = _ai.get("luces_direccional_der")
	var v_stp = _ai.get("luces_stop")
	if v_izq != null: dir_izq = bool(v_izq)
	if v_der != null: dir_der = bool(v_der)
	if v_stp != null: stop_on = bool(v_stp)

	# ── Parpadeo de direccionales ────────────────────────────
	var parpadea: bool = dir_izq or dir_der
	if parpadea:
		_blink_acc += delta
		var periodo: float = 1.0 / frecuencia_parpadeo
		if _blink_acc >= periodo:
			_blink_acc = fmod(_blink_acc, periodo)
			_blink_estado = not _blink_estado
	else:
		_blink_acc = 0.0
		_blink_estado = false

	# ── Aplicar visibilidad ──────────────────────────────────
	_set_visible(_nodos_izq, dir_izq and _blink_estado)
	_set_visible(_nodos_der, dir_der and _blink_estado)
	_set_visible(_nodos_stop, stop_on)

# ── helpers ───────────────────────────────────────────────────
func _resolver_meshes(paths: Array[NodePath], result: Array[MeshInstance3D]) -> void:
	result.clear()
	for p in paths:
		if str(p) == "":
			continue
		var n: Node = get_node_or_null(p)
		if n and n is MeshInstance3D:
			result.append(n as MeshInstance3D)
		elif n:
			push_warning("Luces_IA [", name, "]: '", p, "' no es MeshInstance3D.")

func _set_visible(nodos: Array[MeshInstance3D], estado: bool) -> void:
	for m in nodos:
		if is_instance_valid(m):
			m.visible = estado
