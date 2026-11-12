# DestinoMensajero.gd - Nodo visual para colocar puntos de entrega en la escena
@tool
extends Marker3D
class_name DestinoMensajero

func _ready() -> void:
	add_to_group("destinos_mensajero")
