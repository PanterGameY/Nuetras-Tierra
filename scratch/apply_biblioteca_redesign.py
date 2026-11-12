import re

def update_ui_editor():
    path = r"c:\Users\johan\OneDrive\Documentos\GitHub\nuestra-tierra-2.0\mundo\editor_mapas\UIEditorMapas.gd"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Variables
    old_vars = """# 3. Consola Lateral Derecha (Catálogo y Parámetros)
var _panel_consola: PanelContainer"""
    new_vars = """# 3. Consola Lateral Derecha (Catálogo y Parámetros — Workstation Pro)
const ANCHO_CONSOLA_ESTANDAR: float = 780.0
const ANCHO_CONSOLA_WORKSTATION: float = 1120.0
var _modo_workstation_expandido: bool = false
var _btn_toggle_workstation: Button = null
var _texto_busqueda_catalogo: String = ""
var _wrapper_subapartados: VBoxContainer = null

var _panel_consola: PanelContainer"""
    if old_vars in content:
        content = content.replace(old_vars, new_vars, 1)

    # 2. _construir_dock_accion_maestro
    old_dock = """func _construir_dock_accion_maestro(padre: Control) -> void:
\t_dock_accion_maestro = PanelContainer.new()
\t_dock_accion_maestro.name = "DockAccionMaestro"
\t_dock_accion_maestro.anchor_left = 1.0
\t_dock_accion_maestro.anchor_right = 1.0
\t_dock_accion_maestro.anchor_top = 1.0
\t_dock_accion_maestro.anchor_bottom = 1.0
\t_dock_accion_maestro.offset_left = -456.0
\t_dock_accion_maestro.offset_right = -16.0
\t_dock_accion_maestro.offset_top = -102.0
\t_dock_accion_maestro.offset_bottom = -16.0"""

    new_dock = """func _construir_dock_accion_maestro(padre: Control) -> void:
\t_dock_accion_maestro = PanelContainer.new()
\t_dock_accion_maestro.name = "DockAccionMaestro"
\t_dock_accion_maestro.anchor_left = 1.0
\t_dock_accion_maestro.anchor_right = 1.0
\t_dock_accion_maestro.anchor_top = 1.0
\t_dock_accion_maestro.anchor_bottom = 1.0
\t_dock_accion_maestro.offset_left = -(ANCHO_CONSOLA_ESTANDAR + 16.0)
\t_dock_accion_maestro.offset_right = -16.0
\t_dock_accion_maestro.offset_top = -102.0
\t_dock_accion_maestro.offset_bottom = -16.0"""
    if old_dock in content:
        content = content.replace(old_dock, new_dock, 1)

    # 3. _construir_consola_derecha y colapso
    old_consola = """# ── 3. CONSOLA LATERAL DERECHA UNIFICADA (440px — CATÁLOGO E INSPECTORES) ──
func _construir_consola_derecha(padre: Control) -> void:
\t_panel_consola = PanelContainer.new()
\t_panel_consola.name = "ConsolaLateral"
\t_panel_consola.anchor_left = 1.0
\t_panel_consola.anchor_right = 1.0
\t_panel_consola.anchor_top = 0.0
\t_panel_consola.anchor_bottom = 1.0
\t_panel_consola.offset_left = -456.0
\t_panel_consola.offset_right = -16.0
\t_panel_consola.offset_top = 96.0
\t_panel_consola.offset_bottom = -112.0
\t_panel_consola.mouse_filter = Control.MOUSE_FILTER_STOP
\t_estilar_panel_glass(_panel_consola, Color(0.06, 0.07, 0.08, 0.94), Color(0.78, 0.81, 0.85, 0.24))
\tpadre.add_child(_panel_consola)
\t
\t_btn_colapsar = Button.new()
\t_btn_colapsar.name = "BtnColapsar"
\t_btn_colapsar.text = "❯"
\t_btn_colapsar.custom_minimum_size = Vector2(48, 84)
\t_btn_colapsar.position = Vector2(-50, 20)
\t_estilar_boton(_btn_colapsar, Color(0.09, 0.10, 0.12, 0.92))
\t_btn_colapsar.add_theme_font_size_override("font_size", 24)
\t_btn_colapsar.pressed.connect(_alternar_colapso)
\t_panel_consola.add_child(_btn_colapsar)
\t
\tvar vbox_drawer := VBoxContainer.new()
\tvbox_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tvbox_drawer.add_theme_constant_override("separation", 8)
\t_panel_consola.add_child(vbox_drawer)
\t
\t# VISTA A: Biblioteca / Catálogo de objetos
\t_box_biblioteca = VBoxContainer.new()
\t_box_biblioteca.name = "BoxBiblioteca"
\t_box_biblioteca.size_flags_vertical = Control.SIZE_EXPAND_FILL
\t_box_biblioteca.add_theme_constant_override("separation", 8)
\tvbox_drawer.add_child(_box_biblioteca)
\t
\t_panel_parametros = VBoxContainer.new()
\t_panel_parametros.add_theme_constant_override("separation", 6)
\t_box_biblioteca.add_child(_panel_parametros)
\t
\tvar scroll := ScrollContainer.new()
\tscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\tscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
\t_box_biblioteca.add_child(scroll)
\t
\t_grid_items = GridContainer.new()
\t_grid_items.columns = 2
\t_grid_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_grid_items.add_theme_constant_override("h_separation", 8)
\t_grid_items.add_theme_constant_override("v_separation", 8)
\tscroll.add_child(_grid_items)
\t
\t# VISTA B: Inspector de Objeto Seleccionado (Integrado en el Drawer)
\t_construir_seccion_inspector_objeto(vbox_drawer)
\t# VISTAS C, D, E: Inspectores de Cruce, Punto de Vía y Equipamiento (Integrados en el Drawer, sin paneles flotantes gigantes)
\t_construir_hojas_contextuales(vbox_drawer)

func _alternar_colapso() -> void:
\t_esta_colapsado = not _esta_colapsado
\t_btn_colapsar.text = "❮" if _esta_colapsado else "❯"
\t
\tvar tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
\tif _esta_colapsado:
\t\ttween.tween_property(_panel_consola, "offset_left", -48.0, 0.25)
\t\ttween.parallel().tween_property(_panel_consola, "offset_right", 392.0, 0.25)
\telse:
\t\ttween.tween_property(_panel_consola, "offset_left", -456.0, 0.25)
\t\ttween.parallel().tween_property(_panel_consola, "offset_right", -16.0, 0.25)"""

    new_consola = """# ── 3. CONSOLA LATERAL DERECHA UNIFICADA (WORKSTATION PRO: 780px / 1120px) ──
func _construir_consola_derecha(padre: Control) -> void:
\t_panel_consola = PanelContainer.new()
\t_panel_consola.name = "ConsolaLateral"
\t_panel_consola.anchor_left = 1.0
\t_panel_consola.anchor_right = 1.0
\t_panel_consola.anchor_top = 0.0
\t_panel_consola.anchor_bottom = 1.0
\t_panel_consola.offset_left = -(ANCHO_CONSOLA_ESTANDAR + 16.0)
\t_panel_consola.offset_right = -16.0
\t_panel_consola.offset_top = 92.0
\t_panel_consola.offset_bottom = -108.0
\t_panel_consola.mouse_filter = Control.MOUSE_FILTER_STOP
\t_estilar_panel_glass(_panel_consola, Color(0.06, 0.07, 0.08, 0.95), Color(0.78, 0.81, 0.85, 0.24))
\tpadre.add_child(_panel_consola)
\t
\t_btn_colapsar = Button.new()
\t_btn_colapsar.name = "BtnColapsar"
\t_btn_colapsar.text = "❯"
\t_btn_colapsar.custom_minimum_size = Vector2(48, 84)
\t_btn_colapsar.position = Vector2(-50, 20)
\t_estilar_boton(_btn_colapsar, Color(0.09, 0.10, 0.12, 0.92))
\t_btn_colapsar.add_theme_font_size_override("font_size", 24)
\t_btn_colapsar.pressed.connect(_alternar_colapso)
\t_panel_consola.add_child(_btn_colapsar)
\t
\tvar vbox_drawer := VBoxContainer.new()
\tvbox_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tvbox_drawer.add_theme_constant_override("separation", 10)
\t_panel_consola.add_child(vbox_drawer)
\t
\t# VISTA A: Biblioteca / Catálogo de objetos
\t_box_biblioteca = VBoxContainer.new()
\t_box_biblioteca.name = "BoxBiblioteca"
\t_box_biblioteca.size_flags_vertical = Control.SIZE_EXPAND_FILL
\t_box_biblioteca.add_theme_constant_override("separation", 8)
\tvbox_drawer.add_child(_box_biblioteca)
\t
\t_panel_parametros = VBoxContainer.new()
\t_panel_parametros.add_theme_constant_override("separation", 8)
\t_box_biblioteca.add_child(_panel_parametros)
\t
\tvar scroll := ScrollContainer.new()
\tscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
\tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\tscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
\t_box_biblioteca.add_child(scroll)
\t
\t_grid_items = GridContainer.new()
\t_grid_items.columns = 3
\t_grid_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_grid_items.add_theme_constant_override("h_separation", 10)
\t_grid_items.add_theme_constant_override("v_separation", 10)
\tscroll.add_child(_grid_items)
\t
\t# VISTA B: Inspector de Objeto Seleccionado (Integrado en el Drawer)
\t_construir_seccion_inspector_objeto(vbox_drawer)
\t# VISTAS C, D, E: Inspectores de Cruce, Punto de Vía y Equipamiento
\t_construir_hojas_contextuales(vbox_drawer)

func _alternar_colapso() -> void:
\t_esta_colapsado = not _esta_colapsado
\t_btn_colapsar.text = "❮" if _esta_colapsado else "❯"
\t
\tvar ancho_actual: float = ANCHO_CONSOLA_WORKSTATION if _modo_workstation_expandido else ANCHO_CONSOLA_ESTANDAR
\tvar tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
\tif _esta_colapsado:
\t\ttween.tween_property(_panel_consola, "offset_left", -48.0, 0.25)
\t\ttween.parallel().tween_property(_panel_consola, "offset_right", ancho_actual - 48.0, 0.25)
\t\tif _dock_accion_maestro:
\t\t\ttween.parallel().tween_property(_dock_accion_maestro, "offset_left", -48.0, 0.25)
\t\t\ttween.parallel().tween_property(_dock_accion_maestro, "offset_right", ancho_actual - 48.0, 0.25)
\telse:
\t\ttween.tween_property(_panel_consola, "offset_left", -(ancho_actual + 16.0), 0.25)
\t\ttween.parallel().tween_property(_panel_consola, "offset_right", -16.0, 0.25)
\t\tif _dock_accion_maestro:
\t\t\ttween.parallel().tween_property(_dock_accion_maestro, "offset_left", -(ancho_actual + 16.0), 0.25)
\t\t\ttween.parallel().tween_property(_dock_accion_maestro, "offset_right", -16.0, 0.25)

func _alternar_modo_workstation() -> void:
\t_modo_workstation_expandido = not _modo_workstation_expandido
\tvar ancho_nuevo: float = ANCHO_CONSOLA_WORKSTATION if _modo_workstation_expandido else ANCHO_CONSOLA_ESTANDAR
\t_grid_items.columns = 4 if _modo_workstation_expandido else 3
\t
\tif _btn_toggle_workstation:
\t\t_btn_toggle_workstation.text = "🗗 COMPACTAR" if _modo_workstation_expandido else "⛶ WORKSTATION"
\t\tif _modo_workstation_expandido:
\t\t\t_estilar_boton(_btn_toggle_workstation, Color(0.88, 0.68, 0.28, 0.95))
\t\t\t_btn_toggle_workstation.add_theme_color_override("font_color", Color(0.06, 0.07, 0.08))
\t\telse:
\t\t\t_estilar_boton(_btn_toggle_workstation, Color(0.12, 0.14, 0.18, 0.90))
\t\t\t_btn_toggle_workstation.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85))
\t\t\t
\tif not _esta_colapsado:
\t\tvar tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
\t\ttween.tween_property(_panel_consola, "offset_left", -(ancho_nuevo + 16.0), 0.25)
\t\ttween.parallel().tween_property(_panel_consola, "offset_right", -16.0, 0.25)
\t\tif _dock_accion_maestro:
\t\t\ttween.parallel().tween_property(_dock_accion_maestro, "offset_left", -(ancho_nuevo + 16.0), 0.25)
\t\t\ttween.parallel().tween_property(_dock_accion_maestro, "offset_right", -16.0, 0.25)"""
    if old_consola in content:
        content = content.replace(old_consola, new_consola, 1)

    # 4. _construir_filtros_apartados_edificaciones
    old_filtros_pat = re.compile(r"## Construye la barra de pestañas y subapartados de la Biblioteca\s+func _construir_filtros_apartados_edificaciones\(\) -> void:.*?subherramienta_seleccionada\.emit\(primer_id\)", re.DOTALL)

    new_filtros = """## Construye la barra de pestañas, búsqueda y subapartados de la Biblioteca (Workstation Grade)
func _construir_filtros_apartados_edificaciones() -> void:
\t_dict_btn_secciones_edif.clear()
\t_dict_btn_subapartados_edif.clear()
\t
\t_box_filtros_edificaciones = VBoxContainer.new()
\t_box_filtros_edificaciones.name = "BoxFiltrosEdificaciones"
\t_box_filtros_edificaciones.add_theme_constant_override("separation", 10)
\t_panel_parametros.add_child(_box_filtros_edificaciones)
\t
\t# 1. Barra de Búsqueda Rápida en el Catálogo
\tvar hbox_search := HBoxContainer.new()
\thbox_search.add_theme_constant_override("separation", 6)
\t_box_filtros_edificaciones.add_child(hbox_search)
\t
\tvar input_busqueda := LineEdit.new()
\tinput_busqueda.placeholder_text = "🔍 Buscar modelo (chalet, colonial, edificio, hacienda...)"
\tinput_busqueda.custom_minimum_size = Vector2(0, 42)
\tinput_busqueda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tinput_busqueda.add_theme_font_size_override("font_size", 14)
\tinput_busqueda.clear_button_enabled = true
\tvar sb_input := StyleBoxFlat.new()
\tsb_input.bg_color = Color(0.08, 0.09, 0.12, 0.92)
\tsb_input.border_width_left = 1
\tsb_input.border_width_top = 1
\tsb_input.border_width_right = 1
\tsb_input.border_width_bottom = 1
\tsb_input.border_color = Color(0.78, 0.81, 0.85, 0.25)
\tsb_input.corner_radius_top_left = 10
\tsb_input.corner_radius_top_right = 10
\tsb_input.corner_radius_bottom_right = 10
\tsb_input.corner_radius_bottom_left = 10
\tsb_input.content_margin_left = 12
\tsb_input.content_margin_right = 12
\tinput_busqueda.add_theme_stylebox_override("normal", sb_input)
\tinput_busqueda.text_changed.connect(func(nuevo_txt: String):
\t\t_texto_busqueda_catalogo = nuevo_txt.strip_edges().to_lower()
\t\t_refrescar_grid_edificaciones()
\t)
\thbox_search.add_child(input_busqueda)
\t
\t# 2. Header de Secciones Principales
\tvar hbox_sec_hdr := HBoxContainer.new()
\t_box_filtros_edificaciones.add_child(hbox_sec_hdr)
\t
\tvar lbl_sec := Label.new()
\tlbl_sec.text = "🏛️ SECCIONES DE LA BIBLIOTECA"
\tlbl_sec.add_theme_font_size_override("font_size", 13)
\tlbl_sec.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.98))
\tif _fuente_moderniz:
\t\tlbl_sec.add_theme_font_override("font", _fuente_moderniz)
\thbox_sec_hdr.add_child(lbl_sec)
\t
\t# Grilla de Secciones (2 filas de 3 botones) — CERO SCROLLBARS HORIZONTALES
\tvar grid_sec := GridContainer.new()
\tgrid_sec.columns = 3
\tgrid_sec.add_theme_constant_override("h_separation", 8)
\tgrid_sec.add_theme_constant_override("v_separation", 6)
\tgrid_sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_box_filtros_edificaciones.add_child(grid_sec)
\t
\tvar secciones_def: Array[Dictionary] = [
\t\t{"id": "01_Residencial", "nombre": "Residencial", "icono": "🏠"},
\t\t{"id": "02_Comercial", "nombre": "Comercial", "icono": "🏪"},
\t\t{"id": "03_Industrial_Logistica", "nombre": "Industrial", "icono": "🏭"},
\t\t{"id": "04_Servicios_Publicos", "nombre": "Servicios", "icono": "🏛️"},
\t\t{"id": "05_Rural_Agropecuario", "nombre": "Rural / Fincas", "icono": "🚜"},
\t\t{"id": "todas", "nombre": "Todas", "icono": "🌟"}
\t]
\t
\tfor s in secciones_def:
\t\tvar btn_s := Button.new()
\t\tbtn_s.text = "%s %s" % [s["icono"], s["nombre"]]
\t\tbtn_s.custom_minimum_size = Vector2(0, 44)
\t\tbtn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tbtn_s.add_theme_font_size_override("font_size", 13)
\t\t_estilar_boton(btn_s, Color(0.08, 0.09, 0.12, 0.88), Color(0.78, 0.81, 0.85, 0.22), 10.0)
\t\t
\t\tvar sec_id: String = s["id"]
\t\tbtn_s.pressed.connect(func():
\t\t\t_seccion_biblioteca_activa = sec_id
\t\t\t_subapartado_biblioteca_activa = "todos"
\t\t\t_actualizar_botones_secciones_edif()
\t\t\t_actualizar_botones_subapartados_edif()
\t\t\t_refrescar_grid_edificaciones()
\t\t)
\t\tgrid_sec.add_child(btn_s)
\t\t_dict_btn_secciones_edif[sec_id] = btn_s
\t
\t# 3. Contenedor Envoltorio de Subapartados (Carpetas internas)
\t_wrapper_subapartados = VBoxContainer.new()
\t_wrapper_subapartados.add_theme_constant_override("separation", 6)
\t_box_filtros_edificaciones.add_child(_wrapper_subapartados)
\t
\t_lbl_subapartados_header = Label.new()
\t_lbl_subapartados_header.text = "📁 CARPETAS / SUB-APARTADOS"
\t_lbl_subapartados_header.add_theme_font_size_override("font_size", 12)
\t_lbl_subapartados_header.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.85))
\t_wrapper_subapartados.add_child(_lbl_subapartados_header)
\t
\t_box_subapartados_container = HFlowContainer.new()
\t_box_subapartados_container.add_theme_constant_override("h_separation", 8)
\t_box_subapartados_container.add_theme_constant_override("v_separation", 6)
\t_box_subapartados_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t_wrapper_subapartados.add_child(_box_subapartados_container)
\t
\t_actualizar_botones_secciones_edif()
\t_actualizar_botones_subapartados_edif()

## Actualiza el resaltado visual de las pestañas de Secciones
func _actualizar_botones_secciones_edif() -> void:
\tfor id in _dict_btn_secciones_edif:
\t\tvar btn: Button = _dict_btn_secciones_edif[id]
\t\tif id == _seccion_biblioteca_activa:
\t\t\t_estilar_boton(btn, Color(0.88, 0.68, 0.28, 0.35), Color(0.88, 0.68, 0.28, 0.95), 10.0)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
\t\telse:
\t\t\t_estilar_boton(btn, Color(0.08, 0.09, 0.12, 0.88), Color(0.78, 0.81, 0.85, 0.22), 10.0)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85))

## Actualiza la lista dinámica de subapartados según la sección activa
func _actualizar_botones_subapartados_edif() -> void:
\tif not _box_subapartados_container:
\t\treturn
\tfor c in _box_subapartados_container.get_children():
\t\tc.queue_free()
\t_dict_btn_subapartados_edif.clear()
\t
\tif _seccion_biblioteca_activa == "todas":
\t\tif _lbl_subapartados_header:
\t\t\t_lbl_subapartados_header.visible = false
\t\tif _box_subapartados_container.get_parent():
\t\t\t_box_subapartados_container.get_parent().visible = false
\t\treturn
\t\t
\tif _lbl_subapartados_header:
\t\t_lbl_subapartados_header.visible = true
\tif _box_subapartados_container.get_parent():
\t\t_box_subapartados_container.get_parent().visible = true
\t
\tvar subapartados = CargadorBiblioteca.obtener_subapartados_de_seccion("01_Edificaciones", _seccion_biblioteca_activa)
\tvar total_sec = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", _seccion_biblioteca_activa, "todos").size()
\tvar lista_subs: Array[Dictionary] = [{"id": "todos", "nombre": "Todos", "icono": "🌟", "conteo": total_sec}]
\tfor sub in subapartados:
\t\tvar n_sub = sub.duplicate()
\t\tvar cant = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", _seccion_biblioteca_activa, sub["id"]).size()
\t\tn_sub["conteo"] = cant
\t\tlista_subs.append(n_sub)
\t
\tfor sub in lista_subs:
\t\tvar btn := Button.new()
\t\tvar cant: int = sub.get("conteo", 0)
\t\tbtn.text = "%s %s (%d)" % [sub["icono"], sub["nombre"], cant]
\t\tbtn.custom_minimum_size = Vector2(0, 36)
\t\tbtn.add_theme_font_size_override("font_size", 12)
\t\t_estilar_boton(btn, Color(0.07, 0.08, 0.10, 0.85), Color(0.78, 0.81, 0.85, 0.18), 14.0)
\t\t
\t\tvar sub_id: String = sub["id"]
\t\tbtn.pressed.connect(func():
\t\t\t_subapartado_biblioteca_activa = sub_id
\t\t\t_actualizar_estilo_subapartados_edif()
\t\t\t_refrescar_grid_edificaciones()
\t\t)
\t\t_box_subapartados_container.add_child(btn)
\t\t_dict_btn_subapartados_edif[sub_id] = btn
\t\t
\t_actualizar_estilo_subapartados_edif()

func _actualizar_estilo_subapartados_edif() -> void:
\tfor id in _dict_btn_subapartados_edif:
\t\tvar btn: Button = _dict_btn_subapartados_edif[id]
\t\tif id == _subapartado_biblioteca_activa:
\t\t\t_estilar_boton(btn, Color(0.88, 0.68, 0.28, 0.35), Color(0.88, 0.68, 0.28, 0.95), 14.0)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.98, 0.92, 0.75))
\t\telse:
\t\t\t_estilar_boton(btn, Color(0.07, 0.08, 0.10, 0.85), Color(0.78, 0.81, 0.85, 0.18), 14.0)
\t\t\tbtn.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))

## Refresca la grilla de items filtrada con los apartados y carpetas seleccionadas
func _refrescar_grid_edificaciones() -> void:
\tfor c in _grid_items.get_children():
\t\tc.queue_free()
\t_dict_tarjetas_items.clear()
\t
\tvar items: Array[Dictionary] = []
\tif _seccion_biblioteca_activa == "todas":
\t\titems = CargadorBiblioteca.obtener_items_por_categoria("01_Edificaciones")
\t\tfor c_extra in ["02_Monumentos_Hitos", "03_Accesorios_Viales", "04_Mobiliario_Urbano", "06_Infraestructura_Transporte", "07_Plantillas_y_Kits"]:
\t\t\titems.append_array(CargadorBiblioteca.obtener_items_por_categoria(c_extra))
\telse:
\t\titems = CargadorBiblioteca.obtener_items_filtrados("01_Edificaciones", _seccion_biblioteca_activa, _subapartado_biblioteca_activa)
\t
\t# Filtro en tiempo real por búsqueda de texto
\tif _texto_busqueda_catalogo != "":
\t\tvar filtrados: Array[Dictionary] = []
\t\tfor it in items:
\t\t\tvar nom: String = it.get("nombre", "").to_lower()
\t\t\tvar id_str: String = it.get("id", "").to_lower()
\t\t\tvar sub_str: String = it.get("subapartado", "").to_lower()
\t\t\tif nom.contains(_texto_busqueda_catalogo) or id_str.contains(_texto_busqueda_catalogo) or sub_str.contains(_texto_busqueda_catalogo):
\t\t\t\tfiltrados.append(it)
\t\titems = filtrados
\t\t
\tif items.is_empty():
\t\tvar lbl_vacio := Label.new()
\t\tlbl_vacio.text = "🔍 No se encontraron modelos en esta sección." if _texto_busqueda_catalogo == "" else "🔍 Sin coincidencias para '%s'" % _texto_busqueda_catalogo
\t\tlbl_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t\tlbl_vacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tlbl_vacio.custom_minimum_size = Vector2(0, 80)
\t\tlbl_vacio.add_theme_font_size_override("font_size", 15)
\t\tlbl_vacio.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.70))
\t\t_grid_items.add_child(lbl_vacio)
\t\treturn
\t
\tvar primer_id := ""
\tfor it in items:
\t\tif primer_id == "":
\t\t\tprimer_id = it["id"]
\t\tvar tex_ico: String = it.get("icono_textura", "")
\t\tvar sub_txt: String = it.get("subapartado", "").replace("_", " ")
\t\tvar dim = it.get("dimensiones", Vector3.ZERO)
\t\tvar dim_str: String = ""
\t\tif dim is Vector3 and dim != Vector3.ZERO:
\t\t\tdim_str = " · %.1fm" % dim.y
\t\t_crear_tarjeta_item(it["id"], it.get("icono", "🏢"), it["nombre"], "", tex_ico, sub_txt + dim_str)
\t\t
\tif primer_id != "":
\t\t_id_item_activo = primer_id
\t\t_resaltar_tarjeta_activa(primer_id)
\t\t_actualizar_preview_3d_objeto(primer_id)
\t\tsubherramienta_seleccionada.emit(primer_id)"""

    match = old_filtros_pat.search(content)
    if match is not None:
        content = content[:match.start()] + new_filtros + content[match.end():]
    else:
        print("Warning: old_filtros_pat not matched, checking if already updated...")

    # 5. _construir_panel_preview_3d y _actualizar_preview_3d_objeto
    old_preview_pat = re.compile(r"func _construir_panel_preview_3d\(padre: Control\) -> void:.*?_camara_preview_3d\.look_at_from_position\(\s+Vector3\(0\.0, centro_y \+ 0\.5, distancia\),\s+Vector3\(0\.0, centro_y, 0\.0\),\s+Vector3\.UP\s+\)", re.DOTALL)

    new_preview = """func _construir_panel_preview_3d(padre: Control) -> void:
\t_panel_preview_3d = PanelContainer.new()
\t_panel_preview_3d.name = "PanelPreview3D"
\t_estilar_panel_glass(_panel_preview_3d, Color(0.08, 0.09, 0.11, 0.94), Color(0.78, 0.81, 0.85, 0.22), 14.0, 10.0)
\tpadre.add_child(_panel_preview_3d)
\t
\tvar vbox_outer := VBoxContainer.new()
\tvbox_outer.add_theme_constant_override("separation", 6)
\t_panel_preview_3d.add_child(vbox_outer)
\t
\tvar hbox_top := HBoxContainer.new()
\thbox_top.add_theme_constant_override("separation", 8)
\tvbox_outer.add_child(hbox_top)
\t
\tvar vbox_info := VBoxContainer.new()
\tvbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\tvbox_info.add_theme_constant_override("separation", 2)
\thbox_top.add_child(vbox_info)
\t
\t_lbl_preview_titulo = Label.new()
\t_lbl_preview_titulo.text = "SELECCIONA UN OBJETO"
\tif _fuente_moderniz:
\t\t_lbl_preview_titulo.add_theme_font_override("font", _fuente_moderniz)
\t_lbl_preview_titulo.add_theme_font_size_override("font_size", 18)
\t_lbl_preview_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
\tvbox_info.add_child(_lbl_preview_titulo)
\t
\t_lbl_preview_telemetria = Label.new()
\t_lbl_preview_telemetria.text = "ALT: -- | ANCHO: --"
\t_lbl_preview_telemetria.add_theme_font_size_override("font_size", 13)
\t_lbl_preview_telemetria.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.85))
\tvbox_info.add_child(_lbl_preview_telemetria)
\t
\t# Botón Toggle Vista 3D
\tvar btn_toggle_3d := Button.new()
\tbtn_toggle_3d.text = "👁 OCULTAR 3D" if _preview_3d_expandido else "👁 VER 3D"
\tbtn_toggle_3d.custom_minimum_size = Vector2(115, 40)
\t_estilar_boton(btn_toggle_3d, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 10.0)
\tbtn_toggle_3d.add_theme_font_size_override("font_size", 13)
\thbox_top.add_child(btn_toggle_3d)
\t
\t# Botón Toggle Modo Workstation (780px / 1120px)
\t_btn_toggle_workstation = Button.new()
\t_btn_toggle_workstation.text = "⛶ WORKSTATION"
\t_btn_toggle_workstation.tooltip_text = "Alternar entre modo estándar (780px) y estación amplia (1120px)"
\t_btn_toggle_workstation.custom_minimum_size = Vector2(148, 40)
\t_estilar_boton(_btn_toggle_workstation, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 10.0)
\t_btn_toggle_workstation.add_theme_font_size_override("font_size", 13)
\t_btn_toggle_workstation.pressed.connect(_alternar_modo_workstation)
\thbox_top.add_child(_btn_toggle_workstation)
\t
\tvar marco_vp := PanelContainer.new()
\tmarco_vp.visible = _preview_3d_expandido
\tmarco_vp.custom_minimum_size = Vector2(0, 150)
\t_estilar_panel_glass(marco_vp, Color(0.04, 0.05, 0.06, 0.95), Color(0.88, 0.68, 0.28, 0.35), 10.0, 4.0)
\tvbox_outer.add_child(marco_vp)
\t
\tbtn_toggle_3d.pressed.connect(func():
\t\t_preview_3d_expandido = not _preview_3d_expandido
\t\tmarco_vp.visible = _preview_3d_expandido
\t\tbtn_toggle_3d.text = "👁 OCULTAR 3D" if _preview_3d_expandido else "👁 VER 3D"
\t)
\t
\tvar vp_cont := SubViewportContainer.new()
\tvp_cont.custom_minimum_size = Vector2(240, 140)
\tvp_cont.stretch = true
\tmarco_vp.add_child(vp_cont)
\t
\t_subviewport_preview = SubViewport.new()
\t_subviewport_preview.size = Vector2i(240, 140)
\t_subviewport_preview.transparent_bg = true
\t_subviewport_preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
\tvp_cont.add_child(_subviewport_preview)
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
\t_camara_preview_3d.position = Vector3(0, 4.2, 10.0)
\t_camara_preview_3d.look_at(Vector3(0, 0, 0), Vector3.UP)
\t_subviewport_preview.add_child(_camara_preview_3d)
\t
\tvar light := DirectionalLight3D.new()
\tlight.rotation_degrees = Vector3(-45, 35, 0)
\tlight.light_energy = 1.3
\t_subviewport_preview.add_child(light)
\t
\t_pivote_preview_3d = Node3D.new()
\t_pivote_preview_3d.name = "PivotePreview"
\t_subviewport_preview.add_child(_pivote_preview_3d)

func _actualizar_preview_3d_objeto(id_modelo: String) -> void:
\tif not _pivote_preview_3d or not is_instance_valid(_pivote_preview_3d):
\t\treturn
\t\t
\tfor ch in _pivote_preview_3d.get_children():
\t\t_pivote_preview_3d.remove_child(ch)
\t\tch.queue_free()
\t\t
\tvar item_data: Dictionary = {}
\tfor it in GeneradorModelosCiudad.obtener_catalogo():
\t\tif it["id"] == id_modelo:
\t\t\titem_data = it
\t\t\tbreak
\tif item_data.is_empty():
\t\titem_data = CargadorBiblioteca.obtener_item(id_modelo)
\t\t\t
\tvar nom: String = item_data.get("nombre", id_modelo)
\tvar tam: Vector3 = item_data.get("tamano", Vector3(6, 10, 6))
\tif item_data.has("dimensiones") and item_data["dimensiones"] is Vector3:
\t\ttam = item_data["dimensiones"]
\t
\tif _lbl_preview_titulo:
\t\t_lbl_preview_titulo.text = nom.to_upper()
\tif _lbl_preview_telemetria:
\t\t_lbl_preview_telemetria.text = "ALT: %.1fm | ANCHO: %.1fm" % [tam.y, max(tam.x, tam.z)]
\t\t
\tvar nuevo_obj = GeneradorModelosCiudad.crear_instancia_objeto(id_modelo)
\tif not nuevo_obj:
\t\tnuevo_obj = CargadorBiblioteca.instanciar_asset(id_modelo)
\tif nuevo_obj:
\t\tfor c in nuevo_obj.find_children("*", "CollisionShape3D", true, false):
\t\t\tif c is CollisionShape3D:
\t\t\t\tc.disabled = true
\t\t_pivote_preview_3d.add_child(nuevo_obj)
\t\t
\t\tvar altura = max(3.0, tam.y)
\t\tvar diametro = max(tam.x, tam.z)
\t\tvar distancia = max(altura * 1.4, diametro * 1.5) + 2.0
\t\tvar centro_y = altura * 0.45
\t\t
\t\tif _camara_preview_3d:
\t\t\t_camara_preview_3d.look_at_from_position(
\t\t\t\tVector3(0.0, centro_y + 0.5, distancia),
\t\t\t\tVector3(0.0, centro_y, 0.0),
\t\t\t\tVector3.UP
\t\t\t)"""

    match = old_preview_pat.search(content)
    assert match is not None, "old_preview_pat not matched"
    content = content[:match.start()] + new_preview + content[match.end():]

    # 6. _crear_tarjeta_item y resaltado
    old_card_pat = re.compile(r"func _crear_tarjeta_item\(id: String, fallback_ico: String, nombre: String, svg_name: String = \"\", icono_textura: String = \"\"\) -> void:.*?_dict_tarjetas_items\[id\] = btn", re.DOTALL)

    new_card = """func _crear_tarjeta_item(id: String, fallback_ico: String, nombre: String, svg_name: String = "", icono_textura: String = "", subtitulo: String = "") -> void:
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
\tvbox.add_child(lbl_sub)
\t
\tbtn.pressed.connect(func():
\t\t_id_item_activo = id
\t\t_resaltar_tarjeta_activa(id)
\t\tif _box_agua_lago_controles and is_instance_valid(_box_agua_lago_controles):
\t\t\t_box_agua_lago_controles.visible = (id == "lago_agua")
\t\tif _box_agua_rio_controles and is_instance_valid(_box_agua_rio_controles):
\t\t\t_box_agua_rio_controles.visible = (id == "rio_agua")
\t\tif _panel_preview_3d and is_instance_valid(_panel_preview_3d):
\t\t\t_actualizar_preview_3d_objeto(id)
\t\tsubherramienta_seleccionada.emit(id)
\t)
\t
\t_grid_items.add_child(btn)
\t_dict_tarjetas_items[id] = btn"""

    match = old_card_pat.search(content)
    assert match is not None, "old_card_pat not matched"
    content = content[:match.start()] + new_card + content[match.end():]

    # 7. _estilar_panel_glass y _estilar_boton
    old_estilar = """func _estilar_panel_glass(panel: PanelContainer, color_fondo: Color, color_borde: Color = Color(0.78, 0.81, 0.85, 0.22)) -> void:
\tvar sb := StyleBoxFlat.new()
\tsb.bg_color = color_fondo
\tsb.border_width_left = 2
\tsb.border_width_top = 2
\tsb.border_width_right = 2
\tsb.border_width_bottom = 2
\tsb.border_color = color_borde
\tsb.corner_radius_top_left = 16
\tsb.corner_radius_top_right = 16
\tsb.corner_radius_bottom_right = 16
\tsb.corner_radius_bottom_left = 16
\tsb.shadow_color = Color(0, 0, 0, 0.50)
\tsb.shadow_size = 10
\tsb.content_margin_left = 16
\tsb.content_margin_right = 16
\tsb.content_margin_top = 14
\tsb.content_margin_bottom = 14
\tpanel.add_theme_stylebox_override("panel", sb)

func _estilar_boton(btn: Button, color_fondo: Color, color_borde: Color = Color(0.78, 0.81, 0.85, 0.22)) -> void:
\tbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
\t
\tvar sb_normal := StyleBoxFlat.new()
\tsb_normal.bg_color = color_fondo
\tsb_normal.border_width_left = 2
\tsb_normal.border_width_top = 2
\tsb_normal.border_width_right = 2
\tsb_normal.border_width_bottom = 2
\tsb_normal.border_color = color_borde
\tsb_normal.corner_radius_top_left = 12
\tsb_normal.corner_radius_top_right = 12
\tsb_normal.corner_radius_bottom_right = 12
\tsb_normal.corner_radius_bottom_left = 12
\tsb_normal.shadow_color = Color(0, 0, 0, 0.35)
\tsb_normal.shadow_size = 4
\tbtn.add_theme_stylebox_override("normal", sb_normal)
\t
\tvar sb_hover := sb_normal.duplicate()
\tsb_hover.border_color = Color(0.88, 0.68, 0.28, 0.85)
\tbtn.add_theme_stylebox_override("hover", sb_hover)
\t
\tvar sb_pressed := sb_normal.duplicate()
\tsb_pressed.bg_color = color_fondo.lightened(0.12)
\tsb_pressed.border_color = Color(0.88, 0.68, 0.28, 1.0)
\tbtn.add_theme_stylebox_override("pressed", sb_pressed)"""

    new_estilar = """func _estilar_panel_glass(panel: PanelContainer, color_fondo: Color, color_borde: Color = Color(0.78, 0.81, 0.85, 0.22), radio: float = 16.0, margen: float = 14.0) -> void:
\tvar sb := StyleBoxFlat.new()
\tsb.bg_color = color_fondo
\tsb.border_width_left = 2
\tsb.border_width_top = 2
\tsb.border_width_right = 2
\tsb.border_width_bottom = 2
\tsb.border_color = color_borde
\tsb.corner_radius_top_left = int(radio)
\tsb.corner_radius_top_right = int(radio)
\tsb.corner_radius_bottom_right = int(radio)
\tsb.corner_radius_bottom_left = int(radio)
\tsb.shadow_color = Color(0, 0, 0, 0.50)
\tsb.shadow_size = 10
\tsb.content_margin_left = margen
\tsb.content_margin_right = margen
\tsb.content_margin_top = margen
\tsb.content_margin_bottom = margen
\tpanel.add_theme_stylebox_override("panel", sb)

func _estilar_boton(btn: Button, color_fondo: Color, color_borde: Color = Color(0.78, 0.81, 0.85, 0.22), radio: float = 12.0, grosor: int = 2) -> void:
\tbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
\t
\tvar sb_normal := StyleBoxFlat.new()
\tsb_normal.bg_color = color_fondo
\tsb_normal.border_width_left = grosor
\tsb_normal.border_width_top = grosor
\tsb_normal.border_width_right = grosor
\tsb_normal.border_width_bottom = grosor
\tsb_normal.border_color = color_borde
\tsb_normal.corner_radius_top_left = int(radio)
\tsb_normal.corner_radius_top_right = int(radio)
\tsb_normal.corner_radius_bottom_right = int(radio)
\tsb_normal.corner_radius_bottom_left = int(radio)
\tsb_normal.shadow_color = Color(0, 0, 0, 0.35)
\tsb_normal.shadow_size = 4
\tbtn.add_theme_stylebox_override("normal", sb_normal)
\t
\tvar sb_hover := sb_normal.duplicate()
\tsb_hover.border_color = Color(0.88, 0.68, 0.28, 0.85)
\tbtn.add_theme_stylebox_override("hover", sb_hover)
\t
\tvar sb_pressed := sb_normal.duplicate()
\tsb_pressed.bg_color = color_fondo.lightened(0.12)
\tsb_pressed.border_color = Color(0.88, 0.68, 0.28, 1.0)
\tbtn.add_theme_stylebox_override("pressed", sb_pressed)"""

    if old_estilar in content:
        content = content.replace(old_estilar, new_estilar, 1)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("UIEditorMapas.gd updated successfully!")

if __name__ == "__main__":
    update_ui_editor()
