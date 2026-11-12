with open("mundo/editor_mapas/UIEditorMapas.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

print("Line 158-175:")
for i in range(157, 175):
    print(f"{i+1}: {lines[i].rstrip()}")
