extends RefCounted
class_name TrailerFactory

# ═══════════════════════════════════════════════════════════════════════
# TrailerFactory — Creador e Instanciador Configurable de Remolques
# Permite crear e instanciar cualquier remolque en el juego configurando
# el tipo de rueda, acabado de rines, posición y enganche inicial.
# ═══════════════════════════════════════════════════════════════════════

const RUTA_CHASIS_DEFECTO: String = "res://modelos3d/vehiculos/Trailers/chasis/CT_1.tscn"
const RUTA_CARPADO_DEFECTO: String = "res://modelos3d/vehiculos/Trailers/escenas/Carpado1.tscn"

## Instancia un trailer configurado con el tipo de rueda deseado
static func crear_trailer(
	ruta_escena: String = RUTA_CHASIS_DEFECTO,
	tipo_rueda_id: String = "rin_t2_cromo",
	posicion_global: Vector3 = Vector3.ZERO,
	rotacion_global: Vector3 = Vector3.ZERO,
	acabado_rines: Dictionary = {}
) -> RigidBody3D:
	if not ResourceLoader.exists(ruta_escena):
		push_error("TrailerFactory: La ruta de escena del remolque no existe: " + ruta_escena)
		return null

	var scene_res = load(ruta_escena) as PackedScene
	if not scene_res:
		push_error("TrailerFactory: No se pudo cargar la PackedScene: " + ruta_escena)
		return null

	var trailer = scene_res.instantiate() as RigidBody3D
	if not trailer:
		push_error("TrailerFactory: La escena instanciada no es RigidBody3D: " + ruta_escena)
		return null

	if posicion_global != Vector3.ZERO:
		trailer.position = posicion_global
	if rotacion_global != Vector3.ZERO:
		trailer.rotation = rotacion_global

	# Configurar el tipo de rueda si el trailer tiene la propiedad o método
	if "tipo_ruedas" in trailer:
		trailer.set("tipo_ruedas", tipo_rueda_id)
	elif trailer.has_method("aplicar_tipo_ruedas"):
		trailer.call("aplicar_tipo_ruedas", tipo_rueda_id)

	# Configurar acabado opcional de rines
	if not acabado_rines.is_empty() and trailer.has_method("aplicar_color_rines"):
		var col = acabado_rines.get("color", Color.TRANSPARENT)
		var met = acabado_rines.get("metallic", -1.0)
		var rough = acabado_rines.get("roughness", -1.0)
		trailer.call("aplicar_color_rines", col, met, rough)

	return trailer
