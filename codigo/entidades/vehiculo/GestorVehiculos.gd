extends Node

# ════════════════════════════════════════════════════════════════════════════
# GestorVehiculos.gd — Sistema Central de Gestión de Conducción y Pasajeros
# Controla la entrada y salida de vehículos por parte del jugador.
# ════════════════════════════════════════════════════════════════════════════

var vehiculo_actual: Node3D = null

func subir_jugador_a_vehiculo(jugador: Node3D, vehiculo: Node3D) -> void:
	if not is_instance_valid(jugador) or not is_instance_valid(vehiculo):
		return
	vehiculo_actual = vehiculo
	if jugador.has_method("ocultar_interfaz_pie"):
		jugador.ocultar_interfaz_pie()
	# Sincronizar estado en el jugador si este no había iniciado la subida directamente
	if jugador.has_method("_subir_al_vehiculo") and not jugador.get("_conduciendo"):
		jugador._subir_al_vehiculo(vehiculo)
	elif jugador.has_method("entrar_al_vehiculo") and not jugador.get("esta_conduciendo"):
		jugador.entrar_al_vehiculo(vehiculo)


func bajar_jugador_de_vehiculo(jugador: Node3D, vehiculo: Node3D, posicion_salida: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(jugador):
		return
	
	vehiculo_actual = null

	# 1. Notificar al script del jugador (jugador3D) para que ejecute su salida limpia
	if jugador.has_method("salir_del_vehiculo"):
		jugador.salir_del_vehiculo()
	elif jugador.has_method("_salir_del_vehiculo"):
		jugador._salir_del_vehiculo()

	# 2. Desactivar forzosamente variables internas de conducción en el jugador
	if "_conduciendo" in jugador:
		jugador.set("_conduciendo", false)
	if "_vehiculo_actual" in jugador:
		jugador.set("_vehiculo_actual", null)

	# 3. Posicionar al jugador en el punto de salida seguro sobre el suelo estático
	var destino_salida: Vector3 = posicion_salida
	if destino_salida == Vector3.ZERO and is_instance_valid(vehiculo):
		var zona = vehiculo.find_child("ZonaEntrada", true, false)
		if zona and is_instance_valid(zona):
			destino_salida = zona.global_position - (vehiculo.global_transform.basis.x.normalized() * 0.6)
		else:
			destino_salida = vehiculo.global_position - (vehiculo.global_transform.basis.x.normalized() * 2.2)

	if destino_salida != Vector3.ZERO:
		destino_salida = _ajustar_salida_sobre_suelo(jugador, vehiculo, destino_salida)
		if jugador is CharacterBody3D:
			(jugador as CharacterBody3D).velocity = Vector3.ZERO
		jugador.global_position = destino_salida

	# 4. Restaurar estado de procesamiento y visibilidad del nodo
	jugador.show()
	jugador.process_mode = Node.PROCESS_MODE_INHERIT
	if jugador.has_method("set_physics_process"):
		jugador.set_physics_process(true)
	if jugador.has_method("set_process"):
		jugador.set_process(true)

	# 5. Asegurar visibilidad del modelo 3D del personaje
	var modelo = jugador.get_node_or_null("RootNode")
	if not modelo:
		modelo = jugador.find_child("RootNode", true, false)
	if modelo:
		modelo.show()

	# 6. Reactivar la forma de colisión del jugador
	var col = jugador.find_child("CollisionShape3D", true, false)
	if col and is_instance_valid(col) and col is CollisionShape3D:
		col.disabled = false
	if jugador.has_method("_verificar_seguridad_mapa"):
		jugador.call("_verificar_seguridad_mapa", true)

	# 7. Reactivar interfaz táctil a pie (UIpie) y sus controles
	if jugador.has_method("mostrar_interfaz_pie"):
		jugador.mostrar_interfaz_pie()
	else:
		var ui_pie = jugador.find_child("UIpie", true, false)
		if is_instance_valid(ui_pie):
			ui_pie.process_mode = Node.PROCESS_MODE_INHERIT
			ui_pie.visible = true
			var controles = ui_pie.get_node_or_null("Controles")
			if controles:
				controles.visible = true

	# 8. Resetear la animación a Idle (evita que se quede atascado en "Conducir")
	if jugador.has_method("_reproducir_anim"):
		jugador.call("_reproducir_anim", "Idle")
	var anim_player = jugador.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player and is_instance_valid(anim_player) and anim_player.has_animation("Idle"):
		anim_player.play("Idle")

	# 9. Restaurar cámara activa al jugador
	if jugador.has_method("restaurar_camara_salida_vehiculo"):
		jugador.restaurar_camara_salida_vehiculo()
	else:
		var cam = jugador.find_child("Camera3D", true, false)
		if cam and cam is Camera3D:
			cam.make_current()


func _raycast_estatico_vertical(nodo_ref: Node3D, xz: Vector3, y_desde: float, y_hasta: float, excl_extra: Array[RID] = []) -> Dictionary:
	if not is_instance_valid(nodo_ref) or not nodo_ref.is_inside_tree():
		return {}
	var mundo := nodo_ref.get_world_3d()
	if not mundo or not mundo.direct_space_state:
		return {}
	var space := mundo.direct_space_state
	var excl: Array[RID] = excl_extra.duplicate()
	if nodo_ref is CollisionObject3D:
		excl.append((nodo_ref as CollisionObject3D).get_rid())
	var y_origen: float = y_desde
	for _i in range(6):
		if y_origen <= y_hasta:
			break
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(xz.x, y_origen, xz.z),
			Vector3(xz.x, y_hasta, xz.z),
			1,
			excl
		)
		var res := space.intersect_ray(q)
		if res.is_empty():
			break
		var hit_col = res["collider"]
		# Saltar vehículos u otros cuerpos dinámicos para encontrar la vía/suelo real
		if hit_col is VehicleBody3D or hit_col is RigidBody3D or hit_col is CharacterBody3D:
			excl.append(res["rid"])
			y_origen = (res["position"] as Vector3).y - 0.05
			continue
		var norm: Vector3 = res["normal"]
		if norm.y >= 0.45:
			return res
		excl.append(res["rid"])
		y_origen = (res["position"] as Vector3).y - 0.05
	return {}


func _ajustar_salida_sobre_suelo(jugador: Node3D, vehiculo: Node3D, pos: Vector3) -> Vector3:
	var excl: Array[RID] = []
	if is_instance_valid(vehiculo) and vehiculo is CollisionObject3D:
		excl.append((vehiculo as CollisionObject3D).get_rid())
	var ref_y: float = pos.y
	if is_instance_valid(vehiculo):
		ref_y = maxf(ref_y, vehiculo.global_position.y)
	var res := _raycast_estatico_vertical(jugador, pos, ref_y + 10.0, ref_y - 25.0, excl)
	if not res.is_empty():
		var out := pos
		out.y = (res["position"] as Vector3).y + 0.15
		return out
	return pos


func _es_via_o_suelo_estatico(col: Object) -> bool:
	if not (col is StaticBody3D or col is CSGShape3D):
		return false
	var nodo := col as Node
	var nom := nodo.name.to_lower()
	var nom_p := nodo.get_parent().name.to_lower() if nodo.get_parent() else ""
	for kw in ["carretera", "acera", "trocha", "asfalto", "calle", "rotonda", "edificio_base", "suelo", "piso", "grid", "terreno", "lote"]:
		if nom.contains(kw) or nom_p.contains(kw):
			return true
	return false


## Protege cualquier vehículo jugable contra caída al vacío o traspaso bajo carreteras
func asegurar_vehiculo_sobre_mapa(vehiculo: RigidBody3D, pos_segura: Vector3) -> Vector3:
	if not is_instance_valid(vehiculo) or not vehiculo.is_inside_tree():
		return pos_segura

	var pos := vehiculo.global_position
	var necesita_chequeo := (pos.y < -1.5) or (vehiculo.linear_velocity.y < -6.0) or (Engine.get_physics_frames() % 10 == 0)
	if not necesita_chequeo:
		return pos_segura

	# 1. ¿Hay una carretera/suelo encima del techo del vehículo (+2.2m a +40m)?
	var res_arriba := _raycast_estatico_vertical(vehiculo, pos, pos.y + 40.0, pos.y + 2.2)
	var atrapado_bajo_via := (not res_arriba.is_empty()) and _es_via_o_suelo_estatico(res_arriba["collider"])

	# 2. ¿Está cayendo en vacío puro (sin suelo debajo dentro de 35m)?
	var res_abajo := _raycast_estatico_vertical(vehiculo, pos, pos.y + 0.8, pos.y - 35.0)
	var en_vacio := res_abajo.is_empty() and pos.y < -0.8

	if atrapado_bajo_via or en_vacio or pos.y < -2.8:
		vehiculo.linear_velocity = Vector3.ZERO
		vehiculo.angular_velocity = Vector3.ZERO
		vehiculo.global_rotation.x = 0.0
		vehiculo.global_rotation.z = 0.0
		if not res_arriba.is_empty():
			vehiculo.global_position.y = (res_arriba["position"] as Vector3).y + 0.75
			return vehiculo.global_position
		var res_top := _raycast_estatico_vertical(vehiculo, pos, 90.0, -30.0)
		if not res_top.is_empty():
			vehiculo.global_position.y = (res_top["position"] as Vector3).y + 0.75
			return vehiculo.global_position
		if pos_segura != Vector3.ZERO:
			vehiculo.global_position = pos_segura + Vector3(0.0, 0.75, 0.0)
			return vehiculo.global_position
		vehiculo.global_position = Vector3(33.8119, 1.35, 783.8547)
		return vehiculo.global_position

	# Guardar última posición válida cuando tiene suelo cercano debajo y no hay vía encima
	if not res_abajo.is_empty() and pos.y - (res_abajo["position"] as Vector3).y < 2.2 and pos.y >= -1.5:
		return pos
	return pos_segura


func _obtener_ruta_escena_actual(nodo: Node = null) -> String:
	var tree := nodo.get_tree() if is_instance_valid(nodo) and nodo.is_inside_tree() else get_tree()
	if is_instance_valid(nodo) and tree and tree.root:
		var anc: Node = nodo
		while anc and anc.get_parent() != tree.root:
			anc = anc.get_parent()
		if anc and anc.scene_file_path != "":
			return anc.scene_file_path
	if tree and tree.current_scene and tree.current_scene.scene_file_path != "":
		return tree.current_scene.scene_file_path
	return ""


func _es_escena_prueba_persistencia(nodo: Node = null) -> bool:
	var sp := _obtener_ruta_escena_actual(nodo).to_lower()
	if sp == "":
		return false
	return ("academia_licencias" in sp) or ("/pruebas/" in sp)


func clave_ubicacion_vehiculo(vehiculo: Node3D) -> String:
	if not is_instance_valid(vehiculo):
		return ""
	var ruta := str(vehiculo.scene_file_path)
	if ruta == "":
		return str(vehiculo.name)
	if vehiculo.is_in_group("remolque") or vehiculo.is_in_group("trailers"):
		return "%s::%s" % [ruta, str(vehiculo.name)]
	return ruta


func guardar_ubicacion_vehiculo(vehiculo: Node3D, escribir_disco: bool = true) -> void:
	if not is_instance_valid(vehiculo) or not vehiculo.is_inside_tree():
		return
	if _es_escena_prueba_persistencia(vehiculo):
		return
	var datos := get_node_or_null("/root/DatosUsuario")
	if not datos or typeof(datos.vehiculos_posiciones) != TYPE_DICTIONARY:
		return
	var clave := clave_ubicacion_vehiculo(vehiculo)
	if clave == "":
		return
	var cur_sc := _obtener_ruta_escena_actual(vehiculo)
	datos.vehiculos_posiciones[clave] = {
		"pos": vehiculo.global_position,
		"rot": vehiculo.global_rotation,
		"scene": cur_sc,
		"nombre": str(vehiculo.name)
	}
	if escribir_disco:
		datos.save_local(true)


func restaurar_ubicacion_vehiculo(vehiculo: Node3D) -> bool:
	if not is_instance_valid(vehiculo) or not vehiculo.is_inside_tree():
		return false
	if _es_escena_prueba_persistencia(vehiculo):
		return false
	var datos := get_node_or_null("/root/DatosUsuario")
	if not datos or typeof(datos.vehiculos_posiciones) != TYPE_DICTIONARY:
		return false
	var clave := clave_ubicacion_vehiculo(vehiculo)
	if clave == "" or not datos.vehiculos_posiciones.has(clave):
		return false
	var entry = datos.vehiculos_posiciones[clave]
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var cur_sc := _obtener_ruta_escena_actual(vehiculo)
	var entry_nombre := str(entry.get("nombre", ""))
	if str(entry.get("scene", "")) != cur_sc:
		return false
	if entry_nombre != "" and entry_nombre != str(vehiculo.name):
		return false
	if not (entry.get("pos") is Vector3):
		return false
	vehiculo.global_position = entry["pos"]
	if entry.get("rot") is Vector3:
		vehiculo.global_rotation = entry["rot"]
	if vehiculo is RigidBody3D:
		(vehiculo as RigidBody3D).linear_velocity = Vector3.ZERO
		(vehiculo as RigidBody3D).angular_velocity = Vector3.ZERO
	return true


func calcular_punto_salida_seguro(jugador: Node3D, vehiculo: Node3D) -> Vector3:
	if not is_instance_valid(vehiculo):
		return jugador.global_position if is_instance_valid(jugador) else Vector3.ZERO
	var zona := vehiculo.find_child("ZonaEntrada", true, false) as Area3D
	var destino: Vector3
	if zona and is_instance_valid(zona):
		destino = zona.global_position - (vehiculo.global_transform.basis.x.normalized() * 0.7)
		destino.y = zona.global_position.y + 0.1
	else:
		destino = vehiculo.global_position - (vehiculo.global_transform.basis.x.normalized() * 2.4)
		destino.y = vehiculo.global_position.y + 0.2
	return _ajustar_salida_sobre_suelo(jugador, vehiculo, destino)
