@tool
extends Node3D

## t800_setup_modular.gd
## Conecta automáticamente la jerarquía modular de T800_Alargada.glb (Cabina_Exterior,
## Interior_Cabina, Cristales_y_Espejos, Chasis_y_Suspension, Ruedas) con todos los
## materiales texturizados de Godot (tanto en editor como en tiempo de ejecución),
## doble cara en suelo interior y asientos, espejos retrovisores funcionales y quinta rueda.

const MAT_CARROCERIA := "res://materiales/Vehiculos/Carroceria.tres"
const MAT_CROMO := "res://modelos3d/vehiculos/materiales/cromo.tres"
const MAT_CROMO_ALT := "res://materiales/Vehiculos/cromo.tres"
const MAT_CROMADO := "res://shaders/cromado_realista.tres"
const MAT_NEGRO := "res://materiales/negro.tres"
const MAT_PLASTICO_NEGRO := "res://modelos3d/vehiculos/materiales/basicos/plastico_negro.tres"
const MAT_CRISTAL := "res://modelos3d/vehiculos/materiales/cristal.tres"

const TEX_DIR := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/textures/"
const TEX_DETALI := TEX_DIR + "detali.png"
const TEX_DETAILS := TEX_DIR + "details.png"
const TEX_NEGRO := TEX_DIR + "negro.png"
const TEX_PLASTIC3 := TEX_DIR + "plastic3 (2).png"
const TEX_PLAST_WOOD := TEX_DIR + "plast_wood.png"
const TEX_LEATHER_DARK := TEX_DIR + "leather_dark.png"
const TEX_WOOD := TEX_DIR + "woodtexture.png"
const TEX_WOOD_KNOB := TEX_DIR + "wood.png"
const TEX_INTERIOR_BARKAI := TEX_DIR + "interiorbarkai.png"
const TEX_PALANCA := TEX_DIR + "tex de palanca.png"
const TEX_GREY := TEX_DIR + "grey.png"
const TEX_FARO := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800_Alargada/T800_Alargada_Faro.jpg"
const TEX_ECON4 := "res://modelos3d/vehiculos/tractomulas/cabezotes/T800/T800 Econom_0_4.png"

var _coche: RigidBody3D = null
var _motor: Node = null
var _cam_interna: Camera3D = null
var _espejos_viewports: Array[SubViewport] = []
var _espejos_camaras: Array[Camera3D] = []
var _espejos_activos: bool = false
var _palanca_pivot: Node3D = null
var _palanca_rot_base: Vector3 = Vector3.ZERO
var _palanca_tilt_actual: Vector2 = Vector2.ZERO


func _ready() -> void:
	_coche = _buscar_vehiculo_raiz()
	if is_instance_valid(_coche) and not Engine.is_editor_hint():
		_cam_interna = _coche.find_child("Cam_Interna", true, false) as Camera3D
		_motor = _coche.get_node_or_null("Motor")
		_palanca_pivot = _coche.find_child("Palanca_Pivot", true, false) as Node3D
		if _palanca_pivot:
			_palanca_rot_base = _palanca_pivot.rotation
	if not Engine.is_editor_hint():
		call_deferred("_conectar_ruedas_a_fisicas")
		call_deferred("_reconectar_enganche")


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_coche):
		return
	var activo_actual := bool(_coche.get("activo")) if "activo" in _coche else false
	_actualizar_estado_espejos(activo_actual)
	_actualizar_animacion_palanca(delta, activo_actual)


func _buscar_vehiculo_raiz() -> RigidBody3D:
	var n: Node = get_parent()
	while n:
		if n is RigidBody3D:
			return n as RigidBody3D
		n = n.get_parent()
	return null


func _crear_mat_tex(ruta: String, color: Color = Color.WHITE, rough: float = 0.5, metal: float = 0.0, doble_cara: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if doble_cara:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ruta != "" and ResourceLoader.exists(ruta):
		mat.albedo_texture = load(ruta) as Texture2D
	return mat


func _aplicar_materiales_y_texturas() -> void:
	if not is_instance_valid(_coche):
		_coche = _buscar_vehiculo_raiz()
	if not is_instance_valid(_coche):
		return

	var mat_carroceria: Material = load(MAT_CARROCERIA) if ResourceLoader.exists(MAT_CARROCERIA) else null
	var mat_cromo: Material = load(MAT_CROMO) if ResourceLoader.exists(MAT_CROMO) else null
	var mat_cromo_alt: Material = load(MAT_CROMO_ALT) if ResourceLoader.exists(MAT_CROMO_ALT) else mat_cromo
	var mat_cromado: Material = load(MAT_CROMADO) if ResourceLoader.exists(MAT_CROMADO) else mat_cromo
	var mat_negro: Material = load(MAT_NEGRO) if ResourceLoader.exists(MAT_NEGRO) else null
	var mat_plastico_negro: Material = load(MAT_PLASTICO_NEGRO) if ResourceLoader.exists(MAT_PLASTICO_NEGRO) else mat_negro
	var mat_cristal: Material = load(MAT_CRISTAL) if ResourceLoader.exists(MAT_CRISTAL) else null

	# Materiales texturizados completos (exterior, chasis, llantas e interior)
	var mat_chasis := _crear_mat_tex(TEX_NEGRO, Color(0.16, 0.17, 0.19), 0.55, 0.25)
	var mat_goma_negra := _crear_mat_tex(TEX_NEGRO, Color(0.08, 0.085, 0.09), 0.85, 0.0)
	var mat_neumatico := _crear_mat_tex(TEX_NEGRO, Color(0.07, 0.075, 0.08), 0.88, 0.0)
	var mat_asientos := _crear_mat_tex(TEX_LEATHER_DARK, Color(0.88, 0.88, 0.90), 0.48, 0.0, true)
	var mat_interior := _crear_mat_tex(TEX_INTERIOR_BARKAI, Color(0.92, 0.92, 0.94), 0.55, 0.0, true)
	var mat_interior_negro := _crear_mat_tex(TEX_NEGRO, Color(0.14, 0.145, 0.16), 0.65, 0.0, true)
	var mat_tablero_det := _crear_mat_tex(TEX_DETALI, Color(0.96, 0.96, 0.96), 0.40, 0.05)
	var mat_details := _crear_mat_tex(TEX_DETAILS, Color(0.95, 0.95, 0.95), 0.45, 0.10)
	var mat_madera := _crear_mat_tex(TEX_WOOD, Color(0.95, 0.92, 0.88), 0.35, 0.05)
	var mat_madera_pomo := _crear_mat_tex(TEX_WOOD_KNOB, Color(0.95, 0.92, 0.88), 0.32, 0.05)
	var mat_plast3 := _crear_mat_tex(TEX_PLASTIC3, Color(0.82, 0.84, 0.86), 0.52, 0.05)
	var mat_gris := _crear_mat_tex(TEX_GREY, Color(0.55, 0.57, 0.60), 0.45, 0.20)
	var mat_quinta := _crear_mat_tex(TEX_NEGRO, Color(0.22, 0.23, 0.25), 0.48, 0.45)
	var mat_palanca := _crear_mat_tex(TEX_PALANCA, Color(0.92, 0.92, 0.92), 0.45, 0.10)
	var mat_radio := _crear_mat_tex(TEX_ECON4, Color(0.95, 0.95, 0.95), 0.35, 0.0)
	var mat_aguja := _crear_mat_tex("", Color(0.92, 0.22, 0.14), 0.35, 0.0)

	var mat_faro := _crear_mat_tex(TEX_FARO, Color(1.0, 0.98, 0.92), 0.15, 0.10)
	mat_faro.emission_enabled = true
	mat_faro.emission = Color(0.95, 0.90, 0.78)
	mat_faro.emission_energy_multiplier = 0.65

	var mat_espejo_base := _crear_mat_tex("", Color(0.82, 0.88, 0.94), 0.02, 1.0)
	mat_espejo_base.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Ocultar piezas que T800_A.tscn reemplaza por nodos propios (VolanteDragon)
	var ocultar_nodos := [
		"Volante_Pivot", "ParaBichos", "Antena",
		"Insignia1", "Luz_Cono", "Corneta"
	]
	for nm_oc in ocultar_nodos:
		var nodo_oc := _coche.find_child(nm_oc, true, false) as Node3D
		if nodo_oc:
			nodo_oc.visible = false

	# Asignar materiales globales por nombre de nodo
	var mapa_mat := {
		"Capo": mat_carroceria,
		"Accesorio_parachoquesD": mat_carroceria,
		"Plane_002": mat_carroceria,
		"parachoques_delantero": mat_cromo,
		"parachoques_trasero": mat_cromo,
		"Rejilla_radiador": mat_cromo,
		"Logo": mat_cromo,
		"Parasol": mat_cromo,
		"Parasol_lateral": mat_cromo,
		"Espejos": mat_cromo,
		"Filtro_aire": mat_cromo,
		"GuardaEscape": mat_cromo,
		"GuardaEscape_001": mat_cromo_alt,
		"Guarbarros_Trasero1": mat_cromo,
		"Tanques_combustible_002": mat_cromo,
		"Tanques_combustible_003": mat_cromo,
		"Cylinder_002": mat_cromo,
		"Cylinder": mat_cromo,
		"Cube_002": mat_cromo,
		"Guardabarro_delantero": mat_goma_negra,
		"Guardabarros": mat_goma_negra,
		"gomaventana_ref001_": mat_goma_negra,
		"parrilla_trasera": mat_plastico_negro,
		"Chasis": mat_chasis,
		"Soporte_cables": mat_chasis,
		"Kt800_003": mat_quinta,
		"Parabrisas": mat_cristal,
		"asientos": mat_asientos,
		"Fondo_panel": mat_tablero_det,
		"Aguja": mat_aguja,
		"Tableta": mat_plast3,
		"palanca_003": mat_palanca,
		"Palanca_intermitente": mat_interior_negro,
		"Palanca_parabrisas": mat_interior_negro,
		"palancas_ref002_": mat_interior,
		"negroz_ref001_off_click001_off__001": mat_interior_negro,
	}
	for nm_m in mapa_mat.keys():
		var m_res: Material = mapa_mat[nm_m]
		if not m_res:
			continue
		var mi := _coche.find_child(nm_m, true, false) as MeshInstance3D
		if mi:
			mi.material_override = m_res

	# Puertas: superficie 0 = carrocería, superficie 1 = moldura/marco cromado
	var puertas := _coche.find_child("Puertas", true, false) as MeshInstance3D
	if puertas and puertas.mesh:
		if mat_carroceria and puertas.mesh.get_surface_count() > 0:
			puertas.set_surface_override_material(0, mat_carroceria)
		if mat_cromo and puertas.mesh.get_surface_count() > 1:
			puertas.set_surface_override_material(1, mat_cromo)

	# Faros y cromo del capó
	var capo2 := _coche.find_child("Capo_002", true, false) as MeshInstance3D
	if capo2 and capo2.mesh:
		if mat_cromo and capo2.mesh.get_surface_count() > 0:
			capo2.set_surface_override_material(0, mat_cromo)
		if capo2.mesh.get_surface_count() > 1:
			capo2.set_surface_override_material(1, mat_faro)

	var acc_car := _coche.find_child("Accesorio_carroceria", true, false) as MeshInstance3D
	if acc_car and acc_car.mesh:
		if mat_cromado and acc_car.mesh.get_surface_count() > 0:
			acc_car.set_surface_override_material(0, mat_cromado)
		if mat_carroceria and acc_car.mesh.get_surface_count() > 1:
			acc_car.set_surface_override_material(1, mat_carroceria)

	# Tablero principal (14 superficies diferenciadas: relojes, madera, cuero, plástico, gris)
	var tablero := _coche.find_child("Interior_Tablero", true, false) as MeshInstance3D
	if tablero and tablero.mesh:
		for s in range(tablero.mesh.get_surface_count()):
			var sm := tablero.mesh.surface_get_material(s)
			var sn := sm.resource_name.to_lower() if sm else ""
			if "detali" in sn:
				tablero.set_surface_override_material(s, mat_tablero_det)
			elif "details" in sn:
				tablero.set_surface_override_material(s, mat_details)
			elif "wood" in sn:
				tablero.set_surface_override_material(s, mat_madera)
			elif "leather" in sn:
				tablero.set_surface_override_material(s, mat_asientos)
			elif "grey" in sn:
				tablero.set_surface_override_material(s, mat_gris)
			elif "negro" in sn:
				tablero.set_surface_override_material(s, mat_interior_negro)
			else:
				tablero.set_surface_override_material(s, mat_plast3)

	# Consola/techo interior secundario
	var int_ref := _coche.find_child("Interior_ref002__004", true, false) as MeshInstance3D
	if int_ref and int_ref.mesh:
		for s in range(int_ref.mesh.get_surface_count()):
			var sm := int_ref.mesh.surface_get_material(s)
			var sn := sm.resource_name.to_lower() if sm else ""
			if "negro" in sn:
				int_ref.set_surface_override_material(s, mat_interior_negro)
			else:
				int_ref.set_surface_override_material(s, mat_interior)

	# Pomo de palanca de cambios (madera, cuero y base)
	var pomo := _coche.find_child("Pomo", true, false) as MeshInstance3D
	if pomo and pomo.mesh:
		for s in range(pomo.mesh.get_surface_count()):
			var sm := pomo.mesh.surface_get_material(s)
			var sn := sm.resource_name.to_lower() if sm else ""
			if "wood" in sn:
				pomo.set_surface_override_material(s, mat_madera_pomo)
			elif "leather" in sn:
				pomo.set_surface_override_material(s, mat_asientos)
			else:
				pomo.set_surface_override_material(s, mat_cromo)

	# Radio
	var radio := _coche.find_child("radio", true, false) as MeshInstance3D
	if radio and radio.mesh:
		for s in range(radio.mesh.get_surface_count()):
			var sm := radio.mesh.surface_get_material(s)
			var sn := sm.resource_name.to_lower() if sm else ""
			if "detali" in sn:
				radio.set_surface_override_material(s, mat_radio)
			else:
				radio.set_surface_override_material(s, mat_interior_negro)

	# Interior principal: vidrios + tapicería doble cara + molduras negras
	var interior_mi := _coche.find_child("Interior", true, false) as MeshInstance3D
	if interior_mi and interior_mi.mesh:
		for s in range(interior_mi.mesh.get_surface_count()):
			var surf_mat := interior_mi.mesh.surface_get_material(s)
			var sn := surf_mat.resource_name.to_lower() if surf_mat else ""
			if "vidrio" in sn or "glass" in sn:
				if mat_cristal:
					interior_mi.set_surface_override_material(s, mat_cristal)
			elif "negro" in sn:
				interior_mi.set_surface_override_material(s, mat_interior_negro)
			else:
				interior_mi.set_surface_override_material(s, mat_interior)

	# Ruedas: caucho mate en llanta y cromo en rines/copas
	for nm_r in ["Rueda_DI", "Rueda_DD", "Rueda_TI1", "Rueda_TI2", "Rueda_TD1", "Rueda_TD2"]:
		var r_mi := _coche.find_child(nm_r, true, false) as MeshInstance3D
		if r_mi and r_mi.mesh:
			for s in range(r_mi.mesh.get_surface_count()):
				var sm := r_mi.mesh.surface_get_material(s)
				var sn := sm.resource_name.to_lower() if sm else ""
				if "negro" in sn:
					r_mi.set_surface_override_material(s, mat_neumatico)
				elif mat_cromo:
					r_mi.set_surface_override_material(s, mat_cromo)


func _conectar_ruedas_a_fisicas() -> void:
	if not is_instance_valid(_coche):
		return
	var ctrl_llantas := _coche.get_node_or_null("ControladorLlantas")
	if not ctrl_llantas:
		return

	var mapa_ruedas := {
		"Rueda_Del_Izq": "Rueda_DI",
		"Rueda_Del_Der": "Rueda_DD",
		"Rueda_Tras_Izq_1": "Rueda_TI2",
		"Rueda_Tras_Izq_2": "Rueda_TI1",
		"Rueda_Tras_Der_1": "Rueda_TD2",
		"Rueda_Tras_Der_2": "Rueda_TD1",
	}

	for nombre_pivot in mapa_ruedas.keys():
		var rueda_blender := _coche.find_child(nombre_pivot, true, false) as Node3D
		var ray_llanta := ctrl_llantas.get_node_or_null(mapa_ruedas[nombre_pivot]) as RayCast3D
		if not rueda_blender or not ray_llanta:
			continue

		var gx := rueda_blender.global_transform
		var pivot := ray_llanta.get_node_or_null("VisualPivot") as Node3D
		if not pivot:
			pivot = Node3D.new()
			pivot.name = "VisualPivot"
			ray_llanta.add_child(pivot)
			ray_llanta.move_child(pivot, 0)
		pivot.global_position = gx.origin

		if rueda_blender.get_parent():
			rueda_blender.get_parent().remove_child(rueda_blender)
		pivot.add_child(rueda_blender)
		rueda_blender.global_transform = gx

		if "rueda_visual" in ray_llanta:
			ray_llanta.set("rueda_visual", pivot)
		if "rotacion_visual_base" in ray_llanta:
			ray_llanta.set("rotacion_visual_base", pivot.quaternion)


func _reconectar_enganche() -> void:
	if not is_instance_valid(_coche):
		return
	var eng := _coche.get_node_or_null("Enganche")
	if not eng:
		return
	var quinta_rueda := _coche.find_child("Kt800_003", true, false) as MeshInstance3D
	if quinta_rueda and "mesh_enganche" in eng:
		eng.set("mesh_enganche", quinta_rueda)


func _configurar_espejos_funcionales() -> void:
	if not is_instance_valid(_coche):
		return

	var specs := [
		{ "nombres": ["Espejo_Cristal_Izq"], "dir_x": -0.18, "dir_y": -0.05, "off_x": -0.05, "off_z": 0.16, "fov": 48.0, "res": Vector2i(256, 384) },
		{ "nombres": ["Espejo_Cristal_Der"], "dir_x": 0.18,  "dir_y": -0.05, "off_x": 0.05,  "off_z": 0.16, "fov": 48.0, "res": Vector2i(256, 384) },
	]

	var shader_code := """
shader_type spatial;
render_mode unshaded, cull_disabled;
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
		1.0 - clamp((local_v.x - aabb_min.x) / max(aabb_size.x, 0.0001), 0.0, 1.0),
		1.0 - clamp((local_v.y - aabb_min.y) / max(aabb_size.y, 0.0001), 0.0, 1.0)
	);
	vec3 col = texture(mirror_tex, uv_m).rgb;
	ALBEDO = mix(col, vec3(0.75, 0.85, 0.92), tint_strength);
}
"""
	var sh := Shader.new()
	sh.code = shader_code

	for sp in specs:
		var mi: MeshInstance3D = null
		for nm in sp["nombres"]:
			mi = _coche.find_child(nm, true, false) as MeshInstance3D
			if mi:
				break
		if not mi or not mi.mesh:
			continue

		mi.layers = 1 << 2
		var aabb := mi.mesh.get_aabb()

		var vp := SubViewport.new()
		vp.name = "VP_" + mi.name
		vp.size = sp["res"]
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_DISABLED
		_coche.add_child(vp)

		var cam := Camera3D.new()
		cam.name = "Cam_" + mi.name
		cam.fov = sp["fov"]
		cam.near = 0.25
		cam.far = 450.0
		cam.cull_mask = 0xFFFFFFFF & ~(1 << 2)
		vp.add_child(cam)

		var mount := Node3D.new()
		mount.name = "Mount_" + mi.name
		_coche.add_child(mount)
		var cam_offset: Vector3 = _coche.global_transform.basis * Vector3(sp["off_x"], 0.0, sp["off_z"])
		mount.global_transform = mi.global_transform
		mount.global_position += cam_offset
		var target_pos: Vector3 = mount.global_position + (_coche.global_transform.basis * Vector3(sp["dir_x"], sp["dir_y"], 1.0)) * 20.0
		mount.look_at(target_pos, _coche.global_transform.basis.y)

		var rt := RemoteTransform3D.new()
		rt.remote_path = cam.get_path()
		mount.add_child(rt)

		var smat := ShaderMaterial.new()
		smat.shader = sh
		smat.set_shader_parameter("mirror_tex", vp.get_texture())
		smat.set_shader_parameter("aabb_min", aabb.position)
		smat.set_shader_parameter("aabb_size", aabb.size)
		mi.material_override = smat

		_espejos_viewports.append(vp)
		_espejos_camaras.append(cam)


func _actualizar_estado_espejos(activo: bool) -> void:
	if _espejos_activos == activo:
		return
	_espejos_activos = activo
	var modo := SubViewport.UPDATE_ALWAYS if activo else SubViewport.UPDATE_DISABLED
	for vp in _espejos_viewports:
		if is_instance_valid(vp):
			vp.render_target_update_mode = modo


func _actualizar_animacion_palanca(delta: float, activo: bool) -> void:
	if not is_instance_valid(_palanca_pivot):
		return
	var target_deg := Vector2.ZERO
	if activo:
		var iv: Node = get_tree().root.get_node_or_null("InputVehiculo")
		var marcha_str: String = str(iv.get("marcha")) if iv and iv.get("marcha") != null else "N"
		if marcha_str == "R":
			target_deg = Vector2(-11.0, 7.0)
		elif marcha_str == "D":
			var gear: int = 0
			if is_instance_valid(_motor) and _motor.get("_current_gear") != null:
				gear = int(_motor.get("_current_gear"))
			var row_x: float = -9.5 if (gear % 2 == 0) else 9.5
			var col_z: float = 6.0 if (gear < 3) else (0.0 if gear < 7 else -6.0)
			target_deg = Vector2(row_x, col_z)
	var factor: float = 1.0 - exp(-12.0 * delta)
	_palanca_tilt_actual = _palanca_tilt_actual.lerp(target_deg, factor)
	_palanca_pivot.rotation = _palanca_rot_base + Vector3(
		deg_to_rad(_palanca_tilt_actual.x),
		0.0,
		deg_to_rad(_palanca_tilt_actual.y)
	)
