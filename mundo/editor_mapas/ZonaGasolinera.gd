class_name ZonaGasolinera
extends Node3D

## Sistema interactivo de bahías de gasolinera procedural.
## Flujo con el jugador:
## 1. Vehículo entra a la zona de estacionamiento de una bahía.
## 2. El jugador detiene el vehículo y apaga el motor.
## 3. El jugador se baja del vehículo.
## 4. El jugador se acerca al surtidor y agarra la pistola/surtidor.
## 5. El jugador se acerca al vehículo y llena el tanque (actualizando displays 3D y combustible).

const PATH_PISTOLA_GLB := "res://modelos3d/mapa/modulares/pistola_gasolina.glb"
const RUTA_FUENTE_MODERNIZ := "res://recursos/fonts/Moderniz.otf"
const PantallaSurtidor2D = preload("res://mundo/editor_mapas/PantallaSurtidor2D.gd")

@export var precio_galon_cop: float = 11200.0
@export var litros_por_galon: float = 3.78541
@export var velocidad_flujo_lps: float = 14.0

var color_primario: Color = Color(0.86, 0.14, 0.14)
var color_secundario: Color = Color(0.95, 0.72, 0.12)

# Lista de diccionarios de surtidores/bahías registrados por ControladorGasolineras:
# {"pos_surtidor": Vector3, "area_vehiculo": Area3D, "area_surtidor": Area3D, "display_total": Label3D, "display_litros": Label3D}
var _surtidores: Array[Dictionary] = []
var _areas_veh_conectadas: Array[Area3D] = []

var _vehiculo_actual: Node3D = null
var _surtidor_activo_idx: int = -1
var _jugador_en_rango_surtidor: bool = false
var _jugador_actual: Node3D = null

var _pistola_agarrada: bool = false
var _repostando: bool = false
var _litros_cargados: float = 0.0
var _costo_cop: float = 0.0

var _nodo_pistola_mano: Node3D = null
var _skel_jugador: Skeleton3D = null
var _mano_bone_idx: int = -1
var _manguera_mesh: MeshInstance3D = null
var _mat_manguera: StandardMaterial3D = null

var _audio_sfx: AudioStreamPlayer = null
var _audio_flujo: AudioStreamPlayer = null
var _wav_agarrar: AudioStreamWAV = null
var _wav_colgar: AudioStreamWAV = null
var _wav_flujo_loop: AudioStreamWAV = null
var _wav_lleno: AudioStreamWAV = null

# HUD Glassmorphic (Píldora superior de estado + botones flotantes inferiores solo a pie)
var _canvas_hud: CanvasLayer = null
var _panel_hud: PanelContainer = null
var _lbl_estado: Label = null
var _barra_tanque: ProgressBar = null
var _hbox_botones: HBoxContainer = null
var _btn_accion: Button = null
var _btn_colgar: Button = null

func _ready() -> void:
	add_to_group("estaciones_gasolina")
	_mat_manguera = StandardMaterial3D.new()
	_mat_manguera.albedo_color = Color(0.07, 0.07, 0.08)
	_mat_manguera.roughness = 0.72
	_inicializar_audio_procedural()

func registrar_surtidor(pos_surtidor_local: Vector3, area_vehiculo: Area3D, area_surtidor: Area3D, pantalla_2d: PantallaSurtidor2D) -> void:
	var idx := _surtidores.size()
	_surtidores.append({
		"pos_local": pos_surtidor_local,
		"area_vehiculo": area_vehiculo,
		"area_surtidor": area_surtidor,
		"pantalla_2d": pantalla_2d
	})
	if area_vehiculo and not (area_vehiculo in _areas_veh_conectadas):
		_areas_veh_conectadas.append(area_vehiculo)
		area_vehiculo.body_entered.connect(_on_vehiculo_entered.bind(idx))
		area_vehiculo.body_exited.connect(_on_vehiculo_exited.bind(idx))
	if area_surtidor:
		var cb_se := _on_jugador_surtidor_entered.bind(idx)
		if not area_surtidor.body_entered.is_connected(cb_se):
			area_surtidor.body_entered.connect(cb_se)
		var cb_sx := _on_jugador_surtidor_exited.bind(idx)
		if not area_surtidor.body_exited.is_connected(cb_sx):
			area_surtidor.body_exited.connect(cb_sx)

func _exit_tree() -> void:
	_soltar_pistola(true)
	if is_instance_valid(_canvas_hud):
		_canvas_hud.queue_free()

func _process(delta: float) -> void:
	if not is_instance_valid(_vehiculo_actual) and not _pistola_agarrada:
		if is_instance_valid(_panel_hud) and _panel_hud.visible:
			_panel_hud.visible = false
		if is_instance_valid(_hbox_botones) and _hbox_botones.visible:
			_hbox_botones.visible = false
		return

	if not is_instance_valid(_jugador_actual):
		_jugador_actual = _buscar_jugador_en_escena()

	if _repostando:
		_procesar_repostaje(delta)

	if _pistola_agarrada:
		_actualizar_posicion_pistola_mano()
		_actualizar_manguera_3d()
		# Si el jugador se aleja demasiado de la estación, colgar automáticamente
		if is_instance_valid(_jugador_actual) and _surtidor_activo_idx >= 0 and _surtidor_activo_idx < _surtidores.size():
			var pos_s: Vector3 = to_global(_surtidores[_surtidor_activo_idx]["pos_local"])
			if _jugador_actual.global_position.distance_to(pos_s) > 14.0:
				_soltar_pistola(false)
				_notificar("Te alejaste demasiado; el surtidor regresó a su soporte.", "info")

	_actualizar_ui_estado()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_panel_hud) or not _panel_hud.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_ejecutar_accion_principal()

func _on_vehiculo_entered(body: Node, idx: int) -> void:
	var veh := _obtener_raiz_vehiculo(body)
	if not veh:
		return
	_vehiculo_actual = veh
	_surtidor_activo_idx = idx
	_asegurar_hud()
	_panel_hud.visible = true

func _on_vehiculo_exited(body: Node, idx: int) -> void:
	var veh := _obtener_raiz_vehiculo(body)
	if veh and veh == _vehiculo_actual and idx == _surtidor_activo_idx:
		if _repostando:
			_detener_repostaje()
		_vehiculo_actual = null
		if not _pistola_agarrada:
			if is_instance_valid(_panel_hud):
				_panel_hud.visible = false
			if is_instance_valid(_hbox_botones):
				_hbox_botones.visible = false

func _on_jugador_surtidor_entered(body: Node, idx: int) -> void:
	if _es_jugador(body):
		_jugador_actual = body as Node3D
		_jugador_en_rango_surtidor = true
		if not _pistola_agarrada:
			_surtidor_activo_idx = idx
		_asegurar_hud()
		_panel_hud.visible = true

func _on_jugador_surtidor_exited(body: Node, idx: int) -> void:
	if _es_jugador(body) and idx == _surtidor_activo_idx:
		_jugador_en_rango_surtidor = false

func _esta_conduciendo() -> bool:
	if has_node("/root/InputVehiculo"):
		var iv := get_node("/root/InputVehiculo")
		if "conduciendo" in iv:
			return bool(iv.get("conduciendo"))
	if is_instance_valid(_vehiculo_actual) and "activo" in _vehiculo_actual:
		return bool(_vehiculo_actual.get("activo"))
	return false

func _motor_esta_encendido() -> bool:
	if has_node("/root/InputVehiculo"):
		var iv := get_node("/root/InputVehiculo")
		if "motor_encendido" in iv:
			return bool(iv.get("motor_encendido"))
	return false

func _apagar_motor_vehiculo() -> void:
	if has_node("/root/InputVehiculo"):
		var iv := get_node("/root/InputVehiculo")
		if "motor_encendido" in iv:
			iv.set("motor_encendido", false)
	if is_instance_valid(_vehiculo_actual):
		var motor := _vehiculo_actual.find_child("Motor", true, false)
		if motor and "encendido" in motor:
			motor.set("encendido", false)
	_notificar("Motor apagado. Ahora bájate del vehículo.", "info")

func _ejecutar_accion_principal() -> void:
	if not is_instance_valid(_vehiculo_actual) and not _pistola_agarrada:
		return

	if _esta_conduciendo():
		return

	if not _pistola_agarrada:
		if _jugador_en_rango_surtidor or _jugador_cerca_surtidor():
			_agarrar_pistola()
		else:
			_notificar("Acércate al surtidor para agarrar la pistola.", "info")
		return

	# Ya tiene la pistola en la mano
	if _repostando:
		_detener_repostaje()
	else:
		if _jugador_cerca_vehiculo():
			_iniciar_repostaje()
		else:
			_notificar("Acércate al vehículo estacionado para llenar el tanque.", "info")

func _agarrar_pistola() -> void:
	if _pistola_agarrada:
		return
	if not is_instance_valid(_jugador_actual):
		_jugador_actual = _buscar_jugador_en_escena()
	if not is_instance_valid(_jugador_actual):
		return

	_pistola_agarrada = true
	_litros_cargados = 0.0
	_costo_cop = 0.0
	_jugador_actual.set_meta("llevando_pistola_gasolina", true)

	_skel_jugador = _jugador_actual.find_child("Skeleton3D", true, false) as Skeleton3D
	_mano_bone_idx = -1
	if _skel_jugador:
		for bname: String in ["mixamorig_RightHand", "mixamorig:RightHand", "RightHand"]:
			var bi := _skel_jugador.find_bone(bname)
			if bi != -1:
				_mano_bone_idx = bi
				break

	if ResourceLoader.exists(PATH_PISTOLA_GLB):
		var escena := load(PATH_PISTOLA_GLB) as PackedScene
		if escena:
			_nodo_pistola_mano = escena.instantiate() as Node3D
			_nodo_pistola_mano.name = "PistolaGasolinaEnMano"
			_colorear_pistola(_nodo_pistola_mano)
			for ch in _nodo_pistola_mano.find_children("*", "VisualInstance3D", true, false):
				(ch as VisualInstance3D).layers = 1
			add_child(_nodo_pistola_mano)
			_actualizar_posicion_pistola_mano()

	if not is_instance_valid(_manguera_mesh):
		_manguera_mesh = MeshInstance3D.new()
		_manguera_mesh.name = "MangueraDinamica"
		_manguera_mesh.material_override = _mat_manguera
		add_child(_manguera_mesh)

	_reproducir_sfx(_wav_agarrar)
	_notificar("Surtidor agarrado. Acércate al vehículo y llena el tanque.", "exito")

func _actualizar_posicion_pistola_mano() -> void:
	if not is_instance_valid(_nodo_pistola_mano) or not is_instance_valid(_jugador_actual):
		return
	var cam := get_viewport().get_camera_3d()
	var en_1p := false
	if "_primera_persona" in _jugador_actual and bool(_jugador_actual.get("_primera_persona")):
		en_1p = true
	elif is_instance_valid(cam) and "_camara_1p" in _jugador_actual and cam == _jugador_actual.get("_camara_1p"):
		en_1p = true

	if en_1p and is_instance_valid(cam):
		# Viewmodel en primera persona: pistola visible en la esquina inferior derecha de la pantalla
		var vib := Vector3.ZERO
		if _repostando:
			var t := float(Time.get_ticks_msec()) * 0.04
			vib = Vector3(sin(t) * 0.003, cos(t * 1.3) * 0.003, 0.0)
		var b_cam := cam.global_transform.basis.orthonormalized()
		var rot_vm := b_cam * Basis.from_euler(Vector3(deg_to_rad(-8.0), deg_to_rad(12.0), deg_to_rad(5.0)))
		var pos_vm := cam.global_transform.origin + b_cam * (Vector3(0.24, -0.19, -0.44) + vib)
		_nodo_pistola_mano.global_transform = Transform3D(rot_vm.scaled(Vector3(1.65, 1.65, 1.65)), pos_vm)
		return

	var xf_mano: Transform3D
	if is_instance_valid(_skel_jugador) and _mano_bone_idx >= 0:
		var bone_g := _skel_jugador.global_transform * _skel_jugador.get_bone_global_pose(_mano_bone_idx)
		var basis_rot := bone_g.basis.orthonormalized()
		var offset_local := basis_rot * Vector3(0.02, 0.09, 0.05)
		var rot_pistola := basis_rot * Basis.from_euler(Vector3(deg_to_rad(82.0), 0.0, deg_to_rad(90.0)))
		xf_mano = Transform3D(rot_pistola.scaled(Vector3(1.5, 1.5, 1.5)), bone_g.origin + offset_local)
	else:
		var jb := _jugador_actual.global_transform.basis.orthonormalized()
		var pos_fb := _jugador_actual.global_position + jb * Vector3(0.32, 1.05, -0.32)
		xf_mano = Transform3D(jb.scaled(Vector3(1.5, 1.5, 1.5)), pos_fb)
	_nodo_pistola_mano.global_transform = xf_mano

func _soltar_pistola(silencioso: bool = false) -> void:
	if _repostando:
		_detener_repostaje()
	_pistola_agarrada = false
	if is_instance_valid(_jugador_actual):
		_jugador_actual.set_meta("llevando_pistola_gasolina", false)
	_skel_jugador = null
	_mano_bone_idx = -1
	if is_instance_valid(_nodo_pistola_mano):
		_nodo_pistola_mano.queue_free()
		_nodo_pistola_mano = null
	if is_instance_valid(_manguera_mesh):
		_manguera_mesh.queue_free()
		_manguera_mesh = null
	if not silencioso:
		_reproducir_sfx(_wav_colgar)
		_notificar("Surtidor colgado en su soporte.", "info")

func _iniciar_repostaje() -> void:
	if not is_instance_valid(_vehiculo_actual) or _repostando:
		return
	if _obtener_porcentaje_tanque() >= 0.995:
		_notificar("El tanque del vehículo ya está lleno.", "info")
		return
	_repostando = true
	if is_instance_valid(_audio_flujo) and _wav_flujo_loop:
		_audio_flujo.stream = _wav_flujo_loop
		_audio_flujo.play()
	_notificar("Llenando tanque de combustible...", "info")

func _detener_repostaje() -> void:
	if not _repostando:
		return
	_repostando = false
	if is_instance_valid(_audio_flujo) and _audio_flujo.playing:
		_audio_flujo.stop()
	_reproducir_sfx(_wav_colgar)
	_actualizar_displays_3d()
	var datos := get_node_or_null("/root/DatosUsuario")
	if datos and datos.has_method("save_local"):
		datos.save_local()
	_notificar("Tanqueo pausado: %.1f L ($%s COP)" % [_litros_cargados, _formatear_pesos(_costo_cop)], "exito")

func _procesar_repostaje(delta: float) -> void:
	if not is_instance_valid(_vehiculo_actual):
		_detener_repostaje()
		return
	var litros_frame := velocidad_flujo_lps * delta
	var costo_litro := precio_galon_cop / litros_por_galon
	var costo_frame := litros_frame * costo_litro

	var datos := get_node_or_null("/root/DatosUsuario")
	if datos and "dinero" in datos:
		if float(datos.get("dinero")) >= costo_frame:
			datos.set("dinero", float(datos.get("dinero")) - costo_frame)

	_litros_cargados += litros_frame
	_costo_cop += costo_frame

	var pct := _aplicar_combustible_vehiculo(litros_frame)
	_actualizar_displays_3d()

	if pct >= 0.995:
		_repostando = false
		if is_instance_valid(_audio_flujo) and _audio_flujo.playing:
			_audio_flujo.stop()
		_reproducir_sfx(_wav_lleno)
		_actualizar_displays_3d()
		_notificar("¡Tanque lleno al 100%! Cuelga el surtidor y vuelve al vehículo.", "exito")

func _aplicar_combustible_vehiculo(litros_frame: float) -> float:
	var pct: float = 1.0
	if has_node("/root/InputVehiculo"):
		var iv := get_node("/root/InputVehiculo")
		if "combustible" in iv:
			var act := float(iv.get("combustible"))
			if act <= 1.05:
				act = minf(act + litros_frame / 420.0, 1.0)
				pct = act
			else:
				act = minf(act + (litros_frame / 420.0) * 100.0, 100.0)
				pct = act / 100.0
			iv.set("combustible", act)

	if is_instance_valid(_vehiculo_actual):
		var motor := _vehiculo_actual.find_child("Motor", true, false)
		if motor and "nivel_combustible_l" in motor and "capacidad_combustible_l" in motor:
			var cap_l := maxf(1.0, float(motor.get("capacidad_combustible_l")))
			var act_l := minf(float(motor.get("nivel_combustible_l")) + litros_frame, cap_l)
			motor.set("nivel_combustible_l", act_l)
			pct = act_l / cap_l
		var comp_comb := _vehiculo_actual.find_child("Combustible", true, false)
		if comp_comb and comp_comb.has_method("recargar_cantidad"):
			comp_comb.recargar_cantidad(litros_frame)
			if "combustible_actual" in comp_comb and "combustible_max" in comp_comb:
				pct = float(comp_comb.get("combustible_actual")) / maxf(1.0, float(comp_comb.get("combustible_max")))
	return clampf(pct, 0.0, 1.0)

func _obtener_porcentaje_tanque() -> float:
	if is_instance_valid(_vehiculo_actual):
		var motor := _vehiculo_actual.find_child("Motor", true, false)
		if motor and "nivel_combustible_l" in motor and "capacidad_combustible_l" in motor:
			return clampf(float(motor.get("nivel_combustible_l")) / maxf(1.0, float(motor.get("capacidad_combustible_l"))), 0.0, 1.0)
	if has_node("/root/InputVehiculo"):
		var iv := get_node("/root/InputVehiculo")
		if "combustible" in iv:
			var act := float(iv.get("combustible"))
			return clampf(act if act <= 1.05 else act / 100.0, 0.0, 1.0)
	return 0.5

func _actualizar_displays_3d() -> void:
	if _surtidor_activo_idx < 0 or _surtidor_activo_idx >= _surtidores.size():
		return
	var d: Dictionary = _surtidores[_surtidor_activo_idx]
	var p2d := d.get("pantalla_2d") as PantallaSurtidor2D
	if is_instance_valid(p2d):
		p2d.actualizar_lectura(_costo_cop, _litros_cargados, precio_galon_cop, litros_por_galon, _repostando)

func _actualizar_manguera_3d() -> void:
	if not is_instance_valid(_manguera_mesh) or _surtidor_activo_idx < 0 or _surtidor_activo_idx >= _surtidores.size():
		return
	var origen := to_local(to_global(_surtidores[_surtidor_activo_idx]["pos_local"]) + Vector3(0.0, 1.85, 0.0))
	var destino := origen + Vector3(0.5, -0.5, 0.0)
	if is_instance_valid(_nodo_pistola_mano):
		destino = to_local(_nodo_pistola_mano.global_position)
	elif is_instance_valid(_jugador_actual):
		destino = to_local(_jugador_actual.global_position + Vector3(0.0, 1.1, 0.0))

	var mid := (origen + destino) * 0.5 - Vector3(0.0, 0.45, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pasos := 10
	var prev := origen
	for i in range(1, pasos + 1):
		var t := float(i) / float(pasos)
		var u := 1.0 - t
		var pt := u * u * origen + 2.0 * u * t * mid + t * t * destino
		_agregar_tubo_segmento(st, prev, pt, 0.022)
		prev = pt
	st.generate_normals()
	_manguera_mesh.mesh = st.commit()

func _agregar_tubo_segmento(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var dir := b - a
	if dir.length_squared() < 0.0001:
		return
	var fwd := dir.normalized()
	var up := Vector3.UP if absf(fwd.y) < 0.9 else Vector3.RIGHT
	var side := fwd.cross(up).normalized() * r
	var up_n := side.cross(fwd).normalized() * r
	var offs := [side, up_n, -side, -up_n]
	for i in range(4):
		var j := (i + 1) % 4
		var a0: Vector3 = a + offs[i]
		var a1: Vector3 = a + offs[j]
		var b0: Vector3 = b + offs[i]
		var b1: Vector3 = b + offs[j]
		st.add_vertex(a0); st.add_vertex(a1); st.add_vertex(b1)
		st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(b0)

func _colorear_pistola(nodo: Node3D) -> void:
	for ch in nodo.find_children("*", "MeshInstance3D", true, false):
		var mi := ch as MeshInstance3D
		if not mi or not mi.mesh:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat := mi.mesh.surface_get_material(s)
			if mat and mat.resource_name == "Mat_Primario":
				var dup := mat.duplicate() as StandardMaterial3D
				if dup:
					dup.albedo_color = color_primario
					mi.set_surface_override_material(s, dup)

func _jugador_cerca_surtidor() -> bool:
	if not is_instance_valid(_jugador_actual) or _surtidor_activo_idx < 0 or _surtidor_activo_idx >= _surtidores.size():
		return false
	var pos_s := to_global(_surtidores[_surtidor_activo_idx]["pos_local"])
	return _jugador_actual.global_position.distance_to(pos_s) <= 3.6

func _jugador_cerca_vehiculo() -> bool:
	if not is_instance_valid(_jugador_actual) or not is_instance_valid(_vehiculo_actual):
		return false
	return _jugador_actual.global_position.distance_to(_vehiculo_actual.global_position) <= 5.5

func _actualizar_ui_estado() -> void:
	if not is_instance_valid(_panel_hud) or not _panel_hud.visible:
		return
	var pct := _obtener_porcentaje_tanque()
	_barra_tanque.value = pct * 100.0
	_barra_tanque.visible = _pistola_agarrada
	_btn_colgar.visible = _pistola_agarrada

	if _esta_conduciendo():
		var vel_len := 0.0
		if is_instance_valid(_vehiculo_actual) and "linear_velocity" in _vehiculo_actual:
			vel_len = (_vehiculo_actual.get("linear_velocity") as Vector3).length()
		if vel_len > 0.5:
			_lbl_estado.text = "⛽ DETÉN EL VEHÍCULO"
		elif _motor_esta_encendido():
			_lbl_estado.text = "⏻ APAGA EL MOTOR"
		else:
			_lbl_estado.text = "🚪 BÁJATE DEL VEHÍCULO"
		_btn_accion.visible = false
	elif not _pistola_agarrada:
		if _jugador_en_rango_surtidor or _jugador_cerca_surtidor():
			_lbl_estado.text = "⛽ TOMA EL SURTIDOR"
			_btn_accion.visible = true
			_btn_accion.text = "⛽ AGARRAR SURTIDOR"
		else:
			_lbl_estado.text = "🚶 ACÉRCATE AL SURTIDOR"
			_btn_accion.visible = false
	else:
		if _repostando:
			_lbl_estado.text = "⛽ TANQUEANDO • %.0f%% • $%s" % [pct * 100.0, _formatear_pesos(_costo_cop)]
			_btn_accion.visible = true
			_btn_accion.text = "⏸ DETENER"
		elif pct >= 0.995:
			_lbl_estado.text = "✓ TANQUE LLENO (100%)"
			_btn_accion.visible = false
		elif _jugador_cerca_vehiculo():
			_lbl_estado.text = "⛽ LISTO • %.0f%%" % (pct * 100.0)
			_btn_accion.visible = true
			_btn_accion.text = "⛽ LLENAR TANQUE"
		else:
			_lbl_estado.text = "🚶 ACÉRCATE AL VEHÍCULO"
			_btn_accion.visible = false

	_hbox_botones.visible = _btn_accion.visible or _btn_colgar.visible

func _asegurar_hud() -> void:
	if is_instance_valid(_canvas_hud):
		return
	_canvas_hud = CanvasLayer.new()
	_canvas_hud.name = "UIGasolinera"
	_canvas_hud.layer = 16
	add_child(_canvas_hud)

	var fuente: Font = load(RUTA_FUENTE_MODERNIZ) if ResourceLoader.exists(RUTA_FUENTE_MODERNIZ) else null

	# 1. Píldora compacta superior (estilo Automotive Glassmorphism)
	_panel_hud = PanelContainer.new()
	_panel_hud.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel_hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_hud.offset_top = 102
	_panel_hud.offset_left = -220
	_panel_hud.offset_right = 220
	_panel_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.08, 0.88)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.78, 0.81, 0.85, 0.24)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 22; sb.content_margin_right = 22; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	sb.shadow_size = 5
	sb.shadow_color = Color(0, 0, 0, 0.45)
	_panel_hud.add_theme_stylebox_override("panel", sb)
	_canvas_hud.add_child(_panel_hud)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_hud.add_child(vbox)

	_lbl_estado = Label.new()
	_lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_estado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_estado.add_theme_font_size_override("font_size", 24)
	_lbl_estado.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.96))
	if fuente:
		_lbl_estado.add_theme_font_override("font", fuente)
	_lbl_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_lbl_estado)

	_barra_tanque = ProgressBar.new()
	_barra_tanque.custom_minimum_size = Vector2(360, 12)
	_barra_tanque.max_value = 100.0
	_barra_tanque.show_percentage = false
	_barra_tanque.visible = false
	var sb_bg_bar := StyleBoxFlat.new()
	sb_bg_bar.bg_color = Color(0.12, 0.14, 0.16, 0.90)
	sb_bg_bar.set_corner_radius_all(6)
	_barra_tanque.add_theme_stylebox_override("background", sb_bg_bar)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.88, 0.68, 0.28, 0.95)
	sb_fill.set_corner_radius_all(6)
	_barra_tanque.add_theme_stylebox_override("fill", sb_fill)
	vbox.add_child(_barra_tanque)

	# 2. Botones táctiles flotantes inferiores (solo visibles cuando el jugador está a pie)
	_hbox_botones = HBoxContainer.new()
	_hbox_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox_botones.add_theme_constant_override("separation", 14)
	_hbox_botones.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hbox_botones.offset_left = -280
	_hbox_botones.offset_right = 280
	_hbox_botones.offset_top = -126
	_hbox_botones.offset_bottom = -56
	_hbox_botones.visible = false
	_hbox_botones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_hud.add_child(_hbox_botones)

	_btn_accion = Button.new()
	_btn_accion.custom_minimum_size = Vector2(300, 68)
	_btn_accion.add_theme_font_size_override("font_size", 23)
	if fuente:
		_btn_accion.add_theme_font_override("font", fuente)
	var st_btn := StyleBoxFlat.new()
	st_btn.bg_color = Color(0.08, 0.09, 0.11, 0.88)
	st_btn.border_width_left = 2; st_btn.border_width_top = 2; st_btn.border_width_right = 2; st_btn.border_width_bottom = 2
	st_btn.border_color = Color(0.88, 0.68, 0.28, 0.92)
	st_btn.set_corner_radius_all(12)
	st_btn.shadow_size = 5
	st_btn.shadow_color = Color(0, 0, 0, 0.45)
	_btn_accion.add_theme_stylebox_override("normal", st_btn)
	_btn_accion.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.98))
	_btn_accion.pressed.connect(_ejecutar_accion_principal)
	_hbox_botones.add_child(_btn_accion)

	_btn_colgar = Button.new()
	_btn_colgar.text = "↩ COLGAR"
	_btn_colgar.custom_minimum_size = Vector2(180, 68)
	_btn_colgar.add_theme_font_size_override("font_size", 21)
	if fuente:
		_btn_colgar.add_theme_font_override("font", fuente)
	var st_col := StyleBoxFlat.new()
	st_col.bg_color = Color(0.78, 0.28, 0.26, 0.92)
	st_col.border_width_left = 1; st_col.border_width_top = 1; st_col.border_width_right = 1; st_col.border_width_bottom = 1
	st_col.border_color = Color(1.0, 0.55, 0.55, 0.45)
	st_col.set_corner_radius_all(12)
	st_col.shadow_size = 5
	st_col.shadow_color = Color(0, 0, 0, 0.45)
	_btn_colgar.add_theme_stylebox_override("normal", st_col)
	_btn_colgar.add_theme_color_override("font_color", Color.WHITE)
	_btn_colgar.pressed.connect(func(): _soltar_pistola(false))
	_hbox_botones.add_child(_btn_colgar)

func _obtener_raiz_vehiculo(node: Node) -> Node3D:
	var curr: Node = node
	while curr and curr != get_tree().current_scene:
		if curr.is_in_group("vehiculo") or curr.has_method("subir_jugador"):
			return curr as Node3D
		curr = curr.get_parent()
	return null

func _es_jugador(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	return node.is_in_group("jugador") or node.name.begins_with("Jugador") or node.has_method("_subir_al_vehiculo") or node.has_method("entrar_al_vehiculo")

func _buscar_jugador_en_escena() -> Node3D:
	var jugadores := get_tree().get_nodes_in_group("jugador")
	if not jugadores.is_empty() and jugadores[0] is Node3D:
		return jugadores[0] as Node3D
	var root := get_tree().current_scene
	if root:
		var j := root.find_child("JugadorPrueba", true, false)
		if j is Node3D:
			return j as Node3D
	return null

func _formatear_pesos(monto: float) -> String:
	var entero := int(monto)
	var str_val := str(entero)
	var res := ""
	var contador := 0
	for i in range(str_val.length() - 1, -1, -1):
		res = str_val[i] + res
		contador += 1
		if contador == 3 and i > 0:
			res = "." + res
			contador = 0
	return res

func _notificar(msg: String, tipo: String = "info") -> void:
	if has_node("/root/NotificationManager"):
		var nm := get_node("/root/NotificationManager")
		if tipo == "exito" and nm.has_method("notificar_exito"):
			nm.call("notificar_exito", msg)
			return
		elif tipo == "alerta" and nm.has_method("notificar_error"):
			nm.call("notificar_error", msg)
			return
	print("[Gasolinera] ", msg)

func _inicializar_audio_procedural() -> void:
	_audio_sfx = AudioStreamPlayer.new()
	_audio_sfx.volume_db = -4.0
	add_child(_audio_sfx)

	_audio_flujo = AudioStreamPlayer.new()
	_audio_flujo.volume_db = -6.0
	add_child(_audio_flujo)

	_wav_agarrar = _generar_wav_click(0.14, 920.0, 420.0)
	_wav_colgar = _generar_wav_click(0.16, 480.0, 210.0)
	_wav_flujo_loop = _generar_wav_flujo_combustible(1.2)
	_wav_lleno = _generar_wav_lleno(0.45)

func _reproducir_sfx(wav: AudioStreamWAV) -> void:
	if is_instance_valid(_audio_sfx) and wav:
		_audio_sfx.stream = wav
		_audio_sfx.play()

func _generar_wav_click(duracion: float, f1: float, f2: float) -> AudioStreamWAV:
	var sr := 22050
	var n := int(duracion * sr)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(sr)
		var env := exp(-t * 28.0)
		var s := (sin(TAU * f1 * t) * 0.55 + sin(TAU * f2 * t) * 0.45 + randf_range(-0.25, 0.25)) * env * 0.7
		data.encode_s16(i * 2, clampi(int(s * 32767.0), -32767, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.data = data
	return wav

func _generar_wav_flujo_combustible(duracion: float) -> AudioStreamWAV:
	var sr := 22050
	var n := int(duracion * sr)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(sr)
		var motor_hum := sin(TAU * 58.0 * t) * 0.22 + sin(TAU * 116.0 * t) * 0.10
		var raw_noise := randf_range(-1.0, 1.0)
		lp = lerpf(lp, raw_noise, 0.22)
		var flujo := (raw_noise - lp) * 0.28 + lp * 0.18
		var s := (motor_hum + flujo) * 0.55
		data.encode_s16(i * 2, clampi(int(s * 32767.0), -32767, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	wav.data = data
	return wav

func _generar_wav_lleno(duracion: float) -> AudioStreamWAV:
	var sr := 22050
	var n := int(duracion * sr)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(sr)
		var clack := (sin(TAU * 380.0 * t) + randf_range(-0.3, 0.3)) * exp(-t * 45.0) * 0.6
		var chime := (sin(TAU * 880.0 * t) * exp(-maxf(0.0, t - 0.05) * 9.0) + sin(TAU * 1320.0 * t) * exp(-maxf(0.0, t - 0.14) * 8.0)) * 0.35
		var s := clack + chime
		data.encode_s16(i * 2, clampi(int(s * 32767.0), -32767, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.data = data
	return wav
