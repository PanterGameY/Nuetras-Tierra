extends Node3D
# limpiavidrios.gd
# Colocar este script en cada pivote de brazo por separado.
# Cada instancia es independiente y se configura desde el inspector.

@export_group("Configuración")
@export var accion: StringName = "limpiavidrios"
@export var velocidad: float = 1.0         # Ciclos completos por segundo
@export var angulo_barrido: float = 95.0   # Grados de arco del barrido
@export var sentido_positivo: bool = true  # true = gira en +Z, false = gira en -Z
@export var retardo_inicio: float = 0.0    # Segundos de retardo al arrancar (para escalonar brazos)

var _activo: bool = false
var _tween: Tween
var _rot_inicial: float = 0.0

func _ready() -> void:
	_rot_inicial = rotation_degrees.z

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(accion):
		_activo = !_activo
		if _activo:
			_iniciar()
		else:
			_detener()

# ─────────────────────────────────────────────────
func _iniciar() -> void:
	if _tween:
		_tween.kill()

	var duracion := 1.0 / velocidad
	var signo := 1.0 if sentido_positivo else -1.0
	var destino := _rot_inicial + angulo_barrido * signo

	if retardo_inicio > 0.0:
		await get_tree().create_timer(retardo_inicio).timeout
		if not _activo:  # Fue desactivado durante el retardo
			return

	_tween = create_tween().set_loops()

	# Ida
	_tween.tween_property(self, "rotation_degrees:z", destino, duracion * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Vuelta
	_tween.tween_property(self, "rotation_degrees:z", _rot_inicial, duracion * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _detener() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	# Regresa suavemente a posición de reposo
	create_tween()\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\
		.tween_property(self, "rotation_degrees:z", _rot_inicial, 0.4)

# Llamable desde un botón de UI
func activar_desde_boton() -> void:
	_activo = !_activo
	if _activo:
		_iniciar()
	else:
		_detener()
