extends Camera3D

@export var debug_espejo: bool = false

func _ready() -> void:
	# Invierte la escala en X de la cámara para que actúe como un espejo real
	# y no como una cámara de reversa de TV.
	set_frustum_offset(Vector2(0, 0))
	self.scale.x = -1

	# Diagnostics: confirmar que el script _ready corre en runtime
	if debug_espejo:
		print("[EspejoCam] _ready path:", get_path(), " parent:", get_parent() and get_parent().get_path() or "<no-parent>")
		print("[EspejoCam] global_pos:", global_transform.origin, " current:", current)
	# Intentar forzar que esta cámara sea la actual en su viewport
	call_deferred("make_current")
	call_deferred("_espejo_print_late")

func _espejo_print_late() -> void:
	# Se ejecuta un frame después para comprobar estado tras inicializaciones ajenas
	if debug_espejo:
		print("[EspejoCam] late global_pos:", global_transform.origin, " current:", current)
		var vp = get_viewport()
		if vp:
			print("[EspejoCam] viewport:", vp.get_path(), " size:", vp.size, " render_mode:", vp.render_target_update_mode)
		else:
			print("[EspejoCam] no viewport found for this camera")
