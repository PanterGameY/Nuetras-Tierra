# TiendaItems.gd
# Catálogo centralizado de productos y generador de modelos 3D procedurales para items en mano.
# Totalmente optimizado para alto rendimiento en PC y Android con materiales StandardMaterial3D y render_priority alta.
class_name TiendaItems
extends RefCounted

enum Categoria {
	TODOS,
	BEBIDAS_Y_SNACKS,
	HERRAMIENTAS,
	EQUIPAMIENTO
}

## Lista de productos disponibles en la tienda
static func get_catalogo() -> Array[Dictionary]:
	return [
		{
			"id": "bloque_suministros",
			"nombre": "Bloque de Provisiones",
			"categoria": Categoria.EQUIPAMIENTO,
			"precio": 1500.0,
			"descripcion": "Caja cúbica de provisiones campesinas con refuerzos de hierro forjado. Sostenla en la mano exactamente como un bloque cúbico en Minecraft.",
			"icono_color": Color(0.75, 0.52, 0.28),
			"badge": "★ ESTILO BLOQUE 3D",
			"consumible": false,
			"efecto_tipo": "bloque",
			"efecto_valor": 1.0,
			"duracion": 0.0
		},
		{
			"id": "cafe_tinto",
			"nombre": "Café Tinto Paisa",
			"categoria": Categoria.BEBIDAS_Y_SNACKS,
			"precio": 2500.0,
			"descripcion": "Café de origen campesino recién colado. Otorga un impulso de energía y acelera tu velocidad de movimiento por 60 segundos.",
			"icono_color": Color(0.72, 0.45, 0.20),
			"badge": "⚡ +35% VELOCIDAD",
			"consumible": true,
			"efecto_tipo": "velocidad",
			"efecto_valor": 1.35,
			"duracion": 60.0
		},
		{
			"id": "bebida_energizante",
			"nombre": "Energizante 'El Camionero'",
			"categoria": Categoria.BEBIDAS_Y_SNACKS,
			"precio": 4500.0,
			"descripcion": "Bebida taurina de alta concentración. Restaura la resistencia al instante y elimina el agotamiento en rutas pesadas.",
			"icono_color": Color(0.20, 0.90, 0.45),
			"badge": "🔋 RESISTENCIA MÁXIMA",
			"consumible": true,
			"efecto_tipo": "energia",
			"efecto_valor": 1.5,
			"duracion": 90.0
		},
		{
			"id": "botella_agua",
			"nombre": "Agua Mineral de Manantial",
			"categoria": Categoria.BEBIDAS_Y_SNACKS,
			"precio": 1800.0,
			"descripcion": "Agua purificada fría de la cordillera. Hidratación esencial para largas jornadas de conducción y trabajo a pie.",
			"icono_color": Color(0.25, 0.65, 0.95),
			"badge": "💧 HIDRATACIÓN PURA",
			"consumible": true,
			"efecto_tipo": "salud",
			"efecto_valor": 1.0,
			"duracion": 0.0
		},
		{
			"id": "linterna_tactica",
			"nombre": "Linterna Táctica LED Ultra",
			"categoria": Categoria.HERRAMIENTAS,
			"precio": 25000.0,
			"descripcion": "Linterna de aluminio aeronáutico con proyector frontal de largo alcance. Emite un potente haz de luz funcional en la oscuridad.",
			"icono_color": Color(0.95, 0.85, 0.35),
			"badge": "🔦 PROYECTOR 35m",
			"consumible": false,
			"efecto_tipo": "luz",
			"efecto_valor": 1.0,
			"duracion": -1.0
		},
		{
			"id": "bidon_gasolina",
			"nombre": "Bidón Diésel 20 Litros",
			"categoria": Categoria.HERRAMIENTAS,
			"precio": 45000.0,
			"descripcion": "Galón con combustible diésel de reserva para repostar y reanimar vehículos varados en la carretera.",
			"icono_color": Color(0.90, 0.25, 0.20),
			"badge": "⛽ +20L COMBUSTIBLE",
			"consumible": true,
			"efecto_tipo": "combustible",
			"efecto_valor": 20.0,
			"duracion": 0.0
		},
		{
			"id": "caja_herramientas",
			"nombre": "Caja de Llaves y Herramientas",
			"categoria": Categoria.HERRAMIENTAS,
			"precio": 60000.0,
			"descripcion": "Kit mecánico profesional en cofre reforzado para despinchar llantas y mantenimiento de chasis de camiones.",
			"icono_color": Color(0.85, 0.40, 0.15),
			"badge": "🛠 REPARACIÓN DE RUTA",
			"consumible": true,
			"efecto_tipo": "reparacion",
			"efecto_valor": 50.0,
			"duracion": 0.0
		},
		{
			"id": "gato_hidraulico",
			"nombre": "Gato Hidráulico Truper 2T",
			"categoria": Categoria.HERRAMIENTAS,
			"precio": 35000.0,
			"descripcion": "Gato hidráulico de patín 2 toneladas reforzado con palanca desmontable y ruedas de arrastre. Incluye modo de colocación diegético y ciclo mecánico interactivo.",
			"icono_color": Color(0.95, 0.35, 0.08),
			"badge": "★ PRUEBAS Y TALLER",
			"consumible": false,
			"efecto_tipo": "herramienta_gato",
			"efecto_valor": 1.0,
			"duracion": 0.0
		},
		{
			"id": "mochila_tactica",
			"nombre": "Mochila de Lona Reforzada",
			"categoria": Categoria.EQUIPAMIENTO,
			"precio": 75000.0,
			"descripcion": "Mochila táctica con compartimentos de lona y correas de alta resistencia. Amplía tu inventario a 10 slots permanentes.",
			"icono_color": Color(0.40, 0.50, 0.35),
			"badge": "🎒 +8 SLOTS INVENTARIO",
			"consumible": true,
			"efecto_tipo": "mochila",
			"efecto_valor": 10.0,
			"duracion": 0.0
		}
	]

## Obtener datos de un producto específico
static func get_item(p_id: String) -> Dictionary:
	for item in get_catalogo():
		if item["id"] == p_id:
			return item
	return {}

## Helper para crear material con render_priority alta (evita clipping con paredes y terreno)
static func _crear_material(color: Color, metallic: float = 0.1, roughness: float = 0.5, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.render_priority = 10
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.2
	return mat

## Construye un modelo 3D optimizado para el item en pantalla / manos
static func crear_modelo_3d(p_id: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "ItemModel_" + p_id

	match p_id:
		"bloque_suministros":
			_construir_bloque_minecraft(raiz)
		"cafe_tinto":
			_construir_vaso_cafe(raiz)
		"bebida_energizante":
			_construir_lata_energizante(raiz)
		"botella_agua":
			_construir_botella_agua(raiz)
		"linterna_tactica":
			_construir_linterna(raiz)
		"bidon_gasolina":
			_construir_bidon(raiz)
		"caja_herramientas":
			_construir_caja_herramientas(raiz)
		"mochila_tactica":
			_construir_mochila(raiz)
		_:
			_construir_bloque_minecraft(raiz)

	return raiz

# ─────────────────────────────────────────────────────────────
#  CONSTRUCTORES PROCEDURALES DE MODELOS 3D
# ─────────────────────────────────────────────────────────────

## Bloque 3D estilo Minecraft (Cubo con esquineros metálicos y listones de madera)
static func _construir_bloque_minecraft(parent: Node3D) -> void:
	# Cubo central principal de madera
	var cubo := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.20, 0.20, 0.20)
	cubo.mesh = box
	cubo.material_override = _crear_material(Color(0.62, 0.42, 0.24), 0.05, 0.75)
	parent.add_child(cubo)

	# Marco de hierro / esquineros metálicos reforzados
	var marco_top := MeshInstance3D.new()
	var box_top := BoxMesh.new()
	box_top.size = Vector3(0.206, 0.024, 0.206)
	marco_top.mesh = box_top
	marco_top.position.y = 0.09
	marco_top.material_override = _crear_material(Color(0.22, 0.24, 0.26), 0.8, 0.35)
	parent.add_child(marco_top)

	var marco_bot := MeshInstance3D.new()
	var box_bot := BoxMesh.new()
	box_bot.size = Vector3(0.206, 0.024, 0.206)
	marco_bot.mesh = box_bot
	marco_bot.position.y = -0.09
	marco_bot.material_override = _crear_material(Color(0.22, 0.24, 0.26), 0.8, 0.35)
	parent.add_child(marco_bot)

	# Tornillos / remaches en las esquinas
	var cinta := MeshInstance3D.new()
	var box_cinta := BoxMesh.new()
	box_cinta.size = Vector3(0.208, 0.04, 0.04)
	cinta.mesh = box_cinta
	cinta.material_override = _crear_material(Color(0.88, 0.68, 0.28), 0.6, 0.4) # Acento ámbar
	parent.add_child(cinta)

## Vaso de café de carretera con faja de cartón y café caliente
static func _construir_vaso_cafe(parent: Node3D) -> void:
	# Vaso blanco térmico
	var cuerpo := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.065
	cyl.bottom_radius = 0.048
	cyl.height = 0.18
	cuerpo.mesh = cyl
	cuerpo.material_override = _crear_material(Color(0.96, 0.94, 0.90), 0.1, 0.6)
	parent.add_child(cuerpo)

	# Faja marrón de cartón
	var faja := MeshInstance3D.new()
	var cyl_f := CylinderMesh.new()
	cyl_f.top_radius = 0.066
	cyl_f.bottom_radius = 0.054
	cyl_f.height = 0.08
	faja.mesh = cyl_f
	faja.material_override = _crear_material(Color(0.55, 0.35, 0.20), 0.0, 0.9)
	parent.add_child(faja)

	# Tapa plástica negra/roja
	var tapa := MeshInstance3D.new()
	var cyl_t := CylinderMesh.new()
	cyl_t.top_radius = 0.068
	cyl_t.bottom_radius = 0.065
	cyl_t.height = 0.025
	tapa.mesh = cyl_t
	tapa.position.y = 0.095
	tapa.material_override = _crear_material(Color(0.12, 0.12, 0.14), 0.3, 0.4)
	parent.add_child(tapa)

	# Superficie de café oscuro
	var cafe := MeshInstance3D.new()
	var cyl_c := CylinderMesh.new()
	cyl_c.top_radius = 0.062
	cyl_c.bottom_radius = 0.062
	cyl_c.height = 0.005
	cafe.mesh = cyl_c
	cafe.position.y = 0.085
	cafe.material_override = _crear_material(Color(0.14, 0.08, 0.04), 0.2, 0.2)
	parent.add_child(cafe)

## Lata de energizante metálica
static func _construir_lata_energizante(parent: Node3D) -> void:
	var cuerpo := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.048
	cyl.bottom_radius = 0.048
	cyl.height = 0.21
	cuerpo.mesh = cyl
	# Verde neón metálico con acento
	cuerpo.material_override = _crear_material(Color(0.15, 0.85, 0.35), 0.85, 0.25, Color(0.05, 0.25, 0.10))
	parent.add_child(cuerpo)

	# Aro superior e inferior de aluminio pulido
	var aro_top := MeshInstance3D.new()
	var cyl_top := CylinderMesh.new()
	cyl_top.top_radius = 0.046
	cyl_top.bottom_radius = 0.048
	cyl_top.height = 0.02
	aro_top.mesh = cyl_top
	aro_top.position.y = 0.11
	aro_top.material_override = _crear_material(Color(0.88, 0.90, 0.92), 0.95, 0.15)
	parent.add_child(aro_top)

	# Lengüeta / Destapador
	var tab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.005, 0.04)
	tab.mesh = box
	tab.position = Vector3(0.0, 0.122, -0.01)
	tab.material_override = _crear_material(Color(0.85, 0.88, 0.92), 0.9, 0.2)
	parent.add_child(tab)

## Botella de agua mineral translúcida
static func _construir_botella_agua(parent: Node3D) -> void:
	var cuerpo := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.046
	cyl.bottom_radius = 0.046
	cyl.height = 0.19
	cuerpo.mesh = cyl
	
	var mat_agua := StandardMaterial3D.new()
	mat_agua.albedo_color = Color(0.45, 0.75, 0.95, 0.85)
	mat_agua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_agua.roughness = 0.1
	mat_agua.metallic = 0.1
	mat_agua.render_priority = 10
	cuerpo.material_override = mat_agua
	parent.add_child(cuerpo)

	# Etiqueta azul marino
	var etiqueta := MeshInstance3D.new()
	var cyl_e := CylinderMesh.new()
	cyl_e.top_radius = 0.047
	cyl_e.bottom_radius = 0.047
	cyl_e.height = 0.07
	etiqueta.mesh = cyl_e
	etiqueta.material_override = _crear_material(Color(0.10, 0.40, 0.75), 0.1, 0.4)
	parent.add_child(etiqueta)

	# Tapa de rosca azul
	var tapa := MeshInstance3D.new()
	var cyl_t := CylinderMesh.new()
	cyl_t.top_radius = 0.024
	cyl_t.bottom_radius = 0.024
	cyl_t.height = 0.035
	tapa.mesh = cyl_t
	tapa.position.y = 0.11
	tapa.material_override = _crear_material(Color(0.05, 0.35, 0.80), 0.2, 0.3)
	parent.add_child(tapa)

## Linterna táctica funcional con haz de luz proyectado hacia adelante
static func _construir_linterna(parent: Node3D) -> void:
	# Tubo / Mango estriado de aluminio negro
	var tubo := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 0.22
	tubo.mesh = cyl
	tubo.rotation.x = deg_to_rad(90.0) # Apunta hacia el frente (-Z)
	tubo.material_override = _crear_material(Color(0.12, 0.13, 0.14), 0.7, 0.3)
	parent.add_child(tubo)

	# Cabeza reflectora ancha
	var cabeza := MeshInstance3D.new()
	var cyl_c := CylinderMesh.new()
	cyl_c.top_radius = 0.048
	cyl_c.bottom_radius = 0.032
	cyl_c.height = 0.07
	cabeza.mesh = cyl_c
	cabeza.rotation.x = deg_to_rad(90.0)
	cabeza.position.z = -0.13
	cabeza.material_override = _crear_material(Color(0.18, 0.20, 0.22), 0.8, 0.25)
	parent.add_child(cabeza)

	# Lente LED emisor
	var lente := MeshInstance3D.new()
	var cyl_l := CylinderMesh.new()
	cyl_l.top_radius = 0.045
	cyl_l.bottom_radius = 0.045
	cyl_l.height = 0.01
	lente.mesh = cyl_l
	lente.rotation.x = deg_to_rad(90.0)
	lente.position.z = -0.165
	lente.material_override = _crear_material(Color(0.95, 0.95, 0.85), 0.0, 0.1, Color(1.0, 0.95, 0.80))
	parent.add_child(lente)

	# Luz SpotLight3D funcional proyectada al frente
	var luz := SpotLight3D.new()
	luz.name = "LuzLinterna"
	luz.light_color = Color(1.0, 0.96, 0.88)
	luz.light_energy = 3.5
	luz.spot_range = 35.0
	luz.spot_angle = 32.0
	luz.spot_attenuation = 1.2
	luz.shadow_enabled = true
	luz.position.z = -0.18
	luz.rotation_degrees.y = 180.0 # Apunta hacia adelante en el eje -Z
	parent.add_child(luz)

## Bidón Diésel de 20 Litros
static func _construir_bidon(parent: Node3D) -> void:
	var cuerpo := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.24, 0.24)
	cuerpo.mesh = box
	cuerpo.material_override = _crear_material(Color(0.85, 0.20, 0.16), 0.2, 0.4) # Rojo combustible
	parent.add_child(cuerpo)

	# Asa triple superior
	var asa := MeshInstance3D.new()
	var box_a := BoxMesh.new()
	box_a.size = Vector3(0.04, 0.05, 0.18)
	asa.mesh = box_a
	asa.position.y = 0.14
	asa.material_override = _crear_material(Color(0.70, 0.16, 0.13), 0.2, 0.5)
	parent.add_child(asa)

	# Tapa de llenado amarilla
	var tapa := MeshInstance3D.new()
	var cyl_t := CylinderMesh.new()
	cyl_t.top_radius = 0.026
	cyl_t.bottom_radius = 0.026
	cyl_t.height = 0.03
	tapa.mesh = cyl_t
	tapa.position = Vector3(0.04, 0.13, -0.07)
	tapa.material_override = _crear_material(Color(0.92, 0.80, 0.20), 0.3, 0.3)
	parent.add_child(tapa)

## Caja de herramientas mecánicas
static func _construir_caja_herramientas(parent: Node3D) -> void:
	var cuerpo := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.17, 0.14, 0.26)
	cuerpo.mesh = box
	cuerpo.material_override = _crear_material(Color(0.85, 0.40, 0.12), 0.4, 0.4) # Naranja industrial
	parent.add_child(cuerpo)

	# Tapa superior
	var tapa := MeshInstance3D.new()
	var box_t := BoxMesh.new()
	box_t.size = Vector3(0.175, 0.04, 0.265)
	tapa.mesh = box_t
	tapa.position.y = 0.08
	tapa.material_override = _crear_material(Color(0.18, 0.20, 0.22), 0.7, 0.3)
	parent.add_child(tapa)

	# Manija cromada
	var asa := MeshInstance3D.new()
	var box_asa := BoxMesh.new()
	box_asa.size = Vector3(0.03, 0.04, 0.12)
	asa.mesh = box_asa
	asa.position.y = 0.12
	asa.material_override = _crear_material(Color(0.85, 0.88, 0.92), 0.95, 0.15)
	parent.add_child(asa)

## Mochila táctica
static func _construir_mochila(parent: Node3D) -> void:
	var cuerpo := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.22, 0.18)
	cuerpo.mesh = box
	cuerpo.material_override = _crear_material(Color(0.32, 0.38, 0.28), 0.0, 0.85) # Verde militar
	parent.add_child(cuerpo)

	# Bolsillo frontal
	var bols := MeshInstance3D.new()
	var box_b := BoxMesh.new()
	box_b.size = Vector3(0.13, 0.12, 0.06)
	bols.mesh = box_b
	bols.position.z = 0.11
	bols.material_override = _crear_material(Color(0.26, 0.30, 0.22), 0.0, 0.9)
	parent.add_child(bols)

	# Correas y hebillas ámbar
	var hebilla := MeshInstance3D.new()
	var box_h := BoxMesh.new()
	box_h.size = Vector3(0.06, 0.02, 0.02)
	hebilla.mesh = box_h
	hebilla.position = Vector3(0.0, 0.02, 0.145)
	hebilla.material_override = _crear_material(Color(0.88, 0.68, 0.28), 0.8, 0.3)
	parent.add_child(hebilla)
