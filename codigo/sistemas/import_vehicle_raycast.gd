@tool
extends EditorScenePostImport

# Longitud del rayo de suspensión hacia abajo (en metros)
const SUSPENSION_REST_LENGTH: float = 0.65 

func _post_import(scene: Node) -> Object:
	var wheels_parent = scene.find_child("Wheels", true, false)
	if not wheels_parent:
		printerr("[Auto-Raycast] No se encontró el nodo 'Wheels'.")
		return scene

	# Lista de los 4 empties de las ruedas configurados en Blender
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

		# 1. Crear el nodo RayCast3D
		var raycast = RayCast3D.new()
		raycast.name = "RayCast_" + w_name
		
		# 2. Asignarle la posición exacta que tenía la rueda
		raycast.transform = wheel_node.transform
		
		# 3. Configurar el rayo hacia abajo (-Y) para detectar el suelo
		raycast.target_position = Vector3(0, -SUSPENSION_REST_LENGTH, 0)
		raycast.enabled = true
		raycast.collision_mask = 1 # Capa de colisión del suelo

		# 4. Añadir el RayCast al padre 'Wheels'
		wheels_parent.add_child(raycast)
		raycast.owner = scene

		# 5. Mover la rueda (Rim + Tire) como hija del RayCast
		wheel_node.get_parent().remove_child(wheel_node)
		raycast.add_child(wheel_node)
		wheel_node.owner = scene
		
		# Resetear la posición local de la rueda dentro del RayCast
		wheel_node.transform = Transform3D.IDENTITY

	print("[Auto-Raycast] ¡Ruedas configuradas con RayCast3D exitosamente!")
	return scene