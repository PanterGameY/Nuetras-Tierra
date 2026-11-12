import sys

path = "mundo/editor_mapas/ControladorEquipamientoVias.gd"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Update _limpiar_subtipo_en_segmento
old_limpiar = """func _limpiar_subtipo_en_segmento(seg: RoadSegment, prefijo_tipo: String) -> void:
\tvar clave = _obtener_clave_segmento(seg)
\tif _nodos_por_clave_segmento.has(clave):
\t\tvar lista: Array = _nodos_por_clave_segmento[clave]
\t\tvar restantes: Array = []
\t\tfor nodo in lista:
\t\t\tif is_instance_valid(nodo) and (nodo.name.begins_with(prefijo_tipo) or str(nodo.get_meta("subtipo_equip", "")) == prefijo_tipo):
\t\t\t\tif nodo.get_parent():
\t\t\t\t\tnodo.get_parent().remove_child(nodo)
\t\t\t\tnodo.queue_free()
\t\t\telif is_instance_valid(nodo):
\t\t\t\trestantes.append(nodo)
\t\t_nodos_por_clave_segmento[clave] = restantes
\t# Limpiar también cualquier nodo huérfano en _contenedor_equipamiento para esta clave y prefijo
\tif is_instance_valid(_contenedor_equipamiento):
\t\tvar nombre_esperado := "%s_%s" % [prefijo_tipo, clave]
\t\tfor h in _contenedor_equipamiento.get_children():
\t\t\tif is_instance_valid(h) and (h.name == nombre_esperado or (str(h.get_meta("subtipo_equip", "")) == prefijo_tipo and str(h.get_meta("clave_seg", "")) == clave)):
\t\t\t\t_contenedor_equipamiento.remove_child(h)
\t\t\t\th.queue_free()"""

new_limpiar = """func _limpiar_subtipo_en_segmento(seg: RoadSegment, prefijo_tipo: String) -> void:
\tvar clave = _obtener_clave_segmento(seg)
\tif _nodos_por_clave_segmento.has(clave):
\t\tvar lista: Array = _nodos_por_clave_segmento[clave]
\t\tvar restantes: Array = []
\t\tfor nodo in lista:
\t\t\tif is_instance_valid(nodo):
\t\t\t\tvar n_name := nodo.name
\t\t\t\tvar es_tipo = n_name.begins_with(prefijo_tipo) or n_name.contains(prefijo_tipo) or str(nodo.get_meta("subtipo_equip", "")) == prefijo_tipo
\t\t\t\tif es_tipo:
\t\t\t\t\tif nodo.get_parent():
\t\t\t\t\t\tnodo.get_parent().remove_child(nodo)
\t\t\t\t\tnodo.queue_free()
\t\t\t\telse:
\t\t\t\t\trestantes.append(nodo)
\t\t_nodos_por_clave_segmento[clave] = restantes
\t\t
\t# Limpiar también cualquier nodo huérfano o duplicado en _contenedor_equipamiento para esta clave o tipo
\tif is_instance_valid(_contenedor_equipamiento):
\t\tfor h in _contenedor_equipamiento.get_children():
\t\t\tif is_instance_valid(h):
\t\t\t\tvar h_name := h.name
\t\t\t\tvar coincide_clave = clave.is_empty() or h_name.contains(clave) or str(h.get_meta("clave_seg", "")) == clave
\t\t\t\tvar coincide_tipo = h_name.contains(prefijo_tipo) or str(h.get_meta("subtipo_equip", "")) == prefijo_tipo
\t\t\t\tif coincide_tipo and coincide_clave:
\t\t\t\t\t_contenedor_equipamiento.remove_child(h)
\t\t\t\t\th.queue_free()"""

text_clean = text.replace("\r\n", "\n")
old_clean = old_limpiar.replace("\r\n", "\n")
new_clean = new_limpiar.replace("\r\n", "\n")

assert old_clean in text_clean, "old_limpiar not found in text"
text_clean = text_clean.replace(old_clean, new_clean, 1)

# 2. Fix precision adjustment of Blender 4G model in _instanciar_pilar_en_curva
old_adj = """\t\t\tvar escala_x_cap: float = clampf(ancho_cabezal / 8.60, 0.55, 2.20)
\t\t\tif nodo_zapata and nodo_fuste and nodo_capitel:
\t\t\t\tvar h_zap: float = minf(1.20, h_total * 0.25)
\t\t\t\tvar sy_zap: float = h_zap / 1.20
\t\t\t\tnodo_zapata.position = Vector3.ZERO
\t\t\t\tnodo_zapata.scale = Vector3(clampf(escala_x_cap, 0.75, 1.35), sy_zap, 1.0)
\t\t\t\t
\t\t\t\tvar h_cap_base: float = 2.20
\t\t\t\tvar sy_cap: float = minf(1.0, (h_total * 0.38) / h_cap_base)
\t\t\t\tvar h_cap_real: float = h_cap_base * sy_cap
\t\t\t\tvar y_base_cap: float = maxf(h_zap + 0.40, h_total - h_cap_real)
\t\t\t\t
\t\t\t\tnodo_capitel.position = Vector3(0.0, y_base_cap, 0.0)
\t\t\t\tnodo_capitel.scale = Vector3(escala_x_cap, sy_cap, 1.0)
\t\t\t\t
\t\t\t\tvar h_fuste_real: float = maxf(0.40, y_base_cap - h_zap)
\t\t\t\tvar sy_fuste: float = h_fuste_real / 4.60
\t\t\t\tnodo_fuste.position = Vector3(0.0, h_zap, 0.0)
\t\t\t\tnodo_fuste.scale = Vector3(clampf(escala_x_cap, 0.80, 1.30), sy_fuste, 1.0)
\t\t\telse:
\t\t\t\tinst_pilar.scale = Vector3(escala_x_cap, h_total / 8.0, 1.0)"""

new_adj = """\t\t\tvar escala_x_cap: float = clampf(ancho_cabezal / 8.60, 0.55, 2.20)
\t\t\tif nodo_zapata and nodo_fuste and nodo_capitel:
\t\t\t\tconst H_CAP_MESH := 2.32
\t\t\t\tconst H_ZAP_MESH := 1.20
\t\t\t\tconst H_FUSTE_MESH := 4.60
\t\t\t\t
\t\t\t\tvar h_cap: float = clampf(h_total * 0.28, 1.20, H_CAP_MESH)
\t\t\t\tvar sy_cap: float = h_cap / H_CAP_MESH
\t\t\t\tvar y_base_cap: float = maxf(0.80, h_total - h_cap)
\t\t\t\tnodo_capitel.position = Vector3(0.0, y_base_cap, 0.0)
\t\t\t\tnodo_capitel.scale = Vector3(escala_x_cap, sy_cap, 1.0)
\t\t\t\t
\t\t\t\tvar h_zap: float = clampf(h_total * 0.18, 0.50, H_ZAP_MESH)
\t\t\t\tvar sy_zap: float = h_zap / H_ZAP_MESH
\t\t\t\tnodo_zapata.position = Vector3.ZERO
\t\t\t\tnodo_zapata.scale = Vector3(clampf(escala_x_cap, 0.75, 1.35), sy_zap, 1.0)
\t\t\t\t
\t\t\t\tvar h_fuste_real: float = maxf(0.20, y_base_cap - h_zap)
\t\t\t\tvar sy_fuste: float = h_fuste_real / H_FUSTE_MESH
\t\t\t\tnodo_fuste.position = Vector3(0.0, h_zap, 0.0)
\t\t\t\tnodo_fuste.scale = Vector3(clampf(escala_x_cap, 0.80, 1.30), sy_fuste, 1.0)
\t\t\telse:
\t\t\t\tinst_pilar.scale = Vector3(escala_x_cap, h_total / 8.0, 1.0)"""

old_adj_clean = old_adj.replace("\r\n", "\n")
new_adj_clean = new_adj.replace("\r\n", "\n")
assert old_adj_clean in text_clean, "old_adj not found"
text_clean = text_clean.replace(old_adj_clean, new_adj_clean, 1)

if "\r\n" in text:
    text_clean = text_clean.replace("\n", "\r\n")

with open(path, "w", encoding="utf-8") as f:
    f.write(text_clean)

print("Successfully applied viaduct pillar cleanup & adjustment fix!")
