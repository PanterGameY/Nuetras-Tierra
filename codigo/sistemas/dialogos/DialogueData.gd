# DialogueData.gd - Recurso de datos de diálogos para NPCs
class_name DialogueData
extends Resource

@export var npc_nombre: String = "NPC"
@export var texto_inicial: String = ""
@export var opcion_inicial_grupo: String = ""
@export var opciones: Dictionary = {} # opcion_nombre -> respuesta_texto
@export var opciones_por_grupo: Dictionary = {} # grupo_nombre -> Array[opcion_nombre]
@export var siguiente_grupo_por_opcion: Dictionary = {} # opcion_nombre -> siguiente_grupo
