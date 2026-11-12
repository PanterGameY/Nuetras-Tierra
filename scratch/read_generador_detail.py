import sys

with open("mundo/editor_mapas/GeneradorModelosCiudad.gd", "r", encoding="utf-8") as f:
    text = f.read()

lines = text.splitlines()
for i in range(120, min(300, len(lines))):
    sys.stdout.buffer.write(f"{i+1:3d}: {lines[i]}\n".encode("utf-8"))
