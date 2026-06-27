with open(r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\escenas\gui\menu_personalizacion.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "btn_volver" in line:
        print(f"{i+1}: {line.strip()}")
