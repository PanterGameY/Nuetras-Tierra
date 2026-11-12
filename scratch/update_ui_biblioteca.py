path = "mundo/editor_mapas/UIEditorMapas.gd"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add state variables around line 138
old_vars = """var _grid_items: GridContainer
var _dict_tarjetas_items: Dictionary = {}"""

new_vars = """var _grid_items: GridContainer
var _dict_tarjetas_items: Dictionary = {}
var _seccion_biblioteca_activa: String = "01_Residencial"
var _subapartado_biblioteca_activa: String = "todos"
var _box_filtros_edificaciones: VBoxContainer = null
var _box_subapartados_container: HBoxContainer = null
var _lbl_subapartados_header: Label = null
var _dict_btn_secciones_edif: Dictionary = {}
var _dict_btn_subapartados_edif: Dictionary = {}"""

text_clean = text.replace("\r\n", "\n")
old_v_clean = old_vars.replace("\r\n", "\n")
new_v_clean = new_vars.replace("\r\n", "\n")
assert old_v_clean in text_clean, "old_vars not found"
text_clean = text_clean.replace(old_v_clean, new_v_clean, 1)

# 2. Replace _llenar_catalogo_ciudad with the new structured system
old_ciudad = """func _llenar_catalogo_ciudad() -> void:
\t_construir_panel_preview_3d(_panel_parametros)
\t_crear_barra_herramientas_objetos()
\t
\tCargadorBiblioteca.inicializar()
\tvar items = CargadorBiblioteca.obtener_items_por_categoria("01_Edificaciones")
\tfor c_extra in ["02_Monumentos_Hitos", "03_Accesorios_Viales", "04_Mobiliario_Urbano", "06_Infraestructura_Transporte", "07_Plantillas_y_Kits"]:
\t\titems.append_array(CargadorBiblioteca.obtener_items_por_categoria(c_extra))
\t\t
\tvar primer_id := ""
\tfor it in items:
\t\tif primer_id == "":
\t\t\tprimer_id = it["id"]
\t\tvar tex_ico: String = it.get("icono_textura", "")
\t\t_crear_tarjeta_item(it["id"], it.get("icono", "🏢"), it["nombre"], "", tex_ico)
\tif primer_id != "":
\t\t_resaltar_tarjeta_activa(primer_id)
\t\t_actualizar_preview_3d_objeto(primer_id)"""

new_ciudad = """func _llenar_catalogo_ciudad() -> void:
\t_construir_panel_preview_3d(_panel_parametros)
\t_crear_barra_herramientas_objetos()
\tCargadorBiblioteca.inicializar()
\t_construir_filtros_apartados_edificaciones()
\t_refrescar_grid_edificaciones()

## Construye la barra de pestañas y subapartados de la Biblioteca
func _construir_filtros_apartados_edificaciones() -> void:
\t_dict_btn_secciones_edif.clear()
\t_dict_btn_subapartados_edif.clear()
\t
\t_box_filtros_edificaciones = VBoxContainer.new()
\t_box_filtros_edificaciones.name = "BoxFiltrosEdificaciones"
\t_box_filtros_edificaciones.add_theme_constant_override("separation", 6)
\t_panel_parametros.add_child(_box_filtros_edificaciones)
\t
\t# 1. Header Secciones
\tvar lbl_sec := Label.new()
\tlbl_sec.text = "🏛️ SECCIONES DE LA BIBLIOTECA"
\tlbl_sec.add_theme_font_size_override("font_size", 12)
\tlbl_sec.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28, 0.95))
\t_box_filtros_edificaciones.add_child(lbl_sec)
\t
\t# Scroll horizontal de Secciones
\tvar scroll_sec := ScrollContainer.new()
\tscroll_sec.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
\tscroll_sec.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\tscroll_sec.custom_minimum_size = Vector2(0, 42)
\t_box_filtros_edificaciones.add_child(scroll_sec)
\t
\tvar box_sec := HBoxContainer.new()
\tbox_sec.add_theme_constant_override("separation", 6)
\tscroll_sec.add_child(box_sec)
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
\t\tbtn_s.custom_minimum_size = Vector2(110, 36)
\t\tbtn_s.add_theme_font_size_override("font_size", 12)
\t\t_estilar_boton(btn_s, Color(0.08, 0.09, 0.12, 0.85))
\t\t
\t\tvar sec_id: String = s["id"]
\t\tbtn_s.pressed.connect(func():
\t\t\t_seccion_biblioteca_activa = sec_id
\t\t\t_subapartado_biblioteca_activa = "todos"
\t\t\t_actualizar_botones_secciones_edif()
\t\t\t_actualizar_botones_subapartados_edif()
\t\t\t_refrescar_grid_edificaciones()
\t\t)
\t\tbox_sec.add_child(btn_s)
\t\t_dict_btn_secciones_edif[sec_id] = btn_s
\t
\t# 2. Header y Contenedor de Subapartados (Carpetas internas)
\t_lbl_subapartados_header = Label.new()
\t_lbl_subapartados_header.text = "📁 SUB-APARTADOS (CARPETAS)"
\t_lbl_subapartados_header.add_theme_font_size_override("font_size", 11)
\t_lbl_subapartados_header.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.80))
\t_box_filtros_edificaciones.add_child(_lbl_subapartados_header)
\t
\tvar scroll_sub := ScrollContainer.new()
\tscroll_sub.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
\tscroll_sub.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\tscroll_sub.custom_minimum_size = Vector2(0, 38)
\t_box_filtros_edificaciones.add_child(scroll_sub)
\t
\t_box_subapartados_container = HBoxContainer.new()
\t_box_subapartados_container.add_theme_constant_override("separation", 6)
\tscroll_sub.add_child(_box_subapartados_container)
\t
\t_actualizar_botones_secciones_edif()
\t_actualizar_botones_subapartados_edif()

## Actualiza el resaltado visual de las pestañas de Secciones
func _actualizar_botones_secciones_edif() -> void:
\tfor id in _dict_btn_secciones_edif:
\t\tvar btn: Button = _dict_btn_secciones_edif[id]
\t\tif id == _seccion_biblioteca_activa:
\t\t\t_estilar_boton(btn, Color(0.88, 0.68, 0.28, 0.35), Color(0.88, 0.68, 0.28, 0.95))
\t\t\tbtn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
\t\telse:
\t\t\t_estilar_boton(btn, Color(0.08, 0.09, 0.12, 0.85))
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
\t\t_box_subapartados_container.get_parent().visible = false
\t\treturn
\t\t
\tif _lbl_subapartados_header:
\t\t_lbl_subapartados_header.visible = true
\t_box_subapartados_container.get_parent().visible = true
\t
\tvar subapartados = CargadorBiblioteca.obtener_subapartados_de_seccion("01_Edificaciones", _seccion_biblioteca_activa)
\tvar lista_subs: Array[Dictionary] = [{"id": "todos", "nombre": "Todos", "icono": "🌟"}]
\tlista_subs.append_array(subapartados)
\t
\tfor sub in lista_subs:
\t\tvar btn := Button.new()
\t\tbtn.text = "%s %s" % [sub["icono"], sub["nombre"]]
\t\tbtn.custom_minimum_size = Vector2(100, 32)
\t\tbtn.add_theme_font_size_override("font_size", 11)
\t\t_estilar_boton(btn, Color(0.07, 0.08, 0.10, 0.80))
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
\t\t\t_estilar_boton(btn, Color(0.20, 0.55, 0.85, 0.35), Color(0.28, 0.68, 0.98, 0.95))
\t\t\tbtn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
\t\telse:
\t\t\t_estilar_boton(btn, Color(0.07, 0.08, 0.10, 0.80))
\t\t\tbtn.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78))

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
\tvar primer_id := ""
\tfor it in items:
\t\tif primer_id == "":
\t\t\tprimer_id = it["id"]
\t\tvar tex_ico: String = it.get("icono_textura", "")
\t\t_crear_tarjeta_item(it["id"], it.get("icono", "🏢"), it["nombre"], "", tex_ico)
\t\t
\tif primer_id != "":
\t\t_id_item_activo = primer_id
\t\t_resaltar_tarjeta_activa(primer_id)
\t\t_actualizar_preview_3d_objeto(primer_id)
\t\tsubherramienta_seleccionada.emit(primer_id)"""

old_c_clean = old_ciudad.replace("\r\n", "\n")
new_c_clean = new_ciudad.replace("\r\n", "\n")
assert old_c_clean in text_clean, "old_ciudad not found"
text_clean = text_clean.replace(old_c_clean, new_c_clean, 1)

if "\r\n" in text:
    text_clean = text_clean.replace("\n", "\r\n")

with open(path, "w", encoding="utf-8") as f:
    f.write(text_clean)

print("Successfully updated UIEditorMapas with categorized library sections & folders!")
