extends SceneTree

func _init() -> void:
	var scn = load("res://mundo/editor_mapas/modelos/pilar_viaducto_4g.glb")
	if scn:
		var inst = scn.instantiate()
		print("Root: ", inst.name)
		for c in inst.get_children():
			print("  Child: ", c.name, " pos: ", c.position, " rot: ", c.rotation_degrees, " scale: ", c.scale)
			if c is MeshInstance3D and c.mesh:
				print("    Mesh AABB: ", c.mesh.get_aabb())
			for c2 in c.get_children():
				print("    SubChild: ", c2.name, " pos: ", c2.position)
				if c2 is MeshInstance3D and c2.mesh:
					print("      Mesh AABB: ", c2.mesh.get_aabb())
	quit()
