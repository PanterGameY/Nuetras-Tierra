extends HBoxContainer

## Barra de divisas compartida (efectivo y esmeraldas).
## Usa el mismo cristal ahumado, acentos y tipografia en todas las pantallas.

class_name BarraDivisas

@export var compacta := false

var _dinero_previo := -1.0
var _esmeraldas_previas := -1

@onready var _panel_dinero: PanelContainer = $PanelDinero
@onready var _panel_esmeraldas: PanelContainer = $PanelEsmeraldas
@onready var _hbox_dinero: HBoxContainer = $PanelDinero/HBox
@onready var _hbox_esmeraldas: HBoxContainer = $PanelEsmeraldas/HBox
@onready var _acento_dinero: ColorRect = $PanelDinero/HBox/Acento
@onready var _acento_esmeraldas: ColorRect = $PanelEsmeraldas/HBox/Acento
@onready var _icono_dinero: TextureRect = $PanelDinero/HBox/Icono
@onready var _icono_esmeraldas: TextureRect = $PanelEsmeraldas/HBox/Icono
@onready var _caption_dinero: Label = $PanelDinero/HBox/VBoxDatos/Caption
@onready var _caption_esmeraldas: Label = $PanelEsmeraldas/HBox/VBoxDatos/Caption
@onready var _valor_dinero: Label = $PanelDinero/HBox/VBoxDatos/LabelValor
@onready var _valor_esmeraldas: Label = $PanelEsmeraldas/HBox/VBoxDatos/LabelValor


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if compacta:
		_aplicar_densidad_compacta()
	refrescar(false)


## Lee el saldo actual del usuario y actualiza la barra.
func refrescar(animar := true) -> void:
	var dinero := 0.0
	var esmeraldas := 0
	if DatosUsuario:
		dinero = float(DatosUsuario.dinero)
		esmeraldas = int(DatosUsuario.esmeraldas)
	set_valores(dinero, esmeraldas, animar)


## Actualiza los valores mostrados. Anima solo cuando el saldo cambia.
func set_valores(dinero: float, esmeraldas: int, animar := true) -> void:
	var cambio_dinero := _dinero_previo >= 0.0 and not is_equal_approx(dinero, _dinero_previo)
	var cambio_esmeraldas := _esmeraldas_previas >= 0 and esmeraldas != _esmeraldas_previas

	_dinero_previo = dinero
	_esmeraldas_previas = esmeraldas

	_valor_dinero.text = _formatear_dinero(dinero)
	_valor_esmeraldas.text = _formatear_miles(esmeraldas)

	if animar and cambio_dinero:
		pulsar_dinero()
	if animar and cambio_esmeraldas:
		pulsar_esmeraldas()


func pulsar_dinero() -> void:
	_pulsar(_panel_dinero)


func pulsar_esmeraldas() -> void:
	_pulsar(_panel_esmeraldas)


func _pulsar(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	var previo = ctrl.get_meta("tw_pulso", null)
	if previo is Tween and previo.is_valid():
		previo.kill()
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw := ctrl.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2(1.05, 1.05), 0.10)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.18)
	ctrl.set_meta("tw_pulso", tw)


func _aplicar_densidad_compacta() -> void:
	add_theme_constant_override("separation", 12)
	_panel_dinero.custom_minimum_size = Vector2(190, 58)
	_panel_esmeraldas.custom_minimum_size = Vector2(156, 58)
	for hbox in [_hbox_dinero, _hbox_esmeraldas]:
		hbox.add_theme_constant_override("separation", 10)
	for acento in [_acento_dinero, _acento_esmeraldas]:
		acento.custom_minimum_size = Vector2(2, 26)
	_icono_dinero.custom_minimum_size = Vector2(30, 30)
	_icono_esmeraldas.custom_minimum_size = Vector2(30, 30)
	for caption in [_caption_dinero, _caption_esmeraldas]:
		caption.add_theme_font_size_override("font_size", 10)
	for valor in [_valor_dinero, _valor_esmeraldas]:
		valor.add_theme_font_size_override("font_size", 18)


func _formatear_dinero(valor: float) -> String:
	var absoluto := absf(valor)
	var entero := int(floor(absoluto))
	var centavos := int(round((absoluto - float(entero)) * 100.0))
	if centavos >= 100:
		entero += 1
		centavos = 0

	var texto := "$ " + _formatear_miles(entero)
	if centavos > 0:
		texto += ",%02d" % centavos
	if valor < 0.0:
		texto = "-" + texto
	return texto


func _formatear_miles(valor: int) -> String:
	var negativo := valor < 0
	var digitos := str(absi(valor))
	var salida := ""
	for i in range(digitos.length()):
		if i > 0 and (digitos.length() - i) % 3 == 0:
			salida += "."
		salida += digitos[i]
	return ("-" if negativo else "") + salida
