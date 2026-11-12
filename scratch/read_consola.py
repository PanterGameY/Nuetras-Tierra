import sys

with open("mundo/editor_mapas/UIEditorMapas.gd", "r", encoding="utf-8") as f:
    text = f.read()

idx = text.find("_panel_consola =")
if idx != -1:
    sys.stdout.buffer.write(text[max(0, idx - 150):idx + 1000].encode("utf-8"))
