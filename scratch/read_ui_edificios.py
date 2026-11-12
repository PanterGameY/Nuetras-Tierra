import sys

with open("mundo/editor_mapas/UIEditorMapas.gd", "r", encoding="utf-8") as f:
    text = f.read()

idx = text.find('obtener_items_por_categoria("01_Edificaciones")')
if idx != -1:
    sys.stdout.buffer.write(text[max(0, idx - 600):idx + 1200].encode("utf-8"))
else:
    print("Not found")
