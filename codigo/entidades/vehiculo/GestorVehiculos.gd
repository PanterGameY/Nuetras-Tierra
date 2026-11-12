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

	# 3. Posicionar al jugador en el punto de salida
	if posicion_salida != Vector3.ZERO:
		jugador.global_position = posicion_salida
	elif is_instance_valid(vehiculo):
		var zona = vehiculo.find_child("ZonaEntrada", true, false)
		if zona and is_instance_valid(zona):
			jugador.global_position = zona.global_position - (vehiculo.global_transform.basis.x.normalized() * 0.6)
		else:
			jugador.global_position = vehiculo.global_position - (vehiculo.global_transform.basis.x.normalized() * 2.2)

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
