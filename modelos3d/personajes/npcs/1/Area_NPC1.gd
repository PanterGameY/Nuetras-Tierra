extends CharacterBody3D

@onready var burbuja_texto = $CanvasLayer/Panel # Tu UI de dialogo
@onready var label_texto = $CanvasLayer/Panel/Label

func _ready():
	burbuja_texto.hide()

func _on_interaction_area_body_entered(body):
	if body.is_in_group("Player"):
		mostrar_dialogo("¡Quiubo! Si busca la licencia de servicio público, hablemos aquí.")

func mostrar_dialogo(contenido):
	label_texto.text = contenido
	burbuja_texto.show()
	# Aquí podrías usar un Tween para que el texto aparezca letra por letra