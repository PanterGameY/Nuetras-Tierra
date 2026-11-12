extends SceneTree

func _init() -> void:
	var res = load("res://modelos3d/mapa/casas.glb")
	print("Loaded casas.glb: ", res)
	if res:
		var inst = res.instantiate()
		print("Instantiated: ", inst)
		for child in inst.get_children():
			print("  Child: ", child.name, " class: ", child.get_class())
	quit()
