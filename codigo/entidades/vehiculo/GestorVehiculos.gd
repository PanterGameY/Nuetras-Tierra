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


func _ajustar_salida_sobre_suelo(jugador: Node3D, vehiculo: Node3D, pos: Vector3) -> Vector3:
	var mundo := jugador.get_world_3d()
	if not mundo or not mundo.direct_space_state:
		return pos
	var space := mundo.direct_space_state
	var excl: Array[RID] = []
	if jugador is CollisionObject3D:
		excl.append((jugador as CollisionObject3D).get_rid())
	if is_instance_valid(vehiculo) and vehiculo is CollisionObject3D:
		excl.append((vehiculo as CollisionObject3D).get_rid())
	var ref_y: float = pos.y
	if is_instance_valid(vehiculo):
		ref_y = maxf(ref_y, vehiculo.global_position.y)
	var y_origen: float = ref_y + 10.0
	var y_fin: float = ref_y - 25.0
	for _i in range(6):
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(pos.x, y_origen, pos.z),
			Vector3(pos.x, y_fin, pos.z),
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
			var out := pos
			out.y = (res["position"] as Vector3).y + 0.15
			return out
		excl.append(res["rid"])
		y_origen = (res["position"] as Vector3).y - 0.05
	return pos
