extends SceneTree

const CargadorBiblioteca = preload("res://mundo/editor_mapas/CargadorBiblioteca.gd")

func _init() -> void:
	CargadorBiblioteca.inicializar()
	var items = CargadorBiblioteca.obtener_items_por_categoria("01_Edificaciones")
	print("Items en 01_Edificaciones: ", items.size())
	for it in items:
		print("  [%s] %s (subcat: %s, escena: %s)" % [it["id"], it["nombre"], it.get("subcategoria", ""), it.get("ruta_escena", "")])
	quit()
