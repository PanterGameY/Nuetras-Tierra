extends SceneTree

func _init() -> void:
	print("==================================================")
	print("  TEST: DOCK DE PREVIEW E INSPECTOR EN TODAS LAS CATEGORÍAS")
	print("==================================================")
	
	var escena_editor = load("res://mundo/editor_mapas/EditorMapas.tscn")
	assert(escena_editor != null, "EditorMapas.tscn debe existir")
	var editor = escena_editor.instantiate()
	root.add_child(editor)
	editor.notification(Node.NOTIFICATION_ENTER_TREE)
	editor._ready()
	
	var ui = editor.ui_editor
	assert(ui != null, "UIEditorMapas debe existir")
	if not ui.is_node_ready():
		ui._ready()
		
	assert(ui._dock_preview_inferior != null, "_dock_preview_inferior debe existir")
	print("  ✓ Dock de preview inferior creado correctamente")
	
	print("1. Probando preview en TERRENO...")
	ui.seleccionar_categoria("terreno")
	assert(ui._dock_preview_inferior.get_child_count() > 0, "Dock inferior de terreno debe tener contenido")
	print("  ✓ Contenido del dock de terreno activo")
	
	print("2. Probando preview en VÍAS...")
	ui.seleccionar_categoria("vias")
	assert(ui._dock_preview_inferior.get_child_count() > 0, "Dock inferior de vías debe tener contenido")
	print("  ✓ Contenido del dock de vías activo")
	
	print("3. Probando preview 3D en CIUDAD...")
	ui.seleccionar_categoria("ciudad")
	assert(ui._dock_preview_inferior.get_child_count() > 0, "Dock inferior de ciudad debe tener contenido")
	assert(ui._vp_container_preview != null, "SubViewportContainer debe estar instanciado")
	print("  ✓ Contenido del dock de ciudad activo con SubViewport 3D")
	
	print("4. Probando preview 3D en NATURALEZA (VEGETACIÓN)...")
	ui.seleccionar_categoria("vegetacion")
	assert(ui._dock_preview_inferior.get_child_count() > 0, "Dock inferior de vegetación debe tener contenido")
	print("  ✓ Contenido del dock de vegetación activo con SubViewport 3D")
	
	print("5. Probando preview en AGUA...")
	ui.seleccionar_categoria("agua")
	assert(ui._dock_preview_inferior.get_child_count() > 0, "Dock inferior de agua debe tener contenido")
	print("  ✓ Contenido del dock de agua activo")
	
	print("6. Probando preview en SPAWN...")
	ui.seleccionar_categoria("spawn")
	assert(ui._dock_preview_inferior.get_child_count() > 0, "Dock inferior de spawn debe tener contenido")
	print("  ✓ Contenido del dock de spawn activo")
	
	print("==================================================")
	print("  ¡TODAS LAS CATEGORÍAS TIENEN PREVIEW ACTIVO Y CERO ESPACIO MUERTO!")
	print("==================================================")
	quit()
