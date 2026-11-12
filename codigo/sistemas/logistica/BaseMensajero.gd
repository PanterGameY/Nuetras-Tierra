extends Node3D
class_name BaseMensajero

# ═══════════════════════════════════════════════════════════════════════
# BaseMensajero.gd — Controlador de Áreas y Diálogos de la Oficina de Correos
# ═══════════════════════════════════════════════════════════════════════

@export_group("Nodos de Referencia")
## Ruta al nodo principal que tiene el script Mensajero.gd
@export var mensajero_node: Node3D = null
## Area3D para el spawn y retorno físico del vehículo de reparto
@export var area_vehiculo: Area3D = null
## Area3D para hablar con el NPC encargado
@export var area_dialogo: Area3D = null
## MeshInstance3D de la recepcionista para mostrar el diálogo flotante y recibir la tableta
@export var recepcionista_mesh: MeshInstance3D = null

@export_group("Diálogos")
@export var dialogo_ofrecer_trabajo: Resource = null
@export var dialogo_trabajo_activo: Resource = null
@export var dialogo_cobrar_trabajo: Resource = null

# Estado
var jugador_cerca: Node3D = null
var tableta_entregada: bool = false
var label_recepcionista: Label3D = null
var _recepcion_cl: CanvasLayer = null
var _recepcion_btn: Button = null

# UI interna
var _canvas_layer: CanvasLayer = null
var _ui_box: PanelContainer = null
var _text_label: RichTextLabel = null
var _buttons_box: BoxContainer = null

func _ready() -> void:
	if not mensajero_node:
		mensajero_node = get_node_or_null("Mensajero")
		if not mensajero_node and get_parent():
			mensajero_node = get_parent().get_node_or_null("Mensajero")

	# Crear marca visual en el suelo y Label3D flotante sobre el area_dialogo
	if area_dialogo:
		area_dialogo.body_entered.connect(_on_dialogo_body_entered)
		area_dialogo.body_exited.connect(_on_dialogo_body_exited)
		
		# 1. Label3D flotante
		var label3d = Label3D.new()
		label3d.text = "OFICINA DE MENSAJERIA"
		label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label3d.font_size = 72
		label3d.outline_size = 18
		label3d.modulate = Color(0.0, 0.85, 1.0) # Celeste neón muy brillante
		label3d.position = Vector3(0, 2.3, 0)
		area_dialogo.add_child(label3d)
		
		# 2. Marca cyan neón circular en el suelo
		var visual_floor = MeshInstance3D.new()
		var ring = CylinderMesh.new()
		ring.top_radius = 1.6
		ring.bottom_radius = 1.6
		ring.height = 0.03
		ring.radial_segments = 32
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.0, 0.85, 1.0, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.85, 1.0)
		mat.emission_energy_multiplier = 5.0
		
		visual_floor.mesh = ring
		visual_floor.material_override = mat
		visual_floor.position = Vector3(0.0, -0.95, 0.0)
		area_dialogo.add_child(visual_floor)

	if area_vehiculo:
		area_vehiculo.body_entered.connect(_on_vehiculo_body_entered)

func _on_dialogo_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		jugador_cerca = body
		
		# Evitar abrir automáticamente el diálogo si el jugador está ocupado cargando o en ruta de entrega
		if is_instance_valid(mensajero_node):
			var estado = mensajero_node.get("estado_actual")
			if estado == 1 or estado == 3: # CARGANDO (1) o ENTREGANDO (3)
				return
				
		_mostrar_opciones_dialogo()

func _on_dialogo_body_exited(body: Node3D) -> void:
	if body == jugador_cerca:
		jugador_cerca = null
		_cerrar_dialogo()

func _on_vehiculo_body_entered(body: Node3D) -> void:
	if not is_instance_valid(mensajero_node):
		return
		
	var vehiculo_trabajo = mensajero_node.get("vehiculo_instanciado")
	var estado_actual = mensajero_node.get("estado_actual")
	
	# Estado 4 es EstadoTrabajo.RETORNANDO
	if body == vehiculo_trabajo and estado_actual == 4:
		# En lugar de cobrar automáticamente al pisar, notificar al jugador que vaya a hablar con logística
		if mensajero_node.has_method("_mostrar_notificacion"):
			mensajero_node.call("_mostrar_notificacion", "Furgo estacionado. Baja del vehiculo y ve a cobrar con el Jefe de Logistica.")


# ─── Lógica de Diálogos y UI ────────────────────────────────────────────

func _mostrar_opciones_dialogo() -> void:
	if not jugador_cerca or not is_instance_valid(mensajero_node):
		return

	var estado = mensajero_node.get("estado_actual")
	
	# Si el jugador está viendo la cinemática de inicio, no interrumpir ni mostrar diálogos automáticos
	if jugador_cerca and jugador_cerca.has_meta("cinematic_active") and jugador_cerca.get_meta("cinematic_active") == true:
		return

	var npc_nombre = "JEFE DE LOGISTICA"
	var texto_dialogo = ""
	var opciones = []

	match estado:
		0: # INACTIVO
			texto_dialogo = "Ey, conductor. Justo a tiempo. Tengo el almacen reventado de paquetes y necesito alguien de confianza al volante. ¿Estas listo para salir a ruta o vine a interrumpirte el descanso?"
			opciones = [
				{"texto": "Listo. Dame la ruta.", "accion": "elegir_ruta"},
				{"texto": "¿Cuanto pagan?", "accion": "preguntar_pago"},
				{"texto": "Hoy no puedo, Jefe.", "accion": "cerrar"}
			]
		1: # CARGANDO
			var total = mensajero_node.get("total_entregas_mision")
			var cargadas = mensajero_node.get("cajas_cargadas")
			texto_dialogo = "El furgo no se carga solo, conductor. Faltan %d cajas. Llevas %d de %d. Apurate antes de que el turno se acabe." % [total - cargadas, cargadas, total]
			opciones = [
				{"texto": "Ya casi termino.", "accion": "cerrar"},
				{"texto": "Dejalo, cancelo la ruta. (-$50)", "accion": "cancelar"}
			]
		2: # LISTO_PARA_PARTIR
			texto_dialogo = "Todo el cargamento esta dentro. Ruta validada, papeles en orden. Solo falta que tu apretes el acelerador. ¿Salimos o te quedas aqui mirando?"
			opciones = [
				{"texto": "Confirmo salida. Voy.", "accion": "confirmar_salida"},
				{"texto": "Dame un segundo.", "accion": "cerrar"}
			]
		3: # ENTREGANDO
			texto_dialogo = "Oye, ¿que haces aqui? Todavia tienes paquetes afuera esperando. Mira el GPS y termina lo que empezaste."
			opciones = [
				{"texto": "Voy de una.", "accion": "cerrar"},
				{"texto": "Mejor lo cancelo. (-$50)", "accion": "cancelar"}
			]
		4: # RETORNANDO
			texto_dialogo = "Buen trabajo, conductor. Todas las entregas completas. Deja el furgo en su lugar y ven a cobrar tu tajada. Te lo ganaste."
			opciones = [
				{"texto": "Cobrar y entregar el furgo.", "accion": "cobrar"},
				{"texto": "Espera, ya vengo.", "accion": "cerrar"}
			]

	_dibujar_interfaz_dialogo(npc_nombre, texto_dialogo, opciones)

func _dibujar_interfaz_dialogo(nombre_npc: String, mensaje: String, opciones: Array) -> void:
	_cerrar_dialogo()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var nombre_limpio = _quitar_tildes(nombre_npc)
	var mensaje_limpio = _quitar_tildes(mensaje)

	# ── Cargar fuente Moderniz ────────────────────────────────────────────
	var font_path = "res://recursos/fonts/Moderniz.otf"
	var moderniz: Font = null
	if ResourceLoader.exists(font_path):
		moderniz = load(font_path)

	# ── Canvas ───────────────────────────────────────────────────────────
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 120
	add_child(_canvas_layer)

	# ── Raiz pantalla completa ────────────────────────────────────────────
	var root_ctrl = Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(root_ctrl)

	# ── Dimmer zona superior ──────────────────────────────────────────────
	var dimmer = ColorRect.new()
	dimmer.anchor_left   = 0.0
	dimmer.anchor_top    = 0.0
	dimmer.anchor_right  = 1.0
	dimmer.anchor_bottom = 0.36
	dimmer.offset_left   = 0
	dimmer.offset_top    = 0
	dimmer.offset_right  = 0
	dimmer.offset_bottom = 0
	dimmer.color = Color(0.0, 0.0, 0.0, 0.55)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(dimmer)

	# ── Panel principal ───────────────────────────────────────────────────
	_ui_box = PanelContainer.new()
	_ui_box.anchor_left   = 0.0
	_ui_box.anchor_top    = 0.36
	_ui_box.anchor_right  = 1.0
	_ui_box.anchor_bottom = 1.0
	_ui_box.offset_left   = 0
	_ui_box.offset_top    = 0
	_ui_box.offset_right  = 0
	_ui_box.offset_bottom = 0

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.03, 0.03, 0.06, 0.97)
	bg_style.border_width_top = 4
	bg_style.border_color = Color(0.95, 0.76, 0.0, 1.0)
	bg_style.set_content_margin_all(0)
	_ui_box.add_theme_stylebox_override("panel", bg_style)
	root_ctrl.add_child(_ui_box)

	# ── Layout vertical principal ─────────────────────────────────────────
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	_ui_box.add_child(main_vbox)

	# ── HEADER — nombre del NPC ───────────────────────────────────────────
	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 92)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.06, 0.05, 0.02, 1.0)
	header_style.border_width_bottom = 3
	header_style.border_color = Color(0.95, 0.76, 0.0, 0.70)
	header_style.set_content_margin_all(0)
	header.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header)

	var gold_bar = ColorRect.new()
	gold_bar.anchor_left   = 0.0
	gold_bar.anchor_top    = 0.15
	gold_bar.anchor_right  = 0.0
	gold_bar.anchor_bottom = 0.85
	gold_bar.offset_left   = 0
	gold_bar.offset_right  = 8
	gold_bar.offset_top    = 0
	gold_bar.offset_bottom = 0
	gold_bar.color = Color(0.95, 0.76, 0.0, 1.0)
	gold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(gold_bar)

	var npc_name_lbl = Label.new()
	npc_name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	npc_name_lbl.offset_left  = 26
	npc_name_lbl.offset_right = -16
	npc_name_lbl.text = nombre_limpio
	npc_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	npc_name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	npc_name_lbl.add_theme_font_size_override("font_size", 40)
	npc_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.76, 0.0))
	npc_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if moderniz:
		npc_name_lbl.add_theme_font_override("font", moderniz)
	header.add_child(npc_name_lbl)

	# ── TEXTO DEL DIALOGO ─────────────────────────────────────────────────
	var text_margin = MarginContainer.new()
	text_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_margin.add_theme_constant_override("margin_left",   32)
	text_margin.add_theme_constant_override("margin_right",  32)
	text_margin.add_theme_constant_override("margin_top",    24)
	text_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(text_margin)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled  = true
	_text_label.scroll_active   = false
	_text_label.fit_content     = false
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.add_theme_color_override("default_color", Color(0.93, 0.93, 0.97))
	_text_label.add_theme_font_size_override("normal_font_size", 40)
	if moderniz:
		_text_label.add_theme_font_override("normal_font", moderniz)
	_text_label.text = mensaje_limpio
	text_margin.add_child(_text_label)

	# ── SEPARADOR DORADO ─────────────────────────────────────────────────
	var sep = ColorRect.new()
	sep.color = Color(0.95, 0.76, 0.0, 0.30)
	sep.custom_minimum_size = Vector2(0, 3)
	main_vbox.add_child(sep)

	# ── OPCIONES — botones separados con caja y borde ─────────────────────
	var btn_margin = MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_left",   18)
	btn_margin.add_theme_constant_override("margin_right",  18)
	btn_margin.add_theme_constant_override("margin_top",    18)
	btn_margin.add_theme_constant_override("margin_bottom", 18)
	main_vbox.add_child(btn_margin)

	var options_vbox = VBoxContainer.new()
	options_vbox.add_theme_constant_override("separation", 14)
	options_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_margin.add_child(options_vbox)
	_buttons_box = options_vbox

	# Normal: caja oscura dorada, texto gold
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color                    = Color(0.07, 0.06, 0.02, 1.0)
	sb_n.border_width_left           = 2
	sb_n.border_width_top            = 2
	sb_n.border_width_right          = 2
	sb_n.border_width_bottom         = 2
	sb_n.border_color                = Color(0.95, 0.76, 0.0, 0.60)
	sb_n.corner_radius_top_left      = 12
	sb_n.corner_radius_top_right     = 12
	sb_n.corner_radius_bottom_left   = 12
	sb_n.corner_radius_bottom_right  = 12
	sb_n.content_margin_left         = 28
	sb_n.content_margin_right        = 28
	sb_n.content_margin_top          = 0
	sb_n.content_margin_bottom       = 0

	# Hover: relleno dorado completo, texto negro
	var sb_h = StyleBoxFlat.new()
	sb_h.bg_color                    = Color(0.95, 0.76, 0.0, 1.0)
	sb_h.border_width_left           = 2
	sb_h.border_width_top            = 2
	sb_h.border_width_right          = 2
	sb_h.border_width_bottom         = 2
	sb_h.border_color                = Color(1.0, 0.92, 0.30, 1.0)
	sb_h.corner_radius_top_left      = 12
	sb_h.corner_radius_top_right     = 12
	sb_h.corner_radius_bottom_left   = 12
	sb_h.corner_radius_bottom_right  = 12
	sb_h.content_margin_left         = 28
	sb_h.content_margin_right        = 28
	sb_h.content_margin_top          = 0
	sb_h.content_margin_bottom       = 0

	var sb_p = sb_h.duplicate()
	sb_p.bg_color = Color(1.0, 0.88, 0.10, 1.0)

	var sb_foc = StyleBoxFlat.new()
	sb_foc.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb_foc.set_content_margin_all(0)

	for opcion in opciones:
		var btn = Button.new()
		btn.text = _quitar_tildes(opcion["texto"])
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.flat = false
		btn.custom_minimum_size = Vector2(0, 88)
		btn.add_theme_font_size_override("font_size", 36)
		btn.add_theme_color_override("font_color",         Color(0.95, 0.76, 0.0))
		btn.add_theme_color_override("font_hover_color",   Color(0.04, 0.04, 0.06))
		btn.add_theme_color_override("font_pressed_color", Color(0.10, 0.08, 0.0))
		btn.add_theme_stylebox_override("normal",  sb_n)
		btn.add_theme_stylebox_override("hover",   sb_h)
		btn.add_theme_stylebox_override("pressed", sb_p)
		btn.add_theme_stylebox_override("focus",   sb_foc)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if moderniz:
			btn.add_theme_font_override("font", moderniz)

		var action = opcion["accion"]
		if action == "iniciar":
			btn.pressed.connect(dialog_accion_iniciar)
		elif action == "confirmar_salida":
			btn.pressed.connect(dialog_accion_confirmar_salida)
		elif action == "cobrar":
			btn.pressed.connect(dialog_accion_cobrar)
		elif action == "cancelar":
			btn.pressed.connect(dialog_accion_cancelar)
		elif action == "cerrar":
			btn.pressed.connect(dialog_accion_cerrar)
		elif action == "elegir_ruta":
			btn.pressed.connect(dialog_accion_elegir_ruta)
		elif action == "preguntar_pago":
			btn.pressed.connect(dialog_accion_preguntar_pago)
		elif action == "mostrar_bienvenida":
			btn.pressed.connect(_mostrar_opciones_dialogo)
		elif action == "iniciar_corta":
			btn.pressed.connect(func(): dialog_accion_iniciar_personalizada(2))
		elif action == "iniciar_media":
			btn.pressed.connect(func(): dialog_accion_iniciar_personalizada(4))
		elif action == "iniciar_larga":
			btn.pressed.connect(func(): dialog_accion_iniciar_personalizada(7))

		options_vbox.add_child(btn)


# ─── Eventos de Botones ─────────────────────────────────────────────────
# Opciones interactivas del Jefe de Logistica
func dialog_accion_elegir_ruta() -> void:
	var opciones = [
		{"texto": "Express — 2 paradas", "accion": "iniciar_corta"},
		{"texto": "Estandar — 4 paradas", "accion": "iniciar_media"},
		{"texto": "Ruta Pesada — 7 paradas", "accion": "iniciar_larga"},
		{"texto": "Espera, vuelvo.", "accion": "mostrar_bienvenida"}
	]
	_dibujar_interfaz_dialogo("JEFE DE LOGISTICA", "Elige tu carga para hoy. Mas paradas, mas plata. Pero el tiempo corre y la ciudad no espera.", opciones)

func dialog_accion_preguntar_pago() -> void:
	var opciones = [
		{"texto": "Me convence. Dame la ruta.", "accion": "elegir_ruta"},
		{"texto": "Mejor en otro momento.", "accion": "cerrar"}
	]
	_dibujar_interfaz_dialogo("JEFE DE LOGISTICA", "Base: $200 por ruta completa. Mas $2.50 por cada metro que recorras en la ciudad. Haz bien el trabajo y el efectivo llega solo. ¿Te animas?", opciones)

func dialog_accion_iniciar_personalizada(cant_entregas: int) -> void:
	if is_instance_valid(mensajero_node):
		mensajero_node.set("min_entregas_por_ruta", cant_entregas)
		mensajero_node.set("max_entregas_por_ruta", cant_entregas)
		dialog_accion_iniciar()

func dialog_accion_iniciar() -> void:
	if is_instance_valid(mensajero_node):
		if area_vehiculo:
			mensajero_node.set("spawn_vehiculo_posicion", area_vehiculo.global_position)
			mensajero_node.set("base_posicion", area_vehiculo.global_position)
		if mensajero_node.has_method("iniciar_trabajo"):
			mensajero_node.call("iniciar_trabajo")
			
		_cerrar_dialogo()

func dialog_accion_cobrar() -> void:
	if is_instance_valid(mensajero_node) and mensajero_node.has_method("terminar_y_cobrar"):
		mensajero_node.call("terminar_y_cobrar")
		dialog_accion_cerrar()

func dialog_accion_confirmar_salida() -> void:
	if is_instance_valid(mensajero_node) and mensajero_node.has_method("confirmar_salida_ruta"):
		mensajero_node.call("confirmar_salida_ruta")
		dialog_accion_cerrar()

func dialog_accion_cancelar() -> void:
	if is_instance_valid(mensajero_node) and mensajero_node.has_method("cancelar_trabajo"):
		mensajero_node.call("cancelar_trabajo")
		_cerrar_dialogo() # Esto ya no bloquea el mouse
		_dibujar_interfaz_dialogo("JEFE DE LOGISTICA", "Ruta cancelada. Se descontaron $50 de tu pago. La proxima, piensalo dos veces antes de arrancar.", [
			{"texto": "Entendido, Jefe.", "accion": "cerrar"}
		])

func dialog_accion_cerrar() -> void:
	_cerrar_dialogo()


func _cerrar_dialogo() -> void:
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	
	_canvas_layer = null
	_ui_box = null
	_text_label = null
	_buttons_box = null

func _exit_tree() -> void:
	_cerrar_dialogo()

# ─── Helpers ────────────────────────────────────────────────────────────

func _quitar_tildes(texto: String) -> String:
	var reemplazos = {
		"a": "a", "e": "e", "i": "i", "o": "o", "u": "u",
		"A": "A", "E": "E", "I": "I", "O": "O", "U": "U",
		"n": "n", "N": "N"
	}
	var resultado = texto
	for original in reemplazos:
		resultado = resultado.replace(original, reemplazos[original])
	return resultado

# ─── Recepcionista & Tableta Handover ───────────────────────────────────

func _process(delta: float) -> void:
	if recepcionista_mesh:
		var player = _find_player()
		if player:
			var dist = player.global_position.distance_to(recepcionista_mesh.global_position)
			if dist < 2.0:
				jugador_cerca = player
				_actualizar_dialogo_recepcionista(true)
			else:
				_actualizar_dialogo_recepcionista(false)

func _actualizar_dialogo_recepcionista(cerca: bool) -> void:
	if not cerca:
		if is_instance_valid(label_recepcionista):
			label_recepcionista.visible = false
		_ocultar_boton_recepcion()
		return

	# Asegurar que el Label3D exista sobre la recepcionista
	if not is_instance_valid(label_recepcionista):
		label_recepcionista = Label3D.new()
		label_recepcionista.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_recepcionista.font_size = 24
		label_recepcionista.outline_size = 6
		label_recepcionista.modulate = Color(1.0, 0.9, 0.2) # Amarillo/oro agradable
		# Posicionarlo flotando por encima del mesh de la recepcionista
		label_recepcionista.position = Vector3(0, 1.15, 0)
		label_recepcionista.autowrap_mode = TextServer.AUTOWRAP_WORD
		label_recepcionista.width = 300.0
		recepcionista_mesh.add_child(label_recepcionista)

	label_recepcionista.visible = true

	if not tableta_entregada:
		label_recepcionista.text = "RECEPCIONISTA:\nHola, conductor. Toma, te entrego esta tableta de reparto para que veas tus destinos y el GPS.\nRecuerda posicionarla en el vehiculo."
		
		# Mostrar botón en pantalla para móviles
		_mostrar_boton_recepcion()
		
		# Leer interacción de teclado como fallback
		if Input.is_key_pressed(KEY_E) or Input.is_action_just_pressed("ui_accept"):
			tableta_entregada = true
			_entregar_tableta_a_jugador()
			_ocultar_boton_recepcion()
	else:
		label_recepcionista.text = "RECEPCIONISTA:\nListo, ya tienes la tableta.\nLlevala a tu vehiculo para activar el GPS."
		_ocultar_boton_recepcion()

func _mostrar_boton_recepcion() -> void:
	if not is_instance_valid(_recepcion_btn):
		_recepcion_cl = CanvasLayer.new()
		_recepcion_cl.layer = 110
		add_child(_recepcion_cl)
		
		_recepcion_btn = Button.new()
		_recepcion_btn.text = "RECIBIR TABLETA"
		_recepcion_btn.custom_minimum_size = Vector2(280, 90)
		
		# Centrado inferior
		_recepcion_btn.anchor_left = 0.5
		_recepcion_btn.anchor_right = 0.5
		_recepcion_btn.anchor_top = 0.75
		_recepcion_btn.anchor_bottom = 0.75
		_recepcion_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_recepcion_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
		
		var sb_n = StyleBoxFlat.new()
		sb_n.bg_color = Color(0.0, 0.65, 0.85, 0.9)
		sb_n.border_width_bottom = 4
		sb_n.border_color = Color(0.0, 0.45, 0.65, 1.0)
		sb_n.corner_radius_top_left = 16
		sb_n.corner_radius_top_right = 16
		sb_n.corner_radius_bottom_left = 16
		sb_n.corner_radius_bottom_right = 16
		
		var sb_p = sb_n.duplicate()
		sb_p.bg_color = Color(0.0, 0.45, 0.65, 1.0)
		
		_recepcion_btn.add_theme_stylebox_override("normal", sb_n)
		_recepcion_btn.add_theme_stylebox_override("hover", sb_n)
		_recepcion_btn.add_theme_stylebox_override("pressed", sb_p)
		_recepcion_btn.add_theme_color_override("font_color", Color.WHITE)
		_recepcion_btn.add_theme_font_size_override("font_size", 28)
		
		var font_path = "res://recursos/fonts/Moderniz.otf"
		if ResourceLoader.exists(font_path):
			_recepcion_btn.add_theme_font_override("font", load(font_path))
			
		_recepcion_btn.pressed.connect(func():
			tableta_entregada = true
			_entregar_tableta_a_jugador()
			_ocultar_boton_recepcion()
		)
		_recepcion_cl.add_child(_recepcion_btn)

func _ocultar_boton_recepcion() -> void:
	if is_instance_valid(_recepcion_cl):
		_recepcion_cl.queue_free()
	_recepcion_cl = null
	_recepcion_btn = null

func _entregar_tableta_a_jugador() -> void:
	if jugador_cerca:
		var tableta_scene = load("res://modelos3d/inventario/tableta.tscn")
		if tableta_scene:
			var tableta_instance = tableta_scene.instantiate()
			tableta_instance.name = "tableta" # Asegurar nombre para matching
			
			if inventario_has_room_and_added(jugador_cerca, tableta_instance):
				# Ocultarla físicamente
				tableta_instance.visible = false
				
				if is_instance_valid(mensajero_node) and mensajero_node.has_method("_mostrar_notificacion"):
					mensajero_node.call("_mostrar_notificacion", "Has recibido la Tableta de Reparto. Abre tu Inventario para verla.")

func inventario_has_room_and_added(player: Node, item: Node3D) -> bool:
	var inv = player.get("inventario")
	if inv and inv.has_method("agregar_item"):
		var added = inv.call("agregar_item", item.name, item)
		if added:
			if item.get_parent():
				item.get_parent().remove_child(item)
			player.get_tree().current_scene.add_child(item)
			return true
	return false

func _find_player() -> Node3D:
	if jugador_cerca:
		return jugador_cerca
	var p = get_tree().get_first_node_in_group("jugador")
	if p:
		return p as Node3D
	return _find_player_recursive(get_tree().root)

func _find_player_recursive(node: Node) -> Node3D:
	if node.name.to_lower().contains("jugador") or node.name.to_lower().contains("player"):
		if node is CharacterBody3D:
			return node as Node3D
	for child in node.get_children():
		var res = _find_player_recursive(child)
		if res:
			return res
	return null
