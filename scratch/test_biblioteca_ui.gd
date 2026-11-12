extends SceneTree

const CargadorBiblioteca = preload("res://mundo/editor_mapas/CargadorBiblioteca.gd")

func _init() -> void:
	print("==================================================")
	print("  TEST: BIBLIOTECA ORGANIZADA POR APARTADOS Y UI")
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
	
	print("1. Seleccionando categoría Ciudad en la UI...")
	ui.seleccionar_categoria("ciudad")
	assert(ui._box_filtros_edificaciones != null, "_box_filtros_edificaciones debe haberse creado")
	assert(ui._dict_btn_secciones_edif.size() >= 5, "Deben existir al menos 5 botones de secciones")
	print("  ✓ Secciones creadas: ", ui._dict_btn_secciones_edif.keys())
	
	print("2. Probando filtro de Residencial...")
	assert(ui._seccion_biblioteca_activa == "01_Residencial", "La sección activa inicial debe ser 01_Residencial")
	assert(ui._dict_btn_subapartados_edif.has("Casas_Modernas"), "Debe tener botón Casas_Modernas")
	assert(ui._dict_btn_subapartados_edif.has("Casas_Tradicionales"), "Debe tener botón Casas_Tradicionales")
	assert(ui._dict_btn_subapartados_edif.has("Conjuntos_Cerrados"), "Debe tener botón Conjuntos_Cerrados")
	assert(ui._dict_btn_subapartados_edif.has("Edificios_Apartamentos"), "Debe tener botón Edificios_Apartamentos")
	print("  ✓ Subapartados residenciales: ", ui._dict_btn_subapartados_edif.keys())
	
	print("3. Probando filtrado de Casas Modernas...")
	ui._subapartado_biblioteca_activa = "Casas_Modernas"
	ui._refrescar_grid_edificaciones()
	var items_modernas = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", "01_Residencial", "Casas_Modernas")
	print("  ✓ Items Casas Modernas: %d" % items_modernas.size())
	assert(items_modernas.size() >= 2, "Debe haber al menos 2 casas modernas")
	
	print("4. Probando filtrado de Casas Tradicionales...")
	ui._subapartado_biblioteca_activa = "Casas_Tradicionales"
	ui._refrescar_grid_edificaciones()
	var items_trad = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", "01_Residencial", "Casas_Tradicionales")
	print("  ✓ Items Casas Tradicionales: %d" % items_trad.size())
	assert(items_trad.size() >= 2, "Debe haber al menos 2 casas tradicionales")
	
	print("5. Probando instanciación real en 3D de modelos generados...")
	for id_mod in ["casa_moderna_cubica", "casa_campesina_paisa", "porteria_conjunto", "edificio_apartamentos_ladrillo", "casona_hacienda_cafetera"]:
		var inst = CargadorBiblioteca.instanciar_asset(id_mod)
		assert(inst != null, "Debe instanciarse el modelo %s" % id_mod)
		print("  ✓ Instanciado con éxito: '%s' (%s)" % [id_mod, inst.name])
		inst.queue_free()
		
	print("==================================================")
	print("  ¡TODAS LAS PRUEBAS DE LA BIBLIOTECA PASARON AL 100%!")
	print("==================================================")
	quit()
