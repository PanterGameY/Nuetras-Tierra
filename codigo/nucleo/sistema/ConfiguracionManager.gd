# ConfiguracionManager.gd
extends Node

# GESTOR CENTRAL DE CONFIGURACIONES - AUTOLOAD (SINGLETON)
signal configuracion_cambiada(seccion: String, clave: String, valor: Variant)
signal configuraciones_guardadas
signal configuraciones_restauradas

var archivo_configuracion: String = "user://configuraciones.cfg"
var configuraciones: Dictionary = {}
var configuraciones_defecto: Dictionary = {}

func _ready() -> void:
	print("[ConfigMan] Inicializando ConfiguracionManager...")
	_inicializar_configuraciones()
	_cargar_configuraciones()
	print("[ConfigMan] ConfiguracionManager lista")

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
		"controles": {
			"invertir_eje_x": false,
			"invertir_eje_y": false,
			"deadzone_joystick": 0.2,
		},
		"accesibilidad": {
			"daltonismo": false,
			"alto_contraste": false,
			"tamaño_texto": 1.0,
		}
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
			print("[Conf] Configuraciones cargadas desde: ", archivo_configuracion)
		else:
			print("[Conf] Error al cargar configuraciones: ", error)
			_guardar_configuraciones()
	else:
		print("[Conf] Primera ejecucion, creando archivo de configuraciones...")
		_guardar_configuraciones()
		_aplicar_configuraciones()

func _guardar_configuraciones() -> void:
	var config = ConfigFile.new()
	for seccion in configuraciones.keys():
		for clave in configuraciones[seccion].keys():
			config.set_value(seccion, clave, configuraciones[seccion][clave])
	
	var error = config.save(archivo_configuracion)
	if error == OK:
		print("[ConfigMan] Configuraciones guardadas correctamente")
		configuraciones_guardadas.emit()
	else:
		print("[ERROR] Error al guardar configuraciones: ", error)

func _aplicar_configuraciones() -> void:
	print("[ConfigMan] Aplicando configuraciones...")
	_aplicar_graficos()
	_aplicar_audio()
	_aplicar_juego()
	_aplicar_controles()

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
			_aplicar_seccion_especifica(seccion, clave)

func obtener_seccion(seccion: String) -> Dictionary:
	if configuraciones.has(seccion):
		return configuraciones[seccion].duplicate()
	return {}

func restaurar_defectos() -> void:
	configuraciones = configuraciones_defecto.duplicate(true)
	_guardar_configuraciones()
	_aplicar_configuraciones()
	configuraciones_restauradas.emit()

func _aplicar_seccion_especifica(seccion: String, _clave: String) -> void:
	match seccion:
		"graficos":
			_aplicar_graficos()
		"audio":
			_aplicar_audio()
		"juego":
			_aplicar_juego()
		"controles":
			_aplicar_controles()

func _aplicar_graficos() -> void:
	var config = configuraciones["graficos"]
	match int(config["calidad"]):
		0:
			get_tree().root.canvas_cull_mask = 0b11
			print("[Graficos] Calidad grafica: BAJA")
		1:
			get_tree().root.canvas_cull_mask = 0b111
			print("[Graficos] Calidad grafica: MEDIA")
		2:
			get_tree().root.canvas_cull_mask = 0b1111
			print("[Graficos] Calidad grafica: ALTA")
	
	if config["pantalla_completa"]:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
	
	var vsync_mode = DisplayServer.VSYNC_ENABLED if config["vsync"] else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

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

func _aplicar_controles() -> void:
	print("[Controles] Controles aplicados")

func exportar_configuraciones() -> String:
	return JSON.stringify(configuraciones)

func importar_configuraciones(json_string: String) -> bool:
	var json = JSON.new()
	if json.parse(json_string) == OK:
		configuraciones = json.data
		_guardar_configuraciones()
		_aplicar_configuraciones()
		return true
	return false
