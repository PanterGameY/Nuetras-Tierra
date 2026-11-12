import sys
sys.stdout.reconfigure(encoding='utf-8')

with open("mundo/editor_mapas/UIEditorMapas.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i in range(3115, 3135):
    print(f"{i+1}: {repr(lines[i])}")
