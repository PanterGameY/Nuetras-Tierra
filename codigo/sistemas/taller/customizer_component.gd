extends Node
class_name CustomizerComponent

signal mesh_selected(slot_idx)

# Minimal, robust CustomizerComponent compatible with MenuPersonalizacion
# Provides the properties and methods expected by the UI and Taller

@export_group("Nodos de Carrocería")
@export var material_index: int = 0

var wheel_offset_actual: float = 0.0
var wheel_camber_actual: float = 0.0

var neon_node: Node3D = null
var neon_enabled_actual: bool = false
var neon_color_actual: Color = Color.BLUE
var neon_intensity_actual: float = 1.0

var plate_text_actual: String = "ABC 123"
var plate_city_actual: String = "BOGOTÁ"
var plate_is_public_actual: bool = false

var skin_actual_path: String = ""

# Compatibility props used by the UI
var color_actual: Color = Color.WHITE
var metallic_actual: float = 0.0
var roughness_actual: float = 0.5
var specular_actual: float = 0.5

var color_sec_actual: Color = Color.WHITE
var metallic_sec_actual: float = 0.0
var roughness_sec_actual: float = 0.5
var specular_sec_actual: float = 0.5

var glass_color_actual: Color = Color.BLACK
var glass_opacity_actual: float = 0.0

var rims_color_actual: Color = Color.WHITE
var rims_metallic_actual: float = 0.8
var rims_roughness_actual: float = 0.2
var modelo_rines: String = "original"

var materiales_detectados: Array = []
var meshes_materiales_mapeo: Dictionary = {}
var meshes_detectados: Array = []

func _ready() -> void:
	await get_tree().process_frame
	detectar_materiales_personalizables()
	detectar_meshes_personalizables()
	cargar_personalizacion()

func detectar_materiales_personalizables() -> void:
	materiales_detectados.clear()
	meshes_materiales_mapeo.clear()
	var parent = get_parent()
	if parent:
		_detectar_materiales_recursivo(parent)

func _detectar_materiales_recursivo(nodo: Node) -> void:
	if not nodo:
		return
	if nodo is MeshInstance3D:
		if nodo.material_override and (nodo.material_override is StandardMaterial3D or nodo.material_override is ShaderMaterial):
			_registrar_material(nodo.material_override, nodo, -1)
		for i in range(nodo.get_surface_override_material_count()):
			var mat = nodo.get_surface_override_material(i)
			if mat and (mat is StandardMaterial3D or mat is ShaderMaterial):
				_registrar_material(mat, nodo, i)
		if nodo.mesh:
			for i in range(nodo.mesh.get_surface_count()):
				var mat = nodo.get_active_material(i)
				if mat and (mat is StandardMaterial3D or mat is ShaderMaterial):
					_registrar_material(mat, nodo, i)
	for hijo in nodo.get_children():
		_detectar_materiales_recursivo(hijo)

func _registrar_material(mat: Material, mesh: MeshInstance3D, index: int) -> void:
	var m_name = mat.resource_name.to_lower() if mat.resource_name != null else ""
	var _path = mat.resource_path.to_lower() if mat.resource_path != null else ""
	if "tire" in m_name or "rubber" in m_name or "caucho" in m_name or "neumatico" in _path:
		return
	if not materiales_detectados.has(mat):
		materiales_detectados.append(mat)
		meshes_materiales_mapeo[mat] = []
	var ya = false
	for item in meshes_materiales_mapeo[mat]:
		if item["mesh"] == mesh and item["index"] == index:
			ya = true
			break
	if not ya:
		meshes_materiales_mapeo[mat].append({"mesh": mesh, "index": index})

func aplicar_color_slot(slot_idx: int, color: Color, metallic: float, roughness: float, specular: float) -> void:
	if slot_idx < 0 or slot_idx >= materiales_detectados.size():
		return
	var mat_original = materiales_detectados[slot_idx]
	var lista_meshes: Array = meshes_materiales_mapeo.get(mat_original, [])
	var mat_duplicado: Material = null
	for item in lista_meshes:
		var mesh: MeshInstance3D = item["mesh"]
		var index: int = item["index"]
		if not is_instance_valid(mesh):
			continue
		var mat_actual = mesh.material_override if index == -1 else mesh.get_surface_override_material(index)
		if not mat_actual or mat_actual == mat_original:
			if not mat_duplicado:
				mat_duplicado = mat_original.duplicate()
			mat_actual = mat_duplicado
		if mat_actual is StandardMaterial3D:
			mat_actual.albedo_color = color
			mat_actual.metallic = metallic
			mat_actual.roughness = roughness
			mat_actual.metallic_specular = specular
		elif mat_actual is ShaderMaterial:
			if mat_actual.get_shader_parameter("albedo") != null:
				mat_actual.set_shader_parameter("albedo", color)
			elif mat_actual.get_shader_parameter("paint_color") != null:
				mat_actual.set_shader_parameter("paint_color", color)
			if mat_actual.get_shader_parameter("metallic") != null:
				mat_actual.set_shader_parameter("metallic", metallic)
			if mat_actual.get_shader_parameter("roughness") != null:
				mat_actual.set_shader_parameter("roughness", roughness)
		if index == -1:
			mesh.material_override = mat_actual
		else:
			mesh.set_surface_override_material(index, mat_actual)
	if mat_duplicado:
		meshes_materiales_mapeo[mat_duplicado] = lista_meshes
		meshes_materiales_mapeo.erase(mat_original)
		materiales_detectados[slot_idx] = mat_duplicado

func aplicar_offset_ruedas(val: float) -> void:
	wheel_offset_actual = val
	var parent = get_parent()
	if parent:
		for hijo in parent.get_children():
			if hijo.name == "ControladorLlantas" or hijo.name == "controlador_llantas":
				for llanta in hijo.get_children():
					if llanta.has_method("aplicar_offset"):
						llanta.aplicar_offset(val)

func aplicar_camber_ruedas(val: float) -> void:
	wheel_camber_actual = val
	var parent = get_parent()
	if parent:
		for hijo in parent.get_children():
			if hijo.name == "ControladorLlantas" or hijo.name == "controlador_llantas":
				for llanta in hijo.get_children():
					if "camber_deg" in llanta:
						llanta.camber_deg = val

func aplicar_neon(enabled: bool, color: Color, intensity: float) -> void:
	neon_enabled_actual = enabled
	neon_color_actual = color
	neon_intensity_actual = intensity
	var parent = get_parent()
	if not parent:
		return
	if not enabled:
		var ex_neon = parent.get_node_or_null("UnderglowNeon")
		if ex_neon:
			ex_neon.queue_free()
		neon_node = null
		return
	if not neon_node or not is_instance_valid(neon_node):
		neon_node = parent.get_node_or_null("UnderglowNeon")
		if not neon_node:
			neon_node = Node3D.new()
			neon_node.name = "UnderglowNeon"
			parent.add_child(neon_node)
			var posiciones = [Vector3(-1.0, -0.4, 2.0), Vector3(1.0, -0.4, 2.0), Vector3(-1.0, -0.4, -2.0), Vector3(1.0, -0.4, -2.0)]
			for i in range(posiciones.size()):
				var light = OmniLight3D.new()
				light.name = "NeonLight_%d" % i
				light.omni_range = 5.0
				light.omni_attenuation = 1.2
				light.shadow_enabled = false
				neon_node.add_child(light)
				light.position = posiciones[i]
	for light in neon_node.get_children():
		if light is OmniLight3D:
			light.light_color = color
			light.light_energy = intensity * 4.0

func aplicar_placa(texto: String, ciudad: String, es_publica: bool) -> void:
	plate_text_actual = texto
	plate_city_actual = ciudad
	plate_is_public_actual = es_publica
	var parent = get_parent()
	if parent:
		_actualizar_placas_recursivo(parent, texto, ciudad, es_publica)

func _actualizar_placas_recursivo(nodo: Node, texto: String, ciudad: String, es_publica: bool) -> void:
	if not nodo:
		return
	var is_placa = nodo.has_method("set_plate") or "plate_text" in nodo
	if is_placa:
		if "plate_text" in nodo:
			nodo.set("plate_text", texto)
		if "city" in nodo:
			nodo.set("city", ciudad)
		if "publico" in nodo:
			nodo.set("publico", es_publica)
		if nodo.has_method("_update_labels"):
			nodo.call("_update_labels")
		if nodo.has_method("_update_color"):
			nodo.call("_update_color")
	for hijo in nodo.get_children():
		_actualizar_placas_recursivo(hijo, texto, ciudad, es_publica)

func aplicar_skin(textura_path: String) -> void:
	skin_actual_path = textura_path
	var tex = load(textura_path) if textura_path != "" else null
	if not tex:
		return
	if materiales_detectados.size() > 0:
		var mat = materiales_detectados[0]
		if mat is StandardMaterial3D:
			mat.albedo_texture = tex

func guardar_personalizacion() -> void:
	if DatosUsuario:
		var parent_name = String(get_parent().name) if get_parent() else "<unknown>"
		if not "vehiculos_personalizados" in DatosUsuario:
			DatosUsuario.set("vehiculos_personalizados", {})
		var col_hex_list = []
		var met_list = []
		var rough_list = []
		var spec_list = []
		for mat in materiales_detectados:
			if mat is StandardMaterial3D:
				col_hex_list.append(mat.albedo_color.to_html())
				met_list.append(mat.metallic)
				rough_list.append(mat.roughness)
				spec_list.append(mat.metallic_specular)
			elif mat is ShaderMaterial:
				var col = mat.get_shader_parameter("albedo")
				if col == null:
					col = mat.get_shader_parameter("paint_color")
				if col == null:
					col = Color.WHITE
				col_hex_list.append(col.to_html())
				var met = mat.get_shader_parameter("metallic")
				met_list.append(met if met != null else 0.0)
				var rough = mat.get_shader_parameter("roughness")
				rough_list.append(rough if rough != null else 0.5)
				spec_list.append(0.5)
		var dict = {
			"colores_slots": col_hex_list,
			"metallic_slots": met_list,
			"roughness_slots": rough_list,
			"specular_slots": spec_list,
			"wheel_offset": wheel_offset_actual,
			"wheel_camber": wheel_camber_actual,
			"skin": skin_actual_path,
			"neon_enabled": neon_enabled_actual,
			"neon_color": neon_color_actual.to_html(),
			"neon_intensity": neon_intensity_actual,
			"plate_text": plate_text_actual,
			"plate_city": plate_city_actual,
			"plate_is_public": plate_is_public_actual
		}
		DatosUsuario.get("vehiculos_personalizados")[parent_name] = dict
		DatosUsuario.save_local()
		print("CustomizerComponent: Personalización guardada para ", parent_name)

func cargar_personalizacion() -> void:
	if DatosUsuario and "vehiculos_personalizados" in DatosUsuario:
		var parent_name = String(get_parent().name) if get_parent() else "<unknown>"
		var dicts = DatosUsuario.get("vehiculos_personalizados")
		if dicts and dicts.has(parent_name):
			var data = dicts[parent_name]
			var col_list = data.get("colores_slots", [])
			var met_list = data.get("metallic_slots", [])
			var rough_list = data.get("roughness_slots", [])
			var spec_list = data.get("specular_slots", [])
			for i in range(min(col_list.size(), materiales_detectados.size())):
				var col = Color.html(col_list[i])
				var met = float(met_list[i]) if i < met_list.size() else 0.0
				var rough = float(rough_list[i]) if i < rough_list.size() else 0.5
				var spec = float(spec_list[i]) if i < spec_list.size() else 0.5
				aplicar_color_slot(i, col, met, rough, spec)
			aplicar_offset_ruedas(float(data.get("wheel_offset", 0.0)))
			aplicar_camber_ruedas(float(data.get("wheel_camber", 0.0)))
			aplicar_neon(bool(data.get("neon_enabled", false)), Color.html(data.get("neon_color", "0000ff")), float(data.get("neon_intensity", 1.0)))
			aplicar_placa(str(data.get("plate_text", "ABC 123")), str(data.get("plate_city", "BOGOTÁ")), bool(data.get("plate_is_public", false)))
			if data.has("skin") and data["skin"] != "":
				aplicar_skin(data["skin"])

# Wrappers y utilidades para compatibilidad con la UI
func aplicar_pintura(color: Color, metallic: float=0.0, roughness: float=0.5, specular: float=0.5) -> void:
	color_actual = color
	metallic_actual = metallic
	roughness_actual = roughness
	specular_actual = specular
	aplicar_color_slot(0, color, metallic, roughness, specular)

func aplicar_pintura_secundaria(color: Color, metallic: float=0.0, roughness: float=0.5, specular: float=0.5) -> void:
	color_sec_actual = color
	metallic_sec_actual = metallic
	roughness_sec_actual = roughness
	specular_sec_actual = specular
	aplicar_color_slot(1, color, metallic, roughness, specular)

func aplicar_vidrios(color: Color, opacity: float) -> void:
	glass_color_actual = color
	glass_opacity_actual = opacity
	var parent = get_parent()
	if parent:
		_apply_glass_recursively(parent, color, opacity)

func _apply_glass_recursively(nodo: Node, color: Color, opacity: float) -> void:
	if nodo is MeshInstance3D:
		var n_name = nodo.name.to_lower()
		if "glass" in n_name or "vidrio" in n_name or "windshield" in n_name or "window" in n_name:
			for i in range(nodo.get_surface_override_material_count()):
				var mat = nodo.get_surface_override_material(i)
				if not mat and nodo.mesh:
					mat = nodo.get_active_material(i)
				if mat and mat is StandardMaterial3D:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					var c = color
					c.a = clamp(1.0 - opacity, 0.05, 1.0)
					mat.albedo_color = c
					mat.roughness = 0.05
				elif mat and mat is ShaderMaterial:
					if mat.get_shader_parameter("tint_color") != null:
						mat.set_shader_parameter("tint_color", color)
					elif mat.get_shader_parameter("albedo") != null:
						var c2 = color
						c2.a = clamp(1.0 - opacity, 0.05, 1.0)
						mat.set_shader_parameter("albedo", c2)
	for hijo in nodo.get_children():
		_apply_glass_recursively(hijo, color, opacity)

func aplicar_color_rines(color: Color, metallic: float, roughness: float) -> void:
	rims_color_actual = color
	rims_metallic_actual = metallic
	rims_roughness_actual = roughness
	var parent = get_parent()
	if not parent:
		return
	if parent.has_method("aplicar_color_rines"):
		parent.call("aplicar_color_rines", color, metallic, roughness)
	for hijo in parent.get_children():
		if hijo.name == "ControladorLlantas" or hijo.name == "controlador_llantas":
			for llanta in hijo.get_children():
				if llanta.has_method("aplicar_color_rin"):
					llanta.aplicar_color_rin(color, metallic, roughness)
				else:
					_apply_color_to_node_meshes(llanta, color, metallic, roughness)

func _apply_color_to_node_meshes(node: Node, color: Color, metallic: float, roughness: float) -> void:
	if node is MeshInstance3D:
		for i in range(node.get_surface_override_material_count()):
			var mat = node.get_surface_override_material(i)
			if not mat and node.mesh:
				mat = node.get_active_material(i)
			if mat and mat is StandardMaterial3D:
				mat.albedo_color = color
				mat.metallic = metallic
				mat.roughness = roughness
			elif mat and mat is ShaderMaterial:
				if mat.get_shader_parameter("albedo") != null:
					mat.set_shader_parameter("albedo", color)
				if mat.get_shader_parameter("metallic") != null:
					mat.set_shader_parameter("metallic", metallic)
				if mat.get_shader_parameter("roughness") != null:
					mat.set_shader_parameter("roughness", roughness)
	for c in node.get_children():
		_apply_color_to_node_meshes(c, color, metallic, roughness)

func aplicar_rines(modelo: String) -> void:
	modelo_rines = modelo
	var parent = get_parent()
	if not parent:
		return
	if parent.has_method("aplicar_tipo_ruedas"):
		parent.call("aplicar_tipo_ruedas", modelo)
	for hijo in parent.get_children():
		if hijo.name == "ControladorLlantas" or hijo.name == "controlador_llantas":
			if hijo.has_method("aplicar_modelo_rines"):
				hijo.call("aplicar_modelo_rines", modelo)
			else:
				for llanta in hijo.get_children():
					if "modelo" in llanta:
						llanta.set("modelo", modelo)
					if llanta.has_method("_update_rin_model"):
						llanta.call("_update_rin_model", modelo)


func resaltar_slot(slot_idx: int, taller: Node = null, duracion: float = 0.8, pulses: int = 2) -> void:
	# Resalta y hace parpadear las mallas que corresponden al canal/slot indicado.
	if slot_idx < 0 or slot_idx >= materiales_detectados.size():
		return
	var mat = materiales_detectados[slot_idx]
	var lista = meshes_materiales_mapeo.get(mat, [])
	if lista.size() == 0:
		return

	# Intentar enfocar con la referencia al Taller si fue provista
	var target_entry = lista[0]
	var target_mesh = target_entry.get("mesh")
	if target_mesh and is_instance_valid(target_mesh) and taller and is_instance_valid(taller):
		if taller.has_method("enfocar_nodo"):
			var dist = 3.0
			if target_mesh.mesh:
				var aabb = target_mesh.mesh.get_aabb()
				dist = max(2.0, aabb.size.length() * 0.8)
			taller.call("enfocar_nodo", target_mesh, dist, -45.0, -15.0, Vector3.ZERO)
		else:
			if "target_pivot_pos" in taller:
				taller.target_pivot_pos = target_mesh.global_position
				if "target_distance" in taller:
					taller.target_distance = 3.0

	# Ejecutar parpadeo sobre las entradas (mesh + index)
	_blink_meshes(lista, Color(1.0, 0.9, 0.25, 1.0), duracion, pulses)

func seleccionar_mesh(mesh: MeshInstance3D, taller: Node = null, duracion: float = 0.8, pulses: int = 2) -> void:
	# Busca el slot/material asociado a la malla y lo selecciona (notifica UI)
	if not mesh or not is_instance_valid(mesh):
		return
	for i in range(materiales_detectados.size()):
		var mat = materiales_detectados[i]
		var lista = meshes_materiales_mapeo.get(mat, [])
		for entry in lista:
			if entry.get("mesh") == mesh:
				# seleccionar y notificar
				resaltar_slot(i, taller, duracion, pulses)
				emit_signal("mesh_selected", i)
				return

func _blink_meshes(entries: Array, highlight: Color, duracion: float, pulses: int = 2) -> void:
	# Parpadea creando overrides temporales de material (no modifica recursos compartidos)
	var backups := []
	for entry in entries:
		var mesh = entry.get("mesh")
		var index = entry.get("index")
		if not mesh or not is_instance_valid(mesh):
			continue
		var original = null
		if index == -1:
			original = mesh.material_override
		else:
			original = mesh.get_surface_override_material(index)
		backups.append({"mesh": mesh, "index": index, "original": original})

	var step = max(0.02, duracion / float(max(1, pulses) * 2))
	for i in range(pulses):
		# Aplicar highlight (material duplicado)
		for b in backups:
			var mesh = b.mesh
			var index = b.index
			var orig = b.original
			var dup = null
			if orig:
				dup = orig.duplicate()
			else:
				dup = StandardMaterial3D.new()
			if dup is StandardMaterial3D:
				dup.albedo_color = highlight
				dup.roughness = 0.1
				dup.metallic = 0.95
			elif dup is ShaderMaterial:
				if dup.get_shader_parameter("albedo") != null:
					dup.set_shader_parameter("albedo", highlight)
			if index == -1:
				mesh.material_override = dup
			else:
				mesh.set_surface_override_material(index, dup)

		await get_tree().create_timer(step).timeout

		# Restaurar originales
		for b in backups:
			var mesh = b.mesh
			var index = b.index
			var orig = b.original
			if index == -1:
				mesh.material_override = orig
			else:
				mesh.set_surface_override_material(index, orig)

		await get_tree().create_timer(step).timeout

# ═══════════════════════════════════════════════════════════════════════
# Métodos avanzados para Personalización por Objetos e Isolation X-Ray
# ═══════════════════════════════════════════════════════════════════════

func detectar_meshes_personalizables() -> void:
	meshes_detectados.clear()
	var parent = get_parent()
	if parent:
		_detectar_meshes_recursivo(parent)

func _detectar_meshes_recursivo(nodo: Node) -> void:
	if not nodo:
		return
	if nodo.name.to_lower() == "excluir":
		return
	if nodo is MeshInstance3D:
		var n_name = nodo.name.to_lower()
		var parent_name = nodo.get_parent().name.to_lower() if nodo.get_parent() else ""
		if "llanta" in n_name or "wheel" in n_name or "rin" in n_name or "tire" in n_name or "rubber" in n_name or "caucho" in n_name:
			pass
		elif "llanta" in parent_name or "wheel" in parent_name or "rin" in parent_name or "controlador" in parent_name:
			pass
		else:
			var mats = obtener_materiales_de_mesh(nodo)
			if mats.size() > 0:
				meshes_detectados.append(nodo)
	for hijo in nodo.get_children():
		_detectar_meshes_recursivo(hijo)

func obtener_materiales_de_mesh(mesh: MeshInstance3D) -> Array:
	var result = []
	if not mesh or not is_instance_valid(mesh):
		return result
		
	var ya_agregados = []
	
	if mesh.material_override and (mesh.material_override is StandardMaterial3D or mesh.material_override is ShaderMaterial):
		var mat = mesh.material_override
		result.append({"surface_idx": -1, "material": mat})
		ya_agregados.append(mat)
		
	for i in range(mesh.get_surface_override_material_count()):
		var mat = mesh.get_surface_override_material(i)
		if mat and (mat is StandardMaterial3D or mat is ShaderMaterial):
			if not mat in ya_agregados:
				result.append({"surface_idx": i, "material": mat})
				ya_agregados.append(mat)
				
	if mesh.mesh:
		for i in range(mesh.mesh.get_surface_count()):
			var override_exists = false
			for entry in result:
				if entry["surface_idx"] == i or entry["surface_idx"] == -1:
					override_exists = true
					break
			if not override_exists:
				var mat = mesh.get_active_material(i)
				if mat and (mat is StandardMaterial3D or mat is ShaderMaterial):
					if not mat in ya_agregados:
						result.append({"surface_idx": i, "material": mat})
						ya_agregados.append(mat)
	return result

var xray_material: StandardMaterial3D = null
var xray_backups: Dictionary = {}

func _obtener_material_xray() -> StandardMaterial3D:
	if not xray_material:
		xray_material = StandardMaterial3D.new()
		xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		xray_material.albedo_color = Color(0.3, 0.4, 0.5, 0.15)
		xray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return xray_material

func activar_xray_para_mesh(mesh_seleccionado: MeshInstance3D) -> void:
	desactivar_xray()
	var xray_mat = _obtener_material_xray()
	for mesh in meshes_detectados:
		if not is_instance_valid(mesh):
			continue
		if mesh == mesh_seleccionado:
			continue
		xray_backups[mesh] = mesh.material_override
		mesh.material_override = xray_mat

func desactivar_xray() -> void:
	for mesh in xray_backups.keys():
		if is_instance_valid(mesh):
			mesh.material_override = xray_backups[mesh]
	xray_backups.clear()

func aplicar_color_a_mesh_material(mesh: MeshInstance3D, surface_idx: int, color: Color, metallic: float, roughness: float, specular: float) -> void:
	if not is_instance_valid(mesh):
		return
	var mat_original: Material = null
	if surface_idx == -1:
		mat_original = mesh.material_override
		if not mat_original:
			var mats = obtener_materiales_de_mesh(mesh)
			if mats.size() > 0:
				mat_original = mats[0]["material"]
				surface_idx = mats[0]["surface_idx"]
	else:
		mat_original = mesh.get_surface_override_material(surface_idx)
		if not mat_original and mesh.mesh:
			mat_original = mesh.get_active_material(surface_idx)
			
	if not mat_original:
		return
		
	if mat_original == xray_material:
		var backup = xray_backups.get(mesh)
		if backup:
			mat_original = backup
		else:
			return
			
	var mat_actual = mat_original
	if mat_original.resource_path != "":
		mat_actual = mat_original.duplicate()
		if surface_idx == -1:
			mesh.material_override = mat_actual
		else:
			mesh.set_surface_override_material(surface_idx, mat_actual)
			
	if mat_actual is StandardMaterial3D:
		mat_actual.albedo_color = color
		mat_actual.metallic = metallic
		mat_actual.roughness = roughness
		mat_actual.metallic_specular = specular
	elif mat_actual is ShaderMaterial:
		if mat_actual.get_shader_parameter("albedo") != null:
			mat_actual.set_shader_parameter("albedo", color)
		elif mat_actual.get_shader_parameter("paint_color") != null:
			mat_actual.set_shader_parameter("paint_color", color)
		if mat_actual.get_shader_parameter("metallic") != null:
			mat_actual.set_shader_parameter("metallic", metallic)
		if mat_actual.get_shader_parameter("roughness") != null:
			mat_actual.set_shader_parameter("roughness", roughness)
			
	if mesh in xray_backups:
		if surface_idx == -1:
			xray_backups[mesh] = mat_actual
			
	var mat_idx = materiales_detectados.find(mat_original)
	if mat_idx != -1:
		materiales_detectados[mat_idx] = mat_actual
	else:
		if not materiales_detectados.has(mat_actual):
			materiales_detectados.append(mat_actual)
			
	if not meshes_materiales_mapeo.has(mat_actual):
		meshes_materiales_mapeo[mat_actual] = []
	var found = false
	for entry in meshes_materiales_mapeo[mat_actual]:
		if entry["mesh"] == mesh and entry["index"] == surface_idx:
			found = true
			break
	if not found:
		meshes_materiales_mapeo[mat_actual].append({"mesh": mesh, "index": surface_idx})
