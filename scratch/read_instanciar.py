import sys

with open("mundo/editor_mapas/ControladorEquipamientoVias.gd", "r", encoding="utf-8") as f:
    text = f.read()

idx = text.find("func _instanciar_pilar_en_curva")
lines = text[idx:].splitlines()
for i in range(min(50, len(lines))):
    sys.stdout.buffer.write(f"{i+1:2d}: {lines[i]}\n".encode("utf-8"))
