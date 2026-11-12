import re

def apply_preview_dock():
    path = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\mundo\editor_mapas\UIEditorMapas.gd"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. New variables for dock preview inferior
    old_vars = """var _panel_consola: PanelContainer
var _btn_colapsar: Button"""
    new_vars = """var _dock_preview_inferior: PanelContainer = null
var _vp_container_preview: SubViewportContainer = null
var _panel_consola: PanelContainer
var _btn_colapsar: Button"""
    if old_vars in content:
        content = content.replace(old_vars, new_vars, 1)

    # 2. In _construir_consola_derecha: add _dock_preview_inferior to _box_biblioteca
    old_consola_box = """\t_grid_items = GridContainer.new()
\t_grid_items.columns = 3
\t_grid_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_grid_items.add_theme_constant_override("h_separation", 10)
\t_grid_items.add_theme_constant_override("v_separation", 10)
\tscroll.add_child(_grid_items)"""

    new_consola_box = """\t_grid_items = GridContainer.new()
\t_grid_items.columns = 3
\t_grid_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_grid_items.add_theme_constant_override("h_separation", 10)
\t_grid_items.add_theme_constant_override("v_separation", 10)
\tscroll.add_child(_grid_items)
\t
\t# DOCK INFERIOR: Previsualización e Inspector Contextual Permanente (Cero Espacio Muerto)
\t_dock_preview_inferior = PanelContainer.new()
\t_dock_preview_inferior.name = "DockPreviewInferior"
\t_dock_preview_inferior.custom_minimum_size = Vector2(0, 270)
\t_estilar_panel_glass(_dock_preview_inferior, Color(0.05, 0.06, 0.08, 0.96), Color(0.78, 0.81, 0.85, 0.22), 12.0, 10.0)
\t_box_biblioteca.add_child(_dock_preview_inferior)"""

    if old_consola_box in content:
        content = content.replace(old_consola_box, new_consola_box, 1)

    # 3. Update _llenar_catalogo_ciudad (no redundant preview at top, calls dock at bottom)
    old_ciudad = """func _llenar_catalogo_ciudad() -> void:
\t_construir_panel_preview_3d(_panel_parametros)
\t_crear_barra_herramientas_objetos()
\tCargadorBiblioteca.inicializar()
\t_construir_filtros_apartados_edificaciones()
\t_refrescar_grid_edificaciones()"""

    new_ciudad = """func _llenar_catalogo_ciudad() -> void:
\tCargadorBiblioteca.inicializar()
\t_construir_filtros_apartados_edificaciones()
\t_refrescar_grid_edificaciones()"""

    if old_ciudad in content:
        content = content.replace(old_ciudad, new_ciudad, 1)

    # 4. Update _llenar_catalogo_vegetacion (call preview at bottom)
    old_veg_end = """\tif primer_id != "":
\t\t_resaltar_tarjeta_activa(primer_id)
\t\t_actualizar_preview_3d_objeto(primer_id)"""

    new_veg_end = """\tif primer_id != "":
\t\t_resaltar_tarjeta_activa(primer_id)
\t\t_actualizar_dock_preview_contextual("vegetacion", primer_id)"""

    if old_veg_end in content:
        content = content.replace(old_veg_end, new_veg_end, 1)

    # 5. In _refrescar_grid_edificaciones: update dock preview call
    old_refrescar_end = """\tif primer_id != "":
\t\t_id_item_activo = primer_id
\t\t_resaltar_tarjeta_activa(primer_id)
\t\t_actualizar_preview_3d_objeto(primer_id)
\t\tsubherramienta_seleccionada.emit(primer_id)"""

    new_refrescar_end = """\tif primer_id != "":
\t\t_id_item_activo = primer_id
\t\t_resaltar_tarjeta_activa(primer_id)
\t\t_actualizar_dock_preview_contextual("ciudad", primer_id)
\t\tsubherramienta_seleccionada.emit(primer_id)"""

    if old_refrescar_end in content:
        content = content.replace(old_refrescar_end, new_refrescar_end, 1)

    # 6. In _crear_tarjeta_item: wire to _actualizar_dock_preview_contextual
    old_card_click = """\tbtn.pressed.connect(func():
\t\t_id_item_activo = id
\t\t_resaltar_tarjeta_activa(id)
\t\tif _box_agua_lago_controles and is_instance_valid(_box_agua_lago_controles):
\t\t\t_box_agua_lago_controles.visible = (id == "lago_agua")
\t\tif _box_agua_rio_controles and is_instance_valid(_box_agua_rio_controles):
\t\t\t_box_agua_rio_controles.visible = (id == "rio_agua")
\t\tif _panel_preview_3d and is_instance_valid(_panel_preview_3d):
\t\t\t_actualizar_preview_3d_objeto(id)
\t\tsubherramienta_seleccionada.emit(id)
\t)"""

    new_card_click = """\tbtn.pressed.connect(func():
\t\t_id_item_activo = id
\t\t_resaltar_tarjeta_activa(id)
\t\tif _box_agua_lago_controles and is_instance_valid(_box_agua_lago_controles):
\t\t\t_box_agua_lago_controles.visible = (id == "lago_agua")
\t\tif _box_agua_rio_controles and is_instance_valid(_box_agua_rio_controles):
\t\t\t_box_agua_rio_controles.visible = (id == "rio_agua")
\t\t_actualizar_dock_preview_contextual(_categoria_activa, id)
\t\tsubherramienta_seleccionada.emit(id)
\t)"""

    if old_card_click in content:
        content = content.replace(old_card_click, new_card_click, 1)

    # 7. Add dock preview methods and helpers at the end of the catalog section
    dock_methods = """
# ── DOCK DE PREVISUALIZACIÓN E INSPECTOR TÉCNICO PERMANENTE ──────────
func _inicializar_subviewport_3d() -> void:
\tif _vp_container_preview != null and is_instance_valid(_vp_container_preview):
\t\treturn
\t\t
\t_vp_container_preview = SubViewportContainer.new()
\t_vp_container_preview.custom_minimum_size = Vector2(240, 160)
\t_vp_container_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_vp_container_preview.stretch = true
\t
\t_subviewport_preview = SubViewport.new()
\t_subviewport_preview.size = Vector2i(320, 160)
\t_subviewport_preview.transparent_bg = true
\t_subviewport_preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
\t_vp_container_preview.add_child(_subviewport_preview)
\t
\tvar world_3d := World3D.new()
\t_subviewport_preview.world_3d = world_3d
\t
\tvar env := Environment.new()
\tenv.background_mode = Environment.BG_CLEAR_COLOR
\tenv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
\tenv.ambient_light_color = Color(0.88, 0.90, 0.95)
\tenv.ambient_light_energy = 0.95
\tworld_3d.environment = env
\t
\t_camara_preview_3d = Camera3D.new()
\t_camara_preview_3d.current = true
\t_camara_preview_3d.fov = 34.0
\t_subviewport_preview.add_child(_camara_preview_3d)
\t_camara_preview_3d.look_at_from_position(Vector3(0, 4.2, 10.0), Vector3(0, 0, 0), Vector3.UP)
\t
\tvar light := DirectionalLight3D.new()
\tlight.rotation_degrees = Vector3(-45, 35, 0)
\tlight.light_energy = 1.3
\t_subviewport_preview.add_child(light)
\t
\t_pivote_preview_3d = Node3D.new()
\t_pivote_preview_3d.name = "PivotePreview"
\t_subviewport_preview.add_child(_pivote_preview_3d)

func _actualizar_dock_preview_contextual(categoria: String, id_item: String) -> void:
\tif not _dock_preview_inferior or not is_instance_valid(_dock_preview_inferior):
\t\treturn
\tmatch categoria:
\t\t"terreno":
\t\t\t_construir_preview_terreno(id_item)
\t\t"vias":
\t\t\t_construir_preview_vias(id_item)
\t\t"ciudad":
\t\t\t_construir_preview_3d_dock(categoria, id_item)
\t\t"vegetacion":
\t\t\t_construir_preview_3d_dock(categoria, id_item)
\t\t"agua":
\t\t\t_construir_preview_agua(id_item)
\t\t"spawn":
\t\t\t_construir_preview_spawn(id_item)

func _construir_preview_terreno(id_item: String) -> void:
\tfor c in _dock_preview_inferior.get_children():
\t\tc.queue_free()
\t\t
\tvar vbox := VBoxContainer.new()
\tvbox.add_theme_constant_override("separation", 6)
\t_dock_preview_inferior.add_child(vbox)
\t
\tvar hbox_hdr := HBoxContainer.new()
\tvbox.add_child(hbox_hdr)
\t
\tvar lbl_titulo := Label.new()
\tlbl_titulo.text = _obtener_nombre_herramienta_terreno(id_item).to_upper()
\tlbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tlbl_titulo.add_theme_font_size_override("font_size", 16)
\tlbl_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\tif _fuente_moderniz:
\t\tlbl_titulo.add_theme_font_override("font", _fuente_moderniz)
\thbox_hdr.add_child(lbl_titulo)
\t
\tvar badge_modo := Label.new()
\tbadge_modo.text = " [ MODO ESCULPIDO ] " if id_item in ["elevar", "bajar", "aplanar", "suavizar"] else " [ PINTURA PBR ] "
\tbadge_modo.add_theme_font_size_override("font_size", 12)
\tbadge_modo.add_theme_color_override("font_color", Color(0.2, 0.75, 0.95))
\thbox_hdr.add_child(badge_modo)
\t
\tvar panel_grafico := PanelContainer.new()
\tpanel_grafico.custom_minimum_size = Vector2(0, 100)
\t_estilar_panel_glass(panel_grafico, Color(0.04, 0.05, 0.07, 0.88), Color(0.78, 0.81, 0.85, 0.16), 8.0, 8.0)
\tvbox.add_child(panel_grafico)
\t
\tvar vbox_graf := VBoxContainer.new()
\tvbox_graf.alignment = BoxContainer.ALIGNMENT_CENTER
\tpanel_grafico.add_child(vbox_graf)
\t
\tvar lbl_graf_ico := Label.new()
\tlbl_graf_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_graf_ico.text = _obtener_grafico_perfil_terreno(id_item)
\tlbl_graf_ico.add_theme_font_size_override("font_size", 22)
\tvbox_graf.add_child(lbl_graf_ico)
\t
\tvar lbl_graf_desc := Label.new()
\tlbl_graf_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_graf_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tlbl_graf_desc.text = _obtener_descripcion_herramienta_terreno(id_item)
\tlbl_graf_desc.add_theme_font_size_override("font_size", 12)
\tlbl_graf_desc.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.90))
\tvbox_graf.add_child(lbl_graf_desc)
\t
\tvar hbox_falloff := HBoxContainer.new()
\thbox_falloff.add_theme_constant_override("separation", 6)
\tvbox.add_child(hbox_falloff)
\t
\tvar lbl_fall := Label.new()
\tlbl_fall.text = "PERFIL:"
\tlbl_fall.add_theme_font_size_override("font_size", 12)
\tlbl_fall.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.80))
\thbox_falloff.add_child(lbl_fall)
\t
\tvar perfiles = [
\t\t{"id": "suave", "txt": "⏺ Gaussiano Suave"},
\t\t{"id": "lineal", "txt": "⛰ Escarpado"},
\t\t{"id": "plano", "txt": "⏹ Plano"}
\t]
\tfor p in perfiles:
\t\tvar btn_p := Button.new()
\t\tbtn_p.text = p["txt"]
\t\tbtn_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tbtn_p.custom_minimum_size = Vector2(0, 34)
\t\tbtn_p.add_theme_font_size_override("font_size", 11)
\t\t_estilar_boton(btn_p, Color(0.08, 0.09, 0.12, 0.88), Color(0.78, 0.81, 0.85, 0.20), 8.0)
\t\tbtn_p.pressed.connect(func():
\t\t\tmostrar_notificacion("Perfil de pincel cambiado a: %s" % p["txt"])
\t\t)
\t\thbox_falloff.add_child(btn_p)
\t\t
\tvar lbl_atajo := Label.new()
\tlbl_atajo.text = "💡 Clic/Toque y arrastra en el mapa | Shift invierte a Bajar | Clic derecho: rotar cámara"
\tlbl_atajo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_atajo.add_theme_font_size_override("font_size", 11)
\tlbl_atajo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.75))
\tvbox.add_child(lbl_atajo)

func _construir_preview_vias(id_item: String) -> void:
\tfor c in _dock_preview_inferior.get_children():
\t\tc.queue_free()
\t\t
\tvar vbox := VBoxContainer.new()
\tvbox.add_theme_constant_override("separation", 6)
\t_dock_preview_inferior.add_child(vbox)
\t
\tvar hbox_hdr := HBoxContainer.new()
\tvbox.add_child(hbox_hdr)
\t
\tvar lbl_titulo := Label.new()
\tlbl_titulo.text = ("🛣️ " + id_item.replace("_", " ")).to_upper()
\tlbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tlbl_titulo.add_theme_font_size_override("font_size", 16)
\tlbl_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\tif _fuente_moderniz:
\t\tlbl_titulo.add_theme_font_override("font", _fuente_moderniz)
\thbox_hdr.add_child(lbl_titulo)
\t
\tvar panel_sec := PanelContainer.new()
\tpanel_sec.custom_minimum_size = Vector2(0, 100)
\t_estilar_panel_glass(panel_sec, Color(0.04, 0.05, 0.07, 0.88), Color(0.78, 0.81, 0.85, 0.16), 8.0, 8.0)
\tvbox.add_child(panel_sec)
\t
\tvar vbox_esq := VBoxContainer.new()
\tvbox_esq.alignment = BoxContainer.ALIGNMENT_CENTER
\tpanel_sec.add_child(vbox_esq)
\t
\tvar lbl_esq_graf := Label.new()
\tlbl_esq_graf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_esq_graf.text = _obtener_grafico_seccion_via(id_item)
\tlbl_esq_graf.add_theme_font_size_override("font_size", 20)
\tvbox_esq.add_child(lbl_esq_graf)
\t
\tvar lbl_esq_desc := Label.new()
\tlbl_esq_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_esq_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tlbl_esq_desc.text = _obtener_descripcion_seccion_via(id_item)
\tlbl_esq_desc.add_theme_font_size_override("font_size", 12)
\tlbl_esq_desc.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.90))
\tvbox_esq.add_child(lbl_esq_desc)
\t
\tvar hbox_badges := HBoxContainer.new()
\thbox_badges.add_theme_constant_override("separation", 6)
\tvbox.add_child(hbox_badges)
\t
\tvar specs: Array[String] = _obtener_specs_via(id_item)
\tfor sp in specs:
\t\tvar p_badge := PanelContainer.new()
\t\tp_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\t_estilar_panel_glass(p_badge, Color(0.08, 0.09, 0.12, 0.85), Color(0.88, 0.68, 0.28, 0.30), 6.0, 4.0)
\t\tvar l := Label.new()
\t\tl.text = sp
\t\tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t\tl.add_theme_font_size_override("font_size", 11)
\t\tl.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\t\tp_badge.add_child(l)
\t\thbox_badges.add_child(p_badge)
\t\t
\tvar lbl_guia := Label.new()
\tlbl_guia.text = "💡 Toca dos puntos en el terreno para trazar carretera con peralte y rasante automática."
\tlbl_guia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tlbl_guia.add_theme_font_size_override("font_size", 11)
\tlbl_guia.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.70))
\tvbox.add_child(lbl_guia)

func _construir_preview_3d_dock(categoria: String, id_modelo: String) -> void:
\tfor c in _dock_preview_inferior.get_children():
\t\tc.queue_free()
\t\t
\t_inicializar_subviewport_3d()
\t
\tvar vbox := VBoxContainer.new()
\tvbox.add_theme_constant_override("separation", 6)
\t_dock_preview_inferior.add_child(vbox)
\t
\tvar hbox_top := HBoxContainer.new()
\thbox_top.add_theme_constant_override("separation", 8)
\tvbox.add_child(hbox_top)
\t
\tvar vbox_tit := VBoxContainer.new()
\tvbox_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tvbox_tit.add_theme_constant_override("separation", 2)
\thbox_top.add_child(vbox_tit)
\t
\t_lbl_preview_titulo = Label.new()
\t_lbl_preview_titulo.text = id_modelo.to_upper().replace("_", " ")
\t_lbl_preview_titulo.add_theme_font_size_override("font_size", 16)
\t_lbl_preview_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\tif _fuente_moderniz:
\t\t_lbl_preview_titulo.add_theme_font_override("font", _fuente_moderniz)
\tvbox_tit.add_child(_lbl_preview_titulo)
\t
\t_lbl_preview_telemetria = Label.new()
\t_lbl_preview_telemetria.text = "CALCULANDO DIMENSIONES..."
\t_lbl_preview_telemetria.add_theme_font_size_override("font_size", 12)
\t_lbl_preview_telemetria.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.85))
\tvbox_tit.add_child(_lbl_preview_telemetria)
\t
\tif categoria == "ciudad":
\t\tvar btn_rotar := Button.new()
\t\tbtn_rotar.text = "⟳ ROTAR 45°"
\t\tbtn_rotar.custom_minimum_size = Vector2(125, 36)
\t\t_estilar_boton(btn_rotar, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 8.0)
\t\tbtn_rotar.add_theme_font_size_override("font_size", 12)
\t\tbtn_rotar.pressed.connect(func(): rotar_objeto_solicitado.emit())
\t\thbox_top.add_child(btn_rotar)
\t\t
\t\tvar btn_dem := Button.new()
\t\tbtn_dem.text = "🚜 DEMOLER"
\t\tbtn_dem.custom_minimum_size = Vector2(110, 36)
\t\t_estilar_boton(btn_dem, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 8.0)
\t\tbtn_dem.add_theme_font_size_override("font_size", 12)
\t\tbtn_dem.pressed.connect(func():
\t\t\tvar act = not (_btn_demoler.get_meta("activo", false) if _btn_demoler else false)
\t\t\tif _btn_demoler: _btn_demoler.set_meta("activo", act)
\t\t\t_modo_demolicion_activo = act
\t\t\tdemolicion_alternada.emit(act)
\t\t)
\t\thbox_top.add_child(btn_dem)
\t
\tvar marco_vp := PanelContainer.new()
\tmarco_vp.custom_minimum_size = Vector2(0, 160)
\tmarco_vp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_estilar_panel_glass(marco_vp, Color(0.04, 0.05, 0.06, 0.95), Color(0.88, 0.68, 0.28, 0.35), 8.0, 4.0)
\tvbox.add_child(marco_vp)
\t
\tif _vp_container_preview.get_parent():
\t\t_vp_container_preview.get_parent().remove_child(_vp_container_preview)
\tmarco_vp.add_child(_vp_container_preview)
\t
\t_actualizar_preview_3d_objeto(id_modelo)

func _construir_preview_agua(id_item: String) -> void:
\tfor c in _dock_preview_inferior.get_children():
\t\tc.queue_free()
\t\t
\tvar vbox := VBoxContainer.new()
\tvbox.add_theme_constant_override("separation", 6)
\t_dock_preview_inferior.add_child(vbox)
\t
\tvar lbl_titulo := Label.new()
\tlbl_titulo.text = "🌊 VISOR HIDRÁULICO: " + ("LAGO CONTINENTAL" if id_item == "lago_agua" else "RÍO DE MONTAÑA")
\tlbl_titulo.add_theme_font_size_override("font_size", 16)
\tlbl_titulo.add_theme_color_override("font_color", Color(0.2, 0.75, 0.95))
\tif _fuente_moderniz:
\t\tlbl_titulo.add_theme_font_override("font", _fuente_moderniz)
\tvbox.add_child(lbl_titulo)
\t
\tvar panel_aq := PanelContainer.new()
\tpanel_aq.custom_minimum_size = Vector2(0, 100)
\t_estilar_panel_glass(panel_aq, Color(0.04, 0.08, 0.12, 0.92), Color(0.2, 0.75, 0.95, 0.35), 8.0, 8.0)
\tvbox.add_child(panel_aq)
\t
\tvar v_in := VBoxContainer.new()
\tv_in.alignment = BoxContainer.ALIGNMENT_CENTER
\tpanel_aq.add_child(v_in)
\t
\tvar l_wave := Label.new()
\tl_wave.text = "〰 〰 〰 🌊 〰 〰 〰" if id_item == "lago_agua" else "🏞️ ⤹ ⤹ CORRIENTE FLUVIAL ⤹ ⤹ 🏞️"
\tl_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tl_wave.add_theme_font_size_override("font_size", 20)
\tv_in.add_child(l_wave)
\t
\tvar l_desc := Label.new()
\tl_desc.text = "Shader de agua con refracción, cáusticas y espuma en orillas." if id_item == "lago_agua" else "Generador de mallas curvas fluviales con excavación continua de cauce."
\tl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tl_desc.add_theme_font_size_override("font_size", 12)
\tl_desc.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.90))
\tv_in.add_child(l_desc)
\t
\tvar hbox_pres := HBoxContainer.new()
\thbox_pres.add_theme_constant_override("separation", 6)
\tvbox.add_child(hbox_pres)
\t
\tfor pr in ["💧 Laguna Cristalina", "🏞️ Río Andino", "🌿 Humedal Sabanero"]:
\t\tvar b := Button.new()
\t\tb.text = pr
\t\tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tb.custom_minimum_size = Vector2(0, 36)
\t\tb.add_theme_font_size_override("font_size", 11)
\t\t_estilar_boton(b, Color(0.08, 0.10, 0.14, 0.88), Color(0.2, 0.75, 0.95, 0.30), 8.0)
\t\tb.pressed.connect(func():
\t\t\tmostrar_notificacion("Preset acuático aplicado: " + pr)
\t\t)
\t\thbox_pres.add_child(b)

func _construir_preview_spawn(id_item: String) -> void:
\tfor c in _dock_preview_inferior.get_children():
\t\tc.queue_free()
\t\t
\tvar vbox := VBoxContainer.new()
\tvbox.add_theme_constant_override("separation", 6)
\t_dock_preview_inferior.add_child(vbox)
\t
\tvar lbl_titulo := Label.new()
\tlbl_titulo.text = "🏁 PUNTO DE PARTIDA Y SPAWN"
\tlbl_titulo.add_theme_font_size_override("font_size", 16)
\tlbl_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\tif _fuente_moderniz:
\t\tlbl_titulo.add_theme_font_override("font", _fuente_moderniz)
\tvbox.add_child(lbl_titulo)
\t
\tvar panel_sp := PanelContainer.new()
\tpanel_sp.custom_minimum_size = Vector2(0, 100)
\t_estilar_panel_glass(panel_sp, Color(0.04, 0.05, 0.07, 0.90), Color(0.88, 0.68, 0.28, 0.25), 8.0, 8.0)
\tvbox.add_child(panel_sp)
\t
\tvar v_in := VBoxContainer.new()
\tv_in.alignment = BoxContainer.ALIGNMENT_CENTER
\tpanel_sp.add_child(v_in)
\t
\tvar l_ico := Label.new()
\tl_ico.text = "🚛 VEHÍCULO INICIAL: KENWORTH T800" if id_item == "spawn_vehiculo" else "🚶 PEATÓN EN PRIMERA PERSONA"
\tl_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tl_ico.add_theme_font_size_override("font_size", 15)
\tl_ico.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
\tv_in.add_child(l_ico)
\t
\tvar l_desc := Label.new()
\tl_desc.text = "Fija la posición de reaparición y prueba con física real."
\tl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tl_desc.add_theme_font_size_override("font_size", 12)
\tl_desc.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.85))
\tv_in.add_child(l_desc)
\t
\tvar hbox_btn := HBoxContainer.new()
\thbox_btn.add_theme_constant_override("separation", 6)
\tvbox.add_child(hbox_btn)
\t
\tvar b_t800 := Button.new()
\tb_t800.text = "🚛 Mula T800"
\tb_t800.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tb_t800.custom_minimum_size = Vector2(0, 36)
\tb_t800.add_theme_font_size_override("font_size", 12)
\t_estilar_boton(b_t800, Color(0.88, 0.68, 0.28, 0.35), Color(0.88, 0.68, 0.28, 0.95), 8.0)
\thbox_btn.add_child(b_t800)
\t
\tvar b_cam := Button.new()
\tb_cam.text = "🚙 Camioneta"
\tb_cam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tb_cam.custom_minimum_size = Vector2(0, 36)
\tb_cam.add_theme_font_size_override("font_size", 12)
\t_estilar_boton(b_cam, Color(0.08, 0.09, 0.12, 0.88), Color(0.78, 0.81, 0.85, 0.20), 8.0)
\thbox_btn.add_child(b_cam)

func _obtener_nombre_herramienta_terreno(id: String) -> String:
\tmatch id:
\t\t"elevar": return "▲ Pincel Elevar Terreno"
\t\t"bajar": return "▼ Pincel Deprimir / Hundir"
\t\t"aplanar": return "▬ Pincel Aplanar Meseta"
\t\t"suavizar": return "〰 Pincel Suavizado Pendiente"
\t\t"cesped": return "🌱 Material Césped Sabanero PBR"
\t\t"tierra": return "🟫 Material Tierra Fértil PBR"
\t\t"roca": return "🪨 Material Risco / Roca Andina PBR"
\t\t"lago_agua": return "🌊 Herramienta Lago / Embalse"
\t\t"rio_agua": return "🏞️ Herramienta Río / Quebrada"
\t\t_: return id.capitalize()

func _obtener_grafico_perfil_terreno(id: String) -> String:
\tmatch id:
\t\t"elevar": return "⛰️   / ▔ ▔ ▔ ＼   ▲ (+Y)"
\t\t"bajar": return "🕳️   ＼ _ _ _ /   ▼ (-Y)"
\t\t"aplanar": return "⬛   | ▔ ▔ ▔ ▔ |   ▬ (Cota Fija)"
\t\t"suavizar": return "〰️   ~ ~ ~ ~ ~ ~   ≈ (Difuminado Bézier)"
\t\t"cesped": return "🌱  ☘️ ☘️ ☘️ CÉSPED ☘️ ☘️ ☘️"
\t\t"tierra": return "🟫  ░▒▓ TIERRA CORDAL ▓▒░"
\t\t"roca": return "🪨  ▲▲▲ ROCA RISCO ▲▲▲"
\t\t"lago_agua": return "🌊  ≈ ≈ ≈ EMBALSE ≈ ≈ ≈"
\t\t"rio_agua": return "🏞️  ⤹ ⤹ CAUCE FLUVIAL ⤹ ⤹"
\t\t_: return "✦ " + id

func _obtener_descripcion_herramienta_terreno(id: String) -> String:
\tmatch id:
\t\t"elevar": return "Eleva la topografía gradualmente aplicando un mapa de influencia gaussiano."
\t\t"bajar": return "Crea valles, depresiones y cauces reduciendo la cota de altura."
\t\t"aplanar": return "Mantiene una altura constante para crear plataformas de construcción o lotes."
\t\t"suavizar": return "Elimina aristas abruptas e imperfecciones calculando la media local."
\t\t"cesped": return "Pinta textura orgánica de pasto andino resistente con microrelieve."
\t\t"tierra": return "Aplica suelo fértil arcilloso ideal para orillas y caminos campesinos."
\t\t"roca": return "Pinta farallones y paredes rocosas de alta fricción para laderas pronunciadas."
\t\t"lago_agua": return "Excava y genera un espejo de agua con plano freático nivelado."
\t\t"rio_agua": return "Traza un río dinámico excavando el terreno con ancho y profundidad continua."
\t\t_: return "Herramienta de modificación topográfica."

func _obtener_grafico_seccion_via(id: String) -> String:
\tmatch id:
\t\t"calle_2": return "🚶 | 🚗 ⬅ | ➡ 🚙 | 🚶"
\t\t"avenida_4": return "🚶 | 🚗 🚗 | 🌳 | 🚗 🚗 | 🚶"
\t\t"autopista_6": return "🛡️ | 🏎️ 🏎️ 🏎️ | 🚧 | 🏎️ 🏎️ 🏎️ | 🛡️"
\t\t"trocha": return "🌾 |   🚜  BARRO / AFIRMADO  | 🌾"
\t\t"reductor_velocidad": return "⚠️   / ▔ ▔ ＼   [ RESALTO 7cm ]"
\t\t"cruce_4": return "➕ CRUCE ORTOGONAL 4 SENTIDOS"
\t\t"cruce_t": return "┳ EMPALME TIPO T CON PRIORIDAD"
\t\t"modificar_vias": return "📐 MANIPULADOR VECTORIAL DE VÍA"
\t\t"equipamiento_vias": return "🌉 VIADUCTO 4G Y MOBILIARIO"
\t\t_: return "🛣️ " + id

func _obtener_descripcion_seccion_via(id: String) -> String:
\tmatch id:
\t\t"calle_2": return "Vía urbana secundaria de 10m de calzada. 1 carril por sentido con andenes peatonales."
\t\t"avenida_4": return "Arteria urbana de 20m con separador central arborizado y capacidad de 4 carriles."
\t\t"autopista_6": return "Corredor de alta velocidad de 30m con barreras rígidas y bermas de seguridad."
\t\t"trocha": return "Camino veredal no pavimentado de 7m adaptado a la geografía de montaña."
\t\t"reductor_velocidad": return "Resalto reductor de velocidad reglamentario con franjas amarillas reflectivas."
\t\t"cruce_4": return "Intersección semaforizada o de prioridad para conectar 4 ramales viales."
\t\t"cruce_t": return "Intersección en T ideal para desvíos, retornos y accesos residenciales."
\t\t"modificar_vias": return "Selecciona nodos de la carretera para ajustar posición 3D, peralte y curvatura."
\t\t"equipamiento_vias": return "Configura pilares de viaducto, barandas metálicas de puente y bermas."
\t\t_: return "Especificación de infraestructura de transporte."

func _obtener_specs_via(id: String) -> Array[String]:
\tmatch id:
\t\t"calle_2": return ["📏 Ancho: 10m", "🏎️ Máx: 50 km/h", "🚶 Andén: 1.5m"]
\t\t"avenida_4": return ["📏 Ancho: 20m", "🏎️ Máx: 70 km/h", "🌳 Separador: 2m"]
\t\t"autopista_6": return ["📏 Ancho: 30m", "🏎️ Máx: 100 km/h", "🛡️ Berma: 2.5m"]
\t\t"trocha": return ["📏 Ancho: 7m", "🚜 Máx: 30 km/h", "🌾 Sin pavimentar"]
\t\t"reductor_velocidad": return ["📏 Largo: 3.8m", "⚠️ Altura: 7cm", "🛑 Máx: 20 km/h"]
\t\t"cruce_4": return ["🔀 4 Ramales", "📐 90° Ángulo", "🚦 Control Cruce"]
\t\t"cruce_t": return ["🔀 3 Ramales", "┳ Incorporación", "⚠️ Ceda el Paso"]
\t\t"modificar_vias": return ["📐 Modo Vector", "📍 Control 3D", "⟳ Peralte Bézier"]
\t\t"equipamiento_vias": return ["🌉 Viaducto 4G", "🧱 Hormigón", "🛡️ Barandas Metálicas"]
\t\t_: return ["🛣️ Estándar", "✓ Paramétrico"]
"""

    # Also update _llenar_catalogo_terreno, _llenar_catalogo_vias, _llenar_catalogo_agua, _llenar_catalogo_spawn to call _actualizar_dock_preview_contextual
    old_terreno_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("elevar")"""

    new_terreno_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("elevar")
\t_actualizar_dock_preview_contextual("terreno", "elevar")"""

    if old_terreno_end in content:
        content = content.replace(old_terreno_end, new_terreno_end, 1)

    old_vias_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("calle_2")"""

    new_vias_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("calle_2")
\t_actualizar_dock_preview_contextual("vias", "calle_2")"""

    if old_vias_end in content:
        content = content.replace(old_vias_end, new_vias_end, 1)

    old_agua_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("lago_agua")"""

    new_agua_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("lago_agua")
\t_actualizar_dock_preview_contextual("agua", "lago_agua")"""

    if old_agua_end in content:
        content = content.replace(old_agua_end, new_agua_end, 1)

    old_spawn_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("spawn_vehiculo")"""

    new_spawn_end = """\tfor it in items:
\t\t_crear_tarjeta_item(it["id"], it["fallback"], it["nombre"], it["svg"])
\t_resaltar_tarjeta_activa("spawn_vehiculo")
\t_actualizar_dock_preview_contextual("spawn", "spawn_vehiculo")"""

    if old_spawn_end in content:
        content = content.replace(old_spawn_end, new_spawn_end, 1)

    # Insert dock_methods before func _actualizar_preview_3d_objeto
    target_pos = content.find("func _actualizar_preview_3d_objeto")
    assert target_pos != -1, "func _actualizar_preview_3d_objeto not found"
    content = content[:target_pos] + dock_methods + "\n" + content[target_pos:]

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Preview dock upgrade applied successfully!")

if __name__ == "__main__":
    apply_preview_dock()
