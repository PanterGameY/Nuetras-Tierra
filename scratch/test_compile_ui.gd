extends SceneTree

func _init() -> void:
	var script = load("res://mundo/editor_mapas/UIEditorMapas.gd")
	print("UIEditorMapas script loaded: ", script)
	if script != null:
		var instance = script.new()
		print("Instance created: ", instance)
		instance.free()
	quit()
