extends CanvasLayer

@onready var barra_carga: ProgressBar = %BarraCarga
@onready var fade_overlay: ColorRect = %FadeOut
@onready var label_consejos: Label = %Consejos
@onready var titulo_juego: TextureRect = %TituloJuego
@onready var contenedor_ui: Control = %UI
@onready var fondo_textura: TextureRect = get_node_or_null("%FondoBase")
@onready var vignette_efecto: TextureRect = %Vignette
@onready var particulas_polvo: GPUParticles2D = %ParticulasPolvo
@onready var porcentaje_carga: Label = %PorcentajeCarga
@onready var estado_carga: Label = %EstadoCarga
@onready var atmosfera_shader: ColorRect = get_node_or_null("%AtmosferaShader")
@onready var haz_azul: ColorRect = get_node_or_null("%HazAzul")
@onready var haz_ambar: ColorRect = get_node_or_null("%HazAmbar")
@onready var destino_badge: Label = get_node_or_null("%DestinoBadge")
@onready var camera_carga: Camera3D = get_node_or_null("%CameraCarga")
@onready var radar_scanner: Node3D = get_node_or_null("SubViewportContainer/SubViewport/Escena3D/Diorama/RadarScanner")
@onready var truck_mover: Node3D = get_node_or_null("%ConvoyReal")
var _ruedas_convoy: Array[Node3D] = []

const ESCENA_DEFAULT := "res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn"
const RUTA_T800_SHOWCASE := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn"
const RUTA_CARPADO_SHOWCASE := "res://modelos3d/Trailers y remolques/Carpado/carpado.tscn"
const RUTA_ROBLE := "res://modelos3d/mapa/arboles/arbol_roble_3d.tscn"
const RUTA_MAT_CESPED := "res://materiales/Mapa/Cesped/Cesped.tres"
const INTENSIDAD_PARALLAX := 10.0
const DURACION_MINIMA_CARGA := 2.2

var _t800_instanciada := false
var _carpado_instanciado := false
var _tiempo_visible := 0.0

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
	"USA EL FRENO DE MOTOR EN DESCENSOS DE MONTANA.",
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
	_actualizar_destino_badge()
	_mejorar_entorno_natural()
	_solicitar_convoy_asincrono()
	_configurar_entrada()
	_iniciar_carga_threaded()

func _mejorar_entorno_natural() -> void:
	var diorama := get_node_or_null("SubViewportContainer/SubViewport/Escena3D/Diorama")
	var escena_3d := get_node_or_null("SubViewportContainer/SubViewport/Escena3D")
	if diorama:
		var mat_cesped: Material = load(RUTA_MAT_CESPED) if ResourceLoader.exists(RUTA_MAT_CESPED) else null
		var cola: Array[Node] = [diorama]
		while not cola.is_empty():
			var n: Node = cola.pop_back()
			if n is MeshInstance3D:
				var nm := n.name.to_lower()
				if nm.begins_with("pine_"):
					n.visible = false
				elif mat_cesped and (nm.begins_with("terrainbase") or nm.begins_with("andesridge")):
					n.material_override = mat_cesped
			for h in n.get_children():
				cola.append(h)
	if escena_3d and ResourceLoader.exists(RUTA_ROBLE):
		var roble_ps := load(RUTA_ROBLE) as PackedScene
		if roble_ps:
			var arboles_root := Node3D.new()
			arboles_root.name = "RoblesEntorno"
			escena_3d.add_child(arboles_root)
			var puntos: Array[Vector4] = [
				Vector4(-13.5, 0.0, -32.0, 1.2), Vector4(-16.0, 0.0, -18.0, 1.05),
				Vector4(-13.0, 0.0, -4.0, 1.25), Vector4(-15.5, 0.0, 12.0, 1.1),
				Vector4(-12.5, 0.0, 26.0, 1.15), Vector4(13.5, 0.0, -30.0, 1.15),
				Vector4(16.0, 0.0, -14.0, 1.3), Vector4(13.0, 0.0, 2.0, 1.1),
				Vector4(15.5, 0.0, 16.0, 1.05), Vector4(12.8, 0.0, 28.0, 1.2),
			]
			for i in range(puntos.size()):
				var p: Vector4 = puntos[i]
				var r := roble_ps.instantiate() as Node3D
				if r:
					r.position = Vector3(p.x, p.y, p.z)
					r.rotation.y = float(i) * 1.17
					r.scale = Vector3.ONE * p.w
					arboles_root.add_child(r)

func _solicitar_convoy_asincrono() -> void:
	if not truck_mover:
		return
	for ruta in [RUTA_T800_SHOWCASE, RUTA_CARPADO_SHOWCASE]:
		if ResourceLoader.exists(ruta):
			var st := ResourceLoader.load_threaded_get_status(ruta)
			if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or st == ResourceLoader.THREAD_LOAD_FAILED:
				ResourceLoader.load_threaded_request(ruta)

func _actualizar_carga_convoy() -> void:
	if not truck_mover:
		return
	if not _t800_instanciada and ResourceLoader.load_threaded_get_status(RUTA_T800_SHOWCASE) == ResourceLoader.THREAD_LOAD_LOADED:
		_t800_instanciada = true
		var ps := ResourceLoader.load_threaded_get(RUTA_T800_SHOWCASE) as PackedScene
		if ps:
			var inst := ps.instantiate()
			_desactivar_fisicas_y_scripts(inst)
			inst.name = "T800"
			if inst is Node3D:
				inst.position = Vector3.ZERO
			truck_mover.add_child(inst)
			_recolectar_ruedas_convoy()
		return
	if _t800_instanciada and not _carpado_instanciado and ResourceLoader.load_threaded_get_status(RUTA_CARPADO_SHOWCASE) == ResourceLoader.THREAD_LOAD_LOADED:
		_carpado_instanciado = true
		var ps2 := ResourceLoader.load_threaded_get(RUTA_CARPADO_SHOWCASE) as PackedScene
		if ps2:
			var inst2 := ps2.instantiate()
			_desactivar_fisicas_y_scripts(inst2)
			inst2.name = "Carpado"
			if inst2 is Node3D:
				inst2.position = Vector3(0.0, 0.0, 7.6)
			# Subir las patas del trailer para que circule enganchado
			var patas := inst2.find_child("Patas", true, false)
			if patas is Node3D:
				patas.position.y += 0.58
			truck_mover.add_child(inst2)
			_recolectar_ruedas_convoy()

func _desactivar_fisicas_y_scripts(raiz: Node) -> void:
	var cola: Array[Node] = [raiz]
	while not cola.is_empty():
		var n: Node = cola.pop_back()
		if n.get_script() != null:
			n.set_script(null)
		n.set_process(false)
		n.set_physics_process(false)
		n.set_process_input(false)
		n.set_process_unhandled_input(false)
		if n is RigidBody3D:
			n.freeze = true
			n.gravity_scale = 0.0
			n.collision_layer = 0
			n.collision_mask = 0
		elif n is CollisionShape3D:
			n.disabled = true
		elif n is Camera3D:
			n.current = false
		elif n is AudioStreamPlayer or n is AudioStreamPlayer3D:
			n.autoplay = false
			if n.playing:
				n.stop()
		for hijo in n.get_children():
			cola.append(hijo)

func _recolectar_ruedas_convoy() -> void:
	_ruedas_convoy.clear()
	if not truck_mover:
		return
	# 1. Ruedas reales de la T800 dentro de ControladorLlantas
	var t800 := truck_mover.get_node_or_null("T800")
	if t800:
		var ctrl_llantas := t800.find_child("ControladorLlantas", true, false)
		if ctrl_llantas:
			var cola_t: Array[Node] = [ctrl_llantas]
			while not cola_t.is_empty():
				var n: Node = cola_t.pop_back()
				if n is MeshInstance3D:
					_ruedas_convoy.append(n)
				for h in n.get_children():
					cola_t.append(h)
	# 2. Ruedas reales del trailer Carpado dentro de Ruedas/Rueda_*/Neumatico*
	var carpado := truck_mover.get_node_or_null("Carpado")
	if carpado:
		var ruedas_tr := carpado.find_child("Ruedas", true, false)
		if ruedas_tr:
			for ray in ruedas_tr.get_children():
				for neu in ray.get_children():
					if neu is Node3D and neu.name.to_lower().begins_with("neumatico"):
						_ruedas_convoy.append(neu)

func _actualizar_destino_badge() -> void:
	if not destino_badge:
		return
	var ruta := target_scene.to_lower()
	if ruta.contains("mainmenu"):
		destino_badge.text = "GARAJE PRINCIPAL"
	elif ruta.contains("perfil"):
		destino_badge.text = "PERFIL DE CONDUCTOR"
	elif ruta.contains("garaje"):
		destino_badge.text = "TALLER Y FLOTA"
	elif ruta.contains("tienda"):
		destino_badge.text = "CONCESIONARIO"
	else:
		destino_badge.text = "EN RUTA"


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
	var dt := minf(delta, 0.05)
	tiempo += dt
	_tiempo_visible += dt
	_actualizar_parallax(dt)
	_actualizar_consejo(dt)
	_actualizar_estado_ambiente(dt)
	_actualizar_logo(dt)
	_actualizar_efectos_luz(dt)

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

	var progreso_por_tiempo := clampf(_tiempo_visible / DURACION_MINIMA_CARGA, 0.0, 1.0)
	var objetivo_visual := minf(progreso_real, progreso_por_tiempo)
	progreso_visual = move_toward(progreso_visual, objetivo_visual, dt * 1.4)
	if barra_carga:
		barra_carga.value = progreso_visual * 100.0
	if porcentaje_carga:
		porcentaje_carga.text = "%3d%%" % roundi(progreso_visual * 100.0)
	if progreso_visual >= 0.99 and recurso_cargado != null and _tiempo_visible >= DURACION_MINIMA_CARGA:
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
	_actualizar_carga_convoy()
	if truck_mover:
		truck_mover.position.z -= delta * 7.8
		if truck_mover.position.z < -42.0:
			truck_mover.position.z = 26.0
		truck_mover.position.y = 0.05 + sin(tiempo * 8.5) * 0.02
		for r in _ruedas_convoy:
			if is_instance_valid(r):
				var dir_giro := 1.0 if r.basis.z.z < 0.0 else -1.0
				r.rotate_x(dir_giro * delta * 12.0)
	if camera_carga:
		var cam_z := (truck_mover.position.z - 11.5) if truck_mover else 14.0
		var cam_x := -4.6 + sin(tiempo * 0.45) * 1.1
		camera_carga.position = Vector3(cam_x, 3.2 + sin(tiempo * 0.6) * 0.22, cam_z)
		var look_target := Vector3(2.6, 2.0, (truck_mover.position.z + 1.5) if truck_mover else -4.0)
		camera_carga.look_at(look_target, Vector3.UP)
	if radar_scanner:
		radar_scanner.rotate_y(delta * 2.4)
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

	var datos := get_node_or_null("/root/DatosUsuario")
	if datos and "escenas_precargadas" in datos and datos.escenas_precargadas.has(target_scene):
		var cached: PackedScene = datos.escenas_precargadas[target_scene] as PackedScene
		if cached:
			recurso_cargado = cached
			progreso_real = 1.0
			cargando = true
			return

	var estado_prev := ResourceLoader.load_threaded_get_status(target_scene)
	if estado_prev == ResourceLoader.THREAD_LOAD_IN_PROGRESS or estado_prev == ResourceLoader.THREAD_LOAD_LOADED:
		cargando = true
		return

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
		estado_carga.text = "SISTEMAS LISTOS - ENTRANDO"
		estado_carga.add_theme_color_override("font_color", Color(0.32, 0.90, 0.56, 0.98))
	if porcentaje_carga:
		porcentaje_carga.text = "100%"
	if barra_carga:
		var fill_verde := StyleBoxFlat.new()
		fill_verde.bg_color = Color(0.24, 0.86, 0.48, 1.0)
		fill_verde.set_corner_radius_all(9)
		barra_carga.add_theme_stylebox_override("fill", fill_verde)
	await get_tree().create_timer(0.35).timeout

	var datos := get_node_or_null("/root/DatosUsuario")
	if datos and "next_scene" in datos:
		datos.next_scene = ""
	if datos and "escenas_precargadas" in datos and recurso_cargado:
		if target_scene.contains("MainMenuModerno") or target_scene.contains("Perfil_Menu"):
			datos.escenas_precargadas[target_scene] = recurso_cargado

	if fade_overlay:
		var fade_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.32)
		await fade_tween.finished

	if recurso_cargado:
		get_tree().change_scene_to_packed(recurso_cargado)
	else:
		get_tree().change_scene_to_file(target_scene)
