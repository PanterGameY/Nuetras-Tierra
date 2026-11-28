# icono_entrada_vehiculo.gd
# Componente diegético de entrada a vehículos (Sprite3D interactivo por proximidad).
# Reemplaza los botones fijos 2D de pantalla por un icono flotante 3D junto a la manija de la puerta.
# Se activa únicamente cuando el jugador está dentro de la ZonaEntrada del vehículo específico.
# Incluye marco/borde naranja neón estilo glassmorphic y detección táctil/clic 100% infalible en pantalla.
extends Area3D

const COLOR_FONDO_VIDRIO: Color = Color(0.06, 0.06, 0.08, 0.90)
const COLOR_BORDE_NEON: Color = Color(1.00, 0.45, 0.00, 0.95)
const COLOR_ICONO: Color = Color(1.0, 1.0, 1.0, 1.0)
const RUTA_TEXTURA_ICONO: String = "res://recursos/botones/conducir.png"
const RUTA_FUENTE: String = "res://recursos/fonts/Moderniz.otf"
const ARCHIVO_CONFIG_OFFSETS: String = "user://offset_icono_conducir.cfg"
const RUTA_SONIDO_SUBIDA: String = "res://recursos/sonidos_vehiculo/efectos/abrir-puerta-vehiculo.ogg"

# ════════════════════════════════════════════════════════════════════════════
#  CALIBRACIÓN IDEAL FIJA (T800 / Vehículos)
# ════════════════════════════════════════════════════════════════════════════
@export_group("Calibración Posición")
## Offset local respecto al punto de anclaje (0.85, 0.85, 0.85 calibrado ideal)
@export var offset_posicion: Vector3 = Vector3(0.85, 0.85, 0.85):
	set(val):
		offset_posicion = val
		_actualizar_posicion_con_offset()

## Factor de escala del botón flotante (0.70 calibrado para T800 / Tractomulas)
@export var escala_icono: float = 0.70:
	set(val):
		escala_icono = clamp(val, 0.2, 3.0)
		_actualizar_escala_base()

@export_group("Audio Feedback")
## Sonido al abrir puerta o subir al vehículo (por defecto abrir-puerta-vehiculo.ogg)
@export var sonido_subida: AudioStream = null

## Ganancia en decibelios para el sonido de entrada (+8.0 dB para destacar nítidamente sobre el motor)
@export var volumen_sonido_db: float = 8.0

var vehiculo: Node3D = null
var zona_entrada: Area3D = null
var jugador_cerca: Node3D = null

var _activo: bool = false
var _tiempo_anim: float = 0.0
var _posicion_anclaje_original: Vector3 = Vector3.ZERO
var _base_pos_y: float = 0.0
var _tween_transicion: Tween = null
var _cooldown_subida: float = 0.0

# Nodos visuales y colisión
var fondo_borde_sprite: Sprite3D = null
var icono_sprite: Sprite3D = null
var label_texto: Label3D = null
var col_shape: CollisionShape3D = null

func _ready() -> void:
	add_to_group("icono_entrada_vehiculo")
	collision_layer = 1
	collision_mask = 0
	input_ray_pickable = true
	monitoring = false
	monitorable = false
	
	_crear_componentes_visuales()
	if not sonido_subida and ResourceLoader.exists(RUTA_SONIDO_SUBIDA):
		sonido_subida = load(RUTA_SONIDO_SUBIDA)
	
	visible = false
	scale = Vector3(0.01, 0.01, 0.01)
	if fondo_borde_sprite: fondo_borde_sprite.modulate.a = 0.0
	if icono_sprite: icono_sprite.modulate.a = 0.0
	if label_texto: label_texto.modulate.a = 0.0
	_base_pos_y = position.y

func _distancia_caja_redondeada(p: Vector2, b: Vector2, r: float) -> float:
	var q = p.abs() - b + Vector2(r, r)
	return min(max(q.x, q.y), 0.0) + Vector2(max(q.x, 0.0), max(q.y, 0.0)).length() - r

func _generar_textura_marco_neon() -> ImageTexture:
	var tam: int = 128
	var img = Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var centro := Vector2((tam - 1) * 0.5, (tam - 1) * 0.5)
	var r_ext: float = 56.0
	var r_int: float = 44.0

	for y in range(tam):
		for x in range(tam):
			var d := Vector2(x, y).distance_to(centro)
			if d <= r_ext:
				if d >= r_int:
					img.set_pixel(x, y, Color(0.88, 0.68, 0.28, 0.95))
				else:
					img.set_pixel(x, y, Color(0.06, 0.07, 0.09, 0.88))

	return ImageTexture.create_from_image(img)

func _crear_componentes_visuales() -> void:
	# 1. Colisionador amplio para touch / mouse click en espacio 3D
	col_shape = CollisionShape3D.new()
	var esfera = SphereShape3D.new()
	esfera.radius = 0.65 * escala_icono
	col_shape.shape = esfera
	add_child(col_shape)
	
	# 2. Punto circular estilo glassmorphic igual que mangueras y capo
	fondo_borde_sprite = Sprite3D.new()
	fondo_borde_sprite.name = "BordeNeon"
	fondo_borde_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fondo_borde_sprite.no_depth_test = true
	fondo_borde_sprite.render_priority = 10
	fondo_borde_sprite.shaded = false
	fondo_borde_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fondo_borde_sprite.pixel_size = 0.0042
	fondo_borde_sprite.texture = _generar_textura_marco_neon()
	add_child(fondo_borde_sprite)

	# 3. Etiqueta limpia "CONDUCIR" sobre el punto
	label_texto = Label3D.new()
	label_texto.name = "LabelSubir"
	label_texto.text = "CONDUCIR"
	label_texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_texto.no_depth_test = true
	label_texto.render_priority = 12
	label_texto.shaded = false
	label_texto.font_size = 34
	label_texto.outline_size = 8
	label_texto.outline_modulate = Color(0.04, 0.04, 0.06, 0.95)
	label_texto.modulate = Color(0.96, 0.88, 0.65, 1.0)
	label_texto.position = Vector3(0.0, 0.36, 0.0)
	if ResourceLoader.exists(RUTA_FUENTE):
		label_texto.font = load(RUTA_FUENTE)
	add_child(label_texto)

func configurar(p_vehiculo: Node3D, p_zona: Area3D) -> void:
	vehiculo = p_vehiculo
	zona_entrada = p_zona
	if is_instance_valid(zona_entrada):
		# 1. Buscar si existe un punto específico de manija o puerta en el vehículo
		var manija: Node3D = null
		if is_instance_valid(vehiculo):
			manija = vehiculo.find_child("ManijaConductor", true, false) as Node3D
			if not manija:
				manija = vehiculo.find_child("ManijaPuerta", true, false) as Node3D
			if not manija:
				manija = vehiculo.find_child("Manija", true, false) as Node3D
		
		if manija and is_instance_valid(manija):
			_posicion_anclaje_original = zona_entrada.to_local(manija.global_position)
			offset_posicion = Vector3.ZERO
		else:
			# 2. Si no hay marcador explícito, anclar respecto a ZonaEntrada
			var cs = zona_entrada.find_child("CollisionShape3D*", true, false)
			if not cs:
				cs = zona_entrada.get_node_or_null("CollisionShape3D")
			if cs and cs is CollisionShape3D:
				_posicion_anclaje_original = cs.position
			else:
				_posicion_anclaje_original = Vector3.ZERO
			# Cargar offsets si existiesen guardados localmente
			_cargar_offsets_guardados()
		_actualizar_posicion_con_offset()

func _obtener_escala_padre_segura() -> Vector3:
	if is_instance_valid(zona_entrada):
		var s := zona_entrada.scale.abs()
		return Vector3(maxf(s.x, 0.01), maxf(s.y, 0.01), maxf(s.z, 0.01))
	return Vector3.ONE

func _actualizar_posicion_con_offset() -> void:
	var esc_padre := _obtener_escala_padre_segura()
	position = _posicion_anclaje_original + Vector3(
		offset_posicion.x / esc_padre.x,
		offset_posicion.y / esc_padre.y,
		offset_posicion.z / esc_padre.z
	)
	_base_pos_y = position.y

func _actualizar_escala_base() -> void:
	if col_shape and col_shape.shape is SphereShape3D:
		(col_shape.shape as SphereShape3D).radius = 0.65 * escala_icono

func mostrar(p_jugador: Node3D) -> void:
	if not is_instance_valid(vehiculo):
		return
	if "activo" in vehiculo and vehiculo.activo:
		return
	
	jugador_cerca = p_jugador
	_activo = true
	_cooldown_subida = 0.15
	
	visible = true
	input_ray_pickable = true
	
	if _tween_transicion and _tween_transicion.is_valid():
		_tween_transicion.kill()
		
	_tween_transicion = create_tween().set_parallel(true)
	_tween_transicion.set_ease(Tween.EASE_OUT)
	_tween_transicion.set_trans(Tween.TRANS_BACK)
	var esc_padre := _obtener_escala_padre_segura()
	var esc_target = Vector3(escala_icono / esc_padre.x, escala_icono / esc_padre.y, escala_icono / esc_padre.z)
	_tween_transicion.tween_property(self, "scale", esc_target, 0.32)
	if fondo_borde_sprite:
		_tween_transicion.tween_property(fondo_borde_sprite, "modulate:a", 1.0, 0.25)
	if icono_sprite:
		_tween_transicion.tween_property(icono_sprite, "modulate:a", 1.0, 0.25)
	if label_texto:
		_tween_transicion.tween_property(label_texto, "modulate:a", 1.0, 0.25)

func ocultar() -> void:
	_activo = false
	jugador_cerca = null
	input_ray_pickable = false
	
	if _tween_transicion and _tween_transicion.is_valid():
		_tween_transicion.kill()
		
	_tween_transicion = create_tween().set_parallel(true)
	_tween_transicion.set_ease(Tween.EASE_IN)
	_tween_transicion.set_trans(Tween.TRANS_CUBIC)
	_tween_transicion.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.20)
	if fondo_borde_sprite:
		_tween_transicion.tween_property(fondo_borde_sprite, "modulate:a", 0.0, 0.18)
	if icono_sprite:
		_tween_transicion.tween_property(icono_sprite, "modulate:a", 0.0, 0.18)
	if label_texto:
		_tween_transicion.tween_property(label_texto, "modulate:a", 0.0, 0.18)
	_tween_transicion.chain().tween_callback(func():
		if not _activo:
			visible = false
	)

func _process(delta: float) -> void:
	if _cooldown_subida > 0.0:
		_cooldown_subida -= delta

	if not is_instance_valid(vehiculo):
		return
	if "activo" in vehiculo and vehiculo.activo:
		if _activo or visible:
			ocultar()
		return

	# Comprobación de proximidad en tiempo real mediante ZonaEntrada puntual
	if is_instance_valid(zona_entrada):
		var jugador_detectado: Node3D = null
		var bodies = zona_entrada.get_overlapping_bodies()
		for b in bodies:
			if b and b.is_in_group("jugador"):
				if b.get("_conduciendo") != true and b.get("esta_conduciendo") != true:
					jugador_detectado = b
					break

		if not jugador_detectado:
			# Fallback por distancia horizontal/vertical a la puerta (hasta 3.5m)
			var jugador_node = get_tree().get_first_node_in_group("jugador") if get_tree() else null
			if is_instance_valid(jugador_node) and jugador_node.is_inside_tree():
				if jugador_node is Node3D and jugador_node.get("_conduciendo") != true and jugador_node.get("esta_conduciendo") != true:
					var pz: Vector3 = zona_entrada.global_position
					var pj: Vector3 = (jugador_node as Node3D).global_position
					var d_xz := Vector2(pz.x - pj.x, pz.z - pj.z).length()
					if d_xz <= 3.5 and absf(pz.y - pj.y) <= 3.5:
						jugador_detectado = jugador_node

		if jugador_detectado:
			if not _activo:
				mostrar(jugador_detectado)
		else:
			if _activo:
				ocultar()

	if not visible or not _activo:
		return

	_tiempo_anim += delta
	
	# Flotación suave oscilatoria vertical (3.5cm de amplitud)
	var esc_padre := _obtener_escala_padre_segura()
	position.y = _base_pos_y + (sin(_tiempo_anim * 3.0) * 0.035) / esc_padre.y
	
	# Sutil pulsación de escala (breathing)
	var factor_pulso: float = 1.0 + sin(_tiempo_anim * 2.4) * 0.035
	if not (_tween_transicion and _tween_transicion.is_running()):
		var esc_actual = factor_pulso * escala_icono
		scale = Vector3(esc_actual / esc_padre.x, esc_actual / esc_padre.y, esc_actual / esc_padre.z)

func _input(event: InputEvent) -> void:
	if not visible or not _activo or _cooldown_subida > 0.0:
		return

	# ════════════════════════════════════════════════════════════════════════
	# DETECCIÓN DE CLIC / TOUCH 100% INFALIBLE (DESPROYECCIÓN 2D A PANTALLA)
	# ════════════════════════════════════════════════════════════════════════
	var click_pos: Vector2 = Vector2(-1, -1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		click_pos = event.position
	elif event is InputEventScreenTouch and event.is_pressed():
		click_pos = event.position

	if click_pos != Vector2(-1, -1):
		var cam = get_viewport().get_camera_3d() if get_viewport() else null
		if cam and is_instance_valid(cam):
			if not cam.is_position_behind(global_position):
				var screen_pos = cam.unproject_position(global_position)
				# Radio de toque holgado en píxeles (mínimo 70px)
				var radio_px: float = max(90.0 * escala_icono, 70.0)
				if click_pos.distance_to(screen_pos) <= radio_px:
					get_viewport().set_input_as_handled()
					intentar_subir()
					return

func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not visible or not _activo or _cooldown_subida > 0.0:
		return
		
	var toque_valido: bool = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		toque_valido = true
	elif event is InputEventScreenTouch and event.is_pressed():
		toque_valido = true
		
	if toque_valido:
		get_viewport().set_input_as_handled()
		intentar_subir()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _activo or _cooldown_subida > 0.0:
		return

	if event.is_action_pressed("interactuar") or event.is_action_pressed("ui_accept"):
		if is_instance_valid(jugador_cerca):
			var mi_dist: float = global_position.distance_squared_to(jugador_cerca.global_position)
			var otros = get_tree().get_nodes_in_group("icono_entrada_vehiculo")
			for otro in otros:
				if otro != self and is_instance_valid(otro) and otro.is_inside_tree() and otro.visible and otro.get("_activo") == true:
					if otro.global_position.distance_squared_to(jugador_cerca.global_position) < mi_dist:
						return
						
		get_viewport().set_input_as_handled()
		intentar_subir()

func _determinar_bus_audio() -> String:
	if AudioServer.get_bus_index("SFX") != -1:
		return "SFX"
	elif AudioServer.get_bus_index("Efectos") != -1:
		return "Efectos"
	return "Master"

func _reproducir_sonido_subida() -> void:
	if not sonido_subida and ResourceLoader.exists(RUTA_SONIDO_SUBIDA):
		sonido_subida = load(RUTA_SONIDO_SUBIDA)
	if sonido_subida:
		var asp := AudioStreamPlayer.new()
		asp.process_mode = Node.PROCESS_MODE_ALWAYS
		asp.stream = sonido_subida
		asp.bus = _determinar_bus_audio()
		asp.volume_db = volumen_sonido_db
		if get_tree() and get_tree().root:
			get_tree().root.add_child(asp)
		else:
			add_child(asp)
		asp.play()
		print("[IconoEntrada] Reproduciendo sonido de puerta: %s (bus: %s, %.1f dB)" % [
			sonido_subida.resource_path.get_file() if sonido_subida.resource_path != "" else "Stream",
			asp.bus,
			asp.volume_db
		])
		asp.finished.connect(asp.queue_free)

func intentar_subir() -> void:
	if not is_instance_valid(vehiculo):
		return
	if "activo" in vehiculo and vehiculo.activo:
		return
		
	if not is_instance_valid(jugador_cerca):
		jugador_cerca = get_tree().get_first_node_in_group("jugador")
	if not is_instance_valid(jugador_cerca):
		return
	if jugador_cerca.get_meta("llevando_pistola_gasolina", false):
		if has_node("/root/NotificationManager"):
			var nm := get_node("/root/NotificationManager")
			if nm.has_method("notificar_error"):
				nm.call("notificar_error", "Cuelga el surtidor antes de subir al vehículo.")
		return
		
	# Reproducir sonido de apertura de puerta / subida al vehículo
	_reproducir_sonido_subida()

	# Feedback visual táctil elástico
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector3(1.25 * escala_icono, 1.25 * escala_icono, 1.25 * escala_icono), 0.08)
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	
	var j = jugador_cerca
	ocultar()
	
	# Subida diegética y directa al vehículo específico puntual
	if vehiculo.has_method("subir_jugador"):
		vehiculo.subir_jugador(j)
	elif j.has_method("_subir_al_vehiculo"):
		j._subir_al_vehiculo(vehiculo)
	elif j.has_method("entrar_al_vehiculo"):
		j.entrar_al_vehiculo(vehiculo)

func _obtener_clave_vehiculo() -> String:
	if is_instance_valid(vehiculo) and vehiculo.name != "":
		return vehiculo.name
	return "General"

func _cargar_offsets_guardados() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(ARCHIVO_CONFIG_OFFSETS) == OK:
		var sec = _obtener_clave_vehiculo()
		if cfg.has_section(sec):
			offset_posicion = cfg.get_value(sec, "offset", offset_posicion)
			escala_icono = cfg.get_value(sec, "escala", escala_icono)
		elif cfg.has_section("General"):
			offset_posicion = cfg.get_value("General", "offset", offset_posicion)
			escala_icono = cfg.get_value("General", "escala", escala_icono)




