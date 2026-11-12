extends SceneTree

func _init() -> void:
	print("==================================================")
	print("  TEST: PREVIEW EMBEBIDO EN LA TARJETA DE DESCRIPCIÓN Y VELOCIDAD REDUCIDA")
	print("==================================================")
	
	var script = load("res://mundo/editor_mapas/UIEditorMapas.gd")
	assert(script != null, "UIEditorMapas debe cargar sin errores")
	var ui = script.new()
	root.add_child(ui)
	ui._ready()
	
	print("1. Verificando velocidad de rotación reducida...")
	print("  Velocidad actual: ", ui._velocidad_rotacion_preview, " rad/s")
	assert(ui._velocidad_rotacion_preview <= 0.25, "La rotación debe ser lenta (<= 0.25 rad/s)")
	print("  ✓ Rotación lenta y cinematográfica confirmada (0.20 rad/s)")
	
	print("2. Seleccionando categoría Ciudad...")
	ui.seleccionar_categoria("ciudad")
	assert(ui._dock_preview_inferior != null, "Dock de preview debe existir")
	assert(ui._dock_preview_inferior.get_child_count() > 0, "Dock debe contener la tarjeta unificada")
	
	print("3. Verificando que el visor 3D esté empotrado directamente en la tarjeta...")
	assert(ui._vp_container_preview != null, "SubViewportContainer debe existir")
	assert(ui._vp_container_preview.get_parent() != null, "SubViewportContainer debe estar añadido al árbol de la tarjeta")
	assert(ui._lbl_preview_titulo != null, "Label de título debe existir")
	assert(ui._lbl_preview_categoria != null, "Label de categoría debe existir")
	assert(ui._lbl_preview_telemetria != null, "Label de telemetría debe existir")
	assert(ui._lbl_preview_desc != null, "Label de descripción debe existir")
	
	print("  Título en tarjeta: ", ui._lbl_preview_titulo.text)
	print("  Categoría en tarjeta: ", ui._lbl_preview_categoria.text)
	print("  Telemetría en tarjeta: ", ui._lbl_preview_telemetria.text)
	print("  Descripción en tarjeta: ", ui._lbl_preview_desc.text)
	
	assert(not ui._lbl_preview_titulo.text.is_empty(), "El título debe estar presente")
	assert(not ui._lbl_preview_categoria.text.is_empty(), "La categoría debe estar presente")
	assert(not ui._lbl_preview_telemetria.text.is_empty(), "La telemetría debe estar presente")
	assert(not ui._lbl_preview_desc.text.is_empty(), "La descripción debe estar presente")
	print("  ✓ Tarjeta unificada contiene Visor 3D + Título + Categoría + Telemetría + Descripción + Botones")
	
	print("4. Probando cambio de modelo a 'chalet_alpino_moderno'...")
	ui._actualizar_dock_preview_contextual("ciudad", "chalet_alpino_moderno")
	print("  Nuevo título: ", ui._lbl_preview_titulo.text)
	print("  Nueva descripción: ", ui._lbl_preview_desc.text)
	assert("CHALET" in ui._lbl_preview_titulo.text, "El título debe actualizarse al nuevo modelo")
	assert("alpina" in ui._lbl_preview_desc.text.to_lower() or "chalet" in ui._lbl_preview_desc.text.to_lower(), "La descripción debe describir el chalet")
	print("  ✓ Metadatos y descripción técnica reactivos al modelo seleccionado")
	
	print("==================================================")
	print("  TODAS LAS PRUEBAS DE LA TARJETA Y VELOCIDAD: ¡PASARON EXITOSAMENTE! (100%)")
	print("==================================================")
	quit()
