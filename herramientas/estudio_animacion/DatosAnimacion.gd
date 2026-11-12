class_name DatosAnimacion
extends RefCounted

## Utilidades y estructuras para el controlador y estudio de animación 3D.
## Soporta modelos con Skeleton3D (humanoide Mixamo, Godot standard o personalizados).

# ---------------------------------------------------------------------------
# BÚSQUEDA DE NODOS
# ---------------------------------------------------------------------------

static func buscar_esqueleto(raiz: Node) -> Skeleton3D:
	if raiz is Skeleton3D:
		return raiz
	for hijo in raiz.get_children():
		var encontrado = buscar_esqueleto(hijo)
		if encontrado:
			return encontrado
	return null

static func buscar_animation_player(raiz: Node) -> AnimationPlayer:
	if raiz is AnimationPlayer:
		return raiz
	for hijo in raiz.get_children():
		var encontrado = buscar_animation_player(hijo)
		if encontrado:
			return encontrado
	return null

# ---------------------------------------------------------------------------
# MAPEO Y ESPEJO DE HUESOS
# ---------------------------------------------------------------------------

static func obtener_hueso_espejo(nombre: String) -> String:
	var pares: Array = [
		["Left", "Right"],
		["left", "right"],
		["_L", "_R"],
		["_l", "_r"],
		[".L", ".R"],
		[".l", ".r"],
		["Izq", "Der"],
		["izq", "der"]
	]
	
	for par in pares:
		var l: String = par[0]
		var r: String = par[1]
		if l in nombre and not r in nombre:
			return nombre.replace(l, r)
		elif r in nombre and not l in nombre:
			return nombre.replace(r, l)
			
	return nombre

static func espejar_rotacion_euler(euler_deg: Vector3) -> Vector3:
	# Para simetría bilateral estándar:
	# Pitch (X) = inclinación adelante/atrás -> se preserva
	# Yaw (Y) = rotación axial / giro -> se invierte
	# Roll (Z) = abducción / aducción -> se invierte
	return Vector3(euler_deg.x, -euler_deg.y, -euler_deg.z)

static func espejar_pose(pose: Dictionary) -> Dictionary:
	var pose_espejada: Dictionary = {}
	var rotaciones: Dictionary = pose.get("rotaciones", {})
	var rot_espejadas: Dictionary = {}
	
	for nombre_hueso in rotaciones.keys():
		var hueso_opuesto = obtener_hueso_espejo(nombre_hueso)
		var q: Quaternion = rotaciones[nombre_hueso]
		var euler = q.get_euler()
		var euler_deg = Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))
		var euler_esp = espejar_rotacion_euler(euler_deg)
		var q_esp = Quaternion.from_euler(Vector3(deg_to_rad(euler_esp.x), deg_to_rad(euler_esp.y), deg_to_rad(euler_esp.z)))
		rot_espejadas[hueso_opuesto] = q_esp
		
	pose_espejada["rotaciones"] = rot_espejadas
	
	# Espejo de posición de raíz (Hips): X se invierte, Y y Z se mantienen
	if pose.has("root_pos"):
		var r_pos: Vector3 = pose["root_pos"]
		pose_espejada["root_pos"] = Vector3(-r_pos.x, r_pos.y, r_pos.z)
	else:
		pose_espejada["root_pos"] = Vector3.ZERO
		
	return pose_espejada

# ---------------------------------------------------------------------------
# CAPTURA Y APLICACIÓN DE POSES
# ---------------------------------------------------------------------------

static func capturar_pose_esqueleto(esqueleto: Skeleton3D, hueso_raiz_nombre: String = "") -> Dictionary:
	var pose: Dictionary = {
		"rotaciones": {},
		"root_pos": Vector3.ZERO
	}
	if not esqueleto:
		return pose
		
	for i in range(esqueleto.get_bone_count()):
		var nombre_hueso = esqueleto.get_bone_name(i)
		var rot = esqueleto.get_bone_pose_rotation(i)
		pose["rotaciones"][nombre_hueso] = rot
		
	# Capturar posición de raíz
	var idx_raiz = -1
	if hueso_raiz_nombre != "":
		idx_raiz = esqueleto.find_bone(hueso_raiz_nombre)
	if idx_raiz < 0:
		idx_raiz = esqueleto.find_bone("mixamorig_Hips")
	if idx_raiz < 0:
		idx_raiz = esqueleto.find_bone("Hips")
	if idx_raiz < 0 and esqueleto.get_bone_count() > 0:
		idx_raiz = 0
		
	if idx_raiz >= 0:
		pose["root_pos"] = esqueleto.get_bone_pose_position(idx_raiz)
		
	return pose

static func aplicar_pose_a_esqueleto(esqueleto: Skeleton3D, pose: Dictionary, hueso_raiz_nombre: String = ""):
	if not esqueleto or not pose:
		return
		
	var rotaciones: Dictionary = pose.get("rotaciones", {})
	for nombre_hueso in rotaciones.keys():
		var idx = esqueleto.find_bone(nombre_hueso)
		if idx >= 0:
			esqueleto.set_bone_pose_rotation(idx, rotaciones[nombre_hueso])
			
	if pose.has("root_pos"):
		var idx_raiz = -1
		if hueso_raiz_nombre != "":
			idx_raiz = esqueleto.find_bone(hueso_raiz_nombre)
		if idx_raiz < 0:
			idx_raiz = esqueleto.find_bone("mixamorig_Hips")
		if idx_raiz < 0:
			idx_raiz = esqueleto.find_bone("Hips")
		if idx_raiz < 0 and esqueleto.get_bone_count() > 0:
			idx_raiz = 0
			
		if idx_raiz >= 0:
			esqueleto.set_bone_pose_position(idx_raiz, pose["root_pos"])

# ---------------------------------------------------------------------------
# INTERPOLACIÓN ENTRE KEYFRAMES
# ---------------------------------------------------------------------------

static func interpolar_poses(pose_a: Dictionary, pose_b: Dictionary, factor: float) -> Dictionary:
	var f = clampf(factor, 0.0, 1.0)
	var resultado: Dictionary = {
		"rotaciones": {},
		"root_pos": Vector3.ZERO
	}
	
	var rot_a: Dictionary = pose_a.get("rotaciones", {})
	var rot_b: Dictionary = pose_b.get("rotaciones", {})
	
	var todos_huesos = {}
	for k in rot_a.keys():
		todos_huesos[k] = true
	for k in rot_b.keys():
		todos_huesos[k] = true
		
	for h in todos_huesos.keys():
		var qa = rot_a.get(h, Quaternion.IDENTITY)
		var qb = rot_b.get(h, Quaternion.IDENTITY)
		resultado["rotaciones"][h] = qa.slerp(qb, f)
		
	var pos_a: Vector3 = pose_a.get("root_pos", Vector3.ZERO)
	var pos_b: Vector3 = pose_b.get("root_pos", Vector3.ZERO)
	resultado["root_pos"] = pos_a.lerp(pos_b, f)
	
	return resultado

static func obtener_pose_en_tiempo(keyframes: Array, tiempo: float, duracion: float, loop: bool) -> Dictionary:
	if keyframes.is_empty():
		return {"rotaciones": {}, "root_pos": Vector3.ZERO}
		
	if keyframes.size() == 1:
		return keyframes[0].get("pose", {})
		
	# Ordenar keyframes por tiempo
	var kfs = keyframes.duplicate()
	kfs.sort_custom(func(a, b): return a.get("tiempo", 0.0) < b.get("tiempo", 0.0))
	
	var t = tiempo
	if loop and duracion > 0.0:
		t = fmod(t, duracion)
		if t < 0.0:
			t += duracion
			
	# Si antes del primer keyframe
	if t <= kfs[0]["tiempo"]:
		if loop and duracion > 0.0:
			# Interpolar entre el último y el primero
			var ultimo = kfs[-1]
			var primero = kfs[0]
			var lapso = (duracion - ultimo["tiempo"]) + primero["tiempo"]
			var delta = (t + duracion - ultimo["tiempo"]) if lapso > 0.0 else 0.0
			var factor = clampf(delta / maxf(lapso, 0.0001), 0.0, 1.0)
			return interpolar_poses(ultimo["pose"], primero["pose"], factor)
		return kfs[0]["pose"]
		
	# Si después del último keyframe
	if t >= kfs[-1]["tiempo"]:
		if loop and duracion > 0.0:
			var ultimo = kfs[-1]
			var primero = kfs[0]
			var lapso = (duracion - ultimo["tiempo"]) + primero["tiempo"]
			var delta = (t - ultimo["tiempo"]) if lapso > 0.0 else 0.0
			var factor = clampf(delta / maxf(lapso, 0.0001), 0.0, 1.0)
			return interpolar_poses(ultimo["pose"], primero["pose"], factor)
		return kfs[-1]["pose"]
		
	# Buscar el segmento [kf_i, kf_i+1]
	for i in range(kfs.size() - 1):
		var kf_a = kfs[i]
		var kf_b = kfs[i + 1]
		if t >= kf_a["tiempo"] and t <= kf_b["tiempo"]:
			var lapso = kf_b["tiempo"] - kf_a["tiempo"]
			var factor = (t - kf_a["tiempo"]) / maxf(lapso, 0.0001)
			return interpolar_poses(kf_a["pose"], kf_b["pose"], factor)
			
	return kfs[-1]["pose"]

# ---------------------------------------------------------------------------
# EXPORTACIÓN E IMPORTACIÓN DE ANIMATION DE GODOT
# ---------------------------------------------------------------------------

static func crear_recurso_animacion(nombre_anim: String, keyframes: Array, duracion: float, loop: bool, anim_player: AnimationPlayer, esqueleto: Skeleton3D, hueso_raiz_nombre: String = "") -> Animation:
	var anim = Animation.new()
	anim.resource_name = nombre_anim
	anim.length = maxf(duracion, 0.1)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	
	if keyframes.is_empty() or not esqueleto:
		return anim
		
	# Determinar la ruta relativa desde AnimationPlayer.root_node hacia el Skeleton3D
	var ruta_esqueleto = "Armature/Skeleton3D"
	if anim_player and esqueleto:
		var nodo_raiz_anim = anim_player.get_node_or_null(anim_player.root_node)
		if nodo_raiz_anim:
			ruta_esqueleto = String(nodo_raiz_anim.get_path_to(esqueleto))
			
	# Identificar hueso raíz
	var nombre_raiz = hueso_raiz_nombre
	if nombre_raiz == "":
		if esqueleto.find_bone("mixamorig_Hips") >= 0:
			nombre_raiz = "mixamorig_Hips"
		elif esqueleto.find_bone("Hips") >= 0:
			nombre_raiz = "Hips"
		elif esqueleto.get_bone_count() > 0:
			nombre_raiz = esqueleto.get_bone_name(0)
			
	# Ordenar keyframes
	var kfs = keyframes.duplicate()
	kfs.sort_custom(func(a, b): return a.get("tiempo", 0.0) < b.get("tiempo", 0.0))
	
	# 1. Pistas de rotación para cada hueso que aparece en keyframes
	var todos_huesos: Dictionary = {}
	for kf in kfs:
		var rots: Dictionary = kf.get("pose", {}).get("rotaciones", {})
		for b_name in rots.keys():
			todos_huesos[b_name] = true
			
	for b_name in todos_huesos.keys():
		var idx_track = anim.add_track(Animation.TYPE_ROTATION_3D)
		var track_path = NodePath(ruta_esqueleto + ":" + b_name)
		anim.track_set_path(idx_track, track_path)
		anim.track_set_interpolation_type(idx_track, Animation.INTERPOLATION_LINEAR)
		
		for kf in kfs:
			var t: float = kf.get("tiempo", 0.0)
			var rots: Dictionary = kf.get("pose", {}).get("rotaciones", {})
			var q: Quaternion = rots.get(b_name, Quaternion.IDENTITY)
			anim.rotation_track_insert_key(idx_track, t, q)
			
	# 2. Pista de posición para el hueso raíz
	if nombre_raiz != "":
		var idx_track_pos = anim.add_track(Animation.TYPE_POSITION_3D)
		var track_path_pos = NodePath(ruta_esqueleto + ":" + nombre_raiz)
		anim.track_set_path(idx_track_pos, track_path_pos)
		anim.track_set_interpolation_type(idx_track_pos, Animation.INTERPOLATION_LINEAR)
		
		for kf in kfs:
			var t: float = kf.get("tiempo", 0.0)
			var pos_raiz: Vector3 = kf.get("pose", {}).get("root_pos", Vector3.ZERO)
			anim.position_track_insert_key(idx_track_pos, t, pos_raiz)
			
	return anim

static func guardar_animacion_en_disco(anim: Animation, ruta_completa: String) -> Error:
	if not anim:
		return ERR_INVALID_DATA
		
	var dir = ruta_completa.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		
	var err = ResourceSaver.save(anim, ruta_completa)
	if err != OK:
		push_error("Error al guardar recurso de animación en: %s (código: %d)" % [ruta_completa, err])
	return err

# ---------------------------------------------------------------------------
# BIBLIOTECA DE POSES PREDEFINIDAS
# ---------------------------------------------------------------------------

static func q_deg(x: float, y: float, z: float) -> Quaternion:
	return Quaternion.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z)))

static func obtener_poses_predefinidas() -> Dictionary:
	var presets: Dictionary = {}
	
	# 1. T-Pose (Rest neutro)
	presets["T-Pose (Rest)"] = {
		"rotaciones": {
			"mixamorig_LeftArm": q_deg(0, 0, 0),
			"mixamorig_RightArm": q_deg(0, 0, 0),
			"mixamorig_LeftForeArm": q_deg(0, 0, 0),
			"mixamorig_RightForeArm": q_deg(0, 0, 0),
			"mixamorig_LeftUpLeg": q_deg(0, 0, 0),
			"mixamorig_RightUpLeg": q_deg(0, 0, 0),
			"mixamorig_Spine": q_deg(0, 0, 0),
			"mixamorig_Head": q_deg(0, 0, 0)
		},
		"root_pos": Vector3.ZERO
	}
	
	# 2. A-Pose
	presets["A-Pose"] = {
		"rotaciones": {
			"mixamorig_LeftArm": q_deg(0, 0, -42),
			"mixamorig_RightArm": q_deg(0, 0, 42),
			"mixamorig_LeftForeArm": q_deg(0, 0, 0),
			"mixamorig_RightForeArm": q_deg(0, 0, 0),
			"mixamorig_LeftUpLeg": q_deg(0, 0, 6),
			"mixamorig_RightUpLeg": q_deg(0, 0, -6),
			"mixamorig_Spine": q_deg(2, 0, 0)
		},
		"root_pos": Vector3.ZERO
	}
	
	# 3. Reposo / Idle Relajado
	presets["Idle Relajado"] = {
		"rotaciones": {
			"mixamorig_LeftArm": q_deg(8, 0, -68),
			"mixamorig_RightArm": q_deg(8, 0, 68),
			"mixamorig_LeftForeArm": q_deg(0, 15, -12),
			"mixamorig_RightForeArm": q_deg(0, -15, 12),
			"mixamorig_LeftUpLeg": q_deg(-2, 0, 4),
			"mixamorig_RightUpLeg": q_deg(2, 0, -8),
			"mixamorig_Spine": q_deg(-3, 0, 0),
			"mixamorig_Spine1": q_deg(4, 0, 0),
			"mixamorig_Head": q_deg(-2, 0, 0)
		},
		"root_pos": Vector3(0, -0.02, 0)
	}
	
	# 4. Caminata: Contacto
	presets["Caminar: Contacto"] = {
		"rotaciones": {
			"mixamorig_LeftUpLeg": q_deg(28, 0, 0),
			"mixamorig_LeftLeg": q_deg(5, 0, 0),
			"mixamorig_LeftFoot": q_deg(-15, 0, 0),
			"mixamorig_RightUpLeg": q_deg(-25, 0, 0),
			"mixamorig_RightLeg": q_deg(15, 0, 0),
			"mixamorig_RightFoot": q_deg(10, 0, 0),
			"mixamorig_LeftArm": q_deg(-22, 0, -55),
			"mixamorig_LeftForeArm": q_deg(0, 20, 0),
			"mixamorig_RightArm": q_deg(26, 0, 55),
			"mixamorig_RightForeArm": q_deg(0, -25, 0),
			"mixamorig_Spine": q_deg(5, 6, 0)
		},
		"root_pos": Vector3(0, -0.04, 0)
	}
	
	# 5. Caminata: Pase
	presets["Caminar: Pase"] = {
		"rotaciones": {
			"mixamorig_LeftUpLeg": q_deg(-3, 0, 0),
			"mixamorig_LeftLeg": q_deg(4, 0, 0),
			"mixamorig_LeftFoot": q_deg(0, 0, 0),
			"mixamorig_RightUpLeg": q_deg(18, 0, 0),
			"mixamorig_RightLeg": q_deg(45, 0, 0),
			"mixamorig_RightFoot": q_deg(12, 0, 0),
			"mixamorig_LeftArm": q_deg(4, 0, -65),
			"mixamorig_LeftForeArm": q_deg(0, 10, 0),
			"mixamorig_RightArm": q_deg(-2, 0, 65),
			"mixamorig_RightForeArm": q_deg(0, -10, 0),
			"mixamorig_Spine": q_deg(2, -2, 0)
		},
		"root_pos": Vector3(0, 0.02, 0)
	}
	
	# 6. Carrera: Impulso
	presets["Correr: Impulso"] = {
		"rotaciones": {
			"mixamorig_LeftUpLeg": q_deg(48, 0, 0),
			"mixamorig_LeftLeg": q_deg(35, 0, 0),
			"mixamorig_RightUpLeg": q_deg(-42, 0, 0),
			"mixamorig_RightLeg": q_deg(60, 0, 0),
			"mixamorig_LeftArm": q_deg(-45, 0, -45),
			"mixamorig_LeftForeArm": q_deg(0, 65, 0),
			"mixamorig_RightArm": q_deg(50, 0, 45),
			"mixamorig_RightForeArm": q_deg(0, -70, 0),
			"mixamorig_Spine": q_deg(16, 8, 0)
		},
		"root_pos": Vector3(0, 0.05, 0)
	}
	
	# 7. Sentado
	presets["Sentado"] = {
		"rotaciones": {
			"mixamorig_LeftUpLeg": q_deg(82, 0, 8),
			"mixamorig_RightUpLeg": q_deg(82, 0, -8),
			"mixamorig_LeftLeg": q_deg(-84, 0, 0),
			"mixamorig_RightLeg": q_deg(-84, 0, 0),
			"mixamorig_LeftArm": q_deg(22, 0, -45),
			"mixamorig_RightArm": q_deg(22, 0, 45),
			"mixamorig_LeftForeArm": q_deg(0, 35, 0),
			"mixamorig_RightForeArm": q_deg(0, -35, 0),
			"mixamorig_Spine": q_deg(4, 0, 0)
		},
		"root_pos": Vector3(0, -0.48, -0.05)
	}
	
	# 8. Conducir Vehículo
	presets["Conducir"] = {
		"rotaciones": {
			"mixamorig_LeftUpLeg": q_deg(72, 0, 12),
			"mixamorig_RightUpLeg": q_deg(72, 0, -12),
			"mixamorig_LeftLeg": q_deg(-68, 0, 0),
			"mixamorig_RightLeg": q_deg(-68, 0, 0),
			"mixamorig_LeftArm": q_deg(48, 14, -28),
			"mixamorig_RightArm": q_deg(48, -14, 28),
			"mixamorig_LeftForeArm": q_deg(0, 42, -15),
			"mixamorig_RightForeArm": q_deg(0, -42, 15),
			"mixamorig_Spine": q_deg(8, 0, 0),
			"mixamorig_Head": q_deg(2, 0, 0)
		},
		"root_pos": Vector3(0, -0.42, -0.02)
	}
	
	# 9. Saludo (Wave)
	presets["Saludar"] = {
		"rotaciones": {
			"mixamorig_RightShoulder": q_deg(15, 0, 10),
			"mixamorig_RightArm": q_deg(-10, 0, 130),
			"mixamorig_RightForeArm": q_deg(0, -60, -35),
			"mixamorig_RightHand": q_deg(0, 0, 20),
			"mixamorig_LeftArm": q_deg(8, 0, -70),
			"mixamorig_Spine": q_deg(-2, -5, 0),
			"mixamorig_Head": q_deg(4, -8, 0)
		},
		"root_pos": Vector3.ZERO
	}
	
	# 10. Guardia de Combate
	presets["Guardia Combate"] = {
		"rotaciones": {
			"mixamorig_LeftUpLeg": q_deg(18, 12, 0),
			"mixamorig_RightUpLeg": q_deg(-18, -12, 0),
			"mixamorig_LeftLeg": q_deg(24, 0, 0),
			"mixamorig_RightLeg": q_deg(22, 0, 0),
			"mixamorig_LeftArm": q_deg(35, 20, -25),
			"mixamorig_LeftForeArm": q_deg(0, 85, 0),
			"mixamorig_RightArm": q_deg(25, -15, 25),
			"mixamorig_RightForeArm": q_deg(0, -95, 0),
			"mixamorig_Spine": q_deg(8, -12, 0),
			"mixamorig_Head": q_deg(-4, 10, 0)
		},
		"root_pos": Vector3(0, -0.08, 0)
	}
	
	return presets
