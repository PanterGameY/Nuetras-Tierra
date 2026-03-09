extends Control

@onready var barra: ProgressBar = $UI/Centro/Marco/PanelCarga/Contenido/BarraCarga
@onready var label_porcentaje: Label = $UI/Centro/Marco/PanelCarga/Contenido/Porcentaje
@onready var label_subtitulo: Label = $UI/Centro/Marco/PanelCarga/Contenido/Subtitulo
@onready var label_consejo: Label = $UI/Centro/Marco/PanelCarga/Contenido/Consejo
@onready var label_estado: Label = $UI/Centro/Marco/PanelCarga/Contenido/HBoxEstado/Estado
@onready var spinner: Label = $UI/Centro/Marco/PanelCarga/Contenido/HBoxEstado/Spinner
@onready var fade_overlay: ColorRect = $FadeOut
@onready var brillo_a: ColorRect = $Fondo/BrilloA
@onready var brillo_b: ColorRect = $Fondo/BrilloB
@onready var shader_mat: ShaderMaterial = barra.material as ShaderMaterial

const TIEMPO_CAMBIO_CONSEJO := 2.2
const ESCENA_OBJETIVO := "res://scenes/Fusa.tscn"

var progreso := 0.0
var progreso_visual := 0.0
var progreso_real := 0.0
var cargando := false
var cambio_iniciado := false
var tiempo_consejo := 0.0
var indice_consejo := 0
var tiempo_anim := 0.0
var carga_iniciada := false
var carga_fallida := false

var consejos := [
	"Consejo: Frena antes de entrar a curvas cerradas.",
	"Consejo: Mantén velocidad estable en terreno irregular.",
	"Consejo: Usa aceleración progresiva para no perder tracción.",
	"Consejo: Ajusta tu línea para salir más rápido de cada curva."
]

var spinner_chars := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
var spinner_index := 0

func _ready():
	progreso = 0.0
	progreso_visual = 0.0
	progreso_real = 0.0
	if fade_overlay:
		fade_overlay.modulate.a = 0.0
	if label_estado:
		label_estado.text = "Preparando recursos..."
	actualizar_consejo()
	actualizar_barra()
	iniciar_carga_real()
	set_process(true)

func _process(delta):
	tiempo_anim += delta
	animar_fondo(delta)
	animar_spinner(delta)

	if cargando:
		actualizar_carga_real()
		var objetivo_visual := smoothstep(0.0, 1.0, progreso_real)
		progreso_visual = lerpf(progreso_visual, objetivo_visual, delta * 8.0)
		progreso = progreso_real
		actualizar_barra()
		if progreso_real >= 1.0 and not cambio_iniciado:
			cargando = false
			if label_estado:
				label_estado.text = "Iniciando mundo..."
			iniciar_transicion()
	elif carga_fallida and label_estado:
		label_estado.text = "No se pudo cargar la escena"

		tiempo_consejo += delta
		if tiempo_consejo >= TIEMPO_CAMBIO_CONSEJO:
			tiempo_consejo = 0.0
			indice_consejo = (indice_consejo + 1) % consejos.size()
			actualizar_consejo()

		if label_subtitulo:
			var puntos := int(floor(fmod(Time.get_ticks_msec() / 450.0, 4.0)))
			label_subtitulo.text = "Cargando mundo" + ".".repeat(puntos)

func iniciar_carga_real() -> void:
	if carga_iniciada:
		return
	carga_iniciada = true
	var err := ResourceLoader.load_threaded_request(ESCENA_OBJETIVO)
	if err != OK:
		carga_fallida = true
		cargando = false
		push_error("[Carga] Error al iniciar carga threaded: %s" % err)
		return
	cargando = true

func actualizar_carga_real() -> void:
	var progreso_arr: Array = []
	var estado := ResourceLoader.load_threaded_get_status(ESCENA_OBJETIVO, progreso_arr)
	match estado:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progreso_arr.size() > 0:
				progreso_real = clampf(float(progreso_arr[0]), 0.0, 0.99)
			if label_estado:
				label_estado.text = "Descomprimiendo assets..."
		ResourceLoader.THREAD_LOAD_LOADED:
			progreso_real = 1.0
		ResourceLoader.THREAD_LOAD_FAILED:
			carga_fallida = true
			cargando = false
			push_error("[Carga] Fallo al cargar escena objetivo")
		_:
			pass

func animar_spinner(delta: float) -> void:
	if spinner:
		var velocidad := 12.0 # Frames por segundo
		spinner_index = int(floor(tiempo_anim * velocidad)) % spinner_chars.size()
		spinner.text = spinner_chars[spinner_index]

func animar_fondo(_delta: float) -> void:
	if brillo_a:
		brillo_a.modulate.a = 0.12 + sin(tiempo_anim * 0.85) * 0.05
	if brillo_b:
		brillo_b.modulate.a = 0.10 + cos(tiempo_anim * 1.10) * 0.04

func actualizar_barra():
	if barra:
		barra.value = progreso_visual * barra.max_value
	if shader_mat:
		shader_mat.set_shader_parameter("progreso", progreso_visual)
		shader_mat.set_shader_parameter("animacion", fmod(Time.get_ticks_msec() / 1000.0, 1000.0))
	if label_porcentaje:
		label_porcentaje.text = str(int(round(progreso_visual * 100.0))) + "%"

func actualizar_consejo():
	if label_consejo and consejos.size() > 0:
		label_consejo.text = consejos[indice_consejo]

func iniciar_transicion():
	if cambio_iniciado:
		return
	cambio_iniciado = true
	if fade_overlay:
		var tween := create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.35)
		tween.finished.connect(cambiar_a_juego)
	else:
		cambiar_a_juego()

func cambiar_a_juego():
	if carga_fallida:
		return
	var recurso := ResourceLoader.load_threaded_get(ESCENA_OBJETIVO)
	if recurso is PackedScene:
		get_tree().change_scene_to_packed(recurso)
	else:
		# Fallback de seguridad
		get_tree().change_scene_to_file(ESCENA_OBJETIVO)
