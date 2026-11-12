import sys

with open("mundo/editor_mapas/CargadorBiblioteca.gd", "r", encoding="utf-8") as f:
    text = f.read()

# print line by line up to line 100
lines = text.splitlines()
for i in range(min(120, len(lines))):
    sys.stdout.buffer.write(f"{i+1:3d}: {lines[i]}\n".encode("utf-8"))
