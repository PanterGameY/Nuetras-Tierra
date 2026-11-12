# ControladorItemEnMano.gd
# Maneja el brazo 3D y el objeto sostenido en primera persona (Viewmodel estilo Minecraft).
# Incluye animación de equipar, golpe/swing de Minecraft, inercia de cámara (sway) y balanceo al caminar (bobbing).
class_name ControladorItemEnMano
extends Node3D

signal item_consumido(item_id: String)
signal item_guardado(item_id: String)
signal item_soltado(item_id: String)

# ─────────────────────────────────────────────────────────────
#  CONFIGURACIÓN DE VIEWMODEL
# ─────────────────────────────────────────────────────────────
@export var posicion_reposo: Vector3 = Vector3(0.24, -0.20, -0.36)
@export var rotacion_reposo_deg: Vector3 = Vector3(12.0, -28.0, 8.0)
@export var intensidad_sway: float = 0.0006
@export var suavizado_sway: float = 9.0

# Jerarquía interna de pivotes para efectos combinados
var _pivot_sway: Node3D
var _pivot_bob: Node3D
var _pivot_swing: Node3D
var _brazo_viewmodel: Node3D
var _item_anchor: Node3D

# Estado activo
var item_id_actual: String = ""
var item_data_actual: Dictionary = {}
var modelo_nodo: Node3D = null
var jugador_ref: CharacterBody3D = null
var camara_ref: Camera3D = null

# Sway, Bobbing e Inercia
var _sway_pos_target: Vector3 = Vector3.ZERO
var _sway_rot_target: Vector3 = Vector3.ZERO
var _tiempo_bob: float = 0.0
var _animando_swing: bool = false
var _linterna_encendida: bool = true

# UI flotante en pantalla para controles táctiles y atajos
var _hud_layer: CanvasLayer = null
var _panel_controles: PanelContainer = null
var _btn_usar: Button = null
var _btn_guardar: Button = null
var _label_nombre: Label = null
var _audio_player: AudioStreamPlayer = null

func _ready() -> void:
	top_level = false
	position = posicion_reposo
	rotation_degrees = rotacion_reposo_deg

	_construir_jerarquia_viewmodel()
	_construir_brazo_minecraft()
	_crear_hud_en_pantalla()
	_crear_audio_player()

	# Iniciar oculto hasta que se equipe algo
	visible = false

func _construir_jerarquia_viewmodel() -> void:
	_pivot_sway = Node3D.new()
	_pivot_sway.name = "PivotSway"
	add_child(_pivot_sway)

	_pivot_bob = Node3D.new()
	_pivot_bob.name = "PivotBob"
	_pivot_sway.add_child(_pivot_bob)

	_pivot_swing = Node3D.new()
	_pivot_swing.name = "PivotSwing"
	_pivot_bob.add_child(_pivot_swing)

	_brazo_viewmodel = Node3D.new()
	_brazo_viewmodel.name = "BrazoViewmodel"
	_pivot_swing.add_child(_brazo_viewmodel)

	_item_anchor = Node3D.new()
	_item_anchor.name = "ItemAnchor"
	# Posición del anclaje del objeto justo en la palma de la mano
	_item_anchor.position = Vector3(0.02, 0.04, -0.04)
	# Rotación isométrica inclinada estilo Minecraft para apreciar caras y volumen 3D
	_item_anchor.rotation_degrees = Vector3(15.0, -35.0, 12.0)
	_pivot_swing.add_child(_item_anchor)

## Construye un brazo y guante táctico procedural en 3D para sostener el objeto
func _construir_brazo_minecraft() -> void:
	# Material del antebrazo / manga de chaqueta táctica
	var mat_manga := StandardMaterial3D.new()
	mat_manga.albedo_color = Color(0.12, 0.14, 0.16) # Dark Carbon Slate
	mat_manga.roughness = 0.8
	mat_manga.render_priority = 10

	# Material de la franja / ribete ámbar
	var mat_cuff := StandardMaterial3D.new()
	mat_cuff.albedo_color = Color(0.88, 0.68, 0.28) # Amber Cockpit
	mat_cuff.metallic = 0.4
	mat_cuff.roughness = 0.3
	mat_cuff.render_priority = 10

	# Material del guante de cuero de cabina
	var mat_guante := StandardMaterial3D.new()
	mat_guante.albedo_color = Color(0.08, 0.09, 0.10) # Cuero oscuro
	mat_guante.roughness = 0.65
	mat_guante.render_priority = 10

	# 1. Antebrazo (sale de la esquina inferior derecha hacia adelante)
	var antebrazo := MeshInstance3D.new()
	var box_arm := BoxMesh.new()
	box_arm.size = Vector3(0.085, 0.085, 0.28)
	antebrazo.mesh = box_arm
	antebrazo.position = Vector3(0.05, -0.06, 0.13)
	antebrazo.rotation_degrees = Vector3(12.0, -10.0, 5.0)
	antebrazo.material_override = mat_manga
	_brazo_viewmodel.add_child(antebrazo)

	# 2. Puño / Ribete ámbar de la manga
	var puno := MeshInstance3D.new()
	var box_puno := BoxMesh.new()
	box_puno.size = Vector3(0.09, 0.09, 0.025)
	puno.mesh = box_puno
	puno.position = Vector3(0.035, -0.035, 0.035)
	puno.rotation_degrees = Vector3(12.0, -10.0, 5.0)
	puno.material_override = mat_cuff
	_brazo_viewmodel.add_child(puno)

	# 3. Palma del guante / Mano
	var mano := MeshInstance3D.new()
	var box_mano := BoxMesh.new()
	box_mano.size = Vector3(0.075, 0.07, 0.09)
	mano.mesh = box_mano
	mano.position = Vector3(0.015, -0.01, -0.015)
	mano.rotation_degrees = Vector3(10.0, -8.0, 0.0)
	mano.material_override = mat_guante
	_brazo_viewmodel.add_child(mano)

	# 4. Dedos / Nudillos sujetando el objeto
	var dedos := MeshInstance3D.new()
	var box_dedos := BoxMesh.new()
	box_dedos.size = Vector3(0.025, 0.055, 0.07)
	dedos.mesh = box_dedos
	dedos.position = Vector3(-0.025, 0.015, -0.035)
	dedos.rotation_degrees = Vector3(15.0, 10.0, -12.0)
	dedos.material_override = mat_guante
	_brazo_viewmodel.add_child(dedos)

	# Pulgar
	var pulgar := MeshInstance3D.new()
	var box_pulgar := BoxMesh.new()
	box_pulgar.size = Vector3(0.028, 0.03, 0.04)
	pulgar.mesh = box_pulgar
	pulgar.position = Vector3(0.045, 0.03, -0.02)
	pulgar.rotation_degrees = Vector3(-15.0, -20.0, 15.0)
	pulgar.material_override = mat_guante
	_brazo_viewmodel.add_child(pulgar)

func vincular_jugador(p_jugador: CharacterBody3D, p_camara: Camera3D) -> void:
	jugador_ref = p_jugador
	camara_ref = p_camara

	if is_instance_valid(p_camara):
		if get_parent() != p_camara:
			if get_parent():
				get_parent().remove_child(self)
			p_camara.add_child(self)
		position = posicion_reposo
		rotation_degrees = rotacion_reposo_deg
		# Si ya hay un item equipado, mantenerlo visible
		if not item_id_actual.is_empty():
			visible = true

func tiene_item_equipado() -> bool:
	return not item_id_actual.is_empty() and is_instance_valid(modelo_nodo)

func equipar_item(p_id: String) -> void:
	var datos := TiendaItems.get_item(p_id)
	if datos.is_empty():
		push_warning("[ControladorItemEnMano] Item no reconocido: " + p_id)
		return

	desequipar_item(false)

	item_id_actual = p_id
	item_data_actual = datos
	modelo_nodo = TiendaItems.crear_modelo_3d(p_id)
	_item_anchor.add_child(modelo_nodo)

	visible = true

	# Animación suave de subida al equipar (Equip Tween)
	position = posicion_reposo - Vector3(0.0, 0.28, -0.08)
	rotation_degrees = rotacion_reposo_deg + Vector3(25.0, 5.0, -12.0)
	scale = Vector3(0.6, 0.6, 0.6)

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", posicion_reposo, 0.32)
	tw.tween_property(self, "rotation_degrees", rotacion_reposo_deg, 0.32)
	tw.tween_property(self, "scale", Vector3.ONE, 0.32)

	_reproducir_sonido_equip()
	_actualizar_hud()

func desequipar_item(animar: bool = true) -> void:
	if item_id_actual.is_empty():
		return

	if animar and is_instance_valid(modelo_nodo):
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "position", posicion_reposo - Vector3(0.0, 0.32, 0.0), 0.18)
		tw.tween_property(self, "scale", Vector3(0.3, 0.3, 0.3), 0.18)
		await tw.finished

	if is_instance_valid(modelo_nodo):
		modelo_nodo.queue_free()
		modelo_nodo = null

	item_id_actual = ""
	item_data_actual = {}
	visible = false
	_actualizar_hud()

## Animación clásica de Swing / Golpe de Minecraft al usar o hacer clic
func usar_item() -> void:
	if item_id_actual.is_empty() or _animando_swing:
		return

	_animando_swing = true

	var es_consumible: bool = item_data_actual.get("consumible", false)
	var tipo_efecto: String = item_data_actual.get("efecto_tipo", "")

	# Animación de golpe/swing potente en arco (Minecraft punch/swing)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Fase 1: Golpe hacia adelante y abajo
	tw.tween_property(_pivot_swing, "rotation_degrees", Vector3(-32.0, 32.0, -26.0), 0.10)
	tw.parallel().tween_property(_pivot_swing, "position", Vector3(-0.06, -0.04, -0.06), 0.10)
	# Fase 2: Recuperación con rebote elástico suave
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pivot_swing, "rotation_degrees", Vector3.ZERO, 0.16)
	tw.parallel().tween_property(_pivot_swing, "position", Vector3.ZERO, 0.16)

	_reproducir_sonido_swing()

	# Ejecución de la acción en el clímax del golpe
	match tipo_efecto:
		"bloque":
			_mostrar_notificacion("¡Bloque listo para construir o transportar!")
		"velocidad":
			_aplicar_efecto_velocidad(item_data_actual.get("efecto_valor", 1.35), item_data_actual.get("duracion", 60.0))
		"energia":
			_aplicar_efecto_energia()
		"salud":
			_mostrar_notificacion("¡Te has refrescado con Agua Mineral pura!")
		"luz":
			_alternar_linterna()
		"combustible":
			_intentar_recargar_combustible()
		"reparacion":
			_intentar_reparar_vehiculo()
		"mochila":
			_desbloquear_mochila()

	await tw.finished
	_animando_swing = false
	emit_signal("item_consumido", item_id_actual)

	# Si es consumible, consumirlo y desequipar
	if es_consumible and tipo_efecto != "luz":
		_mostrar_notificacion("Consumido: " + item_data_actual.get("nombre", ""))
		desequipar_item(true)

func guardar_en_inventario() -> void:
	if item_id_actual.is_empty():
		return

	if jugador_ref and jugador_ref.has_node("InventarioUI"):
		var inv = jugador_ref.get_node("InventarioUI")
		if inv.has_method("agregar_item"):
			var ok: bool = inv.agregar_item(item_data_actual.get("nombre", item_id_actual), null)
			if ok:
				_mostrar_notificacion("Guardado en mochila: " + item_data_actual.get("nombre", ""))
				emit_signal("item_guardado", item_id_actual)
				desequipar_item(true)
				return

	emit_signal("item_guardado", item_id_actual)
	desequipar_item(true)

func _alternar_linterna() -> void:
	_linterna_encendida = !_linterna_encendida
	if is_instance_valid(modelo_nodo):
		var luz = modelo_nodo.find_child("LuzLinterna", true, false)
		if luz is Light3D:
			luz.visible = _linterna_encendida
	_mostrar_notificacion("Linterna: " + ("ENCENDIDA" if _linterna_encendida else "APAGADA"))

func _aplicar_efecto_velocidad(multiplicador: float, duracion: float) -> void:
	if not jugador_ref: return
	var vel_orig: float = jugador_ref.velocidad_caminar
	var sprint_orig: float = jugador_ref.velocidad_correr
	jugador_ref.velocidad_caminar *= multiplicador
	jugador_ref.velocidad_correr *= multiplicador
	_mostrar_notificacion("⚡ ¡Impulso de Café! Velocidad x%.2f por %.0fs" % [multiplicador, duracion])

	await get_tree().create_timer(duracion).timeout
	if is_instance_valid(jugador_ref):
		jugador_ref.velocidad_caminar = vel_orig
		jugador_ref.velocidad_correr = sprint_orig

func _aplicar_efecto_energia() -> void:
	_mostrar_notificacion("🔋 ¡Energía y Resistencia al Máximo!")

func _intentar_recargar_combustible() -> void:
	_mostrar_notificacion("⛽ Bidón listo. Acércate al tanque del camión para repostar.")

func _intentar_reparar_vehiculo() -> void:
	_mostrar_notificacion("🛠 Kit mecánico listo. Acércate al motor o chasis dañado.")

func _desbloquear_mochila() -> void:
	if jugador_ref and jugador_ref.has_node("InventarioUI"):
		var inv = jugador_ref.get_node("InventarioUI")
		inv.tiene_mochila = true
		_mostrar_notificacion("🎒 Mochila equipada: Capacidad ampliada a 10 slots.")
	desequipar_item(true)

# ─────────────────────────────────────────────────────────────
#  CINEMÁTICA Y ACTUALIZACIÓN EN VIVO (SWAY Y BOBBING)
# ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(_pivot_sway):
		return

	# Asegurar que permanezca vinculado a la cámara activa del jugador
	if is_instance_valid(jugador_ref) and jugador_ref.has_method("get_camara_activa"):
		var cam_act = jugador_ref.get_camara_activa()
		if is_instance_valid(cam_act) and get_parent() != cam_act:
			vincular_jugador(jugador_ref, cam_act)

	# 1. Recuperación suave de inercia / sway del mouse
	_sway_pos_target = _sway_pos_target.lerp(Vector3.ZERO, delta * suavizado_sway)
	_sway_rot_target = _sway_rot_target.lerp(Vector3.ZERO, delta * suavizado_sway)
	_pivot_sway.position = _pivot_sway.position.lerp(_sway_pos_target, delta * 12.0)
	_pivot_sway.rotation_degrees = _pivot_sway.rotation_degrees.lerp(_sway_rot_target, delta * 12.0)

	# 2. Bobbing al caminar / correr
	var vel_player := jugador_ref.velocity if is_instance_valid(jugador_ref) else Vector3.ZERO
	var vel_horizontal := Vector2(vel_player.x, vel_player.z).length()

	if vel_horizontal > 0.4:
		var es_sprint: bool = vel_horizontal > 4.5
		var frec: float = 14.0 if es_sprint else 9.5
		var amp_x: float = 0.007 if es_sprint else 0.004
		var amp_y: float = 0.006 if es_sprint else 0.0035

		_tiempo_bob += delta * frec
		var bob_x: float = sin(_tiempo_bob) * amp_x
		var bob_y: float = abs(cos(_tiempo_bob)) * amp_y
		_pivot_bob.position = _pivot_bob.position.lerp(Vector3(bob_x, -bob_y, 0.0), delta * 12.0)
		_pivot_bob.rotation_degrees.z = lerpf(_pivot_bob.rotation_degrees.z, sin(_tiempo_bob) * 1.5, delta * 10.0)
	else:
		_tiempo_bob = 0.0
		_pivot_bob.position = _pivot_bob.position.lerp(Vector3.ZERO, delta * 8.0)
		_pivot_bob.rotation_degrees.z = lerpf(_pivot_bob.rotation_degrees.z, 0.0, delta * 8.0)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Inercia de cámara (Sway al rotar la vista)
	if event is InputEventMouseMotion:
		_sway_pos_target.x = clamp(-event.relative.x * intensidad_sway, -0.025, 0.025)
		_sway_pos_target.y = clamp(event.relative.y * intensidad_sway, -0.025, 0.025)
		_sway_rot_target.y = clamp(-event.relative.x * 0.12, -7.0, 7.0)
		_sway_rot_target.x = clamp(event.relative.y * 0.12, -7.0, 7.0)

# ─────────────────────────────────────────────────────────────
#  INTERFAZ DE USUARIO FLOTANTE Y AUDIO
# ─────────────────────────────────────────────────────────────

func _crear_hud_en_pantalla() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDItemMano"
	_hud_layer.layer = 11
	add_child(_hud_layer)

	_panel_controles = PanelContainer.new()
	_panel_controles.name = "PanelControlesMano"
	_panel_controles.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel_controles.anchor_left = 1.0
	_panel_controles.anchor_top = 1.0
	_panel_controles.anchor_right = 1.0
	_panel_controles.anchor_bottom = 1.0
	_panel_controles.offset_left = -380
	_panel_controles.offset_top = -140
	_panel_controles.offset_right = -24
	_panel_controles.offset_bottom = -24

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.90) # Dark Slate Cockpit
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.81, 0.85, 0.22) # Frost Metallic 1px
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.5)
	_panel_controles.add_theme_stylebox_override("panel", sb)
	_hud_layer.add_child(_panel_controles)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel_controles.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_label_nombre = Label.new()
	_label_nombre.text = "EN MANO: OBJETO"
	_label_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aplicar_fuente_label(_label_nombre, 18, Color(0.88, 0.68, 0.28)) # Amber
	vbox.add_child(_label_nombre)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	_btn_usar = Button.new()
	_btn_usar.text = "✊ USAR [E]"
	_btn_usar.custom_minimum_size = Vector2(170, 44)
	_estilizar_boton(_btn_usar, Color(0.88, 0.68, 0.28, 0.95), Color(0.88, 0.68, 0.28, 0.25))
	_btn_usar.pressed.connect(usar_item)
	hbox.add_child(_btn_usar)

	_btn_guardar = Button.new()
	_btn_guardar.text = "✕ GUARDAR [G]"
	_btn_guardar.custom_minimum_size = Vector2(150, 44)
	_estilizar_boton(_btn_guardar, Color(0.78, 0.28, 0.26, 0.95), Color(0.78, 0.28, 0.26, 0.25))
	_btn_guardar.pressed.connect(guardar_en_inventario)
	hbox.add_child(_btn_guardar)

	_panel_controles.visible = false

func _actualizar_hud() -> void:
	if not _panel_controles:
		return

	if item_id_actual.is_empty():
		_panel_controles.visible = false
	else:
		_panel_controles.visible = true
		var nom: String = item_data_actual.get("nombre", item_id_actual)
		var tipo: String = item_data_actual.get("efecto_tipo", "")
		_label_nombre.text = "EN MANO: " + nom.to_upper()

		if tipo == "luz":
			_btn_usar.text = "🔦 LUZ [E]"
		elif tipo == "bloque":
			_btn_usar.text = "✊ GOLPEAR [E]"
		else:
			_btn_usar.text = "✊ CONSUMIR [E]"

func _crear_audio_player() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)

func _reproducir_sonido_equip() -> void:
	var path := "res://recursos/efectos/checkpoint.mp3"
	if ResourceLoader.exists(path) and _audio_player:
		_audio_player.stream = load(path)
		_audio_player.volume_db = -6.0
		_audio_player.play()

func _reproducir_sonido_swing() -> void:
	var path := "res://recursos/sonidos_vehiculo/efectos/choque_leve.mp3"
	if ResourceLoader.exists(path) and _audio_player:
		_audio_player.stream = load(path)
		_audio_player.volume_db = -12.0
		_audio_player.pitch_scale = randf_range(1.4, 1.7)
		_audio_player.play()

func _mostrar_notificacion(msg: String) -> void:
	print("[ItemEnMano] " + msg)
	if jugador_ref and jugador_ref.has_method("_screen_log"):
		jugador_ref._screen_log(msg)

func _aplicar_fuente_label(lbl: Label, size: int, col: Color) -> void:
	var font_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		lbl.add_theme_font_override("font", load(font_path))
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)

func _estilizar_boton(btn: Button, col_texto: Color, col_borde: Color) -> void:
	var font_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(font_path):
		btn.add_theme_font_override("font", load(font_path))
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", col_texto)

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.08, 0.09, 0.11, 0.82)
	sb_normal.border_width_left = 1
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 1
	sb_normal.border_color = col_borde
	sb_normal.corner_radius_top_left = 8
	sb_normal.corner_radius_top_right = 8
	sb_normal.corner_radius_bottom_left = 8
	sb_normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb_normal)

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color(col_borde.r, col_borde.g, col_borde.b, 0.45)
	sb_pressed.border_width_left = 1
	sb_pressed.border_width_top = 1
	sb_pressed.border_width_right = 1
	sb_pressed.border_width_bottom = 2
	sb_pressed.border_color = col_texto
	sb_pressed.corner_radius_top_left = 8
	sb_pressed.corner_radius_top_right = 8
	sb_pressed.corner_radius_bottom_left = 8
	sb_pressed.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_normal)
