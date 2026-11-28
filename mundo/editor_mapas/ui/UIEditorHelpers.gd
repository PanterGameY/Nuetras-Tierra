class_name UIEditorHelpers
extends RefCounted

## UIEditorHelpers.gd — Módulo reutilizable de utilidades UI, Recientes y Validación
## Desacopla lógica auxiliar de UIEditorMapas.gd y HubEditorMapas.gd.

const MAX_RECIENTES := 8
const RUTA_RECIENTES := "user://editor_recientes.cfg"

static var _recientes_cache: Array[String] = []
static var _recientes_cargados: bool = false


static func crear_estilo_glass(
	fondo: Color,
	borde: Color,
	radio: int = 12,
	grosor: int = 1,
	sombra: int = 6
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_border_width_all(grosor)
	sb.border_color = borde
	sb.set_corner_radius_all(radio)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = sombra
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func cargar_miniatura_mapa(ruta_ntmap: String) -> Texture2D:
	var ruta_thumb := ruta_ntmap.get_basename() + "_thumb.jpg"
	if not FileAccess.file_exists(ruta_thumb):
		return null
	var img := Image.new()
	if img.load(ruta_thumb) != OK or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


static func registrar_objeto_reciente(id_modelo: String) -> void:
	var id_limpio := id_modelo.strip_edges()
	if id_limpio.is_empty():
		return
	var lista := obtener_objetos_recientes()
	lista.erase(id_limpio)
	lista.push_front(id_limpio)
	while lista.size() > MAX_RECIENTES:
		lista.pop_back()
	_recientes_cache = lista
	var cfg := ConfigFile.new()
	cfg.set_value("editor", "recientes", lista)
	cfg.save(RUTA_RECIENTES)


static func obtener_objetos_recientes() -> Array[String]:
	if _recientes_cargados:
		return _recientes_cache
	_recientes_cargados = true
	_recientes_cache.clear()
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_RECIENTES) == OK:
		var arr = cfg.get_value("editor", "recientes", [])
		if arr is Array:
			for it in arr:
				var s := str(it).strip_edges()
				if not s.is_empty():
					_recientes_cache.append(s)
	return _recientes_cache


static func filtrar_catalogo(items: Array, consulta: String) -> Array:
	var q := consulta.strip_edges().to_lower()
	if q.is_empty():
		return items
	var salida: Array = []
	for it in items:
		if it is Dictionary:
			var nom := str(it.get("nombre", it.get("titulo", it.get("id", "")))).to_lower()
			var id_v := str(it.get("id", "")).to_lower()
			if q in nom or q in id_v:
				salida.append(it)
		elif q in str(it).to_lower():
			salida.append(it)
	return salida


static func validar_mapa_archivo(ruta_ntmap: String) -> Dictionary:
	if not FileAccess.file_exists(ruta_ntmap):
		return {"ok": false, "mensaje": "El archivo del mapa no existe."}
	var txt := ""
	var fc := FileAccess.open_compressed(ruta_ntmap, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if fc:
		txt = fc.get_as_text()
		fc.close()
	if txt.is_empty():
		var fp := FileAccess.open(ruta_ntmap, FileAccess.READ)
		if fp:
			txt = fp.get_as_text()
			fp.close()
	var parsed = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return {"ok": false, "mensaje": "Formato de mapa inválido."}
	var vias = parsed.get("carreteras", [])
	var objs = parsed.get("objetos", [])
	var n_vias: int = vias.size() if vias is Array else 0
	var n_objs: int = objs.size() if objs is Array else 0
	if n_vias == 0 and n_objs == 0:
		return {"ok": false, "mensaje": "Agrega al menos una vía o un objeto antes de publicar."}
	return {"ok": true, "mensaje": "Mapa válido (%d vías, %d objetos)." % [n_vias, n_objs]}


static func crear_carga_sencilla(padre: Node, texto: String = "Cargando...") -> CanvasLayer:
	var capa := CanvasLayer.new()
	capa.layer = 160
	padre.add_child(capa)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.04, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 96)
	var sb := crear_estilo_glass(Color(0.06, 0.07, 0.08, 0.94), Color(0.88, 0.68, 0.28, 0.65), 14, 1, 10)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)

	var punto := Panel.new()
	punto.custom_minimum_size = Vector2(14, 14)
	punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_p := StyleBoxFlat.new()
	sb_p.bg_color = Color(0.88, 0.68, 0.28, 1.0)
	sb_p.set_corner_radius_all(7)
	punto.add_theme_stylebox_override("panel", sb_p)
	hb.add_child(punto)

	var lbl := Label.new()
	lbl.name = "LabelCarga"
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97, 1.0))
	var f_path := "res://recursos/fonts/Moderniz.otf"
	if ResourceLoader.exists(f_path):
		lbl.add_theme_font_override("font", load(f_path))
	hb.add_child(lbl)
	capa.set_meta("_lbl", lbl)

	return capa


static func actualizar_carga_sencilla(capa: CanvasLayer, texto: String) -> void:
	if not is_instance_valid(capa) or not capa.has_meta("_lbl"):
		return
	var lbl = capa.get_meta("_lbl")
	if is_instance_valid(lbl) and lbl is Label:
		lbl.text = texto


static func cerrar_carga_sencilla(capa: CanvasLayer) -> void:
	if is_instance_valid(capa):
		capa.queue_free()
