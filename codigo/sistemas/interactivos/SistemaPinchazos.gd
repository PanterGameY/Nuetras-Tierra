# SistemaPinchazos.gd - Sistema de Pinchazos, Rueda de Repuesto y Gato Hidráulico
# Desarrollado para Nuestra Tierra 2.0 (Godot 4.7) - Panter Studio
# Gestiona la presión de neumáticos, deformación por pinchazo, uso obligatorio del gato hidráulico,
# animación de agacharse del jugador, minijuego interactivo de pernos y solicitud de asistencia técnica.
extends Node
class_name SistemaPinchazos

signal rueda_pinchada(nombre_rueda: String)
signal rueda_reparada(nombre_rueda: String)
signal requiere_mecanico_carretera(posicion_camion: Vector3)

static var instance: SistemaPinchazos = null

@export_group("Configuración de Neumáticos")
@export var presion_nominal_psi: float = 110.0
@export var probabilidad_pinchazo_por_km: float = 0.0025 # Ocurrencia realista de clavos/objetos en carretera
@export var desinflado_inmediato: bool = false

@export_group("Repuesto del Vehículo")
@export var rueda_repuesto_disponible: bool = true
@export var repuesto_pinchado: bool = false

# Estado de las ruedas instaladas en el camión
var ruedas_estado: Dictionary = {
	"delantera_izq": {"presion": 110.0, "pinchada": false, "area_3d": null, "raycast": null, "gato_puesto": false},
	"delantera_der": {"presion": 110.0, "pinchada": false, "area_3d": null, "raycast": null, "gato_puesto": false},
	"trasera_izq_1": {"presion": 110.0, "pinchada": false, "area_3d": null, "raycast": null, "gato_puesto": false},
	"trasera_der_1": {"presion": 110.0, "pinchada": false, "area_3d": null, "raycast": null, "gato_puesto": false},
	"trasera_izq_2": {"presion": 110.0, "pinchada": false, "area_3d": null, "raycast": null, "gato_puesto": false},
	"trasera_der_2": {"presion": 110.0, "pinchada": false, "area_3d": null, "raycast": null, "gato_puesto": false}
}

# Estado del gato hidráulico y elevación
var gato_colocado: bool = false
var vehiculo_levantado: bool = false
var rueda_en_reparacion: String = ""
var nodo_gato_3d: Node3D = null

# Referencias
var coche: RigidBody3D = null
var jugador: CharacterBody3D = null
var altura_camara_original: float = 1.75
var _distancia_recorrida_m: float = 0.0
var _posicion_anterior: Vector3 = Vector3.ZERO

func _ready() -> void:
	instance = self
	add_to_group("sistema_pinchazos")
	
	var p = get_parent()
	while p and not p is RigidBody3D:
		p = p.get_parent()
	coche = p as RigidBody3D
	
	if coche:
		_posicion_anterior = coche.global_position
		call_deferred("_inicializar_areas_interaccion_ruedas")

func _physics_process(delta: float) -> void:
	if not coche or not coche.is_inside_tree():
		return
		
	# Calcular desgaste por rodadura y probabilidad de pinchazo
	var vel_ms = coche.linear_velocity.length()
	if vel_ms > 2.0:
		var dist_delta = coche.global_position.distance_to(_posicion_anterior)
		_distancia_recorrida_m += dist_delta
		_posicion_anterior = coche.global_position
		
		# Cada 500 metros evalúa riesgo de pinchazo aleatorio si no hay rueda ya pinchada
		if _distancia_recorrida_m > 500.0:
			_distancia_recorrida_m = 0.0
			_evaluar_riesgo_pinchazo_aleatorio()

	# Aplicar física de pinchazo (desviación de dirección e inclinación de suspensión)
	_aplicar_efectos_fisicos_pinchazo(delta)

func _evaluar_riesgo_pinchazo_aleatorio() -> void:
	if tiene_rueda_pinchada():
		return
	if randf() < probabilidad_pinchazo_por_km:
		var llaves = ruedas_estado.keys()
		var rueda_afectada = llaves[randi() % llaves.size()]
		pinchar_rueda(rueda_afectada)

func pinchar_rueda(nombre_rueda: String) -> void:
	if not ruedas_estado.has(nombre_rueda):
		return
	var r = ruedas_estado[nombre_rueda]
	if r["pinchada"]:
		return
		
	r["pinchada"] = true
	r["presion"] = 0.0
	
	# Sonido diegético de estallido / escape de aire a presión
	_reproducir_sfx_pinchazo()
	
	# Modificar el RayCast3D correspondiente (reducir largo de reposo para simular rueda desinflada)
	if r["raycast"] and is_instance_valid(r["raycast"]):
		if "largo_reposo" in r["raycast"]:
			r["raycast"].largo_reposo = max(0.12, r["raycast"].largo_reposo - 0.16)
		if "agarre_lateral" in r["raycast"]:
			r["raycast"].agarre_lateral *= 0.35
		if "agarre_longitudinal" in r["raycast"]:
			r["raycast"].agarre_longitudinal *= 0.40

	emit_signal("rueda_pinchada", nombre_rueda)
	
	# Notificar a la tableta CelularUI
	if CelularUI.instance:
		if tiene_ambas_ruedas_inutilizadas():
			CelularUI.instance.notificar("🚨 ¡NEUMÁTICO REVENTADO SIN REPUESTO! Llama al Mecánico de Carretera desde la Tableta.", "alerta")
			emit_signal("requiere_mecanico_carretera", coche.global_position if coche else Vector3.ZERO)
		else:
			CelularUI.instance.notificar("⚠️ ¡NEUMÁTICO PINCHADO (%s)! Baja a colocar el Gato Hidráulico para reparar." % nombre_rueda.to_upper(), "alerta")

func tiene_rueda_pinchada() -> bool:
	for k in ruedas_estado:
		if ruedas_estado[k]["pinchada"]:
			return true
	return false

func obtener_primera_rueda_pinchada() -> String:
	for k in ruedas_estado:
		if ruedas_estado[k]["pinchada"]:
			return k
	return ""

func tiene_ambas_ruedas_inutilizadas() -> bool:
	# Si hay rueda pinchada y NO hay repuesto disponible (o el repuesto también está pinchado)
	return tiene_rueda_pinchada() and (not rueda_repuesto_disponible or repuesto_pinchado)

func _aplicar_efectos_fisicos_pinchazo(delta: float) -> void:
	if not coche:
		return
	for k in ruedas_estado:
		if ruedas_estado[k]["pinchada"]:
			# Fuerza lateral y desbalance según lado afectado
			var es_izq = k.contains("izq")
			var fuerza_desviacion = Vector3.LEFT if es_izq else Vector3.RIGHT
			var torque_giro = -0.15 if es_izq else 0.15
			
			# Vibración / cabeceo rítmico proporcional a la velocidad
			var vel_kmh = coche.linear_velocity.length() * 3.6
			if vel_kmh > 15.0:
				var factor_vibracion = sin(Time.get_ticks_msec() * 0.035) * clampf(vel_kmh * 15.0, 50.0, 600.0)
				coche.apply_torque(Vector3(factor_vibracion, 0.0, factor_vibracion * 0.5))

func _inicializar_areas_interaccion_ruedas() -> void:
	if not coche:
		return
		
	# Buscar los RayCast3D de ruedas pesadas (llanta_pesada.gd)
	var nodos_rueda = coche.find_children("*", "RayCast3D", true, false)
	for r_nodo in nodos_rueda:
		var n_lower = r_nodo.name.to_lower()
		for k in ruedas_estado.keys():
			if n_lower.contains(k) or (n_lower.contains("fl") and k.contains("delantera_izq")) or (n_lower.contains("fr") and k.contains("delantera_der")):
				ruedas_estado[k]["raycast"] = r_nodo
				_crear_area_interaccion_rueda(k, r_nodo)
				break

func _crear_area_interaccion_rueda(nombre_rueda: String, nodo_rueda: Node3D) -> void:
	var area = Area3D.new()
	area.name = "AreaRueda_" + nombre_rueda
	area.collision_layer = 4 # Capa de interacción jugador
	area.collision_mask = 2  # Jugador
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.2, 1.4, 1.2)
	col.shape = box
	area.add_child(col)
	
	# Prompt visual 3D
	var label_prompt = Label3D.new()
	label_prompt.name = "PromptRueda"
	label_prompt.text = "🔧 [E / Toque] Inspeccionar Rueda"
	label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_prompt.font_size = 28
	label_prompt.modulate = Color(1.0, 0.85, 0.20, 1.0)
	label_prompt.position = Vector3(0.0, 0.8, 0.0)
	label_prompt.visible = false
	area.add_child(label_prompt)
	
	area.body_entered.connect(func(body):
		if body.is_in_group("jugador") or body is CharacterBody3D:
			jugador = body as CharacterBody3D
			label_prompt.visible = true
			_actualizar_texto_prompt(nombre_rueda, label_prompt)
	)
	
	area.body_exited.connect(func(body):
		if body == jugador:
			label_prompt.visible = false
			jugador = null
	)
	
	nodo_rueda.add_child(area)
	ruedas_estado[nombre_rueda]["area_3d"] = area

func _actualizar_texto_prompt(nombre_rueda: String, label: Label3D) -> void:
	var r = ruedas_estado[nombre_rueda]
	if not r["pinchada"]:
		label.text = "✅ Neumático %s (110 PSI - Óptimo)" % nombre_rueda.replace("_", " ").capitalize()
		label.modulate = Color(0.2, 1.0, 0.4)
	elif tiene_ambas_ruedas_inutilizadas():
		label.text = "🚨 SIN REPUESTO DISPONIBLE\nLlama al Mecánico de Carretera desde la Tableta"
		label.modulate = Color(1.0, 0.2, 0.2)
	elif not gato_colocado or not vehiculo_levantado:
		label.text = "⚠️ [E] Colocar y Accionar Gato Hidráulico\n(Obligatorio para levantar el vehículo antes de desmontar)"
		label.modulate = Color(1.0, 0.6, 0.1)
	else:
		label.text = "🛠️ [E] Iniciar Cambio de Rueda (Agacharse y soltar pernos)"
		label.modulate = Color(0.2, 0.8, 1.0)

func interactuar_con_rueda(nombre_rueda: String) -> void:
	if not ruedas_estado.has(nombre_rueda):
		return
	var r = ruedas_estado[nombre_rueda]
	if not r["pinchada"]:
		if CelularUI.instance:
			CelularUI.instance.notificar("Este neumático está calibrado a 110 PSI en perfectas condiciones.", "info")
		return

	# Si no hay repuesto disponible
	if tiene_ambas_ruedas_inutilizadas():
		if CelularUI.instance:
			CelularUI.instance.notificar("¡No tienes rueda de repuesto! Abre la Tableta y solicita Asistencia Mecánica en Carretera.", "alerta")
			CelularUI.instance.call("_switch_app", "soporte")
		return

	# Paso 1: Requerir gato hidráulico obligatorio
	if not gato_colocado or not vehiculo_levantado:
		_colocar_y_accionar_gato_hidraulico(nombre_rueda)
		return

	# Paso 2: Si el camión ya está levantado, iniciar cambio con animación de agacharse y minijuego
	_iniciar_proceso_cambio_rueda(nombre_rueda)

func _colocar_y_accionar_gato_hidraulico(nombre_rueda: String) -> void:
	rueda_en_reparacion = nombre_rueda
	gato_colocado = true
	
	if CelularUI.instance:
		CelularUI.instance.notificar("Posicionando gato hidráulico bajo el chasis...", "info")
		
	# Crear representación visual 3D del gato hidráulico si no existe
	if not is_instance_valid(nodo_gato_3d):
		var escena_gato := load("res://modelos3d/inventario/Gato-Hidraulico/gato_hidraulico.tscn") as PackedScene
		if escena_gato:
			nodo_gato_3d = escena_gato.instantiate()
			if nodo_gato_3d.has_method("set"):
				nodo_gato_3d.set("auto_iniciar_colocacion", false)
				nodo_gato_3d.set("estado_actual", 3) # LISTO_PARA_SUBIR
			var raycast = ruedas_estado[nombre_rueda]["raycast"]
			if raycast:
				raycast.add_child(nodo_gato_3d)
				nodo_gato_3d.position = Vector3(0.0, -0.2, 0.35)
				nodo_gato_3d.rotation.y = deg_to_rad(90)
				if nodo_gato_3d.has_method("ejecutar_subida"):
					nodo_gato_3d.call("ejecutar_subida")
		else:
			nodo_gato_3d = Node3D.new()
			nodo_gato_3d.name = "GatoHidraulicoVisual"
			var mesh_base = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.14
			cyl.bottom_radius = 0.18
			cyl.height = 0.45
			mesh_base.mesh = cyl
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.20, 0.15) # Rojo maquinaria
			mat.metallic = 0.7
			mat.roughness = 0.3
			mesh_base.material_override = mat
			nodo_gato_3d.add_child(mesh_base)
			
			# Pistón plateado
			var mesh_piston = MeshInstance3D.new()
			var cyl_p = CylinderMesh.new()
			cyl_p.top_radius = 0.08
			cyl_p.bottom_radius = 0.08
			cyl_p.height = 0.35
			mesh_piston.mesh = cyl_p
			mesh_piston.position.y = 0.25
			var mat_p = StandardMaterial3D.new()
			mat_p.albedo_color = Color(0.85, 0.88, 0.92) # Cromado
			mat_p.metallic = 0.95
			mat_p.roughness = 0.15
			mesh_piston.material_override = mat_p
			nodo_gato_3d.add_child(mesh_piston)
			
			var raycast = ruedas_estado[nombre_rueda]["raycast"]
			if raycast:
				raycast.add_child(nodo_gato_3d)
				nodo_gato_3d.position = Vector3(0.0, -0.2, 0.35)

	# Sonido mecánico de bombeo hidráulico y elevación suave del chasis
	_reproducir_sfx_gato()
	
	var tw = create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func():
		vehiculo_levantado = true
		if CelularUI.instance:
			CelularUI.instance.notificar("✅ Vehículo elevado con el gato hidráulico. Ahora puedes retirar los pernos con seguridad.", "exito")
		# Actualizar el prompt visual
		var area = ruedas_estado[nombre_rueda]["area_3d"]
		if area and area.has_node("PromptRueda"):
			_actualizar_texto_prompt(nombre_rueda, area.get_node("PromptRueda"))
	)

func _iniciar_proceso_cambio_rueda(nombre_rueda: String) -> void:
	rueda_en_reparacion = nombre_rueda
	
	# 1. Animación de agacharse del jugador
	_animar_agacharse_jugador(true)
	
	# 2. Desplegar el minijuego de pernos y cambio de llanta
	_abrir_minijuego_rueda(nombre_rueda)

func _animar_agacharse_jugador(agacharse: bool) -> void:
	if not jugador:
		return
	var cam = jugador.get_node_or_null("Camera3D")
	if not cam:
		cam = jugador.find_child("*Camera*", true, false)
	if cam:
		var target_y = 0.65 if agacharse else altura_camara_original
		var tw = jugador.create_tween()
		tw.tween_property(cam, "position:y", target_y, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _abrir_minijuego_rueda(nombre_rueda: String) -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "CanvasMinijuegoRueda"
	canvas.layer = 20
	
	var script_minijuego = load("res://codigo/sistemas/interactivos/MinijuegoRueda.gd")
	var minijuego: Control = null
	if script_minijuego:
		minijuego = script_minijuego.new()
	else:
		minijuego = Control.new()
		
	canvas.add_child(minijuego)
	add_child(canvas)
	
	if minijuego.has_signal("minijuego_completado"):
		minijuego.connect("minijuego_completado", func():
			_finalizar_cambio_rueda_exitoso(nombre_rueda, canvas)
		)
	if minijuego.has_signal("minijuego_cancelado"):
		minijuego.connect("minijuego_cancelado", func():
			_animar_agacharse_jugador(false)
			canvas.queue_free()
		)

func _finalizar_cambio_rueda_exitoso(nombre_rueda: String, canvas: CanvasLayer) -> void:
	# 1. Cerrar UI y reincorporar al jugador
	canvas.queue_free()
	_animar_agacharse_jugador(false)
	
	# 2. Bajar y retirar gato hidráulico
	vehiculo_levantado = false
	gato_colocado = false
	if is_instance_valid(nodo_gato_3d):
		nodo_gato_3d.queue_free()
		
	# 3. Consumir la rueda de repuesto
	rueda_repuesto_disponible = false
	
	# 4. Restaurar neumático a 110 PSI
	var r = ruedas_estado[nombre_rueda]
	r["pinchada"] = false
	r["presion"] = 110.0
	
	if r["raycast"] and is_instance_valid(r["raycast"]):
		if "largo_reposo" in r["raycast"]:
			r["raycast"].largo_reposo = 0.35 # Altura original de suspensión pesada
		if "agarre_lateral" in r["raycast"]:
			r["raycast"].agarre_lateral = 18.0
		if "agarre_longitudinal" in r["raycast"]:
			r["raycast"].agarre_longitudinal = 16.0
			
	emit_signal("rueda_reparada", nombre_rueda)
	
	if CelularUI.instance:
		CelularUI.instance.notificar("✅ ¡Rueda de repuesto instalada con éxito! Neumático calibrado a 110 PSI.", "exito")
		CelularUI.instance.notificar("⚠️ Recuerda: Ya no tienes repuesto en el camión. Puedes comprar uno en el taller.", "alerta")
		
	# Actualizar prompt visual
	var area = r["area_3d"]
	if area and area.has_node("PromptRueda"):
		_actualizar_texto_prompt(nombre_rueda, area.get_node("PromptRueda"))

# Reparación total realizada por el Mecánico de Asistencia Vial
func reparar_por_mecanico_asistencia() -> void:
	for k in ruedas_estado:
		var r = ruedas_estado[k]
		r["pinchada"] = false
		r["presion"] = 110.0
		if r["raycast"] and is_instance_valid(r["raycast"]):
			if "largo_reposo" in r["raycast"]:
				r["raycast"].largo_reposo = 0.35
			if "agarre_lateral" in r["raycast"]:
				r["raycast"].agarre_lateral = 18.0
			if "agarre_longitudinal" in r["raycast"]:
				r["raycast"].agarre_longitudinal = 16.0
		var area = r["area_3d"]
		if area and area.has_node("PromptRueda"):
			_actualizar_texto_prompt(k, area.get_node("PromptRueda"))
			
	# Restaurar rueda de repuesto nueva en el camión
	rueda_repuesto_disponible = true
	repuesto_pinchado = false
	gato_colocado = false
	vehiculo_levantado = false
	if is_instance_valid(nodo_gato_3d):
		nodo_gato_3d.queue_free()

func _reproducir_sfx_pinchazo() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXPinchazo"
	var stream = load("res://recursos/sonidos_vehiculo/efectos/choque_leve.mp3")
	if stream:
		sfx.stream = stream
		sfx.unit_size = 18.0
		if coche:
			coche.add_child(sfx)
			sfx.play()
			sfx.finished.connect(func(): sfx.queue_free())

func _reproducir_sfx_gato() -> void:
	var sfx = AudioStreamPlayer3D.new()
	sfx.name = "SFXGatoHidraulico"
	var stream = load("res://recursos/sonidos_vehiculo/efectos/Hidraulico.mp3")
	if stream:
		sfx.stream = stream
		sfx.pitch_scale = 1.35
		sfx.unit_size = 10.0
		if coche:
			coche.add_child(sfx)
			sfx.play()
			sfx.finished.connect(func(): sfx.queue_free())
