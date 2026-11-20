extends Node3D

## academia_licencias.gd
## Sistema completo de pruebas de manejo para Licencias C1, C2 y C3.
## Instancia mapa de Blender, robles reales, materiales PBR de Godot, conos físicos,
## carteles 3D (Label3D), checkpoints luminosos, sonidos y HUD Automotive Glassmorphism.

const FONT := preload("res://recursos/fonts/Moderniz.otf")
const RUTA_CESPED := "res://materiales/Mapa/Cesped/Cesped.tres"
const RUTA_ASFALTO_ALBEDO := "res://mundo/editor_mapas/modelos/texturas/asfalto_pbr_albedo.png"
const RUTA_ASFALTO_NORMAL := "res://mundo/editor_mapas/modelos/texturas/asfalto_pbr_normal.png"
const RUTA_ASFALTO_ROUGH := "res://mundo/editor_mapas/modelos/texturas/asfalto_pbr_roughness.png"
const RUTA_ROBLE := "res://modelos3d/mapa/arboles/arbol_roble_3d.tscn"
const RUTA_CONO := "res://modelos3d/mapa/academia/cono_trafico.glb"

const RUTA_VEH_C1 := "res://modelos3d/vehiculos/automoviles/Duster/duster.tscn"
const RUTA_VEH_C2 := "res://modelos3d/vehiculos/rigidos_fisicas/NPR/npr_fisicas.tscn"
const RUTA_VEH_C3 := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_A.tscn"
const RUTA_TRAILER_C3 := "res://modelos3d/Trailers y remolques/Carpado/carpado.tscn"

const SFX_CHECKPOINT := "res://recursos/efectos/checkpoint.mp3"
const SFX_VICTORIA := "res://recursos/efectos/level_up.mp3"
const SFX_GOLPE := "res://recursos/sonidos_vehiculo/efectos/choque_leve.mp3"

const MAX_CONOS_PERMITIDOS := 4

var categoria: String = "C1"
var _vehiculo: Node3D = null
var _trailer: Node3D = null
var _jugador: Node3D = null

var _checkpoints: Array[Dictionary] = []
var _cp_idx: int = 0
var _cp_beacon: Node3D = null
var _cp_ring: MeshInstance3D = null
var _cp_ring_inner: MeshInstance3D = null
var _cp_beam: MeshInstance3D = null
var _cp_label3d: Label3D = null
var _cp_next_beacon: Node3D = null
var _flecha_guia: Node3D = null
var _toast_paso: PanelContainer = null
var _toast_paso_lbl: Label = null

var _conos_data: Array[Dictionary] = []
var _conos_derribados: int = 0
var _max_conos: int = MAX_CONOS_PERMITIDOS
var _tiempo_restante: float = 180.0
var _tiempo_detenido_cp: float = 0.0
var _reversa_validada_cp: bool = false
var _examen_activo: bool = false
var _examen_terminado: bool = false
var _tiempo_anim: float = 0.0

# HUD
var _hud_layer: CanvasLayer = null
var _lbl_licencia: Label = null
var _lbl_progreso: Label = null
var _lbl_tiempo: Label = null
var _lbl_conos: Label = null
var _lbl_vel: Label = null
var _lbl_instruccion: Label = null
var _lbl_distancia: Label = null
var _sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	if DatosUsuario and "licencia_prueba_pendiente" in DatosUsuario and not str(DatosUsuario.licencia_prueba_pendiente).strip_edges().is_empty():
		categoria = str(DatosUsuario.licencia_prueba_pendiente).strip_edges().to_upper()
	if categoria != "C1" and categoria != "C2" and categoria != "C3":
		categoria = "C1"

	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

	_aplicar_materiales_realistas_mapa()
	_poblar_robles_reales()
	_crear_carteles_3d()
	_configurar_recorrido_por_licencia()
	_spawnear_conos_fisicos()
	_spawnear_vehiculo_y_jugador()
	_crear_beacon_checkpoint()
	_construir_hud_glassmorphism()
	_actualizar_checkpoint_visual()
	_examen_activo = true


func _process(delta: float) -> void:
	_tiempo_anim += delta
	if _cp_ring and is_instance_valid(_cp_ring):
		_cp_ring.rotate_y(delta * 1.6)
		_cp_ring.position.y = 0.55 + sin(_tiempo_anim * 2.8) * 0.14
	if _cp_ring_inner and is_instance_valid(_cp_ring_inner):
		_cp_ring_inner.rotate_y(-delta * 2.4)
		_cp_ring_inner.position.y = 1.05 + cos(_tiempo_anim * 3.2) * 0.12
	if _flecha_guia and is_instance_valid(_flecha_guia) and _vehiculo and _cp_idx < _checkpoints.size():
		var alto_flecha := 3.6 if categoria == "C1" else 4.8
		_flecha_guia.global_position = _vehiculo.global_position + Vector3(0.0, alto_flecha + sin(_tiempo_anim * 4.0) * 0.14, 0.0)
		var objetivo: Vector3 = _checkpoints[_cp_idx]["pos"]
		var target_flat := Vector3(objetivo.x, _flecha_guia.global_position.y, objetivo.z)
		if _flecha_guia.global_position.distance_to(target_flat) > 1.0:
			_flecha_guia.look_at(target_flat, Vector3.UP)
		_flecha_guia.visible = _examen_activo and not _examen_terminado

	if not _examen_activo or _examen_terminado:
		return

	_tiempo_restante = maxf(0.0, _tiempo_restante - delta)
	_verificar_conos_derribados()
	_actualizar_hud_en_vivo()
	_verificar_progreso_checkpoint()

	if _tiempo_restante <= 0.0:
		_finalizar_examen(false, "TIEMPO AGOTADO EN LA PRUEBA")
	elif _conos_derribados >= _max_conos:
		_finalizar_examen(false, "DEMASIADOS CONOS DERRIBADOS (%d/%d)" % [_conos_derribados, _max_conos])


# ═══════════════════════════════════════════════════════════════════════════════
# 1. ENTORNO REALISTA: MATERIALES GODOT + ROBLES REALES + CARTELES 3D
# ═══════════════════════════════════════════════════════════════════════════════

func _aplicar_materiales_realistas_mapa() -> void:
	var mapa := get_node_or_null("MapaAcademia")
	if not mapa:
		return

	var mat_cesped: Material = load(RUTA_CESPED) if ResourceLoader.exists(RUTA_CESPED) else null
	var mat_asfalto := StandardMaterial3D.new()
	mat_asfalto.albedo_color = Color(0.88, 0.89, 0.91, 1.0)
	if ResourceLoader.exists(RUTA_ASFALTO_ALBEDO):
		mat_asfalto.albedo_texture = load(RUTA_ASFALTO_ALBEDO)
	if ResourceLoader.exists(RUTA_ASFALTO_NORMAL):
		mat_asfalto.normal_enabled = true
		mat_asfalto.normal_texture = load(RUTA_ASFALTO_NORMAL)
		mat_asfalto.normal_scale = 1.25
	if ResourceLoader.exists(RUTA_ASFALTO_ROUGH):
		mat_asfalto.roughness_texture = load(RUTA_ASFALTO_ROUGH)
	mat_asfalto.roughness = 0.88
	mat_asfalto.uv1_triplanar = true
	mat_asfalto.uv1_scale = Vector3(0.16, 0.16, 0.16)

	var cola: Array[Node] = [mapa]
	while not cola.is_empty():
		var n: Node = cola.pop_back()
		if n is MeshInstance3D:
			var nm := n.name.to_lower()
			if mat_cesped and nm.begins_with("terraingrass"):
				n.material_override = mat_cesped
			elif nm.begins_with("roadasphalt") or nm.begins_with("ramphillasphalt"):
				n.material_override = mat_asfalto
		for h in n.get_children():
			cola.append(h)


func _poblar_robles_reales() -> void:
	if not ResourceLoader.exists(RUTA_ROBLE):
		return
	var roble_ps := load(RUTA_ROBLE) as PackedScene
	if not roble_ps:
		return

	var contenedor := Node3D.new()
	contenedor.name = "RoblesAcademia"
	add_child(contenedor)

	var posiciones: Array[Vector4] = [
		# Borde Oeste (tras la academia y parqueadero)
		Vector4(-48, 0, -56, 1.3), Vector4(-50, 0, -28, 1.2), Vector4(-48, 0, 6, 1.25),
		Vector4(-50, 0, 38, 1.2), Vector4(-46, 0, 72, 1.35),
		# Borde Norte (tras la curva amplia y chicana)
		Vector4(-14, 0, -86, 1.25), Vector4(18, 0, -96, 1.2), Vector4(52, 0, -96, 1.3),
		Vector4(86, 1.2, -82, 1.25), Vector4(110, 3.0, -54, 1.35),
		# Borde Este (acompañando la subida y cresta andina)
		Vector4(114, 5.5, -18, 1.35), Vector4(112, 5.8, 18, 1.3), Vector4(104, 3.5, 52, 1.25),
		Vector4(86, 1.5, 84, 1.2),
		# Borde Sur (tras los resaltos)
		Vector4(56, 0, 98, 1.25), Vector4(24, 0, 98, 1.3), Vector4(-12, 0, 92, 1.2),
		# Isla central verde (bosque interior lejos de la calzada)
		Vector4(36, 0, -42, 1.25), Vector4(58, 1.2, -26, 1.15), Vector4(34, 0, -10, 1.35),
		Vector4(58, 1.5, 10, 1.25), Vector4(36, 0, 26, 1.2), Vector4(52, 0.8, 42, 1.15),
		Vector4(24, 0, 48, 1.1),
		# Cercanías de la torre y edificio
		Vector4(-16, 0, -48, 1.15), Vector4(-36, 0, -34, 1.25), Vector4(-38, 0, 24, 1.1),
	]

	for i in range(posiciones.size()):
		var p: Vector4 = posiciones[i]
		var arbol := roble_ps.instantiate() as Node3D
		if arbol:
			arbol.position = Vector3(p.x, p.y, p.z)
			arbol.rotation.y = float(i) * 1.37
			arbol.scale = Vector3.ONE * p.w
			contenedor.add_child(arbol)


func _crear_carteles_3d() -> void:
	# Señalización vial física realista (tableros metálicos + postes galvanizados)
	# sin textos flotantes gigantes que ensucien el paisaje.
	var carteles_root := Node3D.new()
	carteles_root.name = "SenalesViales3D"
	add_child(carteles_root)

	var mat_poste := StandardMaterial3D.new()
	mat_poste.albedo_color = Color(0.55, 0.58, 0.62)
	mat_poste.metallic = 0.78
	mat_poste.roughness = 0.38

	var mat_marco := StandardMaterial3D.new()
	mat_marco.albedo_color = Color(0.11, 0.12, 0.14)
	mat_marco.metallic = 0.65
	mat_marco.roughness = 0.45

	var mat_preventivo := StandardMaterial3D.new()
	mat_preventivo.albedo_color = Color(0.92, 0.72, 0.12)
	mat_preventivo.roughness = 0.35

	var mat_informativo := StandardMaterial3D.new()
	mat_informativo.albedo_color = Color(0.08, 0.34, 0.19)
	mat_informativo.roughness = 0.38

	var mat_arco := StandardMaterial3D.new()
	mat_arco.albedo_color = Color(0.08, 0.09, 0.11)
	mat_arco.metallic = 0.55
	mat_arco.roughness = 0.35

	# 1) Letrero metálico integrado en el arco de salida
	var arco_holder := Node3D.new()
	arco_holder.position = Vector3(0.0, 8.2, 36.7)
	carteles_root.add_child(arco_holder)

	var placa_arco := MeshInstance3D.new()
	var box_arco := BoxMesh.new()
	box_arco.size = Vector3(6.8, 0.95, 0.14)
	placa_arco.mesh = box_arco
	placa_arco.material_override = mat_arco
	arco_holder.add_child(placa_arco)

	var lbl_arco := Label3D.new()
	lbl_arco.text = "ACADEMIA NUESTRA TIERRA  |  EXAMEN " + categoria
	lbl_arco.font = FONT
	lbl_arco.font_size = 38
	lbl_arco.pixel_size = 0.0055
	lbl_arco.position = Vector3(0.0, 0.0, 0.08)
	lbl_arco.modulate = Color(0.94, 0.74, 0.26)
	lbl_arco.outline_size = 0
	lbl_arco.shaded = true
	lbl_arco.double_sided = false
	arco_holder.add_child(lbl_arco)

	# 2) Señales viales compactas de carretera (escala real 1.55m x 0.75m)
	var senales: Array[Dictionary] = [
		{"pos": Vector3(-9.5, 2.25, 16.0), "rot_y": 28.0, "texto": "ESLALON", "tipo": "prev"},
		{"pos": Vector3(24.0, 2.25, -67.0), "rot_y": -32.0, "texto": "CHICANA\nMAX 45", "tipo": "prev"},
		{"pos": Vector3(77.0, 3.6, -52.0), "rot_y": -132.0, "texto": "SUBIDA\nANDINA", "tipo": "info"},
		{"pos": Vector3(81.0, 7.2, 28.0), "rot_y": 148.0, "texto": "BAJADA\nFRENO MOTOR", "tipo": "info"},
		{"pos": Vector3(52.0, 2.25, 71.0), "rot_y": 148.0, "texto": "RESALTOS\n20 KM/H", "tipo": "prev"},
		{"pos": Vector3(-24.5, 2.25, 38.5), "rot_y": 0.0, "texto": "BAHIA DE\nPARQUEO", "tipo": "info"},
	]

	for s in senales:
		var holder := Node3D.new()
		holder.position = s["pos"]
		holder.rotation_degrees.y = float(s["rot_y"])
		carteles_root.add_child(holder)

		# Poste galvanizado
		var poste := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.055
		cyl.height = 2.4
		poste.mesh = cyl
		poste.position = Vector3(0.0, -1.2, -0.05)
		poste.material_override = mat_poste
		holder.add_child(poste)

		# Marco metálico trasero
		var marco := MeshInstance3D.new()
		var mb := BoxMesh.new()
		mb.size = Vector3(1.62, 0.82, 0.05)
		marco.mesh = mb
		marco.material_override = mat_marco
		holder.add_child(marco)

		# Cara frontal reflectiva (amarilla preventiva o verde informativa)
		var es_prev: bool = (s["tipo"] == "prev")
		var cara := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(1.52, 0.72, 0.02)
		cara.mesh = cb
		cara.position = Vector3(0.0, 0.0, 0.025)
		cara.material_override = mat_preventivo if es_prev else mat_informativo
		holder.add_child(cara)

		# Texto impreso sobre la placa física (sin contorno negro ni brillo arcade)
		var lbl := Label3D.new()
		lbl.text = str(s["texto"])
		lbl.font = FONT
		lbl.font_size = 34
		lbl.pixel_size = 0.0044
		lbl.position = Vector3(0.0, 0.0, 0.04)
		lbl.modulate = Color(0.08, 0.09, 0.10) if es_prev else Color(0.96, 0.97, 0.98)
		lbl.outline_size = 0
		lbl.shaded = true
		lbl.double_sided = false
		holder.add_child(lbl)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. RECORRIDO, CONOS FÍSICOS Y VEHÍCULOS POR LICENCIA (C1, C2, C3)
# ═══════════════════════════════════════════════════════════════════════════════

func _configurar_recorrido_por_licencia() -> void:
	_checkpoints.clear()
	match categoria:
		"C1":
			# C1: Tutorial dinámico interactivo con 10 pruebas progresivas de conducción
			_tiempo_restante = 260.0
			_max_conos = 4
			_checkpoints = [
				{"pos": Vector3(0.0, 0.2, 34.0), "radio": 8.0, "titulo": "ARRANQUE Y SALIDA", "msg": "PASO 1/10: SUBE AL VEHICULO Y ACELERA (W / PEDAL DER.) PARA CRUZAR EL ARCO"},
				{"pos": Vector3(0.0, 0.2, 0.0), "radio": 7.5, "titulo": "CONTROL DE VOLANTE", "msg": "PASO 2/10: USA A/D O EL VOLANTE PARA TRAZAR EL ESLALON ENTRE CONOS"},
				{"pos": Vector3(0.0, 0.2, -28.0), "radio": 8.0, "titulo": "ESLALON COMPLETADO", "msg": "PASO 3/10: MANTEN EL RITMO Y TERMINA EL ESLALON SIN DERRIBAR CONOS"},
				{"pos": Vector3(14.0, 0.2, -68.0), "radio": 8.5, "frenar": true, "hold": 0.8, "titulo": "FRENADO DE EMERGENCIA", "msg": "PASO 4/10: PRUEBA DE FRENO - DETENTE POR COMPLETO CON S O ESPACIO"},
				{"pos": Vector3(52.0, 0.7, -78.0), "radio": 9.0, "max_kmh": 45.0, "titulo": "CHICANA CONTROLADA", "msg": "PASO 5/10: ATRAVIESA LA CHICANA A VELOCIDAD SEGURA (MAX 45 KM/H)"},
				{"pos": Vector3(86.0, 2.6, -54.0), "radio": 9.0, "frenar": true, "hold": 0.7, "titulo": "ARRANQUE EN PENDIENTE", "msg": "PASO 6/10: DETENTE EN LA SUBIDA Y ARRANCA SIN DEJARTE RODAR"},
				{"pos": Vector3(94.0, 6.4, -12.0), "radio": 9.0, "min_kmh": 22.0, "titulo": "POTENCIA EN COLINA", "msg": "PASO 7/10: SUBE LA COLINA SOSTENIENDO AL MENOS 22 KM/H EN LA CIMA"},
				{"pos": Vector3(72.0, 3.0, 64.0), "radio": 9.0, "max_kmh": 45.0, "titulo": "DESCENSO EN CURVA", "msg": "PASO 8/10: CONTROLA LA BAJADA EN CURVA SIN SUPERAR 45 KM/H"},
				{"pos": Vector3(36.0, 0.2, 80.0), "radio": 9.0, "max_kmh": 26.0, "titulo": "RESALTOS DE SUSPENSION", "msg": "PASO 9/11: CRUZA LOS RESALTOS SUAVE A MENOS DE 26 KM/H"},
				{"pos": Vector3(-24.0, 0.2, 72.0), "radio": 8.5, "frenar": true, "hold": 0.6, "titulo": "ALINEACION PARA REVERSA", "msg": "PASO 10/11: DETENTE FRENTE A LA BAHIA PARA INICIAR LA MANIOBRA EN REVERSA"},
				{"pos": Vector3(-24.0, 0.2, 50.0), "radio": 7.5, "reversa": true, "frenar": true, "hold": 1.2, "titulo": "ESTACIONAMIENTO EN REVERSA", "msg": "PASO 11/11: PON REVERSA (R) Y RETROCEDE A LA BAHIA SIN TOCAR CONOS"},
			]
		"C2":
			# C2: Examen completo de camión rígido (11 pruebas con reversa)
			_tiempo_restante = 300.0
			_max_conos = 3
			_checkpoints = [
				{"pos": Vector3(0.0, 0.2, 34.0), "radio": 8.5, "titulo": "SALIDA CAMION RIGIDO", "msg": "PRUEBA 1/11: CRUZA EL ARCO DE SALIDA CON EL CAMION NPR"},
				{"pos": Vector3(0.0, 0.2, 0.0), "radio": 8.0, "max_kmh": 35.0, "titulo": "ESLALON INTERMEDIO", "msg": "PRUEBA 2/11: ESLALON RIGIDO (MAX 35 KM/H) - CUIDA EL RADIO DE GIRO"},
				{"pos": Vector3(0.0, 0.2, -28.0), "radio": 8.5, "max_kmh": 35.0, "titulo": "SALIDA DE ESLALON", "msg": "PRUEBA 3/11: TERMINA EL ESLALON (MAX 3 CONOS DERRIBADOS)"},
				{"pos": Vector3(14.0, 0.2, -68.0), "radio": 9.0, "frenar": true, "hold": 0.9, "titulo": "FRENADO DE CARGA", "msg": "PRUEBA 4/11: FRENADO CONTROLADO ANTES DE LA CHICANA"},
				{"pos": Vector3(52.0, 0.7, -78.0), "radio": 9.0, "max_kmh": 38.0, "titulo": "CHICANA DE CONCRETO", "msg": "PRUEBA 5/11: SUPERA LA CHICANA A MENOS DE 38 KM/H"},
				{"pos": Vector3(86.0, 2.6, -54.0), "radio": 9.0, "frenar": true, "hold": 1.0, "titulo": "PARADA EN PENDIENTE", "msg": "PRUEBA 6/11: DETENTE EN LA SUBIDA Y ARRANCA EN PRIMERA"},
				{"pos": Vector3(94.0, 6.4, -12.0), "radio": 9.5, "min_kmh": 18.0, "titulo": "ASCENSO ANDINO", "msg": "PRUEBA 7/11: CORONA LA CIMA MANTENIENDO AL MENOS 18 KM/H"},
				{"pos": Vector3(72.0, 3.0, 64.0), "radio": 9.5, "max_kmh": 35.0, "titulo": "DESCENSO FRENO MOTOR", "msg": "PRUEBA 8/11: BAJADA EN CURVA CON FRENO DE MOTOR (MAX 35 KM/H)"},
				{"pos": Vector3(36.0, 0.2, 80.0), "radio": 9.0, "max_kmh": 22.0, "titulo": "RESALTOS CON CARGA", "msg": "PRUEBA 9/11: CRUZA LOS RESALTOS A MENOS DE 22 KM/H"},
				{"pos": Vector3(-24.0, 0.2, 72.0), "radio": 9.0, "frenar": true, "hold": 0.7, "titulo": "ALINEACION PARA REVERSA", "msg": "PRUEBA 10/11: DETENTE FRENTE A LA BAHIA PARA RETROCEDER CON ESPEJOS"},
				{"pos": Vector3(-24.0, 0.2, 50.0), "radio": 8.0, "reversa": true, "frenar": true, "hold": 1.3, "titulo": "REVERSA EN BAHIA", "msg": "PRUEBA 11/11: PON REVERSA (R), USA LOS ESPEJOS Y ESTACIONA EN LA BAHIA"},
			]
		_: # C3
			# C3: Examen profesional de tractomula pesada (11 pruebas con reversa)
			_tiempo_restante = 350.0
			_max_conos = 2
			_checkpoints = [
				{"pos": Vector3(0.0, 0.2, 34.0), "radio": 9.5, "titulo": "SALIDA TRACTOMULA C3", "msg": "PRUEBA 1/11: ARCO DE SALIDA CON TRACTOMULA ARTICULADA (MAX 2 CONOS)"},
				{"pos": Vector3(0.0, 0.2, 0.0), "radio": 9.5, "max_kmh": 30.0, "titulo": "ESLALON ARTICULADO", "msg": "PRUEBA 2/11: TRAZA AMPLIO (MAX 30 KM/H) VIGILANDO EL TRAILER"},
				{"pos": Vector3(0.0, 0.2, -28.0), "radio": 9.5, "max_kmh": 30.0, "titulo": "SALIDA DE ESLALON C3", "msg": "PRUEBA 3/11: COMPLETA EL ESLALON SIN TOCAR CONOS"},
				{"pos": Vector3(14.0, 0.2, -68.0), "radio": 10.0, "frenar": true, "hold": 1.0, "titulo": "FRENADO DE CONVOY", "msg": "PRUEBA 4/11: DETENCION TOTAL CONTROLADA DEL CONVOY"},
				{"pos": Vector3(52.0, 0.7, -78.0), "radio": 10.0, "max_kmh": 32.0, "titulo": "CHICANA PESADA", "msg": "PRUEBA 5/11: ABRE EL GIRO EN LA CHICANA (MAX 32 KM/H)"},
				{"pos": Vector3(86.0, 2.6, -54.0), "radio": 10.0, "frenar": true, "hold": 1.0, "titulo": "ARRANQUE PESADO", "msg": "PRUEBA 6/11: DETENTE EN PENDIENTE Y SUBE CON MARCHAS CORTAS"},
				{"pos": Vector3(94.0, 6.4, -12.0), "radio": 10.5, "min_kmh": 15.0, "titulo": "CRESTA ANDINA C3", "msg": "PRUEBA 7/11: SUBE LA COLINA SOSTENIENDO AL MENOS 15 KM/H"},
				{"pos": Vector3(72.0, 3.0, 64.0), "radio": 10.5, "max_kmh": 30.0, "titulo": "BAJADA FRENO MOTOR", "msg": "PRUEBA 8/11: BAJADA PESADA OBLIGATORIA A MAX 30 KM/H"},
				{"pos": Vector3(36.0, 0.2, 80.0), "radio": 10.0, "max_kmh": 20.0, "titulo": "RESALTOS DE SUSPENSION", "msg": "PRUEBA 9/11: CRUZA LOS RESALTOS A MENOS DE 20 KM/H"},
				{"pos": Vector3(-24.0, 0.2, 72.0), "radio": 10.0, "frenar": true, "hold": 0.8, "titulo": "ALINEACION DE CONVOY", "msg": "PRUEBA 10/11: DETENTE ALINEADO FRENTE A LA BAHIA PARA DAR REVERSA"},
				{"pos": Vector3(-24.0, 0.2, 50.0), "radio": 9.5, "reversa": true, "frenar": true, "hold": 1.5, "titulo": "ESTACIONAMIENTO EN REVERSA C3", "msg": "PRUEBA 11/11: PON REVERSA (R) Y METE EL CONVOY EN LA BAHIA"},
			]


func _spawnear_conos_fisicos() -> void:
	if not ResourceLoader.exists(RUTA_CONO):
		return
	var cono_ps := load(RUTA_CONO) as PackedScene
	if not cono_ps:
		return

	var conos_root := Node3D.new()
	conos_root.name = "ConosFisicos"
	add_child(conos_root)

	var puntos_conos: Array[Vector3] = []
	# Eslalon en recta principal (espaciado según tamaño de vehículo)
	var paso_z := 11.0 if categoria == "C1" else (14.5 if categoria == "C2" else 19.0)
	var offset_x := 2.4 if categoria == "C1" else (3.2 if categoria == "C2" else 4.0)
	var z_cur := 16.0
	var lado := 1.0
	while z_cur >= -26.0:
		puntos_conos.append(Vector3(lado * offset_x, 0.06, z_cur))
		lado *= -1.0
		z_cur -= paso_z

	# Conos delimitando la bahía de estacionamiento final
	for pz in [42.0, 48.0, 54.0, 60.0]:
		puntos_conos.append(Vector3(-31.0, 0.06, pz))
		puntos_conos.append(Vector3(-17.0, 0.06, pz))

	for i in range(puntos_conos.size()):
		var rb := RigidBody3D.new()
		rb.name = "Cono_%d" % i
		rb.mass = 2.5
		rb.position = puntos_conos[i]

		var col := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.20
		sh.height = 0.72
		col.shape = sh
		col.position = Vector3(0, 0.36, 0)
		rb.add_child(col)

		var vis := cono_ps.instantiate() as Node3D
		if vis:
			rb.add_child(vis)

		conos_root.add_child(rb)
		_conos_data.append({
			"body": rb,
			"origen": puntos_conos[i],
			"derribado": false
		})


func _spawnear_vehiculo_y_jugador() -> void:
	var ruta_veh := RUTA_VEH_C1
	if categoria == "C2":
		ruta_veh = RUTA_VEH_C2
	elif categoria == "C3":
		ruta_veh = RUTA_VEH_C3

	if ResourceLoader.exists(ruta_veh):
		var ps := load(ruta_veh) as PackedScene
		if ps:
			_vehiculo = ps.instantiate() as Node3D
			_vehiculo.name = "VehiculoExamen"
			var spawn_y := 0.02 if categoria == "C2" else 0.35
			_vehiculo.position = Vector3(0.0, spawn_y, 50.0)
			add_child(_vehiculo)

	if categoria == "C3" and ResourceLoader.exists(RUTA_TRAILER_C3):
		var ps_tr := load(RUTA_TRAILER_C3) as PackedScene
		if ps_tr:
			_trailer = ps_tr.instantiate() as Node3D
			_trailer.name = "TrailerExamen"
			_trailer.position = Vector3(0.0, 0.35, 58.2)
			add_child(_trailer)

	_jugador = get_node_or_null("Jugador") as Node3D
	if _jugador:
		_jugador.set_meta("en_modo_prueba", true)
		_jugador.position = Vector3(-2.6, 0.4, 47.2) if categoria == "C2" else Vector3(-3.6, 0.4, 49.0)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. CHECKPOINTS 3D, DETECCIÓN, SONIDOS Y HUD GLASSMORPHISM
# ═══════════════════════════════════════════════════════════════════════════════

func _crear_beacon_checkpoint() -> void:
	_cp_beacon = Node3D.new()
	_cp_beacon.name = "CheckpointBeacon"
	add_child(_cp_beacon)

	_cp_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.7
	torus.outer_radius = 3.25
	_cp_ring.mesh = torus
	_cp_ring.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.72, 0.20, 0.88)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.72, 0.20)
	mat.emission_energy_multiplier = 3.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cp_ring.material_override = mat
	_cp_beacon.add_child(_cp_ring)

	_cp_ring_inner = MeshInstance3D.new()
	var torus2 := TorusMesh.new()
	torus2.inner_radius = 1.9
	torus2.outer_radius = 2.25
	_cp_ring_inner.mesh = torus2
	_cp_ring_inner.rotation_degrees.x = 90.0
	_cp_ring_inner.material_override = mat.duplicate()
	_cp_beacon.add_child(_cp_ring_inner)

	_cp_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.8
	cyl.height = 7.5
	_cp_beam.mesh = cyl
	_cp_beam.position = Vector3(0, 3.75, 0)
	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.95, 0.72, 0.20, 0.075)
	mat_b.emission_enabled = true
	mat_b.emission = Color(0.95, 0.72, 0.20)
	mat_b.emission_energy_multiplier = 1.4
	mat_b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_b.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cp_beam.material_override = mat_b
	_cp_beacon.add_child(_cp_beam)

	# Sin Label3D flotante sobre el checkpoint: la información limpia está en el HUD superior.
	_cp_label3d = null

	# Previsualización sutil del siguiente checkpoint (anticipa curvas)
	_cp_next_beacon = Node3D.new()
	_cp_next_beacon.name = "NextCheckpointPreview"
	var next_ring := MeshInstance3D.new()
	var nt := TorusMesh.new()
	nt.inner_radius = 1.8
	nt.outer_radius = 2.1
	next_ring.mesh = nt
	next_ring.rotation_degrees.x = 90.0
	next_ring.position.y = 1.0
	var mat_n := StandardMaterial3D.new()
	mat_n.albedo_color = Color(0.75, 0.82, 0.90, 0.35)
	mat_n.emission_enabled = true
	mat_n.emission = Color(0.75, 0.82, 0.90)
	mat_n.emission_energy_multiplier = 1.4
	mat_n.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	next_ring.material_override = mat_n
	_cp_next_beacon.add_child(next_ring)
	add_child(_cp_next_beacon)

	# Flecha guía 3D flotante sobre el vehículo apuntando al próximo checkpoint
	_flecha_guia = Node3D.new()
	_flecha_guia.name = "FlechaGuia3D"
	var cono_f := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.42
	cm.height = 1.15
	cono_f.mesh = cm
	cono_f.rotation_degrees.x = -90.0
	var mat_f := StandardMaterial3D.new()
	mat_f.albedo_color = Color(0.98, 0.74, 0.20, 0.95)
	mat_f.emission_enabled = true
	mat_f.emission = Color(0.98, 0.74, 0.20)
	mat_f.emission_energy_multiplier = 3.2
	cono_f.material_override = mat_f
	_flecha_guia.add_child(cono_f)
	add_child(_flecha_guia)


func _actualizar_checkpoint_visual() -> void:
	if _cp_idx >= _checkpoints.size() or not _cp_beacon:
		return
	var cp := _checkpoints[_cp_idx]
	_cp_beacon.position = cp["pos"]
	_cp_beacon.visible = true

	# Color según tipo de prueba: Verde = frenar/parqueo, Cian = límite vel., Ámbar = ruta/subida
	var col_cp := Color(0.95, 0.72, 0.20)
	if bool(cp.get("frenar", false)):
		col_cp = Color(0.24, 0.92, 0.52)
	elif float(cp.get("max_kmh", 0.0)) > 0.0:
		col_cp = Color(0.24, 0.78, 1.0)

	for m_node in [_cp_ring, _cp_ring_inner]:
		if m_node and m_node.material_override is StandardMaterial3D:
			var sm := m_node.material_override as StandardMaterial3D
			sm.albedo_color = Color(col_cp.r, col_cp.g, col_cp.b, 0.88)
			sm.emission = col_cp
	if _cp_beam and _cp_beam.material_override is StandardMaterial3D:
		var sb := _cp_beam.material_override as StandardMaterial3D
		sb.albedo_color = Color(col_cp.r, col_cp.g, col_cp.b, 0.075)
		sb.emission = col_cp

	if _cp_label3d:
		var tag := str(cp.get("titulo", "PUNTO %d/%d" % [_cp_idx + 1, _checkpoints.size()]))
		_cp_label3d.text = "%s\n(%d / %d)" % [tag, _cp_idx + 1, _checkpoints.size()]
		_cp_label3d.modulate = col_cp.lightened(0.2)

	if _cp_next_beacon:
		if _cp_idx + 1 < _checkpoints.size():
			_cp_next_beacon.position = _checkpoints[_cp_idx + 1]["pos"]
			_cp_next_beacon.visible = true
		else:
			_cp_next_beacon.visible = false

	if _lbl_instruccion:
		_lbl_instruccion.text = str(cp["msg"])
		_lbl_instruccion.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	if _lbl_progreso:
		_lbl_progreso.text = "CP %d/%d" % [_cp_idx + 1, _checkpoints.size()]


func _verificar_conos_derribados() -> void:
	for c in _conos_data:
		if bool(c["derribado"]):
			continue
		var rb: RigidBody3D = c["body"]
		if not is_instance_valid(rb):
			continue
		var inclinado := rb.global_transform.basis.y.y < 0.65
		var desplazado := rb.global_position.distance_to(c["origen"]) > 0.85
		if inclinado or desplazado:
			c["derribado"] = true
			_conos_derribados += 1
			_reproducir_sfx(SFX_GOLPE, -2.0)


func _verificar_progreso_checkpoint() -> void:
	if _cp_idx >= _checkpoints.size() or not _vehiculo:
		return
	var cp := _checkpoints[_cp_idx]
	var dist := _vehiculo.global_position.distance_to(cp["pos"])
	var radio := float(cp.get("radio", 8.0))
	var vel_kmh := _obtener_velocidad_kmh()

	if dist > radio:
		_tiempo_detenido_cp = 0.0
		_reversa_validada_cp = false
		return

	# Verificar si la prueba requiere entrar en reversa
	if bool(cp.get("reversa", false)):
		var en_rev_input := is_instance_valid(InputVehiculo) and InputVehiculo.esta_en_reversa()
		var vel_fwd := 0.0
		if _vehiculo is RigidBody3D:
			vel_fwd = (-_vehiculo.global_transform.basis.z).dot((_vehiculo as RigidBody3D).linear_velocity)
		if en_rev_input or vel_fwd < -0.35:
			_reversa_validada_cp = true
		if not _reversa_validada_cp:
			if _lbl_instruccion:
				_lbl_instruccion.text = "CAMBIA A REVERSA (R) E INGRESA RETROCEDIENDO A LA BAHIA!"
				_lbl_instruccion.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32))
			return

	# Verificar velocidad mínima (ej. potencia sostenida en subida)
	var min_kmh := float(cp.get("min_kmh", 0.0))
	if min_kmh > 0.0 and vel_kmh < min_kmh:
		if _lbl_instruccion:
			_lbl_instruccion.text = "ACELERA UN POCO MAS (%.0f KM/H) - MINIMO %.0f KM/H EN SUBIDA!" % [vel_kmh, min_kmh]
			_lbl_instruccion.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32))
		return

	# Verificar límite de velocidad del tramo si existe
	var max_kmh := float(cp.get("max_kmh", 0.0))
	if max_kmh > 0.0 and vel_kmh > max_kmh:
		if _lbl_instruccion:
			_lbl_instruccion.text = "DEMASIADO RAPIDO (%.0f KM/H) - REDUCE A MAX %.0f KM/H!" % [vel_kmh, max_kmh]
			_lbl_instruccion.add_theme_color_override("font_color", Color(0.98, 0.36, 0.32))
		return

	# Verificar parada controlada si es prueba de frenado / parqueo / arranque en pendiente
	var requiere_freno := bool(cp.get("frenar", false))
	if requiere_freno:
		var hold_req := float(cp.get("hold", 1.0))
		if vel_kmh > 5.0:
			_tiempo_detenido_cp = 0.0
			if _lbl_instruccion:
				_lbl_instruccion.text = "DETENTE POR COMPLETO EN LA ZONA (%.0f KM/H)" % vel_kmh
				_lbl_instruccion.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32))
			return
		_tiempo_detenido_cp += get_process_delta_time()
		if _tiempo_detenido_cp < hold_req:
			if _lbl_instruccion:
				_lbl_instruccion.text = "MANTEN EL FRENO... %.1fS" % maxf(0.0, hold_req - _tiempo_detenido_cp)
				_lbl_instruccion.add_theme_color_override("font_color", Color(0.32, 0.90, 0.56))
			return

	_tiempo_detenido_cp = 0.0
	_reversa_validada_cp = false
	if _lbl_instruccion:
		_lbl_instruccion.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	_reproducir_sfx(SFX_CHECKPOINT, -2.0)
	var titulo_paso := str(cp.get("titulo", "CHECKPOINT"))
	_mostrar_toast_paso("SUPERADO: " + titulo_paso)
	_cp_idx += 1
	if _cp_idx >= _checkpoints.size():
		_finalizar_examen(true, "LICENCIA %s APROBADA CON EXITO" % categoria)
	else:
		_actualizar_checkpoint_visual()


func _mostrar_toast_paso(texto: String) -> void:
	if not _hud_layer:
		return
	if _toast_paso and is_instance_valid(_toast_paso):
		_toast_paso.queue_free()
	_toast_paso = PanelContainer.new()
	_toast_paso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_paso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_paso.offset_left = -260
	_toast_paso.offset_right = 260
	_toast_paso.offset_top = 122
	_toast_paso.offset_bottom = 166
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.20, 0.12, 0.94)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.28, 0.92, 0.54, 0.95)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_toast_paso.add_theme_stylebox_override("panel", sb)
	_toast_paso_lbl = _crear_lbl(texto, 16, Color(0.45, 0.98, 0.66))
	_toast_paso_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_paso.add_child(_toast_paso_lbl)
	_hud_layer.add_child(_toast_paso)
	_toast_paso.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_toast_paso, "modulate:a", 1.0, 0.18)
	tw.tween_interval(1.6)
	tw.tween_property(_toast_paso, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		if is_instance_valid(_toast_paso):
			_toast_paso.queue_free()
	)


func _obtener_velocidad_kmh() -> float:
	if _vehiculo is RigidBody3D:
		return (_vehiculo as RigidBody3D).linear_velocity.length() * 3.6
	return 0.0


func _actualizar_hud_en_vivo() -> void:
	var mins := int(_tiempo_restante) / 60
	var segs := int(_tiempo_restante) % 60
	if _lbl_tiempo:
		_lbl_tiempo.text = "%02d:%02d" % [mins, segs]
	if _lbl_conos:
		_lbl_conos.text = "CONOS %d/%d" % [_conos_derribados, _max_conos]
		_lbl_conos.add_theme_color_override("font_color", Color(0.95, 0.35, 0.32) if _conos_derribados > 0 else Color(0.32, 0.90, 0.56))
	if _lbl_distancia and _vehiculo and _cp_idx < _checkpoints.size():
		var dist := _vehiculo.global_position.distance_to(_checkpoints[_cp_idx]["pos"])
		_lbl_distancia.text = "%d M" % roundi(dist)


func _reproducir_sfx(ruta: String, vol_db: float = -3.0) -> void:
	if not _sfx_player or not ResourceLoader.exists(ruta):
		return
	_sfx_player.stream = load(ruta)
	_sfx_player.volume_db = vol_db
	_sfx_player.play()


func _finalizar_examen(aprobado: bool, motivo: String) -> void:
	_examen_activo = false
	_examen_terminado = true
	if _cp_beacon:
		_cp_beacon.visible = false

	var xp_premio := 500 if categoria == "C1" else (1000 if categoria == "C2" else 2000)
	if aprobado:
		_reproducir_sfx(SFX_VICTORIA, -1.0)
		if DatosUsuario:
			if categoria == "C1":
				DatosUsuario.licencia_c1 = true
				DatosUsuario.licencia_automovil = true
			elif categoria == "C2":
				DatosUsuario.licencia_c2 = true
				DatosUsuario.licencia_camion = true
			elif categoria == "C3":
				DatosUsuario.licencia_c3 = true
				DatosUsuario.licencia_camion = true
				DatosUsuario.licencia_carga_sobredimensionada = true
			DatosUsuario.licencia_prueba_pendiente = ""
			if DatosUsuario.has_method("agregar_experiencia"):
				DatosUsuario.agregar_experiencia(xp_premio)
			else:
				DatosUsuario.experiencia += xp_premio
			DatosUsuario.save_local()
		var sb := get_node_or_null("/root/SupabaseManager")
		if sb and sb.has_method("esta_autenticado") and sb.esta_autenticado():
			sb.guardar_perfil()
	else:
		_reproducir_sfx(SFX_GOLPE, 0.0)

	_mostrar_modal_resultado(aprobado, motivo, xp_premio)


func _construir_hud_glassmorphism() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDAcademia"
	_hud_layer.layer = 5
	add_child(_hud_layer)

	# Panel compacto en la zona segura SUPERIOR-CENTRO (sin tapar velocímetro, tableta ni controles táctiles)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_left = -430
	top.offset_right = 430
	top.offset_top = 12
	top.offset_bottom = 112
	var sb_top := StyleBoxFlat.new()
	sb_top.bg_color = Color(0.06, 0.07, 0.08, 0.90)
	sb_top.set_border_width_all(1)
	sb_top.border_color = Color(0.78, 0.81, 0.85, 0.26)
	sb_top.set_corner_radius_all(14)
	sb_top.shadow_color = Color(0, 0, 0, 0.45)
	sb_top.shadow_size = 10
	sb_top.content_margin_left = 20
	sb_top.content_margin_right = 20
	sb_top.content_margin_top = 10
	sb_top.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel", sb_top)
	_hud_layer.add_child(top)

	var vbox_top := VBoxContainer.new()
	vbox_top.add_theme_constant_override("separation", 8)
	top.add_child(vbox_top)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_top.add_child(hbox)

	_lbl_licencia = _crear_lbl("LIC. " + categoria, 17, Color(0.95, 0.78, 0.32))
	hbox.add_child(_lbl_licencia)
	_lbl_progreso = _crear_lbl("CP 1 / 7", 16, Color(0.94, 0.96, 0.98))
	hbox.add_child(_lbl_progreso)
	_lbl_tiempo = _crear_lbl("03:00", 16, Color(0.82, 0.86, 0.92))
	hbox.add_child(_lbl_tiempo)
	_lbl_conos = _crear_lbl("CONOS 0/4", 16, Color(0.32, 0.90, 0.56))
	hbox.add_child(_lbl_conos)
	_lbl_distancia = _crear_lbl("0 M", 16, Color(0.95, 0.78, 0.32))
	hbox.add_child(_lbl_distancia)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	var btn_retry := _crear_btn("REINTENTAR", Color(0.10, 0.12, 0.15, 0.92), Color(0.88, 0.68, 0.28, 0.75))
	btn_retry.custom_minimum_size = Vector2(128, 36)
	btn_retry.add_theme_font_size_override("font_size", 13)
	btn_retry.pressed.connect(func(): get_tree().reload_current_scene())
	hbox.add_child(btn_retry)

	var btn_salir := _crear_btn("SALIR", Color(0.24, 0.08, 0.08, 0.94), Color(0.78, 0.28, 0.26, 0.95))
	btn_salir.custom_minimum_size = Vector2(92, 36)
	btn_salir.add_theme_font_size_override("font_size", 13)
	btn_salir.pressed.connect(func():
		if DatosUsuario:
			DatosUsuario.cambiar_escena("res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn")
	)
	hbox.add_child(btn_salir)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.78, 0.81, 0.85, 0.16)
	vbox_top.add_child(sep)

	_lbl_instruccion = _crear_lbl("SUBE AL VEHICULO Y CRUZA EL ARCO DE SALIDA", 16, Color(0.95, 0.96, 0.98))
	_lbl_instruccion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_instruccion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_top.add_child(_lbl_instruccion)


func _mostrar_modal_resultado(aprobado: bool, motivo: String, xp_premio: int) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.04, 0.78)
	_hud_layer.add_child(bg)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(920, 440)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.24, 0.88, 0.52, 0.95) if aprobado else Color(0.82, 0.28, 0.26, 0.95)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	card.add_theme_stylebox_override("panel", sb)
	_hud_layer.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	card.add_child(vb)

	var tit := _crear_lbl("EXAMEN APROBADO" if aprobado else "EXAMEN REPROBADO", 42, Color(0.28, 0.94, 0.56) if aprobado else Color(0.95, 0.36, 0.34))
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tit)

	var sub := _crear_lbl(motivo, 22, Color(0.90, 0.92, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	if aprobado:
		var premio := _crear_lbl("LICENCIA %s DESBLOQUEADA  -  +%d XP" % [categoria, xp_premio], 24, Color(0.95, 0.78, 0.32))
		premio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(premio)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	vb.add_child(hb)

	var b1 := _crear_btn("REINTENTAR", Color(0.10, 0.12, 0.15, 0.95), Color(0.78, 0.81, 0.85, 0.4))
	b1.custom_minimum_size = Vector2(260, 66)
	b1.pressed.connect(func(): get_tree().reload_current_scene())
	hb.add_child(b1)

	var b2 := _crear_btn("VOLVER AL MENU", Color(0.88, 0.68, 0.28, 0.96), Color(1.0, 0.86, 0.45, 1.0))
	b2.custom_minimum_size = Vector2(300, 66)
	b2.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08, 1.0))
	b2.pressed.connect(func():
		if DatosUsuario:
			DatosUsuario.cambiar_escena("res://interfaz/pantallas/menu_principal/MainMenuModerno.tscn")
	)
	hb.add_child(b2)


func _crear_lbl(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


func _crear_btn(txt: String, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(150, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	return b
