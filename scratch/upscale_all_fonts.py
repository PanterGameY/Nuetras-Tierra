import re

def upscale_fonts():
    path = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\mundo\editor_mapas\UIEditorMapas.gd"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Top HUD Categories: 17 -> 20
    content = content.replace('btn.add_theme_font_size_override("font_size", 17)\n\t\tif _fuente_moderniz:', 'btn.add_theme_font_size_override("font_size", 20)\n\t\tif _fuente_moderniz:')

    # 2. Toast HUD: 16 -> 20
    content = content.replace('_toast_hud.add_theme_font_size_override("font_size", 16)', '_toast_hud.add_theme_font_size_override("font_size", 20)')

    # 3. Sliders: lbl 15 -> 18, lbl_val 16 -> 22, height 36 -> 42
    old_slider = """\tlbl.add_theme_font_size_override("font_size", 15)
\tlbl.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.90))
\thbox_hdr.add_child(lbl)
\t
\tvar lbl_val := Label.new()
\tlbl_val.text = "%.0f" % default_val if max_val > 5.0 else "%.2f" % default_val
\tlbl_val.add_theme_font_size_override("font_size", 16)
\tlbl_val.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\thbox_hdr.add_child(lbl_val)
\t
\tvar slider := HSlider.new()
\tslider.min_value = min_val
\tslider.max_value = max_val
\tslider.step = 0.05 if max_val <= 5.0 else 1.0
\tslider.value = default_val
\tslider.custom_minimum_size = Vector2(0, 36)"""

    new_slider = """\tlbl.add_theme_font_size_override("font_size", 18)
\tlbl.add_theme_color_override("font_color", Color(0.88, 0.91, 0.95, 0.95))
\thbox_hdr.add_child(lbl)
\t
\tvar lbl_val := Label.new()
\tlbl_val.text = "%.0f" % default_val if max_val > 5.0 else "%.2f" % default_val
\tlbl_val.add_theme_font_size_override("font_size", 22)
\tlbl_val.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\thbox_hdr.add_child(lbl_val)
\t
\tvar slider := HSlider.new()
\tslider.min_value = min_val
\tslider.max_value = max_val
\tslider.step = 0.05 if max_val <= 5.0 else 1.0
\tslider.value = default_val
\tslider.custom_minimum_size = Vector2(0, 42)"""

    assert old_slider in content, "old_slider not found"
    content = content.replace(old_slider, new_slider, 1)

    # 4. _crear_tarjeta_item:
    # btn size: 228, 120 -> 232, 138
    # panel_ico size: 54 -> 58
    # lbl_ico size: 32 -> 38
    # lbl_nom font_size: 13 -> 18
    # lbl_sub font_size: 11 -> 15
    old_card_code = """func _crear_tarjeta_item(id: String, fallback_ico: String, nombre: String, svg_name: String = "", icono_textura: String = "", subtitulo: String = "") -> void:
\tvar btn := Button.new()
\tbtn.custom_minimum_size = Vector2(228, 120)
\tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_estilar_boton(btn, Color(0.09, 0.10, 0.13, 0.90), Color(0.78, 0.81, 0.85, 0.22), 10.0)
\t
\tvar margin_card := MarginContainer.new()
\tmargin_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
\tmargin_card.add_theme_constant_override("margin_left", 8)
\tmargin_card.add_theme_constant_override("margin_right", 8)
\tmargin_card.add_theme_constant_override("margin_top", 8)
\tmargin_card.add_theme_constant_override("margin_bottom", 8)
\tmargin_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tbtn.add_child(margin_card)
\t
\tvar vbox := VBoxContainer.new()
\tvbox.add_theme_constant_override("separation", 4)
\tvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tmargin_card.add_child(vbox)
\t
\t# Recuadro Recesivo para el Icono / Thumbnail
\tvar panel_ico := PanelContainer.new()
\tpanel_ico.custom_minimum_size = Vector2(0, 54)
\tpanel_ico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tpanel_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t_estilar_panel_glass(panel_ico, Color(0.04, 0.05, 0.07, 0.88), Color(0.78, 0.81, 0.85, 0.16), 8.0, 4.0)
\tvbox.add_child(panel_ico)
\t
\tvar box_ico_center := CenterContainer.new()
\tbox_ico_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tpanel_ico.add_child(box_ico_center)
\t
\tvar tex_mostrada: Texture2D = null
\tif icono_textura != "" and ResourceLoader.exists(icono_textura):
\t\ttex_mostrada = load(icono_textura) as Texture2D
\telif svg_name != "":
\t\ttex_mostrada = _cargar_icono_svg(svg_name)
\t\t
\tif tex_mostrada:
\t\tvar tex_rect := TextureRect.new()
\t\ttex_rect.texture = tex_mostrada
\t\ttex_rect.custom_minimum_size = Vector2(44, 44)
\t\ttex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
\t\ttex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
\t\ttex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t\tbox_ico_center.add_child(tex_rect)
\telse:
\t\tvar lbl_ico := Label.new()
\t\tlbl_ico.text = fallback_ico
\t\tlbl_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t\tlbl_ico.add_theme_font_size_override("font_size", 32)
\t\tbox_ico_center.add_child(lbl_ico)
\t\t
\t# Título principal del objeto (Smart Word Wrap)
\tvar lbl_nom := Label.new()
\tlbl_nom.text = nombre
\tlbl_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
\tlbl_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tlbl_nom.max_lines_visible = 2
\tlbl_nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tlbl_nom.add_theme_font_size_override("font_size", 13)
\tlbl_nom.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
\tvbox.add_child(lbl_nom)
\t
\t# Subtítulo descriptivo o dimensión (si existe)
\tif subtitulo != "":
\t\tvar lbl_sub := Label.new()
\t\tlbl_sub.text = subtitulo
\t\tlbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t\tlbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\tlbl_sub.max_lines_visible = 1
\t\tlbl_sub.add_theme_font_size_override("font_size", 11)
\t\tlbl_sub.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.90))
\t\tvbox.add_child(lbl_sub)"""

    new_card_code = """func _crear_tarjeta_item(id: String, fallback_ico: String, nombre: String, svg_name: String = "", icono_textura: String = "", subtitulo: String = "") -> void:
\tvar btn := Button.new()
\tbtn.custom_minimum_size = Vector2(232, 138)
\tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_estilar_boton(btn, Color(0.09, 0.10, 0.13, 0.90), Color(0.78, 0.81, 0.85, 0.24), 10.0)
\t
\tvar margin_card := MarginContainer.new()
\tmargin_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
\tmargin_card.add_theme_constant_override("margin_left", 8)
\tmargin_card.add_theme_constant_override("margin_right", 8)
\tmargin_card.add_theme_constant_override("margin_top", 8)
\tmargin_card.add_theme_constant_override("margin_bottom", 8)
\tmargin_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tbtn.add_child(margin_card)
\t
\tvar vbox := VBoxContainer.new()
\tvbox.add_theme_constant_override("separation", 4)
\tvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tmargin_card.add_child(vbox)
\t
\t# Recuadro Recesivo para el Icono / Thumbnail
\tvar panel_ico := PanelContainer.new()
\tpanel_ico.custom_minimum_size = Vector2(0, 58)
\tpanel_ico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tpanel_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t_estilar_panel_glass(panel_ico, Color(0.04, 0.05, 0.07, 0.88), Color(0.78, 0.81, 0.85, 0.18), 8.0, 4.0)
\tvbox.add_child(panel_ico)
\t
\tvar box_ico_center := CenterContainer.new()
\tbox_ico_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
\tpanel_ico.add_child(box_ico_center)
\t
\tvar tex_mostrada: Texture2D = null
\tif icono_textura != "" and ResourceLoader.exists(icono_textura):
\t\ttex_mostrada = load(icono_textura) as Texture2D
\telif svg_name != "":
\t\ttex_mostrada = _cargar_icono_svg(svg_name)
\t\t
\tif tex_mostrada:
\t\tvar tex_rect := TextureRect.new()
\t\ttex_rect.texture = tex_mostrada
\t\ttex_rect.custom_minimum_size = Vector2(48, 48)
\t\ttex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
\t\ttex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
\t\ttex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t\tbox_ico_center.add_child(tex_rect)
\telse:
\t\tvar lbl_ico := Label.new()
\t\tlbl_ico.text = fallback_ico
\t\tlbl_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t\tlbl_ico.add_theme_font_size_override("font_size", 38)
\t\tbox_ico_center.add_child(lbl_ico)
\t\t
\t# Título principal del objeto (Smart Word Wrap con Fuente Grande y Legible)
\tvar lbl_nom := Label.new()
\tlbl_nom.text = nombre
\tlbl_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
\tlbl_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tlbl_nom.max_lines_visible = 2
\tlbl_nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tlbl_nom.add_theme_font_size_override("font_size", 17)
\tlbl_nom.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
\tvbox.add_child(lbl_nom)
\t
\t# Subtítulo descriptivo o dimensión (Grande y Nítido)
\tif subtitulo != "":
\t\tvar lbl_sub := Label.new()
\t\tlbl_sub.text = subtitulo
\t\tlbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t\tlbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\tlbl_sub.max_lines_visible = 1
\t\tlbl_sub.add_theme_font_size_override("font_size", 14)
\t\tlbl_sub.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
\t\tvbox.add_child(lbl_sub)"""

    assert old_card_code in content, "old_card_code not found"
    content = content.replace(old_card_code, new_card_code, 1)

    # 5. Search Bar, Section headers, and category buttons in _construir_filtros_apartados_edificaciones
    old_filtros_search = """\tvar input_busqueda := LineEdit.new()
\tinput_busqueda.placeholder_text = "🔍 Buscar modelo (chalet, colonial, edificio, hacienda...)"
\tinput_busqueda.custom_minimum_size = Vector2(0, 42)
\tinput_busqueda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tinput_busqueda.add_theme_font_size_override("font_size", 14)"""

    new_filtros_search = """\tvar input_busqueda := LineEdit.new()
\tinput_busqueda.placeholder_text = "🔍 Buscar modelo (chalet, colonial, edificio, hacienda...)"
\tinput_busqueda.custom_minimum_size = Vector2(0, 50)
\tinput_busqueda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tinput_busqueda.add_theme_font_size_override("font_size", 17)"""

    assert old_filtros_search in content, "old_filtros_search not found"
    content = content.replace(old_filtros_search, new_filtros_search, 1)

    # 6. Section header label and buttons
    content = content.replace('lbl_sec.add_theme_font_size_override("font_size", 13)\n\tlbl_sec.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.98))', 'lbl_sec.add_theme_font_size_override("font_size", 18)\n\tlbl_sec.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.98))')

    old_sec_btn = """\t\tbtn_s.custom_minimum_size = Vector2(0, 44)
\t\tbtn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tbtn_s.add_theme_font_size_override("font_size", 13)"""

    new_sec_btn = """\t\tbtn_s.custom_minimum_size = Vector2(0, 50)
\t\tbtn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tbtn_s.add_theme_font_size_override("font_size", 17)"""

    assert old_sec_btn in content, "old_sec_btn not found"
    content = content.replace(old_sec_btn, new_sec_btn, 1)

    # 7. Subapartados header & chips
    content = content.replace('_lbl_subapartados_header.add_theme_font_size_override("font_size", 12)', '_lbl_subapartados_header.add_theme_font_size_override("font_size", 16)')

    old_sub_btn = """\t\tbtn.custom_minimum_size = Vector2(0, 36)
\t\tbtn.add_theme_font_size_override("font_size", 12)"""

    new_sub_btn = """\t\tbtn.custom_minimum_size = Vector2(0, 44)
\t\tbtn.add_theme_font_size_override("font_size", 15)"""

    assert old_sub_btn in content, "old_sub_btn not found"
    content = content.replace(old_sub_btn, new_sub_btn, 1)

    # 8. Dock Preview Inferior titles and descriptions:
    content = content.replace('lbl_titulo.add_theme_font_size_override("font_size", 16)', 'lbl_titulo.add_theme_font_size_override("font_size", 22)')
    content = content.replace('_lbl_preview_titulo.add_theme_font_size_override("font_size", 16)', '_lbl_preview_titulo.add_theme_font_size_override("font_size", 22)')
    content = content.replace('badge_modo.add_theme_font_size_override("font_size", 12)', 'badge_modo.add_theme_font_size_override("font_size", 16)')
    content = content.replace('lbl_graf_desc.add_theme_font_size_override("font_size", 12)', 'lbl_graf_desc.add_theme_font_size_override("font_size", 16)')
    content = content.replace('lbl_esq_desc.add_theme_font_size_override("font_size", 12)', 'lbl_esq_desc.add_theme_font_size_override("font_size", 16)')
    content = content.replace('lbl_fall.add_theme_font_size_override("font_size", 12)', 'lbl_fall.add_theme_font_size_override("font_size", 15)')
    content = content.replace('btn_p.add_theme_font_size_override("font_size", 11)', 'btn_p.add_theme_font_size_override("font_size", 15)')
    content = content.replace('lbl_atajo.add_theme_font_size_override("font_size", 11)', 'lbl_atajo.add_theme_font_size_override("font_size", 14)')
    content = content.replace('lbl_guia.add_theme_font_size_override("font_size", 11)', 'lbl_guia.add_theme_font_size_override("font_size", 14)')
    content = content.replace('_lbl_preview_telemetria.add_theme_font_size_override("font_size", 12)', '_lbl_preview_telemetria.add_theme_font_size_override("font_size", 16)')
    content = content.replace('l.add_theme_font_size_override("font_size", 11)', 'l.add_theme_font_size_override("font_size", 15)')
    content = content.replace('l_desc.add_theme_font_size_override("font_size", 12)', 'l_desc.add_theme_font_size_override("font_size", 15)')
    content = content.replace('b.add_theme_font_size_override("font_size", 11)', 'b.add_theme_font_size_override("font_size", 15)')
    content = content.replace('btn_rotar.add_theme_font_size_override("font_size", 12)', 'btn_rotar.add_theme_font_size_override("font_size", 16)')
    content = content.replace('btn_dem.add_theme_font_size_override("font_size", 12)', 'btn_dem.add_theme_font_size_override("font_size", 16)')
    content = content.replace('b_t800.add_theme_font_size_override("font_size", 12)', 'b_t800.add_theme_font_size_override("font_size", 16)')
    content = content.replace('b_cam.add_theme_font_size_override("font_size", 12)', 'b_cam.add_theme_font_size_override("font_size", 16)')

    # 9. Top Action buttons in Vias / Naturaleza:
    content = content.replace('btn_terminar.add_theme_font_size_override("font_size", 15)', 'btn_terminar.add_theme_font_size_override("font_size", 18)')
    content = content.replace('_btn_accion_conectar.add_theme_font_size_override("font_size", 15)', '_btn_accion_conectar.add_theme_font_size_override("font_size", 18)')
    content = content.replace('btn_nivelar.add_theme_font_size_override("font_size", 15)', 'btn_nivelar.add_theme_font_size_override("font_size", 18)')
    content = content.replace('btn_scatter.add_theme_font_size_override("font_size", 16)', 'btn_scatter.add_theme_font_size_override("font_size", 18)')
    content = content.replace('btn_borrar_veg.add_theme_font_size_override("font_size", 15)', 'btn_borrar_veg.add_theme_font_size_override("font_size", 17)')

    # 10. Action button Colocar:
    content = content.replace('_btn_colocar_grande.add_theme_font_size_override("font_size", 22)', '_btn_colocar_grande.add_theme_font_size_override("font_size", 24)')

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print("All fonts upscaled successfully!")

if __name__ == "__main__":
    upscale_fonts()
