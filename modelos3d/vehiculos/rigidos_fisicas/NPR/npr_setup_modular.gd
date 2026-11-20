extends Node3D

## npr_setup_modular.gd
## Conecta automáticamente la jerarquía de Emptys exportada desde Blender (npr_optimizado.glb)
## con los sistemas de Godot: suspensión a altura real sin elevación exagerada, límite de dirección
## realista, texturizado completo del interior, giro del volante (Empty_Volante), y luces
## delanteras, traseras (stop) y direccionales.

const MAT_CARROCERIA := "res://materiales/Vehiculos/Carroceria.tres"
const MAT_CROMO := "res://materiales/Vehiculos/cromo.tres"
const MAT_CRISTAL := "res://materiales/Cristal.tres"
const MAT_PANORAMICO := "res://materiales/NPR/Cristal1.tres"
const MAT_ESPEJO := "res://materiales/Vehiculos/Colores basicos/espejo.tres"

const TEX_CUERO := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/textures/leather_dark.png"
const TEX_PLASTICO_GRIS := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/textures/a5z71-6txcd.jpg"
const TEX_PLASTICO_NEGRO := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/textures/plastic3 (2).png"
const TEX_INTERIOR_NPR := "res://materiales/NPR/imagenes/interior.png"
const TEX_ASIENTO_NPR := "res://materiales/NPR/imagenes/bancomotora.png"
const TEX_PANEL_ON := "res://materiales/NPR/imagenes/painel_on.png"
const TEX_BOTONES := "res://materiales/NPR/imagenes/botones.png"
const TEX_RADIO := "res://materiales/NPR/imagenes/som.png"
const TEX_CAMBIO := "res://materiales/NPR/imagenes/cambiok124.png"

const SCRIPT_VOLANTE := "res://modelos3d/vehiculos/volantes/volante_visual.gd"
const SCRIPT_PANORAMICO := "res://modelos3d/vehiculos/rigidos_fisicas/NPR/panoramico.gd"

@export var escala_modelo: float = 0.38
@export var offset_anclaje_suspension_y: float = 0.14

var _coche: RigidBody3D = null
var _cam_interna: Camera3D = null
var _luces_delanteras: Node3D = null
var _luz_stop: Node3D = null
var _direccionales: Node3D = null
var _mat_dir_izq: StandardMaterial3D = null
var _mat_dir_der: StandardMaterial3D = null
var _mat_faro_del: StandardMaterial3D = null
var _espejos_viewports: Array[SubViewport] = []
var _espejos_camaras: Array[Camera3D] = []
var _espejos_activos: bool = false


func _ready() -> void:
	_coche = _buscar_vehiculo_raiz()
	if is_instance_valid(_coche):
		_cam_interna = _coche.find_child("Cam_Interna", true, false) as Camera3D
	_aplicar_materiales_y_texturas_interior()
	_conectar_volante_dinamico()
	call_deferred("_conectar_ruedas_a_fisicas")
	call_deferred("_conectar_mallas_luces")
	call_deferred("_configurar_espejos_funcionales")


func _process(_delta: float) -> void:
	if not is_instance_valid(_coche):
		return
	var activo_actual := bool(_coche.get("activo")) if "activo" in _coche else false

	# Actualizar estado de render de espejos (solo activos cuando se conduce en vista interior)
	_actualizar_estado_espejos(activo_actual)

	# Sincronizar estado de conductor con LucesDelanteras, LuzStop y Direccionales
	if is_instance_valid(_luces_delanteras) and "conductor_presente" in _luces_delanteras:
		_luces_delanteras.set("conductor_presente", activo_actual)
		var modo := int(_luces_delanteras.get("modo_luces")) if "modo_luces" in _luces_delanteras else 0
		if _mat_faro_del:
			_mat_faro_del.emission_enabled = (modo > 0 and activo_actual)
			_mat_faro_del.emission_energy_multiplier = 4.5 if modo == 2 else (2.2 if modo == 1 else 0.0)

	if is_instance_valid(_direccionales):
		var est_izq := bool(_direccionales.get("estado_izquierda")) if "estado_izquierda" in _direccionales else false
		var est_der := bool(_direccionales.get("estado_derecha")) if "estado_derecha" in _direccionales else false
		if _mat_dir_izq:
			_mat_dir_izq.emission_enabled = est_izq
			_mat_dir_izq.emission_energy_multiplier = 4.5 if est_izq else 0.0
		if _mat_dir_der:
			_mat_dir_der.emission_enabled = est_der
			_mat_dir_der.emission_energy_multiplier = 4.5 if est_der else 0.0


func _buscar_vehiculo_raiz() -> RigidBody3D:
	var n: Node = get_parent()
	while n:
		if n is RigidBody3D:
			return n as RigidBody3D
		n = n.get_parent()
	return null


func _conectar_ruedas_a_fisicas() -> void:
	if not is_instance_valid(_coche):
		_coche = _buscar_vehiculo_raiz()
	if not is_instance_valid(_coche):
		return

	var ctrl_llantas := _coche.get_node_or_null("ControladorLlantas")
	if not ctrl_llantas:
		return

	# Forzar rango de giro realista de camión (evita que las llantas atraviesen el guardabarros)
	if "angulo_max_giro" in ctrl_llantas:
		ctrl_llantas.set("angulo_max_giro", 0.44)
	if "wheelbase" in ctrl_llantas:
		ctrl_llantas.set("wheelbase", 4.25)
	if "track_width" in ctrl_llantas:
		ctrl_llantas.set("track_width", 1.88)

	var mapa_ruedas := {
		"Empty_Rueda_Del_Izq": "Rueda_DI",
		"Empty_Rueda_Del_Der": "Rueda_DD",
		"Empty_Rueda_Tras_Izq": "Rueda_TI",
		"Empty_Rueda_Tras_Der": "Rueda_TD",
	}

	for nombre_empty in mapa_ruedas.keys():
		var empty_rueda := find_child(nombre_empty, true, false) as Node3D
		var ray_llanta := ctrl_llantas.get_node_or_null(mapa_ruedas[nombre_empty]) as RayCast3D
		if not empty_rueda or not ray_llanta:
			continue

		# Posicionar el anclaje superior del resorte (RayCast3D) ligeramente arriba del centro del eje,
		# para que cuando la suspensión se comprima en reposo (ty ≈ -0.14m), la rueda quede exactamente
		# en su altura original dentro del guardabarros sin levantar el camión.
		var pos_global_hub := empty_rueda.global_position
		ray_llanta.global_position = pos_global_hub + Vector3(0.0, offset_anclaje_suspension_y, 0.0)
		if "base_pos_x" in ray_llanta:
			ray_llanta.set("base_pos_x", ray_llanta.position.x)

		var pivot := ray_llanta.get_node_or_null("VisualPivot") as Node3D
		if not pivot:
			pivot = Node3D.new()
			pivot.name = "VisualPivot"
			ray_llanta.add_child(pivot)
			ray_llanta.move_child(pivot, 0)
		pivot.position = Vector3(0.0, -offset_anclaje_suspension_y, 0.0)

		if empty_rueda.get_parent():
			empty_rueda.get_parent().remove_child(empty_rueda)
		pivot.add_child(empty_rueda)
		empty_rueda.position = Vector3.ZERO
		empty_rueda.rotation = Vector3(0.0, PI, 0.0)
		empty_rueda.scale = Vector3.ONE * escala_modelo

		if "rueda_visual" in ray_llanta:
			ray_llanta.set("rueda_visual", pivot)
		if "rotacion_visual_base" in ray_llanta:
			ray_llanta.set("rotacion_visual_base", pivot.quaternion)


func _conectar_volante_dinamico() -> void:
	var empty_volante := find_child("Empty_Volante", true, false) as Node3D
	if not empty_volante or not ResourceLoader.exists(SCRIPT_VOLANTE):
		return

	# Determinar automáticamente el eje local más delgado del aro del volante (normal exacta del disco)
	var eje_normal := Vector3(0.0, 1.0, 0.0)
	var vol_mesh := empty_volante.find_child("Volante_NPR", true, false) as MeshInstance3D
	if vol_mesh and vol_mesh.mesh:
		var sz := vol_mesh.mesh.get_aabb().size
		if sz.x <= sz.y and sz.x <= sz.z:
			eje_normal = Vector3(1.0, 0.0, 0.0)
		elif sz.y <= sz.x and sz.y <= sz.z:
			eje_normal = Vector3(0.0, 1.0, 0.0)
		else:
			eje_normal = Vector3(0.0, 0.0, 1.0)

	empty_volante.set_script(load(SCRIPT_VOLANTE))
	empty_volante.set("espacio_eje", 0) # LOCAL
	empty_volante.set("tipo_eje", 3)    # PERSONALIZADO
	empty_volante.set("ejes_de_giro", eje_normal)
	empty_volante.set("invertir_giro", true)
	empty_volante.set("steering_wheel_ratio", 2.2)
	empty_volante.set("max_rotation_deg", 780.0)
	empty_volante.set("habilitar_vibracion_motor", false)
	empty_volante.set("intensidad_vibracion", 0.0)
	empty_volante.set_process(true)
	if empty_volante.has_method("_ready"):
		empty_volante._ready()


func _crear_mat_textura(ruta_tex: String, color_tinte: Color, rough: float, triplanar: bool = false, escala_uv: float = 1.0, emision_energia: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_tinte
	mat.roughness = rough
	if ResourceLoader.exists(ruta_tex):
		var tex := load(ruta_tex) as Texture2D
		mat.albedo_texture = tex
		if emision_energia > 0.0:
			mat.emission_enabled = true
			mat.emission_texture = tex
			mat.emission_energy_multiplier = emision_energia
	if triplanar:
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * escala_uv
	elif escala_uv != 1.0:
		mat.uv1_scale = Vector3.ONE * escala_uv
	return mat


func _aplicar_materiales_y_texturas_interior() -> void:
	var mat_carroceria: Material = load(MAT_CARROCERIA) if ResourceLoader.exists(MAT_CARROCERIA) else null
	var mat_cromo: Material = load(MAT_CROMO) if ResourceLoader.exists(MAT_CROMO) else null

	# Cristal claro automotriz para que las ventanas y el panorámico se vean nítidos desde adentro
	var mat_cristal_claro := StandardMaterial3D.new()
	mat_cristal_claro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cristal_claro.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_cristal_claro.albedo_color = Color(0.22, 0.30, 0.33, 0.16)
	mat_cristal_claro.roughness = 0.05
	mat_cristal_claro.metallic = 0.12

	var mat_panoramico: Material = mat_cristal_claro
	if ResourceLoader.exists(MAT_PANORAMICO):
		var pan_base := load(MAT_PANORAMICO)
		if pan_base is ShaderMaterial:
			var pan_claro := pan_base.duplicate() as ShaderMaterial
			pan_claro.set_shader_parameter("base_color", Color(0.12, 0.22, 0.24, 0.14))
			pan_claro.set_shader_parameter("metallic", 0.15)
			pan_claro.set_shader_parameter("reflection_intensity", 0.16)
			pan_claro.set_shader_parameter("sun_strip_opacity", 0.30)
			pan_claro.set_shader_parameter("dirt_intensity", 0.03)
			mat_panoramico = pan_claro

	# Materiales texturizados de alta calidad para el interior
	var mat_tablero := _crear_mat_textura(TEX_CUERO, Color(0.22, 0.23, 0.25), 0.46, true, 2.2)
	var mat_volante := _crear_mat_textura(TEX_CUERO, Color(0.14, 0.15, 0.17), 0.38, true, 3.0)
	var mat_sillas := _crear_mat_textura(TEX_ASIENTO_NPR, Color(0.85, 0.86, 0.88), 0.58, true, 1.8)
	mat_sillas.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_puertas_int := _crear_mat_textura(TEX_PLASTICO_GRIS, Color(0.30, 0.32, 0.35), 0.52, true, 2.0)
	var mat_piso_cab := _crear_mat_textura(TEX_PLASTICO_NEGRO, Color(0.15, 0.16, 0.18), 0.65, true, 2.5)
	var mat_consola := _crear_mat_textura(TEX_INTERIOR_NPR, Color(0.75, 0.76, 0.78), 0.50, false, 1.0)
	var mat_palanca := _crear_mat_textura(TEX_CAMBIO, Color(0.85, 0.85, 0.85), 0.42, false, 1.0)
	var mat_radio := _crear_mat_textura(TEX_RADIO, Color(0.95, 0.95, 0.95), 0.35, false, 1.0, 0.35)
	var mat_cluster := _crear_mat_textura(TEX_PANEL_ON, Color(1.0, 1.0, 1.0), 0.25, false, 1.0, 0.85)
	var mat_botones := _crear_mat_textura(TEX_BOTONES, Color(0.95, 0.95, 0.95), 0.35, false, 1.0, 0.45)

	var scr_panoramico: Script = load(SCRIPT_PANORAMICO) if ResourceLoader.exists(SCRIPT_PANORAMICO) else null

	var cola: Array[Node] = [self]
	while not cola.is_empty():
		var n: Node = cola.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var nm := mi.name.to_lower()

			# 1. Piezas específicas del interior por nombre
			if nm == "tablero_principal":
				mi.material_override = mat_tablero
			elif nm == "volante_npr" or nm == "piece_3_004" or nm == "piece_3.004":
				mi.material_override = mat_volante
			elif nm.begins_with("silla_"):
				mi.material_override = mat_sillas
			elif nm.begins_with("panel_puerta_interior") or nm == "columna_direccion" or nm == "awe_653" or nm == "awe.653":
				mi.material_override = mat_puertas_int
			elif nm == "piso_forro_cabina":
				mi.material_override = mat_piso_cab
			elif nm.begins_with("interior_sillas_y_mas"):
				mi.material_override = mat_consola
			elif nm.begins_with("_manualgearn_"):
				mi.material_override = mat_palanca
			elif nm == "tablero1_002" or nm == "tablero1.002":
				mi.material_override = mat_radio
			elif nm == "luces" or nm.begins_with("_ref002_"):
				mi.material_override = mat_cluster
			elif nm == "luces_001" or nm == "luces.001":
				mi.material_override = mat_botones
			# 2. Cristales claros
			elif nm == "vidrio_panoramico":
				mi.material_override = mat_panoramico
				if scr_panoramico and mi.get_script() == null:
					mi.set_script(scr_panoramico)
					if mi.has_method("_ready"):
						mi._ready()
			elif nm.begins_with("vidrio_puerta") or nm == "awe_639" or nm == "awe.639":
				mi.material_override = mat_cristal_claro
			# 3. Materiales por superficie
			elif mi.mesh:
				var surf_count := mi.mesh.get_surface_count()
				for s in range(surf_count):
					var m := mi.mesh.surface_get_material(s)
					if not m:
						continue
					var mn := m.resource_name.to_lower()
					if "carpaint" in mn and mat_carroceria:
						mi.set_surface_override_material(s, mat_carroceria)
					elif ("chrome" in mn or "cromo" in mn or "cromado" in mn) and mat_cromo:
						mi.set_surface_override_material(s, mat_cromo)
					elif ("windowglass" in mn or "darkglass" in mn):
						mi.set_surface_override_material(s, mat_cristal_claro)
					elif "mirror" in mn and mat_cromo and nm.begins_with("piece_"):
						mi.set_surface_override_material(s, mat_cromo)

		for h in n.get_children():
			cola.append(h)


func _conectar_mallas_luces() -> void:
	if not is_instance_valid(_coche):
		_coche = _buscar_vehiculo_raiz()
	if not is_instance_valid(_coche):
		return

	_luces_delanteras = _coche.get_node_or_null("Luces/LucesDelanteras") as Node3D
	_luz_stop = _coche.get_node_or_null("Luces/LuzStop") as Node3D
	_direccionales = _coche.get_node_or_null("Luces/Direccionales") as Node3D

	# Faros delanteros (awe.629 -> awe_629 en Godot glTF)
	var m_faro := _buscar_malla_por_nombres(["awe_629", "awe.629"])
	if m_faro:
		_mat_faro_del = StandardMaterial3D.new()
		_mat_faro_del.albedo_color = Color(0.92, 0.95, 1.0, 0.65)
		_mat_faro_del.roughness = 0.08
		_mat_faro_del.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_faro_del.emission = Color(0.96, 0.98, 1.0)
		m_faro.set_surface_override_material(0, _mat_faro_del)

	# Luces de Stop traseras (awe.611 y awe.612)
	var m_stop_izq := _buscar_malla_por_nombres(["awe_611", "awe.611"])
	var m_stop_der := _buscar_malla_por_nombres(["awe_612", "awe.612"])
	var paths_stop: Array[NodePath] = []
	for ms in [m_stop_izq, m_stop_der]:
		if ms:
			var mat_st := StandardMaterial3D.new()
			mat_st.albedo_color = Color(0.75, 0.04, 0.04)
			mat_st.roughness = 0.15
			mat_st.emission_enabled = true
			mat_st.emission = Color(1.0, 0.08, 0.05)
			mat_st.emission_energy_multiplier = 0.35
			ms.set_surface_override_material(0, mat_st)
			if is_instance_valid(_luz_stop):
				paths_stop.append(_luz_stop.get_path_to(ms))
	if is_instance_valid(_luz_stop) and not paths_stop.is_empty():
		_luz_stop.set("mallas", paths_stop)
		_luz_stop.set("_mallas_listas", true)

	# Direccionales traseras (awe.616 = Izq, awe.615 = Der)
	var m_dir_izq := _buscar_malla_por_nombres(["awe_616", "awe.616"])
	if m_dir_izq:
		_mat_dir_izq = StandardMaterial3D.new()
		_mat_dir_izq.albedo_color = Color(0.90, 0.38, 0.02)
		_mat_dir_izq.roughness = 0.15
		_mat_dir_izq.emission = Color(1.0, 0.55, 0.05)
		m_dir_izq.set_surface_override_material(0, _mat_dir_izq)

	var m_dir_der := _buscar_malla_por_nombres(["awe_615", "awe.615"])
	if m_dir_der:
		_mat_dir_der = StandardMaterial3D.new()
		_mat_dir_der.albedo_color = Color(0.90, 0.38, 0.02)
		_mat_dir_der.roughness = 0.15
		_mat_dir_der.emission = Color(1.0, 0.55, 0.05)
		m_dir_der.set_surface_override_material(0, _mat_dir_der)


func _buscar_malla_por_nombres(nombres: Array[String]) -> MeshInstance3D:
	for nm in nombres:
		var n := find_child(nm, true, false) as MeshInstance3D
		if n:
			return n
	return null


func _configurar_espejos_funcionales() -> void:
	if not is_instance_valid(_coche):
		return

	# Definir espejos: [nombres_malla, offset_angulo_x, offset_angulo_y, fov, resolucion]
	var specs := [
		{ "nombres": ["awe_560", "awe.560"], "dir_x": -0.16, "dir_y": -0.06, "fov": 46.0, "res": Vector2i(256, 384) }, # Izquierdo
		{ "nombres": ["awe_561", "awe.561"], "dir_x": 0.16,  "dir_y": -0.06, "fov": 46.0, "res": Vector2i(256, 384) }, # Derecho
		{ "nombres": ["awe_562", "awe.562"], "dir_x": 0.28,  "dir_y": -0.28, "fov": 72.0, "res": Vector2i(224, 224) }, # Auxiliar gran angular
	]

	var shader_code := """
shader_type spatial;
render_mode unshaded;
uniform sampler2D mirror_tex : source_color, filter_linear;
uniform vec3 aabb_min;
uniform vec3 aabb_size;
uniform float tint_strength = 0.08;
varying vec3 local_v;
void vertex() {
	local_v = VERTEX;
}
void fragment() {
	vec2 uv_m = vec2(
		clamp((local_v.x - aabb_min.x) / max(aabb_size.x, 0.0001), 0.0, 1.0),
		1.0 - clamp((local_v.y - aabb_min.y) / max(aabb_size.y, 0.0001), 0.0, 1.0)
	);
	vec3 col = texture(mirror_tex, uv_m).rgb;
	ALBEDO = mix(col, vec3(0.75, 0.85, 0.92), tint_strength);
}
"""
	var sh := Shader.new()
	sh.code = shader_code

	for sp in specs:
		var nombres_espejo: Array[String] = []
		nombres_espejo.assign(sp["nombres"])
		var mi := _buscar_malla_por_nombres(nombres_espejo)
		if not mi or not mi.mesh:
			continue

		var aabb := mi.mesh.get_aabb()
		var centro_local := aabb.get_center()

		# Crear SubViewport dedicado para el retrovisor
		var vp := SubViewport.new()
		vp.name = "SubViewport_" + mi.name
		vp.size = sp["res"]
		vp.msaa_3d = SubViewport.MSAA_DISABLED
		vp.positional_shadow_atlas_size = 0
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		mi.add_child(vp)
		_espejos_viewports.append(vp)

		# Crear Camera3D alineada con el espejo mirando hacia atrás del camión
		var cam := Camera3D.new()
		cam.name = "Cam_" + mi.name
		cam.fov = sp["fov"]
		cam.near = 0.25
		cam.far = 250.0
		cam.set_cull_mask_value(3, false) # Evitar feedback de capa 3
		vp.add_child(cam)
		cam.current = true
		_espejos_camaras.append(cam)

		# Usar RemoteTransform3D en el espejo para mover la cámara del SubViewport en el mundo
		var pivot_cam := Node3D.new()
		pivot_cam.name = "PivotCam_" + mi.name
		mi.add_child(pivot_cam)
		pivot_cam.position = centro_local

		var target_global := pivot_cam.global_position + _coche.global_transform.basis.z * 10.0 \
			+ _coche.global_transform.basis.x * (float(sp["dir_x"]) * 10.0) \
			+ _coche.global_transform.basis.y * (float(sp["dir_y"]) * 10.0)
		pivot_cam.look_at(target_global, _coche.global_transform.basis.y)

		var rt := RemoteTransform3D.new()
		rt.remote_path = cam.get_path()
		pivot_cam.add_child(rt)

		# Mover malla del espejo a Capa 3 para evitar feedback en Vulkan (Cam_Interna la ve)
		mi.set_layer_mask_value(1, false)
		mi.set_layer_mask_value(3, true)

		# Asignar ShaderMaterial proyectado por AABB local
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("mirror_tex", vp.get_texture())
		sm.set_shader_parameter("aabb_min", aabb.position)
		sm.set_shader_parameter("aabb_size", aabb.size)
		mi.material_override = sm


func _actualizar_estado_espejos(conductor_activo: bool) -> void:
	var en_cabina := conductor_activo and is_instance_valid(_cam_interna) and _cam_interna.current
	if en_cabina == _espejos_activos:
		return
	_espejos_activos = en_cabina
	var modo := SubViewport.UPDATE_ALWAYS if en_cabina else SubViewport.UPDATE_DISABLED
	for vp in _espejos_viewports:
		if is_instance_valid(vp):
			vp.render_target_update_mode = modo
	if en_cabina:
		# CameraManager.desactivar_camaras() apaga current=false en todas las Camera3D hijas al bajarse;
		# reactivarlas aquí al volver a entrar a la cabina.
		for cam in _espejos_camaras:
			if is_instance_valid(cam):
				cam.current = true
