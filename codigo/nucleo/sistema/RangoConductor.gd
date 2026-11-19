class_name RangoConductor
extends RefCounted

## Sistema general de rangos e insignias militares/de prestigio por nivel.

static var _cache_escudos: Dictionary = {}

static func obtener_rango(nivel: int) -> Dictionary:
	var n := maxi(nivel, 0)
	if n >= 110:
		return {"tier": 10, "nombre": "LEYENDA", "color": Color(1.0, 0.42, 0.24, 1.0), "borde": Color(1.0, 0.86, 0.36, 1.0)}
	elif n >= 90:
		return {"tier": 9, "nombre": "GRAN MAESTRO", "color": Color(0.95, 0.28, 0.34, 1.0), "borde": Color(1.0, 0.72, 0.56, 1.0)}
	elif n >= 75:
		return {"tier": 8, "nombre": "COMANDANTE", "color": Color(0.68, 0.42, 1.0, 1.0), "borde": Color(0.86, 0.72, 1.0, 1.0)}
	elif n >= 60:
		return {"tier": 7, "nombre": "MAESTRO", "color": Color(0.24, 0.78, 1.0, 1.0), "borde": Color(0.66, 0.92, 1.0, 1.0)}
	elif n >= 45:
		return {"tier": 6, "nombre": "EXPERTO", "color": Color(0.22, 0.88, 0.54, 1.0), "borde": Color(0.58, 0.98, 0.76, 1.0)}
	elif n >= 30:
		return {"tier": 5, "nombre": "VETERANO", "color": Color(0.95, 0.75, 0.25, 1.0), "borde": Color(1.0, 0.90, 0.55, 1.0)}
	elif n >= 20:
		return {"tier": 4, "nombre": "ESPECIALISTA", "color": Color(0.78, 0.86, 0.96, 1.0), "borde": Color(0.94, 0.98, 1.0, 1.0)}
	elif n >= 10:
		return {"tier": 3, "nombre": "OFICIAL", "color": Color(0.46, 0.66, 0.86, 1.0), "borde": Color(0.72, 0.84, 0.98, 1.0)}
	elif n >= 5:
		return {"tier": 2, "nombre": "APRENDIZ", "color": Color(0.82, 0.54, 0.28, 1.0), "borde": Color(0.95, 0.72, 0.48, 1.0)}
	return {"tier": 1, "nombre": "RECLUTA", "color": Color(0.62, 0.67, 0.74, 1.0), "borde": Color(0.82, 0.86, 0.92, 1.0)}


static func obtener_textura_escudo(nivel: int) -> ImageTexture:
	var info := obtener_rango(nivel)
	var tier := int(info["tier"])
	if _cache_escudos.has(tier):
		return _cache_escudos[tier]

	var sz := 112
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var c_main: Color = info["color"]
	var c_rim: Color = info["borde"]
	var c_core := Color(0.06, 0.07, 0.09, 0.98)

	for y in range(sz):
		var ny := (float(y) / float(sz - 1)) * 2.0 - 1.0
		for x in range(sz):
			var nx := absf((float(x) / float(sz - 1)) * 2.0 - 1.0)
			var col := Color(0, 0, 0, 0)

			# 1. Alas / barras laterales estilo militar en rangos altos (tier >= 7)
			if tier >= 7 and _en_alas_laterales(nx, ny, tier):
				col = c_rim if (ny < -0.15 or tier >= 9) else c_main

			# 2. Corona superior para rangos supremos (tier >= 9)
			if tier >= 9 and _en_corona(nx, ny):
				col = c_rim

			# 3. Cuerpo del escudo
			var max_w := _ancho_escudo(ny, tier)
			if ny >= -0.72 and ny <= 0.86 and max_w > 0.0:
				var d_edge := max_w - nx
				var d_top := ny - (-0.72)
				var d_min := minf(d_edge, d_top)
				if d_min >= 0.0:
					if d_min < 0.075:
						col = c_rim
					elif d_min < 0.14:
						col = c_main
					else:
						var sheen := clampf((0.35 - ny) * 0.16, 0.0, 0.14)
						col = c_core.lightened(sheen)
						if _en_emblema_interno(nx, ny, tier):
							col = c_rim if (tier >= 6 and ny < -0.18) else c_main
					if d_min < 0.022:
						col.a *= clampf(d_min / 0.022, 0.0, 1.0)

			if col.a > 0.0:
				img.set_pixel(x, y, col)

	var tex := ImageTexture.create_from_image(img)
	_cache_escudos[tier] = tex
	return tex


static func _ancho_escudo(ny: float, tier: int) -> float:
	if ny < -0.72 or ny > 0.86:
		return 0.0
	var base_w := 0.62 if tier >= 7 else 0.70
	if ny <= -0.46 and tier >= 5:
		# Hombros biselados tipo insignia táctica
		return base_w - (ny + 0.72) * 0.12
	if ny <= 0.06:
		return base_w
	var t := clampf((ny - 0.06) / 0.80, 0.0, 1.0)
	return base_w * (1.0 - pow(t, 1.6))


static func _en_emblema_interno(nx: float, ny: float, tier: int) -> bool:
	# Galones / chevrones militares progresivos (1 a 4 líneas)
	var num_galones := mini(tier, 3) if tier <= 4 else (3 if tier <= 7 else 4)
	var start_y := -0.10 if tier >= 5 else -0.22
	var step_y := 0.18 if num_galones >= 4 else 0.22
	for i in range(num_galones):
		var base_y := start_y + float(i) * step_y
		var linea_y := base_y + nx * 0.50
		if nx <= 0.34 and absf(ny - linea_y) < 0.052:
			return true

	# Barras horizontales de oficial arriba de los galones (tier >= 4)
	if tier >= 4:
		var barras := 1 if tier < 6 else 2
		for b in range(barras):
			var by := -0.34 - float(b) * 0.12
			if nx <= 0.30 and absf(ny - by) < 0.036:
				return true

	# Estrella / diamante central en rangos altos (tier >= 6)
	if tier >= 6:
		var dy := absf(ny + 0.54)
		if nx + dy < 0.16:
			return true

	return false


static func _en_alas_laterales(nx: float, ny: float, tier: int) -> bool:
	if nx < 0.64 or nx > 0.94:
		return false
	var num_plumas := 2 if tier < 9 else 3
	for p in range(num_plumas):
		var y_base := -0.34 + float(p) * 0.22
		var y_linea := y_base + (nx - 0.64) * -0.55
		if absf(ny - y_linea) < 0.048:
			return true
	return false


static func _en_corona(nx: float, ny: float) -> bool:
	if ny < -0.94 or ny > -0.73 or nx > 0.34:
		return false
	if absf(nx) < 0.06 and ny >= -0.94:
		return true
	if absf(nx - 0.24) < 0.06 and ny >= -0.89:
		return true
	if ny >= -0.80:
		return true
	return false
