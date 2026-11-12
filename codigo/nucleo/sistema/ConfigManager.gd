# ConfiguracionManager.gd
extends Node

signal configuracion_cambiada(seccion: String, clave: String, valor: Variant)
signal configuraciones_guardadas
signal configuraciones_restauradas

var archivo_configuracion: String = "user://configuraciones.cfg"
var configuraciones: Dictionary = {}
var configuraciones_defecto: Dictionary = {}

func _ready() -> void:
	print("[ConfigMan] Inicializando...")
	_inicializar_configuraciones()
	_cargar_configuraciones()
	print("[ConfigMan] Listo")

func _inicializar_configuraciones() -> void:
	configuraciones = {
		"graficos": {
			"calidad": 2,
			"sombras": true,
			"reflejos": true,
			"antialiasing": true,
			"resolucion": "1920x1080",
			"pantalla_completa": true,
			"vsync": true,
		},
		"audio": {
			"volumen_general": 80,
			"volumen_musica": 70,
			"volumen_efectos": 80,
			"volumen_voces": 100,
			"mute_background": false,
		},
		"juego": {
			"subtitulos": true,
			"sensibilidad_camara": 50,
			"dificultad": 1,
			"velocidad_juego": 1.0,
			"mostrar_fps": false,
			"idioma": "es_ES",
		},
	}
	configuraciones_defecto = configuraciones.duplicate(true)

func _cargar_configuraciones() -> void:
	if ResourceLoader.exists(archivo_configuracion):
		var config = ConfigFile.new()
		var error = config.load(archivo_configuracion)
		
		if error == OK:
			for seccion in configuraciones.keys():
				if config.has_section(seccion):
					for clave in configuraciones[seccion].keys():
						if config.has_section_key(seccion, clave):
							configuraciones[seccion][clave] = config.get_value(seccion, clave)
			print("[Conf] Cargado")
		else:
			_guardar_configuraciones()
	else:
		_guardar_configuraciones()
		_aplicar_configuraciones()

func _guardar_configuraciones() -> void:
	var config = ConfigFile.new()
	for seccion in configuraciones.keys():
		for clave in configuraciones[seccion].keys():
			config.set_value(seccion, clave, configuraciones[seccion][clave])
	
	var error = config.save(archivo_configuracion)
	if error == OK:
		print("[ConfigMan] Guardado")
		configuraciones_guardadas.emit()

func _aplicar_configuraciones() -> void:
	print("[ConfigMan] Aplicando...")
	_aplicar_graficos()
	_aplicar_audio()
	_aplicar_juego()

func obtener(seccion: String, clave: String) -> Variant:
	if configuraciones.has(seccion) and configuraciones[seccion].has(clave):
		return configuraciones[seccion][clave]
	return null

func establecer(seccion: String, clave: String, valor: Variant, guardar: bool = true) -> void:
	if configuraciones.has(seccion) and configuraciones[seccion].has(clave):
		configuraciones[seccion][clave] = valor
		configuracion_cambiada.emit(seccion, clave, valor)
		if guardar:
			_guardar_configuraciones()

func obtener_seccion(seccion: String) -> Dictionary:
	if configuraciones.has(seccion):
		return configuraciones[seccion].duplicate()
	return {}

func restaurar_defectos() -> void:
	configuraciones = configuraciones_defecto.duplicate(true)
	_guardar_configuraciones()
	_aplicar_configuraciones()
	configuraciones_restauradas.emit()

func _aplicar_graficos() -> void:
	var config = configuraciones["graficos"]
	match int(config["calidad"]):
		0:
			get_tree().root.canvas_cull_mask = 0b11
			print("[Graficos] Baja")
		1:
			get_tree().root.canvas_cull_mask = 0b111
			print("[Graficos] Media")
		2:
			get_tree().root.canvas_cull_mask = 0b1111
			print("[Graficos] Alta")

func _aplicar_audio() -> void:
	var config = configuraciones["audio"]
	var db = linear_to_db(clamp(config["volumen_general"] / 100.0, 0.0, 1.0))
	AudioServer.set_bus_volume_db(0, db)
	AudioServer.set_bus_mute(0, config["volumen_general"] == 0)
	
	var bus_musica = AudioServer.get_bus_index("Musica")
	if bus_musica != -1:
		var db_musica = linear_to_db(clamp(config["volumen_musica"] / 100.0, 0.0, 1.0))
		AudioServer.set_bus_volume_db(bus_musica, db_musica)
	
	var bus_efectos = AudioServer.get_bus_index("Efectos")
	if bus_efectos != -1:
		var db_efectos = linear_to_db(clamp(config["volumen_efectos"] / 100.0, 0.0, 1.0))
		AudioServer.set_bus_volume_db(bus_efectos, db_efectos)

func _aplicar_juego() -> void:
	var config = configuraciones["juego"]
	Engine.time_scale = config["velocidad_juego"]
