extends SceneTree

const CargadorBiblioteca = preload("res://mundo/editor_mapas/CargadorBiblioteca.gd")

func _init() -> void:
	CargadorBiblioteca.inicializar()
	var secs = CargadorBiblioteca.obtener_secciones_de_categoria("01_Edificaciones")
	print("Secciones encontradas en 01_Edificaciones: ", secs.size())
	for s in secs:
		print("  -> [%s] %s %s" % [s["id"], s["icono"], s["nombre"]])
		var subs = CargadorBiblioteca.obtener_subapartados_de_seccion("01_Edificaciones", s["id"])
		for sub in subs:
			var count = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", s["id"], sub["id"]).size()
			print("       • [%s] %s %s (%d items)" % [sub["id"], sub["icono"], sub["nombre"], count])
			
	quit()
