extends Node3D

# puerta_santamaria.gd
# Este script se encarga de controlar la puerta de bodega (tipo Santamaría) ejecutando
# la animación "gartentor" del Skeleton/AnimationPlayer asociado a la malla.
# Incluye detección por proximidad usando un mesh sensor y muestra un botón interactivo
# premium para abrirla. Al terminar la animación, espera 10 segundos y se cierra en reversa.

@export_group("Configuracion")
## Activar mensajes de depuración en la consola
@export var debug: bool = true
## Nombre de la animación a reproducir
@export var nombre_animacion: String = "gartentor"
## Tiempo de espera antes de que la puerta se cierre sola (en segundos)
@export var tiempo_espera_cierre: float = 10.0
## Radio de proximidad del sensor (en metros)
@export var radio_deteccion: float = 3.5

@export_group("Nodos de Referencia")
## El mesh que actúa como sensor. Si se deja vacío, se buscará un hijo llamado "sensor".
@export var sensor_mesh: Node3D
## El AnimationPlayer que contiene la animación. Si se deja vacío, se buscará automáticamente.
@export var anim_player: AnimationPlayer

# Estado interno
var _area_sensor: Area3D
var _jugador_cerca: bool = false
var _animacion_reproduciendo: bool = false
var _puerta_abierta: bool = false

# UI
var _canvas_ui: CanvasLayer
var _boton_abrir: Button

# Efectos visuales de Sensor
var _material_sensor: StandardMaterial3D
var _label_3d: Label3D
var _tiempo_acumulado: float = 0.0

func _init() -> void:
	print("[Santamaria] SCRIPT INSTANCIADO EN MEMORIA")

func _ready() -> void:
	print("[Santamaria] _ready() ejecutado. Nodo: ", name, " | Ruta: ", get_path())

	# 1. Encontrar el AnimationPlayer
	if not anim_player:
		anim_player = _find_animation_player()
	
	if anim_player:
		print("[Santamaria] AnimationPlayer encontrado: ", anim_player.get_path())
		# Conectar la señal de animación finalizada
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
	else:
		printerr("[Santamaria] ERROR: No se encontró ningún AnimationPlayer en la escena.")

	# 2. Encontrar el Mesh del Sensor
	if not sensor_mesh:
		sensor_mesh = find_child("sensor", true, false) as Node3D
		if not sensor_mesh:
			sensor_mesh = find_child("Sensor", true, false) as Node3D
			
	if not sensor_mesh:
		print("[Santamaria] No se encontró mesh 'sensor'. Usando el origen del nodo actual.")
		sensor_mesh = self
	else:
		print("[Santamaria] Mesh del Sensor configurado: ", sensor_mesh.name, " | Posición global: ", sensor_mesh.global_position)

	# 3. Crear el Area3D del Sensor
	_crear_area_sensor()
	
	# 4. Crear la UI del botón
	_crear_interfaz_ui()
	
	# 5. Aplicar efectos visuales al sensor
	_preparar_efectos_sensor()

func _find_animation_player() -> AnimationPlayer:
	# Buscar en los hijos
	var ap = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		return ap
	
	# Buscar en el nodo padre o sus ancestros
	var parent = get_parent()
	while parent:
		ap = parent.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			return ap
		parent = parent.get_parent()
	return null

func _crear_area_sensor() -> void:
	if not sensor_mesh:
		return
		
	_area_sensor = Area3D.new()
	_area_sensor.name = "AreaSensorSantamaria"
	_area_sensor.collision_layer = 0
	_area_sensor.collision_mask = 0xFFFFFFFF # Detectar cualquier capa
	sensor_mesh.add_child(_area_sensor)
	
	var col_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radio_deteccion
	col_shape.shape = sphere
	_area_sensor.add_child(col_shape)
	
	# Conectar señales
	_area_sensor.body_entered.connect(_on_sensor_body_entered)
	_area_sensor.body_exited.connect(_on_sensor_body_exited)
	
	print("[Santamaria] Area3D autogenerada alrededor de ", sensor_mesh.name, " con radio de ", radio_deteccion, "m")

func _preparar_efectos_sensor() -> void:
	if not sensor_mesh:
		return
		
	# A) Crear material emisor dinámico para el mesh del sensor
	_material_sensor = StandardMaterial3D.new()
	_material_sensor.albedo_color = Color(0.08, 0.12, 0.2) # Base oscura metálica
	_material_sensor.metallic = 1.0
	_material_sensor.roughness = 0.15
	_material_sensor.emission_enabled = true
	_material_sensor.emission = Color(0.0, 0.6, 1.0) # Brillo celeste de base
	_material_sensor.emission_energy_multiplier = 1.0
	
	if sensor_mesh is MeshInstance3D:
		sensor_mesh.set_surface_override_material(0, _material_sensor)
		
	# B) Crear una Label3D flotante sobre el sensor
	_label_3d = Label3D.new()
	_label_3d.name = "SensorLabel3D"
	_label_3d.text = "[ BODEGA ]\nPRESIONA ABRIR"
	_label_3d.font_size = 22 # Texto un poco más pequeño
	_label_3d.outline_size = 8
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED # Billboard habilitado (siempre de cara a la cámara)
	_label_3d.no_depth_test = true # Evitar que se mezcle o tape con las paredes
	_label_3d.position = Vector3(0, 1.2, 0) # 1.2 metros sobre el sensor
	
	# Colores iniciales transparentes (haremos fade-in)
	_label_3d.modulate = Color(0.0, 0.8, 1.0, 0.0)
	_label_3d.outline_modulate = Color(0.02, 0.1, 0.2, 0.0)
	
	# Cargar fuente personalizada si existe
	var font_path_override = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path_override):
		var custom_font = load(font_path_override)
		if custom_font:
			_label_3d.font = custom_font
			
	sensor_mesh.add_child(_label_3d)

func _process(delta: float) -> void:
	# Manejar pulsaciones de brillo y desvanecimiento de etiquetas
	_tiempo_acumulado += delta
	
	# Modulación de brillo en el material del sensor (pulso rápido si está cerca, lento si no)
	if _material_sensor:
		var freq = 5.0 if _jugador_cerca else 2.0
		var energy_min = 0.8 if _jugador_cerca else 0.3
		var energy_max = 2.2 if _jugador_cerca else 0.9
		var pulse = (sin(_tiempo_acumulado * freq) + 1.0) * 0.5
		_material_sensor.emission_energy_multiplier = lerp(energy_min, energy_max, pulse)
		
		# Cambiar color de emisión basado en si está reproduciendo animación
		if _animacion_reproduciendo:
			_material_sensor.emission = Color(1.0, 0.5, 0.0) # Naranja mientras se mueve
		elif _puerta_abierta:
			_material_sensor.emission = Color(0.1, 0.9, 0.1) # Verde si está abierta
		else:
			_material_sensor.emission = Color(0.0, 0.6, 1.0) # Azul si está cerrada y lista
			
	# Transición suave (fade in/out) del Label3D
	if _label_3d:
		var target_alpha = 1.0 if _jugador_cerca else 0.0
		
		# Ajustar el texto dinámicamente según el estado de la puerta (sin tildes)
		if _animacion_reproduciendo:
			if _puerta_abierta:
				_label_3d.text = "[ BODEGA ]\nCERRANDO..."
			else:
				_label_3d.text = "[ BODEGA ]\nABRIENDO..."
		elif _puerta_abierta:
			# El texto del contador se maneja dinámicamente en _on_animation_finished
			pass
		else:
			_label_3d.text = "[ BODEGA ]\nPRESIONA ABRIR"
			
		# Interpolación de color y opacidad
		var c_mod = _label_3d.modulate
		var c_out = _label_3d.outline_modulate
		
		c_mod.a = move_toward(c_mod.a, target_alpha, delta * 3.0)
		c_out.a = move_toward(c_out.a, target_alpha, delta * 3.0)
		
		# Color del texto dinámico
		if _animacion_reproduciendo:
			c_mod.r = 1.0; c_mod.g = 0.5; c_mod.b = 0.0 # Naranja
		elif _puerta_abierta:
			c_mod.r = 0.1; c_mod.g = 0.9; c_mod.b = 0.1 # Verde
		else:
			c_mod.r = 0.0; c_mod.g = 0.8; c_mod.b = 1.0 # Celeste
			
		_label_3d.modulate = c_mod
		_label_3d.outline_modulate = c_out

func _crear_interfaz_ui() -> void:
	_canvas_ui = CanvasLayer.new()
	_canvas_ui.name = "UISantamaria"
	add_child(_canvas_ui)
	
	# Crear un contenedor de control que ocupe toda la pantalla
	var base_control = Control.new()
	base_control.name = "BaseControl"
	base_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_control.mouse_filter = Control.MOUSE_FILTER_IGNORE # Evitar bloquear clics en joysticks y botones
	_canvas_ui.add_child(base_control)
	
	_boton_abrir = Button.new()
	_boton_abrir.text = "ABRIR PUERTA BODEGA"
	_boton_abrir.visible = false
	_boton_abrir.custom_minimum_size = Vector2(340, 60)
	_boton_abrir.focus_mode = Control.FOCUS_NONE
	
	base_control.add_child(_boton_abrir)
	
	# Centrar en la parte inferior de la pantalla (PRESET_CENTER_BOTTOM)
	_boton_abrir.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	
	# Elevar el botón y centrarlo horizontalmente (margen de 170 es la mitad de 340)
	_boton_abrir.offset_left = -170
	_boton_abrir.offset_right = 170
	_boton_abrir.offset_top = -220
	_boton_abrir.offset_bottom = -160
	
	# Estilo premium (Estilo plano moderno / Glassmorphism elegante)
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.12, 0.2, 0.75) # Fondo oscuro translúcido
	style_normal.set_corner_radius_all(15) # Coincide con el radio 15 de los botones principales
	style_normal.set_content_margin_all(12)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.0, 0.75, 1.0, 0.8) # Borde de brillo celeste neón
	style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style_normal.shadow_size = 8
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.12, 0.2, 0.3, 0.85)
	style_hover.border_color = Color(0.0, 0.9, 1.0, 0.95)
	
	var style_pressed = style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = Color(0.04, 0.08, 0.15, 0.9)
	style_pressed.border_color = Color(0.0, 0.5, 0.8, 0.9)
	
	var style_disabled = style_normal.duplicate() as StyleBoxFlat
	style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.4)
	style_disabled.border_color = Color(0.4, 0.4, 0.4, 0.3)
	style_disabled.shadow_size = 0

	_boton_abrir.add_theme_stylebox_override("normal", style_normal)
	_boton_abrir.add_theme_stylebox_override("hover", style_hover)
	_boton_abrir.add_theme_stylebox_override("pressed", style_pressed)
	_boton_abrir.add_theme_stylebox_override("disabled", style_disabled)
	_boton_abrir.add_theme_font_size_override("font_size", 14)
	_boton_abrir.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0)) # Letras celestes brillantes
	_boton_abrir.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_boton_abrir.add_theme_color_override("font_pressed_color", Color(0.0, 0.6, 0.8))
	
	# Cargar fuente personalizada si existe
	var font_path_override = "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path_override):
		var custom_font = load(font_path_override)
		if custom_font:
			_boton_abrir.add_theme_font_override("font", custom_font)

	_boton_abrir.pressed.connect(_on_btn_abrir_pressed)

func _on_sensor_body_entered(body: Node3D) -> void:
	print("[Santamaria] DETECTADO CUERPO EN EL SENSOR: ", body.name, " | Grupos: ", body.get_groups())
	
	if body.is_in_group("jugador") or "jugador" in body.name.to_lower() or body is CharacterBody3D:
		_jugador_cerca = true
		_actualizar_estado_boton()
		print("[Santamaria] ¡Jugador válido detectado cerca! Mostrando botón.")

func _on_sensor_body_exited(body: Node3D) -> void:
	print("[Santamaria] CUERPO SALIÓ DEL SENSOR: ", body.name)
	
	if body.is_in_group("jugador") or "jugador" in body.name.to_lower() or body is CharacterBody3D:
		_jugador_cerca = false
		_boton_abrir.visible = false
		print("[Santamaria] Jugador válido se alejó. Ocultando botón.")

func _on_btn_abrir_pressed() -> void:
	if not anim_player or _animacion_reproduciendo:
		return
		
	# Iniciar animación de apertura
	_animacion_reproduciendo = true
	_boton_abrir.disabled = true
	
	print("[Santamaria] Reproduciendo animación '", nombre_animacion, "' (Apertura)...")
		
	anim_player.play(nombre_animacion)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name != nombre_animacion:
		return
		
	_animacion_reproduciendo = false
	
	if not _puerta_abierta:
		# La puerta se ha abierto completamente
		_puerta_abierta = true
		_boton_abrir.visible = false # Ocultar mientras esté abierta
		
		# Cuenta regresiva de cierre (10, 9, 8...) en el Label3D
		var tiempo_restante = tiempo_espera_cierre
		while tiempo_restante > 0.0:
			if _label_3d:
				_label_3d.text = "[ BODEGA ABIERTA ]\nCERRANDO EN %d SEC" % int(ceil(tiempo_restante))
			await get_tree().create_timer(1.0).timeout
			tiempo_restante -= 1.0
		
		# Cerrar la puerta reproduciendo en reversa
		if anim_player:
			_animacion_reproduciendo = true
			print("[Santamaria] Temporizador cumplido. Cerrando puerta (reversa)...")
			anim_player.play_backwards(nombre_animacion)
	else:
		# La puerta se ha cerrado completamente en reversa
		_puerta_abierta = false
		_boton_abrir.disabled = false
		_actualizar_estado_boton()
		
		print("[Santamaria] Puerta completamente cerrada. Lista para usarse de nuevo.")

func _actualizar_estado_boton() -> void:
	if _jugador_cerca and not _animacion_reproduciendo and not _puerta_abierta:
		_boton_abrir.visible = true
	else:
		_boton_abrir.visible = false
