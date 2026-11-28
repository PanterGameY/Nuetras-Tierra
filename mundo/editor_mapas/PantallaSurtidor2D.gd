class_name PantallaSurtidor2D
extends SubViewport

var _lbl_estado: Label = null
var _lbl_total: Label = null
var _lbl_galones: Label = null
var _lbl_litros: Label = null
var _lbl_precio: Label = null
var _dot_estado: ColorRect = null

var _ultimo_hash: String = ""

func _init() -> void:
	size = Vector2i(384, 256)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	transparent_bg = false
	_construir_ui()

func _construir_ui() -> void:
	var root := PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb_root := StyleBoxFlat.new()
	sb_root.bg_color = Color(0.03, 0.07, 0.06, 1.0)
	sb_root.border_width_left = 4; sb_root.border_width_top = 4
	sb_root.border_width_right = 4; sb_root.border_width_bottom = 4
	sb_root.border_color = Color(0.14, 0.30, 0.24, 1.0)
	sb_root.content_margin_left = 18; sb_root.content_margin_right = 18
	sb_root.content_margin_top = 14; sb_root.content_margin_bottom = 14
	root.add_theme_stylebox_override("panel", sb_root)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	# Barra superior
	var hbox_top := HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox_top)

	_dot_estado = ColorRect.new()
	_dot_estado.custom_minimum_size = Vector2(14, 14)
	_dot_estado.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot_estado.color = Color(0.25, 0.90, 0.45)
	hbox_top.add_child(_dot_estado)

	_lbl_estado = Label.new()
	_lbl_estado.text = "LISTO PARA SURTIR"
	_lbl_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_estado.add_theme_font_size_override("font_size", 20)
	_lbl_estado.add_theme_color_override("font_color", Color(0.62, 0.92, 0.78))
	hbox_top.add_child(_lbl_estado)

	var lbl_mon := Label.new()
	lbl_mon.text = "COP $"
	lbl_mon.add_theme_font_size_override("font_size", 20)
	lbl_mon.add_theme_color_override("font_color", Color(0.88, 0.68, 0.28))
	hbox_top.add_child(lbl_mon)

	# Panel principal: TOTAL A PAGAR
	var card_total := PanelContainer.new()
	card_total.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_tot := StyleBoxFlat.new()
	sb_tot.bg_color = Color(0.05, 0.12, 0.09, 1.0)
	sb_tot.border_width_left = 2; sb_tot.border_width_top = 2
	sb_tot.border_width_right = 2; sb_tot.border_width_bottom = 2
	sb_tot.border_color = Color(0.20, 0.55, 0.38, 0.85)
	sb_tot.set_corner_radius_all(8)
	sb_tot.content_margin_left = 14; sb_tot.content_margin_right = 14
	sb_tot.content_margin_top = 8; sb_tot.content_margin_bottom = 8
	card_total.add_theme_stylebox_override("panel", sb_tot)
	vbox.add_child(card_total)

	var vb_tot := VBoxContainer.new()
	vb_tot.alignment = BoxContainer.ALIGNMENT_CENTER
	card_total.add_child(vb_tot)

	var lbl_cap_tot := Label.new()
	lbl_cap_tot.text = "TOTAL VENTA"
	lbl_cap_tot.add_theme_font_size_override("font_size", 16)
	lbl_cap_tot.add_theme_color_override("font_color", Color(0.55, 0.80, 0.68))
	vb_tot.add_child(lbl_cap_tot)

	_lbl_total = Label.new()
	_lbl_total.text = "$ 0"
	_lbl_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_total.add_theme_font_size_override("font_size", 46)
	_lbl_total.add_theme_color_override("font_color", Color(0.32, 1.0, 0.56))
	vb_tot.add_child(_lbl_total)

	# Fila inferior: GALONES | LITROS | PRECIO
	var hbox_bot := HBoxContainer.new()
	hbox_bot.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_bot)

	_lbl_galones = _crear_caja_metrica(hbox_bot, "GALONES", "0.000", Color(0.98, 0.85, 0.28))
	_lbl_litros = _crear_caja_metrica(hbox_bot, "LITROS", "0.0 L", Color(0.86, 0.94, 0.90))
	_lbl_precio = _crear_caja_metrica(hbox_bot, "PRECIO/GAL", "$ 11.200", Color(0.68, 0.88, 0.80))

func _crear_caja_metrica(padre: HBoxContainer, titulo: String, val_ini: String, col_val: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.09, 0.08, 1.0)
	sb.border_width_left = 1; sb.border_width_top = 1
	sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.16, 0.36, 0.28, 0.75)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	padre.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	var l_tit := Label.new()
	l_tit.text = titulo
	l_tit.add_theme_font_size_override("font_size", 11)
	l_tit.add_theme_color_override("font_color", Color(0.55, 0.76, 0.68))
	vb.add_child(l_tit)

	var l_val := Label.new()
	l_val.text = val_ini
	l_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_val.add_theme_font_size_override("font_size", 21)
	l_val.add_theme_color_override("font_color", col_val)
	vb.add_child(l_val)
	return l_val

func actualizar_lectura(total_cop: float, litros: float, precio_galon: float, litros_por_galon: float, surtiendo: bool) -> void:
	var txt_tot := "$ %s" % _formatear_pesos(total_cop)
	var txt_gal := "%.2f" % (litros / maxf(0.01, litros_por_galon))
	var txt_lit := "%.1f L" % litros
	var nuevo_hash := "%s|%s|%s|%s" % [txt_tot, txt_gal, txt_lit, str(surtiendo)]
	if nuevo_hash == _ultimo_hash:
		return
	_ultimo_hash = nuevo_hash

	if _lbl_total:
		_lbl_total.text = txt_tot
	if _lbl_galones:
		_lbl_galones.text = txt_gal
	if _lbl_litros:
		_lbl_litros.text = txt_lit
	if _lbl_precio:
		_lbl_precio.text = "$ %s" % _formatear_pesos(precio_galon)
	if _lbl_estado and _dot_estado:
		if surtiendo:
			_lbl_estado.text = "SURTIENDO COMBUSTIBLE..."
			_dot_estado.color = Color(0.98, 0.75, 0.18)
		else:
			_lbl_estado.text = "LISTO PARA SURTIR"
			_dot_estado.color = Color(0.25, 0.90, 0.45)
	render_target_update_mode = SubViewport.UPDATE_ONCE

func _formatear_pesos(monto: float) -> String:
	var entero := int(round(monto))
	var str_val := str(entero)
	var res := ""
	var contador := 0
	for i in range(str_val.length() - 1, -1, -1):
		res = str_val[i] + res
		contador += 1
		if contador == 3 and i > 0:
			res = "." + res
			contador = 0
	return res
