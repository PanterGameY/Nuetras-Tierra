path = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\mundo\editor_mapas\UIEditorMapas.gd"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

target = """\t_camara_preview_3d.position = Vector3(0, 4.2, 10.0)
\t_camara_preview_3d.look_at(Vector3(0, 0, 0), Vector3.UP)
\t_subviewport_preview.add_child(_camara_preview_3d)"""

replacement = """\t_subviewport_preview.add_child(_camara_preview_3d)
\t_camara_preview_3d.look_at_from_position(Vector3(0, 4.2, 10.0), Vector3(0, 0, 0), Vector3.UP)"""

assert target in text, "target not found"
text = text.replace(target, replacement, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("look_at_from_position fixed!")
