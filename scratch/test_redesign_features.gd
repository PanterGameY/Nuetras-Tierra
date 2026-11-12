extends SceneTree

const CargadorBiblioteca = preload("res://mundo/editor_mapas/CargadorBiblioteca.gd")

func _init() -> void:
	print("==================================================")
	print("  TEST: WORKSTATION REDESIGN Y BUSCADOR UI")
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
		
	ui.seleccionar_categoria("ciudad")
	
	print("1. Probando dimensiones estándar del panel...")
	print("  Offset izquierdo actual: ", ui._panel_consola.offset_left)
	assert(ui._panel_consola.offset_left == -(ui.ANCHO_CONSOLA_ESTANDAR + 16.0), "Debe tener 780px de ancho base")
	assert(ui._grid_items.columns == 3, "Debe tener 3 columnas en modo estándar")
	
	print("2. Probando toggle a Modo Workstation (1120px)...")
	ui._alternar_modo_workstation()
	assert(ui._modo_workstation_expandido == true, "Debe estar activo el modo workstation")
	assert(ui._grid_items.columns == 4, "Debe pasar a 4 columnas en modo workstation")
	print("  ✓ Modo Workstation activado con éxito (4 columnas)")
	
	ui._alternar_modo_workstation()
	assert(ui._modo_workstation_expandido == false, "Debe volver a modo estándar")
	assert(ui._grid_items.columns == 3, "Debe volver a 3 columnas")
	print("  ✓ Retorno a modo estándar con éxito")
	
	print("3. Probando filtrado en tiempo real por búsqueda...")
	ui._seccion_biblioteca_activa = "todas"
	ui._texto_busqueda_catalogo = "chalet"
	ui._refrescar_grid_edificaciones()
	var tarjetas_chalet = ui._dict_tarjetas_items.keys()
	print("  ✓ Tarjetas con 'chalet': ", tarjetas_chalet)
	assert(tarjetas_chalet.has("chalet_alpino_moderno"), "Debe encontrar el chalet")
	assert(tarjetas_chalet.size() == 1, "Solo debe haber 1 resultado para 'chalet'")
	
	ui._texto_busqueda_catalogo = "ladrillo"
	ui._refrescar_grid_edificaciones()
	var tarjetas_ladrillo = ui._dict_tarjetas_items.keys()
	print("  ✓ Tarjetas con 'ladrillo': ", tarjetas_ladrillo)
	assert(tarjetas_ladrillo.has("edificio_apartamentos_ladrillo"), "Debe encontrar edificio apartamentos ladrillo")
	
	ui._texto_busqueda_catalogo = ""
	ui._seccion_biblioteca_activa = "01_Residencial"
	ui._subapartado_biblioteca_activa = "todos"
	ui._refrescar_grid_edificaciones()
	print("  ✓ Tarjetas totales Residencial: ", ui._dict_tarjetas_items.size())
	assert(ui._dict_tarjetas_items.size() >= 8, "Debe haber al menos 8 tarjetas en residencial")
	
	print("4. Probando estructura de tarjetas...")
	var primera_tarjeta = ui._dict_tarjetas_items.values()[0]
	assert(primera_tarjeta.custom_minimum_size.x >= 220, "La tarjeta debe tener ancho amplio (>=220px)")
	assert(primera_tarjeta.custom_minimum_size.y >= 115, "La tarjeta debe tener alto amplio (>=115px)")
	print("  ✓ Dimensiones de tarjeta verificadas: ", primera_tarjeta.custom_minimum_size)
	
	print("==================================================")
	print("  ¡TODAS LAS PRUEBAS DEL REDISEÑO PASARON AL 100%!")
	print("==================================================")
	quit()
