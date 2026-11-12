class_name SelectorRigHumanoide
extends Control

## Panel selector visual de partes del cuerpo para esqueletos humanoides o estándar.
## Permite seleccionar rápidamente cualquier extremidad con un solo clic.

signal parte_solicitada(nombre_patron: String)

@export var controlador: ControladorAnimacion

# Mapeo de botones hacia nombres Mixamo o estándar
const MAPA_HUESOS: Dictionary = {
	"cabeza": ["mixamorig_Head", "Head", "head", "cabeza"],
	"cuello": ["mixamorig_Neck", "Neck", "neck", "cuello"],
	"pecho": ["mixamorig_Spine2", "mixamorig_Spine1", "Chest", "Spine2", "chest"],
	"columna": ["mixamorig_Spine", "Spine", "spine"],
	"cadera": ["mixamorig_Hips", "Hips", "pelvis", "cadera", "root"],
	
	"hombro_izq": ["mixamorig_LeftShoulder", "LeftShoulder", "shoulder.l", "hombro_izq"],
	"brazo_izq": ["mixamorig_LeftArm", "LeftUpperArm", "upper_arm.l", "brazo_izq"],
	"antebrazo_izq": ["mixamorig_LeftForeArm", "LeftLowerArm", "forearm.l", "antebrazo_izq"],
	"mano_izq": ["mixamorig_LeftHand", "LeftHand", "hand.l", "mano_izq"],
	
	"hombro_der": ["mixamorig_RightShoulder", "RightShoulder", "shoulder.r", "hombro_der"],
	"brazo_der": ["mixamorig_RightArm", "RightUpperArm", "upper_arm.r", "brazo_der"],
	"antebrazo_der": ["mixamorig_RightForeArm", "RightLowerArm", "forearm.r", "antebrazo_der"],
	"mano_der": ["mixamorig_RightHand", "RightHand", "hand.r", "mano_der"],
	
	"muslo_izq": ["mixamorig_LeftUpLeg", "LeftUpperLeg", "thigh.l", "muslo_izq"],
	"pantorrilla_izq": ["mixamorig_LeftLeg", "LeftLowerLeg", "shin.l", "pierna_izq"],
	"pie_izq": ["mixamorig_LeftFoot", "LeftFoot", "foot.l", "pie_izq"],
	"dedos_pie_izq": ["mixamorig_LeftToeBase", "LeftToe", "toe.l"],
	
	"muslo_der": ["mixamorig_RightUpLeg", "RightUpperLeg", "thigh.r", "muslo_der"],
	"pantorrilla_der": ["mixamorig_RightLeg", "RightLowerLeg", "shin.r", "pierna_der"],
	"pie_der": ["mixamorig_RightFoot", "RightFoot", "foot.r", "pie_der"],
	"dedos_pie_der": ["mixamorig_RightToeBase", "RightToe", "toe.r"]
}

func seleccionar_parte(clave_parte: String):
	if not controlador or not controlador.esqueleto:
		return
		
	var patrones: Array = MAPA_HUESOS.get(clave_parte, [clave_parte])
	var skel = controlador.esqueleto
	
	for pat in patrones:
		var idx = skel.find_bone(pat)
		if idx >= 0:
			controlador.seleccionar_hueso_por_indice(idx)
			return
			
	# Si no se encontró exactamente, buscar coincidencia parcial
	for i in range(skel.get_bone_count()):
		var b_name = skel.get_bone_name(i).to_lower()
		for pat in patrones:
			if b_name.contains(pat.to_lower()):
				controlador.seleccionar_hueso_por_indice(i)
				return
