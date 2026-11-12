class_name ControladorAgua
extends Node3D

## ControladorAgua.gd
## Gestión de cuerpos de agua procedurables (Lagos, Embalses y Ríos) para el Editor de Mapas.
## Emplea el shader AAA de shaders/agua_realista.gdshader y colisiones/áreas de flotación.

signal cuerpo_agua_creado(nodo: Node3D)
signal cuerpo_agua_modificado(nodo: Node3D)
signal cuerpo_agua_eliminado(nodo: Node3D)

const SHADER_AGUA := preload("res://shaders/agua_realista.gdshader")

enum TipoAgua {
	LAGO_CIRCULAR,
	LAGO_RECTANGULAR,
	RIO_TRAMO
}

# Referencias externas
var controlador_terreno: Node = null

# Estado y selección
var cuerpo_seleccionado: Node3D = null
var _contenedor_aguas: Node3D = null
var _contador_aguas: int = 0

func _ready() -> void:
	_inicializar_contenedor()

func _inicializar_contenedor() -> void:
	if not _contenedor_aguas or not is_instance_valid(_contenedor_aguas):
		_contenedor_aguas = Node3D.new()
		_contenedor_aguas.name = "ContenedorCuerposAgua"
		add_child(_contenedor_aguas)

## Crea un lago o embalse procedural en la posición dada
func crear_lago(pos_mundo: Vector3, radio: float = 24.0, profundidad: float = 3.5, es_circular: bool = true) -> Node3D:
	_inicializar_contenedor()
	_contador_aguas += 1
	
	var lago_root := Node3D.new()
	lago_root.name = "Lago_%d" % _contador_aguas
	_contenedor_aguas.add_child(lago_root)
	if lago_root.is_inside_tree():
		lago_root.global_position = pos_mundo
	else:
		lago_root.position = pos_mundo
	lago_root.set_meta("tipo_cuerpo", TipoAgua.LAGO_CIRCULAR if es_circular else TipoAgua.LAGO_RECTANGULAR)
	lago_root.set_meta("radio", radio)
	lago_root.set_meta("profundidad", profundidad)
	
	# Malla de superficie de agua
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SuperficieAgua"
	
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(radio * 2.0, radio * 2.0)
	plane_mesh.subdivide_width = 16
	plane_mesh.subdivide_depth = 16
	mesh_inst.mesh = plane_mesh
	
	# Material con Shader Realista
	var mat_shader := ShaderMaterial.new()
	mat_shader.shader = SHADER_AGUA
	mat_shader.set_shader_parameter("color_orilla", Color(0.12, 0.42, 0.45, 0.50))
	mat_shader.set_shader_parameter("color_profundo", Color(0.02, 0.12, 0.22, 0.95))
	mat_shader.set_shader_parameter("color_espuma", Color(0.95, 0.98, 1.0, 0.95))
	mat_shader.set_shader_parameter("fuerza_normal", 1.2)
	mat_shader.set_shader_parameter("rugosidad", 0.05)
	mat_shader.set_shader_parameter("metalico", 0.05)
	mat_shader.set_shader_parameter("velocidad_olas", 1.0)
	mat_shader.set_shader_parameter("altura_olas", 0.08)
	mesh_inst.material_override = mat_shader
	lago_root.add_child(mesh_inst)
	
	# Área 3D para detección de flotación e interacción física
	var area := Area3D.new()
	area.name = "AreaAgua"
	area.add_to_group("area_agua")
	var col_shape := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(radio * 2.0, profundidad * 2.0, radio * 2.0)
	col_shape.shape = box_col
	col_shape.position = Vector3(0, -profundidad * 0.5, 0)
	area.add_child(col_shape)
	lago_root.add_child(area)
	
	cuerpo_agua_creado.emit(lago_root)
	
	# Nivelar/deprimir terreno bajo el agua si el controlador de terreno está activo
	if profundidad > 0.5 and controlador_terreno and controlador_terreno.has_method("obtener_altura"):
		deprimir_terreno_bajo_lago(pos_mundo, radio, profundidad)
		
	return lago_root

## Excava suavemente el lecho del lago en el terreno
func deprimir_terreno_bajo_lago(pos_centro: Vector3, radio: float, profundidad: float) -> void:
	if not controlador_terreno:
		return
	var terr_editor = controlador_terreno.get("terrain_editor")
	if not terr_editor:
		return
		
	# Configurar pincel para excavar lecho de lago
	var dict_brush = {
		"size": radio * 1.8,
		"strength": 0.45,
		"height": pos_centro.y - profundidad
	}
	terr_editor.set_brush_data(dict_brush)
	terr_editor.set_tool(Terrain3DEditor.HEIGHT)
	terr_editor.set_operation(Terrain3DEditor.REPLACE)
	terr_editor.start_operation(pos_centro)
	terr_editor.operate(pos_centro, 0.0)
	terr_editor.stop_operation()
	if controlador_terreno.has_signal("terreno_modificado"):
		controlador_terreno.terreno_modificado.emit()

## Crea un tramo de río continuo mediante una cinta o spline
func crear_tramo_rio(puntos_mundo: Array[Vector3], ancho: float = 7.0) -> Node3D:
	if puntos_mundo.size() < 2:
		return null
	_inicializar_contenedor()
	_contador_aguas += 1
	
	var rio_root := Node3D.new()
	rio_root.name = "Rio_%d" % _contador_aguas
	rio_root.global_position = puntos_mundo[0]
	rio_root.set_meta("tipo_cuerpo", TipoAgua.RIO_TRAMO)
	rio_root.set_meta("ancho", ancho)
	rio_root.set_meta("puntos", puntos_mundo)
	
	# Construir cinta de agua
	var im := ImmediateMesh.new()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "SuperficieRio"
	mesh_inst.mesh = im
	
	var mat_shader := ShaderMaterial.new()
	mat_shader.shader = SHADER_AGUA
	mat_shader.set_shader_parameter("color_orilla", Color(0.14, 0.44, 0.42, 0.60))
	mat_shader.set_shader_parameter("color_profundo", Color(0.04, 0.16, 0.20, 0.95))
	mat_shader.set_shader_parameter("velocidad_olas", 1.8) # Flujo más rápido para río
	mat_shader.set_shader_parameter("altura_olas", 0.06)
	mesh_inst.material_override = mat_shader
	
	# Generar quads a lo largo de la ruta
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat_shader)
	var acum_dist := 0.0
	for i in range(puntos_mundo.size()):
		var p = puntos_mundo[i] - rio_root.global_position
		var fwd := Vector3.FORWARD
		if i + 1 < puntos_mundo.size():
			fwd = (puntos_mundo[i + 1] - puntos_mundo[i]).normalized()
		elif i > 0:
			fwd = (puntos_mundo[i] - puntos_mundo[i - 1]).normalized()
		var lat := fwd.cross(Vector3.UP).normalized() * (ancho * 0.5)
		
		if i > 0:
			acum_dist += puntos_mundo[i].distance_to(puntos_mundo[i - 1])
		var v_coord = acum_dist / maxf(1.0, ancho)
		
		im.surface_set_uv(Vector2(0.0, v_coord))
		im.surface_add_vertex(p - lat)
		im.surface_set_uv(Vector2(1.0, v_coord))
		im.surface_add_vertex(p + lat)
	im.surface_end()
	
	rio_root.add_child(mesh_inst)
	_contenedor_aguas.add_child(rio_root)
	cuerpo_agua_creado.emit(rio_root)
	return rio_root

## Selecciona un cuerpo de agua cercano
func seleccionar_cuerpo_cercano(pos_mundo: Vector3, radio_max: float = 12.0) -> Node3D:
	if not _contenedor_aguas:
		return null
	var mejor_dist = radio_max
	var mejor_cuerpo: Node3D = null
	for hijo in _contenedor_aguas.get_children():
		var node = hijo as Node3D
		if not node:
			continue
		var d = pos_mundo.distance_to(node.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor_cuerpo = node
	cuerpo_seleccionado = mejor_cuerpo
	return mejor_cuerpo

## Modifica la elevación o nivel de agua del cuerpo seleccionado
func modificar_nivel_agua(delta_y: float) -> float:
	if cuerpo_seleccionado and is_instance_valid(cuerpo_seleccionado):
		cuerpo_seleccionado.global_position.y += delta_y
		cuerpo_agua_modificado.emit(cuerpo_seleccionado)
		return cuerpo_seleccionado.global_position.y
	return 0.0

## Elimina el cuerpo de agua seleccionado
func eliminar_cuerpo_seleccionado() -> bool:
	if cuerpo_seleccionado and is_instance_valid(cuerpo_seleccionado):
		var target = cuerpo_seleccionado
		cuerpo_seleccionado = null
		cuerpo_agua_eliminado.emit(target)
		target.queue_free()
		return true
	return false

## Limpia todos los cuerpos de agua
func limpiar_todo_agua() -> void:
	cuerpo_seleccionado = null
	if _contenedor_aguas:
		for hijo in _contenedor_aguas.get_children():
			hijo.queue_free()

## Serialización para .ntmap
func serializar_aguas() -> Array:
	var lista: Array = []
	if not _contenedor_aguas:
		return lista
	for hijo in _contenedor_aguas.get_children():
		var node = hijo as Node3D
		if not node:
			continue
		var tipo: int = int(node.get_meta("tipo_cuerpo", 0))
		var radio: float = float(node.get_meta("radio", 20.0))
		var prof: float = float(node.get_meta("profundidad", 3.0))
		var puntos = node.get_meta("puntos", [])
		var p_ser: Array = []
		for p in puntos:
			p_ser.append([p.x, p.y, p.z])
			
		var p_pos: Vector3 = node.global_position if node.is_inside_tree() else node.position
		lista.append({
			"tipo": tipo,
			"posicion": [p_pos.x, p_pos.y, p_pos.z],
			"radio": radio,
			"profundidad": prof,
			"puntos": p_ser
		})
	return lista

## Deserialización desde .ntmap
func deserializar_aguas(lista: Array) -> void:
	limpiar_todo_agua()
	for it in lista:
		var tipo: int = int(it.get("tipo", 0))
		var pos_arr = it.get("posicion", [0, 0, 0])
		var pos := Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		var rad: float = float(it.get("radio", 20.0))
		var prof: float = float(it.get("profundidad", 3.0))
		if tipo == TipoAgua.RIO_TRAMO:
			var pts_arr = it.get("puntos", [])
			var pts: Array[Vector3] = []
			for p in pts_arr:
				pts.append(Vector3(p[0], p[1], p[2]))
			if pts.size() >= 2:
				crear_tramo_rio(pts, rad)
		else:
			crear_lago(pos, rad, prof, tipo == TipoAgua.LAGO_CIRCULAR)
