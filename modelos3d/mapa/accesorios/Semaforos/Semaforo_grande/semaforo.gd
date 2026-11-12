extends Node3D

## ════════════════════════════════════════════════════════════════
## SEMÁFORO — Script funcional configurable desde el Inspector
## Asigna cada MeshInstance3D de luz en los exports de abajo.
##
## DETECCIÓN DE IA:
## Agrega un Area3D hijo con el CollisionShape3D dentro de él.
## Asígnalo al export "area_deteccion".
## La IA puede llamar  debe_detenerse()  o conectar la señal
## "fase_cambiada" para reaccionar en tiempo real.
## ════════════════════════════════════════════════════════════════

## Emitida cuando la fase cambia. La IA de tráfico puede conectarse.
## fase: 0=ROJO  1=AMARILLO  2=VERDE
signal fase_cambiada(fase: int)

## Emitida cuando un cuerpo entra/sale del área de detección.
signal vehiculo_entro(body: Node3D)
signal vehiculo_salio(body: Node3D)

enum ModoSemaforo {
	ESTANDAR,         ## Rojo → Verde → Amarillo → Rojo ...
	SOLO_AMARILLO,    ## Parpadeo amarillo (precaución permanente)
	APAGADO,          ## Todas las luces apagadas
	MANUAL,           ## El juego controla el estado vía código
}

# ─── Área de detección para IA de tráfico ────────────────────────────────────
@export_group("Detección IA")
## Asigna aquí el Area3D que contiene el CollisionShape3D de detección.
## Los vehículos que entren recibirán la señal y pueden consultar debe_detenerse().
@export var area_deteccion: Area3D = null

# ─── Luces ───────────────────────────────────────────────────────────────────
@export_group("Luces")
@export var mesh_rojo:     MeshInstance3D = null
@export var mesh_amarillo: MeshInstance3D = null
@export var mesh_verde:    MeshInstance3D = null

# ─── Modo de operación ───────────────────────────────────────────────────────
@export_group("Comportamiento")
@export var modo: ModoSemaforo = ModoSemaforo.ESTANDAR

## Si true el semáforo arranca en ROJO; si false arranca en VERDE
@export var iniciar_en_rojo: bool = true

# ─── Duraciones de cada fase (segundos) ──────────────────────────────────────
@export_group("Duraciones")
@export var duracion_rojo:     float = 5.0
@export var duracion_amarillo: float = 2.0
@export var duracion_verde:    float = 5.0
@export var velocidad_parpadeo: float = 0.5  ## Para modo SOLO_AMARILLO

# ─── Colores emisivos (apagado vs encendido) ─────────────────────────────────
@export_group("Colores")
@export var color_rojo:     Color = Color(1.0, 0.0, 0.0)
@export var color_amarillo: Color = Color(1.0, 0.8, 0.0)
@export var color_verde:    Color = Color(0.0, 1.0, 0.1)
@export var brillo_encendido: float = 8.0   ## Intensidad de emisión visible de lejos
@export var brillo_apagado:   float = 0.05  ## Intensidad residual cuando está "apagada"

# ─── Luces OmniLight (visibilidad a distancia) ───────────────────────────
@export_group("Luces OmniLight")
## Asigna un OmniLight3D por cada color para que la luz se vea desde lejos.
## El script los enciende/apaga automáticamente con cada fase.
@export var luz_rojo:     OmniLight3D = null
@export var luz_amarillo: OmniLight3D = null
@export var luz_verde:    OmniLight3D = null
@export var energia_luz: float = 3.0   ## Energía de los OmniLight al estar encendidos
@export var rango_luz:   float = 12.0  ## Radio de iluminación (metros)

# ─── Estado interno ──────────────────────────────────────────────────────────
enum _Fase { ROJO, AMARILLO, VERDE }

var _fase_actual: _Fase = _Fase.ROJO
var _timer: float = 0.0
var _parpadeo_encendido: bool = true

# Materiales creados en tiempo de ejecución para cada luz
var _mat_rojo:     StandardMaterial3D = null
var _mat_amarillo: StandardMaterial3D = null
var _mat_verde:    StandardMaterial3D = null


# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_crear_materiales()
	_crear_luces_automaticas()
	_aplicar_modo_inicial()
	_conectar_area()


# ══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	match modo:
		ModoSemaforo.ESTANDAR:
			_procesar_estandar(delta)
		ModoSemaforo.SOLO_AMARILLO:
			_procesar_parpadeo_amarillo(delta)
		ModoSemaforo.APAGADO:
			pass  # No hace nada; las luces ya están apagadas
		ModoSemaforo.MANUAL:
			pass  # Controlado externamente


# ══════════════════════════════════════════════════════════════════════════════
## Lógica del ciclo estándar: Rojo → Verde → Amarillo → Rojo...
func _procesar_estandar(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return

	match _fase_actual:
		_Fase.ROJO:
			_cambiar_fase(_Fase.VERDE, duracion_verde)
		_Fase.VERDE:
			_cambiar_fase(_Fase.AMARILLO, duracion_amarillo)
		_Fase.AMARILLO:
			_cambiar_fase(_Fase.ROJO, duracion_rojo)


## Lógica de parpadeo amarillo
func _procesar_parpadeo_amarillo(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = velocidad_parpadeo
	_parpadeo_encendido = not _parpadeo_encendido
	_apagar_todas()
	if _parpadeo_encendido and mesh_amarillo:
		_encender(mesh_amarillo, _mat_amarillo, color_amarillo)
		_encender_luz(luz_amarillo, color_amarillo)
	else:
		_apagar_luz(luz_amarillo)


# ══════════════════════════════════════════════════════════════════════════════
func _cambiar_fase(nueva_fase: _Fase, duracion: float) -> void:
	_fase_actual = nueva_fase
	_timer = duracion
	_apagar_todas()
	match nueva_fase:
		_Fase.ROJO:
			if mesh_rojo:    _encender(mesh_rojo,     _mat_rojo,     color_rojo)
			_encender_luz(luz_rojo, color_rojo)
		_Fase.AMARILLO:
			if mesh_amarillo: _encender(mesh_amarillo, _mat_amarillo, color_amarillo)
			_encender_luz(luz_amarillo, color_amarillo)
		_Fase.VERDE:
			if mesh_verde:   _encender(mesh_verde,    _mat_verde,    color_verde)
			_encender_luz(luz_verde, color_verde)
	# Notificar a la IA de tráfico
	fase_cambiada.emit(int(nueva_fase))


# ══════════════════════════════════════════════════════════════════════════════
## API pública — usar desde otros scripts para control manual
## Ejemplo: semaforo_node.poner_en_rojo()

func poner_en_rojo() -> void:
	_cambiar_fase(_Fase.ROJO, duracion_rojo)

func poner_en_verde() -> void:
	_cambiar_fase(_Fase.VERDE, duracion_verde)

func poner_en_amarillo() -> void:
	_cambiar_fase(_Fase.AMARILLO, duracion_amarillo)

func cambiar_modo(nuevo_modo: ModoSemaforo) -> void:
	modo = nuevo_modo
	_apagar_todas()
	match nuevo_modo:
		ModoSemaforo.ESTANDAR:
			if iniciar_en_rojo:
				_cambiar_fase(_Fase.ROJO, duracion_rojo)
			else:
				_cambiar_fase(_Fase.VERDE, duracion_verde)
		ModoSemaforo.SOLO_AMARILLO:
			_timer = 0.0
			_parpadeo_encendido = false
		ModoSemaforo.APAGADO, ModoSemaforo.MANUAL:
			_apagar_todas()

func esta_en_rojo() -> bool:
	return _fase_actual == _Fase.ROJO and modo == ModoSemaforo.ESTANDAR

## ── API para IA de tráfico ────────────────────────────────────────────────

## Devuelve true si los vehículos deben detenerse (rojo o amarillo)
func debe_detenerse() -> bool:
	if modo == ModoSemaforo.APAGADO:
		return false
	if modo == ModoSemaforo.SOLO_AMARILLO:
		return _parpadeo_encendido  ## Detener solo cuando está encendido
	return _fase_actual == _Fase.ROJO or _fase_actual == _Fase.AMARILLO

## Devuelve true si los vehículos pueden avanzar libremente
func puede_avanzar() -> bool:
	return not debe_detenerse()

## Devuelve la fase actual como string (útil para debug y IA)
func get_fase_string() -> String:
	match _fase_actual:
		_Fase.ROJO:     return "ROJO"
		_Fase.AMARILLO: return "AMARILLO"
		_Fase.VERDE:    return "VERDE"
	return "DESCONOCIDO"

## Devuelve los segundos restantes de la fase actual
func get_tiempo_restante() -> float:
	return max(0.0, _timer)


# ══════════════════════════════════════════════════════════════════════════════
## Conexión del Area3D para detección de vehículos
func _conectar_area() -> void:
	if area_deteccion == null:
		# Intentar encontrar un Area3D hijo automáticamente
		for hijo in get_children():
			if hijo is Area3D:
				area_deteccion = hijo
				break

	if area_deteccion == null:
		push_warning("Semaforo '%s': No se encontró Area3D para detección de IA." % name)
		return

	if not area_deteccion.body_entered.is_connected(_on_vehiculo_entro):
		area_deteccion.body_entered.connect(_on_vehiculo_entro)
	if not area_deteccion.body_exited.is_connected(_on_vehiculo_salio):
		area_deteccion.body_exited.connect(_on_vehiculo_salio)


func _on_vehiculo_entro(body: Node3D) -> void:
	vehiculo_entro.emit(body)
	# Si el vehículo tiene el método del sistema de tráfico, notificarle directamente
	if body.has_method("notificar_semaforo"):
		body.notificar_semaforo(self)


func _on_vehiculo_salio(body: Node3D) -> void:
	vehiculo_salio.emit(body)
	if body.has_method("semaforo_despejado"):
		body.semaforo_despejado(self)


# ══════════════════════════════════════════════════════════════════════════════
## Funciones internas de material/color

func _crear_materiales() -> void:
	_mat_rojo     = _nuevo_material(color_rojo)
	_mat_amarillo = _nuevo_material(color_amarillo)
	_mat_verde    = _nuevo_material(color_verde)
	# Aplicar materiales apagados como override base
	if mesh_rojo:     mesh_rojo.material_override     = _mat_rojo
	if mesh_amarillo: mesh_amarillo.material_override = _mat_amarillo
	if mesh_verde:    mesh_verde.material_override    = _mat_verde
	_apagar_todas()


func _nuevo_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = brillo_apagado
	return mat


func _encender(_mesh: MeshInstance3D, mat: StandardMaterial3D, color: Color) -> void:
	mat.albedo_color = color
	mat.emission = color
	mat.emission_energy_multiplier = brillo_encendido


func _apagar_todas() -> void:
	for par in [[mesh_rojo, _mat_rojo, color_rojo],
				[mesh_amarillo, _mat_amarillo, color_amarillo],
				[mesh_verde, _mat_verde, color_verde]]:
		var mesh: MeshInstance3D = par[0]
		var mat:  StandardMaterial3D = par[1]
		var col:  Color = par[2]
		if mesh and mat:
			mat.albedo_color = col * 0.15  ## Muy oscuro = apagado
			mat.emission = col
			mat.emission_energy_multiplier = brillo_apagado
	# Apagar todos los OmniLight
	_apagar_luz(luz_rojo)
	_apagar_luz(luz_amarillo)
	_apagar_luz(luz_verde)


func _encender_luz(luz: OmniLight3D, color: Color) -> void:
	if luz == null:
		return
	luz.light_color = color
	luz.light_energy = energia_luz
	luz.omni_range = rango_luz
	luz.visible = true


func _apagar_luz(luz: OmniLight3D) -> void:
	if luz:
		luz.visible = false


## Crea OmniLight3D automáticamente si no fueron asignados en el Inspector
func _crear_luces_automaticas() -> void:
	# Configurar visibilidad de LOD en los meshes para verlos desde lejos
	for mesh in [mesh_rojo, mesh_amarillo, mesh_verde]:
		if mesh:
			mesh.visibility_range_end = 0.0        ## 0 = sin límite de distancia
			mesh.visibility_range_end_margin = 0.0

	# Crear OmniLights automáticamente si los meshes existen pero no hay luces
	if mesh_rojo and luz_rojo == null:
		luz_rojo = _crear_omni(mesh_rojo, color_rojo)
	if mesh_amarillo and luz_amarillo == null:
		luz_amarillo = _crear_omni(mesh_amarillo, color_amarillo)
	if mesh_verde and luz_verde == null:
		luz_verde = _crear_omni(mesh_verde, color_verde)


func _crear_omni(referencia: MeshInstance3D, color: Color) -> OmniLight3D:
	var omni := OmniLight3D.new()
	omni.light_color = color
	omni.light_energy = energia_luz
	omni.omni_range = rango_luz
	omni.shadow_enabled = false  ## Sin sombras para mejor rendimiento
	omni.visible = false
	# Posicionarlo en el mismo lugar que el mesh
	omni.position = referencia.global_position - global_position
	add_child(omni)
	return omni


func _aplicar_modo_inicial() -> void:
	match modo:
		ModoSemaforo.ESTANDAR:
			if iniciar_en_rojo:
				_cambiar_fase(_Fase.ROJO, duracion_rojo)
			else:
				_cambiar_fase(_Fase.VERDE, duracion_verde)
		ModoSemaforo.SOLO_AMARILLO:
			_timer = 0.0
			_parpadeo_encendido = false
		ModoSemaforo.APAGADO, ModoSemaforo.MANUAL:
			_apagar_todas()
