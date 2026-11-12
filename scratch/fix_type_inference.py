with open("mundo/editor_mapas/ControladorEquipamientoVias.gd", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("var n_name := nodo.name", "var n_name: String = str(nodo.name)")
text = text.replace("var h_name := h.name", "var h_name: String = str(h.name)")

with open("mundo/editor_mapas/ControladorEquipamientoVias.gd", "w", encoding="utf-8") as f:
    f.write(text)

print("Fixed type inference on n_name and h_name")
