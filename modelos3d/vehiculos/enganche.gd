extends Node3D

static var _shader_indicador_compartido: Shader = null
static var _stream_clank: AudioStream = null
static var _stream_crash: AudioStream = null

signal enganche_conectado(camion: Node, remolque: Node)
signal enganche_desconectado(camion: Node, remolque: Node)

## true  → este Enganche está en el REMOLQUE (receptor, no inicia nada)
## false → este Enganche está en el CAMIÓN  (iniciador de la conexión)
@export var es_remolque: bool = false

## false → conexión automática por choque/contacto (por defecto)
## true  → requiere presionar botón manual
@export var modo_manual: bool = false

var area:   Area3D              = null
var joint:  Joint3D  = null
var marker: Marker3D            = null

var enganche_remoto: Node       = null
var conectado:       bool       = false
var _recien_conectado: bool     = false
@export var debug_enganche: bool = false

var _enganche_candidato: Node = null
var _tiempo_ultimo_aviso_patas: float = 0.0

var audio_player: AudioStreamPlayer3D = null
var audio_player_crash: AudioStreamPlayer3D = null

@export_group("Dimensiones de Detección")
@export var area_extents: Vector3 = Vector3(1.2, 0.7, 1.2)
@export var area_offset: Vector3 = Vector3(0.0, 0.01, 0.0)

@export_group("Realismo del Enganche")
@export var limite_velocidad_acople: float = 4.0
@export var fuerza_impacto_suspension: float = 0.08
@export var duracion_alineacion: float = 0.25

@export_group("Visualización X-Ray de Enganche")
## MeshInstance3D para resaltar (Quinta Rueda en camión o Kingpin/Enganche en remolque).
## Si no se asigna, se busca automáticamente ("Quinta_rueda", "Kingpin", etc.) o se genera uno representativo.
@export var mesh_enganche: MeshInstance3D = null
## Tiempo en segundos que los meshes permanecen en verde tras acoplarse antes de desvanecerse suavemente.
@export var duracion_verde_acople: float = 2.5
## Distancia máxima a la que se activa el parpadeo de aproximación en rojo.
@export var distancia_max_deteccion: float = 6.0

var _mesh_overlay: MeshInstance3D = null
var _mat_overlay: StandardMaterial3D = null
var _tween_overlay: Tween = null
var _estado_visual: String = "inactivo" # "inactivo" | "acercando" | "verde_conectado"

# ─── Botón táctil ───
var _btn_canvas: CanvasLayer = null
var _ultimo_estado_boton: String = "" # "" | "enganchar"
var _patas_canvas: CanvasLayer = null
var _ultimo_estado_patas_botones: bool = false

# ─── Botón 3D de Desenganche en la Quinta Rueda ───
var _sprite_desenganche: Sprite3D = null
var _label_desenganche: Label3D = null
var _sprite_desenganche_visible: bool = false
var _tween_sprite_desenganche: Tween = null
var _pos_base_sprite_desenganche: Vector3 = Vector3.ZERO
var _canvas_desenganche: CanvasLayer = null
var _btn_pantalla_desenganche: Button = null
var _ultimo_tiempo_desenganche_ms: int = 0

# ─── Control de Desenganche y Prevención de Re-enganche Inmediato ───
var _tiempo_desenganche_bloqueo: float = 0.0
var _remolque_desenganchado_reciente: Node = null
var _separado_tras_desenganche: bool = true
var _excepcion_aprox_cuerpo: PhysicsBody3D = null


func _ready() -> void:
	scale = Vector3.ONE

	area = get_node_or_null("Area3D")
	if not area:
		area = Area3D.new()
		area.name = "Area3D"
		add_child(area)

		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box = BoxShape3D.new()
		box.size = area_extents
		collision_shape.shape = box
		collision_shape.position = area_offset
		area.add_child(collision_shape)

	joint = get_node_or_null("PinJoint3D")
	if not joint:
		joint = get_node_or_null("QuintaRuedaJoint")

	marker = get_node_or_null("Marker3D")
	if not marker:
		marker = Marker3D.new()
		marker.name = "Marker3D"
		add_child(marker)

	if not _stream_clank:
		_stream_clank = load("res://recursos/sonidos_vehiculo/sonidos_metalicos/clank.mp3")
	if not _stream_crash:
		_stream_crash = load("res://recursos/sonidos_vehiculo/sonidos_metalicos/car_crash.mp3")

	audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = _stream_clank
	audio_player.unit_size = 12.0
	audio_player.max_distance = 80.0
	audio_player.bus = &"Master"
	add_child(audio_player)

	audio_player_crash = AudioStreamPlayer3D.new()
	audio_player_crash.stream = _stream_crash
	audio_player_crash.unit_size = 15.0
	audio_player_crash.max_distance = 100.0
	audio_player_crash.bus = &"Master"
	add_child(audio_player_crash)

	area.monitoring  = true
	area.monitorable = true
	if es_remolque:
		area.collision_layer = 8
		area.collision_mask  = 0
		area.monitoring      = false
		area.monitorable     = true
		add_to_group("enganche_remolque")
	else:
		area.collision_layer = 0
		area.collision_mask  = 8
		area.monitoring      = true
		area.monitorable     = false
		add_to_group("enganche_camion")
	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)

	if not es_remolque:
		call_deferred("_crear_boton_sprite_desenganche")

	call_deferred("_preparar_overlay_resaltado")


func _exit_tree() -> void:
	_destruir_boton()
	_destruir_botones_patas()
	_destruir_sprite_desenganche()
	_destruir_overlay_resaltado()
	if is_instance_valid(_indicador):
		_indicador.queue_free()
	_indicador = null


func _on_area_entered(otra_area: Area3D) -> void:
	if conectado or es_remolque:
		return

	var otro = otra_area.get_parent()
	if not otro or otro.get("es_remolque") != true:
		return

	var ahora := Time.get_ticks_msec() / 1000.0
	var cuerpo_remolque_potencial := _buscar_cuerpo(otro)
	if not _separado_tras_desenganche and is_instance_valid(_remolque_desenganchado_reciente) and cuerpo_remolque_potencial == _remolque_desenganchado_reciente:
		return
	if ahora < _tiempo_desenganche_bloqueo:
		return

	var cuerpo_propio := _buscar_cuerpo(self)
	if cuerpo_propio and cuerpo_remolque_potencial:
		var vel_relativa = (cuerpo_propio.linear_velocity - cuerpo_remolque_potencial.linear_velocity).length()
		if vel_relativa > limite_velocidad_acople:
			if audio_player_crash:
				audio_player_crash.pitch_scale = randf_range(0.9, 1.1)
				audio_player_crash.play()
			if debug_enganche:
				print("Enganche fallido: Demasiado rápido (", vel_relativa, " m/s)")
			return

	_enganche_candidato = otro
	if modo_manual:
		_actualizar_boton()


func _on_area_exited(otra_area: Area3D) -> void:
	var otro = otra_area.get_parent()
	if otro == _enganche_candidato:
		_enganche_candidato = null
		_actualizar_boton()


func _conectar_a(otro_enganche: Node, es_restauracion: bool = false) -> void:
	var cuerpo_propio   := _buscar_cuerpo(self)
	var cuerpo_remolque := _buscar_cuerpo(otro_enganche)

	if not cuerpo_propio or not cuerpo_remolque:
		push_warning("Enganche: no se encontró RigidBody3D en uno de los lados")
		return

	conectado         = true
	_recien_conectado = true
	enganche_remoto   = otro_enganche
	_enganche_candidato = null
	_separado_tras_desenganche = true
	_remolque_desenganchado_reciente = null
	_tiempo_desenganche_bloqueo = 0.0
	if "conectado" in otro_enganche:
		otro_enganche.conectado = true
	if "enganche_remoto" in otro_enganche:
		otro_enganche.enganche_remoto = self

	cuerpo_propio.add_collision_exception_with(cuerpo_remolque)
	# Seguridad anti-separación: si por reconexión o carga de partida hay distancia entre el remolque y la quinta rueda,
	# alineamos suavemente el kingpin al marker del camión antes de activar el joint para evitar explosiones de físicas.
	var pos_marker = marker.global_position if marker else global_position
	var pos_kingpin = otro_enganche.global_position
	if pos_marker.distance_to(pos_kingpin) > 0.20:
		var delta_pos = pos_marker - pos_kingpin
		cuerpo_remolque.global_position += delta_pos
		cuerpo_remolque.linear_velocity = Vector3.ZERO
		cuerpo_remolque.angular_velocity = Vector3.ZERO

	# El joint físico de quinta rueda vincula ambos cuerpos exactamente en el punto de contacto.
	_activar_joint(cuerpo_propio, cuerpo_remolque)

	if not es_restauracion:
		_ejecutar_efecto_verde_conectado()
		if otro_enganche.has_method("_ejecutar_efecto_verde_conectado"):
			otro_enganche.call("_ejecutar_efecto_verde_conectado")
		elif otro_enganche.has_method("_ejecutar_efecto_enganche"):
			otro_enganche.call("_ejecutar_efecto_enganche")

		var pos_local_camion = cuerpo_propio.to_local(marker.global_position)
		var masa_impacto = cuerpo_remolque.mass * fuerza_impacto_suspension
		cuerpo_propio.apply_impulse(Vector3.DOWN * masa_impacto, pos_local_camion)

		if audio_player:
			audio_player.pitch_scale = randf_range(0.95, 1.05)
			audio_player.play()

		if has_node("/root/NotificationManager"):
			get_node("/root/NotificationManager").notificar_exito("¡Tráiler enganchado! Debes bajarte y subir las patas para arrancar.")

	get_tree().create_timer(0.5).timeout.connect(func(): _recien_conectado = false, CONNECT_ONE_SHOT)

	if cuerpo_remolque.has_method("enganchado_a"):
		cuerpo_remolque.enganchado_a(cuerpo_propio)

	if debug_enganche:
		print("Enganchado: ", cuerpo_propio.name, " <-> ", cuerpo_remolque.name)
	enganche_conectado.emit(cuerpo_propio, cuerpo_remolque)
	if not es_restauracion:
		_guardar_persistencia()
	_actualizar_boton()


func _activar_joint(cuerpo_a: PhysicsBody3D, cuerpo_b: PhysicsBody3D) -> void:
	if not conectado:
		return

	if is_instance_valid(joint):
		joint.queue_free()

	var j6 = Generic6DOFJoint3D.new()
	j6.name = "QuintaRuedaJoint"
	add_child(j6)
	j6.global_position = marker.global_position
	j6.global_transform.basis = marker.global_transform.basis.orthonormalized()

	j6.node_a = cuerpo_a.get_path()
	j6.node_b = cuerpo_b.get_path()

	# Bloqueo total de movimiento lineal en X, Y, Z
	for axis in ["x", "y", "z"]:
		j6.set("linear_limit_%s/enabled" % axis, true)
		j6.set("linear_limit_%s/upper_distance" % axis, 0.0)
		j6.set("linear_limit_%s/lower_distance" % axis, 0.0)
		j6.set("linear_spring_%s/enabled" % axis, false)

	# Grados de libertad angulares:
	# Pitch (eje X): Permite inclinación en pendientes (+-22 grados)
	j6.set("angular_limit_x/enabled", true)
	j6.set("angular_limit_x/lower_angle", deg_to_rad(-22.0))
	j6.set("angular_limit_x/upper_angle", deg_to_rad(22.0))
	j6.set("angular_limit_x/softness", 0.5)

	# Yaw (eje Y): Tope realista de quinta rueda (+-78 grados) para que el tráiler no traspase la cabina
	j6.set("angular_limit_y/enabled", true)
	j6.set("angular_limit_y/lower_angle", deg_to_rad(-78.0))
	j6.set("angular_limit_y/upper_angle", deg_to_rad(78.0))
	j6.set("angular_limit_y/softness", 0.5)

	# Roll (eje Z): Permitir balanceo y torsión lateral del remolque (+-7 grados) para que el chasis oscile con las irregularidades del camino
	j6.set("angular_limit_z/enabled", true)
	j6.set("angular_limit_z/lower_angle", deg_to_rad(-7.0))
	j6.set("angular_limit_z/upper_angle", deg_to_rad(7.0))
	j6.set("angular_limit_z/softness", 0.4)

	joint = j6


func soltar() -> void:
	if not conectado:
		return

	var cuerpo_propio   := _buscar_cuerpo(self)
	var cuerpo_remolque := _buscar_cuerpo(enganche_remoto) if enganche_remoto else null

	if is_instance_valid(joint):
		joint.queue_free()
		joint = null

	if cuerpo_propio and cuerpo_remolque:
		# Dejar excepción de colisión por 1.5s para que el camión pueda avanzar libremente sin enganches físicos
		var cp = cuerpo_propio
		var cr = cuerpo_remolque
		var tree = get_tree()
		if tree:
			tree.create_timer(1.5).timeout.connect(func():
				if is_instance_valid(cp) and is_instance_valid(cr):
					cp.remove_collision_exception_with(cr)
					cr.remove_collision_exception_with(cp)
			, CONNECT_ONE_SHOT)
		else:
			cp.remove_collision_exception_with(cr)
			cr.remove_collision_exception_with(cp)

		if cuerpo_remolque.has_method("desenganchado_de"):
			cuerpo_remolque.desenganchado_de(cuerpo_propio)
		elif cuerpo_remolque.has_method("activar_patas"):
			cuerpo_remolque.activar_patas()

		if audio_player:
			audio_player.pitch_scale = randf_range(0.85, 0.95)
			audio_player.play()

		if has_node("/root/NotificationManager"):
			get_node("/root/NotificationManager").notificar_exito("¡Tráiler desenganchado! Patas de apoyo aseguradas.")

		enganche_desconectado.emit(cuerpo_propio, cuerpo_remolque)

	if is_instance_valid(enganche_remoto):
		if "conectado" in enganche_remoto:
			enganche_remoto.conectado = false
		if "enganche_remoto" in enganche_remoto:
			enganche_remoto.enganche_remoto = null

	# Registrar remolque desenganchado reciente y bloqueo para no re-enganchar de inmediato
	_remolque_desenganchado_reciente = cuerpo_remolque
	_separado_tras_desenganche = false
	_tiempo_desenganche_bloqueo = (Time.get_ticks_msec() / 1000.0) + 6.0

	conectado         = false
	if is_instance_valid(enganche_remoto) and enganche_remoto.has_method("_detener_efecto_visual"):
		enganche_remoto.call("_detener_efecto_visual")
	enganche_remoto   = null
	_recien_conectado = false
	_detener_efecto_visual()
	if debug_enganche:
		print("Desenganchado")

	_guardar_persistencia()
	_mostrar_ocultar_sprite_desenganche(false)
	_actualizar_boton()


# ─── Persistencia ───

func _get_datos() -> Node:
	return get_node_or_null("/root/DatosUsuario")


func _guardar_persistencia() -> void:
	var datos = _get_datos()
	if not datos:
		return

	var ruta_origen = _get_mi_ruta_escena()
	var trailer_path = ""
	var trailer_body: Node = null
	if conectado and enganche_remoto:
		trailer_body = _buscar_cuerpo(enganche_remoto)
		if trailer_body:
			trailer_path = _get_ruta_escena(trailer_body)

	var remolques = datos.get("remolques_activos")
	if remolques == null or typeof(remolques) != TYPE_DICTIONARY:
		remolques = {}

	var truck_node = _buscar_cuerpo(self)
	var truck_name = truck_node.name if truck_node else ""

	if trailer_path != "":
		var t_ruedas = trailer_body.get("tipo_ruedas") if trailer_body else ""
		remolques[ruta_origen] = {
			"trailer_scene": trailer_path,
			"trailer_name": str(trailer_body.name),
			"truck_name": truck_name,
			"hitch_name": name,
			"tipo_ruedas": t_ruedas if t_ruedas != null else "",
			"trailer_pos": trailer_body.global_position,
			"trailer_rot_y": trailer_body.rotation.y,
		}
	else:
		if remolques.has(ruta_origen):
			remolques.erase(ruta_origen)

	datos.set("remolques_activos", remolques)
	datos.save_local()


func _get_mi_ruta_escena() -> String:
	var p = _buscar_cuerpo(self)
	if p:
		return _get_ruta_escena(p)
	return ""


func _get_ruta_escena(n: Node) -> String:
	var escena = n.scene_file_path
	if escena != "":
		return escena
	var inst = n.get_scene_instance_load_placeholder()
	if inst:
		return inst
	var owner_node = n.owner
	if owner_node and owner_node.scene_file_path != "":
		return owner_node.scene_file_path
	return ""


# ─── Información del Jugador (A pie vs Conduciendo) ───

func _obtener_info_jugador() -> Dictionary:
	var info = {
		"jugador": null,
		"a_pie": false,
		"distancia": 9999.0
	}
	var tree = get_tree()
	if not tree:
		return info

	var j = tree.get_first_node_in_group("jugador")
	if not is_instance_valid(j):
		j = tree.get_first_node_in_group("player")

	if not is_instance_valid(j) or not (j is Node3D):
		return info

	var conduciendo = false

	# 1. InputVehiculo Global
	var iv = get_node_or_null("/root/InputVehiculo")
	if iv and "conduciendo" in iv and iv.conduciendo:
		conduciendo = true

	# 2. GestorVehiculos Central
	if not conduciendo:
		var gv = get_node_or_null("/root/GestorVehiculos")
		if gv and gv.get("vehiculo_actual") != null:
			conduciendo = true

	# 3. Comprobar si el camión portador tiene al jugador montado
	if not conduciendo:
		var camion = _buscar_cuerpo(self)
		if camion and (camion.get("activo") == true or camion.get("jugador_ref") != null):
			conduciendo = true

	# 4. Variables de conducción en el nodo del jugador
	if not conduciendo:
		if j.get("_conduciendo") == true or j.get("esta_conduciendo") == true or j.get("conduciendo") == true:
			conduciendo = true

	# 5. Comprobar visibilidad del jugador (se oculta al subirse al vehículo)
	if not conduciendo and not (j as Node3D).is_visible_in_tree():
		conduciendo = true

	info["jugador"] = j
	info["a_pie"] = not conduciendo
	info["distancia"] = global_position.distance_to((j as Node3D).global_position)
	return info


# ─── Botón táctil Quinta Rueda ───

func _crear_boton(texto: String, color: Color, en_cabina: bool = false) -> void:
	_destruir_boton()

	_btn_canvas = CanvasLayer.new()
	_btn_canvas.name = "BtnEngancheCanvas"
	_btn_canvas.layer = 110
	add_child(_btn_canvas)

	var btn = Button.new()
	btn.name = "BtnEnganche"
	btn.text = texto
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if en_cabina:
		# Ubicación ergonómica en cabina (esquina superior derecha, accesible y sin estorbar controles)
		btn.custom_minimum_size = Vector2(250, 65)
		btn.anchor_left = 0.73
		btn.anchor_right = 0.97
		btn.anchor_top = 0.16
		btn.anchor_bottom = 0.24
		btn.pivot_offset = Vector2(125, 32)
	else:
		# Ubicación a pie (centro inferior)
		btn.custom_minimum_size = Vector2(360, 80)
		btn.anchor_left = 0.5
		btn.anchor_right = 0.5
		btn.anchor_top = 0.82
		btn.anchor_bottom = 0.82
		btn.pivot_offset = Vector2(180, 40)

	btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn.grow_vertical = Control.GROW_DIRECTION_BOTH

	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	if texto.begins_with("ENGANCHAR"):
		sb.border_color = Color(1.00, 0.45, 0.00, 0.90) # Naranja neón
	else:
		sb.border_color = Color(0.95, 0.25, 0.15, 0.90) # Rojo anaranjado para soltar
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover = sb.duplicate()
	sb_hover.bg_color = color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sb_hover)

	btn.add_theme_font_size_override("font_size", 20 if en_cabina else 26)

	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		btn.add_theme_font_override("font", load(font_path))

	if texto.begins_with("ENGANCHAR"):
		btn.pressed.connect(func():
			if is_instance_valid(_enganche_candidato):
				_conectar_a(_enganche_candidato)
		)
	else:
		btn.pressed.connect(func():
			soltar()
		)

	_btn_canvas.add_child(btn)

	btn.modulate.a = 0.0
	btn.scale = Vector2(0.85, 0.85)
	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(btn, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _destruir_boton() -> void:
	if is_instance_valid(_btn_canvas):
		_btn_canvas.queue_free()
	_btn_canvas = null
	_ultimo_estado_boton = ""


func _actualizar_boton(info_jugador: Dictionary = {}) -> void:
	if es_remolque:
		return

	if info_jugador.is_empty():
		info_jugador = _obtener_info_jugador()

	var a_pie: bool = info_jugador.get("a_pie", false)
	var dist_jugador: float = info_jugador.get("distancia", 9999.0)

	var nuevo_estado: String = ""

	if conectado:
		# El desenganche ahora se realiza exclusivamente mediante el botón interactivo Sprite3D en la quinta rueda
		nuevo_estado = ""
	elif modo_manual and is_instance_valid(_enganche_candidato):
		var dist_hitch = global_position.distance_to(_enganche_candidato.global_position)
		if dist_hitch <= 2.2 and a_pie and dist_jugador <= 2.5:
			nuevo_estado = "enganchar"

	if nuevo_estado == _ultimo_estado_boton:
		return
	_ultimo_estado_boton = nuevo_estado

	if nuevo_estado == "soltar_cabina":
		_crear_boton("DESENGANCHAR (T)", Color(0.14, 0.04, 0.04, 0.92), true)
	elif nuevo_estado == "soltar_pie":
		_crear_boton("DESENGANCHAR (E)", Color(0.14, 0.04, 0.04, 0.92), false)
	elif nuevo_estado == "enganchar":
		_crear_boton("ENGANCHAR (E)", Color(0.06, 0.06, 0.08, 0.90), false)
	else:
		_destruir_boton()


func _buscar_cuerpo(nodo: Node) -> PhysicsBody3D:
	var n := nodo
	while n != null:
		if n is PhysicsBody3D:
			return n as PhysicsBody3D
		n = n.get_parent()
	return null


# ─── Visualización X-Ray de Meshes (Quinta Rueda / Enganche) ───
var _indicador: Node3D = null # Compatibilidad hacia atrás si algún nodo externo lo consulta

func _obtener_o_crear_mesh_objetivo() -> MeshInstance3D:
	if is_instance_valid(mesh_enganche):
		return mesh_enganche

	# 1. Buscar si hay un MeshInstance3D hijo directo
	for child in get_children():
		if child is MeshInstance3D and child != _mesh_overlay and not child.name.begins_with("Overlay"):
			mesh_enganche = child
			return mesh_enganche

	# 2. Buscar en el padre y jerarquía de hermanos (por ejemplo en tractomulas con "Quinta_rueda")
	var p = get_parent()
	if is_instance_valid(p):
		var nombres_candidatos = [
			"Quinta_rueda", "QuintaRueda", "quinta_rueda", "quinta", "Quinta",
			"Perno", "Kingpin", "kingpin", "EngancheMesh", "enganche_mesh"
		]
		for nom in nombres_candidatos:
			var nodo = p.find_child(nom, true, false)
			if is_instance_valid(nodo) and nodo is MeshInstance3D:
				mesh_enganche = nodo
				return mesh_enganche

	# 3. Fallback: Si no existe un mesh modelado por separado (ej. trailers sin kingpin independiente),
	# creamos una geometría 3D limpia y representativa
	var mesh_fallback = MeshInstance3D.new()
	mesh_fallback.name = "MeshEngancheFallback"
	if es_remolque:
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.055
		cyl.bottom_radius = 0.055
		cyl.height = 0.28
		mesh_fallback.mesh = cyl
	else:
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.42
		cyl.height = 0.06
		mesh_fallback.mesh = cyl

	add_child(mesh_fallback)
	mesh_enganche = mesh_fallback
	return mesh_enganche


func _preparar_overlay_resaltado() -> void:
	if is_instance_valid(_mesh_overlay):
		return

	var target = _obtener_o_crear_mesh_objetivo()
	if not is_instance_valid(target) or not target.mesh:
		return

	_mat_overlay = StandardMaterial3D.new()
	_mat_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_mat_overlay.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_overlay.no_depth_test = true
	_mat_overlay.render_priority = 12
	_mat_overlay.albedo_color = Color(1.0, 0.06, 0.06, 0.0)

	_mesh_overlay = MeshInstance3D.new()
	_mesh_overlay.name = "OverlayResaltadoEnganche"
	_mesh_overlay.mesh = target.mesh
	_mesh_overlay.material_override = _mat_overlay
	_mesh_overlay.visible = false
	_mesh_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	target.add_child(_mesh_overlay)
	_mesh_overlay.transform = Transform3D.IDENTITY


func _actualizar_efecto_visual(estado: String, distancia: float = 999.0) -> void:
	_preparar_overlay_resaltado()
	if not is_instance_valid(_mesh_overlay) or not is_instance_valid(_mat_overlay):
		return

	if estado == "acercando":
		if _estado_visual == "verde_conectado":
			return # Dejar que el verde continúe su duración
		_estado_visual = "acercando"
		_mesh_overlay.visible = true

		# Parpadeo rojo cuya frecuencia aumenta al acercarse
		var factor_proximidad = clampf(1.0 - (distancia / maxf(distancia_max_deteccion, 0.1)), 0.0, 1.0)
		var freq = lerpf(2.0, 7.5, factor_proximidad)
		var t = Time.get_ticks_msec() / 1000.0
		var pulso = pow((sin(t * freq * TAU) + 1.0) * 0.5, 1.6)
		var alpha = lerpf(0.08, 0.92, pulso)
		_mat_overlay.albedo_color = Color(1.0, 0.06, 0.06, alpha)

	elif estado == "inactivo":
		if _estado_visual == "verde_conectado":
			return
		_estado_visual = "inactivo"
		_mesh_overlay.visible = false
		_mat_overlay.albedo_color.a = 0.0


func _ejecutar_efecto_verde_conectado() -> void:
	_preparar_overlay_resaltado()
	if not is_instance_valid(_mesh_overlay) or not is_instance_valid(_mat_overlay):
		return

	_estado_visual = "verde_conectado"
	_mesh_overlay.visible = true

	if _tween_overlay:
		_tween_overlay.kill()

	# Verde brillante neón
	_mat_overlay.albedo_color = Color(0.12, 1.0, 0.28, 0.95)

	_tween_overlay = create_tween()
	# 1. Permanecer en verde durante duracion_verde_acople segundos
	_tween_overlay.tween_interval(duracion_verde_acople)
	# 2. Desvanecimiento suave
	_tween_overlay.tween_property(_mat_overlay, "albedo_color:a", 0.0, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# 3. Ocultar el overlay
	_tween_overlay.tween_callback(func():
		_estado_visual = "inactivo"
		if is_instance_valid(_mesh_overlay):
			_mesh_overlay.visible = false
	)


func _detener_efecto_visual() -> void:
	if _estado_visual == "verde_conectado":
		return
	_estado_visual = "inactivo"
	if _tween_overlay:
		_tween_overlay.kill()
	if is_instance_valid(_mesh_overlay):
		_mesh_overlay.visible = false
	if is_instance_valid(_mat_overlay):
		_mat_overlay.albedo_color.a = 0.0


func _destruir_overlay_resaltado() -> void:
	if _tween_overlay:
		_tween_overlay.kill()
	_tween_overlay = null
	if is_instance_valid(_mesh_overlay):
		_mesh_overlay.queue_free()
	_mesh_overlay = null
	_mat_overlay = null


# ─── Stubs de compatibilidad hacia atrás ───
func _actualizar_aspecto_indicador(distancia: float, _delta: float) -> void:
	_actualizar_efecto_visual("acercando", distancia)

func _ejecutar_efecto_enganche() -> void:
	_ejecutar_efecto_verde_conectado()

func _set_indicador_visible(estado: bool) -> void:
	if estado:
		_actualizar_efecto_visual("acercando", 3.0)
	else:
		_detener_efecto_visual()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.is_echo():
		return

	if _sprite_desenganche_visible and is_instance_valid(_sprite_desenganche) and _sprite_desenganche.visible:
		if event.keycode == KEY_E or event.keycode == KEY_R or event.keycode == KEY_T or event.is_action_pressed("interactuar"):
			print("[Enganche] Tecla interactuar desenganche presionada: ", event.as_text())
			_interactuar_desenganche()
			get_viewport().set_input_as_handled()
			return

	if es_remolque:
		if _ultimo_estado_patas_botones:
			if event.keycode == KEY_PAGEUP or event.keycode == KEY_Q:
				_subir_patas_remolque()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_PAGEDOWN or event.keycode == KEY_Z:
				_bajar_patas_remolque()
				get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_E or event.keycode == KEY_R or event.keycode == KEY_T:
		if _ultimo_estado_boton == "enganchar" and is_instance_valid(_enganche_candidato):
			_conectar_a(_enganche_candidato)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_actualizar_posicion_pantalla_desenganche()

	var info_jugador = _obtener_info_jugador()
	var a_pie: bool = info_jugador.get("a_pie", false)
	var dist_jugador: float = info_jugador.get("distancia", 9999.0)

	if es_remolque:
		_actualizar_botones_patas(false)
		return

	# Lógica en el camión / tractomula:
	if conectado:
		if _estado_visual != "verde_conectado":
			_detener_efecto_visual()
		if is_instance_valid(enganche_remoto) and enganche_remoto.has_method("_detener_efecto_visual"):
			if enganche_remoto.get("_estado_visual") != "verde_conectado":
				enganche_remoto.call("_detener_efecto_visual")
		_actualizar_boton(info_jugador)
		_actualizar_presencia_desenganche(info_jugador)
		return

	# Si no está conectado, asegurar que el botón de desenganche esté oculto
	if _sprite_desenganche_visible:
		_mostrar_ocultar_sprite_desenganche(false)

	# Camión no conectado: buscar remolques cercanos
	var remolques = get_tree().get_nodes_in_group("enganche_remolque") if get_tree() else []
	var mas_cercano: Node3D = null
	var dist_min: float = 12.0

	for r in remolques:
		if is_instance_valid(r) and r is Node3D:
			var d = global_position.distance_to(r.global_position)
			if d < dist_min:
				dist_min = d
				mas_cercano = r

	if is_instance_valid(mas_cercano):
		var cuerpo_candidato = _buscar_cuerpo(mas_cercano)
		var ahora := Time.get_ticks_msec() / 1000.0

		# Comprobar si el camión ya se separó al menos 4 metros del remolque tras desenganchar
		if not _separado_tras_desenganche:
			if is_instance_valid(_remolque_desenganchado_reciente) and cuerpo_candidato == _remolque_desenganchado_reciente:
				if dist_min >= 4.0:
					_separado_tras_desenganche = true
					_remolque_desenganchado_reciente = null
			else:
				_separado_tras_desenganche = true

		var puede_enganchar := _separado_tras_desenganche and (ahora >= _tiempo_desenganche_bloqueo)

		# Visualización X-Ray de los meshes al hacer reversa (parpadeo rojo mientras se van juntando)
		if dist_min <= distancia_max_deteccion and puede_enganchar:
			_actualizar_efecto_visual("acercando", dist_min)
			if mas_cercano.has_method("_actualizar_efecto_visual"):
				mas_cercano.call("_actualizar_efecto_visual", "acercando", dist_min)
		else:
			_detener_efecto_visual()
			if mas_cercano.has_method("_detener_efecto_visual"):
				mas_cercano.call("_detener_efecto_visual")

		# Alineación física precisa entre el enganche del camión y el kingpin del trailer
		var pos_camion: Vector3 = marker.global_position if is_instance_valid(marker) else global_position
		var pos_remolque: Vector3 = mas_cercano.global_position
		var diff_hitch: Vector3 = pos_camion - pos_remolque
		var dist_xz: float = Vector2(diff_hitch.x, diff_hitch.z).length()
		var dist_y: float = absf(diff_hitch.y)

		# Solo se acoplan cuando el vehículo realmente hace contacto físico con el kingpin
		# (ambos están juntos correctamente, sin teletransporte ni tirones)
		if dist_xz <= 0.35 and dist_y <= 0.45:
			_enganche_candidato = mas_cercano
			if not modo_manual and not conectado and not es_remolque and puede_enganchar:
				_conectar_a(mas_cercano)
		elif dist_min <= 2.2:
			_enganche_candidato = mas_cercano
		else:
			if _enganche_candidato == mas_cercano:
				_enganche_candidato = null
	else:
		_detener_efecto_visual()
		for r in remolques:
			if is_instance_valid(r) and r.has_method("_detener_efecto_visual"):
				r.call("_detener_efecto_visual")
		_enganche_candidato = null

	_actualizar_boton(info_jugador)


func _physics_process(delta: float) -> void:
	if not conectado and not es_remolque:
		var cuerpo_propio := _buscar_cuerpo(self)
		if cuerpo_propio:
			var mejor_cuerpo: PhysicsBody3D = null
			var mejor_dist: float = 4.5
			for n_rem in get_tree().get_nodes_in_group("enganche_remolque"):
				if not is_instance_valid(n_rem) or not (n_rem is Node3D):
					continue
				var d := global_position.distance_to((n_rem as Node3D).global_position)
				if d < mejor_dist:
					var cr := _buscar_cuerpo(n_rem)
					if cr:
						mejor_dist = d
						mejor_cuerpo = cr
			if mejor_cuerpo != _excepcion_aprox_cuerpo:
				if is_instance_valid(_excepcion_aprox_cuerpo):
					cuerpo_propio.remove_collision_exception_with(_excepcion_aprox_cuerpo)
					_excepcion_aprox_cuerpo.remove_collision_exception_with(cuerpo_propio)
				_excepcion_aprox_cuerpo = mejor_cuerpo
				if is_instance_valid(_excepcion_aprox_cuerpo):
					cuerpo_propio.add_collision_exception_with(_excepcion_aprox_cuerpo)
					_excepcion_aprox_cuerpo.add_collision_exception_with(cuerpo_propio)

	if conectado and not es_remolque:
		var cuerpo_propio := _buscar_cuerpo(self)
		var cuerpo_remolque := _buscar_cuerpo(enganche_remoto) if is_instance_valid(enganche_remoto) else null
		if cuerpo_propio and cuerpo_remolque:
			if cuerpo_remolque.has_method("tiene_patas_abajo") and cuerpo_remolque.tiene_patas_abajo():
				# Si las patas del tráiler están apoyadas en el suelo, el camión no arranca y permanece frenado
				cuerpo_propio.linear_velocity = cuerpo_propio.linear_velocity.move_toward(Vector3.ZERO, delta * 40.0)
				cuerpo_propio.angular_velocity = cuerpo_propio.angular_velocity.move_toward(Vector3.ZERO, delta * 40.0)

				# Avisar al conductor si está en cabina intentando arrancar
				var info = _obtener_info_jugador()
				var a_pie: bool = info.get("a_pie", false)
				if not a_pie:
					var ahora = Time.get_ticks_msec() / 1000.0
					if ahora - _tiempo_ultimo_aviso_patas > 3.0:
						_tiempo_ultimo_aviso_patas = ahora
						if has_node("/root/NotificationManager"):
							get_node("/root/NotificationManager").notificar_error("¡El camión no puede arrancar! Bájate a subir las patas del tráiler.")


# ─── Control de Patas del Remolque (▲ / ▼) ───

func _actualizar_botones_patas(mostrar: bool) -> void:
	if mostrar == _ultimo_estado_patas_botones:
		return
	_ultimo_estado_patas_botones = mostrar
	
	if mostrar:
		_crear_botones_patas()
	else:
		_destruir_botones_patas()


func _crear_botones_patas() -> void:
	_destruir_botones_patas()
	
	_patas_canvas = CanvasLayer.new()
	_patas_canvas.name = "PatasControlCanvas"
	_patas_canvas.layer = 110
	add_child(_patas_canvas)
	
	var panel = VBoxContainer.new()
	panel.name = "PanelPatas"
	panel.custom_minimum_size = Vector2(300, 110)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Ubicación táctil ergonómica al Centro Inferior (completamente libre de joystick y controles)
	panel.anchor_left = 0.36
	panel.anchor_right = 0.64
	panel.anchor_top = 0.78
	panel.anchor_bottom = 0.93
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_patas_canvas.add_child(panel)

	# Etiqueta de título
	var lbl = Label.new()
	lbl.text = "PATAS DE APOYO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0, 0.9))
	var font_path = "res://recursos/fonts/Moderniz.otf"
	var custom_font = load(font_path) if ResourceLoader.exists(font_path) else null
	if custom_font:
		lbl.add_theme_font_override("font", custom_font)
	panel.add_child(lbl)

	var contenedor = HBoxContainer.new()
	contenedor.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(contenedor)
	
	# Estilo Glassmorphism con bordes naranja neón según la guía de diseño
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.90) # Fondo oscuro traslúcido
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.00, 0.45, 0.00, 0.80) # Naranja neón
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	
	# Botón SUBIR PATAS (▲)
	var btn_subir = Button.new()
	btn_subir.name = "BtnSubirPatas"
	btn_subir.text = "▲ SUBIR"
	btn_subir.custom_minimum_size = Vector2(130, 70)
	btn_subir.add_theme_stylebox_override("normal", sb)
	btn_subir.add_theme_stylebox_override("hover", sb_hover)
	btn_subir.add_theme_font_size_override("font_size", 22)
	if custom_font:
		btn_subir.add_theme_font_override("font", custom_font)
	btn_subir.pressed.connect(func(): _subir_patas_remolque())
	contenedor.add_child(btn_subir)
	
	# Espaciador
	var espaciador = Control.new()
	espaciador.custom_minimum_size = Vector2(15, 0)
	contenedor.add_child(espaciador)
	
	# Botón BAJAR PATAS (▼)
	var btn_bajar = Button.new()
	btn_bajar.name = "BtnBajarPatas"
	btn_bajar.text = "▼ BAJAR"
	btn_bajar.custom_minimum_size = Vector2(130, 70)
	btn_bajar.add_theme_stylebox_override("normal", sb)
	btn_bajar.add_theme_stylebox_override("hover", sb_hover)
	btn_bajar.add_theme_font_size_override("font_size", 22)
	if custom_font:
		btn_bajar.add_theme_font_override("font", custom_font)
	btn_bajar.pressed.connect(func(): _bajar_patas_remolque())
	contenedor.add_child(btn_bajar)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = Vector2(150, 55)
	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _destruir_botones_patas() -> void:
	if is_instance_valid(_patas_canvas):
		_patas_canvas.queue_free()
	_patas_canvas = null


func _subir_patas_remolque() -> void:
	var cuerpo_remolque = _buscar_cuerpo(self)
	if cuerpo_remolque:
		if cuerpo_remolque.has_method("_subir_patas"):
			cuerpo_remolque.call("_subir_patas")
		if cuerpo_remolque.has_method("desactivar_patas"):
			cuerpo_remolque.call("desactivar_patas")


func _bajar_patas_remolque() -> void:
	var cuerpo_remolque = _buscar_cuerpo(self)
	if cuerpo_remolque:
		if cuerpo_remolque.has_method("_bajar_patas"):
			cuerpo_remolque.call("_bajar_patas")
		if cuerpo_remolque.has_method("activar_patas"):
			cuerpo_remolque.call("activar_patas")


# ═══════════════════════════════════════════════════════════════════════
# BOTÓN INTERACTIVO SPRITE3D DE DESENGANCHE (QUINTA RUEDA)
# ═══════════════════════════════════════════════════════════════════════

func _crear_boton_sprite_desenganche() -> void:
	if es_remolque:
		return
	if is_instance_valid(_sprite_desenganche):
		return

	var ruta_icono = "res://recursos/botones/desenganchar.svg"
	var tex: Texture2D = null
	if ResourceLoader.exists(ruta_icono):
		tex = load(ruta_icono) as Texture2D
	if not tex:
		var fallback = "res://recursos/botones/flecha.svg"
		if ResourceLoader.exists(fallback):
			tex = load(fallback) as Texture2D
	if not tex:
		return

	_sprite_desenganche = Sprite3D.new()
	_sprite_desenganche.name = "BotonDesengancheSprite3D"
	_sprite_desenganche.texture = tex
	_sprite_desenganche.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite_desenganche.pixel_size = 0.0016
	_sprite_desenganche.shaded = false
	_sprite_desenganche.no_depth_test = true
	_sprite_desenganche.render_priority = 6
	_sprite_desenganche.visible = false
	_sprite_desenganche.modulate = Color(1.0, 0.40, 0.15, 0.0)

	var local_marker = marker.position if is_instance_valid(marker) else Vector3.ZERO
	_pos_base_sprite_desenganche = local_marker + Vector3(0.0, 0.95, 0.0)
	_sprite_desenganche.position = _pos_base_sprite_desenganche
	add_child(_sprite_desenganche)

	# Etiqueta de texto indicador estilizado con fuente Moderniz
	_label_desenganche = Label3D.new()
	_label_desenganche.name = "TextoDesenganche"
	_label_desenganche.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_desenganche.pixel_size = 0.0028
	_label_desenganche.no_depth_test = true
	_label_desenganche.render_priority = 7
	_label_desenganche.position = Vector3(0.0, 0.48, 0.0)
	_label_desenganche.font_size = 28
	_label_desenganche.outline_size = 8
	_label_desenganche.modulate = Color(1.0, 0.40, 0.15)
	_label_desenganche.outline_modulate = Color(0.06, 0.06, 0.08, 0.95)
	var font_path = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		_label_desenganche.font = load(font_path)
	_label_desenganche.text = "DESENGANCHAR"
	_sprite_desenganche.add_child(_label_desenganche)

	_crear_ui_tactil_desenganche()


func _crear_ui_tactil_desenganche() -> void:
	if is_instance_valid(_canvas_desenganche):
		_canvas_desenganche.queue_free()

	_canvas_desenganche = CanvasLayer.new()
	_canvas_desenganche.name = "CanvasDesenganche"
	_canvas_desenganche.layer = 125
	add_child(_canvas_desenganche)

	# Botón táctil transparente que rastrea la posición en pantalla del Sprite3D
	_btn_pantalla_desenganche = Button.new()
	_btn_pantalla_desenganche.name = "BtnPantallaDesenganche"
	_btn_pantalla_desenganche.custom_minimum_size = Vector2(160, 160)
	_btn_pantalla_desenganche.size = Vector2(160, 160)
	_btn_pantalla_desenganche.flat = true
	_btn_pantalla_desenganche.focus_mode = Control.FOCUS_NONE
	_btn_pantalla_desenganche.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_pantalla_desenganche.visible = false
	_btn_pantalla_desenganche.pressed.connect(_interactuar_desenganche)
	_canvas_desenganche.add_child(_btn_pantalla_desenganche)


func _interactuar_desenganche() -> void:
	var ahora_ms: int = Time.get_ticks_msec()
	if ahora_ms - _ultimo_tiempo_desenganche_ms < 600:
		return
	_ultimo_tiempo_desenganche_ms = ahora_ms

	print("[Enganche] _interactuar_desenganche() ejecutado")

	if is_instance_valid(_sprite_desenganche):
		var tw_punch = create_tween()
		tw_punch.tween_property(_sprite_desenganche, "scale", Vector3.ONE * 0.45, 0.08).set_ease(Tween.EASE_OUT)
		tw_punch.tween_property(_sprite_desenganche, "scale", Vector3.ONE * 0.70, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	soltar()


func _mostrar_ocultar_sprite_desenganche(mostrar: bool) -> void:
	if mostrar == _sprite_desenganche_visible:
		return
	_sprite_desenganche_visible = mostrar
	if _tween_sprite_desenganche:
		_tween_sprite_desenganche.kill()
	_tween_sprite_desenganche = create_tween().set_parallel(true)

	if mostrar:
		if is_instance_valid(_sprite_desenganche):
			_sprite_desenganche.visible = true
			_sprite_desenganche.scale = Vector3.ZERO
			_sprite_desenganche.modulate.a = 0.0
			_tween_sprite_desenganche.tween_property(_sprite_desenganche, "scale", Vector3.ONE * 0.70, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween_sprite_desenganche.tween_property(_sprite_desenganche, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	else:
		if is_instance_valid(_sprite_desenganche):
			_tween_sprite_desenganche.tween_property(_sprite_desenganche, "scale", Vector3.ZERO, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			_tween_sprite_desenganche.tween_property(_sprite_desenganche, "modulate:a", 0.0, 0.18)

		_tween_sprite_desenganche.chain().tween_callback(func():
			if is_instance_valid(_sprite_desenganche) and not _sprite_desenganche_visible:
				_sprite_desenganche.visible = false
			if is_instance_valid(_btn_pantalla_desenganche) and not _sprite_desenganche_visible:
				_btn_pantalla_desenganche.visible = false
		)


func _actualizar_presencia_desenganche(info_jugador: Dictionary) -> void:
	if es_remolque:
		return

	if not is_instance_valid(_sprite_desenganche):
		_crear_boton_sprite_desenganche()

	var mostrar := false

	if conectado:
		var cuerpo_remolque := _buscar_cuerpo(enganche_remoto) if is_instance_valid(enganche_remoto) else null
		if cuerpo_remolque:
			var patas_abajo := false
			if cuerpo_remolque.has_method("tiene_patas_abajo"):
				patas_abajo = cuerpo_remolque.tiene_patas_abajo()
			elif "patas_abajo" in cuerpo_remolque:
				patas_abajo = cuerpo_remolque.patas_abajo

			# REQUISITO FUNDAMENTAL:
			# El botón de desenganchar en el enganche SOLO sale si las patas están abajo
			if patas_abajo:
				var a_pie: bool = info_jugador.get("a_pie", false)
				if a_pie:
					var pos_hitch := marker.global_position if is_instance_valid(marker) else global_position
					var j = info_jugador.get("jugador")
					if is_instance_valid(j) and (j is Node3D):
						var d: float = pos_hitch.distance_to((j as Node3D).global_position)
						mostrar = (d <= 4.5)

	if mostrar != _sprite_desenganche_visible:
		_mostrar_ocultar_sprite_desenganche(mostrar)


func _actualizar_posicion_pantalla_desenganche() -> void:
	if _sprite_desenganche_visible and is_instance_valid(_sprite_desenganche) and _sprite_desenganche.visible:
		var cam := get_viewport().get_camera_3d() if get_viewport() else null
		if cam and not cam.is_position_behind(_sprite_desenganche.global_position):
			var sp := cam.unproject_position(_sprite_desenganche.global_position)
			if is_instance_valid(_btn_pantalla_desenganche):
				_btn_pantalla_desenganche.global_position = sp - _btn_pantalla_desenganche.size * 0.5
				_btn_pantalla_desenganche.visible = true
		else:
			if is_instance_valid(_btn_pantalla_desenganche):
				_btn_pantalla_desenganche.visible = false

		var hover = sin(Time.get_ticks_msec() * 0.0035) * 0.04
		_sprite_desenganche.position.y = _pos_base_sprite_desenganche.y + hover
	else:
		if is_instance_valid(_btn_pantalla_desenganche):
			_btn_pantalla_desenganche.visible = false


func _destruir_sprite_desenganche() -> void:
	if is_instance_valid(_canvas_desenganche):
		_canvas_desenganche.queue_free()
	_canvas_desenganche = null
	_btn_pantalla_desenganche = null
	if is_instance_valid(_sprite_desenganche):
		_sprite_desenganche.queue_free()
	_sprite_desenganche = null
	_label_desenganche = null
	_sprite_desenganche_visible = false

