path = "mundo/editor_mapas/UIEditorMapas.gd"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("CargadorBiblioteca.obtener_icono_apartado(", "CargadorBiblioteca.deducir_icono_seccion_o_sub(")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Updated function calls successfully!")
