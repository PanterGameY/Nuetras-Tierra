extends CanvasLayer

# --- REFERENCIAS A NODOS (% UNIQUE NAMES) ---
@onready var barra_carga: ProgressBar = %BarraCarga
@onready var fade_overlay: ColorRect = %FadeOut
@onready var label_consejos: Label = %Consejos
@onready var titulo_juego: TextureRect = %TituloJuego
@onready var contenedor_ui: Control = %UI
@onready var fondo_textura: TextureRect = %FondoBase
@onready var vignette_efecto: TextureRect = %Vignette
@onready var particulas_polvo: GPUParticles2D = %ParticulasPolvo

# Constantes de configuración
const ESCENA_OBJETIVO := "res://escenas/main menu/Main-Menu.tscn"
const TIEMPO_CAMBIO_CONSEJO := 5.0
const INTENSIDAD_PARALLAX := 15.0 # Píxeles que se mueve el fondo
var target_scene := ESCENA_OBJETIVO

# Variables de control
var progreso_real := 0.0
var progreso_visual := 0.0
var cargando := false
var tiempo := 0.0
var ultimo_hito: int = 0

var consejos := [
	"PREPARA TU SUSPENSIÓN PARA LA TROCHA.",
	"EL TERRENO DE NUESTRA TIERRA NO PERDONA ERROR.",
	"SOLO LOS MÁS HÁBILES LLEGARÁN A LA CIMA.",
	"TIP: MANTÉN LA ACELERACIÓN CONSTANTE EN EL BARRO.",
	"NOTA: ESTA ES UNA VERSIÓN DE DESARROLLO BETA.",
	"SIGUE LOS CANALES OFICIALES PARA MÁS ACTUALIZACIONES Y CONTENIDO EXCLUSIVO.",
	"RECUERDA QUE ESTÁS EN UNA VERSIÓN DE PRUEBA, ASÍ QUE ESPERA ALGUNOS BUGS Y AJUSTES EN EL CAMINO.",
	"GRACIAS POR SER PARTE DE ESTA AVENTURA DESDE EL PRINCIPIO. TU FEEDBACK ES VITAL PARA MEJORAR EL JUEGO.",
	"ESTAMOS TRABAJANDO DURO PARA ENTREGARTE LA MEJOR EXPERIENCIA POSIBLE, ASÍ QUE NO DUDES EN COMPARTIR TUS SUGERENCIAS Y COMENTARIOS.",
	"ESTE JUEGO ESTÁ SIENDO DESARROLLADO POR UN PEQUEÑO EQUIPO INDEPENDIENTE, ASÍ QUE CADA COMENTARIO Y SUGERENCIA CUENTA PARA HACERLO MEJOR.",
	"RECUERDA QUE ESTÁS APOYANDO A UN PROYECTO INDEPENDIENTE, Y TU PACIENCIA Y ENTUSIASMO SON INVALUABLES PARA NOSOTROS.",
	"ESTAMOS COMPROMETIDOS A MEJORAR EL JUEGO CON CADA ACTUALIZACIÓN, ASÍ QUE TU FEEDBACK ES REALMENTE APRECIADO. ¡GRACIAS POR SER PARTE DE ESTA AVENTURA!",
	"NO CONDUZCAS DEMASIADO RÁPIDO, LA MONTAÑA ES TRAICIONERA.",
	"NO MANEJES CON EL MOVIL, CUIDA TU VIDA Y LA DE LOS DEMÁS."
]

func _ready() -> void:
	print("[escena_carga] _ready called")
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and datos.next_scene != "":
		target_scene = datos.next_scene
	# 1. Setup Inicial de Seguridad
	fade_overlay.visible = true
	fade_overlay.modulate.a = 1.0 # Empezamos en negro total
	barra_carga.value = 0
	particulas_polvo.emitting = false
	
	# Configurar Pivot del logo para animaciones centradas
	titulo_juego.pivot_offset = titulo_juego.size / 2
	
	# 2. Intro Cinematográfica (Tweens en paralelo)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(fade_overlay, "modulate:a", 0.0, 1.5) # Fade in largo
	tw.tween_property(titulo_juego, "modulate:a", 1.0, 1.0).set_delay(0.2)
	
	# Efecto de "inflado" elástico en el logo
	titulo_juego.scale = Vector2(0.6, 0.6)
	tw.tween_property(titulo_juego, "scale", Vector2(1.0, 1.0), 1.8).set_trans(Tween.TRANS_ELASTIC)
	
	tw.finished.connect(func(): particulas_polvo.emitting = true)

	# 3. Iniciar sistemas
	_cambiar_consejo_recursivo()
	_iniciar_carga_threaded()

func _process(delta: float) -> void:
	# Efecto Parallax sutil basado en el mouse (da profundidad)
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var local_offset = (mouse_pos - screen_size/2) / (screen_size/2)
	fondo_textura.position = lerp(fondo_textura.position, local_offset * INTENSIDAD_PARALLAX, delta * 2.0)

	if not cargando: return
	tiempo += delta
	
	# 1. Monitorear Progreso Real
	var progreso_array = []
	var estado = ResourceLoader.load_threaded_get_status(target_scene, progreso_array)
	# Solo imprimir si cambia el estado o progreso para no saturar
	if Engine.get_process_frames() % 60 == 0:
		print("[escena_carga] estado:", estado, " progreso:", progreso_array)
	
	match estado:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progreso_real = progreso_array[0]
		ResourceLoader.THREAD_LOAD_LOADED:
			progreso_real = 1.0
			# Verificación de seguridad adicional: asegurar que el progreso visual también llegó al final
			if progreso_visual >= 0.99:
				cargando = false
				_finalizar_y_entrar()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			cargando = false
			print("[escena_carga] Fallo crítico de carga (estado %d). Continuando a finalización." % estado)
			progreso_real = 1.0
			barra_carga.value = 100.0
			_finalizar_y_entrar()

	# 2. Actualización Visual Suave (Lerp)
	progreso_visual = lerp(progreso_visual, progreso_real, delta * 4.0)
	barra_carga.value = progreso_visual * 100.0
	
	# 3. EFECTOS ATMOSFÉRICOS DINÁMICOS

	# Oscilación sutil del contenedor UI (efecto flotante)
	contenedor_ui.position.y = sin(tiempo * 1.0) * 8.0

	# Brillo dinámico de la barra (Café Tierra -> Dorado Esmeralda)
	var color_tierra = Color("#6f4e37") # Café cuero
	var color_oro = Color("#f5deb3") # Trigo/Oro claro
	var pulso = (sin(tiempo * 4.0) * 0.1) + 0.9
	barra_carga.modulate = color_tierra.lerp(color_oro, progreso_visual) * pulso

	# Aumentar la velocidad de las partículas según la carga (da prisa)
	var particle_material = particulas_polvo.process_material as ParticleProcessMaterial
	if particle_material:
		particle_material.initial_velocity_min = lerp(20.0, 100.0, progreso_visual)
		particle_material.initial_velocity_max = lerp(50.0, 200.0, progreso_visual)

	# Respiración del logo
	titulo_juego.pivot_offset = titulo_juego.size / 2
	titulo_juego.scale = Vector2.ONE * (1.0 + sin(tiempo * 1.2) * 0.018)

	# Vignette pulsante (tensión creciente)
	vignette_efecto.modulate.a = 0.35 + sin(tiempo * 1.8) * 0.15

	# Tinte cálido rotante en el fondo (tierra → cálido)
	var tint := sin(tiempo * 0.25) * 0.5 + 0.5
	fondo_textura.modulate = Color(1.0, lerp(0.88, 1.0, tint), lerp(0.72, 0.95, tint))

	# Hitos de progreso al 25 / 50 / 75 %
	var hito_actual := int(progreso_visual * 4.0)
	if hito_actual > ultimo_hito and hito_actual < 4:
		ultimo_hito = hito_actual
		_disparar_hito()

func _cambiar_consejo_recursivo() -> void:
	if not label_consejos: return
	
	var tw = create_tween()
	tw.tween_property(label_consejos, "modulate:a", 0.0, 0.6) # Desaparece
	tw.tween_callback(func(): label_consejos.text = consejos.pick_random())
	tw.tween_property(label_consejos, "modulate:a", 1.0, 0.6) # Aparece
	
	# Bucle infinito usando Timer
	get_tree().create_timer(TIEMPO_CAMBIO_CONSEJO).timeout.connect(_cambiar_consejo_recursivo)

func _iniciar_carga_threaded() -> void:
	var err = ResourceLoader.load_threaded_request(target_scene)
	if err == OK:
		cargando = true
	else:
		push_warning("escena_carga: no se pudo iniciar carga threaded para %s (err=%d). Se omitirá y se continuará." % [ESCENA_OBJETIVO, err])
		print("[escena_carga] load_threaded_request failed, err=%d" % err)
		# Si no hay escena objetivo para cargar en background, simulamos actividad
		# para que el jugador vea progreso y luego finalizamos el flujo.
		cargando = true
		progreso_real = 1.0
		barra_carga.value = 100.0
		# Llamar a la finalización de forma deferred para mantener orden de frames
		call_deferred("_finalizar_y_entrar")

func _disparar_hito() -> void:
	# Flash de brillo momentáneo en el UI
	var tw_flash := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw_flash.tween_property(contenedor_ui, "modulate", Color(1.5, 1.4, 1.1), 0.06)
	tw_flash.tween_property(contenedor_ui, "modulate", Color.WHITE, 0.4)

	# Micro shake del contenedor
	var tw_shake := create_tween()
	for i in range(4):
		var f := 7.0 / float(i + 1)
		tw_shake.tween_property(contenedor_ui, "position", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.03)
	tw_shake.tween_property(contenedor_ui, "position", Vector2.ZERO, 0.08)

	# Bump elástico del logo
	var tw_logo := create_tween().set_ease(Tween.EASE_OUT)
	tw_logo.tween_property(titulo_juego, "scale", Vector2(1.12, 1.12), 0.07).set_trans(Tween.TRANS_BACK)
	tw_logo.tween_property(titulo_juego, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC)


func _finalizar_y_entrar() -> void:
	# 1. Efecto de "Impacto" al terminar (Shake de UI)
	var tw_shake = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in range(6):
		var intensity = 15.0 / (i + 1)
		tw_shake.tween_property(contenedor_ui, "position", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.04)
	tw_shake.tween_property(contenedor_ui, "position", Vector2.ZERO, 0.1)
	
	# 2. Pequeña pausa dramática para ver el 100% y dar tiempo al motor 
	# para preparar recursos en segundo plano.
	await get_tree().create_timer(1.5).timeout
	
	# 3. Fade Out final a negro para el cambio
	var tw_out = create_tween()
	tw_out.tween_property(fade_overlay, "modulate:a", 1.0, 0.6) # Fundido a negro
	await tw_out.finished
	
	# 4. Cambio de escena definitivo
	var datos := get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.next_scene = ""
	
	print("[escena_carga] Cargando escena objetivo:", target_scene)
	get_tree().call_deferred("change_scene_to_file", target_scene)