@tool
extends EditorScenePostImport

# Longitud del rayo de suspensión hacia abajo (en metros)
const SUSPENSION_REST_LENGTH: float = 0.65
const RUEDA_TRAILER_SCRIPT_PATH: String = "res://modelos3d/vehiculos/Trailers/escenas/ruedatrailer.gd"

func _post_import(scene: Node) -> Object:
	var configurados := 0

	# 1. Soporte para automóviles (nodo 'Wheels' con 'Wheel_*')
	var wheels_parent = scene.find_child("Wheels", true, false)
	if wheels_parent:
		var wheel_names = [
			"Wheel_Front_Left",
			"Wheel_Front_Right",
			"Wheel_Rear_Left",
			"Wheel_Rear_Right"
		]
		for w_name in wheel_names:
			var wheel_node = wheels_parent.find_child(w_name, false, false)
			if not wheel_node:
				continue
			var raycast = RayCast3D.new()
			raycast.name = "RayCast_" + w_name
			raycast.transform = wheel_node.transform
			raycast.target_position = Vector3(0, -SUSPENSION_REST_LENGTH, 0)
			raycast.enabled = true
			raycast.collision_mask = 1

			wheels_parent.add_child(raycast)
			raycast.owner = scene
			wheel_node.get_parent().remove_child(wheel_node)
			raycast.add_child(wheel_node)
			wheel_node.owner = scene
			wheel_node.transform = Transform3D.IDENTITY
			configurados += 1

	# 2. Soporte universal para trailers (nodo 'Ruedas' con hijos 'Rueda_*')
	var ruedas_parent = scene.find_child("Ruedas", true, false)
	if ruedas_parent:
		var script_rueda = load(RUEDA_TRAILER_SCRIPT_PATH)
		var hijos = ruedas_parent.get_children().duplicate()
		for wheel_node in hijos:
			if not (wheel_node is Node3D) or wheel_node is RayCast3D:
				continue
			if not wheel_node.name.begins_with("Rueda_"):
				continue

			var raycast := RayCast3D.new()
			if script_rueda:
				raycast.set_script(script_rueda)
			raycast.name = "RayCast_" + wheel_node.name
			raycast.transform = wheel_node.transform
			raycast.position.y = maxf(wheel_node.position.y, 0.60)
			raycast.target_position = Vector3(0, -1.25, 0)
			raycast.enabled = true
			raycast.collision_mask = 1
			if script_rueda:
				raycast.set("largo_reposo", 0.28)
				raycast.set("radio_rueda", 0.54)
				raycast.set("rigidez_muelle", 85000.0)
				raycast.set("fuerza_suspension_max", 150000.0)
				raycast.set("agarre_lateral", 30.0)

			ruedas_parent.remove_child(wheel_node)
			raycast.add_child(wheel_node)
			wheel_node.transform = Transform3D.IDENTITY
			if script_rueda:
				raycast.set("rueda_visual", wheel_node)
			ruedas_parent.add_child(raycast)
			raycast.owner = scene
			wheel_node.owner = scene
			configurados += 1

	if configurados > 0:
		print("[Auto-Raycast] ¡Configurados ", configurados, " RayCast3D de ruedas exitosamente!")
	else:
		printerr("[Auto-Raycast] No se encontró 'Wheels' ni 'Ruedas' con ruedas válidas.")
	return scene