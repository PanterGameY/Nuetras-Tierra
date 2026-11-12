import sys

with open("mundo/editor_mapas/UIEditorMapas.gd", "r", encoding="utf-8") as f:
    text = f.read()

lines = text.splitlines()
for i in range(40, min(100, len(lines))):
    sys.stdout.buffer.write(f"{i+1:3d}: {lines[i]}\n".encode("utf-8"))
