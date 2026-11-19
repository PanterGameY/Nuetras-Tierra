# ═══════════════════════════════════════════════════════════════════════════════
# pista_pruebas_pesados.gd
# Controlador de la Pista de Pruebas de Vehículos Pesados
# Telemetría en vivo, teletransporte a sectores, báscula, antivuelco y UI Glassmorphic
# Nuestra Tierra 2.0
# ═══════════════════════════════════════════════════════════════════════════════
extends Node3D

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var camion_actual: RigidBody3D = $T800_Alargada
@onready var jugador: CharacterBody3D = get_node_or_null("Brayan") if has_node("Brayan") else get_node_or_null("Jugador2")

# Remolques de prueba
@onready var trailer_vacio: RigidBody3D = get_node_or_null("TrailersPrueba/TrailerVacio")
@onready var trailer_medio: RigidBody3D = get_node_or_null("TrailersPrueba/TrailerMedio")
@onready var trailer_pesado: RigidBody3D = get_node_or_null("carpado")

# Puntos de teletransporte (Markers)
@onready var spawn_patio: Marker3D = $PuntosTeletransporte/SpawnPatio
@onready var spawn_frenado: Marker3D = $PuntosTeletransporte/SpawnFrenado
@onready var spawn_rampas: Marker3D = $PuntosTeletransporte/SpawnRampas
@onready var spawn_suspension: Marker3D = $PuntosTeletransporte/SpawnSuspension
@onready var spawn_balancin: Marker3D = $PuntosTeletransporte/SpawnBalancin
@onready var spawn_inclinacion: Marker3D = $PuntosTeletransporte/SpawnInclinacion

# Báscula 3D
@onready var display_bascula: Label3D = get_node_or_null("MapaPruebas/SectorPatio/Bascula/DisplayPeso")
@onready var area_bascula: Area3D = get_node_or_null("MapaPruebas/SectorPatio/Bascula/AreaPesaje")

# HUD y UI
@onready var canvas_hud: CanvasLayer = $HUDPruebas
@onready var btn_abrir_menu: Button = $HUDPruebas/BotonAbrirMenu
@onready var panel_menu: Control = $HUDPruebas/PanelMenuModal
@onready var panel_contenedor: PanelContainer = $HUDPruebas/PanelMenuModal/Centro/PanelGlass
@onready var lbl_telemetria_vel: Label = $HUDPruebas/HUDTelemetria/VBox/FilaVel/ValorVel
@onready var lbl_telemetria_pitch: Label = $HUDPruebas/HUDTelemetria/VBox/FilaPitch/ValorPitch
@onready var lbl_telemetria_roll: Label = $HUDPruebas/HUDTelemetria/VBox/FilaRoll/ValorRoll
@onready var lbl_telemetria_frenado: Label = $HUDPruebas/HUDTelemetria/VBox/FilaFrenado/ValorFrenado
@onready var lbl_telemetria_peso: Label = $HUDPruebas/HUDTelemetria/VBox/FilaPeso/ValorPeso

# Variables de medición de frenado automático
var _frenando_medicion: bool = false
var _pos_inicio_freno: Vector3 = Vector3.ZERO
var _vel_inicio_freno_kmh: float = 0.0
var _tiempo_inicio_freno: float = 0.0
var _resultado_distancia_freno: float = 0.0
var _resultado_tiempo_freno: float = 0.0

# Animación de menú
var _tween_menu: Tween = null
var _menu_abierto: bool = false

# Prueba de manejo para licencias (desde Tienda)
var _prueba_activa: bool = false
var _prueba_categoria: String = ""
var _prueba_puntos: Array[Vector3] = []
var _prueba_idx: int = 0
var _prueba_marker_3d: MeshInstance3D = null
var _prueba_banner: PanelContainer = null
var _prueba_lbl_estado: Label = null
var _prueba_lbl_dist: Label = null


func _ready() -> void:
	_configurar_interfaz()
	_conectar_bascula()
	_actualizar_display_bascula(0.0)
	if DatosUsuario and "licencia_prueba_pendiente" in DatosUsuario and DatosUsuario.licencia_prueba_pendiente != "":
		_iniciar_prueba_licencia(DatosUsuario.licencia_prueba_pendiente)


func _process(delta: float) -> void:
	_actualizar_telemetria(delta)
	if _prueba_activa:
		_actualizar_prueba_licencia()


# ═══════════════════════════════════════════════════════════════════════════════
# 📊 TELEMETRÍA EN VIVO Y MEDICIÓN DE FRENADO
# ═══════════════════════════════════════════════════════════════════════════════

func _actualizar_telemetria(delta: float) -> void:
	var vehiculo = _obtener_vehiculo_activo()
	if not vehiculo:
		return

	# 1. Velocidad actual en km/h
	var vel_ms: float = vehiculo.linear_velocity.length()
	var vel_kmh: float = vel_ms * 3.6
	if lbl_telemetria_vel:
		lbl_telemetria_vel.text = "%3.0f km/h" % vel_kmh

	# 2. Inclinaciones (Pitch y Roll en grados)
	var basis_car: Basis = vehiculo.global_transform.basis.orthonormalized()
	# Pitch (cabeceo hacia adelante / atrás)
	var fwd_y = -basis_car.z.y
	var pitch_grados = rad_to_deg(asin(clampf(fwd_y, -1.0, 1.0)))
	# Roll (inclinación lateral izquierda / derecha)
	var right_y = basis_car.x.y
	var roll_grados = rad_to_deg(asin(clampf(right_y, -1.0, 1.0)))

	if lbl_telemetria_pitch:
		lbl_telemetria_pitch.text = "%+4.1f°" % pitch_grados
	if lbl_telemetria_roll:
		lbl_telemetria_roll.text = "%+4.1f°" % roll_grados

	# 3. Medición automática de frenado a fondo
	_procesar_medidor_frenado(vehiculo, vel_kmh)

	# 4. Peso total convoy
	var peso_camion: float = vehiculo.mass if "mass" in vehiculo else 8500.0
	var peso_trailer: float = 0.0
	if vehiculo.has_method("obtener_peso_remolque"):
		peso_trailer = vehiculo.obtener_peso_remolque()

	var peso_total_kg = peso_camion + peso_trailer
	if lbl_telemetria_peso:
		lbl_telemetria_peso.text = "%5.0f kg (%4.1f t)" % [peso_total_kg, peso_total_kg / 1000.0]


func _procesar_medidor_frenado(vehiculo: RigidBody3D, vel_kmh: float) -> void:
	# Detectar frenado profundo
	var frenando: bool = false
	if Input.is_action_pressed("freno") or Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE):
		frenando = true

	# Inicio de prueba de frenado: cuando supera 30 km/h y clava los frenos
	if not _frenando_medicion and frenando and vel_kmh > 30.0:
		_frenando_medicion = true
		_pos_inicio_freno = vehiculo.global_position
		_vel_inicio_freno_kmh = vel_kmh
		_tiempo_inicio_freno = Time.get_ticks_msec() / 1000.0
		if lbl_telemetria_frenado:
			lbl_telemetria_frenado.text = "Frenando desde %.0f km/h..." % _vel_inicio_freno_kmh

	# Durante la frenada: calcular distancia acumulada
	if _frenando_medicion:
		var dist_actual = vehiculo.global_position.distance_to(_pos_inicio_freno)
		if vel_kmh <= 1.5:
			# Camión detenido: finalizar medición
			_frenando_medicion = false
			_resultado_distancia_freno = dist_actual
			_resultado_tiempo_freno = (Time.get_ticks_msec() / 1000.0) - _tiempo_inicio_freno
			if lbl_telemetria_frenado:
				lbl_telemetria_frenado.text = "%.1fm en %.2fs (desde %.0f km/h)" % [
					_resultado_distancia_freno,
					_resultado_tiempo_freno,
					_vel_inicio_freno_kmh
				]
		elif not frenando and vel_kmh > 5.0:
			# El jugador soltó el freno antes de parar completamente
			_frenando_medicion = false
			if lbl_telemetria_frenado:
				lbl_telemetria_frenado.text = "Interrumpido: %.1fm (suelta)" % dist_actual
		else:
			if lbl_telemetria_frenado:
				lbl_telemetria_frenado.text = "Freno: %.1f m" % dist_actual


# ═══════════════════════════════════════════════════════════════════════════════
# ⚖️ BÁSCULA CAMIONERA CON DETECCIÓN DE PESO
# ═══════════════════════════════════════════════════════════════════════════════

func _conectar_bascula() -> void:
	if area_bascula:
		area_bascula.body_entered.connect(_on_bascula_body_entered)
		area_bascula.body_exited.connect(_on_bascula_body_exited)


func _on_bascula_body_entered(body: Node) -> void:
	if body is RigidBody3D:
		_recalcular_peso_bascula()


func _on_bascula_body_exited(body: Node) -> void:
	if body is RigidBody3D:
		_recalcular_peso_bascula()


func _recalcular_peso_bascula() -> void:
	if not area_bascula:
		return
	var cuerpos = area_bascula.get_overlapping_bodies()
	var peso_total: float = 0.0
	for c in cuerpos:
		if c is RigidBody3D:
			peso_total += c.mass
	_actualizar_display_bascula(peso_total)


func _actualizar_display_bascula(peso_kg: float) -> void:
	if display_bascula:
		if peso_kg > 50.0:
			display_bascula.text = "BÁSCULA: %7.0f KG\n(%4.1f TONELADAS)" % [peso_kg, peso_kg / 1000.0]
			display_bascula.modulate = Color(1.0, 0.84, 0.0) # Oro
		else:
			display_bascula.text = "BÁSCULA DISPONIBLE\n[ COLOQUE VEHÍCULO ]"
			display_bascula.modulate = Color(0.2, 0.6, 1.0) # Azul neon


# ═══════════════════════════════════════════════════════════════════════════════
# 🚀 TELETRANSPORTE Y RESTABLECIMIENTO (ANTIVUELCO)
# ═══════════════════════════════════════════════════════════════════════════════

func teletransportar_a(marker: Marker3D) -> void:
	if not marker:
		return

	var vehiculo = _obtener_vehiculo_activo()
	if not vehiculo:
		return

	var destino_pos = marker.global_position + Vector3(0.0, 0.6, 0.0)
	var destino_rot = marker.global_rotation

	# Reseteo de velocidades físicas para evitar inercias acumuladas
	vehiculo.linear_velocity = Vector3.ZERO
	vehiculo.angular_velocity = Vector3.ZERO

	# Reposicionar cabezote
	var nueva_trans = Transform3D(Basis.from_euler(destino_rot), destino_pos)
	vehiculo.global_transform = nueva_trans
	PhysicsServer3D.body_set_state(vehiculo.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, nueva_trans)
	PhysicsServer3D.body_set_state(vehiculo.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(vehiculo.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

	# Si tiene un remolque acoplado, alinearlo exactamente detrás del cabezote
	if "enganche_nodo" in vehiculo and vehiculo.enganche_nodo:
		var remolque_obj = vehiculo.enganche_nodo.get("enganche_remoto")
		if remolque_obj and vehiculo.enganche_nodo.has_method("_buscar_cuerpo"):
			var cuerpo_rem = vehiculo.enganche_nodo._buscar_cuerpo(remolque_obj)
			if cuerpo_rem and cuerpo_rem is RigidBody3D:
				var atras_dir = -nueva_trans.basis.z.normalized()
				var pos_rem = destino_pos - (atras_dir * 7.5) + Vector3(0.0, 0.3, 0.0)
				var trans_rem = Transform3D(nueva_trans.basis, pos_rem)
				cuerpo_rem.global_transform = trans_rem
				PhysicsServer3D.body_set_state(cuerpo_rem.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, trans_rem)
				PhysicsServer3D.body_set_state(cuerpo_rem.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
				PhysicsServer3D.body_set_state(cuerpo_rem.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

	# Cerrar modal
	toggle_menu(false)


func enderezar_vehiculo() -> void:
	var vehiculo = _obtener_vehiculo_activo()
	if not vehiculo:
		return

	# Mantener posición actual elevándola ligeramente para asentar ruedas
	var pos = vehiculo.global_position + Vector3(0.0, 1.2, 0.0)
	var rot_actual_y = vehiculo.global_rotation.y
	var nueva_trans = Transform3D(Basis.from_euler(Vector3(0.0, rot_actual_y, 0.0)), pos)

	vehiculo.linear_velocity = Vector3.ZERO
	vehiculo.angular_velocity = Vector3.ZERO
	vehiculo.global_transform = nueva_trans
	PhysicsServer3D.body_set_state(vehiculo.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, nueva_trans)
	PhysicsServer3D.body_set_state(vehiculo.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(vehiculo.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

	# Enderezar remolque si está acoplado
	if "enganche_nodo" in vehiculo and vehiculo.enganche_nodo:
		var remolque_obj = vehiculo.enganche_nodo.get("enganche_remoto")
		if remolque_obj and vehiculo.enganche_nodo.has_method("_buscar_cuerpo"):
			var cuerpo_rem = vehiculo.enganche_nodo._buscar_cuerpo(remolque_obj)
			if cuerpo_rem and cuerpo_rem is RigidBody3D:
				var pos_rem = cuerpo_rem.global_position + Vector3(0.0, 1.2, 0.0)
				var rot_rem_y = cuerpo_rem.global_rotation.y
				var trans_rem = Transform3D(Basis.from_euler(Vector3(0.0, rot_rem_y, 0.0)), pos_rem)
				cuerpo_rem.linear_velocity = Vector3.ZERO
				cuerpo_rem.angular_velocity = Vector3.ZERO
				cuerpo_rem.global_transform = trans_rem
				PhysicsServer3D.body_set_state(cuerpo_rem.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, trans_rem)
				PhysicsServer3D.body_set_state(cuerpo_rem.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
				PhysicsServer3D.body_set_state(cuerpo_rem.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

	toggle_menu(false)


# ═══════════════════════════════════════════════════════════════════════════════
# ☀️ CAMBIO RÁPIDO DE HORA / AMBIENTE
# ═══════════════════════════════════════════════════════════════════════════════

func cambiar_hora(nueva_hora: float) -> void:
	if world_env and "hora_del_dia" in world_env:
		world_env.hora_del_dia = nueva_hora
	var sol_ctrl = get_node_or_null("ControladorSolLuna")
	if sol_ctrl and "hora_actual" in sol_ctrl:
		sol_ctrl.hora_actual = nueva_hora


# ═══════════════════════════════════════════════════════════════════════════════
# 🎨 GESTIÓN DE UI GLASSMORPHIC (MANUAL DE DISEÑO UI)
# ═══════════════════════════════════════════════════════════════════════════════

func _configurar_interfaz() -> void:
	if btn_abrir_menu:
		btn_abrir_menu.pressed.connect(func(): toggle_menu(true))

	if panel_menu:
		panel_menu.visible = false
		panel_menu.modulate.a = 0.0

	# Conectar botones del modal
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/GridTeleport/BtnPatio", func(): teletransportar_a(spawn_patio))
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/GridTeleport/BtnFrenado", func(): teletransportar_a(spawn_frenado))
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/GridTeleport/BtnRampas", func(): teletransportar_a(spawn_rampas))
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/GridTeleport/BtnSuspension", func(): teletransportar_a(spawn_suspension))
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/GridTeleport/BtnBalancin", func(): teletransportar_a(spawn_balancin))
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/GridTeleport/BtnInclinacion", func(): teletransportar_a(spawn_inclinacion))

	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/FilaAcciones/BtnEnderezar", enderezar_vehiculo)
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/FilaAcciones/BtnCerrar", func(): toggle_menu(false))

	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/FilaClima/BtnDia", func(): cambiar_hora(9.5))
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/FilaClima/BtnTarde", func(): cambiar_hora(17.8))
	_conectar_boton("PanelMenuModal/Centro/PanelGlass/Margin/VBox/FilaClima/BtnNoche", func(): cambiar_hora(21.5))


func _conectar_boton(ruta: String, callback: Callable) -> void:
	var btn = $HUDPruebas.get_node_or_null(ruta) as Button
	if btn:
		btn.pressed.connect(callback)


func toggle_menu(abrir: bool) -> void:
	if not panel_menu or not panel_contenedor:
		return

	if _tween_menu and _tween_menu.is_running():
		_tween_menu.kill()

	_menu_abierto = abrir
	_tween_menu = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if abrir:
		panel_menu.visible = true
		panel_contenedor.scale = Vector2(0.85, 0.85)
		panel_contenedor.pivot_offset = panel_contenedor.size * 0.5
		_tween_menu.tween_property(panel_menu, "modulate:a", 1.0, 0.30)
		_tween_menu.tween_property(panel_contenedor, "scale", Vector2(1.0, 1.0), 0.35)
	else:
		_tween_menu.tween_property(panel_menu, "modulate:a", 0.0, 0.25)
		_tween_menu.tween_property(panel_contenedor, "scale", Vector2(0.85, 0.85), 0.25)
		_tween_menu.chain().tween_callback(func(): panel_menu.visible = false)


func _obtener_vehiculo_activo() -> RigidBody3D:
	if is_instance_valid(camion_actual):
		return camion_actual
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# 🪪 PRUEBA DE MANEJO PARA LICENCIAS (DESDE TIENDA)
# ═══════════════════════════════════════════════════════════════════════════════

func _iniciar_prueba_licencia(categoria: String) -> void:
	_prueba_categoria = categoria.to_upper()
	_prueba_activa = true
	_prueba_idx = 0
	_prueba_puntos.clear()

	for m in [spawn_frenado, spawn_rampas, spawn_suspension, spawn_inclinacion, spawn_patio]:
		if is_instance_valid(m):
			_prueba_puntos.append(m.global_position)

	if _prueba_puntos.is_empty():
		_completar_prueba_licencia()
		return

	# Crear baliza 3D luminosa ámbar para el checkpoint actual
	_prueba_marker_3d = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.6
	cyl.bottom_radius = 2.6
	cyl.height = 7.0
	_prueba_marker_3d.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.68, 0.28, 0.40)
	mat.emission_enabled = true
	mat.emission = Color(0.88, 0.68, 0.28, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_prueba_marker_3d.material_override = mat
	add_child(_prueba_marker_3d)
	_prueba_marker_3d.global_position = _prueba_puntos[0] + Vector3(0, 3.5, 0)

	# Banner superior Glassmorphism Automotriz
	if canvas_hud:
		_prueba_banner = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.07, 0.08, 0.90)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.88, 0.68, 0.28, 0.85)
		sb.set_corner_radius_all(12)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
		_prueba_banner.add_theme_stylebox_override("panel", sb)
		_prueba_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_prueba_banner.offset_left = 360.0
		_prueba_banner.offset_right = -360.0
		_prueba_banner.offset_top = 18.0
		_prueba_banner.offset_bottom = 94.0

		var mg := MarginContainer.new()
		mg.add_theme_constant_override("margin_left", 20)
		mg.add_theme_constant_override("margin_right", 20)
		mg.add_theme_constant_override("margin_top", 10)
		mg.add_theme_constant_override("margin_bottom", 10)
		_prueba_banner.add_child(mg)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 18)
		mg.add_child(hbox)

		var font_mod := load("res://recursos/fonts/Moderniz.otf") as Font
		_prueba_lbl_estado = Label.new()
		_prueba_lbl_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_prueba_lbl_estado.add_theme_font_size_override("font_size", 22)
		_prueba_lbl_estado.add_theme_color_override("font_color", Color(0.88, 0.90, 0.93, 0.95))
		if font_mod:
			_prueba_lbl_estado.add_theme_font_override("font", font_mod)
		hbox.add_child(_prueba_lbl_estado)

		_prueba_lbl_dist = Label.new()
		_prueba_lbl_dist.add_theme_font_size_override("font_size", 22)
		_prueba_lbl_dist.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
		if font_mod:
			_prueba_lbl_dist.add_theme_font_override("font", font_mod)
		hbox.add_child(_prueba_lbl_dist)

		var btn_cancel := Button.new()
		btn_cancel.text = "CANCELAR"
		btn_cancel.custom_minimum_size = Vector2(150, 48)
		btn_cancel.focus_mode = Control.FOCUS_NONE
		btn_cancel.add_theme_font_size_override("font_size", 18)
		btn_cancel.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97, 1.0))
		if font_mod:
			btn_cancel.add_theme_font_override("font", font_mod)
		var sb_c := StyleBoxFlat.new()
		sb_c.bg_color = Color(0.24, 0.11, 0.11, 0.94)
		sb_c.set_border_width_all(1)
		sb_c.border_color = Color(0.78, 0.28, 0.26, 0.95)
		sb_c.set_corner_radius_all(8)
		btn_cancel.add_theme_stylebox_override("normal", sb_c)
		btn_cancel.pressed.connect(func():
			if DatosUsuario:
				DatosUsuario.licencia_prueba_pendiente = ""
			_salir_a_tienda()
		)
		hbox.add_child(btn_cancel)
		canvas_hud.add_child(_prueba_banner)


func _actualizar_prueba_licencia() -> void:
	if _prueba_idx >= _prueba_puntos.size():
		return
	var ref_node: Node3D = _obtener_vehiculo_activo()
	if not is_instance_valid(ref_node):
		ref_node = jugador
	if not is_instance_valid(ref_node):
		return

	var target := _prueba_puntos[_prueba_idx]
	var dist := ref_node.global_position.distance_to(target)
	if _prueba_lbl_estado:
		_prueba_lbl_estado.text = "PRUEBA LICENCIA %s  •  PUNTO %d / %d" % [_prueba_categoria, _prueba_idx + 1, _prueba_puntos.size()]
	if _prueba_lbl_dist:
		_prueba_lbl_dist.text = "%d m" % int(round(dist))

	if dist <= 7.5:
		_prueba_idx += 1
		if _prueba_idx >= _prueba_puntos.size():
			_completar_prueba_licencia()
		elif is_instance_valid(_prueba_marker_3d):
			_prueba_marker_3d.global_position = _prueba_puntos[_prueba_idx] + Vector3(0, 3.5, 0)


func _completar_prueba_licencia() -> void:
	_prueba_activa = false
	if is_instance_valid(_prueba_marker_3d):
		_prueba_marker_3d.queue_free()
	if is_instance_valid(_prueba_banner):
		_prueba_banner.queue_free()

	if DatosUsuario:
		if DatosUsuario.has_method("otorgar_licencia"):
			DatosUsuario.otorgar_licencia(_prueba_categoria)
		DatosUsuario.licencia_prueba_pendiente = ""
		DatosUsuario.save_local()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not canvas_hud:
		_salir_a_tienda()
		return

	var modal := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.88, 0.68, 0.28, 0.92)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	modal.add_theme_stylebox_override("panel", sb)
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.custom_minimum_size = Vector2(680, 300)
	modal.offset_left = -340.0
	modal.offset_right = 340.0
	modal.offset_top = -150.0
	modal.offset_bottom = 150.0

	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left", 32)
	mg.add_theme_constant_override("margin_right", 32)
	mg.add_theme_constant_override("margin_top", 28)
	mg.add_theme_constant_override("margin_bottom", 28)
	modal.add_child(mg)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	mg.add_child(vbox)

	var font_mod := load("res://recursos/fonts/Moderniz.otf") as Font
	var tit := Label.new()
	tit.text = "¡PRUEBA APROBADA!"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 36)
	tit.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
	if font_mod:
		tit.add_theme_font_override("font", font_mod)
	vbox.add_child(tit)

	var sub := Label.new()
	sub.text = "Adquiriste la Licencia %s correctamente." % _prueba_categoria
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.88, 0.90, 0.93, 0.95))
	vbox.add_child(sub)

	var btn := Button.new()
	btn.text = "VOLVER A LA TIENDA"
	btn.custom_minimum_size = Vector2(320, 68)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 1.0))
	if font_mod:
		btn.add_theme_font_override("font", font_mod)
	var sb_b := StyleBoxFlat.new()
	sb_b.bg_color = Color(0.88, 0.68, 0.28, 0.95)
	sb_b.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", sb_b)
	btn.pressed.connect(_salir_a_tienda)
	vbox.add_child(btn)

	canvas_hud.add_child(modal)
	modal.scale = Vector2(0.92, 0.92)
	modal.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal, "scale", Vector2.ONE, 0.30)
	tw.tween_property(modal, "modulate:a", 1.0, 0.25)


func _salir_a_tienda() -> void:
	get_tree().change_scene_to_file("res://interfaz/pantallas/tienda/Tienda.tscn")
