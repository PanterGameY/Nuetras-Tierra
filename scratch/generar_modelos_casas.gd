extends SceneTree

func _init() -> void:
	print("==================================================")
	print("  GENERANDO MODELOS 3D Y METADATA PARA BIBLIOTECA")
	print("==================================================")
	
	_generar_casa_moderna_cubica()
	_generar_chalet_alpino()
	_generar_casa_campesina_paisa()
	_generar_casa_pueblo_colonial()
	_generar_porteria_conjunto()
	_generar_modulo_casas_adosadas()
	_generar_edificio_apartamentos()
	_generar_torre_residencial()
	_generar_casona_hacienda()
	_generar_tienda_esquinera()
	
	print("==================================================")
	print("  ¡TODOS LOS MODELOS GENERADOS EXITOSAMENTE!")
	print("==================================================")
	quit()

# ── HELPER DE MATERIALES ─────────────────────────────────────────────
func _mat(albedo: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	return m

func _caja(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	padre.add_child(mi)
	mi.owner = padre
	
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tam
	col.shape = s
	col.position = pos
	padre.add_child(col)
	col.owner = padre
	return mi

func _cilindro(padre: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	mi.mesh = c
	mi.position = pos
	mi.material_override = mat
	padre.add_child(mi)
	mi.owner = padre
	return mi

func _tejado_dos_aguas(padre: Node3D, tam: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = tam
	mi.mesh = p
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	padre.add_child(mi)
	mi.owner = padre
	return mi

func _guardar_escena_y_meta(raiz: Node3D, ruta_tscn: String, id: String, nombre: String, icono: String, cat: String, sub: String, tam: Vector3, desc: String) -> void:
	var ps := PackedScene.new()
	ps.pack(raiz)
	var err = ResourceSaver.save(ps, ruta_tscn)
	print("  -> Guardado %s: %s" % [ruta_tscn, "OK" if err == OK else str(err)])
	
	var ruta_json = ruta_tscn.get_basename() + ".json"
	var meta = {
		"id": id,
		"nombre": nombre,
		"icono": icono,
		"categoria_raiz": cat,
		"seccion": sub.split("/")[0] if "/" in sub else sub,
		"subcategoria": sub.split("/")[-1] if "/" in sub else sub,
		"tamano": [tam.x, tam.y, tam.z],
		"descripcion": desc
	}
	var f = FileAccess.open(ruta_json, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta, "\t"))
		f.close()
		print("  -> Metadata: %s" % ruta_json)

# ── MODELOS RESIDENCIALES ────────────────────────────────────────────

func _generar_casa_moderna_cubica() -> void:
	var root := StaticBody3D.new()
	root.name = "CasaModernaCubica"
	
	var m_estuco := _mat(Color(0.93, 0.94, 0.95), 0.7)
	var m_gris := _mat(Color(0.24, 0.26, 0.29), 0.5)
	var m_madera := _mat(Color(0.68, 0.45, 0.28), 0.75)
	var m_vidrio := _mat(Color(0.2, 0.35, 0.45, 0.85), 0.1, 0.2)
	
	# Planta baja (blanco)
	_caja(root, Vector3(9.0, 3.2, 8.5), Vector3(0, 1.6, 0), m_estuco)
	# Planta alta desfasada (gris grafito)
	_caja(root, Vector3(8.0, 3.0, 7.5), Vector3(0.8, 4.7, -0.4), m_gris)
	# Ventanal frontal planta baja
	_caja(root, Vector3(4.0, 2.2, 0.2), Vector3(-1.0, 1.5, 4.3), m_vidrio)
	# Ventanal balcón planta alta
	_caja(root, Vector3(5.0, 2.0, 0.2), Vector3(0.8, 4.7, 3.4), m_vidrio)
	# Pérgola de madera en terraza
	_caja(root, Vector3(3.2, 0.2, 3.8), Vector3(-2.8, 3.3, 1.0), m_madera)
	# Columnas pérgola
	_caja(root, Vector3(0.2, 3.2, 0.2), Vector3(-4.2, 1.6, 2.8), m_madera)
	
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Casas_Modernas/casa_moderna_cubica.tscn",
		"casa_moderna_cubica", "Casa Moderna Cúbica", "🏢", "01_Edificaciones", "01_Residencial/Casas_Modernas", Vector3(10.0, 6.5, 9.5),
		"Residencia de arquitectura moderna con 2 plantas, ventanales panorámicos y pérgola.")

func _generar_chalet_alpino() -> void:
	var root := StaticBody3D.new()
	root.name = "ChaletAlpinoModerno"
	
	var m_piedra := _mat(Color(0.42, 0.44, 0.46), 0.9)
	var m_madera := _mat(Color(0.55, 0.36, 0.22), 0.7)
	var m_teja_negra := _mat(Color(0.18, 0.19, 0.20), 0.5)
	var m_vidrio := _mat(Color(0.2, 0.35, 0.45), 0.1)
	
	# Base de mampostería / piedra
	_caja(root, Vector3(8.5, 2.2, 10.0), Vector3(0, 1.1, 0), m_piedra)
	# Cuerpo superior de madera
	_caja(root, Vector3(7.8, 2.8, 9.2), Vector3(0, 3.6, 0), m_madera)
	# Tejado a 2 aguas pronunciado estilo alpino
	_tejado_dos_aguas(root, Vector3(9.2, 3.8, 10.8), Vector3(0, 6.4, 0), Vector3(0, 0, 0), m_teja_negra)
	# Gran ventanal triangular frontal
	_caja(root, Vector3(3.4, 2.4, 0.2), Vector3(0, 3.8, 4.65), m_vidrio)
	# Deck exterior frontal
	_caja(root, Vector3(7.5, 0.3, 3.0), Vector3(0, 0.15, 6.2), m_madera)
	
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Casas_Modernas/chalet_alpino_moderno.tscn",
		"chalet_alpino_moderno", "Chalet Alpino Moderno", "🏡", "01_Edificaciones", "01_Residencial/Casas_Modernas", Vector3(9.5, 8.5, 12.0),
		"Chalet estilo alpino con techumbre inclinada, deck de madera y fachada mixta.")

func _generar_casa_campesina_paisa() -> void:
	var root := StaticBody3D.new()
	root.name = "CasaCampesinaPaisa"
	
	var m_blanco := _mat(Color(0.94, 0.92, 0.88), 0.8) # Cal
	var m_zocalo := _mat(Color(0.12, 0.38, 0.72), 0.7) # Zócalo azul típico
	var m_teja := _mat(Color(0.72, 0.32, 0.18), 0.85) # Teja de barro terracota
	var m_chambrana := _mat(Color(0.85, 0.22, 0.18), 0.6) # Chambrana roja
	var m_madera := _mat(Color(0.48, 0.30, 0.16), 0.8)
	
	# Muro principal blanco
	_caja(root, Vector3(8.0, 3.2, 7.5), Vector3(0, 1.6, 0), m_blanco)
	# Zócalo inferior azul
	_caja(root, Vector3(8.1, 0.9, 7.6), Vector3(0, 0.45, 0), m_zocalo)
	# Tejado de barro a dos aguas
	_tejado_dos_aguas(root, Vector3(9.2, 2.2, 8.8), Vector3(0, 4.2, 0), Vector3(0, 0, 0), m_teja)
	# Corredor frontal (chambrana paisa)
	_caja(root, Vector3(8.4, 0.9, 0.15), Vector3(0, 0.55, 3.9), m_chambrana)
	# Columnas de madera del corredor
	for x in [-3.8, -1.3, 1.3, 3.8]:
		_caja(root, Vector3(0.22, 2.8, 0.22), Vector3(x, 1.4, 3.9), m_madera)
		
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Casas_Tradicionales/casa_campesina_paisa.tscn",
		"casa_campesina_paisa", "Casa Campesina Paisa", "🏠", "01_Edificaciones", "01_Residencial/Casas_Tradicionales", Vector3(9.5, 5.5, 9.0),
		"Vivienda tradicional campesina con tejas de barro, zócalo de color y corredor frontal.")

func _generar_casa_pueblo_colonial() -> void:
	var root := StaticBody3D.new()
	root.name = "CasaPuebloColonial"
	
	var m_pared := _mat(Color(0.92, 0.91, 0.86), 0.85)
	var m_zocalo := _mat(Color(0.68, 0.22, 0.15), 0.75) # Zócalo terracota
	var m_balcon := _mat(Color(0.38, 0.24, 0.14), 0.7) # Madera oscura
	var m_teja := _mat(Color(0.70, 0.30, 0.16), 0.9)
	
	# Estructura de 2 pisos
	_caja(root, Vector3(7.5, 6.2, 8.0), Vector3(0, 3.1, 0), m_pared)
	# Zócalo base
	_caja(root, Vector3(7.6, 1.0, 8.1), Vector3(0, 0.5, 0), m_zocalo)
	# Balcón corrido de madera en 2do piso
	_caja(root, Vector3(6.5, 1.0, 1.2), Vector3(0, 3.6, 4.4), m_balcon)
	# Tejado colonial
	_tejado_dos_aguas(root, Vector3(8.4, 2.2, 9.2), Vector3(0, 7.1, 0), Vector3(0, 0, 0), m_teja)
	
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Casas_Tradicionales/casa_pueblo_colonial.tscn",
		"casa_pueblo_colonial", "Casa de Pueblo Colonial", "🏛️", "01_Edificaciones", "01_Residencial/Casas_Tradicionales", Vector3(8.5, 8.5, 9.5),
		"Casona de dos plantas con balcón de madera tallada y arquitectura colonial.")

func _generar_porteria_conjunto() -> void:
	var root := StaticBody3D.new()
	root.name = "PorteriaConjunto"
	
	var m_concreto := _mat(Color(0.85, 0.86, 0.88), 0.6)
	var m_antracita := _mat(Color(0.20, 0.22, 0.24), 0.5)
	var m_vidrio := _mat(Color(0.25, 0.4, 0.5, 0.8), 0.1)
	var m_barrera := _mat(Color(0.9, 0.75, 0.1), 0.4) # Amarillo señal
	
	# Caseta de control
	_caja(root, Vector3(4.0, 3.0, 4.0), Vector3(-3.5, 1.5, 0), m_concreto)
	# Ventanal garita
	_caja(root, Vector3(2.8, 1.4, 2.8), Vector3(-3.5, 1.7, 0.6), m_vidrio)
	# Techo voladizo de acceso vehicular
	_caja(root, Vector3(12.0, 0.5, 6.0), Vector3(0, 4.2, 0), m_antracita)
	# Columna soporte
	_caja(root, Vector3(0.5, 4.0, 0.5), Vector3(5.5, 2.0, 0), m_concreto)
	# Barrera de paso (talanquera)
	_caja(root, Vector3(4.5, 0.12, 0.12), Vector3(1.5, 0.9, 0), m_barrera)
	
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Conjuntos_Cerrados/porteria_conjunto.tscn",
		"porteria_conjunto", "Portería y Acceso Conjunto", "🚪", "01_Edificaciones", "01_Residencial/Conjuntos_Cerrados", Vector3(13.0, 4.8, 6.5),
		"Acceso vigilado para urbanizaciones con garita de seguridad y cubierta vehicular.")

func _generar_modulo_casas_adosadas() -> void:
	var root := StaticBody3D.new()
	root.name = "ModuloCasasAdosadas"
	
	var m_muro1 := _mat(Color(0.90, 0.91, 0.93), 0.6)
	var m_muro2 := _mat(Color(0.78, 0.72, 0.66), 0.7)
	var m_techo := _mat(Color(0.22, 0.24, 0.26), 0.4)
	var m_vidrio := _mat(Color(0.2, 0.35, 0.45), 0.1)
	
	# Casa Izquierda
	_caja(root, Vector3(6.5, 5.8, 9.0), Vector3(-3.4, 2.9, 0), m_muro1)
	# Casa Derecha
	_caja(root, Vector3(6.5, 5.8, 9.0), Vector3(3.4, 2.9, 0), m_muro2)
	# Cubierta unificada moderna
	_caja(root, Vector3(13.8, 0.4, 9.6), Vector3(0, 6.0, 0), m_techo)
	# Ventanales
	_caja(root, Vector3(3.2, 2.0, 0.2), Vector3(-3.4, 4.2, 4.6), m_vidrio)
	_caja(root, Vector3(3.2, 2.0, 0.2), Vector3(3.4, 4.2, 4.6), m_vidrio)
	
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Conjuntos_Cerrados/modulo_casas_adosadas.tscn",
		"modulo_casas_adosadas", "Módulo Casas Pareadas", "🏘️", "01_Edificaciones", "01_Residencial/Conjuntos_Cerrados", Vector3(14.5, 6.5, 10.0),
		"Conjunto pareado de 2 viviendas unifamiliares para barrios residenciales continuos.")

func _generar_edificio_apartamentos() -> void:
	var root := StaticBody3D.new()
	root.name = "EdificioApartamentosLadrillo"
	
	var m_ladrillo := _mat(Color(0.72, 0.38, 0.24), 0.85) # Ladrillo a la vista
	var m_concreto := _mat(Color(0.82, 0.84, 0.86), 0.7)
	var m_vidrio := _mat(Color(0.2, 0.35, 0.45), 0.1)
	
	# Bloque de 4 plantas
	_caja(root, Vector3(11.0, 13.5, 11.0), Vector3(0, 6.75, 0), m_ladrillo)
	# Cornisa / remate superior
	_caja(root, Vector3(11.6, 0.6, 11.6), Vector3(0, 13.8, 0), m_concreto)
	# Ventanales frontales por piso
	for piso in range(4):
		var y = 2.0 + (piso * 3.2)
		_caja(root, Vector3(3.5, 1.8, 0.2), Vector3(-2.8, y, 5.6), m_vidrio)
		_caja(root, Vector3(3.5, 1.8, 0.2), Vector3(2.8, y, 5.6), m_vidrio)
		
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Edificios_Apartamentos/edificio_apartamentos_ladrillo.tscn",
		"edificio_apartamentos_ladrillo", "Edificio Apartamentos Ladrillo", "🏢", "01_Edificaciones", "01_Residencial/Edificios_Apartamentos", Vector3(12.0, 14.5, 12.0),
		"Bloque residencial multifamiliar de 4 pisos en ladrillo a la vista.")

func _generar_torre_residencial() -> void:
	var root := StaticBody3D.new()
	root.name = "TorreResidencialModerna"
	
	var m_blanco := _mat(Color(0.92, 0.93, 0.95), 0.6)
	var m_vidrio := _mat(Color(0.2, 0.4, 0.55), 0.1)
	var m_negro := _mat(Color(0.18, 0.20, 0.22), 0.5)
	
	# Torre de 6 pisos
	_caja(root, Vector3(12.0, 19.0, 12.0), Vector3(0, 9.5, 0), m_blanco)
	# Balcones acristalados continuos
	for piso in range(6):
		var y = 2.2 + (piso * 3.0)
		_caja(root, Vector3(10.5, 0.9, 1.5), Vector3(0, y, 6.5), m_vidrio)
	# Remate terraza superior
	_caja(root, Vector3(8.0, 2.5, 8.0), Vector3(0, 20.0, 0), m_negro)
	
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/01_Residencial/Edificios_Apartamentos/torre_residencial_moderna.tscn",
		"torre_residencial_moderna", "Torre Residencial Moderna", "🏬", "01_Edificaciones", "01_Residencial/Edificios_Apartamentos", Vector3(13.0, 21.5, 13.5),
		"Torre de vivienda urbana de 6 pisos con balcones panorámicos y terraza.")

func _generar_casona_hacienda() -> void:
	var root := StaticBody3D.new()
	root.name = "CasonaHaciendaCafetera"
	
	var m_pared := _mat(Color(0.94, 0.92, 0.88), 0.85)
	var m_teja := _mat(Color(0.72, 0.32, 0.18), 0.85)
	var m_madera := _mat(Color(0.50, 0.32, 0.18), 0.8)
	
	# Núcleo central
	_caja(root, Vector3(12.0, 4.0, 10.0), Vector3(0, 2.0, 0), m_pared)
	# Tejado amplio a cuatro aguas
	_tejado_dos_aguas(root, Vector3(15.0, 2.8, 13.0), Vector3(0, 5.2, 0), Vector3(0, 0, 0), m_teja)
	# Corredor perimetral con columnas rústicas
	for x in [-6.8, 6.8]:
		for z in [-5.5, -2.0, 2.0, 5.5]:
			_caja(root, Vector3(0.3, 3.6, 0.3), Vector3(x, 1.8, z), m_madera)
			
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/05_Rural_Agropecuario/Fincas_Haciendas/casona_hacienda_cafetera.tscn",
		"casona_hacienda_cafetera", "Casona Hacienda Cafetera", "🚜", "01_Edificaciones", "05_Rural_Agropecuario/Fincas_Haciendas", Vector3(16.0, 6.5, 14.0),
		"Casona rural tradicional con corredores en cuatro costados y techos amplios.")

func _generar_tienda_esquinera() -> void:
	var root := StaticBody3D.new()
	root.name = "TiendaEsquineraBarrio"
	
	var m_muro := _mat(Color(0.92, 0.90, 0.84), 0.7)
	var m_toldo := _mat(Color(0.85, 0.18, 0.18), 0.6) # Rojo con blanco
	var m_vidrio := _mat(Color(0.25, 0.4, 0.5), 0.1)
	
	# Local comercial
	_caja(root, Vector3(8.0, 4.5, 7.5), Vector3(0, 2.25, 0), m_muro)
	# Toldo frontal esquinero
	_caja(root, Vector3(7.0, 0.2, 2.0), Vector3(0, 3.2, 4.4), m_toldo)
	# Gran vitrina de comercio
	_caja(root, Vector3(6.0, 2.2, 0.2), Vector3(0, 1.6, 3.8), m_vidrio)
	
	_guardar_escena_y_meta(root, "res://mundo/editor_mapas/Biblioteca/01_Edificaciones/02_Comercial/Tiendas_y_Locales/tienda_esquinera_barrio.tscn",
		"tienda_esquinera_barrio", "Tienda Esquinera de Barrio", "🏪", "01_Edificaciones", "02_Comercial/Tiendas_y_Locales", Vector3(9.0, 5.0, 8.5),
		"Tienda comercial de barrio con toldo frontal y amplia vitrina.")
