extends CharacterBody3D

# --- CONSTANTES ---
const VELOCIDAD_CAMINAR: float = 5.0
const VELOCIDAD_CORRER: float = 8.0
const VELOCIDAD_AGACHADO: float = 2.5
const FUERZA_SALTO: float = 4.5
const SENSIBILIDAD_RATON: float = 0.002
const ALTURA_DE_PIE: float = 0.6
const ALTURA_AGACHADO: float = 0.2  
const FRECUENCIA_BOB: float = 2.4   
const AMPLITUD_BOB: float = 0.08    
const TIEMPO_EXCEPCION_COLISION_SALIDA: float = 0.25

# --- VARIABLES CONFIGURABLES ---
@export_group("Control / Cámara")
@export var modo_movil: bool = true 
@export var sensibilidad_tactil: float = 0.005

@export_group("Posicionamiento de Cámara")
## Posición del pivot o cabeza respecto al jugador (X, Y=altura, Z)
@export var camara_posicion_offset: Vector3 = Vector3(0.0, 1.6, 0.0):
	set(val):
		camara_posicion_offset = val
		_actualizar_posicion_camara_export()

## Offset local de la cámara (desfase horizontal/vertical/profundidad)
@export var camara_offset_local: Vector3 = Vector3.ZERO:
	set(val):
		camara_offset_local = val
		_actualizar_posicion_camara_export()

## Rotación base de la cámara en grados (X, Y, Z)
@export var camara_rotacion_base: Vector3 = Vector3.ZERO:
	set(val):
		camara_rotacion_base = val
		_actualizar_posicion_camara_export()

@export_group("Mecánicas de Movimiento")
@export var velocidad_inclinacion: float = 10.0      
@export var angulo_inclinacion: float = 0.2       
@export var desplazamiento_inclinacion: float = -0.5     

@export_group("Daño por Caída")
@export var umbral_caida: float = -12.0 
@export var multiplicador_daño: float = 4.0

@export_group("Debug / Economía")
## Presiona esta casilla en el Inspector para añadir dinero a DatosUsuario
@export var debug_anadir_dinero: bool = false:
	set(val):
		if val:
			debug_anadir_dinero = false
			anadir_dinero(cantidad_dinero_debug)

## Cantidad de dinero (COP) a añadir
@export var cantidad_dinero_debug: float = 1000.0

## Presiona esta casilla en el Inspector para añadir esmeraldas a DatosUsuario
@export var debug_anadir_esmeraldas: bool = false:
	set(val):
		if val:
			debug_anadir_esmeraldas = false
			anadir_esmeraldas(cantidad_esmeraldas_debug)

## Cantidad de esmeraldas a añadir
@export var cantidad_esmeraldas_debug: int = 10

# --- REFERENCIAS ---
@onready var nodo_cabeza: Node3D = $Head
@onready var nodo_camara: Camera3D = $Head/Camera3D
@onready var shader_velocidad: ColorRect = $Head/Camera3D/CanvasLayer/ColorRect
@onready var componente_salud: Node = $HealthComponent
@onready var componente_hambre: Node = $HungerComponent
@onready var escena_hud: CanvasLayer = $HUD
@onready var ui_pie: CanvasLayer = $UIpie 
@onready var sonido_pasos: AudioStreamPlayer3D = $SonidoPasos
@onready var sonido_impacto: AudioStreamPlayer3D = $SonidoImpacto
@onready var luz_linterna: SpotLight3D = $Head/linterna
@onready var rayo_interaccion: RayCast3D = $InteraccionRay 

# --- VARIABLES DE ESTADO INTERNO ---
var velocidad_actual: float = 5.0
var tiempo_bob: float = 0.0
var inclinacion_actual: float = 0.0                
var velocidad_vertical_previa: float = 0.0  
var esta_agachado: bool = false
var esta_conduciendo: bool = false
var vehiculo_actual: RigidBody3D = null
var timer_pasos: float = 0.0
var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _ultimo_frame_interaccion: int = -1

# --- MÉTODOS PRINCIPALES ---

func es_autoridad_local() -> bool:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return true
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return true
	return is_multiplayer_authority()

func _ready() -> void:
	if not es_autoridad_local():
		add_to_group("jugador_remoto")
		if nodo_camara:
			nodo_camara.current = false
		if escena_hud:
			escena_hud.visible = false
		if ui_pie:
			ui_pie.visible = false
		if shader_velocidad and shader_velocidad.get_parent() is CanvasLayer:
			(shader_velocidad.get_parent() as CanvasLayer).visible = false
		if rayo_interaccion:
			rayo_interaccion.enabled = false
		if luz_linterna:
			luz_linterna.visible = false
		return

	add_to_group("jugador")
	if rayo_interaccion:
		rayo_interaccion.collision_mask |= 2
	
	# El ratón nunca se captura, siempre visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_configurar_componentes()
	if luz_linterna: luz_linterna.visible = false

	_conectar_controles_tactiles()
	restaurar_camara_salida_vehiculo()

func _input(event: InputEvent) -> void:
	pass

func _unhandled_input(_evento: InputEvent) -> void:
	if not es_autoridad_local():
		return
	if Input.is_action_just_pressed("quit"):
		get_tree().change_scene_to_file("res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn")
		return
	_procesar_interaccion_vehiculo()

func _physics_process(delta: float) -> void:
	if not es_autoridad_local():
		# En jugadores remotos, actualizar visibilidad y colisión según si están conduciendo
		visible = not esta_conduciendo
		if has_node("CollisionShape3D"):
			$CollisionShape3D.disabled = esta_conduciendo
		if nodo_cabeza:
			var alt_remota := ALTURA_AGACHADO if esta_agachado else ALTURA_DE_PIE
			nodo_cabeza.position.y = lerp(nodo_cabeza.position.y, alt_remota, delta * 10.0)
		return

	_procesar_interaccion_vehiculo()

	if esta_conduciendo:
		if vehiculo_actual: global_position = vehiculo_actual.global_position
		return

	_aplicar_gravedad(delta)
	
	# --- INPUT HÍBRIDO ---
	var input_dir = _obtener_direccion_entrada()
	
	if _peticion_salto() and is_on_floor():
		velocity.y = FUERZA_SALTO
		esta_agachado = false 

	_procesar_estados_movimiento(input_dir, delta)
	_aplicar_movimiento(input_dir, delta)
	_procesar_visuales(delta, input_dir)
	
	velocidad_vertical_previa = velocity.y
	move_and_slide()
	
	if is_on_floor() and velocidad_vertical_previa < umbral_caida:
		_detectar_impacto_caida()

# --- SISTEMA DE ENTRADA HÍBRIDO (PC/MÓVIL) ---

func _obtener_direccion_entrada() -> Vector2:
	# Prioridad Joystick Táctil (desde UIPie raíz o metadato en JoystickIzq)
	if ui_pie:
		var dir_root = ui_pie.get("direccion")
		if dir_root is Vector2 and dir_root != Vector2.ZERO:
			return dir_root
		var joystick = ui_pie.get_node_or_null("Controles/JoystickIzq")
		if joystick:
			var dir_joy = joystick.get("direccion")
			if dir_joy is Vector2 and dir_joy != Vector2.ZERO:
				return dir_joy
			if joystick.has_meta("direccion"):
				var meta_dir = joystick.get_meta("direccion")
				if meta_dir is Vector2 and meta_dir != Vector2.ZERO:
					return meta_dir
	# Alternativa Teclado
	return Input.get_vector("izquierda", "derecha", "acelerar", "frenar")

func _peticion_salto() -> bool:
	return Input.is_action_just_pressed("jump") or _check_boton_ui("BotonSalto")

func _peticion_agachar() -> bool:
	return Input.is_action_just_pressed("crouch") or _check_boton_ui("BotonAgacharse")

func _peticion_interactuar() -> bool:
	return Input.is_action_just_pressed("interactuar") \
		or _check_boton_ui("BotonInteractuar") \
		or _check_boton_ui("Interactuar")

func _procesar_interaccion_vehiculo() -> void:
	if not _peticion_interactuar():
		return

	var frame_actual: int = Engine.get_process_frames()
	if _ultimo_frame_interaccion == frame_actual:
		return
	_ultimo_frame_interaccion = frame_actual

	if esta_conduciendo:
		salir_del_vehiculo()
	else:
		_intentar_entrar_vehiculo()

func _peticion_correr() -> bool:
	return Input.is_action_pressed("run") or _check_boton_ui_mantener("BotonCorrer")

func _check_boton_ui(nombre: String) -> bool:
	if ui_pie:
		var btn = ui_pie.get_node_or_null("Controles/" + nombre)
		if btn and btn.get("esta_presionado"): # Tu script de botón debe resetear esto
			btn.esta_presionado = false 
			return true
	return false

func _check_boton_ui_mantener(nombre: String) -> bool:
	if ui_pie:
		var btn = ui_pie.get_node_or_null("Controles/" + nombre)
		if btn: return btn.get("presionado_actualmente")
	return false

# --- CÁMARA ---

func _conectar_controles_tactiles() -> void:
	if ui_pie:
		await get_tree().process_frame
		if ui_pie.has_signal("camara_movida") and not ui_pie.camara_movida.is_connected(_manejar_camara_tactil):
			ui_pie.camara_movida.connect(_manejar_camara_tactil)
		var zona = ui_pie.get_node_or_null("Controles/ZonaCamara")
		if zona and zona.has_signal("camara_movida") and not zona.camara_movida.is_connected(_manejar_camara_tactil):
			zona.camara_movida.connect(_manejar_camara_tactil)

func _manejar_camara_tactil(relativo: Vector2) -> void:
	_rotar_camara(relativo * sensibilidad_tactil)

func _rotar_camara(relativo: Vector2) -> void:
	rotate_y(-relativo.x)
	nodo_cabeza.rotate_x(-relativo.y)
	nodo_cabeza.rotation.x = clamp(nodo_cabeza.rotation.x, deg_to_rad(-80), deg_to_rad(80))

# --- VEHÍCULO ---

func _intentar_entrar_vehiculo() -> void:
	if rayo_interaccion and rayo_interaccion.is_colliding():
		var col = rayo_interaccion.get_collider()
		if col and col.has_method("interactuar"):
			col.interactuar()
			return
		if col and col.has_method("subir_jugador"):
			entrar_al_vehiculo(col)
			return
	
	for v in get_tree().get_nodes_in_group("vehiculo"):
		if v.get("jugador_cerca") == true:
			entrar_al_vehiculo(v)
			break

func entrar_al_vehiculo(v_obj: RigidBody3D) -> void:
	esta_conduciendo = true
	vehiculo_actual = v_obj
	velocity = Vector3.ZERO
	self.visible = false
	$CollisionShape3D.set_deferred("disabled", true)
	if v_obj and v_obj is PhysicsBody3D:
		add_collision_exception_with(v_obj)
	if ui_pie: ui_pie.visible = false
	v_obj.subir_jugador(self)

func salir_del_vehiculo() -> void:
	if vehiculo_actual:
		var vehiculo_salida := vehiculo_actual
		esta_conduciendo = false
		vehiculo_actual = null
		velocity = Vector3.ZERO
		vehiculo_salida.bajar_jugador()
		self.visible = true
		$CollisionShape3D.set_deferred("disabled", false)
		restaurar_camara_salida_vehiculo()
		if ui_pie:
			ui_pie.process_mode = Node.PROCESS_MODE_INHERIT
			ui_pie.visible = true
		_finalizar_salida_vehiculo(vehiculo_salida)

func _actualizar_posicion_camara_export() -> void:
	if nodo_cabeza and is_instance_valid(nodo_cabeza) and camara_posicion_offset != Vector3.ZERO:
		nodo_cabeza.position = camara_posicion_offset
	if nodo_camara and is_instance_valid(nodo_camara):
		nodo_camara.position = camara_offset_local
		nodo_camara.rotation_degrees = camara_rotacion_base

func restaurar_camara_salida_vehiculo() -> void:
	if nodo_cabeza and is_instance_valid(nodo_cabeza) and camara_posicion_offset != Vector3.ZERO:
		nodo_cabeza.position = camara_posicion_offset
	if nodo_camara and is_instance_valid(nodo_camara):
		nodo_camara.visible = true
		nodo_camara.process_mode = Node.PROCESS_MODE_INHERIT
		nodo_camara.position = camara_offset_local
		nodo_camara.rotation_degrees = camara_rotacion_base
		nodo_camara.make_current()

func _finalizar_salida_vehiculo(vehiculo_salida: Node) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(TIEMPO_EXCEPCION_COLISION_SALIDA).timeout
	if is_instance_valid(vehiculo_salida) and vehiculo_salida is PhysicsBody3D:
		remove_collision_exception_with(vehiculo_salida)
	$CollisionShape3D.set_deferred("disabled", false)

# --- MOVIMIENTO Y FÍSICA ---

func _aplicar_gravedad(delta: float) -> void:
	if not is_on_floor(): velocity.y -= gravedad * delta

func _procesar_estados_movimiento(dir: Vector2, _delta: float) -> void:
	if _peticion_agachar():
		esta_agachado = !esta_agachado
		
	var quiere_correr = _peticion_correr() and is_on_floor() and dir.y < 0
	
	if quiere_correr:
		esta_agachado = false
		velocidad_actual = VELOCIDAD_CORRER
	elif esta_agachado:
		velocidad_actual = VELOCIDAD_AGACHADO
	else:
		velocidad_actual = VELOCIDAD_CAMINAR

func _aplicar_movimiento(dir: Vector2, delta: float) -> void:
	var direccion := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
	var suavizado = 7.0 if is_on_floor() else 2.0
	velocity.x = lerp(velocity.x, direccion.x * velocidad_actual, delta * suavizado)
	velocity.z = lerp(velocity.z, direccion.z * velocidad_actual, delta * suavizado)

func _procesar_visuales(delta: float, dir: Vector2) -> void:
	# Inclinación lateral (Lean)
	var obj_lean := Input.get_axis("inclin-der", "inclin-izq")
	inclinacion_actual = lerp(inclinacion_actual, obj_lean, delta * velocidad_inclinacion)
	
	# Altura de cabeza (Agachado)
	var altura_obj := ALTURA_AGACHADO if esta_agachado else ALTURA_DE_PIE
	nodo_cabeza.position.y = lerp(nodo_cabeza.position.y, altura_obj, delta * 10.0)
	nodo_cabeza.position.x = lerp(nodo_cabeza.position.x, inclinacion_actual * desplazamiento_inclinacion, delta * velocidad_inclinacion)
	nodo_cabeza.rotation.z = inclinacion_actual * angulo_inclinacion
	
	# Movimiento de cámara (Bobbing)
	if is_on_floor() and velocity.length() > 0.5 and dir != Vector2.ZERO:
		_manejar_bob_y_pasos(delta)
	else:
		nodo_camara.transform.origin = nodo_camara.transform.origin.lerp(Vector3.ZERO, delta * 15.0)

func _manejar_bob_y_pasos(delta: float) -> void:
	tiempo_bob += delta * velocity.length()
	nodo_camara.transform.origin.y = sin(tiempo_bob * FRECUENCIA_BOB) * AMPLITUD_BOB
	nodo_camara.transform.origin.x = cos(tiempo_bob * FRECUENCIA_BOB / 2) * AMPLITUD_BOB
	
	timer_pasos += delta * velocity.length()
	if timer_pasos > 2.2:
		if sonido_pasos:
			sonido_pasos.pitch_scale = randf_range(0.9, 1.1)
			sonido_pasos.play()
		timer_pasos = 0.0

func _detectar_impacto_caida() -> void:
	var intensidad = abs(velocidad_vertical_previa)
	if intensidad > abs(umbral_caida):
		if componente_salud: componente_salud.recibir_daño(int(intensidad * multiplicador_daño / 2.0))
		if sonido_impacto: sonido_impacto.play()

# --- COMPONENTES Y HUD ---

func _configurar_componentes() -> void:
	if shader_velocidad: shader_velocidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if componente_salud: componente_salud.salud_actualizada.connect(_actualizar_mi_hud)
	if componente_hambre: componente_hambre.hambre_actualizada.connect(_actualizar_mi_hud_hambre)

func _actualizar_mi_hud(s_act: int) -> void:
	if escena_hud: escena_hud.actualizar_barra_vida(s_act, 100)

func _actualizar_mi_hud_hambre(h_act: float, h_max: float) -> void:
	if escena_hud: escena_hud.actualizar_barra_hambre(h_act, h_max)

func alternar_linterna_jugador(estado: Variant = null) -> bool:
	if not luz_linterna:
		return false
	if estado is bool:
		luz_linterna.visible = estado
	else:
		luz_linterna.visible = not luz_linterna.visible
	return luz_linterna.visible

func _set_agachado(v: bool) -> void:
	esta_agachado = v

func puede_interactuar() -> bool:
	if esta_conduciendo:
		return false
	if rayo_interaccion and rayo_interaccion.is_colliding():
		var col = rayo_interaccion.get_collider()
		if col and (col.has_method("subir_jugador") or col.has_method("interactuar")):
			return true
	for v in get_tree().get_nodes_in_group("vehiculo"):
		if v and v.get("jugador_cerca") == true:
			return true
	return false

func interactuar_contextual() -> void:
	if esta_conduciendo:
		salir_del_vehiculo()
	else:
		_intentar_entrar_vehiculo()

func ejecutar_salto_tactil(fuerza_v: float, impulso_h: Vector3 = Vector3.ZERO) -> void:
	if esta_conduciendo:
		return
	if is_on_floor():
		velocity.y = maxf(fuerza_v, FUERZA_SALTO)
		if impulso_h.length() > 0.05:
			var imp_mundo := transform.basis * impulso_h
			velocity.x += imp_mundo.x
			velocity.z += imp_mundo.z
		esta_agachado = false

func ajustar_fov_suave(nuevo_fov: float) -> void:
	if nodo_camara and is_instance_valid(nodo_camara):
		var tw: Tween = create_tween()
		tw.tween_property(nodo_camara, "fov", clampf(nuevo_fov, 50.0, 110.0), 0.2)

func saludar() -> void:
	pass

func notificar_vehiculo_cerca(veh: Node3D) -> void:
	if veh and veh is RigidBody3D:
		vehiculo_actual = veh

func notificar_vehiculo_lejos(veh: Node3D = null) -> void:
	if veh == null or vehiculo_actual == veh:
		if not esta_conduciendo:
			vehiculo_actual = null


func ejecutar_parpadeo():
	var flash = get_node_or_null("CanvasLayer/Parpadeo")
	if flash:
		var mat = flash.material
		var tween = create_tween()
		tween.tween_property(mat, "shader_parameter/blink_progress", 1.0, 0.15)
		tween.tween_property(mat, "shader_parameter/blink_progress", 0.0, 0.25)

func anadir_dinero(monto: float) -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.dinero += monto
		if datos.has_method("guardar_progreso"):
			datos.call("guardar_progreso")
		print("[Player] Dinero añadido: +$", monto, " | Nuevo total: $", datos.dinero)

func anadir_esmeraldas(monto: int) -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.esmeraldas += monto
		if datos.has_method("guardar_progreso"):
			datos.call("guardar_progreso")
		print("[Player] Esmeraldas añadidas: +", monto, " | Nuevo total: ", datos.esmeraldas)
