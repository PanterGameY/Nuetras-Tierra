extends SceneTree

func _init() -> void:
	var escena_editor = load("res://mundo/editor_mapas/EditorMapas.tscn")
	var editor = escena_editor.instantiate()
	root.add_child(editor)
	editor.notification(Node.NOTIFICATION_ENTER_TREE)
	editor._ready()
	
	var ctrl_carreteras = editor.controlador_carreteras
	var ctrl_equip = editor.controlador_equipamiento
	ctrl_carreteras._ready()
	
	var p1 = ctrl_carreteras.agregar_punto_carretera(Vector3(10, 0, 10))
	var p2 = ctrl_carreteras.agregar_punto_carretera(Vector3(10, 0, 30))
	ctrl_carreteras.finalizar_tramo_actual()
	
	ctrl_equip.road_container = ctrl_carreteras.road_container
	ctrl_equip.controlador_carreteras = ctrl_carreteras
	
	ctrl_carreteras.seleccionar_punto_carretera(p2)
	
	print("--- Simulando 4 cambios de altura sucesivos (flecha arriba) ---")
	for h in [5.0, 5.5, 6.0, 6.5]:
		ctrl_carreteras.establecer_altura_punto_seleccionado(h)
		var total_nodos_puente := 0
		var total_pilares := 0
		for c in ctrl_equip._contenedor_equipamiento.get_children():
			if "PuenteViaducto" in c.name:
				total_nodos_puente += 1
				total_pilares += c.get_child_count()
		print("  Altura %+.1fm -> Nodos PuenteViaducto: %d, Total Pilares en escena: %d" % [h, total_nodos_puente, total_pilares])
		
	quit()
