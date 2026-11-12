import sys

with open("scratch/test_integracion_completa.gd", "r", encoding="utf-8") as f:
    text = f.read()

lines = text.splitlines()
for i in range(min(40, len(lines))):
    sys.stdout.buffer.write(f"{i+1:3d}: {lines[i]}\n".encode("utf-8"))
