extends CanvasLayer

var jugador: Node = null

# Referencia al ciclo dia/noche del mundo (fuente unica de la hora del juego)
var _sol_luna: Node = null
var _buscar_sol_luna_cd: float = 0.0
var _ultimo_minuto: int = -1

@onready var panel_estado: PanelContainer = find_child("PanelEstado", true, false)
@onready var label_hora: Label = find_child("LabelHora", true, false)
@onready var label_fase: Label = find_child("LabelFase", true, false)
@onready var barra_salud: ProgressBar = find_child("BarraSalud", true, false)
@onready var label_salud: Label = find_child("LabelSaludNum", true, false)
@onready var barra_energia: ProgressBar = find_child("BarraEnergia", true, false)
@onready var label_energia: Label = find_child("LabelEnergiaNum", true, false)


func _ready() -> void:
	layer = 80
	await get_tree().process_frame
	_conectar_jugador()


func _conectar_jugador() -> void:
	jugador = get_tree().get_first_node_in_group("jugador")


func _process(delta: float) -> void:
	# El reloj se refresca siempre, aunque el panel este oculto al conducir
	_actualizar_reloj(delta)

	if not jugador or not is_instance_valid(jugador):
		_conectar_jugador()

	# Ocultar automaticamente al conducir para dejar despejado el GPS Waze y velocimetro
	if jugador and is_instance_valid(jugador):
		var conduciendo: bool = false
		if "_conduciendo" in jugador:
			conduciendo = jugador._conduciendo
		elif "conduciendo" in jugador:
			conduciendo = jugador.conduciendo

		if conduciendo:
			if visible:
				visible = false
			return
		if not visible:
			visible = true

	# Actualizar Salud y Energia
	if jugador and is_instance_valid(jugador):
		var salud_val: float = float(jugador.get("salud")) if "salud" in jugador else 100.0
		var energia_val: float = float(jugador.get("energia")) if "energia" in jugador else 100.0
		if barra_salud:
			barra_salud.value = salud_val
		if label_salud:
			label_salud.text = str(int(salud_val)) + "%"
		if barra_energia:
			barra_energia.value = energia_val
		if label_energia:
			label_energia.text = str(int(energia_val)) + "%"


# ── Reloj del juego ──────────────────────────────────────────────────────────
func _actualizar_reloj(delta: float) -> void:
	if not label_hora:
		return

	if not is_instance_valid(_sol_luna):
		_sol_luna = null
		_buscar_sol_luna_cd -= delta
		if _buscar_sol_luna_cd > 0.0:
			return
		_buscar_sol_luna_cd = 1.0
		var raiz := get_tree().current_scene
		if raiz:
			_sol_luna = _buscar_controlador_sol_luna(raiz)
		if not _sol_luna:
			return

	var horas: float = 12.0
	if "hora_actual" in _sol_luna:
		horas = float(_sol_luna.hora_actual)

	var total_minutos: int = int(floor(fposmod(horas, 24.0) * 60.0))
	if total_minutos == _ultimo_minuto:
		return
	_ultimo_minuto = total_minutos

	var h: int = int(total_minutos / 60.0)
	var m: int = total_minutos % 60
	label_hora.text = "%02d:%02d" % [h, m]
	if label_fase:
		label_fase.text = _fase_del_dia(horas)


func _buscar_controlador_sol_luna(nodo: Node) -> Node:
	if nodo is ControladorSolLuna:
		return nodo
	for hijo in nodo.get_children():
		var encontrado := _buscar_controlador_sol_luna(hijo)
		if encontrado:
			return encontrado
	return null


func _fase_del_dia(horas: float) -> String:
	var h: float = fposmod(horas, 24.0)
	if h >= 5.0 and h < 7.0:
		return "AMANECER"
	if h >= 7.0 and h < 17.0:
		return "DIA"
	if h >= 17.0 and h < 19.0:
		return "ATARDECER"
	return "NOCHE"
