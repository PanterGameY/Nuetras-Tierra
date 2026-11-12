import sys
sys.stdout.reconfigure(encoding='utf-8')

with open("mundo/editor_mapas/UIEditorMapas.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

print("Line 2795-2865 (_construir_preview_3d_dock):")
for i in range(2794, 2865):
    print(f"{i+1}: {lines[i].rstrip()}")

print("\nLine 3050-3105 (_actualizar_preview_3d_objeto):")
for i in range(3050, 3105):
    print(f"{i+1}: {lines[i].rstrip()}")
