path = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\mundo\editor_mapas\UIEditorMapas.gd"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace('btn_toggle_3d.add_theme_font_size_override("font_size", 13)', 'btn_toggle_3d.add_theme_font_size_override("font_size", 16)')
text = text.replace('_btn_toggle_workstation.add_theme_font_size_override("font_size", 13)', '_btn_toggle_workstation.add_theme_font_size_override("font_size", 16)')
text = text.replace('_lbl_preview_telemetria.add_theme_font_size_override("font_size", 13)', '_lbl_preview_telemetria.add_theme_font_size_override("font_size", 16)')

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Remaining 13px fonts upscaled to 16px!")
