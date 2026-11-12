import sys

with open("mundo/editor_mapas/UIEditorMapas.gd", "r", encoding="utf-8") as f:
    text = f.read()

idx = text.find("func _llenar_catalogo_ciudad")
lines = text[idx:].splitlines()
for i in range(min(45, len(lines))):
    sys.stdout.buffer.write(f"{i+1:2d}: {lines[i]}\n".encode("utf-8"))
