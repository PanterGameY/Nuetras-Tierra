# GatoHidraulico.gd
# Controlador interactivo del Gato Hidráulico Truper 2 Toneladas para Nuestra Tierra 2.0.
# Ajustado 100% para experiencia móvil limpia:
# - Sin atajos de teclado de PC en los textos diegéticos.
# - Label3D compacto (font_size 18) que SÓLO se hace visible cuando el punto central apunta al gato.
# - Plato de apoyo físicamente anclado al brazo elevador.
# - Animación de desenroscar y guardar ejecutada exactamente como la reversa de enroscar.
# - Cero activaciones accidentales al arrastrar la cámara.
class_name GatoHidraulico
extends Node3D

signal estado_cambiado(nuevo_estado: Estado)
signal gato_posicionado(pos_mundo: Vector3)
signal elevacion_completada()
signal descenso_completado()
signal varilla_guardada()
signal gato_recogido()

enum Estado {
	EN_COLOCACION,               # Moviéndose frente a cámara proyectado al suelo
	VARILLA_EN_SOPORTE_TITILANDO,# Fijado al suelo; varilla titila en rojo esperando toque
	ANIMANDO_MONTAR_VARILLA,     # Varilla saliendo de soporte y enroscándose
	LISTO_PARA_SUBIR,            # Varilla montada; esperando toque para bombear
	ANIMANDO_SUBIDA,             # 5 bombeos mecánicos y elevación del brazo
	ARRIBA_ELEVADO,              # Brazo en máxima altura; esperando toque para bajar
	ANIMANDO_BAJADA,             # Válvula abierta, descenso suave y cierre de válvula
	LISTO_PARA_GUARDAR,          # Abajo; esperando toque para desenroscar
	ANIMANDO_GUARDAR_VARILLA,    # Desenroscado y retorno al soporte (reversa de montar)
	LISTO_PARA_RECOGER,          # En reposo en el suelo; esperando toque al chasis
	RECOGIDO                     # Proceso finalizado
}

@export var estado_actual: Estado = Estado.EN_COLOCACION
@export var velocidad_animacion: float = 1.0
@export var distancia_colocacion_m: float = 2.4
@export var distancia_interaccion_max: float = 4.0
@export var auto_iniciar_colocacion: bool = true

# Transformación local de reposo de la varilla en sus horquillas laterales
const VARILLA_POS_REPOSO := Vector3(0.505, -0.128, -0.040)
const VARILLA_ROT_REPOSO := Vector3(0.0, -1.5707963, 0.0)

# Rotaciones del brazo elevador y plato de apoyo (abajo vs arriba)
const BRAZO_ROT_ABAJO := Vector3(0.0, 0.087266, 0.0)
const PLATO_ROT_ABAJO := Vector3(0.0, -0.087266, 0.0)
const BRAZO_ROT_ARRIBA := Vector3(0.0, -0.558505, 0.0)
const PLATO_ROT_ARRIBA := Vector3(0.0, 0.558505, 0.0)

# Nodos del árbol
@onready var raycast_suelo: RayCast3D = $RayCastSuelo
@onready var prompt_label_3d: Label3D = $PivotePrompt/PromptLabel3D
@onready var pivote_prompt: Node3D = $PivotePrompt
@onready var canvas_ui_colocacion: CanvasLayer = $CanvasColocacion
@onready var btn_listo_ui: Button = $CanvasColocacion/BtnListo

var anim_player: AnimationPlayer = null
var varilla_mesh: Node3D = null
var brazo_mesh: Node3D = null
var plato_mesh: Node3D = null
var camara_activa: Camera3D = null

# Retícula central minimalista
var canvas_reticula: CanvasLayer = null
var punto_centro: Control = null

# Detección de enfoque
var _apuntando_al_gato: bool = false
var _tiempo_acumulado: float = 0.0
var _tw_titileo: Tween = null
var _mat_varilla_override: StandardMaterial3D = null

# Filtro estricto para diferenciar arrastrar cámara vs toque intencional
var _touch_inicio_pos: Vector2 = Vector2.ZERO
var _touch_inicio_tiempo: int = 0
var _arrastrando_pantalla: bool = false

# Audio
var _audio_stream: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("gato_hidraulico")
	visible = true
	
	if scale == Vector3.ONE:
		scale = Vector3(1.35, 1.35, 1.35)
		
	_buscar_nodos_modelo()
	_crear_punto_central_reticula()
	_configurar_audio()
	
	if pivote_prompt:
		pivote_prompt.visible = false
	if prompt_label_3d:
		prompt_label_3d.visible = true
		prompt_label_3d.font_size = 18
		
	if btn_listo_ui:
		btn_listo_ui.pressed.connect(_on_btn_listo_presionado)
		
	_forzar_posicion_reposo()
	
	if auto_iniciar_colocacion:
		iniciar_modo_colocacion()
	else:
		fijar_en_suelo()

func _buscar_nodos_modelo() -> void:
	anim_player = find_child("AnimationPlayer*", true, false) as AnimationPlayer
	if not anim_player:
		for child in get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
				
	varilla_mesh = find_child("Varilla_Palanca*", true, false) as Node3D
	brazo_mesh = find_child("Brazo_Elevador*", true, false) as Node3D
	plato_mesh = find_child("Plato_Apoyo*", true, false) as Node3D
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animacion_terminada)

func _forzar_posicion_reposo() -> void:
	if is_instance_valid(varilla_mesh):
		varilla_mesh.position = VARILLA_POS_REPOSO
		varilla_mesh.rotation = VARILLA_ROT_REPOSO
	if is_instance_valid(brazo_mesh):
		brazo_mesh.rotation = BRAZO_ROT_ABAJO
	if is_instance_valid(plato_mesh):
		plato_mesh.rotation = PLATO_ROT_ABAJO
		
	if anim_player:
		if anim_player.has_animation("reposo"):
			anim_player.play("reposo")
			anim_player.seek(0.0, true)
			anim_player.pause()
		elif anim_player.has_animation("montar_varilla"):
			anim_player.play("montar_varilla")
			anim_player.seek(0.0, true)
			anim_player.pause()

func _forzar_varilla_en_soporte() -> void:
	_forzar_posicion_reposo()

# ─────────────────────────────────────────────────────────────
# RETÍCULA CENTRAL MINIMALISTA (SÓLO EL PUNTO EN PANTALLA)
# ─────────────────────────────────────────────────────────────
func _crear_punto_central_reticula() -> void:
	canvas_reticula = CanvasLayer.new()
	canvas_reticula.name = "CanvasReticulaGato"
	canvas_reticula.layer = 15
	add_child(canvas_reticula)
	
	punto_centro = Control.new()
	punto_centro.name = "PuntoCentro"
	punto_centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	punto_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_reticula.add_child(punto_centro)
	
	var punto_draw = Control.new()
	punto_draw.custom_minimum_size = Vector2(20, 20)
	punto_draw.position = Vector2(-10, -10)
	punto_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	punto_draw.draw.connect(func():
		var c := Vector2(10, 10)
		if _apuntando_al_gato:
			var col := Color(1.0, 0.25, 0.25) if estado_actual == Estado.VARILLA_EN_SOPORTE_TITILANDO else Color(1.0, 0.85, 0.2)
			punto_draw.draw_circle(c, 5.0, col)
			punto_draw.draw_arc(c, 8.5, 0, TAU, 18, Color(col.r, col.g, col.b, 0.5), 1.5)
		else:
			punto_draw.draw_circle(c, 3.0, Color(1.0, 1.0, 1.0, 0.45))
	)
	punto_centro.add_child(punto_draw)

func _configurar_audio() -> void:
	_audio_stream = AudioStreamPlayer3D.new()
	_audio_stream.name = "AudioGato"
	_audio_stream.max_distance = 15.0
	_audio_stream.bus = "Master"
	add_child(_audio_stream)

# ─────────────────────────────────────────────────────────────
# PROCESAMIENTO Y VISIBILIDAD CONDICIONAL DEL LABEL3D
# ─────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_tiempo_acumulado += delta
	camara_activa = get_viewport().get_camera_3d()
	
	# Asegurar que el brazo elevador esté abajo en estados de reposo
	if estado_actual != Estado.ANIMANDO_SUBIDA and estado_actual != Estado.ARRIBA_ELEVADO and estado_actual != Estado.ANIMANDO_BAJADA:
		if is_instance_valid(brazo_mesh):
			brazo_mesh.rotation = BRAZO_ROT_ABAJO
		if is_instance_valid(plato_mesh):
			plato_mesh.rotation = PLATO_ROT_ABAJO
	
	if pivote_prompt and pivote_prompt.visible:
		var float_offset := sin(_tiempo_acumulado * 3.5) * 0.03
		prompt_label_3d.position.y = 0.35 + float_offset
		
	if estado_actual == Estado.EN_COLOCACION:
		_procesar_posicionamiento_colocacion()
		if canvas_reticula: canvas_reticula.visible = false
		if pivote_prompt: pivote_prompt.visible = true
		return
	else:
		if canvas_reticula: canvas_reticula.visible = true
		
	_evaluar_enfoque_reticula_central()

func _evaluar_enfoque_reticula_central() -> void:
	if not camara_activa:
		if pivote_prompt: pivote_prompt.visible = false
		return
		
	var dist_jugador := camara_activa.global_position.distance_to(global_position)
	var en_rango := dist_jugador <= distancia_interaccion_max
	
	var estaba_apuntando := _apuntando_al_gato
	_apuntando_al_gato = false
	
	var es_animando := (
		estado_actual == Estado.ANIMANDO_MONTAR_VARILLA or
		estado_actual == Estado.ANIMANDO_SUBIDA or
		estado_actual == Estado.ANIMANDO_BAJADA or
		estado_actual == Estado.ANIMANDO_GUARDAR_VARILLA or
		estado_actual == Estado.RECOGIDO
	)
	
	if en_rango and not es_animando:
		var pos_interes := pivote_prompt.global_position if is_instance_valid(pivote_prompt) else (global_position + Vector3(0, 0.25, 0))
		var en_pantalla := not camara_activa.is_position_behind(pos_interes)
		
		var centro := get_viewport().get_visible_rect().size * 0.5
		var ray_from := camara_activa.project_ray_origin(centro)
		var ray_dir := camara_activa.project_ray_normal(centro)
		var hacia_gato := (pos_interes - ray_from).normalized()
		var producto_punto := ray_dir.dot(hacia_gato)
		
		# Apuntando al gato: cono amplio y cómodo para móviles
		if en_pantalla and producto_punto > 0.60:
			_apuntando_al_gato = true
			
		# El label 3D siempre guía al jugador si está en rango y en el campo de visión
		if pivote_prompt:
			pivote_prompt.visible = en_pantalla and (producto_punto > 0.35)
	else:
		if pivote_prompt:
			pivote_prompt.visible = false
			
	if estaba_apuntando != _apuntando_al_gato and punto_centro:
		var draw_node = punto_centro.get_child(0) as Control
		if draw_node: draw_node.queue_redraw()

# ─────────────────────────────────────────────────────────────
# CONTROL TÁCTIL ESTRICTO (CERO DISPAROS AL ARRASTRAR CÁMARA)
# ─────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if estado_actual == Estado.EN_COLOCACION:
		if event.is_action_pressed("ui_accept"):
			fijar_en_suelo()
		return
		
	# 1. Botón nativo de interacción del juego o tecla estándar
	if event.is_action_pressed("interactuar") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		if _apuntando_al_gato or (pivote_prompt and pivote_prompt.visible):
			ejecutar_accion_contextual_actual()
			return
			
	# 2. Toque táctil móvil estricto: SÓLO si es un tap rápido (< 12px de desplazamiento)
	if event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed:
			_touch_inicio_pos = touch_ev.position
			_touch_inicio_tiempo = Time.get_ticks_msec()
			_arrastrando_pantalla = false
		else:
			var delta_pos: float = touch_ev.position.distance_to(_touch_inicio_pos)
			var tiempo_toque: float = float(Time.get_ticks_msec() - _touch_inicio_tiempo) / 1000.0
			# Si arrastró el dedo más de 12px para rotar la vista, SE IGNORA
			if delta_pos < 12.0 and tiempo_toque < 0.28 and not _arrastrando_pantalla:
				if _apuntando_al_gato or (pivote_prompt and pivote_prompt.visible):
					ejecutar_accion_contextual_actual()
		return
		
	if event is InputEventScreenDrag:
		_arrastrando_pantalla = true
		return
		
	# 3. Clic izquierdo en PC sólo como tap estático
	if event is InputEventMouseButton:
		var mouse_ev := event as InputEventMouseButton
		if mouse_ev.button_index == MOUSE_BUTTON_LEFT:
			if mouse_ev.pressed:
				_touch_inicio_pos = mouse_ev.position
			else:
				var delta_mouse: float = mouse_ev.position.distance_to(_touch_inicio_pos)
				if delta_mouse < 5.0 and (_apuntando_al_gato or (pivote_prompt and pivote_prompt.visible)):
					ejecutar_accion_contextual_actual()

# ─────────────────────────────────────────────────────────────
# 1. MODO COLOCACIÓN
# ─────────────────────────────────────────────────────────────
func iniciar_modo_colocacion() -> void:
	estado_actual = Estado.EN_COLOCACION
	visible = true
	if canvas_ui_colocacion: canvas_ui_colocacion.visible = true
	_forzar_varilla_en_soporte()
	_detener_titileo_varilla()
	_actualizar_prompt("📍 Toca 'Listo' para colocar")
	emit_signal("estado_cambiado", estado_actual)

func _procesar_posicionamiento_colocacion() -> void:
	if not camara_activa:
		return
		
	var origen_cam := camara_activa.global_position
	var forward_cam := -camara_activa.global_transform.basis.z.normalized()
	var forward_horizontal := Vector3(forward_cam.x, 0.0, forward_cam.z).normalized()
	if forward_horizontal.length_squared() < 0.01:
		forward_horizontal = Vector3.FORWARD
		
	var target_pos := origen_cam + (forward_horizontal * distancia_colocacion_m)
	target_pos.y = origen_cam.y + 0.6
	
	if raycast_suelo:
		raycast_suelo.global_position = target_pos
		raycast_suelo.force_raycast_update()
		if raycast_suelo.is_colliding():
			global_position = global_position.lerp(raycast_suelo.get_collision_point(), 0.32)
		else:
			target_pos.y = origen_cam.y - 1.45
			global_position = global_position.lerp(target_pos, 0.32)
	else:
		target_pos.y = origen_cam.y - 1.45
		global_position = global_position.lerp(target_pos, 0.32)
		
	var angulo_cam := atan2(forward_horizontal.x, forward_horizontal.z)
	rotation.y = lerp_angle(rotation.y, angulo_cam, 0.22)

func _on_btn_listo_presionado() -> void:
	if estado_actual == Estado.EN_COLOCACION:
		fijar_en_suelo()

func fijar_en_suelo() -> void:
	visible = true
	if canvas_ui_colocacion: canvas_ui_colocacion.visible = false
	if raycast_suelo:
		raycast_suelo.force_raycast_update()
		if raycast_suelo.is_colliding():
			global_position = raycast_suelo.get_collision_point()
			
	_forzar_varilla_en_soporte()
	_reproducir_sfx_clic_metalico()
	emit_signal("gato_posicionado", global_position)
	
	_activar_estado_varilla_titilando()

# ─────────────────────────────────────────────────────────────
# 2. VARILLA TITILANDO EN ROJO
# ─────────────────────────────────────────────────────────────
func _activar_estado_varilla_titilando() -> void:
	estado_actual = Estado.VARILLA_EN_SOPORTE_TITILANDO
	_forzar_varilla_en_soporte()
	_posicionar_pivote_prompt_en_varilla()
	_actualizar_prompt("🔴 Toca la varilla para montarla", Color(1.0, 0.25, 0.25))
	_iniciar_titileo_rojo_varilla()
	emit_signal("estado_cambiado", estado_actual)

func _iniciar_titileo_rojo_varilla() -> void:
	_detener_titileo_varilla()
	
	var mi_varilla: MeshInstance3D = null
	if varilla_mesh is MeshInstance3D: mi_varilla = varilla_mesh as MeshInstance3D
	elif varilla_mesh: mi_varilla = varilla_mesh.find_child("*", true, false) as MeshInstance3D
		
	if mi_varilla:
		if not _mat_varilla_override:
			_mat_varilla_override = StandardMaterial3D.new()
			_mat_varilla_override.albedo_color = Color(0.95, 0.15, 0.15)
			_mat_varilla_override.emission_enabled = true
			_mat_varilla_override.emission = Color(1.0, 0.1, 0.1)
			_mat_varilla_override.emission_energy_multiplier = 2.5
		mi_varilla.material_override = _mat_varilla_override
		
	_tw_titileo = create_tween().set_loops()
	_tw_titileo.tween_property(prompt_label_3d, "modulate", Color(1.0, 0.95, 0.95), 0.32)
	if _mat_varilla_override:
		_tw_titileo.parallel().tween_property(_mat_varilla_override, "emission_energy_multiplier", 3.2, 0.32)
	_tw_titileo.tween_property(prompt_label_3d, "modulate", Color(1.0, 0.18, 0.18), 0.32)
	if _mat_varilla_override:
		_tw_titileo.parallel().tween_property(_mat_varilla_override, "emission_energy_multiplier", 0.3, 0.32)

func _detener_titileo_varilla() -> void:
	if _tw_titileo and _tw_titileo.is_valid():
		_tw_titileo.kill()
		_tw_titileo = null
		
	prompt_label_3d.modulate = Color.WHITE
	var mi_varilla: MeshInstance3D = null
	if varilla_mesh is MeshInstance3D: mi_varilla = varilla_mesh as MeshInstance3D
	elif varilla_mesh: mi_varilla = varilla_mesh.find_child("*", true, false) as MeshInstance3D
	if mi_varilla: mi_varilla.material_override = null

# ─────────────────────────────────────────────────────────────
# 3. ACCIONES DEL CICLO MECÁNICO
# ─────────────────────────────────────────────────────────────
func ejecutar_accion_contextual_actual() -> void:
	match estado_actual:
		Estado.VARILLA_EN_SOPORTE_TITILANDO:
			ejecutar_montar_varilla()
		Estado.LISTO_PARA_SUBIR:
			ejecutar_subida()
		Estado.ARRIBA_ELEVADO:
			ejecutar_bajada()
		Estado.LISTO_PARA_GUARDAR:
			ejecutar_guardar_varilla()
		Estado.LISTO_PARA_RECOGER:
			recoger_gato()

func ejecutar_montar_varilla() -> void:
	_detener_titileo_varilla()
	estado_actual = Estado.ANIMANDO_MONTAR_VARILLA
	_actualizar_prompt("⚙️ Enroscando varilla...", Color(1.0, 0.8, 0.2))
	emit_signal("estado_cambiado", estado_actual)
	_reproducir_sfx_enroscar()
	_reproducir_animacion_clip("montar_varilla", 0.0, 4.41)

func ejecutar_subida() -> void:
	estado_actual = Estado.ANIMANDO_SUBIDA
	_actualizar_prompt("⚡ Bombeando y elevando...", Color(0.2, 0.9, 0.4))
	emit_signal("estado_cambiado", estado_actual)
	_reproducir_sfx_bombeo_continuo()
	_reproducir_animacion_clip("subir_gato", 4.79, 9.37)

func ejecutar_bajada() -> void:
	estado_actual = Estado.ANIMANDO_BAJADA
	_actualizar_prompt("💨 Bajando chasis...", Color(0.3, 0.7, 1.0))
	emit_signal("estado_cambiado", estado_actual)
	_reproducir_sfx_escape_presion()
	_reproducir_animacion_clip("bajar_gato", 10.0, 14.25)

func ejecutar_guardar_varilla() -> void:
	estado_actual = Estado.ANIMANDO_GUARDAR_VARILLA
	_actualizar_prompt("↩️ Desenroscando y guardando...", Color(0.9, 0.7, 0.3))
	emit_signal("estado_cambiado", estado_actual)
	_reproducir_sfx_enroscar()
	# Desenroscar es EXACTAMENTE la animación de montar pero al revés
	_reproducir_desenroscar_reversa()

func _reproducir_desenroscar_reversa() -> void:
	if not anim_player:
		get_tree().create_timer(3.5).timeout.connect(func(): _on_animacion_terminada("guardar_varilla"))
		return
		
	# Reproducir montar_varilla en reversa
	if anim_player.has_animation("montar_varilla"):
		anim_player.speed_scale = 1.0 * velocidad_animacion
		anim_player.play_backwards("montar_varilla")
	elif anim_player.has_animation("guardar_varilla"):
		anim_player.speed_scale = velocidad_animacion
		anim_player.play("guardar_varilla")
	else:
		_reproducir_animacion_clip("guardar_varilla", 0.0, 4.41, true)

func recoger_gato() -> void:
	estado_actual = Estado.RECOGIDO
	_actualizar_prompt("📦 ¡Gato recogido!", Color(0.3, 1.0, 0.4))
	if canvas_reticula: canvas_reticula.visible = false
	if pivote_prompt: pivote_prompt.visible = false
	emit_signal("estado_cambiado", estado_actual)
	emit_signal("gato_recogido")
	_reproducir_sfx_clic_metalico()
	
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.35)
	tw.tween_callback(func(): queue_free()).set_delay(0.36)

# ─────────────────────────────────────────────────────────────
# 4. GESTIÓN DE ANIMACIÓN
# ─────────────────────────────────────────────────────────────
func _reproducir_animacion_clip(nombre_clip: String, fallback_start: float, fallback_end: float, reverso: bool = false) -> void:
	if not anim_player:
		var duracion := absf(fallback_end - fallback_start)
		get_tree().create_timer(duracion).timeout.connect(func(): _on_animacion_terminada(nombre_clip))
		return
		
	if anim_player.has_animation(nombre_clip):
		anim_player.speed_scale = -velocidad_animacion if reverso else velocidad_animacion
		if reverso:
			var anim = anim_player.get_animation(nombre_clip)
			anim_player.play(nombre_clip)
			anim_player.seek(anim.length, true)
		else:
			anim_player.play(nombre_clip)
		return
		
	var main_anim := ""
	for anim_name in anim_player.get_animation_list():
		if "Action" in anim_name or "Scene" in anim_name or "Varilla" in anim_name:
			main_anim = anim_name
			break
			
	if main_anim != "":
		anim_player.speed_scale = velocidad_animacion
		anim_player.play(main_anim)
		if reverso:
			anim_player.speed_scale = -velocidad_animacion
			anim_player.seek(fallback_end, true)
		else:
			anim_player.seek(fallback_start, true)
			
		var dur := absf(fallback_end - fallback_start) / velocidad_animacion
		get_tree().create_timer(dur).timeout.connect(func():
			anim_player.pause()
			_on_animacion_terminada(nombre_clip)
		)
	else:
		get_tree().create_timer(2.0).timeout.connect(func(): _on_animacion_terminada(nombre_clip))

func _on_animacion_terminada(nombre_anim: StringName) -> void:
	match estado_actual:
		Estado.ANIMANDO_MONTAR_VARILLA:
			estado_actual = Estado.LISTO_PARA_SUBIR
			_actualizar_prompt("⬆️ Toca la palanca para subir", Color(0.25, 0.9, 0.45))
			_posicionar_pivote_prompt_en_palanca_montada()
			emit_signal("estado_cambiado", estado_actual)
			
		Estado.ANIMANDO_SUBIDA:
			estado_actual = Estado.ARRIBA_ELEVADO
			_actualizar_prompt("⬇️ Toca la palanca para bajar", Color(0.3, 0.75, 1.0))
			emit_signal("estado_cambiado", estado_actual)
			emit_signal("elevacion_completada")
			_notificar_sistema_pinchazos(true)
			
		Estado.ANIMANDO_BAJADA:
			estado_actual = Estado.LISTO_PARA_GUARDAR
			if is_instance_valid(brazo_mesh): brazo_mesh.rotation = BRAZO_ROT_ABAJO
			if is_instance_valid(plato_mesh): plato_mesh.rotation = PLATO_ROT_ABAJO
			_actualizar_prompt("↩️ Toca la varilla para guardarla", Color(1.0, 0.75, 0.25))
			emit_signal("estado_cambiado", estado_actual)
			emit_signal("descenso_completado")
			_notificar_sistema_pinchazos(false)
			
		Estado.ANIMANDO_GUARDAR_VARILLA:
			estado_actual = Estado.LISTO_PARA_RECOGER
			_forzar_posicion_reposo()
			_posicionar_pivote_prompt_en_chasis()
			_actualizar_prompt("📦 Toca el gato para recogerlo", Color(0.95, 0.85, 0.2))
			emit_signal("estado_cambiado", estado_actual)
			emit_signal("varilla_guardada")

func _notificar_sistema_pinchazos(vehiculo_arriba: bool) -> void:
	var sp = get_tree().get_first_node_in_group("sistema_pinchazos")
	if sp:
		sp.set("vehiculo_levantado", vehiculo_arriba)
		sp.set("gato_colocado", true)
		sp.set("nodo_gato_3d", self)

# ─────────────────────────────────────────────────────────────
# 5. TEXTOS Y POSICIONES DE PROMPTS DIEGÉTICOS
# ─────────────────────────────────────────────────────────────
func _actualizar_prompt(texto: String, color: Color = Color.WHITE) -> void:
	if prompt_label_3d:
		prompt_label_3d.text = texto
		prompt_label_3d.modulate = color
		prompt_label_3d.outline_modulate = Color(0.04, 0.05, 0.08, 0.95)

func _posicionar_pivote_prompt_en_varilla() -> void:
	if pivote_prompt:
		pivote_prompt.position = Vector3(0.20, 0.12, -0.15)

func _posicionar_pivote_prompt_en_palanca_montada() -> void:
	if pivote_prompt:
		pivote_prompt.position = Vector3(-0.25, 0.35, 0.0)

func _posicionar_pivote_prompt_en_chasis() -> void:
	if pivote_prompt:
		pivote_prompt.position = Vector3(0.15, 0.22, 0.0)

# ─────────────────────────────────────────────────────────────
# 6. AUDIO PROCEDURAL
# ─────────────────────────────────────────────────────────────
func _reproducir_sfx_clic_metalico() -> void:
	_tocar_tono(440.0, 0.08, 0.3)

func _reproducir_sfx_enroscar() -> void:
	_tocar_tono(320.0, 0.12, 0.25)

func _reproducir_sfx_bombeo_continuo() -> void:
	_tocar_tono(180.0, 0.35, 0.4)

func _reproducir_sfx_escape_presion() -> void:
	_tocar_tono(220.0, 0.45, 0.3)

func _tocar_tono(freq: float, duracion: float, volumen: float = 0.3) -> void:
	if not _audio_stream:
		return
	var sample_rate := 22050
	var num_samples := int(sample_rate * duracion)
	var pcm := PackedByteArray()
	pcm.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / num_samples)
		var sample := sin(2.0 * PI * freq * t) * envelope * volumen
		var val_16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val_16)
		
	var stream_sample := AudioStreamWAV.new()
	stream_sample.format = AudioStreamWAV.FORMAT_16_BITS
	stream_sample.mix_rate = sample_rate
	stream_sample.data = pcm
	_audio_stream.stream = stream_sample
	_audio_stream.play()
