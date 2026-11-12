@tool
extends Node3D
class_name AcademiaSpawnPoint

## AcademiaSpawnPoint.gd
##
## Coloca este nodo en tu escena 3D en la ubicación de la Academia de Enseñanza
## para que funcione como el punto de referencia del GPS y visualizador del checkpoint de la academia.

@export_group("Visuales del Checkpoint")
## Color del holograma del checkpoint (se recomienda azul o amarillo para destacar comercial/misión)
@export var checkpoint_color: Color = Color(0.20, 0.60, 1.00, 0.45):
	set(val):
		checkpoint_color = val
		_update_visuals()

## Radio del checkpoint
@export var checkpoint_radius: float = 1.8:
	set(val):
		checkpoint_radius = val
		_update_visuals()

## Altura de la columna de luz
@export var checkpoint_height: float = 3.5:
	set(val):
		checkpoint_height = val
		_update_visuals()

## Velocidad de la pulsación de respiración
@export var pulse_speed: float = 1.5:
	set(val):
		pulse_speed = val
		_update_visuals()

## Intensidad de la pulsación (expansión de tamaño)
@export var pulse_strength: float = 0.08:
	set(val):
		pulse_strength = val
		_update_visuals()

## Velocidad de la onda de escaneo vertical
@export var scan_speed: float = 2.5:
	set(val):
		scan_speed = val
		_update_visuals()

@export_group("Teleportacion y Vehiculos")
## Marker3D a donde se teletransportara el jugador al adquirir una licencia
@export var teleport_target: Marker3D = null

## Marker3D donde aparecera el vehiculo spawnado
@export var vehicle_spawn_marker: Marker3D = null

## Vehiculo para la Licencia de Automovil
@export var vehicle_auto: PackedScene = null

## Vehiculo para la Licencia de Camion
@export var vehicle_camion: PackedScene = null

## Vehiculo para Carga Delicada
@export var vehicle_delicada: PackedScene = null

## Vehiculo para Carga Sobredimensionada
@export var vehicle_sobredimensionada: PackedScene = null

@export_group("Prueba de Ruta (Path3D)")
## Path3D que define la ruta de la prueba
@export var test_route_path: Path3D = null

## Limite de velocidad permitido durante la prueba (km/h)
@export var max_speed_limit: float = 50.0

## Cantidad maxima de choques permitidos antes de reprobar
@export var max_allowed_collisions: int = 3

# Variables internas para gestionar el estado de la prueba
var test_active: bool = false
var current_checkpoint_idx: int = 0
var active_test_vehicle: Node3D = null
var active_test_checkpoints: Array = []
var collision_count: int = 0
var speed_warning_shown: bool = false
var test_hud: CanvasLayer = null
var is_cinematic_running: bool = false
var last_attempted_vehicle_scene: PackedScene = null
var _inmunidad_seguridad: float = 0.0
var _admob_instance: Node = null
var _admob_active_reward_type: int = 1
var _admob_reward_granted: bool = false
var _posicion_fallo: Vector3 = Vector3.ZERO
var _rotacion_fallo: Vector3 = Vector3.ZERO
var _cinematica_reproducida_una_vez: bool = false
var cine_cam_ref: Camera3D = null
var path_follow_ref: PathFollow3D = null
var path_indicators: Array = []
var path_indicators_tween: Tween = null
var _speed_warning_timer: float = -1.0
var _speed_warning_canvas: CanvasLayer = null
var _esperando_reclamar_licencia_en_puerta: bool = false


@export_group("Debug/Pruebas")
## Presiona esta casilla en el Inspector durante la prueba para ir directamente al penúltimo checkpoint (29/30)
@export var debug_ir_al_penultimo_checkpoint: bool = false:
	set(val):
		if val == true:
			debug_ir_al_penultimo_checkpoint = false
			if test_active and active_test_checkpoints.size() > 1:
				current_checkpoint_idx = active_test_checkpoints.size() - 2
				_actualizar_visibilidad_checkpoints()
				if is_instance_valid(active_test_vehicle):
					var penultimo_cp = active_test_checkpoints[current_checkpoint_idx]
					active_test_vehicle.global_position = penultimo_cp["position"] + Vector3(0, 0.5, 0)
					if "linear_velocity" in active_test_vehicle:
						active_test_vehicle.linear_velocity = Vector3.ZERO
					if "angular_velocity" in active_test_vehicle:
						active_test_vehicle.angular_velocity = Vector3.ZERO
				print("[Academia] Debug: Transportado al penúltimo checkpoint (%d/%d)" % [current_checkpoint_idx + 1, active_test_checkpoints.size()])

## Presiona esta casilla en el Inspector durante el juego para sumar +100 EXP al jugador
@export var debug_anadir_100_exp: bool = false:
	set(val):
		if val == true:
			debug_anadir_100_exp = false
			var datos = get_node_or_null("/root/DatosUsuario")
			if datos and datos.has_method("agregar_experiencia"):
				datos.call("agregar_experiencia", 100)
				print("[AcademiaSpawnPoint] +100 EXP agregados de forma manual para pruebas.")

var label_3d: Label3D = null
var player_inside: bool = false
var dialogue_ui: CanvasLayer = null

func _ready() -> void:
	# Limpiar cualquier residuo del visual antiguo del editor si existe
	var legacy_visual = get_node_or_null("_EditorVisual")
	if legacy_visual:
		legacy_visual.queue_free()
		
	_update_visuals()
	
	if not Engine.is_editor_hint():
		add_to_group("AcademiaSpawnPoint")
		tree_exited.connect(func(): _cerrar_tienda_dialogo())
		
		# Inicialización del plugin de AdMob (v5.0.0 Poing Studios / Legacy)
		if ClassDB.class_exists("MobileAds") or Engine.has_singleton("MobileAds"):
			var on_init = OnInitializationCompleteListener.new()
			on_init.on_initialization_complete = func(_status) -> void:
				print("[Academia] AdMob v5.0.0 inicializado correctamente.")
			MobileAds.initialize(on_init)
		elif ClassDB.class_exists("Admob"):
			_admob_instance = ClassDB.instantiate("Admob")
			add_child(_admob_instance)
			print("[Academia] AdMob legacy plugin instanciado de forma correcta.")
			
			# Conexión de señales nativas
			_admob_instance.connect("rewarded_ad_loaded", func(_ad_info, _response_info):
				print("[Academia] Anuncio recompensado cargado, mostrándolo...")
				_admob_instance.show_rewarded_ad()
			)
			_admob_instance.connect("rewarded_ad_failed_to_load", func(_ad_info, error_data):
				print("[Academia] Anuncio falló al cargar: ", error_data)
				_notificar_tienda("No se pudo cargar el anuncio. Intenta de nuevo.", "error")
			)
			_admob_instance.connect("rewarded_ad_user_earned_reward", func(_ad_info, _reward_data):
				print("[Academia] Usuario vio el anuncio por completo.")
				_otorgar_recompensa_admob(_admob_active_reward_type)
			)
			_admob_instance.connect("rewarded_ad_dismissed_full_screen_content", func(_ad_info):
				print("[Academia] Anuncio cerrado por el usuario.")
			)
		
		print("[AcademiaSpawnPoint] Registrado en la escena en la posición: ", global_position)

func _update_visuals() -> void:
	# Asegurarnos de que el árbol esté listo
	if not is_inside_tree():
		return
		
	# 1. Crear o buscar Marker3D para el Checkpoint
	var marker_node = get_node_or_null("Marker3D") as Marker3D
	if not marker_node:
		marker_node = Marker3D.new()
		marker_node.name = "Marker3D"
		add_child(marker_node)
		if Engine.is_editor_hint():
			marker_node.owner = get_tree().edited_scene_root
		
	# 2. Añadir/Actualizar la malla visual del Checkpoint
	var checkpoint_mesh = marker_node.get_node_or_null("CheckpointVisual") as MeshInstance3D
	if not checkpoint_mesh:
		checkpoint_mesh = MeshInstance3D.new()
		checkpoint_mesh.name = "CheckpointVisual"
		marker_node.add_child(checkpoint_mesh)
		if Engine.is_editor_hint():
			checkpoint_mesh.owner = get_tree().edited_scene_root
		
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = checkpoint_radius
	cylinder.bottom_radius = checkpoint_radius
	cylinder.height = checkpoint_height
	cylinder.radial_segments = 32
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	checkpoint_mesh.mesh = cylinder
	
	# Centrar el cilindro para que el pivote esté exactamente en el suelo
	checkpoint_mesh.position = Vector3(0, checkpoint_height / 2.0, 0)
	
	# Material con el shader animado
	var shader_res = load("res://shaders/checkpoint.gdshader")
	if shader_res:
		var mat = ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("color_albedo", checkpoint_color)
		mat.set_shader_parameter("scale_pulse_speed", pulse_speed)
		mat.set_shader_parameter("scale_pulse_strength", pulse_strength)
		mat.set_shader_parameter("speed", scan_speed)
		checkpoint_mesh.material_override = mat
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = checkpoint_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		checkpoint_mesh.material_override = mat

	# 3. Crear/Actualizar Label3D para el texto flotante de "Academia"
	var label_node = get_node_or_null("TextoAcademia") as Label3D
	if not label_node:
		label_node = Label3D.new()
		label_node.name = "TextoAcademia"
		label_node.text = "Academia"
		label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_node.font_size = 48
		label_node.outline_modulate = Color.BLACK
		label_node.outline_size = 12
		add_child(label_node)
		if Engine.is_editor_hint():
			label_node.owner = get_tree().edited_scene_root
		
	# Sincronizar el color del texto y la altura
	label_node.modulate = Color(checkpoint_color.r, checkpoint_color.g, checkpoint_color.b)
	label_node.position = Vector3(0, checkpoint_height + 0.5, 0)
	
	# En el editor queremos ver el texto "Academia" siempre para saber cómo queda
	if Engine.is_editor_hint():
		label_node.visible = true
	else:
		label_node.visible = false
		
	label_3d = label_node

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	# Buscar al jugador usando el grupo oficial "jugador"
	var player = null
	var players = get_tree().get_nodes_in_group("jugador")
	if players.size() > 0:
		player = players[0]
		
	if not player:
		# Fallback a bÃºsqueda en escena por nombre
		var root = get_tree().current_scene if get_tree() else null
		if root:
			player = root.find_child("Jugador2", true, false)
			if not player:
				for child in root.get_children():
					if (child.name.to_int() > 0 or child.name.begins_with("Jugador_")) and child is Node3D:
						player = child
						break
	
	if _inmunidad_seguridad > 0.0:
		_inmunidad_seguridad -= delta

	if player and player is Node3D:
		# â”€â”€ CONTROL DEL ESTADO DE LA PRUEBA EN PROCESO â”€â”€
		if test_active and is_instance_valid(active_test_vehicle):
			# Comprobar si el jugador se bajÃ³ del vehÃ­culo
			var is_driving = false
			var v_actual = player.get("_vehiculo_actual")
			if v_actual == active_test_vehicle:
				is_driving = true
			
			if not is_driving:
				_reprobar_prueba("Te bajaste del vehiculo de prueba!")
				return
			
			# Comprobar velocidad del vehÃ­culo
			var velocity_vec = Vector3.ZERO
			if active_test_vehicle.has_method("get_real_velocity"):
				velocity_vec = active_test_vehicle.call("get_real_velocity")
			elif "linear_velocity" in active_test_vehicle:
				velocity_vec = active_test_vehicle.linear_velocity
			elif "velocity" in active_test_vehicle:
				velocity_vec = active_test_vehicle.velocity
			
			var speed_kmh = velocity_vec.length() * 3.6
			_actualizar_hud_prueba(speed_kmh)
			
			if speed_kmh > max_speed_limit:
				if _speed_warning_timer < 0.0:
					_speed_warning_timer = 5.0
				else:
					_speed_warning_timer -= delta
				
				_mostrar_o_actualizar_advertencia_velocidad(_speed_warning_timer)
				
				if _speed_warning_timer <= 0.0:
					_ocultar_advertencia_velocidad()
					_reprobar_prueba("No redujiste la velocidad a tiempo!")
					return
			else:
				if _speed_warning_timer >= 0.0:
					_speed_warning_timer = -1.0
					_ocultar_advertencia_velocidad()
			
			# Comprobar proximidad del checkpoint activo
			if current_checkpoint_idx < active_test_checkpoints.size():
				var target_cp_pos = active_test_checkpoints[current_checkpoint_idx]["position"] as Vector3
				var v_pos_2d = Vector2(active_test_vehicle.global_position.x, active_test_vehicle.global_position.z)
				var cp_pos_2d = Vector2(target_cp_pos.x, target_cp_pos.z)
				var dist_2d = v_pos_2d.distance_to(cp_pos_2d)
				var h_diff = abs(active_test_vehicle.global_position.y - target_cp_pos.y)
				
				# Si pasa por el checkpoint
				if dist_2d < 4.0 and h_diff < 4.0:
					_avanzar_checkpoint()
			
		# Si completó la ruta y se baja del auto, iniciar timer de 3 segundos para que desaparezca
		if _esperando_reclamar_licencia_en_puerta and is_instance_valid(active_test_vehicle):
			var is_driving = false
			var v_actual = player.get("_vehiculo_actual")
			if v_actual == active_test_vehicle:
				is_driving = true
			
			if not is_driving:
				var v_temp = active_test_vehicle
				active_test_vehicle = null
				_notificar_tienda("Vehículo devolviéndose a la academia en 3 segundos...", "info")
				get_tree().create_timer(3.0).timeout.connect(func():
					if is_instance_valid(v_temp):
						v_temp.queue_free()
				)

		# Si no hay prueba activa, comprobar si el jugador se sube al vehículo spawnado para iniciarla
		elif is_instance_valid(active_test_vehicle) and not test_active and not is_cinematic_running and not _esperando_reclamar_licencia_en_puerta and not is_instance_valid(_dialogo_derrota_referencia) and not get_tree().paused:
			var is_driving = false
			var v_actual = player.get("_vehiculo_actual")
			if v_actual == active_test_vehicle:
				is_driving = true
			
			if is_driving:
				if not _cinematica_reproducida_una_vez:
					_iniciar_cinematica_prueba(player)
				else:
					# Omitir cinemática, ir directo a iniciar la prueba
					_iniciar_prueba_oficial()
		
		# ── DETECCIÓN DE ENTRADA AL CHECKPOINT DE LA ACADEMIA (PUERTA) ──
		var checkpoint_pos = global_position
		var marker = get_node_or_null("Marker3D") as Marker3D
		if marker:
			checkpoint_pos = marker.global_position
			
		var player_pos_2d = Vector2(player.global_position.x, player.global_position.z)
		var self_pos_2d = Vector2(checkpoint_pos.x, checkpoint_pos.z)
		var dist_2d = player_pos_2d.distance_to(self_pos_2d)
		var height_diff = abs(player.global_position.y - checkpoint_pos.y)
		
		if dist_2d < (checkpoint_radius + 2.2) and height_diff < (checkpoint_height + 2.0):
			if not player_inside:
				player_inside = true
				if _esperando_reclamar_licencia_en_puerta:
					_esperando_reclamar_licencia_en_puerta = false
					_aprobar_prueba()
				else:
					_abrir_tienda_dialogo()
		else:
			if player_inside:
				player_inside = false
				_cerrar_tienda_dialogo()
		
		# Visibilidad de etiqueta GPS
		var gps_dirigido_a_academia := false
		var gps_line = player.get_node_or_null("GPSRutaLinea")
		if gps_line and gps_line.get("active") == true:
			var target_pos = gps_line.get("target_position")
			if target_pos.distance_to(checkpoint_pos) < 3.0:
				gps_dirigido_a_academia = true
		
		if is_instance_valid(label_3d) and label_3d.visible != gps_dirigido_a_academia:
			label_3d.visible = gps_dirigido_a_academia

func _abrir_tienda_dialogo() -> void:
	_cerrar_tienda_dialogo()
	
	# Habilitar mouse para interactuar
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var canvas = CanvasLayer.new()
	canvas.name = "AcademiaTiendaOverlay"
	canvas.layer = 95
	add_child(canvas)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92) # Glassmorphic translúcido
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(1.00, 0.45, 0.00, 0.80) # Naranja Neon de alto contraste
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(1.00, 0.45, 0.00, 0.15)
	style.shadow_size = 35
	style.content_margin_left = 45
	style.content_margin_right = 45
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)
	
	# Tamaño adaptable y grande para lectura móvil cómoda
	panel.custom_minimum_size = Vector2(1300, 850)
	panel.pivot_offset = Vector2(650, 425)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	panel.add_child(vbox)

	# Cabecera
	var title_lbl = Label.new()
	title_lbl.text = "ACADEMIA DE CONDUCCIÓN"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 48)
	title_lbl.add_theme_color_override("font_color", Color(1.00, 0.45, 0.00)) # Naranja neón de la academia
	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	if font:
		title_lbl.add_theme_font_override("font", font)
	vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = "Adquiere las licencias requeridas para desbloquear misiones y conducir vehículos especiales."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 28)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	vbox.add_child(desc_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Lista de licencias con ScrollContainer
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# Grid a 2 columnas para albergar tarjetas grandes de licencias
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 35)
	grid.add_theme_constant_override("v_separation", 30)
	scroll.add_child(grid)

	_dibujar_opciones_tienda(grid)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Botón Cerrar (Estilizado de 80px de alto con Moderniz de 32px)
	var close_btn = Button.new()
	close_btn.text = "SALIR DE LA ACADEMIA"
	close_btn.custom_minimum_size = Vector2(0, 80)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.35, 0.12, 0.15, 0.85)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.70, 0.20, 0.25, 0.8)
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	close_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_style_hover = btn_style.duplicate() as StyleBoxFlat
	btn_style_hover.bg_color = Color(0.50, 0.15, 0.20, 0.95)
	close_btn.add_theme_stylebox_override("hover", btn_style_hover)
	
	close_btn.add_theme_font_size_override("font_size", 32)
	if font:
		close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(func():
		_cerrar_tienda_dialogo()
	)
	vbox.add_child(close_btn)

	# Animación de entrada
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var anim_tw = get_tree().create_tween().set_parallel(true)
	anim_tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tw.tween_property(panel, "modulate:a", 1.0, 0.30)
	dialogue_ui = canvas

func _dibujar_opciones_tienda(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()
	
	var datos = get_node_or_null("/root/DatosUsuario")
	if not datos:
		return
	
	var level = datos.get("nivel") as int
	var money = datos.get("dinero") as float
	
	var has_auto = datos.get("licencia_automovil") as bool
	var has_truck = datos.get("licencia_camion") as bool
	var has_delicate = datos.get("licencia_carga_delicada") as bool
	var has_oversized = datos.get("licencia_carga_sobredimensionada") as bool

	var licencias = [
		{
			"id": "auto",
			"nombre": "LICENCIA DE AUTOMÓVIL",
			"costo": 150.0,
			"desc": "Permite conducir vehículos pequeños y livianos de pasajeros.",
			"req_desc": "Nivel Requerido: 1 (Abierto)",
			"cumple": true,
			"adquirida": has_auto
		},
		{
			"id": "camion",
			"nombre": "LICENCIA DE CAMIÓN",
			"costo": 500.0,
			"desc": "Permite conducir vehículos pesados y camiones de carga articulados.",
			"req_desc": "Requiere: Licencia de Auto y Nivel 3+",
			"cumple": has_auto and level >= 3,
			"adquirida": has_truck
		},
		{
			"id": "delicada",
			"nombre": "CARGA DELICADA",
			"costo": 1200.0,
			"desc": "Habilita el transporte especial de cargas frágiles de alto valor.",
			"req_desc": "Requiere: Licencia de Camión y Nivel 10+",
			"cumple": has_truck and level >= 10,
			"adquirida": has_delicate
		},
		{
			"id": "sobredimensionada",
			"nombre": "CARGA SOBREDIMENSIONADA",
			"costo": 3000.0,
			"desc": "Habilita el transporte de cargas voluminosas e industriales.",
			"req_desc": "Requiere: Lic. Camión, Carga Delicada y Nivel 20+",
			"cumple": has_truck and has_delicate and level >= 20,
			"adquirida": has_oversized
		}
	]

	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	for lic in licencias:
		# Crear Tarjeta (Panel Container)
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 240)
		
		# Estilo de la tarjeta
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.08, 0.11, 0.95)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.corner_radius_top_left = 12
		card_style.corner_radius_top_right = 12
		card_style.corner_radius_bottom_left = 12
		card_style.corner_radius_bottom_right = 12
		card_style.content_margin_left = 25
		card_style.content_margin_right = 25
		card_style.content_margin_top = 25
		card_style.content_margin_bottom = 25
		
		# Color del borde según estado
		if lic["adquirida"]:
			card_style.border_color = Color(0.20, 0.80, 0.40, 0.8) # Verde para adquirida
		elif lic["cumple"]:
			card_style.border_color = Color(1.00, 0.45, 0.00, 0.7) # Naranja neón si se puede adquirir
		else:
			card_style.border_color = Color(0.90, 0.30, 0.30, 0.3) # Rojo/apagado si no cumple
			
		card.add_theme_stylebox_override("panel", card_style)
		grid.add_child(card)

		# Contenedor interno de la tarjeta
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 12)
		card.add_child(card_vbox)

		# 1. Nombre de Licencia
		var name_lbl = Label.new()
		name_lbl.text = lic["nombre"]
		name_lbl.add_theme_font_size_override("font_size", 28)
		if lic["adquirida"]:
			name_lbl.add_theme_color_override("font_color", Color(0.20, 0.80, 0.40))
		elif lic["cumple"]:
			name_lbl.add_theme_color_override("font_color", Color(1.00, 0.45, 0.00))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			
		if font:
			name_lbl.add_theme_font_override("font", font)
		card_vbox.add_child(name_lbl)

		# 2. Descripción
		var desc_lbl = Label.new()
		desc_lbl.text = lic["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 24)
		desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(desc_lbl)

		# 3. Requisitos
		var req_lbl = Label.new()
		req_lbl.text = lic["req_desc"]
		req_lbl.add_theme_font_size_override("font_size", 24)
		if lic["adquirida"] or lic["cumple"]:
			req_lbl.add_theme_color_override("font_color", Color(0.20, 0.80, 0.40))
		else:
			req_lbl.add_theme_color_override("font_color", Color(0.90, 0.30, 0.30))
		card_vbox.add_child(req_lbl)

		# Espaciador para empujar el botón abajo
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vbox.add_child(spacer)

		# 4. Botón de Acción
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 80) # Altura reglamentaria de 80px
		
		var btn_style = StyleBoxFlat.new()
		btn_style.corner_radius_top_left = 12 # Radio reglamentario de 12px
		btn_style.corner_radius_top_right = 12
		btn_style.corner_radius_bottom_left = 12
		btn_style.corner_radius_bottom_right = 12
		
		if lic["adquirida"]:
			btn.text = "ADQUIRIDA"
			btn.disabled = true
			btn_style.bg_color = Color(0.10, 0.40, 0.20, 0.4)
			btn.add_theme_color_override("font_color_disabled", Color(0.20, 0.80, 0.40))
		elif lic["cumple"]:
			btn.text = "ADQUIRIR ($%d)" % lic["costo"]
			btn.disabled = false
			
			if money >= lic["costo"]:
				btn_style.bg_color = Color(1.00, 0.45, 0.00, 0.85) # Naranja neón activado
				btn.pressed.connect(func(): _intentar_comprar_licencia(lic["id"], lic["costo"]))
			else:
				btn.text = "DINERO INSUFICIENTE ($%d)" % lic["costo"]
				btn.disabled = true
				btn_style.bg_color = Color(0.35, 0.20, 0.10, 0.5)
				btn.add_theme_color_override("font_color_disabled", Color(0.8, 0.5, 0.3))
		else:
			btn.text = "BLOQUEADA"
			btn.disabled = true
			btn_style.bg_color = Color(0.20, 0.22, 0.25, 0.6)
			btn.add_theme_color_override("font_color_disabled", Color(0.55, 0.55, 0.60))
			
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("disabled", btn_style)
		
		if not btn.disabled:
			var btn_style_hover = btn_style.duplicate() as StyleBoxFlat
			btn_style_hover.bg_color = Color(btn_style.bg_color.r * 1.15, btn_style.bg_color.g * 1.15, btn_style.bg_color.b * 1.15, 1.0)
			btn.add_theme_stylebox_override("hover", btn_style_hover)
		
		btn.add_theme_font_size_override("font_size", 28)
		if font:
			btn.add_theme_font_override("font", font)
		card_vbox.add_child(btn)

func _intentar_comprar_licencia(lic_id: String, costo: float) -> void:
	var datos = get_node_or_null("/root/DatosUsuario")
	if not datos:
		return
	
	if datos.dinero < costo:
		_notificar_tienda("Dinero insuficiente.", "error")
		return
	
	datos.dinero -= costo
	
	match lic_id:
		"auto":
			# Desactivado temporalmente para pruebas
			# datos.licencia_automovil = true
			datos.completar_mision_licencia()
		"camion":
			datos.licencia_camion = true
		"delicada":
			datos.licencia_carga_delicada = true
		"sobredimensionada":
			datos.licencia_carga_sobredimensionada = true
	
	datos.save_local()
	
	# Reproducir sonido de caja registradora
	var sfx = AudioStreamPlayer.new()
	var money_stream = load("res://recursos/efectos/money.mp3")
	if money_stream:
		sfx.stream = money_stream
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())
	
	_notificar_tienda("Licencia adquirida correctamente!", "exito")
	
	# â”€â”€ TELETRANSPORTACIÃ“N Y SPAWN CON TRANSICIÃ“N SUAVE â”€â”€
	var player = null
	var players = get_tree().get_nodes_in_group("jugador")
	if players.size() > 0:
		player = players[0]
	if not player:
		var root = get_tree().current_scene if get_tree() else null
		if root:
			player = root.find_child("Jugador2", true, false)
			
	var vehicle_scene: PackedScene = null
	match lic_id:
		"auto": vehicle_scene = vehicle_auto
		"camion": vehicle_scene = vehicle_camion
		"delicada": vehicle_scene = vehicle_delicada
		"sobredimensionada": vehicle_scene = vehicle_sobredimensionada
	
	last_attempted_vehicle_scene = vehicle_scene
	_ejecutar_fade_y_teleport(player, vehicle_scene)
	_cerrar_tienda_dialogo()

func _notificar_tienda(msg: String, tipo: String) -> void:
	var celular = get_node_or_null("/root/CelularUI")
	if celular:
		celular.call("notificar", msg, tipo)
	else:
		print("[Academia] Notificacion: ", msg)

func _cerrar_tienda_dialogo() -> void:
	if is_instance_valid(dialogue_ui):
		dialogue_ui.queue_free()
		dialogue_ui = null
	_cerrar_dialogo_derrota()

func _anadir_flecha_indicadora(vehiculo: Node3D) -> void:
	# Contenedor pivot para las animaciones del cono flotante
	var marker_pivot = Node3D.new()
	marker_pivot.name = "MarcadorVehiculo"
	marker_pivot.position = Vector3(0, 3.4, 0)
	vehiculo.add_child(marker_pivot)
	
	# 1. Piramide invertida 3D (CylinderMesh con radio superior 0)
	var pyramid = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.45
	cone.height = 0.8
	cone.radial_segments = 4 # Piramide de 4 caras
	pyramid.mesh = cone
	pyramid.rotation.x = PI # Invertida

	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Emisivo / Sin sombras (brillo puro)
	mat.albedo_color = Color(1.0, 0.45, 0.0) # Naranja neon brillante / Emisivo
	pyramid.material_override = mat
	marker_pivot.add_child(pyramid)

	# 2. Etiqueta de texto estÃ¡tica separada (Hija directa del vehiculo, NO flota)
	var label = Label3D.new()
	label.name = "TextoVehiculoPrueba"
	label.text = "[ VEHICULO DE PRUEBA ]"
	label.position = Vector3(0, 2.3, 0) # Fija y separada debajo del cono
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.015
	label.modulate = Color(1.0, 0.45, 0.0) # Modulada al naranja del cono
	label.outline_modulate = Color(0, 0, 0, 1)
	label.outline_size = 12

	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	if font:
		label.font = font
	vehiculo.add_child(label) # Agregada al vehiculo, queda quieta

	# Animacion de flotacion vertical solo para la piramide (cono)
	var tw_float = get_tree().create_tween().set_loops()
	tw_float.tween_property(marker_pivot, "position:y", 3.9, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_float.tween_property(marker_pivot, "position:y", 3.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Animacion de rotacion continua solo para la piramide 3D
	var tw_rot = get_tree().create_tween().set_loops()
	tw_rot.tween_property(pyramid, "rotation:y", PI * 2, 2.5).as_relative()

func _mostrar_anuncio_pantalla(msg: String) -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "AnuncioInstruccion"
	canvas.layer = 90
	get_tree().current_scene.add_child(canvas)

	# Contenedor superior para el centrado perfecto horizontal
	var container = HBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(container)

	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_top", 140) # Push down slightly
	container.add_child(margin_container)

	var label = Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24) # Mas pequeno y limpio
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0)) # Amarillo oro
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size", 8)

	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	if font:
		label.add_theme_font_override("font", font)

	margin_container.add_child(label)

	label.modulate.a = 0.0
	var tw = get_tree().create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(4.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): canvas.queue_free())

func _ejecutar_fade_y_teleport(player: Node3D, vehicle_scene: PackedScene) -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "FadeTeleportOverlay"
	canvas.layer = 100
	get_tree().current_scene.add_child(canvas)

	var rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)

	rect.modulate.a = 0.0
	var tw = get_tree().create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.35)

	tw.tween_callback(func():
		if player and player is Node3D and teleport_target:
			player.global_transform = teleport_target.global_transform
			print("[Academia] Teletransportado en fade a: ", teleport_target.global_position)
			
		# Guardar vehiculo para controlar el inicio de la prueba
		if vehicle_scene and vehicle_spawn_marker:
			var vehicle_instance = vehicle_scene.instantiate() as Node3D
			if vehicle_instance:
				get_tree().current_scene.add_child(vehicle_instance)
				var spawn_tf = vehicle_spawn_marker.global_transform
				spawn_tf.origin.y += 0.28 # Altura natural del suelo (congelado previene hundirse)
				vehicle_instance.global_transform = spawn_tf
				if vehicle_instance is RigidBody3D:
					vehicle_instance.freeze = true
				active_test_vehicle = vehicle_instance
				_anadir_flecha_indicadora(vehicle_instance)
	)

	tw.tween_interval(0.2)
	tw.tween_property(rect, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		canvas.queue_free()
		# Restaurar modo de raton al terminar el teleport
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)

# â”€â”€ SISTEMA DE PRUEBA DE CONDUCCIÃ“N (PATH3D) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _iniciar_cinematica_prueba(player: Node3D) -> void:
	is_cinematic_running = true
	_cinematica_reproducida_una_vez = true
	
	# Congelar jugador y vehÃ­culo
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(active_test_vehicle):
		active_test_vehicle.process_mode = Node.PROCESS_MODE_DISABLED
		if "freeze" in active_test_vehicle:
			active_test_vehicle.freeze = false
		
		# Ocultar por completo la flecha indicadora y el label estÃ¡tico
		var marker_node = active_test_vehicle.get_node_or_null("MarcadorVehiculo")
		if marker_node:
			marker_node.visible = false
		var text_lbl = active_test_vehicle.get_node_or_null("TextoVehiculoPrueba")
		if text_lbl:
			text_lbl.visible = false
		
		# Conectar detector de colisiones del vehículo si es RigidBody3D
		if active_test_vehicle is RigidBody3D:
			active_test_vehicle.contact_monitor = true
			active_test_vehicle.max_contacts_reported = 4
			if not active_test_vehicle.body_entered.is_connected(_on_vehicle_collision):
				active_test_vehicle.body_entered.connect(_on_vehicle_collision)
	
	if not test_route_path or not test_route_path.curve or test_route_path.curve.point_count < 2:
		# Si no hay ruta configurada, iniciar prueba de inmediato
		_iniciar_prueba_oficial()
		return
	
	var camara_original = get_viewport().get_camera_3d()
	
	# Crear cámara cinematográfica agregada a la escena directamente
	var cine_cam = Camera3D.new()
	cine_cam.cull_mask = 4294967295
	get_tree().current_scene.add_child(cine_cam)
	cine_cam_ref = cine_cam
	cine_cam.make_current()

	# Mostrar la pista parpadeante durante la cinemática
	_crear_pista_parpadeante()

	# Crear Overlay para efecto de parpadeo lento (Fade en negro entre tomas)
	var fade_canvas = CanvasLayer.new()
	fade_canvas.name = "CineFadeOverlay"
	fade_canvas.layer = 100
	get_tree().current_scene.add_child(fade_canvas)

	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.modulate.a = 0.0
	fade_canvas.add_child(fade_rect)

	# Definir 7 tomas distribuidas dinámicamente a lo largo del Path3D
	var curve = test_route_path.curve
	var path_len = curve.get_baked_length()
	var total_tomas = 7
	
	# Ejecutar las tomas de forma secuencial
	var tw_tomas = get_tree().create_tween()
	
	for i in range(total_tomas):
		var ratio = float(i) / float(total_tomas - 1)
		var offset_dist = ratio * path_len
		var pos_path = test_route_path.to_global(curve.sample_baked(offset_dist, true))
		
		# Variar los ángulos y distancias de la cámara según la toma para vistas dinámicas en altura elevada (18m-25m para evitar colisionadores)
		var start_cam_offset = Vector3.ZERO
		var end_cam_offset = Vector3.ZERO
		
		match i % 4:
			0:
				start_cam_offset = Vector3(18.0, 22.0, 16.0)
				end_cam_offset = Vector3(14.0, 20.0, 10.0)
			1:
				start_cam_offset = Vector3(-20.0, 24.0, 12.0)
				end_cam_offset = Vector3(-15.0, 21.0, 18.0)
			2:
				start_cam_offset = Vector3(12.0, 25.0, -20.0)
				end_cam_offset = Vector3(18.0, 22.0, -14.0)
			3:
				start_cam_offset = Vector3(-16.0, 22.0, -16.0)
				end_cam_offset = Vector3(-12.0, 19.0, -10.0)
				
		var duration_toma = 1.9
		
		tw_tomas.tween_callback(func():
			if is_instance_valid(cine_cam_ref):
				# Raycast de seguridad anti-colisión: Verificamos si hay un obstáculo entre la carretera y la cámara
				var space_state = cine_cam_ref.get_world_3d().direct_space_state
				var target_start = pos_path + start_cam_offset
				var query = PhysicsRayQueryParameters3D.create(pos_path + Vector3(0, 1.5, 0), target_start)
				query.collide_with_areas = false
				var result = space_state.intersect_ray(query)
				
				if result:
					# Si hay colisión con paredes o edificios, acortamos la posición al punto del impacto con margen
					target_start = result.position - (result.position - pos_path).normalized() * 1.5
				
				cine_cam_ref.global_position = target_start
				cine_cam_ref.look_at(pos_path, Vector3.UP)
				
				# Movimiento suave de la cámara durante la toma (Traveling / Paneo)
				var move_tw = get_tree().create_tween().set_parallel(true)
				move_tw.tween_property(cine_cam_ref, "global_position", pos_path + end_cam_offset, duration_toma).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				move_tw.tween_method(func(val):
					if is_instance_valid(cine_cam_ref):
						cine_cam_ref.look_at(val, Vector3.UP)
				, pos_path, pos_path + Vector3(0, 0.5, 0), duration_toma).set_trans(Tween.TRANS_SINE)
		)
		
		# Parpadeo lento: Fade in (aparece vista)
		tw_tomas.tween_property(fade_rect, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		# Mantener la toma en movimiento continuo por el tiempo de la toma
		tw_tomas.tween_interval(duration_toma - 0.9)
		
		# Si no es la última toma, parpadeo lento hacia negro (Fade out)
		if i < total_tomas - 1:
			tw_tomas.tween_property(fade_rect, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
		else:
			# En la última toma pasar a vista aérea panorámica
			tw_tomas.tween_property(fade_rect, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)

	tw_tomas.tween_callback(func():
		fade_canvas.queue_free()
		# --- TRANSICIÓN DE VISTA GENERAL (PANORÁMICA) ---
		if is_instance_valid(cine_cam):
			var path_center = Vector3.ZERO
			if curve.point_count > 0:
				var sum = Vector3.ZERO
				for i in range(curve.point_count):
					sum += test_route_path.to_global(curve.get_point_position(i))
				path_center = sum / curve.point_count
			
			var overview_pos = path_center + Vector3(0.0, 36.0, 24.0)
			cine_cam.global_position = overview_pos
			cine_cam.look_at(path_center, Vector3.UP)
			
			# Mostrar panel estilizado con reglas
			_mostrar_panel_reglas(player, camara_original, cine_cam)
	)

func _crear_pista_parpadeante() -> void:
	_limpiar_pista_parpadeante()
	
	if not is_inside_tree() or not test_route_path or not test_route_path.is_inside_tree() or not test_route_path.curve:
		return
		
	var curve = test_route_path.curve
	var length = curve.get_baked_length()
	var step = 4.0
	var current_offset = 0.0
	
	var mat = StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.0, 0.75)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	while current_offset <= length:
		var pos = curve.sample_baked(current_offset, true)
		var global_pos = test_route_path.to_global(pos)
		
		var node = Node3D.new()
		node.name = "BalizaPista_" + str(int(current_offset))
		get_tree().current_scene.add_child(node)
		node.global_position = global_pos
		path_indicators.append(node)
		
		var mesh_inst = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 0.15
		mesh_inst.mesh = cyl
		mesh_inst.material_override = mat
		mesh_inst.position = Vector3(0, 0.075, 0)
		node.add_child(mesh_inst)
		
		current_offset += step

	path_indicators_tween = get_tree().create_tween().set_loops()
	path_indicators_tween.tween_property(mat, "albedo_color:a", 0.15, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	path_indicators_tween.tween_property(mat, "albedo_color:a", 0.75, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _limpiar_pista_parpadeante() -> void:
	if is_instance_valid(path_indicators_tween):
		path_indicators_tween.kill()
		path_indicators_tween = null
	
	for node in path_indicators:
		if is_instance_valid(node):
			node.queue_free()
	path_indicators.clear()

func _mostrar_panel_reglas(player: Node3D, camara_original: Camera3D, cine_cam: Camera3D) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var canvas = CanvasLayer.new()
	canvas.name = "RulesPanelOverlay"
	canvas.layer = 95
	add_child(canvas)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.9)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.45, 0.0, 0.8)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 50
	style.content_margin_right = 50
	style.content_margin_top = 45
	style.content_margin_bottom = 45
	panel.add_theme_stylebox_override("panel", style)

	panel.custom_minimum_size = Vector2(1100, 680)
	panel.pivot_offset = Vector2(550, 340)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "REGLAS DE LA PRUEBA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	if font:
		title.add_theme_font_override("font", font)
	vbox.add_child(title)

	var body_txt = Label.new()
	body_txt.text = "Para completar esta prueba de manejo con exito:\n\n1. Sigue el camino marcado y pasa por los 30 checkpoints naranja.\n2. No choques contra obstaculos (max. " + str(max_allowed_collisions) + " choques).\n3. No subas el vehiculo a las aceras.\n4. Respeta el limite de velocidad de " + str(int(max_speed_limit)) + " km/h.\n5. No te bajes del vehiculo de prueba."
	body_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_txt.add_theme_font_size_override("font_size", 28)
	body_txt.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	vbox.add_child(body_txt)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var btn = Button.new()
	btn.text = "COMENZAR PRUEBA"
	btn.custom_minimum_size = Vector2(0, 80)
	var btn_st = StyleBoxFlat.new()
	btn_st.bg_color = Color(1.0, 0.45, 0.0)
	btn_st.corner_radius_top_left = 12
	btn_st.corner_radius_top_right = 12
	btn_st.corner_radius_bottom_left = 12
	btn_st.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", btn_st)
	btn.add_theme_font_size_override("font_size", 32)
	if font:
		btn.add_theme_font_override("font", font)

	btn.pressed.connect(func():
		canvas.queue_free()
		_limpiar_pista_parpadeante()
		
		# Flaggear inmediatamente para que _physics_process no intente disparar en el mismo frame
		test_active = true
		is_cinematic_running = false
		
		if is_instance_valid(camara_original):
			camara_original.make_current()
		cine_cam_ref = null
		if is_instance_valid(cine_cam):
			cine_cam.queue_free()
		if is_instance_valid(player):
			player.process_mode = Node.PROCESS_MODE_INHERIT
		if is_instance_valid(active_test_vehicle):
			active_test_vehicle.process_mode = Node.PROCESS_MODE_INHERIT
		_iniciar_prueba_oficial()
	)
	vbox.add_child(btn)

	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)

func _iniciar_prueba_oficial() -> void:
	_limpiar_visual_checkpoints()
	_ocultar_advertencia_velocidad()
	_speed_warning_timer = -1.0
	collision_count = 0
	current_checkpoint_idx = 0
	speed_warning_shown = false
	is_cinematic_running = false
	
	# Activar 3.5 segundos de inmunidad para absorber la oscilación de caída del vehículo
	_inmunidad_seguridad = 3.5
	test_active = true
	
	# Descongelar la física del vehículo para que pueda rodar
	if is_instance_valid(active_test_vehicle) and "freeze" in active_test_vehicle:
		active_test_vehicle.freeze = false
	
	if not test_route_path:
		_aprobar_prueba()
		return
	
	# 1. Spawnear 30 checkpoints visuales a lo largo del Path3D
	var curve = test_route_path.curve
	var total_checkpoints = 30
	var path_length = curve.get_baked_length()
	
	for idx in range(total_checkpoints):
		var ratio = float(idx) / float(total_checkpoints - 1) if total_checkpoints > 1 else 0.0
		var dist = ratio * path_length
		var local_pos = curve.sample_baked(dist, true)
		var global_pos = test_route_path.to_global(local_pos)
		var visual_cp = _spawnear_visual_checkpoint(global_pos, idx)
		active_test_checkpoints.append({
			"position": global_pos,
			"node": visual_cp
		})
	
	# Mostrar solo el primero
	_actualizar_visibilidad_checkpoints()
	
	# 2. Crear HUD en pantalla
	_crear_hud_prueba()

	_notificar_tienda("La prueba comenzara en 5 segundos...", "info")

	# Esperar 5 segundos antes de activar la prueba y comenzar a contar choques
	await get_tree().create_timer(5.0).timeout

	test_active = true
	_notificar_tienda("Prueba iniciada. Sigue la ruta marcada!", "info")

func _spawnear_visual_checkpoint(pos: Vector3, index: int) -> Node3D:
	var visual_node = Node3D.new()
	visual_node.name = "VisualCP_" + str(index)
	var parent_node = get_tree().current_scene if get_tree() and get_tree().current_scene else self
	parent_node.add_child(visual_node)
	visual_node.global_position = pos

	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.6
	cyl.height = 3.5
	cyl.radial_segments = 16
	mesh_inst.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.0, 0.25)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0, 1.75, 0)
	visual_node.add_child(mesh_inst)

	var lbl = Label3D.new()
	lbl.text = str(index + 1)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 72
	lbl.position = Vector3(0, 3.8, 0)
	lbl.modulate = Color(1.0, 0.7, 0.0)
	lbl.outline_modulate = Color(0, 0, 0, 1)
	lbl.outline_size = 12
	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	if font:
		lbl.font = font
	visual_node.add_child(lbl)

	return visual_node

func _actualizar_visibilidad_checkpoints() -> void:
	for i in range(active_test_checkpoints.size()):
		var cp = active_test_checkpoints[i]
		if is_instance_valid(cp["node"]):
			cp["node"].visible = (i == current_checkpoint_idx)

func _avanzar_checkpoint() -> void:
	if current_checkpoint_idx < active_test_checkpoints.size():
		var cp = active_test_checkpoints[current_checkpoint_idx]
		if is_instance_valid(cp["node"]):
			cp["node"].queue_free()
	
	current_checkpoint_idx += 1
	
	# Reproducir sonido de checkpoint
	var sfx = AudioStreamPlayer.new()
	var stream = load("res://recursos/efectos/checkpoint.mp3")
	if stream:
		sfx.stream = stream
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

	if current_checkpoint_idx >= active_test_checkpoints.size():
		# Llegó al último checkpoint de la ruta
		test_active = false
		_esperando_reclamar_licencia_en_puerta = true
		_destruir_hud_prueba()
		_ocultar_advertencia_velocidad()
		
		_mostrar_anuncio_pantalla("¡CIRCUITO DE PRUEBA COMPLETADO!\nBAJATE DEL VEHÍCULO Y VE A LA PUERTA DE LA ACADEMIA PARA RECLAMAR TU LICENCIA")
		_notificar_tienda("Ruta completada! Bajate e ingresa al checkpoint de la Academia.", "exito")
	else:
		_actualizar_visibilidad_checkpoints()
		_notificar_tienda("Checkpoint completado (%d/%d)!" % [current_checkpoint_idx, active_test_checkpoints.size()], "exito")

func _on_vehicle_collision(body: Node) -> void:
	if not test_active or _inmunidad_seguridad > 0.0:
		return
	
	var body_name = body.name.to_lower()
	var is_sidewalk = "acera" in body_name or "sidewalk" in body_name or body.is_in_group("acera")

	if is_sidewalk:
		_reprobar_prueba("Subiste el vehiculo a la acera!")
	else:
		collision_count += 1
		if collision_count > max_allowed_collisions:
			_reprobar_prueba("Excediste el limite de choques permitidos!")
		else:
			_mostrar_anuncio_pantalla("¡ADVERTENCIA DE CHOQUE!\nCHOQUES: %d / %d" % [collision_count, max_allowed_collisions])
			_notificar_tienda("Choque detectado (%d/%d)" % [collision_count, max_allowed_collisions], "error")

var _reprobar_motivo: String = ""
var _dialogo_derrota_referencia: CanvasLayer = null
var _anuncios_restantes_omitir: int = 0

func _reprobar_prueba(motivo: String) -> void:
	# NO pausar todavía, dejar que los efectos corran primero
	test_active = false
	_speed_warning_timer = -1.0
	_ocultar_advertencia_velocidad()
	_destruir_hud_prueba()
	_limpiar_pista_parpadeante()

	_reprobar_motivo = motivo

	# Guardar la posición exacta del vehículo antes del fallo
	if is_instance_valid(active_test_vehicle):
		_posicion_fallo = active_test_vehicle.global_position
		_rotacion_fallo = active_test_vehicle.global_rotation
		if "linear_velocity" in active_test_vehicle:
			active_test_vehicle.linear_velocity = Vector3.ZERO
		if "angular_velocity" in active_test_vehicle:
			active_test_vehicle.angular_velocity = Vector3.ZERO

	# Lanzar secuencia de efectos dramáticos (async) y luego mostrar el diálogo
	_efecto_derrota_dramatico()

# ---- EFECTOS VISUALES DE DERROTA ----

func _efecto_derrota_dramatico() -> void:
	# Capa principal que contiene todos los efectos (SIEMPRE procesando aunque se pause)
	var fx_layer = CanvasLayer.new()
	fx_layer.name = "FXDerrota"
	fx_layer.layer = 94
	fx_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fx_layer)

	# ---- 1. DESTELLO BLANCO-ROJO instantáneo ----
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.1, 0.05, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.process_mode = Node.PROCESS_MODE_ALWAYS
	fx_layer.add_child(flash)

	var tw_flash = create_tween()
	tw_flash.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_flash.tween_property(flash, "color:a", 0.82, 0.04)
	tw_flash.tween_property(flash, "color:a", 0.0, 0.18)

	# ---- 2. SACUDIDA DE CÁMARA ----
	await get_tree().create_timer(0.05, false).timeout
	_shake_camara(0.38, 14.0, 0.95)

	# ---- 3. VIGNETTE ROJA PULSANTE (shader) ----
	var vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	fx_layer.add_child(vignette_rect)

	var vig_shader_code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.85;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 center = uv - 0.5;
	float dist = length(center) * 1.6;
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + time_offset);
	float vignette = smoothstep(0.35, 1.0, dist);
	vec4 vig_color = vec4(0.85, 0.04, 0.04, vignette * intensity * (0.75 + 0.25 * pulse));
	COLOR = vig_color;
}
"""
	var vig_shader = Shader.new()
	vig_shader.code = vig_shader_code
	var vig_mat = ShaderMaterial.new()
	vig_mat.shader = vig_shader
	vig_mat.set_shader_parameter("intensity", 0.0)
	vig_mat.set_shader_parameter("pulse_speed", 4.0)
	vignette_rect.material = vig_mat

	# Animar intensidad: aparece rápido, se mantiene, desvanece
	var tw_vig = create_tween()
	tw_vig.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_vig.tween_method(func(v: float): vig_mat.set_shader_parameter("intensity", v), 0.0, 0.92, 0.12)
	tw_vig.tween_interval(0.55)
	tw_vig.tween_method(func(v: float): vig_mat.set_shader_parameter("intensity", v), 0.92, 0.40, 0.55)

	# ---- 4. TEXTO "REPROBADO" GIGANTE que aparece y desvanece ----
	var big_lbl_ctrl = Control.new()
	big_lbl_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_lbl_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	fx_layer.add_child(big_lbl_ctrl)

	var big_lbl = Label.new()
	big_lbl.text = "REPROBADO"
	var big_font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	if big_font:
		big_lbl.add_theme_font_override("font", big_font)
	big_lbl.add_theme_font_size_override("font_size", 110)
	big_lbl.add_theme_color_override("font_color", Color(1.0, 0.08, 0.05, 0.0))
	big_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_lbl.pivot_offset = Vector2(960, 540)
	big_lbl_ctrl.add_child(big_lbl)

	# Shader de distorsión glitch en el texto grande
	var glitch_shader_code = """
shader_type canvas_item;

uniform float glitch_amount : hint_range(0.0, 0.05) = 0.012;
uniform float time_seed = 0.0;

void fragment() {
	vec2 uv = UV;
	float noise = fract(sin(dot(uv + time_seed, vec2(127.1, 311.7))) * 43758.5453);
	if (noise > 0.92) {
		uv.x += (noise - 0.92) * glitch_amount * 80.0;
	}
	COLOR = texture(TEXTURE, uv);
}
"""
	var glitch_shader = Shader.new()
	glitch_shader.code = glitch_shader_code
	var glitch_mat = ShaderMaterial.new()
	glitch_mat.shader = glitch_shader
	big_lbl.material = glitch_mat

	var tw_txt = create_tween().set_parallel(true)
	tw_txt.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_txt.tween_property(big_lbl, "theme_override_colors/font_color", Color(1.0, 0.08, 0.05, 0.90), 0.10)
	tw_txt.tween_property(big_lbl, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_EXPO)

	# Animación de glitch en el seed
	var glitch_tw = create_tween()
	glitch_tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	glitch_tw.tween_method(func(v: float): glitch_mat.set_shader_parameter("time_seed", v), 0.0, 99.0, 0.80)

	await get_tree().create_timer(0.38, false).timeout

	var tw_txt2 = create_tween().set_parallel(true)
	tw_txt2.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_txt2.tween_property(big_lbl, "theme_override_colors/font_color", Color(1.0, 0.08, 0.05, 0.0), 0.45)
	tw_txt2.tween_property(big_lbl, "scale", Vector2(1.35, 1.35), 0.45).set_trans(Tween.TRANS_EXPO)

	await get_tree().create_timer(0.55, false).timeout

	# ---- 5. FADE A NEGRO suave antes del diálogo ----
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	fx_layer.add_child(fade_rect)

	var tw_fade = create_tween()
	tw_fade.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_fade.tween_property(fade_rect, "color:a", 0.88, 0.32)
	await tw_fade.finished

	# Pausar ahora que la pantalla ya está cubierta
	get_tree().paused = true

	# Mostrar el diálogo (que tiene process_mode ALWAYS)
	_mostrar_dialogo_derrota(fx_layer)

	# Desvanecer el FX layer progresivamente (el diálogo ya se ve debajo)
	var tw_fade2 = create_tween()
	tw_fade2.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_fade2.tween_property(fade_rect, "color:a", 0.0, 0.50)
	var tw_vig2 = create_tween()
	tw_vig2.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_vig2.tween_method(func(v: float): vig_mat.set_shader_parameter("intensity", v), 0.40, 0.28, 0.80)

func _shake_camara(duracion: float, magnitud: float, amortiguacion: float) -> void:
	var cameras = get_tree().get_nodes_in_group("jugador")
	var camera: Camera3D = null
	for c in cameras:
		camera = c.get_node_or_null("Camera3D") as Camera3D
		if not camera:
			camera = c.find_child("Camera3D", true, false) as Camera3D
		if camera:
			break
	
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var original_v_offset = camera.v_offset
	var original_h_offset = camera.h_offset
	var elapsed: float = 0.0
	var mag = magnitud

	while elapsed < duracion:
		elapsed += get_process_delta_time()
		mag *= amortiguacion
		camera.h_offset = original_h_offset + randf_range(-mag, mag) * 0.018
		camera.v_offset = original_v_offset + randf_range(-mag, mag) * 0.018
		await get_tree().process_frame

	camera.h_offset = original_h_offset
	camera.v_offset = original_v_offset

func _efecto_glitch_label(lbl: Label, duracion: float) -> void:
	var original = lbl.text
	var chars = "#@!%&?X*-■"
	var rng = RandomNumberGenerator.new()
	var elapsed := 0.0
	while elapsed < duracion:
		elapsed += get_process_delta_time()
		var glitched = ""
		for i in original.length():
			if rng.randf() < 0.18:
				glitched += chars[rng.randi() % chars.length()]
			else:
				glitched += original[i]
		lbl.text = glitched
		await get_tree().process_frame
	lbl.text = original


func _teleportar_y_reiniciar_vehiculo() -> void:
	# Descongelar el árbol
	get_tree().paused = false

	# Resetear contadores de la prueba
	collision_count = 0
	current_checkpoint_idx = 0
	_speed_warning_timer = -1.0
	_ocultar_advertencia_velocidad()
	_limpiar_visual_checkpoints()

	# Mover el vehículo al punto de spawn (el jugador sigue adentro)
	if is_instance_valid(active_test_vehicle) and vehicle_spawn_marker:
		var spawn_tf = vehicle_spawn_marker.global_transform
		spawn_tf.origin.y += 0.35
		active_test_vehicle.global_transform = spawn_tf
		if "linear_velocity" in active_test_vehicle:
			active_test_vehicle.linear_velocity = Vector3.ZERO
		if "angular_velocity" in active_test_vehicle:
			active_test_vehicle.angular_velocity = Vector3.ZERO
		if active_test_vehicle is RigidBody3D:
			active_test_vehicle.freeze = false

	# Reactivar la prueba con inmunidad inicial
	_inmunidad_seguridad = 3.0
	test_active = true
	_actualizar_visibilidad_checkpoints()
	_crear_hud_prueba()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func _mostrar_dialogo_derrota(fx_layer: CanvasLayer = null) -> void:
	_cerrar_dialogo_derrota()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Usar el FX layer si se pasó, o crear uno nuevo
	var canvas: CanvasLayer
	if is_instance_valid(fx_layer):
		canvas = fx_layer
		canvas.name = "DialogoDerrota"
	else:
		canvas = CanvasLayer.new()
		canvas.name = "DialogoDerrota"
		canvas.layer = 95
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(canvas)
	_dialogo_derrota_referencia = canvas

	# Fondo oscuro difuminado
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.0, 0.0, 0.0, 0.75)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(bg_rect)

	# Contenedor centrador
	var center_ctn = CenterContainer.new()
	center_ctn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_ctn.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(center_ctn)

	# Panel Principal Glassmorphic
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.20, 0.10, 0.90)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.95, 0.10, 0.10, 0.40)
	style.shadow_size = 35
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(860, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	center_ctn.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	# --- Franja roja superior de acento ---
	var accent_bar = ColorRect.new()
	accent_bar.color = Color(0.95, 0.15, 0.10, 0.85)
	accent_bar.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(accent_bar)

	# --- Título ---
	var icon_lbl = Label.new()
	icon_lbl.text = "✕  PRUEBA REPROBADA  ✕"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.add_theme_color_override("font_color", Color(1.00, 0.25, 0.15))
	if font:
		icon_lbl.add_theme_font_override("font", font)
	vbox.add_child(icon_lbl)

	# --- Motivo del fallo ---
	var motivo_lbl = Label.new()
	motivo_lbl.text = _reprobar_motivo
	motivo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motivo_lbl.add_theme_font_size_override("font_size", 22)
	motivo_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.80))
	motivo_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font:
		motivo_lbl.add_theme_font_override("font", font)
	vbox.add_child(motivo_lbl)

	# --- Tarjeta de estadísticas ---
	var stats_panel = PanelContainer.new()
	var stats_style = StyleBoxFlat.new()
	stats_style.bg_color = Color(0.12, 0.05, 0.05, 0.80)
	stats_style.border_color = Color(0.90, 0.20, 0.10, 0.40)
	stats_style.border_width_left = 1
	stats_style.border_width_top = 1
	stats_style.border_width_right = 1
	stats_style.border_width_bottom = 1
	stats_style.corner_radius_top_left = 10
	stats_style.corner_radius_top_right = 10
	stats_style.corner_radius_bottom_left = 10
	stats_style.corner_radius_bottom_right = 10
	stats_style.content_margin_left = 20
	stats_style.content_margin_right = 20
	stats_style.content_margin_top = 10
	stats_style.content_margin_bottom = 10
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	vbox.add_child(stats_panel)

	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 40)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_panel.add_child(stats_hbox)

	var _add_stat = func(label_txt: String, value_txt: String, color: Color):
		var col = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var lbl_val = Label.new()
		lbl_val.text = value_txt
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_val.add_theme_font_size_override("font_size", 28)
		lbl_val.add_theme_color_override("font_color", color)
		if font: lbl_val.add_theme_font_override("font", font)
		col.add_child(lbl_val)
		var lbl_key = Label.new()
		lbl_key.text = label_txt
		lbl_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_key.add_theme_font_size_override("font_size", 16)
		lbl_key.add_theme_color_override("font_color", Color(0.75, 0.65, 0.65))
		if font: lbl_key.add_theme_font_override("font", font)
		col.add_child(lbl_key)
		stats_hbox.add_child(col)

	_add_stat.call("CHECKPOINT", "%d / %d" % [current_checkpoint_idx, active_test_checkpoints.size() if active_test_checkpoints.size() > 0 else 30], Color(1.0, 0.80, 0.20))
	_add_stat.call("CHOQUES", "%d / %d" % [collision_count, max_allowed_collisions], Color(1.0, 0.35, 0.15))

	# --- Botones de acción organizados ---
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_vbox)

	# Botón Principal: Reiniciar
	btn_vbox.add_child(_crear_boton_derrota(
		"REINICIAR PRUEBA",
		"Vuelve al principio del circuito",
		Color(0.15, 0.75, 0.30), false, font, 0,
		func():
			_cerrar_dialogo_derrota()
			_teleportar_y_reiniciar_vehiculo()
	))

	# Fila Secundaria: 2 columnas balanceadas
	var hbox_extra = HBoxContainer.new()
	hbox_extra.add_theme_constant_override("separation", 10)
	hbox_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_vbox.add_child(hbox_extra)

	var btn_cont = _crear_boton_derrota(
		"CONTINUAR DESDE AQUÍ",
		"Reanuda en este punto",
		Color(0.15, 0.55, 0.95), true, font, 1,
		func():
			_cerrar_dialogo_derrota()
			_mostrar_anuncio_recompensado(1)
	)
	btn_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_extra.add_child(btn_cont)

	var btn_skip = _crear_boton_derrota(
		"SALTAR PRUEBA",
		"Obtén la licencia directo",
		Color(1.0, 0.48, 0.0), true, font, 1,
		func():
			_cerrar_dialogo_derrota()
			_anuncios_restantes_omitir = 1
			_mostrar_anuncio_recompensado(2)
	)
	btn_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_extra.add_child(btn_skip)

	# ---- ANIMACIÓN DE ENTRADA SUAVE (Tween scale/alpha 0.35s) ----
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	var tw_in = create_tween().set_parallel(true)
	tw_in.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tw_in.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

# Crea un botón de acción de derrota con feedback interactivo
func _crear_boton_derrota(
		titulo: String,
		subtitulo: String,
		color: Color,
		con_anuncio: bool,
		font: FontFile,
		num_anuncios: int,
		callback: Callable
	) -> Control:

	var root = Control.new()
	root.custom_minimum_size = Vector2(0, 62)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var st = StyleBoxFlat.new()
	st.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.92)
	st.border_width_left = 0
	st.border_width_top = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	st.border_color = Color(color.r, color.g, color.b, 0.65)
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", st)
	root.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(hbox)

	# Accent bar
	var accent = ColorRect.new()
	accent.color = Color(color.r, color.g, color.b, 1.0)
	accent.custom_minimum_size = Vector2(6, 0)
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	accent.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(accent)

	# Left padding
	var pad_l = Control.new()
	pad_l.custom_minimum_size = Vector2(14, 0)
	pad_l.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(pad_l)

	# VBox texts
	var texts = VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(texts)

	var lbl_t = Label.new()
	lbl_t.text = titulo
	lbl_t.add_theme_font_size_override("font_size", 20)
	lbl_t.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lbl_t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_t.mouse_filter = Control.MOUSE_FILTER_PASS
	if font: lbl_t.add_theme_font_override("font", font)
	texts.add_child(lbl_t)

	var lbl_s = Label.new()
	lbl_s.text = subtitulo
	lbl_s.add_theme_font_size_override("font_size", 13)
	lbl_s.add_theme_color_override("font_color", Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.9).clamp())
	lbl_s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_s.mouse_filter = Control.MOUSE_FILTER_PASS
	if font: lbl_s.add_theme_font_override("font", font)
	texts.add_child(lbl_s)

	# Ads icons
	if con_anuncio:
		var ad_tex: Texture2D = load("res://recursos/botones/anuncio.png")
		var ad_ctn = HBoxContainer.new()
		ad_ctn.alignment = BoxContainer.ALIGNMENT_CENTER
		ad_ctn.add_theme_constant_override("separation", 2)
		ad_ctn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ad_ctn.mouse_filter = Control.MOUSE_FILTER_PASS
		hbox.add_child(ad_ctn)
		var cantidad_iconos = min(num_anuncios, 1) # Máximo 1 icono de anuncio por botón
		for _i in range(cantidad_iconos):
			var tr = TextureRect.new()
			tr.texture = ad_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(32, 32)
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tr.mouse_filter = Control.MOUSE_FILTER_PASS
			ad_ctn.add_child(tr)

	# Right padding
	var pad_r = Control.new()
	pad_r.custom_minimum_size = Vector2(12, 0)
	pad_r.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(pad_r)

	# Button element
	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.text = ""
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var empty = StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(s, empty)
	btn.pressed.connect(callback)

	# Feedback interactivo (hover y click)
	btn.mouse_entered.connect(func():
		var tw = root.create_tween()
		tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		tw.tween_property(root, "scale", Vector2(1.02, 1.02), 0.10)
		st.border_color = Color(color.r, color.g, color.b, 1.0)
	)
	btn.mouse_exited.connect(func():
		var tw = root.create_tween()
		tw.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		tw.tween_property(root, "scale", Vector2.ONE, 0.10)
		st.border_color = Color(color.r, color.g, color.b, 0.65)
	)
	btn.button_down.connect(func():
		root.scale = Vector2(0.98, 0.98)
	)
	btn.button_up.connect(func():
		root.scale = Vector2(1.02, 1.02)
	)

	root.add_child(btn)
	return root

func account_label_color(lbl: Label, color: Color) -> void:
	lbl.add_theme_color_override("font_color", color)

func _cerrar_dialogo_derrota() -> void:
	# Asegurar despausar el juego al continuar si la escena está activa
	if is_inside_tree() and get_tree():
		get_tree().paused = false
	
	if is_instance_valid(_dialogo_derrota_referencia):
		_dialogo_derrota_referencia.queue_free()
		_dialogo_derrota_referencia = null
	if not is_instance_valid(dialogue_ui) and not test_active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _mostrar_anuncio_recompensado(tipo: int) -> void:
	_admob_active_reward_type = tipo
	_admob_reward_granted = false
	
	# Usar Poing Studios AdMob v5.0.0 si está disponible
	var has_ad_node = (is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("RewardedAdLoader"))
	if ClassDB.class_exists("RewardedAdLoader") or has_ad_node:
		var ad_unit_id := _obtener_rewarded_ad_unit_id()
		if ad_unit_id.is_empty():
			push_error("[Academia] Falta configurar el ID recompensado de AdMob para Android.")
			_notificar_tienda("Los anuncios aun no estan configurados.", "error")
			return
		_notificar_tienda("Cargando anuncio AdMob v5...", "info")
		var loader = RewardedAdLoader.new()
		var load_cb = RewardedAdLoadCallback.new()
		load_cb.on_ad_loaded = func(ad: RewardedAd) -> void:
			var show_cb = FullScreenContentCallback.new()
			show_cb.on_ad_dismissed_full_screen_content = func() -> void:
				if ad: ad.destroy()
			show_cb.on_ad_failed_to_show_full_screen_content = func(_err) -> void:
				if ad: ad.destroy()
			ad.full_screen_content_callback = show_cb
			
			var reward_cb = OnUserEarnedRewardListener.new()
			reward_cb.on_user_earned_reward = func(_item) -> void:
				_otorgar_recompensa_admob(tipo)
			ad.show(reward_cb)
			
		load_cb.on_ad_failed_to_load = func(err) -> void:
			print("[Academia] AdMob v5 ad failed: ", err)
			_notificar_tienda("No se pudo cargar el anuncio. Intenta de nuevo.", "error")
			
		loader.load(ad_unit_id, AdRequest.new(), load_cb)
		return
	
	if is_instance_valid(_admob_instance):
		_notificar_tienda("Cargando anuncio AdMob...", "info")
		_admob_instance.call("load_rewarded_ad")
		return
	
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		# El bypass solo existe en escritorio; nunca otorga una recompensa por fallos móviles.
		_notificar_tienda("Iniciando bypass de desarrollo offline...", "info")
		await get_tree().create_timer(1.2, false).timeout
		_otorgar_recompensa_admob(tipo)
		return

	_notificar_tienda("El anuncio no esta disponible en este dispositivo.", "error")

func _obtener_rewarded_ad_unit_id() -> String:
	var setting_name := "nuestra_tierra/admob/rewarded_unit_id_android"
	if OS.get_name() == "iOS":
		setting_name = "nuestra_tierra/admob/rewarded_unit_id_ios"
	if ProjectSettings.has_setting(setting_name):
		var configured_id := str(ProjectSettings.get_setting(setting_name)).strip_edges()
		if not configured_id.is_empty():
			return configured_id
	if OS.get_name() == "Android" and OS.is_debug_build():
		return "ca-app-pub-3940256099942544/5224354917"
	if OS.get_name() == "iOS" and OS.is_debug_build():
		return "ca-app-pub-3940256099942544/1712485313"
	return ""

func _otorgar_recompensa_admob(tipo: int) -> void:
	if _admob_reward_granted:
		return
	_admob_reward_granted = true
	_procesar_recompensa_anuncio(tipo)

func _procesar_recompensa_anuncio(tipo: int) -> void:
	if tipo == 1:
		# Seguir desde donde perdio - Reposicionar vehiculo en el sitio del fallo
		if is_instance_valid(active_test_vehicle):
			# Elevar levemente sobre el suelo en el mismo punto de la carretera
			active_test_vehicle.global_position = _posicion_fallo + Vector3(0, 0.8, 0)
			active_test_vehicle.global_rotation = _rotacion_fallo
			
			if "linear_velocity" in active_test_vehicle:
				active_test_vehicle.linear_velocity = Vector3.ZERO
			if "angular_velocity" in active_test_vehicle:
				active_test_vehicle.angular_velocity = Vector3.ZERO
			
			# Re-activar detector de colisiones nativo
			if active_test_vehicle is RigidBody3D:
				active_test_vehicle.contact_monitor = true
				active_test_vehicle.max_contacts_reported = 4

		# Re-activar la prueba e inmunidad inicial
		_inmunidad_seguridad = 3.5
		test_active = true
		
		# Forzar que el HUD de la prueba se re-cree
		_crear_hud_prueba()
		
		# Asegurar que las paradas y checkpoints visuales reflejen la posición actual
		_actualizar_visibilidad_checkpoints()

		_notificar_tienda("Continua la prueba desde donde estabas!", "exito")

	elif tipo == 2:
		_anuncios_restantes_omitir -= 1
		if _anuncios_restantes_omitir <= 0:
			test_active = false
			_esperando_reclamar_licencia_en_puerta = true
			_destruir_hud_prueba()
			_ocultar_advertencia_velocidad()
			_limpiar_visual_checkpoints()
			_limpiar_pista_parpadeante()

			_mostrar_anuncio_pantalla("¡PRUEBA OMITIDA CON ÉXITO!\nBÁJATE DEL VEHÍCULO Y VE A LA PUERTA DE LA ACADEMIA PARA RECLAMAR TU LICENCIA")
			_notificar_tienda("Prueba omitida! Bájate del vehículo e ingresa a la puerta de la Academia para reclamar tu licencia.", "exito")
		else:
			_notificar_tienda("Anuncio completado! Te faltan " + str(_anuncios_restantes_omitir) + " anuncios.", "info")
			_mostrar_anuncio_recompensado(2)

func _aprobar_prueba() -> void:
	test_active = false
	_esperando_reclamar_licencia_en_puerta = false
	_ocultar_advertencia_velocidad()
	_destruir_hud_prueba()
	_limpiar_visual_checkpoints()
	_limpiar_pista_parpadeante()

	# 1. Bajar al jugador del vehículo llamando a su método oficial de bajada
	if is_instance_valid(active_test_vehicle):
		var v_ref = active_test_vehicle
		active_test_vehicle = null
		
		if v_ref.has_method("bajar_jugador"):
			v_ref.call("bajar_jugador")
		
		# Eliminar el vehículo en diferido para que el script de vehículo complete la devolución del jugador
		v_ref.call_deferred("queue_free")

	# 2. Conceder licencia y guardar los datos
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.call("completar_mision_licencia")
		if datos.has_method("save_local"):
			datos.call("save_local")
		print("[Academia] Licencia otorgada y DatosUsuario guardados exitosamente.")

	_mostrar_dialogo_felicitaciones()

func _mostrar_dialogo_felicitaciones() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var canvas = CanvasLayer.new()
	canvas.name = "DialogoFelicitaciones"
	canvas.layer = 96
	add_child(canvas)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.92) # Glassmorphic
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.20, 0.80, 0.40, 0.90) # Verde Neón de éxito
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.20, 0.80, 0.40, 0.25)
	style.shadow_size = 40
	style.content_margin_left = 50
	style.content_margin_right = 50
	style.content_margin_top = 45
	style.content_margin_bottom = 45
	panel.add_theme_stylebox_override("panel", style)

	panel.custom_minimum_size = Vector2(1100, 680)
	panel.pivot_offset = Vector2(550, 340)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)

	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile

	var title = Label.new()
	title.text = "¡FELICITACIONES!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.20, 0.80, 0.40))
	if font:
		title.add_theme_font_override("font", font)
	vbox.add_child(title)

	var sub_title = Label.new()
	sub_title.text = "HAS ADQUIRIDO LA LICENCIA"
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_title.add_theme_font_size_override("font_size", 36)
	sub_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0)) # Dorado brillante
	if font:
		sub_title.add_theme_font_override("font", font)
	vbox.add_child(sub_title)

	var body_txt = Label.new()
	body_txt.text = "Has superado con exito los 30 checkpoints de la prueba de conduccion.\n\nAhora tienes el permiso legal para operar este tipo de vehiculo en todas las vias del pais."
	body_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_txt.add_theme_font_size_override("font_size", 28)
	body_txt.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	body_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body_txt)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn = Button.new()
	btn.text = "ACEPTAR"
	btn.custom_minimum_size = Vector2(0, 80)
	var btn_st = StyleBoxFlat.new()
	btn_st.bg_color = Color(0.20, 0.80, 0.40, 0.85)
	btn_st.corner_radius_top_left = 12
	btn_st.corner_radius_top_right = 12
	btn_st.corner_radius_bottom_left = 12
	btn_st.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", btn_st)
	
	var btn_st_hover = btn_st.duplicate() as StyleBoxFlat
	btn_st_hover.bg_color = Color(0.25, 0.90, 0.45, 1.0)
	btn.add_theme_stylebox_override("hover", btn_st_hover)
	
	btn.add_theme_font_size_override("font_size", 32)
	if font:
		btn.add_theme_font_override("font", font)

	btn.pressed.connect(func():
		canvas.queue_free()
		_notificar_tienda("Licencia otorgada exitosamente.", "exito")
	)
	vbox.add_child(btn)

	# Reproducir sonido de premio / éxito
	var sfx = AudioStreamPlayer.new()
	var money_stream = load("res://recursos/efectos/money.mp3")
	if money_stream:
		sfx.stream = money_stream
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

	# Animación de entrada suave Tween
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.30)

# Limpiar marcadores y desvincular vehÃ­culo
	if is_instance_valid(active_test_vehicle):
		var label = active_test_vehicle.get_node_or_null("TextoVehiculoPrueba")
		if label: label.queue_free()
		var marker = active_test_vehicle.get_node_or_null("MarcadorVehiculo")
		if marker: marker.queue_free()
		active_test_vehicle = null

func _crear_hud_prueba() -> void:
	_destruir_hud_prueba()

	var canvas = CanvasLayer.new()
	canvas.name = "HUDPruebaConduccion"
	canvas.layer = 90
	add_child(canvas)
	dot_hud_parent(canvas)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	canvas.add_child(margin)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.45, 0.0, 0.6)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "PRUEBA EN CURSO"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
	if font:
		title.add_theme_font_override("font", font)
	vbox.add_child(title)

	var cp_lbl = Label.new()
	cp_lbl.name = "CheckpointLabel"
	cp_lbl.text = "Ruta: %d / %d" % [current_checkpoint_idx, active_test_checkpoints.size()]
	cp_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(cp_lbl)

	var col_lbl = Label.new()
	col_lbl.name = "CollisionLabel"
	col_lbl.text = "Choques: %d / %d" % [collision_count, max_allowed_collisions]
	col_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(col_lbl)

	var spd_lbl = Label.new()
	spd_lbl.name = "SpeedLabel"
	spd_lbl.text = "Velocidad: 0 km/h"
	spd_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(spd_lbl)

func dot_hud_parent(canvas: CanvasLayer) -> void:
	test_hud = canvas

func _actualizar_hud_prueba(speed_kmh: float) -> void:
	if not test_hud:
		return
	
	var cp_lbl = test_hud.find_child("CheckpointLabel", true, false) as Label
	if cp_lbl:
		cp_lbl.text = "Ruta: %d / %d" % [current_checkpoint_idx, active_test_checkpoints.size()]
	
	var col_lbl = test_hud.find_child("CollisionLabel", true, false) as Label
	if col_lbl:
		col_lbl.text = "Choques: %d / %d" % [collision_count, max_allowed_collisions]
	
	var spd_lbl = test_hud.find_child("SpeedLabel", true, false) as Label
	if spd_lbl:
		spd_lbl.text = "Velocidad: %d km/h" % int(speed_kmh)
		if speed_kmh > max_speed_limit:
			spd_lbl.add_theme_color_override("font_color", Color.RED)
		else:
			spd_lbl.add_theme_color_override("font_color", Color.WHITE)

func _destruir_hud_prueba() -> void:
	if is_instance_valid(test_hud):
		test_hud.queue_free()
		test_hud = null

func _limpiar_visual_checkpoints() -> void:
	for cp in active_test_checkpoints:
		if is_instance_valid(cp["node"]):
			cp["node"].queue_free()
	active_test_checkpoints.clear()

func _mostrar_o_actualizar_advertencia_velocidad(tiempo_restante: float) -> void:
	var seg = int(ceil(max(0.0, tiempo_restante)))
	var texto_msg = "¡EXCESO DE VELOCIDAD!\nREDUCE A MENOS DE %d KM/H EN %d S O PERDERÁS LA PRUEBA" % [int(max_speed_limit), seg]

	if not is_instance_valid(_speed_warning_canvas):
		var canvas = CanvasLayer.new()
		canvas.name = "AdvertenciaVelocidadCanvas"
		canvas.layer = 92
		get_tree().current_scene.add_child(canvas)
		_speed_warning_canvas = canvas

		var container = HBoxContainer.new()
		container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		container.alignment = BoxContainer.ALIGNMENT_CENTER
		canvas.add_child(container)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_top", 120)
		container.add_child(margin)

		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.85, 0.1, 0.1, 0.90)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.0, 0.9, 0.0, 0.9)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.content_margin_left = 30
		style.content_margin_right = 30
		style.content_margin_top = 20
		style.content_margin_bottom = 20
		panel.add_theme_stylebox_override("panel", style)
		margin.add_child(panel)

		var label = Label.new()
		label.name = "LabelVelocidadAdvertencia"
		label.text = texto_msg
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color.WHITE)
		var font = load("res://recursos/fonts/Moderniz.otf") as FontFile
		if font:
			label.add_theme_font_override("font", font)
		panel.add_child(label)
	else:
		var label = _speed_warning_canvas.find_child("LabelVelocidadAdvertencia", true, false) as Label
		if label:
			label.text = texto_msg

func _ocultar_advertencia_velocidad() -> void:
	if is_instance_valid(_speed_warning_canvas):
		_speed_warning_canvas.queue_free()
		_speed_warning_canvas = null
