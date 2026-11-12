extends RefCounted
class_name CatalogoRuedasTrailer

# ═══════════════════════════════════════════════════════════════════════
# CatalogoRuedasTrailer — Galería y Catálogo Centralizado de Ruedas
# Permite registrar, consultar y aplicar distintos tipos de ruedas/rines
# a cualquier tráiler o remolque tanto en el editor como en runtime.
#
# ¡NO ES NECESARIO CREAR UNA ESCENA (.tscn) POR CADA RUEDA!
# Puedes pasar simplemente la ruta a un archivo .glb del rin y el sistema
# le ensambla los neumáticos dobles de remolque de forma 100% automática.
# ═══════════════════════════════════════════════════════════════════════

const RUTA_BASE_NEUMATICOS: String = "res://modelos3d/vehiculos/Rines/rines/Rin_T2.tscn"

# Registro dinámico de presets (en tiempo de ejecución o inicial)
static var _presets_dinamicos: Dictionary = {}

const PRESETS_BASE: Dictionary = {
	"rin_t2_cromo": {
		"id": "rin_t2_cromo",
		"nombre": "Disco Cromado Americano (T2)",
		"estilo": "Cromado",
		"descripcion": "Doble neumático de remolque con rines de disco cromados, copa central pulida y tuercas reforzadas.",
		"escena_path": "res://modelos3d/vehiculos/Rines/rines/Rin_T2.tscn",
		"radio_rueda": 0.52,
		"largo_reposo": 0.12,
		"offset_lado": 0.0,
		"acabado_defecto": {
			"color": Color(0.95, 0.95, 0.95),
			"metallic": 0.95,
			"roughness": 0.15
		}
	},
	"rin_t3_aluminio": {
		"id": "rin_t3_aluminio",
		"nombre": "Aluminio Alcoa Pulido (T3)",
		"estilo": "Aluminio",
		"descripcion": "Rines livianos de aluminio forjado y pulido con orificios circulares de ventilación para frenos de remolque.",
		"rin_glb": "res://modelos3d/vehiculos/Rines/rines/Rines Traseros/3.glb",
		"escala_rin": 0.68,
		"radio_rueda": 0.52,
		"largo_reposo": 0.12,
		"offset_lado": 0.0,
		"acabado_defecto": {
			"color": Color(0.90, 0.92, 0.95),
			"metallic": 0.85,
			"roughness": 0.25
		}
	},
	"rin_t1_artillado": {
		"id": "rin_t1_artillado",
		"nombre": "Artillada Trochera (T1)",
		"estilo": "Artillado",
		"descripcion": "Rin tradicional colombiano tipo artillada / araña de cinco radios con campana central para trocha pesada.",
		"rin_glb": "res://modelos3d/vehiculos/Rines/rines/Rines Traseros/1.glb",
		"escala_rin": 0.65,
		"radio_rueda": 0.53,
		"largo_reposo": 0.12,
		"offset_lado": 0.0,
		"acabado_defecto": {
			"color": Color(0.20, 0.20, 0.22),
			"metallic": 0.60,
			"roughness": 0.45
		}
	},
	"rin_t4_trochero": {
		"id": "rin_t4_trochero",
		"nombre": "Disco Ventilado 8 Huecos (T4)",
		"estilo": "Servicio Pesado",
		"descripcion": "Rin de acero estampado de 8 perforaciones para distribución uniforme de carga en terrenos quebrados.",
		"rin_glb": "res://modelos3d/vehiculos/Rines/rines/Rines Traseros/2.glb",
		"escala_rin": 0.66,
		"radio_rueda": 0.52,
		"largo_reposo": 0.12,
		"offset_lado": 0.0,
		"acabado_defecto": {
			"color": Color(0.40, 0.40, 0.42),
			"metallic": 0.70,
			"roughness": 0.35
		}
	},
	"original_carpado": {
		"id": "original_carpado",
		"nombre": "Serie Remolque Estándar",
		"estilo": "Original",
		"descripcion": "Montaje original de fábrica con neumáticos duales de transporte nacional de carga seca.",
		"escena_path": "", # Usa las mallas nativas del trailer o fallback
		"radio_rueda": 0.50,
		"largo_reposo": 0.12,
		"offset_lado": 0.0,
		"acabado_defecto": {
			"color": Color(0.35, 0.35, 0.35),
			"metallic": 0.50,
			"roughness": 0.50
		}
	}
}

const PRESET_DEFAULT_ID: String = "rin_t2_cromo"

## Permite registrar un nuevo rin al catálogo pasando únicamente el archivo .glb (¡CERO escenas .tscn necesarias!)
static func registrar_rin_glb(
	id: String,
	nombre: String,
	ruta_glb: String,
	estilo: String = "Personalizado",
	descripcion: String = "",
	radio_rueda: float = 0.52,
	escala_rin: float = 0.66
) -> void:
	var desc = descripcion
	if desc == "":
		desc = "Rin personalizado equipado con doble neumático de remolque para carga pesada."
	_presets_dinamicos[id] = {
		"id": id,
		"nombre": nombre,
		"estilo": estilo,
		"descripcion": desc,
		"rin_glb": ruta_glb,
		"escala_rin": escala_rin,
		"radio_rueda": radio_rueda,
		"largo_reposo": 0.20,
		"offset_lado": 0.0,
		"acabado_defecto": {
			"color": Color(0.9, 0.9, 0.9),
			"metallic": 0.8,
			"roughness": 0.2
		}
	}

## Retorna un diccionario combinado de los presets base y los dinámicos
static func _obtener_diccionario_presets() -> Dictionary:
	var dic = PRESETS_BASE.duplicate(true)
	for k in _presets_dinamicos.keys():
		dic[k] = _presets_dinamicos[k].duplicate(true)
	return dic

## Retorna la lista completa de presets disponibles en la galería
static func obtener_todos() -> Array[Dictionary]:
	var presets = _obtener_diccionario_presets()
	var lista: Array[Dictionary] = []
	for k in presets.keys():
		lista.append(presets[k].duplicate(true))
	return lista

## Retorna la lista de identificadores para selectores
static func obtener_ids() -> Array[String]:
	var presets = _obtener_diccionario_presets()
	var ids: Array[String] = []
	for k in presets.keys():
		ids.append(k)
	return ids

## Retorna la configuración de un preset específico por su ID
static func obtener_config(id: String) -> Dictionary:
	var presets = _obtener_diccionario_presets()
	if presets.has(id):
		return presets[id].duplicate(true)
	if presets.has(PRESET_DEFAULT_ID):
		return presets[PRESET_DEFAULT_ID].duplicate(true)
	return {}

## Comprueba si un ID de rueda existe en el catálogo
static func existe_id(id: String) -> bool:
	var presets = _obtener_diccionario_presets()
	return presets.has(id)

## Extrae o instancia de forma limpia el nodo visual Node3D para acoplarlo a una RuedaTrailer
static func instanciar_nodo_visual(id: String) -> Node3D:
	var cfg = obtener_config(id)

	# 1. Si el preset especifica un modelo .glb directo (¡NO requiere crear escena .tscn!):
	var ruta_glb = cfg.get("rin_glb", "")
	if ruta_glb != "" and ResourceLoader.exists(ruta_glb):
		var escala = float(cfg.get("escala_rin", 0.65))
		return ensamblar_rueda_desde_glb(ruta_glb, escala)

	# 2. Si el preset tiene una escena .tscn existente:
	var path_escena: String = cfg.get("escena_path", "")
	if path_escena != "" and ResourceLoader.exists(path_escena):
		var scene_res = load(path_escena) as PackedScene
		if scene_res:
			var inst = scene_res.instantiate()
			if inst:
				# Extraer el contenedor visual hijo si la raíz era un RayCast3D
				if inst is RayCast3D:
					for child in inst.get_children():
						if child is Node3D and not (child is RayCast3D) and not (child is CollisionObject3D):
							inst.remove_child(child)
							inst.queue_free()
							return child
				if inst is Node3D:
					return inst as Node3D

	# 3. Fallback: si no existe la ruta o es original sin mallas, usar preset por defecto
	if id != PRESET_DEFAULT_ID:
		return instanciar_nodo_visual(PRESET_DEFAULT_ID)
	return null

## Ensambla automáticamente cualquier rin .glb con los neumáticos duales estándar de remolque
static func ensamblar_rueda_desde_glb(ruta_glb: String, escala: float = 0.65, offset_x: float = 0.02) -> Node3D:
	if not ResourceLoader.exists(RUTA_BASE_NEUMATICOS):
		push_error("CatalogoRuedasTrailer: No se encontró la escena base de neumáticos: " + RUTA_BASE_NEUMATICOS)
		return null

	var base_scene = load(RUTA_BASE_NEUMATICOS) as PackedScene
	if not base_scene:
		return null

	var base_inst = base_scene.instantiate()
	var contenedor: Node3D = null
	for child in base_inst.get_children():
		if child is Node3D and not (child is RayCast3D):
			contenedor = child
			break

	if not contenedor:
		base_inst.queue_free()
		return null

	base_inst.remove_child(contenedor)
	base_inst.queue_free()

	# Ocultar las mallas de disco originales dejando exclusivamente los neumáticos N1 y N2
	for n_name in ["1", "2", "3"]:
		var m = contenedor.get_node_or_null(n_name)
		if m:
			m.visible = false

	# Cargar e instanciar el archivo .glb del rin en el centro de los neumáticos
	var glb_scene = load(ruta_glb) as PackedScene
	if glb_scene:
		var rin_node = glb_scene.instantiate()
		rin_node.name = "RinGLB"
		rin_node.scale = Vector3(escala, escala, escala)
		rin_node.position = Vector3(offset_x, 0.0, 0.0)
		contenedor.add_child(rin_node)

	return contenedor
