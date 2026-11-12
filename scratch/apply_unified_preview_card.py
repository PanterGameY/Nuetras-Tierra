import re
import sys

path = "mundo/editor_mapas/UIEditorMapas.gd"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add _lbl_preview_categoria and adjust rotation speed to 0.20
target_vars = """var _lbl_preview_titulo: Label = null
var _lbl_preview_telemetria: Label = null
var _lbl_preview_desc: Label = null
var _velocidad_rotacion_preview: float = 0.65"""

replacement_vars = """var _lbl_preview_titulo: Label = null
var _lbl_preview_categoria: Label = null
var _lbl_preview_telemetria: Label = null
var _lbl_preview_desc: Label = null
var _velocidad_rotacion_preview: float = 0.20"""

assert target_vars in content, "target_vars not found!"
content = content.replace(target_vars, replacement_vars)

# 2. In _llenar_catalogo_vegetacion, remove redundant _construir_panel_preview_3d and _crear_barra_herramientas_objetos
target_veg = """func _llenar_catalogo_vegetacion() -> void:
	_construir_panel_preview_3d(_panel_parametros)
	_crear_barra_herramientas_objetos()
	
	var btn_scatter := Button.new()"""

replacement_veg = """func _llenar_catalogo_vegetacion() -> void:
	var btn_scatter := Button.new()"""

assert target_veg in content, "target_veg not found!"
content = content.replace(target_veg, replacement_veg)

# 3. Update _construir_preview_3d_dock to build the unified description & preview card
target_dock = """func _construir_preview_3d_dock(categoria: String, id_modelo: String) -> void:
	for c in _dock_preview_inferior.get_children():
		c.queue_free()
		
	_inicializar_subviewport_3d()
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_dock_preview_inferior.add_child(vbox)
	
	var hbox_top := HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_top)
	
	var vbox_tit := VBoxContainer.new()
	vbox_tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_tit.add_theme_constant_override("separation", 2)
	hbox_top.add_child(vbox_tit)
	
	_lbl_preview_titulo = Label.new()
	_lbl_preview_titulo.text = id_modelo.to_upper().replace("_", " ")
	_lbl_preview_titulo.add_theme_font_size_override("font_size", 22)
	_lbl_preview_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
	if _fuente_moderniz:
		_lbl_preview_titulo.add_theme_font_override("font", _fuente_moderniz)
	vbox_tit.add_child(_lbl_preview_titulo)
	
	_lbl_preview_telemetria = Label.new()
	_lbl_preview_telemetria.text = "CALCULANDO DIMENSIONES..."
	_lbl_preview_telemetria.add_theme_font_size_override("font_size", 16)
	_lbl_preview_telemetria.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.85))
	vbox_tit.add_child(_lbl_preview_telemetria)
	
	if categoria == "ciudad":
		var btn_rotar := Button.new()
		btn_rotar.text = "⟳ ROTAR 45°"
		btn_rotar.custom_minimum_size = Vector2(125, 36)
		_estilar_boton(btn_rotar, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 8.0)
		btn_rotar.add_theme_font_size_override("font_size", 16)
		btn_rotar.pressed.connect(func(): rotar_objeto_solicitado.emit())
		hbox_top.add_child(btn_rotar)
		
		var btn_dem := Button.new()
		btn_dem.text = "🚜 DEMOLER"
		btn_dem.custom_minimum_size = Vector2(110, 36)
		_estilar_boton(btn_dem, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 8.0)
		btn_dem.add_theme_font_size_override("font_size", 16)
		btn_dem.pressed.connect(func():
			var act = not (_btn_demoler.get_meta("activo", false) if _btn_demoler else false)
			if _btn_demoler: _btn_demoler.set_meta("activo", act)
			_modo_demolicion_activo = act
			demolicion_alternada.emit(act)
		)
		hbox_top.add_child(btn_dem)
	
	var marco_vp := PanelContainer.new()
	marco_vp.custom_minimum_size = Vector2(0, 160)
	marco_vp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estilar_panel_glass(marco_vp, Color(0.04, 0.05, 0.06, 0.95), Color(0.88, 0.68, 0.28, 0.35), 8.0, 4.0)
	vbox.add_child(marco_vp)
	
	if _vp_container_preview.get_parent():
		_vp_container_preview.get_parent().remove_child(_vp_container_preview)
	marco_vp.add_child(_vp_container_preview)
	
	_actualizar_preview_3d_objeto(id_modelo)"""

replacement_dock = """func _construir_preview_3d_dock(categoria: String, id_modelo: String) -> void:
	for c in _dock_preview_inferior.get_children():
		c.queue_free()
		
	_inicializar_subviewport_3d()
	
	# Tarjeta Unificada Glassmorphic de Inspección y Previsualización
	var card_unificada := PanelContainer.new()
	card_unificada.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_unificada.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_estilar_panel_glass(card_unificada, Color(0.06, 0.07, 0.09, 0.96), Color(0.88, 0.68, 0.28, 0.35), 12.0, 10.0)
	_dock_preview_inferior.add_child(card_unificada)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card_unificada.add_child(margin)
	
	# Layout Horizontal: Izquierda = 3D Turntable Suave, Derecha = Datos Técnicos y Acciones
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)
	
	# ── LADO IZQUIERDO: VISOR 3D DIRECTO EN LA TARJETA ──
	var marco_vp := PanelContainer.new()
	marco_vp.custom_minimum_size = Vector2(250, 180)
	_estilar_panel_glass(marco_vp, Color(0.04, 0.05, 0.06, 0.95), Color(0.88, 0.68, 0.28, 0.30), 8.0, 4.0)
	hbox.add_child(marco_vp)
	
	if _vp_container_preview.get_parent():
		_vp_container_preview.get_parent().remove_child(_vp_container_preview)
	_vp_container_preview.custom_minimum_size = Vector2(250, 180)
	_vp_container_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vp_container_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco_vp.add_child(_vp_container_preview)
	
	# ── LADO DERECHO: METADATOS Y ACCIONES ──
	var vbox_info := VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_info.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox_info)
	
	# Header: Título en Moderniz y Botones de Acción
	var hbox_hdr := HBoxContainer.new()
	hbox_hdr.add_theme_constant_override("separation", 8)
	vbox_info.add_child(hbox_hdr)
	
	_lbl_preview_titulo = Label.new()
	_lbl_preview_titulo.text = id_modelo.to_upper().replace("_", " ")
	_lbl_preview_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_preview_titulo.add_theme_font_size_override("font_size", 22)
	_lbl_preview_titulo.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
	if _fuente_moderniz:
		_lbl_preview_titulo.add_theme_font_override("font", _fuente_moderniz)
	hbox_hdr.add_child(_lbl_preview_titulo)
	
	if categoria in ["ciudad", "vegetacion"]:
		var btn_rotar := Button.new()
		btn_rotar.text = "⟳ ROTAR 45°"
		btn_rotar.custom_minimum_size = Vector2(130, 42)
		_estilar_boton(btn_rotar, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 8.0)
		btn_rotar.add_theme_font_size_override("font_size", 16)
		btn_rotar.pressed.connect(func(): rotar_objeto_solicitado.emit())
		hbox_hdr.add_child(btn_rotar)
		
		var btn_dem := Button.new()
		btn_dem.text = "🚜 DEMOLER"
		btn_dem.custom_minimum_size = Vector2(120, 42)
		_estilar_boton(btn_dem, Color(0.12, 0.14, 0.18, 0.90), Color(0.78, 0.81, 0.85, 0.22), 8.0)
		btn_dem.add_theme_font_size_override("font_size", 16)
		btn_dem.pressed.connect(func():
			var act = not (_btn_demoler.get_meta("activo", false) if _btn_demoler else false)
			if _btn_demoler: _btn_demoler.set_meta("activo", act)
			_modo_demolicion_activo = act
			demolicion_alternada.emit(act)
		)
		hbox_hdr.add_child(btn_dem)
		
	# Categoría y Subapartado
	_lbl_preview_categoria = Label.new()
	_lbl_preview_categoria.text = "PROCESANDO CATEGORÍA..."
	_lbl_preview_categoria.add_theme_font_size_override("font_size", 15)
	_lbl_preview_categoria.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 0.95))
	vbox_info.add_child(_lbl_preview_categoria)
	
	# Telemetría de Dimensiones
	_lbl_preview_telemetria = Label.new()
	_lbl_preview_telemetria.text = "CALCULANDO DIMENSIONES..."
	_lbl_preview_telemetria.add_theme_font_size_override("font_size", 16)
	_lbl_preview_telemetria.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85, 0.95))
	vbox_info.add_child(_lbl_preview_telemetria)
	
	# Párrafo de Descripción de la Tarjeta
	_lbl_preview_desc = Label.new()
	_lbl_preview_desc.text = "Cargando descripción técnica..."
	_lbl_preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_preview_desc.add_theme_font_size_override("font_size", 15)
	_lbl_preview_desc.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.85))
	vbox_info.add_child(_lbl_preview_desc)
	
	_actualizar_preview_3d_objeto(id_modelo)"""

assert target_dock in content, "target_dock not found!"
content = content.replace(target_dock, replacement_dock)

# 4. Update _actualizar_preview_3d_objeto to populate category, telemetry, and rich description
target_update = """func _actualizar_preview_3d_objeto(id_modelo: String) -> void:
	if not _pivote_preview_3d or not is_instance_valid(_pivote_preview_3d):
		return
		
	for ch in _pivote_preview_3d.get_children():
		_pivote_preview_3d.remove_child(ch)
		ch.queue_free()
		
	var item_data: Dictionary = {}
	for it in GeneradorModelosCiudad.obtener_catalogo():
		if it["id"] == id_modelo:
			item_data = it
			break
	if item_data.is_empty():
		item_data = CargadorBiblioteca.obtener_item(id_modelo)
			
	var nom: String = item_data.get("nombre", id_modelo)
	var tam: Vector3 = item_data.get("tamano", Vector3(6, 10, 6))
	if item_data.has("dimensiones") and item_data["dimensiones"] is Vector3:
		tam = item_data["dimensiones"]
	
	if _lbl_preview_titulo:
		_lbl_preview_titulo.text = nom.to_upper()
	if _lbl_preview_telemetria:
		_lbl_preview_telemetria.text = "ALT: %.1fm | ANCHO: %.1fm" % [tam.y, max(tam.x, tam.z)]
		
	var nuevo_obj = GeneradorModelosCiudad.crear_instancia_objeto(id_modelo)"""

replacement_update = """func _actualizar_preview_3d_objeto(id_modelo: String) -> void:
	if not _pivote_preview_3d or not is_instance_valid(_pivote_preview_3d):
		return
		
	for ch in _pivote_preview_3d.get_children():
		_pivote_preview_3d.remove_child(ch)
		ch.queue_free()
		
	var item_data: Dictionary = {}
	for it in GeneradorModelosCiudad.obtener_catalogo():
		if it["id"] == id_modelo:
			item_data = it
			break
	if item_data.is_empty():
		item_data = CargadorBiblioteca.obtener_item(id_modelo)
			
	var nom: String = item_data.get("nombre", id_modelo.capitalize().replace("_", " "))
	var tam: Vector3 = item_data.get("tamano", Vector3(6, 10, 6))
	if item_data.has("dimensiones") and item_data["dimensiones"] is Vector3:
		tam = item_data["dimensiones"]
	
	if _lbl_preview_titulo:
		_lbl_preview_titulo.text = nom.to_upper()
		
	if _lbl_preview_categoria:
		var cat_str: String = ""
		if item_data.has("seccion"):
			var sec: String = item_data.get("seccion", "").capitalize()
			var sub: String = item_data.get("subapartado", "").replace("_", " ").capitalize()
			var ico_cat = CargadorBiblioteca.obtener_icono_apartado(sec)
			cat_str = "%s %s%s" % [ico_cat, sec, (" · " + sub if sub != "" and sub != "Todos" else "")]
		elif item_data.has("categoria_raiz"):
			var rz: String = CargadorBiblioteca.formatear_nombre_carpeta(item_data.get("categoria_raiz", "")).capitalize()
			var ico_rz = CargadorBiblioteca.obtener_icono_apartado(rz)
			cat_str = "%s %s" % [ico_rz, rz]
		else:
			cat_str = "🏛️ Arquitectura & Paisaje"
		_lbl_preview_categoria.text = cat_str
		
	if _lbl_preview_telemetria:
		_lbl_preview_telemetria.text = "📏 Altura: %.1fm  •  📐 Base: %.1fm × %.1fm" % [tam.y, tam.x, tam.z]
		
	if _lbl_preview_desc:
		var d_txt: String = item_data.get("desc", "")
		if d_txt.is_empty():
			d_txt = item_data.get("descripcion", "")
		if d_txt.is_empty():
			var lower_id = id_modelo.to_lower()
			if "chalet" in lower_id:
				d_txt = "Chalet de arquitectura alpina con cubierta inclinada, vigas de madera y diseño contemporáneo de montaña."
			elif "colonial" in lower_id:
				d_txt = "Vivienda tradicional de estilo colonial con teja de barro, carpintería clásica y patio central."
			elif "paisa" in lower_id or "campesina" in lower_id:
				d_txt = "Casa típica campesina con corredor exterior, zócalos coloridos y tejas de barro tradicionales."
			elif "modern" in lower_id or "cubica" in lower_id:
				d_txt = "Residencia contemporánea con volúmenes geométricos puros, amplios ventanales y losas de concreto arquitectónico."
			elif "edificio" in lower_id or "apartamento" in lower_id:
				d_txt = "Edificación residencial urbana de varios niveles con balcones y acabados de ladrillo a la vista."
			elif "porteria" in lower_id or "acceso" in lower_id:
				d_txt = "Módulo de control de acceso y portería con garita de seguridad para urbanizaciones y conjuntos cerrados."
			elif "arbol" in lower_id or "palmera" in lower_id or "roble" in lower_id:
				d_txt = "Especie arbórea natural de alta fidelidad para paisajismo, sombreado y enriquecimiento del entorno ecológico."
			else:
				d_txt = "Modelo tridimensional optimizado con colisiones para integración en el mapa de Nuestra Tierra."
		_lbl_preview_desc.text = d_txt
		
	var nuevo_obj = GeneradorModelosCiudad.crear_instancia_objeto(id_modelo)"""

assert target_update in content, "target_update not found!"
content = content.replace(target_update, replacement_update)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("SUCCESS: Preview embedded in description card and turntable rotation slowed down!")
