extends Node3D
class_name ZonaAlquilerTrailer

## ZonaAlquilerTrailer.gd
## Checkpoint / zona interactiva colocable desde el Editor de Mapas para pedir
## en alquiler y spawnear un tráiler (Carpado o Portacontenedor) alineado en la bahía.

const RUTA_CARPADO_1 := "res://modelos3d/vehiculos/Trailers/escenas/Carpado1.tscn"
const RUTA_CARPADO_ALT := "res://modelos3d/Trailers y remolques/Carpado/carpado.tscn"
const RUTA_CHASIS := "res://modelos3d/vehiculos/Trailers/chasis/CT_1.tscn"
const RUTA_CARPADO_GLB := "res://modelos3d/vehiculos/Trailers/carpado1_optimizado.glb"
const RUTA_CHASIS_GLB := "res://modelos3d/vehiculos/Trailers/chasis/1.glb"
const FUENTE_MODERNIZ := "res://recursos/fonts/Moderniz.otf"
const FUENTE_TITULO := "res://recursos/fonts/creato_display/CreatoDisplay-Bold.otf"
const FUENTE_CUERPO := "res://recursos/fonts/creato_display/CreatoDisplay-Medium.otf"

const COL_FONDO := Color(0.06, 0.07, 0.08, 0.78)
const COL_CARD := Color(0.09, 0.10, 0.12, 0.68)
const COL_BORDE := Color(0.78, 0.81, 0.85, 0.16)
const COL_ACENTO := Color(0.88, 0.68, 0.28, 0.78)
const COL_CERRAR := Color(0.78, 0.28, 0.26, 0.70)

var _area: Area3D = null
var _ui_layer: CanvasLayer = null
var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _lbl_estado: Label = null
var _badge_estado: Label = null
var _tarjetas: Array[PanelContainer] = []
var _trailer_actual: Node3D = null
var _entidades_dentro: Array[Node] = []
var _panel_mostrado_en_parada: bool = false
var _es_fantasma: bool = false


func _ready() -> void:
	var p: Node = get_parent()
	while p:
		if "Preview" in p.name or "Fantasma" in p.name:
			_es_fantasma = true
			return
		p = p.get_parent()

	_crear_area_deteccion()
	_precargar_trailers()
	set_notify_transform(true)
	call_deferred("_actualizar_alturas_proyeccion")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and not _es_fantasma:
		_actualizar_alturas_proyeccion()


func _actualizar_alturas_proyeccion() -> void:
	if get_parent() is Node3D:
		GeneradorModelosCiudad.actualizar_alturas_proyeccion_zona(get_parent() as Node3D)


func _precargar_trailers() -> void:
	var ruta_carpado := RUTA_CARPADO_1 if ResourceLoader.exists(RUTA_CARPADO_1) else RUTA_CARPADO_ALT
	if ResourceLoader.exists(ruta_carpado):
		ResourceLoader.load_threaded_request(ruta_carpado)
	if ResourceLoader.exists(RUTA_CHASIS):
		ResourceLoader.load_threaded_request(RUTA_CHASIS)


func _process(_delta: float) -> void:
	if _es_fantasma or _entidades_dentro.is_empty() or not _en_modo_juego():
		return
	var detenido := _entidad_detenida_en_zona()
	if detenido and not _panel_mostrado_en_parada:
		_panel_mostrado_en_parada = true
		_mostrar_ui()


func _entidad_detenida_en_zona() -> bool:
	for e in _entidades_dentro:
		if not is_instance_valid(e):
			continue
		if e is RigidBody3D:
			if (e as RigidBody3D).linear_velocity.length() < 0.6:
				return true
		elif e is CharacterBody3D:
			if (e as CharacterBody3D).velocity.length() < 0.6:
				return true
		else:
			return true
	return false


func _crear_area_deteccion() -> void:
	_area = Area3D.new()
	_area.name = "AreaAlquilerTrailer"
	_area.monitoring = true
	_area.monitorable = false
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.2, 3.8, 8.6)
	col.shape = box
	col.position = Vector3(0.0, 1.9, -7.8)
	_area.add_child(col)
	add_child(_area)

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _en_modo_juego() -> bool:
	var mp := get_tree().root.find_child("ModoPrueba", true, false)
	if mp and "en_prueba" in mp:
		return bool(mp.get("en_prueba"))
	var ed := get_tree().root.find_child("EditorMapas", true, false)
	if ed != null:
		return false
	return true


func _es_entidad_jugador(body: Node) -> bool:
	if not is_instance_valid(body):
		return false
	if body.is_in_group("jugador") or "jugador" in body.name.to_lower():
		return true
	if body is RigidBody3D and "activo" in body and bool(body.get("activo")):
		return true
	return false


func _on_body_entered(body: Node) -> void:
	if _es_fantasma or not _en_modo_juego():
		return
	if not _es_entidad_jugador(body):
		return
	if not _entidades_dentro.has(body):
		_entidades_dentro.append(body)


func _on_body_exited(body: Node) -> void:
	_entidades_dentro.erase(body)
	if _entidades_dentro.is_empty():
		_panel_mostrado_en_parada = false
		_ocultar_ui()


func _mostrar_ui() -> void:
	if not _ui_layer:
		_construir_ui()
	_ui_layer.visible = true
	if is_instance_valid(_backdrop):
		_backdrop.modulate.a = 0.0
		create_tween().tween_property(_backdrop, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_panel):
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.90, 0.90)
		_panel.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in range(_tarjetas.size()):
		var c := _tarjetas[i]
		if not is_instance_valid(c):
			continue
		c.modulate.a = 0.0
		var tw_c := create_tween()
		tw_c.tween_interval(0.05 * float(i + 1))
		tw_c.tween_property(c, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _ocultar_ui() -> void:
	if not is_instance_valid(_ui_layer) or not _ui_layer.visible:
		return
	if is_instance_valid(_panel):
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_panel, "scale", Vector2(0.94, 0.94), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_panel, "modulate:a", 0.0, 0.16)
		if is_instance_valid(_backdrop):
			tw.tween_property(_backdrop, "modulate:a", 0.0, 0.16)
		tw.chain().tween_callback(func():
			if is_instance_valid(_ui_layer):
				_ui_layer.visible = false
		)
	else:
		_ui_layer.visible = false


func _construir_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 45
	add_child(_ui_layer)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.03, 0.04, 0.34)
	_ui_layer.add_child(_backdrop)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(centro)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1260, 780)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.78, 0.81, 0.85, 0.24)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	sb.shadow_size = 24
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", sb)
	centro.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_panel.add_child(vbox)

	var fuente_mod: Font = load(FUENTE_MODERNIZ) if ResourceLoader.exists(FUENTE_MODERNIZ) else null
	var fuente_tit: Font = load(FUENTE_TITULO) if ResourceLoader.exists(FUENTE_TITULO) else fuente_mod
	var fuente_cuerpo: Font = load(FUENTE_CUERPO) if ResourceLoader.exists(FUENTE_CUERPO) else fuente_tit

	var hbox_head := HBoxContainer.new()
	hbox_head.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox_head)

	var lbl_tit := Label.new()
	lbl_tit.text = "ALQUILER DE TRAILER"
	lbl_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_tit.add_theme_font_size_override("font_size", 40)
	lbl_tit.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	if fuente_mod:
		lbl_tit.add_theme_font_override("font", fuente_mod)
	elif fuente_tit:
		lbl_tit.add_theme_font_override("font", fuente_tit)
	hbox_head.add_child(lbl_tit)

	var badge_box := PanelContainer.new()
	var sb_badge := StyleBoxFlat.new()
	sb_badge.bg_color = Color(0.88, 0.68, 0.28, 0.14)
	sb_badge.border_color = COL_ACENTO
	sb_badge.set_border_width_all(1)
	sb_badge.set_corner_radius_all(8)
	sb_badge.content_margin_left = 16
	sb_badge.content_margin_right = 16
	sb_badge.content_margin_top = 8
	sb_badge.content_margin_bottom = 8
	badge_box.add_theme_stylebox_override("panel", sb_badge)
	hbox_head.add_child(badge_box)

	_badge_estado = Label.new()
	_badge_estado.text = "DISPONIBLE"
	_badge_estado.add_theme_font_size_override("font_size", 18)
	_badge_estado.add_theme_color_override("font_color", COL_ACENTO)
	if fuente_mod:
		_badge_estado.add_theme_font_override("font", fuente_mod)
	badge_box.add_child(_badge_estado)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.14)
	vbox.add_child(sep)

	_lbl_estado = Label.new()
	_lbl_estado.text = "Selecciona el semirremolque que deseas desplegar en la bahia:"
	_lbl_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_estado.add_theme_font_size_override("font_size", 24)
	_lbl_estado.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 0.94))
	if fuente_cuerpo:
		_lbl_estado.add_theme_font_override("font", fuente_cuerpo)
	vbox.add_child(_lbl_estado)

	# Tarjetas lado a lado (Showroom 2 columnas)
	var grid_cards := HBoxContainer.new()
	grid_cards.add_theme_constant_override("separation", 22)
	grid_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_cards)

	_tarjetas.clear()
	var ruta_carpado := RUTA_CARPADO_1 if ResourceLoader.exists(RUTA_CARPADO_1) else RUTA_CARPADO_ALT
	var c1 := _crear_tarjeta_trailer(RUTA_CARPADO_GLB, "🚛", "Trailer Carpado", "Lona alta con varillas y compuertas abatibles", ["3 EJES", "HASTA 34 T", "CARPA"], fuente_mod, fuente_tit, fuente_cuerpo, func(card_ref):
		_pulsar_tarjeta(card_ref)
		_spawnear_trailer(ruta_carpado, "Trailer Carpado")
	)
	_tarjetas.append(c1)
	grid_cards.add_child(c1)

	var c2 := _crear_tarjeta_trailer(RUTA_CHASIS_GLB, "📦", "Chasis Portacontenedor", "Plataforma abierta reforzada para carga visible", ["3 EJES", "PLATAFORMA", "CONTENEDOR"], fuente_mod, fuente_tit, fuente_cuerpo, func(card_ref):
		_pulsar_tarjeta(card_ref)
		_spawnear_trailer(RUTA_CHASIS, "Chasis Portacontenedor")
	)
	_tarjetas.append(c2)
	grid_cards.add_child(c2)

	var btn_cerrar := _crear_boton("CERRAR", COL_CERRAR, fuente_mod if fuente_mod else fuente_tit)
	btn_cerrar.custom_minimum_size = Vector2(0, 72)
	btn_cerrar.add_theme_font_size_override("font_size", 24)
	btn_cerrar.pressed.connect(_ocultar_ui)
	vbox.add_child(btn_cerrar)


func _crear_tarjeta_trailer(ruta_preview_glb: String, ico: String, nombre: String, detalle: String, tags: Array[String], fuente_mod: Font, fuente_tit: Font, fuente_cuerpo: Font, cb: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.12, 0.90)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.78, 0.81, 0.85, 0.20)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)

	var vbox_card := VBoxContainer.new()
	vbox_card.add_theme_constant_override("separation", 14)
	card.add_child(vbox_card)

	var preview_box := _crear_preview_trailer(ruta_preview_glb, ico)
	vbox_card.add_child(preview_box)

	var lbl_nom := Label.new()
	lbl_nom.text = nombre
	lbl_nom.add_theme_font_size_override("font_size", 30)
	lbl_nom.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 1.0))
	if fuente_tit:
		lbl_nom.add_theme_font_override("font", fuente_tit)
	vbox_card.add_child(lbl_nom)

	var lbl_det := Label.new()
	lbl_det.text = detalle
	lbl_det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_det.add_theme_font_size_override("font_size", 22)
	lbl_det.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 0.92))
	if fuente_cuerpo:
		lbl_det.add_theme_font_override("font", fuente_cuerpo)
	vbox_card.add_child(lbl_det)

	var hbox_tags := HBoxContainer.new()
	hbox_tags.add_theme_constant_override("separation", 8)
	vbox_card.add_child(hbox_tags)
	for t in tags:
		var chip := PanelContainer.new()
		var sb_chip := StyleBoxFlat.new()
		sb_chip.bg_color = Color(0.88, 0.68, 0.28, 0.12)
		sb_chip.border_color = Color(0.88, 0.68, 0.28, 0.45)
		sb_chip.set_border_width_all(1)
		sb_chip.set_corner_radius_all(6)
		sb_chip.content_margin_left = 10
		sb_chip.content_margin_right = 10
		sb_chip.content_margin_top = 4
		sb_chip.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", sb_chip)
		var l_tag := Label.new()
		l_tag.text = t
		l_tag.add_theme_font_size_override("font_size", 15)
		l_tag.add_theme_color_override("font_color", Color(0.92, 0.76, 0.40, 0.98))
		if fuente_mod:
			l_tag.add_theme_font_override("font", fuente_mod)
		chip.add_child(l_tag)
		hbox_tags.add_child(chip)

	var btn := _crear_boton("ALQUILAR TRAILER", COL_ACENTO, fuente_mod if fuente_mod else fuente_tit)
	btn.custom_minimum_size = Vector2(0, 74)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): cb.call(card))
	vbox_card.add_child(btn)
	return card


func _pulsar_tarjeta(card: PanelContainer) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(0.97, 0.97), 0.08)
	tw.tween_property(card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _crear_boton(texto: String, borde_hover: Color, fuente: Font) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97, 1.0))
	if fuente:
		btn.add_theme_font_override("font", fuente)

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.08, 0.09, 0.11, 0.65)
	sb_n.set_border_width_all(1)
	sb_n.border_color = COL_BORDE
	sb_n.set_corner_radius_all(10)

	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.14, 0.16, 0.19, 0.85)
	sb_p.border_color = borde_hover

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_p)
	btn.add_theme_stylebox_override("pressed", sb_p)
	return btn


func _bahia_ocupada(centro_bahia: Vector3) -> String:
	var space := get_world_3d().direct_space_state
	if not space:
		return ""
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 3.0, 12.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(global_transform.basis, centro_bahia + Vector3(0.0, 1.85, 0.0))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excludes: Array[RID] = []
	if get_parent() is CollisionObject3D:
		excludes.append((get_parent() as CollisionObject3D).get_rid())
	if is_instance_valid(_trailer_actual) and _trailer_actual is CollisionObject3D:
		excludes.append((_trailer_actual as CollisionObject3D).get_rid())
	query.exclude = excludes

	var hits := space.intersect_shape(query, 16)
	for h in hits:
		var col: Object = h.get("collider")
		if col is RigidBody3D:
			return (col as Node).name
	return ""


func _spawnear_trailer(ruta_escena: String, nombre_tipo: String) -> void:
	var pos_bahia: Vector3 = global_position + (global_transform.basis * Vector3(0.0, 0.0, 7.5))
	var obstaculo := _bahia_ocupada(pos_bahia)
	if not obstaculo.is_empty():
		if _badge_estado:
			_badge_estado.text = "OCUPADA"
		if _lbl_estado:
			_lbl_estado.text = "La bahia trasera esta ocupada (%s). Despeja la zona trasera para desplegar el trailer." % obstaculo
		return

	if is_instance_valid(_trailer_actual):
		_trailer_actual.queue_free()
		_trailer_actual = null

	var pos_sp: Vector3 = pos_bahia + Vector3(0.0, 0.45, 0.0)
	var rot_sp := global_rotation
	var trailer := TrailerFactory.crear_trailer(ruta_escena, "rin_t2_cromo", pos_sp, rot_sp)
	if not trailer:
		if _lbl_estado:
			_lbl_estado.text = "No se pudo cargar el trailer."
		return

	var padre: Node = get_tree().current_scene
	if not padre:
		padre = get_tree().root
	trailer.set_meta("no_auto_reconectar", true)
	padre.add_child(trailer)
	trailer.global_position = pos_sp
	trailer.global_rotation = rot_sp
	_trailer_actual = trailer

	# Evitar que el tráiler recién desplegado se acople automáticamente al instante
	var bloqueo_hasta: float = (Time.get_ticks_msec() / 1000.0) + 1.5
	var eng_tr := trailer.find_child("Enganche", true, false)
	if eng_tr and "_tiempo_desenganche_bloqueo" in eng_tr:
		eng_tr.set("_tiempo_desenganche_bloqueo", bloqueo_hasta)
	for ent in _entidades_dentro:
		if is_instance_valid(ent):
			var eng_cam := ent.find_child("Enganche", true, false)
			if eng_cam and "_tiempo_desenganche_bloqueo" in eng_cam:
				eng_cam.set("_tiempo_desenganche_bloqueo", bloqueo_hasta)

	_ocultar_ui()
	var resumen: Array[Dictionary] = [
		{"label": "SEMIRREMOLQUE", "valor": nombre_tipo},
		{"label": "UBICACION", "valor": "Bahia trasera (sin enganchar)"},
	]
	ZonaCargaInteractiva.mostrar_notificacion_global(
		self,
		"ALQUILER · BAHIA TRASERA",
		"TRAILER DESPLEGADO",
		"Tu semirremolque aparecio en la bahia trasera sin enganchar. Retrocede suavemente con el cabezote para acoplarlo.",
		"LISTO",
		resumen
	)


func _crear_preview_trailer(ruta_glb: String, ico_fallback: String) -> PanelContainer:
	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(520, 240)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	sb.border_color = Color(0.78, 0.81, 0.85, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	marco.add_theme_stylebox_override("panel", sb)

	if not ResourceLoader.exists(ruta_glb):
		var lbl := Label.new()
		lbl.text = ico_fallback
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 48)
		marco.add_child(lbl)
		return marco

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(516, 236)
	marco.add_child(svc)

	var sv := SubViewport.new()
	sv.size = Vector2i(780, 360)
	sv.own_world_3d = true
	sv.world_3d = World3D.new()
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_2X
	sv.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(sv)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.90, 0.96)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	key_light.light_energy = 1.45
	sv.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-25.0, -140.0, 0.0)
	fill_light.light_energy = 0.70
	sv.add_child(fill_light)

	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.2
	cam.far = 200.0
	cam.current = true
	sv.add_child(cam)

	var packed := load(ruta_glb) as PackedScene
	if packed:
		var inst := packed.instantiate()
		sv.add_child(inst)
		var aabb := _calcular_aabb_recursivo(inst)
		var centro := aabb.get_center()
		var radio := maxf(aabb.size.length() * 0.5, 2.0)
		var dir_cam := Vector3(0.90, 0.34, -0.78).normalized()
		var cam_pos := centro + dir_cam * (radio * 2.35)
		cam.transform = Transform3D(Basis.looking_at((centro - cam_pos).normalized(), Vector3.UP), cam_pos)

	# Congelar a UPDATE_ONCE después de renderizar 2 frames ya montado en pantalla
	marco.tree_entered.connect(func():
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(sv):
			sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	)

	return marco


func _calcular_aabb_recursivo(nodo: Node) -> AABB:
	var res := AABB()
	var primero := true
	var cola: Array[Node] = [nodo]
	while not cola.is_empty():
		var actual: Node = cola.pop_back()
		if actual is VisualInstance3D and actual is Node3D:
			var vi := actual as VisualInstance3D
			var local_box := vi.get_aabb()
			var xform := (actual as Node3D).transform
			var p: Node = actual.get_parent()
			while p and p != nodo and p is Node3D:
				xform = (p as Node3D).transform * xform
				p = p.get_parent()
			var global_box := xform * local_box
			if primero:
				res = global_box
				primero = false
			else:
				res = res.merge(global_box)
		for h in actual.get_children():
			cola.append(h)
	return res
