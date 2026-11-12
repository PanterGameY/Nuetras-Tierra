extends CanvasLayer

@onready var barra_carga: ProgressBar = %BarraCarga
@onready var fade_overlay: ColorRect = %FadeOut
@onready var label_consejos: Label = %Consejos
@onready var titulo_juego: TextureRect = %TituloJuego
@onready var contenedor_ui: Control = %UI
@onready var fondo_textura: TextureRect = %FondoBase
@onready var vignette_efecto: TextureRect = %Vignette
@onready var particulas_polvo: GPUParticles2D = %ParticulasPolvo
@onready var porcentaje_carga: Label = %PorcentajeCarga
@onready var estado_carga: Label = %EstadoCarga
@onready var atmosfera_shader: ColorRect = %AtmosferaShader
@onready var haz_azul: ColorRect = %HazAzul
@onready var haz_ambar: ColorRect = %HazAmbar

const ESCENA_DEFAULT := "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const INTENSIDAD_PARALLAX := 10.0

var target_scene := ESCENA_DEFAULT
var progreso_real := 0.0
var progreso_visual := 0.0
var cargando := false
var tiempo := 0.0
var cambiando_escena := false
var recurso_cargado: PackedScene = null

var consejos := [
	"PREPARA TU SUSPENSION PARA LA TROCHA COLOMBIANA.",
	"EL TERRENO DE NUESTRA TIERRA NO PERDONA DESCUIDOS.",
	"USA EL FRENO DE MOTOR EN DESCENSOS DE MONTAÑA.",
	"CONSERVA EL MOMENTO Y UNA ACELERACION CONSTANTE EN EL BARRO.",
	"EL PATIO DE LA BODEGA ES IDEAL PARA PRACTICAR MANIOBRAS.",
	"REVISA LA PRESION DE LOS NEUMATICOS ANTES DE SALIR.",
	"CUMPLE TUS CONTRATOS A TIEMPO PARA GANAR REPUTACION.",
	"BAJA LA VELOCIDAD ANTES DE ENTRAR A CURVAS CERRADAS."
]

var _consejo_index := 0
var _consejo_timer := 0.0
var _ambiente_timer := 0.0


func _ready() -> void:
	var datos := get_node_or_null("/root/DatosUsuario")
	if datos and "next_scene" in datos and datos.next_scene != "":
		target_scene = datos.next_scene

	print("[escena_carga] Cargando destino de forma asincrona: ", target_scene)
	_configurar_entrada()
	_iniciar_carga_threaded()


func _configurar_entrada() -> void:
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 1.0
		var fade_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.45)

	if barra_carga:
		barra_carga.value = 0.0
	if particulas_polvo:
		particulas_polvo.emitting = true
	if label_consejos:
		label_consejos.text = consejos.pick_random()
		_consejo_index = consejos.find(label_consejos.text)

	if titulo_juego:
		titulo_juego.pivot_offset = titulo_juego.size / 2.0
		titulo_juego.scale = Vector2(0.85, 0.85)
		titulo_juego.modulate.a = 0.0
		var logo_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		logo_tween.set_parallel(true)
		logo_tween.tween_property(titulo_juego, "scale", Vector2.ONE, 0.65).set_delay(0.12)
		logo_tween.tween_property(titulo_juego, "modulate:a", 1.0, 0.40).set_delay(0.12)

	if contenedor_ui:
		contenedor_ui.modulate.a = 0.0
		var ui_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ui_tween.tween_property(contenedor_ui, "modulate:a", 1.0, 0.50).set_delay(0.18)


func _process(delta: float) -> void:
	tiempo += delta
	_actualizar_parallax(delta)
	_actualizar_consejo(delta)
	_actualizar_estado_ambiente(delta)
	_actualizar_logo(delta)
	_actualizar_efectos_luz(delta)

	if not cargando or cambiando_escena:
		return

	var progreso_arr := []
	var estado := ResourceLoader.load_threaded_get_status(target_scene, progreso_arr)
	match estado:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progreso_arr.size() > 0:
				progreso_real = max(progreso_real, progreso_arr[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			progreso_real = 1.0
			if not recurso_cargado:
				recurso_cargado = ResourceLoader.load_threaded_get(target_scene) as PackedScene
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			if recurso_cargado == null and ResourceLoader.exists(target_scene):
				push_warning("[escena_carga] Procediendo con carga directa.")
				recurso_cargado = load(target_scene) as PackedScene
			progreso_real = 1.0

	progreso_visual = move_toward(progreso_visual, progreso_real, delta * 1.8)
	if barra_carga:
		barra_carga.value = progreso_visual * 100.0
	if porcentaje_carga:
		porcentaje_carga.text = "%3d%%" % roundi(progreso_visual * 100.0)
	if progreso_visual >= 0.98 and recurso_cargado != null:
		cambiando_escena = true
		cargando = false
		_finalizar_y_entrar()


func _actualizar_parallax(delta: float) -> void:
	if not fondo_textura:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var screen_size := get_viewport().get_visible_rect().size
	var local_offset := Vector2.ZERO
	if screen_size.x > 0.0 and screen_size.y > 0.0:
		local_offset = (mouse_pos - screen_size / 2.0) / (screen_size / 2.0)
	fondo_textura.position = fondo_textura.position.lerp(local_offset * INTENSIDAD_PARALLAX, delta * 3.0)


func _actualizar_logo(_delta: float) -> void:
	if not titulo_juego or cambiando_escena:
		return
	titulo_juego.modulate.a = lerp(0.92, 1.0, (sin(tiempo * 1.25) + 1.0) * 0.5) if titulo_juego.modulate.a > 0.1 else 0.0


func _actualizar_efectos_luz(delta: float) -> void:
	if atmosfera_shader and atmosfera_shader.material is ShaderMaterial:
		var material := atmosfera_shader.material as ShaderMaterial
		material.set_shader_parameter("progress", progreso_visual)
	if haz_azul:
		haz_azul.modulate.a = 0.55 + sin(tiempo * 1.4) * 0.18
		haz_azul.rotation = -0.18 + sin(tiempo * 0.42) * 0.025
	if haz_ambar:
		haz_ambar.modulate.a = 0.50 + sin(tiempo * 1.1 + 1.2) * 0.20
		haz_ambar.position.x += sin(tiempo * 0.35) * delta * 2.0


func _actualizar_consejo(delta: float) -> void:
	if not label_consejos:
		return
	_consejo_timer += delta
	if _consejo_timer < 5.5:
		return
	_consejo_timer = 0.0
	_consejo_index = (_consejo_index + 1) % consejos.size()
	var consejo_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	consejo_tween.tween_property(label_consejos, "modulate:a", 0.0, 0.18)
	consejo_tween.tween_callback(func() -> void:
		label_consejos.text = consejos[_consejo_index]
	)
	consejo_tween.tween_property(label_consejos, "modulate:a", 1.0, 0.28)


func _actualizar_estado_ambiente(delta: float) -> void:
	_ambiente_timer += delta
	if _ambiente_timer < 1.0 or not estado_carga or cambiando_escena:
		return
	_ambiente_timer = 0.0
	if progreso_real < 0.28:
		estado_carga.text = "INICIALIZANDO SISTEMAS"
	elif progreso_real < 0.58:
		estado_carga.text = "PREPARANDO MUNDO"
	elif progreso_real < 0.82:
		estado_carga.text = "COMPILANDO ENTORNO"
	else:
		estado_carga.text = "SINCRONIZANDO"


func _iniciar_carga_threaded() -> void:
	if not ResourceLoader.exists(target_scene):
		push_error("[escena_carga] La escena objetivo no existe: %s" % target_scene)
		target_scene = ESCENA_DEFAULT

	var err := ResourceLoader.load_threaded_request(target_scene)
	if err == OK:
		cargando = true
	else:
		push_warning("[escena_carga] Fallo la carga asíncrona. Continuando directamente.")
		cargando = true
		recurso_cargado = load(target_scene) as PackedScene
		progreso_real = 1.0


func _finalizar_y_entrar() -> void:
	if estado_carga:
		estado_carga.text = "ENTRANDO"
	if porcentaje_carga:
		porcentaje_carga.text = "100%"
	await get_tree().create_timer(0.28).timeout

	var datos := get_node_or_null("/root/DatosUsuario")
	if datos and "next_scene" in datos:
		datos.next_scene = ""

	if fade_overlay:
		var fade_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.32)
		await fade_tween.finished

	if recurso_cargado:
		get_tree().change_scene_to_packed(recurso_cargado)
	else:
		get_tree().change_scene_to_file(target_scene)
