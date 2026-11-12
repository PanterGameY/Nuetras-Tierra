path = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\mundo\editor_mapas\UIEditorMapas.gd"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

target = "\tvbox.add_child(lbl_sub)\n\t\n\tbtn.pressed.connect"
replacement = "\t\tvbox.add_child(lbl_sub)\n\t\n\tbtn.pressed.connect"

assert target in text, "target not found"
text = text.replace(target, replacement, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Indentation fixed successfully!")
