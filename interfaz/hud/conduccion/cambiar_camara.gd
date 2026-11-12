extends Button

func _ready():
	focus_mode = FocusMode.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	# Connect pressed signal to handler (use Callable for safety)
	pressed.connect(Callable(self, "_on_pressed"))

func _on_pressed():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("CambiarCamaraGlobal"):
			gm.call("CambiarCamaraGlobal", 0)
		elif gm.has_method("cambiar_camara_global"):
			gm.call("cambiar_camara_global")
		else:
			push_warning("cambiar_camara: GameManager no expone método para cambiar cámara.")
	else:
		push_warning("cambiar_camara: GameManager no encontrado en /root/GameManager")
