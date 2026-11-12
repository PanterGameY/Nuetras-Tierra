# ════════════════════════════════════════════════════════════════════════════════
# EstacionGasolina.gd — Surtidor Interactivo de Combustible con Cobro en COP
# Panter Studio | Nuestra Tierra Job Simulator (Godot 4.7)
# ════════════════════════════════════════════════════════════════════════════════
extends Node3D
class_name EstacionGasolina

signal repostaje_iniciado(vehiculo: Node)
signal repostaje_progreso(litros_cargados: float, costo_actual_cop: float, porcentaje_tanque: float)
signal repostaje_finalizado(litros_totales: float, costo_total_cop: float)

@export_group("Configuración Comercial")
## Nombre comercial visible de la estación (ej. "Estación Terpel - Silvania")
@export var nombre_estacion: String = "Estación de Servicio Terpel - Silvania"
## Precio por galón en pesos colombianos ($ COP)
@export var precio_galon_cop: float = 11200.0
## Factor de conversión oficial: litros por galón estadounidense
@export var litros_por_galon: float = 3.78541
## Velocidad de suministro de la manguera en litros por segundo
@export var velocidad_flujo_lps: float = 12.5

@export_group("Nodos de Control")
@export var area_surtidor: Area3D = null
@export var display_litros_3d: Label3D = null
@export var display_total_3d: Label3D = null
@export var sprite_prompt_3d: Sprite3D = null
@export var audio_surtidor: AudioStreamPlayer3D = null

var _vehiculo_en_bahia: Node = null
var _repostando: bool = false
var _litros_cargados_sesion: float = 0.0
var _costo_acumulado_sesion: float = 0.0

# Canvas táctil para celular/tablet
var _canvas_tanqueo: CanvasLayer = null
var _btn_tanqueo: Button = null

func _ready() -> void:
	add_to_group("estaciones_gasolina")
	_inicializar_nodos()
	_actualizar_displays(0.0, 0.0)

func _process(delta: float) -> void:
	if _repostando and is_instance_valid(_vehiculo_en_bahia):
		_procesar_flujo_combustible(delta)

func _inicializar_nodos() -> void:
	if not area_surtidor:
		area_surtidor = find_child("AreaSurtidor", true, false) as Area3D
	if area_surtidor:
		area_surtidor.body_entered.connect(_on_area_surtidor_body_entered)
		area_surtidor.body_exited.connect(_on_area_surtidor_body_exited)

	if not display_litros_3d:
		display_litros_3d = find_child("DisplayLitros", true, false) as Label3D
	if not display_total_3d:
		display_total_3d = find_child("DisplayTotal", true, false) as Label3D

func _on_area_surtidor_body_entered(body: Node) -> void:
	var v = _obtener_raiz_vehiculo(body)
	if not v:
		return

	_vehiculo_en_bahia = v
	_mostrar_ui_tanqueo(true)
	_actualizar_displays(0.0, 0.0)
	_notificar("Llegaste al surtidor de combustible. Detén el vehículo y apaga el motor para tanquear.", "info")

func _on_area_surtidor_body_exited(body: Node) -> void:
	var v = _obtener_raiz_vehiculo(body)
	if v and v == _vehiculo_en_bahia:
		if _repostando:
			detener_repostaje()
		_vehiculo_en_bahia = null
		_mostrar_ui_tanqueo(false)

func iniciar_repostaje() -> bool:
	if not is_instance_valid(_vehiculo_en_bahia) or _repostando:
		return false

	if "linear_velocity" in _vehiculo_en_bahia:
		var vel: Vector3 = _vehiculo_en_bahia.get("linear_velocity")
		if vel.length() > 0.4:
			_notificar("Debes detener completamente el camión antes de tanquear.", "alerta")
			return false

	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and datos.dinero < (precio_galon_cop * 0.25):
		_notificar("No tienes saldo suficiente para tanquear combustible.", "alerta")
		return false

	_repostando = true
	_litros_cargados_sesion = 0.0
	_costo_acumulado_sesion = 0.0
	repostaje_iniciado.emit(_vehiculo_en_bahia)

	if audio_surtidor and not audio_surtidor.playing:
		audio_surtidor.play()

	_actualizar_texto_boton("DETENER TANQUEO")
	return true

func detener_repostaje() -> void:
	if not _repostando:
		return

	_repostando = false
	if audio_surtidor and audio_surtidor.playing:
		audio_surtidor.stop()

	_actualizar_texto_boton("⛽ TANQUEAR COMBUSTIBLE")
	repostaje_finalizado.emit(_litros_cargados_sesion, _costo_acumulado_sesion)

	var datos = get_node_or_null("/root/DatosUsuario")
	if datos and datos.has_method("save_local"):
		datos.save_local()

	_notificar("Tanqueo finalizado: %s galones cargados por $%s COP." % [
		_formatear_decimal(_litros_cargados_sesion / litros_por_galon, 1),
		_formatear_pesos(_costo_acumulado_sesion)
	], "exito")

func _procesar_flujo_combustible(delta: float) -> void:
	var litros_frame = velocidad_flujo_lps * delta
	var costo_litro = precio_galon_cop / litros_por_galon
	var costo_frame = litros_frame * costo_litro

	var datos = get_node_or_null("/root/DatosUsuario")
	if datos:
		if datos.dinero < costo_frame:
			_notificar("Saldo agotado. Finalizando suministro.", "alerta")
			detener_repostaje()
			return
		datos.dinero -= costo_frame

	_litros_cargados_sesion += litros_frame
	_costo_acumulado_sesion += costo_frame

	var tanque_lleno: bool = false
	var pct_tanque: float = 1.0

	if has_node("/root/InputVehiculo"):
		var iv = get_node("/root/InputVehiculo")
		var actual = float(iv.get("combustible")) if "combustible" in iv else 0.5
		var delta_pct = litros_frame / 420.0
		var nuevo_pct = minf(actual + delta_pct, 1.0)
		iv.set("combustible", nuevo_pct)
		pct_tanque = nuevo_pct
		if nuevo_pct >= 0.999:
			tanque_lleno = true

	var motor = _vehiculo_en_bahia.find_child("Motor", true, false)
	if motor:
		if "nivel_combustible_l" in motor and "capacidad_combustible_l" in motor:
			var act_l = float(motor.get("nivel_combustible_l"))
			var cap_l = float(motor.get("capacidad_combustible_l"))
			var nuevo_l = minf(act_l + litros_frame, cap_l)
			motor.set("nivel_combustible_l", nuevo_l)
			pct_tanque = nuevo_l / cap_l
			if nuevo_l >= cap_l - 0.1:
				tanque_lleno = true

	_actualizar_displays(_litros_cargados_sesion, _costo_acumulado_sesion)
	repostaje_progreso.emit(_litros_cargados_sesion, _costo_acumulado_sesion, pct_tanque)

	if tanque_lleno:
		_notificar("¡Tanque lleno al 100%!", "exito")
		detener_repostaje()

func _actualizar_displays(litros: float, total_cop: float) -> void:
	if display_litros_3d:
		display_litros_3d.text = "%s L\n(%s gal)" % [_formatear_decimal(litros, 1), _formatear_decimal(litros / litros_por_galon, 1)]
	if display_total_3d:
		display_total_3d.text = "$%s COP" % _formatear_pesos(total_cop)

func _mostrar_ui_tanqueo(visible: bool) -> void:
	if visible:
		if not _canvas_tanqueo:
			_canvas_tanqueo = CanvasLayer.new()
			_canvas_tanqueo.layer = 15
			add_child(_canvas_tanqueo)

			var btn = Button.new()
			btn.name = "BotonTanqueo"
			btn.text = "⛽ TANQUEAR COMBUSTIBLE"
			btn.custom_minimum_size = Vector2(280, 65)
			btn.anchor_left = 0.5
			btn.anchor_right = 0.5
			btn.anchor_top = 0.82
			btn.anchor_bottom = 0.82
			btn.offset_left = -140
			btn.offset_right = 140
			btn.offset_top = -32
			btn.offset_bottom = 33

			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.65, 0.35, 0.92)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(1, 1, 1, 0.4)
			style.corner_radius_top_left = 14
			style.corner_radius_top_right = 14
			style.corner_radius_bottom_left = 14
			style.corner_radius_bottom_right = 14
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_color_override("font_color", Color.WHITE)

			btn.pressed.connect(func():
				if _repostando:
					detener_repostaje()
				else:
					iniciar_repostaje()
			)
			_canvas_tanqueo.add_child(btn)
			_btn_tanqueo = btn
		else:
			_canvas_tanqueo.visible = true
	else:
		if _canvas_tanqueo:
			_canvas_tanqueo.visible = false

func _actualizar_texto_boton(texto: String) -> void:
	if _btn_tanqueo:
		_btn_tanqueo.text = texto
		var st = _btn_tanqueo.get_theme_stylebox("normal") as StyleBoxFlat
		if st:
			if _repostando:
				st.bg_color = Color(0.85, 0.25, 0.25, 0.92)
			else:
				st.bg_color = Color(0.12, 0.65, 0.35, 0.92)

func _obtener_raiz_vehiculo(node: Node) -> Node:
	var curr = node
	while curr and curr != get_tree().current_scene:
		if curr.is_in_group("vehiculo") or curr.has_method("subir_jugador"):
			return curr
		curr = curr.get_parent()
	return null

func _formatear_pesos(monto: float) -> String:
	var entero = int(monto)
	var str_val = str(entero)
	var res = ""
	var contador = 0
	for i in range(str_val.length() - 1, -1, -1):
		res = str_val[i] + res
		contador += 1
		if contador == 3 and i > 0:
			res = "." + res
			contador = 0
	return res

func _formatear_decimal(valor: float, dec: int = 1) -> String:
	return ("%." + str(dec) + "f") % valor

func _notificar(msg: String, tipo: String = "info") -> void:
	if has_node("/root/NotificationManager"):
		var nm = get_node("/root/NotificationManager")
		if tipo == "exito" and nm.has_method("notificar_exito"):
			nm.call("notificar_exito", msg)
			return
		elif tipo == "alerta" and nm.has_method("notificar_error"):
			nm.call("notificar_error", msg)
			return
	print("[Gasolinera] ", msg)
