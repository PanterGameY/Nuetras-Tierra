extends CanvasLayer

@onready var label_nombre: Label = $Control/HeaderPanel/Margin/HBox/PlayerSection/InfoText/NameHBox/LabelNombre
@onready var btn_editar = $Control/HeaderPanel/Margin/HBox/PlayerSection/InfoText/NameHBox/BtnEditar
@onready var btn_cerrar = $Control/HeaderPanel/Margin/HBox/ActionButtons/BtnCerrar
@export var volver_a: String = ""

func _ready():
	# Conectar botones
	# Conectar solo si el nodo existe, evitando acceso a instancia nula
	if btn_cerrar:
		btn_cerrar.pressed.connect(Callable(self, "_on_btn_cerrar_pressed"))
	else:
		push_warning("Inventario: BtnCerrar no encontrado; señal 'pressed' no conectada.")
	# Mostrar nombre del usuario si existe en el singleton DatosUsuario
	if DatosUsuario:
		if DatosUsuario.nombre_usuario != "":
			label_nombre.text = DatosUsuario.nombre_usuario
		# Conectar señal para actualizaciones en tiempo real
		var cb := Callable(self, "_on_nombre_usuario_cambiado")
		if not DatosUsuario.is_connected("nombre_usuario_cambiado", cb):
			DatosUsuario.connect("nombre_usuario_cambiado", cb)

# --- NAVEGACIÓN ---
func _on_btn_cerrar_pressed():
	# Aquí decides si cierras la escena o vuelves al menú principal
	print("Saliendo del inventario...")
	# Si el caller fijó `volver_a` (export) lo usamos primero
	if volver_a != null and volver_a != "":
		get_tree().change_scene_to_file(volver_a)
		return
	# Si hay previous_scene definido en DatosUsuario lo usamos
	if DatosUsuario and DatosUsuario.previous_scene != "":
		var target := DatosUsuario.previous_scene
		DatosUsuario.previous_scene = ""
		if target != "":
			get_tree().change_scene_to_file(target)
			return
	# Fallback: si el inventario es un popup dentro de otra escena, simplemente liberamos
	queue_free()

# --- SHORTCUT DE TECLADO ---
func _input(event):
	# Detectar la tecla ESC para cerrar, como dice el texto del botón
	if event.is_action_pressed("ui_cancel"): # "ui_cancel" es ESC por defecto en Godot
		_on_btn_cerrar_pressed()

# Función para que otros scripts actualicen el avatar si el jugador cambia de equipo
func actualizar_avatar(nueva_textura: Texture2D):
	var icon = $Control/HeaderPanel/Margin/HBox/PlayerSection/AvatarBG/AvatarIcon
	icon.texture = nueva_textura

func _on_nombre_usuario_cambiado(new_name: String) -> void:
	if label_nombre:
		label_nombre.text = new_name
