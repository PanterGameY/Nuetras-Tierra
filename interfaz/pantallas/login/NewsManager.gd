extends PanelContainer

@onready var contenedor_movil = %ContenedorMovil
@onready var timer_cambio = %TimerCambio
@onready var indicadores = $VBoxContainer/Indicadores
@onready var carrusel_container = $VBoxContainer/CarruselContainer

# Variables exportadas para ajustar desde el inspector
@export var ancho_noticia: int = 380
@export var alto_noticia: int = 160
@export var separacion_entre_items: int = 20
@export var tiempo_transicion: float = 0.5
@export var tiempo_espera: float = 5.0
@export var tamanio_titulo: int = 18
@export var tamanio_subtitulo: int = 24
@export var tamanio_descripcion: int = 12
@export var color_borde_evento: Color = Color(0, 1, 1, 0.8)
@export var color_borde_actualizacion: Color = Color(1, 0.8, 0, 0.8)
@export var color_borde_noticia: Color = Color(0.5, 0.5, 1, 0.8)

var indice_actual := 0
var ancho_item := 0

var noticias_datos: Array[Dictionary] = [
	{"titulo": "🎮 NUEVO EVENTO", "subtitulo": "Carrera Nocturna", "descripcion": "Participa en la carrera nocturna y gana recompensas exclusivas.", "tipo": "evento"},
	{"titulo": "⭐ ACTUALIZACIÓN", "subtitulo": "Versión 2.1", "descripcion": "Nuevos camiones, mapas y mejoras de rendimiento.", "tipo": "actualizacion"},
	{"titulo": "🏆 TORNEO SEMANAL", "subtitulo": "En Fusa", "descripcion": "Compite contra otros jugadores este fin de semana.", "tipo": "evento"},
	{"titulo": "🚀 MANTENIMIENTO", "subtitulo": "Programado", "descripcion": "El servidor estará en mantenimiento el lunes 3 AM.", "tipo": "noticia"}
]

func _ready():
	timer_cambio.wait_time = tiempo_espera
	timer_cambio.timeout.connect(_deslizar_siguiente)
	
	contenedor_movil.add_theme_constant_override("separation", separacion_entre_items)
	
	cargar_noticias_carrusel()
	
	# Esperar a que se renderice
	await get_tree().process_frame
	await get_tree().process_frame
	
	calcular_ancho_item()
	crear_indicadores()
	
	# Aplicar tamaño inicial
	actualizar_tamanos()

func actualizar_tamanos():
	# Actualizar tamaño del carrusel container
	carrusel_container.custom_minimum_size = Vector2(ancho_noticia, alto_noticia)
	
	# Actualizar todos los items existentes
	for item in contenedor_movil.get_children():
		item.custom_minimum_size = Vector2(ancho_noticia, alto_noticia)
		
		# Actualizar estilos y fuentes dentro del item
		var vbox = item.get_child(0) if item.get_child_count() > 0 else null
		if vbox:
			var index = 0
			for child in vbox.get_children():
				if child is Label:
					# Identificar por posición en lugar de texto
					match index:
						0: # Título
							child.add_theme_font_size_override("font_size", tamanio_titulo)
						1: # Subtítulo (si existe)
							if noticias_datos[indice_actual].has("subtitulo"):
								child.add_theme_font_size_override("font_size", tamanio_subtitulo)
						2: # Separador - no es Label, ignorar
							pass
						3: # Descripción
							child.add_theme_font_size_override("font_size", tamanio_descripcion)
					index += 1
func recalcular_tamanos():
	# Recalcular ancho del item
	calcular_ancho_item()
	# Reajustar posición
	_deslizar_a_indice()

func calcular_ancho_item():
	ancho_item = ancho_noticia + separacion_entre_items

func cargar_noticias_carrusel():
	for child in contenedor_movil.get_children():
		child.queue_free()
	
	for i in range(noticias_datos.size()):
		var item = crear_item_noticia(noticias_datos[i])
		contenedor_movil.add_child(item)
	
	indice_actual = 0
	contenedor_movil.position.x = 0

func crear_item_noticia(noticia: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(ancho_noticia, alto_noticia)
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_FILL
	
	# Estilo según tipo
	var estilo = StyleBoxFlat.new()
	estilo.content_margin_left = 16
	estilo.content_margin_top = 12
	estilo.content_margin_right = 16
	estilo.content_margin_bottom = 12
	estilo.corner_radius_top_left = 12
	estilo.corner_radius_top_right = 12
	estilo.corner_radius_bottom_right = 12
	estilo.corner_radius_bottom_left = 12
	estilo.border_width_left = 3
	estilo.border_width_top = 3
	estilo.border_width_right = 3
	estilo.border_width_bottom = 3
	
	match noticia["tipo"]:
		"evento":
			estilo.bg_color = Color(0.05, 0.15, 0.2, 0.95)
			estilo.border_color = color_borde_evento
		"actualizacion":
			estilo.bg_color = Color(0.15, 0.1, 0.05, 0.95)
			estilo.border_color = color_borde_actualizacion
		_:
			estilo.bg_color = Color(0.1, 0.1, 0.15, 0.95)
			estilo.border_color = color_borde_noticia
	
	panel.add_theme_stylebox_override("panel", estilo)
	
	# Contenedor vertical centrado
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	# Título principal
	var titulo_label = Label.new()
	titulo_label.text = noticia["titulo"]
	titulo_label.add_theme_font_size_override("font_size", tamanio_titulo)
	titulo_label.add_theme_color_override("font_color", Color.WHITE)
	titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(titulo_label)
	
	# Subtítulo
	if noticia.has("subtitulo"):
		var subtitulo_label = Label.new()
		subtitulo_label.text = noticia["subtitulo"]
		subtitulo_label.add_theme_font_size_override("font_size", tamanio_subtitulo)
		subtitulo_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		subtitulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitulo_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(subtitulo_label)
	
	# Separador
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(ancho_noticia - 80, 2)
	vbox.add_child(sep)
	
	# Descripción
	var desc_label = Label.new()
	desc_label.text = noticia["descripcion"]
	desc_label.add_theme_font_size_override("font_size", tamanio_descripcion)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
	return panel

func crear_indicadores():
	for child in indicadores.get_children():
		child.queue_free()
	
	for i in range(noticias_datos.size()):
		var indicador = Button.new()
		indicador.text = "●"
		indicador.add_theme_font_size_override("font_size", 16)
		indicador.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		indicador.custom_minimum_size = Vector2(30, 30)
		indicador.pressed.connect(_ir_a_noticia.bind(i))
		
		var estilo_btn = StyleBoxFlat.new()
		estilo_btn.bg_color = Color(0, 0, 0, 0)
		indicador.add_theme_stylebox_override("normal", estilo_btn)
		indicador.add_theme_stylebox_override("hover", estilo_btn)
		indicador.add_theme_stylebox_override("pressed", estilo_btn)
		
		indicadores.add_child(indicador)
	
	actualizar_indicadores()

func actualizar_indicadores():
	for i in range(indicadores.get_child_count()):
		var indicador = indicadores.get_child(i)
		if i == indice_actual:
			indicador.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		else:
			indicador.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))

func _ir_a_noticia(indice: int):
	if indice == indice_actual:
		return
	
	timer_cambio.stop()
	indice_actual = indice
	_deslizar_a_indice()
	timer_cambio.start()

func _deslizar_siguiente():
	if contenedor_movil.get_child_count() <= 1:
		return
	
	indice_actual += 1
	
	if indice_actual >= contenedor_movil.get_child_count():
		indice_actual = 0
	
	_deslizar_a_indice()

func _deslizar_a_indice():
	if ancho_item == 0:
		calcular_ancho_item()
	
	var destino_x = -(indice_actual * ancho_item)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(contenedor_movil, "position:x", destino_x, tiempo_transicion)
	
	actualizar_indicadores()

func _on_resized():
	await get_tree().process_frame
	recalcular_tamanos()

# Método público para agregar noticias desde fuera
func agregar_noticia(titulo: String, subtitulo: String, descripcion: String, tipo: String = "noticia"):
	var nueva_noticia = {
		"titulo": titulo,
		"subtitulo": subtitulo,
		"descripcion": descripcion,
		"tipo": tipo
	}
	noticias_datos.append(nueva_noticia)
	cargar_noticias_carrusel()
	recalcular_tamanos()

# Método público para cambiar tamaño desde código
func set_tamanos(ancho: int, alto: int):
	ancho_noticia = ancho
	alto_noticia = alto
	actualizar_tamanos()
	recalcular_tamanos()
