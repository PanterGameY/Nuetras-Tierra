extends Node3D

# ═══════════════════════════════════════════════════════════════════════
# Mensajero.gd — Sistema de trabajo de mensajería (Flujo Completo)
# ═══════════════════════════════════════════════════════════════════════

enum EstadoTrabajo {
	INACTIVO,
	CARGANDO,
	LISTO_PARA_PARTIR,
	ENTREGANDO,
	RETORNANDO
}

@export_group("Configuración de Base")
## Ubicación de la base/oficina de mensajería donde se inicia y finaliza el trabajo
@export var base_posicion: Vector3 = Vector3(45.0, 0.0, 20.0)
## Ubicación exacta donde aparecerá el vehículo de reparto
@export var spawn_vehiculo_posicion: Vector3 = Vector3(48.0, 0.5, 25.0)
## Rotación del vehículo al aparecer (en grados)
@export var spawn_vehiculo_rotacion: Vector3 = Vector3(0, 90, 0)
## Escena del vehículo de reparto que se le asignará al jugador
@export var vehiculo_reparto_scene: PackedScene = null
## Nodo contenedor que tiene los Marker3D/Node3D de entrega como hijos directos
@export var contenedor_destinos: Node3D = null
## Ubicación de la zona donde el jugador recoge las cajas para cargar
@export var zona_recogida_posicion: Vector3 = Vector3(41.0, 0.0, 16.0)

var zona_recogida_area: Area3D = null
var cajas_cargadas: int = 0
var caja_escena: PackedScene = preload("res://mundo/logistica/mensajero/caja.tscn")

# Offsets locales dentro de EspacioCajas para apilar cajas visualmente dentro del furgo.
var offsets_cajas: Array[Vector3] = [
	Vector3(-0.35,  0.05, -0.35), # Fila 1 Izquierda fondo
	Vector3( 0.35,  0.05, -0.35), # Fila 1 Derecha fondo
	Vector3(-0.35,  0.05,  0.20), # Fila 2 Izquierda
	Vector3( 0.35,  0.05,  0.20), # Fila 2 Derecha
	Vector3( 0.00,  0.37, -0.35), # Apilada encima centro fondo
	Vector3(-0.35,  0.37,  0.20), # Apilada encima izquierda
	Vector3( 0.35,  0.37,  0.20), # Apilada encima derecha
]
var cajas_visuales_instanciadas: Array[Node3D] = []
var area_carga_dinamica: Area3D = null

@export_group("Configuración de Entregas")
## Cantidad mínima de paquetes/paradas por ruta de entrega
@export var min_entregas_por_ruta: int = 1
## Cantidad máxima de paquetes/paradas por ruta de entrega
@export var max_entregas_por_ruta: int = 15

# Referencias
var gps_linea: Node
var gps_router: Node 

# Estado interno
var estado_actual: EstadoTrabajo = EstadoTrabajo.INACTIVO
var mision_activa: Dictionary = {}
var recompensa_base: float = 200.0
var vehiculo_instanciado: RigidBody3D = null

# Nuevas variables para ruta multipunto
var destinos_pendientes: Array[Vector3] = []
var entregas_completadas: int = 0
var total_entregas_mision: int = 0
var recompensa_acumulada: float = 0.0

# Zonas de interacción Area3D
var zona_base: Area3D = null
var zona_entrega_actual: Area3D = null

# Lógica de rol de entrega (ZonaCarga en el Sprinter)
var tiene_paquete: bool = false
var cerca_mensaje_mostrado: bool = false
var zona_carga_visual: MeshInstance3D = null
var guia_puntos_nodos: Array[MeshInstance3D] = []

# Sistema de notificaciones personalizadas gigantes y centradas de Mensajero
var canvas_notif: CanvasLayer = null
var panel_notif: PanelContainer = null
var label_notif: Label = null
var show_timer: float = 0.0
var target_alpha: float = 0.0
var current_alpha: float = 0.0
var target_y_offset: float = -80.0
var current_y_offset: float = -80.0
var current_scale: float = 1.0
var target_scale: float = 1.0

# Barra de progreso del trabajo/misión activa en pantalla
var hud_progreso: PanelContainer = null
var barra_progreso: ProgressBar = null
var label_progreso: Label = null

# Lista de destinos posibles en la ciudad
var destinos: Array[Vector3] = [
	Vector3(0.0, 0.0, 80.0),    # norte_2 / mercado
	Vector3(0.0, 1.5, -60.0),   # centro
	Vector3(-80.0, 0.0, 45.0),  # gasolinera
	Vector3(-50.0, 0.0, -35.0), # taller_mecanico
	Vector3(30.0, 0.0, -90.0)   # policia
]
var ultimo_destino_index: int = -1

# Nuevas variables para entrega interactiva y reporte/factura final
var pago_entrega_actual: float = 0.0
var distancia_entrega_actual: float = 0.0
var reporte_ruta: Array[Dictionary] = []
var panel_entrega_interactivo: PanelContainer
var label_entrega_titulo: Label
var progress_bar_entrega: ProgressBar
var btn_tocar_puerta: Button
var esperando_cliente: bool = false
var etapa_entrega: int = 1
var tiempo_espera_acumulado: float = 0.0
var jugador_en_zona_entrega: bool = false

var panel_factura: PanelContainer
var vbox_factura_items: VBoxContainer
var label_factura_total: Label
var btn_factura_cobrar: Button

# Temporizador de retorno de furgoneta
var retorno_timer_activo: bool = false
var retorno_etapa: int = 1 # 1 = Normal, 2 = Descuento, 3 = Desaparecer
var retorno_tiempo_restante: float = 0.0
var descuento_acumulado: float = 0.0
var tiempo_etapa_normal: float = 120.0 # 2 minutos para regresar
var tiempo_etapa_descuento: float = 60.0 # 1 minuto extra con descuento progresivo
var tiempo_etapa_desaparecer: float = 10.0 # 10 segundos finales de aviso

# Mecánica de Fragilidad/Delicadeza de Cajas (Opción 2)
var caja_actual_delicada: bool = false
var caja_salud: float = 100.0



func _ready() -> void:
	gps_linea = get_node_or_null("GPSRutaLinea")
	gps_router = get_node_or_null("GPSRouter")

	if not gps_linea and get_parent():
		gps_linea = get_parent().find_child("GPSRutaLinea", true, false)
	if not gps_router and get_parent():
		gps_router = get_parent().find_child("GPSRouter", true, false)

	if not vehiculo_reparto_scene:
		vehiculo_reparto_scene = load("res://modelos3d/vehiculos/automoviles/sprinter/sprinter_repartidor.tscn")
		if not vehiculo_reparto_scene:
			vehiculo_reparto_scene = load("res://modelos3d/vehiculos/automoviles/sprinter/alaris_repartidor.tscn")

	# Buscar destinos desde el contenedor configurado (Node3D)
	if is_instance_valid(contenedor_destinos):
		var hijos = contenedor_destinos.get_children()
		if not hijos.is_empty():
			destinos.clear()
			for h in hijos:
				if h is Node3D:
					destinos.append(h.global_position)
			print("[Mensajero] Se cargaron ", destinos.size(), " destinos desde el contenedor: ", contenedor_destinos.name)
	else:
		# Fallback: buscar destinos colocados visualmente por grupo en la escena
		var destinos_grupo = get_tree().get_nodes_in_group("destinos_mensajero")
		if not destinos_grupo.is_empty():
			destinos.clear()
			for d in destinos_grupo:
				if d is Node3D:
					destinos.append(d.global_position)
			print("[Mensajero] Se cargaron ", destinos.size(), " destinos visuales desde la escena.")

	call_deferred("_crear_zona_base")
	_crear_ui_notificaciones()


# ─── Creación y Gestión de Zonas Físicas ────────────────────────────────

func _crear_zona_base() -> void:
	_limpiar_zona_base()

	zona_base = Area3D.new()
	zona_base.collision_layer = 0
	zona_base.collision_mask = 4294967295 # Detectar todas las capas para evitar fallos de colisión
	
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(6.0, 3.0, 6.0)
	collision.shape = box_shape
	
	zona_base.add_child(collision)
	zona_base.body_entered.connect(_on_zona_base_body_entered)
	
	add_child(zona_base)
	zona_base.global_position = base_posicion

func _limpiar_zona_base() -> void:
	if is_instance_valid(zona_base):
		zona_base.queue_free()
	zona_base = null

func _crear_zona_entrega(pos: Vector3) -> void:
	_limpiar_zona_entrega()

	zona_entrega_actual = Area3D.new()
	zona_entrega_actual.collision_layer = 0
	zona_entrega_actual.collision_mask = 4294967295 # Detectar todas las capas (vehículo o jugador)
	
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2.5, 3.0, 2.5)
	collision.shape = box_shape
	
	zona_entrega_actual.add_child(collision)
	zona_entrega_actual.body_entered.connect(_on_zona_entrega_body_entered)
	zona_entrega_actual.body_exited.connect(_on_zona_entrega_body_exited)
	
	# 1. Aro exterior neón celeste brillante
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "IndicadorVisual"
	var cyl_mesh = CylinderMesh.new()
	cyl_mesh.top_radius = 2.2
	cyl_mesh.bottom_radius = 2.2
	cyl_mesh.height = 0.05
	cyl_mesh.radial_segments = 32
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.85, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.85, 1.0)
	mat.emission_energy_multiplier = 3.5
	
	mesh_inst.mesh = cyl_mesh
	mesh_inst.material_override = mat
	zona_entrega_actual.add_child(mesh_inst)
	mesh_inst.position = Vector3(0.0, 0.05, 0.0)
	
	# 2. Prisma flotante apuntando hacia abajo en el centro
	var prism_inst = MeshInstance3D.new()
	prism_inst.name = "PrismaFlotante"
	var prism_mesh = CylinderMesh.new()
	prism_mesh.top_radius = 0.0
	prism_mesh.bottom_radius = 0.4
	prism_mesh.height = 0.8
	prism_mesh.radial_segments = 4
	
	var mat_prism = StandardMaterial3D.new()
	mat_prism.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_prism.albedo_color = Color(1.0, 0.85, 0.0, 0.75)
	mat_prism.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_prism.emission_enabled = true
	mat_prism.emission = Color(1.0, 0.85, 0.0)
	mat_prism.emission_energy_multiplier = 4.0
	
	prism_inst.mesh = prism_mesh
	prism_inst.material_override = mat_prism
	zona_entrega_actual.add_child(prism_inst)
	prism_inst.position = Vector3(0.0, 1.3, 0.0)
	prism_inst.rotation_degrees = Vector3(180, 0, 0)
	
	add_child(zona_entrega_actual)
	zona_entrega_actual.global_position = pos

func _limpiar_zona_entrega() -> void:
	if is_instance_valid(zona_entrega_actual):
		zona_entrega_actual.queue_free()
	zona_entrega_actual = null

func _crear_zona_recogida() -> void:
	_limpiar_zona_recogida()
	
	# Obtener posición desde el Marker3D ZonaCajas si existe en la jerarquía
	var marker_recogida = get_node_or_null("ZonaCajas")
	if marker_recogida:
		zona_recogida_posicion = marker_recogida.global_position
	
	zona_recogida_area = Area3D.new()
	zona_recogida_area.collision_layer = 0
	zona_recogida_area.collision_mask = 4294967295
	
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(3.0, 3.0, 3.0)
	collision.shape = box_shape
	zona_recogida_area.add_child(collision)
	
	# Conectar señal
	zona_recogida_area.body_entered.connect(_on_zona_recogida_body_entered)
	
	# Aro visual naranja neón
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "IndicadorVisualRecogida"
	var cyl_mesh = CylinderMesh.new()
	cyl_mesh.top_radius = 2.0
	cyl_mesh.bottom_radius = 2.0
	cyl_mesh.height = 0.05
	cyl_mesh.radial_segments = 32
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.5, 0.0, 0.4) # Naranja neón
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 4.0
	
	mesh_inst.mesh = cyl_mesh
	mesh_inst.material_override = mat
	zona_recogida_area.add_child(mesh_inst)
	mesh_inst.position = Vector3(0.0, 0.05, 0.0)
	
	# Prisma flotante naranja
	var prism_inst = MeshInstance3D.new()
	prism_inst.name = "PrismaFlotanteRecogida"
	var prism_mesh = CylinderMesh.new()
	prism_mesh.top_radius = 0.0
	prism_mesh.bottom_radius = 0.35
	prism_mesh.height = 0.7
	prism_mesh.radial_segments = 4
	
	var mat_prism = StandardMaterial3D.new()
	mat_prism.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat_prism.albedo_color = Color(1.0, 0.65, 0.0, 0.75)
	mat_prism.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_prism.emission_enabled = true
	mat_prism.emission = Color(1.0, 0.65, 0.0)
	mat_prism.emission_energy_multiplier = 4.0
	
	prism_inst.mesh = prism_mesh
	prism_inst.material_override = mat_prism
	zona_recogida_area.add_child(prism_inst)
	prism_inst.position = Vector3(0.0, 1.3, 0.0)
	prism_inst.rotation_degrees = Vector3(180, 0, 0)
	
	# Label3D flotante
	var label3d = Label3D.new()
	label3d.text = "DESPACHO DE ENVIOS\n[ RECOGER CAJA ]"
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.font_size = 32
	label3d.outline_size = 10
	label3d.modulate = Color(1.0, 0.5, 0.0) # Naranja neón
	label3d.position = Vector3(0, 2.0, 0)
	
	var font_moderniz = load("res://recursos/fonts/Moderniz.otf")
	if font_moderniz:
		label3d.font = font_moderniz
		
	zona_recogida_area.add_child(label3d)
	
	add_child(zona_recogida_area)
	zona_recogida_area.global_position = zona_recogida_posicion

func _limpiar_zona_recogida() -> void:
	if is_instance_valid(zona_recogida_area):
		zona_recogida_area.queue_free()
	zona_recogida_area = null

func _on_zona_recogida_body_entered(body: Node3D) -> void:
	if estado_actual == EstadoTrabajo.CARGANDO:
		if body.is_in_group("jugador"):
			var jugador = body
			if jugador.get("caja_agarrada") == null:
				# Instanciar la caja y dársela al jugador en las manos
				if caja_escena:
					var nueva_caja = caja_escena.instantiate()
					
					# Randomizar fragilidad (45% de probabilidad de ser delicada)
					var es_delicada = randf() < 0.45
					if es_delicada:
						# Guardar estado en el Mensajero
						caja_actual_delicada = true
						caja_salud = 100.0
						
						# Cambiar color de la caja a Naranja/Rojo Neon para denotar peligro
						var mesh = nueva_caja.find_child("MeshInstance3D", true, false) as MeshInstance3D
						if mesh:
							var mat = StandardMaterial3D.new()
							mat.albedo_color = Color(1.0, 0.3, 0.0) # Naranja rojizo
							mat.roughness = 0.5
							mat.emission_enabled = true
							mat.emission = Color(1.0, 0.15, 0.0)
							mat.emission_energy_multiplier = 1.2
							mesh.material_override = mat
							
						# Añadir un Label3D sobre la caja que indique "DELICADA"
						var label3d = Label3D.new()
						label3d.text = "[ DELICADA ]"
						label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
						label3d.font_size = 14
						label3d.outline_size = 4
						label3d.modulate = Color(1.0, 0.2, 0.0) # Rojo/Naranja brillante
						label3d.position = Vector3(0, 0.25, 0)
						var font = load("res://recursos/fonts/Moderniz.otf")
						if font:
							label3d.font = font
						nueva_caja.add_child(label3d)
					else:
						caja_actual_delicada = false
						caja_salud = 100.0
					
					jugador.agarrar_caja(nueva_caja)
					
					_crear_efecto_satisfaccion(zona_recogida_posicion, Color(1.0, 0.5, 0.0), Color(1.0, 0.85, 0.0))
					if es_delicada:
						_mostrar_notificacion("¡ATENCION! CAJA DELICADA RECOGIDA. CONDUCE CON CUIDADO!")
					else:
						_mostrar_notificacion("CAJA RECOGIDA! LLEVALA A LA PARTE TRASERA DEL FURGON.")
					
					# GPS apunta al furgón
					if is_instance_valid(vehiculo_instanciado):
						_actualizar_gps_celular(vehiculo_instanciado.global_position, "Cargar en Furgoneta")
			else:
				_mostrar_notificacion("YA LLEVAS UNA CAJA! CARGALA EN LA FURGONETA.")

# Registrar daño por impacto del vehículo (Opción 2)
func registrar_impacto_vehiculo(fuerza: float) -> void:
	# Solo dañar si estamos transportando (CARGANDO o ENTREGANDO) y la caja actual es delicada
	if not caja_actual_delicada or fuerza < 2.0:
		return
		
	# Calcular daño basado en la fuerza del choque
	var dano = snapped(fuerza * 6.5, 1.0)
	caja_salud = clamp(caja_salud - dano, 0.0, 100.0)
	
	# Mostrar indicador 3D flotando encima del vehículo indicando el daño (Opción 8)
	if is_instance_valid(vehiculo_instanciado):
		var text3d = Label3D.new()
		text3d.text = "-%d%% CAJA DAÑADA" % int(dano)
		text3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text3d.font_size = 28
		text3d.outline_size = 8
		text3d.modulate = Color(1.0, 0.1, 0.1) # Rojo brillante
		
		# Cargar la fuente Moderniz
		var font = load("res://recursos/fonts/Moderniz.otf")
		if font:
			text3d.font = font
			
		vehiculo_instanciado.add_child(text3d)
		text3d.global_position = vehiculo_instanciado.global_position + Vector3(0, 2.5, 0)
		
		# Animar el texto hacia arriba y desvanecerlo
		var tween = get_tree().create_tween()
		tween.tween_property(text3d, "global_position:y", text3d.global_position.y + 1.5, 1.2)
		tween.parallel().tween_property(text3d, "modulate:a", 0.0, 1.2)
		tween.finished.connect(func(): if is_instance_valid(text3d): text3d.queue_free())
		
	_mostrar_notificacion("¡CHOQUE! PAQUETE DELICADO DAÑADO. SALUD: %d%%" % int(caja_salud))


# ─── Lógica del Trabajo ─────────────────────────────────────────────────

func generar_mision(destino: Vector3) -> void:
	_limpiar_zona_entrega()

	var origen = base_posicion
	if is_inside_tree():
		origen = global_transform.origin
		if get_parent() and get_parent().is_inside_tree():
			origen = get_parent().global_transform.origin

	var distancia = origen.distance_to(destino)
	var pago_entrega = snapped(recompensa_base + (distancia * 2.5), 1.0)
	
	distancia_entrega_actual = distancia
	pago_entrega_actual = pago_entrega
	recompensa_acumulada += pago_entrega

	mision_activa = {
		"destino": destino,
		"recompensa": recompensa_acumulada
	}

func iniciar_trabajo() -> void:
	if estado_actual != EstadoTrabajo.INACTIVO:
		return

	if not vehiculo_reparto_scene:
		_mostrar_notificacion("Error: Escena del vehículo de reparto no encontrada.")
		return

	# 1. Spawnear el vehículo
	vehiculo_instanciado = vehiculo_reparto_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(vehiculo_instanciado)
	vehiculo_instanciado.add_to_group("vehiculo")
	
	# Ajustar posición al suelo mediante Raycast para evitar que spawnee en el aire
	var spawn_pos = spawn_vehiculo_posicion
	var space_state = vehiculo_instanciado.get_world_3d().direct_space_state
	if space_state:
		var query = PhysicsRayQueryParameters3D.create(
			spawn_pos + Vector3(0, 5.0, 0),
			spawn_pos - Vector3(0, 15.0, 0),
			4294967295 # Buscar en todas las capas de colisión (suelo, calles, etc.)
		)
		var result = space_state.intersect_ray(query)
		if result and result.has("position"):
			spawn_pos.y = result.position.y + 0.15 # Margen pequeño
	
	vehiculo_instanciado.global_position = spawn_pos
	vehiculo_instanciado.global_rotation = Vector3(
		deg_to_rad(spawn_vehiculo_rotacion.x),
		deg_to_rad(spawn_vehiculo_rotacion.y),
		deg_to_rad(spawn_vehiculo_rotacion.z)
	)

	# 2. Configurar la lista de entregas multipunto
	destinos_pendientes = destinos.duplicate()
	destinos_pendientes.shuffle() # Barajar la ruta de entregas
	
	# Seleccionar una cantidad aleatoria de paradas configurada en el inspector
	var min_val = clamp(min_entregas_por_ruta, 1, destinos_pendientes.size())
	var max_val = clamp(max_entregas_por_ruta, min_val, destinos_pendientes.size())
	var cant_entregas = randi_range(min_val, max_val)
	destinos_pendientes = destinos_pendientes.slice(0, cant_entregas)
	
	entregas_completadas = 0
	total_entregas_mision = destinos_pendientes.size()
	recompensa_acumulada = 0.0
	reporte_ruta.clear()

	if total_entregas_mision == 0:
		_mostrar_notificacion("Error: No hay destinos configurados.")
		_resetear_sistema()
		return

	estado_actual = EstadoTrabajo.CARGANDO
	cajas_cargadas = 0
	_crear_zona_recogida()
	
	# Mostrar HUD de progreso de carga inicialmente
	if hud_progreso and label_progreso and barra_progreso:
		hud_progreso.visible = true
		label_progreso.text = "CAJAS CARGADAS: 0 / %d" % total_entregas_mision
		barra_progreso.max_value = total_entregas_mision
		barra_progreso.value = 0
		
	# Apuntar el GPS a la zona de recogida
	_actualizar_gps_celular(zona_recogida_posicion, "Recogida de Cajas")
	_inicializar_zona_carga_furgon()

	# Añadir marca visual cyan neón en la ZonaEntrada de abordaje del vehículo
	var zona_entrada = vehiculo_instanciado.find_child("ZonaEntrada", true, false)
	if zona_entrada and zona_entrada is Area3D:
		var visual_ze = MeshInstance3D.new()
		visual_ze.name = "MarcaSubirse"
		var ring = CylinderMesh.new()
		ring.top_radius = 1.0
		ring.bottom_radius = 1.0
		ring.height = 0.05
		ring.radial_segments = 24
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.0, 0.75, 1.0, 0.45) # Celeste neón
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.75, 1.0)
		mat.emission_energy_multiplier = 3.5
		
		visual_ze.mesh = ring
		visual_ze.material_override = mat
		zona_entrada.add_child(visual_ze)
		# Posicionar en el suelo del Area3D (offset vertical para quedar sobre el suelo real)
		visual_ze.position = Vector3(0.0, -1.0, 0.0)
		visual_ze.rotation_degrees = Vector3(0, 0, 0) # El cilindro con altura 0.05 ya es plano horizontalmente
		
	# Ejecutar la cinemática de presentación de inicio del trabajo
	_ejecutar_cinematica_inicio()

func _siguiente_entrega() -> void:
	# Actualizar la barra de progreso física en pantalla
	if hud_progreso and label_progreso and barra_progreso:
		hud_progreso.visible = true
		label_progreso.text = "ENTREGAS: %d / %d" % [entregas_completadas, total_entregas_mision]
		barra_progreso.max_value = total_entregas_mision
		barra_progreso.value = entregas_completadas

	if destinos_pendientes.is_empty():
		# Ya se completaron todas las paradas, retornar a base
		estado_actual = EstadoTrabajo.RETORNANDO
		_limpiar_zona_entrega()
		
		# Activar temporizador de retorno
		retorno_timer_activo = true
		retorno_etapa = 1
		retorno_tiempo_restante = tiempo_etapa_normal
		descuento_acumulado = 0.0
		
		_actualizar_gps_celular(base_posicion, "Retorno a la Base")
		_mostrar_notificacion("Todas las entregas realizadas. Retorna a la base a tiempo.")
		return
		
	var siguiente_destino = destinos_pendientes[0]
	generar_mision(siguiente_destino)
	
	# Actualizar GPS y Celular con el progreso actual
	var texto_ui = "Paquete %d/%d" % [entregas_completadas + 1, total_entregas_mision]
	_actualizar_gps_celular(siguiente_destino, texto_ui)
	_mostrar_notificacion("GPS actualizado. Ve al punto " + str(entregas_completadas + 1) + "/" + str(total_entregas_mision))
	
	# Crear la zona visual del paquete en el suelo
	_crear_zona_entrega(siguiente_destino)

func entregar_paquete() -> void:
	if estado_actual != EstadoTrabajo.ENTREGANDO:
		return

	entregas_completadas += 1
	if not destinos_pendientes.is_empty():
		destinos_pendientes.remove_at(0)

	_mostrar_notificacion("¡Paquete entregado con éxito! (" + str(entregas_completadas) + "/" + str(total_entregas_mision) + ")")
	
	# Reproducir un sonido de caja registradora/éxito si existe
	var sonido_coche = vehiculo_instanciado.get_node_or_null("Sonido_dual") if is_instance_valid(vehiculo_instanciado) else null
	if sonido_coche and sonido_coche.has_method("reproducir_claxon"):
		# Breve bocinazo de éxito de fondo
		sonido_coche.call_deferred("reproducir_claxon")

	# Ir a la siguiente parada
	_siguiente_entrega()

func terminar_y_cobrar() -> void:
	if estado_actual != EstadoTrabajo.RETORNANDO:
		return

	# Si el reporte de factura final no se esta mostrando, mostrarlo primero
	if is_instance_valid(panel_factura) and not panel_factura.visible and not panel_factura.has_meta("factura_mostrada"):
		panel_factura.set_meta("factura_mostrada", true)
		_mostrar_reporte_final()
		return
		
	if is_instance_valid(panel_factura):
		panel_factura.remove_meta("factura_mostrada")

	var pago: float = mision_activa.get("recompensa", 0.0)

	_despawnear_vehiculo()

	# Agregar recompensa
	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		datos.dinero += pago
		if datos.has_method("save_local"):
			datos.save_local()
			print("[Mensajero] Recompensa de $", pago, " sumada a DatosUsuario. Nuevo saldo: $", datos.dinero)
		elif datos.has_method("guardar_progreso"):
			datos.call("guardar_progreso")
			
		# Si hay algún script escuchando cambios o si el celular tiene que refrescar el saldo
		var celular = get_tree().get_first_node_in_group("celular")
		if not celular:
			celular = get_tree().current_scene.find_child("CelularUI", true, false)
		if celular:
			if celular.has_method("_update_bank_display"):
				celular.call("_update_bank_display")

	_resetear_sistema()
	
	# Mensaje de pago grande, brillante y satisfactorio al finalizar la misión
	_mostrar_notificacion("TRABAJO COMPLETADO! RECOMPENSA: +$" + str(int(pago)))
	
	# Forzar un sonido de éxito
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador and jugador.has_method("play_sound"):
		jugador.call("play_sound", "recompensa")

func cancelar_trabajo() -> void:
	if estado_actual == EstadoTrabajo.INACTIVO:
		return

	_despawnear_vehiculo()
	_resetear_sistema()
	_mostrar_notificacion("Trabajo de mensajería cancelado.")


# ─── Helpers ────────────────────────────────────────────────────────────

func _actualizar_gps_celular(destino: Vector3, texto_ui: String) -> void:
	# Asegurar instancias válidas del GPS dinámicamente si no se encontraron en _ready()
	if not is_instance_valid(gps_linea):
		var jugador = get_tree().get_first_node_in_group("jugador")
		if jugador:
			gps_linea = jugador.get_node_or_null("GPSRutaLinea")
			if not gps_linea:
				gps_linea = jugador.find_child("GPSRutaLinea", true, false)
				
	if not is_instance_valid(gps_router):
		gps_router = get_tree().current_scene.find_child("GPSRouter", true, false)

	if gps_linea and gps_linea.has_method("set_destination"):
		gps_linea.set_destination(destino)
		
	var ruta_puntos = PackedVector3Array()
	
	# 1. Obtenemos los puntos matemáticos del GPSRouter
	if gps_router and gps_router.has_method("get_route"):
		var origen_ruta = base_posicion
		
		# Obtener la posición actual del jugador/vehículo como origen real
		var jugador = get_tree().get_first_node_in_group("jugador")
		if jugador:
			if jugador.get("_conduciendo") == true and jugador.get("_vehiculo_actual") != null:
				origen_ruta = jugador.get("_vehiculo_actual").global_position
			else:
				origen_ruta = jugador.global_position
				
		ruta_puntos = gps_router.get_route(origen_ruta, destino)
		
	# 2. Buscamos el celular
	var celular = get_tree().get_first_node_in_group("celular")
	if not celular:
		celular = get_tree().current_scene.find_child("CelularUI", true, false)
		
	# 3. Actualizamos la UI y le enviamos la ruta para que la dibuje
	if celular:
		if "gps_line" in celular:
			celular.gps_line = gps_linea
			
		var waze_edit = celular.find_child("SearchLineEdit", true, false)
		if waze_edit:
			waze_edit.text = texto_ui
			
		# ¡AQUÍ ESTÁ LA MAGIA NUEVA! Llamamos a una función en el celular
		if celular.has_method("trazar_ruta_mapa") and not ruta_puntos.is_empty():
			celular.trazar_ruta_mapa(ruta_puntos)
		elif celular.has_method("limpiar_ruta_mapa") and ruta_puntos.is_empty():
			celular.limpiar_ruta_mapa()
			
func _despawnear_vehiculo() -> void:
	if is_instance_valid(vehiculo_instanciado):
		var jugador = get_tree().get_first_node_in_group("jugador")
		if jugador:
			# Si el jugador está conduciendo este vehículo, forzar la bajada primero
			if jugador.get("_vehiculo_actual") == vehiculo_instanciado or vehiculo_instanciado.get("activo") == true:
				if vehiculo_instanciado.has_method("bajar_jugador"):
					vehiculo_instanciado.bajar_jugador()
				elif jugador.has_method("salir_del_vehiculo"):
					jugador.salir_del_vehiculo()
		
		# Esperar un frame para dar tiempo a desvincular al jugador, cámaras y UI
		await get_tree().process_frame
		
		# Asegurar que el UI de vehículo se oculte si aún quedó activo
		var ui_veh = vehiculo_instanciado.get_node_or_null("UIVehiculo")
		if is_instance_valid(ui_veh):
			ui_veh.visible = false
			
		vehiculo_instanciado.queue_free()
		vehiculo_instanciado = null

func _resetear_sistema() -> void:
	estado_actual = EstadoTrabajo.INACTIVO
	mision_activa.clear()
	destinos_pendientes.clear()
	entregas_completadas = 0
	total_entregas_mision = 0
	recompensa_acumulada = 0.0
	tiene_paquete = false
	cerca_mensaje_mostrado = false
	retorno_timer_activo = false
	retorno_etapa = 1
	descuento_acumulado = 0.0
	_limpiar_zona_carga_visual()
	_limpiar_zona_entrega()
	_limpiar_zona_recogida()
	_limpiar_guias_suelo()
	
	# Soltar y borrar la caja que lleva el jugador si canceló/terminó
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador and jugador.get("caja_agarrada") != null:
		var caja = jugador.soltar_caja()
		if caja:
			caja.queue_free()
			
	if is_instance_valid(panel_notif):
		panel_notif.visible = false
	if is_instance_valid(hud_progreso):
		hud_progreso.visible = false
	if gps_linea and gps_linea.has_method("clear_route"):
		gps_linea.clear_route()

func _ejecutar_cinematica_inicio() -> void:
	var jugador = get_tree().get_first_node_in_group("jugador")
	if not jugador or not is_instance_valid(vehiculo_instanciado):
		return
		
	# 1. Bloquear temporalmente el movimiento y la cámara del jugador
	jugador.process_mode = Node.PROCESS_MODE_DISABLED
	jugador.set_meta("cinematic_active", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Ocultar UIpie del jugador
	var ui_pie = jugador.find_child("UIpie", true, false)
	if ui_pie:
		ui_pie.visible = false
	
	# 2. Guardar la cámara activa
	var camara_original = get_viewport().get_camera_3d()
	
	# 3. Crear cámara de la cinemática
	var cine_cam = Camera3D.new()
	get_tree().current_scene.add_child(cine_cam)
	cine_cam.cull_mask = 4294967295 # Forzar visualización de todas las capas 3D (texturas reales, carreteras)
	cine_cam.make_current()
	
	var veh_pos = vehiculo_instanciado.global_position
	var forward_veh = -vehiculo_instanciado.global_transform.basis.z.normalized()
	var right_veh = vehiculo_instanciado.global_transform.basis.x.normalized()
	var pasos = [
		{
			"texto": "TRABAJO DE MENSAJERO INICIADO. AQUI TIENES TU FURGON DE REPARTO.",
			"cam_pos": veh_pos + forward_veh * 9.0 + Vector3(0.0, 4.5, 0.0),
			"look_at": veh_pos + Vector3(0.0, 0.8, 0.0)
		},
		{
			"texto": "SUBE A LA FURGONETA PARA CONDUCIR.",
			"cam_pos": veh_pos + forward_veh * 5.0 + right_veh * 3.5 + Vector3(0.0, 2.0, 0.0),
			"look_at": veh_pos + Vector3(0.0, 0.8, 0.0)
		},
		{
			"texto": "PRIMERO, VE A PIE AL PUNTO DE RECOGIDA PARA CARGAR LAS CAJAS EN LA PARTE TRASERA DEL FURGON.",
			"cam_pos": veh_pos - forward_veh * 4.2 + right_veh * 2.0 + Vector3(0.0, 1.8, 0.0),
			"look_at": veh_pos - forward_veh * 2.0 + Vector3(0.5, 0.5, 0.0)
		},
		{
			"texto": "ABRE TU CELULAR DESDE EL VEHICULO Y SIGUE LA RUTA EN EL GPS (WAZE) PARA ENTREGAR LOS PAQUETES. ¡BUENA SUERTE!",
			"cam_pos": veh_pos + forward_veh * 9.0 + Vector3(0.0, 4.5, 0.0),
			"look_at": veh_pos + Vector3(0.0, 0.8, 0.0)
		}
	]
	
	_avanzar_tutorial_paso(0, cine_cam, camara_original, jugador, pasos)

func _avanzar_tutorial_paso(paso_actual: int, cine_cam: Camera3D, camara_original: Camera3D, jugador: Node3D, pasos: Array) -> void:
	if paso_actual >= pasos.size():
		# Finalizar cinemática
		if is_instance_valid(jugador):
			jugador.process_mode = Node.PROCESS_MODE_INHERIT
			jugador.set_meta("cinematic_active", false)
			var ui_pie = jugador.find_child("UIpie", true, false)
			if ui_pie:
				ui_pie.visible = true
			if is_instance_valid(camara_original):
				camara_original.make_current()
		if is_instance_valid(cine_cam):
			cine_cam.queue_free()
		return
		
	var paso = pasos[paso_actual]
	
	# Prevenir que la cámara atraviese paredes usando Raycast de física
	var space_state = cine_cam.get_world_3d().direct_space_state
	var target_pos = _get_safe_camera_position(paso["look_at"], paso["cam_pos"], space_state)
	
	# Animar cámara hacia el nuevo punto
	if paso_actual == 0:
		cine_cam.global_position = target_pos
		cine_cam.look_at(paso["look_at"], Vector3.UP)
	else:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(cine_cam, "global_position", target_pos, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(look_target: Vector3):
			if is_instance_valid(cine_cam):
				cine_cam.look_at(look_target, Vector3.UP)
		, cine_cam.global_position + (-cine_cam.global_transform.basis.z), paso["look_at"], 1.5)
	
	# Dibujar la interfaz de diálogo en el CanvasLayer de BaseMensajero (usamos BaseMensajero como cargador)
	var base_mensajero = get_parent()
	if base_mensajero and base_mensajero.has_method("_dibujar_interfaz_dialogo"):
		# Limpiar diálogos abiertos anteriormente
		if base_mensajero.has_method("_cerrar_dialogo"):
			base_mensajero.call("_cerrar_dialogo")
			
		# Creamos una opción con acción que avanza el tutorial al pulsar
		var avanzar = func():
			_avanzar_tutorial_paso(paso_actual + 1, cine_cam, camara_original, jugador, pasos)
			
		base_mensajero.call("_dibujar_interfaz_dialogo", "TUTORIAL DE MENSAJERO", paso["texto"], [
			{"texto": "SIGUIENTE", "accion": "avanzar"}
		])
		
		# Conectar programáticamente el botón para que ejecute 'avanzar' al pulsar
		await get_tree().process_frame
		if is_instance_valid(base_mensajero) and base_mensajero.get("_buttons_box"):
			var btns = base_mensajero.get("_buttons_box").get_children()
			if btns.size() > 0:
				var btn = btns[0] as Button
				if btn:
					btn.pressed.connect(avanzar)
	else:
		# Fallback si BaseMensajero no está estructurado como parent directo
		_mostrar_notificacion(paso["texto"])
		var timer = get_tree().create_timer(7.0) # Más tiempo para que puedan leer en fallback
		var safe_avanzar = func():
			if is_instance_valid(cine_cam) and is_inside_tree():
				_avanzar_tutorial_paso(paso_actual + 1, cine_cam, camara_original, jugador, pasos)
		timer.timeout.connect(safe_avanzar)

func _get_safe_camera_position(from_pos: Vector3, to_pos: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	if not space_state:
		return to_pos
	# Lanzar raycast desde el objetivo (vehículo) hacia la posición deseada de la cámara
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1 # Capa estándar de colisión con terrenos y paredes
	var result = space_state.intersect_ray(query)
	if result:
		# Si choca con una pared, colocamos la cámara 0.5m antes del punto de choque
		var dir = (from_pos - to_pos).normalized()
		return result.position + dir * 0.5
	return to_pos

func _crear_ui_notificaciones() -> void:
	if is_instance_valid(canvas_notif):
		return
		
	canvas_notif = CanvasLayer.new()
	canvas_notif.layer = 25 # Prioridad muy alta encima de todos los HUDs
	add_child(canvas_notif)
	
	panel_notif = PanelContainer.new()
	panel_notif.visible = false
	canvas_notif.add_child(panel_notif)
	
	# Configurar el anclaje central superior
	panel_notif.anchors_preset = Control.PRESET_CENTER_TOP
	panel_notif.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	# Estilo premium con cristal traslúcido y bordes coloreados
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.95)
	style.border_color = Color(1.0, 0.65, 0.0, 0.9)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 16
	panel_notif.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 45)
	margin.add_theme_constant_override("margin_right", 45)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel_notif.add_child(margin)
	
	label_notif = Label.new()
	label_notif.text = ""
	
	var settings = LabelSettings.new()
	settings.font_size = 35 # Letra bastante grande para destacar en pantalla!
	settings.font_color = Color(1.0, 1.0, 1.0)
	settings.outline_color = Color(0.0, 0.0, 0.0)
	settings.outline_size = 10
	
	# CARGAR FUENTE MODERNIZ SOLICITADA
	var font_moderniz = load("res://recursos/fonts/Moderniz.otf")
	if font_moderniz:
		settings.font = font_moderniz
		print("[Mensajero] Fuente Moderniz.otf cargada con éxito para notificaciones.")
	
	label_notif.label_settings = settings
	label_notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_notif.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_notif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_notif.custom_minimum_size = Vector2(850, 0)
	margin.add_child(label_notif)

	# --- CREAR HUD DE PROGRESO DE MISIÓN (Cristal esmerilado con barra de progreso) ---
	# --- CREAR HUD DE PROGRESO DE MISIÓN (Cristal esmerilado premium) ---
	hud_progreso = PanelContainer.new()
	hud_progreso.visible = false
	hud_progreso.custom_minimum_size = Vector2(400, 75)
	hud_progreso.anchors_preset = Control.PRESET_CENTER_TOP
	hud_progreso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	canvas_notif.add_child(hud_progreso)
	
	var hud_style = StyleBoxFlat.new()
	hud_style.bg_color = Color(0.04, 0.04, 0.08, 0.88) # Cristal oscuro de alta opacidad
	hud_style.border_color = Color(0.2, 0.75, 1.0, 0.6) # Celeste neón brillante
	hud_style.border_width_left = 2
	hud_style.border_width_top = 2
	hud_style.border_width_right = 2
	hud_style.border_width_bottom = 2
	hud_style.corner_radius_top_left = 14
	hud_style.corner_radius_top_right = 14
	hud_style.corner_radius_bottom_left = 14
	hud_style.corner_radius_bottom_right = 14
	hud_style.set_content_margin_all(12)
	hud_style.shadow_color = Color(0, 0, 0, 0.4)
	hud_style.shadow_size = 8
	hud_progreso.add_theme_stylebox_override("panel", hud_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	hud_progreso.add_child(vbox)
	
	label_progreso = Label.new()
	label_progreso.text = "ENTREGAS: 0 / 0"
	var label_settings = LabelSettings.new()
	label_settings.font_size = 15 # Letra ligeramente más grande
	label_settings.outline_size = 4
	label_settings.outline_color = Color(0,0,0)
	if font_moderniz:
		label_settings.font = font_moderniz
	label_progreso.label_settings = label_settings
	label_progreso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label_progreso)
	
	barra_progreso = ProgressBar.new()
	barra_progreso.show_percentage = false
	barra_progreso.custom_minimum_size = Vector2(0, 12) # Barra más gruesa
	vbox.add_child(barra_progreso)
	
	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	bg_bar.corner_radius_top_left = 4
	bg_bar.corner_radius_top_right = 4
	bg_bar.corner_radius_bottom_left = 4
	bg_bar.corner_radius_bottom_right = 4
	barra_progreso.add_theme_stylebox_override("background", bg_bar)
	
	var fill_bar = StyleBoxFlat.new()
	fill_bar.bg_color = Color(0.0, 0.85, 1.0, 0.95) # Relleno celeste neón brillante
	fill_bar.corner_radius_top_left = 4
	fill_bar.corner_radius_top_right = 4
	fill_bar.corner_radius_bottom_left = 4
	fill_bar.corner_radius_bottom_right = 4
	barra_progreso.add_theme_stylebox_override("fill", fill_bar)
	
	_crear_ui_entrega_y_factura()

func _quitar_tildes(texto: String) -> String:
	var t = texto
	t = t.replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u")
	t = t.replace("Á", "A").replace("É", "E").replace("Í", "I").replace("Ó", "O").replace("Ú", "U")
	t = t.replace("¡", "").replace("!", "").replace("¿", "").replace("?", "")
	return t

func _mostrar_notificacion(msg: String) -> void:
	if not label_notif or not panel_notif:
		print("[Mensajero Fallback] ", msg)
		return
		
	# Quitar tildes y hacer mayúsculas para mejor compatibilidad con la fuente Moderniz
	var clean_msg = _quitar_tildes(msg).to_upper()
	label_notif.text = clean_msg
	panel_notif.visible = true
	show_timer = 4.5
	
	# Dinámicamente colorear el borde según el contexto del mensaje
	var style = panel_notif.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if "recogido" in msg or "exito" in msg or "terminado" in msg or "realizadas" in msg:
			style.border_color = Color(0.15, 0.85, 0.35, 0.95) # Verde éxito
		elif "Llegaste" in msg or "Bajate" in msg:
			style.border_color = Color(0.0, 0.7, 1.0, 0.95) # Azul informativo
		else:
			style.border_color = Color(1.0, 0.65, 0.0, 0.95) # Naranja alerta/base
			
	# Activar animación de deslizamiento y fade-in
	target_alpha = 1.0
	target_y_offset = 120.0 if (is_instance_valid(hud_progreso) and hud_progreso.visible) else 35.0
	
	current_alpha = 0.0
	current_y_offset = -100.0 # Deslizar desde arriba de la pantalla
	panel_notif.modulate.a = 0.0
	
	# IMPULSO DE ESCALA (PULSO DE APARICIÓN SATISFACTORIO)
	current_scale = 1.35
	target_scale = 1.0
	panel_notif.scale = Vector2(current_scale, current_scale)

func _crear_zona_carga_visual(pos: Vector3) -> void:
	_limpiar_zona_carga_visual()
	
	# Solo mostrar este indicador sutil en la fase de carga
	if estado_actual != EstadoTrabajo.CARGANDO:
		return
		
	zona_carga_visual = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.3, 0.3)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.7, 1.0, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.5
	
	zona_carga_visual.mesh = box_mesh
	zona_carga_visual.material_override = mat
	zona_carga_visual.layers = 1
	get_tree().current_scene.add_child(zona_carga_visual)
	zona_carga_visual.global_position = pos

func _limpiar_zona_carga_visual() -> void:
	if is_instance_valid(zona_carga_visual):
		zona_carga_visual.queue_free()
	zona_carga_visual = null

func _limpiar_guias_suelo() -> void:
	for nodo in guia_puntos_nodos:
		if is_instance_valid(nodo):
			nodo.queue_free()
	guia_puntos_nodos.clear()

func _actualizar_guias_suelo(jugador: Node3D, destino: Vector3) -> void:
	_limpiar_guias_suelo()
	if not is_instance_valid(jugador) or estado_actual != EstadoTrabajo.CARGANDO:
		return
		
	var start_pos = jugador.global_position
	
	# Calcular la distancia total lineal entre jugador y destino
	var dist_total = start_pos.distance_to(destino)
	if dist_total < 1.0:
		return # Demasiado cerca, no hace falta dibujar
		
	# Espaciar los puntos guía a lo largo de la línea recta cada ~1.2 metros
	var intervalo = 1.2
	var cantidad_puntos = int(dist_total / intervalo)
	if cantidad_puntos < 1:
		cantidad_puntos = 1
		
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.65, 0.0, 0.45) # Naranja neón sutil
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 2.0
	
	# Animar los puntos oscilando con el tiempo
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = 0.12 + sin(time * 4.0) * 0.03
	
	for i in range(1, cantidad_puntos):
		var t = float(i) / float(cantidad_puntos)
		# Interpolar de forma lineal y recta
		var pos_punto = start_pos.lerp(destino, t)
		
		# Crear malla de punto sutil (pequeño cilindro/disco plano en el suelo)
		var disco = CylinderMesh.new()
		disco.top_radius = pulse
		disco.bottom_radius = pulse
		disco.height = 0.02
		disco.radial_segments = 8
		
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = disco
		mesh_inst.material_override = mat
		mesh_inst.layers = 1
		get_tree().current_scene.add_child(mesh_inst)
		# Posicionar a una altura fija sobre el suelo del jugador
		mesh_inst.global_position = Vector3(pos_punto.x, start_pos.y + 0.04, pos_punto.z)
		guia_puntos_nodos.append(mesh_inst)


func _crear_efecto_satisfaccion(pos: Vector3, color_primario: Color, color_secundario: Color) -> void:
	# Partículas CPU de celebración (muy optimizadas para móviles APK)
	var particles = CPUParticles3D.new()
	particles.amount = 75
	particles.explosiveness = 0.95
	particles.one_shot = true
	particles.direction = Vector3.UP
	particles.spread = 80.0
	particles.gravity = Vector3(0, -6.5, 0)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 9.5
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	particles.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color_primario
	mat.emission_enabled = true
	mat.emission = color_primario
	mat.emission_energy_multiplier = 4.0
	particles.material_override = mat
	
	# Gradiente de color interactivo
	var gradient = Gradient.new()
	gradient.set_color(0, color_primario)
	gradient.set_color(1, color_secundario)
	particles.color_ramp = gradient
	
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos + Vector3(0, 0.2, 0)
	particles.emitting = true
	
	# Auto-eliminar
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _process(delta: float) -> void:
	if esperando_cliente:
		tiempo_espera_acumulado += delta
		var duracion = 3.0 if etapa_entrega == 1 else 2.5
		if is_instance_valid(progress_bar_entrega):
			progress_bar_entrega.value = (tiempo_espera_acumulado / duracion) * 100.0
		if tiempo_espera_acumulado >= duracion:
			_avanzar_etapa_entrega()

	if retorno_timer_activo:
		retorno_tiempo_restante -= delta
		_actualizar_hud_retorno()
		if retorno_tiempo_restante <= 0.0:
			_avanzar_etapa_retorno()

	# 1. Animación, escala y desvanecimiento de notificaciones personalizadas gigantes
	if is_instance_valid(panel_notif) and panel_notif.visible:
		show_timer -= delta
		if show_timer <= 0.0:
			target_alpha = 0.0
			target_y_offset = -120.0 # Se desliza completamente hacia arriba fuera de la pantalla
			if current_alpha < 0.05:
				panel_notif.visible = false
		else:
			# Si está activa la notificación, calcular dinámicamente si se desplaza debajo del HUD de progreso
			target_y_offset = 120.0 if (is_instance_valid(hud_progreso) and hud_progreso.visible) else 35.0
				
		current_alpha = lerp(current_alpha, target_alpha, delta * 8.0)
		current_y_offset = lerp(current_y_offset, target_y_offset, delta * 8.0)
		current_scale = lerp(current_scale, target_scale, delta * 12.0)
		
		panel_notif.modulate.a = current_alpha
		panel_notif.scale = Vector2(current_scale, current_scale)
		
		# Centrar el panel en la pantalla horizontalmente y aplicar posición vertical
		var screen_width = panel_notif.get_viewport_rect().size.x
		var panel_width = panel_notif.size.x
		panel_notif.pivot_offset = panel_notif.size * 0.5
		panel_notif.global_position = Vector2((screen_width - panel_width) * 0.5, current_y_offset)

	# 2. Animar el indicador visual de la zona de entrega (aro y prisma flotante)
	if is_instance_valid(zona_entrega_actual):
		var mesh_inst = zona_entrega_actual.get_node_or_null("IndicadorVisual")
		var time = Time.get_ticks_msec() / 1000.0
		if mesh_inst and mesh_inst is MeshInstance3D:
			mesh_inst.rotate_y(delta * 0.6)
			var scale_pulse = 0.95 + sin(time * 3.5) * 0.08
			mesh_inst.scale = Vector3(scale_pulse, 1.0, scale_pulse)
			
			var mat = mesh_inst.material_override as StandardMaterial3D
			if mat:
				if tiene_paquete:
					mat.albedo_color = Color(0.2, 1.0, 0.4, 0.4) # Verde éxito si tiene el paquete
					mat.emission = Color(0.2, 1.0, 0.4)
				else:
					mat.albedo_color = Color(0.0, 0.85, 1.0, 0.4) # Celeste informativo
					mat.emission = Color(0.0, 0.85, 1.0)
				mat.albedo_color.a = 0.35 + sin(time * 3.5) * 0.12
		
		var prisma = zona_entrega_actual.get_node_or_null("PrismaFlotante")
		if prisma and prisma is MeshInstance3D:
			prisma.rotate_y(delta * 1.5)
			prisma.position.y = 1.3 + sin(time * 4.0) * 0.15
			
	# 2b. Animar el indicador visual de la zona de recogida si está activa
	if is_instance_valid(zona_recogida_area):
		var mesh_inst = zona_recogida_area.get_node_or_null("IndicadorVisualRecogida")
		var time = Time.get_ticks_msec() / 1000.0
		if mesh_inst and mesh_inst is MeshInstance3D:
			mesh_inst.rotate_y(delta * 0.6)
			var scale_pulse = 0.95 + sin(time * 3.5) * 0.08
			mesh_inst.scale = Vector3(scale_pulse, 1.0, scale_pulse)
		
		var prisma = zona_recogida_area.get_node_or_null("PrismaFlotanteRecogida")
		if prisma and prisma is MeshInstance3D:
			prisma.rotate_y(delta * 1.5)
			prisma.position.y = 1.3 + sin(time * 4.0) * 0.15

	# Centrar dinámicamente el panel de entrega interactivo si está visible
	if is_instance_valid(panel_entrega_interactivo) and panel_entrega_interactivo.visible:
		var screen_size = panel_entrega_interactivo.get_viewport_rect().size
		panel_entrega_interactivo.size = Vector2(400, 150)
		panel_entrega_interactivo.global_position = Vector2((screen_size.x - 400) * 0.5, screen_size.y - 240)

	# Centrar dinámicamente el HUD de progreso si está visible
	if is_instance_valid(hud_progreso) and hud_progreso.visible:
		var screen_size = hud_progreso.get_viewport_rect().size
		hud_progreso.size = Vector2(400, 75)
		hud_progreso.global_position = Vector2((screen_size.x - 400) * 0.5, 25)

	# 3. Lógica de carga y entrega del paquete
	if is_instance_valid(vehiculo_instanciado):
		var jugador = get_tree().get_first_node_in_group("jugador")
		if jugador:
			var zona_carga = vehiculo_instanciado.find_child("EspacioCajas", true, false)
			if not zona_carga:
				zona_carga = vehiculo_instanciado.find_child("ZonaCajas", true, false)
			if not zona_carga:
				zona_carga = vehiculo_instanciado.find_child("ZonaCarga", true, false)
			var zc_pos = zona_carga.global_position if zona_carga else vehiculo_instanciado.global_position
			
			var conduciendo = jugador.get("_conduciendo") == true
			
			if estado_actual == EstadoTrabajo.CARGANDO:
				if conduciendo:
					_limpiar_zona_carga_visual()
					_limpiar_guias_suelo()
				else:
					# Mostrar visualmente la caja cargándose o la zona trasera
					if not is_instance_valid(zona_carga_visual):
						_crear_zona_carga_visual(zc_pos)
					else:
						zona_carga_visual.global_position = zc_pos
						zona_carga_visual.rotate_y(delta * 1.5)
						
					# Dibujar guías en el suelo
					var tiene_caja = jugador.get("caja_agarrada") != null
					var dest_guia = zc_pos if tiene_caja else zona_recogida_posicion
					_actualizar_guias_suelo(jugador, dest_guia)
							
			elif estado_actual == EstadoTrabajo.ENTREGANDO:
				_limpiar_guias_suelo()
				var veh_pos = vehiculo_instanciado.global_position
				var dest_pos = mision_activa.get("destino", Vector3.ZERO)
				var dist_to_dest = veh_pos.distance_to(dest_pos)
				var player_dist = jugador.global_position.distance_to(dest_pos)
				
				# Mostrar mensaje de llegada al acercarse (menos de 45m en vehículo o 30m a pie)
				if dist_to_dest < 45.0 or player_dist < 30.0:
					if not cerca_mensaje_mostrado:
						cerca_mensaje_mostrado = true
						_mostrar_notificacion("¡Llegaste! Bájate de la furgoneta, ve a la Zona de Carga trasera, agarra el paquete y entrégalo.")
				else:
					# Si se aleja demasiado, permitir que el mensaje se vuelva a mostrar si regresa
					if dist_to_dest > 60.0 and player_dist > 45.0:
						cerca_mensaje_mostrado = false
				
				if zona_carga:
					# Crear o mover el indicador de la caja trasera (solo si NO está conduciendo y no tiene paquete)
					if conduciendo or tiene_paquete:
						_limpiar_zona_carga_visual()
					else:
						if not is_instance_valid(zona_carga_visual):
							_crear_zona_carga_visual(zc_pos)
						else:
							zona_carga_visual.global_position = zc_pos
							zona_carga_visual.rotate_y(delta * 1.5)
						
					# Verificar si el jugador a pie se acerca al marcador de carga para recogerlo
					conduciendo = jugador.get("_conduciendo") == true
					if not conduciendo and not tiene_paquete:
						var player_pos = jugador.global_position
						if player_pos.distance_to(zc_pos) < 2.2:
							# Si el vehículo tiene el script Puertas_Mensajero, este se encarga del progreso.
							# De lo contrario, se recoge inmediatamente para compatibilidad.
							var tiene_script_puertas = false
							for child in vehiculo_instanciado.get_children():
								if child.get_script() and child.get_script().resource_path.ends_with("Puertas_Mensajero.gd"):
									tiene_script_puertas = true
									break
							if not tiene_script_puertas:
								recoger_paquete()

	# 4. Animar la marca celeste de abordar el vehículo (ZonaEntrada)
	if is_instance_valid(vehiculo_instanciado):
		var ze = vehiculo_instanciado.find_child("ZonaEntrada", true, false)
		if ze:
			var marca = ze.get_node_or_null("MarcaSubirse")
			if marca and marca is MeshInstance3D:
				var jugador = get_tree().get_first_node_in_group("jugador")
				var conduciendo = false
				if jugador and jugador.get("_conduciendo") == true:
					conduciendo = true
				
				# Solo mostrar si NO está conduciendo y el estado amerita usar el vehículo
				var necesita_vehiculo = (estado_actual == EstadoTrabajo.CARGANDO or estado_actual == EstadoTrabajo.ENTREGANDO or estado_actual == EstadoTrabajo.RETORNANDO)
				marca.visible = not conduciendo and necesita_vehiculo
				
				if marca.visible:
					# Rotar lentamente y oscilar su escala
					marca.rotate_y(delta * 0.9)
					var time = Time.get_ticks_msec() / 1000.0
					var scale_pulse = 0.92 + sin(time * 3.0) * 0.08
					marca.scale = Vector3(scale_pulse, 1.0, scale_pulse)

# ─── Manejo de Señales/Entrada de Áreas ────────────────────────────────

func _on_zona_base_body_entered(body: Node3D) -> void:
	if estado_actual == EstadoTrabajo.INACTIVO:
		if body.is_in_group("jugador") or body.is_in_group("vehiculo"):
			iniciar_trabajo()
	elif estado_actual == EstadoTrabajo.RETORNANDO:
		if body == vehiculo_instanciado or body.is_in_group("jugador") or body.is_in_group("vehiculo"):
			terminar_y_cobrar()

func _on_zona_entrega_body_entered(body: Node3D) -> void:
	if estado_actual == EstadoTrabajo.ENTREGANDO:
		if tiene_paquete:
			if body.is_in_group("jugador"):
				jugador_en_zona_entrega = true
				if is_instance_valid(panel_entrega_interactivo):
					panel_entrega_interactivo.visible = true
					btn_tocar_puerta.visible = true
					progress_bar_entrega.visible = false
					label_entrega_titulo.text = "TOCA LA PUERTA PARA ENTREGAR"
		else:
			if body == vehiculo_instanciado or body.is_in_group("jugador") or body.is_in_group("vehiculo"):
				_mostrar_notificacion("Bájate del vehículo y recoge el paquete de la Zona de Carga trasera.")

func _on_zona_entrega_body_exited(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		jugador_en_zona_entrega = false
		_cancelar_espera_cliente()

func recoger_paquete() -> void:
	if not tiene_paquete:
		tiene_paquete = true
		_limpiar_zona_carga_visual()
		var zc_pos = global_position
		if is_instance_valid(vehiculo_instanciado):
			var zona_carga = vehiculo_instanciado.find_child("EspacioCajas", true, false)
			if not zona_carga:
				zona_carga = vehiculo_instanciado.find_child("ZonaCajas", true, false)
			if not zona_carga:
				zona_carga = vehiculo_instanciado.find_child("ZonaCarga", true, false)
			if zona_carga:
				zc_pos = zona_carga.global_position
				
		# Determinar si la última caja del furgón era delicada
		var es_delicada = false
		if not cajas_visuales_instanciadas.is_empty():
			var visual_caja = cajas_visuales_instanciadas[-1]
			if is_instance_valid(visual_caja) and visual_caja.has_meta("delicada"):
				es_delicada = visual_caja.get_meta("delicada")
				caja_actual_delicada = es_delicada
				caja_salud = visual_caja.get_meta("salud") if visual_caja.has_meta("salud") else caja_salud
				
		# Instanciar físicamente la caja y dársela al jugador en las manos
		var jugador = get_tree().get_first_node_in_group("jugador")
		if jugador and jugador.has_method("agarrar_caja"):
			if caja_escena:
				var nueva_caja = caja_escena.instantiate()
				
				# Aplicar estilo delicado si se detectó
				if es_delicada:
					var mesh = nueva_caja.find_child("MeshInstance3D", true, false) as MeshInstance3D
					if mesh:
						var mat = StandardMaterial3D.new()
						mat.albedo_color = Color(1.0, 0.3, 0.0)
						mat.roughness = 0.5
						mat.emission_enabled = true
						mat.emission = Color(1.0, 0.15, 0.0)
						mat.emission_energy_multiplier = 1.2
						mesh.material_override = mat
						
					var label3d = Label3D.new()
					label3d.text = "[ DELICADA ]"
					label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					label3d.font_size = 14
					label3d.outline_size = 4
					label3d.modulate = Color(1.0, 0.2, 0.0)
					label3d.position = Vector3(0, 0.25, 0)
					var font = load("res://recursos/fonts/Moderniz.otf")
					if font:
						label3d.font = font
					nueva_caja.add_child(label3d)
					
				jugador.agarrar_caja(nueva_caja)
				
		# Eliminar una caja visual fija del compartimento trasero del furgón
		if not cajas_visuales_instanciadas.is_empty():
			var visual_caja = cajas_visuales_instanciadas.pop_back()
			if is_instance_valid(visual_caja):
				visual_caja.queue_free()
				
		_crear_efecto_satisfaccion(zc_pos, Color(0.0, 0.75, 1.0), Color(0.0, 1.0, 0.8)) # Estallido turquesa neón
		if es_delicada:
			_mostrar_notificacion("¡PAQUETE DELICADO RECOGIDO! SALUD: %d%%" % int(caja_salud))
		else:
			_mostrar_notificacion("¡Paquete recogido! Llévalo al punto verde neón marcado en el suelo.")

func _crear_ui_entrega_y_factura() -> void:
	if not canvas_notif:
		return
		
	var font_moderniz = load("res://recursos/fonts/Moderniz.otf")
	
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color(0.04, 0.04, 0.07, 0.95)
	style_panel.corner_detail = 12
	style_panel.set_corner_radius_all(14)
	style_panel.set_content_margin_all(20)
	style_panel.border_width_left = 2
	style_panel.border_width_top = 2
	style_panel.border_width_right = 2
	style_panel.border_width_bottom = 2
	style_panel.border_color = Color(0.2, 0.75, 1.0, 0.4)
	style_panel.shadow_color = Color(0, 0, 0, 0.6)
	style_panel.shadow_size = 14

	# 1. PANEL DE ENTREGA INTERACTIVO (TOCAR PUERTA)
	panel_entrega_interactivo = PanelContainer.new()
	panel_entrega_interactivo.visible = false
	panel_entrega_interactivo.custom_minimum_size = Vector2(400, 150)
	panel_entrega_interactivo.anchors_preset = Control.PRESET_CENTER_BOTTOM
	panel_entrega_interactivo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_entrega_interactivo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel_entrega_interactivo.position = Vector2(-200, -220)
	panel_entrega_interactivo.add_theme_stylebox_override("panel", style_panel)
	canvas_notif.add_child(panel_entrega_interactivo)
	
	var vbox_entrega = VBoxContainer.new()
	vbox_entrega.add_theme_constant_override("separation", 12)
	panel_entrega_interactivo.add_child(vbox_entrega)
	
	label_entrega_titulo = Label.new()
	label_entrega_titulo.text = "TOCA LA PUERTA PARA ENTREGAR"
	label_entrega_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_entrega_titulo.add_theme_font_size_override("font_size", 16)
	label_entrega_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	if font_moderniz:
		label_entrega_titulo.add_theme_font_override("font", font_moderniz)
	vbox_entrega.add_child(label_entrega_titulo)
	
	progress_bar_entrega = ProgressBar.new()
	progress_bar_entrega.custom_minimum_size = Vector2(300, 24)
	progress_bar_entrega.show_percentage = true
	progress_bar_entrega.value = 0.0
	progress_bar_entrega.visible = false
	
	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.12, 0.12, 0.16, 1.0)
	bg_bar.set_corner_radius_all(6)
	progress_bar_entrega.add_theme_stylebox_override("background", bg_bar)
	
	var fill_bar = StyleBoxFlat.new()
	fill_bar.bg_color = Color(1.0, 0.85, 0.0, 1.0) # Inicialmente amarillo dorado
	fill_bar.set_corner_radius_all(6)
	progress_bar_entrega.add_theme_stylebox_override("fill", fill_bar)
	vbox_entrega.add_child(progress_bar_entrega)
	
	btn_tocar_puerta = Button.new()
	btn_tocar_puerta.text = "TOCAR PUERTA"
	btn_tocar_puerta.custom_minimum_size = Vector2(300, 50)
	btn_tocar_puerta.focus_mode = Control.FOCUS_NONE
	btn_tocar_puerta.add_theme_font_size_override("font_size", 14)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.05, 0.45, 0.7, 0.85)
	btn_normal.set_corner_radius_all(10)
	btn_normal.set_content_margin_all(10)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.2, 0.85, 1.0, 0.6)
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.07, 0.55, 0.85, 0.95)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.9)
	
	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.02, 0.3, 0.5, 0.95)
	
	btn_tocar_puerta.add_theme_stylebox_override("normal", btn_normal)
	btn_tocar_puerta.add_theme_stylebox_override("hover", btn_hover)
	btn_tocar_puerta.add_theme_stylebox_override("pressed", btn_pressed)
	if font_moderniz:
		btn_tocar_puerta.add_theme_font_override("font", font_moderniz)
	btn_tocar_puerta.pressed.connect(_on_btn_tocar_puerta_pressed)
	vbox_entrega.add_child(btn_tocar_puerta)

	# 2. PANEL DE FACTURA / REPORTE FINAL (GIGANTE)
	panel_factura = PanelContainer.new()
	panel_factura.visible = false
	panel_factura.custom_minimum_size = Vector2(580, 480) # Factura más grande
	panel_factura.anchors_preset = Control.PRESET_CENTER
	panel_factura.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_factura.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel_factura.add_theme_stylebox_override("panel", style_panel)
	canvas_notif.add_child(panel_factura)
	
	var vbox_factura = VBoxContainer.new()
	vbox_factura.add_theme_constant_override("separation", 18)
	panel_factura.add_child(vbox_factura)
	
	var lbl_fac_tit = Label.new()
	lbl_fac_tit.text = "REPORTE DE ENTREGAS"
	lbl_fac_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fac_tit.add_theme_font_size_override("font_size", 24) # Título más grande
	lbl_fac_tit.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	if font_moderniz:
		lbl_fac_tit.add_theme_font_override("font", font_moderniz)
	vbox_factura.add_child(lbl_fac_tit)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	vbox_factura.add_child(scroll)
	
	vbox_factura_items = VBoxContainer.new()
	vbox_factura_items.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox_factura_items)
	
	label_factura_total = Label.new()
	label_factura_total.text = "TOTAL NETO GANADO: $0"
	label_factura_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_factura_total.add_theme_font_size_override("font_size", 22) # Total más grande y visible
	label_factura_total.add_theme_color_override("font_color", Color(0.2, 0.85, 0.35))
	if font_moderniz:
		label_factura_total.add_theme_font_override("font", font_moderniz)
	vbox_factura.add_child(label_factura_total)
	
	btn_factura_cobrar = Button.new()
	btn_factura_cobrar.text = "ACEPTAR Y COBRAR"
	btn_factura_cobrar.custom_minimum_size = Vector2(0, 52)
	btn_factura_cobrar.focus_mode = Control.FOCUS_NONE
	btn_factura_cobrar.add_theme_font_size_override("font_size", 15)
	
	var btn_cobrar_normal = btn_normal.duplicate()
	btn_cobrar_normal.bg_color = Color(0.1, 0.6, 0.2, 0.85)
	btn_cobrar_normal.border_color = Color(0.2, 0.85, 0.35, 0.6)
	
	var btn_cobrar_hover = btn_cobrar_normal.duplicate()
	btn_cobrar_hover.bg_color = Color(0.12, 0.7, 0.25, 0.95)
	btn_cobrar_hover.border_color = Color(0.2, 0.85, 0.35, 0.9)
	
	var btn_cobrar_pressed = btn_cobrar_normal.duplicate()
	btn_cobrar_pressed.bg_color = Color(0.05, 0.4, 0.1, 0.95)
	
	btn_factura_cobrar.add_theme_stylebox_override("normal", btn_cobrar_normal)
	btn_factura_cobrar.add_theme_stylebox_override("hover", btn_cobrar_hover)
	btn_factura_cobrar.add_theme_stylebox_override("pressed", btn_cobrar_pressed)
	if font_moderniz:
		btn_factura_cobrar.add_theme_font_override("font", font_moderniz)
	btn_factura_cobrar.pressed.connect(_on_btn_factura_cobrar_pressed)
	vbox_factura.add_child(btn_factura_cobrar)

func _on_btn_tocar_puerta_pressed() -> void:
	if not esperando_cliente:
		esperando_cliente = true
		etapa_entrega = 1
		tiempo_espera_acumulado = 0.0
		btn_tocar_puerta.visible = false
		progress_bar_entrega.visible = true
		progress_bar_entrega.value = 0.0
		label_entrega_titulo.text = "CLIENTE ACERCANDOSE A LA PUERTA..."
		label_entrega_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		
		# Forzar color amarillo de carga en la barra
		var fill_style = progress_bar_entrega.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		fill_style.bg_color = Color(1.0, 0.85, 0.0)
		progress_bar_entrega.add_theme_stylebox_override("fill", fill_style)
		
		# Reproducir sonido de golpear puerta
		var sound_path = "res://recursos/efectos/golpear_puerta.mp3"
		if ResourceLoader.exists(sound_path):
			var audio_player = AudioStreamPlayer.new()
			audio_player.stream = load(sound_path)
			add_child(audio_player)
			audio_player.play()
			audio_player.finished.connect(func(): audio_player.queue_free())

func _cancelar_espera_cliente() -> void:
	esperando_cliente = false
	if is_instance_valid(panel_entrega_interactivo):
		panel_entrega_interactivo.visible = false
	if is_instance_valid(btn_tocar_puerta):
		btn_tocar_puerta.visible = true
	if is_instance_valid(progress_bar_entrega):
		progress_bar_entrega.visible = false

func _avanzar_etapa_entrega() -> void:
	if etapa_entrega == 1:
		# Evaluar si el cliente está en casa (88% de éxito)
		var exito = randf() > 0.12
		if not exito:
			esperando_cliente = false
			panel_entrega_interactivo.visible = false
			
			# Soltar y borrar la caja que lleva el jugador
			var jugador = get_tree().get_first_node_in_group("jugador")
			if jugador and jugador.get("caja_agarrada") != null:
				var caja = jugador.soltar_caja()
				if caja:
					caja.queue_free()
			
			var nombres = ["JUAN", "MARIA", "PEDRO", "SOFIA", "CARLOS", "ANA", "LUIS", "ELENA", "JOSE", "LAURA"]
			var cliente = nombres[randi() % nombres.size()]
			reporte_ruta.append({
				"punto": entregas_completadas + 1,
				"cliente": cliente,
				"exito": false,
				"pago": 0.0,
				"distancia": distancia_entrega_actual
			})
			_mostrar_notificacion("NO HAY NADIE EN CASA ENTREGA FALLIDA")
			tiene_paquete = false
			cerca_mensaje_mostrado = false
			
			# Completar entrega con fallo con un retraso para poder leer la notificacion
			entregas_completadas += 1
			if not destinos_pendientes.is_empty():
				destinos_pendientes.remove_at(0)
			get_tree().create_timer(4.0).timeout.connect(func(): _siguiente_entrega())
		else:
			# El cliente abre la puerta! Pasa a la firma
			etapa_entrega = 2
			tiempo_espera_acumulado = 0.0
			label_entrega_titulo.text = "CLIENTE FIRMANDO ENTREGA..."
			label_entrega_titulo.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			
			# Cambiar color de la barra de carga a verde éxito
			var fill_style = progress_bar_entrega.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
			fill_style.bg_color = Color(0.2, 1.0, 0.4)
			progress_bar_entrega.add_theme_stylebox_override("fill", fill_style)
	elif etapa_entrega == 2:
		# Firma completada con éxito
		_completar_espera_cliente()

func _completar_espera_cliente() -> void:
	esperando_cliente = false
	panel_entrega_interactivo.visible = false
	
	# Soltar y borrar la caja que lleva el jugador
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador and jugador.get("caja_agarrada") != null:
		var caja = jugador.soltar_caja()
		if caja:
			caja.queue_free()
	
	var nombres = ["JUAN", "MARIA", "PEDRO", "SOFIA", "CARLOS", "ANA", "LUIS", "ELENA", "JOSE", "LAURA"]
	var cliente = nombres[randi() % nombres.size()]
	
	var pago = pago_entrega_actual
	
	# Penalizar pago si la caja es delicada y sufrió daños
	if caja_actual_delicada:
		var mult_salud = caja_salud / 100.0
		pago = snapped(pago * mult_salud, 1.0)
		
	reporte_ruta.append({
		"punto": entregas_completadas + 1,
		"cliente": cliente,
		"exito": true,
		"pago": pago,
		"distancia": distancia_entrega_actual,
		"delicada": caja_actual_delicada,
		"salud": caja_salud
	})
	
	_crear_efecto_satisfaccion(global_position, Color(0.15, 0.85, 0.35), Color(1.0, 0.9, 0.1))
	if caja_actual_delicada and caja_salud < 100.0:
		_mostrar_notificacion("ENTREGA: %s. PAGO CON DESCUENTO POR DAÑO: $%d (SALUD: %d%%)" % [cliente, int(pago), int(caja_salud)])
	else:
		_mostrar_notificacion("EL CLIENTE " + cliente + " SALIO Y RECIBIO EL PAQUETE. PAGO: $%d" % int(pago))
	
	var sonido_coche = vehiculo_instanciado.get_node_or_null("Sonido_dual") if is_instance_valid(vehiculo_instanciado) else null
	if sonido_coche and sonido_coche.has_method("reproducir_claxon"):
		sonido_coche.call_deferred("reproducir_claxon")
		
	tiene_paquete = false
	cerca_mensaje_mostrado = false
	
	# Siguiente parada con un retraso para poder leer la notificacion
	entregas_completadas += 1
	if not destinos_pendientes.is_empty():
		destinos_pendientes.remove_at(0)
	get_tree().create_timer(4.0).timeout.connect(func(): _siguiente_entrega())

func _mostrar_reporte_final() -> void:
	# Limpiar items anteriores
	for c in vbox_factura_items.get_children():
		c.queue_free()
		
	var font_moderniz = load("res://recursos/fonts/Moderniz.otf")
	var total_acumulado = 0.0
	
	for item in reporte_ruta:
		var HBoxPrincipal = VBoxContainer.new() # VBox para soportar doble fila por item
		HBoxPrincipal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_factura_items.add_child(HBoxPrincipal)
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		HBoxPrincipal.add_child(hbox)
		
		var lbl_nombre = Label.new()
		lbl_nombre.text = "PUNTO %d: %s" % [item["punto"], item["cliente"]]
		lbl_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_nombre.add_theme_font_size_override("font_size", 17) # Fuentes de items aumentadas
		if font_moderniz:
			lbl_nombre.add_theme_font_override("font", font_moderniz)
		hbox.add_child(lbl_nombre)
		
		var lbl_estado = Label.new()
		if item["exito"]:
			lbl_estado.text = "ENTREGADO"
			lbl_estado.add_theme_color_override("font_color", Color(0.2, 0.85, 0.35))
		else:
			lbl_estado.text = "SIN RESPUESTA"
			lbl_estado.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		lbl_estado.add_theme_font_size_override("font_size", 16) # Estado aumentado
		if font_moderniz:
			lbl_estado.add_theme_font_override("font", font_moderniz)
		hbox.add_child(lbl_estado)
		
		var lbl_pago = Label.new()
		lbl_pago.text = "  $%d" % int(item["pago"])
		lbl_pago.add_theme_font_size_override("font_size", 18) # Pagos aumentados
		if font_moderniz:
			lbl_pago.add_theme_font_override("font", font_moderniz)
		hbox.add_child(lbl_pago)
		
		# Fila secundaria con info de salud si el paquete era delicado
		if item.get("delicada") == true:
			var hbox_sub = HBoxContainer.new()
			hbox_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			HBoxPrincipal.add_child(hbox_sub)
			
			var lbl_delicada_status = Label.new()
			var salud_int = int(item["salud"])
			lbl_delicada_status.text = "  -> PAQUETE DELICADO: SALUD AL %d%%" % salud_int
			lbl_delicada_status.add_theme_font_size_override("font_size", 13)
			if salud_int == 100:
				lbl_delicada_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.35, 0.8)) # Verde tenue
			elif salud_int > 50:
				lbl_delicada_status.add_theme_color_override("font_color", Color(1.0, 0.65, 0.0, 0.8)) # Naranja tenue
			else:
				lbl_delicada_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 0.8)) # Rojo tenue
			if font_moderniz:
				lbl_delicada_status.add_theme_font_override("font", font_moderniz)
			hbox_sub.add_child(lbl_delicada_status)
		
		total_acumulado += item["pago"]

	# Aplicar y mostrar descuento si existiese retraso
	if descuento_acumulado > 0.0:
		var hbox_desc = HBoxContainer.new()
		hbox_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_factura_items.add_child(hbox_desc)
		
		var lbl_desc_name = Label.new()
		lbl_desc_name.text = "DESCUENTO POR RETRASO"
		lbl_desc_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_desc_name.add_theme_font_size_override("font_size", 17)
		lbl_desc_name.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		if font_moderniz:
			lbl_desc_name.add_theme_font_override("font", font_moderniz)
		hbox_desc.add_child(lbl_desc_name)
		
		var lbl_desc_val = Label.new()
		lbl_desc_val.text = "-$%d" % int(descuento_acumulado)
		lbl_desc_val.add_theme_font_size_override("font_size", 18)
		lbl_desc_val.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		if font_moderniz:
			lbl_desc_val.add_theme_font_override("font", font_moderniz)
		hbox_desc.add_child(lbl_desc_val)
		
		total_acumulado = max(total_acumulado - descuento_acumulado, 0.0)
		
	label_factura_total.text = "TOTAL NETO GANADO: $%d" % int(total_acumulado)
	mision_activa["recompensa"] = total_acumulado
	panel_factura.visible = true
	
	# Centrar el panel gigante de factura
	var screen_size = panel_factura.get_viewport_rect().size
	panel_factura.size = Vector2(580, 480)
	panel_factura.global_position = (screen_size - panel_factura.size) * 0.5

func _on_btn_factura_cobrar_pressed() -> void:
	panel_factura.visible = false
	retorno_timer_activo = false
	terminar_y_cobrar()

func _actualizar_hud_retorno() -> void:
	if not is_instance_valid(hud_progreso) or not is_instance_valid(label_progreso) or not is_instance_valid(barra_progreso):
		return
		
	hud_progreso.visible = true
	
	var minutos = int(retorno_tiempo_restante / 60.0)
	var segundos = int(retorno_tiempo_restante) % 60
	var tiempo_texto = "%02d:%02d" % [minutos, segundos]
	
	if retorno_etapa == 1:
		label_progreso.text = "TIEMPO RETORNO: %s (NORMAL)" % tiempo_texto
		label_progreso.add_theme_color_override("font_color", Color.WHITE)
		barra_progreso.max_value = tiempo_etapa_normal
		barra_progreso.value = retorno_tiempo_restante
		var fill = barra_progreso.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		fill.bg_color = Color(0.0, 0.85, 1.0)
		barra_progreso.add_theme_stylebox_override("fill", fill)
	elif retorno_etapa == 2:
		var segundos_tarde = tiempo_etapa_descuento - retorno_tiempo_restante
		descuento_acumulado = snapped(segundos_tarde * 3.0, 1.0)
		
		label_progreso.text = "RETORNO TARDE: %s (-$%d)" % [tiempo_texto, int(descuento_acumulado)]
		label_progreso.add_theme_color_override("font_color", Color(1.0, 0.65, 0.0))
		barra_progreso.max_value = tiempo_etapa_descuento
		barra_progreso.value = retorno_tiempo_restante
		var fill = barra_progreso.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		fill.bg_color = Color(1.0, 0.65, 0.0)
		barra_progreso.add_theme_stylebox_override("fill", fill)
	elif retorno_etapa == 3:
		label_progreso.text = "ALERTA REMOLQUE: %s" % tiempo_texto
		label_progreso.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		barra_progreso.max_value = tiempo_etapa_desaparecer
		barra_progreso.value = retorno_tiempo_restante
		var fill = barra_progreso.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		fill.bg_color = Color(1.0, 0.2, 0.2)
		barra_progreso.add_theme_stylebox_override("fill", fill)

func _avanzar_etapa_retorno() -> void:
	if retorno_etapa == 1:
		retorno_etapa = 2
		retorno_tiempo_restante = tiempo_etapa_descuento
		_mostrar_notificacion("TIEMPO LIMITE EXCEDIDO DESCUENTO ACTIVO POR RETRASO")
	elif retorno_etapa == 2:
		retorno_etapa = 3
		retorno_tiempo_restante = tiempo_etapa_desaparecer
		_mostrar_notificacion("FURGON ABANDONADO SE DESESPAWNEARA EN 10 SEGUNDOS")
	elif retorno_etapa == 3:
		retorno_timer_activo = false
		_despawnear_vehiculo()
		_resetear_sistema()
		_mostrar_notificacion("TIEMPO LIMITE COMPLETADO VEHICULO REMOLCADO TRABAJO FALLIDO")

func _exit_tree() -> void:
	_limpiar_zona_base()
	_limpiar_zona_entrega()
	_limpiar_zona_carga_visual()
	_limpiar_zona_recogida()
	_despawnear_vehiculo()
	if is_instance_valid(canvas_notif):
		canvas_notif.queue_free()

func confirmar_salida_ruta() -> void:
	if estado_actual == EstadoTrabajo.LISTO_PARA_PARTIR:
		estado_actual = EstadoTrabajo.ENTREGANDO
		_mostrar_notificacion("SALIDA CONFIRMADA! SIGUE LA RUTA EN EL GPS PARA ENTREGAR LAS CAJAS.")
		_siguiente_entrega()

func cargar_caja_desde_area(jugador: Node3D, zc_pos: Vector3) -> void:
	if estado_actual != EstadoTrabajo.CARGANDO:
		return

	# Quitar la caja de las manos del jugador y eliminarla
	var caja = jugador.soltar_caja()
	if is_instance_valid(caja):
		caja.queue_free()

	# Buscar EspacioCajas (o fallback) en el vehiculo
	var marker_cajas: Node3D = null
	if is_instance_valid(vehiculo_instanciado):
		marker_cajas = vehiculo_instanciado.find_child("EspacioCajas", true, false)
		if not marker_cajas:
			marker_cajas = vehiculo_instanciado.find_child("ZonaCajas", true, false)
		if not marker_cajas:
			marker_cajas = vehiculo_instanciado.find_child("ZonaCarga", true, false)

	# Colocar caja visual estatica en EspacioCajas directamente
	_colocar_caja_visual_en_espacio(marker_cajas)

	_crear_efecto_satisfaccion(zc_pos, Color(1.0, 0.85, 0.0), Color(0.0, 0.85, 1.0))
	cajas_cargadas += 1

	if hud_progreso and label_progreso and barra_progreso:
		label_progreso.text = "CAJAS CARGADAS: %d / %d" % [cajas_cargadas, total_entregas_mision]
		barra_progreso.value = cajas_cargadas

	if cajas_cargadas < total_entregas_mision:
		_mostrar_notificacion("CAJA CARGADA (%d/%d). RECOGE OTRA EN EL PUNTO DE RECOGIDA." % [cajas_cargadas, total_entregas_mision])
		_actualizar_gps_celular(zona_recogida_posicion, "Recogida de Cajas")
	else:
		_mostrar_notificacion("TODAS LAS CAJAS CARGADAS! VE A HABLAR CON EL JEFE DE LOGISTICA PARA CONFIRMAR LA SALIDA.")
		_limpiar_zona_recogida()
		_limpiar_zona_carga_visual()
		estado_actual = EstadoTrabajo.LISTO_PARA_PARTIR
		_actualizar_gps_celular(base_posicion, "Confirmar Salida con Jefe")


func _colocar_caja_visual_en_espacio(marker_cajas: Node3D) -> void:
	if not marker_cajas or not caja_escena:
		return
	var visual_caja = caja_escena.instantiate()
	
	# Si la caja actual es delicada, aplicar estilo visual aquí también
	if caja_actual_delicada:
		var mesh = visual_caja.find_child("MeshInstance3D", true, false) as MeshInstance3D
		if mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.3, 0.0)
			mat.roughness = 0.5
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.15, 0.0)
			mat.emission_energy_multiplier = 1.2
			mesh.material_override = mat
			
		var label3d = Label3D.new()
		label3d.text = "[ DELICADA ]"
		label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label3d.font_size = 14
		label3d.outline_size = 4
		label3d.modulate = Color(1.0, 0.2, 0.0)
		label3d.position = Vector3(0, 0.25, 0)
		var font = load("res://recursos/fonts/Moderniz.otf")
		if font:
			label3d.font = font
		visual_caja.add_child(label3d)
		
		# Guardar información de fragilidad/salud en la caja visual instanciada como meta
		visual_caja.set_meta("delicada", true)
		visual_caja.set_meta("salud", caja_salud)
	
	marker_cajas.add_child(visual_caja)
	# Desactivar fisica y colisiones de la caja visual estatica
	if visual_caja is RigidBody3D:
		visual_caja.freeze = true
		var shape = visual_caja.find_child("CollisionShape3D", true, false)
		if shape:
			shape.disabled = true
	var offset_idx = (cajas_cargadas - 1) % offsets_cajas.size()
	visual_caja.position = offsets_cajas[offset_idx]
	visual_caja.rotation = Vector3.ZERO
	cajas_visuales_instanciadas.append(visual_caja)

func _inicializar_zona_carga_furgon() -> void:
	cajas_visuales_instanciadas.clear()
	if not is_instance_valid(vehiculo_instanciado):
		return
		
	var marker_cajas = vehiculo_instanciado.find_child("EspacioCajas", true, false)
	if not marker_cajas:
		marker_cajas = vehiculo_instanciado.find_child("ZonaCajas", true, false)
	if not marker_cajas:
		marker_cajas = vehiculo_instanciado.find_child("ZonaCarga", true, false)
		
	if marker_cajas:
		# 1. Crear Area3D dinámica de colisión
		area_carga_dinamica = Area3D.new()
		area_carga_dinamica.collision_layer = 0
		area_carga_dinamica.collision_mask = 4294967295
		
		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(2.2, 2.0, 2.2)
		collision.shape = box_shape
		area_carga_dinamica.add_child(collision)
		
		marker_cajas.add_child(area_carga_dinamica)
		area_carga_dinamica.position = Vector3.ZERO
		
		# Conectar señal de entrada
		area_carga_dinamica.body_entered.connect(_on_zona_carga_dinamica_body_entered)

func _on_zona_carga_dinamica_body_entered(_body: Node3D) -> void:
	# Carga automática desactivada. El jugador debe usar el botón de la UI "SOLTAR CAJA".
	pass
