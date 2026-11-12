extends SceneTree

func _init() -> void:
	var res = load("res://modelos3d/mapa/casas.glb")
	if res:
		var inst = res.instantiate()
		var mesh_inst: MeshInstance3D = inst.get_node("Cube_001") as MeshInstance3D
		if mesh_inst and mesh_inst.mesh:
			var aabb = mesh_inst.mesh.get_aabb()
			print("AABB: position=", aabb.position, " size=", aabb.size)
	quit()
