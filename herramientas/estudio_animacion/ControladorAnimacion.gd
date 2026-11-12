class_name ControladorAnimacion
extends Control

## Controlador maestro para el Estudio de Animación 3D.
## Permite animar de forma visual, rápida y natural a Jugador.tscn
## o cualquier escena/modelo con Skeleton3D.

signal esqueleto_cambiado(nuevo_esqueleto: Skeleton3D)
signal hueso_seleccionado(nombre_hueso: String, idx: int)

# Nodos de la escena 3D
@export var ruta_pivot_modelo: NodePath = ^"Visor3D/SubViewport/PivoteModelo"
@export var ruta_camara: NodePath = ^"Visor3D/SubViewport/CamaraEstudio"
@export var ruta_visualizador: NodePath = ^"Visor3D/SubViewport/VisualizadorHuesos"

# Nodos de la UI
@export var ruta_label_hueso_actual: NodePath
@export var ruta_slider_rot_x: NodePath
@export var ruta_slider_rot_y: NodePath
@export var ruta_slider_rot_z: NodePath
@export var ruta_spin_rot_x: NodePath
@export var ruta_spin_rot_y: NodePath
@export var ruta_spin_rot_z: NodePath

@export var ruta_panel_raiz_pos: NodePath
@export var ruta_slider_pos_x: NodePath
@export var ruta_slider_pos_y: NodePath
@export var ruta_slider_pos_z: NodePath
@export var ruta_spin_pos_x: NodePath
@export var ruta_spin_pos_y: NodePath
@export var ruta_spin_pos_z: NodePath

@export var ruta_slider_tiempo: NodePath
@export var ruta_label_tiempo: NodePath
@export var ruta_contenedor_marcas_kf: NodePath
@export var ruta_boton_play_pause: NodePath
@export var ruta_spin_duracion: NodePath
@export var ruta_check_loop: NodePath

@export var ruta_input_ruta_modelo: NodePath
@export var ruta_input_nombre_anim: NodePath
@export var ruta_menu_anim_existentes: NodePath
@export var ruta_lista_todos_huesos: NodePath
@export var ruta_filtro_huesos: NodePath
@export var ruta_contenedor_presets: NodePath
@export var ruta_label_notificacion: NodePath
@export var selector_rig: SelectorRigHumanoide

# Variables internas del modelo
var modelo_instanciado: Node3D = null
var esqueleto: Skeleton3D = null
var anim_player: AnimationPlayer = null
var hueso_actual_idx: int = -1
var hueso_actual_nombre: String = ""

# Animación y Keyframes
var keyframes: Array = [] # Array de diccionarios { "tiempo": float, "pose": Dictionary }
var tiempo_actual: float = 0.0
var duracion_total: float = 1.0
var reproduciendo: bool = false
var loop_activo: bool = true
var velocidad_reproduccion: float = 1.0
var buffer_pose_copiada: Dictionary = {}

var _bloqueando_senales_ui: bool = false
var _nombre_hueso_raiz: String = "mixamorig_Hips"

# Referencias a nodos resueltos
var pivote_modelo: Node3D
var camara_estudio: CamaraEstudio
var visualizador_huesos: VisualizadorHuesos

func _ready():
	pivote_modelo = get_node_or_null(ruta_pivot_modelo)
	camara_estudio = get_node_or_null(ruta_camara)
	visualizador_huesos = get_node_or_null(ruta_visualizador)
	
	if visualizador_huesos:
		visualizador_huesos.hueso_seleccionado_en_3d.connect(_on_hueso_seleccionado_en_3d)
		
	_conectar_eventos_ui()
	_poblar_presets_en_ui()
	
	# Cargar modelo por defecto: Jugador.tscn
	var ruta_defecto = "res://modelos3d/personajes/Jugador/Jugador.tscn"
	var edit_modelo = get_node_or_null(ruta_input_ruta_modelo) as LineEdit
	if edit_modelo:
		edit_modelo.text = ruta_defecto
		
	cargar_modelo(ruta_defecto)
	_actualizar_marcas_keyframes()

# ---------------------------------------------------------------------------
# CARGA Y DETECCIÓN DEL MODELO
# ---------------------------------------------------------------------------

func cargar_modelo(ruta_escena: String):
	if not ResourceLoader.exists(ruta_escena):
		_mostrar_notificacion("Archivo no encontrado: %s" % ruta_escena, true)
		return
		
	var packed = load(ruta_escena) as PackedScene
	if not packed:
		_mostrar_notificacion("No se pudo cargar la escena: %s" % ruta_escena, true)
		return
		
	# Limpiar modelo anterior
	if modelo_instanciado and is_instance_valid(modelo_instanciado):
		modelo_instanciado.queue_free()
		modelo_instanciado = null
		
	modelo_instanciado = packed.instantiate() as Node3D
	if not modelo_instanciado:
		_mostrar_notificacion("El nodo raíz debe ser Node3D", true)
		return
		
	# Congelar procesos de juego en el modelo cargado para manipularlo libremente
	modelo_instanciado.set_physics_process(false)
	modelo_instanciado.set_process(false)
	if modelo_instanciado is CollisionObject3D:
		modelo_instanciado.set_collision_layer_value(1, false)
		modelo_instanciado.set_collision_mask_value(1, false)
		
	# Desactivar HUD o UI anidada si existen
	for hijo in modelo_instanciado.get_children():
		if hijo is CanvasLayer or hijo.name.to_lower().contains("hud") or hijo.name.to_lower().contains("ui"):
			hijo.visible = false
			hijo.process_mode = Node.PROCESS_MODE_DISABLED
			
	pivote_modelo.add_child(modelo_instanciado)
	modelo_instanciado.position = Vector3.ZERO
	modelo_instanciado.rotation = Vector3.ZERO
	
	# Desactivar cámaras del modelo cargado y asegurar la cámara de estudio
	_desactivar_camaras_internas(modelo_instanciado)
	if camara_estudio:
		camara_estudio.make_current()
		
	# Desactivar procesos que puedan interferir con la pose manual
	_desactivar_scripts_modelo(modelo_instanciado)
	
	# Detectar esqueleto
	esqueleto = DatosAnimacion.buscar_esqueleto(modelo_instanciado)
	if not esqueleto:
		_mostrar_notificacion("Aviso: No se detectó Skeleton3D en la escena.", true)
	else:
		_mostrar_notificacion("Modelo cargado con éxito: %d huesos detectados." % esqueleto.get_bone_count())
		
	# Detectar AnimationPlayer
	anim_player = DatosAnimacion.buscar_animation_player(modelo_instanciado)
	if anim_player:
		anim_player.stop()
		_poblar_animaciones_existentes()
		
	if visualizador_huesos:
		visualizador_huesos.asignar_esqueleto(esqueleto)
		
	_poblar_lista_todos_huesos()
	
	# Detectar hueso raíz
	_determinar_hueso_raiz()
	
	# Seleccionar primer hueso por defecto (Hips o Torso)
	if esqueleto and esqueleto.get_bone_count() > 0:
		var idx_inicio = esqueleto.find_bone(_nombre_hueso_raiz)
		if idx_inicio < 0:
			idx_inicio = 0
		seleccionar_hueso_por_indice(idx_inicio)
		
	# Inicializar un keyframe base en t=0.0
	keyframes.clear()
	capturar_keyframe_actual()
	
	esqueleto_cambiado.emit(esqueleto)

func _desactivar_camaras_internas(nodo: Node):
	if nodo is Camera3D and nodo != camara_estudio:
		nodo.current = false
	for hijo in nodo.get_children():
		_desactivar_camaras_internas(hijo)

func _desactivar_scripts_modelo(nodo: Node):
	nodo.set_physics_process(false)
	nodo.set_process(false)
	nodo.set_process_input(false)
	nodo.set_process_unhandled_input(false)
	
	# Desactivar SkeletonIK3D si existen para que no sobreescriban poses manuales
	if nodo is SkeletonIK3D:
		nodo.stop()
		
	for hijo in nodo.get_children():
		_desactivar_scripts_modelo(hijo)


func _determinar_hueso_raiz():
	if not esqueleto:
		return
	if esqueleto.find_bone("mixamorig_Hips") >= 0:
		_nombre_hueso_raiz = "mixamorig_Hips"
	elif esqueleto.find_bone("Hips") >= 0:
		_nombre_hueso_raiz = "Hips"
	elif esqueleto.find_bone("pelvis") >= 0:
		_nombre_hueso_raiz = "pelvis"
	elif esqueleto.get_bone_count() > 0:
		_nombre_hueso_raiz = esqueleto.get_bone_name(0)

# ---------------------------------------------------------------------------
# SELECCIÓN Y MANIPULACIÓN DE HUESOS
# ---------------------------------------------------------------------------

func seleccionar_hueso_por_nombre(nombre_hueso: String):
	if not esqueleto:
		return
	var idx = esqueleto.find_bone(nombre_hueso)
	if idx >= 0:
		seleccionar_hueso_por_indice(idx)
	else:
		_mostrar_notificacion("Hueso no encontrado: %s" % nombre_hueso, true)

func seleccionar_hueso_por_indice(idx: int):
	if not esqueleto or idx < 0 or idx >= esqueleto.get_bone_count():
		return
		
	hueso_actual_idx = idx
	hueso_actual_nombre = esqueleto.get_bone_name(idx)
	
	if visualizador_huesos:
		visualizador_huesos.seleccionar_hueso(idx)
		
	_actualizar_ui_hueso_seleccionado()
	hueso_seleccionado.emit(hueso_actual_nombre, idx)

func _on_hueso_seleccionado_en_3d(nombre_hueso: String, idx: int):
	hueso_actual_idx = idx
	hueso_actual_nombre = nombre_hueso
	_actualizar_ui_hueso_seleccionado()
	hueso_seleccionado.emit(nombre_hueso, idx)

func _actualizar_ui_hueso_seleccionado():
	if not esqueleto or hueso_actual_idx < 0:
		return
		
	_bloqueando_senales_ui = true
	
	var label_hueso = get_node_or_null(ruta_label_hueso_actual) as Label
	if label_hueso:
		label_hueso.text = "Hueso: %s [#%d]" % [hueso_actual_nombre, hueso_actual_idx]
		
	var rot_q = esqueleto.get_bone_pose_rotation(hueso_actual_idx)
	var euler = rot_q.get_euler()
	var deg_x = rad_to_deg(euler.x)
	var deg_y = rad_to_deg(euler.y)
	var deg_z = rad_to_deg(euler.z)
	
	_set_slider_spin(ruta_slider_rot_x, ruta_spin_rot_x, deg_x)
	_set_slider_spin(ruta_slider_rot_y, ruta_spin_rot_y, deg_y)
	_set_slider_spin(ruta_slider_rot_z, ruta_spin_rot_z, deg_z)
	
	# Controles de posición de raíz
	var panel_raiz = get_node_or_null(ruta_panel_raiz_pos) as Control
	var es_raiz = (hueso_actual_nombre == _nombre_hueso_raiz or hueso_actual_idx == 0)
	if panel_raiz:
		panel_raiz.visible = es_raiz
		
	if es_raiz:
		var pos = esqueleto.get_bone_pose_position(hueso_actual_idx)
		_set_slider_spin(ruta_slider_pos_x, ruta_spin_pos_x, pos.x)
		_set_slider_spin(ruta_slider_pos_y, ruta_spin_pos_y, pos.y)
		_set_slider_spin(ruta_slider_pos_z, ruta_spin_pos_z, pos.z)
		
	_bloqueando_senales_ui = false

func _set_slider_spin(ruta_slider: NodePath, ruta_spin: NodePath, val: float):
	var sl = get_node_or_null(ruta_slider) as Range
	if sl:
		sl.value = val
	var sp = get_node_or_null(ruta_spin) as Range
	if sp:
		sp.value = val

func _aplicar_rotacion_desde_ui():
	if _bloqueando_senales_ui or not esqueleto or hueso_actual_idx < 0:
		return
		
	var rx = _get_spin_val(ruta_spin_rot_x)
	var ry = _get_spin_val(ruta_spin_rot_y)
	var rz = _get_spin_val(ruta_spin_rot_z)
	
	var q = Quaternion.from_euler(Vector3(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz)))
	esqueleto.set_bone_pose_rotation(hueso_actual_idx, q)

func _aplicar_posicion_desde_ui():
	if _bloqueando_senales_ui or not esqueleto or hueso_actual_idx < 0:
		return
		
	var px = _get_spin_val(ruta_spin_pos_x)
	var py = _get_spin_val(ruta_spin_pos_y)
	var pz = _get_spin_val(ruta_spin_pos_z)
	
	esqueleto.set_bone_pose_position(hueso_actual_idx, Vector3(px, py, pz))

func _get_spin_val(ruta_spin: NodePath) -> float:
	var sp = get_node_or_null(ruta_spin) as Range
	return sp.value if sp else 0.0

func rotar_hueso_delta(eje: String, delta_grados: float):
	if hueso_actual_idx < 0:
		return
	var ruta_spin = ruta_spin_rot_x if eje == "x" else (ruta_spin_rot_y if eje == "y" else ruta_spin_rot_z)
	var sp = get_node_or_null(ruta_spin) as Range
	if sp:
		sp.value = wrapf(sp.value + delta_grados, -180.0, 180.0)
		_sincronizar_slider_desde_spin(eje)
		_aplicar_rotacion_desde_ui()

func resetear_hueso_actual():
	if not esqueleto or hueso_actual_idx < 0:
		return
	esqueleto.reset_bone_pose(hueso_actual_idx)
	_actualizar_ui_hueso_seleccionado()

func resetear_toda_la_pose():
	if not esqueleto:
		return
	esqueleto.reset_bone_poses()
	_actualizar_ui_hueso_seleccionado()
	_mostrar_notificacion("Pose reiniciada a T-Pose.")

# ---------------------------------------------------------------------------
# ESPEJO, COPIADO Y BIBLIOTECA DE POSES
# ---------------------------------------------------------------------------

func espejar_hueso_seleccionado():
	if not esqueleto or hueso_actual_idx < 0:
		return
		
	var nombre_opuesto = DatosAnimacion.obtener_hueso_espejo(hueso_actual_nombre)
	if nombre_opuesto == hueso_actual_nombre:
		_mostrar_notificacion("Este hueso no tiene contraparte lateral.", true)
		return
		
	var idx_op = esqueleto.find_bone(nombre_opuesto)
	if idx_op < 0:
		_mostrar_notificacion("No se encontró el hueso opuesto: %s" % nombre_opuesto, true)
		return
		
	var rx = _get_spin_val(ruta_spin_rot_x)
	var ry = _get_spin_val(ruta_spin_rot_y)
	var rz = _get_spin_val(ruta_spin_rot_z)
	
	var euler_esp = DatosAnimacion.espejar_rotacion_euler(Vector3(rx, ry, rz))
	var q_esp = Quaternion.from_euler(Vector3(deg_to_rad(euler_esp.x), deg_to_rad(euler_esp.y), deg_to_rad(euler_esp.z)))
	
	esqueleto.set_bone_pose_rotation(idx_op, q_esp)
	_mostrar_notificacion("Espejado a: %s" % nombre_opuesto)

func espejar_toda_la_pose():
	if not esqueleto:
		return
	var pose_actual = DatosAnimacion.capturar_pose_esqueleto(esqueleto, _nombre_hueso_raiz)
	var pose_esp = DatosAnimacion.espejar_pose(pose_actual)
	DatosAnimacion.aplicar_pose_a_esqueleto(esqueleto, pose_esp, _nombre_hueso_raiz)
	_actualizar_ui_hueso_seleccionado()
	_mostrar_notificacion("Pose completa espejada (L <-> R).")

func copiar_pose():
	if not esqueleto:
		return
	buffer_pose_copiada = DatosAnimacion.capturar_pose_esqueleto(esqueleto, _nombre_hueso_raiz)
	_mostrar_notificacion("Pose copiada al portapapeles.")

func pegar_pose():
	if not esqueleto or buffer_pose_copiada.is_empty():
		_mostrar_notificacion("No hay ninguna pose copiada.", true)
		return
	DatosAnimacion.aplicar_pose_a_esqueleto(esqueleto, buffer_pose_copiada, _nombre_hueso_raiz)
	_actualizar_ui_hueso_seleccionado()
	_mostrar_notificacion("Pose pegada.")

func aplicar_preset(nombre_preset: String):
	if not esqueleto:
		return
	var presets = DatosAnimacion.obtener_poses_predefinidas()
	if not presets.has(nombre_preset):
		_mostrar_notificacion("Preset no disponible: %s" % nombre_preset, true)
		return
	var pose = presets[nombre_preset]
	DatosAnimacion.aplicar_pose_a_esqueleto(esqueleto, pose, _nombre_hueso_raiz)
	_actualizar_ui_hueso_seleccionado()
	_mostrar_notificacion("Preset aplicado: %s" % nombre_preset)

# ---------------------------------------------------------------------------
# LÍNEA DE TIEMPO Y KEYFRAMING
# ---------------------------------------------------------------------------

func _process(delta: float):
	if reproduciendo:
		tiempo_actual += delta * velocidad_reproduccion
		if tiempo_actual >= duracion_total:
			if loop_activo:
				tiempo_actual = fmod(tiempo_actual, duracion_total)
			else:
				tiempo_actual = duracion_total
				pausar()
				
		_actualizar_tiempo_ui()
		_aplicar_pose_interpolada_en_tiempo(tiempo_actual)

func _aplicar_pose_interpolada_en_tiempo(t: float):
	if not esqueleto or keyframes.is_empty():
		return
	var pose = DatosAnimacion.obtener_pose_en_tiempo(keyframes, t, duracion_total, loop_activo)
	DatosAnimacion.aplicar_pose_a_esqueleto(esqueleto, pose, _nombre_hueso_raiz)
	_actualizar_ui_hueso_seleccionado()

func capturar_keyframe_actual():
	if not esqueleto:
		return
	var pose = DatosAnimacion.capturar_pose_esqueleto(esqueleto, _nombre_hueso_raiz)
	
	# Verificar si ya existe un keyframe en tiempo_actual cercano (+/- 0.03s)
	var indice_reemplazo = -1
	for i in range(keyframes.size()):
		if absf(keyframes[i]["tiempo"] - tiempo_actual) < 0.03:
			indice_reemplazo = i
			break
			
	if indice_reemplazo >= 0:
		keyframes[indice_reemplazo]["pose"] = pose
		keyframes[indice_reemplazo]["tiempo"] = tiempo_actual
		_mostrar_notificacion("Keyframe actualizado en %.2fs." % tiempo_actual)
	else:
		keyframes.append({
			"tiempo": tiempo_actual,
			"pose": pose
		})
		keyframes.sort_custom(func(a, b): return a["tiempo"] < b["tiempo"])
		_mostrar_notificacion("Keyframe insertado en %.2fs." % tiempo_actual)
		
	_actualizar_marcas_keyframes()

func eliminar_keyframe_actual():
	if keyframes.is_empty():
		return
		
	var indice_borrar = -1
	var menor_dist = 0.05
	for i in range(keyframes.size()):
		var dist = absf(keyframes[i]["tiempo"] - tiempo_actual)
		if dist <= menor_dist:
			menor_dist = dist
			indice_borrar = i
			
	if indice_borrar >= 0:
		var t_borrado = keyframes[indice_borrar]["tiempo"]
		keyframes.remove_at(indice_borrar)
		_mostrar_notificacion("Keyframe en %.2fs eliminado." % t_borrado)
		_actualizar_marcas_keyframes()
	else:
		_mostrar_notificacion("No hay keyframe en el cabezal actual.", true)

func limpiar_todos_keyframes():
	keyframes.clear()
	capturar_keyframe_actual()
	_actualizar_marcas_keyframes()
	_mostrar_notificacion("Línea de tiempo limpiada.")

func toggle_play_pause():
	if reproduciendo:
		pausar()
	else:
		reproducir()

func reproducir():
	reproduciendo = true
	var btn = get_node_or_null(ruta_boton_play_pause) as Button
	if btn:
		btn.text = "⏸ PAUSA"

func pausar():
	reproduciendo = false
	var btn = get_node_or_null(ruta_boton_play_pause) as Button
	if btn:
		btn.text = "▶ PLAY"

func cambiar_tiempo(nuevo_tiempo: float):
	tiempo_actual = clampf(nuevo_tiempo, 0.0, duracion_total)
	_actualizar_tiempo_ui()
	_aplicar_pose_interpolada_en_tiempo(tiempo_actual)

func ir_al_inicio():
	cambiar_tiempo(0.0)

func ir_al_final():
	cambiar_tiempo(duracion_total)

func ir_al_keyframe_anterior():
	if keyframes.is_empty():
		return
	var anterior_t = 0.0
	for kf in keyframes:
		if kf["tiempo"] < tiempo_actual - 0.02:
			anterior_t = kf["tiempo"]
	cambiar_tiempo(anterior_t)

func ir_al_keyframe_siguiente():
	if keyframes.is_empty():
		return
	var siguiente_t = duracion_total
	for kf in keyframes:
		if kf["tiempo"] > tiempo_actual + 0.02:
			siguiente_t = kf["tiempo"]
			break
	cambiar_tiempo(siguiente_t)

func _actualizar_tiempo_ui():
	var slider_t = get_node_or_null(ruta_slider_tiempo) as Range
	if slider_t:
		slider_t.max_value = duracion_total
		slider_t.set_value_no_signal(tiempo_actual)
		
	var label_t = get_node_or_null(ruta_label_tiempo) as Label
	if label_t:
		var frame = int(round(tiempo_actual * 30.0))
		var total_frames = int(round(duracion_total * 30.0))
		label_t.text = "%.2fs / %.2fs  [F: %d/%d]" % [tiempo_actual, duracion_total, frame, total_frames]

func _actualizar_marcas_keyframes():
	var contenedor = get_node_or_null(ruta_contenedor_marcas_kf) as Control
	if not contenedor:
		return
		
	# Limpiar marcas anteriores
	for child in contenedor.get_children():
		child.queue_free()
		
	var ancho = contenedor.size.x
	if ancho <= 0.0:
		ancho = 600.0 # Valor por defecto seguro
		
	for kf in keyframes:
		var t = kf["tiempo"]
		var ratio = clampf(t / maxf(duracion_total, 0.001), 0.0, 1.0)
		var marca = ColorRect.new()
		marca.color = Color(0.95, 0.72, 0.22, 0.95) # Ámbar instrumento
		marca.custom_minimum_size = Vector2(4, 18)
		marca.size = Vector2(4, 18)
		marca.position = Vector2(ratio * ancho - 2, 0)
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor.add_child(marca)

# ---------------------------------------------------------------------------
# EXPORTACIÓN E INYECCIÓN DE ANIMACIÓN
# ---------------------------------------------------------------------------

func exportar_a_archivo():
	var edit_nombre = get_node_or_null(ruta_input_nombre_anim) as LineEdit
	var nombre = edit_nombre.text.strip_edges() if edit_nombre else "nueva_animacion"
	if nombre == "":
		nombre = "animacion_personalizada"
		
	var ruta_carpeta = "res://modelos3d/personajes/Jugador/animaciones/"
	var ruta_completa = ruta_carpeta + nombre + ".tres"
	
	var recurso_anim = DatosAnimacion.crear_recurso_animacion(nombre, keyframes, duracion_total, loop_activo, anim_player, esqueleto, _nombre_hueso_raiz)
	var err = DatosAnimacion.guardar_animacion_en_disco(recurso_anim, ruta_completa)
	
	if err == OK:
		_mostrar_notificacion("¡Guardado exitoso! -> %s" % ruta_completa)
	else:
		_mostrar_notificacion("Error al guardar: %d" % err, true)

func inyectar_en_animation_player_modelo():
	if not anim_player:
		_mostrar_notificacion("El modelo no tiene AnimationPlayer.", true)
		return
		
	var edit_nombre = get_node_or_null(ruta_input_nombre_anim) as LineEdit
	var nombre = edit_nombre.text.strip_edges() if edit_nombre else "anim_estudio"
	if nombre == "":
		nombre = "anim_estudio"
		
	var recurso_anim = DatosAnimacion.crear_recurso_animacion(nombre, keyframes, duracion_total, loop_activo, anim_player, esqueleto, _nombre_hueso_raiz)
	
	var lib = anim_player.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
		
	if lib.has_animation(nombre):
		lib.remove_animation(nombre)
	lib.add_animation(nombre, recurso_anim)
	
	_poblar_animaciones_existentes()
	_mostrar_notificacion("¡Animación '%s' inyectada en AnimationPlayer!" % nombre)

func importar_animacion_existente(nombre_anim: String):
	if not anim_player or not esqueleto:
		return
		
	var anim: Animation = null
	if anim_player.has_animation(nombre_anim):
		anim = anim_player.get_animation(nombre_anim)
	elif anim_player.has_animation_library(""):
		var lib = anim_player.get_animation_library("")
		if lib and lib.has_animation(nombre_anim):
			anim = lib.get_animation(nombre_anim)
			
	if not anim:
		_mostrar_notificacion("No se encontró la animación: %s" % nombre_anim, true)
		return
		
	# Muestrear poses a 30 FPS
	duracion_total = anim.length
	loop_activo = (anim.loop_mode != Animation.LOOP_NONE)
	
	var spin_dur = get_node_or_null(ruta_spin_duracion) as Range
	if spin_dur:
		spin_dur.value = duracion_total
		
	var check_l = get_node_or_null(ruta_check_loop) as CheckBox
	if check_l:
		check_l.button_pressed = loop_activo
		
	keyframes.clear()
	var fps = 30.0
	var total_pasos = max(1, int(round(duracion_total * fps)))
	
	# Guardar estado actual
	var pos_anterior = anim_player.current_animation_position
	var anim_anterior = anim_player.current_animation
	
	anim_player.play(nombre_anim)
	
	for step in range(total_pasos + 1):
		var t = clampf(float(step) / fps, 0.0, duracion_total)
		anim_player.seek(t, true)
		var pose_sample = DatosAnimacion.capturar_pose_esqueleto(esqueleto, _nombre_hueso_raiz)
		keyframes.append({
			"tiempo": t,
			"pose": pose_sample
		})
		
	anim_player.stop()
	if anim_anterior != "":
		anim_player.play(anim_anterior)
		anim_player.seek(pos_anterior, true)
		
	tiempo_actual = 0.0
	_actualizar_tiempo_ui()
	_actualizar_marcas_keyframes()
	_aplicar_pose_interpolada_en_tiempo(0.0)
	_mostrar_notificacion("Importada '%s' (%d keyframes extraídos)." % [nombre_anim, keyframes.size()])

# ---------------------------------------------------------------------------
# INTERFAZ Y EVENTOS
# ---------------------------------------------------------------------------

func _conectar_eventos_ui():
	# Sliders y spins de rotación
	_conectar_slider_spin(ruta_slider_rot_x, ruta_spin_rot_x, "x", true)
	_conectar_slider_spin(ruta_slider_rot_y, ruta_spin_rot_y, "y", true)
	_conectar_slider_spin(ruta_slider_rot_z, ruta_spin_rot_z, "z", true)
	
	# Sliders y spins de posición de raíz
	_conectar_slider_spin(ruta_slider_pos_x, ruta_spin_pos_x, "x", false)
	_conectar_slider_spin(ruta_slider_pos_y, ruta_spin_pos_y, "y", false)
	_conectar_slider_spin(ruta_slider_pos_z, ruta_spin_pos_z, "z", false)
	
	# Slider de tiempo
	var slider_t = get_node_or_null(ruta_slider_tiempo) as Range
	if slider_t:
		slider_t.value_changed.connect(func(v):
			if not reproduciendo:
				cambiar_tiempo(v)
		)
		
	# Duración total
	var spin_dur = get_node_or_null(ruta_spin_duracion) as Range
	if spin_dur:
		spin_dur.value_changed.connect(func(v):
			duracion_total = maxf(v, 0.1)
			_actualizar_tiempo_ui()
			_actualizar_marcas_keyframes()
		)
		
	# Loop CheckBox
	var check_l = get_node_or_null(ruta_check_loop) as CheckBox
	if check_l:
		check_l.toggled.connect(func(val): loop_activo = val)
		
	# Filtro de búsqueda de huesos
	var edit_filtro = get_node_or_null(ruta_filtro_huesos) as LineEdit
	if edit_filtro:
		edit_filtro.text_changed.connect(_filtrar_lista_huesos)

func _conectar_slider_spin(ruta_slider: NodePath, ruta_spin: NodePath, eje: String, es_rotacion: bool):
	var sl = get_node_or_null(ruta_slider) as Range
	var sp = get_node_or_null(ruta_spin) as Range
	
	if sl and sp:
		sl.value_changed.connect(func(v):
			if not _bloqueando_senales_ui:
				sp.set_value_no_signal(v)
				if es_rotacion:
					_aplicar_rotacion_desde_ui()
				else:
					_aplicar_posicion_desde_ui()
		)
		sp.value_changed.connect(func(v):
			if not _bloqueando_senales_ui:
				sl.set_value_no_signal(v)
				if es_rotacion:
					_aplicar_rotacion_desde_ui()
				else:
					_aplicar_posicion_desde_ui()
		)

func _sincronizar_slider_desde_spin(eje: String):
	var ruta_sl = ruta_slider_rot_x if eje == "x" else (ruta_slider_rot_y if eje == "y" else ruta_slider_rot_z)
	var ruta_sp = ruta_spin_rot_x if eje == "x" else (ruta_spin_rot_y if eje == "y" else ruta_spin_rot_z)
	var sl = get_node_or_null(ruta_sl) as Range
	var sp = get_node_or_null(ruta_sp) as Range
	if sl and sp:
		sl.set_value_no_signal(sp.value)

func _poblar_lista_todos_huesos():
	var lista = get_node_or_null(ruta_lista_todos_huesos) as ItemList
	if not lista or not esqueleto:
		return
		
	lista.clear()
	for i in range(esqueleto.get_bone_count()):
		var nombre = esqueleto.get_bone_name(i)
		lista.add_item("[%d] %s" % [i, nombre])
		
	if not lista.item_selected.is_connected(_on_item_lista_huesos_selected):
		lista.item_selected.connect(_on_item_lista_huesos_selected)

func _filtrar_lista_huesos(texto: String):
	var lista = get_node_or_null(ruta_lista_todos_huesos) as ItemList
	if not lista or not esqueleto:
		return
		
	lista.clear()
	var filtro = texto.strip_edges().to_lower()
	for i in range(esqueleto.get_bone_count()):
		var nombre = esqueleto.get_bone_name(i)
		if filtro == "" or nombre.to_lower().contains(filtro):
			var idx_item = lista.add_item("[%d] %s" % [i, nombre])
			lista.set_item_metadata(idx_item, i)

func _on_item_lista_huesos_selected(idx_item: int):
	var lista = get_node_or_null(ruta_lista_todos_huesos) as ItemList
	if not lista:
		return
	var metadata = lista.get_item_metadata(idx_item)
	var real_idx = metadata if metadata != null else idx_item
	seleccionar_hueso_por_indice(real_idx)

func _poblar_presets_en_ui():
	var contenedor = get_node_or_null(ruta_contenedor_presets) as Container
	if not contenedor:
		return
		
	for child in contenedor.get_children():
		child.queue_free()
		
	var presets = DatosAnimacion.obtener_poses_predefinidas()
	for p_name in presets.keys():
		var btn = Button.new()
		btn.text = p_name
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(func(): aplicar_preset(p_name))
		contenedor.add_child(btn)

func _poblar_animaciones_existentes():
	var menu = get_node_or_null(ruta_menu_anim_existentes) as OptionButton
	if not menu or not anim_player:
		return
		
	menu.clear()
	menu.add_item("-- Importar Animación Existente --")
	
	var anim_list = anim_player.get_animation_list()
	for a_name in anim_list:
		menu.add_item(a_name)
		
	if not menu.item_selected.is_connected(_on_anim_existente_seleccionada):
		menu.item_selected.connect(_on_anim_existente_seleccionada)

func _on_anim_existente_seleccionada(idx: int):
	var menu = get_node_or_null(ruta_menu_anim_existentes) as OptionButton
	if not menu or idx <= 0:
		return
	var anim_name = menu.get_item_text(idx)
	importar_animacion_existente(anim_name)

func enfocar_hueso_actual():
	if not camara_estudio or not esqueleto or hueso_actual_idx < 0:
		return
	var pos_global = esqueleto.global_transform * esqueleto.get_bone_global_pose(hueso_actual_idx).origin
	camara_estudio.enfocar_posicion(pos_global, 1.2)

func _mostrar_notificacion(mensaje: String, es_alerta: bool = false):
	print("[EstudioAnimacion] ", mensaje)
	var lbl = get_node_or_null(ruta_label_notificacion) as Label
	if lbl:
		lbl.text = mensaje
		lbl.modulate = Color(1.0, 0.45, 0.45, 1.0) if es_alerta else Color(0.95, 0.75, 0.25, 1.0)
		var tween = create_tween()
		tween.tween_property(lbl, "modulate:a", 1.0, 0.15)
		tween.tween_interval(2.2)
		tween.tween_property(lbl, "modulate:a", 0.0, 0.45)

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_play_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			enfocar_hueso_actual()
			get_viewport().set_input_as_handled()

func _on_btn_cargar_modelo_pressed():
	var edit = get_node_or_null(ruta_input_ruta_modelo) as LineEdit
	if edit:
		cargar_modelo(edit.text.strip_edges())

func _on_check_ver_huesos_toggled(toggled_on: bool):
	if visualizador_huesos:
		visualizador_huesos.mostrar_huesos = toggled_on

func _on_btn_reset_cam_pressed():
	if camara_estudio:
		camara_estudio.reset_camara()

func _on_btn_parte_pressed(parte: String):
	if selector_rig:
		selector_rig.seleccionar_parte(parte)

func _on_btn_rot_delta_pressed(eje: String, delta: float):
	rotar_hueso_delta(eje, delta)


