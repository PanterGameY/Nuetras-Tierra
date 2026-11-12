class_name ControladorSpawn
extends Node3D

## ControladorSpawn.gd — Marcador 3D visual y gestor del punto de spawn
## Permite reubicar el punto de inicio, orientar la dirección y elegir el modo (Vehículo o A Pie).

signal spawn_actualizado(posicion: Vector3, rotacion_y: float, modo: String)

enum ModoSpawn {
	VEHICULO,
	A_PIE
}

@export var modo_spawn: ModoSpawn = ModoSpawn.VEHICULO
@export var rotacion_y_grados: float = 0.0

var _marcador_raiz: Node3D
var _anillo_holo: MeshInstance3D
var _flecha_direccion: MeshInstance3D
var _haz_luz: MeshInstance3D
var _etiqueta: Label3D
var _marcador_preview_spawn: Node3D = null

func _ready() -> void:
	_construir_marcador_3d()
	_crear_marcador_preview_spawn()

func _crear_marcador_preview_spawn() -> void:
	_marcador_preview_spawn = Node3D.new()
	_marcador_preview_spawn.name = "PreviewSpawnCursor"
	
	var anillo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.4
	torus.outer_radius = 2.7
	anillo.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.65) # Cyan holográfico
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	anillo.material_override = mat
	_marcador_preview_spawn.add_child(anillo)
	
	_marcador_preview_spawn.visible = false
	add_child(_marcador_preview_spawn)

func actualizar_cursor_spawn(pos_mundo: Vector3, visible_en_pantalla: bool) -> void:
	if not _marcador_preview_spawn:
		return
	_marcador_preview_spawn.visible = visible_en_pantalla
	if visible_en_pantalla:
		_marcador_preview_spawn.global_position = Vector3(pos_mundo.x, pos_mundo.y + 0.15, pos_mundo.z)
		_marcador_preview_spawn.rotation_degrees.y = rotacion_y_grados

func _construir_marcador_3d() -> void:
	_marcador_raiz = Node3D.new()
	_marcador_raiz.name = "MarcadorSpawn3D"
	add_child(_marcador_raiz)
	_marcador_raiz.global_position = Vector3(0.0, 0.2, 0.0)
	
	# 1. Anillo holográfico en el suelo
	_anillo_holo = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.4
	torus.outer_radius = 2.7
	torus.rings = 36
	torus.ring_segments = 4
	_anillo_holo.mesh = torus
	
	var mat_anillo := StandardMaterial3D.new()
	mat_anillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_anillo.albedo_color = Color(0.88, 0.68, 0.28, 0.95) # Automotive Instrument Amber
	mat_anillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_anillo.emission_enabled = true
	mat_anillo.emission = Color(0.88, 0.68, 0.28)
	mat_anillo.emission_energy_multiplier = 2.0
	_anillo_holo.material_override = mat_anillo
	_marcador_raiz.add_child(_anillo_holo)
	
	# 2. Haz de luz vertical translúcido
	_haz_luz = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 1.4
	cyl.height = 12.0
	_haz_luz.mesh = cyl
	_haz_luz.position = Vector3(0.0, 6.0, 0.0)
	
	var mat_haz := StandardMaterial3D.new()
	mat_haz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_haz.albedo_color = Color(0.88, 0.68, 0.28, 0.22)
	mat_haz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_haz_luz.material_override = mat_haz
	_marcador_raiz.add_child(_haz_luz)
	
	# 3. Flecha 3D de dirección (apunta hacia adelante -Z)
	_flecha_direccion = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 2.5, 0.3)
	_flecha_direccion.mesh = prism
	_flecha_direccion.rotation_degrees.x = -90.0
	_flecha_direccion.position = Vector3(0.0, 0.35, -2.2)
	
	var mat_flecha := StandardMaterial3D.new()
	mat_flecha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flecha.albedo_color = Color(0.95, 0.82, 0.35, 0.95)
	mat_flecha.emission_enabled = true
	mat_flecha.emission = Color(0.95, 0.82, 0.35)
	_flecha_direccion.material_override = mat_flecha
	_marcador_raiz.add_child(_flecha_direccion)
	
	# 4. Etiqueta flotante 3D
	_etiqueta = Label3D.new()
	_etiqueta.text = "🚩 PUNTO DE SPAWN"
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.font_size = 36
	_etiqueta.modulate = Color(0.88, 0.68, 0.28)
	_etiqueta.outline_modulate = Color(0.06, 0.07, 0.08)
	_etiqueta.outline_size = 6
	_etiqueta.position = Vector3(0.0, 3.2, 0.0)
	_marcador_raiz.add_child(_etiqueta)

func _process(delta: float) -> void:
	# Suave pulso holográfico
	if _anillo_holo:
		var pulso = 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.06
		_anillo_holo.scale = Vector3(pulso, 1.0, pulso)

func posicionar_spawn(pos_mundo: Vector3) -> void:
	if not _marcador_raiz:
		return
	_marcador_raiz.global_position = Vector3(pos_mundo.x, pos_mundo.y + 0.15, pos_mundo.z)
	spawn_actualizado.emit(_marcador_raiz.global_position, rotacion_y_grados, obtener_modo_nombre())

func rotar_spawn(paso_grados: float = 45.0) -> void:
	rotacion_y_grados = fmod(rotacion_y_grados + paso_grados, 360.0)
	if _marcador_raiz:
		_marcador_raiz.rotation_degrees.y = rotacion_y_grados
	spawn_actualizado.emit(_marcador_raiz.global_position, rotacion_y_grados, obtener_modo_nombre())

func alternar_modo() -> String:
	if modo_spawn == ModoSpawn.VEHICULO:
		modo_spawn = ModoSpawn.A_PIE
	else:
		modo_spawn = ModoSpawn.VEHICULO
	
	_actualizar_texto_etiqueta()
	spawn_actualizado.emit(_marcador_raiz.global_position, rotacion_y_grados, obtener_modo_nombre())
	return obtener_modo_nombre()

func establecer_modo(modo: String) -> void:
	if modo.to_lower() == "a_pie" or modo.to_lower() == "pie":
		modo_spawn = ModoSpawn.A_PIE
	else:
		modo_spawn = ModoSpawn.VEHICULO
	_actualizar_texto_etiqueta()

func _actualizar_texto_etiqueta() -> void:
	if _etiqueta:
		if modo_spawn == ModoSpawn.VEHICULO:
			_etiqueta.text = "🚩 SPAWN: VEHÍCULO"
		else:
			_etiqueta.text = "🚩 SPAWN: A PIE"

func obtener_posicion() -> Vector3:
	if _marcador_raiz:
		return _marcador_raiz.global_position
	return Vector3.ZERO

func obtener_rotacion_y() -> float:
	return rotacion_y_grados

func obtener_transform_spawn() -> Transform3D:
	if _marcador_raiz:
		return _marcador_raiz.global_transform
	return Transform3D.IDENTITY

func obtener_modo_nombre() -> String:
	return "vehiculo" if modo_spawn == ModoSpawn.VEHICULO else "a_pie"

func serializar_spawn() -> Dictionary:
	var pos = obtener_posicion()
	return {
		"posicion": [pos.x, pos.y, pos.z],
		"rotacion_y": rotacion_y_grados,
		"modo": obtener_modo_nombre()
	}

func deserializar_spawn(datos: Dictionary) -> void:
	var pos_arr = datos.get("posicion", [0.0, 0.2, 0.0])
	rotacion_y_grados = datos.get("rotacion_y", 0.0)
	establecer_modo(datos.get("modo", "vehiculo"))
	if _marcador_raiz:
		_marcador_raiz.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		_marcador_raiz.rotation_degrees.y = rotacion_y_grados
