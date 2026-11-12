# Sistema para controlar luces direccionales del vehículo.

@tool
extends Node3D

@export var tiempo_parpadeo: float = 0.5 # Tiempo en segundos para cada estado (encendido/apagado)
@export var luces_izquierda: Array[NodePath] = [] # Rutas a las luces de la izquierda
@export var luces_derecha: Array[NodePath] = [] # Rutas a las luces de la derecha
var parpadeo_timer: float = 0.0
var tiempo_parpadeo_default: float = 0.5
@export var modo_estrobos: bool = false # Si es true, las luces parpadean continuamente (modo estrobos)
@export var conductor_presente: bool = false # Si es true, el jugador está en el vehículo

var estado_izquierda: bool = false
var estado_derecha: bool = false
var parpadeando_izquierda: bool = false
var parpadeando_derecha: bool = false

func _ready() -> void:
    tiempo_parpadeo_default = tiempo_parpadeo
    parpadeo_timer = 0.0
    estado_izquierda = false
    estado_derecha = false
    parpadeando_izquierda = false
    parpadeando_derecha = false
    _set_all_lights(false)

func _process(delta: float) -> void:
    # Parpadeo solo si alguna señal está activa o si estamos en modo estrobos
    if not parpadeando_izquierda and not parpadeando_derecha and not modo_estrobos:
        return

    parpadeo_timer += delta
    if parpadeo_timer >= tiempo_parpadeo:
        parpadeo_timer = 0.0
        if parpadeando_izquierda or modo_estrobos:
            estado_izquierda = not estado_izquierda
            _set_lights(luces_izquierda, estado_izquierda)
        if parpadeando_derecha or modo_estrobos:
            estado_derecha = not estado_derecha
            _set_lights(luces_derecha, estado_derecha)

func _set_lights(list: Array, on: bool) -> void:
    for p in list:
        var n = get_node_or_null(p)
        if n:
            n.visible = on

func _set_all_lights(on: bool) -> void:
    _set_lights(luces_izquierda, on)
    _set_lights(luces_derecha, on)

func set_conductor_presente(present: bool) -> void:
    conductor_presente = present
    if not conductor_presente:
        # Apagar todas las luces si el jugador sale del vehículo
        desactivar_izquierda()
        desactivar_derecha()

func activar_izquierda() -> void:
    if not conductor_presente:
        return
    # Si la derecha está activada, desactivarla (exclusividad)
    if parpadeando_derecha:
        desactivar_derecha()
    parpadeando_izquierda = true
    estado_izquierda = true
    parpadeo_timer = 0.0
    _set_lights(luces_izquierda, true)

func desactivar_izquierda() -> void:
    parpadeando_izquierda = false
    estado_izquierda = false
    _set_lights(luces_izquierda, false)

func toggle_izquierda() -> void:
    if not conductor_presente:
        return
    if parpadeando_izquierda:
        desactivar_izquierda()
    else:
        activar_izquierda()

func activar_derecha() -> void:
    if not conductor_presente:
        return
    # Si la izquierda está activada, desactivarla (exclusividad)
    if parpadeando_izquierda:
        desactivar_izquierda()
    parpadeando_derecha = true
    estado_derecha = true
    parpadeo_timer = 0.0
    _set_lights(luces_derecha, true)

func desactivar_derecha() -> void:
    parpadeando_derecha = false
    estado_derecha = false
    _set_lights(luces_derecha, false)

func toggle_derecha() -> void:
    if not conductor_presente:
        return
    if parpadeando_derecha:
        desactivar_derecha()
    else:
        activar_derecha()

# Activar ambas direccionales
func activar_direccionales() -> void:
    if not conductor_presente:
        return
    parpadeando_izquierda = true
    parpadeando_derecha = true
    estado_izquierda = true
    estado_derecha = true
    parpadeo_timer = 0.0
    _set_all_lights(true)

func desactivar_direccionales() -> void:
    parpadeando_izquierda = false
    parpadeando_derecha = false
    estado_izquierda = false
    estado_derecha = false
    modo_estrobos = false
    _set_all_lights(false)

# Modo estrobos: parpadeo rápido continuo para ambas
func activar_estrobos() -> void:
    if not conductor_presente:
        return
    modo_estrobos = true
    parpadeando_izquierda = true
    parpadeando_derecha = true
    parpadeo_timer = 0.0
    tiempo_parpadeo = 0.1 # Parpadeo rápido
    estado_izquierda = true
    estado_derecha = true
    _set_all_lights(true)

func desactivar_estrobos() -> void:
    modo_estrobos = false
    tiempo_parpadeo = tiempo_parpadeo_default
    parpadeando_izquierda = false
    parpadeando_derecha = false
    estado_izquierda = false
    estado_derecha = false
    _set_all_lights(false)

# Control individual por índice (lado izquierdo/derecho)
func activar_luz_izquierda_por_indice(idx: int) -> void:
    if idx >= 0 and idx < luces_izquierda.size():
        var p = luces_izquierda[idx]
        var n = get_node_or_null(p)
        if n:
            n.visible = true

func desactivar_luz_izquierda_por_indice(idx: int) -> void:
    if idx >= 0 and idx < luces_izquierda.size():
        var p = luces_izquierda[idx]
        var n = get_node_or_null(p)
        if n:
            n.visible = false

func activar_luz_derecha_por_indice(idx: int) -> void:
    if idx >= 0 and idx < luces_derecha.size():
        var p = luces_derecha[idx]
        var n = get_node_or_null(p)
        if n:
            n.visible = true

func desactivar_luz_derecha_por_indice(idx: int) -> void:
    if idx >= 0 and idx < luces_derecha.size():
        var p = luces_derecha[idx]
        var n = get_node_or_null(p)
        if n:
            n.visible = false

# Control por NodePath
func activar_luz_por_path(path: NodePath) -> void:
    var n = get_node_or_null(path)
    if n:
        n.visible = true

func desactivar_luz_por_path(path: NodePath) -> void:
    var n = get_node_or_null(path)
    if n:
        n.visible = false

# Input: usar acciones `inclin-izq`/`inquin_izqui` para izquierda, `inclin-der`/`inquin-der` para derecha, y `crouch` para ambas
func _input(event) -> void:
    if event.is_action_pressed("inclin-izq"):
        toggle_izquierda()
    elif event.is_action_pressed("inclin-der"):
        toggle_derecha()
    elif event.is_action_pressed("crouch"):
        # Si ambas ya están activas -> apagar; si no -> activar ambas
        if parpadeando_izquierda and parpadeando_derecha:
            desactivar_direccionales()
        else:
            activar_direccionales()
