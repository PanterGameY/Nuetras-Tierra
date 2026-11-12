extends Node3D
## Escena de validación del módulo de tráfico. Arma el Path3D de prueba
## siguiendo el centro REAL de la vía (assets/IaTrafico_mapa.glb): se
## detectaron los dos bordes del asfalto como los dos lazos de borde de la
## malla, se emparejaron punto a punto y se promediaron. La altura de cada
## punto es la altura exacta del asfalto en ese lugar, así los autos apoyan
## las llantas sobre la carretera en vez de flotar.
##
## Se arma en _enter_tree() (no en _ready()) a propósito: en Godot, los
## nodos hijos ejecutan _ready() ANTES que su padre, así que si la curva
## se asignara en _ready() de este nodo (la raíz), GestorTrafico.gd ya
## habría intentado leerla en su propio _ready() y la encontraría nula.
## _enter_tree() del padre sí corre antes que el de sus hijos.
##
## Tecla C: alterna entre "manejar" (flechas mueven el auto azul, la cámara
## lo sigue desde atrás) y "cámara libre" (el auto se queda quieto, control
## total de la cámara con mouse + WASD). Empieza en modo "manejar".

const CARRIL_JUGADOR := 2.3   # m a la derecha del centro de la vía


@onready var carretera = $Path3D
var _conduciendo := true
var _tecla_anterior := false
var _etiqueta_hud: Label


func _ready() -> void:
	_generar_colision_mapa()
	_crear_hud()
##_aplicar_modo()


func _process(_delta: float) -> void:
	var presionada := Input.is_key_pressed(KEY_C)
	if presionada and not _tecla_anterior:
		_conduciendo = not _conduciendo
##		_aplicar_modo()
	_tecla_anterior = presionada
##	_actualizar_hud()


##func _aplicar_modo() -> void:
##	_auto.conduccion_habilitada = _conduciendo
##	_camara.objetivo_seguimiento = _auto if _conduciendo else null


## Texto en pantalla: velocidad del auto azul y qué hace la tecla C.
func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_etiqueta_hud = Label.new()
	_etiqueta_hud.position = Vector2(16.0, 12.0)
	_etiqueta_hud.add_theme_font_size_override("font_size", 22)
	_etiqueta_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	_etiqueta_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_etiqueta_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_etiqueta_hud)


##func _actualizar_hud() -> void:
##	var modo := "MANEJANDO (flechas)  |  C: cámara libre"
##	if not _conduciendo:
##		modo = "CÁMARA LIBRE (WASD + clic derecho)  |  C: volver al auto"
##	_etiqueta_hud.text = "Auto azul: %d km/h\n%s" % [int(roundf(_auto.velocidad_kmh())), modo]


## La malla del mapa se importa solo como visual (sin colisión). Se le genera
## una colisión de malla (trimesh) y se mueve a la capa 3 (valor 4), distinta
## de la capa 1 (jugador) y la 2 (vehículos IA). Así los sensores de los autos
## de tráfico (máscara 3 = capas 1 y 2) NO detectan el suelo como obstáculo,
## y el auto del jugador sí puede medir la altura del terreno con sus rayos.
func _generar_colision_mapa() -> void:
	var mapa := get_node_or_null("MapaReal")
	if mapa != null:
		_generar_colision_recursivo(mapa)


func _generar_colision_recursivo(nodo: Node) -> void:
	var malla := nodo as MeshInstance3D
	if malla != null:
		malla.create_trimesh_collision()
		for hijo in malla.get_children():
			var cuerpo := hijo as StaticBody3D
			if cuerpo != null:
				cuerpo.collision_layer = 4
				cuerpo.collision_mask = 0
	for hijo in nodo.get_children():
		_generar_colision_recursivo(hijo)


func _enter_tree() -> void:
	var carretera: Path3D = $CarreteraPrueba
	var curva := Curve3D.new()

	

	# Tipos de vehículo del tráfico (variedad tipo ETS/ATS) y su frecuencia relativa.
	var gestor: GestorTrafico = $GestorTrafico
	gestor.escenas_vehiculo = [
		preload("res://modelos3d/TraficoIA/Cascadia_IA/Cascadia_IA.tscn"),
		preload("res://modelos3d/TraficoIA/T680_IA/T680_IA.tscn"),
		preload("res://modelos3d/TraficoIA/Escenas_IA/Furgon1.tscn"),
		preload("res://modelos3d/TraficoIA/Transit_IA.tscn"),
	]
	gestor.pesos_vehiculo = [3.0, 2.5, 3.5, 4.0]

	# El auto azul arranca en el carril derecho, mirando hacia donde avanza la curva.
	var inicio := curva.sample_baked(0.0)
	var adelante := curva.sample_baked(3.0)
	var tx := adelante.x - inicio.x
	var tz := adelante.z - inicio.z
	var largo := sqrt(tx * tx + tz * tz)
	if largo > 0.0001:
		tx /= largo
		tz /= largo
	var auto: Node3D = $AutoJugador
	auto.position = Vector3(inicio.x - tz * CARRIL_JUGADOR, inicio.y + 1.0, inicio.z + tx * CARRIL_JUGADOR)
	auto.rotation.y = atan2(-tx, -tz)
