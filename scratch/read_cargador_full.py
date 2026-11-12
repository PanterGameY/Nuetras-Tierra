import sys

with open("mundo/editor_mapas/CargadorBiblioteca.gd", "r", encoding="utf-8") as f:
    text = f.read()

lines = text.splitlines()
print(f"Total lines in CargadorBiblioteca: {len(lines)}")
for i in range(min(70, len(lines))):
    sys.stdout.buffer.write(f"{i+1:3d}: {lines[i]}\n".encode("utf-8"))
