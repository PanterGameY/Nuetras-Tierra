extends SceneTree

func _init() -> void:
	var scn = load("res://mundo/editor_mapas/modelos/pilar_viaducto_4g.glb")
	var inst = scn.instantiate()
	var root_node = inst.get_node("Pilar_Viaducto_4G_Root")
	for c in root_node.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi:
			print("Mesh %s: transform=%s, AABB=%s" % [mi.name, mi.transform, mi.mesh.get_aabb()])
	quit()
